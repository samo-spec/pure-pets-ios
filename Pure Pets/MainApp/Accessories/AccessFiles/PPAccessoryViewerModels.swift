import Foundation
import UIKit

enum PPAccessoryViewerL10n {
    private static let arabicIntegerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar_QA")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let englishIntegerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_QA")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let arabicDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar_QA")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let englishDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_QA")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static var locale: Locale {
        Locale(
            identifier: PPAccessoryViewerLegacyBridge.isRTL()
                ? "ar_QA"
                : "en_QA"
        )
    }

    @inline(__always)
    static func text(_ key: String) -> String {
        let localized = PPAccessoryViewerLegacyBridge.localizedText(
            key: key,
            fallback: key
        )
        return localized.isEmpty ? key : localized
    }

    static func formatted(
        _ key: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key),
            locale: locale,
            arguments: arguments
        )
    }

    static func integer(_ value: Int) -> String {
        let formatter = PPAccessoryViewerLegacyBridge.isRTL()
            ? arabicIntegerFormatter
            : englishIntegerFormatter
        return formatter.string(from: NSNumber(value: value))
            ?? String(value)
    }

    static func decimal(_ value: Double) -> String {
        let formatter = PPAccessoryViewerLegacyBridge.isRTL()
            ? arabicDecimalFormatter
            : englishDecimalFormatter
        return formatter.string(from: NSNumber(value: value))
            ?? String(value)
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

enum PPAccessoryViewerCheckoutPhase: Equatable {
    case ready
    case preparingCart
    case openingPayment
    case routeFailed
}

enum PPAccessoryViewerLivePhase: Equatable {
    case current
    case refreshing
    case stale
    case deleted
}

enum PPAccessoryViewerStockNotificationPhase: Equatable {
    case idle
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
        var seenIDs = Set<String>()
        let mapped = accessory.imageItems.compactMap { item -> Self? in
            guard let media = makeItem(from: item),
                  seenIDs.insert(media.id).inserted else {
                return nil
            }
            return media
        }
        if !mapped.isEmpty {
            return mapped
        }

        return accessory.imageURLsArray.compactMap { value -> Self? in
            let url = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let stableID = "image:\(url)"
            guard !url.isEmpty, seenIDs.insert(stableID).inserted else {
                return nil
            }
            return Self(
                id: stableID,
                imageURL: url,
                videoURL: nil,
                blurHash: accessory.blurHash,
                isVideo: false
            )
        }
    }

    private static func makeItem(
        from item: PetImageItem
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
        let stableResource = resolvedVideoURL ?? resolvedImageURL ?? rawURL
        return Self(
            id: "\(isVideo ? "video" : "image"):\(stableResource)",
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
    let size: String
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
    let isBlocked: Bool
    let isDeleted: Bool
    let isDisabled: Bool
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
        size = PPAccessoryViewerLegacyBridge.sizeText(for: accessory)
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
        isBlocked = accessory.isBlocked
        isDeleted = accessory.isDeleted
        isDisabled = accessory.isDisabled
        showsCart =
            PPAccessoryViewerLegacyBridge.shouldShowCart(for: accessory)
        media = PPAccessoryViewerMediaItem.items(from: accessory)
    }

    var hasDiscount: Bool {
        guard price != originalPrice else { return false }
        return (discountPercent ?? 0) > 0 || (discountAmount ?? 0) > 0
    }

    var hasReadinessFacts: Bool {
        !stock.isEmpty ||
            !condition.isEmpty ||
            !createdDate.isEmpty
    }

    var isFood: Bool {
        accessory.isFood
    }

    var isMedicine: Bool {
        accessory.isPetMedicine
    }

    var isAvailableForPurchase: Bool {
        !isUnavailable && quantity > 0
    }

    var canRequestStockNotification: Bool {
        !id.isEmpty &&
            quantity <= 0 &&
            !isBlocked &&
            !isDeleted &&
            !isDisabled &&
            accessory.showInAppMarket
    }

    var petFitDataGapText: String {
        if isFood {
            return PPAccessoryViewerL10n.text(
                "accessory_view_food_fit_gap"
            )
        }
        if isMedicine {
            return PPAccessoryViewerL10n.text(
                "accessory_view_medicine_fit_gap"
            )
        }
        return PPAccessoryViewerL10n.text(
            "accessory_view_accessory_fit_gap"
        )
    }

    var petFitDetails: [PPAccessoryViewerDetailItem] {
        var result: [PPAccessoryViewerDetailItem] = []

        if !category.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "fit-category",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_pet_category"
                    ),
                    value: category,
                    symbol: "pawprint.fill",
                    tone: .coral
                )
            )
        }
        if !subcategory.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "fit-subcategory",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_product_category"
                    ),
                    value: subcategory,
                    symbol: "square.grid.2x2.fill",
                    tone: .sea
                )
            )
        }
        if !accessoryCategory.isEmpty &&
            accessoryCategory != subcategory {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "fit-product-group",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_product_group"
                    ),
                    value: accessoryCategory,
                    symbol: "tag.fill",
                    tone: .sun
                )
            )
        }
        if !weight.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "fit-weight",
                    title: PPAccessoryViewerL10n.text(
                        isFood || isMedicine
                            ? "accessory_view_pack_weight"
                            : "accessory_view_size_weight"
                    ),
                    value: weight,
                    symbol: "scalemass.fill",
                    tone: .ink
                )
            )
        }
        if !size.isEmpty {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "fit-size",
                    title: PPAccessoryViewerL10n.text("accessory_view_size"),
                    value: size,
                    symbol: "ruler.fill",
                    tone: .palm
                )
            )
        }
        if !condition.isEmpty && !isFood && !isMedicine {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "fit-condition",
                    title: PPAccessoryViewerL10n.text("Condition"),
                    value: condition,
                    symbol: "checkmark.seal.fill",
                    tone: .palm
                )
            )
        }
        if !expiryDate.isEmpty && (isFood || isMedicine) {
            result.append(
                PPAccessoryViewerDetailItem(
                    id: "fit-expiry",
                    title: PPAccessoryViewerL10n.text("ExpiryDateTitle"),
                    value: expiryDate,
                    symbol: "calendar.badge.clock",
                    tone: .coral
                )
            )
        }

        return result
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
                    value: PPAccessoryViewerL10n.integer(quantity),
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
    let companyProfileImageURL: String?
    let phoneNumber: String?
    let isVerified: Bool
    let isChatAllowed: Bool
    let ratingValue: Double
    let reviewCount: Int

    init(user: UserModel, companyProfileImageURL: String? = nil) {
        self.user = user
        name = PPAccessoryViewerLegacyBridge.displayName(for: user)
        avatarURL = PPAccessoryViewerLegacyBridge.avatarURL(for: user)
        let cleanCompanyImageURL =
            companyProfileImageURL?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        self.companyProfileImageURL =
            cleanCompanyImageURL?.isEmpty == false ? cleanCompanyImageURL : nil
        phoneNumber = PPAccessoryViewerLegacyBridge.phoneNumber(for: user)
        isVerified = PPAccessoryViewerLegacyBridge.isVerified(user: user)
        isChatAllowed =
            PPAccessoryViewerLegacyBridge.isChatAllowed(for: user)
        ratingValue = min(max(user.providerRatingValue, 0), 5)
        reviewCount = max(user.providerReviewCount, 0)
    }

    var preferredAvatarURL: String? {
        companyProfileImageURL ?? avatarURL
    }

    var hasRating: Bool {
        ratingValue > 0 && reviewCount > 0
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
    let isAvailable: Bool

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
        isAvailable =
            !PPAccessoryViewerLegacyBridge.isUnavailable(accessory) &&
            accessory.quantity > 0
    }
}


