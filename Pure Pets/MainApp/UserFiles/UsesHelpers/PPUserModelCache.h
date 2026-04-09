//
//  PPUserModelCache.h
//  PurePets
//
//  Extracted from UserModel.m — Phase 2A cleanup.
//  Owns all NSKeyedArchiver disk-caching logic for UserModel.
//

#import <Foundation/Foundation.h>

@class UserModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPUserModelCache : NSObject

/// Load a cached UserModel from disk by UID.
/// SECURITY: Privilege-granting fields (role, isAdmin, isSuperAdmin, permissions)
/// are zeroed out to prevent cache-tampering privilege escalation.
+ (nullable UserModel *)loadUserWithUID:(NSString *)uid;

/// Persist a UserModel to disk using NSKeyedArchiver.
+ (void)saveUser:(UserModel *)user;

/// Remove the cached UserModel file for a given UID.
+ (void)clearUserWithUID:(NSString *)uid;

@end

NS_ASSUME_NONNULL_END
