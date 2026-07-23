import SwiftUI

/// Branded loading moment — a breathing paw over a soft halo with calm,
/// honest copy. Shown only while the snapshot has no renderable content.
struct PPPetAdViewerLoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: PPSpace.xl) {
            ZStack {
                Circle()
                    .fill(Color.ppPrimary.opacity(0.10))
                    .frame(width: 112, height: 112)
                    .scaleEffect(isBreathing ? 1.06 : 0.94)

                Circle()
                    .fill(PPGradient.hero)
                    .frame(width: 76, height: 76)
                    .shadow(
                        color: Color.ppPrimary.opacity(0.24),
                        radius: 20,
                        y: 10
                    )

                Image(systemName: "pawprint.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.white)
            }

            VStack(spacing: PPSpace.sm) {
                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_loading_title",
                        fallback: "Preparing this pet’s story"
                    )
                )
                .font(PPPetAdTypography.title2)
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)

                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_loading_detail",
                        fallback:
                            "Loading photos, details, and contact options."
                    )
                )
                .font(PPPetAdTypography.subheadline)
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
            }

            ProgressView()
                .tint(Color.ppPrimary)
        }
        .padding(PPSpace.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            PPPetAdLocalization.text("Loading", fallback: "Loading")
        )
    }
}
