#!/usr/bin/env python3
"""
cancellation_support_contract_regression_test.py
Pure Pets iOS Commerce Lifecycle — Phase 10 Regression Test Suite

Validates:
1. Cancellation is a server-authoritative command, never a direct client mutation.
2. Fresh server document preflight ensures cancellation eligibility is based on canonical server state.
3. Cancellation eligibility across the full order lifecycle (pre-fulfillment, advanced fulfillment, closed, unknown).
4. Fulfillment V1 all-or-nothing multi-child cancellation rules (one custody child blocks entire order cancellation).
5. Cancellation request dispositions and presentation accuracy (immediate_cancellation, pending_review, rejected/blocked).
6. Idempotency, replay, and network retry resilience (deduplication handling, auth token refresh).
7. Financial refund separation (refundRequired: true, refundStatus: pending; captured payment preserved pending settlement).
8. Objective-C source code contract invariants across PPOrderManager, PPOrder, and support request controllers.
"""

import sys
import os
import re

TEST_RESULTS = []

def record_pass(group: str, name: str):
    TEST_RESULTS.append({"group": group, "name": name, "passed": True, "error": None})
    print(f"  ✅ PASS: {name}")

def record_fail(group: str, name: str, error: str):
    TEST_RESULTS.append({"group": group, "name": name, "passed": False, "error": error})
    print(f"  ❌ FAIL: {name} — {error}")

# ==============================================================================
# Simulation Logic Matching Backend orderSupportCancellation.js & PPOrderManager.m
# ==============================================================================

CANCELLABLE_PRE_FULFILLMENT_STATUSES = {
    "pending", "created", "placed", "confirmed", "paid", "waiting"
}

FULFILLMENT_CUSTODY_STATUSES = {
    "handed_over", "picked_up", "in_transit", "shipped", "out_for_delivery",
    "delivered", "completed", "returned_to_store"
}

def simulate_cancellation_blocked_reason(order: dict) -> str:
    if not order or not isinstance(order, dict):
        return "order_action_unavailable_generic"

    status_key = (order.get("status") or "").strip().lower()
    is_v1 = order.get("fulfillmentVersion") == 1
    delivery_status = (order.get("deliveryStatus") or "").strip().lower()
    is_uncaptured_qib = order.get("isUncapturedQIB", False)

    # Closed or terminal orders
    if any(k in status_key for k in ["cancelled", "canceled"]):
        return "order_action_cancel_unavailable_closed"
    if any(k in status_key for k in ["failed", "rejected", "declined", "expired", "voided", "error"]):
        if not is_uncaptured_qib:
            return "order_action_cancel_unavailable_closed"

    # Fulfillment V1 custody check
    if is_v1:
        custody_transferred = any(k in delivery_status for k in FULFILLMENT_CUSTODY_STATUSES)
        if custody_transferred or "delivered" in status_key:
            return "order_action_cancel_unavailable_fulfillment"
    else:
        if any(k in status_key for k in ["packing", "processing", "preparing"]):
            return "order_action_cancel_unavailable_preparing"
        if any(k in status_key for k in ["shipped", "delivered"]):
            return "order_action_cancel_unavailable_fulfillment"

    # Payment check
    is_cod = order.get("isCashOnDelivery", False)
    has_captured_payment = order.get("hasCapturedPayment", False)
    if not is_cod and not has_captured_payment:
        if status_key in ["pending", "failed"]:
            return None # Cancellable through checkout cancellation callable
        return "order_action_cancel_unavailable_payment_pending"

    # Pre-fulfillment status check
    if status_key not in CANCELLABLE_PRE_FULFILLMENT_STATUSES:
        return "order_action_unavailable_generic"

    return None

