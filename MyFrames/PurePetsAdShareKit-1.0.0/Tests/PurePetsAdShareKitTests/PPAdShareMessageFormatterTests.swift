import Foundation
import XCTest

@testable import PurePetsAdShareKit

final class PPAdShareMessageFormatterTests: XCTestCase {
  func testEnglishMessageIncludesApprovedDetailsAndOneCanonicalURL() throws {
    let payload = try makePayload()
    let message = PPAdShareMessageFormatter(copy: .english).message(for: payload)

    XCTAssertEqual(
      message,
      """
      🐾 Golden Retriever Puppy
      💰 Price: EGP 8,500
      📍 Location: Cairo
      ✅ Vaccinated • Male • 3 months
      Vaccinated and ready for a caring home.

      View this ad on Pure Pets:
      https://purepets.app/ads/ad-2048
      """
    )
    XCTAssertEqual(
      message.components(separatedBy: payload.canonicalURL.absoluteString).count - 1,
      1
    )
  }

  func testArabicMessageUsesArabicLabels() throws {
    let payload = try PPAdSharePayload(
      id: "ad-2048",
      title: "جرو جولدن ريتريفر",
      formattedPrice: "٨٬٥٠٠ ج.م",
      location: "القاهرة",
      attributes: [
        .init(id: "vaccinated", title: "مطعّم"),
        .init(id: "male", title: "ذكر"),
      ],
      canonicalURL: URL(string: "https://purepets.app/ads/ad-2048")!
    )

    let message = PPAdShareMessageFormatter(copy: .arabic).message(for: payload)

    XCTAssertTrue(message.contains("💰 السعر: ٨٬٥٠٠ ج.م"))
    XCTAssertTrue(message.contains("📍 الموقع: القاهرة"))
    XCTAssertTrue(message.contains("شاهد الإعلان على Pure Pets:"))
    XCTAssertTrue(message.hasSuffix(payload.canonicalURL.absoluteString))
  }

  func testMessageOmitsMissingOptionalRowsWithoutBlankNoise() throws {
    let payload = try PPAdSharePayload(
      id: "minimal",
      title: "Rescue cat",
      canonicalURL: URL(string: "https://purepets.app/ads/minimal")!
    )

    let message = PPAdShareMessageFormatter(copy: .english).message(for: payload)

    XCTAssertFalse(message.contains("Price:"))
    XCTAssertFalse(message.contains("Location:"))
    XCTAssertFalse(message.contains("✅"))
    XCTAssertFalse(message.contains("\n\n\n"))
  }

  func testMessageRemovesCanonicalURLFromBackendTextBeforeAppendingIt() throws {
    let url = URL(string: "https://purepets.app/ads/duplicate")!
    let payload = try PPAdSharePayload(
      id: "duplicate",
      title: "Puppy \(url.absoluteString)",
      shortDescription: "Open \(url.absoluteString) for private notes",
      canonicalURL: url
    )

    let message = PPAdShareMessageFormatter(copy: .english).message(for: payload)

    XCTAssertEqual(
      message.components(separatedBy: url.absoluteString).count - 1,
      1
    )
  }

  func testCopySelectionUsesLocaleNotLayoutDirection() {
    XCTAssertEqual(PPAdShareCopy.forLocale(Locale(identifier: "ar_EG")), .arabic)
    XCTAssertEqual(PPAdShareCopy.forLocale(Locale(identifier: "en_EG")), .english)
    XCTAssertEqual(PPAdShareCopy.forLocale(Locale(identifier: "he_IL")), .english)
  }

  func testCaptionDoesNotExposeSellerNameByDefault() throws {
    let payload = try PPAdSharePayload(
      id: "privacy",
      title: "Rescue cat",
      canonicalURL: URL(string: "https://purepets.app/ads/privacy")!,
      sellerDisplayName: "Approved Public Seller Name"
    )

    let message = PPAdShareMessageFormatter(copy: .english).message(for: payload)

    XCTAssertFalse(message.contains("Approved Public Seller Name"))
  }

  private func makePayload() throws -> PPAdSharePayload {
    try PPAdSharePayload(
      id: "ad-2048",
      title: "Golden Retriever Puppy",
      formattedPrice: "EGP 8,500",
      location: "Cairo",
      shortDescription: "Vaccinated and ready for a caring home.",
      attributes: [
        .init(id: "vaccinated", title: "Vaccinated"),
        .init(id: "male", title: "Male"),
        .init(id: "age", title: "3 months"),
      ],
      canonicalURL: URL(string: "https://purepets.app/ads/ad-2048")!
    )
  }
}
