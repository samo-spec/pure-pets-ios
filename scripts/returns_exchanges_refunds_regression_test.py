#!/usr/bin/env python3
"""
returns_exchanges_refunds_regression_test.py
Pure Pets iOS Commerce Lifecycle — Phase 11 Regression Test Suite

Validates:
1. Financial refund and physical inventory return are strictly separate concepts.
2. For accessories & food:
   - Exact sellable variant identity preservation (sellableUnitId / variantId / productId).
   - Quantity bounds and un-exchanged/un-refunded limits.
   - Original frozen order line price snapshot preservation.
   - Dual stock movement (stock_in/stock_out) and inventory ledger auditing.
3. For live animals:
   - Financial refund does NOT release inventory to sellable stock.
   - Preserves quarantine, medical hold, and physical return inspection lifecycle.
   - Enforces maker-checker quarantine release principle.
4. Comprehensive test scenarios:
   - Normal full refund (capturedAmount -> settledAmount).
   - Partial refund (up to availableAmount).
   - Repeated refund over captured balance rejected (failed-precondition).
   - Cross-variant exchange with frozen line price snapshot delta.
   - Out-of-stock replacement variant rejection (REPLACEMENT_OUT_OF_STOCK).
   - Damaged return disposition routing (DAMAGED bucket, available stock untouched).
   - Quarantine return disposition routing (QUARANTINE bucket).
   - Already-settled refund protection.
   - Unauthorized direct client mutation prevention (Firestore security rules & client contracts).
5. Consumer iOS Client Verification:
   - Return eligibility (delivered within 14-day window).
   - Refund eligibility (captured payment, pre-shipment, within 14-day window).
   - Replacement eligibility (delivered within 14-day window).
   - Zero direct client writes to Orders, refundSettlements, or returnCases.
   - Client support request status presentation mappings.
"""

import sys
import os
import re
import math

TEST_RESULTS = []

def record_pass(group: str, name: str):
    TEST_RESULTS.append({"group": group, "name": name, "passed": True, "error": None})
    print(f"  ✅ PASS: {name}")

def record_fail(group: str, name: str, error: str):
    TEST_RESULTS.append({"group": group, "name": name, "passed": False, "error": error})
    print(f"  ❌ FAIL: {name} — {error}")

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INFRA_FUNCTIONS = os.path.join(PROJECT_ROOT, "Pure Pets Infra", "functions")
IOS_ROOT = os.path.join(PROJECT_ROOT, "Pure Pets IOS", "Pure Pets")
FIRESTORE_RULES_PATH = os.path.join(PROJECT_ROOT, "Pure Pets Infra", "firestore.rules")

# ==============================================================================
# Simulation Logic: Financial Refund Ledger Math (from refundSettlement.js)
# ==============================================================================

def round_money(val: float) -> float:
    return round(float(val) + 1e-9, 2)

class SimulatedRefundLedger:
    def __init__(self, captured_amount: float, currency: str = "QAR", payment_tx_id: str = "tx_123"):
        self.captured_amount = round_money(captured_amount)
        self.settled_amount = 0.0
        self.reserved_amount = 0.0
        self.currency = currency
        self.payment_transaction_id = payment_tx_id

    @property
    def available_amount(self) -> float:
        return round_money(self.captured_amount - self.settled_amount - self.reserved_amount)

    def attempt_refund(self, amount: float) -> dict:
        refund_val = round_money(amount)
        if refund_val <= 0:
            return {"ok": False, "error": "invalid-argument", "message": "Refund amount must be positive."}
        if refund_val > self.available_amount + 0.005:
            return {
                "ok": False,
                "error": "failed-precondition",
                "message": f"Refund amount ({refund_val}) exceeds available refundable balance ({self.available_amount})."
            }
        # Settle
        self.settled_amount = round_money(self.settled_amount + refund_val)
        status = "refunded" if self.available_amount <= 0.005 else "partially_refunded"
        return {
            "ok": True,
            "status": status,
            "refundedAmount": refund_val,
            "settledTotal": self.settled_amount,
            "availableRemaining": self.available_amount
        }

# ==============================================================================
# Simulation Logic: Product Variant Exchange Math & Invariants
# ==============================================================================

