import SwiftUI
import UIKit

@available(iOS 16.0, *)
public struct PPServiceViewerScreen: View {
    @StateObject var store: PPServiceViewerStore
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: PPServiceViewerStore, onClose: @escaping () -> Void) {
        self._store = StateObject(wrappedValue: store)
        self.onClose = onClose
    }

    @State private var showsNavigationTitlePill = false

    public var body: some View {
        ZStack(alignment: .top) {
            Color.ppBackground
                .ignoresSafeArea()

            if let snapshot = store.snapshot {
                GeometryReader { proxy in
                    let contentWidth = min(proxy.size.width, 900)
                    let compact = contentWidth < 700
                    let horizontalPadding: CGFloat = compact ? 16 : 34
                    let heroHeight = compact
                        ? min(max(proxy.size.height * 0.42, 370), 460)
                        : min(max(contentWidth * 0.52, 420), 560)
                    let topBarHeight: CGFloat = proxy.safeAreaInsets.top + 60

                    ZStack(alignment: .top) {
                        ScrollView {
                            PPAccessoryViewerScrollOffsetReader()

                            VStack(spacing: 18) {
                                PPServiceViewerHeroHeader(
                                    imageURL: snapshot.imageURL,
                                    blurHash: snapshot.blurHash,
                                    height: heroHeight,
                                    compact: compact
                                )
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, topBarHeight)

                                VStack(spacing: 18) {
                                    PPServiceViewerTitleCard(snapshot: snapshot)

                                    PPServiceViewerProviderCard(
                                        snapshot: snapshot,
                                        onCall: store.callProvider
                                    )

                                    if !snapshot.desc.isEmpty {
                                        descriptionCard(snapshot.desc)
                                    }

                                    reviewsSection
                                }
                                .padding(.horizontal, PPSpace.screenMargin)
                                .padding(.bottom, 100)
                            }
                        }
                        .coordinateSpace(
                            name: PPAccessoryViewerScrollMetrics.coordinateSpace
                        )
                        .onPreferenceChange(
                            PPAccessoryViewerScrollOffsetPreferenceKey.self
                        ) { scrollDistance in
                            showsNavigationTitlePill = scrollDistance > 120
                        }
                        .ignoresSafeArea(edges: .top)

                        PPServiceViewerTopBar(
                            onClose: onClose,
                            onShare: { store.shareService() },
                            snapshot: snapshot,
                            showsSmartTitle: showsNavigationTitlePill
                        )
                        .padding(.top, proxy.safeAreaInsets.top + 4)

                        PPServiceViewerActionBar(
                            snapshot: snapshot,
                            onShare: { store.shareService() },
                            onCall: { store.callProvider() },
                            onClose: onClose
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            } else {
                ProgressView()
                    .tint(Color.ppPrimary)
            }
        }
        .environment(
            \.layoutDirection,
            Language.isRTL() ? .rightToLeft : .leftToRight
        )
        .onAppear {
            store.load()
        }
    }

    private func descriptionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PPServiceViewerL10n.text("About Service", fallback: "About Service"))
                .font(PPAccessoryTypography.headline)
                .foregroundStyle(Color.ppTextPrimary)

            Text(text)
                .font(PPAccessoryTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppGlassSurface(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: Color.ppCard.opacity(0.85),
            fallback: Color(uiColor: .systemBackground).opacity(0.95),
            stroke: Color.white.opacity(0.18)
        )
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PPServiceViewerReviewComposer(
                rating: $store.reviewRating,
                text: $store.reviewText,
                isSubmitting: store.isSubmittingReview,
                onSubmit: { store.submitReview() }
            )

            if !store.reviews.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(PPServiceViewerL10n.text("Reviews", fallback: "Reviews"))
                        .font(PPAccessoryTypography.headline)
                        .foregroundStyle(Color.ppTextPrimary)

                    ForEach(store.reviews) { review in
                        PPServiceViewerReviewRow(item: review)
                    }
                }
                .padding(16)
                .ppGlassSurface(
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                    tint: Color.ppCard.opacity(0.85),
                    fallback: Color(uiColor: .systemBackground).opacity(0.95),
                    stroke: Color.white.opacity(0.18)
                )
            }
        }
    }
}
