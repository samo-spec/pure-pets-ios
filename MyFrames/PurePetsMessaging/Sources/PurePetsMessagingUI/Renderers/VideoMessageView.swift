import SwiftUI

struct VideoMessageView: View {
  let payload: VideoPayload
  let onOpen: () -> Void

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
    .accessibilityLabel("Video, \(payload.accessibilityDescription), \(durationText)")
    .accessibilityHint("Opens the video player")
  }

  private var clampedAspectRatio: Double {
    min(max(payload.dimensions.aspectRatio, 0.65), 1.8)
  }

  private var durationText: String {
    let seconds = max(Int(payload.duration.rounded()), 0)
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
