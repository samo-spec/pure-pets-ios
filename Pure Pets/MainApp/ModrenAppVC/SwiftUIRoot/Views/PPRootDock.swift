//
//  PPRootDock.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Native SwiftUI bottom TabBar component with material background, system separator line, and RTL layout support.
public struct PPRootDock: View {
    @ObservedObject public var store: PPRootStore
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    
    private var primaryColor: Color {
        Color(uiColor: UIColor(named: "AppPrimaryColor") ?? UIColor(red: 227/255, green: 6/255, blue: 83/255, alpha: 1.0))
    }
    
    public init(store: PPRootStore) {
        self.store = store
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Home Tab
            PPRootDockItem(
                tab: .home,
                isSelected: store.selectedTab == .home,
                unreadCount: 0,
                sessionState: store.sessionState
            ) {
                store.selectTab(.home)
            }
            
            // MyAds Tab
            PPRootDockItem(
                tab: .myAds,
                isSelected: store.selectedTab == .myAds,
                unreadCount: 0,
                sessionState: store.sessionState
            ) {
                store.selectTab(.myAds)
            }
            
            // Create Tab
            PPRootDockItem(
                tab: .create,
                isSelected: store.selectedTab == .create,
                unreadCount: 0,
                sessionState: store.sessionState
            ) {
                store.selectTab(.create)
            }
            
            // Chats Tab
            PPRootDockItem(
                tab: .chats,
                isSelected: store.selectedTab == .chats,
                unreadCount: store.unreadChatsCount,
                sessionState: store.sessionState
            ) {
                store.selectTab(.chats)
            }
            
            // Menu Tab
            PPRootDockItem(
                tab: .menu,
                isSelected: store.selectedTab == .menu,
                unreadCount: 0,
                sessionState: store.sessionState
            ) {
                store.selectTab(.menu)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color(uiColor: .separator)),
                    alignment: .top
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 8, x: 0, y: -2)
        }
        .frame(maxWidth: .infinity)
    }
}
