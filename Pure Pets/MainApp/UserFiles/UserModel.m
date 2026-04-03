//
//  UserModel.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 21/08/2025.
//  Refactored for best practices
//

#import "UserModel.h"

static NSString *const PPUserModelErrorDomain = @"UserModel";

// Model / Firestore keys
static NSString *const kUserKeyID = @"ID";
static NSString *const kUserKeyUID = @"uid";
static NSString *const kUserKeyUserName = @"UserName";
static NSString *const kUserKeyFirstName = @"FirstName";
static NSString *const kUserKeyLastName = @"LastName";
static NSString *const kUserKeyMobileNo = @"MobileNo";
static NSString *const kUserKeyUserEmail = @"UserEmail";
static NSString *const kUserKeyUserImageName = @"UserImageName";
static NSString *const kUserKeyUserAbout = @"UserAbout";
static NSString *const kUserKeyUserImageURL = @"UserImageUrl";
static NSString *const kUserKeyPhotoURL = @"photoURL";
static NSString *const kUserKeyDisplayName = @"displayName";
static NSString *const kUserKeyEmail = @"email";
static NSString *const kUserKeyLoginDate = @"loginDate";
static NSString *const kUserKeyUpdatedAt = @"updatedAt";
static NSString *const kUserKeyCountryID = @"CountryID";
static NSString *const kUserKeyPPUserTokenID = @"PPUserTokenID";
static NSString *const kUserKeyPPAdminTokenID = @"PPAdminTokenID";
static NSString *const kUserKeyRole = @"role";
static NSString *const kUserKeyRoleValue = @"roleValue";
static NSString *const kUserKeyRoleName = @"roleName";
static NSString *const kUserKeyVerified = @"verified";
static NSString *const kUserKeyPlan = @"plan";
static NSString *const kUserKeyLoginSource = @"loginSource";
static NSString *const kUserKeyIsAdmin = @"isAdmin";
static NSString *const kUserKeyIsSuperAdmin = @"isSuperAdmin";
static NSString *const kUserKeyIsBlocked = @"isBlocked";
static NSString *const kUserKeyBlocked = @"blocked";
static NSString *const kUserKeyClaims = @"claims";
static NSString *const kUserKeyOnline = @"online";
static NSString *const kUserKeyOnlineStatus = @"onlineStatus";
static NSString *const kUserKeyIsOnline = @"isOnline";
static NSString *const kUserKeyLastSeen = @"lastSeen";
static NSString *const kUserKeyPermissions = @"permissions";
static NSString *const kUserPermissionAllowedKey = @"allowed";

static inline BOOL PPUserBoolValue(id _Nullable value) {
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static id _Nullable PPUserFirstValueForKeys(NSDictionary *dict, NSArray<NSString *> *keys) {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    for (NSString *key in keys) {
        id value = dict[key];
        if (value && value != [NSNull null]) {
            return value;
        }
    }
    return nil;
}

static UserRole PPUserResolvedRoleFromProfileAndClaims(NSDictionary *profile, NSDictionary *claims) {
    BOOL hasProfileRoleValue = PPUserFirstValueForKeys(profile, @[kUserKeyRoleValue, kUserKeyRole, kUserKeyRoleName]) != nil;
    if (hasProfileRoleValue) {
        UserRole role = PPParseRoleFromUserDoc(profile);
        if (role != UserRoleUnknown) {
            return role;
        }
    }

    BOOL hasClaimsRoleValue = PPUserFirstValueForKeys(claims, @[kUserKeyRoleValue, kUserKeyRole, kUserKeyRoleName]) != nil;
    if (hasClaimsRoleValue) {
        UserRole role = PPParseRoleFromUserDoc(claims);
        if (role != UserRoleUnknown) {
            return role;
        }
    }

    UserRole fallbackRole = PPParseRoleFromUserDoc(profile);
    if (fallbackRole != UserRoleUnknown) {
        return fallbackRole;
    }

    fallbackRole = PPParseRoleFromUserDoc(claims);
    return fallbackRole == UserRoleUnknown ? UserRoleUser : fallbackRole;
}

static BOOL PPUserResolvedBoolFromProfileAndClaims(NSDictionary *profile,
                                                   NSArray<NSString *> *profileKeys,
                                                   NSDictionary *claims,
                                                   NSArray<NSString *> *claimKeys,
                                                   BOOL defaultValue,
                                                   BOOL * _Nullable usedProfileValue) {
    id profileValue = PPUserFirstValueForKeys(profile, profileKeys);
    if (profileValue) {
        if (usedProfileValue) *usedProfileValue = YES;
        return PPUserBoolValue(profileValue);
    }
    if (usedProfileValue) *usedProfileValue = NO;

    id claimValue = PPUserFirstValueForKeys(claims, claimKeys);
    if (claimValue) {
        return PPUserBoolValue(claimValue);
    }
    return defaultValue;
}

static NSString *PPCanonicalPermissionName(NSString *rawName) {
    NSString *name = [PPSafeString(rawName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) return @"";
    if ([name isEqualToString:@"ManageUsers"]) return kPermAdoption;
    if ([name isEqualToString:@"ManageNotificatiuons"] || [name isEqualToString:@"ManageNotifications"]) return kPermModeration;
    if ([name isEqualToString:@"ManageBanners"]) return kPermPostAds;
    if ([name isEqualToString:@"Prodection"]) return kPermProduction;
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

static NSDate *_Nullable PPUserDateFromValue(id _Nullable value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:[FIRTimestamp class]]) {
        return ((FIRTimestamp *)value).dateValue;
    }
    return nil;
}

static NSString *PPUserSanitizedCacheID(NSString *identifier) {
    if (identifier.length == 0) {
        return @"";
    }

    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/:?%*|\"<>"];
    NSArray<NSString *> *parts = [identifier componentsSeparatedByCharactersInSet:invalid];
    NSString *sanitized = [parts componentsJoinedByString:@"_"];
    return sanitized.length ? sanitized : identifier;
}

