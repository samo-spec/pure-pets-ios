
#import "UserManager.h"
#import "UserModel.h"
#import "PPRolePermission.h"  // Assuming this defines UserPermission enum and possibly mapping
#import "AppDataListenerManager.h"
#import "CartManager.h"
#import "ChManager.h"

@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseStorage;
@import FirebaseFunctions;
@import FirebaseAnalytics;
@import FirebaseMessaging;
@import UIKit;
NSString * const LanguageDidChangeNotification = @"LanguageDidChangeNotification";

NS_ASSUME_NONNULL_BEGIN

@interface UserManager ()

@property (nonatomic, strong) FIRFunctions *functions;
@property (nonatomic, strong, nullable) id authStateListenerHandle;  // handle for Auth state listener
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> blockedStateListener;
@property (nonatomic, strong) dispatch_queue_t authQueue;
@property (nonatomic, assign) NSUInteger authStateVersion;
@property (nonatomic, assign) BOOL isSessionRestoreRunning;
@property (nonatomic, assign) BOOL isSignOutInProgress;
@property (nonatomic, assign) BOOL didFinishInitialSetup;
@property (nonatomic, copy, nullable) FUAuthStateHandler authStateHandler;
@property (nonatomic, strong, nullable) NSTimer *tokenRefreshTimer;
@property (nonatomic, assign) BOOL requireVerifiedEmail;
@property (nonatomic, assign) BOOL enforceFirestoreBlockedFlag;
@end

@implementation UserManager

// MARK: - Constant Definitions
NSString *const FUUpdateKeyEmail       = @"email";
NSString *const FUUpdateKeyPhoneNumber = @"phoneNumber";
NSString *const FUUpdateKeyDisplayName = @"displayName";
NSString *const FUUpdateKeyPhotoURL    = @"photoURL";
NSString *const FUUpdateKeyCustomClaims = @"customClaims";

NSString *const FUErrorDomain = @"com.yourapp.FUManagerError";
NSErrorUserInfoKey const FUErrorDetailedDescriptionKey = @"FUDetailedDescription";
NSString *const PPUserManagerDidSyncCurrentUserNotification = @"PPUserManagerDidSyncCurrentUserNotification";
NSString *const PPUserManagerDidSignOutNotification = @"PPUserManagerDidSignOutNotification";
NSString *const PPUserManagerDidUpdateBlockedStateNotification = @"PPUserManagerDidUpdateBlockedStateNotification";
NSString *const PPUserManagerBlockedStateUserInfoKey = @"isBlocked";

static NSString *PPUserManagerTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPUserManagerNormalizedDigitsString(NSString *value)
{
    NSString *raw = PPUserManagerTrimmedString(value);
    if (raw.length == 0) return @"";

    NSMutableString *digits = [NSMutableString string];
    NSCharacterSet *digitSet = NSCharacterSet.decimalDigitCharacterSet;
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar ch = [raw characterAtIndex:i];
        if (ch >= '0' && ch <= '9') {
            [digits appendFormat:@"%c", (char)ch];
            continue;
        }
        if (ch >= 0x0660 && ch <= 0x0669) { // Arabic-Indic
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x0660))];
            continue;
        }
        if (ch >= 0x06F0 && ch <= 0x06F9) { // Extended Arabic-Indic
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x06F0))];
            continue;
        }
        if (ch >= 0xFF10 && ch <= 0xFF19) { // Full-width digits
            [digits appendFormat:@"%c", (char)('0' + (ch - 0xFF10))];
            continue;
        }
        if ([digitSet characterIsMember:ch]) {
            NSString *scalar = [NSString stringWithCharacters:&ch length:1];
            NSInteger numeric = [scalar integerValue];
            if (numeric >= 0 && numeric <= 9) {
                [digits appendFormat:@"%ld", (long)numeric];
            }
        }
    }
    return digits;
}

static NSString *PPUserManagerCanonicalDialCode(NSString *value)
{
    NSString *digits = PPUserManagerNormalizedDigitsString(value);
    if (digits.length == 0) return @"";
    return [NSString stringWithFormat:@"+%@", digits];
}

static NSString *PPUserManagerCanonicalE164Candidate(NSString *value)
{
    NSString *trimmed = PPUserManagerTrimmedString(value);
    if (trimmed.length == 0) return @"";

    NSString *digits = PPUserManagerNormalizedDigitsString(trimmed);
    if (digits.length == 0) return @"";

    BOOL hasPlus = [trimmed hasPrefix:@"+"];
    return hasPlus ? [NSString stringWithFormat:@"+%@", digits] : digits;
}

// MARK: - Singleton
+ (instancetype)sharedManager {
    static UserManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[UserManager alloc] init];
    });
    return shared;
}

+ (void)cleanupUnauthenticatedFirestoreUsers_OneTime {
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🧹 [Cleanup] Starting unauthenticated users cleanup…");

    [[db collectionWithPath:@"UsersCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error) {

        if (error) {
            NSLog(@"❌ [Cleanup] Failed to fetch users: %@", error);
            return;
        }

        __block NSInteger checked = 0;
        __block NSInteger deleted = 0;

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSString *uid = doc.documentID;
            if (uid.length == 0) continue;

            checked++;

            // 🔁 Call your EXISTING availability function
            [[ChManager sharedManager]
             checkChatAvailabilityForUser:uid
             completion:^(BOOL available, NSString * _Nullable reason) {

                if (!available && [reason isEqualToString:@"auth_deleted"]) {

                    NSLog(@"🗑️ [Cleanup] Deleting Firestore user UID=%@", uid);

                    [[doc reference] deleteDocumentWithCompletion:^(NSError * _Nullable delErr) {
                        if (delErr) {
                            NSLog(@"❌ [Cleanup] Failed deleting %@: %@", uid, delErr);
                        } else {
                            deleted++;
                            NSLog(@"✅ [Cleanup] Deleted %@", uid);
                        }
                    }];
                }
            }];
        }

        NSLog(@"🧹 [Cleanup] Finished. Checked=%ld",
              (long)checked);
    }];
}

+ (UserModel *)userModelFromUsersArrayForID:(NSString *)userID {
    if (!userID || userID.length == 0) return nil;
    //NSLog(@"[chat]AppManager.sharedInstance.usersArray %@.",AppManager.sharedInstance.usersArray);

    for (UserModel *user in AppManager.sharedInstance.usersArray) {
        if ([user.ID isEqualToString:userID]) {
            return user;
        }
    }
    return nil;
}



// MARK: - Init & Setup
- (instancetype)init {
    if (self = [super init]) {
        _functions = [FIRFunctions functions];
        SEL limitedUseSetter = NSSelectorFromString(@"setUseAppCheckLimitedUseTokens:");
        if ([_functions respondsToSelector:limitedUseSetter]) {
            NSMethodSignature *signature = [_functions methodSignatureForSelector:limitedUseSetter];
            if (signature) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                BOOL enabled = YES;
                [invocation setSelector:limitedUseSetter];
                [invocation setTarget:_functions];
                [invocation setArgument:&enabled atIndex:2];
                [invocation invoke];
                NSLog(@"[AppCheck] Enabled limited-use App Check tokens for callable functions.");
            }
        }
        _authQueue = dispatch_queue_create("com.purepets.auth.state.queue", DISPATCH_QUEUE_SERIAL);
        _authStateVersion = 0;
        _isSessionRestoreRunning = NO;
        _didFinishInitialSetup = NO;
        _requireVerifiedEmail = [[NSUserDefaults standardUserDefaults] boolForKey:@"PPRequireEmailVerification"];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSNumber *enforceBlockedSetting = [defaults objectForKey:@"PPEnforceFirestoreBlockedFlag"];
        // Always enforce blocked users in this app.
        _enforceFirestoreBlockedFlag = YES;
        if (enforceBlockedSetting == nil || ![enforceBlockedSetting boolValue]) {
            [defaults setBool:YES forKey:@"PPEnforceFirestoreBlockedFlag"];
            [defaults synchronize];
        }

        // Attempt to load cached user for faster cold-start rendering.
        [self loadCachedUser];

        // Attach auth observer asynchronously to avoid dispatch_once re-entrancy
        // if Auth immediately invokes callbacks while the singleton is still initializing.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startAuthStateMonitoringWithHandler:nil];
        });

        // Session restore is intentionally triggered by app bootstrap (App/Scene delegate).
        // Keeping it out of init prevents duplicate restore races on launch.
        dispatch_async(dispatch_get_main_queue(), ^{
            self.didFinishInitialSetup = YES;
        });
    }
    return self;
}

- (NSString *)pp_defaultDisplayNameForAuthUser:(FIRUser *)auth
{
    NSString *displayName = [auth.displayName isKindOfClass:NSString.class]
        ? [auth.displayName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (displayName.length > 0) {
        return displayName;
    }

    NSString *email = [auth.email isKindOfClass:NSString.class]
        ? [auth.email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (email.length > 0) {
        NSString *localPart = [[email componentsSeparatedByString:@"@"] firstObject] ?: @"";
        localPart = [localPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (localPart.length > 0) {
            return localPart;
        }
    }

    NSString *phone = [auth.phoneNumber isKindOfClass:NSString.class]
        ? [auth.phoneNumber stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (phone.length > 0) {
        return [NSString stringWithFormat:@"User %@", phone];
    }
    return @"User";
}

- (NSString *)pp_currentUserDocumentUID
{
    NSString *authUID = PPSafeString([FIRAuth auth].currentUser.uid);
    if (authUID.length > 0) {
        return authUID;
    }
    return PPSafeString(self.currentUser.ID);
}

- (BOOL)pp_shouldRepairUserDocumentForTokenSyncError:(NSError * _Nullable)error
{
    if (!error) return NO;

    if ([error.domain isEqualToString:FIRFirestoreErrorDomain] &&
        (error.code == FIRFirestoreErrorCodePermissionDenied ||
         error.code == FIRFirestoreErrorCodeNotFound)) {
        return YES;
    }

    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    if ([underlying isKindOfClass:NSError.class] &&
        [underlying.domain isEqualToString:FIRFirestoreErrorDomain] &&
        (underlying.code == FIRFirestoreErrorCodePermissionDenied ||
         underlying.code == FIRFirestoreErrorCodeNotFound)) {
        return YES;
    }

    return NO;
}

- (void)pp_resolveAuthoritativeUserDocumentSnapshotForAuthUser:(FIRUser *)authUser
                                                    completion:(void (^)(FIRDocumentSnapshot * _Nullable snapshot,
                                                                         NSError * _Nullable error))completion
{
    if (!authUser.uid.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:FUErrorDomain
                                                code:FUErrorCodeInvalidCredentials
                                            userInfo:@{NSLocalizedDescriptionKey: @"Missing auth UID."}]);
        }
        return;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:authUser.uid];
    [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot || !snapshot.metadata.isFromCache) {
            if (completion) completion(snapshot, error);
            return;
        }

        [docRef getDocumentWithSource:FIRFirestoreSourceServer
                           completion:^(FIRDocumentSnapshot * _Nullable serverSnapshot,
                                        NSError * _Nullable serverError) {
            if (!serverError && serverSnapshot) {
                if (completion) completion(serverSnapshot, nil);
                return;
            }

            if (completion) completion(snapshot, nil);
        }];
    }];
}

// Helper to prepare default Firestore data for a new user from FIRUser
- (NSDictionary *)defaultUserDataForAuthUser:(FIRUser *)auth {
    NSDate *now = [NSDate date];
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    NSString *resolvedDisplayName = [self pp_defaultDisplayNameForAuthUser:auth];
    // Basic identity info
    data[@"ID"] = auth.uid;
    data[@"uid"] = auth.uid;
    data[@"createdAt"] = now;
    if (auth.email) {
        NSString *email = [[auth.email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        if (email.length > 254) {
            email = [email substringToIndex:254];
        }
        if (email.length > 0) {
            data[@"UserEmail"] = email;
            data[@"email"] = email;
        }
    }
    data[@"UserName"] = resolvedDisplayName;
    if (auth.displayName.length > 0) {
        // If displayName contains a space, split into first/last name as best guess
        NSArray<NSString *> *nameParts = [auth.displayName componentsSeparatedByString:@" "];
        if (nameParts.count >= 1) data[@"FirstName"] = nameParts[0];
        if (nameParts.count >= 2) data[@"LastName"] = [nameParts.lastObject copy];
    } else if (auth.email.length > 0) {
        NSString *localPart = [[auth.email componentsSeparatedByString:@"@"] firstObject] ?: @"";
        if (localPart.length > 0) {
            data[@"FirstName"] = localPart;
        }
    }
    if (auth.photoURL) {
        data[@"UserImageUrl"] = auth.photoURL.absoluteString;
    }
    if (auth.phoneNumber) {
        NSString *mobile = PPUserManagerCanonicalE164Candidate(auth.phoneNumber);
        if ([mobile hasPrefix:@"+"] && mobile.length >= 9 && mobile.length <= 16) {
            data[@"MobileNo"] = mobile;
        }
    }
    data[@"emailVerified"] = @(auth.emailVerified);
    // Role/permissions default
    data[@"role"] = @(UserRoleUser);         // Assuming UserRoleUser is a valid enum value for normal user
    data[@"isAdmin"] = @NO;
    data[@"isSuperAdmin"] = @NO;
    data[@"isAdminAll"] = @NO;
    data[@"isBlocked"] = @NO;
    // Other default fields
    data[@"loginDate"] = now;
    data[@"updatedAt"] = now;
    data[@"loginSource"] = @(UserLoginSourcePPUsers);  // Always mark login source as main app
    // Device token (PPUserTokenID) if available from messaging
    NSString *deviceToken = [[NSUserDefaults standardUserDefaults] stringForKey:@"deviceToken"];
    if (deviceToken) {
        data[@"PPUserTokenID"] = deviceToken;
    }
    return data;
}

// MARK: - Current Auth User property
- (FIRUser * _Nullable)currentAuthUser {
    return [FIRAuth auth].currentUser;
}

#pragma mark - Auth State Monitoring

- (BOOL)pp_isAuthSessionFatalErrorCode:(NSInteger)code
{
    return code == FIRAuthErrorCodeUserDisabled ||
           code == FIRAuthErrorCodeUserNotFound ||
           code == FIRAuthErrorCodeInvalidUserToken ||
           code == FIRAuthErrorCodeUserTokenExpired;
}

- (NSUInteger)pp_incrementAndGetAuthStateVersion
{
    __block NSUInteger nextVersion = 0;
    dispatch_sync(self.authQueue, ^{
        self.authStateVersion += 1;
        nextVersion = self.authStateVersion;
    });
    return nextVersion;
}

- (BOOL)pp_isAuthStateVersionCurrent:(NSUInteger)version
{
    __block BOOL isCurrent = NO;
    dispatch_sync(self.authQueue, ^{
        isCurrent = (version == self.authStateVersion);
    });
    return isCurrent;
}

- (void)pp_startTokenRefreshTimer
{
    [self pp_stopTokenRefreshTimer];
    __weak typeof(self) weakSelf = self;
    self.tokenRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:600.0
                                                               repeats:YES
                                                                 block:^(__unused NSTimer * _Nonnull timer) {
        [weakSelf refreshIDTokenIfNeededWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[UserManager] ⚠️ Token refresh timer observed error: %@", error.localizedDescription);
            }
        }];
    }];
}

- (void)pp_stopTokenRefreshTimer
{
    [self.tokenRefreshTimer invalidate];
    self.tokenRefreshTimer = nil;
}

- (void)pp_clearLocalSessionStateForBootstrap
{
    [self pp_stopTokenRefreshTimer];
    [self stopListeningCurrentUserPermissions];
    [self stopListeningCurrentUserBlockedState];
    self.currentToken = nil;
    [self clearUserDefaults];
    _currentUser = nil;
}

- (BOOL)pp_beginSignOutIfNeeded
{
    __block BOOL shouldProceed = NO;
    dispatch_sync(self.authQueue, ^{
        if (!self.isSignOutInProgress) {
            self.isSignOutInProgress = YES;
            shouldProceed = YES;
        }
    });
    return shouldProceed;
}

- (void)pp_completeSignOut
{
    dispatch_sync(self.authQueue, ^{
        self.isSignOutInProgress = NO;
    });
}

- (void)pp_resetFirestorePersistenceAfterLogout
{
    // clearPersistence requires Firestore to be fully terminated before any active usage.
    // This app keeps long-lived managers around, so runtime clear calls are skipped to avoid
    // placing managers into a terminated Firestore instance unexpectedly.
}

