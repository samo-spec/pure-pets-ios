import SwiftUI

struct VideoMessageView: View {
  let payload: VideoPayload
  let onOpen: () -> Void

  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  var body: some View {
    Button(action: onOpen) {
      ZStack {
        RemoteMediaImage(url: payload.thumbnailURL, contentMode: .fill) {
          LinearGradient(
            colors: [
              PurePetsMessagingTheme.surfaceRaised,
              PurePetsMessagingTheme.replySurface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .overlay {
            Image(systemName: "video")
              .font(.system(size: 28, weight: .light))
              .foregroundStyle(.secondary)
          }
        }

        LinearGradient(
          colors: [Color.black.opacity(0.06), Color.black.opacity(0.38)],
          startPoint: .top,
          endPoint: .bottom
        )

        ZStack {
          Circle()
            .fill(resolvedMediaChrome)
          Circle()
            .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.8)
          Image(systemName: "play.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .offset(x: 1)
        }
        .frame(width: 54, height: 54)

        Text(durationText)
          .font(Font.ppBeirutiSemiBold(size: 11.5, relativeTo: .caption).monospacedDigit())
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .frame(minHeight: 28)
          .background(resolvedMediaChrome, in: Capsule())
          .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7)
          }
          .padding(9)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
        format: localized("chat_video_accessibility_format"),
        payload.accessibilityDescription,
        durationText
      )
    )
    .accessibilityHint(localized("chat_video_open_accessibility_hint"))
  }

  private var resolvedMediaChrome: Color {
    if reduceTransparency || colorSchemeContrast == .increased {
      Color.black
    } else {
      PurePetsMessagingTheme.mediaChrome
    }
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