@interface UserModel ()
- (void)pp_applyDefaults;
- (void)pp_applyDictionary:(NSDictionary *)dict;
- (void)pp_applyDictionary:(NSDictionary *)dict fallbackDocumentID:(nullable NSString *)fallbackDocumentID;
- (void)pp_normalizeIdentityFields;
- (NSString *)pp_documentID;
- (NSString *)pp_cacheIdentifier;
- (nullable FIRCollectionReference *)pp_permissionsCollection;
- (nullable FIRCollectionReference *)pp_legacyPermissionsCollection;
- (nullable FIRCollectionReference *)pp_legacyPermissionsCollectionAlt;
+ (NSError *)pp_errorWithCode:(NSInteger)code key:(NSString *)localizedKey;
+ (NSMutableDictionary<NSString *, NSNumber *> *)pp_sanitizedPermissionsDictionary:(NSDictionary *)permissions;
+ (NSMutableDictionary<NSString *, NSNumber *> *)pp_permissionsDictionaryFromDocuments:(NSArray<FIRDocumentSnapshot *> *)documents;
+ (void)pp_dispatchLoadCompletion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
                            user:(UserModel * _Nullable)user
                           error:(NSError * _Nullable)error;
@end

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

@implementation UserModel

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        [self pp_applyDefaults];
    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [self init];
    if (!self) {
        return nil;
    }

    if ([dict isKindOfClass:[NSDictionary class]]) {
        [self pp_applyDictionary:dict fallbackDocumentID:nil];
    }

    return self;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    if (!snapshot.exists) {
        return nil;
    }
    self = [self init];
    if (!self) {
        return nil;
    }
    [self pp_applyDictionary:(snapshot.data ?: @{}) fallbackDocumentID:PPSafeString(snapshot.documentID)];
    return self;
}

- (void)dealloc {
    [self stopListeningPermissions];
}

#pragma mark - Private (Initialization)

- (BOOL)isOnline {
    return self.onlineStatus == OnlineStatusOnline;
}

- (void)setIsOnline:(BOOL)isOnline {
    self.onlineStatus = isOnline ? OnlineStatusOnline : OnlineStatusOffline;
}

- (void)pp_applyDefaults {
    self.ID = @"";
    self.UserName = @"";
    self.UserEmail = @"";
    self.PPUserTokenID = @"";
    self.PPAdminTokenID = @"";
    self.permissions = [NSMutableDictionary dictionary];
    self.Addresses = [NSMutableArray array];
    self.onlineStatus = OnlineStatusOffline;
    self.loginSource = UserLoginSourceUnknown;
}

- (void)pp_applyDictionary:(NSDictionary *)dict {
    [self pp_applyDictionary:dict fallbackDocumentID:nil];
}

