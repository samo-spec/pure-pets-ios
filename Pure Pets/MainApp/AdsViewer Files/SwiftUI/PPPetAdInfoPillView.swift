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
        HStack(alignment: .center, spacing: PPSpace.md) {
            pillIcon
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize ? 60 : 52,
                    height: dynamicTypeSize.isAccessibilitySize ? 48 : 42
                )
                .background(
                    Color.ppPrimary.opacity(0.11),
                    in: Capsule(style: .continuous)
                )

            factText(
                valueFont: PPPetAdTypography.title3
            )
        }
        .padding(.vertical, PPSpace.base)
    }

    private var supportingContent: some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            pillIcon
                .frame(width: 24, height: 24)

            factText(
                valueFont: PPPetAdTypography.headline
            )
        }
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.md)
    }

    private func factText(valueFont: Font) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(label)
                .font(PPPetAdTypography.footnote)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "\u{2068}\(value)\u{2069}")
                .font(valueFont)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var pillIcon: some View {
        if let assetIcon, !assetIcon.isEmpty {
            Image(assetIcon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(PPPetAdViewerStyle.actionAccent)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        } else if let systemIcon, !systemIcon.isEmpty {
            Image(systemName: systemIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    Color.ppTextSecondary
                )
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
