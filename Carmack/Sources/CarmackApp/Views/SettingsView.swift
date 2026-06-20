import SwiftUI

struct SettingsView: View {
    @ObservedObject var beacon: BeaconDiscovery
    @AppStorage("autoConnect") private var autoConnect = true
    @AppStorage("bleRadarEnabled") private var bleRadar = true
    @AppStorage("notificationsEnabled") private var notifications = true

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.075)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                connectionSection
                radarSection
                aboutSection
            }
            .padding(.bottom, 80)
        }
    }

    var header: some View {
        VStack(spacing: 4) {
            Text("SETTINGS")
                .font(.system(size: 11, weight: .medium))
                .kerning(4)
                .foregroundColor(gold)
            Text("Configuration")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    var connectionSection: some View {
        section("BEACON CONNECTION") {
            toggleRow("Auto-Connect", subtitle: "Reconnect to last known beacon", isOn: $autoConnect)
            separator
            toggleRow("Notifications", subtitle: "Alert on disconnect / new device", isOn: $notifications)
            separator
            infoRow("Status", beacon.isConnected ? "Connected" : "Disconnected")
            if beacon.isConnected {
                separator
                HStack {
                    Text("Disconnect")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture { beacon.disconnect() }
            }
        }
    }

    var radarSection: some View {
        section("PROXIMITY RADAR") {
            toggleRow("BLE Scanning", subtitle: "Detect nearby devices via Bluetooth", isOn: $bleRadar)
            separator
            infoRow("Range", "~20m")
            separator
            infoRow("Update Rate", "1s")
        }
    }

    var aboutSection: some View {
        section("ABOUT") {
            infoRow("App", "Carmack v0.1.0")
            separator
            infoRow("Codename", "Ghost Operative")
            separator
            infoRow("Architecture", "Path 1 — Remote")
            separator
            HStack {
                Text("GitHub")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Spacer()
                Text("memjar/tether")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.5)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) { content() }
                .background(cardBg)
                .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }

    var separator: some View {
        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1).padding(.horizontal, 16)
    }

    func toggleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(gold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