- (void)pp_applyDictionary:(NSDictionary *)dict fallbackDocumentID:(nullable NSString *)fallbackDocumentID {
    NSDictionary *safeDict = [dict isKindOfClass:[NSDictionary class]] ? dict : @{};

    NSString *dictID = PPSafeString(safeDict[kUserKeyID]);
    NSString *dictUID = PPSafeString(safeDict[kUserKeyUID]);
    NSString *resolvedID = dictID.length ? dictID : (dictUID.length ? dictUID : PPSafeString(fallbackDocumentID));

    self.ID = resolvedID;

    NSString *serverUserName = PPSafeString(safeDict[kUserKeyUserName]);
    NSString *serverDisplayName = PPSafeString(safeDict[kUserKeyDisplayName]);
    self.UserName = serverUserName.length ? serverUserName : serverDisplayName;

    NSString *serverUserEmail = PPSafeString(safeDict[kUserKeyUserEmail]);
    NSString *serverEmail = PPSafeString(safeDict[kUserKeyEmail]);
    self.UserEmail = serverUserEmail.length ? serverUserEmail : serverEmail;

    self.FirstName = PPSafeString(safeDict[kUserKeyFirstName]);
    self.LastName = PPSafeString(safeDict[kUserKeyLastName]);
    self.MobileNo = PPSafeString(safeDict[kUserKeyMobileNo]);

    NSString *about = PPSafeString(safeDict[kUserKeyUserAbout]);
    self.UserAbout = [about isEqualToString:@"no_value"] ? @"" : about;

    self.UserImageName = PPSafeString(safeDict[kUserKeyUserImageName]);
    self.PPAdminTokenID = PPSafeString(safeDict[kUserKeyPPAdminTokenID]);
    self.PPUserTokenID = PPSafeString(safeDict[kUserKeyPPUserTokenID]);

    NSString *imageURLString = PPSafeString(safeDict[kUserKeyUserImageURL]);
    NSString *photoURLString = PPSafeString(safeDict[kUserKeyPhotoURL]);
    NSString *resolvedImageURL = imageURLString.length ? imageURLString : photoURLString;
    self.UserImageUrl = PPSafeURL(resolvedImageURL);

    self.loginDate = PPUserDateFromValue(safeDict[kUserKeyLoginDate]);
    self.updatedAt = PPUserDateFromValue(safeDict[kUserKeyUpdatedAt]);
    self.CountryID = PPSafeIntegerUniversal(safeDict[kUserKeyCountryID]);

    NSDictionary *claimsDict = PPSafeDict(safeDict[kUserKeyClaims]);
    UserRole resolvedRole = PPUserResolvedRoleFromProfileAndClaims(safeDict, claimsDict);

    BOOL usedProfileIsSuperAdmin = NO;
    BOOL usedProfileIsAdmin = NO;
    BOOL usedProfileIsBlocked = NO;

    BOOL resolvedIsSuperAdmin = PPUserResolvedBoolFromProfileAndClaims(
        safeDict,
        @[kUserKeyIsSuperAdmin, @"superAdmin", @"superadmin"],
        claimsDict,
        @[kUserKeyIsSuperAdmin, @"superAdmin", @"superadmin"],
        NO,
        &usedProfileIsSuperAdmin
    );

    BOOL resolvedIsAdmin = PPUserResolvedBoolFromProfileAndClaims(
        safeDict,
        @[kUserKeyIsAdmin, @"admin"],
        claimsDict,
        @[kUserKeyIsAdmin, @"admin"],
        NO,
        &usedProfileIsAdmin
    );

    BOOL resolvedIsBlocked = PPUserResolvedBoolFromProfileAndClaims(
        safeDict,
        @[kUserKeyIsBlocked, kUserKeyBlocked],
        claimsDict,
        @[kUserKeyIsBlocked, kUserKeyBlocked],
        NO,
        &usedProfileIsBlocked
    );

    if (!usedProfileIsSuperAdmin && resolvedRole == UserRoleSuperAdmin) {
        resolvedIsSuperAdmin = YES;
    }
    if (!usedProfileIsAdmin && (resolvedRole == UserRoleAdmin || resolvedRole == UserRoleSuperAdmin)) {
        resolvedIsAdmin = YES;
    }
    if (resolvedIsSuperAdmin) {
        resolvedIsAdmin = YES;
    }
    if (!usedProfileIsBlocked && !claimsDict.count) {
        resolvedIsBlocked = NO;
    }

    self.role = resolvedRole;
    self.isAdmin = resolvedIsAdmin;
    self.isSuperAdmin = resolvedIsSuperAdmin;
    self.isBlocked = resolvedIsBlocked;
    self.verified = PPUserBoolValue(safeDict[kUserKeyVerified]);
    self.plan = PPSafeString(safeDict[kUserKeyPlan]);
    self.loginSource = PPSafeIntegerUniversal(safeDict[kUserKeyLoginSource]);

    BOOL onlineStatusKeyExists = safeDict[kUserKeyOnlineStatus] != nil;
    if (onlineStatusKeyExists) {
        NSInteger statusValue = PPSafeIntegerUniversal(safeDict[kUserKeyOnlineStatus]);
        self.onlineStatus = statusValue == OnlineStatusOnline ? OnlineStatusOnline : OnlineStatusOffline;
    } else {
        BOOL online = PPUserBoolValue(safeDict[kUserKeyOnline]) || PPUserBoolValue(safeDict[kUserKeyIsOnline]);
        self.onlineStatus = online ? OnlineStatusOnline : OnlineStatusOffline;
    }

    self.lastSeen = PPUserDateFromValue(safeDict[kUserKeyLastSeen]);

    NSDictionary *permDict = PPSafeDict(safeDict[kUserKeyPermissions]);
    self.permissions = [UserModel pp_sanitizedPermissionsDictionary:permDict];

    [self pp_normalizeIdentityFields];
}

