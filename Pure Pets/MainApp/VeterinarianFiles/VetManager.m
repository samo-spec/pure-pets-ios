//
//  VetManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//

#import "VetManager.h"
#import "VetModel.h"

static NSString *PPVetManagerSafeString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[[value stringValue] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    }
    return @"";
}

static NSArray<NSString *> *PPVetManagerStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (id entry in (NSArray *)value) {
        NSString *safeEntry = PPVetManagerSafeString(entry);
        if (safeEntry.length > 0) {
            [items addObject:safeEntry];
        }
    }
    return items.copy;
}

static NSDate * _Nullable PPVetManagerDateFromValue(id value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    return nil;
}

static NSInteger const PPVetMedicineAccessKindType = 4;

static BOOL PPVetManagerBoolFromValue(id value) {
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = [[(NSString *)value lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return [normalized isEqualToString:@"true"] || [normalized isEqualToString:@"yes"] || [normalized isEqualToString:@"1"];
    }
    return NO;
}

static NSString *PPVetManagerFirstImageURL(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return PPVetManagerSafeString(value);
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id entry in (NSArray *)value) {
            NSString *url = PPVetManagerFirstImageURL(entry);
            if (url.length > 0) {
                return url;
            }
        }
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        return PPVetManagerFirstImageURL(((NSDictionary *)value)[@"url"]);
    }
    return @"";
}

static BOOL PPVetManagerIsMedicineDocument(NSDictionary *dict) {
    NSInteger accessKindType = [dict[@"accessKindType"] respondsToSelector:@selector(integerValue)] ? [dict[@"accessKindType"] integerValue] : 0;
    NSInteger legacyType = [dict[@"type"] respondsToSelector:@selector(integerValue)] ? [dict[@"type"] integerValue] : 0;
    return accessKindType == PPVetMedicineAccessKindType || legacyType == PPVetMedicineAccessKindType;
}

static NSString *PPVetManagerOwnerIdentifierForDocument(NSDictionary *dict) {
    for (NSString *key in @[@"ownerID", @"ownerId", @"userId", @"userID", @"providerId", @"providerID"]) {
        NSString *candidate = PPVetManagerSafeString(dict[key]);
        if (candidate.length > 0) {
            return candidate;
        }
    }
    return @"";
}

static void PPVetManagerGetDocumentsServerThenCache(FIRQuery *query,
                                                    NSString *logContext,
                                                    void (^completion)(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error)) {
    [query getDocumentsWithSource:FIRFirestoreSourceServer
                       completion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!error && snapshot) {
            if (completion) completion(snapshot, nil);
            return;
        }

        NSLog(@"[VetManager] %@ server fetch failed, trying cache: %@",
              logContext ?: @"query",
              error.localizedDescription ?: @"Unknown error");

        [query getDocumentsWithSource:FIRFirestoreSourceCache
                           completion:^(FIRQuerySnapshot * _Nullable cacheSnapshot, NSError * _Nullable cacheError) {
            if (cacheSnapshot) {
                if (completion) completion(cacheSnapshot, nil);
                return;
            }

            if (completion) completion(nil, cacheError ?: error);
        }];
    }];
}

@implementation VetMedicineModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _medicineID = @"";
        _title = @"";
        _medicineDescription = @"";
        _imageUrl = @"";
        _blurHash = @"";
        _vetId = @"";
        _userId = @"";
        _animalTypes = @[];
        _category = @"";
        _currency = @"QAR";
        _isAvailable = YES;
        _isPublished = YES;
    }
    return self;
}

- (NSString *)title_lowercase {
    return self.title.lowercaseString ?: @"";
}

