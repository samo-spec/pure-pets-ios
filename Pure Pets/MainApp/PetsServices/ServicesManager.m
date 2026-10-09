//
//  ServicesManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//

#import "ServicesManager.h"
#import "ServiceModel.h"
#import "ArabicNormalizer.h"
#import "UserManager.h"
#import "UserModel.h"
#import "PPUserKitCompatibility.h"
#import "PPFunc.h"
@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseStorage;

@implementation ServicesManager {
    id<FIRListenerRegistration>  _allServicesListener;
    id<FIRListenerRegistration>  _kindServicesListener;
    NSMutableArray<id<FIRListenerRegistration>> *_multiKindListeners;
}

static NSError *PPServiceWriteError(NSInteger code, NSString *key) {
    return [NSError errorWithDomain:@"ServicesManager"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: kLang(key ?: @"service_management_error_permission")}];
}

+ (instancetype)sharedInstance {
    static ServicesManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - Add Service

- (void)addService:(ServiceModel *)service image:(nullable UIImage *)image completion:(void (^)(NSError * _Nullable))completion {
    UserManager *userManager = [UserManager sharedManager];
    UserModel *currentUser = userManager.currentUser;
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";

    if (uid.length == 0) {
        if (completion) completion(PPServiceWriteError(-41, @"service_management_error_sign_in"));
        return;
    }

    if (currentUser.isBlocked || [userManager isCurrentUserBlocked]) {
        if (completion) completion(PPServiceWriteError(-41, @"service_management_error_blocked"));
        return;
    }

    if (![currentUser hasAnyPermissionInKeys:@[kPermManageServices, kPermAdminAll]]) {
        if (completion) completion(PPServiceWriteError(-41, @"service_management_error_permission"));
        return;
    }

    // Round-trip serialization includes moderation and review projections.
    // Creation submits only provider content and server creation timestamps.
    NSMutableDictionary *data = [[service providerToDictionary] mutableCopy];
    data[@"availableDate"] = service.availableDate ?: NSNull.null;
    data[@"timestamp"] = FIRFieldValue.fieldValueForServerTimestamp;
    data[@"createdAt"] = FIRFieldValue.fieldValueForServerTimestamp;
    FIRFirestore *db = [FIRFirestore firestore];
    void (^saveContent)(void) = ^{
        if (![uid isEqualToString:FIRAuth.auth.currentUser.uid]) {
            if (completion) completion(PPServiceWriteError(-41, @"service_management_error_session"));
            return;
        }
        [[db collectionWithPath:@"serviceOffers"] addDocumentWithData:data completion:completion];
    };
    
    if (image) {
        NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
        if (!imageData.length) {
            if (completion) completion(PPServiceWriteError(-42, @"service_management_error_image"));
            return;
        }
        NSString *fileName = [NSString stringWithFormat:@"services/%@.jpg", [[NSUUID UUID] UUIDString]];
        FIRStorageReference *ref = [[FIRStorage storage].reference child:fileName];

        FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
        metadata.contentType = @"image/jpeg";
        metadata.customMetadata = @{
            @"uploaded_by": uid,
            @"entity_type": @"service",
            @"entity_id": service.serviceID ?: @""
        };

        [ref putData:imageData metadata:metadata completion:^(FIRStorageMetadata *metadata, NSError *error) {
            if (error) {
                if (completion) completion(error);
                return;
            }
            [ref downloadURLWithCompletion:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (error || !url) {
                    if (completion) completion(error ?: PPServiceWriteError(-42, @"service_management_error_image"));
                    return;
                }
                data[@"imageURL"] = url.absoluteString;
                saveContent();
            }];
        }];
    } else {
        saveContent();
    }
}

#pragma mark - Update Service

- (void)updateService:(NSString *)documentID withModel:(ServiceModel *)service completion:(void (^)(NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];
    // Never replace the whole document: doing so drops server projections,
    // unknown future fields and the moderation decision already on the record.
    NSMutableDictionary *data = [[service providerToDictionary] mutableCopy];
    data[@"availableDate"] = service.availableDate ?: NSNull.null;
    [[[db collectionWithPath:@"serviceOffers"] documentWithPath:documentID] updateData:data completion:completion];
}

#pragma mark - Delete Service

- (void)deleteService:(NSString *)documentID completion:(void (^)(NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"serviceOffers"] documentWithPath:documentID];
    
    // 🗑️ Fetch image URL before deleting so we can clean up Storage
    [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSString *imageURL = snapshot.data[@"imageURL"];
        
        [docRef deleteDocumentWithCompletion:^(NSError * _Nullable deleteError) {
            if (!deleteError && [imageURL isKindOfClass:NSString.class] && imageURL.length > 0) {
                [PPFunc pp_deleteStorageImagesForURLs:@[imageURL]];
            }
            if (completion) completion(deleteError);
        }];
    }];
}

#pragma mark - Listener: All Services

