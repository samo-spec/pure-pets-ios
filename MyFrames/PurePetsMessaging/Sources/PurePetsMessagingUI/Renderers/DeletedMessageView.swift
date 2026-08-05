import SwiftUI

struct DeletedMessageView: View {
  let payload: DeletedPayload

  var body: some View {
    Label(message, systemImage: "nosign")
      .font(.subheadline.italic())
      .foregroundStyle(.secondary)
      .accessibilityLabel(message)
  }

  private var message: String {
    switch payload.deletedBy {
    case .sender:
      "This message was deleted"
    case .recipient:
      "You deleted this message"
    case .moderator:
      "This message was removed by a moderator"
    case .system:
      "This message is no longer available"
    }
  }
}
