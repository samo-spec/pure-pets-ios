import SwiftUI

struct StickerMessageView: View {
  let payload: StickerPayload

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    RemoteMediaImage(url: payload.assetURL, contentMode: .fit) {
      Text(payload.fallbackEmoji)
        .font(.system(size: stickerSize))
        .minimumScaleFactor(0.6)
    }
    .frame(width: stickerSize, height: stickerSize)
    .modifier(
      StickerMotionModifier(
        isEnabled: payload.isAnimated && !reduceMotion
      )
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      String(
        format: localized("chat_sticker_accessibility_format"),
        payload.accessibilityDescription.value
      )
    )
  }

  private var stickerSize: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 176 : 144
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}

private struct StickerMotionModifier: ViewModifier {
  let isEnabled: Bool

  func body(content: Content) -> some View {
    if isEnabled {
      content
        .phaseAnimator([false, true]) { view, lifted in
          view
            .offset(y: lifted ? -5 : 0)
            .rotationEffect(.degrees(lifted ? 1.5 : -0.5))
        } animation: { _ in
          .easeInOut(duration: 0.9)
        }
    } else {
      content
    }
  }
}
