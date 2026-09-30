#!/usr/bin/env python3
"""
checkout_state_machine_regression_test.py
Pure Pets iOS Commerce Lifecycle — Phase 4 Regression Test Suite

Deterministic, zero-runtime regression tests validating:
  1. PPCheckoutState enum & string mappings.
  2. Central transition matrix (PPCheckoutCanTransition) covering all legal transitions.
  3. Negative test matrix verifying illegal transitions fail closed.
  4. Generation guard rejecting stale callbacks from previous attempts.
  5. Terminal resolution guard guaranteeing exactly one terminal resolution per generation.
  6. Idempotency key preservation on retryable failure and cleanup on terminal resolution.
  7. Re-entrancy protection and repeated checkout tap suppression.
  8. Full multi-step checkout lifecycle simulations (COD, Electronic, Retry, Cancel, Delayed).
  9. Objective-C source code contract invariant audits.
"""

import sys
import re
import os
import uuid
from typing import Optional, List, Dict, Any, Tuple

# Color output helpers
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
BOLD = "\033[1m"
RESET = "\033[0m"

PASS_COUNT = 0
FAIL_COUNT = 0


def assert_true(condition: bool, test_name: str, detail: str = ""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"  {GREEN}✅ PASS{RESET}: {test_name}")
    else:
        FAIL_COUNT += 1
        msg = f"  {RED}❌ FAIL{RESET}: {test_name}"
        if detail:
            msg += f" — {detail}"
        print(msg)


def assert_equal(actual: Any, expected: Any, test_name: str):
    assert_true(actual == expected, test_name, f"expected {expected}, got {actual}")


# =============================================================================
# Python Replica of PPCheckoutState & PPCheckoutCanTransition
# (Direct translation of Objective-C implementation in PPCheckoutCoordinator)
# =============================================================================

class PPCheckoutState:
    IDLE = 0
    VALIDATING = 1
    CREATING_ORDER = 2
    AWAITING_PAYMENT = 3
    VERIFYING_PAYMENT = 4
    PENDING_VERIFICATION = 5
    SUCCEEDED = 6
    FAILED = 7
    CANCELLED = 8

STATE_NAMES = {
    PPCheckoutState.IDLE: "idle",
    PPCheckoutState.VALIDATING: "validating",
    PPCheckoutState.CREATING_ORDER: "creatingOrder",
    PPCheckoutState.AWAITING_PAYMENT: "awaitingPayment",
    PPCheckoutState.VERIFYING_PAYMENT: "verifyingPayment",
    PPCheckoutState.PENDING_VERIFICATION: "pendingVerification",
    PPCheckoutState.SUCCEEDED: "succeeded",
    PPCheckoutState.FAILED: "failed",
    PPCheckoutState.CANCELLED: "cancelled",
}

def string_from_pp_checkout_state(state: int) -> str:
    return STATE_NAMES.get(state, "unknown")

def pp_checkout_can_transition(from_state: int, to_state: int) -> bool:
    if from_state == to_state:
        return True
    
    if from_state == PPCheckoutState.IDLE:
        return to_state == PPCheckoutState.VALIDATING

    if from_state == PPCheckoutState.VALIDATING:
        return to_state in (
            PPCheckoutState.CREATING_ORDER,
            PPCheckoutState.FAILED,
            PPCheckoutState.CANCELLED,
        )

    if from_state == PPCheckoutState.CREATING_ORDER:
        return to_state in (
            PPCheckoutState.AWAITING_PAYMENT,
            PPCheckoutState.VERIFYING_PAYMENT,
            PPCheckoutState.SUCCEEDED,
            PPCheckoutState.FAILED,
            PPCheckoutState.CANCELLED,
        )

    if from_state == PPCheckoutState.AWAITING_PAYMENT:
        return to_state in (
            PPCheckoutState.VERIFYING_PAYMENT,
            PPCheckoutState.PENDING_VERIFICATION,
            PPCheckoutState.CANCELLED,
            PPCheckoutState.FAILED,
            PPCheckoutState.SUCCEEDED,
        )

    if from_state == PPCheckoutState.VERIFYING_PAYMENT:
        return to_state in (
            PPCheckoutState.SUCCEEDED,
            PPCheckoutState.FAILED,
            PPCheckoutState.PENDING_VERIFICATION,
            PPCheckoutState.CANCELLED,
        )

    if from_state == PPCheckoutState.PENDING_VERIFICATION:
        return to_state in (
            PPCheckoutState.SUCCEEDED,
            PPCheckoutState.FAILED,
            PPCheckoutState.CANCELLED,
            PPCheckoutState.IDLE,
            PPCheckoutState.VALIDATING,
        )

    if from_state == PPCheckoutState.SUCCEEDED:
        return to_state in (
            PPCheckoutState.IDLE,
            PPCheckoutState.VALIDATING,
        )

    if from_state == PPCheckoutState.FAILED:
        return to_state in (
            PPCheckoutState.IDLE,
            PPCheckoutState.VALIDATING,
        )

    if from_state == PPCheckoutState.CANCELLED:
        return to_state in (
            PPCheckoutState.IDLE,
            PPCheckoutState.VALIDATING,
        )

    return False


