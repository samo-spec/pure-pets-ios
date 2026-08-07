import SwiftUI

struct UnsupportedMessageView: View {
  let payload: UnsupportedPayload
  let onUpdateApp: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(PurePetsMessagingTheme.signal)
          .frame(width: 28, height: 28)
          .background(PurePetsMessagingTheme.brandSoft, in: Circle())
          .accessibilityHidden(true)

        Text(localized("chat_message_unavailable"))
          .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
      }

      Text(localized("chat_message_requires_update"))
        .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Button(action: onUpdateApp) {
        Text(localized("chat_update_app"))
          .font(Font.ppBeirutiSemiBold(size: 13.5, relativeTo: .subheadline))
          .foregroundStyle(PurePetsMessagingTheme.signalForeground)
          .padding(.horizontal, 14)
          .frame(minHeight: 44)
          .background(PurePetsMessagingTheme.signal, in: Capsule())
      }
      .buttonStyle(PurePetsMessagingPressButtonStyle())
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
