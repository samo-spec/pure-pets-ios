import SwiftUI

enum PPPromoTheme {
  static let brandPrimary = Color(ppHex: "CB2654", fallback: .pink)
  static let pressedAction = Color(ppHex: "A91E46", fallback: .pink)
  static let mainBackground = Color(ppHex: "F8F8F9", fallback: Color(uiColor: .systemBackground))
  static let surface = Color(ppHex: "FFFFFF", fallback: Color(uiColor: .secondarySystemBackground))
  static let elevatedSurface = Color(
    ppHex: "FFFDFC", fallback: Color(uiColor: .secondarySystemBackground))
  static let warmPorcelain = Color(
    ppHex: "F7F1ED", fallback: Color(uiColor: .tertiarySystemBackground))
  static let mineralBeige = Color(ppHex: "EEE3DA", fallback: Color(uiColor: .separator))
  static let softRose = Color(ppHex: "F6E2E8", fallback: .pink.opacity(0.12))
  static let promoTextPrimary = Color(ppHex: "21191C", fallback: .black)
  static let promoTextSecondary = Color(ppHex: "756E70", fallback: .gray)

  static let cardCornerRadius: CGFloat = 30
  static let cardAspectRatio: CGFloat = 1.42
  static let cardWidthRatio: CGFloat = 0.82
  static let cardSpacing: CGFloat = 14
  static let minimumPeek: CGFloat = 22

  static let titleFont = Font.custom("Beiruti", size: 27, relativeTo: .title2).weight(.bold)
  static let subtitleFont = Font.custom("Beiruti", size: 17, relativeTo: .body).weight(.regular)
  static let buttonFont = Font.custom("Beiruti", size: 18, relativeTo: .headline).weight(.semibold)
  static let badgeFont = Font.custom("Beiruti", size: 13, relativeTo: .caption).weight(.semibold)

  static let snapAnimation = Animation.interpolatingSpring(
    mass: 0.78,
    stiffness: 280,
    damping: 30,
    initialVelocity: 0
  )

  static let reducedMotionAnimation = Animation.easeOut(duration: 0.16)
}
