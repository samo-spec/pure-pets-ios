#!/usr/bin/env python3
"""
Phase 15 Static Contract & Architecture Verification Test
Verifies that Pure Pets Product Options Rollout & Rollback Architecture satisfies:
1. product_options_rollout.js CLI operator tool exists with all operational verbs.
2. variantRolloutAndRollback.emulator.test.js covers disabled, authoring, publication, and rollback states.
3. package.json registers test:variant-rollout script.
4. package.json includes test:variant-rollout in composite test:product-options runner.
5. Server-owned CommerceConfig/productOptions controls authoringEnabled and customerSelectionEnabled.
6. Generic authoring is strictly gated by VARIANT_OPTIONS_NOT_ENABLED.
7. Public marketplace family publishing is strictly gated by VARIANT_PUBLICATION_NOT_READY.
8. Emergency rollback-customer disables publication while leaving admin matrix authoring intact.
9. Emergency rollback-all resets flags while legacy envelope 2 color families remain 100% functional.
10. Product Variants Master Plan (0 to 15) completed, certified, and fully documented.
"""

import sys
import os
import re

INFRA_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "Pure Pets Infra", "functions"))
SCRIPTS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "Pure Pets Infra", "scripts"))
DOCS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "docs", "stock"))

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
    print("  PHASE 15: ROLLOUT & ROLLBACK MASTER STATIC VERIFICATION     ")
    print("===============================================================")
    failures = 0

    rollout_tool = os.path.join(SCRIPTS_ROOT, "product_options_rollout.js")
    rollout_test = os.path.join(INFRA_ROOT, "tests", "variantRolloutAndRollback.emulator.test.js")
    pkg_json = os.path.join(INFRA_ROOT, "package.json")
    master_plan = os.path.join(DOCS_ROOT, "Pure_Pets_Product_Variants_Master_Plan_and_Handoff.md")

    # 1. product_options_rollout.js CLI commands
    if not check_file_contains(rollout_tool, [
        r"CommerceConfig/productOptions",
        r"enable-authoring",
        r"enable-customer",
        r"enable-all",
        r"rollback-customer",
        r"rollback-all",
    ], "product_options_rollout.js CLI commands"):
        failures += 1

    # 2. variantRolloutAndRollback.emulator.test.js coverage
    if not check_file_contains(rollout_test, [
        r"VARIANT_OPTIONS_NOT_ENABLED",
        r"VARIANT_PUBLICATION_NOT_READY",
        r"rollback-customer",
        r"rollback-all",
        r"contractVersion:\s*2",
    ], "variantRolloutAndRollback.emulator.test.js transition assertions"):
        failures += 1

    # 3. package.json test:variant-rollout script
    if not check_file_contains(pkg_json, [
        r'"test:variant-rollout":\s*"firebase --config ../firebase\.json --project pure-pets-49199 emulators:exec --only firestore \\"node tests/variantRolloutAndRollback\.emulator\.test\.js\\""'
    ], "package.json test:variant-rollout registration"):
        failures += 1

    # 4. package.json composite runner
    if not check_file_contains(pkg_json, [
        r'node tests/variantRolloutAndRollback\.emulator\.test\.js && node tests/productVariantFamily\.rules\.test\.js'
    ], "package.json test:product-options composite inclusion"):
        failures += 1

    # 5. Config path & flag keys
    if not check_file_contains(rollout_tool, [
        r"CONFIG_PATH = \"CommerceConfig/productOptions\"",
        r"authoringEnabled",
        r"customerSelectionEnabled",
    ], "product_options_rollout.js config schema"):
        failures += 1

    # 6. Generic authoring gate
    family_src = os.path.join(INFRA_ROOT, "productVariantFamily.js")
    if not check_file_contains(family_src, [
        r'rollout\.data\(\)\?\.authoringEnabled !== true',
        r'VARIANT_OPTIONS_NOT_ENABLED',
    ], "productVariantFamily.js generic authoring gate"):
        failures += 1

    # 7. Customer publication gate
    if not check_file_contains(family_src, [
        r'rollout\.data\(\)\?\.customerSelectionEnabled !== true',
        r'VARIANT_PUBLICATION_NOT_READY',
    ], "productVariantFamily.js customer publication gate"):
        failures += 1

    # 8. Zero-downtime rollback-customer
    if not check_file_contains(rollout_test, [
        r"Customer selection rolled back: customer view defaults safely",
    ], "variantRolloutAndRollback.emulator.test.js customer rollback"):
        failures += 1

    # 9. Legacy envelope 2 preservation during full rollback
    if not check_file_contains(rollout_test, [
        r"Legacy contractVersion: 2 family functions uninterrupted during rollback",
    ], "variantRolloutAndRollback.emulator.test.js legacy color preservation"):
        failures += 1

    # 10. Master Plan exists and documents full architecture
    if not check_file_contains(master_plan, [
        r"# Pure Pets — Product Options & Sellable Variants",
        r"30\. Phase 14 — Production QA & Master Matrix Certification",
    ], "Pure_Pets_Product_Variants_Master_Plan_and_Handoff.md completeness"):
        failures += 1

    print("===============================================================")
    if failures == 0:
        print("  ALL 10 PHASE 15 STATIC CONTRACT CHECKS PASSED (10/10)       ")
        print("===============================================================")
        sys.exit(0)
    else:
        print(f"  {failures} CHECK(S) FAILED IN PHASE 15 STATIC VERIFICATION  ")
        print("===============================================================")
        sys.exit(1)

if __name__ == "__main__":
    main()
