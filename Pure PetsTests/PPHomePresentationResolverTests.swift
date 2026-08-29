import CoreLocation
import UIKit
import XCTest
@testable import Pure_Pets

/// Pins the frozen resolver precedence. These assertions are the disproof tests
/// for the Home presentation contract: every bound, every suppression, and every
/// reachability guarantee is verified here, not inferred from the renderer.
final class PPHomePresentationResolverTests: XCTestCase {

    // MARK: Fixtures

    private func config(
        _ rows: [(id: Int, visible: Bool)],
        titleViewMode: String = "location",
        pureLensVisible: Bool = true,
        premiumCareVisible: Bool = true
    ) -> HomeConfigModel {
        HomeConfigModel(
            sections: rows.map {
                HomeConfigSection(
                    id: $0.id,
                    type: "PPHomeSection\($0.id)",
                    isVisible: $0.visible,
                    metadata: ["id": NSNumber(value: $0.id)]
                )
            },
            titleViewMode: titleViewMode,
            premiumCareVisible: premiumCareVisible,
            novaFloatingVisible: true,
            backgroundGlowsFaded: false,
            pureLensVisible: pureLensVisible,
            cameFromCache: false
        )
    }

    private func heroPage(
        id: String,
        kind: HomeHeroKind
    ) -> HomeHeroPage {
        HomeHeroPage(
            id: id,
            kind: kind,
            eyebrow: "eyebrow",
            title: "title",
            subtitle: "subtitle",
            primaryTitle: "primary",
            secondaryTitle: "secondary",
            imageURL: nil,
            localImage: nil,
            accentHex: "CB2654",
            action: .openPetProfiles
        )
    }

    private func pet(id: String) -> HomePetModel {
        HomePetModel(
            id: id,
            name: "Nour",
            breedOrCategory: "Cat",
            age: "2",
            imageURL: nil,
            categoryID: 1,
            isDefault: true,
            raw: NSObject()
        )
    }

    private func category(id: String) -> HomeCategoryModel {
        HomeCategoryModel(
            id: id,
            title: "Cats",
            imageURL: nil,
            heroImageURL: nil,
            localImage: nil,
            accent: .ppPrimary,
            raw: NSObject()
        )
    }

    private func order() -> HomeOrderModel {
        HomeOrderModel(
            id: "order-1",
            reference: "PP-1",
            statusKey: "pending",
            statusTitle: "Pending",
            statusHint: "hint",
            symbol: "shippingbox.fill",
            progress: 0.2,
            itemCount: 2,
            amount: "20",
            previewImageURLs: [],
            raw: NSObject()
        )
    }

    private func rail(
        id: Int,
        kind: HomeSectionID
    ) -> HomeSectionModel {
        HomeSectionModel(
            id: id,
            kind: kind,
            title: "rail-\(id)",
            subtitle: nil,
            seeAllTitle: "See all",
            rawConfigSectionID: id,
            state: .loading
        )
    }

    private func priorityAction(_ identifier: String) -> HomePriorityAction {
        HomePriorityAction(
            id: identifier,
            title: identifier,
            subtitle: identifier,
            systemImage: "pawprint.fill",
            accent: .ppPrimary,
            destination: .petProfile
        )
    }

    private func state(
        config: HomeConfigModel,
        heroPages: [HomeHeroPage] = [],
        promotionPages: [HomeHeroPage] = [],
        marketplaceHeroPage: HomeHeroPage? = nil,
        pets: [HomePetModel] = [],
        categories: [HomeCategoryModel] = [],
        priorityActions: [HomePriorityAction] = [],
        featuredOrder: HomeOrderModel? = nil,
        sections: [HomeSectionModel] = []
    ) -> HomeViewState {
        var value = HomeViewState.initial
        value.config = config
        value.heroPages = heroPages
        value.promotionPages = promotionPages
        value.marketplaceHeroPage = marketplaceHeroPage
        value.pets = pets
        value.categories = categories
        value.priorityActions = priorityActions
        value.featuredOrder = featuredOrder
        value.sections = sections
        return value
    }

