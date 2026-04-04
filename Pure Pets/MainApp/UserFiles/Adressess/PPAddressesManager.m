//
//  PPAddressesManager.m
//  Pure Pets
//

#import "PPAddressesManager.h"
#import "UserManager.h"
@import FirebaseAuth;

NSString *const PPAddressesDidChangeNotification = @"PPAddressesDidChangeNotification";
static NSString *const PPAddressesErrorDomain = @"PPAddressesManager";

@interface PPAddressesManager ()
@property (nonatomic, strong) FIRFirestore *db;
@end

@implementation PPAddressesManager

+ (instancetype)sharedManager {
    static PPAddressesManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initPrivate];
    });
    return sharedInstance;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _db = [FIRFirestore firestore];
    }
    return self;
}

#pragma mark - Helpers

- (NSString * _Nullable)currentAuthenticatedUserID
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length > 0) {
        return authUser.uid;
    }
    return nil;
}

- (NSError *)pp_errorWithCode:(NSInteger)code description:(NSString *)description
{
    return [NSError errorWithDomain:PPAddressesErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"Address operation failed."}];
}

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSError *)pp_validationErrorForAddress:(PPAddressModel *)address
                        requireDocumentID:(BOOL)requireDocumentID
{
    if (!address) {
        return [self pp_errorWithCode:400 description:@"Address payload is missing."];
    }

    if (requireDocumentID && address.documentID.length == 0) {
        return [self pp_errorWithCode:400 description:@"Missing address document ID."];
    }

    address.fullName = [self pp_trimmedString:address.fullName];
    address.addressLine1 = [self pp_trimmedString:address.addressLine1];
    address.addressLine2 = [self pp_trimmedString:address.addressLine2];
    address.postalCode = [self pp_trimmedString:address.postalCode];
    address.locatioName = [self pp_trimmedString:address.locatioName];
    address.locationPoints = [self pp_trimmedString:address.locationPoints];

    // SECURITY: Validate phone number format if present (E.164-like: +digits, 7-15 chars)
    NSString *phone = [self pp_trimmedString:address.phoneNumber];
    if (phone.length > 0) {
        NSCharacterSet *allowedPhoneChars = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
        NSCharacterSet *phoneChars = [NSCharacterSet characterSetWithCharactersInString:phone];
        BOOL hasOnlyDigitsAndPlus = [allowedPhoneChars isSupersetOfSet:phoneChars];
        BOOL hasValidLength = (phone.length >= 7 && phone.length <= 16);
        if (!hasOnlyDigitsAndPlus || !hasValidLength) {
            return [self pp_errorWithCode:422 description:@"Phone number format is invalid."];
        }
        address.phoneNumber = phone;
    }

    if (![address isSemanticallyValid]) {
        return [self pp_errorWithCode:422 description:@"Address fields are incomplete or invalid."];
    }

    return nil;
}

- (NSMutableDictionary *)pp_firestorePayloadForAddress:(PPAddressModel *)address
                                                userID:(NSString *)userID
                                               isCreate:(BOOL)isCreate
{
    NSDate *now = [NSDate date];
    if (address.addressID.length == 0) {
        address.addressID = address.documentID.length > 0 ? address.documentID : [[NSUUID UUID] UUIDString];
    }
    if (address.documentID.length == 0) {
        address.documentID = address.addressID;
    }
    address.userID = userID ?: @"";
    if (isCreate && !address.createdAt) {
        address.createdAt = now;
    }
    address.updatedAt = now;

    NSMutableDictionary *data = [[address toDictionary] mutableCopy];
    data[@"addressID"] = address.addressID ?: address.documentID ?: @"";
    data[@"userID"] = userID ?: @"";
    data[@"updatedAt"] = now;
    if (isCreate || address.createdAt) {
        data[@"createdAt"] = address.createdAt ?: now;
    }
    return data;
}

