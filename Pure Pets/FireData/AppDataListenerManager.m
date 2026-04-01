//
//  AppDataListenerManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/12/2025.
//



#import "AppDataListenerManager.h"

@interface NSObject (PPSortDate)
@property (nonatomic, strong) NSDate *pp_sortDate;
@end

#import <objc/runtime.h>

@implementation NSObject (PPSortDate)

- (void)setPp_sortDate:(NSDate *)pp_sortDate {
    objc_setAssociatedObject(self, @selector(pp_sortDate), pp_sortDate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate *)pp_sortDate {
    return objc_getAssociatedObject(self, @selector(pp_sortDate));
}

@end

@interface AppDataListenerManager ()
@property (nonatomic, strong) id<FIRListenerRegistration> cardsListener;
@property (nonatomic, strong) id<FIRListenerRegistration> cagesListener;
@property (nonatomic, strong) id<FIRListenerRegistration> archiveListener;
@property (nonatomic, strong) id<FIRListenerRegistration> trashListener;
@property (nonatomic, strong) id<FIRListenerRegistration> salesListener;


@end



@implementation AppDataListenerManager

#pragma mark - Sorting Helpers

- (void)applySortDateIfNeeded:(NSObject *)obj
{
    if ([obj pp_sortDate]) return;

    if ([obj isKindOfClass:CardModel.class]) {
        obj.pp_sortDate = ((CardModel *)obj).AddedDate;
    }
    else if ([obj isKindOfClass:CageModel.class]) {
        obj.pp_sortDate = ((CageModel *)obj).CreateDate;
    }
    else if ([obj isKindOfClass:ArchiveModel.class]) {
        obj.pp_sortDate = ((ArchiveModel *)obj).archiveDate;
    }
    else if ([obj isKindOfClass:BuyerModel.class]) {
        obj.pp_sortDate = ((BuyerModel *)obj).sellDate;
    }
    else if ([obj isKindOfClass:TrashModel.class]) {
        obj.pp_sortDate = ((TrashModel *)obj).DeletedAt;
    }
}

- (void)sortArrayByDateDesc:(NSMutableArray *)array
{
    for (NSObject *obj in array) {
        [self applySortDateIfNeeded:obj];
    }

    [array sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {

        NSDate *d1 = [obj1 pp_sortDate];
        NSDate *d2 = [obj2 pp_sortDate];

        if (!d1 && !d2) {
            NSString *id1 = [obj1 respondsToSelector:@selector(ID)] ? [obj1 valueForKey:@"ID"] : @"";
            NSString *id2 = [obj2 respondsToSelector:@selector(ID)] ? [obj2 valueForKey:@"ID"] : @"";
            return [id1 compare:id2];
        }
        if (!d1) return NSOrderedDescending;
        if (!d2) return NSOrderedAscending;

        NSComparisonResult primary = [d2 compare:d1]; // newest first
        if (primary != NSOrderedSame) return primary;

        NSString *id1 = [obj1 respondsToSelector:@selector(ID)] ? [obj1 valueForKey:@"ID"] : @"";
        NSString *id2 = [obj2 respondsToSelector:@selector(ID)] ? [obj2 valueForKey:@"ID"] : @"";
        return [id1 compare:id2];
    }];
}

+ (instancetype)shared {
    static AppDataListenerManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [AppDataListenerManager new]; });
    return m;
}

- (void)pp_logFirestoreListenerError:(NSError *)error
                           collection:(NSString *)collection
{
    if (!error) {
        return;
    }

    NSString *message = [error.localizedDescription isKindOfClass:NSString.class]
        ? error.localizedDescription
        : @"Unknown error";
    NSString *reason = [error.userInfo[NSLocalizedFailureReasonErrorKey] isKindOfClass:NSString.class]
        ? error.userInfo[NSLocalizedFailureReasonErrorKey]
        : @"";
    NSString *combined = [NSString stringWithFormat:@"%@ %@", message, reason];
    NSString *combinedLower = [combined lowercaseString];

    BOOL isAppCheckRelated =
        [combinedLower containsString:@"app check"] ||
        [combinedLower containsString:@"appcheck"] ||
        [combinedLower containsString:@"app attest"] ||
        [combinedLower containsString:@"appattest"] ||
        [combinedLower containsString:@"devicecheck"];

    NSLog(@"[Firestore][%@] Listener error (%@/%ld): %@ | userInfo=%@",
          collection ?: @"Unknown",
          error.domain ?: @"UnknownDomain",
          (long)error.code,
          message,
          error.userInfo ?: @{});

    if (isAppCheckRelated) {
        NSLog(@"[AppCheck] Firestore listener for %@ was blocked. Verify App Check provider + debug token registration for this build/device.", collection ?: @"Unknown");
    }
}

