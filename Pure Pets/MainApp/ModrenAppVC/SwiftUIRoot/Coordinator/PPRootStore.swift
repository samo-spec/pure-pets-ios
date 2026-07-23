//
//  PPRootStore.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import Combine
import SwiftUI
import UIKit

/// Single source of truth for the SwiftUI Root hierarchy owning reactive states,
/// cart collapse timers, notification subscriptions, and action dispatches via typed handler protocol.
@MainActor
public final class PPRootStore: ObservableObject {
    @Published public private(set) var selectedTab: PPRootTab = .home
    @Published public private(set) var lastSelectedTab: PPRootTab = .home
    @Published public private(set) var unreadChatsCount: Int = 0
    @Published public private(set) var sessionState: PPRootSessionState = .init()
    @Published public private(set) var cartState: PPCartFloatingBarState = .init()
    @Published public private(set) var novaState: PPRootNovaState = .init()
    @Published public private(set) var blockedState: PPBlockedAccountState = .init()
    
    @Published public private(set) var isDockHidden: Bool = false
    @Published public private(set) var isExternallyHidden: Bool = false
    @Published public private(set) var useLegacyBar: Bool = false
    @Published public private(set) var bottomOverlayHeight: CGFloat = 0.0
    @Published public private(set) var activeSafeAreaBottom: CGFloat = 0.0
    
    public private(set) weak var actionHandler: PPRootActionHandling?
    
    private var notificationTokens: [NSObjectProtocol] = []
    private var collapseTimer: Timer?
    private var activeSourceViewController: weak_ref<UIViewController>?
    private var cartOpenHandler: (() -> Void)?
    private var isStarted = false
    
    public init(actionHandler: PPRootActionHandling? = nil) {
        self.actionHandler = actionHandler
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
    
    public func setActionHandler(_ handler: PPRootActionHandling) {
        self.actionHandler = handler
    }
    
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        
        installNotificationObservers()
        refreshAllState()
        
        if let handler = actionHandler {
            handler.handleShowIntroIfNeeded()
        }
    }
    
    public func stop() {
        invalidateCollapseTimer()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        isStarted = false
    }
    
    // MARK: - Reactive Visibility Rules
    
    public var shouldShowDock: Bool {
        !useLegacyBar && !isExternallyHidden && !isDockHidden && !cartState.isVisible && !sessionState.isAnyBlocked
    }
    
    public var shouldShowCartBar: Bool {
        cartState.isVisible && !sessionState.isAnyBlocked
    }
    
    public var shouldShowNovaButton: Bool {
        novaState.isEffectivelyVisible && !isExternallyHidden && !isDockHidden && !sessionState.isAnyBlocked
    }
    
    public var shouldShowBottomOverlay: Bool {
        shouldShowDock || shouldShowCartBar || shouldShowNovaButton
    }
    
    /// Adaptive safe-area-aware content clearance calculation (Fixes Risk #1).
    public var computedBottomContentClearance: CGFloat {
        if cartState.isVisible {
            let baseBarHeight: CGFloat = 56.0
            return ceil(baseBarHeight + 12.0)
        }
        if isDockHidden || isExternallyHidden {
            return 0.0
        }
        if !useLegacyBar {
            return ceil(bottomOverlayHeight > 0 ? bottomOverlayHeight + 8.0 : 64.0)
        }
        return 8.0
    }
    
    // MARK: - State Mutations & Actions
    
    public func selectTab(_ tab: PPRootTab) {
        if tab == .create {
            PPHaptics.softImpact()
            actionHandler?.handlePresentCreateOptionPicker()
            return
        }
        
        if selectedTab == tab {
            // Tab reselection -> pop to root on navigation stack
            actionHandler?.handleTabReselected(tab)
            PPHaptics.selection()
            return
        }
        
        lastSelectedTab = selectedTab
        selectedTab = tab
        PPHaptics.selection()
        
        actionHandler?.handleSelectTab(tab)
        refreshSurfaceForTopViewController()
    }
    
