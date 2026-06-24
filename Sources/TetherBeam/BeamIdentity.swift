import Foundation
import CryptoKit

public struct BeamIdentity {
    public let pin: String
    public let hostname: String
    public let platform: String

    public static func current() -> BeamIdentity {
        let host = ProcessInfo.processInfo.hostName
        let platform = "macOS"
        let seed = host + platform + (ProcessInfo.processInfo.environment["USER"] ?? "")
        let hash = SHA256.hash(data: Data(seed.utf8))
        let pin = hash.prefix(4).map { String(format: "%02X", $0) }.joined()
        return BeamIdentity(pin: pin, hostname: host, platform: platform)
    }

    public func toDict() -> [String: String] {
        ["pin": pin, "hostname": hostname, "platform": platform]
    }
}
