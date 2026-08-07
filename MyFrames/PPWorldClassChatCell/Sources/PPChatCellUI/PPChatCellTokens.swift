#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public struct PPChatCellStyle {
    public var brand: Color
    public var cornerRadius: CGFloat
    public var compactCornerRadius: CGFloat
    /// Corner radius of the resting (collapsed) card. Kept close to the
    /// expanded radius so the shape morph reads as one seamless surface.
    public var collapsedCornerRadius: CGFloat
    public var avatarSize: CGFloat
    public var outerHorizontalInset: CGFloat
    public var outerVerticalInset: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var rowSpacing: CGFloat
    public var sectionSpacing: CGFloat
    public var minimumSummaryHeight: CGFloat
    public var minimumTouchTarget: CGFloat
    public var composerHeight: CGFloat
    /// Fixed elevation blur radius. NEVER animated — only the shadow's
    /// opacity animates between states, which is what keeps the shadow
    /// perfectly stable (no trembling) while the card resizes.
    public var shadowRadius: CGFloat
    /// Fixed elevation vertical offset. NEVER animated.
    public var shadowYOffset: CGFloat

    public init(
        brand: Color,
        cornerRadius: CGFloat = 26,
        compactCornerRadius: CGFloat = 17,
        collapsedCornerRadius: CGFloat = 22,
        avatarSize: CGFloat = 54,
        outerHorizontalInset: CGFloat = 14,
        outerVerticalInset: CGFloat = 7,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 13,
        rowSpacing: CGFloat = 12,
        sectionSpacing: CGFloat = 16,
        minimumSummaryHeight: CGFloat = 78,
        minimumTouchTarget: CGFloat = 44,
        composerHeight: CGFloat = 48,
        shadowRadius: CGFloat = 14,
        shadowYOffset: CGFloat = 6
    ) {
        self.brand = brand
        self.cornerRadius = cornerRadius
        self.compactCornerRadius = compactCornerRadius
        self.collapsedCornerRadius = collapsedCornerRadius
        self.avatarSize = avatarSize
        self.outerHorizontalInset = outerHorizontalInset
        self.outerVerticalInset = outerVerticalInset
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.rowSpacing = rowSpacing
        self.sectionSpacing = sectionSpacing
        self.minimumSummaryHeight = minimumSummaryHeight
        self.minimumTouchTarget = max(44, minimumTouchTarget)
        self.composerHeight = max(44, composerHeight)
        self.shadowRadius = max(0, shadowRadius)
        self.shadowYOffset = shadowYOffset
    }

    public static let purePets = PPChatCellStyle(
        brand: Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(
                    red: 255 / 255,
                    green: 155 / 255,
                    blue: 150 / 255,
                    alpha: 1
                )
            }

            return UIColor(
                red: 203 / 255,
                green: 38 / 255,
                blue: 84 / 255,
                alpha: 1
            )
        })
    )
}

extension PPChatCellStyle {
    var opaqueSurface: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    var elevatedSurface: Color {
        Color(uiColor: .systemBackground)
    }

    var replyDockSurface: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }

    var quietFill: Color {
        Color(uiColor: .tertiarySystemFill)
    }

    var brandSoft: Color {
        brand.opacity(0.10)
    }

    var separator: Color {
        Color(uiColor: .separator)
    }

    var success: Color {
        Color(uiColor: .systemGreen)
    }

    var danger: Color {
        Color(uiColor: .systemRed)
    }

    // MARK: - Elevation

    /// Base color of the drop shadow. Warm-neutral so the elevation reads as
    /// depth rather than a grey smudge.
    var shadowColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
            ? UIColor.black
            : UIColor(red: 0.09, green: 0.05, blue: 0.07, alpha: 1)
        })
    }

    /// Resting elevation opacity — a whisper of depth so collapsed rows read
    /// as floating cards without visual noise.
    func restingShadowOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.22 : 0.055
    }

    /// Lifted elevation opacity while expanded. The delta from resting is what
    /// animates (opacity only — radius stays fixed), producing a smooth,
    /// tremor-free lift.
    func liftedShadowOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.40 : 0.14
    }

    /// A one-pixel top highlight → bottom shade gradient used for the card
    /// border so the surface catches light like a physical card.
    func hairlineBorder(_ scheme: ColorScheme, contrast: ColorSchemeContrast) -> LinearGradient {
        if contrast == .increased {
            return LinearGradient(
                colors: [separator.opacity(0.9), separator.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        let top = scheme == .dark
            ? Color.white.opacity(0.14)
            : Color.white.opacity(0.9)
        let bottom = scheme == .dark
            ? Color.black.opacity(0.28)
            : separator.opacity(0.42)

        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

public extension Font {
    static func ppBeirutiBold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "Beiruti-Bold", size: size) != nil {
            return .custom("Beiruti-Bold", size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .bold)
    }

    static func ppBeirutiSemiBold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "Beiruti-SemiBold", size: size) != nil {
            return .custom("Beiruti-SemiBold", size: size, relativeTo: textStyle)
        } else if UIFont(name: "Beiruti-Bold", size: size) != nil {
            return .custom("Beiruti-Bold", size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .semibold)
    }

    static func ppBeirutiMedium(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "Beiruti-Medium", size: size) != nil {
            return .custom("Beiruti-Medium", size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .medium)
    }

    static func ppBeirutiRegular(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "Beiruti-Regular", size: size) != nil {
            return .custom("Beiruti-Regular", size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .regular)
    }

    static func ppBeirutiBlack(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if UIFont(name: "Beiruti-Black", size: size) != nil {
            return .custom("Beiruti-Black", size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .black)
    }
}
#endif
