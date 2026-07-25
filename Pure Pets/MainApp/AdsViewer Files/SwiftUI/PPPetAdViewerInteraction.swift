import Foundation
import SwiftUI
import UIKit

// MARK: - Consolidated viewer support
//
// The viewer's small state types, layout metrics, localization helper,
// motion tokens, press behavior, and glass treatment intentionally live in
// this existing source file. Keeping the definitions here avoids requiring a
// new PBX file reference when these sources are dropped into the legacy app.

enum PPPetAdViewerInteraction: Int {
    case view = 0
    case favoriteAdded = 1
    case favoriteRemoved = 2
    case share = 3
    case call = 4
    case chat = 5
}

enum PPPetAdViewerActionState: Equatable {
    case idle
    case working
    case succeeded(message: String)
    case failed(message: String)
}

enum PPPetAdViewerScreenState: Equatable {
    case loading
    case content
    case empty
    case offline(message: String)
    case failed(message: String)
}

enum PPPetAdViewerSectionState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case offline(message: String)
    case failed(message: String)
}

enum PPPetAdVideoState: Equatable {
    case loading
    case ready
    case failed
}

enum PPPetAdImageLoadState {
    case idle
    case loading(placeholder: UIImage?)
    case loaded(UIImage)
    case failed
}

enum PPPetAdRelatedItemKind {
    case petAd(PetAd)
    case accessory(PetAccessory)
}

enum PPPetAdLocalization {
    @inline(__always)
    static func text(_ key: String, fallback: String) -> String {
        let localized = Language.get(key, alter: fallback)
        guard let localized, !localized.isEmpty, localized != key else {
            return fallback
        }
        return localized
    }
}

enum PPPetAdReportReason: String, CaseIterable, Identifiable {
    case inappropriateContent = "inappropriate_content"
    case scamOrFraud = "scam_fraud"
    case wrongCategory = "wrong_category"
    case spam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inappropriateContent:
            return PPPetAdLocalization.text(
                "report_reason_inappropriate",
                fallback: "Inappropriate Content"
            )
        case .scamOrFraud:
            return PPPetAdLocalization.text(
                "report_reason_fraud",
                fallback: "Scam or Fraud"
            )
        case .wrongCategory:
            return PPPetAdLocalization.text(
                "report_reason_wrong_category",
                fallback: "Wrong Category"
            )
        case .spam:
            return PPPetAdLocalization.text(
                "report_reason_spam",
                fallback: "Spam"
            )
        case .other:
            return PPPetAdLocalization.text(
                "report_reason_other",
                fallback: "Other"
            )
        }
    }
}

struct PPPetAdOwner {
    let user: UserModel
    let displayName: String
    let avatarURL: String?
    let phoneNumber: String?
    let isVerified: Bool
    let isChatAllowed: Bool

    init(user: UserModel) {
        self.user = user
        displayName = PPPetAdViewerLegacyBridge.displayName(for: user)
        avatarURL = PPPetAdViewerLegacyBridge.avatarURL(for: user)
        phoneNumber = PPPetAdViewerLegacyBridge.phoneNumber(for: user)
        isVerified = PPPetAdViewerLegacyBridge.isVerified(user: user)
        isChatAllowed = PPPetAdViewerLegacyBridge.isChatAllowed(for: user)
    }
}

struct PPPetAdViewerSnapshot {
    let ad: PetAd
    let title: String
    let category: String
    let subcategory: String
    let location: String
    let price: String
    let age: String
    let gender: String
    let description: String
    let media: [PPPetAdMediaItem]

    var hasRenderableContent: Bool {
        !title.isEmpty || !category.isEmpty || !subcategory.isEmpty || !price.isEmpty
            || !age.isEmpty
            || !gender.isEmpty || !description.isEmpty || !media.isEmpty
    }
}

enum PPPetAdViewerMotion {
    static let press = Animation.easeOut(duration: 0.10)
    static let content = Animation.easeOut(duration: 0.28)
    static let state = Animation.easeInOut(duration: 0.22)
    static let entrance = Animation.spring(
        response: 0.46,
        dampingFraction: 0.92,
        blendDuration: 0.06
    )
    static let expansion = Animation.spring(
        response: 0.36,
        dampingFraction: 0.90,
        blendDuration: 0.06
    )
    static let navigation = Animation.spring(
        response: 0.40,
        dampingFraction: 0.92,
        blendDuration: 0.06
    )
    static let toast = Animation.spring(
        response: 0.32,
        dampingFraction: 0.90,
        blendDuration: 0.04
    )

    static func entrance(delayIndex: Int) -> Animation {
        entrance.delay(Double(max(delayIndex, 0)) * 0.04)
    }
}

enum PPPetAdViewerSurfaceElevation: Equatable {
    case base
    case raised
}

enum PPPetAdViewerStyle {
    static let sheetRadius: CGFloat = 34
    static let surfaceRadius: CGFloat = 20
    static let insetRadius: CGFloat = 14
    static let infoRadius: CGFloat = 20
    static let descriptionRadius: CGFloat = 22
    static let surfacePadding: CGFloat = 18
    static let compactSurfacePadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 20
    static let contentTopPadding: CGFloat = 30
    static let contentBottomPadding: CGFloat = 36
    static let sheetOverlap: CGFloat = 30
    static let dockControlSize: CGFloat = 60
    static let hairlineWidth: CGFloat = 0.5

    static let heroPeachTop = Color.ppBackground
    static let heroPeachBottom = Color.ppBackground

    static let sheetBackground = Color.ppBackground
    static let actionAccent = Color.ppPrimary
    static let actionForeground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.82)
                : UIColor.white
        }
    )
    static let darkActionFill = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.96, alpha: 1)
                : UIColor(white: 0.055, alpha: 1)
        }
    )
    static let darkActionForeground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.04, alpha: 1)
                : UIColor.white
        }
    )
}

