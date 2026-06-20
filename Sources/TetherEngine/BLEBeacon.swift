import Foundation
import CoreBluetooth

public let kTetherServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
public let kStatusCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")
public let kCommandCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567892")
public let kRadioCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567893")

public final class BLEBeacon: NSObject, ObservableObject, @unchecked Sendable {
    @Published public var isAdvertising = false
    @Published public var connectedCentrals: Int = 0

    private var peripheralManager: CBPeripheralManager?
    private var statusChar: CBMutableCharacteristic?
    private var commandChar: CBMutableCharacteristic?
    private var radioChar: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []

    public var onCommand: (([String: Any]) -> Void)?

    private let queue = DispatchQueue(label: "diy.tether.ble.beacon")

    public override init() {
        super.init()
    }

    public func start() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
    }

    public func stop() {
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
        isAdvertising = false
        connectedCentrals = 0
        subscribedCentrals.removeAll()
    }

    public func pushStatus(_ data: [String: Any]) {
        guard let char = statusChar, let pm = peripheralManager, pm.state == .poweredOn else { return }
        guard let json = try? JSONSerialization.data(withJSONObject: data) else { return }
        let chunks = chunk(json, size: 182)
        for c in chunks {
            pm.updateValue(c, for: char, onSubscribedCentrals: nil)
        }
    }

    public func pushRadio(_ data: [String: Any]) {
        guard let char = radioChar, let pm = peripheralManager, pm.state == .poweredOn else { return }
        guard let json = try? JSONSerialization.data(withJSONObject: data) else { return }
        pm.updateValue(json, for: char, onSubscribedCentrals: nil)
    }

    private func chunk(_ data: Data, size: Int) -> [Data] {
        if data.count <= size { return [data] }
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + size, data.count)
            chunks.append(data[offset..<end])
            offset = end
        }
        return chunks
    }

    private func buildService() {
        statusChar = CBMutableCharacteristic(
            type: kStatusCharUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        commandChar = CBMutableCharacteristic(
            type: kCommandCharUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        radioChar = CBMutableCharacteristic(
            type: kRadioCharUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: kTetherServiceUUID, primary: true)
        service.characteristics = [statusChar!, commandChar!, radioChar!]
        peripheralManager?.add(service)
    }
}

extension BLEBeacon: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            DispatchQueue.main.async { self.isAdvertising = false }
            return
        }
        buildService()
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [kTetherServiceUUID],
            CBAdvertisementDataLocalNameKey: "Tether"
        ])
        DispatchQueue.main.async { self.isAdvertising = true }
        print("[BLEBeacon] Advertising Tether GATT service")
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let err = error { print("[BLEBeacon] Service add error: \(err)") }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
        }
        DispatchQueue.main.async { self.connectedCentrals = self.subscribedCentrals.count }
        print("[BLEBeacon] Central subscribed: \(central.identifier.uuidString.prefix(8))")
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
        DispatchQueue.main.async { self.connectedCentrals = self.subscribedCentrals.count }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == kStatusCharUUID {
            let placeholder = "{\"sharing\":\"idle\"}".data(using: .utf8) ?? Data()
            request.value = placeholder
            peripheral.respond(to: request, withResult: .success)
        } else if request.characteristic.uuid == kRadioCharUUID {
            let placeholder = "{\"rssi\":0}".data(using: .utf8) ?? Data()
            request.value = placeholder
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == kCommandCharUUID, let data = request.value {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    onCommand?(json)
                }
            }
        }
        if let first = requests.first {
            peripheral.respond(to: first, withResult: .success)
        }
    }
}
