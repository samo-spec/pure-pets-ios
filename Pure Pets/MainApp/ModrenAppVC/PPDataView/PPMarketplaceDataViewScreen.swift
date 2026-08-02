import SwiftUI
import UIKit

@available(iOS 15.0, *)
struct PPMarketplaceDataViewScreen: View {
    @ObservedObject var store: PPMarketplaceDataViewStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var hasPresentedEntrance = false
    @State private var dockIsPinned = false
    @GestureState private var scrollGestureIsActive = false
    @State private var bridgeScrollInteractionIsActive = false
    @State private var measuredScrollContentHeight: CGFloat = 0
    @State private var retainedScrollContentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 0,
                        pinnedViews: [.sectionHeaders]
                    ) {
                            PPMarketplaceHero(
                                store: store,
                                availableWidth: proxy.size.width,
                                showsBackControl: !dockIsPinned,
                                currentFlowProgress: entranceProgress
                            )
                            .zIndex(contextForegroundZIndex)

                            PPMarketplaceTaxonomyCurrent(store: store)
                                .padding(.horizontal, horizontalContentInset)
                                .padding(.vertical, PPSpace.sm)
                                .ppMarketplaceEntrance(
                                    isPresented: hasPresentedEntrance,
                                    layer: .context
                                )
                                .zIndex(contextForegroundZIndex)
                                .allowsHitTesting(!store.isReplacingContext)

                            Section {
                                PPMarketplaceContent(
                                    store: store,
                                    availableWidth: proxy.size.width,
                                    availableHeight: proxy.size.height
                                )
                                .padding(.horizontal, horizontalContentInset)
                                .padding(.top, PPSpace.md)
                                .opacity(store.isReplacingContext ? 0.46 : 1)
                                .allowsHitTesting(!store.isReplacingContext)
                                .accessibilityHidden(store.isReplacingContext)
                                .overlay(alignment: .top) {
                                    if store.isReplacingContext,
                                       !store.records.isEmpty {
                                        PPMarketplaceReplacementStatus(
                                            accent: store.accentColor
                                        )
                                        .padding(.top, PPSpace.md)
                                    }
                                }
                                .ppMarketplaceEntrance(
                                    isPresented: hasPresentedEntrance,
                                    layer: .results
                                )

                                Color.clear
                                    .frame(
                                        height: resolvedBottomBreathingRoom(
                                            availableHeight: proxy.size.height
                                        )
                                    )
                                    .accessibilityHidden(true)
                            } header: {
                                PPMarketplaceCurrentDock(
                                    store: store,
                                    showsPinnedBackControl: dockIsPinned,
                                    statusBarHeight: proxy.safeAreaInsets.top
                                )
                                .ppMarketplaceEntrance(
                                    isPresented: hasPresentedEntrance,
                                    layer: .controls
                                )
                                .background {
                                    PPMarketplaceScrollStabilityController(
                                        isReplacingContext: store.isReplacingContext,
                                        contentRevision: store.contentRevision,
                                        naturalContentHeight: measuredScrollContentHeight,
                                        onRestorationCompleted: {
                                            guard !store.isReplacingContext else {
                                                return
                                            }
                                            retainedScrollContentHeight = 0
                                        }
                                    )
                                    .accessibilityHidden(true)
                                }
                                .background {
                                    GeometryReader { dockProxy in
                                        Color.clear.preference(
                                            key: PPMarketplaceDockMinYPreferenceKey.self,
                                            value: dockProxy.frame(
                                                in: .named("pp.marketplace.scroll")
                                            ).minY
                                        )
                                    }
                                }
                            }
                        }
                        .background {
                            GeometryReader { contentProxy in
                                Color.clear.preference(
                                    key: PPMarketplaceScrollContentHeightPreferenceKey.self,
                                    value: contentProxy.size.height
                                )
                            }
                        }
                        .frame(
                            minHeight: retainedScrollContentHeight,
                            alignment: .top
                        )
                        .padding(.bottom, PPSpace.sm)
                    }
                    .coordinateSpace(name: "pp.marketplace.scroll")
                    .onPreferenceChange(
                        PPMarketplaceDockMinYPreferenceKey.self
                    ) { minY in
                        let nextPinned = minY <= 1
                        guard dockIsPinned != nextPinned else { return }
                        DispatchQueue.main.async {
                            guard dockIsPinned != nextPinned else { return }
                            dockIsPinned = nextPinned
                        }
                    }
                    .onPreferenceChange(
                        PPMarketplaceScrollContentHeightPreferenceKey.self
                    ) { height in
                        measuredScrollContentHeight = max(0, height)
                        if store.isReplacingContext {
                            retainedScrollContentHeight = max(
                                retainedScrollContentHeight,
                                measuredScrollContentHeight
                            )
                        }
                    }
                    .onChange(of: store.isReplacingContext) { isReplacing in
                        if isReplacing {
                            retainedScrollContentHeight = max(
                                retainedScrollContentHeight,
                                measuredScrollContentHeight
                            )
                        } else if !dockIsPinned {
                            retainedScrollContentHeight = 0
                        }
                    }
                    .onChange(of: dockIsPinned) { isPinned in
                        if !isPinned && !store.isReplacingContext {
                            retainedScrollContentHeight = 0
                        }
                    }
                    .refreshable {
                        await store.refresh()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 3)
                            .updating($scrollGestureIsActive) { _, isActive, _ in
                                isActive = true
                            }
                    )
                    .onChange(of: scrollGestureIsActive) { isActive in
                        updateBridgeScrollInteraction(isActive: isActive)
                    }
            }
        }
        .background {
            PPMarketplaceAtmosphere(
                accent: store.accentColor,
                usesBrandAccent: store.usesBrandAccent
            )
                .ignoresSafeArea()
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
        .sheet(
            item: $store.activeSheet,
            onDismiss: store.sheetDidDismiss
        ) { sheet in
            switch sheet {
            case .filters:
                PPMarketplaceFilterSheet(store: store)
            case .providers:
                PPMarketplaceProviderSheet(store: store)
            }
        }
        .overlay(alignment: .top) {
            if let message = store.updateErrorMessage {
                PPMarketplaceUpdateErrorBanner(
                    message: message,
                    retry: store.retry,
                    dismiss: store.dismissUpdateError
                )
                .padding(.horizontal, horizontalContentInset)
                .padding(.top, PPSpace.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(contentMotionIsDisabled ? nil : .easeInOut(duration: 0.20), value: store.updateErrorMessage)
        .animation(contentMotionIsDisabled ? nil : .easeInOut(duration: 0.16), value: dockIsPinned)
        .task {
            await presentEntranceIfNeeded()
        }
        .onDisappear {
            endScrollGestureIfNeeded()
            retainedScrollContentHeight = 0
        }
    }

    private var horizontalContentInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }

    private var contextForegroundZIndex: Double {
        5
    }

    private func endScrollGestureIfNeeded() {
        guard bridgeScrollInteractionIsActive else { return }
        bridgeScrollInteractionIsActive = false
        store.bridge.userDidEndScrolling()
    }

    private func updateBridgeScrollInteraction(isActive: Bool) {
        guard bridgeScrollInteractionIsActive != isActive else { return }
        bridgeScrollInteractionIsActive = isActive
        if isActive {
            store.bridge.userDidBeginScrolling()
        } else {
            store.bridge.userDidEndScrolling()
        }
    }

    private func resolvedBottomBreathingRoom(
        availableHeight: CGFloat
    ) -> CGFloat {
        let base = max(
            store.bottomClearance + PPSpace.lg,
            dynamicTypeSize.isAccessibilitySize ? 128 : 96
        )
        switch store.loadState {
        case .empty, .offline, .failed, .loading, .content:
            return base
        }
    }

    private var entranceIsResolved: Bool {
        entranceMotionIsDisabled || hasPresentedEntrance
    }

    private var entranceMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    private var contentMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    private var entranceProgress: CGFloat {
        entranceIsResolved ? 1 : 0
    }

    @MainActor
    private func presentEntranceIfNeeded() async {
        guard !hasPresentedEntrance else { return }

        if !entranceMotionIsDisabled {
            do {
                try await Task.sleep(nanoseconds: 24_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
        }

        if entranceMotionIsDisabled {
            hasPresentedEntrance = true
        } else {
            withAnimation(PPMarketplaceEntranceMotion.current) {
                hasPresentedEntrance = true
            }
        }
    }
}

@available(iOS 15.0, *)
private enum PPMarketplaceEntranceMotion {
    static let current = Animation.timingCurve(
        0.16,
        1,
        0.30,
        1,
        duration: 0.42
    )
    static let context = Animation.timingCurve(
        0.16,
        1,
        0.30,
        1,
        duration: 0.28
    ).delay(0.05)
    static let controls = Animation.timingCurve(
        0.16,
        1,
        0.30,
        1,
        duration: 0.28
    ).delay(0.10)
    static let results = Animation.timingCurve(
        0.16,
        1,
        0.30,
        1,
        duration: 0.28
    ).delay(0.15)
}

@available(iOS 15.0, *)
private enum PPMarketplaceEntranceLayer {
    case context
    case controls
    case results

    var offset: CGFloat {
        switch self {
        case .context: return 12
        case .controls: return 10
        case .results: return 14
        }
    }

    var animation: Animation {
        switch self {
        case .context: return PPMarketplaceEntranceMotion.context
        case .controls: return PPMarketplaceEntranceMotion.controls
        case .results: return PPMarketplaceEntranceMotion.results
        }
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceEntranceModifier: ViewModifier {
    let isPresented: Bool
    let layer: PPMarketplaceEntranceLayer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    func body(content: Content) -> some View {
        let isResolved = entranceMotionIsDisabled || isPresented
        content
            .opacity(isResolved ? 1 : 0)
            .offset(y: isResolved ? 0 : layer.offset)
            .allowsHitTesting(isResolved)
            .accessibilityHidden(!isResolved)
            .animation(entranceMotionIsDisabled ? nil : layer.animation, value: isPresented)
    }

    private var entranceMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }
}

@available(iOS 15.0, *)
private extension View {
    func ppMarketplaceEntrance(
        isPresented: Bool,
        layer: PPMarketplaceEntranceLayer
    ) -> some View {
        modifier(
            PPMarketplaceEntranceModifier(
                isPresented: isPresented,
                layer: layer
            )
        )
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceDockMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceScrollContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Owns the brief Species/Breed handoff from the pinned dock, which remains
/// realized at deep offsets. The old SwiftUI height prevents an early clamp;
/// after the replacement lays out, this coordinator restores the logical dock
/// position, releases the floor, and clamps only when the new result set is
/// physically too short to preserve the previous offset.
@available(iOS 15.0, *)
private struct PPMarketplaceScrollStabilityController: UIViewRepresentable {
    let isReplacingContext: Bool
    let contentRevision: Int
    let naturalContentHeight: CGFloat
    let onRestorationCompleted: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ marker: UIView, context: Context) {
        context.coordinator.update(
            anchorView: marker,
            isReplacingContext: isReplacingContext,
            contentRevision: contentRevision,
            naturalContentHeight: naturalContentHeight,
            onRestorationCompleted: onRestorationCompleted
        )
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.dismantle()
    }

    final class Coordinator {
        private struct Capture {
            let offsetY: CGFloat
            let anchorContentY: CGFloat
        }

        private weak var scrollView: UIScrollView?
        private var capture: Capture?
        private var wasReplacingContext = false
        private var lastContentRevision: Int?
        private var restorationToken = 0
        private var previousScrollEnabled = true
        private var ownsScrollLock = false
        private var isDismantled = false
        private var latestNaturalContentHeight: CGFloat = 0
        private var latestRestorationCompletion: (() -> Void)?

        func update(
            anchorView: UIView,
            isReplacingContext: Bool,
            contentRevision: Int,
            naturalContentHeight: CGFloat,
            onRestorationCompleted: @escaping () -> Void
        ) {
            isDismantled = false
            latestNaturalContentHeight = max(0, naturalContentHeight)
            latestRestorationCompletion = onRestorationCompleted

            DispatchQueue.main.async { [weak self, weak anchorView] in
                guard let self,
                      !self.isDismantled,
                      let anchorView,
                      anchorView.window != nil,
                      let scrollView = self.enclosingScrollView(for: anchorView) else {
                    return
                }
                self.bind(to: scrollView)

                if isReplacingContext {
                    if !self.wasReplacingContext {
                        self.restorationToken &+= 1
                        self.capture = self.makeCapture(
                            anchorView: anchorView,
                            scrollView: scrollView
                        )
                        self.lockScrollView(scrollView)
                    }
                    if self.capture == nil {
                        self.capture = self.makeCapture(
                            anchorView: anchorView,
                            scrollView: scrollView
                        )
                    }
                    self.wasReplacingContext = true
                } else {
                    let revisionChanged = self.lastContentRevision.map {
                        $0 != contentRevision
                    } ?? false
                    if (self.wasReplacingContext || revisionChanged),
                       let capture = self.capture {
                        self.scheduleRestoration(
                            capture,
                            anchorView: anchorView,
                            scrollView: scrollView
                        )
                    } else if self.wasReplacingContext {
                        self.unlockScrollViewIfNeeded()
                    }
                    self.wasReplacingContext = false
                }
                self.lastContentRevision = contentRevision
            }
        }

        func dismantle() {
            isDismantled = true
            restorationToken &+= 1
            unlockScrollViewIfNeeded()
            capture = nil
            latestRestorationCompletion = nil
            scrollView = nil
        }

        private func bind(to scrollView: UIScrollView) {
            guard self.scrollView !== scrollView else { return }
            unlockScrollViewIfNeeded()
            self.scrollView = scrollView
            capture = nil
            wasReplacingContext = false
            lastContentRevision = nil
        }

        private func enclosingScrollView(for view: UIView) -> UIScrollView? {
            var candidate = view.superview
            while let current = candidate {
                if let scrollView = current as? UIScrollView {
                    return scrollView
                }
                candidate = current.superview
            }
            return nil
        }

        private func makeCapture(
            anchorView: UIView,
            scrollView: UIScrollView
        ) -> Capture {
            Capture(
                offsetY: scrollView.contentOffset.y,
                anchorContentY: anchorContentY(
                    anchorView: anchorView,
                    scrollView: scrollView
                )
            )
        }

        private func anchorContentY(
            anchorView: UIView,
            scrollView: UIScrollView
        ) -> CGFloat {
            anchorView.convert(.zero, to: scrollView).y
        }

        private func lockScrollView(_ scrollView: UIScrollView) {
            guard !ownsScrollLock else { return }
            previousScrollEnabled = scrollView.isScrollEnabled
            // Selecting a taxonomy control is an explicit context handoff.
            // Stop any residual momentum before capturing the stable offset so
            // the completed payload cannot race deceleration or AX scrolling.
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
            scrollView.isScrollEnabled = false
            ownsScrollLock = true
        }

        private func unlockScrollViewIfNeeded() {
            guard ownsScrollLock else { return }
            scrollView?.isScrollEnabled = previousScrollEnabled
            ownsScrollLock = false
        }

        private func scheduleRestoration(
            _ capture: Capture,
            anchorView: UIView,
            scrollView: UIScrollView
        ) {
            restorationToken &+= 1
            let token = restorationToken
            restore(
                capture,
                anchorView: anchorView,
                scrollView: scrollView,
                token: token,
                remainingPasses: 2
            )
        }

        private func restore(
            _ capture: Capture,
            anchorView: UIView,
            scrollView: UIScrollView,
            token: Int,
            remainingPasses: Int
        ) {
            DispatchQueue.main.async { [weak self, weak anchorView, weak scrollView] in
                guard let self,
                      !self.isDismantled,
                      let anchorView,
                      anchorView.window != nil,
                      let scrollView,
                      self.restorationToken == token else {
                    return
                }
                let anchorDelta = self.anchorContentY(
                    anchorView: anchorView,
                    scrollView: scrollView
                ) - capture.anchorContentY
                let minimumY = -scrollView.adjustedContentInset.top
                let naturalMaximumY = max(
                    minimumY,
                    self.latestNaturalContentHeight - scrollView.bounds.height +
                        scrollView.adjustedContentInset.bottom
                )
                let desiredY = min(
                    max(minimumY, capture.offsetY + anchorDelta),
                    naturalMaximumY
                )
                UIView.performWithoutAnimation {
                    scrollView.setContentOffset(
                        CGPoint(x: scrollView.contentOffset.x, y: desiredY),
                        animated: false
                    )
                    scrollView.layoutIfNeeded()
                }

                if remainingPasses > 1 {
                    self.restore(
                        capture,
                        anchorView: anchorView,
                        scrollView: scrollView,
                        token: token,
                        remainingPasses: remainingPasses - 1
                    )
                } else {
                    self.releaseGeometryFloor(
                        desiredY: desiredY,
                        scrollView: scrollView,
                        token: token
                    )
                }
            }
        }

        private func releaseGeometryFloor(
            desiredY: CGFloat,
            scrollView: UIScrollView,
            token: Int
        ) {
            latestRestorationCompletion?()
            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self,
                      !self.isDismantled,
                      let scrollView,
                      self.restorationToken == token else {
                    return
                }
                scrollView.layoutIfNeeded()
                let minimumY = -scrollView.adjustedContentInset.top
                let maximumY = max(
                    minimumY,
                    scrollView.contentSize.height - scrollView.bounds.height +
                        scrollView.adjustedContentInset.bottom
                )
                let resolvedY = min(max(minimumY, desiredY), maximumY)
                UIView.performWithoutAnimation {
                    scrollView.setContentOffset(
                        CGPoint(x: scrollView.contentOffset.x, y: resolvedY),
                        animated: false
                    )
                }
                self.capture = nil
                self.unlockScrollViewIfNeeded()
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                }
            }
        }
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceReplacementStatus: View {
    let accent: UIColor

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            ProgressView()
                .tint(Color(uiColor: accent))
            Text(PPMarketplaceText.localized("marketplace_loading_title"))
                .font(HomeFont.bold(13))
                .foregroundStyle(Color.ppMarketplaceTextPrimary)
        }
        .padding(.horizontal, PPSpace.base)
        .frame(minHeight: 44)
        .background(
            .regularMaterial,
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    Color.ppMarketplaceSeparator.opacity(0.28),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            PPMarketplaceText.localized("marketplace_loading_title")
        )
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceContent: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            switch store.loadState {
            case .loading:
                PPMarketplaceLoadingState(layout: store.layout)

            case .content:
                content

            case .empty:
                PPMarketplaceEmptyState(
                    hasFilters: store.activeFilterCount > 0,
                    accent: store.accentColor,
                    clearAction: store.clearAllFilters,
                    retryAction: store.retry
                )

            case .offline(let message):
                PPMarketplaceRecoveryState(
                    kind: .offline,
                    message: message,
                    accent: store.accentColor,
                    retryAction: store.retry
                )

            case .failed(let message):
                PPMarketplaceRecoveryState(
                    kind: .failed,
                    message: message,
                    accent: store.accentColor,
                    retryAction: store.retry
                )
            }
        }
        // A viewport-tall results surface keeps the pinned Section header
        // alive while the bridge swaps a long grid for its loading/empty state.
        .frame(
            maxWidth: .infinity,
            minHeight: max(availableHeight, 1),
            alignment: .top
        )
    }

    @ViewBuilder
    private var content: some View {
        switch store.layout {
        case .compact:
            LazyVStack(spacing: PPSpace.md) {
                ForEach(store.records) { record in
                    PPMarketplaceUniversalCard(
                        record: record,
                        section: record.section,
                        layout: .compact,
                        bridge: store.bridge
                    )
                    .onAppear {
                        store.fetchNextPageIfNeeded(for: record)
                    }
                }
            }

        case .showcase:
            LazyVStack(spacing: PPSpace.lg) {
                ForEach(store.records) { record in
                    PPMarketplaceUniversalCard(
                        record: record,
                        section: record.section,
                        layout: .showcase,
                        bridge: store.bridge
                    )
                    .onAppear {
                        store.fetchNextPageIfNeeded(for: record)
                    }
                }
            }

        case .mosaic:
            VStack(alignment: .leading, spacing: PPSpace.base) {
                LazyVGrid(columns: mosaicColumns, spacing: PPSpace.base) {
                    ForEach(store.records) { record in
                        PPMarketplaceUniversalCard(
                            record: record,
                            section: record.section,
                            layout: .mosaic,
                            bridge: store.bridge
                        )
                        .onAppear {
                            store.fetchNextPageIfNeeded(for: record)
                        }
                    }
                }
            }

        case .focus:
            VStack(alignment: .leading, spacing: PPSpace.base) {
                PPMarketplaceFocusCarousel(
                    records: store.records,
                    bridge: store.bridge,
                    loadMore: store.fetchNextPageIfNeeded
                )
            }
        }
    }

    private var mosaicColumns: [GridItem] {
        let usableWidth = max(0, availableWidth - horizontalOuterInsets)
        let minimumCardWidth: CGFloat = dynamicTypeSize.isAccessibilitySize
            ? usableWidth
            : 168
        let proposedCount = Int(
            (usableWidth + PPSpace.base) / (minimumCardWidth + PPSpace.base)
        )
        let maximumCount = horizontalSizeClass == .regular ? 4 : 2
        let count = max(1, min(maximumCount, proposedCount))
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.base),
            count: count
        )
    }

    private var horizontalOuterInsets: CGFloat {
        let perSide = horizontalSizeClass == .regular
            ? PPSpace.xxl
            : PPSpace.screenMargin
        return perSide * 2
    }
}
