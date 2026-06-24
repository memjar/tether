import Foundation
import CryptoKit

public struct BeamBuild: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let version: String
    public let build: String
    public let bundleId: String
    public let platform: BeamPlatform
    public let fileSize: Int64
    public let sha256: String
    public let createdAt: Date
    public let ghostMode: Bool

    public init(id: UUID = UUID(), name: String, version: String, build: String, bundleId: String, platform: BeamPlatform, fileSize: Int64, sha256: String, createdAt: Date = Date(), ghostMode: Bool = false) {
        self.id = id; self.name = name; self.version = version; self.build = build
        self.bundleId = bundleId; self.platform = platform; self.fileSize = fileSize
        self.sha256 = sha256; self.createdAt = createdAt; self.ghostMode = ghostMode
    }
}

public final class BeamStore {
    private let root: URL
    private let queue = DispatchQueue(label: "diy.tether.beam.store")

    public init(directory: URL) {
        self.root = directory
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            NSLog("[Beam] failed to create store directory: %@", error.localizedDescription)
        }
    }

    public func save(fileData: Data, name: String, version: String, build: String, bundleId: String, platform: BeamPlatform, ghostMode: Bool) -> BeamBuild? {
        return queue.sync {
            let id = UUID()
            let dir = root.appendingPathComponent(id.uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                NSLog("[Beam] failed to create build directory: %@", error.localizedDescription)
                return nil
            }

            let ext = platform == .ios ? "ipa" : "app.zip"
            let filePath = dir.appendingPathComponent("\(name)-\(version).\(ext)")
            do {
                try fileData.write(to: filePath)
            } catch {
                NSLog("[Beam] failed to write build file: %@", error.localizedDescription)
                return nil
            }

            let hash = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            let record = BeamBuild(id: id, name: name, version: version, build: build, bundleId: bundleId, platform: platform, fileSize: Int64(fileData.count), sha256: hash, ghostMode: ghostMode)

            let metaPath = dir.appendingPathComponent("build.json")
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(record).write(to: metaPath)
            } catch {
                NSLog("[Beam] failed to write metadata: %@", error.localizedDescription)
            }
            return record
        }
    }

    public func list() -> [BeamBuild] {
        return queue.sync {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return contents.compactMap { dir in
                let meta = dir.appendingPathComponent("build.json")
                guard let data = try? Data(contentsOf: meta),
                      let build = try? decoder.decode(BeamBuild.self, from: data) else { return nil }
                return build
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }

    public func get(id: UUID) -> BeamBuild? {
        return list().first { $0.id == id }
    }

    public func filePath(for build: BeamBuild) -> URL? {
        let dir = root.appendingPathComponent(build.id.uuidString)
        let ext = build.platform == .ios ? "ipa" : "app.zip"
        let path = dir.appendingPathComponent("\(build.name)-\(build.version).\(ext)")
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    public func delete(id: UUID) -> Bool {
        return queue.sync {
            let dir = root.appendingPathComponent(id.uuidString)
            do {
                try FileManager.default.removeItem(at: dir)
                return true
            } catch {
                NSLog("[Beam] failed to delete build %@: %@", id.uuidString, error.localizedDescription)
                return false
            }
        }
    }
}
