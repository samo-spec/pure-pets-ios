import Foundation
import SwiftUI
import UIKit

public enum PurePetsMessagingTheme {
  // MARK: - Brand and signal

  public static let brand = Color(red: 0.796, green: 0.149, blue: 0.329)
  public static let brandDeep = adaptive(
    light: UIColor(red: 0.435, green: 0.075, blue: 0.172, alpha: 1),
    dark: UIColor(red: 0.800, green: 0.235, blue: 0.430, alpha: 1),
    highContrastLight: UIColor(red: 0.345, green: 0.035, blue: 0.120, alpha: 1),
    highContrastDark: UIColor(red: 1.000, green: 0.395, blue: 0.590, alpha: 1)
  )
  public static let brandSoft = adaptive(
    light: UIColor(red: 0.984, green: 0.914, blue: 0.937, alpha: 1),
    dark: UIColor(red: 0.285, green: 0.085, blue: 0.145, alpha: 1),
    highContrastLight: UIColor(red: 0.970, green: 0.850, blue: 0.895, alpha: 1),
    highContrastDark: UIColor(red: 0.355, green: 0.090, blue: 0.175, alpha: 1)
  )
  public static let signal = adaptive(
    light: UIColor(red: 0.796, green: 0.149, blue: 0.329, alpha: 1),
    dark: UIColor(red: 0.965, green: 0.475, blue: 0.620, alpha: 1),
    highContrastLight: UIColor(red: 0.690, green: 0.055, blue: 0.245, alpha: 1),
    highContrastDark: UIColor(red: 1.000, green: 0.560, blue: 0.700, alpha: 1)
  )
  public static let signalForeground = adaptive(
    light: .white,
    dark: UIColor(white: 0.055, alpha: 1),
    highContrastLight: .white,
    highContrastDark: .black
  )

  // MARK: - Environmental layers

  public static let canvas = adaptive(
    light: UIColor(red: 0.956, green: 0.946, blue: 0.928, alpha: 1),
    dark: UIColor(red: 0.041, green: 0.045, blue: 0.047, alpha: 1),
    highContrastLight: UIColor(red: 0.930, green: 0.918, blue: 0.895, alpha: 1),
    highContrastDark: UIColor(red: 0.018, green: 0.020, blue: 0.021, alpha: 1)
  )
  public static let ambientWarm = adaptive(
    light: UIColor(red: 0.925, green: 0.822, blue: 0.755, alpha: 0.54),
    dark: UIColor(red: 0.360, green: 0.205, blue: 0.178, alpha: 0.24),
    highContrastLight: UIColor.clear,
    highContrastDark: UIColor.clear
  )
  public static let ambientSignal = adaptive(
    light: UIColor(red: 0.796, green: 0.149, blue: 0.329, alpha: 0.075),
    dark: UIColor(red: 0.965, green: 0.475, blue: 0.620, alpha: 0.075),
    highContrastLight: UIColor.clear,
    highContrastDark: UIColor.clear
  )
  public static let surface = adaptive(
    light: UIColor(red: 0.994, green: 0.986, blue: 0.969, alpha: 0.98),
    dark: UIColor(red: 0.085, green: 0.091, blue: 0.094, alpha: 0.98),
    highContrastLight: UIColor.white,
    highContrastDark: UIColor(red: 0.105, green: 0.112, blue: 0.116, alpha: 1)
  )
  public static let surfaceRaised = adaptive(
    light: UIColor(red: 1.000, green: 0.997, blue: 0.989, alpha: 1),
    dark: UIColor(red: 0.115, green: 0.121, blue: 0.124, alpha: 1),
    highContrastLight: .white,
    highContrastDark: UIColor(red: 0.145, green: 0.151, blue: 0.154, alpha: 1)
  )
  public static let surfaceStroke = adaptive(
    light: UIColor(white: 0.08, alpha: 0.085),
    dark: UIColor(white: 1, alpha: 0.12),
    highContrastLight: UIColor(white: 0, alpha: 0.24),
    highContrastDark: UIColor(white: 1, alpha: 0.30)
  )

  // MARK: - Message surfaces

