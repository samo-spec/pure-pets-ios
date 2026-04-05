//
//  ServicesManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ServiceModel;

NS_ASSUME_NONNULL_BEGIN

@interface ServicesManager : NSObject

+ (instancetype)sharedInstance;
- (void)searchServicesWithText:(NSString *)query
                    completion:(void (^)(NSArray<ServiceModel *> *services))completion;
// Add service with image
- (void)addService:(ServiceModel *)service
             image:(nullable UIImage *)image
        completion:(void (^)(NSError * _Nullable error))completion;

// Update existing service
- (void)updateService:(NSString *)documentID
            withModel:(ServiceModel *)service
           completion:(void (^)(NSError * _Nullable error))completion;

// Delete service by ID
- (void)deleteService:(NSString *)documentID
           completion:(void (^)(NSError * _Nullable error))completion;

// Real-time listener to all services
- (void)listenToAllServicesWithCompletion:(void (^)(NSArray<ServiceModel *> *services, NSError * _Nullable error))completion;

// Real-time listener to services for specific petMainKindID
- (void)listenToServicesForPetMainKindID:(NSInteger)kindID
                              completion:(void (^)(NSArray<ServiceModel *> *services, NSError * _Nullable error))completion;

// One-shot fetch by petMainKindID (no live listener retained)
- (void)fetchServicesForPetMainKindID:(NSInteger)kindID
                           completion:(void (^)(NSArray<ServiceModel *> *services, NSError * _Nullable error))completion;

- (void)fetchLatestServicesWithLimit:(NSInteger)limit
                          completion:(void (^)(NSArray<ServiceModel *> *services,
                                               NSError * _Nullable error))completion;
- (void)migrateSearchTitleForExistingServices;

- (void)fetchServicesForAllMainKinds:(void (^)(NSArray<ServiceModel *> *services,
                                               NSError * _Nullable error))completion;

/// Removes all active Firestore listeners. Call on logout or when listeners are no longer needed.
- (void)stopAllListeners;
@end

NS_ASSUME_NONNULL_END

