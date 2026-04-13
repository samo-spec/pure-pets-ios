//
//  PPHomeFunc.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#import <UIKit/UIKit.h>

//NS_ASSUME_NONNULL_BEGIN

@interface PPHomeFunc : NSObject
  
+ (NSCollectionLayoutSection *)mainKindsHorizontalSection;
+ (NSCollectionLayoutSection *)mainKindsGridSection;
+ (NSCollectionLayoutSection *)servicesSection;
+ (NSCollectionLayoutSection *)carouselSection;
+ (NSCollectionLayoutSection *)heroSection;
+ (NSCollectionLayoutSection *)currentOrdersSection;
+ (NSCollectionLayoutSection *)currentOrdersSectionExpanded:(BOOL)expanded;
+ (NSCollectionLayoutSection *)quickActionsSection;
+ (NSCollectionLayoutSection *)emptyFallbackSection;
+ (NSCollectionLayoutSection *)accessoriesSection;
+ (NSCollectionLayoutSection *)buyAgainSection;
+ (NSCollectionLayoutSection *)adsNearBySection;
+ (NSCollectionLayoutSection *)petProfileSection;
+ (NSCollectionLayoutSection *)emptySection;
+ (void)registerDecorationsForLayout:(UICollectionViewCompositionalLayout *)layout;
+ (NSCollectionLayoutSection *)adoptSection;
+ (NSCollectionLayoutSection *)categoriesOptionsSection;
+ (NSCollectionLayoutSection *)categoriesItemsSection;
+ (NSCollectionLayoutSection *)suggestionsSection;

+ (NSCollectionLayoutSection *)mainKindsHorizontalSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)mainKindsGridSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)carouselSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)heroSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)currentOrdersSectionExpanded:(BOOL)expanded
                                                  forWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)quickActionsSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)accessoriesSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)buyAgainSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)adsNearBySectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)petProfileSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)lastFoodSection;
+ (NSCollectionLayoutSection *)lastFoodSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)adoptSectionForWidth:(CGFloat)availableWidth;
+ (NSCollectionLayoutSection *)suggestionsSectionForWidth:(CGFloat)availableWidth;
@end
 
