import Foundation
import MultipeerConnectivity
import Combine
import UIKit

private let kMeshService = "tether-mesh"

final class TetherMesh: NSObject, ObservableObject {
    @Published var connectedPeers: [MCPeerID] = []
    @Published var messages: [MeshMessage] = []
    @Published var droppedFiles: [DroppedFile] = []
    @Published var transferProgress: [String: Double] = [:]

    var peerCount: Int { connectedPeers.count }
    var displayName: String { myPeer.displayName }

    private let myPeer: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var progressObservers: [String: NSKeyValueObservation] = [:]

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let dropDir: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tether-drops")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override init() {
        myPeer = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    func start() {
        guard session == nil else { return }
        let s = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        session = s

        let adv = MCNearbyServiceAdvertiser(peer: myPeer, discoveryInfo: nil, serviceType: kMeshService)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        let brw = MCNearbyServiceBrowser(peer: myPeer, serviceType: kMeshService)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        progressObservers.removeAll()
        DispatchQueue.main.async {
            self.connectedPeers = []
            self.messages = []
            self.transferProgress = [:]
        }
    }

    func send(_ text: String) {
        let msg = MeshMessage(id: UUID(), sender: myPeer.displayName, body: text, timestamp: Date(), kind: .text)
        appendMessage(msg)
        broadcast(msg)
    }

    func sendFile(at url: URL) {
        guard let s = session, !s.connectedPeers.isEmpty else { return }
        let name = url.lastPathComponent

        let msg = MeshMessage(id: UUID(), sender: myPeer.displayName, body: name, timestamp: Date(), kind: .fileSent)
        appendMessage(msg)
        broadcast(msg)

        for (index, peer) in s.connectedPeers.enumerated() {
            let trackKey = s.connectedPeers.count > 1 ? "\(name).\(index)" : name
            let progress = s.sendResource(at: url, withName: name, toPeer: peer) { [weak self] error in
                if let error = error {
                    NSLog("[TetherMesh] sendResource to %@ failed: %@", peer.displayName, error.localizedDescription)
                }
                DispatchQueue.main.async {
                    self?.transferProgress.removeValue(forKey: trackKey)
                    self?.progressObservers.removeValue(forKey: trackKey)
                }
            }
            if let progress = progress {
                trackProgress(progress, key: trackKey)
            }
        }
    }

    private func broadcast(_ msg: MeshMessage) {
        guard let data = try? encoder.encode(msg),
              let s = session, !s.connectedPeers.isEmpty else { return }
        try? s.send(data, toPeers: s.connectedPeers, with: .reliable)
    }

    private func appendMessage(_ msg: MeshMessage) {
        DispatchQueue.main.async { self.messages.append(msg) }
    }

    private func trackProgress(_ progress: Progress, key: String) {
        let obs = progress.observe(\.fractionCompleted, options: [.new]) { [weak self] p, _ in
            DispatchQueue.main.async { self?.transferProgress[key] = p.fractionCompleted }
        }
        progressObservers[key] = obs
        DispatchQueue.main.async { self.transferProgress[key] = 0 }
    }
}

extension TetherMesh: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let kind: MeshMessage.Kind
        let body: String
        switch state {
        case .connected:    kind = .peerJoined; body = "joined the mesh"
        case .notConnected: kind = .peerLeft;   body = "left the mesh"
        default: return
        }
        let msg = MeshMessage(id: UUID(), sender: peerID.displayName, body: body, timestamp: Date(), kind: kind)
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.messages.append(msg)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let msg = try? decoder.decode(MeshMessage.self, from: data) else {
            NSLog("[TetherMesh] failed to decode message from %@", peerID.displayName)
            return
        }
        appendMessage(msg)
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName name: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        trackProgress(progress, key: name)
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName name: String, fromPeer peerID: MCPeerID, at url: URL?, withError error: Error?) {
        DispatchQueue.main.async {
            self.transferProgress.removeValue(forKey: name)
            self.progressObservers.removeValue(forKey: name)
        }

        if let error = error {
            NSLog("[TetherMesh] receive resource '%@' from %@ failed: %@", name, peerID.displayName, error.localizedDescription)
            return
        }
        guard let url = url else { return }

        let dest = dropDir.appendingPathComponent("\(UUID().uuidString)_\(name)")
        do {
            try FileManager.default.moveItem(at: url, to: dest)
        } catch {
            NSLog("[TetherMesh] failed to move received file '%@': %@", name, error.localizedDescription)
            return
        }
        let file = DroppedFile(id: UUID(), name: name, localURL: dest, sender: peerID.displayName, receivedAt: Date())
        let msg = MeshMessage(id: UUID(), sender: peerID.displayName, body: name, timestamp: Date(), kind: .fileReceived)
        DispatchQueue.main.async {
            self.droppedFiles.insert(file, at: 0)
            self.messages.append(msg)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName name: String, fromPeer peerID: MCPeerID) {}
}

extension TetherMesh: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("[TetherMesh] advertiser failed: %@", error.localizedDescription)
    }
}

extension TetherMesh: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let s = session, !s.connectedPeers.contains(peerID) else { return }
        browser.invitePeer(peerID, to: s, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("[TetherMesh] browser failed: %@", error.localizedDescription)
    }
}
