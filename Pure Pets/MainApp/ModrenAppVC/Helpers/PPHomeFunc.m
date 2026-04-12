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

/// Standard spacing unit — every inset/gap derives from this.
static const CGFloat kStd = 12.0;

// Aliases so every call-site compiles (all resolve to kStd = 12)
static const CGFloat kPageInset       = kStd;
//static const CGFloat kSectionSpacing  = kStd;
static const CGFloat kPadding         = kStd;
//static const CGFloat kGapSmall        = kStd;
static const CGFloat kGapMedium       = kStd;
static const CGFloat kGapLarge        = kStd;


static const CGFloat PPSize16        = 16;
static const CGFloat PPSize12       = 16;
static const CGFloat PPSize6       = 8;

static const CGFloat kHeaderHeight     = 72.0;
static const CGFloat kHeaderHeightMin     = 58.0;

static const CGFloat kAccessoriesItemWidth  = 188;
static const CGFloat kAccessoriesItemHeight = 248;

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
        return 20.0;
    }
    return 16.0;
}

static inline CGFloat PPHomeHeroHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 280.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 248.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 224.0;
    }
    return (PPIOS26() ? 236.0 : 240.0);
}

static inline CGFloat PPHomeCurrentOrdersHeight(BOOL expanded, CGFloat width)
{
    if (expanded) {
        if (PPHomeWidthIsTablet(width)) {
            return 264.0;
        }
        if (PPHomeWidthIsWidePhone(width)) {
            return 248.0;
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
        return 130.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 116.0;
    }
    return 122.0;
}

static inline CGFloat PPHomeAccessoryCardWidth(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 228.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 204.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 170.0;
    }
    return kCardMedium;
}

static inline CGFloat PPHomeAccessoryCardHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 286.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 266.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 236.0;
    }
    return kCardLarge;
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

static inline CGFloat PPHomeQuickActionWidth(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 184.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 168.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 152.0;
    }
    return 176.0;
}

static inline CGFloat PPHomeQuickActionHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 72.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 68.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 60.0;
    }
    return 64.0;
}

static inline CGFloat PPHomeAdoptHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 208.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 188.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 166.0;
    }
    return 176.0;
}

static inline CGSize PPHomeNearbyCardSize(CGFloat width)
{
    width = PPHomeResolvedWidth(width);
    if (PPHomeWidthIsTablet(width)) {
        return CGSizeMake(MIN(width * 0.40, 336.0), 284.0);
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return CGSizeMake(MIN(width * 0.58, 304.0), 248.0);
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return CGSizeMake(MIN(width * 0.78, 258.0), 224.0);
    }
    return CGSizeMake(MIN(width * 0.68, 284.0), 234.0);
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
    NSDirectionalEdgeInsetsMake(8.0, horizontalInset, 16.0, horizontalInset);

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
    NSDirectionalEdgeInsetsMake(8.0, horizontalInset, 16.0, horizontalInset);

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
                                                     PPSize6,
                                                     0,
                                                     PPSize6);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
        UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

    section.interGroupSpacing = 0;

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(kGapMedium, horizontalInset, kGapLarge, horizontalInset);

    section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin
                                                                  pinned:YES]];

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
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardHeight(availableWidth)]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    item.contentInsets = NSDirectionalEdgeInsetsMake(0,
                                                     PPSize6,
                                                     0,
                                                     PPSize6);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
        UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

    section.interGroupSpacing = 0;

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(PPSize12, horizontalInset, PPSize12, horizontalInset);

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
    section.contentInsets = NSDirectionalEdgeInsetsMake(PPSize12,
                                                        horizontalInset,
                                                        PPSize12,
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
    NSDirectionalEdgeInsetsMake(10.0, horizontalInset, 10.0, horizontalInset);

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

   // 10pt margin on each side → width = view width - 20
   section.contentInsets =
   NSDirectionalEdgeInsetsMake(2, horizontalInset, PPSize16, horizontalInset);

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
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardWidth(availableWidth)]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:PPHomeAccessoryCardHeight(availableWidth)]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    item.contentInsets = NSDirectionalEdgeInsetsMake(0,PPSize6,0,PPSize6);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;


    section.contentInsets =
    NSDirectionalEdgeInsetsMake(PPSize12, horizontalInset, PPSize12, horizontalInset);

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
    CGFloat itemFraction = 1.0 / MAX(1.0, (CGFloat)columnCount);
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:itemFraction]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:itemFraction]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:itemFraction]]
                                                  subitem:item
                                                    count:columnCount];

    group.interItemSpacing =
    [NSCollectionLayoutSpacing fixedSpacing:(PPHomeWidthIsTablet(availableWidth) ? 8.0 : PPSize6)];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.interGroupSpacing = PPHomeWidthIsTablet(availableWidth) ? 8.0 : 6.0;
    section.contentInsets =
    NSDirectionalEdgeInsetsMake(12, horizontalInset, 12, horizontalInset);

    section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin
                                                                  pinned:YES]];

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

    section.interGroupSpacing = 0;
    section.contentInsets =
    NSDirectionalEdgeInsetsMake(6, 12, 6, 12);

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

       item.contentInsets = NSDirectionalEdgeInsetsMake(0, 6, 0, 6);

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
   
   CGFloat itemWidth  = 150;
   CGFloat itemHeight = 185;

   NSCollectionLayoutSize *itemSize =
   [NSCollectionLayoutSize sizeWithWidthDimension:
    [NSCollectionLayoutDimension absoluteDimension:itemWidth]
                                    heightDimension:
    [NSCollectionLayoutDimension absoluteDimension:itemHeight]];

   NSCollectionLayoutItem *item =
   [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
   item.contentInsets = NSDirectionalEdgeInsetsMake(0, 3, 6,3);

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
   section.interGroupSpacing = 6;
   section.contentInsets = NSDirectionalEdgeInsetsMake(6, 16, 16, 16);

   
   return section;
}




