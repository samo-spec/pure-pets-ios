import SwiftUI

/// Root scene of the pet-ad viewer.
///
/// Composition contract:
/// 1. A full-bleed hero that stretches on pull and parallax-collapses
///    beneath floating chrome.
/// 2. A continuous-corner sheet that cascades its sections in on first
///    appearance — identity, facts, trust, story, discovery.
/// 3. A single store driving five fully designed screen states
///    (loading / content / empty / offline / failed).
struct PPPetAdViewerScreen: View {
    let isRoot: Bool
    let languageCode: String
    let authenticationRevision: UUID

    @StateObject private var store: PPPetAdViewerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isNavigationCollapsed = false
    @State private var heroMinY: CGFloat = 0
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

    /// Readable measure on iPad and multitasking widths.
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : .infinity
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PPPetAdViewerBackground()

                sceneContent(proxy: proxy)
                    .animation(
                        reduceMotion ? nil : PPPetAdViewerMotion.content,
                        value: store.screenState
                    )

                navigationBar
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
                                : .move(edge: .bottom).combined(
                                    with: .opacity
                                )
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
        .fullScreenCover(
            isPresented: $store.isMediaViewerPresented
        ) {
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
                    fallback:
                        "Choose the reason that best describes the issue."
                )
            )
        }
        .onAppear {
            store.start()
            guard !hasAppeared else { return }
            hasAppeared = true
        }
        .adOnChange(of: languageCode) { _ in
            store.refreshLocalization()
        }
        .adOnChange(of: authenticationRevision) { _ in
            store.refreshAuthenticationState()
        }
    }

    // MARK: - Scene states

    @ViewBuilder
    private func sceneContent(proxy: GeometryProxy) -> some View {
        switch store.screenState {
        case .loading:
            PPPetAdViewerLoadingStateView()
                .transition(.opacity)
        case .content:
            content(proxy: proxy)
                .transition(.opacity)
        case .empty:
            PPPetAdViewerEmptyStateView(onClose: handleBack)
                .transition(.opacity)
        case let .offline(message):
            PPPetAdViewerErrorStateView(
                isOffline: true,
                message: message,
                onRetry: store.refresh,
                onClose: handleBack
            )
            .transition(.opacity)
        case let .failed(message):
            PPPetAdViewerErrorStateView(
                isOffline: false,
                message: message,
                onRetry: store.refresh,
                onClose: handleBack
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Content scene

private extension PPPetAdViewerScreen {
    /// Single ScrollView: hero as stretchy header, sheet content below
    /// overlapping the hero. Eliminates dual-scroll gesture conflicts.
    func content(proxy: GeometryProxy) -> some View {
        let heroHeight = min(
            max(proxy.size.width * 0.62, 220),
            horizontalSizeClass == .regular ? 320 : 286
        )
        let navBarBottomY = proxy.safeAreaInsets.top + 60.0
        let minHeroHeight = max(navBarBottomY, heroHeight * 0.40)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                heroBlock(
                    heroHeight: heroHeight,
                    minHeroHeight: minHeroHeight
                )
                .frame(height: heroHeight)

                detailsSheet()
                    .offset(y: -PPSpace.xl)
                    .padding(.bottom, -PPSpace.xl)
            }
        }
        .coordinateSpace(name: "PPPetAdViewerScroll")
        .ignoresSafeArea(edges: .top)
        .refreshable { store.refresh() }
        .onPreferenceChange(PPPetAdScrollOffsetPreferenceKey.self) { value in
            heroMinY = value
            let nextValue =
                value < -(heroHeight - navBarBottomY - PPSpace.lg)
            if nextValue != isNavigationCollapsed {
                withAnimation(
                    reduceMotion ? nil : PPPetAdViewerMotion.navigation
                ) {
                    isNavigationCollapsed = nextValue
                }
            }
        }
    }

    /// Stretchy, parallaxing hero that blurs as it collapses.
    func heroBlock(
        heroHeight: CGFloat,
        minHeroHeight: CGFloat
    ) -> some View {
        GeometryReader { heroGeometry in
            let minY = heroGeometry
                .frame(in: .named("PPPetAdViewerScroll"))
                .minY
            let isPullingDown = minY > 0

            let currentHeight: CGFloat = {
                if isPullingDown {
                    return heroHeight + minY
                }
                let maxCollapse = heroHeight - minHeroHeight
                let collapse = min(maxCollapse, abs(minY))
                return heroHeight - collapse
            }()

            let offsetY: CGFloat = -minY
            let blurRadius =
                isPullingDown ? 0 : min(8.0, abs(minY) / 40.0)

            PPPetAdHeroGallery(
                items: store.snapshot.media,
                selection: $store.selectedMediaIndex,
                onOpen: store.selectMedia
            )
            .frame(height: currentHeight)
            .blur(radius: blurRadius)
            .offset(y: offsetY)
            .preference(
                key: PPPetAdScrollOffsetPreferenceKey.self,
                value: minY
            )
        }
    }
}


// MARK: - Details sheet

private extension PPPetAdViewerScreen {
    /// Sections rise in a 55ms stagger: grabber → identity → facts →
    /// trust → story → discovery. Each step is a spring, never a snap.
    func detailsSheet() -> some View {
        VStack(spacing: PPSpace.base) {
            Capsule()
                .fill(Color.ppTextTertiary.opacity(0.22))
                .frame(width: 40, height: 5)
                .padding(.top, PPSpace.sm)
                .accessibilityHidden(true)
                .adCascade(step: 0, appeared: hasAppeared, reduceMotion: reduceMotion)

            PPPetAdHeaderCard(
                title: store.snapshot.title,
                categoryLine: store.snapshot.categoryLine,
                location: store.snapshot.location,
                price: store.snapshot.price,
                postedDate: store.snapshot.postedDate
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .adCascade(step: 1, appeared: hasAppeared, reduceMotion: reduceMotion)

            PPPetAdInfoGrid(
                type: store.snapshot.typeLabel,
                age: store.snapshot.age,
                gender: store.snapshot.gender
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .adCascade(step: 2, appeared: hasAppeared, reduceMotion: reduceMotion)

            PPPetAdContactCard(store: store)
                .padding(.horizontal, PPSpace.screenMargin)
                .adCascade(step: 3, appeared: hasAppeared, reduceMotion: reduceMotion)

            if !store.snapshot.normalizedDescription.isEmpty {
                PPPetAdDescriptionCard(
                    description: store.snapshot.normalizedDescription
                )
                .padding(.horizontal, PPSpace.screenMargin)
                .adCascade(step: 4, appeared: hasAppeared, reduceMotion: reduceMotion)
            }

            PPPetAdRelatedSection(
                title: PPPetAdLocalization.text(
                    "Similar Ads",
                    fallback: "Similar pets"
                ),
                subtitle: PPPetAdLocalization.text(
                    "pet_ad_viewer_similar_detail",
                    fallback:
                        "More listings selected from this category."
                ),
                state: store.relatedAdsState,
                items: store.relatedAds,
                onRetry: store.retryRelatedAds,
                onSelect: store.selectRelatedItem
            )
            .adCascade(step: 5, appeared: hasAppeared, reduceMotion: reduceMotion)

            PPPetAdRelatedSection(
                title: PPPetAdLocalization.text(
                    "Similar Accessories",
                    fallback: "Related accessories"
                ),
                subtitle: PPPetAdLocalization.text(
                    "pet_ad_viewer_accessories_detail",
                    fallback:
                        "Useful finds chosen for pets in this category."
                ),
                state: store.accessoriesState,
                items: store.relatedAccessories,
                onRetry: store.retryAccessories,
                onSelect: store.selectRelatedItem
            )
            .adCascade(step: 6, appeared: hasAppeared, reduceMotion: reduceMotion)

            Color.clear.frame(height: PPSpace.xxxl)
        }
        .padding(.top, PPSpace.sm)
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity)
        .background(
            Color.ppBackground,
            in: RoundedRectangle(
                cornerRadius: PPCorner.hero,
                style: .continuous
            )
        )
    }
}

// MARK: - Cascade entrance

private extension View {
    /// Applies the sheet's staggered first-appearance rise. When Reduce
    /// Motion is on, content simply appears — never animates.
    func adCascade(
        step: Int,
        appeared: Bool,
        reduceMotion: Bool
    ) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 24)
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.cascadeDelay(step),
                value: appeared
            )
    }
}


