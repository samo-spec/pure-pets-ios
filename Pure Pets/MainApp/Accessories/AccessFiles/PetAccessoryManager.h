//
//  PetAccessoryManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/05/2025.
//


// PetAccessoryManager.h

#import <Foundation/Foundation.h>
@class FIRDocumentSnapshot;
#import "PetAccessory.h"
#import "CartItem.h"
NS_ASSUME_NONNULL_BEGIN

@interface PetAccessoryManager : NSObject
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
- (void)updateAccessoryID:(NSString *)accessoryID
          showInAppMarket:(BOOL)showInAppMarket
               completion:(void (^)(NSError * _Nullable error))completion;
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
- (void)createAccessory:(PetAccessory *)accessory
      uploadedImageURLs:(NSArray<NSString *> *)imageURLs
          imageMetadata:(NSArray<NSDictionary *> *)imageMetadata
              videoURLs:(NSArray<NSString *> *)videoURLs
          videoMetadata:(NSArray<NSDictionary *> *)videoMetadata
          mixedMetadata:(NSArray<NSDictionary *> *)mixedMetadata
             completion:(void (^)(NSError * _Nullable error))completion;
+ (void)fetchAccessoriesForUserID:(NSString *)userID completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
+ (void)fetchAccessoriesWithIDs:(NSArray<NSString *> *)itemIDs completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;

+ (void)fetchSuggestedAccessoriesForAccess:(PetAccessory *)ad completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;

+ (void)fetchProviderMarketplaceAccessoriesForOwnerID:(NSString *)ownerID
                                    excludingAccessory:(PetAccessory *)exclude
                                           completion:(void (^)(NSArray<PetAccessory *> *accessories))completion;
+ (void)fetchProviderMarketplaceAccessoriesForOwnerID:(NSString *)ownerID
                                    excludingAccessory:(nullable PetAccessory *)exclude
                                   completionWithError:(void (^)(NSArray<PetAccessory *> *accessories,
                                                                 NSError * _Nullable error))completion;
+ (void)fetchProviderPharmacyAccessoriesForOwnerID:(NSString *)ownerID
                                 excludingAccessory:(nullable PetAccessory *)exclude
                                completionWithError:(void (^)(NSArray<PetAccessory *> *accessories,
                                                              NSError * _Nullable error))completion;
+ (void)fetchPublicMarketplaceAccessoriesWithCompletion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                                 NSError * _Nullable error))completion;
/// Exact, uncapped public accessory inventory for a Home marketplace signal.
/// A positive category is required. Results retain the manager's existing
/// market, moderation, expiry, and condition eligibility filters.
- (void)fetchPublicMarketplaceAccessoriesForMainCategoryID:(NSInteger)mainCategoryID
                                                completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                                     NSError * _Nullable error))completion;
+ (void)fetchPublicPharmacyAccessoriesWithCompletion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                              NSError * _Nullable error))completion;
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

#pragma mark - Colour-variant families

/// Reads one `ProductFamilies` document and returns its raw data.
///
/// Read-only and open by rule: `ProductFamilies` is world-readable so the marketplace
/// can resolve a product's sibling colours before the customer authenticates. The
/// family document is merchandising identity only — it carries no stock, cost,
/// supplier or branch data, so the caller must still read each member product for
/// live price and availability.
///
/// Calls back on the main queue with `nil` when the family is missing or the read
/// fails; `error` distinguishes the two.
+ (void)fetchProductFamilyWithID:(NSString *)familyID
                      completion:(void (^)(NSDictionary * _Nullable family, NSError * _Nullable error))completion;

/// Reads a single `petAccessories` document without applying any merchandising
/// filter.
///
/// `fetchAccessoriesWithIDs:` deliberately drops items that fail the used-accessory
/// flag, which is correct for list surfaces but wrong when resolving a specific
/// colour the customer just tapped: silently returning nothing would look like a
/// broken swatch. This returns whatever the document says and lets the caller decide.
+ (void)fetchAccessoryWithID:(NSString *)accessoryID
                  completion:(void (^)(PetAccessory * _Nullable accessory, NSError * _Nullable error))completion;


 
- (void)fetchAccessoriesForAllMainKinds:(void (^)(NSArray<PetAccessory *> *accessories))completion;
- (void)fetchFoodForAllMainKinds:(void (^)(NSArray<PetAccessory *> *foods))completion;
- (void)migrateSearchTitleForExistingAccessories;
@end



NS_ASSUME_NONNULL_END