- (void)handleCardsSnapshot:(FIRQuerySnapshot *)snapshot userID:(NSString *)userID {
    if (!snapshot) return;
    NSLog(@"Starting listeners for userID: %@", userID);
    // Map documents -> models in background to avoid blocking
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Create local variables to apply changes
        NSMutableArray<CardModel *> *all = self.AllCardsDocs ?: [NSMutableArray array];
        NSMutableDictionary<NSString *, CardModel *> *map = self.AllCardsByID ?: [NSMutableDictionary dictionary];

        // Ensure arrays are mutable copies
        all = [all mutableCopy];
        map = [map mutableCopy];

        // Build list of index updates for UI
        NSMutableArray<NSIndexPath *> *insertedIndexPaths = [NSMutableArray array];
        NSMutableArray<NSIndexPath *> *deletedIndexPaths = [NSMutableArray array];
        NSMutableArray<NSIndexPath *> *modifiedIndexPaths = [NSMutableArray array];

        for (FIRDocumentChange *change in snapshot.documentChanges) {
            FIRDocumentSnapshot *doc = change.document;
            CardModel *model = [[CardModel alloc] initWithSnapshot:doc];
            model.docID = doc.documentID;
            NSString *docID = doc.documentID;
            switch (change.type) {
                case FIRDocumentChangeTypeAdded: {
                    // Insert into ordered array at newIndex
                    NSUInteger idx = change.newIndex;
                    if (idx <= all.count) {
                        [all insertObject:model atIndex:idx];
                    } else {
                        [all addObject:model];
                        idx = all.count - 1;
                    }
                    map[docID] = model;
                    [insertedIndexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
                    // If belongs to user, add to UserCardsDocs
                    if ([model.UserID isEqualToString:userID]) {
                        NSMutableArray *user = self.UserCardsDocs ?: [NSMutableArray array];
                        [user addObject:model];
                        self.UserCardsDocs = user;
                    }
                    break;
                }
                case FIRDocumentChangeTypeModified: {
                    // Find existing model index by docID
                    CardModel *existing = map[docID];
                    if (existing) {
                        NSUInteger idx = [all indexOfObjectPassingTest:^BOOL(CardModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            return [obj.docID isEqualToString:docID];
                        }];
                        if (idx != NSNotFound) {
                            all[idx] = model;
                            [modifiedIndexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
                        }
                        map[docID] = model;
                    } else {
                        // If not found, treat as add
                        [all addObject:model];
                        map[docID] = model;
                        [insertedIndexPaths addObject:[NSIndexPath indexPathForItem:all.count-1 inSection:0]];
                    }
                    // Also update UserCardsDocs: add/remove depending on userID match
                    NSMutableArray *user = self.UserCardsDocs ?: [NSMutableArray array];
                    BOOL inUser = [user indexOfObjectPassingTest:^BOOL(CardModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        return [obj.docID isEqualToString:docID];
                    }] != NSNotFound;
                    BOOL shouldBeInUser = [model.UserID isEqualToString:userID];
                    if (!inUser && shouldBeInUser) [user addObject:model];
                    else if (inUser && !shouldBeInUser) {
                        NSUInteger uidx = [user indexOfObjectPassingTest:^BOOL(CardModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            return [obj.docID isEqualToString:docID];
                        }];
                        if (uidx != NSNotFound) [user removeObjectAtIndex:uidx];
                    } else if (inUser && shouldBeInUser) {
                        NSUInteger uidx = [user indexOfObjectPassingTest:^BOOL(CardModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            return [obj.docID isEqualToString:docID];
                        }];
                        if (uidx != NSNotFound) user[uidx] = model;
                    }
                    self.UserCardsDocs = user;
                    break;
                }
                case FIRDocumentChangeTypeRemoved: {
                    // Remove from all & map
                    NSUInteger idx = [all indexOfObjectPassingTest:^BOOL(CardModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        return [obj.docID isEqualToString:docID];
                    }];
                    if (idx != NSNotFound) {
                        [all removeObjectAtIndex:idx];
                        [deletedIndexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
                    }
                    [map removeObjectForKey:docID];

                    // Remove from user list if present
                    NSMutableArray *user = self.UserCardsDocs ?: [NSMutableArray array];
                    NSUInteger uidx = [user indexOfObjectPassingTest:^BOOL(CardModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        return [obj.docID isEqualToString:docID];
                    }];
                    if (uidx != NSNotFound) [user removeObjectAtIndex:uidx];
                    self.UserCardsDocs = user;
                    break;
                }
            } // switch
        } // for changes

        // Assign back to shared manager atomically
        self.AllCardsDocs = [all mutableCopy];
        self.AllCardsByID = [map mutableCopy];

        // Post notification on main thread with change info for collection view updates
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"cardsUpdatedWithDiffs"
             object:nil
             userInfo:@{
                 @"inserted": insertedIndexPaths ?: @[],
                 @"deleted": deletedIndexPaths ?: @[],
                 @"modified": modifiedIndexPaths ?: @[]
             }]; 
        });
    });
}