- (void)pp_normalizeIdentityFields {
    self.ID = PPSafeString(self.ID);
    self.UserName = PPSafeString(self.UserName);
    self.UserEmail = PPSafeString(self.UserEmail);

    if (self.UserName.length == 0 && self.FirstName.length > 0) {
        self.UserName = self.FirstName;
    }

    if (!self.permissions) {
        self.permissions = [NSMutableDictionary dictionary];
    }
    if (!self.Addresses) {
        self.Addresses = [NSMutableArray array];
    }
}

#pragma mark - Firestore Sync

- (NSDictionary *)toDictionary {
    NSString *documentID = [self pp_documentID];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[kUserKeyID] = documentID ?: @"";
    dict[kUserKeyUserName] = self.UserName ?: @"";
    dict[kUserKeyFirstName] = PPSafeString(self.FirstName);
    dict[kUserKeyLastName] = PPSafeString(self.LastName);
    dict[kUserKeyMobileNo] = PPSafeString(self.MobileNo);
    dict[kUserKeyUserEmail] = self.UserEmail ?: @"";
    dict[kUserKeyUserImageName] = PPSafeString(self.UserImageName);
    dict[kUserKeyUserAbout] = PPSafeString(self.UserAbout);

    dict[kUserKeyUserImageURL] = PPSafeString(self.UserImageUrl.absoluteString);

    if (self.loginDate) {
        dict[kUserKeyLoginDate] = self.loginDate;
    }
    if (self.updatedAt) {
        dict[kUserKeyUpdatedAt] = self.updatedAt;
    }

    dict[kUserKeyCountryID] = @(self.CountryID);
    dict[kUserKeyPPUserTokenID] = self.PPUserTokenID ?: @"";
    dict[kUserKeyRole] = @(self.role);
    dict[kUserKeyVerified] = @(self.verified);
    dict[kUserKeyPlan] = PPSafeString(self.plan);
    dict[kUserKeyLoginSource] = @(self.loginSource);
    dict[kUserKeyIsAdmin] = @(self.isAdmin);
    dict[kUserKeyIsSuperAdmin] = @(self.isSuperAdmin);
    dict[kUserKeyIsBlocked] = @(self.isBlocked);
    dict[kUserKeyPPAdminTokenID] = self.PPAdminTokenID ?: @"";

    // NOTE: Addresses and permissions are stored in dedicated subcollections.
    return dict;
}

- (void)SYNC:(void(^)(NSError * _Nullable error))completion {
    NSString *documentID = [self pp_documentID];
    if (!documentID.length) {
        if (completion) {
            completion([UserModel pp_errorWithCode:400 key:@"error_uid_required"]);
        }
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:kPPUsersCol] documentWithPath:documentID];

    [docRef setData:[self toDictionary] merge:YES completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ [UserModel] SYNC failed: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ [UserModel] SYNC success for ID %@", documentID);
        }
        if (completion) {
            completion(error);
        }
    }];
}

#pragma mark - Permissions

- (void)fetchPermissionsWithCompletion:(void (^)(NSDictionary<NSString *, NSNumber *> *, NSError * _Nullable))completion {
    FIRCollectionReference *canonicalCollection = [self pp_permissionsCollection];
    if (!canonicalCollection) {
        if (completion) {
            completion(@{}, [UserModel pp_errorWithCode:404 key:@"error_missing_uid"]);
        }
        return;
    }
    FIRCollectionReference *legacyCollection = [self pp_legacyPermissionsCollection];
    FIRCollectionReference *legacyCollectionAlt = [self pp_legacyPermissionsCollectionAlt];

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

        NSMutableDictionary<NSString *, NSNumber *> *perms = [UserModel pp_permissionsDictionaryFromDocuments:legacyDocs];
        [perms addEntriesFromDictionary:[UserModel pp_permissionsDictionaryFromDocuments:legacyAltDocs]];
        [perms addEntriesFromDictionary:[UserModel pp_permissionsDictionaryFromDocuments:canonicalDocs]];
        self.permissions = perms;
        if (completion) completion([perms copy], nil);
    });
}

