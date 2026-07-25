#import "PPAccessoryViewerLegacyBridge.h"

#import "AccessViewerVC.h"
#import "AppClasses.h"
#import "CartItem.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "ChManager.h"
#import "CitiesManager.h"
#import "GM.h"
#import "Language.h"
#import "MainKindsModel.h"
#import "PPAlertHelper.h"
#import "PPAnalytics.h"
#import "PPCommerceFeedbackManager.h"
#import "PPHUD.h"
#import "PPImageLoaderManager.h"
#import "PPNavigationController.h"
#import "PPNetworkRetryHelper.h"
#import "PPUserSigningManager.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PetAdManager.h"
#import "SellerProfileVC.h"
#import "UserManager.h"
#import "UserModel.h"

@import FirebaseAuth;

static NSString * const PPAccessoryViewerBridgeErrorDomain =
    @"com.purepets.accessory-viewer";
static NSString * const PPAccessoryOfficialSupportUserID =
    @"PUIDPOFFICILAL20262214";

static NSString *PPAccessoryBridgeTrimmedString(NSString *value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [value stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static UIViewController *PPAccessoryResolvedPresenter(
    UIViewController *source
) {
    UIViewController *presenter = source;
    BOOL advanced = YES;
    while (advanced) {
        advanced = NO;
        if (presenter.presentedViewController &&
            !presenter.presentedViewController.isBeingDismissed) {
            presenter = presenter.presentedViewController;
            advanced = YES;
            continue;
        }
        if ([presenter isKindOfClass:UINavigationController.class]) {
            UIViewController *visible =
                ((UINavigationController *)presenter).visibleViewController;
            if (visible && visible != presenter) {
                presenter = visible;
                advanced = YES;
                continue;
            }
        }
        if ([presenter isKindOfClass:UITabBarController.class]) {
            UIViewController *selected =
                ((UITabBarController *)presenter).selectedViewController;
            if (selected && selected != presenter) {
                presenter = selected;
                advanced = YES;
            }
        }
    }
    return presenter;
}

@implementation PPAccessoryViewerLegacyBridge

+ (BOOL)isSignedIn
{
    return UserManager.sharedManager.isUserLoggedIn;
}

+ (BOOL)isNetworkAvailable
{
    return [PPNetworkRetryHelper isNetworkAvailable];
}

+ (BOOL)isRTL
{
    return Language.isRTL;
}

+ (nullable NSString *)currentUserID
{
    NSString *modelID = UserManager.sharedManager.currentUser.ID;
    if (modelID.length > 0) {
        return modelID;
    }
    NSString *authID = FIRAuth.auth.currentUser.uid;
    return authID.length > 0 ? authID : nil;
}

+ (NSString *)localizedTextForKey:(NSString *)key
                         fallback:(NSString *)fallback
{
    NSString *localized = [Language get:key alter:fallback];
    return localized.length > 0 ? localized : fallback;
}

+ (NSString *)formattedPriceForAccessory:(PetAccessory *)accessory
{
    return [PetAccessory formatCurrency:accessory.finalPrice ?: accessory.price]
        ?: @"";
}

+ (NSString *)formattedOriginalPriceForAccessory:(PetAccessory *)accessory
{
    return [PetAccessory formatCurrency:accessory.price] ?: @"";
}

+ (NSString *)categoryNameForAccessory:(PetAccessory *)accessory
{
    MainKindsModel *model =
        [MainKindsModel mainKindModelForID:accessory.petMainCategoryID];
    NSString *name = PPAccessoryBridgeTrimmedString(model.KindName);
    return name.length > 0
        ? name
        : ([PetAccessory typeTextForAccessory:accessory] ?: @"");
}

+ (NSString *)subcategoryNameForAccessory:(PetAccessory *)accessory
{
    MainKindsModel *model =
        [MainKindsModel mainKindModelForID:accessory.petMainCategoryID];
    SubKindModel *subcategory =
        [model subKindForID:accessory.petSubCategoryID];
    return PPAccessoryBridgeTrimmedString(subcategory.SubKindName);
}

+ (NSString *)accessoryCategoryNameForAccessory:(PetAccessory *)accessory
{
    NSString *categoryID =
        PPAccessoryBridgeTrimmedString(accessory.AccessoryCategoryID);
    if (categoryID.length == 0) {
        return @"";
    }
    MainKindsModel *model =
        [MainKindsModel mainKindModelForID:accessory.petMainCategoryID];
    PPAccessoryCategoryModel *category =
        [model accessoryCategoryForID:categoryID];
    NSString *displayName =
        PPAccessoryBridgeTrimmedString([category displayName]);
    return displayName.length > 0 ? displayName : categoryID;
}

+ (NSString *)typeNameForAccessory:(PetAccessory *)accessory
{
    return [PetAccessory typeTextForAccessory:accessory] ?: @"";
}

+ (NSString *)conditionNameForAccessory:(PetAccessory *)accessory
{
    return [PetAccessory conditionTextForAccessory:accessory] ?: @"";
}

+ (NSString *)stockTextForAccessory:(PetAccessory *)accessory
{
    return [accessory stockStatusText] ?: @"";
}

+ (NSString *)weightTextForAccessory:(PetAccessory *)accessory
{
    NSString *stored = PPAccessoryBridgeTrimmedString(accessory.weightText);
    if (stored.length > 0) {
        return stored;
    }
    if (!accessory.weight) {
        return @"";
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = NSLocale.currentLocale;
    formatter.maximumFractionDigits = 2;
    formatter.minimumFractionDigits = 0;
    NSString *number = [formatter stringFromNumber:accessory.weight] ?: @"";
    NSString *unit = PPAccessoryBridgeTrimmedString(accessory.weightUnit);
    return unit.length > 0
        ? [NSString stringWithFormat:@"%@ %@", number, unit]
        : number;
}

+ (NSString *)locationNameForAccessory:(PetAccessory *)accessory
{
    NSString *city = [CitiesManager.shared cityNameForID:accessory.cityID];
    return PPAccessoryBridgeTrimmedString(city);
}

+ (NSString *)formattedDate:(NSDate *)date
{
    if (!date) {
        return @"";
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = NSLocale.currentLocale;
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    return [formatter stringFromDate:date] ?: @"";
}

+ (NSString *)createdDateTextForAccessory:(PetAccessory *)accessory
{
    return [self formattedDate:accessory.createdAt];
}

+ (NSString *)expiryDateTextForAccessory:(PetAccessory *)accessory
{
    return [self formattedDate:accessory.expiryDate];
}

+ (BOOL)isUsedAccessory:(PetAccessory *)accessory
{
    return accessory.condition == AccessConditionsUsed;
}

+ (BOOL)isProviderMarketplaceAccessory:(PetAccessory *)accessory
{
    NSString *ownerID = PPAccessoryBridgeTrimmedString(accessory.ownerID);
    if (ownerID.length == 0 ||
        [[self currentUserID] isEqualToString:ownerID] ||
        [self isUsedAccessory:accessory]) {
        return NO;
    }
    if ([accessory.ownerType isEqualToString:@"partner"] ||
        [accessory.source isEqualToString:@"provider_marketplace"]) {
        return YES;
    }
    return YES;
}

+ (BOOL)isOwnAccessory:(PetAccessory *)accessory
{
    NSString *ownerID = PPAccessoryBridgeTrimmedString(accessory.ownerID);
    NSString *currentUserID = [self currentUserID];
    return ownerID.length > 0 &&
        currentUserID.length > 0 &&
        [ownerID isEqualToString:currentUserID];
}

+ (BOOL)isAccessoryUnavailable:(PetAccessory *)accessory
{
    return accessory.isBlocked ||
        accessory.isDeleted ||
        accessory.isDisabled;
}

+ (BOOL)shouldShowCartForAccessory:(PetAccessory *)accessory
{
    return ![self isUsedAccessory:accessory];
}

+ (NSInteger)cartQuantityForAccessory:(PetAccessory *)accessory
{
    return [CartManager.sharedManager quantityForAccessory:accessory];
}

+ (NSInteger)cartItemsCount
{
    return [CartManager.sharedManager totalItemsCount];
}

+ (UserModel *)officialSupportOwner
{
    UserModel *user = [UserModel new];
    user.ID = PPAccessoryOfficialSupportUserID;
    user.UserName =
        [self localizedTextForKey:@"accessory_view_store_name"
                         fallback:@"Pure Pets Store"];
    return user;
}

+ (void)fetchOwnerForAccessory:(PetAccessory *)accessory
                    completion:(void (^)(UserModel * _Nullable,
                                         NSError * _Nullable))completion
{
    NSString *ownerID = PPAccessoryBridgeTrimmedString(accessory.ownerID);
    if (ownerID.length == 0 || [ownerID isEqualToString:@"unknown"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, nil);
        });
        return;
    }
    if ([ownerID isEqualToString:PPAccessoryOfficialSupportUserID]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([self officialSupportOwner], nil);
        });
        return;
    }
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (currentUser &&
        [currentUser.ID isEqualToString:ownerID]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(currentUser, nil);
        });
        return;
    }

    [UserManager.sharedManager
     getOtherUserModelFromFirestoreWithUID:ownerID
     completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(user, error);
        });
    }];
}

