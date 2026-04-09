//
//  PPUserPermissionsManager.m
//  PurePets
//
//  Extracted from UserModel.m — Phase 2A cleanup.
//  Owns all Firestore permission fetching, listening, writing, and checking.
//

#import "PPUserPermissionsManager.h"
#import "UserModel.h"
#import "PPRolePermission.h"
@import FirebaseFirestore;
#import <os/log.h>

// ---------------------------------------------------------------------------
#pragma mark - Logging
// ---------------------------------------------------------------------------

static os_log_t PPPermissionsManagerLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.purepets.ios", "PermissionsManager");
    });
    return log;
}

// ---------------------------------------------------------------------------
#pragma mark - Constants
// ---------------------------------------------------------------------------

static NSString *const PPPermissionsManagerErrorDomain = @"PPUserPermissionsManager";
static NSString *const kUserPermissionAllowedKey = @"allowed";

// ---------------------------------------------------------------------------
#pragma mark - Static Helpers
// ---------------------------------------------------------------------------

static inline BOOL PPUserBoolValue(id _Nullable value) {
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

// ---------------------------------------------------------------------------
#pragma mark - Legacy Name Functions (moved from UserModel.m)
// ---------------------------------------------------------------------------

static NSString *PPCanonicalPermissionName(NSString *rawName) {
    NSString *name = [PPSafeString(rawName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) return @"";
    NSString *canonical = nil;
    if ([name isEqualToString:@"ManageUsers"]) canonical = kPermAdoption;
    else if ([name isEqualToString:@"ManageNotificatiuons"] || [name isEqualToString:@"ManageNotifications"]) canonical = kPermModeration;
    else if ([name isEqualToString:@"ManageBanners"]) canonical = kPermPostAds;
    else if ([name isEqualToString:@"Prodection"]) canonical = kPermProduction;
    if (canonical) {
        os_log_info(PPPermissionsManagerLog(), "Canonicalized legacy name '%{public}@' → '%{public}@'", name, canonical);
        return canonical;
    }
    return name;
}

static NSString *PPLegacyPermissionName(NSString *canonicalName) {
    NSString *name = [PPSafeString(canonicalName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) return @"";
    if ([name isEqualToString:kPermAdoption]) return @"ManageUsers";
    if ([name isEqualToString:kPermModeration]) return @"ManageNotificatiuons";
    if ([name isEqualToString:kPermPostAds]) return @"ManageBanners";
    if ([name isEqualToString:kPermProduction]) return @"Prodection";
    return name;
}

static NSArray<NSString *> *PPLegacyPermissionNames(NSString *canonicalName) {
    NSString *primary = PPLegacyPermissionName(canonicalName);
    if (primary.length == 0) {
        return @[];
    }
    if ([canonicalName isEqualToString:kPermModeration]) {
        return @[primary, @"ManageNotifications"];
    }
    return @[primary];
}

// ---------------------------------------------------------------------------
#pragma mark - Collection Helpers
// ---------------------------------------------------------------------------

static FIRCollectionReference * _Nullable PPPermissionsCollection(NSString *uid) {
    if (uid.length == 0) return nil;
    FIRFirestore *db = [FIRFirestore firestore];
    return [[[db collectionWithPath:kPPUsersCol] documentWithPath:uid] collectionWithPath:kPPPermsSubCol];
}

static FIRCollectionReference * _Nullable PPLegacyPermissionsCollection(NSString *uid) {
    if (uid.length == 0) return nil;
    FIRFirestore *db = [FIRFirestore firestore];
    return [[[db collectionWithPath:kPPUsersCol] documentWithPath:uid] collectionWithPath:kPPLegacyPermsSubCol];
}

static FIRCollectionReference * _Nullable PPLegacyPermissionsCollectionAlt(NSString *uid) {
    if (uid.length == 0) return nil;
    FIRFirestore *db = [FIRFirestore firestore];
    return [[[db collectionWithPath:kPPUsersCol] documentWithPath:uid] collectionWithPath:kPPLegacyPermsSubColAlt];
}

// ---------------------------------------------------------------------------
#pragma mark - Error Helper
// ---------------------------------------------------------------------------

static NSError *PPPermError(NSInteger code, NSString *key) {
    return [NSError errorWithDomain:PPPermissionsManagerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: kLang(key)}];
}

// ---------------------------------------------------------------------------
#pragma mark - PPCompositeListenerRegistration (moved from UserModel.m)
// ---------------------------------------------------------------------------

@interface PPCompositeListenerRegistration : NSObject <FIRListenerRegistration>
@property (nonatomic, strong) NSArray<id<FIRListenerRegistration>> *registrations;
- (instancetype)initWithRegistrations:(NSArray<id<FIRListenerRegistration>> *)registrations;
@end

@implementation PPCompositeListenerRegistration

- (instancetype)initWithRegistrations:(NSArray<id<FIRListenerRegistration>> *)registrations {
    self = [super init];
    if (self) {
        _registrations = registrations ?: @[];
    }
    return self;
}

- (void)remove {
    for (id<FIRListenerRegistration> registration in self.registrations) {
        [registration remove];
    }
    self.registrations = @[];
}

@end

// ---------------------------------------------------------------------------
#pragma mark - PPUserPermissionsManager Private
// ---------------------------------------------------------------------------

@interface PPUserPermissionsManager ()
@property (nonatomic, weak) UserModel *listeningUser;
@property (nonatomic, strong) id<FIRListenerRegistration> compositeListener;
@property (nonatomic, strong) NSDate *lastPermissionWriteDate;
@end

// ---------------------------------------------------------------------------
#pragma mark - PPUserPermissionsManager
// ---------------------------------------------------------------------------

@implementation PPUserPermissionsManager

#pragma mark - Fetch

- (void)fetchPermissionsForUser:(UserModel *)user
                     completion:(void (^)(NSDictionary<NSString *, NSNumber *> *perms,
                                          NSError * _Nullable error))completion {
    NSString *uid = user.ID;
    FIRCollectionReference *canonicalCollection = PPPermissionsCollection(uid);
    if (!canonicalCollection) {
        if (completion) {
            completion(@{}, PPPermError(404, @"error_missing_uid"));
        }
        return;
    }
    FIRCollectionReference *legacyCollection = PPLegacyPermissionsCollection(uid);
    FIRCollectionReference *legacyCollectionAlt = PPLegacyPermissionsCollectionAlt(uid);

    dispatch_group_t group = dispatch_group_create();
    __block NSArray<FIRDocumentSnapshot *> *canonicalDocs = @[];
    __block NSArray<FIRDocumentSnapshot *> *legacyDocs = @[];
    __block NSArray<FIRDocumentSnapshot *> *legacyAltDocs = @[];
    __block NSError *canonicalError = nil;

    dispatch_group_enter(group);
    [canonicalCollection getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        canonicalError = error;
        canonicalDocs = snapshot.documents ?: @[];
        dispatch_group_leave(group);
    }];

    if (legacyCollection) {
        dispatch_group_enter(group);
        [legacyCollection getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (!error) {
                legacyDocs = snapshot.documents ?: @[];
            }
            dispatch_group_leave(group);
        }];
    }

    if (legacyCollectionAlt) {
        dispatch_group_enter(group);
        [legacyCollectionAlt getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (!error) {
                legacyAltDocs = snapshot.documents ?: @[];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (canonicalError) {
            if (completion) completion(@{}, canonicalError);
            return;
        }

        if (legacyDocs.count > 0) {
            os_log_info(PPPermissionsManagerLog(), "Legacy PermisstionsCol returned %zu docs for user %{public}@",
                        (unsigned long)legacyDocs.count, uid);
        }
        if (legacyAltDocs.count > 0) {
            os_log_info(PPPermissionsManagerLog(), "Legacy PermissionsCol returned %zu docs for user %{public}@",
                        (unsigned long)legacyAltDocs.count, uid);
        }

        NSMutableDictionary<NSString *, NSNumber *> *perms = [PPUserPermissionsManager permissionsDictionaryFromDocuments:legacyDocs];
        [perms addEntriesFromDictionary:[PPUserPermissionsManager permissionsDictionaryFromDocuments:legacyAltDocs]];
        [perms addEntriesFromDictionary:[PPUserPermissionsManager permissionsDictionaryFromDocuments:canonicalDocs]];
        user.permissions = [perms copy];
        if (completion) completion([perms copy], nil);
    });
}

#pragma mark - Listen

- (void)startListeningPermissionsForUser:(UserModel *)user
                                onChange:(void (^)(NSDictionary<NSString *, NSNumber *> *perms))onChange {
    [self stopListening];

    NSString *uid = user.ID;
    FIRCollectionReference *canonicalCollection = PPPermissionsCollection(uid);
    if (!canonicalCollection) {
        return;
    }
    FIRCollectionReference *legacyCollection = PPLegacyPermissionsCollection(uid);
    FIRCollectionReference *legacyCollectionAlt = PPLegacyPermissionsCollectionAlt(uid);

    self.listeningUser = user;

    __weak typeof(self) weakSelf = self;
    __block BOOL isRefreshing = NO;
    __block BOOL needsRefresh = NO;
    __block void (^refreshMergedPermissions)(void) = nil;
    refreshMergedPermissions = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        UserModel *strongUser = strongSelf.listeningUser;
        if (!strongSelf || !strongUser) return;

        if (isRefreshing) {
            needsRefresh = YES;
            return;
        }

        isRefreshing = YES;
        [strongSelf fetchPermissionsForUser:strongUser completion:^(NSDictionary<NSString *,NSNumber *> * _Nonnull perms, NSError * _Nullable error) {
            isRefreshing = NO;
            if (!error && onChange) {
                onChange(perms ?: @{});
            }
            if (needsRefresh) {
                needsRefresh = NO;
                refreshMergedPermissions();
            }
        }];
    };

    NSMutableArray<id<FIRListenerRegistration>> *listeners = [NSMutableArray array];
    id<FIRListenerRegistration> canonicalListener =
        [canonicalCollection addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) return;
            (void)snapshot;
            refreshMergedPermissions();
        }];
    if (canonicalListener) {
        [listeners addObject:canonicalListener];
    }

    if (legacyCollection) {
        id<FIRListenerRegistration> legacyListener =
            [legacyCollection addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
                if (error) return;
                (void)snapshot;
                refreshMergedPermissions();
            }];
        if (legacyListener) {
            [listeners addObject:legacyListener];
        }
    }

    if (legacyCollectionAlt) {
        id<FIRListenerRegistration> legacyAltListener =
            [legacyCollectionAlt addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
                if (error) return;
                (void)snapshot;
                refreshMergedPermissions();
            }];
        if (legacyAltListener) {
            [listeners addObject:legacyAltListener];
        }
    }

    PPCompositeListenerRegistration *composite = [[PPCompositeListenerRegistration alloc] initWithRegistrations:listeners];
    self.compositeListener = composite;
    user.permissionsListener = composite;
    refreshMergedPermissions();
}

