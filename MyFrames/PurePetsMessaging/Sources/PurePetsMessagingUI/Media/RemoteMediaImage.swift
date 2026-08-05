import SwiftUI

struct RemoteMediaImage<Placeholder: View>: View {
  let url: URL?
  let contentMode: ContentMode
  @ViewBuilder let placeholder: () -> Placeholder

  var body: some View {
    if let url {
      AsyncImage(url: url, transaction: .init(animation: .easeInOut(duration: 0.18))) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .transition(.opacity)
        case .empty:
          placeholder()
            .overlay {
              ProgressView()
            }
        case .failure:
          placeholder()
            .overlay {
              Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(PurePetsMessagingTheme.danger)
            }
        @unknown default:
          placeholder()
        }
      }
    } else {
      placeholder()
    }
  }
}
