#import "PPPetAdViewerLegacyBridge.h"

#import "AccessViewerVC.h"
#import "AppClasses.h"
#import "ChManager.h"
#import "ChMessagingController.h"
#import "CitiesManager.h"
#import "EnumValues.h"
#import "GM.h"
#import "Language.h"
#import "MainKindsModel.h"
#import "PPAdSharingHelper.h"
#import "PPAlertHelper.h"
#import "PPAnalytics.h"
#import "PPCommerceFeedbackManager.h"
#import "PPImageLoaderManager.h"
#import "PPNavigationController.h"
#import "PPNetworkRetryHelper.h"
#import "PPUserSigningManager.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PetAd.h"
#import "PetAdManager.h"
#import "SubKindModel.h"
#import "UserManager.h"
#import "UserModel.h"

@import FirebaseAuth;
@import FirebaseFirestore;

static NSString * const PPPetAdViewerBridgeErrorDomain =
    @"com.purepets.pet-ad-viewer";

static UIViewController *PPPetAdViewerResolvedPresenter(
    UIViewController *source
) {
    UIViewController *presenter = source;
    BOOL didAdvance = YES;
    while (didAdvance) {
        didAdvance = NO;
        if (presenter.presentedViewController &&
            !presenter.presentedViewController.isBeingDismissed) {
            presenter = presenter.presentedViewController;
            didAdvance = YES;
            continue;
        }
        if ([presenter isKindOfClass:UINavigationController.class]) {
            UIViewController *visible =
                ((UINavigationController *)presenter).visibleViewController;
            if (visible && visible != presenter) {
                presenter = visible;
                didAdvance = YES;
                continue;
            }
        }
        if ([presenter isKindOfClass:UITabBarController.class]) {
            UIViewController *selected =
                ((UITabBarController *)presenter).selectedViewController;
            if (selected && selected != presenter) {
                presenter = selected;
                didAdvance = YES;
            }
        }
    }
    return presenter;
}

@implementation PPPetAdViewerLegacyBridge

+ (BOOL)isSignedIn
{
    return UserManager.sharedManager.isUserLoggedIn;
}

+ (BOOL)isNetworkAvailable
{
    return [PPNetworkRetryHelper isNetworkAvailable];
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

+ (void)fetchAdForID:(NSString *)adID
          completion:(void (^)(PetAd * _Nullable, NSError * _Nullable))completion
{
    if (adID.length == 0) {
        NSError *error = [NSError errorWithDomain:PPPetAdViewerBridgeErrorDomain
                                             code:1000
                                         userInfo:@{
            NSLocalizedDescriptionKey: @"The ad identifier is missing."
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, error);
        });
        return;
    }

    [PetAdManager fetchAdsWithIDs:@[adID] completion:^(NSArray<PetAd *> *ads) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(ads.firstObject, nil);
        });
    }];
}

+ (void)fetchOwnerForID:(NSString *)ownerID
             completion:(void (^)(UserModel * _Nullable,
                                  NSError * _Nullable))completion
{
    if (ownerID.length == 0) {
        NSError *error = [NSError errorWithDomain:PPPetAdViewerBridgeErrorDomain
                                             code:1001
                                         userInfo:@{
            NSLocalizedDescriptionKey: @"The advertiser identifier is missing."
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, error);
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

+ (void)fetchSimilarAdsForAd:(PetAd *)ad
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray<PetAd *> *,
                                       NSError * _Nullable))completion
{
    PetAd *queryAd = [PetAd new];
    queryAd.adID = ad.adID ?: @"";
    queryAd.category = ad.category;
    queryAd.adTitle = ad.adTitle;
    queryAd.subcategory = 0;

    [PetAdManager.sharedManager
     fetchSimilarAdsForAd:queryAd
     limit:MAX(limit, 1)
     completion:^(NSArray<PetAd *> *ads) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(ads ?: @[], nil);
        });
    }];
}

+ (void)fetchAccessoriesForAd:(PetAd *)ad
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray<PetAccessory *> *,
                                        NSError * _Nullable))completion
{
    [PetAccessoryManager.sharedManager
     fetchAccessoriesForMainCategoryID:ad.category
     subCategoryID:0
     limit:MAX(limit, 1)
     completion:^(NSArray<PetAccessory *> *accessories) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(accessories ?: @[], nil);
        });
    }];
}

