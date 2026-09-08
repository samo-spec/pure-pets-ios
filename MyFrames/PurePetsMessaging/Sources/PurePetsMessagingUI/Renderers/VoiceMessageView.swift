import SwiftUI
import UIKit

struct VoiceMessageView: View {
  let messageID: MessageID
  let payload: VoicePayload
  @ObservedObject var audioCoordinator: ConversationAudioCoordinator

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @State private var isDraggingSeek = false
  @State private var dragProgress: Double = 0

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
      width: dynamicTypeSize.isAccessibilitySize ? nil : 246,
      alignment: .leading
    )
    .onDisappear {
      audioCoordinator.stop(messageID: messageID)
    }
  }

  private var isPlaying: Bool {
    audioCoordinator.isPlaying(messageID)
  }

  private var isActive: Bool {
    audioCoordinator.activeMessageID == messageID
  }

  private var playButton: some View {
    Button {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
          .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)

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
        let width = proxy.size.width
        waveformBars(width: width)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                isDraggingSeek = true
                let normalized = min(max(value.location.x / width, 0), 1)
                dragProgress = normalized
                audioCoordinator.seek(to: normalized, messageID: messageID)
              }
              .onEnded { _ in
                isDraggingSeek = false
                UISelectionFeedbackGenerator().selectionChanged()
              }
          )
      }
      .frame(height: barHeight)

      HStack(spacing: 6) {
        Text(elapsedText)
          .foregroundStyle(isPlaying ? PurePetsMessagingTheme.signal : .secondary)

        Spacer(minLength: 4)

        if isActive || isPlaying {
          speedButton
        }

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
      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
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

  private var speedButton: some View {
    Button {
      UISelectionFeedbackGenerator().selectionChanged()
      withAnimation(PurePetsMessagingMotion.quick) {
        audioCoordinator.cyclePlaybackRate()
      }
    } label: {
      Text(speedText)
        .font(Font.ppBeirutiBold(size: 10.5, relativeTo: .caption2))
        .foregroundStyle(PurePetsMessagingTheme.signal)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(PurePetsMessagingTheme.brandSoft, in: Capsule())
    }
    .buttonStyle(PurePetsMessagingPressButtonStyle())
  }

  private var speedText: String {
    let rate = audioCoordinator.playbackRate
    if rate == 1.5 { return "1.5×" }
    if rate == 2.0 { return "2×" }
    return "1×"
  }

  private func waveformBars(width: CGFloat) -> some View {
    let samples = decimatedSamples(for: width)
    let currentProgress = effectiveProgress

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
            .frame(width: proxy.size.width * min(max(currentProgress, 0), 1))
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

  private var effectiveProgress: Double {
    isDraggingSeek ? dragProgress : progress
  }

  private var progress: Double {
    audioCoordinator.progress(for: messageID)
  }

  private var elapsedText: String {
    durationString(payload.duration * effectiveProgress)
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
