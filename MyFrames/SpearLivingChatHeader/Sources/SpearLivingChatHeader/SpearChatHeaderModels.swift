import Foundation

// MARK: - Header State

public enum SpearChatHeaderLoadState: Equatable, Sendable {
  case loading
  case ready(SpearChatHeaderModel)
  case unavailable(title: String, retryTitle: String?)
}

public struct SpearChatHeaderModel: Equatable, Identifiable, Sendable {
  public let id: String
  public var name: String
  public var avatarFallback: SpearAvatarFallback
  public var trust: SpearTrustState
  public var presence: SpearPresence
  public var metrics: [SpearIdentityMetric]
  public var context: SpearConversationContext?
  public var isModal: Bool

  public init(
    id: String,
    name: String,
    avatarFallback: SpearAvatarFallback,
    trust: SpearTrustState = .standard(role: nil),
    presence: SpearPresence,
    metrics: [SpearIdentityMetric] = [],
    context: SpearConversationContext? = nil,
    isModal: Bool = false
  ) {
    self.id = id
    self.name = name
    self.avatarFallback = avatarFallback
    self.trust = trust
    self.presence = presence
    self.metrics = Self.normalizedMetrics(metrics)
    self.context = context
    self.isModal = isModal
  }

  private static func normalizedMetrics(
    _ metrics: [SpearIdentityMetric]
  ) -> [SpearIdentityMetric] {
    var seenIDs = Set<String>()
    var normalized: [SpearIdentityMetric] = []

    for metric in metrics where !metric.id.isEmpty {
      guard seenIDs.insert(metric.id).inserted else { continue }
      normalized.append(metric)
      if normalized.count == 3 { break }
    }

    return normalized
  }
}

// MARK: - Identity

public enum SpearAvatarFallback: Equatable, Sendable {
  case initials(String)
  case systemImage(String)
}

public enum SpearTrustState: Equatable, Sendable {
  case standard(role: String?)
  case verifiedSeller(role: String, location: String?)
  case verifiedBusiness(displayName: String)
  case restricted(reason: String)

  public var isVerified: Bool {
    switch self {
    case .verifiedSeller, .verifiedBusiness:
      return true
    case .standard, .restricted:
      return false
    }
  }

  public var isRestricted: Bool {
    if case .restricted = self { return true }
    return false
  }

  public var detailText: String? {
    switch self {
    case .standard(let role):
      return role

    case .verifiedSeller(let role, let location):
      return [role, location]
        .compactMap { value in
          guard let value, !value.isEmpty else { return nil }
          return value
        }
        .joined(separator: " · ")

    case .verifiedBusiness(let displayName):
      return displayName

    case .restricted(let reason):
      return reason
    }
  }

  internal var badgeSystemName: String? {
    switch self {
    case .standard:
      return nil
    case .verifiedSeller:
      return "checkmark.seal.fill"
    case .verifiedBusiness:
      return "building.2.crop.circle.fill"
    case .restricted:
      return "exclamationmark.shield.fill"
    }
  }

  internal var detailSystemName: String? {
    switch self {
    case .standard(let role):
      return role == nil ? nil : "person.crop.circle"
    case .verifiedSeller:
      return "checkmark.seal.fill"
    case .verifiedBusiness:
      return "building.2.crop.circle.fill"
    case .restricted:
      return "exclamationmark.shield.fill"
    }
  }
}

public struct SpearIdentityMetric: Equatable, Identifiable, Sendable {
  public let id: String
  public var value: String
  public var label: String

  public init(id: String, value: String, label: String) {
    self.id = id
    self.value = value
    self.label = label
  }
}

// MARK: - Presence

public enum SpearResponseSpeed: Equatable, Sendable {
  case fast
  case typical
}

public enum SpearPresence: Equatable, Sendable {
  case online(responseSpeed: SpearResponseSpeed?)
  case typing
  case viewingOffer
  case offline(lastActiveAt: Date)

  internal var transitionIdentity: String {
    switch self {
    case .online:
      return "online"
    case .typing:
      return "typing"
    case .viewingOffer:
      return "viewingOffer"
    case .offline:
      return "offline"
    }
  }
}
