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
#import "PPSelectPaymentVC.h"
#import "PPUniversalCellHelper.h"
#import "PPUniversalCellViewModel.h"
#import "PPUserSigningManager.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PetAdManager.h"
#import "SellerProfileVC.h"
#import "UserManager.h"
#import "UserModel.h"

@import FirebaseAuth;
@import FirebaseFirestore;

#import <float.h>
#import <math.h>

static NSString * const PPAccessoryViewerBridgeErrorDomain =
    @"com.purepets.accessory-viewer";
static NSString * const PPAccessoryOfficialSupportUserID =
    @"PUIDPOFFICILAL20262214";
static NSString * const PPAccessorySupportAvatarToken =
    @"purepets://support-logo";

static NSString *PPAccessoryBridgeTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [value stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSNumberFormatter *PPAccessoryBridgeCurrencyFormatter(BOOL isRTL)
{
    static NSNumberFormatter *arabicFormatter;
    static NSNumberFormatter *englishFormatter;
    static dispatch_once_t arabicOnceToken;
    static dispatch_once_t englishOnceToken;

    if (isRTL) {
        dispatch_once(&arabicOnceToken, ^{
            arabicFormatter = [[NSNumberFormatter alloc] init];
            arabicFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
            arabicFormatter.locale =
                [NSLocale localeWithLocaleIdentifier:@"ar_QA"];
            arabicFormatter.currencyCode = @"QAR";
            arabicFormatter.minimumFractionDigits = 0;
            arabicFormatter.maximumFractionDigits = 2;
        });
        return arabicFormatter;
    }
    dispatch_once(&englishOnceToken, ^{
        englishFormatter = [[NSNumberFormatter alloc] init];
        englishFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        englishFormatter.locale =
            [NSLocale localeWithLocaleIdentifier:@"en_QA"];
        englishFormatter.currencyCode = @"QAR";
        englishFormatter.minimumFractionDigits = 0;
        englishFormatter.maximumFractionDigits = 2;
    });
    return englishFormatter;
}

static NSNumberFormatter *PPAccessoryBridgeIntegerFormatter(BOOL isRTL)
{
    static NSNumberFormatter *arabicFormatter;
    static NSNumberFormatter *englishFormatter;
    static dispatch_once_t arabicOnceToken;
    static dispatch_once_t englishOnceToken;

    if (isRTL) {
        dispatch_once(&arabicOnceToken, ^{
            arabicFormatter = [[NSNumberFormatter alloc] init];
            arabicFormatter.numberStyle = NSNumberFormatterDecimalStyle;
            arabicFormatter.maximumFractionDigits = 0;
            arabicFormatter.locale =
                [NSLocale localeWithLocaleIdentifier:@"ar_QA"];
        });
        return arabicFormatter;
    }
    dispatch_once(&englishOnceToken, ^{
        englishFormatter = [[NSNumberFormatter alloc] init];
        englishFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        englishFormatter.maximumFractionDigits = 0;
        englishFormatter.locale =
            [NSLocale localeWithLocaleIdentifier:@"en_QA"];
    });
    return englishFormatter;
}

static NSString *PPAccessoryBridgeFormattedCurrency(NSNumber *amount)
{
    if (![amount isKindOfClass:NSNumber.class]) {
        return @"";
    }
    if (fabs(amount.doubleValue) < DBL_EPSILON) {
        NSString *freeText = [Language get:@"Free" alter:@"Free"];
        return freeText.length > 0 ? freeText : @"Free";
    }

    NSNumberFormatter *formatter =
        PPAccessoryBridgeCurrencyFormatter(Language.isRTL);
    return [formatter stringFromNumber:amount] ?: @"";
}

static NSString *PPAccessoryBridgeFormattedInteger(NSInteger value)
{
    NSNumberFormatter *formatter =
        PPAccessoryBridgeIntegerFormatter(Language.isRTL);
    return [formatter stringFromNumber:@(MAX(value, 0))]
        ?: [NSString stringWithFormat:@"%ld", (long)MAX(value, 0)];
}

static NSString *PPAccessoryBridgeProviderDisplayName(
    NSString *providerID,
    NSString *fallback
) {
    NSString *cleanProviderID =
        PPAccessoryBridgeTrimmedString(providerID);
    UserModel *user =
        cleanProviderID.length > 0
            ? [UserManager userModelForID:cleanProviderID]
            : nil;
    NSString *displayName =
        PPAccessoryBridgeTrimmedString([user bestDisplayName]);
    return displayName.length > 0 ? displayName : fallback;
}

static NSString *PPAccessoryBridgeProviderProfileImageURL(NSDictionary *data)
{
    if (![data isKindOfClass:NSDictionary.class]) {
        NSLog(@"[PPAccessoryViewer][SellerImage] Provider profile payload is not a dictionary.");
        return @"";
    }

    NSDictionary *form =
        [data[@"form"] isKindOfClass:NSDictionary.class] ? data[@"form"] : @{};
    NSDictionary *userSummary =
        [data[@"userSummary"] isKindOfClass:NSDictionary.class]
            ? data[@"userSummary"]
            : @{};
    NSArray *candidates = @[
        userSummary[@"photoURL"] ?: @"",
        data[@"avatarURL"] ?: @"",
        data[@"photoURL"] ?: @"",
        data[@"photoUrl"] ?: @"",
        data[@"UserImageUrl"] ?: @"",
        userSummary[@"avatarURL"] ?: @"",
        form[@"photoURL"] ?: @"",
        form[@"logoURL"] ?: @"",
        form[@"logoUrl"] ?: @"",
        data[@"logoURL"] ?: @"",
        data[@"logoUrl"] ?: @"",
        data[@"profileImageURL"] ?: @"",
        data[@"profileImageUrl"] ?: @"",
        data[@"imageURL"] ?: @"",
        data[@"imageUrl"] ?: @""
    ];

    for (id value in candidates) {
        NSString *cleanURL = PPAccessoryBridgeTrimmedString(value);
        if (cleanURL.length > 0) {
            NSLog(@"[PPAccessoryViewer][SellerImage] Resolved provider profile image candidate: %@", cleanURL);
            return cleanURL;
        }
    }
    NSLog(@"[PPAccessoryViewer][SellerImage] No provider profile image candidate was found in profile payload.");
    return @"";
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

@interface PPAccessoryViewerLegacyBridge ()

+ (void)pp_addAccessory:(PetAccessory *)accessory
                quantity:(NSInteger)quantity
      fromViewController:(UIViewController *)viewController
       showsSuccessToast:(BOOL)showsSuccessToast
   waitsForConfirmedSync:(BOOL)waitsForConfirmedSync
               completion:(void (^)(PPAccessoryCartResultCode result,
                                    NSInteger addedQuantity,
                                    NSInteger cartQuantity,
                                    NSInteger remainingStock))completion;

@end

@interface PPAccessoryCheckoutPreview ()

@property (nonatomic, copy, readwrite) NSString *selectionTotalText;
@property (nonatomic, copy, readwrite) NSString *cartSubtotalText;
@property (nonatomic, assign, readwrite) NSInteger unitsCount;
@property (nonatomic, assign, readwrite) BOOL requiresProviderSwitch;
@property (nonatomic, assign, readwrite) BOOL canCommit;

- (instancetype)initWithSelectionTotalText:(NSString *)selectionTotalText
                           cartSubtotalText:(NSString *)cartSubtotalText
                                 unitsCount:(NSInteger)unitsCount
                     requiresProviderSwitch:(BOOL)requiresProviderSwitch
                                  canCommit:(BOOL)canCommit;

@end

@implementation PPAccessoryCheckoutPreview

- (instancetype)initWithSelectionTotalText:(NSString *)selectionTotalText
                           cartSubtotalText:(NSString *)cartSubtotalText
                                 unitsCount:(NSInteger)unitsCount
                     requiresProviderSwitch:(BOOL)requiresProviderSwitch
                                  canCommit:(BOOL)canCommit
{
    self = [super init];
    if (self) {
        _selectionTotalText = [selectionTotalText copy] ?: @"";
        _cartSubtotalText = [cartSubtotalText copy] ?: @"";
        _unitsCount = MAX(unitsCount, 0);
        _requiresProviderSwitch = requiresProviderSwitch;
        _canCommit = canCommit;
    }
    return self;
}

@end

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
    return PPAccessoryBridgeFormattedCurrency(
        accessory.finalPrice ?: accessory.price
    );
}

+ (NSString *)formattedPriceForAccessory:(PetAccessory *)accessory quantity:(NSInteger)quantity
{
    if (!accessory) {
        return @"";
    }
    NSNumber *unitPriceNum = accessory.finalPrice ?: accessory.price;
    double unitPrice = unitPriceNum.doubleValue;
    double total = unitPrice * MAX(1, quantity);
    return PPAccessoryBridgeFormattedCurrency(@(total));
}

+ (NSString *)formattedOriginalPriceForAccessory:(PetAccessory *)accessory
{
    return PPAccessoryBridgeFormattedCurrency(accessory.price);
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
    formatter.locale = [NSLocale localeWithLocaleIdentifier:
        Language.isRTL ? @"ar_QA" : @"en_QA"];
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
    formatter.locale = [NSLocale localeWithLocaleIdentifier:
        Language.isRTL ? @"ar_QA" : @"en_QA"];
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

+ (void)updateCartQuantity:(NSInteger)quantity
              forAccessory:(PetAccessory *)accessory
                completion:(void (^)(BOOL,
                                     NSInteger,
                                     NSInteger))completion
{
    void (^finish)(BOOL) = ^(BOOL succeeded) {
        NSInteger cartQuantity =
            [CartManager.sharedManager quantityForAccessory:accessory];
        NSInteger remainingStock =
            MAX(0, accessory.quantity - cartQuantity);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(succeeded, cartQuantity, remainingStock);
        });
    };

    if (!accessory || ![self isSignedIn]) {
        finish(NO);
        return;
    }

    CartManager *cartManager = CartManager.sharedManager;
    CartItem *item =
        [cartManager getCartItemForItemID:accessory.accessoryID];
    if (!item) {
        finish(NO);
        return;
    }

    NSInteger requestedQuantity = MAX(quantity, 0);
    if (requestedQuantity == 0) {
        [cartManager removeItemForAccessory:accessory];
        finish(YES);
        return;
    }

    [cartManager updateQuantity:requestedQuantity
                         forItem:item
                      completion:^(BOOL succeeded) {
        finish(succeeded);
    }];
}