    /// A fully populated production-shaped state using the real fallback order.
    private func populatedState() -> HomeViewState {
        var value = HomeViewState.initial
        value.config = .fallback
        value.heroPages = [
            heroPage(id: "pet-1", kind: .pet),
            heroPage(id: "reminder-1", kind: .reminder),
        ]
        value.promotionPages = [
            heroPage(id: "promotion-1", kind: .promotion),
            heroPage(id: "promotion-2", kind: .promotion),
        ]
        value.marketplaceHeroPage = heroPage(
            id: "home-marketplace-hero",
            kind: .marketplace
        )
        value.pets = [pet(id: "pet-1")]
        value.categories = [category(id: "main-kind-1")]
        value.priorityActions = ["pet", "shop", "ads", "pharmacy", "vet"]
            .map(priorityAction)
        value.featuredOrder = order()
        value.sections = [
            rail(id: 7, kind: .accessories),
            rail(id: 18, kind: .recommendations),
            rail(id: 19, kind: .recommendations),
            rail(id: 6, kind: .recommendations),
            rail(id: 10, kind: .food),
            rail(id: 12, kind: .nearbyAdvertisements),
            rail(id: 11, kind: .services),
            rail(id: 14, kind: .buyAgain),
        ]
        return value
    }

    // MARK: Determinism and identity

    func testIdenticalInputProducesIdenticalPlan() {
        let value = populatedState()
        let first = PPHomePresentationResolver.plan(for: value)
        let second = PPHomePresentationResolver.plan(for: value)
        XCTAssertEqual(first, second)
        XCTAssertEqual(
            first.allModules.map(\.rawID),
            second.allModules.map(\.rawID)
        )
    }

    func testEveryModulePreservesItsRawConsoleIdentity() {
        let plan = PPHomePresentationResolver.plan(for: populatedState())
        let configuredIDs = Set(HomeConfigModel.fallback.sections.map(\.id))
        for module in plan.allModules {
            XCTAssertTrue(
                configuredIDs.contains(module.rawID),
                "Presented module \(module.rawID) is not a configured identifier"
            )
            XCTAssertEqual(module.id, module.rawID)
        }
    }

    // MARK: Rule 1 — hidden never renders

