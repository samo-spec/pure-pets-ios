import SwiftUI

struct DeliveryStatusView: View {
  let direction: MessageDirection
  let timestamp: Date
  let isEdited: Bool
  let onRetry: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      if isEdited {
        Text(localized("chat_status_edited"))
      }

      Text(timestamp, style: .time)

      if case .outgoing(let state) = direction {
        outgoingStateView(state)
      }
    }
    .font(Font.ppBeirutiRegular(size: 11, relativeTo: .caption2))
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func outgoingStateView(_ state: OutgoingDeliveryState) -> some View {
    switch state {
    case .queued:
      Image(systemName: "clock")
        .accessibilityLabel(localized("chat_status_sending"))

    case .uploading(let progress):
      ProgressView(value: min(max(progress, 0), 1))
        .frame(width: 30)
        .accessibilityLabel(localized("Uploading…"))
        .accessibilityValue(Text(progress, format: .percent))

    case .sent:
      Image(systemName: "checkmark")
        .accessibilityLabel(localized("chat_status_sent"))

    case .delivered:
      Image(systemName: "checkmark.circle")
        .accessibilityLabel(localized("chat_status_delivered"))

    case .read:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(PurePetsMessagingTheme.signal)
        .accessibilityLabel(localized("chat_status_read"))

    case .failed:
      Button(action: onRetry) {
        Label(localized("Retry"), systemImage: "exclamationmark.circle.fill")
          .foregroundStyle(PurePetsMessagingTheme.danger)
      }
      .buttonStyle(.plain)
      .accessibilityHint(localized("chat_retry_send_message"))
    }
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
