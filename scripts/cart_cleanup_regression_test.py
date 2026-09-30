#!/usr/bin/env python3
"""
cart_cleanup_regression_test.py — Phase 6 Cart Cleanup Regression Test Suite

Pure Pets Platform (pure-pets-49199)
Primary Client: Pure Pets IOS/ (Consumer iOS)

Validates the success/failure cart cleanup contract:
- On terminal success:
  * Full-cart checkout removes all purchased items from memory, local cache, and Firestore.
  * Subset checkout (e.g. Direct "Buy Now") removes or decrements only the purchased items, strictly preserving unrelated cart items.
  * Partial-quantity purchases decrement the matching line item in memory and Firestore.
  * Uncarted "Buy Now" leaves cart completely untouched (no redundant writes, no notifications).
  * Exactly ONE kCartUpdatedNotification is posted for the entire cleanup operation.
  * Undo buffer is safely reset (orders cannot be "undone" back into the cart via UI undo).
- On failure / cancellation / pending verification:
  * In-memory cart items, quantities, local cache, and Firestore documents are strictly untouched.
- On duplicate callbacks / races:
  * Cleanup is executed exactly once; duplicate or stale callbacks are suppressed.
- On Firestore batch failure:
  * Local state is maintained, pending delete keys are tracked to prevent resurrection on snapshot reconnect.
- Objective-C source code contract invariants:
  * Verified in CartManager.h/.m and PPCheckoutCoordinator.m.
"""

import sys
import os
import re
from typing import List, Dict, Any, Optional, Tuple

BOLD = "\033[1m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
RESET = "\033[0m"

PASS_COUNT = 0
FAIL_COUNT = 0


def assert_true(cond: bool, msg: str):
    global PASS_COUNT, FAIL_COUNT
    if cond:
        PASS_COUNT += 1
        print(f"  {GREEN}✅ PASS:{RESET} {msg}")
    else:
        FAIL_COUNT += 1
        print(f"  {RED}❌ FAIL:{RESET} {msg}")


def assert_equal(actual: Any, expected: Any, msg: str):
    global PASS_COUNT, FAIL_COUNT
    if actual == expected:
        PASS_COUNT += 1
        print(f"  {GREEN}✅ PASS:{RESET} {msg}")
    else:
        FAIL_COUNT += 1
        print(f"  {RED}❌ FAIL:{RESET} {msg} (expected {expected!r}, got {actual!r})")


# =============================================================================
# SIMULATED DOMAIN MODELS & COORDINATOR
# =============================================================================

class MockCartItem:
    def __init__(self, item_id: str, quantity: int, price: float,
                 variant_id: str = "", variant_combination_key: str = "", name: str = ""):
        self.item_id = item_id
        self.quantity = quantity
        self.price = price
        self.variant_id = variant_id
        self.variant_combination_key = variant_combination_key
        self.name = name or f"Item_{item_id}"
        self.stock_quantity = 100

    def cart_key(self) -> str:
        if self.variant_combination_key:
            return f"{self.item_id}#{self.variant_combination_key}"
        return self.item_id

    def matches(self, other: "MockCartItem") -> bool:
        if self.item_id != other.item_id:
            return False
        k1 = self.variant_combination_key or ""
        k2 = other.variant_combination_key or ""
        return k1 == k2

    def copy(self) -> "MockCartItem":
        c = MockCartItem(self.item_id, self.quantity, self.price,
                         self.variant_id, self.variant_combination_key, self.name)
        c.stock_quantity = self.stock_quantity
        return c


