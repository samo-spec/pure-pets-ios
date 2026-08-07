import SwiftUI

struct DeliveryStatusView: View {
  let direction: MessageDirection
  let timestamp: Date
  let isEdited: Bool
  let onRetry: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 4) {
      if isEdited {
        Text(localized("chat_status_edited"))
      }

      Text(timestamp, style: .time)
        .monospacedDigit()

      if case .outgoing(let state) = direction {
        // A FIXED-SIZE slot. Every outgoing state (queued/uploading/sent/
        // delivered/read/failed) renders inside the same footprint, so a
        // status change animates in place and never reflows the bubble or
        // nudges the transcript — the root of "jumping" during status updates.
        statusSlot(state)
          .frame(width: 22, height: 14, alignment: .trailing)
          .animation(reduceMotion ? nil : PurePetsMessagingMotion.status, value: phaseToken(state))
      }
    }
    .font(Font.ppBeirutiRegular(size: 11, relativeTo: .caption2))
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .combine)
  }

  // MARK: - Status slot

  @ViewBuilder
  private func statusSlot(_ state: OutgoingDeliveryState) -> some View {
    switch state {
    case .queued:
      queuedGlyph
        .transition(glyphTransition)

    case .uploading(let progress):
      UploadProgressRing(
        progress: min(max(progress, 0), 1),
        reduceMotion: reduceMotion
      )
      .transition(glyphTransition)

    // A single branch for the three "check" states keeps one Image identity,
    // so the SF Symbol morphs in place (checkmark → double → filled) via the
    // symbol replace transition instead of hard-swapping views.
    case .sent, .delivered, .read:
      checkGlyph(for: state)
        .transition(glyphTransition)

    case .failed:
      failedGlyph
        .transition(glyphTransition)
    }
  }

  private var queuedGlyph: some View {
    Image(systemName: "clock")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .modifier(RepeatingPulse(active: !reduceMotion))
      .accessibilityLabel(localized("chat_status_sending"))
  }

  private func checkGlyph(for state: OutgoingDeliveryState) -> some View {
    let isRead = { if case .read = state { return true } else { return false } }()
    return Image(systemName: checkSymbol(for: state))
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(isRead ? PurePetsMessagingTheme.signal : Color.secondary)
      .contentTransition(.symbolEffect(.replace.downUp))
      .symbolEffect(.bounce, options: .nonRepeating, value: isRead)
      .accessibilityLabel(localized(checkAccessibilityKey(for: state)))
  }

  private var failedGlyph: some View {
    Button(action: onRetry) {
      Image(systemName: "exclamationmark.circle.fill")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(PurePetsMessagingTheme.danger)
        .symbolEffect(.bounce, options: .nonRepeating, value: phaseToken(.failed(.unknown(code: nil))))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(localized("Retry"))
    .accessibilityHint(localized("chat_retry_send_message"))
  }

  // MARK: - Mapping

  private func checkSymbol(for state: OutgoingDeliveryState) -> String {
    switch state {
    case .sent: return "checkmark"
    case .delivered: return "checkmark.circle"
    case .read: return "checkmark.circle.fill"
    default: return "checkmark"
    }
  }

  private func checkAccessibilityKey(for state: OutgoingDeliveryState) -> String {
    switch state {
    case .sent: return "chat_status_sent"
    case .delivered: return "chat_status_delivered"
    case .read: return "chat_status_read"
    default: return "chat_status_sent"
    }
  }

  /// Discrete category used to drive the branch-swap animation. Deliberately
  /// ignores the continuous upload progress value so the ring's own
  /// progress animation owns that, and the branch morph fires only on real
  /// state transitions.
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
      : .opacity.combined(with: .scale(scale: 0.55))
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}

// MARK: - Upload progress ring

/// A compact determinate ring used for the outgoing "uploading" state. Reads as
/// a premium, tactile sending indicator: a faint track, a brand-gradient
/// progress arc that eases toward completion, and a soft leading-cap dot.
private struct UploadProgressRing: View {
  let progress: Double
  let reduceMotion: Bool

  var body: some View {
    ZStack {
      Circle()
        .stroke(
          PurePetsMessagingTheme.waveformTrack(.light).opacity(0.9),
          lineWidth: 2
        )

      Circle()
        .trim(from: 0, to: max(0.02, progress))
        .stroke(
          PurePetsMessagingTheme.waveformPlayedGradient,
          style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(reduceMotion ? nil : PurePetsMessagingMotion.progress, value: progress)
    }
    .frame(width: 13, height: 13)
    .accessibilityLabel(NSLocalizedString("Uploading…", comment: ""))
    .accessibilityValue(Text(progress, format: .percent))
  }
}

// MARK: - Repeating pulse

/// A gentle, infinitely-repeating opacity+scale breath used for the queued
/// state so an outgoing message reads as actively "in flight" while it waits.
private struct RepeatingPulse: ViewModifier {
  let active: Bool
  @State private var on = false

  func body(content: Content) -> some View {
    content
      .opacity(active ? (on ? 1 : 0.45) : 1)
      .scaleEffect(active ? (on ? 1 : 0.9) : 1)
      .onAppear {
        guard active else { return }
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
          on = true
        }
      }
  }
}
