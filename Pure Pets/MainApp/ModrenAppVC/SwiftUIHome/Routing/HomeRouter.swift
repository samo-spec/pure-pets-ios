import FirebaseAnalytics
import FirebaseAuth
import Foundation
import PureLens
import SwiftUI
import UIKit

@MainActor
final class HomeRouter: NSObject {
    private(set) weak var owner: PPHomeViewController?
    private var inFlightRoutes = Set<String>()
    private let pureLensPresenter = PPPureLensHostPresenter()

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
        // A Home pet can remain the launch affordance, but scanner eligibility
        // and discovery are deliberately identical when this value is nil.
        _ = pet
        guard let owner else { return }
        pureLensPresenter.present(from: owner)
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

    private func performOnce(_ key: String, action: () -> Void) {
        guard inFlightRoutes.insert(key).inserted else { return }
        action()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self?.inFlightRoutes.remove(key)
        }
    }
}

/// The single host-app composition root for Home and Account entry points.
/// It owns no PetProfile manager and persists no detected animal identity.
@objcMembers
@MainActor
final class PPPureLensHostPresenter: NSObject {
    private static let consentVersion = "purelens-3.0-google-gemini-no-retention-v1"
    private static let consentEvent = "pure_lens_remote_processing_consent_granted"

    private var isPresenting = false

