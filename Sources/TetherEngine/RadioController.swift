import Foundation
import CoreWLAN

public struct RadioInfo: Sendable {
    public let interfaceName: String
    public let ssid: String?
    public let bssid: String?
    public let channel: Int
    public let channelBand: String // "2GHz" or "5GHz"
    public let channelWidth: Int // 20, 40, 80, 160
    public let rssi: Int
    public let noise: Int
    public let txRate: Double
    public let phyMode: String
    public let countryCode: String?
    public let powerOn: Bool
    public let hardwareAddress: String?

    public var signalQuality: Double {
        let snr = Double(rssi - noise)
        return min(max(snr / 50.0, 0), 1.0)
    }

    public var signalLabel: String {
        let q = signalQuality
        if q > 0.8 { return "Excellent" }
        if q > 0.6 { return "Good" }
        if q > 0.4 { return "Fair" }
        if q > 0.2 { return "Weak" }
        return "Poor"
    }
}

public struct ScannedNetwork: Sendable {
    public let ssid: String
    public let bssid: String
    public let rssi: Int
    public let channel: Int
    public let band: String
    public let security: String
    public let isIBSS: Bool
}

public final class RadioController: @unchecked Sendable {
    private let wifiClient: CWWiFiClient
    private var interface: CWInterface?

    public init() {
        self.wifiClient = CWWiFiClient.shared()
        self.interface = wifiClient.interface()
    }

    // MARK: - Radio Info

    public func currentRadioInfo() -> RadioInfo? {
        guard let iface = interface else { return nil }

        let channel = iface.wlanChannel()
        let bandLabel: String
        if let ch = channel {
            switch ch.channelBand {
            case .band2GHz: bandLabel = "2GHz"
            case .band5GHz: bandLabel = "5GHz"
            case .bandUnknown: bandLabel = "Unknown"
            @unknown default: bandLabel = "Unknown"
            }
        } else {
            bandLabel = "Unknown"
        }

        let widthValue: Int
        if let ch = channel {
            switch ch.channelWidth {
            case .width20MHz: widthValue = 20
            case .width40MHz: widthValue = 40
            case .width80MHz: widthValue = 80
            case .width160MHz: widthValue = 160
            case .widthUnknown: widthValue = 0
            @unknown default: widthValue = 20
            }
        } else {
            widthValue = 20
        }

        let phyLabel: String
        switch iface.activePHYMode() {
        case .mode11a: phyLabel = "802.11a"
        case .mode11b: phyLabel = "802.11b"
        case .mode11g: phyLabel = "802.11g"
        case .mode11n: phyLabel = "802.11n"
        case .mode11ac: phyLabel = "802.11ac"
        case .mode11ax: phyLabel = "802.11ax"
        case .modeNone: phyLabel = "None"
        @unknown default: phyLabel = "Unknown"
        }

        return RadioInfo(
            interfaceName: iface.interfaceName ?? "en0",
            ssid: iface.ssid(),
            bssid: iface.bssid(),
            channel: channel?.channelNumber ?? 0,
            channelBand: bandLabel,
            channelWidth: widthValue,
            rssi: iface.rssiValue(),
            noise: iface.noiseMeasurement(),
            txRate: iface.transmitRate(),
            phyMode: phyLabel,
            countryCode: iface.countryCode(),
            powerOn: iface.powerOn(),
            hardwareAddress: iface.hardwareAddress()
        )
    }

    // MARK: - WiFi Scanning

    public func scanNetworks() -> [ScannedNetwork] {
        guard let iface = interface else { return [] }

        do {
            let networks = try iface.scanForNetworks(withName: nil)
            return networks.map { net in
                let band: String
                if let ch = net.wlanChannel {
                    switch ch.channelBand {
                    case .band2GHz: band = "2GHz"
                    case .band5GHz: band = "5GHz"
                    @unknown default: band = "Unknown"
                    }
                } else {
                    band = "Unknown"
                }

                return ScannedNetwork(
                    ssid: net.ssid ?? "<hidden>",
                    bssid: net.bssid ?? "",
                    rssi: net.rssiValue,
                    channel: net.wlanChannel?.channelNumber ?? 0,
                    band: band,
                    security: "WPA2", // simplified
                    isIBSS: net.ibss
                )
            }.sorted { $0.rssi > $1.rssi }
        } catch {
            return []
        }
    }

    // MARK: - Power Control

    public func setPower(on: Bool) throws {
        guard let iface = interface else { return }
        try iface.setPower(on)
    }

    // MARK: - Channel Selection

    public func supportedChannels() -> [(number: Int, band: String, width: Int)] {
        guard let iface = interface else { return [] }
        guard let channels = iface.supportedWLANChannels() else { return [] }

        return channels.map { ch in
            let band: String
            switch ch.channelBand {
            case .band2GHz: band = "2GHz"
            case .band5GHz: band = "5GHz"
            case .bandUnknown: band = "?"
            @unknown default: band = "?"
            }
            let width: Int
            switch ch.channelWidth {
            case .width20MHz: width = 20
            case .width40MHz: width = 40
            case .width80MHz: width = 80
            case .width160MHz: width = 160
            case .widthUnknown: width = 0
            @unknown default: width = 20
            }
            return (number: ch.channelNumber, band: band, width: width)
        }.sorted { $0.number < $1.number }
    }

    public func bestChannel(for band: String) -> Int {
        let scanned = scanNetworks()
        let channels = supportedChannels().filter { $0.band == band }
        guard !channels.isEmpty else { return band == "5GHz" ? 36 : 1 }

        var usage: [Int: Int] = [:]
        for ch in channels { usage[ch.number] = 0 }
        for net in scanned where net.band == band {
            usage[net.channel, default: 0] += 1
        }

        return usage.min(by: { $0.value < $1.value })?.key ?? channels[0].number
    }

    // MARK: - Interface List

    public func allWiFiInterfaces() -> [String] {
        return CWWiFiClient.interfaceNames() ?? []
    }

    // MARK: - Hotspot Mode Queries

    public func isAutoHotspotEnabled() -> Bool {
        return false
    }

    // MARK: - Extended Scan

    public func extendedScan() -> [[String: Any]] {
        return []
    }
}
