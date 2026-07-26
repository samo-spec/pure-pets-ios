#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PetAccessory;
@class UserModel;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPAccessoryCartResultCode) {
    PPAccessoryCartResultCodeSuccess = 0,
    PPAccessoryCartResultCodeCancelled,
    PPAccessoryCartResultCodeOffline,
    PPAccessoryCartResultCodeAuthenticationRequired,
    PPAccessoryCartResultCodeOutOfStock,
    PPAccessoryCartResultCodeUnavailable,
    PPAccessoryCartResultCodeFailed,
};

/// Narrow interoperability boundary for the SwiftUI accessory viewer.
///
/// All reads, writes, validation, analytics, navigation, and side effects are
/// forwarded to the same Objective-C managers used by AccessViewerVC.
/// The class name is retained for Swift/Objective-C compatibility; the legacy
/// UIKit accessory viewer UI has been removed from AccessViewerVC.
@interface PPAccessoryViewerLegacyBridge : NSObject

+ (BOOL)isSignedIn NS_SWIFT_NAME(isSignedIn());
+ (BOOL)isNetworkAvailable NS_SWIFT_NAME(isNetworkAvailable());
+ (BOOL)isRTL NS_SWIFT_NAME(isRTL());
+ (nullable NSString *)currentUserID NS_SWIFT_NAME(currentUserID());

+ (NSString *)localizedTextForKey:(NSString *)key
                         fallback:(NSString *)fallback
    NS_SWIFT_NAME(localizedText(key:fallback:));

+ (NSString *)formattedPriceForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(formattedPrice(for:));
+ (NSString *)formattedPriceForAccessory:(PetAccessory *)accessory quantity:(NSInteger)quantity
    NS_SWIFT_NAME(formattedPrice(for:quantity:));
+ (NSString *)formattedOriginalPriceForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(formattedOriginalPrice(for:));
+ (NSString *)categoryNameForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(categoryName(for:));
+ (NSString *)subcategoryNameForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(subcategoryName(for:));
+ (NSString *)accessoryCategoryNameForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(accessoryCategoryName(for:));
+ (NSString *)typeNameForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(typeName(for:));
+ (NSString *)conditionNameForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(conditionName(for:));
+ (NSString *)stockTextForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(stockText(for:));
+ (NSString *)weightTextForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(weightText(for:));
+ (NSString *)locationNameForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(locationName(for:));
+ (NSString *)createdDateTextForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(createdDateText(for:));
+ (NSString *)expiryDateTextForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(expiryDateText(for:));

+ (BOOL)isUsedAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(isUsed(_:));
+ (BOOL)isProviderMarketplaceAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(isProviderMarketplace(_:));
+ (BOOL)isOwnAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(isOwn(_:));
+ (BOOL)isAccessoryUnavailable:(PetAccessory *)accessory
    NS_SWIFT_NAME(isUnavailable(_:));
+ (BOOL)shouldShowCartForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(shouldShowCart(for:));

+ (NSInteger)cartQuantityForAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(cartQuantity(for:));
+ (NSInteger)cartItemsCount NS_SWIFT_NAME(cartItemsCount());

+ (nullable id)listenToAccessoryID:(NSString *)accessoryID
                           onChange:(void (^)(PetAccessory * _Nullable updatedAccessory))onChange
    NS_SWIFT_NAME(listenToAccessory(accessoryID:onChange:));

+ (void)fetchOwnerForAccessory:(PetAccessory *)accessory
                    completion:(void (^)(UserModel * _Nullable user,
                                         NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchOwner(for:completion:));

+ (void)fetchSuggestionsForAccessory:(PetAccessory *)accessory
                          completion:(void (^)(NSArray<PetAccessory *> *items,
                                               BOOL fromSameProvider,
                                               NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchSuggestions(for:completion:));

+ (void)loadFavoriteForAccessoryID:(NSString *)accessoryID
                        completion:(void (^)(BOOL isFavorite,
                                             NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadFavorite(accessoryID:completion:));

+ (void)setFavorite:(BOOL)isFavorite
      accessoryID:(NSString *)accessoryID
        completion:(void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(setFavorite(_:accessoryID:completion:));

+ (void)addAccessory:(PetAccessory *)accessory
             quantity:(NSInteger)quantity
   fromViewController:(UIViewController *)viewController
            completion:(void (^)(PPAccessoryCartResultCode result,
                                 NSInteger addedQuantity,
                                 NSInteger cartQuantity,
                                 NSInteger remainingStock))completion
    NS_SWIFT_NAME(addToCart(_:quantity:from:completion:));

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

+ (void)shareAccessory:(PetAccessory *)accessory
     fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(share(_:from:));
+ (void)callOwner:(UserModel *)owner
      accessory:(PetAccessory *)accessory
fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(call(owner:accessory:from:));
+ (void)chatWithOwner:(UserModel *)owner
          accessory:(PetAccessory *)accessory
fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(chat(owner:accessory:from:));
+ (void)openSupportFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openSupport(from:));
+ (void)openCartFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openCart(from:));
+ (void)openSellerProfileForAccessory:(PetAccessory *)accessory
                                owner:(UserModel *)owner
                          suggestions:(NSArray<PetAccessory *> *)suggestions
                   fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openSellerProfile(accessory:owner:suggestions:from:));
+ (void)openAccessory:(PetAccessory *)accessory
    fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openAccessory(_:from:));
+ (void)closeFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(close(from:));

+ (void)presentSignInFromViewController:(UIViewController *)viewController
                              completion:(void (^)(BOOL signedIn))completion
    NS_SWIFT_NAME(presentSignIn(from:completion:));

+ (void)loadImageAtURL:(nullable NSString *)urlString
             completion:(void (^)(UIImage * _Nullable image))completion
    NS_SWIFT_NAME(loadImage(url:completion:));
+ (void)prefetchImageURLs:(NSArray<NSString *> *)urlStrings
    NS_SWIFT_NAME(prefetch(urls:));

+ (void)trackInteractionCode:(NSInteger)interactionCode
                forAccessory:(PetAccessory *)accessory
    NS_SWIFT_NAME(track(interactionCode:accessory:));
+ (void)playFavoriteFeedback:(BOOL)isFavorite
    NS_SWIFT_NAME(playFavoriteFeedback(isFavorite:));
+ (void)playSelectionFeedback NS_SWIFT_NAME(playSelectionFeedback());

@end

NS_ASSUME_NONNULL_END
