import XCTest
@testable import PureLensCore

final class LensObservationConfidenceTests: XCTestCase {
    func testEffectiveConfidenceMultipliesObservationAndLabelConfidence() {
        XCTAssertEqual(
            LensObservationConfidence.effective(observation: 0.25, label: 0.95),
            0.2375,
            accuracy: 0.000_001
        )
    }

    func testEffectiveConfidenceClampsInvalidInputs() {
        XCTAssertEqual(
            LensObservationConfidence.effective(observation: .nan, label: 0.95),
            0
        )
        XCTAssertEqual(
            LensObservationConfidence.effective(observation: 2, label: 2),
            1
        )
    }
}

final class LensAnimalClassificationTaxonomyTests: XCTestCase {
    func testMapsSupportedClassifierAnimalsToDiscoverySpecies() {
        XCTAssertEqual(LensAnimalClassificationTaxonomy.species(for: "canine"), "dog")
        XCTAssertEqual(LensAnimalClassificationTaxonomy.species(for: "parrot"), "bird")
        XCTAssertEqual(LensAnimalClassificationTaxonomy.species(for: "puffer_fish"), "fish")
        XCTAssertEqual(LensAnimalClassificationTaxonomy.species(for: "monitor-lizard"), "reptile")
        XCTAssertEqual(LensAnimalClassificationTaxonomy.species(for: "hamster"), "small mammal")
        XCTAssertEqual(LensAnimalClassificationTaxonomy.species(for: "camel"), "camel")
    }

    func testRejectsNonAnimalLabelsThatContainAnimalWords() {
        XCTAssertNil(LensAnimalClassificationTaxonomy.species(for: "hotdog"))
        XCTAssertNil(LensAnimalClassificationTaxonomy.species(for: "birdhouse"))
        XCTAssertNil(LensAnimalClassificationTaxonomy.species(for: "fishbowl"))
        XCTAssertNil(LensAnimalClassificationTaxonomy.species(for: "computer_mouse"))
        XCTAssertNil(LensAnimalClassificationTaxonomy.species(for: "fried_chicken"))
    }

    func testClassifierSpeciesRemainAcceptedByRecognitionParser() throws {
        let box = LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        for expected in ["Camel", "Sheep", "Goat", "Cow"] {
            let detection = LensLocalDetection(
                kind: .animal,
                label: expected.lowercased(),
                confidence: 0.9,
                boundingBox: box
            )
            XCTAssertEqual(try XCTUnwrap(LensPetRecognition.parse(detection)).species, expected)
        }
    }
}

final class LensSpatialTrackingReleaseTests: XCTestCase {
    private let left = LensNormalizedRect(x: 0.05, y: 0.25, width: 0.25, height: 0.45)
    private let nearby = LensNormalizedRect(x: 0.10, y: 0.27, width: 0.25, height: 0.45)
    private let right = LensNormalizedRect(x: 0.70, y: 0.25, width: 0.25, height: 0.45)

    func testNearbyObservationMatchesSameInstance() throws {
        let first = try XCTUnwrap(recognition(box: left))
        let second = try XCTUnwrap(recognition(box: nearby))

        XCTAssertTrue(first.isSameInstance(as: second))
    }

    func testDistantSameSpeciesObservationIsDifferentInstance() throws {
        let first = try XCTUnwrap(recognition(box: left))
        let second = try XCTUnwrap(recognition(box: right))

        XCTAssertFalse(first.isSameInstance(as: second))
    }

    func testLockedDogDoesNotJumpToMoreConfidentDistantDog() throws {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(
                minimumConfidence: 0.50,
                requiredStableFrames: 1,
                replacementStableFrames: 3,
                lostFrameTolerance: 1
            )
        )
        let leftDog = detection(id: "left", confidence: 0.80, box: left)
        let rightDog = detection(id: "right", confidence: 0.99, box: right)

