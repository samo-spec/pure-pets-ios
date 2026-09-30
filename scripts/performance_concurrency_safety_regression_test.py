#!/usr/bin/env python3
"""
Pure Pets iOS Commerce — Phase 14 Performance & Concurrency Safety Test Suite

Comprehensive contract & source verification across all consumer iOS commerce surfaces:
1. Listener Single-Registration, Deduplication & Guaranteed Teardown.
2. Generational Guarding & Stale Async Callback Dropping.
3. Cart Mutex Locking, Pending Sync Tracking & Resurrection Prevention.
4. Targeted Single-Document Mutations vs Full-Collection Rewrites.
5. Hot UI Path Reload Debouncing & Notification Suppression.
6. Checkout Single-Execution Gate, Race-Free State Transitions & Idempotency Cleanup.
"""

import os
import re
import sys

IOS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Pure Pets"))

def check_file_patterns(rel_path, patterns, desc):
    abs_path = os.path.join(IOS_ROOT, rel_path)
    if not os.path.exists(abs_path):
        return False, f"Missing file: {rel_path}"
    with open(abs_path, "r", encoding="utf-8") as f:
        content = f.read()
    for p in patterns:
        if not re.search(p, content):
            return False, f"Pattern not found in {rel_path}: {p}"
    return True, desc

def check_no_patterns(rel_path, patterns, desc):
    abs_path = os.path.join(IOS_ROOT, rel_path)
    if not os.path.exists(abs_path):
        return False, f"Missing file: {rel_path}"
    with open(abs_path, "r", encoding="utf-8") as f:
        content = f.read()
    for p in patterns:
        match = re.search(p, content)
        if match:
            return False, f"Forbidden pattern found in {rel_path}: {p} -> {match.group(0)}"
    return True, desc