    func testHiddenModuleNeverRenders() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.carousel, visible: false),
                (id: PPHomeSectionRegistry.marketplaceHero, visible: true),
            ]),
            promotionPages: [heroPage(id: "promotion-1", kind: .promotion)],
            marketplaceHeroPage: heroPage(id: "m", kind: .marketplace)
        )
        let plan = PPHomePresentationResolver.plan(for: value)

        XCTAssertFalse(
            plan.containsModule(rawID: PPHomeSectionRegistry.carousel)
        )
        XCTAssertTrue(
            plan.hiddenModuleIDs.contains(PPHomeSectionRegistry.carousel)
        )
        XCTAssertFalse(
            plan.suppressedModules.contains {
                $0.rawID == PPHomeSectionRegistry.carousel
            }
        )
    }

    func testEmptyConfigProducesEmptyPlanWithoutCrashing() {
        let plan = PPHomePresentationResolver.plan(
            for: state(config: config([]))
        )
        XCTAssertTrue(plan.isEmpty)
        XCTAssertTrue(plan.suppressedModules.isEmpty)
        XCTAssertTrue(plan.retainedUnknownModuleIDs.isEmpty)
        XCTAssertTrue(plan.unmappedSuppressedModuleIDs.isEmpty)
    }

    func testDuplicateConfiguredIdentifiersCollapseToTheFirstOccurrence() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.accessories, visible: true),
                (id: PPHomeSectionRegistry.accessories, visible: false),
            ]),
            sections: [rail(id: 7, kind: .accessories)]
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertEqual(
            plan.allModules.filter {
                $0.rawID == PPHomeSectionRegistry.accessories
            }.count,
            1
        )
    }

    // MARK: Unknown identifiers

    func testUnknownIdentifierIsRetainedAndNeverReinterpreted() {
        let value = state(
            config: config([
                (id: 27, visible: true),
                (id: PPHomeSectionRegistry.accessories, visible: true),
            ]),
            sections: [rail(id: 7, kind: .accessories)]
        )
        let plan = PPHomePresentationResolver.plan(for: value)

        XCTAssertEqual(plan.retainedUnknownModuleIDs, [27])
        XCTAssertFalse(plan.containsModule(rawID: 27))
        XCTAssertFalse(plan.suppressedModules.contains { $0.rawID == 27 })
        XCTAssertEqual(
            plan.allModules.map(\.rawID),
            [PPHomeSectionRegistry.accessories]
        )
    }

    // MARK: Rule 2/5 — marketing stage arbitration by server order

    func testMarketingStageTakesTheFirstEligibleCandidateInServerOrder() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.carousel, visible: true),
                (id: PPHomeSectionRegistry.marketplaceHero, visible: true),
                (id: PPHomeSectionRegistry.hero, visible: true),
            ]),
            heroPages: [heroPage(id: "pet-1", kind: .pet)],
            promotionPages: [heroPage(id: "promotion-1", kind: .promotion)],
            marketplaceHeroPage: heroPage(id: "m", kind: .marketplace),
            pets: [pet(id: "pet-1")]
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        let stage = plan.modules(in: .marketingStage)

        XCTAssertEqual(stage.count, PPHomePresentationLimits.marketingStages)
        XCTAssertEqual(stage.first?.rawID, PPHomeSectionRegistry.carousel)
        XCTAssertEqual(stage.first?.kind, .marketingStage(.promotions))
    }

    func testReorderedServerConfigChangesTheStageOwner() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.marketplaceHero, visible: true),
                (id: PPHomeSectionRegistry.carousel, visible: true),
            ]),
            promotionPages: [heroPage(id: "promotion-1", kind: .promotion)],
            marketplaceHeroPage: heroPage(id: "m", kind: .marketplace)
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertEqual(
            plan.modules(in: .marketingStage).first?.kind,
            .marketingStage(.marketplace)
        )
    }

    func testMissingCampaignMakesTheLaneIneligibleWithoutSuppressingContent() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.carousel, visible: true),
                (id: PPHomeSectionRegistry.marketplaceHero, visible: true),
            ]),
            promotionPages: [],
            marketplaceHeroPage: heroPage(id: "m", kind: .marketplace)
        )
        let plan = PPHomePresentationResolver.plan(for: value)

        XCTAssertEqual(
            plan.modules(in: .marketingStage).first?.kind,
            .marketingStage(.marketplace)
        )
        // An ineligible promotion lane has no campaign to reach, so it is
        // reported rather than mapped to an unrelated destination.
        XCTAssertTrue(
            plan.unmappedSuppressedModuleIDs
                .contains(PPHomeSectionRegistry.carousel)
        )
    }

    func testPetHeroIsIneligibleWithoutAPet() {
        let value = state(
            config: config([(id: PPHomeSectionRegistry.hero, visible: true)]),
            heroPages: [heroPage(id: "pet-1", kind: .pet)],
            pets: []
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertTrue(plan.modules(in: .marketingStage).isEmpty)
        XCTAssertEqual(
            plan.suppressedModules.first { $0.rawID == PPHomeSectionRegistry.hero }?
                .destination,
            .petProfiles
        )
    }

    // MARK: Partner bound and reachability

    func testOnlyOnePartnerFeatureIsPresentedAtATime() {
        let plan = PPHomePresentationResolver.plan(for: populatedState())
        let partners = plan.allModules.filter {
            if case .partnerFeature = $0.kind { return true }
            return false
        }
        XCTAssertLessThanOrEqual(
            partners.count,
            PPHomePresentationLimits.partnerFeatures
        )
    }

    func testPartnerSlotPrefersTheCampaignWithNoAlternativeDestination() {
        // Pet hero owns the stage; both campaign lanes are demoted. Promotions
        // have no list destination, so suppressing them would break rule 7.
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.hero, visible: true),
                (id: PPHomeSectionRegistry.marketplaceHero, visible: true),
                (id: PPHomeSectionRegistry.carousel, visible: true),
            ]),
            heroPages: [heroPage(id: "pet-1", kind: .pet)],
            promotionPages: [heroPage(id: "promotion-1", kind: .promotion)],
            marketplaceHeroPage: heroPage(id: "m", kind: .marketplace),
            pets: [pet(id: "pet-1")]
        )
        let plan = PPHomePresentationResolver.plan(for: value)

        XCTAssertEqual(
            plan.module(rawID: PPHomeSectionRegistry.carousel)?.kind,
            .partnerFeature(.promotions)
        )
        XCTAssertEqual(
            plan.suppressedModules
                .first { $0.rawID == PPHomeSectionRegistry.marketplaceHero }?
                .destination,
            .marketplaceCampaign
        )
        XCTAssertTrue(plan.unmappedSuppressedModuleIDs.isEmpty)
    }

    func testPetContextIsNeverPresentedAsAPartnerFeature() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.carousel, visible: true),
                (id: PPHomeSectionRegistry.hero, visible: true),
            ]),
            heroPages: [heroPage(id: "pet-1", kind: .pet)],
            promotionPages: [heroPage(id: "promotion-1", kind: .promotion)],
            pets: [pet(id: "pet-1")]
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertFalse(
            plan.allModules.contains { $0.kind == .partnerFeature(.petContext) }
        )
    }

    // MARK: Live priority bound

    func testLivePriorityIsBoundedToOneItemAndPrefersTheOperationalOrder() {
        let plan = PPHomePresentationResolver.plan(for: populatedState())
        let live = plan.modules(in: .livePriority)

        XCTAssertEqual(live.count, PPHomePresentationLimits.livePriorityItems)
        XCTAssertEqual(live.first?.kind, .livePriorityOrder)
        XCTAssertEqual(live.first?.rawID, PPHomeSectionRegistry.currentOrders)
    }

    func testCareReminderOwnsLivePriorityWhenNoOrderExists() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.carousel, visible: true),
                (id: PPHomeSectionRegistry.hero, visible: true),
                (id: PPHomeSectionRegistry.currentOrders, visible: true),
            ]),
            heroPages: [
                heroPage(id: "pet-1", kind: .pet),
                heroPage(id: "reminder-1", kind: .reminder),
            ],
            promotionPages: [heroPage(id: "promotion-1", kind: .promotion)],
            pets: [pet(id: "pet-1")],
            featuredOrder: nil
        )
        let plan = PPHomePresentationResolver.plan(for: value)

        XCTAssertEqual(
            plan.modules(in: .livePriority).first?.kind,
            .livePriorityCare
        )
        XCTAssertEqual(
            plan.suppressedModules
                .first { $0.rawID == PPHomeSectionRegistry.currentOrders }?
                .destination,
            .orderHistory
        )
    }

    func testMissingOrderRemovesLivePriorityEntirely() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.currentOrders, visible: true),
            ]),
            featuredOrder: nil
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertTrue(plan.modules(in: .livePriority).isEmpty)
        XCTAssertEqual(
            plan.suppressedModules.first?.destination,
            .orderHistory
        )
    }

    // MARK: Ecosystem launcher bound

    func testEcosystemLauncherNeverExceedsItsBound() {
        var value = populatedState()
        value.priorityActions = [
            "pet", "shop", "ads", "pharmacy", "vet", "extra1", "extra2",
        ].map(priorityAction)

        let plan = PPHomePresentationResolver.plan(for: value)
        let actions = PPHomePresentationResolver.ecosystemLauncherActions(
            for: value,
            plan: plan
        )
        XCTAssertLessThanOrEqual(
            actions.count,
            PPHomePresentationLimits.ecosystemLauncherSecondaryActions
        )
        // Configured order is preserved; only deliberately excluded
        // destinations are dropped.
        XCTAssertEqual(
            actions.map(\.id),
            ["pet", "shop", "ads", "pharmacy", "vet", "extra1", "extra2"]
                .filter {
                    !PPHomePresentationFlags.launcherExcludedActionIDs
                        .contains($0)
                }
                .prefix(
                    PPHomePresentationLimits
                        .ecosystemLauncherSecondaryActions
                )
                .map { $0 }
        )
    }

    func testMyPetFeatureLeadsFourHighestPrioritySecondaryActions() {
        var value = populatedState()
        value.priorityActions = [
            "pet", "shop", "ads", "pharmacy", "vet", "services",
        ].map(priorityAction)

        let plan = PPHomePresentationResolver.plan(for: value)
        let featured = PPHomePresentationResolver
            .ecosystemLauncherFeaturedAction(for: value, plan: plan)
        let actions = PPHomePresentationResolver.ecosystemLauncherActions(
            for: value,
            plan: plan
        )

        XCTAssertEqual(featured?.id, "pet")
        XCTAssertEqual(
            actions.map(\.id),
            ["shop", "ads", "pharmacy", "vet"]
        )
        XCTAssertTrue(value.priorityActions.contains { $0.id == "services" })
        XCTAssertFalse(actions.contains { $0.id == "services" })
    }

    func testMissingPetDoesNotPromoteASecondaryActionToFeatured() {
        var value = populatedState()
        value.priorityActions = [
            "shop", "ads", "pharmacy", "vet", "services",
        ].map(priorityAction)

        let plan = PPHomePresentationResolver.plan(for: value)
        let featured = PPHomePresentationResolver
            .ecosystemLauncherFeaturedAction(for: value, plan: plan)
        let actions = PPHomePresentationResolver.ecosystemLauncherActions(
            for: value,
            plan: plan
        )

        XCTAssertNil(featured)
        XCTAssertEqual(
            actions.map(\.id),
            ["shop", "ads", "pharmacy", "vet"]
        )
    }

    func testLauncherExcludedDestinationsStayReachableElsewhere() {
        let value = populatedState()
        let plan = PPHomePresentationResolver.plan(for: value)
        let actions = PPHomePresentationResolver.ecosystemLauncherActions(
            for: value,
            plan: plan
        )
        for excluded in PPHomePresentationFlags.launcherExcludedActionIDs {
            XCTAssertFalse(actions.contains { $0.id == excluded })
        }
        // The pet destination is still presented by the pet context module.
        XCTAssertEqual(
            plan.module(rawID: PPHomeSectionRegistry.petProfile)?.kind,
            .petContext
        )
        XCTAssertEqual(
            PPHomePresentationResolver
                .ecosystemLauncherFeaturedAction(for: value, plan: plan)?.id,
            "pet"
        )
    }

    func testLauncherIsAbsentWithoutConfiguredActions() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.quickActions, visible: true),
            ]),
            priorityActions: []
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertTrue(plan.modules(in: .ecosystemLauncher).isEmpty)
        XCTAssertEqual(
            PPHomePresentationResolver.ecosystemLauncherActions(
                for: value,
                plan: plan
            ),
            []
        )
        XCTAssertNil(
            PPHomePresentationResolver
                .ecosystemLauncherFeaturedAction(for: value, plan: plan)
        )
    }

    // MARK: Commerce rail bound and reachability

    func testCommerceRailsAreBoundedAndOverflowStaysReachable() {
        let plan = PPHomePresentationResolver.plan(for: populatedState())
        let rails = plan.allModules.filter {
            if case .commerceRail = $0.kind { return true }
            return false
        }

        XCTAssertEqual(rails.count, PPHomePresentationLimits.commerceRails)
        // Fallback order presents accessories 7, suggestion ads 18, then
        // suggestion accessories 19.
        XCTAssertEqual(rails.map(\.rawID), [7, 18, 19])

        for overflow in [6, 10, 12, 11, 14] {
            let suppressed = plan.suppressedModules.first {
                $0.rawID == overflow
            }
            XCTAssertNotNil(
                suppressed,
                "Overflow rail \(overflow) must stay reachable"
            )
            if case .commerceSeeAll = suppressed?.destination {
                // Correct: it maps onto the existing See All route.
            } else {
                XCTFail("Rail \(overflow) is not mapped to a See All route")
            }
        }
    }

    func testRailWithNoResolvedSectionIsSuppressedNotRendered() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.accessories, visible: true),
            ]),
            sections: []
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertFalse(
            plan.containsModule(rawID: PPHomeSectionRegistry.accessories)
        )
        XCTAssertTrue(
            plan.unmappedSuppressedModuleIDs
                .contains(PPHomeSectionRegistry.accessories)
                || plan.suppressedModules.contains {
                    $0.rawID == PPHomeSectionRegistry.accessories
                }
        )
    }

    // MARK: Single care gateway

    func testOnlyOneCareGatewayIsPresentedAndTheOtherStaysReachable() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.premiumCare, visible: true),
                (id: PPHomeSectionRegistry.providerCategoryNav, visible: true),
            ])
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        let gateways = plan.allModules.filter {
            if case .careGateway = $0.kind { return true }
            return false
        }

        XCTAssertEqual(gateways.count, 1)
        XCTAssertEqual(gateways.first?.rawID, PPHomeSectionRegistry.premiumCare)
        XCTAssertEqual(gateways.first?.kind, .careGateway(.premiumCare))
        XCTAssertEqual(
            plan.suppressedModules
                .first {
                    $0.rawID == PPHomeSectionRegistry.providerCategoryNav
                }?
                .destination,
            .careGateway
        )
    }

    func testProviderNavigationOwnsTheGatewayWhenItComesFirst() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.providerCategoryNav, visible: true),
                (id: PPHomeSectionRegistry.premiumCare, visible: true),
            ])
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertEqual(
            plan.module(rawID: PPHomeSectionRegistry.providerCategoryNav)?.kind,
            .careGateway(.providerNavigation)
        )
    }

    // MARK: Pure Lens

    func testPureLensRespectsItsConsoleVisibilityFlag() {
        let visible = PPHomePresentationResolver.plan(
            for: state(
                config: config(
                    [(id: PPHomeSectionRegistry.pureLens, visible: true)],
                    pureLensVisible: true
                )
            )
        )
        XCTAssertEqual(
            visible.module(rawID: PPHomeSectionRegistry.pureLens)?.kind,
            .pureLensFeature
        )

        let hidden = PPHomePresentationResolver.plan(
            for: state(
                config: config(
                    [(id: PPHomeSectionRegistry.pureLens, visible: true)],
                    pureLensVisible: false
                )
            )
        )
        XCTAssertFalse(
            hidden.containsModule(rawID: PPHomeSectionRegistry.pureLens)
        )
        XCTAssertTrue(
            hidden.hiddenModuleIDs.contains(PPHomeSectionRegistry.pureLens)
        )
    }

    // MARK: Pet context

    func testPetContextRemainsPresentWithNoPetSoHomeStaysComplete() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.petProfile, visible: true),
            ]),
            pets: []
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertEqual(
            plan.module(rawID: PPHomeSectionRegistry.petProfile)?.kind,
            .petContext
        )
    }

    func testSignedOutStateStillProducesADiscoverableHome() {
        var value = HomeViewState.initial
        value.config = .fallback
        value.categories = [category(id: "main-kind-1")]

        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertTrue(plan.modules(in: .marketingStage).isEmpty)
        XCTAssertTrue(plan.modules(in: .livePriority).isEmpty)
        XCTAssertTrue(
            plan.containsModule(rawID: PPHomeSectionRegistry.mainKinds)
        )
        XCTAssertTrue(
            plan.containsModule(rawID: PPHomeSectionRegistry.premiumCare)
        )
        XCTAssertTrue(plan.unmappedSuppressedModuleIDs.isEmpty)
    }

    // MARK: Rule 7 — no silent discard

    func testEverySuppressedModuleIsEitherMappedOrReported() {
        let plan = PPHomePresentationResolver.plan(for: populatedState())
        let presented = Set(plan.allModules.map(\.rawID))
        let mapped = Set(plan.suppressedModules.map(\.rawID))
        let reported = Set(plan.unmappedSuppressedModuleIDs)
        let hidden = Set(plan.hiddenModuleIDs)
        let retained = Set(plan.retainedUnknownModuleIDs)

        for section in HomeConfigModel.fallback.sections {
            let accounted =
                presented.contains(section.id)
                || mapped.contains(section.id)
                || reported.contains(section.id)
                || hidden.contains(section.id)
                || retained.contains(section.id)
            XCTAssertTrue(
                accounted,
                "Configured module \(section.id) vanished from the plan"
            )
        }
        XCTAssertTrue(mapped.isDisjoint(with: presented))
    }

    func testCommandSurfaceOwnsTheDiscoveryPrompt() {
        let value = state(
            config: config([
                (id: PPHomeSectionRegistry.premiumSearch, visible: true),
            ])
        )
        let plan = PPHomePresentationResolver.plan(for: value)
        XCTAssertEqual(
            plan.modules(in: .commandSurface).map(\.kind),
            [.discoveryPrompt]
        )
    }

    func testZoneOrderIsStable() {
        let plan = PPHomePresentationResolver.plan(for: populatedState())
        XCTAssertEqual(
            plan.zones.map(\.id),
            [
                .commandSurface, .marketingStage, .ecosystemLauncher,
                .livePriority, .commerceDiscovery,
            ]
        )
    }
}
