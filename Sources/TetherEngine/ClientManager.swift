import Foundation

public struct ManagedClient: Sendable {
    public let mac: String
    public var ip: String
    public var hostname: String?
    public var customName: String?
    public var isPaused: Bool
    public var isPriority: Bool
    public var group: String?
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public let firstSeen: Date
    public var lastSeen: Date

    public var displayName: String {
        customName ?? hostname ?? mac
    }
}

public final class ClientManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "diy.tether.clients")
    private var knownClients: [String: ManagedClient] = [:] // keyed by MAC
    private var pausedMACs: Set<String> = []
    private var priorityMACs: Set<String> = []
    private let pfAnchor = "com.tether.clients"

    public init() {}

    // MARK: - Client Registry

    public func updateFromLeases(_ tethered: [TetheredClient]) {
        queue.sync {
            let now = Date()
            for client in tethered {
                if var existing = knownClients[client.mac] {
                    existing.ip = client.ip
                    existing.lastSeen = now
                    if let h = client.hostname { existing.hostname = h }
                    knownClients[client.mac] = existing
                } else {
                    knownClients[client.mac] = ManagedClient(
                        mac: client.mac,
                        ip: client.ip,
                        hostname: client.hostname,
                        customName: nil,
                        isPaused: pausedMACs.contains(client.mac),
                        isPriority: priorityMACs.contains(client.mac),
                        group: nil,
                        bytesIn: 0,
                        bytesOut: 0,
                        firstSeen: now,
                        lastSeen: now
                    )
                }
            }
        }
    }

    public var allClients: [ManagedClient] {
        queue.sync { Array(knownClients.values).sorted { $0.lastSeen > $1.lastSeen } }
    }

    public var activeClients: [ManagedClient] {
        allClients.filter { Date().timeIntervalSince($0.lastSeen) < 300 }
    }

    // MARK: - Pause / Resume (PF-based)

    public func pauseClient(mac: String) throws {
        guard var client = knownClients[mac] else { return }
        let ip = client.ip

        // Block via PF (packet filter) — same mechanism Apple uses for Internet Sharing NAT
        let rule = "block drop quick on bridge100 from \(ip) to any"
        let tempFile = "/tmp/tether-block-\(mac.replacingOccurrences(of: ":", with: "")).conf"

        try rule.write(toFile: tempFile, atomically: true, encoding: .utf8)
        shell("/sbin/pfctl", ["-a", pfAnchor, "-f", tempFile])
        shell("/sbin/pfctl", ["-e"]) // ensure PF is enabled

        try? FileManager.default.removeItem(atPath: tempFile)

        client.isPaused = true
        queue.sync { knownClients[mac] = client; pausedMACs.insert(mac) }
    }

    public func resumeClient(mac: String) throws {
        guard var client = knownClients[mac] else { return }

        // Flush the anchor to remove block rules for this client
        shell("/sbin/pfctl", ["-a", pfAnchor, "-F", "rules"])

        // Re-add rules for other paused clients
        let stillPaused = queue.sync { pausedMACs.filter { $0 != mac } }
        for otherMAC in stillPaused {
            if let other = knownClients[otherMAC] {
                let rule = "block drop quick on bridge100 from \(other.ip) to any"
                let tempFile = "/tmp/tether-block-\(otherMAC.replacingOccurrences(of: ":", with: "")).conf"
                try? rule.write(toFile: tempFile, atomically: true, encoding: .utf8)
                shell("/sbin/pfctl", ["-a", pfAnchor, "-f", tempFile])
                try? FileManager.default.removeItem(atPath: tempFile)
            }
        }

        client.isPaused = false
        queue.sync { knownClients[mac] = client; pausedMACs.remove(mac) }
    }

    public func kickClient(mac: String) {
        // Force ARP cache flush for the client's IP
        if let client = knownClients[mac] {
            shell("/usr/sbin/arp", ["-d", client.ip])
        }
        queue.sync { knownClients.removeValue(forKey: mac) }
    }

    // MARK: - Priority / Naming

    public func setClientName(mac: String, name: String) {
        queue.sync {
            knownClients[mac]?.customName = name
        }
    }

    public func setClientGroup(mac: String, group: String) {
        queue.sync {
            knownClients[mac]?.group = group
        }
    }

    public func setPriority(mac: String, priority: Bool) {
        queue.sync {
            knownClients[mac]?.isPriority = priority
            if priority { priorityMACs.insert(mac) } else { priorityMACs.remove(mac) }
        }
    }

    // MARK: - Bandwidth Tracking

    public func updateBandwidth(mac: String, bytesIn: UInt64, bytesOut: UInt64) {
        queue.sync {
            knownClients[mac]?.bytesIn = bytesIn
            knownClients[mac]?.bytesOut = bytesOut
        }
    }

    // MARK: - Shell Helper

    @discardableResult
    private func shell(_ command: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch { return "" }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