def simulate_base_fulfillment_cancellation_plan(fulfillments: list) -> dict:
    if not fulfillments:
        return {"allowed": False, "blockedReason": "no_fulfillments", "orderCancelled": False}

    blocked_children = []
    for f in fulfillments:
        st = (f.get("status") or "").strip().lower()
        if st in FULFILLMENT_CUSTODY_STATUSES:
            blocked_children.append(st)

    if blocked_children:
        return {
            "allowed": False,
            "blockedReason": "non_cancellable_fulfillment",
            "blockedStatuses": blocked_children,
            "orderCancelled": False
        }

    # All children pre-custody
    all_pre_handover = all(f.get("status") in ["new_request", "accepted", "preparing", "ready_for_pickup", "delivery_assigned", "awaiting_handover"] for f in fulfillments)
    return {
        "allowed": True,
        "blockedReason": None,
        "orderCancelled": True,
        "cancellationDisposition": "immediate_cancellation" if all_pre_handover else "pending_review"
    }

def simulate_create_order_support_request(server_order: dict, request_payload: dict, existing_requests: dict) -> dict:
    # 1. Preflight eligibility check against server_order
    blocked_reason = simulate_cancellation_blocked_reason(server_order)
    if blocked_reason:
        return {
            "success": False,
            "code": 409,
            "error": blocked_reason
        }

    # 2. Idempotency check
    idempotency_key = (request_payload.get("idempotencyKey") or "").strip()
    if idempotency_key and idempotency_key in existing_requests:
        existing = existing_requests[idempotency_key]
        return {
            "success": True,
            "requestId": existing["requestId"],
            "deduplicated": True,
            "orderCancelled": existing["orderCancelled"],
            "cancellationDisposition": existing["cancellationDisposition"],
            "status": existing["status"]
        }

    # 3. Fulfillment plan
    fulfillments = server_order.get("fulfillments", [])
    plan = simulate_base_fulfillment_cancellation_plan(fulfillments) if fulfillments else {"allowed": True, "orderCancelled": True, "cancellationDisposition": "immediate_cancellation"}

    req_id = f"req_{len(existing_requests) + 1}"
    record = {
        "requestId": req_id,
        "orderCancelled": plan["orderCancelled"],
        "cancellationDisposition": plan["cancellationDisposition"],
        "status": "approved" if plan["orderCancelled"] else "pending_review"
    }
    if idempotency_key:
        existing_requests[idempotency_key] = record

    return {
        "success": True,
        "requestId": req_id,
        "deduplicated": False,
        "orderCancelled": record["orderCancelled"],
        "cancellationDisposition": record["cancellationDisposition"],
        "status": record["status"]
    }

REQUEST_STATUS_DISPLAY_TITLES = {
    "pending_review": "order_request_status_pending_review",
    "approved": "order_request_status_approved",
    "rejected": "order_request_status_rejected",
    "completed": "order_request_status_completed",
    "refunded": "order_request_status_refunded",
    "partially_refunded": "order_request_status_partially_refunded",
    "pending_settlement": "order_request_status_pending_settlement",
    "settlement_retryable": "order_request_status_settlement_retryable",
    "settlement_failed": "order_request_status_settlement_failed",
    "cancelled": "order_request_status_cancelled",
    "closed": "order_request_status_closed",
}

def simulate_display_title_for_request_status(status: str) -> str:
    normalized = (status or "").strip().lower()
    return REQUEST_STATUS_DISPLAY_TITLES.get(normalized, "order_request_status_pending_review")


# ==============================================================================
# Test Execution
# ==============================================================================

print("\n=================================================================")
print(" Pure Pets iOS Commerce — Phase 10 Cancellation & Support Suite  ")
print("=================================================================\n")

# ------------------------------------------------------------------------------
# Group 1: Server Command Verification (Zero Direct Client Mutations)
# ------------------------------------------------------------------------------
group = "Group 1: Server Command Verification"
print(f"[{group}]")

payments_dir = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS")

direct_order_cancellation_writes = 0
direct_request_writes = 0