+ (PPAccessoryCheckoutPreview *)checkoutPreviewForAccessory:(PetAccessory *)accessory
                                                    quantity:(NSInteger)quantity
{
    NSInteger safeQuantity = MAX(quantity, 1);
    CartManager *cartManager = CartManager.sharedManager;
    CartItem *item =
        [[CartItem alloc] initWithAccessory:accessory quantity:safeQuantity];
    PPCartAddProjection *projection =
        [cartManager projectionForAddingItem:item];
    BOOL requiresProviderSwitch = projection
        ? projection.requiresProviderSwitch
        : [cartManager shouldConfirmProviderSwitchForItem:item];
    double selectionSubtotal = projection
        ? projection.selectionSubtotal
        : MAX(0.0, item.lineSubtotal);
    double projectedSubtotal = projection
        ? projection.projectedSubtotal
        : cartManager.subtotalAmount;
    NSInteger projectedUnits = projection
        ? projection.totalUnits
        : cartManager.totalItemsCount;

    return [[PPAccessoryCheckoutPreview alloc]
        initWithSelectionTotalText:
            PPAccessoryBridgeFormattedCurrency(@(selectionSubtotal))
                 cartSubtotalText:
            PPAccessoryBridgeFormattedCurrency(@(projectedSubtotal))
                       unitsCount:projectedUnits
           requiresProviderSwitch:requiresProviderSwitch
                        canCommit:projection != nil];
}

