import Foundation

@MainActor
protocol PPPetAdViewerRepository: AnyObject {
    var isSignedIn: Bool { get }
    var isNetworkAvailable: Bool { get }
    var currentUserID: String? { get }

    func makeSnapshot(for ad: PetAd) -> PPPetAdViewerSnapshot
    func loadOwner(ownerID: String) async throws -> PPPetAdOwner?
    func loadRelatedAds(for ad: PetAd, limit: Int) async throws
        -> [PPPetAdRelatedItem]
    func loadRelatedAccessories(for ad: PetAd, limit: Int) async throws
        -> [PPPetAdRelatedItem]
    func loadFavorite(adID: String) async throws -> Bool
    func setFavorite(_ isFavorite: Bool, adID: String) async throws
    func submitReport(for ad: PetAd, reason: PPPetAdReportReason) async throws
    func track(_ interaction: PPPetAdViewerInteraction, ad: PetAd)
    func logView(ad: PetAd)
    func logContact(ad: PetAd, channelCode: Int)
}
