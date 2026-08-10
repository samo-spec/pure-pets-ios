import SwiftUI
import UIKit

private enum HomeSectionRawID {
    static let pureLens = 20
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
        pureLens, hero, quickActions, currentOrders, carousel, mainKinds,
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
    @State private var pureLensContentMotionReady = false
    @State private var pureLensSignalStoryPlayed = false
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
                configuredSection(section, sectionIndex: index)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, sectionVerticalPadding(section.id))
                    .background(sectionBand(for: section.id))
                    .homeSectionEntrance(
                        isVisible: loadedEntranceVisible,
                        sectionIndex: index,
                        reduceMotion: reduceMotion
                    )
                    .homeVerticalSectionReveal(
                        entranceAlreadyPlayed: loadedEntranceVisible
                    )
                    .homeSectionDataReload(
                        revision: store.sectionDataRevision(for: section.id),
                        accent: sectionReloadAccent(for: section.id)
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
            if section.id == HomeSectionRawID.pureLens {
                if #available(iOS 16.0, *) {
                    return store.state.config.pureLensVisible
                }
                return false
            }
            return true
        }
    }

    @ViewBuilder
    private func configuredSection(
        _ section: HomeConfigSection,
        sectionIndex: Int
    ) -> some View {
        switch section.id {
        case HomeSectionRawID.pureLens:
            if #available(iOS 16.0, *), let pureLensAction {
                HomePureLensSection(
                    motionReady: pureLensContentMotionReady,
                    motionAlreadyPlayed: pureLensSignalStoryPlayed,
                    onMotionSettled: {
                        pureLensSignalStoryPlayed = true
                    },
                    action: pureLensAction
                )
                .padding(.horizontal, PPSpace.screenMargin)
                .modifier(HomePureLensMotionGate(
                    homeEntranceAlreadyPresented: loadedEntranceVisible,
                    sectionIndex: sectionIndex,
                    isReady: $pureLensContentMotionReady
                ))
            }

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
        case HomeSectionRawID.suggestions,
             HomeSectionRawID.suggestionAds,
             HomeSectionRawID.suggestionAccessories:
            return .ppQuietLilac
        case HomeSectionRawID.premiumCare:
            return .homeSectionBand
        case HomeSectionRawID.nearbyServices:
            return .homeAmbientField
        default:
            return .clear
        }
    }

    private func sectionReloadAccent(for rawID: Int) -> Color {
        switch rawID {
        case HomeSectionRawID.mainKinds,
             HomeSectionRawID.marketplaceHero,
             HomeSectionRawID.suggestions,
             HomeSectionRawID.accessories,
             HomeSectionRawID.lastFood,
             HomeSectionRawID.adsNearby,
             HomeSectionRawID.suggestionAds,
             HomeSectionRawID.suggestionAccessories:
            return selectedMainKindAccent
        case HomeSectionRawID.petProfile,
             HomeSectionRawID.quickActions:
            return .homeStatusSuccess
        case HomeSectionRawID.premiumCare:
            return .homeVeterinary
        case HomeSectionRawID.nearbyServices,
             HomeSectionRawID.providerCategoryNav:
            return .homeServices
        case HomeSectionRawID.currentOrders,
             HomeSectionRawID.buyAgain:
            return .homeFocus
        default:
            return .homeBrand
        }
    }

    private var selectedMainKindAccent: Color {
        guard let selectedID = store.state.selectedMainKindID,
              let category = store.state.categories.first(where: {
                  HomeModelAdapter.mainKindID($0.raw) == selectedID
              })
        else {
            return .homeBrand
        }
        return Color(uiColor: category.accent)
    }

    private var pureLensAction: (() -> Void)? {
        guard store.state.config.pureLensVisible else {
            return nil
        }
        let homeStore = store
        return {
            homeStore.openPureLens()
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

    @State private var selection = 0

    private var cards: [PPPromoCard] {
        pages.enumerated().map { index, page in
            PPPromoCard(homeHeroPage: page, position: index, totalCount: pages.count)
        }
    }

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selection) else { return nil }
        return pages[selection]
    }

    var body: some View {
        PPPeekCarousel(
            cards: cards,
            isActive: !pages.isEmpty,
            onAction: performPromoAction,
            selection: $selection
        )
        .onAppear(perform: resolveSelection)
        .onChange(of: pages.map(\.id)) { _ in resolveSelection() }
    }

    private func resolveSelection() {
        guard !pages.isEmpty else {
            selection = 0
            return
        }
        selection = min(max(selection, 0), pages.count - 1)
    }

    private func performPromoAction(_ action: PPPromoAction) {
        guard let page = page(for: action.cardID) else { return }
        switch action.source {
        case .card, .primaryButton:
            primaryAction(page)
        case .secondaryButton:
            secondaryAction(page)
        }
    }

    private func page(for cardID: String) -> HomeHeroPage? {
        pages.first(where: { $0.id == cardID })
    }
}

