import SwiftUI
import UIKit

// MARK: - Hero composition flag

/// Presentation flag for the Home hero composition.
///
/// `UseHeroV2 == true` renders `HomeHeroV2View`: a compact editorial card
/// whose copy column owns the leading edge and whose category artwork plus
/// living plate bubble form one contained object on the trailing edge.
///
/// `UseHeroV2 == false` restores `PPHomeMarketingStage`, the previous inset card
/// composition. Both branches are fed the same pages and the same `HomeStore`
/// callbacks, so this switch is presentation-only: paging state, navigation,
/// hero actions, and the marketplace signal contract are unchanged either way.
enum PPHomeHeroFlags {
    static let UseHeroV2 = true
}

// MARK: - Render rows

/// A flattened, ordered, stably identified render list derived from the
/// deterministic presentation plan. Zones stay a product concept; this is what
/// the lazy vertical container actually walks.
private struct HomeRenderRow: Identifiable {
    enum Content {
        case module(PPHomeModule)
        case exploreMore
    }

    let id: String
    let zone: PPHomeZoneID
    let content: Content

    var rawID: Int? {
        if case let .module(module) = content { return module.rawID }
        return nil
    }

    /// The marketplace Living Ledger owns its required category-bound reveal.
    /// Exempt only that module from the generic row spring so motion never
    /// stacks; promotions and pet-context stages retain existing behavior.
    var usesIndependentContentMotion: Bool {
        guard case let .module(module) = content,
              case .marketingStage(.marketplace) = module.kind
        else { return false }
        return true
    }
}

@available(iOS 15.0, *)
private struct HomeLivingGatewayStage: View {
    let pages: [HomeHeroPage]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onPrimary: (HomeHeroPage) -> Void
    let onSecondary: (HomeHeroPage) -> Void
    let onInteractionChanged: (Bool) -> Void

    init(
        pages: [HomeHeroPage],
        selectedIndex: Int,
        discloseCampaign: Bool,
        marketplaceSignals: HomeMarketplaceSignals = HomeMarketplaceSignals(),
        onSelect: @escaping (Int) -> Void,
        onPrimary: @escaping (HomeHeroPage) -> Void,
        onSecondary: @escaping (HomeHeroPage) -> Void,
        onInteractionChanged: @escaping (Bool) -> Void,
        onMarketplaceSignal: @escaping (HomeMarketplaceSignalKind) -> Void = { _ in }
    ) {
        self.pages = pages
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onInteractionChanged = onInteractionChanged
    }

    private var resolvedIndex: Int {
        pages.indices.contains(selectedIndex) ? selectedIndex : 0
    }

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(resolvedIndex) else {
            return nil
        }
        return pages[resolvedIndex]
    }

    var body: some View {
        HomeHeroView(
            pages: pages,
            selectedIndex: resolvedIndex,
            onSelect: onSelect,
            onPrimaryAction: performPrimaryAction,
            onSecondaryAction: performSecondaryAction,
            onInteractionChanged: onInteractionChanged
        )
    }

    private func performPrimaryAction() {
        guard let selectedPage else { return }
        onPrimary(selectedPage)
    }

    private func performSecondaryAction() {
        guard let selectedPage else { return }
        onSecondary(selectedPage)
    }
}

/// Home Hero V2 stage.
///
/// Adapts `HomeStore`'s page-scoped hero callbacks to `HomeHeroV2View`, which
/// takes index-free primary/secondary closures. The initializer intentionally
/// mirrors `PPHomeMarketingStage` so the marketing row can be pointed at either
/// composition without touching its call sites.
///
/// V2 owns its compact 16pt outer inset internally so the card and its shadow
/// stay optically consistent across Home presentation plans. The row therefore
/// must not add the standard section margin a second time.
@available(iOS 15.0, *)
private struct HomeHeroV2Stage: View {
    let pages: [HomeHeroPage]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onPrimary: (HomeHeroPage) -> Void
    let onSecondary: (HomeHeroPage) -> Void
    let onInteractionChanged: (Bool) -> Void

    init(
        pages: [HomeHeroPage],
        selectedIndex: Int,
        discloseCampaign: Bool,
        marketplaceSignals: HomeMarketplaceSignals = HomeMarketplaceSignals(),
        onSelect: @escaping (Int) -> Void,
        onPrimary: @escaping (HomeHeroPage) -> Void,
        onSecondary: @escaping (HomeHeroPage) -> Void,
        onInteractionChanged: @escaping (Bool) -> Void,
        onMarketplaceSignal: @escaping (HomeMarketplaceSignalKind) -> Void = { _ in }
    ) {
        self.pages = pages
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onInteractionChanged = onInteractionChanged
    }

