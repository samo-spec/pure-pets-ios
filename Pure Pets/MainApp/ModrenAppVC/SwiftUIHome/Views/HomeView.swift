import SwiftUI
import UIKit

private enum HomeSectionRawID {
    static let hero = 0
    static let quickActions = 1
    static let currentOrders = 2
    static let carousel = 4
    static let mainKinds = 5
    static let suggestions = 6
    static let accessories = 7
    static let petProfile = 8
    static let premiumCare = 9
    static let lastFood = 10
    static let nearbyServices = 11
    static let adsNearby = 12
    static let adopt = 13
    static let buyAgain = 14
    static let premiumSearch = 15
    static let providerCategoryNav = 16
    static let marketplaceHero = 17
    static let suggestionAds = 18
    static let suggestionAccessories = 19

    static let supported: Set<Int> = [
        hero, quickActions, currentOrders, carousel, mainKinds,
        suggestions, accessories, petProfile, premiumCare, lastFood,
        nearbyServices, adsNearby, adopt, buyAgain, premiumSearch,
        providerCategoryNav, marketplaceHero, suggestionAds,
        suggestionAccessories,
    ]
}

@available(iOS 15.0, *)
struct HomeView: View {
    @ObservedObject var store: HomeStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var loadedEntranceVisible = false
    @State private var presentedOrder: HomeOrderModel?

    private let topAnchor = "pp-home-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Color.clear
                        .frame(height: 1)
                        .id(topAnchor)
                        .accessibilityHidden(true)