private extension PPPromoCard {
    init(homeHeroPage page: HomeHeroPage, position: Int, totalCount: Int) {
        let primaryTitle =
            page.primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondaryTitle =
            page.secondaryTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.init(
            id: page.id,
            position: position,
            totalCount: totalCount,
            badgeText: page.eyebrow,
            title: page.title,
            subtitle: page.subtitle,
            primaryButtonTitle: primaryTitle,
            secondaryButtonTitle: secondaryTitle,
            showsPrimaryButton: !primaryTitle.isEmpty,
            showsSecondaryButton: !secondaryTitle.isEmpty,
            artworkURL: page.imageURL.flatMap(URL.init(string:)),
            localArtworkName: nil,
            startColorHex: page.accentHex,
            endColorHex: page.accentHex,
            accentColorHex: page.accentHex,
            cardActionRawValue: 0,
            cardActionValue: "",
            primaryActionRawValue: 0,
            primaryActionValue: "",
            secondaryActionRawValue: 0,
            secondaryActionValue: "",
            autoScrollInterval: page.autoScrollInterval
        )
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
            }
            .ppElevation(.floating, cornerRadius: PPCorner.card)
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

            if showsNova {
                Button(action: novaAction) {
                    HomeHeaderSparkleMotion()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(HomeModelAdapter.localized(
                    "nova_empty_title",
                    fallback: "Ask Nova"
                ))
                .accessibilityHint(HomeModelAdapter.localized(
                    "nova_empty_subtitle",
                    fallback: "Smart shopping assistant from Pure Pets"
                ))
            } else {
                HomeHeaderSparkleMotion()
            }
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
                    .fill(Color.ppAdoptionAccent)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Circle()
                        .fill(Color.homeRaisedSurface)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().fill(Color.ppAdoptionAccent).padding(3))
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

