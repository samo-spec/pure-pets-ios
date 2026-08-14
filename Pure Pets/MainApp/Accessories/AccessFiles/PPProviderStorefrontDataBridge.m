#import "PPProviderStorefrontDataBridge.h"

#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "CitiesManager.h"
#import "GM.h"
#import "UserManager.h"
#import "UserModel.h"

@import FirebaseFirestore;
@import FirebaseFunctions;

static NSString *PPProviderStorefrontSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static NSString *PPProviderStorefrontTrimmedString(id value)
{
    return [PPProviderStorefrontSafeString(value)
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *PPProviderStorefrontNormalizedCategory(NSString *value)
{
    return [PPProviderStorefrontTrimmedString(value) lowercaseString];
}

static BOOL PPProviderStorefrontIsPharmacyCategory(NSString *value)
{
    return [PPProviderStorefrontNormalizedCategory(value) isEqualToString:@"pharmacy"];
}

static NSString *PPProviderStorefrontDisplayNameForUser(UserModel *user)
{
    if (![user isKindOfClass:UserModel.class]) {
        return @"";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (user.FirstName.length > 0) {
        [parts addObject:user.FirstName];
    }
    if (user.LastName.length > 0) {
        [parts addObject:user.LastName];
    }
    if (parts.count > 0) {
        return [parts componentsJoinedByString:@" "];
    }

    NSString *displayName = [user bestDisplayName];
    if (displayName.length > 0) {
        return displayName;
    }
    displayName = [user PPBestDisplayName];
    if (displayName.length > 0) {
        return displayName;
    }
    return PPProviderStorefrontSafeString(user.UserName);
}

static NSString *PPProviderStorefrontCityText(id value)
{
    NSString *rawValue = [value isKindOfClass:NSNumber.class]
        ? [(NSNumber *)value stringValue]
        : PPProviderStorefrontTrimmedString(value);
    if (rawValue.length == 0) {
        return @"";
    }

    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    if ([rawValue rangeOfCharacterFromSet:nonDigits].location == NSNotFound && rawValue.integerValue > 0) {
        NSString *city = [CitiesManager.shared cityNameForID:rawValue.integerValue];
        if (city.length > 0) {
            return city;
        }
    }
    return rawValue;
}

static NSArray<NSString *> *PPProviderStorefrontURLArray(id value)
{
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    for (id candidate in (NSArray *)value) {
        NSString *url = PPProviderStorefrontTrimmedString(candidate);
        if (url.length > 0) {
            [urls addObject:url];
        }
    }
    return urls.copy;
}

@implementation PPProviderStorefrontProviderRecord

- (instancetype)init
{
    self = [super init];
    if (self) {
        _ownerID = @"";
        _items = @[];
        _displayName = @"";
        _aboutText = @"";
        _cityText = @"";
        _avatarURLString = @"";
        _coverURLString = @"";
    }
    return self;
}

@end

@implementation PPProviderStorefrontDataBridge

+ (void)fetchProviderRecordsForCategoryIdentifier:(NSString *)categoryIdentifier
                                        completion:(void (^)(NSArray<PPProviderStorefrontProviderRecord *> *, NSError * _Nullable))completion
{
    void (^finish)(NSArray<PetAccessory *> *, NSError * _Nullable) =
        ^(NSArray<PetAccessory *> *accessories, NSError * _Nullable error) {
        [self pp_hydrateProviderRecordsFromAccessories:accessories ?: @[]
                                     categoryIdentifier:categoryIdentifier
                                              seedError:error
                                             completion:completion];
    };

    if (PPProviderStorefrontIsPharmacyCategory(categoryIdentifier)) {
        [PetAccessoryManager fetchPublicPharmacyAccessoriesWithCompletion:finish];
    } else {
        [PetAccessoryManager fetchPublicMarketplaceAccessoriesWithCompletion:finish];
    }
}

+ (void)pp_hydrateProviderRecordsFromAccessories:(NSArray<PetAccessory *> *)accessories
                                categoryIdentifier:(NSString *)categoryIdentifier
                                         seedError:(NSError * _Nullable)seedError
                                        completion:(void (^)(NSArray<PPProviderStorefrontProviderRecord *> *, NSError * _Nullable))completion
{
    if (accessories.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], seedError);
        });
        return;
    }

    NSMutableDictionary<NSString *, NSMutableArray<PetAccessory *> *> *grouped = [NSMutableDictionary dictionary];
    for (PetAccessory *item in accessories) {
        NSString *ownerID = PPProviderStorefrontTrimmedString(item.ownerID);
        if (ownerID.length == 0) {
            continue;
        }
        NSMutableArray<PetAccessory *> *items = grouped[ownerID];
        if (!items) {
            items = [NSMutableArray array];
            grouped[ownerID] = items;
        }
        [items addObject:item];
    }

    if (grouped.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], seedError);
        });
        return;
    }

    NSMutableArray<PPProviderStorefrontProviderRecord *> *records = [NSMutableArray arrayWithCapacity:grouped.count];
    [grouped enumerateKeysAndObjectsUsingBlock:^(NSString *ownerID, NSMutableArray<PetAccessory *> *items, BOOL *stop) {
        [items sortUsingComparator:^NSComparisonResult(PetAccessory *left, PetAccessory *right) {
            NSDate *leftDate = left.createdAt ?: NSDate.distantPast;
            NSDate *rightDate = right.createdAt ?: NSDate.distantPast;
            return [rightDate compare:leftDate];
        }];

        PPProviderStorefrontProviderRecord *record = [PPProviderStorefrontProviderRecord new];
        record.ownerID = ownerID;
        record.items = items.copy;
        record.productCount = items.count;
        record.latestCreatedAt = items.firstObject.createdAt;
        [records addObject:record];
    }];

    dispatch_group_t group = dispatch_group_create();
    __block NSError *profileError = seedError;
    NSString *currentUID = [UserManager sharedManager].currentUser.ID ?: @"";

    for (PPProviderStorefrontProviderRecord *record in records) {
        dispatch_group_enter(group);
        void (^hydrateProfile)(void) = ^{
            [self pp_hydrateProviderProfileForRecord:record
                                    categoryIdentifier:categoryIdentifier
                                           completion:^{
                dispatch_group_leave(group);
            }];
        };

        if (currentUID.length > 0 &&
            [record.ownerID isEqualToString:currentUID] &&
            [UserManager sharedManager].currentUser) {
            record.user = [UserManager sharedManager].currentUser;
            hydrateProfile();
            continue;
        }

        [[UserManager sharedManager] getOtherUserModelFromFirestoreWithUID:record.ownerID
                                                                 completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
            if (user) {
                record.user = user;
                hydrateProfile();
                return;
            }
            if (error && !profileError) {
                profileError = error;
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray<PPProviderStorefrontProviderRecord *> *resolved = [NSMutableArray array];
        for (PPProviderStorefrontProviderRecord *record in records) {
            [self pp_refreshRecordPresentation:record];
            if (record.displayName.length > 0) {
                [resolved addObject:record];
            }
        }

        [resolved sortUsingComparator:^NSComparisonResult(PPProviderStorefrontProviderRecord *left,
                                                           PPProviderStorefrontProviderRecord *right) {
            if (left.productCount != right.productCount) {
                return left.productCount > right.productCount ? NSOrderedAscending : NSOrderedDescending;
            }
            NSDate *leftDate = left.latestCreatedAt ?: NSDate.distantPast;
            NSDate *rightDate = right.latestCreatedAt ?: NSDate.distantPast;
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
            return [left.displayName localizedCaseInsensitiveCompare:right.displayName];
        }];

        [self pp_refreshRatingSummariesForRecords:resolved completion:^{
            completion(resolved.copy, resolved.count == 0 ? profileError : nil);
        }];
    });
}