- (NSArray<PPAddressModel *> *)pp_modelsFromSnapshot:(FIRQuerySnapshot *)snapshot
{
    NSString *uid = [self currentAuthenticatedUserID] ?: @"";
    NSMutableArray<PPAddressModel *> *results = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (FIRDocumentSnapshot *doc in snapshot.documents) {
        NSString *docID = doc.documentID ?: @"";
        if (docID.length == 0 || [seen containsObject:docID]) {
            continue;
        }
        [seen addObject:docID];

        PPAddressModel *model = [[PPAddressModel alloc] initWithDictionary:doc.data documentID:docID];
        if (!model.addressID.length) {
            model.addressID = docID;
        }
        model.documentID = docID;
        if (model.userID.length > 0 && uid.length > 0 && ![model.userID isEqualToString:uid]) {
            continue;
        }
        if (!model.userID.length) {
            model.userID = uid;
        }
        [results addObject:model];
    }

    [results sortUsingComparator:^NSComparisonResult(PPAddressModel * _Nonnull a, PPAddressModel * _Nonnull b) {
        if (a.isDefault != b.isDefault) {
            return a.isDefault ? NSOrderedAscending : NSOrderedDescending;
        }
        NSDate *aDate = a.updatedAt ?: a.createdAt ?: [NSDate distantPast];
        NSDate *bDate = b.updatedAt ?: b.createdAt ?: [NSDate distantPast];
        return [bDate compare:aDate];
    }];

    return results.copy;
}

- (void)pp_syncCachedUserAddresses:(NSArray<PPAddressModel *> *)addresses
                            userID:(NSString *)userID
{
    UserModel *current = UserManager.sharedManager.currentUser;
    if (!current) return;

    NSString *currentUID = current.ID;
    if (userID.length > 0 &&
        currentUID.length > 0 &&
        ![currentUID isEqualToString:userID]) {
        return;
    }

    current.Addresses = [NSMutableArray arrayWithArray:addresses ?: @[]];
    [UserManager.sharedManager cacheUser:current];
}

- (void)pp_notifyAddressesChangedForUserID:(NSString *)userID
{
    if (userID.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PPAddressesDidChangeNotification
                                                            object:self
                                                          userInfo:@{@"uid": userID}];
    });
}

- (void)pp_commitAddressData:(NSDictionary *)data
                documentID:(NSString *)documentID
              makeDefault:(BOOL)makeDefault
                completion:(PPVoidCompletion _Nullable)completion
{
    FIRCollectionReference *collection = self.userAddressesCollection;
    NSString *uid = [self currentAuthenticatedUserID] ?: @"";
    if (!collection || uid.length == 0) {
        if (completion) completion(NO, [self pp_errorWithCode:401 description:@"User must be authenticated."]);
        return;
    }

    FIRDocumentReference *targetRef = [collection documentWithPath:documentID];
    if (!makeDefault) {
        [targetRef setData:data merge:YES completion:^(NSError * _Nullable error) {
            if (!error) {
                [self getAllAddressesWithCompletion:nil];
                [self pp_notifyAddressesChangedForUserID:uid];
            }
            if (completion) completion(error == nil, error);
        }];
        return;
    }

    [collection getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            if (completion) completion(NO, error ?: [self pp_errorWithCode:500 description:@"Unable to load addresses."]);
            return;
        }

        FIRWriteBatch *batch = [self.db batch];
        NSDate *now = [NSDate date];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [batch updateData:@{@"isDefault": @NO, @"updatedAt": now} forDocument:doc.reference];
        }

        NSMutableDictionary *targetData = [data mutableCopy];
        targetData[@"isDefault"] = @YES;
        targetData[@"updatedAt"] = now;
        [batch setData:targetData forDocument:targetRef merge:YES];

        [batch commitWithCompletion:^(NSError * _Nullable commitError) {
            if (!commitError) {
                [self getAllAddressesWithCompletion:nil];
                [self pp_notifyAddressesChangedForUserID:uid];
            } else {
                // SECURITY: Batch failure may leave isDefault state inconsistent — force resync
                NSLog(@"[PPAddressesManager] ⚠️ Default-swap batch failed, resyncing: %@", commitError.localizedDescription);
                [self getAllAddressesWithCompletion:nil];
            }
            if (completion) completion(commitError == nil, commitError);
        }];
    }];
}

#pragma mark - Collection Reference