- (void)stopListening {
    [self.compositeListener remove];
    self.compositeListener = nil;
    self.listeningUser.permissionsListener = nil;
    self.listeningUser = nil;
}

#pragma mark - Write

- (void)setPermissionNamed:(NSString *)permName
                   allowed:(BOOL)allowed
                   forUser:(UserModel *)user
                completion:(void (^)(NSError * _Nullable))completion {
    // SECURITY: Debounce — reject writes less than 2 seconds apart
    static const NSTimeInterval kMinPermissionWriteInterval = 2.0;
    NSDate *now = [NSDate date];
    if (self.lastPermissionWriteDate &&
        [now timeIntervalSinceDate:self.lastPermissionWriteDate] < kMinPermissionWriteInterval) {
        NSLog(@"[PPUserPermissionsManager] ⚠️ setPermissionNamed: throttled — too frequent (%.1fs since last write).",
              [now timeIntervalSinceDate:self.lastPermissionWriteDate]);
        if (completion) {
            completion(PPPermError(429, @"error_permission_write_throttled"));
        }
        return;
    }
    self.lastPermissionWriteDate = now;

    NSString *uid = user.ID;
    NSString *cleanPermission = [PPSafeString(permName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *canonicalPermission = PPCanonicalPermissionName(cleanPermission);
    FIRCollectionReference *permissionsCollection = PPPermissionsCollection(uid);
    FIRCollectionReference *legacyCollection = PPLegacyPermissionsCollection(uid);
    FIRCollectionReference *legacyCollectionAlt = PPLegacyPermissionsCollectionAlt(uid);

    if (canonicalPermission.length == 0 || !permissionsCollection) {
        if (completion) {
            completion(PPPermError(404, @"error_missing_uid_or_perm"));
        }
        return;
    }

    NSMutableDictionary *payload = [@{
        kUserPermissionAllowedKey: @(allowed),
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } mutableCopy];

    FIRWriteBatch *batch = [[FIRFirestore firestore] batch];
    [batch setData:payload
       forDocument:[permissionsCollection documentWithPath:canonicalPermission]
             merge:YES];

    NSArray<NSString *> *legacyPermissionNames = PPLegacyPermissionNames(canonicalPermission);
    NSMutableArray<FIRCollectionReference *> *legacyCollections = [NSMutableArray array];
    if (legacyCollection) {
        [legacyCollections addObject:legacyCollection];
    }
    if (legacyCollectionAlt) {
        [legacyCollections addObject:legacyCollectionAlt];
    }

    for (FIRCollectionReference *collection in legacyCollections) {
        for (NSString *legacyPermission in legacyPermissionNames) {
            if (legacyPermission.length == 0) {
                continue;
            }
            [batch setData:payload
               forDocument:[collection documentWithPath:legacyPermission]
                     merge:YES];
        }
    }

    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (!error) {
            NSMutableDictionary *updated = [user.permissions mutableCopy] ?: [NSMutableDictionary dictionary];
            updated[canonicalPermission] = @(allowed);
            user.permissions = [updated copy];
        }
        if (completion) {
            completion(error);
        }
    }];
}

