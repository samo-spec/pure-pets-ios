//
//  VetManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//

NS_ASSUME_NONNULL_BEGIN
@class VetModel;

@interface VetManager : NSObject

+ (instancetype)sharedManager;

- (void)addVet:(VetModel *)vet image:(UIImage * _Nullable)image completion:(void(^)(NSError * _Nullable error))completion;
- (void)updateVet:(VetModel *)vet image:(UIImage * _Nullable)image completion:(void(^)(NSError * _Nullable error))completion;
- (void)deleteVet:(VetModel *)vet completion:(void(^)(NSError * _Nullable error))completion;
- (void)getVetsForUser:(NSString *)userID completion:(void(^)(NSArray<VetModel *> *vets, NSError * _Nullable error))completion;
- (void)uploadImage:(UIImage *)image vetID:(NSString *)vetID completion:(void(^)(NSString *imageURL))completion;
- (void)getVetsForPetMainKindID:(NSInteger)kindID completion:(void (^)(NSArray<VetModel *> *vets, NSError * _Nullable error))completion;
- (void)fetchAllVetsWithCompletion:(void (^)(NSArray<VetModel *> *vetsArray, NSError * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END


