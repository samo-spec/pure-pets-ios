import SwiftUI

struct DeliveryStatusView: View {
  let direction: MessageDirection
  let timestamp: Date
  let isEdited: Bool
  let onRetry: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      if isEdited {
        Text("Edited")
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
        .accessibilityLabel("Queued")

    case .uploading(let progress):
      ProgressView(value: min(max(progress, 0), 1))
        .frame(width: 30)
        .accessibilityLabel("Uploading")
        .accessibilityValue(Text(progress, format: .percent))

    case .sent:
      Image(systemName: "checkmark")
        .accessibilityLabel("Sent")

    case .delivered:
      Image(systemName: "checkmark.circle")
        .accessibilityLabel("Delivered")

    case .read:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(PurePetsMessagingTheme.brand)
        .accessibilityLabel("Read")

    case .failed:
      Button(action: onRetry) {
        Label("Retry", systemImage: "exclamationmark.circle.fill")
          .foregroundStyle(PurePetsMessagingTheme.danger)
      }
      .buttonStyle(.plain)
      .accessibilityHint("Attempts to send this message again")
    }
  }
}
