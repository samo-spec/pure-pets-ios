import SwiftUI

struct VoiceMessageView: View {
  let messageID: MessageID
  let payload: VoicePayload
  let audioCoordinator: ConversationAudioCoordinator

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let barHeight: CGFloat = 28
  private let maxBarHeight: CGFloat = 26

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

  private var isPlaying: Bool {
    audioCoordinator.isPlaying(messageID)
  }

  private var playButton: some View {
    Button {
      audioCoordinator.toggle(messageID: messageID, payload: payload)
    } label: {
      Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        .font(.system(size: 15, weight: .bold))
        .frame(width: 40, height: 40)
        .background(PurePetsMessagingTheme.signal, in: .circle)
        .foregroundStyle(PurePetsMessagingTheme.signalForeground)
        // Morph play↔pause in place rather than hard-cutting the glyph.
        .contentTransition(.symbolEffect(.replace.offUp))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      localized(
        isPlaying
          ? "chat_voice_pause_accessibility"
          : "chat_voice_play_accessibility"
      )
    )
  }

  private var waveform: some View {
    VStack(alignment: .leading, spacing: 3) {
      GeometryReader { proxy in
        waveBars(width: proxy.size.width)
      }
      .frame(height: barHeight)

      HStack {
        Text(elapsedText)
        Spacer()
        Text(durationText)
      }
      .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
      .monospacedDigit()
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

  /// While playing (and motion is allowed) a `TimelineView` drives a subtle
  /// travelling pulse at the playhead so the bar reads as *alive* without ever
  /// changing the view's footprint. Otherwise the bars are perfectly static.
  @ViewBuilder
  private func waveBars(width: CGFloat) -> some View {
    if isPlaying && !reduceMotion {
      TimelineView(.animation) { timeline in
        barsRow(width: width, time: timeline.date.timeIntervalSinceReferenceDate)
      }
    } else {
      barsRow(width: width, time: nil)
    }
  }

  private func barsRow(width: CGFloat, time: TimeInterval?) -> some View {
    let count = max(payload.waveform.count, 1)
    let barWidth = max(2, (width - CGFloat(count - 1) * 2) / CGFloat(count))
    let playheadIndex = Int((progress * Double(count)).rounded(.down))

    return HStack(alignment: .center, spacing: 2) {
      ForEach(Array(payload.waveform.enumerated()), id: \.offset) { index, sample in
        let played = isPlayed(index)
        Capsule()
          .fill(
            played
              ? AnyShapeStyle(PurePetsMessagingTheme.waveformPlayedGradient)
              : AnyShapeStyle(PurePetsMessagingTheme.waveformTrack(.light))
          )
          .frame(
            width: barWidth,
            height: max(4, maxBarHeight * sample * playheadPulse(index, playheadIndex, time))
          )
          // Only the fill (progress) animates implicitly; height while playing
          // is driven directly by TimelineView so the two never fight.
          .animation(reduceMotion ? nil : PurePetsMessagingMotion.waveBar, value: played)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// A gentle amplitude bump on the 1–2 bars nearest the playhead. Returns 1.0
  /// (no change) when not playing or under Reduce Motion.
  private func playheadPulse(_ index: Int, _ playheadIndex: Int, _ time: TimeInterval?) -> CGFloat {
    guard let time else { return 1 }
    let distance = abs(index - playheadIndex)
    guard distance <= 1 else { return 1 }
    let falloff: CGFloat = distance == 0 ? 1 : 0.5
    let wave = (sin(time * 6.0) + 1) / 2 // 0…1
    return 1 + 0.16 * falloff * CGFloat(wave)
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
