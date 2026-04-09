//
//  PPUserPermissionsManager.h
//  PurePets
//
//  Extracted from UserModel.m — Phase 2A cleanup.
//  Owns all Firestore permission fetching, listening, writing, and checking.
//

#import <Foundation/Foundation.h>

@class UserModel;
@class FIRDocumentSnapshot;

NS_ASSUME_NONNULL_BEGIN

@interface PPUserPermissionsManager : NSObject

#pragma mark - Fetch

/// Fetch permissions for a user model from all 3 Firestore paths (canonical + 2 legacy).
- (void)fetchPermissionsForUser:(UserModel *)user
                     completion:(void (^)(NSDictionary<NSString *, NSNumber *> *perms,
                                          NSError * _Nullable error))completion;

#pragma mark - Listen

/// Start real-time listener on all 3 permission paths for a user.
- (void)startListeningPermissionsForUser:(UserModel *)user
                                onChange:(void (^)(NSDictionary<NSString *, NSNumber *> *perms))onChange;

/// Stop the active permissions listener.
- (void)stopListening;

#pragma mark - Write

/// Write a permission value for a user (writes to all 3 paths for backward compat).
/// Includes a 2-second debounce to prevent rapid-fire writes.
- (void)setPermissionNamed:(NSString *)permName
                   allowed:(BOOL)allowed
                   forUser:(UserModel *)user
                completion:(void (^)(NSError * _Nullable error))completion;

#pragma mark - Check

/// Check if a user has a specific permission.
+ (BOOL)user:(UserModel *)user hasPermissionNamed:(NSString *)permName;

/// Check if a user has any of the given permissions.
+ (BOOL)user:(UserModel *)user hasAnyPermissionInKeys:(NSArray<NSString *> *)permNames;

#pragma mark - Name Helpers

/// Canonicalize a permission name (handles legacy name mappings).
+ (NSString *)canonicalPermissionName:(NSString *)rawName;

#pragma mark - Sanitize

/// Sanitize a raw permissions dictionary into canonical form.
+ (NSDictionary<NSString *, NSNumber *> *)sanitizedPermissionsDictionary:(NSDictionary *)permissions;

/// Build a permissions dictionary from Firestore document snapshots.
+ (NSMutableDictionary<NSString *, NSNumber *> *)permissionsDictionaryFromDocuments:(NSArray<FIRDocumentSnapshot *> *)documents;

@end

NS_ASSUME_NONNULL_END
