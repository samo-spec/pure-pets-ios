import Foundation
import XCTest
@testable import PureLensCore

final class LensContractTests: XCTestCase {
    func testPurePetsEyesContractAllowsZeroPetProfiles() {
        let missing = LensContext(activePetID: "  ")
        let saved = LensContext(activePetID: "pet-123")

        XCTAssertTrue(PurePetsEyesIntegrationContract.isEligible(context: missing))
        XCTAssertTrue(PurePetsEyesIntegrationContract.isEligible(context: saved))
        XCTAssertFalse(PurePetsEyesIntegrationContract.requiresSavedPetProfile)
        XCTAssertTrue(PurePetsEyesIntegrationContract.allowsAnonymousScanning)
        XCTAssertTrue(PurePetsEyesIntegrationContract.requiresUserConfirmationForWrites)
    }

    func testUncertainBreedFallsBackToSpeciesOnly() {
        let recognition = LensPetRecognition(
            breed: "Golden Retriever",
            species: "Dog",
            confidence: 0.68,
            boundingBox: LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5),
            sourceLabel: "dog:golden retriever"
        )

        let animal = DetectedAnimalContext(
            recognition: recognition,
            minimumBreedConfidence: 0.74
        )
        XCTAssertEqual(animal.species, "Dog")
        XCTAssertNil(animal.breed)
    }

    func testReliableBreedIsRetainedForSessionContext() {
        let recognition = LensPetRecognition(
            breed: "Golden Retriever",
            species: "Dog",
            confidence: 0.91,
            boundingBox: LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5),
            sourceLabel: "dog:golden retriever"
        )

        let animal = DetectedAnimalContext(
            recognition: recognition,
            minimumBreedConfidence: 0.74
        )
        XCTAssertEqual(animal.breed, "Golden Retriever")
    }

    func testGuidanceHandoffContainsOnlyUserRelevantAnimalFacts() {
        let animal = DetectedAnimalContext(
            species: " Cat ",
            breed: " Persian ",
            confidence: 0.94,
            detectionSource: .onDeviceCoreML,
            boundingBox: LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5),
            trackID: "camera-track-17"
        )

        let handoff = LensGuidanceHandoff(
            animal: animal,
            displayName: " القطة الفارسية "
        )

        XCTAssertEqual(handoff.species, "Cat")
        XCTAssertEqual(handoff.breed, "Persian")
        XCTAssertEqual(handoff.displayName, "القطة الفارسية")
        XCTAssertTrue(handoff.isSupported)
    }

    func testGuidanceHandoffSupportsUnsupportedAnimals() {
        let animal = DetectedAnimalContext(
            species: "Giraffe",
            breed: nil,
            confidence: 0.88,
            detectionSource: .onDeviceVision,
            boundingBox: LensNormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        )

        let handoff = LensGuidanceHandoff(
            animal: animal,
            displayName: "زرافة",
            isSupported: false
        )

        XCTAssertEqual(handoff.species, "Giraffe")
        XCTAssertNil(handoff.breed)
        XCTAssertEqual(handoff.displayName, "زرافة")
        XCTAssertFalse(handoff.isSupported)
    }

    func testDiscoveryRankingKeepsReliableBreedAheadOfVisualSimilarity() {
        let animal = DetectedAnimalContext(
            species: "Cat",
            breed: "Persian",
            confidence: 0.92,
            detectionSource: .onDeviceCoreML,
            boundingBox: LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        )
        let breedCompatible = LensDiscoveryItem(
            id: "breed",
            category: .accessories,
            kind: .accessory,
            title: "Persian cat brush",
            source: .marketplaceTaxonomy,
            marketplaceRank: 20
        )
        let visual = LensDiscoveryItem(
            id: "visual",
            category: .accessories,
            kind: .accessory,
            title: "Generic brush",
            source: .imageSearch,
            visualScore: 1,
            marketplaceRank: 0
        )

        let ranked = LensDiscoveryRanking.merge(
            taxonomyItems: [breedCompatible],
            imageItems: [visual],
            for: animal,
            category: .accessories
        )
        XCTAssertEqual(ranked.map(\.id), ["breed", "visual"])
    }

    func testDiscoveryRankingDeduplicatesSharedMarketplaceObject() {
        let animal = DetectedAnimalContext(
            species: "Dog",
            confidence: 0.88,
            detectionSource: .onDeviceVision,
            boundingBox: LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        )
        let taxonomy = LensDiscoveryItem(
            id: "same",
            category: .products,
            kind: .product,
            title: "Daily food",
            source: .marketplaceTaxonomy
        )
        let image = LensDiscoveryItem(
            id: "same",
            category: .products,
            kind: .product,
            title: "Daily food",
            imageURL: "https://example.com/item.jpg",
            source: .imageSearch,
            visualScore: 0.8
        )

        let ranked = LensDiscoveryRanking.merge(
            taxonomyItems: [taxonomy],
            imageItems: [image],
            for: animal,
            category: .products
        )
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.imageURL, "https://example.com/item.jpg")
    }

    func testResolveRequestRoundTrip() throws {
        let request = LensResolveRequest(
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
            frame: LensFrame(
                data: Data([0x01, 0x02, 0x03]),
                pixelWidth: 576,
                pixelHeight: 1_024
            ),
            localDetections: [
                LensLocalDetection(
                    kind: .animal,
                    label: "dog",
                    confidence: 0.98,
                    boundingBox: LensNormalizedRect(x: 0.2, y: 0.3, width: 0.5, height: 0.6)
                )
            ],
            remoteProcessingConsentGranted: true,
            remoteProcessingConsentVersion: "purelens-3.0-google-gemini-no-retention-v1",
            context: LensContext(activePetID: "luna", activePetName: "Luna")
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(LensResolveRequest.self, from: data)
        XCTAssertEqual(decoded, request)
        XCTAssertTrue(decoded.remoteProcessingConsentGranted)
        XCTAssertEqual(
            decoded.remoteProcessingConsentVersion,
            "purelens-3.0-google-gemini-no-retention-v1"
        )
    }
}
