//
//  PPHomeLayoutManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/01/2026.
//


#import "PPHomeLayoutManager.h"

@implementation PPHomeLayoutManager

- (instancetype)initWithMainKindsExpanded:(BOOL)isMainKindsExpanded {
    self = [super init];
    if (self) {
        _isMainKindsExpanded = isMainKindsExpanded;
    }
    return self;
}

- (UICollectionViewCompositionalLayout *)buildLayout {

    __weak typeof(self) weakSelf = self;
    NSArray<NSNumber *> *renderOrder = @[
        @(PPHomeSectionHero),
        @(PPHomeSectionQuickActions),
       // @(PPHomeSectionServices),
        @(PPHomeSectionCurrentOrders),
        @(PPHomeSectionCarousel),
        @(PPHomeSectionMainKinds),
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionPetProfile),
        @(PPHomeSectionAdsNearBy),
        @(PPHomeSectionAdopt),
        @(PPHomeSectionBuyAgain),
    ];

    UICollectionViewCompositionalLayout *layout =
    [[UICollectionViewCompositionalLayout alloc]
     initWithSectionProvider:^NSCollectionLayoutSection * _Nullable
     (NSInteger sectionIndex, id<NSCollectionLayoutEnvironment> env) {
        CGFloat availableWidth = env.container.effectiveContentSize.width;
        if (availableWidth <= 0.0) {
            availableWidth = UIScreen.mainScreen.bounds.size.width;
        }

        PPHomeSection sectionType = PPHomeSectionHero;
        if (sectionIndex >= 0 && sectionIndex < renderOrder.count) {
            sectionType = (PPHomeSection)renderOrder[sectionIndex].integerValue;
        }

        switch (sectionType) {

            case PPHomeSectionHero:
                return [PPHomeFunc heroSectionForWidth:availableWidth];

            case PPHomeSectionQuickActions:
                return [PPHomeFunc quickActionsSectionForWidth:availableWidth];

            //case PPHomeSectionServices:
                //return [PPHomeFunc servicesSection];

            case PPHomeSectionCurrentOrders:
                return [PPHomeFunc currentOrdersSectionExpanded:weakSelf.isCurrentOrdersExpanded
                                                      forWidth:availableWidth];

            case PPHomeSectionCarousel:
                return [PPHomeFunc carouselSectionForWidth:availableWidth];

            case PPHomeSectionMainKinds:
                return weakSelf.isMainKindsExpanded
                ? [PPHomeFunc mainKindsGridSectionForWidth:availableWidth]
                : [PPHomeFunc mainKindsHorizontalSectionForWidth:availableWidth];

            case PPHomeSectionAdopt:
                return [PPHomeFunc adoptSectionForWidth:availableWidth];

            case PPHomeSectionSuggestions:
                return [PPHomeFunc suggestionsSectionForWidth:availableWidth];

            case PPHomeSectionAccessories:
                return [PPHomeFunc accessoriesSectionForWidth:availableWidth];

            case PPHomeSectionPetProfile:
                return [PPHomeFunc petProfileSectionForWidth:availableWidth];

            case PPHomeSectionAdsNearBy:
                return [PPHomeFunc adsNearBySectionForWidth:availableWidth];

            case PPHomeSectionBuyAgain:
                return [PPHomeFunc buyAgainSectionForWidth:availableWidth];

            //case PPHomeSectionCategoriesItems:
            //    return nil; //[PPHomeFunc categoriesItemsSection];

            default:
                return [PPHomeFunc emptySection];
        }
    }];

    [PPHomeFunc registerDecorationsForLayout:layout];
    return layout;
}



@end
