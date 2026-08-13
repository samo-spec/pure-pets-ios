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

    func testHeaderV2CollapseUsesOneClampedScrollProgress() {
        XCTAssertEqual(
            PPMarketplaceHeaderV2ScrollMetrics.progress(for: 40),
            0
        )
        XCTAssertEqual(
            PPMarketplaceHeaderV2ScrollMetrics.progress(
                for: -PPMarketplaceHeaderV2ScrollMetrics.collapseDistance / 2
            ),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPMarketplaceHeaderV2ScrollMetrics.progress(for: -10_000),
            1
        )
    }

    func testHeaderV2ReduceMotionKeepsOneActiveRepresentation() {
        let threshold =
            PPMarketplaceHeaderV2ScrollMetrics.compactActivationProgress

        XCTAssertEqual(
            PPMarketplaceHeaderV2ScrollMetrics.expandedVisibility(
                for: threshold - 0.01,
                reduceMotion: true
            ),
            1
        )
        XCTAssertEqual(
            PPMarketplaceHeaderV2ScrollMetrics.compactVisibility(
                for: threshold - 0.01,
                reduceMotion: true
            ),
            0
        )
        XCTAssertEqual(
            PPMarketplaceHeaderV2ScrollMetrics.expandedVisibility(
                for: threshold,
                reduceMotion: true
            ),
            0
        )
        XCTAssertEqual(
            PPMarketplaceHeaderV2ScrollMetrics.compactVisibility(
                for: threshold,
                reduceMotion: true
            ),
            1
        )
    }

    func testHeaderV2ControlsMeetMinimumTargetAndKeepEverySection() {
        XCTAssertGreaterThanOrEqual(
            PPMarketplaceHeaderV2Geometry.expandedControlSize,
            PPMarketplaceHeaderV2Geometry.minimumTouchTarget
        )
        XCTAssertGreaterThanOrEqual(
            PPMarketplaceHeaderV2Geometry.compactControlSize,
            PPMarketplaceHeaderV2Geometry.minimumTouchTarget
        )
        XCTAssertGreaterThanOrEqual(
            PPMarketplaceHeaderV2Geometry.expandedSearchHeight,
            PPMarketplaceHeaderV2Geometry.minimumTouchTarget
        )
        XCTAssertEqual(
            PPMarketplaceSectionDescriptor.all.map(\.rawValue),
            [0, 1, 2, 3]
        )
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
