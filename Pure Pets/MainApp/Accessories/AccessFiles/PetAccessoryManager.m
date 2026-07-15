
//
//  PetAccessoryManager 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/05/2025.
//


// PetAccessoryManager.m

#import "PetAccessoryManager.h"
#import "PetAdManager.h"
#import "UserManager.h"
#import "UserModel.h"
#import "PPRolePermission.h"
#import "PPFirestoreErrorNotifier.h"
#import "PPFunc.h"
#import "PPImageCollection.h"

#pragma mark - Hidden-Category Filtering (Accessories) — REMOVED
// Visibility filtering has been replaced by positive accessKindType == X
// Firestore queries. The PPVisibleMainKindIDsForAccessories() and
// PPFilterAccessoriesByVisibleCategories() functions have been removed.

@interface PetAccessoryManager ()
@property (nonatomic, strong) FIRFirestore *firestore;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
+ (NSArray<PetAccessory *> *)pp_filterItems:(NSArray<PetAccessory *> *)items
                               matchingKind:(AccessKindType)kind
                requiresAppMarketVisibility:(BOOL)requiresAppMarketVisibility;
+ (NSArray<PetAccessory *> *)pp_sortItemsByCreatedAtDescending:(NSArray<PetAccessory *> *)items;
+ (void)pp_fetchPublicAccessoriesForKinds:(NSArray<NSNumber *> *)kinds
               requiresAppMarketVisibility:(BOOL)requiresAppMarketVisibility
                               completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                    NSError * _Nullable error))completion;
+ (void)pp_fetchProviderAccessoriesForOwnerID:(NSString *)ownerID
                                         kinds:(NSArray<NSNumber *> *)kinds
                             excludingAccessory:(nullable PetAccessory *)exclude
                    requiresAppMarketVisibility:(BOOL)requiresAppMarketVisibility
                                    completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                         NSError * _Nullable error))completion;
@end

@implementation PetAccessoryManager

#pragma mark - Expiry Threshold

static NSInteger _pp_cachedExpiryThresholdDays = 7;
static BOOL _pp_thresholdLoaded = NO;

static AccessKindType PPAccessKindTypeNormalize(AccessKindType kind) {
    switch (kind) {
        case AccessTypeAccessory:
        case AccessTypeFood:
        case AccessTypeLivePet:
        case AccessTypePetMedicine:
            return kind;
    }
    return AccessTypeAccessory;
}

static FIRQuery *PPAccessoryRequirePublicMarketVisibility(FIRQuery *query) {
    return [query queryWhereField:@"showInAppMarket" isEqualTo:@(YES)];
}

static BOOL PPAccessoryItemPassesUsedAccessoryFlag(PetAccessory *item, AccessKindType normalizedKind) {
    if (PPAllwedUsedAccessoriesEnabled() || normalizedKind != AccessTypeAccessory) {
        return YES;
    }
    return item.condition == AccessConditionsNew;
}

+ (void)pp_loadExpiryThresholdIfNeeded {
    if (_pp_thresholdLoaded) return;
    _pp_thresholdLoaded = YES;

    FIRFirestore *db = [FIRFirestore firestore];
    [[db documentWithPath:@"settings/system"]
     getDocumentWithCompletion:^(FIRDocumentSnapshot *snap, NSError *err) {
        if (snap.exists) {
            NSNumber *val = snap.data[@"expiryThresholdDays"];
            if ([val isKindOfClass:[NSNumber class]]) {
                _pp_cachedExpiryThresholdDays = val.integerValue;
            }
        }
        NSLog(@"🕐 Expiry threshold loaded: %ld days", (long)_pp_cachedExpiryThresholdDays);
    }];
}

+ (BOOL)pp_itemPassesVisibilityAndExpiry:(PetAccessory *)item
                               cutoffDate:(NSDate *)cutoff
                requiresAppMarketVisibility:(BOOL)requiresAppMarketVisibility {
    if (!item) {
        return NO;
    }
    if (requiresAppMarketVisibility && !item.showInAppMarket) {
        return NO;
    }
    if (item.isDeleted || item.isBlocked || item.isDisabled) {
        return NO;
    }
    if (!item.expiryDate) {
        return YES;
    }
    return [item.expiryDate compare:cutoff] == NSOrderedDescending;
}

+ (NSArray<PetAccessory *> *)pp_filterVisibleItems:(NSArray<PetAccessory *> *)items
                                      matchingKind:(AccessKindType)kind {
    return [self pp_filterItems:items
                   matchingKind:kind
    requiresAppMarketVisibility:YES];
}

+ (NSArray<PetAccessory *> *)pp_filterItems:(NSArray<PetAccessory *> *)items
                               matchingKind:(AccessKindType)kind
                requiresAppMarketVisibility:(BOOL)requiresAppMarketVisibility {
    if (!items.count) return items;

    AccessKindType normalizedKind = PPAccessKindTypeNormalize(kind);
    NSDate *cutoff = [[NSDate date] dateByAddingTimeInterval:_pp_cachedExpiryThresholdDays * 86400.0];
    NSMutableArray<PetAccessory *> *filtered = [NSMutableArray arrayWithCapacity:items.count];

    for (PetAccessory *item in items) {
        if (item.accessKindType != normalizedKind) {
            continue;
        }
        if (!PPAccessoryItemPassesUsedAccessoryFlag(item, normalizedKind)) {
            continue;
        }
        if ([self pp_itemPassesVisibilityAndExpiry:item
                                        cutoffDate:cutoff
                         requiresAppMarketVisibility:requiresAppMarketVisibility]) {
            [filtered addObject:item];
        }
    }
    return [self pp_sortItemsByCreatedAtDescending:filtered];
}

+ (NSArray<PetAccessory *> *)pp_filterExpiredItems:(NSArray<PetAccessory *> *)items {
    return [self pp_filterVisibleItems:items matchingKind:AccessTypeAccessory];
}

+ (NSArray<PetAccessory *> *)pp_sortItemsByCreatedAtDescending:(NSArray<PetAccessory *> *)items {
    return [items sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *a, PetAccessory *b) {
        NSDate *left = [a.createdAt isKindOfClass:NSDate.class] ? a.createdAt : NSDate.distantPast;
        NSDate *right = [b.createdAt isKindOfClass:NSDate.class] ? b.createdAt : NSDate.distantPast;
        return [right compare:left];
    }];
}

#pragma mark - ONE TIME PRICE MIGRATION (REMOVE AFTER RUNNING)

/// ⚠️ One-time use only.
/// Sets ALL accessories:
/// price = 15
/// discount = 5
/// finalPrice = 10

- (void)pp_oneTimeSetAllAccessoriesPriceToFixedValuesWithCompletion:(void (^)(NSError * _Nullable error,
                                                                              NSInteger updatedCount))completion
{
    NSLog(@"🧾 [ONE-TIME] Accessories pricing migration started (price=%@, discount=%@, finalPrice=%@)", @10, @3, @7);
    static BOOL didRun = NO;
    if (didRun) {
        NSLog(@"⚠️ [ONE-TIME] Migration already executed in this session - skipping");
        if (completion) completion(nil, 0);
        return;
    }
    didRun = YES;

    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];
    FIRCollectionReference *col = [db collectionWithPath:@"petAccessories"];
    FIRQuery *baseQuery = [[col queryOrderedByField:@"createdAt"] queryLimitedTo:400];
    NSLog(@"🧾 [ONE-TIME] Using collection 'petAccessories' with page size = %d", 400);

    __block NSInteger totalUpdated = 0;
    __block void (^runPage)(FIRQuery *);
    runPage = ^(FIRQuery *query) {
        NSLog(@"📄 [ONE-TIME] Fetching next page... (updated so far = %ld)", (long)totalUpdated);
        [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
            if (error || !snapshot) {
                NSLog(@"❌ [ONE-TIME] Failed to fetch page: %@", error.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(error, totalUpdated);
                });
                return;
            }
            if (snapshot.documents.count == 0) {
                NSLog(@"✅ [ONE-TIME] No more documents. Migration finished. Total updated = %ld", (long)totalUpdated);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, totalUpdated);
                });
                return;
            }
            FIRWriteBatch *batch = [db batch];
            NSDictionary *updateData = @{
                @"price": @10,
                @"discount": @3,
                @"finalPrice": @7
            };
            NSLog(@"✍️ [ONE-TIME] Updating %lu docs in this batch...", (unsigned long)snapshot.documents.count);
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                [batch updateData:updateData forDocument:[col documentWithPath:doc.documentID]];
            }
            [batch commitWithCompletion:^(NSError *commitError) {
                if (commitError) {
                    NSLog(@"❌ [ONE-TIME] Batch commit failed (updated so far = %ld): %@", (long)totalUpdated, commitError.localizedDescription);
                } else {
                    NSLog(@"✅ [ONE-TIME] Batch commit succeeded. Batch size = %lu", (unsigned long)snapshot.documents.count);
                }
                if (commitError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) completion(commitError, totalUpdated);
                    });
                    return;
                }
                totalUpdated += snapshot.documents.count;
                NSLog(@"📈 [ONE-TIME] Progress: total updated = %ld", (long)totalUpdated);
                FIRDocumentSnapshot *lastDoc = snapshot.documents.lastObject;
                FIRQuery *nextQuery = [[baseQuery queryStartingAfterDocument:lastDoc] queryLimitedTo:400];
                NSLog(@"➡️ [ONE-TIME] Moving to next page after docID=%@", lastDoc.documentID);
                runPage(nextQuery);
            }];
        }];
    };
    runPage(baseQuery);
}

static NSError *PPAccessoryCreatePermissionError(NSString *message) {
    return [NSError errorWithDomain:@"PetAccessoryManager"
                               code:-21
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"You do not have permission to add this accessory."}];
}

- (nullable NSError *)pp_validateCreatePermissionForAccessory:(PetAccessory *)accessory {
    UserManager *userManager = [UserManager sharedManager];
    UserModel *currentUser = userManager.currentUser;
    NSString *currentUID = [currentUser.ID isKindOfClass:NSString.class] ? currentUser.ID : @"";

    if (currentUID.length == 0) {
        return PPAccessoryCreatePermissionError(@"Please sign in to add a new accessory.");
    }

    if (currentUser.isBlocked || [userManager isCurrentUserBlocked]) {
        return PPAccessoryCreatePermissionError(@"Your account is blocked. You can't add new items right now.");
    }

    if (accessory.accessKindType == AccessTypeAccessory &&
        !PPAllwedUsedAccessoriesEnabled() &&
        accessory.condition == AccessConditionsUsed) {
        return PPAccessoryCreatePermissionError(kLang(@"used_accessories_disabled_message"));
    }

    NSArray<NSString *> *candidateKeys;
    NSString *deniedMessage;
    if (accessory.accessKindType == AccessTypeFood) {
        candidateKeys = @[kPermManageFood, kPermManageStore, kPermSellNew, kPermPostAds, kPermAdminAll];
        deniedMessage = @"You don't have permission to add food items.";
    } else if (accessory.accessKindType == AccessTypeLivePet) {
        candidateKeys = @[kPermManageStore, kPermSellNew, kPermPostAds, kPermAdminAll];
        deniedMessage = @"You don't have permission to add live pets.";
    } else if (accessory.condition == AccessConditionsNew) {
        candidateKeys = @[kPermSellNew, kPermManageStore, kPermPostAds, kPermAdminAll];
        deniedMessage = @"You don't have permission to add new accessories.";
    } else {
        candidateKeys = @[kPermSellUsed, kPermManageStore, kPermPostAds, kPermAdminAll];
        deniedMessage = @"You don't have permission to add used accessories.";
    }

    if ([currentUser hasAnyPermissionInKeys:candidateKeys]) {
        return nil;
    }

    return PPAccessoryCreatePermissionError(deniedMessage);
}

