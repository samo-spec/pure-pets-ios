//
//  PPRootBottomOverlayView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Preference key tracking dynamic height of the composite bottom overlay container (Fixes Risk #1).
private struct PPRootBottomOverlayHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PPRootBottomOverlayInteractiveFramesKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private enum PPRootBottomOverlayCoordinateSpace {
    static let name = "pp.root.bottom-overlay"
}

private extension View {
    func reportsBottomOverlayInteractiveFrame() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PPRootBottomOverlayInteractiveFramesKey.self,
                    value: [
                        proxy.frame(
                            in: .named(PPRootBottomOverlayCoordinateSpace.name)
                        )
                    ]
                )
            }
        }
    }
}

/// Composite bottom overlay view enclosing the Command Deck and floating cart bar.
public struct PPRootBottomOverlayView: View {
    @ObservedObject public var store: PPRootStore
    private let interactiveFramesDidChange: ([CGRect]) -> Void

    public init(
        store: PPRootStore,
        interactiveFramesDidChange: @escaping ([CGRect]) -> Void = { _ in }
    ) {
        self.store = store
        self.interactiveFramesDidChange = interactiveFramesDidChange
    }

    public var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .passthroughTouches(true)

                ZStack(alignment: .bottomTrailing) {
                    if store.shouldShowDock {
                        if #available(iOS 17.0, *) {
                            PPRootCommandDeck(store: store)
                                .padding(
                                    .horizontal,
                                    PPCommandDeckTabBar.hostHorizontalInset
                                )
                                .padding(
                                    .top,
                                    PPCommandDeckTabBar.hostTopInset
                                )
                                .padding(
                                    .bottom,
                                    PPCommandDeckTabBar.hostBottomInset
                                )
                                .reportsBottomOverlayInteractiveFrame()
                                .transition(
                                    .move(edge: .bottom).combined(with: .opacity)
                                )
                        }
                    }

                    // The floating cart remains an independent surface. Its
                    // existing state machine hides the dock while active.
                    if store.shouldShowCartBar {
                        PPCartFloatingBarView(state: store.cartState) {
                            store.handleCartTapped()
                        }
                        .passthroughTouches(false)
                        .reportsBottomOverlayInteractiveFrame()
                        .padding(.horizontal, 16)
                        .padding(
                            .bottom,
                            proxy.safeAreaInsets.bottom
                                + (store.shouldShowDock ? 54 : 12)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .passthroughTouches(true)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: PPRootBottomOverlayHeightKey.self,
                            value: geo.size.height
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .onPreferenceChange(PPRootBottomOverlayHeightKey.self) { measuredHeight in
                DispatchQueue.main.async {
                    store.updateMeasuredBottomOverlayHeight(
                        measuredHeight,
                        safeAreaBottom: proxy.safeAreaInsets.bottom
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .passthroughTouches(true)
        .coordinateSpace(name: PPRootBottomOverlayCoordinateSpace.name)
        .onPreferenceChange(
            PPRootBottomOverlayInteractiveFramesKey.self,
            perform: interactiveFramesDidChange
        )
    }
}

@available(iOS 17.0, *)
private struct PPRootCommandDeck: View {
    @ObservedObject var store: PPRootStore

    var body: some View {
        PPCommandDeckTabBar(
            selection: Binding(
                get: { store.selectedTab.ppCommandDeckTab },
                set: { store.selectTab($0.ppRootTab) }
            ),
            unreadChats: store.unreadChatsCount,
            copy: PPCommandDeckCopy(
                navigationLabel: LocalizedStringKey(
                    localized("a11y_command_deck_navigation")
                ),
                createLabel: LocalizedStringKey(localized("a11y_tab_add")),
                createHint: LocalizedStringKey(
                    localized("a11y_btn_add_new_hint")
                )
            )
        ) {
            // Create is intentionally an action, not a selected destination.
            store.selectTab(.create)
        }
        // Language owns both reading direction and localized label geometry.
        // Rebuild only the deck presentation so its selection namespace and
        // measurements reset while the store keeps the active route intact.
        .environment(
            \.layoutDirection,
            store.languageCode == "ar" ? .rightToLeft : .leftToRight
        )
        .id(store.languageCode)
    }

    private func localized(_ key: String) -> String {
        Language.get(key, alter: key) ?? key
    }
}

@available(iOS 17.0, *)
private extension PPRootTab {
    var ppCommandDeckTab: PPCommandDeckTab {
        switch self {
        case .home:
            .home
        case .myAds:
            .myAds
        case .chats:
            .chats
        case .menu:
            .menu
        case .create:
            // Create never owns selection; retain the existing destination.
            .home
        }
    }
}

@available(iOS 17.0, *)
private extension PPCommandDeckTab {
    var ppRootTab: PPRootTab {
        switch self {
        case .home:
            .home
        case .myAds:
            .myAds
        case .chats:
            .chats
        case .menu:
            .menu
        }
    }
}