+ (void)fetchSuggestionsForAccessory:(PetAccessory *)accessory
                          completion:(void (^)(NSArray<PetAccessory *> *,
                                               BOOL,
                                               NSError * _Nullable))completion
{
    void (^categoryFallback)(void) = ^{
        [PetAccessoryManager
         fetchSuggestedAccessoriesForAccess:accessory
         completion:^(NSArray<PetAccessory *> *items) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(items ?: @[], NO, nil);
            });
        }];
    };

    if (![self isProviderMarketplaceAccessory:accessory]) {
        categoryFallback();
        return;
    }

    [PetAccessoryManager
     fetchProviderMarketplaceAccessoriesForOwnerID:accessory.ownerID
     excludingAccessory:accessory
     completionWithError:^(NSArray<PetAccessory *> *items,
                           NSError * _Nullable error) {
        if (items.count >= 2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(items, YES, error);
            });
        } else {
            categoryFallback();
        }
    }];
}

+ (void)loadFavoriteForAccessoryID:(NSString *)accessoryID
                        completion:(void (^)(BOOL,
                                             NSError * _Nullable))completion
{
    NSString *userID = [self currentUserID];
    if (![self isSignedIn] || userID.length == 0 ||
        accessoryID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, nil);
        });
        return;
    }

    [PetAdManager isAdFavorited:accessoryID
                        forUser:userID
                     collection:@"favoritesAccessories"
                     completion:^(BOOL favorited) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(favorited, nil);
        });
    }];
}