        guard case .detected(let locked) = stabilizer.ingest([leftDog]) else {
            return XCTFail("Expected the left dog to lock")
        }
        let originalTrackID = try XCTUnwrap(locked.trackID)

        guard case .detected(let retained) = stabilizer.ingest([rightDog]) else {
            return XCTFail("Expected the original lock to remain during replacement stabilization")
        }
        XCTAssertEqual(retained.trackID, originalTrackID)
        XCTAssertEqual(retained.boundingBox.x, left.x, accuracy: 0.000_001)
    }

    func testDistantSameSpeciesReplacementGetsNewTrackIDAfterThreshold() throws {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(
                minimumConfidence: 0.50,
                requiredStableFrames: 1,
                replacementStableFrames: 2,
                lostFrameTolerance: 1
            )
        )
        let leftDog = detection(id: "left", confidence: 0.90, box: left)
        let rightDog = detection(id: "right", confidence: 0.95, box: right)

        guard case .detected(let first) = stabilizer.ingest([leftDog]) else {
            return XCTFail("Expected initial lock")
        }
        _ = stabilizer.ingest([rightDog])
        guard case .detected(let replacement) = stabilizer.ingest([rightDog]) else {
            return XCTFail("Expected spatial replacement")
        }

        XCTAssertNotEqual(replacement.trackID, first.trackID)
        XCTAssertEqual(replacement.boundingBox.x, right.x, accuracy: 0.000_001)
    }

    func testLockedSpatialInstanceWinsWhenAnotherDogIsStrongerInSameFrame() throws {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 1, replacementStableFrames: 3)
        )
        let leftDog = detection(id: "left", confidence: 0.75, box: left)
        let leftUpdate = detection(id: "left-update", confidence: 0.72, box: nearby)
        let rightDog = detection(id: "right", confidence: 0.99, box: right)

        guard case .detected(let first) = stabilizer.ingest([leftDog]) else {
            return XCTFail("Expected initial lock")
        }
        guard case .detected(let updated) = stabilizer.ingest([rightDog, leftUpdate]) else {
            return XCTFail("Expected lock update")
        }

        XCTAssertEqual(updated.trackID, first.trackID)
        XCTAssertLessThan(updated.boundingBox.x, 0.20)
    }

    func testBoundFrameRejectsDifferentDogAtDistantPosition() throws {
        let tracked = try XCTUnwrap(recognition(box: left, trackID: "track-a"))
        let other = try XCTUnwrap(recognition(box: right, trackID: "track-b"))
        let now = Date(timeIntervalSince1970: 100)
        let bound = LensBoundFrame(
            frame: LensFrame(data: Data([1]), pixelWidth: 100, pixelHeight: 100),
            recognition: other,
            capturedAt: now
        )

        XCTAssertFalse(bound.isValid(for: tracked, at: now, maximumAge: 3))
    }

    private func detection(
        id: String,
        confidence: Double,
        box: LensNormalizedRect
    ) -> LensLocalDetection {
        LensLocalDetection(
            id: id,
            kind: .animal,
            label: "dog",
            confidence: confidence,
            boundingBox: box
        )
    }

    private func recognition(
        box: LensNormalizedRect,
        trackID: String? = nil
    ) -> LensPetRecognition? {
        LensPetRecognition.parse(detection(id: UUID().uuidString, confidence: 0.9, box: box))?
            .withTrackID(trackID)
    }
}

