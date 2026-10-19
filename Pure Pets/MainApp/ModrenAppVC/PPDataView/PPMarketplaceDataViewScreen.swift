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
                                showsBackControl: !dockIsPinned
                            )
                            .ppMarketplaceEntrance(
                                isPresented: hasPresentedEntrance
                            )
                            .zIndex(contextForegroundZIndex)

                            Section {
                                PPMarketplaceContent(
                                    store: store,
                                    availableWidth: proxy.size.width,
                                    availableHeight: proxy.size.height
                                )
                                .padding(
                                    .horizontal,
                                    store.layout == .mosaic || store.layout == .pinterest
                                        ? PPMarketplaceContentGeometry.mosaicCellSpacing
                                        : horizontalContentInset
                                )
                                .padding(.top, PPSpace.md)
                                .opacity(store.isReplacingContext ? 0.46 : 1)
                                .animation(
                                    contentMotionIsDisabled
                                        ? nil
                                        : .easeOut(duration: 0.18),
                                    value: store.isReplacingContext
                                )
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
                                    isPresented: hasPresentedEntrance
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
                                    isPresented: hasPresentedEntrance
                                )
                                .background {
                                    PPMarketplaceScrollStabilityController(
                                        isReplacingContext: store.isReplacingContext,
                                        contentTransitionIntent: store.contentTransitionIntent,
                                        contentRevision: store.contentRevision,
                                        naturalContentHeight: measuredScrollContentHeight,
                                        onRestorationCompleted: {
                                            DispatchQueue.main.async {
                                                retainedScrollContentHeight = 0
                                            }
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
                                .anchorPreference(
                                    key: PPMarketplaceTopDeckBoundsPreferenceKey.self,
                                    value: .bounds
                                ) { $0 }
                                .zIndex(6)
                            }
                        }
                        .backgroundPreferenceValue(
                            PPMarketplaceTopDeckBoundsPreferenceKey.self
                        ) { dockBounds in
                            GeometryReader { deckProxy in
                                if let dockBounds {
                                    // Resolve the live dock boundary rather
                                    // than guessing a height: the same field
                                    // therefore spans the status area, hero,
                                    // sections and filters in every locale and
                                    // Dynamic Type size.
                                    let dockFrame = deckProxy[dockBounds]
                                    let safeAreaTop = max(0, proxy.safeAreaInsets.top)

                                    PPMarketplaceTopDeckBackground(
                                        accent: Color(uiColor: store.accentColor),
                                        isRightToLeft: store.isRightToLeft
                                    )
                                    .frame(
                                        width: deckProxy.size.width,
                                        height: max(0, dockFrame.maxY) + safeAreaTop
                                    )
                                    .offset(y: -safeAreaTop)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                }
                            }
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
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
                        dockIsPinned = nextPinned
                    }
                    .onPreferenceChange(
                        PPMarketplaceScrollContentHeightPreferenceKey.self
                    ) { height in
                        guard abs(measuredScrollContentHeight - height) > 0.5 else { return }
                        DispatchQueue.main.async {
                            measuredScrollContentHeight = max(0, height)
                            if store.isReplacingContext {
                                if case .refinement = store.contentTransitionIntent {
                                    retainedScrollContentHeight = max(
                                        retainedScrollContentHeight,
                                        min(measuredScrollContentHeight, proxy.size.height + 300)
                                    )
                                } else {
                                    retainedScrollContentHeight = 0
                                }
                            }
                        }
                    }
                    .onChange(of: store.isReplacingContext) { isReplacing in
                        if isReplacing {
                            if case .refinement = store.contentTransitionIntent {
                                retainedScrollContentHeight = max(
                                    retainedScrollContentHeight,
                                    min(measuredScrollContentHeight, proxy.size.height + 300)
                                )
                            } else {
                                retainedScrollContentHeight = 0
                            }
                        } else {
                            DispatchQueue.main.async {
                                retainedScrollContentHeight = 0
                            }
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
            .overlay(alignment: .bottom) {
                bottomNavigationFade
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
        .fullScreenCover(
            item: $store.activeSheet,
            onDismiss: store.sheetDidDismiss
        ) { sheet in
            switch sheet {
            case .category:
                PPMarketplaceCategorySheet(store: store)
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
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(contentMotionIsDisabled ? nil : .easeInOut(duration: 0.20), value: store.updateErrorMessage)
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
        if store.bottomClearance > 0 {
            let clearancePadding: CGFloat = dynamicTypeSize.isAccessibilitySize ? PPSpace.base : PPSpace.md
            return store.bottomClearance + clearancePadding
        } else {
            return dynamicTypeSize.isAccessibilitySize ? PPSpace.xl : PPSpace.base
        }
    }

    private var bottomNavigationFade: some View {
        GeometryReader { proxy in
            let extraFade: CGFloat = store.bottomClearance > 0 ? PPSpace.xs : 0
            let fadeHeight = max(
                store.bottomClearance,
                proxy.safeAreaInsets.bottom
            ) + extraFade

            if fadeHeight > 0 {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.ppBackground.opacity(0.12), location: 0.35),
                        .init(color: Color.ppBackground.opacity(0.55), location: 0.70),
                        .init(color: Color.ppBackground, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var entranceMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    private var contentMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    @MainActor
    private func presentEntranceIfNeeded() async {
        guard !hasPresentedEntrance else { return }

        if entranceMotionIsDisabled {
            hasPresentedEntrance = true
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                hasPresentedEntrance = true
            }
        }
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceEntranceModifier: ViewModifier {
    let isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    func body(content: Content) -> some View {
        let isResolved = entranceMotionIsDisabled || isPresented
        content
            .opacity(isResolved ? 1 : 0)
            .allowsHitTesting(isResolved)
            .accessibilityHidden(!isResolved)
            .animation(
                entranceMotionIsDisabled ? nil : .easeOut(duration: 0.18),
                value: isPresented
            )
    }

    private var entranceMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }
}

@available(iOS 15.0, *)
private extension View {
    func ppMarketplaceEntrance(
        isPresented: Bool
    ) -> some View {
        modifier(
            PPMarketplaceEntranceModifier(
                isPresented: isPresented
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
private struct PPMarketplaceTopDeckBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil

    static func reduce(
        value: inout Anchor<CGRect>?,
        nextValue: () -> Anchor<CGRect>?
    ) {
        value = value ?? nextValue()
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
    let contentTransitionIntent: PPMarketplaceContentTransitionIntent
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
            contentTransitionIntent: contentTransitionIntent,
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
        }

        private weak var scrollView: UIScrollView?
        private var contentSizeObservation: NSKeyValueObservation?
        private var capture: Capture?
        private var wasReplacingContext = false
        private var lastContentRevision: Int?
        private var lastHandledSectionChangeRevision: Int?
        private var restorationToken = 0
        private var previousScrollEnabled = true
        private var ownsScrollLock = false
        private var isDismantled = false
        private var latestNaturalContentHeight: CGFloat = 0
        private var latestRestorationCompletion: (() -> Void)?

        func update(
            anchorView: UIView,
            isReplacingContext: Bool,
            contentTransitionIntent: PPMarketplaceContentTransitionIntent,
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

                // If this is a major section change, reset scroll to top once
                // and clear any retained context offset.
                if case .sectionChange = contentTransitionIntent {
                    self.unlockScrollViewIfNeeded()
                    self.capture = nil
                    self.wasReplacingContext = false
                    if self.lastHandledSectionChangeRevision != contentRevision {
                        self.lastHandledSectionChangeRevision = contentRevision
                        let minimumY = -scrollView.adjustedContentInset.top
                        if abs(scrollView.contentOffset.y - minimumY) > 0.5 {
                            UIView.performWithoutAnimation {
                                scrollView.setContentOffset(
                                    CGPoint(x: scrollView.contentOffset.x, y: minimumY),
                                    animated: false
                                )
                            }
                        }
                    }
                    self.latestRestorationCompletion?()
                    return
                } else {
                    self.lastHandledSectionChangeRevision = nil
                }

                if isReplacingContext {
                    if !self.wasReplacingContext {
                        self.restorationToken &+= 1
                        self.capture = Capture(offsetY: scrollView.contentOffset.y)
                        self.lockScrollView(scrollView)
                    }
                    if self.capture == nil {
                        self.capture = Capture(offsetY: scrollView.contentOffset.y)
                    }
                    self.wasReplacingContext = true
                } else {
                    if self.wasReplacingContext, let capture = self.capture {
                        self.scheduleRestoration(
                            capture,
                            scrollView: scrollView
                        )
                    } else {
                        self.unlockScrollViewIfNeeded()
                        self.clampScrollOffset(in: scrollView)
                    }
                    self.wasReplacingContext = false
                }
                self.lastContentRevision = contentRevision
                self.clampScrollOffset(in: scrollView)
            }
        }

        func dismantle() {
            isDismantled = true
            restorationToken &+= 1
            contentSizeObservation?.invalidate()
            contentSizeObservation = nil
            unlockScrollViewIfNeeded()
            capture = nil
            latestRestorationCompletion = nil
            scrollView = nil
        }

        private func bind(to scrollView: UIScrollView) {
            guard self.scrollView !== scrollView else { return }
            unlockScrollViewIfNeeded()
            contentSizeObservation?.invalidate()
            self.scrollView = scrollView
            capture = nil
            wasReplacingContext = false
            lastContentRevision = nil
            lastHandledSectionChangeRevision = nil
            contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] sv, _ in
                DispatchQueue.main.async {
                    self?.clampScrollOffset(in: sv)
                }
            }
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

        private func lockScrollView(_ scrollView: UIScrollView) {
            guard !ownsScrollLock else { return }
            previousScrollEnabled = scrollView.isScrollEnabled
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
            scrollView: UIScrollView
        ) {
            restorationToken &+= 1
            let token = restorationToken
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
                let resolvedY = min(max(minimumY, capture.offsetY), maximumY)
                UIView.performWithoutAnimation {
                    scrollView.setContentOffset(
                        CGPoint(x: scrollView.contentOffset.x, y: resolvedY),
                        animated: false
                    )
                }
                self.capture = nil
                self.unlockScrollViewIfNeeded()
                self.clampScrollOffset(in: scrollView)
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                }
            }
        }

        private func clampScrollOffset(in scrollView: UIScrollView) {
            guard !ownsScrollLock, !scrollView.isDragging, !scrollView.isDecelerating else { return }
            let minimumY = -scrollView.adjustedContentInset.top
            let maximumY = max(
                minimumY,
                scrollView.contentSize.height - scrollView.bounds.height +
                    scrollView.adjustedContentInset.bottom
            )
            if scrollView.contentOffset.y > maximumY + 1.0 {
                UIView.performWithoutAnimation {
                    scrollView.setContentOffset(
                        CGPoint(x: scrollView.contentOffset.x, y: maximumY),
                        animated: false
                    )
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pinterestPartition = PPMarketplacePinterestPartition()

    var body: some View {
        Group {
            switch store.loadState {
            case .loading:
                PPMarketplaceLoadingState(
                    layout: store.layout,
                    availableWidth: availableWidth
                )
                .transition(stateTransition)

            case .content:
                content
                    .id("content-\(store.currentSection.rawValue)-\(store.contentRevision)")
                    .transition(contentTransition)

            case .empty:
                PPMarketplaceEmptyState(
                    hasFilters: store.activeFilterCount > 0,
                    accent: store.accentColor,
                    clearAction: store.clearAllFilters,
                    retryAction: store.retry
                )
                .transition(stateTransition)

            case .offline(let message):
                PPMarketplaceRecoveryState(
                    kind: .offline,
                    message: message,
                    accent: store.accentColor,
                    retryAction: store.retry
                )
                .transition(stateTransition)

            case .failed(let message):
                PPMarketplaceRecoveryState(
                    kind: .failed,
                    message: message,
                    accent: store.accentColor,
                    retryAction: store.retry
                )
                .transition(stateTransition)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: store.contentRevision)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: store.currentSection.rawValue)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: store.loadState)
        .frame(
            maxWidth: .infinity,
            minHeight: contentMinHeight,
            alignment: .top
        )
    }

    private var contentMinHeight: CGFloat? {
        if store.isReplacingContext && store.contentTransitionIntent == .refinement {
            // Retain surface height during active refinement transitions (e.g. breed/species)
            // to keep the pinned section header stable before new items settle.
            return max(availableHeight, 1)
        }
        // Allow content, skeleton loading, and empty states to size naturally
        // without creating an excessive blank void at the bottom of the screen.
        return nil
    }

    private var stateTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity
        )
    }

    @ViewBuilder
    private var content: some View {
        switch store.layout {
        case .pinterest:
            pinterestContent

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
            VStack(alignment: .leading, spacing: PPMarketplaceContentGeometry.mosaicLineSpacing) {
                LazyVGrid(
                    columns: mosaicColumns,
                    spacing: PPMarketplaceContentGeometry.mosaicLineSpacing
                ) {
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
        let count = PPMarketplaceContentGeometry.mosaicColumnCount(
            availableWidth: availableWidth,
            horizontalSizeClass: horizontalSizeClass,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
        return Array(
            repeating: GridItem(.flexible(), spacing: PPMarketplaceContentGeometry.mosaicCellSpacing),
            count: count
        )
    }

    private var pinterestColumnCount: Int {
        PPMarketplaceContentGeometry.mosaicColumnCount(
            availableWidth: availableWidth,
            horizontalSizeClass: horizontalSizeClass,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private var pinterestColumnWidth: CGFloat {
        let spacing = PPMarketplaceContentGeometry.mosaicCellSpacing
        let usableWidth = max(1, availableWidth - spacing * 2)
        return max(1, (usableWidth - CGFloat(pinterestColumnCount - 1) * spacing) / CGFloat(pinterestColumnCount))
    }

    private var pinterestContent: some View {
        let columnWidth = pinterestColumnWidth
        let columns = pinterestPartition.columns(
            records: store.records,
            count: pinterestColumnCount,
            width: columnWidth,
            context: "\(store.currentSection.rawValue)|\(store.currentMainKindID)|\(store.currentSubKindID)|\(pinterestContentSizeCategory.rawValue)|\(Language.currentLanguageCode() ?? "en")",
            height: { record in pinterestHeight(for: record, width: columnWidth) }
        )
        return HStack(alignment: .top, spacing: PPMarketplaceContentGeometry.mosaicCellSpacing) {
            ForEach(columns.indices, id: \.self) { column in
                LazyVStack(spacing: PPMarketplaceContentGeometry.mosaicLineSpacing) {
                    ForEach(columns[column]) { item in
                        PPMarketplaceUniversalCard(
                            record: item.record,
                            section: item.record.section,
                            layout: .pinterest,
                            bridge: store.bridge
                        )
                        .accessibilitySortPriority(-Double(item.sourceIndex))
                        .onAppear {
                            store.fetchNextPageIfNeeded(for: item.record)
                        }
                    }
                }
                .frame(width: columnWidth, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func pinterestHeight(for record: PPMarketplaceItemRecord, width: CGFloat) -> CGFloat {
        if #available(iOS 16.0, *), record.section == .ads || record.section == .food || record.section == .accessories {
            return PPUniversalCardHostingCell.discoveryFittingHeight(
                for: record.viewModel,
                width: width,
                contentSizeCategory: pinterestContentSizeCategory.rawValue,
                dataViewPresentation: true
            )
        }
        // iOS 15 keeps its existing compatibility renderer. This deterministic
        // estimate only chooses a column; it never fixes or truncates card height.
        return width + (dynamicTypeSize.isAccessibilitySize ? 320 : 160)
    }

    private var pinterestContentSizeCategory: UIContentSizeCategory {
        switch dynamicTypeSize {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

@available(iOS 15.0, *)
private struct PPMarketplacePinterestItem: Identifiable {
    let record: PPMarketplaceItemRecord
    let sourceIndex: Int
    var id: String { record.id }
}

/// Layout bookkeeping retains existing columns on append and data refresh.
/// A reordered/filtered set or changed width/type/context starts a fresh pack.
/// It does not publish state or own product/navigation behavior.
@available(iOS 15.0, *)
private final class PPMarketplacePinterestPartition {
    private var geometryKey = ""
    private var recordIDs: [String] = []
    private var assignments: [String: Int] = [:]

    func columns(
        records: [PPMarketplaceItemRecord],
        count: Int,
        width: CGFloat,
        context: String,
        height: (PPMarketplaceItemRecord) -> CGFloat
    ) -> [[PPMarketplacePinterestItem]] {
        let key = "\(count)|\(width)|\(context)"
        let incomingIDs = records.map(\.id)
        let extendsCurrentRecords = incomingIDs.count >= recordIDs.count &&
            Array(incomingIDs.prefix(recordIDs.count)) == recordIDs
        if geometryKey != key || !extendsCurrentRecords {
            assignments.removeAll(keepingCapacity: true)
        }
        geometryKey = key
        recordIDs = incomingIDs

        var columns = Array(repeating: [PPMarketplacePinterestItem](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)
        for (sourceIndex, record) in records.enumerated() {
            let measuredHeight = height(record)
            let safeHeight = measuredHeight.isFinite && measuredHeight > 0 ? measuredHeight : width + 160
            let column = assignments[record.id] ?? heights.indices.min {
                heights[$0] < heights[$1]
            } ?? 0
            assignments[record.id] = column
            columns[column].append(PPMarketplacePinterestItem(record: record, sourceIndex: sourceIndex))
            heights[column] += safeHeight + PPMarketplaceContentGeometry.mosaicLineSpacing
        }
        return columns
    }
}