#pragma mark - Check

+ (BOOL)user:(UserModel *)user hasPermissionNamed:(NSString *)permName {
    NSString *cleanPermission = PPCanonicalPermissionName(permName);
    if (cleanPermission.length == 0) {
        return NO;
    }

    NSDictionary<NSString *, id> *permissions =
        [user.permissions isKindOfClass:NSDictionary.class] ? user.permissions : @{};

    id explicitPermission = permissions[cleanPermission];
    if ([explicitPermission respondsToSelector:@selector(boolValue)]) {
        return [explicitPermission boolValue];
    }

    // AdminAll remains a global override only when explicitly set.
    if (![cleanPermission isEqualToString:kPermAdminAll]) {
        id adminAllPermission = permissions[kPermAdminAll];
        if ([adminAllPermission respondsToSelector:@selector(boolValue)]) {
            return [adminAllPermission boolValue];
        }
    }

    // If we have explicit permission docs but this key is missing,
    // fall back to role-based defaults rather than denying outright.
    // This prevents lockouts from partial permission migration.
    return [PPRolePermission role:user.role hasPermission:cleanPermission];
}

+ (BOOL)user:(UserModel *)user hasAnyPermissionInKeys:(NSArray<NSString *> *)permNames {
    for (NSString *name in permNames ?: @[]) {
        if ([self user:user hasPermissionNamed:name]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Name Helpers

+ (NSString *)canonicalPermissionName:(NSString *)rawName {
    return PPCanonicalPermissionName(rawName);
}

#pragma mark - Sanitize

+ (NSDictionary<NSString *, NSNumber *> *)sanitizedPermissionsDictionary:(NSDictionary *)permissions {
    NSMutableDictionary<NSString *, NSNumber *> *sanitized = [NSMutableDictionary dictionary];
    if (![permissions isKindOfClass:[NSDictionary class]] || permissions.count == 0) {
        return sanitized;
    }

    [permissions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *permName = PPCanonicalPermissionName(PPSafeString(key));
        if (permName.length == 0) {
            return;
        }

        BOOL allowed = NO;
        if ([obj isKindOfClass:NSDictionary.class]) {
            NSDictionary *nested = PPSafeDict(obj);
            allowed = PPUserBoolValue(nested[kUserPermissionAllowedKey]);
        } else {
            allowed = PPUserBoolValue(obj);
        }
        sanitized[permName] = @(allowed);
    }];

    return sanitized;
}

+ (NSMutableDictionary<NSString *, NSNumber *> *)permissionsDictionaryFromDocuments:(NSArray<FIRDocumentSnapshot *> *)documents {
    NSMutableDictionary<NSString *, NSNumber *> *perms = [NSMutableDictionary dictionary];

    for (FIRDocumentSnapshot *doc in documents) {
        NSString *permName = PPCanonicalPermissionName(PPSafeString(doc.documentID));
        if (permName.length == 0) {
            continue;
        }

        NSDictionary *docData = PPSafeDict(doc.data);
        BOOL allowed = PPUserBoolValue(docData[kUserPermissionAllowedKey]);
        perms[permName] = @(allowed);
    }

    return perms;
}

@end
