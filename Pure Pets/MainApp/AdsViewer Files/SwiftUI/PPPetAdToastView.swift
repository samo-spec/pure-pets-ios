import SwiftUI

/// Lightweight confirmation banner for completed actions — favorite saved,
/// report submitted, network warnings. Appears from the bottom edge with
/// a spring and announces itself to VoiceOver.
struct PPPetAdToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)

            Text(message)
                .font(PPPetAdTypography.subheadlineBold)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.md)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
        }
        .shadow(
            color: Color.black.opacity(0.14),
            radius: 18,
            y: 9
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
