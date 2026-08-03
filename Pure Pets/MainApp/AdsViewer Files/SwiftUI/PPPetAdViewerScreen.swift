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
    @StateObject private var interactionState =
        PPPetAdViewerInteractionState()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var hasAppeared = false
    @State private var contactDockHeight: CGFloat = 0
    @State private var hostSafeAreaInsets: UIEdgeInsets = .zero

    private let repository: PPPetAdViewerRepository
    private let hostActions: PPPetAdViewerHostActions
    private let contactDockBottomInset = PPSpace.base
    private let showsHorizontalThumbnailRail = false

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
            let insets = resolvedChromeInsets(proxy)

            ZStack {
                PPPetAdViewerBackground()

                screenContent(proxy: proxy)
                .id(screenStateIdentity)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(
                            with: .scale(scale: 0.994)
                        )
                )

                navigationBar(topInset: insets.top)

                navigationLink

                bottomFadeOverlay

                contactDock
                    .zIndex(15)

                toastOverlay
                    .zIndex(20)
            }
            .animation(screenStateAnimation, value: screenStateIdentity)
            .animation(navigationAnimation, value: store.ppShowsContactDock)
        }
        .ignoresSafeArea(.all, edges: [.top, .bottom])
        .background {
            PPPetAdSafeAreaReader(insets: $hostSafeAreaInsets)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .navigationBarHidden(true)
        .fullScreenCover(
            isPresented: Binding(
                get: { store.isMediaViewerPresented },
                set: { store.isMediaViewerPresented = $0 }
            )
        ) {
            PPMediaViewer(
                items: PPMediaItem.from(
                    petAdMedia: store.snapshot.media
                ),
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
                PPPetAdLocalization.text(
                    "Cancel",
                    fallback: "Cancel"
                ),
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
        }
        .task {
            await presentEntranceIfNeeded()
        }
        .onChange(of: languageCode) { _ in
            store.refreshLocalization()
        }
        .onChange(of: authenticationRevision) { _ in
            store.refreshAuthenticationState()
        }
        .accessibilityAction(.escape, handleBack)
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

    private func content(proxy: GeometryProxy) -> some View {
        let heroHeight = resolvedHeroHeight(for: proxy.size)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                GeometryReader { heroProxy in
                    let minimumY = heroProxy.frame(
                        in: .named(
                            PPPetAdViewerCoordinateSpace.trustJourney
                        )
                    ).minY
                    let offset = -minimumY
                    let rawProgress = max(
                        0,
                        min(
                            offset / max(heroHeight * 0.54, 1),
                            1
                        )
                    )
                    let quantizedProgress =
                        (rawProgress * 120).rounded() / 120

                    PPPetAdTrustJourneyHero(
                        items: store.snapshot.media,
                        selection: Binding(
                            get: { store.selectedMediaIndex },
                            set: { store.selectedMediaIndex = $0 }
                        ),
                        interactionState: interactionState,
                        height: heroHeight,
                        scrollOffset: offset,
                        onOpen: store.selectMedia(at:)
                    )
                    .preference(
                        key: PPPetAdScrollOffsetPreferenceKey.self,
                        value: quantizedProgress
                    )
                }
                .frame(height: heroHeight)

                VStack(spacing: 0) {
                    PPPetAdHeroContentBlend()
                        .overlay(alignment: .top) {
                            fadeThumbnailRail
                        }

                    PPPetAdTrustJourneyDetailsContent(
                        store: store,
                        hasAppeared: hasAppeared,
                        bottomClearance:
                            contactDockClearance
                            + PPSpace.xxxl
                    )
                }
                .padding(
                    .top,
                    -PPPetAdViewerLayoutMetrics
                        .trustJourneyContentBlendOverlap
                )
            }
        }
        .coordinateSpace(
            name: PPPetAdViewerCoordinateSpace.trustJourney
        )
        .refreshable {
            store.refresh()
        }
        .onPreferenceChange(
            PPPetAdScrollOffsetPreferenceKey.self
        ) { progress in
            interactionState.update(progress: progress)
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(
            reduceMotion || hasAppeared ? 1 : 1.012,
            anchor: .top
        )
        .animation(entranceAnimation, value: hasAppeared)
        .background(Color.ppBackground)
    }

    @ViewBuilder
    private var fadeThumbnailRail: some View {
        if showsHorizontalThumbnailRail && store.snapshot.media.count > 1 {
            GeometryReader { railProxy in
                PPPetAdThumbnailRail(
                    items: store.snapshot.media,
                    selection: Binding(
                        get: { store.selectedMediaIndex },
                        set: { store.selectedMediaIndex = $0 }
                    ),
                    axis: .horizontal,
                    maximumLength: min(railProxy.size.width, 520)
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: PPPetAdThumbnailRail.thickness)
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.xl)
            .ppPetAdEntrance(
                isPresented: hasAppeared,
                delayIndex: 0
            )
        }
    }

    private func navigationBar(topInset: CGFloat) -> some View {
        PPPetAdViewerNavigationBar(
            interactionState: interactionState,
            topInset: topInset,
            canShare: store.screenState == .content,
            canReport:
                store.screenState == .content && store.canReport,
            isReportWorking: store.reportState == .working,
            onBack: handleBack,
            onShare: store.share,
            onReport: store.requestReport
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .zIndex(10)
    }

    @ViewBuilder
    private var contactDock: some View {
        if store.ppShowsContactDock {
            PPPetAdContactDock(store: store)
                .background {
                    GeometryReader { dockProxy in
                        Color.clear.preference(
                            key: PPPetAdContactDockHeightPreferenceKey.self,
                            value: dockProxy.size.height
                        )
                    }
                }
                .padding(.horizontal, PPSpace.base)
                .padding(.bottom, contactDockBottomInset)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.container, edges: .bottom)
                .opacity(hasAppeared ? 1 : 0)
                .allowsHitTesting(hasAppeared)
                .accessibilityHidden(!hasAppeared)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
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

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = store.toastMessage {
            PPPetAdToastView(message: message)
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(
                    .bottom,
                    max(contactDockClearance, PPSpace.lg)
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
        }
    }

    private var navigationLink: some View {
        NavigationLink(
            isActive: Binding(
                get: { store.isRelatedViewerPresented },
                set: { store.isRelatedViewerPresented = $0 }
            )
        ) {
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

    private var bottomFadeOverlay: some View {
        let height =
            contactDockHeight
            + contactDockBottomInset
            + PPSpace.xxxl

        return LinearGradient(
            colors: [
                Color.clear,
                Color.ppBackground.opacity(0.58),
                Color.ppBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .ignoresSafeArea(edges: .bottom)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .opacity(hasAppeared && store.ppShowsContactDock ? 1 : 0)
        .zIndex(8)
    }

    private func handleBack() {
        if isRoot {
            store.close()
        } else {
            dismiss()
        }
    }

    @MainActor
    private func presentEntranceIfNeeded() async {
        guard !hasAppeared else { return }
        if !reduceMotion {
            do {
                try await Task.sleep(nanoseconds: 24_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
        }
        hasAppeared = true
    }

    private func resolvedHeroHeight(for size: CGSize) -> CGFloat {
        if size.height < 600 {
            return max(340, size.height * 0.82)
        }
        return min(max(size.height * 0.62, 500), 640)
    }

    private var contactDockClearance: CGFloat {
        guard store.ppShowsContactDock else { return 0 }
        let fallback = dynamicTypeSize.isAccessibilitySize ? 210.0 : 104.0
        return max(fallback, contactDockHeight + PPSpace.base)
    }

    private var screenStateIdentity: Int {
        switch store.screenState {
        case .loading: return 0
        case .content: return 1
        case .empty: return 2
        case .offline: return 3
        case .failed: return 4
        }
    }

    private var screenStateAnimation: Animation? {
        reduceMotion ? nil : PPPetAdViewerMotion.state
    }

    private var navigationAnimation: Animation? {
        reduceMotion ? nil : PPPetAdViewerMotion.navigation
    }

    private var entranceAnimation: Animation? {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : PPPetAdViewerMotion.heroEntrance
    }

    private func resolvedChromeInsets(
        _ proxy: GeometryProxy
    ) -> UIEdgeInsets {
        let proxyLeftInset = layoutDirection == .rightToLeft
            ? proxy.safeAreaInsets.trailing
            : proxy.safeAreaInsets.leading
        let proxyRightInset = layoutDirection == .rightToLeft
            ? proxy.safeAreaInsets.leading
            : proxy.safeAreaInsets.trailing
        let hasMeasuredInsets =
            hostSafeAreaInsets.top > 1
            || hostSafeAreaInsets.bottom > 1
            || proxy.safeAreaInsets.top > 1
            || proxy.safeAreaInsets.bottom > 1
        let fallback = hasMeasuredInsets
            ? UIEdgeInsets.zero
            : PPPetAdSafeAreaReader.activeWindowInsets()

        return UIEdgeInsets(
            top: max(
                max(proxy.safeAreaInsets.top, hostSafeAreaInsets.top),
                max(fallback.top, 24)
            ),
            left: max(
                max(proxyLeftInset, hostSafeAreaInsets.left),
                fallback.left
            ),
            bottom: max(
                max(proxy.safeAreaInsets.bottom, hostSafeAreaInsets.bottom),
                fallback.bottom
            ),
            right: max(
                max(proxyRightInset, hostSafeAreaInsets.right),
                fallback.right
            )
        )
    }
}

private struct PPPetAdSafeAreaReader: UIViewRepresentable {
    @Binding var insets: UIEdgeInsets

    func makeUIView(context _: Context) -> ReaderView {
        let view = ReaderView()
        configure(view)
        return view
    }

    func updateUIView(_ view: ReaderView, context _: Context) {
        configure(view)
        view.publishInsetsIfNeeded()
    }

    static func dismantleUIView(_ view: ReaderView, coordinator _: ()) {
        view.onInsetsChanged = nil
    }

    static func activeWindowInsets() -> UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }

    private func configure(_ view: ReaderView) {
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.onInsetsChanged = { nextInsets in
            guard nextInsets != insets else { return }
            DispatchQueue.main.async {
                guard nextInsets != insets else { return }
                insets = nextInsets
            }
        }
    }

    final class ReaderView: UIView {
        var onInsetsChanged: ((UIEdgeInsets) -> Void)?
        private var lastInsets: UIEdgeInsets = .zero

        override func didMoveToWindow() {
            super.didMoveToWindow()
            publishInsetsIfNeeded()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            publishInsetsIfNeeded()
        }

        func publishInsetsIfNeeded() {
            guard safeAreaInsets != lastInsets else { return }
            lastInsets = safeAreaInsets
            onInsetsChanged?(safeAreaInsets)
        }
    }
}