final class LensResolutionReleaseGateTests: XCTestCase {
    private let box = LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)

    func testRequestIncludesStabilizedRecognition() throws {
        let detection = LensLocalDetection(
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.88,
            boundingBox: box
        )
        let recognition = try XCTUnwrap(LensPetRecognition.parse(detection)?.withTrackID("track-1"))
        let snapshot = try LensResolutionSnapshot(
            recognition: recognition,
            boundFrame: nil,
            localDetections: [detection],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            maximumFrameAge: 3
        )

        let request = snapshot.makeRequest()

        XCTAssertEqual(request.stabilizedRecognition, recognition)
    }

    func testBarcodePayloadIsRedactedByDefault() throws {
        let barcode = LensLocalDetection(
            kind: .barcode,
            label: "barcode",
            confidence: 0.99,
            boundingBox: box,
            machineValue: "otpauth://totp/account?secret=TOPSECRET"
        )
        let snapshot = try LensResolutionSnapshot(
            recognition: nil,
            boundFrame: nil,
            localDetections: [barcode],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            maximumFrameAge: 3
        )

        XCTAssertEqual(snapshot.makeRequest().localDetections.count, 0)
    }

    func testPresenceOnlyBarcodePolicyRemovesMachineValue() throws {
        let barcode = LensLocalDetection(
            kind: .barcode,
            label: "barcode",
            confidence: 0.99,
            boundingBox: box,
            machineValue: "private-value"
        )
        let snapshot = try LensResolutionSnapshot(
            recognition: nil,
            boundFrame: nil,
            localDetections: [barcode],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            maximumFrameAge: 3,
            barcodePayloadPolicy: .presenceOnly
        )

        XCTAssertEqual(snapshot.makeRequest().localDetections.count, 1)
        XCTAssertNil(snapshot.makeRequest().localDetections.first?.machineValue)
    }
}

final class LensAutomaticResolutionGateTests: XCTestCase {
    private let box = LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)

    func testBreedEnrichmentDoesNotResolveSameTrackTwice() throws {
        var gate = LensAutomaticResolutionGate()
        let generic = try XCTUnwrap(recognition("dog", kind: .animal)?.withTrackID("track-1"))
        let breed = try XCTUnwrap(recognition("pet|dog|Golden Retriever", kind: .object)?.withTrackID("track-1"))

        XCTAssertTrue(gate.shouldStart(for: generic))
        XCTAssertFalse(gate.shouldStart(for: breed))
    }

    func testReacquiredPetWithNewTrackCanResolveAgain() throws {
        var gate = LensAutomaticResolutionGate()
        let first = try XCTUnwrap(recognition("dog", kind: .animal)?.withTrackID("track-1"))
        let reacquired = try XCTUnwrap(recognition("dog", kind: .animal)?.withTrackID("track-2"))

        XCTAssertTrue(gate.shouldStart(for: first))
        XCTAssertTrue(gate.shouldStart(for: reacquired))
    }

    func testPreviouslyResolvedTrackDoesNotResolveAgainAfterAnotherPet() throws {
        var gate = LensAutomaticResolutionGate()
        let dog = try XCTUnwrap(recognition("dog", kind: .animal)?.withTrackID("track-dog"))
        let cat = try XCTUnwrap(recognition("cat", kind: .animal)?.withTrackID("track-cat"))

        XCTAssertTrue(gate.shouldStart(for: dog))
        XCTAssertTrue(gate.shouldStart(for: cat))
        XCTAssertFalse(gate.shouldStart(for: dog))
    }

    private func recognition(_ label: String, kind: LensDetectionKind) -> LensPetRecognition? {
        LensPetRecognition.parse(
            LensLocalDetection(
                kind: kind,
                label: label,
                confidence: 0.9,
                boundingBox: box
            )
        )
    }
}

final class LensDetectorFailureGateTests: XCTestCase {
    func testDetectorFailureIsRateLimitedButRecoversAfterCooldown() {
        var gate = LensDetectorFailureGate(cooldown: 5)

        XCTAssertTrue(gate.shouldReport(at: 10))
        XCTAssertFalse(gate.shouldReport(at: 12))
        XCTAssertTrue(gate.shouldReport(at: 15))
    }

    func testSuccessfulAnalysisResetsFailureGate() {
        var gate = LensDetectorFailureGate(cooldown: 5)

        XCTAssertTrue(gate.shouldReport(at: 10))
        gate.markHealthy()
        XCTAssertTrue(gate.shouldReport(at: 11))
    }
}

