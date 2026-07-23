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
            return NSLocalizedString("MainPage", comment: "Main Page / Home Tab")
        case .myAds:
            let ordersTitle = NSLocalizedString("menu_action_orders", comment: "My Orders")
            return (ordersTitle.isEmpty || ordersTitle == "menu_action_orders")
                ? NSLocalizedString("OrderHistory", comment: "Order History")
                : ordersTitle
        case .create:
            return NSLocalizedString("Add", comment: "Add / Create New Post")
        case .chats:
            return NSLocalizedString("chatsTitle", comment: "Chats & Notifications")
        case .menu:
            return NSLocalizedString("user_menu_tab_title", comment: "User Menu / Profile")
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
            return NSLocalizedString("a11y_tab_home", value: "Home tab", comment: "")
        case .myAds:
            return NSLocalizedString("a11y_tab_orders", value: title, comment: "")
        case .create:
            return NSLocalizedString("a11y_tab_add", value: "Add new post tab", comment: "")
        case .chats:
            return NSLocalizedString("a11y_tab_notifications", value: title, comment: "")
        case .menu:
            return NSLocalizedString("a11y_tab_user_menu", value: title, comment: "")
        }
    }
    
    /// Accessibility hint for VoiceOver compliance.
    public var accessibilityHint: String {
        switch self {
        case .home:
            return NSLocalizedString("a11y_tab_home_hint", value: "Browse pet ads and services", comment: "")
        case .myAds:
            return NSLocalizedString("a11y_tab_orders_hint", value: "View your active orders and history", comment: "")
        case .create:
            return NSLocalizedString("a11y_btn_add_new_hint", value: "Create a new pet ad, accessory listing, or adoption post", comment: "")
        case .chats:
            return NSLocalizedString("a11y_tab_notifications_hint", value: "View your chats and notifications", comment: "")
        case .menu:
            return NSLocalizedString("a11y_tab_user_menu_hint", value: "Access profile, settings, and account management", comment: "")
        }
    }
}
