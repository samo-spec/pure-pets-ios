#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public struct PPChatCellStyle {
    public var brand: Color
    public var cornerRadius: CGFloat
    public var compactCornerRadius: CGFloat
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

    public init(
        brand: Color,
        cornerRadius: CGFloat = 28,
        compactCornerRadius: CGFloat = 17,
        avatarSize: CGFloat = 54,
        outerHorizontalInset: CGFloat = 14,
        outerVerticalInset: CGFloat = 5,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 13,
        rowSpacing: CGFloat = 12,
        sectionSpacing: CGFloat = 16,
        minimumSummaryHeight: CGFloat = 78,
        minimumTouchTarget: CGFloat = 44,
        composerHeight: CGFloat = 48
    ) {
        self.brand = brand
        self.cornerRadius = cornerRadius
        self.compactCornerRadius = compactCornerRadius
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
