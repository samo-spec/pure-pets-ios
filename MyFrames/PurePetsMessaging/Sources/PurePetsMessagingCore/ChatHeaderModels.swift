import Foundation

public enum ConversationPresence: Hashable, Codable, Sendable {
  case typing
  case online(expiresAt: Date)
  case activeRecently(Date)
  case offline
  case unavailable

  public func normalized(at now: Date) -> ConversationPresence {
    switch self {
    case .online(let expiresAt) where expiresAt <= now:
      .activeRecently(expiresAt)
    default:
      self
    }
  }
}

public struct ActiveOrderContext: Hashable, Codable, Sendable {
  public enum Status: String, Hashable, Codable, Sendable {
    case created
    case preparing
    case ready
    case courierAssigned
    case onTheWay
    case delivered
    case completed
    case cancelled
  }

  public let orderNumber: String
  public let status: Status

  public init(orderNumber: String, status: Status) {
    self.orderNumber = orderNumber
    self.status = status
  }
}

public enum ChatHeaderContext: Hashable, Codable, Sendable {
  case activeOrder(ActiveOrderContext)
  case supportEscalation
  case none
}

public struct ChatHeaderPresentation: Hashable, Codable, Sendable {
  public let participant: MessageSender
  public let roleLabel: String?
  public let presence: ConversationPresence
  public let context: ChatHeaderContext

  public init(
    participant: MessageSender,
    roleLabel: String? = nil,
    presence: ConversationPresence,
    context: ChatHeaderContext = .none
  ) {
    self.participant = participant
    self.roleLabel = roleLabel
    self.presence = presence
    self.context = context
  }
}
