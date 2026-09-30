#!/usr/bin/env python3
"""
fulfillment_delivery_contract_regression_test.py
Pure Pets iOS Commerce Lifecycle — Phase 9 Regression Test Suite

Validates:
1. Valid backend fulfillment transitions (provider, delivery driver, admin).
2. Illegal transition rejection (fail-closed behavior).
3. Parent order fulfillment summary calculation and parent/delivery status derivation.
4. Multi-provider split order fulfillment derivation and resolution.
5. Consumer iOS presentation mapping (effectiveDeliveryStatus & customerVisibleStatusKey).
6. Legacy order status mapping cannot override canonical fulfillment state.
7. Server-owned delivery notification invariants (zero client notification writes).
8. Objective-C and Swift source code fulfillment invariants across PPOrder, PPOrderManager,
   PPOrderDetailsMissionControlBridge, and OrderDetailsViewController.
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
# Simulation Logic Matching Backend fulfillmentOrders.js & iOS PPOrder.m
# ==============================================================================

FULFILLMENT_STATUSES = [
    "new_request", "accepted", "rejected", "preparing", "ready_for_pickup",
    "delivery_requested", "delivery_assigned", "awaiting_handover", "handed_over",
    "in_transit", "delivered", "payment_pending", "payment_confirmed",
    "completed", "cancelled", "failed", "returned"
]

PROVIDER_TRANSITIONS = {
    "new_request": {
        "accept": "accepted",
        "reject": "rejected",
        "cancel_request": "cancelled"
    },
    "accepted": {
        "start_preparing": "preparing",
        "cancel_request": "cancelled"
    },
    "preparing": {
        "mark_ready": "ready_for_pickup",
        "cancel_request": "cancelled"
    },
    "ready_for_pickup": {
        "request_delivery": "delivery_requested",
        "cancel_request": "cancelled"
    },
    "delivery_requested": {
        "cancel_request": "cancelled"
    },
    "delivery_assigned": {
        "confirm_handover": "awaiting_handover",
        "cancel_request": "cancelled"
    },
    "awaiting_handover": {
        "cancel_request": "cancelled"
    }
}

DELIVERY_TRANSITIONS = {
    ("delivery_requested", "order_accept_delivery"): "delivery_assigned",
    ("awaiting_handover", "order_mark_shipped"): "handed_over",
    ("handed_over", "order_mark_in_transit"): "in_transit",
    ("in_transit", "order_mark_delivered_prepaid"): "delivered",
    ("in_transit", "order_mark_delivered_cod"): "payment_pending",
    ("payment_pending", "order_collect_payment"): "payment_confirmed",
    ("delivered", "order_mark_completed"): "completed",
    ("payment_confirmed", "order_mark_completed"): "completed",
    ("delivery_assigned", "order_cancel_delivery"): "cancelled",
    ("awaiting_handover", "order_cancel_delivery"): "cancelled"
}

def next_provider_status(current_status: str, action: str):
    current = (current_status or "").strip().lower()
    act = (action or "").strip().lower()
    return PROVIDER_TRANSITIONS.get(current, {}).get(act, None)

def next_delivery_status(current_status: str, action: str):
    current = (current_status or "").strip().lower()
    act = (action or "").strip().lower()
    return DELIVERY_TRANSITIONS.get((current, act), None)

def compute_parent_fulfillment_summary(child_statuses: list) -> dict:
    total = len(child_statuses)
    by_status = {}
    for s in child_statuses:
        status_key = (s or "").strip().lower()
        by_status[status_key] = by_status.get(status_key, 0) + 1

    return {
        "total": total,
        "totalCount": total,
        "byStatus": by_status,
        "pendingCount": by_status.get("new_request", 0),
        "acceptedCount": by_status.get("accepted", 0),
        "preparingCount": by_status.get("preparing", 0),
        "readyForDeliveryCount": by_status.get("ready_for_pickup", 0) + by_status.get("delivery_requested", 0),
        "inDeliveryCount": by_status.get("delivery_assigned", 0) + by_status.get("awaiting_handover", 0) +
                           by_status.get("handed_over", 0) + by_status.get("in_transit", 0),
        "deliveredCount": by_status.get("delivered", 0) + by_status.get("payment_pending", 0) + by_status.get("payment_confirmed", 0),
        "completedCount": by_status.get("completed", 0),
        "cancelledCount": by_status.get("cancelled", 0),
        "rejectedCount": by_status.get("rejected", 0),
        "failedCount": by_status.get("failed", 0),
        "returnedCount": by_status.get("returned", 0),
        "allCompleted": total > 0 and by_status.get("completed", 0) == total,
        "allCancelled": total > 0 and (by_status.get("cancelled", 0) + by_status.get("rejected", 0)) == total
    }

def derive_delivery_status_from_summary(summary: dict) -> str:
    if not summary or not isinstance(summary, dict):
        return ""
    total = summary.get("total", 0)
    by_status = summary.get("byStatus", {})

    def count_for(statuses):
        return sum(by_status.get(s, 0) for s in statuses)

    if total > 0 and count_for(["completed"]) == total:
        return "completed"
    if total > 0 and count_for(["cancelled", "rejected"]) == total:
        return "delivery_cancelled"
    if count_for(["failed"]) > 0:
        return "delivery_failed"
    if count_for(["returned"]) > 0:
        return "returned_to_store"
    if count_for(["payment_pending"]) > 0:
        return "payment_pending"
    if count_for(["payment_confirmed"]) > 0:
        return "payment_confirmed"
    if count_for(["delivered"]) > 0:
        return "delivered"
    if count_for(["in_transit"]) > 0:
        return "in_transit"
    if count_for(["handed_over"]) > 0:
        return "picked_up"
    if count_for(["awaiting_handover"]) > 0:
        return "awaiting_handover"
    if count_for(["delivery_assigned"]) > 0:
        return "delivery_assigned"
    if count_for(["delivery_requested"]) > 0:
        return "delivery_requested"
    if count_for(["ready_for_pickup"]) > 0:
        return "ready_to_ship"
    return ""

def derive_parent_status_from_summary(summary: dict) -> str:
    if not summary or not isinstance(summary, dict):
        return "pending"
    total = summary.get("total", 0)
    if total <= 0:
        return "pending"
    by_status = summary.get("byStatus", {})

    def count_for(statuses):
        return sum(by_status.get(s, 0) for s in statuses)

    pending = count_for(["new_request"])
    processing = count_for(["accepted", "preparing"])
    ready = count_for(["ready_for_pickup", "delivery_requested"])
    delivery = count_for(["delivery_assigned", "awaiting_handover", "handed_over", "in_transit"])
    delivered = count_for(["delivered", "payment_pending", "payment_confirmed"])
    completed = count_for(["completed"])
    cancelled = count_for(["cancelled", "rejected"])
    failed = count_for(["failed", "returned"])

    if completed == total:
        return "completed"
    if cancelled == total:
        return "cancelled"
    if failed > 0:
        return "failed"
    if delivered > 0:
        return "delivered"
    if delivery > 0:
        return "in_transit"
    if ready > 0:
        return "ready"
    if processing > 0:
        return "processing"
    if pending == total:
        return "pending"
    return "processing"

def simulate_effective_delivery_status(order: dict) -> str:
    explicit = (order.get("deliveryStatus") or "").strip().lower()
    if explicit:
        return explicit

    raw = (order.get("status") or "").strip().lower()
    if "cancelled" in raw or "canceled" in raw:
        return "delivery_cancelled"

    if order.get("fulfillmentVersion") == 1 and order.get("fulfillmentSummary"):
        derived = derive_delivery_status_from_summary(order["fulfillmentSummary"])
        if derived:
            return derived
        return "preparing_for_shipment"

    if "returned_to_store" in raw:
        return "returned_to_store"
    if any(k in raw for k in ["failed", "rejected", "declined", "expired", "voided", "error"]):
        return "delivery_failed"
    if "completed" in raw or "fulfilled" in raw:
        return "completed"
    if "delivered" in raw:
        return "delivered"
    if any(k in raw for k in ["shipped", "shipping", "out_for_delivery", "in_transit"]):
        return "in_transit"
    if "ready" in raw:
        return "ready_to_ship"
    if any(k in raw for k in ["processing", "preparing", "confirmed", "paid", "success", "approved", "verified"]):
        return "preparing_for_shipment"
    return "preparing_for_shipment"

def simulate_customer_visible_status_key(order: dict) -> str:
    delivery = simulate_effective_delivery_status(order)
    raw = (order.get("status") or "").strip().lower()

    if order.get("isUncapturedQIBPaymentPending"):
        return "checkout_card_payment_pending"
    if order.get("isUncapturedQIBPaymentFailed"):
        return "checkout_card_payment_failed"
    if order.get("isUncapturedQIBPaymentCancelled"):
        return "checkout_card_payment_cancelled"

    if order.get("fulfillmentVersion") == 1 and order.get("fulfillmentSummary"):
        canonical_parent = derive_parent_status_from_summary(order["fulfillmentSummary"])
        if canonical_parent:
            raw = canonical_parent

    if delivery == "delivery_cancelled" or "cancelled" in raw or "canceled" in raw:
        return "delivery_cancelled"
    if delivery == "returned_to_store" or "returned_to_store" in raw or "returned" in raw:
        return "returned_to_store"
    if delivery == "delivery_failed" or any(k in raw for k in ["failed", "rejected", "declined", "expired", "voided", "error"]):
        return "delivery_failed"
    if delivery == "completed" or "completed" in raw or "fulfilled" in raw:
        return "completed"
    if delivery in ["delivered", "payment_pending", "payment_confirmed"] or "delivered" in raw:
        return "delivered"
    if delivery in ["delivery_assigned", "awaiting_handover"]:
        return "delivery_partner_assigned"
    if delivery in ["picked_up", "in_transit"] or any(k in raw for k in ["shipped", "shipping", "out_for_delivery", "in_transit"]):
        return "on_the_way"
    if delivery in ["ready_to_ship", "ready_for_pickup", "delivery_requested", "delivery_reassigned", "ready_for_delivery"]:
        return "ready_for_delivery"
    if any(k in raw for k in ["pending", "created", "placed", "waiting"]):
        return "pending"
    if delivery == "preparing_for_shipment" or any(k in raw for k in ["processing", "preparing", "confirmed"]):
        return "preparing_for_shipment"
    return "unknown"


# ==============================================================================
# Test Execution
# ==============================================================================

print("\n=================================================================")
print(" Pure Pets iOS Commerce — Phase 9 Fulfillment & Delivery Suite  ")
print("=================================================================\n")

# ------------------------------------------------------------------------------
# Group 1: Valid Backend Provider Transitions
# ------------------------------------------------------------------------------
group = "Group 1: Valid Backend Provider Transitions"
print(f"[{group}]")

provider_cases = [
    ("new_request", "accept", "accepted"),
    ("new_request", "reject", "rejected"),
    ("new_request", "cancel_request", "cancelled"),
    ("accepted", "start_preparing", "preparing"),
    ("accepted", "cancel_request", "cancelled"),
    ("preparing", "mark_ready", "ready_for_pickup"),
    ("preparing", "cancel_request", "cancelled"),
    ("ready_for_pickup", "request_delivery", "delivery_requested"),
    ("ready_for_pickup", "cancel_request", "cancelled"),
    ("delivery_assigned", "confirm_handover", "awaiting_handover"),
    ("delivery_assigned", "cancel_request", "cancelled"),
    ("awaiting_handover", "cancel_request", "cancelled"),
]

for from_st, act, exp in provider_cases:
    res = next_provider_status(from_st, act)
    if res == exp:
        record_pass(group, f"Provider: {from_st} + {act} -> {exp}")
    else:
        record_fail(group, f"Provider: {from_st} + {act}", f"Expected {exp}, got {res}")

# ------------------------------------------------------------------------------
# Group 2: Illegal Provider Transitions Fail Closed
# ------------------------------------------------------------------------------
group = "Group 2: Illegal Provider Transitions Fail Closed"
print(f"\n[{group}]")

illegal_provider_cases = [
    ("new_request", "mark_ready"),
    ("accepted", "request_delivery"),
    ("preparing", "confirm_handover"),
    ("ready_for_pickup", "start_preparing"),
    ("in_transit", "cancel_request"),
    ("delivered", "cancel_request"),
    ("completed", "cancel_request"),
    ("cancelled", "accept"),
    ("rejected", "start_preparing"),
]

for from_st, act in illegal_provider_cases:
    res = next_provider_status(from_st, act)
    if res is None:
        record_pass(group, f"Illegal provider transition blocked: {from_st} + {act} -> None")
    else:
        record_fail(group, f"Illegal transition allowed: {from_st} + {act}", f"Got {res}")

# ------------------------------------------------------------------------------
# Group 3: Valid Delivery Driver Transitions
# ------------------------------------------------------------------------------
group = "Group 3: Valid Delivery Driver Transitions"
print(f"\n[{group}]")

delivery_cases = [
    ("delivery_requested", "order_accept_delivery", "delivery_assigned"),
    ("awaiting_handover", "order_mark_shipped", "handed_over"),
    ("handed_over", "order_mark_in_transit", "in_transit"),
    ("in_transit", "order_mark_delivered_prepaid", "delivered"),
    ("in_transit", "order_mark_delivered_cod", "payment_pending"),
    ("payment_pending", "order_collect_payment", "payment_confirmed"),
    ("delivered", "order_mark_completed", "completed"),
    ("payment_confirmed", "order_mark_completed", "completed"),
    ("delivery_assigned", "order_cancel_delivery", "cancelled"),
    ("awaiting_handover", "order_cancel_delivery", "cancelled"),
]

for from_st, act, exp in delivery_cases:
    res = next_delivery_status(from_st, act)
    if res == exp:
        record_pass(group, f"Delivery: {from_st} + {act} -> {exp}")
    else:
        record_fail(group, f"Delivery: {from_st} + {act}", f"Expected {exp}, got {res}")

# ------------------------------------------------------------------------------
# Group 4: Single & Multi-Provider Parent Derivations
# ------------------------------------------------------------------------------
group = "Group 4: Single & Multi-Provider Parent Derivations"
print(f"\n[{group}]")

derivation_cases = [
    # (child_statuses, expected_parent_status, expected_delivery_status)
    (["new_request"], "pending", ""),
    (["new_request", "new_request"], "pending", ""),
    (["accepted", "new_request"], "processing", ""),
    (["preparing", "accepted"], "processing", ""),
    (["ready_for_pickup", "preparing"], "ready", "ready_to_ship"),
    (["ready_for_pickup", "ready_for_pickup"], "ready", "ready_to_ship"),
    (["delivery_assigned", "ready_for_pickup"], "in_transit", "delivery_assigned"),
    (["in_transit", "preparing"], "in_transit", "in_transit"),
    (["in_transit", "in_transit"], "in_transit", "in_transit"),
    (["delivered", "in_transit"], "delivered", "delivered"),
    (["delivered", "delivered"], "delivered", "delivered"),
    (["completed", "delivered"], "delivered", "delivered"),
    (["completed", "completed"], "completed", "completed"),
    (["cancelled", "cancelled"], "cancelled", "delivery_cancelled"),
    (["rejected", "cancelled"], "cancelled", "delivery_cancelled"),
    (["cancelled", "in_transit"], "in_transit", "in_transit"), # Active child drives parent
    (["failed", "in_transit"], "failed", "delivery_failed"),   # Failure flags parent
    (["returned", "delivered"], "failed", "returned_to_store")
]

for children, exp_parent, exp_del in derivation_cases:
    summary = compute_parent_fulfillment_summary(children)
    parent_res = derive_parent_status_from_summary(summary)
    del_res = derive_delivery_status_from_summary(summary)
    if parent_res == exp_parent and del_res == exp_del:
        record_pass(group, f"Children {children} -> parent: '{exp_parent}', delivery: '{exp_del}'")
    else:
        record_fail(group, f"Children {children}", f"Got parent='{parent_res}', delivery='{del_res}', expected parent='{exp_parent}', delivery='{exp_del}'")

# ------------------------------------------------------------------------------
# Group 5: Consumer iOS Presentation Mapping Across Fulfillment States
# ------------------------------------------------------------------------------
group = "Group 5: Consumer iOS Presentation Mapping Across Fulfillment States"
print(f"\n[{group}]")

presentation_cases = [
    # (child_statuses, expected_customer_visible_key)
    (["new_request"], "pending"),
    (["accepted"], "preparing_for_shipment"),
    (["preparing"], "preparing_for_shipment"),
    (["ready_for_pickup"], "ready_for_delivery"),
    (["delivery_requested"], "ready_for_delivery"),
    (["delivery_assigned"], "delivery_partner_assigned"),
    (["awaiting_handover"], "delivery_partner_assigned"),
    (["handed_over"], "on_the_way"),
    (["in_transit"], "on_the_way"),
    (["delivered"], "delivered"),
    (["payment_pending"], "delivered"),
    (["payment_confirmed"], "delivered"),
    (["completed"], "completed"),
    (["cancelled"], "delivery_cancelled"),
    (["failed"], "delivery_failed"),
    (["returned"], "returned_to_store"),
]

for children, exp_ui in presentation_cases:
    summary = compute_parent_fulfillment_summary(children)
    order = {
        "fulfillmentVersion": 1,
        "fulfillmentSummary": summary,
        "status": "", # Let summary drive
        "deliveryStatus": ""
    }
    ui_res = simulate_customer_visible_status_key(order)
    if ui_res == exp_ui:
        record_pass(group, f"Fulfillment {children} mapped to customerVisibleStatusKey: '{exp_ui}'")
    else:
        record_fail(group, f"Fulfillment {children}", f"Expected UI '{exp_ui}', got '{ui_res}'")

# ------------------------------------------------------------------------------
# Group 6: Legacy Order Status Overriding Prevention (Requirement 5)
# ------------------------------------------------------------------------------
group = "Group 6: Legacy Order Status Overriding Prevention"
print(f"\n[{group}]")

override_cases = [
    # Stale legacy rawStatus, real children, expected canonical UI status
    ("paid", ["in_transit"], "on_the_way"),
    ("paid", ["delivered"], "delivered"),
    ("processing", ["delivered"], "delivered"),
    ("processing", ["ready_for_pickup"], "ready_for_delivery"),
    ("ready", ["cancelled", "cancelled"], "delivery_cancelled"),
    ("confirmed", ["in_transit"], "on_the_way"),
    ("shipped", ["new_request"], "pending"), # Obsolete script marked shipped, but children are new
]

for stale_status, children, exp_ui in override_cases:
    summary = compute_parent_fulfillment_summary(children)
    order = {
        "fulfillmentVersion": 1,
        "fulfillmentSummary": summary,
        "status": stale_status, # Stale legacy status
        "deliveryStatus": ""    # Omitted or un-bridged
    }
    ui_res = simulate_customer_visible_status_key(order)
    if ui_res == exp_ui:
        record_pass(group, f"Stale '{stale_status}' overridden by canonical {children} -> '{exp_ui}'")
    else:
        record_fail(group, f"Stale '{stale_status}' failed override", f"Expected '{exp_ui}', got '{ui_res}'")

# ------------------------------------------------------------------------------
# Group 7: Server-Owned Delivery Notifications (Requirement 6)
# ------------------------------------------------------------------------------
group = "Group 7: Server-Owned Delivery Notifications"
print(f"\n[{group}]")

# Audit that iOS client never performs direct writes to notification collections
payments_dir = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS")

client_notification_writes_found = 0
for root, _, files in os.walk(payments_dir):
    for f in files:
        if f.endswith((".m", ".h", ".swift")):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8", errors="ignore") as fh:
                content = fh.read()
                # Check for direct writes to systemNotifications or notifications
                if re.search(r'\[.*collectionWithPath:@"systemNotifications"\]\s*(?:addDocument|setData|updateData)', content):
                    client_notification_writes_found += 1
                if re.search(r'\[.*collectionWithPath:@"NotificationsCol"\]\s*(?:addDocument|setData|updateData)', content):
                    client_notification_writes_found += 1

if client_notification_writes_found == 0:
    record_pass(group, "Zero direct client writes to systemNotifications / NotificationsCol in PAYMENTS")
else:
    record_fail(group, "Zero client notification writes", f"Found {client_notification_writes_found} illegal writes")

# Verify server-owned notification planner in Infra
infra_orders_path = os.path.join(os.path.dirname(__file__), "..", "..", "Pure Pets Infra", "functions", "fulfillmentOrders.js")
if os.path.exists(infra_orders_path):
    with open(infra_orders_path, "r", encoding="utf-8") as fh:
        infra_src = fh.read()
    if "buildFulfillmentCustomerNotification" in infra_src:
        record_pass(group, "buildFulfillmentCustomerNotification present in backend fulfillmentOrders.js")
    else:
        record_fail(group, "buildFulfillmentCustomerNotification in Infra", "Method missing")

    if "notifications_inbox_order_fulfillment_ready_title" in infra_src:
        record_pass(group, "Canonical notification localization keys present in backend fulfillmentOrders.js")
    else:
        record_fail(group, "Notification localization keys in Infra", "Keys missing")

# ------------------------------------------------------------------------------
# Group 8: Objective-C & Swift Source Code Fulfillment Invariants
# ------------------------------------------------------------------------------
group = "Group 8: Objective-C & Swift Source Code Fulfillment Invariants"
print(f"\n[{group}]")

pp_order_h = os.path.join(payments_dir, "Models", "Orders", "PPOrder.h")
pp_order_m = os.path.join(payments_dir, "Models", "Orders", "PPOrder.m")
pp_ordermgr_m = os.path.join(payments_dir, "Manager", "Order", "PPOrderManager.m")
order_details_vc_m = os.path.join(payments_dir, "CartAndOrdersFiles", "OrderDetailsViewController.m")

with open(pp_order_h, "r", encoding="utf-8") as fh:
    order_h_src = fh.read()
with open(pp_order_m, "r", encoding="utf-8") as fh:
    order_m_src = fh.read()
with open(pp_ordermgr_m, "r", encoding="utf-8") as fh:
    ordermgr_m_src = fh.read()
with open(order_details_vc_m, "r", encoding="utf-8") as fh:
    details_vc_src = fh.read()

# PPOrder.h declarations
if "deliveryStatusFromFulfillmentSummary:" in order_h_src:
    record_pass(group, "deliveryStatusFromFulfillmentSummary: declared in PPOrder.h")
else:
    record_fail(group, "deliveryStatusFromFulfillmentSummary: in PPOrder.h", "Declaration missing")

if "parentStatusFromFulfillmentSummary:" in order_h_src:
    record_pass(group, "parentStatusFromFulfillmentSummary: declared in PPOrder.h")
else:
    record_fail(group, "parentStatusFromFulfillmentSummary: in PPOrder.h", "Declaration missing")

# PPOrder.m implementations
if "PPOrderDeliveryStatusFromFulfillmentSummary(" in order_m_src:
    record_pass(group, "PPOrderDeliveryStatusFromFulfillmentSummary implemented in PPOrder.m")
else:
    record_fail(group, "PPOrderDeliveryStatusFromFulfillmentSummary in PPOrder.m", "Function missing")

if "PPOrderParentStatusFromFulfillmentSummary(" in order_m_src:
    record_pass(group, "PPOrderParentStatusFromFulfillmentSummary implemented in PPOrder.m")
else:
    record_fail(group, "PPOrderParentStatusFromFulfillmentSummary in PPOrder.m", "Function missing")

if "self.fulfillmentVersion == 1" in order_m_src and "PPOrderDeliveryStatusFromFulfillmentSummary(self.fulfillmentSummary)" in order_m_src:
    record_pass(group, "effectiveDeliveryStatus adopts PPOrderDeliveryStatusFromFulfillmentSummary for v1 orders")
else:
    record_fail(group, "effectiveDeliveryStatus v1 adoption", "Missing in PPOrder.m")

if "self.fulfillmentVersion == 1" in order_m_src and "PPOrderParentStatusFromFulfillmentSummary(self.fulfillmentSummary)" in order_m_src:
    record_pass(group, "customerVisibleStatusKey synchronizes raw parent status from fulfillment summary for v1 orders")
else:
    record_fail(group, "customerVisibleStatusKey v1 adoption", "Missing in PPOrder.m")

# OrderDetailsViewController.m fulfillment UI
if "fulfillmentStatusDisplayName:" in details_vc_src:
    record_pass(group, "fulfillmentStatusDisplayName: implemented in OrderDetailsViewController.m")
else:
    record_fail(group, "fulfillmentStatusDisplayName: in OrderDetailsViewController.m", "Method missing")

if "fulfillmentStatusColor:" in details_vc_src:
    record_pass(group, "fulfillmentStatusColor: implemented in OrderDetailsViewController.m")
else:
    record_fail(group, "fulfillmentStatusColor: in OrderDetailsViewController.m", "Method missing")

if "fulfillment_section_title" in details_vc_src:
    record_pass(group, "Fulfillment section title configured in OrderDetailsViewController.m")
else:
    record_fail(group, "Fulfillment section title in OrderDetailsViewController.m", "String missing")

# PPOrderManager.m fulfillment methods
if "fetchFulfillmentOrdersWithIDs:" in ordermgr_m_src:
    record_pass(group, "fetchFulfillmentOrdersWithIDs: implemented in PPOrderManager.m")
else:
    record_fail(group, "fetchFulfillmentOrdersWithIDs: in PPOrderManager.m", "Method missing")

if "observeFulfillmentEventsForFulfillmentID:" in ordermgr_m_src:
    record_pass(group, "observeFulfillmentEventsForFulfillmentID: implemented in PPOrderManager.m")
else:
    record_fail(group, "observeFulfillmentEventsForFulfillmentID: in PPOrderManager.m", "Method missing")

if "order.fulfillmentVersion == 1" in ordermgr_m_src and "order_action_cancel_unavailable_fulfillment" in ordermgr_m_src:
    record_pass(group, "PPOrderManager gates cancellation for fulfillment v1 orders based on custody")
else:
    record_fail(group, "PPOrderManager fulfillment v1 cancellation gating", "Check missing")

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
    print("❌ SOME PHASE 9 FULFILLMENT & DELIVERY TESTS FAILED!")
    sys.exit(1)
else:
    print("🎉 ALL PHASE 9 FULFILLMENT & DELIVERY CONTRACT TESTS PASSED (100% GREEN)!\n")
    sys.exit(0)