    public func setUsesLegacyBar(_ enabled: Bool) {
        useLegacyBar = enabled
    }
    
    public func updateMeasuredBottomOverlayHeight(_ height: CGFloat, safeAreaBottom: CGFloat) {
        guard abs(self.bottomOverlayHeight - height) > 0.5 || abs(self.activeSafeAreaBottom - safeAreaBottom) > 0.5 else { return }
        self.bottomOverlayHeight = height
        self.activeSafeAreaBottom = safeAreaBottom
        actionHandler?.updateBottomNavigationClearance(computedBottomContentClearance)
    }
    
    public func setDockHidden(_ hidden: Bool, animated: Bool = true) {
        withAnimation(animated ? .spring(response: 0.35, dampingFraction: 0.85) : nil) {
            isDockHidden = hidden
        }
        actionHandler?.updateBottomNavigationClearance(computedBottomContentClearance)
    }
    
    public func setExternallyHidden(_ hidden: Bool, animated: Bool = true) {
        withAnimation(animated ? .spring(response: 0.35, dampingFraction: 0.85) : nil) {
            isExternallyHidden = hidden
            novaState.isHiddenByBottomNavigation = hidden
        }
        actionHandler?.updateBottomNavigationClearance(computedBottomContentClearance)
    }
    
    public func activateFloatingCart(
        sourceViewController: UIViewController,
        openCartHandler: @escaping () -> Void,
        animated: Bool
    ) {
        guard let handler = actionHandler,
              handler.isEligibleFloatingCartSource(sourceViewController) else { return }
        
        activeSourceViewController = weak_ref(sourceViewController)
        self.cartOpenHandler = openCartHandler
        
        let freshCart = handler.fetchCurrentCartSnapshot()
        guard freshCart.itemCount > 0 else {
            cartState.isVisible = false
            return
        }
        
        withAnimation(animated ? .spring(response: 0.35, dampingFraction: 0.85) : nil) {
            cartState = PPCartFloatingBarState(
                itemCount: freshCart.itemCount,
                totalAmount: freshCart.totalAmount,
                isVisible: true,
                isCollapsed: false
            )
            isDockHidden = true
        }
        
        startCollapseTimer()
        handler.updateBottomNavigationClearance(computedBottomContentClearance)
    }
    
    public func deactivateFloatingCart(sourceViewController: UIViewController, animated: Bool) {
        guard activeSourceViewController?.value === sourceViewController else { return }
        
        invalidateCollapseTimer()
        withAnimation(animated ? .spring(response: 0.35, dampingFraction: 0.85) : nil) {
            cartState.isVisible = false
            cartState.isCollapsed = false
            isDockHidden = false
        }
        
        activeSourceViewController = nil
        cartOpenHandler = nil
        refreshSurfaceForTopViewController()
    }
    
    public func handleCartTapped() {
        PPHaptics.softImpact()
        if cartState.isCollapsed {
            expandCartBar()
            return
        }
        cartOpenHandler?()
    }
    
    public func toggleCartCollapsed() {
        if cartState.isCollapsed {
            expandCartBar()
        } else {
            collapseCartBar()
        }
    }
    