- (NSDictionary *)toDictionary {
    NSString *title = self.title ?: @"";
    NSString *desc = self.medicineDescription ?: @"";
    NSString *ownerID = self.userId ?: @"";
    NSInteger quantity = MAX(0, self.stockQuantity);
    NSMutableArray<NSString *> *imageURLs = [NSMutableArray array];
    if (self.imageUrl.length > 0) {
        [imageURLs addObject:self.imageUrl];
    }
    NSMutableDictionary *dict = [@{
        @"accessKindType": @(PPVetMedicineAccessKindType),
        @"type": @(PPVetMedicineAccessKindType),
        @"name": title,
        @"nameEn": title,
        @"title": title,
        @"title_lowercase": self.title_lowercase,
        @"searchTitle": self.title_lowercase,
        @"desc": desc,
        @"descEn": desc,
        @"description": desc,
        @"imageUrl": self.imageUrl ?: @"",
        @"imageURLsArray": imageURLs.copy,
        @"blurHash": self.blurHash ?: @"",
        @"vetId": self.vetId ?: @"",
        @"userId": ownerID,
        @"ownerID": ownerID,
        @"animalTypes": self.animalTypes ?: @[],
        @"category": self.category ?: @"",
        @"requiresPrescription": @(self.requiresPrescription),
        @"price": @(self.price),
        @"finalPrice": @(self.price),
        @"currency": self.currency.length > 0 ? self.currency : @"QAR",
        @"stockQuantity": @(quantity),
        @"quantity": @(quantity),
        @"noStock": @(quantity <= 0),
        @"isAvailable": @(self.isAvailable && quantity > 0),
        @"isPublished": @(self.isPublished),
        @"isDisabled": @(self.isDisabled),
        @"condition": @(1),
    } mutableCopy];
    if (self.createdAt) dict[@"createdAt"] = self.createdAt;
    if (self.updatedAt) dict[@"updatedAt"] = self.updatedAt;
    return dict.copy;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)medicineID {
    VetMedicineModel *model = [[VetMedicineModel alloc] init];
    model.medicineID = medicineID ?: @"";
    NSString *name = PPVetManagerSafeString(dict[@"name"]);
    NSString *nameEn = PPVetManagerSafeString(dict[@"nameEn"]);
    NSString *title = PPVetManagerSafeString(dict[@"title"]);
    model.title = title.length > 0 ? title : (name.length > 0 ? name : nameEn);
    NSString *desc = PPVetManagerSafeString(dict[@"desc"]);
    NSString *descEn = PPVetManagerSafeString(dict[@"descEn"]);
    NSString *legacyDescription = PPVetManagerSafeString(dict[@"description"]);
    model.medicineDescription = legacyDescription.length > 0 ? legacyDescription : (desc.length > 0 ? desc : descEn);
    NSString *imageUrl = PPVetManagerFirstImageURL(dict[@"imageUrl"]);
    if (imageUrl.length == 0) {
        imageUrl = PPVetManagerFirstImageURL(dict[@"imageURLsArray"]);
    }
    model.imageUrl = imageUrl;
    model.blurHash = PPVetManagerSafeString(dict[@"blurHash"]);
    model.vetId = PPVetManagerSafeString(dict[@"vetId"]);
    NSString *ownerID = PPVetManagerOwnerIdentifierForDocument(dict);
    NSString *userId = PPVetManagerSafeString(dict[@"userId"]);
    model.userId = userId.length > 0 ? userId : ownerID;
    model.animalTypes = PPVetManagerStringArray(dict[@"animalTypes"]);
    model.category = PPVetManagerSafeString(dict[@"category"]);
    model.requiresPrescription = [dict[@"requiresPrescription"] boolValue];
    model.price = [dict[@"price"] respondsToSelector:@selector(doubleValue)] ? [dict[@"price"] doubleValue] : ([dict[@"finalPrice"] respondsToSelector:@selector(doubleValue)] ? [dict[@"finalPrice"] doubleValue] : 0.0);
    model.currency = PPVetManagerSafeString(dict[@"currency"]).length > 0 ? PPVetManagerSafeString(dict[@"currency"]) : @"QAR";
    model.stockQuantity = [dict[@"stockQuantity"] respondsToSelector:@selector(integerValue)] ? [dict[@"stockQuantity"] integerValue] : ([dict[@"quantity"] respondsToSelector:@selector(integerValue)] ? [dict[@"quantity"] integerValue] : 0);
    BOOL noStock = PPVetManagerBoolFromValue(dict[@"noStock"]);
    model.isAvailable = dict[@"isAvailable"] == nil ? (model.stockQuantity > 0 && !noStock) : [dict[@"isAvailable"] boolValue];
    BOOL blocked = PPVetManagerBoolFromValue(dict[@"isBlocked"]);
    BOOL deleted = PPVetManagerBoolFromValue(dict[@"isDeleted"]);
    BOOL archived = PPVetManagerBoolFromValue(dict[@"isArchived"]);
    BOOL active = dict[@"active"] == nil ? YES : PPVetManagerBoolFromValue(dict[@"active"]);
    model.isPublished = dict[@"isPublished"] == nil ? (active && !(blocked || deleted || archived)) : [dict[@"isPublished"] boolValue];
    model.isDisabled = [dict[@"isDisabled"] boolValue] || blocked || deleted || archived;
    model.createdAt = PPVetManagerDateFromValue(dict[@"createdAt"]);
    model.updatedAt = PPVetManagerDateFromValue(dict[@"updatedAt"]);
    return model;
}

