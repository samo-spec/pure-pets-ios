import SwiftUI

struct PPPetAdPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed
                    ? 1
                    : pressedScale
            )
            .opacity(configuration.isPressed ? 0.80 : 1)
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.press,
                value: configuration.isPressed
            )
    }
}