final class LensPrivacyConsentReleaseGateTests: XCTestCase {
    func testRawBarcodePayloadAlwaysRequiresConsent() {
        XCTAssertTrue(
            LensRemoteProcessingConsentPolicy.requiresConsent(
                hasConsent: false,
                requiresSelectedFrameConsent: false,
                selectedFrameWillBeUploaded: false,
                rawBarcodePayloadWillBeUploaded: true
            )
        )
    }

    func testExistingConsentSuppressesAdditionalPrompt() {
        XCTAssertFalse(
            LensRemoteProcessingConsentPolicy.requiresConsent(
                hasConsent: true,
                requiresSelectedFrameConsent: true,
                selectedFrameWillBeUploaded: true,
                rawBarcodePayloadWillBeUploaded: true
            )
        )
    }

    func testMetadataOnlyWithoutRawBarcodeDoesNotRequireConsent() {
        XCTAssertFalse(
            LensRemoteProcessingConsentPolicy.requiresConsent(
                hasConsent: false,
                requiresSelectedFrameConsent: true,
                selectedFrameWillBeUploaded: false,
                rawBarcodePayloadWillBeUploaded: false
            )
        )
    }
}

final class LensAdditionalDetectorReleaseGateTests: XCTestCase {
    private let left = LensNormalizedRect(x: 0.05, y: 0.25, width: 0.25, height: 0.45)
    private let right = LensNormalizedRect(x: 0.70, y: 0.25, width: 0.25, height: 0.45)

    func testSameTrackTokenCannotOverrideDistantSpatialMismatch() throws {
        let target = try XCTUnwrap(recognition(label: "dog", box: left)?.withTrackID("track-1"))
        let distant = try XCTUnwrap(recognition(label: "dog", box: right)?.withTrackID("track-1"))
        let now = Date(timeIntervalSince1970: 100)
        let bound = LensBoundFrame(
            frame: LensFrame(data: Data([1]), pixelWidth: 100, pixelHeight: 100),
            recognition: distant,
            capturedAt: now
        )

        XCTAssertFalse(bound.isValid(for: target, at: now, maximumAge: 3))
    }

    func testBreedEnrichmentOnSameTrackDoesNotReplayFeedback() throws {
        var gate = LensRecognitionFeedbackGate()
        let generic = try XCTUnwrap(recognition(label: "dog", box: left)?.withTrackID("track-1"))
        let breed = try XCTUnwrap(
            recognition(label: "pet|dog|Golden Retriever", box: left)?.withTrackID("track-1")
        )
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(gate.shouldPlay(for: generic, at: start, cooldown: 10))
        XCTAssertFalse(gate.shouldPlay(for: breed, at: start.addingTimeInterval(1), cooldown: 10))
    }

    func testExplicitBarcodePayloadPolicyIncludesPayload() throws {
        let barcode = LensLocalDetection(
            kind: .barcode,
            label: "barcode",
            confidence: 0.99,
            boundingBox: left,
            machineValue: "approved-payload"
        )
        let snapshot = try LensResolutionSnapshot(
            recognition: nil,
            boundFrame: nil,
            localDetections: [barcode],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            maximumFrameAge: 3,
            barcodePayloadPolicy: .includePayloads
        )

        XCTAssertEqual(snapshot.makeRequest().localDetections.first?.machineValue, "approved-payload")
    }

