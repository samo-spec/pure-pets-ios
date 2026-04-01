//
//  ArchiveManager.m
//  Pure Pets
//

#import "ArchivesManager.h"
#import "ArchiveModel.h"
#import "ArchiveDetailsModel.h"

@implementation ArchivesManager {
    FIRFirestore *_db;
    NSMutableDictionary<NSString *, NSArray<ArchiveDetailsModel *> *> *_archiveDetailsCache;
}


- (void)restoreArchiveDetail:(ArchiveDetailsModel *)detail cageID:(NSString *)cageID completion:(void (^)(NSError * _Nullable))completion
{
    if (!detail || !detail.ID.length || !detail.CardID.length || !cageID.length) {
        if (completion) completion([NSError errorWithDomain:@"ArchiveRestore"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Invalid restore params"}]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRWriteBatch *batch = [db batch];

    // 1️⃣ ArchiveDetail → deleted
    FIRDocumentReference *detailRef =
    [[[[db collectionWithPath:@"ArchiveCol"]
       documentWithPath:detail.masterArchiveID]
      collectionWithPath:@"ArchiveDetailsCol"]
     documentWithPath:detail.ID];

    [batch updateData:@{@"isDeleted": @1}
          forDocument:detailRef];

    // 2️⃣ Restore Card
    FIRDocumentReference *cardRef =
    [[db collectionWithPath:@"CardsCol"]
     documentWithPath:detail.CardID];

    [batch updateData:@{
        @"CardLocation": @"cage",
        @"cardSection": @(CardSectionCage),
        @"archiveID": [NSNull null],
        @"masterArchiveID": [NSNull null]
    } forDocument:cardRef];

    // 3️⃣ Restore Child
    FIRDocumentReference *childRef =
    [[[[db collectionWithPath:@"CagesCol"]
       documentWithPath:cageID]
      collectionWithPath:@"ChildsCol"]
     documentWithPath:detail.CardID]; // childID == cardID relation

    [batch updateData:@{
        @"archiveID": [NSNull null],
        @"masterArchiveID": [NSNull null]
    } forDocument:childRef];

    // COMMIT
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}




- (NSArray<ArchiveDetailsModel *> *)cachedArchiveDetailsForArchiveID:(NSString *)archiveID
{
    if (!archiveID.length) return @[];
    return _archiveDetailsCache[archiveID] ?: @[];
}

// Returns an ArchiveModel from cache by archiveID, or nil if not found.
- (ArchiveModel * _Nullable)archiveByID:(NSString *)archiveID
{
    if (!archiveID.length) {
        NSLog(@"⚠️ [archiveByID] Empty archiveID");
        return nil;
    }

    // Try in-memory cache first (derived from fetched archives if any)
         NSArray<ArchiveModel *> *cached =AppData.AllArchivesDocs;
        for (ArchiveModel *ar in cached) {
            if ([ar.ID isEqualToString:archiveID]) {
                NSLog(@"✅ [archiveByID] FOUND in cache | %@", archiveID);
                return ar;
            }
        }
 
    // Fallback: fetch directly from Firestore synchronously is NOT allowed here.
    // Caller should use async fetch if nil is returned.
    NSLog(@"🌐 [archiveByID] Cache MISS | %@", archiveID);
    return nil;
}

- (void)archiveDetailByID:(NSString *)detailID
               completion:(void(^)(ArchiveDetailsModel * _Nullable detail))completion
{
    if (!detailID.length) {
        NSLog(@"⚠️ [ArchiveDetailByID] Empty detailID");
        if (completion) completion(nil);
        return;
    }

    NSLog(@"🔍 [ArchiveDetailByID] Looking for detailID: %@", detailID);

    // 1️⃣ Try cache first
    if (_archiveDetailsCache.count == 0) {
        NSLog(@"📦 [ArchiveDetailByID] Cache is EMPTY");
    } else {
        NSLog(@"📦 [ArchiveDetailByID] Cache keys: %@", _archiveDetailsCache.allKeys);
    }

    for (NSArray<ArchiveDetailsModel *> *details in _archiveDetailsCache.allValues) {
        for (ArchiveDetailsModel *detail in details) {
            if ([detail.ID isEqualToString:detailID]) {
                NSLog(@"✅ [ArchiveDetailByID] FOUND in cache | archiveID=%@", detail.masterArchiveID);
                if (completion) completion(detail);
                return;
            }
        }
    }

    NSLog(@"🌐 [ArchiveDetailByID] Cache MISS → Firestore collectionGroup query");

    // 2️⃣ Fallback: collectionGroup query
    FIRFirestore *db = [FIRFirestore firestore];

    [[[db collectionGroupWithID:@"ArchiveDetailsCol"]
      queryWhereField:@"ID" isEqualTo:detailID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            NSLog(@"❌ [ArchiveDetailByID] Firestore error: %@", error);
            if (completion) completion(nil);
            return;
        }

        if (snapshot.documents.count == 0) {
            NSLog(@"❌ [ArchiveDetailByID] NOT FOUND in Firestore | detailID=%@", detailID);
            if (completion) completion(nil);
            return;
        }

        FIRDocumentSnapshot *doc = snapshot.documents.firstObject;
        ArchiveDetailsModel *detail =
        [[ArchiveDetailsModel alloc] initWithSnapshot:doc];

        NSLog(@"✅ [ArchiveDetailByID] FOUND in Firestore | archiveID=%@ detailID=%@",
              detail.masterArchiveID,
              detail.ID);

        // 3️⃣ Cache it for next time
        NSString *archiveID = detail.masterArchiveID;
        if (archiveID.length) {

            NSMutableArray *arr =
            [self->_archiveDetailsCache[archiveID] mutableCopy] ?: [NSMutableArray array];

            [arr addObject:detail];
            self->_archiveDetailsCache[archiveID] = arr;

            NSLog(@"📌 [ArchiveDetailByID] Cached detail under archiveID=%@ (count=%lu)",
                  archiveID,
                  (unsigned long)arr.count);
        } else {
            NSLog(@"⚠️ [ArchiveDetailByID] detail.masterArchiveID is EMPTY");
        }

        if (completion) completion(detail);
    }];
}

- (ArchiveDetailsModel *)cachedArchiveDetailByID:(NSString *)detailID
{
    NSLog(@"detail ID  %@ ----- %@",detailID,self.archiveDetailsCache.allValues);
    if (!detailID.length) return nil;
   
    for (NSArray<ArchiveDetailsModel *> *details in self.archiveDetailsCache.allValues) {
        for (ArchiveDetailsModel *detail in details) {
            NSLog(@"detail ID %@  ----- %@",detail.ID,detailID);
            if ([detail.ID isEqualToString:detailID]) {
                return detail;
            }
        }
    }
    return nil;
}

+ (instancetype)shared {
    static ArchivesManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[ArchivesManager alloc] initPrivate];
    });
    return mgr;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _db = [FIRFirestore firestore];
        _archiveDetailsCache = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Archives

