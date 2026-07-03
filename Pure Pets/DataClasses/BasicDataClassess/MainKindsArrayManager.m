//
//  MainKindsArrayManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/08/2025.
//

#import "MainKindsArrayManager.h"
static NSString * const kCachedMainKindsKey = @"cachedMainKinds_v2";

@interface MainKindsArrayManager ()
- (void)pp_fillAccessoryCategoriesForMainKinds:(NSArray<MainKindsModel *> *)mainKinds completion:(dispatch_block_t)completion;
@end


//NSArray<MainKindsModel *> *PPMainKinds      = nil;

// MainKindsArrayManager.m
@implementation MainKindsArrayManager
+ (instancetype)shared {

    static id s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [self new];
        //   sharedInstance.MainKindsArray = [NSMutableArray<MainKindsModel *> new];
        //   self.subKindsArrayForFilter = [[NSMutableArray<SubKindModel *> alloc] init];
    });

    return s;
}

- (void)listenForMainKindsChangesWithBlock:(void (^)(NSArray<MainKindsModel *> *mainKinds, NSError *error))block {
    if (self.mainKindsListener) {
        [self.mainKindsListener remove];
        self.mainKindsListener = nil;
    }

    FIRQuery *query = [[[[FIRFirestore firestore] collectionWithPath:@"MainKindsCollection"]
                        queryWhereField:@"is_visible_in_user_app" isEqualTo:@YES]
                       queryOrderedByField:@"sortingKey" descending:NO];

    __weak typeof(self) weakSelf = self;
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[MainKinds] ❌ Fetch error: %@", error.localizedDescription);
            if (block) block(nil, error);
            return;
        }
        if (!snapshot) {
            if (block) block(@[], nil);
            return;
        }

        NSMutableArray<MainKindsModel *> *arr = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            MainKindsModel *m = [[MainKindsModel alloc] initWithSnapshot:doc];
            if (m) [arr addObject:m];
        }

        [arr sortUsingComparator:^NSComparisonResult(MainKindsModel *a, MainKindsModel *b) {
            return a.sortingKey < b.sortingKey ? NSOrderedAscending :
            a.sortingKey > b.sortingKey ? NSOrderedDescending :
            NSOrderedSame;
        }];

        [strongSelf pp_fillAccessoryCategoriesForMainKinds:arr completion:^{
            strongSelf.MainKindsArray = arr.mutableCopy;

            NSLog(@"[MainKinds] 🔄 Fetch completed → %lu items", (unsigned long)arr.count);

            [strongSelf saveMainKindsToCache];

            if (block) block(arr, nil);
        }];
    }];
}

//tnuBlC!bPt^x]37R
/*
 tnuBlC!bPt^x]37R
 + (void)loadMainDataCompletionHandler:(void (^)(int result))completionHandler {
 NSLog(@"===========================================");
 NSLog(@"PPMainKindsManager: 🔄 loadMainData (prefer cache, fallback server)");

 FIRQuery *q = [[[FIRFirestore firestore] collectionWithPath:@"MainKindsCollection"]
 queryOrderedByField:@"ID" descending:NO];

 // ---- 1) Try CACHE ----
 [q getDocumentsWithSource:FIRFirestoreSourceCache
 completion:^(FIRQuerySnapshot * _Nullable cacheSnap, NSError * _Nullable cacheErr)
 {
 if (cacheErr) {
 NSLog(@"PPMainKindsManager: ⚠️ Cache read error: %@", cacheErr.localizedDescription);
 }

 BOOL hasCache = (cacheSnap && cacheSnap.documents.count > 0);
 if (hasCache) {
 NSLog(@"PPMainKindsManager: 💾 Cache hit. docs=%lu fromCache=%d pending=%d",
 (unsigned long)cacheSnap.documents.count,
 cacheSnap.metadata.isFromCache,
 cacheSnap.metadata.hasPendingWrites);

 NSArray<MainKindsModel *> *cacheModels = [self pp_modelsFromSnapshot:cacheSnap];
 // Keep immutable snapshot in global
 PPMainKindsArray = [cacheModels copy];

 // Return immediately to UI
 [self pp_finishWithSuccess:YES completion:completionHandler];

 // Also refresh from SERVER in background — optional but recommended
 [self pp_refreshFromServerIfChangedWithQuery:q baseline:cacheModels];

 return;
 }

 // ---- 2) No cache: fall back to SERVER ----
 NSLog(@"PPMainKindsManager: 💨 No cache. Fetching from SERVER...");
 [q getDocumentsWithSource:FIRFirestoreSourceServer
 completion:^(FIRQuerySnapshot * _Nullable serverSnap, NSError * _Nullable serverErr)
 {
 if (serverErr || !serverSnap) {
 NSLog(@"PPMainKindsManager: ❌ Server fetch failed: %@", serverErr.localizedDescription);
 [self pp_finishWithSuccess:NO completion:completionHandler];
 return;
 }

 NSLog(@"PPMainKindsManager: 🌐 Server docs=%lu fromCache=%d pending=%d",
 (unsigned long)serverSnap.documents.count,
 serverSnap.metadata.isFromCache,
 serverSnap.metadata.hasPendingWrites);

 NSArray<MainKindsModel *> *srvModels = [self pp_modelsFromSnapshot:serverSnap];
 PPMainKindsArray = [srvModels copy];

 [self pp_finishWithSuccess:YES completion:completionHandler];
 }];
 }];
 }
 */
