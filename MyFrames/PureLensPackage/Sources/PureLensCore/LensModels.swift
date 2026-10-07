import Foundation

public enum LensDomain: String, Codable, CaseIterable, Sendable {
    case food
    case accessory
    case toy
    case medicine
    case veterinary
    case adoption
    case marketplace
    case unknown
}

public enum LensActionKind: String, Codable, CaseIterable, Sendable {
    case prepareCart
    case openProduct
    case bookVet
    case openVerifiedMedicine
    case createListingDraft
    case openAdoption
    case contactSupport
    case none

    public var isWriteAction: Bool {
        switch self {
        case .prepareCart, .createListingDraft:
            return true
        case .openProduct, .bookVet, .openVerifiedMedicine, .openAdoption, .contactSupport, .none:
            return false
        }
    }
}

public enum LensMedicalContent: String, Codable, Sendable {
    case none
    case verifiedPackageInformation
    case symptomTriage
    case diagnosis
    case dosage
}

public struct LensSafety: Codable, Equatable, Sendable {
    public var medicalContent: LensMedicalContent
    public var requiresHumanReview: Bool
    public var hasVerifiedSource: Bool

    public init(
        medicalContent: LensMedicalContent = .none,
        requiresHumanReview: Bool = false,
        hasVerifiedSource: Bool = true
    ) {
        self.medicalContent = medicalContent
        self.requiresHumanReview = requiresHumanReview
        self.hasVerifiedSource = hasVerifiedSource
    }
}

public struct LensEvidence: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var value: String

    public init(id: String = UUID().uuidString, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct LensAction: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: LensActionKind
    public var title: String
    public var subtitle: String?
    public var payload: [String: String]
    public var requiresConfirmation: Bool

    public init(
        id: String = UUID().uuidString,
        kind: LensActionKind,
        title: String,
        subtitle: String? = nil,
        payload: [String: String] = [:],
        requiresConfirmation: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.payload = payload
        self.requiresConfirmation = requiresConfirmation ?? kind.isWriteAction
    }
}

public struct LensInsight: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var domain: LensDomain
    public var confidence: Double
    public var petName: String?
    public var headline: String
    public var detail: String
    public var badge: String?
    public var priceText: String?
    public var action: LensAction
    public var evidence: [LensEvidence]
    public var safety: LensSafety
    public var expiresAt: Date?

    public init(
        id: String = UUID().uuidString,
        domain: LensDomain,
        confidence: Double,
        petName: String? = nil,
        headline: String,
        detail: String,
        badge: String? = nil,
        priceText: String? = nil,
        action: LensAction,
        evidence: [LensEvidence] = [],
        safety: LensSafety = .init(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.domain = domain
        self.confidence = confidence
        self.petName = petName
        self.headline = headline
        self.detail = detail
        self.badge = badge
        self.priceText = priceText
        self.action = action
        self.evidence = evidence
        self.safety = safety
        self.expiresAt = expiresAt
    }
}

public struct LensNormalizedRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum LensObservationConfidence {
    public static func effective(observation: Double, label: Double) -> Double {
        let safeObservation = observation.isFinite ? min(max(observation, 0), 1) : 0
        let safeLabel = label.isFinite ? min(max(label, 0), 1) : 0
        return safeObservation * safeLabel
    }
}

/// Maps only explicit animal identifiers emitted by Apple's on-device image
/// classifier. Exact matching prevents incidental labels such as `hotdog`,
/// `birdhouse`, or `computer_mouse` from becoming animal detections.
public enum LensAnimalClassificationTaxonomy {
    public static func species(for identifier: String) -> String? {
        let normalized = normalize(identifier)
        if isExcludedNonAnimal(normalized) { return nil }
        if let direct = speciesByIdentifier[normalized] {
            return direct
        }
        let tokens = normalized.split(separator: "_").map(String.init)
        if tokens.count > 1 {
            for token in tokens.reversed() {
                if isExcludedNonAnimal(token) { return nil }
                if let mapped = speciesByIdentifier[token] {
                    return mapped
                }
            }
        }
        return fallbackAnimalSpecies(for: normalized)
    }

    public static func specificAnimal(for identifier: String) -> String? {
        let normalized = normalize(identifier)
        if isExcludedNonAnimal(normalized) { return nil }
        if let specific = specificAnimalByIdentifier[normalized] {
            return specific
        }
        let tokens = normalized.split(separator: "_").map(String.init)
        if tokens.count > 1 {
            for token in tokens.reversed() {
                if let specific = specificAnimalByIdentifier[token] {
                    return specific
                }
            }
        }
        if let mapped = species(for: identifier) {
            return mapped.prefix(1).uppercased() + mapped.dropFirst()
        }
        return isAnimal(identifier: identifier) ? displayName(for: identifier) : nil
    }

