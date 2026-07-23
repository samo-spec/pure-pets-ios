//
//  PPRootNavigationDelegateProxy.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import UIKit

/// Proxy object forwarding all optional `UINavigationControllerDelegate` callbacks to both the SwiftUI Root
/// coordinator and any pre-existing navigation controller delegate, preventing delegate overrides (Fixes Risk #4 & Requirement #12).
@MainActor
public final class PPRootNavigationDelegateProxy: NSObject, UINavigationControllerDelegate {
    public private(set) weak var primaryDelegate: UINavigationControllerDelegate?
    public private(set) weak var secondaryDelegate: UINavigationControllerDelegate?
    
    public init(primary: UINavigationControllerDelegate?, secondary: UINavigationControllerDelegate?) {
        self.primaryDelegate = primary
        self.secondaryDelegate = secondary
        super.init()
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        primaryDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
        if secondaryDelegate !== primaryDelegate {
            secondaryDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
        }
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        primaryDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        if secondaryDelegate !== primaryDelegate {
            secondaryDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        }
    }
    
    public func navigationControllerSupportedInterfaceOrientations(
        _ navigationController: UINavigationController
    ) -> UIInterfaceOrientationMask {
        if let primary = primaryDelegate,
           let mask = primary.navigationControllerSupportedInterfaceOrientations?(navigationController) {
            return mask
        }
        if let secondary = secondaryDelegate,
           let mask = secondary.navigationControllerSupportedInterfaceOrientations?(navigationController) {
            return mask
        }
        return .allButUpsideDown
    }
    
    public func navigationControllerPreferredInterfaceOrientationForPresentation(
        _ navigationController: UINavigationController
    ) -> UIInterfaceOrientation {
        if let primary = primaryDelegate,
           let orientation = primary.navigationControllerPreferredInterfaceOrientationForPresentation?(navigationController) {
            return orientation
        }
        if let secondary = secondaryDelegate,
           let orientation = secondary.navigationControllerPreferredInterfaceOrientationForPresentation?(navigationController) {
            return orientation
        }
        return .portrait
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        if let primary = primaryDelegate,
           let controller = primary.navigationController?(navigationController, interactionControllerFor: animationController) {
            return controller
        }
        if let secondary = secondaryDelegate,
           let controller = secondary.navigationController?(navigationController, interactionControllerFor: animationController) {
            return controller
        }
        return nil
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        if let primary = primaryDelegate,
           let animator = primary.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC) {
            return animator
        }
        if let secondary = secondaryDelegate,
           let animator = secondary.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC) {
            return animator
        }
        return nil
    }
    
    public override func responds(to aSelector: Selector?) -> Bool {
        guard let selector = aSelector else { return false }
        if super.responds(to: selector) { return true }
        let primaryResponds = primaryDelegate?.responds(to: selector) ?? false
        let secondaryResponds = secondaryDelegate?.responds(to: selector) ?? false
        return primaryResponds || secondaryResponds
    }
    
    public override func forwardingTarget(for aSelector: Selector?) -> Any? {
        guard let selector = aSelector else { return nil }
        if let primary = primaryDelegate, primary.responds(to: selector) {
            return primary
        }
        if let secondary = secondaryDelegate, secondary.responds(to: selector) {
            return secondary
        }
        return super.forwardingTarget(for: selector)
    }
}
