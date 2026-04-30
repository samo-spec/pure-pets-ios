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

    UICollectionViewCompositionalLayout *layout =
    [[UICollectionViewCompositionalLayout alloc]
     initWithSectionProvider:^NSCollectionLayoutSection * _Nullable
     (NSInteger sectionIndex, id<NSCollectionLayoutEnvironment> env) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return [PPHomeFunc emptySection];

        CGFloat availableWidth = env.container.effectiveContentSize.width;
        if (availableWidth <= 0.0) {
            availableWidth = UIScreen.mainScreen.bounds.size.width;
        }

        // 🎯 Resolve actual section type from data source (avoids jumping/mismatches)
        PPHomeSection sectionType = PPHomeSectionHero;
        if (self.sectionIdentifierProvider) {
            sectionType = self.sectionIdentifierProvider(sectionIndex);
        } else {
            // Fallback to old behavior if provider not set (should not happen)
            NSArray<NSNumber *> *renderOrder = @[
                @(PPHomeSectionHero),
                @(PPHomeSectionQuickActions),
                @(PPHomeSectionCurrentOrders),
                @(PPHomeSectionPremiumCare),
                
                @(PPHomeSectionMainKinds),
                @(PPHomeSectionSuggestions),
                
                @(PPHomeSectionCarousel),
                @(PPHomeSectionAccessories),
                @(PPHomeSectionLastFood),
                @(PPHomeSectionNearbyServices),
                @(PPHomeSectionPetProfile),
                @(PPHomeSectionAdsNearBy),
                @(PPHomeSectionAdopt),
                @(PPHomeSectionBuyAgain),
                @(PPHomeSectionServices),
            ];
            if (sectionIndex >= 0 && sectionIndex < renderOrder.count) {
                sectionType = (PPHomeSection)renderOrder[sectionIndex].integerValue;
            }
        }

        // 🔒 Robust Check: If section is empty and dynamic, return empty layout to prevent "jumping" headers
        NSInteger itemCount = 0;
        if (self.itemCountProvider) {
            itemCount = self.itemCountProvider(sectionIndex);
        }

        BOOL isDynamicSection = (sectionType == PPHomeSectionSuggestions ||
                                 sectionType == PPHomeSectionAdsNearBy ||
                                 sectionType == PPHomeSectionNearbyServices ||
                                 sectionType == PPHomeSectionAccessories ||
                                 sectionType == PPHomeSectionLastFood ||
                                 sectionType == PPHomeSectionBuyAgain);

        if (isDynamicSection && itemCount == 0) {
            return [PPHomeFunc emptySection];
        }

        switch (sectionType) {

            case PPHomeSectionHero:
                return [PPHomeFunc heroSectionForWidth:availableWidth];

            case PPHomeSectionQuickActions:
                return [PPHomeFunc quickActionsSectionForWidth:availableWidth];

            case PPHomeSectionServices:
                return [PPHomeFunc servicesSection];

            case PPHomeSectionCurrentOrders:
                return [PPHomeFunc currentOrdersSectionExpanded:self.isCurrentOrdersExpanded
                                                      forWidth:availableWidth];

            case PPHomeSectionCarousel:
                return [PPHomeFunc carouselSectionForWidth:availableWidth];

            case PPHomeSectionMainKinds:
                return self.isMainKindsExpanded
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

            case PPHomeSectionPremiumCare:
                return [PPHomeFunc premiumCareSectionForWidth:availableWidth];

            case PPHomeSectionLastFood:
                return [PPHomeFunc lastFoodSectionForWidth:availableWidth];

            case PPHomeSectionAdsNearBy:
                return [PPHomeFunc adsNearBySectionForWidth:availableWidth];

            case PPHomeSectionNearbyServices:
                return [PPHomeFunc nearbyServicesSectionForWidth:availableWidth];

            case PPHomeSectionBuyAgain:
                return [PPHomeFunc buyAgainSectionForWidth:availableWidth];

            default:
                return [PPHomeFunc emptySection];
        }
    }];

    [PPHomeFunc registerDecorationsForLayout:layout];
    return layout;
}



@end
