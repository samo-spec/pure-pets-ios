#if DEBUG && canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  @available(iOS 17.0, *)
  private enum PPAdSharePreviewFixture {
    static let payload: PPAdSharePayload = {
      do {
        return try PPAdSharePayload(
          id: "preview-ad",
          title: "Golden Retriever Puppy",
          formattedPrice: "EGP 8,500",
          location: "Cairo",
          shortDescription: "Vaccinated and ready for a caring home.",
          attributes: [
            .init(id: "vaccinated", title: "Vaccinated"),
            .init(id: "male", title: "Male"),
            .init(id: "age", title: "3 months"),
          ],
          canonicalURL: URL(string: "https://purepets.app/ads/preview-ad")!
        )
      } catch {
        preconditionFailure("Invalid preview payload: \(error)")
      }
    }()

    static let image: UIImage = {
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 700))
      return renderer.image { context in
        UIColor.systemPink.withAlphaComponent(0.18).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 900, height: 700))
        let symbol = UIImage(systemName: "pawprint.fill")?
          .withTintColor(.systemPink, renderingMode: .alwaysOriginal)
        symbol?.draw(in: CGRect(x: 350, y: 250, width: 200, height: 200))
      }
    }()
  }

  @available(iOS 17.0, *)
  struct PPAdSharePreview_Previews: PreviewProvider {
    static var previews: some View {
      VStack(spacing: 18) {
        PPFancyShareLabel(
          copy: .english,
          brandColor: PPAdShareConfiguration.purePets.brandColor,
          isPreparing: false
        )

        PPFancyShareLabel(
          copy: .arabic,
          brandColor: PPAdShareConfiguration.purePets.brandColor,
          isPreparing: true
        )
        .environment(\.layoutDirection, .rightToLeft)
      }
      .padding()
      .previewDisplayName("Fancy share labels")

      ScrollView([.horizontal, .vertical]) {
        PPAdShareCard(
          payload: PPAdSharePreviewFixture.payload,
          listingImage: PPAdSharePreviewFixture.image
        )
        .scaleEffect(0.32, anchor: .topLeading)
        .frame(width: 346, height: 432, alignment: .topLeading)
      }
      .previewDisplayName("Export card")
    }
  }
#endif
