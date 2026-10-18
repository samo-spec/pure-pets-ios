import CoreLocation
import XCTest
@testable import Pure_Pets

final class PPHomeSwiftUIMigrationTests: XCTestCase {
    private func product(_ id: String) -> PetAccessory {
        let product = PetAccessory()
        product.accessoryID = id
        product.name = id
        product.price = 10
        product.imageURLsArray = []
        return product
    }

    func testHomeShelvesFillFromProductsBeyondTheEarlierPreviewLimit() {
        let products = (1...30).map { product("product-\($0)") }
        let featured = HomeModelAdapter.cards(
            from: products, context: .forMarket, kind: .accessory, limit: 8
        )
        let essentials = HomeModelAdapter.cards(
            from: products, context: .forMarket, kind: .accessory,
            limit: 12, excluding: Set(featured.map(\.id))
        )

        XCTAssertEqual(featured.map(\.id), (1...8).map { "product-\($0)" })
        XCTAssertEqual(essentials.map(\.id), (9...20).map { "product-\($0)" })
        XCTAssertTrue(Set(featured.map(\.id)).isDisjoint(with: essentials.map(\.id)))
    }

    func testHomeShelvesDoNotRestoreDuplicatesForASmallCatalog() {
        let products = [product("first"), product("second"), product("third")]
        let remaining = HomeModelAdapter.cards(
            from: products, context: .forMarket, kind: .accessory,
            excluding: ["first", "second"]
        )
        let exhausted = HomeModelAdapter.cards(
            from: products, context: .forMarket, kind: .accessory,
            excluding: ["first", "second", "third"]
        )

        XCTAssertEqual(remaining.map(\.id), ["third"])
        XCTAssertTrue(exhausted.isEmpty)
    }

    func testDuplicateProductDocumentsDoNotConsumePreviewCapacity() {
        let products = [product("used"), product("used"), product("fresh"),
                        product("fresh"), product("next")]
        let cards = HomeModelAdapter.cards(
            from: products, context: .forMarket, kind: .accessory,
            limit: 2, excluding: ["used"]
        )

        XCTAssertEqual(cards.map(\.id), ["fresh", "next"])
    }

    func testHomePreviewClaimsDoNotMutateTheSourceOrLeakIntoANewContext() {
        let products = [product("first"), product("second")]
        let nextShelf = HomeModelAdapter.cards(
            from: products, context: .forMarket, kind: .accessory,
            excluding: ["first"]
        )
        let newContext = HomeModelAdapter.cards(
            from: products, context: .forMarket, kind: .accessory
        )

        XCTAssertEqual(nextShelf.map(\.id), ["second"])
        XCTAssertEqual(newContext.map(\.id), ["first", "second"])
        XCTAssertEqual(products.map(\.accessoryID), ["first", "second"])
    }

    func testConfigPreservesServerOrderAndVisibility() {
        let rows: [[AnyHashable: Any]] = [
            ["id": NSNumber(value: 17), "visible": NSNumber(value: true)],
            ["id": NSNumber(value: 12), "visible": NSNumber(value: false)],
            ["id": NSNumber(value: 7), "visible": NSNumber(value: true)],
        ]

        let config = HomeModelAdapter.config(
            sections: rows,
            titleViewMode: "location",
            premiumCareVisible: true,
            novaFloatingVisible: false,
            backgroundGlowsFaded: true,
            pureLensVisible: true,
            fromCache: false
        )

        XCTAssertEqual(config.orderedSectionIDs, [17, 12, 7])
        XCTAssertTrue(config.isVisible(17))
        XCTAssertFalse(config.isVisible(12))
        XCTAssertTrue(config.isVisible(7))
        XCTAssertFalse(config.novaFloatingVisible)
        XCTAssertTrue(config.backgroundGlowsFaded)
    }

