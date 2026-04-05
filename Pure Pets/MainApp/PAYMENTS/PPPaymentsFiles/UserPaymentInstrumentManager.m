//
//  UserPaymentInstrumentManager.m
//  PurePets
//

#import "UserPaymentInstrumentManager.h"
#import "PPFirestoreErrorNotifier.h"
 
@interface UserPaymentInstrumentManager ()
@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, strong) NSMutableArray<UserPaymentInstrument *> *instruments;
@end

@implementation UserPaymentInstrumentManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static UserPaymentInstrumentManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] initPrivate];
    });
    return shared;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        _db = [FIRFirestore firestore];
        _instruments = [NSMutableArray array];
        NSLog(@"🪄 UserPaymentInstrumentManager initialized with Firestore instance");
    }
    return self;
}

#pragma mark - Utility

- (NSArray<UserPaymentInstrument *> *)cachedInstruments {
    return [self.instruments copy];
}

- (void)stopListening {
    if (self.listener) {
        NSLog(@"🛑 Stopping listener for payment instruments");
        [self.listener remove];
        self.listener = nil;
    }
}

#pragma mark - LISTEN FOR CHANGES (Realtime)

- (void)listenForInstrumentsForUser:(NSString *)userID
                         completion:(void(^)(NSArray<UserPaymentInstrument *> * _Nullable instruments,
                                             NSError * _Nullable error))completion {
    if (userID.length == 0) {
        NSLog(@"⚠️ Missing userID for listenForInstruments");
        if (completion) completion(@[], nil);
        return;
    }

    [self stopListening];

    FIRCollectionReference *ref = [[[_db collectionWithPath:@"UsersCol"]
                                    documentWithPath:userID]
                                    collectionWithPath:@"paymentInstruments"];

    NSLog(@"🎧 Listening for payment instruments for user %@", userID);

    // U4: Prevent retain cycle in payment instruments listener
    __weak typeof(self) weakSelf = self;
    self.listener = [ref addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            NSLog(@"❌ Firestore listener error: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextPaymentInstrumentListener];
            if (completion) completion(nil, error);
            return;
        }

        NSMutableArray<UserPaymentInstrument *> *instruments = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSDictionary *data = doc.data;
            if (!data) continue;

            UserPaymentInstrument *inst = [[UserPaymentInstrument alloc] initWithDictionary:data];
            inst.instrumentID = doc.documentID;
            inst.userID = userID;
            [instruments addObject:inst];
        }

        NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO];
        [instruments sortUsingDescriptors:@[sort]];
        strongSelf.instruments = instruments;

        NSLog(@"✅ Realtime update: %lu instruments", (unsigned long)instruments.count);
        if (completion) completion(instruments, nil);
    }];
}

#pragma mark - FETCH (Once)

- (void)fetchInstrumentsForUser:(NSString *)userID
                     completion:(void (^)(NSArray<UserPaymentInstrument *> *, NSError *))completion {
    if (userID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }

    NSString *path = [NSString stringWithFormat:@"UsersCol/%@/paymentInstruments", userID];
    NSLog(@"📦 Fetching instruments once from %@", path);

    [[_db collectionWithPath:path] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Firestore fetch error: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextPaymentInstrumentFetch];
            if (completion) completion(nil, error);
            return;
        }

        NSMutableArray<UserPaymentInstrument *> *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSDictionary *data = doc.data;
            if (!data) continue;

            UserPaymentInstrument *inst = [[UserPaymentInstrument alloc] initWithDictionary:data];
            inst.instrumentID = doc.documentID;
            inst.userID = userID;
            [result addObject:inst];
        }

        self.instruments = result;
        NSLog(@"✅ Fetched %lu instruments for user %@", (unsigned long)result.count, userID);
        completion(result, nil);
    }];
}

#pragma mark - ADD Instrument

