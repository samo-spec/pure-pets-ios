//
//  PPHomeFunc.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#import "PPHomeFunc.h"
#import "PPBannerCollectionCell.h"

NS_ASSUME_NONNULL_BEGIN




@implementation PPHomeFunc

#pragma mark - Design Tokens (2026)

// Spacing sourced from PPDesignTokens.h (globally available via PrefixHeader.pch):
//   PPSpaceSM = 8 | PPSpaceBase = 16 | PPScreenMargin = 20

static const CGFloat kHeaderHeight     = 68.0;
static const CGFloat kHeaderHeightMin     = 62.0;


// Standard card sizes
static const CGFloat kCardMedium  = 188.0;
static const CGFloat kCardLarge   = 248.0;

static const CGFloat kCurrentOrdersExpandedItemHeight = 236.0;
static const CGFloat kCurrentOrdersCollapsedItemHeight = 83.0;

static inline CGFloat PPHomeResolvedWidth(CGFloat width)
{
    return width > 0.0 ? width : UIScreen.mainScreen.bounds.size.width;
}

static inline BOOL PPHomeWidthIsTablet(CGFloat width)
{
    width = PPHomeResolvedWidth(width);
    return width >= 700.0;
}

static inline BOOL PPHomeWidthIsWidePhone(CGFloat width)
{
    width = PPHomeResolvedWidth(width);
    return width >= 430.0 && width < 700.0;
}

static inline BOOL PPHomeWidthIsCompactPhone(CGFloat width)
{
    width = PPHomeResolvedWidth(width);
    return width < 375.0;
}

static inline CGFloat PPHomeHorizontalInset(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 28.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return PPScreenMargin;
    }
    return PPScreenMargin;
}

static inline CGFloat PPHomeHeroHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 170.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 160.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 130.0;
    }
    return (PPIOS26() ? 160.0 : 160.0);
}

static inline CGFloat PPHomeCurrentOrdersHeight(BOOL expanded, CGFloat width)
{
    if (expanded) {
        if (PPHomeWidthIsTablet(width)) {
            return 264.0;
        }
        if (PPHomeWidthIsWidePhone(width)) {
            return 238.0;
        }
        if (PPHomeWidthIsCompactPhone(width)) {
            return 224.0;
        }
        return kCurrentOrdersExpandedItemHeight;
    }

    if (PPHomeWidthIsTablet(width)) {
        return 96.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 88.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 80.0;
    }
    return kCurrentOrdersCollapsedItemHeight;
}

static inline CGFloat PPHomeMainKindsHorizontalItemWidth(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 132.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 112.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 94.0;
    }
    return 102.0;
}

static inline CGFloat PPHomeMainKindsHorizontalItemHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 146.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 116.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 116.0;
    }
    return 116.0;
}

static inline CGFloat PPHomeMainKindsGridItemHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 146.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 132.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 122.0;
    }
    return 126.0;
}

static inline CGFloat PPHomeAccessoryCardWidth(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 242.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 218.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 184.0;
    }
    return kCardMedium;
}

static inline CGFloat PPHomeAccessoryCardHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 361.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 361.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 3120.0;
    }
    return kCardLarge + 15.0;
}

static inline CGFloat PPHomePetProfileHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 264.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 252.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 228.0;
    }
    return 240.0;
}


static inline CGFloat PPHomeQuickActionHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 72.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 64.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 64.0;
    }
    return 64.0;
}


static inline CGFloat PPHomeCareHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 208.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 138.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 126.0;
    }
    return 116.0;
}

static inline CGFloat PPHomeAdoptHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 208.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 198.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 176.0;
    }
    return 176.0;
}

static inline NSInteger PPHomeMainKindsGridColumnCount(CGFloat width)
{
    return PPHomeWidthIsTablet(width) ? 4 : 3;
}

#pragma mark - Public Sections

+ (NSCollectionLayoutSection *)heroSection
{
    return [self heroSectionForWidth:UIScreen.mainScreen.bounds.size.width];
}

+ (NSCollectionLayoutSection *)heroSectionForWidth:(CGFloat)availableWidth
{
    CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:PPHomeHeroHeight(availableWidth)]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

   return section;
}

