import SwiftUI

struct PPPetAdViewerEmptyStateView: View {
    let onClose: () -> Void

    var body: some View {
        PPPetAdViewerStateScaffold(
            symbol: "pawprint.fill",
            tint: .ppPrimary,
            title: PPPetAdLocalization.text(
                "pet_ad_viewer_empty_title",
                fallback: "This advertisement is unavailable"
            ),
            message: PPPetAdLocalization.text(
                "pet_ad_viewer_empty_detail",
                fallback:
                    "It may have been removed, completed, or no longer contains displayable details."
            ),
            primaryTitle: PPPetAdLocalization.text(
                "Close",
                fallback: "Close"
            ),
            primarySymbol: "xmark",
            primaryAction: onClose,
            secondaryTitle: nil,
            secondaryAction: nil
        )
    }
}