- (void)pp_loadOrRepairCurrentUserForAuthUser:(FIRUser *)authUser
                                   completion:(FUCompletion)completion
{
    if (!authUser.uid.length) {
        if (completion) completion([NSError errorWithDomain:FUErrorDomain
                                                       code:FUErrorCodeInvalidCredentials
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Missing auth UID."}]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:authUser.uid];
    [self pp_resolveAuthoritativeUserDocumentSnapshotForAuthUser:authUser
                                                      completion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                                   NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed loading user document for restore: %@", error.localizedDescription);
            if (completion) completion(error);
            return;
        }

        NSMutableDictionary *repairData = [NSMutableDictionary dictionary];
        NSDictionary *data = snapshot.data ?: @{};
        BOOL shouldCreate = !snapshot.exists;

        void (^finalizeLoad)(NSError * _Nullable) = ^(NSError * _Nullable finalizeError) {
            if (finalizeError) {
                if (completion) completion(finalizeError);
                return;
            }
            [UserModel loadCurrentUserModelWithCompletion:^(UserModel * _Nullable u, NSError * _Nullable err) {
                if (u) {
                    self.currentUser = u;
                    [self cacheUser:u];
                    [self startListeningCurrentUserPermissionsWithChange:nil];
                    [self startListeningCurrentUserBlockedState];
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:PPUserManagerDidSyncCurrentUserNotification
                                      object:self
                                    userInfo:@{ @"uid": authUser.uid ?: @"" }];
                }
                if (completion) completion(err);
            }];
        };

        void (^processResolvedData)(NSDictionary *) = ^(NSDictionary *resolvedData) {
            [repairData removeAllObjects];

            if (shouldCreate) {
                [repairData addEntriesFromDictionary:[self defaultUserDataForAuthUser:authUser]];
            } else {
                id storedID = resolvedData[@"ID"];
                if (![storedID isKindOfClass:NSString.class] ||
                    [((NSString *)storedID) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
                    repairData[@"ID"] = authUser.uid;
                }

                NSString *resolvedDisplayName = [self pp_defaultDisplayNameForAuthUser:authUser];
                NSString *storedUserName = PPUserManagerTrimmedString(resolvedData[@"UserName"]);
                if (storedUserName.length == 0 && resolvedDisplayName.length > 0) {
                    repairData[@"UserName"] = resolvedDisplayName;
                }

                if (authUser.email.length > 0) {
                    NSString *email = PPUserManagerTrimmedString(authUser.email).lowercaseString;
                    if (email.length > 254) email = [email substringToIndex:254];
                    NSString *storedEmail = PPUserManagerTrimmedString(resolvedData[@"UserEmail"]).lowercaseString;
                    if (![storedEmail isEqualToString:email]) {
                        repairData[@"UserEmail"] = email;
                        repairData[@"email"] = email;
                    }
                }

                NSString *storedMobile = PPUserManagerCanonicalE164Candidate(PPSafeString(resolvedData[@"MobileNo"]));
                NSString *resolvedMobile = PPUserManagerCanonicalE164Candidate(authUser.phoneNumber ?: @"");
                if (storedMobile.length == 0 &&
                    [resolvedMobile hasPrefix:@"+"] &&
                    resolvedMobile.length >= 9 &&
                    resolvedMobile.length <= 16) {
                    repairData[@"MobileNo"] = resolvedMobile;
                }

                if (![resolvedData[@"loginSource"] respondsToSelector:@selector(integerValue)]) {
                    repairData[@"loginSource"] = @(UserLoginSourcePPUsers);
                }

                if (repairData.count > 0) {
                    repairData[@"updatedAt"] = [NSDate date];
                }
                // Keep createdAt/role/admin flags unchanged for existing docs.
            }

            if (shouldCreate || repairData.count > 0) {
                [docRef setData:repairData
                          merge:YES
                     completion:^(NSError * _Nullable setError) {
                    if (setError) {
                        NSLog(@"[UserManager] Failed repairing user document for UID %@: %@",
                              authUser.uid, setError.localizedDescription);
                    }
                    finalizeLoad(setError);
                }];
                return;
            }

            finalizeLoad(nil);
        };

        BOOL blockedInFirestore = [data[@"isBlocked"] boolValue];
        if (!shouldCreate && blockedInFirestore && self.enforceFirestoreBlockedFlag) {
            BOOL blockedCheckFromCache = snapshot.metadata.isFromCache;
            if (blockedCheckFromCache) {
                [docRef getDocumentWithSource:FIRFirestoreSourceServer
                                   completion:^(FIRDocumentSnapshot * _Nullable serverSnapshot,
                                                NSError * _Nullable serverError) {
                    NSDictionary *serverData = serverSnapshot.data ?: @{};

                    if (serverError) {
                        NSLog(@"[UserManager] Blocked-state server verification failed for UID %@: %@",
                              authUser.uid,
                              serverError.localizedDescription ?: @"unknown");
                        // Cached "blocked" can be stale. Never sign out here; continue with local snapshot.
                        processResolvedData(data);
                        return;
                    }

                    if (!serverSnapshot.exists) {
                        // Treat missing server doc as repairable state.
                        processResolvedData(data);
                        return;
                    }

                    // Keep local user session active; UI blocks actions via live blocked-state handling.
                    processResolvedData(serverData);
                }];
                return;
            }
        }

        if (!shouldCreate && blockedInFirestore && !self.enforceFirestoreBlockedFlag) {
            NSLog(@"[UserManager] Firestore isBlocked flag found for UID %@ but local enforcement is disabled.", authUser.uid);
        }

        processResolvedData(data);
    }];
}

- (void)restoreSessionOnLaunchWithCompletion:(FUCompletion)completion
{
    if (self.isSessionRestoreRunning) {
        if (completion) completion(nil);
        return;
    }
    self.isSessionRestoreRunning = YES;

    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        [self pp_clearLocalSessionStateForBootstrap];
        self.isSessionRestoreRunning = NO;
        if (completion) completion(nil);
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self validateCurrentAuthSessionWithCompletion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            if (completion) completion(error);
            return;
        }
        if (error) {
            self.isSessionRestoreRunning = NO;
            if (completion) completion(error);
            return;
        }

        [self pp_loadOrRepairCurrentUserForAuthUser:authUser completion:^(NSError * _Nullable userError) {
            self.isSessionRestoreRunning = NO;
            if (completion) completion(userError);
        }];
    }];
}

- (void)validateCurrentAuthSessionWithCompletion:(FUCompletion)completion
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) completion(nil);
        return;
    }

    [authUser reloadWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            if ([self pp_isAuthSessionFatalErrorCode:error.code]) {
                NSLog(@"[UserManager] Fatal auth session error on reload: %@", error.localizedDescription);
                [self signOutCurrentUserWithCompletion:nil];
            }
            if (completion) completion(error);
            return;
        }

        if (self.requireVerifiedEmail &&
            authUser.email.length > 0 &&
            !authUser.emailVerified) {
            NSError *verificationError =
                [NSError errorWithDomain:FUErrorDomain
                                    code:FUErrorCodeOperationNotAllowed
                                userInfo:@{NSLocalizedDescriptionKey:
                                               @"Please verify your email before continuing."}];
            if (completion) completion(verificationError);
            return;
        }

        [self refreshIDTokenIfNeededWithCompletion:^(NSError * _Nullable tokenError) {
            if (!tokenError) {
                [self pp_startTokenRefreshTimer];
            }
            if (completion) completion(tokenError);
        }];
    }];
}

- (void)refreshIDTokenIfNeededWithCompletion:(FUCompletion)completion
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) completion(nil);
        return;
    }

    [authUser getIDTokenResultWithCompletion:^(FIRAuthTokenResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(error);
            return;
        }

        NSDate *expiry = result.expirationDate ?: [NSDate distantPast];
        NSTimeInterval refreshThreshold = 5 * 60; // refresh if expiring in <= 5 min
        if ([expiry timeIntervalSinceNow] > refreshThreshold) {
            if (completion) completion(nil);
            return;
        }

        [authUser getIDTokenForcingRefresh:YES completion:^(__unused NSString * _Nullable token, NSError * _Nullable forceError) {
            if (forceError) {
                if ([self pp_isAuthSessionFatalErrorCode:forceError.code]) {
                    NSLog(@"[UserManager] Fatal auth session error on token refresh: %@", forceError.localizedDescription);
                    [self signOutCurrentUserWithCompletion:nil];
                }
                if (completion) completion(forceError);
                return;
            }
            if (completion) completion(nil);
        }];
    }];
}

- (void)startAuthStateMonitoringWithHandler:(nullable FUAuthStateHandler)handler {
    [self stopAuthStateMonitoring];
    self.authStateHandler = handler;

    __weak typeof(self) weakSelf = self;
    _authStateListenerHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth * _Nonnull auth, FIRUser * _Nullable user) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSUInteger localVersion = [strongSelf pp_incrementAndGetAuthStateVersion];

        if (!user) {
            NSLog(@"[UserManager] Auth state changed: signed out.");
            if (strongSelf.didFinishInitialSetup) {
                [strongSelf logoutAndClearAll];
            } else {
                [strongSelf pp_clearLocalSessionStateForBootstrap];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:PPUserManagerDidSignOutNotification object:strongSelf];
            FUAuthStateHandler callback = strongSelf.authStateHandler;
            if (callback) {
                callback(nil, nil);
            }
            return;
        }

        NSLog(@"[UserManager] Auth state changed: signed in UID=%@.", user.uid);
        [strongSelf validateCurrentAuthSessionWithCompletion:^(NSError * _Nullable validationError) {
            if (![strongSelf pp_isAuthStateVersionCurrent:localVersion]) {
                return;
            }
            if (validationError) {
                FUAuthStateHandler callback = strongSelf.authStateHandler;
                if (callback) {
                    callback(nil, validationError);
                }
                return;
            }

            [strongSelf pp_loadOrRepairCurrentUserForAuthUser:user completion:^(NSError * _Nullable loadError) {
                if (![strongSelf pp_isAuthStateVersionCurrent:localVersion]) {
                    return;
                }
                FUAuthStateHandler callback = strongSelf.authStateHandler;
                if (callback) {
                    callback(loadError ? nil : strongSelf.currentUser, loadError);
                }
            }];
        }];
    }];
}

- (void)stopAuthStateMonitoring {
    if (_authStateListenerHandle) {
        [[FIRAuth auth] removeAuthStateDidChangeListener:_authStateListenerHandle];
        _authStateListenerHandle = nil;
    }
    [self pp_incrementAndGetAuthStateVersion];
    self.authStateHandler = nil;
}

- (void)reloadCurrentUserWithCompletion:(FUUserCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *error = [NSError errorWithDomain:FUErrorDomain
                                             code:FUErrorCodeInvalidCredentials
                                         userInfo:@{NSLocalizedDescriptionKey: @"No current user to reload."}];
        if (completion) completion(nil, error);
        return;
    }

    [self validateCurrentAuthSessionWithCompletion:^(NSError * _Nullable validationError) {
        if (validationError) {
            if (completion) completion(nil, validationError);
            return;
        }
        [self pp_loadOrRepairCurrentUserForAuthUser:authUser completion:^(NSError * _Nullable loadError) {
            if (completion) completion(loadError ? nil : self.currentUser, loadError);
        }];
    }];
}

#pragma mark - Sign In Methods

- (void)signInWithGoogleIDToken:(NSString *)idToken
                    accessToken:(NSString *)accessToken
                     completion:(FUUserCompletion)completion {
    if (!idToken || !accessToken) {
        NSError *error = [NSError errorWithDomain:FUErrorDomain
                                             code:FUErrorCodeInvalidParameter
                                         userInfo:@{NSLocalizedDescriptionKey: @"Google ID token or access token missing."}];
        if (completion) completion(nil, error);
        return;
    }
    // Create Google Auth credential
    FIRAuthCredential *credential = [FIRGoogleAuthProvider credentialWithIDToken:idToken accessToken:accessToken];
    NSLog(@"[UserManager] Signing in with Google credentials...");
    [[FIRAuth auth] signInWithCredential:credential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Google sign-in failed: %@", error);
            if (completion) completion(nil, error);
        } else {
            NSLog(@"[UserManager] Google sign-in succeeded for user: %@", authResult.user.uid);
            // Check if new user account and create Firestore doc if needed
            BOOL isNew = authResult.additionalUserInfo.isNewUser;
            [self handlePostSignInForAuthResult:authResult isNewUser:isNew completion:completion];
        }
    }];
}

- (void)signInWithAppleIDToken:(NSString *)idToken
                       rawNonce:(NSString *)nonce
                     completion:(FUUserCompletion)completion {
    if (!idToken || !nonce) {
        NSError *error = [NSError errorWithDomain:FUErrorDomain
                                             code:FUErrorCodeInvalidParameter
                                         userInfo:@{NSLocalizedDescriptionKey: @"Apple ID token or nonce missing."}];
        if (completion) completion(nil, error);
        return;
    }
    // Create Apple Auth credential
    FIRAuthCredential *credential = [FIROAuthProvider credentialWithProviderID:@"apple.com"
                                                                       IDToken:idToken
                                                                     rawNonce:nonce];
    NSLog(@"[UserManager] Signing in with Apple credentials...");
    [[FIRAuth auth] signInWithCredential:credential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Apple sign-in failed: %@", error);
            if (completion) completion(nil, error);
        } else {
            NSLog(@"[UserManager] Apple sign-in succeeded for user: %@", authResult.user.uid);
            BOOL isNew = authResult.additionalUserInfo.isNewUser;
            [self handlePostSignInForAuthResult:authResult isNewUser:isNew completion:completion];
        }
    }];
}

- (void)signInWithPhoneVerificationID:(NSString *)verificationID
                       verificationCode:(NSString *)code
                            completion:(FUUserCompletion)completion {
    if (!verificationID || !code) {
        NSError *error = [NSError errorWithDomain:FUErrorDomain
                                             code:FUErrorCodeInvalidParameter
                                         userInfo:@{NSLocalizedDescriptionKey: @"Verification ID or code is missing."}];
        if (completion) completion(nil, error);
        return;
    }
    FIRAuthCredential *credential = [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID verificationCode:code];
    NSLog(@"[UserManager] Signing in with phone credential...");
    [[FIRAuth auth] signInWithCredential:credential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Phone sign-in failed: %@", error);
            if (completion) completion(nil, error);
        } else {
            NSLog(@"[UserManager] Phone sign-in succeeded for user: %@", authResult.user.uid);
            BOOL isNew = authResult.additionalUserInfo.isNewUser;
            [self handlePostSignInForAuthResult:authResult isNewUser:isNew completion:completion];
        }
    }];
}

// Internal helper after any sign-in succeeds: ensure Firestore user doc exists, load model, etc.
- (void)handlePostSignInForAuthResult:(FIRAuthDataResult *)authResult
                           isNewUser:(BOOL)isNew
                           completion:(FUUserCompletion)completion {
    FIRUser *authUser = authResult.user;
    if (isNew) {
        // New user: create a Firestore doc with default data
        NSDictionary *initialData = [self defaultUserDataForAuthUser:authUser];
        [self createUserDocumentForUID:authUser.uid initialData:initialData completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[UserManager] Error creating Firestore doc for new user: %@", error);
                // Proceed to load model even if doc creation failed (maybe security rules allow read default)
            }
            [self finalizeSignInForAuthUser:authUser completion:completion];
        }];
    } else {
        [self finalizeSignInForAuthUser:authUser completion:completion];
    }
}

// Finalize sign-in by loading the user model and caching it
- (void)finalizeSignInForAuthUser:(FIRUser *)authUser completion:(FUUserCompletion)completion {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *pushToken = PPSafeString([prefs valueForKey:@"PPUserTokenID"]) ?: nil;

    [self validateCurrentAuthSessionWithCompletion:^(NSError * _Nullable validationError) {
        if (validationError) {
            if (completion) completion(nil, validationError);
            return;
        }

        [self pp_loadOrRepairCurrentUserForAuthUser:authUser completion:^(NSError * _Nullable loadError) {
            if (loadError) {
                BOOL isBlockedAccountError =
                    [loadError.domain isEqualToString:FUErrorDomain] &&
                    loadError.code == FUErrorCodePermissionDenied;
                if (isBlockedAccountError) {
                    NSLog(@"[UserManager] Blocked account sign-in rejected for UID %@.", authUser.uid);
                    if (completion) completion(nil, loadError);
                    return;
                }

                NSLog(@"[UserManager] Warning: failed to load repaired user model after sign-in: %@",
                      loadError.localizedDescription);
                UserModel *fallback = [UserModel fromAuthUser:authUser
                                                       rootDoc:nil
                                                   permissions:nil
                                                        claims:nil];
                fallback.PPUserTokenID = pushToken ?: @"";
                self.currentUser = fallback;
                [self cacheUser:fallback];
                [self startListeningCurrentUserBlockedState];
                if (completion) completion(fallback, loadError);
                return;
            }

            if (pushToken.length > 0) {
                self.currentUser.PPUserTokenID = pushToken;
                [self updateCurrentUserWithPPUserTokenID:pushToken];
            }
            if (completion) completion(self.currentUser, nil);
        }];
    }];
}

#pragma mark - Sign Out & Deletion

- (void)signOutCurrentUserWithCompletion:(nullable FUCompletion)completion {
    if (![self pp_beginSignOutIfNeeded]) {
        if (completion) completion(nil);
        return;
    }

    void (^finishSignOut)(NSError * _Nullable) = ^(NSError * _Nullable finishError) {
        [self pp_completeSignOut];
        if (completion) completion(finishError);
    };

    [self pp_stopTokenRefreshTimer];
    self.currentToken = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"deviceToken"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PPUserTokenID"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[FIRMessaging messaging] deleteTokenWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Warning: Failed to clear FCM token on logout: %@", error.localizedDescription);
        }
    }];

    NSError *signOutError = nil;
    BOOL status = [[FIRAuth auth] signOut:&signOutError];
    if (!status) {
        NSLog(@"[UserManager] Error signing out: %@", signOutError.localizedDescription);
        finishSignOut(signOutError);
        return;
    }

    // Auth listener handles the canonical local cleanup/notification path.
    // Fallback to direct cleanup only if listener is not active.
    if (!self.authStateListenerHandle) {
        [self logoutAndClearAll];
        [[NSNotificationCenter defaultCenter] postNotificationName:PPUserManagerDidSignOutNotification object:self];
    }
    [self pp_resetFirestorePersistenceAfterLogout];
    NSLog(@"[UserManager] User signed out successfully.");
    finishSignOut(nil);
}

