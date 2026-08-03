import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdViewerLoadingStateView: View {
    var body: some View {
        GeometryReader { proxy in
            let heroHeight = min(
                min(max(proxy.size.height * 0.62, 500), 640),
                proxy.size.height
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    heroPlaceholder
                        .frame(height: heroHeight)

                    VStack(spacing: 0) {
                        PPPetAdHeroContentBlend()

                        contentPlaceholder
                            .padding(.horizontal, PPSpace.screenMargin)
                            .padding(.bottom, 150)
                            .background(Color.ppBackground)
                    }
                    .padding(
                        .top,
                        -PPPetAdViewerLayoutMetrics
                            .trustJourneyContentBlendOverlap
                    )
                }
            }
            .scrollDisabled(true)
        }
        .background(Color.ppBackground)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_loading_detail",
                fallback:
                    "Loading photos, details, and contact options."
            )
        )
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.ppSecondarySurface,
                    Color.ppSoftRose.opacity(0.64),
                    Color.ppBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ProgressView()
                .controlSize(.large)
                .tint(Color.ppPrimary)
        }
    }

    private var contentPlaceholder: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                skeletonLine(width: 260, height: 34)
                skeletonLine(width: 150, height: 28)
                skeletonLine(width: 210, height: 18)
            }

            HStack(spacing: PPSpace.base) {
                ForEach(Self.factPlaceholders) { _ in
                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        skeletonLine(width: 72, height: 16)
                        skeletonLine(width: 48, height: 11)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Rectangle()
                .fill(Color.ppSeparator)
                .frame(height: 1)

            ForEach(Self.timelinePlaceholders) { placeholder in
                HStack(alignment: .top, spacing: PPSpace.md) {
                    Circle()
                        .fill(Color.ppSoftRose)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        skeletonLine(
                            width: placeholder.titleWidth,
                            height: 20
                        )
                        skeletonLine(width: 250, height: 14)
                        skeletonLine(width: 205, height: 14)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, alignment: .leading)
        .redacted(reason: .placeholder)
    }

    private func skeletonLine(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        RoundedRectangle(
            cornerRadius: min(height / 2, PPCorner.verysmall),
            style: .continuous
        )
        .fill(Color.ppTextTertiary.opacity(0.14))
        .frame(maxWidth: width)
        .frame(height: height)
    }

    private static let factPlaceholders = [
        PPPetAdLoadingPlaceholder(id: "location", titleWidth: 72),
        PPPetAdLoadingPlaceholder(id: "age", titleWidth: 72),
        PPPetAdLoadingPlaceholder(id: "gender", titleWidth: 72)
    ]

    private static let timelinePlaceholders = [
        PPPetAdLoadingPlaceholder(id: "story", titleWidth: 150),
        PPPetAdLoadingPlaceholder(id: "trust", titleWidth: 118),
        PPPetAdLoadingPlaceholder(id: "seller", titleWidth: 150),
        PPPetAdLoadingPlaceholder(id: "decision", titleWidth: 118)
    ]
}

private struct PPPetAdLoadingPlaceholder: Identifiable {
    let id: String
    let titleWidth: CGFloat
}
