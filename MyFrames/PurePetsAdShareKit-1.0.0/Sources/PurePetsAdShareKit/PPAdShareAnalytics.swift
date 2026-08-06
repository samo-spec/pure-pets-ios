#if canImport(UIKit)
  import Foundation

  @available(iOS 17.0, *)
  public enum PPAdShareAnalyticsEvent: Equatable, Sendable {
    case preparationStarted(advertisementID: String)
    case preparationFailed(advertisementID: String, errorCode: String)
    case shareCompleted(
      advertisementID: String,
      activityType: String?,
      completed: Bool
    )
  }

  @available(iOS 17.0, *)
  public protocol PPAdShareAnalytics: AnyObject {
    @MainActor
    func record(_ event: PPAdShareAnalyticsEvent)
  }

  @available(iOS 17.0, *)
  public final class PPNoopAdShareAnalytics: PPAdShareAnalytics {
    public static let shared = PPNoopAdShareAnalytics()

    private init() {}

    @MainActor
    public func record(_ event: PPAdShareAnalyticsEvent) {}
  }

  @available(iOS 17.0, *)
  public final class PPClosureAdShareAnalytics: PPAdShareAnalytics {
    private let handler: @MainActor (PPAdShareAnalyticsEvent) -> Void

    public init(
      handler: @escaping @MainActor (PPAdShareAnalyticsEvent) -> Void
    ) {
      self.handler = handler
    }

    public func record(_ event: PPAdShareAnalyticsEvent) {
      handler(event)
    }
  }
#endif
