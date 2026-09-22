#!/usr/bin/env python3
"""
Phase 13 Static Contract & Architecture Verification Test
Verifies that Pure Pets Accessibility and Arabic/RTL implementation satisfies:
1. PPAccessoryViewerComponents.swift integrates @Environment(\\.accessibilityReduceMotion).
2. PPAccessoryViewerComponents.swift adapts to @Environment(\\.dynamicTypeSize) with accessibility stacking.
3. PPAccessoryViewerComponents.swift includes comprehensive accessibility labels with status.
4. PPAccessoryViewerComponents.swift enforces >= 44pt touch targets on interactive option controls.
5. PPAccessoryViewerComponents.swift applies .accessibilityAddTraits([.isButton, .isSelected]).
6. PPCartTableCell.m provides localized VoiceOver accessibilityLabel on variantOptionsLabel.
7. PPCartTableCell.m uses natural text alignment and RTL-safe layout.
8. PetAccessory.m formats price ranges with Language.isRTL directionality checks.
9. Localizable.strings in both ar.lproj and en.lproj provide accessory_view_options_title.
10. PPAccessoryVariantMatrixView.swift in Admin UI integrates Dynamic Type and Reduce Motion environments.
"""

import sys
import os
import re

IOS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Pure Pets"))
ADMIN_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "Pure Pets Admin", "PurePetsAdmin"))

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
    print("  PHASE 13: ACCESSIBILITY + ARABIC/RTL STATIC VERIFICATION    ")
    print("===============================================================")
    failures = 0

    # 1. PPAccessoryViewerComponents.swift reduce motion
    components_swift = os.path.join(IOS_ROOT, "MainApp", "Accessories", "AccessFiles", "PPAccessoryViewerComponents.swift")
    if not check_file_contains(components_swift, [
        r"@Environment\(\\.accessibilityReduceMotion\)\s*private\s*var\s*reduceMotion",
    ], "PPAccessoryViewerComponents.swift Reduce Motion support"):
        failures += 1

    # 2. PPAccessoryViewerComponents.swift dynamic type accessibility size adaptation
    if not check_file_contains(components_swift, [
        r"@Environment\(\\.dynamicTypeSize\)\s*private\s*var\s*dynamicTypeSize",
        r"if\s*dynamicTypeSize\.isAccessibilitySize\s*\{",
    ], "PPAccessoryViewerComponents.swift Dynamic Type AX size vertical stacking"):
        failures += 1

    # 3. PPAccessoryViewerComponents.swift option value accessibility label with status
    if not check_file_contains(components_swift, [
        r"\.accessibilityLabel\(accessibilityLabel\(for:\s*value,\s*status:\s*status\)\)",
        r"case\s*\.selected:",
        r"case\s*\.outOfStock:",
        r"case\s*\.incompatible:",
    ], "PPAccessoryViewerComponents.swift option value status accessibility labels"):
        failures += 1

    # 4. PPAccessoryViewerComponents.swift touch target minimums (>= 44pt)
    if not check_file_contains(components_swift, [
        r"\.frame\(minHeight:\s*44\)",
    ], "PPAccessoryViewerComponents.swift touch target minimum height"):
        failures += 1

    # 5. PPAccessoryViewerComponents.swift button and selection traits
    if not check_file_contains(components_swift, [
        r"\.accessibilityAddTraits\(isSelected\s*\?\s*\[\.isButton,\s*\.isSelected\]\s*:\s*\.isButton\)",
    ], "PPAccessoryViewerComponents.swift accessibility selection traits"):
        failures += 1

    # 6. PPCartTableCell.m VoiceOver accessibilityLabel
    cart_cell_m = os.path.join(IOS_ROOT, "MainApp", "PAYMENTS", "CartAndOrdersFiles", "PPCartTableCell.m")
    if not check_file_contains(cart_cell_m, [
        r"self\.variantOptionsLabel\.accessibilityLabel\s*=\s*\[NSString\s*stringWithFormat:@\"%@:\s*%@\",\s*kLang\(@\"accessory_view_options_title\"\),\s*item\.optionsSummary\];",
    ], "PPCartTableCell.m VoiceOver accessibility label"):
        failures += 1

    # 7. PPCartTableCell.m natural alignment
    if not check_file_contains(cart_cell_m, [
        r"variantOptionsLabel\.textAlignment\s*=\s*NSTextAlignmentNatural;",
    ], "PPCartTableCell.m natural text alignment for RTL safety"):
        failures += 1

    # 8. PetAccessory.m price range formatting with RTL safety
    accessory_m = os.path.join(IOS_ROOT, "MainApp", "Accessories", "AccessFiles", "PetAccessory.m")
    if not check_file_contains(accessory_m, [
        r"if\s*\(Language\.isRTL\)\s*\{",
        r"return\s*\[NSString\s*stringWithFormat:@\"من\s*%@\s*إلى\s*%@\",\s*minFormatted,\s*maxFormatted\];",
        r"return\s*\[NSString\s*stringWithFormat:@\"%@\s*-\s*%@\",\s*minFormatted,\s*maxFormatted\];",
    ], "PetAccessory.m RTL-aware formatted price range"):
        failures += 1

    # 9. Localizable.strings in ar and en
    ar_strings = os.path.join(IOS_ROOT, "ar.lproj", "Localizable.strings")
    en_strings = os.path.join(IOS_ROOT, "en.lproj", "Localizable.strings")
    if not check_file_contains(ar_strings, [
        r'\"accessory_view_options_title\"\s*=\s*\"خيارات المنتج\";',
    ], "ar.lproj Localizable.strings options title"):
        failures += 1
    if not check_file_contains(en_strings, [
        r'\"accessory_view_options_title\"\s*=\s*\"Product Options\";',
    ], "en.lproj Localizable.strings options title"):
        failures += 1

    # 10. Admin UI Variant Matrix accessibility environments
    admin_matrix_swift = os.path.join(ADMIN_ROOT, "AccessorySection", "PPAccessoryVariantMatrixView.swift")
    if not check_file_contains(admin_matrix_swift, [
        r"@Environment\(\\.dynamicTypeSize\)\s*private\s*var\s*dynamicTypeSize",
        r"@Environment\(\\.accessibilityReduceMotion\)\s*private\s*var\s*reduceMotion",
    ], "Admin PPAccessoryVariantMatrixView.swift accessibility environments"):
        failures += 1

    print("\n---------------------------------------------------------------")
    if failures == 0:
        print("  ALL 10/10 PHASE 13 STATIC CHECKS PASSED")
        print("===============================================================")
        return 0
    else:
        print(f"  ❌ {failures} CHECKS FAILED")
        print("===============================================================")
        return 1

if __name__ == "__main__":
    sys.exit(main())
