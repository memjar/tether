import Foundation
import Combine

public final class Beam: ObservableObject {
    @Published public private(set) var availableBuilds: [BeamBuild] = []
    @Published public private(set) var discoveredPeers: [BeamPeer] = []
    @Published public private(set) var isRunning = false

    public let identity: BeamIdentity
    public let events: BeamEventBus

    private let config: BeamConfig
    private let store: BeamStore
    private let server: BeamServer
    private let discovery: BeamDiscovery
    private let manifest = BeamManifest()

    public init(config: BeamConfig = .default) {
        self.config = config
        self.identity = BeamIdentity.current()
        self.events = BeamEventBus(
            deviceId: identity.pin,
            ntfyTopic: config.ntfyTopic.isEmpty ? nil : config.ntfyTopic
        )
        self.store = BeamStore(directory: config.storageDir)
        self.server = BeamServer(port: config.port, store: store, manifest: manifest, config: config, events: events)
        self.discovery = BeamDiscovery(port: config.port)

        for url in config.webhookURLs {
            events.addWebhook(BeamWebhook(url: url, label: URL(string: url)?.host ?? url))
        }

        discovery.onPeerFound = { [weak self] peer in
            guard let self = self else { return }
            DispatchQueue.main.async { self.discoveredPeers.append(peer) }
            self.events.emit(.peerDiscovered, payload: ["name": peer.name, "host": peer.host])
        }
        discovery.onPeerLost = { [weak self] id in
            guard let self = self else { return }
            DispatchQueue.main.async { self.discoveredPeers.removeAll { $0.id == id } }
            self.events.emit(.peerLost, payload: ["id": id])
        }
    }

    public func start() {
        server.start()
        discovery.startAdvertising()
        discovery.startBrowsing()
        refreshBuilds()
        DispatchQueue.main.async { self.isRunning = true }
        events.emit(.serverStarted, payload: identity.toDict().merging(["port": "\(config.port)"], uniquingKeysWith: { _, b in b }))
        NSLog("[Beam] started — PIN %@ port %d store %@", identity.pin, config.port, config.storageDir.path)
    }

    public func stop() {
        server.stop()
        discovery.stopAdvertising()
        discovery.stopBrowsing()
        DispatchQueue.main.async { self.isRunning = false }
        events.emit(.serverStopped, payload: ["pin": identity.pin])
    }

    public func upload(fileAt url: URL, name: String, version: String, build: String, platform: BeamPlatform, ghostMode: Bool = false) throws -> BeamBuild {
        let data = try Data(contentsOf: url)
        guard let record = store.save(fileData: data, name: name, version: version, build: build, bundleId: config.allowedBundleIds.first ?? "ca.axetechnologies.tether", platform: platform, ghostMode: ghostMode) else {
            NSLog("[Beam] upload failed for %@", name)
            throw BeamError.saveFailed
        }
        refreshBuilds()
        events.emit(.buildUploaded, payload: [
            "id": record.id.uuidString,
            "name": name,
            "version": version,
            "build": build,
            "platform": platform.rawValue,
            "size": "\(record.fileSize)",
            "sha256": record.sha256
        ])
        return record
    }

    public func builds() -> [BeamBuild] { store.list() }

    public func installURL(for buildId: UUID) -> String? {
        guard let build = store.get(id: buildId) else { return nil }
        return manifest.installURL(for: build, baseURL: config.baseURL)
    }

    public func downloadURL(for buildId: UUID) -> String? {
        guard let build = store.get(id: buildId) else { return nil }
        return "\(config.baseURL)/builds/\(build.id.uuidString)/download"
    }

    public func deleteBuild(id: UUID) -> Bool {
        let ok = store.delete(id: id)
        if ok {
            refreshBuilds()
            events.emit(.buildDeleted, payload: ["id": id.uuidString])
        }
        return ok
    }

    public func peers() -> [BeamPeer] { discovery.peers() }

    public func addWebhook(url: String, events: [BeamEventType] = [], headers: [String: String] = [:], label: String = "") {
        self.events.addWebhook(BeamWebhook(url: url, events: events, headers: headers, label: label))
    }

    public func removeWebhook(id: UUID) {
        events.removeWebhook(id: id)
    }

    public func webhooks() -> [BeamWebhook] {
        events.listWebhooks()
    }

    private func refreshBuilds() {
        let builds = store.list()
        DispatchQueue.main.async { self.availableBuilds = builds }
    }
}

public enum BeamError: Error {
    case saveFailed
    case notFound
    case unauthorized
}
