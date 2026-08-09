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
        color,
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.black.opacity(0.12))
          .opacity(configuration.isPressed ? 1 : 0)
      }
      .shadow(
        color: color.opacity(colorScheme == .dark ? 0.16 : 0.18),
        radius: 5,
        y: 2
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.86 : 1)
      .animation(reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed), value: configuration.isPressed)
  }
}