- (void)fetchArchivesForUserID:(NSString *)userID
                    completion:(void(^)(NSArray<ArchiveModel *> *archives,
                                         NSError * _Nullable error))completion
{
    [[[[_db collectionWithPath:@"ArchiveCol"]
      queryWhereField:@"archiveOwnerID" isEqualTo:userID]
     queryWhereField:@"isDeleted" isEqualTo:@0]
    getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }

        NSMutableArray *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            ArchiveModel *ar = [[ArchiveModel alloc] initWithSnapshot:doc];
            [result addObject:ar];
        }

        if (completion) completion(result, nil);
    }];
}

- (void)removeArchiveDetailsByCardID:(NSString *)cardID
                          completion:(void(^)(NSError * _Nullable error))completion
{
    FIRFirestore *db = [FIRFirestore firestore];

    [[[db collectionGroupWithID:@"ArchiveDetailsCol"]
     queryWhereField:@"CardID" isEqualTo:cardID]
    getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            if (completion) completion(error);
            return;
        }

        if (snapshot.documents.count == 0) {
            if (completion) completion(nil);
            return;
        }

        FIRWriteBatch *batch = [db batch];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            FIRDocumentReference *ref = doc.reference;
            [batch updateData:@{ @"isDeleted": @1 } forDocument:ref];
        }

        [batch commitWithCompletion:^(NSError * _Nullable commitError) {
            if (completion) completion(commitError);
        }];
    }];
}

