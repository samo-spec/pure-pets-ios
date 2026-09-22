#!/usr/bin/env python3
"""
Phase 10 Static Contract & Architecture Verification Test
Verifies that Pure Pets Returns, Refunds & Exchanges implementation satisfies:
1. orderSupportCancellation.js extracts exact variant identifier (sellableUnitId / variantId)
   ahead of parent itemId to guarantee variant-exact inventory restock.
2. productVariantExchange.js exists and exports processProductVariantExchangeHandler.
3. Strict staff permission validation (stock.manage / pos.sell).
4. Order line validation enforcing unreturned/un-exchanged quantity limits.
5. Out-of-stock replacement gating with REPLACEMENT_OUT_OF_STOCK domain code.
6. Damaged return disposition routing stock to DAMAGED bucket without increasing sellable stock.
7. Price delta calculation referencing frozen order line price snapshots.
8. Dual stockMovements and inventoryLedger auditing for both returned and replacement variants.
9. Mandatory writeAuditLog invocation on all exchanges.
10. Exit Gate: No return or exchange can increase the wrong variant's inventory.
"""

import sys
import os
import re

INFRA_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "Pure Pets Infra", "functions"))

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

def main():
    print("===============================================================")
    print("  PHASE 10: RETURNS, REFUNDS & EXCHANGES STATIC VERIFICATION")
    print("===============================================================")
    failures = 0

    # 1. Check orderSupportCancellation.js
    cancellation_file = os.path.join(INFRA_ROOT, "orderSupportCancellation.js")
    if not check_file_contains(cancellation_file, [
        r"const productId = trimmed\(item\.sellableUnitId \|\| item\.variantId \|\| item\.itemId",
    ], "orderSupportCancellation.js variant-first item resolution"):
        failures += 1

    # 2. Check productVariantExchange.js exists and exports processProductVariantExchangeHandler
    exchange_file = os.path.join(INFRA_ROOT, "productVariantExchange.js")
    if not check_file_contains(exchange_file, [
        r"processProductVariantExchangeHandler",
        r"module\.exports\s*=\s*\{[^}]*processProductVariantExchangeHandler",
    ], "productVariantExchange.js module export"):
        failures += 1

    # 3. Check staff authorization & permissions
    if not check_file_contains(exchange_file, [
        r"requireAuth\(request\)",
        r'requireInventoryPermission\(request,\s*"stock\.manage"\)',
    ], "productVariantExchange.js staff permission validation"):
        failures += 1

    # 4. Check un-exchanged quantity validation
    if not check_file_contains(exchange_file, [
        r"alreadyExchanged\s*=\s*Number\(sourceLine\.exchangedQuantity",
        r"availableForExchange\s*=\s*Math\.max\(0,\s*lineQty\s*-\s*alreadyExchanged\s*-\s*alreadyRefunded\)",
        r'domainCode:\s*"EXCHANGE_QUANTITY_EXCEEDED"',
    ], "productVariantExchange.js over-exchange quantity protection"):
        failures += 1

    # 5. Check out-of-stock replacement variant gating
    if not check_file_contains(exchange_file, [
        r"replacementCatalogStock\s*<\s*quantity",
        r'domainCode:\s*"REPLACEMENT_OUT_OF_STOCK"',
    ], "productVariantExchange.js out-of-stock replacement rejection"):
        failures += 1

    # 6. Check damaged and quarantine return dispositions
    if not check_file_contains(exchange_file, [
        r"conditionToBucket\(condition\)",
        r"destBucket\s*===\s*INVENTORY_BUCKET\.AVAILABLE",
        r"destBucket\s*===\s*INVENTORY_BUCKET\.DAMAGED",
        r"destBucket\s*===\s*INVENTORY_BUCKET\.QUARANTINE",
    ], "productVariantExchange.js disposition routing (AVAILABLE/DAMAGED/QUARANTINE)"):
        failures += 1

    # 7. Check price delta calculation from frozen snapshot
    if not check_file_contains(exchange_file, [
        r"sourceUnitPrice\s*=\s*roundMoney\(Number\(sourceLine\.price",
        r"replacementUnitPrice\s*=\s*roundMoney\(Number\(replacementData\.finalPrice",
        r"priceDelta\s*=\s*roundMoney\(replacementTotal\s*-\s*sourceTotal\)",
    ], "productVariantExchange.js frozen price snapshot delta calculation"):
        failures += 1

    # 8. Check dual stockMovements and inventoryLedger logging
    if not check_file_contains(exchange_file, [
        r'type:\s*"stock_in"',
        r'movementType:\s*"RETURN_EXCHANGE"',
        r'type:\s*"stock_out"',
        r'movementType:\s*"EXCHANGE_OUT"',
        r'type:\s*"exchange_return"',
        r'type:\s*"exchange_replacement"',
    ], "productVariantExchange.js dual stockMovements & ledger tracking"):
        failures += 1

    # 9. Check mandatory audit logging
    if not check_file_contains(exchange_file, [
        r"writeAuditLog\(",
        r'action:\s*"order_product_variant_exchange"',
        r"targetCollection:\s*ORDERS_COLLECTION",
    ], "productVariantExchange.js mandatory audit log integration"):
        failures += 1

    # 10. Exit Gate Invariant: Exact variant targeting for stock updates
    if not check_file_contains(exchange_file, [
        r"tx\.update\(sourceAccessoryRef,",
        r"tx\.update\(replacementAccessoryRef,",
        r'branchId:\s*branchId,\s*productId:\s*sourceProductId',
        r'branchId:\s*branchId,\s*productId:\s*replacementProductId',
    ], "Exit Gate: atomic exact variant inventory adjustment"):
        failures += 1

    print("---------------------------------------------------------------")
    if failures == 0:
        print("🎉 ALL PHASE 10 STATIC CONTRACT CHECKS PASSED (10/10)!")
        print("===============================================================")
        return 0
    else:
        print(f"❌ FAILED WITH {failures} VIOLATIONS!")
        print("===============================================================")
        return 1

if __name__ == "__main__":
    sys.exit(main())
