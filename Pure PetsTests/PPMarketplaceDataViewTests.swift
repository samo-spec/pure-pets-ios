import Combine
import XCTest
@testable import Pure_Pets

@MainActor
final class PPMarketplaceDataViewTests: XCTestCase {
    func testCategoryDraftFiltersSubkindsByMainKind() {
        let fixture = makeFixture()
        let store = PPMarketplaceDataViewStore(bridge: fixture.bridge)

        store.beginCategoryEditing()
        XCTAssertEqual(store.categoryDraftMainKindID, 1)
        XCTAssertEqual(store.categoryDraftSubKindChoices.map(\.id), [0, 101])

        let cats = tryUnwrap(
            store.mainKindChoices.first(where: { $0.id == 2 })
        )
        store.selectCategoryMainKind(cats)

        XCTAssertEqual(store.categoryDraftMainKindID, 2)
        XCTAssertEqual(store.categoryDraftSubKindChoices.map(\.id), [0, 201])
    }

    func testChangingMainKindClearsIncompatibleSubkind() {
        let fixture = makeFixture()
        let store = PPMarketplaceDataViewStore(bridge: fixture.bridge)

        store.beginCategoryEditing()
        let dogsSubkind = tryUnwrap(
            store.categoryDraftSubKindChoices.first(where: { $0.id == 101 })
        )
        store.selectCategorySubKind(dogsSubkind)
        XCTAssertEqual(store.categoryDraftSubKindID, 101)

        let cats = tryUnwrap(
            store.mainKindChoices.first(where: { $0.id == 2 })
        )
        store.selectCategoryMainKind(cats)

        XCTAssertEqual(store.categoryDraftSubKindID, 0)
    }

