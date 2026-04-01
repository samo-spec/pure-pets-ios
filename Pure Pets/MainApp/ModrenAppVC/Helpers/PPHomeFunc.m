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

static const CGFloat kPageInset        = PPScreenMargin;
static const CGFloat kSectionSpacing   = PPSpaceBase;

static const CGFloat kSuggestionsItemHeight      = 248.0;

 static const CGFloat kHeaderHeight     = 64.0;

static const CGFloat NearByItemWidth  = 200;
static const CGFloat NearByItemHeight = 288;

static const CGFloat kAdsItemWidth  = 188;
static const CGFloat kAdsItemHeight = 248;

static const CGFloat kAccessoriesItemWidth  = 188;
static const CGFloat kAccessoriesItemHeight = 248;

static const CGFloat kMainKindsItemWidth  = 106;
static const CGFloat kMainKindsItemHeight = 132;

// Base spacing
static const CGFloat kPadding    = PPSpaceBase;
static const CGFloat kGapSmall   = PPSpaceXS + 2;
static const CGFloat kGapMedium  = PPSpaceSM;
static const CGFloat kGapLarge   = PPSpaceMD;

// Standard card sizes
static const CGFloat kCardTall    = 228.0;
static const CGFloat kCardMedium  = 188.0;
static const CGFloat kCardLarge   = 248.0;
static const CGFloat kCurrentOrdersExpandedItemHeight = 224.0;
static const CGFloat kCurrentOrdersCollapsedItemHeight = 96.0;

// Section header height
static const CGFloat kHeaderH = 64.0;

#pragma mark - Public Sections
 

+ (NSCollectionLayoutSection *)heroSection
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:(PPIOS26() ? 226.0 : 228.0)]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(10.0, kPadding, 16.0, kPadding);

    return section;
}

+ (NSCollectionLayoutSection *)currentOrdersSection
{
    return [self currentOrdersSectionExpanded:YES];
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
    item.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
    section.contentInsets =
    NSDirectionalEdgeInsetsMake(6.0, kPageInset, 14.0, kPageInset);

    return section;
}


// MARK: - Main Kinds Horizontal Section
+ (NSCollectionLayoutSection *)mainKindsHorizontalSection
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:96]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:122]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    item.contentInsets = NSDirectionalEdgeInsetsMake(kGapSmall, kGapSmall, kGapSmall, kGapSmall);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
        UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

    section.interGroupSpacing = kGapMedium;

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(kGapMedium, kPadding, kGapLarge, kPadding);

    section.boundarySupplementaryItems = @[[self sectionHeader]];

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

    item.contentInsets = NSDirectionalEdgeInsetsMake(kGapSmall, kGapSmall, kGapSmall, kGapSmall);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
        UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

    section.interGroupSpacing = kGapMedium;

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(kGapMedium, kPadding, kGapLarge, kPadding);

    section.boundarySupplementaryItems = @[[self sectionHeader]];

    return section;
}

+ (NSCollectionLayoutSection *)buyAgainSection
{
    NSCollectionLayoutSection *section = [self accessoriesSection];
    section.contentInsets = NSDirectionalEdgeInsetsMake(8.0, kPadding, 28.0, kPadding);
    section.interGroupSpacing = kGapMedium;
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
   item.contentInsets = NSDirectionalEdgeInsetsMake(4, 0, 8, 0);

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
   NSDirectionalEdgeInsetsMake(0, 16, 26, 16);

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
    item.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;


    section.contentInsets =
    NSDirectionalEdgeInsetsMake(6, kPageInset, 18, kPageInset);

    section.boundarySupplementaryItems = @[[self sectionHeader]];
    return section;
}

/*
 
// MARK: - Suggestions Section (Premium carousel)
+ (NSCollectionLayoutSection *)suggestionsSection
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalHeightDimension:1.0]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    item.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

    NSCollectionLayoutSize *groupSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:0.78]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:kSquareCardH + 10]];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered;

    section.contentInsets =
    NSDirectionalEdgeInsetsMake(12, kPageInset, kSectionSpacing, kPageInset);
    section.interGroupSpacing = 12;

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

 */



