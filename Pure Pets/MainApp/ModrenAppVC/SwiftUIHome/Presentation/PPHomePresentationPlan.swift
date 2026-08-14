import Foundation

// MARK: - Registry

/// Stable raw Home section identifiers owned by `AppConfigCol/HomeConfig`.
///
/// These integers are the persisted Console contract. They are declared once
/// here so the resolver, the renderer, and the tests all read the same registry
/// instead of repeating literals. No identifier is renamed, reused, or
/// reinterpreted.
enum PPHomeSectionRegistry {
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
    static let pureLens = 20

    /// Every identifier this renderer can present. Anything else is retained
    /// with its original identity and deliberately not rendered.
    static let supported: Set<Int> = [
        hero, quickActions, currentOrders, carousel, mainKinds, suggestions,
        accessories, petProfile, premiumCare, lastFood, nearbyServices,
        adsNearby, adopt, buyAgain, premiumSearch, providerCategoryNav,
        marketplaceHero, suggestionAds, suggestionAccessories, pureLens,
    ]

    /// Identifiers that can legitimately own the single Marketing Stage.
    /// Arbitration between them is decided by server order, never by this list.
    static let marketingCapable: Set<Int> = [hero, carousel, marketplaceHero]

    /// Identifiers that can own the single Live Priority slot. The operational
    /// order candidate always outranks the care-reminder candidate (rule 5a).
    static let livePriorityCapable: Set<Int> = [currentOrders, hero]

    /// Identifiers that resolve to the same veterinary/pharmacy destinations.
    static let careGatewayCapable: Set<Int> = [premiumCare, providerCategoryNav]
}

// MARK: - Presentation limits

/// Home presentation maximums. These are product bounds on the *presentation*,
/// never on the configured content: anything beyond a bound is mapped to an
/// existing reachable destination instead of being discarded.
enum PPHomePresentationLimits {
    static let marketingStages = 1
    static let livePriorityItems = 1
    /// Total launcher capacity used by adoption-gateway arbitration.
    static let ecosystemLauncherActions = 5
    /// Four compact destinations sit beside the leading My Pet tile.
    static let ecosystemLauncherSecondaryActions = 4
    static let commerceRails = 3
    static let partnerFeatures = 1
}

// MARK: - Plan model

enum PPHomeZoneID: String, CaseIterable, Hashable {
    case commandSurface
    case marketingStage
    case ecosystemLauncher
    case livePriority
    case commerceDiscovery
}

/// Which real content lane owns a marketing or partner treatment.
enum PPHomeMarketingSource: Equatable {
    /// Raw section `0` — pet/reminder context pages owned by `HomeStore`.
    case petContext
    /// Raw section `4` — Console promotion carousel campaigns.
    case promotions
    /// Raw section `17` — the marketplace campaign lane.
    case marketplace
}

/// Temporary, reversible presentation switches. Each one is a single boolean
/// with a documented restore path; none removes a module, a route, a Console
/// contract, or any code.
enum PPHomePresentationFlags {
    /// TEMPORARY: keeps the command surface on its single compact lane, so the
    /// dedicated Home search lane stays hidden. Raw section `15` is still
    /// resolved, still accounted for by the resolver invariants, and search is
    /// still reachable from the command bar's compact control.
    ///
    /// Set to `false` to restore the spotlight search lane. Nothing else needs
    /// to change.
    static let temporarilyHidesSearchLane = true

    /// Keeps the Nova affordance out of the pinned command surface. Nova itself
    /// is untouched: `NovaAmbientAssistantCoordinator` and the root
    /// `handleOpenNovaChat()` path remain its live entry points, and
    /// `HomeRouter.openNova()` is still wired.
    ///
    /// Set to `false` to put Nova back in the command surface.
    static let hidesNovaInCommandSurface = true

    /// Destinations the ecosystem launcher's bounded bands deliberately omit.
    /// Every excluded destination must stay reachable through a dedicated
    /// presentation slot or another Home module.
    ///
    /// `pet` owns the launcher's separate featured slot rather than displacing
    /// one of the five band destinations. Raw section `8` also retains the pet
    /// context strip and its `.petProfiles` route.
    static let launcherExcludedActionIDs: Set<String> = ["pet"]
}

/// How prominently the pinned command surface presents search. Raw section `15`
/// no longer renders a separate Home search row: it upgrades the command bar's
/// own search treatment instead, so Home never shows two search affordances.
enum PPHomeSearchProminence: Equatable {
    case compact
    case spotlight
}