- (void)startListeningPermissionsWithChange:(void (^)(NSDictionary<NSString *, NSNumber *> *))onChange {
    [self stopListeningPermissions];

    FIRCollectionReference *canonicalCollection = [self pp_permissionsCollection];
    if (!canonicalCollection) {
        return;
    }
    FIRCollectionReference *legacyCollection = [self pp_legacyPermissionsCollection];
    FIRCollectionReference *legacyCollectionAlt = [self pp_legacyPermissionsCollectionAlt];

    __weak typeof(self) weakSelf = self;
    __block BOOL isRefreshing = NO;
    __block BOOL needsRefresh = NO;
    __block void (^refreshMergedPermissions)(void) = nil;
    refreshMergedPermissions = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (isRefreshing) {
            needsRefresh = YES;
            return;
        }

        isRefreshing = YES;
        [self fetchPermissionsWithCompletion:^(NSDictionary<NSString *,NSNumber *> * _Nonnull perms, NSError * _Nullable error) {
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

    self.permissionsListener = [[PPCompositeListenerRegistration alloc] initWithRegistrations:listeners];
    refreshMergedPermissions();
}

- (void)stopListeningPermissions {
    id<FIRListenerRegistration> listener = self.permissionsListener;
    if (listener) {
        [listener remove];
    }
    self.permissionsListener = nil;
}

- (void)setPermissionNamed:(NSString *)permName
                   allowed:(BOOL)allowed
                completion:(void (^)(NSError * _Nullable))completion {
    NSString *cleanPermission = [PPSafeString(permName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *canonicalPermission = PPCanonicalPermissionName(cleanPermission);
    FIRCollectionReference *permissionsCollection = [self pp_permissionsCollection];
    FIRCollectionReference *legacyCollection = [self pp_legacyPermissionsCollection];
    FIRCollectionReference *legacyCollectionAlt = [self pp_legacyPermissionsCollectionAlt];

    if (canonicalPermission.length == 0 || !permissionsCollection) {
        if (completion) {
            completion([UserModel pp_errorWithCode:404 key:@"error_missing_uid_or_perm"]);
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
            if (!self.permissions) {
                self.permissions = [NSMutableDictionary dictionary];
            }
            self.permissions[canonicalPermission] = @(allowed);
        }
        if (completion) {
            completion(error);
        }
    }];
}

- (BOOL)hasPermissionNamed:(NSString *)permName {
    NSString *cleanPermission = PPCanonicalPermissionName(permName);
    if (cleanPermission.length == 0) {
        return NO;
    }

    NSDictionary<NSString *, id> *permissions =
        [self.permissions isKindOfClass:NSDictionary.class] ? self.permissions : @{};

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
    return [PPRolePermission role:self.role hasPermission:cleanPermission];
}

- (BOOL)hasAnyPermissionInKeys:(NSArray<NSString *> *)permNames {
    for (NSString *name in permNames ?: @[]) {
        if ([self hasPermissionNamed:name]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Convenience Getters

- (BOOL)canPostAds     { return [self hasPermissionNamed:kPermPostAds]; }
- (BOOL)canSellNew     { return [self hasPermissionNamed:kPermSellNew]; }
- (BOOL)canSellUsed    { return [self hasPermissionNamed:kPermSellUsed]; }
- (BOOL)canAdoption    { return [self hasPermissionNamed:kPermAdoption]; }
- (BOOL)canManageStore { return [self hasPermissionNamed:kPermManageStore]; }
- (BOOL)canModeration  { return [self hasPermissionNamed:kPermModeration]; }
- (BOOL)canManageFood  { return [self hasPermissionNamed:kPermManageFood]; }
- (BOOL)canManageServices { return [self hasPermissionNamed:kPermManageServices]; }
- (BOOL)canProduction  { return [self hasPermissionNamed:kPermProduction]; }
- (BOOL)isAdminAll     { return [self hasPermissionNamed:kPermAdminAll]; }

- (BOOL)isStoreManager { return self.role == UserRoleStoreManager; }
- (BOOL)isFoodManager  { return self.role == UserRoleFoodManager; }
- (BOOL)isModerator    { return self.role == UserRoleModerator; }
- (BOOL)isOwner        { return self.role == UserRoleOwner; }
- (BOOL)isVet          { return self.role == UserRoleVet; }

#pragma mark - Cache Helpers

+ (nullable instancetype)loadSavedUserWithUID:(NSString *)uid {
    NSString *path = [self cachePathForUID:uid];
    if (path.length == 0) {
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        return nil;
    }

    return [NSKeyedUnarchiver unarchivedObjectOfClass:UserModel.class fromData:data error:nil];
}

- (void)saveToDisk {
    NSString *identifier = [self pp_cacheIdentifier];
    if (identifier.length == 0) {
        return;
    }

    NSString *path = [[self class] cachePathForUID:identifier];
    if (path.length == 0) {
        return;
    }

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self
                                         requiringSecureCoding:YES
                                                         error:nil];
    if (data.length == 0) {
        return;
    }

    [data writeToFile:path atomically:YES];
}

+ (void)clearCachedUserWithUID:(NSString *)uid {
    NSString *path = [self cachePathForUID:uid];
    if (path.length == 0) {
        return;
    }
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

+ (NSString *)cachePathForUID:(NSString *)uid {
    NSString *safeUID = PPUserSanitizedCacheID(PPSafeString(uid));
    if (safeUID.length == 0) {
        return @"";
    }

    NSString *dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"UserModel_%@.dat", safeUID]];
}

#pragma mark - XLFormOptionObject

- (nonnull NSString *)formDisplayText {
    return [self PPBestDisplayName];
}

- (nonnull id)formValue {
    return self;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.ID forKey:kUserKeyID];
    [coder encodeObject:self.UserName forKey:kUserKeyUserName];
    [coder encodeObject:self.FirstName forKey:kUserKeyFirstName];
    [coder encodeObject:self.LastName forKey:kUserKeyLastName];
    [coder encodeObject:self.MobileNo forKey:kUserKeyMobileNo];
    [coder encodeObject:self.UserEmail forKey:kUserKeyUserEmail];
    [coder encodeObject:self.UserImageName forKey:kUserKeyUserImageName];
    [coder encodeObject:self.UserAbout forKey:kUserKeyUserAbout];
    [coder encodeObject:self.UserImageUrl forKey:kUserKeyUserImageURL];
    [coder encodeObject:self.loginDate forKey:kUserKeyLoginDate];
    [coder encodeObject:self.updatedAt forKey:kUserKeyUpdatedAt];
    [coder encodeInteger:self.CountryID forKey:kUserKeyCountryID];
    [coder encodeObject:self.PPUserTokenID forKey:kUserKeyPPUserTokenID];
    [coder encodeBool:self.isAdmin forKey:kUserKeyIsAdmin];
    [coder encodeBool:self.isSuperAdmin forKey:kUserKeyIsSuperAdmin];
    [coder encodeBool:self.isBlocked forKey:kUserKeyIsBlocked];
    [coder encodeInteger:self.role forKey:kUserKeyRole];
    [coder encodeBool:self.verified forKey:kUserKeyVerified];
    [coder encodeObject:self.plan forKey:kUserKeyPlan];
    [coder encodeInteger:self.loginSource forKey:kUserKeyLoginSource];
    [coder encodeObject:self.PPAdminTokenID forKey:kUserKeyPPAdminTokenID];
    [coder encodeInteger:self.onlineStatus forKey:kUserKeyOnlineStatus];
    [coder encodeBool:self.isOnline forKey:kUserKeyIsOnline];
    [coder encodeObject:self.lastSeen forKey:kUserKeyLastSeen];
    [coder encodeObject:self.permissions forKey:kUserKeyPermissions];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (!self) {
        return nil;
    }

    NSString *decodedID = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyID]);
    NSString *decodedUID = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyUID]);
    self.ID = decodedID.length ? decodedID : decodedUID;

    NSString *decodedUserName = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyUserName]);
    NSString *decodedDisplayName = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyDisplayName]);
    self.UserName = decodedUserName.length ? decodedUserName : decodedDisplayName;

    self.FirstName = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyFirstName]);
    self.LastName = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyLastName]);
    self.MobileNo = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyMobileNo]);

    NSString *decodedUserEmail = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyUserEmail]);
    NSString *decodedEmail = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyEmail]);
    self.UserEmail = decodedUserEmail.length ? decodedUserEmail : decodedEmail;

    self.UserImageName = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyUserImageName]);

    NSString *about = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyUserAbout]);
    self.UserAbout = [about isEqualToString:@"no_value"] ? @"" : about;

    NSURL *decodedImageURL = [coder decodeObjectOfClass:NSURL.class forKey:kUserKeyUserImageURL];
    NSString *decodedPhotoURL = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyPhotoURL]);
    self.UserImageUrl = decodedImageURL ?: PPSafeURL(decodedPhotoURL);

    self.loginDate = [coder decodeObjectOfClass:NSDate.class forKey:kUserKeyLoginDate];
    self.updatedAt = [coder decodeObjectOfClass:NSDate.class forKey:kUserKeyUpdatedAt];
    self.CountryID = [coder decodeIntegerForKey:kUserKeyCountryID];
    self.PPUserTokenID = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyPPUserTokenID]);
    self.isAdmin = [coder decodeBoolForKey:kUserKeyIsAdmin];
    self.isSuperAdmin = [coder decodeBoolForKey:kUserKeyIsSuperAdmin];
    self.isBlocked = [coder decodeBoolForKey:kUserKeyIsBlocked];
    self.role = [coder decodeIntegerForKey:kUserKeyRole];
    self.verified = [coder decodeBoolForKey:kUserKeyVerified];
    self.plan = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyPlan]);
    self.loginSource = [coder decodeIntegerForKey:kUserKeyLoginSource];
    self.PPAdminTokenID = PPSafeString([coder decodeObjectOfClass:NSString.class forKey:kUserKeyPPAdminTokenID]);

    if ([coder containsValueForKey:kUserKeyOnlineStatus]) {
        NSInteger statusValue = [coder decodeIntegerForKey:kUserKeyOnlineStatus];
        self.onlineStatus = statusValue == OnlineStatusOnline ? OnlineStatusOnline : OnlineStatusOffline;
    } else {
        BOOL online = [coder decodeBoolForKey:kUserKeyOnline] || [coder decodeBoolForKey:kUserKeyIsOnline];
        self.onlineStatus = online ? OnlineStatusOnline : OnlineStatusOffline;
    }

    self.lastSeen = [coder decodeObjectOfClass:NSDate.class forKey:kUserKeyLastSeen];

    NSSet *permissionClasses = [NSSet setWithObjects:NSDictionary.class, NSString.class, NSNumber.class, nil];
    NSDictionary *decodedPermissions = [coder decodeObjectOfClasses:permissionClasses forKey:kUserKeyPermissions];
    self.permissions = [UserModel pp_sanitizedPermissionsDictionary:PPSafeDict(decodedPermissions)];

    [self pp_normalizeIdentityFields];

    return self;
}

