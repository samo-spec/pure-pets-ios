import Foundation

public struct PPAdShareCopy: Equatable, Sendable {
  public let localeIdentifier: String
  public let appName: String
  public let fallbackTitle: String
  public let priceLabel: String
  public let locationLabel: String
  public let callToAction: String
  public let buttonTitle: String
  public let buttonSubtitle: String
  public let buttonAccessibilityHint: String
  public let preparingTitle: String
  public let failureTitle: String
  public let dismissTitle: String

  public init(
    localeIdentifier: String,
    appName: String,
    fallbackTitle: String,
    priceLabel: String,
    locationLabel: String,
    callToAction: String,
    buttonTitle: String,
    buttonSubtitle: String,
    buttonAccessibilityHint: String,
    preparingTitle: String,
    failureTitle: String,
    dismissTitle: String
  ) {
    self.localeIdentifier = localeIdentifier
    self.appName = appName
    self.fallbackTitle = fallbackTitle
    self.priceLabel = priceLabel
    self.locationLabel = locationLabel
    self.callToAction = callToAction
    self.buttonTitle = buttonTitle
    self.buttonSubtitle = buttonSubtitle
    self.buttonAccessibilityHint = buttonAccessibilityHint
    self.preparingTitle = preparingTitle
    self.failureTitle = failureTitle
    self.dismissTitle = dismissTitle
  }

  public static func forLocale(_ locale: Locale) -> Self {
    locale.identifier.lowercased().hasPrefix("ar") ? .arabic : .english
  }

  public static let english = PPAdShareCopy(
    localeIdentifier: "en_US",
    appName: "Pure Pets",
    fallbackTitle: "Pure Pets advertisement",
    priceLabel: "Price",
    locationLabel: "Location",
    callToAction: "View this ad on Pure Pets:",
    buttonTitle: "Share this ad",
    buttonSubtitle: "Photo, details and direct link",
    buttonAccessibilityHint: "Shares the advertisement image, public details and direct link.",
    preparingTitle: "Preparing advertisement…",
    failureTitle: "Unable to share advertisement",
    dismissTitle: "OK"
  )

  public static let arabic = PPAdShareCopy(
    localeIdentifier: "ar_EG",
    appName: "Pure Pets",
    fallbackTitle: "إعلان Pure Pets",
    priceLabel: "السعر",
    locationLabel: "الموقع",
    callToAction: "شاهد الإعلان على Pure Pets:",
    buttonTitle: "مشاركة الإعلان",
    buttonSubtitle: "صورة وتفاصيل ورابط مباشر",
    buttonAccessibilityHint: "يشارك صورة الإعلان وتفاصيله العامة والرابط المباشر.",
    preparingTitle: "جارٍ تجهيز الإعلان…",
    failureTitle: "تعذرت مشاركة الإعلان",
    dismissTitle: "حسنًا"
  )
}