+ (NSCollectionLayoutSection *)adsNearBySection
{
    return [self adsNearBySectionForWidth:UIScreen.mainScreen.bounds.size.width];
}

+ (NSCollectionLayoutSection *)adsNearBySectionForWidth:(CGFloat)availableWidth
{
    CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);
    CGSize cardSize = PPHomeNearbyCardSize(availableWidth);
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalHeightDimension:1.0]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    item.contentInsets = NSDirectionalEdgeInsetsMake(0, PPSize6, 0, PPSize6);

    NSCollectionLayoutSize *groupSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:cardSize.width]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:cardSize.height * 1.2]];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                  subitem:item
                                                    count:1];
    group.interItemSpacing =
    [NSCollectionLayoutSpacing fixedSpacing:0];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered;

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(PPSize12, horizontalInset, PPSize12, horizontalInset);
    section.interGroupSpacing = 0;

    NSCollectionLayoutSize *size =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:56]];
    
    section.boundarySupplementaryItems = @[[NSCollectionLayoutBoundarySupplementaryItem
                                            boundarySupplementaryItemWithLayoutSize:size
                                            elementKind:UICollectionElementKindSectionHeader
                                            alignment:NSRectAlignmentTop]];
    return section;
}



+ (NSCollectionLayoutSection *)quickActionsSection {
   return [self quickActionsSectionForWidth:UIScreen.mainScreen.bounds.size.width];
}

+ (NSCollectionLayoutSection *)quickActionsSectionForWidth:(CGFloat)availableWidth {
   CGFloat horizontalInset = PPHomeHorizontalInset(availableWidth);

   NSCollectionLayoutSize *itemSize =
   [NSCollectionLayoutSize sizeWithWidthDimension:
    [NSCollectionLayoutDimension absoluteDimension:PPHomeQuickActionWidth(availableWidth)]
                                    heightDimension:
    [NSCollectionLayoutDimension absoluteDimension:PPHomeQuickActionHeight(availableWidth)]];

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
   section.interGroupSpacing = PPHomeWidthIsTablet(availableWidth) ? 16.0 : 12.0;
   section.contentInsets = NSDirectionalEdgeInsetsMake(4.0, horizontalInset, 12.0, horizontalInset);

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
   section.contentInsets = NSDirectionalEdgeInsetsMake([PPBannerCollectionCell preferredCarouselSectionTopInset],
                                                       horizontalInset,
                                                       [PPBannerCollectionCell preferredCarouselSectionBottomInset],
                                                       horizontalInset);


   
   
   return section;
}






@end

 

 
NS_ASSUME_NONNULL_END

















/*
 + (NSCollectionLayoutSection *)adsNearBySection_s {
    // =========================
    // Item (large card)
    // =========================


    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:NearByItemWidth]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:NearByItemHeight]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    item.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

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
    section.interGroupSpacing = 0;
    section.contentInsets = NSDirectionalEdgeInsetsMake(12, 16.0, 24, 16.0);

    // =========================
    // Header (standard)
    // =========================
     section.boundarySupplementaryItems = @[[self sectionHeader]];


    // =========================
    // Divider (top separator)
    // =========================
    NSCollectionLayoutDecorationItem *divider =
    [NSCollectionLayoutDecorationItem
     backgroundDecorationItemWithElementKind:PPHomeSectionDividerKind];

    divider.contentInsets = NSDirectionalEdgeInsetsMake(-12, 10, 0, 10);
    section.decorationItems = @[divider];

    return section;
 }
 */