#pragma mark - Archive Details

- (void)fetchArchiveDetailsForArchiveID:(NSString *)archiveID
                             completion:(void(^)(NSArray<ArchiveDetailsModel *> *details,
                                                  NSError * _Nullable error))completion
{
    if (!archiveID.length) {
        if (completion) completion(@[], nil);
        return;
    }
    NSLog(@"fetchArchiveDetailsForArchiveID");
    
    __weak typeof(_archiveDetailsCache) weakArchiveDetailsCache = _archiveDetailsCache;
    [[[[_db collectionWithPath:@"ArchiveCol"]
      documentWithPath:archiveID]
     collectionWithPath:@"ArchiveDetailsCol"]
    getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }
        __strong typeof(weakArchiveDetailsCache) _archiveDetailsCache = weakArchiveDetailsCache;

        NSMutableArray *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            ArchiveDetailsModel *det =
            [[ArchiveDetailsModel alloc] initWithSnapshot:doc];
            [result addObject:det];
        }

        // 🔥 CACHE IT
        _archiveDetailsCache[archiveID] = result.copy;

        if (completion) completion(result, nil);
    }];
}

#pragma mark - Add / Move / Delete

- (void)addCardToArchiveID:(NSString *)archiveID
                    cardID:(NSString *)cardID
                    userID:(NSString *)userID
                    cageID:(nullable NSString *)cageID
                completion:(void(^)(NSError * _Nullable error))completion
{
    NSString *detailID =
    [NSString stringWithFormat:@"DET_%@_%@",
     userID,
     @((long long)(NSDate.date.timeIntervalSince1970 * 1000))];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"masterArchiveID"] = archiveID;
    data[@"CardID"] = cardID;
    data[@"UserID"] = userID;
    data[@"cardArchiveDate"] = [FIRTimestamp timestampWithDate:[NSDate date]];
    data[@"isDeleted"] = @0;

    if (cageID.length) {
        data[@"CageID"] = cageID;
    }

    FIRDocumentReference *ref =
    [[[[_db collectionWithPath:@"ArchiveCol"]
      documentWithPath:archiveID]
     collectionWithPath:@"ArchiveDetailsCol"]
    documentWithPath:detailID];

    [ref setData:data completion:^(NSError * _Nullable error) {
        [ArchivesManager.shared syncDetailsCountForArchiveID:archiveID];
        if (completion) completion(error);
    }];
}

- (void)moveArchiveDetail:(ArchiveDetailsModel *)detail
            toArchiveID:(NSString *)newArchiveID
              completion:(void(^)(NSError * _Nullable error))completion
{
    FIRWriteBatch *batch = [_db batch];

    FIRDocumentReference *oldRef =
    [[[[_db collectionWithPath:@"ArchiveCol"]
      documentWithPath:detail.masterArchiveID]
     collectionWithPath:@"ArchiveDetailsCol"]
    documentWithPath:detail.ID];

    FIRDocumentReference *newRef =
    [[[[_db collectionWithPath:@"ArchiveCol"]
      documentWithPath:newArchiveID]
     collectionWithPath:@"ArchiveDetailsCol"]
    documentWithPath:detail.ID];

    NSMutableDictionary *dict = [[detail toDictionary] mutableCopy];
    dict[@"masterArchiveID"] = newArchiveID;

    [batch deleteDocument:oldRef];
    [batch setData:dict forDocument:newRef];

    [batch commitWithCompletion:^(NSError * _Nullable error) {
        [self syncDetailsCountForArchiveID:detail.masterArchiveID];
        if (completion) completion(error);
    }];
}

