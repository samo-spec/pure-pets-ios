import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct PPAccessoryViewerScreen: View {
    @StateObject var store: PPAccessoryViewerStore

    @State private var heroResolved = false
    @State private var contentResolved = false
    @State private var actionResolved = false
    @State private var didRunEntrance = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            screenBody
                .toolbar(.hidden, for: .navigationBar)
        }
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

                if case .loaded = store.phase {
                    VStack(spacing: 10) {
                        PPAccessoryViewerTopBar(store: store)
                        if let message = store.bannerMessage {
                            PPAccessoryViewerInlineBanner(
                                message: message,
                                dismiss: store.dismissBanner
                            )
                            .padding(.horizontal, 18)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .move(edge: .top).combined(
                                        with: .opacity
                                    )
                            )
                        }
                    }
                    .padding(.top, topChromeInset(proxy) + 6)
                    .opacity(heroResolved ? 1 : 0)
                    .offset(y: heroResolved ? 0 : -12)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(
                                response: 0.30,
                                dampingFraction: 0.88
                            ),
                        value: store.bannerMessage
                    )
                    .zIndex(20)
                }
            }
        }
    }

    @ViewBuilder
    private func phaseContent(proxy: GeometryProxy) -> some View {
        switch store.phase {
        case .loading:
            PPAccessoryViewerLoadingState(
                topInset: topChromeInset(proxy),
                compact: proxy.size.width < 700 ||
                    dynamicTypeSize.isAccessibilitySize
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
            ? min(max(proxy.size.height * 0.34, 310), 390)
            : min(max(contentWidth * 0.46, 360), 500)
        let topInset = topChromeInset(proxy)
        let galleryTopPadding = compact
            ? max(topInset + 8, 24)
            : max(topInset + 14, 32)

        return ScrollView {
            VStack(spacing: compact ? 16 : 24) {
                PPAccessoryShorelineGallery(
                    snapshot: snapshot,
                    height: heroHeight,
                    compact: compact,
                    onShare: store.share
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.top, galleryTopPadding)
                .scaleEffect(heroResolved ? 1 : 1.045)
                .opacity(heroResolved ? 1 : 0)

                PPAccessoryProductIdentity(
                    snapshot: snapshot,
                    compact: compact
                )
                .padding(.horizontal, horizontalPadding)
                .opacity(contentResolved ? 1 : 0)
                .offset(y: contentResolved ? 0 : 16)

                VStack(spacing: compact ? 22 : 30) {
                    PPAccessorySpecReef(
                        details: snapshot.details,
                        compactColumns: compact
                    )

                    PPAccessorySourceIsland(
                        store: store,
                        snapshot: snapshot
                    )

                    PPAccessoryEditorialDescription(
                        text: snapshot.description
                    )

                    PPAccessorySuggestionShore(store: store)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, snapshot.showsCart ? 8 : 14)
                .opacity(contentResolved ? 1 : 0)
                .offset(y: contentResolved ? 0 : 22)
            }
            .frame(maxWidth: contentWidth)
            .frame(maxWidth: .infinity)
        }
        .coordinateSpace(name: "accessory-viewer-scroll")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PPAccessoryPersistentDecisionBar(
                store: store,
                snapshot: snapshot,
                compact: compact
            )
            .opacity(actionResolved ? 1 : 0)
            .offset(y: actionResolved ? 0 : 18)
        }
        .onAppear {
            runEntranceIfNeeded()
            store.refreshCartState()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification
            )
        ) { _ in
            store.refreshCartState()
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

    private func runEntranceIfNeeded() {
        guard !didRunEntrance else { return }
        didRunEntrance = true

        if reduceMotion {
            heroResolved = true
            contentResolved = true
            actionResolved = true
            return
        }

        withAnimation(.easeOut(duration: 0.46)) {
            heroResolved = true
        }
        withAnimation(
            .spring(response: 0.54, dampingFraction: 0.88)
                .delay(0.08)
        ) {
            contentResolved = true
        }
        withAnimation(
            .spring(response: 0.42, dampingFraction: 0.90)
                .delay(0.16)
        ) {
            actionResolved = true
        }
    }
}
