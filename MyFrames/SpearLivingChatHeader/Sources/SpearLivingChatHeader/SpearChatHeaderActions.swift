import Foundation

// MARK: - Capabilities

public enum SpearActionAvailability: Equatable, Sendable {
  case hidden
  case disabled(reason: String)
  case enabled

  public var isVisible: Bool {
    if case .hidden = self { return false }
    return true
  }

  public var isEnabled: Bool {
    if case .enabled = self { return true }
    return false
  }

  public var disabledReason: String? {
    guard case .disabled(let reason) = self else { return nil }
    return reason
  }
}

public struct SpearHeaderAction {
  public var availability: SpearActionAvailability
  public var perform: () -> Void

  public init(
    availability: SpearActionAvailability,
    perform: @escaping () -> Void
  ) {
    self.availability = availability
    self.perform = perform
  }

  public static func enabled(_ perform: @escaping () -> Void) -> Self {
    .init(availability: .enabled, perform: perform)
  }

  public static func disabled(reason: String) -> Self {
    .init(availability: .disabled(reason: reason), perform: {})
  }

  public static var hidden: Self {
    .init(availability: .hidden, perform: {})
  }
}

/// Call state and call action are intentionally one value so an active call can
/// never be rendered without a working End Call control.
public enum SpearCallControl {
  case hidden
  case unavailable(reason: String)
  case start(perform: () -> Void)
  case active(elapsedSeconds: Int, end: () -> Void)

  public var isVisible: Bool {
    if case .hidden = self { return false }
    return true
  }

  public var isActive: Bool {
    if case .active = self { return true }
    return false
  }

  public var elapsedSeconds: Int? {
    guard case .active(let elapsedSeconds, _) = self else { return nil }
    return max(0, elapsedSeconds)
  }

  internal var buttonAction: SpearHeaderAction {
    switch self {
    case .hidden:
      return .hidden
    case .unavailable(let reason):
      return .disabled(reason: reason)
    case .start(let perform):
      return .enabled(perform)
    case .active(_, let end):
      return .enabled(end)
    }
  }

  internal var transitionIdentity: String {
    isActive ? "activeCall" : "inactiveCall"
  }
}

public struct SpearContextHeaderAction {
  public var availability: SpearActionAvailability
  public var perform: (SpearConversationContext) -> Void

  public init(
    availability: SpearActionAvailability,
    perform: @escaping (SpearConversationContext) -> Void
  ) {
    self.availability = availability
    self.perform = perform
  }

  public static func enabled(
    _ perform: @escaping (SpearConversationContext) -> Void
  ) -> Self {
    .init(availability: .enabled, perform: perform)
  }

  public static func disabled(reason: String) -> Self {
    .init(availability: .disabled(reason: reason), perform: { _ in })
  }

  public static var hidden: Self {
    .init(availability: .hidden, perform: { _ in })
  }
}

public struct SpearChatHeaderActions {
  public var onBack: () -> Void
  public var call: SpearCallControl
  public var more: SpearHeaderAction
  public var profile: SpearHeaderAction
  public var safety: SpearHeaderAction
  public var context: SpearContextHeaderAction
  public var retry: SpearHeaderAction

  public init(
    onBack: @escaping () -> Void,
    call: SpearCallControl = .hidden,
    more: SpearHeaderAction = .hidden,
    profile: SpearHeaderAction = .hidden,
    safety: SpearHeaderAction = .hidden,
    context: SpearContextHeaderAction = .hidden,
    retry: SpearHeaderAction = .hidden
  ) {
    self.onBack = onBack
    self.call = call
    self.more = more
    self.profile = profile
    self.safety = safety
    self.context = context
    self.retry = retry
  }
}

// MARK: - Accessibility IDs

public enum SpearChatHeaderAccessibilityID {
  public static let root = "spear.chat.header"
  public static let back = "spear.chat.header.back"
  public static let identity = "spear.chat.header.identity"
  public static let call = "spear.chat.header.call"
  public static let more = "spear.chat.header.more"
  public static let profile = "spear.chat.header.profile"
  public static let safety = "spear.chat.header.safety"
  public static let contextAction = "spear.chat.header.contextAction"
  public static let retry = "spear.chat.header.retry"
}