+ (void)setFavorite:(BOOL)isFavorite
      accessoryID:(NSString *)accessoryID
        completion:(void (^)(NSError * _Nullable))completion
{
    NSString *userID = [self currentUserID];
    if (![self isSignedIn] || userID.length == 0 ||
        accessoryID.length == 0) {
        NSError *error =
            [NSError errorWithDomain:PPAccessoryViewerBridgeErrorDomain
                                code:1001
                            userInfo:@{
            NSLocalizedDescriptionKey:
                [self localizedTextForKey:@"accessory_view_sign_in_required"
                                 fallback:@"Sign in to continue."]
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
        return;
    }

    if (isFavorite) {
        [PetAdManager addFavoriteAdWithID:accessoryID
                               collection:@"favoritesAccessories"
                                forUserID:userID
                               completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }];
    } else {
        [PetAdManager removeFavoriteAdWithID:accessoryID
                                  collection:@"favoritesAccessories"
                                   forUserID:userID
                                  completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }];
    }
}

+ (void)addAccessory:(PetAccessory *)accessory
             quantity:(NSInteger)quantity
   fromViewController:(UIViewController *)viewController
            completion:(void (^)(PPAccessoryCartResultCode,
                                 NSInteger,
                                 NSInteger,
                                 NSInteger))completion
{
    [PPCommerceFeedbackManager.shared
     playEvent:PPCommerceFeedbackEventPaymentAction];

    void (^finish)(PPAccessoryCartResultCode, NSInteger) =
        ^(PPAccessoryCartResultCode result, NSInteger addedQuantity) {
        NSInteger cartQuantity =
            [CartManager.sharedManager quantityForAccessory:accessory];
        NSInteger remaining = MAX(0, accessory.quantity - cartQuantity);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, addedQuantity, cartQuantity, remaining);
        });
    };

    if ([self isAccessoryUnavailable:accessory]) {
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
        finish(PPAccessoryCartResultCodeUnavailable, 0);
        return;
    }
    if (![self isNetworkAvailable]) {
        UIViewController *presenter =
            PPAccessoryResolvedPresenter(viewController);
        [PPAlertHelper showWarningIn:presenter
                              title:[self localizedTextForKey:
                                     @"offline_action_title"
                                                          fallback:@"You're offline"]
                           subtitle:[self localizedTextForKey:
                                     @"offline_action_message"
                                                          fallback:@"Check your connection and try again."]
                         completion:nil];
        finish(PPAccessoryCartResultCodeOffline, 0);
        return;
    }
    if (![self isSignedIn]) {
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
        [UserManager showPromptOnTopController];
        finish(PPAccessoryCartResultCodeAuthenticationRequired, 0);
        return;
    }

    NSInteger stock = MAX(accessory.quantity, 0);
    NSInteger existing =
        [CartManager.sharedManager quantityForAccessory:accessory];
    NSInteger requested = MAX(quantity, 1);
    NSInteger available = MAX(0, stock - existing);
    if (stock <= 0 || available <= 0) {
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
        UIViewController *presenter =
            PPAccessoryResolvedPresenter(viewController);
        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:
                [self localizedTextForKey:@"Out of stock"
                                 fallback:@"Out of stock"]
             message:nil
             preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:
            [UIAlertAction
             actionWithTitle:[self localizedTextForKey:@"OK" fallback:@"OK"]
             style:UIAlertActionStyleDefault
             handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
        finish(PPAccessoryCartResultCodeOutOfStock, 0);
        return;
    }

    NSInteger safeQuantity = MIN(requested, available);
    CartItem *item =
        [[CartItem alloc] initWithAccessory:accessory quantity:safeQuantity];
    UIViewController *presenter =
        PPAccessoryResolvedPresenter(viewController);
    [CartManager.sharedManager
     addItem:item
     presentingViewController:presenter
     completion:^(BOOL didAdd, BOOL didCancel) {
        if (didCancel) {
            finish(PPAccessoryCartResultCodeCancelled, 0);
            return;
        }
        if (!didAdd) {
            [PPCommerceFeedbackManager.shared
             playEvent:PPCommerceFeedbackEventPaymentFailure];
            finish(PPAccessoryCartResultCodeFailed, 0);
            return;
        }

        [PPAnalytics logAddToCartItemID:accessory.accessoryID
                                   name:accessory.name
                               category:[NSString stringWithFormat:
                                         @"acc-%ld",
                                         (long)accessory.petMainCategoryID]
                                  price:accessory.finalPrice.doubleValue
                               quantity:safeQuantity];

        NSString *message = safeQuantity < requested
            ? [NSString stringWithFormat:@"%@ %ld %@",
               [self localizedTextForKey:@"Only" fallback:@"Only"],
               (long)available,
               [self localizedTextForKey:@"left in stock"
                                fallback:@"left in stock"]]
            : [self localizedTextForKey:@"ItemAddedToYourCart"
                               fallback:@"Item added to your cart."];
        [PPHUD showSuccess:
            [self localizedTextForKey:@"AddedToCart" fallback:@"Added"]
                    subtitle:message
                       delay:1.25];

        if ([viewController isKindOfClass:AccessViewerVC.class]) {
            AccessViewerVC *viewerController =
                (AccessViewerVC *)viewController;
            [viewerController.QtyDelegate updateCartAndReloadCollection];
        }
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventCartQuantityChanged];
        finish(PPAccessoryCartResultCodeSuccess, safeQuantity);
    }];
}

