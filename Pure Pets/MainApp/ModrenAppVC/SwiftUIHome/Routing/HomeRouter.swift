import Foundation
import UIKit
import FirebaseAuth
import FirebaseAppCheck
import PureLens

@MainActor
final class HomeRouter: NSObject, PureLensViewControllerDelegate {
    private(set) weak var owner: PPHomeViewController?
    private var inFlightRoutes = Set<String>()
    private var activeLensContext: LensContext?
    private var profilePresentationCoordinator: PetProfilePresentationCoordinator?
    private let lensEndpoint = URL(string: "https://us-central1-pure-pets-49199.cloudfunctions.net/lensResolve")!

    init(owner: PPHomeViewController) {
        self.owner = owner
        super.init()
    }

    var universalCardDelegate: PPUniversalCellDelegate? { owner }
    func bottomContentClearance() -> CGFloat { max(0, owner?.pp_homeBottomContentClearance() ?? 8) }

    func openSearch() { performOnce("search") { [weak self] in self?.owner?.pp_homeOpenSearch() } }
    func openCart() { performOnce("cart") { [weak self] in self?.owner?.pp_homeOpenCart() } }
    func openDetails(for card: HomeCardModel) {
        guard let object = card.viewModel.modelObject else { return }
        performOnce("details:\(card.id)") { [weak self] in self?.owner?.pp_homeOpenObject(object) }
    }
    func openCategory(_ category: HomeCategoryModel) { owner?.pp_homeOpenMainKind(category.raw) }
    func openAllCategories() { owner?.pp_homeOpenDeepLinkTarget(.allCategories, mainKind: nil, source: .homeMainKindsSection) }
    func openPetProfiles() { owner?.pp_homeOpenPetProfiles() }

    func openPureLens(pet: HomePetModel? = nil) {
        guard #available(iOS 16.0, *), let owner else { owner?.pp_homeOpenPetProfiles(); return }
        let preferredID = pet?.id.trimmingCharacters(in: .whitespacesAndNewlines)
        loadPetContext(preferredPetID: preferredID) { [weak self, weak owner] context, error in
            guard let self, let owner else { return }
            guard error == nil, let context else { owner.pp_homeOpenPetProfiles(); return }
            self.activeLensContext = context
            let locale = Language.currentLanguageCode() ?? Locale.current.identifier
            let configuration = PureLensObjCConfiguration(
                endpoint: self.lensEndpoint,
                activePetID: context.activePetID,
                activePetName: context.activePetName,
                petIdentityConfidence: context.petIdentityConfidence ?? 0,
                proactiveHint: nil,
                proactiveHintExpiresAt: nil,
                hapticsEnabled: true,
                remoteProcessingDisclosure: nil,
                hasPriorRemoteProcessingConsent: false,
                localeIdentifier: locale
            )
            let lens = PureLensViewControllerFactory.makeViewController(configuration: configuration, delegate: self)
            lens.modalPresentationStyle = .fullScreen
            owner.present(lens, animated: true)
        }
    }

    func editPet(_ pet: HomePetModel) { owner?.pp_homeOpenPetEditor(pet.raw) }
    func openOrder(_ order: HomeOrderModel) { performOnce("order:\(order.id)") { [weak self] in self?.owner?.pp_homeOpenOrder(order.raw) } }
    func openOrderHistory() { owner?.pp_homeOpenOrderHistory() }
    func openAccessories(mainKind: NSObject?) { owner?.pp_homeOpenDeepLinkTarget(.accessories, mainKind: mainKind, source: .homeAccessoriesSection) }
    func openFood(mainKind: NSObject?) { owner?.pp_homeOpenDeepLinkTarget(.food, mainKind: mainKind, source: .homeAccessoriesSection) }
    func openAdvertisements(mainKind: NSObject?) { owner?.pp_homeOpenDeepLinkTarget(.ads, mainKind: mainKind, source: .homeMainKindsSection) }
    func openNearbyAdvertisements() { owner?.pp_homeOpenDeepLinkTarget(.newByAds, mainKind: nil, source: .homeNearBySection) }
    func openServices(mainKind: NSObject?) { owner?.pp_homeOpenDeepLinkTarget(.services, mainKind: mainKind, source: .homeServicesSection) }
    func openVeterinaryCare(mainKind: NSObject?) { owner?.pp_homeOpenCareSection(1, mainKind: mainKind) }
    func openPharmacy(mainKind: NSObject?) { owner?.pp_homeOpenCareSection(0, mainKind: mainKind) }
    func openAdoption() { owner?.pp_homeOpenAdoption() }
    func openProviderCategory(identifier: String, titleKey: String?, subtitleKey: String?) { owner?.pp_homeOpenProviderCategoryIdentifier(identifier, titleKey: titleKey, subtitleKey: subtitleKey) }