- (void)fetchAccessoriesForMainCategoryID:(NSInteger)mainCategoryID
                            subCategoryID:(NSInteger)subCategoryID
                                    limit:(NSInteger)limit
                               completion:(void (^)(NSArray<PetAccessory *> *accessories))completion
{
    if (mainCategoryID <= 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];

    FIRQuery *query =
    [[db collectionWithPath:@"petAccessories"]
     queryWhereField:@"petMainCategoryID"
           isEqualTo:@(mainCategoryID)];
    query = PPAccessoryRequirePublicMarketVisibility(query);

    // Optional sub-category filter
    if (subCategoryID > 0) {
        query =
        [query queryWhereField:@"petSubCategoryID"
                     isEqualTo:@(subCategoryID)];
    }

    // Stable ordering (recommended)
    query = [query queryOrderedByField:@"createdAt" descending:YES];

    // Optional limit
    if (limit > 0) {
        query = [query queryLimitedTo:limit];
    }

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchAccessoriesForMainCategoryID error: %@",
                  error.localizedDescription);
            if (error) {
                [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextAccessoryFetch];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        NSMutableArray<PetAccessory *> *results =
        [NSMutableArray arrayWithCapacity:snapshot.documents.count];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PetAccessory *item =
            [[PetAccessory alloc] initWithDictionary:doc.data
                                          documentID:doc.documentID];
            item.accessoryID = doc.documentID;
            if (item) [results addObject:item];
        }

        NSArray *visible = [PetAccessoryManager pp_filterVisibleItems:results
                                                         matchingKind:AccessTypeAccessory];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(visible);
        });
    }];
}
// MARK: - Similar Accessories Helper
- (void)fetchSimilarAccessoriesForAd:(PetAccessory *)ad
                          completion:(void (^)(NSArray<PetAccessory *> *accessories))completion
{
    if (!ad || ad.petMainCategoryID <= 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *ref = [db collectionWithPath:@"petAccessories"];

    FIRQuery *query =
    [ref queryWhereField:@"petMainCategoryID"
              isEqualTo:@(ad.petMainCategoryID)];
    if (ad.accessKindType != AccessTypePetMedicine) {
        query = PPAccessoryRequirePublicMarketVisibility(query);
    }

    // Prefer same sub category if available
    if (ad.petSubCategoryID > 0) {
        query = [query queryWhereField:@"petSubCategoryID"
                             isEqualTo:@(ad.petSubCategoryID)];
    }

    // Stable ordering
    query = [query queryOrderedByField:@"createdAt" descending:YES];
    query = [query queryLimitedTo:20];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchSimilarAccessoriesForAd error: %@", error.localizedDescription);
            if (error) {
                [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextAccessorySimilar];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        NSMutableArray<PetAccessory *> *results = [NSMutableArray array];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            if ([doc.documentID isEqualToString:ad.accessoryID]) {
                continue; // Skip same accessory
            }

            PetAccessory *item =
            [[PetAccessory alloc] initWithDictionary:doc.data
                                          documentID:doc.documentID];
            item.accessoryID = doc.documentID;

            [results addObject:item];
        }

        AccessKindType similarKind = PPAccessKindTypeNormalize(ad.accessKindType);
        NSArray *visible = [PetAccessoryManager pp_filterVisibleItems:results
                                                         matchingKind:similarKind];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(visible);
        });
    }];
}

/// Fetch accessories filtered by kind, main category, and subKind (if >0).
- (void)fetchAccessoriesOfKind:(AccessKindType)kind
                  MainCategory:(NSInteger)mainCategoryID
                     subKindID:(NSInteger)subKindID
                    completion:(void (^)(NSArray<PetAccessory *> *accessories))completion
{
    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];
    AccessKindType normalizedKind = PPAccessKindTypeNormalize(kind);

    FIRQuery *query =
        [[db collectionWithPath:@"petAccessories"]
         queryWhereField:@"accessKindType" isEqualTo:@(normalizedKind)];
    if (normalizedKind != AccessTypePetMedicine) {
        query = PPAccessoryRequirePublicMarketVisibility(query);
    }

    if (mainCategoryID > 0) {
        query =
        [query queryWhereField:@"petMainCategoryID"
                   isEqualTo:@(mainCategoryID)];
    }

    if (subKindID > 0) {
        query =
        [query queryWhereField:@"petSubCategoryID"
                   isEqualTo:@(subKindID)];
    }

    // Sort locally after fetch. Keeping this query equality-only avoids a
    // required composite Firestore index for the Pet Care medicine screen.

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot,
                                        NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchAccessoriesOfKind:MainCategory:subKindID error: %@",
                  error.localizedDescription);
            if (error) {
                [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextAccessoryKindFetch];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

            NSMutableArray<PetAccessory *> *results =
                [NSMutableArray arrayWithCapacity:snapshot.documents.count];

            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *item =
                    [[PetAccessory alloc] initWithDictionary:doc.data
                                                 documentID:doc.documentID];
                item.accessoryID = doc.documentID;
                if (item) [results addObject:item];
            }

            BOOL requiresMarketVisibility = normalizedKind != AccessTypePetMedicine;
            NSArray *visible = [PetAccessoryManager pp_filterItems:results
                                                      matchingKind:normalizedKind
                                       requiresAppMarketVisibility:requiresMarketVisibility];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(visible);
            });
        });
    }];
}



- (void)fetchAccessoriesOfKind:(AccessKindType)kind
                  MainCategory:(NSInteger)mainCatID
                    completion:(void (^)(NSArray<PetAccessory *> *items))completion
{
    NSString *PetAccessoriesCol  = @"petAccessories";
    AccessKindType normalizedKind = PPAccessKindTypeNormalize(kind);
    FIRQuery *query =
    [[self.firestore collectionWithPath:PetAccessoriesCol]
     queryWhereField:@"accessKindType" isEqualTo:@(normalizedKind)];
    if (normalizedKind != AccessTypePetMedicine) {
        query = PPAccessoryRequirePublicMarketVisibility(query);
    }

    if (mainCatID != 0) {
        query = [query queryWhereField:@"petMainCategoryID"
                             isEqualTo:@(mainCatID)];
    }

    // Sort locally after fetch to keep the Firestore query equality-only.

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot,
                                        NSError *error) {

        if (error) {
            NSLog(@"❌ fetchAccessoriesOfKind error: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextAccessoryKindFetch];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[]);
            });
            return;
        }

        NSMutableArray *results = [NSMutableArray arrayWithCapacity:snapshot.documents.count];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PetAccessory *item =
            [[PetAccessory alloc] initWithDictionary:doc.data
                                          documentID:doc.documentID];
            [results addObject:item];
        }

        BOOL requiresMarketVisibility = normalizedKind != AccessTypePetMedicine;
        NSArray *visible = [PetAccessoryManager pp_filterItems:results
                                                  matchingKind:normalizedKind
                                   requiresAppMarketVisibility:requiresMarketVisibility];
        // ✅ Always return on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(visible);
        });
    }];
}




- (void)searchAccessoriesWithText:(NSString *)query
                       completion:(void (^)(NSArray<PetAccessory *> *accessories))completion
{
    if (query.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(@[]);
        });
        return;
    }

    NSString *normalizedQuery = [ArabicNormalizer normalize:query];
    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];

    FIRQuery *fsQuery =
    [[[[db collectionWithPath:@"petAccessories"]
       queryOrderedByField:@"searchTitle"]
      queryStartingAtValues:@[normalizedQuery]]
     queryEndingAtValues:@[[normalizedQuery stringByAppendingString:@"\uf8ff"]]];

    [fsQuery getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ searchAccessoriesWithText error: %@", error.localizedDescription);
            if (error) {
                [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextAccessorySearch];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        NSMutableArray<PetAccessory *> *results = [NSMutableArray array];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            PetAccessory *item =
            [[PetAccessory alloc] initWithDictionary:doc.data
                                          documentID:doc.documentID];
            item.accessoryID = doc.documentID;

            // 🔒 Safety fallback for old docs
            NSString *normalizedName =
                [ArabicNormalizer normalize:item.name ?: @""];

            if ([normalizedName containsString:normalizedQuery]) {
                [results addObject:item];
            }
        }

        NSArray *visible = [PetAccessoryManager pp_filterExpiredItems:results];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ Accessories matched = %lu", (unsigned long)visible.count);
            if (completion) completion(visible);
        });
    }];
}



/// Fetch latest accessories that have offers (ordered by createdAt DESC)
- (void)fetchLatestAccessoriesHasOffersWithLimit:(NSInteger)limit
                                      completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                           NSError * _Nullable error))completion
{
    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];

    FIRQuery *query =
    [[db collectionWithPath:@"petAccessories"]
     queryWhereField:@"hasOffer" isEqualTo:@(YES)];
    query = PPAccessoryRequirePublicMarketVisibility(query);

    // Stable ordering
    query = [query queryOrderedByField:@"createdAt" descending:YES];

    if (limit > 0) {
        query = [query queryLimitedTo:limit];
    }

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                        NSError * _Nullable error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchLatestAccessoriesHasOffers error: %@", error.localizedDescription);
            if (error) {
                [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextAccessoryOffers];
            }
            if (completion) completion(@[], error);
            return;
        }

        NSMutableArray<PetAccessory *> *results =
        [NSMutableArray arrayWithCapacity:snapshot.documents.count];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PetAccessory *item =
            [[PetAccessory alloc] initWithDictionary:doc.data
                                          documentID:doc.documentID];
            item.accessoryID = doc.documentID;
            [results addObject:item];
        }

        NSArray *visible = [PetAccessoryManager pp_filterExpiredItems:results];
        // Always return on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(visible, nil);
        });
    }];
}

#pragma mark - Latest Accessories Fetching
/// Fetch the latest accessories (ordered by createdAt descending), limited to given count.
- (void)fetchLatestAccessoriesWithLimit:(NSInteger)limit
                             completion:(void (^)(NSArray<PetAccessory *> *accessories, NSError * _Nullable error))completion {

    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];

    FIRQuery *query = PPAccessoryRequirePublicMarketVisibility([db collectionWithPath:@"petAccessories"]);
    query = [query queryOrderedByField:@"createdAt" descending:YES];

    if (limit > 0) {
        query = [query queryLimitedTo:limit];
    }

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                        NSError * _Nullable error) {

        if (error || !snapshot) {
            if (completion) completion(@[], error);
            return;
        }

        NSMutableArray<PetAccessory *> *results = [NSMutableArray array];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PetAccessory *item =
                [[PetAccessory alloc] initWithDictionary:doc.data
                                             documentID:doc.documentID];
            item.accessoryID = doc.documentID;
            [results addObject:item];
        }

        NSArray *visible = [PetAccessoryManager pp_filterExpiredItems:results];
        if (completion) {
            completion(visible, nil);
        }
    }];
}

+ (instancetype)sharedManager {
    static PetAccessoryManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PetAccessoryManager alloc] init];
        sharedInstance.firestore = [FIRFirestore firestore];
        sharedInstance.accessoriesArray = [NSMutableArray array];
        [PetAccessoryManager pp_loadExpiryThresholdIfNeeded];
    });
    return sharedInstance;
}



#pragma mark - Create Accessory with Images