@end

@interface VetManager ()
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@end

@implementation VetManager

+ (instancetype)sharedManager {
    static VetManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[VetManager alloc] init];
    });
    return sharedInstance;
}

- (FIRCollectionReference *)vetsCollection {
    return [[FIRFirestore firestore] collectionWithPath:@"veterinarians"];
}

- (FIRCollectionReference *)petAccessoriesCollection {
    return [[FIRFirestore firestore] collectionWithPath:@"petAccessories"];
}

- (void)addVet:(VetModel *)vet image:(UIImage *)image completion:(void (^)(NSError * _Nullable))completion {
    NSString *docID = [[NSUUID UUID] UUIDString];
    vet.vetID = docID;
    if (vet.userID.length == 0) {
        vet.userID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    if (!vet.createdAt) {
        vet.createdAt = [NSDate date];
    }
    vet.updatedAt = [NSDate date];
    if (vet.verificationStatus.length == 0) {
        vet.verificationStatus = @"pending";
    }
    vet.readyToContact = vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
    
    void (^saveBlock)(NSString *) = ^(NSString *logoURL) {
        vet.logoURL = logoURL;
        [[[self vetsCollection] documentWithPath:docID]  setData:[vet toDictionary]  completion:completion];
    };
    
    if (image) {
        [self uploadImage:image vetID:docID completion:saveBlock];
    } else {
        saveBlock(@"");
    }
}

- (void)updateVet:(VetModel *)vet image:(UIImage *)image completion:(void (^)(NSError * _Nullable))completion {
    vet.updatedAt = [NSDate date];
    if (vet.verificationStatus.length == 0) {
        vet.verificationStatus = @"pending";
    }
    vet.readyToContact = vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
    void (^updateBlock)(NSString *) = ^(NSString *logoURL) {
        vet.logoURL = logoURL.length ? logoURL : vet.logoURL;
        [[[self vetsCollection] documentWithPath:vet.vetID]  setData:[vet toDictionary]  completion:completion];
    };
    
    if (image) {
        [self uploadImage:image vetID:vet.vetID completion:updateBlock];
    } else {
        updateBlock(@"");
    }
}

- (void)deleteVet:(VetModel *)vet completion:(void (^)(NSError * _Nullable))completion {
    [[[self vetsCollection] documentWithPath:vet.vetID] deleteDocumentWithCompletion:completion];
}

- (void)getVetsForUser:(NSString *)userID completion:(void (^)(NSArray<VetModel *> *, NSError * _Nullable))completion {
    NSString *safeUserID = userID ?: @"";
    if (safeUserID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }

    [[[self vetsCollection] queryWhereField:@"userId" isEqualTo:safeUserID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        NSArray<FIRDocumentSnapshot *> *documents = snapshot.documents;
        if (documents.count == 0) {
            [[[self vetsCollection] queryWhereField:@"userID" isEqualTo:safeUserID]
             getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable legacySnapshot, NSError * _Nullable legacyError) {
                NSMutableArray *legacyResult = [NSMutableArray array];
                for (FIRDocumentSnapshot *doc in legacySnapshot.documents) {
                    VetModel *vet = [VetModel fromDictionary:doc.data withID:doc.documentID];
                    [legacyResult addObject:vet];
                }
                if (completion) completion(legacyResult.copy, legacyError);
            }];
            return;
        }

        NSMutableArray *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in documents) {
            VetModel *vet = [VetModel fromDictionary:doc.data withID:doc.documentID];
            [result addObject:vet];
        }
        if (completion) completion(result.copy, nil);
    }];
}

