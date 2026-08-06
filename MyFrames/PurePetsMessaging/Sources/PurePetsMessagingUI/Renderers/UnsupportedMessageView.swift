import SwiftUI

struct UnsupportedMessageView: View {
  let payload: UnsupportedPayload
  let onUpdateApp: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(localized("chat_message_unavailable"), systemImage: "exclamationmark.triangle")
        .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))

      Text(localized("chat_message_requires_update"))
        .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
        .foregroundStyle(.secondary)

      Button(localized("chat_update_app"), action: onUpdateApp)
        .buttonStyle(.bordered)
        .tint(PurePetsMessagingTheme.signal)
    }
    .accessibilityElement(children: .contain)
    .accessibilityHint(
      String(
        format: localized("chat_unsupported_type_accessibility_format"),
        payload.typeIdentifier
      )
    )
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
