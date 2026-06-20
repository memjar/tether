import Foundation

struct TetherDevice: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let mac: String
    let ip: String
    let band: Band
    let rssi: Int
    let rxBytes: UInt64
    let txBytes: UInt64
    let isPaused: Bool
    let firstSeen: Date
    let lastSeen: Date

    enum Band: String, Codable {
        case ghz24 = "2.4 GHz"
        case ghz5 = "5 GHz"
        case unknown = "Unknown"
    }

    var signalStrength: Double {
        min(max(Double(rssi + 100) / 60.0, 0), 1)
    }
}

struct BeaconInfo: Codable {
    let ssid: String
    let source: String
    let subnet: String
    let security: String
    let deviceCount: Int
    let uptime: TimeInterval
    let downloadSpeed: Double
    let uploadSpeed: Double
    let latency: Double
}

struct BeaconStatus: Codable {
    let active: Bool
    let info: BeaconInfo?
    let devices: [TetherDevice]
}
