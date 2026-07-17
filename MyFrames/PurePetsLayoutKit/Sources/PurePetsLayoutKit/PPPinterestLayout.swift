import UIKit

/// Drop-in UIKit compatibility layout implemented in Swift.
/// It preserves the Objective-C runtime class name while fixing width, section, ratio, and invalidation defects.
@objc(PPPinterestLayout)
@objcMembers
public final class PPPinterestLayout: UICollectionViewLayout {
    public weak var delegate: AnyObject?
    public var columnCount: UInt = 0 { didSet { invalidateIfChanged(oldValue, columnCount) } }
    public var spacing: CGFloat = 16 {
        didSet {
            guard oldValue != spacing else { return }
            if minimumInteritemSpacing != spacing { minimumInteritemSpacing = spacing }
            if minimumLineSpacing != spacing { minimumLineSpacing = spacing }
            invalidateLayout()
        }
    }
    public var minimumInteritemSpacing: CGFloat = 16 { didSet { invalidateIfChanged(oldValue, minimumInteritemSpacing) } }
    public var minimumLineSpacing: CGFloat = 16 { didSet { invalidateIfChanged(oldValue, minimumLineSpacing) } }
    public var sectionInset: UIEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16) {
        didSet { if oldValue != sectionInset { invalidateLayout() } }
    }
    public var heightCache: NSMutableDictionary = [:]

    @nonobjc public var heightProvider: ((IndexPath, CGFloat) -> CGFloat)?
    @nonobjc public var stableIDProvider: ((IndexPath) -> String?)?

    private var attributesByIndexPath: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var orderedAttributes: [UICollectionViewLayoutAttributes] = []
    private var calculatedContentSize: CGSize = .zero
    private var preparedWidth: CGFloat = -1

    public override func prepare() {
        super.prepare()
        guard let collectionView else {
            reset()
            return
        }

        let adjusted = collectionView.adjustedContentInset
        let availableWidth = max(1, collectionView.bounds.width - adjusted.left - adjusted.right)
        let sections = collectionView.numberOfSections
        guard sections > 0 else {
            reset(contentWidth: collectionView.bounds.width)
            return
        }

        attributesByIndexPath.removeAll(keepingCapacity: true)
        orderedAttributes.removeAll(keepingCapacity: true)
        preparedWidth = availableWidth

        let columns = resolvedColumnCount(for: availableWidth)
        let usableWidth = max(
            1,
            availableWidth
                - sectionInset.left
                - sectionInset.right
                - CGFloat(columns - 1) * minimumInteritemSpacing
        )
        let itemWidth = floor(usableWidth / CGFloat(columns))
        var sectionOriginY: CGFloat = 0

        for section in 0..<sections {
            let count = collectionView.numberOfItems(inSection: section)
            var columnHeights = Array(repeating: sectionOriginY + sectionInset.top, count: columns)

            for item in 0..<count {
                let indexPath = IndexPath(item: item, section: section)
                let targetColumn = columnHeights.enumerated().min { lhs, rhs in
                    lhs.element == rhs.element ? lhs.offset < rhs.offset : lhs.element < rhs.element
                }?.offset ?? 0
                let requestedHeight = resolvedHeight(for: indexPath, width: itemWidth)
                let itemHeight = max(1, requestedHeight.isFinite ? requestedHeight : itemWidth)
                let x = sectionInset.left + CGFloat(targetColumn) * (itemWidth + minimumInteritemSpacing)
                let y = columnHeights[targetColumn]

                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = pixelAligned(
                    CGRect(x: x, y: y, width: itemWidth, height: itemHeight),
                    scale: collectionView.window?.screen.scale ?? UIScreen.main.scale
                )
                attributesByIndexPath[indexPath] = attributes
                orderedAttributes.append(attributes)
                columnHeights[targetColumn] = attributes.frame.maxY + minimumLineSpacing
            }

            let sectionBottom = (columnHeights.max() ?? sectionOriginY)
                - (count > 0 ? minimumLineSpacing : 0)
                + sectionInset.bottom
            sectionOriginY = max(sectionOriginY, sectionBottom)
        }

        calculatedContentSize = CGSize(
            width: collectionView.bounds.width,
            height: max(sectionOriginY, collectionView.bounds.height)
        )
    }

    public override var collectionViewContentSize: CGSize {
        calculatedContentSize
    }

    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        orderedAttributes.filter { $0.frame.intersects(rect) }
    }

    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesByIndexPath[indexPath]
    }

    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        let adjusted = collectionView.adjustedContentInset
        let newWidth = max(1, newBounds.width - adjusted.left - adjusted.right)
        return abs(newWidth - preparedWidth) > 0.5
    }

    public override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        super.invalidationContext(forBoundsChange: newBounds)
    }

    private func resolvedColumnCount(for width: CGFloat) -> Int {
        if columnCount > 0 { return max(1, Int(columnCount)) }
        let targetWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 220 : 176
        let automatic = Int(floor((width + minimumInteritemSpacing) / (targetWidth + minimumInteritemSpacing)))
        return max(UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2, automatic)
    }

    private func resolvedHeight(for indexPath: IndexPath, width: CGFloat) -> CGFloat {
        let requestedHeight: CGFloat
        if let heightProvider {
            requestedHeight = heightProvider(indexPath, width)
        } else {
            guard let object = delegate as? NSObject else {
                return boundedHeight(width, for: width)
            }
            let selector = NSSelectorFromString("collectionView:layout:heightForItemAtIndexPath:withWidth:")
            guard object.responds(to: selector), let collectionView else {
                return boundedHeight(width, for: width)
            }

            typealias Function = @convention(c) (
                AnyObject,
                Selector,
                UICollectionView,
                PPPinterestLayout,
                NSIndexPath,
                CGFloat
            ) -> CGFloat
            let implementation = object.method(for: selector)
            let function = unsafeBitCast(implementation, to: Function.self)
            requestedHeight = function(
                object,
                selector,
                collectionView,
                self,
                indexPath as NSIndexPath,
                width
            )
        }

        return boundedHeight(requestedHeight, for: width)
    }

    private func boundedHeight(_ proposedHeight: CGFloat, for width: CGFloat) -> CGFloat {
        let safeWidth = max(width, 1)
        let minimumHeight: CGFloat = 130
        let isAccessibilityCategory = collectionView?.traitCollection.preferredContentSizeCategory.isAccessibilityCategory == true
        let dynamicTypeAllowance: CGFloat = isAccessibilityCategory ? 96 : 0
        let maximumHeight = max(280, safeWidth * 2.1 + dynamicTypeAllowance)
        let finiteHeight = proposedHeight.isFinite && proposedHeight > 0
            ? proposedHeight
            : safeWidth
        return min(max(finiteHeight, minimumHeight), maximumHeight)
    }

    private func reset(contentWidth: CGFloat = 0) {
        attributesByIndexPath.removeAll(keepingCapacity: false)
        orderedAttributes.removeAll(keepingCapacity: false)
        calculatedContentSize = CGSize(width: contentWidth, height: 0)
        preparedWidth = -1
    }

    private func invalidateIfChanged<T: Equatable>(_ oldValue: T, _ newValue: T) {
        if oldValue != newValue { invalidateLayout() }
    }

    private func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let safeScale = max(scale, 1)
        func align(_ value: CGFloat) -> CGFloat { (value * safeScale).rounded(.down) / safeScale }
        return CGRect(
            x: align(rect.origin.x),
            y: align(rect.origin.y),
            width: align(rect.size.width),
            height: align(rect.size.height)
        )
    }
}
