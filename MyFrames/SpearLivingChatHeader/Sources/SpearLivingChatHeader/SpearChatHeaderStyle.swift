import SwiftUI

// MARK: - Style Configuration

public struct SpearChatHeaderStyle {
  public var brandColor: Color
  public var cornerRadius: CGFloat
  public var horizontalPadding: CGFloat

  public init(
    brandColor: Color = Color(
      red: 203.0 / 255.0,
      green: 38.0 / 255.0,
      blue: 84.0 / 255.0
    ),
    cornerRadius: CGFloat = 18,
    horizontalPadding: CGFloat = 12
  ) {
    self.brandColor = brandColor
    self.cornerRadius = cornerRadius
    self.horizontalPadding = horizontalPadding
  }

  public static let spear = SpearChatHeaderStyle()
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