    func openHeroAction(_ action: HomeHeroAction) {
        switch action {
        case .openPetProfiles: openPetProfiles()
        case let .editPet(pet): owner?.pp_homeOpenPetEditor(pet)
        case let .openPromotion(card, interaction): owner?.pp_homeOpenPromoCard(card, interaction: interaction)
        case .openMarketplace: openProviderCategory(identifier: "marketplace", titleKey: "provider_marketplace_title", subtitleKey: "provider_marketplace_subtitle")
        case let .openPharmacy(mainKind): openAccessories(mainKind: mainKind)
        }
    }
    func presentLocationOptions() { performOnce("location-options") { [weak self] in self?.owner?.pp_homePresentLocationOptions() } }
    func openLocationPicker() { performOnce("location-picker") { [weak self] in self?.owner?.pp_homeOpenLocationPicker() } }
    func openLocationSettings() { performOnce("location-settings") { [weak self] in self?.owner?.pp_homeOpenLocationSettings() } }
    func openNova() { performOnce("nova") { [weak self] in self?.owner?.pp_homeOpenNova() } }
    func refreshOwner() { owner?.pp_homeRefresh() }

    // MARK: - Pure Lens bridge

    func pureLensAuthorizationToken(_ completion: @escaping (String?, NSError?) -> Void) {
        guard let user = Auth.auth().currentUser else { completion(nil, lensError("Error")); return }
        user.getIDTokenForcingRefresh(false) { [weak user] token, error in
            if let token, !token.isEmpty, error == nil { completion(token, nil); return }
            guard let user else {
                completion(nil, error.map { $0 as NSError } ?? self.lensError("Error"))
                return
            }
            user.getIDTokenForcingRefresh(true) { refreshed, refreshError in
                completion(
                    (refreshed?.isEmpty == false) ? refreshed : nil,
                    refreshError.map { $0 as NSError }
                        ?? error.map { $0 as NSError }
                        ?? self.lensError("Error")
                )
            }
        }
    }

    func pureLensAdditionalHeaders(_ completion: @escaping (NSDictionary?, NSError?) -> Void) {
        AppCheck.appCheck().limitedUseToken { token, error in
            guard let token = token?.token, !token.isEmpty, error == nil else {
                completion(nil, error.map { $0 as NSError } ?? self.lensError("Error")); return
            }
            completion(["X-Firebase-AppCheck": token] as NSDictionary, nil)
        }
    }

    func pureLensOpenPetProfile(_ completion: @escaping (NSDictionary?, NSError?) -> Void) {
        guard let owner, profilePresentationCoordinator == nil else { completion(nil, lensError("Error")); return }
        let presenter = topViewController(from: owner.presentedViewController ?? owner)
        let profileVC = PPPetProfilesViewController()
        let navigation = UINavigationController(rootViewController: profileVC)
        navigation.modalPresentationStyle = .formSheet
        let coordinator = PetProfilePresentationCoordinator { [weak self] in
            guard let self else { completion(nil, self?.lensError("Error")); return }
            self.profilePresentationCoordinator = nil
            self.loadPetContext(preferredPetID: self.activeLensContext?.activePetID) { context, error in
                guard let context, error == nil else { completion(nil, error ?? self.lensError("Error")); return }
                self.activeLensContext = context
                completion(self.contextDictionary(context), nil)
            }
        }
        profilePresentationCoordinator = coordinator
        presenter.present(navigation, animated: true) { navigation.presentationController?.delegate = coordinator }
    }

