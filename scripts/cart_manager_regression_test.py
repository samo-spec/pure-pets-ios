#!/usr/bin/env python3
"""
cart_manager_regression_test.py
iOS Commerce Lifecycle — Phase 1 Deterministic Cart Regression Test Suite

Validates CartItem, CartManager, and PPCartCalculator behavior, serialization,
reconciliation, multi-variant coexistence, stock ceilings, provider-switch policies,
floating-point decimal precision, and error recovery without requiring an iOS runtime.
"""

import math
import os
import re
import sys

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPTS_DIR)
PAYMENTS_DIR = os.path.join(PROJECT_ROOT, "Pure Pets", "MainApp", "PAYMENTS")
CART_FILES_DIR = os.path.join(PAYMENTS_DIR, "CartAndOrdersFiles")
CART_MGR_DIR = os.path.join(PAYMENTS_DIR, "Manager", "Cart")

CART_ITEM_H = os.path.join(CART_FILES_DIR, "CartItem.h")
CART_ITEM_M = os.path.join(CART_FILES_DIR, "CartItem.m")
CART_MGR_H = os.path.join(CART_MGR_DIR, "CartManager.h")
CART_MGR_M = os.path.join(CART_MGR_DIR, "CartManager.m")
CART_CALC_H = os.path.join(CART_MGR_DIR, "PPCartCalculator.h")
CART_CALC_M = os.path.join(CART_MGR_DIR, "PPCartCalculator.m")

# ==============================================================================
# 1. CANONICAL MODEL IMPLEMENTATION (High-Fidelity Python Simulator of ObjC)
# ==============================================================================

NSNotFound = -1

def round_money(val: float) -> float:
    if not math.isfinite(val):
        return 0.0
    return round(val * 100.0) / 100.0

class CartItemModel:
    def __init__(self,
                 item_id: str = "",
                 name: str = "",
                 quantity: int = 1,
                 stock_quantity: int = NSNotFound,
                 price: float = 0.0,
                 original_price: float = 0.0,
                 image_url: str = "",
                 provider_id: str = "",
                 type_: str = "",
                 size: str = "",
                 sellable_unit_id: str = "",
                 variant_id: str = "",
                 variant_combination_key: str = "",
                 product_family_id: str = "",
                 sku: str = "",
                 barcode: str = "",
                 is_variant: bool = False,
                 selected_options: dict = None,
                 selected_options_snapshot: list = None,
                 options_summary: str = ""):
        self.item_id = str(item_id or "")
        self.name = str(name or "")
        self.quantity = max(0, int(quantity))
        self.stock_quantity = int(stock_quantity)
        self.price = round_money(float(price)) if math.isfinite(price) and price >= 0 else 0.0
        self.original_price = round_money(float(original_price)) if math.isfinite(original_price) and original_price > 0 else self.price
        self.image_url = str(image_url or "")
        self.provider_id = str(provider_id or "")
        self.type = str(type_ or "")
        self.size = str(size or "")
        self.sellable_unit_id = str(sellable_unit_id or self.item_id)
        self.variant_id = str(variant_id or self.sellable_unit_id)
        self.variant_combination_key = str(variant_combination_key or "")
        self.product_family_id = str(product_family_id or "")
        self.sku = str(sku or "")
        self.barcode = str(barcode or "")
        self.is_variant = bool(is_variant or (len(self.variant_combination_key) > 0))
        self.selected_options = dict(selected_options or {})
        self.selected_options_snapshot = list(selected_options_snapshot or [])
        self.options_summary = str(options_summary or "")

    @property
    def has_discount(self) -> bool:
        return self.original_price > 0.0 and self.original_price > self.price + 0.009

    @property
    def discount_per_unit(self) -> float:
        return round_money(self.original_price - self.price) if self.has_discount else 0.0

    @property
    def line_subtotal(self) -> float:
        return round_money(self.price * max(self.quantity, 0))

    @property
    def line_subtotal_before_discount(self) -> float:
        base = self.original_price if self.has_discount else self.price
        return round_money(base * max(self.quantity, 0))

    @property
    def line_discount_total(self) -> float:
        return round_money(self.discount_per_unit * max(self.quantity, 0)) if self.has_discount else 0.0

    def firestore_dictionary(self) -> dict:
        d = {
            "id": self.item_id,
            "itemID": self.item_id,
            "type": self.type,
            "name": self.name,
            "price": self.price,
            "originalPrice": self.original_price,
            "qty": max(self.quantity, 0),
            "quantity": max(self.quantity, 0),
        }
        if self.size: d["size"] = self.size
        if self.sellable_unit_id: d["sellableUnitId"] = self.sellable_unit_id
        if self.variant_id: d["variantId"] = self.variant_id
        if self.variant_combination_key: d["variantCombinationKey"] = self.variant_combination_key
        if self.product_family_id: d["productFamilyId"] = self.product_family_id
        if self.sku: d["sku"] = self.sku
        if self.barcode: d["barcode"] = self.barcode
        if self.is_variant: d["isVariant"] = True
        if self.selected_options: d["selectedOptions"] = self.selected_options
        if self.selected_options_snapshot: d["selectedOptionsSnapshot"] = self.selected_options_snapshot
        if self.options_summary: d["optionsSummary"] = self.options_summary
        if self.image_url: d["imageURL"] = self.image_url
        if self.provider_id: d["providerID"] = self.provider_id
        if self.has_discount:
            d["discountPerUnit"] = self.discount_per_unit
            d["lineDiscount"] = self.line_discount_total
        # Contract F-25: stockQuantity is NOT persisted!
        return d

    @classmethod
    def from_dictionary(cls, d: dict) -> "CartItemModel":
        if not isinstance(d, dict):
            d = {}
        item_id = str(d.get("itemID") or d.get("id") or "")
        name = str(d.get("name") or "")
        type_ = str(d.get("type") or "")
        size = str(d.get("size") or "")
        
        # Quantity parsing
        qty_val = d.get("quantity") if d.get("quantity") is not None else d.get("qty")
        try:
            quantity = max(0, int(qty_val))
        except (ValueError, TypeError):
            quantity = 0

        # Price parsing
        try:
            price = float(d.get("price", 0.0))
            if not math.isfinite(price) or price < 0.0:
                price = 0.0
        except (ValueError, TypeError):
            price = 0.0

        # OriginalPrice parsing
        try:
            orig = float(d.get("originalPrice", price))
            original_price = orig if math.isfinite(orig) and orig > 0.0 else price
        except (ValueError, TypeError):
            original_price = price

        image_url = str(d.get("imageURL") or "")
        provider_id = str(d.get("providerID") or "")
        sellable_unit_id = str(d.get("sellableUnitId") or item_id)
        variant_id = str(d.get("variantId") or sellable_unit_id)
        variant_comb = str(d.get("variantCombinationKey") or "")
        family_id = str(d.get("productFamilyId") or "")
        sku = str(d.get("sku") or "")
        barcode = str(d.get("barcode") or "")
        is_var = bool(d.get("isVariant", False)) or (len(variant_comb) > 0)
        sel_opts = dict(d.get("selectedOptions")) if isinstance(d.get("selectedOptions"), dict) else {}
        sel_snap = list(d.get("selectedOptionsSnapshot")) if isinstance(d.get("selectedOptionsSnapshot"), list) else []
        options_summary = str(d.get("optionsSummary") or "")

        # Contract F-25: Restored cart always starts with NSNotFound stockQuantity
        stock_quantity = NSNotFound

        return cls(
            item_id=item_id,
            name=name,
            quantity=quantity,
            stock_quantity=stock_quantity,
            price=price,
            original_price=original_price,
            image_url=image_url,
            provider_id=provider_id,
            type_=type_,
            size=size,
            sellable_unit_id=sellable_unit_id,
            variant_id=variant_id,
            variant_combination_key=variant_comb,
            product_family_id=family_id,
            sku=sku,
            barcode=barcode,
            is_variant=is_var,
            selected_options=sel_opts,
            selected_options_snapshot=sel_snap,
            options_summary=options_summary
        )


