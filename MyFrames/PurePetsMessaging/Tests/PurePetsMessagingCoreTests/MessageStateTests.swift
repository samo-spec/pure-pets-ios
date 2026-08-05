import Foundation
import Testing

@testable import PurePetsMessagingCore

struct MessageStateTests {
  @Test
  func incomingMessageHasNoOutgoingDeliveryState() {
    let direction = MessageDirection.incoming(receivedAt: .now)

    #expect(direction.isOutgoing == false)
  }

  @Test
  func uploadingProgressIsClamped() {
    let aboveRange = OutgoingDeliveryState.uploading(progress: 1.8)
    let belowRange = OutgoingDeliveryState.uploading(progress: -0.5)

    #expect(aboveRange.normalizedProgress == 1)
    #expect(belowRange.normalizedProgress == 0)
  }

  @Test
  func stickerDescriptionCannotBeEmpty() {
    #expect(throws: NonEmptyText.ValidationError.empty) {
      _ = try NonEmptyText("   ")
    }
  }

  @Test
  func stickerUsesTransparentChrome() throws {
    let sticker = StickerPayload(
      fallbackEmoji: "🐶",
      accessibilityDescription: try NonEmptyText("Happy puppy")
    )

    #expect(MessagePayload.sticker(sticker).usesTransparentChrome)
    #expect(MessagePayload.text(TextPayload(text: "Hello")).usesTransparentChrome == false)
  }

  @Test
  func deletedAndUnsupportedMessagesCannotBeForwarded() {
    let deleted = MessagePayload.deleted(DeletedPayload(deletedBy: .sender))
    let unsupported = MessagePayload.unsupported(
      UnsupportedPayload(typeIdentifier: "future.payload")
    )

    #expect(deleted.canForward == false)
    #expect(unsupported.canForward == false)
  }

  @Test
  func staleOnlinePresenceNormalizesToActiveRecently() {
    let expired = Date.now.addingTimeInterval(-30)
    let presence = ConversationPresence.online(expiresAt: expired)

    #expect(presence.normalized(at: .now) == .activeRecently(expired))
  }
}
