import CoreGraphics
import Foundation

public struct PPMasonryPartition: Equatable, Sendable {
    public let columns: [[Int]]
    public let estimatedColumnHeights: [CGFloat]

    public init(columns: [[Int]], estimatedColumnHeights: [CGFloat]) {
        self.columns = columns
        self.estimatedColumnHeights = estimatedColumnHeights
    }
}

public enum PPMasonryPartitioner {
    /// Stable shortest-column partition. Equal-height ties resolve to the leading column.
    public static func partition(
        descriptors: [PPLayoutItemDescriptor],
        columnCount: Int,
        itemWidth: CGFloat,
        spacing: CGFloat
    ) -> PPMasonryPartition {
        let count = max(1, columnCount)
        var columns = Array(repeating: [Int](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)

        for (index, descriptor) in descriptors.enumerated() {
            let target = heights.enumerated().min { lhs, rhs in
                lhs.element == rhs.element ? lhs.offset < rhs.offset : lhs.element < rhs.element
            }?.offset ?? 0
            columns[target].append(index)
            heights[target] += descriptor.estimatedHeight(for: itemWidth, mode: .pinterest) + spacing
        }

        return PPMasonryPartition(columns: columns, estimatedColumnHeights: heights)
    }
}
