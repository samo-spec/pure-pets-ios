import SwiftUI

struct PPPetAdViewerScreen: View {
    let isRoot: Bool
    let languageCode: String
    let authenticationRevision: UUID

    @StateObject private var store: PPPetAdViewerStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collapseProgress: CGFloat = 0
    @State private var isNavigationCollapsed = false
    @State private var hasAppeared = false

    private let repository: PPPetAdViewerRepository
    private let hostActions: PPPetAdViewerHostActions

    init(
        ad: PetAd,
        repository: PPPetAdViewerRepository,
        hostActions: PPPetAdViewerHostActions,
        isRoot: Bool,
        languageCode: String,
        authenticationRevision: UUID
    ) {
        self.repository = repository
        self.hostActions = hostActions
        self.isRoot = isRoot
        self.languageCode = languageCode
        self.authenticationRevision = authenticationRevision
        _store = StateObject(
            wrappedValue: PPPetAdViewerStore(
                ad: ad,
                repository: repository,
                hostActions: hostActions
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PPPetAdViewerBackground()

                switch store.screenState {
                case .loading:
                    PPPetAdViewerLoadingStateView()
                case .content:
                    content(proxy: proxy)
                case .empty:
                    PPPetAdViewerEmptyStateView(onClose: handleBack)
                case .offline(let message):
                    PPPetAdViewerErrorStateView(
                        isOffline: true,
                        message: message,
                        onRetry: store.refresh,
                        onClose: handleBack
                    )
                case .failed(let message):
                    PPPetAdViewerErrorStateView(
                        isOffline: false,
                        message: message,
                        onRetry: store.refresh,
                        onClose: handleBack
                    )
                }

                navigationBar
                    .padding(.top, proxy.safeAreaInsets.top)
                    .background {
                        navigationBackground
                    }
                    .frame(maxHeight: .infinity, alignment: .top)

                navigationLink

                if let message = store.toastMessage {
                    PPPetAdToastView(message: message)
                        .padding(.horizontal, PPSpace.screenMargin)
                        .padding(
                            .bottom,
                            max(proxy.safeAreaInsets.bottom, PPSpace.lg)
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                        .zIndex(20)
                }
            }
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.toast,
                value: store.toastMessage
            )
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $store.isMediaViewerPresented) {
            PPPetAdMediaViewerScreen(
                items: store.snapshot.media,
                selection: $store.selectedMediaIndex,
                onDismiss: {
                    store.isMediaViewerPresented = false
                },
                onShare: store.share
            )
        }
        .confirmationDialog(
            PPPetAdLocalization.text(
                "report_ad_title",
                fallback: "Report advertisement"
            ),
            isPresented: $store.isReportDialogPresented,
            titleVisibility: .visible
        ) {
            ForEach(PPPetAdReportReason.allCases) { reason in
                Button(reason.title) {
                    store.submitReport(reason: reason)
                }
            }
            Button(
                PPPetAdLocalization.text("Cancel", fallback: "Cancel"),
                role: .cancel
            ) {
            }
        } message: {
            Text(
                PPPetAdLocalization.text(
                    "report_ad_message",
                    fallback: "Choose the reason that best describes the issue."
                )
            )
        }
        .onAppear {
            store.start()
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(PPPetAdViewerMotion.content.delay(0.04)) {
                    hasAppeared = true
                }
            }
        }
        .onChange(of: languageCode) { _ in
            store.refreshLocalization()
        }
        .onChange(of: authenticationRevision) { _ in
            store.refreshAuthenticationState()
        }
    }

    private func content(proxy: GeometryProxy) -> some View {
        let metrics = PPPetAdViewerLayoutMetrics(
            containerSize: proxy.size,
            safeAreaTop: proxy.safeAreaInsets.top
        )

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                GeometryReader { heroProxy in
                    let offset = heroProxy.frame(
                        in: .named("PPPetAdViewerScroll")
                    ).minY
                    let progress = metrics.collapseProgress(
                        for: offset
                    )

                    PPPetAdHeroGallery(
                        items: store.snapshot.media,
                        selection: $store.selectedMediaIndex,
                        collapseProgress: progress,
                        onOpen: store.selectMedia
                    )
                    .frame(
                        width: heroProxy.size.width,
                        height: metrics.heroHeight(for: offset)
                    )
                    .offset(y: -offset)
                    .preference(
                        key: PPPetAdScrollOffsetPreferenceKey.self,
                        value: offset
                    )
                }
                .frame(height: metrics.expandedHeroHeight)
                .zIndex(2)

                detailsSheet(bottomInset: proxy.safeAreaInsets.bottom)
                    .zIndex(1)
            }
        }
        .coordinateSpace(name: "PPPetAdViewerScroll")
        .ignoresSafeArea(edges: .top)
        .refreshable {
            store.refresh()
        }
        .onPreferenceChange(PPPetAdScrollOffsetPreferenceKey.self) {
            offset in
            let nextProgress = metrics.collapseProgress(for: offset)
            if abs(nextProgress - collapseProgress) > 0.002 {
                collapseProgress = nextProgress
            }

            let nextCollapsed =
                isNavigationCollapsed
                ? nextProgress > 0.72
                : nextProgress >= 0.86
            if nextCollapsed != isNavigationCollapsed {
                isNavigationCollapsed = nextCollapsed
            }
        }
    }

    private func detailsSheet(bottomInset: CGFloat) -> some View {
        VStack(spacing: PPSpace.lg) {
            PPPetAdHeaderCard(
                title: store.snapshot.title,
                category: store.snapshot.category,
                subcategory: store.snapshot.subcategory,
                location: store.snapshot.location,
                price: store.snapshot.price
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.xl)

            PPPetAdInfoGrid(
                type: store.snapshot.subcategory.isEmpty
                    ? store.snapshot.category
                    : store.snapshot.subcategory,
                age: store.snapshot.age,
                gender: store.snapshot.gender
            )
            .padding(.horizontal, PPSpace.screenMargin)

            PPPetAdContactCard(store: store)
                .padding(.horizontal, PPSpace.screenMargin)

            if !store.snapshot.description.isEmpty {
                PPPetAdDescriptionCard(
                    description: store.snapshot.description
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

            PPPetAdRelatedSection(
                title: PPPetAdLocalization.text(
                    "Similar Ads",
                    fallback: "Similar pets"
                ),
                subtitle: PPPetAdLocalization.text(
                    "pet_ad_viewer_similar_detail",
                    fallback: "More listings selected from this category."
                ),
                state: store.relatedAdsState,
                items: store.relatedAds,
                onRetry: store.retryRelatedAds,
                onSelect: store.selectRelatedItem
            )

            PPPetAdRelatedSection(
                title: PPPetAdLocalization.text(
                    "Similar Accessories",
                    fallback: "Related accessories"
                ),
                subtitle: PPPetAdLocalization.text(
                    "pet_ad_viewer_accessories_detail",
                    fallback: "Useful finds chosen for pets in this category."
                ),
                state: store.accessoriesState,
                items: store.relatedAccessories,
                onRetry: store.retryAccessories,
                onSelect: store.selectRelatedItem
            )

            Color.clear.frame(
                height: max(
                    PPSpace.xxxxl,
                    bottomInset + PPSpace.xxl
                )
            )
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.ppBackground,
            in: RoundedRectangle(
                cornerRadius: PPCorner.hero,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.hero,
                style: .continuous
            )
            .stroke(
                Color(uiColor: .separator).opacity(0.16),
                lineWidth: 0.5
            )
        }
        .opacity(hasAppeared ? 1 : 0)
    }

    private var navigationBar: some View {
        PPPetAdViewerNavigationBar(
            title: store.snapshot.title,
            isCollapsed: isNavigationCollapsed,
            isFavorite: store.isFavorite,
            isFavoriteWorking: store.favoriteState == .working,
            canShare: store.screenState == .content,
            canFavorite:
                store.screenState == .content && !store.snapshot.ad.adID.isEmpty,
            canReport:
                store.screenState == .content && store.canReport,
            isReportWorking: store.reportState == .working,
            onBack: handleBack,
            onFavorite: store.toggleFavorite,
            onShare: store.share,
            onReport: store.requestReport
        )
        .zIndex(10)
    }

    @ViewBuilder
    private var navigationBackground: some View {
        if store.screenState == .content {
            Color.clear
                .ppGlassSurface(
                    in: Rectangle(),
                    tint: Color.black.opacity(0.30),
                    fallback: Color.black.opacity(0.92),
                    stroke: .clear,
                    lineWidth: 0
                )
                .overlay(alignment: .bottom) {
                    Divider()
                        .overlay(Color.white.opacity(0.10))
                }
                .opacity(collapseProgress)
                .ignoresSafeArea(edges: .top)
        } else {
            PPGradient.hero
                .overlay(Color.black.opacity(0.12))
                .ignoresSafeArea(edges: .top)
        }
    }

    private var navigationLink: some View {
        NavigationLink(isActive: $store.isRelatedViewerPresented) {
            Group {
                if let ad = store.selectedPetAd {
                    PPPetAdViewerScreen(
                        ad: ad,
                        repository: repository,
                        hostActions: hostActions,
                        isRoot: false,
                        languageCode: languageCode,
                        authenticationRevision: authenticationRevision
                    )
                    .id(ObjectIdentifier(ad))
                } else {
                    EmptyView()
                }
            }
        } label: {
            EmptyView()
        }
        .hidden()
    }

    private func handleBack() {
        if isRoot {
            store.close()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
