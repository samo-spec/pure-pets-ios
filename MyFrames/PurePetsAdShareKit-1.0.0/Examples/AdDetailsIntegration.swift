import PurePetsAdShareKit
import SwiftUI

@available(iOS 17.0, *)
struct AdDetailsShareSection: View {
  let payload: PPAdSharePayload

  private let analytics = PPClosureAdShareAnalytics { event in
    // Map only the privacy-safe event to your analytics provider.
    print("Ad share event:", event)
  }

  var body: some View {
    PPAdShareButton(
      payload: payload,
      // Omit this argument to use payload.imageURL automatically.
      imageSource: payload.imageURL.map(PPAdShareImageSource.remote),
      configuration: .purePets,
      analytics: analytics
    )
    .padding(.horizontal, 20)
  }
}

@available(iOS 17.0, *)
func makePublicSharePayload(from ad: AppAdvertisement) throws -> PPAdSharePayload {
  try PPAdSharePayload(
    id: ad.publicID,
    title: ad.title,
    formattedPrice: ad.formattedPrice,
    location: ad.publicLocation,
    shortDescription: ad.publicSummary,
    attributes: ad.publicHighlights.map {
      PPAdShareAttribute(id: $0.key, title: $0.value)
    },
    imageURL: ad.primaryImageURL,
    canonicalURL: ad.publicWebURL,
    sellerDisplayName: ad.publicSellerName
  )
}

// Replace this protocol with your repository's real advertisement model.
protocol AppAdvertisement {
  var publicID: String { get }
  var title: String { get }
  var formattedPrice: String? { get }
  var publicLocation: String? { get }
  var publicSummary: String? { get }
  var publicHighlights: [(key: String, value: String)] { get }
  var primaryImageURL: URL? { get }
  var publicWebURL: URL { get }
  var publicSellerName: String? { get }
}
