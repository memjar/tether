import Foundation
import SystemConfiguration

final class SystemWatcher {
    typealias Handler = (String) -> Void

    private var store: SCDynamicStore?
    private var source: CFRunLoopSource?
    private var darwinTokens: [Int32] = []
    private var onChange: Handler?

    func start(onChange: @escaping Handler) {
        self.onChange = onChange
        setupDynamicStore()
        watchDarwinNotifications()
    }

    func stop() {
        if let source = source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        source = nil
        store = nil
        for token in darwinTokens {
            var t = token
            notify_cancel(t)
        }
        darwinTokens.removeAll()
    }

    func copyInterfaceState(_ iface: String) -> [String: Any]? {
        guard let store = store else { return nil }
        let key = "State:/Network/Interface/\(iface)/AirPort" as CFString
        return SCDynamicStoreCopyValue(store, key) as? [String: Any]
    }

    func copyGlobalIPv4() -> [String: Any]? {
        guard let store = store else { return nil }
        return SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
    }

    func copyDNS() -> [String: Any]? {
        guard let store = store else { return nil }
        return SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any]
    }

    private func setupDynamicStore() {
        var ctx = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        store = SCDynamicStoreCreate(nil, "Tether" as CFString, { (_, keys, info) in
            guard let info = info else { return }
            let watcher = Unmanaged<SystemWatcher>.fromOpaque(info).takeUnretainedValue()
            guard let changedKeys = keys as? [String] else { return }
            for key in changedKeys {
                watcher.onChange?(key)
            }
        }, &ctx)

        guard let store = store else { return }

        let watchKeys = [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
            "State:/Network/Global/DNS",
            "State:/Network/Interface/en0/AirPort",
            "State:/Network/Interface/en0/IPv4",
            "State:/Network/Interface/en1/AirPort",
            "State:/Network/Interface/bridge100/IPv4",
            "Setup:/Network/Global/IPv4"
        ] as CFArray

        let patterns = [
            "State:/Network/Interface/.*/Link",
            "State:/Network/Interface/.*/IPv4"
        ] as CFArray

        SCDynamicStoreSetNotificationKeys(store, watchKeys, patterns)

        source = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
        if let source = source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private func watchDarwinNotifications() {
        let events = [
            "com.apple.system.config.network_change",
            "com.apple.networking.linkquality",
            "com.apple.wifi.link.up",
            "com.apple.wifi.link.down",
            "com.apple.bluetooth.state"
        ]

        for event in events {
            var token: Int32 = 0
            let name = event
            notify_register_dispatch(name, &token, DispatchQueue.main) { [weak self] _ in
                self?.onChange?(name)
            }
            darwinTokens.append(token)
        }
    }

    deinit { stop() }
}
