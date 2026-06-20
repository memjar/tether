import Foundation
import CoreBluetooth
import Combine

let kTetherServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
let kStatusCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")
let kCommandCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567892")
let kRadioCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567893")

final class BLETether: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var sharingState: String = "unknown"
    @Published var clientCount: Int = 0
    @Published var ssid: String = ""
    @Published var rssi: Int = 0
    @Published var channel: Int = 0
    @Published var band: String = ""
    @Published var phyMode: String = ""

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var commandChar: CBCharacteristic?
    private let queue = DispatchQueue(label: "diy.tether.ble.client")

    func startScanning() {
        central = CBCentralManager(delegate: self, queue: queue)
    }

    func stopScanning() {
        central?.stopScan()
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        central = nil
        DispatchQueue.main.async { self.isConnected = false }
    }

    func sendCommand(_ action: String, params: [String: Any] = [:]) {
        guard let char = commandChar, let p = peripheral else { return }
        var cmd: [String: Any] = ["action": action]
        for (k, v) in params { cmd[k] = v }
        guard let data = try? JSONSerialization.data(withJSONObject: cmd) else { return }
        p.writeValue(data, for: char, type: .withResponse)
    }

    func startSharing(ssid: String = "Tether", password: String = "", source: String = "en0") {
        sendCommand("start", params: ["ssid": ssid, "password": password, "source": source])
    }

    func stopSharing() { sendCommand("stop") }
    func pauseDevice(mac: String) { sendCommand("pause", params: ["device": mac]) }
    func resumeDevice(mac: String) { sendCommand("resume", params: ["device": mac]) }
    func kickDevice(mac: String) { sendCommand("kick", params: ["device": mac]) }
}

extension BLETether: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [kTetherServiceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([kTetherServiceUUID])
        DispatchQueue.main.async { self.isConnected = true }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { self.isConnected = false }
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.central?.scanForPeripherals(withServices: [kTetherServiceUUID], options: nil)
        }
    }
}

extension BLETether: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == kTetherServiceUUID }) else { return }
        peripheral.discoverCharacteristics([kStatusCharUUID, kCommandCharUUID, kRadioCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            switch char.uuid {
            case kStatusCharUUID:
                peripheral.setNotifyValue(true, for: char)
                peripheral.readValue(for: char)
            case kCommandCharUUID:
                commandChar = char
            case kRadioCharUUID:
                peripheral.setNotifyValue(true, for: char)
                peripheral.readValue(for: char)
            default: break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        DispatchQueue.main.async {
            switch characteristic.uuid {
            case kStatusCharUUID:
                self.sharingState = json["sharing"] as? String ?? "unknown"
                self.clientCount = json["clients"] as? Int ?? 0
                self.ssid = json["ssid"] as? String ?? ""
            case kRadioCharUUID:
                self.rssi = json["rssi"] as? Int ?? 0
                self.channel = json["channel"] as? Int ?? 0
                self.band = json["band"] as? String ?? ""
                self.phyMode = json["phy"] as? String ?? ""
            default: break
            }
        }
    }
}
