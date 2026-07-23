import SwiftUI

/// Premium horizontal specification container: Species, Age, Gender.
/// Each item uses consistent icon sizing, typography, and alignment in
/// a unified card with restrained Apple-style shadows.
struct PPPetAdInfoGrid: View {
    let type: String
    let age: String
    let gender: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PPSpace.sm) {
                    specItems
                }
            } else {
                HStack(spacing: PPSpace.sm) {
                    specItems
                }
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity)
        .background(Color.ppForeground.opacity(0.72))
        .clipShape(
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
            .stroke(Color.ppTextTertiary.opacity(0.08), lineWidth: 0.75)
        }
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 8,
            x: 0,
            y: 2
        )
    }

    @ViewBuilder
    private var specItems: some View {
        if !type.isEmpty {
            specItem(
                symbol: "pawprint.fill",
                label: PPPetAdLocalization.text("Species", fallback: "Species"),
                value: type,
                tint: Color.ppPrimary
            )
        }

        if !age.isEmpty {
            specItem(
                symbol: "calendar",
                label: PPPetAdLocalization.text("Age", fallback: "Age"),
                value: age,
                tint: Color.ppInfo
            )
        }

        if !gender.isEmpty {
            specItem(
                symbol: "sparkles",
                label: PPPetAdLocalization.text("Gender", fallback: "Gender"),
                value: gender,
                tint: Color.ppWarning
            )
        }
    }

    private func specItem(
        symbol: String,
        label: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(spacing: PPSpace.xs) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: Circle())

            Text(label)
                .font(PPPetAdTypography.caption)
                .foregroundStyle(Color.ppTextTertiary)
                .lineLimit(1)

            Text(value)
                .font(PPPetAdTypography.subheadlineBold)
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