+ (NSCollectionLayoutSection *)premiumSearchSectionForWidth:(CGFloat)availableWidth
{
    CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
    CGFloat searchHeight = PPHomeWidthIsTablet(availableWidth)       ? 72.0
                         : PPHomeWidthIsCompactPhone(availableWidth) ? 60.0
                         : 64.0;

    NSCollectionLayoutSize *itemSize =
        [NSCollectionLayoutSize sizeWithWidthDimension:
         [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                        heightDimension:
         [NSCollectionLayoutDimension absoluteDimension:searchHeight]];

    NSCollectionLayoutItem *item =
        [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
        [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                       subitems:@[item]];

    NSCollectionLayoutSection *section =
        [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
    section.interGroupSpacing = 0.0;
    section.contentInsets = NSDirectionalEdgeInsetsZero;

    NSCollectionLayoutSize *searchSize =
        [NSCollectionLayoutSize sizeWithWidthDimension:
         [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                        heightDimension:
         [NSCollectionLayoutDimension absoluteDimension:searchHeight]];

    NSCollectionLayoutBoundarySupplementaryItem *stickySearch =
        [NSCollectionLayoutBoundarySupplementaryItem
         boundarySupplementaryItemWithLayoutSize:searchSize
                                    elementKind:UICollectionElementKindSectionHeader
         alignment:NSRectAlignmentNone];
    stickySearch.pinToVisibleBounds = YES;
    stickySearch.zIndex = 1024;

    CGFloat searchInset = PPIOS26() ? PPSpaceBase : horizontalInset;
    stickySearch.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceXS, searchInset, PPSpaceXS, searchInset);
    section.boundarySupplementaryItems = @[stickySearch];

    return section;
}

 + (NSCollectionLayoutSection *)currentOrdersSection
 {
     return [self currentOrdersSectionExpanded:NO];
 }

 + (NSCollectionLayoutSection *)currentOrdersSectionExpanded:(BOOL)expanded
 {
     return [self currentOrdersSectionExpanded:expanded
                                     forWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)currentOrdersSectionExpanded:(BOOL)expanded
                                                   forWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeCurrentOrdersHeight(expanded, availableWidth)]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
     item.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0, 0.0, 0);

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
     UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     return section;
 }


 // MARK: - Main Kinds Horizontal Section
 + (NSCollectionLayoutSection *)mainKindsHorizontalSection
 {
     return [self mainKindsHorizontalSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)mainKindsHorizontalSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeMainKindsHorizontalItemWidth(availableWidth)]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeMainKindsHorizontalItemHeight(availableWidth)]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     item.contentInsets = NSDirectionalEdgeInsetsMake(0,
                                                      PPSpaceSM,
                                                      0,
                                                      PPSpaceSM);

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
         UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

     section.interGroupSpacing = 0;

     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin
                                                                   pinned:NO]];

     return section;
 }



 // MARK: - Accessories Section (and Ads, unified card logic)
 + (NSCollectionLayoutSection *)accessoriesSection
 {
     return [self accessoriesSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)accessoriesSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardWidth(availableWidth)]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardHeight(availableWidth) + 10.0]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     item.contentInsets = NSDirectionalEdgeInsetsMake(0,
                                                      PPSpaceSM,
                                                      0,
                                                      PPSpaceSM);

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
         UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

     section.interGroupSpacing = 0;

     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin]];

     return section;
 }

 + (NSCollectionLayoutSection *)buyAgainSection
 {
     return [self buyAgainSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)buyAgainSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSection *section = [self accessoriesSectionForWidth:availableWidth];
     section.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceBase,
                                                         horizontalInset,
                                                         PPSpaceBase,
                                                         horizontalInset);
     section.interGroupSpacing = 0;
     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight]];
     return section;
 }

 + (NSCollectionLayoutSection *)petProfileSection
 {
     return [self petProfileSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)petProfileSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomePetProfileHeight(availableWidth)]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
     UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
     section.interGroupSpacing = 0.0;
     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     return section;
 }

 + (NSCollectionLayoutSection *)lastFoodSection {
     return [self lastFoodSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)lastFoodSectionForWidth:(CGFloat)availableWidth {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSection *section = [self accessoriesSectionForWidth:availableWidth];
     section.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceBase,
                                                         horizontalInset,
                                                         PPSpaceBase,
                                                         horizontalInset);
     section.interGroupSpacing = 0;
     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight]];
     return section;
 }

 + (NSCollectionLayoutSection *)adoptSection {
    return [self adoptSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)adoptSectionForWidth:(CGFloat)availableWidth {
    CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
    // =========================
    // Single full-width card
    // =========================
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAdoptHeight(availableWidth)]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    // No inner spacing – single card
    item.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 0, 0);

    // =========================
    // Group (single item)
    // =========================
    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    // =========================
    // Section
    // =========================
    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    // 12pt margin on each side
    section.contentInsets =
    NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

    // ❌ No header
    // ❌ No orthogonal scrolling
    // ❌ No decoration
    
    
    NSCollectionLayoutDecorationItem *divider =
    [NSCollectionLayoutDecorationItem
     backgroundDecorationItemWithElementKind:PPHomeSectionDividerKind];

    divider.contentInsets = NSDirectionalEdgeInsetsMake(-12, 0, 0, 0);
    //section.decorationItems = @[divider];
    
    return section;
 }



 // MARK: - Suggestions Section (Premium carousel)
 + (NSCollectionLayoutSection *)suggestionsSection
 {
     return [self suggestionsSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)suggestionsSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardWidth(availableWidth) + 10]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardHeight(availableWidth) + 0.0]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
     item.contentInsets = NSDirectionalEdgeInsetsMake(0,PPSpaceSM,0,PPSpaceSM);

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
     UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;


     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight]];
     return section;
 }


 // MARK: - Section Header (single source of truth)
 + (NSCollectionLayoutBoundarySupplementaryItem *)sectionHeaderWithHeight:(float)height
 {
     return [self sectionHeaderWithHeight:height pinned:NO];
 }

 + (NSCollectionLayoutBoundarySupplementaryItem *)sectionHeaderWithHeight:(float)height
                                                                  pinned:(BOOL)pinned
 {
     NSCollectionLayoutSize *size =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:height]];

     NSCollectionLayoutBoundarySupplementaryItem *header =
         [NSCollectionLayoutBoundarySupplementaryItem
          boundarySupplementaryItemWithLayoutSize:size
          elementKind:UICollectionElementKindSectionHeader
          alignment:NSRectAlignmentTop];
     header.pinToVisibleBounds = pinned;
     header.zIndex = pinned ? 2 : 0;
     return header;
 }


 // MARK: - Main Kinds Grid Section
 + (NSCollectionLayoutSection *)mainKindsGridSection
 {
     return [self mainKindsGridSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)mainKindsGridSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSInteger columnCount = PPHomeMainKindsGridColumnCount(availableWidth);
     CGFloat itemHeight = PPHomeMainKindsGridItemHeight(availableWidth);
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:itemHeight]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:
      [NSCollectionLayoutSize sizeWithWidthDimension:
       [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                       heightDimension:
       [NSCollectionLayoutDimension absoluteDimension:itemHeight]]
                                                   subitem:item
                                                     count:columnCount];

     group.interItemSpacing =
     [NSCollectionLayoutSpacing fixedSpacing:PPSpaceBase];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.interGroupSpacing = PPSpaceBase;
     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin
                                                                   pinned:NO]];

     return section;
 }


 // MARK: - Empty/Fallback Section (cleaned, unified)
 + (NSCollectionLayoutSection *)emptyFallbackSection
 {
     NSCollectionLayoutSize *size =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:1]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:size];

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup verticalGroupWithLayoutSize:size
                                                 subitems:@[item]];

  return [NSCollectionLayoutSection sectionWithGroup:group];
 }

 + (NSCollectionLayoutSection *)quickActionsSection {
    return [self quickActionsSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)quickActionsSectionForWidth:(CGFloat)availableWidth {
    CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
    CGFloat contentWidth = MAX(0.0, availableWidth - (2.0 * horizontalInset));
    CGFloat itemWidth  = MAX(156.0, floor(contentWidth * 0.48));
    CGFloat itemHeight = PPHomeQuickActionHeight(availableWidth);

    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension estimatedDimension:itemWidth + 6]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:itemHeight - 0]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    item.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
        UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
    section.interGroupSpacing = PPSpaceBase;
    section.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceSM, horizontalInset, PPSpaceSM, horizontalInset);

    return section;
 }

 + (NSCollectionLayoutSection *)premiumCareSection {
     return [self premiumCareSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)premiumCareSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeCareHeight(availableWidth) + 34.0]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                    subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
     UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
     section.interGroupSpacing = 0.0;
     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     return section;
 }

 + (NSCollectionLayoutSection *)adsNearBySection {
     return [self adsNearBySectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)adsNearBySectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     CGFloat cardWidth  = PPHomeAccessoryCardWidth(availableWidth);
     CGFloat cardHeight = PPHomeAccessoryCardHeight(availableWidth) + 40.0;

     NSCollectionLayoutSize *itemSize =
         [NSCollectionLayoutSize sizeWithWidthDimension:
         [NSCollectionLayoutDimension absoluteDimension:cardWidth]
                                        heightDimension:
         [NSCollectionLayoutDimension absoluteDimension:cardHeight]];

     NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     NSCollectionLayoutGroup *group =
         [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                       subitems:@[item]];

     NSCollectionLayoutSection *section =
         [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
         UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
     section.interGroupSpacing = PPSpaceBase;
     section.contentInsets =
         NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight
                                                                    pinned:NO]];

     return section;
 }

 + (NSCollectionLayoutSection *)nearbyServicesSection {
     return [self nearbyServicesSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)nearbyServicesSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
     CGFloat cardWidth  = PPHomeAccessoryCardWidth(availableWidth);
     CGFloat cardHeight = PPHomeAccessoryCardHeight(availableWidth) + 60.0;

     NSCollectionLayoutSize *itemSize =
         [NSCollectionLayoutSize sizeWithWidthDimension:
          [NSCollectionLayoutDimension absoluteDimension:cardWidth]
                                         heightDimension:
          [NSCollectionLayoutDimension absoluteDimension:cardHeight]];

     NSCollectionLayoutItem *item =
         [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     NSCollectionLayoutGroup *group =
         [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                       subitems:@[item]];

     NSCollectionLayoutSection *section =
         [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
         UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
     section.interGroupSpacing = PPSpaceBase;
     section.contentInsets =
         NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight
                                                                   pinned:NO]];

     return section;
 }


 // MARK: - Services Section (3 items per row, modern grid)
 + (NSCollectionLayoutSection *)servicesSection
 {
     // Item (1 of 3)
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:(1.0 / 3.0)]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:54]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     item.contentInsets =
     NSDirectionalEdgeInsetsMake(0, PPSpaceSM, 0, PPSpaceSM);

     // Group (single row, 3 items)
     NSCollectionLayoutSize *groupSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:54]];

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                   subitems:@[item, item, item]];

     // Section
     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.interGroupSpacing = 0;
     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPSpaceSM, PPSpaceBase, PPSpaceSM, PPSpaceBase);

     return section;
 }


 + (NSCollectionLayoutSection *)categoriesOptionsSection
 {
    NSCollectionLayoutItem *item =
        [NSCollectionLayoutItem itemWithLayoutSize:
         [NSCollectionLayoutSize sizeWithWidthDimension:
          [NSCollectionLayoutDimension absoluteDimension:0]
                                       heightDimension:
          [NSCollectionLayoutDimension absoluteDimension:0]]];

        item.contentInsets = NSDirectionalEdgeInsetsMake(0, PPSpaceSM, 0, PPSpaceSM);

        NSCollectionLayoutGroup *group =
        [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:
         [NSCollectionLayoutSize sizeWithWidthDimension:
          [NSCollectionLayoutDimension absoluteDimension:0]
                                       heightDimension:
          [NSCollectionLayoutDimension absoluteDimension:0]]
                                                      subitems:@[item]];

        NSCollectionLayoutSection *section =
        [NSCollectionLayoutSection sectionWithGroup:group];

        section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

        section.contentInsets =
            NSDirectionalEdgeInsetsMake(0, 0, 0, 0);

        return section;
 }


 + (void)registerDecorationsForLayout:(UICollectionViewCompositionalLayout *)layout {
    [layout registerClass:PPHomeSectionDividerView.class forDecorationViewOfKind:PPHomeSectionDividerKind];
 }


 // MARK: - Empty Section (cleaned)
 + (NSCollectionLayoutSection *)emptySection
 {
     NSCollectionLayoutSize *size =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:1]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:size];

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup verticalGroupWithLayoutSize:size
                                                 subitems:@[item]];

     return [NSCollectionLayoutSection sectionWithGroup:group];
 }


 + (NSCollectionLayoutSection *)categoriesItemsSection {
    return [self categoriesItemsSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)categoriesItemsSectionForWidth:(CGFloat)availableWidth {
    CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
    CGFloat itemWidth  = 150;
    CGFloat itemHeight = 185;

    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:itemWidth]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:itemHeight]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    item.contentInsets = NSDirectionalEdgeInsetsZero;

    // =========================
    // Group (single card per page)
    // =========================
    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    // =========================
    // Section
    // =========================
    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    // Paging – modern, smooth, card snapping
    //section.orthogonalScrollingBehavior =
    //UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered;
    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
    section.interGroupSpacing = PPSpaceBase;
    section.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceBase, horizontalInset, PPSpaceBase, horizontalInset);

    
    return section;
 }


 
 

 + (NSCollectionLayoutSection *)carouselSection {
    return [self carouselSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)carouselSectionForWidth:(CGFloat)availableWidth {
    CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
    CGFloat preferredHeight = [PPBannerCollectionCell preferredCarouselSectionHeight];
    if (PPHomeWidthIsTablet(availableWidth)) {
        preferredHeight += 18.0;
    } else if (PPHomeWidthIsCompactPhone(availableWidth)) {
        preferredHeight = MAX(214.0, preferredHeight - 10.0);
    }

    // Item
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalHeightDimension:1.0]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    // Group (card size)
    NSCollectionLayoutSize *groupSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                   heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:preferredHeight]];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                  subitems:@[item]];

    // Section
    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];
    section.interGroupSpacing = 0;
    section.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceBase,
                                                        horizontalInset,
                                                        PPSpaceBase,
                                                        horizontalInset);


    
    
    return section;
 }







@end

NS_ASSUME_NONNULL_END
