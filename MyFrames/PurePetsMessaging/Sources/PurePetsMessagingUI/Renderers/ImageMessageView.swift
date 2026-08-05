import SwiftUI

struct ImageMessageView: View {
  let payload: ImagePayload
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      RemoteMediaImage(url: payload.thumbnailURL ?? payload.imageURL, contentMode: .fill) {
        Rectangle()
          .fill(.quaternary)
          .overlay {
            Image(systemName: "photo")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
          }
      }
      .frame(maxWidth: 280)
      .aspectRatio(clampedAspectRatio, contentMode: .fit)
      .clipShape(.rect(cornerRadius: 14, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Image, \(payload.accessibilityDescription)")
    .accessibilityHint("Opens the image viewer")
  }

  private var clampedAspectRatio: Double {
    min(max(payload.dimensions.aspectRatio, 0.65), 1.8)
  }
}