- (void)deleteCurrentUserAccountWithCompletion:(FUCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *error = [NSError errorWithDomain:FUErrorDomain
                                             code:FUErrorCodeInvalidCredentials
                                         userInfo:@{NSLocalizedDescriptionKey: @"No logged-in user to delete."}];
        if (completion) completion(error);
        return;
    }
    // Deleting user - requires recent login, otherwise error .requiresRecentLogin
    NSLog(@"[UserManager] Deleting user account UID=%@ ...", authUser.uid);
    [authUser deleteWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Error deleting user account: %@", error);
            if (completion) completion(error);
        } else {
            // Also delete user document in Firestore for cleanup
            [self deleteUserDocumentForUID:authUser.uid completion:^(NSError * _Nullable docErr) {
                if (docErr) {
                    NSLog(@"[UserManager] Warning: failed to delete user Firestore doc: %@", docErr);
                }
                // Clear any local data
                [self logoutAndClearAll];
                NSLog(@"[UserManager] User account deleted successfully.");
                if (completion) completion(nil);
            }];
        }
    }];
}

#pragma mark - User Profile Updates

- (BOOL)pp_requiresRecentLoginForSensitiveChange:(FIRUser *)authUser
{
    NSDate *lastSignIn = authUser.metadata.lastSignInDate;
    if (!lastSignIn) {
        return YES;
    }
    NSTimeInterval secondsSinceSignIn = fabs([lastSignIn timeIntervalSinceNow]);
    return secondsSinceSignIn > 300.0;
}

- (void)updateCurrentUserProfileWithValues:(NSDictionary<NSString *,id> *)values
                                completion:(FUCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain
                                           code:FUErrorCodeInvalidCredentials
                                       userInfo:@{NSLocalizedDescriptionKey: @"No current user to update."}];
        if (completion) completion(err);
        return;
    }
    NSMutableDictionary<NSString *, id> *normalizedValues = [NSMutableDictionary dictionary];
    [values enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![key isKindOfClass:NSString.class] || key.length == 0) return;
        if (!obj || obj == [NSNull null]) return;
        if ([obj isKindOfClass:NSString.class]) {
            NSString *trimmed = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            normalizedValues[key] = trimmed;
            return;
        }
        normalizedValues[key] = obj;
    }];

    NSNumber *allowEmailChangeAfterReauth = normalizedValues[@"ppAllowEmailChangeAfterReauth"];
    BOOL didExplicitReauth = [allowEmailChangeAfterReauth respondsToSelector:@selector(boolValue)] && [allowEmailChangeAfterReauth boolValue];
    [normalizedValues removeObjectForKey:@"ppAllowEmailChangeAfterReauth"];

    NSString *newEmail = normalizedValues[FUUpdateKeyEmail];
    if (newEmail && [newEmail isKindOfClass:[NSString class]]) {
        NSString *trimmedEmail = [newEmail lowercaseString];
        if (trimmedEmail.length == 0) {
            NSError *invalidEmailError = [NSError errorWithDomain:FUErrorDomain
                                                             code:FUErrorCodeInvalidParameter
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Email cannot be empty."}];
            if (completion) completion(invalidEmailError);
            return;
        }
        if (trimmedEmail.length > 0 &&
            ![trimmedEmail isEqualToString:[authUser.email ?: @"" lowercaseString]] &&
            !didExplicitReauth) {
            NSError *reauthError = [NSError errorWithDomain:FUErrorDomain
                                                       code:FUErrorCodeRequiresRecentLogin
                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                                  @"Please reauthenticate before changing email."}];
            if (completion) completion(reauthError);
            return;
        }
    }
    NSString *newDisplayName = normalizedValues[FUUpdateKeyDisplayName];
    if (newDisplayName && [newDisplayName isKindOfClass:[NSString class]] && newDisplayName.length == 0) {
        NSError *invalidNameError = [NSError errorWithDomain:FUErrorDomain
                                                        code:FUErrorCodeInvalidParameter
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Display name cannot be empty."}];
        if (completion) completion(invalidNameError);
        return;
    }
    if ([normalizedValues[@"UserName"] isKindOfClass:[NSString class]]) {
        NSString *userName = normalizedValues[@"UserName"];
        if (userName.length == 0) {
            NSError *invalidUserNameError = [NSError errorWithDomain:FUErrorDomain
                                                                 code:FUErrorCodeInvalidParameter
                                                             userInfo:@{NSLocalizedDescriptionKey: @"User name cannot be empty."}];
            if (completion) completion(invalidUserNameError);
            return;
        }
    }
    if ([normalizedValues[@"MobileNo"] isKindOfClass:[NSString class]]) {
        NSString *mobile = PPUserManagerTrimmedString(normalizedValues[@"MobileNo"]);
        if (mobile.length == 0) {
            // Empty mobile value means "no change" in profile update flow.
            [normalizedValues removeObjectForKey:@"MobileNo"];
        } else {
            NSString *canonicalMobile = PPUserManagerCanonicalE164Candidate(mobile);
            NSString *canonicalDialCode = @"";
            if ([normalizedValues[@"CountryDialCode"] isKindOfClass:NSString.class]) {
                canonicalDialCode = PPUserManagerCanonicalDialCode(normalizedValues[@"CountryDialCode"]);
                if (canonicalDialCode.length > 0) {
                    normalizedValues[@"CountryDialCode"] = canonicalDialCode;
                }
            }

            if (canonicalMobile.length == 0) {
                NSError *invalidMobileError = [NSError errorWithDomain:FUErrorDomain
                                                                  code:FUErrorCodeInvalidParameter
                                                              userInfo:@{NSLocalizedDescriptionKey: @"Mobile number must be in E.164 format."}];
                if (completion) completion(invalidMobileError);
                return;
            }
            if (![canonicalMobile hasPrefix:@"+"]) {
                NSString *dialDigits = [canonicalDialCode stringByReplacingOccurrencesOfString:@"+" withString:@""];
                if (dialDigits.length > 0) {
                    canonicalMobile = [NSString stringWithFormat:@"+%@%@", dialDigits, canonicalMobile];
                } else {
                    canonicalMobile = [NSString stringWithFormat:@"+%@", canonicalMobile];
                }
            }

            NSError *mobileError = nil;
            NSRegularExpression *mobileRegex =
                [NSRegularExpression regularExpressionWithPattern:@"^\\+[0-9]{8,15}$"
                                                         options:0
                                                           error:&mobileError];
            if (mobileError ||
                [mobileRegex numberOfMatchesInString:canonicalMobile options:0 range:NSMakeRange(0, canonicalMobile.length)] == 0) {
                NSError *invalidMobileError = [NSError errorWithDomain:FUErrorDomain
                                                                   code:FUErrorCodeInvalidParameter
                                                               userInfo:@{NSLocalizedDescriptionKey: @"Mobile number must be in E.164 format."}];
                if (completion) completion(invalidMobileError);
                return;
            }
            normalizedValues[@"MobileNo"] = canonicalMobile;
        }
    }
    if ([normalizedValues[@"CountryIsoCode"] isKindOfClass:[NSString class]]) {
        NSString *iso = [normalizedValues[@"CountryIsoCode"] uppercaseString];
        NSError *isoError = nil;
        NSRegularExpression *isoRegex =
            [NSRegularExpression regularExpressionWithPattern:@"^[A-Z]{2}$"
                                                     options:0
                                                       error:&isoError];
        if (isoError ||
            [isoRegex numberOfMatchesInString:iso options:0 range:NSMakeRange(0, iso.length)] == 0) {
            NSError *invalidISOError = [NSError errorWithDomain:FUErrorDomain
                                                           code:FUErrorCodeInvalidParameter
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Country ISO code must be a 2-letter code."}];
            if (completion) completion(invalidISOError);
            return;
        }
        normalizedValues[@"CountryIsoCode"] = iso;
    }
    if ([normalizedValues[@"CountryDialCode"] isKindOfClass:[NSString class]]) {
        NSString *dialCode = PPUserManagerCanonicalDialCode(normalizedValues[@"CountryDialCode"]);
        NSError *dialError = nil;
        NSRegularExpression *dialRegex =
            [NSRegularExpression regularExpressionWithPattern:@"^\\+[0-9]{1,4}$"
                                                     options:0
                                                       error:&dialError];
        if (dialError ||
            [dialRegex numberOfMatchesInString:dialCode options:0 range:NSMakeRange(0, dialCode.length)] == 0) {
            NSError *invalidDialError = [NSError errorWithDomain:FUErrorDomain
                                                            code:FUErrorCodeInvalidParameter
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Country dial code is invalid."}];
            if (completion) completion(invalidDialError);
            return;
        }
        normalizedValues[@"CountryDialCode"] = dialCode;
    }
    id rawCountryID = normalizedValues[@"CountryID"];
    if (rawCountryID && ![rawCountryID respondsToSelector:@selector(integerValue)]) {
        NSError *invalidCountryIDError = [NSError errorWithDomain:FUErrorDomain
                                                             code:FUErrorCodeInvalidParameter
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Country ID must be numeric."}];
        if (completion) completion(invalidCountryIDError);
        return;
    }
    if (rawCountryID && [rawCountryID integerValue] < 0) {
        NSError *invalidCountryIDError = [NSError errorWithDomain:FUErrorDomain
                                                             code:FUErrorCodeInvalidParameter
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Country ID cannot be negative."}];
        if (completion) completion(invalidCountryIDError);
        return;
    }
    NSArray<NSString *> *restrictedProfileKeys = @[@"isAdmin", @"isSuperAdmin", @"isBlocked", @"role"];
    for (NSString *restrictedKey in restrictedProfileKeys) {
        if (normalizedValues[restrictedKey] != nil) {
            NSLog(@"[UserManager] Ignoring restricted profile field update: %@", restrictedKey);
            [normalizedValues removeObjectForKey:restrictedKey];
        }
    }
    NSString *newPhotoURL = normalizedValues[FUUpdateKeyPhotoURL];
    if ([newPhotoURL isKindOfClass:NSString.class] && newPhotoURL.length > 0) {
        NSURL *candidateURL = [NSURL URLWithString:newPhotoURL];
        if (!candidateURL) {
            NSError *invalidPhotoURLError = [NSError errorWithDomain:FUErrorDomain
                                                                 code:FUErrorCodeInvalidParameter
                                                             userInfo:@{NSLocalizedDescriptionKey: @"Photo URL is invalid."}];
            if (completion) completion(invalidPhotoURLError);
            return;
        }
    }

    // Prepare group dispatch to handle multiple updates
    dispatch_group_t group = dispatch_group_create();
    __block NSError *aggError = nil;
    // If email update is requested
    if (newEmail && [newEmail isKindOfClass:[NSString class]]) {
        NSString *trimmedEmail = [newEmail lowercaseString];
        dispatch_group_enter(group);
        [authUser updateEmail:trimmedEmail completion:^(NSError * _Nullable error) {
            if (error) {
                aggError = error;
                NSLog(@"[UserManager] Failed to update email: %@", error);
            } else {
                NSLog(@"[UserManager] Email updated in Auth.");
                // Also update Firestore document field
                [self updateUserDocumentForUID:authUser.uid
                                        fields:@{
                                            @"UserEmail": trimmedEmail,
                                            @"emailVerified": @(NO)
                                        }
                                    completion:nil];
            }
            dispatch_group_leave(group);
        }];
    }
    // If phone number update is requested (requires reauth with credential)
    // We won't handle phone here in bulk (use updatePhoneNumberForCurrentUser instead).
    // If displayName update is requested
    NSString *newName = normalizedValues[FUUpdateKeyDisplayName];
    NSURL *preservedPhotoURL = authUser.photoURL;
    if (!(newPhotoURL.length > 0) && !preservedPhotoURL) {
        NSString *cachedPhotoURLString = @"";
        if ([self.currentUser.UserImageUrl isKindOfClass:NSURL.class]) {
            cachedPhotoURLString = PPUserManagerTrimmedString(self.currentUser.UserImageUrl.absoluteString);
        }
        if (cachedPhotoURLString.length == 0 &&
            [normalizedValues[@"UserImageUrl"] isKindOfClass:NSString.class]) {
            cachedPhotoURLString = PPUserManagerTrimmedString(normalizedValues[@"UserImageUrl"]);
        }
        NSURL *candidatePhotoURL = [NSURL URLWithString:cachedPhotoURLString];
        if (candidatePhotoURL) {
            preservedPhotoURL = candidatePhotoURL;
        }
    }
    NSString *currentDisplayName = [PPUserManagerTrimmedString(authUser.displayName) copy];
    BOOL shouldUpdateDisplayName =
        [newName isKindOfClass:NSString.class] &&
        newName.length > 0 &&
        ![newName isEqualToString:currentDisplayName];
    if (shouldUpdateDisplayName) {
        dispatch_group_enter(group);
        FIRUserProfileChangeRequest *changeReq = [authUser profileChangeRequest];
        changeReq.displayName = newName;
        if (!(newPhotoURL.length > 0) && preservedPhotoURL) {
            // Defensive: keep existing photo URL while updating displayName.
            changeReq.photoURL = preservedPhotoURL;
        }
        [changeReq commitChangesWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                aggError = error;
                NSLog(@"[UserManager] Failed to update displayName: %@", error);
            } else {
                NSLog(@"[UserManager] DisplayName updated in Auth.");
                [self updateUserDocumentForUID:authUser.uid
                                        fields:@{@"UserName": newName}
                                    completion:nil];
            }
            dispatch_group_leave(group);
        }];
    }
    // If photoURL update is requested
    NSString *photoURLStr = normalizedValues[FUUpdateKeyPhotoURL];
    if (photoURLStr && [photoURLStr isKindOfClass:[NSString class]]) {
        NSURL *photoURL = [NSURL URLWithString:photoURLStr];
        if (photoURL) {
            dispatch_group_enter(group);
            FIRUserProfileChangeRequest *changeReq = [authUser profileChangeRequest];
            changeReq.photoURL = photoURL;
            [changeReq commitChangesWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    aggError = error;
                    NSLog(@"[UserManager] Failed to update photoURL: %@", error);
                } else {
                    NSLog(@"[UserManager] PhotoURL updated in Auth.");
                    [self updateUserDocumentForUID:authUser.uid
                                            fields:@{@"UserImageUrl": photoURLStr}
                                        completion:nil];
                }
                dispatch_group_leave(group);
            }];
        }
    }
    // If custom claims update is requested (admin)
    id customClaims = normalizedValues[FUUpdateKeyCustomClaims];
    if (customClaims) {
        dispatch_group_enter(group);
        if ([customClaims isKindOfClass:[NSDictionary class]]) {
            // Call a Cloud Function to set custom claims for current user
            [[_functions HTTPSCallableWithName:@"setCustomUserClaims"] callWithObject:@{@"claims": customClaims}
                                                                          completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
                if (error) {
                    aggError = error;
                    NSLog(@"[UserManager] Failed to set custom claims via Cloud Function: %@", error);
                } else {
                    NSLog(@"[UserManager] Custom claims update requested.");
                }
                dispatch_group_leave(group);
            }];
        } else {
            // Invalid format
            aggError = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"CustomClaims must be a dictionary."}];
            dispatch_group_async(group, dispatch_get_main_queue(), ^{ /* no async work, just mark group */ });
        }
    }
    // Firestore only fields (any other keys in values that are not handled above)
    NSMutableDictionary *firestoreFields = [NSMutableDictionary dictionary];
    for (NSString *key in normalizedValues) {
        if ([key isEqualToString:FUUpdateKeyEmail] || [key isEqualToString:FUUpdateKeyDisplayName] ||
            [key isEqualToString:FUUpdateKeyPhotoURL] || [key isEqualToString:FUUpdateKeyPhoneNumber] ||
            [key isEqualToString:FUUpdateKeyCustomClaims]) {
            continue; // skip keys already handled
        }
        if ([key isEqualToString:@"createdAt"] ||
            [key isEqualToString:@"uid"] ||
            [key isEqualToString:@"ID"]) {
            continue;
        }
        firestoreFields[key] = normalizedValues[key];
    }
    if (firestoreFields.count > 0) {
        dispatch_group_enter(group);
        [self updateUserDocumentForUID:authUser.uid fields:firestoreFields completion:^(NSError * _Nullable error) {
            if (error) {
                aggError = error;
                NSLog(@"[UserManager] Firestore fields update failed: %@", error);
            } else {
                NSLog(@"[UserManager] Firestore fields updated: %@", firestoreFields);
            }
            dispatch_group_leave(group);
        }];
    }
    // Notify completion when all updates finished
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // Refresh currentUser model from Firestore to reflect changes
        if (self.currentUser) {
            [UserModel loadCurrentUserModelWithCompletion:^(UserModel * _Nullable u, NSError * _Nullable err) {
                if (u) {
                    self.currentUser = u;
                    [self cacheUser:u];
                }
                if (completion) completion(aggError);
            }];
        } else {
            if (completion) completion(aggError);
        }
    });
}

- (void)updateUserProfileForUID:(NSString *)userUID
                         values:(NSDictionary<NSString *,id> *)values
                     completion:(FUCompletion)completion {
    // For admin use: update another user's profile.
    if (!userUID) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UserUID is required"}];
        if (completion) completion(err);
        return;
    }
    // If updating someone other than current user, we likely need admin privileges (e.g., via Cloud Functions).
    NSString *currentUID = [FIRAuth auth].currentUser.uid;
    if (![userUID isEqualToString:currentUID]) {
        // For updates to a different user, use Firestore and possibly Cloud Function for auth fields.
        NSLog(@"[UserManager] Admin updating user %@ with values: %@", userUID, values);
        // We cannot directly update another user's Auth profile from client SDK; only Firestore fields and custom claims via function.
        NSMutableDictionary *firestoreFields = [NSMutableDictionary dictionary];
        for (NSString *key in values) {
            if ([key isEqualToString:FUUpdateKeyCustomClaims]) continue;
            firestoreFields[key] = values[key];
        }
        // Update Firestore document fields
        [self updateUserDocumentForUID:userUID fields:firestoreFields completion:^(NSError * _Nullable error) {
            if (error) {
                if (completion) completion(error);
            } else {
                // If custom claims provided, call function
                id claims = values[FUUpdateKeyCustomClaims];
                if (claims && [claims isKindOfClass:[NSDictionary class]]) {
                    [[self->_functions HTTPSCallableWithName:@"setCustomUserClaims"] callWithObject:@{@"uid": userUID, @"claims": claims} completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
                        if (error) {
                            if (completion) completion(error);
                        } else {
                            if (completion) completion(nil);
                        }
                    }];
                } else {
                    if (completion) completion(nil);
                }
            }
        }];
    } else {
        // If trying to update current user, just call the other method
        [self updateCurrentUserProfileWithValues:values completion:completion];
    }
}

