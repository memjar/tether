import SwiftUI
import TetherEngine

struct StatusView: View {
    @ObservedObject var engine: TetherEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                networkSection
                Divider()
                signalSection
                Divider()
                sourcesSection
            }
            .padding(.vertical, 8)
        }
    }

    var networkSection: some View {
        Group {
            sectionHeader("Network")
            statusRow("Status", engine.networkStatus, color: engine.networkStatus == "Connected" ? .green : .red)
            statusRow("Interface", "\(engine.primaryInterface) (\(engine.interfaceType))")
            statusRow("SSID", engine.ssid ?? "—")
            if engine.isExpensive {
                statusRow("Metered", "Yes", color: .orange)
            }
        }
    }

    var signalSection: some View {
        Group {
            sectionHeader("Signal")
            signalBar
            statusRow("RSSI", "\(engine.signalStrength) dBm")
            statusRow("Noise", "\(engine.noiseLevel) dBm")
            statusRow("SNR", "\(engine.signalStrength - engine.noiseLevel) dB")
            statusRow("Tx Rate", String(format: "%.0f Mbps", engine.txRate))
        }
    }

    var sourcesSection: some View {
        Group {
            sectionHeader("Sources")
            if engine.detectedSources.isEmpty {
                Text("No sources detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(engine.detectedSources, id: \.name) { src in
                    HStack {
                        Image(systemName: iconForKind(src.kind))
                            .frame(width: 16)
                        Text(src.kind.rawValue)
                            .font(.system(size: 12))
                        Spacer()
                        Text(src.ip)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    var signalBar: some View {
        let snr = Double(engine.signalStrength - engine.noiseLevel)
        let quality = min(max(snr / 50.0, 0), 1.0)

        return HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Double(i) / 5.0 < quality ? barColor(quality) : Color.gray.opacity(0.2))
                    .frame(width: 12, height: CGFloat(8 + i * 4))
            }
            Spacer()
            Text(signalLabel(quality))
                .font(.system(size: 11))
                .foregroundColor(barColor(quality))
        }
        .padding(.horizontal, 16)
    }

    func barColor(_ q: Double) -> Color {
        if q > 0.7 { return .green }
        if q > 0.4 { return .yellow }
        return .red
    }

    func signalLabel(_ q: Double) -> String {
        if q > 0.8 { return "Excellent" }
        if q > 0.6 { return "Good" }
        if q > 0.4 { return "Fair" }
        if q > 0.2 { return "Weak" }
        return "Poor"
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
    }

    func statusRow(_ label: String, _ value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(color ?? .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 1)
    }

    func iconForKind(_ kind: InterfaceKind) -> String {
        switch kind {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .iphoneUSB: return "iphone"
        case .thunderbolt: return "bolt.fill"
        case .bluetooth: return "wave.3.right"
        case .unknown: return "questionmark.circle"
        }
    }
}
