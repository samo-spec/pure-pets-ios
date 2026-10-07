import XCTest
@testable import PureLensCore

final class LensAnimalIdentityTests: XCTestCase {
    private let box = LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)

    func testSupportedResolutionCarriesCanonicalBusinessScope() throws {
        let result = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Peregrine falcon",
            canonicalSpecies: "peregrine falcon",
            scientificName: "Falco peregrinus",
            animalGroup: "bird",
            breed: nil,
            speciesConfidence: 0.96,
            breedConfidence: 0,
            support: .init(mainKindID: 2, nameEn: "Falcons", nameAr: "صقور", matchedBy: "main_kind_species")
        )

        XCTAssertEqual(result.support?.mainKindID, 2)
        XCTAssertTrue(result.isSupported)
    }

    func testUnsupportedAnimalCannotCreateBusinessScope() {
        let result = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Sugar glider",
            canonicalSpecies: "sugar glider",
            scientificName: "Petaurus breviceps",
            animalGroup: "mammal",
            breed: nil,
            speciesConfidence: 0.93,
            breedConfidence: 0,
            support: nil
        )

        XCTAssertFalse(result.isSupported)
        XCTAssertNil(result.support)
    }

    func testWeakRemoteBreedDoesNotOverrideReliableSpecies() {
        let local = DetectedAnimalContext(
            species: "Cat",
            confidence: 0.91,
            detectionSource: .fusedOnDevice,
            boundingBox: box,
            trackID: "cat-1"
        )
        let result = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Domestic cat",
            canonicalSpecies: "domestic cat",
            animalGroup: "mammal",
            breed: "British Shorthair",
            speciesConfidence: 0.95,
            breedConfidence: 0.52,
            support: .init(mainKindID: 4, nameEn: "Cats", nameAr: "قطط", matchedBy: "main_kind_species")
        )
        let refined = result.refinedAnimal(from: local, minimumBreedConfidence: 0.78)
        XCTAssertEqual(refined.species, "Domestic cat")
        XCTAssertNil(refined.breed)
        XCTAssertEqual(refined.trackID, "cat-1")
        XCTAssertEqual(refined.boundingBox, box)
    }

    func testBusinessScopeRejectsWrongOrMissingMainKindItems() {
        let scope = LensAnimalSupportContext(
            mainKindID: 2,
            nameEn: "Falcons",
            nameAr: "صقور",
            matchedBy: "main_kind_species"
        )
        let correct = item(id: "falcon-food", mainKindID: 2)
        let wrong = item(id: "cat-food", mainKindID: 4)
        let missing = item(id: "unknown-food", mainKindID: nil)

        XCTAssertEqual(scope.filterCompatible([wrong, missing, correct]).map(\.id), ["falcon-food"])
    }

    private func item(id: String, mainKindID: Int?) -> LensDiscoveryItem {
        LensDiscoveryItem(
            id: id,
            category: .products,
            kind: .product,
            title: id,
            source: .marketplaceTaxonomy,
            petMainKindID: mainKindID
        )
    }
}

extension LensAnimalIdentityTests {
    func testCallableFailureReasonsKeepTaxonomyFailureDistinct() {
        XCTAssertEqual(
            LensAnimalIdentityServiceError.fromServerReason("taxonomy_unavailable"),
            .taxonomyUnavailable
        )
        XCTAssertEqual(
            LensAnimalIdentityServiceError.fromServerReason("identity_unavailable"),
            .identityUnavailable
        )
        XCTAssertNil(LensAnimalIdentityServiceError.fromServerReason("provider_detail"))
        XCTAssertNil(LensAnimalIdentityServiceError.fromServerReason(nil))
    }

    func testIdentityRoutingNeverTreatsUnsupportedAsDiscoveryReady() {
        let supported = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Falcon",
            canonicalSpecies: "falcon",
            speciesConfidence: 0.94,
            support: .init(mainKindID: 2, nameEn: "Falcons", nameAr: "صقور", matchedBy: "main_kind_species")
        )
        let unsupported = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Tiger",
            canonicalSpecies: "tiger",
            speciesConfidence: 0.97,
            support: nil
        )
        let uncertain = LensAnimalIdentificationResult(
            status: .uncertain,
            commonName: "Fox",
            canonicalSpecies: "fox",
            speciesConfidence: 0.43,
            support: nil
        )

        XCTAssertEqual(LensAnimalIdentificationRouting.destination(for: supported), .discovery)
        XCTAssertEqual(LensAnimalIdentificationRouting.destination(for: unsupported), .unsupported)
        XCTAssertEqual(LensAnimalIdentificationRouting.destination(for: uncertain), .uncertain)
    }
}