- (void)addInstrument:(UserPaymentInstrument *)instrument
              forUser:(NSString *)userID
           completion:(void (^)(BOOL, NSError *))completion {

    if (!instrument || userID.length == 0) {
        NSLog(@"⚠️ Invalid instrument or userID in addInstrument");
        if (completion) completion(NO, nil);
        return;
    }

    FIRTimestamp *now = [FIRTimestamp timestamp];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"userID"] = userID;
    dict[@"methodID"] = instrument.methodID ?: @"";
    dict[@"maskedDetails"] = instrument.maskedDetails ?: @"";
    dict[@"isDefault"] = @(instrument.isDefault);
    dict[@"metaData"] = instrument.metaData ?: @{};
    dict[@"originalData"] = instrument.originalData ?: @{};
    dict[@"createdAt"] = now;
    dict[@"updatedAt"] = now;

    NSString *path = [NSString stringWithFormat:@"UsersCol/%@/paymentInstruments", userID];
    FIRCollectionReference *ref = [_db collectionWithPath:path];

    NSLog(@"📝 Adding new payment instrument for user %@ (methodID=%@)", userID, instrument.methodID);

    FIRDocumentReference *createdRef = [ref addDocumentWithData:dict completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to add instrument: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextPaymentInstrumentAdd];
            if (completion) completion(NO, error);
            return;
        }
        NSLog(@"✅ Successfully added instrument %@ for %@", instrument.methodID, userID);
        if (completion) completion(YES, nil);
    }];
    instrument.instrumentID = createdRef.documentID ?: instrument.instrumentID;
}

#pragma mark - SET Default Instrument

- (void)setDefaultInstrument:(UserPaymentInstrument *)instrument
                     forUser:(NSString *)userID
                  completion:(void (^)(BOOL, NSError *))completion {
    if (userID.length == 0 || !instrument) {
        NSLog(@"⚠️ Missing userID or instrument in setDefaultInstrument");
        if (completion) completion(NO, nil);
        return;
    }

    NSString *path = [NSString stringWithFormat:@"UsersCol/%@/paymentInstruments", userID];
    FIRCollectionReference *col = [_db collectionWithPath:path];

    [col getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Error fetching instruments to update default: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextPaymentInstrumentSetDefault];
            if (completion) completion(NO, error);
            return;
        }

        FIRWriteBatch *batch = [self.db batch];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            BOOL isTarget = [doc.documentID isEqualToString:instrument.instrumentID];
            [batch updateData:@{
                @"isDefault": @(isTarget),
                @"updatedAt": [FIRTimestamp timestamp]
            } forDocument:doc.reference];
        }

        [batch commitWithCompletion:^(NSError * _Nullable err) {
            if (err) {
                NSLog(@"❌ Failed to update default instrument: %@", err.localizedDescription);
                [PPFirestoreErrorNotifier postError:err context:PPFirestoreContextPaymentInstrumentDefaultBatch];
                if (completion) completion(NO, err);
            } else {
                NSLog(@"✅ Default instrument set to %@", instrument.maskedDetails);
                if (completion) completion(YES, nil);
            }
        }];
    }];
}

#pragma mark - DELETE Instrument

- (void)deleteInstrument:(UserPaymentInstrument *)instrument
                 forUser:(NSString *)userID
              completion:(void (^)(BOOL, NSError *))completion {
    if (userID.length == 0 || !instrument.instrumentID) {
        NSLog(@"⚠️ Invalid parameters in deleteInstrument");
        if (completion) completion(NO, nil);
        return;
    }

    NSString *docPath = [NSString stringWithFormat:@"UsersCol/%@/paymentInstruments/%@", userID, instrument.instrumentID];
    NSLog(@"🗑 Deleting instrument: %@ → %@", instrument.instrumentID, instrument.maskedDetails);

    [[_db documentWithPath:docPath] deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Delete failed: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextPaymentInstrumentDelete];
            if (completion) completion(NO, error);
        } else {
            NSLog(@"✅ Instrument deleted successfully");
            if (completion) completion(YES, nil);
        }
    }];
}



- (void)updateInstrument:(UserPaymentInstrument *)instrument
                 forUser:(NSString *)userID
              completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!instrument.instrumentID) {
        if (completion) completion(NO, [NSError errorWithDomain:@"UpdateError" code:400 userInfo:@{NSLocalizedDescriptionKey:@"Missing instrument ID"}]);
        return;
    }
    
    NSDictionary *dict = @{
        @"maskedDetails": instrument.maskedDetails ?: @"",
        @"metaData": instrument.metaData ?: @{},
        @"originalData": instrument.originalData ?: @{},
        @"updatedAt": [FIRTimestamp timestamp]
    };
    
    [[[self.db collectionWithPath:[NSString stringWithFormat:@"UsersCol/%@/paymentInstruments", userID]]
      documentWithPath:instrument.instrumentID]
     updateData:dict completion:^(NSError * _Nullable error) {
        completion(error == nil, error);
    }];
}


@end