- (void)createAccessory:(PetAccessory *)accessory
      uploadedImageURLs:(NSArray<NSString *> *)imageURLs
          imageMetadata:(NSArray<NSDictionary *> *)imageMetadata
              videoURLs:(NSArray<NSString *> *)videoURLs
          videoMetadata:(NSArray<NSDictionary *> *)videoMetadata
          mixedMetadata:(NSArray<NSDictionary *> *)mixedMetadata
             completion:(void (^)(NSError * _Nullable error))completion
{
    if (!accessory) {
        if (completion) {
            completion([NSError errorWithDomain:@"PetAccessoryManager"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Accessory object cannot be nil"}]);
        }
        return;
    }

    NSError *permissionError = [self pp_validateCreatePermissionForAccessory:accessory];
    if (permissionError) {
        if (completion) completion(permissionError);
        return;
    }

    if (!accessory.accessoryID || accessory.accessoryID.length == 0) {
        accessory.accessoryID = [[NSUUID UUID] UUIDString];
    }
    if (!accessory.createdAt) {
        accessory.createdAt = [NSDate date];
    }
    if (!accessory.ownerID || accessory.ownerID.length == 0) {
        accessory.ownerID = UserManager.sharedManager.currentUser.ID ?: @"unknown";
    }

    NSArray<NSDictionary *> *safeMixedMetadata = [mixedMetadata isKindOfClass:NSArray.class] ? mixedMetadata : @[];
    NSArray<NSString *> *safeImageURLs = [imageURLs isKindOfClass:NSArray.class] ? imageURLs : @[];
    NSArray<NSString *> *safeVideoURLs = [videoURLs isKindOfClass:NSArray.class] ? videoURLs : @[];
    if (safeMixedMetadata.count == 0 && safeImageURLs.count == 0 && safeVideoURLs.count == 0) {
        if (completion) {
            completion([NSError errorWithDomain:@"PetAccessoryManager"
                                           code:-9
                                       userInfo:@{NSLocalizedDescriptionKey: @"Media upload result is empty"}]);
        }
        return;
    }

    accessory.imageURLsArray = [safeImageURLs copy];
    accessory.imageMeta = safeMixedMetadata.count > 0 ? [safeMixedMetadata copy] : [imageMetadata copy];

    [self saveAccessoryToDatabase:accessory completion:completion];
}

- (void)createAccessory:(PetAccessory *)accessory
                 images:(NSArray<UIImage *> *)images
             completion:(void (^)(NSError * _Nullable error))completion {

    // Validate inputs
    if (!accessory) {
        if (completion) {
            completion([NSError errorWithDomain:@"PetAccessoryManager"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Accessory object cannot be nil"}]);
        }
        return;
    }

    NSError *permissionError = [self pp_validateCreatePermissionForAccessory:accessory];
    if (permissionError) {
        if (completion) {
            completion(permissionError);
        }
        return;
    }

    // Generate accessory ID if not provided
    if (!accessory.accessoryID || accessory.accessoryID.length == 0) {
        accessory.accessoryID = [[NSUUID UUID] UUIDString];
    }

    // Set creation timestamp only when creating new models.
    // Editing flows can reuse this method and must keep their original createdAt.
    if (!accessory.createdAt) {
        accessory.createdAt = [NSDate date];
    }

    if (!accessory.ownerID || accessory.ownerID.length == 0) {
        accessory.ownerID = UserManager.sharedManager.currentUser.ID ?: @"unknown";
    }

    // Validate images
    if (images.count == 0) {
        // Create accessory without images
        [self saveAccessoryToDatabase:accessory completion:completion];
        return;
    }

    // Validate maximum image count
    NSUInteger maxImages = 10; // Adjust as needed
    if (images.count > maxImages) {
        if (completion) {
            completion([NSError errorWithDomain:@"PetAccessoryManager"
                                           code:-2
                                       userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Maximum %ld images allowed", (long)maxImages],
                @"maxImages": @(maxImages)
            }]);
        }
        return;
    }

    NSLog(@"🆕 Creating accessory '%@' with %ld images", accessory.name, (long)images.count);

    // 🗑️ Capture old image URLs before overwriting (edit reuse path)
    NSArray<NSString *> *previousImageURLs = [accessory.imageURLsArray copy] ?: @[];

    // Upload images in parallel
    dispatch_group_t uploadGroup = dispatch_group_create();
    NSMutableArray<NSString *> *downloadURLs = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *imageMetadata = [NSMutableArray array];
    NSMutableArray<NSError *> *uploadErrors = [NSMutableArray array];
    NSLock *arrayLock = [[NSLock alloc] init];

    for (NSInteger i = 0; i < images.count; i++) {
        UIImage *image = images[i];

        // Strict mode: invalid images are treated as real upload failures.
        if (![image isKindOfClass:[UIImage class]] || image.size.width == 0 || image.size.height == 0) {
            NSLog(@"❌ Invalid image at index %ld", (long)i);
            [arrayLock lock];
            [uploadErrors addObject:[NSError errorWithDomain:@"PetAccessoryManager"
                                                        code:-8
                                                    userInfo:@{
                NSLocalizedDescriptionKey: @"Invalid image payload",
                @"index": @(i)
            }]];
            [arrayLock unlock];
            continue;
        }

        dispatch_group_enter(uploadGroup);

        // Upload on background queue with autorelease pool
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                // Optimize image for upload
                UIImage *optimizedImage = [self optimizeImageForUpload:image];

                // Encode as PNG (lossless)
                NSData *imageData = UIImagePNGRepresentation(optimizedImage);

                if (!imageData || imageData.length == 0) {
                    NSLog(@"❌ Failed to compress image at index %ld", (long)i);

                    [arrayLock lock];
                    [uploadErrors addObject:
                     [NSError errorWithDomain:@"PetAccessoryManager"
                                         code:-3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to compress image",
                                                @"index": @(i),
                                                @"imageSize": NSStringFromCGSize(image.size)}]];
                    [arrayLock unlock];

                    dispatch_group_leave(uploadGroup);
                    return;
                }

                // Check file size (optional limit)
                NSUInteger maxFileSize = 10 * 1024 * 1024; // 10MB for PNG
                if (imageData.length > maxFileSize) {
                    NSLog(@"❌ Image at index %ld is too large (%lu bytes)", (long)i, (unsigned long)imageData.length);

                    [arrayLock lock];
                    [uploadErrors addObject:
                     [NSError errorWithDomain:@"PetAccessoryManager"
                                         code:-4
                                     userInfo:@{NSLocalizedDescriptionKey: @"Image file too large",
                                                @"index": @(i),
                                                @"maxSize": @(maxFileSize)}]];
                    [arrayLock unlock];

                    dispatch_group_leave(uploadGroup);
                    return;
                }

                // Create filename with accessory ID and index
                NSString *fileName = [NSString stringWithFormat:@"%@_%ld_%@.png",
                                      accessory.accessoryID,
                                      (long)i,
                                      @((NSInteger)[[NSDate date] timeIntervalSince1970])];

                // Upload to Firebase Storage
                NSString *storagePath = [NSString stringWithFormat:@"used-accessories/%@/images/%@",accessory.accessoryID, fileName];
                FIRStorageReference *storageRef = [[FIRStorage storage].reference child:storagePath];

                // Prepare metadata
                FIRStorageMetadata *firebaseMetadata = [[FIRStorageMetadata alloc] init];
                firebaseMetadata.contentType = @"image/png";
                firebaseMetadata.customMetadata = @{
                    @"uploaded_by": accessory.ownerID,
                    @"accessory_id": accessory.accessoryID,
                    @"accessory_name": accessory.name ?: @"unnamed",
                    @"upload_timestamp": @((NSInteger)[[NSDate date] timeIntervalSince1970]).stringValue,
                    @"image_width": @(image.size.width).stringValue,
                    @"image_height": @(image.size.height).stringValue,
                    @"file_size": @(imageData.length).stringValue,
                    @"is_primary": (i == 0) ? @"true" : @"false"
                };

                // Upload with progress tracking (optional)
                FIRStorageUploadTask *uploadTask = [storageRef putData:imageData
                                                              metadata:firebaseMetadata];

                // Optional: Monitor upload progress
                [uploadTask observeStatus:FIRStorageTaskStatusProgress
                                 handler:^(FIRStorageTaskSnapshot *snapshot) {
                    // Progress tracking if needed
                    // double percentComplete = 100.0 * (snapshot.progress.completedUnitCount /
                    //                                   (double)snapshot.progress.totalUnitCount);
                }];

                [uploadTask observeStatus:FIRStorageTaskStatusSuccess
                                 handler:^(FIRStorageTaskSnapshot *snapshot) {

                    // Get download URL
                    [storageRef downloadURLWithCompletion:^(NSURL * _Nullable downloadURL,
                                                           NSError * _Nullable urlError) {
                        if (urlError) {
                            NSLog(@"❌ Failed to get download URL for image %ld: %@",
                                  (long)i, urlError.localizedDescription);

                            [arrayLock lock];
                            [uploadErrors addObject:urlError];
                            [arrayLock unlock];
                        } else if (downloadURL) {
                            // Create image metadata for our model
                            NSDictionary *imgMeta = @{
                                @"url": downloadURL.absoluteString,
                                @"width": @(image.size.width),
                                @"height": @(image.size.height),
                                @"file_size": @(imageData.length),
                                @"is_primary": @(i == 0),
                                @"order": @(i),
                                @"storage_path": storagePath,
                                @"uploaded_at": firebaseMetadata.customMetadata[@"upload_timestamp"]
                            };

                            [arrayLock lock];
                            [downloadURLs addObject:downloadURL.absoluteString];
                            [imageMetadata addObject:imgMeta];
                            [arrayLock unlock];

                            NSLog(@"✅ Uploaded image %ld for accessory '%@'",
                                  (long)i, accessory.name);
                        }

                        dispatch_group_leave(uploadGroup);
                    }];
                }];

                [uploadTask observeStatus:FIRStorageTaskStatusFailure
                                 handler:^(FIRStorageTaskSnapshot *snapshot) {
                    NSError *error = snapshot.error;
                    NSLog(@"❌ Upload failed for image %ld: %@", (long)i, error.localizedDescription);

                    [arrayLock lock];
                    [uploadErrors addObject:error];
                    [arrayLock unlock];

                    dispatch_group_leave(uploadGroup);
                }];
            }
        });
    }

    // Handle completion when all uploads finish
    dispatch_group_notify(uploadGroup, dispatch_get_main_queue(), ^{
        [self handleCreateCompletionForAccessory:accessory
                                   downloadURLs:downloadURLs
                                  imageMetadata:imageMetadata
                                   uploadErrors:uploadErrors
                                totalImageCount:images.count
                              previousImageURLs:previousImageURLs
                                     completion:completion];
    });
}

#pragma mark - Helper Methods

- (UIImage *)optimizeImageForUpload:(UIImage *)image {
    // Resize if image is too large
    CGFloat maxDimension = 2048.0; // Maximum dimension
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;

    if (width <= maxDimension && height <= maxDimension) {
        return image; // No resizing needed
    }

    // Calculate new size maintaining aspect ratio
    CGFloat ratio = width / height;
    CGSize newSize;

    if (width > height) {
        newSize = CGSizeMake(maxDimension, maxDimension / ratio);
    } else {
        newSize = CGSizeMake(maxDimension * ratio, maxDimension);
    }

    // Create graphics context
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resizedImage ?: image;
}

