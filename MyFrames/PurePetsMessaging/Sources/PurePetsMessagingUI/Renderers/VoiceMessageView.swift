import SwiftUI

struct VoiceMessageView: View {
  let messageID: MessageID
  let payload: VoicePayload
  let audioCoordinator: ConversationAudioCoordinator

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 10) {
          playButton
          waveform
        }
      } else {
        HStack(spacing: 10) {
          playButton
          waveform
        }
      }
    }
    .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 220)
    .onDisappear {
      audioCoordinator.stop(messageID: messageID)
    }
  }

  private var playButton: some View {
    Button {
      audioCoordinator.toggle(messageID: messageID, payload: payload)
    } label: {
      Image(systemName: audioCoordinator.isPlaying(messageID) ? "pause.fill" : "play.fill")
        .font(.headline)
        .frame(width: 44, height: 44)
        .background(PurePetsMessagingTheme.brand, in: .circle)
        .foregroundStyle(.white)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      audioCoordinator.isPlaying(messageID) ? "Pause voice message" : "Play voice message")
  }

  private var waveform: some View {
    VStack(alignment: .leading, spacing: 5) {
      GeometryReader { proxy in
        HStack(alignment: .center, spacing: 2) {
          ForEach(Array(payload.waveform.enumerated()), id: \.offset) { index, sample in
            Capsule()
              .fill(
                isPlayed(index)
                  ? PurePetsMessagingTheme.brand
                  : Color.secondary.opacity(0.45)
              )
              .frame(
                width: max(
                  2,
                  (proxy.size.width - CGFloat(payload.waveform.count - 1) * 2)
                    / CGFloat(max(payload.waveform.count, 1))
                ),
                height: max(5, 32 * sample)
              )
          }
        }
        .frame(maxHeight: .infinity)
      }
      .frame(height: 36)

      HStack {
        Text(elapsedText)
        Spacer()
        Text(durationText)
      }
      .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
      .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Voice message")
    .accessibilityValue("\(elapsedText) of \(durationText)")
  }

  private var progress: Double {
    audioCoordinator.progress(for: messageID)
  }

  private func isPlayed(_ index: Int) -> Bool {
    guard !payload.waveform.isEmpty else {
      return false
    }
    return Double(index) / Double(payload.waveform.count) <= progress
  }

  private var elapsedText: String {
    durationString(payload.duration * progress)
  }

  private var durationText: String {
    durationString(payload.duration)
  }

  private func durationString(_ duration: TimeInterval) -> String {
    let seconds = max(Int(duration.rounded()), 0)
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
