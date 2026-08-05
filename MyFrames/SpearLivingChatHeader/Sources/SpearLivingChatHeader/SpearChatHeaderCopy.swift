import Foundation

public struct SpearChatHeaderCopy: Equatable, Sendable {
  public var localeIdentifier: String
  public var backAccessibilityLabel: String
  public var callButtonTitle: String
  public var startCallAccessibilityLabel: String
  public var endCallAccessibilityLabel: String
  public var moreButtonTitle: String
  public var moreAccessibilityLabel: String
  public var verifiedSellerAccessibilityLabel: String
  public var verifiedBusinessAccessibilityLabel: String
  public var restrictedAccessibilityLabel: String
  public var profileButtonTitle: String
  public var safetyButtonTitle: String
  public var loadingAccessibilityLabel: String
  public var conversationAccessibilityPrefix: String
  public var onlineNowText: String
  public var repliesFastText: String
  public var repliesTypicallyText: String
  public var typingText: String
  public var viewingOfferText: String
  public var lastSeenPrefix: String
  public var secureCallText: String
  public var expandAccessibilityHint: String
  public var collapseAccessibilityHint: String
  public var expandedAccessibilityValue: String
  public var collapsedAccessibilityValue: String

  public init(
    localeIdentifier: String,
    backAccessibilityLabel: String,
    callButtonTitle: String,
    startCallAccessibilityLabel: String,
    endCallAccessibilityLabel: String,
    moreButtonTitle: String,
    moreAccessibilityLabel: String,
    verifiedSellerAccessibilityLabel: String,
    verifiedBusinessAccessibilityLabel: String,
    restrictedAccessibilityLabel: String,
    profileButtonTitle: String,
    safetyButtonTitle: String,
    loadingAccessibilityLabel: String,
    conversationAccessibilityPrefix: String,
    onlineNowText: String,
    repliesFastText: String,
    repliesTypicallyText: String,
    typingText: String,
    viewingOfferText: String,
    lastSeenPrefix: String,
    secureCallText: String,
    expandAccessibilityHint: String,
    collapseAccessibilityHint: String,
    expandedAccessibilityValue: String,
    collapsedAccessibilityValue: String
  ) {
    self.localeIdentifier = localeIdentifier
    self.backAccessibilityLabel = backAccessibilityLabel
    self.callButtonTitle = callButtonTitle
    self.startCallAccessibilityLabel = startCallAccessibilityLabel
    self.endCallAccessibilityLabel = endCallAccessibilityLabel
    self.moreButtonTitle = moreButtonTitle
    self.moreAccessibilityLabel = moreAccessibilityLabel
    self.verifiedSellerAccessibilityLabel = verifiedSellerAccessibilityLabel
    self.verifiedBusinessAccessibilityLabel = verifiedBusinessAccessibilityLabel
    self.restrictedAccessibilityLabel = restrictedAccessibilityLabel
    self.profileButtonTitle = profileButtonTitle
    self.safetyButtonTitle = safetyButtonTitle
    self.loadingAccessibilityLabel = loadingAccessibilityLabel
    self.conversationAccessibilityPrefix = conversationAccessibilityPrefix
    self.onlineNowText = onlineNowText
    self.repliesFastText = repliesFastText
    self.repliesTypicallyText = repliesTypicallyText
    self.typingText = typingText
    self.viewingOfferText = viewingOfferText
    self.lastSeenPrefix = lastSeenPrefix
    self.secureCallText = secureCallText
    self.expandAccessibilityHint = expandAccessibilityHint
    self.collapseAccessibilityHint = collapseAccessibilityHint
    self.expandedAccessibilityValue = expandedAccessibilityValue
    self.collapsedAccessibilityValue = collapsedAccessibilityValue
  }

  public func presenceText(for presence: SpearPresence) -> String {
    switch presence {
    case .online(let responseSpeed):
      guard let responseSpeed else { return onlineNowText }
      return "\(onlineNowText) · \(responseSpeedText(for: responseSpeed))"

    case .typing:
      return typingText

    case .viewingOffer:
      return viewingOfferText

    case .offline(let lastActiveAt):
      let safeLastActiveAt = min(lastActiveAt, Date())
      let relative = safeLastActiveAt.formatted(
        .relative(presentation: .numeric, unitsStyle: .wide)
          .locale(Locale(identifier: localeIdentifier))
      )
      return "\(lastSeenPrefix) \(relative)"
    }
  }

