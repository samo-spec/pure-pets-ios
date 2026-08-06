import XCTest

@testable import PurePetsAdShareKit

final class PPAdSharePayloadTests: XCTestCase {
  func testPayloadTrimsPublicFieldsAndDeduplicatesAttributes() throws {
    let payload = try PPAdSharePayload(
      id: "  ad-2048  ",
      title: "  Golden Retriever Puppy  ",
      formattedPrice: "  EGP 8,500  ",
      location: "  Cairo  ",
      shortDescription: "  Vaccinated and ready for a caring home.  ",
      attributes: [
        .init(id: "vaccinated", title: " Vaccinated "),
        .init(id: "vaccinated", title: "Duplicate"),
        .init(id: "male", title: " Male "),
        .init(id: "age", title: " 3 months "),
        .init(id: "extra", title: " Extra "),
      ],
      imageURL: URL(string: "https://cdn.example.com/ad.jpg"),
      canonicalURL: URL(string: "https://purepets.app/ads/ad-2048")!,
      sellerDisplayName: "  Pure Pets Seller  "
    )

    XCTAssertEqual(payload.id, "ad-2048")
    XCTAssertEqual(payload.title, "Golden Retriever Puppy")
    XCTAssertEqual(payload.formattedPrice, "EGP 8,500")
    XCTAssertEqual(payload.location, "Cairo")
    XCTAssertEqual(payload.attributes.map(\.id), ["vaccinated", "male", "age"])
    XCTAssertEqual(payload.sellerDisplayName, "Pure Pets Seller")
  }

  func testPayloadRejectsBlankID() {
    XCTAssertThrowsError(
      try PPAdSharePayload(
        id: "   ",
        title: "Puppy",
        canonicalURL: URL(string: "https://purepets.app/ads/1")!
      )
    ) { error in
      XCTAssertEqual(error as? PPAdShareError, .invalidIdentifier)
    }
  }

  func testPayloadRejectsInsecureRemoteImageURL() {
    XCTAssertThrowsError(
      try PPAdSharePayload(
        id: "1",
        title: "Puppy",
        imageURL: URL(string: "http://cdn.purepets.app/ad.jpg")!,
        canonicalURL: URL(string: "https://purepets.app/ads/1")!
      )
    ) { error in
      XCTAssertEqual(error as? PPAdShareError, .invalidImageURL)
    }
  }

  func testPayloadRejectsNonHTTPCanonicalURL() {
    XCTAssertThrowsError(
      try PPAdSharePayload(
        id: "1",
        title: "Puppy",
        canonicalURL: URL(string: "purepets://ads/1")!
      )
    ) { error in
      XCTAssertEqual(error as? PPAdShareError, .invalidCanonicalURL)
    }
  }

  func testPayloadRejectsInsecureCanonicalURL() {
    XCTAssertThrowsError(
      try PPAdSharePayload(
        id: "1",
        title: "Puppy",
        canonicalURL: URL(string: "http://purepets.app/ads/1")!
      )
    ) { error in
      XCTAssertEqual(error as? PPAdShareError, .invalidCanonicalURL)
    }
  }

  func testPayloadRejectsExcessiveIdentifierAndTitleLengths() {
    XCTAssertThrowsError(
      try PPAdSharePayload(
        id: String(repeating: "a", count: 257),
        title: "Puppy",
        canonicalURL: URL(string: "https://purepets.app/ads/1")!
      )
    ) { error in
      XCTAssertEqual(error as? PPAdShareError, .identifierTooLong)
    }

    XCTAssertThrowsError(
      try PPAdSharePayload(
        id: "1",
        title: String(repeating: "a", count: 241),
        canonicalURL: URL(string: "https://purepets.app/ads/1")!
      )
    ) { error in
      XCTAssertEqual(error as? PPAdShareError, .titleTooLong)
    }
  }

  func testPayloadBoundsOptionalPresentationStrings() throws {
    let payload = try PPAdSharePayload(
      id: "bounded",
      title: "Puppy",
      formattedPrice: String(repeating: "1", count: 120),
      location: String(repeating: "L", count: 180),
      shortDescription: String(repeating: "D", count: 700),
      attributes: [
        .init(id: "attribute", title: String(repeating: "A", count: 120))
      ],
      canonicalURL: URL(string: "https://purepets.app/ads/bounded")!,
      sellerDisplayName: String(repeating: "S", count: 180)
    )

    XCTAssertEqual(payload.formattedPrice?.count, 80)
    XCTAssertEqual(payload.location?.count, 120)
    XCTAssertEqual(payload.shortDescription?.count, 500)
    XCTAssertEqual(payload.attributes.first?.title.count, 80)
    XCTAssertEqual(payload.sellerDisplayName?.count, 120)
  }

  func testPayloadRejectsBlankTitle() {
    XCTAssertThrowsError(
      try PPAdSharePayload(
        id: "1",
        title: "\n\t",
        canonicalURL: URL(string: "https://purepets.app/ads/1")!
      )
    ) { error in
      XCTAssertEqual(error as? PPAdShareError, .invalidTitle)
    }
  }

  func testPayloadRejectsLocalAndPrivateNetworkURLs() {
    let blockedURLs = [
      "https://localhost/ad.jpg",
      "https://api.localhost/ad.jpg",
      "https://127.0.0.1/ad.jpg",
      "https://10.0.0.8/ad.jpg",
      "https://172.16.4.2/ad.jpg",
      "https://192.168.1.4/ad.jpg",
      "https://169.254.10.4/ad.jpg",
      "https://[::1]/ad.jpg",
      "https://[fd00::1]/ad.jpg",
      "https://[fe80::1]/ad.jpg",
    ]

    for value in blockedURLs {
      let url = URL(string: value)!
      XCTAssertThrowsError(
        try PPAdSharePayload(
          id: "private-network",
          title: "Puppy",
          imageURL: url,
          canonicalURL: URL(string: "https://purepets.app/ads/private-network")!
        ),
        "Expected to reject \(value)"
      ) { error in
        XCTAssertEqual(error as? PPAdShareError, .invalidImageURL)
      }
    }
  }

  func testPayloadAcceptsPublicHTTPSHosts() throws {
    let payload = try PPAdSharePayload(
      id: "public-host",
      title: "Puppy",
      imageURL: URL(string: "https://cdn.purepets.app/ad.jpg")!,
      canonicalURL: URL(string: "https://purepets.app/ads/public-host")!
    )

    XCTAssertEqual(payload.imageURL?.host, "cdn.purepets.app")
  }

}