+ (NSString *)displayNameForUser:(UserModel *)user
{
    NSString *name = [user bestDisplayName];
    return name.length > 0
        ? name
        : [self localizedTextForKey:@"accessory_view_seller_title"
                           fallback:@"Seller"];
}

+ (nullable NSString *)avatarURLForUser:(UserModel *)user
{
    return user.UserImageUrl.absoluteString;
}

+ (nullable NSString *)phoneNumberForUser:(UserModel *)user
{
    NSString *phone = PPAccessoryBridgeTrimmedString(user.MobileNo);
    return phone.length > 0 ? phone : nil;
}

+ (BOOL)isUserVerified:(UserModel *)user
{
    return user.isVerified;
}

+ (BOOL)isChatAllowedForUser:(UserModel *)user
{
    return !user.isChatEffectivelyBlocked && user.canUseChatFeature;
}

+ (void)shareAccessory:(PetAccessory *)accessory
     fromViewController:(UIViewController *)viewController
{
    [PetAccessory sharePetAccessory:accessory
                 fromViewController:PPAccessoryResolvedPresenter(viewController)
                         sourceView:viewController.view];
    [self trackInteractionCode:PPItemInteractionTypeShare
                  forAccessory:accessory];
    [PPCommerceFeedbackManager.shared
     playEvent:PPCommerceFeedbackEventPaymentAction];
}