    func testConfigDropsDuplicateSectionIdentifiers() {
        let rows: [[AnyHashable: Any]] = [
            ["id": NSNumber(value: 7), "visible": NSNumber(value: true)],
            ["id": NSNumber(value: 7), "visible": NSNumber(value: false)],
            ["id": NSNumber(value: 18), "visible": NSNumber(value: true)],
        ]

        let config = HomeModelAdapter.config(
            sections: rows,
            titleViewMode: "search",
            premiumCareVisible: true,
            novaFloatingVisible: true,
            backgroundGlowsFaded: false,
            pureLensVisible: true,
            fromCache: true
        )

        XCTAssertEqual(config.orderedSectionIDs, [7, 18])
        XCTAssertTrue(config.isVisible(7))
        XCTAssertTrue(config.cameFromCache)
    }

    func testConfigPreservesFutureSectionMetadataWithoutRenderingItByDefault() {
        let rows: [[AnyHashable: Any]] = [
            [
                "id": NSNumber(value: 27),
                "visible": NSNumber(value: true),
                "type": "futureCareSurface",
                "accent": "CB2654",
            ],
        ]

        let config = HomeModelAdapter.config(
            sections: rows,
            titleViewMode: "unsupported",
            premiumCareVisible: true,
            novaFloatingVisible: true,
            backgroundGlowsFaded: false,
            pureLensVisible: true,
            fromCache: false
        )

        XCTAssertEqual(config.orderedSectionIDs, [27])
        XCTAssertEqual(config.section(withID: 27)?.type, "futureCareSurface")
        XCTAssertEqual(
            config.section(withID: 27)?.metadata["accent"] as? String,
            "CB2654"
        )
        XCTAssertEqual(config.titleViewMode, "location")
    }

    func testPremiumCareFeatureFlagCannotReenableHiddenSection() {
        let rows: [[AnyHashable: Any]] = [
            ["id": NSNumber(value: 9), "visible": NSNumber(value: true)],
            ["id": NSNumber(value: 10), "visible": NSNumber(value: true)],
        ]

        let config = HomeModelAdapter.config(
            sections: rows,
            titleViewMode: "search",
            premiumCareVisible: false,
            novaFloatingVisible: true,
            backgroundGlowsFaded: true,
            pureLensVisible: true,
            fromCache: false
        )

        XCTAssertFalse(config.isVisible(9))
        XCTAssertTrue(config.isVisible(10))
    }

    func testLocationRequiresBothCoordinateComponents() {
        var location = HomeLocationModel()
        XCTAssertFalse(location.hasCoordinate)

        location.latitude = CLLocationDegrees(25.2854)
        XCTAssertFalse(location.hasCoordinate)

        location.longitude = CLLocationDegrees(51.5310)
        XCTAssertTrue(location.hasCoordinate)
    }

    func testProvisionsCareLayoutKeepsShopFeaturedBesideTwoByTwoActionGrid() {
        XCTAssertEqual(PPProvisionsCareLayout.featuredActionID, "shop")
        XCTAssertEqual(
            PPProvisionsCareLayout.gridColumns,
            [["food", "pharmacy"], ["vet", "services"]]
        )
        XCTAssertEqual(PPProvisionsCareLayout.compactRowCount, 2)
        XCTAssertEqual(PPProvisionsCareLayout.innerSectionSpacing, 8)
        XCTAssertEqual(PPProvisionsCareLayout.featuredToGridSpacing, 8)
        XCTAssertEqual(
            PPProvisionsCareLayout.preservedFeaturedCardWidth(totalWidth: 320),
            104,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PPProvisionsCareLayout.compactCardWidth(totalWidth: 320),
            100,
            accuracy: 0.001
        )
    }