#pragma mark - Helpers

/// Map a snapshot to models, sort by numeric `ID`.
+ (NSArray<MainKindsModel *> *)pp_modelsFromSnapshot:(FIRQuerySnapshot *)snap {
    NSMutableArray<MainKindsModel *> *arr = [NSMutableArray arrayWithCapacity:snap.documents.count];

    for (FIRDocumentSnapshot *doc in snap.documents) {
        if (!doc.exists) { continue; }

        MainKindsModel *m = [[MainKindsModel alloc] initWithSnapshot:doc];
        if (!m) {
            NSLog(@"PPMainKindsManager: ⚠️ initWithSnapshot returned nil for docID=%@", doc.documentID);
            continue;
        }

        // Ensure arrays exist if your UI expects them
        if (!m.SubKindsArray) m.SubKindsArray = [NSMutableArray array];

        [arr addObject:m];
        // Deep log
        // NSLog(@"PPMainKindsManager: main doc=%@ path=%@ ID=%ld", doc.documentID, doc.reference.path, (long)m.ID);
    }

    // Sort by ID ascending (adjust if you need sortingKey, etc.)
    [arr sortUsingComparator:^NSComparisonResult(MainKindsModel *a, MainKindsModel *b) {
        if (a.ID < b.ID) return NSOrderedAscending;
        if (a.ID > b.ID) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return arr;
}

/// Finish on main thread: call completion(1/0) + post notification if success
+ (void)pp_finishWithSuccess:(BOOL)ok completion:(void (^)(int))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(ok ? 1 : 0);
        if (ok) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"fetchMainKindsComplete"
                                                                object:self
                                                              userInfo:nil];
        }
    });
}

/// Fetch from server and update global if different than baseline. Posts notification on change.
+ (void)pp_refreshFromServerIfChangedWithQuery:(FIRQuery *)q
                                      baseline:(NSArray<MainKindsModel *> *)baseline
{
    [q getDocumentsWithSource:FIRFirestoreSourceServer completion:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable err) {
        if (err || !snap) {
            NSLog(@"PPMainKindsManager: ⚠️ Server refresh failed: %@", err.localizedDescription);
            return;
        }

        NSArray<MainKindsModel *> *serverModels = [self pp_modelsFromSnapshot:snap];

        // Simple difference check: count + IDs ordered. Customize if needed.
        BOOL changed = ![self pp_sameMainKinds:baseline other:serverModels];
        if (changed) {
            NSLog(@"PPMainKindsManager: 🔁 Server has updates. Updating global + notifying.");
            PPMainKindsArray = [serverModels copy];

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"fetchMainKindsComplete"
                                                                    object:self
                                                                  userInfo:nil];
            });
        } else {
            NSLog(@"PPMainKindsManager: ✅ Cache already up-to-date with server.");
        }
    }];
}

+ (BOOL)pp_sameMainKinds:(NSArray<MainKindsModel *> *)a other:(NSArray<MainKindsModel *> *)b {
    if (a.count != b.count) return NO;
    for (NSUInteger i = 0; i < a.count; i++) {
        if (a[i].ID != b[i].ID) return NO; // basic equality by ID; extend if needed
    }
    return YES;
}




