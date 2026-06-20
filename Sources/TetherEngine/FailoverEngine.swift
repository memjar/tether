import Foundation
import Network

public enum FailoverAction: String, Sendable {
    case none
    case preWarm
    case failover
    case throttle
}

public struct FailoverDecision: Sendable {
    public let action: FailoverAction
    public let fromInterface: String
    public let toInterface: String?
    public let reason: String
    public let confidence: Double
    public let timestamp: Date
}

public final class FailoverEngine: @unchecked Sendable {
    private let monitor: NetworkMonitor
    private let sharingController: InternetSharingController
    private var onDecision: ((FailoverDecision) -> Void)?
    private var isRunning = false
    private let queue = DispatchQueue(label: "diy.tether.failover")

    private var lastAction: FailoverAction = .none
    private var failoverCount = 0
    private var lastFailoverTime: Date?
    private var signalHistory: [Double] = []

    public private(set) var currentDecision: FailoverDecision?

    public init(monitor: NetworkMonitor, sharingController: InternetSharingController) {
        self.monitor = monitor
        self.sharingController = sharingController
    }

    public func start(onDecision: @escaping (FailoverDecision) -> Void) {
        self.onDecision = onDecision
        self.isRunning = true

        monitor.start { [weak self] snapshot in
            guard let self = self, self.isRunning else { return }
            let decision = self.evaluate(snapshot)
            self.currentDecision = decision
            if decision.action != .none {
                self.execute(decision)
                onDecision(decision)
            }
        }
    }

    public func stop() {
        isRunning = false
    }

    private func evaluate(_ snapshot: NetworkSnapshot) -> FailoverDecision {
        let primary = snapshot.primaryInterface
        let available = snapshot.interfaces.filter { $0.type != .loopback }
        let inactive = available.filter { !$0.isActive }

        if snapshot.status == .unsatisfied {
            let fallback = bestFallback(from: inactive)
            return FailoverDecision(
                action: .failover,
                fromInterface: primary?.name ?? "none",
                toInterface: fallback?.name,
                reason: "Primary connection lost",
                confidence: 1.0,
                timestamp: Date()
            )
        }

        if snapshot.isExpensive {
            if let wifi = inactive.first(where: { $0.type == .wifi }) {
                return FailoverDecision(
                    action: .preWarm,
                    fromInterface: primary?.name ?? "cellular",
                    toInterface: wifi.name,
                    reason: "On expensive connection, WiFi available",
                    confidence: 0.7,
                    timestamp: Date()
                )
            }
        }

        if snapshot.isConstrained && !snapshot.isExpensive {
            return FailoverDecision(
                action: .throttle,
                fromInterface: primary?.name ?? "none",
                toInterface: nil,
                reason: "Network constrained — Low Data Mode active",
                confidence: 0.8,
                timestamp: Date()
            )
        }

        let history = monitor.getHistory(last: 30)
        let recentDrops = history.filter { $0.status == .unsatisfied }.count
        if recentDrops > 3 {
            let fallback = bestFallback(from: inactive)
            return FailoverDecision(
                action: .preWarm,
                fromInterface: primary?.name ?? "none",
                toInterface: fallback?.name,
                reason: "Unstable — \(recentDrops) drops in 30s",
                confidence: 0.6,
                timestamp: Date()
            )
        }

        return FailoverDecision(
            action: .none,
            fromInterface: primary?.name ?? "none",
            toInterface: nil,
            reason: "Network stable",
            confidence: 1.0,
            timestamp: Date()
        )
    }

    private func bestFallback(from interfaces: [InterfaceSnapshot]) -> InterfaceSnapshot? {
        let priority: [NWInterface.InterfaceType] = [.wifi, .wiredEthernet, .cellular, .other]
        for type in priority {
            if let match = interfaces.first(where: { $0.type == type }) { return match }
        }
        return interfaces.first
    }

    private func execute(_ decision: FailoverDecision) {
        guard decision.action == .failover, let target = decision.toInterface else { return }
        guard shouldAllowFailover() else {
            print("[Failover] Cooldown active — skipping switch to \(target)")
            return
        }

        print("[Failover] Switching source from \(decision.fromInterface) to \(target)")
        failoverCount += 1
        lastFailoverTime = Date()
        lastAction = decision.action

        if sharingController.state == .active {
            let currentConfig = sharingController.config
            let newConfig = SharingConfig(
                sourceInterface: target,
                shareVia: currentConfig.shareVia,
                wifiConfig: currentConfig.wifiConfig,
                subnet: currentConfig.subnet,
                startAddress: currentConfig.startAddress,
                endAddress: currentConfig.endAddress,
                netmask: currentConfig.netmask
            )
            sharingController.updateConfig(newConfig)

            Task {
                try? await sharingController.stopSharing()
                try? await Task.sleep(nanoseconds: 500_000_000)
                try? await sharingController.startSharing()
                print("[Failover] Sharing restarted on \(target)")
            }
        }
    }

    private func shouldAllowFailover() -> Bool {
        guard let last = lastFailoverTime else { return true }
        return Date().timeIntervalSince(last) > 10
    }
}