#pragma mark - Start All Listeners Once
- (void)startListenersForUser:(NSString *)userID {
    //userID = @"HW7N9Hx66qc27VekuUaUr4if9yz1";
    FIRFirestore *db = [FIRFirestore firestore];

    // --- Generic block for snapshot handling ---
    id (^mapAndFilter)(Class, FIRQuerySnapshot *, NSPredicate *) =
    ^id(Class modelClass, FIRQuerySnapshot *snapshot, NSPredicate *predicate) {

        if (![modelClass respondsToSelector:@selector(fromSnapshot:)]) return @[];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSMutableArray *arr = [modelClass performSelector:@selector(fromSnapshot:) withObject:snapshot];
#pragma clang diagnostic pop

        if (predicate)
            return [[arr filteredArrayUsingPredicate:predicate] mutableCopy];
        else
            return arr;
    };

    // ------------------------------------------------------------
    // CARDS
    // ------------------------------------------------------------
    self.cardsListener =
    [[db collectionWithPath:@"CardsCol"]
     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            [self pp_logFirestoreListenerError:error collection:@"CardsCol"];
            return;
        }
        [PPDeepLog logSnapshot:snapshot collectionName:@"CardsCol"];

        NSMutableArray *all = mapAndFilter(CardModel.class, snapshot, nil);
        if (!all) all = [NSMutableArray array];
        NSArray *filtered =
            [all filteredArrayUsingPredicate:
             [NSPredicate predicateWithFormat:@"UserID == %@ AND (isDeleted == 0 OR isDeleted == nil) AND (isSold == 0 OR isSold == nil)", userID]];

        // Invalidate pp_sortDate cache before sorting
        for (NSObject *obj in all) { obj.pp_sortDate = nil; }
        for (NSObject *obj in filtered) { obj.pp_sortDate = nil; }

        self.AllCardsDocs = all;
        self.UserCardsDocs = filtered.mutableCopy;

        [self sortArrayByDateDesc:self.AllCardsDocs];
        [self sortArrayByDateDesc:self.UserCardsDocs];

        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"cardsUpdated" object:nil];
        
        //[self handleCardsSnapshot:snapshot userID:userID];
    }];
    
    // ------------------------------------------------------------
    // CAGES
    // ------------------------------------------------------------
    // ------------------------------------------------------------
    // CAGES
    // ------------------------------------------------------------
    self.cagesListener =
    [[db collectionWithPath:@"CagesCol"]
     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            [self pp_logFirestoreListenerError:error collection:@"CagesCol"];
            return;
        }
        [PPDeepLog logSnapshot:snapshot collectionName:@"CagesCol"];

        // 1️⃣ Map ALL cages (deleted + not deleted)
        NSMutableArray *raw =
        mapAndFilter(CageModel.class, snapshot, nil);

        NSMutableArray<CageModel *> *allCages = [NSMutableArray array];

        for (id obj in raw) {
            if (![obj isKindOfClass:CageModel.class]) continue;
            if (![(CageModel *)obj UserID]) continue;   // critical
            [allCages addObject:obj];
        }

        // 2️⃣ Filter USER cages (ONLY not deleted)
        NSMutableArray<CageModel *> *userCages = [NSMutableArray array];

        for (CageModel *cage in allCages) {
            if (![cage.UserID isEqualToString:userID]) continue;
            if (cage.isDeleted == 1) continue;
            [userCages addObject:cage];
        }

        // 3️⃣ Invalidate sort cache
        for (NSObject *obj in allCages)  { obj.pp_sortDate = nil; }
        for (NSObject *obj in userCages) { obj.pp_sortDate = nil; }

        // 4️⃣ Assign
        self.caGeDocs  = allCages;
        self.UserCaGeDocs = userCages;

        // 5️⃣ Sort
        [self sortArrayByDateDesc:self.caGeDocs];
        [self sortArrayByDateDesc:self.UserCaGeDocs];

        // 6️⃣ Notify
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"cagesUpdated"
                          object:nil];
    }];

    // ------------------------------------------------------------
    // ARCHIVE
    // ------------------------------------------------------------
    // ------------------------------------------------------------
    // ARCHIVE
    // ------------------------------------------------------------
    self.archiveListener =
    [[db collectionWithPath:@"ArchiveCol"]
     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            [self pp_logFirestoreListenerError:error collection:@"ArchiveCol"];
            return;
        }
        [PPDeepLog logSnapshot:snapshot collectionName:@"ArchiveCol"];

      

        NSMutableArray<ArchiveModel *> *allArchives =
        mapAndFilter(ArchiveModel.class, snapshot, nil);
        if (!allArchives) allArchives = [NSMutableArray array];

        // 2️⃣ Filter user archives
        NSPredicate *byUser =
        [NSPredicate predicateWithFormat:@"archiveOwnerID == %@  AND (isDeleted == 0 OR isDeleted == nil)", userID];// AND (isDeleted == 0 OR isDeleted == nil)

        NSMutableArray<ArchiveModel *> *userArchives =
        [[allArchives filteredArrayUsingPredicate:byUser] mutableCopy];

        // 3️⃣ Invalidate sort cache
        for (NSObject *obj in allArchives)  { obj.pp_sortDate = nil; }
        for (NSObject *obj in userArchives) { obj.pp_sortDate = nil; }

        // 4️⃣ Assign
        self.AllArchivesDocs     = allArchives;
        self.UserArchivesDocs = userArchives;

        // 5️⃣ Sort
        [self sortArrayByDateDesc:self.AllArchivesDocs];
        [self sortArrayByDateDesc:self.UserArchivesDocs];

        // 6️⃣ Notify
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"archivesUpdated"
                          object:nil];
    }];

    // ------------------------------------------------------------
    // TRASH
    // ------------------------------------------------------------
    self.trashListener =
    [[[db collectionWithPath:@"TrashCol"]
      queryWhereField:@"ownerID" isEqualTo:userID]
     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            [self pp_logFirestoreListenerError:error collection:@"TrashCol"];
            return;
        }
        [PPDeepLog logSnapshot:snapshot collectionName:@"TrashCol"];

        NSMutableArray *allTrash =
            mapAndFilter(TrashModel.class, snapshot, nil);
        if (!allTrash) allTrash = [NSMutableArray array];

        // Invalidate pp_sortDate cache before sorting
        for (NSObject *obj in allTrash) { obj.pp_sortDate = nil; }

        self.trashDocs = allTrash;
        [self sortArrayByDateDesc:self.trashDocs];
       //NSLog(@"========================  allTrash %@ =================================\n\n",
         //     [self.trashDocs modelToJSONString]);
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"trashUpdated" object:nil];
    }];
    
    
    self.salesListener =
    [[[db collectionWithPath:@"BuyersCollection"]
       queryWhereField:@"UserID" isEqualTo:userID]
     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            [self pp_logFirestoreListenerError:error collection:@"BuyersCollection"];
            return;
        }

        [PPDeepLog logSnapshot:snapshot collectionName:@"BuyersCollection"];

        NSMutableArray *allSales =
        mapAndFilter(BuyerModel.class, snapshot, nil);
        if (!allSales) allSales = [NSMutableArray array];

        NSPredicate *notDeleted =
        [NSPredicate predicateWithFormat:@"isDeleted == 0 OR isDeleted == nil"];

        NSArray *filteredSales =
        [allSales filteredArrayUsingPredicate:notDeleted];

        // Invalidate pp_sortDate cache before sorting
        for (NSObject *obj in filteredSales) {
            obj.pp_sortDate = nil;
        }

        self.BuyerArray = filteredSales.mutableCopy;
        [self sortArrayByDateDesc:self.BuyerArray];

        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"salesUpdated" object:nil];
    }];
}


