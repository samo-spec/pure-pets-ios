import XCTest
@testable import PureLensCore

final class LensDetectionStabilizerTests: XCTestCase {
    private let box = LensNormalizedRect(x: 0.2, y: 0.3, width: 0.5, height: 0.5)

    func testGenericVisionAnimalBecomesSpeciesRecognition() throws {
        let detection = LensLocalDetection(
            kind: .animal,
            label: "dog",
            confidence: 0.93,
            boundingBox: box
        )

        let recognition = try XCTUnwrap(LensPetRecognition.parse(detection))

        XCTAssertNil(recognition.breed)
        XCTAssertEqual(recognition.species, "Dog")
        XCTAssertEqual(recognition.category, "Pet")
        XCTAssertEqual(recognition.identity, "pet|dog|")
    }

    func testStructuredCoreMLLabelExposesBreedSpeciesAndCategory() throws {
        let detection = LensLocalDetection(
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.91,
            boundingBox: box
        )

        let recognition = try XCTUnwrap(LensPetRecognition.parse(detection))

        XCTAssertEqual(recognition.breed, "Golden Retriever")
        XCTAssertEqual(recognition.species, "Dog")
        XCTAssertEqual(recognition.category, "Pet")
        XCTAssertEqual(recognition.identity, "pet|dog|golden retriever")
    }

