import SwiftUI

public enum PurePetsMessagingTheme {
  public static let brand = Color(red: 0.796, green: 0.149, blue: 0.329)
  public static let brandSoft = Color(red: 0.984, green: 0.914, blue: 0.937)
  public static let incomingSurface = Color(uiColor: .secondarySystemBackground)
  public static let conversationBackground = Color(uiColor: .systemGroupedBackground)
  public static let subduedText = Color.secondary
  public static let success = Color(red: 0.086, green: 0.510, blue: 0.365)
  public static let danger = Color(red: 0.706, green: 0.141, blue: 0.110)
}

// MARK: - Font Tokens

import UIKit

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
