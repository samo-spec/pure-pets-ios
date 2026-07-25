import SwiftUI

struct PPPetAdInfoPillView: View {
    let systemIcon: String?
    let assetIcon: String?
    let label: String
    let value: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        systemIcon: String? = nil,
        assetIcon: String? = nil,
        label: String,
        value: String
    ) {
        self.systemIcon = systemIcon
        self.assetIcon = assetIcon
        self.label = label
        self.value = value
    }

    private var isAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(spacing: PPSpace.xs) {
                pillIcon

                Text(label)
                    .font(PPPetAdTypography.footnote)
                    .foregroundStyle(Color.ppTextSecondary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(value)
                .font(PPPetAdTypography.headline)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.base)
        .frame(
            maxWidth: .infinity,
            minHeight: isAccessibilityLayout ? 82 : 78,
            alignment: .leading
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    @ViewBuilder
    private var pillIcon: some View {
        if let assetIcon, !assetIcon.isEmpty {
            Image(assetIcon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(PPPetAdViewerStyle.actionAccent)
                .frame(width: 19, height: 19)
                .accessibilityHidden(true)
        } else if let systemIcon, !systemIcon.isEmpty {
            Image(systemName: systemIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    PPPetAdViewerStyle.actionAccent.opacity(0.88)
                )
                .frame(width: 19, height: 19)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("Info Pills Grid") {
    VStack(spacing: PPSpace.md) {
        PPPetAdInfoPillView(
            systemIcon: "sparkles",
            label: "الجنس",
            value: "أنثى"
        )
        PPPetAdInfoPillView(
            systemIcon: "calendar",
            label: "العمر",
            value: "سنتين"
        )
        PPPetAdInfoPillView(
            assetIcon: "peeking_pets",
            label: "السلالة",
            value: "شيرازي أصيل"
        )
    }
    .padding()
    .background(Color.ppBackground)
}
#endif
