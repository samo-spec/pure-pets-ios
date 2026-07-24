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
    static let press = Animation.easeOut(duration: 0.14)
    static let content = Animation.easeOut(duration: 0.28)
    static let expansion = Animation.spring(
        response: 0.38,
        dampingFraction: 0.86,
        blendDuration: 0.08
    )
    static let navigation = Animation.spring(
        response: 0.44,
        dampingFraction: 0.88,
        blendDuration: 0.10
    )
    static let toast = Animation.spring(
        response: 0.34,
        dampingFraction: 0.84,
        blendDuration: 0.06
    )
}

struct PPPetAdPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed
                    ? 1
                    : pressedScale
            )
            .opacity(configuration.isPressed ? 0.80 : 1)
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.press,
                value: configuration.isPressed
            )
    }
}

struct PPPetAdScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = nextValue()
    }
}

struct PPPetAdViewerLayoutMetrics {
    static let navigationControlSize: CGFloat = 44
    static let navigationVerticalPadding: CGFloat = 8
    static let minimumHeroClearance: CGFloat = 18

    let expandedHeroHeight: CGFloat
    let minimumHeroHeight: CGFloat

    init(containerSize: CGSize, safeAreaTop: CGFloat) {
        let navigationHeight =
            Self.navigationControlSize + (Self.navigationVerticalPadding * 2)
        let minimum =
            safeAreaTop + navigationHeight + Self.minimumHeroClearance

        let widthDrivenHeight = containerSize.width * 1.06
        let viewportCap = max(
            minimum + 120,
            min(540, containerSize.height * 0.68)
        )
        let preferred = min(max(widthDrivenHeight, 360), viewportCap)

        minimumHeroHeight = minimum
        expandedHeroHeight = max(minimum + 120, preferred)
    }

    var collapseDistance: CGFloat {
        max(expandedHeroHeight - minimumHeroHeight, 1)
    }

    func heroHeight(for scrollOffset: CGFloat) -> CGFloat {
        max(minimumHeroHeight, expandedHeroHeight + scrollOffset)
    }

    func collapseProgress(for scrollOffset: CGFloat) -> CGFloat {
        min(max(-scrollOffset / collapseDistance, 0), 1)
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
}