    func testEncodedRequestCarriesStabilizedRecognitionAndRedactsBarcodeByDefault() throws {
        let recognition = try XCTUnwrap(
            self.recognition(label: "pet|dog|Golden Retriever", box: left)?.withTrackID("track-1")
        )
        let targetDetection = LensLocalDetection(
            id: "target-dog",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.90,
            boundingBox: left
        )
        let barcode = LensLocalDetection(
            kind: .barcode,
            label: "barcode",
            confidence: 0.99,
            boundingBox: left,
            machineValue: "TOP-SECRET"
        )
        let snapshot = try LensResolutionSnapshot(
            recognition: recognition,
            boundFrame: nil,
            localDetections: [targetDetection, barcode],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            maximumFrameAge: 3
        )

        let data = try JSONEncoder().encode(snapshot.makeRequest())
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("Golden Retriever"))
        XCTAssertTrue(json.contains("track-1"))
        XCTAssertFalse(json.contains("TOP-SECRET"))
    }

    func testArbitraryObjectLabelIsNotParsedAsPet() {
        let product = LensLocalDetection(
            kind: .object,
            label: "pet food bowl",
            confidence: 0.99,
            boundingBox: left
        )

        XCTAssertNil(LensPetRecognition.parse(product))
    }

    private func recognition(label: String, box: LensNormalizedRect) -> LensPetRecognition? {
        LensPetRecognition.parse(
            LensLocalDetection(
                kind: label.contains("|") ? .object : .animal,
                label: label,
                confidence: 0.9,
                boundingBox: box
            )
        )
    }
}

final class LensMultiPetAmbiguityReleaseGateTests: XCTestCase {
    private let targetBox = LensNormalizedRect(x: 0.30, y: 0.25, width: 0.25, height: 0.45)
    private let leftBox = LensNormalizedRect(x: 0.20, y: 0.25, width: 0.25, height: 0.45)
    private let rightBox = LensNormalizedRect(x: 0.40, y: 0.25, width: 0.25, height: 0.45)

    func testNearbyNativeDogsRemainSeparateCandidates() {
        let detections = [
            animal(id: "left", box: leftBox, confidence: 0.90),
            animal(id: "right", box: rightBox, confidence: 0.88)
        ]

        let candidates = LensPetRecognition.candidates(in: detections)

        XCTAssertEqual(candidates.count, 2)
    }

    func testEquidistantDogsAreAmbiguousForFrameCapture() throws {
        let target = try XCTUnwrap(
            LensPetRecognition.parse(animal(id: "target", box: targetBox, confidence: 0.9))?
                .withTrackID("track-1")
        )
        let detections = [
            animal(id: "left", box: leftBox, confidence: 0.90),
            animal(id: "right", box: rightBox, confidence: 0.90)
        ]

        XCTAssertNil(LensPetRecognition.bestSpatialMatch(in: detections, for: target))
    }

    func testAmbiguousCrossingSuspendsSafeLockAndRequiresNewTrack() throws {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 1, replacementStableFrames: 3)
        )
        let target = animal(id: "target", box: targetBox, confidence: 0.90)
        guard case .detected(let locked) = stabilizer.ingest([target]) else {
            return XCTFail("Expected initial lock")
        }

        let ambiguous = stabilizer.ingest([
            animal(id: "left", box: leftBox, confidence: 0.90),
            animal(id: "right", box: rightBox, confidence: 0.90)
        ])

        guard case .stabilizing(let retained, let progress) = ambiguous else {
            return XCTFail("Ambiguity must suspend safe detected status")
        }
        XCTAssertEqual(progress, 0)
        XCTAssertEqual(retained.trackID, locked.trackID)
        XCTAssertEqual(retained.boundingBox, locked.boundingBox)

        let right = animal(id: "right", box: rightBox, confidence: 0.92)
        XCTAssertFalse(stabilizer.ingest([right]).isDetected)
        XCTAssertFalse(stabilizer.ingest([right]).isDetected)
        guard case .detected(let reacquired) = stabilizer.ingest([right]) else {
            return XCTFail("Expected a newly stabilized track after ambiguity")
        }
        XCTAssertNotEqual(reacquired.trackID, locked.trackID)
        XCTAssertEqual(reacquired.boundingBox, rightBox)
    }

    private func animal(
        id: String,
        box: LensNormalizedRect,
        confidence: Double
    ) -> LensLocalDetection {
        LensLocalDetection(
            id: id,
            kind: .animal,
            label: "dog",
            confidence: confidence,
            boundingBox: box
        )
    }
}

