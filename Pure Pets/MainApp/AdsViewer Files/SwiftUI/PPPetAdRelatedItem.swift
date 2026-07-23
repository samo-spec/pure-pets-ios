import Foundation

struct PPPetAdRelatedItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let price: String
    let imageURL: String?
    let blurHash: String?
    let kind: PPPetAdRelatedItemKind

    init(ad: PetAd) {
        let fallbackID = String(ObjectIdentifier(ad).hashValue)
        id = ad.adID.isEmpty ? fallbackID : ad.adID
        let resolvedTitle =
            ad.adTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let resolvedTitle, !resolvedTitle.isEmpty {
            title = resolvedTitle
        } else {
            title = PPPetAdLocalization.text(
                "pet_ad_viewer_pet_fallback",
                fallback: "Pet listing"
            )
        }

        let subcategory =
            PPPetAdViewerLegacyBridge.subcategoryName(for: ad)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        let location =
            PPPetAdViewerLegacyBridge.locationName(for: ad)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        subtitle = [subcategory, location]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        price = PPPetAdViewerLegacyBridge.formattedPrice(for: ad)
        imageURL =
            ad.imageItems.first?.url ??
            ad.imageURLs?.first
        blurHash = ad.imageItems.first?.blurHash ?? ad.blurHash
        kind = .petAd(ad)
    }

    init(accessory: PetAccessory) {
        let fallbackID = String(ObjectIdentifier(accessory).hashValue)
        id = accessory.accessoryID.isEmpty
            ? fallbackID
            : accessory.accessoryID
        let resolvedTitle =
            accessory.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
        title = resolvedTitle.isEmpty
            ? PPPetAdLocalization.text(
                "pet_ad_viewer_accessory_badge",
                fallback: "Accessory"
            )
            : resolvedTitle

        let type =
            PPPetAdViewerLegacyBridge.subtitle(forAccessory: accessory)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        let location =
            PPPetAdViewerLegacyBridge.locationName(forAccessory: accessory)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        subtitle = [type, location]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        price =
            PPPetAdViewerLegacyBridge.formattedPrice(forAccessory: accessory)
        imageURL =
            accessory.imageItems.first?.url ??
            accessory.imageURLsArray.first
        blurHash = accessory.imageItems.first?.blurHash ?? accessory.blurHash
        kind = .accessory(accessory)
    }
}
