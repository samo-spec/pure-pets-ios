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
        guard let controller = targetController,
              let viewControllers = controller.viewControllers,
              tab.rawValue < viewControllers.count,
              controller.selectedIndex != tab.rawValue else { return }

        let selectedController = viewControllers[tab.rawValue]
        controller.selectedIndex = tab.rawValue
        notifyLegacyDelegate(
            controller,
            didSelect: selectedController
        )
    }

    public func handleTabReselected(_ tab: PPRootTab) {
        guard let controller = targetController,
              let viewControllers = controller.viewControllers,
              tab.rawValue < viewControllers.count else { return }

        let selectedController = viewControllers[tab.rawValue]
        if let nav = selectedController as? UINavigationController,
           nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        }

        // The UIKit delegate owns Home's specialized reselection behavior,
        // commerce feedback, bottom surfaces, and legacy bookkeeping.
        notifyLegacyDelegate(
            controller,
            didSelect: selectedController
        )
    }

    private func notifyLegacyDelegate(
        _ controller: UITabBarController,
        didSelect selectedController: UIViewController
    ) {
        controller.delegate?.tabBarController?(
            controller,
            didSelect: selectedController
        )
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
            // Ignore transient alerts and activity controllers
            if presented is UIAlertController || presented is UIActivityViewController {
                break
            }
            
            // If presented is a sheet / drawer presentation, only descend if it defines its own surface
            var isSheetPresentation = false
            if #available(iOS 15.0, *) {
                if presented.sheetPresentationController != nil {
                    isSheetPresentation = true
                }
            }
            if presented.modalPresentationStyle == .pageSheet ||
               presented.modalPresentationStyle == .formSheet ||
               presented.modalPresentationStyle == .overFullScreen ||
               presented.modalPresentationStyle == .overCurrentContext ||
               presented.modalPresentationStyle == .custom {
                isSheetPresentation = true
            }

            if isSheetPresentation && !isControllerOrChildCustomSurface(presented) {
                break
            }

            current = presented
        }
        if let nav = current as? UINavigationController {
            let top = nav.topViewController
            if let candidate = nav.visibleViewController, candidate !== top, !candidate.isBeingDismissed {
                if isControllerOrChildCustomSurface(candidate) {
                    return candidate
                }
            }
            return top ?? nav.visibleViewController
        }
        return current
    }

    private func isControllerOrChildCustomSurface(_ viewController: UIViewController) -> Bool {
        if isDirectEligibleFloatingCartSource(viewController) {
            return true
        }
        let preferredKindSelector = NSSelectorFromString("pp_preferredBottomSurfaceKind")
        if viewController.responds(to: preferredKindSelector) {
            let defaultMethod = class_getInstanceMethod(UIViewController.self, preferredKindSelector)
            let controllerMethod = class_getInstanceMethod(type(of: viewController), preferredKindSelector)
            if let defaultMethod, let controllerMethod, method_getImplementation(defaultMethod) != method_getImplementation(controllerMethod) {
                return true
            }
        }
        if let nav = viewController as? UINavigationController {
            let top = nav.visibleViewController ?? nav.topViewController
            if let top, top !== viewController {
                return isControllerOrChildCustomSurface(top)
            }
        }
        return false
    }

    private func isDirectEligibleFloatingCartSource(_ viewController: UIViewController) -> Bool {
        let eligibilitySelector = NSSelectorFromString("pp_isFloatingCartEligible")
        if viewController.responds(to: eligibilitySelector),
            let implementation = viewController.method(for: eligibilitySelector) {
            typealias EligibilityFunction = @convention(c) (
                AnyObject,
                Selector
            ) -> Bool
            let function = unsafeBitCast(
                implementation,
                to: EligibilityFunction.self
            )
            return function(viewController, eligibilitySelector)
        }

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
        return className.contains("SellerProfileVC")
    }

    public func isEligibleFloatingCartSource(_ viewController: UIViewController) -> Bool {
        var candidate: UIViewController? = viewController
        while let current = candidate {
            if isDirectEligibleFloatingCartSource(current) {
                return true
            }
            candidate = current.presentingViewController ?? current.parent
        }
        return false
    }

    // MARK: - Bottom Surface

    public func applyBottomSurface(for viewController: UIViewController, animated: Bool) {
        PPRootLegacyAdapter.applySurface(for: viewController, animated: animated)
    }
}