final class LensPostConsentFrameGateTests: XCTestCase {
    func testPendingResolveWaitsForPostConsentCaptureEvent() {
        var gate = LensPostConsentFrameGate()
        gate.beginWaiting()

        XCTAssertFalse(gate.shouldRelease(eventAllowsRawPayloads: false))
        XCTAssertTrue(gate.isWaiting)
        XCTAssertTrue(gate.shouldRelease(eventAllowsRawPayloads: true))
        XCTAssertFalse(gate.isWaiting)
    }

    func testGatePassesEventsWhenNotWaiting() {
        var gate = LensPostConsentFrameGate()

        XCTAssertTrue(gate.shouldRelease(eventAllowsRawPayloads: false))
    }

    func testCancelClearsPendingWait() {
        var gate = LensPostConsentFrameGate()
        gate.beginWaiting()
        gate.cancel()

        XCTAssertFalse(gate.isWaiting)
        XCTAssertTrue(gate.shouldRelease(eventAllowsRawPayloads: false))
    }
}

extension LensMultiPetAmbiguityReleaseGateTests {
    func testBreedEnrichmentFusesOnlyWithMatchingSpatialPet() throws {
        let leftAnimal = animal(id: "left-animal", box: leftBox, confidence: 0.91)
        let rightAnimal = animal(id: "right-animal", box: rightBox, confidence: 0.93)
        let leftBreed = LensLocalDetection(
            id: "left-breed",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.89,
            boundingBox: leftBox
        )

        let candidates = LensPetRecognition.candidates(
            in: [rightAnimal, leftBreed, leftAnimal]
        )

        XCTAssertEqual(candidates.count, 2)
        let breed = try XCTUnwrap(candidates.first(where: { $0.breed == "Golden Retriever" }))
        XCTAssertEqual(breed.boundingBox, leftBox)
        let generic = try XCTUnwrap(candidates.first(where: { $0.breed == nil }))
        XCTAssertEqual(generic.boundingBox, rightBox)
    }

    func testLowEffectiveVisionConfidenceCannotEnterStabilization() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(minimumConfidence: 0.58, requiredStableFrames: 1)
        )
        let effective = LensObservationConfidence.effective(
            observation: 0.25,
            label: 0.95
        )
        let weak = animal(id: "weak", box: targetBox, confidence: effective)

        XCTAssertEqual(stabilizer.ingest([weak]), .searching)
    }
}

extension LensMultiPetAmbiguityReleaseGateTests {
    func testAmbiguousBreedEnrichmentIsDroppedRatherThanAttachedToWrongDog() {
        let leftAnimal = animal(id: "left-animal", box: leftBox, confidence: 0.91)
        let rightAnimal = animal(id: "right-animal", box: rightBox, confidence: 0.93)
        let ambiguousBreed = LensLocalDetection(
            id: "ambiguous-breed",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.95,
            boundingBox: targetBox
        )

        let candidates = LensPetRecognition.candidates(
            in: [leftAnimal, rightAnimal, ambiguousBreed]
        )

        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.allSatisfy { $0.breed == nil })
    }
}

extension LensSpatialTrackingReleaseTests {
    func testSameCenterWithExtremeSizeDifferenceIsDifferentInstance() throws {
        let large = LensNormalizedRect(x: 0.20, y: 0.20, width: 0.50, height: 0.50)
        let tiny = LensNormalizedRect(x: 0.40, y: 0.40, width: 0.10, height: 0.10)
        let largeDog = try XCTUnwrap(recognition(box: large))
        let tinyDog = try XCTUnwrap(recognition(box: tiny))

        XCTAssertFalse(largeDog.isSameInstance(as: tinyDog))
    }
}

