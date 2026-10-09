import SwiftUI
import UIKit

@available(iOS 15.0, *)
public struct PPServiceViewerScreen: View {
    // UIKit creates and owns the store; SwiftUI observes that same instance.
    @ObservedObject var store: PPServiceViewerStore
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var languageCode = Language.currentLanguageCode()
    @State private var showsReview = false
    @AccessibilityFocusState private var reviewButtonFocused: Bool

    public init(store: PPServiceViewerStore, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            PPServiceViewerTopBar(
                onClose: onClose,
                onShare: { store.shareService() },
                canShare: store.snapshot != nil
            )

            if let snapshot = store.snapshot {
                GeometryReader { geometry in
                    let wide = geometry.size.width >= 800 && !dynamicTypeSize.isAccessibilitySize
                    ScrollView {
                        VStack(alignment: .leading, spacing: PPSpace.xl) {
                            if let error = store.serviceError {
                                PPServiceViewerRecovery(message: error, action: store.refresh)
                            } else if store.isServiceCached {
                                Label(PPServiceViewerL10n.text("service_note_saved_details"),
                                      systemImage: "icloud.slash")
                                    .font(PPAccessoryTypography.callout)
                                    .foregroundStyle(Color.ppTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            PPServiceViewerIntroduction(snapshot: snapshot)

                            if wide {
                                HStack(alignment: .top, spacing: PPSpace.xxl) {
                                    details(snapshot)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    decision(snapshot)
                                        .frame(width: 300, alignment: .leading)
                                }
                            } else {
                                decision(snapshot)
                                details(snapshot)
                            }

                            Divider().overlay(Color.ppSurfaceBorder)
                            reviewsSection(snapshot)
                        }
                        .frame(maxWidth: wide ? 960 : 660, alignment: .leading)
                        .padding(.horizontal, geometry.size.width < 360
                            ? PPSpace.base : PPSpace.screenMargin)
                        .padding(.top, PPSpace.lg)
                        .padding(.bottom, PPSpace.xl)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    PPServiceViewerActionBar(
                        snapshot: snapshot,
                        isLoadingOwner: store.isLoadingOwner,
                        isSignedIn: store.isSignedIn,
                        onCall: store.callProvider
                    )
                }
            } else {
                unavailable
            }
        }
        .background(Color.ppBackground.ignoresSafeArea())
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: languageCode == "ar" ? "ar_QA" : "en_QA"))
        .multilineTextAlignment(.leading)
        .sheet(isPresented: $showsReview, onDismiss: { reviewButtonFocused = true }) {
            PPServiceViewerReviewComposer(store: store, onClose: { showsReview = false })
                .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
                .environment(\.locale, PPServiceViewerL10n.locale)
        }
        .alert(PPServiceViewerL10n.text("service_view_default_title"),
               isPresented: Binding(
                get: { store.bannerMessage != nil },
                set: { if !$0 { store.bannerMessage = nil } }
               )) {
            Button(PPServiceViewerL10n.text("OK"), role: .cancel) { store.bannerMessage = nil }
        } message: {
            Text(store.bannerMessage ?? "")
        }
        .onAppear { store.load() }
        .onDisappear { store.stop() }
        .serviceViewerOnChange(of: scenePhase) { phase in
            if phase == .active { store.load() }
            else if phase == .background { store.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name("PPLanguageDidChangeNotification"))) { _ in
                languageCode = Language.currentLanguageCode()
                store.refreshLocalization()
        }
    }