- (void)listenToAllServicesWithCompletion:(void (^)(NSArray<ServiceModel *> *, NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];
    
    if (_allServicesListener) {
        [_allServicesListener remove];
    }
    
    _allServicesListener = [[db collectionWithPath:@"serviceOffers"]
        addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                completion(@[], error);
                return;
            }
            
            NSMutableArray *results = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                ServiceModel *model = [[ServiceModel alloc] initWithDictionary:doc.data documentID:doc.documentID];
                [results addObject:model];
            }
            completion(results, nil);
        }];
}

#pragma mark - Listener: By petMainKindID & Multi-Category

- (void)listenToServicesForPetMainKindID:(NSInteger)kindID
                              completion:(void (^)(NSArray<ServiceModel *> *, NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];

    // Remove previous listeners to prevent stacking
    [_kindServicesListener remove];
    _kindServicesListener = nil;
    for (id<FIRListenerRegistration> reg in _multiKindListeners) {
        [reg remove];
    }
    _multiKindListeners = [NSMutableArray array];

    if (kindID <= 0) {
        [self listenToAllServicesWithCompletion:completion];
        return;
    }

    FIRCollectionReference *coll = [db collectionWithPath:@"serviceOffers"];
    NSArray<FIRQuery *> *queries = @[
        [coll queryWhereField:@"petMainKindID" isEqualTo:@(kindID)],
        [coll queryWhereField:@"petMainCategoryIDs" arrayContains:@(kindID)],
        [coll queryWhereField:@"isAllCategories" isEqualTo:@(YES)],
        [coll queryWhereField:@"petMainKindID" isEqualTo:@(0)]
    ];

    NSMutableDictionary<NSString *, ServiceModel *> *combinedMap = [NSMutableDictionary dictionary];
    NSLock *mapLock = [[NSLock alloc] init];

    void (^emitCombined)(void) = ^{
        [mapLock lock];
        NSArray<ServiceModel *> *sorted = [combinedMap.allValues sortedArrayUsingComparator:^NSComparisonResult(ServiceModel *a, ServiceModel *b) {
            NSDate *dateA = a.updatedAt ?: a.createdAt ?: a.timestamp ?: a.availableDate ?: [NSDate distantPast];
            NSDate *dateB = b.updatedAt ?: b.createdAt ?: b.timestamp ?: b.availableDate ?: [NSDate distantPast];
            return [dateB compare:dateA];
        }];
        [mapLock unlock];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(sorted, nil);
        });
    };

    for (FIRQuery *q in queries) {
        id<FIRListenerRegistration> reg = [q addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                // If index or query errors, emit whatever has been gathered
                return;
            }
            if (snapshot) {
                [mapLock lock];
                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    ServiceModel *model = [[ServiceModel alloc] initWithDictionary:doc.data documentID:doc.documentID];
                    if (model && model.isLive) {
                        combinedMap[doc.documentID] = model;
                    }
                }
                [mapLock unlock];
                emitCombined();
            }
        }];
        if (reg) {
            [_multiKindListeners addObject:reg];
        }
    }
}

- (void)fetchServicesForPetMainKindID:(NSInteger)kindID
                           completion:(void (^)(NSArray<ServiceModel *> *services, NSError * _Nullable error))completion
{
    if (kindID <= 0) {
        [self fetchServicesForAllMainKinds:completion];
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *coll = [db collectionWithPath:@"serviceOffers"];

    NSArray<FIRQuery *> *queries = @[
        [coll queryWhereField:@"petMainKindID" isEqualTo:@(kindID)],
        [coll queryWhereField:@"petMainCategoryIDs" arrayContains:@(kindID)],
        [coll queryWhereField:@"isAllCategories" isEqualTo:@(YES)],
        [coll queryWhereField:@"petMainKindID" isEqualTo:@(0)]
    ];

    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary<NSString *, ServiceModel *> *uniqueMap = [NSMutableDictionary dictionary];
    NSLock *lock = [[NSLock alloc] init];
    __block NSError *lastError = nil;

    for (FIRQuery *query in queries) {
        dispatch_group_enter(group);
        [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                [lock lock];
                lastError = error;
                [lock unlock];
            } else if (snapshot) {
                [lock lock];
                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    if (!uniqueMap[doc.documentID]) {
                        ServiceModel *model = [[ServiceModel alloc] initWithDictionary:doc.data documentID:doc.documentID];
                        if (model && model.isLive) {
                            uniqueMap[doc.documentID] = model;
                        }
                    }
                }
                [lock unlock];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [lock lock];
        NSArray<ServiceModel *> *allModels = [uniqueMap.allValues sortedArrayUsingComparator:^NSComparisonResult(ServiceModel *a, ServiceModel *b) {
            NSDate *dateA = a.updatedAt ?: a.createdAt ?: a.timestamp ?: a.availableDate ?: [NSDate distantPast];
            NSDate *dateB = b.updatedAt ?: b.createdAt ?: b.timestamp ?: b.availableDate ?: [NSDate distantPast];
            return [dateB compare:dateA];
        }];
        [lock unlock];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(allModels, (allModels.count == 0 && lastError) ? lastError : nil);
            }
        });
    });
}



