import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdViewerScreen: View {
    let isRoot: Bool
    let languageCode: String
    let authenticationRevision: UUID

    @StateObject private var store: PPPetAdViewerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                PPPetAdViewerBackground(
                    topColor: store.heroTopColor,
                    middleColor: store.heroMiddleColor,
                    bottomColor: store.heroBottomColor
                )

                screenContent(proxy: proxy)
                    .id(screenStateIdentity)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(scale: 0.992)
                            )
                    )

                navigationBar



                navigationLink

                contactDock(
                    bottomInset: proxy.safeAreaInsets.bottom
                )
                .zIndex(15)

                toastOverlay(
                    bottomInset: proxy.safeAreaInsets.bottom
                )
                .animation(
                    reduceMotion ? nil : PPPetAdViewerMotion.toast,
                    value: store.toastMessage
                )
                .zIndex(20)
            }
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.state,
                value: screenStateIdentity
            )
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.navigation,
                value: store.ppShowsContactDock
            )
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: Binding(
            get: { store.isMediaViewerPresented },
            set: { store.isMediaViewerPresented = $0 }
        )) {
            PPPetAdMediaViewerScreen(
                items: store.snapshot.media,
                selection: Binding(
                    get: { store.selectedMediaIndex },
                    set: { store.selectedMediaIndex = $0 }
                ),
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
            isPresented: Binding(
                get: { store.isReportDialogPresented },
                set: { store.isReportDialogPresented = $0 }
            ),
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
            hasAppeared = true
        }
        .onChange(of: languageCode) { _ in
            store.refreshLocalization()
        }
        .onChange(of: authenticationRevision) { _ in
            store.refreshAuthenticationState()
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private func screenContent(proxy: GeometryProxy) -> some View {
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
    }

    @ViewBuilder
    private func toastOverlay(bottomInset: CGFloat) -> some View {
        if let message = store.toastMessage {
            PPPetAdToastView(message: message)
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(
                    .bottom,
                    max(
                        bottomInset + contactDockClearance,
                        PPSpace.lg
                    )
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
        }
    }

    private func content(proxy: GeometryProxy) -> some View {
        let metrics = PPPetAdViewerLayoutMetrics(
            containerSize: proxy.size,
            safeAreaTop: proxy.safeAreaInsets.top
        )

        return PPPetAdHeroScrollContainer(
            minimumHeroHeight: metrics.minimumHeroHeight,
            expandedHeroHeight: metrics.expandedHeroHeight,
            onRefresh: store.refresh,
            onNavigationCollapseChanged: setNavigationCollapsed
        ) { scrollState in
            PPPetAdHeroGallery(
                items: store.snapshot.media,
                selection: Binding(
                    get: { store.selectedMediaIndex },
                    set: { store.selectedMediaIndex = $0 }
                ),
                scrollState: scrollState,
                onOpen: store.selectMedia(at:),
                bottomViewType: .thumbRails,
                onFirstImageLoaded: store.handleFirstImageLoaded
            )

            .ignoresSafeArea()
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(
                reduceMotion || hasAppeared ? 1 : 1.012,
                anchor: UnitPoint.center
            )
            .animation(
                reduceMotion
                    ? Animation.easeOut(duration: 0.16)
                    : Animation.easeOut(duration: 0.38),
                value: hasAppeared
            )
        } content: {
            detailsSheet(bottomInset: proxy.safeAreaInsets.bottom)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func setNavigationCollapsed(_ isCollapsed: Bool) {
        guard isCollapsed != isNavigationCollapsed else { return }
        isNavigationCollapsed = isCollapsed
    }

    private func detailsSheet(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            PPPetAdDetailsSummary(
                title: store.snapshot.title,
                location: store.snapshot.location,
                price: store.snapshot.price,
                type: summaryType,
                age: store.snapshot.age,
                gender: store.snapshot.gender
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPPetAdViewerStyle.contentTopPadding)
            .ppPetAdEntrance(
                isPresented: hasAppeared,
                delayIndex: 0
            )

            if !store.snapshot.description.isEmpty {
                PPPetAdDescriptionCard(
                    title: aboutTitle,
                    description: store.snapshot.description
                )
                .padding(.horizontal, PPSpace.screenMargin)
                .ppPetAdEntrance(
                    isPresented: hasAppeared,
                    delayIndex: 2
                )
            }

            if store.ppShowsInlineContactStatus {
                PPPetAdContactCard(
                    store: store,
                    showsActions: false
                )
                .padding(.horizontal, PPSpace.screenMargin)
                .ppPetAdEntrance(
                    isPresented: hasAppeared,
                    delayIndex: 3
                )
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
            .padding(.top, PPSpace.xxxl)
            .ppPetAdEntrance(
                isPresented: hasAppeared,
                delayIndex: 4
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
            .padding(.top, PPSpace.xxxl)
            .ppPetAdEntrance(
                isPresented: hasAppeared,
                delayIndex: 5
            )

            Color.clear.frame(
                height: max(
                    PPPetAdViewerStyle.contentBottomPadding,
                    bottomInset
                        + contactDockClearance
                        + PPSpace.xl
                )
            )
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            PPPetAdViewerStyle.sheetBackground
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: PPPetAdViewerStyle.sheetRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: PPPetAdViewerStyle.sheetRadius,
                        style: .continuous
                    )
                )
        }
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 12,
            x: 0,
            y: -3
        )
        .offset(y: -PPPetAdViewerStyle.sheetOverlap)
    }

    @ViewBuilder
    private func contactDock(bottomInset: CGFloat) -> some View {
        if store.ppShowsContactDock {
            let compactBottomPadding = max(8, min(bottomInset, 16))

            PPPetAdContactDock(store: store)
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.top, PPSpace.md + 2)
                .padding(.bottom, compactBottomPadding)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .background {
                    PPPetAdViewerStyle.sheetBackground
                        .ignoresSafeArea(edges: .bottom)
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            Color(uiColor: .separator).opacity(0.30)
                        )
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                .shadow(
                    color: Color.black.opacity(0.06),
                    radius: 12,
                    x: 0,
                    y: -3
                )
                .frame(maxHeight: .infinity, alignment: .bottom)

                .opacity(hasAppeared ? 1 : 0)
                .allowsHitTesting(hasAppeared)
                .accessibilityHidden(!hasAppeared)
                .offset(
                    y:
                        reduceMotion || hasAppeared
                        ? 0
                        : 8
                )
                .animation(
                    reduceMotion
                        ? Animation.easeOut(duration: 0.16)
                        : PPPetAdViewerMotion.entrance(
                            delayIndex: 2
                        ),
                    value: hasAppeared
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
                .animation(
                    reduceMotion ? nil : PPPetAdViewerMotion.navigation,
                    value: store.ppShowsContactDock
                )
        }
    }

    private var safeAreaTopInset: CGFloat {
        let windowTop = PPComponentSwift.PPStatusBarHeight
        return max(windowTop, 44)
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
        .padding(.top, safeAreaTopInset + 4)
        .background {
            navigationBackground
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .zIndex(10)
    }


    @ViewBuilder
    private var navigationBackground: some View {
        if isNavigationCollapsed {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            Color(uiColor: .separator).opacity(0.18)
                        )
                        .frame(height: PPPetAdViewerStyle.hairlineWidth)
                }
                .ignoresSafeArea(edges: .top)
        } else {
            Color.clear
        }
    }

    private var navigationLink: some View {
        NavigationLink(isActive: Binding(
            get: { store.isRelatedViewerPresented },
            set: { store.isRelatedViewerPresented = $0 }
        )) {
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
            dismiss()
        }
    }

    private var screenStateIdentity: Int {
        switch store.screenState {
        case .loading:
            return 0
        case .content:
            return 1
        case .empty:
            return 2
        case .offline:
            return 3
        case .failed:
            return 4
        }
    }

    private var summaryType: String {
        store.snapshot.subcategory.isEmpty
            ? store.snapshot.category
            : store.snapshot.subcategory
    }

    private var aboutTitle: String {
        guard !store.snapshot.title.isEmpty else {
            return PPPetAdLocalization.text(
                "pet_ad_viewer_description",
                fallback: "About this pet"
            )
        }

        return String(
            format: PPPetAdLocalization.text(
                "pet_ad_viewer_about_name_format",
                fallback: "About %@"
            ),
            store.snapshot.title
        )
    }

    private var contactDockClearance: CGFloat {
        guard store.ppShowsContactDock else { return 0 }
        return dynamicTypeSize.isAccessibilitySize ? 172 : 86
    }
}
