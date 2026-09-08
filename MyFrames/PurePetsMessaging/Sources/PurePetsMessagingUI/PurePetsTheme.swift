import Foundation
import SwiftUI
import UIKit

public enum PurePetsMessagingTheme {
  // MARK: - Brand and Signal (Pure Pets Signature Palette)

  public static let brand = Color(red: 0.722, green: 0.196, blue: 0.325) // #B83253

  public static let brandDeep = adaptive(
    light: UIColor(red: 0.520, green: 0.095, blue: 0.210, alpha: 1),
    dark: UIColor(red: 0.820, green: 0.250, blue: 0.410, alpha: 1),
    highContrastLight: UIColor(red: 0.400, green: 0.050, blue: 0.150, alpha: 1),
    highContrastDark: UIColor(red: 0.980, green: 0.380, blue: 0.550, alpha: 1)
  )

  public static let brandSoft = adaptive(
    light: UIColor(red: 0.985, green: 0.925, blue: 0.940, alpha: 1),
    dark: UIColor(red: 0.260, green: 0.080, blue: 0.135, alpha: 1),
    highContrastLight: UIColor(red: 0.965, green: 0.880, blue: 0.910, alpha: 1),
    highContrastDark: UIColor(red: 0.340, green: 0.090, blue: 0.170, alpha: 1)
  )

  public static let signal = adaptive(
    light: UIColor(red: 0.722, green: 0.196, blue: 0.325, alpha: 1),
    dark: UIColor(red: 0.965, green: 0.485, blue: 0.615, alpha: 1),
    highContrastLight: UIColor(red: 0.620, green: 0.080, blue: 0.220, alpha: 1),
    highContrastDark: UIColor(red: 1.000, green: 0.550, blue: 0.680, alpha: 1)
  )

  public static let signalForeground = adaptive(
    light: .white,
    dark: UIColor(white: 0.055, alpha: 1),
    highContrastLight: .white,
    highContrastDark: .black
  )

  // MARK: - Environmental Layers

  public static let canvas = adaptive(
    light: UIColor(red: 0.965, green: 0.960, blue: 0.950, alpha: 1),
    dark: UIColor(red: 0.055, green: 0.050, blue: 0.055, alpha: 1),
    highContrastLight: UIColor(red: 0.940, green: 0.935, blue: 0.925, alpha: 1),
    highContrastDark: UIColor(red: 0.020, green: 0.020, blue: 0.020, alpha: 1)
  )

  public static let ambientWarm = adaptive(
    light: UIColor(red: 0.950, green: 0.880, blue: 0.840, alpha: 0.45),
    dark: UIColor(red: 0.320, green: 0.160, blue: 0.180, alpha: 0.22),
    highContrastLight: UIColor.clear,
    highContrastDark: UIColor.clear
  )

  public static let ambientSignal = adaptive(
    light: UIColor(red: 0.722, green: 0.196, blue: 0.325, alpha: 0.070),
    dark: UIColor(red: 0.965, green: 0.485, blue: 0.615, alpha: 0.070),
    highContrastLight: UIColor.clear,
    highContrastDark: UIColor.clear
  )

  public static let surface = adaptive(
    light: UIColor(red: 0.995, green: 0.992, blue: 0.985, alpha: 0.98),
    dark: UIColor(red: 0.095, green: 0.090, blue: 0.098, alpha: 0.98),
    highContrastLight: UIColor.white,
    highContrastDark: UIColor(red: 0.110, green: 0.105, blue: 0.115, alpha: 1)
  )

  public static let surfaceRaised = adaptive(
    light: UIColor.white,
    dark: UIColor(red: 0.130, green: 0.125, blue: 0.135, alpha: 1),
    highContrastLight: .white,
    highContrastDark: UIColor(red: 0.155, green: 0.150, blue: 0.160, alpha: 1)
  )