// MARK: - Chrome, navigation & dismissal

private extension PPPetAdViewerScreen {
    var navigationBar: some View {
        PPPetAdViewerNavigationBar(
            title: store.snapshot.title,
            isCollapsed: isNavigationCollapsed,
            scrollOffset: heroMinY,
            isFavorite: store.isFavorite,
            isFavoriteWorking: store.favoriteState == .working,
            canShare: store.screenState == .content,
            canFavorite:
                store.screenState == .content &&
                !store.snapshot.ad.adID.isEmpty,
            canReport:
                store.screenState == .content &&
                store.canReport,
            isReportWorking: store.reportState == .working,
            onBack: handleBack,
            onFavorite: store.toggleFavorite,
            onShare: store.share,
            onReport: store.requestReport
        )
        .zIndex(10)
    }

    /// Push-based drill-in for related pet ads. Accessories route through
    /// the legacy navigation stack via the host actions instead.
    var navigationLink: some View {
        NavigationLink(
            isActive: $store.isRelatedViewerPresented
        ) {
            Group {
                if let ad = store.selectedPetAd {
                    PPPetAdViewerScreen(
                        ad: ad,
                        repository: repository,
                        hostActions: hostActions,
                        isRoot: false,
                        languageCode: languageCode,
                        authenticationRevision:
                            authenticationRevision
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

    func handleBack() {
        if isRoot {
            store.close()
        } else {
            dismiss()
        }
    }
}

