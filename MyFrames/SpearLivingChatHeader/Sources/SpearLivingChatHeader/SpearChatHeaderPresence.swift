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

  @ScaledMetric(relativeTo: .body) private var scaledSize = 46
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let size = min(scaledSize, 54)

    ZStack(alignment: .bottomTrailing) {
      Circle()
        .strokeBorder(ringColor, lineWidth: 2)
        .frame(width: size + 5, height: size + 5)

      content
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
          Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
        }

      SpearPresenceBadge(
        presence: presence,
        callIsActive: call.isActive,
        animateOnline: motionMode == .onlinePresence && !reduceMotion
      )
    }
    .frame(width: size + 7, height: size + 7)
    .accessibilityHidden(true)
  }

  private var ringColor: Color {
    if trust.isRestricted { return .orange.opacity(0.65) }
    if trust.isVerified { return brandColor.opacity(0.68) }
    return Color.primary.opacity(0.14)
  }
}

@available(iOS 17.0, *)
internal struct SpearPresenceBadge: View {
  let presence: SpearPresence
  let callIsActive: Bool
  let animateOnline: Bool

  @ViewBuilder
  var body: some View {
    if callIsActive {
      Image(systemName: "waveform")
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 18, height: 18)
        .background(.green, in: Circle())
        .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
    } else {
      switch presence {
      case .online, .typing, .viewingOffer:
        SpearOnlineBadge(isAnimated: animateOnline)

      case .offline:
        Circle()
          .fill(.secondary)
          .frame(width: 12, height: 12)
          .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
      }
    }
  }
}

@available(iOS 17.0, *)
internal struct SpearOnlineBadge: View {
  let isAnimated: Bool

  var body: some View {
    ZStack {
      if isAnimated {
        Circle()
          .fill(.green.opacity(0.28))
          .phaseAnimator([false, true]) { circle, phase in
            circle
              .scaleEffect(phase ? 1.75 : 1)
              .opacity(phase ? 0 : 0.7)
          } animation: { _ in
            .easeOut(duration: 1.35)
          }
      }

      Circle().fill(.green)
    }
    .frame(width: 12, height: 12)
    .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
  }
}

@available(iOS 17.0, *)
internal struct SpearPresenceLine: View {
  let presence: SpearPresence
  let call: SpearCallControl
  let copy: SpearChatHeaderCopy
  let motionMode: SpearMotionMode

  var body: some View {
    HStack(spacing: 6) {
      Text(displayText)
        .font(.caption)
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
    .id(transitionIdentity)
    .transition(.opacity)
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
    if call.isActive { return .green }

    switch presence {
    case .online, .typing, .viewingOffer:
      return .green
    case .offline:
      return .secondary
    }
  }
}

@available(iOS 17.0, *)
internal struct SpearTypingDots: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if reduceMotion {
      dots(activeIndex: nil)
    } else {
      PhaseAnimator([0, 1, 2]) { activeIndex in
        dots(activeIndex: activeIndex)
      } animation: { _ in
        .easeInOut(duration: 0.28)
      }
    }
  }

  private func dots(activeIndex: Int?) -> some View {
    HStack(spacing: 2) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(.secondary)
          .frame(width: 4, height: 4)
          .offset(y: activeIndex == index ? -3 : 0)
          .opacity(activeIndex == nil || activeIndex == index ? 1 : 0.35)
      }
    }
    .frame(height: 8)
    .accessibilityHidden(true)
  }
}

@available(iOS 17.0, *)
internal struct SpearCallWaveform: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if reduceMotion {
      bars(phase: 0)
    } else {
      PhaseAnimator([0, 1, 2, 3]) { phase in
        bars(phase: phase)
      } animation: { _ in
        .easeInOut(duration: 0.24)
      }
    }
  }

  private func bars(phase: Int) -> some View {
    HStack(alignment: .center, spacing: 2) {
      ForEach(0..<4, id: \.self) { index in
        Capsule()
          .fill(.green)
          .frame(width: 2.5, height: height(for: index, phase: phase))
      }
    }
    .frame(height: 14)
    .accessibilityHidden(true)
  }

  private func height(for index: Int, phase: Int) -> CGFloat {
    let sequence: [[CGFloat]] = [
      [5, 11, 7, 13],
      [10, 6, 13, 8],
      [7, 13, 6, 11],
      [12, 8, 11, 5],
    ]
    return sequence[phase % sequence.count][index]
  }
}
