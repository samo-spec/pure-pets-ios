import XCTest
@testable import Pure_Pets

final class PPVetViewerTests: XCTestCase {
    func testArabicAndPersianContactDigitsBecomeRoutableWithoutChangingTheNumber() {
        XCTAssertEqual(PPVetContactRouting.normalizedPhone("+٩٧٤ (٣٣١٢) ٤٥٦٧"), "+97433124567")
        XCTAssertEqual(PPVetContactRouting.normalizedPhone("۰۰۹۷۴-۳۳۱۲-۴۵۶۷"), "+97433124567")
        XCTAssertEqual(PPVetContactRouting.callURL(phone: "3312 4567", whatsapp: "")?.absoluteString,
                       "tel:33124567")
    }

    func testMalformedNumbersCannotEnableExternalActions() {
        for value in ["", "Call me", "123", "+974+33124567", "97433124567?text=hello",
                      "97433124567#123", "1234567890123456", "٩٧٤/٣٣١٢٤٥٦٧"] {
            XCTAssertNil(PPVetContactRouting.normalizedPhone(value), value)
            XCTAssertNil(PPVetContactRouting.callURL(phone: value, whatsapp: ""), value)
            XCTAssertNil(PPVetContactRouting.whatsAppURL(phone: "", whatsapp: value), value)
        }
    }

    func testWhatsAppRemovesInternationalPrefixAndKeepsLegacyInternationalDigits() {
        for value in ["+97433124567", "0097433124567", "97433124567", "+٩٧٤٣٣١٢٤٥٦٧"] {
            XCTAssertEqual(PPVetContactRouting.whatsAppURL(phone: "", whatsapp: value)?.absoluteString,
                           "https://wa.me/97433124567")
        }
    }

    func testWhatsAppDoesNotGuessCountryCodeAndFallsBackToValidPhone() {
        XCTAssertNil(PPVetContactRouting.whatsAppURL(phone: "33124567", whatsapp: ""))
        XCTAssertNotNil(PPVetContactRouting.callURL(phone: "33124567", whatsapp: ""))
        XCTAssertEqual(PPVetContactRouting.whatsAppURL(phone: "+97433124567", whatsapp: "33124567")?.absoluteString,
                       "https://wa.me/97433124567")
        XCTAssertEqual(PPVetContactRouting.callURL(phone: "invalid", whatsapp: "+97433124567")?.absoluteString,
                       "tel:+97433124567")
    }

    func testMissingAndInvalidFeesNeverBecomeFreeConsultationClaims() {
        let content = PPVetViewerContent()
        for value in [0.0, -1, Double.nan, Double.infinity] {
            content.vetCost = value
            let snapshot = PPVetViewerSnapshot(content: content)
            XCTAssertFalse(snapshot.hasPublishedFee)
            XCTAssertEqual(snapshot.consultationCostText, PPVetDetailLocalization.text("vet_detail_confirm_fee"))
        }
        content.vetCost = 75.5
        XCTAssertTrue(PPVetViewerSnapshot(content: content).hasPublishedFee)
    }

    func testMembershipAndApprovalAreNotProfessionalVerification() {
        let content = PPVetViewerContent()
        content.subscriptionActive = true
        content.subscriptionTier = 3
        content.verificationStatus = "approved"
        XCTAssertFalse(PPVetViewerSnapshot(content: content).isVerified)
        content.verificationStatus = " VERIFIED "
        XCTAssertTrue(PPVetViewerSnapshot(content: content).isVerified)
        content.subscriptionActive = false
        XCTAssertNil(PPVetViewerSnapshot(content: content).membershipText)
    }

    func testUnavailableProfilesDisableBothChannelsEvenWithValidContactData() {
        let content = PPVetViewerContent()
        content.phone = "+97433124567"
        for status in ["pending", "rejected", "suspended", "unknown"] {
            content.verificationStatus = status
            let snapshot = PPVetViewerSnapshot(content: content)
            XCTAssertFalse(snapshot.isListed)
            XCTAssertFalse(snapshot.canCall)
            XCTAssertFalse(snapshot.canWhatsApp)
        }
        content.verificationStatus = "approved"
        content.isDisabled = true
        XCTAssertFalse(PPVetViewerSnapshot(content: content).canCall)
        content.isDisabled = false
        XCTAssertTrue(PPVetViewerSnapshot(content: content).canCall)
    }

