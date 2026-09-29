#if canImport(UIKit)
import SwiftUI

/// A placement-agnostic entry point for Pure Pets Eyes.
///
/// The host owns the label and styling, so this button can live in a home card,
/// toolbar, Pet Profile, marketplace surface, tab, or any future feature area.
/// Entry placement never changes the profile-independent scanner eligibility.
public struct PureLensFeatureButton<Label: View>: View {
    private let module: PureLensModule
    private let label: () -> Label

    @State private var isPresentingPureLens = false

    @MainActor
    public init(
        module: PureLensModule,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.module = module
        self.label = label
    }

    public var body: some View {
        Button {
            isPresentingPureLens = true
        } label: {
            label()
        }
        .fullScreenCover(isPresented: $isPresentingPureLens) {
            PureLensView(module: module)
        }
    }
}

#if DEBUG
#Preview("Pure Pets Eyes feature button") {
    PureLensFeatureButton(module: .demo(localeIdentifier: "en")) {
        Label("Pure Pets Eyes", systemImage: "camera.viewfinder")
    }
    .buttonStyle(.borderedProminent)
}
#endif


#endif
