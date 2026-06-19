import Foundation
import TetherEngine

public struct PredictionResult: Sendable {
    public let failureProbability: Double
    public let recommendedAction: FailoverAction
    public let predictedDowntime: Double
    public let alternativeInterface: String?
    public let timestamp: Date
}

public final class NetworkPredictor: @unchecked Sendable {
    private var signalHistory: [Double] = []
    private let windowSize = 60

    public init() {}

    public func feed(snapshot: NetworkSnapshot) -> PredictionResult {
        let signalScore = calculateSignalScore(snapshot)
        signalHistory.append(signalScore)
        if signalHistory.count > windowSize {
            signalHistory.removeFirst(signalHistory.count - windowSize)
        }

        let trend = calculateTrend()
        let volatility = calculateVolatility()

        let failProb = min(1.0, max(0.0, (1.0 - signalScore) * 0.4 + (-trend) * 0.3 + volatility * 0.3))

        let action: FailoverAction
        if failProb > 0.9 { action = .failover }
        else if failProb > 0.7 { action = .preWarm }
        else if failProb > 0.5 { action = .throttle }
        else { action = .none }

        let alt = snapshot.interfaces.first(where: { !$0.isActive && $0.type != .loopback })

        return PredictionResult(
            failureProbability: failProb,
            recommendedAction: action,
            predictedDowntime: failProb > 0.7 ? 5.0 + (failProb * 10.0) : 0,
            alternativeInterface: alt?.name,
            timestamp: Date()
        )
    }

    private func calculateSignalScore(_ snapshot: NetworkSnapshot) -> Double {
        var score = 0.0
        if snapshot.status == .satisfied { score += 0.5 }
        if snapshot.supportsIPv4 { score += 0.15 }
        if snapshot.supportsIPv6 { score += 0.1 }
        if snapshot.supportsDNS { score += 0.15 }
        if !snapshot.isExpensive { score += 0.05 }
        if !snapshot.isConstrained { score += 0.05 }
        return score
    }

    private func calculateTrend() -> Double {
        guard signalHistory.count >= 10 else { return 0 }
        let recent = Array(signalHistory.suffix(10))
        let first = recent.prefix(5).reduce(0, +) / 5.0
        let last = recent.suffix(5).reduce(0, +) / 5.0
        return last - first
    }

    private func calculateVolatility() -> Double {
        guard signalHistory.count >= 5 else { return 0 }
        let recent = Array(signalHistory.suffix(10))
        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(recent.count)
        return min(1.0, variance * 4)
    }
}