extension LensAnimalIdentityTests {
    func testGenericVisionAnimalCanEnterRemoteIdentityPipeline() throws {
        let detection = LensLocalDetection(
            kind: .animal,
            label: "animal",
            confidence: 0.91,
            boundingBox: box
        )
        let recognition = try XCTUnwrap(LensPetRecognition.parse(detection))
        XCTAssertEqual(recognition.species, "Animal")
        XCTAssertNil(recognition.breed)
    }
}

// MARK: - Canonical commerce scope TDD
extension LensAnimalIdentityTests {
    func testInvalidBusinessScopeCannotReportSupported() {
        let invalid = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Dog",
            canonicalSpecies: "dog",
            speciesConfidence: 0.95,
            support: .init(mainKindID: 0, nameEn: "Dogs", nameAr: "كلاب", matchedBy: "invalid")
        )

        XCTAssertFalse(invalid.isSupported)
        XCTAssertEqual(LensAnimalIdentificationRouting.destination(for: invalid), .unsupported)
        XCTAssertNil(LensCommerceScope(result: invalid))
    }

    func testCommerceScopeRequiresIdentifiedSupportedAnimal() {
        let unsupported = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Sugar glider",
            canonicalSpecies: "sugar glider",
            speciesConfidence: 0.93,
            support: nil
        )

        XCTAssertNil(LensCommerceScope(result: unsupported))
        XCTAssertNil(LensCommerceScope(mainKindID: 0))
    }

    func testCommerceScopeRejectsConflictingImageSearchKind() throws {
        let scope = try XCTUnwrap(LensCommerceScope(mainKindID: 2))
        let result = LensImageSearchResult(
            items: [
                item(id: "wrong", mainKindID: 4),
                item(id: "right", mainKindID: 2)
            ],
            detectedMainKindID: 4
        )

        XCTAssertTrue(scope.filteredImageSearch(result).isEmpty)
    }

    func testCommerceScopeFiltersEveryItemToCanonicalKind() throws {
        let scope = try XCTUnwrap(LensCommerceScope(mainKindID: 2))
        let items = [
            item(id: "wrong", mainKindID: 4),
            item(id: "missing", mainKindID: nil),
            item(id: "right", mainKindID: 2)
        ]

        XCTAssertEqual(scope.filterCompatible(items).map(\.id), ["right"])
    }
}

