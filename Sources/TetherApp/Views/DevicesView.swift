import SwiftUI
import TetherEngine

struct DevicesView: View {
    @ObservedObject var engine: TetherEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CONNECTED DEVICES")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(engine.connectedDevices.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if engine.connectedDevices.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No devices connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !engine.sharingActive {
                            Text("Start sharing to see devices")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(engine.connectedDevices, id: \.mac) { device in
                        DeviceRow(device: device, engine: engine)
                    }
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: ManagedClient
    @ObservedObject var engine: TetherEngine
    @State private var showActions = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: deviceIcon)
                    .font(.system(size: 16))
                    .foregroundColor(device.isPaused ? .red : .accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(device.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(device.ip)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if device.isPriority {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                }

                if device.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(3)
                }

                Button(action: { showActions.toggle() }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())

            if showActions {
                HStack(spacing: 12) {
                    if device.isPaused {
                        actionButton("Resume", icon: "play.fill", color: .green) {
                            engine.resumeDevice(mac: device.mac)
                        }
                    } else {
                        actionButton("Pause", icon: "pause.fill", color: .orange) {
                            engine.pauseDevice(mac: device.mac)
                        }
                    }
                    actionButton("Kick", icon: "xmark.circle.fill", color: .red) {
                        engine.kickDevice(mac: device.mac)
                    }
                    actionButton(device.isPriority ? "Unstar" : "Priority", icon: "star.fill", color: .yellow) {
                        engine.clients.setPriority(mac: device.mac, priority: !device.isPriority)
                        engine.refreshClients()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            Divider().padding(.horizontal, 16)
        }
    }

    var deviceIcon: String {
        let name = device.displayName.lowercased()
        if name.contains("iphone") || name.contains("phone") { return "iphone" }
        if name.contains("ipad") || name.contains("tablet") { return "ipad" }
        if name.contains("mac") || name.contains("book") { return "laptopcomputer" }
        if name.contains("tv") || name.contains("apple-tv") { return "appletv" }
        if name.contains("watch") { return "applewatch" }
        return "desktopcomputer"
    }

    func actionButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
