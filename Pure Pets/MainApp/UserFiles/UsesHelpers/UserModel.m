//
//  UserModel.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 21/08/2025.
//  Refactored for best practices
//

#import "UserModel.h"
#import "PPUserPermissionsManager.h"
#import "PPUserModelCache.h"
@import FirebaseAuth;
@import FirebaseFirestore;
#import <os/log.h>

static os_log_t PPUserModelLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.purepets.ios", "UserModel");
    });
    return log;
}

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

// User Access Model keys (Console-managed)
static NSString *const kUserKeyAccountStatus = @"accountStatus";
static NSString *const kUserKeyProdectionStatus = @"prodectionStatus";
static NSString *const kUserKeyFeatures = @"features";
static NSString *const kUserKeyRestrictions = @"restrictions";
static NSString *const kUserKeySubscription = @"subscription";

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
    // SECURITY: Claims are signed by Firebase Auth — prefer them over profile fields
    // which are stored in Firestore and could theoretically be tampered with.
    BOOL hasClaimsRoleValue = PPUserFirstValueForKeys(claims, @[kUserKeyRoleValue, kUserKeyRole, kUserKeyRoleName]) != nil;
    if (hasClaimsRoleValue) {
        UserRole role = PPParseRoleFromUserDoc(claims);
        if (role != UserRoleUnknown) {
            return role;
        }
    }

    // Fallback to profile for legacy users without custom claims
    BOOL hasProfileRoleValue = PPUserFirstValueForKeys(profile, @[kUserKeyRoleValue, kUserKeyRole, kUserKeyRoleName]) != nil;
    if (hasProfileRoleValue) {
        UserRole role = PPParseRoleFromUserDoc(profile);
        if (role != UserRoleUnknown) {
            return role;
        }
    }

    UserRole fallbackRole = PPParseRoleFromUserDoc(claims);
    if (fallbackRole != UserRoleUnknown) {
        return fallbackRole;
    }

    fallbackRole = PPParseRoleFromUserDoc(profile);
    return fallbackRole == UserRoleUnknown ? UserRoleUser : fallbackRole;
}

static BOOL PPUserResolvedBoolFromProfileAndClaims(NSDictionary *profile,
                                                   NSArray<NSString *> *profileKeys,
                                                   NSDictionary *claims,
                                                   NSArray<NSString *> *claimKeys,
                                                   BOOL defaultValue,
                                                   BOOL * _Nullable usedProfileValue) {
    // SECURITY: Prefer claims (signed by Firebase Auth) over profile (Firestore doc)
    id claimValue = PPUserFirstValueForKeys(claims, claimKeys);
    if (claimValue) {
        if (usedProfileValue) *usedProfileValue = NO;
        return PPUserBoolValue(claimValue);
    }

    // Fallback to profile for legacy users without custom claims
    id profileValue = PPUserFirstValueForKeys(profile, profileKeys);
    if (profileValue) {
        if (usedProfileValue) *usedProfileValue = YES;
        return PPUserBoolValue(profileValue);
    }
    if (usedProfileValue) *usedProfileValue = NO;
    return defaultValue;
}

static NSDate *_Nullable PPUserDateFromValue(id _Nullable value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:[FIRTimestamp class]]) {
        return ((FIRTimestamp *)value).dateValue;
    }
    // Support epoch seconds from JSON cache round-trip
    if ([value isKindOfClass:[NSNumber class]]) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
    }
    return nil;
}

@interface UserModel ()
- (void)pp_applyDefaults;
- (void)pp_applyDictionary:(NSDictionary *)dict;
- (void)pp_applyDictionary:(NSDictionary *)dict fallbackDocumentID:(nullable NSString *)fallbackDocumentID;
- (void)pp_normalizeIdentityFields;
- (NSString *)pp_documentID;
+ (NSError *)pp_errorWithCode:(NSInteger)code key:(NSString *)localizedKey;
+ (void)pp_dispatchLoadCompletion:(void(^)(UserModel * _Nullable user, NSError * _Nullable error))completion
                            user:(UserModel * _Nullable)user
                           error:(NSError * _Nullable)error;
@end