                    Section {
                        content
                            .padding(.top, PPSpace.sm)
                            .padding(.bottom, bottomPadding)
                    } header: {
                        HomeCommandBar(
                            state: store.state,
                            searchAction: store.router.openSearch,
                            cartAction: store.router.openCart,
                            locationAction: store.locationTapped
                        )
                        .zIndex(10)
                    }
                }
            }
            .background(background)
            .scrollDismissesKeyboardCompat()
            .refreshable {
                await store.refresh()
            }
            .onChange(of: store.scrollToTopGeneration) { _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                    proxy.scrollTo(topAnchor, anchor: .top)
                }
            }
        }
        .environment(
            \.layoutDirection,
            store.state.isRightToLeft ? .rightToLeft : .leftToRight
        )
        .sheet(item: $presentedOrder) { order in
            HomeOrderContextSheet(
                order: order,
                openDetails: {
                    presentedOrder = nil
                    DispatchQueue.main.async {
                        store.openOrder(order)
                    }
                },
                openHistory: {
                    presentedOrder = nil
                    DispatchQueue.main.async {
                        store.seeAll(.currentOrder)
                    }
                }
            )
            .environment(
                \.layoutDirection,
                store.state.isRightToLeft ? .rightToLeft : .leftToRight
            )
        }
        .onChange(of: scenePhase) { phase in
            DispatchQueue.main.async {
                store.setSceneActive(phase == .active)
            }
        }
        .onChange(of: reduceMotion) { value in
            DispatchQueue.main.async {
                store.setReduceMotion(value)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeStatusBanner(
                state: store.state,
                retry: store.retryAll
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.vertical, PPSpace.sm)

            switch store.state.phase {
            case .coldLoading, .warmLoading:
                loadingContent
            case let .failed(message):
                HomeInlineState(
                    symbol: "wifi.exclamationmark",
                    title: HomeModelAdapter.localized(
                        "home_pulse_failed_title",
                        fallback: "Home could not load"
                    ),
                    message: message,
                    actionTitle: HomeModelAdapter.localized(
                        "Retry",
                        fallback: "Retry"
                    ),
                    action: store.retryAll
                )
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, PPSpace.xl)
            case .empty:
                emptyContent
            case .loaded, .refreshing, .partial:
                loadedContent
            }
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            if !store.state.heroPages.isEmpty {
                HomeHeroView(
                    pages: store.state.heroPages,
                    selectedIndex: store.state.selectedHeroIndex,
                    onSelect: store.selectHero,
                    onPrimaryAction: store.performSelectedHeroAction,
                    onSecondaryAction: store.performSelectedHeroSecondaryAction,
                    onInteractionChanged: store.setHeroInteractionActive
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

            HomePriorityGrid(
                actions: placeholderActions,
                featuredPet: nil,
                onSelect: { _ in }
            )
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .padding(.horizontal, PPSpace.screenMargin)

            HomeInlineState(
                symbol: "hourglass",
                title: HomeModelAdapter.localized(
                    "home_pulse_loading_title",
                    fallback: "Preparing your Home"
                ),
                message: HomeModelAdapter.localized(
                    "home_pulse_loading_message",
                    fallback: "Pet context, marketplace, and care destinations are loading."
                ),
                actionTitle: nil,
                action: nil
            )
            .padding(.horizontal, PPSpace.screenMargin)
        }
        .padding(.vertical, PPSpace.lg)
    }

    private var loadedContent: some View {
        let sections = visibleSupportedSections

        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(
                Array(sections.enumerated()),
                id: \.element.id
            ) { index, section in
                configuredSection(section)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, sectionVerticalPadding(section.id))
                    .padding(
                        .top,
                        heroToMainKindsBreathingRoom(
                            in: sections,
                            at: index
                        )
                    )
                    .background(sectionBand(for: section.id))
                    .homeSectionEntrance(
                        isVisible: loadedEntranceVisible,
                        sectionIndex: index,
                        reduceMotion: reduceMotion
                    )
                    .id("home-section-\(section.id)")
            }
        }
        .onAppear(perform: startLoadedEntranceIfNeeded)
    }

    private var visibleSupportedSections: [HomeConfigSection] {
        store.state.config.sections.filter { section in
            guard section.isVisible,
                  HomeSectionRawID.supported.contains(section.id)
            else {
                return false
            }
            if section.id == HomeSectionRawID.hero {
                return !store.state.pets.isEmpty
                    && !store.state.heroPages.isEmpty
            }
            return true
        }
    }

    @ViewBuilder
    private func configuredSection(_ section: HomeConfigSection) -> some View {
        switch section.id {
        case HomeSectionRawID.premiumSearch:
            HomePremiumSearchSection(
                isRightToLeft: store.state.isRightToLeft,
                showsNova: store.state.config.novaFloatingVisible,
                searchAction: store.router.openSearch,
                novaAction: store.router.openNova
            )
            .padding(.horizontal, PPSpace.screenMargin)

        case HomeSectionRawID.marketplaceHero:
            if let page = store.state.marketplaceHeroPage {
                HomeSingleHeroSection(
                    page: page,
                    primaryAction: { store.performHeroAction(page) },
                    secondaryAction: { store.performHeroSecondaryAction(page) }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

        case HomeSectionRawID.providerCategoryNav:
            HomeProviderCategoryNavigation(
                action: store.openProviderCategory
            )
            .padding(.horizontal, PPSpace.screenMargin)

        case HomeSectionRawID.hero:
            if !store.state.heroPages.isEmpty {
                HomeHeroView(
                    pages: store.state.heroPages,
                    selectedIndex: store.state.selectedHeroIndex,
                    onSelect: store.selectHero,
                    onPrimaryAction: store.performSelectedHeroAction,
                    onSecondaryAction: store.performSelectedHeroSecondaryAction,
                    onInteractionChanged: store.setHeroInteractionActive
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

        case HomeSectionRawID.mainKinds:
            if !store.state.categories.isEmpty {
                HomeCategoryRail(
                    categories: store.state.categories,
                    selectedID: store.state.selectedMainKindID,
                    entrancePresented: loadedEntranceVisible,
                    onSelect: store.selectCategory
                )
            }

        case HomeSectionRawID.premiumCare:
            HomePremiumCareSection(
                openVeterinary: {
                    store.openProviderCategory("veterinarians")
                },
                openPharmacy: {
                    store.openProviderCategory("pharmacy")
                }
            )
            .padding(.horizontal, PPSpace.screenMargin)

        case HomeSectionRawID.quickActions:
            HomePriorityGrid(
                actions: store.state.priorityActions,
                featuredPet: selectedPriorityPet,
                onSelect: store.performPriorityAction
            )
            .padding(.horizontal, PPSpace.screenMargin)

        case HomeSectionRawID.currentOrders:
            if let order = store.state.featuredOrder {
                HomeOrderCard(
                    order: order,
                    onTap: { store.openOrder(order) }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

        case HomeSectionRawID.carousel:
            if store.state.promotionPages.isEmpty {
                HomeInlineState(
                    symbol: "photo.on.rectangle.angled",
                    title: HomeModelAdapter.localized(
                        "home_carousel_empty_title",
                        fallback: "Offers are being prepared"
                    ),
                    message: HomeModelAdapter.localized(
                        "home_carousel_empty_message",
                        fallback: "New offers will appear here when available."
                    ),
                    actionTitle: HomeModelAdapter.localized(
                        "Retry",
                        fallback: "Retry"
                    ),
                    action: store.retryAll
                )
                .padding(.horizontal, PPSpace.screenMargin)
            } else {
                HomePromotionCarousel(
                    pages: store.state.promotionPages,
                    primaryAction: store.performHeroAction,
                    secondaryAction: store.performHeroSecondaryAction
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

        case HomeSectionRawID.adopt:
            HomeAdoptionSection(action: store.openAdoption)
                .padding(.horizontal, PPSpace.screenMargin)

        case HomeSectionRawID.petProfile:
            VStack(alignment: .leading, spacing: PPSpace.lg) {
                if !store.state.pets.isEmpty {
                    HomePetSwitcher(
                        pets: store.state.pets,
                        selectedID: store.state.selectedPetID,
                        onSelect: store.selectPet,
                        onEdit: store.editSelectedPet
                    )
                }
                HomeMyPetProfileCard(
                    pets: store.state.pets,
                    selectedID: store.state.selectedPetID,
                    isLoading: store.state.phase.isLoading,
                    errorMessage: nil,
                    action: store.openPetProfiles
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

        case HomeSectionRawID.suggestions,
             HomeSectionRawID.accessories,
             HomeSectionRawID.lastFood,
             HomeSectionRawID.nearbyServices,
             HomeSectionRawID.adsNearby,
             HomeSectionRawID.buyAgain,
             HomeSectionRawID.suggestionAds,
             HomeSectionRawID.suggestionAccessories:
            if let feed = store.state.sections.first(where: { $0.id == section.id }) {
                HomeFeedSection(
                    section: feed,
                    store: store,
                    entrancePresented: loadedEntranceVisible
                )
            }

        default:
            EmptyView()
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            HomeInlineState(
                symbol: "pawprint.fill",
                title: HomeModelAdapter.localized(
                    "home_pulse_empty_title",
                    fallback: "Your Home is ready to grow"
                ),
                message: HomeModelAdapter.localized(
                    "home_pulse_empty_message",
                    fallback: "Explore pet listings, products, and care destinations while new recommendations arrive."
                ),
                actionTitle: HomeModelAdapter.localized(
                    "home_pulse_explore_market",
                    fallback: "Explore marketplace"
                ),
                action: store.exploreMarketplace
            )
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.vertical, PPSpace.xl)
        .homeEntrance(
            isVisible: loadedEntranceVisible,
            delay: 0.05,
            reduceMotion: reduceMotion
        )
        .onAppear(perform: startLoadedEntranceIfNeeded)
    }

    private var background: some View {
        WorldGlassBackground(
            isFaded: store.state.config.backgroundGlowsFaded
        )
    }

    private func sectionBand(for rawID: Int) -> Color {
        switch rawID {
        case HomeSectionRawID.suggestions:
            return .ppQuietLilac
        case HomeSectionRawID.premiumCare:
            return .homeSectionBand
        case HomeSectionRawID.suggestionAds,
             HomeSectionRawID.suggestionAccessories,
             HomeSectionRawID.nearbyServices:
            return .homeAmbientField
        default:
            return .clear
        }
    }

    private func sectionVerticalPadding(_ rawID: Int) -> CGFloat {
        switch rawID {
        case HomeSectionRawID.mainKinds: return PPSpace.sm
        case HomeSectionRawID.carousel,
             HomeSectionRawID.hero,
             HomeSectionRawID.marketplaceHero: return PPSpace.md
        default: return PPSpace.lg
        }
    }

    private func heroToMainKindsBreathingRoom(
        in sections: [HomeConfigSection],
        at index: Int
    ) -> CGFloat {
        guard index > sections.startIndex,
              sections.indices.contains(index),
              sections[index].id == HomeSectionRawID.mainKinds,
              sections[index - 1].id == HomeSectionRawID.hero
        else {
            return 0
        }
        return PPSpace.sm
    }

    private var bottomPadding: CGFloat {
        store.state.bottomContentClearance +
            (dynamicTypeSize.isAccessibilitySize ? 144 : 96)
    }

    private func startLoadedEntranceIfNeeded() {
        guard !loadedEntranceVisible else { return }
        // Commit on the next run loop so the initial visible shelves are
        // already in their staged pose before the one-shot phase changes.
        DispatchQueue.main.async {
            guard !loadedEntranceVisible else { return }
            loadedEntranceVisible = true
        }
    }

    private var selectedPriorityPet: HomePetModel? {
        if let selectedID = store.state.selectedPetID,
           let selectedPet = store.state.pets.first(where: {
               $0.id == selectedID
           }) {
            return selectedPet
        }

        return store.state.pets.first(where: \.isDefault) ??
            store.state.pets.first
    }

    private var placeholderActions: [HomePriorityAction] {
        let ids = ["pet", "shop", "ads", "pharmacy", "vet"]
        return ids.map { id in
            HomePriorityAction(
                id: id,
                title: "••••",
                subtitle: "••••••••",
                systemImage: "pawprint.fill",
                accent: .ppPrimary,
                destination: .petProfile
            )
        }
    }
}

@available(iOS 15.0, *)
private struct HomeSingleHeroSection: View {
    let page: HomeHeroPage
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        HomeHeroView(
            pages: [page],
            selectedIndex: 0,
            onSelect: { _ in },
            onPrimaryAction: primaryAction,
            onSecondaryAction: secondaryAction,
            onInteractionChanged: { _ in }
        )
    }
}

@available(iOS 15.0, *)
private struct HomePromotionCarousel: View {
    let pages: [HomeHeroPage]
    let primaryAction: (HomeHeroPage) -> Void
    let secondaryAction: (HomeHeroPage) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedPageID: String?
    @State private var interactionActive = false
    @State private var voiceOverRunning = UIAccessibility.isVoiceOverRunning

    private var selectedIndex: Int {
        guard let selectedPageID,
              let index = pages.firstIndex(where: { $0.id == selectedPageID })
        else {
            return 0
        }
        return index
    }

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex]
    }

    private var taskIdentity: String {
        [
            pages.map(\.id).joined(separator: "|"),
            selectedPageID ?? "",
            String(scenePhase == .active),
            String(reduceMotion),
            String(voiceOverRunning),
            String(interactionActive),
        ].joined(separator: ":")
    }

    var body: some View {
        HomeHeroView(
            pages: pages,
            selectedIndex: selectedIndex,
            onSelect: select,
            onPrimaryAction: {
                if let selectedPage {
                    primaryAction(selectedPage)
                }
            },
            onSecondaryAction: {
                if let selectedPage {
                    secondaryAction(selectedPage)
                }
            },
            onInteractionChanged: { interactionActive = $0 }
        )
        .onAppear(perform: resolveSelection)
        .onChange(of: pages.map(\.id)) { _ in resolveSelection() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIAccessibility.voiceOverStatusDidChangeNotification
            )
        ) { _ in
            voiceOverRunning = UIAccessibility.isVoiceOverRunning
        }
        .task(id: taskIdentity) {
            guard pages.count > 1,
                  scenePhase == .active,
                  !reduceMotion,
                  !voiceOverRunning,
                  !interactionActive
            else {
                return
            }
            while !Task.isCancelled {
                let interval = max(2.0, selectedPage?.autoScrollInterval ?? 4.8)
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(interval * 1_000_000_000)
                    )
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                select((selectedIndex + 1) % pages.count)
            }
        }
    }

    private func resolveSelection() {
        guard !pages.isEmpty else {
            selectedPageID = nil
            return
        }
        if !pages.contains(where: { $0.id == selectedPageID }) {
            selectedPageID = pages[0].id
        }
    }

    private func select(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        selectedPageID = pages[index].id
    }
}

@available(iOS 15.0, *)
private struct HomePremiumSearchSection: View {
    let isRightToLeft: Bool
    let showsNova: Bool
    let searchAction: () -> Void
    let novaAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            discoveryHeader

            VStack(spacing: 0) {
                searchButton

                if showsNova {
                    Rectangle()
                        .fill(Color.homeSeparator.opacity(contrast == .increased ? 0.92 : 0.70))
                        .frame(height: contrast == .increased ? 1.5 : 0.8)
                        .padding(.horizontal, PPSpace.base)

                    novaButton
                }
            }
            .background(Color.homeRaisedSurface, in: consoleShape)
            .clipShape(consoleShape)
            .overlay {
                consoleShape.stroke(
                    contrast == .increased
                        ? Color.homeTextPrimary.opacity(0.68)
                        : Color.homeBrand.opacity(colorScheme == .dark ? 0.24 : 0.12),
                    lineWidth: contrast == .increased ? 1.5 : 0.9
                )
            }
            .shadow(
                color: contrast == .increased
                    ? .clear
                    : Color.black.opacity(colorScheme == .dark ? 0.20 : 0.065),
                radius: colorScheme == .dark ? 12 : 18,
                y: colorScheme == .dark ? 5 : 9
            )
        }
        .padding(PPSpace.base)
        .background(sectionAtmosphere, in: outerShape)
        .overlay {
            outerShape.stroke(
                Color.homeBrand.opacity(contrast == .increased ? 0.42 : 0.10),
                lineWidth: contrast == .increased ? 1.5 : 0.8
            )
        }
        .environment(
            \.layoutDirection,
            isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var discoveryHeader: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(HomeModelAdapter.localized(
                    "home_search_hint",
                    fallback: "What are you looking for?"
                ))
                .font(HomeFont.title2())
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Text(HomeModelAdapter.localized(
                    "home_pulse_search_prompt",
                    fallback: "Search products, pets, and services"
                ))
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.homeTextSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HomeHeaderSparkleMotion()
        }
    }

    private var searchButton: some View {
        Button(action: searchAction) {
            HStack(spacing: PPSpace.md) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                    .fill(Color.homeBrand)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Circle()
                        .fill(Color.homeRaisedSurface)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().fill(Color.homeBrand).padding(3))
                        .offset(x: 2, y: 2)
                }
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(HomeModelAdapter.localized(
                        "home_pulse_search_a11y",
                        fallback: "Search Pure Pets"
                    ))
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.homeTextPrimary)
                    .multilineTextAlignment(.leading)

                    HomeCommandBar.HomeAnimatedSearchSuggestionView(
                        isRTL: isRightToLeft
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                directionalArrow
            }
            .padding(.horizontal, PPSpace.base)
            .padding(.vertical, PPSpace.md)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePremiumSearchButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(HomeModelAdapter.localized(
            "home_pulse_search_a11y",
            fallback: "Search Pure Pets"
        ))
        .accessibilityHint(HomeModelAdapter.localized(
            "home_pulse_search_prompt",
            fallback: "Search products, pets, and services"
        ))
    }

    private var novaButton: some View {
        Button(action: novaAction) {
            HStack(spacing: PPSpace.md) {
                Text(verbatim: "N")
                    .font(HomeFont.bold(20))
                    .foregroundStyle(Color.white)
                    .frame(width: 46, height: 46)
                    .background(Color.homeBrandDeep, in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    ))
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: PPCorner.small,
                            style: .continuous
                        )
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeModelAdapter.localized(
                        "nova_empty_title",
                        fallback: "Ask Nova"
                    ))
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.homeBrandDeep)
                    .multilineTextAlignment(.leading)

                    Text(HomeModelAdapter.localized(
                        "nova_subtitle",
                        fallback: "Pure Pets smart shopping assistant"
                    ))
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.homeTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                directionalArrow
            }
            .padding(.horizontal, PPSpace.base)
            .padding(.vertical, PPSpace.md)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Color.homeBrand.opacity(colorScheme == .dark ? 0.12 : 0.055))
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePremiumSearchButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(HomeModelAdapter.localized(
            "home_pulse_nova_a11y",
            fallback: "Open Nova assistant"
        ))
        .accessibilityHint(HomeModelAdapter.localized(
            "home_pulse_nova_hint_a11y",
            fallback: "Ask Pure Pets for help"
        ))
    }

    private var directionalArrow: some View {
        Image(systemName: isRightToLeft ? "arrow.left" : "arrow.right")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.homeBrand)
            .frame(width: 36, height: 36)
            .background(Color.homeAmbientField.opacity(0.78), in: Circle())
            .accessibilityHidden(true)
    }

    private var sectionAtmosphere: Color {
        Color.homeAmbientField.opacity(colorScheme == .dark ? 0.42 : 0.72)
    }

    private var outerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
    }

    private var consoleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
    }
}