  public static let surfaceStroke = adaptive(
    light: UIColor(white: 0.08, alpha: 0.075),
    dark: UIColor(white: 1.00, alpha: 0.110),
    highContrastLight: UIColor(white: 0, alpha: 0.22),
    highContrastDark: UIColor(white: 1, alpha: 0.30)
  )

  // MARK: - Message Surfaces (Vibrant Ruby & Ceramic Alabaster)

  public static let outgoingBubbleSurface = adaptive(
    light: UIColor(red: 0.722, green: 0.196, blue: 0.325, alpha: 1), // PurePets Ruby
    dark: UIColor(red: 0.785, green: 0.225, blue: 0.370, alpha: 1),
    highContrastLight: UIColor(red: 0.600, green: 0.080, blue: 0.210, alpha: 1),
    highContrastDark: UIColor(red: 0.850, green: 0.180, blue: 0.380, alpha: 1)
  )

  public static let outgoingBubbleDepth = adaptive(
    light: UIColor(red: 0.540, green: 0.100, blue: 0.215, alpha: 1), // Deep Luxury Ruby
    dark: UIColor(red: 0.590, green: 0.120, blue: 0.245, alpha: 1),
    highContrastLight: UIColor(red: 0.400, green: 0.040, blue: 0.130, alpha: 1),
    highContrastDark: UIColor(red: 0.500, green: 0.060, blue: 0.190, alpha: 1)
  )

  public static let incomingSurface = adaptive(
    light: UIColor(red: 1.000, green: 0.996, blue: 0.990, alpha: 1), // Ceramic Alabaster
    dark: UIColor(red: 0.125, green: 0.120, blue: 0.130, alpha: 1), // Velvet Obsidian
    highContrastLight: UIColor.white,
    highContrastDark: UIColor(red: 0.145, green: 0.140, blue: 0.150, alpha: 1)
  )

  public static let incomingSurfaceDepth = adaptive(
    light: UIColor(red: 0.978, green: 0.968, blue: 0.955, alpha: 1),
    dark: UIColor(red: 0.095, green: 0.090, blue: 0.100, alpha: 1),
    highContrastLight: UIColor(red: 0.950, green: 0.935, blue: 0.915, alpha: 1),
    highContrastDark: UIColor(red: 0.080, green: 0.075, blue: 0.085, alpha: 1)
  )

  public static let outgoingBubbleStroke = adaptive(
    light: UIColor(white: 1.00, alpha: 0.26), // Luminous inner rim
    dark: UIColor(white: 1.00, alpha: 0.22),
    highContrastLight: UIColor(white: 1.00, alpha: 0.45),
    highContrastDark: UIColor(white: 1.00, alpha: 0.48)
  )

  public static let incomingBubbleStroke = surfaceStroke

  public static let replySurface = adaptive(
    light: UIColor(white: 0.00, alpha: 0.045),
    dark: UIColor(white: 1.00, alpha: 0.085),
    highContrastLight: UIColor(white: 0, alpha: 0.090),
    highContrastDark: UIColor(white: 1, alpha: 0.140)
  )

  public static let reactionSurface = adaptive(
    light: UIColor(red: 1.000, green: 0.995, blue: 0.990, alpha: 0.98),
    dark: UIColor(red: 0.135, green: 0.130, blue: 0.140, alpha: 0.98),
    highContrastLight: .white,
    highContrastDark: UIColor(red: 0.165, green: 0.160, blue: 0.170, alpha: 1)
  )

