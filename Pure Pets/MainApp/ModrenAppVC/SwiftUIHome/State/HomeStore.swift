import Foundation
import os
import SwiftUI
import UIKit

/// Stable raw values from the legacy `PPHomeSection` contract. Swift imports
/// that Objective-C enum differently across toolchains, while HomeConfig
/// persists these exact numeric identifiers.
private enum HomeLegacySectionID: Int, CaseIterable {
    case hero = 0
    case quickActions = 1
    case currentOrders = 2
    case carousel = 4
    case mainKinds = 5
    case suggestions = 6
    case accessories = 7
    case petProfile = 8
    case premiumCare = 9
    case lastFood = 10
    case nearbyServices = 11
    case adsNearby = 12
    case adopt = 13
    case buyAgain = 14
    case premiumSearch = 15
    case providerCategoryNav = 16
    case marketplaceHero = 17
    case suggestionAds = 18
    case suggestionAccessories = 19
}

private enum HomeHeroPresentationMode {
    static let marketplaceHeroID = "home-marketplace-hero"
}

private enum HomeMarketplaceFeedKind {
    case recommendations
    case advertisements
    case accessorySuggestions
    case accessories
    case food
    case nearbyAdvertisements
    case services
}

private enum HomeMarketplaceAudience {
    case pet
    case category(String)
    case general
}

private struct HomeSectionCopy {
    let title: String
    let subtitle: String
}

@MainActor
final class HomeStore: ObservableObject {
    @Published private(set) var state: HomeViewState
    @Published private(set) var scrollToTopGeneration = 0
    @Published private(set) var sectionDataRevisions: [Int: Int] = [:]

    let router: HomeRouter

    private let repository: HomeRepository
    private var mainKinds: [NSObject] = []
    private var promotions: [NSObject] = []
    private var accessories: [PetAccessory] = []
    private var food: [PetAccessory] = []
    private var advertisements: [PetAd] = []
    private var nearbyAdvertisements: [PetAd] = []
    private var services: [ServiceModel] = []
    private var petProfiles: [NSObject] = []
    private var petReminders: [NSObject] = []
    private var recentOrders: [NSObject] = []
    private var buyAgainAccessories: [PetAccessory] = []
    private var categoryAccessories: [Int: [PetAccessory]] = [:]
    private var categoryAccessoryRequests = Set<Int>()
    private var staleCategoryAccessoryIDs = Set<Int>()
    private var showingRecentNearbyFallback = false

    private var loadedSources = Set<Int>()
    private var sourceErrors: [Int: String] = [:]
    private var observers: [NSObjectProtocol] = []
    private var heroRotationTask: Task<Void, Never>?
    private var heroPauseGeneration = 0
    private var initialMainKindID: Int?
    private var orderResolutionGeneration = 0
    private var started = false
    private var visible = false
    private var sceneActive = true
    private var heroInteractionActive = false
    private var voiceOverRunning = UIAccessibility.isVoiceOverRunning
    private var reduceMotion = UIAccessibility.isReduceMotionEnabled
    private var hasPublishedLoadedState = false
    private var refreshRequestGeneration = 0
    private var refreshCompletionPending = false
    private var refreshPendingSources = Set<Int>()
    private var refreshUpdatedSectionIDs = Set<Int>()
    private var refreshTimeoutTask: Task<Void, Never>?
    private var refreshSignpostID: OSSignpostID?

    private static let selectedMainKindKey = "PPHome.lastSelectedMainKindID.v1"
    private static let selectedPetKey = "pp.home.selectedPetID.v2"
    private static let refreshLog = OSLog(
        subsystem: "com.purepets.ios",
        category: "HomeReload"
    )
    private static let trackedRefreshSources: Set<Int> = [
        PPHomeBridgeSource.mainKinds.rawValue,
        PPHomeBridgeSource.accessories.rawValue,
        PPHomeBridgeSource.food.rawValue,
        PPHomeBridgeSource.advertisements.rawValue,
        PPHomeBridgeSource.nearbyAdvertisements.rawValue,
        PPHomeBridgeSource.services.rawValue,
        PPHomeBridgeSource.petProfiles.rawValue,
        PPHomeBridgeSource.petReminders.rawValue,
    ]

    init(
        owner: PPHomeViewController,
        repository: HomeRepository? = nil
    ) {
        let resolvedRepository = repository ?? HomeRepository()
        self.router = HomeRouter(owner: owner)
        self.repository = resolvedRepository

        var initial = HomeViewState.initial
        initial.languageCode = Language.currentLanguageCode() ?? "ar"
        initial.isRightToLeft = Language.isRTL()
        initial.cartCount = PPHomeDataBridge.currentCartItemCount()
        initial.bottomContentClearance = router.bottomContentClearance()
        self.state = initial

        resolvedRepository.onEvent = { [weak self] event in
            self?.handle(event)
        }
        installObservers()
    }

    deinit {
        heroRotationTask?.cancel()
        refreshTimeoutTask?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func setInitialMainKindID(_ identifier: Int) {
        guard identifier > 0 else { return }
        initialMainKindID = identifier
        rebuildState()
    }

    func start() {
        guard !started else { return }
        started = true
        state.phase = state.config.cameFromCache ? .warmLoading : .coldLoading
        repository.start()
        restartHeroRotation()
    }

    func setVisible(_ value: Bool) {
        guard visible != value else { return }
        heroPauseGeneration += 1
        heroInteractionActive = false
        visible = value
        if value {
            state.bottomContentClearance = router.bottomContentClearance()
            repository.refresh()
        }
        restartHeroRotation()
    }

    func setSceneActive(_ active: Bool) {
        guard sceneActive != active else { return }
        sceneActive = active
        if active && visible {
            repository.refresh()
        }
        restartHeroRotation()
    }

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        restartHeroRotation()
    }

    func setVoiceOverRunning(_ enabled: Bool) {
        guard voiceOverRunning != enabled else { return }
        voiceOverRunning = enabled
        restartHeroRotation()
    }

    func setHeroInteractionActive(_ active: Bool) {
        guard heroInteractionActive != active else { return }
        heroPauseGeneration += 1
        heroInteractionActive = active
        restartHeroRotation()
    }

    func refresh() async {
        guard !refreshCompletionPending,
              let generation = beginTrackedRefresh()
        else {
            return
        }

        while refreshCompletionPending,
              generation == refreshRequestGeneration,
              !Task.isCancelled {
            try? await Task<Never, Never>.sleep(nanoseconds: 100_000_000)
        }
    }

    func retryAll() {
        guard !refreshCompletionPending else { return }
        let previousErrors = sourceErrors
        sourceErrors.removeAll()
        rebuildState()
        guard beginTrackedRefresh() != nil else {
            sourceErrors = previousErrors
            rebuildState()
            return
        }
    }

    func retry(section: HomeSectionID) {
        for source in sourceIDs(for: section) {
            sourceErrors.removeValue(forKey: source)
        }
        rebuildState()
        repository.refresh()
    }

    func handleReselection() {
        scrollToTopGeneration += 1
        repository.refresh()
    }

    func sectionDataRevision(for rawSectionID: Int) -> Int {
        sectionDataRevisions[rawSectionID, default: 0]
    }

    func selectHero(index: Int) {
        guard state.heroPages.indices.contains(index) else { return }
        state.selectedHeroIndex = index
        restartHeroRotation()
    }

    func advanceHero(direction: Int = 1) {
        guard state.heroPages.count > 1 else { return }
        let count = state.heroPages.count
        let next = (state.selectedHeroIndex + direction + count) % count
        state.selectedHeroIndex = next
    }

    func performSelectedHeroAction() {
        guard state.heroPages.indices.contains(state.selectedHeroIndex) else {
            return
        }
        performHeroAction(state.heroPages[state.selectedHeroIndex])
    }

    func performSelectedHeroSecondaryAction() {
        guard state.heroPages.indices.contains(state.selectedHeroIndex) else {
            return
        }
        performHeroSecondaryAction(state.heroPages[state.selectedHeroIndex])
    }

    func performHeroAction(_ page: HomeHeroPage) {
        pauseHeroForNavigation()
        router.openHeroAction(page.action)
    }

    func performHeroSecondaryAction(_ page: HomeHeroPage) {
        switch page.kind {
        case .pet, .reminder:
            router.openAccessories(mainKind: selectedMainKind)
        case .promotion:
            if case let .openPromotion(card, _) = page.action {
                pauseHeroForNavigation()
                router.openHeroAction(
                    .openPromotion(card, interaction: "secondary")
                )
            }
        case .marketplace, .pharmacy:
            router.openServices(mainKind: selectedMainKind)
        case .petOnboarding:
            router.openAdvertisements(mainKind: selectedMainKind)
        }
    }

