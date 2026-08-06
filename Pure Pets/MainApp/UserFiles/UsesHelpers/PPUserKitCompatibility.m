#import "PPUserKitCompatibility.h"

NSString * const kPermPostAds = @"PostAds";
NSString * const kPermSellNew = @"SellNew";
NSString * const kPermSellUsed = @"SellUsed";
NSString * const kPermAdoption = @"Adoption";
NSString * const kPermManageStore = @"ManageStore";
NSString * const kPermModeration = @"Moderation";
NSString * const kPermAdminAll = @"AdminAll";
NSString * const kPermManageFood = @"ManageFood";
NSString * const kPermManageServices = @"ManageServices";
NSString * const kPermProduction = @"production";

NSString *PPCanonicalPermissionName(NSString *rawName) {
    NSString *name = [rawName isKindOfClass:NSString.class]
        ? [rawName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (name.length == 0) return @"";
    if ([name isEqualToString:@"ManageUsers"]) return kPermAdoption;
    if ([name isEqualToString:@"ManageNotificatiuons"] ||
        [name isEqualToString:@"ManageNotifications"]) {
        return kPermModeration;
    }
    if ([name isEqualToString:@"ManageBanners"]) return kPermPostAds;
    if ([name isEqualToString:@"Prodection"]) return kPermProduction;
    return name;
}

@implementation PPRolePermission

+ (NSArray<NSString *> *)defaultPermissionsForRole:(UserRole)role {
    NSMutableArray<NSString *> *defaults = [NSMutableArray arrayWithArray:@[
        kPermPostAds, kPermProduction, kPermAdoption, kPermSellUsed
    ]];

    switch (role) {
        case UserRoleOwner:
            [defaults addObjectsFromArray:@[kPermSellNew, kPermManageServices]];
            break;
        case UserRoleVet:
            [defaults addObject:kPermManageServices];
            break;
        case UserRoleModerator:
            [defaults addObject:kPermModeration];
            break;
        case UserRoleAdmin:
            [defaults addObjectsFromArray:@[
                kPermSellNew, kPermModeration, kPermManageStore,
                kPermManageServices, kPermAdminAll
            ]];
            break;
        case UserRoleStoreManager:
            [defaults addObjectsFromArray:@[
                kPermSellNew, kPermManageStore, kPermManageServices
            ]];
            break;
        case UserRoleFoodManager:
            [defaults addObjectsFromArray:@[
                kPermSellNew, kPermManageStore, kPermManageFood,
                kPermManageServices
            ]];
            break;
        case UserRoleSuperAdmin:
            [defaults removeAllObjects];
            [defaults addObjectsFromArray:@[
                kPermPostAds, kPermSellNew, kPermSellUsed, kPermAdoption,
                kPermModeration, kPermManageStore, kPermManageFood,
                kPermManageServices, kPermProduction, kPermAdminAll
            ]];
            break;
        case UserRoleUnknown:
        case UserRoleUser:
            break;
    }
    return defaults;
}

+ (NSString *)roleName:(UserRole)role {
    switch (role) {
        case UserRoleUser: return @"user";
        case UserRoleOwner: return @"owner";
        case UserRoleVet: return @"vet";
        case UserRoleModerator: return @"moderator";
        case UserRoleAdmin: return @"admin";
        case UserRoleStoreManager: return @"storemanager";
        case UserRoleFoodManager: return @"foodmanager";
        case UserRoleSuperAdmin: return @"superadmin";
        default: return @"unknown";
    }
}

+ (UserRole)roleFromName:(NSString *)name {
    NSString *normalized = name.lowercaseString;
    if ([normalized isEqualToString:@"user"]) return UserRoleUser;
    if ([normalized isEqualToString:@"owner"]) return UserRoleOwner;
    if ([normalized isEqualToString:@"vet"]) return UserRoleVet;
    if ([normalized isEqualToString:@"moderator"]) return UserRoleModerator;
    if ([normalized isEqualToString:@"admin"]) return UserRoleAdmin;
    if ([normalized isEqualToString:@"storemanager"] || [normalized isEqualToString:@"store_manager"]) return UserRoleStoreManager;
    if ([normalized isEqualToString:@"foodmanager"] || [normalized isEqualToString:@"food_manager"]) return UserRoleFoodManager;
    if ([normalized isEqualToString:@"superadmin"] || [normalized isEqualToString:@"super_admin"]) return UserRoleSuperAdmin;
    return UserRoleUnknown;
}

+ (BOOL)role:(UserRole)role hasPermission:(NSString *)permKey {
    return [[self defaultPermissionsForRole:role] containsObject:permKey];
}

+ (NSString *)localizedRoleName:(UserRole)role {
    switch (role) {
        case UserRoleUser: return kLang(@"Role_User");
        case UserRoleOwner: return kLang(@"Role_Owner");
        case UserRoleVet: return kLang(@"Role_Vet");
        case UserRoleModerator: return kLang(@"Role_Moderator");
        case UserRoleAdmin: return kLang(@"Role_Admin");
        case UserRoleStoreManager: return kLang(@"Role_StoreManager");
        case UserRoleFoodManager: return kLang(@"Role_FoodManager");
        case UserRoleSuperAdmin: return kLang(@"Role_SuperAdmin");
        default: return kLang(@"Role_Title");
    }
}

+ (NSString *)localizedRoleDescription:(UserRole)role {
    switch (role) {
        case UserRoleAdmin:
        case UserRoleSuperAdmin:
            return kLang(@"Role_Admin_Description");
        case UserRoleOwner:
            return kLang(@"Role_Owner_Description");
        case UserRoleVet:
            return kLang(@"Role_Vet_Description");
        case UserRoleModerator:
            return kLang(@"Role_Moderator_Description");
        case UserRoleStoreManager:
            return kLang(@"Role_StoreManager_Description");
        case UserRoleFoodManager:
            return kLang(@"Role_FoodManager_Description");
        case UserRoleUser:
        default:
            return kLang(@"Role_User_Description");
    }
}

@end