  public func callText(elapsedSeconds: Int) -> String {
    "\(secureCallText) · \(formattedDuration(elapsedSeconds))"
  }

  public func trustAccessibilityText(for trust: SpearTrustState) -> String? {
    switch trust {
    case .standard(let role):
      return role

    case .verifiedSeller(let role, let location):
      return [verifiedSellerAccessibilityLabel, role, location]
        .compactMap { value in
          guard let value, !value.isEmpty else { return nil }
          return value
        }
        .joined(separator: ", ")

    case .verifiedBusiness(let displayName):
      return "\(verifiedBusinessAccessibilityLabel), \(displayName)"

    case .restricted(let reason):
      return "\(restrictedAccessibilityLabel), \(reason)"
    }
  }

  private func responseSpeedText(for speed: SpearResponseSpeed) -> String {
    switch speed {
    case .fast:
      return repliesFastText
    case .typical:
      return repliesTypicallyText
    }
  }

  private func formattedDuration(_ elapsedSeconds: Int) -> String {
    let seconds = max(0, elapsedSeconds)
    let locale = Locale(identifier: localeIdentifier)
    let twoDigits = IntegerFormatStyle<Int>.number
      .locale(locale)
      .precision(.integerLength(2))
    let minutes = (seconds / 60).formatted(twoDigits)
    let remainingSeconds = (seconds % 60).formatted(twoDigits)
    return "\(minutes):\(remainingSeconds)"
  }

  public static let english = SpearChatHeaderCopy(
    localeIdentifier: "en_US",
    backAccessibilityLabel: "Back",
    callButtonTitle: "Call",
    startCallAccessibilityLabel: "Start voice call",
    endCallAccessibilityLabel: "End call",
    moreButtonTitle: "More",
    moreAccessibilityLabel: "More conversation actions",
    verifiedSellerAccessibilityLabel: "Verified seller",
    verifiedBusinessAccessibilityLabel: "Verified business",
    restrictedAccessibilityLabel: "Restricted account",
    profileButtonTitle: "View profile",
    safetyButtonTitle: "Safety tools",
    loadingAccessibilityLabel: "Loading conversation identity",
    conversationAccessibilityPrefix: "Conversation with",
    onlineNowText: "Online now",
    repliesFastText: "Replies fast",
    repliesTypicallyText: "Usually replies soon",
    typingText: "Typing",
    viewingOfferText: "Viewing your offer now",
    lastSeenPrefix: "Last seen",
    secureCallText: "Secure call",
    expandAccessibilityHint: "Expands profile details",
    collapseAccessibilityHint: "Collapses profile details",
    expandedAccessibilityValue: "Expanded",
    collapsedAccessibilityValue: "Collapsed"
  )

  public static let arabic = SpearChatHeaderCopy(
    localeIdentifier: "ar_EG",
    backAccessibilityLabel: "رجوع",
    callButtonTitle: "اتصال",
    startCallAccessibilityLabel: "بدء مكالمة صوتية",
    endCallAccessibilityLabel: "إنهاء المكالمة",
    moreButtonTitle: "المزيد",
    moreAccessibilityLabel: "المزيد من إجراءات المحادثة",
    verifiedSellerAccessibilityLabel: "بائع موثق",
    verifiedBusinessAccessibilityLabel: "نشاط تجاري موثق",
    restrictedAccessibilityLabel: "حساب مقيّد",
    profileButtonTitle: "عرض الملف الشخصي",
    safetyButtonTitle: "أدوات الأمان",
    loadingAccessibilityLabel: "جارٍ تحميل هوية المحادثة",
    conversationAccessibilityPrefix: "محادثة مع",
    onlineNowText: "متصل الآن",
    repliesFastText: "سريع الرد",
    repliesTypicallyText: "يرد عادةً قريبًا",
    typingText: "يكتب الآن",
    viewingOfferText: "يشاهد عرضك الآن",
    lastSeenPrefix: "آخر ظهور",
    secureCallText: "مكالمة آمنة",
    expandAccessibilityHint: "يوسّع تفاصيل الملف الشخصي",
    collapseAccessibilityHint: "يطوي تفاصيل الملف الشخصي",
    expandedAccessibilityValue: "موسّع",
    collapsedAccessibilityValue: "مطوي"
  )
}