- (void)updateCurrentUserEmail:(NSString *)email completion:(FUCompletion)completion {
    if (!email) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"Email must not be nil."}];
        if (completion) completion(err);
        return;
    }
    [self updateCurrentUserProfileWithValues:@{FUUpdateKeyEmail: email} completion:completion];
}

- (void)updateCurrentUserPhoneNumber:(NSString *)phoneNumber completion:(FUCompletion)completion {
    if (!phoneNumber) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"Phone number must not be nil."}];
        if (completion) completion(err);
        return;
    }
    // This method will initiate an SMS to verify the new number, then update it.
    NSLog(@"[UserManager] Updating current user's phone number to %@", phoneNumber);
    // Send verification code to new phone number
    [[FIRPhoneAuthProvider provider] verifyPhoneNumber:phoneNumber
                                           UIDelegate:nil
                                           completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to send verification SMS: %@", error);
            if (completion) completion(error);
        } else {
            // Prompt user for the verification code via a UI prompt
            NSLog(@"[UserManager] Verification code sent for phone update, requesting user input...");
            [UserManager showPromptOnTopController];  // This should prompt user to enter the code
            // In a real implementation, the app should capture the code and call the following:
            // [self finalizePhoneNumberUpdateWithVerificationID:verificationID verificationCode:code completion:completion];
            // For safety, call completion with an error if not implemented:
            NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeOperationNotAllowed userInfo:@{NSLocalizedDescriptionKey: @"Phone update flow not fully implemented."}];
            if (completion) completion(err);
        }
    }];
}

- (void)updateCurrentUserDisplayName:(NSString *)displayName completion:(FUCompletion)completion {
    if (!displayName) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"Display name must not be nil."}];
        if (completion) completion(err);
        return;
    }
    [self updateCurrentUserProfileWithValues:@{FUUpdateKeyDisplayName: displayName} completion:completion];
}

#pragma mark - Multi-Provider Account Linking

- (void)linkEmailProviderWithEmail:(NSString *)email
                          password:(NSString *)password
                        completion:(FUUserCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user to link provider."}];
        if (completion) completion(nil, err);
        return;
    }
    FIRAuthCredential *cred = [FIREmailAuthProvider credentialWithEmail:email password:password];
    NSLog(@"[UserManager] Linking email/password provider to current user...");
    [authUser linkWithCredential:cred completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to link email provider: %@", error);
            if (completion) completion(nil, error);
        } else {
            NSLog(@"[UserManager] Email provider linked successfully.");
            // Update user model's email fields
            self.currentUser.UserEmail = email;
            [self updateUserDocumentForUID:authUser.uid fields:@{@"UserEmail": email} completion:nil];
            if (completion) completion(self.currentUser, nil);
        }
    }];
}

- (void)linkPhoneNumberProviderWithNumber:(NSString *)phoneNumber
                               completion:(FUUserCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user to link provider."}];
        if (completion) completion(nil, err);
        return;
    }
    NSLog(@"[UserManager] Linking phone number provider for number: %@", phoneNumber);
    // Send verification SMS
    [[FIRPhoneAuthProvider provider] verifyPhoneNumber:phoneNumber UIDelegate:nil completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to send verification for linking phone: %@", error);
            if (completion) completion(nil, error);
        } else {
            // Normally, here we should prompt for SMS code, but we'll assume code is obtained for this flow.
            [UserManager showPromptOnTopController];
            // NOTE: In practice, after user enters the code, you'd call:
            // FIRAuthCredential *phoneCred = [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID verificationCode:code];
            // [authUser linkWithCredential:phoneCred completion:...]
            NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeOperationNotAllowed userInfo:@{NSLocalizedDescriptionKey: @"Phone linking requires user to input code."}];
            if (completion) completion(nil, err);
        }
    }];
}

- (void)linkAppleProviderWithIDToken:(NSString *)idToken
                               nonce:(NSString *)nonce
                          completion:(FUUserCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user to link provider."}];
        if (completion) completion(nil, err);
        return;
    }
    FIRAuthCredential *appleCred = [FIROAuthProvider credentialWithProviderID:@"apple.com" IDToken:idToken rawNonce:nonce];
    NSLog(@"[UserManager] Linking Apple ID provider to current user...");
    [authUser linkWithCredential:appleCred completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to link Apple provider: %@", error);
            if (completion) completion(nil, error);
        } else {
            NSLog(@"[UserManager] Apple provider linked successfully.");
            // If Apple returned a new displayName or email and our user didn't have one, update Firestore doc
            if (authResult.user.displayName) {
                [self updateUserDocumentForUID:authUser.uid
                                        fields:@{@"UserName": authResult.user.displayName}
                                    completion:nil];
            }
            if (authResult.user.email) {
                [self updateUserDocumentForUID:authUser.uid
                                        fields:@{@"UserEmail": authResult.user.email}
                                    completion:nil];
            }
            if (completion) completion(self.currentUser, nil);
        }
    }];
}

- (void)unlinkProvider:(NSString *)providerID completion:(FUUserCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user to unlink provider."}];
        if (completion) completion(nil, err);
        return;
    }
    NSLog(@"[UserManager] Unlinking provider %@ from current user...", providerID);
    [authUser unlinkFromProvider:providerID completion:^(FIRUser * _Nullable user, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to unlink provider: %@", error);
            if (completion) completion(nil, error);
        } else {
            NSLog(@"[UserManager] Provider %@ unlinked.", providerID);
            // If email/password was unlinked (i.e., providerID == @"password"), perhaps clear stored email?
            if ([providerID isEqualToString:FIREmailAuthProviderID]) {
                // Keep the Firebase Auth email property intact, but maybe mark something in user model if needed.
            }
            if (completion) completion(self.currentUser, nil);
        }
    }];
}

- (void)fetchLinkedProvidersWithCompletion:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user."}];
        completion(@[], err);
        return;
    }
    // Fetch sign-in methods for the user's email (this will include "password" if email/password is linked)
    if (authUser.email) {
        [[FIRAuth auth] fetchSignInMethodsForEmail:authUser.email completion:^(NSArray<NSString *> * _Nullable methods, NSError * _Nullable error) {
            if (error) {
                completion(nil, error);
            } else {
                // Combine with providerData providers (like phone, apple, google)
                NSMutableSet *providers = [NSMutableSet set];
                for (id<FIRUserInfo> info in authUser.providerData) {
                    [providers addObject:info.providerID];
                }
                for (NSString *method in methods) {
                    // The "password" method corresponds to FIREmailAuthProviderID
                    NSString *provID = [method isEqualToString:@"password"] ? FIREmailAuthProviderID : method;
                    [providers addObject:provID];
                }
                completion([providers allObjects], nil);
            }
        }];
    } else {
        // No email on account (e.g., phone-only account)
        NSMutableArray *providerIDs = [NSMutableArray array];
        for (id<FIRUserInfo> info in authUser.providerData) {
            [providerIDs addObject:info.providerID];
        }
        completion(providerIDs, nil);
    }
}

- (void)updatePhoneNumberForCurrentUser:(NSString *)phoneNumber completion:(FUCompletion)completion {
    // Alias to updateCurrentUserPhoneNumber for clarity
    [self updateCurrentUserPhoneNumber:phoneNumber completion:completion];
}

#pragma mark - Photo/Avatar Management

- (void)uploadUserAvatar:(UIImage *)avatarImage
            maxDimension:(CGFloat)maxDimension
             maxFileSize:(NSUInteger)maxFileSize
                progress:(FUProgressHandler)progress
              completion:(FUURLCompletion)completion {
    if (!avatarImage) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"Image is nil."}];
        if (completion) completion(nil, err);
        return;
    }
    // Resize image if larger than maxDimension
    UIImage *imageToUpload = avatarImage;
    if (maxDimension > 0) {
        CGFloat maxDim = MAX(imageToUpload.size.width, imageToUpload.size.height);
        if (maxDim > maxDimension) {
            CGFloat scale = maxDimension / maxDim;
            CGSize newSize = CGSizeMake(imageToUpload.size.width * scale, imageToUpload.size.height * scale);
            UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
            [imageToUpload drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resized) {
                imageToUpload = resized;
            }
        }
    }
    // Compress image to JPEG within maxFileSize if specified
    NSData *imageData = UIImageJPEGRepresentation(imageToUpload, 0.9);
    if (maxFileSize > 0) {
        CGFloat compression = 0.9;
        while ([imageData length] > maxFileSize && compression > 0.1) {
            compression -= 0.1;
            imageData = UIImageJPEGRepresentation(imageToUpload, compression);
        }
    }
    // Get storage reference path: "users/<uid>/avatar.jpg"
    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No user logged in for image upload."}];
        if (completion) completion(nil, err);
        return;
    }
    NSString *imageName = @"avatar.jpg";
    FIRStorageReference *storageRef = [[FIRStorage storage] reference];
    FIRStorageReference *avatarRef = [[storageRef child:@"users"] child:[NSString stringWithFormat:@"%@/%@", uid, imageName]];
    FIRStorageUploadTask *uploadTask = [avatarRef putData:imageData metadata:nil completion:^(FIRStorageMetadata *metadata, NSError *error) {
        if (error) {
            NSLog(@"[UserManager] Avatar upload failed: %@", error);
            if (completion) completion(nil, error);
        } else {
            // Fetch the download URL
            [avatarRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[UserManager] Failed to get download URL: %@", error);
                    if (completion) completion(nil, error);
                } else {
                    NSLog(@"[UserManager] Avatar uploaded successfully. URL: %@", URL.absoluteString);
                    if (completion) completion(URL, nil);
                }
            }];
        }
    }];
    // Monitor upload progress if a handler is provided
    if (progress) {
        [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
            double percent = (snapshot.progress.completedUnitCount * 1.0) / snapshot.progress.totalUnitCount;
            progress(percent);
        }];
    }
}

- (void)updateUserAvatarWithURL:(NSURL *)avatarURL completion:(FUCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user."}];
        if (completion) completion(err);
        return;
    }
    // Update Auth profile
    FIRUserProfileChangeRequest *changeReq = [authUser profileChangeRequest];
    changeReq.photoURL = avatarURL;
    [changeReq commitChangesWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to update Auth photoURL: %@", error);
            if (completion) completion(error);
        } else {
            // Update Firestore doc as well
            [self updateUserDocumentForUID:authUser.uid
                                    fields:@{@"UserImageUrl": avatarURL.absoluteString}
                                completion:^(NSError * _Nullable error2) {
                if (error2) {
                    NSLog(@"[UserManager] Warning: Auth photo updated, but Firestore update failed: %@", error2);
                }
                if (completion) completion(error2);
            }];
        }
    }];
}

- (void)deleteUserAvatarWithCompletion:(FUCompletion)completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user."}];
        if (completion) completion(err);
        return;
    }
    // Delete avatar file from storage
    FIRStorageReference *avatarRef = [[[FIRStorage storage] reference] child:[NSString stringWithFormat:@"users/%@/avatar.jpg", authUser.uid]];
    [avatarRef deleteWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Avatar deletion failed: %@", error);
            if (completion) completion(error);
        } else {
            NSLog(@"[UserManager] Avatar deleted from storage.");
            // Remove photoURL from Auth profile
            FIRUserProfileChangeRequest *changeReq = [authUser profileChangeRequest];
            changeReq.photoURL = nil;
            [changeReq commitChangesWithCompletion:^(NSError * _Nullable error2) {
                if (error2) {
                    NSLog(@"[UserManager] Failed to clear Auth photoURL: %@", error2);
                }
                // Update Firestore fields to remove references
                [self updateUserDocumentForUID:authUser.uid
                                        fields:@{@"UserImageUrl": [NSNull null]}
                                    completion:^(NSError * _Nullable error3) {
                    if (error3) {
                        NSLog(@"[UserManager] Warning: failed to clear photoURL in Firestore: %@", error3);
                    }
                    if (completion) completion(error2 ?: error3);
                }];
            }];
        }
    }];
}

- (void)fetchUserAvatarURLForUID:(NSString *)userUID completion:(FUURLCompletion)completion {
    if (!userUID) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UserUID is required"}];
        if (completion) completion(nil, err);
        return;
    }
    // We assume avatar stored at users/<uid>/avatar.jpg
    FIRStorageReference *avatarRef = [[[FIRStorage storage] reference] child:[NSString stringWithFormat:@"users/%@/avatar.jpg", userUID]];
    [avatarRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
        } else {
            if (completion) completion(URL, nil);
        }
    }];
}

#pragma mark - Firestore User Document Management

- (void)createUserDocumentForUID:(NSString *)userUID initialData:(NSDictionary *)data completion:(FUCompletion)completion {
    if (!userUID) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UID is required"}];
        if (completion) completion(err);
        return;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:userUID];
    NSMutableDictionary *safeData = [NSMutableDictionary dictionaryWithDictionary:data ?: @{}];
    safeData[@"ID"] = userUID;
    safeData[@"uid"] = safeData[@"uid"] ?: userUID;
    NSString *userName = [safeData[@"UserName"] isKindOfClass:NSString.class]
        ? [safeData[@"UserName"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (userName.length == 0) {
        safeData[@"UserName"] = @"User";
    }
    if (![safeData[@"role"] respondsToSelector:@selector(integerValue)]) {
        safeData[@"role"] = @(UserRoleUser);
    }
    if (![safeData[@"isAdmin"] isKindOfClass:NSNumber.class]) {
        safeData[@"isAdmin"] = @NO;
    }
    if (![safeData[@"isSuperAdmin"] isKindOfClass:NSNumber.class]) {
        safeData[@"isSuperAdmin"] = @NO;
    }
    if (![safeData[@"isAdminAll"] isKindOfClass:NSNumber.class]) {
        safeData[@"isAdminAll"] = @NO;
    }
    if (![safeData[@"isBlocked"] isKindOfClass:NSNumber.class]) {
        safeData[@"isBlocked"] = @NO;
    }
    if (![safeData[@"loginSource"] respondsToSelector:@selector(integerValue)]) {
        safeData[@"loginSource"] = @(UserLoginSourcePPUsers);
    }
    safeData[@"createdAt"] = safeData[@"createdAt"] ?: [NSDate date];
    safeData[@"updatedAt"] = [NSDate date];

    [docRef setData:safeData merge:YES completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to create user document: %@", error);
        } else {
            NSLog(@"[UserManager] User document created for UID: %@", userUID);
        }
        if (completion) completion(error);
    }];
}

- (void)updateUserDocumentForUID:(NSString * _Nullable)userUID fields:(NSDictionary<NSString *,id> * _Nullable)fields completion:(FUCompletion _Nullable)completion {
    if (!userUID || !fields) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UID and fields are required"}];
        if (completion) completion(err);
        return;
    }
    NSMutableDictionary *safeFields = [NSMutableDictionary dictionary];
    [fields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
        if (![key isKindOfClass:NSString.class] || key.length == 0) return;
        if (!value) return;
        if ([value isKindOfClass:NSString.class]) {
            NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            safeFields[key] = trimmed;
            return;
        }
        safeFields[key] = value;
    }];

    NSArray<NSString *> *blockedFields = @[
        @"createdAt",
        @"uid",
        @"ID",
        @"Addresses",
        @"AddressTitles",
        @"permissions",
        @"claims",
        @"isAdmin",
        @"isSuperAdmin",
        @"isAdminAll",
        @"isBlocked",
        @"role"
    ];
    for (NSString *blocked in blockedFields) {
        [safeFields removeObjectForKey:blocked];
    }

    NSString *normalizedEmail = [safeFields[@"UserEmail"] isKindOfClass:NSString.class]
        ? [safeFields[@"UserEmail"] lowercaseString]
        : nil;
    if (normalizedEmail.length > 0) {
        safeFields[@"UserEmail"] = normalizedEmail;
    }

    if ([safeFields[@"MobileNo"] isKindOfClass:NSString.class]) {
        NSString *mobile = PPUserManagerCanonicalE164Candidate(safeFields[@"MobileNo"]);
        NSString *dial = [safeFields[@"CountryDialCode"] isKindOfClass:NSString.class]
            ? PPUserManagerCanonicalDialCode(safeFields[@"CountryDialCode"])
            : @"";
        if (dial.length > 0) {
            safeFields[@"CountryDialCode"] = dial;
        }
        if (mobile.length == 0) {
            [safeFields removeObjectForKey:@"MobileNo"];
        } else {
            if (![mobile hasPrefix:@"+"]) {
                NSString *dialDigits = [dial stringByReplacingOccurrencesOfString:@"+" withString:@""];
                if (dialDigits.length > 0) {
                    mobile = [NSString stringWithFormat:@"+%@%@", dialDigits, mobile];
                } else {
                    mobile = [NSString stringWithFormat:@"+%@", mobile];
                }
            }
            safeFields[@"MobileNo"] = mobile;
        }
    }
    if ([safeFields[@"CountryIsoCode"] isKindOfClass:NSString.class]) {
        NSString *iso = [safeFields[@"CountryIsoCode"] uppercaseString];
        if (iso.length == 0) {
            [safeFields removeObjectForKey:@"CountryIsoCode"];
        } else {
            safeFields[@"CountryIsoCode"] = iso;
        }
    }
    if ([safeFields[@"CountryDialCode"] isKindOfClass:NSString.class]) {
        NSString *dial = [safeFields[@"CountryDialCode"] stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (dial.length > 0 && ![dial hasPrefix:@"+"]) {
            dial = [@"+" stringByAppendingString:dial];
        }
        if (dial.length == 0) {
            [safeFields removeObjectForKey:@"CountryDialCode"];
        } else {
            safeFields[@"CountryDialCode"] = dial;
        }
    }

    if ([safeFields[@"UserName"] isKindOfClass:NSString.class]) {
        NSString *userName = safeFields[@"UserName"];
        if (userName.length == 0) {
            [safeFields removeObjectForKey:@"UserName"];
        }
    }

    id countryValue = safeFields[@"CountryID"];
    if (countryValue && ![countryValue respondsToSelector:@selector(integerValue)]) {
        [safeFields removeObjectForKey:@"CountryID"];
    }

    safeFields[@"ID"] = userUID;
    safeFields[@"updatedAt"] = [NSDate date];

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:userUID];
    FIRUser *authUser = [FIRAuth auth].currentUser;
    BOOL canAttemptRepair = (authUser.uid.length > 0 && [authUser.uid isEqualToString:userUID]);

    __weak typeof(self) weakSelf = self;
    __block BOOL didAttemptRepair = NO;
    __block void (^performWrite)(void) = nil;
    performWrite = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [docRef setData:safeFields merge:YES completion:^(NSError * _Nullable error) {
            if (error &&
                !didAttemptRepair &&
                canAttemptRepair &&
                [strongSelf pp_shouldRepairUserDocumentForTokenSyncError:error]) {
                didAttemptRepair = YES;
                [strongSelf pp_loadOrRepairCurrentUserForAuthUser:authUser completion:^(NSError * _Nullable repairError) {
                    if (repairError) {
                        NSLog(@"[UserManager] Failed to repair user document for UID %@ before retry: %@",
                              userUID, repairError.localizedDescription ?: @"unknown");
                        if (completion) completion(repairError);
                        return;
                    }
                    performWrite();
                }];
                return;
            }

            if (error) {
                NSLog(@"[UserManager] Failed to update document for UID %@: %@", userUID, error);
            } else {
                NSLog(@"[UserManager] User document updated for UID %@ with fields: %@", userUID, safeFields);
            }
            if (completion) completion(error);
        }];
    };

    performWrite();
}

