import Foundation
import CoreBluetooth

final class DeepRadar: NSObject, ObservableObject {
    @Published var enrichedDevices: [EnrichedDevice] = []

    struct EnrichedDevice: Identifiable {
        let id: String
        let name: String
        let rssi: Int
        let distance: Double
        var manufacturer: String = "Unknown"
        var deviceModel: String?
        var batteryLevel: Int?
        var isApple: Bool = false
    }

    private var darwinTokens: [Int32] = []

    override init() {
        super.init()
        watchSystemEvents()
        #if GHOST_MODE
        loadPrivateEnrichment()
        #endif
    }

    func enrich(_ devices: [BLEDevice]) -> [EnrichedDevice] {
        return devices.map { dev in
            var e = EnrichedDevice(
                id: dev.id,
                name: dev.name,
                rssi: dev.rssi,
                distance: dev.distance
            )
            e.isApple = dev.name.contains("iPhone") || dev.name.contains("iPad") ||
                        dev.name.contains("Mac") || dev.name.contains("Apple")
            parseManufacturer(&e, from: dev)
            return e
        }
    }

    private func parseManufacturer(_ device: inout EnrichedDevice, from ble: BLEDevice) {
        if device.name.hasPrefix("iPhone") || device.name.hasPrefix("iPad") {
            device.manufacturer = "Apple"
            device.isApple = true
        }
    }

    private func watchSystemEvents() {
        var token: Int32 = 0
        notify_register_dispatch("com.apple.bluetooth.state", &token, DispatchQueue.main) { [weak self] _ in
            self?.objectWillChange.send()
        }
        darwinTokens.append(token)
    }

    #if GHOST_MODE
    private var btManagerClass: AnyClass?
    private var btManager: NSObject?

    private func loadPrivateEnrichment() {
        loadBluetoothManager()
        loadMobileGestalt()
    }

    private func loadBluetoothManager() {
        guard let lib = dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_LAZY) else { return }
        btManagerClass = NSClassFromString("BluetoothManager")
        btManager = btManagerClass?.perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? NSObject

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name("BluetoothDeviceDiscoveredNotification"), object: nil, queue: .main) { [weak self] notif in
            guard let device = notif.object as? NSObject else { return }
            let name = device.value(forKey: "_name") as? String ?? "Unknown"
            let addr = device.value(forKey: "_address") as? String ?? ""
            self?.handlePrivateDiscovery(name: name, address: addr, device: device)
        }

        nc.addObserver(forName: NSNotification.Name("BluetoothDeviceBatteryChangedNotification"), object: nil, queue: .main) { [weak self] notif in
            guard let device = notif.object as? NSObject,
                  let addr = device.value(forKey: "_address") as? String else { return }
            self?.updateBatteryForDevice(address: addr, device: device)
        }
    }

    private func handlePrivateDiscovery(name: String, address: String, device: NSObject) {
        let product = device.value(forKey: "_productName") as? String
        DispatchQueue.main.async {
            if let idx = self.enrichedDevices.firstIndex(where: { $0.id == address }) {
                self.enrichedDevices[idx].manufacturer = "Apple"
                self.enrichedDevices[idx].deviceModel = product
            }
        }
    }

    private func updateBatteryForDevice(address: String, device: NSObject) {
        DispatchQueue.main.async {
            if let idx = self.enrichedDevices.firstIndex(where: { $0.id == address }) {
                self.enrichedDevices[idx].batteryLevel = device.value(forKey: "_batteryLevel") as? Int
            }
        }
    }

    private func loadMobileGestalt() {
        guard let lib = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY) else { return }
        typealias MGCopyFn = @convention(c) (CFString) -> CFTypeRef?
        guard let sym = dlsym(lib, "MGCopyAnswer") else { return }
        let mgCopy = unsafeBitCast(sym, to: MGCopyFn.self)

        let deviceName = mgCopy("DeviceName" as CFString) as? String
        let modelNumber = mgCopy("ModelNumber" as CFString) as? String
        let wifiAddress = mgCopy("WiFiAddress" as CFString) as? String
        let btAddress = mgCopy("BluetoothAddress" as CFString) as? String

        if let name = deviceName {
            NotificationCenter.default.post(name: NSNotification.Name("TetherDeviceIdentified"),
                                            object: nil,
                                            userInfo: ["name": name, "model": modelNumber ?? "", "wifi": wifiAddress ?? "", "bt": btAddress ?? ""])
        }
    }
    #endif

    deinit {
        for token in darwinTokens {
            var t = token
            notify_cancel(t)
        }
    }
}