    @objc(presentFromViewController:)
    func present(from viewController: UIViewController) {
        guard #available(iOS 16.0, *), !isPresenting else { return }
        let presenter = resolvedPresenter(from: viewController)
        guard presenter.viewIfLoaded?.window != nil,
              presenter.presentedViewController == nil,
              !presenter.isBeingDismissed
        else { return }

        isPresenting = true
        let bridge = PPPureLensDiscoveryBridge(presenter: presenter)
        let configuration = PureLensConfiguration(
            hapticsEnabled: true,
            hasPriorRemoteProcessingConsent: hasCurrentConsent,
            remoteProcessingConsentVersion: Self.consentVersion,
            remoteProcessingDisclosure: localized("purelens_remote_processing_disclosure"),
            localeIdentifier: Language.currentLanguageCode() ?? Locale.current.identifier
        )
        let itemLimit = configuration.discoveryItemLimit
        let discovery = LensDiscoveryClient(
            isAnimalSupported: { animal in
                try await withCheckedThrowingContinuation { continuation in
                    bridge.validateSpecies(animal.species) { supported, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: supported)
                        }
                    }
                }
            },
            searchByImage: { frame, animal in
                let rows: NSArray = try await withCheckedThrowingContinuation { continuation in
                    bridge.searchImage(
                        data: frame.data,
                        contentType: frame.mimeType,
                        species: animal.species,
                        breed: animal.breed,
                        limit: itemLimit
                    ) { items, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: (items ?? []) as NSArray)
                        }
                    }
                }
                return LensImageSearchResult(
                    items: try PureLensDiscoveryDictionaryAdapter.items(
                        from: rows,
                        limit: itemLimit
                    )
                )
            },
            searchMarketplace: { category, animal in
                let rows: NSArray = try await withCheckedThrowingContinuation { continuation in
                    bridge.searchMarketplace(
                        category: category.rawValue,
                        species: animal.species,
                        breed: animal.breed,
                        limit: itemLimit
                    ) { items, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: (items ?? []) as NSArray)
                        }
                    }
                }
                return try PureLensDiscoveryDictionaryAdapter.items(from: rows, limit: itemLimit)
                    .filter { $0.category == category }
            }
        )
        let module = PureLensModule.production(
            configuration: configuration,
            theme: appTheme,
            discovery: discovery,
            actionHandler: { item in
                try await withCheckedThrowingContinuation { continuation in
                    bridge.openItem(identifier: item.id, kind: item.kind.rawValue) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
            },
            guidanceActions: LensGuidanceActionClient { [weak self, weak presenter] handoff in
                guard let self, let presenter else { return }
                self.openNova(from: presenter, handoff: handoff)
            },
            analytics: LensAnalyticsClient { [weak self] name, properties in
                Task { @MainActor in
                    self?.track(name: name, properties: properties)
                }
            }
        )
        let lens = PureLensUIKit.makeViewController(module: module)
        presenter.present(lens, animated: true) { [weak self] in
            self?.isPresenting = false
        }
    }

    private func track(name: String, properties: [String: String]) {
        if name == Self.consentEvent {
            persistCurrentConsent()
        }
        let allowedEvents: Set<String> = [
            "pure_lens_opened",
            "pure_lens_pet_detected",
            "pure_lens_failed",
            "pure_lens_detector_degraded",
            "pure_lens_unsupported_subject",
            "pure_lens_taxonomy_validation_failed",
            "pure_lens_remote_processing_declined",
            "pure_lens_discovery_category_failed",
            "pure_lens_image_search_completed",
            "pure_lens_image_search_failed",
            "pure_lens_discovery_item_opened",
            "pure_lens_discovery_item_open_failed",
            "pure_lens_guidance_opened",
            Self.consentEvent
        ]
        guard allowedEvents.contains(name) else { return }

        let allowedProperties: Set<String> = [
            "feedbackPlayed", "confidence", "category", "kind", "errorType", "resultCount", "species", "version"
        ]
        let parameters = properties.reduce(into: [String: Any]()) { result, element in
            guard allowedProperties.contains(element.key), element.value.count <= 120 else { return }
            result[element.key] = element.value
        }
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
    }

    private func openNova(
        from presenter: UIViewController,
        handoff: LensGuidanceHandoff
    ) {
        let format = localized("purelens_nova_context_draft")
        let localeIdentifier = Language.currentLanguageCode() ?? Locale.current.identifier
        let draft = String(
            format: format,
            locale: Locale(identifier: localeIdentifier),
            handoff.displayName
        )
        let presentNova = { [weak presenter] in
            guard let presenter, presenter.viewIfLoaded?.window != nil else { return }
            PPNovaAmbientAssistantChatBridge.open(
                from: presenter,
                initialDraft: draft
            )
        }

        if let presented = presenter.presentedViewController {
            presenter.dismiss(animated: true, completion: presentNova)
        } else {
            presentNova()
        }
    }

    private var appTheme: PureLensTheme {
        PureLensTheme(
            canvas: .ppBackground,
            ambientField: .ppSurfaceBase,
            surface: .ppSurface,
            surfaceRaised: .ppSurfaceRaised,
            surfaceElevated: .ppSurfaceElevated,
            overlay: Color.black.opacity(0.44),
            cameraChrome: .black,
            brandStrong: .ppPrimary,
            brandSignal: .ppAccentText,
            brandPressed: .ppPressedAction,
            brandSoft: .ppSoftRose,
            recognition: .ppSuccess,
            textPrimary: .ppTextPrimary,
            textSecondary: .ppTextSecondary,
            textOnCamera: .white,
            success: .ppSuccess,
            warning: .ppWarning,
            warningOnCamera: .ppWarning,
            danger: .ppError,
            separator: .ppSeparator,
            typography: .purePets
        )
    }

    private var consentDefaultsKey: String? {
        guard let identity = Auth.auth().currentUser?.uid, !identity.isEmpty else {
            return nil
        }
        return "PurePets.PureLens.remoteConsent.\(identity)"
    }

    private var hasCurrentConsent: Bool {
        guard let key = consentDefaultsKey,
              let record = UserDefaults.standard.dictionary(forKey: key),
              record["granted"] as? Bool == true,
              record["version"] as? String == Self.consentVersion
        else { return false }
        return true
    }

    private func persistCurrentConsent() {
        guard let key = consentDefaultsKey else { return }
        UserDefaults.standard.set(
            ["granted": true, "version": Self.consentVersion],
            forKey: key
        )
    }

    private func localized(_ key: String) -> String {
        PPAccessoryViewerLegacyBridge.localizedText(key: key, fallback: key)
    }

    private func resolvedPresenter(from source: UIViewController) -> UIViewController {
        if let navigation = source as? UINavigationController {
            return navigation.topViewController ?? navigation
        }
        if let tab = source as? UITabBarController {
            return resolvedPresenter(from: tab.selectedViewController ?? tab)
        }
        return source
    }
}
