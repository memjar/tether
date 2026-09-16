import SwiftUI
import UIKit

/// Shown wherever a hardware permission is off/denied/unsupported, with a direct route to Settings.
struct PermissionBanner: View {
    let message: String
    var icon: String = "exclamationmark.triangle.fill"

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.075)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(gold)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: openSettings) {
                    Text("Open Settings")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Rectangle().stroke(gold.opacity(0.3), lineWidth: 1))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBg)
        .overlay(Rectangle().stroke(gold.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
