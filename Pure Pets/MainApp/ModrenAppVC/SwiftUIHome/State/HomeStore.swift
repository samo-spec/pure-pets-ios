import Foundation
import SwiftUI
import UIKit

/// Stable raw values from the legacy `PPHomeSection` contract. Swift imports
/// that Objective-C enum differently across toolchains, while HomeConfig
/// persists these exact numeric identifiers.
private enum HomeLegacySectionID: Int {
    case carousel = 4
    case suggestions = 6
    case accessories = 7
    case lastFood = 10
    case nearbyServices = 11
    case adsNearby = 12
    case adopt = 13
    case buyAgain = 14
    case suggestionAds = 18
    case suggestionAccessories = 19
}

@MainActor
final class HomeStore: ObservableObject {
    @Published private(set) var state: HomeViewState
    @Published private(set) var scrollToTopGeneration = 0

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

    private static let selectedMainKindKey = "PPHome.lastSelectedMainKindID.v1"
    private static let selectedPetKey = "pp.home.selectedPetID.v2"

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
        guard state.phase != .refreshing else { return }
        state.phase = .refreshing
        repository.refresh()
        try? await Task<Never, Never>.sleep(nanoseconds: 450_000_000)
        if case .refreshing = state.phase {
            updateScreenPhase()
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: HomeModelAdapter.localized(
                "home_pulse_refresh_complete_a11y",
                fallback: "Home refreshed"
            )
        )
    }

    func retryAll() {
        sourceErrors.removeAll()
        state.phase = hasAnyContent ? .refreshing : .coldLoading
        repository.refresh()
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
        pauseHeroForNavigation()
        router.openHeroAction(state.heroPages[state.selectedHeroIndex].action)
    }

    func performSelectedHeroSecondaryAction() {
        guard state.heroPages.indices.contains(state.selectedHeroIndex) else {
            return
        }
        let page = state.heroPages[state.selectedHeroIndex]
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
        case .marketplace:
            router.openServices(mainKind: selectedMainKind)
        case .petOnboarding:
            router.openAdvertisements(mainKind: selectedMainKind)
        }
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

    func openFeaturedOrder() {
        guard let order = state.featuredOrder else { return }
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
        switch event {
        case let .mainKinds(models):
            mainKinds = models
            markLoaded(PPHomeBridgeSource.mainKinds.rawValue)
        case let .promotions(models):
            promotions = models
            markLoaded(PPHomeBridgeSource.promotions.rawValue)
        case let .accessories(models):
            accessories = models
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
            fromCache
        ):
            state.config = HomeModelAdapter.config(
                sections: sections,
                titleViewMode: titleViewMode,
                premiumCareVisible: premiumCareVisible,
                novaFloatingVisible: novaFloatingVisible,
                backgroundGlowsFaded: backgroundGlowsFaded,
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
    }

    private func markLoaded(_ source: Int) {
        loadedSources.insert(source)
        sourceErrors.removeValue(forKey: source)
    }

    private func resolveBuyAgain() {
        orderResolutionGeneration += 1
        let generation = orderResolutionGeneration
        let itemIDs = HomeModelAdapter.orderItemIDs(from: recentOrders, limit: 8)
        guard !itemIDs.isEmpty else {
            buyAgainAccessories = []
            rebuildState()
            return
        }
        repository.resolveAccessories(ids: itemIDs) { [weak self] resolved in
            guard let self, generation == self.orderResolutionGeneration else {
                return
            }
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
        }
    }

    private func rebuildState() {
        let previousHeroIDs = state.heroPages.map(\.id)
        state.categories = HomeModelAdapter.categories(from: mainKinds)
        state.pets = HomeModelAdapter.pets(from: petProfiles)

        let persistedCategory = UserDefaults.standard.object(
            forKey: Self.selectedMainKindKey
        ) as? NSNumber
        state.selectedMainKindID = HomeModelAdapter.selectedCategoryID(
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

        if persistedCategory == nil,
           state.selectedMainKindID == nil,
           let petCategoryID = selectedPet?.categoryID,
           petCategoryID > 0,
           state.categories.contains(where: {
               HomeModelAdapter.mainKindID($0.raw) == petCategoryID
           }) {
            state.selectedMainKindID = petCategoryID
        }

        state.heroPages = buildHeroPages()
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
        } else if hasFailures {
            state.phase = .partial
        } else {
            state.phase = .loaded
        }
        state.hasStaleContent =
            state.connectivity == .offline && hasAnyContent
    }

    private func buildHeroPages() -> [HomeHeroPage] {
        var pages: [HomeHeroPage] = []
        let pet = selectedPet

        if let pet {
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
            pages.append(
                HomeHeroPage(
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
            )

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
        } else {
            pages.append(
                HomeHeroPage(
                    id: "pet-onboarding",
                    kind: .petOnboarding,
                    eyebrow: HomeModelAdapter.localized(
                        "home_pulse_make_it_yours",
                        fallback: "MAKE IT YOURS"
                    ),
                    title: HomeModelAdapter.localized(
                        "home_pulse_no_pet_title",
                        fallback: "Build a Home around your pet"
                    ),
                    subtitle: HomeModelAdapter.localized(
                        "home_pulse_no_pet_subtitle",
                        fallback: "Add a profile for relevant products, care organization, reminders, and faster discovery."
                    ),
                    primaryTitle: HomeModelAdapter.localized(
                        "home_pulse_create_pet",
                        fallback: "Create pet profile"
                    ),
                    secondaryTitle: HomeModelAdapter.localized(
                        "home_pulse_keep_browsing",
                        fallback: "Keep browsing"
                    ),
                    imageURL: nil,
                    localImage: UIImage(named: "petcare_placeholder"),
                    accentHex: "CB2654",
                    action: .openPetProfiles
                )
            )
        }

        if state.config.isVisible(HomeLegacySectionID.carousel.rawValue) {
            for card in promotions.prefix(3) {
                let presentation =
                    PPHomeDataBridge.promotionPresentation(for: card)
                let title = presentation["title"] as? String ?? ""
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    continue
                }
                let badge = presentation["badge"] as? String ?? ""
                let subtitle = presentation["subtitle"] as? String ?? ""
                let primaryTitle =
                    presentation["primaryTitle"] as? String ?? ""
                let secondaryTitle =
                    presentation["secondaryTitle"] as? String ?? ""
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
                pages.append(
                    HomeHeroPage(
                        id: "promotion-\(stableID)",
                        kind: .promotion,
                        eyebrow: badge,
                        title: title,
                        subtitle: subtitle,
                        primaryTitle: showsPrimary
                            ? primaryTitle
                            : HomeModelAdapter.localized(
                                "Details",
                                fallback: "Explore"
                            ),
                        secondaryTitle: showsSecondary
                            ? secondaryTitle
                            : nil,
                        imageURL: imageURL.isEmpty ? nil : imageURL,
                        localImage: nil,
                        accentHex: normalizedHex(
                            accentHex,
                            fallback: "CB2654"
                        ),
                        action: .openPromotion(card, interaction: "card")
                    )
                )
            }
        }

        if pages.count == 1 || pet != nil {
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
            pages.append(
                HomeHeroPage(
                    id: "marketplace-\(state.selectedMainKindID ?? -1)",
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
                    accentHex: selectedCategoryHex,
                    action: .openMarketplace(selectedMainKind)
                )
            )
        }

        return pages
    }

    private func buildPriorityActions() -> [HomePriorityAction] {
        let petTitle = selectedPet == nil
            ? HomeModelAdapter.localized(
                "home_pulse_priority_add_pet",
                fallback: "Add pet"
            )
            : HomeModelAdapter.localized(
                "home_pulse_priority_my_pet",
                fallback: "My pet"
            )
        return [
            HomePriorityAction(
                id: "pet",
                title: petTitle,
                subtitle: selectedPet?.name ?? HomeModelAdapter.localized(
                    "home_pulse_priority_personalize",
                    fallback: "Personalize Home"
                ),
                systemImage: selectedPet == nil
                    ? "plus.circle.fill"
                    : "pawprint.circle.fill",
                accent: .ppPrimary,
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
                accent: UIColor(red: 0.79, green: 0.15, blue: 0.33, alpha: 1),
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
                systemImage: "heart.circle.fill",
                accent: UIColor(red: 0.72, green: 0.30, blue: 0.48, alpha: 1),
                destination: .advertisements
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
                accent: UIColor(red: 0.20, green: 0.48, blue: 0.67, alpha: 1),
                destination: .veterinary
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
                accent: UIColor(red: 0.29, green: 0.52, blue: 0.48, alpha: 1),
                destination: .pharmacy
            ),
            HomePriorityAction(
                id: "services",
                title: HomeModelAdapter.localized(
                    "home_pulse_priority_services",
                    fallback: "Services"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_priority_services_subtitle",
                    fallback: "Grooming & training"
                ),
                systemImage: "sparkles",
                accent: UIColor(red: 0.64, green: 0.40, blue: 0.24, alpha: 1),
                destination: .services
            ),
        ]
    }

    private func buildSections() -> [HomeSectionModel] {
        let selectedCategoryID = state.selectedMainKindID

        let relevantAccessories = accessories.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "petMainCategoryID") == selectedCategoryID
        }
        let relevantAds = advertisements.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "category") == selectedCategoryID
        }
        let relevantServices = services.filter {
            selectedCategoryID != nil &&
            integerValue($0, key: "petMainKindID") == selectedCategoryID
        }
        let recommendationObjects: [Any] =
            Array(relevantAccessories.prefix(4)).map { $0 as Any } +
            Array(relevantAds.prefix(3)).map { $0 as Any } +
            Array(relevantServices.prefix(2)).map { $0 as Any }
        let recommendationCards = recommendationObjects.compactMap {
            object -> HomeCardModel? in
            if object is PetAccessory {
                return HomeModelAdapter.cards(
                    from: [object],
                    context: .forMarket,
                    kind: .accessory,
                    limit: 1
                ).first
            }
            if object is ServiceModel {
                return HomeModelAdapter.cards(
                    from: [object],
                    context: .forServices,
                    kind: .service,
                    limit: 1
                ).first
            }
            return HomeModelAdapter.cards(
                from: [object],
                context: .forAds,
                kind: .advertisement,
                limit: 1
            ).first
        }
        let recommendationIDs = Set(recommendationCards.map(\.id))

        let accessoryCards = HomeModelAdapter.cards(
            from: accessories,
            context: .forMarket,
            kind: .accessory
        ).filter { !recommendationIDs.contains($0.id) }
        let advertisementCards = HomeModelAdapter.cards(
            from: advertisements,
            context: .forAds,
            kind: .advertisement
        ).filter { !recommendationIDs.contains($0.id) }
        let foodCards = HomeModelAdapter.cards(
            from: food,
            context: .forFood,
            kind: .food
        )
        let nearbyCards = HomeModelAdapter.cards(
            from: nearbyAdvertisements,
            context: .forAds,
            kind: .advertisement
        )
        let serviceCards = HomeModelAdapter.cards(
            from: services,
            context: .forServices,
            kind: .service
        ).filter { !recommendationIDs.contains($0.id) }
        let buyAgainCards = HomeModelAdapter.cards(
            from: buyAgainAccessories,
            context: .forMarket,
            kind: .buyAgain,
            limit: 8
        )

        var result: [HomeSectionModel] = []
        var emitted = Set<HomeSectionID>()
        for rawID in state.config.orderedSectionIDs
        where state.config.isVisible(rawID) {
            let section: HomeSectionModel?
            switch rawID {
            case HomeLegacySectionID.buyAgain.rawValue:
                guard !buyAgainCards.isEmpty else { continue }
                section = makeSection(
                    id: .buyAgain,
                    rawID: rawID,
                    titleKey: "home_pulse_section_buy_again",
                    titleFallback: "Buy again",
                    subtitleKey: "home_pulse_section_buy_again_subtitle",
                    subtitleFallback: "Products resolved from your real order history",
                    cards: buyAgainCards,
                    source: PPHomeBridgeSource.orders.rawValue,
                    emptyAction: nil
                )
            case HomeLegacySectionID.suggestions.rawValue,
                 HomeLegacySectionID.suggestionAds.rawValue,
                 HomeLegacySectionID.suggestionAccessories.rawValue:
                guard selectedPet != nil, !recommendationCards.isEmpty else {
                    continue
                }
                section = makeSection(
                    id: .recommendations,
                    rawID: rawID,
                    titleKey: "home_pulse_section_relevant",
                    titleFallback: "Relevant for your pet",
                    subtitleKey: "home_pulse_section_relevant_subtitle",
                    subtitleFallback: "Matched to the selected pet category",
                    cards: recommendationCards,
                    source: PPHomeBridgeSource.accessories.rawValue,
                    emptyAction: nil
                )
            case HomeLegacySectionID.accessories.rawValue:
                section = makeSection(
                    id: .accessories,
                    rawID: rawID,
                    titleKey: "home_pulse_section_accessories",
                    titleFallback: "Featured essentials",
                    subtitleKey: "home_pulse_section_accessories_subtitle",
                    subtitleFallback: "Available products and genuine offers",
                    cards: accessoryCards,
                    source: PPHomeBridgeSource.accessories.rawValue,
                    emptyAction: HomeModelAdapter.localized(
                        "home_pulse_explore_market",
                        fallback: "Explore marketplace"
                    )
                )
            case HomeLegacySectionID.adopt.rawValue:
                section = makeSection(
                    id: .advertisements,
                    rawID: rawID,
                    titleKey: "home_pulse_section_listings",
                    titleFallback: "Pet marketplace",
                    subtitleKey: "home_pulse_section_listings_subtitle",
                    subtitleFallback: "Recent approved pet listings",
                    cards: advertisementCards,
                    source: PPHomeBridgeSource.advertisements.rawValue,
                    emptyAction: HomeModelAdapter.localized(
                        "home_pulse_keep_browsing",
                        fallback: "Browse listings"
                    )
                )
            case HomeLegacySectionID.lastFood.rawValue:
                guard !foodCards.isEmpty ||
                      sourceErrors[PPHomeBridgeSource.food.rawValue] != nil
                else {
                    continue
                }
                section = makeSection(
                    id: .food,
                    rawID: rawID,
                    titleKey: "home_pulse_section_food",
                    titleFallback: "Food and nutrition",
                    subtitleKey: "home_pulse_section_food_subtitle",
                    subtitleFallback: "Available food products for supported pets",
                    cards: foodCards,
                    source: PPHomeBridgeSource.food.rawValue,
                    emptyAction: nil
                )
            case HomeLegacySectionID.adsNearby.rawValue:
                section = nearbySection(
                    rawID: rawID,
                    cards: nearbyCards
                )
            case HomeLegacySectionID.nearbyServices.rawValue:
                section = makeSection(
                    id: .services,
                    rawID: rawID,
                    titleKey: "home_pulse_section_services",
                    titleFallback: "Care and services",
                    subtitleKey: "home_pulse_section_services_subtitle",
                    subtitleFallback: "Grooming, training, and available provider offers",
                    cards: serviceCards,
                    source: PPHomeBridgeSource.services.rawValue,
                    emptyAction: HomeModelAdapter.localized(
                        "home_pulse_find_services",
                        fallback: "Find services"
                    )
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
        id: HomeSectionID,
        rawID: Int,
        titleKey: String,
        titleFallback: String,
        subtitleKey: String,
        subtitleFallback: String,
        cards: [HomeCardModel],
        source: Int,
        emptyAction: String?
    ) -> HomeSectionModel {
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
            renderState = .empty(
                title: HomeModelAdapter.localized(
                    "home_pulse_section_empty_title",
                    fallback: "Nothing to show yet"
                ),
                message: HomeModelAdapter.localized(
                    "home_pulse_section_empty_message",
                    fallback: "New items will appear here when they are available."
                ),
                actionTitle: emptyAction
            )
        } else {
            renderState = .content(cards)
        }

        return HomeSectionModel(
            id: id,
            title: HomeModelAdapter.localized(titleKey, fallback: titleFallback),
            subtitle: HomeModelAdapter.localized(
                subtitleKey,
                fallback: subtitleFallback
            ),
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
        cards: [HomeCardModel]
    ) -> HomeSectionModel {
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
        let baseSection = makeSection(
            id: .nearbyAdvertisements,
            rawID: rawID,
            titleKey: "home_pulse_section_nearby",
            titleFallback: "Near your area",
            subtitleKey: "home_pulse_section_nearby_subtitle",
            subtitleFallback: "Choose an area for nearby discovery",
            cards: cards,
            source: PPHomeBridgeSource.nearbyAdvertisements.rawValue,
            emptyAction: HomeModelAdapter.localized(
                "home_pulse_choose_area",
                fallback: "Choose area"
            )
        )
        var section = HomeSectionModel(
            id: baseSection.id,
            title: baseSection.title,
            subtitle: resolvedSubtitle,
            seeAllTitle: baseSection.seeAllTitle,
            rawConfigSectionID: baseSection.rawConfigSectionID,
            state: baseSection.state
        )
        if !state.location.hasCoordinate {
            section = HomeSectionModel(
                id: section.id,
                title: section.title,
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
        return section
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
        return normalizedHex(raw, fallback: "CB2654")
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
}