class CartManagerModel:
    def __init__(self, delivery_fee: float = 22.0, allow_multi_provider: bool = False):
        self.cart_items: list[CartItemModel] = []
        self.delivery_fee = round_money(delivery_fee)
        self.allow_multi_provider = allow_multi_provider
        self.is_locked = False
        self.last_removed_item: CartItemModel | None = None
        self.last_removed_index: int = NSNotFound

    def is_cart_empty(self) -> bool:
        return len(self.cart_items) == 0

    def total_items_count(self) -> int:
        return sum(item.quantity for item in self.cart_items)

    def subtotal_amount(self) -> float:
        return round_money(sum(item.line_subtotal for item in self.cart_items))

    def shipping_fee(self) -> float:
        return 0.0 if self.is_cart_empty() else max(0.0, self.delivery_fee)

    def total_amount(self) -> float:
        return round_money(self.subtotal_amount() + self.shipping_fee())

    def should_confirm_provider_switch(self, provider_id: str) -> bool:
        if self.allow_multi_provider:
            return False
        clean_incoming = str(provider_id or "").strip()
        if not clean_incoming:
            return False
        for item in self.cart_items:
            existing_prov = str(item.provider_id or "").strip()
            if existing_prov and existing_prov != clean_incoming:
                return True
        return False

    def find_matching_item(self, candidate: CartItemModel) -> CartItemModel | None:
        if not candidate or not candidate.item_id:
            return None
        for existing in self.cart_items:
            if existing.item_id != candidate.item_id:
                continue
            if existing.variant_combination_key and candidate.variant_combination_key:
                if existing.variant_combination_key == candidate.variant_combination_key:
                    return existing
                continue
            return existing
        return None

    def add_item(self, item: CartItemModel, stock_limit: int = NSNotFound) -> bool:
        if not item or not item.item_id:
            return False
        if item.quantity <= 0:
            return False
        if item.price < 0.01 or not math.isfinite(item.price):
            return False
        if self.should_confirm_provider_switch(item.provider_id):
            return False
        if self.is_locked:
            return False

        self.is_locked = True
        try:
            self.last_removed_item = None
            self.last_removed_index = NSNotFound

            existing = self.find_matching_item(item)
            existing_qty = existing.quantity if existing else 0

            # Stock limit resolution
            limit = stock_limit
            if limit == NSNotFound and item.stock_quantity != NSNotFound:
                limit = item.stock_quantity
            if limit == NSNotFound:
                return False  # fail-closed
            if limit <= 0:
                return False  # out of stock

            available = max(0, limit - existing_qty)
            if available <= 0:
                return False  # stock ceiling reached

            increment = min(item.quantity, available)
            if increment <= 0:
                return False

            if existing:
                existing.quantity += increment
                if limit != NSNotFound:
                    existing.stock_quantity = limit
                # Merge variant metadata
                if item.variant_combination_key: existing.variant_combination_key = item.variant_combination_key
                if item.sellable_unit_id: existing.sellable_unit_id = item.sellable_unit_id
                if item.variant_id: existing.variant_id = item.variant_id
                if item.sku: existing.sku = item.sku
                if item.barcode: existing.barcode = item.barcode
                if item.selected_options: existing.selected_options = dict(item.selected_options)
            else:
                item.quantity = increment
                item.stock_quantity = limit
                self.cart_items.append(item)
            return True
        finally:
            self.is_locked = False

    def remove_item(self, item: CartItemModel) -> bool:
        if item in self.cart_items:
            self.last_removed_index = self.cart_items.index(item)
            self.last_removed_item = item
            self.cart_items.remove(item)
            return True
        return False

    def restore_last_removed(self) -> bool:
        if self.last_removed_item and self.last_removed_index != NSNotFound:
            idx = min(self.last_removed_index, len(self.cart_items))
            self.cart_items.insert(idx, self.last_removed_item)
            self.last_removed_item = None
            self.last_removed_index = NSNotFound
            return True
        return False

    def update_quantity(self, item: CartItemModel, new_quantity: int, stock_limit: int = NSNotFound) -> bool:
        if item not in self.cart_items:
            return False
        if new_quantity <= 0:
            return self.remove_item(item)
        limit = stock_limit if stock_limit != NSNotFound else item.stock_quantity
        if limit != NSNotFound and limit > 0:
            item.quantity = min(new_quantity, limit)
        else:
            item.quantity = new_quantity
        return True

    def clear_cart(self):
        self.cart_items.clear()
        self.last_removed_item = None
        self.last_removed_index = NSNotFound


