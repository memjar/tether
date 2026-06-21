import SwiftUI

struct RadarView: View {
    @ObservedObject var radar: BLERadar

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.85
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.047).ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer()
                    radarHeader
                    radarDisk(size: size)
                    legend
                    Spacer()
                }
            }
        }
        .onAppear { radar.startScanning(); radar.startAdvertising() }
        .onDisappear { radar.stopScanning(); radar.stopAdvertising() }
    }

    var radarHeader: some View {
        VStack(spacing: 4) {
            Text("PROXIMITY RADAR")
                .font(.system(size: 11, weight: .medium))
                .kerning(4)
                .foregroundColor(gold)
            Text("\(radar.devices.count) Nearby")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
        }
    }

    func radarDisk(size: CGFloat) -> some View {
        let center = size / 2
        let maxR = size / 2 - 20

        return ZStack {
            ForEach(1..<5) { ring in
                Circle()
                    .stroke(gold.opacity(0.08), lineWidth: 1)
                    .frame(width: maxR * 2 * CGFloat(ring) / 4, height: maxR * 2 * CGFloat(ring) / 4)
            }

            crosshair(center: center, maxR: maxR)

            Circle()
                .fill(gold)
                .frame(width: 12, height: 12)

            ForEach(radar.devices) { device in
                deviceBlip(device, center: center, maxR: maxR)
            }
        }
        .frame(width: size, height: size)
    }

    func crosshair(center: CGFloat, maxR: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(gold.opacity(0.06))
                .frame(width: 1, height: maxR * 2)
            Rectangle()
                .fill(gold.opacity(0.06))
                .frame(width: maxR * 2, height: 1)

            ForEach(["N", "S", "E", "W"], id: \.self) { dir in
                Text(dir)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(gold.opacity(0.3))
                    .offset(
                        x: dir == "E" ? maxR + 12 : (dir == "W" ? -(maxR + 12) : 0),
                        y: dir == "N" ? -(maxR + 12) : (dir == "S" ? maxR + 12 : 0)
                    )
            }
        }
    }

    func deviceBlip(_ device: BLEDevice, center: CGFloat, maxR: CGFloat) -> some View {
        let normalizedDist = min(device.distance / 20, 1)
        let r = normalizedDist * maxR
        let x = cos(device.angle) * r
        let y = sin(device.angle) * r
        let alpha = max(0.3, 1 - normalizedDist)

        return VStack(spacing: 2) {
            Circle()
                .fill(gold.opacity(alpha))
                .frame(width: 8, height: 8)
                .shadow(color: gold.opacity(alpha * 0.5), radius: 4)
            Text(device.name)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(alpha))
                .lineLimit(1)
        }
        .offset(x: x, y: y)
    }

    var legend: some View {
        HStack(spacing: 20) {
            legendItem("Immediate", alpha: 1)
            legendItem("Near", alpha: 0.7)
            legendItem("Mid", alpha: 0.45)
            legendItem("Far", alpha: 0.25)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
    }

    func legendItem(_ label: String, alpha: Double) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gold.opacity(alpha))
                .frame(width: 6, height: 6)
            Text(label)
        }
    }
}