- (void)handleCreateCompletionForAccessory:(PetAccessory *)accessory
                             downloadURLs:(NSArray<NSString *> *)downloadURLs
                            imageMetadata:(NSArray<NSDictionary *> *)imageMetadata
                             uploadErrors:(NSArray<NSError *> *)uploadErrors
                          totalImageCount:(NSInteger)totalImageCount
                        previousImageURLs:(NSArray<NSString *> *)previousImageURLs
                               completion:(void (^)(NSError * _Nullable error))completion {

    // Calculate final price if needed
    if (accessory.price) {
        // This will trigger the calculation of finalPrice
        [accessory calculateFinalPrice];
    }

    // Log summary
    NSLog(@"📊 Creation Summary:");
    NSLog(@"  - Accessory: %@ (ID: %@)", accessory.name, accessory.accessoryID);
    NSLog(@"  - Type: %@", [PetAccessory typeTextForAccessory:accessory]);
    NSLog(@"  - Condition: %@", accessory.condition == AccessConditionsNew ? @"New" : @"Used");
    NSLog(@"  - Price: %@ (Final: %@)", accessory.price, accessory.finalPrice);
    NSLog(@"  - Images attempted: %ld", (long)totalImageCount);
    NSLog(@"  - Images uploaded: %ld", (long)downloadURLs.count);
    NSLog(@"  - Upload errors: %ld", (long)uploadErrors.count);

    // Strict production mode: all images must upload successfully before Firestore write.
    BOOL hasAnyUploadIssue = (uploadErrors.count > 0 ||
                              downloadURLs.count != totalImageCount ||
                              imageMetadata.count != totalImageCount);
    if (hasAnyUploadIssue) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PetAccessoryManager"
                                                 code:-5
                                             userInfo:@{
                NSLocalizedDescriptionKey: @"Image upload incomplete. Accessory was not saved.",
                @"underlyingErrors": uploadErrors,
                @"accessoryID": accessory.accessoryID ?: @"unknown",
                @"imagesAttempted": @(totalImageCount),
                @"imagesUploaded": @(downloadURLs.count)
            }];
            completion(error);
        }
        return;
    }

    // Update accessory with image data only after all uploads complete successfully.
    accessory.imageURLsArray = [downloadURLs copy];
    accessory.imageMeta = [imageMetadata copy];

    // Save accessory to Firestore
    [self saveAccessoryToDatabase:accessory completion:^(NSError * _Nullable dbError) {
        if (dbError) {
            NSLog(@"❌ Failed to save accessory to database: %@", dbError.localizedDescription);

            if (completion) {
                completion(dbError);
            }
        } else {
            NSLog(@"✅ Successfully created accessory '%@' with %ld images",
                  accessory.name, (long)downloadURLs.count);

            // 🗑️ Clean up old images from Storage (for edit reuse path)
            [PPFunc pp_deleteRemovedStorageImagesFromOldURLs:previousImageURLs
                                                    newURLs:accessory.imageURLsArray];

            if (completion) {
                completion(nil);
            }
        }
    }];
}

- (void)saveAccessoryToDatabase:(PetAccessory *)accessory
                     completion:(void (^)(NSError * _Nullable error))completion {

    // Get Firestore collection reference
    FIRCollectionReference *collectionRef = [self accessoriesCollection];

    // Convert to Firestore dictionary
    NSDictionary *accessoryData = [accessory toFirestoreDictionary];

    if (!accessoryData) {
        if (completion) {
            completion([NSError errorWithDomain:@"PetAccessoryManager"
                                           code:-7
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert accessory to dictionary"}]);
        }
        return;
    }

    NSLog(@"💾 Saving accessory '%@' to Firestore...", accessory.name);

    // Set document ID if provided, otherwise let Firestore auto-generate
    FIRDocumentReference *docRef;
    if (accessory.accessoryID && accessory.accessoryID.length > 0) {
        docRef = [collectionRef documentWithPath:accessory.accessoryID];
    } else {
        docRef = [collectionRef documentWithAutoID];
        accessory.accessoryID = docRef.documentID;
    }

    // Save to Firestore
    [docRef setData:accessoryData
         completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Firestore save failed: %@", error.localizedDescription);
        } else {
           // NSLog(@"✅ Accessory saved to Firestore with ID: %@", docRef.documentID);

            // Also update local cache if you have one
            [self updateLocalCacheWithAccessory:accessory];
        }

        if (completion) completion(error);
    }];
}

- (void)updateLocalCacheWithAccessory:(PetAccessory *)accessory {
    // Implement if you have a local cache
    // For example:
    // [[LocalCacheManager shared] addAccessory:accessory];
}

#pragma mark - Firestore Collection Helper

- (FIRCollectionReference *)accessoriesCollection {
    FIRFirestore *db = [FIRFirestore firestore];
    return [db collectionWithPath:@"petAccessories"];
}

- (void)startListeningWithKind:(AccessKindType)kindType
                  mainCategory:(NSInteger)mainCategoryID
                       onArray:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock {
    if (self.listener) {
        [self.listener remove];
    }

    AccessKindType normalizedKind = PPAccessKindTypeNormalize(kindType);
    FIRQuery *query = [[self.firestore collectionWithPath:@"petAccessories"]
                       queryWhereField:@"accessKindType" isEqualTo:@(normalizedKind)];
    if (normalizedKind != AccessTypePetMedicine) {
        query = PPAccessoryRequirePublicMarketVisibility(query);
    }

    if (mainCategoryID != 0) {
        query = [query queryWhereField:@"petMainCategoryID" isEqualTo:@(mainCategoryID)];
    }

    // U4: Prevent retain cycle in accessory kind listener
    __weak typeof(self) weakSelf = self;
    self.listener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot,
                                                 NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            NSLog(@"❌ Error listening for kind %ld + mainCategory %ld: %@",
                  (long)normalizedKind, (long)mainCategoryID, error.localizedDescription);
            return;
        }

        [strongSelf.accessoriesArray removeAllObjects];
        NSMutableArray<PetAccessory *> *snapshotItems = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PetAccessory *accessory =
                [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
            accessory.accessoryID = doc.documentID;
            if (accessory) [snapshotItems addObject:accessory];

            NSLog(@"listening for kind  %@",accessory.name);
        }

        BOOL requiresMarketVisibility = normalizedKind != AccessTypePetMedicine;
        NSArray<PetAccessory *> *visibleItems =
            [PetAccessoryManager pp_filterItems:snapshotItems
                                  matchingKind:normalizedKind
                   requiresAppMarketVisibility:requiresMarketVisibility];
        [strongSelf.accessoriesArray addObjectsFromArray:visibleItems];

        if (updateBlock) {
            updateBlock(strongSelf.accessoriesArray);
        }
    }];
}


