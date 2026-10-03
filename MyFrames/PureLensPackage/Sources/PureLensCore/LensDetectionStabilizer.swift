import Foundation

public struct LensSpatialAssociationConfiguration: Equatable, Sendable {
    public var minimumIntersectionOverUnion: Double
    public var maximumCenterDistance: Double
    public var centerDistanceScale: Double
    public var minimumAreaRatio: Double
    /// Minimum score gap required to choose one same-species subject when two
    /// candidates are both spatially plausible. Smaller gaps are held as
    /// ambiguous so the reticle and selected frame cannot jump between pets.
    public var minimumAssociationScoreSeparation: Double

    public init(
        minimumIntersectionOverUnion: Double = 0.08,
        maximumCenterDistance: Double = 0.30,
        centerDistanceScale: Double = 0.85,
        minimumAreaRatio: Double = 0.20,
        minimumAssociationScoreSeparation: Double = 0.25
    ) {
        self.minimumIntersectionOverUnion = min(max(minimumIntersectionOverUnion, 0), 1)
        self.maximumCenterDistance = min(max(maximumCenterDistance, 0.02), 1)
        self.centerDistanceScale = min(max(centerDistanceScale, 0.10), 2)
        self.minimumAreaRatio = min(max(minimumAreaRatio, 0), 1)
        self.minimumAssociationScoreSeparation = min(
            max(minimumAssociationScoreSeparation, 0),
            2
        )
    }

    public static let `default` = Self()
}

public struct LensPetRecognition: Codable, Equatable, Identifiable, Sendable {
    public var breed: String?
    public var species: String
    public var category: String
    public var confidence: Double
    public var boundingBox: LensNormalizedRect
    public var sourceLabel: String
    /// Ephemeral identifier assigned by the stabilizer to one spatially tracked pet.
    /// It is intentionally optional so raw classifier observations remain backward compatible.
    public var trackID: String?

    public var id: String { instanceIdentity }

    public var identity: String {
        [category, species, breed ?? ""]
            .map(Self.normalizedIdentityComponent)
            .joined(separator: "|")
    }

    /// Stable category/species identity used while breed detail is still being enriched.
    public var trackingIdentity: String {
        [category, species]
            .map(Self.normalizedIdentityComponent)
            .joined(separator: "|")
    }

    /// Stable identity for one visible pet. Breed enrichment does not change it.
    public var instanceIdentity: String {
        trackID ?? identity
    }

    public var primaryName: String {
        breed ?? species
    }

    public init(
        breed: String?,
        species: String,
        category: String = "Pet",
        confidence: Double,
        boundingBox: LensNormalizedRect,
        sourceLabel: String,
        trackID: String? = nil
    ) {
        let normalizedBreed = breed?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breed = normalizedBreed?.isEmpty == false ? normalizedBreed : nil
        self.species = species.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
        self.boundingBox = boundingBox
        self.sourceLabel = sourceLabel
        let normalizedTrackID = trackID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.trackID = normalizedTrackID?.isEmpty == false ? normalizedTrackID : nil
    }

    public func withTrackID(_ trackID: String?) -> Self {
        var copy = self
        let normalized = trackID?.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.trackID = normalized?.isEmpty == false ? normalized : nil
        return copy
    }

    public static func parse(_ detection: LensLocalDetection) -> Self? {
        LensPetLabelParser.parse(detection)
    }

    public static func preferred(
        in detections: [LensLocalDetection],
        minimumConfidence: Double = 0,
        spatialConfiguration: LensSpatialAssociationConfiguration = .default
    ) -> Self? {
        candidates(
            in: detections,
            minimumConfidence: minimumConfidence,
            spatialConfiguration: spatialConfiguration
        ).first
    }

