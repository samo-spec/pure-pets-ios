import SwiftUI

private struct PPPressFeedbackModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.985 : 1)
            .brightness(isPressed ? -0.015 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}

public extension View {
    func ppPressFeedback() -> some View {
        modifier(PPPressFeedbackModifier())
    }

    @ViewBuilder
    func ppKeyboardDismissBehavior() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
