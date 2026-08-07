import Foundation
import UIKit
import FirebaseAuth
import FirebaseAnalytics
import FirebaseAppCheck
import PureLens

@MainActor
final class HomeRouter: NSObject, PureLensViewControllerDelegate {
    private(set) weak var owner: PPHomeViewController?
    private var inFlightRoutes = Set<String>()
    private var inFlightLensActions = Set<String>()
    private var completedLensActions: [String: NSDictionary] = [:]
    private var activeLensContext: LensContext?
    private var profilePresentationCoordinator: PetProfilePresentationCoordinator?
    private let lensEndpoint = URL(string: "https://us-central1-pure-pets-49199.cloudfunctions.net/lensResolve")!

    // Consent is scoped to the authenticated user and the exact processor,
    // purpose, and retention terms disclosed by the current backend contract.
    // Bump this value whenever those terms change.
    private static let lensConsentVersion = "purelens-3.0-google-gemini-no-retention-v1"
    private static let lensConsentEvent = "pure_lens_remote_processing_consent_granted"

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
            let locale = context.localeIdentifier
            let configuration = PureLensObjCConfiguration(
                endpoint: self.lensEndpoint,
                activePetID: context.activePetID,
                activePetName: context.activePetName,
                petIdentityConfidence: context.petIdentityConfidence ?? 0,
                proactiveHint: context.proactiveHint,
                proactiveHintExpiresAt: context.proactiveHintExpiresAt,
                hapticsEnabled: true,
                remoteProcessingDisclosure: self.localizedLens(
                    "purelens_remote_processing_disclosure"
                ),
                hasPriorRemoteProcessingConsent: self.hasCurrentLensConsent,
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
        guard let user = Auth.auth().currentUser else { completion(nil, lensError("purelens_error_auth")); return }
        user.getIDTokenForcingRefresh(false) { [weak user] token, error in
            if let token, !token.isEmpty, error == nil { completion(token, nil); return }
            guard let user else {
                completion(nil, error.map { $0 as NSError } ?? self.lensError("purelens_error_auth"))
                return
            }
            user.getIDTokenForcingRefresh(true) { refreshed, refreshError in
                completion(
                    (refreshed?.isEmpty == false) ? refreshed : nil,
                    refreshError.map { $0 as NSError }
                        ?? error.map { $0 as NSError }
                        ?? self.lensError("purelens_error_auth")
                )
            }
        }
    }

    func pureLensAdditionalHeaders(_ completion: @escaping (NSDictionary?, NSError?) -> Void) {
        AppCheck.appCheck().limitedUseToken { token, error in
            guard let token = token?.token, !token.isEmpty, error == nil else {
                completion(nil, error.map { $0 as NSError } ?? self.lensError("purelens_error_app_check"))
                return
            }
            completion(["X-Firebase-AppCheck": token] as NSDictionary, nil)
        }
    }

    func pureLensOpenPetProfile(_ completion: @escaping (NSDictionary?, NSError?) -> Void) {
        guard let owner, profilePresentationCoordinator == nil else { completion(nil, lensError("purelens_error_profile")); return }
        let presenter = topViewController(from: owner.presentedViewController ?? owner)
        let profileVC = PPPetProfilesViewController()
        let navigation = UINavigationController(rootViewController: profileVC)
        navigation.modalPresentationStyle = .formSheet
        let coordinator = PetProfilePresentationCoordinator { [weak self] in
            guard let self else {
                completion(nil, NSError(domain: "PurePets.PureLens", code: 1))
                return
            }
            self.profilePresentationCoordinator = nil
            self.loadPetContext(preferredPetID: self.activeLensContext?.activePetID) { context, error in
                guard let context, error == nil else {
                    completion(nil, error ?? self.lensError("purelens_error_profile"))
                    return
                }
                self.activeLensContext = context
                completion(self.contextDictionary(context), nil)
            }
        }
        profilePresentationCoordinator = coordinator
        presenter.present(navigation, animated: true) { navigation.presentationController?.delegate = coordinator }
    }