    func openProviderCategory(_ identifier: String) {
        switch identifier {
        case "veterinarians":
            router.openVeterinaryCare(mainKind: selectedMainKind)
        case "pharmacy":
            router.openProviderCategory(
                identifier: "pharmacy",
                titleKey: "provider_pharmacies_title",
                subtitleKey: "provider_pharmacies_subtitle"
            )
        default:
            router.openProviderCategory(
                identifier: identifier,
                titleKey: nil,
                subtitleKey: nil
            )
        }
    }

    func openAdoption() {
        router.openAdoption()
    }

    func selectCategory(_ category: HomeCategoryModel?) {
        guard let category else {
            state.selectedMainKindID = nil
            UserDefaults.standard.set(-1, forKey: Self.selectedMainKindKey)
            rebuildState()
            UISelectionFeedbackGenerator().selectionChanged()
            router.openAllCategories()
            return
        }

        let identifier = HomeModelAdapter.mainKindID(category.raw)
        guard identifier > 0 else { return }
        state.selectedMainKindID = identifier
        UserDefaults.standard.set(identifier, forKey: Self.selectedMainKindKey)
        rebuildState()
        UISelectionFeedbackGenerator().selectionChanged()
        router.openCategory(category)
    }

    func selectPet(_ pet: HomePetModel) {
        state.selectedPetID = pet.id
        UserDefaults.standard.set(pet.id, forKey: Self.selectedPetKey)
        if pet.categoryID > 0,
           state.categories.contains(where: {
               HomeModelAdapter.mainKindID($0.raw) == pet.categoryID
           }) {
            state.selectedMainKindID = pet.categoryID
            UserDefaults.standard.set(
                pet.categoryID,
                forKey: Self.selectedMainKindKey
            )
        }
        rebuildState()
        UISelectionFeedbackGenerator().selectionChanged()
        UIAccessibility.post(
            notification: .announcement,
            argument: String(
                format: HomeModelAdapter.localized(
                    "home_pulse_pet_selected_a11y",
                    fallback: "%@ selected"
                ),
                pet.name
            )
        )
    }

    func openPetProfiles() {
        router.openPetProfiles()
    }

    @objc func openPureLens() {
        let pet = selectedPet
        router.openPureLens(pet: pet)
    }

    func editSelectedPet() {
        guard let pet = selectedPet else {
            router.openPetProfiles()
            return
        }
        router.editPet(pet)
    }

    func performPriorityAction(_ action: HomePriorityAction) {
        let kind = selectedMainKind
        switch action.destination {
        case .shop:
            router.openAccessories(mainKind: kind)
        case .advertisements:
            router.openAdvertisements(mainKind: kind)
        case .veterinary:
            router.openVeterinaryCare(mainKind: kind)
        case .pharmacy:
            router.openPharmacy(mainKind: kind)
        case .services:
            router.openServices(mainKind: kind)
        case .petProfile:
            editSelectedPet()
        }
    }

    func exploreMarketplace() {
        router.openAccessories(mainKind: selectedMainKind)
    }

    func tapCard(_ card: HomeCardModel) {
        router.openDetails(for: card)
    }

    func setQuantity(_ quantity: Int, for card: HomeCardModel) {
        router.owner?.ppUniversalCell_changeQuantity(
            card.viewModel,
            quantity: quantity
        )
    }

    func openOrder(_ order: HomeOrderModel) {
        router.openOrder(order)
    }

    func seeAll(_ sectionID: HomeSectionID) {
        switch sectionID {
        case .currentOrder:
            router.openOrderHistory()
        case .buyAgain, .accessories, .recommendations:
            router.openAccessories(mainKind: selectedMainKind)
        case .advertisements:
            router.openAdvertisements(mainKind: selectedMainKind)
        case .food:
            router.openFood(mainKind: selectedMainKind)
        case .nearbyAdvertisements:
            if state.location.hasCoordinate {
                router.openNearbyAdvertisements()
            } else {
                router.openLocationPicker()
            }
        case .services:
            router.openServices(mainKind: selectedMainKind)
        }
    }

    func locationTapped() {
        switch state.location.presentation {
        case .notDetermined:
            repository.requestLocationAuthorization()
        case .denied, .restricted:
            router.openLocationSettings()
        case .failed:
            router.openLocationPicker()
        case .loading, .ready:
            router.presentLocationOptions()
        }
    }

    func requestAutomaticLocation() {
        repository.useAutomaticLocation()
    }

    func applyManualLocation(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        title: String
    ) {
        repository.setManualLocation(
            latitude: latitude,
            longitude: longitude,
            title: title
        )
    }

    private var selectedPet: HomePetModel? {
        if let selectedID = state.selectedPetID,
           let match = state.pets.first(where: { $0.id == selectedID }) {
            return match
        }
        return state.pets.first(where: \.isDefault) ?? state.pets.first
    }

    private var selectedMainKind: NSObject? {
        guard let selectedID = state.selectedMainKindID else { return nil }
        return state.categories.first {
            HomeModelAdapter.mainKindID($0.raw) == selectedID
        }?.raw
    }

    private var hasAnyContent: Bool {
        !accessories.isEmpty ||
        !food.isEmpty ||
        !advertisements.isEmpty ||
        !nearbyAdvertisements.isEmpty ||
        !services.isEmpty ||
        !petProfiles.isEmpty ||
        !recentOrders.isEmpty ||
        !promotions.isEmpty
    }

    private func handle(_ event: HomeRepositoryEvent) {
        let settledSource = sourceRawValue(for: event)
        let affectedSectionIDs = settledSource.map(sectionIDsAffected) ?? []
        let previousFingerprints = sectionPresentationFingerprints(
            for: affectedSectionIDs
        )

        switch event {
        case let .mainKinds(models):
            mainKinds = models
            markLoaded(PPHomeBridgeSource.mainKinds.rawValue)
        case let .promotions(models):
            promotions = models
            markLoaded(PPHomeBridgeSource.promotions.rawValue)
        case let .accessories(models):
            accessories = models
            // Keep scoped category results visible while refreshing them.
            // Clearing this cache here caused Home to oscillate from the
            // scoped shelf back to generic products after returning from
            // Marketplace.
            staleCategoryAccessoryIDs.formUnion(categoryAccessories.keys)
            markLoaded(PPHomeBridgeSource.accessories.rawValue)
            resolveBuyAgain()
        case let .food(models):
            food = models
            markLoaded(PPHomeBridgeSource.food.rawValue)
        case let .advertisements(models):
            advertisements = models
            markLoaded(PPHomeBridgeSource.advertisements.rawValue)
        case let .nearbyAdvertisements(models, fallback):
            nearbyAdvertisements = models
            showingRecentNearbyFallback = fallback
            markLoaded(PPHomeBridgeSource.nearbyAdvertisements.rawValue)
        case let .services(models):
            services = models
            markLoaded(PPHomeBridgeSource.services.rawValue)
        case let .petProfiles(models):
            petProfiles = models
            markLoaded(PPHomeBridgeSource.petProfiles.rawValue)
        case let .petReminders(models):
            petReminders = models
            markLoaded(PPHomeBridgeSource.petReminders.rawValue)
        case let .orders(models):
            recentOrders = models
            markLoaded(PPHomeBridgeSource.orders.rawValue)
            resolveBuyAgain()
        case let .homeConfig(
            sections,
            titleViewMode,
            premiumCareVisible,
            novaFloatingVisible,
            backgroundGlowsFaded,
            pureLensVisible,
            fromCache
        ):
            state.config = HomeModelAdapter.config(
                sections: sections,
                titleViewMode: titleViewMode,
                premiumCareVisible: premiumCareVisible,
                novaFloatingVisible: novaFloatingVisible,
                backgroundGlowsFaded: backgroundGlowsFaded,
                pureLensVisible: pureLensVisible,
                fromCache: fromCache
            )
            if fromCache && !hasPublishedLoadedState {
                state.phase = .warmLoading
            }
            markLoaded(PPHomeBridgeSource.homeConfig.rawValue)
        case let .location(locationState, areaName, coordinate, manual):
            state.location = HomeLocationModel(
                presentation: locationPresentation(locationState),
                areaName: areaName,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                isManual: manual
            )
            markLoaded(PPHomeBridgeSource.location.rawValue)
        case let .connectivity(connectivity):
            state.connectivity = connectivity
            state.hasStaleContent = connectivity == .offline && hasAnyContent
        case let .failure(sourceRawValue, error):
            sourceErrors[sourceRawValue] = error.localizedDescription
            if sourceRawValue != PPHomeBridgeSource.homeConfig.rawValue {
                loadedSources.insert(sourceRawValue)
            }
        }

        state.cartCount = PPHomeDataBridge.currentCartItemCount()
        state.languageCode = Language.currentLanguageCode() ?? "ar"
        state.isRightToLeft = Language.isRTL()
        rebuildState()
        if let settledSource {
            publishOrQueueSectionReloads(
                for: settledSource,
                changedSectionIDs: changedSectionIDs(
                    in: affectedSectionIDs,
                    comparedWith: previousFingerprints
                )
            )
        }
    }

