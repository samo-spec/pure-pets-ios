import SwiftUI

enum PPPromoCarouselMetrics {
  static func cardWidth(containerWidth: CGFloat) -> CGFloat {
    let ratioWidth = containerWidth * PPPromoTheme.cardWidthRatio
    let maximumWidth = containerWidth - PPPromoTheme.minimumPeek * 2
    return max(0, min(ratioWidth, maximumWidth))
  }

  static func cardHeight(cardWidth: CGFloat, usesAccessibilityType: Bool) -> CGFloat {
    let baseHeight = cardWidth / PPPromoTheme.cardAspectRatio
    return baseHeight + (usesAccessibilityType ? 92 : 0)
  }

  static func scale(relativeProgress: CGFloat) -> CGFloat {
    1 - min(abs(relativeProgress), 1) * 0.065
  }

  static func rotation(relativeProgress: CGFloat) -> Double {
    Double(max(-1, min(1, relativeProgress)) * -5.5)
  }

  static func verticalOffset(relativeProgress: CGFloat) -> CGFloat {
    min(abs(relativeProgress), 1) * 8
  }

  static func opacity(relativeProgress: CGFloat) -> Double {
    Double(1 - min(abs(relativeProgress), 1) * 0.30)
  }

  static func zIndex(relativeProgress: CGFloat) -> Double {
    Double(10 - abs(relativeProgress))
  }
}
