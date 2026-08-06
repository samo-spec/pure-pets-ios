import SwiftUI

struct VideoMessageView: View {
  let payload: VideoPayload
  let onOpen: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    Button(action: onOpen) {
      ZStack {
        RemoteMediaImage(url: payload.thumbnailURL, contentMode: .fill) {
          Rectangle()
            .fill(.quaternary)
            .overlay {
              Image(systemName: "video")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            }
        }

        Circle()
          .fill(.black.opacity(0.58))
          .frame(width: 52, height: 52)
          .overlay {
            Image(systemName: "play.fill")
              .foregroundStyle(.white)
          }

        Text(durationText)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.white)
          .padding(.horizontal, 7)
          .padding(.vertical, 4)
          .background(.black.opacity(0.65), in: .capsule)
          .padding(8)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }
      .frame(maxWidth: 280)
      .aspectRatio(clampedAspectRatio, contentMode: .fit)
      .clipShape(.rect(cornerRadius: 14, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      String(
        format: localized("chat_video_accessibility_format"),
        payload.accessibilityDescription,
        durationText
      )
    )
    .accessibilityHint(localized("chat_video_open_accessibility_hint"))
  }

  private var clampedAspectRatio: Double {
    min(max(payload.dimensions.aspectRatio, 0.65), 1.8)
  }

  private var durationText: String {
    PurePetsMessageDurationFormatter.string(for: payload.duration, locale: locale)
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
