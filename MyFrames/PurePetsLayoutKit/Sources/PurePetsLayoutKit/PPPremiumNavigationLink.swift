import SwiftUI

/// Keeps navigation native while adding consistent card press feedback and accessibility semantics.
public struct PPPremiumNavigationLink<Label: View, Destination: View>: View {
    private let destination: Destination
    private let label: Label

    public init(
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.destination = destination()
        self.label = label()
    }

    public var body: some View {
        NavigationLink(destination: destination) {
            label
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ppPressFeedback()
    }
}
