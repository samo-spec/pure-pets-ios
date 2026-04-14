





#import "PPCollectionLayoutManager.h"
#import <UIKit/UIKit.h>
#import "PPUniversalCellViewModel.h"
#import "PetAccessory.h"

@interface PPCollectionLayoutManager ()
// No private properties needed for now.
@end

@implementation PPCollectionLayoutManager
//{ PPManagerCellLayoutMode _currentLayoutMode;  }

// Macro to get a fractional width/height dimension (for brevity in compositional layout creation)
#define FRAC_WIDTH(x) [NSCollectionLayoutDimension fractionalWidthDimension:x]
#define FRAC_HEIGHT(x) [NSCollectionLayoutDimension fractionalHeightDimension:x]
#define ABSOLUTE(x) [NSCollectionLayoutDimension absoluteDimension:x]
#define ESTIMATED(x) [NSCollectionLayoutDimension estimatedDimension:x]

- (nullable PPUniversalCellViewModel *)pp_firstUniversalViewModel
{
    id firstItem = self.items.firstObject;
    if ([firstItem isKindOfClass:[PPUniversalCellViewModel class]]) {
        return (PPUniversalCellViewModel *)firstItem;
    }
    return nil;
}

- (BOOL)pp_isAdsContextForViewModel:(PPUniversalCellViewModel *)vm
{
    if (![vm isKindOfClass:[PPUniversalCellViewModel class]]) {
        return NO;
    }
    return vm.modelContext == PPCellForAds || vm.modelContext == PPCellForHomeAds;
}

- (BOOL)pp_isCatalogCommerceContextForViewModel:(PPUniversalCellViewModel *)vm
{
    if (![vm isKindOfClass:[PPUniversalCellViewModel class]]) {
        return NO;
    }
    return vm.modelContext == PPCellForMarket
        || vm.modelContext == PPCellForFood
        || [vm.ModelObject isKindOfClass:[PetAccessory class]];
}

- (BOOL)pp_isServiceContextForViewModel:(PPUniversalCellViewModel *)vm
{
    if (![vm isKindOfClass:[PPUniversalCellViewModel class]]) {
        return NO;
    }
    return vm.modelContext == PPCellForServices;
}

- (CGFloat)pp_catalogCardHeightForWidth:(CGFloat)width
{
    if (width > 260.0) {
        return 192.0;
    }
    CGFloat contentWidth = MAX(width - 28.0, 96.0);
    CGFloat imageHeight = contentWidth * 0.78;
    return ceil(14.0 + imageHeight + 12.0 + 66.0 + 10.0 + 44.0 + 10.0 + 28.0 + 16.0);
}

- (CGFloat)pp_serviceCardHeightForWidth:(CGFloat)width
{
    if (width > 260.0) {
        return 188.0;
    }
    return ceil((width * 0.74) + 170.0);
}

- (CGFloat)pp_adsCardHeightForWidth:(CGFloat)width
                          viewModel:(PPUniversalCellViewModel *)vm
{
    CGFloat ratio = 1.02;
    if (!CGSizeEqualToSize(vm.imageSize, CGSizeZero) && vm.imageSize.width > 0.0) {
        ratio = MAX(ratio, vm.imageSize.height / MAX(vm.imageSize.width, 1.0));
    } else if (vm.preferredAspectRatio > 0.0) {
        ratio = MAX(ratio, vm.preferredAspectRatio);
    }
    ratio = MIN(ratio, 1.18);
    if (width > 260.0) {
        return 204.0;
    }
    return ceil((width * ratio) + 160.0);
}

- (CGFloat)pp_preferredHeightForViewModel:(PPUniversalCellViewModel *)vm
                                    width:(CGFloat)width
                            defaultHeight:(CGFloat)defaultHeight
{
    if (![vm isKindOfClass:[PPUniversalCellViewModel class]]) {
        return defaultHeight;
    }

    if ([self pp_isServiceContextForViewModel:vm]) {
        return [self pp_serviceCardHeightForWidth:width];
    }

    if ([self pp_isCatalogCommerceContextForViewModel:vm]) {
        return [self pp_catalogCardHeightForWidth:width];
    }

    if ([self pp_isAdsContextForViewModel:vm]) {
        return [self pp_adsCardHeightForWidth:width viewModel:vm];
    }

    if (!CGSizeEqualToSize(vm.imageSize, CGSizeZero) && vm.imageSize.width > 0.0) {
        CGFloat ratio = vm.imageSize.height / MAX(vm.imageSize.width, 1.0);
        return width * ratio + 42.0;
    }

    if (vm.preferredAspectRatio > 0.0) {
        return width * vm.preferredAspectRatio + 72.0;
    }

    return defaultHeight;
}

