import Foundation

public struct BeamConfig {
    public let port: UInt16
    public let storageDir: URL
    public let baseURL: String
    public let apiKey: String
    public let allowedBundleIds: [String]
    public let ntfyTopic: String
    public let webhookURLs: [String]

    public init(
        port: UInt16 = 8902,
        storageDir: URL? = nil,
        baseURL: String = "https://tether.diy",
        apiKey: String = "",
        allowedBundleIds: [String] = ["ca.axetechnologies.tether"],
        ntfyTopic: String = "",
        webhookURLs: [String] = []
    ) {
        self.port = UInt16(ProcessInfo.processInfo.environment["BEAM_PORT"] ?? "") ?? port
        self.baseURL = ProcessInfo.processInfo.environment["BEAM_URL"] ?? baseURL
        self.apiKey = ProcessInfo.processInfo.environment["BEAM_KEY"] ?? apiKey
        self.ntfyTopic = ProcessInfo.processInfo.environment["BEAM_NTFY"] ?? ntfyTopic
        self.allowedBundleIds = allowedBundleIds

        if let envHooks = ProcessInfo.processInfo.environment["BEAM_WEBHOOKS"] {
            self.webhookURLs = envHooks.split(separator: ",").map(String.init)
        } else {
            self.webhookURLs = webhookURLs
        }

        if let dir = storageDir {
            self.storageDir = dir
        } else if let envDir = ProcessInfo.processInfo.environment["BEAM_DIR"] {
            self.storageDir = URL(fileURLWithPath: envDir)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageDir = appSupport.appendingPathComponent("Tether/Beam", isDirectory: true)
        }
    }

    public static let `default` = BeamConfig()
}

public enum BeamPlatform: String, Codable {
    case ios, macos
}
