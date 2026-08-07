import Foundation
import SwiftUI
import UIKit

public enum PurePetsMessagingTheme {
  public static let brand = Color(red: 0.796, green: 0.149, blue: 0.329)
  public static let brandSoft = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.285, green: 0.085, blue: 0.145, alpha: 1)
      : UIColor(red: 0.984, green: 0.914, blue: 0.937, alpha: 1)
  })
  public static let signal = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.965, green: 0.475, blue: 0.620, alpha: 1)
      : UIColor(red: 0.796, green: 0.149, blue: 0.329, alpha: 1)
  })
  public static let signalForeground = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(white: 0.055, alpha: 1)
      : UIColor.white
  })
  public static let outgoingBubbleSurface = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.175, green: 0.183, blue: 0.187, alpha: 0.98)
      : UIColor(red: 0.125, green: 0.132, blue: 0.136, alpha: 0.98)
  })
  public static let incomingSurface = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.102, green: 0.110, blue: 0.114, alpha: 0.98)
      : UIColor(red: 0.990, green: 0.978, blue: 0.954, alpha: 0.98)
  })
  public static let outgoingBubbleStroke = Color.white.opacity(0.10)
  public static let incomingBubbleStroke = Color(uiColor: UIColor { traits in
    let increasedContrast = traits.accessibilityContrast == .high
    return traits.userInterfaceStyle == .dark
      ? UIColor(white: 1, alpha: increasedContrast ? 0.24 : 0.10)
      : UIColor(white: 0.05, alpha: increasedContrast ? 0.20 : 0.085)
  })
  public static let avatarSurface = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(white: 1, alpha: 0.09)
      : UIColor(white: 0, alpha: 0.055)
  })
  public static let avatarForeground = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(white: 0.92, alpha: 1)
      : UIColor(white: 0.24, alpha: 1)
  })
  public static let conversationBackground = Color(uiColor: .systemGroupedBackground)
  public static let subduedText = Color.secondary
  public static let success = Color(red: 0.086, green: 0.510, blue: 0.365)
  public static let danger = Color(red: 0.706, green: 0.141, blue: 0.110)

  // MARK: - Waveform

  /// Gradient used to paint the *played* portion of a voice waveform. Brand at
  /// the leading edge easing into the softer signal tint gives the bars a
  /// studio-grade, lit-from-within read while still tracking playback.
  static var waveformPlayedGradient: LinearGradient {
    LinearGradient(
      colors: [signal, brand],
      startPoint: .bottom,
      endPoint: .top
    )
  }

  /// Fill for the not-yet-played portion of a waveform.
  static func waveformTrack(_ scheme: ColorScheme) -> Color {
    scheme == .dark
      ? Color.white.opacity(0.24)
      : Color.black.opacity(0.20)
  }
}

// MARK: - Shared motion

/// Centralized, tuned motion curves so every messaging animation shares one
/// physical vocabulary. All are no-overshoot or gently damped so nothing in a
/// scrolling transcript can jitter, flash, or push neighbouring rows.
enum PurePetsMessagingMotion {
  /// Status glyph morphs (sent → delivered → read). Snappy but settled.
  static let status: Animation = .spring(response: 0.34, dampingFraction: 1.0)
  /// Determinate upload-ring progress.
  static let progress: Animation = .easeInOut(duration: 0.30)
  /// Message entrance (incoming/outgoing). Gentle, no overshoot.
  static let entrance: Animation = .spring(response: 0.40, dampingFraction: 0.90)
  /// Per-bar waveform level response while recording/playing.
  static let waveBar: Animation = .spring(response: 0.28, dampingFraction: 0.72)
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
