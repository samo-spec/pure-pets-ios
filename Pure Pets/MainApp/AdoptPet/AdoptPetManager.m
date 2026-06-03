//
//  AdoptPetManager.m
//  Pure Pets
//

#import "AdoptPetManager.h"
#import "AdoptPetModel.h"
#import "PPImageUploadValidator.h"
#import "PPFunc.h"
#import "PPImageCollection.h"
@import Firebase;
@import FirebaseStorage;

static NSString * const kAdoptPetsCollection = @"adopt_pets";
static NSString * const kAdoptPetsStorageRoot = @"adopt_pets";
static NSInteger const kFirestoreInQueryLimit = 10;

@interface AdoptPetManager ()
@end

@implementation AdoptPetManager

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static AdoptPetManager *mgr = nil;
    dispatch_once(&onceToken, ^{
        mgr = [[AdoptPetManager alloc] init];
    });
    return mgr;
}

#pragma mark - Create

- (void)createPet:(AdoptPetModel *)model
           images:(NSArray<UIImage *> *)images
       completion:(AdoptPetCreateCompletion)completion {

    // ── Client-side image validation before upload ──
    if (images.count > 0) {
        NSInteger failedIndex = 0;
        PPImageValidationResult result =
            [PPImageUploadValidator validateImages:images failedIndex:&failedIndex];
        if (result != PPImageValidationResultValid) {
            if (completion) {
                NSString *message = [PPImageUploadValidator localizedMessageForResult:result];
                NSError *validationError =
                    [NSError errorWithDomain:@"AdoptPetManager"
                                        code:(NSInteger)result
                                    userInfo:@{NSLocalizedDescriptionKey: message}];
                completion(NO, nil, validationError);
            }
            return;
        }
    }

    FIRDocumentReference *doc = model.documentID.length > 0
        ? [[self petsCollection] documentWithPath:model.documentID]
        : [[self petsCollection] documentWithAutoID];
    model.documentID = doc.documentID;

    __weak typeof(self) weakSelf = self;
    [self pp_uploadImages:images forDocumentID:doc.documentID completion:^(NSArray<NSString *> * _Nullable urls, NSError * _Nullable uploadError) {
        __strong typeof(weakSelf) strongSelf = weakSelf ?: self;

        if (uploadError) {
            if (completion) {
                completion(NO, nil, uploadError);
            }
            return;
        }

        if (urls.count > 0) {
            model.imageURLs = urls;
        }

        [[[strongSelf petsCollection] documentWithPath:doc.documentID]
         setData:[model toFirestoreDictionary]
         completion:^(NSError * _Nullable error) {
            if (completion) {
                completion(error == nil, error ? nil : doc.documentID, error);
            }
        }];
    }];
}

#pragma mark - Observe / Fetch

- (id<FIRListenerRegistration>)observeAllPetsWithUpdate:(AdoptPetListenerHandle)completion {
    FIRQuery *query = [[self petsCollection] queryOrderedByField:@"createdAt" descending:YES];
    return [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!completion) {
            return;
        }

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], error);
            });
            return;
        }

        NSMutableArray<AdoptPetModel *> *pets = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            AdoptPetModel *model = [[AdoptPetModel alloc] initWithSnapshot:doc];
            model.documentID = doc.documentID;
            if (model.visibility == 0) {
                [pets addObject:model];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(pets.copy, nil);
        });
    }];
}

- (void)fetchPetsForUserID:(NSString *)userID completion:(AdoptPetArrayCompletion)completion {
    if (userID.length == 0) {
        if (completion) {
            completion(@[], nil);
        }
        return;
    }

    [[[self petsCollection] queryWhereField:@"ownerID" isEqualTo:userID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        NSMutableArray<AdoptPetModel *> *pets = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            AdoptPetModel *model = [[AdoptPetModel alloc] initWithSnapshot:doc];
            model.documentID = doc.documentID;
            [pets addObject:model];
        }

        if (completion) {
            completion(pets.copy, nil);
        }
    }];
}

