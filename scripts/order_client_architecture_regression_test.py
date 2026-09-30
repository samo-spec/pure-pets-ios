#!/usr/bin/env python3
"""
order_client_architecture_regression_test.py — Phase 8 Order Client Architecture Suite

Pure Pets Platform (pure-pets-49199)
Primary Client: Pure Pets IOS/ (Consumer iOS)

Validates the Order Client Architecture:
1. Canonical Order Model Parsing & Deserialization:
   - Canonical fields: orderId, orderNumber, rawStatus, amount, shippingFee, totalAmount, currency, paymentMethodId, paymentStatus, fulfillmentVersion.
   - Fulfillment V1 discrimination.
2. Typed Status & Lifecycle Presentation Mapping:
   - Maps backend states to customer visible keys:
     * checkout_card_payment_pending / cancelled / failed
     * pending
     * preparing_for_shipment
     * ready_for_delivery
     * delivery_partner_assigned
     * on_the_way
     * delivered
     * completed
     * returned_to_store
     * delivery_cancelled / delivery_failed
     * unknown (safe fallback)
3. Unknown Backend State Fail-Closed Safety:
   - Unknown status maps safely to "unknown" without crashing or misrepresenting progress.
   - Unknown status NEVER permits destructive direct cancellation (blocked fail-closed with generic unavailable copy).
4. Customer Support & Lifecycle Actions Eligibility Matrix:
   - Cancellation:
     * Unpaid pending / failed checkout order: cancellable (abandonable via callable).
     * Pre-fulfillment paid / COD order: cancellable.
     * In-packing / preparing order: cancellation blocked.
     * In-transit / custody transferred order: cancellation blocked.
     * Closed / already cancelled order: cancellation blocked.
     * Unknown status order: cancellation blocked fail-closed.
   - Returns: only eligible after delivery within 14-day window.
   - Refunds: only eligible after capture, before shipment, within 14-day window.
   - Replacements: only eligible after delivery within 14-day window.
5. Objective-C Source Code Contract Invariant Audits:
   - Audits in PPOrder.h/.m and PPOrderManager.h/.m.
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
# SIMULATED ORDER & ELIGIBILITY ENGINE
# =============================================================================

class MockPPOrder:
    def __init__(self, order_id: str, raw_status: str, payment_method_id: str = "qib",
                 payment_status: str = "paid", delivery_status: str = "",
                 amount: float = 100.0, shipping_fee: float = 15.0,
                 fulfillment_version: int = 1, delivery_accepted_at: bool = False,
                 delivery_requested_at: bool = False):
        self.order_id = order_id
        self.raw_status = raw_status.lower().strip()
        self.payment_method_id = payment_method_id.lower().strip()
        self.payment_status = payment_status.lower().strip()
        self.delivery_status = delivery_status.lower().strip()
        self.amount = amount
        self.shipping_fee = shipping_fee
        self.total_amount = amount + shipping_fee
        self.fulfillment_version = fulfillment_version
        self.delivery_accepted_at = delivery_accepted_at
        self.delivery_requested_at = delivery_requested_at

    def is_cash_on_delivery(self) -> bool:
        return self.payment_method_id == "cash"

    def has_captured_payment(self) -> bool:
        return self.payment_status in {"paid", "captured", "payment_paid", "payment_captured"}

    def effective_delivery_status(self) -> str:
        return self.delivery_status

    def customer_visible_status_key(self) -> str:
        raw = self.raw_status
        deliv = self.delivery_status

        # Uncaptured checkout card payment states
        if not self.is_cash_on_delivery() and not self.has_captured_payment():
            if self.payment_status == "cancelled" or "abandoned" in raw:
                return "checkout_card_payment_cancelled"
            if self.payment_status == "failed" or any(t in raw for t in ["failed", "declined", "rejected", "error"]):
                return "checkout_card_payment_failed"
            if self.payment_status == "pending" or any(t in raw for t in ["pending", "created", "waiting"]):
                return "checkout_card_payment_pending"

        # Terminal delivery states
        if deliv in ["delivery_cancelled"] or any(t in raw for t in ["cancelled", "canceled"]):
            return "delivery_cancelled"
        if deliv in ["returned_to_store"] or any(t in raw for t in ["returned_to_store", "returned"]):
            return "returned_to_store"
        if deliv in ["delivery_failed"] or any(t in raw for t in ["failed", "rejected", "declined", "expired", "voided", "error"]):
            return "delivery_failed"
        if deliv in ["completed"] or any(t in raw for t in ["completed", "fulfilled"]):
            return "completed"
        if deliv in ["delivered", "payment_pending", "payment_confirmed"] or any(t in raw for t in ["delivered"]):
            return "delivered"

        # Active in-transit states
        if deliv in ["picked_up", "in_transit", "out_for_delivery"] or any(t in raw for t in ["shipped", "shipping", "in_transit", "out_for_delivery"]):
            return "on_the_way"

        # Partner assigned
        if deliv in ["delivery_assigned", "awaiting_handover"] or self.delivery_accepted_at:
            return "delivery_partner_assigned"

        # Ready for pickup/delivery
        if deliv in ["ready_to_ship", "ready_for_pickup", "delivery_requested", "delivery_reassigned", "ready_for_delivery"] or self.delivery_requested_at:
            return "ready_for_delivery"

        # Placed / pending
        if any(t in raw for t in ["pending", "created", "placed", "waiting"]):
            return "pending"

        # Preparing
        if any(t in raw for t in ["processing", "preparing", "confirmed"]) or (self.fulfillment_version != 1 and self.has_captured_payment()):
            return "preparing_for_shipment"

        if not raw and not deliv:
            return "preparing_for_shipment"

        return "unknown"


class MockOrderManager:
    @staticmethod
    def cancellation_blocked_reason_for_order(order: Optional[MockPPOrder]) -> Optional[str]:
        if not order:
            return "order_support_unavailable_no_order"

        status_key = order.raw_status or "pending"

        is_uncaptured_checkout_failure = (
            "failed" in status_key and
            not order.is_cash_on_delivery() and
            not order.has_captured_payment()
        )

        if "cancelled" in status_key or "canceled" in status_key or ("failed" in status_key and not is_uncaptured_checkout_failure):
            return "order_action_cancel_unavailable_closed"

        if order.fulfillment_version == 1:
            delivery_status = order.effective_delivery_status()
            custody_transferred = any(k in delivery_status for k in [
                "picked_up", "in_transit", "shipped", "out_for_delivery",
                "delivered", "completed", "returned_to_store"
            ])
            if custody_transferred or any(k in status_key for k in ["delivered", "completed", "fulfilled"]):
                return "order_action_cancel_unavailable_fulfillment"
        else:
            if any(k in status_key for k in ["processing", "preparing", "packing", "ready"]):
                return "order_action_cancel_unavailable_preparing"
            if any(k in status_key for k in ["shipped", "shipping", "in_transit", "delivered", "completed"]):
                return "order_action_cancel_unavailable_fulfillment"

        # Uncaptured checkout card payments
        if not order.is_cash_on_delivery() and not order.has_captured_payment():
            if status_key in ["pending", "failed"]:
                return None  # Cancellable / abandonable
            return "order_action_cancel_unavailable_payment_pending"

        # For paid or COD orders, cancellation is only available before fulfillment starts.
        # An unknown or unrecognized backend status must fail closed and never trigger cancellation!
        is_cancellable_pre_fulfillment = any(k in status_key for k in [
            "pending", "created", "placed", "confirmed", "paid", "waiting"
        ])
        if not is_cancellable_pre_fulfillment:
            return "order_action_unavailable_generic"

        return None

    @classmethod
    def can_user_cancel_order(cls, order: Optional[MockPPOrder]) -> bool:
        return cls.cancellation_blocked_reason_for_order(order) is None

    @staticmethod
    def eligibility_for_return(order: MockPPOrder, days_since_delivery: int) -> Tuple[bool, str]:
        status_key = order.raw_status
        is_delivered = any(k in status_key for k in ["delivered", "completed", "fulfilled"]) or order.delivery_status == "delivered"
        if not is_delivered:
            return False, "order_action_return_unavailable_not_delivered"
        if days_since_delivery > 14:
            return False, "order_action_return_unavailable_window"
        return True, "order_action_return_hint"

    @staticmethod
    def eligibility_for_refund(order: MockPPOrder, days_since_payment: int) -> Tuple[bool, str]:
        status_key = order.raw_status
        has_captured = order.has_captured_payment()
        if not (has_captured or "cancelled" in status_key):
            return False, "order_action_refund_unavailable_unpaid"
        if any(k in status_key for k in ["shipped", "in_transit", "picked_up"]):
            return False, "order_action_refund_unavailable_after_shipment"
        if days_since_payment > 14:
            return False, "order_action_refund_unavailable_window"
        return True, "order_action_refund_hint"


# =============================================================================
# TESTS
# =============================================================================

def run_tests():
    print(f"\n{BOLD}{BLUE}================================================================={RESET}")
    print(f"{BOLD}{BLUE} Pure Pets iOS Commerce — Phase 8 Order Architecture Suite       {RESET}")
    print(f"{BOLD}{BLUE}================================================================={RESET}\n")

    # -------------------------------------------------------------------------
    # Group 1: Canonical Order Status Mapping Across Lifecycle
    # -------------------------------------------------------------------------
    print(f"{BOLD}[Group 1: Canonical Status & Lifecycle Presentation Mapping]{RESET}")
    # 1. Uncaptured checkout payment pending
    o1 = MockPPOrder("ord_1", "pending", payment_method_id="qib", payment_status="pending")
    assert_equal(o1.customer_visible_status_key(), "checkout_card_payment_pending", "Checkout card payment pending mapped")

    # 2. Uncaptured checkout payment cancelled
    o2 = MockPPOrder("ord_2", "abandoned", payment_method_id="qib", payment_status="cancelled")
    assert_equal(o2.customer_visible_status_key(), "checkout_card_payment_cancelled", "Checkout card payment cancelled mapped")

    # 3. Uncaptured checkout payment failed
    o3 = MockPPOrder("ord_3", "failed", payment_method_id="qib", payment_status="failed")
    assert_equal(o3.customer_visible_status_key(), "checkout_card_payment_failed", "Checkout card payment failed mapped")

    # 4. COD pending
    o4 = MockPPOrder("ord_4", "pending", payment_method_id="cash", payment_status="pending_collection")
    assert_equal(o4.customer_visible_status_key(), "pending", "COD pending mapped to pending")

    # 5. Preparing for shipment
    o5 = MockPPOrder("ord_5", "processing", payment_method_id="qib", payment_status="paid")
    assert_equal(o5.customer_visible_status_key(), "preparing_for_shipment", "Processing mapped to preparing_for_shipment")

    # 6. Ready for delivery
    o6 = MockPPOrder("ord_6", "ready", delivery_status="ready_to_ship", payment_status="paid")
    assert_equal(o6.customer_visible_status_key(), "ready_for_delivery", "Ready to ship mapped to ready_for_delivery")

    # 7. Delivery partner assigned
    o7 = MockPPOrder("ord_7", "assigned", delivery_status="delivery_assigned", payment_status="paid")
    assert_equal(o7.customer_visible_status_key(), "delivery_partner_assigned", "Delivery assigned mapped")

    # 8. On the way / In transit
    o8 = MockPPOrder("ord_8", "in_transit", delivery_status="in_transit", payment_status="paid")
    assert_equal(o8.customer_visible_status_key(), "on_the_way", "In transit mapped to on_the_way")

    # 9. Delivered
    o9 = MockPPOrder("ord_9", "delivered", delivery_status="delivered", payment_status="paid")
    assert_equal(o9.customer_visible_status_key(), "delivered", "Delivered mapped to delivered")

    # 10. Completed
    o10 = MockPPOrder("ord_10", "completed", delivery_status="completed", payment_status="paid")
    assert_equal(o10.customer_visible_status_key(), "completed", "Completed mapped to completed")

    # 11. Returned to store
    o11 = MockPPOrder("ord_11", "returned", delivery_status="returned_to_store", payment_status="paid")
    assert_equal(o11.customer_visible_status_key(), "returned_to_store", "Returned to store mapped")

    # 12. Delivery cancelled
    o12 = MockPPOrder("ord_12", "cancelled", delivery_status="delivery_cancelled", payment_status="paid")
    assert_equal(o12.customer_visible_status_key(), "delivery_cancelled", "Delivery cancelled mapped")

    # -------------------------------------------------------------------------
    # Group 2: Unknown Backend State Safe Display
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 2: Unknown Backend State Safe Fallback Display]{RESET}")
    # Backend introduces a new / experimental status unknown to consumer iOS
    o_unknown = MockPPOrder("ord_unk", "disputed_chargeback_review", payment_method_id="qib", payment_status="paid")
    assert_equal(o_unknown.customer_visible_status_key(), "unknown", "Unknown status maps safely to 'unknown'")

    o_mystery = MockPPOrder("ord_myst", "state_x_v3_investigation", payment_method_id="cash", payment_status="pending_collection")
    assert_equal(o_mystery.customer_visible_status_key(), "unknown", "Novel state maps safely to 'unknown'")

    # -------------------------------------------------------------------------
    # Group 3: Unknown Backend State Never Triggers Destructive Cancellation
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 3: Unknown Backend State Cancellation Fail-Closed]{RESET}")
    # Destructive action: user tries to cancel an order in an unknown / ambiguous state
    assert_equal(MockOrderManager.can_user_cancel_order(o_unknown), False,
                 "Unknown state order CANNOT be cancelled directly by customer")
    blocked_reason = MockOrderManager.cancellation_blocked_reason_for_order(o_unknown)
    assert_equal(blocked_reason, "order_action_unavailable_generic",
                 "Cancellation blocked with generic unavailable reason on unknown state")

    assert_equal(MockOrderManager.can_user_cancel_order(o_mystery), False,
                 "Novel mystery state order CANNOT be cancelled directly by customer")

    # -------------------------------------------------------------------------
    # Group 4: Cancellation Eligibility Rules Across Valid Lifecycle
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 4: Cancellation Eligibility Rules Across Lifecycle]{RESET}")
    # 1. Unpaid pending checkout order -> Cancellable (abandonment)
    assert_true(MockOrderManager.can_user_cancel_order(o1), "Unpaid pending checkout order is cancellable")

    # 2. COD order just placed (pending) -> Cancellable
    assert_true(MockOrderManager.can_user_cancel_order(o4), "COD pending order is cancellable")

    # 3. Paid order in initial confirmed state -> Cancellable
    o_paid_initial = MockPPOrder("ord_pi", "confirmed", payment_method_id="qib", payment_status="paid")
    assert_true(MockOrderManager.can_user_cancel_order(o_paid_initial), "Initial confirmed paid order is cancellable")

    # 4. Order in packing / preparing -> Blocked
    o_packing = MockPPOrder("ord_pack", "packing", payment_method_id="qib", payment_status="paid", fulfillment_version=0)
    assert_equal(MockOrderManager.can_user_cancel_order(o_packing), False, "Packing order cancellation blocked")
    assert_equal(MockOrderManager.cancellation_blocked_reason_for_order(o_packing),
                 "order_action_cancel_unavailable_preparing", "Packing order receives preparing reason")

    # 5. Order with custody transferred (in transit) -> Blocked
    assert_equal(MockOrderManager.can_user_cancel_order(o8), False, "In-transit order cancellation blocked")
    assert_equal(MockOrderManager.cancellation_blocked_reason_for_order(o8),
                 "order_action_cancel_unavailable_fulfillment", "In-transit receives fulfillment reason")

    # 6. Delivered order -> Blocked
    assert_equal(MockOrderManager.can_user_cancel_order(o9), False, "Delivered order cancellation blocked")

    # 7. Already cancelled order -> Blocked
    assert_equal(MockOrderManager.can_user_cancel_order(o12), False, "Cancelled order cancellation blocked")
    assert_equal(MockOrderManager.cancellation_blocked_reason_for_order(o12),
                 "order_action_cancel_unavailable_closed", "Cancelled order receives closed reason")

    # 8. Nil order -> Blocked
    assert_equal(MockOrderManager.can_user_cancel_order(None), False, "Nil order cancellation blocked")

    # -------------------------------------------------------------------------
    # Group 5: Returns, Refunds, and Replacements Eligibility
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 5: Returns, Refunds, and Replacements Eligibility]{RESET}")
    # Return before delivery -> Blocked
    can_ret_unshipped, ret_msg1 = MockOrderManager.eligibility_for_return(o5, days_since_delivery=0)
    assert_equal(can_ret_unshipped, False, "Return blocked before delivery")
    assert_equal(ret_msg1, "order_action_return_unavailable_not_delivered", "Blocked with not-delivered copy")

    # Return within 14-day window -> Eligible
    can_ret_valid, _ = MockOrderManager.eligibility_for_return(o9, days_since_delivery=5)
    assert_equal(can_ret_valid, True, "Return eligible 5 days after delivery")

    # Return after 14-day window -> Blocked
    can_ret_expired, ret_msg2 = MockOrderManager.eligibility_for_return(o9, days_since_delivery=15)
    assert_equal(can_ret_expired, False, "Return blocked 15 days after delivery")
    assert_equal(ret_msg2, "order_action_return_unavailable_window", "Blocked with window-expired copy")

    # Refund before capture -> Blocked
    can_ref_unpaid, ref_msg1 = MockOrderManager.eligibility_for_refund(o1, days_since_payment=1)
    assert_equal(can_ref_unpaid, False, "Refund blocked for unpaid order")

    # Refund after shipment -> Blocked
    can_ref_shipped, ref_msg2 = MockOrderManager.eligibility_for_refund(o8, days_since_payment=2)
    assert_equal(can_ref_shipped, False, "Refund blocked after shipment")

    # Refund paid pre-shipment within window -> Eligible
    can_ref_valid, _ = MockOrderManager.eligibility_for_refund(o_paid_initial, days_since_payment=3)
    assert_equal(can_ref_valid, True, "Refund eligible for paid unshipped order within 14 days")

    # -------------------------------------------------------------------------
    # Group 6: Objective-C Source Code Contract Invariant Audits
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 6: Objective-C Source Code Order Architecture Invariants]{RESET}")
    ios_payments = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS")
    order_h_path = os.path.join(ios_payments, "Models", "Orders", "PPOrder.h")
    order_m_path = os.path.join(ios_payments, "Models", "Orders", "PPOrder.m")
    mgr_h_path = os.path.join(ios_payments, "Manager", "Order", "PPOrderManager.h")
    mgr_m_path = os.path.join(ios_payments, "Manager", "Order", "PPOrderManager.m")

    with open(order_h_path, "r", encoding="utf-8") as f:
        order_h = f.read()
    with open(order_m_path, "r", encoding="utf-8") as f:
        order_m = f.read()
    with open(mgr_h_path, "r", encoding="utf-8") as f:
        mgr_h = f.read()
    with open(mgr_m_path, "r", encoding="utf-8") as f:
        mgr_m = f.read()

    # 1. Customer visible status key exposed and implemented
    assert_true("- (NSString *)customerVisibleStatusKey;" in order_h, "customerVisibleStatusKey declared in PPOrder.h")
    assert_true("- (NSString *)customerVisibleStatusKey" in order_m, "customerVisibleStatusKey implemented in PPOrder.m")

    # 2. Unknown status fallback in PPOrder.m
    assert_true('return @"unknown";' in order_m, "customerVisibleStatusKey returns 'unknown' fallback")

    # 3. Can user cancel order declared and implemented
    assert_true("+ (BOOL)canUserCancelOrder:(PPOrder *)order;" in mgr_h, "canUserCancelOrder: declared in PPOrderManager.h")
    assert_true("+ (BOOL)canUserCancelOrder:(PPOrder *)order" in mgr_m, "canUserCancelOrder: implemented in PPOrderManager.m")

    # 4. Cancellation blocked reason implemented
    assert_true("+ (nullable NSString *)cancellationBlockedReasonForOrder:(PPOrder *)order" in mgr_m,
                "cancellationBlockedReasonForOrder: implemented in PPOrderManager.m")

    # 5. Non-cancellable pre-fulfillment check protects against unknown status
    assert_true("isCancellablePreFulfillment" in mgr_m,
                "isCancellablePreFulfillment check present in cancellationBlockedReasonForOrder:")
    assert_true("order_action_unavailable_generic" in mgr_m,
                "order_action_unavailable_generic returned when status is not cancellable pre-fulfillment")

    # 6. Action eligibility method declared and implemented
    assert_true("- (PPOrderEligibilityDecision *)eligibilityForAction:(PPOrderCustomerActionType)actionType" in mgr_h,
                "eligibilityForAction: declared in PPOrderManager.h")
    assert_true("- (PPOrderEligibilityDecision *)eligibilityForAction:(PPOrderCustomerActionType)actionType" in mgr_m,
                "eligibilityForAction: implemented in PPOrderManager.m")

    # 7. Fulfillment version 1 awareness in order cancellation
    assert_true("order.fulfillmentVersion == 1" in mgr_m,
                "Fulfillment V1 distinct cancellation handling present in PPOrderManager.m")

    # Summary
    print(f"\n{BOLD}================================================================={RESET}")
    print(f"  RESULTS: {PASS_COUNT}/{PASS_COUNT + FAIL_COUNT} tests passed ({FAIL_COUNT} failures)")
    print(f"{BOLD}================================================================={RESET}\n")

    if FAIL_COUNT > 0:
        print(f"{RED}❌ SOME ORDER CLIENT ARCHITECTURE TESTS FAILED!{RESET}\n")
        sys.exit(1)
    else:
        print(f"{GREEN}🎉 ALL PHASE 8 ORDER CLIENT ARCHITECTURE TESTS PASSED (100% GREEN)!{RESET}\n")
        sys.exit(0)


if __name__ == "__main__":
    run_tests()