// MARK: - Section Header (single source of truth)
+ (NSCollectionLayoutBoundarySupplementaryItem *)sectionHeader
{
    NSCollectionLayoutSize *size =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:kHeaderHeight]];

    return
    [NSCollectionLayoutBoundarySupplementaryItem
     boundarySupplementaryItemWithLayoutSize:size
     elementKind:UICollectionElementKindSectionHeader
     alignment:NSRectAlignmentTop];
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
    [NSCollectionLayoutSpacing fixedSpacing:kSectionSpacing];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.interGroupSpacing = kSectionSpacing;
    section.contentInsets =
    NSDirectionalEdgeInsetsMake(12, kPageInset, 18, kPageInset);

    section.boundarySupplementaryItems = @[[self sectionHeader]];
    return section;
}

/*
 // MARK: - Main Kinds Horizontal Section
 + (NSCollectionLayoutSection *)mainKindsHorizontalSection
 {
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension absoluteDimension:kMainKindsItemWidth]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:kMainKindsItemHeight]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
     item.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
     UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

     section.contentInsets =
     NSDirectionalEdgeInsetsMake(0, kPageInset, 18, kPageInset);

     section.boundarySupplementaryItems = @[[self sectionHeader]];
     return section;
 }
 
 
 
 + (NSCollectionLayoutSection *)accessoriesSection
 {
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension absoluteDimension:kAccessoriesItemWidth]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:kAccessoriesItemHeight]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
     item.contentInsets = NSDirectionalEdgeInsetsMake(0, 6, 6, 6);

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                   subitems:@[item]];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior =
     UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;

     section.contentInsets =
     NSDirectionalEdgeInsetsMake(12, kPageInset, 18, kPageInset);

     section.boundarySupplementaryItems = @[[self sectionHeader]];
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
     [NSCollectionLayoutDimension absoluteDimension:156]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    // No inner spacing – single card
    item.contentInsets = NSDirectionalEdgeInsetsMake(2, 0, 6, 0);;

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
    NSDirectionalEdgeInsetsMake(0, 16, 26, 16);

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
 */
// MARK: - Accessories Section (and Ads, unified card logic)



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
     [NSCollectionLayoutDimension absoluteDimension:64]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    item.contentInsets =
    NSDirectionalEdgeInsetsMake(4, 4, 4, 4);

    // Group (single row, 3 items)
    NSCollectionLayoutSize *groupSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:64]];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                  subitems:@[item, item, item]];

    // Section
    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.interGroupSpacing = 0;
    section.contentInsets =
    NSDirectionalEdgeInsetsMake(2, 16, 10, 16);

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
    item.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

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
    NSDirectionalEdgeInsetsMake(12, 6, kSectionSpacing, 6);
    section.interGroupSpacing = 6;

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

   // =========================
   // Item (3 per row)
   // =========================
   NSCollectionLayoutSize *itemSize =
   [NSCollectionLayoutSize sizeWithWidthDimension:
    [NSCollectionLayoutDimension fractionalWidthDimension:(1.0 / 3.0)]
                                    heightDimension:
    [NSCollectionLayoutDimension absoluteDimension:58]];

   NSCollectionLayoutItem *item =
   [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

   item.contentInsets = NSDirectionalEdgeInsetsMake(4, 4, 4, 4);

   // =========================
   // Group (3 columns)
   // =========================
   NSCollectionLayoutSize *groupSize =
   [NSCollectionLayoutSize sizeWithWidthDimension:
    [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                    heightDimension:
    [NSCollectionLayoutDimension absoluteDimension:58]];

   NSCollectionLayoutGroup *group =
   [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                 subitems:@[item, item]];

   // =========================
   // Section
   // =========================
   NSCollectionLayoutSection *section =
   [NSCollectionLayoutSection sectionWithGroup:group];

   section.interGroupSpacing = 8;
   section.contentInsets = NSDirectionalEdgeInsetsMake(16.0, 16.0, 26, 16.0);

  

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
