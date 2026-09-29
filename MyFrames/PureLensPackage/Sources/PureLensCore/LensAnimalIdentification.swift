import Foundation

public enum LensAnimalIdentificationStatus: String, Codable, Equatable, Sendable {
    case identified
    case uncertain
    case notAnimal = "not_animal"
}

/// Public, sanitized failure classification from the identity callable.
/// Firebase error details are parsed by the host adapter, never by the UI.
public enum LensAnimalIdentityServiceError: String, Error, Equatable, Sendable {
    case identityUnavailable = "identity_unavailable"
    case taxonomyUnavailable = "taxonomy_unavailable"

    public static func fromServerReason(_ reason: String?) -> Self? {
        guard let reason else { return nil }
        return Self(rawValue: reason)
    }
}

/// An uncertain identity proposed by the server. A candidate has no commerce
/// authority until the server verifies the selected species on the same frame.
public struct LensAnimalIdentityCandidate: Codable, Equatable, Sendable {
    public let commonName: String
    public let commonNameAr: String?
    public let canonicalSpecies: String
    public let scientificName: String?
    public let confidence: Double

    public init(commonName: String, commonNameAr: String? = nil, canonicalSpecies: String, scientificName: String?, confidence: Double) {
        self.commonName = String(commonName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        self.commonNameAr = commonNameAr.map {
            String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        }
        self.canonicalSpecies = String(canonicalSpecies.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        self.scientificName = scientificName.map {
            String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        }
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
    }

    private enum CodingKeys: String, CodingKey {
        case commonName, commonNameAr, canonicalSpecies, scientificName, confidence
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            commonName: try values.decode(String.self, forKey: .commonName),
            commonNameAr: try values.decodeIfPresent(String.self, forKey: .commonNameAr),
            canonicalSpecies: try values.decode(String.self, forKey: .canonicalSpecies),
            scientificName: try values.decodeIfPresent(String.self, forKey: .scientificName),
            confidence: try values.decode(Double.self, forKey: .confidence)
        )
    }
}

/// Mirrors the server's candidate presentation limits. These checks never grant
/// commerce authority; selecting a choice still requires server confirmation.
private enum LensAnimalCandidatePolicy {
    private static let broadNames: Set<String> = [
        "animal", "pet", "mammal", "bird", "reptile", "amphibian", "fish",
        "invertebrate", "big cat", "wild cat", "canine", "feline", "cat", "dog",
        "falcon", "parrot", "eagle", "owl"
    ]

    static func choices(
        from candidates: [LensAnimalIdentityCandidate],
        ambiguityReason: String?
    ) -> [LensAnimalIdentityCandidate] {
        guard ambiguityReason?.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() != "multiple_animals" else { return [] }
        var seen = Set<String>()
        var choices: [LensAnimalIdentityCandidate] = []
        for candidate in candidates.prefix(8) {
            let key = identityKey(candidate.canonicalSpecies)
            guard !key.isEmpty,
                  !broadNames.contains(key),
                  candidate.confidence.isFinite,
                  candidate.confidence >= 0.35,
                  identityKey(candidate.commonName) == key,
                  seen.insert(key).inserted else { continue }
            choices.append(candidate)
            if choices.count == 3 { break }
        }
        return choices.count >= 2 ? choices : []
    }

    private static func identityKey(_ value: String) -> String {
        value.decomposedStringWithCompatibilityMapping
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map { rawToken -> String in
                let token = String(rawToken)
                guard token.count > 3 else { return token }
                if token.hasSuffix("ies"), token.count > 4 {
                    return String(token.dropLast(3)) + "y"
                }
                if ["ches", "shes", "xes", "zes", "sses"].contains(where: { token.hasSuffix($0) }) {
                    return String(token.dropLast(2))
                }
                if token.hasSuffix("s"), !token.hasSuffix("ss") {
                    return String(token.dropLast())
                }
                return token
            }
            .joined(separator: " ")
    }
}

public struct LensAnimalSupportContext: Codable, Equatable, Sendable {
    public let mainKindID: Int
    public let nameEn: String
    public let nameAr: String
    public let matchedBy: String