- (void)fetchUserDocumentForUID:(NSString *)userUID completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    if (!userUID) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UID is required"}];
        completion(nil, err);
        return;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:userUID];
    [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else if (!snapshot.exists) {
            NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeUserNotFound userInfo:@{NSLocalizedDescriptionKey: @"User document not found"}];
            completion(nil, err);
        } else {
            completion(snapshot.data, nil);
        }
    }];
}

- (void)deleteUserDocumentForUID:(NSString *)userUID completion:(FUCompletion)completion {
    if (!userUID) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UID is required"}];
        if (completion) completion(err);
        return;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    [[[db collectionWithPath:@"UsersCol"] documentWithPath:userUID] deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to delete user document %@: %@", userUID, error);
        } else {
            NSLog(@"[UserManager] User document deleted for UID %@", userUID);
        }
        if (completion) completion(error);
    }];
}

#pragma mark - User Listing & Querying

- (id<FIRListenerRegistration>)observeAllUsersWithQuery:(FIRQuery *)query completion:(FUUsersListCompletion)completion {
    id<FIRListenerRegistration> listener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] observeAllUsers query error: %@", error);
            if (completion) completion(nil, error);
        } else {
            NSMutableArray<UserModel *> *users = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                UserModel *user = [[UserModel alloc] initWithSnapshot:doc];
                [users addObject:user];
                // Update internal caches
                [UserManager cacheUserModelInMemory:user];
            }
            if (completion) completion(users, nil);
        }
    }];
    return listener;
}

- (void)fetchUsersWithQuery:(FIRQuery *)query completion:(FUUsersListCompletion)completion {
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else {
            NSMutableArray<UserModel *> *users = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                UserModel *user = [[UserModel alloc] initWithSnapshot:doc];
                [users addObject:user];
                [UserManager cacheUserModelInMemory:user];
            }
            completion(users, nil);
        }
    }];
}

- (void)searchUsersWithField:(NSString *)fieldName value:(id)value completion:(FUUsersListCompletion)completion {
    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query = [[db collectionWithPath:@"UsersCol"] queryWhereField:fieldName isEqualTo:value];
    [self fetchUsersWithQuery:query completion:completion];
}

#pragma mark - Permissions & Roles

- (void)updatePermission:(UserPermission)flag
                 enabled:(BOOL)enabled
              forUserIDs:(NSArray<NSString *> *)userIDs
              completion:(void(^)(NSError * _Nullable error))completion
{
    NSString *name = PPPermNameFor(flag);
    if (!name || userIDs.count == 0) { if (completion) completion(nil); return; }

    FIRWriteBatch *batch = [[FIRFirestore firestore] batch];

    for (NSString *uid in userIDs) {
        if (uid.length == 0) continue;
        FIRDocumentReference *doc =
            [[[[[FIRFirestore firestore] collectionWithPath:@"UsersCol"]
                documentWithPath:uid]
               collectionWithPath:@"permissions"]
              documentWithPath:name];
        [batch setData:@{@"allowed": @(enabled)} forDocument:doc];
    }

    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[Perms] Batch commit failed: %@", error.localizedDescription);
        }
        if (completion) completion(error);
    }];
}

- (BOOL)currentUserCan:(UserPermission)flag {
    UserModel *u = self.currentUser;
    if (!u) return NO;

    NSString *name = PPPermNameFor(flag);
    if (!name) return NO;

    return [u hasPermissionNamed:name];
}

- (void)startListeningCurrentUserPermissionsWithChange:(void (^_Nullable)(NSDictionary<NSString *,NSNumber *> * _Nullable))onChange {
    if (!self.currentUser) return;
    NSString *uid = [self pp_currentUserDocumentUID];
    if (uid.length == 0) return;

    [self.currentUser stopListeningPermissions];

    __weak typeof(self) weakSelf = self;
    [self.currentUser startListeningPermissionsWithChange:^(NSDictionary<NSString *,NSNumber *> * _Nonnull perms) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.currentUser) return;

        if ([perms isKindOfClass:NSDictionary.class]) {
            self.currentUser.permissions = [perms mutableCopy];
            [self cacheUser:self.currentUser];

            NSString *syncUID =  self.currentUser.ID;
            [[NSNotificationCenter defaultCenter]
                postNotificationName:PPUserManagerDidSyncCurrentUserNotification
                              object:self
                            userInfo:@{ @"ID": syncUID ?: @"" }];
        }

        if (onChange) {
            onChange(perms);
        }
    }];
    NSLog(@"[UserManager] Started listening to current user permissions (merged canonical + legacy).");
}

- (void)stopListeningCurrentUserPermissions {
    if (self.currentUser) {
        [self.currentUser stopListeningPermissions];
        NSLog(@"[UserManager] Stopped listening to current user permissions.");
    }
}

- (BOOL)isCurrentUserBlocked {
    return self.currentUser.isBlocked;
}

- (void)startListeningCurrentUserBlockedState {
    [self stopListeningCurrentUserBlockedState];

    NSString *uid = PPSafeString(self.currentUser.ID);
    if (uid.length == 0) {
        uid = PPSafeString([FIRAuth auth].currentUser.uid);
    }
    if (uid.length == 0) {
        return;
    }

    FIRDocumentReference *docRef = [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:uid];
    __weak typeof(self) weakSelf = self;
    self.blockedStateListener = [docRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                              NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[UserManager] Block-state listener error: %@", error.localizedDescription);
            return;
        }
        if (!snapshot.exists) {
            return;
        }

        BOOL isBlocked = [snapshot.data[@"isBlocked"] boolValue];
        BOOL didChange = (strongSelf.currentUser.isBlocked != isBlocked);
        strongSelf.currentUser.isBlocked = isBlocked;

        if (didChange && strongSelf.currentUser.ID.length > 0) {
            [strongSelf.currentUser saveToDisk];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PPUserManagerDidUpdateBlockedStateNotification
                                                                object:strongSelf
                                                              userInfo:@{
                PPUserManagerBlockedStateUserInfoKey: @(isBlocked),
                @"uid": uid ?: @""
            }];

        });
    }];
}

- (void)stopListeningCurrentUserBlockedState {
    if (self.blockedStateListener) {
        [self.blockedStateListener remove];
        self.blockedStateListener = nil;
    }
}

#pragma mark - Security & Reauthentication

- (void)reauthenticateWithPhoneNumber:(NSString *)phoneNumber completion:(FUCompletion)completion {
    if (!phoneNumber) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"Phone number required for reauthentication."}];
        if (completion) completion(err);
        return;
    }
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidCredentials userInfo:@{NSLocalizedDescriptionKey: @"No current user to reauthenticate."}];
        if (completion) completion(err);
        return;
    }
    NSLog(@"[UserManager] Reauthenticating current user via phone number %@", phoneNumber);
    [[FIRPhoneAuthProvider provider] verifyPhoneNumber:phoneNumber UIDelegate:nil completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Failed to send reauth SMS: %@", error);
            if (completion) completion(error);
        } else {
            [UserManager showPromptOnTopController];
            // After user enters code, developer should create credential and call reauthenticate:
            // FIRAuthCredential *cred = [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID verificationCode:code];
            // [authUser reauthenticateWithCredential:cred completion: ...];
            NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeOperationNotAllowed userInfo:@{NSLocalizedDescriptionKey: @"Reauthentication flow requires user input."}];
            if (completion) completion(err);
        }
    }];
}

#pragma mark - Batch Operations

- (void)batchUpdateUsers:(NSArray<NSString *> *)userUIDs fields:(NSDictionary<NSString *,id> *)fields completion:(void (^)(NSArray<NSError *> *))completion {
    if (!userUIDs || userUIDs.count == 0 || !fields) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UserUIDs and fields are required"}];
        if (completion) completion(@[err]);
        return;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    FIRWriteBatch *batch = [db batch];
    for (NSString *uid in userUIDs) {
        FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
        [batch updateData:fields forDocument:docRef];
    }
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Batch update failed: %@", error);
            if (completion) completion(@[error]);
        } else {
            NSLog(@"[UserManager] Batch update succeeded for %lu users.", (unsigned long)userUIDs.count);
            if (completion) completion(@[]);
        }
    }];
}

- (void)batchDeleteUsers:(NSArray<NSString *> *)userUIDs completion:(void (^)(NSArray<NSError *> *))completion {
    if (!userUIDs || userUIDs.count == 0) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UserUIDs array is empty"}];
        if (completion) completion(@[err]);
        return;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    FIRWriteBatch *batch = [db batch];
    for (NSString *uid in userUIDs) {
        FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];
        [batch deleteDocument:docRef];
    }
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] Batch delete failed: %@", error);
            if (completion) completion(@[error]);
        } else {
            NSLog(@"[UserManager] Batch delete succeeded for %lu users.", (unsigned long)userUIDs.count);
            if (completion) completion(@[]);
        }
    }];
}

#pragma mark - Analytics & Monitoring

- (void)logUserActivity:(NSString *)activity parameters:(NSDictionary *)parameters {
    NSLog(@"[Analytics] Log activity: %@, params: %@", activity, parameters);
    if ([FIRAnalytics class]) {
        [FIRAnalytics logEventWithName:activity parameters:parameters];
    }
}

- (void)trackUserEngagementMetric:(NSString *)metric value:(NSNumber *)value {
    NSLog(@"[Analytics] Track metric: %@ = %@", metric, value);
    if ([FIRAnalytics class]) {
        [FIRAnalytics logEventWithName:@"user_engagement_metric"
                            parameters:@{@"metric": metric, @"value": value ?: @0}];
    }
}

#pragma mark - User Session Caching

- (void)cacheUser:(UserModel *)user {
    if (!user || !user.ID) return;
    // Save using UserModel's secure coding (to disk)
    if(self.currentUser != user)
    {
        self.currentUser = user;
        PPCurrentUser = user;
    }
   
    [user saveToDisk];
    // Store last logged in UID in user defaults for quick reference
    [[NSUserDefaults standardUserDefaults] setObject:user.ID forKey:@"lastLoggedInUID"];
    [[NSUserDefaults standardUserDefaults] setObject:user.ID forKey:@"lastAuthenticatedUID"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadCachedUser {
    NSString *uid = [[NSUserDefaults standardUserDefaults] stringForKey:@"lastLoggedInUID"];
    if (uid.length == 0) {
        return;
    }
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser)
    {
        if (authUser.uid && [authUser.uid isEqualToString:uid]) {
            UserModel *cached = [UserModel loadSavedUserWithUID:uid];
            if (cached) {
                _currentUser = cached;
                NSLog(@"[UserManager] Loaded cached user %@ (%@) from disk.", cached.UserName ?: cached.UserEmail, uid);
            }
        }
    }
    
}

- (void)clearUserDefaults {
    NSString *uid = [[NSUserDefaults standardUserDefaults] stringForKey:@"lastLoggedInUID"];
    if (uid) {
        [UserModel clearCachedUserWithUID:uid];
    }
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *keysToRemove = @[
        @"lastLoggedInUID",
        @"lastAuthenticatedUID",
        @"userID",
        @"uid",
        @"UserName",
        @"FirstName",
        @"LastName",
        @"MobileNo",
        @"UserEmail",
        @"UserImageName",
        @"UserAbout",
        @"CountryID",
        @"PPUserTokenID",
        @"SubID",
        @"loginDate",
        @"UserImageUrl"
    ];
    for (NSString *key in keysToRemove) {
        [defs removeObjectForKey:key];
    }
    [defs synchronize];
    NSLog(@"[UserManager] Cleared cached user data.");
}

- (void)logoutAndClearAll {
    [self pp_stopTokenRefreshTimer];
    [self stopListeningCurrentUserPermissions];
    [self stopListeningCurrentUserBlockedState];
    [self clearUserDefaults];
    self.currentToken = nil;
    [[AppDataListenerManager shared] stopAllListeners];
    [[ChManager sharedManager] stopListening];
    [[ChManager sharedManager] stopAllThreadMessageListeners];
    [CartManager.sharedManager clearCart];
    _currentUser = nil;
    PPCurrentUser = nil;
    NSLog(@"[UserManager] Logged out and cleared all user data.");
}

#pragma mark - User ID <-> UID Mapping

// In-memory cache dictionaries
static NSMutableDictionary<NSString*, UserModel*> *userCacheByID;
static NSMutableDictionary<NSString*, UserModel*> *userCacheByUID;

+ (void)initialize {
    if (self == [UserManager self]) {
        userCacheByID = [NSMutableDictionary dictionary];
        userCacheByUID = [NSMutableDictionary dictionary];
    }
}

// Internal: store user in static cache
+ (void)cacheUserModelInMemory:(UserModel *)user {
    if (!user) return;
    if (user.ID) {
        userCacheByID[user.ID] = user;
    }
    if (user.ID) {
        userCacheByUID[user.ID] = user;
    }
}

// Async fetch mapping
+ (void)getUidByUserID:(NSString *)userID completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    if (!userID) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeInvalidParameter userInfo:@{NSLocalizedDescriptionKey: @"UserID is required"}];
        completion(nil, err);
        return;
    }
    // Check cache first
    UserModel *cachedUser = userCacheByID[userID];
    if (cachedUser) {
        completion(cachedUser.ID, nil);
        return;
    }
    // Not in cache, query Firestore
    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query = [[db collectionWithPath:@"UsersCol"] queryWhereField:@"ID" isEqualTo:userID];
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else if (snapshot.documents.count == 0) {
            NSError *err = [NSError errorWithDomain:FUErrorDomain code:FUErrorCodeUserNotFound userInfo:@{NSLocalizedDescriptionKey: @"No user with given ID"}];
            completion(nil, err);
        } else {
            FIRDocumentSnapshot *doc = snapshot.documents.firstObject;
            NSString *uid = doc.documentID;
            // Optionally cache
            UserModel *user = [[UserModel alloc] initWithSnapshot:doc];
            if (user) {
                [UserManager cacheUserModelInMemory:user];
            }
            completion(uid, nil);
        }
    }];
}

+ (NSString *_Nullable)uidForID:(NSString *)userID {
    if (!userID) return nil;
    UserModel *user = userCacheByID[userID];
    return user ? user.ID : nil;
}

+ (UserModel *_Nullable)userModelForID:(NSString *)userID {
    if (!userID) return nil;
    return userCacheByID[userID];
}

+ (NSString *_Nullable)iDForUid:(NSString *)uid {
    if (!uid) return nil;
    UserModel *user = userCacheByUID[uid];
    return user ? user.ID : nil;
}


+ (BOOL)isLoginOnStack:(UINavigationController *)nav {
    for (UIViewController *vc in nav.viewControllers) {
        if ([vc isKindOfClass:PPUserSigningController.class]) return YES;
    }
    return NO;
}

+ (BOOL)isShowingLoginFrom:(UIViewController *)vc {
    if ([vc isKindOfClass:PPUserSigningController.class]) return YES;
    if ([vc isKindOfClass:UINavigationController.class]) {
        return [self isLoginOnStack:(UINavigationController *)vc];
    }
    if (vc.navigationController && [self isLoginOnStack:vc.navigationController]) return YES;
    if (vc.presentedViewController) return [self isShowingLoginFrom:vc.presentedViewController];
    return NO;
}



