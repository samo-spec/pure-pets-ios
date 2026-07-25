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
        VStack(alignment: .leading, spacing: PPPetAdViewerStyle.sectionSpacing) {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                if dynamicTypeSize >= .xxLarge {
                    skeletonLine(width: 220, height: 28)
                    skeletonLine(width: 88, height: 22)
                } else {
                    HStack(alignment: .center, spacing: PPSpace.base) {
                        skeletonFillLine(height: 28)
                        skeletonLine(width: 88, height: 22)
                    }
                }
                skeletonLine(width: 176, height: 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            factsSkeletonRail
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
        Group {
            if dynamicTypeSize >= .xxLarge {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        factSkeletonCell

                        if index < 2 {
                            Divider()
                                .padding(.horizontal, PPSpace.md)
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        factSkeletonCell

                        if index < 2 {
                            Divider()
                                .frame(height: 44)
                        }
                    }
                }
            }
        }
        .background(Color.ppCard, in: factsRailShape)
        .overlay {
            factsRailShape.stroke(
                Color(uiColor: .separator).opacity(
                    colorSchemeContrast == .increased ? 0.54 : 0.20
                ),
                lineWidth: colorSchemeContrast == .increased
                    ? 1.5
                    : PPPetAdViewerStyle.hairlineWidth
            )
        }
        .clipShape(factsRailShape)
    }

    private var factsRailShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.infoRadius,
            style: .continuous
        )
    }

    private var factSkeletonCell: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            skeletonLine(width: 40, height: 10)
            skeletonLine(width: 58, height: 16)
        }
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.base)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
    }
}
