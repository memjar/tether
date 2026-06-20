import SwiftUI
import TetherEngine

struct DashboardView: View {
    @ObservedObject var engine: TetherEngine
    @State private var selectedTab = 0

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.094)

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            tabBar
            Divider()
            Group {
                switch selectedTab {
                case 0: StatusView(engine: engine)
                case 1: DevicesView(engine: engine)
                case 2: RadioView(engine: engine)
                case 3: SharingView(engine: engine)
                default: settingsPlaceholder
                }
            }
            Spacer(minLength: 0)
            Divider()
            footerView
        }
        .frame(width: 340, height: 520)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
    }

    var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundColor(engine.sharingActive ? gold : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tether")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(engine.sharingActive ? "Beacon Active" : engine.networkStatus)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    var statusColor: Color {
        if engine.sharingActive { return gold }
        if engine.networkStatus == "Connected" { return .blue }
        return .red
    }

    var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("Status", icon: "network", tag: 0)
            tabButton("Devices", icon: "laptopcomputer.and.iphone", tag: 1)
            tabButton("Radio", icon: "wave.3.right", tag: 2)
            tabButton("Beacon", icon: "wifi", tag: 3)
            tabButton("Settings", icon: "gearshape", tag: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button(action: { selectedTab = tag }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 8, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(selectedTab == tag ? gold.opacity(0.2) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .foregroundColor(selectedTab == tag ? gold : .secondary)
    }

    var settingsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Settings")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var footerView: some View {
        HStack {
            Text("tether.diy")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
