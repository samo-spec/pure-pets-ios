import SwiftUI

struct MessageReactionsView: View {
  let reactions: [MessageReaction]
  let onReactionTap: (MessageReaction) -> Void

  var body: some View {
    if !reactions.isEmpty {
      HStack(spacing: 4) {
        ForEach(reactions) { reaction in
          Button {
            onReactionTap(reaction)
          } label: {
            Text("\(reaction.emoji) \(reaction.count)")
              .font(.caption)
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
            "\(reaction.emoji) reaction, \(reaction.count) people"
          )
        }
      }
    }
  }
}
