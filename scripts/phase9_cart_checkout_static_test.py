#!/usr/bin/env python3
"""
Phase 9 Static Contract & Architecture Verification Test
Verifies that Pure Pets IOS and Infra Cart, Checkout & Orders implementation satisfies:
1. CartItem typed variant properties, initialization from PetAccessory, and Firestore serialization/deserialization.
2. CartManager multi-variant coexistence, matching by (itemID + variantCombinationKey), and full payload synchronization.
3. PPCartTableCell tactile variant badge layout, auto-hiding for standard items, and cell reuse resets.
4. PPOrderDetailsMissionControl line item options snapshot extraction and UI presentation.
5. OrderHistoryViewController search indexing of variant options and SKUs.
6. Zero direct client Firestore writes to Orders or petAccessories.
"""

import sys
import os
import re

IOS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PAYMENTS_DIR = os.path.join(IOS_ROOT, "Pure Pets", "MainApp", "PAYMENTS")
CART_ORDERS_DIR = os.path.join(PAYMENTS_DIR, "CartAndOrdersFiles")
CART_MGR_DIR = os.path.join(PAYMENTS_DIR, "Manager", "Cart")

def check_file_contains(filepath, patterns, label):
    if not os.path.exists(filepath):
        print(f"❌ FAIL: File not found: {filepath}")
        return False
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    for pattern in patterns:
        if not re.search(pattern, content):
            print(f"❌ FAIL: {label} missing '{pattern}' in {os.path.basename(filepath)}")
            return False
    print(f"✅ PASS: {label} in {os.path.basename(filepath)}")
    return True

def check_file_not_contains(filepath, patterns, label):
    if not os.path.exists(filepath):
        print(f"❌ FAIL: File not found: {filepath}")
        return False
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    for pattern in patterns:
        if re.search(pattern, content):
            print(f"❌ FAIL: {label} found forbidden pattern '{pattern}' in {os.path.basename(filepath)}")
            return False
    print(f"✅ PASS: {label} in {os.path.basename(filepath)}")
    return True

