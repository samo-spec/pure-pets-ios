import SwiftUI

struct ReplyReferenceView: View {
  let reference: ReplyReference
  let onOpen: () -> Void
  @Environment(\.layoutDirection) private var fallbackLayoutDirection

  var body: some View {
    Button(action: onOpen) {
      HStack(spacing: 8) {
        Capsule()
          .fill(PurePetsMessagingTheme.signal)
          .frame(width: 3)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(reference.senderDisplayName)
            .font(Font.ppBeirutiSemiBold(size: 12, relativeTo: .caption))
            .foregroundStyle(PurePetsMessagingTheme.signal)
            .lineLimit(1)
            .truncationMode(.tail)

          Label(previewText, systemImage: previewSymbol)
            .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 7)
      // A reply should be legible without forcing every quoted message to the
      // transcript's maximum width. Long previews can still grow and wrap
      // within the parent bubble proposal.
      .frame(minWidth: 148, alignment: .leading)
      .background(
        Color.primary.opacity(0.055),
        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.6)
      }
      .contentShape(.rect)
      .environment(\.layoutDirection, resolvedLayoutDirection)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      String(
        format: NSLocalizedString("chat_replying_to_format", comment: ""),
        reference.senderDisplayName
      ) + ", " + previewText
    )
  }

  private var resolvedLayoutDirection: LayoutDirection {
    PurePetsMessageTextDirection.resolve(
      previewText,
      fallback: PurePetsMessageTextDirection.resolve(
        reference.senderDisplayName,
        fallback: fallbackLayoutDirection
      )
    )
  }

  private var previewText: String {
    switch reference.preview {
    case .text(let text): text
    case .voice: localized("chat_reply_audio")
    case .image: localized("chat_reply_image")
    case .video: localized("chat_reply_video")
    case .sticker: localized("chat_reply_sticker")
    case .deleted, .unsupported: localized("chat_reply_unavailable")
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

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