enum PPHomeCareGatewayVariant: Equatable {
    case premiumCare
    case providerNavigation
}

enum PPHomeModuleKind: Equatable {
    case discoveryPrompt
    case marketingStage(PPHomeMarketingSource)
    case ecosystemLauncher
    case livePriorityOrder
    case livePriorityCare
    case discoveryRail
    case commerceRail(HomeSectionID)
    case partnerFeature(PPHomeMarketingSource)
    case careGateway(PPHomeCareGatewayVariant)
    case adoptionGateway
    case petContext
    case pureLensFeature
}

/// One presentation module. `rawID` and `type` are the untouched Console
/// identity; `kind` is presentation only.
struct PPHomeModule: Identifiable, Equatable {
    let rawID: Int
    let type: String
    let kind: PPHomeModuleKind

    var id: Int { rawID }
}

struct PPHomeZone: Identifiable, Equatable {
    let id: PPHomeZoneID
    let modules: [PPHomeModule]

    var isEmpty: Bool { modules.isEmpty }
}

/// An existing, already reachable destination for a module the presentation
/// bounded out. Every value maps onto a route the production router already
/// owns; no new destination is invented here.
enum PPHomeSuppressedDestination: Equatable {
    case commerceSeeAll(HomeSectionID)
    case marketplaceCampaign
    case careGateway
    case adoption
    case petProfiles
    case orderHistory
    case search
}

struct PPHomeSuppressedModule: Identifiable, Equatable {
    let rawID: Int
    let type: String
    let destination: PPHomeSuppressedDestination

    var id: Int { rawID }
}

/// The complete, deterministic Home presentation plan.
struct PPHomePresentationPlan: Equatable {
    let zones: [PPHomeZone]

    /// Configured-but-hidden identifiers. Retained for diagnostics; never
    /// rendered. Their raw model identity is untouched.
    let hiddenModuleIDs: [Int]

    /// Configured identifiers this renderer has no component for. Retained
    /// with their original identity and never reinterpreted as another module.
    let retainedUnknownModuleIDs: [Int]

    /// Modules the presentation bounded out, each with an existing reachable
    /// destination so nothing configured becomes unreachable.
    let suppressedModules: [PPHomeSuppressedModule]

    /// Bounded-out identifiers with no valid existing destination. A non-empty
    /// value is a reportable configuration conflict, not silent data loss.
    let unmappedSuppressedModuleIDs: [Int]

    static let empty = PPHomePresentationPlan(
        zones: [],
        hiddenModuleIDs: [],
        retainedUnknownModuleIDs: [],
        suppressedModules: [],
        unmappedSuppressedModuleIDs: []
    )

    func zone(_ identifier: PPHomeZoneID) -> PPHomeZone? {
        zones.first { $0.id == identifier }
    }

    func modules(in identifier: PPHomeZoneID) -> [PPHomeModule] {
        zone(identifier)?.modules ?? []
    }

    var allModules: [PPHomeModule] {
        zones.flatMap(\.modules)
    }

    func containsModule(rawID: Int) -> Bool {
        allModules.contains { $0.rawID == rawID }
    }

    func module(rawID: Int) -> PPHomeModule? {
        allModules.first { $0.rawID == rawID }
    }

    var isEmpty: Bool {
        zones.allSatisfy(\.isEmpty)
    }

    /// Resolved from the command-surface zone. `spotlight` when the Console has
    /// enabled the premium search module, `compact` otherwise.
    ///
    /// `PPHomePresentationFlags.temporarilyHidesSearchLane` pins this to
    /// `compact` while the dedicated search lane is intentionally hidden.
    var searchProminence: PPHomeSearchProminence {
        guard !PPHomePresentationFlags.temporarilyHidesSearchLane else {
            return .compact
        }
        return modules(in: .commandSurface)
            .contains { $0.kind == .discoveryPrompt }
            ? .spotlight
            : .compact
    }
}

// MARK: - Resolver

