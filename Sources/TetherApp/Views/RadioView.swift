import SwiftUI
import TetherEngine

struct RadioView: View {
    @ObservedObject var engine: TetherEngine
    @State private var scannedNetworks: [ScannedNetwork] = []
    @State private var isScanning = false

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.094)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                radioCard
                channelMap
                scanSection
            }
            .padding(.vertical, 8)
        }
    }

    var radioCard: some View {
        VStack(spacing: 6) {
            sectionHeader("RADIO")
            VStack(spacing: 0) {
                infoRow("Channel", "\(engine.channel) (\(engine.channelBand))")
                Divider().opacity(0.1)
                infoRow("PHY Mode", engine.phyMode)
                Divider().opacity(0.1)
                infoRow("Tx Rate", String(format: "%.0f Mbps", engine.txRate))
                Divider().opacity(0.1)
                infoRow("RSSI", "\(engine.signalStrength) dBm")
                Divider().opacity(0.1)
                infoRow("Noise", "\(engine.noiseLevel) dBm")
            }
            .background(cardBg)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .cornerRadius(4)
            .padding(.horizontal, 16)
        }
    }

    var channelMap: some View {
        let channels = engine.radio.supportedChannels()
        let bands = Dictionary(grouping: channels, by: { $0.band })

        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CHANNEL MAP")
            ForEach(["2GHz", "5GHz"], id: \.self) { band in
                if let chs = bands[band] {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(band)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(gold)
                            .padding(.horizontal, 16)
                        channelRow(Array(Set(chs.map { $0.number })).sorted())
                    }
                }
            }
        }
    }

    func channelRow(_ channels: [Int]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(channels, id: \.self) { ch in
                    Text("\(ch)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ch == engine.channel ? .black : .secondary)
                        .frame(width: 24, height: 20)
                        .background(ch == engine.channel ? gold : cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(ch == engine.channel ? gold : Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .cornerRadius(2)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    var scanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .foregroundColor(gold)
                .padding(.trailing, 16)
            }

            if scannedNetworks.isEmpty {
                Text("Tap refresh to scan")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(scannedNetworks, id: \.bssid) { net in
                    networkRow(net)
                }
            }
        }
    }

    func networkRow(_ net: ScannedNetwork) -> some View {
        HStack(spacing: 8) {
            signalBars(net.rssi)
            VStack(alignment: .leading, spacing: 1) {
                Text(net.ssid)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Ch \(net.channel) \u{00B7} \(net.band)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(net.rssi) dBm")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(rssiColor(net.rssi))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    func signalBars(_ rssi: Int) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < barCount(rssi) ? rssiColor(rssi) : Color.gray.opacity(0.15))
                    .frame(width: 3, height: CGFloat(4 + i * 3))
            }
        }
        .frame(width: 20, height: 16)
    }

    func barCount(_ rssi: Int) -> Int {
        if rssi > -50 { return 4 }
        if rssi > -60 { return 3 }
        if rssi > -70 { return 2 }
        if rssi > -80 { return 1 }
        return 0
    }

    func rssiColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -70 { return gold }
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
            .kerning(0.5)
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
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
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
