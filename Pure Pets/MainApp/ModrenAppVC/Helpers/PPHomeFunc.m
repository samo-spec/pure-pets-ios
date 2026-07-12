//
//  PPHomeFunc.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#import "PPHomeFunc.h"
#import "PPBannerCollectionCell.h"
#import "PPHomeProviderUnifiedCategoryCardCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeFunc (PPHomeSectionHeaderInsets)
+ (NSCollectionLayoutBoundarySupplementaryItem *)sectionHeaderWithHeight:(float)height
                                                                   pinned:(BOOL)pinned
                                                            contentInsets:(NSDirectionalEdgeInsets)contentInsets;
@end




@implementation PPHomeFunc

#pragma mark - Design Tokens (2026)

// Home section spacing uses a local visual rhythm so adjacent compositional
// sections do not accidentally double the visible gap.

static const CGFloat PPHomeVerticalInnerSpacing   = 0.0;
static const CGFloat PPHomeEdgeSpacing   = 16.0;
static const CGFloat PPHomeSpacingBase    = 16.0;
static const CGFloat PPInner = 16.0;
static const CGFloat PPHomeSpacingSection = 16.0;
static const CGFloat kHeaderHeight     = 48.0;
static const CGFloat kHeaderHeightMin     = 34.0;


// Standard card sizes
static const CGFloat kCardMedium  = 164.0;
static const CGFloat kCardLarge   = 248.0;

static const CGFloat kCurrentOrdersExpandedItemHeight = 236.0;
static const CGFloat kCurrentOrdersCollapsedItemHeight = 93.0;

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
    // Vertical spacing between sections set to 16pt
    return PPHomeSpacingSection;
}

 

static inline NSDirectionalEdgeInsets PPHomeFullWidthSectionInsets(void)
{
    return NSDirectionalEdgeInsetsMake(8.0,
                                       PPHomeEdgeSpacing,
                                       PPHomeSpacingSection,
                                       PPHomeEdgeSpacing);
}
 

static inline NSDirectionalEdgeInsets PPHomeHorizontalRailSectionInsets(void)
{
    return NSDirectionalEdgeInsetsMake(8.0,
                                       PPHomeEdgeSpacing,
                                       PPHomeSpacingSection,
                                       PPHomeEdgeSpacing);
}

static inline NSDirectionalEdgeInsets PPHomeHorizontalRailItemInsets(void)
{
    return NSDirectionalEdgeInsetsMake(0.0,
                                       0,
                                       0.0,
                                       16);
}

static inline NSDirectionalEdgeInsets PPHomeExpandedHorizontalRailHeaderInsets(void)
{
    return NSDirectionalEdgeInsetsMake(0.0,
                                       0.0,
                                       PPHomeVerticalInnerSpacing,
                                       0);
}

static NSCollectionLayoutSection *PPHomeBuildHorizontalRailSection(CGFloat cardWidth,
                                                                   CGFloat cardHeight,
                                                                   CGFloat interGroupSpacing,
                                                                   CGFloat headerHeight,
                                                                   BOOL expandHeaderToFullWidth)
{
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:cardWidth]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:cardHeight]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    item.contentInsets = NSDirectionalEdgeInsetsMake(0.0,
                                                     0,
                                                     0.0,
                                                     0);

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
    section.interGroupSpacing = interGroupSpacing;
    section.contentInsets = PPHomeHorizontalRailSectionInsets();

    if (expandHeaderToFullWidth) {
        section.boundarySupplementaryItems = @[[PPHomeFunc sectionHeaderWithHeight:headerHeight
                                                                            pinned:NO
                                                                     contentInsets:PPHomeExpandedHorizontalRailHeaderInsets()]];
    } else {
        section.boundarySupplementaryItems = @[[PPHomeFunc sectionHeaderWithHeight:headerHeight]];
    }

    return section;
}

static inline CGFloat PPHomeHeroHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 190.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 180.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 164.0;
    }
    return 176.0;
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
        return 136.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 110.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 110.0;
    }
    return 110.0;
}

static inline CGFloat PPHomeMainKindsHorizontalItemHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 150.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 120.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 110.0;
    }
    return 120.0;
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

