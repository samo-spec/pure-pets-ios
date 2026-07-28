import SwiftUI

enum PPPetAdInfoEmphasis {
    case featured
    case supporting
}

enum PPPetAdInfoSignature: String, CaseIterable {
    case breed
    case age
    case gender

    var accentColor: Color {
        switch self {
        case .breed:
            return .ppPrimary
        case .age:
            return .ppInfo
        case .gender:
            return .ppSuccess
        }
    }
}

private enum PPPetAdInfoBillStyle {
    static let featuredIconSize: CGFloat = 38
    static let supportingIconSize: CGFloat = 26
    static let featuredGlyphSize: CGFloat = 18
    static let supportingGlyphSize: CGFloat = 14
    static let accentWidth: CGFloat = 32
    static let accentHeight: CGFloat = 3
}

struct PPPetAdInfoAccent: View {
    let color: Color

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                color.opacity(
                    colorSchemeContrast == .increased ? 0.90 : 0.62
                )
            )
            .frame(
                width: PPPetAdInfoBillStyle.accentWidth,
                height: PPPetAdInfoBillStyle.accentHeight
            )
            .accessibilityHidden(true)
    }
}

struct PPPetAdInfoPillView: View {
    let systemIcon: String?
    let assetIcon: String?
    let label: String
    let value: String
    let signature: PPPetAdInfoSignature
    let emphasis: PPPetAdInfoEmphasis
    let showsBottomAccent: Bool
    let usesCompactColumn: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(
        systemIcon: String? = nil,
        assetIcon: String? = nil,
        label: String,
        value: String,
        signature: PPPetAdInfoSignature = .breed,
        emphasis: PPPetAdInfoEmphasis = .supporting,
        showsBottomAccent: Bool = false,
        usesCompactColumn: Bool = false
    ) {
        self.systemIcon = systemIcon
        self.assetIcon = assetIcon
        self.label = label
        self.value = value
        self.signature = signature
        self.emphasis = emphasis
        self.showsBottomAccent = showsBottomAccent
        self.usesCompactColumn = usesCompactColumn
    }

    var body: some View {
        adaptiveFactRow
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .overlay(alignment: .bottom) {
                if showsBottomAccent {
                    PPPetAdInfoAccent(color: signature.accentColor)
                }
            }
            .layoutPriority(emphasis == .featured ? 1 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label): \(value)")
    }

    @ViewBuilder
    private var adaptiveFactRow: some View {
        if emphasis == .featured {
            HStack(alignment: .center, spacing: PPSpace.md) {
                iconMarker(size: PPPetAdInfoBillStyle.featuredIconSize)
                factText
            }
        } else if usesCompactColumn {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                HStack(spacing: PPSpace.sm) {
                    iconMarker(size: PPPetAdInfoBillStyle.supportingIconSize)

                    Text(label)
                        .font(PPPetAdTypography.caption)
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                valueText
            }
        } else {
            HStack(alignment: .center, spacing: PPSpace.md) {
                iconMarker(size: PPPetAdInfoBillStyle.supportingIconSize)
                factText
            }
        }
    }

    private var factText: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(label)
                .font(PPPetAdTypography.caption)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            valueText
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private var valueText: some View {
        Text(verbatim: "\u{2068}\(value)\u{2069}")
            .font(
                emphasis == .featured
                    ? PPPetAdTypography.headline
                    : PPPetAdTypography.subheadlineBold
            )
            .foregroundStyle(Color.ppTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    private func iconMarker(size: CGFloat) -> some View {
        billIcon
            .frame(
                width: glyphSize(for: size),
                height: glyphSize(for: size)
            )
            .frame(
                width: size,
                height: size
            )
            .background {
                if emphasis == .featured {
                    Circle()
                        .fill(
                            signature.accentColor.opacity(
                                colorScheme == .dark ? 0.20 : 0.10
                            )
                        )
                }
            }
            .overlay {
                if emphasis == .featured {
                    Circle()
                        .strokeBorder(
                            signature.accentColor.opacity(
                                colorSchemeContrast == .increased ? 0.72 : 0.16
                            ),
                            lineWidth: colorSchemeContrast == .increased
                                ? 1
                                : PPPetAdViewerStyle.hairlineWidth
                        )
                }
            }
            .accessibilityHidden(true)
    }

    private func glyphSize(for markerSize: CGFloat) -> CGFloat {
        markerSize == PPPetAdInfoBillStyle.featuredIconSize
            ? PPPetAdInfoBillStyle.featuredGlyphSize
            : PPPetAdInfoBillStyle.supportingGlyphSize
    }

    private var horizontalPadding: CGFloat {
        emphasis == .featured
            ? 0
            : (usesCompactColumn ? PPSpace.md : 0)
    }

    private var verticalPadding: CGFloat {
        emphasis == .featured
            ? 0
            : PPSpace.md
    }

    @ViewBuilder
    private var billIcon: some View {
        if let assetIcon, !assetIcon.isEmpty {
            Image(assetIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(signature.accentColor)
                .accessibilityHidden(true)
        } else if let systemIcon, !systemIcon.isEmpty {
            Image(systemName: systemIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(signature.accentColor)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("Provider-language info bills") {
    VStack(spacing: PPSpace.md) {
        PPPetAdInfoPillView(
            assetIcon: "peeking_pets",
            label: "السلالة",
            value: "شيرازي أصيل",
            signature: .breed,
            emphasis: .featured,
            showsBottomAccent: true
        )
        PPPetAdInfoPillView(
            systemIcon: "calendar",
            label: "العمر",
            value: "سنتان",
            signature: .age,
            showsBottomAccent: true
        )
    }
    .padding()
    .background(Color.ppBackground)
    .environment(\.layoutDirection, .rightToLeft)
}
#endif
