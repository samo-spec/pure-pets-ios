import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdViewerLoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
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
            headerSkeleton
            factsSkeletonRail
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, PPPetAdViewerStyle.contentTopPadding)
        .opacity(isPulsing ? 0.84 : 1)
    }

    private var headerSkeleton: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.sm) {
                skeletonLine(width: 58, height: 10)
                Capsule(style: .continuous)
                    .fill(Color.ppPrimary.opacity(0.24))
                    .frame(width: 34, height: 3)
            }

            if dynamicTypeSize >= .xxLarge {
                skeletonLine(width: 220, height: 32)
                skeletonPriceTicket
            } else {
                HStack(alignment: .top, spacing: PPSpace.lg) {
                    skeletonFillLine(height: 34)
                    skeletonPriceTicket
                }
            }

            HStack(spacing: PPSpace.sm) {
                RoundedRectangle(cornerRadius: PPSpace.sm, style: .continuous)
                    .fill(Color.ppTextTertiary.opacity(0.10))
                    .frame(width: 24, height: 24)

                skeletonLine(width: 168, height: 14)
            }
        }
        .padding(.leading, PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.ppPrimary.opacity(0.34))
                .frame(width: colorSchemeContrast == .increased ? 5 : 4)
                .padding(.vertical, PPSpace.xs)
        }
    }

    private var skeletonPriceTicket: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            skeletonLine(width: 42, height: 10)
            skeletonLine(width: 92, height: 24)
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .background(
            Color.ppPrimary.opacity(
                colorSchemeContrast == .increased ? 0.14 : 0.08
            ),
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
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
        .background(
            Color.ppForeground.opacity(
                colorScheme == .dark ? 0.34 : 0.58
            ),
            in: RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
            .strokeBorder(
                Color.ppSeparator.opacity(
                    colorSchemeContrast == .increased ? 1 : 0.52
                ),
                lineWidth: skeletonDividerThickness
            )
        }
    }

    private var featuredFactSkeleton: some View {
        HStack(spacing: PPSpace.md) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.ppPrimary.opacity(0.10))
                .frame(width: 44, height: 44)

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