    func testBreedRecognitionWinsOverMoreConfidentGenericSpecies() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 1)
        )
        let generic = LensLocalDetection(
            id: "vision-dog",
            kind: .animal,
            label: "dog",
            confidence: 0.95,
            boundingBox: box
        )
        let breed = LensLocalDetection(
            id: "model-golden",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.78,
            boundingBox: box
        )

        let state = stabilizer.ingest([generic, breed])

        guard case .detected(let recognition) = state else {
            return XCTFail("Expected a stable detection")
        }
        XCTAssertEqual(recognition.breed, "Golden Retriever")
        XCTAssertEqual(recognition.species, "Dog")
    }

    func testWeakBreedDoesNotOverrideMuchStrongerGenericSpecies() {
        let generic = LensLocalDetection(
            id: "vision-dog",
            kind: .animal,
            label: "dog",
            confidence: 0.98,
            boundingBox: box
        )
        let weakBreed = LensLocalDetection(
            id: "model-golden",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.60,
            boundingBox: box
        )

        let recognition = LensPetRecognition.preferred(in: [generic, weakBreed])

        XCTAssertEqual(recognition?.species, "Dog")
        XCTAssertNil(recognition?.breed)
    }

    func testCandidateLocksOnlyAfterRequiredFrames() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(
                minimumConfidence: 0.60,
                requiredStableFrames: 3,
                replacementStableFrames: 3,
                lostFrameTolerance: 2
            )
        )
        let detection = animal("cat", confidence: 0.92)

        guard case .stabilizing(let firstRecognition, let firstProgress) = stabilizer.ingest([detection]) else {
            return XCTFail("Expected the first frame to begin stabilization")
        }
        XCTAssertEqual(firstRecognition.species, "Cat")
        XCTAssertNotNil(firstRecognition.trackID)
        XCTAssertEqual(firstProgress, 1.0 / 3.0, accuracy: 0.001)
        guard case .stabilizing(_, let progress) = stabilizer.ingest([detection]) else {
            return XCTFail("Expected stabilizing state")
        }
        XCTAssertEqual(progress, 2.0 / 3.0, accuracy: 0.001)
        guard case .detected(let recognition) = stabilizer.ingest([detection]) else {
            return XCTFail("Expected detected state")
        }
        XCTAssertEqual(recognition.species, "Cat")
    }

    func testShortDetectionGapDoesNotDropLock() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(
                minimumConfidence: 0.60,
                requiredStableFrames: 2,
                replacementStableFrames: 3,
                lostFrameTolerance: 2
            )
        )
        let dog = animal("dog", confidence: 0.94)
        _ = stabilizer.ingest([dog])
        _ = stabilizer.ingest([dog])

        guard case .detected = stabilizer.ingest([]) else {
            return XCTFail("First missing frame should retain lock")
        }
        guard case .detected = stabilizer.ingest([]) else {
            return XCTFail("Second missing frame should retain lock")
        }
        XCTAssertEqual(stabilizer.ingest([]), .searching)
    }

    func testPreLockGapRetainsProgressButStillRequiresThreeAcceptedFrames() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 3, lostFrameTolerance: 2)
        )
        let dog = animal("dog", confidence: 0.94)
        let first = stabilizer.ingest([dog])
        let trackID = first.recognition?.trackID
        XCTAssertNotNil(trackID)
        assertProgress(first, equals: 1.0 / 3.0)
        XCTAssertEqual(stabilizer.ingest([]), first)

        let second = stabilizer.ingest([dog])
        assertProgress(second, equals: 2.0 / 3.0)
        XCTAssertEqual(second.recognition?.trackID, trackID)
        XCTAssertEqual(stabilizer.ingest([]), second)
        XCTAssertEqual(stabilizer.ingest([]), second)

        let third = stabilizer.ingest([dog])
        XCTAssertTrue(third.isDetected)
        XCTAssertEqual(third.recognition?.trackID, trackID)
    }

    func testSubthresholdFrameDoesNotAdvanceOrLowerPreLockConfidence() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(minimumConfidence: 0.60, requiredStableFrames: 3, lostFrameTolerance: 2)
        )
        let dog = animal("dog", confidence: 0.94)
        let weakDog = animal("dog", confidence: 0.59)
        XCTAssertEqual(stabilizer.ingest([weakDog]), .searching)
        _ = stabilizer.ingest([dog])
        let second = stabilizer.ingest([dog])

        XCTAssertEqual(stabilizer.ingest([weakDog]), second)
        XCTAssertEqual(stabilizer.ingest([weakDog]), second)
        assertProgress(stabilizer.state, equals: 2.0 / 3.0)

        let third = stabilizer.ingest([dog])
        XCTAssertTrue(third.isDetected)
        XCTAssertEqual(third.recognition?.trackID, second.recognition?.trackID)
        XCTAssertEqual(third.recognition?.confidence ?? 0, 0.94, accuracy: 0.001)
    }

    func testExceedingPreLockGapToleranceDropsProgressAndStartsANewTrack() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 3, lostFrameTolerance: 2)
        )
        let dog = animal("dog", confidence: 0.94)
        _ = stabilizer.ingest([dog])
        let oldCandidate = stabilizer.ingest([dog])
        XCTAssertEqual(stabilizer.ingest([]), oldCandidate)
        XCTAssertEqual(stabilizer.ingest([]), oldCandidate)
        XCTAssertEqual(stabilizer.ingest([]), .searching)

        let fresh = stabilizer.ingest([dog])
        assertProgress(fresh, equals: 1.0 / 3.0)
        XCTAssertNotEqual(fresh.recognition?.trackID, oldCandidate.recognition?.trackID)
        assertProgress(stabilizer.ingest([dog]), equals: 2.0 / 3.0)
        XCTAssertTrue(stabilizer.ingest([dog]).isDetected)
    }

    func testZeroPreLockGapToleranceStillRequiresConsecutiveFrames() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 3, lostFrameTolerance: 0)
        )
        let dog = animal("dog", confidence: 0.94)
        _ = stabilizer.ingest([dog])
        let oldCandidate = stabilizer.ingest([dog])
        XCTAssertEqual(stabilizer.ingest([]), .searching)

        let fresh = stabilizer.ingest([dog])
        assertProgress(fresh, equals: 1.0 / 3.0)
        XCTAssertNotEqual(fresh.recognition?.trackID, oldCandidate.recognition?.trackID)
    }

    func testDifferentSpeciesAfterToleratedGapCannotInheritPreLockProgress() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 3, lostFrameTolerance: 2)
        )
        let dog = animal("dog", confidence: 0.94)
        let cat = animal("cat", confidence: 0.95)
        _ = stabilizer.ingest([dog])
        let dogCandidate = stabilizer.ingest([dog])
        _ = stabilizer.ingest([])

        let catCandidate = stabilizer.ingest([cat])
        assertProgress(catCandidate, equals: 1.0 / 3.0)
        XCTAssertEqual(catCandidate.recognition?.species, "Cat")
        XCTAssertNotEqual(catCandidate.recognition?.trackID, dogCandidate.recognition?.trackID)
        assertProgress(stabilizer.ingest([cat]), equals: 2.0 / 3.0)
        let locked = stabilizer.ingest([cat])
        XCTAssertTrue(locked.isDetected)
        XCTAssertEqual(locked.recognition?.trackID, catCandidate.recognition?.trackID)
    }

    func testDistantSameSpeciesAfterToleratedGapCannotInheritPreLockProgress() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 3, lostFrameTolerance: 2)
        )
        let left = LensLocalDetection(
            id: "left-dog", kind: .animal, label: "dog", confidence: 0.94,
            boundingBox: .init(x: 0.02, y: 0.3, width: 0.18, height: 0.25)
        )
        let right = LensLocalDetection(
            id: "right-dog", kind: .animal, label: "dog", confidence: 0.95,
            boundingBox: .init(x: 0.80, y: 0.3, width: 0.18, height: 0.25)
        )
        _ = stabilizer.ingest([left])
        let leftCandidate = stabilizer.ingest([left])
        _ = stabilizer.ingest([])

        let rightCandidate = stabilizer.ingest([right])
        assertProgress(rightCandidate, equals: 1.0 / 3.0)
        XCTAssertNotEqual(rightCandidate.recognition?.trackID, leftCandidate.recognition?.trackID)
        assertProgress(stabilizer.ingest([right]), equals: 2.0 / 3.0)
        let locked = stabilizer.ingest([right])
        XCTAssertTrue(locked.isDetected)
        XCTAssertEqual(locked.recognition?.trackID, rightCandidate.recognition?.trackID)
        XCTAssertEqual(locked.recognition?.boundingBox, right.boundingBox)
    }

    func testAmbiguousPreLockAssociationDiscardsProgressInsteadOfTreatingItAsAGap() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 3, lostFrameTolerance: 2)
        )
        let dog = animal("dog", confidence: 0.94)
        _ = stabilizer.ingest([dog])
        let original = stabilizer.ingest([dog])
        _ = stabilizer.ingest([])
        let first = LensLocalDetection(
            id: "crossing-first", kind: .animal, label: "dog", confidence: 0.94,
            boundingBox: .init(x: 0.19, y: 0.3, width: 0.5, height: 0.5)
        )
        let second = LensLocalDetection(
            id: "crossing-second", kind: .animal, label: "dog", confidence: 0.95,
            boundingBox: .init(x: 0.21, y: 0.3, width: 0.5, height: 0.5)
        )

        XCTAssertEqual(stabilizer.ingest([first, second]), .searching)
        XCTAssertEqual(stabilizer.ingest([]), .searching)
        let reacquired = stabilizer.ingest([dog])
        assertProgress(reacquired, equals: 1.0 / 3.0)
        XCTAssertNotEqual(reacquired.recognition?.trackID, original.recognition?.trackID)
        assertProgress(stabilizer.ingest([dog]), equals: 2.0 / 3.0)
        XCTAssertTrue(stabilizer.ingest([dog]).isDetected)
    }

    func testPreLockToleranceDoesNotRetainAReplacementCandidateAcrossAMiss() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 1, replacementStableFrames: 3, lostFrameTolerance: 2)
        )
        let dog = animal("dog", confidence: 0.94)
        let cat = animal("cat", confidence: 0.95)
        let lockedDog = stabilizer.ingest([dog])
        _ = stabilizer.ingest([cat])
        _ = stabilizer.ingest([cat])
        XCTAssertEqual(stabilizer.ingest([]), lockedDog)
        XCTAssertEqual(stabilizer.ingest([cat]), lockedDog)
        XCTAssertEqual(stabilizer.ingest([cat]), lockedDog)

        let lockedCat = stabilizer.ingest([cat])
        XCTAssertTrue(lockedCat.isDetected)
        XCTAssertEqual(lockedCat.recognition?.species, "Cat")
        XCTAssertNotEqual(lockedCat.recognition?.trackID, lockedDog.recognition?.trackID)
    }

    func testCompetingCandidateMustStabilizeBeforeReplacingLock() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(
                minimumConfidence: 0.60,
                requiredStableFrames: 2,
                replacementStableFrames: 3,
                lostFrameTolerance: 1
            )
        )
        let dog = animal("dog", confidence: 0.95)
        let cat = animal("cat", confidence: 0.96)
        _ = stabilizer.ingest([dog])
        _ = stabilizer.ingest([dog])

        guard case .detected(let first) = stabilizer.ingest([cat]) else {
            return XCTFail("Existing lock should remain during replacement stabilization")
        }
        XCTAssertEqual(first.species, "Dog")
        guard case .detected(let second) = stabilizer.ingest([cat]) else {
            return XCTFail("Existing lock should remain until replacement threshold")
        }
        XCTAssertEqual(second.species, "Dog")
        guard case .detected(let replacement) = stabilizer.ingest([cat]) else {
            return XCTFail("Replacement should lock")
        }
        XCTAssertEqual(replacement.species, "Cat")
    }


    func testAlternatingGenericAndBreedFramesShareOneStableCandidate() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(
                minimumConfidence: 0.60,
                requiredStableFrames: 3,
                replacementStableFrames: 3,
                lostFrameTolerance: 1
            )
        )
        let generic = animal("dog", confidence: 0.95)
        let breed = LensLocalDetection(
            id: "model-golden",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.78,
            boundingBox: box
        )

        guard case .stabilizing = stabilizer.ingest([generic]) else {
            return XCTFail("Expected the generic species to start one candidate")
        }
        guard case .stabilizing(_, let progress) = stabilizer.ingest([breed]) else {
            return XCTFail("Breed enrichment must continue the same candidate")
        }
        XCTAssertEqual(progress, 2.0 / 3.0, accuracy: 0.001)
        guard case .detected(let recognition) = stabilizer.ingest([generic]) else {
            return XCTFail("Alternating generic and breed frames should still lock")
        }
        XCTAssertEqual(recognition.species, "Dog")
        XCTAssertEqual(recognition.breed, "Golden Retriever")
    }

    func testGenericFrameDoesNotDowngradeLockedBreed() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(requiredStableFrames: 2)
        )
        let generic = animal("dog", confidence: 0.97)
        let breed = LensLocalDetection(
            id: "model-golden",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.79,
            boundingBox: box
        )

        _ = stabilizer.ingest([breed])
        _ = stabilizer.ingest([generic])
        guard case .detected(let locked) = stabilizer.state else {
            return XCTFail("Expected a locked recognition")
        }
        XCTAssertEqual(locked.breed, "Golden Retriever")

        guard case .detected(let updated) = stabilizer.ingest([generic]) else {
            return XCTFail("Generic confirmation should retain the lock")
        }
        XCTAssertEqual(updated.breed, "Golden Retriever")
    }

    func testDifferentBreedRequiresReplacementThreshold() {
        var stabilizer = LensDetectionStabilizer(
            configuration: .init(
                requiredStableFrames: 1,
                replacementStableFrames: 3
            )
        )
        let golden = LensLocalDetection(
            id: "golden",
            kind: .object,
            label: "pet|dog|Golden Retriever",
            confidence: 0.90,
            boundingBox: box
        )
        let labrador = LensLocalDetection(
            id: "labrador",
            kind: .object,
            label: "pet|dog|Labrador Retriever",
            confidence: 0.92,
            boundingBox: box
        )

        _ = stabilizer.ingest([golden])
        for _ in 0..<2 {
            guard case .detected(let current) = stabilizer.ingest([labrador]) else {
                return XCTFail("Existing breed should stay locked during replacement")
            }
            XCTAssertEqual(current.breed, "Golden Retriever")
        }
        guard case .detected(let replacement) = stabilizer.ingest([labrador]) else {
            return XCTFail("New breed should replace after the configured threshold")
        }
        XCTAssertEqual(replacement.breed, "Labrador Retriever")
    }

    func testFeedbackGateKeepsCooldownPerIdentityAcrossOtherPets() {
        var gate = LensRecognitionFeedbackGate()
        let dog = LensPetRecognition.parse(animal("dog", confidence: 0.95))!
        let cat = LensPetRecognition.parse(animal("cat", confidence: 0.95))!
        let start = Date(timeIntervalSince1970: 2_000)

        XCTAssertTrue(gate.shouldPlay(for: dog, at: start, cooldown: 5))
        XCTAssertTrue(gate.shouldPlay(for: cat, at: start.addingTimeInterval(1), cooldown: 5))
        XCTAssertFalse(gate.shouldPlay(for: dog, at: start.addingTimeInterval(2), cooldown: 5))
        XCTAssertTrue(gate.shouldPlay(for: dog, at: start.addingTimeInterval(5.1), cooldown: 5))
    }

    func testFeedbackGateDeduplicatesIdentityWithinCooldown() {
        var gate = LensRecognitionFeedbackGate()
        let dog = LensPetRecognition.parse(animal("dog", confidence: 0.95))!
        let cat = LensPetRecognition.parse(animal("cat", confidence: 0.95))!
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(gate.shouldPlay(for: dog, at: start, cooldown: 3))
        XCTAssertFalse(gate.shouldPlay(for: dog, at: start.addingTimeInterval(1), cooldown: 3))
        XCTAssertTrue(gate.shouldPlay(for: cat, at: start.addingTimeInterval(1), cooldown: 3))
        XCTAssertTrue(gate.shouldPlay(for: dog, at: start.addingTimeInterval(4), cooldown: 3))
    }

    func testRealWorldEffectiveConfidenceStabilizesUnderDefaultThreshold() {
        var stabilizer = LensDetectionStabilizer()
        // Typical real-world Vision animal detection: observation 0.72, label 0.70 => 0.504 effective confidence
        let effective = LensObservationConfidence.effective(observation: 0.72, label: 0.70)
        let dog = animal("dog", confidence: effective)

        let first = stabilizer.ingest([dog])
        assertProgress(first, equals: 1.0 / 3.0)

        let second = stabilizer.ingest([dog])
        assertProgress(second, equals: 2.0 / 3.0)

        let third = stabilizer.ingest([dog])
        XCTAssertTrue(third.isDetected)
        XCTAssertEqual(third.recognition?.species, "Dog")
    }

    private func assertProgress(
        _ state: LensDetectorState,
        equals expected: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .stabilizing(_, let progress) = state else {
            return XCTFail("Expected stabilization without a detection", file: file, line: line)
        }
        XCTAssertEqual(progress, expected, accuracy: 0.001, file: file, line: line)
    }

    private func animal(_ label: String, confidence: Double) -> LensLocalDetection {
        LensLocalDetection(
            kind: .animal,
            label: label,
            confidence: confidence,
            boundingBox: box
        )
    }
}