+ (void)pp_hydrateProviderProfileForRecord:(PPProviderStorefrontProviderRecord *)record
                         categoryIdentifier:(NSString *)categoryIdentifier
                                completion:(dispatch_block_t)completion
{
    if (record.ownerID.length == 0) {
        completion();
        return;
    }

    NSString *providerType = PPProviderStorefrontIsPharmacyCategory(categoryIdentifier)
        ? @"pharmacy"
        : @"marketplace";
    NSString *profileID = [NSString stringWithFormat:@"%@_%@", record.ownerID, providerType];
    FIRDocumentReference *reference =
        [[[FIRFirestore firestore] collectionWithPath:@"providerProfiles"] documentWithPath:profileID];
    [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!error && snapshot.exists) {
            [self pp_applyProviderProfileData:snapshot.data ?: @{} toRecord:record];
        }
        completion();
    }];
}

+ (void)pp_applyProviderProfileData:(NSDictionary *)data
                            toRecord:(PPProviderStorefrontProviderRecord *)record
{
    if (![data isKindOfClass:NSDictionary.class]) {
        return;
    }

    NSDictionary *form = [data[@"form"] isKindOfClass:NSDictionary.class] ? data[@"form"] : @{};
    NSDictionary *userSummary = [data[@"userSummary"] isKindOfClass:NSDictionary.class] ? data[@"userSummary"] : @{};

    NSString *displayName = PPProviderStorefrontTrimmedString(form[@"fullName"]);
    if (displayName.length == 0) {
        displayName = PPProviderStorefrontTrimmedString(userSummary[@"displayName"]);
    }
    if (displayName.length == 0) {
        displayName = PPProviderStorefrontTrimmedString(data[@"displayName"]);
    }
    if (displayName.length > 0) {
        record.displayName = displayName;
    }

    record.cityText = PPProviderStorefrontCityText(form[@"city"] ?: data[@"city"]);

    NSArray<NSString *> *coverURLs = PPProviderStorefrontURLArray(form[@"imageRefs"]);
    if (coverURLs.count == 0) {
        coverURLs = PPProviderStorefrontURLArray(data[@"coverImageUrls"]);
    }
    if (coverURLs.count > 0) {
        record.coverURLString = coverURLs.firstObject;
    }

    NSString *avatarURL = PPProviderStorefrontTrimmedString(userSummary[@"photoURL"]);
    if (avatarURL.length == 0) {
        avatarURL = PPProviderStorefrontTrimmedString(data[@"avatarURL"]);
    }
    if (avatarURL.length == 0) {
        avatarURL = PPProviderStorefrontTrimmedString(data[@"photoURL"]);
    }
    if (avatarURL.length > 0) {
        record.avatarURLString = avatarURL;
    }
}

