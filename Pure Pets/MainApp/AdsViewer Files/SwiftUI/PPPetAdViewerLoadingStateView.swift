import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdViewerLoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isPulsing = false

    var body: some View {
        GeometryReader { proxy in
            let metrics = PPPetAdViewerLayoutMetrics(
                containerSize: proxy.size,
                safeAreaTop: proxy.safeAreaInsets.top
            )

            VStack(spacing: 0) {
                heroSkeleton
                    .frame(height: metrics.expandedHeroHeight)

                detailsSkeleton
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .top
                    )
                    .background(
                        PPPetAdViewerStyle.sheetBackground,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius:
                                PPPetAdViewerStyle.sheetRadius,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius:
                                PPPetAdViewerStyle.sheetRadius,
                            style: .continuous
                        )
                    )
                    .offset(y: -PPPetAdViewerStyle.sheetOverlap)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 1.05)
                    .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPPetAdLocalization.text("Loading", fallback: "Loading")
        )
    }

    private var heroSkeleton: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PPPetAdViewerStyle.heroPeachTop,
                    PPPetAdViewerStyle.heroPeachBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "pawprint.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary.opacity(0.20))
        }
        .opacity(isPulsing ? 0.84 : 1)
    }

    private var detailsSkeleton: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxxl) {
            passportSkeleton
            storySkeleton
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, PPSpace.xl)
        .opacity(isPulsing ? 0.84 : 1)
    }

    private var passportSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSkeleton

            PPPetAdFadingDivider(axis: .horizontal)
                .frame(height: PPPetAdViewerStyle.hairlineWidth)
                .padding(.top, PPSpace.lg)

            factsSkeletonRail
                .padding(.top, PPSpace.xs)
        }
        .padding(PPSpace.base)
        .background(
            Color.ppCard,
            in: RoundedRectangle(
                cornerRadius: PPPetAdViewerStyle.surfaceRadius + 4,
                style: .continuous
            )
        )
        .overlay(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(Color.ppPrimary.opacity(0.28))
                .frame(width: 58, height: 4)
                .padding(.leading, PPSpace.base)
                .padding(.top, PPSpace.sm)
                .accessibilityHidden(true)
        }
    }

    private var headerSkeleton: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            identitySkeleton
            priceSkeleton
                .frame(maxWidth: .infinity, alignment: .leading)

            locationBridgeSkeleton
                .padding(.top, PPSpace.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identitySkeleton: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            skeletonLine(width: 58, height: 10)
            skeletonFillLine(height: 28)
        }
    }

    private var priceSkeleton: some View {
        HStack(alignment: .bottom, spacing: PPSpace.xs) {
            skeletonLine(width: 112, height: 28)
            skeletonLine(width: 24, height: 10)
        }
    }

    private var locationBridgeSkeleton: some View {
        HStack(spacing: PPSpace.sm) {
            RoundedRectangle(cornerRadius: PPSpace.xs, style: .continuous)
                .fill(Color.ppPrimary.opacity(0.13))
                .frame(width: 18, height: 18)

            skeletonLine(width: 144, height: 16)

            Circle()
                .fill(Color.ppSeparator)
                .frame(width: PPSpace.xs, height: PPSpace.xs)

            skeletonLine(width: 54, height: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func skeletonLine(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.ppTextTertiary.opacity(0.13))
            .frame(width: width, height: height)
    }

    private func skeletonFillLine(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.ppTextTertiary.opacity(0.13))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private var factsSkeletonRail: some View {
        VStack(spacing: 0) {
            featuredFactSkeleton
                .padding(.vertical, PPSpace.sm)

            PPPetAdFadingDivider(axis: .horizontal)
                .frame(height: PPPetAdViewerStyle.hairlineWidth)

            if dynamicTypeSize >= .xxLarge {
                VStack(spacing: 0) {
                    supportingFactSkeleton(signature: .age)
                    PPPetAdFadingDivider(axis: .horizontal)
                        .frame(height: PPPetAdViewerStyle.hairlineWidth)
                    supportingFactSkeleton(signature: .gender)
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    supportingFactSkeleton(signature: .age)
                        .frame(maxWidth: .infinity)

                    PPPetAdFadingDivider(axis: .vertical)
                        .frame(width: PPPetAdViewerStyle.hairlineWidth)
                        .padding(.vertical, PPSpace.md)

                    supportingFactSkeleton(signature: .gender)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(PPSpace.sm)
        .background(
            Color.ppForeground.opacity(0.70),
            in: RoundedRectangle(
                cornerRadius: PPPetAdViewerStyle.infoRadius,
                style: .continuous
            )
        )
    }

    private var featuredFactSkeleton: some View {
        HStack(spacing: PPSpace.md) {
            factSkeletonIcon(signature: .breed, size: 42)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                skeletonLine(width: 44, height: 10)
                skeletonLine(width: 132, height: 17)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supportingFactSkeleton(
        signature: PPPetAdInfoSignature
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            factSkeletonIcon(signature: signature, size: 30)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                skeletonLine(width: 38, height: 9)
                skeletonLine(width: 64, height: 15)
            }
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func factSkeletonIcon(
        signature: PPPetAdInfoSignature,
        size: CGFloat
    ) -> some View {
        Circle()
            .fill(signature.accentColor.opacity(0.10))
            .frame(width: size, height: size)
    }

    private var storySkeleton: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            HStack(spacing: PPSpace.md) {
                Circle()
                    .fill(Color.ppPrimary.opacity(0.10))
                    .frame(width: 34, height: 34)
                skeletonLine(width: 142, height: 20)
            }

            HStack(alignment: .top, spacing: PPSpace.md) {
                Capsule(style: .continuous)
                    .fill(Color.ppPrimary.opacity(0.34))
                    .frame(width: 3, height: 58)

                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    skeletonFillLine(height: 12)
                    skeletonFillLine(height: 12)
                    skeletonLine(width: 172, height: 12)
                }
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppCard,
            in: RoundedRectangle(
                cornerRadius: PPPetAdViewerStyle.descriptionRadius,
                style: .continuous
            )
        )
    }
}
