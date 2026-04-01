//
//  VetManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//

#import "VetManager.h"
#import "VetModel.h"

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

- (void)addVet:(VetModel *)vet image:(UIImage *)image completion:(void (^)(NSError * _Nullable))completion {
    NSString *docID = [[NSUUID UUID] UUIDString];
    vet.vetID = docID;
    
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
    [[[self vetsCollection] queryWhereField:@"userID" isEqualTo:userID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            VetModel *vet = [VetModel fromDictionary:doc.data withID:doc.documentID];
            [result addObject:vet];
        }
        completion(result, error);
    }];
}

- (void)fetchAllVetsWithCompletion:(void (^)(NSArray<VetModel *> *vetsArray, NSError * _Nullable error))completion {
    [[self vetsCollection] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray *vets = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            VetModel *vet = [VetModel fromDictionary:doc.data withID:doc.documentID];
            [vets addObject:vet];
        }
        completion(vets, error);
    }];
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
