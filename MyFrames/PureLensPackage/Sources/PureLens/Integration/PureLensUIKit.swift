#if canImport(UIKit)
import PureLensCore
import SwiftUI
import UIKit

@MainActor
public enum PureLensUIKit {
    public static func makeViewController(module: PureLensModule) -> UIViewController {
        let controller = UIHostingController(rootView: PureLensView(module: module))
        controller.modalPresentationStyle = .fullScreen
        controller.view.backgroundColor = .black
        return controller
    }
}

@MainActor
@objc
public protocol PureLensViewControllerDelegate: AnyObject {
    @objc(pureLensSearchImage:contentType:animal:completion:)
    func pureLensSearchImage(
        _ imageData: NSData,
        contentType: String,
        animal: NSDictionary,
        completion: @escaping (NSArray?, NSError?) -> Void
    )

    @objc(pureLensSearchMarketplace:animal:completion:)
    func pureLensSearchMarketplace(
        _ category: String,
        animal: NSDictionary,
        completion: @escaping (NSArray?, NSError?) -> Void
    )

    @objc(pureLensOpenDiscoveryItem:completion:)
    func pureLensOpenDiscoveryItem(
        _ item: NSDictionary,
        completion: @escaping (NSError?) -> Void
    )

    @objc optional func pureLensTrackEvent(
        _ name: String,
        properties: NSDictionary
    )
}

@objcMembers
public final class PureLensObjCConfiguration: NSObject {
    /// Retained for source compatibility with the previous resolver bridge.
    /// Discovery no longer calls this endpoint or requires its PetProfile IDs.
    public let endpoint: URL
    public let activePetID: String?
    public let activePetName: String?
    public let petIdentityConfidence: Double
    public let proactiveHint: String?
    public let proactiveHintExpiresAt: Date?
    public let hapticsEnabled: Bool
    public let remoteProcessingDisclosure: String?
    public let hasPriorRemoteProcessingConsent: Bool
    public let remoteProcessingConsentVersion: String
    public let localeIdentifier: String?

    @objc(initWithEndpoint:activePetID:activePetName:petIdentityConfidence:proactiveHint:proactiveHintExpiresAt:hapticsEnabled:remoteProcessingDisclosure:hasPriorRemoteProcessingConsent:remoteProcessingConsentVersion:localeIdentifier:)
    public init(
        endpoint: URL,
        activePetID: String? = nil,
        activePetName: String? = nil,
        petIdentityConfidence: Double = 0,
        proactiveHint: String? = nil,
        proactiveHintExpiresAt: Date? = nil,
        hapticsEnabled: Bool = true,
        remoteProcessingDisclosure: String? = nil,
        hasPriorRemoteProcessingConsent: Bool = false,
        remoteProcessingConsentVersion: String = "",
        localeIdentifier: String? = nil
    ) {
        self.endpoint = endpoint
        self.activePetID = activePetID
        self.activePetName = activePetName
        self.petIdentityConfidence = petIdentityConfidence
        self.proactiveHint = proactiveHint
        self.proactiveHintExpiresAt = proactiveHintExpiresAt
        self.hapticsEnabled = hapticsEnabled
        self.remoteProcessingDisclosure = remoteProcessingDisclosure
        self.hasPriorRemoteProcessingConsent = hasPriorRemoteProcessingConsent
        self.remoteProcessingConsentVersion = remoteProcessingConsentVersion
        self.localeIdentifier = localeIdentifier
    }
}