#pragma mark - Global Services Fetching

- (void)fetchServicesForAllMainKinds:(void (^)(NSArray<ServiceModel *> *services,
                                               NSError * _Nullable error))completion
{
    FIRFirestore *db = [FIRFirestore firestore];

    FIRQuery *query =
    [[db collectionWithPath:@"serviceOffers"]
     queryOrderedByField:@"availableDate"
     descending:YES];

    query = [query queryLimitedTo:50];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                        NSError * _Nullable error)
    {
        if (error || !snapshot) {
            NSLog(@"❌ fetchServicesForAllMainKinds error: %@",
                  error.localizedDescription);
            if (completion) {
                completion(@[], error);
            }
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

            NSMutableArray<ServiceModel *> *results =
            [NSMutableArray arrayWithCapacity:snapshot.documents.count];

            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                ServiceModel *model =
                [[ServiceModel alloc] initWithDictionary:doc.data
                                              documentID:doc.documentID];
                if (model) {
                    [results addObject:model];
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(results.copy, nil);
                }
            });
        });
    }];
}

#pragma mark - Fetch Latest Services (One-shot)

- (void)fetchLatestServicesWithLimit:(NSInteger)limit
                          completion:(void (^)(NSArray<ServiceModel *> *services,
                                               NSError * _Nullable error))completion
{
    FIRFirestore *db = [FIRFirestore firestore];

    FIRQuery *query = [[db collectionWithPath:@"serviceOffers"]
                       queryOrderedByField:@"availableDate"
                       descending:YES];

    if (limit > 0) {
        query = [query queryLimitedTo:limit];
    }

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                        NSError * _Nullable error)
    {
        if (error || !snapshot) {
            if (completion) {
                completion(@[], error);
            }
            return;
        }

        NSMutableArray<ServiceModel *> *results = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            ServiceModel *model =
            [[ServiceModel alloc] initWithDictionary:doc.data
                                          documentID:doc.documentID];
            [results addObject:model];
        }

        if (completion) {
            completion(results, nil);
        }
    }];
}

#pragma mark - Search Services (Prefix)

- (void)searchServicesWithText:(NSString *)query
                    completion:(void (^)(NSArray<ServiceModel *> *services))completion
{
    if (query.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(@[]);
        });
        return;
    }

    NSString *normalizedQuery = [ArabicNormalizer normalize:query];
    FIRFirestore *db = [FIRFirestore firestore];

    FIRQuery *fsQuery =
    [[[[db collectionWithPath:@"serviceOffers"]
       queryOrderedByField:@"searchTitle"]
      queryStartingAtValues:@[normalizedQuery]]
     queryEndingAtValues:@[[normalizedQuery stringByAppendingString:@"\uf8ff"]]];

    [fsQuery getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                         NSError * _Nullable error)
    {
        if (error || !snapshot) {
            NSLog(@"❌ searchServicesWithText error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        NSMutableArray<ServiceModel *> *results =
        [NSMutableArray arrayWithCapacity:snapshot.documents.count];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            ServiceModel *model =
            [[ServiceModel alloc] initWithDictionary:doc.data
                                          documentID:doc.documentID];

            // 🔒 Safety fallback for old docs
            NSString *normalizedTitle =
                [ArabicNormalizer normalize:model.title ?: @""];

            if ([normalizedTitle containsString:normalizedQuery]) {
                [results addObject:model];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ Services matched = %lu", (unsigned long)results.count);
            if (completion) completion(results);
        });
    }];
}



#pragma mark - Migration (searchTitle)

- (void)migrateSearchTitleForExistingServices
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚀 Starting services searchTitle migration...");

    [[db collectionWithPath:@"serviceOffers"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ Services migration failed: %@", error.localizedDescription);
            return;
        }

        __block NSInteger updatedCount = 0;
        dispatch_group_t group = dispatch_group_create();

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            NSString *title = doc.data[@"title"];
            NSString *searchTitle = doc.data[@"searchTitle"];

            // Skip already migrated or invalid docs
            if (searchTitle.length > 0 || title.length == 0) {
                continue;
            }

            dispatch_group_enter(group);

            NSString *normalized =
                [ArabicNormalizer normalize:title];

            [[doc reference] updateData:@{
                @"searchTitle": normalized
            } completion:^(NSError * _Nullable err) {

                if (err) {
                    NSLog(@"❌ Failed to migrate service %@: %@",
                          doc.documentID, err.localizedDescription);
                } else {
                    updatedCount++;
                }

                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSLog(@"✅ Services searchTitle migration completed. Updated: %ld",
                  (long)updatedCount);
        });
    }];
}

- (void)stopAllListeners {
    [_allServicesListener remove];
    _allServicesListener = nil;
    [_kindServicesListener remove];
    _kindServicesListener = nil;
    for (id<FIRListenerRegistration> reg in _multiKindListeners) {
        [reg remove];
    }
    [_multiKindListeners removeAllObjects];
}

- (void)dealloc {
    [self stopAllListeners];
}

@end