- (void)stopAllListeners {
    [self.cardsListener remove];
    [self.cagesListener remove];
    [self.archiveListener remove];
    [self.trashListener remove];
    [self.salesListener remove];
}
@end










@implementation PPDeepLog

+ (void)logSnapshot:(FIRQuerySnapshot *)snapshot
    collectionName:(NSString *)collection
{
    
    return;
#if DEBUG
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"HH:mm:ss.SSS";

    NSString *ts = [df stringFromDate:[NSDate date]];
    NSLog(@"\n================= 🔍 FIRESTORE DEEP LOG =================\n"
          @"🕒 Time: %@\n📚 Collection: %@\n📄 Document Count: %lu\n=========================================================\n",
          ts, collection, (unsigned long)snapshot.documents.count);

    // ---- SUMMARY -------------------------------------------------------
    NSUInteger addedCount = 0;
    NSUInteger modifiedCount = 0;
    NSUInteger removedCount = 0;

    for (FIRDocumentChange *change in snapshot.documentChanges) {
        switch (change.type) {
            case FIRDocumentChangeTypeAdded:     addedCount++; break;
            case FIRDocumentChangeTypeModified:  modifiedCount++; break;
            case FIRDocumentChangeTypeRemoved:   removedCount++; break;
        }
    }

    NSString *firstDocID = snapshot.documentChanges.count > 0 ?
                           snapshot.documentChanges.firstObject.document.documentID :
                           @"-";

    NSLog(@"SUMMARY → Added: %lu  Modified: %lu  Removed: %lu  | FirstChange: %@  | TotalChanges: %lu",
          (unsigned long)addedCount,
          (unsigned long)modifiedCount,
          (unsigned long)removedCount,
          firstDocID,
          (unsigned long)snapshot.documentChanges.count);

    
    NSLog(@"=========================================================\n\n");
#endif
}

@end


/*
 “Fix trash restore once and for all
 
 
 
 •    “Refactor MainController using everything you saved”
 •    “Fix trash restore once and for all”
 •    “Design a safe one-time healing runner”
 •    “Audit delete / restore flows”
 •    “Split responsibilities into managers”
 •    “Explain why index mismatch happens and eliminate it”
 
 
 
 
 Known Fragile Points (Now Remembered)

 These are not opinions — they are architectural facts now stored:
     1.    IndexPath mismatch
     •    Happens when:
     •    Data mutates before snapshot applied
     •    Trash restore fires before listener update
     2.    Delayed UI refresh
     •    When relying on notifications instead of snapshot diff
     •    Especially in Trash → Restore → immediate scroll
     3.    Child count drift
     •    Caused by:
     •    Restore/delete without sync
     •    Multiple listeners per cage
     4.    Helper overreach risk
     •    Must stay UI-only
     •    Never resolve data directly
 
 
 •    Refactor MainController safely
 •    Fix index mismatch crashes
 •    Redesign trash restore flow
 •    Optimize listeners and UI refresh
 •    Clean architecture pass (without breaking behavior)
 
 */
