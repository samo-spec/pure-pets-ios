#!/usr/bin/env python3
"""Source-contract UX guards. These do not substitute for on-device tests."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
ORDER = ROOT / "Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderDetailsMissionControlViews.swift"
PICKER = ROOT / "Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalVariantPicker.swift"
EN = ROOT / "Pure Pets/en.lproj/Localizable.strings"
AR = ROOT / "Pure Pets/ar.lproj/Localizable.strings"


class PurchaseDecisionUXContracts(unittest.TestCase):
    def test_tracking_is_prioritized_above_cancellation_and_returns(self):
        source = ORDER.read_text(encoding="utf-8")
        ranking = source.split("private var heroRanking: [String] {", 1)[1].split("\n    private var gridActions", 1)[0]
        lists = re.findall(r'\?\s*\[([^\]]+)\]\s*:\s*\[([^\]]+)\]', ranking)
        self.assertEqual(len(lists), 1, "Both delivered and active ranking lists should be explicit")
        for values in lists[0]:
            kinds = re.findall(r'"([^"]+)"', values)
            self.assertLess(kinds.index("track"), kinds.index("cancel"))
            self.assertLess(kinds.index("track"), kinds.index("return"))

    def test_order_tracking_never_claims_fabricated_percentage(self):
        source = ORDER.read_text(encoding="utf-8")
        self.assertNotIn("Int(store.state.statusProgress * 100)", source)
        self.assertIn("store.state.updatedAtText", source)
        self.assertIn("PPOrderLivingHandoffRail(", source)

    def test_product_family_actions_invite_selection_not_immediate_purchase(self):
        source = (ROOT / "Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalCellSwiftUI.swift").read_text(encoding="utf-8")
        title = source.split("private var primaryActionTitle: String {", 1)[1].split("private var primaryActionIcon:", 1)[0]
        self.assertIn('"universal_variant_choose_options"', title)
        self.assertIn('"universal_variant_review_options"', title)
        menu = source.split("func contextActions()", 1)[-1].split("func performContextAction(", 1)[0]
        self.assertIn('requiresVariantSelection', menu)
        self.assertIn('"universal_variant_choose_options"', menu)
        for localization in (EN, AR):
            values = localization.read_text(encoding="utf-8")
            for key in ("universal_variant_choose_options", "universal_variant_review_options"):
                self.assertIsNotNone(re.search(rf'^"{key}"\s*=\s*"[^"]+";', values, re.MULTILINE))

    def test_variant_choices_explain_live_confirmation_and_archival(self):
        source = PICKER.read_text(encoding="utf-8")
        for key in ("variant_sheet_confirmed_selection", "variant_sheet_check_live_price"):
            self.assertIn(key, source)
            for localization in (EN, AR):
                self.assertIsNotNone(re.search(rf'^"{key}"\s*=\s*"[^"]+";', localization.read_text(encoding="utf-8"), re.MULTILINE))
        self.assertIn(".disabled(isMutating || !store.canChangeVariant || selected || variant.isArchived)", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