    public static func isAnimal(identifier: String) -> Bool {
        let normalized = normalize(identifier)
        if isExcludedNonAnimal(normalized) {
            return false
        }
        return speciesByIdentifier[normalized] != nil
            || specificAnimalByIdentifier[normalized] != nil
            || animalGroupsByIdentifier[normalized] != nil
            || biologicalAnimalClasses.contains(normalized)
            || species(for: identifier) != nil
    }

    public static func displayName(for identifier: String) -> String? {
        let normalized = normalize(identifier)
        if let specific = specificAnimalByIdentifier[normalized] {
            return specific
        }
        guard isAnimal(identifier: identifier) else { return nil }
        let words = normalized.split(separator: "_")
        return words.map { word in
            word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    public static func animalGroup(for identifier: String) -> String? {
        let normalized = normalize(identifier)
        if let direct = animalGroupsByIdentifier[normalized] {
            return direct
        }
        let tokens = normalized.split(separator: "_").map(String.init)
        if tokens.count > 1 {
            for token in tokens.reversed() {
                if let group = animalGroupsByIdentifier[token] {
                    return group
                }
            }
        }
        return nil
    }

    private static func normalize(_ identifier: String) -> String {
        identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func fallbackAnimalSpecies(for normalized: String) -> String? {
        if isExcludedNonAnimal(normalized) { return nil }
        if let group = animalGroupsByIdentifier[normalized] {
            return group
        }
        return nil
    }

    private static func isExcludedNonAnimal(_ normalized: String) -> Bool {
        if nonAnimalIdentifiers.contains(normalized) { return true }
        let tokens = normalized.split(separator: "_").map(String.init)
        for token in tokens {
            if nonAnimalIdentifiers.contains(token) {
                return true
            }
        }
        return false
    }

    private static let nonAnimalIdentifiers: Set<String> = [
        "hotdog", "hot_dog", "birdhouse", "bird_house", "fishbowl", "fish_bowl",
        "computer_mouse", "mouse_pad", "fried_chicken", "chicken_nugget", "chicken_wing",
        "cat_litter", "dog_food", "cat_food", "bird_feeder", "dog_bone", "cat_toy",
        "leash", "collar", "aquarium_tank", "cage", "kennel", "carrier", "bed",
        "food", "toy", "bowl", "snack", "treat", "harness"
    ]

    private static let speciesByIdentifier: [String: String] = [
        // Retained for backward-compatibility with existing release gate contracts
        "dog": "dog",
        "canine": "dog",
        "puppy": "dog",
        "hound": "dog",
        "terrier": "dog",
        "retriever": "dog",
        "golden_retriever": "dog",
        "labrador_retriever": "dog",
        "german_shepherd": "dog",
        "poodle": "dog",
        "beagle": "dog",
        "bulldog": "dog",
        "french_bulldog": "dog",
        "rottweiler": "dog",
        "doberman": "dog",
        "boxer": "dog",
        "husky": "dog",
        "siberian_husky": "dog",
        "chihuahua": "dog",
        "pomeranian": "dog",
        "shih_tzu": "dog",
        "cocker_spaniel": "dog",
        "border_collie": "dog",
        "mastiff": "dog",
        "pug": "dog",
        "sheepdog": "dog",
        "maltese": "dog",
        "great_dane": "dog",
        "samoyed": "dog",
        "cane_corso": "dog",
        "dalmatian": "dog",

        "cat": "cat",
        "adult_cat": "cat",
        "feline": "cat",
        "kitten": "cat",
        "persian": "cat",
        "persian_cat": "cat",
        "siamese": "cat",
        "siamese_cat": "cat",
        "maine_coon": "cat",
        "ragdoll": "cat",
        "bengal": "cat",
        "bengal_cat": "cat",
        "sphynx": "cat",
        "sphynx_cat": "cat",
        "british_shorthair": "cat",
        "scottish_fold": "cat",
        "abyssinian": "cat",
        "birman": "cat",
        "russian_blue": "cat",
        "american_shorthair": "cat",
        "norwegian_forest_cat": "cat",

        "bird": "bird",
        "birds": "bird",
        "avian": "bird",
        "parrot": "bird",
        "cockatoo": "bird",
        "cockatiel": "bird",
        "parakeet": "bird",
        "budgerigar": "bird",
        "macaw": "bird",
        "canary": "bird",
        "finch": "bird",
        "lovebird": "bird",
        "conure": "bird",
        "african_grey": "bird",
        "falcon": "bird",
        "peregrine_falcon": "bird",
        "hawk": "bird",
        "eagle": "bird",
        "owl": "bird",
        "barn_owl": "bird",
        "hummingbird": "bird",
        "pigeon": "bird",
        "dove": "bird",
        "sparrow": "bird",
        "swan": "bird",
        "peacock": "bird",
        "duck": "bird",
        "goose": "bird",
        "chicken": "bird",
        "rooster": "bird",
        "turkey": "bird",
        "quail": "bird",
        "toucan": "bird",
        "pelican": "bird",
        "flamingo": "bird",
        "penguin": "bird",
        "ostrich": "bird",

        "rabbit": "rabbit",
        "bunny": "rabbit",
        "hare": "rabbit",
        "cottontail": "rabbit",

        "fish": "fish",
        "goldfish": "fish",
        "betta": "fish",
        "siamese_fighting_fish": "fish",
        "clownfish": "fish",
        "angelfish": "fish",
        "cichlid": "fish",
        "guppy": "fish",
        "tetra": "fish",
        "koi": "fish",
        "discus": "fish",
        "puffer_fish": "fish",
        "seahorse": "fish",
        "catfish": "fish",

        "reptile": "reptile",
        "lizard": "reptile",
        "monitor_lizard": "reptile",
        "iguana": "reptile",
        "chameleon": "reptile",
        "gecko": "reptile",
        "bearded_dragon": "reptile",
        "skink": "reptile",
        "snake": "reptile",
        "snake_other": "reptile",
        "python": "reptile",
        "boa": "reptile",
        "corn_snake": "reptile",
        "rattlesnake": "reptile",
        "turtle": "reptile",
        "tortoise": "reptile",
        "terrapin": "reptile",
        "alligator_crocodile": "reptile",
        "alligator": "reptile",
        "crocodile": "reptile",
        "frog": "reptile",
        "toad": "reptile",
        "salamander": "reptile",
        "newt": "reptile",

        "hamster": "small mammal",
        "guinea_pig": "small mammal",
        "ferret": "small mammal",
        "gerbil": "small mammal",
        "chinchilla": "small mammal",
        "rat": "small mammal",
        "mouse": "small mammal",
        "hedgehog": "small mammal",
        "squirrel": "small mammal",
        "chipmunk": "small mammal",
        "sugar_glider": "small mammal",
        "degu": "small mammal",
        "small_mammal": "small mammal",

        "horse": "horse",
        "pony": "horse",
        "foal": "horse",
        "equine": "horse",
        "camel": "camel",
        "dromedary": "camel",
        "donkey": "donkey",
        "mule": "donkey",
        "sheep": "sheep",
        "lamb": "sheep",
        "goat": "goat",
        "cow": "cow",
        "cattle": "cow",
        "calf": "cow",
        "bull": "cow",
        "pig": "pig",
        "piglet": "pig",
        "alpaca": "alpaca",
        "llama": "llama",

        "lion": "lion",
        "tiger": "tiger",
        "cheetah": "cheetah",
        "leopard": "leopard",
        "jaguar": "jaguar",
        "panther": "panther",
        "bear": "bear",
        "panda": "panda",
        "polar_bear": "polar_bear",
        "koala": "koala",
        "kangaroo": "kangaroo",
        "fox": "fox",
        "fennec_fox": "fox",
        "wolf": "wolf",
        "hyena": "hyena",
        "jackal": "jackal",
        "raccoon": "raccoon",
        "badger": "badger",
        "otter": "otter",
        "beaver": "beaver",
        "meerkat": "meerkat",
        "sloth": "sloth",
        "monkey": "monkey",
        "chimpanzee": "chimpanzee",
        "gorilla": "gorilla",
        "elephant": "elephant",
        "giraffe": "giraffe",
        "zebra": "zebra",
        "deer": "deer",
        "stag": "deer",
        "seal": "seal",
        "sea_lion": "seal",
        "walrus": "seal",
        "dolphin": "dolphin",
        "whale": "whale",
        "killer_whale": "whale",
        "orca": "whale",
        "rhino": "rhino",
        "rhinoceros": "rhino",
        "hippopotamus": "hippo",
        "hippo": "hippo",
        "antelope": "deer",
        "gazelle": "deer",
        "elk": "deer",
        "moose": "deer",
        "coyote": "wolf",
        "dingo": "dog",
        "orangutan": "monkey",
        "baboon": "monkey",
        "lemur": "monkey",
        "caiman": "reptile",
        "komodo_dragon": "reptile",
        "cobra": "reptile",
        "viper": "reptile",
        "anaconda": "reptile",
        "shark": "fish",
        "stingray": "fish",
        "ray": "fish"
    ]

    private static let specificAnimalByIdentifier: [String: String] = [
        "parrot": "Parrot",
        "cockatoo": "Cockatoo",
        "cockatiel": "Cockatiel",
        "parakeet": "Parakeet",
        "budgerigar": "Budgerigar",
        "macaw": "Macaw",
        "canary": "Canary",
        "finch": "Finch",
        "lovebird": "Lovebird",
        "falcon": "Falcon",
        "peregrine_falcon": "Peregrine Falcon",
        "eagle": "Eagle",
        "owl": "Owl",
        "pigeon": "Pigeon",
        "dove": "Dove",
        "duck": "Duck",
        "goose": "Goose",
        "swan": "Swan",
        "peacock": "Peacock",
        "chicken": "Chicken",
        "rooster": "Rooster",
        "turkey": "Turkey",

        "rabbit": "Rabbit",
        "bunny": "Rabbit",
        "hare": "Hare",
        "hamster": "Hamster",
        "guinea_pig": "Guinea Pig",
        "ferret": "Ferret",
        "gerbil": "Gerbil",
        "chinchilla": "Chinchilla",
        "hedgehog": "Hedgehog",
        "sugar_glider": "Sugar Glider",

        "turtle": "Turtle",
        "tortoise": "Tortoise",
        "terrapin": "Terrapin",
        "chameleon": "Chameleon",
        "gecko": "Gecko",
        "iguana": "Iguana",
        "lizard": "Lizard",
        "bearded_dragon": "Bearded Dragon",
        "monitor_lizard": "Monitor Lizard",
        "snake": "Snake",
        "python": "Python",
        "boa": "Boa",
        "frog": "Frog",
        "toad": "Toad",

        "goldfish": "Goldfish",
        "betta": "Betta Fish",
        "siamese_fighting_fish": "Betta Fish",
        "clownfish": "Clownfish",
        "angelfish": "Angelfish",
        "cichlid": "Cichlid",
        "koi": "Koi",
        "guppy": "Guppy",
        "tetra": "Tetra",
        "seahorse": "Seahorse",
        "puffer_fish": "Pufferfish",

        "horse": "Horse",
        "pony": "Pony",
        "camel": "Camel",
        "donkey": "Donkey",
        "sheep": "Sheep",
        "lamb": "Lamb",
        "goat": "Goat",
        "cow": "Cow",
        "pig": "Pig",
        "alpaca": "Alpaca",
        "llama": "Llama",

        "lion": "Lion",
        "tiger": "Tiger",
        "cheetah": "Cheetah",
        "leopard": "Leopard",
        "bear": "Bear",
        "panda": "Panda",
        "fox": "Fox",
        "fennec_fox": "Fennec Fox",
        "wolf": "Wolf",
        "hyena": "Hyena",
        "jackal": "Jackal",
        "meerkat": "Meerkat",
        "sloth": "Sloth",
        "monkey": "Monkey",
        "chimpanzee": "Chimpanzee",
        "elephant": "Elephant",
        "giraffe": "Giraffe",
        "zebra": "Zebra",
        "deer": "Deer",
        "kangaroo": "Kangaroo",
        "koala": "Koala",
        "penguin": "Penguin",
        "dolphin": "Dolphin",
        "whale": "Whale",
        "gorilla": "Gorilla",
        "orangutan": "Orangutan",
        "baboon": "Baboon",
        "rhino": "Rhinoceros",
        "hippo": "Hippopotamus",
        "antelope": "Antelope",
        "gazelle": "Gazelle",
        "elk": "Elk",
        "moose": "Moose",
        "crocodile": "Crocodile",
        "alligator": "Alligator",
        "shark": "Shark"
    ]

    private static let animalGroupsByIdentifier: [String: String] = [
        "dog": "mammal", "cat": "mammal", "horse": "mammal", "camel": "mammal",
        "rabbit": "mammal", "hamster": "mammal", "guinea_pig": "mammal", "ferret": "mammal",
        "chinchilla": "mammal", "sheep": "mammal", "goat": "mammal", "cow": "mammal",
        "lion": "mammal", "tiger": "mammal", "bear": "mammal", "monkey": "mammal",
        "elephant": "mammal", "deer": "mammal", "fox": "mammal", "fennec_fox": "mammal", "wolf": "mammal",
        "hyena": "mammal", "jackal": "mammal", "meerkat": "mammal", "sloth": "mammal",
        "cheetah": "mammal", "leopard": "mammal", "zebra": "mammal", "giraffe": "mammal",
        "panda": "mammal", "koala": "mammal", "kangaroo": "mammal",

        "bird": "bird", "parrot": "bird", "canary": "bird", "cockatiel": "bird",
        "cockatoo": "bird", "budgerigar": "bird", "falcon": "bird", "eagle": "bird",
        "owl": "bird", "pigeon": "bird", "dove": "bird", "duck": "bird", "swan": "bird",

        "reptile": "reptile", "lizard": "reptile", "chameleon": "reptile", "gecko": "reptile",
        "turtle": "reptile", "tortoise": "reptile", "snake": "reptile", "iguana": "reptile",

        "amphibian": "amphibian", "frog": "amphibian", "toad": "amphibian",

        "fish": "fish", "goldfish": "fish", "betta": "fish", "clownfish": "fish",
        "angelfish": "fish", "cichlid": "fish", "koi": "fish", "seahorse": "fish"
    ]

    private static let biologicalAnimalClasses: Set<String> = [
        "mammal", "mammalia", "bird", "aves", "reptile", "reptilia",
        "amphibian", "amphibia", "fish", "pisces", "chordata", "vertebrate",
        "carnivore", "carnivora", "herbivore", "rodent", "rodentia", "canine",
        "feline", "felidae", "canidae", "equine", "equidae", "bovine", "bovidae"
    ]
}

public enum LensBarcodePayloadPolicy: String, Codable, Sendable {
    case omitBarcodes
    case presenceOnly
    case includePayloads
}

public enum LensDetectionKind: String, Codable, Sendable {
    case animal
    case barcode
    case object
}

public struct LensLocalDetection: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: LensDetectionKind
    public var label: String
    public var confidence: Double
    public var boundingBox: LensNormalizedRect
    public var machineValue: String?

    public init(
        id: String = UUID().uuidString,
        kind: LensDetectionKind,
        label: String,
        confidence: Double,
        boundingBox: LensNormalizedRect,
        machineValue: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.machineValue = machineValue
    }
}

public extension Array where Element == LensLocalDetection {
    func sanitizedForRemote(
        barcodePayloadPolicy: LensBarcodePayloadPolicy
    ) -> [LensLocalDetection] {
        switch barcodePayloadPolicy {
        case .omitBarcodes:
            return filter { $0.kind != .barcode }
        case .presenceOnly:
            return map { detection in
                guard detection.kind == .barcode else { return detection }
                var redacted = detection
                redacted.machineValue = nil
                return redacted
            }
        case .includePayloads:
            return self
        }
    }
}

public extension Array where Element == LensLocalDetection {
    /// Restricts remote pet metadata to the single unambiguous spatial track
    /// selected by the stabilizer. This prevents other pets in the same frame
    /// from influencing resolution for the locked subject.
    func sanitizedForRemote(
        barcodePayloadPolicy: LensBarcodePayloadPolicy,
        recognition: LensPetRecognition?,
        spatialConfiguration: LensSpatialAssociationConfiguration
    ) -> [LensLocalDetection] {
        let privacySanitized = sanitizedForRemote(
            barcodePayloadPolicy: barcodePayloadPolicy
        )
        guard let recognition else { return privacySanitized }

        let petDetections = privacySanitized.filter {
            $0.kind == .animal || $0.kind == .object
        }
        guard let matched = LensPetRecognition.bestSpatialMatch(
            in: petDetections,
            for: recognition,
            spatialConfiguration: spatialConfiguration
        ) else {
            return privacySanitized.filter { $0.kind == .barcode }
        }

        return privacySanitized.filter { detection in
            if detection.kind == .barcode { return true }
            guard let parsed = LensPetRecognition.parse(detection) else { return false }
            return matched.isSameInstance(
                as: parsed,
                configuration: spatialConfiguration
            )
        }
    }
}

public struct LensFrame: Codable, Equatable, Sendable {
    public var data: Data
    public var mimeType: String
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(data: Data, mimeType: String = "image/jpeg", pixelWidth: Int, pixelHeight: Int) {
        self.data = data
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct LensContext: Codable, Equatable, Sendable {
    public var activePetID: String?
    public var activePetName: String?
    public var petIdentityConfidence: Double?
    public var proactiveHint: String?
    public var proactiveHintExpiresAt: Date?
    public var localeIdentifier: String
    public var timeZoneIdentifier: String
    public var clientVersion: String?
    public var attributes: [String: String]

    public init(
        activePetID: String? = nil,
        activePetName: String? = nil,
        petIdentityConfidence: Double? = nil,
        proactiveHint: String? = nil,
        proactiveHintExpiresAt: Date? = nil,
        localeIdentifier: String = Locale.current.identifier,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        clientVersion: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.activePetID = activePetID
        self.activePetName = activePetName
        self.petIdentityConfidence = petIdentityConfidence
        self.proactiveHint = proactiveHint
        self.proactiveHintExpiresAt = proactiveHintExpiresAt
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.clientVersion = clientVersion
        self.attributes = attributes
    }

}

public enum LensAnimalDetectionSource: String, Codable, Equatable, Sendable {
    case onDeviceVision
    case onDeviceCoreML
    case fusedOnDevice
    case serverAssisted
}

/// Ephemeral animal identity owned by one Pure Lens scanning session. It is
/// deliberately independent from a saved Pet Profile and is never persisted by
/// the package.
public struct DetectedAnimalContext: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var species: String
    public var breed: String?
    public var confidence: Double
    public var detectionSource: LensAnimalDetectionSource
    public var boundingBox: LensNormalizedRect
    public var trackID: String?
    /// Canonical live MainKinds scope. Nil means business support is unresolved or unsupported.
    public var businessMainKindID: Int?

    public init(
        id: String = UUID().uuidString,
        species: String,
        breed: String? = nil,
        confidence: Double,
        detectionSource: LensAnimalDetectionSource,
        boundingBox: LensNormalizedRect,
        trackID: String? = nil,
        businessMainKindID: Int? = nil
    ) {
        let normalizedBreed = breed?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.species = species.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breed = normalizedBreed?.isEmpty == false ? normalizedBreed : nil
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
        self.detectionSource = detectionSource
        self.boundingBox = boundingBox
        self.trackID = trackID
        self.businessMainKindID = businessMainKindID.flatMap { $0 > 0 ? $0 : nil }
    }

    public init(
        recognition: LensPetRecognition,
        minimumBreedConfidence: Double = 0.74,
        detectionSource: LensAnimalDetectionSource = .fusedOnDevice
    ) {
        let breedFloor = min(max(minimumBreedConfidence, 0), 1)
        self.init(
            species: recognition.species,
            breed: recognition.confidence >= breedFloor ? recognition.breed : nil,
            confidence: recognition.confidence,
            detectionSource: detectionSource,
            boundingBox: recognition.boundingBox,
            trackID: recognition.trackID
        )
    }
}

/// Privacy-minimal, ephemeral context for a user-initiated guidance handoff.
/// Camera data, geometry, tracking identity, and confidence stay inside Lens.
public struct LensGuidanceHandoff: Equatable, Sendable {
    public let species: String
    public let breed: String?
    public let displayName: String
    public let isSupported: Bool

    public init(animal: DetectedAnimalContext, displayName: String, isSupported: Bool = true) {
        let normalizedSpecies = animal.species
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBreed = animal.breed?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDisplayName = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        species = String(normalizedSpecies.prefix(80))
        if let normalizedBreed, !normalizedBreed.isEmpty {
            breed = String(normalizedBreed.prefix(120))
        } else {
            breed = nil
        }
        self.displayName = String(
            (normalizedDisplayName.isEmpty ? normalizedSpecies : normalizedDisplayName)
                .prefix(160)
        )
        self.isSupported = isSupported
    }
}

public enum LensDiscoveryCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case accessories
    case services
    case medicine
    case products
}

public enum LensDiscoveryItemKind: String, Codable, Equatable, Sendable {
    case accessory
    case service
    case medicine
    case product
}

public enum LensDiscoverySource: String, Codable, Equatable, Sendable {
    case marketplaceTaxonomy
    case imageSearch
}

public struct LensDiscoveryItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var category: LensDiscoveryCategory
    public var kind: LensDiscoveryItemKind
    public var title: String
    public var subtitle: String?
    public var priceText: String?
    public var imageURL: String?
    public var source: LensDiscoverySource
    public var petMainKindID: Int?
    public var visualScore: Double?
    public var marketplaceRank: Int
    public var metadata: [String: String]

    public init(
        id: String,
        category: LensDiscoveryCategory,
        kind: LensDiscoveryItemKind,
        title: String,
        subtitle: String? = nil,
        priceText: String? = nil,
        imageURL: String? = nil,
        source: LensDiscoverySource,
        petMainKindID: Int? = nil,
        visualScore: Double? = nil,
        marketplaceRank: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.category = category
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.priceText = priceText
        self.imageURL = imageURL
        self.source = source
        self.petMainKindID = petMainKindID
        self.visualScore = visualScore.map { min(max($0.isFinite ? $0 : 0, 0), 1) }
        self.marketplaceRank = max(0, marketplaceRank)
        self.metadata = metadata
    }
}

public struct LensImageSearchResult: Equatable, Sendable {
    public var items: [LensDiscoveryItem]
    public var detectedMainKindID: Int?

