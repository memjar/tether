import Foundation

public enum BeamEventType: String, Codable {
    case buildUploaded = "build.uploaded"
    case buildDownloaded = "build.downloaded"
    case buildDeleted = "build.deleted"
    case peerDiscovered = "peer.discovered"
    case peerLost = "peer.lost"
    case serverStarted = "server.started"
    case serverStopped = "server.stopped"
}

public struct BeamEvent: Codable {
    public let type: BeamEventType
    public let timestamp: Date
    public let deviceId: String
    public let payload: [String: String]

    public init(type: BeamEventType, deviceId: String, payload: [String: String] = [:]) {
        self.type = type
        self.timestamp = Date()
        self.deviceId = deviceId
        self.payload = payload
    }
}

public struct BeamWebhook: Codable, Identifiable {
    public let id: UUID
    public let url: String
    public let events: [BeamEventType]
    public let headers: [String: String]
    public let label: String

    public init(url: String, events: [BeamEventType] = [], headers: [String: String] = [:], label: String = "") {
        self.id = UUID()
        self.url = url
        self.events = events
        self.headers = headers
        self.label = label
    }

    public func matches(_ event: BeamEventType) -> Bool {
        events.isEmpty || events.contains(event)
    }
}

public final class BeamEventBus {
    private var webhooks: [BeamWebhook] = []
    private var ntfyTopic: String?
    private let deviceId: String
    private let queue = DispatchQueue(label: "diy.tether.beam.events")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public init(deviceId: String, ntfyTopic: String? = nil) {
        self.deviceId = deviceId
        self.ntfyTopic = ntfyTopic
    }

    public func addWebhook(_ webhook: BeamWebhook) {
        queue.sync { webhooks.append(webhook) }
        NSLog("[Beam] webhook registered: %@ → %@", webhook.label.isEmpty ? webhook.id.uuidString : webhook.label, webhook.url)
    }

    public func removeWebhook(id: UUID) {
        queue.sync { webhooks.removeAll { $0.id == id } }
    }

    public func listWebhooks() -> [BeamWebhook] {
        queue.sync { webhooks }
    }

    public func setNtfyTopic(_ topic: String?) {
        ntfyTopic = topic
    }

    public func emit(_ type: BeamEventType, payload: [String: String] = [:]) {
        let event = BeamEvent(type: type, deviceId: deviceId, payload: payload)
        NSLog("[Beam] event: %@ %@", type.rawValue, payload.description)

        queue.async { [weak self] in
            guard let self = self else { return }
            self.pushNtfy(event)
            let targets = self.webhooks.filter { $0.matches(type) }
            for hook in targets {
                self.fireWebhook(hook, event: event)
            }
        }
    }

    private func pushNtfy(_ event: BeamEvent) {
        guard let topic = ntfyTopic, !topic.isEmpty else { return }
        guard let url = URL(string: "https://ntfy.sh/\(topic)") else { return }

        let title: String
        let body: String
        switch event.type {
        case .buildUploaded:
            title = "Beam: Build Uploaded"
            body = "\(event.payload["name"] ?? "?") v\(event.payload["version"] ?? "?") (\(event.payload["platform"] ?? "?")) — \(event.payload["size"] ?? "?") bytes"
        case .buildDownloaded:
            title = "Beam: Build Downloaded"
            body = "\(event.payload["name"] ?? "?") v\(event.payload["version"] ?? "?") fetched by \(event.payload["remoteAddr"] ?? "unknown")"
        case .peerDiscovered:
            title = "Beam: Peer Found"
            body = "\(event.payload["name"] ?? "unknown") on LAN"
        case .buildDeleted:
            title = "Beam: Build Deleted"
            body = event.payload["id"] ?? "?"
        default:
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: .utf8)
        req.setValue(title, forHTTPHeaderField: "Title")
        req.setValue("3", forHTTPHeaderField: "Priority")
        URLSession.shared.dataTask(with: req) { _, _, err in
            if let err = err { NSLog("[Beam] ntfy error: %@", err.localizedDescription) }
        }.resume()
    }

    private func fireWebhook(_ hook: BeamWebhook, event: BeamEvent) {
        guard let url = URL(string: hook.url) else { return }
        guard let body = try? encoder.encode(event) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("TetherBeam/1.0", forHTTPHeaderField: "User-Agent")
        for (key, val) in hook.headers {
            req.setValue(val, forHTTPHeaderField: key)
        }
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                NSLog("[Beam] webhook %@ failed: %@", hook.label, err.localizedDescription)
            } else if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
                NSLog("[Beam] webhook %@ returned %d", hook.label, http.statusCode)
            }
        }.resume()
    }
}
