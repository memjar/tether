import SwiftUI
import TetherEngine

struct DevicesView: View {
    @ObservedObject var engine: TetherEngine
    @State private var filter = 0

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.094)

    var filteredDevices: [ManagedClient] {
        switch filter {
        case 1: return engine.connectedDevices.filter { !$0.isPaused }
        case 2: return engine.connectedDevices.filter { $0.isPaused }
        default: return engine.connectedDevices
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                headerBar
                filterBar
                deviceList
            }
            .padding(.vertical, 8)
        }
    }

    var headerBar: some View {
        HStack {
            Text("CONNECTED DEVICES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(0.5)
            Spacer()
            Text("\(engine.connectedDevices.count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(gold)
        }
        .padding(.horizontal, 16)
    }

    var filterBar: some View {
        HStack(spacing: 0) {
            filterButton("All", tag: 0)
            filterButton("Active", tag: 1)
            filterButton("Paused", tag: 2)
        }
        .background(cardBg)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    func filterButton(_ title: String, tag: Int) -> some View {
        Button(action: { filter = tag }) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(filter == tag ? gold.opacity(0.2) : Color.clear)
                .foregroundColor(filter == tag ? gold : .secondary)
        }
        .buttonStyle(.plain)
    }

    var deviceList: some View {
        Group {
            if filteredDevices.isEmpty {
                emptyState
            } else {
                ForEach(filteredDevices, id: \.mac) { device in
                    DeviceRow(device: device, engine: engine, gold: gold, cardBg: cardBg)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No devices connected")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            if !engine.sharingActive {
                Text("Open a beacon to see devices")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

struct DeviceRow: View {
    let device: ManagedClient
    @ObservedObject var engine: TetherEngine
    let gold: Color
    let cardBg: Color
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if expanded {
                actionBar
            }
        }
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .cornerRadius(4)
        .padding(.horizontal, 16)
    }

    var mainRow: some View {
        Button(action: { expanded.toggle() }) {
            HStack(spacing: 10) {
                Image(systemName: deviceIcon)
                    .font(.system(size: 15))
                    .foregroundColor(device.isPaused ? .red : gold)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(device.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if device.isPriority {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(gold)
                        }
                    }
                    Text(device.ip)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if device.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                }

                signalDots

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var signalDots: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < signalLevel ? gold : Color.gray.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }

    var signalLevel: Int {
        if device.isPaused { return 0 }
        return 3
    }

    var actionBar: some View {
        HStack(spacing: 8) {
            if device.isPaused {
                actionBtn("Resume", icon: "play.fill", color: .green) {
                    engine.resumeDevice(mac: device.mac)
                }
            } else {
                actionBtn("Pause", icon: "pause.fill", color: .orange) {
                    engine.pauseDevice(mac: device.mac)
                }
            }
            actionBtn("Kick", icon: "xmark.circle.fill", color: .red) {
                engine.kickDevice(mac: device.mac)
            }
            actionBtn(device.isPriority ? "Unstar" : "Priority", icon: "star.fill", color: gold) {
                engine.clients.setPriority(mac: device.mac, priority: !device.isPriority)
                engine.refreshClients()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    func actionBtn(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
        }
        .buttonStyle(.plain)
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
}
