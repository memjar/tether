import Cocoa
import SwiftUI
import TetherEngine
import TetherAI
import TetherAPI
import TetherBeam

@main
struct TetherApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menubar-only, no dock icon
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var engine: TetherEngine!
    var apiServer: TetherAPIServer!
    var beam: Beam!
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = TetherEngine()
        engine.start()

        let predictor = NetworkPredictor()
        let failover = FailoverEngine(monitor: engine.monitor, sharingController: engine.sharing)
        apiServer = TetherAPIServer(
            monitor: engine.monitor,
            sharing: engine.sharing,
            clients: engine.clients,
            predictor: predictor,
            failover: failover
        )
        Task { try? await apiServer.start() }

        beam = Beam(config: BeamConfig(
            baseURL: "https://beam.tether.diy",
            webhookURLs: [
                "https://axe.observer/api/beam/events",
                "https://atlas.axe.observer/api/ingest",
                "https://crown.axe.observer/api/ingest"
            ],
            pushTargets: [
                BeamFleetPush(name: "nova", endpoint: "http://jl1.local:8902"),
                BeamFleetPush(name: "forge", endpoint: "http://jl2.local:8902"),
                BeamFleetPush(name: "vigil", endpoint: "http://jl3.local:8902")
            ]
        ))
        beam.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Tether")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let contentView = DashboardView(engine: engine)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let p = self?.popover, p.isShown { p.performClose(nil) }
        }

    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