@objcMembers
@MainActor
public final class PureLensViewControllerFactory: NSObject {
    @objc(makeViewControllerWithConfiguration:delegate:)
    public static func makeViewController(
        configuration: PureLensObjCConfiguration,
        delegate: PureLensViewControllerDelegate
    ) -> UIViewController {
        let delegateBox = WeakLensDelegateBox(delegate)
        let itemLimit = PureLensConfiguration.production.discoveryItemLimit
        let discovery = LensDiscoveryClient(
            searchByImage: { frame, animal in
                let rows: NSArray = try await withCheckedThrowingContinuation { continuation in
                    guard let delegate = delegateBox.value else {
                        continuation.resume(throwing: PureLensBridgeError.delegateReleased)
                        return
                    }
                    delegate.pureLensSearchImage(
                        frame.data as NSData,
                        contentType: frame.mimeType,
                        animal: PureLensDiscoveryDictionaryAdapter.dictionary(for: animal)
                    ) { rows, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: rows ?? [])
                        }
                    }
                }
                return LensImageSearchResult(
                    items: try PureLensDiscoveryDictionaryAdapter.items(from: rows, limit: itemLimit)
                )
            },
            searchMarketplace: { category, animal in
                let rows: NSArray = try await withCheckedThrowingContinuation { continuation in
                    guard let delegate = delegateBox.value else {
                        continuation.resume(throwing: PureLensBridgeError.delegateReleased)
                        return
                    }
                    delegate.pureLensSearchMarketplace(
                        category.rawValue,
                        animal: PureLensDiscoveryDictionaryAdapter.dictionary(for: animal)
                    ) { rows, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: rows ?? [])
                        }
                    }
                }
                return try PureLensDiscoveryDictionaryAdapter.items(from: rows, limit: itemLimit)
                    .filter { $0.category == category }
            }
        )

        let module = PureLensModule.production(
            configuration: PureLensConfiguration(
                hapticsEnabled: configuration.hapticsEnabled,
                hasPriorRemoteProcessingConsent: configuration.hasPriorRemoteProcessingConsent,
                remoteProcessingConsentVersion: configuration.remoteProcessingConsentVersion,
                remoteProcessingDisclosure: configuration.remoteProcessingDisclosure,
                localeIdentifier: configuration.localeIdentifier
            ),
            discovery: discovery,
            actionHandler: { item in
                try await withCheckedThrowingContinuation { continuation in
                    guard let delegate = delegateBox.value else {
                        continuation.resume(throwing: PureLensBridgeError.delegateReleased)
                        return
                    }
                    delegate.pureLensOpenDiscoveryItem(
                        PureLensDiscoveryDictionaryAdapter.dictionary(for: item)
                    ) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
            },
            analytics: LensAnalyticsClient { name, properties in
                Task { @MainActor in
                    delegateBox.value?.pureLensTrackEvent?(
                        name,
                        properties: NSDictionary(dictionary: properties)
                    )
                }
            }
        )

        return PureLensUIKit.makeViewController(module: module)
    }
}

private final class WeakLensDelegateBox: @unchecked Sendable {
    weak var value: PureLensViewControllerDelegate?

    init(_ value: PureLensViewControllerDelegate) {
        self.value = value
    }
}

public enum PureLensDiscoveryDictionaryAdapter {
    public static func items(from rows: NSArray, limit: Int) throws -> [LensDiscoveryItem] {
        var items: [LensDiscoveryItem] = []
        var identities = Set<String>()
        for case let row as NSDictionary in rows {
            guard let item = item(from: row) else { continue }
            let identity = "\(item.kind.rawValue)|\(item.id)"
            guard identities.insert(identity).inserted else { continue }
            items.append(item)
            if items.count >= limit { break }
        }
        return items
    }

    public static func item(from row: NSDictionary) -> LensDiscoveryItem? {
        guard let identifier = trimmedString(row["id"]),
              let categoryValue = trimmedString(row["category"]),
              let category = LensDiscoveryCategory(rawValue: categoryValue),
              let kindValue = trimmedString(row["kind"]),
              let kind = LensDiscoveryItemKind(rawValue: kindValue),
              let title = trimmedString(row["title"]),
              let sourceValue = trimmedString(row["source"]),
              let source = LensDiscoverySource(rawValue: sourceValue)
        else { return nil }

        let rawMetadata = row["metadata"] as? [String: Any] ?? [:]
        let metadata = rawMetadata.reduce(into: [String: String]()) { result, element in
            if let value = element.value as? String {
                result[element.key] = String(value.prefix(240))
            }
        }
        return LensDiscoveryItem(
            id: identifier,
            category: category,
            kind: kind,
            title: title,
            subtitle: trimmedString(row["subtitle"]),
            priceText: trimmedString(row["priceText"]),
            imageURL: trimmedString(row["imageURL"]),
            source: source,
            petMainKindID: (row["petMainKindID"] as? NSNumber)?.intValue,
            visualScore: (row["visualScore"] as? NSNumber)?.doubleValue,
            marketplaceRank: (row["marketplaceRank"] as? NSNumber)?.intValue ?? 0,
            metadata: metadata
        )
    }

    public static func dictionary(for animal: DetectedAnimalContext) -> NSDictionary {
        var value: [String: Any] = [
            "id": animal.id,
            "species": animal.species,
            "confidence": animal.confidence,
            "detectionSource": animal.detectionSource.rawValue
        ]
        if let breed = animal.breed { value["breed"] = breed }
        if let trackID = animal.trackID { value["trackID"] = trackID }
        return value as NSDictionary
    }

    public static func dictionary(for item: LensDiscoveryItem) -> NSDictionary {
        var value: [String: Any] = [
            "id": item.id,
            "category": item.category.rawValue,
            "kind": item.kind.rawValue,
            "title": item.title,
            "source": item.source.rawValue,
            "metadata": item.metadata
        ]
        if let subtitle = item.subtitle { value["subtitle"] = subtitle }
        if let priceText = item.priceText { value["priceText"] = priceText }
        if let imageURL = item.imageURL { value["imageURL"] = imageURL }
        if let mainKindID = item.petMainKindID { value["petMainKindID"] = mainKindID }
        if let visualScore = item.visualScore { value["visualScore"] = visualScore }
        return value as NSDictionary
    }

    private static func trimmedString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(500))
    }
}

private enum PureLensBridgeError: Error {
    case delegateReleased
}

#endif