    /// Returns one fused recognition per spatial pet instance rather than one
    /// global semantic winner. Generic species and breed observations fuse only
    /// when their boxes describe the same visible subject.
    public static func candidates(
        in detections: [LensLocalDetection],
        minimumConfidence: Double = 0,
        spatialConfiguration: LensSpatialAssociationConfiguration = .default
    ) -> [Self] {
        let floor = min(max(minimumConfidence, 0), 1)
        let parsed = detections
            .filter { $0.confidence >= floor }
            .compactMap { detection -> (recognition: Self, kind: LensDetectionKind)? in
                guard let recognition = parse(detection) else { return nil }
                return (recognition, detection.kind)
            }

        // Native animal observations are the geometric anchors. Each native
        // object starts its own cluster, then custom model output may enrich at
        // most one anchor. This prevents ordering or confidence from attaching
        // a breed label to the wrong nearby pet.
        let nativeAnimals = parsed
            .filter { $0.kind == .animal }
            .sorted { $0.recognition.confidence > $1.recognition.confidence }
        let customObjects = parsed
            .filter { $0.kind == .object }
            .sorted { $0.recognition.confidence > $1.recognition.confidence }

        var clusters = nativeAnimals.map { [$0] }
        for customObject in customObjects {
            let eligibleClusters = clusters.indices.compactMap { index -> (Int, Double)? in
                let cluster = clusters[index]
                guard !cluster.contains(where: { $0.kind == .object }) else { return nil }
                let score = cluster
                    .map { existing in
                        existing.recognition.spatialAssociationScore(
                            with: customObject.recognition,
                            configuration: spatialConfiguration
                        )
                    }
                    .max() ?? -.infinity
                guard score.isFinite,
                      cluster.contains(where: { existing in
                          existing.recognition.boundingBox.isSpatiallyAssociated(
                              with: customObject.recognition.boundingBox,
                              configuration: spatialConfiguration
                          )
                      })
                else {
                    return nil
                }
                return (index, score)
            }
            .sorted { lhs, rhs in lhs.1 > rhs.1 }

            if eligibleClusters.count > 1,
               eligibleClusters[0].1 - eligibleClusters[1].1
                < spatialConfiguration.minimumAssociationScoreSeparation {
                // A breed result equally plausible for two pets is unsafe.
                continue
            }
            if let bestIndex = eligibleClusters.first?.0 {
                clusters[bestIndex].append(customObject)
            } else {
                // Custom-only detection remains usable when Apple Vision did
                // not produce a corresponding animal observation.
                clusters.append([customObject])
            }
        }

        return clusters
            .compactMap { preferredRecognition(in: $0.map(\.recognition)) }
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.boundingBox.area > rhs.boundingBox.area
                }
                return lhs.confidence > rhs.confidence
            }
    }

    public static func bestSpatialMatch(
        in detections: [LensLocalDetection],
        for target: Self,
        minimumConfidence: Double = 0,
        spatialConfiguration: LensSpatialAssociationConfiguration = .default
    ) -> Self? {
        switch spatialMatch(
            in: candidates(
                in: detections,
                minimumConfidence: minimumConfidence,
                spatialConfiguration: spatialConfiguration
            ),
            for: target,
            spatialConfiguration: spatialConfiguration
        ) {
        case .match(let recognition):
            return recognition
        case .none, .ambiguous:
            return nil
        }
    }

    fileprivate static func spatialMatch(
        in recognitions: [Self],
        for target: Self,
        spatialConfiguration: LensSpatialAssociationConfiguration
    ) -> LensSpatialMatchResult {
        let ranked = recognitions
            .filter { target.isSameInstance(as: $0, configuration: spatialConfiguration) }
            .map { recognition in
                (
                    recognition: recognition,
                    score: target.spatialAssociationScore(
                        with: recognition,
                        configuration: spatialConfiguration
                    )
                )
            }
            .sorted { lhs, rhs in lhs.score > rhs.score }

        guard let strongest = ranked.first else { return .none }
        if ranked.count > 1,
           strongest.score - ranked[1].score
            < spatialConfiguration.minimumAssociationScoreSeparation {
            return .ambiguous
        }
        return .match(strongest.recognition)
    }

    /// Returns true when two observations can describe the same pet semantically
    /// while one classifier is still missing breed detail.
    public func isCompatible(with other: Self) -> Bool {
        guard trackingIdentity == other.trackingIdentity else { return false }
        switch (breed, other.breed) {
        case (.none, _), (_, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return Self.normalizedIdentityComponent(lhs) == Self.normalizedIdentityComponent(rhs)
        }
    }

    /// Semantic and spatial association for one visible pet instance.
    public func isSameInstance(
        as other: Self,
        configuration: LensSpatialAssociationConfiguration = .default
    ) -> Bool {
        guard isCompatible(with: other) else { return false }
        if let trackID, let otherTrackID = other.trackID, trackID != otherTrackID {
            return false
        }
        return boundingBox.isSpatiallyAssociated(
            with: other.boundingBox,
            configuration: configuration
        )
    }

    public func spatialAssociationScore(
        with other: Self,
        configuration: LensSpatialAssociationConfiguration = .default
    ) -> Double {
        guard isCompatible(with: other) else { return -.infinity }
        let iou = boundingBox.intersectionOverUnion(with: other.boundingBox)
        let distance = boundingBox.normalizedCenterDistance(to: other.boundingBox)
        return iou * 2 - distance / max(configuration.maximumCenterDistance, 0.001)
    }

    private static func preferredRecognition(in recognitions: [Self]) -> Self? {
        guard let strongest = recognitions.max(by: { $0.confidence < $1.confidence }) else {
            return nil
        }
        guard strongest.breed == nil else { return strongest }

        let maximumBreedConfidenceGap = 0.20
        let matchingBreed = recognitions
            .filter { $0.breed != nil && $0.trackingIdentity == strongest.trackingIdentity }
            .max(by: { $0.confidence < $1.confidence })
        if let matchingBreed,
           strongest.confidence - matchingBreed.confidence <= maximumBreedConfidenceGap {
            return matchingBreed
        }
        return strongest
    }

    private static func normalizedIdentityComponent(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private enum LensSpatialMatchResult {
    case none
    case ambiguous
    case match(LensPetRecognition)
}

public enum LensDetectorState: Equatable, Sendable {
    case searching
    case stabilizing(recognition: LensPetRecognition, progress: Double)
    case detected(LensPetRecognition)

    public var recognition: LensPetRecognition? {
        switch self {
        case .searching:
            return nil
        case .stabilizing(let recognition, _), .detected(let recognition):
            return recognition
        }
    }

    public var isDetected: Bool {
        if case .detected = self { return true }
        return false
    }
}

public struct LensDetectionStabilizer: Sendable {
    public struct Configuration: Equatable, Sendable {
        public var minimumConfidence: Double
        public var requiredStableFrames: Int
        public var replacementStableFrames: Int
        /// Consecutive absent or subthreshold observations tolerated while
        /// acquiring or retaining one subject. Missing frames never advance
        /// stabilization; competing and ambiguous subjects are not misses.
        public var lostFrameTolerance: Int
        public var spatialAssociation: LensSpatialAssociationConfiguration

        public init(
            minimumConfidence: Double = 0.45,
            requiredStableFrames: Int = 3,
            replacementStableFrames: Int = 4,
            lostFrameTolerance: Int = 2,
            spatialAssociation: LensSpatialAssociationConfiguration = .default
        ) {
            self.minimumConfidence = min(max(minimumConfidence, 0), 1)
            self.requiredStableFrames = max(1, requiredStableFrames)
            self.replacementStableFrames = max(1, replacementStableFrames)
            self.lostFrameTolerance = max(0, lostFrameTolerance)
            self.spatialAssociation = spatialAssociation
        }
    }

    private struct Candidate: Sendable {
        var recognition: LensPetRecognition
        var frameCount: Int
    }

    public private(set) var state: LensDetectorState = .searching

    private let configuration: Configuration
    private var candidate: Candidate?
    private var lockedRecognition: LensPetRecognition?
    private var missingFrameCount = 0
    private var requiresReacquisitionAfterAmbiguity = false

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    @discardableResult
    public mutating func ingest(_ detections: [LensLocalDetection]) -> LensDetectorState {
        let recognitions = LensPetRecognition.candidates(
            in: detections,
            minimumConfidence: configuration.minimumConfidence,
            spatialConfiguration: configuration.spatialAssociation
        )

        guard !recognitions.isEmpty else {
            return ingestMissingFrame()
        }

        if let lockedRecognition {
            if requiresReacquisitionAfterAmbiguity {
                missingFrameCount = 0
                guard let strongest = recognitions.first else {
                    return ingestMissingFrame()
                }
                candidate = updatedCandidate(with: strongest)
                let progress = min(
                    Double(candidate?.frameCount ?? 0)
                        / Double(configuration.replacementStableFrames),
                    1
                )
                if let candidate,
                   candidate.frameCount >= configuration.replacementStableFrames {
                    self.lockedRecognition = candidate.recognition
                    self.candidate = nil
                    requiresReacquisitionAfterAmbiguity = false
                    state = .detected(candidate.recognition)
                } else {
                    // Keep the last trustworthy geometry visible, but suspend
                    // safe detected status until one post-crossing subject has
                    // independently stabilized as a new track.
                    state = .stabilizing(recognition: lockedRecognition, progress: progress)
                }
                return state
            }

            switch spatialMatch(for: lockedRecognition, in: recognitions) {
            case .match(let matched):
                missingFrameCount = 0
                let updated = merge(lockedRecognition, with: matched)
                self.lockedRecognition = updated
                candidate = nil
                state = .detected(updated)
                return state
            case .ambiguous:
                // Preserve the last trustworthy reticle geometry, but stop
                // treating the identity as safe for frame capture or resolution.
                // Pure spatial tracking cannot prove which same-species pet
                // exited a crossing, so reacquisition must create a new track.
                missingFrameCount = 0
                candidate = nil
                requiresReacquisitionAfterAmbiguity = true
                state = .stabilizing(recognition: lockedRecognition, progress: 0)
                return state
            case .none:
                break
            }
        }

        missingFrameCount = 0
        guard let strongest = recognitions.first else {
            return ingestMissingFrame()
        }

        if let lockedRecognition {
            candidate = updatedCandidate(with: strongest)
            if let candidate,
               candidate.frameCount >= configuration.replacementStableFrames {
                self.lockedRecognition = candidate.recognition
                self.candidate = nil
                state = .detected(candidate.recognition)
            } else {
                state = .detected(lockedRecognition)
            }
            return state
        }

        let acceptedRecognition: LensPetRecognition
        if let candidate {
            switch spatialMatch(for: candidate.recognition, in: recognitions) {
            case .match(let matched):
                acceptedRecognition = matched
            case .ambiguous:
                // A tolerated gap must not let two crossing pets inherit one
                // another's accepted frames or track identity.
                self.candidate = nil
                state = .searching
                return state
            case .none:
                acceptedRecognition = strongest
            }
        } else {
            acceptedRecognition = strongest
        }

        candidate = updatedCandidate(with: acceptedRecognition)
        guard let candidate else {
            state = .searching
            return state
        }

        if candidate.frameCount >= configuration.requiredStableFrames {
            lockedRecognition = candidate.recognition
            self.candidate = nil
            state = .detected(candidate.recognition)
        } else {
            let progress = min(
                Double(candidate.frameCount) / Double(configuration.requiredStableFrames),
                1
            )
            state = .stabilizing(recognition: candidate.recognition, progress: progress)
        }
        return state
    }

    public mutating func reset() {
        candidate = nil
        lockedRecognition = nil
        missingFrameCount = 0
        requiresReacquisitionAfterAmbiguity = false
        state = .searching
    }

    private mutating func ingestMissingFrame() -> LensDetectorState {
        if let lockedRecognition {
            // Replacement/reacquisition candidates still require uninterrupted
            // evidence. Pre-lock tolerance must not weaken replacement safety.
            candidate = nil
            missingFrameCount += 1
            if missingFrameCount <= configuration.lostFrameTolerance {
                if requiresReacquisitionAfterAmbiguity {
                    state = .stabilizing(recognition: lockedRecognition, progress: 0)
                } else {
                    state = .detected(lockedRecognition)
                }
                return state
            }
        } else if let candidate {
            missingFrameCount += 1
            if missingFrameCount <= configuration.lostFrameTolerance {
                state = .stabilizing(
                    recognition: candidate.recognition,
                    progress: min(
                        Double(candidate.frameCount) / Double(configuration.requiredStableFrames),
                        1
                    )
                )
                return state
            }
        }
        candidate = nil
        lockedRecognition = nil
        missingFrameCount = 0
        requiresReacquisitionAfterAmbiguity = false
        state = .searching
        return state
    }

    private func spatialMatch(
        for target: LensPetRecognition,
        in recognitions: [LensPetRecognition]
    ) -> LensSpatialMatchResult {
        LensPetRecognition.spatialMatch(
            in: recognitions,
            for: target,
            spatialConfiguration: configuration.spatialAssociation
        )
    }

    private mutating func updatedCandidate(with recognition: LensPetRecognition) -> Candidate {
        if let candidate,
           candidate.recognition.isSameInstance(
            as: recognition,
            configuration: configuration.spatialAssociation
           ) {
            return Candidate(
                recognition: merge(candidate.recognition, with: recognition),
                frameCount: candidate.frameCount + 1
            )
        }
        let trackID = recognition.trackID ?? UUID().uuidString
        return Candidate(
            recognition: recognition.withTrackID(trackID),
            frameCount: 1
        )
    }

    private func merge(
        _ previous: LensPetRecognition,
        with current: LensPetRecognition
    ) -> LensPetRecognition {
        let weight = 0.42
        let preferredBreed = previous.breed ?? current.breed
        let sourceLabel: String
        if current.breed != nil || previous.breed == nil {
            sourceLabel = current.sourceLabel
        } else {
            sourceLabel = previous.sourceLabel
        }
        return LensPetRecognition(
            breed: preferredBreed,
            species: current.species,
            category: current.category,
            confidence: previous.confidence * (1 - weight) + current.confidence * weight,
            boundingBox: previous.boundingBox.interpolated(to: current.boundingBox, amount: weight),
            sourceLabel: sourceLabel,
            trackID: previous.trackID ?? current.trackID
        )
    }
}

public struct LensRecognitionFeedbackGate: Sendable {
    private var playbackDatesByIdentity: [String: Date] = [:]

    public init() {}

    public mutating func shouldPlay(
        for recognition: LensPetRecognition,
        at date: Date = Date(),
        cooldown: TimeInterval
    ) -> Bool {
        let safeCooldown = max(0, cooldown)
        let identity = recognition.instanceIdentity
        if let lastPlaybackDate = playbackDatesByIdentity[identity],
           date.timeIntervalSince(lastPlaybackDate) < safeCooldown {
            return false
        }
        playbackDatesByIdentity[identity] = date
        return true
    }

    public mutating func reset() {
        playbackDatesByIdentity.removeAll(keepingCapacity: true)
    }
}

public struct LensAutomaticResolutionGate: Sendable {
    private var startedTrackIdentities: Set<String> = []

    public init() {}

    public mutating func shouldStart(for recognition: LensPetRecognition) -> Bool {
        startedTrackIdentities.insert(recognition.instanceIdentity).inserted
    }

    public mutating func reset() {
        startedTrackIdentities.removeAll(keepingCapacity: true)
    }
}

public struct LensDetectorFailureGate: Sendable {
    private let cooldown: TimeInterval
    private var lastReportTimestamp: TimeInterval?

    public init(cooldown: TimeInterval = 5) {
        self.cooldown = max(0, cooldown)
    }

    public mutating func shouldReport(at timestamp: TimeInterval) -> Bool {
        guard timestamp.isFinite else { return false }
        if let lastReportTimestamp,
           timestamp >= lastReportTimestamp,
           timestamp - lastReportTimestamp < cooldown {
            return false
        }
        self.lastReportTimestamp = timestamp
        return true
    }

    public mutating func markHealthy() {
        lastReportTimestamp = nil
    }
}

private enum LensPetLabelParser {
    private static let speciesAliases: [String: String] = [
        "animal": "Animal",
        "dog": "Dog", "dogs": "Dog", "canine": "Dog", "puppy": "Dog",
        "cat": "Cat", "cats": "Cat", "feline": "Cat", "kitten": "Cat",
        "bird": "Bird", "birds": "Bird", "avian": "Bird", "parrot": "Bird",
        "rabbit": "Rabbit", "bunny": "Rabbit",
        "fish": "Fish", "reptile": "Reptile", "turtle": "Reptile",
        "snake": "Reptile", "lizard": "Reptile",
        "hamster": "Small Mammal", "guinea pig": "Small Mammal", "ferret": "Small Mammal",
        "small mammal": "Small Mammal", "horse": "Horse", "equine": "Horse",
        "camel": "Camel", "camels": "Camel", "sheep": "Sheep", "lamb": "Sheep",
        "goat": "Goat", "goats": "Goat", "cow": "Cow", "cows": "Cow", "cattle": "Cow"
    ]

    private static let allowedStructuredCategories: Set<String> = [
        "pet", "animal", "companion animal",
    ]

    private static let knownDogBreeds: Set<String> = [
        "golden retriever", "labrador retriever", "german shepherd", "poodle",
        "beagle", "bulldog", "french bulldog", "rottweiler", "doberman",
        "husky", "siberian husky", "chihuahua", "pomeranian", "shih tzu",
        "cocker spaniel", "border collie", "boxer", "great dane", "maltese",
        "yorkshire terrier", "samoyed", "cane corso", "pit bull", "dalmatian",
    ]

    private static let knownCatBreeds: Set<String> = [
        "persian", "siamese", "maine coon", "ragdoll", "bengal", "sphynx",
        "british shorthair", "scottish fold", "abyssinian", "birman",
        "russian blue", "american shorthair", "norwegian forest cat",
    ]

    static func parse(_ detection: LensLocalDetection) -> LensPetRecognition? {
        let raw = detection.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let structured = structuredParts(raw) {
            return LensPetRecognition(
                breed: structured.breed,
                species: structured.species,
                category: structured.category,
                confidence: detection.confidence,
                boundingBox: detection.boundingBox,
                sourceLabel: raw
            )
        }

        let cleaned = displayText(raw)
        let key = cleaned.lowercased()

        if let species = speciesAliases[key] {
            return LensPetRecognition(
                breed: nil,
                species: species,
                confidence: detection.confidence,
                boundingBox: detection.boundingBox,
                sourceLabel: raw
            )
        }

        if knownDogBreeds.contains(key) {
            return LensPetRecognition(
                breed: cleaned,
                species: "Dog",
                confidence: detection.confidence,
                boundingBox: detection.boundingBox,
                sourceLabel: raw
            )
        }

        if knownCatBreeds.contains(key) {
            return LensPetRecognition(
                breed: cleaned,
                species: "Cat",
                confidence: detection.confidence,
                boundingBox: detection.boundingBox,
                sourceLabel: raw
            )
        }

        // Unknown native identifiers are rejected rather than automatically
        // promoted to the Pet category. Supported species must be explicit in
        // the alias table, and custom object labels must follow the structured
        // pet contract above.
        return nil
    }

    private static func structuredParts(
        _ raw: String
    ) -> (category: String, species: String, breed: String?)? {
        let pipeParts = raw
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { displayText(String($0)) }
        if pipeParts.count >= 3,
           allowedStructuredCategories.contains(pipeParts[0].lowercased()),
           let species = canonicalPetSpecies(pipeParts[1]) {
            return (
                category: "Pet",
                species: species,
                breed: pipeParts[2].isEmpty ? nil : pipeParts[2]
            )
        }

        let colonParts = raw
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .map { displayText(String($0)) }
        if colonParts.count == 2,
           let species = canonicalPetSpecies(colonParts[0]) {
            return (
                category: "Pet",
                species: species,
                breed: colonParts[1].isEmpty ? nil : colonParts[1]
            )
        }
        return nil
    }

    private static func canonicalPetSpecies(_ value: String) -> String? {
        speciesAliases[value.lowercased()]
    }

    private static func displayText(_ raw: String) -> String {
        let spaced = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spaced.isEmpty else { return "" }
        return spaced
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                let value = String(token)
                guard value == value.lowercased() || value == value.uppercased() else {
                    return value
                }
                return value.prefix(1).uppercased() + value.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

public extension LensNormalizedRect {
    var area: Double {
        max(0, width) * max(0, height)
    }

    func intersectionOverUnion(with other: LensNormalizedRect) -> Double {
        let left = max(x, other.x)
        let bottom = max(y, other.y)
        let right = min(x + max(0, width), other.x + max(0, other.width))
        let top = min(y + max(0, height), other.y + max(0, other.height))
        let intersection = max(0, right - left) * max(0, top - bottom)
        let union = area + other.area - intersection
        guard union > 0 else { return 0 }
        return min(max(intersection / union, 0), 1)
    }

    func normalizedCenterDistance(to other: LensNormalizedRect) -> Double {
        let dx = (x + width / 2) - (other.x + other.width / 2)
        let dy = (y + height / 2) - (other.y + other.height / 2)
        return sqrt(dx * dx + dy * dy)
    }

    func isSpatiallyAssociated(
        with other: LensNormalizedRect,
        configuration: LensSpatialAssociationConfiguration = .default
    ) -> Bool {
        let largerArea = max(area, other.area)
        guard largerArea > 0 else { return false }
        let areaRatio = min(area, other.area) / largerArea
        guard areaRatio >= configuration.minimumAreaRatio else { return false }

        if intersectionOverUnion(with: other) >= configuration.minimumIntersectionOverUnion {
            return true
        }
        let averageExtent = max(
            0.02,
            (max(width, height) + max(other.width, other.height)) / 2
        )
        let adaptiveDistance = min(
            configuration.maximumCenterDistance,
            0.04 + averageExtent * configuration.centerDistanceScale
        )
        return normalizedCenterDistance(to: other) <= adaptiveDistance
    }

    fileprivate func interpolated(
        to other: LensNormalizedRect,
        amount: Double
    ) -> LensNormalizedRect {
        let t = min(max(amount, 0), 1)
        return LensNormalizedRect(
            x: x + (other.x - x) * t,
            y: y + (other.y - y) * t,
            width: width + (other.width - width) * t,
            height: height + (other.height - height) * t
        )
    }
}

/// A JPEG keyframe explicitly bound to one spatially tracked recognition.
public struct LensBoundFrame: Equatable, Sendable {
    public var frame: LensFrame
    public var recognition: LensPetRecognition
    public var capturedAt: Date

    public init(
        frame: LensFrame,
        recognition: LensPetRecognition,
        capturedAt: Date = Date()
    ) {
        self.frame = frame
        self.recognition = recognition
        self.capturedAt = capturedAt
    }

    public func isValid(
        for recognition: LensPetRecognition,
        at date: Date = Date(),
        maximumAge: TimeInterval,
        spatialConfiguration: LensSpatialAssociationConfiguration = .default
    ) -> Bool {
        let age = date.timeIntervalSince(capturedAt)
        guard age >= 0, age <= max(0, maximumAge) else { return false }
        return self.recognition.isSameInstance(
            as: recognition,
            configuration: spatialConfiguration
        )
    }
}

/// Throttles expensive frame analysis while treating camera timestamp rollback
/// as a new capture epoch after interruption or media-services recovery.
public struct LensFrameAnalysisGate: Sendable {
    private let minimumInterval: TimeInterval
    private var lastAnalysisTimestamp: TimeInterval?

    public init(minimumInterval: TimeInterval) {
        self.minimumInterval = max(0, minimumInterval)
    }

    public mutating func shouldAnalyze(timestamp: TimeInterval) -> Bool {
        guard timestamp.isFinite else {
            lastAnalysisTimestamp = nil
            return true
        }

        guard let lastAnalysisTimestamp else {
            self.lastAnalysisTimestamp = timestamp
            return true
        }

        let elapsed = timestamp - lastAnalysisTimestamp
        guard elapsed >= 0, elapsed < minimumInterval else {
            self.lastAnalysisTimestamp = timestamp
            return true
        }
        return false
    }

    public mutating func reset() {
        lastAnalysisTimestamp = nil
    }
}

/// Decides when the camera should materialize an uploadable frame.
/// A newly recognized identity bypasses the interval so the selected keyframe
/// always belongs to the currently detected pet.
public struct LensFrameCaptureGate: Sendable {
    private let minimumInterval: TimeInterval
    private var lastIdentity: String?
    private var lastCaptureTimestamp: TimeInterval?

    public init(minimumInterval: TimeInterval) {
        self.minimumInterval = max(0, minimumInterval)
    }

    public mutating func shouldCapture(
        identity: String?,
        timestamp: TimeInterval
    ) -> Bool {
        guard let identity, !identity.isEmpty, timestamp.isFinite else {
            return false
        }

        if identity != lastIdentity {
            lastIdentity = identity
            lastCaptureTimestamp = timestamp
            return true
        }

        guard let lastCaptureTimestamp else {
            self.lastCaptureTimestamp = timestamp
            return true
        }

        let elapsed = timestamp - lastCaptureTimestamp
        if elapsed < 0 {
            self.lastCaptureTimestamp = timestamp
            return true
        }
        guard elapsed >= minimumInterval else {
            return false
        }
        self.lastCaptureTimestamp = timestamp
        return true
    }

    public mutating func reset() {
        lastIdentity = nil
        lastCaptureTimestamp = nil
    }
}

/// Centralizes whether discovery is safe so manual and automatic paths cannot
/// resolve while a track is still stabilizing or suspended by multi-pet ambiguity.
public enum LensDiscoveryReadiness {
    public static func isReady(
        isCameraInterrupted: Bool,
        detectorState: LensDetectorState,
        requiresFrame: Bool,
        hasValidFrame: Bool
    ) -> Bool {
        guard !isCameraInterrupted,
              detectorState.isDetected
        else {
            return false
        }
        return !requiresFrame || hasValidFrame
    }
}
