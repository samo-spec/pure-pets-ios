#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UserModel.h"

@class PetAccessory;
@class PetAd;

NS_ASSUME_NONNULL_BEGIN

/// Narrow Objective-C interoperability boundary used by the SwiftUI pet-ad viewer.
///
/// This class does not own presentation state or navigation state. It only forwards
/// calls to the application's existing managers so the SwiftUI feature preserves the
/// same Firebase collections, authentication rules, analytics, caching, and legacy
/// destinations without depending on a coordinator.
@interface PPPetAdViewerLegacyBridge : NSObject

+ (BOOL)isSignedIn NS_SWIFT_NAME(isSignedIn());
+ (BOOL)isNetworkAvailable NS_SWIFT_NAME(isNetworkAvailable());
+ (nullable NSString *)currentUserID NS_SWIFT_NAME(currentUserID());

+ (void)fetchAdForID:(NSString *)adID
          completion:(void (^)(PetAd * _Nullable ad,
                               NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchAd(id:completion:));

+ (void)fetchOwnerForID:(NSString *)ownerID
             completion:(void (^)(UserModel * _Nullable user,
                                  NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchOwner(id:completion:));

+ (void)fetchSimilarAdsForAd:(PetAd *)ad
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray<PetAd *> *ads,
                                       NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchSimilarAds(for:limit:completion:));

+ (void)fetchAccessoriesForAd:(PetAd *)ad
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                        NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchAccessories(for:limit:completion:));

+ (void)loadFavoriteForAdID:(NSString *)adID
                 completion:(void (^)(BOOL isFavorite,
                                      NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadFavorite(adID:completion:));

+ (void)setFavorite:(BOOL)isFavorite
            forAdID:(NSString *)adID
          completion:(void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(setFavorite(_:adID:completion:));

+ (void)submitReportForAd:(PetAd *)ad
                   reason:(NSString *)reason
               completion:(void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(submitReport(for:reason:completion:));

+ (void)trackInteractionCode:(NSInteger)interactionCode
                       forAd:(PetAd *)ad
    NS_SWIFT_NAME(track(interactionCode:ad:));

+ (void)logViewForAd:(PetAd *)ad NS_SWIFT_NAME(logView(for:));
+ (void)logContactForAd:(PetAd *)ad
            channelCode:(NSInteger)channelCode
    NS_SWIFT_NAME(logContact(for:channelCode:));

+ (NSString *)formattedPriceForAd:(PetAd *)ad
    NS_SWIFT_NAME(formattedPrice(for:));
+ (NSString *)categoryNameForAd:(PetAd *)ad
    NS_SWIFT_NAME(categoryName(for:));
+ (NSString *)subcategoryNameForAd:(PetAd *)ad
    NS_SWIFT_NAME(subcategoryName(for:));
+ (NSString *)locationNameForAd:(PetAd *)ad
    NS_SWIFT_NAME(locationName(for:));
+ (NSString *)ageTextForAd:(PetAd *)ad
    NS_SWIFT_NAME(ageText(for:));
+ (nullable NSString *)formattedDateForAd:(PetAd *)ad
    NS_SWIFT_NAME(formattedDate(for:));
+ (NSString *)formattedPriceForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(formattedPrice(forAccessory:));
+ (NSString *)subtitleForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(subtitle(forAccessory:));
+ (NSString *)locationNameForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(locationName(forAccessory:));

+ (NSString *)displayNameForUser:(UserModel *)user
    NS_SWIFT_NAME(displayName(for:));
+ (nullable NSString *)avatarURLForUser:(UserModel *)user
    NS_SWIFT_NAME(avatarURL(for:));
+ (nullable NSString *)phoneNumberForUser:(UserModel *)user
    NS_SWIFT_NAME(phoneNumber(for:));
+ (BOOL)isUserVerified:(UserModel *)user
    NS_SWIFT_NAME(isVerified(user:));
+ (BOOL)isChatAllowedForUser:(UserModel *)user
    NS_SWIFT_NAME(isChatAllowed(for:));

+ (void)shareAd:(PetAd *)ad
fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(share(_:from:));

+ (void)presentSignInFromViewController:(UIViewController *)viewController
                              completion:(void (^)(BOOL signedIn))completion
    NS_SWIFT_NAME(presentSignIn(from:completion:));

+ (void)callUser:(UserModel *)user
fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(call(_:from:));

+ (void)openWhatsAppForUser:(UserModel *)user
         fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openWhatsApp(for:from:));

+ (void)openChatForUser:(UserModel *)user
     fromViewController:(UIViewController *)viewController
             completion:(void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(openChat(for:from:completion:));

+ (void)openAccessory:(PetAccessory *)accessory
   fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openAccessory(_:from:));

+ (void)loadImageAtURL:(nullable NSString *)urlString
             completion:(void (^)(UIImage * _Nullable image))completion
    NS_SWIFT_NAME(loadImage(url:completion:));

+ (void)prefetchImageURLs:(NSArray<NSString *> *)urlStrings
    NS_SWIFT_NAME(prefetch(urls:));

+ (void)playFavoriteFeedback:(BOOL)isFavorite
    NS_SWIFT_NAME(playFavoriteFeedback(isFavorite:));

+ (void)setPremiumTabDockHidden:(BOOL)hidden
                       animated:(BOOL)animated
             fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(setPremiumTabDockHidden(_:animated:from:));

@end

NS_ASSUME_NONNULL_END