final class LensBreedModelLabelContractTests: XCTestCase {
    private let box = LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)

    func testProductStructuredLabelCannotMasqueradeAsPet() {
        XCTAssertNil(parseObject("product|bowl|ceramic"))
    }

    func testUnknownStructuredSpeciesIsRejected() {
        XCTAssertNil(parseObject("pet|unicorn|Magic"))
    }

    func testSupportedStructuredBirdBreedIsAccepted() throws {
        let recognition = try XCTUnwrap(parseObject("pet|bird|Macaw"))

        XCTAssertEqual(recognition.category, "Pet")
        XCTAssertEqual(recognition.species, "Bird")
        XCTAssertEqual(recognition.breed, "Macaw")
    }

    private func parseObject(_ label: String) -> LensPetRecognition? {
        LensPetRecognition.parse(
            LensLocalDetection(
                kind: .object,
                label: label,
                confidence: 0.9,
                boundingBox: box
            )
        )
    }
}

extension LensBreedModelLabelContractTests {
    func testUnsupportedNativeAnimalIdentifierIsRejected() {
        let unsupported = LensLocalDetection(
            kind: .animal,
            label: "tiger",
            confidence: 0.99,
            boundingBox: box
        )

        XCTAssertNil(LensPetRecognition.parse(unsupported))
    }
}

extension LensResolutionReleaseGateTests {
    func testSnapshotExcludesOtherPetsFromTrackedResolution() throws {
        let left = LensNormalizedRect(x: 0.05, y: 0.25, width: 0.25, height: 0.45)
        let right = LensNormalizedRect(x: 0.70, y: 0.25, width: 0.25, height: 0.45)
        let targetDetection = LensLocalDetection(
            id: "left-dog",
            kind: .animal,
            label: "dog",
            confidence: 0.90,
            boundingBox: left
        )
        let otherDetection = LensLocalDetection(
            id: "right-dog",
            kind: .animal,
            label: "dog",
            confidence: 0.99,
            boundingBox: right
        )
        let target = try XCTUnwrap(
            LensPetRecognition.parse(targetDetection)?.withTrackID("track-left")
        )
        let snapshot = try LensResolutionSnapshot(
            recognition: target,
            boundFrame: nil,
            localDetections: [otherDetection, targetDetection],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            maximumFrameAge: 3
        )

        XCTAssertEqual(snapshot.makeRequest().localDetections.map(\.id), ["left-dog"])
    }

    func testAmbiguousPetMetadataIsOmittedRatherThanSendingWrongInstance() throws {
        let targetBox = LensNormalizedRect(x: 0.30, y: 0.25, width: 0.25, height: 0.45)
        let left = LensNormalizedRect(x: 0.20, y: 0.25, width: 0.25, height: 0.45)
        let right = LensNormalizedRect(x: 0.40, y: 0.25, width: 0.25, height: 0.45)
        let seed = LensLocalDetection(
            kind: .animal,
            label: "dog",
            confidence: 0.90,
            boundingBox: targetBox
        )
        let target = try XCTUnwrap(LensPetRecognition.parse(seed)?.withTrackID("track-1"))
        let detections = [
            LensLocalDetection(id: "left", kind: .animal, label: "dog", confidence: 0.9, boundingBox: left),
            LensLocalDetection(id: "right", kind: .animal, label: "dog", confidence: 0.9, boundingBox: right)
        ]
        XCTAssertThrowsError(
            try LensResolutionSnapshot(
                recognition: target,
                boundFrame: nil,
                localDetections: detections,
                context: LensContext(activePetID: "pet-1"),
                requiresFrame: false,
                maximumFrameAge: 3
            )
        ) { error in
            XCTAssertEqual(error as? LensResolutionSnapshotError, .unboundRecognition)
        }
    }
}

