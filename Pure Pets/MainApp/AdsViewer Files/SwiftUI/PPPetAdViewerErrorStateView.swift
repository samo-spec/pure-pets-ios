import SwiftUI

struct PPPetAdViewerErrorStateView: View {
    let isOffline: Bool
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        PPPetAdViewerStateScaffold(
            symbol: isOffline
                ? "wifi.slash"
                : "exclamationmark.arrow.triangle.2.circlepath",
            tint: isOffline ? .ppWarning : .ppError,
            title: isOffline
                ? PPPetAdLocalization.text(
                    "pet_ad_viewer_offline_title",
                    fallback: "You’re offline"
                )
                : PPPetAdLocalization.text(
                    "pet_ad_viewer_error_title",
                    fallback: "This page did not load"
                ),
            message: message,
            primaryTitle: PPPetAdLocalization.text(
                "Retry",
                fallback: "Retry"
            ),
            primarySymbol: "arrow.clockwise",
            primaryAction: onRetry,
            secondaryTitle: PPPetAdLocalization.text(
                "Close",
                fallback: "Close"
            ),
            secondaryAction: onClose
        )
    }
}
