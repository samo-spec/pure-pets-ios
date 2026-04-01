//
//  PetAccessoryManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/05/2025.
//


// PetAccessoryManager.h

#import <Foundation/Foundation.h>
@import FirebaseFirestore;
#import "PetAccessory.h"
#import "CartItem.h"
NS_ASSUME_NONNULL_BEGIN

@interface PetAccessoryManager : NSObject
- (void)pp_oneTimePopulateAccessoryInventoryAndOffersWithCompletion:(void (^)(NSError * _Nullable error,
                                                                              NSInteger updatedCount))completion;
- (void)pp_oneTimeSetAllAccessoriesPriceToFixedValuesWithCompletion:(void (^)(NSError * _Nullable error,
                                                                              NSInteger updatedCount))completion;
- (void)fetchAccessoriesForMainCategoryID:(NSInteger)mainCategoryID
                            subCategoryID:(NSInteger)subCategoryID
                                    limit:(NSInteger)limit
                               completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;


- (void)searchAccessoriesWithText:(NSString *)query
                       completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
- (void)fetchLatestAccessoriesHasOffersWithLimit:(NSInteger)limit
                                      completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                           NSError * _Nullable error))completion;
- (void)fetchSimilarAccessoriesForAd:(PetAccessory *)ad
                          completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;

- (void)fetchAccessoriesOfKind:(AccessKindType)kind
                  MainCategory:(NSInteger)mainCategoryID
                     subKindID:(NSInteger)subKindID
                    completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;


@property (nonatomic, strong) NSMutableArray<PetAccessory *> *accessoriesArray;
- (void)fetchLatestAccessoriesWithLimit:(NSInteger)limit
                             completion:(void (^)(NSArray<PetAccessory *> *accessories, NSError * _Nullable error))completion;
+ (instancetype)sharedManager;
- (void)startListeningWithKind:(AccessKindType)kindType
                  mainCategory:(NSInteger)mainCategoryID
                       onArray:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock;
- (void)startListeningWithUpdateForMianId:(NSInteger)mainCategoryID onArray:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock;

- (void)addAccessory:(PetAccessory *)accessory completion:(void (^)(NSError * _Nullable error))completion;
- (void)updateAccessory:(PetAccessory *)accessory completion:(void (^)(NSError * _Nullable error))completion;
- (void)deleteAccessory:(NSString *)accessoryID completion:(void (^)(NSError * _Nullable error))completion;
- (void)updateAccessoryWithComplationUpdatedClass:(PetAccessory *)model  completion:(void(^)(NSError * _Nullable, PetAccessory * _Nullable updatedModel))completion;

- (void)updateAccessory:(PetAccessory *)accessory
                 images:(NSArray<UIImage *> *)images
             completion:(void (^)(NSError * _Nullable error))completion;

- (NSArray<PetAccessory *> *)filterByMainCategory:(NSInteger)mainCatID subCategory:(NSInteger)subCatID;

//- (void)uploadAccessory:(PetAccessory *)accessory
//                 images:(NSArray<NSURL *> *)images
//             completion:(void (^)(NSError * _Nullable error))completion;
- (void)uploadAccessory:(PetAccessory *)accessory
           imageObjects:(NSArray<UIImage *> *)images
             completion:(void (^)(NSError * _Nullable error))completion;
- (PetAccessory *)getAccessoryID:(NSString *)accessID;
- (void)loadAllAccessories:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock;
////////
///
- (void)createAccessory:(PetAccessory *)accessory
                 images:(NSArray<UIImage *> *)images
             completion:(void (^)(NSError * _Nullable error))completion;
+ (void)fetchAccessoriesForUserID:(NSString *)userID completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
+ (void)fetchAccessoriesWithIDs:(NSArray<NSString *> *)itemIDs completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;

+ (void)fetchSuggestedAccessoriesForAccess:(PetAccessory *)ad completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
@property (nonatomic, strong) UIViewController *ParentVC;

/// Start listener, optionally filtering by condition (pass 0 to skip)
- (void)startListeningWithMainCategory:(NSInteger)mainCategoryID
                             condition:(AccessConditions)condition
                               onArray:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock;

- (NSArray<PetAccessory *> *)filterAccessoriesWithCondition:(AccessConditions)condition;

- (void)fetchAccessoriesOfKind:(AccessKindType)kind
                    completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
- (void)fetchAccessoriesOfKind:(AccessKindType)kind MainCategory:(NSInteger)mainCatID completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;

+ (void)fetchAccessoriesForUserID:(NSString *)userID accessKindType:(AccessKindType)accessKindType completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
- (void)startListeningWithKind:(AccessKindType)kindType
                      onUpdate:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock;
- (NSArray<PetAccessory *> *)filterAccessoriesByKind:(AccessKindType)kind;

+ (void)fetchAccessoriesTypeAccessWithIDs:(NSArray<NSString *> *)itemIDs completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
+ (void)fetchAccessoriesTypeFoodWithIDs:(NSArray<NSString *> *)itemIDs completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;


 
- (void)fetchAccessoriesForAllMainKinds:(void (^)(NSArray<PetAccessory *> *accessories))completion;
- (void)fetchFoodForAllMainKinds:(void (^)(NSArray<PetAccessory *> *foods))completion;
- (void)migrateSearchTitleForExistingAccessories;
@end



NS_ASSUME_NONNULL_END