/// Pure, deterministic Home presentation resolver.
///
/// Contract:
/// - Input is `HomeViewState` only (which already carries `HomeConfigModel`).
/// - It owns no fetching, listener, persistence, routing, analytics, or
///   business mutation.
/// - Identical input always produces identical zones and identical module IDs.
///
/// Precedence, frozen before implementation and pinned by
/// `PPHomePresentationResolverTests`:
///  1. Remove hidden or unsupported modules without changing their raw model
///     identity.
///  2. Preserve the Console-provided order exactly *within* each zone. Zone
///     precedence itself is the product hierarchy (command surface → marketing
///     → ecosystem → live priority → commerce/discovery).
///  3. Explicit backend priority metadata is *not* consulted: no field in
///     `HomeConfig` has a proven ranking meaning in source, and none is
///     invented here.
///  4. User/application state is used only for eligibility (does a pet, order,
///     campaign, coordinate, or card actually exist), never as a new ranking
///     signal.
///  5. Each bounded slot takes the first eligible candidate in server order.
///  5a. The Live Priority slot prefers the operational order candidate over the
///     care-reminder candidate. This is not a taste ranking: only the order
///     represents a transaction the user has already committed to, and the
///     reminder remains reachable through the pet context module.
///  6. Every remaining eligible module keeps its stable identity and original
///     relative order.
///  7. Every bounded-out module is mapped to an existing reachable
///     destination. When no valid destination exists the identifier is
///     reported in `unmappedSuppressedModuleIDs`.
///
/// The partner slot applies one extra, invariant-derived rule: when more than
/// one demoted marketing module competes for it, a candidate that has **no**
/// alternative reachable destination is preferred, because suppressing it would
/// otherwise violate rule 7. Ties break by server order. This is not a
/// subjective reordering of product value.
enum PPHomePresentationResolver {

