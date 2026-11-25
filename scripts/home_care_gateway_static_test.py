#!/usr/bin/env python3
"""Source contract guard for the Home care invitation (not a runtime/UI test)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "Pure Pets/MainApp/ModrenAppVC/SwiftUIHome"

class HomeCareGatewayContract(unittest.TestCase):
    def setUp(self):
        source = (ROOT / "Views/PPHomeZoneComponents.swift").read_text()
        self.card = source.split("struct PPHomePetCareCard: View {", 1)[1].split("// MARK: - Companion invitations", 1)[0]
        self.home = (ROOT / "Views/HomeView.swift").read_text()
        self.store = (ROOT / "State/HomeStore.swift").read_text()

    def test_single_existing_destination(self):
        self.assertEqual(self.card.count("Button(action: open)"), 1)
        self.assertNotIn("Button(", self.card.replace("Button(action: open)", ""))
        self.assertIn('open: { store.openProviderCategory("veterinarians") }', self.home)
        self.assertIn("router.openVeterinaryCare(mainKind: selectedMainKind)", self.store)
        self.assertIn('.accessibilityIdentifier("home.petCare")', self.card)

    def test_adaptive_unified_care_identity(self):
        self.assertNotIn("homePetCareConsultation", self.card)
        self.assertIn("PPHomeCareOrbit", self.card)
        self.assertIn("dynamicTypeSize", self.card)
        self.assertIn("PPHomeSurfacePressStyle(reduceMotion: reduceMotion)", self.card)
        self.assertIn("Text(spokenSummary)", self.card)
        for key in ("pet_care_veterinarians", "pet_care_clinics", "pet_care_medicines"):
            self.assertIn(key, self.card)

if __name__ == "__main__":
    unittest.main()