+ (void)pp_refreshRecordPresentation:(PPProviderStorefrontProviderRecord *)record
{
    UserModel *user = record.user;
    if (record.displayName.length == 0) {
        record.displayName = PPProviderStorefrontDisplayNameForUser(user);
    }
    record.aboutText = PPProviderStorefrontTrimmedString(user.UserAbout);
    if (record.avatarURLString.length == 0) {
        record.avatarURLString = PPProviderStorefrontTrimmedString(user.UserImageUrl.absoluteString);
    }
    if (record.coverURLString.length == 0 && user.coverImageUrls.count > 0) {
        record.coverURLString = PPProviderStorefrontTrimmedString(user.coverImageUrls.firstObject);
    }
    if (record.coverURLString.length == 0 && record.items.count > 0) {
        PetAccessory *latest = record.items.firstObject;
        record.coverURLString = PPProviderStorefrontTrimmedString(latest.imageURLsArray.firstObject);
    }
    record.verified = user.isVerified;
    record.active = [PPProviderStorefrontSafeString(user.accountStatus) isEqualToString:@"active"];
}

+ (void)pp_refreshRatingSummariesForRecords:(NSArray<PPProviderStorefrontProviderRecord *> *)records
                                 completion:(dispatch_block_t)completion
{
    if (records.count == 0 || ![UserManager sharedManager].isUserLoggedIn) {
        completion();
        return;
    }

    NSMutableOrderedSet<NSString *> *providerIDs = [NSMutableOrderedSet orderedSet];
    for (PPProviderStorefrontProviderRecord *record in records) {
        if (record.ownerID.length > 0) {
            [providerIDs addObject:record.ownerID];
        }
    }
    NSArray<NSString *> *requestedIDs = providerIDs.count > 50
        ? [providerIDs.array subarrayWithRange:NSMakeRange(0, 50)]
        : providerIDs.array;
    if (requestedIDs.count == 0) {
        completion();
        return;
    }

    FIRHTTPSCallable *callable =
        [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"getProviderReviewSummaries"];
    [callable callWithObject:@{ @"providerIDs": requestedIDs }
                  completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        NSDictionary *summaries = [result.data isKindOfClass:NSDictionary.class]
            ? result.data[@"summaries"]
            : nil;
        if ([summaries isKindOfClass:NSDictionary.class]) {
            for (PPProviderStorefrontProviderRecord *record in records) {
                NSDictionary *summary = summaries[record.ownerID];
                if (![summary isKindOfClass:NSDictionary.class]) {
                    continue;
                }
                record.ratingValue = MAX(0.0, MIN(5.0, [summary[@"providerRatingValue"] doubleValue]));
                record.reviewCount = MAX(0, [summary[@"providerReviewCount"] integerValue]);
            }
        }
        dispatch_async(dispatch_get_main_queue(), completion);
    }];
}