#pragma mark - Builders

+ (instancetype)fromAuthUser:(FIRUser *)auth
                     rootDoc:(nullable NSDictionary *)root
                 permissions:(nullable NSDictionary<NSString *, NSNumber *> *)perms
                      claims:(nullable NSDictionary *)claims {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if ([root isKindOfClass:[NSDictionary class]]) {
        [dict addEntriesFromDictionary:root];
    }

    NSString *authUID = PPSafeString(auth.uid);
    dict[kUserKeyID] = authUID;

    NSString *authEmail = PPSafeString(auth.email);
    if (authEmail.length > 0) {
        dict[kUserKeyUserEmail] = authEmail;
    }

    NSString *authDisplayName = PPSafeString(auth.displayName);
    if (authDisplayName.length > 0) {
        dict[kUserKeyUserName] = authDisplayName;
    }

    NSString *authPhotoURL = PPSafeString(auth.photoURL.absoluteString);
    NSString *rootPhotoURL = PPSafeString(dict[kUserKeyPhotoURL]);
    NSString *rootImageURL = PPSafeString(dict[kUserKeyUserImageURL]);
    NSString *resolvedPhotoURL = authPhotoURL.length > 0
        ? authPhotoURL
        : (rootPhotoURL.length > 0 ? rootPhotoURL : rootImageURL);

    if (resolvedPhotoURL.length > 0) {
        dict[kUserKeyUserImageURL] = resolvedPhotoURL;
    }

    if (perms.count > 0) {
        dict[kUserKeyPermissions] = [UserModel pp_sanitizedPermissionsDictionary:perms];
    }

    NSDictionary *safeClaims = PPSafeDict(claims);
    if (dict[kUserKeyClaims] == nil && safeClaims.count > 0) {
        dict[kUserKeyClaims] = safeClaims;
    }

    if (dict[kUserKeyRole] == nil && dict[kUserKeyRoleValue] == nil && dict[kUserKeyRoleName] == nil) {
        if (safeClaims[kUserKeyRoleValue] != nil) {
            dict[kUserKeyRoleValue] = safeClaims[kUserKeyRoleValue];
        } else if (safeClaims[kUserKeyRole] != nil) {
            dict[kUserKeyRole] = safeClaims[kUserKeyRole];
        }
    }

    if (dict[kUserKeyIsAdmin] == nil) {
        id claimAdmin = safeClaims[kUserKeyIsAdmin] ?: safeClaims[@"admin"];
        if (claimAdmin != nil) {
            dict[kUserKeyIsAdmin] = claimAdmin;
        }
    }

    if (dict[kUserKeyIsSuperAdmin] == nil) {
        id claimSuperAdmin = safeClaims[kUserKeyIsSuperAdmin] ?: safeClaims[@"superAdmin"] ?: safeClaims[@"superadmin"];
        if (claimSuperAdmin != nil) {
            dict[kUserKeyIsSuperAdmin] = claimSuperAdmin;
        }
    }

    if (dict[kUserKeyIsBlocked] == nil && dict[kUserKeyBlocked] == nil) {
        id claimBlocked = safeClaims[kUserKeyIsBlocked] ?: safeClaims[kUserKeyBlocked];
        if (claimBlocked != nil) {
            dict[kUserKeyIsBlocked] = claimBlocked;
        }
    }

    return [[UserModel alloc] initWithDict:dict];
}

