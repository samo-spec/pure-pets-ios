#!/usr/bin/env python3
"""
Phase 12 Static Contract & Architecture Verification Test
Verifies that Pure Pets Performance & Resilience implementation satisfies:
1. productVariantFamily.js defines MAX_VARIANTS_PER_FAMILY = 40 (strictly within 500-write budget).
2. productOptionsDomain.js defines MAX_OPTIONS = 3 and MAX_VARIANTS = 40 (preventing combinatorial explosion).
3. PetAccessoryManager.m executes single document read for family resolution (zero N+1 query fanouts).
4. PetAccessoryManager.m handles deleted/released families gracefully without failing or blocking.
5. PPAccessoryViewerStore.swift enforces in-flight mutation safety locks during purchases.
6. PPAccessoryViewerStore.swift isolates quantity per-variant (resets to 1 on variant switch).
7. PPAccessoryViewerStore.swift implements non-blocking recovery with VoiceOver accessibility on fetch errors.
8. PPAccessoryViewerModels.swift conforms PPAccessoryViewerOptionDefinition to Identifiable, Equatable.
9. PPAccessoryViewerModels.swift conforms PPAccessoryViewerOptionValue to Identifiable, Equatable.
10. PPAccessoryViewerModels.swift conforms PPAccessoryViewerVariant to Identifiable, Equatable.
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
    print("  PHASE 12: PERFORMANCE & RESILIENCE STATIC VERIFICATION")
    print("===============================================================")
    failures = 0

    # 1. productVariantFamily.js MAX_VARIANTS_PER_FAMILY = 40
    family_js = os.path.join(INFRA_ROOT, "productVariantFamily.js")
    if not check_file_contains(family_js, [
        r"const MAX_VARIANTS_PER_FAMILY\s*=\s*40;",
    ], "productVariantFamily.js bounded variant limit"):
        failures += 1

    # 2. productOptionsDomain.js MAX_OPTIONS = 3 and MAX_VARIANTS = 40
    options_js = os.path.join(INFRA_ROOT, "productOptionsDomain.js")
    if not check_file_contains(options_js, [
        r"const MAX_OPTIONS\s*=\s*3;",
        r"const MAX_VARIANTS\s*=\s*40;",
    ], "productOptionsDomain.js axis and variant bounds"):
        failures += 1

    # 3. PetAccessoryManager.m single document read
    mgr_m = os.path.join(IOS_ROOT, "MainApp", "Accessories", "AccessFiles", "PetAccessoryManager.m")
    if not check_file_contains(mgr_m, [
        r"\+\s*\(void\)fetchProductFamilyWithID:\(NSString\s*\*\)familyID",
        r"\[\[\[db collectionWithPath:@\"ProductFamilies\"\] documentWithPath:cleanID\]",
        r"getDocumentWithCompletion:",
    ], "PetAccessoryManager.m single document family read (zero N+1)"):
        failures += 1

    # 4. PetAccessoryManager.m deleted/missing family tolerance
    if not check_file_contains(mgr_m, [
        r"completion\(doc\.exists \? doc\.data : nil, nil\);",
    ], "PetAccessoryManager.m missing family standalone fallback"):
        failures += 1

    # 5. PPAccessoryViewerStore.swift mutation locking
    store_swift = os.path.join(IOS_ROOT, "MainApp", "Accessories", "AccessFiles", "PPAccessoryViewerStore.swift")
    if not check_file_contains(store_swift, [
        r"guard cartPhase != \.processing, checkoutPhase != \.preparingCart else",
    ], "PPAccessoryViewerStore.swift in-flight mutation safety locks"):
        failures += 1

    # 6. PPAccessoryViewerStore.swift quantity reset on variant change
    if not check_file_contains(store_swift, [
        r"quantity = 1",
        r"preparedCheckoutCartQuantity = nil",
    ], "PPAccessoryViewerStore.swift per-variant quantity isolation"):
        failures += 1

    # 7. PPAccessoryViewerStore.swift non-blocking fetch error recovery
    if not check_file_contains(store_swift, [
        r"self\.switchingVariantProductId = nil",
        r"UIAccessibility\.post\(",
    ], "PPAccessoryViewerStore.swift accessible non-blocking error recovery"):
        failures += 1

    # 8. PPAccessoryViewerOptionDefinition Identifiable, Equatable
    models_swift = os.path.join(IOS_ROOT, "MainApp", "Accessories", "AccessFiles", "PPAccessoryViewerModels.swift")
    if not check_file_contains(models_swift, [
        r"struct PPAccessoryViewerOptionDefinition:\s*Identifiable,\s*Equatable",
    ], "PPAccessoryViewerOptionDefinition Identifiable conformance"):
        failures += 1

    # 9. PPAccessoryViewerOptionValue Identifiable, Equatable
    if not check_file_contains(models_swift, [
        r"struct PPAccessoryViewerOptionValue:\s*Identifiable,\s*Equatable",
    ], "PPAccessoryViewerOptionValue Identifiable conformance"):
        failures += 1

    # 10. PPAccessoryViewerVariant Identifiable, Equatable
    if not check_file_contains(models_swift, [
        r"struct PPAccessoryViewerVariant:\s*Identifiable,\s*Equatable",
    ], "PPAccessoryViewerVariant Identifiable conformance"):
        failures += 1

    print("\n---------------------------------------------------------------")
    if failures == 0:
        print("  ALL 10/10 PHASE 12 STATIC CHECKS PASSED")
        print("===============================================================")
        return 0
    else:
        print(f"  ❌ {failures} CHECKS FAILED")
        print("===============================================================")
        return 1

if __name__ == "__main__":
    sys.exit(main())
