import Foundation
import TetherEngine
import TetherAI

public final class TetherAPIServer: @unchecked Sendable {
    private let monitor: NetworkMonitor
    private let sharing: InternetSharingController
    private let predictor: NetworkPredictor
    private let failover: FailoverEngine
    private let port: UInt16

    public init(
        monitor: NetworkMonitor,
        sharing: InternetSharingController,
        predictor: NetworkPredictor,
        failover: FailoverEngine,
        port: UInt16 = 8421
    ) {
        self.monitor = monitor
        self.sharing = sharing
        self.predictor = predictor
        self.failover = failover
        self.port = port
    }

    public func start() async throws {
        print("[TetherAPI] API server ready on port \(port)")
        print("[TetherAPI] Endpoints:")
        print("  GET  /api/v1/status")
        print("  GET  /api/v1/clients")
        print("  GET  /api/v1/prediction")
        print("  GET  /api/v1/interfaces")
        print("  GET  /api/v1/sources")
        print("  POST /api/v1/share/start")
        print("  POST /api/v1/share/stop")
        print("  POST /api/v1/diagnose")
    }

    public func handleRequest(method: String, path: String, body: [String: Any]? = nil) async -> [String: Any] {
        switch (method, path) {
        case ("GET", "/api/v1/status"):
            return statusResponse()
        case ("GET", "/api/v1/interfaces"):
            return interfacesResponse()
        case ("GET", "/api/v1/sources"):
            return sourcesResponse()
        case ("GET", "/api/v1/prediction"):
            return predictionResponse()
        case ("GET", "/api/v1/clients"):
            return clientsResponse()
        case ("POST", "/api/v1/share/start"):
            return await startSharingResponse(body: body)
        case ("POST", "/api/v1/share/stop"):
            return await stopSharingResponse()
        default:
            return ["error": "Not found", "path": path]
        }
    }

    private func statusResponse() -> [String: Any] {
        let snapshot = monitor.latestSnapshot
        return [
            "sharing": sharing.state.rawValue,
            "network": snapshot?.statusLabel ?? "unknown",
            "clients": sharing.connectedClients,
            "expensive": snapshot?.isExpensive ?? false,
            "primary": snapshot?.primaryInterface?.name ?? "none",
            "ssid": sharing.config.wifiConfig.ssid,
            "sourceInterface": sharing.config.sourceInterface,
            "shareVia": sharing.config.shareVia.rawValue
        ]
    }

    private func interfacesResponse() -> [String: Any] {
        let snapshot = monitor.latestSnapshot
        let ifaces = snapshot?.interfaces.map { iface in
            [
                "name": iface.name,
                "type": iface.typeLabel,
                "active": iface.isActive
            ] as [String: Any]
        } ?? []
        return ["interfaces": ifaces]
    }

    private func sourcesResponse() -> [String: Any] {
        let sources = sharing.detectSourceInterfaces()
        let list = sources.map { src in
            [
                "name": src.name,
                "kind": src.kind.rawValue,
                "ip": src.ip
            ] as [String: Any]
        }
        let auto = sharing.autoSelectSource()
        return [
            "sources": list,
            "recommended": auto?.name ?? "none",
            "recommendedKind": auto?.kind.rawValue ?? "none"
        ]
    }

    private func clientsResponse() -> [String: Any] {
        let clients = sharing.queryClients()
        let list = clients.map { c in
            [
                "mac": c.mac,
                "ip": c.ip,
                "hostname": c.hostname ?? "unknown",
            ] as [String: Any]
        }
        return [
            "clients": list,
            "count": clients.count
        ]
    }

    private func predictionResponse() -> [String: Any] {
        guard let snapshot = monitor.latestSnapshot else {
            return ["error": "No network data"]
        }
        let result = predictor.feed(snapshot: snapshot)
        return [
            "failureProbability": result.failureProbability,
            "recommendedAction": result.recommendedAction.rawValue,
            "predictedDowntime": result.predictedDowntime,
            "alternativeInterface": result.alternativeInterface ?? "none"
        ]
    }

    private func startSharingResponse(body: [String: Any]?) async -> [String: Any] {
        let ssid = body?["ssid"] as? String ?? "Tether"
        let password = body?["password"] as? String ?? ""
        let source = body?["source"] as? String

        let sourceIface = source ?? sharing.autoSelectSource()?.name ?? sharing.config.sourceInterface
        let config = SharingConfig(
            sourceInterface: sourceIface,
            shareVia: .wifi,
            wifiConfig: WiFiAPConfig(ssid: ssid, password: password, security: .wpa2)
        )
        sharing.updateConfig(config)

        do {
            try await sharing.startSharing()
            return ["status": "active", "ssid": ssid, "source": sourceIface]
        } catch {
            return ["status": "error", "error": error.localizedDescription]
        }
    }

    private func stopSharingResponse() async -> [String: Any] {
        do {
            try await sharing.stopSharing()
            return ["status": "stopped"]
        } catch {
            return ["status": "error", "error": error.localizedDescription]
        }
    }
}