+ (void)loadCurrentUserModelWithCompletion:(void(^)(UserModel *_Nullable u,
                                                    NSError *_Nullable err))completion {
    FIRUser *current = [FIRAuth auth].currentUser;
    if (!current) {
        [self pp_dispatchLoadCompletion:completion
                                   user:nil
                                  error:[self pp_errorWithCode:401 key:@"error_not_signed_in"]];
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:kPPUsersCol] documentWithPath:current.uid];

    [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            [self pp_dispatchLoadCompletion:completion user:nil error:error];
            return;
        }

        NSDictionary *root = snapshot.exists ? (snapshot.data ?: @{}) : @{};

        [current getIDTokenResultWithCompletion:^(FIRAuthTokenResult * _Nullable result, NSError * _Nullable tokenError) {
            if (tokenError) {
                NSLog(@"⚠️ [UserModel] Token claims unavailable: %@", tokenError.localizedDescription);
            }
            NSDictionary *claims = result.claims ?: @{};

            FIRCollectionReference *canonicalCol = [docRef collectionWithPath:kPPPermsSubCol];
            FIRCollectionReference *legacyCol = [docRef collectionWithPath:kPPLegacyPermsSubCol];
            FIRCollectionReference *legacyAltCol = [docRef collectionWithPath:kPPLegacyPermsSubColAlt];

            dispatch_group_t group = dispatch_group_create();
            __block NSArray<FIRDocumentSnapshot *> *canonicalDocs = @[];
            __block NSArray<FIRDocumentSnapshot *> *legacyDocs = @[];
            __block NSArray<FIRDocumentSnapshot *> *legacyAltDocs = @[];
            __block NSError *canonicalError = nil;

            dispatch_group_enter(group);
            [canonicalCol getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable permsSnapshot, NSError * _Nullable permsError) {
                canonicalError = permsError;
                canonicalDocs = permsSnapshot.documents ?: @[];
                dispatch_group_leave(group);
            }];

            dispatch_group_enter(group);
            [legacyCol getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable permsSnapshot, NSError * _Nullable permsError) {
                if (!permsError) {
                    legacyDocs = permsSnapshot.documents ?: @[];
                }
                dispatch_group_leave(group);
            }];

            dispatch_group_enter(group);
            [legacyAltCol getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable permsSnapshot, NSError * _Nullable permsError) {
                if (!permsError) {
                    legacyAltDocs = permsSnapshot.documents ?: @[];
                }
                dispatch_group_leave(group);
            }];

            dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                if (canonicalError) {
                    [self pp_dispatchLoadCompletion:completion user:nil error:canonicalError];
                    return;
                }

                NSMutableDictionary<NSString *, NSNumber *> *perms = [self pp_permissionsDictionaryFromDocuments:legacyDocs];
                [perms addEntriesFromDictionary:[self pp_permissionsDictionaryFromDocuments:legacyAltDocs]];
                [perms addEntriesFromDictionary:[self pp_permissionsDictionaryFromDocuments:canonicalDocs]];

                UserModel *user = [UserModel fromAuthUser:current
                                                  rootDoc:root
                                              permissions:perms
                                                   claims:claims];

                [self pp_dispatchLoadCompletion:completion user:user error:nil];
            });
        }];
    }];
}

