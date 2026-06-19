import SwiftUI
import TetherEngine

struct DashboardView: View {
    @ObservedObject var engine: TetherEngine
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            tabBar
            Divider()

            switch selectedTab {
            case 0: StatusView(engine: engine)
            case 1: DevicesView(engine: engine)
            case 2: RadioView(engine: engine)
            case 3: SharingView(engine: engine)
            default: StatusView(engine: engine)
            }

            Spacer(minLength: 0)
            Divider()
            footerView
        }
        .frame(width: 340, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }

    var headerView: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundColor(engine.sharingActive ? .green : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tether")
                    .font(.headline)
                Text(engine.sharingActive ? "Sharing Active" : engine.networkStatus)
                    .font(.caption)
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
        if engine.sharingActive { return .green }
        if engine.networkStatus == "Connected" { return .blue }
        return .red
    }

    var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Status", icon: "network", tag: 0)
            tabButton("Devices", icon: "laptopcomputer.and.iphone", tag: 1)
            tabButton("Radio", icon: "wave.3.right", tag: 2)
            tabButton("Share", icon: "wifi", tag: 3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button(action: { selectedTab = tag }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(selectedTab == tag ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .foregroundColor(selectedTab == tag ? .accentColor : .secondary)
    }

    var footerView: some View {
        HStack {
            Text("tether.diy")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
