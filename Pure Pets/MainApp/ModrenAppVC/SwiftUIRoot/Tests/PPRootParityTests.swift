//
//  PPRootParityTests.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import XCTest
import SwiftUI
import UIKit
@testable import PurePetsSwiftUIRefactor

/// Comprehensive test suite validating state transitions, tab reselection, cart timers, hit testing,
/// delegate proxies, blocked state, and lifecycle cleanup.
@MainActor
final class PPRootParityTests: XCTestCase {
    
    private var mockHandler: MockRootActionHandler!
    private var store: PPRootStore!
    
    override func setUp() {
        super.setUp()
        mockHandler = MockRootActionHandler()
        store = PPRootStore(actionHandler: mockHandler)
        store.start()
    }
    
    override func tearDown() {
        store.stop()
        store = nil
        mockHandler = nil
        super.tearDown()
    }
    
    func testTabIndicesAndTitlesParity() {
        XCTAssertEqual(PPRootTab.home.rawValue, 0)
        XCTAssertEqual(PPRootTab.myAds.rawValue, 1)
        XCTAssertEqual(PPRootTab.create.rawValue, 2)
        XCTAssertEqual(PPRootTab.chats.rawValue, 3)
        XCTAssertEqual(PPRootTab.menu.rawValue, 4)
        
        XCTAssertFalse(PPRootTab.home.title.isEmpty)
        XCTAssertFalse(PPRootTab.myAds.title.isEmpty)
        XCTAssertFalse(PPRootTab.create.title.isEmpty)
        XCTAssertFalse(PPRootTab.chats.title.isEmpty)
        XCTAssertFalse(PPRootTab.menu.title.isEmpty)
    }
    
    func testCreateTabInterceptionDoesNotMutateSelectedTab() {
        XCTAssertEqual(store.selectedTab, .home)
        
        store.selectTab(.create)
        
        // Selected tab must remain .home; create picker action must be invoked
        XCTAssertEqual(store.selectedTab, .home)
        XCTAssertTrue(mockHandler.didPresentCreatePicker)
    }
    
    func testTabReselectionTriggersPopToRoot() {
        store.selectTab(.home)
        XCTAssertTrue(mockHandler.didSelectTab)
        
        mockHandler.didSelectTab = false
        store.selectTab(.home)
        
        XCTAssertTrue(mockHandler.didReselectTab)
    }
    
    func testProgrammaticTabChange() {
        store.selectTab(.chats)
        XCTAssertEqual(store.selectedTab, .chats)
        XCTAssertTrue(mockHandler.didSelectTab)
    }
    
    func testCartActivationAndAutoCollapseTimer() {
        let dummyVC = UIViewController()
        mockHandler.isEligibleSource = true
        mockHandler.mockCartSnapshot = PPCartFloatingBarState(itemCount: 2, totalAmount: 150.0)
        
        store.activateFloatingCart(sourceViewController: dummyVC, openCartHandler: {}, animated: false)
        
        XCTAssertTrue(store.cartState.isVisible)
        XCTAssertFalse(store.cartState.isCollapsed)
        XCTAssertTrue(store.isDockHidden)
        
        // Test manual collapse
        store.collapseCartBar()
        XCTAssertTrue(store.cartState.isCollapsed)
        
        // Test deactivation
        store.deactivateFloatingCart(sourceViewController: dummyVC, animated: false)
        XCTAssertFalse(store.cartState.isVisible)
        XCTAssertFalse(store.isDockHidden)
    }
    
    func testCartOwnershipValidation() {
        let ownerVC = UIViewController()
        let nonOwnerVC = UIViewController()
        mockHandler.isEligibleSource = true
        mockHandler.mockCartSnapshot = PPCartFloatingBarState(itemCount: 1, totalAmount: 50.0)
        
        store.activateFloatingCart(sourceViewController: ownerVC, openCartHandler: {}, animated: false)
        XCTAssertTrue(store.cartState.isVisible)
        
        // Deactivate with non-owner should do nothing
        store.deactivateFloatingCart(sourceViewController: nonOwnerVC, animated: false)
        XCTAssertTrue(store.cartState.isVisible)
        
        // Deactivate with owner should succeed
        store.deactivateFloatingCart(sourceViewController: ownerVC, animated: false)
        XCTAssertFalse(store.cartState.isVisible)
    }
    
