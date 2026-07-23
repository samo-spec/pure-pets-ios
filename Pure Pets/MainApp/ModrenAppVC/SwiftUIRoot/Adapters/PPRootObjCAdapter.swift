//
//  PPRootObjCAdapter.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import UIKit

@MainActor
public final class PPRootObjCAdapter: PPRootActionHandling {
    private weak var targetController: UITabBarController?

    public init(targetController: UITabBarController) {
        self.targetController = targetController
    }

    // MARK: - Tab Actions

    public func handleSelectTab(_ tab: PPRootTab) {
        guard let controller = targetController else { return }
        if controller.selectedIndex != tab.rawValue,
           tab.rawValue < (controller.viewControllers?.count ?? 0) {
            controller.selectedIndex = tab.rawValue
        }
    }

    public func handleTabReselected(_ tab: PPRootTab) {
        guard let controller = targetController,
              let vcs = controller.viewControllers,
              tab.rawValue < vcs.count else { return }
        if let nav = vcs[tab.rawValue] as? UINavigationController,
           nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        }
    }

    // MARK: - Root Controller Actions

    public func handlePresentCreateOptionPicker() {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.presentBottomSheet(on: c)
    }

    public func handleOpenNovaChat() {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.novaButtonTapped(on: c)
    }

    public func handleOpenSearchExperience(openingAccessories: Bool) {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.openSearchExperience(on: c, openingAccessories: openingAccessories)
    }

    public func handleOpenChatThreadNotification(thread: Any, animated: Bool) -> Bool {
        guard let c = targetController else { return false }
        return PPRootLegacyAdapter.openChatThread(on: c, thread: thread, animated: animated)
    }

    public func handleBlockedContactSupportCall() {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.blockedContactSupportTapped(on: c)
    }

    public func handleBlockedContactSupportWhatsApp() {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.blockedContactSupportTapped(on: c)
    }

    public func handleBlockedSignOut(completion: @escaping (Error?) -> Void) {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.blockedSignOutTapped(on: c)
        completion(nil)
    }

    public func handleShowIntroIfNeeded() {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.showIntroIfNeeded(on: c)
    }

    public func updateBottomNavigationClearance(_ clearance: CGFloat) {
        guard let c = targetController else { return }
        PPRootLegacyAdapter.applyBottomNavigationClearance(on: c)
    }

    // MARK: - Session & Unread State

    public func fetchCurrentSessionSnapshot() -> PPRootSessionState {
        let loggedIn            = PPRootLegacyAdapter.isUserLoggedIn()
        let blocked             = PPRootLegacyAdapter.isCurrentUserBlocked()
        let effectivelyBlocked  = PPRootLegacyAdapter.isCurrentUserEffectivelyBlocked()
        let displayName         = PPRootLegacyAdapter.currentUserDisplayName() ?? ""
        let imageURL            = PPRootLegacyAdapter.currentUserImageURL()

        return PPRootSessionState(
            isLoggedIn: loggedIn,
            isBlocked: blocked,
            isEffectivelyBlocked: effectivelyBlocked,
            displayName: displayName,
            userImageUrl: imageURL
        )
    }

    
    public func fetchCurrentUnreadChatsCount() -> Int {
        return PPRootLegacyAdapter.totalUnreadChatsCount()
    }

    // MARK: - Cart State

    public func fetchCurrentCartSnapshot() -> PPCartFloatingBarState {
        let count = PPRootLegacyAdapter.cartTotalItemsCount()
        let total = PPRootLegacyAdapter.cartTotalAmount()
        return PPCartFloatingBarState(
            itemCount: count,
            totalAmount: total,
            isVisible: false, // isVisible is controlled explicitly by activateFloatingCart for eligible source VCs
            isCollapsed: false
        )
    }

    // MARK: - Context Helpers

    public func topVisibleViewController() -> UIViewController? {
        guard let controller = targetController else { return nil }
        var current: UIViewController? = controller.selectedViewController ?? controller
        while let presented = current?.presentedViewController, !presented.isBeingDismissed {
            current = presented
        }
        if let nav = current as? UINavigationController {
            return nav.visibleViewController ?? nav.topViewController
        }
        return current
    }

    public func isEligibleFloatingCartSource(_ viewController: UIViewController) -> Bool {
        let className = NSStringFromClass(viewController.classForCoder)
        if className.isEmpty ||
           className.contains("PPHomeViewController") ||
           className.contains("Home") ||
           className.contains("Photo") ||
           className.contains("Viewer") ||
           className.contains("DetailAd") ||
           className.contains("Accessory") {
            return false
        }
        return className.contains("PPDataViewVC") || className.contains("SellerProfileVC")
    }

    // MARK: - Bottom Surface

    public func applyBottomSurface(for viewController: UIViewController, animated: Bool) {
        PPRootLegacyAdapter.applySurface(for: viewController, animated: animated)
    }
}
