import Foundation
import Combine

public final class TetherEngine: ObservableObject {
    public let monitor: NetworkMonitor
    public let sharing: InternetSharingController
    public let radio: RadioController
    public let clients: ClientManager

    @Published public var networkStatus: String = "Initializing..."
    @Published public var primaryInterface: String = "—"
    @Published public var interfaceType: String = "—"
    @Published public var isExpensive: Bool = false
    @Published public var signalStrength: Int = 0
    @Published public var noiseLevel: Int = 0
    @Published public var channel: Int = 0
    @Published public var channelBand: String = "—"
    @Published public var phyMode: String = "—"
    @Published public var txRate: Double = 0
    @Published public var ssid: String? = nil
    @Published public var sharingActive: Bool = false
    @Published public var connectedDevices: [ManagedClient] = []
    @Published public var detectedSources: [DetectedInterface] = []

    public init() {
        self.monitor = NetworkMonitor()
        self.sharing = InternetSharingController()
        self.radio = RadioController()
        self.clients = ClientManager()
    }

    public func start() {
        monitor.start { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.networkStatus = snapshot.statusLabel
                self.primaryInterface = snapshot.primaryInterface?.name ?? "—"
                self.interfaceType = snapshot.primaryInterface?.typeLabel ?? "—"
                self.isExpensive = snapshot.isExpensive
            }
        }

        refreshRadio()
        refreshSources()
        startRefreshTimer()
    }

    public func refreshRadio() {
        if let info = radio.currentRadioInfo() {
            DispatchQueue.main.async {
                self.signalStrength = info.rssi
                self.noiseLevel = info.noise
                self.channel = info.channel
                self.channelBand = info.channelBand
                self.phyMode = info.phyMode
                self.txRate = info.txRate
                self.ssid = info.ssid
            }
        }
    }

    public func refreshSources() {
        let sources = sharing.detectSourceInterfaces()
        DispatchQueue.main.async {
            self.detectedSources = sources
        }
    }

    public func refreshClients() {
        let tethered = sharing.queryClients()
        clients.updateFromLeases(tethered)
        DispatchQueue.main.async {
            self.connectedDevices = self.clients.allClients
        }
    }

    public func startSharing(ssid: String, password: String, source: String) {
        let config = SharingConfig(
            sourceInterface: source,
            shareVia: .wifi,
            wifiConfig: WiFiAPConfig(ssid: ssid, password: password, security: .wpa2)
        )
        sharing.updateConfig(config)
        Task {
            do {
                try await sharing.startSharing()
                await MainActor.run { self.sharingActive = true }
            } catch {
                await MainActor.run { self.sharingActive = false }
            }
        }
    }

    public func stopSharing() {
        Task {
            try? await sharing.stopSharing()
            await MainActor.run {
                self.sharingActive = false
                self.connectedDevices = []
            }
        }
    }

    public func pauseDevice(mac: String) {
        try? clients.pauseClient(mac: mac)
        refreshClients()
    }

    public func resumeDevice(mac: String) {
        try? clients.resumeClient(mac: mac)
        refreshClients()
    }

    public func kickDevice(mac: String) {
        clients.kickClient(mac: mac)
        refreshClients()
    }

    private var refreshTimer: DispatchSourceTimer?

    private func startRefreshTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.refreshRadio()
            self?.refreshClients()
        }
        timer.resume()
        refreshTimer = timer
    }
}
