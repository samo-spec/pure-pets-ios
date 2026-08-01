import SwiftUI
import UIKit

private struct PPAccessoryDecisionBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = max(value, nextValue())
    }
}



@available(iOS 16.0, *)
struct PPAccessoryViewerScreen: View {
    @StateObject var store: PPAccessoryViewerStore

    @State private var heroResolved = false
    @State private var identityResolved = false
    @State private var cardsResolved = false
    @State private var actionResolved = false
    @State private var didRunEntrance = false
    @State private var showsNavigationTitlePill = false
    @State private var decisionBarHeight: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let bottomScreenSpacing = PPSpace.base

    var body: some View {
        NavigationStack {
            screenBody
                .toolbar(.hidden, for: .navigationBar)
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .environment(
            \.layoutDirection,
            PPAccessoryViewerLegacyBridge.isRTL()
                ? .rightToLeft
                : .leftToRight
        )
        .task {
            await store.load()
        }
        .onChange(of: store.phase) { phase in
            if phase == .loaded {
                runEntranceIfNeeded()
            }
        }
    }

    private var screenBody: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                PPAccessoryBeachCanvas()

                phaseContent(proxy: proxy)
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
        }
    }

    @ViewBuilder
    private func phaseContent(proxy: GeometryProxy) -> some View {
        switch store.phase {
        case .loading:
            PPAccessoryViewerLoadingState(
                topInset: topChromeInset(proxy),
                compact: proxy.size.width < 700 ||
                    dynamicTypeSize.isAccessibilitySize,
                bottomInset: bottomScreenSpacing
            )
        case let .failed(message):
            PPAccessoryViewerErrorState(
                message: message,
                retry: store.retry,
                close: store.close
            )
        case .loaded:
            if let snapshot = store.snapshot {
                loaded(snapshot: snapshot, proxy: proxy)
            } else {
                PPAccessoryViewerErrorState(
                    message: PPAccessoryViewerL10n.text(
                        "accessory_view_unavailable_message"
                    ),
                    retry: store.retry,
                    close: store.close
                )
            }
        }
    }

    private func loaded(
        snapshot: PPAccessoryViewerSnapshot,
        proxy: GeometryProxy
    ) -> some View {
        let contentWidth = min(proxy.size.width, 900)
        let compact = contentWidth < 700 || dynamicTypeSize.isAccessibilitySize
        let horizontalPadding: CGFloat = compact ? 16 : 34
        let heroHeight = compact
            ? min(max(proxy.size.height * 0.42, 370), 460)
            : min(max(contentWidth * 0.52, 420), 560)
        let topInset = topChromeInset(proxy)
        let bottomInset = bottomScreenSpacing
        let topBarHeight: CGFloat = topInset + (compact ? 70 : 80)
        let titleRevealOffset: CGFloat = compact ? 14 : 22
        let usesRecoveryDock =
            !snapshot.isAvailableForPurchase ||
            store.livePhase != .current
        let decisionBarClearance: CGFloat = {
            if dynamicTypeSize.isAccessibilitySize {
                if snapshot.showsCart {
                    return usesRecoveryDock ? 322 : 222
                }
                return 158
            }
            if snapshot.showsCart {
                if usesRecoveryDock {
                    return compact ? 238 : 150
                }
                return compact ? 158 : 104
            }
            return 98
        }()
        let resolvedDecisionBarClearance: CGFloat = {
            guard decisionBarHeight > 0, decisionBarHeight < 420 else {
                return decisionBarClearance
            }
            let measuredContentHeight = max(
                decisionBarHeight - bottomInset,
                decisionBarClearance
            )
            return measuredContentHeight + PPSpace.sm
        }()

        return ZStack(alignment: .top) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    PPAccessoryViewerScrollOffsetReader()

                    VStack(spacing: compact ? 14 : 22) {
                        PPAccessoryShorelineGallery(
                            snapshot: snapshot,
                            height: heroHeight,
                            compact: compact,
                            onShare: store.share
                        )
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, topBarHeight)
                        .scaleEffect(heroResolved ? 1.0 : 0.97)
                        .opacity(heroResolved ? 1 : 0)
                        .offset(y: heroResolved ? 0 : 8)

                        PPAccessoryProductIdentity(
                            store: store,
                            snapshot: snapshot,
                            compact: compact
                        )
                        .padding(.horizontal, horizontalPadding)
                        .opacity(identityResolved ? 1 : 0)
                        .offset(y: identityResolved ? 0 : 14)

                        PPAccessoryPetFitCard(snapshot: snapshot)
                            .padding(.horizontal, horizontalPadding)
                            .opacity(cardsResolved ? 1 : 0)
                            .offset(y: cardsResolved ? 0 : 16)

                        PPAccessoryDecisionRibbon(
                            store: store,
                            snapshot: snapshot
                        )
                            .padding(.horizontal, horizontalPadding)
                            .opacity(cardsResolved ? 1 : 0)
                            .offset(y: cardsResolved ? 0 : 16)

                        VStack(spacing: compact ? 22 : 30) {
                            PPAccessorySourceIsland(
                                store: store,
                                snapshot: snapshot
                            )

                            PPAccessoryEditorialDescription(
                                text: snapshot.description
                            )

                            PPAccessorySpecReef(
                                details: snapshot.details,
                                compactColumns: compact
                            )

                            PPAccessorySuggestionShore(
                                store: store,
                                compact: compact
                            )
                            .id("accessory-recommendations")
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(
                            .bottom,
                            resolvedDecisionBarClearance + bottomInset
                        )
                        .opacity(cardsResolved ? 1 : 0)
                        .offset(y: cardsResolved ? 0 : 20)
                    }
                    .frame(maxWidth: contentWidth)
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(
                    name: PPAccessoryViewerScrollMetrics.coordinateSpace
                )
                .onPreferenceChange(
                    PPAccessoryViewerScrollOffsetPreferenceKey.self
                ) { scrollDistance in
                    setNavigationTitlePillVisible(
                        scrollDistance > titleRevealOffset
                    )
                }
                .onChange(of: store.scrollToSuggestionsToken) { token in
                    guard token > 0 else { return }
                    withAnimation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.38)
                    ) {
                        scrollProxy.scrollTo(
                            "accessory-recommendations",
                            anchor: .top
                        )
                    }
                }
            }

            topFadeOverlay(proxy: proxy)

            bottomFadeOverlay(
                snapshot: snapshot,
                bottomInset: bottomInset
            )

            VStack(spacing: 8) {
                PPAccessoryViewerTopBar(
                    store: store,
                    snapshot: snapshot,
                    showsSmartTitle: showsNavigationTitlePill
                )

                if let message = store.bannerMessage {
                    PPAccessoryViewerInlineBanner(
                        message: message,
                        dismiss: store.dismissBanner
                    )
                    .padding(.horizontal, 18)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity)
                    )
                }
            }
            .padding(.top, topInset + 4)
            .padding(.bottom, 6)
            .frame(maxWidth: contentWidth)
            .frame(maxWidth: .infinity)
            .background(PPAccessorySubviewBackground.clear)
            .opacity(heroResolved ? 1 : 0)
            .offset(y: heroResolved ? 0 : -8)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.30, dampingFraction: 0.88),
                value: store.bannerMessage
            )
            .ignoresSafeArea(.container, edges: .top)
            .zIndex(100)

            PPAccessoryPersistentDecisionBar(
                store: store,
                snapshot: snapshot,
                compact: compact,
                bottomInset: bottomInset
            )
            .opacity(actionResolved ? 1 : 0)
            .background {
                GeometryReader { decisionProxy in
                    Color.clear.preference(
                        key: PPAccessoryDecisionBarHeightPreferenceKey.self,
                        value: decisionProxy.size.height
                    )
                }
            }
            .offset(y: actionResolved ? 0 : 22)
            .ignoresSafeArea(.container, edges: .bottom)
            .zIndex(100)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .onPreferenceChange(
                PPAccessoryDecisionBarHeightPreferenceKey.self
            ) { measuredHeight in
                guard measuredHeight > 0, measuredHeight < 420 else { return }
                guard abs(measuredHeight - decisionBarHeight) > 0.5 else {
                    return
                }
                decisionBarHeight = measuredHeight
            }
        }
        .coordinateSpace(name: "accessory-viewer-root")
        .ignoresSafeArea(.all, edges: [.top, .bottom])
        .onAppear {
            runEntranceIfNeeded()
            store.resume()
        }
        .onDisappear {
            store.pause()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification
            )
        ) { _ in
            store.resume()
        }
    }

    private func topChromeInset(_ proxy: GeometryProxy) -> CGFloat {
        let resolved = proxy.safeAreaInsets.top
        if resolved > 1 {
            return resolved
        }
        let sceneTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
        return max(sceneTop, 24)
    }

    private func topFadeOverlay(proxy: GeometryProxy) -> some View {
        let topColor = Color.ppBackground

        return LinearGradient(
            colors: [
                topColor.opacity(0.86),
                topColor.opacity(0.66),
                topColor.opacity(0.22),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: proxy.safeAreaInsets.top + 80)
        .ignoresSafeArea(edges: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .opacity(heroResolved ? 1 : 0)
        .zIndex(80)
    }

    private func bottomFadeOverlay(
        snapshot: PPAccessoryViewerSnapshot,
        bottomInset: CGFloat
    ) -> some View {
        let fallbackHeight = dynamicTypeSize.isAccessibilitySize
            ? (snapshot.showsCart ? 224.0 : 168.0)
            : (snapshot.showsCart ? 170.0 : 112.0)
        let safeDecisionBarHeight = (decisionBarHeight > 0 && decisionBarHeight < 420)
            ? decisionBarHeight
            : fallbackHeight
        let totalOverlayHeight = safeDecisionBarHeight
            + max(bottomInset, PPBottomDecisionBarGeometry.bottomBreathingRoom)
            + 44
        let bottomColor = Color.ppBackground

        return LinearGradient(
            colors: [
                Color.clear,
                bottomColor.opacity(0.12),
                bottomColor.opacity(0.38),
                bottomColor.opacity(0.62)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: totalOverlayHeight)
        .ignoresSafeArea(edges: .bottom)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .opacity(actionResolved ? 1 : 0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88),
            value: actionResolved
        )
        .zIndex(80)
    }

    private func runEntranceIfNeeded() {
        guard !didRunEntrance else { return }
        didRunEntrance = true

        if reduceMotion {
            heroResolved = true
            identityResolved = true
            cardsResolved = true
            actionResolved = true
            return
        }

        withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
            heroResolved = true
        }
        withAnimation(
            .spring(response: 0.46, dampingFraction: 0.86)
                .delay(0.06)
        ) {
            identityResolved = true
        }
        withAnimation(
            .spring(response: 0.50, dampingFraction: 0.88)
                .delay(0.12)
        ) {
            cardsResolved = true
        }
        withAnimation(
            .spring(response: 0.38, dampingFraction: 0.84)
                .delay(0.18)
        ) {
            actionResolved = true
        }
    }

    private func setNavigationTitlePillVisible(_ isVisible: Bool) {
        guard isVisible != showsNavigationTitlePill else { return }
        showsNavigationTitlePill = isVisible
    }
}

public enum PPAccessoryViewerScrollMetrics {
    public static let coordinateSpace = "accessory-viewer-scroll"
}

public struct PPAccessoryViewerScrollOffsetPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0

    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

public struct PPAccessoryViewerScrollOffsetReader: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(
                in: .named(PPAccessoryViewerScrollMetrics.coordinateSpace)
            ).minY

            Color.clear.preference(
                key: PPAccessoryViewerScrollOffsetPreferenceKey.self,
                value: max(0, -minY)
            )
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}
