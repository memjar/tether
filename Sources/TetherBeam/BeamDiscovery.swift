import Foundation
import Network

public struct BeamPeer: Identifiable {
    public let id: String
    public let name: String
    public let host: String
    public let port: UInt16

    public init(id: String, name: String, host: String, port: UInt16) {
        self.id = id; self.name = name; self.host = host; self.port = port
    }
}

public final class BeamDiscovery {
    public var onPeerFound: ((BeamPeer) -> Void)?
    public var onPeerLost: ((String) -> Void)?

    private var advertiser: NWListener?
    private var browser: NWBrowser?
    private let port: UInt16
    private let queue = DispatchQueue(label: "diy.tether.beam.discovery")
    private var knownPeers: [String: BeamPeer] = [:]

    public init(port: UInt16) {
        self.port = port
    }

    public func startAdvertising() {
        do {
            let params = NWParameters.tcp
            advertiser = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            advertiser?.service = NWListener.Service(name: Host.current().localizedName ?? "Beam", type: "_tether-beam._tcp")
            advertiser?.stateUpdateHandler = { state in
                if case .failed(let err) = state { NSLog("[Beam] advertise failed: %@", err.localizedDescription) }
            }
            advertiser?.start(queue: queue)
            NSLog("[Beam] advertising on _tether-beam._tcp port %d", port)
        } catch {
            NSLog("[Beam] failed to start advertiser: %@", error.localizedDescription)
        }
    }

    public func stopAdvertising() {
        advertiser?.cancel()
        advertiser = nil
    }

    public func startBrowsing() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_tether-beam._tcp", domain: nil)
        browser = NWBrowser(for: descriptor, using: .tcp)
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            for change in changes {
                switch change {
                case .added(let result):
                    if case .service(let name, _, _, _) = result.endpoint {
                        let peer = BeamPeer(id: name, name: name, host: name, port: self.port)
                        self.knownPeers[name] = peer
                        self.onPeerFound?(peer)
                    }
                case .removed(let result):
                    if case .service(let name, _, _, _) = result.endpoint {
                        self.knownPeers.removeValue(forKey: name)
                        self.onPeerLost?(name)
                    }
                default: break
                }
            }
        }
        browser?.stateUpdateHandler = { state in
            if case .failed(let err) = state { NSLog("[Beam] browse failed: %@", err.localizedDescription) }
        }
        browser?.start(queue: queue)
        NSLog("[Beam] browsing for _tether-beam._tcp peers")
    }

    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    public func peers() -> [BeamPeer] {
        Array(knownPeers.values)
    }
}
