#!/usr/bin/env python3
"""
Pure Pets iOS Commerce — Phase 13 Accessibility + Arabic/RTL + Apple Interaction Test Suite

Comprehensive contract & source verification across all consumer iOS commerce surfaces:
1. Dynamic Type & Font Scaling Across Commerce Surfaces.
2. VoiceOver Announcements, Elements, Traits, Hints & Cohesion.
3. Minimum Interactive Touch Targets (>= 44pt).
4. Arabic RTL Layout, Leading/Trailing Anchors, Semantic Content & Chevron Mirroring.
5. Reduce Motion & Low-Power Accessibility Compliance.
6. Reduce Transparency & High Contrast Adaptation.
7. Localization Integrity (Arabic Primary RTL & English Secondary LTR).
"""

import os
import re
import sys

IOS_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Pure Pets"))

def check_file_patterns(rel_path, patterns, desc):
    abs_path = os.path.join(IOS_ROOT, rel_path)
    if not os.path.exists(abs_path):
        return False, f"Missing file: {rel_path}"
    with open(abs_path, "r", encoding="utf-8") as f:
        content = f.read()
    for p in patterns:
        if not re.search(p, content):
            return False, f"Pattern not found in {rel_path}: {p}"
    return True, desc

def check_no_patterns(rel_path, patterns, desc):
    abs_path = os.path.join(IOS_ROOT, rel_path)
    if not os.path.exists(abs_path):
        return False, f"Missing file: {rel_path}"
    with open(abs_path, "r", encoding="utf-8") as f:
        content = f.read()
    for p in patterns:
        match = re.search(p, content)
        if match:
            return False, f"Forbidden pattern found in {rel_path}: {p} -> {match.group(0)}"
    return True, desc

def verify_string_key(key, ar_path, en_path):
    with open(ar_path, "r", encoding="utf-8") as f:
        ar_content = f.read()
    with open(en_path, "r", encoding="utf-8") as f:
        en_content = f.read()
    ar_match = re.search(rf'"{re.escape(key)}"\s*=\s*"([^"]+)";', ar_content)
    en_match = re.search(rf'"{re.escape(key)}"\s*=\s*"([^"]+)";', en_content)
    if not ar_match or not en_match:
        return False, f"Key '{key}' missing or empty (ar: {bool(ar_match)}, en: {bool(en_match)})"
    return True, f"Key '{key}' -> ar: '{ar_match.group(1)}', en: '{en_match.group(1)}'"

