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
        devices.map { dev in
            var e = EnrichedDevice(id: dev.id, name: dev.name, rssi: dev.rssi, distance: dev.distance)
            let lower = dev.name.lowercased()
            if lower.hasPrefix("iphone") || lower.hasPrefix("ipad") || lower.hasPrefix("mac") || lower.hasPrefix("apple") {
                e.manufacturer = "Apple"
                e.isApple = true
            }
            return e
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
    private var btManager: NSObject?

    private func loadPrivateEnrichment() {
        loadBluetoothManager()
        loadMobileGestalt()
    }

    private func loadBluetoothManager() {
        guard dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_LAZY) != nil else {
            NSLog("[DeepRadar] BluetoothManager.framework unavailable")
            return
        }
        guard let cls = NSClassFromString("BluetoothManager"),
              let instance = cls.perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? NSObject else {
            NSLog("[DeepRadar] BluetoothManager sharedInstance failed")
            return
        }
        btManager = instance

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name("BluetoothDeviceDiscoveredNotification"), object: nil, queue: .main) { [weak self] notif in
            guard let device = notif.object as? NSObject else { return }
            let name = device.value(forKey: "_name") as? String ?? "Unknown"
            let addr = device.value(forKey: "_address") as? String ?? ""
            let product = device.value(forKey: "_productName") as? String
            self?.handlePrivateDiscovery(address: addr, name: name, product: product)
        }

        nc.addObserver(forName: NSNotification.Name("BluetoothDeviceBatteryChangedNotification"), object: nil, queue: .main) { [weak self] notif in
            guard let device = notif.object as? NSObject,
                  let addr = device.value(forKey: "_address") as? String,
                  let level = device.value(forKey: "_batteryLevel") as? Int else { return }
            self?.updateBattery(address: addr, level: level)
        }
    }

    private func handlePrivateDiscovery(address: String, name: String, product: String?) {
        DispatchQueue.main.async {
            guard let idx = self.enrichedDevices.firstIndex(where: { $0.id == address }) else { return }
            self.enrichedDevices[idx].manufacturer = "Apple"
            self.enrichedDevices[idx].isApple = true
            self.enrichedDevices[idx].deviceModel = product
        }
    }

    private func updateBattery(address: String, level: Int) {
        DispatchQueue.main.async {
            guard let idx = self.enrichedDevices.firstIndex(where: { $0.id == address }) else { return }
            self.enrichedDevices[idx].batteryLevel = level
        }
    }

    private func loadMobileGestalt() {
        guard let lib = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY),
              let sym = dlsym(lib, "MGCopyAnswer") else {
            NSLog("[DeepRadar] MobileGestalt unavailable")
            return
        }
        typealias MGCopyFn = @convention(c) (CFString) -> CFTypeRef?
        let mgCopy = unsafeBitCast(sym, to: MGCopyFn.self)

        let deviceName = mgCopy("DeviceName" as CFString) as? String
        let modelNumber = mgCopy("ModelNumber" as CFString) as? String
        let wifiAddress = mgCopy("WiFiAddress" as CFString) as? String
        let btAddress = mgCopy("BluetoothAddress" as CFString) as? String

        guard let name = deviceName else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("TetherDeviceIdentified"),
            object: nil,
            userInfo: ["name": name, "model": modelNumber ?? "", "wifi": wifiAddress ?? "", "bt": btAddress ?? ""]
        )
    }
    #endif

    deinit {
        darwinTokens.forEach { notify_cancel($0) }
    }
}