    public init(mainKindID: Int, nameEn: String, nameAr: String, matchedBy: String) {
        self.mainKindID = mainKindID
        self.nameEn = nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
        self.nameAr = nameAr.trimmingCharacters(in: .whitespacesAndNewlines)
        self.matchedBy = matchedBy.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func filterCompatible(_ items: [LensDiscoveryItem]) -> [LensDiscoveryItem] {
        guard mainKindID > 0 else { return [] }
        return items.filter { $0.petMainKindID == mainKindID }
    }
}
public struct LensCommerceScope: Equatable, Sendable {
    public let mainKindID: Int

    public init?(mainKindID: Int) {
        guard mainKindID > 0 else { return nil }
        self.mainKindID = mainKindID
    }

    public init?(result: LensAnimalIdentificationResult) {
        guard result.status == .identified,
              LensLocalIdentitySpecificity.isSufficientForSupport(species: result.canonicalSpecies),
              let id = result.support?.mainKindID,
              id > 0 else { return nil }
        mainKindID = id
    }

    public func filterCompatible(_ items: [LensDiscoveryItem]) -> [LensDiscoveryItem] {
        items.filter { $0.petMainKindID == mainKindID }
    }

    public func filteredImageSearch(_ result: LensImageSearchResult) -> [LensDiscoveryItem] {
        if let detectedMainKindID = result.detectedMainKindID,
           detectedMainKindID != mainKindID {
            return []
        }
        return filterCompatible(result.items)
    }
}

public struct LensAnimalIdentificationResult: Codable, Equatable, Sendable {
    public let status: LensAnimalIdentificationStatus
    public let commonName: String
    public let commonNameAr: String?
    public let canonicalSpecies: String
    public let scientificName: String?
    public let animalGroup: String?
    public let breed: String?
    public let speciesConfidence: Double
    public let breedConfidence: Double
    public let ambiguityReason: String?
    public let candidates: [LensAnimalIdentityCandidate]
    public let support: LensAnimalSupportContext?

    public var isSupported: Bool {
        status == .identified
            && LensLocalIdentitySpecificity.isSufficientForSupport(species: canonicalSpecies)
            && (support?.mainKindID ?? 0) > 0
    }

    public init(
        status: LensAnimalIdentificationStatus,
        commonName: String,
        commonNameAr: String? = nil,
        canonicalSpecies: String,
        scientificName: String? = nil,
        animalGroup: String? = nil,
        breed: String? = nil,
        speciesConfidence: Double,
        breedConfidence: Double = 0,
        ambiguityReason: String? = nil,
        candidates: [LensAnimalIdentityCandidate] = [],
        support: LensAnimalSupportContext?
    ) {
        self.status = status
        self.commonName = Self.clean(commonName, limit: 160)
        self.commonNameAr = Self.optionalClean(commonNameAr, limit: 160)
        self.canonicalSpecies = Self.clean(canonicalSpecies, limit: 160)
        self.scientificName = Self.optionalClean(scientificName, limit: 160)
        self.animalGroup = Self.optionalClean(animalGroup, limit: 80)
        self.speciesConfidence = Self.clamp(speciesConfidence)
        self.breedConfidence = Self.clamp(breedConfidence)
        let cleanBreed = Self.optionalClean(breed, limit: 120)
        self.breed = self.breedConfidence >= 0.78 ? cleanBreed : nil
        self.ambiguityReason = status == .identified
            ? nil
            : Self.optionalClean(ambiguityReason, limit: 80)
        self.candidates = status == .uncertain
            ? LensAnimalCandidatePolicy.choices(from: candidates, ambiguityReason: ambiguityReason)
            : []
        self.support = status == .identified ? support : nil
    }

