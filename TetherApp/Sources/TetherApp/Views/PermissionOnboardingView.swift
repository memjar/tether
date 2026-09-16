import SwiftUI

/// One-time explanation shown before the real Bluetooth / Local Network prompts,
/// so the system dialogs land with context instead of firing cold on first launch.
struct PermissionOnboardingView: View {
    var onContinue: () -> Void

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let dark = Color(red: 0.04, green: 0.04, blue: 0.047)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.075)

    var body: some View {
        ZStack {
            dark.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 4) {
                    Text("TETHER")
                        .font(.system(size: 11, weight: .medium))
                        .kerning(4)
                        .foregroundColor(gold)
                    Text("Before You Start")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(.white)
                }

                VStack(spacing: 16) {
                    permissionRow(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Bluetooth",
                        detail: "Finds and controls your beacon, and shows nearby devices on the radar."
                    )
                    permissionRow(
                        icon: "wifi",
                        title: "Local Network",
                        detail: "Connects to your beacon and other Tether devices on the mesh."
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(gold)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(cardBg)
        .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