@available(iOS 15.0, *)
private struct HomePremiumSearchButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.988 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.16),
                value: configuration.isPressed
            )
    }
}

@available(iOS 15.0, *)
private struct HomeHeaderSparkleMotion: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.homeBrand)
            .scaleEffect(reduceMotion ? 1.0 : (isAnimating ? 1.12 : 0.94))
            .rotationEffect(.degrees(reduceMotion ? 0 : (isAnimating ? 10 : -6)))
            .opacity(reduceMotion ? 1.0 : (isAnimating ? 1.0 : 0.82))
            .frame(width: 42, height: 42)
            .background(Color.homeRaisedSurface.opacity(0.86), in: Circle())
            .overlay {
                Circle().stroke(Color.homeBrand.opacity(isAnimating ? 0.28 : 0.13), lineWidth: 0.8)
            }
            .shadow(color: Color.homeBrand.opacity(reduceMotion ? 0 : (isAnimating ? 0.25 : 0.05)), radius: 8)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 2.4)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
            .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
private struct HomeProviderCategoryNavigation: View {
    let action: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let categories = [
        HomeProviderCategory(
            id: "pharmacy",
            titleKey: "provider_pharmacies_title",
            subtitleKey: "provider_pharmacies_subtitle",
            symbol: "cross.case.fill",
            color: .homePharmacy
        ),
        HomeProviderCategory(
            id: "veterinarians",
            titleKey: "provider_vets_title",
            subtitleKey: "provider_vets_subtitle",
            symbol: "stethoscope",
            color: .homeVeterinary
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HomeSectionHeader(
                title: HomeModelAdapter.localized(
                    "home_provider_navigation_title",
                    fallback: "Trusted care"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_provider_navigation_subtitle",
                    fallback: "Choose the care destination you need"
                ),
                actionTitle: nil,
                action: nil
            )

            LazyVGrid(columns: columns, spacing: PPSpace.sm) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    Button { action(category.id) } label: {
                        VStack(alignment: .leading, spacing: PPSpace.sm) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(category.color)
                                .frame(width: 42, height: 42)
                                .background(category.color.opacity(0.12), in: RoundedRectangle(
                                    cornerRadius: PPCorner.small,
                                    style: .continuous
                                ))
                            Text(HomeModelAdapter.localized(category.titleKey, fallback: ""))
                                .font(HomeFont.headline())
                                .foregroundStyle(Color.homeTextPrimary)
                            Text(HomeModelAdapter.localized(category.subtitleKey, fallback: ""))
                                .font(HomeFont.footnote())
                                .foregroundStyle(Color.homeTextSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                        .padding(PPSpace.md)
                        .background(Color.homeSurface, in: RoundedRectangle(
                            cornerRadius: PPCorner.card,
                            style: .continuous
                        ))
                        .overlay {
                            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                                .stroke(category.color.opacity(0.24), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .modifier(HomeScrollCellReveal(ordinal: index))
                }
            }
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.sm),
            count: count
        )
    }
}

private struct HomeProviderCategory: Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let symbol: String
    let color: Color
}

