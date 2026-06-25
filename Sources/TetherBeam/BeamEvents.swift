import Foundation

public enum BeamEventType: String, Codable, CaseIterable {
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

public protocol BeamPushTarget {
    var targetId: String { get }
    func push(event: BeamEvent)
}

public final class BeamFleetPush: BeamPushTarget {
    public let targetId: String
    private let endpoint: String

    public init(name: String, endpoint: String) {
        self.targetId = name
        self.endpoint = endpoint
    }

    public func push(event: BeamEvent) {
        guard let url = URL(string: "\(endpoint)/events") else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(event) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("TetherBeam/1.0", forHTTPHeaderField: "User-Agent")
        req.httpBody = body
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                NSLog("[Beam] push to %@ failed: %@", self.targetId, err.localizedDescription)
            }
        }.resume()
    }
}

public final class BeamEventBus {
    private var webhooks: [BeamWebhook] = []
    private var pushTargets: [BeamPushTarget] = []
    private let deviceId: String
    private let queue = DispatchQueue(label: "diy.tether.beam.events")
    private let logDir: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public init(deviceId: String) {
        self.deviceId = deviceId
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.logDir = appSupport.appendingPathComponent("Tether/Beam/events", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
    }

    public func addWebhook(_ webhook: BeamWebhook) {
        queue.sync { webhooks.append(webhook) }
        NSLog("[Beam] webhook registered: %@ -> %@", webhook.label.isEmpty ? webhook.id.uuidString : webhook.label, webhook.url)
    }

    public func removeWebhook(id: UUID) {
        queue.sync { webhooks.removeAll { $0.id == id } }
    }

    public func listWebhooks() -> [BeamWebhook] {
        queue.sync { webhooks }
    }

    public func addPushTarget(_ target: BeamPushTarget) {
        queue.sync { pushTargets.append(target) }
        NSLog("[Beam] push target added: %@", target.targetId)
    }

    public func removePushTarget(id: String) {
        queue.sync { pushTargets.removeAll { $0.targetId == id } }
    }

    public func emit(_ type: BeamEventType, payload: [String: String] = [:]) {
        let event = BeamEvent(type: type, deviceId: deviceId, payload: payload)
        NSLog("[Beam] event: %@ %@", type.rawValue, payload.description)

        queue.async { [weak self] in
            guard let self = self else { return }
            self.persist(event)
            for target in self.pushTargets {
                target.push(event: event)
            }
            let targets = self.webhooks.filter { $0.matches(type) }
            for hook in targets {
                self.fireWebhook(hook, event: event)
            }
        }
    }

    public func recentEvents(limit: Int = 50) -> [BeamEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = logDir.appendingPathComponent("beam_\(formatter.string(from: Date())).jsonl")
        guard let data = try? String(contentsOf: today, encoding: .utf8) else { return [] }
        let lines = data.split(separator: "\n").suffix(limit)
        return lines.compactMap { line in
            try? decoder.decode(BeamEvent.self, from: Data(line.utf8))
        }
    }

    private func persist(_ event: BeamEvent) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let path = logDir.appendingPathComponent("beam_\(formatter.string(from: Date())).jsonl")
        guard let line = try? encoder.encode(event), let str = String(data: line, encoding: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: path) {
            handle.seekToEndOfFile()
            handle.write(Data((str + "\n").utf8))
            handle.closeFile()
        } else {
            try? (str + "\n").write(to: path, atomically: true, encoding: .utf8)
        }
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
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                NSLog("[Beam] webhook %@ failed: %@", hook.label, err.localizedDescription)
            } else if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
                NSLog("[Beam] webhook %@ returned %d", hook.label, http.statusCode)
            }
        }.resume()
    }
}