    func testPartialProfilesHaveStableIdentityAndDoNotInventBiographyOrSpecies() {
        let content = PPVetViewerContent()
        let first = PPVetViewerSnapshot(content: content)
        XCTAssertEqual(first, PPVetViewerSnapshot(content: content))
        XCTAssertTrue(first.bio.isEmpty)
        XCTAssertTrue(first.speciesNames.isEmpty)
        content.animalTypes = ["7", "٧", " Cats ", "cats"]
        content.mainKindName = "Cats"
        XCTAssertEqual(PPVetViewerSnapshot(content: content).speciesNames, ["Cats"])
    }

    func testOnlyRemoteWebImagesReachTheImageLoader() {
        let content = PPVetViewerContent()
        for value in ["", "file:///private/image.png", "javascript:alert(1)", "https:"] {
            content.logoURL = value
            XCTAssertNil(PPVetViewerSnapshot(content: content).logoURL)
        }
        content.logoURL = " https://example.com/vet.png "
        XCTAssertEqual(PPVetViewerSnapshot(content: content).logoURL, "https://example.com/vet.png")
    }

    func testFeatureTranslationsArePackagedInBothAppLanguages() throws {
        // Test the application resources, not text found in the checkout. This catches the
        // observed failure where Swift source updated but the installed strings did not.
        let app = Bundle(for: PPVetViewerContent.self)
        for (language, doctor, call) in [("en", "Veterinarian", "Call"), ("ar", "طبيب بيطري", "اتصال")] {
            let path = try XCTUnwrap(app.path(forResource: language, ofType: "lproj"))
            let localized = try XCTUnwrap(Bundle(path: path))
            XCTAssertEqual(localized.localizedString(forKey: "vet_detail_doctor", value: nil, table: "VetDetails"), doctor)
            XCTAssertEqual(localized.localizedString(forKey: "vet_detail_call", value: nil, table: "VetDetails"), call)
            let resource = try XCTUnwrap(localized.url(forResource: "VetDetails", withExtension: "strings"))
            let table = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: resource),
                                                                            options: [], format: nil) as? [String: String])
            XCTAssertGreaterThanOrEqual(table.count, 47)
            for (key, value) in table {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
                XCTAssertNotEqual(key, value)
            }
        }
    }

    func testMissingFeatureTableUsesLocalizedLegacyCopyInsteadOfRawKeys() {
        var lookups: [String] = []
        let text = PPVetDetailLocalization.resolvedText(for: "vet_detail_call") { key, table in
            lookups.append((table ?? "Localizable") + ":" + key)
            return table == nil && key == "pet_care_call" ? "اتصال" : key
        }
        XCTAssertEqual(text, "اتصال")
        XCTAssertEqual(lookups.first, "VetDetails:vet_detail_call")
        XCTAssertFalse(text.contains("vet_detail_"))
        XCTAssertEqual(PPVetDetailLocalization.resolvedText(for: "unknown_key") { key, _ in key }, "")
    }

    func testFeatureTableHasPriorityOverLegacyResources() {
        let text = PPVetDetailLocalization.resolvedText(for: "vet_detail_call") { _, table in
            table == "VetDetails" ? "اتصال" : "Legacy value"
        }
        XCTAssertEqual(text, "اتصال")
    }

    func testMissingFeatureTablesRetainEnglishBackAndErrorLabels() {
        let legacy = ["chat_header_back": "Back", "error": "Error"]
        for (key, expected) in [("vet_detail_back", "Back"), ("vet_detail_contact_error_title", "Error")] {
            let text = PPVetDetailLocalization.resolvedText(for: key) { candidate, table in
                table == nil ? legacy[candidate] ?? candidate : candidate
            }
            XCTAssertEqual(text, expected)
        }
    }

    func testDisplayedAmountAndCareScopeKeepTheirOwnSemanticRuns() {
        let content = PPVetViewerContent()
        content.vetCost = 250
        content.animalTypes = ["طيور", "قطط"]
        let snapshot = PPVetViewerSnapshot(content: content)
        XCTAssertNotNil(snapshot.consultationAmountText)
        XCTAssertFalse(snapshot.consultationAmountText?.contains("QAR") ?? true)
        XCTAssertFalse(snapshot.consultationAmountText?.contains("ر") ?? true)
        XCTAssertTrue(snapshot.speciesSummary.contains("طيور"))
        XCTAssertTrue(snapshot.speciesSummary.contains("قطط"))
    }

}