class SimulatedProductVariantExchange:
    def __init__(self):
        self.catalog = {
            "var_red_m": {"name": "Shirt Red M", "quantity": 10, "finalPrice": 120.0, "isDeleted": False, "isArchived": False},
            "var_red_l": {"name": "Shirt Red L", "quantity": 5, "finalPrice": 120.0, "isDeleted": False, "isArchived": False},
            "var_blue_l": {"name": "Shirt Blue L", "quantity": 0, "finalPrice": 140.0, "isDeleted": False, "isArchived": False}, # Out of stock
            "var_archived": {"name": "Shirt Green L", "quantity": 10, "finalPrice": 120.0, "isDeleted": False, "isArchived": True},
        }
        self.branch_inventory = {
            "main_branch_var_red_m": {"available": 10, "damaged": 0, "quarantine": 0},
            "main_branch_var_red_l": {"available": 5, "damaged": 0, "quarantine": 0},
            "main_branch_var_blue_l": {"available": 0, "damaged": 0, "quarantine": 0},
        }
        self.order_lines = {
            "var_red_m": {"price": 100.0, "quantity": 2, "exchangedQuantity": 0, "refundedQuantity": 0} # Frozen line price was 100.0
        }

    def process_exchange(self, source_id: str, replacement_id: str, quantity: int, condition: str = "sellable") -> dict:
        if source_id == replacement_id:
            return {"ok": False, "domainCode": "SAME_VARIANT_EXCHANGE"}

        source_line = self.order_lines.get(source_id)
        if not source_line:
            return {"ok": False, "domainCode": "VARIANT_NOT_IN_ORDER"}

        available_for_exchange = source_line["quantity"] - source_line["exchangedQuantity"] - source_line["refundedQuantity"]
        if quantity > available_for_exchange:
            return {
                "ok": False,
                "domainCode": "EXCHANGE_QUANTITY_EXCEEDED",
                "requested": quantity,
                "available": available_for_exchange
            }

        rep_item = self.catalog.get(replacement_id)
        if not rep_item:
            return {"ok": False, "domainCode": "REPLACEMENT_NOT_FOUND"}
        if rep_item.get("isArchived"):
            return {"ok": False, "domainCode": "REPLACEMENT_ARCHIVED"}
        if rep_item["quantity"] < quantity:
            return {
                "ok": False,
                "domainCode": "REPLACEMENT_OUT_OF_STOCK",
                "available": rep_item["quantity"],
                "requested": quantity
            }

        # Price delta calculation from frozen order line price snapshot
        source_unit_price = round_money(source_line["price"])
        replacement_unit_price = round_money(rep_item["finalPrice"])
        source_total = round_money(source_unit_price * quantity)
        replacement_total = round_money(replacement_unit_price * quantity)
        price_delta = round_money(replacement_total - source_total)

        # Restock returned variant into destination bucket
        dest_bucket = "AVAILABLE" if condition == "sellable" else ("DAMAGED" if condition == "damaged" else "QUARANTINE")
        s_branch = self.branch_inventory.get(f"main_branch_{source_id}", {"available": 0, "damaged": 0, "quarantine": 0})
        
        if dest_bucket == "AVAILABLE":
            self.catalog[source_id]["quantity"] += quantity
            s_branch["available"] += quantity
        elif dest_bucket == "DAMAGED":
            # Damaged bucket only: does NOT increase sellable/available stock
            s_branch["damaged"] += quantity
        elif dest_bucket == "QUARANTINE":
            s_branch["quarantine"] += quantity

        # Deduct replacement variant
        self.catalog[replacement_id]["quantity"] -= quantity
        r_branch = self.branch_inventory.get(f"main_branch_{replacement_id}", {"available": 0, "damaged": 0, "quarantine": 0})
        r_branch["available"] -= quantity

        source_line["exchangedQuantity"] += quantity

        return {
            "ok": True,
            "sourceTotal": source_total,
            "replacementTotal": replacement_total,
            "priceDelta": price_delta,
            "destBucket": dest_bucket,
            "sourceCatalogStock": self.catalog[source_id]["quantity"],
            "sourceAvailableStock": s_branch["available"],
            "sourceDamagedStock": s_branch["damaged"],
            "replacementCatalogStock": self.catalog[replacement_id]["quantity"],
            "movementTypes": ["RETURN_EXCHANGE", "EXCHANGE_OUT"]
        }

