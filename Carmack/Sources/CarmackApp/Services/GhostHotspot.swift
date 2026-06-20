import Foundation
import Network

final class GhostHotspot: ObservableObject {
    @Published var hotspotActive = false
    @Published var canDetectHotspot = false

    private var monitor: NWPathMonitor?

    func startMonitoring() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wifi = path.usesInterfaceType(.wifi)
                let cellular = path.usesInterfaceType(.cellular)
                self?.hotspotActive = wifi && cellular
                self?.canDetectHotspot = true
            }
        }
        monitor?.start(queue: .global(qos: .utility))
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }

    func openHotspotSettings() {
        #if os(iOS)
        if let url = URL(string: "App-Prefs:root=INTERNET_TETHERING") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }

    #if GHOST_MODE
    func toggleHotspot(on: Bool) {
        // MobileWiFi.framework private API
        // WiFiManagerClientCreate() -> WiFiManagerClient
        // WiFiManagerClientSetProperty(client, "AllowTethering", on ? 1 : 0)
        // Requires com.apple.wifi.manager-access entitlement (sideload only)
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_LAZY) else { return }
        typealias CreateFn = @convention(c) () -> UnsafeMutableRawPointer?
        typealias SetPropFn = @convention(c) (UnsafeMutableRawPointer, CFString, CFNumber) -> Void

        guard let createSym = dlsym(handle, "WiFiManagerClientCreate"),
              let setPropSym = dlsym(handle, "WiFiManagerClientSetProperty") else {
            dlclose(handle)
            return
        }

        let create = unsafeBitCast(createSym, to: CreateFn.self)
        let setProp = unsafeBitCast(setPropSym, to: SetPropFn.self)

        guard let client = create() else { dlclose(handle); return }
        let value = NSNumber(value: on ? 1 : 0)
        setProp(client, "AllowTethering" as CFString, value)
        dlclose(handle)
        hotspotActive = on
    }
    #endif
}
