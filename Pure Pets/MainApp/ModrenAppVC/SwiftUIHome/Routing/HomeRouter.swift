import Foundation
import UIKit
import PureLens


@MainActor
final class HomeRouter {
    private(set) weak var owner: PPHomeViewController?
    private var inFlightRoutes = Set<String>()

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
        performOnce("search") { [weak self] in
            self?.owner?.pp_homeOpenSearch()
        }
    }

    func openCart() {
        performOnce("cart") { [weak self] in
            self?.owner?.pp_homeOpenCart()
        }
    }

    func openDetails(for card: HomeCardModel) {
        guard let object = card.viewModel.modelObject else { return }
        performOnce("details:\(card.id)") { [weak self] in
            self?.owner?.pp_homeOpenObject(object)
        }
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

    func openPureLens(pet: HomePetModel? = nil) {
        if #available(iOS 16.0, *) {
            guard let owner = owner else { return }
            let petName = pet?.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let petID = pet?.id.trimmingCharacters(in: .whitespacesAndNewlines),
                  !petID.isEmpty
            else {
                owner.pp_homeOpenPetProfiles()
                return
            }
            let localeIdentifier = Language.currentLanguageCode() ?? Locale.current.identifier

            let module: PurePetsEyesModule = .purePetsCameraPreview(
                localeIdentifier: localeIdentifier,
                contextProvider: {
                    LensContext(
                        activePetID: petID,
                        activePetName: (petName?.isEmpty == false) ? petName : nil,
                        petIdentityConfidence: nil,
                        proactiveHint: nil,
                        proactiveHintExpiresAt: nil,
                        localeIdentifier: localeIdentifier
                    )
                }
            )

            let eyesVC = PurePetsEyesUIKit.makeViewController(module: module)
            eyesVC.modalPresentationStyle = .fullScreen
            owner.present(eyesVC, animated: true, completion: nil)
        } else {
            owner?.pp_homeOpenPetProfiles()
        }
    }

    func editPet(_ pet: HomePetModel) {
        owner?.pp_homeOpenPetEditor(pet.raw)
    }

    func openOrder(_ order: HomeOrderModel) {
        performOnce("order:\(order.id)") { [weak self] in
            self?.owner?.pp_homeOpenOrder(order.raw)
        }
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
        case .openMarketplace:
            openProviderCategory(
                identifier: "marketplace",
                titleKey: "provider_marketplace_title",
                subtitleKey: "provider_marketplace_subtitle"
            )
        case let .openPharmacy(mainKind):
            openAccessories(mainKind: mainKind)
        }
    }

    func presentLocationOptions() {
        performOnce("location-options") { [weak self] in
            self?.owner?.pp_homePresentLocationOptions()
        }
    }

    func openLocationPicker() {
        performOnce("location-picker") { [weak self] in
            self?.owner?.pp_homeOpenLocationPicker()
        }
    }

    func openLocationSettings() {
        performOnce("location-settings") { [weak self] in
            self?.owner?.pp_homeOpenLocationSettings()
        }
    }

    func openNova() {
        performOnce("nova") { [weak self] in
            self?.owner?.pp_homeOpenNova()
        }
    }

    func refreshOwner() {
        owner?.pp_homeRefresh()
    }

    private func performOnce(
        _ key: String,
        action: () -> Void
    ) {
        guard inFlightRoutes.insert(key).inserted else { return }
        action()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self?.inFlightRoutes.remove(key)
        }
    }
}
