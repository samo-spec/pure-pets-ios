import SwiftUI
import UIKit

// MARK: - Avatar and Presence

@available(iOS 17.0, *)
internal struct SpearAvatarFrame<Content: View>: View {
  let trust: SpearTrustState
  let presence: SpearPresence
  let call: SpearCallControl
  let motionMode: SpearMotionMode
  let brandColor: Color
  let content: Content

  @ScaledMetric(relativeTo: .body) private var scaledSize = 44
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let size = min(scaledSize, SpearHeaderLayout.avatarMaximumSize)

    ZStack(alignment: .bottomTrailing) {
      content
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
          Circle()
            .strokeBorder(ringStrokeColor, lineWidth: 1.5)
        }

      SpearPresenceBadge(
        presence: presence,
        callIsActive: call.isActive,
        animateOnline: motionMode == .onlinePresence && !reduceMotion
      )
    }
    .frame(width: size, height: size)
    .animation(
      reduceMotion ? nil : SpearHeaderMotion.liveIndicator, value: presence.transitionIdentity
    )
    .animation(reduceMotion ? nil : SpearHeaderMotion.liveIndicator, value: motionMode)
    .accessibilityHidden(true)
  }

  private var ringStrokeColor: Color {
    if trust.isRestricted { return SpearHeaderSemanticColor.warning.opacity(0.7) }
    if trust.isVerified { return brandColor.opacity(0.6) }
    return Color.primary.opacity(0.1)
  }
}

// MARK: - Presence Line (atmospheric text color)

@available(iOS 17.0, *)
internal struct SpearPresenceLine: View {
  let presence: SpearPresence
  let call: SpearCallControl
  let copy: SpearChatHeaderCopy
  let motionMode: SpearMotionMode
  let brandColor: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      if case .offline = presence,
        !call.isActive,
        scenePhase == .active
      {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
          lineContent
        }
      } else {
        lineContent
      }
    }
  }

  private var lineContent: some View {
    HStack(spacing: 5) {
      Text(displayText)
        .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
        .foregroundStyle(semanticColor)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .contentTransition(.interpolate)

      if motionMode == .typing {
        SpearTypingDots()
      } else if motionMode == .activeCall {
        SpearCallWaveform()
      }
    }
    .frame(minHeight: 18, alignment: .leading)
    .id(transitionIdentity)
    .transition(
      reduceMotion
        ? .opacity
        : .opacity.combined(with: .offset(y: -2))
    )
    .animation(reduceMotion ? nil : SpearHeaderMotion.liveIndicator, value: transitionIdentity)
  }

  private var displayText: String {
    if let elapsedSeconds = call.elapsedSeconds {
      return copy.callText(elapsedSeconds: elapsedSeconds)
    }
    return copy.presenceText(for: presence)
  }

  private var transitionIdentity: String {
    call.isActive ? call.transitionIdentity : presence.transitionIdentity
  }

  private var semanticColor: Color {
    if call.isActive { return SpearHeaderSemanticColor.live }

    switch presence {
    case .online:
      return SpearHeaderSemanticColor.live
    case .typing:
      return brandColor
    case .viewingOffer:
      return brandColor
    case .offline:
      return .secondary
    }
  }
}

// MARK: - Typing Dots

@available(iOS 17.0, *)
internal struct SpearTypingDots: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    if reduceMotion || scenePhase != .active {
      dots(activeIndex: nil)
    } else {
      PhaseAnimator([0, 1, 2]) { activeIndex in
        dots(activeIndex: activeIndex)
      } animation: { _ in
        SpearHeaderMotion.liveIndicator
      }
    }
  }

  private func dots(activeIndex: Int?) -> some View {
    HStack(spacing: 2.5) {
      ForEach([0, 1, 2], id: \.self) { index in
        Circle()
          .fill(.secondary)
          .frame(width: 4, height: 4)
          .offset(y: activeIndex == index ? -3 : 0)
          .opacity(activeIndex == nil || activeIndex == index ? 1 : 0.3)
      }
    }
    .frame(height: 8)
    .accessibilityHidden(true)
  }
}

// MARK: - Call Waveform

@available(iOS 17.0, *)
internal struct SpearCallWaveform: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    if reduceMotion || scenePhase != .active {
      bars(phase: 0)
    } else {
      PhaseAnimator([0, 1, 2, 3]) { phase in
        bars(phase: phase)
      } animation: { _ in
        SpearHeaderMotion.liveIndicator
      }
    }
  }

  private func bars(phase: Int) -> some View {
    HStack(alignment: .center, spacing: 2) {
      ForEach([0, 1, 2, 3], id: \.self) { index in
        Capsule()
          .fill(SpearHeaderSemanticColor.live)
          .frame(width: 2.5, height: 13)
          .scaleEffect(
            x: 1,
            y: scale(for: index, phase: phase),
            anchor: .center
          )
      }
    }
    .frame(height: 14)
    .accessibilityHidden(true)
  }

  private func scale(for index: Int, phase: Int) -> CGFloat {
    let sequence: [[CGFloat]] = [
      [5, 11, 7, 13],
      [10, 6, 13, 8],
      [7, 13, 6, 11],
      [12, 8, 11, 5],
    ]
    return sequence[phase % sequence.count][index] / 13
  }
}
