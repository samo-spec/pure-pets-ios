# Legacy Layout Audit

The original implementation had several deterministic geometry defects:

1. `PPUniversalAdsPinterestAspectRatio` forced every source ratio into `0.78...0.92`, guaranteeing crop for many portrait and landscape assets when the image view used aspect fill.
2. Full-width, horizontal-row, and vertical modes derived every cell size from `items.firstObject`.
3. Standard layouts used `UIScreen.main.bounds.width` rather than the collection view's effective width.
4. `applyLayoutMode` returned early for the current mode, preventing recalculation after asynchronous image dimensions arrived.
5. Pinterest item resolution ignored `indexPath.section` and read `items[indexPath.item]`.
6. Pinterest forced `itemHeight >= itemWidth`, overriding valid short card heights.
7. `prepareLayout` rebuilt and enumerated an unordered dictionary for visible attributes.
8. Width invalidation did not explicitly account for adjusted content insets and had no targeted async metadata API.
9. `PPHeightCacheManager` persisted index-path heights through `NSUserDefaults`, which becomes stale after reordering and is unsuitable for volatile layout geometry.
10. The code contained duplicated spacing/height constants and separate layout paths with inconsistent behavior.

The replacement removes ratio clamping, calculates every item independently, supports nested sections, uses stable deterministic placement, invalidates on effective width changes, exposes targeted image-metadata invalidation, and centralizes layout configuration.
