import Foundation
import Network
import TetherEngine
import TetherAI

public final class TetherAPIServer: @unchecked Sendable {
    private let monitor: NetworkMonitor
    private let sharing: InternetSharingController
    private let clients: ClientManager
    private let predictor: NetworkPredictor
    private let failover: FailoverEngine
    private let port: UInt16

    private var httpListener: NWListener?
    private var controlListener: NWListener?
    private var controlConnections: [NWConnection] = []
    private let queue = DispatchQueue(label: "diy.tether.api")

    public init(
        monitor: NetworkMonitor,
        sharing: InternetSharingController,
        clients: ClientManager,
        predictor: NetworkPredictor,
        failover: FailoverEngine,
        port: UInt16 = 8421
    ) {
        self.monitor = monitor
        self.sharing = sharing
        self.clients = clients
        self.predictor = predictor
        self.failover = failover
        self.port = port
    }

    // MARK: - Lifecycle

    public func start() async throws {
        try startHTTPListener()
        try startControlListener()
        print("[TetherAPI] API server live on port \(port)")
        print("[TetherAPI] Bonjour: _tether._tcp advertised")
    }

    public func stop() {
        httpListener?.cancel()
        controlListener?.cancel()
        controlConnections.forEach { $0.cancel() }
        controlConnections.removeAll()
    }

    // MARK: - HTTP Listener (port 8421)

