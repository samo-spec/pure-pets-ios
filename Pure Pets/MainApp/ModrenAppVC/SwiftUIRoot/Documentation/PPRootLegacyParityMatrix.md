# Complete Legacy Parity Matrix — PurePets SwiftUI Root Refactor

This document contains the exhaustive parity matrix mapping every legacy Objective-C property, method, selector, notification observer, timer, delegate callback, user-defaults key, localization key, asset, lifecycle event, and public API from `PPRootTabBarController.h` and `PPRootTabBarController.m` (4,596 lines) to its new Swift owner inside `PurePetsSwiftUIRefactor/Root/`.

---

## 1. Public API & Protocol Parity

| Legacy Objective-C Signature / Method | Location in `PPRootTabBarController` | Swift Refactor Owner & Method | Parity & Behavioral Verification |
| :--- | :--- | :--- | :--- |
| `pp_setBottomNavigationHidden:animated:` | Line 405 | `PPRootSwiftCoordinator.setBottomNavigationHidden(_:animated:)` | Preserved. Updates `isExternallyHidden` and animates opacity. |
| `pp_setTabDockHidden:animated:` | Line 412 | `PPRootSwiftCoordinator.setDockHidden(_:animated:)` | Preserved. Updates `isDockHidden` in `PPRootStore`. |
| `pp_currentBottomNavigationContentClearance` | Line 420 | `PPRootSwiftCoordinator.currentBottomNavigationContentClearance()` | Preserved & **Fixed (Risk #1)**. Adaptively measures overlay height + safe area. |
| `pp_activateFloatingCartBarForSourceViewController:openCartHandler:animated:` | Line 435 | `PPRootSwiftCoordinator.activateFloatingCart(sourceViewController:openCartHandler:animated:)` | Preserved. Registers source VC, starts 6s auto-collapse timer. |
| `pp_deactivateFloatingCartBarForSourceViewController:animated:` | Line 448 | `PPRootSwiftCoordinator.deactivateFloatingCart(sourceViewController:animated:)` | Preserved. Validates source VC ownership before dismissing cart bar. |
| `pp_openChatThreadFromNotification:animated:` | Line 460 | `PPRootSwiftCoordinator.openChatThreadFromNotification(thread:animated:)` | Preserved. Navigates directly to target chat thread. |

---

## 2. State & Property Ownership

| Legacy Property / Variable | Description & Scope | Swift Owner & Property | Type & Access Control |
| :--- | :--- | :--- | :--- |
| `selectedViewController` / `selectedIndex` | Active tab index (0-4) | `PPRootStore.selectedTab` | `PPRootTab` (`@Published`) |
| `unreadChatsCount` | Unread messaging threads | `PPRootStore.unreadChatsCount` | `Int` (`@Published`) |
| `cartFloatingBarCoordinator` | Floating cart banner state | `PPRootStore.cartState` | `PPCartFloatingBarState` (`@Published`) |
| `cartCollapseTimer` | 6.0s auto-collapse timer | `PPRootStore.cartCollapseTimer` | `Timer?` (Main thread) |
| `blockedOverlayView` | Full-screen suspended account screen | `PPBlockedAccountOverlayView` | SwiftUI View + `PPBlockedAccountState` |
| `novaButtonView` | Floating Nova AI button | `PPRootNovaButton` | SwiftUI View + `PPRootNovaState` |
| `useLegacyBar` | Fallback system tab bar flag | `PPRootStore.useLegacyBar` | `Bool` (`@Published`) |

---

## 3. Notification Observers & Subscriptions

| Notification Key / Name | Legacy Observer Handler | Swift Observer (`PPRootStore.swift`) | Handled Event Action |
| :--- | :--- | :--- | :--- |
| `UnreadCountsUpdated` | `pp_handleUnreadCountsUpdated:` | `PPRootStore.bindNotifications()` | Fetches latest unread chat count; updates badge `"99+"`. |
| `PPUserManagerDidUpdateBlockedStateNotification` | `pp_handleUserBlockedStateChanged:` | `PPRootStore.bindNotifications()` | Refreshes session snapshot & toggles blocked overlay. |
| `PPNovaFloatingVisibilityDidChangeNotification` | `pp_handleNovaVisibilityChanged:` | `PPRootStore.bindNotifications()` | Reads `pp_nova_floating_visible` user default flag. |
| `kCartUpdatedNotification` | `pp_handleCartUpdated:` | `PPRootStore.bindNotifications()` | Refreshes item count and total cart amount. |
| `PPShowSystemTabBarNotification` | `pp_handleShowSystemTabBar:` | `PPRootStore.bindNotifications()` | Sets `isExternallyHidden = false`. |
| `PPHideSystemTabBarNotification` | `pp_handleHideSystemTabBar:` | `PPRootStore.bindNotifications()` | Sets `isExternallyHidden = true`. |
| `PPRouteToSearchAccessoriesNotificationKey` | `pp_handleRouteSearchAccessories:` | `PPRootStore.bindNotifications()` | Dispatches search experience opening accessories tab. |

---

## 4. Assets & Localization Keys

| Key / Resource Name | Type | Usage | Swift Location |
| :--- | :--- | :--- | :--- |
| `MainPage` | Localized Key | Tab 0 Title (Home) | `PPRootTab.home.title` |
| `menu_action_orders` | Localized Key | Tab 1 Title (My Ads / Orders) | `PPRootTab.myAds.title` |
| `add_post_title` | Localized Key | Tab 2 Title (Create) | `PPRootTab.create.title` |
| `chats_tab_title` | Localized Key | Tab 3 Title (Chats) | `PPRootTab.chats.title` |
| `menu_title` | Localized Key | Tab 4 Title (User Menu) | `PPRootTab.menu.title` |
| `Cart` | Localized Key | Floating Cart Title | `PPCartFloatingBarView.swift` |
| `checkout_review_cart_action` | Localized Key | Cart CTA Button | `PPCartFloatingBarView.swift` |
| `auth_account_blocked_title` | Localized Key | Blocked Title | `PPBlockedAccountOverlayView.swift` |
| `auth_account_blocked_message` | Localized Key | Blocked Subtitle | `PPBlockedAccountOverlayView.swift` |
| `order_support_button` | Localized Key | Call Support CTA | `PPBlockedAccountOverlayView.swift` |
| `logout` | Localized Key | Sign Out Button | `PPBlockedAccountOverlayView.swift` |
| `Ncolored.json` | Lottie Asset | Nova AI Button | `PPRootNovaLottieView.swift` |
| `Profile.lottie` | Lottie Asset | Guest Profile Tab | `PPRootGuestProfileLottieView.swift` |
| `contactUs` | Lottie Asset | Blocked Header | `PPBlockedAccountOverlayView.swift` |

---

## 5. User Defaults & Configuration Keys

| UserDefault Key | Description | Swift Owner |
| :--- | :--- | :--- |
| `PP_USE_SWIFTUI_ROOT_ENABLED` | Feature flag gating SwiftUI Root activation | `PPRootFeatureFlag.shared.isSwiftUIRootEnabled` |
| `PPUSE_LEGACY_BAR` | Force fallback system tab bar | `PPRootFeatureFlag.shared.isLegacyBarForced` |
| `pp_nova_floating_visible` | Nova floating button user visibility preference | `PPRootStore.refreshNovaState()` |

---

## 6. Delegate & Proxy Architecture

| Delegate Protocol | Primary Target | Proxy Handling Class | Forwarding Behavior |
| :--- | :--- | :--- | :--- |
| `UITabBarControllerDelegate` | `PPRootTabBarController` | `PPRootSwiftCoordinator` | Intercepts Tab 2 (.create) & blocked touch states. |
| `UINavigationControllerDelegate` | `PPRootTabBarController` | `PPRootNavigationDelegateProxy` | Forwards `willShow`, `didShow`, orientations, & transition animators. |
