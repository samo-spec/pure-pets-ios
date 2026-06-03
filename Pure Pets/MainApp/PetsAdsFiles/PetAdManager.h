//
//  PetAdManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/05/2025.
//


#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "AddNewAd.h"
#import "PetAd.h"
NS_ASSUME_NONNULL_BEGIN

typedef void (^PetAdListCompletion)(NSArray<PetAd *> * _Nullable ads, NSError * _Nullable error);
typedef void (^PetAdCompletion)(NSError *_Nullable error);
typedef NS_ENUM(NSInteger, PPItemInteractionType) {
    PPItemInteractionTypeView = 0,
    PPItemInteractionTypeFavoriteAdd,
    PPItemInteractionTypeFavoriteRemove,
    PPItemInteractionTypeShare,
    PPItemInteractionTypeCall,
    PPItemInteractionTypeChat
};

@interface PetAdManager : NSObject

+ (instancetype)sharedManager;

- (void)approveAllAdsOnceWithCompletion:(void (^)(NSError * _Nullable error))completion;
@property (nonatomic, strong) UIViewController *ParentVC;
- (void)fetchAllAdsWithCompletion:(PetAdListCompletion)completion;

- (void)addPetAd:(PetAd *)ad completion:(PetAdCompletion)completion;

- (void)updatePetAd:(PetAd *)ad completion:(PetAdCompletion)completion;

- (void)updatePetAdID:(NSString *)adID
           visibility:(PetAdVisibility)visibility
           completion:(PetAdCompletion)completion;

- (void)deletePetAd:(PetAd *)ad completion:(PetAdCompletion)completion;
- (void)fetchSimilarAdsForAd:(PetAd *)ad
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray<PetAd *> *ads))completion;
- (void)migrateImageMetaToImageItemsOnce;
- (void)startListeningForPetAdsWithUpdate:(void (^)(NSArray<PetAd *> *ads))updateBlock;
- (void)stopListening;
- (void)startListeningForPetAdsWithFilters:(nullable NSString *)ownerID
                                   category:(NSInteger)category
                                subcategory:(NSInteger)subcategory
                         currentAdsPointer:(NSMutableArray<PetAd *> *_Nonnull)adsArray
                                  onChange:(void (^_Nonnull)(NSArray<PetAd *> *  _Nonnull updatedAds))changeBlock;

+ (void)removeFavoriteAdWithID:(NSString *)adID
                    collection:(NSString *)collection
                     forUserID:(NSString *)userID
                    completion:(void (^)(NSError * _Nullable error))completion;

+ (void)addFavoriteAdWithID:(NSString *)adID
                 collection:(NSString *)collection
                  forUserID:(NSString *)userID
                 completion:(void (^)(NSError * _Nullable error))completion;

+ (NSArray<PetAd *> * _Nonnull)filterAdsByCategory:(NSInteger)categoryID targetArray:(NSArray * _Nonnull)ads;
+ (NSArray<PetAd *> * _Nonnull)filterAdsWithCategory:(NSInteger)category subcategory:(NSInteger)subcategory targetArray:(NSArray * _Nonnull)ads;

+ (void)addFavoriteAdWithID:(NSString *)adID collection:(NSString *)collection forUserID:(NSString *)userID;
+ (void)removeFavoriteAdWithID:(NSString *)adID collection:(NSString *)collection forUserID:(NSString *)userID;
+ (void)isAdFavorited:(NSString *)adID forUser:(NSString *)userID collection:(NSString *)collection completion:(void (^)(BOOL favorited))completion;
+ (void)fetchFavoriteAdIDsForUserID:(NSString *)userID collection:(NSString *)collection completion:(void (^)(NSArray<NSString *> *adIDs))completion;

+ (void)trackInteraction:(PPItemInteractionType)interaction
               forItemID:(NSString *)itemID
              collection:(NSString *)collectionPath
                  userID:(nullable NSString *)userID
              completion:(nullable void (^)(NSError * _Nullable error))completion;



- (void)fetchLatestAdsWithLimit:(NSInteger)limit
                     completion:(void (^)(NSArray<PetAd *> *ads))completion;

///////
///
+ (void)fetchAdsForUserID:(NSString *)userID completion:(void (^)(NSArray<PetAd *> *ads))completion;
+ (void)fetchAdsWithIDs:(NSArray<NSString *> *)adIDs completion:(void (^)(NSArray<PetAd *> *ads))completion;
- (void)getAdsCountForCategory:(NSInteger)categoryID completion:(void(^)(NSInteger count))completion;
- (void)getAdsForCategory:(NSInteger)categoryID subCategory:(NSInteger)subcategory completion:(void (^)(NSArray<PetAd *> *_Nullable ads))completion ;
- (void)populateMissingImageMetadataForExistingAds:(void (^)(NSError * _Nullable error))completion ;
#pragma mark - Category Live Listener
- (void)fetchAdsForMainKind:(MainKindsModel *)mainKind
                 completion:(void (^)(NSArray<PetAd *> *ads))completion;
- (void)listenForCategory:(NSInteger)categoryID
                 onChange:(void (^)(NSArray<PetAd *> *updatedAds))changeBlock;
- (void)fetchAdsForMainKind:(MainKindsModel *)mainKind
                 subKindID:(NSInteger)subKindID
                 completion:(void (^)(NSArray<PetAd *> *ads))completion;
- (void)uploadImagesFromUIImageArray:(NSArray<UIImage *> *)images
                               forAd:(PetAd *)ad
                          completion:(void (^)(PetAd *_Nullable updatedAd, NSError *_Nullable error))completion;


- (void)fetchNearByAdsWithLimit:(NSInteger)limit
                       category:(NSInteger)category
                      completion:(void (^)(NSArray<PetAd *> *ads))completion;

- (void)fetchNearbyAdsAtCoordinate:(CLLocationCoordinate2D)coordinate
                          radiusKm:(double)radiusKm
                             limit:(NSInteger)limit
                          category:(NSInteger)category
                        completion:(void (^)(NSArray<PetAd *> *ads))completion;

- (void)searchAdsWithText:(NSString *)query
               completion:(void (^)(NSArray<PetAd *> *ads))completion;

- (void)fetchAdsForAllMainKinds:(void (^)(NSArray<PetAd *> *ads))completion;
- (void)populateMissingSearchTitleForExistingAds;
@end


 
    


NS_ASSUME_NONNULL_END