- (void)startListeningWithUpdateForMianId:(NSInteger)mainCategoryID onArray:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock{
    if (self.listener) {
        [self.listener remove];
    }

    if(mainCategoryID == 0)
    {
        // U4: Prevent retain cycle in accessory listener (all categories)
        __weak typeof(self) weakSelf = self;
        self.listener = [[self.firestore collectionWithPath:@"petAccessories"]
                         addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                NSLog(@"Error listening for accessory changes: %@", error.localizedDescription);
                return;
            }

            [strongSelf.accessoriesArray removeAllObjects];
            NSMutableArray<PetAccessory *> *snapshotItems = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *accessory = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                accessory.accessoryID = doc.documentID;
                if (accessory) [snapshotItems addObject:accessory];
            }

            NSArray<PetAccessory *> *visibleAccessories =
                [PetAccessoryManager pp_filterVisibleItems:snapshotItems matchingKind:AccessTypeAccessory];
            [strongSelf.accessoriesArray addObjectsFromArray:visibleAccessories];

            if (updateBlock) {
                updateBlock(strongSelf.accessoriesArray);
            }
        }];
    }
    else
    {
        // U4: Prevent retain cycle in accessory listener (filtered category)
        __weak typeof(self) weakSelf2 = self;
        self.listener = [[[self.firestore collectionWithPath:@"petAccessories"] queryWhereField:@"petMainCategoryID" isEqualTo:@(mainCategoryID)]
                         addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            __strong typeof(weakSelf2) strongSelf = weakSelf2;
            if (!strongSelf) return;
            if (error) {
                NSLog(@"Error listening for accessory changes: %@", error.localizedDescription);
                return;
            }

            [strongSelf.accessoriesArray removeAllObjects];
            NSMutableArray<PetAccessory *> *snapshotItems = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *accessory = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                accessory.accessoryID = doc.documentID;
                if (accessory) [snapshotItems addObject:accessory];
            }

            NSArray<PetAccessory *> *visibleAccessories =
                [PetAccessoryManager pp_filterVisibleItems:snapshotItems matchingKind:AccessTypeAccessory];
            [strongSelf.accessoriesArray addObjectsFromArray:visibleAccessories];

            if (updateBlock) {
                updateBlock(strongSelf.accessoriesArray);
            }
        }];

    }

}

    - (void)loadAllAccessories:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock{
        if (self.listener) {
            [self.listener remove];
        }

        [[self.firestore collectionWithPath:@"petAccessories"] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {

            if (error) {
                NSLog(@"Error listening for accessory changes: %@", error.localizedDescription);
                return;
            }

            [self.accessoriesArray removeAllObjects];
            NSMutableArray<PetAccessory *> *snapshotItems = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *accessory = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                accessory.accessoryID = doc.documentID;
                if (accessory) [snapshotItems addObject:accessory];
            }

            NSArray<PetAccessory *> *visibleAccessories =
                [PetAccessoryManager pp_filterVisibleItems:snapshotItems matchingKind:AccessTypeAccessory];
            [self.accessoriesArray addObjectsFromArray:visibleAccessories];

            if (updateBlock) {
                updateBlock(self.accessoriesArray);
            }
        }];
    }

    - (void)addAccessory:(PetAccessory *)accessory completion:(void (^)(NSError * _Nullable error))completion {
        NSDictionary *data = [accessory toFirestoreDictionary];
        [[self.firestore collectionWithPath:@"petAccessories"] addDocumentWithData:data completion:completion];
    }

    - (void)uploadAccessory:(PetAccessory *)accessory
    imageObjects:(NSArray<UIImage *> *)images
    completion:(void (^)(NSError * _Nullable error))completion {

        // Early exit if no images
        if (images.count == 0) {
            [self addAccessory:accessory completion:completion];
            return;
        }

        // Validate inputs
        if (!accessory) {
            if (completion) {
                completion([NSError errorWithDomain:@"PetAccessoryManager"
                                               code:-1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Accessory object is nil"}]);
            }
            return;
        }

        // Generate a unique accessory ID if needed
        if (!accessory.accessoryID || accessory.accessoryID.length == 0) {
            accessory.accessoryID = [[NSUUID UUID] UUIDString];
        }

        // Create dispatch group for parallel uploads
        dispatch_group_t uploadGroup = dispatch_group_create();
        NSMutableArray<NSString *> *downloadURLs = [NSMutableArray array];
        NSMutableArray<NSError *> *uploadErrors = [NSMutableArray array];
        NSLock *arrayLock = [[NSLock alloc] init];

        for (NSInteger i = 0; i < images.count; i++) {
            UIImage *image = images[i];

            // Skip invalid images
            if (![image isKindOfClass:[UIImage class]] || image.size.width == 0 || image.size.height == 0) {
                NSLog(@"❌ Invalid image at index %ld", (long)i);
                continue;
            }

            dispatch_group_enter(uploadGroup);

            // Perform upload on background queue
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    // Encode as PNG
                    NSData *imageData = UIImagePNGRepresentation(image);

                    if (!imageData || imageData.length == 0) {
                        NSLog(@"❌ Failed to compress image at index %ld", (long)i);

                        [arrayLock lock];
                        [uploadErrors addObject:
                         [NSError errorWithDomain:@"PetAccessoryManager"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to compress image",
                                                    @"index": @(i)}]];
                        [arrayLock unlock];

                        dispatch_group_leave(uploadGroup);
                        return;
                    }

                    // Create filename
                    NSString *fileName = [NSString stringWithFormat:@"%@_%ld_%@.png",
                                          accessory.accessoryID,
                                          (long)i,
                                          @((NSInteger)[[NSDate date] timeIntervalSince1970])];

                    // Upload to Firebase
                    NSString *storagePath = [NSString stringWithFormat:@"petAccessories/%@", fileName];
                    FIRStorageReference *storageRef = [[FIRStorage storage].reference child:storagePath];

                    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
                    metadata.contentType = @"image/png";
                    metadata.customMetadata = @{
                        @"uploaded_by": UserManager.sharedManager.currentUser.ID ?: @"unknown",
                        @"accessory_id": accessory.accessoryID,
                        @"upload_timestamp": @((NSInteger)[[NSDate date] timeIntervalSince1970]).stringValue,
                        @"image_width": @(image.size.width).stringValue,
                        @"image_height": @(image.size.height).stringValue,
                        @"file_size": @(imageData.length).stringValue
                    };

                    [storageRef putData:imageData
                               metadata:metadata
                             completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {

                        if (error) {
                            NSLog(@"❌ Upload failed for image %ld: %@", (long)i, error.localizedDescription);

                            [arrayLock lock];
                            [uploadErrors addObject:error];
                            [arrayLock unlock];

                            dispatch_group_leave(uploadGroup);
                            return;
                        }

                        // Get download URL
                        [storageRef downloadURLWithCompletion:^(NSURL * _Nullable downloadURL, NSError * _Nullable urlError) {
                            if (urlError) {
                                NSLog(@"❌ Failed to get download URL for image %ld: %@",
                                      (long)i, urlError.localizedDescription);

                                [arrayLock lock];
                                [uploadErrors addObject:urlError];
                                [arrayLock unlock];
                            } else if (downloadURL) {
                                NSLog(@"✅ Uploaded image %ld: %@", (long)i, downloadURL.absoluteString);

                                [arrayLock lock];
                                [downloadURLs addObject:downloadURL.absoluteString];
                                [arrayLock unlock];
                            }

                            dispatch_group_leave(uploadGroup);
                        }];
                    }];
                }
            });
        }

        // Handle completion
        dispatch_group_notify(uploadGroup, dispatch_get_main_queue(), ^{
            [self handleUploadCompletionForAccessory:accessory
                                        downloadURLs:downloadURLs
                                        uploadErrors:uploadErrors
                                     totalImageCount:images.count
                                          completion:completion];
        });
    }

    // Helper method for handling completion logic
    - (void)handleUploadCompletionForAccessory:(PetAccessory *)accessory
    downloadURLs:(NSArray<NSString *> *)downloadURLs
    uploadErrors:(NSArray<NSError *> *)uploadErrors
    totalImageCount:(NSInteger)totalCount
    completion:(void (^)(NSError * _Nullable error))completion {

        // Update accessory with URLs
        accessory.imageURLsArray = [downloadURLs copy];

        // Log summary
        NSLog(@"📊 Upload Summary:");
        NSLog(@"  - Total images: %ld", (long)totalCount);
        NSLog(@"  - Successfully uploaded: %ld", (long)downloadURLs.count);
        NSLog(@"  - Failed: %ld", (long)uploadErrors.count);

        // Save to database
        [self addAccessory:accessory completion:^(NSError * _Nullable dbError) {
            if (dbError) {
                NSLog(@"❌ Database save failed: %@", dbError.localizedDescription);

                if (completion) {
                    if (uploadErrors.count > 0) {
                        // Combine errors
                        NSMutableArray *allErrors = [uploadErrors mutableCopy];
                        [allErrors addObject:dbError];

                        completion([NSError errorWithDomain:@"PetAccessoryManager"
                                                       code:-3
                                                   userInfo:@{
                            NSLocalizedDescriptionKey: @"Failed to upload images AND save accessory",
                            @"underlyingErrors": allErrors
                        }]);
                    } else {
                        completion(dbError);
                    }
                }
            } else {
                NSLog(@"✅ Accessory saved successfully");

                if (completion) {
                    if (uploadErrors.count > 0) {
                        // Partial success
                        completion([NSError errorWithDomain:@"PetAccessoryManager"
                                                       code:1 // Warning
                                                   userInfo:@{
                            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Saved with %ld/%ld images",
                                                        (long)downloadURLs.count,
                                                        (long)totalCount],
                            @"successfulUploads": @(downloadURLs.count),
                            @"failedUploads": @(uploadErrors.count)
                        }]);
                    } else {
                        completion(nil);
                    }
                }
            }
        }];
    }





    - (void)updateAccessory:(PetAccessory *)accessory
    images:(NSArray<UIImage *> *)images
    completion:(void (^)(NSError * _Nullable error))completion {

        // Validate accessory
        if (!accessory || !accessory.accessoryID) {
            if (completion) {
                completion([NSError errorWithDomain:@"PetAccessoryManager"
                                               code:-1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Invalid accessory or missing ID"}]);
            }
            return;
        }

        // 🗑️ Fetch original image URLs from Firestore BEFORE uploading
        [self pp_fetchImageURLsForAccessoryID:accessory.accessoryID completion:^(NSArray<NSString *> *originalURLsFromDB) {

        // Early exit: if no new images, just update the accessory
        if (images.count == 0) {
            [self updateAccessoryInDatabase:accessory completion:^(NSError * _Nullable error) {
                if (!error) {
                    [PPFunc pp_deleteRemovedStorageImagesFromOldURLs:originalURLsFromDB
                                                            newURLs:accessory.imageURLsArray];
                }
                if (completion) completion(error);
            }];
            return;
        }

        // Get existing image URLs from the accessory
        NSArray<NSString *> *existingImageURLs = accessory.imageURLsArray ?: @[];
        NSLog(@"🔄 Updating accessory %@ with %ld new images (keeping %ld existing)",
              accessory.accessoryID, (long)images.count, (long)existingImageURLs.count);

        // Strategy: Keep existing URLs, upload new images, combine results
        dispatch_group_t uploadGroup = dispatch_group_create();
        NSMutableArray<NSString *> *newDownloadURLs = [NSMutableArray array];
        NSMutableArray<NSError *> *uploadErrors = [NSMutableArray array];
        NSLock *arrayLock = [[NSLock alloc] init];

        // Upload new images
        for (NSInteger i = 0; i < images.count; i++) {
            UIImage *image = images[i];

            // Validate image
            if (![image isKindOfClass:[UIImage class]] || image.size.width == 0 || image.size.height == 0) {
                NSLog(@"⚠️ Skipping invalid image at index %ld", (long)i);
                continue;
            }

            dispatch_group_enter(uploadGroup);

            // Upload on background queue
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    // Encode as PNG
                    NSData *imageData = UIImagePNGRepresentation(image);
                    if (!imageData || imageData.length == 0) {
                        NSLog(@"❌ Failed to compress new image at index %ld", (long)i);

                        [arrayLock lock];
                        [uploadErrors addObject:
                         [NSError errorWithDomain:@"PetAccessoryManager"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to compress new image",
                                                    @"index": @(i)}]];
                        [arrayLock unlock];

                        dispatch_group_leave(uploadGroup);
                        return;
                    }

                    // Create filename with timestamp to avoid collisions
                    NSString *fileName = [NSString stringWithFormat:@"%@_new_%ld_%@.png",
                                          accessory.accessoryID,
                                          (long)i,
                                          @((NSInteger)[[NSDate date] timeIntervalSince1970])];

                    // Upload to Firebase
                    NSString *storagePath = [NSString stringWithFormat:@"petAccessories/%@", fileName];
                    FIRStorageReference *storageRef = [[FIRStorage storage].reference child:storagePath];

                    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
                    metadata.contentType = @"image/png";
                    metadata.customMetadata = @{
                        @"uploaded_by": UserManager.sharedManager.currentUser.ID ?: @"unknown",
                        @"accessory_id": accessory.accessoryID,
                        @"upload_timestamp": @((NSInteger)[[NSDate date] timeIntervalSince1970]).stringValue,
                        @"image_width": @(image.size.width).stringValue,
                        @"image_height": @(image.size.height).stringValue,
                        @"file_size": @(imageData.length).stringValue,
                        @"is_update": @"true"
                    };

                    [storageRef putData:imageData
                               metadata:metadata
                             completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {

                        if (error) {
                            NSLog(@"❌ Upload failed for new image %ld: %@", (long)i, error.localizedDescription);

                            [arrayLock lock];
                            [uploadErrors addObject:error];
                            [arrayLock unlock];

                            dispatch_group_leave(uploadGroup);
                            return;
                        }

                        // Get download URL
                        [storageRef downloadURLWithCompletion:^(NSURL * _Nullable downloadURL, NSError * _Nullable urlError) {
                            if (urlError) {
                                NSLog(@"❌ Failed to get download URL for new image %ld: %@",
                                      (long)i, urlError.localizedDescription);

                                [arrayLock lock];
                                [uploadErrors addObject:urlError];
                                [arrayLock unlock];
                            } else if (downloadURL) {
                                NSLog(@"✅ Uploaded new image %ld: %@", (long)i, downloadURL.absoluteString);

                                [arrayLock lock];
                                [newDownloadURLs addObject:downloadURL.absoluteString];
                                [arrayLock unlock];
                            }

                            dispatch_group_leave(uploadGroup);
                        }];
                    }];
                }
            });
        }

        // Handle completion
        dispatch_group_notify(uploadGroup, dispatch_get_main_queue(), ^{
            [self handleUpdateCompletionForAccessory:accessory
                                        existingURLs:existingImageURLs
                                     newDownloadURLs:newDownloadURLs
                                        uploadErrors:uploadErrors
                                      totalNewImages:images.count
                                          completion:^(NSError * _Nullable error) {
                // 🗑️ Clean up orphaned images after successful DB save
                if (!error || error.code == 1 /* warning-only */) {
                    [PPFunc pp_deleteRemovedStorageImagesFromOldURLs:originalURLsFromDB
                                                            newURLs:accessory.imageURLsArray];
                }
                if (completion) completion(error);
            }];
        });
        }]; // end pp_fetchImageURLsForAccessoryID block
    }

