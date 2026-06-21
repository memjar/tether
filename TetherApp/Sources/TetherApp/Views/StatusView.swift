import SwiftUI

struct StatusView: View {
    @ObservedObject var beacon: BeaconDiscovery
    @StateObject private var hotspot = GhostHotspot()

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.075)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                connectionStatus
                if let info = beacon.status?.info { statsPanel(info) }
                hotspotSection
            }
            .padding(.bottom, 80)
        }
        .onAppear {
            beacon.startDiscovery()
            hotspot.startMonitoring()
        }
    }

    var header: some View {
        VStack(spacing: 4) {
            Text("TETHER")
                .font(.system(size: 11, weight: .medium))
                .kerning(4)
                .foregroundColor(gold)
            Text("Remote Control")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 32)
    }

    var connectionStatus: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(beacon.isConnected ? gold.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(beacon.isConnected ? gold.opacity(0.15) : Color.gray.opacity(0.05))
                    .frame(width: 72, height: 72)
                Image(systemName: beacon.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 28))
                    .foregroundColor(beacon.isConnected ? gold : .gray)
            }
            Text(beacon.isConnected ? "Beacon Connected" : "Searching...")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            if beacon.isConnected, let info = beacon.status?.info {
                Text(info.ssid)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            } else if !beacon.discoveredHosts.isEmpty {
                Text("Found: \(beacon.discoveredHosts.joined(separator: ", "))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(gold.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(cardBg)
        .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    func statsPanel(_ info: BeaconInfo) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                statCell("DOWNLOAD", String(format: "%.0f", info.downloadSpeed), "Mbps")
                divider
                statCell("UPLOAD", String(format: "%.0f", info.uploadSpeed), "Mbps")
            }
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
            HStack(spacing: 0) {
                statCell("LATENCY", String(format: "%.0f", info.latency), "ms")
                divider
                statCell("DEVICES", "\(info.deviceCount)", "active")
            }
        }
        .background(cardBg)
        .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    var divider: some View {
        Rectangle().fill(Color.white.opacity(0.04)).frame(width: 1)
    }

    func statCell(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .kerning(0.5)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    var hotspotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LOCAL HOTSPOT")
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.5)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Circle()
                    .fill(hotspot.hotspotActive ? gold : Color.gray)
                    .frame(width: 10, height: 10)
                Text(hotspot.hotspotActive ? "Personal Hotspot Active" : "Hotspot Off")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { hotspot.openHotspotSettings() }) {
                    Text("Open Settings")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Rectangle().stroke(gold.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardBg)
            .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 1))
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }
}
