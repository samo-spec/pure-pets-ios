import SwiftUI
import UIKit

public struct MessageQuickReactionBar: View {
  public let onSelectEmoji: (String) -> Void
  public let onDismiss: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  public static let defaultEmojis: [String] = ["❤️", "👍", "🐾", "😂", "😮", "🙏"]

  public init(
    onSelectEmoji: @escaping (String) -> Void,
    onDismiss: @escaping () -> Void = {}
  ) {
    self.onSelectEmoji = onSelectEmoji
    self.onDismiss = onDismiss
  }

  public var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(Self.defaultEmojis.enumerated()), id: \.offset) { index, emoji in
        Button {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          onSelectEmoji(emoji)
        } label: {
          Text(emoji)
            .font(.system(size: 24))
            .frame(width: 38, height: 38)
            .contentShape(Circle())
        }
        .buttonStyle(QuickReactionBounceStyle())
        .scaleEffect(appeared || reduceMotion ? 1 : 0.001)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .animation(
          reduceMotion ? nil : PurePetsMessagingMotion.springBouncy.delay(Double(index) * 0.035),
          value: appeared
        )
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Capsule(style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
    )
    .overlay(
      Capsule(style: .continuous)
        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.75)
    )
    .onAppear {
      withAnimation(PurePetsMessagingMotion.springBouncy) {
        appeared = true
      }
    }
  }
}

private struct QuickReactionBounceStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 1.35 : 1.0)
      .animation(PurePetsMessagingMotion.springSnap, value: configuration.isPressed)
  }
}
