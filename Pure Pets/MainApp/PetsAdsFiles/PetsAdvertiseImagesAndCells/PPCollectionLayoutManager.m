





#import "PPCollectionLayoutManager.h"
#import <UIKit/UIKit.h>
#import "PPUniversalCellViewModel.h"
#import "PetAccessory.h"
#import "BBDataViewFullDetailsLayout.h"

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

static CGFloat const PPUniversalAdsPinterestOuterInset = 4.0;
static CGFloat const PPUniversalAdsPinterestButtonHeight = 34.0;
static CGFloat const PPUniversalAdsPinterestCompactTitleHeight = 22.0;
static CGFloat const PPUniversalAdsPinterestCompactSubtitleHeight = 16.0;
static CGFloat const PPUniversalAdsPinterestCompactPriceHeight = 24.0;
static CGFloat const PPUniversalAdsPinterestCardHorizontalInset = 3.0;
static CGFloat const PPUniversalAdsPinterestCardVerticalInset = 2.0;
static CGFloat const PPUniversalAdsPinterestBodyVerticalPadding = 15.0;
static CGFloat const PPUniversalAdsPinterestTitleToPriceSpacing = 3.0;
static CGFloat const PPUniversalAdsPinterestPriceToActionSpacing = 5.0;

static CGFloat PPUniversalAdsPinterestInnerImageWidth(CGFloat cellWidth)
{
    CGFloat horizontalChrome = (PPUniversalAdsPinterestCardHorizontalInset * 2.0) + (PPUniversalAdsPinterestOuterInset * 2.0);
    return MAX(cellWidth - horizontalChrome, 1.0);
}

static CGFloat PPUniversalAdsPinterestAspectRatio(PPUniversalCellViewModel * _Nullable vm)
{
    CGFloat ratio = 1.0;
    if ([vm isKindOfClass:[PPUniversalCellViewModel class]] &&
        vm.imageSize.width > 0.0 &&
        vm.imageSize.height > 0.0) {
        ratio = vm.imageSize.height / MAX(vm.imageSize.width, 1.0);
    } else if ([vm isKindOfClass:[PPUniversalCellViewModel class]] &&
               vm.preferredAspectRatio > 0.0) {
        ratio = vm.preferredAspectRatio;
    }

    return MIN(MAX(ratio, 0.78), 0.92);
}

static CGFloat PPUniversalAdsPinterestMeasuredTitleHeight(NSString *title,
                                                          UIFont *font,
                                                          CGFloat width)
{
    CGFloat minimumHeight = MAX(PPUniversalAdsPinterestCompactTitleHeight, ceil(font.lineHeight));
    if (title.length == 0 || width <= 0.0) {
        return minimumHeight;
    }

    CGRect rect = [title boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                      options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                   attributes:@{ NSFontAttributeName : font }
                                      context:nil];
    CGFloat maxHeight = ceil(font.lineHeight) * 2.0;
    return MAX(minimumHeight, MIN(ceil(rect.size.height), maxHeight));
}

static CGFloat PPUniversalAdsPinterestBodyHeight(CGFloat cellWidth,
                                                 PPUniversalCellViewModel * _Nullable vm)
{
    CGFloat contentWidth = PPUniversalAdsPinterestInnerImageWidth(cellWidth);
    UIFont *titleFont = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    CGFloat titleHeight = PPUniversalAdsPinterestMeasuredTitleHeight(vm.title ?: @"", titleFont, contentWidth);
    CGFloat subtitleHeight = vm.subtitle.length > 0 || vm.location.length > 0
        ? PPUniversalAdsPinterestCompactSubtitleHeight
        : 0.0;

    return ceil(PPUniversalAdsPinterestBodyVerticalPadding +
                titleHeight +
                subtitleHeight +
                PPUniversalAdsPinterestTitleToPriceSpacing +
                PPUniversalAdsPinterestCompactPriceHeight +
                PPUniversalAdsPinterestPriceToActionSpacing +
                PPUniversalAdsPinterestButtonHeight);
}

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
        return 192.0 - 20.0;
    }
    CGFloat contentWidth = MAX(width - 28.0, 96.0);
    CGFloat imageHeight = contentWidth * 0.78;
    return ceil(16.0 + imageHeight + 16.0 + 66.0 + 10.0 + 44.0 + 10.0 + 28.0 + 16.0) - 20.0;
}