- (void)fetchPetsWithIDs:(NSArray<NSString *> *)ids completion:(AdoptPetArrayCompletion)completion {
    NSMutableOrderedSet<NSString *> *cleanIDs = [NSMutableOrderedSet orderedSet];
    for (NSString *identifier in ids) {
        if (identifier.length > 0) {
            [cleanIDs addObject:identifier];
        }
    }

    if (cleanIDs.count == 0) {
        if (completion) {
            completion(@[], nil);
        }
        return;
    }

    NSArray<NSString *> *orderedIDs = cleanIDs.array;
    NSMutableArray<NSArray<NSString *> *> *chunks = [NSMutableArray array];
    for (NSUInteger i = 0; i < orderedIDs.count; i += kFirestoreInQueryLimit) {
        NSUInteger len = MIN(kFirestoreInQueryLimit, orderedIDs.count - i);
        [chunks addObject:[orderedIDs subarrayWithRange:NSMakeRange(i, len)]];
    }

    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary<NSString *, AdoptPetModel *> *fetchedMap = [NSMutableDictionary dictionary];
    __block NSError *firstError = nil;

    for (NSArray<NSString *> *chunk in chunks) {
        dispatch_group_enter(group);
        [[[self petsCollection] queryWhereField:@"documentID" in:chunk]
         getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error && !firstError) {
                firstError = error;
                dispatch_group_leave(group);
                return;
            }

            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                AdoptPetModel *model = [[AdoptPetModel alloc] initWithSnapshot:doc];
                model.documentID = doc.documentID;
                if (model.visibility == 0) {
                    fetchedMap[doc.documentID] = model;
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (firstError) {
            if (completion) {
                completion(nil, firstError);
            }
            return;
        }

        NSMutableArray<AdoptPetModel *> *orderedPets = [NSMutableArray arrayWithCapacity:orderedIDs.count];
        for (NSString *identifier in orderedIDs) {
            AdoptPetModel *model = fetchedMap[identifier];
            if (model) {
                [orderedPets addObject:model];
            }
        }

        if (completion) {
            completion(orderedPets.copy, nil);
        }
    });
}

#pragma mark - Delete / Update

- (void)deletePetWithID:(NSString *)documentID completion:(AdoptPetCompletion)completion {
    if (documentID.length == 0) {
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"AdoptPetManager"
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey: @"Missing document ID"}]);
        }
        return;
    }

    // 🗑️ Fetch image URLs before deleting so we can clean up Storage
    [[[self petsCollection] documentWithPath:documentID]
     getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSArray *imageURLs = snapshot.data[@"imageURLs"];
        [PPImageCollection deleteEntityMediaWithEntityType:@"adoptions" entityID:documentID completion:nil];
        
        [[[self petsCollection] documentWithPath:documentID]
         deleteDocumentWithCompletion:^(NSError * _Nullable deleteError) {
            if (!deleteError && [imageURLs isKindOfClass:NSArray.class] && imageURLs.count > 0) {
                [PPFunc pp_deleteStorageImagesForURLs:imageURLs];
            }
            if (completion) {
                completion(deleteError == nil, deleteError);
            }
        }];
    }];
}

