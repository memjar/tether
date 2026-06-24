import Foundation
import UIKit

final class NativeDrop: NSObject, ObservableObject {
    @Published var nearbyReceivers: [DropTarget] = []
    @Published var transferState: TransferState = .idle

    enum TransferState: Equatable {
        case idle
        case discovering
        case sending(String, Double)
        case complete(String)
        case failed(String)
    }

    struct DropTarget: Identifiable {
        let id: String
        let name: String
        let deviceType: String
    }

    #if GHOST_MODE
    private var sharingLib: UnsafeMutableRawPointer?
    private var discoveryController: NSObject?
    private var transferManager: NSObject?

    func startDiscovery() {
        sharingLib = dlopen("/System/Library/PrivateFrameworks/Sharing.framework/Sharing", RTLD_LAZY)
        guard sharingLib != nil else {
            DispatchQueue.main.async { self.transferState = .failed("Sharing.framework unavailable") }
            return
        }
        DispatchQueue.main.async { self.transferState = .discovering }

        guard let dcClass = NSClassFromString("SFAirDropDiscoveryController") as? NSObject.Type else {
            NSLog("[NativeDrop] SFAirDropDiscoveryController class not found")
            return
        }
        discoveryController = dcClass.init()
        discoveryController?.perform(NSSelectorFromString("setDelegate:"), with: self)
        discoveryController?.perform(NSSelectorFromString("startDiscovery"))
    }

    func stopDiscovery() {
        discoveryController?.perform(NSSelectorFromString("stopDiscovery"))
        discoveryController = nil
        DispatchQueue.main.async {
            self.nearbyReceivers = []
            self.transferState = .idle
        }
    }

    func sendFile(at url: URL, to target: DropTarget) {
        guard let tmClass = NSClassFromString("SFAirDropTransferManager") as? NSObject.Type else {
            NSLog("[NativeDrop] SFAirDropTransferManager class not found")
            return
        }
        guard let instance = tmClass.perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? NSObject else {
            NSLog("[NativeDrop] failed to get sharedInstance")
            return
        }
        transferManager = instance

        DispatchQueue.main.async { self.transferState = .sending(url.lastPathComponent, 0) }

        let sel = NSSelectorFromString("sendItems:toNode:")
        guard instance.responds(to: sel) else {
            NSLog("[NativeDrop] sendItems:toNode: not available")
            DispatchQueue.main.async { self.transferState = .failed("Transfer API unavailable") }
            return
        }
        let items = [url] as NSArray
        instance.perform(sel, with: items, with: target.id)
    }

    #else

    func startDiscovery() {}

    func stopDiscovery() {
        DispatchQueue.main.async {
            self.nearbyReceivers = []
            self.transferState = .idle
        }
    }

    #endif

    func sendViaActivitySheet(items: [Any], from viewController: UIViewController) {
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        viewController.present(ac, animated: true)
    }
}