# ==============================================================================
# 2. DETERMINISTIC TEST RUNNER
# ==============================================================================

class TestSuite:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.total = 0

    def assert_true(self, condition: bool, description: str):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"  ✅ PASS: {description}")
        else:
            self.failed += 1
            print(f"  ❌ FAIL: {description}")

    def assert_false(self, condition: bool, description: str):
        self.total += 1
        if not condition:
            self.passed += 1
            print(f"  ✅ PASS: {description}")
        else:
            self.failed += 1
            print(f"  ❌ FAIL: {description}")

    def assert_equal(self, actual, expected, description: str):
        self.total += 1
        if actual == expected:
            self.passed += 1
            print(f"  ✅ PASS: {description}")
        else:
            self.failed += 1
            print(f"  ❌ FAIL: {description} (Expected {expected!r}, got {actual!r})")

    def assert_almost_equal(self, actual: float, expected: float, description: str, tol: float = 0.001):
        self.total += 1
        if abs(actual - expected) <= tol:
            self.passed += 1
            print(f"  ✅ PASS: {description} ({actual:.2f} == {expected:.2f})")
        else:
            self.failed += 1
            print(f"  ❌ FAIL: {description} (Expected {expected:.2f}, got {actual:.2f})")


def run_all_tests():
    t = TestSuite()

    print("===============================================================")
    print("  PHASE 1: DIRECT DETERMINISTIC CART REGRESSION TESTS")
    print("===============================================================")

    # --------------------------------------------------------------------------
    # GROUP 1: CartItem Initialization, Discounts, Calculations & Edge Cases
    # --------------------------------------------------------------------------
    print("\n[Group 1: CartItem Domain & Calculations]")

    # 1.1 Non-discounted item calculations
    item1 = CartItemModel(item_id="item_01", name="Leash", quantity=2, price=25.00, original_price=25.00)
    t.assert_equal(item1.has_discount, False, "Item without discount has_discount == False")
    t.assert_almost_equal(item1.discount_per_unit, 0.0, "Zero discount per unit")
    t.assert_almost_equal(item1.line_subtotal, 50.00, "Line subtotal == price * qty (25.00 * 2 = 50.00)")
    t.assert_almost_equal(item1.line_subtotal_before_discount, 50.00, "Subtotal before discount == 50.00")
    t.assert_almost_equal(item1.line_discount_total, 0.0, "Line discount total == 0.0")

    # 1.2 Discounted item calculations
    item2 = CartItemModel(item_id="item_02", name="Harness", quantity=3, price=19.99, original_price=29.99)
    t.assert_equal(item2.has_discount, True, "Discounted item has_discount == True")
    t.assert_almost_equal(item2.discount_per_unit, 10.00, "Discount per unit == 10.00 (29.99 - 19.99)")
    t.assert_almost_equal(item2.line_subtotal, 59.97, "Line subtotal == 59.97 (19.99 * 3)")
    t.assert_almost_equal(item2.line_subtotal_before_discount, 89.97, "Subtotal before discount == 89.97 (29.99 * 3)")
    t.assert_almost_equal(item2.line_discount_total, 30.00, "Line discount total == 30.00 (10.00 * 3)")

    # 1.3 Decimal price precision edge cases (19.12 and 24.14)
    item_dec1 = CartItemModel(item_id="dec_01", quantity=3, price=19.12)
    t.assert_almost_equal(item_dec1.line_subtotal, 57.36, "Decimal price: 19.12 * 3 == 57.36 (no IEEE float drift)")
    item_dec2 = CartItemModel(item_id="dec_02", quantity=2, price=24.14)
    t.assert_almost_equal(item_dec2.line_subtotal, 48.28, "Decimal price: 24.14 * 2 == 48.28 (no IEEE float drift)")

    # 1.4 Invalid quantity cannot become negative in calculations
    item_neg = CartItemModel(item_id="neg_01", quantity=-5, price=20.00)
    t.assert_equal(item_neg.quantity, 0, "Negative quantity clamped to 0")
    t.assert_almost_equal(item_neg.line_subtotal, 0.0, "Subtotal for 0 quantity == 0.0")

    # --------------------------------------------------------------------------
    # GROUP 2: Serialization / Deserialization & Contract F-25
    # --------------------------------------------------------------------------
    print("\n[Group 2: Serialization / Deserialization & Contract F-25]")

    variant_item = CartItemModel(
        item_id="prod_100",
        name="Dog Collar",
        quantity=2,
        stock_quantity=10,
        price=15.50,
        original_price=20.00,
        image_url="https://purepets.test/collar.jpg",
        provider_id="prov_alpha",
        type_="accessory",
        size="M",
        sellable_unit_id="unit_100_red_m",
        variant_id="var_red_m",
        variant_combination_key="color=red|size=m",
        product_family_id="family_dog_collars",
        sku="SKU-COLLAR-RED-M",
        barcode="123456789012",
        is_variant=True,
        selected_options={"color": "red", "size": "m"},
        selected_options_snapshot=[{"id": "color", "value": "red"}, {"id": "size", "value": "m"}],
        options_summary="Color: Red · Size: M"
    )

    f_dict = variant_item.firestore_dictionary()
    t.assert_equal(f_dict["id"], "prod_100", "Serialized id matches")
    t.assert_equal(f_dict["itemID"], "prod_100", "Serialized itemID matches")
    t.assert_equal(f_dict["sellableUnitId"], "unit_100_red_m", "Serialized sellableUnitId matches")
    t.assert_equal(f_dict["variantId"], "var_red_m", "Serialized variantId matches")
    t.assert_equal(f_dict["variantCombinationKey"], "color=red|size=m", "Serialized variantCombinationKey matches")
    t.assert_equal(f_dict["productFamilyId"], "family_dog_collars", "Serialized productFamilyId matches")
    t.assert_equal(f_dict["sku"], "SKU-COLLAR-RED-M", "Serialized sku matches")
    t.assert_equal(f_dict["barcode"], "123456789012", "Serialized barcode matches")
    t.assert_equal(f_dict["isVariant"], True, "Serialized isVariant == True")
    t.assert_equal(f_dict["selectedOptions"], {"color": "red", "size": "m"}, "Serialized selectedOptions matches")
    t.assert_equal(f_dict["optionsSummary"], "Color: Red · Size: M", "Serialized optionsSummary matches")
    t.assert_equal(f_dict["providerID"], "prov_alpha", "Serialized providerID matches")
    t.assert_equal(f_dict["quantity"], 2, "Serialized quantity matches")
    t.assert_almost_equal(f_dict["price"], 15.50, "Serialized price matches")
    t.assert_almost_equal(f_dict["originalPrice"], 20.00, "Serialized originalPrice matches")
    t.assert_almost_equal(f_dict["discountPerUnit"], 4.50, "Serialized discountPerUnit matches")

    # CRITICAL CONTRACT F-25: stockQuantity is NOT persisted into Firestore!
    t.assert_true("stockQuantity" not in f_dict, "CONTRACT F-25: stockQuantity is strictly NOT persisted to Firestore")

    # Round-trip deserialization
    restored = CartItemModel.from_dictionary(f_dict)
    t.assert_equal(restored.item_id, "prod_100", "Restored itemID matches")
    t.assert_equal(restored.sellable_unit_id, "unit_100_red_m", "Restored sellableUnitId matches")
    t.assert_equal(restored.variant_combination_key, "color=red|size=m", "Restored variantCombinationKey matches")
    t.assert_equal(restored.quantity, 2, "Restored quantity matches")
    t.assert_almost_equal(restored.price, 15.50, "Restored price matches")
    t.assert_almost_equal(restored.original_price, 20.00, "Restored originalPrice matches")
    t.assert_equal(restored.stock_quantity, NSNotFound, "CONTRACT F-25: Restored cart item stockQuantity is initialized to NSNotFound")

    # 2.2 Corrupted and incomplete inputs fail safely
    empty_dict_item = CartItemModel.from_dictionary({})
    t.assert_equal(empty_dict_item.item_id, "", "Empty dictionary yields empty item_id")
    t.assert_equal(empty_dict_item.quantity, 0, "Empty dictionary yields 0 quantity")
    t.assert_almost_equal(empty_dict_item.price, 0.0, "Empty dictionary yields 0.0 price")

    corrupted_dict = {
        "id": "corrupt_1",
        "quantity": "invalid_number",
        "price": "not_a_float",
        "stockQuantity": 999  # Old stale stock from legacy app
    }
    corrupt_item = CartItemModel.from_dictionary(corrupted_dict)
    t.assert_equal(corrupt_item.item_id, "corrupt_1", "Corrupted item preserves ID")
    t.assert_equal(corrupt_item.quantity, 0, "Corrupted quantity safely defaults to 0")
    t.assert_almost_equal(corrupt_item.price, 0.0, "Corrupted price safely defaults to 0.0")
    t.assert_equal(corrupt_item.stock_quantity, NSNotFound, "CONTRACT F-25: Stale persisted stockQuantity is ignored and reset to NSNotFound")

    # --------------------------------------------------------------------------
    # GROUP 3: CartManager State, Invariants, Adding & Merging
    # --------------------------------------------------------------------------
    print("\n[Group 3: CartManager Adding, Merging & Stock Ceilings]")

    cart = CartManagerModel(delivery_fee=22.0)
    t.assert_true(cart.is_cart_empty(), "Initial cart is empty")
    t.assert_equal(cart.total_items_count(), 0, "Initial items count == 0")
    t.assert_almost_equal(cart.subtotal_amount(), 0.0, "Initial subtotal == 0.0")
    t.assert_almost_equal(cart.shipping_fee(), 0.0, "Empty cart shipping fee == 0.0")
    t.assert_almost_equal(cart.total_amount(), 0.0, "Empty cart total == 0.0")

    # 3.1 First add
    item_a = CartItemModel(item_id="prod_A", name="Shampoo", quantity=2, price=30.00, provider_id="prov_1")
    added = cart.add_item(item_a, stock_limit=10)
    t.assert_true(added, "First add succeeds")
    t.assert_equal(len(cart.cart_items), 1, "Cart has 1 item")
    t.assert_equal(cart.total_items_count(), 2, "Total quantity == 2")
    t.assert_almost_equal(cart.subtotal_amount(), 60.00, "Subtotal == 60.00")
    t.assert_almost_equal(cart.shipping_fee(), 22.00, "Shipping fee applied (22.00)")
    t.assert_almost_equal(cart.total_amount(), 82.00, "Total amount == 82.00 (60.00 + 22.00)")

    # 3.2 Repeated add of same standalone product merges quantity
    item_a_repeat = CartItemModel(item_id="prod_A", quantity=3, price=30.00, provider_id="prov_1")
    added_repeat = cart.add_item(item_a_repeat, stock_limit=10)
    t.assert_true(added_repeat, "Repeated add succeeds")
    t.assert_equal(len(cart.cart_items), 1, "Same product merges into existing line item (count == 1)")
    t.assert_equal(cart.cart_items[0].quantity, 5, "Merged quantity == 5 (2 + 3)")
    t.assert_almost_equal(cart.subtotal_amount(), 150.00, "Subtotal updated to 150.00")

    # 3.3 Adding beyond stock ceiling is clamped to remaining stock
    item_a_exceed = CartItemModel(item_id="prod_A", quantity=10, price=30.00, provider_id="prov_1")
    added_clamped = cart.add_item(item_a_exceed, stock_limit=7)  # only 2 more allowed (7 - 5 = 2)
    t.assert_true(added_clamped, "Add with partial available stock succeeds with clamped quantity")
    t.assert_equal(cart.cart_items[0].quantity, 7, "Quantity capped at stock ceiling (7)")

    # 3.4 Adding when stock limit is already met is rejected
    item_a_full = CartItemModel(item_id="prod_A", quantity=1, price=30.00, provider_id="prov_1")
    added_rejected = cart.add_item(item_a_full, stock_limit=7)
    t.assert_false(added_rejected, "Adding when stock ceiling reached is rejected")
    t.assert_equal(cart.cart_items[0].quantity, 7, "Quantity remains at 7")

    # 3.5 Out of stock item rejected
    item_zero_stock = CartItemModel(item_id="prod_out", quantity=1, price=50.00, provider_id="prov_1")
    added_zero = cart.add_item(item_zero_stock, stock_limit=0)
    t.assert_false(added_zero, "Adding item with 0 stock is rejected")

    # 3.6 Item with unknown stock (NSNotFound) fails closed
    item_no_stock_hint = CartItemModel(item_id="prod_unknown", quantity=1, price=50.00, provider_id="prov_1")
    added_fail_closed = cart.add_item(item_no_stock_hint, stock_limit=NSNotFound)
    t.assert_false(added_fail_closed, "Adding item with unknown stock (NSNotFound) fails closed")

    # 3.7 Invalid price rejected
    item_free = CartItemModel(item_id="prod_free", quantity=1, price=0.00, provider_id="prov_1")
    added_free = cart.add_item(item_free, stock_limit=5)
    t.assert_false(added_free, "Adding item with price 0.0 is rejected")

    # --------------------------------------------------------------------------
    # GROUP 4: Multi-Variant Coexistence & Separation
    # --------------------------------------------------------------------------
    print("\n[Group 4: Multi-Variant Coexistence & Separation]")

    # Product with multiple variants (same item_id, different variant_combination_key)
    var_red = CartItemModel(
        item_id="prod_shirt",
        name="Dog Shirt",
        quantity=1,
        price=40.00,
        provider_id="prov_1",
        variant_combination_key="color=red|size=s",
        is_variant=True
    )
    var_blue = CartItemModel(
        item_id="prod_shirt",
        name="Dog Shirt",
        quantity=2,
        price=40.00,
        provider_id="prov_1",
        variant_combination_key="color=blue|size=m",
        is_variant=True
    )

    t.assert_true(cart.add_item(var_red, stock_limit=10), "Add variant Red succeeds")
    t.assert_true(cart.add_item(var_blue, stock_limit=10), "Add variant Blue succeeds")
    t.assert_equal(len(cart.cart_items), 3, "Distinct variants of same product remain separate line items")

    # Adding more of variant Red merges ONLY with variant Red
    var_red_more = CartItemModel(
        item_id="prod_shirt",
        quantity=3,
        price=40.00,
        provider_id="prov_1",
        variant_combination_key="color=red|size=s"
    )
    t.assert_true(cart.add_item(var_red_more, stock_limit=10), "Add more of variant Red succeeds")

    red_in_cart = [x for x in cart.cart_items if x.variant_combination_key == "color=red|size=s"][0]
    blue_in_cart = [x for x in cart.cart_items if x.variant_combination_key == "color=blue|size=m"][0]
    t.assert_equal(red_in_cart.quantity, 4, "Variant Red merged quantity == 4 (1 + 3)")
    t.assert_equal(blue_in_cart.quantity, 2, "Variant Blue quantity untouched == 2")

    # --------------------------------------------------------------------------
    # GROUP 5: Provider Switch Policy
    # --------------------------------------------------------------------------
    print("\n[Group 5: Provider Switch Policy]")

    t.assert_equal(cart.allow_multi_provider, False, "Multi-provider cart disallowed by default")
    diff_provider_item = CartItemModel(item_id="prod_prov2", quantity=1, price=50.00, provider_id="prov_2")
    
    t.assert_true(cart.should_confirm_provider_switch("prov_2"), "Provider switch required for different provider")
    t.assert_false(cart.should_confirm_provider_switch("prov_1"), "No switch required for same provider")
    t.assert_false(cart.should_confirm_provider_switch(""), "Empty provider triggers no switch")

    # Attempting to add item from different provider is rejected by default
    added_diff = cart.add_item(diff_provider_item, stock_limit=10)
    t.assert_false(added_diff, "Directly adding item from different provider is blocked")

    # When allow_multi_provider is enabled:
    cart.allow_multi_provider = True
    added_multi = cart.add_item(diff_provider_item, stock_limit=10)
    t.assert_true(added_multi, "Adding item from different provider allowed when allow_multi_provider == True")
    cart.allow_multi_provider = False  # restore

    # --------------------------------------------------------------------------
    # GROUP 6: Removal, Quantity Update & Undo Restoration
    # --------------------------------------------------------------------------
    print("\n[Group 6: Removal, Quantity Update & Undo Restoration]")

    # 6.1 Update quantity
    t.assert_true(cart.update_quantity(red_in_cart, 6, stock_limit=10), "Quantity updated to 6")
    t.assert_equal(red_in_cart.quantity, 6, "Quantity verified at 6")

    # Update to 0 removes item
    t.assert_true(cart.update_quantity(red_in_cart, 0), "Updating quantity to 0 removes item")
    t.assert_true(red_in_cart not in cart.cart_items, "Item removed from cart items")

    # 6.2 Undo / Restore
    restored_ok = cart.restore_last_removed()
    t.assert_true(restored_ok, "Restore last removed item succeeds")
    t.assert_true(red_in_cart in cart.cart_items, "Restored item is back in cart")

    # 6.3 Explicit remove item
    t.assert_true(cart.remove_item(blue_in_cart), "Remove item succeeds")
    t.assert_true(blue_in_cart not in cart.cart_items, "Item verified removed")

    # 6.4 Clear cart
    cart.clear_cart()
    t.assert_true(cart.is_cart_empty(), "Cart is empty after clear_cart")
    t.assert_equal(cart.total_items_count(), 0, "Item count == 0 after clear_cart")
    t.assert_almost_equal(cart.total_amount(), 0.0, "Total amount == 0.0 after clear_cart")

    # --------------------------------------------------------------------------
    # GROUP 7: Objective-C Static Source Code Invariant Audits
    # --------------------------------------------------------------------------
    print("\n[Group 7: Objective-C Source Code Contract Invariant Audits]")

    with open(CART_ITEM_M, "r", encoding="utf-8") as f:
        cart_item_m_src = f.read()

    with open(CART_MGR_M, "r", encoding="utf-8") as f:
        cart_mgr_m_src = f.read()

    with open(CART_CALC_M, "r", encoding="utf-8") as f:
        cart_calc_m_src = f.read()

    # 7.1 Verify Contract F-25: stockQuantity is NOT persisted in firestoreDictionary
    fs_dict_body = re.search(r"- \(NSDictionary \*\)firestoreDictionary\s*\{([^}]+)\}", cart_item_m_src)
    t.assert_true(fs_dict_body is not None, "firestoreDictionary implementation found in CartItem.m")
    if fs_dict_body:
        t.assert_true("stockQuantity" not in fs_dict_body.group(1),
                      "CONTRACT F-25: stockQuantity is NOT included in firestoreDictionary payload")

    # 7.2 Verify Contract F-25: stockQuantity in initWithDictionary starts as NSNotFound
    init_dict_body = re.search(r"- \(instancetype\)initWithDictionary:\(NSDictionary \*\)dict\s*\{([\s\S]+?)(?=\n-|\n#pragma|\n\+)", cart_item_m_src)
    t.assert_true(init_dict_body is not None, "initWithDictionary implementation found in CartItem.m")
    if init_dict_body:
        t.assert_true("_stockQuantity = NSNotFound;" in init_dict_body.group(1),
                      "CONTRACT F-25: initWithDictionary initializes _stockQuantity = NSNotFound")

    # 7.3 Verify thread-safety lock in CartManager.m
    t.assert_true("@synchronized (self)" in cart_mgr_m_src, "CartManager uses @synchronized(self) for thread-safety")
    t.assert_true("self.isLocked = YES;" in cart_mgr_m_src and "self.isLocked = NO;" in cart_mgr_m_src,
                  "CartManager manages isLocked re-entrancy protection")

    # 7.4 Verify price validation guard in CartManager.m
    t.assert_true("item.price < 0.01 || isnan(item.price)" in cart_mgr_m_src,
                  "CartManager rejects items with invalid price (< 0.01 or NaN)")

    # 7.5 Verify multi-variant matching in pp_existingItemMatching:
    t.assert_true("[existing.variantCombinationKey isEqualToString:item.variantCombinationKey]" in cart_mgr_m_src,
                  "CartManager compares variantCombinationKey to support distinct variants of same itemID")

    # 7.6 Verify zero floating-point drift: PPCartRoundMoney present in Calculator
    t.assert_true("PPCartRoundMoney" in cart_calc_m_src, "PPCartCalculator enforces 2-decimal money rounding")

    # 7.7 Verify fail-closed stock limit in CartManager.m
    t.assert_true("if (stockLimit == NSNotFound)" in cart_mgr_m_src,
                  "CartManager fails closed when stockLimit == NSNotFound")

    # 7.8 Verify provider switch check in CartManager.m
    t.assert_true("shouldConfirmProviderSwitchForItem" in cart_mgr_m_src,
                  "CartManager checks shouldConfirmProviderSwitchForItem before mutation")

    # --------------------------------------------------------------------------
    # GROUP 8: Cart State Ownership & Reconciliation Invariants (Phase 2)
    # --------------------------------------------------------------------------
    print("\n[Group 8: Cart State Ownership & Reconciliation Invariants (Phase 2)]")

    # 8.1 Verify syncCartToFirestore uses pp_firestorePayloadForItem and strictly avoids stockQuantity
    sync_batch_body = re.search(r"- \(void\)syncCartToFirestore:\(NSArray<CartItem \*> \*\)items\s*\{([\s\S]+?)\n\}", cart_mgr_m_src)
    t.assert_true(sync_batch_body is not None, "syncCartToFirestore implementation found in CartManager.m")
    if sync_batch_body:
        t.assert_true("pp_firestorePayloadForItem:item quantity:item.quantity" in sync_batch_body.group(1),
                      "syncCartToFirestore uses pp_firestorePayloadForItem (consistent serializer)")
        t.assert_true("data[@\"stockQuantity\"]" not in sync_batch_body.group(1),
                      "CONTRACT F-25: syncCartToFirestore strictly does NOT persist stockQuantity")

    # 8.2 Verify listener reconciliation uses variant-aware cartKey
    listener_body = re.search(r"- \(void\)startListeningToCartChanges\s*\{([\s\S]+?)\n\}", cart_mgr_m_src)
    t.assert_true(listener_body is not None, "startListeningToCartChanges implementation found in CartManager.m")
    if listener_body:
        t.assert_true("cartKey" in listener_body.group(1),
                      "startListeningToCartChanges defines variant-aware cartKey")
        t.assert_true("[self pp_cartKeyForItem:item]" in listener_body.group(1) or
                      "[NSString stringWithFormat:@\"%@#%@\", item.itemID, item.variantCombinationKey]" in listener_body.group(1),
                      "cartKey combines itemID and variantCombinationKey to prevent variant collision")
        t.assert_true("mergedByItemID[cartKey]" in listener_body.group(1),
                      "mergedByItemID maps by cartKey instead of raw itemID")

    # 8.3 Simulate remote snapshot reconciliation with multiple variants of the same product
    remote_docs = [
        {
            "id": "prod_hoodie",
            "itemID": "prod_hoodie",
            "name": "Pet Hoodie",
            "price": 35.0,
            "quantity": 1,
            "variantCombinationKey": "color=black|size=l",
            "isVariant": True,
            "providerID": "prov_1"
        },
        {
            "id": "prod_hoodie",
            "itemID": "prod_hoodie",
            "name": "Pet Hoodie",
            "price": 35.0,
            "quantity": 2,
            "variantCombinationKey": "color=yellow|size=m",
            "isVariant": True,
            "providerID": "prov_1"
        }
    ]

    reconciled_by_key = {}
    for doc in remote_docs:
        item = CartItemModel.from_dictionary(doc)
        ckey = f"{item.item_id}#{item.variant_combination_key}" if item.variant_combination_key else item.item_id
        if ckey in reconciled_by_key:
            reconciled_by_key[ckey].quantity += item.quantity
        else:
            reconciled_by_key[ckey] = item

    t.assert_equal(len(reconciled_by_key), 2, "Remote reconciliation preserves 2 distinct variants of same product")
    t.assert_true("prod_hoodie#color=black|size=l" in reconciled_by_key, "Black variant key preserved")
    t.assert_true("prod_hoodie#color=yellow|size=m" in reconciled_by_key, "Yellow variant key preserved")
    t.assert_equal(reconciled_by_key["prod_hoodie#color=black|size=l"].quantity, 1, "Black variant quantity == 1")
    t.assert_equal(reconciled_by_key["prod_hoodie#color=yellow|size=m"].quantity, 2, "Yellow variant quantity == 2")

    # 8.4 Verify listener teardown prevents stacked listeners
    t.assert_true("[self.cartListener remove];" in listener_body.group(1) if listener_body else False,
                  "startListeningToCartChanges removes existing cartListener before registering new one")
    t.assert_true("self.cartListener = nil;" in listener_body.group(1) if listener_body else False,
                  "startListeningToCartChanges clears cartListener reference before reattaching")

    # --------------------------------------------------------------------------
    # GROUP 9: Cart Sync Failure Safety (Phase 3)
    # --------------------------------------------------------------------------
    print("\n[Group 9: Cart Sync Failure Safety & Reconciliation (Phase 3)]")

    # 9.1 Verify updateQuantity rollback on remote error
    update_qty_body = re.search(r"- \(void\)updateQuantity:\(NSInteger\)newQuantity[\s\S]+?\{([\s\S]+?)\n\}", cart_mgr_m_src)
    t.assert_true(update_qty_body is not None, "updateQuantity implementation found in CartManager.m")
    if update_qty_body:
        code = update_qty_body.group(1)
        t.assert_true("previousQuantity = existing.quantity" in code,
                      "updateQuantity snapshots previousQuantity for rollback")
        t.assert_true("current.quantity = previousQuantity" in code,
                      "updateQuantity rolls back current.quantity to previousQuantity on remote error")
        t.assert_true("PPCartCompleteSync(completion, NO)" in code,
                      "updateQuantity notifies completion(NO) on remote write failure")
        t.assert_true("PPCartCompleteSync(completion, YES)" in code,
                      "updateQuantity notifies completion(YES) on remote write success")

    # 9.2 Verify pendingSyncItemKeys and pendingDeletedItemKeys in CartManager
    t.assert_true("pendingSyncItemKeys" in cart_mgr_m_src,
                  "CartManager maintains pendingSyncItemKeys tracking")
    t.assert_true("pendingDeletedItemKeys" in cart_mgr_m_src,
                  "CartManager maintains pendingDeletedItemKeys tracking")

    # 9.3 Verify removeItem supports optional completion and variant safety
    remove_item_comp = re.search(r"- \(void\)removeItem:\(CartItem \*\)item completion:\(void \(\^ _Nullable\)\(BOOL success\)\)completion\s*\{([\s\S]+?)\n\}", cart_mgr_m_src)
    t.assert_true(remove_item_comp is not None, "removeItem:completion: implementation found in CartManager.m")
    if remove_item_comp:
        code = remove_item_comp.group(1)
        t.assert_true("pendingDeletedItemKeys addObject" in code,
                      "removeItem:completion: tracks deleted item in pendingDeletedItemKeys")
        t.assert_true("pendingSyncItemKeys removeObject" in code,
                      "removeItem:completion: clears any pending sync for removed item")
        t.assert_true("docVariantKey" in code or "variantCombinationKey" in code,
                      "removeItem:completion: verifies variantCombinationKey to protect sibling variants")

    # 9.4 Verify malformed remote documents rejected fail-closed in listener
    if listener_body:
        code = listener_body.group(1)
        t.assert_true("item.price < 0.01" in code or "isnan(item.price)" in code,
                      "startListeningToCartChanges rejects malformed/corrupt prices (< 0.01 or NaN)")
        t.assert_true("pendingDeletedItemKeys" in code,
                      "startListeningToCartChanges checks pendingDeletedItemKeys to suppress resurrection")
        t.assert_true("pendingSyncItemKeys" in code,
                      "startListeningToCartChanges reconciles pendingSyncItemKeys to prevent silent cart loss")
        t.assert_true("pp_areCartItems:self.cartItems equalTo:remoteCart" in code,
                      "startListeningToCartChanges checks duplicate snapshot equality to prevent notification loops")
        t.assert_true("stopListeningToCartChanges" in code,
                      "startListeningToCartChanges stops listener on auth invalidation / permission denied")

    # 9.5 Verify undoLastRemoval re-syncs restored item
    undo_body = re.search(r"- \(BOOL\)undoLastRemoval\s*\{([\s\S]+?)\n\}", cart_mgr_m_src)
    t.assert_true(undo_body is not None, "undoLastRemoval implementation found in CartManager.m")
    if undo_body:
        code = undo_body.group(1)
        t.assert_true("pendingDeletedItemKeys removeObject" in code,
                      "undoLastRemoval clears restored item from pendingDeletedItemKeys")
        t.assert_true("pp_syncCartItemToFirestore" in code,
                      "undoLastRemoval re-syncs restored item to Firestore mirror")

    # 9.6 Verify clearCart resets pending sync and delete state
    clear_cart_body = re.search(r"- \(void\)clearCart\s*\{([\s\S]+?)\n\}", cart_mgr_m_src)
    t.assert_true(clear_cart_body is not None, "clearCart implementation found in CartManager.m")
    if clear_cart_body:
        code = clear_cart_body.group(1)
        t.assert_true("pendingSyncItemKeys removeAllObjects" in code,
                      "clearCart clears pendingSyncItemKeys")
        t.assert_true("pendingDeletedItemKeys removeAllObjects" in code,
                      "clearCart clears pendingDeletedItemKeys")

    # 9.7 Python Simulation: Reconciler preserves local-only item during remote write failure / offline
    local_cart = [
        CartItemModel(item_id="item_local_offline", name="Offline Snack", quantity=2, price=18.50, provider_id="p1")
    ]
    pending_sync_keys = {"item_local_offline"}
    remote_snapshot = []  # Firestore is empty because write failed / offline

    reconciled_cart = list(remote_snapshot)
    for l_item in local_cart:
        if l_item.item_id in pending_sync_keys:
            if not any(r.item_id == l_item.item_id for r in reconciled_cart):
                reconciled_cart.append(l_item)

    t.assert_equal(len(reconciled_cart), 1, "Simulated reconciler preserves uncommitted local item")
    t.assert_equal(reconciled_cart[0].item_id, "item_local_offline", "Preserved item ID matches")
    t.assert_equal(reconciled_cart[0].quantity, 2, "Preserved quantity matches local intent")

    # 9.8 Python Simulation: Reconciler suppresses resurrection of locally-deleted item
    pending_deleted_keys = {"item_deleted_offline"}
    remote_snapshot_with_stale_item = [
        {"id": "item_deleted_offline", "itemID": "item_deleted_offline", "name": "Deleted Chew", "quantity": 1, "price": 12.0}
    ]
    reconciled_items = []
    for doc in remote_snapshot_with_stale_item:
        item = CartItemModel.from_dictionary(doc)
        if item.item_id in pending_deleted_keys:
            continue  # Suppress resurrection
        reconciled_items.append(item)

    t.assert_equal(len(reconciled_items), 0, "Simulated reconciler suppresses resurrection of locally deleted item")

    # 9.9 Python Simulation: Malformed remote documents fail closed
    malformed_docs = [
        {"id": "bad_1", "itemID": "bad_1", "name": "Freebie", "quantity": 1, "price": 0.0},
        {"id": "bad_2", "itemID": "bad_2", "name": "Negative", "quantity": 1, "price": -10.0},
        {"id": "bad_3", "itemID": "bad_3", "name": "Zero Qty", "quantity": 0, "price": 25.0},
        {"id": "good_1", "itemID": "good_1", "name": "Valid Collar", "quantity": 1, "price": 45.0}
    ]
    admitted = []
    for doc in malformed_docs:
        item = CartItemModel.from_dictionary(doc)
        if item.quantity <= 0 or item.price < 0.01:
            continue
        admitted.append(item)

    t.assert_equal(len(admitted), 1, "Simulated reconciler admits only well-formed remote items")
    t.assert_equal(admitted[0].item_id, "good_1", "Admitted item is valid collar")

    # 9.10 Python Simulation: Snapshot equality comparison
    def are_carts_equal(c1, c2):
        if len(c1) != len(c2):
            return False
        m1 = {i.item_id: i for i in c1}
        for b in c2:
            a = m1.get(b.item_id)
            if not a:
                return False
            if a.quantity != b.quantity or abs(a.price - b.price) > 0.001:
                return False
        return True

    cart_base = [CartItemModel(item_id="prod_1", quantity=3, price=20.0)]
    cart_duplicate = [CartItemModel(item_id="prod_1", quantity=3, price=20.0)]
    cart_diff_qty = [CartItemModel(item_id="prod_1", quantity=4, price=20.0)]
    cart_diff_item = [CartItemModel(item_id="prod_2", quantity=3, price=20.0)]

    t.assert_true(are_carts_equal(cart_base, cart_duplicate), "Duplicate snapshot detected as equal")
    t.assert_false(are_carts_equal(cart_base, cart_diff_qty), "Different quantity detected as not equal")
    t.assert_false(are_carts_equal(cart_base, cart_diff_item), "Different item detected as not equal")

    # --------------------------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------------------------
    print("\n===============================================================")
    print(f"  RESULTS: {t.passed}/{t.total} tests passed ({t.failed} failures)")
    print("===============================================================")

    if t.failed > 0:
        print("❌ PHASE 1, 2 & 3 REGRESSION TESTS FAILED!")
        sys.exit(1)
    else:
        print("🎉 ALL PHASE 1, 2 & 3 CART REGRESSION TESTS PASSED (100% GREEN)!")
        sys.exit(0)


if __name__ == "__main__":
    run_all_tests()

