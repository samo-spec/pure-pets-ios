import Foundation
import UIKit

enum HomeModelAdapter {
    static func localized(_ key: String, fallback: String) -> String {
        let value = Language.get(key, alter: fallback) ?? fallback
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallback
            : value
    }

    static func categories(from models: [NSObject]) -> [HomeCategoryModel] {
        models.compactMap { model in
            let presentation = PPHomeDataBridge.categoryPresentation(for: model)
            let identifier = presentation["id"] as? String ?? ""
            let numericID =
                (presentation["numericID"] as? NSNumber)?.intValue ?? 0
            let stableID = identifier.isEmpty ? "main-kind-\(numericID)" : identifier
            guard numericID > 0 else { return nil }

            let title = presentation["title"] as? String ?? ""
            let rawImageURL = presentation["imageURL"] as? String ?? ""
            let imageURL = rawImageURL.isEmpty ? nil : rawImageURL
            let localImage = presentation["localImage"] as? UIImage
            let accent = presentation["accent"] as? UIColor ?? .ppPrimary

            return HomeCategoryModel(
                id: stableID,
                title: title.isEmpty
                    ? localized("home_pulse_category_fallback", fallback: "Pets")
                    : title,
                imageURL: imageURL,
                localImage: localImage,
                accent: accent,
                raw: model
            )
        }
    }

    static func pets(from profiles: [NSObject]) -> [HomePetModel] {
        profiles.map { profile in
            let presentation = PPHomeDataBridge.petPresentation(for: profile)
            let rawIdentifier = presentation["id"] as? String ?? ""
            let identifier = rawIdentifier.isEmpty
                ? "pet-\(Unmanaged.passUnretained(profile).toOpaque())"
                : rawIdentifier
            let rawImageURL = presentation["imageURL"] as? String ?? ""
            return HomePetModel(
                id: identifier,
                name: presentation["name"] as? String ?? "",
                breedOrCategory: presentation["context"] as? String ?? "",
                age: presentation["age"] as? String ?? "",
                imageURL: rawImageURL.isEmpty ? nil : rawImageURL,
                categoryID:
                    (presentation["categoryID"] as? NSNumber)?.intValue ?? 0,
                isDefault:
                    (presentation["isDefault"] as? NSNumber)?.boolValue ?? false,
                raw: profile
            )
        }
    }

    static func cards(
        from objects: [Any],
        context: PPCellContext,
        kind: HomeCardKind,
        limit: Int = 12
    ) -> [HomeCardModel] {
        var seen = Set<String>()
        var result: [HomeCardModel] = []
        for object in objects {
            guard result.count < limit else { break }
            let viewModel = PPHomeDataBridge.viewModel(
                object: object,
                context: context
            )
            let sourceObject = object as AnyObject
            let pointerID =
                "object-\(Unmanaged.passUnretained(sourceObject).toOpaque())"
            let candidate = (viewModel.modelID ?? "").trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let stableID = candidate.isEmpty ? pointerID : candidate
            guard seen.insert(stableID).inserted else { continue }
            result.append(
                HomeCardModel(
                    id: stableID,
                    kind: kind,
                    context: context,
                    viewModel: viewModel
                )
            )
        }
        return result
    }

    static func featuredOrder(from orders: [NSObject]) -> HomeOrderModel? {
        guard let order = PPHomeDataBridge.activeOrder(from: orders) else {
            return nil
        }
        let presentation = PPHomeDataBridge.orderPresentation(for: order)
        let rawIdentifier = presentation["id"] as? String ?? ""
        let identifier = rawIdentifier.isEmpty
            ? "order-\(Unmanaged.passUnretained(order).toOpaque())"
            : rawIdentifier
        return HomeOrderModel(
            id: identifier,
            reference: presentation["reference"] as? String ?? "",
            statusKey: presentation["statusKey"] as? String ?? "pending",
            statusTitle: presentation["statusTitle"] as? String ?? "",
            statusHint: presentation["statusHint"] as? String ?? "",
            symbol: presentation["symbol"] as? String ?? "shippingbox.fill",
            progress: presentation["progress"] as? Double ?? 0.16,
            itemCount: presentation["itemCount"] as? Int ?? 0,
            amount: presentation["amount"] as? String ?? "",
            previewImageURLs: presentation["images"] as? [String] ?? [],
            raw: order
        )
    }

    static func config(
        sections: [[AnyHashable: Any]],
        titleViewMode: String,
        premiumCareVisible: Bool,
        novaFloatingVisible: Bool,
        backgroundGlowsFaded: Bool,
        pureLensVisible: Bool,
        fromCache: Bool
    ) -> HomeConfigModel {
        var seen = Set<Int>()
        var resolvedSections: [HomeConfigSection] = []
        for row in sections {
            guard let identifier = (row["id"] as? NSNumber)?.intValue,
                  identifier >= 0,
                  seen.insert(identifier).inserted
            else {
                continue
            }
            let configuredVisibility =
                (row["visible"] as? NSNumber)?.boolValue ?? true
            resolvedSections.append(
                HomeConfigSection(
                    id: identifier,
                    type: row["type"] as? String ?? "",
                    isVisible: configuredVisibility &&
                        (identifier != 9 || premiumCareVisible),
                    metadata: row
                )
            )
        }

        if resolvedSections.isEmpty {
            resolvedSections = HomeConfigModel.fallback.sections.map { section in
                HomeConfigSection(
                    id: section.id,
                    type: section.type,
                    isVisible: section.isVisible &&
                        (section.id != 9 || premiumCareVisible),
                    metadata: section.metadata
                )
            }
        }

        let resolvedTitleMode = ["location", "search"].contains(titleViewMode)
            ? titleViewMode
            : "location"
        return HomeConfigModel(
            sections: resolvedSections,
            titleViewMode: resolvedTitleMode,
            premiumCareVisible: premiumCareVisible,
            novaFloatingVisible: novaFloatingVisible,
            backgroundGlowsFaded: backgroundGlowsFaded,
            pureLensVisible: pureLensVisible,
            cameFromCache: fromCache
        )
    }

    static func orderItemIDs(
        from orders: [NSObject],
        limit: Int = 8
    ) -> [String] {
        PPHomeDataBridge.buyAgainAccessoryIDs(from: orders, limit: limit)
    }

    static func selectedCategoryID(
        persistedID: Int?,
        initialID: Int?,
        categories: [HomeCategoryModel]
    ) -> Int? {
        let validIDs = Set(categories.map { mainKindID($0.raw) })
        if let initialID, initialID > 0, validIDs.contains(initialID) {
            return initialID
        }
        if let persistedID, persistedID > 0, validIDs.contains(persistedID) {
            return persistedID
        }
        return nil
    }

    static func mainKindID(_ model: NSObject) -> Int {
        let presentation = PPHomeDataBridge.categoryPresentation(for: model)
        return (presentation["numericID"] as? NSNumber)?.intValue ?? 0
    }

    private static func objectValue(_ object: NSObject, key: String) -> Any? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key)
    }

    private static func stringValue(_ object: NSObject, key: String) -> String {
        optionalStringValue(object, key: key) ?? ""
    }

    private static func optionalStringValue(
        _ object: NSObject,
        key: String
    ) -> String? {
        guard let value = objectValue(object, key: key) else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func integerValue(_ object: NSObject, key: String) -> Int {
        if let number = objectValue(object, key: key) as? NSNumber {
            return number.intValue
        }
        return 0
    }
}
