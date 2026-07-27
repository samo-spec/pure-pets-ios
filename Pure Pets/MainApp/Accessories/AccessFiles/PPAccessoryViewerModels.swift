import Foundation
import UIKit

enum PPAccessoryViewerL10n {
    @inline(__always)
    static func text(_ key: String) -> String {
        let localized = PPAccessoryViewerLegacyBridge.localizedText(
            key: key,
            fallback: key
        )
        return localized.isEmpty ? key : localized
    }
}

enum PPAccessoryViewerScreenPhase: Equatable {
    case loading
    case loaded
    case failed(message: String)
}

enum PPAccessoryViewerSectionPhase: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(message: String)
}

enum PPAccessoryViewerCartPhase: Equatable {
    case ready
    case processing
    case success
    case failed
}

/// Error cases for the async ``PPAccessoryViewerStore/addToCartAsync()`` bridge.
enum PPAccessoryCartError: Error {
    case unavailable
    case outOfStock
    case offline
    case failed
}

struct PPAccessoryViewerMediaItem: Identifiable, Equatable {
    let id: String
    let imageURL: String?
    let videoURL: String?
    let blurHash: String?
    let isVideo: Bool

    static func items(from accessory: PetAccessory) -> [Self] {
        let mapped = accessory.imageItems.enumerated().compactMap {
            index,
            item in
            makeItem(from: item, index: index)
        }
        if !mapped.isEmpty {
            return mapped
        }

        return accessory.imageURLsArray.enumerated().compactMap {
            index,
            value in
            let url = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return nil }
            return Self(
                id: "\(index)-\(url)",
                imageURL: url,
                videoURL: nil,
                blurHash: accessory.blurHash,
                isVideo: false
            )
        }
    }

    private static func makeItem(
        from item: PetImageItem,
        index: Int
    ) -> Self? {
        let rawURL = item.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawVideoURL =
            item.videoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mediaType = item.mediaType.lowercased()
        let isVideo = item.isVideoMedia || mediaType.contains("video")
        let metadata = item.mediaMetadata ?? [:]
        let thumbnail =
            (metadata["thumbnail_url"] as? String) ??
            (metadata["thumbnailURL"] as? String) ??
            (metadata["thumbnailUrl"] as? String) ??
            (metadata["thumbnail"] as? String)
        let cleanThumbnail =
            thumbnail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedVideoURL: String? = {
            guard isVideo else { return nil }
            if let rawVideoURL, !rawVideoURL.isEmpty {
                return rawVideoURL
            }
            return rawURL.isEmpty ? nil : rawURL
        }()
        let resolvedImageURL: String? = {
            guard isVideo else {
                return rawURL.isEmpty ? nil : rawURL
            }
            if let cleanThumbnail, !cleanThumbnail.isEmpty {
                return cleanThumbnail
            }
            if !rawURL.isEmpty, rawURL != resolvedVideoURL {
                return rawURL
            }
            return nil
        }()

        guard resolvedImageURL != nil || resolvedVideoURL != nil else {
            return nil
        }
        return Self(
            id: "\(index)-\(resolvedVideoURL ?? resolvedImageURL ?? rawURL)",
            imageURL: resolvedImageURL,
            videoURL: resolvedVideoURL,
            blurHash: item.blurHash ?? accessoryFallbackHash(item: item),
            isVideo: isVideo
        )
    }

    private static func accessoryFallbackHash(item: PetImageItem) -> String? {
        item.blurHash
    }
}

struct PPAccessoryViewerDetailItem: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let symbol: String
    let tone: PPAccessoryViewerDetailTone
}

enum PPAccessoryViewerDetailTone: Equatable {
    case sea
    case sun
    case coral
    case palm
    case ink
}

struct PPAccessoryViewerSnapshot {
    let accessory: PetAccessory
    let id: String
    let title: String
    let description: String
    let price: String
    let originalPrice: String
    let category: String
    let subcategory: String
    let accessoryCategory: String
    let type: String
    let condition: String
    let stock: String
    let weight: String
    let location: String
    let createdDate: String
    let expiryDate: String
    let quantity: Int
    let discountPercent: Double?
    let discountAmount: Double?
    let isUsed: Bool
    let isOwnItem: Bool
    let isProviderMarketplace: Bool
    let isUnavailable: Bool
    let showsCart: Bool
    let media: [PPAccessoryViewerMediaItem]

