#!/usr/bin/env python3
"""Source contract guard for the Home Pure Lens entry card (not a runtime/UI test)."""
from pathlib import Path
import json
import unittest

IOS_ROOT = Path(__file__).resolve().parents[1] / "Pure Pets"
SWIFT_HOME = IOS_ROOT / "MainApp/ModrenAppVC/SwiftUIHome"


class HomePureLensContract(unittest.TestCase):
    def setUp(self):
        components = (SWIFT_HOME / "Views/HomeComponents.swift").read_text()
        self.card = (
            components.split("struct PureLensCardV2: View {", 1)[1]
            .split("// MARK: - Home Pure Lens Section V2", 1)[0]
        )
        self.home = (SWIFT_HOME / "Views/HomeView.swift").read_text()
        self.store = (SWIFT_HOME / "State/HomeStore.swift").read_text()
        self.router = (SWIFT_HOME / "Routing/HomeRouter.swift").read_text()
        self.ar = (IOS_ROOT / "ar.lproj/Localizable.strings").read_text()
        self.en = (IOS_ROOT / "en.lproj/Localizable.strings").read_text()

    def test_single_native_button_and_route(self):
        self.assertEqual(self.card.count("Button {"), 1)
        self.assertNotIn("Button(", self.card)
        self.assertIn('.accessibilityIdentifier("home.pureLens.open")', self.card)
        self.assertIn("HomePureLensSection(", self.home)
        self.assertIn("router.openPureLens(pet: pet)", self.store)
        self.assertIn("pureLensPresenter.present(from: owner)", self.router)

    def test_adaptive_rangefinder_motion_and_localization(self):
        self.assertIn("HomeLensRangefinder(", self.card)
        self.assertIn("HomeLensAliveLens(", self.card)
        self.assertIn("HomeLensOpticalCanvas(", self.card)
        self.assertNotIn('Image(decorative: "homeLensFalcon")', self.card)
        self.assertIn("typeSize.isAccessibilitySize", self.card)
        self.assertIn("ViewThatFits(in: .horizontal)", self.card)
        self.assertIn("@Environment(\\.accessibilityReduceMotion)", self.card)
        self.assertIn("@Environment(\\.accessibilityReduceTransparency)", self.card)
        self.assertIn("@Environment(\\.scenePhase)", self.card)
        self.assertIn("@Environment(\\.colorScheme)", self.card)
        self.assertIn("@Environment(\\.colorSchemeContrast)", self.card)
        self.assertIn("reduceMotion ? nil :", self.card)
        for key in (
            "pure_lens_account_title",
            "home_pure_lens_subtitle",
            "home_pure_lens_action",
            "home_pure_lens_a11y",
        ):
            self.assertIn(f'"{key}"', self.ar)
            self.assertIn(f'"{key}"', self.en)

        imageset = IOS_ROOT / "Assets.xcassets/homeLensFalcon.imageset"
        contents = json.loads((imageset / "Contents.json").read_text())
        filenames = [img.get("filename") for img in contents.get("images", [])]
        self.assertIn("falcon.jpg", filenames)
        self.assertTrue((imageset / "falcon.jpg").is_file())

    def test_alive_lens_lifecycle_and_zero_blur_contract(self):
        self.assertIn("TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isAmbientPaused))", self.card)
        self.assertIn("motionReady: motionReady", self.card)
        self.assertIn("struct HomeLensOpticalCanvas: View, Animatable", self.card)
        self.assertIn(".onDisappear {", self.card)
        self.assertIn("Color.ppPrimary", self.card)
        self.assertIn("Color.ppInfo", self.card)
        self.assertIn("Color.ppSuccess", self.card)
        canvas_section = self.card.split("struct HomeLensOpticalCanvas: View, Animatable {", 1)[1]
        self.assertNotIn(".blur(", canvas_section)


if __name__ == "__main__":
    unittest.main()