+ (UserModel *)officialSupportOwner
{
    UserModel *user = [UserModel new];
    user.ID = PPAccessoryOfficialSupportUserID;
    user.UserName =
        [self localizedTextForKey:@"accessory_view_store_name"
                         fallback:@"Pure Pets Store"];
    user.UserImageUrl =
        [NSURL URLWithString:PPAccessorySupportAvatarToken];
    return user;
}

+ (nullable id)listenToAccessoryID:(NSString *)accessoryID
                           onChange:(void (^)(PetAccessory * _Nullable updatedAccessory))onChange
{
    if (!onChange) {
        return nil;
    }
    return [self listenToAccessoryID:accessoryID
                            onUpdate:^(PPAccessoryLiveUpdateStatus status,
                                       PetAccessory * _Nullable updatedAccessory) {
        onChange(
            status == PPAccessoryLiveUpdateStatusUpdated
                ? updatedAccessory
                : nil
        );
    }];
}

+ (nullable id)listenToAccessoryID:(NSString *)accessoryID
                           onUpdate:(void (^)(PPAccessoryLiveUpdateStatus,
                                              PetAccessory * _Nullable))onUpdate
{
    NSString *cleanID = PPAccessoryBridgeTrimmedString(accessoryID);
    if (cleanID.length == 0 || !onUpdate) {
        return nil;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *ref = [[db collectionWithPath:@"petAccessories"] documentWithPath:cleanID];
    return [ref addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onUpdate(PPAccessoryLiveUpdateStatusFailed, nil);
            });
            return;
        }
        if (!snapshot.exists) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onUpdate(PPAccessoryLiveUpdateStatusMissing, nil);
            });
            return;
        }
        PetAccessory *acc = [[PetAccessory alloc] initWithDictionary:snapshot.data documentID:snapshot.documentID];
        dispatch_async(dispatch_get_main_queue(), ^{
            onUpdate(PPAccessoryLiveUpdateStatusUpdated, acc);
        });
    }];
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

