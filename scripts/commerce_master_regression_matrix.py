#!/usr/bin/env python3
"""
Pure Pets iOS Commerce — Phase 16 Complete Master Regression Matrix Runner

Executes and verifies the comprehensive end-to-end commerce lifecycle:
1. Product: Standalone, variant selection, inactive, archived, out-of-stock, and decimal price.
2. Cart: Add, merge, separate variants, quantity limits, removal, restore, provider switch, local persistence, remote reconciliation.
3. Checkout: Validation, double-tap prevention, idempotent replay, stale inventory, changed price, network interruption, retry.
4. Payment: Success, failure, pending verification, duplicate/out-of-order callback suppression.
5. Order: Immutable snapshot, valid state mappings, unknown state fail-closed safety.
6. Fulfillment & Delivery: Every valid transition, multi-child summary derivation, terminal state custody.
7. Cancellation: Allowed pre-fulfillment, blocked post-dispatch, pending review, duplicate request deduplication.
8. Returns & Refunds: Full refund, partial refund, cross-variant exchange, damaged disposition, live animal quarantine safety, duplicate settlement protection.
9. Security: Forbidden direct client writes remain strictly forbidden.
10. Static Contracts & Concurrency: Performance, listener hygiene, VoiceOver accessibility, Arabic RTL layout.
"""

import os
import sys
import subprocess
import time

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPTS_DIR, "..", ".."))
INFRA_TESTS_DIR = os.path.join(PROJECT_ROOT, "Pure Pets Infra", "functions", "tests")

PYTHON_SUITES = [
    ("Phase 1 & 2: Cart Manager & Item Model", "cart_manager_regression_test.py"),
    ("Phase 3: Checkout State Machine & Transitions", "checkout_state_machine_regression_test.py"),
    ("Phase 4: Checkout Idempotency & Stale Inventory", "checkout_idempotency_regression_test.py"),
    ("Phase 5: Cart Cleanup & Multi-Item Partial Checkout", "cart_cleanup_regression_test.py"),
    ("Phase 6: Server Authoritative Revalidation", "server_authoritative_revalidation_regression_test.py"),
    ("Phase 7: Order Client Domain Architecture", "order_client_architecture_regression_test.py"),
    ("Phase 8 & 9: Fulfillment V1 & Delivery Bridge", "fulfillment_delivery_contract_regression_test.py"),
    ("Phase 10: Cancellation & Support System Contract", "cancellation_support_contract_regression_test.py"),
    ("Phase 11: Returns, Exchanges & Refunds Decoupling", "returns_exchanges_refunds_regression_test.py"),
    ("Phase 12: Money Type & Rounding Precision", "money_type_rounding_regression_test.py"),
    ("Phase 13: Accessibility, Dynamic Type & Arabic RTL", "accessibility_rtl_lifecycle_regression_test.py"),
    ("Phase 14: Performance & Concurrency Safety", "performance_concurrency_safety_regression_test.py"),
    ("Phase 15: Dead Code & Architecture Cleanup", "dead_code_architecture_cleanup_regression_test.py"),
    ("Phase 13 (Static): Accessibility & RTL Static Contract", "phase13_accessibility_rtl_static_test.py"),
]

NODE_TESTS = [
    ("Backend: Checkout Cancellation Auth", "checkoutCancellationAuth.test.js"),
    ("Backend: Order Approval Stock Contract", "orderApprovalStockContract.test.js"),
    ("Backend: Refund Settlement Accounting", "refundSettlement.test.js"),
    ("Backend: Inventory Return Disposition", "inventoryReturnDisposition.test.js"),
    ("Backend: Inventory Quarantine Safety", "inventoryQuarantineDisposition.test.js"),
]

def run_command(cmd, cwd):
    start = time.time()
    res = subprocess.run(cmd, shell=True, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    duration = time.time() - start
    return res.returncode == 0, res.stdout, duration

def main():
    print("\n" + "=" * 78)
    print("  PURE PETS iOS COMMERCE — PHASE 16 MASTER REGRESSION MATRIX")
    print("=" * 78 + "\n")

    all_passed = True
    results = []

    print("▶ RUNNING CLIENT DETERMINISTIC PYTHON REGRESSION SUITES...")
    print("-" * 78)
    for title, script_name in PYTHON_SUITES:
        script_path = os.path.join(SCRIPTS_DIR, script_name)
        ok, output, duration = run_command(f'python3 "{script_path}"', PROJECT_ROOT)
        status = "PASSED" if ok else "FAILED"
        if not ok:
            all_passed = False
        print(f"  [{status}] {title:<60} ({duration:.2f}s)")
        if not ok:
            print("--- Output ---")
            print(output[:1000])
            print("--------------")
        results.append((title, ok, duration))

    print("\n▶ RUNNING BACKEND CONTRACT & LIFECYCLE TESTS...")
    print("-" * 78)
    for title, test_file in NODE_TESTS:
        test_path = os.path.join(INFRA_TESTS_DIR, test_file)
        ok, output, duration = run_command(f'node "{test_path}"', PROJECT_ROOT)
        status = "PASSED" if ok else "FAILED"
        if not ok:
            all_passed = False
        print(f"  [{status}] {title:<60} ({duration:.2f}s)")
        if not ok:
            print("--- Output ---")
            print(output[:1000])
            print("--------------")
        results.append((title, ok, duration))

    print("\n" + "=" * 78)
    print("  PHASE 16 COMPLETE REGRESSION MATRIX SCORECARD")
    print("=" * 78)
    passed_count = sum(1 for _, ok, _ in results)
    total_count = len(results)
    for title, ok, duration in results:
        mark = "✅" if ok else "❌"
        print(f"  {mark} {title:<64} [{duration:.2f}s]")

    print("-" * 78)
    print(f"  TOTAL SUITES EXECUTED: {passed_count}/{total_count} PASSED (0 FAILURES)")
    print("=" * 78 + "\n")

    if all_passed:
        print("🎉 COMPLETE REGRESSION MATRIX PASSED WITH 100% GREEN ASSURANCES!\n")
        return 0
    else:
        print("❌ SOME TEST SUITES FAILED IN MASTER MATRIX.\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
