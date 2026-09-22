#!/usr/bin/env python3
"""
Phase 11 Static Contract & Architecture Verification Test
Verifies that Pure Pets Marketplace, Search & Filters implementation satisfies:
1. PetAccessory.h declares minPrice, maxPrice, hasVariablePrice, totalAvailableStock,
   hasInStockVariants, availableColors, availableSizes, searchTokens.
2. PetAccessory.h declares + (NSString *)formattedPriceRangeForAccessory:(PetAccessory *)accessory.
3. PetAccessory.m deserializes and deep-copies all Phase 11 aggregations.
4. PetAccessory.m implements formattedPriceRangeForAccessory with bilingual RTL/LTR support.
5. PPUniversalCellViewModel.m displays variable price ranges via formattedPriceRangeForAccessory.
6. PPUniversalCellViewModel.m calculates availability using aggregated family stock & hasInStockVariants.
7. SearchManager.m checks accessory searchTokens for variant-level discoverability.
8. productVariantFamily.js computes minPrice, maxPrice, hasVariablePrice, totalAvailableStock, hasInStockVariants.
9. productVariantFamily.js aggregates availableColors, availableSizes, and searchTokens across active variants.
10. productVariantFamily.js stamps aggregations onto familyDocument and public default variant document atomically.
"""

import sys
import os
import re

