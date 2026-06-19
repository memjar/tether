import Foundation
import Network
import SystemConfiguration

public struct InterfaceSnapshot: Sendable {
    public let name: String
    public let type: NWInterface.InterfaceType
    public let isActive: Bool
    public let ipv4: String?
    public let ipv6: String?
    public let timestamp: Date

    public var typeLabel: String {
        switch type {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}

public struct NetworkSnapshot: Sendable {
    public let status: NWPath.Status
    public let interfaces: [InterfaceSnapshot]
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let supportsIPv4: Bool
    public let supportsIPv6: Bool
    public let supportsDNS: Bool
    public let timestamp: Date

    public var primaryInterface: InterfaceSnapshot? {
        interfaces.first(where: { $0.isActive })
    }

    public var statusLabel: String {
        switch status {
        case .satisfied: return "Connected"
        case .unsatisfied: return "Disconnected"
        case .requiresConnection: return "Requires Connection"
        @unknown default: return "Unknown"
        }
    }
}

public final class NetworkMonitor: @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "diy.tether.networkmonitor")
    private var currentPath: NWPath?
    private var onChange: ((NetworkSnapshot) -> Void)?
    private var history: [NetworkSnapshot] = []
    private let maxHistory = 3600 // 1 hour at 1/sec

    public private(set) var latestSnapshot: NetworkSnapshot?

    public init() {
        self.monitor = NWPathMonitor()
    }

    public func start(onChange: @escaping (NetworkSnapshot) -> Void) {
        self.onChange = onChange
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.currentPath = path
            let snapshot = self.buildSnapshot(from: path)
            self.latestSnapshot = snapshot
            self.history.append(snapshot)
            if self.history.count > self.maxHistory {
                self.history.removeFirst(self.history.count - self.maxHistory)
            }
            onChange(snapshot)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
    }

    public func getHistory(last seconds: Int) -> [NetworkSnapshot] {
        let cutoff = Date().addingTimeInterval(-Double(seconds))
        return history.filter { $0.timestamp > cutoff }
    }

    private func buildSnapshot(from path: NWPath) -> NetworkSnapshot {
        let interfaces = path.availableInterfaces.map { iface in
            InterfaceSnapshot(
                name: iface.name,
                type: iface.type,
                isActive: path.usesInterfaceType(iface.type),
                ipv4: nil,
                ipv6: nil,
                timestamp: Date()
            )
        }
        return NetworkSnapshot(
            status: path.status,
            interfaces: interfaces,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            supportsDNS: path.supportsDNS,
            timestamp: Date()
        )
    }
}