+ (void)callOwner:(UserModel *)owner
      accessory:(PetAccessory *)accessory
fromViewController:(UIViewController *)viewController
{
    [self trackInteractionCode:PPItemInteractionTypeCall
                  forAccessory:accessory];
    NSString *phone = [self phoneNumberForUser:owner];
    UIViewController *presenter =
        PPAccessoryResolvedPresenter(viewController);
    if (phone.length == 0) {
        [PPAlertHelper
         showInfoIn:presenter
         title:[self localizedTextForKey:@"No Number"
                                fallback:@"No Number"]
         subtitle:[self localizedTextForKey:@"This user has no phone number"
                                   fallback:@"This user has no phone number"]];
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }
    [AppClasses callPhoneNumber:phone fromViewController:presenter];
    [PPCommerceFeedbackManager.shared
     playEvent:PPCommerceFeedbackEventPaymentAction];
}

+ (void)chatWithOwner:(UserModel *)owner
          accessory:(PetAccessory *)accessory
fromViewController:(UIViewController *)viewController
{
    [self trackInteractionCode:PPItemInteractionTypeChat
                  forAccessory:accessory];
    [GM chatWith:owner
     FromController:PPAccessoryResolvedPresenter(viewController)];
    [PPCommerceFeedbackManager.shared
     playEvent:PPCommerceFeedbackEventPaymentAction];
}

+ (void)openSupportFromViewController:(UIViewController *)viewController
{
    [PPCommerceFeedbackManager.shared
     playEvent:PPCommerceFeedbackEventPaymentAction];
    [ChManager.sharedManager
     openSupportChatFromController:
        PPAccessoryResolvedPresenter(viewController)];
}

+ (void)openCartFromViewController:(UIViewController *)viewController
{
    CartViewController *cart = [[CartViewController alloc] init];
    UIViewController *presenter =
        PPAccessoryResolvedPresenter(viewController);
    UINavigationController *navigation =
        presenter.navigationController ?: viewController.navigationController;
    if (navigation) {
        [navigation pushViewController:cart animated:YES];
    }
}

+ (void)openSellerProfileForAccessory:(PetAccessory *)accessory
                                owner:(UserModel *)owner
                          suggestions:(NSArray<PetAccessory *> *)suggestions
                   fromViewController:(UIViewController *)viewController
{
    NSString *ownerID = PPAccessoryBridgeTrimmedString(accessory.ownerID);
    NSMutableArray<PetAccessory *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSArray<PetAccessory *> *candidates =
        [@[accessory] arrayByAddingObjectsFromArray:suggestions ?: @[]];
    for (PetAccessory *item in candidates) {
        if (![item isKindOfClass:PetAccessory.class] ||
            item.isBlocked ||
            item.isDeleted ||
            item.isDisabled) {
            continue;
        }
        if (item.ownerID.length > 0 &&
            ownerID.length > 0 &&
            ![item.ownerID isEqualToString:ownerID]) {
            continue;
        }
        NSString *itemID =
            PPAccessoryBridgeTrimmedString(item.accessoryID);
        if (itemID.length > 0 && [seen containsObject:itemID]) {
            continue;
        }
        if (itemID.length > 0) {
            [seen addObject:itemID];
        }
        [items addObject:item];
    }

    SellerProfileVC *profile = [[SellerProfileVC alloc] init];
    profile.seller = owner;
    profile.sellerItems = items.copy;
    UIViewController *presenter =
        PPAccessoryResolvedPresenter(viewController);
    if ([viewController conformsToProtocol:
         @protocol(SellerProfileVCDelegate)]) {
        profile.delegate =
            (id<SellerProfileVCDelegate>)viewController;
    }
    profile.parentVC = viewController;
    [presenter.navigationController
     pushViewController:profile
     animated:YES];
}

