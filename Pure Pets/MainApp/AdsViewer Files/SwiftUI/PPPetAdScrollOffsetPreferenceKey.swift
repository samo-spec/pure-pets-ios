import SwiftUI

struct PPPetAdScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = nextValue()
    }
}

enum PPPetAdViewerCoordinateSpace {
    static let trustJourney = "PPPetAdViewer.TrustJourney"
}

extension PPPetAdViewerLayoutMetrics {
    static let trustJourneyHeroBottomGradientHeight: CGFloat = 190
    static let trustJourneyContentBlendHeight: CGFloat = 176
    static let trustJourneyContentBlendOverlap: CGFloat = 156
}
