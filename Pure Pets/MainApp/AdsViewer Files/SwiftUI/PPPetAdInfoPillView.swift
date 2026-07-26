import SwiftUI

enum PPPetAdInfoEmphasis {
    case featured
    case supporting
}

struct PPPetAdInfoPillView: View {
    let systemIcon: String?
    let assetIcon: String?
    let label: String
    let value: String
    let emphasis: PPPetAdInfoEmphasis

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(
        systemIcon: String? = nil,
        assetIcon: String? = nil,
        label: String,
        value: String,
        emphasis: PPPetAdInfoEmphasis = .supporting
    ) {
        self.systemIcon = systemIcon
        self.assetIcon = assetIcon
        self.label = label
        self.value = value
        self.emphasis = emphasis
    }

    var body: some View {
        Group {
            switch emphasis {
            case .featured:
                featuredContent
            case .supporting:
                supportingContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private var featuredContent: some View {
        adaptiveFactRow(
            iconSize: dynamicTypeSize.isAccessibilitySize ? 50 : 44,
            valueFont: PPPetAdTypography.title3
        )
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.base)
    }

    private var supportingContent: some View {
        adaptiveFactRow(
            iconSize: dynamicTypeSize.isAccessibilitySize ? 38 : 30,
            valueFont: PPPetAdTypography.headline
        )
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.md)
    }

    @ViewBuilder
    private func adaptiveFactRow(
        iconSize: CGFloat,
        valueFont: Font
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                iconSlot(size: iconSize)
                factText(valueFont: valueFont)
            }
        } else {
            HStack(alignment: .top, spacing: iconSpacing) {
                iconSlot(size: iconSize)
                factText(valueFont: valueFont)
            }
        }
    }

    private var iconSpacing: CGFloat {
        emphasis == .featured ? PPSpace.md : PPSpace.sm
    }

    private func factText(valueFont: Font) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(label)
                .font(
                    emphasis == .featured
                    ? PPPetAdTypography.footnoteBold
                    : PPPetAdTypography.footnote
                )
                .foregroundStyle(
                    emphasis == .featured
                    ? Color.ppPrimary
                    : Color.ppTextSecondary
                )
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Text(verbatim: "\u{2068}\(value)\u{2069}")
                .font(valueFont)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    private func iconSlot(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: emphasis == .featured ? 15 : 11,
                style: .continuous
            )
            .fill(iconBackground)

            pillIcon
                .frame(
                    width: emphasis == .featured ? 25 : 16,
                    height: emphasis == .featured ? 25 : 16
                )
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(
                cornerRadius: emphasis == .featured ? 15 : 11,
                style: .continuous
            )
            .strokeBorder(
                iconStroke,
                lineWidth:
                    colorSchemeContrast == .increased
                    ? 1.25
                    : PPPetAdViewerStyle.hairlineWidth
            )
        }
        .accessibilityHidden(true)
    }

    private var iconBackground: Color {
        if emphasis == .featured {
            return Color.ppPrimary.opacity(
                colorSchemeContrast == .increased ? 0.18 : 0.10
            )
        }

        return Color.ppTextTertiary.opacity(
            colorSchemeContrast == .increased ? 0.20 : 0.12
        )
    }

    private var iconStroke: Color {
        if emphasis == .featured {
            return Color.ppPrimary.opacity(
                colorSchemeContrast == .increased ? 0.42 : 0.16
            )
        }

        return Color.ppSeparator.opacity(
            colorSchemeContrast == .increased ? 0.62 : 0.28
        )
    }

    @ViewBuilder
    private var pillIcon: some View {
        if let assetIcon, !assetIcon.isEmpty {
            Image(assetIcon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(PPPetAdViewerStyle.actionAccent)
                .accessibilityHidden(true)
        } else if let systemIcon, !systemIcon.isEmpty {
            Image(systemName: systemIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)
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
            value: "شيرازي أصيل",
            emphasis: .featured
        )
    }
    .padding()
    .background(Color.ppBackground)
}
#endif
