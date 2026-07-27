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
    static let iconPlateSize: CGFloat = 42
    static let iconSize: CGFloat = 20
    static let iconCornerRadius: CGFloat = 16
    static let accentWidth: CGFloat = 44
    static let accentHeight: CGFloat = 4
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            .padding(.horizontal, usesCompactColumn ? PPSpace.sm : PPSpace.base)
            .padding(.vertical, PPSpace.base)
            .frame(
                maxWidth: .infinity,
                alignment: usesCompactColumn ? .center : .leading
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
        if usesCompactColumn {
            VStack(alignment: .center, spacing: PPSpace.sm) {
                iconPlate
                factText
            }
        } else if dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                iconPlate
                factText
            }
        } else {
            HStack(alignment: .center, spacing: PPSpace.md) {
                iconPlate
                factText
            }
        }
    }

    private var factText: some View {
        VStack(
            alignment: usesCompactColumn ? .center : .leading,
            spacing: PPSpace.xxs
        ) {
            Text(verbatim: "\u{2068}\(value)\u{2069}")
                .font(PPPetAdTypography.headline)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(usesCompactColumn ? .center : .leading)

            Text(label)
                .font(PPPetAdTypography.caption)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(usesCompactColumn ? .center : .leading)
        }
        .frame(
            maxWidth: .infinity,
            alignment: usesCompactColumn ? .center : .leading
        )
    }

    private var iconPlate: some View {
        billIcon
            .frame(
                width: PPPetAdInfoBillStyle.iconSize,
                height: PPPetAdInfoBillStyle.iconSize
            )
            .frame(
                width: PPPetAdInfoBillStyle.iconPlateSize,
                height: PPPetAdInfoBillStyle.iconPlateSize
            )
            .background {
                LinearGradient(
                    colors: [
                        signature.accentColor.opacity(
                            colorScheme == .dark ? 0.20 : 0.11
                        ),
                        signature.accentColor.opacity(
                            colorScheme == .dark ? 0.10 : 0.045
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PPPetAdInfoBillStyle.iconCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPPetAdInfoBillStyle.iconCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    signature.accentColor.opacity(
                        colorSchemeContrast == .increased ? 0.64 : 0.18
                    ),
                    lineWidth: colorSchemeContrast == .increased
                        ? 1
                        : PPPetAdViewerStyle.hairlineWidth
                )
            }
            .accessibilityHidden(true)
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
                .font(.system(size: 18, weight: .semibold))
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