// MARK: - Discovery authorization policy TDD
extension LensAnimalIdentityTests {
    func testUncertainCandidatesCannotAuthorizeCommerceAndAreBounded() {
        let candidate = LensAnimalIdentityCandidate(
            commonName: " Peregrine falcon ",
            commonNameAr: "صقر شاهين",
            canonicalSpecies: "peregrine falcon",
            scientificName: "Falco peregrinus",
            confidence: 0.71
        )
        let result = LensAnimalIdentificationResult(
            status: .uncertain,
            commonName: "Animal",
            canonicalSpecies: "",
            speciesConfidence: 0.5,
            candidates: [candidate, candidate, identityCandidate("Saker falcon")],
            support: .init(mainKindID: 2, nameEn: "Falcons", nameAr: "صقور", matchedBy: "invalid")
        )

        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.candidates.first?.commonName, "Peregrine falcon")
        XCTAssertEqual(result.candidates.first?.commonNameAr, "صقر شاهين")
        XCTAssertNil(result.support)
        XCTAssertNil(LensCommerceScope(result: result))
        XCTAssertEqual(LensAnimalDiscoveryPolicy.decision(for: result), .uncertain)
    }

    func testCandidateChoicesRequireTwoDistinctConcreteIdentities() {
        let invalid = [
            "Birds", "Cat", "Dogs", "Falcon", "Falcons", "Parrot", "Eagle", "Owl",
            "Pet", "Amphibian", "Invertebrate"
        ].map { identityCandidate($0) }
        let peregrine = identityCandidate("Peregrine falcon")
        let duplicate = identityCandidate(" PEREGRINE   FALCONS ")
        let lowConfidence = identityCandidate("Saker falcon", confidence: 0.34)
        let conflict = LensAnimalIdentityCandidate(
            commonName: "Sea lion", canonicalSpecies: "lion",
            scientificName: nil, confidence: 0.9
        )
        for broadCandidate in invalid {
            XCTAssertTrue(uncertainIdentity(candidates: [broadCandidate, peregrine]).candidates.isEmpty)
        }
        XCTAssertTrue(uncertainIdentity(candidates: [peregrine, duplicate]).candidates.isEmpty)
        XCTAssertTrue(uncertainIdentity(candidates: [peregrine, lowConfidence]).candidates.isEmpty)
        XCTAssertTrue(uncertainIdentity(candidates: [peregrine, conflict]).candidates.isEmpty)
    }

    func testCandidateChoicesAreBoundedAndMultipleSubjectsCannotBeSelected() {
        let candidates = ["Peregrine falcon", "Saker falcon", "Gyrfalcon", "Lanner falcon"]
            .map { identityCandidate($0) }
        XCTAssertEqual(uncertainIdentity(candidates: candidates).candidates.count, 3)
        XCTAssertTrue(uncertainIdentity(candidates: candidates, reason: "multiple_animals").candidates.isEmpty)
    }

    func testDecodedCandidateUsesTheSameBoundsAsDirectConstruction() throws {
        let data = Data("""
        {"commonName":" Peregrine falcon ","canonicalSpecies":" peregrine falcon ","confidence":4}
        """.utf8)
        let candidate = try JSONDecoder().decode(LensAnimalIdentityCandidate.self, from: data)
        XCTAssertEqual(candidate.commonName, "Peregrine falcon")
        XCTAssertEqual(candidate.canonicalSpecies, "peregrine falcon")
        XCTAssertEqual(candidate.confidence, 1)
        XCTAssertNil(candidate.scientificName)
    }

    private func identityCandidate(_ name: String, confidence: Double = 0.7) -> LensAnimalIdentityCandidate {
        LensAnimalIdentityCandidate(
            commonName: name, canonicalSpecies: name,
            scientificName: nil, confidence: confidence
        )
    }

    private func uncertainIdentity(
        candidates: [LensAnimalIdentityCandidate],
        reason: String = "species_visual_evidence_weak"
    ) -> LensAnimalIdentificationResult {
        LensAnimalIdentificationResult(
            status: .uncertain, commonName: "", canonicalSpecies: "",
            speciesConfidence: 0, ambiguityReason: reason,
            candidates: candidates, support: nil
        )
    }

    func testDiscoveryPolicyCarriesScopeOnlyForSupportedIdentity() throws {
        let supported = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Peregrine falcon",
            canonicalSpecies: "peregrine falcon",
            speciesConfidence: 0.96,
            support: .init(mainKindID: 2, nameEn: "Falcons", nameAr: "صقور", matchedBy: "main_kind_species")
        )
        let unsupported = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Sugar glider",
            canonicalSpecies: "sugar glider",
            speciesConfidence: 0.93,
            support: nil
        )
        let uncertain = LensAnimalIdentificationResult(
            status: .uncertain,
            commonName: "Fox",
            canonicalSpecies: "fox",
            speciesConfidence: 0.41,
            support: nil
        )
        let notAnimal = LensAnimalIdentificationResult(
            status: .notAnimal,
            commonName: "Plush toy",
            canonicalSpecies: "",
            speciesConfidence: 0.99,
            support: nil
        )

        XCTAssertEqual(
            LensAnimalDiscoveryPolicy.decision(for: supported),
            .discover(try XCTUnwrap(LensCommerceScope(mainKindID: 2)))
        )
        XCTAssertEqual(LensAnimalDiscoveryPolicy.decision(for: unsupported), .unsupported)
        XCTAssertEqual(LensAnimalDiscoveryPolicy.decision(for: uncertain), .uncertain)
        XCTAssertEqual(LensAnimalDiscoveryPolicy.decision(for: notAnimal), .notAnimal)
    }

    func testBroadLocalIdentityCannotAuthorizeSupport() {
        XCTAssertFalse(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Bird"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Birds"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Cats"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Animal"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Small mammal"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Dog"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Peregrine falcon"))
    }

    func testSpecificBreedEnablesSupportForBroaderCategory() {
        XCTAssertTrue(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Bird", breed: "Parrot"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Small mammal", breed: "Hamster"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Fish", breed: "Goldfish"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Reptile", breed: "Turtle"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Animal", breed: nil))
        XCTAssertFalse(LensLocalIdentitySpecificity.isSufficientForSupport(species: "Animal", breed: "creature"))
    }

    func testCategoryResolvabilityFiltersOnlyPurelyGenericLabels() {
        XCTAssertTrue(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Bird"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Dog"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Cat"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Fish"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Reptile"))
        XCTAssertTrue(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Small mammal"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Animal"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isCategoryResolvable(species: "Creature"))
        XCTAssertFalse(LensLocalIdentitySpecificity.isCategoryResolvable(species: ""))
    }

    func testUncertainIdentityRetainsBoundedAmbiguityReason() {
        let uncertain = LensAnimalIdentificationResult(
            status: .uncertain,
            commonName: "Fox",
            canonicalSpecies: "fox",
            speciesConfidence: 0.41,
            ambiguityReason: " species_visual_evidence_weak ",
            support: nil
        )
        let identified = LensAnimalIdentificationResult(
            status: .identified,
            commonName: "Dog",
            canonicalSpecies: "dog",
            speciesConfidence: 0.95,
            ambiguityReason: "species_visual_evidence_weak",
            support: .init(mainKindID: 3, nameEn: "Dogs", nameAr: "كلاب", matchedBy: "main_kind_species")
        )

        XCTAssertEqual(uncertain.ambiguityReason, "species_visual_evidence_weak")
        XCTAssertNil(identified.ambiguityReason)
    }
}