#pragma mark - Helper Methods for Update

    - (void)handleUpdateCompletionForAccessory:(PetAccessory *)accessory
    existingURLs:(NSArray<NSString *> *)existingURLs
    newDownloadURLs:(NSArray<NSString *> *)newDownloadURLs
    uploadErrors:(NSArray<NSError *> *)uploadErrors
    totalNewImages:(NSInteger)totalNewImages
    completion:(void (^)(NSError * _Nullable error))completion {

        // Combine existing URLs with new URLs
        NSMutableArray<NSString *> *allImageURLs = [NSMutableArray array];

        // Keep existing URLs
        [allImageURLs addObjectsFromArray:existingURLs];

        // Add new URLs
        [allImageURLs addObjectsFromArray:newDownloadURLs];

        // Update accessory with combined URLs
        accessory.imageURLsArray = [allImageURLs copy];

        // Log summary
        NSLog(@"📊 Update Summary for accessory %@:", accessory.accessoryID);
        NSLog(@"  - Existing images kept: %ld", (long)existingURLs.count);
        NSLog(@"  - New images attempted: %ld", (long)totalNewImages);
        NSLog(@"  - New images uploaded: %ld", (long)newDownloadURLs.count);
        NSLog(@"  - Failed uploads: %ld", (long)uploadErrors.count);
        NSLog(@"  - Total images after update: %ld", (long)allImageURLs.count);

        // Check if we should proceed despite errors
        BOOL shouldProceed = YES;
        NSString *warningMessage = nil;

        if (uploadErrors.count > 0) {
            if (newDownloadURLs.count == 0) {
                // All new images failed
                warningMessage = @"No new images were uploaded";
                if (existingURLs.count == 0) {
                    // No existing images either, this might be an error
                    shouldProceed = NO;
                }
            } else {
                // Some succeeded, some failed
                warningMessage = [NSString stringWithFormat:@"%ld out of %ld new images uploaded successfully",
                                  (long)newDownloadURLs.count, (long)totalNewImages];
            }
        }

        if (!shouldProceed) {
            // All uploads failed and no existing images
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"PetAccessoryManager"
                                                     code:-3
                                                 userInfo:@{
                    NSLocalizedDescriptionKey: @"Failed to upload any new images and accessory has no existing images",
                    @"underlyingErrors": uploadErrors
                }];
                completion(error);
            }
            return;
        }

        // Update accessory in database
        [self updateAccessoryInDatabase:accessory completion:^(NSError * _Nullable dbError) {
            if (dbError) {
                NSLog(@"❌ Database update failed: %@", dbError.localizedDescription);

                if (completion) {
                    if (uploadErrors.count > 0) {
                        // Combine upload and database errors
                        NSMutableArray *allErrors = [uploadErrors mutableCopy];
                        [allErrors addObject:dbError];

                        NSError *combinedError = [NSError errorWithDomain:@"PetAccessoryManager"
                                                                     code:-4
                                                                 userInfo:@{
                            NSLocalizedDescriptionKey: @"Failed to update accessory",
                            @"underlyingErrors": allErrors
                        }];
                        completion(combinedError);
                    } else {
                        completion(dbError);
                    }
                }
            } else {
                NSLog(@"✅ Accessory updated successfully with %ld total images",
                      (long)allImageURLs.count);

                if (completion) {
                    if (warningMessage) {
                        // Partial success with warning
                        NSError *warning = [NSError errorWithDomain:@"PetAccessoryManager"
                                                               code:1 // Warning code
                                                           userInfo:@{
                            NSLocalizedDescriptionKey: warningMessage,
                            @"totalImages": @(allImageURLs.count),
                            @"newImagesUploaded": @(newDownloadURLs.count),
                            @"existingImages": @(existingURLs.count)
                        }];
                        completion(warning);
                    } else {
                        // Complete success
                        completion(nil);
                    }
                }
            }
        }];
    }

    - (void)updateAccessoryInDatabase:(PetAccessory *)accessory
    completion:(void (^)(NSError * _Nullable error))completion {

        // Validate accessory
        if (!accessory || !accessory.accessoryID) {
            if (completion) {
                completion([NSError errorWithDomain:@"PetAccessoryManager"
                                               code:-5
                                           userInfo:@{NSLocalizedDescriptionKey: @"Invalid accessory for database update"}]);
            }
            return;
        }

        NSLog(@"💾 Updating accessory %@ in database...", accessory.accessoryID);

        // Prepare update data
        NSMutableDictionary *updateData = [NSMutableDictionary dictionary];

        // Add fields that might have changed
        if (accessory.name) updateData[@"name"] = accessory.name;
        if (accessory.price) updateData[@"price"] = accessory.price;
        if (accessory.desc) updateData[@"desc"] = accessory.desc;
        if (accessory.petMainCategoryID > 0) updateData[@"petMainCategoryID"] = @(accessory.petMainCategoryID);
        if (accessory.petSubCategoryID > 0) updateData[@"petSubCategoryID"] = @(accessory.petSubCategoryID);
        updateData[@"condition"] = @(accessory.condition);
        updateData[@"accessKindType"] = @(accessory.accessKindType);

        // Update image URLs if they exist
        if (accessory.imageURLsArray) {
            updateData[@"imageURLsArray"] = accessory.imageURLsArray;
        }

        // Add metadata
        updateData[@"updatedAt"] = [FIRTimestamp timestampWithDate:[NSDate date]];
        updateData[@"updatedBy"] = UserManager.sharedManager.currentUser.ID ?: @"unknown";

        // Perform Firestore update
        FIRDocumentReference *docRef = [[self.firestore collectionWithPath:@"petAccessories"] documentWithPath:accessory.accessoryID];

        [docRef updateData:updateData completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"❌ Firestore update failed: %@", error.localizedDescription);
            } else {
                NSLog(@"✅ Firestore update successful");
            }

            if (completion) completion(error);
        }];
    }










    -(void)updateAccessoryWithComplationUpdatedClass:(PetAccessory *)model completion:(void (^)(NSError * _Nullable, PetAccessory * _Nullable updatedModel))completion
    {
        if (!model.accessoryID) {
            if (completion) completion([NSError errorWithDomain:@"InvalidID" code:0 userInfo:nil],model);
            return;
        }

        NSDictionary *data = [model toFirestoreDictionary];
        [[[self.firestore collectionWithPath:@"petAccessories"] documentWithPath:model.accessoryID] setData:data merge:YES];

    }
    - (void)updateAccessory:(PetAccessory *)accessory completion:(void (^)(NSError * _Nullable error))completion {
        if (!accessory.accessoryID) {
            if (completion) completion([NSError errorWithDomain:@"InvalidID" code:0 userInfo:nil]);
            return;
        }

        NSDictionary *data = [accessory toFirestoreDictionary];
        [[[self.firestore collectionWithPath:@"petAccessories"] documentWithPath:accessory.accessoryID]
         setData:data completion:completion];
    }

    - (void)updateAccessoryID:(NSString *)accessoryID
              showInAppMarket:(BOOL)showInAppMarket
                   completion:(void (^)(NSError * _Nullable error))completion {
        NSString *cleanID = [accessoryID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (cleanID.length == 0) {
            if (completion) {
                completion([NSError errorWithDomain:@"PetAccessoryManager"
                                               code:-6
                                           userInfo:@{NSLocalizedDescriptionKey: @"Missing accessory ID for visibility update"}]);
            }
            return;
        }

        NSDictionary *data = @{
            @"showInAppMarket": @(showInAppMarket),
            @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"updatedBy": UserManager.sharedManager.currentUser.ID ?: @"unknown"
        };
        [[[self.firestore collectionWithPath:@"petAccessories"] documentWithPath:cleanID]
         updateData:data completion:completion];
    }

    - (void)deleteAccessory:(NSString *)accessoryID completion:(void (^)(NSError * _Nullable error))completion {
        // 🗑️ Fetch image URLs before deleting the document so we can clean up Storage
        [self pp_fetchImageURLsForAccessoryID:accessoryID completion:^(NSArray<NSString *> *imageURLs) {
            [PPImageCollection deleteEntityMediaWithEntityType:@"accessories" entityID:accessoryID completion:nil];
            [PPImageCollection deleteEntityMediaWithEntityType:@"used-accessories" entityID:accessoryID completion:nil];
            [[[self.firestore collectionWithPath:@"petAccessories"] documentWithPath:accessoryID]
             deleteDocumentWithCompletion:^(NSError * _Nullable error) {
                if (!error && imageURLs.count > 0) {
                    [PPFunc pp_deleteStorageImagesForURLs:imageURLs];
                }
                if (completion) completion(error);
            }];
        }];
    }

#pragma mark - 🗑️ Storage Cleanup Helpers

    - (void)pp_fetchImageURLsForAccessoryID:(NSString *)accessoryID
                                completion:(void (^)(NSArray<NSString *> *urls))completion {
        if (!accessoryID || accessoryID.length == 0) {
            if (completion) completion(@[]);
            return;
        }
        [[[self.firestore collectionWithPath:@"petAccessories"] documentWithPath:accessoryID]
         getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error || !snapshot.exists) {
                if (completion) completion(@[]);
                return;
            }
            NSDictionary *data = snapshot.data;
            NSArray *urls = data[@"imageURLsArray"];
            if (![urls isKindOfClass:NSArray.class]) urls = @[];
            if (completion) completion(urls);
        }];
    }

    - (NSArray<PetAccessory *> *)filterByMainCategory:(NSInteger)mainCatID subCategory:(NSInteger)subCatID {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"petMainCategoryID == %ld AND petSubCategoryID == %ld", mainCatID, subCatID];
        return [self.accessoriesArray filteredArrayUsingPredicate:predicate];
    }


    + (void)addFavoriteAccessoryWithID:(NSString *)accessoryID forUserID:(NSString *)userID {
        FIRFirestore *db = [FIRFirestore firestore];

        NSDictionary *data = @{
            @"favoritedAt": [FIRTimestamp timestamp]
        };

        FIRDocumentReference *userDoc = [[db collectionWithPath:@"UsersCol"] documentWithPath:userID];
        FIRCollectionReference *favCollection = [userDoc collectionWithPath:@"favoriteAccessories"];

        [[favCollection documentWithPath:accessoryID]
         setData:data completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"❌ Error saving accessory favorite: %@", error.localizedDescription);
            } else {
                NSLog(@"✅ Accessory favorited: %@", accessoryID);
                [PetAdManager trackInteraction:PPItemInteractionTypeFavoriteAdd
                                     forItemID:accessoryID
                                    collection:@"petAccessories"
                                        userID:userID
                                    completion:nil];
            }
        }];
    }

    + (void)removeFavoriteAccessoryWithID:(NSString *)accessoryID forUserID:(NSString *)userID {
        FIRFirestore *db = [FIRFirestore firestore];

        FIRDocumentReference *userDoc = [[db collectionWithPath:@"UsersCol"] documentWithPath:userID];
        FIRCollectionReference *favCollection = [userDoc collectionWithPath:@"favoriteAccessories"];

        [[favCollection documentWithPath:accessoryID]
         deleteDocumentWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"❌ Error removing favorite accessory: %@", error.localizedDescription);
            } else {
                NSLog(@"✅ Accessory unfavorited: %@", accessoryID);
                [PetAdManager trackInteraction:PPItemInteractionTypeFavoriteRemove
                                     forItemID:accessoryID
                                    collection:@"petAccessories"
                                        userID:userID
                                    completion:nil];
            }
        }];
    }

    + (void)isAccessoryFavorited:(NSString *)accessoryID
    forUser:(NSString *)userID
    completion:(void (^)(BOOL favorited))completion {
        FIRFirestore *db = [FIRFirestore firestore];

        FIRDocumentReference *userDoc = [[db collectionWithPath:@"UsersCol"] documentWithPath:userID];
        FIRCollectionReference *favCollection = [userDoc collectionWithPath:@"favoriteAccessories"];

        [[favCollection documentWithPath:accessoryID]
         getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
            if (error) {
                NSLog(@"❌ Error checking accessory favorite: %@", error.localizedDescription);
                completion(NO);
            } else {
                completion(snapshot.exists);
            }
        }];
    }

    + (void)fetchFavoriteAccessoryIDsForUserID:(NSString *)userID
    completion:(void (^)(NSArray<NSString *> *accessoryIDs))completion {
        FIRFirestore *db = [FIRFirestore firestore];

        FIRDocumentReference *userDoc = [[db collectionWithPath:@"UsersCol"] documentWithPath:userID];
        FIRCollectionReference *favCollection = [userDoc collectionWithPath:@"favoriteAccessories"];

        [favCollection getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
            if (error) {
                NSLog(@"❌ Error fetching favorite accessories: %@", error.localizedDescription);
                completion(@[]);
                return;
            }

            NSMutableArray *accessoryIDs = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                [accessoryIDs addObject:doc.documentID];
            }

            completion(accessoryIDs);
        }];
    }



    //////
    ///
    ///
    + (void)fetchAccessoriesForUserID:(NSString *)userID completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {
        FIRFirestore *db = [FIRFirestore firestore];
        [[[db collectionWithPath:@"petAccessories"]
          queryWhereField:@"ownerID" isEqualTo:userID]
         getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
            if (error || !snapshot) {
                completion(@[]);
                return;
            }

            NSMutableArray<PetAccessory *> *accessories = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                item.accessoryID = doc.documentID;
                if (!PPAccessoryItemPassesUsedAccessoryFlag(item, item.accessKindType)) {
                    continue;
                }
                [accessories addObject:item];
            }
            completion(accessories);
        }];
    }

    + (void)fetchAccessoriesForUserID:(NSString *)userID accessKindType:(AccessKindType)accessKindType completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {
        FIRFirestore *db = [FIRFirestore firestore];
        [[[db collectionWithPath:@"petAccessories"]
          queryWhereField:@"ownerID" isEqualTo:userID]
         getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
            if (error || !snapshot) {
                completion(@[]);
                return;
            }

            NSMutableArray<PetAccessory *> *accessories = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                item.accessoryID = doc.documentID;
                if (item.accessKindType == accessKindType &&
                    PPAccessoryItemPassesUsedAccessoryFlag(item, item.accessKindType)) {
                    [accessories addObject:item];
                }

            }
            completion(accessories);
        }];
    }

    + (void)fetchAccessoriesWithIDs:(NSArray<NSString *> *)itemIDs completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {
        if (itemIDs.count == 0) {
            completion(@[]);
            return;
        }

        FIRFirestore *db = [FIRFirestore firestore];
        NSMutableArray<PetAccessory *> *results = [NSMutableArray array];
        dispatch_group_t group = dispatch_group_create();

        for (NSString *itemID in itemIDs) {
            dispatch_group_enter(group);
            [[[db collectionWithPath:@"petAccessories"] documentWithPath:itemID]
             getDocumentWithCompletion:^(FIRDocumentSnapshot *doc, NSError *error) {
                if (doc.exists && doc.data) {
                    PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                    item.accessoryID = doc.documentID;
                    if (PPAccessoryItemPassesUsedAccessoryFlag(item, item.accessKindType)) {
                        [results addObject:item];
                    }
                }
                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            completion(results);
        });
    }


    + (void)fetchAccessoriesTypeAccessWithIDs:(NSArray<NSString *> *)itemIDs completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {
        if (itemIDs.count == 0) {
            completion(@[]);
            return;
        }

        FIRFirestore *db = [FIRFirestore firestore];
        NSMutableArray<PetAccessory *> *results = [NSMutableArray array];
        dispatch_group_t group = dispatch_group_create();

        for (NSString *itemID in itemIDs) {
            dispatch_group_enter(group);
            [[[db collectionWithPath:@"petAccessories"] documentWithPath:itemID]
             getDocumentWithCompletion:^(FIRDocumentSnapshot *doc, NSError *error) {
                if (doc.exists && doc.data) {
                    PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                    item.accessoryID = doc.documentID;

                    if(item.accessKindType == AccessTypeAccessory &&
                       PPAccessoryItemPassesUsedAccessoryFlag(item, item.accessKindType))
                        [results addObject:item];
                }
                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            completion(results);
        });
    }


    + (void)fetchAccessoriesTypeFoodWithIDs:(NSArray<NSString *> *)itemIDs completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {
        if (itemIDs.count == 0) {
            completion(@[]);
            return;
        }

        FIRFirestore *db = [FIRFirestore firestore];
        NSMutableArray<PetAccessory *> *results = [NSMutableArray array];
        dispatch_group_t group = dispatch_group_create();

        for (NSString *itemID in itemIDs) {
            dispatch_group_enter(group);
            [[[db collectionWithPath:@"petAccessories"] documentWithPath:itemID]
             getDocumentWithCompletion:^(FIRDocumentSnapshot *doc, NSError *error) {
                if (doc.exists && doc.data) {
                    PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                    item.accessoryID = doc.documentID;

                    if(item.accessKindType == AccessTypeFood)
                        [results addObject:item];
                }
                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            completion(results);
        });
    }

    + (void)fetchProviderMarketplaceAccessoriesForOwnerID:(NSString *)ownerID
                                         excludingAccessory:(PetAccessory *)exclude
                                                completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {
        [self fetchProviderMarketplaceAccessoriesForOwnerID:ownerID
                                          excludingAccessory:exclude
                                         completionWithError:^(NSArray<PetAccessory *> *accessories, NSError * _Nullable error) {
            if (error) {
                NSLog(@"❌ fetchProviderMarketplaceAccessories error: %@", error.localizedDescription);
            }
            if (completion) completion(accessories ?: @[]);
        }];
    }

    + (void)fetchProviderMarketplaceAccessoriesForOwnerID:(NSString *)ownerID
                                        excludingAccessory:(PetAccessory *)exclude
                                       completionWithError:(void (^)(NSArray<PetAccessory *> *accessories, NSError * _Nullable error))completion
    {
        [self pp_fetchProviderAccessoriesForOwnerID:ownerID
                                              kinds:@[@(AccessTypeAccessory), @(AccessTypeFood)]
                                  excludingAccessory:exclude
                         requiresAppMarketVisibility:YES
                                         completion:completion];
    }

    + (void)fetchProviderPharmacyAccessoriesForOwnerID:(NSString *)ownerID
                                     excludingAccessory:(PetAccessory *)exclude
                                    completionWithError:(void (^)(NSArray<PetAccessory *> *accessories, NSError * _Nullable error))completion
    {
        [self pp_fetchProviderAccessoriesForOwnerID:ownerID
                                              kinds:@[@(AccessTypePetMedicine)]
                                  excludingAccessory:exclude
                         requiresAppMarketVisibility:NO
                                         completion:completion];
    }

    + (void)fetchPublicMarketplaceAccessoriesWithCompletion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                                     NSError * _Nullable error))completion
    {
        [self pp_fetchPublicAccessoriesForKinds:@[@(AccessTypeAccessory), @(AccessTypeFood)]
                    requiresAppMarketVisibility:YES
                                    completion:completion];
    }

    + (void)fetchPublicPharmacyAccessoriesWithCompletion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                                  NSError * _Nullable error))completion
    {
        [self pp_fetchPublicAccessoriesForKinds:@[@(AccessTypePetMedicine)]
                    requiresAppMarketVisibility:NO
                                    completion:completion];
    }

    + (void)pp_fetchPublicAccessoriesForKinds:(NSArray<NSNumber *> *)kinds
                  requiresAppMarketVisibility:(BOOL)requiresAppMarketVisibility
                                  completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                       NSError * _Nullable error))completion
    {
        [self pp_loadExpiryThresholdIfNeeded];
        if (kinds.count == 0) {
            if (completion) completion(@[], nil);
            return;
        }

        FIRFirestore *db = [FIRFirestore firestore];
        dispatch_group_t group = dispatch_group_create();
        __block NSError *firstError = nil;
        NSMutableDictionary<NSString *, PetAccessory *> *mergedByID = [NSMutableDictionary dictionary];

        for (NSNumber *kindNumber in kinds) {
            AccessKindType kind = (AccessKindType)kindNumber.integerValue;
            dispatch_group_enter(group);

            FIRQuery *query = [[db collectionWithPath:@"petAccessories"]
                               queryWhereField:@"accessKindType" isEqualTo:@(kind)];
            if (requiresAppMarketVisibility) {
                query = PPAccessoryRequirePublicMarketVisibility(query);
            }

            [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
                if (error && !firstError) {
                    firstError = error;
                }

                NSMutableArray<PetAccessory *> *items = [NSMutableArray array];
                for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
                    PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                    item.accessoryID = doc.documentID;
                    [items addObject:item];
                }

                NSArray<PetAccessory *> *visible = [self pp_filterItems:items
                                                           matchingKind:kind
                                            requiresAppMarketVisibility:requiresAppMarketVisibility];
                @synchronized (mergedByID) {
                    for (PetAccessory *item in visible) {
                        NSString *itemID = item.accessoryID ?: @"";
                        if (itemID.length == 0 || mergedByID[itemID] != nil) {
                            continue;
                        }
                        mergedByID[itemID] = item;
                    }
                }

                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSArray<PetAccessory *> *results = [self pp_sortItemsByCreatedAtDescending:mergedByID.allValues ?: @[]];
            if (completion) {
                completion(results, (results.count == 0 ? firstError : nil));
            }
        });
    }

    + (void)pp_fetchProviderAccessoriesForOwnerID:(NSString *)ownerID
                                            kinds:(NSArray<NSNumber *> *)kinds
                                excludingAccessory:(PetAccessory *)exclude
                       requiresAppMarketVisibility:(BOOL)requiresAppMarketVisibility
                                       completion:(void (^)(NSArray<PetAccessory *> *accessories,
                                                            NSError * _Nullable error))completion
    {
        [self pp_loadExpiryThresholdIfNeeded];
        if (ownerID.length == 0) {
            if (completion) completion(@[], nil);
            return;
        }

        NSSet<NSNumber *> *allowedKinds = [NSSet setWithArray:kinds ?: @[]];
        NSDate *cutoff = [[NSDate date] dateByAddingTimeInterval:_pp_cachedExpiryThresholdDays * 86400.0];
        NSString *excludeID = exclude.accessoryID ?: @"";

        FIRFirestore *db = [FIRFirestore firestore];
        FIRQuery *query = [[[db collectionWithPath:@"petAccessories"]
                           queryWhereField:@"ownerID" isEqualTo:ownerID]
                           queryLimitedTo:60];

        [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
            if (error) {
                if (completion) completion(@[], error);
                return;
            }

            NSMutableArray<PetAccessory *> *results = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
                if (excludeID.length > 0 && [doc.documentID isEqualToString:excludeID]) {
                    continue;
                }

                PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                item.accessoryID = doc.documentID;

                if (![allowedKinds containsObject:@(item.accessKindType)]) {
                    continue;
                }
                if (![self pp_itemPassesVisibilityAndExpiry:item
                                                 cutoffDate:cutoff
                                  requiresAppMarketVisibility:requiresAppMarketVisibility]) {
                    continue;
                }
                if (!PPAccessoryItemPassesUsedAccessoryFlag(item, item.accessKindType)) {
                    continue;
                }
                [results addObject:item];
            }

            NSArray<PetAccessory *> *sorted = [self pp_sortItemsByCreatedAtDescending:results];
            if (completion) completion(sorted, nil);
        }];
    }

    + (void)fetchSuggestedAccessoriesForAccess:(PetAccessory *)ad completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {
        if (!ad || !ad.name || ad.name.length == 0) {
            if (completion) completion(@[]);
            return;
        }

        FIRFirestore *db = [FIRFirestore firestore];
        FIRCollectionReference *accessoriesRef = [db collectionWithPath:@"petAccessories"];

        FIRQuery *query = [accessoriesRef queryWhereField:@"petMainCategoryID"
                                                isEqualTo:@(ad.petMainCategoryID)];

        if (ad.accessKindType == AccessTypeFood) {

        } else {

        }


        //AccessTypeAccessory
        [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
            if (error) {
                NSLog(@"❌ Error fetching accessories: %@", error.localizedDescription);
                if (completion) completion(@[]);
                return;
            }

            NSMutableArray<PetAccessory *> *results = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                if ([doc.documentID isEqualToString:ad.accessoryID]) {
                    continue; // Skip the same accessory
                }

                PetAccessory *accessory = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                accessory.accessoryID = doc.documentID;
                if (accessory.accessKindType == ad.accessKindType &&
                    PPAccessoryItemPassesUsedAccessoryFlag(accessory, accessory.accessKindType)) {
                    [results addObject:accessory];
                }
            }

            if (completion) completion(results);
        }];

    }

    -(PetAccessory *)getAccessoryID:(NSString *)accessID
    {
        for (PetAccessory *accessory in self.accessoriesArray) {
            if ([accessory.accessoryID isEqualToString:accessID]) {
                return accessory;
            }
        }

        return nil;
    }



