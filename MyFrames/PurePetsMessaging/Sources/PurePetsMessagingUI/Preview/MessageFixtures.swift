import Foundation
import PurePetsMessagingCore

public enum MessageFixtures {
  public static let customer = MessageSender(
    displayName: "Ahmed Mohamed",
    initials: "AM"
  )

  public static let currentUser = MessageSender(
    displayName: "You",
    initials: "YO"
  )

  public static let header = ChatHeaderPresentation(
    participant: customer,
    roleLabel: "Customer",
    presence: .online(expiresAt: .now.addingTimeInterval(45)),
    context: .activeOrder(
      ActiveOrderContext(orderNumber: "4821", status: .preparing)
    )
  )

  public static let all: [ChatMessage] = [
    ChatMessage(
      sender: customer,
      direction: .incoming(receivedAt: .now),
      payload: .text(TextPayload(text: "Is the salmon recipe available today?")),
      sentAt: .now.addingTimeInterval(-480)
    ),
    ChatMessage(
      sender: currentUser,
      direction: .outgoing(.read(at: .now)),
      payload: .text(TextPayload(text: "Yes — it is available and ready to ship.", isEdited: true)),
      replyReference: ReplyReference(
        messageID: MessageID(),
        senderDisplayName: customer.displayName,
        preview: .text("Is the salmon recipe available today?")
      ),
      reactions: [MessageReaction(emoji: "❤️", count: 2, reactedByCurrentUser: true)],
      sentAt: .now.addingTimeInterval(-420)
    ),
    ChatMessage(
      sender: customer,
      direction: .incoming(receivedAt: .now),
      payload: .voice(
        VoicePayload(
          duration: 18,
          waveform: [0.2, 0.5, 0.32, 0.8, 0.55, 1, 0.42, 0.7, 0.3, 0.88, 0.52, 0.74],
          transcript: "Please add two bags to my order."
        )
      ),
      sentAt: .now.addingTimeInterval(-360)
    ),
    ChatMessage(
      sender: currentUser,
      direction: .outgoing(.delivered),
      payload: .image(
        ImagePayload(
          dimensions: MediaDimensions(width: 4, height: 3),
          accessibilityDescription: "A salmon cat-food bag"
        )
      ),
      sentAt: .now.addingTimeInterval(-300)
    ),
    ChatMessage(
      sender: customer,
      direction: .incoming(receivedAt: .now),
      payload: .video(
        VideoPayload(
          duration: 24,
          dimensions: MediaDimensions(width: 16, height: 9),
          accessibilityDescription: "A short product demonstration"
        )
      ),
      sentAt: .now.addingTimeInterval(-240)
    ),
    ChatMessage(
      sender: currentUser,
      direction: .outgoing(.read(at: .now)),
      payload: .sticker(
        StickerPayload(
          fallbackEmoji: "🐶",
          accessibilityDescription: try! NonEmptyText("Happy puppy waving a paw"),
          isAnimated: true
        )
      ),
      reactions: [MessageReaction(emoji: "😍", count: 1)],
      sentAt: .now.addingTimeInterval(-180)
    ),
    ChatMessage(
      sender: customer,
      direction: .incoming(receivedAt: .now),
      payload: .deleted(DeletedPayload(deletedBy: .sender)),
      sentAt: .now.addingTimeInterval(-120)
    ),
    ChatMessage(
      sender: currentUser,
      direction: .outgoing(.failed(.offline)),
      payload: .unsupported(
        UnsupportedPayload(typeIdentifier: "commerce.bundle", schemaVersion: 4)
      ),
      sentAt: .now.addingTimeInterval(-60)
    ),
  ]
}
