import SwiftUI

/// Brand action used by the unavailable-state recovery control. Keeping this
/// treatment separate prevents the shared control file becoming another
/// catch-all owner as the header grows.
internal struct SpearBrandButtonStyle: ButtonStyle {
  let color: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .frame(minHeight: 44)
      .background(
        color.opacity(configuration.isPressed ? 0.78 : 1),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .shadow(
        color: color.opacity(colorScheme == .dark ? 0.2 : 0.25),
        radius: configuration.isPressed ? 4 : 8,
        y: configuration.isPressed ? 2 : 4
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.17, extraBounce: 0.06), value: configuration.isPressed)
  }
}
