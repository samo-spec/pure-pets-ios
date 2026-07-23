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

/// Composite bottom overlay view enclosing the native SwiftUI TabBar, Nova AI Action Button, and Floating Cart Bar.
public struct PPRootBottomOverlayView: View {
    @ObservedObject public var store: PPRootStore
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    
    public init(store: PPRootStore) {
        self.store = store
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
                    
                    // Floating Cart Bar surface (floats neatly above tab bar)
                    if store.shouldShowCartBar {
                        PPCartFloatingBarView(state: store.cartState) {
                            store.handleCartTapped()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, store.useLegacyBar ? max(proxy.safeAreaInsets.bottom + 54, 88) : max(proxy.safeAreaInsets.bottom, 8))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Nova AI Button (floats neatly above tab bar)
                    if store.shouldShowNovaButton && !store.shouldShowCartBar {
                        PPRootNovaButton(state: store.novaState) {
                            store.handleNovaTapped()
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, store.useLegacyBar ? max(proxy.safeAreaInsets.bottom + 54, 88) : (store.shouldShowDock ? max(proxy.safeAreaInsets.bottom + 54, 64) : max(proxy.safeAreaInsets.bottom, 8)))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .passthroughTouches(false) // Ensures taps on TabBar/Nova/Cart are captured
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
    }
}
