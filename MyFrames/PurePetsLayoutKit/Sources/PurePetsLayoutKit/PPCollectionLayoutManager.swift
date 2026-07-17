import UIKit

/// Objective-C-compatible bridge with the exact legacy runtime class name and selectors.
/// Remove the legacy `.m` implementations from Compile Sources before enabling this file.
@objc(PPCollectionLayoutManager)
@objcMembers
public final class PPCollectionLayoutManager: NSObject {
    public weak var delegate: AnyObject?
    public var currentLayoutMode: Int = 0
    public var items: NSArray?

    /// Optional project-level overrides. They let the existing business model remain untouched.
    @nonobjc public var itemAtIndexPath: ((IndexPath) -> Any?)?
    @nonobjc public var descriptorProvider: ((Any, IndexPath) -> PPLayoutItemDescriptor)?
    @nonobjc public var stableIDProvider: ((Any, IndexPath) -> String)?

    private let configuration = PPLayoutConfiguration.premium

    @objc(layoutForMode:)
    public func layoutForMode(_ rawMode: Int) -> UICollectionViewLayout {
        let mode = PPLayoutMode(legacyRawValue: rawMode)

        if mode == .dataViewFullDetails,
           let layoutClass = NSClassFromString("BBDataViewFullDetailsLayout") as? NSObject.Type,
           let layout = layoutClass.init() as? UICollectionViewLayout {
            return layout
        }

        if mode == .carousel {
            return makeCarouselLayout()
        }

        if mode == .pinterest {
            let layout = PPPinterestLayout()
            layout.columnCount = 0
            layout.minimumInteritemSpacing = configuration.horizontalSpacing
            layout.minimumLineSpacing = configuration.verticalSpacing
            layout.sectionInset = UIEdgeInsets(
                top: configuration.verticalPadding,
                left: configuration.horizontalPadding,
                bottom: configuration.verticalPadding,
                right: configuration.horizontalPadding
            )
            layout.delegate = self
            return layout
        }

        let layout = PPAdaptiveCollectionViewLayout()
        layout.strategy = strategy(for: mode)
        layout.sectionInset = UIEdgeInsets(
            top: configuration.verticalPadding,
            left: configuration.horizontalPadding,
            bottom: configuration.verticalPadding,
            right: configuration.horizontalPadding
        )
        layout.horizontalSpacing = configuration.horizontalSpacing
        layout.verticalSpacing = mode == .horizontalRow ? 12 : configuration.verticalSpacing
        layout.minimumColumnWidth = configuration.minimumGridColumnWidth
        layout.maximumColumns = configuration.maximumGridColumns
        layout.heightProvider = { [weak self] indexPath, width in
            self?.height(at: indexPath, width: width, mode: mode) ?? width
        }
        return layout
    }

    public func listLayout() -> UICollectionViewLayout {
        layoutForMode(PPLayoutMode.fullWidth.rawValue)
    }

    public func horizontalRowLayout() -> UICollectionViewLayout {
        layoutForMode(PPLayoutMode.horizontalRow.rawValue)
    }

    public func verticalLayout() -> UICollectionViewLayout {
        layoutForMode(PPLayoutMode.vertical.rawValue)
    }

    public func pinterestLayout() -> UICollectionViewLayout {
        layoutForMode(PPLayoutMode.pinterest.rawValue)
    }

    public func fullDetailsLayout() -> UICollectionViewLayout {
        layoutForMode(PPLayoutMode.dataViewFullDetails.rawValue)
    }

    @objc(applyLayoutMode:toCollectionView:animated:)
    public func applyLayoutMode(
        _ rawMode: Int,
        to collectionView: UICollectionView,
        animated: Bool
    ) {
        let previousMode = currentLayoutMode
        let newLayout = layoutForMode(rawMode)
        let anchor = captureAnchor(in: collectionView)
        currentLayoutMode = rawMode

        let shouldAnimate = animated
            && collectionView.window != nil
            && !UIAccessibility.isReduceMotionEnabled
            && previousMode != rawMode

        let completion: (Bool) -> Void = { [weak collectionView] _ in
            guard let collectionView else { return }
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
            self.restore(anchor: anchor, in: collectionView)
        }

        if shouldAnimate {
            collectionView.setCollectionViewLayout(newLayout, animated: true, completion: completion)
        } else {
            collectionView.setCollectionViewLayout(newLayout, animated: false)
            completion(true)
        }
    }