- (void)fetchMainKindByID:(NSString *)mainID completion:(void(^)(NSDictionary *, NSError *))completion {
    if (!mainID.length) { if (completion) completion(nil, [NSError errorWithDomain:@"arg" code:400 userInfo:nil]); return; }
    [[[[FIRFirestore firestore] collectionWithPath:@"MainKindsCollection"]
      documentWithPath:mainID]
     getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable err) {
        completion(snap.exists ? snap.data : nil, err);
    }];
}

// New subcollection-based implementation
- (void)addOrReplaceSubKind:(SubKindModel *)sub toMainID:(NSString *)mainID completion:(void(^)(NSError *))completion {
    if (!mainID.length || !sub) {
        if (completion) completion([NSError errorWithDomain:@"arg" code:400 userInfo:@{NSLocalizedDescriptionKey:@"Invalid arguments"}]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *mainDoc = [[db collectionWithPath:@"MainKindsCollection"] documentWithPath:mainID];

    // SubKind document id strategy:
    // - Prefer an existing documentID if present
    // - Else use numeric ID as string (stable)
    NSString *subDocID = nil;
    if ([sub respondsToSelector:@selector(documentID)] && sub.ID > 0) {
        subDocID =  [NSString stringWithFormat:@"%ld", (long)sub.ID];
    } else {
        subDocID = [NSString stringWithFormat:@"%ld", (long)sub.ID];
    }

    FIRDocumentReference *subDoc = [[mainDoc collectionWithPath:@"SubKinds"] documentWithPath:subDocID];

    NSMutableDictionary *data = [[sub toDict] mutableCopy];
    // Keep strong linkage
    data[@"MainKindID"] = @(sub.MainKindID ?: [mainID integerValue]);
    data[@"documentID"] = subDocID;

    [subDoc setData:data merge:YES completion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

// New subcollection-based implementation
- (void)removeSubKindID:(NSString *)subID fromMainID:(NSString *)mainID completion:(void(^)(NSError *))completion {
    if (!mainID.length || !subID.length) {
        if (completion) completion([NSError errorWithDomain:@"arg" code:400 userInfo:@{NSLocalizedDescriptionKey:@"Invalid arguments"}]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *mainDoc = [[db collectionWithPath:@"MainKindsCollection"] documentWithPath:mainID];
    FIRDocumentReference *subDoc = [[mainDoc collectionWithPath:@"SubKinds"] documentWithPath:subID];

    [subDoc deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)FillMainKindsArray
{
    [self loadMainDataCompletionHandler:^(int result) {
        NSLog(@"Initial MainKindsArray Complete From AppDelegate");
    }];
}

- (NSArray<MainKindsModel *> *)loadMainKindsFromCache {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] objectForKey:kCachedMainKindsKey];
    if (![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *mainKind in raw) {
        MainKindsModel *u = [[MainKindsModel alloc] initWithDict:mainKind];
        if (u) [out addObject:u];
    }
    //NSLog(@"[Cache] 📥 Loaded %lu users from cache.", (unsigned long)out.count);
    return out;
}


// MARK: - Users cache
- (void)saveMainKindsToCache {
    NSMutableArray *arr = [NSMutableArray array];
    for (MainKindsModel *mainKind in self.MainKindsArray) {
        if ([mainKind respondsToSelector:@selector(toCacheDictionary)]) {
            [arr addObject:[mainKind toCacheDictionary]];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:kCachedMainKindsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    ////NSLog(@"[Cache] 💾 Saved %lu users.", (unsigned long)arr.count);
}


- (void)loadMainDataCompletionHandler:(void (^)(int result))completionHandler {
    // Initialize array if needed

    self.MainKindsArray =  [self loadMainKindsFromCache].mutableCopy;
    NSLog(@"Initial MainKindsArray Complete From %@",self.MainKindsArray.count > 0 ? @"::CACHE::" :  @"::SERVER::");
    if (!self.MainKindsArray) {
        self.MainKindsArray = [NSMutableArray array];
    }
    else
    {


    }

    // If we already have cached MainKinds data, return it immediately.
    BOOL hasCache = (self.MainKindsArray.count > 0);
    if (hasCache) {
        if (completionHandler) {

            NSLog(@"completionHandler MainKindsArray Because it complete from cache ✅✅✅✅✅✅");
            completionHandler(1);  // Return success with cached data
        }
    }

    // Set a flag indicating whether initial data has been seeded
    self.didSeedMainKinds = hasCache;

    // Build the Firestore query (sorted by ID ascending)
    FIRQuery *query = [[[[FIRFirestore firestore] collectionWithPath:@"MainKindsCollection"]
                        queryWhereField:@"is_visible_in_user_app" isEqualTo:@YES]
                       queryOrderedByField:@"sortingKey" descending:NO];

    // One-time server fetch — persistent snapshot listener not needed;
    // MainKinds data (category hierarchy) changes very rarely (weeks/months).
    __weak typeof(self) weakSelf = self;
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"Error fetching MainKinds: %@", error.localizedDescription);
            if (completionHandler && !strongSelf.didSeedMainKinds) {
                completionHandler(0);
            }
            return;
        }
        if (!snapshot) {
            NSLog(@"No snapshot returned for MainKindsCollection");
            if (completionHandler && !strongSelf.didSeedMainKinds) {
                completionHandler(0);
            }
            return;
        }

        // Seed the array from the fetched data
        [strongSelf.MainKindsArray removeAllObjects];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            MainKindsModel *model = [[MainKindsModel alloc] initWithSnapshot:doc];
            if (!model.SubKindsArray) model.SubKindsArray = [NSMutableArray array];
            model.didSeedSubKinds = NO;
            [strongSelf.MainKindsArray addObject:model];
        }
        [strongSelf.MainKindsArray sortUsingComparator:^NSComparisonResult(MainKindsModel *a, MainKindsModel *b) {
            if (a.sortingKey < b.sortingKey) return NSOrderedAscending;
            if (a.sortingKey > b.sortingKey) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        [strongSelf pp_fillAccessoryCategoriesForMainKinds:strongSelf.MainKindsArray completion:^{
            strongSelf.didSeedMainKinds = YES;
            [strongSelf saveMainKindsToCache];

            if (!hasCache && completionHandler) {
                NSLog(@"Initial MainKindsArray updated with Server %lu items.", (unsigned long)strongSelf.MainKindsArray.count);
                completionHandler(1);
            } else if (completionHandler) {
                completionHandler(1);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:PPMainKindsUpdatedNotification object:strongSelf];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"fetchMainKindsComplete" object:strongSelf];
        }];
    }];
}

// Helper method to find index of MainKind by Firestore documentID
- (NSInteger)indexOfMainKindByDocID:(NSString *)docID {
    if (!docID || self.MainKindsArray.count == 0) {
        return NSNotFound;
    }

    __block NSInteger foundIndex = NSNotFound;
    [self.MainKindsArray enumerateObjectsUsingBlock:^(MainKindsModel *obj, NSUInteger idx, BOOL *stop) {
        if ([obj.documentID isEqualToString:docID]) {
            foundIndex = idx;
            *stop = YES;
        }
    }];
    return foundIndex;
}


- (NSArray<SubKindModel *> *)getSubKindArray:(NSInteger)MainKindID
{
    return [[self.MainKindsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", MainKindID]] firstObject].SubKindsArray;
    // return  self.MainKindsArray[MainKindID].SubKindsArray;
}
- (MainKindsModel *)mainKindForID:(NSInteger)kindID {
    // snapshot to avoid mutation while iterating
    NSArray<MainKindsModel *> *snapshot = [self.MainKindsArray copy];
    for (MainKindsModel *mk in snapshot) {
        if (mk.ID == kindID) {
            return mk;
        }
    }
    return nil;
}

- (NSArray<PPAccessoryCategoryModel *> *)accessoryCategoriesForMainKindID:(NSInteger)mainKindID {
    MainKindsModel *mainKind = [self mainKindForID:mainKindID];
    return mainKind.accessoryCategories ?: @[];
}

- (void)loadAccessoryCategoriesForMainKind:(MainKindsModel *)mainKind
                                completion:(void (^)(NSArray<PPAccessoryCategoryModel *> *categories, NSError * _Nullable error))completion
{
    if (!mainKind) {
        if (completion) completion(@[], [NSError errorWithDomain:@"arg" code:400 userInfo:@{NSLocalizedDescriptionKey:@"MainKind is missing"}]);
        return;
    }

    NSString *docID = mainKind.documentID.length ? mainKind.documentID : [NSString stringWithFormat:@"%ld", (long)mainKind.ID];
    if (docID.length == 0) {
        if (completion) completion(@[], [NSError errorWithDomain:@"arg" code:400 userInfo:@{NSLocalizedDescriptionKey:@"MainKind documentID is missing"}]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *mainDoc = [[db collectionWithPath:@"MainKindsCollection"] documentWithPath:docID];
    FIRCollectionReference *collection = [mainDoc collectionWithPath:@"accessoryCategoriesSubCollection"];

    [collection getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(mainKind.accessoryCategories ?: @[], error);
            return;
        }

        NSMutableArray<PPAccessoryCategoryModel *> *categories = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
            PPAccessoryCategoryModel *category = [[PPAccessoryCategoryModel alloc] initWithSnapshot:doc mainKindID:mainKind.ID];
            if (category.categoryID.length > 0 && category.enabled) {
                [categories addObject:category];
            }
        }

        [categories sortUsingComparator:^NSComparisonResult(PPAccessoryCategoryModel *a, PPAccessoryCategoryModel *b) {
            if (a.sortingKey != b.sortingKey) {
                return a.sortingKey < b.sortingKey ? NSOrderedAscending : NSOrderedDescending;
            }
            return [[a displayName] localizedCaseInsensitiveCompare:[b displayName]];
        }];

        mainKind.accessoryCategories = categories.mutableCopy;
        mainKind.didSeedAccessoryCategories = YES;
        if (completion) completion(categories.copy, nil);
    }];
}

- (void)pp_fillAccessoryCategoriesForMainKinds:(NSArray<MainKindsModel *> *)mainKinds completion:(dispatch_block_t)completion {
    if (mainKinds.count == 0) {
        if (completion) completion();
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    for (MainKindsModel *mainKind in mainKinds) {
        dispatch_group_enter(group);
        MainKindsModel *cachedKind = [self mainKindForID:mainKind.ID];
        [self loadAccessoryCategoriesForMainKind:mainKind completion:^(NSArray<PPAccessoryCategoryModel *> *categories, NSError * _Nullable error) {
            if (error && cachedKind.accessoryCategories.count > 0) {
                mainKind.accessoryCategories = cachedKind.accessoryCategories.mutableCopy;
                mainKind.didSeedAccessoryCategories = cachedKind.didSeedAccessoryCategories;
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion();
    });
}

/*///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

// MARK: - Subcollections API

/// Subcollections API
- (void)listenForSubKindsForMainKind:(MainKindsModel *)mainKind
                               block:(void (^)(NSArray<SubKindModel *> *subKinds, NSError *error))block
{
    if (!mainKind.documentID.length) {
        if (block) block(nil, [NSError errorWithDomain:@"arg" code:400 userInfo:@{NSLocalizedDescriptionKey:@"MainKind documentID is missing"}]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *mainDoc = [[db collectionWithPath:@"MainKindsCollection"] documentWithPath:mainKind.documentID];
    FIRQuery *q = [[mainDoc collectionWithPath:@"SubKinds"] queryOrderedByField:@"ID" descending:NO];

    __weak typeof(self) weakSelf = self;
    [q getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            if (block) block(nil, error);
            return;
        }
        if (!snapshot) {
            if (block) block(@[], nil);
            return;
        }

        NSMutableArray<SubKindModel *> *arr = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            SubKindModel *m = [[SubKindModel alloc] initWithSnapshot:doc];
            if (m) {
                m.MainKindID = mainKind.ID; // enforce linkage for UI
                [arr addObject:m];
            }
        }

        [arr sortUsingComparator:^NSComparisonResult(SubKindModel *a, SubKindModel *b) {
            if (a.ID < b.ID) return NSOrderedAscending;
            if (a.ID > b.ID) return NSOrderedDescending;
            return NSOrderedSame;
        }];

        // Keep it on the model (safe for existing UI that expects SubKindsArray)
        mainKind.SubKindsArray = arr.mutableCopy;
        mainKind.didSeedSubKinds = YES;

        if (block) block(arr, nil);
    }];
}

- (void)listenForSubSubKindsForMainKindID:(NSString *)mainKindDocID
                                  subKind:(SubKindModel *)subKind
                                    block:(void (^)(NSArray<subSubKindModel *> *subSubKinds, NSError *error))block
{
    if (!mainKindDocID.length || !subKind) {
        if (block) block(nil, [NSError errorWithDomain:@"arg" code:400 userInfo:@{NSLocalizedDescriptionKey:@"Invalid arguments"}]);
        return;
    }

    NSString *subDocID =        [NSString stringWithFormat:@"%ld", (long)subKind.ID];

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *subDoc = [[[[db collectionWithPath:@"MainKindsCollection"] documentWithPath:mainKindDocID]
                                     collectionWithPath:@"SubKinds"] documentWithPath:subDocID];

    FIRQuery *q = [[subDoc collectionWithPath:@"SubSubKinds"] queryOrderedByField:@"ID" descending:NO];

    __weak typeof(self) weakSelf = self;
    [q getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            if (block) block(nil, error);
            return;
        }
        if (!snapshot) {
            if (block) block(@[], nil);
            return;
        }

        NSMutableArray<subSubKindModel *> *arr = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            subSubKindModel *m = [[subSubKindModel alloc] initWithSnapshot:doc];
            if (m) {
                m.subKindID = subKind.ID;
                [arr addObject:m];
            }
        }

        [arr sortUsingComparator:^NSComparisonResult(subSubKindModel *a, subSubKindModel *b) {
            if (a.ID < b.ID) return NSOrderedAscending;
            if (a.ID > b.ID) return NSOrderedDescending;
            return NSOrderedSame;
        }];

        subKind.subSubKindArray = arr.mutableCopy;
        if (block) block(arr, nil);
    }];
}

- (void)listenForItemsForMainKindID:(NSString *)mainKindDocID
                          subKindID:(NSString *)subKindDocID
                         subSubKind:(subSubKindModel *)subSubKind
                              block:(void (^)(NSArray<subKindItemsModel *> *items, NSError *error))block
{
    if (!mainKindDocID.length || !subKindDocID.length || !subSubKind) {
        if (block) block(nil, [NSError errorWithDomain:@"arg" code:400 userInfo:@{NSLocalizedDescriptionKey:@"Invalid arguments"}]);
        return;
    }

    NSString *subSubDocID = [NSString stringWithFormat:@"%ld", (long)subSubKind.ID];

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *subSubDoc = [[[[[[db collectionWithPath:@"MainKindsCollection"] documentWithPath:mainKindDocID]
                                         collectionWithPath:@"SubKinds"] documentWithPath:subKindDocID]
                                       collectionWithPath:@"SubSubKinds"] documentWithPath:subSubDocID];

    FIRQuery *q = [[subSubDoc collectionWithPath:@"Items"] queryOrderedByField:@"ID" descending:NO];

    __weak typeof(self) weakSelf = self;
    [q getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            if (block) block(nil, error);
            return;
        }
        if (!snapshot) {
            if (block) block(@[], nil);
            return;
        }

        NSMutableArray<subKindItemsModel *> *arr = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            subKindItemsModel *m = [[subKindItemsModel alloc] initWithSnapshot:doc];
            if (m) {
                m.subSubKindID = subSubKind.ID;
                [arr addObject:m];
            }
        }

        [arr sortUsingComparator:^NSComparisonResult(subKindItemsModel *a, subKindItemsModel *b) {
            if (a.ID < b.ID) return NSOrderedAscending;
            if (a.ID > b.ID) return NSOrderedDescending;
            return NSOrderedSame;
        }];

        subSubKind.subKindItemsArray = arr.mutableCopy;
        if (block) block(arr, nil);
    }];
}

- (void)stopAllKindListeners {
    if (self.mainKindsListener) {
        [self.mainKindsListener remove];
        self.mainKindsListener = nil;
    }

    // Stop nested listeners
    for (MainKindsModel *mk in [self.MainKindsArray copy]) {
        if (mk.subKindsListener) {
            [mk.subKindsListener remove];
            mk.subKindsListener = nil;
        }
        for (SubKindModel *sk in [mk.SubKindsArray copy]) {
            if (sk.subSubKindsListener) {
                [sk.subSubKindsListener remove];
                sk.subSubKindsListener = nil;
            }
            for (subSubKindModel *ssk in [sk.subSubKindArray copy]) {
                if (ssk.subKindItemsListener) {
                    [ssk.subKindItemsListener remove];
                    ssk.subKindItemsListener = nil;
                }
            }
        }
    }
}
@end