+ (UIViewController *)topViewController {
    UIWindow *win = [self activeWindow];
    return [self topViewControllerFrom:win.rootViewController];
}
+ (UIWindow *)activeWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:UIWindowScene.class]) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    // Fallback (pre-iOS 13 or no key flag)
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

+ (UIViewController *)topViewControllerFrom:(UIViewController *)vc {
    if ([vc isKindOfClass:UINavigationController.class]) {
        return [self topViewControllerFrom:((UINavigationController *)vc).visibleViewController];
    } else if ([vc isKindOfClass:UITabBarController.class]) {
        return [self topViewControllerFrom:((UITabBarController *)vc).selectedViewController];
    } else if (vc.presentedViewController) {
        return [self topViewControllerFrom:vc.presentedViewController];
    } else {
        return vc;
    }
}

+ (void)showPromptOnTopController {
    UIViewController *topVC = [self topViewController];
    if (!topVC) return;

    // Avoid showing login if it’s already visible anywhere
    if ([self isShowingLoginFrom:topVC]) {
        return;
    }
   
    [PPAlertHelper showConfirmationIn:topVC title:kLang(@"Not Registered") subtitle:kLang(@"You need to register to continue.")  confirmButton:kLang(@"Register") cancelButton:kLang(@"cancel") icon:[UIImage systemImageNamed:@"person.crop.circle.badge.questionmark"] confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        
        
        if(!didConfirm) return;
        [PPUserSigningManager presentSignInFrom:topVC
                                withCountryCode:CitiesManager.shared.CurrentCountry.countryCode
                              presentationStyle:PPSignInPresentationStyleSheet
                           autoDismissOnSuccess:YES
                                         success:^(UserModel *user) {
            
            [PPFunc reloadAppUI];
            [[AppDataListenerManager shared] stopAllListeners];
            [[AppDataListenerManager shared] startListenersForUser:PPCurrentUser.ID];
            // Custom handling
        } failure:^(NSError *error) {
            // Error handling
        } cancelled:^{
            // Cancellation handling
        }];
    } cancelBlock:^{
        
    }];

   

   
}
    /*// Example implementation: show an alert to prompt for input (like verification code).
    // In a real scenario, you would capture user input via UITextField on alert.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Input Required"
                                                                   message:@"Please enter the verification code sent to your phone."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:nil];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Submit" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *code = alert.textFields.firstObject.text;
        // Ideally, handle code by calling relevant method to complete verification.
        NSLog(@"[UserManager] User entered code: %@", code);
        // NOTE: In practice, you'd call link or reauth with this code here.
    }];
    [alert addAction:ok];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        [topVC presentViewController:alert animated:YES completion:nil];
    }); */




#pragma mark - Get User by ID

// Fetch user once by UID
- (void)getUserWithUID:(NSString *)uid
            completion:(void (^)(UserModel * _Nullable user, NSError * _Nullable error))completion {

    // Guard: invalid UID
    if (uid.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"UserManager"
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid UID"}]);
        }
        return;
    }

    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length > 0 && ![uid isEqualToString:currentUID]) {
        [self getOtherUserModelFromFirestoreWithUID:uid completion:completion];
        return;
    }

    [[[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:uid]
     getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        if (snapshot.exists) {
            UserModel *model = [[UserModel alloc] initWithSnapshot:snapshot];
            self.currentUser = model;
            [self cacheUser:model];
            completion(model, nil);
        } else {
            completion(nil, [NSError errorWithDomain:@"UserManager" code:404 userInfo:@{NSLocalizedDescriptionKey: @"User not found"}]);
        }
    }];
}



// Fetch user once by UID
- (void)getOtherUserModelFromFirestoreWithUID:(NSString *)uid completion:(void (^)(UserModel * _Nullable user, NSError * _Nullable error))completion {

    // Guard: invalid UID
    if (uid.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"UserManager"
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid UID"}]);
        }
        return;
    }

    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length > 0 && [uid isEqualToString:currentUID]) {
        [self getUserWithUID:uid completion:completion];
        return;
    }

    [[[[FIRFirestore firestore] collectionWithPath:@"PublicUserProfiles"] documentWithPath:uid]
     getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        if (snapshot.exists) {
            UserModel *model = [[UserModel alloc] initWithSnapshot:snapshot];
            completion(model, nil);
        } else {
            completion(nil, [NSError errorWithDomain:@"UserManager" code:404 userInfo:@{NSLocalizedDescriptionKey: @"User not found"}]);
        }
    }];
}

- (BOOL)isUserLoggedIn {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        return NO;
    }
    if (self.currentUser.ID.length > 0 &&
        ![self.currentUser.ID isEqualToString:authUser.uid]) {
        return NO;
    }
    return YES;
}


// UserManager.m

- (void)updateUser:(UserModel *)user
        completion:(void (^)(BOOL success, NSError * _Nullable updateError))completion
{
    if (!user || user.ID.length == 0) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain
                                           code:FUErrorCodeInvalidParameter
                                       userInfo:@{NSLocalizedDescriptionKey:@"User/UID is required"}];
        if (completion) completion(NO, err);
        return;
    }

    NSLog(@"[UserManager] updateUser started for UID=%@", user.ID);

    // --- Build Firestore payload (start from model) ---
    NSMutableDictionary *dict = [[user toDictionary] mutableCopy];
    if (!dict) dict = [NSMutableDictionary dictionary];

    // Enforce PPUserTokenID and loginSource per your constraints
    NSString *deviceToken = user.PPUserTokenID.length ? user.PPUserTokenID
                         : [[NSUserDefaults standardUserDefaults] stringForKey:@"deviceToken"];
    if (deviceToken.length) {
        dict[@"PPUserTokenID"] = deviceToken;
    }
    dict[@"loginSource"] = @(UserLoginSourcePPUsers);
    dict[@"updatedAt"]   = [NSDate date];

    // Prefer canonical keys you use in your app
    // If you keep both UserImageUrl (NSURL) and photoURL (NSString), normalize safely:
    if (user.UserImageUrl) {
        NSURL *safeURL = PPSafeURL(user.UserImageUrl.absoluteString);
        if (safeURL) {
            dict[@"UserImageUrl"] = safeURL.absoluteString;
        }
    }

    dispatch_group_t group = dispatch_group_create();
    __block NSError *aggError = nil;

    dispatch_group_enter(group);
    [self updateUserDocumentForUID:user.ID fields:dict completion:^(NSError * _Nullable error) {
        if (error) {
            aggError = error;
            NSLog(@"[UserManager] ❌ Firestore update failed for UID %@: %@", user.ID, error);
        } else {
            NSLog(@"[UserManager] ✅ Firestore updated for UID %@ (fields: %lu)", user.ID, (unsigned long)dict.count);
        }
        dispatch_group_leave(group);
    }];

    // ---- Firebase Auth sync (only if this is the current auth user) ----
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser && [authUser.uid isEqualToString:user.ID]) {
        // displayName/photoURL via profile change request
        FIRUserProfileChangeRequest *changeReq = [authUser profileChangeRequest];
        BOOL shouldCommit = NO;

        // displayName
        NSString *targetName = user.UserName;
        if (targetName.length && ![targetName isEqualToString:authUser.displayName]) {
            changeReq.displayName = targetName;
            shouldCommit = YES;
        }

        // photoURL
        NSString *photoStr = dict[@"UserImageUrl"];
        NSURL *photo = photoStr.length ? [NSURL URLWithString:photoStr] : nil;
        if (photo && ![photo isEqual:authUser.photoURL]) {
            changeReq.photoURL = photo;
            shouldCommit = YES;
        }

        if (shouldCommit) {
            dispatch_group_enter(group);
            [changeReq commitChangesWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    aggError = error;
                    NSLog(@"[UserManager] ❌ Auth profile update failed: %@", error);
                } else {
                    NSLog(@"[UserManager] ✅ Auth profile updated (displayName/photoURL)");
                }
                dispatch_group_leave(group);
            }];
        }

        // Email (use the existing safe helper to respect reauth requirements)
        if (user.UserEmail.length && ![user.UserEmail isEqualToString:authUser.email]) {
            dispatch_group_enter(group);
            [self updateCurrentUserEmail:user.UserEmail completion:^(NSError * _Nullable error) {
                if (error) {
                    aggError = error;
                    NSLog(@"[UserManager] ❌ Email update failed: %@", error);
                } else {
                    NSLog(@"[UserManager] ✅ Email updated in Auth + Firestore");
                }
                dispatch_group_leave(group);
            }];
        }

        // Phone number: leave to your phone update flow (needs SMS code).
        // if (user.MobileNo.length && ![user.MobileNo isEqualToString:authUser.phoneNumber]) { ... }
    } else {
        NSLog(@"[UserManager] (Auth sync skipped: updating a different user than current auth)");
    }

    // ---- Finish: refresh cache if it's the current user ----
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (aggError) {
            if (completion) completion(NO, aggError);
            return;
        }

        // Refresh the current user model if we just updated them
        if (authUser && [authUser.uid isEqualToString:user.ID]) {
            [UserModel loadCurrentUserModelWithCompletion:^(UserModel * _Nullable u, NSError * _Nullable err) {
                if (u) {
                    self.currentUser = u;
                    [self cacheUser:u];
                    NSLog(@"[UserManager] 🔄 currentUser cache refreshed.");
                }
                if (completion) completion(err == nil, err);
            }];
        } else {
            if (completion) completion(YES, nil);
        }
    });
}


// UserManager.m

- (void)uploadUserImage:(UIImage *)image
          userImageName:(NSString *)imageName
             completion:(void (^)(NSError * _Nullable error, NSString * _Nullable imageURL))completion
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain
                                           code:FUErrorCodeInvalidCredentials
                                       userInfo:@{NSLocalizedDescriptionKey:@"No logged-in user for image upload."}];
        if (completion) completion(err, nil);
        return;
    }
    if (!image || imageName.length == 0) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain
                                           code:FUErrorCodeInvalidParameter
                                       userInfo:@{NSLocalizedDescriptionKey:@"Image and imageName are required."}];
        if (completion) completion(err, nil);
        return;
    }

    NSLog(@"[UserManager] 🚀 Uploading image %@ for UID=%@", imageName, authUser.uid);

    // JPEG encode (90% quality)
    NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
    if (!imageData) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain
                                           code:FUErrorCodeInvalidParameter
                                       userInfo:@{NSLocalizedDescriptionKey:@"Failed to encode UIImage to JPEG."}];
        if (completion) completion(err, nil);
        return;
    }

    // Storage path: users/{uid}/{imageName}
    FIRStorageReference *root = [[FIRStorage storage] reference];
    NSString *path = [NSString stringWithFormat:@"users/%@/%@", authUser.uid, imageName];
    FIRStorageReference *ref = [root child:path];

    [ref putData:imageData metadata:nil
                                   completion:^(FIRStorageMetadata *metadata, NSError *error) {
        if (error) {
            NSLog(@"[UserManager] ❌ Upload failed: %@", error);
            if (completion) completion(error, nil);
        } else {
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable urlErr) {
                if (urlErr) {
                    NSLog(@"[UserManager] ❌ Failed to get download URL: %@", urlErr);
                    if (completion) completion(urlErr, nil);
                } else {
                    NSString *urlString = URL.absoluteString;
                    NSLog(@"[UserManager] ✅ Uploaded image %@ → %@", imageName, urlString);

                    // update Firestore user doc with new image URL
                    [self updateUserDocumentForUID:authUser.uid
                                             fields:@{@"UserImageUrl": urlString,
                                                      @"UserImageName": imageName}
                                         completion:^(NSError * _Nullable fsErr) {
                        if (fsErr) {
                            NSLog(@"[UserManager] ⚠️ Firestore update failed for new image: %@", fsErr);
                        }
                    }];

                    if (completion) completion(nil, urlString);
                }
            }];
        }
    }];

    // Optional: you can attach observers to `task` for progress if needed.
}



- (void)addUser:(UserModel *)user
     completion:(void (^)(NSError * _Nullable error, NSString * _Nullable userID))completion
{
    // Validate
    NSString *uid = user.ID.length ? user.ID : [FIRAuth auth].currentUser.uid;
    if (uid.length == 0) {
        NSError *err = [NSError errorWithDomain:FUErrorDomain
                                           code:FUErrorCodeInvalidCredentials
                                       userInfo:@{NSLocalizedDescriptionKey:@"No UID available for addUser."}];
        if (completion) completion(err, nil);
        return;
    }

    NSLog(@"[UserManager] ➕ addUser for UID=%@", uid);

    // Start from model dictionary
    NSMutableDictionary *doc = [[user toDictionary] mutableCopy];
    if (!doc) doc = [NSMutableDictionary dictionary];

    // Enforce required fields
    // PPUserTokenID (device token)
    NSString *token = user.PPUserTokenID.length ? user.PPUserTokenID
                     : [[NSUserDefaults standardUserDefaults] stringForKey:@"deviceToken"];
    if (token.length) { doc[@"PPUserTokenID"] = token; }

    // Always mark login source as PPUsers
    doc[@"loginSource"] = @(UserLoginSourcePPUsers);

    // Normalize photo URL if present
    NSString *photoStr = nil;
    if (user.UserImageUrl.absoluteString.length) {
        NSURL *u = PPSafeURL(user.UserImageUrl.absoluteString);
        if (u) { photoStr = u.absoluteString; }
    }
    if (photoStr.length) {
        doc[@"UserImageUrl"] = photoStr;
    }

    // Timestamps
    doc[@"loginDate"] = doc[@"loginDate"] ?: [NSDate date];
    doc[@"updatedAt"] = [NSDate date];

    // Identity mirrors (friendly names your app uses)
    if (user.UserEmail.length) doc[@"UserEmail"] = user.UserEmail;
    if (user.UserName.length)  { doc[@"UserName"] = user.UserName; }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *ref = [[db collectionWithPath:@"UsersCol"] documentWithPath:uid];

    // Create (no-merge) if new; if you prefer idempotent, switch to merge:YES
    [ref setData:doc merge:NO completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] ❌ addUser Firestore failed: %@", error);
            if (completion) completion(error, nil);
            return;
        }
        NSLog(@"[UserManager] ✅ addUser Firestore created for UID=%@", uid);

        // If this is the signed-in user, refresh currentUser cache
        FIRUser *authUser = [FIRAuth auth].currentUser;
        if (authUser && [authUser.uid isEqualToString:uid]) {
            [UserModel loadCurrentUserModelWithCompletion:^(UserModel * _Nullable u, NSError * _Nullable err) {
                if (u) {
                    self.currentUser = u;
                    [self cacheUser:u];
                    NSLog(@"[UserManager] 🔄 currentUser cached after addUser.");
                }
                if (completion) completion(nil, uid);
            }];
        } else {
            if (completion) completion(nil, uid);
        }
    }];
}

- (void)updateCurrentUserWithPPUserTokenID:(NSString *)PPUserTokenID {
    NSString *trim = [PPUserTokenID isKindOfClass:[NSString class]]
        ? [PPUserTokenID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : nil;
    if (trim.length == 0) {
        NSLog(@"[UserManager] ⚠️ updateCurrentUserWithPPUserTokenID called with empty PPUserTokenID");
        return;
    }

    // Always cache locally so we can attach it at first sign-in as well.
    [[NSUserDefaults standardUserDefaults] setObject:trim forKey:@"PPUserTokenID"];
    [[NSUserDefaults standardUserDefaults] setObject:trim forKey:@"deviceToken"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSLog(@"[UserManager] ℹ️ No auth user yet — stored PPUserTokenID for later use");
        return;
    }

    // Update Firestore: UsersCol/<uid>
    NSDictionary *fields = @{
        @"PPUserTokenID"       : trim,
        @"PPAdminTokenID"      : trim,
        @"loginSource" : @(UserLoginSourcePPUsers),
        @"updatedAt"   : [NSDate date]
    };

    __weak typeof(self) weakSelf = self;
    [self updateUserDocumentForUID:authUser.uid fields:fields completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            NSLog(@"[UserManager] ❌ Failed to update PPUserTokenID in Firestore: %@", error);
            return;
        }

        NSLog(@"[UserManager] ✅ PPUserTokenID/PPAdminTokenID synced to Firestore for UID=%@", authUser.uid);

        if (strongSelf.currentUser) {
            strongSelf.currentUser.PPUserTokenID = trim;
            strongSelf.currentUser.PPAdminTokenID = trim;
            [strongSelf cacheUser:strongSelf.currentUser];
        }
    }];
}