    static func plan(for state: HomeViewState) -> PPHomePresentationPlan {
        let configured = state.config.sections

        // 1. Hidden and unsupported partitioning — raw identity preserved.
        var hidden: [Int] = []
        var retainedUnknown: [Int] = []
        var eligibleOrder: [HomeConfigSection] = []
        var seen = Set<Int>()

        for section in configured where seen.insert(section.id).inserted {
            guard section.isVisible else {
                hidden.append(section.id)
                continue
            }
            guard PPHomeSectionRegistry.supported.contains(section.id) else {
                retainedUnknown.append(section.id)
                continue
            }
            eligibleOrder.append(section)
        }

        var suppressed: [PPHomeSuppressedModule] = []
        var unmapped: [Int] = []

        func suppress(_ section: HomeConfigSection) {
            if let destination = suppressedDestination(
                for: section.id,
                state: state
            ) {
                suppressed.append(
                    PPHomeSuppressedModule(
                        rawID: section.id,
                        type: section.type,
                        destination: destination
                    )
                )
            } else {
                unmapped.append(section.id)
            }
        }

        // 2. Marketing stage — first eligible marketing-capable module.
        let marketingCandidates = eligibleOrder.filter {
            PPHomeSectionRegistry.marketingCapable.contains($0.id)
                && isMarketingEligible($0.id, state: state)
        }
        let stageSection = marketingCandidates.first
        let demotedMarketing = marketingCandidates.dropFirst()

        // 3. Partner slot among demoted campaign modules. Pet context is never
        //    a partner treatment, so it is excluded from this competition.
        let partnerSection = preferredPartnerSection(
            from: demotedMarketing.filter {
                $0.id != PPHomeSectionRegistry.hero
            },
            state: state
        )

        // 4. Live priority — operational order first, care reminder second, and
        //    never the module that already owns the marketing stage.
        let orderCandidate = eligibleOrder.first {
            $0.id == PPHomeSectionRegistry.currentOrders
                && $0.id != stageSection?.id
                && isLivePriorityEligible($0.id, state: state)
        }
        let careCandidate = eligibleOrder.first {
            $0.id == PPHomeSectionRegistry.hero
                && $0.id != stageSection?.id
                && isLivePriorityEligible($0.id, state: state)
        }
        let livePrioritySection = orderCandidate ?? careCandidate

        // 5. Ecosystem launcher.
        let launcherSection = eligibleOrder.first {
            $0.id == PPHomeSectionRegistry.quickActions
                && !state.priorityActions.isEmpty
        }
        let launcherHasFreeSlot =
            launcherSection != nil
            && state.priorityActions.count
                < PPHomePresentationLimits.ecosystemLauncherActions

        // 6. Single care gateway among the duplicate care destinations.
        let careSection = eligibleOrder.first {
            PPHomeSectionRegistry.careGatewayCapable.contains($0.id)
        }

        // 7. Commerce rails, bounded, in server order.
        let railSections = eligibleOrder.filter { section in
            state.sections.contains { $0.id == section.id }
        }
        let presentedRailIDs = Set(
            railSections
                .prefix(PPHomePresentationLimits.commerceRails)
                .map(\.id)
        )

        var commandModules: [PPHomeModule] = []
        var marketingModules: [PPHomeModule] = []
        var launcherModules: [PPHomeModule] = []
        var livePriorityModules: [PPHomeModule] = []
        var commerceModules: [PPHomeModule] = []

        for section in eligibleOrder {
            switch section.id {
            case PPHomeSectionRegistry.premiumSearch:
                commandModules.append(
                    PPHomeModule(
                        rawID: section.id,
                        type: section.type,
                        kind: .discoveryPrompt
                    )
                )

            case PPHomeSectionRegistry.quickActions:
                if section.id == launcherSection?.id {
                    launcherModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .ecosystemLauncher
                        )
                    )
                } else {
                    suppress(section)
                }

            case PPHomeSectionRegistry.hero,
                 PPHomeSectionRegistry.carousel,
                 PPHomeSectionRegistry.marketplaceHero:
                if section.id == stageSection?.id,
                   let source = marketingSource(for: section.id) {
                    marketingModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .marketingStage(source)
                        )
                    )
                } else if section.id == livePrioritySection?.id {
                    livePriorityModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .livePriorityCare
                        )
                    )
                } else if section.id == partnerSection?.id,
                          let source = marketingSource(for: section.id) {
                    commerceModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .partnerFeature(source)
                        )
                    )
                } else {
                    suppress(section)
                }

            case PPHomeSectionRegistry.currentOrders:
                if section.id == livePrioritySection?.id {
                    livePriorityModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .livePriorityOrder
                        )
                    )
                } else {
                    suppress(section)
                }

            case PPHomeSectionRegistry.mainKinds:
                if state.categories.isEmpty {
                    suppress(section)
                } else {
                    commerceModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .discoveryRail
                        )
                    )
                }

            case PPHomeSectionRegistry.pureLens:
                if state.config.pureLensVisible {
                    commerceModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .pureLensFeature
                        )
                    )
                } else {
                    hidden.append(section.id)
                }

            case PPHomeSectionRegistry.premiumCare,
                 PPHomeSectionRegistry.providerCategoryNav:
                if section.id == careSection?.id {
                    commerceModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .careGateway(
                                section.id == PPHomeSectionRegistry.premiumCare
                                    ? .premiumCare
                                    : .providerNavigation
                            )
                        )
                    )
                } else {
                    suppress(section)
                }

            case PPHomeSectionRegistry.adopt:
                if launcherHasFreeSlot {
                    // Consumed by the ecosystem launcher; the standalone
                    // gateway would duplicate the same single destination.
                    suppress(section)
                } else {
                    commerceModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .adoptionGateway
                        )
                    )
                }

            case PPHomeSectionRegistry.petProfile:
                commerceModules.append(
                    PPHomeModule(
                        rawID: section.id,
                        type: section.type,
                        kind: .petContext
                    )
                )

            default:
                guard let rail = state.sections.first(where: {
                    $0.id == section.id
                }) else {
                    suppress(section)
                    continue
                }
                if presentedRailIDs.contains(section.id) {
                    commerceModules.append(
                        PPHomeModule(
                            rawID: section.id,
                            type: section.type,
                            kind: .commerceRail(rail.kind)
                        )
                    )
                } else {
                    suppressed.append(
                        PPHomeSuppressedModule(
                            rawID: section.id,
                            type: section.type,
                            destination: .commerceSeeAll(rail.kind)
                        )
                    )
                }
            }
        }

        let zones = [
            PPHomeZone(id: .commandSurface, modules: commandModules),
            PPHomeZone(id: .marketingStage, modules: marketingModules),
            PPHomeZone(id: .ecosystemLauncher, modules: launcherModules),
            PPHomeZone(id: .livePriority, modules: livePriorityModules),
            PPHomeZone(id: .commerceDiscovery, modules: commerceModules),
        ]

        return PPHomePresentationPlan(
            zones: zones,
            hiddenModuleIDs: hidden,
            retainedUnknownModuleIDs: retainedUnknown,
            suppressedModules: suppressed,
            unmappedSuppressedModuleIDs: unmapped
        )
    }

    /// Bento secondary actions, bounded and in their existing priority order.
    /// The featured pet action is resolved separately, while lower-priority
    /// actions remain in the source model and keep their other entry points.
    static func ecosystemLauncherActions(
        for state: HomeViewState,
        plan: PPHomePresentationPlan
    ) -> [HomePriorityAction] {
        guard plan.containsModule(rawID: PPHomeSectionRegistry.quickActions)
        else { return [] }
        return Array(
            state.priorityActions
                .filter {
                    !PPHomePresentationFlags.launcherExcludedActionIDs
                        .contains($0.id)
                }
                .prefix(
                    PPHomePresentationLimits
                        .ecosystemLauncherSecondaryActions
                )
        )
    }

    /// Existing My Pet action for the launcher's full-height featured slot.
    /// This returns the original model instance so destination, copy, accent,
    /// and callback behavior remain owned by `HomeStore`.
    static func ecosystemLauncherFeaturedAction(
        for state: HomeViewState,
        plan: PPHomePresentationPlan
    ) -> HomePriorityAction? {
        guard plan.containsModule(rawID: PPHomeSectionRegistry.quickActions)
        else { return nil }
        return state.priorityActions.first { $0.id == "pet" }
    }

    // MARK: Eligibility

    private static func isMarketingEligible(
        _ rawID: Int,
        state: HomeViewState
    ) -> Bool {
        switch rawID {
        case PPHomeSectionRegistry.hero:
            return !state.pets.isEmpty && !state.heroPages.isEmpty
        case PPHomeSectionRegistry.carousel:
            return !state.promotionPages.isEmpty
        case PPHomeSectionRegistry.marketplaceHero:
            return state.marketplaceHeroPage != nil
        default:
            return false
        }
    }

    private static func isLivePriorityEligible(
        _ rawID: Int,
        state: HomeViewState
    ) -> Bool {
        switch rawID {
        case PPHomeSectionRegistry.currentOrders:
            return state.featuredOrder != nil
        case PPHomeSectionRegistry.hero:
            // A genuine, already-enabled care reminder from real pet data.
            return state.heroPages.contains { $0.kind == .reminder }
        default:
            return false
        }
    }

    private static func marketingSource(
        for rawID: Int
    ) -> PPHomeMarketingSource? {
        switch rawID {
        case PPHomeSectionRegistry.hero: return .petContext
        case PPHomeSectionRegistry.carousel: return .promotions
        case PPHomeSectionRegistry.marketplaceHero: return .marketplace
        default: return nil
        }
    }

    /// Applies the reachability-derived partner preference described above.
    private static func preferredPartnerSection(
        from candidates: [HomeConfigSection],
        state: HomeViewState
    ) -> HomeConfigSection? {
        guard !candidates.isEmpty else { return nil }
        let withoutAlternative = candidates.first {
            suppressedDestination(for: $0.id, state: state) == nil
        }
        return withoutAlternative ?? candidates.first
    }

    // MARK: Suppressed destinations

    /// Existing reachable destination for a bounded-out module, or `nil` when
    /// the configuration genuinely has nowhere else to reach this content.
    private static func suppressedDestination(
        for rawID: Int,
        state: HomeViewState
    ) -> PPHomeSuppressedDestination? {
        switch rawID {
        case PPHomeSectionRegistry.premiumSearch:
            return .search
        case PPHomeSectionRegistry.hero,
             PPHomeSectionRegistry.petProfile:
            return .petProfiles
        case PPHomeSectionRegistry.carousel:
            // Promotion campaigns are only reachable through their own
            // presentation: they have no list or index destination in source.
            return nil
        case PPHomeSectionRegistry.marketplaceHero,
             PPHomeSectionRegistry.mainKinds:
            return .marketplaceCampaign
        case PPHomeSectionRegistry.currentOrders:
            return .orderHistory
        case PPHomeSectionRegistry.quickActions:
            return .marketplaceCampaign
        case PPHomeSectionRegistry.premiumCare,
             PPHomeSectionRegistry.providerCategoryNav:
            return .careGateway
        case PPHomeSectionRegistry.adopt:
            return .adoption
        default:
            if let rail = state.sections.first(where: { $0.id == rawID }) {
                return .commerceSeeAll(rail.kind)
            }
            return nil
        }
    }
}
