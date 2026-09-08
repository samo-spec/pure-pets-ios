import SwiftUI

struct DeliveryStatusView: View {
  let direction: MessageDirection
  let timestamp: Date
  let isEdited: Bool
  let onRetry: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 4) {
      if isEdited {
        Text(localized("chat_status_edited"))
      }

      Text(timestamp, style: .time)
        .monospacedDigit()

      if case .outgoing(let state) = direction {
        statusSlot(state)
          .frame(width: 22, height: 16, alignment: .trailing)
          .animation(
            reduceMotion ? nil : PurePetsMessagingMotion.status,
            value: phaseToken(state)
          )
      }
    }
    .font(Font.ppBeirutiRegular(size: 11, relativeTo: .caption2))
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func statusSlot(_ state: OutgoingDeliveryState) -> some View {
    switch state {
    case .queued:
      queuedGlyph.transition(glyphTransition)

    case .uploading(let progress):
      UploadProgressRing(
        progress: min(max(progress, 0), 1),
        colorScheme: colorScheme,
        reduceMotion: reduceMotion
      )
      .transition(glyphTransition)

    case .sent, .delivered, .read:
      checkGlyph(for: state).transition(glyphTransition)

    case .failed:
      Color.clear
        .frame(width: 22, height: 16)
        .overlay {
          failedGlyph
        }
        .transition(glyphTransition)
    }
  }

  private var queuedGlyph: some View {
    Image(systemName: "clock")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .accessibilityLabel(localized("chat_status_sending"))
  }

  @ViewBuilder
  private func checkGlyph(for state: OutgoingDeliveryState) -> some View {
    let isRead = { if case .read = state { return true } else { return false } }()
    let checkColor: Color = isRead ? PurePetsMessagingTheme.signal : Color.secondary.opacity(0.85)

    switch state {
    case .sent:
      Image(systemName: "checkmark")
        .font(.system(size: 10.5, weight: .bold))
        .foregroundStyle(checkColor)
        .accessibilityLabel(localized("chat_status_sent"))

    case .delivered, .read:
      HStack(spacing: -5) {
        Image(systemName: "checkmark")
          .font(.system(size: 10, weight: .bold))
        Image(systemName: "checkmark")
          .font(.system(size: 10, weight: .bold))
      }
      .foregroundStyle(checkColor)
      .accessibilityLabel(localized(isRead ? "chat_status_read" : "chat_status_delivered"))

    default:
      Image(systemName: "checkmark")
        .font(.system(size: 10.5, weight: .bold))
        .foregroundStyle(checkColor)
    }
  }

  private var failedGlyph: some View {
    Button(action: onRetry) {
      Image(systemName: "exclamationmark.circle.fill")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(PurePetsMessagingTheme.danger)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(PurePetsMessagingPressButtonStyle())
    .accessibilityLabel(localized("Retry"))
    .accessibilityHint(localized("chat_retry_send_message"))
  }

  private func phaseToken(_ state: OutgoingDeliveryState) -> Int {
    switch state {
    case .queued: return 0
    case .uploading: return 1
    case .sent: return 2
    case .delivered: return 3
    case .read: return 4
    case .failed: return 5
    }
  }

  private var glyphTransition: AnyTransition {
    reduceMotion
      ? .opacity
      : .opacity.combined(with: .scale(scale: 0.94))
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}

private struct UploadProgressRing: View {
  let progress: Double
  let colorScheme: ColorScheme
  let reduceMotion: Bool

  var body: some View {
    ZStack {
      Circle()
        .stroke(
          PurePetsMessagingTheme.waveformTrack(colorScheme),
          lineWidth: 2
        )

      Circle()
        .trim(from: 0, to: max(0.02, progress))
        .stroke(
          PurePetsMessagingTheme.waveformPlayedGradient,
          style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(
          reduceMotion ? nil : PurePetsMessagingMotion.progress,
          value: progress
        )
    }
    .frame(width: 13, height: 13)
    .accessibilityLabel(NSLocalizedString("Uploading…", comment: ""))
    .accessibilityValue(Text(progress, format: .percent))
  }
}