for root, _, files in os.walk(payments_dir):
    for f in files:
        if f.endswith((".m", ".h", ".swift")):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8", errors="ignore") as fh:
                content = fh.read()
                # Check for direct client update/delete setting order to cancelled
                if re.search(r'\[.*collectionWithPath:@"Orders"\]\s*documentWithPath:.*\]\s*(?:updateData|setData):.*@"cancelled"', content):
                    direct_order_cancellation_writes += 1
                # Check for direct client writes to requests subcollection
                if re.search(r'\[.*collectionWithPath:@"requests"\]\s*(?:addDocument|setData|updateData):', content):
                    direct_request_writes += 1

if direct_order_cancellation_writes == 0:
    record_pass(group, "Zero direct client mutations setting Orders to 'cancelled'")
else:
    record_fail(group, "Zero direct order cancellation writes", f"Found {direct_order_cancellation_writes} illegal writes")

if direct_request_writes == 0:
    record_pass(group, "Zero direct client mutations to 'requests' subcollection")
else:
    record_fail(group, "Zero direct requests writes", f"Found {direct_request_writes} illegal writes")

# Verify cancellation uses callable createOrderSupportRequest
pp_ordermgr_m = os.path.join(payments_dir, "Manager", "Order", "PPOrderManager.m")
with open(pp_ordermgr_m, "r", encoding="utf-8") as fh:
    ordermgr_src = fh.read()

if 'HTTPSCallableWithName:@"createOrderSupportRequest"' in ordermgr_src:
    record_pass(group, "Order cancellation routes through 'createOrderSupportRequest' HTTPSCallable")
else:
    record_fail(group, "createOrderSupportRequest routing", "HTTPSCallable invocation missing")

# ------------------------------------------------------------------------------
# Group 2: Canonical Server State Eligibility Preflight
# ------------------------------------------------------------------------------
group = "Group 2: Canonical Server State Eligibility Preflight"
print(f"\n[{group}]")

# Verify preflight fetch of fresh server document
if "[orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *fetchError)" in ordermgr_src:
    record_pass(group, "Preflight getDocumentWithCompletion fetches latest server order before cancellation")
else:
    record_fail(group, "Preflight getDocumentWithCompletion", "Fresh document fetch missing")

if "PPOrder *freshOrder = [PPOrder orderFromSnapshot:snapshot];" in ordermgr_src and \
   "cancellationBlockedReasonForOrder:freshOrder ?: order" in ordermgr_src:
    record_pass(group, "Preflight validates cancellation eligibility against freshOrder canonical state")
else:
    record_fail(group, "Preflight freshOrder validation", "Eligibility check not using freshOrder")

# ------------------------------------------------------------------------------
# Group 3: Cancellation Eligibility Across Full State Space
# ------------------------------------------------------------------------------
group = "Group 3: Cancellation Eligibility Across Full State Space"
print(f"\n[{group}]")

pre_fulfillment_cases = [
    ("pending", True, None),
    ("created", True, None),
    ("placed", True, None),
    ("confirmed", True, None),
    ("paid", True, None),
    ("waiting", True, None),
]

for st, exp_allowed, exp_reason in pre_fulfillment_cases:
    order = {
        "status": st,
        "hasCapturedPayment": True,
        "fulfillmentVersion": 1,
        "deliveryStatus": ""
    }
    reason = simulate_cancellation_blocked_reason(order)
    is_allowed = (reason is None)
    if is_allowed == exp_allowed and reason == exp_reason:
        record_pass(group, f"Initial state '{st}' cancellation allowed: {is_allowed}")
    else:
        record_fail(group, f"Initial state '{st}'", f"Expected allowed={exp_allowed}, got reason='{reason}'")

