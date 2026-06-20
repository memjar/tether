import SwiftUI
import TetherEngine

struct StatusView: View {
    @ObservedObject var engine: TetherEngine

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.094)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionCard
                signalGauge
                statsGrid
                sourcesSection
            }
            .padding(.vertical, 12)
        }
    }

    var connectionCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(engine.sharingActive ? gold : (engine.networkStatus == "Connected" ? Color.blue : Color.red))
                    .frame(width: 10, height: 10)
                Text(engine.sharingActive ? "Beacon Active" : engine.networkStatus)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            Group {
                Text("\(engine.primaryInterface) (\(engine.interfaceType))")
                if let ssid = engine.ssid {
                    Text(ssid)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)

            if engine.isExpensive {
                Text("METERED")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .cornerRadius(4)
        .padding(.horizontal, 16)
    }

    var signalGauge: some View {
        let snr = Double(engine.signalStrength - engine.noiseLevel)
        let quality = min(max(snr / 50.0, 0), 1.0)

        return VStack(spacing: 4) {
            ZStack {
                SignalArc(progress: 1.0)
                    .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 70)
                SignalArc(progress: quality)
                    .stroke(gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 70)
                VStack(spacing: 0) {
                    Text("\(Int(quality * 100))")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(signalLabel(quality))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(gold)
                }
                .offset(y: 8)
            }
            .frame(height: 80)
        }
        .padding(.horizontal, 16)
    }

    var statsGrid: some View {
        let snr = engine.signalStrength - engine.noiseLevel
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                statCell("RSSI", "\(engine.signalStrength)", "dBm")
                statCell("NOISE", "\(engine.noiseLevel)", "dBm")
            }
            HStack(spacing: 8) {
                statCell("SNR", "\(snr)", "dB")
                statCell("TX RATE", String(format: "%.0f", engine.txRate), "Mbps")
            }
        }
        .padding(.horizontal, 16)
    }

    func statCell(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .cornerRadius(4)
    }

    var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SOURCES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(0.5)
                .padding(.horizontal, 16)

            if engine.detectedSources.isEmpty {
                Text("No sources detected")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(engine.detectedSources, id: \.name) { src in
                    sourceRow(src)
                }
            }
        }
    }

    func sourceRow(_ src: DetectedInterface) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconForKind(src.kind))
                .font(.system(size: 12))
                .foregroundColor(gold)
                .frame(width: 16)
            Text(src.kind.rawValue)
                .font(.system(size: 12))
                .foregroundColor(.white)
            Spacer()
            Text(src.ip)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    func signalLabel(_ q: Double) -> String {
        if q > 0.8 { return "Excellent" }
        if q > 0.6 { return "Good" }
        if q > 0.4 { return "Fair" }
        if q > 0.2 { return "Weak" }
        return "Poor"
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

struct SignalArc: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2
        let startAngle = Angle(degrees: -180)
        let endAngle = Angle(degrees: -180 + (180 * progress))
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}
