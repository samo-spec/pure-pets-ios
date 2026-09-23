#!/usr/bin/env python3
"""
Static verification script for Universal Cell Product Variant Indicator.
Tests property declarations, model mapping, UI rendering, and bilingual localization.
"""

import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
IOS_ROOT = os.path.dirname(SCRIPT_DIR)
PURE_PETS_DIR = os.path.join(IOS_ROOT, "Pure Pets")

def check_file_contains(filepath, patterns, description):
    if not os.path.exists(filepath):
        print(f"❌ FAIL: File not found: {filepath}")
        return False
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    
    missing = []
    for pattern in patterns:
        if not re.search(pattern, content):
            missing.append(pattern)
    
    if missing:
        print(f"❌ FAIL: {description}")
        for m in missing:
            print(f"   Missing pattern: {m}")
        return False
    else:
        print(f"✅ PASS: {description}")
        return True

def main():
    print("=" * 65)
    print("  UNIVERSAL CELL PRODUCT VARIANT INFO STATIC VERIFICATION")
    print("=" * 65)

    failures = 0

    # 1. PPUniversalCellViewModel.h declarations
    vm_h = os.path.join(PURE_PETS_DIR, "MainApp", "PetsAdsFiles", "PetsAdvertiseImagesAndCells", "PPUniversalCellViewModel.h")
    if not check_file_contains(vm_h, [
        r"@property\s*\([^)]*\)\s*BOOL\s+hasVariants;",
        r"@property\s*\([^)]*\)\s*NSString\s*\*variantInfoText;",
        r"@property\s*\([^)]*\)\s*NSString\s*\*variantInfoIconName;",
    ], "PPUniversalCellViewModel.h variant property declarations"):
        failures += 1

    # 2. PPUniversalCellViewModel.m variant logic
    vm_m = os.path.join(PURE_PETS_DIR, "MainApp", "PetsAdsFiles", "PetsAdvertiseImagesAndCells", "PPUniversalCellViewModel.m")
    if not check_file_contains(vm_m, [
        r"BOOL\s+hasVariants\s*=\s*NO;",
        r"accessory\.productFamilyId\.length\s*>\s*0",
        r"MultipleOptions",
        r"ColorsAvailableFormat",
        r"SizesAvailableFormat",
        r"OptionsAvailable",
        r"_hasVariants\s*=\s*hasVariants;",
        r"_variantInfoText\s*=\s*\[variantInfoText\s+copy\];",
    ], "PPUniversalCellViewModel.m variant calculation and localization"):
        failures += 1

    # 3. PPUniversalCellHelper.h and .m bridge methods
    helper_h = os.path.join(PURE_PETS_DIR, "MainApp", "PetsAdsFiles", "PetsAdvertiseImagesAndCells", "PPUniversalCellHelper.h")
    if not check_file_contains(helper_h, [
        r"\+\s*\(BOOL\)hasVariantsForViewModel:\(PPUniversalCellViewModel\s*\*\)viewModel;",
        r"\+\s*\(nullable\s+NSString\s*\*\(?\)variantInfoTextForViewModel:\(PPUniversalCellViewModel\s*\*\)viewModel;",
    ], "PPUniversalCellHelper.h variant bridge declarations"):
        failures += 1

    helper_m = os.path.join(PURE_PETS_DIR, "MainApp", "PetsAdsFiles", "PetsAdvertiseImagesAndCells", "PPUniversalCellHelper.m")
    if not check_file_contains(helper_m, [
        r"\+\s*\(BOOL\)hasVariantsForViewModel:\(PPUniversalCellViewModel\s*\*\)viewModel\s*\{",
        r"\+\s*\(NSString\s*\*\(?\)variantInfoTextForViewModel:\(PPUniversalCellViewModel\s*\*\)viewModel\s*\{",
    ], "PPUniversalCellHelper.m variant bridge implementations"):
        failures += 1

    # 4. PPUniversalCellSwiftUI.swift card model and bottomBadgesRow rendering
    swift_ui = os.path.join(PURE_PETS_DIR, "MainApp", "PetsAdsFiles", "PetsAdvertiseImagesAndCells", "PPUniversalCellSwiftUI.swift")
    if not check_file_contains(swift_ui, [
        r"public\s+var\s+hasVariants:\s*Bool",
        r"public\s+var\s+variantInfoText:\s*String\?",
        r"hasVariants:\s*viewModel\.hasVariants",
        r"variantInfoText:\s*viewModel\.variantInfoText",
        r"if\s+let\s+variantInfo\s*=\s*store\.model\.variantInfoText",
        r"PPUniversalPill\(",
    ], "PPUniversalCellSwiftUI.swift card model binding and bottomBadgesRow pill"):
        failures += 1

    # 5. Compatibility cards
    home_card = os.path.join(PURE_PETS_DIR, "MainApp", "ModrenAppVC", "SwiftUIHome", "Views", "HomeUniversalCard.swift")
    if not check_file_contains(home_card, [
        r"if\s+let\s+variantInfo\s*=\s*viewModel\.variantInfoText",
    ], "HomeUniversalCard.swift compatibility variant pill"):
        failures += 1

    market_compat = os.path.join(PURE_PETS_DIR, "MainApp", "ModrenAppVC", "PPDataView", "PPMarketplaceCompatibilityCard.swift")
    if not check_file_contains(market_compat, [
        r"if\s+let\s+variantInfo\s*=\s*viewModel\.variantInfoText",
    ], "PPMarketplaceCompatibilityCard.swift compatibility variant pill"):
        failures += 1

    # 6. Localization files
    ar_strings = os.path.join(PURE_PETS_DIR, "ar.lproj", "Localizable.strings")
    if not check_file_contains(ar_strings, [
        r'"MultipleOptions"\s*=\s*"خيارات متعددة";',
        r'"OptionsAvailable"\s*=\s*"خيارات متوفرة";',
        r'"ColorsAvailableFormat"\s*=\s*"%ld ألوان";',
        r'"SizesAvailableFormat"\s*=\s*"%ld مقاسات";',
    ], "Arabic Localizable.strings variant entries"):
        failures += 1

    en_strings = os.path.join(PURE_PETS_DIR, "en.lproj", "Localizable.strings")
    if not check_file_contains(en_strings, [
        r'"MultipleOptions"\s*=\s*"Multiple options";',
        r'"OptionsAvailable"\s*=\s*"Options available";',
        r'"ColorsAvailableFormat"\s*=\s*"%ld Colors";',
        r'"SizesAvailableFormat"\s*=\s*"%ld Sizes";',
    ], "English Localizable.strings variant entries"):
        failures += 1

    print("-" * 65)
    if failures == 0:
        print("  ALL 8/8 UNIVERSAL CELL VARIANT STATIC CHECKS PASSED ✅")
        print("=" * 65)
        sys.exit(0)
    else:
        print(f"  {failures} CHECK(S) FAILED ❌")
        print("=" * 65)
        sys.exit(1)

if __name__ == "__main__":
    main()
