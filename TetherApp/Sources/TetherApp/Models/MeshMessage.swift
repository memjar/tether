import Foundation

struct MeshMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: String
    let body: String
    let timestamp: Date
    let kind: Kind

    enum Kind: String, Codable {
        case text
        case fileSent
        case fileReceived
        case peerJoined
        case peerLeft
    }

    var isSystem: Bool { kind == .peerJoined || kind == .peerLeft }
    var isFile: Bool { kind == .fileSent || kind == .fileReceived }
}

struct DroppedFile: Identifiable {
    let id: UUID
    let name: String
    let localURL: URL
    let sender: String
    let receivedAt: Date
    var size: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
    }
}