#pragma mark - Local Filtering Methods

    /// Filter loaded accessories by condition enum (new/used)
    - (NSArray<PetAccessory *> *)filterAccessoriesWithCondition:(AccessConditions)condition {
        if (!PPAllwedUsedAccessoriesEnabled() && condition == AccessConditionsUsed) {
            return @[];
        }
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"condition == %ld", (long)condition];
        return [self.accessoriesArray filteredArrayUsingPredicate:predicate];
    }

    /// Filter by mainCategory, subCategory, and condition
    - (NSArray<PetAccessory *> *)filterAccessoriesWithMainCategory:(NSInteger)mainCategoryID
    subCategory:(NSInteger)subCategoryID
    condition:(AccessConditions)condition {
        if (!PPAllwedUsedAccessoriesEnabled() && condition == AccessConditionsUsed) {
            return @[];
        }
        NSPredicate *predicate = [NSPredicate predicateWithFormat:
                                      @"petMainCategoryID == %ld AND petSubCategoryID == %ld AND condition == %ld",
                                  mainCategoryID, subCategoryID, (long)condition
        ];
        return [self.accessoriesArray filteredArrayUsingPredicate:predicate];
    }

#pragma mark - Firestore Real-time Listener with Condition

    /// Start listener, optionally filtering by condition (pass 0 to skip)
    - (void)startListeningWithMainCategory:(NSInteger)mainCategoryID
    condition:(AccessConditions)condition
    onArray:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock {

        //NSLog(@"PetAccessory: startListeningWithMainCategory : %ld condition: %ld", mainCategoryID,condition);

        if (self.listener) {
            [self.listener remove];
        }

        FIRQuery *query = [[self.firestore collectionWithPath:@"petAccessories"]
                           queryWhereField:@"petMainCategoryID" isEqualTo:@(mainCategoryID)];

        if (condition == AccessConditionsNew || condition == AccessConditionsUsed) {
            query = [query queryWhereField:@"condition" isEqualTo:@(condition)];
        }

        if (mainCategoryID == 0) {
            query = [query queryWhereField:@"condition" isEqualTo:@(AccessConditionsNew)];
        }

        // U4: Prevent retain cycle in accessory condition listener
        __weak typeof(self) weakSelf = self;
        self.listener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                NSLog(@"PetAccessory:  ❌ Error listening for accessory changes: %@", error.localizedDescription);
                return;
            }
            [strongSelf.accessoriesArray removeAllObjects];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *accessory = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                if (!PPAccessoryItemPassesUsedAccessoryFlag(accessory, AccessTypeAccessory)) {
                    continue;
                }
                [strongSelf.accessoriesArray addObject:accessory];

                // NSLog(@"PetAccessory: %@", accessory.accessoryID);
            }
            if (updateBlock) {
                updateBlock(strongSelf.accessoriesArray);
            }
        }];
    }


    - (NSArray<PetAccessory *> *)filterAccessoriesByKind:(AccessKindType)kind {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"accessKindType == %ld", kind];
        NSArray<PetAccessory *> *items = [self.accessoriesArray filteredArrayUsingPredicate:predicate];
        if (PPAllwedUsedAccessoriesEnabled() || kind != AccessTypeAccessory) {
            return items;
        }
        return [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PetAccessory *item, __unused NSDictionary *bindings) {
            return PPAccessoryItemPassesUsedAccessoryFlag(item, AccessTypeAccessory);
        }]];
    }


    - (void)startListeningWithKind:(AccessKindType)kindType
    onUpdate:(void (^)(NSArray<PetAccessory *> *accessories))updateBlock {

        if (self.listener) {
            [self.listener remove];
        }

        AccessKindType normalizedKind = PPAccessKindTypeNormalize(kindType);
        FIRQuery *query = [[self.firestore collectionWithPath:@"petAccessories"]
                           queryWhereField:@"accessKindType" isEqualTo:@(normalizedKind)];
        if (normalizedKind != AccessTypePetMedicine) {
            query = PPAccessoryRequirePublicMarketVisibility(query);
        }

        // U4: Prevent retain cycle in accessory kind-only listener
        __weak typeof(self) weakSelf = self;
        self.listener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                NSLog(@"❌ Error listening for accessories: %@", error.localizedDescription);
                return;
            }

            [strongSelf.accessoriesArray removeAllObjects];
            NSMutableArray<PetAccessory *> *snapshotItems = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *accessory = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                accessory.accessoryID = doc.documentID;
                if (accessory) [snapshotItems addObject:accessory];
            }

            BOOL requiresMarketVisibility = normalizedKind != AccessTypePetMedicine;
            NSArray<PetAccessory *> *visibleItems =
                [PetAccessoryManager pp_filterItems:snapshotItems
                                      matchingKind:normalizedKind
                       requiresAppMarketVisibility:requiresMarketVisibility];
            [strongSelf.accessoriesArray addObjectsFromArray:visibleItems];

            if (updateBlock) {
                updateBlock(strongSelf.accessoriesArray);
            }
        }];
    }


    - (void)fetchAccessoriesOfKind:(AccessKindType)kind
    completion:(void (^)(NSArray<PetAccessory *> *accessories))completion {

        AccessKindType normalizedKind = PPAccessKindTypeNormalize(kind);
        FIRQuery *query = [[self.firestore collectionWithPath:@"petAccessories"]
                           queryWhereField:@"accessKindType" isEqualTo:@(normalizedKind)];
        if (normalizedKind != AccessTypePetMedicine) {
            query = PPAccessoryRequirePublicMarketVisibility(query);
        }

        [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
            if (error) {
                NSLog(@"❌ Error fetching by kind: %@", error.localizedDescription);
                completion(@[]);
                return;
            }

            NSMutableArray *results = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAccessory *item = [[PetAccessory alloc] initWithDictionary:doc.data documentID:doc.documentID];
                item.accessoryID = doc.documentID;
                if (item) [results addObject:item];
            }

            BOOL requiresMarketVisibility = normalizedKind != AccessTypePetMedicine;
            NSArray<PetAccessory *> *visibleItems =
                [PetAccessoryManager pp_filterItems:results
                                      matchingKind:normalizedKind
                       requiresAppMarketVisibility:requiresMarketVisibility];
            completion(visibleItems);
        }];
    }
