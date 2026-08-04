import SwiftUI

struct PPHomePromoCarouselView: View {
  @ObservedObject var store: PPHomePromoCarouselStore
  let onAction: (PPPromoAction) -> Void

  @State private var selection = 0

  var body: some View {
    ZStack {
      PPPeekCarousel(
        cards: store.cards,
        isActive: store.isVisible,
        onAction: onAction,
        selection: $selection
      )
      .opacity(store.cards.isEmpty ? 0 : 1)
      .allowsHitTesting(!store.cards.isEmpty)

      stateOverlay
        .opacity(store.cards.isEmpty ? 1 : 0)
        .allowsHitTesting(store.cards.isEmpty)
    }
    .frame(maxWidth: .infinity)
    .background(Color.clear)
    .onChange(of: store.cards.map(\.id)) { _ in
      selection = min(selection, max(store.cards.count - 1, 0))
    }
  }

  @ViewBuilder
  private var stateOverlay: some View {
    switch store.phase {
    case .idle, .loading:
      PPPromoLoadingView()
    case .failed:
      PPPromoUnavailableView(action: store.reload)
    case .empty:
      Color.clear.frame(height: 1)
    case .content:
      Color.clear.frame(height: 1)
    }
  }
}

private struct PPPromoLoadingView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pulse = false

  var body: some View {
    RoundedRectangle(cornerRadius: PPPromoTheme.cardCornerRadius, style: .continuous)
      .fill(PPPromoTheme.warmPorcelain)
      .overlay {
        HStack(spacing: 18) {
          VStack(alignment: .leading, spacing: 12) {
            Capsule().frame(width: 84, height: 13)
            Capsule().frame(width: 130, height: 24)
            Capsule().frame(width: 108, height: 15)
            Capsule().frame(width: 122, height: 46)
          }

          Spacer()

          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .frame(width: 130, height: 170)
        }
        .foregroundStyle(Color.secondary.opacity(0.13))
        .padding(24)
      }
      .opacity(pulse || reduceMotion ? 1 : 0.72)
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.95).repeatForever(autoreverses: true),
        value: pulse
      )
      .onAppear { pulse = true }
      .padding(.horizontal, 34)
      .frame(minHeight: 250)
      .accessibilityLabel(NSLocalizedString("pp_promo_loading", comment: "Carousel loading state"))
  }
}

private struct PPPromoUnavailableView: View {
  let action: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "wifi.exclamationmark")
        .font(.system(size: 28, weight: .medium))
        .foregroundStyle(PPPromoTheme.brandPrimary)

      Text(NSLocalizedString("pp_promo_unavailable", comment: "Carousel unavailable state"))
        .font(PPPromoTheme.subtitleFont)
        .multilineTextAlignment(.center)

      Button(NSLocalizedString("pp_promo_retry", comment: "Retry carousel loading"), action: action)
        .font(PPPromoTheme.buttonFont)
        .frame(minWidth: 108, minHeight: 44)
        .ppPromoGlassCapsule(tint: PPPromoTheme.brandPrimary, interactive: true)
        .buttonStyle(.plain)
    }
    .padding(20)
    .frame(maxWidth: .infinity, minHeight: 250)
  }
}
