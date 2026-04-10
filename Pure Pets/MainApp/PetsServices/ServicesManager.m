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
#import "PPRolePermission.h"
#import "PPFunc.h"
@import FirebaseFirestore;
@import FirebaseStorage;

@implementation ServicesManager {
    id<FIRListenerRegistration>  _allServicesListener;
    id<FIRListenerRegistration>  _kindServicesListener;
}

static NSError *PPServiceCreatePermissionError(NSString *message) {
    return [NSError errorWithDomain:@"ServicesManager"
                               code:-41
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"You do not have permission to add services."}];
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
    NSString *uid = [currentUser.ID isKindOfClass:NSString.class] ? currentUser.ID : @"";

    if (uid.length == 0) {
        if (completion) completion(PPServiceCreatePermissionError(@"Please sign in to add a new service."));
        return;
    }

    if (currentUser.isBlocked || [userManager isCurrentUserBlocked]) {
        if (completion) completion(PPServiceCreatePermissionError(@"Your account is blocked. You can't add services right now."));
        return;
    }

    if (![currentUser hasAnyPermissionInKeys:@[kPermManageServices, kPermAdminAll]]) {
        if (completion) completion(PPServiceCreatePermissionError(@"You don't have permission to add services."));
        return;
    }

    NSMutableDictionary *data = [[service toDictionary] mutableCopy];
    FIRFirestore *db = [FIRFirestore firestore];
    
    if (image) {
        NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
        NSString *fileName = [NSString stringWithFormat:@"services/%@.jpg", [[NSUUID UUID] UUIDString]];
        FIRStorageReference *ref = [[FIRStorage storage].reference child:fileName];

        [ref putData:imageData metadata:nil completion:^(FIRStorageMetadata *metadata, NSError *error) {
            if (error) {
                completion(error);
                return;
            }
            [ref downloadURLWithCompletion:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (url) {
                    data[@"imageURL"] = url.absoluteString;
                }
                [[db collectionWithPath:@"serviceOffers"] addDocumentWithData:data completion:completion];
            }];
        }];
    } else {
        [[db collectionWithPath:@"serviceOffers"] addDocumentWithData:data completion:completion];
    }
}

#pragma mark - Update Service

- (void)updateService:(NSString *)documentID withModel:(ServiceModel *)service completion:(void (^)(NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];
    NSDictionary *data = [service toDictionary];
    [[[db collectionWithPath:@"serviceOffers"] documentWithPath:documentID] setData:data completion:completion];
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

#pragma mark - Listener: By petMainKindID

- (void)listenToServicesForPetMainKindID:(NSInteger)kindID
                              completion:(void (^)(NSArray<ServiceModel *> *, NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];

    // Remove previous kind-specific listener to prevent stacking
    [_kindServicesListener remove];
    _kindServicesListener = nil;

    _kindServicesListener =
    [[[db collectionWithPath:@"serviceOffers"] queryWhereField:@"petMainKindID" isEqualTo:@(kindID)]
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

- (void)fetchServicesForPetMainKindID:(NSInteger)kindID
                           completion:(void (^)(NSArray<ServiceModel *> *services, NSError * _Nullable error))completion
{
    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query =
    [[db collectionWithPath:@"serviceOffers"]
     queryWhereField:@"petMainKindID" isEqualTo:@(kindID)];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[], error);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            NSMutableArray<ServiceModel *> *results =
            [NSMutableArray arrayWithCapacity:snapshot.documents.count];

            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                ServiceModel *model = [[ServiceModel alloc] initWithDictionary:doc.data documentID:doc.documentID];
                if (model) {
                    [results addObject:model];
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(results.copy, nil);
            });
        });
    }];
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

    // Optional safety limit
    // query = [query queryLimitedTo:50];

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
}

- (void)dealloc {
    [self stopAllListeners];
}

@end