static inline CGFloat PPHomeProviderCategoryNavHeight(CGFloat width)
{
    if (PPHomeUseUnifiedProviderCategoryCard) {
        BOOL accessibilityText =
            UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory);
        if (accessibilityText) {
            return  72.0;
        }
        return   72.0;
    }
    if (PPHomeWidthIsTablet(width)) {
        return 72.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 72.0;
    }
    return 72.0;
}

static inline CGFloat PPHomeMarketplaceHeroHeight(CGFloat width)
{
    BOOL accessibilityText =
        UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory);
    if (accessibilityText) {
        return PPHomeWidthIsTablet(width) ? 292.0 : 316.0;
    }
    if (PPHomeWidthIsTablet(width)) {
        return 224.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 216.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 206.0;
    }
    return 212.0;
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
        return kCardMedium;
    }
    return kCardMedium;
}

static inline CGFloat PPHomeAccessoryCardHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 362.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 352.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 352.0;
    }
    return kCardLarge + 0.0;
}

static inline CGFloat PPHomePetProfileHeight(BOOL expanded, CGFloat width)
{
    if (!expanded) {
        if (PPHomeWidthIsTablet(width)) {
            return 178.0;
        }
        if (PPHomeWidthIsWidePhone(width)) {
            return 170.0;
        }
        if (PPHomeWidthIsCompactPhone(width)) {
            return 158.0;
        }
        return 164.0;
    }

    if (PPHomeWidthIsTablet(width)) {
        return 276.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 264.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 246.0;
    }
    return 254.0;
}


static inline CGFloat PPHomeQuickActionHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 56.0;
    }
    return 48.0;
}


static inline CGFloat PPHomeCareHeight(CGFloat width)
{
    if (PPHomeWidthIsTablet(width)) {
        return 164.0;
    }
    if (PPHomeWidthIsWidePhone(width)) {
        return 144.0;
    }
    if (PPHomeWidthIsCompactPhone(width)) {
        return 144.0;
    }
    return 144.0;
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
        return 186.0;
    }
    return 186.0;
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
    CGFloat searchHeight = 52.0;

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
    section.contentInsets = NSDirectionalEdgeInsetsMake(PPHomeSectionEdgeInset(), PPHomeEdgeSpacing, PPHomeSpacingSection, PPHomeEdgeSpacing);

    return section;
}

+ (NSCollectionLayoutSection *)marketplaceHeroSection
{
    return [self marketplaceHeroSectionForWidth:UIScreen.mainScreen.bounds.size.width];
}

