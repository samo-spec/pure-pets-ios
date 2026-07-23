import SwiftUI

/// Compact, centered state block used inside cards — symbol in a tinted
/// halo, a title, a sentence of context, and at most one action.
struct PPPetAdInlineStateView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let tint: Color
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.11), in: Circle())

            VStack(spacing: PPSpace.xs) {
                Text(title)
                    .font(PPPetAdTypography.headline)
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !message.isEmpty {
                    Text(message)
                        .font(PPPetAdTypography.subheadline)
                        .foregroundStyle(Color.ppTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(PPPetAdTypography.calloutBold)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, PPSpace.lg)
                        .frame(minHeight: 46)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(PPPetAdPressButtonStyle())
            }
        }
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}
