# PurePetsLayoutKit

A SwiftUI-first, iOS 15+ collection-layout package replacing the legacy `PPCollectionLayoutManager` and `PPPinterestLayout` implementations while retaining an Objective-C-compatible migration bridge.

## What is fixed

- Uses the collection view/container's real width instead of `UIScreen.main.bounds`.
- Calculates every item from its own image ratio; no first-item global sizing.
- Preserves the complete source image ratio and removes the old `0.78...0.92` forced crop.
- Supports nested/multi-section data instead of indexing every section through `items[indexPath.item]`.
- Allows same-mode invalidation after asynchronous image metadata arrives.
- Uses deterministic shortest-column masonry placement with stable tie-breaking.
- Does not force every Pinterest cell to be at least square.
- Respects adjusted content insets, rotation, split view, safe areas, RTL, Dynamic Type, VoiceOver ordering, Reduce Motion, and Reduce Transparency.
- Uses lazy SwiftUI containers for smooth scrolling and bounded view creation.

## Modules

- `PPLayoutContainer`: SwiftUI list, adaptive grid, carousel, and masonry host.
- `PPLayoutItemDescriptor`: layout metadata independent of business models.
- `PPPremiumCardSurface`: reusable native card surface and press feedback.
- `PPCollectionStateView`: loading, empty, and error presentation.
- `PPImageAspectRegistry`: async image dimension updates.
- `PPCollectionLayoutManager`: Objective-C runtime-compatible UIKit bridge.
- `PPPinterestLayout`: corrected UIKit masonry implementation in Swift.

## Integration strategy

1. Add the package or source folder to the iOS target.
2. Keep all model, Firebase, permission, navigation, delegate, and action code unchanged.
3. Map `PPUniversalCellViewModel` to `PPLayoutItemDescriptor` in one adapter extension.
4. Migrate screens incrementally to `PPLayoutContainer`.
5. For screens that must remain UIKit, remove only the two old `.m` files from Compile Sources and use the bridge classes with the existing Objective-C headers.
6. When an image loader discovers pixel dimensions, update the model/registry and invalidate only affected items.

See `MIGRATION.md` and `INTEGRATION_PROMPT.md`.
