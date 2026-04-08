//
//  PPRolePermission.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 02/09/2025.
//


// In PPRolePermission.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// ===== Roles =====
typedef NS_ENUM(NSInteger, UserRole) {
    UserRoleUnknown     = 0,
    UserRoleUser        = 1,
    UserRoleOwner       = 2,
    UserRoleVet         = 3,
    UserRoleModerator   = 4,
    UserRoleAdmin       = 5,
    UserRoleStoreManager = 6,   // 🏪 Manage accessories / stock
    UserRoleFoodManager  = 7,    // 🍖 Manage food products
    UserRoleSuperAdmin   = 8   // ⬅️ NEW

};



/// ===== Permissions (bitmask) =====
typedef NS_OPTIONS(NSUInteger, UserPermission) {
    UserPermissionNone         = 0,
    UserPermissionPostAds      = 1 << 0,
    UserPermissionSellNew      = 1 << 1,
    UserPermissionSellUsed     = 1 << 2,
    UserPermissionAdoption     = 1 << 3,
    UserPermissionManageStore  = 1 << 4,
    UserPermissionModeration   = 1 << 5,
    UserPermissionAdminAll     = 1 << 6,
    UserPermissionManageFood   = 1 << 7,
    UserPermissionManageServices = 1 << 8,
    UserPermissionProduction   = 1 << 9,
};

/// Canonical Firestore permission keys

extern NSString * const kPermAdminAll;
extern NSString * const kPermPostAds;
extern NSString * const kPermSellNew;
extern NSString * const kPermSellUsed;
extern NSString * const kPermAdoption;
extern NSString * const kPermManageStore;
extern NSString * const kPermModeration;
extern NSString * const kPermManageFood;
extern NSString * const kPermManageServices;
extern NSString * const kPermProduction;

#pragma mark - Admin gate constants + helpers

// Firestore layout
static NSString * const kPPUsersCol          = @"UsersCol";
static NSString * const kPPPermsSubCol       = @"permissions";
static NSString * const kPPLegacyPermsSubCol = @"PermisstionsCol";
static NSString * const kPPLegacyPermsSubColAlt = @"PermissionsCol";
static NSString * const kPPPermAdminAll      = @"AdminAll";
// Allowed roles for PP Admin
// AdminLoginViewController.m

static inline BOOL PPIsAllowedAdminRole(UserRole r) {
    switch (r) {
        case UserRoleOwner:
        case UserRoleVet:
        case UserRoleModerator:
        case UserRoleAdmin:
        case UserRoleStoreManager:
        case UserRoleFoodManager:
        case UserRoleSuperAdmin:   // ⬅️ NEW
            return YES;
        default:
            return NO;
    }
}

static inline UserRole PPParseRoleFromUserDoc(NSDictionary *doc) {
    if (!doc) return UserRoleUnknown;

    NSDictionary *claims = [doc[@"claims"] isKindOfClass:NSDictionary.class] ? (NSDictionary *)doc[@"claims"] : nil;

    NSNumber *roleVal = (NSNumber *)doc[@"roleValue"];
    if (![roleVal isKindOfClass:NSNumber.class]) {
        roleVal = (NSNumber *)doc[@"role"]; // legacy
    }
    if (![roleVal isKindOfClass:NSNumber.class]) {
        roleVal = (NSNumber *)claims[@"roleValue"];
    }
    if (![roleVal isKindOfClass:NSNumber.class]) {
        roleVal = (NSNumber *)claims[@"role"];
    }
    if ([roleVal isKindOfClass:NSNumber.class]) {
        return (UserRole)roleVal.integerValue;
    }

    BOOL isSuperAdmin = [doc[@"isSuperAdmin"] boolValue] ||
                        [doc[@"superAdmin"] boolValue] ||
                        [doc[@"superadmin"] boolValue] ||
                        [claims[@"isSuperAdmin"] boolValue] ||
                        [claims[@"superAdmin"] boolValue] ||
                        [claims[@"superadmin"] boolValue];
    if (isSuperAdmin) return UserRoleSuperAdmin;

    BOOL isAdmin = [doc[@"isAdmin"] boolValue] ||
                   [doc[@"admin"] boolValue] ||
                   [claims[@"isAdmin"] boolValue] ||
                   [claims[@"admin"] boolValue];
    if (isAdmin) return UserRoleAdmin; // legacy mirror if no explicit value

    NSString *name = (NSString *)doc[@"roleName"];
    if (![name isKindOfClass:NSString.class]) {
        name = (NSString *)doc[@"role"];
    }
    if (![name isKindOfClass:NSString.class]) {
        name = (NSString *)claims[@"roleName"];
    }
    if (![name isKindOfClass:NSString.class]) {
        name = (NSString *)claims[@"role"];
    }
    if ([name isKindOfClass:NSString.class]) {
        NSString *n = name.lowercaseString;
        if ([n isEqualToString:@"admin"])        return UserRoleAdmin;
        if ([n isEqualToString:@"superadmin"])   return UserRoleSuperAdmin; // ⬅️ NEW
        if ([n isEqualToString:@"moderator"])    return UserRoleModerator;
        if ([n isEqualToString:@"owner"])        return UserRoleOwner;
        if ([n isEqualToString:@"vet"])          return UserRoleVet;
        if ([n isEqualToString:@"storemanager"]) return UserRoleStoreManager;
        if ([n isEqualToString:@"foodmanager"])  return UserRoleFoodManager;
    }
    return UserRoleUser;
}

static inline BOOL PPBoolFromClaim(NSDictionary *claims, NSString *key) {
    id val = claims[key];
    if (!val || val == [NSNull null]) return NO;
    if ([val isKindOfClass:[NSNumber class]]) return [(NSNumber *)val boolValue];
    if ([val isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)val lowercaseString];
        return [s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"];
    }
    return NO;
}


/// Helpers
@interface PPRolePermission : NSObject
+ (NSString *)localizedRoleName:(UserRole)role;
+ (NSString *)localizedRoleDescription:(UserRole)role;
/// Default permissions given to a role
+ (NSArray<NSString *> *)defaultPermissionsForRole:(UserRole)role;

/// Map role -> human readable
+ (NSString *)roleName:(UserRole)role;

/// Check if role inherently has a permission
+ (BOOL)role:(UserRole)role hasPermission:(NSString *)permKey;


@end

NS_ASSUME_NONNULL_END