    private var directionalArrow: some View {
        Image(systemName: isRightToLeft ? "arrow.left" : "arrow.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.ppAdoptionAccent)
            .frame(width: 32, height: 32)
            .background(Color.ppAdoptionAccent.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }

    private var sectionAtmosphere: Color {
        Color.ppAdoptionAccent.opacity(colorScheme == .dark ? 0.12 : 0.08)
    }

    private var outerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.section, style: .continuous)
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
            .foregroundStyle(Color.ppAdoptionAccent)
            .scaleEffect(reduceMotion ? 1.0 : (isAnimating ? 1.12 : 0.94))
            .rotationEffect(.degrees(reduceMotion ? 0 : (isAnimating ? 10 : -6)))
            .opacity(reduceMotion ? 1.0 : (isAnimating ? 1.0 : 0.82))
            .frame(width: 42, height: 42)
            .background(Color.homeRaisedSurface.opacity(0.86), in: Circle())
            .overlay {
                Circle().stroke(Color.ppAdoptionAccent.opacity(isAnimating ? 0.28 : 0.13), lineWidth: 0.8)
            }
            .shadow(color: Color.ppAdoptionAccent.opacity(reduceMotion ? 0 : (isAnimating ? 0.25 : 0.05)), radius: 8)
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
                accent: Color.ppAdoptionAccent,
                increasedContrast: contrast == .increased,
                cornerGlowOpacityScale: 1
            )
        }
        .overlay {
            cardShape.stroke(
                Color.ppAdoptionAccent.opacity(
                    contrast == .increased
                        ? 0.58
                        : (colorScheme == .dark ? 0.34 : 0.20)
                ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .clipShape(cardShape)
        .shadow(
            color: Color.ppAdoptionAccent.opacity(colorScheme == .dark ? 0.07 : 0.055),
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
                    color: Color.ppBrandPrimary.opacity(
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
                .fill(Color.ppAdoptionAccent.opacity(colorScheme == .dark ? 0.15 : 0.09))
                .padding(PPSpace.sm)

            Circle()
                .stroke(
                    Color.ppAdoptionAccent.opacity(contrast == .increased ? 0.62 : 0.24),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )

            if reduceMotion {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 58, weight: .regular))
                    .foregroundStyle(Color.ppAdoptionAccent)
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
                .foregroundStyle(Color.ppAdoptionAccent)
                .frame(width: 36, height: 36)
                .background(Color.homeRaisedSurface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            Color.ppAdoptionAccent.opacity(contrast == .increased ? 0.58 : 0.20),
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
        let delay = HomeSectionEntranceMotion.staggerDelay(
            sectionIndex: sectionIndex
        )
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
                        response: HomeSectionEntranceMotion.response,
                        dampingFraction: 0.82,
                        blendDuration: 0.08
                    ).delay(delay),
                value: isVisible
            )
    }
}

// MARK: - HomeVerticalSectionReveal — willDisplaySection equivalent

/// World-class scroll-in animation for sections inside the vertical home feed.
///
/// This is the SwiftUI equivalent of `collectionView(_:willDisplaySupplementaryView:…)`
/// or a section-scoped `willDisplay`. `.onAppear` in a `LazyVStack` fires only
/// when the view enters the visible viewport — exactly matching `willDisplay`.
///
/// **Dual-phase intelligence** (mirrors `HomeHorizontalCellReveal`):
/// - `entranceAlreadyPlayed == false`: born during the initial stagger window.
///   `HomeSectionEntranceModifier` owns these. This modifier is a no-op.
/// - `entranceAlreadyPlayed == true`: section scrolled in after first load.
///   Stages the section (opacity 0, scaled from the top, offset below) then
///   springs it into its settled pose with no delay.
///
/// **Motion design:**
///   • Anchor: `.top` — the header stays pinned while the body rises
///   • y offset: +26 pt — section surfaces from just below the fold
///   • scale: 0.976 from `.top` — subtle perspective of distance
///   • Spring: response 0.44, dampingFraction 0.82 — slightly faster than the
///     initial entrance so scroll-in feels immediate and rewarding, not sluggish
///   • No artificial stagger — only one section appears at a time vertically
///   • Reduce Motion: opacity crossfade only; no spatial transforms
private struct HomeVerticalSectionReveal: ViewModifier {
    let entranceAlreadyPlayed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(opacityValue)
            .scaleEffect(scaleValue, anchor: .top)
            .offset(y: offsetY)
            .animation(revealAnimation, value: revealed)
            .onAppear { handleAppear() }
    }

    // MARK: Render values

    private var isStaged: Bool { !revealed && !reduceMotion }

    private var opacityValue: Double {
        guard entranceAlreadyPlayed else { return 1 }
        return revealed ? 1 : 0
    }

    private var scaleValue: CGFloat {
        guard entranceAlreadyPlayed, isStaged else { return 1 }
        return 0.976
    }

    private var offsetY: CGFloat {
        guard entranceAlreadyPlayed, isStaged else { return 0 }
        return 26
    }

    private var revealAnimation: Animation {
        guard entranceAlreadyPlayed else { return .easeOut(duration: 0) }
        if reduceMotion { return .easeOut(duration: 0.18) }
        return .spring(
            response: HomeVerticalSectionMotion.response,
            dampingFraction: 0.82,
            blendDuration: 0.06
        )
    }

    // MARK: onAppear

    private func handleAppear() {
        guard !revealed else { return }
        if !entranceAlreadyPlayed {
            // Initial entrance window — HomeSectionEntranceModifier owns this.
            // Mark ourselves settled so we stay transparent.
            revealed = true
            return
        }
        // Scroll-in: defer one run-loop to ensure the staged pose is committed
        // to the render tree before the spring begins.
        DispatchQueue.main.async {
            guard !revealed else { return }
            revealed = true
        }
    }
}

