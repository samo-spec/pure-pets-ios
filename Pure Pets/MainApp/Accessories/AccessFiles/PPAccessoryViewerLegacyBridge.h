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

typedef NS_ENUM(NSInteger, PPAccessoryLiveUpdateStatus) {
    PPAccessoryLiveUpdateStatusUpdated = 0,
    PPAccessoryLiveUpdateStatusMissing,
    PPAccessoryLiveUpdateStatusFailed,
};

/// Read-only projection of the cart that would result from adding the current
/// selection. Delivery and the final payable total remain owned by checkout.
@interface PPAccessoryCheckoutPreview : NSObject

@property (nonatomic, copy, readonly) NSString *selectionTotalText;
@property (nonatomic, copy, readonly) NSString *cartSubtotalText;
@property (nonatomic, assign, readonly) NSInteger unitsCount;
@property (nonatomic, assign, readonly) BOOL requiresProviderSwitch;
@property (nonatomic, assign, readonly) BOOL canCommit;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

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
+ (void)updateCartQuantity:(NSInteger)quantity
              forAccessory:(PetAccessory *)accessory
                completion:(void (^)(BOOL succeeded,
                                     NSInteger cartQuantity,
                                     NSInteger remainingStock))completion
    NS_SWIFT_NAME(updateCartQuantity(_:for:completion:));
+ (PPAccessoryCheckoutPreview *)checkoutPreviewForAccessory:(PetAccessory *)accessory
                                                    quantity:(NSInteger)quantity
    NS_SWIFT_NAME(checkoutPreview(for:quantity:));

+ (nullable id)listenToAccessoryID:(NSString *)accessoryID
                           onChange:(void (^)(PetAccessory * _Nullable updatedAccessory))onChange
    NS_SWIFT_NAME(listenToAccessory(accessoryID:onChange:));
+ (nullable id)listenToAccessoryID:(NSString *)accessoryID
                           onUpdate:(void (^)(PPAccessoryLiveUpdateStatus status,
                                              PetAccessory * _Nullable updatedAccessory))onUpdate
    NS_SWIFT_NAME(listenToAccessory(accessoryID:onUpdate:));

+ (void)fetchOwnerForAccessory:(PetAccessory *)accessory
                    completion:(void (^)(UserModel * _Nullable user,
                                         NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchOwner(for:completion:));
+ (void)fetchProviderProfileImageURLForOwnerID:(NSString *)ownerID
                                    completion:(void (^)(NSString * _Nullable imageURL))completion
    NS_SWIFT_NAME(fetchProviderProfileImageURL(ownerID:completion:));

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

+ (void)registerStockNotificationForAccessory:(PetAccessory *)accessory
                                    completion:(void (^)(BOOL succeeded))completion
    NS_SWIFT_NAME(registerStockNotification(for:completion:));

+ (void)addAccessory:(PetAccessory *)accessory
             quantity:(NSInteger)quantity
   fromViewController:(UIViewController *)viewController
            completion:(void (^)(PPAccessoryCartResultCode result,
                                 NSInteger addedQuantity,
                                 NSInteger cartQuantity,
                                 NSInteger remainingStock))completion
    NS_SWIFT_NAME(addToCart(_:quantity:from:completion:));

+ (void)prepareAccessoryForCheckout:(PetAccessory *)accessory
                            quantity:(NSInteger)quantity
                  fromViewController:(UIViewController *)viewController
                           completion:(void (^)(PPAccessoryCartResultCode result,
                                                NSInteger addedQuantity,
                                                NSInteger cartQuantity,
                                                NSInteger remainingStock))completion
    NS_SWIFT_NAME(prepareForCheckout(_:quantity:from:completion:));

/// Opens payment for an immutable, one-item accessory snapshot without
/// reading, mutating, synchronizing, or clearing the shared cart.
+ (void)beginDirectCheckoutForAccessory:(PetAccessory *)accessory
                               quantity:(NSInteger)quantity
                     fromViewController:(UIViewController *)viewController
                             completion:(void (^)(PPAccessoryCartResultCode result))completion
    NS_SWIFT_NAME(beginDirectCheckout(_:quantity:from:completion:));

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
+ (BOOL)openPaymentSelectionFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openPaymentSelection(from:));
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
