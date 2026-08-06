import SwiftUI

struct VoiceMessageView: View {
  let messageID: MessageID
  let payload: VoicePayload
  let audioCoordinator: ConversationAudioCoordinator

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 10) {
          playButton
          waveform
        }
      } else {
        HStack(spacing: 9) {
          playButton
          waveform
        }
      }
    }
    .frame(
      width: dynamicTypeSize.isAccessibilitySize ? nil : 218,
      alignment: .leading
    )
    .onDisappear {
      audioCoordinator.stop(messageID: messageID)
    }
  }

  private var playButton: some View {
    Button {
      audioCoordinator.toggle(messageID: messageID, payload: payload)
    } label: {
      Image(systemName: audioCoordinator.isPlaying(messageID) ? "pause.fill" : "play.fill")
        .font(.system(size: 15, weight: .bold))
        .frame(width: 40, height: 40)
        .background(PurePetsMessagingTheme.signal, in: .circle)
        .foregroundStyle(PurePetsMessagingTheme.signalForeground)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      localized(
        audioCoordinator.isPlaying(messageID)
          ? "chat_voice_pause_accessibility"
          : "chat_voice_play_accessibility"
      )
    )
  }

  private var waveform: some View {
    VStack(alignment: .leading, spacing: 3) {
      GeometryReader { proxy in
        HStack(alignment: .center, spacing: 2) {
          ForEach(Array(payload.waveform.enumerated()), id: \.offset) { index, sample in
            Capsule()
              .fill(
                isPlayed(index)
                  ? PurePetsMessagingTheme.signal
                  : Color.secondary.opacity(0.45)
              )
              .frame(
                width: max(
                  2,
                  (proxy.size.width - CGFloat(payload.waveform.count - 1) * 2)
                    / CGFloat(max(payload.waveform.count, 1))
                ),
                height: max(4, 25 * sample)
              )
          }
        }
        .frame(maxHeight: .infinity)
      }
      .frame(height: 28)

      HStack {
        Text(elapsedText)
        Spacer()
        Text(durationText)
      }
      .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
      .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(localized("chat_reply_audio"))
    .accessibilityValue(
      String(
        format: localized("chat_voice_progress_accessibility_format"),
        elapsedText,
        durationText
      )
    )
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
    PurePetsMessageDurationFormatter.string(for: duration, locale: locale)
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}
