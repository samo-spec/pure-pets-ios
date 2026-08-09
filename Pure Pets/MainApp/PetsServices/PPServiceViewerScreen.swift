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
            PPPetAdViewerBackground(
                topColor: store.heroTopColor,
                middleColor: store.heroMiddleColor,
                bottomColor: store.heroBottomColor
            )

            if let snapshot = store.snapshot {
                GeometryReader { proxy in
                    let contentWidth = min(proxy.size.width, 900)
                    let compact = contentWidth < 700
                    let horizontalPadding: CGFloat = compact ? 16 : 34
                    let heroHeight = compact
                        ? min(max(proxy.size.height * 0.39, 330), 430)
                        : min(max(contentWidth * 0.48, 400), 530)
                    let topBarHeight: CGFloat = proxy.safeAreaInsets.top + 14

                    ZStack(alignment: .top) {
                        ScrollView(showsIndicators: false) {
                            PPAccessoryViewerScrollOffsetReader()

                            VStack(spacing: 0) {
                                PPServiceViewerHeroHeader(
                                    imageURL: snapshot.imageURL,
                                    blurHash: snapshot.blurHash,
                                    cacheKey: snapshot.serviceID,
                                    height: heroHeight,
                                    compact: compact,
                                    onImageLoaded: { img in
                                        store.handleImageLoaded(img)
                                    }
                                )
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, topBarHeight)

                                VStack(spacing: 24) {
                                    PPServiceViewerCarePassport(
                                        snapshot: snapshot,
                                        onCall: store.callProvider
                                    )

                                    if !snapshot.desc.isEmpty {
                                        descriptionCard(snapshot.desc)
                                    }

                                    reviewsSection
                                }
                                .padding(.horizontal, PPSpace.screenMargin)
                                .padding(.top, -34)
                                .padding(.bottom, 110)
                            }
                        }
                        .coordinateSpace(
                            name: PPAccessoryViewerScrollMetrics.coordinateSpace
                        )
                        .onPreferenceChange(
                            PPAccessoryViewerScrollOffsetPreferenceKey.self
                        ) { scrollDistance in
                            showsNavigationTitlePill = scrollDistance > 220
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
                            onCall: { store.callProvider() }
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.ppPrimary)
                        .accessibilityHidden(true)

                    ProgressView()
                        .tint(Color.ppPrimary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(PPServiceViewerL10n.text("Loading", fallback: "Loading"))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                Text(PPServiceViewerL10n.text("service_view_description_title", fallback: "Description"))
                    .font(PPAccessoryTypography.headline)
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(text)
                .font(PPAccessoryTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .accessibilityAddTraits(.isHeader)

                    ForEach(store.reviews) { review in
                        PPServiceViewerReviewRow(item: review)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
