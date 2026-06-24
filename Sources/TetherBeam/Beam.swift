import Foundation
import Combine

public final class Beam: ObservableObject {
    @Published public private(set) var availableBuilds: [BeamBuild] = []
    @Published public private(set) var discoveredPeers: [BeamPeer] = []
    @Published public private(set) var isRunning = false

    private let config: BeamConfig
    private let store: BeamStore
    private let server: BeamServer
    private let discovery: BeamDiscovery
    private let manifest = BeamManifest()

    public init(config: BeamConfig = .default) {
        self.config = config
        self.store = BeamStore(directory: config.storageDir)
        self.server = BeamServer(port: config.port, store: store, manifest: manifest, config: config)
        self.discovery = BeamDiscovery(port: config.port)

        discovery.onPeerFound = { [weak self] peer in
            DispatchQueue.main.async { self?.discoveredPeers.append(peer) }
        }
        discovery.onPeerLost = { [weak self] id in
            DispatchQueue.main.async { self?.discoveredPeers.removeAll { $0.id == id } }
        }
    }

    public func start() {
        server.start()
        discovery.startAdvertising()
        discovery.startBrowsing()
        refreshBuilds()
        DispatchQueue.main.async { self.isRunning = true }
        NSLog("[Beam] started — port %d, store %@", config.port, config.storageDir.path)
    }

    public func stop() {
        server.stop()
        discovery.stopAdvertising()
        discovery.stopBrowsing()
        DispatchQueue.main.async { self.isRunning = false }
    }

    public func upload(fileAt url: URL, name: String, version: String, build: String, platform: BeamPlatform, ghostMode: Bool = false) throws -> BeamBuild {
        let data = try Data(contentsOf: url)
        guard let record = store.save(fileData: data, name: name, version: version, build: build, bundleId: config.allowedBundleIds.first ?? "ca.axetechnologies.tether", platform: platform, ghostMode: ghostMode) else {
            NSLog("[Beam] upload failed for %@", name)
            throw BeamError.saveFailed
        }
        refreshBuilds()
        NSLog("[Beam] uploaded %@ v%@ (%@) — %lld bytes", name, version, platform.rawValue, record.fileSize)
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
        if ok { refreshBuilds() }
        return ok
    }

    public func peers() -> [BeamPeer] { discovery.peers() }

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