#pragma mark - Public API

- (UICollectionViewLayout *)layoutForMode:(PPManagerCellLayoutMode)mode {
    
    if (!mode) {
        NSLog(@"[PPCollectionLayoutManager] ERROR: newLayout is nil for mode");
        return nil;
    }
    const CGFloat horizontalSpacing = 16.0;
    const CGFloat verticalSpacing = 16.0;
    const CGFloat topInset = 8.0;
    const CGFloat bottomInset = 16.0;
    // Create an appropriate layout for the given mode.
    UICollectionViewLayout *layout = nil;
   
        // iOS 12 or lower: use legacy layouts (flow layout for standard modes, custom for Pinterest).
        switch (mode) {
            case PPCellLayoutModeFullWidth: {
                // Simple flow layout: 1 column full-width items.
                UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
                flow.scrollDirection = UICollectionViewScrollDirectionVertical;
                CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
                // Full-width cell: use a standard aspect ratio (e.g., 16:9) for height.
                CGFloat itemWidth = screenWidth - 32.0;
                PPUniversalCellViewModel *firstVM = [self pp_firstUniversalViewModel];
                CGFloat defaultHeight = (screenWidth * 0.5625) + 52.0;
                CGFloat itemHeight = [self pp_preferredHeightForViewModel:firstVM
                                                                   width:itemWidth
                                                           defaultHeight:defaultHeight];
                flow.itemSize = CGSizeMake(itemWidth, itemHeight);
                flow.minimumLineSpacing = verticalSpacing;
                flow.minimumInteritemSpacing = horizontalSpacing;
                flow.sectionInset = UIEdgeInsetsMake(topInset,
                                                     16,
                                                     bottomInset,
                                                     16);
                layout = flow;
                break;
            }
            case PPCellLayoutModeSquare: {
                // Flow layout for square grid (e.g., 2 columns by default on phone).
                UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
                flow.scrollDirection = UICollectionViewScrollDirectionVertical;
                CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
                 UIEdgeInsets insets = UIEdgeInsetsMake(topInset, horizontalSpacing, bottomInset, horizontalSpacing);
                NSUInteger columns = 2;
                // Adjust columns for larger screens (simple heuristic).
                if (screenWidth > 500) { columns = 3; }
                CGFloat contentWidth = screenWidth - insets.left - insets.right;
                if (columns > 1) {
                    contentWidth -= (columns - 1) * horizontalSpacing;
                }
                CGFloat itemWidth = floor(contentWidth / columns);
                PPUniversalCellViewModel *firstVM = [self pp_firstUniversalViewModel];
                CGFloat itemHeight = [self pp_preferredHeightForViewModel:firstVM
                                                                   width:itemWidth
                                                           defaultHeight:itemWidth];
                flow.itemSize = CGSizeMake(itemWidth, itemHeight);
                flow.minimumInteritemSpacing = horizontalSpacing;
                flow.minimumLineSpacing = verticalSpacing;
                flow.sectionInset = insets;
                layout = flow;
                break;
            }
            case PPCellLayoutModeVertical: {
                // Flow layout for vertical-oriented grid (e.g., 2 columns with taller cells).
                UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
                flow.scrollDirection = UICollectionViewScrollDirectionVertical;
                CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
                 UIEdgeInsets insets = UIEdgeInsetsMake(topInset, horizontalSpacing, bottomInset, horizontalSpacing);
                NSUInteger columns = 2;
                if (screenWidth > 500) { columns = 3; }
                CGFloat contentWidth = screenWidth - insets.left - insets.right;
                if (columns > 1) {
                    contentWidth -= (columns - 1) * horizontalSpacing;
                }
                CGFloat itemWidth = floor(contentWidth / columns);
                PPUniversalCellViewModel *firstVM = [self pp_firstUniversalViewModel];
                CGFloat itemHeight = [self pp_preferredHeightForViewModel:firstVM
                                                                   width:itemWidth
                                                           defaultHeight:(itemWidth * 1.5)];
                flow.itemSize = CGSizeMake(itemWidth, itemHeight);
                flow.minimumInteritemSpacing = horizontalSpacing;
                flow.minimumLineSpacing = verticalSpacing;
                flow.sectionInset = insets;
                layout = flow;
                break;
            }
            case PPCellLayoutModePinterest: {
                PPPinterestLayout *pinterestLayout = [[PPPinterestLayout alloc] init];
                pinterestLayout.delegate = self;
                pinterestLayout.columnCount = 2;
                pinterestLayout.minimumInteritemSpacing = horizontalSpacing;
                pinterestLayout.minimumLineSpacing = verticalSpacing;
                pinterestLayout.sectionInset =  UIEdgeInsetsMake(topInset,
                                                                 horizontalSpacing,
                                                                 bottomInset,
                                                                 horizontalSpacing);
                layout = pinterestLayout;
                break;
            }
                
                
            case PPCellLayoutModeCarousel:
                NSLog(@"[PPCollectionLayoutManager] Carousel layout activated");
                layout = [self createCompositionalLayoutForMode:PPCellLayoutModeCarousel];
                break;
            default:
            {
                UICollectionViewFlowLayout *ppFollow = [[UICollectionViewFlowLayout alloc] init];
                ppFollow.scrollDirection = UICollectionViewScrollDirectionVertical;
                ppFollow.itemSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width, 100);
                ppFollow.minimumLineSpacing = verticalSpacing;
                ppFollow.sectionInset = UIEdgeInsetsZero;
                layout = ppFollow;
                NSLog(@"[PPCollectionLayoutManager] Warning: Unknown layout mode (%ld), used default flow layout.", (long)mode);
                break;
            }
        }
    
    return layout;
}

