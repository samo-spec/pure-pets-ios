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

/// Composite bottom overlay view enclosing the native SwiftUI TabBar, Nova AI Action Button, and Floating Cart Bar.
public struct PPRootBottomOverlayView: View {
    @ObservedObject public var store: PPRootStore
    private let interactiveFramesDidChange: ([CGRect]) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    
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
                Spacer()
                    .passthroughTouches(true)
                
                ZStack(alignment: .bottomTrailing) {
                    // Main Dock TabBar (if custom SwiftUI dock is active)
                    if store.shouldShowDock {
                        PPRootDock(store: store)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Floating Cart Bar surface (floats neatly above tab bar when active, or near screen bottom when dock hidden)
                    if store.shouldShowCartBar {
                        PPCartFloatingBarView(state: store.cartState) {
                            store.handleCartTapped()
                        }
                        .passthroughTouches(false)
                        .reportsBottomOverlayInteractiveFrame()
                        .padding(.horizontal, 16)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + (store.shouldShowDock ? 54 : 12))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Nova AI Button (floats neatly above tab bar)
                    if store.shouldShowNovaButton && !store.shouldShowCartBar {
                        PPRootNovaButton(state: store.novaState) {
                            store.handleNovaTapped()
                        }
                        .passthroughTouches(false)
                        .reportsBottomOverlayInteractiveFrame()
                        .padding(.trailing, 16)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + (store.shouldShowDock ? 54 : 12))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .passthroughTouches(true)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: PPRootBottomOverlayHeightKey.self,
                            value: geo.size.height
                        )
                    }
                )
            }
            .onPreferenceChange(PPRootBottomOverlayHeightKey.self) { measuredHeight in
                store.updateMeasuredBottomOverlayHeight(
                    measuredHeight,
                    safeAreaBottom: proxy.safeAreaInsets.bottom
                )
            }
        }
        .passthroughTouches(true)
        .coordinateSpace(name: PPRootBottomOverlayCoordinateSpace.name)
        .onPreferenceChange(
            PPRootBottomOverlayInteractiveFramesKey.self,
            perform: interactiveFramesDidChange
        )
    }
}
