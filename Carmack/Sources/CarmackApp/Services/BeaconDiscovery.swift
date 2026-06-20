import Foundation
import Network
import Combine

final class BeaconDiscovery: ObservableObject {
    @Published var isConnected = false
    @Published var status: BeaconStatus?
    @Published var discoveredHosts: [String] = []

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var pollTimer: Timer?

    private let serviceType = "_tether._tcp"
    private let decoder = JSONDecoder()

    func startDiscovery() {
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.discoveredHosts = results.compactMap { result in
                    if case .service(let name, _, _, _) = result.endpoint { return name }
                    return nil
                }
                if let first = results.first { self?.connect(to: first.endpoint) }
            }
        }
        browser?.stateUpdateHandler = { _ in }
        browser?.start(queue: .main)
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        disconnect()
    }

    func connect(to endpoint: NWEndpoint) {
        disconnect()
        let params = NWParameters.tcp
        connection = NWConnection(to: endpoint, using: params)
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.startPolling()
                case .failed, .cancelled:
                    self?.isConnected = false
                    self?.stopPolling()
                default: break
                }
            }
        }
        connection?.start(queue: .main)
    }

    func disconnect() {
        stopPolling()
        connection?.cancel()
        connection = nil
        isConnected = false
        status = nil
    }

    func sendCommand(_ command: String) {
        guard let data = command.data(using: .utf8) else { return }
        connection?.send(content: data, completion: .contentProcessed({ _ in }))
    }

    func pauseDevice(id: String) { sendCommand("{\"action\":\"pause\",\"device\":\"\(id)\"}") }
    func resumeDevice(id: String) { sendCommand("{\"action\":\"resume\",\"device\":\"\(id)\"}") }
    func kickDevice(id: String) { sendCommand("{\"action\":\"kick\",\"device\":\"\(id)\"}") }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.fetchStatus()
        }
        fetchStatus()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func fetchStatus() {
        sendCommand("{\"action\":\"status\"}")
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let data = data, let self = self else { return }
            if let decoded = try? self.decoder.decode(BeaconStatus.self, from: data) {
                DispatchQueue.main.async { self.status = decoded }
            }
        }
    }
}