/// One sellable colour of a product family.
///
/// Every field mirrors the server's `ProductFamilies.variants[]` projection, which is
/// merchandising identity only. It is deliberately **not** a price or stock authority:
/// tapping a swatch resolves the colour's own `petAccessories` document, and that
/// document is what the screen then renders and sells.
///
/// `id` is the colour identifier, never the localized name and never the hex. A colour
/// can be renamed or repainted without changing identity, and two colours may
/// legitimately share a hex (two different fabrics of the same navy).
struct PPAccessoryViewerVariant: Identifiable, Equatable {
    let id: String
    let productId: String
    let name: String
    let hex: String
    let sortOrder: Int
    let isDefault: Bool
    let isArchived: Bool
    let sku: String
    let primaryImageURL: String?

    /// Parses one server projection entry, returning `nil` when it cannot be rendered
    /// as a selectable colour.
    ///
    /// Fails closed on a missing `productId` or colour `id`: a swatch that cannot be
    /// resolved to a document would be a dead tap, which is worse than being absent.
    /// A missing hex is tolerated — the rail falls back to a neutral chip and the name
    /// still identifies the colour, because the name is the accessible label anyway.
    init?(projection: [String: Any]) {
        guard let rawProductId = projection["productId"] as? String,
              case let productId = rawProductId.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ),
              !productId.isEmpty else { return nil }

        let color = projection["color"] as? [String: Any] ?? [:]
        guard let rawColorId = color["id"] as? String,
              case let colorId = rawColorId.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ),
              !colorId.isEmpty else { return nil }

        self.id = colorId
        self.productId = productId

        // Arabic is the product's primary language, English the secondary. Pick by the
        // active language and fall back to the other rather than to the raw id, so a
        // half-translated colour still reads as a colour.
        let nameAr = (color["nameAr"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        let nameEn = (color["nameEn"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        let preferred = PPAccessoryViewerLegacyBridge.isRTL() ? nameAr : nameEn
        let fallback = PPAccessoryViewerLegacyBridge.isRTL() ? nameEn : nameAr
        name = !preferred.isEmpty ? preferred : fallback

        hex = (color["hex"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).uppercased() ?? ""

        if let order = projection["sortOrder"] as? Int {
            sortOrder = order
        } else if let order = projection["sortOrder"] as? NSNumber {
            sortOrder = order.intValue
        } else {
            sortOrder = 0
        }

        isDefault = (projection["isDefault"] as? Bool) ?? false
        isArchived = (projection["isArchived"] as? Bool) ?? false
        sku = (projection["sku"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""

        let image = (projection["primaryImageURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        primaryImageURL = image.isEmpty ? nil : image
    }

    /// The swatch's red/green/blue components in 0...1, or `nil` when the server sent
    /// no usable hex.
    ///
    /// Returns components rather than a `Color` so this models file stays free of
    /// SwiftUI: the view layer decides how to paint a colour, the model only carries
    /// what the server said. A malformed hex yields `nil` so the rail can fall back to
    /// a neutral chip instead of painting an arbitrary wrong colour.
    var swatchComponents: (red: Double, green: Double, blue: Double)? {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        return (
            red: Double((value & 0xFF0000) >> 16) / 255.0,
            green: Double((value & 0x00FF00) >> 8) / 255.0,
            blue: Double(value & 0x0000FF) / 255.0
        )
    }
}
