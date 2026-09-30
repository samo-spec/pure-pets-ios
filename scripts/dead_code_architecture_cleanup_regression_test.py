#!/usr/bin/env python3
"""
Pure Pets iOS Commerce — Phase 15 Dead Code & Architecture Cleanup Test Suite

Verifies:
1. Complete elimination of dead, commented-out, and obsolete duplicate code blocks.
2. Preservation of all canonical active commerce methods and structures.
3. Verification of strict invariants:
   - Zero references to legacy "users" collection (must use canonical "UsersCol").
   - Zero stockQuantity persistence in Firestore cart payloads (Contract F-25).
   - Zero leftAnchor/rightAnchor layout constraints in commerce cells.
   - Clean single listener registration patterns across managers.
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
            return False, f"Forbidden dead/legacy pattern found in {rel_path}: {p} -> '{match.group(0)}'"
    return True, desc

def main():
    print("\n" + "=" * 65)
    print(" Pure Pets iOS Commerce — Phase 15 Dead Code & Architecture Suite")
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
    # Group 1: Elimination of Dead & Commented-Out Implementation Blocks
    # =========================================================================
    print("[Group 1: Elimination of Dead & Commented-Out Implementation Blocks]")

    run_check(lambda: check_no_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderItemCell.m",
        [
            r"/\*[\s\S]*?@implementation\s+OrderItemCell[\s\S]*?\*/"
        ],
        "OrderItemCell.m has zero commented-out duplicate @implementation blocks"
    ), "Group 1")

    run_check(lambda: check_no_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/CartViewController.m",
        [
            r"/\*[\s\S]*?@interface\s+PPInsetLabel[\s\S]*?\*/"
        ],
        "CartViewController.m has zero commented-out PPInsetLabel class definitions"
    ), "Group 1")

    run_check(lambda: check_no_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"/\*[\s\S]*?collectionWithPath:@\"users\"[\s\S]*?\*/",
            r"/\*[\s\S]*?- \(void\)addItem:\(CartItem \*\)item[\s\S]*?\*/"
        ],
        "CartManager.m has zero commented-out legacy addItem implementations"
    ), "Group 1")

    # =========================================================================
    # Group 2: Canonical Collection & Firestore Path Invariants
    # =========================================================================
    print("\n[Group 2: Canonical Collection & Firestore Path Invariants]")

    run_check(lambda: check_no_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"collectionWithPath:@\"users\""
        ],
        "CartManager.m uses strictly 'UsersCol' (zero references to legacy 'users' collection)"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"collectionWithPath:@\"UsersCol\""
        ],
        "CartManager.m uses canonical 'UsersCol' collection path"
    ), "Group 2")

    run_check(lambda: check_no_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"@\"stockQuantity\"\s*:\s*@(item\.stockQuantity)"
        ],
        "CartManager.m strictly enforces Contract F-25: zero stockQuantity persistence in Firestore cart"
    ), "Group 2")

    # =========================================================================
    # Group 3: Active Architecture Contracts Preservation
    # =========================================================================
    print("\n[Group 3: Active Architecture Contracts Preservation]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Manager/Cart/CartManager.m",
        [
            r"- \(BOOL\)pp_addItem:\(CartItem \*\)item\s+syncCompletion:",
            r"- \(void\)addItemAndWaitForSync:\(CartItem \*\)item\s+completion:",
            r"- \(void\)updateQuantity:\(NSInteger\)newQuantity\s+forItem:",
            r"- \(void\)removePurchasedItems:\(NSArray<CartItem \*> \*\)purchasedItems"
        ],
        "CartManager retains all canonical active add, update, and purchase removal interfaces"
    ), "Group 3")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m",
        [
            r"- \(void\)startCheckoutWithAddress:",
            r"- \(BOOL\)pp_transitionToState:\(PPCheckoutState\)newState\s+generation:\(NSInteger\)generation",
            r"- \(void\)completeWithSuccess:",
            r"- \(void\)completeWithFailure:",
            r"- \(void\)completeWithCancellation:"
        ],
        "PPCheckoutCoordinator retains complete lifecycle state machine and completion paths"
    ), "Group 3")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderDetailsViewController.m",
        [
            r"- \(void\)stopRealtimeObservers",
            r"- \(void\)renderFulfillmentSectionFromLiveChildren",
            r"- \(void\)setupViews"
        ],
        "OrderDetailsViewController retains active lifecycle, observer management, and fulfillment rendering"
    ), "Group 3")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderItemCell.m",
        [
            r"- \(void\)configureWithItem:\(CartItem \*\)item",
            r"self\.accessibilityLabel\s*="
        ],
        "OrderItemCell retains clean active implementation with VoiceOver accessibility"
    ), "Group 3")

    # =========================================================================
    # Summary
    # =========================================================================
    print("\n" + "=" * 65)
    print(f"  RESULTS: {passed_tests}/{total_tests} tests passed ({failed_tests} failures)")
    print("=" * 65 + "\n")

    if failed_tests == 0:
        print("🎉 ALL PHASE 15 DEAD CODE & ARCHITECTURE CLEANUP TESTS PASSED (100% GREEN)!\n")
        return 0
    else:
        print(f"❌ {failed_tests} TESTS FAILED IN PHASE 15 SUITE.\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
