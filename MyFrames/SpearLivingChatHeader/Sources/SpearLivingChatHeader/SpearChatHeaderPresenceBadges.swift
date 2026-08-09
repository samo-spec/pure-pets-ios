import SwiftUI
import UIKit

// MARK: - Presence Badge

@available(iOS 17.0, *)
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

@available(iOS 17.0, *)
internal struct SpearOnlineBadge: View {
  let isAnimated: Bool
  @State private var pulseExpanded = false

  var body: some View {
    ZStack {
      if isAnimated {
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
    .onChange(of: isAnimated) { _, enabled in
      pulseExpanded = false
      if enabled {
        startPulseIfNeeded()
      }
    }
  }

  private func startPulseIfNeeded() {
    guard isAnimated, !pulseExpanded else { return }
    withAnimation(SpearHeaderMotion.standard) {
      pulseExpanded = true
    }
  }
}
