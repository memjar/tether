import Foundation
import Network

public final class BeamServer {
    private let port: UInt16
    private let store: BeamStore
    private let manifest: BeamManifest
    private let config: BeamConfig
    private let events: BeamEventBus
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "diy.tether.beam.server")

    public init(port: UInt16, store: BeamStore, manifest: BeamManifest, config: BeamConfig, events: BeamEventBus) {
        self.port = port; self.store = store; self.manifest = manifest; self.config = config; self.events = events
    }

    public func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            NSLog("[Beam] failed to create listener: %@", error.localizedDescription)
            return
        }
        listener?.newConnectionHandler = { [weak self] conn in
            self?.handleConnection(conn)
        }
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready: NSLog("[Beam] server listening on port %d", self.port)
            case .failed(let err): NSLog("[Beam] server failed: %@", err.localizedDescription)
            default: break
            }
        }
        listener?.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        NSLog("[Beam] server stopped")
    }

    private func handleConnection(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, error in
            guard let self = self, let data = data, !data.isEmpty else {
                if let error = error { NSLog("[Beam] receive error: %@", error.localizedDescription) }
                conn.cancel()
                return
            }
            guard let raw = String(data: data, encoding: .utf8) else {
                self.send(conn: conn, status: 400, body: "{\"error\":\"invalid request\"}")
                return
            }
            let (method, path) = self.parseRequestLine(raw)
            let remoteAddr = self.remoteAddress(conn)
            self.route(conn: conn, method: method, path: path, raw: raw, remoteAddr: remoteAddr)
        }
    }

    private func remoteAddress(_ conn: NWConnection) -> String {
        if case .hostPort(let host, _) = conn.currentPath?.remoteEndpoint {
            return "\(host)"
        }
        return "unknown"
    }

    private func parseRequestLine(_ raw: String) -> (String, String) {
        guard let line = raw.split(separator: "\r\n", maxSplits: 1).first else { return ("GET", "/") }
        let parts = line.split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]) : "GET"
        let path = parts.count > 1 ? String(parts[1]) : "/"
        return (method, path)
    }

    private func extractBody(_ raw: String) -> String? {
        guard let range = raw.range(of: "\r\n\r\n") else { return nil }
        let body = String(raw[range.upperBound...])
        return body.isEmpty ? nil : body
    }

    private func route(conn: NWConnection, method: String, path: String, raw: String, remoteAddr: String) {
        if !config.apiKey.isEmpty && path != "/health" {
            let authOk = raw.contains("X-API-Key: \(config.apiKey)") || raw.contains("Authorization: Bearer \(config.apiKey)")
            if !authOk && method != "GET" {
                send(conn: conn, status: 401, body: "{\"error\":\"unauthorized\"}")
                return
            }
        }

        switch (method, path) {
        case ("GET", "/health"):
            let builds = store.list()
            let identity = BeamIdentity.current()
            send(conn: conn, status: 200, body: "{\"status\":\"ok\",\"service\":\"beam\",\"pin\":\"\(identity.pin)\",\"hostname\":\"\(identity.hostname)\",\"builds\":\(builds.count),\"port\":\(port)}")

        case ("GET", "/builds"):
            let builds = store.list()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(builds), let json = String(data: data, encoding: .utf8) {
                send(conn: conn, status: 200, body: json)
            } else {
                send(conn: conn, status: 500, body: "{\"error\":\"encode failed\"}")
            }

        case ("GET", _) where path.hasPrefix("/builds/") && path.hasSuffix("/manifest.plist"):
            let idStr = extractBuildId(from: path)
            guard let uuid = UUID(uuidString: idStr), let build = store.get(id: uuid) else {
                send(conn: conn, status: 404, body: "{\"error\":\"not found\"}")
                return
            }
            let plist = manifest.plist(for: build, baseURL: config.baseURL)
            send(conn: conn, status: 200, body: plist, contentType: "application/xml")

        case ("GET", _) where path.hasPrefix("/builds/") && path.hasSuffix("/download"):
            let idStr = extractBuildId(from: path)
            guard let uuid = UUID(uuidString: idStr), let build = store.get(id: uuid), let filePath = store.filePath(for: build) else {
                send(conn: conn, status: 404, body: "{\"error\":\"not found\"}")
                return
            }
            guard let fileData = try? Data(contentsOf: filePath) else {
                send(conn: conn, status: 500, body: "{\"error\":\"file read failed\"}")
                return
            }
            events.emit(.buildDownloaded, payload: [
                "id": build.id.uuidString,
                "name": build.name,
                "version": build.version,
                "platform": build.platform.rawValue,
                "remoteAddr": remoteAddr
            ])
            let filename = filePath.lastPathComponent
            sendBinary(conn: conn, data: fileData, filename: filename)

        case ("GET", _) where path.hasPrefix("/builds/"):
            let idStr = extractBuildId(from: path)
            guard let uuid = UUID(uuidString: idStr), let build = store.get(id: uuid) else {
                send(conn: conn, status: 404, body: "{\"error\":\"not found\"}")
                return
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(build), let json = String(data: data, encoding: .utf8) {
                let installURL = manifest.installURL(for: build, baseURL: config.baseURL)
                let enriched = String(json.dropLast()) + ",\"installURL\":\"\(installURL)\"}"
                send(conn: conn, status: 200, body: enriched)
            } else {
                send(conn: conn, status: 500, body: "{\"error\":\"encode failed\"}")
            }

        case ("POST", "/webhooks"):
            guard let body = extractBody(raw),
                  let data = body.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let url = obj["url"] as? String else {
                send(conn: conn, status: 400, body: "{\"error\":\"url required\"}")
                return
            }
            let label = obj["label"] as? String ?? ""
            let headers = obj["headers"] as? [String: String] ?? [:]
            let eventTypes: [BeamEventType]
            if let evts = obj["events"] as? [String] {
                eventTypes = evts.compactMap { BeamEventType(rawValue: $0) }
            } else {
                eventTypes = []
            }
            let hook = BeamWebhook(url: url, events: eventTypes, headers: headers, label: label)
            events.addWebhook(hook)
            send(conn: conn, status: 201, body: "{\"id\":\"\(hook.id.uuidString)\",\"status\":\"registered\"}")

        case ("GET", "/webhooks"):
            let hooks = events.listWebhooks()
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(hooks), let json = String(data: data, encoding: .utf8) {
                send(conn: conn, status: 200, body: json)
            } else {
                send(conn: conn, status: 200, body: "[]")
            }

        case ("DELETE", _) where path.hasPrefix("/webhooks/"):
            let idStr = String(path.split(separator: "/").last ?? "")
            guard let uuid = UUID(uuidString: idStr) else {
                send(conn: conn, status: 400, body: "{\"error\":\"invalid id\"}")
                return
            }
            events.removeWebhook(id: uuid)
            send(conn: conn, status: 200, body: "{\"status\":\"removed\"}")

        case ("OPTIONS", _):
            send(conn: conn, status: 200, body: "")

        default:
            send(conn: conn, status: 404, body: "{\"error\":\"not found\",\"path\":\"\(path)\"}")
        }
    }

    private func extractBuildId(from path: String) -> String {
        let parts = path.split(separator: "/").map(String.init)
        guard let idx = parts.firstIndex(of: "builds"), idx + 1 < parts.count else { return "" }
        return parts[idx + 1]
    }

    private func send(conn: NWConnection, status: Int, body: String, contentType: String = "application/json") {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        default: statusText = "Error"
        }
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, DELETE, OPTIONS\r\nAccess-Control-Allow-Headers: X-API-Key, Authorization, Content-Type\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: response.data(using: .utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private func sendBinary(conn: NWConnection, data: Data, filename: String) {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"\(filename)\"\r\nContent-Length: \(data.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var full = header.data(using: .utf8)!
        full.append(data)
        conn.send(content: full, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }
}