- (UICollectionViewLayout *)listLayout {
    // FullWidth (list) layout convenience method.
    return [self layoutForMode:PPCellLayoutModeFullWidth];
}

- (UICollectionViewLayout *)squareLayout {
    return [self layoutForMode:PPCellLayoutModeSquare];
}

- (UICollectionViewLayout *)verticalLayout {
    return [self layoutForMode:PPCellLayoutModeVertical];
}

- (UICollectionViewLayout *)pinterestLayout {
    return [self layoutForMode:PPCellLayoutModePinterest];
}

- (void)applyLayoutMode:(PPManagerCellLayoutMode)mode toCollectionView:(UICollectionView *)collectionView animated:(BOOL)animated {
    if (mode == self.currentLayoutMode && collectionView.collectionViewLayout) {
        // Already in this mode and layout is set, no need to switch.
        return;
    }
    
    if (!mode) {
        NSLog(@"[PPCollectionLayoutManager] ERROR: newLayout is nil for mode %ld", mode);
        return;
    }
    
    
    self.currentLayoutMode = mode;
    
    UICollectionViewLayout *newLayout = [self layoutForMode:mode];
    // Log the layout switch (for debugging).
    NSString *modeName;
    switch (mode) {
        case PPCellLayoutModeFullWidth:  modeName = @"FullWidth"; break;
        case PPCellLayoutModeSquare:    modeName = @"Square"; break;
        case PPCellLayoutModeVertical:  modeName = @"Vertical"; break;
        case PPCellLayoutModePinterest: modeName = @"Pinterest"; break;
        default: modeName = @"Pinterest"; break;
    }
    NSLog(@"[PPCollectionLayoutManager] Switching to %@ mode using layout class: %@",
          modeName, NSStringFromClass([newLayout class]));
    // Apply the new layout to the collection view.
    [collectionView setCollectionViewLayout:newLayout animated:animated];
    [newLayout invalidateLayout];
    [collectionView reloadData];
    NSLog(@"[Layout] Applying mode: %@", modeName);
    self.currentLayoutMode = mode;
}

#pragma mark - Compositional Layout Creation (iOS 13+)