@available(iOS 15.0, *)
private struct HomePremiumCareSection: View {
    let openVeterinary: () -> Void
    let openPharmacy: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Text(HomeModelAdapter.localized(
                "home_premium_care_eyebrow",
                fallback: "Premium care"
            ))
            .font(HomeFont.bold(12))
            .foregroundStyle(Color.homeBrandDeep)

            Text(HomeModelAdapter.localized(
                "home_premium_care_title",
                fallback: "Medicines and vets"
            ))
            .font(HomeFont.title1())
            .foregroundStyle(Color.homeTextPrimary)

            Text(HomeModelAdapter.localized(
                "home_premium_care_subtitle",
                fallback: "Pet medicine and veterinarian care in one refined place."
            ))
            .font(HomeFont.callout())
            .foregroundStyle(Color.homeTextSecondary)

            LazyVGrid(columns: columns, spacing: PPSpace.sm) {
                careButton(
                    titleKey: "provider_vets_title",
                    symbol: "stethoscope",
                    color: .homeVeterinary,
                    action: openVeterinary
                )
                careButton(
                    titleKey: "provider_pharmacies_title",
                    symbol: "cross.case.fill",
                    color: .homePharmacy,
                    action: openPharmacy
                )
            }
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.sm),
            count: count
        )
    }

    private func careButton(
        titleKey: String,
        symbol: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(HomeModelAdapter.localized(titleKey, fallback: ""), systemImage: symbol)
                .font(HomeFont.bold(15))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.homeRaisedSurface, in: RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                ))
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        .stroke(color.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 15.0, *)
private struct HomeAdoptionSection: View {
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    adoptionArtwork
                        .frame(maxWidth: .infinity)

