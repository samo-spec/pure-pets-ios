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

#pragma mark - Public Sections
 

+ (NSCollectionLayoutSection *)heroSection
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:(PPIOS26() ? 236.0 : 240.0)]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(12.0, PPSize16, 12.0, PPSize16);

    return section;
}

+ (NSCollectionLayoutSection *)currentOrdersSection
{
    return [self currentOrdersSectionExpanded:NO];
}

+ (NSCollectionLayoutSection *)currentOrdersSectionExpanded:(BOOL)expanded
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:(expanded ? kCurrentOrdersExpandedItemHeight : kCurrentOrdersCollapsedItemHeight)]];

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
    NSDirectionalEdgeInsetsMake(PPSize6, PPSize12, PPSize12, PPSize12);

    return section;
}


// MARK: - Main Kinds Horizontal Section
+ (NSCollectionLayoutSection *)mainKindsHorizontalSection
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:102]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:122]];

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
    NSDirectionalEdgeInsetsMake(kGapMedium , PPSize16, kGapLarge , PPSize16);

    section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin
                                                                  pinned:YES]];

    return section;
}



// MARK: - Accessories Section (and Ads, unified card logic)
+ (NSCollectionLayoutSection *)accessoriesSection
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:kCardMedium]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:kCardLarge]];

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
    NSDirectionalEdgeInsetsMake(PPSize12, PPSize16, PPSize12, PPSize16);

    section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeightMin]];

    return section;
}

+ (NSCollectionLayoutSection *)buyAgainSection
{
    NSCollectionLayoutSection *section = [self accessoriesSection];
    section.contentInsets = NSDirectionalEdgeInsetsMake(PPSize12,
                                                        PPSize16,
                                                        PPSize12,
                                                        PPSize16);
    section.interGroupSpacing = 0;
    section.boundarySupplementaryItems = @[[self sectionHeaderWithHeight:kHeaderHeight]];
    return section;
}
+ (NSCollectionLayoutSection *)adoptSection {
   // =========================
   // Single full-width card
   // =========================
   NSCollectionLayoutSize *itemSize =
   [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                    heightDimension:
    [NSCollectionLayoutDimension absoluteDimension:176]];

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
   NSDirectionalEdgeInsetsMake(2, PPSize16, PPSize16, PPSize16);

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
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:kAccessoriesItemWidth]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:kAccessoriesItemHeight]];

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
    NSDirectionalEdgeInsetsMake(PPSize12, PPSize16, PPSize12, PPSize16);

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
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0/3.0]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0/3.0]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0/3.0]]
                                                  subitem:item
                                                    count:3];

    group.interItemSpacing =
    [NSCollectionLayoutSpacing fixedSpacing:PPSize6];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.interGroupSpacing = 0;
    section.contentInsets =
    NSDirectionalEdgeInsetsMake(12, PPSize16, 12, PPSize16);

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
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalHeightDimension:1]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    item.contentInsets = NSDirectionalEdgeInsetsMake(0, PPSize6, 0, PPSize6);

    NSCollectionLayoutSize *groupSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:0.65]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:0.80]];

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
    NSDirectionalEdgeInsetsMake(PPSize12, PPSize16, PPSize12, PPSize16);
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

   NSCollectionLayoutSize *itemSize =
   [NSCollectionLayoutSize sizeWithWidthDimension:
    [NSCollectionLayoutDimension absoluteDimension:156.0]
                                    heightDimension:
    [NSCollectionLayoutDimension absoluteDimension:64.0]];

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
   section.interGroupSpacing = 10.0;
   section.contentInsets = NSDirectionalEdgeInsetsMake(0.0, PPSize16, 10.0, PPSize16);

   return section;
}


+ (NSCollectionLayoutSection *)carouselSection {

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
    [NSCollectionLayoutDimension absoluteDimension:[PPBannerCollectionCell preferredCarouselSectionHeight]]];

   NSCollectionLayoutGroup *group =
   [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                 subitems:@[item]];

   // Section
   NSCollectionLayoutSection *section =
   [NSCollectionLayoutSection sectionWithGroup:group];
   section.interGroupSpacing = 0;
   section.contentInsets = NSDirectionalEdgeInsetsMake([PPBannerCollectionCell preferredCarouselSectionTopInset],
                                                       [PPBannerCollectionCell preferredCarouselSectionHorizontalInset],
                                                       [PPBannerCollectionCell preferredCarouselSectionBottomInset],
                                                       [PPBannerCollectionCell preferredCarouselSectionHorizontalInset]);


   
   
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
