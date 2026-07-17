import UIKit

final class PPAdaptiveCollectionViewLayout: UICollectionViewLayout {
    enum Strategy {
        case list
        case horizontalRow
        case rowGrid
        case masonry
    }

    var strategy: Strategy = .list
    var sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    var horizontalSpacing: CGFloat = 16
    var verticalSpacing: CGFloat = 16
    var minimumColumnWidth: CGFloat = 166
    var maximumColumns: Int = 4
    var fixedColumns: Int?
    var heightProvider: ((IndexPath, CGFloat) -> CGFloat)?

    private var attributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var ordered: [UICollectionViewLayoutAttributes] = []
    private var contentSize: CGSize = .zero
    private var preparedWidth: CGFloat = -1

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }

        let adjusted = collectionView.adjustedContentInset
        let width = max(1, collectionView.bounds.width - adjusted.left - adjusted.right)
        preparedWidth = width
        attributes.removeAll(keepingCapacity: true)
        ordered.removeAll(keepingCapacity: true)

        let columns = resolvedColumns(width: width)
        let usableWidth = max(
            1,
            width - sectionInset.left - sectionInset.right - CGFloat(columns - 1) * horizontalSpacing
        )
        let itemWidth = floor(usableWidth / CGFloat(columns))
        var originY: CGFloat = 0

        for section in 0..<collectionView.numberOfSections {
            let count = collectionView.numberOfItems(inSection: section)
            switch strategy {
            case .masonry:
                originY = layoutMasonrySection(
                    section: section,
                    count: count,
                    originY: originY,
                    columns: columns,
                    itemWidth: itemWidth
                )
            case .rowGrid, .list, .horizontalRow:
                originY = layoutRowSection(
                    section: section,
                    count: count,
                    originY: originY,
                    columns: columns,
                    itemWidth: itemWidth
                )
            }
        }

        contentSize = CGSize(width: collectionView.bounds.width, height: max(originY, collectionView.bounds.height))
    }

    override var collectionViewContentSize: CGSize { contentSize }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        ordered.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributes[indexPath]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        let adjusted = collectionView.adjustedContentInset
        let width = max(1, newBounds.width - adjusted.left - adjusted.right)
        return abs(width - preparedWidth) > 0.5
    }

    private func layoutMasonrySection(
        section: Int,
        count: Int,
        originY: CGFloat,
        columns: Int,
        itemWidth: CGFloat
    ) -> CGFloat {
        var heights = Array(repeating: originY + sectionInset.top, count: columns)
        for item in 0..<count {
            let indexPath = IndexPath(item: item, section: section)
            let column = heights.enumerated().min { lhs, rhs in
                lhs.element == rhs.element ? lhs.offset < rhs.offset : lhs.element < rhs.element
            }?.offset ?? 0
            let height = resolvedHeight(indexPath: indexPath, width: itemWidth)
            let x = sectionInset.left + CGFloat(column) * (itemWidth + horizontalSpacing)
            let frame = CGRect(x: x, y: heights[column], width: itemWidth, height: height).integral
            store(indexPath: indexPath, frame: frame)
            heights[column] = frame.maxY + verticalSpacing
        }
        return (heights.max() ?? originY) - (count > 0 ? verticalSpacing : 0) + sectionInset.bottom
    }

    private func layoutRowSection(
        section: Int,
        count: Int,
        originY: CGFloat,
        columns: Int,
        itemWidth: CGFloat
    ) -> CGFloat {
        var y = originY + sectionInset.top
        var item = 0
        while item < count {
            let end = min(item + columns, count)
            var row: [(IndexPath, CGFloat)] = []
            for current in item..<end {
                let indexPath = IndexPath(item: current, section: section)
                row.append((indexPath, resolvedHeight(indexPath: indexPath, width: itemWidth)))
            }
            let rowHeight = row.map(\.1).max() ?? 0
            for (column, entry) in row.enumerated() {
                let x = sectionInset.left + CGFloat(column) * (itemWidth + horizontalSpacing)
                store(
                    indexPath: entry.0,
                    frame: CGRect(x: x, y: y, width: itemWidth, height: entry.1).integral
                )
            }
            y += rowHeight + verticalSpacing
            item = end
        }
        return y - (count > 0 ? verticalSpacing : 0) + sectionInset.bottom
    }

    private func store(indexPath: IndexPath, frame: CGRect) {
        let value = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        value.frame = frame
        attributes[indexPath] = value
        ordered.append(value)
    }

    private func resolvedHeight(indexPath: IndexPath, width: CGFloat) -> CGFloat {
        let raw = heightProvider?(indexPath, width) ?? width
        return max(1, raw.isFinite ? raw : width)
    }

    private func resolvedColumns(width: CGFloat) -> Int {
        switch strategy {
        case .list, .horizontalRow:
            return 1
        case .rowGrid, .masonry:
            if let fixedColumns { return max(1, fixedColumns) }
            let usable = max(1, width - sectionInset.left - sectionInset.right)
            let candidate = Int(floor((usable + horizontalSpacing) / (minimumColumnWidth + horizontalSpacing)))
            return min(maximumColumns, max(2, candidate))
        }
    }
}
