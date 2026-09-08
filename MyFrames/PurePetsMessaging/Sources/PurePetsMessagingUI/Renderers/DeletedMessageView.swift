import Foundation
import SwiftUI

struct DeletedMessageView: View {
  let payload: DeletedPayload

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "slash.circle")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 24, height: 24)
        .background(PurePetsMessagingTheme.replySurface, in: Circle())
        .accessibilityHidden(true)

      Text(message)
        .font(Font.ppBeirutiRegular(size: 13.5, relativeTo: .subheadline).italic())
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(message)
  }

  private var message: String {
    let key: String
    switch payload.deletedBy {
    case .sender:
      key = "chat_deleted_by_sender"
    case .recipient:
      key = "chat_deleted_by_recipient"
    case .moderator:
      key = "chat_deleted_by_moderator"
    case .system:
      key = "chat_deleted_by_system"
    }
    return NSLocalizedString(key, comment: "")
  }
}
