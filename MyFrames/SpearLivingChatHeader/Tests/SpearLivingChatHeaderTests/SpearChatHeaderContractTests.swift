import Foundation
import XCTest

@testable import SpearLivingChatHeader

final class SpearChatHeaderContractTests: XCTestCase {
  func testModelCapsMetricsToThreeUniqueStableItems() {
    let model = SpearChatHeaderModel(
      id: "user-1",
      name: "Ahmed",
      avatarFallback: .initials("AH"),
      presence: .online(responseSpeed: nil),
      metrics: [
        .init(id: "1", value: "1", label: "One"),
        .init(id: "1", value: "Duplicate", label: "Duplicate"),
        .init(id: "2", value: "2", label: "Two"),
        .init(id: "", value: "Empty", label: "Empty"),
        .init(id: "3", value: "3", label: "Three"),
        .init(id: "4", value: "4", label: "Four"),
      ]
    )

    XCTAssertEqual(model.metrics.map(\.id), ["1", "2", "3"])
  }

  func testVerifiedTrustAlwaysOwnsVerifiedBadgeAndSummary() {
    let seller = SpearTrustState.verifiedSeller(role: "Seller", location: "Cairo")
    let business = SpearTrustState.verifiedBusiness(displayName: "SPEar Store")

    XCTAssertTrue(seller.isVerified)
    XCTAssertTrue(business.isVerified)
    XCTAssertEqual(seller.badgeSystemName, "checkmark.seal.fill")
    XCTAssertEqual(business.badgeSystemName, "building.2.crop.circle.fill")
    XCTAssertEqual(seller.detailText, "Seller · Cairo")
  }

  func testRestrictedTrustCannotAppearVerified() {
    let restricted = SpearTrustState.restricted(reason: "Limited")

    XCTAssertFalse(restricted.isVerified)
    XCTAssertTrue(restricted.isRestricted)
    XCTAssertEqual(restricted.badgeSystemName, "exclamationmark.shield.fill")
  }

  func testPresencePresentationIsDerivedFromSemanticState() {
    XCTAssertEqual(
      SpearChatHeaderCopy.english.presenceText(for: .typing),
      "Typing"
    )
    XCTAssertEqual(
      SpearChatHeaderCopy.english.presenceText(
        for: .online(responseSpeed: .fast)
      ),
      "Online now · Replies fast"
    )
  }

  func testOfflinePresenceOwnsTimestampInsteadOfArbitraryStatusText() {
    let text = SpearChatHeaderCopy.english.presenceText(
      for: .offline(lastActiveAt: Date().addingTimeInterval(-12 * 60))
    )

    XCTAssertTrue(text.hasPrefix("Last seen "))
    XCTAssertNotEqual(text, "Online now")
  }

  func testFutureOfflineTimestampNeverAnnouncesFutureActivity() {
    let text = SpearChatHeaderCopy.english.presenceText(
      for: .offline(lastActiveAt: Date().addingTimeInterval(60 * 60))
    )

    XCTAssertFalse(text.contains("in 1 hour"))
    XCTAssertTrue(text.hasPrefix("Last seen "))
  }

  func testUnavailablePresenceNeverInventsRecentActivity() {
    XCTAssertEqual(
      SpearChatHeaderCopy.english.presenceText(for: .unavailable),
      "Activity unavailable"
    )
  }

  func testActiveCallAlwaysOwnsAnEnabledEndAction() {
    var didEnd = false
    let call = SpearCallControl.active(elapsedSeconds: -8) {
      didEnd = true
    }

    XCTAssertTrue(call.isActive)
    XCTAssertEqual(call.elapsedSeconds, 0)
    XCTAssertTrue(call.buttonAction.availability.isEnabled)
    call.buttonAction.perform()
    XCTAssertTrue(didEnd)
  }

  func testCallDurationUsesCopyLocale() {
    XCTAssertEqual(SpearChatHeaderCopy.english.callText(elapsedSeconds: 138), "Secure call · 02:18")
    XCTAssertEqual(SpearChatHeaderCopy.arabic.callText(elapsedSeconds: 138), "مكالمة آمنة · ٠٢:١٨")
    XCTAssertEqual(
      SpearChatHeaderCopy.english.callText(elapsedSeconds: 6_000),
      "Secure call · 1:40:00"
    )
  }

  func testMotionArbiterAllowsOneContinuousMode() {
    XCTAssertEqual(
      SpearMotionMode(presence: .typing, call: .hidden),
      .typing
    )
    XCTAssertEqual(
      SpearMotionMode(
        presence: .typing,
        call: .active(elapsedSeconds: 10, end: {})
      ),
      .activeCall
    )
    XCTAssertEqual(
      SpearMotionMode(
        presence: .online(responseSpeed: nil),
        call: .hidden
      ),
      .onlinePresence
    )
    XCTAssertEqual(
      SpearMotionMode(presence: .viewingOffer, call: .hidden),
      .none
    )
  }

  func testOrderProgressIsFiniteAndClampedToValidRange() {
    let below = makeOrder(id: "below", progress: -0.5)
    let above = makeOrder(id: "above", progress: 1.7)
    let notANumber = makeOrder(id: "nan", progress: .nan)
    let infinite = makeOrder(id: "infinite", progress: .infinity)

    XCTAssertEqual(below.progress, 0)
    XCTAssertEqual(above.progress, 1)
    XCTAssertNil(notANumber.progress)
    XCTAssertNil(infinite.progress)
  }

  func testContextSymbolsAreSemanticAndNotCallerControlled() {
    let listing = SpearConversationContext.listing(
      .init(
        id: "listing",
        eyebrow: "Listing",
        title: "Puppy",
        detail: "Available",
        actionTitle: "View"
      )
    )
    let order = SpearConversationContext.order(makeOrder(id: "order", progress: 0.5))

    XCTAssertEqual(listing.symbolSystemName, "pawprint.fill")
    XCTAssertEqual(order.symbolSystemName, "shippingbox.fill")
  }

  func testContextIdentityIsNamespacedByKind() {
    let listing = SpearConversationContext.listing(
      .init(id: "same", eyebrow: "Listing", title: "Pet", detail: "", actionTitle: "View")
    )
    let order = SpearConversationContext.order(makeOrder(id: "same", progress: nil))
    let support = SpearConversationContext.support(
      .init(id: "same", eyebrow: "Support", title: "Case", detail: "", actionTitle: "Open")
    )

    XCTAssertEqual(listing.id, "listing:same")
    XCTAssertEqual(order.id, "order:same")
    XCTAssertEqual(support.id, "support:same")
    XCTAssertEqual(Set([listing.id, order.id, support.id]).count, 3)
    XCTAssertEqual(listing.backendID, "same")
    XCTAssertEqual(order.backendID, "same")
    XCTAssertEqual(support.backendID, "same")
  }

  func testOptionalActionsDefaultToHiddenInsteadOfNoOpEnabledButtons() {
    let actions = SpearChatHeaderActions(onBack: {})

    XCTAssertFalse(actions.call.isVisible)
    XCTAssertEqual(actions.more.availability, .hidden)
    XCTAssertEqual(actions.profile.availability, .hidden)
    XCTAssertEqual(actions.safety.availability, .hidden)
    XCTAssertEqual(actions.context.availability, .hidden)
    XCTAssertEqual(actions.retry.availability, .hidden)
  }

  private func makeOrder(id: String, progress: Double?) -> SpearOrderContext {
    SpearOrderContext(
      id: id,
      eyebrow: "Order",
      title: "Order \(id)",
      detail: "Preparing",
      actionTitle: "Track",
      progress: progress
    )
  }
}