- (NSString *)profileNameAndTitleWithMode:(ProfileGreetingShorteningMode)mode {
    // Defensive: reset currentUser if not logged in
    self.currentUser = PPIsUserLoggedIn ? PPCurrentUser : nil;
    NSLog(@"profileNameAndTitleWithMode → Logged in: %@", PPIsUserLoggedIn ? @"YES" : @"NO");
    
    if (!PPIsUserLoggedIn || !self.currentUser) {
        return kLang(@"JoinUs") ?: @"Join Us";
    }
    
    // Detect time of day safely
    NSDate *now = [NSDate date] ?: [NSDate dateWithTimeIntervalSince1970:0];
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:now];
    NSString *greeting = @"";
    if (hour < 12) {
        greeting = kLang(@"Good morning") ?: @"Good morning";
    } else if (hour < 18) {
        greeting = kLang(@"Good afternoon") ?: @"Good afternoon";
    } else {
        greeting = kLang(@"Good evening") ?: @"Good evening";
    }
    
    // Username safe fallback
    NSString *userName = [UserManager sharedManager].currentUser.UserName;
    if (![userName isKindOfClass:[NSString class]] || userName.length == 0) {
        userName = kLang(@"Guest") ?: @"Guest";
    }
    
    // ✂️ Shorten username if needed
    if (mode == ProfileGreetingShorteningModeShortName || mode == ProfileGreetingShorteningModeBoth) {
        if (userName.length > 0) {
            NSArray *components = [userName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            components = [components filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
            
            if (components.count > 1) {
                NSString *firstName = components.firstObject ?: @"";
                NSString *last = components.lastObject ?: @"";
                NSString *lastInitial = last.length > 0 ? [[last substringToIndex:1] uppercaseString] : @"";
                userName = [NSString stringWithFormat:@"%@ %@", firstName, lastInitial];
                userName = [NSString stringWithFormat:@"%@", firstName];
            } else if (userName.length > 12) {
                NSUInteger cutLength = MIN(10, userName.length);
                userName = [NSString stringWithFormat:@"%@…", [userName substringToIndex:cutLength]];
            }
        }
    }
    
    // ✂️ Shorten greeting if needed
    if (mode == ProfileGreetingShorteningModeShortGreet || mode == ProfileGreetingShorteningModeBoth) {
        if (Language.languageVal == 0) {
            // English
            if ([greeting rangeOfString:@"morning" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                greeting = kLang(@"Morning") ?: @"Morning";
            } else if ([greeting rangeOfString:@"afternoon" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                greeting = kLang(@"Afternoon") ?: @"Afternoon";
            } else if ([greeting rangeOfString:@"evening" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                greeting = kLang(@"Evening") ?: @"Evening";
            }
        } else {
            // Arabic fallback
            if ([greeting containsString:@"صباح"]) greeting = @"صباح";
            else if ([greeting containsString:@"مساء"]) greeting = @"مساء";
        }
    }
    
    // ✂️ Shorten username if needed
    if (mode == ProfileGreetingShorteningModeShotNameOnly) {
        if (userName.length > 0) {
            userName = [NSString stringWithFormat:@"%@",
                        [UserManager sharedManager].currentUser.PPBestDisplayName];
        }
    }
    
    
    // Localized safe return
    if (Language.languageVal == 0) {
        return [NSString stringWithFormat:@"%@, %@", greeting ?: @"", userName ?: @""];
    } else {
        return [NSString stringWithFormat:@"%@، %@", greeting ?: @"", userName ?: @""];
    }
}
/*

- (NSString *)profileNameAndTitleWithMode:(ProfileGreetingShorteningMode)mode {
    self.currentUser = PPIsUserLoggedIn ? PPCurrentUser : nil;
    NSLog(@"profileNameAndTitleWithMode → Logged in: %@", PPIsUserLoggedIn ? @"YES" : @"NO");
    
    if (!PPIsUserLoggedIn) {
        return kLang(@"JoinUs");
    }
    
    // Detect time of day
    NSDate *now = [NSDate date];
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:now];
    NSString *greeting;
    if (hour < 12) {
        greeting = kLang(@"Good morning");
    } else if (hour < 18) {
        greeting = kLang(@"Good afternoon");
    } else {
        greeting = kLang(@"Good evening");
    }
    
    NSString *userName = [UserManager sharedManager].currentUser.UserName ?: @"";
    
    // ✂️ Shorten username if needed
    if (mode == ProfileGreetingShorteningModeShortName || mode == ProfileGreetingShorteningModeBoth) {
        if (userName.length > 0) {
            NSArray *components = [userName componentsSeparatedByString:@" "];
            if (components.count > 1) {
                NSString *firstName = components.firstObject;
                NSString *lastInitial = [[components.lastObject substringToIndex:1] uppercaseString];
                userName = [NSString stringWithFormat:@"%@ %@", firstName, lastInitial]; // Mohammed A.
            } else if (userName.length > 12) {
                userName = [NSString stringWithFormat:@"%@…", [userName substringToIndex:10]];
            }
        }
    }
    
    // ✂️ Shorten greeting if needed
    if (mode == ProfileGreetingShorteningModeShortGreet || mode == ProfileGreetingShorteningModeBoth) {
        if (Language.languageVal == 0) {
            // English
            if ([greeting containsString:@"morning"]) greeting = kLang(@"Morning");
            else if ([greeting containsString:@"afternoon"]) greeting = kLang(@"Afternoon");
            else if ([greeting containsString:@"evening"]) greeting = kLang(@"Evening");
        } else {
            // Arabic equivalents → صباح/مساء
            if ([greeting containsString:@"صباح"]) greeting = @"صباح";
            else if ([greeting containsString:@"مساء"]) greeting = @"مساء";
        }
    }
    
    // Localized return
    if (Language.languageVal == 0) {
        return [NSString stringWithFormat:@"%@, %@", greeting, userName];
    } else {
        return [NSString stringWithFormat:@"%@، %@", greeting, userName];
    }
}
*/

@end

NS_ASSUME_NONNULL_END





















 /* ========================================================================= Auth Has LaunchedBefore ======================================================================================*/
static NSString * const kPPAuthHasLaunchedBeforeKey = @"PPAuthHasLaunchedBefore";

@implementation PPAuthManager

+ (instancetype)shared {
    static PPAuthManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPAuthManager alloc] init];
    });
    return manager;
}

#pragma mark - Fresh Install Detection

- (void)handleFreshInstall {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL hasLaunchedBefore = [defaults boolForKey:kPPAuthHasLaunchedBeforeKey];
    
    if (!hasLaunchedBefore) {
        NSLog(@"[PPAuthManager] Fresh install detected. Forcing sign-out.");
        
        NSError *error;
        [[FIRAuth auth] signOut:&error];
        if (error) {
            NSLog(@"[PPAuthManager] Error forcing sign-out on fresh install: %@", error.localizedDescription);
        }
        
        [defaults setBool:YES forKey:kPPAuthHasLaunchedBeforeKey];
        [defaults synchronize];
    } else {
        NSLog(@"[PPAuthManager] Not a fresh install. Skipping forced sign-out.");
    }
}

#pragma mark - Sign Out

- (void)signOutUserWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    [[UserManager sharedManager] signOutCurrentUserWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PPAuthManager] Error signing out: %@", error.localizedDescription);
            if (completion) completion(NO, error);
            return;
        }
        NSLog(@"[PPAuthManager] Firebase user signed out.");
        if (completion) completion(YES, nil);
    }];
}

#pragma mark - User Check

- (BOOL)isUserSignedIn {
    return ([FIRAuth auth].currentUser != nil);
}

@end
















