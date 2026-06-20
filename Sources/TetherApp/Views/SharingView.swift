import SwiftUI
import TetherEngine

struct SharingView: View {
    @ObservedObject var engine: TetherEngine
    @State private var ssid = "Tether"
    @State private var password = ""
    @State private var selectedSource = ""

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.094)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusHeader
                Divider().opacity(0.1).padding(.horizontal, 16)
                if engine.sharingActive {
                    activeBeaconView
                } else {
                    configView
                }
            }
            .padding(.vertical, 10)
        }
        .onAppear {
            if selectedSource.isEmpty {
                selectedSource = engine.detectedSources.first?.name ?? ""
            }
        }
    }

    var statusHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(engine.sharingActive ? gold : Color.gray)
                .frame(width: 12, height: 12)
            Text(engine.sharingActive ? "Beacon Active" : "Beacon Off")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            if engine.sharingActive {
                Text("\(engine.connectedDevices.count) devices")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(gold)
            }
        }
        .padding(.horizontal, 16)
    }

    var configView: some View {
        Group {
            networkConfig
            sourceSelect
            openButton
        }
    }

    var networkConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("BEACON NETWORK")
            VStack(spacing: 0) {
                formField("Network Name", text: $ssid)
                Divider().opacity(0.1).padding(.horizontal, 14)
                secureFormField("Password", text: $password)
            }
            .background(cardBg)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .cornerRadius(4)
            .padding(.horizontal, 16)
        }
    }

    var sourceSelect: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("SOURCE")
            if engine.detectedSources.isEmpty {
                Text("No internet sources detected")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            } else {
                ForEach(engine.detectedSources, id: \.name) { src in
                    Button(action: { selectedSource = src.name }) {
                        HStack(spacing: 8) {
                            Image(systemName: selectedSource == src.name ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(selectedSource == src.name ? gold : .secondary)
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
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var openButton: some View {
        VStack(spacing: 6) {
            Button(action: startBeacon) {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 13))
                    Text("Open Beacon")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canStart ? gold : Color.gray)
                .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .disabled(!canStart)
            .padding(.horizontal, 16)

            if !ssid.isEmpty {
                Text("Your beacon will be visible as \"\(ssid)\"")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }

    var activeBeaconView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                infoRow("SSID", engine.sharing.config.wifiConfig.ssid)
                Divider().opacity(0.1)
                infoRow("Source", engine.sharing.config.sourceInterface)
                Divider().opacity(0.1)
                infoRow("Security", engine.sharing.config.wifiConfig.security.rawValue)
                Divider().opacity(0.1)
                infoRow("Subnet", engine.sharing.config.subnet)
                Divider().opacity(0.1)
                infoRow("Devices", "\(engine.connectedDevices.count)")
            }
            .background(cardBg)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .cornerRadius(4)
            .padding(.horizontal, 16)

            Button(action: { engine.stopSharing() }) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                    Text("Close Beacon")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    func formField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    func secureFormField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            SecureField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
            .padding(.horizontal, 16)
    }

    var canStart: Bool { !ssid.isEmpty && !selectedSource.isEmpty }

    func startBeacon() {
        engine.startSharing(ssid: ssid, password: password, source: selectedSource)
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
