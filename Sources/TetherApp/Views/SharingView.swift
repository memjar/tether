import SwiftUI
import TetherEngine

struct SharingView: View {
    @ObservedObject var engine: TetherEngine
    @State private var ssid = "Tether"
    @State private var password = ""
    @State private var selectedSource = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("INTERNET SHARING")

                // Status indicator
                HStack {
                    Circle()
                        .fill(engine.sharingActive ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(engine.sharingActive ? "Sharing Active" : "Sharing Off")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    if engine.sharingActive {
                        Text("\(engine.connectedDevices.count) devices")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)

                Divider()

                if !engine.sharingActive {
                    // Config form
                    sectionHeader("WIFI NETWORK")
                    formField("Network Name", text: $ssid)
                    formField("Password", text: $password, isSecure: true)

                    sectionHeader("SOURCE")
                    if engine.detectedSources.isEmpty {
                        Text("No internet sources detected")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(engine.detectedSources, id: \.name) { src in
                            Button(action: { selectedSource = src.name }) {
                                HStack {
                                    Image(systemName: selectedSource == src.name ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedSource == src.name ? .accentColor : .secondary)
                                    Image(systemName: iconForKind(src.kind))
                                        .frame(width: 16)
                                    Text(src.kind.rawValue)
                                        .font(.system(size: 12))
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

                    Spacer().frame(height: 8)

                    // Start button
                    Button(action: startSharing) {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Start Sharing")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(canStart ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStart)
                    .padding(.horizontal, 16)

                } else {
                    // Active sharing info
                    infoRow("SSID", engine.sharing.config.wifiConfig.ssid)
                    infoRow("Source", engine.sharing.config.sourceInterface)
                    infoRow("Security", engine.sharing.config.wifiConfig.security.rawValue)
                    infoRow("Subnet", engine.sharing.config.subnet)

                    Spacer().frame(height: 12)

                    Button(action: { engine.stopSharing() }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop Sharing")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            if selectedSource.isEmpty {
                selectedSource = engine.detectedSources.first?.name ?? ""
            }
        }
    }

    var canStart: Bool {
        !ssid.isEmpty && !selectedSource.isEmpty
    }

    func startSharing() {
        engine.startSharing(ssid: ssid, password: password, source: selectedSource)
    }

    func formField(_ label: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            if isSecure {
                SecureField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            } else {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
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
