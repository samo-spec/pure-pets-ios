//
//  PPRootSwiftCoordinator.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import Combine
import SwiftUI
import UIKit

/// Main coordinator orchestrating SwiftUI UIHostingController overlays, navigation controller proxies,
/// lifecycle hooks, and state synchronization for the Root container.
@MainActor
@objc(PPRootSwiftCoordinator)
public final class PPRootSwiftCoordinator: NSObject, UITabBarControllerDelegate, UINavigationControllerDelegate {
    public private(set) weak var hostController: UITabBarController?
    public let store: PPRootStore
    
    private var bottomOverlayController: PPRootPassthroughHostingController<PPRootBottomOverlayView>?
    private var blockedAccountController: PPRootPassthroughHostingController<PPBlockedAccountOverlayView>?
    
    private var navigationProxies: [ObjectIdentifier: PPRootNavigationDelegateProxy] = [:]
    private var originalNavigationDelegates: [ObjectIdentifier: weak_ref_delegate] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private var adapter: PPRootObjCAdapter?
    private var useLegacyBar: Bool
    private var isStarted = false
    
    @objc public init(hostController: UITabBarController, useLegacyBar: Bool = false) {
        self.hostController = hostController
        self.useLegacyBar = useLegacyBar
        
        let adapter = PPRootObjCAdapter(targetController: hostController)
        self.adapter = adapter
        self.store = PPRootStore(actionHandler: adapter)
        
        super.init()
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
    
    // MARK: - Lifecycle Management
    
    @objc public func start() {
        guard let host = hostController, !isStarted else { return }
        isStarted = true
        
        print("🚀 [PurePets SwiftUI Root] PPRootSwiftCoordinator STARTED. Overlay views installed.")
        
        store.setUsesLegacyBar(useLegacyBar)
        
        // Wrap navigation controller delegates using proxy to prevent overriding existing delegates (Fixes Risk #4)
        attachNavigationProxies(in: host)
        
        // Embed UIHostingControllers with hit-test pass-through (Fixes Risk #2)
        installBottomOverlay(in: host)
        installBlockedOverlay(in: host)
        
        bindStoreState()
        applySystemTabBarState()
        
        store.start()
    }
    
    @objc public func stop() {
        guard isStarted else { return }
        
        print("🏛️ [PurePets SwiftUI Root] PPRootSwiftCoordinator STOPPED. Overlay views removed.")
        
        store.stop()
        cancellables.removeAll()
        
        detachNavigationProxies()
        
        bottomOverlayController?.willMove(toParent: nil)
        bottomOverlayController?.view.removeFromSuperview()
        bottomOverlayController?.removeFromParent()
        bottomOverlayController = nil
        
        blockedAccountController?.willMove(toParent: nil)
        blockedAccountController?.view.removeFromSuperview()
        blockedAccountController?.removeFromParent()
        blockedAccountController = nil
        
        isStarted = false
    }
    
    @objc public func viewWillAppear(animated: Bool) {
        store.refreshAllState()
        applySystemTabBarState()
    }
    
    @objc public func viewDidAppear(animated: Bool) {
        store.refreshAllState()
        store.refreshSurfaceForTopViewController()
        applySystemTabBarState()
    }
    
    @objc public func viewDidLayoutSubviews() {
        applySystemTabBarState()
        updateOverlayZIndex()
    }
    
    // MARK: - Public Objective-C Interoperability API
    
    @objc public func setUsesLegacyBar(_ enabled: Bool) {
        useLegacyBar = enabled
        store.setUsesLegacyBar(enabled)
        applySystemTabBarState()
    }
    
    @objc public func setBottomNavigationHidden(_ hidden: Bool, animated: Bool) {
        store.setExternallyHidden(hidden, animated: animated)
    }
    
    @objc public func setDockHidden(_ hidden: Bool, animated: Bool) {
        store.setDockHidden(hidden, animated: animated)
    }
    
    @objc public func currentBottomNavigationContentClearance() -> CGFloat {
        store.computedBottomContentClearance
    }
    
    @objc public func activateFloatingCart(
        sourceViewController: UIViewController,
        openCartHandler: @escaping () -> Void,
        animated: Bool
    ) {
        store.activateFloatingCart(
            sourceViewController: sourceViewController,
            openCartHandler: openCartHandler,
            animated: animated
        )
    }
    
    @objc public func deactivateFloatingCart(sourceViewController: UIViewController, animated: Bool) {
        store.deactivateFloatingCart(sourceViewController: sourceViewController, animated: animated)
    }
    
    @objc public func openChatThreadFromNotification(thread: Any, animated: Bool) -> Bool {
        guard let adapter = adapter else { return false }
        return adapter.handleOpenChatThreadNotification(thread: thread, animated: animated)
    }
    
    // MARK: - UITabBarControllerDelegate
    
    public func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController),
              let tab = PPRootTab(rawValue: index) else { return true }
        
