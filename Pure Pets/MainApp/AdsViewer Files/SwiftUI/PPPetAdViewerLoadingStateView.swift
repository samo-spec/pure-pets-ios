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
        VStack(alignment: .leading, spacing: 0) {
            headerSkeleton
            factsSkeletonRail
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, PPPetAdViewerStyle.contentTopPadding)
        .opacity(isPulsing ? 0.84 : 1)
    }

    private var headerSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dynamicTypeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    identitySkeleton
                    priceSkeleton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .top, spacing: PPSpace.lg) {
                    identitySkeleton
                        .frame(maxWidth: .infinity, alignment: .leading)
                    priceSkeleton
                }
            }

            locationBridgeSkeleton
                .padding(.vertical, PPSpace.lg)
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
        VStack(alignment: .trailing, spacing: PPSpace.xs) {
            Capsule(style: .continuous)
                .fill(Color.ppPrimary.opacity(0.34))
                .frame(width: 44, height: PPSpace.xs)

            HStack(alignment: .bottom, spacing: PPSpace.xs) {
                skeletonLine(width: 96, height: 34)
                skeletonLine(width: 24, height: 10)
            }
        }
    }

    private var locationBridgeSkeleton: some View {
        HStack(spacing: PPSpace.sm) {
            bridgeSeparatorSkeleton

            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .fill(Color.ppPrimary.opacity(0.13))
                .frame(width: PPSpace.xxxl, height: PPSpace.xxxl)

            skeletonLine(width: 144, height: 16)

            bridgeSeparatorSkeleton
        }
    }

    private var bridgeSeparatorSkeleton: some View {
        Capsule(style: .continuous)
            .fill(Color.ppPrimary.opacity(0.22))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
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
        Group {
            if dynamicTypeSize >= .xxLarge {
                VStack(spacing: PPSpace.md) {
                    ForEach(PPPetAdInfoSignature.allCases, id: \.self) { signature in
                        factSkeletonCell(
                            signature: signature,
                            usesCompactColumn: false
                        )
                        .frame(maxWidth: .infinity)
                        .ppPetAdInfoSurface(
                            accentColor: signature.accentColor
                        )
                    }
                }
            } else {
                HStack(alignment: .top, spacing: PPSpace.md) {
                    ForEach(PPPetAdInfoSignature.allCases, id: \.self) { signature in
                        factSkeletonCell(
                            signature: signature,
                            usesCompactColumn: true
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ppPetAdInfoSurface(
                            accentColor: signature.accentColor
                        )
                    }
                }
            }
        }
    }

    private func factSkeletonCell(
        signature: PPPetAdInfoSignature,
        usesCompactColumn: Bool
    ) -> some View {
        Group {
            if usesCompactColumn {
                VStack(alignment: .center, spacing: PPSpace.sm) {
                    factSkeletonIcon(signature: signature)

                    VStack(alignment: .center, spacing: PPSpace.xxs) {
                        skeletonLine(width: 54, height: 17)
                        skeletonLine(width: 38, height: 10)
                    }
                }
            } else {
                HStack(spacing: PPSpace.md) {
                    factSkeletonIcon(signature: signature)

                    VStack(alignment: .leading, spacing: PPSpace.xxs) {
                        skeletonLine(width: 72, height: 17)
                        skeletonLine(width: 44, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal, usesCompactColumn ? PPSpace.sm : PPSpace.base)
        .padding(.vertical, PPSpace.base)
        .frame(
            maxWidth: .infinity,
            alignment: usesCompactColumn ? .center : .leading
        )
        .overlay(alignment: .bottom) {
            skeletonBottomAccent(signature: signature)
        }
    }

    private func factSkeletonIcon(
        signature: PPPetAdInfoSignature
    ) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(signature.accentColor.opacity(0.10))
            .frame(width: 42, height: 42)
    }

    private func skeletonBottomAccent(
        signature: PPPetAdInfoSignature
    ) -> some View {
        Capsule(style: .continuous)
            .fill(signature.accentColor.opacity(0.34))
            .frame(width: 44, height: PPSpace.xs)
    }
}
