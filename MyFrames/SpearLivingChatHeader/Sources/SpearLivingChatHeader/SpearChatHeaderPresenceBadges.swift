import SwiftUI
import UIKit

// MARK: - Presence Badge

@available(iOS 15.0, *)
internal struct SpearPresenceBadge: View {
  let presence: SpearPresence
  let callIsActive: Bool
  let animateOnline: Bool

  @ViewBuilder
  var body: some View {
    if callIsActive {
      Image(systemName: "waveform")
        .font(.system(size: 7, weight: .bold))
        .foregroundStyle(SpearHeaderSemanticColor.liveForeground)
        .frame(width: 16, height: 16)
        .background(SpearHeaderSemanticColor.live, in: Circle())
        .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
    } else {
      switch presence {
      case .online, .typing, .viewingOffer:
        SpearOnlineBadge(isAnimated: animateOnline)

      case .offline:
        EmptyView()
      }
    }
  }
}

// MARK: - Online Badge

@available(iOS 15.0, *)
internal struct SpearOnlineBadge: View {
  let isAnimated: Bool
  @State private var pulseExpanded = false
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      if shouldAnimate {
        Circle()
          .fill(SpearHeaderSemanticColor.live.opacity(0.3))
          .scaleEffect(pulseExpanded ? 1.7 : 1)
          .opacity(pulseExpanded ? 0 : 0.7)
      }

      Circle().fill(SpearHeaderSemanticColor.live)
    }
    .frame(width: 10, height: 10)
    .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
    .onAppear {
      startPulseIfNeeded()
    }
    .onChange(of: isAnimated) { enabled in
      pulseExpanded = false
      if enabled {
        startPulseIfNeeded()
      }
    }
    .onChange(of: scenePhase) { phase in
      // Returning from the background renders current truth without replaying
      // the online-entry acknowledgement.
      pulseExpanded = phase == .active
    }
  }

  private var shouldAnimate: Bool {
    isAnimated && scenePhase == .active
  }

  private func startPulseIfNeeded() {
    guard shouldAnimate, !pulseExpanded else { return }
    withAnimation(SpearHeaderMotion.standard) {
      pulseExpanded = true
    }
  }
}