                    adoptionCopy
                }
            } else {
                HStack(alignment: .center, spacing: PPSpace.base) {
                    adoptionCopy
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    adoptionArtwork
                }
            }
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? PPSpace.lg : PPSpace.base)
        .background {
            HomeHeroField(
                accent: Color.homeBrand,
                increasedContrast: contrast == .increased
            )
        }
        .overlay {
            cardShape.stroke(
                Color.homeBrand.opacity(
                    contrast == .increased
                        ? 0.58
                        : (colorScheme == .dark ? 0.34 : 0.20)
                ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .clipShape(cardShape)
        .shadow(
            color: Color.homeBrand.opacity(colorScheme == .dark ? 0.07 : 0.055),
            radius: contrast == .increased ? 0 : 10,
            y: contrast == .increased ? 0 : 4
        )
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
    }

    private var adoptionCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(HomeModelAdapter.localized(
                    "home_adopt_title",
                    fallback: "تعرّف إلى رفيقك القادم"
                ))
                .font(HomeFont.title1())
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

                Text(HomeModelAdapter.localized(
                    "home_adopt_subtitle",
                    fallback: "حيوانات تنتظر بيتاً محباً"
                ))
                .font(HomeFont.callout())
                .foregroundStyle(Color.homeTextSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                HStack(spacing: PPSpace.sm) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .accessibilityHidden(true)

                    Text(HomeModelAdapter.localized(
                        "home_quick_action_adopt",
                        fallback: "تبني"
                    ))
                    .font(HomeFont.bold(16))
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: PPSpace.sm)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .bold))
                        .flipsForRightToLeftLayoutDirection(true)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, PPSpace.base)
                .padding(.vertical, PPSpace.sm)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(PPGradient.hero, in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                ))
                .shadow(
                    color: Color.homeBrand.opacity(
                        contrast == .increased
                            ? 0
                            : (colorScheme == .dark ? 0.08 : 0.10)
                    ),
                    radius: contrast == .increased ? 0 : 4,
                    y: contrast == .increased ? 0 : 2
                )
                .contentShape(RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                ))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(HomeModelAdapter.localized(
                "home_quick_action_adopt",
                fallback: "تبني"
            ))
        }
    }

    private var adoptionArtwork: some View {
        ZStack {
            Circle()
                .fill(Color.homeRaisedSurface.opacity(colorScheme == .dark ? 0.72 : 0.90))

            Circle()
                .fill(Color.homeBrand.opacity(colorScheme == .dark ? 0.15 : 0.09))
                .padding(PPSpace.sm)

            Circle()
                .stroke(
                    Color.homeBrand.opacity(contrast == .increased ? 0.62 : 0.24),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )

            if reduceMotion {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 58, weight: .regular))
                    .foregroundStyle(Color.homeBrand)
            } else {
                HomeHeroLottieRepresentable(
                    animationName: "LottieAnimations/WomanPlayingWithCat.json",
                    loadsFromFirebase: true,
                    playbackEnabled: true
                )
                .clipShape(Circle())
                .padding(PPSpace.xs)
            }
        }
        .frame(
            width: dynamicTypeSize.isAccessibilitySize ? 176 : 148,
            height: dynamicTypeSize.isAccessibilitySize ? 176 : 148
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "heart.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.homeBrand)
                .frame(width: 36, height: 36)
                .background(Color.homeRaisedSurface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            Color.homeBrand.opacity(contrast == .increased ? 0.58 : 0.20),
                            lineWidth: contrast == .increased ? 1.5 : 1
                        )
                }
                .offset(
                    x: layoutDirection == .rightToLeft ? -2 : 2,
                    y: -2
                )
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