#pragma mark - Display Helpers

- (NSString *)PPBestDisplayName {
    if (self.UserName.length) {
        return self.UserName;
    }
    if (self.FirstName.length) {
        return self.FirstName;
    }
    if (self.UserEmail.length) {
        return self.UserEmail;
    }
    return self.ID ?: @"";
}

#pragma mark - Private (Helpers)

- (NSString *)pp_documentID {
    if (self.ID.length > 0) {
        return self.ID;
    }
    return @"";
}

- (NSString *)pp_cacheIdentifier {
    NSString *documentID = [self pp_documentID];
    return documentID.length ? documentID : @"";
}

- (nullable FIRCollectionReference *)pp_permissionsCollection {
    NSString *documentID = [self pp_documentID];
    if (documentID.length == 0) {
        return nil;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    return [[[db collectionWithPath:kPPUsersCol] documentWithPath:documentID] collectionWithPath:kPPPermsSubCol];
}

- (nullable FIRCollectionReference *)pp_legacyPermissionsCollection {
    NSString *documentID = [self pp_documentID];
    if (documentID.length == 0) {
        return nil;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    return [[[db collectionWithPath:kPPUsersCol] documentWithPath:documentID] collectionWithPath:kPPLegacyPermsSubCol];
}

- (nullable FIRCollectionReference *)pp_legacyPermissionsCollectionAlt {
    NSString *documentID = [self pp_documentID];
    if (documentID.length == 0) {
        return nil;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    return [[[db collectionWithPath:kPPUsersCol] documentWithPath:documentID] collectionWithPath:kPPLegacyPermsSubColAlt];
}

+ (NSError *)pp_errorWithCode:(NSInteger)code key:(NSString *)localizedKey {
    return [NSError errorWithDomain:PPUserModelErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: kLang(localizedKey)}];
}

+ (NSMutableDictionary<NSString *, NSNumber *> *)pp_sanitizedPermissionsDictionary:(NSDictionary *)permissions {
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

+ (NSMutableDictionary<NSString *, NSNumber *> *)pp_permissionsDictionaryFromDocuments:(NSArray<FIRDocumentSnapshot *> *)documents {
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

+ (void)pp_dispatchLoadCompletion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
                            user:(UserModel * _Nullable)user
                           error:(NSError * _Nullable)error {
    if (!completion) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        completion(user, error);
    });
}

@end
