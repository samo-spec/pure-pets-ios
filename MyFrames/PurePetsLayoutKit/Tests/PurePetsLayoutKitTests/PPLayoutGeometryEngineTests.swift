import XCTest
@testable import PurePetsLayoutKit

final class PPLayoutGeometryEngineTests: XCTestCase {
    func testMasonryPreservesRealPortraitRatio() {
        let descriptor = PPLayoutItemDescriptor(
            id: "portrait",
            imageAspectRatio: 4.0 / 3.0,
            estimatedBodyHeight: 100
        )
        let result = PPLayoutGeometryEngine.masonry(
            descriptors: [descriptor],
            containerWidth: 390,
            columns: 2,
            configuration: .premium
        )
        let frame = try XCTUnwrap(result.placements.first?.frame)
        XCTAssertGreaterThan(frame.height, frame.width)
    }

    func testMasonryFramesNeverOverlapWithinAColumn() {
        let descriptors = (0..<30).map {
            PPLayoutItemDescriptor(
                id: "\($0)",
                imageAspectRatio: CGFloat(($0 % 5) + 3) / 5,
                estimatedBodyHeight: 96
            )
        }
        let result = PPLayoutGeometryEngine.masonry(
            descriptors: descriptors,
            containerWidth: 430,
            columns: 2,
            configuration: .premium
        )

        for lhs in result.placements {
            for rhs in result.placements where lhs.index != rhs.index {
                XCTAssertFalse(lhs.frame.intersects(rhs.frame))
            }
        }
    }

    func testGridUsesPerItemHeightsInsteadOfFirstItemHeight() {
        let descriptors = [
            PPLayoutItemDescriptor(id: "wide", imageAspectRatio: 0.55, estimatedBodyHeight: 90),
            PPLayoutItemDescriptor(id: "portrait", imageAspectRatio: 1.6, estimatedBodyHeight: 90)
        ]
        let result = PPLayoutGeometryEngine.rowGrid(
            descriptors: descriptors,
            containerWidth: 390,
            columns: 2,
            mode: .vertical,
            configuration: .premium
        )
        XCTAssertNotEqual(result.placements[0].frame.height, result.placements[1].frame.height)
    }

    func testEmptyMasonryHasZeroHeight() {
        let result = PPLayoutGeometryEngine.masonry(
            descriptors: [],
            containerWidth: 390,
            columns: 2,
            configuration: .premium
        )
        XCTAssertEqual(result.contentSize.height, 0)
    }
}