    private func decision(_ snapshot: PPServiceViewerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            PPServiceViewerFacts(snapshot: snapshot)
            PPServiceViewerProvider(
                snapshot: snapshot,
                isLoading: store.isLoadingOwner,
                isSignedIn: store.isSignedIn,
                error: store.ownerError,
                onRetry: store.retryOwner,
                onSignIn: { store.onRequestSignIn?() }
            )
        }
    }

    private func details(_ snapshot: PPServiceViewerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Text(PPServiceViewerL10n.text("service_note_about"))
                .font(PPAccessoryTypography.headline)
                .foregroundStyle(Color.ppTextPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(snapshot.desc.isEmpty
                ? PPServiceViewerL10n.text("service_view_no_description")
                : snapshot.desc)
                .font(PPAccessoryTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reviewsSection(_ snapshot: PPServiceViewerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            Text(PPServiceViewerL10n.text("service_view_reviews_title"))
                .font(PPAccessoryTypography.title)
                .foregroundStyle(Color.ppTextPrimary)
                .accessibilityAddTraits(.isHeader)

            if snapshot.reviewCount > 0 && snapshot.ratingValue > 0 {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Label(PPServiceViewerL10n.format("service_note_rating_format",
                            PPServiceViewerL10n.number(snapshot.ratingValue, decimals: 1)),
                          systemImage: "star.fill")
                        .font(PPAccessoryTypography.hero)
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPServiceViewerL10n.format("service_note_review_count",
                        PPServiceViewerL10n.number(Double(snapshot.reviewCount))))
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .accessibilityElement(children: .combine)
            }

            Button {
                showsReview = true
            } label: {
                Label(PPServiceViewerL10n.text("service_review_composer_title"),
                      systemImage: "square.and.pencil")
                    .font(PPAccessoryTypography.bodyBold)
                    .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.ppAccentText)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PPServiceViewerPressStyle())
            .accessibilityLabel(PPServiceViewerL10n.text("service_review_composer_title"))
            .disabled(!snapshot.isReviewable)
            .accessibilityFocused($reviewButtonFocused)

            if !snapshot.isReviewable {
                Text(PPServiceViewerL10n.text("service_note_review_unavailable"))
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(Color.ppTextSecondary)
            }
            if store.isLoadingReviews {
                ProgressView(PPServiceViewerL10n.text("service_note_reviews_loading"))
                    .font(PPAccessoryTypography.callout)
                    .tint(Color.ppPrimary)
            }
            if let error = store.reviewsError {
                PPServiceViewerRecovery(message: error, action: store.retryReviews)
            }
            if !store.isLoadingReviews && store.reviewsError == nil && store.reviews.isEmpty {
                Text(PPServiceViewerL10n.text(snapshot.reviewCount == 0
                    ? "service_note_reviews_empty" : "service_note_reviews_not_loaded"))
                    .font(PPAccessoryTypography.body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.reviews) { review in
                    PPServiceViewerReviewRow(item: review)
                    Divider().overlay(Color.ppSurfaceBorder)
                }
            }

            if store.canLoadMoreReviews {
                Button(action: store.loadMoreReviews) {
                    HStack(spacing: PPSpace.sm) {
                        if store.isLoadingMoreReviews { ProgressView().tint(Color.ppPrimary) }
                        Text(PPServiceViewerL10n.text("service_note_more_reviews"))
                            .font(PPAccessoryTypography.calloutBold)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .foregroundStyle(Color.ppAccentText)
                .buttonStyle(PPServiceViewerPressStyle())
                .disabled(store.isLoadingMoreReviews)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unavailable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PPSpace.base) {
                if store.isLoadingService {
                    ProgressView(PPServiceViewerL10n.text("Loading"))
                        .font(PPAccessoryTypography.body)
                        .tint(Color.ppPrimary)
                } else {
                    Image(systemName: "pawprint")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.ppAccentText)
                        .accessibilityHidden(true)
                    Text(PPServiceViewerL10n.text(store.serviceMissing
                        ? "service_note_missing" : "service_note_details_error"))
                        .font(PPAccessoryTypography.hero)
                        .foregroundStyle(Color.ppTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(PPServiceViewerL10n.text("service_note_missing_detail"))
                        .font(PPAccessoryTypography.body)
                        .foregroundStyle(Color.ppTextSecondary)
                    Button(action: store.refresh) {
                        Text(PPServiceViewerL10n.text("Retry"))
                            .font(PPAccessoryTypography.bodyBold)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(Color.ppAccentText)
                    .buttonStyle(PPServiceViewerPressStyle())
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PPSpace.xl)
            .padding(.top, PPSpace.xxl)
        }
    }
}