        if tab == .create {
            store.selectTab(.create)
            return false
        }
        
        if store.sessionState.isAnyBlocked {
            store.refreshAllState()
            return false
        }
        
        return true
    }
    
    public func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController),
              let tab = PPRootTab(rawValue: index) else { return }
        
        store.selectTab(tab)
    }
    
    // MARK: - UINavigationControllerDelegate
    
    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        applySystemTabBarState()
        store.refreshSurfaceForTopViewController()
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        applySystemTabBarState()
        store.refreshSurfaceForTopViewController()
    }
    
    // MARK: - Private Installations & Proxying
    
    private func installBottomOverlay(in host: UITabBarController) {
        let rootView = PPRootBottomOverlayView(store: store)
        let hostingController = PPRootPassthroughHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        hostingController.isInteractivePoint = { [weak self] point in
            guard let self = self, let host = self.hostController else { return false }
            let totalHeight = host.view.bounds.height
            let dockInteractiveHeight = max(self.store.bottomOverlayHeight, 88.0) + 32.0
            return point.y >= (totalHeight - dockInteractiveHeight)
        }
        
        host.addChild(hostingController)
        host.view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: host)
        self.bottomOverlayController = hostingController
    }
    
    private func installBlockedOverlay(in host: UITabBarController) {
        let rootView = PPBlockedAccountOverlayView(store: store)
        let hostingController = PPRootPassthroughHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        hostingController.isInteractivePoint = { [weak self] _ in
            guard let self = self else { return false }
            return self.store.sessionState.isAnyBlocked
        }
        
        host.addChild(hostingController)
        host.view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: host)
        self.blockedAccountController = hostingController
    }
    
    private func bindStoreState() {
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateOverlayZIndex()
                }
            }
            .store(in: &cancellables)
    }
    
    private func applySystemTabBarState() {
        guard let host = hostController else { return }
        if !useLegacyBar {
            host.tabBar.isHidden = true
            host.tabBar.alpha = 0.0
            host.tabBar.isUserInteractionEnabled = false
        } else {
            host.tabBar.isHidden = store.isExternallyHidden
            host.tabBar.alpha = store.isExternallyHidden ? 0.0 : 1.0
            host.tabBar.isUserInteractionEnabled = !store.isExternallyHidden
        }
    }
    
    private func updateOverlayZIndex() {
        guard let host = hostController else { return }
        
        let blocked = store.sessionState.isAnyBlocked
        
        if let blockedView = blockedAccountController?.view {
            blockedView.isHidden = !blocked
            if blocked {
                host.view.bringSubviewToFront(blockedView)
            }
        }
        
        if let bottomView = bottomOverlayController?.view {
            bottomView.isHidden = blocked || !store.shouldShowBottomOverlay
            if !blocked && store.shouldShowBottomOverlay {
                host.view.bringSubviewToFront(bottomView)
            }
        }
    }
    
    private func attachNavigationProxies(in host: UITabBarController) {
        guard let viewControllers = host.viewControllers else { return }
        for vc in viewControllers {
            if let nav = vc as? UINavigationController {
                let key = ObjectIdentifier(nav)
                let existingDelegate = nav.delegate
                originalNavigationDelegates[key] = weak_ref_delegate(existingDelegate)
                
                let proxy = PPRootNavigationDelegateProxy(primary: self, secondary: existingDelegate)
                navigationProxies[key] = proxy
                nav.delegate = proxy
            }
        }
    }
    
    private func detachNavigationProxies() {
        guard let viewControllers = hostController?.viewControllers else {
            navigationProxies.removeAll()
            originalNavigationDelegates.removeAll()
            return
        }
        for vc in viewControllers {
            if let nav = vc as? UINavigationController {
                let key = ObjectIdentifier(nav)
                if let originalBox = originalNavigationDelegates[key] {
                    nav.delegate = originalBox.value
                }
            }
        }
        navigationProxies.removeAll()
        originalNavigationDelegates.removeAll()
    }
}

private final class weak_ref_delegate {
    weak var value: UINavigationControllerDelegate?
    init(_ value: UINavigationControllerDelegate?) { self.value = value }
}