    /// Call after async image metadata changes. Unlike the legacy implementation, same-mode refreshes are supported.
    @objc(invalidateLayoutIn:indexPaths:)
    public func invalidateLayout(in collectionView: UICollectionView, indexPaths: [IndexPath]? = nil) {
        if let indexPaths, !indexPaths.isEmpty {
            collectionView.performBatchUpdates {
                collectionView.reloadItems(at: indexPaths)
            }
        }
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func strategy(for mode: PPLayoutMode) -> PPAdaptiveCollectionViewLayout.Strategy {
        switch mode {
        case .horizontalRow:
            return .horizontalRow
        case .vertical, .market, .mainKinds, .allKinds:
            return .rowGrid
        case .pinterest:
            return .masonry
        default:
            return .list
        }
    }

    private func height(at indexPath: IndexPath, width: CGFloat, mode: PPLayoutMode) -> CGFloat {
        if mode == .vertical {
            return fixedVerticalCardHeight(for: width)
        }

        guard let item = resolvedItem(at: indexPath) else {
            return fallbackHeight(width: width, mode: mode)
        }
        let descriptor = descriptorProvider?(item, indexPath) ?? runtimeDescriptor(for: item, indexPath: indexPath)
        return descriptor.estimatedHeight(for: width, mode: mode)
    }

    private func fixedVerticalCardHeight(for width: CGFloat) -> CGFloat {
        let safeWidth = max(width, 1)
        let bottomContentHeight: CGFloat = 128
        let accessibilityAllowance: CGFloat =
            UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
                ? 96
                : 0
        return ceil(safeWidth + bottomContentHeight + accessibilityAllowance)
    }

    @objc(collectionView:layout:heightForItemAtIndexPath:withWidth:)
    public func collectionView(
        _ collectionView: UICollectionView,
        layout: PPPinterestLayout,
        heightForItemAt indexPath: IndexPath,
        withWidth width: CGFloat
    ) -> CGFloat {
        if let delegatedHeight = invokeManagerDelegateHeight(
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath,
            width: width
        ), delegatedHeight.isFinite, delegatedHeight > 0 {
            return delegatedHeight
        }
        return height(at: indexPath, width: width, mode: .pinterest)
    }

    @objc(collectionView:layout:stableIDForItemAtIndexPath:)
    public func collectionView(
        _ collectionView: UICollectionView,
        layout: PPPinterestLayout,
        stableIDForItemAt indexPath: IndexPath
    ) -> String? {
        stableID(at: indexPath)
    }


    private func invokeManagerDelegateHeight(
        collectionView: UICollectionView,
        layout: PPPinterestLayout,
        indexPath: IndexPath,
        width: CGFloat
    ) -> CGFloat? {
        guard let object = delegate as? NSObject, object !== self else { return nil }
        let selector = NSSelectorFromString("collectionView:layout:heightForItemAtIndexPath:withWidth:")
        guard object.responds(to: selector) else { return nil }

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
        return function(object, selector, collectionView, layout, indexPath as NSIndexPath, width)
    }

    private func stableID(at indexPath: IndexPath) -> String? {
        guard let item = resolvedItem(at: indexPath) else { return nil }
        return stableIDProvider?(item, indexPath) ?? runtimeDescriptor(for: item, indexPath: indexPath).id
    }

    private func resolvedItem(at indexPath: IndexPath) -> Any? {
        if let itemAtIndexPath { return itemAtIndexPath(indexPath) }
        guard let items else { return nil }

        if indexPath.section < items.count,
           let sectionItems = items[indexPath.section] as? NSArray,
           indexPath.item < sectionItems.count {
            return sectionItems[indexPath.item]
        }

        guard indexPath.section == 0, indexPath.item < items.count else { return nil }
        return items[indexPath.item]
    }

    private func runtimeDescriptor(for item: Any, indexPath: IndexPath) -> PPLayoutItemDescriptor {
        let object = item as AnyObject
        let imageSize = safeValue(object, key: "imageSize") as? NSValue
        let size = imageSize?.cgSizeValue ?? .zero
        let modelRatio = safeNumber(object, key: "preferredAspectRatio")?.doubleValue
        let title = safeString(object, key: "title") ?? ""
        let subtitle = safeString(object, key: "subtitle") ?? ""
        let location = safeString(object, key: "location") ?? ""
        let id = safeString(object, key: "identifier")
            ?? safeString(object, key: "ID")
            ?? safeString(object, key: "objectID")
            ?? "\(indexPath.section)-\(indexPath.item)"

        let imageRatio: CGFloat? = size.width > 0 && size.height > 0
            ? size.height / size.width
            : nil
        let preferredRatio: CGFloat? = modelRatio.map { CGFloat($0) }
        let bodyHeight: CGFloat = modeIndependentBodyHeight(
            title: title,
            subtitle: subtitle,
            location: location
        )

        return PPLayoutItemDescriptor(
            id: id,
            imageAspectRatio: imageRatio,
            preferredAspectRatio: preferredRatio,
            estimatedBodyHeight: bodyHeight - 70,
            minimumCardHeight: 130,
            titleLineCount: title.count > 38 ? 2 : 1,
            hasSubtitle: !subtitle.isEmpty || !location.isEmpty,
            hasBadge: !subtitle.isEmpty
        )
    }

    private func modeIndependentBodyHeight(title: String, subtitle: String, location: String) -> CGFloat {
        var value: CGFloat = 112
        if title.count > 38 { value += 18 }
        if !subtitle.isEmpty || !location.isEmpty { value += 18 }
        if !subtitle.isEmpty { value += 34 }
        return value
    }

    private func safeValue(_ object: AnyObject, key: String) -> Any? {
        guard let object = object as? NSObject else { return nil }
        let selector = NSSelectorFromString(key)
        guard object.responds(to: selector) else { return nil }
        return object.value(forKey: key)
    }

    private func safeNumber(_ object: AnyObject, key: String) -> NSNumber? {
        safeValue(object, key: key) as? NSNumber
    }

    private func safeString(_ object: AnyObject, key: String) -> String? {
        safeValue(object, key: key) as? String
    }

    private func fallbackHeight(width: CGFloat, mode: PPLayoutMode) -> CGFloat {
        switch mode {
        case .horizontalRow: return 206
        case .mainKinds, .allKinds: return 150
        case .carousel: return configuration.carouselHeight
        default: return max(130, width + 112)
        }
    }

    private func makeCarouselLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(configuration.carouselWidthFraction),
            heightDimension: .absolute(configuration.carouselHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = configuration.horizontalSpacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: configuration.verticalPadding,
            leading: configuration.horizontalPadding,
            bottom: configuration.verticalPadding,
            trailing: configuration.horizontalPadding
        )
        return UICollectionViewCompositionalLayout(section: section)
    }

    private struct Anchor {
        let indexPath: IndexPath
        let deltaY: CGFloat
    }

    private func captureAnchor(in collectionView: UICollectionView) -> Anchor? {
        let indexPath = collectionView.indexPathsForVisibleItems.sorted { lhs, rhs in
            lhs.section == rhs.section ? lhs.item < rhs.item : lhs.section < rhs.section
        }.first
        guard let indexPath,
              let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return nil }
        return Anchor(indexPath: indexPath, deltaY: collectionView.contentOffset.y - attributes.frame.minY)
    }

    private func restore(anchor: Anchor?, in collectionView: UICollectionView) {
        guard let anchor,
              let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: anchor.indexPath) else { return }
        let inset = collectionView.adjustedContentInset
        let minimumY = -inset.top
        let maximumY = max(
            minimumY,
            collectionView.contentSize.height - collectionView.bounds.height + inset.bottom
        )
        let target = min(max(attributes.frame.minY + anchor.deltaY, minimumY), maximumY)
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: target), animated: false)
    }
}
