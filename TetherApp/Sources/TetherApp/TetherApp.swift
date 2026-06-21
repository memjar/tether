import SwiftUI

@main
struct TetherMobileApp: App {
    @StateObject private var beacon = BeaconDiscovery()
    @StateObject private var radar = BLERadar()
    @StateObject private var tether = BLETether()

    var body: some Scene {
        WindowGroup {
            RootView(beacon: beacon, radar: radar, tether: tether)
                .preferredColorScheme(.dark)
                .onAppear { tether.startScanning() }
        }
    }
}

struct RootView: View {
    @ObservedObject var beacon: BeaconDiscovery
    @ObservedObject var radar: BLERadar
    @ObservedObject var tether: BLETether
    @State private var tab: Tab = .status

    enum Tab: String, CaseIterable {
        case status, devices, radar, settings
    }

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let dark = Color(red: 0.04, green: 0.04, blue: 0.047)

    var body: some View {
        ZStack(alignment: .bottom) {
            dark.ignoresSafeArea()
            tabContent
            tabBar
        }
    }

    @ViewBuilder
    var tabContent: some View {
        switch tab {
        case .status: StatusView(beacon: beacon)
        case .devices: DeviceListView(beacon: beacon)
        case .radar: RadarView(radar: radar)
        case .settings: SettingsView(beacon: beacon)
        }
    }

    var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.status, icon: "antenna.radiowaves.left.and.right", label: "Status")
            tabButton(.devices, icon: "macbook.and.iphone", label: "Devices")
            tabButton(.radar, icon: "dot.radiowaves.left.and.right", label: "Radar")
            tabButton(.settings, icon: "gearshape", label: "Settings")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(Color(red: 0.06, green: 0.06, blue: 0.067))
                .shadow(color: .black.opacity(0.5), radius: 10, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    func tabButton(_ t: Tab, icon: String, label: String) -> some View {
        Button(action: { tab = t }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .kerning(0.3)
            }
            .foregroundColor(tab == t ? gold : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}
