import SwiftUI

extension View {
  @ViewBuilder
  func ppPromoGlassCapsule(
    tint: Color? = nil,
    interactive: Bool = false
  ) -> some View {
    #if swift(>=6.2)
      if #available(iOS 26.0, *) {
        let configuredGlass = Glass.regular
          .tint(tint)
          .interactive(interactive)

        self.glassEffect(configuredGlass, in: Capsule())
      } else {
        fallbackPromoGlass(tint: tint)
      }
    #else
      fallbackPromoGlass(tint: tint)
    #endif
  }

  @ViewBuilder
  private func fallbackPromoGlass(tint: Color?) -> some View {
    self
      .background(.ultraThinMaterial, in: Capsule())
      .background((tint ?? .clear).opacity(0.12), in: Capsule())
      .overlay {
        Capsule()
          .stroke(Color.white.opacity(0.56), lineWidth: 0.8)
      }
  }
}