final class LensFrameCaptureGateTests: XCTestCase {
    func testCapturesFirstRecognizedIdentity() {
        var gate = LensFrameCaptureGate(minimumInterval: 0.9)

        XCTAssertTrue(gate.shouldCapture(identity: "pet|dog|golden retriever", timestamp: 1.0))
    }

    func testThrottlesRepeatedIdentityInsideMinimumInterval() {
        var gate = LensFrameCaptureGate(minimumInterval: 0.9)

        XCTAssertTrue(gate.shouldCapture(identity: "pet|dog|golden retriever", timestamp: 1.0))
        XCTAssertFalse(gate.shouldCapture(identity: "pet|dog|golden retriever", timestamp: 1.4))
        XCTAssertTrue(gate.shouldCapture(identity: "pet|dog|golden retriever", timestamp: 1.91))
    }

    func testCapturesChangedIdentityImmediately() {
        var gate = LensFrameCaptureGate(minimumInterval: 0.9)

        XCTAssertTrue(gate.shouldCapture(identity: "pet|dog|golden retriever", timestamp: 1.0))
        XCTAssertTrue(gate.shouldCapture(identity: "pet|cat|persian", timestamp: 1.2))
    }

    func testRejectsMissingIdentityWithoutMutatingThrottle() {
        var gate = LensFrameCaptureGate(minimumInterval: 0.9)

        XCTAssertFalse(gate.shouldCapture(identity: nil, timestamp: 1.0))
        XCTAssertTrue(gate.shouldCapture(identity: "pet|cat|persian", timestamp: 1.1))
    }

