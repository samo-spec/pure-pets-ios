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

// Home section spacing uses a local visual rhythm so adjacent compositional
// sections do not accidentally double the visible gap.
static const CGFloat PPHomeSpacingSmall   = 8.0;
static const CGFloat PPHomeSpacingBase    = 16.0;
static const CGFloat PPHomeSpacingSection = 20.0;

static const CGFloat kHeaderHeight     = 64.0;
static const CGFloat kHeaderHeightMin     = 54.0;


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

static inline CGFloat PPHomeSectionEdgeInset(void)
{
    return MIN(PPHomeSpacingSmall, PPHomeSpacingSection * 0.4);
}

static inline CGFloat PPHomeItemHalfGap(void)
{
    return PPHomeSpacingBase * 0.4;
}

static inline NSDirectionalEdgeInsets PPHomeFullWidthSectionInsets(void)
{
    return NSDirectionalEdgeInsetsMake(PPHomeSectionEdgeInset(),
                                       PPHomeSpacingBase,
                                       PPHomeSpacingBase-4,
                                       PPHomeSpacingBase);
}

static inline NSDirectionalEdgeInsets PPHomeHorizontalRailSectionInsets(void)
{
    return NSDirectionalEdgeInsetsMake(PPHomeSectionEdgeInset(),
                                       PPHomeItemHalfGap(),
                                       PPHomeSpacingBase,
                                       PPHomeItemHalfGap());
}

static inline NSDirectionalEdgeInsets PPHomeHorizontalRailItemInsets(void)
{
    return NSDirectionalEdgeInsetsMake(0.0,
                                       PPHomeItemHalfGap(),
                                       0.0,
                                       PPHomeItemHalfGap());
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
        return 140.0;
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
        return 94.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 94.0;
    }
    return 94.0;
}

static inline CGFloat PPHomeMainKindsHorizontalItemHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 146.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 106.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 106.0;
    }
    return 106.0;
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
        return 212.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return kCardMedium;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 174.0;
    }
    return kCardMedium;
}

static inline CGFloat PPHomeAccessoryCardHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 351.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 351.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 312.0;
    }
    return kCardLarge + 5.0;
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
        return 204.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 162.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 162.0;
    }
    return 162.0;
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
    PPHomeFullWidthSectionInsets();

   return section;
}

