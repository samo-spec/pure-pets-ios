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
        onReactionTap(reaction)
      } label: {
        HStack(spacing: 5) {
          Text(reaction.emoji)
          Text(localizedCount(reaction.count))
            .monospacedDigit()

          if reaction.reactedByCurrentUser && differentiateWithoutColor {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 10, weight: .bold))
              .accessibilityHidden(true)
          }
        }
        .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .frame(minWidth: 44, minHeight: 44)
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
                ? PurePetsMessagingTheme.signal.opacity(0.34)
                : PurePetsMessagingTheme.surfaceStroke,
              lineWidth: reaction.reactedByCurrentUser ? 1 : 0.7
            )
        }
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