    func testProvisionsCareLayoutTwoColumnFeaturedCardGeometry() {
        let totalWidth: CGFloat = 320
        let single = PPProvisionsCareLayout.singleColumnWidth(totalWidth: totalWidth)
        let featured = PPProvisionsCareLayout.twoColumnFeaturedCardWidth(totalWidth: totalWidth)
        let spacing = PPProvisionsCareLayout.innerSectionSpacing

        // Row 1: 2-column featured card + spacing + single column card == totalWidth
        XCTAssertEqual(featured + spacing + single, totalWidth, accuracy: 0.001)
        // Row 2: 3 single column cards + 2 spacings == totalWidth
        XCTAssertEqual(single * 3 + spacing * 2, totalWidth, accuracy: 0.001)
        XCTAssertEqual(PPProvisionsCareLayout.row1SecondaryActionID, "food")
        XCTAssertEqual(PPProvisionsCareLayout.row2ActionIDs, ["pharmacy", "vet", "services"])
        XCTAssertEqual(PPProvisionsCareLayout.compactCardHeight, 112)
        XCTAssertEqual(PPProvisionsCareLayout.featuredCardHeight, 232)
    }

    func testFeaturedShopUsesLivingCommercePortalAnimationContract() {
        XCTAssertEqual(
            PPProvisionsCareLayout.featuredLottieResourceName,
            "LottieAnimations/Shop.json"
        )
        XCTAssertEqual(
            PPProvisionsCareLayout.featuredLottieStoragePath,
            "LottieAnimations/Shop.json"
        )
        XCTAssertEqual(PPProvisionsCareLayout.featuredLottieFallbackName, "Shop2.json")
        XCTAssertTrue(PPProvisionsCareLayout.featuredPrefersFirebaseSource)
        XCTAssertEqual(PPProvisionsCareLayout.featuredArtworkSide, 80)
    }

    func testHomeCategoryIndicatorSymbolResolvesPetSFSymbolWithFallback() {
        func makeCategory(title: String, raw: NSObject = NSObject()) -> HomeCategoryModel {
            HomeCategoryModel(
                id: "test-\(title)",
                title: title,
                imageURL: nil,
                heroImageURL: nil,
                localImage: nil,
                accent: .ppPrimary,
                raw: raw
            )
        }

        // Nil category ("All" selection) falls back to pawprint.fill
        XCTAssertEqual(HomeCategoryModel.indicatorSymbol(for: nil), "pawprint.fill")

        // Dogs (English and Arabic) resolve to dog.fill
        let dogCategoryEn = makeCategory(title: "Dogs")
        let dogCategoryAr = makeCategory(title: "الكلاب")
        XCTAssertEqual(dogCategoryEn.indicatorSymbol, "dog.fill")
        XCTAssertEqual(dogCategoryAr.indicatorSymbol, "dog.fill")
        XCTAssertEqual(HomeCategoryModel.indicatorSymbol(for: dogCategoryEn), "dog.fill")

        // Cats (English and Arabic) resolve to cat.fill
        let catCategoryEn = makeCategory(title: "Cats")
        let catCategoryAr = makeCategory(title: "القطط")
        XCTAssertEqual(catCategoryEn.indicatorSymbol, "cat.fill")
        XCTAssertEqual(catCategoryAr.indicatorSymbol, "cat.fill")

        // Birds (English and Arabic) resolve to bird.fill
        let birdCategoryEn = makeCategory(title: "Birds")
        let birdCategoryAr = makeCategory(title: "الطيور")
        XCTAssertEqual(birdCategoryEn.indicatorSymbol, "bird.fill")
        XCTAssertEqual(birdCategoryAr.indicatorSymbol, "bird.fill")

        // Fish (English and Arabic) resolve to fish.fill
        let fishCategoryEn = makeCategory(title: "Fish")
        let fishCategoryAr = makeCategory(title: "الأسماك")
        XCTAssertEqual(fishCategoryEn.indicatorSymbol, "fish.fill")
        XCTAssertEqual(fishCategoryAr.indicatorSymbol, "fish.fill")

        // Rabbits resolve to hare.fill
        let rabbitCategory = makeCategory(title: "أرانب")
        XCTAssertEqual(rabbitCategory.indicatorSymbol, "hare.fill")

        // Unknown category gracefully falls back to pawprint.fill
        let unknownCategory = makeCategory(title: "Miscellaneous")
        XCTAssertEqual(unknownCategory.indicatorSymbol, "pawprint.fill")
    }
}
