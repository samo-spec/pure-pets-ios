import SwiftUI

struct MessagePayloadView: View {
  let message: ChatMessage
  let audioCoordinator: ConversationAudioCoordinator
  let onOpenImage: (ImagePayload) -> Void
  let onOpenVideo: (VideoPayload) -> Void
  let onUpdateApp: () -> Void

  @ViewBuilder
  var body: some View {
    switch message.payload {
    case .text(let payload):
      TextMessageView(payload: payload)

    case .voice(let payload):
      VoiceMessageView(
        messageID: message.id,
        payload: payload,
        audioCoordinator: audioCoordinator
      )

    case .image(let payload):
      ImageMessageView(payload: payload) {
        onOpenImage(payload)
      }

    case .video(let payload):
      VideoMessageView(payload: payload) {
        onOpenVideo(payload)
      }

    case .sticker(let payload):
      StickerMessageView(payload: payload)

    case .deleted(let payload):
      DeletedMessageView(payload: payload)

    case .unsupported(let payload):
      UnsupportedMessageView(payload: payload, onUpdateApp: onUpdateApp)
    }
  }
}
