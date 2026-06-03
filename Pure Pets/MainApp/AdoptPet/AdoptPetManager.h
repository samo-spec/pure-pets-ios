//
//  AdoptPetManager.h
//  Pure Pets
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class AdoptPetModel;
@import FirebaseFirestore;

NS_ASSUME_NONNULL_BEGIN

typedef void(^AdoptPetCompletion)(BOOL success, NSError * _Nullable error);
typedef void(^AdoptPetCreateCompletion)(BOOL success, NSString * _Nullable documentID, NSError * _Nullable error);
typedef void(^AdoptPetArrayCompletion)(NSArray<AdoptPetModel *> * _Nullable pets, NSError * _Nullable error);
typedef void(^AdoptPetListenerHandle)(NSArray<AdoptPetModel *> *pets, NSError * _Nullable error);

@interface AdoptPetManager : NSObject
+ (instancetype)shared;

- (void)createPet:(AdoptPetModel *)model
           images:(NSArray<UIImage *> *)images
       completion:(AdoptPetCreateCompletion)completion;

/// Real-time listener: returns a FIRListenerRegistration you should keep and remove later.
- (id<FIRListenerRegistration>)observeAllPetsWithUpdate:(AdoptPetListenerHandle)completion;

/// Fetch pets posted by a specific user
- (void)fetchPetsForUserID:(NSString *)userID completion:(AdoptPetArrayCompletion)completion;

/// Delete a pet by doc ID
- (void)deletePetWithID:(NSString *)documentID completion:(AdoptPetCompletion)completion;

/// Update a pet (dictionary is partial update)
- (void)updatePetWithID:(NSString *)documentID
              data:(NSDictionary *)data
        completion:(AdoptPetCompletion)completion;

/// Toggle public visibility without changing ownership, media, or delete/block fields.
- (void)updatePetVisibilityWithID:(NSString *)documentID
                       visibility:(NSInteger)visibility
                       completion:(AdoptPetCompletion)completion;

/// Update a pet model and optionally replace all images.
- (void)updatePet:(AdoptPetModel *)model
           images:(nullable NSArray<UIImage *> *)images
       completion:(AdoptPetCompletion)completion;

/// Fetch pets for a list of document IDs
- (void)fetchPetsWithIDs:(NSArray<NSString *> *)ids completion:(AdoptPetArrayCompletion)completion;

@end

NS_ASSUME_NONNULL_END