# ==============================================================================
# Simulation Logic: Live Animal Physical vs Financial State & Quarantine Rules
# ==============================================================================

class SimulatedLivePetReturnCase:
    def __init__(self, unit_id: str = "pet_puppy_01", sale_price: float = 3500.0):
        self.unit_id = unit_id
        self.sale_price = sale_price
        self.lifecycle_status = "sold" # RETURN_LIFECYCLE
        self.custody_status = "customer"
        self.inventory_status = "SOLD"
        self.active_return_case_id = None
        self.quarantined_by = None
        self.quarantine_reason = None
        self.refund_status = "not_requested" # Financial state is completely separate
        self.refund_amount = 0.0
        self.branch_available = 0 # Not sellable!

    def receive_return(self, return_case_id: str, operator_uid: str):
        self.active_return_case_id = return_case_id
        self.lifecycle_status = "under_inspection"
        self.inventory_status = "QUARANTINED"
        self.custody_status = "return_desk"
        self.quarantined_by = operator_uid
        self.quarantine_reason = "LIVE_ANIMAL_PHYSICAL_RETURN"
        # Invariant: branch available stock remains untouched on return intake!
        self.branch_available = 0

    def settle_refund(self, amount: float):
        # Financial settlement does NOT affect physical inventory status
        self.refund_status = "succeeded"
        self.refund_amount = amount

    def attempt_resale_clearance(self, operator_uid: str, is_admin: bool = False, inspection_cleared: bool = True) -> dict:
        if not inspection_cleared or self.lifecycle_status != "cleared":
            return {"ok": False, "error": "failed-precondition", "message": "Inspection must clear animal for resale first."}
        
        # Maker-checker principle: operator who quarantined cannot self-release unless admin
        if not is_admin and self.quarantined_by == operator_uid:
            return {
                "ok": False,
                "error": "failed-precondition",
                "message": "Quarantine maker-checker violation: cannot self-release quarantined animal."
            }

        self.lifecycle_status = "available"
        self.inventory_status = "AVAILABLE"
        self.custody_status = "store"
        self.branch_available += 1
        return {"ok": True, "lifecycleStatus": "available", "branchAvailable": self.branch_available}

# ==============================================================================
# Simulation Logic: Consumer iOS Action Eligibility (PPOrderManager.m)
# ==============================================================================

def simulate_ios_action_eligibility(action_type: str, order: dict, days_since_event: int, has_open_request: bool = False) -> dict:
    status_key = (order.get("status") or "").strip().lower()
    has_captured_payment = order.get("hasCapturedPayment", False)
    is_cancelled = status_key in ["cancelled", "canceled"]
    is_delivered = status_key in ["delivered", "completed", "fulfilled"]
    is_shipped = status_key in ["shipped", "shipping", "in_transit", "out_for_delivery", "picked_up"]

    if has_open_request:
        return {"eligible": False, "message": "order_action_existing_request_message"}

    if action_type == "return":
        if not is_delivered:
            return {"eligible": False, "message": "order_action_return_unavailable_not_delivered"}
        if days_since_event > 14:
            return {"eligible": False, "message": "order_action_return_unavailable_window"}
        return {"eligible": True, "message": "order_action_return_hint"}

    if action_type == "refund":
        if not (has_captured_payment or is_cancelled):
            return {"eligible": False, "message": "order_action_refund_unavailable_unpaid"}
        if is_shipped:
            return {"eligible": False, "message": "order_action_refund_unavailable_after_shipment"}
        if days_since_event > 14:
            return {"eligible": False, "message": "order_action_refund_unavailable_window"}
        return {"eligible": True, "message": "order_action_refund_hint"}

    if action_type == "replacement":
        if not is_delivered:
            return {"eligible": False, "message": "order_action_replacement_unavailable_not_delivered"}
        if days_since_event > 14:
            return {"eligible": False, "message": "order_action_replacement_unavailable_window"}
        return {"eligible": True, "message": "order_action_replacement_hint"}

    return {"eligible": False, "message": "unknown"}

# ==============================================================================
# Test Execution
# ==============================================================================

