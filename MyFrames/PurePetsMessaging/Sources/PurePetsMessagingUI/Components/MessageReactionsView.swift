import SwiftUI

struct MessageReactionsView: View {
  let reactions: [MessageReaction]
  let onReactionTap: (MessageReaction) -> Void

  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

  @ViewBuilder
  var body: some View {
    if !reactions.isEmpty {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 5) {
          reactionButtons
        }
      } else {
        if #available(iOS 16.0, *) {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
              reactionButtons
            }

            VStack(alignment: .leading, spacing: 5) {
              reactionButtons
            }
          }
        } else {
          HStack(spacing: 5) {
            reactionButtons
          }
        }
      }
    }
  }

  @ViewBuilder
  private var reactionButtons: some View {
    ForEach(reactions) { reaction in
      Button {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onReactionTap(reaction)
      } label: {
        HStack(spacing: 4) {
          Text(reaction.emoji)
            .font(.system(size: 13))
          Text(localizedCount(reaction.count))
            .monospacedDigit()
            .font(Font.ppBeirutiBold(size: 11.5, relativeTo: .caption))
            .foregroundStyle(
              reaction.reactedByCurrentUser
                ? PurePetsMessagingTheme.signal
                : .primary
            )

          if reaction.reactedByCurrentUser && differentiateWithoutColor {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(PurePetsMessagingTheme.signal)
              .accessibilityHidden(true)
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          reaction.reactedByCurrentUser
            ? PurePetsMessagingTheme.brandSoft
            : PurePetsMessagingTheme.reactionSurface,
          in: Capsule(style: .continuous)
        )
        .overlay {
          Capsule(style: .continuous)
            .strokeBorder(
              reaction.reactedByCurrentUser
                ? PurePetsMessagingTheme.signal.opacity(0.38)
                : PurePetsMessagingTheme.surfaceStroke,
              lineWidth: reaction.reactedByCurrentUser ? 1 : 0.65
            )
        }
        .shadow(
          color: Color.black.opacity(reaction.reactedByCurrentUser ? 0.06 : 0.03),
          radius: 3,
          x: 0,
          y: 1
        )
      }
      .buttonStyle(PurePetsMessagingPressButtonStyle())
      .contentShape(Capsule(style: .continuous))
      .accessibilityAddTraits(reaction.reactedByCurrentUser ? .isSelected : [])
      .accessibilityLabel(
        String(
          format: localized("chat_reaction_accessibility_format"),
          reaction.emoji,
          localizedCount(reaction.count)
        )
      )
    }
  }

  private func localizedCount(_ count: Int) -> String {
    count.formatted(.number.locale(locale))
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