- (FIRCollectionReference *)userAddressesCollection {
    NSString *userID = [self currentAuthenticatedUserID];
    if (userID.length == 0) return nil;

    return [[[_db collectionWithPath:@"UsersCol"]
             documentWithPath:userID]
            collectionWithPath:@"Addresses"];
}

#pragma mark - CRUD Operations

- (void)getAllAddressesWithCompletion:(PPAddressesCompletion _Nullable)completion {
    FIRCollectionReference *collection = self.userAddressesCollection;
    if (!collection) {
        if (completion) completion(nil, [self pp_errorWithCode:401 description:@"User must be authenticated."]);
        return;
    }

    [[collection queryOrderedByField:@"isDefault" descending:YES]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            if (completion) completion(nil, error);
            return;
        }
        NSArray<PPAddressModel *> *models = [self pp_modelsFromSnapshot:snapshot];
        NSString *uid = [self currentAuthenticatedUserID] ?: @"";
        [self pp_syncCachedUserAddresses:models userID:uid];
        if (completion) completion(models, nil);
    }];
}

- (void)addAddress:(PPAddressModel *)address completion:(PPAddressCompletion _Nullable)completion {
    NSString *uid = [self currentAuthenticatedUserID];
    if (uid.length == 0) {
        if (completion) completion(nil, [self pp_errorWithCode:401 description:@"User must be authenticated."]);
        return;
    }

    NSError *validationError = [self pp_validationErrorForAddress:address requireDocumentID:NO];
    if (validationError) {
        if (completion) completion(nil, validationError);
        return;
    }

    if (address.documentID.length == 0) {
        address.documentID = [[NSUUID UUID] UUIDString];
    }
    address.addressID = address.documentID;

    FIRCollectionReference *collection = self.userAddressesCollection;
    FIRDocumentReference *docRef = [collection documentWithPath:address.documentID];

    [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        if (snapshot.exists) {
            NSError *dupError = [self pp_errorWithCode:409 description:@"Address ID already exists. Please retry."];
            if (completion) completion(nil, dupError);
            return;
        }

        [collection getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable addressesSnapshot, NSError * _Nullable listError) {
            if (listError || !addressesSnapshot) {
                if (completion) completion(nil, listError ?: [self pp_errorWithCode:500 description:@"Unable to load addresses."]);
                return;
            }

            BOOL hasDefault = NO;
            for (FIRDocumentSnapshot *doc in addressesSnapshot.documents) {
                if ([doc.data[@"isDefault"] boolValue]) {
                    hasDefault = YES;
                    break;
                }
            }

            BOOL shouldMakeDefault = address.isDefault || !hasDefault;
            address.isDefault = shouldMakeDefault;

            NSMutableDictionary *data = [self pp_firestorePayloadForAddress:address userID:uid isCreate:YES];
            data[@"isDefault"] = @(shouldMakeDefault);
            [self pp_commitAddressData:data
                            documentID:address.documentID
                          makeDefault:shouldMakeDefault
                            completion:^(BOOL success, NSError * _Nullable commitError) {
                if (!success || commitError) {
                    if (completion) completion(nil, commitError);
                    return;
                }
                if (completion) completion(address, nil);
            }];
        }];
    }];
}

- (void)updateAddress:(PPAddressModel *)address completion:(PPAddressCompletion _Nullable)completion {
    NSString *uid = [self currentAuthenticatedUserID];
    if (uid.length == 0) {
        if (completion) completion(nil, [self pp_errorWithCode:401 description:@"User must be authenticated."]);
        return;
    }

    NSError *validationError = [self pp_validationErrorForAddress:address requireDocumentID:YES];
    if (validationError) {
        if (completion) completion(nil, validationError);
        return;
    }

    FIRCollectionReference *collection = self.userAddressesCollection;
    FIRDocumentReference *docRef = [collection documentWithPath:address.documentID];
    [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        if (!snapshot.exists) {
            if (completion) completion(nil, [self pp_errorWithCode:404 description:@"Address not found."]);
            return;
        }

        id existingCreatedAt = snapshot.data[@"createdAt"];
        if ([existingCreatedAt isKindOfClass:[FIRTimestamp class]]) {
            address.createdAt = ((FIRTimestamp *)existingCreatedAt).dateValue;
        } else if ([existingCreatedAt isKindOfClass:[NSDate class]]) {
            address.createdAt = existingCreatedAt;
        }
        NSMutableDictionary *data = [self pp_firestorePayloadForAddress:address userID:uid isCreate:NO];
        [self pp_commitAddressData:data
                        documentID:address.documentID
                      makeDefault:address.isDefault
                        completion:^(BOOL success, NSError * _Nullable commitError) {
            if (completion) completion(success ? address : nil, commitError);
        }];
    }];
}

