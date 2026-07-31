import CoreLocation
import XCTest
@testable import Pure_Pets

final class PPHomeSwiftUIMigrationTests: XCTestCase {
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
}