    func pureLensPerformAction(_ kind: String, actionID: String, payload: NSDictionary, completion: @escaping (NSDictionary?, NSError?) -> Void) {
        guard let owner else { completion(nil, lensError("purelens_error_generic")); return }
        guard !actionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(nil, lensError("purelens_error_invalid_payload"))
            return
        }
        if let cached = completedLensActions[actionID] {
            completion(cached, nil)
            return
        }
        guard inFlightLensActions.insert(actionID).inserted else {
            completion(nil, lensError("purelens_error_action_in_progress"))
            return
        }
        let finish: (NSDictionary?, NSError?) -> Void = { [weak self] response, error in
            guard let self else { completion(response, error); return }
            self.inFlightLensActions.remove(actionID)
            if let response, error == nil {
                self.completedLensActions[actionID] = response
            }
            completion(response, error)
        }
        let value = { (key: String) -> String in (payload[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }

        switch kind {
        case "prepareCart":
            let productID = value("productID")
            guard !productID.isEmpty else { finish(nil, lensError("purelens_error_invalid_payload")); return }
            fetchAccessory(id: productID) { product, error in
                guard let product, error == nil, self.available(product, requireStock: true) else {
                    finish(nil, error ?? self.lensError("purelens_error_cart_unavailable"))
                    return
                }
                let quantity = max(1, Int(value("quantity")) ?? 1)
                PPAccessoryViewerLegacyBridge.addToCart(product, quantity: quantity, from: owner) { result, addedQuantity, cartQuantity, remainingStock in
                    DispatchQueue.main.async {
                        guard result.rawValue == 0 else {
                            finish(nil, self.lensError(self.cartErrorKey(result.rawValue)))
                            return
                        }
                        finish(
                            self.actionReceipt(
                                titleKey: "purelens_action_order_ready",
                                detailKey: "purelens_action_order_ready_detail",
                                metadata: [
                                    "actionID": actionID,
                                    "addedQuantity": String(addedQuantity),
                                    "cartQuantity": String(cartQuantity),
                                    "remainingStock": String(remainingStock)
                                ]
                            ),
                            nil
                        )
                    }
                }
            }
        case "openProduct":
            let productID = value("productID")
            guard !productID.isEmpty else { finish(nil, lensError("purelens_error_invalid_payload")); return }
            fetchAccessory(id: productID) { product, error in
                guard let product, error == nil, self.available(product, requireStock: false) else {
                    finish(nil, error ?? self.lensError("purelens_error_product_unavailable"))
                    return
                }
                self.dismissLensThen {
                    PPAccessoryViewerLegacyBridge.openAccessory(product, from: owner)
                    finish(self.actionReceipt(titleKey: "purelens_action_product_opened", detailKey: "purelens_action_product_opened_detail"), nil)
                }
            }
        case "openVerifiedMedicine":
            let medicineID = value("medicineID")
            guard !medicineID.isEmpty else { finish(nil, lensError("purelens_error_invalid_payload")); return }
            fetchAccessory(id: medicineID) { product, error in
                guard let product, error == nil, product.isPetMedicine, self.available(product, requireStock: false) else {
                    finish(nil, error ?? self.lensError("purelens_error_medicine_unavailable"))
                    return
                }
                self.dismissLensThen {
                    PPAccessoryViewerLegacyBridge.openAccessory(product, from: owner)
                    finish(self.actionReceipt(titleKey: "purelens_action_medicine_opened", detailKey: "purelens_action_medicine_opened_detail"), nil)
                }
            }
        case "bookVet":
            guard !value("vetID").isEmpty else { finish(nil, lensError("purelens_error_invalid_payload")); return }
            dismissLensThen {
                owner.pp_homeOpenCareSection(1, mainKind: nil)
                finish(self.actionReceipt(titleKey: "purelens_action_vet_opened", detailKey: "purelens_action_vet_opened_detail"), nil)
            }
        case "openAdoption":
            dismissLensThen {
                owner.pp_homeOpenAdoption()
                finish(self.actionReceipt(titleKey: "purelens_action_adoption_opened", detailKey: "purelens_action_adoption_opened_detail"), nil)
            }
        case "contactSupport":
            dismissLensThen {
                PPAccessoryViewerLegacyBridge.openSupport(from: owner)
                finish(self.actionReceipt(titleKey: "purelens_action_support_opened", detailKey: "purelens_action_support_opened_detail"), nil)
            }
        case "createListingDraft":
            guard let root = owner.tabBarController as? PPRootTabBarController else {
                finish(nil, lensError("purelens_error_listing_unavailable"))
                return
            }
            var prefill: [String: String] = [:]
            for (key, rawValue) in payload {
                guard let key = key as? String, let rawValue = rawValue as? String else { continue }
                prefill[key] = rawValue
            }
            dismissLensThen {
                root.pp_openListingDraft(prefill: prefill)
                finish(self.actionReceipt(titleKey: "purelens_action_listing_opened", detailKey: "purelens_action_listing_opened_detail"), nil)
            }
        default:
            finish(nil, lensError("purelens_error_invalid_action"))
        }
    }

    @objc(pureLensTrackEvent:properties:)
    func pureLensTrackEvent(_ name: String, properties: NSDictionary) {
        if name == Self.lensConsentEvent {
            persistCurrentLensConsent()
        }

        let allowedEvents: Set<String> = [
            "pure_lens_opened",
            "pure_lens_pet_profile_verified",
            "pure_lens_pet_profile_required",
            "pure_lens_pet_detected",
            "pure_lens_discover_tapped",
            "pure_lens_auto_resolve_started",
            "pure_lens_insight_shown",
            "pure_lens_action_confirmed",
            "pure_lens_action_succeeded",
            "pure_lens_failed",
            "pure_lens_detector_degraded",
            "pure_lens_remote_processing_declined",
            Self.lensConsentEvent
        ]
        guard allowedEvents.contains(name) else { return }

        let allowedProperties: Set<String> = [
            "localDetectionCount", "feedbackPlayed", "confidence", "action", "domain", "kind", "errorType"
        ]
        var parameters: [String: Any] = [:]
        properties.forEach { key, value in
            guard let key = key as? String,
                  allowedProperties.contains(key),
                  let value = value as? String,
                  value.count <= 120
            else { return }
            parameters[key] = value
        }
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
    }

    // MARK: - Pet and catalog helpers

    private func loadPetContext(preferredPetID: String?, completion: @escaping (LensContext?, NSError?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion(nil, lensError("purelens_error_auth"))
            return
        }
        let manager = PPPetProfileManager.shared()
        manager.currentUserUID = uid
        manager.fetchPetProfilesForCurrentUser { pets, error in
            DispatchQueue.main.async {
                guard error == nil else { completion(nil, error as NSError?); return }
                let all = pets ?? []
                let selected = preferredPetID.flatMap { wanted in all.first { $0.petID == wanted } }
                    ?? all.first(where: { $0.isDefaultPet }) ?? all.first
                guard let pet = selected, !pet.petID.isEmpty else { completion(nil, nil); return }
                completion(
                    LensContext(
                        activePetID: pet.petID,
                        activePetName: pet.name.isEmpty ? nil : pet.name,
                        petIdentityConfidence: nil,
                        proactiveHint: nil,
                        proactiveHintExpiresAt: nil,
                        localeIdentifier: Language.currentLanguageCode() ?? Locale.current.identifier,
                        timeZoneIdentifier: TimeZone.current.identifier,
                        clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    ),
                    nil
                )
            }
        }
    }

    private func fetchAccessory(id: String, completion: @escaping (PetAccessory?, NSError?) -> Void) {
        guard !id.isEmpty else { completion(nil, lensError("purelens_error_invalid_payload")); return }
        PetAccessoryManager.fetchAccessories(withIDs: [id]) { accessories in
            DispatchQueue.main.async {
                completion(accessories.first, accessories.first == nil ? self.lensError("purelens_error_product_unavailable") : nil)
            }
        }
    }

    private func available(_ product: PetAccessory, requireStock: Bool) -> Bool {
        product.showInAppMarket && !product.isLivePet && !PPAccessoryViewerLegacyBridge.isUnavailable(product) && (!requireStock || product.quantity > 0)
    }

    private func contextDictionary(_ context: LensContext) -> NSDictionary {
        var result: [String: Any] = [
            "activePetID": context.activePetID ?? "",
            "activePetName": context.activePetName ?? "",
            "localeIdentifier": context.localeIdentifier,
            "timeZoneIdentifier": context.timeZoneIdentifier
        ]
        if let confidence = context.petIdentityConfidence { result["petIdentityConfidence"] = confidence }
        if let version = context.clientVersion { result["clientVersion"] = version }
        return result as NSDictionary
    }

    private func actionReceipt(titleKey: String, detailKey: String, metadata: [String: String] = [:]) -> NSDictionary {
        [
            "title": localizedLens(titleKey),
            "detail": localizedLens(detailKey),
            "metadata": metadata
        ] as NSDictionary
    }

    private func localizedLens(_ key: String) -> String {
        PPAccessoryViewerLegacyBridge.localizedText(key: key, fallback: key)
    }

    private func cartErrorKey(_ rawValue: Int) -> String {
        switch rawValue {
        case 1: return "purelens_error_cart_cancelled"
        case 2: return "purelens_error_offline"
        case 3: return "purelens_error_auth"
        case 4: return "purelens_error_cart_out_of_stock"
        case 5: return "purelens_error_product_unavailable"
        default: return "purelens_error_cart_failed"
        }
    }

    private func dismissLensThen(_ action: @escaping () -> Void) {
        guard let owner, owner.presentedViewController != nil else {
            action()
            return
        }
        owner.dismiss(animated: true, completion: action)
    }

    private var lensConsentDefaultsKey: String? {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return nil }
        return "PurePets.PureLens.remoteConsent.\(uid)"
    }

    private var hasCurrentLensConsent: Bool {
        guard let key = lensConsentDefaultsKey,
              let record = UserDefaults.standard.dictionary(forKey: key),
              record["granted"] as? Bool == true,
              record["version"] as? String == Self.lensConsentVersion
        else { return false }
        return true
    }

    private func persistCurrentLensConsent() {
        guard let key = lensConsentDefaultsKey else { return }
        UserDefaults.standard.set(
            ["granted": true, "version": Self.lensConsentVersion],
            forKey: key
        )
    }

    private func topViewController(from root: UIViewController) -> UIViewController {
        var current = root
        while let presented = current.presentedViewController { current = presented }
        return current
    }

    private func lensError(_ key: String) -> NSError {
        NSError(
            domain: "PurePets.PureLens",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: localizedLens(key)]
        )
    }

    private func performOnce(_ key: String, action: () -> Void) {
        guard inFlightRoutes.insert(key).inserted else { return }
        action()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self?.inFlightRoutes.remove(key)
        }
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