+ (void)loadFavoriteForAdID:(NSString *)adID
                 completion:(void (^)(BOOL, NSError * _Nullable))completion
{
    NSString *userID = [self currentUserID];
    if (![self isSignedIn] || userID.length == 0 || adID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, nil);
        });
        return;
    }

    [PetAdManager isAdFavorited:adID
                        forUser:userID
                     collection:@"favoritesAds"
                     completion:^(BOOL favorited) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(favorited, nil);
        });
    }];
}

+ (void)setFavorite:(BOOL)isFavorite
            forAdID:(NSString *)adID
          completion:(void (^)(NSError * _Nullable))completion
{
    NSString *userID = [self currentUserID];
    if (![self isSignedIn] || userID.length == 0 || adID.length == 0) {
        NSError *error = [NSError errorWithDomain:PPPetAdViewerBridgeErrorDomain
                                             code:1002
                                         userInfo:@{
            NSLocalizedDescriptionKey: @"Authentication is required."
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
        return;
    }

    void (^finished)(NSError * _Nullable) = ^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    };

    if (isFavorite) {
        [PetAdManager addFavoriteAdWithID:adID
                               collection:@"favoritesAds"
                                forUserID:userID
                               completion:finished];
    } else {
        [PetAdManager removeFavoriteAdWithID:adID
                                  collection:@"favoritesAds"
                                   forUserID:userID
                                  completion:finished];
    }
}

+ (void)submitReportForAd:(PetAd *)ad
                   reason:(NSString *)reason
               completion:(void (^)(NSError * _Nullable))completion
{
    NSString *userID = [self currentUserID];
    if (![self isSignedIn] || userID.length == 0) {
        NSError *error = [NSError errorWithDomain:PPPetAdViewerBridgeErrorDomain
                                             code:1003
                                         userInfo:@{
            NSLocalizedDescriptionKey: @"Authentication is required."
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
        return;
    }

    if (ad.adID.length == 0 || [ad.ownerID isEqualToString:userID]) {
        NSError *error = [NSError errorWithDomain:PPPetAdViewerBridgeErrorDomain
                                             code:1004
                                         userInfo:@{
            NSLocalizedDescriptionKey: @"This advertisement cannot be reported."
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
        return;
    }

    FIRFirestore *database = FIRFirestore.firestore;
    FIRDocumentReference *adReference =
        [[database collectionWithPath:kPetAdsCollection]
         documentWithPath:ad.adID];

    [adReference updateData:@{
        @"reportedBy": [FIRFieldValue fieldValueForArrayUnion:@[userID]],
        @"reportCount": [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } completion:nil];

    NSString *reportID =
        [NSString stringWithFormat:@"%@_%@", ad.adID, userID];
    FIRDocumentReference *reportReference =
        [[database collectionWithPath:@"reports"] documentWithPath:reportID];

    NSDictionary *reportData = @{
        @"reportId": reportID,
        @"contentId": ad.adID,
        @"contentType": @"pet_ad",
        @"collection": kPetAdsCollection,
        @"reason": reason ?: @"other",
        @"reporterUid": userID,
        @"reportedOwnerUid": ad.ownerID ?: @"",
        @"status": @"pending",
        @"platform": @"ios",
        @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };

    [reportReference setData:reportData
                       merge:YES
                  completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    }];
}

+ (void)trackInteractionCode:(NSInteger)interactionCode
                       forAd:(PetAd *)ad
{
    if (ad.adID.length == 0) {
        return;
    }

    [PetAdManager trackInteraction:(PPItemInteractionType)interactionCode
                         forItemID:ad.adID
                        collection:kPetAdsCollection
                            userID:[self currentUserID]
                        completion:nil];
}

+ (void)logViewForAd:(PetAd *)ad
{
    [PPAnalytics logViewItemForAd:ad];
}

+ (void)logContactForAd:(PetAd *)ad channelCode:(NSInteger)channelCode
{
    [PPAnalytics logContactIntentForAd:ad
                               channel:(PPContactChannel)channelCode];
}

+ (NSString *)formattedPriceForAd:(PetAd *)ad
{
    NSString *currency = [Language get:@"Rials" alter:@"QAR"];
    NSString *price = [GM formatPrice:ad.price currencyCode:currency];
    return price ?: @"";
}

+ (NSString *)categoryNameForAd:(PetAd *)ad
{
    MainKindsModel *model = [MainKindsModel mainKindModelForID:ad.category];
    return model.KindName ?: @"";
}

+ (NSString *)subcategoryNameForAd:(PetAd *)ad
{
    MainKindsModel *model = [MainKindsModel mainKindModelForID:ad.category];
    return [model subKindForID:ad.subcategory].SubKindName ?: @"";
}

+ (NSString *)locationNameForAd:(PetAd *)ad
{
    NSString *cityName = @"";
    if (ad.adLocation > 0) {
        cityName = [CitiesManager.shared cityNameForID:ad.adLocation] ?: @"";
    }
    cityName =
        [cityName stringByTrimmingCharactersInSet:
         NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (cityName.length == 0) {
        cityName =
            [ad.locationName stringByTrimmingCharactersInSet:
             NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }

    if (cityName.length == 0) {
        cityName = [Language get:@"AdViewerLocationSelectedFallback"
                           alter:@"Location selected for this ad"];
    }
    return cityName ?: @"";
}

+ (NSString *)ageTextForAd:(PetAd *)ad
{
    if (!ad.petAgeMonths) {
        return @"";
    }

    NSInteger months = MAX(ad.petAgeMonths.integerValue, 0);
    if (Language.isRTL) {
        return [NSString stringWithFormat:@"%ld شهر", (long)months];
    }
    NSString *unit = months == 1 ? @"month" : @"months";
    return [NSString stringWithFormat:@"%ld %@", (long)months, unit];
}

+ (nullable NSString *)formattedDateForAd:(PetAd *)ad
{
    NSDate *date = ad.postedDate ?: ad.createdAt;
    if (!date) return nil;
    return [GM formatDateFromDate:date];
}

+ (NSString *)formattedPriceForAccessory:(PetAccessory *)accessory
{
    NSNumber *amount = accessory.finalPrice ?: accessory.price;
    return [PetAccessory formatCurrency:amount] ?: @"";
}

+ (NSString *)subtitleForAccessory:(PetAccessory *)accessory
{
    NSString *type = [PetAccessory typeTextForAccessory:accessory] ?: @"";
    NSString *condition =
        [PetAccessory conditionTextForAccessory:accessory] ?: @"";
    if (type.length > 0 && condition.length > 0) {
        return [NSString stringWithFormat:@"%@ · %@", type, condition];
    }
    return type.length > 0 ? type : condition;
}

+ (NSString *)locationNameForAccessory:(PetAccessory *)accessory
{
    NSString *city = [CitiesManager.shared cityNameForID:accessory.cityID];
    return city ?: @"";
}

+ (NSString *)displayNameForUser:(UserModel *)user
{
    NSString *name = [user bestDisplayName];
    return name.length > 0 ? name : [Language get:@"Contact Advertiser"
                                             alter:@"Contact Advertiser"];
}

+ (nullable NSString *)avatarURLForUser:(UserModel *)user
{
    return user.UserImageUrl.absoluteString;
}

+ (nullable NSString *)phoneNumberForUser:(UserModel *)user
{
    NSString *phone =
        [user.MobileNo stringByTrimmingCharactersInSet:
         NSCharacterSet.whitespaceAndNewlineCharacterSet];
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

+ (void)shareAd:(PetAd *)ad
fromViewController:(UIViewController *)viewController
{
    [PPAdSharingHelper sharePetAd:ad fromViewController:viewController];
}

+ (void)presentSignInFromViewController:(UIViewController *)viewController
                              completion:(void (^)(BOOL))completion
{
    if ([self isSignedIn]) {
        completion(YES);
        return;
    }

    [PPUserSigningManager presentSignInFrom:viewController
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

+ (void)callUser:(UserModel *)user
fromViewController:(UIViewController *)viewController
{
    NSString *phone = [self phoneNumberForUser:user];
    if (phone.length == 0) {
        [PPAlertHelper showInfoIn:viewController
                           title:[Language get:@"No Number" alter:@"No Number"]
                        subtitle:[Language get:@"This user has no phone number"
                                         alter:@"This user has no phone number"]];
        return;
    }
    [AppClasses callPhoneNumber:phone fromViewController:viewController];
}

+ (void)openWhatsAppForUser:(UserModel *)user
         fromViewController:(UIViewController *)viewController
{
    NSString *rawPhone = [self phoneNumberForUser:user];
    NSMutableString *digitsOnly = [NSMutableString string];
    for (NSUInteger index = 0; index < rawPhone.length; index++) {
        unichar character = [rawPhone characterAtIndex:index];
        if ([NSCharacterSet.decimalDigitCharacterSet
             characterIsMember:character]) {
            [digitsOnly appendFormat:@"%C", character];
        }
    }

    if (digitsOnly.length == 0) {
        [PPAlertHelper showInfoIn:viewController
                           title:[Language get:@"No Number" alter:@"No Number"]
                        subtitle:[Language get:@"This user has no phone number"
                                         alter:@"This user has no phone number"]];
        return;
    }

    [AppClasses startWhatsAppWith:digitsOnly
               fromViewController:viewController];
}

+ (void)openChatForUser:(UserModel *)user
     fromViewController:(UIViewController *)viewController
             completion:(void (^)(NSError * _Nullable))completion
{
    [ChManager.sharedManager
     createOrGetChatThreadWithUser:user
     completion:^(ChatThreadModel * _Nullable thread,
                  NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !thread) {
                NSError *resolvedError =
                    error ?: [NSError
                        errorWithDomain:PPPetAdViewerBridgeErrorDomain
                                   code:1005
                               userInfo:@{
                    NSLocalizedDescriptionKey:
                        [Language get:@"pet_ad_viewer_chat_failed"
                               alter:@"The chat could not be opened."]
                }];
                completion(resolvedError);
                return;
            }

            ChMessagingController *chat =
                [[ChMessagingController alloc] initWithChatThread:thread];
            UIViewController *presenter =
                PPPetAdViewerResolvedPresenter(viewController);
            if (!presenter ||
                presenter.isBeingDismissed ||
                presenter.isBeingPresented) {
                NSError *presentationError = [NSError
                    errorWithDomain:PPPetAdViewerBridgeErrorDomain
                               code:1006
                           userInfo:@{
                    NSLocalizedDescriptionKey:
                        [Language get:@"pet_ad_viewer_chat_failed"
                               alter:@"The chat could not be opened."]
                }];
                completion(presentationError);
                return;
            }

            PPNavigationController *navigation =
                [[PPNavigationController alloc]
                 initWithRootViewController:chat];
            navigation.modalPresentationStyle =
                UIModalPresentationFullScreen;
            [presenter presentViewController:navigation
                                    animated:YES
                                  completion:^{
                completion(nil);
            }];
        });
    }];
}

+ (void)openAccessory:(PetAccessory *)accessory
   fromViewController:(UIViewController *)viewController
{
    AccessViewerVC *viewer = [AccessViewerVC new];
    viewer.accessAds = accessory;
    viewer.hidesBottomBarWhenPushed = YES;

    UIViewController *presenter =
        PPPetAdViewerResolvedPresenter(viewController);
    UINavigationController *existingNavigation =
        presenter.navigationController ?: viewController.navigationController;
    if (existingNavigation) {
        [existingNavigation pushViewController:viewer animated:YES];
    } else {
        PPNavigationController *navigation =
            [[PPNavigationController alloc]
             initWithRootViewController:viewer];
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:navigation
                                animated:YES
                              completion:nil];
    }
}

+ (void)loadImageAtURL:(nullable NSString *)urlString
             completion:(void (^)(UIImage * _Nullable))completion
{
    [PPImageLoaderManager.shared fetchImageWithURL:urlString
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

+ (void)playFavoriteFeedback:(BOOL)isFavorite
{
    PPCommerceFeedbackEvent event = isFavorite
        ? PPCommerceFeedbackEventPaymentSuccess
        : PPCommerceFeedbackEventPaymentAction;
    [PPCommerceFeedbackManager.shared playEvent:event];
}

+ (void)setPremiumTabDockHidden:(BOOL)hidden
                       animated:(BOOL)animated
             fromViewController:(UIViewController *)viewController
{
    UITabBarController *tabBarController = viewController.tabBarController;
    SEL selector = @selector(setPremiumTabDockViewHidden:animation:);
    if ([tabBarController respondsToSelector:selector]) {
        [(id)tabBarController setPremiumTabDockViewHidden:hidden
                                                 animation:animated];
    }
}

@end