- (void)deleteAddress:(PPAddressModel *)address completion:(PPVoidCompletion _Nullable)completion {
    NSString *uid = [self currentAuthenticatedUserID];
    if (uid.length == 0) {
        if (completion) completion(NO, [self pp_errorWithCode:401 description:@"User must be authenticated."]);
        return;
    }
    if (address.documentID.length == 0) {
        if (completion) completion(NO, [self pp_errorWithCode:400 description:@"Missing address document ID."]);
        return;
    }

    FIRCollectionReference *collection = self.userAddressesCollection;
    [collection getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            if (completion) completion(NO, error ?: [self pp_errorWithCode:500 description:@"Failed to read addresses before delete."]);
            return;
        }

        FIRWriteBatch *batch = [self.db batch];
        FIRDocumentReference *targetRef = [collection documentWithPath:address.documentID];
        [batch deleteDocument:targetRef];

        BOOL deletedWasDefault = NO;
        FIRDocumentReference *fallbackRef = nil;
        NSDate *now = [NSDate date];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            if ([doc.documentID isEqualToString:address.documentID]) {
                deletedWasDefault = [doc.data[@"isDefault"] boolValue];
                continue;
            }
            if (!fallbackRef) {
                fallbackRef = doc.reference;
            }
        }

        if (deletedWasDefault && fallbackRef) {
            [batch updateData:@{@"isDefault": @YES, @"updatedAt": now} forDocument:fallbackRef];
        }

        [batch commitWithCompletion:^(NSError * _Nullable commitError) {
            if (!commitError) {
                [self getAllAddressesWithCompletion:nil];
                [self pp_notifyAddressesChangedForUserID:uid];
            } else {
                // SECURITY: Batch failure may leave isDefault state inconsistent — force resync
                NSLog(@"[PPAddressesManager] ⚠️ Delete batch failed, resyncing: %@", commitError.localizedDescription);
                [self getAllAddressesWithCompletion:nil];
            }
            if (completion) completion(commitError == nil, commitError);
        }];
    }];
}

#pragma mark - Default Address

- (void)setDefaultAddress:(PPAddressModel *)address completion:(PPVoidCompletion _Nullable)completion {
    if (address.documentID.length == 0) {
        if (completion) completion(NO, [self pp_errorWithCode:400 description:@"Missing address document ID."]);
        return;
    }

    NSMutableDictionary *data = [[address toDictionary] mutableCopy];
    data[@"isDefault"] = @YES;
    data[@"updatedAt"] = [NSDate date];
    [self pp_commitAddressData:data
                    documentID:address.documentID
                  makeDefault:YES
                    completion:completion];
}

#pragma mark - Real-Time Updates

- (id<FIRListenerRegistration>)listenToAddressesWithBlock:(PPAddressesCompletion _Nullable)updateBlock {
    FIRCollectionReference *collection = self.userAddressesCollection;
    if (!collection) {
        if (updateBlock) {
            updateBlock(nil, [self pp_errorWithCode:401 description:@"User must be authenticated."]);
        }
        return nil;
    }

    return [[collection queryOrderedByField:@"isDefault" descending:YES]
            addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            if (updateBlock) updateBlock(nil, error);
            return;
        }
        NSArray<PPAddressModel *> *models = [self pp_modelsFromSnapshot:snapshot];
        NSString *uid = [self currentAuthenticatedUserID] ?: @"";
        [self pp_syncCachedUserAddresses:models userID:uid];
        if (updateBlock) updateBlock(models, nil);
    }];
}

@end