    func testReturningToEarlierTimestampStartsNewCaptureEpoch() {
        var gate = LensFrameCaptureGate(minimumInterval: 0.9)

        XCTAssertTrue(gate.shouldCapture(identity: "track-1", timestamp: 120))
        XCTAssertTrue(gate.shouldCapture(identity: "track-1", timestamp: 0.02))
    }
}


final class LensBoundFrameTests: XCTestCase {
    private let box = LensNormalizedRect(x: 0.2, y: 0.3, width: 0.5, height: 0.5)

    func testBreedFrameIsValidForGenericRecognitionOfSameSpecies() throws {
        let breed = try XCTUnwrap(LensPetRecognition.parse(detection("pet|dog|Golden Retriever", kind: .object)))
        let generic = try XCTUnwrap(LensPetRecognition.parse(detection("dog", kind: .animal)))
        let capturedAt = Date(timeIntervalSince1970: 10)
        let bound = LensBoundFrame(
            frame: LensFrame(data: Data([1, 2, 3]), pixelWidth: 100, pixelHeight: 200),
            recognition: breed,
            capturedAt: capturedAt
        )

        XCTAssertTrue(bound.isValid(for: generic, at: capturedAt.addingTimeInterval(1), maximumAge: 3))
    }

    func testDifferentBreedFrameIsRejected() throws {
        let golden = try XCTUnwrap(LensPetRecognition.parse(detection("pet|dog|Golden Retriever", kind: .object)))
        let labrador = try XCTUnwrap(LensPetRecognition.parse(detection("pet|dog|Labrador Retriever", kind: .object)))
        let capturedAt = Date(timeIntervalSince1970: 10)
        let bound = LensBoundFrame(
            frame: LensFrame(data: Data([1]), pixelWidth: 100, pixelHeight: 200),
            recognition: golden,
            capturedAt: capturedAt
        )

        XCTAssertFalse(bound.isValid(for: labrador, at: capturedAt.addingTimeInterval(1), maximumAge: 3))
    }

