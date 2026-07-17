# Migration Guide

## 1. Add the package

Local Swift Package:

1. Xcode → File → Add Package Dependencies.
2. Add Local… and select `PurePetsLayoutKit`.
3. Link `PurePetsLayoutKit` to the Pure Pets iOS application target.

The deployment target is iOS 15.0.

## 2. UIKit compatibility path

For an incremental migration:

1. Remove `PPCollectionLayoutManager.m` and `PPPinterestLayout.m` from **Build Phases → Compile Sources**. Do not delete them until verification is complete.
2. Keep the compatibility headers, or replace the old headers with the versions in `Compatibility/`.
3. Ensure Objective-C files importing the class can link the Swift module. Xcode should generate `<ProductModuleName>-Swift.h` automatically.
4. Existing Objective-C calls such as `layoutForMode:` and `applyLayoutMode:toCollectionView:animated:` remain valid.
5. Set `manager.items` exactly as before.

## 3. Strong model adapter

Do not leave runtime/KVC extraction as the final production mapping. In the app target, assign a strongly typed descriptor provider:

```swift
layoutManager.descriptorProvider = { item, indexPath in
    guard let vm = item as? PPUniversalCellViewModel else {
        return PPLayoutItemDescriptor(id: "\(indexPath.section)-\(indexPath.item)")
    }

    let realRatio: CGFloat? = vm.imageSize.width > 0 && vm.imageSize.height > 0
        ? vm.imageSize.height / vm.imageSize.width
        : nil

    return PPLayoutItemDescriptor(
        id: vm.stableIdentifier,
        imageAspectRatio: realRatio,
        preferredAspectRatio: vm.preferredAspectRatio > 0 ? vm.preferredAspectRatio : nil,
        estimatedBodyHeight: vm.layoutBodyHeight,
        titleLineCount: vm.title.count > 38 ? 2 : 1,
        hasSubtitle: !vm.subtitle.isEmpty || !vm.location.isEmpty,
        hasBadge: !vm.subtitle.isEmpty
    )
}
```

Use actual project property names; do not invent or rename model fields.

## 4. Image metadata updates

When the image loader obtains the real pixel size:

```swift
viewModel.imageSize = image.size
layoutManager.invalidateLayout(in: collectionView, indexPaths: [indexPath])
```

The same layout mode may now be invalidated; the old early return has been removed.

## 5. SwiftUI screen path

Use `PPLayoutContainer` as the layout host and keep business actions in existing coordinators/managers:

```swift
PPLayoutContainer(
    items: viewModels,
    mode: selectedMode,
    state: screenState,
    descriptor: descriptorForViewModel,
    retry: reload
) { viewModel in
    PPUniversalCardView(
        viewModel: viewModel,
        onFavorite: { existingDelegate.favorite(viewModel) },
        onShare: { existingDelegate.share(viewModel) },
        onDelete: { existingDelegate.delete(viewModel) }
    )
}
```

## 6. Image presentation rule

Use `.fit` unless product design explicitly requires crop:

```swift
PPAsyncMediaSurface(
    url: url,
    aspectRatio: descriptor.resolvedImageAspectRatio,
    contentMode: .fit
)
```

If `.fill` is intentionally selected, cropping is expected and must be approved per screen.

## 7. Acceptance gates

- Build with zero errors and zero new warnings.
- All old layout modes still open and switch correctly.
- No top/bottom crop for `.fit` images across portrait, square, and landscape ratios.
- Multi-section and diffable data sources resolve the correct item.
- Rotation and iPad split view recompute columns and item widths.
- Updating image dimensions invalidates only affected items.
- VoiceOver reading order follows source order.
- Arabic layout is correct without manual left/right constants.
- Dynamic Type through accessibility sizes does not clip labels or controls.
- Reduce Motion and Reduce Transparency are respected.
- Instruments confirms no regression in hangs, allocations, or scrolling hitches.