+ (void)fetchStorefrontItemsForOwnerID:(NSString *)ownerID
                    categoryIdentifier:(NSString *)categoryIdentifier
                            seededItems:(NSArray<PetAccessory *> *)seededItems
                             completion:(void (^)(NSArray<PetAccessory *> *, NSError * _Nullable))completion
{
    void (^finish)(NSArray<PetAccessory *> *, NSError * _Nullable) =
        ^(NSArray<PetAccessory *> *fetchedItems, NSError * _Nullable error) {
        NSArray<PetAccessory *> *items = [self pp_mergedStorefrontItemsWithSeededItems:seededItems
                                                                            fetchedItems:fetchedItems
                                                                                ownerID:ownerID
                                                                    categoryIdentifier:categoryIdentifier];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(items, error);
        });
    };

    if (ownerID.length == 0) {
        finish(@[], nil);
        return;
    }

    if (PPProviderStorefrontIsPharmacyCategory(categoryIdentifier)) {
        [PetAccessoryManager fetchProviderPharmacyAccessoriesForOwnerID:ownerID
                                                       excludingAccessory:nil
                                                      completionWithError:finish];
    } else {
        [PetAccessoryManager fetchProviderMarketplaceAccessoriesForOwnerID:ownerID
                                                          excludingAccessory:nil
                                                         completionWithError:finish];
    }
}

+ (NSArray<PetAccessory *> *)pp_mergedStorefrontItemsWithSeededItems:(NSArray<PetAccessory *> *)seededItems
                                                           fetchedItems:(NSArray<PetAccessory *> *)fetchedItems
                                                               ownerID:(NSString *)ownerID
                                                   categoryIdentifier:(NSString *)categoryIdentifier
{
    NSMutableArray<PetAccessory *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];
    NSArray<PetAccessory *> *safeSeededItems = seededItems ?: @[];
    NSArray<PetAccessory *> *safeFetchedItems = fetchedItems ?: @[];
    NSArray<PetAccessory *> *candidates =
        [safeSeededItems arrayByAddingObjectsFromArray:safeFetchedItems];

    for (PetAccessory *item in candidates) {
        if (![self pp_shouldDisplayStorefrontItem:item ownerID:ownerID categoryIdentifier:categoryIdentifier]) {
            continue;
        }
        NSString *itemID = PPProviderStorefrontTrimmedString(item.accessoryID);
        if (itemID.length > 0 && [seenIDs containsObject:itemID]) {
            continue;
        }
        if (itemID.length > 0) {
            [seenIDs addObject:itemID];
        }
        [items addObject:item];
    }
    return items.copy;
}

+ (BOOL)pp_shouldDisplayStorefrontItem:(PetAccessory *)item
                               ownerID:(NSString *)ownerID
                   categoryIdentifier:(NSString *)categoryIdentifier
{
    if (![item isKindOfClass:PetAccessory.class] || item.isBlocked || item.isDeleted || item.isDisabled) {
        return NO;
    }
    if (ownerID.length > 0 && item.ownerID.length > 0 && ![item.ownerID isEqualToString:ownerID]) {
        return NO;
    }
    if (PPProviderStorefrontNormalizedCategory(categoryIdentifier).length == 0) {
        return YES;
    }
    if (PPProviderStorefrontIsPharmacyCategory(categoryIdentifier)) {
        return item.accessKindType == AccessTypePetMedicine;
    }
    return (item.accessKindType == AccessTypeAccessory || item.accessKindType == AccessTypeFood) && item.showInAppMarket;
}

+ (NSString *)sellerIdentifierForUser:(UserModel *)user
{
    return PPProviderStorefrontTrimmedString(user.ID);
}

+ (NSString *)sellerAboutForUser:(UserModel *)user
{
    return PPProviderStorefrontTrimmedString(user.UserAbout);
}

+ (BOOL)isSellerActive:(UserModel *)user
{
    return [PPProviderStorefrontSafeString(user.accountStatus) isEqualToString:@"active"];
}

+ (void)openChatWithSeller:(UserModel *)seller
         fromViewController:(UIViewController *)viewController
{
    if (![seller isKindOfClass:UserModel.class] || !viewController) {
        return;
    }
    [GM chatWith:seller FromController:viewController];
}

@end