+ (NSCollectionLayoutSection *)premiumSearchSectionForWidth:(CGFloat)availableWidth
{
    CGFloat searchHeight = 48.0;

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
    section.contentInsets = PPHomeFullWidthSectionInsets();

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
     PPHomeFullWidthSectionInsets();

     return section;
 }


 // MARK: - Main Kinds Horizontal Section
 + (NSCollectionLayoutSection *)mainKindsHorizontalSection
 {
     return [self mainKindsHorizontalSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)mainKindsHorizontalSectionForWidth:(CGFloat)availableWidth
 {
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeMainKindsHorizontalItemWidth(availableWidth)]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeMainKindsHorizontalItemHeight(availableWidth)]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     item.contentInsets = PPHomeHorizontalRailItemInsets();

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
         UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

     section.interGroupSpacing = 0;

     section.contentInsets =
     PPHomeHorizontalRailSectionInsets();

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
     NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardWidth(availableWidth)]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardHeight(availableWidth) + 0.0]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     item.contentInsets = PPHomeHorizontalRailItemInsets();

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
         UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

     section.interGroupSpacing = 0;

     section.contentInsets =
     PPHomeHorizontalRailSectionInsets();

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin]];

     return section;
 }

 + (NSCollectionLayoutSection *)buyAgainSection
 {
     return [self buyAgainSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)buyAgainSectionForWidth:(CGFloat)availableWidth
 {
     NSCollectionLayoutSection *section = [self accessoriesSectionForWidth:availableWidth];
     section.contentInsets = PPHomeHorizontalRailSectionInsets();
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
     PPHomeFullWidthSectionInsets();

     return section;
 }

 + (NSCollectionLayoutSection *)lastFoodSection {
     return [self lastFoodSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)lastFoodSectionForWidth:(CGFloat)availableWidth {
     NSCollectionLayoutSection *section = [self accessoriesSectionForWidth:availableWidth];
     section.contentInsets = PPHomeHorizontalRailSectionInsets();
     section.interGroupSpacing = 0;
     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight]];
     return section;
 }

 + (NSCollectionLayoutSection *)adoptSection {
    return [self adoptSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)adoptSectionForWidth:(CGFloat)availableWidth {
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
    PPHomeFullWidthSectionInsets();

    // ❌ No header
    // ❌ No orthogonal scrolling
    // ❌ No decoration
    
    
    NSCollectionLayoutDecorationItem *divider =
    [NSCollectionLayoutDecorationItem
     backgroundDecorationItemWithElementKind:PPHomeSectionDividerKind];

    divider.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 0, 0);
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
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardWidth(availableWidth) + 0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardHeight(availableWidth) + 0.0]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
     item.contentInsets = PPHomeHorizontalRailItemInsets();

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
     UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

     section.interGroupSpacing = 0;

     section.contentInsets =
     PPHomeHorizontalRailSectionInsets();

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
     [NSCollectionLayoutSpacing fixedSpacing:PPHomeSpacingBase];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.interGroupSpacing = PPHomeSpacingBase;
     section.contentInsets =
     PPHomeFullWidthSectionInsets();

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
    CGFloat horizontalInset = PPHomeSpacingBase;
    CGFloat contentWidth = MAX(0.0, availableWidth - (2.0 * horizontalInset));
    CGFloat itemWidth  = MAX(156.0, floor(contentWidth * 0.52));
    CGFloat itemHeight = PPHomeQuickActionHeight(availableWidth);

    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension estimatedDimension:itemWidth + PPHomeSpacingSmall]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:itemHeight - 0]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     item.contentInsets = NSDirectionalEdgeInsetsMake(0, 6, 0, 6);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
        UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
    section.interGroupSpacing = PPHomeSpacingBase;
    section.contentInsets = PPHomeFullWidthSectionInsets();

    return section;
 }

 + (NSCollectionLayoutSection *)premiumCareSection {
     return [self premiumCareSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)premiumCareSectionForWidth:(CGFloat)availableWidth
 {
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomeCareHeight(availableWidth)]];

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
     PPHomeFullWidthSectionInsets();

     return section;
 }

 + (NSCollectionLayoutSection *)adsNearBySection {
     return [self adsNearBySectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)adsNearBySectionForWidth:(CGFloat)availableWidth
 {
     CGFloat cardWidth  = PPHomeAccessoryCardWidth(availableWidth);
     CGFloat cardHeight = PPHomeAccessoryCardHeight(availableWidth) + 10.0;

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
     section.interGroupSpacing = PPHomeSpacingBase;
     section.contentInsets =
         PPHomeFullWidthSectionInsets();

     section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight
                                                                    pinned:NO]];

     return section;
 }

 + (NSCollectionLayoutSection *)nearbyServicesSection {
     return [self nearbyServicesSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)nearbyServicesSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat cardWidth  = PPHomeAccessoryCardWidth(availableWidth);
     CGFloat cardHeight = PPHomeAccessoryCardHeight(availableWidth) + 40.0;

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
     section.interGroupSpacing = PPHomeSpacingBase;
     section.contentInsets =
         PPHomeFullWidthSectionInsets();

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
     NSDirectionalEdgeInsetsMake(0, 6, 0, 6);

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

     section.interGroupSpacing = PPHomeSpacingBase;
     section.contentInsets =
     PPHomeHorizontalRailSectionInsets();

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

        item.contentInsets = PPHomeHorizontalRailItemInsets();

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
    section.interGroupSpacing = PPHomeSpacingBase;
    section.contentInsets = PPHomeFullWidthSectionInsets();

    
    return section;
 }


 
 

 + (NSCollectionLayoutSection *)carouselSection {
    return [self carouselSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)carouselSectionForWidth:(CGFloat)availableWidth {
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
    section.contentInsets = PPHomeFullWidthSectionInsets();


    
    
    return section;
 }







@end

NS_ASSUME_NONNULL_END
