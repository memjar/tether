import Foundation
import CoreBluetooth
import Combine

struct BLEDevice: Identifiable, Equatable {
    let id: String
    let name: String
    var rssi: Int
    var distance: Double
    var angle: Double
    var lastSeen: Date

    var proximityLabel: String {
        if distance < 2 { return "Immediate" }
        if distance < 5 { return "Near" }
        if distance < 15 { return "Mid" }
        return "Far"
    }
}

final class BLERadar: NSObject, ObservableObject {
    @Published var devices: [BLEDevice] = []
    @Published var isScanning = false

    private var central: CBCentralManager?
    private var peripheral: CBPeripheralManager?
    private var seen: [String: BLEDevice] = [:]
    private var cleanupTimer: Timer?

    private let tetherServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")

    func startScanning() {
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func stopScanning() {
        central?.stopScan()
        central = nil
        isScanning = false
        cleanupTimer?.invalidate()
    }

    func startAdvertising() {
        peripheral = CBPeripheralManager(delegate: self, queue: nil)
    }

    func stopAdvertising() {
        peripheral?.stopAdvertising()
        peripheral = nil
    }

    private func estimateDistance(rssi: Int) -> Double {
        let txPower = -59.0
        let ratio = Double(rssi) / txPower
        if ratio < 1 { return pow(ratio, 10) }
        return 0.89976 * pow(ratio, 7.7095) + 0.111
    }

    private func pruneStale() {
        let cutoff = Date().addingTimeInterval(-15)
        seen = seen.filter { $0.value.lastSeen > cutoff }
        devices = Array(seen.values).sorted { $0.distance < $1.distance }
    }
}

extension BLERadar: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        isScanning = true
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.pruneStale()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let rssi = RSSI.intValue
        guard rssi > -100 && rssi < 0 else { return }

        let dist = estimateDistance(rssi: rssi)
        let angle = seen[id]?.angle ?? Double.random(in: 0..<(2 * .pi))

        seen[id] = BLEDevice(id: id, name: name, rssi: rssi, distance: dist, angle: angle, lastSeen: Date())
        devices = Array(seen.values).sorted { $0.distance < $1.distance }
    }
}

extension BLERadar: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [tetherServiceUUID],
            CBAdvertisementDataLocalNameKey: "Tether"
        ])
    }
}
