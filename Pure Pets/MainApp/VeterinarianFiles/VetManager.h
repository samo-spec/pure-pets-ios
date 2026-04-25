//
//  VetManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//

NS_ASSUME_NONNULL_BEGIN
@class VetModel;

@interface VetMedicineModel : NSObject
@property (nonatomic, copy) NSString *medicineID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, readonly) NSString *title_lowercase;
@property (nonatomic, copy) NSString *medicineDescription;
@property (nonatomic, copy) NSString *imageUrl;
@property (nonatomic, copy) NSString *blurHash;
@property (nonatomic, copy) NSString *vetId;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSArray<NSString *> *animalTypes;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, assign) BOOL requiresPrescription;
@property (nonatomic, assign) double price;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, assign) NSInteger stockQuantity;
@property (nonatomic, assign) BOOL isAvailable;
@property (nonatomic, assign) BOOL isPublished;
@property (nonatomic, assign) BOOL isDisabled;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)medicineID;
@end

@interface VetManager : NSObject

+ (instancetype)sharedManager;

- (void)addVet:(VetModel *)vet image:(UIImage * _Nullable)image completion:(void(^)(NSError * _Nullable error))completion;
- (void)updateVet:(VetModel *)vet image:(UIImage * _Nullable)image completion:(void(^)(NSError * _Nullable error))completion;
- (void)deleteVet:(VetModel *)vet completion:(void(^)(NSError * _Nullable error))completion;
- (void)getVetsForUser:(NSString *)userID completion:(void(^)(NSArray<VetModel *> *vets, NSError * _Nullable error))completion;
- (void)uploadImage:(UIImage *)image vetID:(NSString *)vetID completion:(void(^)(NSString *imageURL))completion;
- (void)getVetsForPetMainKindID:(NSInteger)kindID completion:(void (^)(NSArray<VetModel *> *vets, NSError * _Nullable error))completion;
- (void)fetchAllVetsWithCompletion:(void (^)(NSArray<VetModel *> *vetsArray, NSError * _Nullable error))completion;
- (void)fetchAllPetMedicinesWithCompletion:(void (^)(NSArray<VetMedicineModel *> *medicinesArray, NSError * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