    private var resolvedIndex: Int {
        pages.indices.contains(selectedIndex) ? selectedIndex : 0
    }

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(resolvedIndex) else { return nil }
        return pages[resolvedIndex]
    }

    var body: some View {
        HomeHeroV2View(
            pages: pages,
            selectedIndex: resolvedIndex,
            onSelect: onSelect,
            onPrimaryAction: performPrimaryAction,
            onSecondaryAction: performSecondaryAction,
            onInteractionChanged: onInteractionChanged
        )
    }

    private func performPrimaryAction() {
        guard let selectedPage else { return }
        onPrimary(selectedPage)
    }

    private func performSecondaryAction() {
        guard let selectedPage else { return }
        onSecondary(selectedPage)
    }
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

    // MARK: Plan

    private var plan: PPHomePresentationPlan {
        PPHomePresentationResolver.plan(for: store.state)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                HomeCommandBar(
                    state: store.state,
                    searchProminence: plan.searchProminence,
                    customAccent: activeHomeAccent,
                    searchAction: store.router.openSearch,
                    cartAction: store.router.openCart,
                    locationAction: store.locationTapped,
                    novaAction: store.router.openNova
                )
                .zIndex(10)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        Color.clear
                            .frame(height: 1)
                            .id(topAnchor)
                            .accessibilityHidden(true)

                        content
                            .padding(.top, 0)
                            .padding(.bottom, bottomPadding)
                    }
                }
                .scrollDismissesKeyboardCompat()
                .refreshable {
                    await store.refresh()
                }
            }
            .background(background)
            .overlay(alignment: .bottom) {
                bottomNavigationFade
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

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.state.connectivity == .offline || (store.state.isUserLoggedIn && store.state.phase == .partial) {
                HomeStatusBanner(
                    state: store.state,
                    retry: store.retryAll
                )
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
                .padding(.vertical, PPSpace.sm)
            }

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
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
                .padding(.vertical, PPSpace.xl)
            case .empty:
                emptyContent
            case .loaded, .refreshing, .partial:
                zonedContent(plan)
            }
        }
    }

    // MARK: Loaded

    private func zonedContent(
        _ resolvedPlan: PPHomePresentationPlan
    ) -> some View {
        let rows = renderRows(for: resolvedPlan)

        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let previousRow = index > 0 ? rows[index - 1] : nil
                renderRow(
                    row,
                    plan: resolvedPlan,
                    sectionIndex: index
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(
                        .top,
                        topPadding(for: row, after: previousRow)
                    )
                    .padding(.bottom, verticalPadding(for: row))
                    .background(rowBackground(for: row))
                    .homeResolvedSectionEntrance(
                        isVisible: loadedEntranceVisible,
                        sectionIndex: index,
                        reduceMotion: reduceMotion,
                        usesEcosystemMotion: row.zone == .ecosystemLauncher,
                        usesIndependentContentMotion:
                            row.usesIndependentContentMotion
                    )
                    .homeSectionDataReload(
                        revision: row.rawID.map(store.sectionDataRevision) ?? 0,
                        accent: reloadAccent(for: row)
                    )
                    .id("home-row-\(row.id)")
            }
        }
        .onAppear(perform: startLoadedEntranceIfNeeded)
    }

    /// `AppConfigCol/HomeConfig.sections` is the Console's persisted ordering
    /// authority. The resolver assigns a presentation zone for visual treatment
    /// and bounds, but it must not move a configured module ahead of another
    /// configured module. In particular, raw section `1` (Explore Pure Pets)
    /// now follows an operator's Home Control drag position.
    private func renderRows(
        for resolvedPlan: PPHomePresentationPlan
    ) -> [HomeRenderRow] {
        var rows: [HomeRenderRow] = []
        var modulesByRawID: [
            Int: (zone: PPHomeZoneID, module: PPHomeModule)
        ] = [:]

        for zone in resolvedPlan.zones where zone.id != .commandSurface {
            for module in zone.modules {
                modulesByRawID[module.rawID] = (zone.id, module)
            }
        }

        // Removing the module as it is emitted preserves the resolver's
        // duplicate suppression if malformed legacy configuration repeats an
        // identifier.
        for rawID in store.state.config.orderedSectionIDs {
            guard let resolved = modulesByRawID.removeValue(forKey: rawID)
            else { continue }
            rows.append(
                HomeRenderRow(
                    id: "\(resolved.zone.rawValue)-\(resolved.module.rawID)",
                    zone: resolved.zone,
                    content: .module(resolved.module)
                )
            )
        }

        // This is not a Home Control section: it is an in-app recovery surface
        // for bounded modules. It therefore follows all operator-configured
        // sections instead of being assigned a fabricated Console position.
        if !exploreMoreEntries(for: resolvedPlan).isEmpty {
            rows.append(
                HomeRenderRow(
                    id: "explore-more",
                    zone: .commerceDiscovery,
                    content: .exploreMore
                )
            )
        }

        return rows
    }

    @ViewBuilder
    private func renderRow(
        _ row: HomeRenderRow,
        plan resolvedPlan: PPHomePresentationPlan,
        sectionIndex: Int
    ) -> some View {
        switch row.content {
        case let .module(module):
            moduleView(
                module,
                plan: resolvedPlan,
                sectionIndex: sectionIndex
            )
        case .exploreMore:
            PPHomeExploreMoreRow(entries: exploreMoreEntries(for: resolvedPlan))
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
        }
    }

    @ViewBuilder
    private func moduleView(
        _ module: PPHomeModule,
        plan resolvedPlan: PPHomePresentationPlan,
        sectionIndex: Int
    ) -> some View {
        switch module.kind {
        case .discoveryPrompt:
            // Owned by the pinned command bar's search lane, never by a row.
            EmptyView()

        case let .marketingStage(source):
            marketingStage(source)
                // Home Hero V2 is full-bleed: its plate bubble bleeds past the
                // trailing screen edge, so the row drops the content margin
                // while the flag is on. V1 keeps its card inset.
                .padding(
                    .horizontal,
                    PPHomeHeroFlags.UseHeroV2
                        ? 0
                        : HomeVisualTokens.contentHorizontalMargin
                )

        case .ecosystemLauncher:
            PPHomeEcosystemLauncher(
                featuredAction: PPHomePresentationResolver
                    .ecosystemLauncherFeaturedAction(
                        for: store.state,
                        plan: resolvedPlan
                    ),
                featuredPet: store.selectedPriorityPet,
                actions: PPHomePresentationResolver.ecosystemLauncherActions(
                    for: store.state,
                    plan: resolvedPlan
                ),
                onSelect: store.performPriorityAction
            )
            .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)

        case .livePriorityOrder:
            if let order = store.state.featuredOrder {
                HomeOrderCard(
                    order: order,
                    onTap: { store.openOrder(order) }
                )
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
            }

        case .livePriorityCare:
            if let reminder = store.state.heroPages.first(where: {
                $0.kind == .reminder
            }) {
                PPHomeStatusCard(
                    page: reminder,
                    action: { store.performHeroAction(reminder) }
                )
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
            }

        case .discoveryRail:
            HomeCategoryRail(
                categories: store.state.categories,
                selectedID: store.state.selectedMainKindID,
                entrancePresented: loadedEntranceVisible,
                onSelect: store.selectCategory
            )

        case .commerceRail:
            if let feed = store.state.sections.first(where: {
                $0.id == module.rawID
            }) {
                HomeFeedSection(
                    section: feed,
                    store: store,
                    entrancePresented: loadedEntranceVisible
                )
            }

        case let .partnerFeature(source):
            partnerFeature(source)
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)

        case let .careGateway(variant):
            careGateway(variant)
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)

        case .adoptionGateway:
            HomeAdoptionSection(action: store.openAdoption)
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)

        case .petContext:
            PPHomePetContextStrip(
                pets: store.state.pets,
                selectedID: store.state.selectedPetID,
                onSelect: store.selectPet,
                onEdit: store.editSelectedPet,
                onOpenProfiles: store.openPetProfiles
            )

        case .pureLensFeature:
            if #available(iOS 16.0, *), let pureLensAction {
                HomePureLensSection(
                    motionReady: pureLensContentMotionReady,
                    motionAlreadyPlayed: pureLensSignalStoryPlayed,
                    onMotionSettled: {
                        pureLensSignalStoryPlayed = true
                    },
                    action: pureLensAction
                )
                .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
                .modifier(HomePureLensMotionGate(
                    homeEntranceAlreadyPresented: loadedEntranceVisible,
                    sectionIndex: sectionIndex,
                    isReady: $pureLensContentMotionReady
                ))
            }
        }
    }

    // MARK: Zone 2

    @ViewBuilder
    private func marketingStage(_ source: PPHomeMarketingSource) -> some View {
        switch source {
        case .petContext:
            // `HomeStore` already owns rotation for these pages, so the stage
            // never starts a second timer for them.
            marketingStageComposition(
                pages: store.state.heroPages,
                selectedIndex: store.state.selectedHeroIndex,
                discloseCampaign: false,
                onSelect: store.selectHero,
                onPrimary: store.performHeroAction,
                onSecondary: store.performHeroSecondaryAction,
                onInteractionChanged: store.setHeroInteractionActive
            )

        case .promotions:
            marketingStageComposition(
                pages: store.state.promotionPages,
                selectedIndex: store.promotionIndex,
                discloseCampaign: true,
                onSelect: store.selectPromotion,
                onPrimary: store.performHeroAction,
                onSecondary: store.performHeroSecondaryAction,
                onInteractionChanged: store.setPromotionInteractionActive
            )

        case .marketplace:
            if let page = store.state.marketplaceHeroPage {
                marketingStageComposition(
                    pages: [page],
                    selectedIndex: 0,
                    discloseCampaign: false,
                    marketplaceSignals: store.state.marketplaceSignals,
                    onSelect: { _ in },
                    onPrimary: store.performHeroAction,
                    onSecondary: store.performHeroSecondaryAction,
                    onInteractionChanged: { _ in },
                    onMarketplaceSignal: store.loadMarketplaceSignal
                )
            }
        }
    }

    /// Single decision point for the Home hero composition.
    ///
    /// `PPHomeHeroFlags.UseHeroV2` selects between the V2 full-bleed reference
    /// composition and the shipped `PPHomeMarketingStage` card. Both branches
    /// receive identical page data and identical store callbacks, so flipping
    /// the flag changes presentation only — never state, navigation, or the
    /// marketplace signal contract.
    @ViewBuilder
    private func marketingStageComposition(
        pages: [HomeHeroPage],
        selectedIndex: Int,
        discloseCampaign: Bool,
        marketplaceSignals: HomeMarketplaceSignals = HomeMarketplaceSignals(),
        onSelect: @escaping (Int) -> Void,
        onPrimary: @escaping (HomeHeroPage) -> Void,
        onSecondary: @escaping (HomeHeroPage) -> Void,
        onInteractionChanged: @escaping (Bool) -> Void,
        onMarketplaceSignal: @escaping (HomeMarketplaceSignalKind) -> Void = { _ in }
    ) -> some View {
        if PPHomeHeroFlags.UseHeroV2 {
            HomeHeroV2Stage(
                pages: pages,
                selectedIndex: selectedIndex,
                discloseCampaign: discloseCampaign,
                marketplaceSignals: marketplaceSignals,
                onSelect: onSelect,
                onPrimary: onPrimary,
                onSecondary: onSecondary,
                onInteractionChanged: onInteractionChanged,
                onMarketplaceSignal: onMarketplaceSignal
            )
        } else {
            PPHomeMarketingStage(
                pages: pages,
                selectedIndex: selectedIndex,
                discloseCampaign: discloseCampaign,
                marketplaceSignals: marketplaceSignals,
                onSelect: onSelect,
                onPrimary: onPrimary,
                onSecondary: onSecondary,
                onInteractionChanged: onInteractionChanged,
                onMarketplaceSignal: onMarketplaceSignal
            )
        }
    }

    // MARK: Zone 5 helpers

    @ViewBuilder
    private func partnerFeature(_ source: PPHomeMarketingSource) -> some View {
        switch source {
        case .promotions:
            PPHomePartnerFeature(
                pages: store.state.promotionPages,
                discloseCampaign: true,
                onPrimary: store.performHeroAction
            )
        case .marketplace:
            if let page = store.state.marketplaceHeroPage {
                PPHomePartnerFeature(
                    pages: [page],
                    discloseCampaign: false,
                    onPrimary: store.performHeroAction
                )
            }
        case .petContext:
            EmptyView()
        }
    }

    private func careGateway(
        _ variant: PPHomeCareGatewayVariant
    ) -> some View {
        PPHomeServiceGateway(
            // No eyebrow: the care gateway is the only banded row, and brand
            // text measures 4.45:1 on the dark section band. The title already
            // carries the same meaning.
            eyebrow: nil,
            title: variant == .premiumCare
                ? PPHomeZoneCopy.careGatewayTitle
                : HomeModelAdapter.localized(
                    "home_provider_navigation_title",
                    fallback: "Trusted care"
                ),
            subtitle: variant == .premiumCare
                ? PPHomeZoneCopy.careGatewaySubtitle
                : HomeModelAdapter.localized(
                    "home_provider_navigation_subtitle",
                    fallback: "Choose the care destination you need"
                ),
            destinations: careDestinations,
            onSelect: { destination in
                store.openProviderCategory(destination.id)
            }
        )
    }

    private var careDestinations: [PPHomeServiceDestination] {
        [
            PPHomeServiceDestination(
                id: "veterinarians",
                title: HomeModelAdapter.localized(
                    "provider_vets_title",
                    fallback: "Veterinarians"
                ),
                subtitle: HomeModelAdapter.localized(
                    "provider_vets_subtitle",
                    fallback: ""
                ),
                symbol: "stethoscope",
                accent: HomeSemanticTone.health
            ),
            PPHomeServiceDestination(
                id: "pharmacy",
                title: HomeModelAdapter.localized(
                    "provider_pharmacies_title",
                    fallback: "Pharmacies"
                ),
                subtitle: HomeModelAdapter.localized(
                    "provider_pharmacies_subtitle",
                    fallback: ""
                ),
                symbol: "cross.case.fill",
                accent: HomeSemanticTone.health
            ),
        ]
    }

    // MARK: Explore more

    /// Every bounded-out module, rendered through the destination the resolver
    /// already proved reachable. Duplicated destinations collapse to one entry.
    private func exploreMoreEntries(
        for resolvedPlan: PPHomePresentationPlan
    ) -> [PPHomeExploreMoreRow.Entry] {
        var seen = Set<String>()
        var entries: [PPHomeExploreMoreRow.Entry] = []

        for suppressed in resolvedPlan.suppressedModules {
            guard let entry = exploreEntry(for: suppressed) else { continue }
            guard seen.insert(destinationKey(suppressed.destination)).inserted
            else { continue }
            entries.append(entry)
        }
        return entries
    }

    private func destinationKey(
        _ destination: PPHomeSuppressedDestination
    ) -> String {
        switch destination {
        case let .commerceSeeAll(kind): return "see-all-\(kind.rawValue)"
        case .marketplaceCampaign: return "marketplace"
        case .careGateway: return "care"
        case .adoption: return "adoption"
        case .petProfiles: return "pets"
        case .orderHistory: return "orders"
        case .search: return "search"
        }
    }

    private func exploreEntry(
        for suppressed: PPHomeSuppressedModule
    ) -> PPHomeExploreMoreRow.Entry? {
        switch suppressed.destination {
        case let .commerceSeeAll(kind):
            let title = store.state.sections
                .first { $0.kind == kind }?
                .title ?? PPHomeZoneCopy.exploreMarketplace
            return PPHomeExploreMoreRow.Entry(
                id: suppressed.rawID,
                title: title,
                symbol: symbol(for: kind),
                action: { store.seeAll(kind) }
            )
        case .marketplaceCampaign:
            return PPHomeExploreMoreRow.Entry(
                id: suppressed.rawID,
                title: PPHomeZoneCopy.exploreMarketplace,
                symbol: "bag.fill",
                action: store.exploreMarketplace
            )
        case .careGateway:
            return PPHomeExploreMoreRow.Entry(
                id: suppressed.rawID,
                title: PPHomeZoneCopy.careGatewayTitle,
                symbol: "stethoscope",
                action: { store.openProviderCategory("veterinarians") }
            )
        case .adoption:
            return PPHomeExploreMoreRow.Entry(
                id: suppressed.rawID,
                title: PPHomeZoneCopy.adoption,
                symbol: "heart.fill",
                action: store.openAdoption
            )
        case .petProfiles:
            return PPHomeExploreMoreRow.Entry(
                id: suppressed.rawID,
                title: PPHomeZoneCopy.myPet,
                symbol: "pawprint.fill",
                action: store.openPetProfiles
            )
        case .orderHistory:
            return PPHomeExploreMoreRow.Entry(
                id: suppressed.rawID,
                title: PPHomeZoneCopy.orders,
                symbol: "shippingbox.fill",
                action: { store.seeAll(.currentOrder) }
            )
        case .search:
            return PPHomeExploreMoreRow.Entry(
                id: suppressed.rawID,
                title: PPHomeZoneCopy.search,
                symbol: "magnifyingglass",
                action: store.router.openSearch
            )
        }
    }

    private func symbol(for kind: HomeSectionID) -> String {
        switch kind {
        case .currentOrder: return "shippingbox.fill"
        case .buyAgain: return "arrow.counterclockwise"
        case .recommendations: return "sparkles"
        case .accessories: return "bag.fill"
        case .advertisements: return "megaphone.fill"
        case .food: return "cart.fill"
        case .nearbyAdvertisements: return "location.fill"
        case .services: return "wrench.and.screwdriver.fill"
        }
    }

    // MARK: Loading / empty

    private var loadingContent: some View {
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.sectionTopSpacing
        ) {
            PPHomeMarketingStage(
                pages: [],
                selectedIndex: 0,
                discloseCampaign: false,
                onSelect: { _ in },
                onPrimary: { _ in },
                onSecondary: { _ in },
                onInteractionChanged: { _ in }
            )
            .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)

            PPHomeEcosystemLauncher(
                featuredAction: nil,
                featuredPet: nil,
                actions: placeholderActions,
                onSelect: { _ in }
            )
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)

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
            .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
        }
        .padding(.vertical, PPSpace.lg)
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
                actionTitle: PPHomeZoneCopy.exploreMarketplace,
                action: store.exploreMarketplace
            )
        }
        .padding(.horizontal, HomeVisualTokens.contentHorizontalMargin)
        .padding(.vertical, PPSpace.xl)
        .homeEntrance(
            isVisible: loadedEntranceVisible,
            delay: 0.05,
            reduceMotion: reduceMotion
        )
        .onAppear(perform: startLoadedEntranceIfNeeded)
    }

    // MARK: Chrome

    private var background: some View {
        WorldGlassBackground(
            isFaded: store.state.config.backgroundGlowsFaded
        )
    }

    private var bottomNavigationFade: some View {
        GeometryReader { proxy in
            let fadeHeight = max(
                store.state.bottomContentClearance,
                proxy.safeAreaInsets.bottom
            ) + PPSpace.xxxl

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.homeCanvas.opacity(0.58),
                    Color.homeCanvas,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One rhythm break for the whole page. The care gateway features a NextGen V6
    /// organic transition band that flows seamlessly into the discovery marketplace.
    @ViewBuilder
    private func rowBackground(for row: HomeRenderRow) -> some View {
        Color.clear
    }

    private func reloadAccent(for row: HomeRenderRow) -> Color {
        guard case let .module(module) = row.content else { return .homeBrand }
        switch module.kind {
        case .discoveryRail, .commerceRail, .partnerFeature, .marketingStage:
            return selectedMainKindAccent
        case .petContext, .ecosystemLauncher:
            return .homeStatusSuccess
        case .careGateway:
            return .homeVeterinary
        case .livePriorityOrder, .livePriorityCare:
            return .homeFocus
        case .adoptionGateway:
            return Color.ppAdoptionAccent
        case .pureLensFeature, .discoveryPrompt:
            return .homeBrand
        }
    }

    private func verticalPadding(for row: HomeRenderRow) -> CGFloat {
        guard case let .module(module) = row.content else {
            return HomeVisualTokens.routineRowSpacing
        }
        switch module.kind {
        case .discoveryRail:
            return HomeVisualTokens.compactRowSpacing
        case .marketingStage:
            return PPHomeHeroFlags.UseHeroV2
                ? PPSpace.xxs
                : HomeVisualTokens.mediaRowSpacing
        default:
            return HomeVisualTokens.routineRowSpacing
        }
    }

    /// Preserve every row's existing bottom breathing room while making the
    /// visible break before each standalone heading token-defined. The
    /// adjustment is derived from the preceding row, so Console-driven section
    /// ordering cannot change the header rhythm.
    private func topPadding(
        for row: HomeRenderRow,
        after previousRow: HomeRenderRow?
    ) -> CGFloat {
        guard let previousRow else {
            return 0
        }
        if case let .module(prevModule) = previousRow.content,
           case .marketingStage = prevModule.kind,
           PPHomeHeroFlags.UseHeroV2 {
            // Tighter space directly beneath Hero V2
            return PPSpace.xs
        }
        guard hasStandaloneSectionHeader(row) else {
            return verticalPadding(for: row)
        }

        let precedingBottom = verticalPadding(for: previousRow)
        return max(
            0,
            PPHomeSectionHeaderMetrics.sectionTopSpacing - precedingBottom
        )
    }

    private func hasStandaloneSectionHeader(_ row: HomeRenderRow) -> Bool {
        switch row.content {
        case .exploreMore:
            return true
        case let .module(module):
            switch module.kind {
            case .ecosystemLauncher,
                 .livePriorityOrder,
                 .discoveryRail,
                 .commerceRail,
                 .partnerFeature,
                 .careGateway,
                 .petContext:
                return true
            case .discoveryPrompt,
                 .marketingStage,
                 .livePriorityCare,
                 .adoptionGateway,
                 .pureLensFeature:
                return false
            }
        }
    }

    private var isCategoryAccentEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: "pp.marketplace.usesMainKindAccentColors"
        )
    }

    private var activeHomeAccent: Color? {
        guard isCategoryAccentEnabled else { return nil }
        guard let selectedID = store.state.selectedMainKindID,
              let category = store.state.categories.first(where: {
                  HomeModelAdapter.mainKindID($0.raw) == selectedID
              })
        else {
            return nil
        }
        return Color(uiColor: category.accent)
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

    private var bottomPadding: CGFloat {
        // The root dock clearance already includes its measured height and
        // physical bottom inset. Keep only a small visual breathing room here;
        // adding a second navigation reserve creates the empty tail below the
        // final Home row.
        max(0, store.state.bottomContentClearance) + PPSpace.base
    }

    private func startLoadedEntranceIfNeeded() {
        guard !loadedEntranceVisible else { return }
        // Commit on the next run loop so the initial visible rows are already
        // in their staged pose before the one-shot phase changes.
        DispatchQueue.main.async {
            guard !loadedEntranceVisible else { return }
            loadedEntranceVisible = true
        }
    }

    private var placeholderFeaturedAction: HomePriorityAction {
        placeholderAction(id: "pet")
    }

    private var placeholderActions: [HomePriorityAction] {
        ["shop", "food", "ads", "vet", "pharmacy", "services"].map {
            placeholderAction(id: $0)
        }
    }

    private func placeholderAction(id: String) -> HomePriorityAction {
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

/// Shared Nova affordance, rendered by `HomeCommandBar`. It uses the same
/// squircle, surface, and border vocabulary as the other command-surface
/// controls so the bar reads as one system rather than four styles.
@available(iOS 15.0, *)
struct HomeHeaderSparkleMotion: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(
                .system(
                    size: 18,
                    weight: HomeVisualTokens.commandIconWeight
                )
            )
            .foregroundStyle(Color.ppAdoptionAccent)
            .scaleEffect(reduceMotion ? 1.0 : (isAnimating ? 1.08 : 0.96))
            .opacity(reduceMotion ? 1.0 : (isAnimating ? 1.0 : 0.86))
            .frame(
                width: HomeCommandBar.controlSide,
                height: HomeCommandBar.controlSide
            )
            .background(HomeCommandBar.controlShape.fill(Color.homeSurface))
            .overlay {
                HomeCommandBar.controlShape.stroke(
                    Color.ppAdoptionAccent.opacity(
                        contrast == .increased ? 0.5 : 0.18
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .contentShape(HomeCommandBar.controlShape)
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
                cornerGlowOpacityScale: 0.50,
                cornerRadius: PPCorner.card
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
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
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

/// Selects exactly one section-entrance owner. The ecosystem launcher uses its
/// quieter product-specific settle, and the marketplace Living Ledger uses its
/// category-bound internal reveal. Every other Home row keeps the established
/// initial and viewport entrance behavior unchanged.
private struct HomeResolvedSectionEntranceModifier: ViewModifier {
    let isVisible: Bool
    let sectionIndex: Int
    let reduceMotion: Bool
    let usesEcosystemMotion: Bool
    let usesIndependentContentMotion: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if usesIndependentContentMotion {
            content
        } else if usesEcosystemMotion {
            content.modifier(
                HomeEcosystemEntranceModifier(
                    isVisible: isVisible,
                    sectionIndex: sectionIndex,
                    reduceMotion: reduceMotion
                )
            )
        } else {
            content
                .modifier(HomeSectionEntranceModifier(
                    isVisible: isVisible,
                    sectionIndex: sectionIndex,
                    reduceMotion: reduceMotion
                ))
                .modifier(HomeVerticalSectionReveal(
                    entranceAlreadyPlayed: isVisible
                ))
        }
    }
}

/// A single restrained entrance for the connected ecosystem surface.
///
/// It replaces, rather than layers over, Home's generic scale-and-rise reveal:
/// opacity plus an 8pt vertical settle communicate hierarchy without making a
/// five-action navigation surface feel unstable. Home's existing loaded-state
/// visibility is the sole entrance driver; accessibility and lifecycle changes
/// move the phase to rest without starting a second animation owner.
private struct HomeEcosystemEntranceModifier: ViewModifier {
    let isVisible: Bool
    let sectionIndex: Int
    let reduceMotion: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @State private var settledAfterDisappearance = false

    func body(content: Content) -> some View {
        let currentPhase = phase
        return content
            .opacity(currentPhase == .staged ? 0 : 1)
            .offset(y: currentPhase == .staged ? 8 : 0)
            .animation(
                currentPhase == .presented ? entranceAnimation : nil,
                value: currentPhase
            )
            .onDisappear(perform: settleAfterDisappearance)
    }

    private var phase: Phase {
        if motionSuppressed { return .settled }
        return isVisible ? .presented : .staged
    }

    private var motionSuppressed: Bool {
        reduceMotion ||
            voiceOverEnabled ||
            switchControlEnabled ||
            scenePhase != .active ||
            settledAfterDisappearance
    }

    private var entranceAnimation: Animation {
        .spring(
            response: 0.34,
            dampingFraction: 0.90,
            blendDuration: 0.04
        )
        .delay(HomeSectionEntranceMotion.staggerDelay(
            sectionIndex: sectionIndex
        ))
    }

    private func settleAfterDisappearance() {
        guard !settledAfterDisappearance else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            settledAfterDisappearance = true
        }
    }

    private enum Phase: Equatable {
        case staged
        case presented
        case settled
    }
}

// MARK: - HomeVerticalSectionReveal — willDisplaySection equivalent

/// A quiet, native scroll-in settle for sections inside the vertical Home feed.
///
/// `LazyVStack` viewport appearances do not need a second spatial transition:
/// the scroll view already provides it. Rows that arrive after the initial load
/// therefore crossfade once, avoiding scale/offset springs that compete with
/// sticky chrome and continuous scrolling. The first loaded pass remains owned
/// by `HomeSectionEntranceModifier`.
private struct HomeVerticalSectionReveal: ViewModifier {
    let entranceAlreadyPlayed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(opacityValue)
            .animation(revealAnimation, value: revealed)
            .onAppear { handleAppear() }
    }

    private var opacityValue: Double {
        guard entranceAlreadyPlayed else { return 1 }
        return revealed ? 1 : 0
    }

    private var revealAnimation: Animation {
        guard entranceAlreadyPlayed else { return .linear(duration: 0) }
        return .easeOut(duration: reduceMotion ? 0.16 : 0.20)
    }

    private func handleAppear() {
        guard !revealed else { return }
        if !entranceAlreadyPlayed {
            // Initial entrance window — HomeSectionEntranceModifier owns this.
            revealed = true
            return
        }
        // Defer one run-loop so the staged opacity is committed first.
        DispatchQueue.main.async {
            guard !revealed else { return }
            revealed = true
        }
    }
}

/// Releases the Pure Lens readiness resolve only after this configured Home row
/// reaches its stable pose. The structured task cancels if the section leaves.
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
    static let response: Double = 0.20
    /// Mirrors the short opacity settle before Pure Lens starts its own work.
    static let settlementBuffer: Double = 0.06

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
                .padding(.leading, HomeVisualTokens.contentHorizontalMargin)
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

extension View {
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

    func homeResolvedSectionEntrance(
        isVisible: Bool,
        sectionIndex: Int,
        reduceMotion: Bool,
        usesEcosystemMotion: Bool,
        usesIndependentContentMotion: Bool = false
    ) -> some View {
        modifier(HomeResolvedSectionEntranceModifier(
            isVisible: isVisible,
            sectionIndex: sectionIndex,
            reduceMotion: reduceMotion,
            usesEcosystemMotion: usesEcosystemMotion,
            usesIndependentContentMotion: usesIndependentContentMotion
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