- (CGFloat)pp_serviceCardHeightForWidth:(CGFloat)width
{
    if (width > 260.0) {
        return 188.0 - 70.0;
    }
    return ceil((width * 0.74) + 170.0) - 70.0;
}

- (CGFloat)pp_horizontalRowHeightForWidth:(CGFloat)width
                                viewModel:(PPUniversalCellViewModel *)vm
{
    CGFloat baseHeight = width >= 390.0 ? 206.0 : 198.0;
    if (width <= 350.0) {
        baseHeight = 210.0;
    }

    if ([self pp_isServiceContextForViewModel:vm]) {
        baseHeight += 10.0;
    } else if ([self pp_isCatalogCommerceContextForViewModel:vm]) {
        baseHeight += 4.0;
    } else if ([self pp_isAdsContextForViewModel:vm] && vm.subtitle.length > 0) {
        baseHeight += 6.0;
    }

    return ceil(MIN(MAX(baseHeight, 184.0), 224.0));
}

- (CGFloat)pp_adsCardHeightForWidth:(CGFloat)width
                          viewModel:(PPUniversalCellViewModel *)vm
{
    CGFloat imageHeight = ceil(PPUniversalAdsPinterestInnerImageWidth(width) *
                               PPUniversalAdsPinterestAspectRatio(vm));
    CGFloat bodyHeight = PPUniversalAdsPinterestBodyHeight(width, vm);
    CGFloat verticalChrome = (PPUniversalAdsPinterestCardVerticalInset * 2.0) +
                             (PPUniversalAdsPinterestOuterInset * 2.0);
    return ceil(imageHeight + bodyHeight + verticalChrome);
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
    const CGFloat topInset = 16.0;
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
            case PPCellLayoutModeHorizontalRow: {
                // Full-width row for the premium horizontal DataView layout.
                UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
                flow.scrollDirection = UICollectionViewScrollDirectionVertical;
                CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
                UIEdgeInsets insets = UIEdgeInsetsMake(topInset, 16.0, bottomInset, 16.0);
                CGFloat itemWidth = MAX(1.0, floor(screenWidth - insets.left - insets.right));
                PPUniversalCellViewModel *firstVM = [self pp_firstUniversalViewModel];
                CGFloat itemHeight = [self pp_horizontalRowHeightForWidth:itemWidth
                                                                 viewModel:firstVM];
                flow.itemSize = CGSizeMake(itemWidth, itemHeight);
                flow.minimumInteritemSpacing = 0.0;
                flow.minimumLineSpacing = 12.0;
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
                PPUniversalCellViewModel *firstVM = [self pp_firstUniversalViewModel];
                if ([self pp_isAdsContextForViewModel:firstVM]) {
                    pinterestLayout.columnCount = 0;
                } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                    pinterestLayout.columnCount = 3;
                } else {
                    pinterestLayout.columnCount = 2;
                }
                pinterestLayout.minimumInteritemSpacing = horizontalSpacing;
                pinterestLayout.minimumLineSpacing = verticalSpacing;
                pinterestLayout.sectionInset =  UIEdgeInsetsMake(topInset,
                                                                 horizontalSpacing,
                                                                 bottomInset,
                                                                 horizontalSpacing);
                layout = pinterestLayout;
                break;
            }
                
                
            case PPCellLayoutModeDataViewFullDetails: {
                layout = [[BBDataViewFullDetailsLayout alloc] init];
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

- (UICollectionViewLayout *)horizontalRowLayout {
    return [self layoutForMode:PPCellLayoutModeHorizontalRow];
}

- (UICollectionViewLayout *)verticalLayout {
    return [self layoutForMode:PPCellLayoutModeVertical];
}

- (UICollectionViewLayout *)pinterestLayout {
    return [self layoutForMode:PPCellLayoutModePinterest];
}

- (UICollectionViewLayout *)fullDetailsLayout {
    return [self layoutForMode:PPCellLayoutModeDataViewFullDetails];
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
    
    
    NSArray<NSIndexPath *> *visibleIndexPaths =
        [collectionView.indexPathsForVisibleItems sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *obj1, NSIndexPath *obj2) {
            if (obj1.section != obj2.section) {
                return obj1.section < obj2.section ? NSOrderedAscending : NSOrderedDescending;
            }
            if (obj1.item == obj2.item) {
                return NSOrderedSame;
            }
            return obj1.item < obj2.item ? NSOrderedAscending : NSOrderedDescending;
        }];
    NSIndexPath *anchorIndexPath = visibleIndexPaths.firstObject;
    CGFloat anchorDeltaY = 0.0;
    if (anchorIndexPath) {
        UICollectionViewLayoutAttributes *anchorAttributes =
            [collectionView layoutAttributesForItemAtIndexPath:anchorIndexPath];
        anchorDeltaY = collectionView.contentOffset.y - CGRectGetMinY(anchorAttributes.frame);
    }

    self.currentLayoutMode = mode;

    UICollectionViewLayout *newLayout = [self layoutForMode:mode];
    // Log the layout switch (for debugging).
    NSString *modeName;
    switch (mode) {
        case PPCellLayoutModeFullWidth:  modeName = @"FullWidth"; break;
        case PPCellLayoutModeHorizontalRow: modeName = @"HorizontalRow"; break;
        case PPCellLayoutModeVertical:  modeName = @"Vertical"; break;
        case PPCellLayoutModePinterest: modeName = @"Pinterest"; break;
        case PPCellLayoutModeDataViewFullDetails: modeName = @"DataViewFullDetails"; break;
        default: modeName = @"Pinterest"; break;
    }
    NSLog(@"[PPCollectionLayoutManager] Switching to %@ mode using layout class: %@",
          modeName, NSStringFromClass([newLayout class]));

    void (^restoreAnchor)(void) = ^{
        if (!anchorIndexPath) {
            return;
        }
        [collectionView layoutIfNeeded];
        UICollectionViewLayoutAttributes *newAttributes =
            [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:anchorIndexPath];
        if (!newAttributes) {
            return;
        }
        UIEdgeInsets inset = collectionView.contentInset;
        if (@available(iOS 11.0, *)) {
            inset = collectionView.adjustedContentInset;
        }
        CGFloat minY = -inset.top;
        CGFloat maxY = MAX(minY, collectionView.contentSize.height - CGRectGetHeight(collectionView.bounds) + inset.bottom);
        CGFloat targetY = CGRectGetMinY(newAttributes.frame) + anchorDeltaY;
        targetY = MIN(MAX(targetY, minY), maxY);
        [collectionView setContentOffset:CGPointMake(collectionView.contentOffset.x, targetY) animated:NO];
    };

    void (^reloadAndRestore)(void) = ^{
        [collectionView reloadData];
        [newLayout invalidateLayout];
        restoreAnchor();
    };

    BOOL shouldAnimate = animated && collectionView.window != nil && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        [collectionView setCollectionViewLayout:newLayout
                                       animated:YES
                                     completion:^(__unused BOOL finished) {
            [UIView transitionWithView:collectionView
                              duration:0.16
                               options:UIViewAnimationOptionTransitionCrossDissolve |
                                       UIViewAnimationOptionAllowUserInteraction |
                                       UIViewAnimationOptionBeginFromCurrentState
                            animations:reloadAndRestore
                            completion:nil];
        }];
    } else {
        [collectionView setCollectionViewLayout:newLayout animated:NO];
        reloadAndRestore();
    }

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

                carousel.interGroupSpacing = 16.0;
                carousel.contentInsets =
                NSDirectionalEdgeInsetsMake(12, 16.0, 24, 16.0);

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
            [NSCollectionLayoutSpacing fixedSpacing:12];

            NSCollectionLayoutSection *sectionLayout =
            [NSCollectionLayoutSection sectionWithGroup:group];

            sectionLayout.interGroupSpacing = 12;
            sectionLayout.contentInsets =
            NSDirectionalEdgeInsetsMake(16.0, 16.0, 16.0, 16.0);

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
        case PPCellLayoutModeHorizontalRow: {
            CGFloat itemHeight = [self pp_horizontalRowHeightForWidth:(containerWidth - sectionInsets.leading - sectionInsets.trailing)
                                                            viewModel:[self pp_firstUniversalViewModel]];
            itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:FRAC_WIDTH(1.0)
                                                      heightDimension:ABSOLUTE(itemHeight)];
            item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
            item.contentInsets = NSDirectionalEdgeInsetsZero;
            NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:FRAC_WIDTH(1.0)
                                                                               heightDimension:ABSOLUTE(itemHeight)];
            group = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:groupSize
                                                                 subitems:@[item]];
            sectionLayout = [NSCollectionLayoutSection sectionWithGroup:group];

            sectionLayout.interGroupSpacing = 12.0;
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
        case PPCellLayoutModeDataViewFullDetails: {
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