/*
#import "UserManager.h"


// Map enum -> canonical doc ID
static inline NSString *PPPermNameFor(UserPermission flag) {
    switch (flag) {
        case UserPermissionPostAds:     return kPermPostAds;
        case UserPermissionSellNew:     return kPermSellNew;
        case UserPermissionSellUsed:    return kPermSellUsed;
        case UserPermissionAdoption:    return kPermAdoption;
        case UserPermissionManageStore: return kPermManageStore;
        case UserPermissionModeration:  return kPermModeration;
        case UserPermissionAdminAll:    return kPermAdminAll;
        default:                        return nil;
    }
}




@interface UserManager ()
// Firestore reference
@property (nonatomic, strong) FIRFirestore *firestore;

// Listener for observing user document changes
@property (nonatomic, strong) id<FIRListenerRegistration> listener;

// Currently logged-in user
@property (nonatomic, strong, readwrite, nullable) UserModel *currentUser;

// Flag to track if this is a new user
@property (nonatomic, assign, readwrite) BOOL isNewUser;
@end

@implementation UserManager



- (void)startListeningCurrentUserPermissionsWithChange:(void (^_Nullable)(NSDictionary<NSString *, NSNumber *> *perms))onChange {
    if (!self.currentUser) return;
    [self.currentUser startListeningPermissionsWithChange:onChange];
}

- (void)stopListeningCurrentUserPermissions {
    [self.currentUser stopListeningPermissions];
}

- (void)updatePermission:(UserPermission)flag
                 enabled:(BOOL)enabled
              forUserIDs:(NSArray<NSString *> *)userIDs
              completion:(void(^)(NSError * _Nullable error))completion
{
    NSString *name = PPPermNameFor(flag);
    if (!name || userIDs.count == 0) { if (completion) completion(nil); return; }

    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];
    FIRWriteBatch *batch = [db batch];

    for (NSString *uid in userIDs) {
        if (uid.length == 0) continue;
        FIRDocumentReference *doc =
            [[[[db collectionWithPath:@"UsersCol"]
                documentWithPath:uid]
               collectionWithPath:@"permissions"]
              documentWithPath:name];
        [batch setData:@{@"allowed": @(enabled)} forDocument:doc];
    }

    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[Perms] Batch commit failed: %@", error.localizedDescription);
        }
        if (completion) completion(error);
    }];
}


- (BOOL)currentUserCan:(UserPermission)flag {
    UserModel *u = self.currentUser;
    if (!u) return NO;
    if (u.isAdminAll) return YES;

    NSString *name = PPPermNameFor(flag);
    if (!name) return NO;

    // Prefer the live map if you already started listening/fetched; otherwise false until loaded.
    return [u hasPermissionNamed:name];
}



// Singleton instance
+ (instancetype)sharedManager {
    static UserManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[UserManager alloc] init];
        sharedInstance.firestore = [FIRFirestore firestore];
    });
    return sharedInstance;
}

#pragma mark - Save User



#pragma mark - Observe User Document

// Observe changes to a specific user's document in Firestore
- (void)observeUserWithUID:(NSString *)uid
                 onUpdate:(void (^)(UserModel * _Nullable user, NSError * _Nullable error))onUpdate {

    // Stop previous listener if any
    [self stopListening];

    FIRDocumentReference *docRef = [[self.firestore collectionWithPath:@"UsersCol"] documentWithPath:uid];
    self.listener = [docRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            onUpdate(nil, error);
            return;
        }
        if (snapshot.exists) {
            UserModel *model = [[UserModel alloc] initWithSnapshot:snapshot];
            self.currentUser = model;
            [self cacheUser:model];
            onUpdate(model, nil);
        } else {
            onUpdate(nil, [NSError errorWithDomain:@"UserManager" code:404 userInfo:@{NSLocalizedDescriptionKey: @"User not found"}]);
        }
    }];
}

#pragma mark - Get User by ID

// Fetch user once by UID
- (void)getUserWithUID:(NSString *)uid
            completion:(void (^)(UserModel * _Nullable user, NSError * _Nullable error))completion {

    // Guard: invalid UID
    if (uid.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"UserManager"
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid UID"}]);
        }
        return;
    }

    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length > 0 && ![uid isEqualToString:currentUID]) {
        [self getOtherUserModelFromFirestoreWithUID:uid completion:completion];
        return;
    }

    [[[self.firestore collectionWithPath:@"UsersCol"] documentWithPath:uid]
     getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        if (snapshot.exists) {
            UserModel *model = [[UserModel alloc] initWithSnapshot:snapshot];
            self.currentUser = model;
            [self cacheUser:model];
            completion(model, nil);
        } else {
            completion(nil, [NSError errorWithDomain:@"UserManager" code:404 userInfo:@{NSLocalizedDescriptionKey: @"User not found"}]);
        }
    }];
}

#pragma mark - Local Cache

// Cache user to NSUserDefaults
- (void)cacheUser:(UserModel *)user {
    if (!user || user.ID.length == 0) return;

    self.currentUser = user;
    [user saveToDisk];
    [self setUserDefaultsFromUserModel:user];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:user.ID forKey:@"lastLoggedInUID"];
    [defs setObject:user.ID forKey:@"lastAuthenticatedUID"];
    [defs synchronize];
}

// Load cached user from NSUserDefaults
- (void)loadCachedUser {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        self.currentUser = nil;
        return;
    }

    NSString *cachedUID = [defs stringForKey:@"lastLoggedInUID"];
    if (cachedUID.length > 0 && ![cachedUID isEqualToString:authUser.uid]) {
        self.currentUser = nil;
        return;
    }

    UserModel *model = [UserModel loadSavedUserWithUID:authUser.uid];
    if (!model) {
        model = [self getUserModelFromDefaults];
    }
    if (model.ID.length > 0 && ![model.ID isEqualToString:authUser.uid]) {
        self.currentUser = nil;
        return;
    }
    self.currentUser = model;
}

#pragma mark - Online Status

// Update online status in Firestore
- (void)updateOnlineStatus:(BOOL)isOnline {
    NSString *uid = [self pp_currentUserDocumentUID];
    if (uid.length == 0) return;

    FIRDocumentReference *doc = [[self.firestore collectionWithPath:@"UserPresence"] documentWithPath:uid];
    NSMutableDictionary *payload = [@{
        @"uid": uid,
        @"online": @(isOnline),
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } mutableCopy];
    if (!isOnline) {
        payload[@"lastSeen"] = [FIRFieldValue fieldValueForServerTimestamp];
    }
    [doc setData:payload merge:YES];

}

// Update last seen timestamp in Firestore
- (void)updateLastSeen {
    NSString *uid = [self pp_currentUserDocumentUID];
    if (uid.length == 0) return;

    FIRDocumentReference *doc = [[self.firestore collectionWithPath:@"UserPresence"] documentWithPath:uid];
    [doc setData:@{
        @"uid": uid,
        @"online": @NO,
        @"lastSeen": [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } merge:YES];
}

#pragma mark - Stop Firestore Listener

// Stop listening to user changes
- (void)stopListening {
    if (self.listener) {
        [self.listener remove];
        self.listener = nil;
    }
}


- (BOOL)isUserLoggedIn {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        return NO;
    }
    if (self.currentUser.ID.length > 0 &&
        ![self.currentUser.ID isEqualToString:authUser.uid]) {
        return NO;
    }
    return YES;
}


- (void)updateCurrentUserWithPPUserTokenID:(NSString *)PPUserTokenID SubID:(NSString *)SubID {
    (void)SubID;
    [self updateCurrentUserWithPPUserTokenID:PPUserTokenID];
}


- (void)updateUser:(UserModel *)user completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!user) {
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"UserManager"
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey: @"Invalid user model."}]);
        }
        return;
    }

    NSString *uid = user.ID;
    if (uid.length == 0) {
        uid = [FIRAuth auth].currentUser.uid;
    }
    if (uid.length == 0) {
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"UserManager"
                                               code:401
                                           userInfo:@{NSLocalizedDescriptionKey: @"User not logged in."}]);
        }
        return;
    }

    NSMutableDictionary *userDict = [[user toDictionary] mutableCopy];
    if (!userDict) userDict = [NSMutableDictionary dictionary];
    [userDict removeObjectForKey:@"createdAt"];
    userDict[@"ID"] = uid;
    userDict[@"updatedAt"] = [NSDate date];
    userDict[@"loginSource"] = @(UserLoginSourcePPUsers);

    FIRDocumentReference *docRef = [[self.firestore collectionWithPath:@"UsersCol"] documentWithPath:uid];
    [docRef setData:userDict merge:YES completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] ❌ Failed to update user %@: %@", uid, error.localizedDescription);
            if (completion) completion(NO, error);
        } else {
            user.ID = uid;
            self.currentUser = user;
            [self cacheUser:user];
            NSLog(@"[UserManager] ✅ User document merged for UID=%@.", uid);
            if (completion) completion(YES, nil);
        }
    }];
}



- (void)uploadUserImage:(UIImage *)image
         userImageName:(NSString *)imageName
            completion:(void (^)(NSError * _Nullable error, NSString * _Nullable imageURL))completion {

    NSString *uid = [self pp_currentUserDocumentUID];
    if (!image || imageName.length == 0 || uid.length == 0) {
        if (completion) {
            completion([NSError errorWithDomain:@"UserManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey: @"Invalid image or user"}],
                       nil);
        }
        return;
    }

    NSData *imageData = UIImageJPEGRepresentation(image, 0.8); // You can use PNG if needed
    if (!imageData) {
        completion([NSError errorWithDomain:@"UserManager"
                                       code:401
                                   userInfo:@{NSLocalizedDescriptionKey: @"Image conversion failed"}],
                   nil);
        return;
    }

    NSString *storagePath = [NSString stringWithFormat:@"UsersImages/%@", imageName];
    FIRStorageReference *ref = [[[FIRStorage storage] reference] child:storagePath];

    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
    metadata.contentType = @"image/jpeg";

    [ref putData:imageData metadata:metadata completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to upload image: %@", error.localizedDescription);
            if (completion) completion(error, nil);
            return;
        }

        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
            if (error || !URL) {
                NSLog(@"❌ Failed to get download URL: %@", error.localizedDescription);
                if (completion) completion(error, nil);
                return;
            }

            NSString *urlString = URL.absoluteString;

            // Update Firestore
            FIRDocumentReference *docRef = [[self.firestore collectionWithPath:@"UsersCol"] documentWithPath:uid];
            [docRef updateData:@{@"UserImageUrl": urlString} completion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"⚠️ Uploaded image but failed to update Firestore: %@", error.localizedDescription);
                    if (completion) completion(error, urlString);
                } else {
                    NSLog(@"✅ Image uploaded and Firestore updated");
                    self.currentUser.UserImageUrl = URL;
                    [self cacheUser:self.currentUser];
                    if (completion) completion(nil, urlString);
                }
            }];
        }];
    }];
}

- (void)addUser:(UserModel *)user
     completion:(void (^)(NSError * _Nullable error, NSString * _Nullable userID))completion {
    if (!user) {
        if (completion) {
            completion([NSError errorWithDomain:@"UserManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey: @"Invalid user model."}],
                       nil);
        }
        return;
    }

    NSString *uid = user.ID;
    if (uid.length == 0) {
        uid = [FIRAuth auth].currentUser.uid;
    }
    if (uid.length == 0) {
        if (completion) {
            completion([NSError errorWithDomain:@"UserManager"
                                           code:401
                                       userInfo:@{NSLocalizedDescriptionKey: @"User not logged in."}],
                       nil);
        }
        return;
    }

    NSMutableDictionary *userDict = [[user toDictionary] mutableCopy];
    if (!userDict) userDict = [NSMutableDictionary dictionary];
    userDict[@"ID"] = uid;
    userDict[@"createdAt"] = userDict[@"createdAt"] ?: [NSDate date];
    userDict[@"updatedAt"] = [NSDate date];
    userDict[@"loginSource"] = @(UserLoginSourcePPUsers);

    FIRDocumentReference *docRef = [[self.firestore collectionWithPath:@"UsersCol"] documentWithPath:uid];
    [docRef setData:userDict merge:YES completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[UserManager] ❌ Failed to add user %@: %@", uid, error.localizedDescription);
            if (completion) completion(error, nil);
        } else {
            user.ID = uid;
            self.currentUser = user;
            [self cacheUser:user];
            NSLog(@"[UserManager] ✅ User added/merged in Firestore for UID=%@.", uid);
            if (completion) completion(nil, uid);
        }
    }];
}

-(void)setUserImageForUser:(UserModel *)user toImageView:(UIImageView *)imageView
{
    [self setUserImageForUser:user toImageView:imageView parentCircle:nil];
}
-(void)setUserImageForUser:(UserModel *)user toImageView:(UIImageView *)imageView  parentCircle:(UIView * _Nullable)circle
{
    NSString *imName  = @"person.crop.circle.fill";
        if (!user || !imageView) return;

        if (user.UserImageUrl) {
            // Use already resolved URL
            
            [GM setImageFromUrlString:user.UserImageUrl.absoluteString imageView:imageView phImage:@"man" completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
                [UIView animateWithDuration:0.2 animations:^{
                    imageView.layer.borderColor = [GM AppForegroundColor].CGColor;
                    imageView.layer.borderWidth = 1.0;
                }];
                if(!image) imageView.image = [UIImage systemImageNamed:imName];
            }];
            //[self loadImageFromURL:user.UserImageUrl into:imageView];
            
            
        } else if (user.UserImageName.length > 0) {
            // Load from Firebase Storage
            NSString *path = [NSString stringWithFormat:@"UsersImages/%@", user.UserImageName];
            FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
                if (!error && URL) {
                    user.UserImageUrl = URL;
                    [self loadImageFromURL:URL into:imageView];
                } else {
                    NSLog(@"❌ Failed to load user image: %@", error.localizedDescription);
                    imageView.image = [UIImage systemImageNamed:imName];
                }
            }];
        } else {
            imageView.image =[UIImage systemImageNamed:imName];
        }
    
    if(!user.UserImageUrl)
    {
        
        [PPFunc PPPlaceIcon:@"plus" onPostions:IconPostionsBottomRight onView:circle ?  circle  : imageView];
    }
    

}


// Make sure you have:
// #import <YYWebImage/YYWebImage.h>
// #import <YYImage/YYImage.h>

- (void)loadImageFromURL:(NSURL *)url into:(UIImageView *)imageView {
    if (!imageView) return;

    UIImage *placeholder = [UIImage systemImageNamed:@"person.crop.circle.fill"];

    if (!url) {
        // Fallback instantly
        dispatch_async(dispatch_get_main_queue(), ^{
            imageView.image = placeholder;
        });
        return;
    }

    // Safe UI setup on main
    dispatch_async(dispatch_get_main_queue(), ^{
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
    });

    // Nice defaults: progressive + fade
    YYWebImageOptions opts =
        YYWebImageOptionProgressive |
        YYWebImageOptionSetImageWithFadeAnimation;

    __weak typeof(imageView) weakIV = imageView;
    [imageView setImageWithURL:url
                      placeholder:placeholder
                          options:opts
                         progress:nil
                        transform:nil
                       completion:^(UIImage * _Nullable image,
                                    NSURL * _Nonnull imageURL,
                                    YYWebImageFromType from,
                                    YYWebImageStage stage,
                                    NSError * _Nullable error)
    {
        __strong typeof(weakIV) iv = weakIV;
        if (!iv) return;

        if (error || !image) {
            // keep placeholder on failure
#ifdef DEBUG
            NSLog(@"[YYImage] load failed: %@ | %@", imageURL.absoluteString, error.localizedDescription);
#endif
            return;
        }

#ifdef DEBUG
        NSString *source = (from == YYWebImageFromMemoryCache ? @"memory"
                         : from == YYWebImageFromDiskCache   ? @"disk"
                         :                                     @"network");
        NSLog(@"[YYImage] loaded from %@: %@", source, imageURL.absoluteString);
#endif
        // Nothing else needed; yy_setImageWithURL already applied the image (with fade)
    }];
}




- (void)setUserDefaultsFromUserModel:(UserModel *)userModel {
    if (!userModel || userModel.ID.length == 0) {
        NSLog(@"USER ----->>  ❌ Invalid userModel. Cannot save to UserDefaults.");
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setObject:userModel.ID forKey:@"userID"];
    [defaults setObject:userModel.UserName ?: @"" forKey:@"UserName"];
    [defaults setObject:userModel.FirstName ?: @"" forKey:@"FirstName"];
    [defaults setObject:userModel.LastName ?: @"" forKey:@"LastName"];
    [defaults setObject:userModel.MobileNo ?: @"" forKey:@"MobileNo"];
    [defaults setObject:userModel.UserEmail ?: @"" forKey:@"UserEmail"];
    [defaults setObject:userModel.UserImageName ?: @"" forKey:@"UserImageName"];
    [defaults setObject:userModel.UserAbout ?: @"" forKey:@"UserAbout"];
    //[defaults setObject:userModel.loginType ?: @"" forKey:@"loginType"];
    //[defaults setObject:userModel.GIDuserID ?: @"" forKey:@"GIDuserID"];
    [defaults setInteger:userModel.CountryID forKey:@"CountryID"];

    if (userModel.UserImageUrl.absoluteString) {
        [defaults setObject:userModel.UserImageUrl.absoluteString forKey:@"UserImageUrl"];
    }

    if (userModel.PPUserTokenID) {
        [defaults setObject:userModel.PPUserTokenID forKey:@"PPUserTokenID"];
    }

    if (userModel.loginDate && [userModel.loginDate isKindOfClass:[FIRTimestamp class]]) {
        FIRTimestamp *timestamp = (FIRTimestamp *)userModel.loginDate;
        [defaults setObject:timestamp.dateValue forKey:@"loginDate"];
    } else if ([userModel.loginDate isKindOfClass:[NSDate class]]) {
        [defaults setObject:userModel.loginDate forKey:@"loginDate"];
    }
    
    

    [defaults synchronize];
    
    NSLog(@"USER ----->>  ✅ User info saved to UserDefaults.");
}


- (UserModel *)getUserModelFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    UserModel *userModel = [[UserModel alloc] init];
    
    userModel.ID = [defaults stringForKey:@"userID"];
    if (userModel.ID.length == 0) {
        userModel.ID = [defaults stringForKey:@"uid"];
    }
    userModel.UserName = [defaults stringForKey:@"UserName"];
    userModel.FirstName = [defaults stringForKey:@"FirstName"];
    userModel.LastName = [defaults stringForKey:@"LastName"];
    userModel.MobileNo = [defaults stringForKey:@"MobileNo"];
    userModel.UserEmail = [defaults stringForKey:@"UserEmail"];
    userModel.UserImageName = [defaults stringForKey:@"UserImageName"];
    userModel.UserAbout = [defaults stringForKey:@"UserAbout"];

    userModel.CountryID = (int)[defaults integerForKey:@"CountryID"];

    NSString *urlString = [defaults stringForKey:@"UserImageUrl"];
    if (urlString.length > 0) {
        userModel.UserImageUrl = [NSURL URLWithString:urlString];
    }

    userModel.PPUserTokenID = [defaults stringForKey:@"PPUserTokenID"];

    NSDate *loginDate = [defaults objectForKey:@"loginDate"];
    if ([loginDate isKindOfClass:[NSDate class]]) {
        userModel.loginDate = loginDate;
    }

    if (userModel.ID.length > 0) {
        NSLog(@"USER ----->> ✅ UserModel loaded from UserDefaults");
        return userModel;
    } else {
        NSLog(@"USER ----->> ❌ No valid UserModel found in UserDefaults");
        return nil;
    }
}


// Optional:  A helper function to clear all user defaults.  Useful for logout.
- (void)clearUserDefaults {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *uid = [defs stringForKey:@"lastLoggedInUID"];
    if (uid.length > 0) {
        [UserModel clearCachedUserWithUID:uid];
    }

    NSArray<NSString *> *keysToRemove = @[
        @"lastLoggedInUID",
        @"lastAuthenticatedUID",
        @"userID",
        @"uid",
        @"UserName",
        @"FirstName",
        @"LastName",
        @"MobileNo",
        @"UserEmail",
        @"UserImageName",
        @"UserAbout",
        @"CountryID",
        @"PPUserTokenID",
        @"SubID",
        @"loginDate",
        @"UserImageUrl"
    ];
    for (NSString *key in keysToRemove) {
        [defs removeObjectForKey:key];
    }
    [defs synchronize];
    NSLog(@"[UserManager] Cleared cached user defaults.");
}


- (void)logoutAndClearAll {
    [self pp_stopTokenRefreshTimer];
    [self stopListeningCurrentUserPermissions];
    if (self.listener) {
        [self.listener remove];
        self.listener = nil;
    }
    [self stopListening];
    [[AppDataListenerManager shared] stopAllListeners];
    [[ChManager sharedManager] stopListening];
    [[ChManager sharedManager] stopAllThreadMessageListeners];
    [CartManager.sharedManager clearCart];

    [self clearUserDefaults];
    self.currentUser = nil;
    PPCurrentUser = nil;
    self.isNewUser = NO;
    NSLog(@"[UserManager] Logged out and cleared user-scoped state.");
}

+ (void)getUidByUserID:(NSString *)userID completion:(void (^)(NSString * _Nullable uid, NSError * _Nullable error))completion {
    if (userID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:FUErrorDomain
                                                code:FUErrorCodeInvalidParameter
                                            userInfo:@{NSLocalizedDescriptionKey: @"User ID is required."}]);
        }
        return;
    }

    UserModel *cachedUser = userCacheByID[userID];
    if (cachedUser.ID.length > 0) {
        if (completion) completion(cachedUser.ID, nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query = [[db collectionWithPath:@"UsersCol"] queryWhereField:@"ID" isEqualTo:userID];
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        FIRDocumentSnapshot *doc = snapshot.documents.firstObject;
        if (!doc || !doc.exists) {
            if (completion) {
                completion(nil, [NSError errorWithDomain:FUErrorDomain
                                                    code:FUErrorCodeUserNotFound
                                                userInfo:@{NSLocalizedDescriptionKey: @"User not found."}]);
            }
            return;
        }

        UserModel *model = [[UserModel alloc] initWithSnapshot:doc];
        if (model) {
            [self cacheUserModelInMemory:model];
        }
        NSString *uid = model.ID.length > 0 ? model.ID : doc.documentID;
        if (completion) completion(uid, nil);
    }];
}



+ (NSString *)uidForID:(NSString *)userID {
    if (userID.length == 0) return nil;
    UserModel *cached = userCacheByID[userID];
    if (cached.ID.length > 0) {
        return cached.ID;
    }
    for (UserModel *user in AppManager.sharedInstance.usersArray) {
        if ([user.ID isEqualToString:userID]) {
            [self cacheUserModelInMemory:user];
            return user.ID;
        }
    }
    return nil;
}

+ (NSString *)iDForUid:(NSString *)uid {
    if (uid.length == 0) return nil;
    UserModel *cached = userCacheByUID[uid];
    if (cached.ID.length > 0) {
        return cached.ID;
    }
    for (UserModel *user in AppManager.sharedInstance.usersArray) {
        if ([user.ID isEqualToString:uid]) {
            [self cacheUserModelInMemory:user];
            return user.ID;
        }
    }
    return nil;
}

+ (UserModel *)userModelForID:(NSString *)userID {
    if (!userID || userID.length == 0) return nil;

    for (UserModel *user in AppManager.sharedInstance.usersArray) {
        if ([user.ID isEqualToString:userID]) {
            return user;
        }
    }
    return nil;
}


+ (void)showPromptOnTopController {
    UIViewController *topVC = [self topViewController];
    if (!topVC) return;

    // Avoid showing login if it’s already visible anywhere
    if ([self isShowingLoginFrom:topVC]) {
        return;
    }

    [PPAlertHelper showConfirmationIn:topVC
                                title:kLang(@"Not Registered")
                             subtitle:kLang(@"You need to register to continue.")
                        confirmButton:kLang(@"Register")
                         cancelButton:kLang(@"cancel")
                                 icon:[UIImage systemImageNamed:@"person.crop.circle.badge.questionmark"]
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        if (!didConfirm) return;
        [PPUserSigningManager presentSignInFrom:topVC
                                withCountryCode:CitiesManager.shared.CurrentCountry.countryCode
                              presentationStyle:PPSignInPresentationStyleSheet
                           autoDismissOnSuccess:YES
                                         success:^(__unused UserModel *user) {
            [PPFunc reloadAppUI];
            [[AppDataListenerManager shared] stopAllListeners];
            [[AppDataListenerManager shared] startListenersForUser:PPCurrentUser.ID];
        } failure:^(__unused NSError *error) {
        } cancelled:^{
        }];
    } cancelBlock:^{}];
}

+ (BOOL)isLoginOnStack:(UINavigationController *)nav {
    for (UIViewController *vc in nav.viewControllers) {
        if ([vc isKindOfClass:PPUserSigningController.class]) return YES;
    }
    return NO;
}

+ (BOOL)isShowingLoginFrom:(UIViewController *)vc {
    if ([vc isKindOfClass:PPUserSigningController.class]) return YES;
    if ([vc isKindOfClass:UINavigationController.class]) {
        return [self isLoginOnStack:(UINavigationController *)vc];
    }
    if (vc.navigationController && [self isLoginOnStack:vc.navigationController]) return YES;
    if (vc.presentedViewController) return [self isShowingLoginFrom:vc.presentedViewController];
    return NO;
}



+ (UIViewController *)topViewController {
    UIWindow *win = [self activeWindow];
    return [self topViewControllerFrom:win.rootViewController];
}

+ (UIWindow *)activeWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:UIWindowScene.class]) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    // Fallback (pre-iOS 13 or no key flag)
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

+ (UIViewController *)topViewControllerFrom:(UIViewController *)vc {
    if ([vc isKindOfClass:UINavigationController.class]) {
        return [self topViewControllerFrom:((UINavigationController *)vc).visibleViewController];
    } else if ([vc isKindOfClass:UITabBarController.class]) {
        return [self topViewControllerFrom:((UITabBarController *)vc).selectedViewController];
    } else if (vc.presentedViewController) {
        return [self topViewControllerFrom:vc.presentedViewController];
    } else {
        return vc;
    }
}


@end

/*
 
 
 
 
 
 
 
 
 
 // ========================================  FUM MANAGER SOURCE ==============================//

 #pragma mark - Auth listener (top level)

 - (void)startAuthListenerWithChangeBlock:(void(^)(FIRUser * _Nullable authUser,
                                                   UserModel * _Nullable userModel))block
 {
     if (self.authHandle) {
         [[FIRAuth auth] removeAuthStateDidChangeListener:self.authHandle];
         self.authHandle = 0;
     }

     __weak typeof(self) weakSelf = self;
     self.authHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser * _Nullable authUser) {
         __strong typeof(weakSelf) self = weakSelf;
         if (!self) return;

         if (!authUser) { if (block) block(nil, nil); return; }

         [[self userDocumentRefForUID:authUser.uid] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable err) {
             FUUserDoc *d = nil;
             if (snap.exists && snap.data) {
                 d = [FUUserDoc new];
                 d.uid         = authUser.uid;
                 d.email       = FUString(snap[@"email"])       ?: authUser.email;
                 d.displayName = FUString(snap[@"displayName"]) ?: authUser.displayName;
                 d.photoURL    = FUURL(snap[@"photoURL"])       ?: authUser.photoURL;
                 d.raw         = snap.data;
             }
             UserModel *merged = [self userModelFromAuth:authUser doc:d];
             if (block) block(authUser, merged);
         }];
     }];
 }

 - (void)reloadCurrentUserWithCompletion:(void(^)(UserModel * _Nullable user,
                                                  NSError * _Nullable error))completion
 {
     FIRUser *authUser = [FIRAuth auth].currentUser;
     if (!authUser) { if (completion) completion(nil, nil); return; }

     [[self userDocumentRefForUID:authUser.uid] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable err) {
         if (err) { if (completion) completion(nil, err); return; }
         FUUserDoc *d = nil;
         if (snap.exists && snap.data) {
             d = [FUUserDoc new];
             d.uid         = authUser.uid;
             d.email       = FUString(snap[@"email"])       ?: authUser.email;
             d.displayName = FUString(snap[@"displayName"]) ?: authUser.displayName;
             d.photoURL    = FUURL(snap[@"photoURL"])       ?: authUser.photoURL;
             d.raw         = snap.data;
         }
         UserModel *merged = [self userModelFromAuth:authUser doc:d];
         if (completion) completion(merged, nil);
     }];
 }

 #pragma mark - Arbitrary field updates

 - (void)updateUserFieldsForUID:(NSString *)uid
                         fields:(NSDictionary<NSString *,id> *)fields
                     completion:(FUErrorBlock)completion
 {
     if (uid.length == 0 || fields.count == 0) { if (completion) completion([self p_err:@"Invalid uid or empty fields" code:-1]); return; }

     [[[self.db collectionWithPath:kFUUsersCollection] documentWithPath:uid]
      updateData:fields
      completion:^(NSError * _Nullable error) {
         if (completion) completion(error);
     }];
 }
 // ========================================  FUM MANAGER SOURCE ==============================//

 */
