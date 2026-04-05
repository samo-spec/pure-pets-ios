//
//  CagesManager 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/12/2025.
//


//
//  CagesManager.m
//  Pure Pets
//
//  Created by ChatGPT for Pure Pets.
//

#import "CagesManager.h"

@interface CagesManager ()
@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, strong) NSMutableDictionary *cagesById;
@end

@implementation CagesManager

+ (instancetype)sharedManager {
    static CagesManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [CagesManager new];
        mgr.db = [FIRFirestore firestore];
    });
    return mgr;
}

#pragma mark - Helpers

- (FIRCollectionReference *)cagesCollection {
    return [self.db collectionWithPath:@"CagesCol"];
}

- (FIRCollectionReference *)childsCollectionForCageID:(NSString *)cageID {
    return [[self.cagesCollection documentWithPath:cageID] collectionWithPath:@"ChildsCol"];
}

- (NSDictionary *)safeDictFromChild:(ChildModel *)child {
    NSDictionary *d = [child dictionaryRepresentation];
    if (!d) return @{};
    return d;
}

#pragma mark - Fetch Cages

- (void)fetchCagesForUserID:(NSString *)userID completion:(CagesArrayCompletion)completion {
    FIRCollectionReference *col = [self cagesCollection];
    FIRQuery *q = [[col queryWhereField:@"UserID" isEqualTo:userID] queryWhereField:@"isDeleted" isEqualTo:@0];
    [q getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }
            NSMutableArray<CageModel *> *result = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                CageModel *m = [[CageModel alloc] initWithSnapshot:doc];
                if (m) [result addObject:m];
            }
            completion(result, nil);
        });
    }];
}

- (id<FIRListenerRegistration>)listenToCagesForUserID:(NSString *)userID changeHandler:(CagesArrayCompletion)changeHandler {
    FIRCollectionReference *col = [self cagesCollection];
    FIRQuery *q = [[col queryWhereField:@"UserID" isEqualTo:userID] queryWhereField:@"isDeleted" isEqualTo:@0];
    id<FIRListenerRegistration> reg = [q addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                changeHandler(nil, error);
            });
            return;
        }
        NSMutableArray<CageModel *> *arr = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            CageModel *m = [[CageModel alloc] initWithSnapshot:doc];
            if (m) [arr addObject:m];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            changeHandler(arr, nil);
        });
    }];
    return reg;
}

#pragma mark - Childs

- (void)fetchChildsForCageID:(NSString *)cageID completion:(ChildsArrayCompletion)completion {
    if (!cageID) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], nil);
        });
        return;
    }
    FIRCollectionReference *col = [self childsCollectionForCageID:cageID];
    FIRQuery *q = [col queryWhereField:@"isDeleted" isEqualTo:@0];
    [q getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }
            NSMutableArray<ChildModel *> *arr = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                ChildModel *c = [[ChildModel alloc] initWithSnapshot:doc];
                if (c) [arr addObject:c];
            }
            completion(arr, nil);
        });
    }];
}

- (id<FIRListenerRegistration>)listenToChildsForCageID:(NSString *)cageID changeHandler:(ChildsArrayCompletion)changeHandler {
    if (!cageID) return nil;
    FIRCollectionReference *col = [self childsCollectionForCageID:cageID];
    id<FIRListenerRegistration> reg = [[col queryWhereField:@"isDeleted" isEqualTo:@0] addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                changeHandler(nil, error);
            });
            return;
        }
        NSMutableArray<ChildModel *> *arr = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            ChildModel *c = [[ChildModel alloc] initWithSnapshot:doc];
            if (c) [arr addObject:c];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            changeHandler(arr, nil);
        });
    }];
    return reg;
}

#pragma mark - Add / Update / Delete Child

- (void)addChild:(ChildModel *)child
       toCageID:(NSString *)cageID
      completion:(SingleChildCompletion)completion
{
    if (!child || !cageID.length || !child.ID.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion(nil, [NSError errorWithDomain:@"CagesManager"
                                                    code:400
                                                userInfo:@{NSLocalizedDescriptionKey:@"Invalid child or missing ID"}]);
        });
        return;
    }

    FIRDocumentReference *docRef =
    [[self childsCollectionForCageID:cageID] documentWithPath:child.ID];

    NSMutableDictionary *dict = [[child dictionaryRepresentation] mutableCopy];
    dict[@"CageID"] = cageID;
    dict[@"addingDate"] =
        [FIRTimestamp timestampWithDate:child.addingDate ?: [NSDate date]];
    dict[@"isDeleted"] = @(child.isDeleted);

    [docRef setData:dict completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(child, error);
        });
    }];
}

