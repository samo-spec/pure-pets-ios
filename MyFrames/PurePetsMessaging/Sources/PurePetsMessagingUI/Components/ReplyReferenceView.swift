import SwiftUI

struct ReplyReferenceView: View {
  let reference: ReplyReference
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      HStack(spacing: 8) {
        Capsule()
          .fill(PurePetsMessagingTheme.brand)
          .frame(width: 3)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(reference.senderDisplayName)
            .font(Font.ppBeirutiSemiBold(size: 12, relativeTo: .caption))
            .foregroundStyle(PurePetsMessagingTheme.brand)

          Label(previewText, systemImage: previewSymbol)
            .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary, in: .rect(cornerRadius: 10))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Replying to \(reference.senderDisplayName), \(previewText)")
  }

  private var previewText: String {
    switch reference.preview {
    case .text(let text): text
    case .voice: "Voice message"
    case .image: "Image"
    case .video: "Video"
    case .sticker(let description): "Sticker, \(description)"
    case .deleted: "Deleted message"
    case .unsupported: "Unavailable message"
    }
  }

  private var previewSymbol: String {
    switch reference.preview {
    case .text: "text.bubble"
    case .voice: "waveform"
    case .image: "photo"
    case .video: "play.rectangle"
    case .sticker: "face.smiling"
    case .deleted: "nosign"
    case .unsupported: "questionmark.square.dashed"
    }
  }
}
