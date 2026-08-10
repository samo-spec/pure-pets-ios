import SwiftUI
import UIKit

// MARK: - Style Configuration

public struct SpearChatHeaderStyle {
  public var brandColor: Color
  public var mainBackgroundColor: Color
  public var cornerRadius: CGFloat
  public var horizontalPadding: CGFloat

  public init(
    brandColor: Color = Color(
      red: 203.0 / 255.0,
      green: 38.0 / 255.0,
      blue: 84.0 / 255.0
    ),
    mainBackgroundColor: Color = Color(
      uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(
            red: 14.0 / 255.0,
            green: 11.0 / 255.0,
            blue: 12.0 / 255.0,
            alpha: 1
          )
          : UIColor(
            red: 248.0 / 255.0,
            green: 248.0 / 255.0,
            blue: 249.0 / 255.0,
            alpha: 1
          )
      }
    ),
    cornerRadius: CGFloat = 18,
    horizontalPadding: CGFloat = 12
  ) {
    self.brandColor = brandColor
    self.mainBackgroundColor = mainBackgroundColor
    self.cornerRadius = cornerRadius
    self.horizontalPadding = horizontalPadding
  }

  public static let spear = SpearChatHeaderStyle()
}

// MARK: - Layout Tokens

internal enum SpearHeaderLayout {
  static let maximumContentWidth: CGFloat = 720
  static let topRowSpacing: CGFloat = 10
  static let deckSpacing: CGFloat = 7
  static let deckCornerRadius: CGFloat = 18
  static let avatarMaximumSize: CGFloat = 50
}

// MARK: - Motion Tokens

internal enum SpearHeaderMotion {
  static let quick = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.16)
  static let standard = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
  static let exit = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
  static let liveIndicator = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
  static let deck = Animation.timingCurve(0.20, 0.82, 0.24, 1, duration: 0.26)

  static func press(isPressed: Bool) -> Animation {
    .timingCurve(
      0.23,
      1,
      0.32,
      1,
      duration: isPressed ? 0.14 : 0.10
    )
  }
}

// MARK: - Status Colors

internal enum SpearHeaderSemanticColor {
  static let live = adaptive(
    light: UIColor(red: 22.0 / 255.0, green: 115.0 / 255.0, blue: 75.0 / 255.0, alpha: 1),
    dark: UIColor(red: 80.0 / 255.0, green: 224.0 / 255.0, blue: 138.0 / 255.0, alpha: 1),
    highContrastLight: UIColor(
      red: 11.0 / 255.0, green: 92.0 / 255.0, blue: 59.0 / 255.0, alpha: 1),
    highContrastDark: UIColor(
      red: 105.0 / 255.0, green: 240.0 / 255.0, blue: 163.0 / 255.0, alpha: 1)
  )
  static let liveForeground = adaptive(
    light: .white,
    dark: UIColor(red: 14.0 / 255.0, green: 11.0 / 255.0, blue: 12.0 / 255.0, alpha: 1),
    highContrastLight: .white,
    highContrastDark: .black
  )
  static let warning = adaptive(
    light: UIColor(red: 138.0 / 255.0, green: 74.0 / 255.0, blue: 0, alpha: 1),
    dark: UIColor(red: 255.0 / 255.0, green: 177.0 / 255.0, blue: 90.0 / 255.0, alpha: 1),
    highContrastLight: UIColor(red: 111.0 / 255.0, green: 56.0 / 255.0, blue: 0, alpha: 1),
    highContrastDark: UIColor(
      red: 255.0 / 255.0, green: 196.0 / 255.0, blue: 119.0 / 255.0, alpha: 1)
  )

  private static func adaptive(
    light: UIColor,
    dark: UIColor,
    highContrastLight: UIColor,
    highContrastDark: UIColor
  ) -> Color {
    Color(
      uiColor: UIColor { traits in
        switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
        case (.dark, .high): highContrastDark
        case (.dark, _): dark
        case (_, .high): highContrastLight
        default: light
        }
      })
  }
}

// MARK: - Motion Mode

internal enum SpearMotionMode: Equatable {
  case none
  case onlinePresence
  case typing
  case activeCall

  init(presence: SpearPresence, call: SpearCallControl) {
    if call.isActive {
      self = .activeCall
      return
    }

    switch presence {
    case .typing:
      self = .typing
    case .online:
      self = .onlinePresence
    case .viewingOffer, .offline:
      self = .none
    }
  }
}

// MARK: - Font Tokens

extension Font {
  public static func ppBeirutiBold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body)
    -> Font
  {
    if UIFont(name: "Beiruti-Bold", size: size) != nil {
      return .custom("Beiruti-Bold", size: size, relativeTo: textStyle)
    }
    return .system(size: size, weight: .bold)
  }

  public static func ppBeirutiSemiBold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body)
    -> Font
  {
    if UIFont(name: "Beiruti-SemiBold", size: size) != nil {
      return .custom("Beiruti-SemiBold", size: size, relativeTo: textStyle)
    } else if UIFont(name: "Beiruti-Bold", size: size) != nil {
      return .custom("Beiruti-Bold", size: size, relativeTo: textStyle)
    }
    return .system(size: size, weight: .semibold)
  }

  public static func ppBeirutiMedium(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body)
    -> Font
  {
    if UIFont(name: "Beiruti-Medium", size: size) != nil {
      return .custom("Beiruti-Medium", size: size, relativeTo: textStyle)
    }
    return .system(size: size, weight: .medium)
  }

  public static func ppBeirutiRegular(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body)
    -> Font
  {
    if UIFont(name: "Beiruti-Regular", size: size) != nil {
      return .custom("Beiruti-Regular", size: size, relativeTo: textStyle)
    }
    return .system(size: size, weight: .regular)
  }

  public static func ppBeirutiBlack(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body)
    -> Font
  {
    if UIFont(name: "Beiruti-Black", size: size) != nil {
      return .custom("Beiruti-Black", size: size, relativeTo: textStyle)
    }
    return .system(size: size, weight: .black)
  }
}
