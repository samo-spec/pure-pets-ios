import SwiftUI

struct VoiceMessageView: View {
  let messageID: MessageID
  let payload: VoicePayload
  @ObservedObject var audioCoordinator: ConversationAudioCoordinator

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  private let barHeight: CGFloat = 28
  private let maxBarHeight: CGFloat = 24

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
      width: dynamicTypeSize.isAccessibilitySize ? nil : 224,
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
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [PurePetsMessagingTheme.signal, PurePetsMessagingTheme.brandDeep],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        Circle()
          .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)

        if #available(iOS 17.0, *) {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 14.5, weight: .bold))
            .foregroundStyle(PurePetsMessagingTheme.signalForeground)
            .contentTransition(
              reduceMotion ? .identity : .symbolEffect(.replace.offUp)
            )
            .offset(x: isPlaying ? 0 : 0.75)
        } else {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 14.5, weight: .bold))
            .foregroundStyle(PurePetsMessagingTheme.signalForeground)
            .offset(x: isPlaying ? 0 : 0.75)
        }
      }
      .frame(width: 44, height: 44)
    }
    .buttonStyle(PurePetsMessagingPressButtonStyle())
    .accessibilityLabel(
      localized(
        isPlaying
          ? "chat_voice_pause_accessibility"
          : "chat_voice_play_accessibility"
      )
    )
  }

  private var waveform: some View {
    VStack(alignment: .leading, spacing: 4) {
      GeometryReader { proxy in
        waveformBars(width: proxy.size.width)
      }
      .frame(height: barHeight)

      HStack(spacing: 8) {
        Text(elapsedText)
          .foregroundStyle(isPlaying ? PurePetsMessagingTheme.signal : .secondary)
        Spacer(minLength: 8)
        Text(durationText)
      }
      .font(Font.ppBeirutiRegular(size: 11.5, relativeTo: .caption))
      .monospacedDigit()
      .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(
      PurePetsMessagingTheme.replySurface,
      in: RoundedRectangle(cornerRadius: 13, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .strokeBorder(PurePetsMessagingTheme.surfaceStroke, lineWidth: 0.65)
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

  private func waveformBars(width: CGFloat) -> some View {
    let samples = decimatedSamples(for: width)

    return ZStack(alignment: .leading) {
      barLayer(
        samples: samples,
        width: width,
        fill: AnyShapeStyle(PurePetsMessagingTheme.waveformTrack(colorScheme))
      )

      barLayer(
        samples: samples,
        width: width,
        fill: AnyShapeStyle(PurePetsMessagingTheme.waveformPlayedGradient)
      )
      .mask(alignment: .leading) {
        GeometryReader { proxy in
          Rectangle()
            .frame(width: proxy.size.width * min(max(progress, 0), 1))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func barLayer(
    samples: [Double],
    width: CGFloat,
    fill: AnyShapeStyle
  ) -> some View {
    let spacing: CGFloat = 2
    let count = max(samples.count, 1)
    let barWidth = max(2, (width - CGFloat(count - 1) * spacing) / CGFloat(count))

    return HStack(alignment: .center, spacing: spacing) {
      ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
        Capsule(style: .continuous)
          .fill(fill)
          .frame(
            width: barWidth,
            height: max(4, maxBarHeight * CGFloat(sample))
          )
      }
    }
  }

  private func decimatedSamples(for width: CGFloat) -> [Double] {
    let source = payload.waveform.isEmpty
      ? [0.32, 0.56, 0.42, 0.75, 0.48, 0.64, 0.36, 0.58]
      : payload.waveform
    let maximumCount = max(Int(width / 4), 8)
    guard source.count > maximumCount else { return source }

    let step = Double(source.count) / Double(maximumCount)
    return (0..<maximumCount).map { index in
      let sourceIndex = min(Int((Double(index) * step).rounded(.down)), source.count - 1)
      return source[sourceIndex]
    }
  }

  private var progress: Double {
    audioCoordinator.progress(for: messageID)
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
