#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UserRole) {
    UserRoleUnknown = 0,
    UserRoleUser = 1,
    UserRoleOwner = 2,
    UserRoleVet = 3,
    UserRoleModerator = 4,
    UserRoleAdmin = 5,
    UserRoleStoreManager = 6,
    UserRoleFoodManager = 7,
    UserRoleSuperAdmin = 8
};

typedef NS_OPTIONS(NSUInteger, UserPermission) {
    UserPermissionNone = 0,
    UserPermissionPostAds = 1 << 0,
    UserPermissionSellNew = 1 << 1,
    UserPermissionSellUsed = 1 << 2,
    UserPermissionAdoption = 1 << 3,
    UserPermissionManageStore = 1 << 4,
    UserPermissionModeration = 1 << 5,
    UserPermissionAdminAll = 1 << 6,
    UserPermissionManageFood = 1 << 7,
    UserPermissionManageServices = 1 << 8,
    UserPermissionProduction = 1 << 9
};

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

FOUNDATION_EXPORT NSString *PPCanonicalPermissionName(NSString *rawName);

static NSString * const kPPUsersCol = @"UsersCol";
static NSString * const kPPPermsSubCol = @"permissions";
static NSString * const kPPLegacyPermsSubCol = @"PermisstionsCol";
static NSString * const kPPLegacyPermsSubColAlt = @"PermissionsCol";
static NSString * const kPPPermAdminAll = @"AdminAll";

static inline BOOL PPIsAllowedAdminRole(UserRole role) {
    switch (role) {
        case UserRoleOwner:
        case UserRoleVet:
        case UserRoleModerator:
        case UserRoleAdmin:
        case UserRoleStoreManager:
        case UserRoleFoodManager:
        case UserRoleSuperAdmin:
            return YES;
        default:
            return NO;
    }
}

static inline UserRole PPParseRoleFromUserDoc(NSDictionary * _Nullable doc) {
    if (![doc isKindOfClass:NSDictionary.class]) return UserRoleUnknown;
    NSDictionary *claims = [doc[@"claims"] isKindOfClass:NSDictionary.class] ? doc[@"claims"] : nil;
    id roleValue = doc[@"roleValue"] ?: doc[@"role"] ?: claims[@"roleValue"] ?: claims[@"role"];
    if ([roleValue isKindOfClass:NSNumber.class]) {
        NSInteger value = [roleValue integerValue];
        return (value >= UserRoleUnknown && value <= UserRoleSuperAdmin)
            ? (UserRole)value
            : UserRoleUnknown;
    }

    BOOL superAdmin = [doc[@"isSuperAdmin"] boolValue] ||
                      [doc[@"superAdmin"] boolValue] ||
                      [doc[@"superadmin"] boolValue] ||
                      [claims[@"isSuperAdmin"] boolValue] ||
                      [claims[@"superAdmin"] boolValue] ||
                      [claims[@"superadmin"] boolValue];
    if (superAdmin) return UserRoleSuperAdmin;

    BOOL admin = [doc[@"isAdmin"] boolValue] ||
                 [doc[@"admin"] boolValue] ||
                 [claims[@"isAdmin"] boolValue] ||
                 [claims[@"admin"] boolValue];
    if (admin) return UserRoleAdmin;

    NSString *name = [doc[@"roleName"] isKindOfClass:NSString.class] ? doc[@"roleName"] : nil;
    name = name.length > 0 ? name : ([doc[@"role"] isKindOfClass:NSString.class] ? doc[@"role"] : nil);
    name = name.length > 0 ? name : ([claims[@"roleName"] isKindOfClass:NSString.class] ? claims[@"roleName"] : nil);
    name = name.length > 0 ? name : ([claims[@"role"] isKindOfClass:NSString.class] ? claims[@"role"] : nil);
    NSString *normalized = name.lowercaseString;
    if ([normalized isEqualToString:@"admin"]) return UserRoleAdmin;
    if ([normalized isEqualToString:@"superadmin"] || [normalized isEqualToString:@"super_admin"]) return UserRoleSuperAdmin;
    if ([normalized isEqualToString:@"moderator"]) return UserRoleModerator;
    if ([normalized isEqualToString:@"owner"]) return UserRoleOwner;
    if ([normalized isEqualToString:@"vet"]) return UserRoleVet;
    if ([normalized isEqualToString:@"storemanager"] || [normalized isEqualToString:@"store_manager"]) return UserRoleStoreManager;
    if ([normalized isEqualToString:@"foodmanager"] || [normalized isEqualToString:@"food_manager"]) return UserRoleFoodManager;
    if ([normalized isEqualToString:@"user"]) return UserRoleUser;
    return UserRoleUser;
}

static inline BOOL PPBoolFromClaim(NSDictionary * _Nullable claims, NSString *key) {
    id value = claims[key];
    if ([value isKindOfClass:NSNumber.class]) return [value boolValue];
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = [value lowercaseString];
        return [normalized isEqualToString:@"1"] ||
               [normalized isEqualToString:@"true"] ||
               [normalized isEqualToString:@"yes"];
    }
    return NO;
}

@interface PPRolePermission : NSObject
+ (NSString *)localizedRoleName:(UserRole)role;
+ (NSString *)localizedRoleDescription:(UserRole)role;
+ (NSArray<NSString *> *)defaultPermissionsForRole:(UserRole)role;
+ (NSString *)roleName:(UserRole)role;
+ (UserRole)roleFromName:(NSString *)name;
+ (BOOL)role:(UserRole)role hasPermission:(NSString *)permKey;
@end

NS_ASSUME_NONNULL_END
