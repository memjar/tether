import SwiftUI
import TetherEngine

struct RadioView: View {
    @ObservedObject var engine: TetherEngine
    @State private var scannedNetworks: [ScannedNetwork] = []
    @State private var isScanning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                radioSection
                Divider()
                channelSection
                Divider()
                scanSection
            }
            .padding(.vertical, 8)
        }
    }

    var radioSection: some View {
        Group {
            sectionHeader("RADIO")
            infoRow("Channel", "\(engine.channel) (\(engine.channelBand))")
            infoRow("PHY Mode", engine.phyMode)
            infoRow("Tx Rate", String(format: "%.0f Mbps", engine.txRate))
            infoRow("RSSI", "\(engine.signalStrength) dBm")
            infoRow("Noise", "\(engine.noiseLevel) dBm")
        }
    }

    var channelSection: some View {
        Group {
            sectionHeader("SUPPORTED CHANNELS")
            channelGrid
        }
    }

    var scanSection: some View {
        Group {
            HStack {
                sectionHeader("NEARBY NETWORKS")
                Spacer()
                Button(action: scanNetworks) {
                    if isScanning {
                        ProgressIndicator()
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.trailing, 16)
            }

            if scannedNetworks.isEmpty {
                Text("Tap refresh to scan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(scannedNetworks, id: \.bssid) { net in
                    networkRow(net)
                }
            }
        }
    }

    var channelGrid: some View {
        let channels = engine.radio.supportedChannels()
        let bands = Dictionary(grouping: channels, by: { $0.band })

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(["2GHz", "5GHz"], id: \.self) { band in
                if let chs = bands[band] {
                    HStack(spacing: 0) {
                        Text(band)
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 32, alignment: .leading)
                        let unique = Array(Set(chs.map { $0.number })).sorted()
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 2), count: 10), spacing: 2) {
                            ForEach(unique, id: \.self) { ch in
                                Text("\(ch)")
                                    .font(.system(size: 8, design: .monospaced))
                                    .frame(width: 22, height: 16)
                                    .background(ch == engine.channel ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
                                    .cornerRadius(3)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    func networkRow(_ net: ScannedNetwork) -> some View {
        HStack(spacing: 8) {
            Image(systemName: net.rssi > -70 ? "wifi" : "wifi.exclamationmark")
                .font(.system(size: 12))
                .foregroundColor(rssiColor(net.rssi))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(net.ssid)
                    .font(.system(size: 11))
                    .lineLimit(1)
                Text("Ch \(net.channel) · \(net.band)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(net.rssi) dBm")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(rssiColor(net.rssi))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    func rssiColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -70 { return .yellow }
        return .red
    }

    func scanNetworks() {
        isScanning = true
        DispatchQueue.global().async {
            let results = engine.radio.scanNetworks()
            DispatchQueue.main.async {
                scannedNetworks = results
                isScanning = false
            }
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
    }

    func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 1)
    }
}

struct ProgressIndicator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.startAnimation(nil)
        return indicator
    }
    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}