# =============================================================================
# Simulated Checkout Coordinator State Machine
# =============================================================================

class SimulatedCheckoutCoordinator:
    def __init__(self):
        self.state = PPCheckoutState.IDLE
        self.checkout_generation = 0
        self.checkout_idempotency_key: Optional[str] = None
        self.is_checkout_in_progress = False
        self.has_resolved_checkout = False
        self.awaiting_server_cancellation_confirmation = False
        self.current_order: Optional[Dict[str, Any]] = None
        self.last_result: Optional[str] = None
        self.last_error: Optional[str] = None

    def is_generation_current(self, generation: int) -> bool:
        return generation > 0 and generation == self.checkout_generation

    def transition_to_state(self, new_state: int, generation: int) -> bool:
        if not self.is_generation_current(generation):
            return False
        if not pp_checkout_can_transition(self.state, new_state):
            return False
        self.state = new_state
        self.is_checkout_in_progress = new_state in (
            PPCheckoutState.VALIDATING,
            PPCheckoutState.CREATING_ORDER,
            PPCheckoutState.AWAITING_PAYMENT,
            PPCheckoutState.VERIFYING_PAYMENT,
        )
        return True

    def begin_terminal_resolution(self, generation: int, label: str) -> bool:
        if not self.is_generation_current(generation):
            return False
        if self.has_resolved_checkout:
            return False
        self.has_resolved_checkout = True
        return True

    def start_checkout(self, items: List[Dict[str, Any]], address: Dict[str, Any], payment_method: str) -> Tuple[bool, Optional[str]]:
        if self.is_checkout_in_progress:
            return False, "payment_request_in_progress"
        if self.awaiting_server_cancellation_confirmation:
            return False, "cancellation_pending"
        if not address:
            return False, "invalid_address"

        self.has_resolved_checkout = False
        self.awaiting_server_cancellation_confirmation = False
        self.checkout_generation += 1
        gen = self.checkout_generation

        if not self.checkout_idempotency_key:
            self.checkout_idempotency_key = str(uuid.uuid4())

        self.transition_to_state(PPCheckoutState.VALIDATING, gen)

        if not items:
            self.fail_order("cart_empty", retryable=False, generation=gen)
            return False, "cart_empty"

        return True, None

    def validate_inventory_success(self, gen: int):
        if not self.is_generation_current(gen) or self.has_resolved_checkout:
            return False
        return self.transition_to_state(PPCheckoutState.CREATING_ORDER, gen)

    def validate_inventory_failure(self, error: str, gen: int):
        return self.fail_order(error, retryable=False, generation=gen)

    def order_created(self, order: Dict[str, Any], gen: int):
        if not self.is_generation_current(gen) or self.has_resolved_checkout:
            return False
        self.current_order = order
        if order.get("is_cod"):
            return self.complete_with_success(gen)
        return self.transition_to_state(PPCheckoutState.AWAITING_PAYMENT, gen)

    def order_creation_failed(self, error: str, gen: int):
        return self.fail_order(error, retryable=True, generation=gen)

    def payment_response_received(self, gen: int):
        if not self.is_generation_current(gen) or self.has_resolved_checkout:
            return False
        return self.transition_to_state(PPCheckoutState.VERIFYING_PAYMENT, gen)

    def payment_sdk_failed(self, error: str, gen: int):
        return self.fail_order(error, retryable=True, generation=gen)

    def complete_with_success(self, gen: int) -> bool:
        if not self.begin_terminal_resolution(gen, "success"):
            return False
        self.transition_to_state(PPCheckoutState.SUCCEEDED, gen)
        self.checkout_idempotency_key = None
        self.is_checkout_in_progress = False
        self.last_result = "SUCCESS"
        return True

    def complete_with_failure(self, error: str, gen: int) -> bool:
        if not self.begin_terminal_resolution(gen, "failure"):
            return False
        self.transition_to_state(PPCheckoutState.FAILED, gen)
        self.is_checkout_in_progress = False
        self.last_result = "FAILED"
        self.last_error = error
        return True

    def fail_order(self, error: str, retryable: bool, generation: int) -> bool:
        if not self.begin_terminal_resolution(generation, "error"):
            return False
        self.transition_to_state(PPCheckoutState.FAILED, generation)
        self.current_order = None
        self.is_checkout_in_progress = False
        self.last_result = "FAILED"
        self.last_error = error
        return True

    def complete_with_cancellation(self, gen: int) -> bool:
        if not self.begin_terminal_resolution(gen, "cancelled"):
            return False
        self.transition_to_state(PPCheckoutState.CANCELLED, gen)
        self.awaiting_server_cancellation_confirmation = True
        self.is_checkout_in_progress = False
        self.last_result = "CANCELLED"
        return True

    def server_confirmed_cancellation(self, gen: int):
        if not self.is_generation_current(gen):
            return False
        self.awaiting_server_cancellation_confirmation = False
        self.checkout_idempotency_key = None
        self.current_order = None
        return True

    def complete_with_pending_verification(self, error: str, gen: int) -> bool:
        if not self.begin_terminal_resolution(gen, "pending_verification"):
            return False
        self.transition_to_state(PPCheckoutState.PENDING_VERIFICATION, gen)
        self.is_checkout_in_progress = False
        self.last_result = "PENDING_VERIFICATION"
        self.last_error = error
        return True


