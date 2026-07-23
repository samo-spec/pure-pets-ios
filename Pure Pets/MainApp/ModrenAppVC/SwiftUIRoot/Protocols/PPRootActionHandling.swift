//
//  PPRootActionHandling.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import UIKit

/// Protocol defining strongly-typed actions and data queries executed by the SwiftUI Root store,
/// decoupling the declarative layer from legacy Objective-C singletons or runtime selectors.
@MainActor
public protocol PPRootActionHandling: AnyObject {
    
    /// User selected or tapped a root tab index.
    func handleSelectTab(_ tab: PPRootTab)
    
    /// User reselected the active tab (triggers pop-to-root on navigation stack).
    func handleTabReselected(_ tab: PPRootTab)
    
    /// User tapped the central Create / Add post action button.
    func handlePresentCreateOptionPicker()
    
    /// User tapped the Nova AI floating button.
    func handleOpenNovaChat()
    
    /// Open search experience from current context.
    func handleOpenSearchExperience(openingAccessories: Bool)
    
    /// Open a chat thread from notification payload.
    func handleOpenChatThreadNotification(thread: Any, animated: Bool) -> Bool
    
    /// Request phone call support for blocked user overlay.
    func handleBlockedContactSupportCall()
    
    /// Request WhatsApp support for blocked user overlay.
    func handleBlockedContactSupportWhatsApp()
    
    /// Sign out current user from blocked user overlay.
    func handleBlockedSignOut(completion: @escaping (Error?) -> Void)
    
    /// Trigger introductory splash/walkthrough if eligible.
    func handleShowIntroIfNeeded()
    
    /// Notify visible list scroll views of current bottom content clearance requirements.
    func updateBottomNavigationClearance(_ clearance: CGFloat)
    
    /// Query current unread chat messages count from in-memory store.
    func fetchCurrentUnreadChatsCount() -> Int
    
    /// Query current user session & blocked status snapshot.
    func fetchCurrentSessionSnapshot() -> PPRootSessionState
    
    /// Query current cart items count and total price snapshot.
    func fetchCurrentCartSnapshot() -> PPCartFloatingBarState
    
    /// Resolve top visible UIViewController from current navigation state.
    func topVisibleViewController() -> UIViewController?
    
    /// Check whether a view controller is eligible to display the floating cart bar.
    func isEligibleFloatingCartSource(_ viewController: UIViewController) -> Bool
    
    /// Apply bottom surface kind for target view controller.
    func applyBottomSurface(for viewController: UIViewController, animated: Bool)
}