    private func markLoaded(_ source: Int) {
        loadedSources.insert(source)
        sourceErrors.removeValue(forKey: source)
    }

    private func beginTrackedRefresh() -> Int? {
        refreshRequestGeneration += 1
        let generation = refreshRequestGeneration
        refreshCompletionPending = true
        refreshPendingSources = Self.trackedRefreshSources
        refreshUpdatedSectionIDs.removeAll(keepingCapacity: true)
        state.phase = .refreshing

        let signpostID = OSSignpostID(log: Self.refreshLog)
        refreshSignpostID = signpostID
        os_signpost(
            .begin,
            log: Self.refreshLog,
            name: "home.reload",
            signpostID: signpostID,
            "generation=%d sources=%d",
            generation,
            refreshPendingSources.count
        )

        guard repository.refresh() else {
            refreshCompletionPending = false
            refreshPendingSources.removeAll(keepingCapacity: true)
            updateScreenPhase()
            os_signpost(
                .end,
                log: Self.refreshLog,
                name: "home.reload",
                signpostID: signpostID,
                "generation=%d accepted=0",
                generation
            )
            refreshSignpostID = nil
            return nil
        }

        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = Task { [weak self] in
            try? await Task<Never, Never>.sleep(
                nanoseconds: 8_000_000_000
            )
            guard !Task.isCancelled,
                  let self,
                  generation == self.refreshRequestGeneration,
                  self.refreshCompletionPending
            else {
                return
            }
            self.finishTrackedRefresh(timedOut: true)
        }
        return generation
    }

    private func publishOrQueueSectionReloads(
        for source: Int,
        changedSectionIDs: Set<Int>
    ) {
        if refreshCompletionPending,
           source == PPHomeBridgeSource.accessories.rawValue,
           hasPendingSelectedCategoryAccessoryRequest {
            // The visible marketplace shelves are category-scoped. Keep the
            // accessories source pending until that authoritative request
            // settles instead of completing on the generic inventory fetch.
            refreshUpdatedSectionIDs.formUnion(changedSectionIDs)
            return
        }

        guard refreshCompletionPending,
              refreshPendingSources.remove(source) != nil
        else {
            publishSectionDataReload(changedSectionIDs)
            return
        }

        refreshUpdatedSectionIDs.formUnion(changedSectionIDs)
        if refreshPendingSources.isEmpty {
            finishTrackedRefresh(timedOut: false)
        }
    }