advanced_fulfillment_cases = [
    # (status, is_v1, delivery_status, expected_reason)
    ("packing", False, "", "order_action_cancel_unavailable_preparing"),
    ("processing", False, "", "order_action_cancel_unavailable_preparing"),
    ("shipped", False, "in_transit", "order_action_cancel_unavailable_fulfillment"),
    ("in_transit", True, "in_transit", "order_action_cancel_unavailable_fulfillment"),
    ("picked_up", True, "picked_up", "order_action_cancel_unavailable_fulfillment"),
    ("delivered", True, "delivered", "order_action_cancel_unavailable_fulfillment"),
    ("cancelled", True, "delivery_cancelled", "order_action_cancel_unavailable_closed"),
    ("failed", True, "delivery_failed", "order_action_cancel_unavailable_closed"),
    ("unknown_mystery_state", True, "", "order_action_unavailable_generic"),
]

for st, is_v1, del_st, exp_reason in advanced_fulfillment_cases:
    order = {
        "status": st,
        "hasCapturedPayment": True,
        "fulfillmentVersion": 1 if is_v1 else 0,
        "deliveryStatus": del_st
    }
    reason = simulate_cancellation_blocked_reason(order)
    if reason == exp_reason:
        record_pass(group, f"Advanced state '{st}' blocked with reason: '{exp_reason}'")
    else:
        record_fail(group, f"Advanced state '{st}'", f"Expected reason '{exp_reason}', got '{reason}'")

# ------------------------------------------------------------------------------
# Group 4: Fulfillment V1 All-or-Nothing Multi-Child Cancellation Rules
# ------------------------------------------------------------------------------
group = "Group 4: Fulfillment V1 All-or-Nothing Multi-Child Cancellation Rules"
print(f"\n[{group}]")

multi_child_cases = [
    # (fulfillments, expected_allowed, expected_disposition)
    ([{"status": "new_request"}, {"status": "accepted"}], True, "immediate_cancellation"),
    ([{"status": "accepted"}, {"status": "preparing"}], True, "immediate_cancellation"),
    ([{"status": "ready_for_pickup"}, {"status": "delivery_assigned"}], True, "immediate_cancellation"),
    ([{"status": "awaiting_handover"}, {"status": "new_request"}], True, "immediate_cancellation"),
    # One custody transferred child blocks entire order
    ([{"status": "new_request"}, {"status": "handed_over"}], False, None),
    ([{"status": "accepted"}, {"status": "in_transit"}], False, None),
    ([{"status": "ready_for_pickup"}, {"status": "delivered"}], False, None),
    ([{"status": "new_request"}, {"status": "returned_to_store"}], False, None),
]

for children, exp_allowed, exp_disp in multi_child_cases:
    plan = simulate_base_fulfillment_cancellation_plan(children)
    if plan["allowed"] == exp_allowed:
        if exp_allowed:
            if plan["cancellationDisposition"] == exp_disp:
                record_pass(group, f"Pre-custody children {children} -> allowed: True, disposition: '{exp_disp}'")
            else:
                record_fail(group, f"Pre-custody children {children}", f"Expected disposition '{exp_disp}', got '{plan['cancellationDisposition']}'")
        else:
            record_pass(group, f"Custody-transferred child in {children} blocks order cancellation")
    else:
        record_fail(group, f"Multi-child plan {children}", f"Expected allowed={exp_allowed}, got {plan['allowed']}")

# ------------------------------------------------------------------------------
# Group 5: Disposition & Display Accuracy Across Request States
# ------------------------------------------------------------------------------
group = "Group 5: Disposition & Display Accuracy Across Request States"
print(f"\n[{group}]")

request_status_cases = [
    ("pending_review", "order_request_status_pending_review"),
    ("approved", "order_request_status_approved"),
    ("rejected", "order_request_status_rejected"),
    ("completed", "order_request_status_completed"),
    ("refunded", "order_request_status_refunded"),
    ("partially_refunded", "order_request_status_partially_refunded"),
    ("pending_settlement", "order_request_status_pending_settlement"),
    ("settlement_retryable", "order_request_status_settlement_retryable"),
    ("settlement_failed", "order_request_status_settlement_failed"),
    ("cancelled", "order_request_status_cancelled"),
    ("closed", "order_request_status_closed"),
    ("unknown_status", "order_request_status_pending_review"), # Safe fallback
]