+ (void)openAccessory:(PetAccessory *)accessory
    fromViewController:(UIViewController *)viewController
{
    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = accessory;
    viewer.hidesBottomBarWhenPushed = YES;
    if ([viewController isKindOfClass:AccessViewerVC.class]) {
        AccessViewerVC *source = (AccessViewerVC *)viewController;
        viewer.QtyDelegate = source.QtyDelegate;
        viewer.ParentVC = source;
    }

    UIViewController *presenter =
        PPAccessoryResolvedPresenter(viewController);
    UINavigationController *navigation =
        presenter.navigationController ?: viewController.navigationController;
    if (navigation) {
        [navigation pushViewController:viewer animated:YES];
    } else {
        PPNavigationController *wrapper =
            [[PPNavigationController alloc]
             initWithRootViewController:viewer];
        wrapper.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:wrapper
                                animated:YES
                              completion:nil];
    }
}

+ (void)closeFromViewController:(UIViewController *)viewController
{
    UINavigationController *navigation = viewController.navigationController;
    if (navigation.topViewController == viewController &&
        navigation.viewControllers.count > 1) {
        [navigation popViewControllerAnimated:YES];
        return;
    }
    if (navigation.presentingViewController) {
        [navigation dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    if (viewController.presentingViewController) {
        [viewController dismissViewControllerAnimated:YES completion:nil];
    }
}

+ (void)presentSignInFromViewController:(UIViewController *)viewController
                              completion:(void (^)(BOOL))completion
{
    if ([self isSignedIn]) {
        completion(YES);
        return;
    }
    [PPUserSigningManager
     presentSignInFrom:PPAccessoryResolvedPresenter(viewController)
     success:^(__unused UserModel *user) {
        completion(YES);
    }
     failure:^(__unused NSError *error) {
        completion(NO);
    }
     cancelled:^{
        completion(NO);
    }];
}

+ (void)loadImageAtURL:(nullable NSString *)urlString
             completion:(void (^)(UIImage * _Nullable))completion
{
    [PPImageLoaderManager.shared
     fetchImageWithURL:urlString
     completion:^(UIImage * _Nullable image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    }];
}

+ (void)prefetchImageURLs:(NSArray<NSString *> *)urlStrings
{
    if (urlStrings.count > 0) {
        [PPImageLoaderManager.shared prefetchURLs:urlStrings];
    }
}

+ (void)trackInteractionCode:(NSInteger)interactionCode
                forAccessory:(PetAccessory *)accessory
{
    if (accessory.accessoryID.length == 0) {
        return;
    }
    [PetAdManager trackInteraction:(PPItemInteractionType)interactionCode
                         forItemID:accessory.accessoryID
                        collection:@"petAccessories"
                            userID:[self currentUserID]
                        completion:nil];
}

+ (void)playFavoriteFeedback:(BOOL)isFavorite
{
    PPCommerceFeedbackEvent event = isFavorite
        ? PPCommerceFeedbackEventPaymentSuccess
        : PPCommerceFeedbackEventPaymentAction;
    [PPCommerceFeedbackManager.shared playEvent:event];
}

+ (void)playSelectionFeedback
{
    [PPCommerceFeedbackManager.shared
     playEvent:PPCommerceFeedbackEventCartQuantityChanged];
}

@end