- (void)deleteArchiveDetail:(ArchiveDetailsModel *)detail
                 completion:(void(^)(NSError * _Nullable error))completion
{
    // Safety
    if (!detail.ID.length || !detail.masterArchiveID.length) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];

    FIRDocumentReference *detailRef =
    [[[[db collectionWithPath:@"ArchiveCol"]
        documentWithPath:detail.masterArchiveID]
      collectionWithPath:@"ArchiveDetailsCol"]
     documentWithPath:detail.ID];

    FIRDocumentReference *trashRef =
    [[db collectionWithPath:@"TrashCol"] documentWithAutoID];

    NSDictionary *trashData = @{
        @"ID": trashRef.documentID,
        @"RefID": detail.ID,
        @"RefType": @(RefTypeArchive),
        @"ownerID": detail.UserID ?: @"",
        @"archiveID": detail.ID,
        @"masterArchiveID": detail.masterArchiveID,
        @"CardID": detail.CardID ?: @"",
        @"DeletedAt": [NSDate date],
        @"isDeleted": @1
    };

    FIRWriteBatch *batch = [db batch];

    // 1️⃣ Mark archive detail deleted
    [batch updateData:@{ @"isDeleted": @1 }
         forDocument:detailRef];

    // 2️⃣ Add to TrashCol
    [batch setData:trashData
       forDocument:trashRef];

    [batch commitWithCompletion:^(NSError * _Nullable error) {

        if (!error) {
            [self syncDetailsCountForArchiveID:detail.masterArchiveID];
        }

        if (completion) completion(error);
    }];
}

- (void)restoreArchiveDetail:(ArchiveDetailsModel *)detail
                  completion:(void(^)(NSError * _Nullable error))completion
{
    if (!detail.ID.length || !detail.masterArchiveID.length) {
        NSLog(@"❌ restoreArchiveDetail failed: missing IDs | detailID=%@ masterArchiveID=%@",
              detail.ID, detail.masterArchiveID);
        if (completion) completion(nil);
        return;
    }

    FIRDocumentReference *ref =
    [[[[_db collectionWithPath:@"ArchiveCol"]
       documentWithPath:detail.masterArchiveID]
      collectionWithPath:@"ArchiveDetailsCol"]
     documentWithPath:detail.ID];

    [ref updateData:@{ @"isDeleted": @0 }
         completion:^(NSError * _Nullable error)
    {
        if (!error) {
            [self syncDetailsCountForArchiveID:detail.masterArchiveID];
        }
        if (completion) completion(error);
    }];
}


- (void)fetchArchiveDetailsForCardID:(NSString *)cardID
                          completion:(void(^)(NSArray<ArchiveDetailsModel *> *details,
                                               NSError * _Nullable error))completion
{
    FIRFirestore *db = [FIRFirestore firestore];

    [[[db collectionGroupWithID:@"ArchiveDetailsCol"]
     queryWhereField:@"CardID" isEqualTo:cardID]
    getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }

        NSMutableArray *result = [NSMutableArray array];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            ArchiveDetailsModel *detail =
            [[ArchiveDetailsModel alloc] initWithSnapshot:doc];
            [result addObject:detail];
        }

        if (completion) completion(result, nil);
    }];
}


