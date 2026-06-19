import Foundation

public enum SharingState: String, Sendable {
    case idle
    case starting
    case active
    case stopping
    case error
}

public enum SecurityType: String, Sendable {
    case none = "None"
    case wep = "WEP"
    case wpa2 = "WPA2 Personal"
    case wpa3 = "WPA3 Personal"
}

public struct WiFiAPConfig: Sendable {
    public let ssid: String
    public let password: String
    public let security: SecurityType
    public let channel: Int
    public let use5GHz: Bool

    public init(
        ssid: String = "Tether",
        password: String = "",
        security: SecurityType = .wpa2,
        channel: Int = 0, // 0 = auto
        use5GHz: Bool = false
    ) {
        self.ssid = ssid
        self.password = password
        self.security = security
        self.channel = channel
        self.use5GHz = use5GHz
    }
}

public struct SharingConfig: Sendable {
    public let sourceInterface: String
    public let shareVia: ShareMethod
    public let wifiConfig: WiFiAPConfig
    public let subnet: String
    public let startAddress: String
    public let endAddress: String
    public let netmask: String

    public enum ShareMethod: String, Sendable {
        case wifi = "WiFi"
        case ethernet = "Ethernet"
        case usb = "USB"
    }

    public init(
        sourceInterface: String = "en0",
        shareVia: ShareMethod = .wifi,
        wifiConfig: WiFiAPConfig = WiFiAPConfig(),
        subnet: String = "192.168.234.0",
        startAddress: String = "192.168.234.2",
        endAddress: String = "192.168.234.254",
        netmask: String = "255.255.255.0"
    ) {
        self.sourceInterface = sourceInterface
        self.shareVia = shareVia
        self.wifiConfig = wifiConfig
        self.subnet = subnet
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.netmask = netmask
    }
}

public struct TetheredClient: Sendable {
    public let mac: String
    public let ip: String
    public let hostname: String?
    public let leaseExpiry: Date?
}