    private func finishTrackedRefresh(timedOut: Bool) {
        guard refreshCompletionPending else { return }

        let generation = refreshRequestGeneration
        let pendingCount = refreshPendingSources.count
        let updatedSectionIDs = refreshUpdatedSectionIDs
        let signpostID = refreshSignpostID

        refreshCompletionPending = false
        refreshPendingSources.removeAll(keepingCapacity: true)
        refreshUpdatedSectionIDs.removeAll(keepingCapacity: true)
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = nil
        refreshSignpostID = nil

        if timedOut {
            state.phase = hasAnyContent
                ? .partial
                : .failed(message: HomeModelAdapter.localized(
                    "home_refresh_interrupted",
                    fallback: "Refresh was interrupted. Try again."
                ))
        } else {
            updateScreenPhase()
        }
        publishSectionDataReload(updatedSectionIDs)

        if let signpostID {
            os_signpost(
                .end,
                log: Self.refreshLog,
                name: "home.reload",
                signpostID: signpostID,
                "generation=%d pending=%d timedOut=%d",
                generation,
                pendingCount,
                timedOut ? 1 : 0
            )
        }

        guard !timedOut else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: HomeModelAdapter.localized(
                "home_pulse_refresh_complete_a11y",
                fallback: "Home refreshed"
            )
        )
    }

    private func publishSectionDataReload(_ rawSectionIDs: Set<Int>) {
        guard !rawSectionIDs.isEmpty else { return }
        var revisions = sectionDataRevisions
        for rawSectionID in rawSectionIDs {
            let current = revisions[rawSectionID, default: 0]
            revisions[rawSectionID] = current == Int.max ? 1 : current + 1
        }
        sectionDataRevisions = revisions

        for rawSectionID in rawSectionIDs.sorted() {
            os_signpost(
                .event,
                log: Self.refreshLog,
                name: "home.section.reload",
                "rawID=%d revision=%d",
                rawSectionID,
                revisions[rawSectionID, default: 0]
            )
        }
    }

    private func queueOrPublishSectionDataReload(
        _ rawSectionIDs: Set<Int>
    ) {
        if refreshCompletionPending {
            refreshUpdatedSectionIDs.formUnion(rawSectionIDs)
        } else {
            publishSectionDataReload(rawSectionIDs)
        }
    }

    private var hasPendingSelectedCategoryAccessoryRequest: Bool {
        guard let selectedMainKindID = state.selectedMainKindID else {
            return false
        }
        return categoryAccessoryRequests.contains(selectedMainKindID)
    }

    private func sourceRawValue(for event: HomeRepositoryEvent) -> Int? {
        switch event {
        case .mainKinds:
            return PPHomeBridgeSource.mainKinds.rawValue
        case .promotions:
            return PPHomeBridgeSource.promotions.rawValue
        case .accessories:
            return PPHomeBridgeSource.accessories.rawValue
        case .food:
            return PPHomeBridgeSource.food.rawValue
        case .advertisements:
            return PPHomeBridgeSource.advertisements.rawValue
        case .nearbyAdvertisements:
            return PPHomeBridgeSource.nearbyAdvertisements.rawValue
        case .services:
            return PPHomeBridgeSource.services.rawValue
        case .petProfiles:
            return PPHomeBridgeSource.petProfiles.rawValue
        case .petReminders:
            return PPHomeBridgeSource.petReminders.rawValue
        case .orders:
            return PPHomeBridgeSource.orders.rawValue
        case .homeConfig:
            return PPHomeBridgeSource.homeConfig.rawValue
        case .location:
            return PPHomeBridgeSource.location.rawValue
        case .connectivity:
            return nil
        case let .failure(sourceRawValue, _):
            return sourceRawValue
        }
    }

    private func sectionIDsAffected(by source: Int) -> Set<Int> {
        let contextualMarketplaceSections: Set<Int> = [
            HomeLegacySectionID.suggestions.rawValue,
            HomeLegacySectionID.accessories.rawValue,
            HomeLegacySectionID.lastFood.rawValue,
            HomeLegacySectionID.nearbyServices.rawValue,
            HomeLegacySectionID.adsNearby.rawValue,
            HomeLegacySectionID.suggestionAds.rawValue,
            HomeLegacySectionID.suggestionAccessories.rawValue,
        ]

        switch source {
        case PPHomeBridgeSource.mainKinds.rawValue:
            return contextualMarketplaceSections.union([
                HomeLegacySectionID.hero.rawValue,
                HomeLegacySectionID.mainKinds.rawValue,
                HomeLegacySectionID.marketplaceHero.rawValue,
            ])
        case PPHomeBridgeSource.promotions.rawValue:
            return [HomeLegacySectionID.carousel.rawValue]
        case PPHomeBridgeSource.accessories.rawValue:
            return [
                HomeLegacySectionID.suggestions.rawValue,
                HomeLegacySectionID.accessories.rawValue,
                HomeLegacySectionID.suggestionAccessories.rawValue,
            ]
        case PPHomeBridgeSource.food.rawValue:
            return [HomeLegacySectionID.lastFood.rawValue]
        case PPHomeBridgeSource.advertisements.rawValue:
            return [
                HomeLegacySectionID.suggestions.rawValue,
                HomeLegacySectionID.suggestionAds.rawValue,
            ]
        case PPHomeBridgeSource.nearbyAdvertisements.rawValue,
             PPHomeBridgeSource.location.rawValue:
            return [HomeLegacySectionID.adsNearby.rawValue]
        case PPHomeBridgeSource.services.rawValue:
            return [
                HomeLegacySectionID.suggestions.rawValue,
                HomeLegacySectionID.nearbyServices.rawValue,
            ]
        case PPHomeBridgeSource.petProfiles.rawValue:
            return contextualMarketplaceSections.union([
                HomeLegacySectionID.hero.rawValue,
                HomeLegacySectionID.quickActions.rawValue,
                HomeLegacySectionID.petProfile.rawValue,
                HomeLegacySectionID.marketplaceHero.rawValue,
            ])
        case PPHomeBridgeSource.petReminders.rawValue:
            return [HomeLegacySectionID.hero.rawValue]
        case PPHomeBridgeSource.orders.rawValue:
            return [HomeLegacySectionID.currentOrders.rawValue]
        case PPHomeBridgeSource.homeConfig.rawValue:
            return Set(HomeLegacySectionID.allCases.map(\.rawValue))
        default:
            return []
        }
    }

    private func changedSectionIDs(
        in candidates: Set<Int>,
        comparedWith previous: [Int: String]
    ) -> Set<Int> {
        let current = sectionPresentationFingerprints(for: candidates)
        return Set(candidates.filter { previous[$0] != current[$0] })
    }

    private func sectionPresentationFingerprints(
        for rawSectionIDs: Set<Int>
    ) -> [Int: String] {
        Dictionary(uniqueKeysWithValues: rawSectionIDs.map {
            ($0, sectionPresentationFingerprint(for: $0))
        })
    }

    private func sectionPresentationFingerprint(for rawSectionID: Int) -> String {
        switch rawSectionID {
        case HomeLegacySectionID.hero.rawValue:
            return heroPagesFingerprint(state.heroPages)
        case HomeLegacySectionID.quickActions.rawValue:
            return ([state.selectedPetID ?? ""] + state.priorityActions.map {
                [$0.id, $0.title, $0.subtitle].joined(separator: "|")
            }).joined(separator: "^")
        case HomeLegacySectionID.currentOrders.rawValue:
            guard let order = state.featuredOrder else { return "none" }
            return [
                order.id,
                order.statusKey,
                order.statusTitle,
                order.statusHint,
                String(order.progress),
                String(order.itemCount),
                order.amount,
            ].joined(separator: "|")
        case HomeLegacySectionID.carousel.rawValue:
            return heroPagesFingerprint(state.promotionPages)
        case HomeLegacySectionID.mainKinds.rawValue:
            return state.categories.map {
                [$0.id, $0.title, $0.imageURL ?? ""].joined(separator: "|")
            }.joined(separator: "^")
        case HomeLegacySectionID.petProfile.rawValue:
            return state.pets.map {
                [
                    $0.id,
                    $0.name,
                    $0.breedOrCategory,
                    $0.age,
                    $0.imageURL ?? "",
                    String($0.isDefault),
                ].joined(separator: "|")
            }.joined(separator: "^")
        case HomeLegacySectionID.marketplaceHero.rawValue:
            guard let page = state.marketplaceHeroPage else { return "none" }
            return heroPagesFingerprint([page])
        case HomeLegacySectionID.suggestions.rawValue,
             HomeLegacySectionID.accessories.rawValue,
             HomeLegacySectionID.lastFood.rawValue,
             HomeLegacySectionID.nearbyServices.rawValue,
             HomeLegacySectionID.adsNearby.rawValue,
             HomeLegacySectionID.buyAgain.rawValue,
             HomeLegacySectionID.suggestionAds.rawValue,
             HomeLegacySectionID.suggestionAccessories.rawValue:
            guard let section = state.sections.first(where: {
                $0.id == rawSectionID
            }) else {
                return "absent"
            }
            return sectionFingerprint(section)
        default:
            let config = state.config.section(withID: rawSectionID)
            return config.map {
                "\($0.type)|\($0.isVisible)"
            } ?? "absent"
        }
    }

    private func heroPagesFingerprint(_ pages: [HomeHeroPage]) -> String {
        pages.map {
            [
                $0.id,
                $0.title,
                $0.subtitle,
                $0.imageURL ?? "",
                $0.accentHex,
            ].joined(separator: "|")
        }.joined(separator: "^")
    }

    private func sectionFingerprint(_ section: HomeSectionModel) -> String {
        let stateFingerprint: String
        switch section.state {
        case .loading:
            stateFingerprint = "loading"
        case let .content(cards):
            stateFingerprint = "content:" + cards.map(\.id).joined(separator: ",")
        case let .empty(title, message, actionTitle):
            stateFingerprint = [
                "empty",
                title,
                message,
                actionTitle ?? "",
            ].joined(separator: "|")
        case let .failed(title, message, retryTitle):
            stateFingerprint = [
                "failed",
                title,
                message,
                retryTitle,
            ].joined(separator: "|")
        }
        return [
            section.title,
            section.subtitle ?? "",
            stateFingerprint,
        ].joined(separator: "^")
    }

    private func resolveBuyAgain() {
        orderResolutionGeneration += 1
        let generation = orderResolutionGeneration
        let itemIDs = HomeModelAdapter.orderItemIDs(from: recentOrders, limit: 8)
        let affectedSectionIDs: Set<Int> = [
            HomeLegacySectionID.buyAgain.rawValue,
        ]
        guard !itemIDs.isEmpty else {
            let previousFingerprints = sectionPresentationFingerprints(
                for: affectedSectionIDs
            )
            buyAgainAccessories = []
            rebuildState()
            queueOrPublishSectionDataReload(changedSectionIDs(
                in: affectedSectionIDs,
                comparedWith: previousFingerprints
            ))
            return
        }
        repository.resolveAccessories(ids: itemIDs) { [weak self] resolved in
            guard let self, generation == self.orderResolutionGeneration else {
                return
            }
            let previousFingerprints = self.sectionPresentationFingerprints(
                for: affectedSectionIDs
            )
            let order = Dictionary(
                itemIDs.enumerated().map { ($1, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            self.buyAgainAccessories = resolved.sorted {
                let lhs = order[$0.accessoryID] ?? Int.max
                let rhs = order[$1.accessoryID] ?? Int.max
                return lhs < rhs
            }
            self.rebuildState()
            self.queueOrPublishSectionDataReload(self.changedSectionIDs(
                in: affectedSectionIDs,
                comparedWith: previousFingerprints
            ))
        }
    }

    private func requestCategoryAccessoriesIfNeeded(for categoryID: Int?) {
        guard let categoryID,
              categoryID > 0,
              categoryAccessories[categoryID] == nil ||
                staleCategoryAccessoryIDs.contains(categoryID),
              categoryAccessoryRequests.insert(categoryID).inserted
        else {
            return
        }

        repository.loadAccessories(mainCategoryID: categoryID) { [weak self] items in
            guard let self else { return }
            let affectedSectionIDs: Set<Int> = [
                HomeLegacySectionID.suggestions.rawValue,
                HomeLegacySectionID.accessories.rawValue,
                HomeLegacySectionID.suggestionAccessories.rawValue,
            ]
            let previousFingerprints = self.sectionPresentationFingerprints(
                for: affectedSectionIDs
            )
            self.categoryAccessoryRequests.remove(categoryID)
            self.categoryAccessories[categoryID] = items
            self.staleCategoryAccessoryIDs.remove(categoryID)
            guard self.state.selectedMainKindID == categoryID else { return }
            self.rebuildState()
            let changedSectionIDs = self.changedSectionIDs(
                in: affectedSectionIDs,
                comparedWith: previousFingerprints
            )
            if self.refreshCompletionPending,
               self.refreshPendingSources.contains(
                   PPHomeBridgeSource.accessories.rawValue
               ) {
                self.publishOrQueueSectionReloads(
                    for: PPHomeBridgeSource.accessories.rawValue,
                    changedSectionIDs: changedSectionIDs
                )
            } else {
                self.queueOrPublishSectionDataReload(changedSectionIDs)
            }
        }
    }

    private func rebuildState() {
        let previousHeroIDs = state.heroPages.map(\.id)
        state.categories = HomeModelAdapter.categories(from: mainKinds)
        state.pets = HomeModelAdapter.pets(from: petProfiles)

        let persistedCategory = UserDefaults.standard.object(
            forKey: Self.selectedMainKindKey
        ) as? NSNumber
        let savedMainKindID = HomeModelAdapter.selectedCategoryID(
            persistedID: persistedCategory?.intValue,
            initialID: initialMainKindID,
            categories: state.categories
        )

        let persistedPetID = UserDefaults.standard.string(
            forKey: Self.selectedPetKey
        )
        if let persistedPetID,
           state.pets.contains(where: { $0.id == persistedPetID }) {
            state.selectedPetID = persistedPetID
        } else {
            state.selectedPetID =
                state.pets.first(where: \.isDefault)?.id ?? state.pets.first?.id
        }

        if let savedMainKindID {
            state.selectedMainKindID = savedMainKindID
        } else if persistedCategory?.intValue == -1 {
            state.selectedMainKindID = nil
        } else if let petCategoryID = selectedPet?.categoryID,
                  petCategoryID > 0,
                  state.categories.contains(where: {
                      HomeModelAdapter.mainKindID($0.raw) == petCategoryID
                  }) {
            state.selectedMainKindID = petCategoryID
        } else {
            state.selectedMainKindID = nil
        }
        requestCategoryAccessoriesIfNeeded(for: state.selectedMainKindID)

        state.heroPages = buildContextHeroPages()
        state.promotionPages = buildPromotionHeroPages()
        state.marketplaceHeroPage = buildMarketplaceHeroPage()
        if state.heroPages.isEmpty {
            state.selectedHeroIndex = 0
        } else {
            state.selectedHeroIndex = min(
                state.selectedHeroIndex,
                state.heroPages.count - 1
            )
        }
        state.priorityActions = buildPriorityActions()
        state.featuredOrder = HomeModelAdapter.featuredOrder(from: recentOrders)
        state.sections = buildSections()
        state.bottomContentClearance = router.bottomContentClearance()
        updateScreenPhase()
        if previousHeroIDs != state.heroPages.map(\.id) {
            restartHeroRotation()
        }
    }

    private func updateScreenPhase() {
        let coreSources: Set<Int> = [
            PPHomeBridgeSource.mainKinds.rawValue,
            PPHomeBridgeSource.accessories.rawValue,
            PPHomeBridgeSource.advertisements.rawValue,
            PPHomeBridgeSource.services.rawValue,
            PPHomeBridgeSource.homeConfig.rawValue,
        ]
        let coreFinished = coreSources.isSubset(of: loadedSources)
        let hasFailures = !sourceErrors.isEmpty

        guard coreFinished else {
            if !hasAnyContent {
                state.phase = state.config.cameFromCache
                    ? .warmLoading
                    : .coldLoading
            }
            return
        }

        hasPublishedLoadedState = true
        if !hasAnyContent && state.categories.isEmpty {
            if let firstError = sourceErrors.values.first {
                state.phase = .failed(message: firstError)
            } else {
                state.phase = .empty
            }
        } else if refreshCompletionPending {
            state.phase = .refreshing
        } else if hasFailures {
            state.phase = .partial
        } else {
            state.phase = .loaded
        }
        state.hasStaleContent =
            state.connectivity == .offline && hasAnyContent
    }

    private func buildContextHeroPages() -> [HomeHeroPage] {
        var pages: [HomeHeroPage] = []
        let pet = selectedPet

        if let pet {
            pages.append(buildPetHeroPage(for: pet))

            if let reminder = nextReminder(for: pet) {
                let reminderPresentation =
                    PPHomeDataBridge.reminderPresentation(for: reminder)
                let reminderID =
                    reminderPresentation["id"] as? String ?? "up-next"
                let reminderTitle =
                    reminderPresentation["title"] as? String ?? ""
                pages.append(
                    HomeHeroPage(
                        id: "reminder-\(reminderID)",
                        kind: .reminder,
                        eyebrow: HomeModelAdapter.localized(
                            "home_pulse_up_next",
                            fallback: "UP NEXT"
                        ),
                        title: reminderTitle,
                        subtitle: reminderSubtitle(reminder),
                        primaryTitle: HomeModelAdapter.localized(
                            "home_pulse_organize_care",
                            fallback: "Organize care"
                        ),
                        secondaryTitle: HomeModelAdapter.localized(
                            "home_pulse_browse_needs",
                            fallback: "Browse needs"
                        ),
                        imageURL: pet.imageURL,
                        localImage: nil,
                        accentHex: "3D7A76",
                        action: .editPet(pet.raw)
                    )
                )
            }
        }

        return pages
    }

    private func buildPromotionHeroPages() -> [HomeHeroPage] {
        promotions.prefix(8).compactMap { card -> HomeHeroPage? in
            let presentation = PPHomeDataBridge.promotionPresentation(for: card)
            var title = presentation["title"] as? String ?? ""
            let subtitle = presentation["subtitle"] as? String ?? ""
            let badge = presentation["badge"] as? String ?? ""
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = subtitle
                } else if !badge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = badge
                } else {
                    title = HomeModelAdapter.localized("home_banner_default_title", fallback: "Special Offer")
                }
            }
            let primaryTitle = presentation["primaryTitle"] as? String ?? ""
            let secondaryTitle = presentation["secondaryTitle"] as? String ?? ""
            let showsPrimary =
                (presentation["showsPrimary"] as? NSNumber)?.boolValue ?? false
            let showsSecondary =
                (presentation["showsSecondary"] as? NSNumber)?.boolValue ?? false
            let imageURL = presentation["imageURL"] as? String ?? ""
            let accentHex = presentation["accentHex"] as? String ?? ""
            let rawID = presentation["id"] as? String ?? ""
            let stableID = rawID.isEmpty
                ? "content:\(title)|\(imageURL)|\(primaryTitle)"
                : rawID
            let interval =
                (presentation["autoScrollInterval"] as? NSNumber)?.doubleValue
                ?? 4.8
            return HomeHeroPage(
                id: "promotion-\(stableID)",
                kind: .promotion,
                eyebrow: badge,
                title: title,
                subtitle: subtitle,
                primaryTitle: showsPrimary
                    ? primaryTitle
                    : HomeModelAdapter.localized("Details", fallback: "Explore"),
                secondaryTitle: showsSecondary ? secondaryTitle : nil,
                imageURL: imageURL.isEmpty ? nil : imageURL,
                localImage: nil,
                accentHex: normalizedHex(accentHex, fallback: "75666B"),
                action: .openPromotion(card, interaction: "card"),
                autoScrollInterval: max(2.0, interval)
            )
        }
    }

    private func buildMarketplaceHeroPage() -> HomeHeroPage {
        let categoryName = selectedCategory?.title
        let marketplaceEyebrow: String
        let marketplaceTitle: String
        let marketplaceSubtitle: String
        let marketplacePrimaryTitle: String

        if let categoryName, !categoryName.isEmpty {
            marketplaceEyebrow = String(
                format: HomeModelAdapter.localized(
                    "home_marketplace_hero_category_eyebrow_format",
                    fallback: "Marketplace | %@ picks"
                ),
                categoryName
            )
            marketplaceTitle = String(
                format: HomeModelAdapter.localized(
                    "home_marketplace_hero_category_title_format",
                    fallback: "Curated for %@"
                ),
                categoryName
            )
            marketplaceSubtitle = String(
                format: HomeModelAdapter.localized(
                    "home_marketplace_hero_category_subtitle_format",
                    fallback: "Products, services, and listings for %@ from trusted providers."
                ),
                categoryName
            )
            marketplacePrimaryTitle = String(
                format: HomeModelAdapter.localized(
                    "home_marketplace_hero_category_cta_format",
                    fallback: "Explore %@"
                ),
                categoryName
            )
        } else {
            marketplaceEyebrow = HomeModelAdapter.localized(
                "home_marketplace_hero_all_eyebrow",
                fallback: HomeModelAdapter.localized(
                    "home_marketplace_hero_eyebrow_proof",
                    fallback: "Marketplace | Top-rated suppliers"
                )
            )
            marketplaceTitle = HomeModelAdapter.localized(
                "home_marketplace_hero_all_title",
                fallback: HomeModelAdapter.localized(
                    "home_marketplace_hero_title",
                    fallback: "Choose a trusted provider"
                )
            )
            marketplaceSubtitle = HomeModelAdapter.localized(
                "home_marketplace_hero_all_subtitle",
                fallback: HomeModelAdapter.localized(
                    "home_marketplace_hero_subtitle",
                    fallback: "Pick a storefront first, then browse products from the provider you trust."
                )
            )
            marketplacePrimaryTitle = HomeModelAdapter.localized(
                "home_marketplace_hero_all_cta",
                fallback: HomeModelAdapter.localized(
                    "home_marketplace_hero_cta",
                    fallback: "View providers"
                )
            )
        }

        return HomeHeroPage(
            id: HomeHeroPresentationMode.marketplaceHeroID,
            kind: .marketplace,
            eyebrow: marketplaceEyebrow,
            title: marketplaceTitle,
            subtitle: marketplaceSubtitle,
            primaryTitle: marketplacePrimaryTitle,
            secondaryTitle: HomeModelAdapter.localized(
                "home_pulse_find_services",
                fallback: "Find services"
            ),
            imageURL: selectedCategory?.imageURL,
            localImage: selectedCategory?.localImage,
            accentHex: normalizedHex(selectedCategoryHex, fallback: "CB2654"),
            action: .openMarketplace(selectedMainKind)
        )
    }

    private func buildPetHeroPage(for pet: HomePetModel) -> HomeHeroPage {
        let title = String(
            format: HomeModelAdapter.localized(
                "home_pulse_pet_hero_title",
                fallback: "Today with %@"
            ),
            pet.name
        )
        let context = [pet.breedOrCategory, pet.age]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        return HomeHeroPage(
            id: "pet-\(pet.id)",
            kind: .pet,
            eyebrow: HomeModelAdapter.localized(
                "home_pulse_eyebrow",
                fallback: "PET PULSE"
            ),
            title: title,
            subtitle: context.isEmpty
                ? HomeModelAdapter.localized(
                    "home_pulse_pet_hero_subtitle",
                    fallback: "Care, shop, and discover from one place."
                )
                : context,
            primaryTitle: HomeModelAdapter.localized(
                "home_pulse_view_pet",
                fallback: "View pet"
            ),
            secondaryTitle: HomeModelAdapter.localized(
                "home_pulse_shop_for_pet",
                fallback: "Shop for this pet"
            ),
            imageURL: pet.imageURL,
            localImage: selectedCategory?.localImage,
            accentHex: selectedCategoryHex,
            action: .editPet(pet.raw)
        )
    }

    private func buildPriorityActions() -> [HomePriorityAction] {
        let petTitle = HomeModelAdapter.localized(
            "home_pulse_priority_my_pet",
            fallback: "My pet"
        )
        let petSubtitle = HomeModelAdapter.localized(
            "home_pulse_priority_personalize",
            fallback: "Pet profile, info, vaccines and more"
        )
        return [
            HomePriorityAction(
                id: "pet",
                title: petTitle,
                subtitle: petSubtitle,
                systemImage: "pawprint.fill",
                accent: UIColor(red: 0.88, green: 0.20, blue: 0.42, alpha: 1.0),
                destination: .petProfile
            ),
            HomePriorityAction(
                id: "shop",
                title: HomeModelAdapter.localized(
                    "home_pulse_priority_shop",
                    fallback: "Shop"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_priority_shop_subtitle",
                    fallback: "Food & essentials"
                ),
                systemImage: "bag.fill",
                accent: UIColor(red: 0.86, green: 0.23, blue: 0.37, alpha: 1.0),
                destination: .shop
            ),
            HomePriorityAction(
                id: "ads",
                title: HomeModelAdapter.localized(
                    "home_pulse_priority_market",
                    fallback: "Pets"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_priority_market_subtitle",
                    fallback: "Listings & adoption"
                ),
                systemImage: "heart.fill",
                accent: UIColor(red: 0.74, green: 0.31, blue: 0.52, alpha: 1.0),
                destination: .advertisements
            ),
            HomePriorityAction(
                id: "pharmacy",
                title: HomeModelAdapter.localized(
                    "home_pulse_priority_pharmacy",
                    fallback: "Pharmacy"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_priority_pharmacy_subtitle",
                    fallback: "Pet medicines"
                ),
                systemImage: "pills.fill",
                accent: UIColor(red: 0.22, green: 0.58, blue: 0.62, alpha: 1.0),
                destination: .pharmacy
            ),
            HomePriorityAction(
                id: "vet",
                title: HomeModelAdapter.localized(
                    "home_pulse_priority_vet",
                    fallback: "Veterinary"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_priority_vet_subtitle",
                    fallback: "Care destination"
                ),
                systemImage: "cross.case.fill",
                accent: UIColor(red: 0.31, green: 0.53, blue: 0.70, alpha: 1.0),
                destination: .veterinary
            ),
        ]
    }

    private func buildSections() -> [HomeSectionModel] {
        let selectedCategoryID = state.selectedMainKindID
        let audience = marketplaceAudience(for: selectedCategoryID)
        let categoryAccessoryItems = selectedCategoryID.flatMap {
            categoryAccessories[$0]
        } ?? []
        let accessoryCandidates = categoryAccessoryItems.isEmpty
            ? accessories
            : categoryAccessoryItems

        let relevantAccessories = accessoryCandidates.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "petMainCategoryID") == selectedCategoryID
        }
        let relevantFood = food.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "petMainCategoryID") == selectedCategoryID
        }
        let relevantAds = advertisements.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "category") == selectedCategoryID
        }
        let relevantNearbyAds = nearbyAdvertisements.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "category") == selectedCategoryID
        }
        let relevantServices = services.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "petMainKindID") == selectedCategoryID
        }
        let prioritizedAccessories = relevantAccessories.isEmpty
            ? accessories
            : relevantAccessories
        let prioritizedFood = relevantFood.isEmpty ? food : relevantFood
        let prioritizedAds = relevantAds.isEmpty
            ? advertisements
            : relevantAds
        let prioritizedNearbyAds = relevantNearbyAds.isEmpty
            ? nearbyAdvertisements
            : relevantNearbyAds
        let prioritizedServices = relevantServices.isEmpty
            ? services
            : relevantServices

        let usesContextualRecommendations =
            !relevantAccessories.isEmpty ||
            !relevantAds.isEmpty ||
            !relevantServices.isEmpty
        let recommendationAccessories = usesContextualRecommendations
            ? relevantAccessories
            : accessories
        let recommendationAds = usesContextualRecommendations
            ? relevantAds
            : advertisements
        let recommendationServices = usesContextualRecommendations
            ? relevantServices
            : services

        let suggestionAccessoryCards = HomeModelAdapter.cards(
            from: Array(prioritizedAccessories.prefix(8)),
            context: .forMarket,
            kind: .accessory,
            limit: 8
        )
        let suggestionAdCards = HomeModelAdapter.cards(
            from: Array(prioritizedAds.prefix(8)),
            context: .forAds,
            kind: .advertisement,
            limit: 8
        )
        let recommendationAccessoryCards = HomeModelAdapter.cards(
            from: Array(recommendationAccessories.prefix(8)),
            context: .forMarket,
            kind: .accessory,
            limit: 8
        )
        let recommendationAdCards = HomeModelAdapter.cards(
            from: Array(recommendationAds.prefix(8)),
            context: .forAds,
            kind: .advertisement,
            limit: 8
        )
        let recommendationServiceCards = HomeModelAdapter.cards(
            from: Array(recommendationServices.prefix(4)),
            context: .forServices,
            kind: .service,
            limit: 4
        )
        let recommendationCards = uniqueCards(
            Array(recommendationAccessoryCards.prefix(4)) +
            Array(recommendationAdCards.prefix(3)) +
            Array(recommendationServiceCards.prefix(2))
        )
        let recommendationIDs = state.config.isVisible(
            HomeLegacySectionID.suggestions.rawValue
        )
            ? Set(recommendationCards.map(\.id))
            : []

        let allAccessoryCards = HomeModelAdapter.cards(
            from: prioritizedAccessories,
            context: .forMarket,
            kind: .accessory
        )
        let accessoryCards = usefulCards(
            from: allAccessoryCards,
            excluding: recommendationIDs
        )
        let foodCards = HomeModelAdapter.cards(
            from: prioritizedFood,
            context: .forFood,
            kind: .food
        )
        let nearbyCards = HomeModelAdapter.cards(
            from: prioritizedNearbyAds,
            context: .forAds,
            kind: .advertisement
        )
        let allServiceCards = HomeModelAdapter.cards(
            from: prioritizedServices,
            context: .forServices,
            kind: .service
        )
        let serviceCards = usefulCards(
            from: allServiceCards,
            excluding: recommendationIDs
        )
        let buyAgainCards = HomeModelAdapter.cards(
            from: buyAgainAccessories,
            context: .forMarket,
            kind: .buyAgain,
            limit: 8
        )

        let recommendationCopy = marketplaceSectionCopy(
            for: .recommendations,
            audience: audience,
            usesContext: usesContextualRecommendations
        )
        let advertisementCopy = marketplaceSectionCopy(
            for: .advertisements,
            audience: audience,
            usesContext: !relevantAds.isEmpty
        )
        let accessorySuggestionCopy = marketplaceSectionCopy(
            for: .accessorySuggestions,
            audience: audience,
            usesContext: !relevantAccessories.isEmpty
        )
        let accessoryCopy = marketplaceSectionCopy(
            for: .accessories,
            audience: audience,
            usesContext: !relevantAccessories.isEmpty
        )
        let foodCopy = marketplaceSectionCopy(
            for: .food,
            audience: audience,
            usesContext: !relevantFood.isEmpty
        )
        let nearbyCopy = marketplaceSectionCopy(
            for: .nearbyAdvertisements,
            audience: audience,
            usesContext: !relevantNearbyAds.isEmpty
        )
        let serviceCopy = marketplaceSectionCopy(
            for: .services,
            audience: audience,
            usesContext: !relevantServices.isEmpty
        )

        var result: [HomeSectionModel] = []
        var emitted = Set<Int>()
        for rawID in state.config.orderedSectionIDs
        where state.config.isVisible(rawID) {
            let section: HomeSectionModel?
            switch rawID {
            case HomeLegacySectionID.buyAgain.rawValue:
                guard !buyAgainCards.isEmpty else { continue }
                section = makeSection(
                    kind: .buyAgain,
                    rawID: rawID,
                    copy: localizedSectionCopy(
                        titleKey: "home_pulse_section_buy_again",
                        titleFallback: "Buy again",
                        subtitleKey: "home_pulse_section_buy_again_subtitle",
                        subtitleFallback: "Products resolved from your real order history"
                    ),
                    cards: buyAgainCards,
                    source: PPHomeBridgeSource.orders.rawValue
                )
            case HomeLegacySectionID.suggestions.rawValue:
                section = makeSection(
                    kind: .recommendations,
                    rawID: rawID,
                    copy: recommendationCopy,
                    cards: recommendationCards,
                    source: PPHomeBridgeSource.accessories.rawValue
                )
            case HomeLegacySectionID.suggestionAds.rawValue:
                section = makeSection(
                    kind: .recommendations,
                    rawID: rawID,
                    copy: advertisementCopy,
                    cards: suggestionAdCards,
                    source: PPHomeBridgeSource.advertisements.rawValue
                )
            case HomeLegacySectionID.suggestionAccessories.rawValue:
                section = makeSection(
                    kind: .recommendations,
                    rawID: rawID,
                    copy: accessorySuggestionCopy,
                    cards: suggestionAccessoryCards,
                    source: PPHomeBridgeSource.accessories.rawValue
                )
            case HomeLegacySectionID.accessories.rawValue:
                section = makeSection(
                    kind: .accessories,
                    rawID: rawID,
                    copy: accessoryCopy,
                    cards: accessoryCards,
                    source: PPHomeBridgeSource.accessories.rawValue
                )
            case HomeLegacySectionID.lastFood.rawValue:
                section = makeSection(
                    kind: .food,
                    rawID: rawID,
                    copy: foodCopy,
                    cards: foodCards,
                    source: PPHomeBridgeSource.food.rawValue
                )
            case HomeLegacySectionID.adsNearby.rawValue:
                section = nearbySection(
                    rawID: rawID,
                    cards: nearbyCards,
                    copy: nearbyCopy
                )
            case HomeLegacySectionID.nearbyServices.rawValue:
                section = makeSection(
                    kind: .services,
                    rawID: rawID,
                    copy: serviceCopy,
                    cards: serviceCards,
                    source: PPHomeBridgeSource.services.rawValue
                )
            default:
                section = nil
            }

            if let section, emitted.insert(section.id).inserted {
                result.append(section)
            }
        }
        return result
    }

    private func makeSection(
        kind: HomeSectionID,
        rawID: Int,
        copy: HomeSectionCopy,
        cards: [HomeCardModel],
        source: Int
    ) -> HomeSectionModel? {
        let renderState: HomeSectionRenderState
        if let message = sourceErrors[source] {
            renderState = .failed(
                title: HomeModelAdapter.localized(
                    "home_pulse_section_error_title",
                    fallback: "This section could not load"
                ),
                message: message,
                retryTitle: HomeModelAdapter.localized(
                    "Retry",
                    fallback: "Retry"
                )
            )
        } else if !loadedSources.contains(source) {
            renderState = .loading
        } else if cards.isEmpty {
            return nil
        } else {
            renderState = .content(cards)
        }

        return HomeSectionModel(
            id: rawID,
            kind: kind,
            title: copy.title,
            subtitle: copy.subtitle,
            seeAllTitle: HomeModelAdapter.localized(
                "ShowAll",
                fallback: "See all"
            ),
            rawConfigSectionID: rawID,
            state: renderState
        )
    }

    private func nearbySection(
        rawID: Int,
        cards: [HomeCardModel],
        copy: HomeSectionCopy
    ) -> HomeSectionModel? {
        if !state.location.hasCoordinate {
            return HomeSectionModel(
                id: rawID,
                kind: .nearbyAdvertisements,
                title: copy.title,
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_nearby_location_needed",
                    fallback: "Choose a location to see genuine nearby results."
                ),
                seeAllTitle: nil,
                rawConfigSectionID: rawID,
                state: .empty(
                    title: HomeModelAdapter.localized(
                        "home_pulse_location_empty_title",
                        fallback: "Nearby discovery needs an area"
                    ),
                    message: HomeModelAdapter.localized(
                        "home_pulse_location_empty_message",
                        fallback: "Use your location or choose an area manually."
                    ),
                    actionTitle: HomeModelAdapter.localized(
                        "home_pulse_choose_area",
                        fallback: "Choose area"
                    )
                )
            )
        }

        let subtitle = showingRecentNearbyFallback
            ? HomeModelAdapter.localized(
                "home_pulse_nearby_recent_fallback",
                fallback: "Few nearby results — showing recent listings"
            )
            : state.location.areaName
        let resolvedSubtitle = subtitle.isEmpty
            ? HomeModelAdapter.localized(
                "home_pulse_section_nearby_subtitle",
                fallback: "Choose an area for nearby discovery"
            )
            : subtitle
        guard let baseSection = makeSection(
            kind: .nearbyAdvertisements,
            rawID: rawID,
            copy: copy,
            cards: cards,
            source: PPHomeBridgeSource.nearbyAdvertisements.rawValue
        ) else {
            return nil
        }
        return HomeSectionModel(
            id: baseSection.id,
            kind: baseSection.kind,
            title: baseSection.title,
            subtitle: resolvedSubtitle,
            seeAllTitle: baseSection.seeAllTitle,
            rawConfigSectionID: baseSection.rawConfigSectionID,
            state: baseSection.state
        )
    }

    private func marketplaceAudience(
        for selectedCategoryID: Int?
    ) -> HomeMarketplaceAudience {
        guard let selectedCategoryID else { return .general }
        if let petCategoryID = selectedPet?.categoryID,
           petCategoryID == selectedCategoryID {
            return .pet
        }
        guard let categoryTitle = state.categories.first(where: {
            HomeModelAdapter.mainKindID($0.raw) == selectedCategoryID
        })?.title.trimmingCharacters(in: .whitespacesAndNewlines),
        !categoryTitle.isEmpty else {
            return .general
        }
        return .category(categoryTitle)
    }

    private func marketplaceSectionCopy(
        for kind: HomeMarketplaceFeedKind,
        audience: HomeMarketplaceAudience,
        usesContext: Bool
    ) -> HomeSectionCopy {
        if usesContext {
            switch audience {
            case .pet:
                return petSectionCopy(for: kind)
            case let .category(categoryTitle):
                return categorySectionCopy(for: kind, title: categoryTitle)
            case .general:
                break
            }
        }
        return generalSectionCopy(for: kind)
    }

    private func petSectionCopy(
        for kind: HomeMarketplaceFeedKind
    ) -> HomeSectionCopy {
        switch kind {
        case .recommendations:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_relevant",
                titleFallback: "Relevant for your pet",
                subtitleKey: "home_pulse_section_relevant_subtitle",
                subtitleFallback: "Matched to the selected pet category"
            )
        case .advertisements:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_relevant_ads",
                titleFallback: "Pet listings for you",
                subtitleKey: "home_pulse_section_relevant_ads_subtitle",
                subtitleFallback: "Listings matched to the selected pet category"
            )
        case .accessorySuggestions:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_relevant_accessories",
                titleFallback: "Essentials for your pet",
                subtitleKey: "home_pulse_section_relevant_accessories_subtitle",
                subtitleFallback: "Products matched to the selected pet category"
            )
        case .accessories:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_pet_featured",
                titleFallback: "Featured for your pet",
                subtitleKey: "home_pulse_section_relevant_accessories_subtitle",
                subtitleFallback: "Products matched to the selected pet category"
            )
        case .food:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_pet_food",
                titleFallback: "Food for your pet",
                subtitleKey: "home_pulse_section_relevant_subtitle",
                subtitleFallback: "Matched to the selected pet category"
            )
        case .nearbyAdvertisements:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_pet_listings",
                titleFallback: "Listings for your pet",
                subtitleKey: "home_pulse_section_relevant_subtitle",
                subtitleFallback: "Matched to the selected pet category"
            )
        case .services:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_pet_services",
                titleFallback: "Care for your pet",
                subtitleKey: "home_pulse_section_relevant_subtitle",
                subtitleFallback: "Matched to the selected pet category"
            )
        }
    }

    private func categorySectionCopy(
        for kind: HomeMarketplaceFeedKind,
        title categoryTitle: String
    ) -> HomeSectionCopy {
        let titleKey: String
        let titleFallback: String
        switch kind {
        case .recommendations:
            titleKey = "home_pulse_section_category_picks_format"
            titleFallback = "Picks for %@"
        case .advertisements, .nearbyAdvertisements:
            titleKey = "home_pulse_section_category_listings_format"
            titleFallback = "Listings for %@"
        case .accessorySuggestions:
            titleKey = "home_pulse_section_category_accessories_format"
            titleFallback = "Essentials for %@"
        case .accessories:
            titleKey = "home_pulse_section_category_featured_format"
            titleFallback = "Featured for %@"
        case .food:
            titleKey = "home_pulse_section_category_food_format"
            titleFallback = "Food for %@"
        case .services:
            titleKey = "home_pulse_section_category_services_format"
            titleFallback = "Services for %@"
        }

        return formattedSectionCopy(
            titleKey: titleKey,
            titleFallback: titleFallback,
            value: categoryTitle,
            subtitleKey: "home_pulse_section_selected_category_subtitle",
            subtitleFallback: "Matched to the category you selected"
        )
    }

    private func generalSectionCopy(
        for kind: HomeMarketplaceFeedKind
    ) -> HomeSectionCopy {
        switch kind {
        case .recommendations:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_picked",
                titleFallback: "Picked for you",
                subtitleKey: "home_pulse_section_picked_subtitle",
                subtitleFallback: "A fresh mix from across Pure Pets"
            )
        case .advertisements:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_listings",
                titleFallback: "New pet listings",
                subtitleKey: "home_pulse_section_listings_subtitle",
                subtitleFallback: "Recent approved pet listings"
            )
        case .accessorySuggestions:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_accessories_latest",
                titleFallback: "New and featured accessories",
                subtitleKey: "home_pulse_section_accessories_subtitle",
                subtitleFallback: "Offers first, followed by the newest arrivals"
            )
        case .accessories:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_accessories",
                titleFallback: "Featured accessories",
                subtitleKey: "home_pulse_section_accessories_subtitle",
                subtitleFallback: "Offers first, followed by the newest arrivals"
            )
        case .food:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_food",
                titleFallback: "New food arrivals",
                subtitleKey: "home_pulse_section_food_subtitle",
                subtitleFallback: "Recently added food and nutrition"
            )
        case .nearbyAdvertisements:
            if showingRecentNearbyFallback {
                return localizedSectionCopy(
                    titleKey: "home_pulse_section_listings",
                    titleFallback: "New pet listings",
                    subtitleKey: "home_pulse_nearby_recent_fallback",
                    subtitleFallback: "Few nearby results - showing recent listings"
                )
            }
            return localizedSectionCopy(
                titleKey: "home_pulse_section_nearby",
                titleFallback: "Near your area",
                subtitleKey: "home_pulse_section_nearby_subtitle",
                subtitleFallback: "Choose an area for nearby discovery"
            )
        case .services:
            return localizedSectionCopy(
                titleKey: "home_pulse_section_services",
                titleFallback: "Latest care services",
                subtitleKey: "home_pulse_section_services_subtitle",
                subtitleFallback: "Recently added grooming, training, and provider offers"
            )
        }
    }

    private func localizedSectionCopy(
        titleKey: String,
        titleFallback: String,
        subtitleKey: String,
        subtitleFallback: String
    ) -> HomeSectionCopy {
        HomeSectionCopy(
            title: HomeModelAdapter.localized(
                titleKey,
                fallback: titleFallback
            ),
            subtitle: HomeModelAdapter.localized(
                subtitleKey,
                fallback: subtitleFallback
            )
        )
    }

    private func formattedSectionCopy(
        titleKey: String,
        titleFallback: String,
        value: String,
        subtitleKey: String,
        subtitleFallback: String
    ) -> HomeSectionCopy {
        let format = HomeModelAdapter.localized(
            titleKey,
            fallback: titleFallback
        )
        return HomeSectionCopy(
            title: String(format: format, value),
            subtitle: HomeModelAdapter.localized(
                subtitleKey,
                fallback: subtitleFallback
            )
        )
    }

    private func sourceIDs(for section: HomeSectionID) -> [Int] {
        switch section {
        case .currentOrder, .buyAgain:
            return [PPHomeBridgeSource.orders.rawValue]
        case .recommendations:
            return [
                PPHomeBridgeSource.accessories.rawValue,
                PPHomeBridgeSource.advertisements.rawValue,
                PPHomeBridgeSource.services.rawValue,
            ]
        case .accessories:
            return [PPHomeBridgeSource.accessories.rawValue]
        case .advertisements:
            return [PPHomeBridgeSource.advertisements.rawValue]
        case .food:
            return [PPHomeBridgeSource.food.rawValue]
        case .nearbyAdvertisements:
            return [PPHomeBridgeSource.nearbyAdvertisements.rawValue]
        case .services:
            return [PPHomeBridgeSource.services.rawValue]
        }
    }

    private func locationPresentation(
        _ state: PPHomeBridgeLocationState
    ) -> HomeLocationPresentation {
        switch state {
        case .notDetermined: return .notDetermined
        case .loading: return .loading
        case .ready: return .ready
        case .denied: return .denied
        case .restricted: return .restricted
        case .failed: return .failed
        @unknown default: return .failed
        }
    }

    private var selectedCategory: HomeCategoryModel? {
        guard let selectedID = state.selectedMainKindID else { return nil }
        return state.categories.first {
            HomeModelAdapter.mainKindID($0.raw) == selectedID
        }
    }

    private var selectedCategoryHex: String {
        guard let category = selectedCategory else { return "CB2654" }
        let presentation =
            PPHomeDataBridge.categoryPresentation(for: category.raw)
        let raw = presentation["colorHex"] as? String ?? ""
        let selectedKindHex =
            hexString(from: presentation["accent"] as? UIColor)
            ?? hexString(from: category.accent)
            ?? "CB2654"
        return normalizedHex(raw, fallback: selectedKindHex)
    }

    private func nextReminder(for pet: HomePetModel) -> NSObject? {
        petReminders.first { reminder in
            let presentation =
                PPHomeDataBridge.reminderPresentation(for: reminder)
            let petID = presentation["petID"] as? String ?? ""
            let enabled =
                (presentation["enabled"] as? NSNumber)?.boolValue ?? false
            return petID == pet.id && enabled
        }
    }

    private func reminderSubtitle(_ reminder: NSObject) -> String {
        let presentation =
            PPHomeDataBridge.reminderPresentation(for: reminder)
        guard let date = presentation["fireDate"] as? Date else {
            return presentation["typeText"] as? String ?? ""
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: state.languageCode)
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func pauseHeroForNavigation() {
        heroPauseGeneration += 1
        let generation = heroPauseGeneration
        heroInteractionActive = true
        restartHeroRotation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self,
                  generation == self.heroPauseGeneration,
                  self.visible
            else {
                return
            }
            self.heroInteractionActive = false
            self.restartHeroRotation()
        }
    }

    private func restartHeroRotation() {
        heroRotationTask?.cancel()
        heroRotationTask = nil
        guard visible,
              sceneActive,
              !heroInteractionActive,
              !voiceOverRunning,
              !reduceMotion,
              state.heroPages.count > 1
        else {
            return
        }

        heroRotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task<Never, Never>.sleep(
                    nanoseconds: 7_000_000_000
                )
                guard !Task.isCancelled, let self else { return }
                self.advanceHero()
            }
        }
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let cartNames = [
            "CartUpdated",
            "kCartUpdatedNotification",
            "PPCartDidChangeNotification",
            "CartManagerCartDidUpdateNotification",
        ]
        for name in cartNames {
            observers.append(
                center.addObserver(
                    forName: Notification.Name(name),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.state.cartCount =
                            PPHomeDataBridge.currentCartItemCount()
                    }
                }
            )
        }

        for name in ["LanguageDidChangeNotification", "PPLanguageDidChangeNotification"] {
            observers.append(
                center.addObserver(
                    forName: Notification.Name(name),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.state.languageCode =
                            Language.currentLanguageCode() ?? "ar"
                        self.state.isRightToLeft = Language.isRTL()
                        self.rebuildState()
                    }
                }
            )
        }

        observers.append(
            center.addObserver(
                forName: UIAccessibility.voiceOverStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.setVoiceOverRunning(UIAccessibility.isVoiceOverRunning)
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
                }
            }
        )
    }

    private func uniqueCards(_ cards: [HomeCardModel]) -> [HomeCardModel] {
        var seen = Set<String>()
        return cards.filter { seen.insert($0.id).inserted }
    }

    private func usefulCards(
        from cards: [HomeCardModel],
        excluding identifiers: Set<String>
    ) -> [HomeCardModel] {
        guard !identifiers.isEmpty else { return cards }
        let filtered = cards.filter { !identifiers.contains($0.id) }
        let minimumUsefulCount = min(3, cards.count)
        return filtered.count >= minimumUsefulCount ? filtered : cards
    }

    private func integerValue(_ object: NSObject, key: String) -> Int {
        guard object.responds(to: NSSelectorFromString(key)),
              let value = object.value(forKey: key) as? NSNumber
        else {
            return 0
        }
        return value.intValue
    }

    private func stringValue(_ object: NSObject, key: String) -> String {
        guard object.responds(to: NSSelectorFromString(key)),
              let value = object.value(forKey: key) as? String
        else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedHex(_ value: String, fallback: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard [6, 8].contains(trimmed.count),
              trimmed.unicodeScalars.allSatisfy(allowed.contains)
        else {
            return fallback
        }
        return String(trimmed.prefix(6))
    }

    private func hexString(from color: UIColor?) -> String? {
        guard let color else { return nil }
        let resolvedColor = color.resolvedColor(with: UITraitCollection.current)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard resolvedColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return nil
        }

        return String(
            format: "%02X%02X%02X",
            colorByte(red),
            colorByte(green),
            colorByte(blue)
        )
    }

    private func colorByte(_ component: CGFloat) -> Int {
        min(255, max(0, Int(round(component * 255))))
    }
}
