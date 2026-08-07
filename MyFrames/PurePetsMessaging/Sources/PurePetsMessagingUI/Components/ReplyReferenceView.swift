import SwiftUI

struct ReplyReferenceView: View {
  let reference: ReplyReference
  let onOpen: () -> Void

  @Environment(\.layoutDirection) private var fallbackLayoutDirection

  var body: some View {
    Button(action: onOpen) {
      HStack(spacing: 10) {
        Capsule(style: .continuous)
          .fill(
            LinearGradient(
              colors: [PurePetsMessagingTheme.signal, PurePetsMessagingTheme.brandDeep],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 3)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(reference.senderDisplayName)
            .font(Font.ppBeirutiSemiBold(size: 12.5, relativeTo: .caption))
            .foregroundStyle(PurePetsMessagingTheme.signal)
            .lineLimit(1)
            .truncationMode(.tail)

          HStack(spacing: 5) {
            Image(systemName: previewSymbol)
              .font(.system(size: 10.5, weight: .semibold))
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)

            Text(previewText)
              .font(Font.ppBeirutiRegular(size: 12.5, relativeTo: .caption))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "arrow.up.left.and.arrow.down.right")
          .font(.system(size: 9.5, weight: .semibold))
          .foregroundStyle(PurePetsMessagingTheme.signal.opacity(0.72))
          .frame(width: 24, height: 24)
          .background(PurePetsMessagingTheme.signal.opacity(0.08), in: Circle())
          .accessibilityHidden(true)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(minWidth: 154, alignment: .leading)
      .background(
        PurePetsMessagingTheme.replySurface,
        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .strokeBorder(PurePetsMessagingTheme.surfaceStroke, lineWidth: 0.65)
      }
      .contentShape(.rect)
      .environment(\.layoutDirection, resolvedLayoutDirection)
    }
    .buttonStyle(PurePetsMessagingPressButtonStyle())
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
