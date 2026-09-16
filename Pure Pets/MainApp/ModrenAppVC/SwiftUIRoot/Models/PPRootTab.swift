//
//  PPRootTab.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Enumeration representing the five primary application tabs with RTL-safe metadata,
/// accessibility hints, and symbol configurations matching legacy `PPRootTabIndex`.
public enum PPRootTab: Int, CaseIterable, Identifiable, Sendable {
    case home = 0
    case myAds = 1
    case create = 2
    case chats = 3
    case menu = 4
    
    public var id: Int { rawValue }
    
    /// User-facing localized title matching legacy `kLang` key targets.
    public var title: String {
        switch self {
        case .home:
            return Language.get("MainPage", alter: "MainPage") ?? "MainPage"
        case .myAds:
            let ordersTitle = Language.get("menu_action_orders", alter: "menu_action_orders")
            return (ordersTitle == nil || ordersTitle == "menu_action_orders")
                ? (Language.get("OrderHistory", alter: "Order History") ?? "Order History")
                : ordersTitle!
        case .create:
            return Language.get("Add", alter: "Add") ?? "Add"
        case .chats:
            return Language.get("chatsTitle", alter: "chatsTitle") ?? "chatsTitle"
        case .menu:
            return Language.get("user_menu_tab_title", alter: "user_menu_tab_title") ?? "user_menu_tab_title"
        }
    }
    
    /// Normal SF Symbol name matching `PPRootTabBarController.m` configuration.
    public var symbolNormalName: String {
        switch self {
        case .home: return "house"
        case .myAds: return "cart.badge.clock"
        case .create: return "plus"
        case .chats: return "message.badge.waveform"
        case .menu: return "person.crop.circle"
        }
    }
    
    /// Selected SF Symbol name.
    public var symbolSelectedName: String {
        switch self {
        case .home: return "house.fill"
        case .myAds: return "cart.badge.clock.fill"
        case .create: return "plus.fill"
        case .chats: return "message.badge.waveform.fill"
        case .menu: return "person.crop.circle.fill"
        }
    }
    
    /// Accessibility label for VoiceOver compliance.
    public var accessibilityLabel: String {
        switch self {
        case .home:
            return Language.get("a11y_tab_home", alter: "Home tab") ?? "Home tab"
        case .myAds:
            return Language.get("a11y_tab_orders", alter: title) ?? title
        case .create:
            return Language.get("a11y_tab_add", alter: "Add new post tab") ?? "Add new post tab"
        case .chats:
            return Language.get("a11y_tab_notifications", alter: title) ?? title
        case .menu:
            return Language.get("a11y_tab_user_menu", alter: title) ?? title
        }
    }
    
    /// Accessibility hint for VoiceOver compliance.
    public var accessibilityHint: String {
        switch self {
        case .home:
            return Language.get("a11y_tab_home_hint", alter: "Browse pet ads and services") ?? "Browse pet ads and services"
        case .myAds:
            return Language.get("a11y_tab_orders_hint", alter: "View your active orders and history") ?? "View your active orders and history"
        case .create:
            return Language.get("a11y_btn_add_new_hint", alter: "Create a new pet ad, accessory listing, or adoption post") ?? "Create a new pet ad, accessory listing, or adoption post"
        case .chats:
            return Language.get("a11y_tab_notifications_hint", alter: "View your chats and notifications") ?? "View your chats and notifications"
        case .menu:
            return Language.get("a11y_tab_user_menu_hint", alter: "Access profile, settings, and account management") ?? "Access profile, settings, and account management"
        }
    }
}
