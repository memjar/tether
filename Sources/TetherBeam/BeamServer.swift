import Foundation
import Network

public final class BeamServer {
    private let port: UInt16
    private let store: BeamStore
    private let manifest: BeamManifest
    private let config: BeamConfig
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "diy.tether.beam.server")

    public init(port: UInt16, store: BeamStore, manifest: BeamManifest, config: BeamConfig) {
        self.port = port; self.store = store; self.manifest = manifest; self.config = config
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
            self.route(conn: conn, method: method, path: path, raw: raw)
        }
    }

    private func parseRequestLine(_ raw: String) -> (String, String) {
        guard let line = raw.split(separator: "\r\n", maxSplits: 1).first else { return ("GET", "/") }
        let parts = line.split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]) : "GET"
        let path = parts.count > 1 ? String(parts[1]) : "/"
        return (method, path)
    }

    private func route(conn: NWConnection, method: String, path: String, raw: String) {
        switch (method, path) {
        case ("GET", "/health"):
            let builds = store.list()
            send(conn: conn, status: 200, body: "{\"status\":\"ok\",\"service\":\"beam\",\"builds\":\(builds.count),\"port\":\(port)}")

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
        let statusText = status == 200 ? "OK" : status == 404 ? "Not Found" : status == 400 ? "Bad Request" : "Error"
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: response.data(using: .utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private func sendBinary(conn: NWConnection, data: Data, filename: String) {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"\(filename)\"\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
        var full = header.data(using: .utf8)!
        full.append(data)
        conn.send(content: full, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }
}
