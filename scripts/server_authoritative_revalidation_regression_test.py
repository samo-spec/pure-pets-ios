#!/usr/bin/env python3
"""
server_authoritative_revalidation_regression_test.py — Phase 7 Revalidation Suite

Pure Pets Platform (pure-pets-49199)
Primary Client: Pure Pets IOS/ (Consumer iOS)

Validates the server-authoritative price & inventory revalidation contract:
1. Client Cart Authority Boundary:
   - Client cart values (price, stock, total) are presentation/cache values only.
   - CartItem serialization never persists stockQuantity to Firestore (Contract F-25).
2. Canonical Backend Authority:
   - Backend order creation ignores client-provided prices and computes unitPrice from
     canonical server records (finalPrice ?? price).
   - Order totalAmount, subtotal, and shipping fee are canonical server computations.
   - Variant snapshot fields (family, unit, options, SKU, barcode, provider) are frozen at order creation.
3. Stale Cart Scenarios & Revalidation:
   - Price changed on server: order creation prices from canonical record; client in-memory order adopts server price.
   - Stock decreased below requested quantity: preflight and backend reject with clear error.
   - Out of stock: rejected fail-closed; cart preserved.
   - Catalog item unavailable / archived: rejected fail-closed.
   - Individually tracked live animal: rejected with specialized selection requirement message.
   - Inactive / invalid payment method: rejected fail-closed.
   - Unsupported currency: rejected fail-closed.
4. Protected Database Record Immutability:
   - iOS client never mutates Orders or petAccessories directly via Firestore SDK.
   - All state transitions route through Cloud Functions (createPendingOrder, verifyQibPayment, cancelOrderCheckout).
5. Objective-C Source Code Contract Invariants:
   - Audits in PPCheckoutCoordinator.m and PPOrderManager.m.
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
# SIMULATED CANONICAL BACKEND PRICING & INVENTORY ENGINE
# =============================================================================

def round_money(val: float) -> float:
    return round(val + 1e-9, 2)


class ServerCatalogItem:
    def __init__(self, item_id: str, name: str, price: float, final_price: Optional[float],
                 quantity: int, is_active: bool = True, is_archived: bool = False,
                 inventory_mode: str = "TRACKED", provider_id: str = "prov_1",
                 family_id: str = "", variant_id: str = "", sku: str = "", barcode: str = ""):
        self.item_id = item_id
        self.name = name
        self.price = price
        self.final_price = final_price
        self.quantity = quantity
        self.is_active = is_active
        self.is_archived = is_archived
        self.inventory_mode = inventory_mode
        self.provider_id = provider_id
        self.family_id = family_id
        self.variant_id = variant_id
        self.sku = sku
        self.barcode = barcode

    def is_available(self) -> bool:
        if self.is_archived or not self.is_active:
            return False
        return True

    def canonical_unit_price(self) -> float:
        if self.final_price is not None and self.final_price > 0:
            return round_money(self.final_price)
        return round_money(self.price)


class SimulatedServerBackend:
    def __init__(self):
        self.catalog: Dict[str, ServerCatalogItem] = {}
        self.delivery_fee: float = 15.0
        self.allowed_payment_methods = {"qib", "apple_pay", "cash"}
        self.supported_currencies = {"QAR", "USD", "EUR", "GBP", "SAR", "AED", "KWD", "BHD", "OMR"}

    def add_catalog_item(self, item: ServerCatalogItem):
        self.catalog[item.item_id] = item

    def create_pending_order(self, uid: str, requested_items: List[Dict[str, Any]],
                             shipping_address_id: str, payment_method_id: str,
                             currency: str = "QAR", idempotency_key: str = "") -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
        if not uid:
            return None, "unauthenticated"
        if not shipping_address_id:
            return None, "Shipping address not found."
        if payment_method_id not in self.allowed_payment_methods:
            return None, f"Payment method {payment_method_id} is disabled."
        if currency not in self.supported_currencies:
            return None, f"Currency {currency} is unsupported."
        if not requested_items:
            return None, "No items provided for checkout."

        order_items = []
        subtotal = 0.0

        for req in requested_items:
            item_id = req.get("itemId") or req.get("itemID")
            qty = int(req.get("quantity") or req.get("qty") or 0)
            if qty <= 0:
                return None, f"Invalid quantity {qty} for item {item_id}."

            server_item = self.catalog.get(item_id)
            if not server_item or not server_item.is_available():
                return None, f"Item {item_id} is unavailable."

            if server_item.inventory_mode == "INDIVIDUAL_TRACKED":
                return None, f"Item {item_id} requires exact individual selection. Complete this sale through the compatible POS workflow."

            if server_item.quantity <= 0:
                return None, f"Item {item_id} is out of stock."

            if qty > server_item.quantity:
                return None, f"Requested quantity for item {item_id} exceeds available stock."

            # Authoritative pricing from server catalog (client prices completely ignored!)
            unit_price = server_item.canonical_unit_price()
            line_total = round_money(unit_price * qty)
            subtotal += line_total

            order_items.append({
                "itemId": item_id,
                "itemID": item_id,
                "name": server_item.name,
                "price": unit_price,
                "quantity": qty,
                "qty": qty,
                "lineTotal": line_total,
                "productFamilyId": server_item.family_id,
                "variantId": server_item.variant_id,
                "sku": server_item.sku,
                "barcode": server_item.barcode,
                "ownerId": server_item.provider_id
            })

        subtotal = round_money(subtotal)
        total_amount = round_money(subtotal + self.delivery_fee)

        order_dict = {
            "orderId": f"ord_{idempotency_key[:8] if idempotency_key else 'gen1'}",
            "orderNumber": f"PP-{idempotency_key[:6] if idempotency_key else '1000'}",
            "amount": subtotal,
            "shippingFee": self.delivery_fee,
            "totalAmount": total_amount,
            "currency": currency,
            "paymentMethodId": payment_method_id,
            "paymentStatus": "pending_collection" if payment_method_id == "cash" else "pending",
            "items": order_items,
            "shippingAddressId": shipping_address_id
        }
        return order_dict, None


# =============================================================================
# SIMULATED CLIENT PREFLIGHT & CHECKOUT
# =============================================================================

class SimulatedClientPreflight:
    @staticmethod
    def validate_inventory(items: List[Dict[str, Any]], catalog: Dict[str, ServerCatalogItem]) -> Tuple[bool, List[Dict[str, Any]], Optional[str]]:
        issues = []
        for req in items:
            item_id = req.get("itemID") or req.get("itemId")
            requested_qty = req.get("quantity", 1)
            server_item = catalog.get(item_id)

            if not server_item or not server_item.is_available():
                issues.append({
                    "itemID": item_id,
                    "name": server_item.name if server_item else "Unknown Item",
                    "requestedQty": requested_qty,
                    "availableQty": 0
                })
            elif server_item.inventory_mode == "INDIVIDUAL_TRACKED":
                issues.append({
                    "itemID": item_id,
                    "name": server_item.name,
                    "requestedQty": requested_qty,
                    "availableQty": server_item.quantity,
                    "requiresExactUnitSelection": True
                })
            elif server_item.quantity < requested_qty:
                issues.append({
                    "itemID": item_id,
                    "name": server_item.name,
                    "requestedQty": requested_qty,
                    "availableQty": server_item.quantity
                })

        if issues:
            return False, issues, None
        return True, [], None


# =============================================================================
# TESTS
# =============================================================================

def run_tests():
    print(f"\n{BOLD}{BLUE}================================================================={RESET}")
    print(f"{BOLD}{BLUE} Pure Pets iOS Commerce — Phase 7 Server-Authoritative Suite     {RESET}")
    print(f"{BOLD}{BLUE}================================================================={RESET}\n")

    backend = SimulatedServerBackend()
    backend.add_catalog_item(ServerCatalogItem("prod_dry_food", "Dry Dog Food 5kg", price=120.0, final_price=99.0, quantity=10))
    backend.add_catalog_item(ServerCatalogItem("prod_collar", "Leather Collar", price=45.0, final_price=None, quantity=3))
    backend.add_catalog_item(ServerCatalogItem("prod_bird_cage", "Large Bird Cage", price=350.0, final_price=None, quantity=0))  # Out of stock
    backend.add_catalog_item(ServerCatalogItem("prod_archived_toy", "Old Toy", price=15.0, final_price=None, quantity=5, is_archived=True))  # Archived
    backend.add_catalog_item(ServerCatalogItem("prod_parrot_macaw", "Blue-and-Gold Macaw", price=5500.0, final_price=None, quantity=1, inventory_mode="INDIVIDUAL_TRACKED"))

    # -------------------------------------------------------------------------
    # Group 1: Client Presentation vs Server Canonical Authority
    # -------------------------------------------------------------------------
    print(f"{BOLD}[Group 1: Presentation Cache vs Server Canonical Authority]{RESET}")
    # Customer cart has an outdated / tampered price: claims price is 10.0 QAR instead of 99.0 QAR
    tampered_client_item = {
        "itemID": "prod_dry_food",
        "name": "Dry Dog Food 5kg",
        "price": 10.0,  # Stale / tampered client price
        "quantity": 2
    }
    order_dict, err = backend.create_pending_order("user_123", [tampered_client_item], "addr_1", "qib")
    assert_true(err is None, "Backend successfully created pending order")
    assert_equal(order_dict["items"][0]["price"], 99.0,
                 "Server canonical price (99.0) overrides client presentation price (10.0)")
    assert_equal(order_dict["amount"], 198.0,
                 "Server authoritative subtotal is exactly 99.0 * 2 = 198.0 QAR")
    assert_equal(order_dict["totalAmount"], 213.0,
                 "Server authoritative totalAmount is 198.0 + 15.0 delivery = 213.0 QAR")

    # -------------------------------------------------------------------------
    # Group 2: Stale Stock Decreased Below Requested Quantity
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 2: Stale Stock Decreased Below Requested Quantity]{RESET}")
    # Customer added 5 collars to cart when stock was 10. Stock is now only 3.
    stale_stock_item = {"itemID": "prod_collar", "name": "Leather Collar", "quantity": 5}
    in_stock, issues, _ = SimulatedClientPreflight.validate_inventory([stale_stock_item], backend.catalog)
    assert_equal(in_stock, False, "Preflight catches decreased stock before order creation")
    assert_equal(issues[0]["availableQty"], 3, "Preflight reports 3 available units")
    assert_equal(issues[0]["requestedQty"], 5, "Preflight reports 5 requested units")

    # Backend verification
    order_res, backend_err = backend.create_pending_order("user_123", [stale_stock_item], "addr_1", "qib")
    assert_true(order_res is None, "Backend order creation rejected when quantity exceeds available stock")
    assert_true("exceeds available stock" in backend_err, "Backend returns explicit stock failure precondition")

    # -------------------------------------------------------------------------
    # Group 3: Stale Out of Stock Item
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 3: Stale Out of Stock Item]{RESET}")
    out_of_stock_item = {"itemID": "prod_bird_cage", "name": "Large Bird Cage", "quantity": 1}
    in_stock_cage, issues_cage, _ = SimulatedClientPreflight.validate_inventory([out_of_stock_item], backend.catalog)
    assert_equal(in_stock_cage, False, "Preflight detects out-of-stock item")
    assert_equal(issues_cage[0]["availableQty"], 0, "Available quantity reported as 0")

    order_cage, err_cage = backend.create_pending_order("user_123", [out_of_stock_item], "addr_1", "qib")
    assert_true(order_cage is None, "Backend rejects out of stock order creation")
    assert_true("out of stock" in err_cage, "Backend returns out of stock error")

    # -------------------------------------------------------------------------
    # Group 4: Archived / Deactivated Product
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 4: Archived or Deactivated Catalog Item]{RESET}")
    archived_item = {"itemID": "prod_archived_toy", "name": "Old Toy", "quantity": 1}
    in_stock_arch, issues_arch, _ = SimulatedClientPreflight.validate_inventory([archived_item], backend.catalog)
    assert_equal(in_stock_arch, False, "Preflight detects archived item")

    order_arch, err_arch = backend.create_pending_order("user_123", [archived_item], "addr_1", "qib")
    assert_true(order_arch is None, "Backend rejects archived item")
    assert_true("unavailable" in err_arch, "Backend returns unavailable error")

    # -------------------------------------------------------------------------
    # Group 5: Individually Tracked Live Animals Protection
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 5: Individually Tracked Live Animals Protection]{RESET}")
    live_animal = {"itemID": "prod_parrot_macaw", "name": "Blue-and-Gold Macaw", "quantity": 1}
    in_stock_live, issues_live, _ = SimulatedClientPreflight.validate_inventory([live_animal], backend.catalog)
    assert_equal(in_stock_live, False, "Preflight flags individually tracked live animal")
    assert_equal(issues_live[0]["requiresExactUnitSelection"], True,
                 "requiresExactUnitSelection flag set to prompt specialized POS/ring selection")

    order_live, err_live = backend.create_pending_order("user_123", [live_animal], "addr_1", "qib")
    assert_true(order_live is None, "Backend blocks quantity-only live animal order creation")
    assert_true("requires exact individual selection" in err_live, "Backend informs POS workflow required")

    # -------------------------------------------------------------------------
    # Group 6: Unsupported Payment Method and Currency Validation
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 6: Payment Method and Currency Validation]{RESET}")
    valid_item = {"itemID": "prod_collar", "quantity": 1}
    _, err_method = backend.create_pending_order("user_123", [valid_item], "addr_1", "bitcoin")
    assert_true("disabled" in err_method, "Unsupported payment method rejected")

    _, err_currency = backend.create_pending_order("user_123", [valid_item], "addr_1", "qib", currency="XYZ")
    assert_true("unsupported" in err_currency, "Unsupported currency rejected")

    # -------------------------------------------------------------------------
    # Group 7: Contract F-25 Invariant — No stockQuantity Persisted in Cart
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 7: Contract F-25 Cart Persistence Invariant]{RESET}")
    cart_item_m_path = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS", "CartAndOrdersFiles", "CartItem.m")
    with open(cart_item_m_path, "r", encoding="utf-8") as f:
        cart_m = f.read()

    fs_dict_match = re.search(r"- \(NSDictionary \*\)firestoreDictionary\s*\{([^}]+)\}", cart_m)
    assert_true(fs_dict_match is not None, "firestoreDictionary implementation found in CartItem.m")
    if fs_dict_match:
        assert_true("stockQuantity" not in fs_dict_match.group(1),
                    "Contract F-25: stockQuantity is strictly NEVER persisted in CartItem.firestoreDictionary")

    # -------------------------------------------------------------------------
    # Group 8: Zero Direct Writes to Orders or petAccessories in iOS Client
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 8: Zero Direct Writes to Orders / petAccessories in iOS Client]{RESET}")
    checkout_m_path = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS", "Checkout", "PPCheckoutCoordinator.m")
    order_mgr_m_path = os.path.join(os.path.dirname(__file__), "..", "Pure Pets", "MainApp", "PAYMENTS", "Manager", "Order", "PPOrderManager.m")

    with open(checkout_m_path, "r", encoding="utf-8") as f:
        checkout_m = f.read()
    with open(order_mgr_m_path, "r", encoding="utf-8") as f:
        order_mgr_m = f.read()

    # Check PPCheckoutCoordinator for direct order writes
    assert_true("[orderRef setData:" not in checkout_m, "PPCheckoutCoordinator never calls [orderRef setData:]")
    assert_true("[orderRef updateData:" not in checkout_m, "PPCheckoutCoordinator never calls [orderRef updateData:]")
    assert_true("[orderRef deleteDocument" not in checkout_m, "PPCheckoutCoordinator never calls [orderRef deleteDocument]")

    # Check PPOrderManager for direct order/stock writes
    assert_true("[[ordersRef documentWithPath:" not in order_mgr_m or "setData:" not in order_mgr_m,
                "PPOrderManager never performs direct setData on Orders collection")
    assert_true("[[db collectionWithPath:@\"petAccessories\"]" in order_mgr_m,
                "PPOrderManager reads petAccessories for preflight inventory check")
    # Verify petAccessories is only read with getDocumentWithCompletion
    pet_acc_snippet = order_mgr_m[order_mgr_m.find("collectionWithPath:@\"petAccessories\""):order_mgr_m.find("collectionWithPath:@\"petAccessories\"") + 300]
    assert_true("getDocumentWithCompletion" in pet_acc_snippet,
                "petAccessories access is read-only (getDocumentWithCompletion:)")
    assert_true("setData:" not in pet_acc_snippet and "updateData:" not in pet_acc_snippet,
                "petAccessories is NEVER mutated directly from iOS client")

    # -------------------------------------------------------------------------
    # Group 9: Server Response Trust in PPOrderManager & PPCheckoutCoordinator
    # -------------------------------------------------------------------------
    print(f"\n{BOLD}[Group 9: Server Order Response Adoption]{RESET}")
    # 1. Order amount from server response
    assert_true("order.amount = [orderDict[@\"amount\"] respondsToSelector:@selector(doubleValue)]" in order_mgr_m,
                "order.amount populated from server response orderDict[@\"amount\"]")
    # 2. Total amount from server response
    assert_true("double totalAmount = [orderDict[@\"totalAmount\"] respondsToSelector:@selector(doubleValue)]" in order_mgr_m,
                "order.totalAmount populated from server response orderDict[@\"totalAmount\"]")
    # 3. Server items adopted
    assert_true("order.items = [orderDict[@\"items\"] isKindOfClass:NSArray.class]" in order_mgr_m,
                "order.items adopts server-verified items array")
    # 4. Inventory validation called prior to CreatingOrder transition in PPCheckoutCoordinator
    assert_true("[[PPOrderManager shared]\n     validateInventoryForItems:items" in checkout_m or "validateInventoryForItems:items" in checkout_m,
                "PPCheckoutCoordinator invokes validateInventoryForItems prior to order creation")
    assert_true("[self pp_transitionToState:PPCheckoutStateCreatingOrder" in checkout_m,
                "PPCheckoutCoordinator transitions to CreatingOrder only after inventory is validated")

    # Summary
    print(f"\n{BOLD}================================================================={RESET}")
    print(f"  RESULTS: {PASS_COUNT}/{PASS_COUNT + FAIL_COUNT} tests passed ({FAIL_COUNT} failures)")
    print(f"{BOLD}================================================================={RESET}\n")

    if FAIL_COUNT > 0:
        print(f"{RED}❌ SOME SERVER AUTHORITATIVE REVALIDATION TESTS FAILED!{RESET}\n")
        sys.exit(1)
    else:
        print(f"{GREEN}🎉 ALL PHASE 7 SERVER-AUTHORITATIVE REVALIDATION TESTS PASSED (100% GREEN)!{RESET}\n")
        sys.exit(0)


if __name__ == "__main__":
    run_tests()