+ (NSCollectionLayoutSection *)marketplaceHeroSectionForWidth:(CGFloat)availableWidth
{
    NSCollectionLayoutSize *itemSize =
        [NSCollectionLayoutSize sizeWithWidthDimension:
         [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                        heightDimension:
         [NSCollectionLayoutDimension absoluteDimension:PPHomeMarketplaceHeroHeight(availableWidth)]];

    NSCollectionLayoutItem *item =
        [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
        [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                      subitems:@[item]];

    NSCollectionLayoutSection *section =
        [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
    section.interGroupSpacing = 0.0;
    section.contentInsets =
        NSDirectionalEdgeInsetsMake(PPHomeSpacingBase,
                                    PPHomeEdgeSpacing,
                                    PPHomeSpacingSection + 0.0,
                                    PPHomeEdgeSpacing);

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
     section.contentInsets = NSDirectionalEdgeInsetsMake(8.0, PPHomeEdgeSpacing, PPHomeSpacingSection, PPHomeEdgeSpacing);

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
     return PPHomeBuildHorizontalRailSection(
                                             PPHomeAccessoryCardWidth(availableWidth),
                                             PPHomeAccessoryCardHeight(availableWidth) + 26.0,
                                             PPHomeSpacingBase,
                                             kHeaderHeightMin,
                                             NO);
 }

 + (NSCollectionLayoutSection *)buyAgainSection
 {
     return [self buyAgainSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)buyAgainSectionForWidth:(CGFloat)availableWidth
 {
     
     return PPHomeBuildHorizontalRailSection(
                                             PPHomeAccessoryCardWidth(availableWidth),
                                             PPHomeAccessoryCardHeight(availableWidth) + 26.0,
                                             PPHomeSpacingBase,
                                             kHeaderHeight,
                                             NO);
      
 }

 + (NSCollectionLayoutSection *)petProfileSection
 {
     return [self petProfileSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)petProfileSectionForWidth:(CGFloat)availableWidth
 {
     return [self petProfileSectionExpanded:YES forWidth:availableWidth];
 }

 + (NSCollectionLayoutSection *)petProfileSectionExpanded:(BOOL)expanded
                                                 forWidth:(CGFloat)availableWidth
 {
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:PPHomePetProfileHeight(expanded, availableWidth)]];

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
     return PPHomeBuildHorizontalRailSection(
                                             PPHomeAccessoryCardWidth(availableWidth),
                                             PPHomeAccessoryCardHeight(availableWidth) + 26.0,
                                             PPHomeSpacingBase,
                                             kHeaderHeight,
                                             NO);
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
     NSDirectionalEdgeInsetsMake(PPHomeSpacingSection,
                                 PPHomeEdgeSpacing,
                                 PPHomeSpacingSection,
                                 PPHomeEdgeSpacing);
 
    
    return section;
 }



 // MARK: - Suggestions Section (Premium carousel)
 + (NSCollectionLayoutSection *)suggestionsSection
 {
     return [self suggestionsSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)suggestionsSectionForWidth:(CGFloat)availableWidth
 {
     return PPHomeBuildHorizontalRailSection(
                                             PPHomeAccessoryCardWidth(availableWidth),
                                             PPHomeAccessoryCardHeight(availableWidth) + 20.0,
                                             PPHomeSpacingBase,
                                             kHeaderHeight,
                                             NO);
 }


 // MARK: - Section Header (single source of truth)
 + (NSCollectionLayoutBoundarySupplementaryItem *)sectionHeaderWithHeight:(float)height
 {
     return [self sectionHeaderWithHeight:height pinned:NO];
 }

 + (NSCollectionLayoutBoundarySupplementaryItem *)sectionHeaderWithHeight:(float)height
                                                                   pinned:(BOOL)pinned
 {
     NSCollectionLayoutDimension *heightDim;
     if (height <= 58.0) {
         heightDim = [NSCollectionLayoutDimension absoluteDimension:height];
     } else {
         heightDim = [NSCollectionLayoutDimension estimatedDimension:height];
     }
     
     NSCollectionLayoutSize *size =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:heightDim];

    NSCollectionLayoutBoundarySupplementaryItem *header =
        [NSCollectionLayoutBoundarySupplementaryItem
         boundarySupplementaryItemWithLayoutSize:size
         elementKind:UICollectionElementKindSectionHeader
         alignment:NSRectAlignmentTop];
    header.pinToVisibleBounds = pinned;
    header.zIndex = pinned ? 2 : 0;
    header.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, PPHomeVerticalInnerSpacing, 0);
    return header;
}

 + (NSCollectionLayoutBoundarySupplementaryItem *)sectionHeaderWithHeight:(float)height
                                                                   pinned:(BOOL)pinned
                                                            contentInsets:(NSDirectionalEdgeInsets)contentInsets
 {
     NSCollectionLayoutBoundarySupplementaryItem *header =
         [self sectionHeaderWithHeight:height pinned:pinned];
     header.contentInsets = contentInsets;
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

 + (NSCollectionLayoutSection *)providerCategoryNavigationSection
 {
     return [self providerCategoryNavigationSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)providerCategoryNavigationSectionForWidth:(CGFloat)availableWidth
 {
     CGFloat resolvedWidth = PPHomeResolvedWidth(availableWidth);
     CGFloat itemHeight = PPHomeProviderCategoryNavHeight(availableWidth);

     if (PPHomeUseUnifiedProviderCategoryCard) {
         NSCollectionLayoutSize *itemSize =
         [NSCollectionLayoutSize sizeWithWidthDimension:
          [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                          heightDimension:
          [NSCollectionLayoutDimension absoluteDimension:itemHeight]];

         NSCollectionLayoutItem *item =
         [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

         NSCollectionLayoutSize *groupSize =
         [NSCollectionLayoutSize sizeWithWidthDimension:
          [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                          heightDimension:
          [NSCollectionLayoutDimension absoluteDimension:itemHeight]];

         NSCollectionLayoutGroup *group =
         [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                       subitems:@[item]];

         NSCollectionLayoutSection *section =
         [NSCollectionLayoutSection sectionWithGroup:group];
         section.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
         section.contentInsets = NSDirectionalEdgeInsetsMake(6.0,
                                                            PPHomeEdgeSpacing+3,
                                                            PPHomeEdgeSpacing,
                                                            PPHomeEdgeSpacing+3);
         return section;
     }

     CGFloat middleSpacing = 12.0;
     CGFloat contentWidth = MAX(0.0, resolvedWidth - (PPHomeEdgeSpacing * 2.0));
     CGFloat itemWidth = MAX(0.0, (contentWidth - middleSpacing) / 2.0);
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:itemWidth]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:itemHeight]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
     item.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 6.0, 0.0, 6.0);

     NSCollectionLayoutSize *groupSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:itemHeight]];
     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                   subitem:item
                                                     count:2];

     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
     section.interGroupSpacing = middleSpacing;
     section.contentInsets = NSDirectionalEdgeInsetsMake(6,
                                                        10,
                                                         PPHomeEdgeSpacing,
                                                        10);
     section.interGroupSpacing = PPHomeEdgeSpacing;
     group.interItemSpacing = [NSCollectionLayoutSpacing fixedSpacing:0];

     return section;
 }

 + (NSCollectionLayoutSection *)quickActionsSectionForWidth:(CGFloat)availableWidth {
    CGFloat itemWidth = PPHomeWidthIsTablet(availableWidth) ? 156.0 : 132.0;
    CGFloat itemHeight = PPHomeQuickActionHeight(availableWidth);

    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension estimatedDimension:itemWidth]
                                     heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:itemHeight]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    item.edgeSpacing = [NSCollectionLayoutEdgeSpacing
                        spacingForLeading:[NSCollectionLayoutSpacing fixedSpacing:0]
                        top:[NSCollectionLayoutSpacing fixedSpacing:0]
                        trailing:[NSCollectionLayoutSpacing fixedSpacing:0]
                        bottom:[NSCollectionLayoutSpacing fixedSpacing:0]];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
        UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
    section.interGroupSpacing = 6.0;
    section.contentInsets = NSDirectionalEdgeInsetsMake(PPHomeSectionEdgeInset(),
                                                       PPHomeEdgeSpacing,
                                                       PPHomeSpacingSection,
                                                       PPHomeEdgeSpacing);

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
     return PPHomeBuildHorizontalRailSection(
                                             PPHomeAccessoryCardWidth(availableWidth),
                                             PPHomeAccessoryCardHeight(availableWidth) + 20.0,
                                             PPHomeSpacingBase,
                                             kHeaderHeight,
                                             NO);
 }

 + (NSCollectionLayoutSection *)nearbyServicesSection {
     return [self nearbyServicesSectionForWidth:UIScreen.mainScreen.bounds.size.width];
 }

 + (NSCollectionLayoutSection *)nearbyServicesSectionForWidth:(CGFloat)availableWidth
 {
     return PPHomeBuildHorizontalRailSection(
                                             PPHomeAccessoryCardWidth(availableWidth),
                                             PPHomeAccessoryCardHeight(availableWidth) + 20.0,
                                             PPHomeSpacingBase,
                                             kHeaderHeight,
                                             NO);
 }


 // MARK: - Services Section (3 items per row, modern grid)
 + (NSCollectionLayoutSection *)servicesSection
 {
     // Item (1 of 3)
     NSCollectionLayoutSize *itemSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:(1.0 / 3.0)]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:58]];

     NSCollectionLayoutItem *item =
     [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

     item.contentInsets =
     NSDirectionalEdgeInsetsMake(0, 6, 0, 6);

     // Group (single row, 3 items)
     NSCollectionLayoutSize *groupSize =
     [NSCollectionLayoutSize sizeWithWidthDimension:
      [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                      heightDimension:
      [NSCollectionLayoutDimension absoluteDimension:58]];

     NSCollectionLayoutGroup *group =
     [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                   subitems:@[item, item, item]];

     // Section
     NSCollectionLayoutSection *section =
     [NSCollectionLayoutSection sectionWithGroup:group];

     section.interGroupSpacing = PPHomeSpacingBase;
     section.contentInsets =
     NSDirectionalEdgeInsetsMake(PPHomeSpacingSection,
                                        PPHomeEdgeSpacing,
                                 PPHomeSpacingSection,
                                        PPHomeEdgeSpacing);

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
