import SwiftUI

struct MessageReactionsView: View {
  let reactions: [MessageReaction]
  let onReactionTap: (MessageReaction) -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    if !reactions.isEmpty {
      HStack(spacing: 4) {
        ForEach(reactions) { reaction in
          Button {
            onReactionTap(reaction)
          } label: {
            Text("\(reaction.emoji) \(localizedCount(reaction.count))")
              .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                reaction.reactedByCurrentUser
                  ? PurePetsMessagingTheme.brandSoft
                  : Color(uiColor: .tertiarySystemBackground),
                in: .capsule
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            String(
              format: localized("chat_reaction_accessibility_format"),
              reaction.emoji,
              localizedCount(reaction.count)
            )
          )
        }
      }
    }
  }

  private func localizedCount(_ count: Int) -> String {
    count.formatted(.number.locale(locale))
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