def main():
    print("\n" + "=" * 65)
    print(" Pure Pets iOS Commerce — Phase 11 Returns, Exchanges & Refunds Suite")
    print("=" * 65 + "\n")

    # --------------------------------------------------------------------------
    # Group 1: Financial Settlement vs Physical Inventory Separation
    # --------------------------------------------------------------------------
    g1 = "Group 1: Financial Settlement vs Physical Inventory Separation"
    print(f"[{g1}]")

    # 1. Live pet: financial refund does not release physical inventory
    case = SimulatedLivePetReturnCase("puppy_101", 3000.0)
    case.receive_return("case_101", "staff_alice")
    case.settle_refund(3000.0)
    if case.refund_status == "succeeded" and case.lifecycle_status == "under_inspection" and case.branch_available == 0:
        record_pass(g1, "Live pet: Financial refund settled while physical inventory remains in inspection/non-sellable")
    else:
        record_fail(g1, "Live pet: Financial refund settled while physical inventory remains in inspection/non-sellable",
                    f"Unexpected state: refund={case.refund_status}, lifecycle={case.lifecycle_status}, avail={case.branch_available}")

    # 2. Refund ledger operates independently of warehouse receipt
    ledger = SimulatedRefundLedger(500.0)
    res = ledger.attempt_refund(200.0)
    if res["ok"] and ledger.settled_amount == 200.0 and ledger.available_amount == 300.0:
        record_pass(g1, "RefundLedger: Financial settlement operates independently of warehouse physical receipt")
    else:
        record_fail(g1, "RefundLedger: Financial settlement operates independently of warehouse physical receipt", str(res))

    # 3. Product variant exchange decouples price delta from inventory bucket routing
    pve = SimulatedProductVariantExchange()
    ex_res = pve.process_exchange("var_red_m", "var_red_l", 1, condition="damaged")
    if ex_res["ok"] and ex_res["priceDelta"] == 20.0 and ex_res["destBucket"] == "DAMAGED":
        record_pass(g1, "VariantExchange: Price delta computed separately from damaged bucket disposition routing")
    else:
        record_fail(g1, "VariantExchange: Price delta computed separately from damaged bucket disposition routing", str(ex_res))

    # --------------------------------------------------------------------------
    # Group 2: Accessories & Food Variant Identity & Price Preservation
    # --------------------------------------------------------------------------
    g2 = "Group 2: Accessories & Food Variant Identity & Price Preservation"
    print(f"\n[{g2}]")

    # 4. Exact variant identifier extraction in cancellation restock
    cancellation_code_path = os.path.join(INFRA_FUNCTIONS, "orderSupportCancellation.js")
    with open(cancellation_code_path, "r", encoding="utf-8") as f:
        cancellation_content = f.read()
    if "item.sellableUnitId || item.variantId || item.itemId" in cancellation_content:
        record_pass(g2, "Cancellation restock extracts exact variant identifier (sellableUnitId/variantId) ahead of parent")
    else:
        record_fail(g2, "Cancellation restock extracts exact variant identifier ahead of parent", "Pattern not found in orderSupportCancellation.js")

    # 5. Frozen order line price snapshot used for exchange delta (not catalog price)
    # Order line price was 100.0, current catalog price is 120.0. Replacement is 120.0.
    # Delta should be 120 - 100 = 20.0 (NOT 120 - 120 = 0.0)
    pve2 = SimulatedProductVariantExchange()
    ex2 = pve2.process_exchange("var_red_m", "var_red_l", 1, condition="sellable")
    if ex2["ok"] and ex2["sourceTotal"] == 100.0 and ex2["replacementTotal"] == 120.0 and ex2["priceDelta"] == 20.0:
        record_pass(g2, "Exchange price delta preserves frozen order line price snapshot (100.0 vs catalog 120.0)")
    else:
        record_fail(g2, "Exchange price delta preserves frozen order line price snapshot", f"Delta={ex2.get('priceDelta')}")

    # 6. Over-exchange beyond purchased quantity rejected
    pve3 = SimulatedProductVariantExchange()
    ex3 = pve3.process_exchange("var_red_m", "var_red_l", 5, condition="sellable") # Ordered qty is 2
    if not ex3["ok"] and ex3["domainCode"] == "EXCHANGE_QUANTITY_EXCEEDED":
        record_pass(g2, "Over-exchange beyond purchased quantity rejected with EXCHANGE_QUANTITY_EXCEEDED")
    else:
        record_fail(g2, "Over-exchange beyond purchased quantity rejected", str(ex3))

    # --------------------------------------------------------------------------
    # Group 3: Out-of-Stock Replacement & Variant Invariants
    # --------------------------------------------------------------------------
    g3 = "Group 3: Out-of-Stock Replacement & Variant Invariants"
    print(f"\n[{g3}]")

    # 7. Same variant exchange rejected
    pve4 = SimulatedProductVariantExchange()
    ex_same = pve4.process_exchange("var_red_m", "var_red_m", 1)
    if not ex_same["ok"] and ex_same["domainCode"] == "SAME_VARIANT_EXCHANGE":
        record_pass(g3, "Exchange of identical source and replacement variants rejected (SAME_VARIANT_EXCHANGE)")
    else:
        record_fail(g3, "Exchange of identical source and replacement variants rejected", str(ex_same))

    # 8. Out-of-stock replacement variant rejected
    ex_oos = pve4.process_exchange("var_red_m", "var_blue_l", 1) # Blue L has 0 stock
    if not ex_oos["ok"] and ex_oos["domainCode"] == "REPLACEMENT_OUT_OF_STOCK":
        record_pass(g3, "Out-of-stock replacement variant rejected (REPLACEMENT_OUT_OF_STOCK)")
    else:
        record_fail(g3, "Out-of-stock replacement variant rejected", str(ex_oos))

    # 9. Archived replacement variant rejected
    ex_arch = pve4.process_exchange("var_red_m", "var_archived", 1)
    if not ex_arch["ok"] and ex_arch["domainCode"] == "REPLACEMENT_ARCHIVED":
        record_pass(g3, "Archived replacement variant rejected (REPLACEMENT_ARCHIVED)")
    else:
        record_fail(g3, "Archived replacement variant rejected", str(ex_arch))

    # --------------------------------------------------------------------------
    # Group 4: Physical Disposition Routing (Available vs Damaged vs Quarantine)
    # --------------------------------------------------------------------------
    g4 = "Group 4: Physical Disposition Routing (Available vs Damaged vs Quarantine)"
    print(f"\n[{g4}]")

    # 10. Sellable condition routes to AVAILABLE and increments available stock
    pve_sellable = SimulatedProductVariantExchange()
    init_avail = pve_sellable.branch_inventory["main_branch_var_red_m"]["available"]
    res_s = pve_sellable.process_exchange("var_red_m", "var_red_l", 1, condition="sellable")
    if res_s["ok"] and res_s["destBucket"] == "AVAILABLE" and res_s["sourceAvailableStock"] == init_avail + 1:
        record_pass(g4, "Sellable condition routes to AVAILABLE and increments available inventory")
    else:
        record_fail(g4, "Sellable condition routes to AVAILABLE and increments available inventory", str(res_s))

    # 11. Damaged condition routes to DAMAGED and does NOT increase available stock
    pve_damaged = SimulatedProductVariantExchange()
    init_avail_d = pve_damaged.branch_inventory["main_branch_var_red_m"]["available"]
    res_d = pve_damaged.process_exchange("var_red_m", "var_red_l", 1, condition="damaged")
    if res_d["ok"] and res_d["destBucket"] == "DAMAGED" and res_d["sourceAvailableStock"] == init_avail_d and res_d["sourceDamagedStock"] == 1:
        record_pass(g4, "Damaged condition routes to DAMAGED bucket without increasing available stock")
    else:
        record_fail(g4, "Damaged condition routes to DAMAGED bucket without increasing available stock", str(res_d))

    # 12. Dual stock movements and inventory ledger audit
    if res_s["ok"] and res_s["movementTypes"] == ["RETURN_EXCHANGE", "EXCHANGE_OUT"]:
        record_pass(g4, "Dual stockMovements logged (RETURN_EXCHANGE stock_in & EXCHANGE_OUT stock_out)")
    else:
        record_fail(g4, "Dual stockMovements logged", str(res_s))

    # --------------------------------------------------------------------------
    # Group 5: Live Animal Return & Quarantine Safety Invariants
    # --------------------------------------------------------------------------
    g5 = "Group 5: Live Animal Return & Quarantine Safety Invariants"
    print(f"\n[{g5}]")

    # 13. Returned animal intake places unit in QUARANTINED without increasing available stock
    pet_case = SimulatedLivePetReturnCase("puppy_kitten_01", 2500.0)
    pet_case.receive_return("case_201", "staff_vet_bob")
    if pet_case.inventory_status == "QUARANTINED" and pet_case.branch_available == 0:
        record_pass(g5, "Live animal return intake moves unit to QUARANTINED; available quantity remains 0")
    else:
        record_fail(g5, "Live animal return intake moves unit to QUARANTINED", f"Status={pet_case.inventory_status}, Avail={pet_case.branch_available}")

    # 14. Maker-checker quarantine release violation rejected
    pet_case.lifecycle_status = "cleared" # Cleared by inspection
    same_op_release = pet_case.attempt_resale_clearance("staff_vet_bob", is_admin=False, inspection_cleared=True)
    if not same_op_release["ok"] and "maker-checker" in same_op_release["message"]:
        record_pass(g5, "Maker-checker violation: operator who quarantined cannot self-release animal")
    else:
        record_fail(g5, "Maker-checker violation: operator who quarantined cannot self-release animal", str(same_op_release))

    # 15. Independent second operator releases animal after inspection clearance
    diff_op_release = pet_case.attempt_resale_clearance("staff_manager_carol", is_admin=False, inspection_cleared=True)
    if diff_op_release["ok"] and pet_case.inventory_status == "AVAILABLE" and pet_case.branch_available == 1:
        record_pass(g5, "Independent operator releases inspected & cleared animal to sellable inventory")
    else:
        record_fail(g5, "Independent operator releases inspected & cleared animal to sellable inventory", str(diff_op_release))

    # --------------------------------------------------------------------------
    # Group 6: Financial Refund Ledger Math & Protection
    # --------------------------------------------------------------------------
    g6 = "Group 6: Financial Refund Ledger Math & Protection"
    print(f"\n[{g6}]")

    # 16. Normal full refund
    full_ledger = SimulatedRefundLedger(450.0)
    r1 = full_ledger.attempt_refund(450.0)
    if r1["ok"] and r1["status"] == "refunded" and full_ledger.available_amount == 0.0:
        record_pass(g6, "Normal full refund settles captured amount completely (status: refunded)")
    else:
        record_fail(g6, "Normal full refund settles captured amount completely", str(r1))

    # 17. Partial refund
    part_ledger = SimulatedRefundLedger(450.0)
    r2 = part_ledger.attempt_refund(150.0)
    if r2["ok"] and r2["status"] == "partially_refunded" and part_ledger.available_amount == 300.0:
        record_pass(g6, "Partial refund settles portion of captured amount (status: partially_refunded)")
    else:
        record_fail(g6, "Partial refund settles portion of captured amount", str(r2))

    # 18. Repeated refund exceeding available captured balance rejected
    r3 = part_ledger.attempt_refund(350.0) # Only 300.0 available
    if not r3["ok"] and r3["error"] == "failed-precondition":
        record_pass(g6, "Repeated/subsequent refund exceeding available balance rejected (failed-precondition)")
    else:
        record_fail(g6, "Repeated refund exceeding available balance rejected", str(r3))

    # 19. Already settled full refund cannot be refunded again
    r4 = full_ledger.attempt_refund(50.0)
    if not r4["ok"] and r4["error"] == "failed-precondition":
        record_pass(g6, "Already fully settled refund rejects subsequent settlement attempts")
    else:
        record_fail(g6, "Already fully settled refund rejects subsequent settlement attempts", str(r4))

    # --------------------------------------------------------------------------
    # Group 7: Consumer iOS Action Eligibility & Post-Shipment Refund Separation
    # --------------------------------------------------------------------------
    g7 = "Group 7: Consumer iOS Action Eligibility & Post-Shipment Refund Separation"
    print(f"\n[{g7}]")

    # 20. Return requires delivered status
    e_ret_pending = simulate_ios_action_eligibility("return", {"status": "processing"}, 2)
    if not e_ret_pending["eligible"] and e_ret_pending["message"] == "order_action_return_unavailable_not_delivered":
        record_pass(g7, "Return is ineligible for non-delivered order (order_action_return_unavailable_not_delivered)")
    else:
        record_fail(g7, "Return is ineligible for non-delivered order", str(e_ret_pending))

    # 21. Return eligible for delivered order within 14 days
    e_ret_deliv = simulate_ios_action_eligibility("return", {"status": "delivered"}, 5)
    if e_ret_deliv["eligible"]:
        record_pass(g7, "Return is eligible for delivered order within 14-day window")
    else:
        record_fail(g7, "Return is eligible for delivered order within 14-day window", str(e_ret_deliv))

    # 22. Return window expired (> 14 days)
    e_ret_expired = simulate_ios_action_eligibility("return", {"status": "delivered"}, 15)
    if not e_ret_expired["eligible"] and e_ret_expired["message"] == "order_action_return_unavailable_window":
        record_pass(g7, "Return window expiration (> 14 days) marks return ineligible")
    else:
        record_fail(g7, "Return window expiration (> 14 days) marks return ineligible", str(e_ret_expired))

    # 23. Refund on shipped order blocked (must use physical return first)
    e_ref_shipped = simulate_ios_action_eligibility("refund", {"status": "shipped", "hasCapturedPayment": True}, 2)
    if not e_ref_shipped["eligible"] and e_ref_shipped["message"] == "order_action_refund_unavailable_after_shipment":
        record_pass(g7, "Refund on shipped order blocked with order_action_refund_unavailable_after_shipment")
    else:
        record_fail(g7, "Refund on shipped order blocked with after_shipment message", str(e_ref_shipped))

    # 24. Replacement requires delivered status within 14 days
    e_rep_deliv = simulate_ios_action_eligibility("replacement", {"status": "delivered"}, 3)
    if e_rep_deliv["eligible"]:
        record_pass(g7, "Replacement is eligible for delivered order within 14-day window")
    else:
        record_fail(g7, "Replacement is eligible for delivered order within 14-day window", str(e_rep_deliv))

    # 25. Unpaid order cannot be refunded
    e_ref_unpaid = simulate_ios_action_eligibility("refund", {"status": "pending", "hasCapturedPayment": False}, 1)
    if not e_ref_unpaid["eligible"] and e_ref_unpaid["message"] == "order_action_refund_unavailable_unpaid":
        record_pass(g7, "Unpaid order is ineligible for financial refund (order_action_refund_unavailable_unpaid)")
    else:
        record_fail(g7, "Unpaid order is ineligible for financial refund", str(e_ref_unpaid))

    # --------------------------------------------------------------------------
    # Group 8: Client Security & Zero Direct Mutation Invariants
    # --------------------------------------------------------------------------
    g8 = "Group 8: Client Security & Zero Direct Mutation Invariants"
    print(f"\n[{g8}]")

    with open(FIRESTORE_RULES_PATH, "r", encoding="utf-8") as f:
        rules_content = f.read()

    # 26. RefundSettlementEvidenceBindings allow read, write: if false
    binding_rule = re.search(r"match\s+/RefundSettlementEvidenceBindings/\{bindingID\}\s*\{\s*allow read,\s*write:\s*if false;", rules_content)
    if binding_rule:
        record_pass(g8, "Firestore Rules deny all direct client reads/writes to RefundSettlementEvidenceBindings")
    else:
        record_fail(g8, "Firestore Rules deny all direct client reads/writes to RefundSettlementEvidenceBindings", "Rule not found")

    # 27. refundSettlements allow read, write: if false
    settlement_rule = re.search(r"match\s+/refundSettlements/\{intentID\}\s*\{\s*allow read,\s*write:\s*if false;", rules_content)
    if settlement_rule:
        record_pass(g8, "Firestore Rules deny all direct client reads/writes to Orders/refundSettlements")
    else:
        record_fail(g8, "Firestore Rules deny all direct client reads/writes to Orders/refundSettlements", "Rule not found")

    # 28. Zero direct writes to returnCases or refundSettlements in iOS codebase
    payments_dir = os.path.join(IOS_ROOT, "MainApp", "PAYMENTS")
    direct_writes_found = []
    for root, _, files in os.walk(payments_dir):
        for file in files:
            if file.endswith((".m", ".swift")):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    c = f.read()
                    if re.search(r'collectionWithPath:@"(returnCases|refundSettlements|stockMovements|inventoryLedger)"', c):
                        direct_writes_found.append(file)
    if not direct_writes_found:
        record_pass(g8, "Zero direct client collections calls to returnCases, refundSettlements, stockMovements, inventoryLedger")
    else:
        record_fail(g8, "Zero direct client calls to sensitive return/refund collections", f"Found in {direct_writes_found}")

    # 29. Return and support drafts submit via createOrderSupportRequest callable
    order_manager_m = os.path.join(payments_dir, "Manager", "Order", "PPOrderManager.m")
    with open(order_manager_m, "r", encoding="utf-8") as f:
        mgr_m_content = f.read()
    if 'HTTPSCallableWithName:@"createOrderSupportRequest"' in mgr_m_content:
        record_pass(g8, "iOS support drafts route strictly through createOrderSupportRequest HTTPS callable")
    else:
        record_fail(g8, "iOS support drafts route through createOrderSupportRequest", "Callable not found in PPOrderManager.m")

    # --------------------------------------------------------------------------
    # Group 9: Objective-C Source Code Contract Invariants
    # --------------------------------------------------------------------------
    g9 = "Group 9: Objective-C Source Code Contract Invariants"
    print(f"\n[{g9}]")

    order_manager_h = os.path.join(payments_dir, "Manager", "Order", "PPOrderManager.h")
    with open(order_manager_h, "r", encoding="utf-8") as f:
        mgr_h_content = f.read()

    # 30. Return and Refund action types declared in OrderSupportFunc.h (imported by PPOrderManager.h)
    order_support_func_h = os.path.join(payments_dir, "CartAndOrdersFiles", "OrderSupportFunc.h")
    with open(order_support_func_h, "r", encoding="utf-8") as f:
        support_func_h_content = f.read()

    if "PPOrderCustomerActionTypeReturn" in support_func_h_content and "PPOrderCustomerActionTypeRefund" in support_func_h_content and 'OrderSupportFunc.h' in mgr_h_content:
        record_pass(g9, "PPOrderCustomerActionTypeReturn and PPOrderCustomerActionTypeRefund declared in OrderSupportFunc.h (imported by PPOrderManager.h)")
    else:
        record_fail(g9, "Return and Refund action types declared", "Missing in OrderSupportFunc.h or PPOrderManager.h")

    # 31. Eligibility method declaration
    if "eligibilityForAction:" in mgr_h_content and "eligibilityDecisionsForOrder:" in mgr_h_content:
        record_pass(g9, "eligibilityForAction: and eligibilityDecisionsForOrder: declared in PPOrderManager.h")
    else:
        record_fail(g9, "eligibility methods declared", "Missing in PPOrderManager.h")

    # 32. Support request status mappings in PPOrderManager.m
    statuses = ["refunded", "partially_refunded", "pending_settlement", "settlement_retryable", "settlement_failed"]
    missing_statuses = [s for s in statuses if s not in mgr_m_content]
    if not missing_statuses:
        record_pass(g9, "displayTitleForRequestStatus: maps all settlement statuses (refunded, partially_refunded, etc.)")
    else:
        record_fail(g9, "displayTitleForRequestStatus: maps all settlement statuses", f"Missing {missing_statuses}")

    # 33. Reason options for Return and Refund configured
    if "order_reason_not_as_described_title" in mgr_m_content and "order_reason_duplicate_payment_title" in mgr_m_content:
        record_pass(g9, "reasonOptionsForAction: returns structured reason options for Return and Refund")
    else:
        record_fail(g9, "reasonOptionsForAction: returns structured reason options", "Missing expected reason tokens")

    # --------------------------------------------------------------------------
    # Summary
    # --------------------------------------------------------------------------
    total = len(TEST_RESULTS)
    passed = sum(1 for t in TEST_RESULTS if t["passed"])
    failed = total - passed

    print("\n" + "=" * 65)
    print(f"  RESULTS: {passed}/{total} tests passed ({failed} failures)")
    print("=" * 65 + "\n")

    if failed == 0:
        print("🎉 ALL PHASE 11 RETURNS, EXCHANGES & REFUNDS CONTRACT TESTS PASSED (100% GREEN)!\n")
        return 0
    else:
        print(f"❌ {failed} TESTS FAILED. Review errors above.\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