    func testApplyForwardsExistingSpeciesAndBreedIdentifiersOnce() {
        let fixture = makeFixture()
        var captured: [(speciesID: Int, breedID: Int)] = []
        let store = PPMarketplaceDataViewStore(
            bridge: fixture.bridge,
            categoryApplyAction: { speciesID, breedID in
                captured.append((speciesID, breedID))
            }
        )

        store.beginCategoryEditing()
        store.selectCategoryMainKind(
            tryUnwrap(store.mainKindChoices.first(where: { $0.id == 2 }))
        )
        store.selectCategorySubKind(
            tryUnwrap(
                store.categoryDraftSubKindChoices.first(where: { $0.id == 201 })
            )
        )
        store.applyCategoryDraft()

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.speciesID, 2)
        XCTAssertEqual(captured.first?.breedID, 201)
    }

    func testMainKindShortcutClearsAnIncompatibleActiveSubkind() {
        let fixture = makeFixture()
        fixture.viewModel.setValue(NSNumber(value: 101), forKey: "currentSubKindID")
        var captured: (speciesID: Int, breedID: Int)?
        let store = PPMarketplaceDataViewStore(
            bridge: fixture.bridge,
            categoryApplyAction: { speciesID, breedID in
                captured = (speciesID, breedID)
            }
        )

        store.applyMainKindShortcut(
            tryUnwrap(store.mainKindChoices.first(where: { $0.id == 2 }))
        )

        XCTAssertEqual(captured?.speciesID, 2)
        XCTAssertEqual(captured?.breedID, 0)
    }

    func testSubkindShortcutUsesActiveMainKind() {
        let fixture = makeFixture()
        var captured: (speciesID: Int, breedID: Int)?
        let store = PPMarketplaceDataViewStore(
            bridge: fixture.bridge,
            categoryApplyAction: { speciesID, breedID in
                captured = (speciesID, breedID)
            }
        )

        store.applySubKindShortcut(
            tryUnwrap(store.subKindChoices.first(where: { $0.id == 101 }))
        )

        XCTAssertEqual(captured?.speciesID, 1)
        XCTAssertEqual(captured?.breedID, 101)
    }

    func testLatestRequestGateRejectsObsoleteResponse() {
        let gate = PPDataViewRequestGate()
        let obsolete = gate.beginRequest()
        let latest = gate.beginRequest()

        XCTAssertFalse(gate.isCurrentRequest(obsolete))
        XCTAssertTrue(gate.isCurrentRequest(latest))
    }

    func testEmptyAdsRequiresACompletedUnfilteredSnapshot() {
        let fixture = makeFixture()
        fixture.viewModel.currentSection = .ads
        XCTAssertFalse(fixture.bridge.hasLoadedEmptyAds)

        fixture.viewModel.setValue([], forKey: "latestRawResults")
        fixture.viewModel.setValue(true, forKey: "isLoading")
        XCTAssertFalse(fixture.bridge.hasLoadedEmptyAds)

        fixture.viewModel.setValue(false, forKey: "isLoading")
        XCTAssertTrue(fixture.bridge.hasLoadedEmptyAds)

        // Zero displayed cards after filtering does not mean there are no ads.
        fixture.viewModel.setValue([PetAd()], forKey: "latestRawResults")
        XCTAssertEqual(fixture.viewModel.itemCount, 0)
        XCTAssertFalse(fixture.bridge.hasLoadedEmptyAds)

        fixture.viewModel.setValue([], forKey: "latestRawResults")
        fixture.viewModel.currentSection = .accessories
        XCTAssertFalse(fixture.bridge.hasLoadedEmptyAds)
    }

    func testEmptyAdsSwitchesToAccessoriesAndKeepsCategoryAndBreed() async {
        let (bridge, store) = makeEmptyAdsFixture()
        bridge.testViewModel.currentSubKindID = 101
        let switched = expectation(description: "Empty Ads selects Accessories")
        let observation = store.$currentSection
            .first(where: { $0 == .accessories })
            .sink { _ in switched.fulfill() }

        bridge.completeLoad(section: .ads, rawResults: [])
        await fulfillment(of: [switched], timeout: 1)

        XCTAssertEqual(bridge.switchedSections, [.accessories])
        XCTAssertEqual(bridge.currentMainKindID, 1)
        XCTAssertEqual(bridge.currentSubKindID, 101)
        XCTAssertEqual(store.loadState, .loading)
        withExtendedLifetime(observation) {}
    }

    func testFilterOnlyEmptyAdsDoesNotSwitchSections() async {
        let (bridge, store) = makeEmptyAdsFixture()
        let empty = expectation(description: "Filtered Ads stays empty")
        let observation = store.$loadState
            .first(where: { $0 == .empty })
            .sink { _ in empty.fulfill() }

        bridge.completeLoad(section: .ads, rawResults: [PetAd()])
        await fulfillment(of: [empty], timeout: 1)

        XCTAssertEqual(store.currentSection, .ads)
        XCTAssertTrue(bridge.switchedSections.isEmpty)
        withExtendedLifetime(observation) {}
    }

    func testFailedAdsLoadStaysOnAdsAndSuccessfulRetryCanFallBack() async {
        let (bridge, store) = makeEmptyAdsFixture()
        let failed = expectation(description: "Ads failure stays visible")
        let failureObservation = store.$loadState
            .first(where: {
                if case .failed = $0 { return true }
                if case .offline = $0 { return true }
                return false
            })
            .sink { _ in failed.fulfill() }

        bridge.testViewModel.setValue(false, forKey: "isLoading")
        bridge.loadingDidFail?(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))
        await fulfillment(of: [failed], timeout: 1)
        XCTAssertEqual(store.currentSection, .ads)
        XCTAssertTrue(bridge.switchedSections.isEmpty)

        let switched = expectation(description: "Successful empty retry can switch")
        let retryObservation = store.$currentSection
            .first(where: { $0 == .accessories })
            .sink { _ in switched.fulfill() }
        bridge.completeLoad(section: .ads, rawResults: [])
        await fulfillment(of: [switched], timeout: 1)
        XCTAssertEqual(bridge.switchedSections, [.accessories])
        withExtendedLifetime((failureObservation, retryObservation)) {}
    }

    func testReturningToAdsAfterFallbackDoesNotSwitchAgain() async {
        let (bridge, store) = makeEmptyAdsFixture()
        let switched = expectation(description: "Initial fallback")
        let sectionObservation = store.$currentSection
            .first(where: { $0 == .accessories })
            .sink { _ in switched.fulfill() }
        bridge.completeLoad(section: .ads, rawResults: [])
        await fulfillment(of: [switched], timeout: 1)

        let accessoriesLoaded = expectation(description: "Empty Accessories finishes normally")
        let accessoryObservation = store.$isReplacingContext
            .first(where: { !$0 })
            .sink { _ in accessoriesLoaded.fulfill() }
        bridge.completeLoad(section: .accessories, rawResults: [])
        await fulfillment(of: [accessoriesLoaded], timeout: 1)
        XCTAssertEqual(store.loadState, .empty)
        XCTAssertEqual(bridge.switchedSections, [.accessories])

        store.selectSection(tryUnwrap(PPMarketplaceSectionDescriptor.all.first(where: {
            $0.section == .ads
        })))
        let adsLoaded = expectation(description: "Manual Ads selection stays selected")
        let adsObservation = store.$isReplacingContext
            .first(where: { !$0 })
            .sink { _ in adsLoaded.fulfill() }
        bridge.completeLoad(section: .ads, rawResults: [])
        bridge.itemsDidChange?() // Duplicate delivery must not restart the fallback.
        await fulfillment(of: [adsLoaded], timeout: 1)

        XCTAssertEqual(store.currentSection, .ads)
        XCTAssertEqual(store.loadState, .empty)
        XCTAssertEqual(bridge.switchedSections, [.accessories, .ads])
        withExtendedLifetime((sectionObservation, accessoryObservation, adsObservation)) {}
    }

    func testNewBreedAllowsEmptyAdsFallbackAfterManualTabChoice() async {
        let (bridge, store) = makeEmptyAdsFixture()
        store.selectSection(tryUnwrap(PPMarketplaceSectionDescriptor.all.first(where: {
            $0.section == .ads
        })))
        store.selectSubKind(PPMarketplaceSubKindChoice(id: 101, title: "Retriever"))
        let switched = expectation(description: "New breed can fall back")
        let observation = store.$currentSection
            .first(where: { $0 == .accessories })
            .sink { _ in switched.fulfill() }

        bridge.completeLoad(section: .ads, rawResults: [])
        await fulfillment(of: [switched], timeout: 1)

        XCTAssertEqual(bridge.switchedSections, [.accessories])
        XCTAssertEqual(bridge.currentSubKindID, 101)
        withExtendedLifetime(observation) {}
    }

    func testCallbackForAnotherCurrentSectionDoesNotTriggerAdsFallback() async {
        let (bridge, store) = makeEmptyAdsFixture()
        let empty = expectation(description: "Current Food result is retained")
        let observation = store.$loadState
            .first(where: { $0 == .empty })
            .sink { _ in empty.fulfill() }

        bridge.completeLoad(section: .food, rawResults: [])
        await fulfillment(of: [empty], timeout: 1)

        XCTAssertEqual(store.currentSection, .food)
        XCTAssertTrue(bridge.switchedSections.isEmpty)
        withExtendedLifetime(observation) {}
    }

    func testSearchPresentationPreservesCommittedCategory() {
        let fixture = makeFixture()
        fixture.viewModel.setValue(NSNumber(value: 101), forKey: "currentSubKindID")
        var captured: (mainKindID: Int, subKindID: Int)?
        let store = PPMarketplaceDataViewStore(
            bridge: fixture.bridge,
            searchAction: {
                captured = (
                    fixture.bridge.currentMainKindID,
                    fixture.bridge.currentSubKindID
                )
            }
        )

        store.openSearch()

        XCTAssertEqual(captured?.mainKindID, 1)
        XCTAssertEqual(captured?.subKindID, 101)
        XCTAssertEqual(fixture.bridge.currentMainKindID, 1)
        XCTAssertEqual(fixture.bridge.currentSubKindID, 101)
    }

    func testViewModelTaxonomyParametersKeepLegacyBackendMapping() {
        let fixture = makeFixture()
        fixture.viewModel.setValue(NSNumber(value: 101), forKey: "currentSubKindID")

        let parameters = fixture.viewModel.currentTaxonomyParameters()

        XCTAssertEqual(parameters["speciesID"]?.intValue, 1)
        XCTAssertEqual(parameters["breedID"]?.intValue, 101)
    }

    func testSmallDeviceHeroControlsKeepIndependentMinimumTargets() {
        let metrics = PPMarketplaceHeroControlLayoutPolicy.metrics(
            availableWidth: 320,
            isAccessibilitySize: false,
            layoutDirection: .leftToRight
        )

        XCTAssertTrue(metrics.usesCompactHeader)
        XCTAssertEqual(metrics.searchButtonSize, 50)
        XCTAssertGreaterThanOrEqual(metrics.categoryMinimumHeight, 44)
        XCTAssertTrue((12...16).contains(metrics.spacing))
    }

    func testRTLKeepsTheSameSafeHeroControlGeometry() {
        let ltr = PPMarketplaceHeroControlLayoutPolicy.metrics(
            availableWidth: 320,
            isAccessibilitySize: false,
            layoutDirection: .leftToRight
        )
        let rtl = PPMarketplaceHeroControlLayoutPolicy.metrics(
            availableWidth: 320,
            isAccessibilitySize: false,
            layoutDirection: .rightToLeft
        )

        XCTAssertEqual(ltr, rtl)
    }

    func testCommandDockV3CollapseUsesOneClampedScrollProgress() {
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.progress(forDockMinY: 200),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.progress(
                forDockMinY: PPMarketplaceCommandDockV3Metrics.collapseDistance / 2
            ),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.progress(forDockMinY: 0),
            1
        )
    }

    func testCommandDockV3InterpolationRetainsOneGeometryOwner() {
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.interpolate(
                expanded: 56,
                compact: 48,
                progress: -1
            ),
            56
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.interpolate(
                expanded: 56,
                compact: 48,
                progress: 0.5
            ),
            52
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.interpolate(
                expanded: 56,
                compact: 48,
                progress: 2
            ),
            48
        )
    }

    func testCommandDockV3ControlsMeetMinimumTargetAndKeepEverySection() {
        XCTAssertGreaterThanOrEqual(
            PPMarketplaceCommandDockV3Metrics.minimumTouchTarget,
            44
        )
        XCTAssertFalse(
            PPMarketplaceCommandDockV3Metrics.showsCompactNavigation(
                progress: 0.49
            )
        )
        XCTAssertTrue(
            PPMarketplaceCommandDockV3Metrics.showsCompactNavigation(
                progress: 0.50
            )
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.compactNavigationProgress(
                progress: 0
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.compactNavigationProgress(
                progress: -1
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.compactNavigationProgress(
                progress: 0.20
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.compactNavigationProgress(
                progress: 0.35
            ),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.compactNavigationProgress(
                progress: 0.50
            ),
            1,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.compactNavigationProgress(
                progress: 2
            ),
            1,
            accuracy: 0.001
        )

        let sampledProgress: [CGFloat] = [0, 0.20, 0.35, 0.49, 0.50, 0.69, 1]
        for progress in sampledProgress {
            let compactHeight = PPMarketplaceCommandDockV3Metrics.interpolate(
                expanded: 56,
                compact: 48,
                progress: progress
            )
            let activeTargetHeight =
                PPMarketplaceCommandDockV3Metrics.activeCategoryTargetHeight(
                    expandedHeight: 64,
                    compactHeight: compactHeight,
                    progress: progress
                )
            XCTAssertGreaterThanOrEqual(
                activeTargetHeight,
                PPMarketplaceCommandDockV3Metrics.minimumTouchTarget,
                "Active category target fell below 44pt at progress \(progress)"
            )
        }

        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.taxonomyRowHeight(
                expandedHeight: 64,
                progress: 0.50
            ),
            44,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Metrics.taxonomyRowHeight(
                expandedHeight: 64,
                progress: 1
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceCommandDockV3Accessibility.taxonomyIdentifier,
            "pp.marketplace.header.v2.taxonomy"
        )
        XCTAssertEqual(
            Set([
                PPMarketplaceCommandDockV3Accessibility.compactTaxonomyIdentifier,
                PPMarketplaceCommandDockV3Accessibility.speciesIdentifier,
                PPMarketplaceCommandDockV3Accessibility.breedIdentifier
            ]).count,
            3
        )
        XCTAssertEqual(
            PPMarketplaceSectionDescriptor.all.map(\.rawValue),
            [0, 1, 2, 3]
        )
    }

    func testTopDeckMetricsAndWaveShapes() {
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.waveDepth, 10.0)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.horizonDepth, 16.0)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.separatorStrokeWidth, 1.5)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.separatorStrokeIncreasedContrastWidth, 2.0)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.dockBottomPadding, 18.0)

        let testRect = CGRect(x: 0, y: 0, width: 421, height: 100)

        // Verify RTL top deck wave shape produces a valid, bounded surface
        let rtlWaveShape = PPMarketplaceTopDeckWaveShape(isRightToLeft: true, waveDepth: 10.0)
        let rtlPath = rtlWaveShape.path(in: testRect)
        XCTAssertFalse(rtlPath.isEmpty)
        XCTAssertLessThanOrEqual(rtlPath.boundingRect.minY, 0)
        XCTAssertGreaterThanOrEqual(rtlPath.boundingRect.maxY, 95)

        // Verify LTR mirrored wave shape produces a valid, bounded surface
        let ltrWaveShape = PPMarketplaceTopDeckWaveShape(isRightToLeft: false, waveDepth: 10.0)
        let ltrPath = ltrWaveShape.path(in: testRect)
        XCTAssertFalse(ltrPath.isEmpty)
        XCTAssertLessThanOrEqual(ltrPath.boundingRect.minY, 0)
        XCTAssertGreaterThanOrEqual(ltrPath.boundingRect.maxY, 95)

        // Verify wave separator line stroke path
        let rtlLineShape = PPMarketplaceWaveSeparatorLine(isRightToLeft: true, waveDepth: 10.0)
        let rtlLinePath = rtlLineShape.path(in: testRect)
        XCTAssertFalse(rtlLinePath.isEmpty)
        XCTAssertGreaterThanOrEqual(rtlLinePath.boundingRect.minY, 88)
        XCTAssertLessThanOrEqual(rtlLinePath.boundingRect.maxY, 101)

        let ltrLineShape = PPMarketplaceWaveSeparatorLine(isRightToLeft: false, waveDepth: 10.0)
        let ltrLinePath = ltrLineShape.path(in: testRect)
        XCTAssertFalse(ltrLinePath.isEmpty)
        XCTAssertGreaterThanOrEqual(ltrLinePath.boundingRect.minY, 88)
        XCTAssertLessThanOrEqual(ltrLinePath.boundingRect.maxY, 101)
    }

    func testTopDeckFocusFieldAndHorizonMirrorSemanticDirection() {
        let testRect = CGRect(x: 0, y: 0, width: 421, height: 100)

        let ltrFocusPath = PPMarketplaceTopDeckFocusFieldShape(
            isRightToLeft: false
        ).path(in: testRect)
        let rtlFocusPath = PPMarketplaceTopDeckFocusFieldShape(
            isRightToLeft: true
        ).path(in: testRect)

        XCTAssertFalse(ltrFocusPath.isEmpty)
        XCTAssertFalse(rtlFocusPath.isEmpty)
        XCTAssertGreaterThan(ltrFocusPath.boundingRect.minX, testRect.midX * 0.8)
        XCTAssertEqual(ltrFocusPath.boundingRect.maxX, testRect.maxX, accuracy: 0.1)
        XCTAssertEqual(rtlFocusPath.boundingRect.minX, testRect.minX, accuracy: 0.1)
        XCTAssertLessThan(rtlFocusPath.boundingRect.maxX, testRect.midX * 1.2)
        XCTAssertEqual(
            ltrFocusPath.boundingRect.width,
            rtlFocusPath.boundingRect.width,
            accuracy: 0.1
        )

        let ltrHorizonPath = PPMarketplaceDeckHorizonShape(
            isRightToLeft: false
        ).path(in: testRect)
        let rtlHorizonPath = PPMarketplaceDeckHorizonShape(
            isRightToLeft: true
        ).path(in: testRect)

        XCTAssertFalse(ltrHorizonPath.isEmpty)
        XCTAssertFalse(rtlHorizonPath.isEmpty)
        XCTAssertEqual(ltrHorizonPath.boundingRect.minX, testRect.minX, accuracy: 0.1)
        XCTAssertEqual(ltrHorizonPath.boundingRect.maxX, testRect.maxX, accuracy: 0.1)
        XCTAssertEqual(rtlHorizonPath.boundingRect.minX, testRect.minX, accuracy: 0.1)
        XCTAssertEqual(rtlHorizonPath.boundingRect.maxX, testRect.maxX, accuracy: 0.1)
        XCTAssertEqual(
            ltrHorizonPath.boundingRect.height,
            rtlHorizonPath.boundingRect.height,
            accuracy: 0.1
        )
        XCTAssertGreaterThan(ltrHorizonPath.boundingRect.minY, 80)
        XCTAssertLessThan(ltrHorizonPath.boundingRect.maxY, testRect.maxY)

        let ltrBandPath = PPMarketplaceDeckHorizonBandShape(
            isRightToLeft: false
        ).path(in: testRect)
        let rtlBandPath = PPMarketplaceDeckHorizonBandShape(
            isRightToLeft: true
        ).path(in: testRect)

        XCTAssertEqual(ltrBandPath.boundingRect.minX, testRect.minX, accuracy: 0.1)
        XCTAssertEqual(ltrBandPath.boundingRect.maxX, testRect.maxX, accuracy: 0.1)
        XCTAssertEqual(ltrBandPath.boundingRect.maxY, testRect.maxY, accuracy: 0.1)
        XCTAssertEqual(rtlBandPath.boundingRect.minX, testRect.minX, accuracy: 0.1)
        XCTAssertEqual(rtlBandPath.boundingRect.maxX, testRect.maxX, accuracy: 0.1)
        XCTAssertEqual(rtlBandPath.boundingRect.maxY, testRect.maxY, accuracy: 0.1)
    }

    func testTopDeckStraightSeparatorWithCenterHalfCircle() {
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.halfCircleRadius, 0.0)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.horizonDepth, 16.0)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.separatorStrokeWidth, 1.5)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.separatorStrokeIncreasedContrastWidth, 2.0)
        XCTAssertEqual(PPMarketplaceTopDeckMetrics.dockBottomPadding, 18.0)

        let testRect = CGRect(x: 0, y: 0, width: 421, height: 100)

        // Verify straight deck shape bounding box with clean straight separator (r = 0)
        let straightDeckShape = PPMarketplaceTopDeckStraightShape(halfCircleRadius: 0.0)
        let deckPath = straightDeckShape.path(in: testRect)
        XCTAssertFalse(deckPath.isEmpty)
        XCTAssertEqual(deckPath.boundingRect.minX, 0, accuracy: 0.1)
        XCTAssertEqual(deckPath.boundingRect.maxX, 421, accuracy: 0.1)
        XCTAssertEqual(deckPath.boundingRect.minY, 0, accuracy: 0.1)
        XCTAssertEqual(deckPath.boundingRect.maxY, 100, accuracy: 0.1)

        // Verify straight separator line shape without center half-circle (r = 0)
        let cleanSeparatorShape = PPMarketplaceDeckSeparatorShape(halfCircleRadius: 0.0)
        let cleanLinePath = cleanSeparatorShape.path(in: testRect)
        XCTAssertFalse(cleanLinePath.isEmpty)
        XCTAssertEqual(cleanLinePath.boundingRect.minX, 0, accuracy: 0.1)
        XCTAssertEqual(cleanLinePath.boundingRect.maxX, 421, accuracy: 0.1)
        XCTAssertEqual(cleanLinePath.boundingRect.minY, 100, accuracy: 0.1)
        XCTAssertEqual(cleanLinePath.boundingRect.maxY, 100, accuracy: 0.1)

        // Verify backward compatibility when halfCircleRadius is explicitly configured
        let domeSeparatorShape = PPMarketplaceDeckSeparatorShape(halfCircleRadius: 16.0)
        let domeLinePath = domeSeparatorShape.path(in: testRect)
        XCTAssertFalse(domeLinePath.isEmpty)
        XCTAssertEqual(domeLinePath.boundingRect.minX, 0, accuracy: 0.1)
        XCTAssertEqual(domeLinePath.boundingRect.maxX, 421, accuracy: 0.1)
        XCTAssertEqual(domeLinePath.boundingRect.minY, 84, accuracy: 0.1)
        XCTAssertEqual(domeLinePath.boundingRect.maxY, 100, accuracy: 0.1)
    }

    func testMedicinesFilterStateContainsDepartmentAndCategoryGroups() {
        let state = PPFilterConfigProvider.medicinesFilterState()
        XCTAssertEqual(state.groups.count, 5)

        let groupFilter = tryUnwrap(state.group(forID: PPFilterIDMedicineGroup))
        XCTAssertEqual(groupFilter.options.count, 3)
        XCTAssertEqual(groupFilter.options[0].value, PPFilterMedicineGroup.all.rawValue)
        XCTAssertEqual(groupFilter.options[1].value, PPFilterMedicineGroup.veterinaryMedicines.rawValue)
        XCTAssertEqual(groupFilter.options[2].value, PPFilterMedicineGroup.petCare.rawValue)

        let catFilter = tryUnwrap(state.group(forID: PPFilterIDMedicineCategory))
        XCTAssertEqual(catFilter.options.count, 23)
        XCTAssertEqual(catFilter.options[0].value, 0)
        XCTAssertEqual(catFilter.options[1].identifierValue, "med_antibiotics")
        XCTAssertEqual(catFilter.options[13].identifierValue, "care_shampoo")
    }

    func testOtherSectionsDoNotContainMedicineFilters() {
        let ads = PPFilterConfigProvider.defaultFilterState(for: .ads)
        XCTAssertNil(ads.group(forID: PPFilterIDMedicineGroup))
        XCTAssertNil(ads.group(forID: PPFilterIDMedicineCategory))

        let accessories = PPFilterConfigProvider.defaultFilterState(for: .accessories)
        XCTAssertNil(accessories.group(forID: PPFilterIDMedicineGroup))
        XCTAssertNil(accessories.group(forID: PPFilterIDMedicineCategory))

        let food = PPFilterConfigProvider.defaultFilterState(for: .food)
        XCTAssertNil(food.group(forID: PPFilterIDMedicineGroup))
        XCTAssertNil(food.group(forID: PPFilterIDMedicineCategory))

        let services = PPFilterConfigProvider.defaultFilterState(for: .services)
        XCTAssertNil(services.group(forID: PPFilterIDMedicineGroup))
        XCTAssertNil(services.group(forID: PPFilterIDMedicineCategory))
    }

    private func makeEmptyAdsFixture() -> (
        PPMarketplaceEmptyAdsTestBridge,
        PPMarketplaceDataViewStore
    ) {
        let fixture = makeFixture()
        let input = tryUnwrap(fixture.bridge.value(forKey: "input") as? PPDataViewInput)
        let bridge = PPMarketplaceEmptyAdsTestBridge(input: input)
        bridge.testViewModel.currentSection = .ads
        return (bridge, PPMarketplaceDataViewStore(bridge: bridge))
    }

    private func makeFixture() -> (
        bridge: PPMarketplaceDataViewBridge,
        viewModel: PPDataViewVM
    ) {
        let dogs = makeMainKind(
            id: 1,
            english: "Dogs",
            arabic: "كلاب",
            subkindID: 101,
            subkindEnglish: "Retriever",
            subkindArabic: "ريتريفر"
        )
        let cats = makeMainKind(
            id: 2,
            english: "Cats",
            arabic: "قطط",
            subkindID: 201,
            subkindEnglish: "Persian",
            subkindArabic: "شيرازي"
        )
        let input = PPDataViewInput()
        input.setValue(dogs, forKey: "mainKind")
        input.setValue([dogs, cats], forKey: "mainKindsArr")
        input.setValue(NSNumber(value: 0), forKey: "sourceTarget")
        input.setValue(NSNumber(value: 0), forKey: "source")

        let bridge = PPMarketplaceDataViewBridge(input: input)
        let viewModel = tryUnwrap(
            bridge.value(forKey: "viewModel") as? PPDataViewVM
        )
        return (bridge, viewModel)
    }

    private func makeMainKind(
        id: Int,
        english: String,
        arabic: String,
        subkindID: Int,
        subkindEnglish: String,
        subkindArabic: String
    ) -> MainKindsModel {
        let subkind = SubKindModel()
        subkind.setValue(NSNumber(value: subkindID), forKey: "ID")
        subkind.setValue(NSNumber(value: id), forKey: "MainKindID")
        subkind.setValue(subkindEnglish, forKey: "SubKindNameEn")
        subkind.setValue(subkindArabic, forKey: "SubKindNameAr")

        let mainKind = MainKindsModel()
        mainKind.setValue(NSNumber(value: id), forKey: "ID")
        mainKind.setValue(english, forKey: "KindNameEn")
        mainKind.setValue(arabic, forKey: "KindNameAr")
        mainKind.setValue(NSMutableArray(array: [subkind]), forKey: "SubKindsArray")
        return mainKind
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("Expected non-nil test fixture value", file: file, line: line)
            fatalError("Missing test fixture value")
        }
        return value
    }
}

/// Drives bridge callbacks without starting Firebase reads or persisting a
/// section preference. The production VM still supplies the emptiness signal.
private final class PPMarketplaceEmptyAdsTestBridge: PPMarketplaceDataViewBridge {
    private(set) var switchedSections: [PPDataSection] = []

    var testViewModel: PPDataViewVM {
        value(forKey: "viewModel") as! PPDataViewVM
    }

    override func switchSection(_ section: PPDataSection) {
        switchedSections.append(section)
        testViewModel.currentSection = section
        beginLoad()
    }

    override func switchSubKind(identifier: Int) {
        testViewModel.currentSubKindID = identifier
        beginLoad()
    }

    func completeLoad(section: PPDataSection, rawResults: [PetAd]) {
        testViewModel.currentSection = section
        testViewModel.setValue(rawResults, forKey: "latestRawResults")
        testViewModel.setValue(false, forKey: "isLoading")
        itemsDidChange?()
    }

    private func beginLoad() {
        testViewModel.setValue(nil, forKey: "latestRawResults")
        testViewModel.setValue(true, forKey: "isLoading")
        itemsDidChange?()
    }
}