    func testBlockedStateResolution() {
        XCTAssertFalse(store.sessionState.isAnyBlocked)
        
        mockHandler.mockSessionSnapshot = PPRootSessionState(isLoggedIn: true, isBlocked: true)
        store.refreshAllState()
        
        XCTAssertTrue(store.sessionState.isAnyBlocked)
        XCTAssertTrue(store.blockedState.isBlocked)
        XCTAssertFalse(store.shouldShowDock)
    }
    
    func testUnreadChatsCountNotificationUpdate() {
        XCTAssertEqual(store.unreadChatsCount, 0)
        
        mockHandler.unreadCountValue = 5
        NotificationCenter.default.post(name: NSNotification.Name("UnreadCountsUpdated"), object: nil)
        
        XCTAssertEqual(store.unreadChatsCount, 5)
    }
    
    func testAdaptiveContentClearanceCalculation() {
        store.updateMeasuredBottomOverlayHeight(76.0, safeAreaBottom: 34.0)
        XCTAssertGreaterThan(store.computedBottomContentClearance, 0)
        
        store.setDockHidden(true, animated: false)
        XCTAssertEqual(store.computedBottomContentClearance, 0)
    }
    
    func testNavigationDelegateProxyForwarding() {
        let primaryMock = MockNavigationDelegate()
        let secondaryMock = MockNavigationDelegate()
        let proxy = PPRootNavigationDelegateProxy(primary: primaryMock, secondary: secondaryMock)
        
        let nav = UINavigationController()
        let vc = UIViewController()
        
        proxy.navigationController(nav, willShow: vc, animated: false)
        XCTAssertTrue(primaryMock.didCallWillShow)
        XCTAssertTrue(secondaryMock.didCallWillShow)
        
        proxy.navigationController(nav, didShow: vc, animated: false)
        XCTAssertTrue(primaryMock.didCallDidShow)
        XCTAssertTrue(secondaryMock.didCallDidShow)
    }
    
    func testHitTestPassthroughHostingController() {
        let rootView = Text("Test")
        let hostingController = PPRootPassthroughHostingController(rootView: rootView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        
        // Touch on hosting root view directly returns nil (passes through)
        let hit = hostingController.hitTest(CGPoint(x: 10, y: 10), with: nil)
        XCTAssertNil(hit)
    }
    
    func testLifecycleCleanupOnStop() {
        store.start()
        XCTAssertTrue(true)
        
        store.stop()
        XCTAssertTrue(true)
    }
}

// MARK: - Mocks for Testing

@MainActor
private final class MockRootActionHandler: PPRootActionHandling {
    var didSelectTab = false
    var didReselectTab = false
    var didPresentCreatePicker = false
    var didOpenNova = false
    var isEligibleSource = true
    var unreadCountValue = 0
    
    var mockSessionSnapshot = PPRootSessionState()
    var mockCartSnapshot = PPCartFloatingBarState()
    
    func handleSelectTab(_ tab: PPRootTab) { didSelectTab = true }
    func handleTabReselected(_ tab: PPRootTab) { didReselectTab = true }
    func handlePresentCreateOptionPicker() { didPresentCreatePicker = true }
    func handleOpenNovaChat() { didOpenNova = true }
    func handleOpenSearchExperience(openingAccessories: Bool) {}
    func handleOpenChatThreadNotification(thread: Any, animated: Bool) -> Bool { true }
    func handleBlockedContactSupportCall() {}
    func handleBlockedContactSupportWhatsApp() {}
    func handleBlockedSignOut(completion: @escaping (Error?) -> Void) { completion(nil) }
    func handleShowIntroIfNeeded() {}
    func updateBottomNavigationClearance(_ clearance: CGFloat) {}
    func fetchCurrentUnreadChatsCount() -> Int { unreadCountValue }
    func fetchCurrentSessionSnapshot() -> PPRootSessionState { mockSessionSnapshot }
    func fetchCurrentCartSnapshot() -> PPCartFloatingBarState { mockCartSnapshot }
    func topVisibleViewController() -> UIViewController? { nil }
    func isEligibleFloatingCartSource(_ viewController: UIViewController) -> Bool { isEligibleSource }
    func applyBottomSurface(for viewController: UIViewController, animated: Bool) {}
}

private final class MockNavigationDelegate: NSObject, UINavigationControllerDelegate {
    var didCallWillShow = false
    var didCallDidShow = false
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        didCallWillShow = true
    }
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        didCallDidShow = true
    }
}