/// Releases the Pure Lens content story only after Home's section reveal has
/// reached its stable pose. The structured task cancels if the section leaves.
private struct HomePureLensMotionGate: ViewModifier {
    let homeEntranceAlreadyPresented: Bool
    let sectionIndex: Int
    @Binding var isReady: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.task(id: reduceMotion) {
            await releaseAfterHomeMotionSettles()
        }
    }

    @MainActor
    private func releaseAfterHomeMotionSettles() async {
        guard !isReady else { return }

        if reduceMotion {
            isReady = true
            return
        }

        let nanoseconds = homeEntranceAlreadyPresented
            ? HomeVerticalSectionMotion.settleDelayNanoseconds
            : HomeSectionEntranceMotion.settleDelayNanoseconds(
                sectionIndex: sectionIndex
            )

        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        isReady = true
    }
}

private enum HomeSectionEntranceMotion {
    static let maximumStaggerIndex = 6
    static let staggerStep: Double = 0.045
    static let response: Double = 0.52
    /// Allows the damped spring to visually settle beyond its response time.
    static let settlementBuffer: Double = 0.12

    static func staggerDelay(sectionIndex: Int) -> Double {
        Double(min(sectionIndex, maximumStaggerIndex)) * staggerStep
    }

    static func settleDelayNanoseconds(sectionIndex: Int) -> UInt64 {
        let seconds = staggerDelay(sectionIndex: sectionIndex)
            + response
            + settlementBuffer
        return UInt64(seconds * 1_000_000_000)
    }
}

private enum HomeVerticalSectionMotion {
    static let response: Double = 0.44
    /// Matches the initial entrance's post-response settlement allowance.
    static let settlementBuffer: Double = 0.12

    static var settleDelayNanoseconds: UInt64 {
        UInt64((response + settlementBuffer) * 1_000_000_000)
    }
}

/// A one-shot data-arrival signal that never transforms or fades shelf content.
/// Rapid revisions coalesce before presentation, and cancellation always leaves
/// the section itself in its stable rendered pose.
private struct HomeSectionDataReloadModifier: ViewModifier {
    let revision: Int
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var observedRevision: Int?
    @State private var traceProgress: CGFloat = 0
    @State private var bloomProgress: CGFloat = 0
    @State private var signalOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                HomeSectionReloadSignal(
                    accent: accent,
                    traceProgress: traceProgress,
                    bloomProgress: bloomProgress,
                    signalOpacity: signalOpacity,
                    lineAnchor: semanticLineAnchor
                )
                .padding(.leading, PPSpace.screenMargin)
            }
            .task(id: revision) {
                await presentReloadSignalIfNeeded()
            }
            .onChange(of: reduceMotion) { enabled in
                if enabled {
                    resetSignal()
                }
            }
            .onDisappear(perform: resetSignal)
    }

    @MainActor
    private func presentReloadSignalIfNeeded() async {
        guard let previousRevision = observedRevision else {
            observedRevision = revision
            resetSignal()
            return
        }
        guard previousRevision != revision else { return }
        observedRevision = revision

        guard !motionIsSuppressed else {
            resetSignal()
            return
        }

        guard await wait(HomeSectionReloadMotion.coalescingDelay) else {
            return
        }

        if signalOpacity > 0.001 {
            withAnimation(.easeOut(
                duration: HomeSectionReloadMotion.interruptionDuration
            )) {
                signalOpacity = 0
            }
            guard await wait(HomeSectionReloadMotion.interruptionDelay) else {
                return
            }
        }

        resetSignal()
        withAnimation(HomeSectionReloadMotion.arrivalAnimation) {
            traceProgress = 1
            bloomProgress = 1
            signalOpacity = 1
        }

        guard await wait(HomeSectionReloadMotion.arrivalDelay) else {
            return
        }

        withAnimation(.easeOut(
            duration: HomeSectionReloadMotion.departureDuration
        )) {
            signalOpacity = 0
        }

        guard await wait(HomeSectionReloadMotion.departureDelay) else {
            return
        }
        resetSignal()
    }

    @MainActor
    private func wait(_ nanoseconds: UInt64) async -> Bool {
        do {
            try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private func resetSignal() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            traceProgress = 0
            bloomProgress = 0
            signalOpacity = 0
        }
    }

    private var motionIsSuppressed: Bool {
        reduceMotion ||
        UIAccessibility.isVoiceOverRunning ||
        UIAccessibility.isSwitchControlRunning
    }

    private var semanticLineAnchor: UnitPoint {
        layoutDirection == .rightToLeft ? .trailing : .leading
    }
}

