//
//  PPHomeFunc.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

@interface PPHomeFunc : NSObject
  
+ (NSCollectionLayoutSection *)mainKindsHorizontalSection;
+ (NSCollectionLayoutSection *)mainKindsGridSection;
+ (NSCollectionLayoutSection *)servicesSection;
+ (NSCollectionLayoutSection *)carouselSection;
+ (NSCollectionLayoutSection *)heroSection;
+ (NSCollectionLayoutSection *)currentOrdersSection;
+ (NSCollectionLayoutSection *)quickActionsSection;
+ (NSCollectionLayoutSection *)emptyFallbackSection;
+ (NSCollectionLayoutSection *)accessoriesSection;
+ (NSCollectionLayoutSection *)buyAgainSection;
+ (NSCollectionLayoutSection *)adsNearBySection;
+ (NSCollectionLayoutSection *)emptySection;
+ (void)registerDecorationsForLayout:(UICollectionViewCompositionalLayout *)layout;
+ (NSCollectionLayoutSection *)adoptSection;
+ (NSCollectionLayoutSection *)categoriesOptionsSection;
+ (NSCollectionLayoutSection *)categoriesItemsSection;
+ (NSCollectionLayoutSection *)suggestionsSection;
@end
 