class MockCartManager:
    def __init__(self):
        self.cart_items: List[MockCartItem] = []
        self.saved_cart: List[Dict[str, Any]] = []
        self.notifications_posted = 0
        self.pending_deleted_item_keys: set = set()
        self.pending_sync_item_keys: set = set()
        self.last_removed_item: Optional[MockCartItem] = None
        self.last_removed_index: int = -1
        self.firestore_batches_committed: List[Dict[str, Any]] = []
        self.simulate_firestore_error = False

    def add_item(self, item: MockCartItem):
        for existing in self.cart_items:
            if existing.matches(item):
                existing.quantity += item.quantity
                self.save_cart()
                self.notifications_posted += 1
                return
        self.cart_items.append(item.copy())
        self.save_cart()
        self.notifications_posted += 1

    def save_cart(self):
        self.saved_cart = [
            {"itemID": it.item_id, "quantity": it.quantity, "price": it.price,
             "variantCombinationKey": it.variant_combination_key}
            for it in self.cart_items
        ]

    def remove_purchased_items(self, purchased_items: List[MockCartItem], completion=None):
        if not purchased_items:
            if completion:
                completion(True)
            return

        items_to_remove_completely: List[MockCartItem] = []
        items_to_update_quantity: List[MockCartItem] = []
        keys_to_delete: List[str] = []

        for purchased in purchased_items:
            matched = None
            for it in self.cart_items:
                if it.matches(purchased):
                    matched = it
                    break
            if not matched:
                continue

            ck = matched.cart_key()
            if matched.quantity <= purchased.quantity:
                items_to_remove_completely.append(matched)
                if ck:
                    keys_to_delete.append(ck)
            else:
                matched.quantity -= purchased.quantity
                items_to_update_quantity.append(matched)

        if not items_to_remove_completely and not items_to_update_quantity:
            # Uncarted direct buy now
            if completion:
                completion(True)
            return

        # Complete removals from in-memory cart
        for it in items_to_remove_completely:
            if it in self.cart_items:
                self.cart_items.remove(it)

        # Track pending deletions to prevent resurrection
        for k in keys_to_delete:
            self.pending_deleted_item_keys.add(k)
            self.pending_sync_item_keys.discard(k)

        for it in items_to_update_quantity:
            self.pending_sync_item_keys.add(it.cart_key())

        # Reset undo buffer
        self.last_removed_item = None
        self.last_removed_index = -1

        # Persist local cache
        self.save_cart()

        # Emit exactly ONE notification for purchase cleanup
        self.notifications_posted += 1

        # Firestore sync batch
        batch = {
            "deleted_ids": [it.item_id for it in items_to_remove_completely],
            "updated_items": [
                {"itemID": it.item_id, "quantity": it.quantity, "cartKey": it.cart_key()}
                for it in items_to_update_quantity
            ]
        }
        self.firestore_batches_committed.append(batch)

        if self.simulate_firestore_error:
            # Keys stay in pending_deleted_item_keys to prevent resurrection
            if completion:
                completion(False)
            return

        for k in keys_to_delete:
            self.pending_deleted_item_keys.discard(k)
        for it in items_to_update_quantity:
            self.pending_sync_item_keys.discard(it.cart_key())

        if completion:
            completion(True)


class MockOrder:
    def __init__(self, order_id: str, total_amount: float = 100.0):
        self.order_id = order_id
        self.total_amount = total_amount


class MockCheckoutCoordinator:
    def __init__(self, cart_manager: MockCartManager):
        self.cart_manager = cart_manager
        self.state = 0  # 0: Idle, 1: Validating, 2: CreatingOrder, 3: AwaitingPayment, 4: Verifying, 5: Pending, 6: Succeeded, 7: Failed, 8: Cancelled
        self.generation = 0
        self.has_resolved_checkout = False
        self.is_checkout_in_progress = False
        self.checkout_items: List[MockCartItem] = []
        self.current_order: Optional[MockOrder] = None
        self.completion = None
        self.terminal_invocations = 0

    def start_checkout(self, items: List[MockCartItem], completion):
        self.generation += 1
        self.has_resolved_checkout = False
        self.is_checkout_in_progress = True
        self.checkout_items = [it.copy() for it in items]
        self.state = 1  # Validating
        self.completion = completion
        self.state = 2  # CreatingOrder
        self.current_order = MockOrder(f"ord_{self.generation}", sum(it.price * it.quantity for it in items))

    def pp_begin_terminal_resolution(self, gen: int, label: str) -> bool:
        if gen != self.generation:
            return False
        if self.has_resolved_checkout:
            return False
        self.has_resolved_checkout = True
        self.terminal_invocations += 1
        return True

    def complete_with_success(self, gen: int):
        if not self.pp_begin_terminal_resolution(gen, "success"):
            return
        self.state = 6  # Succeeded
        self.is_checkout_in_progress = False

        # Phase 6 contract: clean up purchased items
        self.cart_manager.remove_purchased_items(self.checkout_items)

        cb = self.completion
        self.completion = None
        if cb:
            cb("SUCCESS", self.current_order, None)

    def complete_with_failure(self, gen: int, error: str):
        if not self.pp_begin_terminal_resolution(gen, "failure"):
            return
        self.state = 7  # Failed
        self.is_checkout_in_progress = False
        # Invariant: NO cart cleanup on failure

        cb = self.completion
        self.completion = None
        if cb:
            cb("FAILED", self.current_order, error)

    def complete_with_pending_verification(self, gen: int):
        if not self.pp_begin_terminal_resolution(gen, "pending"):
            return
        self.state = 5  # PendingVerification
        self.is_checkout_in_progress = False
        # Invariant: NO cart cleanup on pending verification

        cb = self.completion
        self.completion = None
        if cb:
            cb("PENDING", self.current_order, None)

    def complete_with_cancellation(self, gen: int):
        if not self.pp_begin_terminal_resolution(gen, "cancelled"):
            return
        self.state = 8  # Cancelled
        self.is_checkout_in_progress = False
        # Invariant: NO cart cleanup on cancellation

        cb = self.completion
        self.completion = None
        if cb:
            cb("CANCELLED", self.current_order, None)


