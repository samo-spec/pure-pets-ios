import Foundation
import UIKit

@MainActor
final class HomeRouter {
    private(set) weak var owner: PPHomeViewController?

    init(owner: PPHomeViewController) {
        self.owner = owner
    }

    var universalCardDelegate: PPUniversalCellDelegate? {
        owner
    }

    func bottomContentClearance() -> CGFloat {
        max(0, owner?.pp_homeBottomContentClearance() ?? 8)
    }

    func openSearch() {
        owner?.pp_homeOpenSearch()
    }

    func openCart() {
        owner?.pp_homeOpenCart()
    }

    func openDetails(for card: HomeCardModel) {
        guard let object = card.viewModel.modelObject else { return }
        owner?.pp_homeOpenObject(object)
    }

    func openCategory(_ category: HomeCategoryModel) {
        owner?.pp_homeOpenMainKind(category.raw)
    }

    func openAllCategories() {
        owner?.pp_homeOpenDeepLinkTarget(
            .allCategories,
            mainKind: nil,
            source: .homeMainKindsSection
        )
    }

    func openPetProfiles() {
        owner?.pp_homeOpenPetProfiles()
    }

    func editPet(_ pet: HomePetModel) {
        owner?.pp_homeOpenPetEditor(pet.raw)
    }

    func openOrder(_ order: HomeOrderModel) {
        owner?.pp_homeOpenOrder(order.raw)
    }

    func openOrderHistory() {
        owner?.pp_homeOpenOrderHistory()
    }

    func openAccessories(mainKind: NSObject?) {
        owner?.pp_homeOpenDeepLinkTarget(
            .accessories,
            mainKind: mainKind,
            source: .homeAccessoriesSection
        )
    }

    func openFood(mainKind: NSObject?) {
        owner?.pp_homeOpenDeepLinkTarget(
            .food,
            mainKind: mainKind,
            source: .homeAccessoriesSection
        )
    }

    func openAdvertisements(mainKind: NSObject?) {
        owner?.pp_homeOpenDeepLinkTarget(
            .ads,
            mainKind: mainKind,
            source: .homeMainKindsSection
        )
    }

    func openNearbyAdvertisements() {
        owner?.pp_homeOpenDeepLinkTarget(
            .newByAds,
            mainKind: nil,
            source: .homeNearBySection
        )
    }

    func openServices(mainKind: NSObject?) {
        owner?.pp_homeOpenDeepLinkTarget(
            .services,
            mainKind: mainKind,
            source: .homeServicesSection
        )
    }

    func openVeterinaryCare(mainKind: NSObject?) {
        owner?.pp_homeOpenCareSection(1, mainKind: mainKind)
    }

    func openPharmacy(mainKind: NSObject?) {
        owner?.pp_homeOpenCareSection(0, mainKind: mainKind)
    }

    func openAdoption() {
        owner?.pp_homeOpenAdoption()
    }

    func openProviderCategory(
        identifier: String,
        titleKey: String?,
        subtitleKey: String?
    ) {
        owner?.pp_homeOpenProviderCategoryIdentifier(
            identifier,
            titleKey: titleKey,
            subtitleKey: subtitleKey
        )
    }

    func openHeroAction(_ action: HomeHeroAction) {
        switch action {
        case .openPetProfiles:
            openPetProfiles()
        case let .editPet(pet):
            owner?.pp_homeOpenPetEditor(pet)
        case let .openPromotion(card, interaction):
            owner?.pp_homeOpenPromoCard(card, interaction: interaction)
        case let .openMarketplace(mainKind):
            openAdvertisements(mainKind: mainKind)
        }
    }

    func presentLocationOptions() {
        owner?.pp_homePresentLocationOptions()
    }

    func openLocationPicker() {
        owner?.pp_homeOpenLocationPicker()
    }

    func openLocationSettings() {
        owner?.pp_homeOpenLocationSettings()
    }

    func openNova() {
        owner?.pp_homeOpenNova()
    }

    func refreshOwner() {
        owner?.pp_homeRefresh()
    }
}
