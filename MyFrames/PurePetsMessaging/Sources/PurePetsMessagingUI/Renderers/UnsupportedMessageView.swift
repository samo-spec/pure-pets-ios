import SwiftUI

struct UnsupportedMessageView: View {
  let payload: UnsupportedPayload
  let onUpdateApp: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Message unavailable", systemImage: "exclamationmark.triangle")
        .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))

      Text("This message type requires a newer app version.")
        .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
        .foregroundStyle(.secondary)

      Button("Update app", action: onUpdateApp)
        .buttonStyle(.bordered)
        .tint(PurePetsMessagingTheme.brand)
    }
    .accessibilityElement(children: .contain)
    .accessibilityHint("Unsupported type \(payload.typeIdentifier)")
  }
}