@implementation UserModel {
    PPUserPermissionsManager *_permissionsManager;
}

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
    self.permissions = @{};
    self.Addresses = [NSMutableArray array];
    self.onlineStatus = OnlineStatusOffline;
    self.loginSource = UserLoginSourceUnknown;

    // User Access Model defaults
    self.accountStatus = @"active";
    self.prodectionStatus = @"active";
    self.canPostPetAdsFeature = YES;
    self.canPostAdoptionFeature = YES;
    self.canSellAccessoriesFeature = YES;
    self.canOfferServicesFeature = NO;
    self.canUseStoriesFeature = YES;
    self.canUseChatFeature = YES;
    self.canAccessPremiumMarketplaceFeature = NO;
    self.subscriptionPlan = @"free";
    self.subscriptionStatus = @"active";
    self.subscriptionSource = @"manual";
    self.postingBlocked = NO;
    self.chatBlocked = NO;
    self.purchaseBlocked = NO;
    self.withdrawalBlocked = NO;
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

    // ── User Access Model (Console-managed) ──
    self.accountStatus = PPSafeString(safeDict[kUserKeyAccountStatus]);
    if (self.accountStatus.length == 0) self.accountStatus = @"active";

    self.prodectionStatus = PPSafeString(safeDict[kUserKeyProdectionStatus]);
    if (self.prodectionStatus.length == 0) self.prodectionStatus = @"active";

    // Features
    NSDictionary *featuresDict = PPSafeDict(safeDict[kUserKeyFeatures]);
    if (featuresDict.count > 0) {
        self.canPostPetAdsFeature = PPUserBoolValue(featuresDict[@"canPostPetAds"]);
        self.canPostAdoptionFeature = PPUserBoolValue(featuresDict[@"canPostAdoption"]);
        self.canSellAccessoriesFeature = PPUserBoolValue(featuresDict[@"canSellAccessories"]);
        self.canOfferServicesFeature = PPUserBoolValue(featuresDict[@"canOfferServices"]);
        self.canUseStoriesFeature = PPUserBoolValue(featuresDict[@"canUseStories"]);
        self.canUseChatFeature = PPUserBoolValue(featuresDict[@"canUseChat"]);
        self.canAccessPremiumMarketplaceFeature = PPUserBoolValue(featuresDict[@"canAccessPremiumMarketplace"]);
    } else {
        // Default all features for users without the features dict yet
        self.canPostPetAdsFeature = YES;
        self.canPostAdoptionFeature = YES;
        self.canSellAccessoriesFeature = YES;
        self.canOfferServicesFeature = NO;
        self.canUseStoriesFeature = YES;
        self.canUseChatFeature = YES;
        self.canAccessPremiumMarketplaceFeature = NO;
    }

    // Subscription
    NSDictionary *subDict = PPSafeDict(safeDict[kUserKeySubscription]);
    if (subDict.count > 0) {
        self.subscriptionPlan = PPSafeString(subDict[@"plan"]) ?: @"free";
        self.subscriptionStatus = PPSafeString(subDict[@"status"]) ?: @"active";
        self.subscriptionSource = PPSafeString(subDict[@"source"]) ?: @"manual";
        if (self.subscriptionPlan.length == 0) self.subscriptionPlan = @"free";
        if (self.subscriptionStatus.length == 0) self.subscriptionStatus = @"active";
        if (self.subscriptionSource.length == 0) self.subscriptionSource = @"manual";
    }

    // Restrictions
    NSDictionary *restrictionsDict = PPSafeDict(safeDict[kUserKeyRestrictions]);
    if (restrictionsDict.count > 0) {
        self.postingBlocked = PPUserBoolValue(restrictionsDict[@"postingBlocked"]);
        self.chatBlocked = PPUserBoolValue(restrictionsDict[@"chatBlocked"]);
        self.purchaseBlocked = PPUserBoolValue(restrictionsDict[@"purchaseBlocked"]);
        self.withdrawalBlocked = PPUserBoolValue(restrictionsDict[@"withdrawalBlocked"]);
    }

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
    self.permissions = [[PPUserPermissionsManager sanitizedPermissionsDictionary:permDict] copy];

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
        self.permissions = @{};
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
    dict[kUserKeyVerified] = @(self.verified);
    dict[kUserKeyPlan] = PPSafeString(self.plan);
    dict[kUserKeyLoginSource] = @(self.loginSource);

    // SECURITY: role, isAdmin, isSuperAdmin, isBlocked are server-managed.
    // They are intentionally EXCLUDED from client-originated writes.
    // Tokens are written via dedicated updateCurrentUserWithPPUserTokenID: path.

    // NOTE: Addresses and permissions are stored in dedicated subcollections.
    return dict;
}

