import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdViewerLoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
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
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                skeletonLine(width: 58, height: 10)

                if dynamicTypeSize >= .xxLarge {
                    skeletonLine(width: 220, height: 32)
                    skeletonLine(width: 104, height: 20)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: PPSpace.lg) {
                        skeletonFillLine(height: 32)
                        skeletonLine(width: 104, height: 20)
                    }
                }
                skeletonLine(width: 168, height: 14)
            }
            .padding(.leading, PPSpace.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.ppPrimary.opacity(0.34))
                    .frame(width: PPSpace.xs)
                    .padding(.vertical, PPSpace.xs)
            }

            factsSkeletonRail
                .padding(.leading, PPSpace.base)
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, PPPetAdViewerStyle.contentTopPadding)
        .opacity(isPulsing ? 0.84 : 1)
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
            skeletonDivider

            if dynamicTypeSize >= .xxLarge {
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { index in
                        factSkeletonCell

                        if index < 1 {
                            skeletonDivider
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { index in
                        factSkeletonCell

                        if index < 1 {
                            verticalSkeletonDivider
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            skeletonDivider
        }
        .overlay(alignment: .bottom) {
            skeletonDivider
        }
    }

    private var featuredFactSkeleton: some View {
        HStack(spacing: PPSpace.md) {
            Capsule(style: .continuous)
                .fill(Color.ppPrimary.opacity(0.10))
                .frame(width: 52, height: 42)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                skeletonLine(width: 44, height: 10)
                skeletonLine(width: 112, height: 18)
            }
        }
        .padding(.vertical, PPSpace.base)
    }

    private var factSkeletonCell: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            skeletonLine(width: 40, height: 10)
            skeletonLine(width: 58, height: 16)
        }
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var skeletonDivider: some View {
        Rectangle()
            .fill(skeletonDividerColor)
            .frame(height: skeletonDividerThickness)
    }

    private var verticalSkeletonDivider: some View {
        Rectangle()
            .fill(skeletonDividerColor)
            .frame(width: skeletonDividerThickness)
            .padding(.vertical, PPSpace.md)
    }

    private var skeletonDividerColor: Color {
        Color(uiColor: .separator).opacity(
            colorSchemeContrast == .increased ? 0.64 : 0.24
        )
    }

    private var skeletonDividerThickness: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 1
    }
}