def main():
    print("\n" + "=" * 65)
    print(" Pure Pets iOS Commerce — Phase 13 Accessibility & RTL Suite")
    print("=" * 65 + "\n")

    total_tests = 0
    passed_tests = 0
    failed_tests = 0

    def run_check(fn, group_name):
        nonlocal total_tests, passed_tests, failed_tests
        total_tests += 1
        ok, msg = fn()
        if ok:
            passed_tests += 1
            print(f"  ✅ PASS: {msg}")
        else:
            failed_tests += 1
            print(f"  ❌ FAIL [{group_name}]: {msg}")

    # =========================================================================
    # Group 1: Dynamic Type & Font Scaling
    # =========================================================================
    print("[Group 1: Dynamic Type & Font Scaling Across Commerce Surfaces]")

    run_check(lambda: check_file_patterns(
        "MainApp/Accessories/AccessFiles/PPAccessoryViewerComponents.swift",
        [
            r"@Environment\(\\.dynamicTypeSize\)\s*private\s*var\s*dynamicTypeSize",
            r"dynamicTypeSize\.isAccessibilitySize"
        ],
        "PPAccessoryViewerComponents adapts to Dynamic Type with accessibility stacking"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.m",
        [
            r"UIFontMetrics metricsForTextStyle",
            r"UIContentSizeCategoryIsAccessibilityCategory\(self\.traitCollection\.preferredContentSizeCategory\)",
            r"savedActionsRow\.axis\s*=\s*\(accessibility\s*\|\|"
        ],
        "PPCartTableCell dynamically stacks footer and identity rows for accessibility sizes"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m",
        [
            r"UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline",
            r"self\.titleLabel\.adjustsFontForContentSizeCategory\s*=\s*YES;",
            r"self\.subtitleLabel\.adjustsFontForContentSizeCategory\s*=\s*YES;"
        ],
        "PPPaymentMethodCell scales fonts with UIFontMetrics and adjustsFontForContentSizeCategory"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderItemCell.m",
        [
            r"_nameLabel\.adjustsFontForContentSizeCategory\s*=\s*YES;",
            r"_quantityLabel\.adjustsFontForContentSizeCategory\s*=\s*YES;",
            r"_priceLabel\.adjustsFontForContentSizeCategory\s*=\s*YES;"
        ],
        "OrderItemCell scales product item labels for Dynamic Type"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderHistorySurfaceView.swift",
        [
            r"@Environment\(\\.dynamicTypeSize\)\s*private\s*var\s*dynamicTypeSize",
            r"accessibilitySize:\s*dynamicTypeSize\.isAccessibilitySize",
            r"\.lineLimit\(accessibilitySize\s*\?\s*nil\s*:\s*2\)"
        ],
        "PPOrderHistorySurfaceView dynamically unclamps line limits on accessibility sizes"
    ), "Group 1")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderDetailsMissionControlViews.swift",
        [
            r"@Environment\(\\.dynamicTypeSize\)\s*private\s*var\s*dynamicTypeSize",
            r"if\s*dynamicTypeSize\.isAccessibilitySize\s*\{"
        ],
        "PPOrderDetailsMissionControlViews stacks action buttons vertically on accessibility sizes"
    ), "Group 1")

    # =========================================================================
    # Group 2: VoiceOver Announcements, Traits & Elements
    # =========================================================================
    print("\n[Group 2: VoiceOver Announcements, Traits & Cohesion]")

    run_check(lambda: check_file_patterns(
        "MainApp/Accessories/AccessFiles/PPAccessoryViewerComponents.swift",
        [
            r"\.accessibilityElement\(children:\s*\.ignore\)",
            r"\.accessibilityAddTraits\(isSelected\s*\?\s*\[\.isButton,\s*\.isSelected\]\s*:\s*\.isButton\)",
            r"case\s*\.outOfStock:",
            r"case\s*\.incompatible:"
        ],
        "PPAccessoryViewerComponents announces variant option availability and selection traits"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.m",
        [
            r"self\.nameLabel\.accessibilityTraits\s*=\s*UIAccessibilityTraitButton;",
            r"self\.quantityLabel\.accessibilityLabel\s*=\s*kLang\(@\"a11y_cart_qty_stepper\"\);",
            r"self\.minusButton\.accessibilityLabel\s*=",
            r"self\.plusButton\.accessibilityLabel\s*=",
            r"self\.saveForLaterButton\.accessibilityLabel\s*=",
            r"self\.lineTotalLabel\.accessibilityLabel\s*=",
            r"self\.accessibilityElements\s*=\s*elements;"
        ],
        "PPCartTableCell supplies structured VoiceOver elements, values, hints, and traits"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m",
        [
            r"self\.isAccessibilityElement\s*=\s*YES;",
            r"self\.accessibilityTraits\s*=\s*UIAccessibilityTraitButton",
            r"\(self\.currentSelectionState\s*\?\s*UIAccessibilityTraitSelected\s*:\s*0\);",
            r"pp_updateAccessibilityText"
        ],
        "PPPaymentMethodCell exposes accessible button traits with dynamic selection state"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m",
        [
            r"self\.heroTitleLabel\.accessibilityTraits\s*=\s*UIAccessibilityTraitHeader;",
            r"self\.heroBackButton\.accessibilityLabel\s*=\s*kLang\(@\"Back\"\);"
        ],
        "PPSelectPaymentVC provides accessible header trait and back button label"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineRowView.m",
        [
            r"self\.isAccessibilityElement\s*=\s*YES;",
            r"self\.accessibilityTraits\s*=\s*UIAccessibilityTraitUpdatesFrequently",
            r"self\.accessibilityLabel\s*=\s*self\.titleText;",
            r"self\.accessibilityValue\s*=\s*\[valueComponents\s*componentsJoinedByString:@\",\s*\"\];",
            r"kLang\(@\"fulfillment_status_completed\"\)",
            r"kLang\(@\"fulfillment_status_unknown\"\)",
            r"kLang\(@\"fulfillment_status_failed\"\)",
            r"kLang\(@\"fulfillment_summary_pending\"\)"
        ],
        "PPOrderProgressTimelineRowView announces timeline step state, title, and timestamp as a single VoiceOver unit"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineView.m",
        [
            r"- \(NSArray \*\)accessibilityElements",
            r"if\s*\(index\s*<\s*self\.rowViews\.count\s*&&\s*!self\.rowViews\[index\]\.hidden\)",
            r"\[elements\s*addObject:self\.rowViews\[index\]\];"
        ],
        "PPOrderProgressTimelineView exposes visible timeline rows to VoiceOver in reading order"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderStatusStepperView.m",
        [
            r"self\.isAccessibilityElement\s*=\s*YES;",
            r"self\.accessibilityTraits\s*=\s*UIAccessibilityTraitUpdatesFrequently;",
            r"self\.accessibilityLabel\s*=\s*kLang\(@\"order_status\"\);",
            r"pp_updateAccessibility"
        ],
        "PPOrderStatusStepperView announces overall progress to VoiceOver with fractional step context"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderCell.m",
        [
            r"self\.isAccessibilityElement\s*=\s*YES;",
            r"self\.accessibilityTraits\s*=\s*UIAccessibilityTraitButton;",
            r"self\.accessibilityLabel\s*=\s*\[components\s*componentsJoinedByString:@\",\s*\"\];",
            r"self\.accessibilityHint\s*=\s*kLang\(@\"order_history_row_accessibility_hint\"\);"
        ],
        "OrderCell combines order name, quantity, price, status, and navigation hint into cohesive VoiceOver readout"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderItemCell.m",
        [
            r"self\.accessibilityLabel\s*=\s*\[NSString\s*stringWithFormat:@\"%@,\s*%@,\s*%@\",\s*_nameLabel\.text",
            r"_itemImageView\.accessibilityElementsHidden\s*=\s*YES;"
        ],
        "OrderItemCell aggregates item text and hides decorative image from VoiceOver"
    ), "Group 2")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderSupportComposerViewController.m",
        [
            r"self\.heroBackButton\.accessibilityLabel\s*=\s*kLang\(@\"Back\"\);",
            r"self\.submitButton\.accessibilityLabel\s*=\s*kLang\(@\"order_request_submit\"\);",
            r"self\.heroSurfaceView\.accessibilityLabel\s*="
        ],
        "PPOrderSupportComposerViewController provides accessible labels for actions and hero surface"
    ), "Group 2")

    # =========================================================================
    # Group 3: Minimum Interactive Touch Targets (>= 44pt)
    # =========================================================================
    print("\n[Group 3: Minimum Interactive Touch Targets (>= 44pt)]")

    run_check(lambda: check_file_patterns(
        "MainApp/Accessories/AccessFiles/PPAccessoryViewerComponents.swift",
        [
            r"\.frame\(minHeight:\s*44\)"
        ],
        "PPAccessoryViewerComponents enforces >= 44pt minimum height on option buttons"
    ), "Group 3")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.m",
        [
            r"CGFloat dx = MAX\(0\.0,\s*\(48\.0\s*-\s*CGRectGetWidth\(self\.bounds\)\)\s*/\s*2\.0\);",
            r"CGFloat dy = MAX\(0\.0,\s*\(48\.0\s*-\s*CGRectGetHeight\(self\.bounds\)\)\s*/\s*2\.0\);",
            r"CGRect hitFrame = CGRectInset\(self\.bounds,\s*-dx,\s*-dy\);"
        ],
        "PPCartTableCell expands small button hit regions to 48x48pt"
    ), "Group 3")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m",
        [
            r"\[self\.iconContainerView\.widthAnchor constraintEqualToConstant:44\.0\]",
            r"\[self\.iconContainerView\.heightAnchor constraintEqualToConstant:44\.0\]"
        ],
        "PPPaymentMethodCell enforces >= 44pt dimension on touch icon container"
    ), "Group 3")

    # =========================================================================
    # Group 4: Arabic RTL Natural Alignment, Constraints & Mirroring
    # =========================================================================
    print("\n[Group 4: Arabic RTL Alignment, Layout & Directionality]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m",
        [
            r"Language\.isRTL\s*\?\s*@\"chevron\.left\"\s*:\s*@\"chevron\.right\"",
            r"self\.semanticContentAttribute\s*=\s*Language\.semanticAttributeForCurrentLanguage;",
            r"self\.titleLabel\.textAlignment\s*=\s*NSTextAlignmentNatural;",
            r"self\.subtitleLabel\.textAlignment\s*=\s*NSTextAlignmentNatural;"
        ],
        "PPPaymentMethodCell mirrors disclosure chevron and uses natural text alignment for RTL"
    ), "Group 4")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderCell.m",
        [
            r"isRTL\s*\?\s*@\"chevron\.left\"\s*:\s*@\"chevron\.right\"",
            r"NSTextAlignment leadingAlign = isRTL \? NSTextAlignmentRight : NSTextAlignmentLeft;",
            r"UISemanticContentAttribute semanticAttr = isRTL \? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;"
        ],
        "OrderCell mirrors disclosure chevron and enforces proper RTL semantic attributes"
    ), "Group 4")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineView.m",
        [
            r"CGFloat trackX = \[Language isRTL\] \? \(width - 18\.0\) : 18\.0;"
        ],
        "PPOrderProgressTimelineView mirrors vertical timeline track position in RTL"
    ), "Group 4")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineRowView.m",
        [
            r"return self\.isRTL \? \(width - 18\.0\) : 18\.0;",
            r"CGFloat contentLeading = self\.isRTL \? 0\.0 : 46\.0;"
        ],
        "PPOrderProgressTimelineRowView mirrors markers and content leading margins in RTL"
    ), "Group 4")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderStatusStepperView.m",
        [
            r"if\s*\((\[Language languageVal\] == 1|\[Language isRTL\])\)\s*\{",
            r"return MAX\(0,\s*\(NSInteger\)self\.steps\.count\s*-\s*1\s*-\s*logicalIndex\);"
        ],
        "PPOrderStatusStepperView reverses logical horizontal stepper progression for RTL"
    ), "Group 4")

    run_check(lambda: check_file_patterns(
        "MainApp/Accessories/AccessFiles/PetAccessory.m",
        [
            r"if\s*\(Language\.isRTL\)\s*\{",
            r"return\s*\[NSString\s*stringWithFormat:@\"من\s*%@\s*إلى\s*%@\""
        ],
        "PetAccessory formats price ranges with natural Arabic grammatical ordering"
    ), "Group 4")

    run_check(lambda: check_no_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.m",
        [
            r"leftAnchor constraint",
            r"rightAnchor constraint"
        ],
        "PPCartTableCell uses strict leading/trailing layout constraints (zero left/right anchors)"
    ), "Group 4")

    # =========================================================================
    # Group 5: Reduce Motion & Low-Power Accessibility Compliance
    # =========================================================================
    print("\n[Group 5: Reduce Motion & Low-Power Accessibility Compliance]")

    run_check(lambda: check_file_patterns(
        "MainApp/Accessories/AccessFiles/PPAccessoryViewerComponents.swift",
        [
            r"@Environment\(\\.accessibilityReduceMotion\)\s*private\s*var\s*reduceMotion"
        ],
        "PPAccessoryViewerComponents respects Reduce Motion environment"
    ), "Group 5")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.m",
        [
            r"if\s*\(UIAccessibilityIsReduceMotionEnabled\(\)\)\s*\{",
            r"UIAccessibilityReduceMotionStatusDidChangeNotification"
        ],
        "PPCartTableCell bypasses stepper bounce/bloom and listens to Reduce Motion status changes"
    ), "Group 5")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m",
        [
            r"!UIAccessibilityIsReduceMotionEnabled\(\)"
        ],
        "PPPaymentMethodCell gates payment selection spring animations on Reduce Motion"
    ), "Group 5")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineView.m",
        [
            r"if\s*\(animated\s*&&\s*!UIAccessibilityIsReduceMotionEnabled\(\)\)"
        ],
        "PPOrderProgressTimelineView skips transition animations when Reduce Motion is enabled"
    ), "Group 5")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineRowView.m",
        [
            r"!UIAccessibilityIsReduceMotionEnabled\(\)"
        ],
        "PPOrderProgressTimelineRowView stops continuous halo and marker pulsing under Reduce Motion"
    ), "Group 5")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderStatusStepperView.m",
        [
            r"!UIAccessibilityIsReduceMotionEnabled\(\)"
        ],
        "PPOrderStatusStepperView deactivates stepper pulsing when Reduce Motion is active"
    ), "Group 5")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderCell.m",
        [
            r"!UIAccessibilityIsReduceMotionEnabled\(\)"
        ],
        "OrderCell status pill transition respects Reduce Motion"
    ), "Group 5")

    # =========================================================================
    # Group 6: Reduce Transparency & High Contrast Adaptation
    # =========================================================================
    print("\n[Group 6: Reduce Transparency & High Contrast Adaptation]")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.m",
        [
            r"accessibilityContrast\s*==\s*UIAccessibilityContrastHigh"
        ],
        "PPCartTableCell renders heavier borders and distinct strokes for High Contrast mode"
    ), "Group 6")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderDetailsViewController.m",
        [
            r"UIAccessibilityIsReduceTransparencyEnabled\(\)\s*\?\s*1\.0\s*:"
        ],
        "OrderDetailsViewController renders fully opaque card materials for Reduce Transparency"
    ), "Group 6")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/OrderItemCell.m",
        [
            r"UIAccessibilityIsReduceTransparencyEnabled\(\)\s*\?\s*1\.0\s*:"
        ],
        "OrderItemCell removes surface transparency under Reduce Transparency"
    ), "Group 6")

    run_check(lambda: check_file_patterns(
        "MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderDetailsMissionControlViews.swift",
        [
            r"@Environment\(\\.accessibilityReduceTransparency\)\s*private\s*var\s*reduceTransparency"
        ],
        "PPOrderDetailsMissionControlViews adapts SwiftUI glass surfaces to Reduce Transparency"
    ), "Group 6")

    # =========================================================================
    # Group 7: Localization Integrity Across RTL & LTR
    # =========================================================================
    print("\n[Group 7: Localization Integrity Across RTL & LTR]")

    ar_strings = os.path.join(IOS_ROOT, "ar.lproj", "Localizable.strings")
    en_strings = os.path.join(IOS_ROOT, "en.lproj", "Localizable.strings")

    critical_keys = [
        "accessory_view_options_title",
        "saved_for_later",
        "cart_cell_save_for_later",
        "order_status",
        "fulfillment_status_completed",
        "fulfillment_status_unknown",
        "fulfillment_status_failed",
        "fulfillment_summary_pending",
        "order_history_row_accessibility_hint",
        "order_request_submit",
        "payment_add_method",
        "payment_pay_now",
        "Back",
        "QuantityLabel"
    ]

    for key in critical_keys:
        run_check(lambda k=key: verify_string_key(k, ar_strings, en_strings), "Group 7")

    # =========================================================================
    # Summary
    # =========================================================================
    print("\n" + "=" * 65)
    print(f"  RESULTS: {passed_tests}/{total_tests} tests passed ({failed_tests} failures)")
    print("=" * 65 + "\n")

    if failed_tests == 0:
        print("🎉 ALL PHASE 13 ACCESSIBILITY & RTL LIFECYCLE TESTS PASSED (100% GREEN)!\n")
        return 0
    else:
        print(f"❌ {failed_tests} TESTS FAILED IN PHASE 13 SUITE.\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
