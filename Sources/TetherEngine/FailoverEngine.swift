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
            if decision.action != .none {
                onDecision(decision)
            }
        }
    }

    public func stop() {
        isRunning = false
        monitor.stop()
    }

    private func evaluate(_ snapshot: NetworkSnapshot) -> FailoverDecision {
        let primary = snapshot.primaryInterface

        if snapshot.status == .unsatisfied {
            let fallback = snapshot.interfaces.first(where: { !$0.isActive && $0.type != .loopback })
            return FailoverDecision(
                action: .failover,
                fromInterface: primary?.name ?? "none",
                toInterface: fallback?.name,
                reason: "Primary connection lost",
                confidence: 1.0,
                timestamp: Date()
            )
        }

        if snapshot.isExpensive && snapshot.interfaces.contains(where: { $0.type == .wifi && !$0.isActive }) {
            return FailoverDecision(
                action: .preWarm,
                fromInterface: primary?.name ?? "cellular",
                toInterface: snapshot.interfaces.first(where: { $0.type == .wifi })?.name,
                reason: "On expensive connection, WiFi available",
                confidence: 0.7,
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
}