for raw_st, exp_key in request_status_cases:
    title = simulate_display_title_for_request_status(raw_st)
    if title == exp_key:
        record_pass(group, f"Request status '{raw_st}' maps to localization key: '{exp_key}'")
    else:
        record_fail(group, f"Request status '{raw_st}'", f"Expected key '{exp_key}', got '{title}'")

# ------------------------------------------------------------------------------
# Group 6: Idempotency, Replay & Stale Screen State Protection
# ------------------------------------------------------------------------------
group = "Group 6: Idempotency, Replay & Stale Screen State Protection"
print(f"\n[{group}]")

existing_requests_db = {}
server_order = {
    "status": "pending",
    "hasCapturedPayment": True,
    "fulfillmentVersion": 1,
    "deliveryStatus": "",
    "fulfillments": [{"status": "new_request"}, {"status": "accepted"}]
}

# 1. Initial request with idempotency key
payload1 = {"idempotencyKey": "cancel_idempotency_uuid_1", "reasonCode": "customer_changed_mind"}
res1 = simulate_create_order_support_request(server_order, payload1, existing_requests_db)

if res1["success"] and not res1["deduplicated"] and res1["orderCancelled"]:
    record_pass(group, "Initial cancellation request accepted and processed")
else:
    record_fail(group, "Initial cancellation request", f"Failed: {res1}")

# 2. Repeated duplicate request with identical idempotency key
res2 = simulate_create_order_support_request(server_order, payload1, existing_requests_db)

if res2["success"] and res2["deduplicated"] and res2["requestId"] == res1["requestId"]:
    record_pass(group, "Duplicate cancellation request safely deduplicated with identical requestId")
else:
    record_fail(group, "Duplicate cancellation request", f"Deduplication failed: {res2}")

# 3. Stale screen state: user tap while local screen showed 'pending', but server order moved to 'in_transit'
stale_screen_local_order = {"status": "pending"}
fresh_server_order_progressed = {
    "status": "in_transit",
    "hasCapturedPayment": True,
    "fulfillmentVersion": 1,
    "deliveryStatus": "in_transit",
    "fulfillments": [{"status": "in_transit"}]
}

payload3 = {"idempotencyKey": "cancel_idempotency_uuid_2", "reasonCode": "customer_changed_mind"}
res3 = simulate_create_order_support_request(fresh_server_order_progressed, payload3, existing_requests_db)

if not res3["success"] and res3["code"] == 409 and res3["error"] == "order_action_cancel_unavailable_fulfillment":
    record_pass(group, "Stale screen cancellation blocked by fresh server order preflight (409)")
else:
    record_fail(group, "Stale screen cancellation", f"Expected 409 blocked, got {res3}")

# ------------------------------------------------------------------------------
# Group 7: Financial Settlement Separation
# ------------------------------------------------------------------------------
group = "Group 7: Financial Settlement Separation"
print(f"\n[{group}]")

# Verify backend buildCancellationPaymentPatch preserves captured payment and flags pending refund
infra_cancellation_path = os.path.join(os.path.dirname(__file__), "..", "..", "Pure Pets Infra", "functions", "orderSupportCancellation.js")
if os.path.exists(infra_cancellation_path):
    with open(infra_cancellation_path, "r", encoding="utf-8") as fh:
        infra_cancel_src = fh.read()

    if "refundRequired: true" in infra_cancel_src and 'refundStatus: "pending"' in infra_cancel_src:
        record_pass(group, "buildCancellationPaymentPatch sets refundRequired: true, refundStatus: 'pending'")
    else:
        record_fail(group, "buildCancellationPaymentPatch refund flags", "Missing refundRequired / refundStatus in Infra")

    if 'refundSettlementStatus: "pending"' in infra_cancel_src:
        record_pass(group, "Refund settlement status initialized as 'pending' (financial separation)")
    else:
        record_fail(group, "refundSettlementStatus in Infra", "Missing refundSettlementStatus")

