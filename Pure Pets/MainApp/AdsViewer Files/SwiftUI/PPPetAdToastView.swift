import SwiftUI

struct PPPetAdToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)

            Text(message)
                .font(PPPetAdTypography.subheadlineBold)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.md)
        .ppGlassSurface(
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            ),
            tint: Color.ppBackground.opacity(0.18),
            fallback: Color.ppCard,
            stroke: Color(uiColor: .separator).opacity(0.20)
        )
        .shadow(
            color: Color.black.opacity(0.14),
            radius: 18,
            y: 9
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