  public static let outgoingBubbleSurface = adaptive(
    light: UIColor(red: 0.690, green: 0.070, blue: 0.270, alpha: 1),
    dark: UIColor(red: 0.785, green: 0.135, blue: 0.345, alpha: 1),
    highContrastLight: UIColor(red: 0.560, green: 0.020, blue: 0.200, alpha: 1),
    highContrastDark: UIColor(red: 0.750, green: 0.080, blue: 0.320, alpha: 1)
  )
  public static let outgoingBubbleDepth = adaptive(
    light: UIColor(red: 0.455, green: 0.025, blue: 0.155, alpha: 1),
    dark: UIColor(red: 0.535, green: 0.050, blue: 0.215, alpha: 1),
    highContrastLight: UIColor(red: 0.320, green: 0.000, blue: 0.080, alpha: 1),
    highContrastDark: UIColor(red: 0.460, green: 0.015, blue: 0.150, alpha: 1)
  )
  public static let incomingSurface = adaptive(
    light: UIColor(red: 1.000, green: 0.993, blue: 0.976, alpha: 1),
    dark: UIColor(red: 0.096, green: 0.103, blue: 0.107, alpha: 1),
    highContrastLight: UIColor.white,
    highContrastDark: UIColor(red: 0.125, green: 0.133, blue: 0.138, alpha: 1)
  )
  public static let incomingSurfaceDepth = adaptive(
    light: UIColor(red: 0.974, green: 0.954, blue: 0.921, alpha: 1),
    dark: UIColor(red: 0.067, green: 0.073, blue: 0.076, alpha: 1),
    highContrastLight: UIColor(red: 0.948, green: 0.925, blue: 0.886, alpha: 1),
    highContrastDark: UIColor(red: 0.082, green: 0.089, blue: 0.093, alpha: 1)
  )
  public static let outgoingBubbleStroke = adaptive(
    light: UIColor(white: 1, alpha: 0.22),
    dark: UIColor(white: 1, alpha: 0.21),
    highContrastLight: UIColor(white: 1, alpha: 0.42),
    highContrastDark: UIColor(white: 1, alpha: 0.44)
  )
  public static let incomingBubbleStroke = surfaceStroke
  public static let replySurface = adaptive(
    light: UIColor(white: 0.08, alpha: 0.050),
    dark: UIColor(white: 1, alpha: 0.075),
    highContrastLight: UIColor(white: 0, alpha: 0.090),
    highContrastDark: UIColor(white: 1, alpha: 0.125)
  )
  public static let reactionSurface = adaptive(
    light: UIColor(red: 1.000, green: 0.993, blue: 0.980, alpha: 0.98),
    dark: UIColor(red: 0.122, green: 0.129, blue: 0.133, alpha: 0.98),
    highContrastLight: .white,
    highContrastDark: UIColor(red: 0.155, green: 0.163, blue: 0.168, alpha: 1)
  )
  public static let mediaChrome = adaptive(
    light: UIColor(white: 0.02, alpha: 0.64),
    dark: UIColor(white: 0, alpha: 0.72),
    highContrastLight: UIColor(white: 0, alpha: 1),
    highContrastDark: UIColor(white: 0, alpha: 1)
  )