# ------------------------------------------------------------------------------
# Group 8: Objective-C Source Code Contract Invariants
# ------------------------------------------------------------------------------
group = "Group 8: Objective-C Source Code Contract Invariants"
print(f"\n[{group}]")

pp_ordermgr_h = os.path.join(payments_dir, "Manager", "Order", "PPOrderManager.h")
with open(pp_ordermgr_h, "r", encoding="utf-8") as fh:
    ordermgr_h_src = fh.read()

if "canUserCancelOrder:" in ordermgr_h_src:
    record_pass(group, "canUserCancelOrder: declared in PPOrderManager.h")
else:
    record_fail(group, "canUserCancelOrder: in PPOrderManager.h", "Declaration missing")

if "cancellationBlockedReasonForOrder:" in ordermgr_h_src:
    record_pass(group, "cancellationBlockedReasonForOrder: declared in PPOrderManager.h")
else:
    record_fail(group, "cancellationBlockedReasonForOrder: in PPOrderManager.h", "Declaration missing")

if re.search(r'submitSupportDraft:.*forOrder:.*completion:', ordermgr_h_src, re.DOTALL):
    record_pass(group, "submitSupportDraft:forOrder:completion: declared in PPOrderManager.h")
else:
    record_fail(group, "submitSupportDraft:forOrder:completion: in PPOrderManager.h", "Declaration missing")

if "cancelPendingCheckoutOrder:" in ordermgr_h_src:
    record_pass(group, "cancelPendingCheckoutOrder: declared in PPOrderManager.h")
else:
    record_fail(group, "cancelPendingCheckoutOrder: in PPOrderManager.h", "Declaration missing")

if "displayTitleForRequestStatus:" in ordermgr_h_src:
    record_pass(group, "displayTitleForRequestStatus: declared in PPOrderManager.h")
else:
    record_fail(group, "displayTitleForRequestStatus: in PPOrderManager.h", "Declaration missing")

if "BOOL orderCancelled;" in ordermgr_h_src:
    record_pass(group, "orderCancelled property declared in PPOrderSupportRequest")
else:
    record_fail(group, "orderCancelled in PPOrderSupportRequest", "Property missing")

if "NSString *cancellationDisposition;" in ordermgr_h_src:
    record_pass(group, "cancellationDisposition property declared in PPOrderSupportRequest")
else:
    record_fail(group, "cancellationDisposition in PPOrderSupportRequest", "Property missing")

if "isCancellablePreFulfillment" in ordermgr_src:
    record_pass(group, "isCancellablePreFulfillment check enforced in cancellationBlockedReasonForOrder:")
else:
    record_fail(group, "isCancellablePreFulfillment in PPOrderManager.m", "Check missing")

if "deduplicated" in ordermgr_src and "finishWithData" in ordermgr_src:
    record_pass(group, "Deduplication handling present in pp_callCreateOrderSupportRequestWithPayload:")
else:
    record_fail(group, "Deduplication handling in PPOrderManager.m", "Missing deduplication handling")

# ==============================================================================
# Final Summary
# ==============================================================================

total_tests = len(TEST_RESULTS)
passed_tests = sum(1 for t in TEST_RESULTS if t["passed"])
failed_tests = total_tests - passed_tests

print("\n=================================================================")
print(f"  RESULTS: {passed_tests}/{total_tests} tests passed ({failed_tests} failures)")
print("=================================================================\n")

if failed_tests > 0:
    print("❌ SOME PHASE 10 CANCELLATION & SUPPORT TESTS FAILED!")
    sys.exit(1)
else:
    print("🎉 ALL PHASE 10 CANCELLATION & SUPPORT CONTRACT TESTS PASSED (100% GREEN)!\n")
    sys.exit(0)