@available(iOS 15.0, *)
private struct HomeOrderContextSheet: View {
    let order: HomeOrderModel
    let openDetails: () -> Void
    let openHistory: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            Capsule()
                .fill(Color.homeSeparator)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            HStack(spacing: PPSpace.md) {
                Image(systemName: order.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.homeBrand)
                    .frame(width: 54, height: 54)
                    .background(Color.homeAmbientField, in: RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    ))
                VStack(alignment: .leading, spacing: 3) {
                    Text(HomeModelAdapter.localized(
                        "home_pulse_current_order_title",
                        fallback: "Current order"
                    ))
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.homeTextPrimary)
                    Text(order.reference)
                        .font(HomeFont.footnote())
                        .foregroundStyle(Color.homeTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: PPSpace.sm) {
                Text(order.statusTitle)
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.homeTextPrimary)
                Text(order.statusHint)
                    .font(HomeFont.callout())
                    .foregroundStyle(Color.homeTextSecondary)
                ProgressView(value: order.progress)
                    .tint(Color.homeBrand)
                    .accessibilityLabel(order.statusTitle)
            }

            HStack {
                Text(String(
                    format: HomeModelAdapter.localized(
                        "home_pulse_order_items",
                        fallback: "%d items"
                    ),
                    order.itemCount
                ))
                Spacer()
                if !order.amount.isEmpty {
                    Text(order.amount)
                }
            }
            .font(HomeFont.bold(15))
            .foregroundStyle(Color.homeTextPrimary)

            Button(action: openDetails) {
                Text(HomeModelAdapter.localized("Details", fallback: "Details"))
                    .font(HomeFont.bold(16))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.homeBrand, in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    ))
            }
            .buttonStyle(.plain)

            Button(action: openHistory) {
                Text(HomeModelAdapter.localized(
                    "home_pulse_orders",
                    fallback: "Orders"
                ))
                .font(HomeFont.bold(16))
                .foregroundStyle(Color.homeBrand)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)

            Button(action: { dismiss() }) {
                Text(HomeModelAdapter.localized("Close", fallback: "Close"))
                    .font(HomeFont.callout())
                    .foregroundStyle(Color.homeTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(PPSpace.xl)
        .background(Color.homeCanvas.ignoresSafeArea())
    }
}