+ (void)fetchProviderProfileImageURLForOwnerID:(NSString *)ownerID
                                    completion:(void (^)(NSString * _Nullable))completion
{
    if (!completion) {
        NSLog(@"[PPAccessoryViewer][SellerImage] Missing completion while fetching provider profile image for ownerID=%@", ownerID ?: @"<nil>");
        return;
    }

    NSString *cleanOwnerID = PPAccessoryBridgeTrimmedString(ownerID);
    if (cleanOwnerID.length == 0 ||
        [cleanOwnerID isEqualToString:@"unknown"] ||
        [cleanOwnerID isEqualToString:PPAccessoryOfficialSupportUserID]) {
        NSLog(@"[PPAccessoryViewer][SellerImage] Skipping provider profile fetch because ownerID is invalid or official support. ownerID=%@", ownerID ?: @"<nil>");
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
        return;
    }

    NSString *profileID =
        [NSString stringWithFormat:@"%@_%@", cleanOwnerID, @"marketplace"];
    NSLog(@"[PPAccessoryViewer][SellerImage] Fetching provider profile image. ownerID=%@ profileID=%@", cleanOwnerID, profileID);
    FIRDocumentReference *profileRef =
        [[[FIRFirestore firestore] collectionWithPath:@"providerProfiles"]
         documentWithPath:profileID];
    [profileRef getDocumentWithCompletion:^(
        FIRDocumentSnapshot * _Nullable snapshot,
        NSError * _Nullable error
    ) {
        NSString *imageURL = nil;
        if (error) {
            NSLog(@"[PPAccessoryViewer][SellerImage] Provider profile fetch failed. ownerID=%@ profileID=%@ error=%@", cleanOwnerID, profileID, error.localizedDescription ?: error);
        } else if (!snapshot.exists) {
            NSLog(@"[PPAccessoryViewer][SellerImage] Provider profile document does not exist. ownerID=%@ profileID=%@", cleanOwnerID, profileID);
        } else {
            imageURL =
                PPAccessoryBridgeProviderProfileImageURL(snapshot.data ?: @{});
        }
        NSLog(@"[PPAccessoryViewer][SellerImage] Provider profile fetch resolved. ownerID=%@ profileID=%@ imageURL=%@", cleanOwnerID, profileID, imageURL.length > 0 ? imageURL : @"<nil>");
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(imageURL.length > 0 ? imageURL : nil);
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

+ (void)registerStockNotificationForAccessory:(PetAccessory *)accessory
                                    completion:(void (^)(BOOL))completion
{
    if (![accessory isKindOfClass:PetAccessory.class]) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
            });
        }
        return;
    }

    PPCellContext context =
        accessory.isFood ? PPCellForFood : PPCellForMarket;
    PPUniversalCellViewModel *viewModel =
        [[PPUniversalCellViewModel alloc] initWithModel:accessory
                                                context:context];
    [PPUniversalCellSwiftUIBridge
     registerStockNotificationForViewModel:viewModel
     completion:^(BOOL succeeded) {
        if (completion) {
            completion(succeeded);
        }
    }];
}