public final class InternetSharingController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "diy.tether.sharing")
    public private(set) var state: SharingState = .idle
    public private(set) var config: SharingConfig
    public private(set) var connectedClients: Int = 0
    public private(set) var clients: [TetheredClient] = []

    private let natPlistPath = "/Library/Preferences/SystemConfiguration/com.apple.nat.plist"
    private let launchdPlist = "/System/Library/LaunchDaemons/com.apple.NetworkSharing.plist"
    private let dhcpLeasesPath = "/var/db/dhcpd_leases"

    public init(config: SharingConfig = SharingConfig()) {
        self.config = config
    }

    public func updateConfig(_ config: SharingConfig) {
        self.config = config
    }

    // MARK: - Interface Detection

    public func detectSourceInterfaces() -> [DetectedInterface] {
        var detected: [DetectedInterface] = []

        let output = shell("/sbin/ifconfig", ["-a"])
        let blocks = output.components(separatedBy: "\n").reduce(into: [[String]]()) { result, line in
            if !line.hasPrefix("\t") && !line.hasPrefix(" ") && !line.isEmpty {
                result.append([line])
            } else if !result.isEmpty {
                result[result.count - 1].append(line)
            }
        }

        for block in blocks {
            guard let header = block.first else { continue }
            let name = String(header.prefix(while: { $0 != ":" }))
            let joined = block.joined(separator: "\n")
            let hasIPv4 = joined.contains("inet ")
            let isUp = joined.contains("status: active") || joined.contains("<UP,")

            if !isUp || !hasIPv4 { continue }
            if name == "lo0" { continue }

            let kind = classifyInterface(name: name, detail: joined)
            if kind != .unknown {
                var ip: String?
                for line in block {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("inet ") {
                        ip = trimmed.components(separatedBy: " ")[1]
                        break
                    }
                }
                detected.append(DetectedInterface(name: name, kind: kind, ip: ip ?? ""))
            }
        }

        return detected
    }

    public func autoSelectSource() -> DetectedInterface? {
        let interfaces = detectSourceInterfaces()
        let priority: [InterfaceKind] = [.iphoneUSB, .cellular, .ethernet, .wifi, .thunderbolt, .bluetooth]
        for kind in priority {
            if let match = interfaces.first(where: { $0.kind == kind }) {
                return match
            }
        }
        return interfaces.first
    }

    // MARK: - Sharing Control

    public func startSharing() async throws {
        state = .starting

        try writeNATPlist()

        if config.shareVia == .wifi {
            try writeWiFiAPConfig()
        }

        let result = shell("/bin/launchctl", ["load", "-w", launchdPlist])
        if !result.contains("error") || result.isEmpty {
            state = .active
            startClientMonitor()
        } else {
            state = .error
            throw TetherError.sharingStartFailed(code: 1)
        }
    }

    public func stopSharing() async throws {
        state = .stopping
        let _ = shell("/bin/launchctl", ["unload", "-w", launchdPlist])
        state = .idle
        connectedClients = 0
        clients = []
    }

    public func isInternetSharingRunning() -> Bool {
        let output = shell("/bin/launchctl", ["list"])
        return output.contains("com.apple.NetworkSharing")
    }

    // MARK: - NAT Plist

    private func writeNATPlist() throws {
        var natDict: [String: Any] = [
            "Enabled": 1,
            "PrimaryInterface": [
                "Device": config.sourceInterface,
                "Enabled": 1,
                "HardwareKey": "",
            ] as [String: Any],
            "SharingNetworkNumberStart": config.startAddress,
            "SharingNetworkNumberEnd": config.endAddress,
            "SharingNetworkMask": config.netmask,
            "NatPortMapDisabled": 0,
        ]

        if config.shareVia == .wifi {
            natDict["AirPort"] = [
                "Channel": config.wifiConfig.channel,
                "NetworkName": config.wifiConfig.ssid,
                "SecurityType": config.wifiConfig.security.rawValue,
                "NetworkPassword": config.wifiConfig.password,
                "40MHzChannel": config.wifiConfig.use5GHz ? 1 : 0,
            ] as [String: Any]
            natDict["SharingDevices"] = [findWiFiInterface()]
        } else if config.shareVia == .ethernet {
            natDict["SharingDevices"] = [findEthernetInterface()]
        }

        let plist: [String: Any] = ["NAT": natDict]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)

        let tempPath = "/tmp/com.apple.nat.plist"
        try data.write(to: URL(fileURLWithPath: tempPath))

        let _ = shell("/usr/bin/sudo", ["cp", tempPath, natPlistPath])
        try FileManager.default.removeItem(atPath: tempPath)
    }

    private func writeWiFiAPConfig() throws {
        // InternetSharing reads WiFi AP settings from the NAT plist's AirPort key
        // which we already wrote in writeNATPlist()
    }

    // MARK: - Client Monitoring

    public func queryClients() -> [TetheredClient] {
        var found: [TetheredClient] = []

        // Method 1: DHCP leases file
        if FileManager.default.fileExists(atPath: dhcpLeasesPath) {
            if let content = try? String(contentsOfFile: dhcpLeasesPath, encoding: .utf8) {
                found.append(contentsOf: parseDHCPLeases(content))
            }
        }

        // Method 2: ARP table for our subnet
        let arpOutput = shell("/usr/sbin/arp", ["-a"])
        let subnetPrefix = config.subnet.components(separatedBy: ".").prefix(3).joined(separator: ".")

        for line in arpOutput.components(separatedBy: "\n") {
            guard line.contains(subnetPrefix) else { continue }
            let parts = line.components(separatedBy: " ").filter { !$0.isEmpty }
            guard parts.count >= 4 else { continue }

            let hostname = parts[0]
            let ip = parts[1]
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let mac = parts[3]

            if mac != "(incomplete)" && !found.contains(where: { $0.mac == mac }) {
                found.append(TetheredClient(
                    mac: mac,
                    ip: ip,
                    hostname: hostname == "?" ? nil : hostname,
                    leaseExpiry: nil
                ))
            }
        }

        clients = found
        connectedClients = found.count
        return found
    }

    private var clientTimer: DispatchSourceTimer?

    private func startClientMonitor() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 10)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.state == .active else { return }
            let _ = self.queryClients()
        }
        timer.resume()
        clientTimer = timer
    }

    // MARK: - DHCP Lease Parsing

    private func parseDHCPLeases(_ content: String) -> [TetheredClient] {
        var clients: [TetheredClient] = []
        var currentEntry: [String: String] = [:]

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "{" {
                currentEntry = [:]
            } else if trimmed == "}" {
                if let mac = currentEntry["hw_address"],
                   let ip = currentEntry["ip_address"] {
                    clients.append(TetheredClient(
                        mac: mac,
                        ip: ip,
                        hostname: currentEntry["name"],
                        leaseExpiry: nil
                    ))
                }
            } else if trimmed.contains("=") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count == 2 {
                    currentEntry[parts[0]] = parts[1]
                }
            }
        }
        return clients
    }

    // MARK: - Interface Helpers

    private func findWiFiInterface() -> String {
        let output = shell("/usr/sbin/networksetup", ["-listallhardwareports"])
        var nextIsWiFi = false
        for line in output.components(separatedBy: "\n") {
            if line.contains("Wi-Fi") || line.contains("AirPort") {
                nextIsWiFi = true
            } else if nextIsWiFi && line.contains("Device:") {
                return line.components(separatedBy: ": ").last ?? "en0"
            } else if !line.contains("Device:") {
                nextIsWiFi = false
            }
        }
        return "en0"
    }

    private func findEthernetInterface() -> String {
        let output = shell("/usr/sbin/networksetup", ["-listallhardwareports"])
        var nextIsEth = false
        for line in output.components(separatedBy: "\n") {
            if line.contains("Ethernet") && !line.contains("Thunderbolt") {
                nextIsEth = true
            } else if nextIsEth && line.contains("Device:") {
                return line.components(separatedBy: ": ").last ?? "en1"
            } else if !line.contains("Device:") {
                nextIsEth = false
            }
        }
        return "en1"
    }

    private func classifyInterface(name: String, detail: String) -> InterfaceKind {
        // iPhone USB tethering shows as specific interface types
        if name.hasPrefix("en") && detail.contains("POINTOPOINT") { return .iphoneUSB }
        if name.hasPrefix("bridge") { return .unknown } // our own bridge, skip
        if name == "en0" { return .wifi } // usually WiFi on laptops
        if name.hasPrefix("en") && (detail.contains("autoconf") || name == "en0") { return .wifi }

        // Check via networksetup
        let hwOutput = shell("/usr/sbin/networksetup", ["-listallhardwareports"])
        if hwOutput.contains("Device: \(name)") {
            if hwOutput.components(separatedBy: "Device: \(name)").first?.contains("iPhone") == true { return .iphoneUSB }
            if hwOutput.components(separatedBy: "Device: \(name)").first?.contains("Wi-Fi") == true { return .wifi }
            if hwOutput.components(separatedBy: "Device: \(name)").first?.contains("Ethernet") == true { return .ethernet }
            if hwOutput.components(separatedBy: "Device: \(name)").first?.contains("Thunderbolt") == true { return .thunderbolt }
            if hwOutput.components(separatedBy: "Device: \(name)").first?.contains("Bluetooth") == true { return .bluetooth }
        }

        if name.hasPrefix("en") { return .ethernet }
        if name.hasPrefix("pdp_ip") { return .cellular }
        if name.hasPrefix("bnep") { return .bluetooth }

        return .unknown
    }

    // MARK: - Shell Helper

    private func shell(_ command: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Supporting Types

public enum InterfaceKind: String, Sendable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case iphoneUSB = "iPhone USB"
    case thunderbolt = "Thunderbolt"
    case bluetooth = "Bluetooth"
    case unknown = "Unknown"
}

public struct DetectedInterface: Sendable {
    public let name: String
    public let kind: InterfaceKind
    public let ip: String
}

public enum TetherError: Error, LocalizedError {
    case sharingStartFailed(code: Int)
    case sharingStopFailed(code: Int)
    case noExternalInterface
    case noSharingInterface
    case noPassword
    case configurationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sharingStartFailed(let code): return "Sharing failed to start (exit \(code))"
        case .sharingStopFailed(let code): return "Sharing failed to stop (exit \(code))"
        case .noExternalInterface: return "No internet source found"
        case .noSharingInterface: return "No sharing interface available"
        case .noPassword: return "WiFi password required for WPA2/WPA3"
        case .configurationFailed(let msg): return "Config failed: \(msg)"
        }
    }
}