private struct PPPetAdViewerSurfaceModifier: ViewModifier {
    let elevation: PPPetAdViewerSurfaceElevation

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.surfaceRadius,
            style: .continuous
        )
        let isRaised = elevation == .raised
        let shadowOpacity: CGFloat =
            colorScheme == .dark
            ? (isRaised ? 0.22 : 0.08)
            : (isRaised ? 0.07 : 0.025)

        return content
            .background(Color.ppCard, in: shape)
            .overlay {
                shape.stroke(
                    Color(uiColor: .separator).opacity(
                        colorSchemeContrast == .increased ? 0.42 : 0.20
                    ),
                    lineWidth: PPPetAdViewerStyle.hairlineWidth
                )
            }
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: isRaised ? 20 : 8,
                x: 0,
                y: isRaised ? 10 : 3
            )
    }
}

private struct PPPetAdViewerInsetSurfaceModifier: ViewModifier {
    let tint: Color

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.insetRadius,
            style: .continuous
        )

        content
            .background(Color.ppForeground.opacity(0.64), in: shape)
            .overlay {
                shape.stroke(
                    tint.opacity(
                        colorSchemeContrast == .increased ? 0.34 : 0.12
                    ),
                    lineWidth: PPPetAdViewerStyle.hairlineWidth
                )
            }
    }
}

private struct PPPetAdViewerEntranceModifier: ViewModifier {
    let isPresented: Bool
    let delayIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .offset(
                y: reduceMotion || isPresented
                    ? 0
                    : min(12, 7 + CGFloat(delayIndex))
            )
            .scaleEffect(
                reduceMotion || isPresented ? 1 : 0.994,
                anchor: .top
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.16)
                    : PPPetAdViewerMotion.entrance(delayIndex: delayIndex),
                value: isPresented
            )
    }
}

struct PPPetAdSectionHeading: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .ppPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(
                        tint.opacity(0.09),
                        in: RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                Text(title)
                    .font(PPPetAdTypography.title3)
                    .foregroundStyle(Color.ppTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .accessibilityAddTraits(.isHeader)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(PPPetAdTypography.subheadline)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 44)
            }
        }
    }
}

struct PPPetAdPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled
                    ? 1
                    : pressedScale
            )
            .opacity(
                !isEnabled
                    ? 0.48
                    : (configuration.isPressed ? 0.76 : 1)
            )
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.press,
                value: configuration.isPressed
            )
    }
}

struct PPPetAdViewerLayoutMetrics {
    static let navigationControlSize: CGFloat = 52
    static let navigationVerticalPadding: CGFloat = 8
    static let minimumHeroClearance: CGFloat = 18

    let expandedHeroHeight: CGFloat
    let minimumHeroHeight: CGFloat

    init(containerSize: CGSize, safeAreaTop: CGFloat) {
        let navigationHeight =
            Self.navigationControlSize + (Self.navigationVerticalPadding * 2)
        let navigationBarMaxY = safeAreaTop + navigationHeight
        let minimum = navigationBarMaxY + Self.minimumHeroClearance

        let isTablet = containerSize.width >= 700
        let isShortPhone = containerSize.height < 720
        let widthDrivenHeight =
            containerSize.width * (isTablet ? 0.72 : 1.16)
        let viewportRatio: CGFloat =
            isTablet ? 0.56 : (isShortPhone ? 0.54 : 0.57)
        let maximumHeight: CGFloat = isTablet ? 600 : 540
        let viewportCap = max(
            minimum + 96,
            min(maximumHeight, containerSize.height * viewportRatio)
        )
        let preferredFloor: CGFloat =
            isTablet ? 440 : (isShortPhone ? 340 : 420)
        let preferred = min(
            max(widthDrivenHeight, preferredFloor),
            viewportCap
        )

        minimumHeroHeight = minimum
        expandedHeroHeight = max(minimum + 96, preferred)
    }
}

private struct PPPetAdGlassSurfaceModifier<Surface: Shape>: ViewModifier {
    let shape: Surface
    let tint: Color
    let fallback: Color
    let stroke: Color
    let lineWidth: CGFloat

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                glassBackground
            }
            .overlay {
                shape.stroke(stroke, lineWidth: lineWidth)
            }
    }

    @ViewBuilder
    private var glassBackground: some View {
        if reduceTransparency {
            shape.fill(fallback)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(tint)
                }
        }
    }
}

extension View {
    func ppGlassSurface<Surface: Shape>(
        in shape: Surface,
        tint: Color = .clear,
        fallback: Color = Color(uiColor: .secondarySystemBackground),
        stroke: Color = Color.white.opacity(0.18),
        lineWidth: CGFloat = 0.75
    ) -> some View {
        modifier(
            PPPetAdGlassSurfaceModifier(
                shape: shape,
                tint: tint,
                fallback: fallback,
                stroke: stroke,
                lineWidth: lineWidth
            )
        )
    }

    func ppPetAdSurface(
        elevation: PPPetAdViewerSurfaceElevation = .base
    ) -> some View {
        modifier(PPPetAdViewerSurfaceModifier(elevation: elevation))
    }

    func ppPetAdInsetSurface(tint: Color = .ppPrimary) -> some View {
        modifier(PPPetAdViewerInsetSurfaceModifier(tint: tint))
    }

    func ppPetAdEntrance(
        isPresented: Bool,
        delayIndex: Int
    ) -> some View {
        modifier(
            PPPetAdViewerEntranceModifier(
                isPresented: isPresented,
                delayIndex: delayIndex
            )
        )
    }

}
