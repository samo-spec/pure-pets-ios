import Foundation

/// Production repository that forwards every data and analytics call to the
/// application's existing Objective-C managers through the legacy bridge.
///
/// The bridge owns Firebase access, formatting, caching, and navigation;
/// this type only adapts callback-based APIs into structured concurrency.
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
        PPPetAdViewerSnapshot(
            ad: ad,
            title: ad.adTitle ?? "",
            category: PPPetAdViewerLegacyBridge.categoryName(for: ad),
            subcategory: PPPetAdViewerLegacyBridge.subcategoryName(for: ad),
            location: PPPetAdViewerLegacyBridge.locationName(for: ad),
            price: PPPetAdViewerLegacyBridge.formattedPrice(for: ad),
            age: PPPetAdViewerLegacyBridge.ageText(for: ad),
            gender: ad.genderText,
            description: ad.adDescription ?? "",
            postedDate: PPPetAdViewerLegacyBridge.formattedDate(for: ad) ?? "",
            media: PPPetAdMediaItem.items(from: ad)
        )
    }

    func loadOwner(ownerID: String) async throws -> PPPetAdOwner? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PPPetAdOwner?, Error>) in
            PPPetAdViewerLegacyBridge.fetchOwner(id: ownerID) { user, error in
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[PPPetAdRelatedItem], Error>) in
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[PPPetAdRelatedItem], Error>) in
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            PPPetAdViewerLegacyBridge.loadFavorite(adID: adID) { isFavorite, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: isFavorite)
                }
            }
        }
    }

    func setFavorite(_ isFavorite: Bool, adID: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PPPetAdViewerLegacyBridge.setFavorite(
                isFavorite,
                adID: adID
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func submitReport(
        for ad: PetAd,
        reason: PPPetAdReportReason
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PPPetAdViewerLegacyBridge.submitReport(
                for: ad,
                reason: reason.rawValue
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
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