  public static let mediaChrome = adaptive(
    light: UIColor(white: 0.00, alpha: 0.60),
    dark: UIColor(white: 0.00, alpha: 0.72),
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

  // MARK: - Identity and Status

  public static let avatarSurface = adaptive(
    light: UIColor(red: 0.940, green: 0.910, blue: 0.880, alpha: 1),
    dark: UIColor(red: 0.180, green: 0.175, blue: 0.185, alpha: 1),
    highContrastLight: UIColor(red: 0.880, green: 0.840, blue: 0.800, alpha: 1),
    highContrastDark: UIColor(red: 0.220, green: 0.215, blue: 0.225, alpha: 1)
  )

  public static let avatarDepth = adaptive(
    light: UIColor(red: 0.860, green: 0.790, blue: 0.740, alpha: 1),
    dark: UIColor(red: 0.270, green: 0.150, blue: 0.185, alpha: 1),
    highContrastLight: UIColor(red: 0.790, green: 0.700, blue: 0.630, alpha: 1),
    highContrastDark: UIColor(red: 0.340, green: 0.160, blue: 0.210, alpha: 1)
  )

  public static var avatarGradient: LinearGradient {
    LinearGradient(
      colors: [avatarSurface, avatarDepth],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  public static let avatarForeground = adaptive(
    light: UIColor(white: 0.16, alpha: 1),
    dark: UIColor(white: 0.96, alpha: 1),
    highContrastLight: .black,
    highContrastDark: .white
  )

  public static let messageShadow = adaptive(
    light: UIColor(white: 0.10, alpha: 0.07),
    dark: UIColor(white: 0.00, alpha: 0.36),
    highContrastLight: UIColor(white: 0, alpha: 0.16),
    highContrastDark: UIColor(white: 0, alpha: 0.50)
  )

  public static let conversationBackground = canvas
  public static let subduedText = Color.secondary
  public static let success = Color(red: 0.18, green: 0.76, blue: 0.42) // Vibrant Emerald
  public static let danger = Color(red: 0.92, green: 0.24, blue: 0.28) // Vibrant Coral Red
  public static let warning = Color(red: 0.98, green: 0.64, blue: 0.12) // Vibrant Amber

  // MARK: - Waveform

  public static var waveformPlayedGradient: LinearGradient {
    LinearGradient(
      colors: [signal, brandDeep],
      startPoint: .bottom,
      endPoint: .top
    )
  }

  public static func waveformTrack(_: ColorScheme) -> Color {
    adaptive(
      light: UIColor(white: 0.00, alpha: 0.24),
      dark: UIColor(white: 1.00, alpha: 0.22),
      highContrastLight: UIColor(white: 0, alpha: 0.50),
      highContrastDark: UIColor(white: 1, alpha: 0.50)
    )
  }

  // MARK: - Color Construction

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

// MARK: - Category-Defining Motion Choreography

public enum PurePetsMessagingMotion {
  /// Strong ease-out used for micro-feedback that must feel immediate.
  public static let quick: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.16)
  /// Shared studio transition for state changes already on screen.
  public static let standard: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
  /// Directional, transform-only message entrance with smooth deceleration.
  public static let entrance: Animation = .spring(response: 0.32, dampingFraction: 0.84)
  /// Tactile physics spring for floating reaction bar & modal pills.
  public static let springBouncy: Animation = .spring(response: 0.28, dampingFraction: 0.76)
  /// Snappy recoil spring for press states and haptic detents.
  public static let springSnap: Animation = .spring(response: 0.20, dampingFraction: 0.72)
  /// Interruptible settlement for the direct-manipulation reply gesture.
  public static let replySettlement: Animation = .interactiveSpring(
    response: 0.24,
    dampingFraction: 0.86,
    blendDuration: 0.06
  )
  public static let status: Animation = quick
  public static let progress: Animation = .easeInOut(duration: 0.20)
  public static let waveBar: Animation = .spring(response: 0.22, dampingFraction: 0.78)
}

public struct PurePetsMessagingPressButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    let animation: Animation = {
      if reduceMotion {
        return .easeOut(duration: 0.08)
      }
      return PurePetsMessagingMotion.springSnap
    }()

    return configuration.label
      .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.965 : 1))
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(animation, value: configuration.isPressed)
  }
}

public enum PurePetsMessageTextDirection {
  public static func resolve(
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

public enum PurePetsMessageDurationFormatter {
  public static func string(
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