- (void)updateChild:(ChildModel *)child completion:(VoidWithError)completion
{
    if (!child.ID.length || !child.CageID.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion([NSError errorWithDomain:@"CagesManager"
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey:@"Missing IDs"}]);
        });
        return;
    }

    FIRDocumentReference *docRef =
    [[self childsCollectionForCageID:child.CageID] documentWithPath:child.ID];

    NSMutableDictionary *dict =
        [[child dictionaryRepresentation] mutableCopy];

    dict[@"addingDate"] =
        [FIRTimestamp timestampWithDate:child.addingDate ?: [NSDate date]];
    dict[@"isDeleted"] = @(child.isDeleted);

    [docRef setData:dict merge:YES completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

- (void)softDeleteChild:(ChildModel *)child completion:(VoidWithError)completion {
    if (!child || child.ID.length == 0 || child.CageID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([NSError errorWithDomain:@"CagesManager" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Invalid child or missing IDs"}]);
        });
        return;
    }
    FIRDocumentReference *docRef = [[self childsCollectionForCageID:child.CageID] documentWithPath:child.ID];
    [docRef updateData:@{@"isDeleted": @1} completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

- (void)deleteChildDocument:(ChildModel *)child completion:(VoidWithError)completion {
    if (!child || child.ID.length == 0 || child.CageID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([NSError errorWithDomain:@"CagesManager" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Invalid child or missing IDs"}]);
        });
        return;
    }
    FIRDocumentReference *docRef = [[self childsCollectionForCageID:child.CageID] documentWithPath:child.ID];
    [docRef deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

#pragma mark - Move child between cages

- (void)moveChild:(ChildModel *)child
         toCageID:(NSString *)targetCageID
       completion:(VoidWithError)completion
{
    if (!child || !child.ID.length || !child.CageID.length || !targetCageID.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion([NSError errorWithDomain:@"CagesManager"
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey:@"Invalid params"}]);
        });
        return;
    }

    FIRWriteBatch *batch = [self.db batch];

    // OLD child → Away
    FIRDocumentReference *oldRef =
    [[self childsCollectionForCageID:child.CageID]
     documentWithPath:child.ID];

    [batch updateData:@{
        @"childBox": @(ChildBoxAway),
        @"childBoxID": targetCageID
    } forDocument:oldRef];

    // NEW child → Guest
    NSString *newChildID =
    [NSString stringWithFormat:@"%@_%@",
     child.UserID,
     @(NSDate.date.timeIntervalSince1970)];

    ChildModel *guest = [ChildModel new];
    guest.ID = newChildID;
    guest.CageID = targetCageID;
    guest.CardID = child.CardID;
    guest.ChildRingID = child.ChildRingID;
    guest.UserID = child.UserID;
    guest.childBox = ChildBoxGuest;
    guest.childBoxID = child.CageID;
    guest.addingDate = [NSDate date];
    guest.lastUpdated = [NSDate date];

    FIRDocumentReference *newRef =
    [[self childsCollectionForCageID:targetCageID]
     documentWithPath:newChildID];

    [batch setData:[guest dictionaryRepresentation]
        forDocument:newRef];

    // COMMIT
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

#pragma mark - Update Cage

- (void)updateCage:(CageModel *)cage completion:(VoidWithError)completion {
    if (!cage || cage.ID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([NSError errorWithDomain:@"CagesManager" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Invalid cage"}]);
        });
        return;
    }
    FIRDocumentReference *docRef = [[self cagesCollection] documentWithPath:cage.ID];
    // Build dict from cageModel (you can refine to only changed fields)
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (cage.CageName) dict[@"CageName"] = cage.CageName;
    if (cage.FatherRingID) dict[@"FatherRingID"] = cage.FatherRingID;
    if (cage.MotherRingID) dict[@"MotherRingID"] = cage.MotherRingID;
    dict[@"isDeleted"] = @(cage.isDeleted);
    if (cage.ReminderDate) dict[@"ReminderDate"] = [FIRTimestamp timestampWithDate:cage.ReminderDate];
    if (cage.FristEggDate) dict[@"FristEggDate"] = [FIRTimestamp timestampWithDate:cage.FristEggDate];

    [docRef setData:dict merge:YES completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}


// CagesManager.m
- (id<FIRListenerRegistration>)listenForCageWithID:(NSString *)cageID
                                          onChange:(void (^)(CageModel *cage))onChange
{
    FIRFirestore *db = [FIRFirestore firestore];

    id<FIRListenerRegistration> registration =
    [[[db collectionWithPath:@"CagesCol"]
      documentWithPath:cageID]
     addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {

        if (error || !snapshot.exists) return;

        CageModel *updatedCage =
        [[CageModel alloc] initWithSnapshot:snapshot];

        // Update AppData (replace, do NOT mutate silently)
        [[CagesManager sharedManager] upsertCage:updatedCage];

        if (onChange) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onChange(updatedCage);
            });
        }
    }];
    return registration;
}

// Disallow direct init to enforce singleton usage.
- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Use +[CagesManager shared] instead of -init"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _cagesById = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)upsertCage:(CageModel *)cage {
    if (cage == nil) { return; }

    // Adjust this to match your CageModel's identifier property.
    // Common names: cageId, identifier, uid, objectId, etc.
    NSString *identifier = nil;
    if ([cage respondsToSelector:@selector(ID)]) {
        identifier = [cage valueForKey:@"cageId"];
    } else if ([cage respondsToSelector:@selector(identifier)]) {
        identifier = [cage valueForKey:@"identifier"];
    } else if ([cage respondsToSelector:@selector(uid)]) {
        identifier = [cage valueForKey:@"uid"];
    }

    // Fallback: if no identifier is available, you may decide to skip or assert.
    if (identifier.length == 0) {
        // TODO: Replace with your app's identifier field or error handling.
        // For now, we’ll just return to avoid inserting an unkeyed model.
        return;
    }

    // Replace existing or insert new.
    @synchronized (self) {
        self.cagesById[identifier] = cage;
    }

    // If you maintain derived arrays, notifications, or persistence,
    // trigger them here. For example:
    // [self persistCagesIfNeeded];
    // [[NSNotificationCenter defaultCenter] postNotificationName:CagesManagerDidChangeNotification object:self];
}
@end