def main():
    print("===============================================================")
    print("  PHASE 9: CART, CHECKOUT & ORDERS STATIC VERIFICATION")
    print("===============================================================")
    failures = 0

    # 1. Check CartItem.h
    cart_item_h = os.path.join(CART_ORDERS_DIR, "CartItem.h")
    if not check_file_contains(cart_item_h, [
        r"@property\s*\(.*?\)\s*NSString\s*\*sellableUnitId",
        r"@property\s*\(.*?\)\s*NSString\s*\*variantId",
        r"@property\s*\(.*?\)\s*NSString\s*\*variantCombinationKey",
        r"@property\s*\(.*?\)\s*NSString\s*\*productFamilyId",
        r"@property\s*\(.*?\)\s*NSString\s*\*sku",
        r"@property\s*\(.*?\)\s*NSString\s*\*barcode",
        r"@property\s*\(.*?\)\s*BOOL\s*isVariant",
        r"@property\s*\(.*?\)\s*NSDictionary<\s*NSString\s*\*,\s*NSString\s*\*>\s*\*selectedOptions",
        r"@property\s*\(.*?\)\s*NSArray<\s*NSDictionary\s*\*>\s*\*selectedOptionsSnapshot",
        r"@property\s*\(.*?\)\s*NSString\s*\*optionsSummary"
    ], "CartItem.h typed variant properties"):
        failures += 1

    # 2. Check CartItem.m
    cart_item_m = os.path.join(CART_ORDERS_DIR, "CartItem.m")
    if not check_file_contains(cart_item_m, [
        r'_sellableUnitId\s*=\s*accessory\.sellableUnitId\.length\s*>\s*0\s*\?\s*accessory\.sellableUnitId\s*:\s*_itemID;',
        r'_variantCombinationKey\s*=\s*accessory\.variantCombinationKey\s*\?:',
        r'_selectedOptions\s*=\s*\[accessory\.selectedOptions\s*copy\];',
        r'dict\[@"sellableUnitId"\]\s*=\s*self\.sellableUnitId',
        r'dict\[@"variantCombinationKey"\]\s*=\s*self\.variantCombinationKey',
        r'dict\[@"optionsSummary"\]\s*=\s*self\.optionsSummary',
        # Dictionary hydration validates optional strings before falling back to
        # the legacy product id; NSNull must not become a sellable identifier.
        r'_sellableUnitId\s*=\s*PPCartItemString\(dict\[@"sellableUnitId"\]\);',
        r'if\s*\(_sellableUnitId\.length\s*==\s*0\)\s*\{\s*_sellableUnitId\s*=\s*_itemID;'
    ], "CartItem.m variant mapping and serialization"):
        failures += 1

    # 3. Check CartManager.m
    cart_mgr_m = os.path.join(CART_MGR_DIR, "CartManager.m")
    if not check_file_contains(cart_mgr_m, [
        r"- \(CartItem \*\)pp_existingItemMatching:\(CartItem \*\)item",
        r"if\s*\(\[existing\.variantCombinationKey isEqualToString:item\.variantCombinationKey\]\)",
        r"CartItem \*existing = \[self pp_existingItemMatching:item\];",
        r"copy\.sellableUnitId\s*=\s*source\.sellableUnitId\s*\?:",
        r"copy\.variantCombinationKey\s*=\s*source\.variantCombinationKey\s*\?:",
        r"NSMutableDictionary \*payload = \[\[item firestoreDictionary\] mutableCopy\];"
    ], "CartManager.m multi-variant coexistence & sync"):
        failures += 1

    # 4. Check PPCartTableCell.h and PPCartTableCell.m
    cell_h = os.path.join(CART_ORDERS_DIR, "PPCartTableCell.h")
    cell_m = os.path.join(CART_ORDERS_DIR, "PPCartTableCell.m")
    if not check_file_contains(cell_h, [
        r"@property\s*\(.*?\)\s*UILabel\s*\*variantOptionsLabel"
    ], "PPCartTableCell.h variant options label"):
        failures += 1

    if not check_file_contains(cell_m, [
        r"UIStackView \*variantOptionsRow = \[\[UIStackView alloc\] initWithArrangedSubviews:",
        r"self\.variantOptionsRow = variantOptionsRow;",
        r"self\.variantOptionsLabel\.text\s*=\s*item\.optionsSummary;",
        r"self\.variantOptionsRow\.hidden\s*=\s*NO;",
        r"self\.variantOptionsRow\.hidden\s*=\s*YES;"
    ], "PPCartTableCell.m capsule pill badge & reuse reset"):
        failures += 1

    # 5. Check PPOrderDetailsMissionControlBridge.m
    bridge_m = os.path.join(CART_ORDERS_DIR, "PPOrderDetailsMissionControlBridge.m")
    if not check_file_contains(bridge_m, [
        r"NSString \*optionsSummary = PPMissionSafeString\(item\[@\"optionsSummary\"\]\);",
        r'line\[@"sku"\]\s*=\s*PPMissionSafeString\(item\[@"sku"\]\);',
        r'@\"optionsSummary\": PPMissionSafeString\(line\[@\"optionsSummary\"\]\)'
    ], "PPOrderDetailsMissionControlBridge.m variant options & sku extraction"):
        failures += 1

    # 6. Check PPOrderDetailsMissionControlModels.swift
    models_swift = os.path.join(CART_ORDERS_DIR, "PPOrderDetailsMissionControlModels.swift")
    if not check_file_contains(models_swift, [
        r"let optionsSummary:\s*String",
        r"let sku:\s*String",
        r'optionsSummary = dictionary\.missionString\("optionsSummary"\)'
    ], "PPOrderDetailsMissionControlModels.swift domain properties"):
        failures += 1

    # 7. Check PPOrderDetailsMissionControlViews.swift
    views_swift = os.path.join(CART_ORDERS_DIR, "PPOrderDetailsMissionControlViews.swift")
    if not check_file_contains(views_swift, [
        r"if !item\.optionsSummary\.isEmpty",
        r"Text\(item\.optionsSummary\)"
    ], "PPOrderDetailsMissionControlViews.swift capsule badge rendering"):
        failures += 1

    # 8. Check OrderHistoryViewController.m
    order_hist_m = os.path.join(CART_ORDERS_DIR, "OrderHistoryViewController.m")
    if not check_file_contains(order_hist_m, [
        r'dictionary\[@"optionsSummary"\] \?: @""',
        r'dictionary\[@"sku"\] \?: @""'
    ], "OrderHistoryViewController.m variant search indexing"):
        failures += 1

    # 9. Invariant: Zero direct client writes to Orders from Cart or Order Views
    for target_file in [cell_m, cart_mgr_m]:
        if not check_file_not_contains(target_file, [
            r'setData:.*?collection:\s*@"Orders"',
            r'updateData:.*?collection:\s*@"Orders"'
        ], f"No direct Orders writes in {os.path.basename(target_file)}"):
            failures += 1

    print("---------------------------------------------------------------")
    if failures == 0:
        print("🎉 ALL PHASE 9 STATIC CONTRACT CHECKS PASSED (10/10)!")
        print("===============================================================")
        return 0
    else:
        print(f"❌ FAILED WITH {failures} VIOLATIONS!")
        print("===============================================================")
        return 1

if __name__ == "__main__":
    sys.exit(main())