+ (void)addAccessory:(PetAccessory *)accessory
             quantity:(NSInteger)quantity
   fromViewController:(UIViewController *)viewController
            completion:(void (^)(PPAccessoryCartResultCode,
                                 NSInteger,
                                 NSInteger,
                                 NSInteger))completion
{
    [self pp_addAccessory:accessory
                 quantity:quantity
       fromViewController:viewController
        showsSuccessToast:YES
    waitsForConfirmedSync:NO
                completion:completion];
}

+ (void)prepareAccessoryForCheckout:(PetAccessory *)accessory
                            quantity:(NSInteger)quantity
                  fromViewController:(UIViewController *)viewController
                           completion:(void (^)(PPAccessoryCartResultCode,
                                                NSInteger,
                                                NSInteger,
                                                NSInteger))completion
{
    [self pp_addAccessory:accessory
                 quantity:quantity
       fromViewController:viewController
        showsSuccessToast:NO
    waitsForConfirmedSync:YES
                completion:completion];
}

+ (void)beginDirectCheckoutForAccessory:(PetAccessory *)accessory
                               quantity:(NSInteger)quantity
                     fromViewController:(UIViewController *)viewController
                             completion:(void (^)(PPAccessoryCartResultCode))completion
{
    [PPCommerceFeedbackManager.shared
     playEvent:PPCommerceFeedbackEventPaymentAction];

    void (^finish)(PPAccessoryCartResultCode) =
        ^(PPAccessoryCartResultCode result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result);
        });
    };

    NSString *accessoryID =
        PPAccessoryBridgeTrimmedString(accessory.accessoryID);
    if (![accessory isKindOfClass:PetAccessory.class] ||
        accessoryID.length == 0 ||
        [self isAccessoryUnavailable:accessory]) {
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
        finish(PPAccessoryCartResultCodeUnavailable);
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
        finish(PPAccessoryCartResultCodeOffline);
        return;
    }

    if (![self isSignedIn]) {
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
        [UserManager showPromptOnTopController];
        finish(PPAccessoryCartResultCodeAuthenticationRequired);
        return;
    }

    NSInteger requestedQuantity = MAX(quantity, 0);
    NSInteger availableStock = MAX(accessory.quantity, 0);
    if (requestedQuantity <= 0 ||
        availableStock <= 0 ||
        requestedQuantity > availableStock) {
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
        finish(PPAccessoryCartResultCodeOutOfStock);
        return;
    }

    CartItem *item =
        [[CartItem alloc] initWithAccessory:accessory
                                    quantity:requestedQuantity];
    UIViewController *presenter =
        PPAccessoryResolvedPresenter(viewController);
    UIViewController *routeSource =
        presenter.navigationController ? presenter : viewController;
    BOOL didOpen =
        [PPSelectPaymentVC pushFromViewController:routeSource
                                     checkoutItems:@[item]];
    if (!didOpen) {
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
        finish(PPAccessoryCartResultCodeFailed);
        return;
    }

    finish(PPAccessoryCartResultCodeSuccess);
}