  public static var outgoingBubbleGradient: LinearGradient {
    LinearGradient(
      colors: [outgoingBubbleSurface, outgoingBubbleDepth],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  public static var incomingBubbleGradient: LinearGradient {
    LinearGradient(
      colors: [incomingSurface, incomingSurfaceDepth],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  // MARK: - Identity and status

  public static let avatarSurface = adaptive(
    light: UIColor(red: 0.920, green: 0.885, blue: 0.848, alpha: 1),
    dark: UIColor(red: 0.160, green: 0.170, blue: 0.174, alpha: 1),
    highContrastLight: UIColor(red: 0.865, green: 0.810, blue: 0.755, alpha: 1),
    highContrastDark: UIColor(red: 0.205, green: 0.216, blue: 0.221, alpha: 1)
  )
  public static let avatarDepth = adaptive(
    light: UIColor(red: 0.845, green: 0.765, blue: 0.710, alpha: 1),
    dark: UIColor(red: 0.255, green: 0.150, blue: 0.185, alpha: 1),
    highContrastLight: UIColor(red: 0.775, green: 0.665, blue: 0.595, alpha: 1),
    highContrastDark: UIColor(red: 0.330, green: 0.165, blue: 0.215, alpha: 1)
  )
  public static var avatarGradient: LinearGradient {
    LinearGradient(
      colors: [avatarSurface, avatarDepth],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
  public static let avatarForeground = adaptive(
    light: UIColor(white: 0.18, alpha: 1),
    dark: UIColor(white: 0.95, alpha: 1),
    highContrastLight: .black,
    highContrastDark: .white
  )
  public static let messageShadow = adaptive(
    light: UIColor(white: 0.12, alpha: 0.12),
    dark: UIColor(white: 0, alpha: 0.34),
    highContrastLight: UIColor(white: 0, alpha: 0.18),
    highContrastDark: UIColor(white: 0, alpha: 0.48)
  )
  public static let conversationBackground = canvas
  public static let subduedText = Color.secondary
  public static let success = Color(uiColor: .systemGreen)
  public static let danger = Color(uiColor: .systemRed)

  // MARK: - Waveform

  static var waveformPlayedGradient: LinearGradient {
    LinearGradient(
      colors: [signal, brandDeep],
      startPoint: .bottom,
      endPoint: .top
    )
  }

  static func waveformTrack(_: ColorScheme) -> Color {
    adaptive(
      light: UIColor(white: 0, alpha: 0.38),
      dark: UIColor(white: 1, alpha: 0.34),
      highContrastLight: UIColor(white: 0, alpha: 0.58),
      highContrastDark: UIColor(white: 1, alpha: 0.58)
    )
  }

  // MARK: - Color construction

  private static func adaptive(
    light: UIColor,
    dark: UIColor,
    highContrastLight: UIColor,
    highContrastDark: UIColor
  ) -> Color {
    Color(uiColor: UIColor { traits in
      switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
      case (.dark, .high): highContrastDark
      case (.dark, _): dark
      case (_, .high): highContrastLight
      default: light
      }
    })
  }
}

// MARK: - Shared motion

enum PurePetsMessagingMotion {
  /// Strong ease-out used for feedback that must feel immediate.
  static let quick: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.16)
  /// Shared studio transition for state changes already on screen.
  static let standard: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
  /// Directional, transform-only message entrance with no overshoot.
  static let entrance: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.28)
  /// Interruptible settlement for the direct-manipulation reply gesture.
  static let replySettlement: Animation = .interactiveSpring(
    response: 0.25,
    dampingFraction: 0.88,
    blendDuration: 0.08
  )
  static let status: Animation = quick
  static let progress: Animation = .easeInOut(duration: 0.24)
  static let waveBar: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
}

public struct PurePetsMessagingPressButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    let animation: Animation = {
      if reduceMotion {
        return .easeOut(duration: 0.08)
      }
      return .timingCurve(
        0.23,
        1,
        0.32,
        1,
        duration: configuration.isPressed ? 0.16 : 0.10
      )
    }()

    return configuration.label
      .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
      .opacity(configuration.isPressed ? 0.84 : 1)
      .animation(animation, value: configuration.isPressed)
  }
}

enum PurePetsMessageTextDirection {
  static func resolve(
    _ text: String,
    fallback: LayoutDirection
  ) -> LayoutDirection {
    for scalar in text.unicodeScalars {
      if isRightToLeft(scalar.value) {
        return .rightToLeft
      }
      if CharacterSet.letters.contains(scalar) {
        return .leftToRight
      }
    }
    return fallback
  }

  private static func isRightToLeft(_ value: UInt32) -> Bool {
    switch value {
    case 0x0590...0x08FF,
         0xFB1D...0xFDFF,
         0xFE70...0xFEFF,
         0x10800...0x10FFF:
      return true
    default:
      return false
    }
  }
}

enum PurePetsMessageDurationFormatter {
  static func string(
    for duration: TimeInterval,
    locale: Locale
  ) -> String {
    let totalSeconds = max(Int(duration.rounded()), 0)
    let number = IntegerFormatStyle<Int>.number.locale(locale)
    let twoDigits = number.precision(.integerLength(2))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = (totalSeconds % 60).formatted(twoDigits)
    if hours > 0 {
      return "\(hours.formatted(number)):\(minutes.formatted(twoDigits)):\(seconds)"
    }
    return "\(minutes.formatted(number)):\(seconds)"
  }
}

// MARK: - Font Tokens

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
