//
//  PPUserModelCache.m
//  PurePets
//
//  Extracted from UserModel.m — Phase 2A cleanup.
//  Owns all NSKeyedArchiver disk-caching logic for UserModel.
//

#import "PPUserModelCache.h"
#import "UserModel.h"
#import "PPRolePermission.h"

// ---------------------------------------------------------------------------
#pragma mark - Static Helpers (moved from UserModel.m)
// ---------------------------------------------------------------------------

static NSString *PPUserSanitizedCacheID(NSString *identifier) {
    if (identifier.length == 0) {
        return @"";
    }

    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/:?%*|\"<>"];
    NSArray<NSString *> *parts = [identifier componentsSeparatedByCharactersInSet:invalid];
    NSString *sanitized = [parts componentsJoinedByString:@"_"];
    return sanitized.length ? sanitized : identifier;
}

static NSString *PPCachePathForUID(NSString *uid) {
    NSString *safeUID = PPUserSanitizedCacheID(PPSafeString(uid));
    if (safeUID.length == 0) {
        return @"";
    }

    NSString *dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"UserModel_%@.dat", safeUID]];
}

// ---------------------------------------------------------------------------
#pragma mark - PPUserModelCache
// ---------------------------------------------------------------------------

@implementation PPUserModelCache

+ (nullable UserModel *)loadUserWithUID:(NSString *)uid {
    NSString *path = PPCachePathForUID(uid);
    if (path.length == 0) {
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        return nil;
    }

    UserModel *user = [NSKeyedUnarchiver unarchivedObjectOfClass:UserModel.class fromData:data error:nil];
    if (user) {
        // SECURITY: Zero out privilege-granting flags from disk cache.
        // A jailbroken device could tamper with the .dat file to elevate privileges.
        // The server re-fetch that immediately follows sign-in will restore correct values.
        // Note: isBlocked is intentionally preserved — a tampered cache setting it to NO
        // is harmless because Firestore rules enforce isRequesterBlocked() on all writes.
        user.role = UserRoleUser;
        user.isAdmin = NO;
        user.isSuperAdmin = NO;
        user.permissions = @{};  // Zero out cached permissions — server re-fetch restores correct values
    }
    return user;
}

+ (void)saveUser:(UserModel *)user {
    NSString *uid = PPSafeString(user.ID);
    if (uid.length == 0) {
        return;
    }

    NSString *path = PPCachePathForUID(uid);
    if (path.length == 0) {
        return;
    }

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:user
                                          requiringSecureCoding:YES
                                                          error:nil];
    if (data.length == 0) {
        return;
    }

    [data writeToFile:path atomically:YES];
}

+ (void)clearUserWithUID:(NSString *)uid {
    NSString *path = PPCachePathForUID(uid);
    if (path.length == 0) {
        return;
    }
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

@end
