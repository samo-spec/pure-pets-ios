import Foundation

// MARK: - Context

public struct SpearListingContext: Equatable, Identifiable, Sendable {
  public let id: String
  public var eyebrow: String
  public var title: String
  public var detail: String
  public var actionTitle: String

  public init(
    id: String,
    eyebrow: String,
    title: String,
    detail: String,
    actionTitle: String
  ) {
    self.id = id
    self.eyebrow = eyebrow
    self.title = title
    self.detail = detail
    self.actionTitle = actionTitle
  }
}

public struct SpearOrderContext: Equatable, Identifiable, Sendable {
  public let id: String
  public var eyebrow: String
  public var title: String
  public var detail: String
  public var actionTitle: String
  public var progress: Double?

  public init(
    id: String,
    eyebrow: String,
    title: String,
    detail: String,
    actionTitle: String,
    progress: Double? = nil
  ) {
    self.id = id
    self.eyebrow = eyebrow
    self.title = title
    self.detail = detail
    self.actionTitle = actionTitle
    self.progress = progress.flatMap { value in
      guard value.isFinite else { return nil }
      return min(max(value, 0), 1)
    }
  }
}

public struct SpearSupportContext: Equatable, Identifiable, Sendable {
  public let id: String
  public var eyebrow: String
  public var title: String
  public var detail: String
  public var actionTitle: String

  public init(
    id: String,
    eyebrow: String,
    title: String,
    detail: String,
    actionTitle: String
  ) {
    self.id = id
    self.eyebrow = eyebrow
    self.title = title
    self.detail = detail
    self.actionTitle = actionTitle
  }
}

public enum SpearConversationContext: Equatable, Identifiable, Sendable {
  case listing(SpearListingContext)
  case order(SpearOrderContext)
  case support(SpearSupportContext)

  public var id: String {
    switch self {
    case .listing(let value):
      value.id
    case .order(let value):
      value.id
    case .support(let value):
      value.id
    }
  }

  internal var eyebrow: String {
    switch self {
    case .listing(let value):
      value.eyebrow
    case .order(let value):
      value.eyebrow
    case .support(let value):
      value.eyebrow
    }
  }

  internal var title: String {
    switch self {
    case .listing(let value):
      value.title
    case .order(let value):
      value.title
    case .support(let value):
      value.title
    }
  }

  internal var detail: String {
    switch self {
    case .listing(let value):
      value.detail
    case .order(let value):
      value.detail
    case .support(let value):
      value.detail
    }
  }

  internal var actionTitle: String {
    switch self {
    case .listing(let value):
      value.actionTitle
    case .order(let value):
      value.actionTitle
    case .support(let value):
      value.actionTitle
    }
  }

  internal var symbolSystemName: String {
    switch self {
    case .listing:
      "pawprint.fill"
    case .order:
      "shippingbox.fill"
    case .support:
      "shield.lefthalf.filled"
    }
  }

  internal var orderProgress: Double? {
    guard case .order(let value) = self else { return nil }
    return value.progress
  }
}