    private enum CodingKeys: String, CodingKey {
        case status, commonName, commonNameAr, canonicalSpecies, scientificName, animalGroup
        case breed, speciesConfidence, breedConfidence, ambiguityReason, candidates, support
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            status: try values.decode(LensAnimalIdentificationStatus.self, forKey: .status),
            commonName: try values.decode(String.self, forKey: .commonName),
            commonNameAr: try values.decodeIfPresent(String.self, forKey: .commonNameAr),
            canonicalSpecies: try values.decode(String.self, forKey: .canonicalSpecies),
            scientificName: try values.decodeIfPresent(String.self, forKey: .scientificName),
            animalGroup: try values.decodeIfPresent(String.self, forKey: .animalGroup),
            breed: try values.decodeIfPresent(String.self, forKey: .breed),
            speciesConfidence: try values.decode(Double.self, forKey: .speciesConfidence),
            breedConfidence: try values.decodeIfPresent(Double.self, forKey: .breedConfidence) ?? 0,
            ambiguityReason: try values.decodeIfPresent(String.self, forKey: .ambiguityReason),
            candidates: try values.decodeIfPresent([LensAnimalIdentityCandidate].self, forKey: .candidates) ?? [],
            support: try values.decodeIfPresent(LensAnimalSupportContext.self, forKey: .support)
        )
    }

    public func refinedAnimal(
        from fallback: DetectedAnimalContext,
        minimumBreedConfidence: Double = 0.78
    ) -> DetectedAnimalContext {
        guard status == .identified else { return fallback }
        let speciesName = commonName.isEmpty ? canonicalSpecies : commonName
        let breedFloor = Self.clamp(minimumBreedConfidence)
        let refinedBreed = breedConfidence >= breedFloor ? breed : nil
        return DetectedAnimalContext(
            id: fallback.id,
            species: speciesName.isEmpty ? fallback.species : speciesName,
            breed: refinedBreed,
            confidence: speciesConfidence,
            detectionSource: .serverAssisted,
            boundingBox: fallback.boundingBox,
            trackID: fallback.trackID,
            businessMainKindID: support?.mainKindID
        )
    }

    private static func clean(_ value: String, limit: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    private static func optionalClean(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let clean = self.clean(value, limit: limit)
        return clean.isEmpty ? nil : clean
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

public enum LensAnimalIdentificationDestination: Equatable, Sendable {
    case discovery
    case unsupported
    case uncertain
    case notAnimal
}

public enum LensAnimalIdentificationRouting {
    public static func destination(
        for result: LensAnimalIdentificationResult
    ) -> LensAnimalIdentificationDestination {
        switch result.status {
        case .identified:
            guard LensLocalIdentitySpecificity.isSufficientForSupport(
                species: result.canonicalSpecies
            ) else { return .uncertain }
            return result.isSupported ? .discovery : .unsupported
        case .uncertain:
            return .uncertain
        case .notAnimal:
            return .notAnimal
        }
    }
}
public enum LensLocalIdentitySpecificity {
    private static let broadLabels: Set<String> = [
        "", "animal", "animals", "bird", "birds", "mammal", "mammals",
        "reptile", "reptiles", "fish", "fishes", "small mammal", "small mammals",
        "cats", "dogs", "falcons"
    ]

    public static func isSufficientForSupport(species: String) -> Bool {
        let normalized = species
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return !broadLabels.contains(normalized)
    }
}

public enum LensAnimalDiscoveryDecision: Equatable, Sendable {
    case discover(LensCommerceScope)
    case unsupported
    case uncertain
    case notAnimal
}

public enum LensAnimalDiscoveryPolicy {
    public static func decision(
        for result: LensAnimalIdentificationResult
    ) -> LensAnimalDiscoveryDecision {
        switch LensAnimalIdentificationRouting.destination(for: result) {
        case .discovery:
            guard let scope = LensCommerceScope(result: result) else {
                return .unsupported
            }
            return .discover(scope)
        case .unsupported:
            return .unsupported
        case .uncertain:
            return .uncertain
        case .notAnimal:
            return .notAnimal
        }
    }
}