- (void)updatePetWithID:(NSString *)documentID
                   data:(NSDictionary *)data
             completion:(AdoptPetCompletion)completion {
    if (documentID.length == 0) {
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"AdoptPetManager"
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey: @"Missing document ID"}]);
        }
        return;
    }

    NSDictionary *safeData = [data isKindOfClass:NSDictionary.class] ? data : @{};
    [[[self petsCollection] documentWithPath:documentID]
     updateData:safeData
     completion:^(NSError * _Nullable error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)updatePetVisibilityWithID:(NSString *)documentID
                       visibility:(NSInteger)visibility
                       completion:(AdoptPetCompletion)completion {
    NSDictionary *data = @{
        @"visibility": @(visibility == 0 ? 0 : 1),
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };
    [self updatePetWithID:documentID data:data completion:completion];
}

- (void)updatePet:(AdoptPetModel *)model
           images:(NSArray<UIImage *> *)images
       completion:(AdoptPetCompletion)completion {
    NSString *documentID = model.documentID;
    if (documentID.length == 0) {
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"AdoptPetManager"
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey: @"Missing document ID"}]);
        }
        return;
    }

    // ── Client-side image validation before upload ──
    if (images.count > 0) {
        NSInteger failedIndex = 0;
        PPImageValidationResult result =
            [PPImageUploadValidator validateImages:images failedIndex:&failedIndex];
        if (result != PPImageValidationResultValid) {
            if (completion) {
                NSString *message = [PPImageUploadValidator localizedMessageForResult:result];
                NSError *validationError =
                    [NSError errorWithDomain:@"AdoptPetManager"
                                        code:(NSInteger)result
                                    userInfo:@{NSLocalizedDescriptionKey: message}];
                completion(NO, validationError);
            }
            return;
        }
    }

    // 🗑️ Capture old image URLs before uploading new ones
    NSArray<NSString *> *previousImageURLs = [model.imageURLs copy] ?: @[];
    
    __weak typeof(self) weakSelf = self;
    [self pp_uploadImages:(images ?: @[]) forDocumentID:documentID completion:^(NSArray<NSString *> * _Nullable urls, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf ?: self;

        if (error) {
            if (completion) {
                completion(NO, error);
            }
            return;
        }

        if (urls.count > 0) {
            model.imageURLs = urls;
        }

        [[[strongSelf petsCollection] documentWithPath:documentID]
         setData:[model toFirestoreDictionary]
         merge:YES
         completion:^(NSError * _Nullable setError) {
            if (!setError) {
                // 🗑️ Clean up old images that were replaced
                [PPFunc pp_deleteRemovedStorageImagesFromOldURLs:previousImageURLs
                                                        newURLs:model.imageURLs];
            }
            if (completion) {
                completion(setError == nil, setError);
            }
        }];
    }];
}

#pragma mark - Private

- (FIRCollectionReference *)petsCollection {
    return [[FIRFirestore firestore] collectionWithPath:kAdoptPetsCollection];
}

- (void)pp_uploadImages:(NSArray<UIImage *> *)images
          forDocumentID:(NSString *)documentID
             completion:(void (^)(NSArray<NSString *> * _Nullable urls, NSError * _Nullable error))completion {
    if (images.count == 0) {
        if (completion) {
            completion(@[], nil);
        }
        return;
    }

    FIRStorageReference *storageRef = [[FIRStorage storage] reference];
    NSString *basePath = [NSString stringWithFormat:@"%@/%@", kAdoptPetsStorageRoot, documentID];

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSString *> *downloadURLs = [NSMutableArray arrayWithCapacity:images.count];
    __block NSError *firstError = nil;

    [images enumerateObjectsUsingBlock:^(UIImage * _Nonnull image, NSUInteger idx, BOOL * _Nonnull stop) {
        NSData *jpeg = UIImageJPEGRepresentation(image, 0.85);
        if (jpeg.length == 0) {
            return;
        }

        NSString *fileName = [NSString stringWithFormat:@"image_%lu.jpg", (unsigned long)idx];
        FIRStorageReference *fileRef = [[storageRef child:basePath] child:fileName];

        dispatch_group_enter(group);

        FIRStorageMetadata *meta = [FIRStorageMetadata new];
        meta.contentType = @"image/jpeg";

        [fileRef putData:jpeg metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable uploadError) {
            if (uploadError) {
                @synchronized (downloadURLs) {
                    if (!firstError) {
                        firstError = uploadError;
                    }
                }
                dispatch_group_leave(group);
                return;
            }

            [fileRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable urlError) {
                @synchronized (downloadURLs) {
                    if (URL.absoluteString.length > 0) {
                        [downloadURLs addObject:URL.absoluteString];
                    } else if (urlError && !firstError) {
                        firstError = urlError;
                    }
                }
                dispatch_group_leave(group);
            }];
        }];
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (firstError) {
            if (completion) {
                completion(nil, firstError);
            }
            return;
        }

        if (completion) {
            completion(downloadURLs.copy, nil);
        }
    });
}

@end
