//
//  PPRolePermission.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 02/09/2025.
//


// In PPRolePermission.m
#import "PPRolePermission.h"

// ===== Permission Keys =====
NSString * const kPermPostAds      = @"PostAds";
NSString * const kPermSellNew      = @"SellNew";
NSString * const kPermSellUsed     = @"SellUsed";
NSString * const kPermAdoption     = @"Adoption";

NSString * const kPermManageStore  = @"ManageStore";
NSString * const kPermModeration   = @"Moderation";
NSString * const kPermAdminAll     = @"AdminAll";
NSString * const kPermManageFood   = @"ManageFood";
NSString * const kPermManageServices = @"ManageServices";
NSString * const kPermProduction   = @"production";

@implementation PPRolePermission


// RPManager.m
+  (NSArray<NSString *> *)defaultPermissionsForRole:(UserRole)role {
    NSMutableArray<NSString *> *defaults = [NSMutableArray array];

    // base defaults shared by many roles
    [defaults addObject:kPermPostAds];
    [defaults addObject:kPermProduction];
    [defaults addObject:kPermAdoption];
    [defaults addObject:kPermSellUsed];

    switch (role) {
        case UserRoleOwner:
            [defaults addObjectsFromArray:@[
                kPermSellNew,
                kPermManageServices
            ]];
            break;

        case UserRoleVet:
            [defaults addObject:kPermManageServices];
            break;

        case UserRoleModerator:
            [defaults addObject:kPermModeration];
            break;

        case UserRoleAdmin:
            [defaults addObjectsFromArray:@[
                kPermSellNew,
                kPermModeration,
                kPermManageStore,
                kPermManageServices,
                kPermAdminAll,
                kPermProduction
            ]];
            break;

        case UserRoleStoreManager:
            [defaults addObjectsFromArray:@[
                kPermSellNew,
                kPermManageStore,
                kPermManageServices
            ]];
            break;

        case UserRoleFoodManager:
            [defaults addObjectsFromArray:@[
                kPermSellNew,
                kPermManageStore,
                kPermManageFood,
                kPermManageServices,
                kPermProduction
            ]];
            break;

        case UserRoleSuperAdmin: // ⬅️ NEW
            [defaults removeAllObjects];
            [defaults addObjectsFromArray:@[
                kPermPostAds,
                kPermSellNew,
                kPermSellUsed,
                kPermAdoption,
                kPermModeration,
                kPermManageStore,
                kPermManageFood,
                kPermManageServices,
                kPermProduction,
                kPermAdminAll  // grant all
            ]];
            break;

        case UserRoleUser:
        case UserRoleUnknown:
        default:
            break;
    }
    DLog(@"[PERM_SUB_COLL] defaultPermissionsForRole role=%ld -> %@",
         (long)role, defaults);
    return defaults;
}



// PPRolePermission.m
+ (NSString *)roleName:(UserRole)role {
    switch (role) {
        case UserRoleUser:         return @"user";
        case UserRoleOwner:        return @"owner";
        case UserRoleVet:          return @"vet";
        case UserRoleModerator:    return @"moderator";
        case UserRoleAdmin:        return @"admin";
        case UserRoleStoreManager: return @"storemanager";
        case UserRoleFoodManager:  return @"foodmanager";
        case UserRoleSuperAdmin:   return @"superadmin";   // ⬅️ NEW
        default:                   return @"unknown";
    }
}

+ (UserRole)roleFromName:(NSString *)name {
    NSString *n = name.lowercaseString ?: @"";
    if ([n isEqualToString:@"user"])          return UserRoleUser;
    if ([n isEqualToString:@"owner"])          return UserRoleOwner;
    if ([n isEqualToString:@"vet"])           return UserRoleVet;
    if ([n isEqualToString:@"moderator"])     return UserRoleModerator;
    if ([n isEqualToString:@"admin"])         return UserRoleAdmin;
    if ([n isEqualToString:@"storemanager"])  return UserRoleStoreManager;
    if ([n isEqualToString:@"foodmanager"])   return UserRoleFoodManager;
    if ([n isEqualToString:@"superadmin"])    return UserRoleSuperAdmin; // ⬅️ NEW
    return UserRoleUnknown;
}



+ (BOOL)role:(UserRole)role hasPermission:(NSString *)permKey {
    if (permKey.length == 0) return NO;
    return [[self defaultPermissionsForRole:role] containsObject:permKey];
}


+ (NSString *)localizedRoleName:(UserRole)role {
    switch (role) {
        case UserRoleUser:         return kLang(@"Role_User");
        case UserRoleOwner:        return kLang(@"Role_Owner");
        case UserRoleVet:          return kLang(@"Role_Vet");
        case UserRoleModerator:    return kLang(@"Role_Moderator");
        case UserRoleAdmin:        return kLang(@"Role_Admin");
        case UserRoleStoreManager: return kLang(@"Role_StoreManager");
        case UserRoleFoodManager:  return kLang(@"Role_FoodManager");
        case UserRoleSuperAdmin:   return kLang(@"Role_SuperAdmin");
        case UserRoleUnknown:
        default:                   return kLang(@"Role_Title");
    }
}

+ (NSString *)localizedRoleDescription:(UserRole)role {
    switch (role) {
        case UserRoleUser:         return kLang(@"Role_User_Desc");
        case UserRoleOwner:        return kLang(@"Role_Owner_Desc");
        case UserRoleVet:          return kLang(@"Role_Vet_Desc");
        case UserRoleModerator:    return kLang(@"Role_Moderator_Desc");
        case UserRoleAdmin:        return kLang(@"Role_Admin_Desc");
        case UserRoleStoreManager: return kLang(@"Role_StoreManager_Desc");
        case UserRoleFoodManager:  return kLang(@"Role_FoodManager_Desc");
        case UserRoleSuperAdmin:   return kLang(@"Role_SuperAdmin_Desc");
        case UserRoleUnknown:
        default:                   return @"";
    }
}



@end
