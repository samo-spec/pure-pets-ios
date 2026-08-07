import SwiftUI

struct ImageMessageView: View {
  let payload: ImagePayload
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      ZStack {
        RemoteMediaImage(
          url: payload.thumbnailURL ?? payload.imageURL,
          contentMode: .fill
        ) {
          LinearGradient(
            colors: [
              PurePetsMessagingTheme.surfaceRaised,
              PurePetsMessagingTheme.replySurface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .overlay {
            Image(systemName: "photo.on.rectangle.angled")
              .font(.system(size: 27, weight: .light))
              .foregroundStyle(.secondary)
          }
        }

        LinearGradient(
          colors: [.clear, Color.black.opacity(0.10)],
          startPoint: .center,
          endPoint: .bottom
        )
        .allowsHitTesting(false)
      }
      .frame(maxWidth: 284)
      .aspectRatio(clampedAspectRatio, contentMode: .fit)
      .clipShape(.rect(cornerRadius: 17, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
          .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
      }
      .contentShape(.rect)
    }
    .buttonStyle(PurePetsMessagingPressButtonStyle())
    .accessibilityLabel(
      String(
        format: localized("chat_image_accessibility_format"),
        payload.accessibilityDescription
      )
    )
    .accessibilityHint(localized("chat_image_open_accessibility_hint"))
  }

  private var clampedAspectRatio: Double {
    min(max(payload.dimensions.aspectRatio, 0.65), 1.8)
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
