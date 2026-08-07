import SwiftUI

struct StickerMessageView: View {
  let payload: StickerPayload

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hasPresented = false

  var body: some View {
    RemoteMediaImage(url: payload.assetURL, contentMode: .fit) {
      Text(payload.fallbackEmoji)
        .font(.system(size: stickerSize))
        .minimumScaleFactor(0.6)
    }
    .frame(width: stickerSize, height: stickerSize)
    .scaleEffect(
      payload.isAnimated && !reduceMotion && !hasPresented ? 0.96 : 1
    )
    .rotationEffect(
      .degrees(payload.isAnimated && !reduceMotion && !hasPresented ? -1.2 : 0)
    )
    .shadow(
      color: PurePetsMessagingTheme.messageShadow.opacity(0.34),
      radius: 4,
      y: 2
    )
    .onAppear {
      guard !hasPresented else { return }
      guard payload.isAnimated, !reduceMotion else {
        hasPresented = true
        return
      }
      withAnimation(PurePetsMessagingMotion.standard) {
        hasPresented = true
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      String(
        format: localized("chat_sticker_accessibility_format"),
        payload.accessibilityDescription.value
      )
    )
  }

  private var stickerSize: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 176 : 148
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