private struct HomeEntranceModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : 16)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.12)
                    : .spring(response: 0.58, dampingFraction: 0.92).delay(delay),
                value: isVisible
            )
    }
}

private struct HomeSectionEntranceModifier: ViewModifier {
    let isVisible: Bool
    let sectionIndex: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let cappedIndex = min(sectionIndex, 6)
        let delay = Double(cappedIndex) * 0.045
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(
                reduceMotion || isVisible ? 1 : 0.985,
                anchor: .top
            )
            .offset(y: reduceMotion || isVisible ? 0 : 18)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.12)
                    : .spring(
                        response: 0.52,
                        dampingFraction: 0.82,
                        blendDuration: 0.08
                    ).delay(delay),
                value: isVisible
            )
    }
}

private extension View {
    func homeEntrance(
        isVisible: Bool,
        delay: Double,
        reduceMotion: Bool
    ) -> some View {
        modifier(HomeEntranceModifier(
            isVisible: isVisible,
            delay: delay,
            reduceMotion: reduceMotion
        ))
    }

    func homeSectionEntrance(
        isVisible: Bool,
        sectionIndex: Int,
        reduceMotion: Bool
    ) -> some View {
        modifier(HomeSectionEntranceModifier(
            isVisible: isVisible,
            sectionIndex: sectionIndex,
            reduceMotion: reduceMotion
        ))
    }

    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

extension Color {
    static var homeCanvas: Color {
        .ppBackground
    }

    static var homeAmbientField: Color {
        .ppSoftRose
    }

    static var homeSectionBand: Color {
        .ppSecondarySurface
    }

    static var homeSurface: Color {
        .ppSurface
    }

    static var homeRaisedSurface: Color {
        .ppElevatedSurface
    }

    static var homeTextPrimary: Color {
        .ppTextPrimary
    }

    static var homeTextSecondary: Color {
        .ppTextSecondary
    }

    static var homeBrand: Color {
        .ppPrimary
    }

    static var homeBrandDeep: Color {
        .ppPrimaryDarker
    }

    static var homeVeterinary: Color {
        .ppInfo
    }

    static var homePharmacy: Color {
        .ppSuccess
    }

    static var homeServices: Color {
        .ppWarning
    }

    static var homeStatusSuccess: Color {
        .ppSuccess
    }

    static var homeStatusWarning: Color {
        .ppWarning
    }

    static var homeStatusError: Color {
        .ppError
    }

    static var homeSeparator: Color {
        .ppSeparator
    }

    static var homeFocus: Color {
        .ppInfo
    }
}