final class PPVetCardSnapshotTests: XCTestCase {
    func testProviderTypeSelectsDistinctIdentityWithoutLosingSuppliedFacts() {
        let vet = VetModel()
        vet.vetID = "provider-1"
        vet.title = "  Care practice  "
        vet.cityName = "  Doha  "
        vet.address = "Street 12"
        vet.workingHours = "09:00–18:00"
        vet.homeVisitAvailable = true
        vet.emergency247 = true
        vet.vetCost = 150
        for type in [VetType.personal, .company] {
            vet.type = type
            let profile = PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile
            XCTAssertEqual(profile.isCompany, type == .company)
            XCTAssertEqual(profile.title, "Care practice")
            XCTAssertEqual(profile.cityName, "Doha")
            XCTAssertEqual(profile.address, "Street 12")
            XCTAssertEqual(profile.workingHours, "09:00–18:00")
            XCTAssertTrue(profile.homeVisitAvailable)
            XCTAssertTrue(profile.emergency247)
            XCTAssertTrue(profile.hasPublishedFee)
        }
    }

    func testDirectoryDoesNotTurnMissingFeesOrMembershipIntoClaims() {
        let vet = VetModel()
        vet.subscriptionActive = true
        vet.verificationStatus = "approved"
        for amount in [0.0, -1, Double.nan, Double.infinity] {
            vet.vetCost = amount
            let profile = PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile
            XCTAssertFalse(profile.hasPublishedFee)
            XCTAssertNil(profile.consultationAmountText)
            XCTAssertFalse(profile.isVerified)
        }
        vet.verificationStatus = " VERIFIED "
        XCTAssertTrue(PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile.isVerified)
    }

    func testDirectoryContactEligibilityMatchesTheExistingRoutingOwner() {
        let vet = VetModel()
        vet.phone = "٣٣١٢٤٥٦٧"
        vet.verificationStatus = "approved"
        var profile = PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile
        XCTAssertTrue(profile.canCall)
        XCTAssertFalse(profile.canWhatsApp)
        vet.whatsapp = "+٩٧٤٣٣١٢٤٥٦٧"
        profile = PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile
        XCTAssertTrue(profile.canWhatsApp)
        for status in ["pending", "suspended", "rejected", "unknown"] {
            vet.verificationStatus = status
            profile = PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile
            XCTAssertFalse(profile.canCall)
            XCTAssertFalse(profile.canWhatsApp)
        }
        vet.verificationStatus = "verified"
        vet.isDisabled = true
        XCTAssertFalse(PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile.isListed)
    }

    func testUnknownTaxonomyIdentifiersNeverBecomeSpeciesOrAllPetsClaims() {
        let vet = VetModel()
        vet.animalTypes = ["7", "٧", " Cats ", "cats", ""]
        vet.supportedKindIDs = [NSNumber(value: 999)]
        vet.petMainKindID = 0
        let profile = PPVetCardSnapshot(vet: vet, mainKindName: "All pets", kinds: []).profile
        XCTAssertEqual(profile.speciesNames, ["Cats"])
    }

    func testEmptyProfilesStayStableAndKeepTheirProviderType() {
        let vet = VetModel()
        vet.type = .company
        let first = PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: [])
        XCTAssertEqual(first, PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []))
        XCTAssertEqual(first.profile.title, PPVetDetailLocalization.text("vet_detail_clinic"))
        XCTAssertTrue(first.profile.bio.isEmpty)
        XCTAssertTrue(first.profile.speciesNames.isEmpty)
        XCTAssertNil(first.profile.cityName)
        XCTAssertNil(first.profile.workingHours)
        XCTAssertFalse(first.profile.emergency247)
    }

    func testLegacyTaxonomyCanResolveArabicIdentifiersWithAMissingTranslation() {
        let kind = MainKindsModel()
        kind.id = 7
        kind.setValue("Cats", forKey: "KindNameEn")
        // The Objective-C initializer permits missing fields despite nonnull declarations.
        kind.setValue(nil, forKey: "KindNameAr")
        let vet = VetModel()
        vet.petMainKindID = 7
        vet.animalTypes = ["٧", "Cats"]
        vet.supportedKindIDs = [NSNumber(value: 7)]
        XCTAssertEqual(PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: [kind]).profile.speciesNames,
                       ["Cats"])
    }

    func testDirectoryImagesUseTheSameRemoteURLValidationAsDetails() {
        let vet = VetModel()
        for value in ["file:///private/photo.png", "javascript:invalid", "https:"] {
            vet.logoURL = value
            XCTAssertNil(PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile.logoURL)
        }
        vet.logoURL = "https://example.com/logo.png"
        XCTAssertEqual(PPVetCardSnapshot(vet: vet, mainKindName: nil, kinds: []).profile.logoURL,
                       "https://example.com/logo.png")
    }
}
