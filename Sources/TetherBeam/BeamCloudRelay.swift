import Foundation

public final class BeamCloudRelay {
    public static let shared = BeamCloudRelay()

    public enum State: String { case disconnected, registering, connected, reconnecting }

    private let relayBase = "https://beam.tether.diy"
    private let wsBase = "wss://beam.tether.diy"
    private var wsTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var beaconId: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let queue = DispatchQueue(label: "diy.tether.beam.cloud")
    private var pingTimer: Timer?
    private var onMessage: ((String, [String: Any]) -> Void)?
    private var onStateChange: ((State) -> Void)?

    public private(set) var state: State = .disconnected {
        didSet { onStateChange?(state) }
    }

    private init() {}

    public func configure(onMessage: @escaping (String, [String: Any]) -> Void, onStateChange: ((State) -> Void)? = nil) {
        self.onMessage = onMessage
        self.onStateChange = onStateChange
    }

    public func registerBeacon(beaconId: String, deviceName: String, capabilities: [String] = ["wifi", "hotspot", "chat"], sharingType: String = "wifi", maxClients: Int = 8, apiKey: String = "") {
        self.beaconId = beaconId
        state = .registering

        guard let url = URL(string: "\(relayBase)/beacon/register") else { return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }

        let body: [String: Any] = [
            "beacon_id": beaconId,
            "device_name": deviceName,
            "capabilities": capabilities,
            "sharing_type": sharingType,
            "max_clients": maxClients
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            guard let self = self else { return }
            if let err = err {
                NSLog("[BeamCloud] register failed: %@", err.localizedDescription)
                self.state = .disconnected
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool == true else {
                NSLog("[BeamCloud] register rejected")
                self.state = .disconnected
                return
            }
            NSLog("[BeamCloud] registered beacon %@", beaconId)
            self.connectWebSocket()
        }.resume()
    }

    public func unregisterBeacon(apiKey: String = "") {
        guard let beaconId = beaconId else { return }
        guard let url = URL(string: "\(relayBase)/beacon/\(beaconId)") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "DELETE"
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
        disconnect()
        NSLog("[BeamCloud] unregistered beacon %@", beaconId)
    }

    public func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        beaconId = nil
        reconnectAttempts = 0
        state = .disconnected
    }

    public func send(type: String, payload: [String: Any] = [:]) {
        guard state == .connected else { return }
        var msg = payload
        msg["type"] = type
        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              let text = String(data: data, encoding: .utf8) else { return }
        wsTask?.send(.string(text)) { err in
            if let err = err { NSLog("[BeamCloud] send error: %@", err.localizedDescription) }
        }
    }

    private func connectWebSocket() {
        guard let beaconId = beaconId else { return }
        let identity = BeamIdentity.current()
        let urlStr = "\(wsBase)/relay/\(beaconId)?role=host&name=\(identity.hostname.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? identity.hostname)"
        guard let url = URL(string: urlStr) else { return }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        session = URLSession(configuration: config)
        wsTask = session?.webSocketTask(with: url)
        wsTask?.resume()

        startReceiving()
        startPingTimer()
        reconnectAttempts = 0
        state = .connected
        NSLog("[BeamCloud] WebSocket connected to %@", beaconId)
    }

    private func startReceiving() {
        wsTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String {
                        self.onMessage?(type, json)
                    }
                default: break
                }
                self.startReceiving()
            case .failure(let error):
                NSLog("[BeamCloud] receive error: %@", error.localizedDescription)
                self.handleDisconnect()
            }
        }
    }

    private func startPingTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer?.invalidate()
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.send(type: "ping")
            }
        }
    }

    private func handleDisconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        wsTask = nil

        guard beaconId != nil, reconnectAttempts < maxReconnectAttempts else {
            state = .disconnected
            return
        }

        state = .reconnecting
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts * reconnectAttempts), 30.0)
        NSLog("[BeamCloud] reconnecting in %.0fs (attempt %d)", delay, reconnectAttempts)

        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connectWebSocket()
        }
    }
}
