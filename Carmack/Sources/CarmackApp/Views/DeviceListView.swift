import SwiftUI

struct DeviceListView: View {
    @ObservedObject var beacon: BeaconDiscovery
    @State private var filter: DeviceFilter = .all
    @State private var expanded: String?

    enum DeviceFilter: String, CaseIterable {
        case all = "All"
        case fast = "5 GHz"
        case slow = "2.4 GHz"
        case paused = "Paused"
    }

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.075)

    var filteredDevices: [TetherDevice] {
        let devices = beacon.status?.devices ?? []
        switch filter {
        case .all: return devices
        case .fast: return devices.filter { $0.band == .ghz5 }
        case .slow: return devices.filter { $0.band == .ghz24 }
        case .paused: return devices.filter { $0.isPaused }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                filterBar
                deviceList
            }
            .padding(.bottom, 80)
        }
    }

    var header: some View {
        VStack(spacing: 4) {
            Text("DEVICES")
                .font(.system(size: 11, weight: .medium))
                .kerning(4)
                .foregroundColor(gold)
            Text("\(beacon.status?.devices.count ?? 0) Connected")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DeviceFilter.allCases, id: \.self) { f in
                    Button(action: { filter = f }) {
                        Text(f.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(filter == f ? .black : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(filter == f ? gold : Color.white.opacity(0.04))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
    }

    var deviceList: some View {
        VStack(spacing: 6) {
            if filteredDevices.isEmpty {
                Text("No devices")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
            } else {
                ForEach(filteredDevices) { device in
                    deviceRow(device)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    func deviceRow(_ device: TetherDevice) -> some View {
        VStack(spacing: 0) {
            Button(action: { expanded = expanded == device.id ? nil : device.id }) {
                HStack(spacing: 12) {
                    Image(systemName: iconFor(device))
                        .font(.system(size: 14))
                        .foregroundColor(gold)
                        .frame(width: 32, height: 32)
                        .background(gold.opacity(0.08))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(device.ip)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(device.band.rawValue)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.04))
                        signalDots(device.signalStrength)
                    }
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded == device.id {
                actionBar(device)
            }
        }
        .background(cardBg)
        .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    func actionBar(_ device: TetherDevice) -> some View {
        HStack(spacing: 0) {
            actionButton(device.isPaused ? "Resume" : "Pause", icon: device.isPaused ? "play.fill" : "pause.fill") {
                if device.isPaused { beacon.resumeDevice(id: device.id) }
                else { beacon.pauseDevice(id: device.id) }
            }
            Rectangle().fill(Color.white.opacity(0.04)).frame(width: 1)
            actionButton("Kick", icon: "xmark", destructive: true) {
                beacon.kickDevice(id: device.id)
            }
        }
        .frame(height: 40)
        .background(Color.white.opacity(0.02))
    }

    func actionButton(_ label: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(destructive ? .red : gold)
            .frame(maxWidth: .infinity)
        }
    }

    func signalDots(_ strength: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(Double(i) / 5.0 < strength ? gold : Color.white.opacity(0.08))
                    .frame(width: 5, height: 5)
            }
        }
    }

    func iconFor(_ device: TetherDevice) -> String {
        let lower = device.name.lowercased()
        if lower.contains("mac") || lower.contains("book") { return "laptopcomputer" }
        if lower.contains("iphone") || lower.contains("phone") { return "iphone" }
        if lower.contains("ipad") || lower.contains("pad") { return "ipad" }
        if lower.contains("tv") || lower.contains("apple tv") { return "appletv" }
        if lower.contains("watch") { return "applewatch" }
        if lower.contains("homepod") || lower.contains("pod") { return "homepod" }
        return "questionmark.circle"
    }
}