    private func startHTTPListener() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.stateUpdateHandler = { state in
            if case .failed(let err) = state { print("[TetherAPI] HTTP listener failed: \(err)") }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.handleHTTPConnection(conn)
        }
        listener.start(queue: queue)
        httpListener = listener
    }

    // MARK: - Bonjour Control Listener (_tether._tcp)

    private func startControlListener() throws {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let listener = try NWListener(using: params)
        listener.service = NWListener.Service(name: "Tether", type: "_tether._tcp")
        listener.stateUpdateHandler = { state in
            if case .ready = state, let p = listener.port {
                print("[TetherAPI] Control socket on port \(p.rawValue) (Bonjour)")
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.handleControlConnection(conn)
        }
        listener.start(queue: queue)
        controlListener = listener
    }

    // MARK: - HTTP Connection Handling

    private func handleHTTPConnection(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else {
                conn.cancel()
                return
            }
            guard let raw = String(data: data, encoding: .utf8) else {
                self.sendHTTPResponse(conn, status: 400, body: ["error": "Bad request"])
                return
            }

            let (method, path, bodyData) = self.parseHTTPRequest(raw)
            var jsonBody: [String: Any]?
            if let bd = bodyData, let parsed = try? JSONSerialization.jsonObject(with: bd) as? [String: Any] {
                jsonBody = parsed
            }
            let body = jsonBody

            Task {
                let result = await self.handleRequest(method: method, path: path, body: body)
                let statusCode = result["error"] != nil ? 404 : 200
                self.sendHTTPResponse(conn, status: statusCode, body: result)
            }
        }
    }

    private func parseHTTPRequest(_ raw: String) -> (method: String, path: String, body: Data?) {
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return ("GET", "/", nil) }
        let parts = requestLine.components(separatedBy: " ")
        let method = parts.count > 0 ? parts[0] : "GET"
        let path = parts.count > 1 ? parts[1] : "/"

        if let bodyStart = raw.range(of: "\r\n\r\n") {
            let bodyStr = String(raw[bodyStart.upperBound...])
            if !bodyStr.isEmpty { return (method, path, bodyStr.data(using: .utf8)) }
        }
        return (method, path, nil)
    }

    private func sendHTTPResponse(_ conn: NWConnection, status: Int, body: [String: Any]) {
        let statusText = status == 200 ? "OK" : "Not Found"
        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
        let header = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(jsonData.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var response = header.data(using: .utf8)!
        response.append(jsonData)
        conn.send(content: response, completion: .contentProcessed({ _ in conn.cancel() }))
    }

    // MARK: - Control Socket (Carmack JSON protocol)

    private func handleControlConnection(_ conn: NWConnection) {
        conn.start(queue: queue)
        controlConnections.append(conn)
        conn.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { self?.controlConnections.removeAll { $0 === conn } }
            if case .failed = state { conn.cancel() }
        }
        readControlMessage(conn)
    }

    private func readControlMessage(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.processControlMessage(data, on: conn)
            }
            if isComplete || error != nil {
                conn.cancel()
            } else {
                self.readControlMessage(conn)
            }
        }
    }

    private func processControlMessage(_ data: Data, on conn: NWConnection) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else {
            let err = try? JSONSerialization.data(withJSONObject: ["error": "invalid command"])
            conn.send(content: err, completion: .contentProcessed({ _ in }))
            return
        }

        Task {
            let response: [String: Any]
            switch action {
            case "status":
                let status = statusResponse()
                let clients = clientsResponse()
                let devices = (clients["clients"] as? [[String: Any]])?.map { c -> [String: Any] in
                    var d = c
                    d["id"] = c["mac"]
                    d["name"] = c["hostname"] ?? c["mac"]
                    d["band"] = "Unknown"
                    d["rssi"] = -50
                    d["rxBytes"] = 0
                    d["txBytes"] = 0
                    d["isPaused"] = false
                    d["firstSeen"] = ISO8601DateFormatter().string(from: Date())
                    d["lastSeen"] = ISO8601DateFormatter().string(from: Date())
                    return d
                } ?? []
                response = [
                    "active": status["sharing"] as? String == "active",
                    "info": [
                        "ssid": status["ssid"] ?? "Tether",
                        "source": status["sourceInterface"] ?? "en0",
                        "subnet": "192.168.234.0/24",
                        "security": "WPA2 Personal",
                        "deviceCount": clients["count"] ?? 0,
                        "uptime": 0,
                        "downloadSpeed": 0,
                        "uploadSpeed": 0,
                        "latency": 0
                    ] as [String: Any],
                    "devices": devices
                ]
            case "pause":
                if let device = json["device"] as? String {
                    try? clients.pauseClient(mac: device)
                }
                response = ["ok": true]
            case "resume":
                if let device = json["device"] as? String {
                    try? clients.resumeClient(mac: device)
                }
                response = ["ok": true]
            case "kick":
                if let device = json["device"] as? String {
                    clients.kickClient(mac: device)
                }
                response = ["ok": true]
            default:
                response = ["error": "unknown action: \(action)"]
            }

            if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                conn.send(content: responseData, completion: .contentProcessed({ _ in }))
            }
        }
    }

    // MARK: - Broadcast to all control connections

    public func broadcastStatus() {
        let status = statusResponse()
        guard let data = try? JSONSerialization.data(withJSONObject: status) else { return }
        for conn in controlConnections {
            conn.send(content: data, completion: .contentProcessed({ _ in }))
        }
    }

    // MARK: - HTTP Request Router

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
        case ("POST", "/api/v1/diagnose"):
            return diagnoseResponse()
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

    private func diagnoseResponse() -> [String: Any] {
        let snapshot = monitor.latestSnapshot
        let sources = sharing.detectSourceInterfaces()
        let sharingRunning = sharing.isInternetSharingRunning()
        return [
            "networkReachable": snapshot?.status == .satisfied,
            "interfaceCount": snapshot?.interfaces.count ?? 0,
            "sourceCount": sources.count,
            "sharingDaemonRunning": sharingRunning,
            "sharingState": sharing.state.rawValue,
            "ipv4": snapshot?.supportsIPv4 ?? false,
            "ipv6": snapshot?.supportsIPv6 ?? false,
            "dns": snapshot?.supportsDNS ?? false,
            "expensive": snapshot?.isExpensive ?? false,
            "constrained": snapshot?.isConstrained ?? false
        ]
    }
}