/// Internal helper to create a UICollectionViewCompositionalLayout for a given mode.
- (UICollectionViewCompositionalLayout *)createCompositionalLayoutForMode:(PPManagerCellLayoutMode)mode API_AVAILABLE(ios(13.0)) {
     //float spacing = 10;
   /// float topInset = 85;
   // float bottomInset = 80;
    if (@available(iOS 13.0, *)) {
        return [[UICollectionViewCompositionalLayout alloc]
         initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(
             NSInteger section,
             id<NSCollectionLayoutEnvironment> environment) {

            // 🔥 CAROUSEL MODE
            if (mode == PPCellLayoutModeCarousel) {

                NSCollectionLayoutSize *itemSize =
                [NSCollectionLayoutSize sizeWithWidthDimension:
                 [NSCollectionLayoutDimension fractionalWidthDimension:0.9]
                                                 heightDimension:
                 [NSCollectionLayoutDimension fractionalHeightDimension:1.0]];

                NSCollectionLayoutItem *item =
                [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

                NSCollectionLayoutSize *groupSize =
                [NSCollectionLayoutSize sizeWithWidthDimension:
                 [NSCollectionLayoutDimension fractionalWidthDimension:0.9]
                                                 heightDimension:
                 [NSCollectionLayoutDimension absoluteDimension:220]];

                NSCollectionLayoutGroup *group =
                [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                               subitems:@[item]];

                NSCollectionLayoutSection *carousel =
                [NSCollectionLayoutSection sectionWithGroup:group];

                carousel.orthogonalScrollingBehavior =
                UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered;

                carousel.interGroupSpacing = 12;
                carousel.contentInsets =
                NSDirectionalEdgeInsetsMake(12, 16, 24, 16);

                return carousel;
            }

            // 🔹 DEFAULT GRID (unchanged behavior)
            NSCollectionLayoutSize *itemSize =
            [NSCollectionLayoutSize sizeWithWidthDimension:
             [NSCollectionLayoutDimension fractionalWidthDimension:0.5]
                                             heightDimension:
             [NSCollectionLayoutDimension estimatedDimension:200]];

            NSCollectionLayoutItem *item =
            [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

            NSCollectionLayoutSize *groupSize =
            [NSCollectionLayoutSize sizeWithWidthDimension:
             [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                             heightDimension:
             [NSCollectionLayoutDimension estimatedDimension:200]];

            NSCollectionLayoutGroup *group =
            [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                           subitem:item
                                                             count:2];

            group.interItemSpacing =
            [NSCollectionLayoutSpacing fixedSpacing:10];

            NSCollectionLayoutSection *sectionLayout =
            [NSCollectionLayoutSection sectionWithGroup:group];

            sectionLayout.interGroupSpacing = 10;
            sectionLayout.contentInsets =
            NSDirectionalEdgeInsetsMake(12, 16, 12, 16);

            return sectionLayout;
         }];
        } else {
            // Fallback layout
            return [UICollectionViewCompositionalLayout init] ;
        }
}

/// Creates an NSCollectionLayoutSection for the given mode using the provided layout environment (container).
- (NSCollectionLayoutSection *)compositionalSectionForMode:(PPManagerCellLayoutMode)mode
                                               environment:(id<NSCollectionLayoutEnvironment>)env
API_AVAILABLE(ios(13.0))
{
    CGFloat containerWidth = env.container.effectiveContentSize.width;
    // Common spacing and insets for all modes (can be adjusted if needed per mode).
    float spacing = 10;
    float topInset = 0;
    float bottomInset = 80;
    NSDirectionalEdgeInsets sectionInsets = NSDirectionalEdgeInsetsMake(topInset, spacing, bottomInset, spacing);
    
    NSCollectionLayoutSize *itemSize;
    NSCollectionLayoutItem *item;
    NSCollectionLayoutGroup *group;
    NSCollectionLayoutSection *sectionLayout = nil;
    
    switch (mode) {
        case PPCellLayoutModeFullWidth: {
            // One column full-width list.
            // Width = 100%, height = fixed (e.g., use an absolute or estimated height).
            CGFloat itemHeight = containerWidth * 0.5625; // 16:9 aspect ratio
            itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:FRAC_WIDTH(1.0)
                                                      heightDimension:ABSOLUTE(itemHeight)];
            item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
            group = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:itemSize subitems:@[item]];
            sectionLayout = [NSCollectionLayoutSection sectionWithGroup:group];
            sectionLayout.interGroupSpacing = spacing;
            sectionLayout.contentInsets = *(NSDirectionalEdgeInsets *)&sectionInsets;
            break;
        }
        case PPCellLayoutModeSquare: {
            // Grid of square cells.
            // Determine number of columns based on width (aim for ~150pt cells).
            NSUInteger columns = MAX(2,
                                     floor((containerWidth - sectionInsets.leading - sectionInsets.trailing + spacing) / (150.0 + spacing)));
            // Item width = 1/columns of container, item height = same as width.
            itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:FRAC_WIDTH(1.0/columns)
                                                      heightDimension:FRAC_WIDTH(1.0/columns)]; // use fractional width for height to get square
            item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
            item.contentInsets = NSDirectionalEdgeInsetsZero;
            // Group in horizontal direction with 'columns' items, each item fills group's height.
            NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:FRAC_WIDTH(1.0)
                                                                               heightDimension:FRAC_WIDTH(1.0/columns)];
            group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                                    subitem:item
                                                                     count:columns];
            //group = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:itemSize subitems:@[item]];
            NSCollectionLayoutSection *sectionLayout = [NSCollectionLayoutSection sectionWithGroup:group];

            sectionLayout.interGroupSpacing = spacing;
            sectionLayout.contentInsets = *(NSDirectionalEdgeInsets *)&sectionInsets; // convert UIEdgeInsets to NSDirectionalEdgeInsets
            break;
        }
        case PPCellLayoutModeVertical: {
            // Grid of vertically-oriented rectangles (taller than wide).
            NSUInteger columns = MAX(2,
                                     floor((containerWidth - sectionInsets.leading - sectionInsets.trailing + spacing) / (150.0 + spacing)));
            // For vertical cards, use a height ratio (e.g., 3:2 or 3:4).
            // Here we'll use a 3:2 height ratio relative to item width (height = 1.5 * width).
            // CompositionalLayout doesn't directly support cross-axis fraction, so use absolute or estimated.
            // We compute item width via containerWidth/columns to set absolute height.
            CGFloat contentWidth = containerWidth - sectionInsets.leading - sectionInsets.trailing - (columns - 1) * spacing;
            CGFloat itemWidth = floor(contentWidth / columns);
            CGFloat itemHeight = itemWidth * 1.5; // 3:2 aspect (vertical)
            
            itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:FRAC_WIDTH(1.0/columns)
                                                      heightDimension:ABSOLUTE(itemHeight)];
            item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
            // Horizontal group with fixed item count (columns).
            NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:FRAC_WIDTH(1.0)
                                                                               heightDimension:ABSOLUTE(itemHeight)];
            group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitem:item count:columns];
            group.interItemSpacing = [NSCollectionLayoutSpacing fixedSpacing:spacing];
            sectionLayout  =[NSCollectionLayoutSection sectionWithGroup:group];
            sectionLayout.interGroupSpacing = spacing;
            sectionLayout.contentInsets = *(NSDirectionalEdgeInsets *)&sectionInsets;
            break;
        }
        case PPCellLayoutModePinterest: {
            // For Pinterest mode, using compositional layout is complex due to varying item heights.
            // We will not create a compositional section here (should not be called, as we use custom layout for Pinterest).
            sectionLayout = nil;
            break;
        }
        default:
            sectionLayout = nil;
            break;
    }
    return sectionLayout;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(PPPinterestLayout *)collectionViewLayout
heightForItemAtIndexPath:(NSIndexPath *)indexPath
               withWidth:(CGFloat)width
{
    if (indexPath.item >= self.items.count) {
        return width;
    }

    id obj = self.items[indexPath.item];

    if ([obj isKindOfClass:[PPUniversalCellViewModel class]]) {
        PPUniversalCellViewModel *vm = (PPUniversalCellViewModel *)obj;
        return [self pp_preferredHeightForViewModel:vm
                                              width:width
                                      defaultHeight:(width + 42.0)];
    }

    return width;
}

@end
