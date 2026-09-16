import CoreBluetooth

/// Friendly projection of `CBManagerState` shared by `BLETether` and `BLERadar`
/// so both can publish a state the UI can react to for every case, not just `.poweredOn`.
enum BLEAvailability: Equatable {
    case unknown
    case unsupported
    case unauthorized
    case poweredOff
    case ready

    init(_ state: CBManagerState) {
        switch state {
        case .poweredOn: self = .ready
        case .unauthorized: self = .unauthorized
        case .poweredOff: self = .poweredOff
        case .unsupported: self = .unsupported
        case .resetting, .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }

    /// User-facing explanation, or nil when there's nothing to tell the user (`.ready`/`.unknown`).
    var bannerMessage: String? {
        switch self {
        case .unauthorized:
            return "Bluetooth access is off. Tether needs Bluetooth to find and control your beacon."
        case .poweredOff:
            return "Turn on Bluetooth to find and control your beacon."
        case .unsupported:
            return "This device doesn't support Bluetooth Low Energy, so Tether can't find nearby beacons."
        case .unknown, .ready:
            return nil
        }
    }
}