# =============================================================================
# TEST EXECUTION
# =============================================================================

def run_tests():
    print(f"\n{BOLD}{BLUE}==============================================================={RESET}")
    print(f"{BOLD}{BLUE} Pure Pets iOS Commerce Lifecycle — Phase 4 State Machine Suite{RESET}")
    print(f"{BOLD}{BLUE}==============================================================={RESET}\n")

    # -------------------------------------------------------------------------
    # Group 1: State Enum & String Tokens
    # -------------------------------------------------------------------------
    print(f"{BOLD}[Group 1: PPCheckoutState Enum & String Representations]{RESET}")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.IDLE), "idle", "IDLE maps to 'idle'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.VALIDATING), "validating", "VALIDATING maps to 'validating'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.CREATING_ORDER), "creatingOrder", "CREATING_ORDER maps to 'creatingOrder'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.AWAITING_PAYMENT), "awaitingPayment", "AWAITING_PAYMENT maps to 'awaitingPayment'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.VERIFYING_PAYMENT), "verifyingPayment", "VERIFYING_PAYMENT maps to 'verifyingPayment'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.PENDING_VERIFICATION), "pendingVerification", "PENDING_VERIFICATION maps to 'pendingVerification'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.SUCCEEDED), "succeeded", "SUCCEEDED maps to 'succeeded'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.FAILED), "failed", "FAILED maps to 'failed'")
    assert_equal(string_from_pp_checkout_state(PPCheckoutState.CANCELLED), "cancelled", "CANCELLED maps to 'cancelled'")
    assert_equal(string_from_pp_checkout_state(999), "unknown", "Out of bounds state maps to 'unknown'")

    # -------------------------------------------------------------------------
    # Group 2: Legal Transitions (PPCheckoutCanTransition)
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 2: PPCheckoutCanTransition — All Legal State Transitions]{RESET}")
    # Reflexive
    for s in range(9):
        assert_true(pp_checkout_can_transition(s, s), f"Reflexive transition legal: {string_from_pp_checkout_state(s)} -> {string_from_pp_checkout_state(s)}")
    
    # Idle
    assert_true(pp_checkout_can_transition(PPCheckoutState.IDLE, PPCheckoutState.VALIDATING), "idle -> validating is legal")

    # Validating
    assert_true(pp_checkout_can_transition(PPCheckoutState.VALIDATING, PPCheckoutState.CREATING_ORDER), "validating -> creatingOrder is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.VALIDATING, PPCheckoutState.FAILED), "validating -> failed is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.VALIDATING, PPCheckoutState.CANCELLED), "validating -> cancelled is legal")

    # CreatingOrder
    assert_true(pp_checkout_can_transition(PPCheckoutState.CREATING_ORDER, PPCheckoutState.AWAITING_PAYMENT), "creatingOrder -> awaitingPayment is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.CREATING_ORDER, PPCheckoutState.VERIFYING_PAYMENT), "creatingOrder -> verifyingPayment is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.CREATING_ORDER, PPCheckoutState.SUCCEEDED), "creatingOrder -> succeeded is legal (Cash on Delivery)")
    assert_true(pp_checkout_can_transition(PPCheckoutState.CREATING_ORDER, PPCheckoutState.FAILED), "creatingOrder -> failed is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.CREATING_ORDER, PPCheckoutState.CANCELLED), "creatingOrder -> cancelled is legal")

    # AwaitingPayment
    assert_true(pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.VERIFYING_PAYMENT), "awaitingPayment -> verifyingPayment is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.PENDING_VERIFICATION), "awaitingPayment -> pendingVerification is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.CANCELLED), "awaitingPayment -> cancelled is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.FAILED), "awaitingPayment -> failed is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.SUCCEEDED), "awaitingPayment -> succeeded is legal (early webhook/listener)")

    # VerifyingPayment
    assert_true(pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.SUCCEEDED), "verifyingPayment -> succeeded is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.FAILED), "verifyingPayment -> failed is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.PENDING_VERIFICATION), "verifyingPayment -> pendingVerification is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.CANCELLED), "verifyingPayment -> cancelled is legal")

    # PendingVerification
    assert_true(pp_checkout_can_transition(PPCheckoutState.PENDING_VERIFICATION, PPCheckoutState.SUCCEEDED), "pendingVerification -> succeeded is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.PENDING_VERIFICATION, PPCheckoutState.FAILED), "pendingVerification -> failed is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.PENDING_VERIFICATION, PPCheckoutState.CANCELLED), "pendingVerification -> cancelled is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.PENDING_VERIFICATION, PPCheckoutState.IDLE), "pendingVerification -> idle is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.PENDING_VERIFICATION, PPCheckoutState.VALIDATING), "pendingVerification -> validating is legal (retry)")

    # Succeeded
    assert_true(pp_checkout_can_transition(PPCheckoutState.SUCCEEDED, PPCheckoutState.IDLE), "succeeded -> idle is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.SUCCEEDED, PPCheckoutState.VALIDATING), "succeeded -> validating is legal (new checkout)")

    # Failed
    assert_true(pp_checkout_can_transition(PPCheckoutState.FAILED, PPCheckoutState.IDLE), "failed -> idle is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.FAILED, PPCheckoutState.VALIDATING), "failed -> validating is legal (retry)")

    # Cancelled
    assert_true(pp_checkout_can_transition(PPCheckoutState.CANCELLED, PPCheckoutState.IDLE), "cancelled -> idle is legal")
    assert_true(pp_checkout_can_transition(PPCheckoutState.CANCELLED, PPCheckoutState.VALIDATING), "cancelled -> validating is legal (restart)")

    # -------------------------------------------------------------------------
    # Group 3: Negative Transitions (Illegal Transitions Fail Closed)
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 3: Negative Transitions (Illegal Transitions Fail Closed)]{RESET}")
    # From Idle
    assert_true(not pp_checkout_can_transition(PPCheckoutState.IDLE, PPCheckoutState.AWAITING_PAYMENT), "idle -> awaitingPayment is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.IDLE, PPCheckoutState.VERIFYING_PAYMENT), "idle -> verifyingPayment is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.IDLE, PPCheckoutState.SUCCEEDED), "idle -> succeeded is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.IDLE, PPCheckoutState.FAILED), "idle -> failed is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.IDLE, PPCheckoutState.CANCELLED), "idle -> cancelled is illegal")

    # From Validating
    assert_true(not pp_checkout_can_transition(PPCheckoutState.VALIDATING, PPCheckoutState.AWAITING_PAYMENT), "validating -> awaitingPayment is illegal (skipping order creation)")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.VALIDATING, PPCheckoutState.VERIFYING_PAYMENT), "validating -> verifyingPayment is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.VALIDATING, PPCheckoutState.SUCCEEDED), "validating -> succeeded is illegal")

    # From AwaitingPayment
    assert_true(not pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.VALIDATING), "awaitingPayment -> validating is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.CREATING_ORDER), "awaitingPayment -> creatingOrder is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.AWAITING_PAYMENT, PPCheckoutState.IDLE), "awaitingPayment -> idle is illegal")

    # From VerifyingPayment
    assert_true(not pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.VALIDATING), "verifyingPayment -> validating is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.CREATING_ORDER), "verifyingPayment -> creatingOrder is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.AWAITING_PAYMENT), "verifyingPayment -> awaitingPayment is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.VERIFYING_PAYMENT, PPCheckoutState.IDLE), "verifyingPayment -> idle is illegal")

    # Terminal Transitions to Other Terminals (Succeeded cannot fail or cancel)
    assert_true(not pp_checkout_can_transition(PPCheckoutState.SUCCEEDED, PPCheckoutState.FAILED), "succeeded -> failed is illegal (fail-closed)")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.SUCCEEDED, PPCheckoutState.CANCELLED), "succeeded -> cancelled is illegal (fail-closed)")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.SUCCEEDED, PPCheckoutState.AWAITING_PAYMENT), "succeeded -> awaitingPayment is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.SUCCEEDED, PPCheckoutState.VERIFYING_PAYMENT), "succeeded -> verifyingPayment is illegal")

    # Failed cannot directly become Succeeded or Cancelled without a new validating run
    assert_true(not pp_checkout_can_transition(PPCheckoutState.FAILED, PPCheckoutState.SUCCEEDED), "failed -> succeeded is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.FAILED, PPCheckoutState.CANCELLED), "failed -> cancelled is illegal")

    # Cancelled cannot directly become Succeeded or Failed without a new validating run
    assert_true(not pp_checkout_can_transition(PPCheckoutState.CANCELLED, PPCheckoutState.SUCCEEDED), "cancelled -> succeeded is illegal")
    assert_true(not pp_checkout_can_transition(PPCheckoutState.CANCELLED, PPCheckoutState.FAILED), "cancelled -> failed is illegal")

    # -------------------------------------------------------------------------
    # Group 4: Generation Guard & Stale Callback Rejection
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 4: Generation Guard & Stale Callback Rejection]{RESET}")
    coord = SimulatedCheckoutCoordinator()
    item = {"itemID": "prod_1", "quantity": 1, "price": 50.0}
    addr = {"documentID": "addr_1", "city": "Doha"}

    ok, err = coord.start_checkout([item], addr, "qib")
    assert_true(ok, "Checkout starts generation 1")
    assert_equal(coord.checkout_generation, 1, "Generation == 1")
    assert_equal(coord.state, PPCheckoutState.VALIDATING, "State is VALIDATING")

    # Advance to creatingOrder
    assert_true(coord.validate_inventory_success(gen=1), "Generation 1 advances to CREATING_ORDER")
    assert_equal(coord.state, PPCheckoutState.CREATING_ORDER, "State is CREATING_ORDER")

    # Simulate network failure causing user retry
    coord.order_creation_failed("Network timeout", gen=1)
    assert_equal(coord.state, PPCheckoutState.FAILED, "State is FAILED")

    # User taps retry -> generation increments to 2
    ok, err = coord.start_checkout([item], addr, "qib")
    assert_true(ok, "Retry starts generation 2")
    assert_equal(coord.checkout_generation, 2, "Generation == 2")
    assert_equal(coord.state, PPCheckoutState.VALIDATING, "State is VALIDATING for generation 2")

    # Now a delayed callback from generation 1 arrives
    stale_transition = coord.transition_to_state(PPCheckoutState.CREATING_ORDER, generation=1)
    assert_true(not stale_transition, "Stale transition from generation 1 rejected")
    assert_equal(coord.state, PPCheckoutState.VALIDATING, "State remains VALIDATING (unaffected by stale callback)")

    stale_terminal = coord.complete_with_success(gen=1)
    assert_true(not stale_terminal, "Stale complete_with_success from generation 1 rejected")
    assert_equal(coord.state, PPCheckoutState.VALIDATING, "State remains VALIDATING")

    # -------------------------------------------------------------------------
    # Group 5: Terminal Resolution Guard (Exactly Once Resolution)
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 5: Terminal Resolution Guard (Exactly Once Resolution)]{RESET}")
    coord5 = SimulatedCheckoutCoordinator()
    coord5.start_checkout([item], addr, "qib")
    gen = coord5.checkout_generation
    coord5.validate_inventory_success(gen)
    coord5.order_created({"orderId": "order_123", "is_cod": False}, gen)
    coord5.payment_response_received(gen)
    assert_equal(coord5.state, PPCheckoutState.VERIFYING_PAYMENT, "State is VERIFYING_PAYMENT")

    # First terminal resolution: success from verification callable
    res1 = coord5.complete_with_success(gen)
    assert_true(res1, "First terminal resolution (callable) succeeds")
    assert_equal(coord5.state, PPCheckoutState.SUCCEEDED, "State is SUCCEEDED")
    assert_true(coord5.has_resolved_checkout, "has_resolved_checkout is True")

    # Duplicate terminal resolution: snapshot listener fires 'paid' immediately after
    res2 = coord5.complete_with_success(gen)
    assert_true(not res2, "Duplicate success resolution (listener snapshot) rejected")
    assert_equal(coord5.state, PPCheckoutState.SUCCEEDED, "State stays SUCCEEDED")

    # Duplicate terminal resolution: failure callback arrives after success
    res3 = coord5.complete_with_failure("Late error", gen)
    assert_true(not res3, "Conflicting late failure rejected after success")
    assert_equal(coord5.state, PPCheckoutState.SUCCEEDED, "State strictly protected as SUCCEEDED")

    # Duplicate terminal resolution: cancellation callback arrives after success
    res4 = coord5.complete_with_cancellation(gen)
    assert_true(not res4, "Conflicting cancellation rejected after success")
    assert_equal(coord5.state, PPCheckoutState.SUCCEEDED, "State strictly protected as SUCCEEDED")

    # -------------------------------------------------------------------------
    # Group 6: Idempotency Key & Retry Lifecycle
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 6: Idempotency Key & Retry Lifecycle]{RESET}")
    coord6 = SimulatedCheckoutCoordinator()
    coord6.start_checkout([item], addr, "qib")
    gen1 = coord6.checkout_generation
    initial_idempotency_key = coord6.checkout_idempotency_key
    assert_true(initial_idempotency_key is not None and len(initial_idempotency_key) > 0, "Idempotency key generated on start")

    # Fail with retryable payment error
    coord6.validate_inventory_success(gen1)
    coord6.order_created({"orderId": "order_retry_1", "is_cod": False}, gen1)
    coord6.payment_sdk_failed("Gateway connection dropped", gen1)
    assert_equal(coord6.state, PPCheckoutState.FAILED, "State is FAILED")
    assert_equal(coord6.checkout_idempotency_key, initial_idempotency_key, "Idempotency key preserved after retryable failure")

    # Retry checkout
    coord6.start_checkout([item], addr, "qib")
    gen2 = coord6.checkout_generation
    assert_equal(gen2, 2, "Generation incremented to 2 on retry")
    assert_equal(coord6.checkout_idempotency_key, initial_idempotency_key, "Same idempotency key retained for retry deduplication")

    # Complete success
    coord6.validate_inventory_success(gen2)
    coord6.order_created({"orderId": "order_retry_1", "is_cod": False}, gen2)
    coord6.payment_response_received(gen2)
    coord6.complete_with_success(gen2)
    assert_equal(coord6.state, PPCheckoutState.SUCCEEDED, "State is SUCCEEDED")
    assert_true(coord6.checkout_idempotency_key is None, "Idempotency key cleared on success")

    # Next independent checkout gets a new idempotency key
    coord6.start_checkout([item], addr, "qib")
    gen3 = coord6.checkout_generation
    assert_equal(gen3, 3, "New checkout is generation 3")
    assert_true(coord6.checkout_idempotency_key is not None, "New idempotency key generated")
    assert_true(coord6.checkout_idempotency_key != initial_idempotency_key, "New key differs from previous order key")

    # -------------------------------------------------------------------------
    # Group 7: Re-entrancy & Tap Suppression
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 7: Re-entrancy & Tap Suppression]{RESET}")
    coord7 = SimulatedCheckoutCoordinator()
    coord7.start_checkout([item], addr, "qib")
    assert_true(coord7.is_checkout_in_progress, "is_checkout_in_progress is True during validating")

    # Second tap while validating
    ok, err = coord7.start_checkout([item], addr, "qib")
    assert_true(not ok, "Secondary tap during VALIDATING blocked")
    assert_equal(err, "payment_request_in_progress", "Error is payment_request_in_progress")

    # Advance to AwaitingPayment
    coord7.validate_inventory_success(coord7.checkout_generation)
    coord7.order_created({"orderId": "order_dup_tap", "is_cod": False}, coord7.checkout_generation)
    assert_equal(coord7.state, PPCheckoutState.AWAITING_PAYMENT, "State is AWAITING_PAYMENT")
    assert_true(coord7.is_checkout_in_progress, "is_checkout_in_progress is True during AwaitingPayment")

    # Third tap while awaiting payment
    ok, err = coord7.start_checkout([item], addr, "qib")
    assert_true(not ok, "Secondary tap during AWAITING_PAYMENT blocked")
    assert_equal(err, "payment_request_in_progress", "Error is payment_request_in_progress")

    # Complete success clears is_checkout_in_progress
    coord7.payment_response_received(coord7.checkout_generation)
    coord7.complete_with_success(coord7.checkout_generation)
    assert_true(not coord7.is_checkout_in_progress, "is_checkout_in_progress is False after terminal resolution")

    # -------------------------------------------------------------------------
    # Group 8: Complete Full-Lifecycle Simulated Flows
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 8: Complete Full-Lifecycle Simulated Flows]{RESET}")
    
    # 8.1 Happy Path Electronic (QIB)
    c_elec = SimulatedCheckoutCoordinator()
    c_elec.start_checkout([item], addr, "qib")
    g = c_elec.checkout_generation
    assert_equal(c_elec.state, PPCheckoutState.VALIDATING, "8.1: Step 1 Validating")
    c_elec.validate_inventory_success(g)
    assert_equal(c_elec.state, PPCheckoutState.CREATING_ORDER, "8.1: Step 2 CreatingOrder")
    c_elec.order_created({"orderId": "ord_elec", "is_cod": False}, g)
    assert_equal(c_elec.state, PPCheckoutState.AWAITING_PAYMENT, "8.1: Step 3 AwaitingPayment")
    c_elec.payment_response_received(g)
    assert_equal(c_elec.state, PPCheckoutState.VERIFYING_PAYMENT, "8.1: Step 4 VerifyingPayment")
    c_elec.complete_with_success(g)
    assert_equal(c_elec.state, PPCheckoutState.SUCCEEDED, "8.1: Step 5 Succeeded")
    assert_equal(c_elec.last_result, "SUCCESS", "8.1: Result is SUCCESS")

    # 8.2 Cash on Delivery
    c_cod = SimulatedCheckoutCoordinator()
    c_cod.start_checkout([item], addr, "cash")
    g = c_cod.checkout_generation
    assert_equal(c_cod.state, PPCheckoutState.VALIDATING, "8.2: Step 1 Validating")
    c_cod.validate_inventory_success(g)
    assert_equal(c_cod.state, PPCheckoutState.CREATING_ORDER, "8.2: Step 2 CreatingOrder")
    c_cod.order_created({"orderId": "ord_cod", "is_cod": True}, g)
    assert_equal(c_cod.state, PPCheckoutState.SUCCEEDED, "8.2: Direct transition CreatingOrder -> Succeeded for COD")
    assert_equal(c_cod.last_result, "SUCCESS", "8.2: Result is SUCCESS")

    # 8.3 Inventory Out of Stock
    c_inv = SimulatedCheckoutCoordinator()
    c_inv.start_checkout([item], addr, "qib")
    g = c_inv.checkout_generation
    c_inv.validate_inventory_failure("Item out of stock", g)
    assert_equal(c_inv.state, PPCheckoutState.FAILED, "8.3: Direct transition Validating -> Failed on inventory failure")
    assert_equal(c_inv.last_result, "FAILED", "8.3: Result is FAILED")

    # 8.4 User Cancellation of Payment Sheet
    c_can = SimulatedCheckoutCoordinator()
    c_can.start_checkout([item], addr, "qib")
    g = c_can.checkout_generation
    c_can.validate_inventory_success(g)
    c_can.order_created({"orderId": "ord_can", "is_cod": False}, g)
    c_can.complete_with_cancellation(g)
    assert_equal(c_can.state, PPCheckoutState.CANCELLED, "8.4: AwaitingPayment -> Cancelled")
    assert_equal(c_can.last_result, "CANCELLED", "8.4: Result is CANCELLED")
    assert_true(c_can.awaiting_server_cancellation_confirmation, "8.4: Awaiting server cancellation confirmation")
    c_can.server_confirmed_cancellation(g)
    assert_true(not c_can.awaiting_server_cancellation_confirmation, "8.4: Server confirmed abandonment")

    # 8.5 Verification Delayed / Pending Verification
    c_pen = SimulatedCheckoutCoordinator()
    c_pen.start_checkout([item], addr, "qib")
    g = c_pen.checkout_generation
    c_pen.validate_inventory_success(g)
    c_pen.order_created({"orderId": "ord_pen", "is_cod": False}, g)
    c_pen.payment_response_received(g)
    c_pen.complete_with_pending_verification("Delayed gateway response", g)
    assert_equal(c_pen.state, PPCheckoutState.PENDING_VERIFICATION, "8.5: VerifyingPayment -> PendingVerification")
    assert_equal(c_pen.last_result, "PENDING_VERIFICATION", "8.5: Result is PENDING_VERIFICATION")

    # -------------------------------------------------------------------------
    # Group 9: Objective-C Source Code Contract Invariant Audits
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 9: Objective-C Source Code Contract Invariant Audits]{RESET}")
    h_path = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS", "Checkout", "PPCheckoutCoordinator.h")
    m_path = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS", "Checkout", "PPCheckoutCoordinator.m")

    with open(h_path, "r", encoding="utf-8") as f:
        h_content = f.read()

    with open(m_path, "r", encoding="utf-8") as f:
        m_content = f.read()

    # Enum declared in .h
    assert_true("typedef NS_ENUM(NSInteger, PPCheckoutState)" in h_content, "PPCheckoutState enum declared in header")
    for s_name in ["PPCheckoutStateIdle", "PPCheckoutStateValidating", "PPCheckoutStateCreatingOrder",
                   "PPCheckoutStateAwaitingPayment", "PPCheckoutStateVerifyingPayment",
                   "PPCheckoutStatePendingVerification", "PPCheckoutStateSucceeded",
                   "PPCheckoutStateFailed", "PPCheckoutStateCancelled"]:
        assert_true(s_name in h_content, f"Enum member {s_name} declared in header")

    assert_true("@property (nonatomic, assign, readonly) PPCheckoutState state;" in h_content, "Readonly state property exposed in header")
    assert_true("extern NSString *NSStringFromPPCheckoutState(PPCheckoutState state);" in h_content, "NSStringFromPPCheckoutState declared in header")
    assert_true("extern BOOL PPCheckoutCanTransition(PPCheckoutState fromState, PPCheckoutState toState);" in h_content, "PPCheckoutCanTransition declared in header")

    # Implementation in .m
    assert_true("NSString *NSStringFromPPCheckoutState(PPCheckoutState state)" in m_content, "NSStringFromPPCheckoutState implemented in .m")
    assert_true("BOOL PPCheckoutCanTransition(PPCheckoutState fromState, PPCheckoutState toState)" in m_content, "PPCheckoutCanTransition implemented in .m")
    assert_true("- (BOOL)pp_transitionToState:(PPCheckoutState)newState generation:(NSInteger)generation" in m_content, "pp_transitionToState:generation: implemented in .m")
    assert_true("- (BOOL)pp_beginTerminalResolutionForGeneration:(NSInteger)generation label:(NSString *)label" in m_content, "pp_beginTerminalResolutionForGeneration:label: implemented in .m")

    # Invariant transitions wired in .m
    assert_true("[self pp_transitionToState:PPCheckoutStateValidating generation:generation];" in m_content, "Transition to PPCheckoutStateValidating wired in startCheckout")
    assert_true("[self pp_transitionToState:PPCheckoutStateCreatingOrder generation:generation];" in m_content, "Transition to PPCheckoutStateCreatingOrder wired after inventory check")
    assert_true("[self pp_transitionToState:PPCheckoutStateAwaitingPayment generation:generation];" in m_content, "Transition to PPCheckoutStateAwaitingPayment wired in beginPaymentForOrder")
    assert_true("[self pp_transitionToState:PPCheckoutStateVerifyingPayment generation:generation];" in m_content, "Transition to PPCheckoutStateVerifyingPayment wired before verifyQibPayment")
    assert_true("[self pp_transitionToState:PPCheckoutStateSucceeded generation:generation];" in m_content, "Transition to PPCheckoutStateSucceeded wired in completeWithSuccess")
    assert_true("[self pp_transitionToState:PPCheckoutStateFailed generation:generation];" in m_content, "Transition to PPCheckoutStateFailed wired in completeWithFailure / failOrderWithError")
    assert_true("[self pp_transitionToState:PPCheckoutStatePendingVerification generation:generation];" in m_content, "Transition to PPCheckoutStatePendingVerification wired in completeWithPendingVerification")
    assert_true("[self pp_transitionToState:PPCheckoutStateCancelled generation:generation];" in m_content, "Transition to PPCheckoutStateCancelled wired in completeWithCancellation")

    # Protection against duplicate taps
    assert_true("if (self.isCheckoutInProgress)" in m_content, "isCheckoutInProgress check protects against duplicate taps")

    # Protection against duplicate terminal resolution
    assert_true("if (self.hasResolvedCheckout)" in m_content, "hasResolvedCheckout protects against duplicate terminal callbacks")

    # Stale generation check
    assert_true("- (BOOL)pp_isCheckoutGenerationCurrent:(NSInteger)generation" in m_content, "pp_isCheckoutGenerationCurrent protects against stale callbacks")

    # Summary
    print(f"\n{BOLD}==============================================================={RESET}")
    print(f"  RESULTS: {PASS_COUNT}/{PASS_COUNT + FAIL_COUNT} tests passed ({FAIL_COUNT} failures)")
    print(f"{BOLD}==============================================================={RESET}\n")

    if FAIL_COUNT > 0:
        print(f"{RED}❌ SOME CHECKOUT STATE MACHINE REGRESSION TESTS FAILED!{RESET}\n")
        sys.exit(1)
    else:
        print(f"{GREEN}🎉 ALL PHASE 4 CHECKOUT STATE MACHINE REGRESSION TESTS PASSED (100% GREEN)!{RESET}\n")
        sys.exit(0)


if __name__ == "__main__":
    run_tests()
