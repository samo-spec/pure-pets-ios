import SwiftUI

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