    func testStaleFrameIsRejected() throws {
        let recognition = try XCTUnwrap(LensPetRecognition.parse(detection("dog", kind: .animal)))
        let capturedAt = Date(timeIntervalSince1970: 10)
        let bound = LensBoundFrame(
            frame: LensFrame(data: Data([1]), pixelWidth: 100, pixelHeight: 200),
            recognition: recognition,
            capturedAt: capturedAt
        )

        XCTAssertFalse(bound.isValid(for: recognition, at: capturedAt.addingTimeInterval(3.01), maximumAge: 3))
    }

    private func detection(_ label: String, kind: LensDetectionKind) -> LensLocalDetection {
        LensLocalDetection(
            kind: kind,
            label: label,
            confidence: 0.9,
            boundingBox: box
        )
    }
}

final class LensResolutionSnapshotTests: XCTestCase {
    private let box = LensNormalizedRect(x: 0.2, y: 0.3, width: 0.5, height: 0.5)

    func testSelectedFrameSnapshotRejectsFrameFromDifferentPet() throws {
        let dog = try XCTUnwrap(recognition("pet|dog|Golden Retriever", kind: .object))
        let cat = try XCTUnwrap(recognition("pet|cat|Persian", kind: .object))
        let now = Date(timeIntervalSince1970: 100)
        let catFrame = LensBoundFrame(
            frame: LensFrame(data: Data([9]), pixelWidth: 120, pixelHeight: 180),
            recognition: cat,
            capturedAt: now
        )

        XCTAssertThrowsError(
            try LensResolutionSnapshot(
                recognition: dog,
                boundFrame: catFrame,
                localDetections: [
                    LensLocalDetection(
                        kind: .animal,
                        label: "dog",
                        confidence: 0.92,
                        boundingBox: box
                    )
                ],
                context: LensContext(activePetID: "pet-1"),
                requiresFrame: true,
                at: now,
                maximumFrameAge: 3
            )
        ) { error in
            XCTAssertEqual(error as? LensResolutionSnapshotError, .invalidFrame)
        }
    }