- (void)softDeleteArchiveByID:(NSString *)archiveID
                   completion:(void(^)(NSError * _Nullable error))completion
{
    if (!archiveID.length) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *archiveRef =
    [[db collectionWithPath:@"ArchiveCol"] documentWithPath:archiveID];

    [archiveRef updateData:@{
        @"isDeleted": @1,
        @"DeletedAt": [NSDate date]
    } completion:^(NSError * _Nullable error) {

        if (completion) completion(error);
    }];
}
- (void)addCard:(NSString *)cardID
          child:(ChildModel * _Nullable)child
      toArchive:(NSString *)archiveID
        ownerID:(NSString *)ownerID
     completion:(void(^)(NSError * _Nullable error))completion
{
    if (!cardID.length || !archiveID.length) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];

    // ===============================
    // 1️⃣ Create ArchiveDetails
    // ===============================
    NSString *archiveDetailsID =
    [NSString stringWithFormat:@"AD_%@", NSUUID.UUID.UUIDString];

    FIRDocumentReference *archiveDetailsRef =
    [[[[db collectionWithPath:@"ArchiveCol"]
       documentWithPath:archiveID]
      collectionWithPath:@"ArchiveDetailsCol"]
     documentWithPath:archiveDetailsID];

    NSDictionary *archiveDetailsData = @{
        @"ID"              : archiveDetailsID,
        @"CardID"          : cardID,
        @"UserID"          : ownerID,
        @"masterArchiveID": archiveID,
        @"cardArchiveDate" : [FIRTimestamp timestampWithDate:NSDate.date],
        @"isDeleted"       : @0,
        @"isSold": @0,
    };
  

    // ===============================
    // 2️⃣ Prepare batch
    // ===============================
    FIRWriteBatch *batch = db.batch;

    // ArchiveDetails
    [batch setData:archiveDetailsData
       forDocument:archiveDetailsRef];

    // ===============================
    // 3️⃣ Update Card
    // ===============================
    FIRDocumentReference *cardRef =
    [[db collectionWithPath:@"CardsCol"]
     documentWithPath:cardID];

    [batch updateData:@{
        @"archiveID"       : archiveDetailsID,
        @"masterArchiveID" : archiveID,
        @"isDeleted"       : @0,
        @"cardSection"     : @(CardSectionArchive),
        @"CardLocation"    : @"archive",
    } forDocument:cardRef];

    // ===============================
    // 4️⃣ Update Child (🔥 MOVED HERE)
    // ===============================
    if (child) {

        FIRDocumentReference *childRef =
        [[[[db collectionWithPath:@"CagesCol"]
           documentWithPath:child.CageID]
          collectionWithPath:@"ChildsCol"]
         documentWithPath:child.ID];

        [batch updateData:@{
            @"childBox"        : @(ChildBoxAway),
            @"childBoxID"      : archiveDetailsID,
            @"archiveID"       : archiveDetailsID,
            @"masterArchiveID" : archiveID
        } forDocument:childRef];
    }

    // ===============================
    // 5️⃣ Commit
    // ===============================
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}


 

- (void)updateCardLocationToArchive:(NSString *)cardID
                          archiveID:(NSString *)archiveID
                    masterArchiveID:(NSString *)masterArchiveID
{
    FIRFirestore *db = [FIRFirestore firestore];

    [[[db collectionWithPath:@"CardsCol"]
      documentWithPath:cardID]
     updateData:@{
        @"cardSection": @(CardSectionArchive),
        @"CardLocation": @"archive",
        @"archiveID": archiveID ?: @"",
        @"masterArchiveID": masterArchiveID ?: @""
     }];
}


- (void)syncDetailsCountForArchiveID:(NSString *)archiveID
{
    if (!archiveID.length) return;

    FIRFirestore *db = [FIRFirestore firestore];

    FIRCollectionReference *detailsRef =
    [[[db collectionWithPath:@"ArchiveCol"]
         documentWithPath:archiveID] collectionWithPath:@"ArchiveDetailsCol" ];

    [[detailsRef queryWhereField:@"isDeleted" isEqualTo:@0]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            NSLog(@"syncDetailsCount error: %@", error);
            return;
        }

        NSInteger count = snapshot.documents.count;

        [[[db collectionWithPath:@"ArchiveCol"]
          documentWithPath:archiveID]
         updateData:@{
            @"detailsCount": @(count)
         }];
    }];
}
@end