    public func expandCartBar() {
        invalidateCollapseTimer()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            cartState.isCollapsed = false
        }
        startCollapseTimer()
    }
    
    public func collapseCartBar() {
        invalidateCollapseTimer()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            cartState.isCollapsed = true
        }
    }
    
    public func handleNovaTapped() {
        PPHaptics.softImpact()
        actionHandler?.handleOpenNovaChat()
    }
    
    public func handleBlockedContactSupportCall() {
        actionHandler?.handleBlockedContactSupportCall()
    }
    
    public func handleBlockedContactSupportWhatsApp() {
        actionHandler?.handleBlockedContactSupportWhatsApp()
    }
    
    public func handleBlockedSignOut() {
        actionHandler?.handleBlockedSignOut { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllState()
            }
        }
    }
    
    public func refreshAllState() {
        guard let handler = actionHandler else { return }
        sessionState = handler.fetchCurrentSessionSnapshot()
        cartState = handler.fetchCurrentCartSnapshot()
        unreadChatsCount = handler.fetchCurrentUnreadChatsCount()
        
        blockedState = PPBlockedAccountState(
            isBlocked: sessionState.isAnyBlocked,
            brandName: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Pure Pets"
        )
        
        handler.updateBottomNavigationClearance(computedBottomContentClearance)
    }
    
    public func refreshSurfaceForTopViewController() {
        guard let handler = actionHandler,
              let topVC = handler.topVisibleViewController() else { return }
        handler.applyBottomSurface(for: topVC, animated: true)
    }
    
    // MARK: - Private Helpers & Observers
    
    private func startCollapseTimer() {
        invalidateCollapseTimer()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.collapseCartBar()
            }
        }
    }
    
    private func invalidateCollapseTimer() {
        collapseTimer?.invalidate()
        collapseTimer = nil
    }
    
    private func installNotificationObservers() {
        let center = NotificationCenter.default
        
        let unreadToken = center.addObserver(
            forName: NSNotification.Name("UnreadCountsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllState()
            }
        }
        
        let blockedToken = center.addObserver(
            forName: NSNotification.Name("PPUserManagerDidUpdateBlockedStateNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllState()
            }
        }
        
        let accessToken = center.addObserver(
            forName: NSNotification.Name("PPUserManagerDidUpdateUserAccessNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllState()
            }
        }
        
        let novaVisibilityToken = center.addObserver(
            forName: NSNotification.Name("PPNovaFloatingVisibilityDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                if let visible = note.userInfo?["visible"] as? Bool {
                    self?.novaState.isVisibleByConfig = visible
                }
            }
        }
        
        let cartNotificationNames = [
            "CartUpdated",
            "kCartUpdatedNotification",
            "PPCartDidChangeNotification",
            "CartManagerCartDidUpdateNotification"
        ]
        
        for name in cartNotificationNames {
            let token = center.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleCartNotificationReceived()
                }
            }
            notificationTokens.append(token)
        }
        
        let showTabBarToken = center.addObserver(
            forName: NSNotification.Name("PPShowSystemTabBarNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setExternallyHidden(false)
            }
        }
        
        let hideTabBarToken = center.addObserver(
            forName: NSNotification.Name("PPHideSystemTabBarNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setExternallyHidden(true)
            }
        }
        
        notificationTokens.append(contentsOf: [
            unreadToken, blockedToken, accessToken,
            novaVisibilityToken, showTabBarToken, hideTabBarToken
        ])
    }
    
    private func handleCartNotificationReceived() {
        guard let handler = actionHandler else { return }
        
        let freshCart = handler.fetchCurrentCartSnapshot()
        guard let topVC = handler.topVisibleViewController() else { return }
        let isEligible = handler.isEligibleFloatingCartSource(topVC)
        
        if isEligible && freshCart.itemCount > 0 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                cartState = PPCartFloatingBarState(
                    itemCount: freshCart.itemCount,
                    totalAmount: freshCart.totalAmount,
                    isVisible: true,
                    isCollapsed: cartState.isCollapsed
                )
                isDockHidden = true
            }
            PPHaptics.softImpact()
            startCollapseTimer()
        } else if !isEligible {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                cartState = PPCartFloatingBarState(
                    itemCount: freshCart.itemCount,
                    totalAmount: freshCart.totalAmount,
                    isVisible: false,
                    isCollapsed: false
                )
                isDockHidden = false
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                cartState = PPCartFloatingBarState(
                    itemCount: 0,
                    totalAmount: 0.0,
                    isVisible: false,
                    isCollapsed: false
                )
                isDockHidden = false
            }
        }
        
        handler.updateBottomNavigationClearance(computedBottomContentClearance)
        handler.applyBottomSurface(for: topVC, animated: true)
    }
}

/// Utility weak reference box to prevent retain cycles with source UIViewControllers.
private final class weak_ref<T: AnyObject> {
    weak var value: T?
    init(_ value: T?) { self.value = value }
}
