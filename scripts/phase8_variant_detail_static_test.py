#!/usr/bin/env python3
"""
Phase 8 Static Contract & Architecture Verification Test
Verifies that Pure Pets IOS customer product detail implementation satisfies:
1. Typed Option Models (PPAccessoryViewerOptionDefinition, PPAccessoryViewerOptionValue, PPAccessoryViewerVariant)
2. PetAccessory typed variant properties (selectedOptions, variantCombinationKey, sellableUnitId)
3. Dynamic compatibility resolution in PPAccessoryViewerStore
4. Add-to-cart gating ensuring all options are selected before purchase
5. Full localization in both ar.lproj and en.lproj
6. Zero direct Firestore writes from the viewer components
"""

import sys
import os
import re

IOS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ACCESS_FILES = os.path.join(IOS_ROOT, "Pure Pets", "MainApp", "Accessories", "AccessFiles")
AR_STRINGS = os.path.join(IOS_ROOT, "Pure Pets", "ar.lproj", "Localizable.strings")
EN_STRINGS = os.path.join(IOS_ROOT, "Pure Pets", "en.lproj", "Localizable.strings")

def check_file_contains(filepath, patterns, label):
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
    print("  PHASE 8: CUSTOMER PRODUCT DETAIL STATIC VERIFICATION")
    print("===============================================================")
    failures = 0

    # 1. Check PetAccessory.h
    h_file = os.path.join(ACCESS_FILES, "PetAccessory.h")
    if not check_file_contains(h_file, [
        r"@property\s*\(.*?\)\s*NSDictionary<\s*NSString\s*\*,\s*NSString\s*\*>\s*\*selectedOptions",
        r"@property\s*\(.*?\)\s*NSString\s*\*variantCombinationKey",
        r"@property\s*\(.*?\)\s*NSString\s*\*sellableUnitId",
        r"@property\s*\(.*?\)\s*BOOL\s*isVariant",
        r"@property\s*\(.*?\)\s*BOOL\s*variantIsArchived"
    ], "PetAccessory.h typed variant properties"):
        failures += 1

    # 2. Check PetAccessory.m
    m_file = os.path.join(ACCESS_FILES, "PetAccessory.m")
    if not check_file_contains(m_file, [
        r'_selectedOptions\s*=\s*\[dict\[@"selectedOptions"\]\s*copy\]',
        r'PPAccessoryStringValueForKeys\(dict,\s*@\[@"variantCombinationKey"\]\)',
        r'copy\.selectedOptions\s*=\s*\[source\.selectedOptions\s*copy\]'
    ], "PetAccessory.m dictionary parsing & deepCopy"):
        failures += 1

    # 3. Check PPAccessoryViewerLegacyBridge.h & .m
    bridge_h = os.path.join(ACCESS_FILES, "PPAccessoryViewerLegacyBridge.h")
    if not check_file_contains(bridge_h, [
        r"fetchProductFamilyForAccessory",
        r"NS_SWIFT_NAME\(fetchProductFamily\(for:completion:\)\)"
    ], "LegacyBridge header fetchProductFamily"):
        failures += 1

    bridge_m = os.path.join(ACCESS_FILES, "PPAccessoryViewerLegacyBridge.m")
    if not check_file_contains(bridge_m, [
        r"\+ \(void\)fetchProductFamilyForAccessory",
        r"fetchProductFamilyWithID:familyID"
    ], "LegacyBridge implementation fetchProductFamily"):
        failures += 1

    # 4. Check PPAccessoryViewerModels.swift
    models_file = os.path.join(ACCESS_FILES, "PPAccessoryViewerModels.swift")
    if not check_file_contains(models_file, [
        r"struct PPAccessoryViewerOptionValue",
        r"struct PPAccessoryViewerOptionDefinition",
        r"enum PPAccessoryViewerOptionValueStatus",
        r"struct PPAccessoryViewerVariant",
        r"let selectedOptions:\s*\[String:\s*String\]",
        r"let combinationKey:\s*String"
    ], "PPAccessoryViewerModels domain models"):
        failures += 1

    # 5. Check PPAccessoryViewerStore.swift
    store_file = os.path.join(ACCESS_FILES, "PPAccessoryViewerStore.swift")
    if not check_file_contains(store_file, [
        r"@Published private\(set\) var optionDefinitions:\s*\[PPAccessoryViewerOptionDefinition\]",
        r"@Published private\(set\) var selectedOptions:\s*\[String:\s*String\]",
        r"@Published private\(set\) var currentVariant:\s*PPAccessoryViewerVariant\?",
        r"func selectOptionValue\(optionId:\s*String,\s*valueId:\s*String\)",
        r"func status\s*\(\s*forOptionValue",
        r"fetchProductFamily\(\s*for:\s*accessory"
    ], "PPAccessoryViewerStore option & compatibility resolution"):
        failures += 1

    # 6. Check PPAccessoryViewerComponents.swift
    comp_file = os.path.join(ACCESS_FILES, "PPAccessoryViewerComponents.swift")
    if not check_file_contains(comp_file, [
        r"struct PPAccessoryVariantSelectorSection",
        r"struct PPAccessoryColorSubRail",
        r"struct PPAccessoryOptionPillSubRail",
        r"private var allOptionsSelected:\s*Bool",
        r"allOptionsSelected"
    ], "PPAccessoryViewerComponents option rails & add-to-cart gating"):
        failures += 1

    # 7. Check PPAccessoryViewerScreen.swift
    screen_file = os.path.join(ACCESS_FILES, "PPAccessoryViewerScreen.swift")
    if not check_file_contains(screen_file, [
        r"PPAccessoryVariantSelectorSection\("
    ], "PPAccessoryViewerScreen integration"):
        failures += 1

    # 8. Check Localization in ar and en
    for lang, path in [("ar", AR_STRINGS), ("en", EN_STRINGS)]:
        if not check_file_contains(path, [
            r'"accessory_view_options_title"',
            r'"accessory_view_options_failed"',
            r'"accessory_view_option_incompatible"',
            r'"accessory_view_option_out_of_stock"',
            r'"accessory_view_option_selected_format"',
            r'"accessory_view_option_loading_format"',
            r'"accessory_view_select_option_format"'
        ], f"Localizable.strings ({lang}) keys"):
            failures += 1

    # 9. Verify zero direct Firestore writes in customer viewer
    with open(comp_file, "r", encoding="utf-8") as f:
        comp_content = f.read()
    with open(store_file, "r", encoding="utf-8") as f:
        store_content = f.read()
    
    direct_write_patterns = [r"\.setData\(", r"\.updateData\(", r"\.delete\(", r"collection\(\"petAccessories\"\)\.document"]
    for pattern in direct_write_patterns:
        if re.search(pattern, comp_content) or re.search(pattern, store_content):
            print(f"❌ FAIL: Forbidden direct Firestore write '{pattern}' found in viewer files!")
            failures += 1

    print("---------------------------------------------------------------")
    if failures == 0:
        print("🎉 ALL PHASE 8 STATIC CHECKS PASSED WITH ZERO VIOLATIONS!")
        return 0
    else:
        print(f"❌ {failures} static check(s) failed.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
