import CoreGraphics
import Foundation

public struct PPLayoutPlacement: Equatable, Sendable {
    public let index: Int
    public let frame: CGRect

    public init(index: Int, frame: CGRect) {
        self.index = index
        self.frame = frame
    }
}

public struct PPLayoutGeometryResult: Equatable, Sendable {
    public let placements: [PPLayoutPlacement]
    public let contentSize: CGSize

    public init(placements: [PPLayoutPlacement], contentSize: CGSize) {
        self.placements = placements
        self.contentSize = contentSize
    }
}

/// Deterministic, side-effect-free geometry used by the UIKit bridge and tests.
public enum PPLayoutGeometryEngine {
    public static func gridColumnCount(
        containerWidth: CGFloat,
        configuration: PPLayoutConfiguration
    ) -> Int {
        let usable = max(1, containerWidth - (configuration.horizontalPadding * 2))
        let candidate = Int(floor((usable + configuration.horizontalSpacing) /
                                  (configuration.minimumGridColumnWidth + configuration.horizontalSpacing)))
        return min(configuration.maximumGridColumns, max(2, candidate))
    }

    public static func masonry(
        descriptors: [PPLayoutItemDescriptor],
        containerWidth: CGFloat,
        columns requestedColumns: Int,
        configuration: PPLayoutConfiguration
    ) -> PPLayoutGeometryResult {
        let columns = max(1, requestedColumns)
        let usableWidth = max(
            1,
            containerWidth
                - configuration.horizontalPadding * 2
                - CGFloat(columns - 1) * configuration.horizontalSpacing
        )
        let itemWidth = floor(usableWidth / CGFloat(columns))
        var heights = Array(repeating: configuration.verticalPadding, count: columns)
        var placements: [PPLayoutPlacement] = []
        placements.reserveCapacity(descriptors.count)

        for (index, descriptor) in descriptors.enumerated() {
            let targetColumn = heights.enumerated().min { lhs, rhs in
                lhs.element == rhs.element ? lhs.offset < rhs.offset : lhs.element < rhs.element
            }?.offset ?? 0
            let height = descriptor.estimatedHeight(for: itemWidth, mode: .pinterest)
            let x = configuration.horizontalPadding
                + CGFloat(targetColumn) * (itemWidth + configuration.horizontalSpacing)
            let y = heights[targetColumn]
            let frame = CGRect(x: x, y: y, width: itemWidth, height: height).integral
            placements.append(PPLayoutPlacement(index: index, frame: frame))
            heights[targetColumn] = frame.maxY + configuration.verticalSpacing
        }

        let maxHeight = heights.max() ?? 0
        let contentHeight = descriptors.isEmpty
            ? 0
            : max(configuration.verticalPadding, maxHeight - configuration.verticalSpacing + configuration.verticalPadding)
        return PPLayoutGeometryResult(
            placements: placements,
            contentSize: CGSize(width: max(containerWidth, 1), height: contentHeight)
        )
    }

    public static func rowGrid(
        descriptors: [PPLayoutItemDescriptor],
        containerWidth: CGFloat,
        columns requestedColumns: Int,
        mode: PPLayoutMode,
        configuration: PPLayoutConfiguration
    ) -> PPLayoutGeometryResult {
        let columns = max(1, requestedColumns)
        let usableWidth = max(
            1,
            containerWidth
                - configuration.horizontalPadding * 2
                - CGFloat(columns - 1) * configuration.horizontalSpacing
        )
        let itemWidth = floor(usableWidth / CGFloat(columns))
        var placements: [PPLayoutPlacement] = []
        placements.reserveCapacity(descriptors.count)
        var y = configuration.verticalPadding

        var index = 0
        while index < descriptors.count {
            let end = min(index + columns, descriptors.count)
            let row = Array(descriptors[index..<end])
            let rowHeights = row.map { $0.estimatedHeight(for: itemWidth, mode: mode) }
            let rowHeight = rowHeights.max() ?? 0

            for localIndex in row.indices {
                let absoluteIndex = index + localIndex
                let x = configuration.horizontalPadding
                    + CGFloat(localIndex) * (itemWidth + configuration.horizontalSpacing)
                let frame = CGRect(
                    x: x,
                    y: y,
                    width: itemWidth,
                    height: rowHeights[localIndex]
                ).integral
                placements.append(PPLayoutPlacement(index: absoluteIndex, frame: frame))
            }

            y += rowHeight + configuration.verticalSpacing
            index = end
        }

        let contentHeight = descriptors.isEmpty
            ? 0
            : max(configuration.verticalPadding, y - configuration.verticalSpacing + configuration.verticalPadding)
        return PPLayoutGeometryResult(
            placements: placements,
            contentSize: CGSize(width: max(containerWidth, 1), height: contentHeight)
        )
    }
}