#pragma mark - Global Accessories Fetching
    /// Fetch all accessories for all main kinds (ordered by createdAt descending).
    - (void)fetchAccessoriesForAllMainKinds:(void (^)(NSArray<PetAccessory *> *accessories))completion
    {
        FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];

        FIRQuery *query = PPAccessoryRequirePublicMarketVisibility([db collectionWithPath:@"petAccessories"]);
        query = [query queryOrderedByField:@"createdAt" descending:YES];

        query = [query queryLimitedTo:50];

        [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot,
                                            NSError *error) {

            if (error || !snapshot) {
                NSLog(@"❌ fetchAccessoriesForAllMainKinds error: %@",
                      error.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(@[]);
                });
                return;
            }

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

                NSMutableArray<PetAccessory *> *results =
                [NSMutableArray arrayWithCapacity:snapshot.documents.count];

                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    PetAccessory *item =
                    [[PetAccessory alloc] initWithDictionary:doc.data
                                                  documentID:doc.documentID];
                    item.accessoryID = doc.documentID;
                    if (item) [results addObject:item];
                }

                NSArray<PetAccessory *> *visibleAccessories =
                    [PetAccessoryManager pp_filterVisibleItems:results matchingKind:AccessTypeAccessory];

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(visibleAccessories);
                });
            });
        }];
    }

#pragma mark - Global Food Fetching
    /// Fetch all food accessories for all main kinds (AccessTypeFood only)
    - (void)fetchFoodForAllMainKinds:(void (^)(NSArray<PetAccessory *> *foods))completion
    {
        FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];

        FIRQuery *query =
        [[db collectionWithPath:@"petAccessories"]
         queryWhereField:@"accessKindType" isEqualTo:@(AccessTypeFood)];
        query = PPAccessoryRequirePublicMarketVisibility(query);
        query = [query queryOrderedByField:@"createdAt" descending:YES];

        query = [query queryLimitedTo:50];

        [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot,
                                            NSError *error) {

            if (error || !snapshot) {
                NSLog(@"❌ fetchFoodForAllMainKinds error: %@",
                      error.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(@[]);
                });
                return;
            }

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

                NSMutableArray<PetAccessory *> *results =
                [NSMutableArray arrayWithCapacity:snapshot.documents.count];

                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    PetAccessory *item =
                    [[PetAccessory alloc] initWithDictionary:doc.data
                                                  documentID:doc.documentID];
                    item.accessoryID = doc.documentID;
                    if (item) [results addObject:item];
                }

                NSArray<PetAccessory *> *visibleFoods =
                    [PetAccessoryManager pp_filterVisibleItems:results matchingKind:AccessTypeFood];

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(visibleFoods);
                });
            });
        }];
    }


#pragma mark - One-time Migration Helper
    /// One-time migration: Populate missing searchTitle for existing accessories.
    - (void)migrateSearchTitleForExistingAccessories
    {
        FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];

        NSLog(@"🚀 Starting accessories searchTitle migration...");

        [[db collectionWithPath:@"petAccessories"]
         getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

            if (error || !snapshot) {
                NSLog(@"❌ Accessories migration failed: %@", error.localizedDescription);
                return;
            }

            __block NSInteger updatedCount = 0;

            dispatch_group_t group = dispatch_group_create();

            for (FIRDocumentSnapshot *doc in snapshot.documents) {

                NSString *name = doc.data[@"name"];
                NSString *searchTitle = doc.data[@"searchTitle"];

                // Skip if already migrated or invalid
                if (searchTitle.length > 0 || name.length == 0) {
                    continue;
                }

                dispatch_group_enter(group);

                NSString *normalized =
                [ArabicNormalizer normalize:name];

                [[doc reference] updateData:@{
                    @"searchTitle": normalized
                } completion:^(NSError * _Nullable err) {

                    if (err) {
                        NSLog(@"❌ Failed to migrate accessory %@: %@",
                              doc.documentID, err.localizedDescription);
                    } else {
                        updatedCount++;
                    }

                    dispatch_group_leave(group);
                }];
            }

            dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                NSLog(@"✅ Accessories searchTitle migration completed. Updated: %ld",
                      (long)updatedCount);
            });
        }];
    }


#pragma mark - Latest Accessories Fetching

- (void)dealloc {
    [self.listener remove];
    self.listener = nil;
}

@end
































/*
 [[PetAccessoryManager sharedManager] startListeningWithUpdate:^(NSArray<PetAccessory *> *accessories) {
     self.filteredAccessories = accessories;
     [self.collectionView reloadData];
 }];
 */









