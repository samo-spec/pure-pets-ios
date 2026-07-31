import SwiftUI
import UIKit

private struct PPPetAdContactDockHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = max(value, nextValue())
    }
}

@available(iOS 16.0, *)
struct PPPetAdViewerScreen: View {
    let isRoot: Bool
    let languageCode: String
    let authenticationRevision: UUID

    @StateObject private var store: PPPetAdViewerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var interactionState = PPPetAdViewerInteractionState()
    @State private var hasAppeared = false
    @State private var contactDockHeight: CGFloat = 0

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
            let topInset = topChromeInset(proxy)
            let bottomInset = bottomChromeInset(proxy)

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

                PPPetAdTopAtmosphereOverlay(
                    interactionState: interactionState,
                    height: topInset + 80
                )

                navigationBar(topInset: topInset)

                navigationLink

                bottomFadeOverlay(proxy: proxy)

                contactDock(
                    bottomInset: bottomInset
                )
                .zIndex(15)

                toastOverlay(
                    bottomInset: bottomInset
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
        .ignoresSafeArea(.all, edges: [.top, .bottom])
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: Binding(
            get: { store.isMediaViewerPresented },
            set: { store.isMediaViewerPresented = $0 }
        )) {
            PPMediaViewer(
                items: PPMediaItem.from(petAdMedia: store.snapshot.media),
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
            safeAreaTop: topChromeInset(proxy)
        )

        return PPPetAdHeroScrollContainer(
            minimumHeroHeight: metrics.minimumHeroHeight,
            expandedHeroHeight: metrics.expandedHeroHeight,
            onRefresh: store.refresh,
            interactionState: interactionState
        ) { scrollState in
            PPPetAdHeroGallery(
                items: store.snapshot.media,
                selection: Binding(
                    get: { store.selectedMediaIndex },
                    set: { store.selectedMediaIndex = $0 }
                ),
                interactionState: scrollState,
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
            .zIndex(0)
        } content: {
            detailsSheet(bottomInset: bottomChromeInset(proxy))
                .zIndex(1)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func detailsSheet(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            sheetGrabberIndicator
                .padding(.top, 10)
                .padding(.bottom, 4)

            primaryDetailsContent

            PPPetAdRelatedSection(
                kind: .pets,
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
                kind: .accessories,
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
            PPPetAdWorldSheetSurface(
                interactionState: interactionState,
                topColor: store.heroTopColor,
                middleColor: store.heroMiddleColor,
                bottomColor: store.heroBottomColor
            )
        }
    }

    private var sheetGrabberIndicator: some View {
        Capsule()
            .fill(Color.ppTextSecondary.opacity(0.28))
            .frame(width: 36, height: 4.5)
            .accessibilityHidden(true)
    }

    private var primaryDetailsContent: some View {
        VStack(spacing: 0) {
            PPPetAdDetailsSummary(
                title: store.snapshot.title,
                location: store.snapshot.location,
                price: store.snapshot.price,
                type: summaryType,
                age: store.snapshot.age,
                gender: store.snapshot.gender,
                ad: store.snapshot.ad,
                interactionState: interactionState
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, interactionState.summaryTopPadding)
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
                    delayIndex: 1
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
                    delayIndex: 2
                )
            }
        }
        .padding(.bottom, PPSpace.base)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.ppSeparator.opacity(0.86),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
                .frame(height: PPPetAdViewerStyle.hairlineWidth)
                .padding(.horizontal, PPSpace.screenMargin)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func contactDock(bottomInset _: CGFloat) -> some View {
        if store.ppShowsContactDock {
            PPPetAdContactDock(store: store)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(
                    PPPetAdDockElevationModifier(
                        interactionState: interactionState
                    )
                )
                .background {
                    GeometryReader { dockProxy in
                        Color.clear.preference(
                            key: PPPetAdContactDockHeightPreferenceKey.self,
                            value: dockProxy.size.height
                        )
                    }
                }
                .padding(.horizontal, PPSpace.base)
                .padding(.bottom, 16)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
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
                .onPreferenceChange(
                    PPPetAdContactDockHeightPreferenceKey.self
                ) { measuredHeight in
                    guard abs(measuredHeight - contactDockHeight) > 0.5 else {
                        return
                    }
                    contactDockHeight = measuredHeight
                }
        }
    }

    private func navigationBar(topInset: CGFloat) -> some View {
        PPPetAdViewerNavigationBar(
            snapshot: store.snapshot,
            interactionState: interactionState,
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
        .padding(.top, topInset + PPSpace.sm)
        .background {
            navigationBackground
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .zIndex(10)
    }


    @ViewBuilder
    private var navigationBackground: some View {
        Color.clear
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
        let fallback = dynamicTypeSize.isAccessibilitySize ? 190.0 : 96.0
        return max(
            fallback,
            contactDockHeight
                + 16
        )
    }

    private func topChromeInset(_ proxy: GeometryProxy) -> CGFloat {
        if proxy.safeAreaInsets.top > 1 {
            return proxy.safeAreaInsets.top
        }
        let sceneTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
        return max(sceneTop, 24)
    }

    private func bottomChromeInset(_ proxy: GeometryProxy) -> CGFloat {
        if proxy.safeAreaInsets.bottom > 1 {
            return proxy.safeAreaInsets.bottom
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }

    private func bottomFadeOverlay(proxy _: GeometryProxy) -> some View {
        let totalOverlayHeight = contactDockHeight + 16 + 44
        let bottomColor = Color.ppBackground

        return LinearGradient(
            colors: [
                Color.clear,
                bottomColor.opacity(0.35),
                bottomColor.opacity(0.85),
                bottomColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: totalOverlayHeight)
        .ignoresSafeArea(edges: .bottom)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .opacity(hasAppeared && store.ppShowsContactDock ? 1 : 0)
        .animation(
            reduceMotion ? nil : PPPetAdViewerMotion.navigation,
            value: store.ppShowsContactDock
        )
        .zIndex(8)
    }
}

@available(iOS 16.0, *)
private struct PPPetAdTopAtmosphereOverlay: View {
    @ObservedObject var interactionState: PPPetAdViewerInteractionState
    let height: CGFloat

    var body: some View {
        LinearGradient(
            colors: [
                Color.ppBackground.opacity(
                    Double(
                        min(
                            0.92,
                            0.48 + interactionState.backgroundDimming
                        )
                    )
                ),
                Color.ppBackground.opacity(
                    Double(0.28 + interactionState.backgroundDimming)
                ),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .ignoresSafeArea(edges: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .zIndex(9)
    }
}

@available(iOS 16.0, *)
private struct PPPetAdWorldSheetSurface: View {
    @ObservedObject var interactionState: PPPetAdViewerInteractionState
    let topColor: UIColor?
    let middleColor: UIColor?
    let bottomColor: UIColor?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: interactionState.sheetRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: interactionState.sheetRadius,
            style: .continuous
        )

        ZStack(alignment: .top) {
            shape.fill(Color.ppBackground)

            LinearGradient(
                colors: [
                    sampled(topColor, opacity: 0.13),
                    sampled(middleColor, opacity: 0.07),
                    sampled(bottomColor, opacity: 0.025),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 260)

            LinearGradient(
                colors: [
                    Color.ppCard.opacity(colorScheme == .dark ? 0.30 : 0.44),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)
        }
        .clipShape(shape)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.ppTextPrimary.opacity(
                        Double(
                            colorSchemeContrast == .increased
                                ? interactionState.sheetEdgeOpacity
                                : interactionState.sheetEdgeOpacity * 0.58
                        )
                    ),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: colorSchemeContrast == .increased ? 1.5 : 1)
            .padding(.horizontal, interactionState.sheetRadius)
        }
        .shadow(
            color: Color.black.opacity(
                colorScheme == .dark ? 0.22 : 0.07
            ),
            radius: 14,
            x: 0,
            y: -4
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func sampled(_ color: UIColor?, opacity: CGFloat) -> Color {
        guard let color else { return .clear }
        return Color(uiColor: color).opacity(Double(opacity))
    }
}

@available(iOS 16.0, *)
private struct PPPetAdDockElevationModifier: ViewModifier {
    @ObservedObject var interactionState: PPPetAdViewerInteractionState
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: Color.black.opacity(
                Double(
                    (colorScheme == .dark ? 0.18 : 0.07)
                        * interactionState.dockElevation
                )
            ),
            radius: PPSpace.sm + (PPSpace.sm * interactionState.dockElevation),
            x: 0,
            y: PPSpace.xs
        )
    }
}
