import SwiftUI

/// Branded loading moment — a breathing paw over a soft halo with calm,
/// honest copy. Includes a shimmer skeleton for structural preview.
struct PPPetAdViewerLoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var shimmerOffset: CGFloat = -0.5

    var body: some View {
        ZStack {
            // Background skeleton shapes
            skeletonBackground

            // Foreground branded content
            VStack(spacing: PPSpace.xl) {
                ZStack {
                    Circle()
                        .fill(Color.ppPrimary.opacity(0.10))
                        .frame(width: 100, height: 100)
                        .scaleEffect(isBreathing ? 1.06 : 0.94)

                    Circle()
                        .fill(PPGradient.hero)
                        .frame(width: 68, height: 68)
                        .shadow(
                            color: Color.ppPrimary.opacity(0.24),
                            radius: 20,
                            y: 10
                        )

                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 26, weight: .semibold))
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
            withAnimation(
                .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 1.5
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            PPPetAdLocalization.text("Loading", fallback: "Loading")
        )
    }

    /// Shimmer skeleton that previews the viewer layout structure.
    private var skeletonBackground: some View {
        VStack(spacing: PPSpace.base) {
            // Hero skeleton
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .fill(Color.ppForeground.opacity(0.30))
                .frame(height: 286)
                .overlay(shimmerOverlay)

            // Card skeletons
            VStack(spacing: PPSpace.sm) {
                skeletonBlock(height: 80, corner: PPCorner.card)
                skeletonBlock(height: 80, corner: PPCorner.card)
                skeletonBlock(height: 64, corner: PPCorner.card)
                skeletonBlock(height: 100, corner: PPCorner.card)
            }
            .padding(.horizontal, PPSpace.screenMargin)

            Spacer()
        }
        .opacity(0.60)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func skeletonBlock(height: CGFloat, corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.ppForeground.opacity(0.25))
            .frame(height: height)
            .overlay(shimmerOverlay)
    }

    /// Diagonal shimmer sweep.
    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.12),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .offset(x: geo.size.width * shimmerOffset)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        )
    }
}

private struct SkeletonBlock: View {
    let height: CGFloat
    let corner: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.ppForeground.opacity(0.25))
            .frame(height: height)
    }
}