def main():
    print("\n" + "=" * 65)
    print(" Pure Pets iOS Commerce — Phase 14 Performance & Concurrency Suite")
    print("=" * 65 + "\n")

    total_tests = 0
    passed_tests = 0
    failed_tests = 0

    def run_check(fn, group_name):
        nonlocal total_tests, passed_tests, failed_tests
        total_tests += 1
        ok, msg = fn()
        if ok:
            passed_tests += 1
            print(f"  ✅ PASS: {msg}")
        else:
            failed_tests += 1
            print(f"  ❌ FAIL [{group_name}]: {msg}")

    # =========================================================================
    # Group 1: Listener Single-Registration, Deduplication & Teardown
    # =========================================================================
    print("[Group 1: Listener Single-Registration, Deduplication & Teardown]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"\[self\.cartListener\s+remove\];\s*self\.cartListener\s*=\s*nil;",
            r"- \(void\)stopListeningToCartChanges\s*\{[\s\S]*?\[self\.cartListener\s+remove\];[\s\S]*?self\.cartListener\s*=\s*nil;",
            r"- \(void\)dealloc\s*\{[\s\S]*?\[self\.cartListener\s+remove\];[\s\S]*?self\.cartListener\s*=\s*nil;"
        ],
        "CartManager prevents stacked listeners and guarantees teardown on stop and dealloc"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m",
        [
            r"- \(void\)cleanup\s*\{[\s\S]*?\[self\.orderListener\s+remove\];[\s\S]*?self\.orderListener\s*=\s*nil;",
            r"if\s*\(self\.orderListener\)\s*\{\s*\[self\.orderListener\s+remove\];\s*self\.orderListener\s*=\s*nil;\s*\}"
        ],
        "PPCheckoutCoordinator removes and nils order listener during terminal cleanup and success"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderDetailsViewController.m",
        [
            r"- \(void\)stopRealtimeObservers\s*\{[\s\S]*?\[self\.orderDocumentListener\s+remove\];[\s\S]*?\[self\.requestsListener\s+remove\];[\s\S]*?\[self\.timelineListener\s+remove\];",
            r"- \(void\)stopFulfillmentDocumentListeners\s*\{[\s\S]*?for\s*\(id<FIRListenerRegistration>\s+listener\s+in\s+self\.fulfillmentDocumentListeners\.allValues\.copy\)\s*\{\s*\[listener\s+remove\];\s*\}"
        ],
        "OrderDetailsViewController cleanly dismantles parent order, support, timeline, and fulfillment listeners"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderDetailsMissionControlBridge.m",
        [
            r"for\s*\(id<FIRListenerRegistration>\s+registration\s+in\s+self\.fulfillmentListeners\.allValues\)\s*\{\s*\[registration\s+remove\];\s*\}"
        ],
        "PPOrderDetailsMissionControlBridge cleans up all child fulfillment listeners"
    ), "Group 1")

    # =========================================================================
    # Group 2: Generational Guarding & Stale Async Callback Dropping
    # =========================================================================
    print("\n[Group 2: Generational Guarding & Stale Async Callback Dropping]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m",
        [
            r"@property\s*\(nonatomic,\s*assign\)\s*NSInteger\s*checkoutGeneration;",
            r"- \(BOOL\)pp_isCheckoutGenerationCurrent:\(NSInteger\)generation",
            r"- \(BOOL\)pp_beginTerminalResolutionForGeneration:\(NSInteger\)generation\s+label:\(NSString\s*\*\)label\s*\{[\s\S]*?if\s*\(!\[self\s+pp_isCheckoutGenerationCurrent:generation\]\)\s*\{[\s\S]*?return\s+NO;\s*\}[\s\S]*?if\s*\(self\.hasResolvedCheckout\)\s*\{[\s\S]*?return\s+NO;\s*\}[\s\S]*?self\.hasResolvedCheckout\s*=\s*YES;\s*return\s+YES;\s*\}"
        ],
        "PPCheckoutCoordinator gates resolution with generation counter and drops duplicate or stale terminal callbacks"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderDetailsViewController.m",
        [
            r"self\.realtimeObserverGeneration\s*\+=\s*1;",
            r"- \(BOOL\)isRealtimeObserverGenerationCurrent:\(NSInteger\)generation",
            r"return generation\s*==\s*self\.realtimeObserverGeneration\s*&&"
        ],
        "OrderDetailsViewController invalidates and ignores stale background order snapshots via generation matching"
    ), "Group 2")

    # =========================================================================
    # Group 3: Cart Mutex Locking, Pending Sync Tracking & Resurrection Prevention
    # =========================================================================
    print("\n[Group 3: Cart Mutex Locking & Resurrection Prevention]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"@synchronized\s*\(self\)\s*\{[\s\S]*?if\s*\(self\.isLocked\)\s*\{[\s\S]*?return\s+NO;\s*\}[\s\S]*?self\.isLocked\s*=\s*YES;\s*\}",
            r"@finally\s*\{\s*self\.isLocked\s*=\s*NO;\s*\}"
        ],
        "CartManager guards local mutation with @synchronized and guarantees lock release in @finally block"
    ), "Group 3")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"@synchronized\s*\(self\.pendingDeletedItemKeys\)\s*\{[\s\S]*?isDeletedLocally\s*=\s*\[self\.pendingDeletedItemKeys\s+containsObject:cartKey\];\s*\}",
            r"if\s*\(isDeletedLocally\)\s*\{\s*continue;\s*\}"
        ],
        "CartManager checks pendingDeletedItemKeys in remote snapshot loop to prevent resurrection of deleted items"
    ), "Group 3")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"@synchronized\s*\(self\.pendingSyncItemKeys\)\s*\{[\s\S]*?\[self\.pendingSyncItemKeys\s+addObject:cartKey\];\s*\}",
            r"current\.quantity\s*=\s*previousQuantity;",
            r"current\.stockQuantity\s*=\s*previousStock;"
        ],
        "CartManager tracks pending sync keys and automatically rolls back quantity on network failure"
    ), "Group 3")

    # =========================================================================
    # Group 4: Targeted Single-Document Mutations vs Full-Collection Rewrites
    # =========================================================================
    print("\n[Group 4: Targeted Single-Document Mutations vs Full Rewrites]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"FIRDocumentReference\s*\*itemRef\s*=\s*\[\[\[\[db\s+collectionWithPath:@\"UsersCol\"\][\s\S]*?documentWithPath:item\.itemID\];",
            r"\[itemRef\s+setData:payload\s+merge:YES\s+completion:"
        ],
        "CartManager quantity update mutates only the specific item document without full cart rewrite"
    ), "Group 4")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"for\s*\(CartItem\s*\*removed\s+in\s+itemsToRemoveCompletely\)\s*\{\s*\[batch\s+deleteDocument:\[cartItemsRef\s+documentWithPath:removed\.itemID\]\];\s*\}"
        ],
        "CartManager removePurchasedItems deletes only purchased item documents in an atomic batch"
    ), "Group 4")

    # =========================================================================
    # Group 5: Hot UI Path Reload Debouncing & Notification Suppression
    # =========================================================================
    print("\n[Group 5: Hot UI Path Reload Debouncing & Notification Suppression]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/CartViewController.m",
        [
            r"if\s*\(self\.pendingQuantitySyncReloadSkips\s*>\s*0\)\s*\{[\s\S]*?\[self\s+updateTotalLabel\];\s*return;\s*\}",
            r"if\s*\(self\.isPerformingTableMutation\)\s*\{\s*NSLog\(@\"\[CART\]\s*🔁\s*Skipping reload during table mutation\"\);\s*return;\s*\}"
        ],
        "CartViewController skips heavy table reload when quantity is edited in-place or during table animation"
    ), "Group 5")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/CartViewController.m",
        [
            r"- \(void\)dealloc\s*\{[\s\S]*?\[\[NSNotificationCenter\s+defaultCenter\]\s+removeObserver:self\];"
        ],
        "CartViewController cleans up notification center observations in dealloc"
    ), "Group 5")

    # =========================================================================
    # Group 6: Checkout Single-Execution Gate, Lock & Idempotency Cleanup
    # =========================================================================
    print("\n[Group 6: Checkout Single-Execution Gate, Lock & Idempotency Cleanup]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m",
        [
            r"if\s*\(self\.isCheckoutInProgress\)\s*\{[\s\S]*?kLang\(@\"payment_request_in_progress\"\)[\s\S]*?return;\s*\}",
            r"if\s*\(self\.awaitingServerCancellationConfirmation\)\s*\{[\s\S]*?kLang\(@\"checkout_payment_cancellation_pending_message\"\)[\s\S]*?return;\s*\}"
        ],
        "PPCheckoutCoordinator blocks re-entrant checkouts when busy or when server cancellation is pending"
    ), "Group 6")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m",
        [
            r"\[cart\s+setValue:@\(YES\)\s+forKey:@\"_isLocked\"\];",
            r"self\.hasLockedSharedCart\s*=\s*YES;",
            r"self\.checkoutIdempotencyKey\s*=\s*nil;",
            r"PPCheckoutCompletion\s*completion\s*=\s*self\.completion;\s*self\.completion\s*=\s*nil;"
        ],
        "PPCheckoutCoordinator locks cart, clears idempotency key on order placed, and zeros completion callback"
    ), "Group 6")

    # =========================================================================
    # Summary
    # =========================================================================
    print("\n" + "=" * 65)
    print(f"  RESULTS: {passed_tests}/{total_tests} tests passed ({failed_tests} failures)")
    print("=" * 65 + "\n")

    if failed_tests == 0:
        print("🎉 ALL PHASE 14 PERFORMANCE & CONCURRENCY TESTS PASSED (100% GREEN)!\n")
        return 0
    else:
        print(f"❌ {failed_tests} TESTS FAILED IN PHASE 14 SUITE.\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