    func testSnapshotFreezesRecognitionDetectionsAndFrame() throws {
        let dogDetection = detection("pet|dog|Golden Retriever", kind: .object)
        let dog = try XCTUnwrap(LensPetRecognition.parse(dogDetection))
        let now = Date(timeIntervalSince1970: 100)
        let dogFrame = LensBoundFrame(
            frame: LensFrame(data: Data([1, 2, 3]), pixelWidth: 120, pixelHeight: 180),
            recognition: dog,
            capturedAt: now
        )
        let snapshot = try LensResolutionSnapshot(
            recognition: dog,
            boundFrame: dogFrame,
            localDetections: [dogDetection],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: true,
            at: now,
            maximumFrameAge: 3
        )

        let request = snapshot.makeRequest(capturedAt: now.addingTimeInterval(0.5))

        XCTAssertEqual(snapshot.recognition?.identity, dog.identity)
        XCTAssertEqual(request.capturedAt, now)
        XCTAssertEqual(request.localDetections, [dogDetection])
        XCTAssertEqual(request.frame, dogFrame.frame)
    }

    func testMetadataSnapshotDoesNotRequireRecognitionOrFrame() throws {
        let snapshot = try LensResolutionSnapshot(
            recognition: nil,
            boundFrame: nil,
            localDetections: [],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            at: Date(timeIntervalSince1970: 100),
            maximumFrameAge: 3
        )

        XCTAssertNil(snapshot.makeRequest().frame)
    }