    init(accessory: PetAccessory) {
        self.accessory = accessory
        id = accessory.accessoryID
        title = accessory.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        description = accessory.desc.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        price = PPAccessoryViewerLegacyBridge.formattedPrice(for: accessory)
        originalPrice =
            PPAccessoryViewerLegacyBridge.formattedOriginalPrice(
                for: accessory
            )
        category =
            PPAccessoryViewerLegacyBridge.categoryName(for: accessory)
        subcategory =
            PPAccessoryViewerLegacyBridge.subcategoryName(for: accessory)
        accessoryCategory =
            PPAccessoryViewerLegacyBridge.accessoryCategoryName(
                for: accessory
            )
        type = PPAccessoryViewerLegacyBridge.typeName(for: accessory)
        condition =
            PPAccessoryViewerLegacyBridge.conditionName(for: accessory)
        stock = PPAccessoryViewerLegacyBridge.stockText(for: accessory)
        weight = PPAccessoryViewerLegacyBridge.weightText(for: accessory)
        location =
            PPAccessoryViewerLegacyBridge.locationName(for: accessory)
        createdDate =
            PPAccessoryViewerLegacyBridge.createdDateText(for: accessory)
        expiryDate =
            PPAccessoryViewerLegacyBridge.expiryDateText(for: accessory)
        quantity = max(accessory.quantity, 0)
        discountPercent = accessory.discountPercent?.doubleValue
        discountAmount = accessory.discountAmount?.doubleValue
        isUsed = PPAccessoryViewerLegacyBridge.isUsed(accessory)
        isOwnItem = PPAccessoryViewerLegacyBridge.isOwn(accessory)
        isProviderMarketplace =
            PPAccessoryViewerLegacyBridge.isProviderMarketplace(accessory)
        isUnavailable =
            PPAccessoryViewerLegacyBridge.isUnavailable(accessory)
        showsCart =
            PPAccessoryViewerLegacyBridge.shouldShowCart(for: accessory)
        media = PPAccessoryViewerMediaItem.items(from: accessory)
    }

    var hasDiscount: Bool {
        guard price != originalPrice else { return false }
        return (discountPercent ?? 0) > 0 || (discountAmount ?? 0) > 0
    }

    var details: [PPAccessoryViewerDetailItem] {
        var result = [
            PPAccessoryViewerDetailItem(
                id: "condition",
                title: PPAccessoryViewerL10n.text("Condition"),
                value: condition,
                symbol: "checkmark.seal.fill",
                tone: .palm
            )
        ]

        if !weight.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "weight",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_size_weight"
                    ),
                    value: weight,
                    symbol: "scalemass.fill",
                    tone: .ink
                )
            )
        }
        if !type.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "accessory-kind",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_kind"
                    ),
                    value: type,
                    symbol: "info.circle.fill",
                    tone: .sea
                )
            )
        }
        if quantity > 0 {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "remain-quantity",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_remain_quantity"
                    ),
                    value: "\(quantity)",
                    symbol: "archivebox.fill",
                    tone: .palm
                )
            )
        }
        if !subcategory.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "subcategory",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_subkind"
                    ),
                    value: subcategory,
                    symbol: "square.grid.3x1.below.line.grid.1x2",
                    tone: .sea
                )
            )
        }
        if !accessoryCategory.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "accessory-category",
                    title: PPAccessoryViewerL10n.text(
                        "Accessory Category"
                    ),
                    value: accessoryCategory,
                    symbol: "tag.fill",
                    tone: .sun
                )
            )
        }
        if !location.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "location",
                    title: PPAccessoryViewerL10n.text("Location"),
                    value: location,
                    symbol: "mappin.and.ellipse",
                    tone: .sea
                )
            )
        }
        if !expiryDate.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "expiry",
                    title: PPAccessoryViewerL10n.text("ExpiryDateTitle"),
                    value: expiryDate,
                    symbol: "calendar.badge.clock",
                    tone: .coral
                )
            )
        }
        if !createdDate.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "listed",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_listed_on"
                    ),
                    value: createdDate,
                    symbol: "calendar",
                    tone: .ink
                )
            )
        }
        return result.filter { !$0.value.isEmpty }
    }
}

struct PPAccessoryViewerOwner {
    let user: UserModel
    let name: String
    let avatarURL: String?
    let phoneNumber: String?
    let isVerified: Bool
    let isChatAllowed: Bool

    init(user: UserModel) {
        self.user = user
        name = PPAccessoryViewerLegacyBridge.displayName(for: user)
        avatarURL = PPAccessoryViewerLegacyBridge.avatarURL(for: user)
        phoneNumber = PPAccessoryViewerLegacyBridge.phoneNumber(for: user)
        isVerified = PPAccessoryViewerLegacyBridge.isVerified(user: user)
        isChatAllowed =
            PPAccessoryViewerLegacyBridge.isChatAllowed(for: user)
    }
}

struct PPAccessoryViewerSuggestion: Identifiable {
    let accessory: PetAccessory
    let id: String
    let title: String
    let price: String
    let subtitle: String
    let imageURL: String?
    let blurHash: String?

    init(accessory: PetAccessory) {
        self.accessory = accessory
        id = accessory.accessoryID
        title = accessory.name
        price =
            PPAccessoryViewerLegacyBridge.formattedPrice(for: accessory)
        let type =
            PPAccessoryViewerLegacyBridge.typeName(for: accessory)
        let condition =
            PPAccessoryViewerLegacyBridge.conditionName(for: accessory)
        subtitle = [type, condition]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        let firstMedia =
            PPAccessoryViewerMediaItem.items(from: accessory).first
        imageURL = firstMedia?.imageURL
        blurHash = firstMedia?.blurHash ?? accessory.blurHash
    }
}