    public init(items: [LensDiscoveryItem], detectedMainKindID: Int? = nil) {
        self.items = items
        self.detectedMainKindID = detectedMainKindID
    }
}

public struct LensDiscoverySection: Equatable, Identifiable, Sendable {
    public var category: LensDiscoveryCategory
    public var items: [LensDiscoveryItem]
    public var isLoading: Bool
    public var didFail: Bool

    public var id: LensDiscoveryCategory { category }

    public init(
        category: LensDiscoveryCategory,
        items: [LensDiscoveryItem] = [],
        isLoading: Bool = false,
        didFail: Bool = false
    ) {
        self.category = category
        self.items = items
        self.isLoading = isLoading
        self.didFail = didFail
    }
}

public enum LensDiscoveryRanking {
    /// Species compatibility is enforced by the host before items reach this
    /// merger. Within that compatible set, a reliable breed match outranks
    /// visual similarity, which in turn outranks the marketplace's base order.
    public static func merge(
        taxonomyItems: [LensDiscoveryItem],
        imageItems: [LensDiscoveryItem],
        for animal: DetectedAnimalContext,
        category: LensDiscoveryCategory,
        limit: Int = 12
    ) -> [LensDiscoveryItem] {
        var unique: [String: LensDiscoveryItem] = [:]
        for item in taxonomyItems + imageItems where item.category == category {
            let key = "\(item.kind.rawValue)|\(item.id)"
            if let existing = unique[key] {
                unique[key] = preferred(existing, item, animal: animal)
            } else {
                unique[key] = item
            }
        }

        return unique.values
            .sorted { lhs, rhs in
                let left = score(lhs, animal: animal)
                let right = score(rhs, animal: animal)
                if left == right { return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
                return left > right
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    private static func preferred(
        _ lhs: LensDiscoveryItem,
        _ rhs: LensDiscoveryItem,
        animal: DetectedAnimalContext
    ) -> LensDiscoveryItem {
        let preferred = score(lhs, animal: animal) >= score(rhs, animal: animal) ? lhs : rhs
        var merged = preferred
        if merged.imageURL?.isEmpty != false {
            merged.imageURL = lhs.imageURL?.isEmpty == false ? lhs.imageURL : rhs.imageURL
        }
        if merged.priceText?.isEmpty != false {
            merged.priceText = lhs.priceText?.isEmpty == false ? lhs.priceText : rhs.priceText
        }
        return merged
    }

    private static func score(
        _ item: LensDiscoveryItem,
        animal: DetectedAnimalContext
    ) -> Double {
        let searchable = ([item.title, item.subtitle ?? ""] + Array(item.metadata.values))
            .joined(separator: " ")
            .lowercased()
        let breedBonus: Double
        if let breed = animal.breed?.lowercased(), !breed.isEmpty, searchable.contains(breed) {
            breedBonus = 200
        } else {
            breedBonus = 0
        }
        let visual = (item.visualScore ?? 0) * 100
        let sourceBonus = item.source == .imageSearch ? 10.0 : 0.0
        let marketplace = max(0, 50 - Double(item.marketplaceRank))
        return breedBonus + visual + sourceBonus + marketplace
    }
}

public struct LensResolveRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var capturedAt: Date
    public var frame: LensFrame?
    public var localDetections: [LensLocalDetection]
    public var stabilizedRecognition: LensPetRecognition?
    public var remoteProcessingConsentGranted: Bool
    public var remoteProcessingConsentVersion: String
    public var context: LensContext

    public init(
        id: String = UUID().uuidString,
        capturedAt: Date = Date(),
        frame: LensFrame?,
        localDetections: [LensLocalDetection],
        stabilizedRecognition: LensPetRecognition? = nil,
        remoteProcessingConsentGranted: Bool = false,
        remoteProcessingConsentVersion: String = "",
        context: LensContext
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.frame = frame
        self.localDetections = localDetections
        self.stabilizedRecognition = stabilizedRecognition
        self.remoteProcessingConsentGranted = remoteProcessingConsentGranted
        self.remoteProcessingConsentVersion = remoteProcessingConsentVersion
        self.context = context
    }
}

public enum LensResolutionSnapshotError: Error, Equatable, Sendable {
    case missingRecognition
    case missingFrame
    case invalidFrame
    case unboundRecognition
}

/// Immutable recognition, detections, context, consent, and optional selected
/// frame used for exactly one resolver request.
public struct LensResolutionSnapshot: Equatable, Sendable {
    public let generation: UUID
    public let recognition: LensPetRecognition?
    public let localDetections: [LensLocalDetection]
    public let context: LensContext
    public let frame: LensFrame?
    public let capturedAt: Date
    public let remoteProcessingConsentGranted: Bool
    public let remoteProcessingConsentVersion: String

    public init(
        generation: UUID = UUID(),
        recognition: LensPetRecognition?,
        boundFrame: LensBoundFrame?,
        localDetections: [LensLocalDetection],
        context: LensContext,
        requiresFrame: Bool,
        at date: Date = Date(),
        maximumFrameAge: TimeInterval,
        barcodePayloadPolicy: LensBarcodePayloadPolicy = .omitBarcodes,
        spatialConfiguration: LensSpatialAssociationConfiguration = .default,
        remoteProcessingConsentGranted: Bool = false,
        remoteProcessingConsentVersion: String = ""
    ) throws {
        self.generation = generation
        self.recognition = recognition
        self.context = context
        self.remoteProcessingConsentGranted = remoteProcessingConsentGranted
        self.remoteProcessingConsentVersion = remoteProcessingConsentVersion
        self.capturedAt = requiresFrame ? (boundFrame?.capturedAt ?? date) : date

        if let recognition {
            let spatialDetections = localDetections.filter {
                $0.kind == .animal || $0.kind == .object
            }
            guard LensPetRecognition.bestSpatialMatch(
                in: spatialDetections,
                for: recognition,
                spatialConfiguration: spatialConfiguration
            ) != nil else {
                throw LensResolutionSnapshotError.unboundRecognition
            }
        }

        self.localDetections = localDetections.sanitizedForRemote(
            barcodePayloadPolicy: barcodePayloadPolicy,
            recognition: recognition,
            spatialConfiguration: spatialConfiguration
        )

        if requiresFrame {
            guard let recognition else {
                throw LensResolutionSnapshotError.missingRecognition
            }
            guard let boundFrame else {
                throw LensResolutionSnapshotError.missingFrame
            }
            guard boundFrame.isValid(
                for: recognition,
                at: date,
                maximumAge: maximumFrameAge,
                spatialConfiguration: spatialConfiguration
            ) else {
                throw LensResolutionSnapshotError.invalidFrame
            }
            frame = boundFrame.frame
        } else {
            frame = nil
        }
    }

    public func makeRequest(capturedAt: Date? = nil) -> LensResolveRequest {
        LensResolveRequest(
            capturedAt: frame == nil ? (capturedAt ?? self.capturedAt) : self.capturedAt,
            frame: frame,
            localDetections: localDetections,
            stabilizedRecognition: recognition,
            remoteProcessingConsentGranted: remoteProcessingConsentGranted,
            remoteProcessingConsentVersion: remoteProcessingConsentVersion,
            context: context
        )
    }
}

public struct LensActionReceipt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        detail: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.metadata = metadata
    }
}

public enum LensCameraAuthorization: String, Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

/// Centralized consent rule for any metadata or image that leaves the device.
/// Raw barcode values always require explicit consent because they can encode
/// credentials, account links, health identifiers, or other sensitive data.
public enum LensRemoteProcessingConsentPolicy {
    public static func requiresConsent(
        hasConsent: Bool,
        requiresSelectedFrameConsent: Bool,
        selectedFrameWillBeUploaded: Bool,
        rawBarcodePayloadWillBeUploaded: Bool
    ) -> Bool {
        guard !hasConsent else { return false }
        if rawBarcodePayloadWillBeUploaded { return true }
        return requiresSelectedFrameConsent && selectedFrameWillBeUploaded
    }
}

/// Prevents an in-flight pre-consent camera event from releasing a resolver
/// that requires newly enabled sensitive metadata capture.
public struct LensPostConsentFrameGate: Sendable {
    public private(set) var isWaiting = false

    public init() {}

    public mutating func beginWaiting() {
        isWaiting = true
    }

    public mutating func cancel() {
        isWaiting = false
    }

    public mutating func shouldRelease(eventAllowsRawPayloads: Bool) -> Bool {
        guard isWaiting else { return true }
        guard eventAllowsRawPayloads else { return false }
        isWaiting = false
        return true
    }
}