+ (void)pp_addAccessory:(PetAccessory *)accessory
                quantity:(NSInteger)quantity
      fromViewController:(UIViewController *)viewController
       showsSuccessToast:(BOOL)showsSuccessToast
   waitsForConfirmedSync:(BOOL)waitsForConfirmedSync
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
    CartManager *cartManager = CartManager.sharedManager;

    void (^handleAddResult)(BOOL, BOOL) =
        ^(BOOL didAdd, BOOL didCancel) {
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
        if (showsSuccessToast) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [PPAddToCartSuccessToast showWithTitle:
                    [self localizedTextForKey:@"AddedToCart" fallback:@"Added"]
                                            subtitle:message];
            });
        }

        if ([viewController isKindOfClass:AccessViewerVC.class]) {
            AccessViewerVC *viewerController =
                (AccessViewerVC *)viewController;
            [viewerController.QtyDelegate updateCartAndReloadCollection];
        }
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventCartQuantityChanged];
        finish(PPAccessoryCartResultCodeSuccess, safeQuantity);
    };

    void (^commitPreparedItem)(void) = ^{
        if (waitsForConfirmedSync) {
            [cartManager addItemAndWaitForSync:item
                                    completion:^(BOOL succeeded) {
                handleAddResult(succeeded, NO);
            }];
            return;
        }

        [cartManager addItem:item
            presentingViewController:presenter
                       completion:handleAddResult];
    };

    if ([cartManager shouldConfirmProviderSwitchForItem:item]) {
        CartItem *currentItem = cartManager.cartItems.firstObject;
        NSString *currentFallback =
            currentItem.name.length > 0
                ? [NSString stringWithFormat:
                    [self localizedTextForKey:
                        @"accessory_view_provider_for_product_format"
                                         fallback:@"Seller for %@"],
                    currentItem.name]
                : [self localizedTextForKey:
                    @"accessory_view_current_provider_fallback"
                                     fallback:@"Current seller"];
        NSString *newFallback =
            accessory.name.length > 0
                ? [NSString stringWithFormat:
                    [self localizedTextForKey:
                        @"accessory_view_provider_for_product_format"
                                         fallback:@"Seller for %@"],
                    accessory.name]
                : [self localizedTextForKey:
                    @"accessory_view_new_provider_fallback"
                                     fallback:@"New seller"];
        NSString *currentProvider =
            PPAccessoryBridgeProviderDisplayName(
                currentItem.providerID,
                currentFallback
            );
        NSString *newProvider =
            PPAccessoryBridgeProviderDisplayName(
                item.providerID,
                newFallback
            );
        NSString *messageFormat =
            [self localizedTextForKey:
                @"accessory_view_provider_switch_message_format"
                             fallback:
                @"Current provider: %@\nCurrent cart: %@ items · %@\nNew provider: %@\nQuantity to add: %@\n\nStarting a new cart removes the current items."];
        NSString *message =
            [NSString stringWithFormat:
                messageFormat,
                currentProvider,
                PPAccessoryBridgeFormattedInteger(
                    cartManager.totalItemsCount
                ),
                PPAccessoryBridgeFormattedCurrency(
                    @(cartManager.subtotalAmount)
                ),
                newProvider,
                PPAccessoryBridgeFormattedInteger(safeQuantity)];
        NSString *title =
            [NSString stringWithFormat:
                @"⚠︎ %@",
                [self localizedTextForKey:
                    @"cart_provider_switch_title"
                                     fallback:
                    @"Cart belongs to another provider"]];
        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:title
             message:message
             preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
            [UIAlertAction
             actionWithTitle:
                [self localizedTextForKey:
                    @"accessory_view_view_current_cart"
                                     fallback:@"View current cart"]
             style:UIAlertActionStyleDefault
             handler:^(__unused UIAlertAction *action) {
                handleAddResult(NO, YES);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self openCartFromViewController:presenter];
                });
             }]];
        [alert addAction:
            [UIAlertAction
             actionWithTitle:
                [self localizedTextForKey:
                    @"accessory_view_start_new_cart"
                                     fallback:@"Start new cart & add"]
             style:UIAlertActionStyleDestructive
             handler:^(__unused UIAlertAction *action) {
                [cartManager
                 clearCartAndSyncToFirestoreWithCompletion:^(BOOL cleared) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!cleared) {
                            handleAddResult(NO, NO);
                            return;
                        }
                        commitPreparedItem();
                    });
                 }];
             }]];
        [alert addAction:
            [UIAlertAction
             actionWithTitle:
                [self localizedTextForKey:
                    @"cart_provider_switch_cancel"
                                     fallback:@"Cancel"]
             style:UIAlertActionStyleCancel
             handler:^(__unused UIAlertAction *action) {
                handleAddResult(NO, YES);
             }]];
        [presenter presentViewController:alert animated:YES completion:nil];
        return;
    }

    commitPreparedItem();
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
    if (!user) return nil;
    
    // 1. Check UserImageUrl property
    if ([user respondsToSelector:@selector(UserImageUrl)]) {
        id imgUrl = user.UserImageUrl;
        if ([imgUrl isKindOfClass:[NSString class]]) {
            NSString *str = (NSString *)imgUrl;
            if (str.length > 0) return str;
        } else if ([imgUrl isKindOfClass:[NSURL class]]) {
            NSString *str = ((NSURL *)imgUrl).absoluteString;
            if (str.length > 0) return str;
        }
    }
    
    // 2. Check userImageUrl method/alias
    if ([user respondsToSelector:@selector(userImageUrl)]) {
        id imgUrlAlt = [user userImageUrl];
        if ([imgUrlAlt isKindOfClass:[NSString class]]) {
            NSString *str = (NSString *)imgUrlAlt;
            if (str.length > 0) return str;
        } else if ([imgUrlAlt isKindOfClass:[NSURL class]]) {
            NSString *str = ((NSURL *)imgUrlAlt).absoluteString;
            if (str.length > 0) return str;
        }
    }
    
    // 3. Fallback to UserImageName
    if ([user respondsToSelector:@selector(UserImageName)]) {
        NSString *name = user.UserImageName;
        if (name.length > 0) {
            if ([name hasPrefix:@"http://"] || [name hasPrefix:@"https://"]) {
                return name;
            }
        }
    }
    
    return nil;
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

+ (BOOL)openPaymentSelectionFromViewController:(UIViewController *)viewController
{
    UIViewController *presenter =
        PPAccessoryResolvedPresenter(viewController);
    UIViewController *routeSource =
        presenter.navigationController ? presenter : viewController;
    BOOL didOpen =
        [PPSelectPaymentVC pushFromViewController:routeSource];
    if (!didOpen) {
        [PPCommerceFeedbackManager.shared
         playEvent:PPCommerceFeedbackEventPaymentFailure];
    }
    return didOpen;
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
    NSString *cleanURL = PPAccessoryBridgeTrimmedString(urlString);
    if ([cleanURL hasPrefix:PPAccessorySupportAvatarToken]) {
        UIImage *supportImage =
            [UIImage imageNamed:@"newlogo"]
            ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
        NSLog(@"[PPAccessoryViewer][SellerImage] Resolved support avatar token locally. url=%@", cleanURL);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(supportImage);
        });
        return;
    }

    [PPImageLoaderManager.shared
     fetchImageWithURL:cleanURL
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
