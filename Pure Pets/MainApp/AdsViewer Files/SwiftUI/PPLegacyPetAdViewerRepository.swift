import Foundation

@MainActor
final class PPLegacyPetAdViewerRepository: PPPetAdViewerRepository {
    var isSignedIn: Bool {
        PPPetAdViewerLegacyBridge.isSignedIn()
    }

    var isNetworkAvailable: Bool {
        PPPetAdViewerLegacyBridge.isNetworkAvailable()
    }

    var currentUserID: String? {
        PPPetAdViewerLegacyBridge.currentUserID()
    }

    func makeSnapshot(for ad: PetAd) -> PPPetAdViewerSnapshot {
        let title =
            ad.adTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        return PPPetAdViewerSnapshot(
            ad: ad,
            title: title,
            category: PPPetAdViewerLegacyBridge.categoryName(for: ad),
            subcategory:
                PPPetAdViewerLegacyBridge.subcategoryName(for: ad),
            location: PPPetAdViewerLegacyBridge.locationName(for: ad),
            price: PPPetAdViewerLegacyBridge.formattedPrice(for: ad),
            age: PPPetAdViewerLegacyBridge.ageText(for: ad),
            gender:
                ad.genderText.trimmingCharacters(in: .whitespacesAndNewlines),
            description:
                ad.adDescription?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "",
            media: PPPetAdMediaItem.items(from: ad)
        )
    }

    func loadOwner(ownerID: String) async throws -> PPPetAdOwner? {
        try await withCheckedThrowingContinuation { continuation in
            PPPetAdViewerLegacyBridge.fetchOwner(id: ownerID) {
                user,
                error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(
                        returning: user.map(PPPetAdOwner.init(user:))
                    )
                }
            }
        }
    }

    func loadRelatedAds(
        for ad: PetAd,
        limit: Int
    ) async throws -> [PPPetAdRelatedItem] {
        try await withCheckedThrowingContinuation { continuation in
            PPPetAdViewerLegacyBridge.fetchSimilarAds(
                for: ad,
                limit: limit
            ) { ads, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var seen = Set<String>()
                let items = ads
                    .filter { $0.adID != ad.adID }
                    .map(PPPetAdRelatedItem.init(ad:))
                    .filter { seen.insert($0.id).inserted }
                continuation.resume(returning: items)
            }
        }
    }

    func loadRelatedAccessories(
        for ad: PetAd,
        limit: Int
    ) async throws -> [PPPetAdRelatedItem] {
        try await withCheckedThrowingContinuation { continuation in
            PPPetAdViewerLegacyBridge.fetchAccessories(
                for: ad,
                limit: limit
            ) { accessories, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var seen = Set<String>()
                let items = accessories
                    .map(PPPetAdRelatedItem.init(accessory:))
                    .filter { seen.insert($0.id).inserted }
                continuation.resume(returning: items)
            }
        }
    }

    func loadFavorite(adID: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            PPPetAdViewerLegacyBridge.loadFavorite(adID: adID) {
                isFavorite,
                error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: isFavorite)
                }
            }
        }
    }

    func setFavorite(_ isFavorite: Bool, adID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PPPetAdViewerLegacyBridge.setFavorite(
                isFavorite,
                adID: adID
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: Void())
                }
            }
        }
    }

    func submitReport(
        for ad: PetAd,
        reason: PPPetAdReportReason
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PPPetAdViewerLegacyBridge.submitReport(
                for: ad,
                reason: reason.rawValue
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: Void())
                }
            }
        }
    }

    func track(_ interaction: PPPetAdViewerInteraction, ad: PetAd) {
        PPPetAdViewerLegacyBridge.track(
            interactionCode: interaction.rawValue,
            ad: ad
        )
    }

    func logView(ad: PetAd) {
        PPPetAdViewerLegacyBridge.logView(for: ad)
    }

    func logContact(ad: PetAd, channelCode: Int) {
        PPPetAdViewerLegacyBridge.logContact(
            for: ad,
            channelCode: channelCode
        )
    }
}