- (void)fetchAllVetsWithCompletion:(void (^)(NSArray<VetModel *> *vetsArray, NSError * _Nullable error))completion {
    PPVetManagerGetDocumentsServerThenCache([self vetsCollection], @"fetchAllVets", ^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray *vets = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            VetModel *vet = [VetModel fromDictionary:doc.data withID:doc.documentID];
            [vets addObject:vet];
        }
        if (completion) completion(vets.copy, error);
    });
}

- (void)fetchAllPetMedicinesWithCompletion:(void (^)(NSArray<VetMedicineModel *> *medicinesArray, NSError * _Nullable error))completion {
    NSArray<FIRQuery *> *queries = @[
        [self.petAccessoriesCollection queryWhereField:@"accessKindType" isEqualTo:@(PPVetMedicineAccessKindType)],
        [self.petAccessoriesCollection queryWhereField:@"type" isEqualTo:@(PPVetMedicineAccessKindType)]
    ];

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t syncQueue = dispatch_queue_create("com.purepets.vetmanager.medicines", DISPATCH_QUEUE_SERIAL);
    __block NSMutableDictionary<NSString *, VetMedicineModel *> *medicinesByID = [NSMutableDictionary dictionary];
    __block NSError *firstError = nil;

    [queries enumerateObjectsUsingBlock:^(FIRQuery * _Nonnull query, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_enter(group);
        NSString *logContext = idx == 0 ? @"fetchAllPetMedicines:accessKindType" : @"fetchAllPetMedicines:type";
        PPVetManagerGetDocumentsServerThenCache(query, logContext, ^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (snapshot) {
                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    NSDictionary *data = doc.data ?: @{};
                    if (!PPVetManagerIsMedicineDocument(data)) {
                        continue;
                    }
                    VetMedicineModel *medicine = [VetMedicineModel fromDictionary:data withID:doc.documentID];
                    if (!medicine) {
                        continue;
                    }
                    dispatch_sync(syncQueue, ^{
                        medicinesByID[doc.documentID] = medicine;
                    });
                }
            } else if (error) {
                dispatch_sync(syncQueue, ^{
                    if (!firstError) {
                        firstError = error;
                    }
                });
            }
            dispatch_group_leave(group);
        });
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSArray<VetMedicineModel *> *medicines = medicinesByID.allValues ?: @[];
        if (completion) {
            completion(medicines, medicines.count > 0 ? nil : firstError);
        }
    });
}

- (void)addVetsListenerWithCompletion:(void (^)(NSArray<VetModel *> *vets))onChange {
    if (self.listener) {
        [self.listener remove];
    }

    self.listener = [[self vetsCollection] addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) return;

        NSMutableArray *vets = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            VetModel *vet = [VetModel fromDictionary:doc.data withID:doc.documentID];
            [vets addObject:vet];
        }
        onChange(vets);
    }];
}

- (void)uploadImage:(UIImage *)image vetID:(NSString *)vetID completion:(void(^)(NSString *imageURL))completion {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    NSString *path = [NSString stringWithFormat:@"vets/%@.jpg", vetID];
    FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];
    
    [ref putData:imageData metadata:nil completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            completion(@"");
        } else {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
                completion(URL.absoluteString ?: @"");
            }];
        }
    }];
}


- (void)getVetsForPetMainKindID:(NSInteger)kindID completion:(void (^)(NSArray<VetModel *> *vets, NSError * _Nullable error))completion {
    [[[self vetsCollection] queryWhereField:@"petMainKindID" isEqualTo:@(kindID)]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray *vets = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            VetModel *vet = [VetModel fromDictionary:doc.data withID:doc.documentID];
            [vets addObject:vet];
        }
        completion(vets, error);
    }];
}


@end