    func testSnapshotCarriesRemoteProcessingConsentContract() throws {
        let targetDetection = detection("pet|dog|Golden Retriever", kind: .object)
        let target = try XCTUnwrap(LensPetRecognition.parse(targetDetection))
        let snapshot = try LensResolutionSnapshot(
            recognition: target,
            boundFrame: nil,
            localDetections: [targetDetection],
            context: LensContext(activePetID: "pet-1"),
            requiresFrame: false,
            at: Date(timeIntervalSince1970: 100),
            maximumFrameAge: 3,
            remoteProcessingConsentGranted: true,
            remoteProcessingConsentVersion: "purelens-3.0-google-gemini-no-retention-v1"
        )

        let request = snapshot.makeRequest()

        XCTAssertTrue(request.remoteProcessingConsentGranted)
        XCTAssertEqual(
            request.remoteProcessingConsentVersion,
            "purelens-3.0-google-gemini-no-retention-v1"
        )
    }

    private func recognition(
        _ label: String,
        kind: LensDetectionKind
    ) -> LensPetRecognition? {
        LensPetRecognition.parse(detection(label, kind: kind))
    }

    private func detection(
        _ label: String,
        kind: LensDetectionKind
    ) -> LensLocalDetection {
        LensLocalDetection(
            kind: kind,
            label: label,
            confidence: 0.9,
            boundingBox: box
        )
    }
}

final class LensFrameAnalysisGateTests: XCTestCase {
    func testAnalyzesFirstTimestampAndThrottlesNearbyFrames() {
        var gate = LensFrameAnalysisGate(minimumInterval: 0.38)

        XCTAssertTrue(gate.shouldAnalyze(timestamp: 10))
        XCTAssertFalse(gate.shouldAnalyze(timestamp: 10.20))
        XCTAssertTrue(gate.shouldAnalyze(timestamp: 10.38))
    }

    func testTimestampRollbackStartsANewAnalysisEpoch() {
        var gate = LensFrameAnalysisGate(minimumInterval: 0.38)

        XCTAssertTrue(gate.shouldAnalyze(timestamp: 120))
        XCTAssertTrue(gate.shouldAnalyze(timestamp: 0.02))
        XCTAssertFalse(gate.shouldAnalyze(timestamp: 0.20))
    }

    func testNonFiniteTimestampDoesNotPoisonFutureFrames() {
        var gate = LensFrameAnalysisGate(minimumInterval: 0.38)

        XCTAssertTrue(gate.shouldAnalyze(timestamp: .nan))
        XCTAssertTrue(gate.shouldAnalyze(timestamp: 4))
        XCTAssertFalse(gate.shouldAnalyze(timestamp: 4.10))
    }
}