- (void)syncToFirestoreWithCompletion:(void(^)(NSError * _Nullable error))completion {
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

- (void)SYNC:(void(^)(NSError * _Nullable error))completion {
    [self syncToFirestoreWithCompletion:completion];
}

#pragma mark - Permissions (delegates to PPUserPermissionsManager)

- (PPUserPermissionsManager *)pp_permissionsManager {
    if (!_permissionsManager) {
        _permissionsManager = [[PPUserPermissionsManager alloc] init];
    }
    return _permissionsManager;
}

- (void)fetchPermissionsWithCompletion:(void (^)(NSDictionary<NSString *, NSNumber *> *, NSError * _Nullable))completion {
    [[self pp_permissionsManager] fetchPermissionsForUser:self completion:completion];
}

- (void)startListeningPermissionsWithChange:(void (^)(NSDictionary<NSString *, NSNumber *> *))onChange {
    [[self pp_permissionsManager] startListeningPermissionsForUser:self onChange:onChange];
}

- (void)stopListeningPermissions {
    [_permissionsManager stopListening];
    _permissionsManager = nil;
    self.permissionsListener = nil;
}

- (void)setPermissionNamed:(NSString *)permName
                   allowed:(BOOL)allowed
                completion:(void (^)(NSError * _Nullable))completion {
    [[self pp_permissionsManager] setPermissionNamed:permName
                                             allowed:allowed
                                             forUser:self
                                          completion:completion];
}

- (BOOL)hasPermissionNamed:(NSString *)permName {
    return [PPUserPermissionsManager user:self hasPermissionNamed:permName];
}

- (BOOL)hasAnyPermissionInKeys:(NSArray<NSString *> *)permNames {
    return [PPUserPermissionsManager user:self hasAnyPermissionInKeys:permNames];
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

#pragma mark - User Access Computed Properties

- (BOOL)isEffectivelyBlocked {
    // User is blocked if:
    // 1. Legacy isBlocked flag is YES
    // 2. OR accountStatus is "blocked" or "disabled"
    if (self.isBlocked) return YES;
    if ([self.accountStatus isEqualToString:@"blocked"]) return YES;
    if ([self.accountStatus isEqualToString:@"disabled"]) return YES;
    return NO;
}

- (BOOL)isPostingEffectivelyBlocked {
    if (self.isEffectivelyBlocked) return YES;
    if (self.postingBlocked) return YES;
    return NO;
}

- (BOOL)isChatEffectivelyBlocked {
    if (self.isEffectivelyBlocked) return YES;
    if (self.chatBlocked) return YES;
    return NO;
}

- (BOOL)isPurchaseEffectivelyBlocked {
    if (self.isEffectivelyBlocked) return YES;
    if (self.purchaseBlocked) return YES;
    return NO;
}

#pragma mark - Cache Helpers (delegates to PPUserModelCache)

+ (nullable instancetype)loadSavedUserWithUID:(NSString *)uid {
    return [PPUserModelCache loadUserWithUID:uid];
}

- (void)saveToDisk {
    [PPUserModelCache saveUser:self];
}

+ (void)clearCachedUserWithUID:(NSString *)uid {
    [PPUserModelCache clearUserWithUID:uid];
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
    [coder encodeInteger:self.onlineStatus forKey:kUserKeyOnlineStatus];
    [coder encodeBool:self.isOnline forKey:kUserKeyIsOnline];
    [coder encodeObject:self.lastSeen forKey:kUserKeyLastSeen];
    [coder encodeObject:self.permissions forKey:kUserKeyPermissions];

    // User Access Model (Console-managed)
    [coder encodeObject:self.accountStatus forKey:kUserKeyAccountStatus];
    [coder encodeObject:self.prodectionStatus forKey:kUserKeyProdectionStatus];
    [coder encodeBool:self.canPostPetAdsFeature forKey:@"canPostPetAdsFeature"];
    [coder encodeBool:self.canPostAdoptionFeature forKey:@"canPostAdoptionFeature"];
    [coder encodeBool:self.canSellAccessoriesFeature forKey:@"canSellAccessoriesFeature"];
    [coder encodeBool:self.canOfferServicesFeature forKey:@"canOfferServicesFeature"];
    [coder encodeBool:self.canUseStoriesFeature forKey:@"canUseStoriesFeature"];
    [coder encodeBool:self.canUseChatFeature forKey:@"canUseChatFeature"];
    [coder encodeBool:self.canAccessPremiumMarketplaceFeature forKey:@"canAccessPremiumMarketplaceFeature"];
    [coder encodeObject:self.subscriptionPlan forKey:@"subscriptionPlan"];
    [coder encodeObject:self.subscriptionStatus forKey:@"subscriptionStatus"];
    [coder encodeObject:self.subscriptionSource forKey:@"subscriptionSource"];
    [coder encodeBool:self.postingBlocked forKey:@"postingBlocked"];
    [coder encodeBool:self.chatBlocked forKey:@"chatBlocked"];
    [coder encodeBool:self.purchaseBlocked forKey:@"purchaseBlocked"];
    [coder encodeBool:self.withdrawalBlocked forKey:@"withdrawalBlocked"];
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
    self.permissions = [[PPUserPermissionsManager sanitizedPermissionsDictionary:PPSafeDict(decodedPermissions)] copy];

    // User Access Model (Console-managed)
    self.accountStatus = [coder decodeObjectOfClass:[NSString class] forKey:kUserKeyAccountStatus] ?: @"active";
    self.prodectionStatus = [coder decodeObjectOfClass:[NSString class] forKey:kUserKeyProdectionStatus] ?: @"active";
    self.canPostPetAdsFeature = [coder decodeBoolForKey:@"canPostPetAdsFeature"];
    self.canPostAdoptionFeature = [coder decodeBoolForKey:@"canPostAdoptionFeature"];
    self.canSellAccessoriesFeature = [coder decodeBoolForKey:@"canSellAccessoriesFeature"];
    self.canOfferServicesFeature = [coder decodeBoolForKey:@"canOfferServicesFeature"];
    self.canUseStoriesFeature = [coder decodeBoolForKey:@"canUseStoriesFeature"];
    self.canUseChatFeature = [coder decodeBoolForKey:@"canUseChatFeature"];
    self.canAccessPremiumMarketplaceFeature = [coder decodeBoolForKey:@"canAccessPremiumMarketplaceFeature"];
    self.subscriptionPlan = [coder decodeObjectOfClass:[NSString class] forKey:@"subscriptionPlan"] ?: @"free";
    self.subscriptionStatus = [coder decodeObjectOfClass:[NSString class] forKey:@"subscriptionStatus"] ?: @"active";
    self.subscriptionSource = [coder decodeObjectOfClass:[NSString class] forKey:@"subscriptionSource"] ?: @"manual";
    self.postingBlocked = [coder decodeBoolForKey:@"postingBlocked"];
    self.chatBlocked = [coder decodeBoolForKey:@"chatBlocked"];
    self.purchaseBlocked = [coder decodeBoolForKey:@"purchaseBlocked"];
    self.withdrawalBlocked = [coder decodeBoolForKey:@"withdrawalBlocked"];

    [self pp_normalizeIdentityFields];

    return self;
}

#pragma mark - Builders

+ (instancetype)fromAuthUser:(FIRUser *)auth
                     rootDoc:(nullable NSDictionary *)root
                 permissions:(nullable NSDictionary<NSString *, NSNumber *> *)perms
                      claims:(nullable NSDictionary *)claims {
    if (!auth) {
        NSLog(@"❌ [UserModel] fromAuthUser: called with nil FIRUser — returning nil");
        return nil;
    }

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
        dict[kUserKeyPermissions] = [PPUserPermissionsManager sanitizedPermissionsDictionary:perms];
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

                if (legacyDocs.count > 0) {
                    os_log_info(PPUserModelLog(), "Legacy PermisstionsCol returned %zu docs for user %{public}@",
                                (unsigned long)legacyDocs.count, current.uid);
                }
                if (legacyAltDocs.count > 0) {
                    os_log_info(PPUserModelLog(), "Legacy PermissionsCol returned %zu docs for user %{public}@",
                                (unsigned long)legacyAltDocs.count, current.uid);
                }

                NSMutableDictionary<NSString *, NSNumber *> *perms = [PPUserPermissionsManager permissionsDictionaryFromDocuments:legacyDocs];
                [perms addEntriesFromDictionary:[PPUserPermissionsManager permissionsDictionaryFromDocuments:legacyAltDocs]];
                [perms addEntriesFromDictionary:[PPUserPermissionsManager permissionsDictionaryFromDocuments:canonicalDocs]];

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

- (NSString *)bestDisplayName {
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

- (NSString *)PPBestDisplayName {
    return [self bestDisplayName];
}

#pragma mark - camelCase Aliases (forwarding getters)

- (NSString *)userName          { return self.UserName; }
- (NSString *)userEmail         { return self.UserEmail; }
- (NSString *)firstName         { return self.FirstName; }
- (NSString *)lastName          { return self.LastName; }
- (NSString *)mobileNo          { return self.MobileNo; }
- (NSString *)userAbout         { return self.UserAbout; }
- (NSString *)userImageName     { return self.UserImageName; }
- (NSURL *)userImageUrl         { return self.UserImageUrl; }
- (NSInteger)countryID          { return self.CountryID; }
- (NSString *)ppUserTokenID     { return self.PPUserTokenID; }
- (NSMutableArray<PPAddressModel *> *)addresses { return self.Addresses; }
- (UserPaymentInstrument *)selectedInstrument   { return self.SelectedInstrument; }

#pragma mark - Private (Helpers)

- (NSString *)pp_documentID {
    if (self.ID.length > 0) {
        return self.ID;
    }
    return @"";
}

+ (NSError *)pp_errorWithCode:(NSInteger)code key:(NSString *)localizedKey {
    return [NSError errorWithDomain:PPUserModelErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: kLang(localizedKey)}];
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
