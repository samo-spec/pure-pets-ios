import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdTrustJourneyHero: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    @ObservedObject var interactionState: PPPetAdViewerInteractionState
    let height: CGFloat
    let scrollOffset: CGFloat
    let onOpen: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            PPPetAdHeroGallery(
                items: items,
                selection: $selection,
                interactionState: interactionState,
                onOpen: onOpen,
                bottomViewType: .thumbRails,
                showsTrustJourneyBottomFade: true
            )
            .frame(height: stretchedHeight)
            .scaleEffect(heroScale, anchor: .center)
            .offset(y: parallaxOffset)
        }
        .frame(height: height)
        .clipped()
        .background(Color.ppBackground)
        .accessibilityElement(children: .contain)
    }

    private var stretchedHeight: CGFloat {
        height + max(-scrollOffset, 0)
    }

    private var heroScale: CGFloat {
        guard !reduceMotion, scrollOffset < 0 else { return 1 }
        return 1 + min(abs(scrollOffset) / max(height, 1), 0.12)
    }

    private var parallaxOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        if scrollOffset < 0 {
            return scrollOffset * 0.50
        }
        return scrollOffset * 0.18
    }
}
