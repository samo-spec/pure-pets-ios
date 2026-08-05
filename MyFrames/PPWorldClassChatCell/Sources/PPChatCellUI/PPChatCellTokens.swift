#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public struct PPChatCellStyle {
    public var brand: Color
    public var cornerRadius: CGFloat
    public var compactCornerRadius: CGFloat
    public var avatarSize: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var rowSpacing: CGFloat
    public var sectionSpacing: CGFloat
    public var minimumSummaryHeight: CGFloat
    public var minimumTouchTarget: CGFloat
    public var composerHeight: CGFloat

    public init(
        brand: Color,
        cornerRadius: CGFloat = 22,
        compactCornerRadius: CGFloat = 15,
        avatarSize: CGFloat = 52,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 12,
        rowSpacing: CGFloat = 10,
        sectionSpacing: CGFloat = 14,
        minimumSummaryHeight: CGFloat = 76,
        minimumTouchTarget: CGFloat = 44,
        composerHeight: CGFloat = 52
    ) {
        self.brand = brand
        self.cornerRadius = cornerRadius
        self.compactCornerRadius = compactCornerRadius
        self.avatarSize = avatarSize
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.rowSpacing = rowSpacing
        self.sectionSpacing = sectionSpacing
        self.minimumSummaryHeight = minimumSummaryHeight
        self.minimumTouchTarget = max(44, minimumTouchTarget)
        self.composerHeight = max(44, composerHeight)
    }

    public static let purePets = PPChatCellStyle(
        brand: Color(red: 203 / 255, green: 38 / 255, blue: 84 / 255)
    )
}

extension PPChatCellStyle {
    var opaqueSurface: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    var quietFill: Color {
        Color(uiColor: .tertiarySystemFill)
    }

    var separator: Color {
        Color(uiColor: .separator)
    }
}
#endif