final class LensDetectorInvariantTests: XCTestCase {
    func testEffectiveConfidenceNeverExceedsEitherInputAcrossGrid() {
        for observationStep in 0...20 {
            for labelStep in 0...20 {
                let observation = Double(observationStep) / 20
                let label = Double(labelStep) / 20
                let effective = LensObservationConfidence.effective(
                    observation: observation,
                    label: label
                )

                XCTAssertGreaterThanOrEqual(effective, 0)
                XCTAssertLessThanOrEqual(effective, observation + 0.000_001)
                XCTAssertLessThanOrEqual(effective, label + 0.000_001)
            }
        }
    }

    func testSpatialAssociationIsSymmetricAcrossGrid() {
        let configuration = LensSpatialAssociationConfiguration.default
        for step in 0...10 {
            let first = LensNormalizedRect(
                x: 0.05 + Double(step) * 0.03,
                y: 0.20,
                width: 0.24,
                height: 0.42
            )
            let second = LensNormalizedRect(
                x: 0.60 - Double(step) * 0.02,
                y: 0.22,
                width: 0.22,
                height: 0.40
            )

            XCTAssertEqual(
                first.isSpatiallyAssociated(with: second, configuration: configuration),
                second.isSpatiallyAssociated(with: first, configuration: configuration)
            )
            XCTAssertEqual(
                first.intersectionOverUnion(with: second),
                second.intersectionOverUnion(with: first),
                accuracy: 0.000_001
            )
        }
    }

    func testTrackedResolutionNeverIncludesDistantSameSpeciesAcrossGrid() throws {
        let targetBox = LensNormalizedRect(x: 0.05, y: 0.25, width: 0.22, height: 0.42)
        let targetDetection = LensLocalDetection(
            id: "target",
            kind: .animal,
            label: "dog",
            confidence: 0.90,
            boundingBox: targetBox
        )
        let target = try XCTUnwrap(
            LensPetRecognition.parse(targetDetection)?.withTrackID("target-track")
        )

        for step in 0...12 {
            let other = LensLocalDetection(
                id: "other-\(step)",
                kind: .animal,
                label: "dog",
                confidence: 0.99,
                boundingBox: LensNormalizedRect(
                    x: 0.62 + Double(step) * 0.01,
                    y: 0.25,
                    width: 0.22,
                    height: 0.42
                )
            )
            let snapshot = try LensResolutionSnapshot(
                recognition: target,
                boundFrame: nil,
                localDetections: [other, targetDetection],
                context: LensContext(activePetID: "pet-1"),
                requiresFrame: false,
                maximumFrameAge: 3
            )

            XCTAssertEqual(snapshot.makeRequest().localDetections.map(\.id), ["target"])
        }
    }
}

final class LensDiscoveryReadinessReleaseGateTests: XCTestCase {
    private let recognition = LensPetRecognition(
        breed: nil,
        species: "Dog",
        confidence: 0.9,
        boundingBox: LensNormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5),
        sourceLabel: "dog",
        trackID: "track-1"
    )

    func testAmbiguousOrStabilizingStateCannotResolveMetadataOnly() {
        XCTAssertFalse(
            LensDiscoveryReadiness.isReady(
                isCameraInterrupted: false,
                detectorState: .stabilizing(recognition: recognition, progress: 0),
                requiresFrame: false,
                hasValidFrame: true
            )
        )
    }

    func testDetectedMetadataOnlyStateCanResolve() {
        XCTAssertTrue(
            LensDiscoveryReadiness.isReady(
                isCameraInterrupted: false,
                detectorState: .detected(recognition),
                requiresFrame: false,
                hasValidFrame: false
            )
        )
    }

    func testSelectedFrameStateRequiresFreshValidFrame() {
        XCTAssertFalse(
            LensDiscoveryReadiness.isReady(
                isCameraInterrupted: false,
                detectorState: .detected(recognition),
                requiresFrame: true,
                hasValidFrame: false
            )
        )
        XCTAssertTrue(
            LensDiscoveryReadiness.isReady(
                isCameraInterrupted: false,
                detectorState: .detected(recognition),
                requiresFrame: true,
                hasValidFrame: true
            )
        )
    }
}