private struct HomeSectionReloadSignal: View {
    let accent: Color
    let traceProgress: CGFloat
    let bloomProgress: CGFloat
    let signalOpacity: Double
    let lineAnchor: UnitPoint

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: PPSpace.xs) {
            ZStack {
                Circle()
                    .stroke(
                        accent.opacity(contrast == .increased ? 0.88 : 0.46),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
                    .frame(
                        width: HomeSectionReloadMotion.bloomDiameter,
                        height: HomeSectionReloadMotion.bloomDiameter
                    )
                    .scaleEffect(
                        HomeSectionReloadMotion.bloomStartScale +
                            (HomeSectionReloadMotion.bloomTravel * bloomProgress)
                    )
                    .opacity(
                        signalOpacity * (1 - Double(bloomProgress))
                    )

                Circle()
                    .fill(accent)
                    .frame(
                        width: HomeSectionReloadMotion.originDiameter,
                        height: HomeSectionReloadMotion.originDiameter
                    )
            }
            .frame(
                width: HomeSectionReloadMotion.bloomDiameter,
                height: HomeSectionReloadMotion.bloomDiameter
            )

            Capsule()
                .fill(accent.opacity(contrast == .increased ? 1 : 0.68))
                .frame(
                    width: HomeSectionReloadMotion.traceWidth,
                    height: contrast == .increased
                        ? HomeSectionReloadMotion.increasedTraceHeight
                        : HomeSectionReloadMotion.traceHeight
                )
                .scaleEffect(
                    x: max(HomeSectionReloadMotion.minimumTraceScale, traceProgress),
                    y: 1,
                    anchor: lineAnchor
                )
        }
        .frame(height: PPSpace.sm)
        .opacity(signalOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum HomeSectionReloadMotion {
    static let coalescingDelay: UInt64 = 90_000_000
    static let interruptionDelay: UInt64 = 80_000_000
    static let arrivalDelay: UInt64 = 260_000_000
    static let departureDelay: UInt64 = 200_000_000

    static let interruptionDuration = 0.08
    static let arrivalDuration = 0.24
    static let departureDuration = 0.20
    static let arrivalAnimation = Animation.timingCurve(
        0.2,
        0,
        0,
        1,
        duration: arrivalDuration
    )

    static let bloomDiameter: CGFloat = 8
    static let originDiameter: CGFloat = 3
    static let bloomStartScale: CGFloat = 0.56
    static let bloomTravel: CGFloat = 0.72
    static let traceWidth: CGFloat = 40
    static let traceHeight: CGFloat = 1.5
    static let increasedTraceHeight: CGFloat = 2
    static let minimumTraceScale: CGFloat = 0.02
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

    func homeVerticalSectionReveal(
        entranceAlreadyPlayed: Bool
    ) -> some View {
        modifier(HomeVerticalSectionReveal(
            entranceAlreadyPlayed: entranceAlreadyPlayed
        ))
    }

    func homeSectionDataReload(
        revision: Int,
        accent: Color
    ) -> some View {
        modifier(HomeSectionDataReloadModifier(
            revision: revision,
            accent: accent
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
        .ppSurfaceBase
    }

    static var homeAmbientField: Color {
        .ppSurfaceOverlay
    }

    static var homeAtmosphere: Color {
        .homeAmbientField
    }

    static var homeSectionBand: Color {
        .ppSecondarySurface
    }

    static var homeSurface: Color {
        .ppSurfaceRaised
    }

    static var homeRaisedSurface: Color {
        .ppSurfaceElevated
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
        .ppCareAccent
    }

    static var homePharmacy: Color {
        .ppCareAccent
    }

    static var homeServices: Color {
        .ppCareAccent
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
