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
        @(PPHomeSectionServices),
        @(PPHomeSectionCurrentOrders),
        @(PPHomeSectionMainKinds),
        @(PPHomeSectionCarousel),
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionAdopt),
        @(PPHomeSectionAdsNearBy),
        @(PPHomeSectionBuyAgain),
    ];

    UICollectionViewCompositionalLayout *layout =
    [[UICollectionViewCompositionalLayout alloc]
     initWithSectionProvider:^NSCollectionLayoutSection * _Nullable
     (NSInteger sectionIndex, id<NSCollectionLayoutEnvironment> env) {

        PPHomeSection sectionType = PPHomeSectionHero;
        if (sectionIndex >= 0 && sectionIndex < renderOrder.count) {
            sectionType = (PPHomeSection)renderOrder[sectionIndex].integerValue;
        }

        switch (sectionType) {

            case PPHomeSectionHero:
                return [PPHomeFunc heroSection];

            case PPHomeSectionServices:
                return [PPHomeFunc servicesSection];

            case PPHomeSectionCurrentOrders:
                return [PPHomeFunc currentOrdersSectionExpanded:weakSelf.isCurrentOrdersExpanded];

            case PPHomeSectionCarousel:
                return [PPHomeFunc carouselSection];

            case PPHomeSectionMainKinds:
                return weakSelf.isMainKindsExpanded
                ? [PPHomeFunc mainKindsGridSection]
                : [PPHomeFunc mainKindsHorizontalSection];

            case PPHomeSectionAdopt:
                return [PPHomeFunc adoptSection];

            case PPHomeSectionSuggestions:
                return [PPHomeFunc suggestionsSection];

            case PPHomeSectionAccessories:
                return [PPHomeFunc accessoriesSection];

            case PPHomeSectionAdsNearBy:
                return [PPHomeFunc adsNearBySection];

            case PPHomeSectionBuyAgain:
                return [PPHomeFunc buyAgainSection];

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