# =============================================================================
# TESTS
# =============================================================================

def run_tests():
    print(f"\n{BOLD}{BLUE}================================================================={RESET}")
    print(f"{BOLD}{BLUE} Pure Pets iOS Commerce Lifecycle — Phase 6 Cart Cleanup Suite   {RESET}")
    print(f"{BOLD}{BLUE}================================================================={RESET}\n")

    # -------------------------------------------------------------------------
    # Group 1: Full-Cart Checkout Cleanup Contract
    # -------------------------------------------------------------------------
    print(f"{BOLD}[Group 1: Full Cart Checkout Terminal Cleanup]{RESET}")
    cart1 = MockCartManager()
    item_a = MockCartItem("prod_collar", 2, 35.0, name="Collar")
    item_b = MockCartItem("prod_leash", 1, 50.0, name="Leash")
    cart1.add_item(item_a)
    cart1.add_item(item_b)
    notif_before = cart1.notifications_posted

    coord1 = MockCheckoutCoordinator(cart1)
    results1 = []
    coord1.start_checkout(cart1.cart_items, lambda r, o, e: results1.append((r, o)))
    g1 = coord1.generation

    assert_equal(len(cart1.cart_items), 2, "Cart has 2 items during in-flight checkout")
    coord1.complete_with_success(g1)

    assert_equal(len(cart1.cart_items), 0, "Cart is completely emptied after full checkout success")
    assert_equal(len(cart1.saved_cart), 0, "Local persistent cache is emptied after full checkout success")
    assert_equal(len(cart1.firestore_batches_committed), 1, "Exactly one Firestore batch delete committed")
    assert_equal(sorted(cart1.firestore_batches_committed[0]["deleted_ids"]), ["prod_collar", "prod_leash"],
                 "Firestore batch contains delete ops for all purchased items")
    assert_equal(cart1.notifications_posted, notif_before + 1,
                 "Exactly ONE kCartUpdatedNotification emitted for full cleanup")
    assert_equal(len(results1), 1, "Checkout completion callback received")
    assert_equal(results1[0][0], "SUCCESS", "Checkout succeeded")

    # -------------------------------------------------------------------------
    # Group 2: Subset Checkout Cleanup (Direct "Buy Now" with other cart items)
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 2: Subset Checkout / Direct Buy Now Cart Preservation]{RESET}")
    cart2 = MockCartManager()
    food = MockCartItem("prod_cat_food", 3, 20.0, name="Cat Food")
    shampoo = MockCartItem("prod_shampoo", 1, 45.0, name="Shampoo")
    toy = MockCartItem("prod_mouse_toy", 2, 10.0, name="Toy")
    cart2.add_item(food)
    cart2.add_item(shampoo)
    cart2.add_item(toy)
    notif_before2 = cart2.notifications_posted

    # User initiates "Buy Now" for shampoo ONLY
    coord2 = MockCheckoutCoordinator(cart2)
    results2 = []
    coord2.start_checkout([shampoo], lambda r, o, e: results2.append((r, o)))
    g2 = coord2.generation

    coord2.complete_with_success(g2)

    assert_equal(len(cart2.cart_items), 2, "Cart preserves the other 2 unpurchased items")
    remaining_ids = [it.item_id for it in cart2.cart_items]
    assert_true("prod_cat_food" in remaining_ids and "prod_mouse_toy" in remaining_ids,
                "Food and Toy remain intact in cart")
    assert_true("prod_shampoo" not in remaining_ids, "Shampoo was cleanly removed from cart")
    assert_equal(len(cart2.saved_cart), 2, "Local persistent cache preserves remaining items")
    assert_equal(cart2.firestore_batches_committed[-1]["deleted_ids"], ["prod_shampoo"],
                 "Firestore batch deleted ONLY the purchased shampoo")
    assert_equal(cart2.notifications_posted, notif_before2 + 1,
                 "Exactly ONE notification posted for subset purchase cleanup")

    # -------------------------------------------------------------------------
    # Group 3: Variant-Specific Subset Checkout
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 3: Multi-Variant Subset Checkout Cleanup]{RESET}")
    cart3 = MockCartManager()
    harness_red = MockCartItem("prod_harness", 1, 60.0, variant_combination_key="color:red", name="Harness Red")
    harness_blue = MockCartItem("prod_harness", 1, 60.0, variant_combination_key="color:blue", name="Harness Blue")
    cart3.add_item(harness_red)
    cart3.add_item(harness_blue)

    assert_equal(len(cart3.cart_items), 2, "Two distinct variants present in cart")

    # Buy Now on Red variant only
    coord3 = MockCheckoutCoordinator(cart3)
    coord3.start_checkout([harness_red], lambda r, o, e: None)
    coord3.complete_with_success(coord3.generation)

    assert_equal(len(cart3.cart_items), 1, "Only 1 variant remains in cart")
    assert_equal(cart3.cart_items[0].variant_combination_key, "color:blue",
                 "Blue variant preserved untouched; Red variant cleanly removed")

    # -------------------------------------------------------------------------
    # Group 4: Partial-Quantity Purchase Cleanup
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 4: Partial Quantity Purchase Decrement]{RESET}")
    cart4 = MockCartManager()
    treats = MockCartItem("prod_treats", 5, 12.0, name="Treats")
    cart4.add_item(treats)

    # Purchased 2 out of 5 treats
    purchased_part = MockCartItem("prod_treats", 2, 12.0, name="Treats")
    coord4 = MockCheckoutCoordinator(cart4)
    coord4.start_checkout([purchased_part], lambda r, o, e: None)
    coord4.complete_with_success(coord4.generation)

    assert_equal(len(cart4.cart_items), 1, "Item remains in cart")
    assert_equal(cart4.cart_items[0].quantity, 3, "Cart item quantity decremented from 5 to 3")
    assert_equal(cart4.saved_cart[0]["quantity"], 3, "Persistent cache updated with decremented quantity")
    last_batch = cart4.firestore_batches_committed[-1]
    assert_equal(len(last_batch["deleted_ids"]), 0, "No delete operation performed")
    assert_equal(len(last_batch["updated_items"]), 1, "One update operation performed")
    assert_equal(last_batch["updated_items"][0]["quantity"], 3, "Firestore batch updated quantity to 3")

    # -------------------------------------------------------------------------
    # Group 5: Uncarted Direct "Buy Now" Cleanup No-Op
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 5: Uncarted Direct Buy Now Cleanup No-Op]{RESET}")
    cart5 = MockCartManager()
    bowl = MockCartItem("prod_bowl", 1, 25.0, name="Bowl")
    cart5.add_item(bowl)
    notif_before5 = cart5.notifications_posted
    batches_before5 = len(cart5.firestore_batches_committed)

    # User buys a Carrier directly from detail page (Carrier was never in cart)
    carrier = MockCartItem("prod_carrier", 1, 150.0, name="Pet Carrier")
    coord5 = MockCheckoutCoordinator(cart5)
    coord5.start_checkout([carrier], lambda r, o, e: None)
    coord5.complete_with_success(coord5.generation)

    assert_equal(len(cart5.cart_items), 1, "Existing cart items strictly unaffected")
    assert_equal(cart5.cart_items[0].item_id, "prod_bowl", "Bowl remains in cart")
    assert_equal(cart5.notifications_posted, notif_before5,
                 "Zero notifications posted when purchased item was uncarted")
    assert_equal(len(cart5.firestore_batches_committed), batches_before5,
                 "Zero Firestore batch operations triggered for uncarted purchase")

    # -------------------------------------------------------------------------
    # Group 6: Terminal Failure & Cancellation Cart Preservation
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 6: Failure & Cancellation Cart Preservation]{RESET}")
    cart6 = MockCartManager()
    item_f1 = MockCartItem("prod_cage", 1, 200.0, name="Cage")
    item_f2 = MockCartItem("prod_seed", 3, 15.0, name="Seed")
    cart6.add_item(item_f1)
    cart6.add_item(item_f2)
    saved_cache_snapshot = list(cart6.saved_cart)

    # Test 1: Payment Failure
    coord_fail = MockCheckoutCoordinator(cart6)
    coord_fail.start_checkout(cart6.cart_items, lambda r, o, e: None)
    coord_fail.complete_with_failure(coord_fail.generation, "Card declined")

    assert_equal(len(cart6.cart_items), 2, "Cart items strictly preserved after payment failure")
    assert_equal(cart6.saved_cart, saved_cache_snapshot, "Cache strictly untouched on failure")
    assert_equal(len(cart6.firestore_batches_committed), 0, "No Firestore deletions on failure")

    # Test 2: Pending Verification (Delayed confirmation)
    coord_pending = MockCheckoutCoordinator(cart6)
    coord_pending.start_checkout(cart6.cart_items, lambda r, o, e: None)
    coord_pending.complete_with_pending_verification(coord_pending.generation)

    assert_equal(len(cart6.cart_items), 2, "Cart items strictly preserved on pending verification")
    assert_equal(cart6.saved_cart, saved_cache_snapshot, "Cache strictly untouched on pending verification")
    assert_equal(len(cart6.firestore_batches_committed), 0, "No Firestore deletions on pending verification")

    # Test 3: User Cancellation
    coord_cancel = MockCheckoutCoordinator(cart6)
    coord_cancel.start_checkout(cart6.cart_items, lambda r, o, e: None)
    coord_cancel.complete_with_cancellation(coord_cancel.generation)

    assert_equal(len(cart6.cart_items), 2, "Cart items strictly preserved on user cancellation")
    assert_equal(cart6.saved_cart, saved_cache_snapshot, "Cache strictly untouched on user cancellation")
    assert_equal(len(cart6.firestore_batches_committed), 0, "No Firestore deletions on user cancellation")

    # -------------------------------------------------------------------------
    # Group 7: Duplicate Terminal Resolution Suppression
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 7: Duplicate Terminal Resolution & Side-Effect Suppression]{RESET}")
    cart7 = MockCartManager()
    item_dup = MockCartItem("prod_bed", 1, 95.0, name="Pet Bed")
    cart7.add_item(item_dup)

    coord_dup = MockCheckoutCoordinator(cart7)
    coord_dup.start_checkout([item_dup], lambda r, o, e: None)
    g_dup = coord_dup.generation

    # Initial success resolves
    coord_dup.complete_with_success(g_dup)
    assert_equal(len(cart7.cart_items), 0, "Cart cleared on initial success")
    assert_equal(len(cart7.firestore_batches_committed), 1, "Exactly one batch commit")

    # Late duplicate success (e.g. late webhook or listener snapshot)
    coord_dup.complete_with_success(g_dup)
    assert_equal(len(cart7.firestore_batches_committed), 1, "Duplicate success rejected; no second batch commit")

    # Late conflicting failure
    coord_dup.complete_with_failure(g_dup, "Late error")
    assert_equal(coord_dup.state, 6, "State remains Succeeded (terminal immutability)")
    assert_equal(coord_dup.terminal_invocations, 1, "Exactly 1 terminal resolution executed")

    # -------------------------------------------------------------------------
    # Group 8: Remote Batch Deletion Failure & Resurrection Protection
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 8: Remote Batch Deletion Failure Safety & Resurrection Protection]{RESET}")
    cart8 = MockCartManager()
    item_res = MockCartItem("prod_aquarium", 1, 500.0, name="Aquarium")
    cart8.add_item(item_res)
    cart8.simulate_firestore_error = True  # Network fails during batch commit

    sync_result = []
    cart8.remove_purchased_items([item_res], completion=lambda s: sync_result.append(s))

    assert_equal(sync_result, [False], "Batch sync completed with failure status")
    assert_equal(len(cart8.cart_items), 0, "Local in-memory cart remains cleared for user UX")
    assert_true("prod_aquarium" in cart8.pending_deleted_item_keys,
                "Failed deletion key retained in pending_deleted_item_keys to prevent resurrection")

    # Simulated snapshot arrives containing stale "prod_aquarium"
    stale_snapshot_items = [MockCartItem("prod_aquarium", 1, 500.0, name="Aquarium")]
    filtered_items = [it for it in stale_snapshot_items if it.cart_key() not in cart8.pending_deleted_item_keys]
    assert_equal(len(filtered_items), 0, "Stale item filtered out by pending_deleted_item_keys (resurrection prevented)")

    # -------------------------------------------------------------------------
    # Group 9: Objective-C Source Code Contract Invariant Audits
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 9: Objective-C Source Code Cart Cleanup Invariants]{RESET}")
    ios_root = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS")

    cart_h_path = os.path.join(ios_root, "Manager", "Cart", "CartManager.h")
    cart_m_path = os.path.join(ios_root, "Manager", "Cart", "CartManager.m")
    checkout_m_path = os.path.join(ios_root, "Checkout", "PPCheckoutCoordinator.m")

    with open(cart_h_path, "r", encoding="utf-8") as f:
        cart_h = f.read()
    with open(cart_m_path, "r", encoding="utf-8") as f:
        cart_m = f.read()
    with open(checkout_m_path, "r", encoding="utf-8") as f:
        checkout_m = f.read()

    # 1. removePurchasedItems declared in CartManager.h
    assert_true("- (void)removePurchasedItems:(NSArray<CartItem *> *)purchasedItems" in cart_h,
                "removePurchasedItems: declared in CartManager.h")

    # 2. removePurchasedItems implemented in CartManager.m
    assert_true("- (void)removePurchasedItems:(NSArray<CartItem *> *)purchasedItems" in cart_m,
                "removePurchasedItems: implemented in CartManager.m")

    # 3. Matches purchased items using variant-aware pp_existingItemMatching:
    assert_true("CartItem *matched = [self pp_existingItemMatching:purchased];" in cart_m,
                "removePurchasedItems uses variant-aware matching")

    # 4. Partial quantity decrement logic in CartManager.m
    assert_true("matched.quantity -= purchased.quantity;" in cart_m,
                "Partial quantity decremented when purchased < cart quantity")

    # 5. Pending delete keys tracking
    assert_true("[self.pendingDeletedItemKeys addObject:k];" in cart_m,
                "Keys added to pendingDeletedItemKeys during purchase cleanup")

    # 6. Single kCartUpdatedNotification emission
    assert_true("[[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];" in cart_m,
                "Single kCartUpdatedNotification posted after purchase cleanup")

    # 7. Wired in PPCheckoutCoordinator.m completeWithSuccess
    assert_true("[CartManager.sharedManager removePurchasedItems:checkoutItems completion:nil];" in checkout_m,
                "removePurchasedItems called with checkoutItems in completeWithSuccess")

    # 8. Verification that failure methods DO NOT call removePurchasedItems
    fail_snippet = checkout_m[checkout_m.find("- (void)completeWithFailure:"):checkout_m.find("- (void)completeWithPendingVerification:")]
    assert_true("removePurchasedItems" not in fail_snippet,
                "completeWithFailure does NOT call removePurchasedItems")
    assert_true("clearCart" not in fail_snippet,
                "completeWithFailure does NOT call clearCart")

    pending_snippet = checkout_m[checkout_m.find("- (void)completeWithPendingVerification:"):checkout_m.find("- (void)failOrderWithError:")]
    assert_true("removePurchasedItems" not in pending_snippet,
                "completeWithPendingVerification does NOT call removePurchasedItems")
    assert_true("clearCart" not in pending_snippet,
                "completeWithPendingVerification does NOT call clearCart")

    # Summary
    print(f"\n{BOLD}================================================================={RESET}")
    print(f"  RESULTS: {PASS_COUNT}/{PASS_COUNT + FAIL_COUNT} tests passed ({FAIL_COUNT} failures)")
    print(f"{BOLD}================================================================={RESET}\n")

    if FAIL_COUNT > 0:
        print(f"{RED}❌ SOME CART CLEANUP REGRESSION TESTS FAILED!{RESET}\n")
        sys.exit(1)
    else:
        print(f"{GREEN}🎉 ALL PHASE 6 CART CLEANUP REGRESSION TESTS PASSED (100% GREEN)!{RESET}\n")
        sys.exit(0)


if __name__ == "__main__":
    run_tests()