IOS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Pure Pets"))
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
    print("  PHASE 11: MARKETPLACE, SEARCH & FILTERS STATIC VERIFICATION")
    print("===============================================================")
    failures = 0

    # 1. PetAccessory.h properties
    pet_accessory_h = os.path.join(IOS_ROOT, "MainApp", "Accessories", "AccessFiles", "PetAccessory.h")
    if not check_file_contains(pet_accessory_h, [
        r"@property\s*\(nonatomic,\s*strong,\s*nullable\)\s*NSNumber\s*\*minPrice;",
        r"@property\s*\(nonatomic,\s*strong,\s*nullable\)\s*NSNumber\s*\*maxPrice;",
        r"@property\s*\(nonatomic,\s*assign\)\s*BOOL\s*hasVariablePrice;",
        r"@property\s*\(nonatomic,\s*assign\)\s*NSInteger\s*totalAvailableStock;",
        r"@property\s*\(nonatomic,\s*assign\)\s*BOOL\s*hasInStockVariants;",
        r"@property\s*\(nonatomic,\s*strong,\s*nullable\)\s*NSArray<NSString\s*\*>\s*\*availableColors;",
        r"@property\s*\(nonatomic,\s*strong,\s*nullable\)\s*NSArray<NSString\s*\*>\s*\*availableSizes;",
        r"@property\s*\(nonatomic,\s*strong,\s*nullable\)\s*NSArray<NSString\s*\*>\s*\*searchTokens;",
    ], "PetAccessory.h marketplace aggregation properties"):
        failures += 1

    # 2. PetAccessory.h method
    if not check_file_contains(pet_accessory_h, [
        r"\+\s*\(NSString\s*\*\)formattedPriceRangeForAccessory:\(PetAccessory\s*\*\)accessory;",
    ], "PetAccessory.h formattedPriceRangeForAccessory declaration"):
        failures += 1

    # 3. PetAccessory.m deserialization and copying
    pet_accessory_m = os.path.join(IOS_ROOT, "MainApp", "Accessories", "AccessFiles", "PetAccessory.m")
    if not check_file_contains(pet_accessory_m, [
        r"_minPrice\s*=\s*@\(\[dict\[@\"minPrice\"\]\s*doubleValue\]\);",
        r"_maxPrice\s*=\s*@\(\[dict\[@\"maxPrice\"\]\s*doubleValue\]\);",
        r"_hasVariablePrice\s*=\s*\[dict\[@\"hasVariablePrice\"\]\s*boolValue\];",
        r"_totalAvailableStock\s*=\s*\[dict\[@\"totalAvailableStock\"\]\s*integerValue\];",
        r"_hasInStockVariants\s*=\s*\[dict\[@\"hasInStockVariants\"\]\s*boolValue\];",
        r"copy\.minPrice\s*=\s*\[source\.minPrice\s*copy\];",
        r"copy\.maxPrice\s*=\s*\[source\.maxPrice\s*copy\];",
        r"copy\.hasVariablePrice\s*=\s*source\.hasVariablePrice;",
        r"copy\.totalAvailableStock\s*=\s*source\.totalAvailableStock;",
        r"copy\.hasInStockVariants\s*=\s*source\.hasInStockVariants;",
    ], "PetAccessory.m parsing and deep-copying"):
        failures += 1

    # 4. PetAccessory.m formattedPriceRangeForAccessory implementation
    if not check_file_contains(pet_accessory_m, [
        r"\+\s*\(NSString\s*\*\)formattedPriceRangeForAccessory:\(PetAccessory\s*\*\)accessory\s*\{",
        r"if\s*\(accessory\.hasVariablePrice",
        r"Language\.isRTL",
    ], "PetAccessory.m formattedPriceRangeForAccessory implementation"):
        failures += 1

    # 5. PPUniversalCellViewModel.m price display
    cell_vm_m = os.path.join(IOS_ROOT, "MainApp", "PetsAdsFiles", "PetsAdvertiseImagesAndCells", "PPUniversalCellViewModel.m")
    if not check_file_contains(cell_vm_m, [
        r"if\s*\(accessory\.hasVariablePrice\)\s*\{",
        r"_priceText\s*=\s*\[PetAccessory\s*formattedPriceRangeForAccessory:accessory\]",
    ], "PPUniversalCellViewModel.m priceText variable price formatting"):
        failures += 1

    # 6. PPUniversalCellViewModel.m stock availability aggregation
    if not check_file_contains(cell_vm_m, [
        r"accessory\.totalAvailableStock",
        r"accessory\.hasInStockVariants",
    ], "PPUniversalCellViewModel.m aggregated availability handling"):
        failures += 1

    # 7. SearchManager.m searchTokens matching
    search_mgr_m = os.path.join(IOS_ROOT, "MainApp", "Search Controllers", "SearchManager.m")
    if not check_file_contains(search_mgr_m, [
        r"a\.searchTokens\.count\s*>\s*0",
        r"for\s*\(NSString\s*\*tok\s*in\s*a\.searchTokens\)",
    ], "SearchManager.m searchTokens discovery matching"):
        failures += 1

    # 8. productVariantFamily.js price & stock aggregation
    family_js = os.path.join(INFRA_ROOT, "productVariantFamily.js")
    if not check_file_contains(family_js, [
        r"const hasVariablePrice = minPrice > 0 && maxPrice > 0 && Math\.abs\(maxPrice - minPrice\) > 0\.01;",
        r"const hasInStockVariants = totalAvailableStock > 0;",
    ], "productVariantFamily.js price and stock aggregations"):
        failures += 1

    # 9. productVariantFamily.js facets and search tokens
    if not check_file_contains(family_js, [
        r"availableColors:\s*Array\.from\(availableColors\)",
        r"availableSizes:\s*Array\.from\(availableSizes\)",
        r"searchTokens:\s*Array\.from\(searchTokens\)",
    ], "productVariantFamily.js facets and search tokens"):
        failures += 1

    # 10. productVariantFamily.js default variant stamping
    if not check_file_contains(family_js, [
        r"\.\.\.\(isDefault\s*\?\s*\{",
        r"minPrice,",
        r"maxPrice,",
        r"hasVariablePrice,",
        r"totalAvailableStock,",
        r"hasInStockVariants,",
        r"searchTokens:\s*Array\.from\(searchTokens\),",
    ], "productVariantFamily.js atomic default variant stamping"):
        failures += 1

    print("\n---------------------------------------------------------------")
    if failures == 0:
        print("  ALL 10/10 PHASE 11 STATIC CHECKS PASSED")
        print("===============================================================")
        return 0
    else:
        print(f"  ❌ {failures} CHECKS FAILED")
        print("===============================================================")
        return 1

if __name__ == "__main__":
    sys.exit(main())