    func pureLensPerformAction(_ kind: String, actionID: String, payload: NSDictionary, completion: @escaping (NSDictionary?, NSError?) -> Void) {
        guard let owner else { completion(nil, lensError("Error")); return }
        let value = { (key: String) -> String in (payload[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        switch kind {
        case "prepareCart":
            fetchAccessory(id: value("productID")) { product, error in
                guard let product, error == nil, self.available(product, requireStock: true) else { completion(nil, error ?? self.lensError("Error")); return }
                let quantity = max(1, Int(value("quantity")) ?? 1)
                PPAccessoryViewerLegacyBridge.addToCart(product, quantity: quantity, from: owner) { result, _, _, _ in
                    completion(result.rawValue == 0 ? nil : nil, result.rawValue == 0 ? nil : self.lensError("Error"))
                }
            }
        case "openProduct":
            fetchAccessory(id: value("productID")) { product, error in
                guard let product, error == nil, self.available(product, requireStock: false) else { completion(nil, error ?? self.lensError("Error")); return }
                PPAccessoryViewerLegacyBridge.openAccessory(product, from: owner); completion(nil, nil)
            }
        case "openVerifiedMedicine":
            fetchAccessory(id: value("medicineID")) { product, error in
                guard let product, error == nil, product.isPetMedicine, self.available(product, requireStock: false) else { completion(nil, error ?? self.lensError("Error")); return }
                PPAccessoryViewerLegacyBridge.openAccessory(product, from: owner); completion(nil, nil)
            }
        case "bookVet": owner.pp_homeOpenCareSection(1, mainKind: nil); completion(nil, nil)
        case "openAdoption": owner.pp_homeOpenAdoption(); completion(nil, nil)
        case "contactSupport": PPAccessoryViewerLegacyBridge.openSupport(from: owner); completion(nil, nil)
        default: completion(nil, lensError("Error"))
        }
    }

    // MARK: - Pet and catalog helpers

    private func loadPetContext(preferredPetID: String?, completion: @escaping (LensContext?, NSError?) -> Void) {
        let manager = PPPetProfileManager.shared()
        manager.currentUserUID = Auth.auth().currentUser?.uid
        manager.fetchPetProfilesForCurrentUser { pets, error in
            DispatchQueue.main.async {
                guard error == nil else { completion(nil, error as NSError?); return }
                let all = pets ?? []
                let selected = preferredPetID.flatMap { wanted in all.first { $0.petID == wanted } }
                    ?? all.first(where: { $0.isDefaultPet }) ?? all.first
                guard let pet = selected, !pet.petID.isEmpty else { completion(nil, nil); return }
                completion(LensContext(activePetID: pet.petID, activePetName: pet.name.isEmpty ? nil : pet.name, petIdentityConfidence: nil, proactiveHint: nil, proactiveHintExpiresAt: nil, localeIdentifier: Language.currentLanguageCode() ?? Locale.current.identifier, timeZoneIdentifier: TimeZone.current.identifier), nil)
            }
        }
    }

    private func fetchAccessory(id: String, completion: @escaping (PetAccessory?, NSError?) -> Void) {
        guard !id.isEmpty else { completion(nil, lensError("Error")); return }
        PetAccessoryManager.fetchAccessories(withIDs: [id]) { accessories in
            DispatchQueue.main.async { completion(accessories.first, accessories.first == nil ? self.lensError("Error") : nil) }
        }
    }
    private func available(_ product: PetAccessory, requireStock: Bool) -> Bool {
        product.showInAppMarket && !product.isLivePet && !PPAccessoryViewerLegacyBridge.isUnavailable(product) && (!requireStock || product.quantity > 0)
    }
    private func contextDictionary(_ context: LensContext) -> NSDictionary {
        ["activePetID": context.activePetID ?? "", "activePetName": context.activePetName ?? "", "localeIdentifier": context.localeIdentifier, "timeZoneIdentifier": context.timeZoneIdentifier] as NSDictionary
    }
    private func topViewController(from root: UIViewController) -> UIViewController {
        var current = root
        while let presented = current.presentedViewController { current = presented }
        return current
    }
    private func lensError(_ key: String) -> NSError { NSError(domain: "PurePets.PureLens", code: 1, userInfo: [NSLocalizedDescriptionKey: PPAccessoryViewerLegacyBridge.localizedText(key: key, fallback: key)]) }

    private func performOnce(_ key: String, action: () -> Void) {
        guard inFlightRoutes.insert(key).inserted else { return }
        action()
        Task { [weak self] in try? await Task.sleep(nanoseconds: 700_000_000); self?.inFlightRoutes.remove(key) }
    }
}

private final class PetProfilePresentationCoordinator: NSObject, UIAdaptivePresentationControllerDelegate {
    private var completed = false
    private let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss; super.init() }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard !completed else { return }; completed = true; onDismiss()
    }
}
