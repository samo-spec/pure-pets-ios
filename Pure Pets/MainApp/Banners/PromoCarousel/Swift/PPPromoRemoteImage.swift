import SwiftUI

struct PPPromoRemoteImage: View {
  let url: URL?
  let localImageName: String?
  let accessibilityLabel: String

  var body: some View {
    Group {
      if let localImageName {
        Image(localImageName)
          .resizable()
          .scaledToFit()
      } else if let url {
        AsyncImage(
          url: url,
          transaction: Transaction(animation: .easeOut(duration: 0.24))
        ) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
              .transition(.opacity.combined(with: .scale(scale: 0.98)))
          case .failure:
            fallbackImage
          case .empty:
            placeholder
          @unknown default:
            fallbackImage
          }
        }
      } else {
        fallbackImage
      }
    }
    .accessibilityLabel(accessibilityLabel)
  }

  private var placeholder: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
      .fill(Color.white.opacity(0.38))
      .overlay {
        ProgressView()
          .tint(PPPromoTheme.brandPrimary)
      }
      .padding(16)
      .accessibilityHidden(true)
  }

  private var fallbackImage: some View {
    Image(systemName: "shippingbox.fill")
      .resizable()
      .scaledToFit()
      .foregroundStyle(PPPromoTheme.brandPrimary.opacity(0.62))
      .padding(42)
      .accessibilityHidden(true)
  }
}
