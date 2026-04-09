//
//  UserManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2025.
//

/*
 #import <FirebaseAuth/FirebaseAuth.h>
 #import <FirebaseFirestore/FirebaseFirestore.h>

 + (void)updateUserWithDisplayName:(NSString *)displayName
                          photoURL:(NSURL *)photoURL
                       completion:(void (^ _Nullable)(NSError * _Nullable authError,
                                                      NSError * _Nullable firestoreError))completion {
     // 1. Get the current Firebase Auth user
     FIRUser *user = [FIRAuth auth].currentUser;
     if (!user) {
         // No user is signed in
         if (completion) {
             NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"No authenticated user." };
             NSError *error = [NSError errorWithDomain:@"AuthErrorDomain" code:0 userInfo:userInfo];
             completion(error, nil);
         }
         return;
     }
     
     // 2. Update Auth profile (displayName and photoURL)
     FIRUserProfileChangeRequest *changeRequest = [user profileChangeRequest];
     changeRequest.displayName = displayName;
     changeRequest.photoURL = photoURL;
     [changeRequest commitChangesWithCompletion:^(NSError * _Nullable authError) {
         if (authError) {
             // Auth profile update failed
             if (completion) completion(authError, nil);
             return;
         }
         // 3. Auth profile update succeeded -> update Firestore document
         FIRFirestore *db = [FIRFirestore firestore];
         FIRDocumentReference *docRef = [[db collectionWithPath:@"UsersCol"] documentWithPath:user.uid];
         // Prepare data dictionary
         NSMutableDictionary *data = [@{ @"displayName": displayName } mutableCopy];
         if (photoURL) {
             data[@"photoURL"] = [photoURL absoluteString];
         }
         // Merge these fields into Firestore document
         [docRef setData:data
                   merge:YES
              completion:^(NSError * _Nullable firestoreError) {
             // 4. Firestore update completed (or failed)
             if (completion) completion(nil, firestoreError);
         }];
     }];
 }

 */
@import FirebaseAuth;
@import FirebaseFirestore;
#import "PPUserSigningController.h"
#import "PPUserSigningManager.h"
@class UserModel;
@class PPPetProfile;
@class PPPetReminder;

extern NSString * _Nullable const LanguageDidChangeNotification;

typedef NS_ENUM(NSInteger, ProfileGreetingShorteningMode) {
    ProfileGreetingShorteningModeNone,        // Full greeting + full username
    ProfileGreetingShorteningModeShortName,   // Shortened username only
    ProfileGreetingShorteningModeShortGreet,  // Short greeting only
    ProfileGreetingShorteningModeBoth,
    ProfileGreetingShorteningModeShotNameOnly  // Shorten both greeting + username
};


@import FirebaseCore;
@import Firebase;
@import FirebaseFunctions;
@class UserModel;
@class FIRQuery;
@protocol FIRListenerRegistration;

NS_ASSUME_NONNULL_BEGIN

// MARK: - Constants (Update Keys, Error Domain, etc.)

/// User profile update field keys
extern NSString *const FUUpdateKeyEmail;
extern NSString *const FUUpdateKeyPhoneNumber;
extern NSString *const FUUpdateKeyDisplayName;
extern NSString *const FUUpdateKeyPhotoURL;
extern NSString *const FUUpdateKeyCustomClaims;

/// Error domain and userInfo keys for UserManager errors
extern NSString *const FUErrorDomain;
extern NSErrorUserInfoKey const FUErrorDetailedDescriptionKey;
extern NSString *const PPUserManagerDidSyncCurrentUserNotification;
extern NSString *const PPUserManagerDidSignOutNotification;
extern NSString *const PPUserManagerDidUpdateBlockedStateNotification;
extern NSString *const PPUserManagerBlockedStateUserInfoKey;

/// Custom error codes for UserManager operations
typedef NS_ENUM(NSInteger, FUErrorCode) {
    FUErrorCodeInvalidParameter    = 1000,
    FUErrorCodeUserNotFound        = 1001,
    FUErrorCodeNetworkError        = 1002,
    FUErrorCodePermissionDenied    = 1003,
    FUErrorCodeInvalidCredentials  = 1004,
    FUErrorCodeOperationNotAllowed = 1005,
    FUErrorCodeRequiresRecentLogin = 1006,
    FUErrorCodeCustomClaimError    = 1007
};

// MARK: - Completion Block Type Definitions

typedef void (^FUAuthStateHandler)(UserModel * _Nullable user, NSError * _Nullable error);
typedef void (^FUUserCompletion)(UserModel * _Nullable user, NSError * _Nullable error);
typedef void (^FUCompletion)(NSError * _Nullable error);
typedef void (^FUURLCompletion)(NSURL * _Nullable URL, NSError * _Nullable error);
typedef void (^FUProgressHandler)(double progress);
typedef void (^FUUsersListCompletion)(NSArray<UserModel*> * _Nullable users, NSError * _Nullable error);


static inline NSString * _Nullable PPPermNameFor(UserPermission flag) {
    switch (flag) {
        case UserPermissionPostAds:     return kPermPostAds;
        case UserPermissionSellNew:     return kPermSellNew;
        case UserPermissionSellUsed:    return kPermSellUsed;
        case UserPermissionAdoption:    return kPermAdoption;
        case UserPermissionManageStore: return kPermManageStore;
        case UserPermissionModeration:  return kPermModeration;
        case UserPermissionManageFood:  return kPermManageFood;
        case UserPermissionManageServices: return kPermManageServices;
        case UserPermissionProduction:  return kPermProduction;
        case UserPermissionAdminAll:    return kPermAdminAll;
        default:                        return nil;
    }
}





// MARK: - UserManager Interface

@interface UserManager : NSObject

 
- (void)fetchPetProfilesForCurrentUserWithCompletion:(void (^)(NSArray<PPPetProfile *> * _Nullable pets, NSError * _Nullable error))completion;
- (void)savePetProfile:(PPPetProfile *)pet completion:(void (^)(NSError * _Nullable error))completion;
- (void)deletePetProfileWithID:(NSString *)petID completion:(void (^)(NSError * _Nullable error))completion;
- (void)setDefaultPetProfileID:(NSString *)petID completion:(void (^)(NSError * _Nullable error))completion;
- (void)uploadPetImage:(UIImage *)image petID:(NSString *)petID completion:(void (^)(NSString * _Nullable imageURL, NSError * _Nullable error))completion;

- (void)fetchPetRemindersForCurrentUserWithCompletion:(void (^)(NSArray<PPPetReminder *> * _Nullable reminders, NSError * _Nullable error))completion;
- (void)savePetReminder:(PPPetReminder *)reminder completion:(void (^)(NSError * _Nullable error))completion;
- (void)deletePetReminderWithID:(NSString *)reminderID completion:(void (^)(NSError * _Nullable error))completion;



/// The singleton instance of UserManager
+ (instancetype)sharedManager;

/// Currently logged-in user’s model (nil if not logged in)
@property (nonatomic, strong, nullable) UserModel *currentUser;
/// Currently logged-in Firebase Auth user (nil if not logged in)
@property (nonatomic, strong, nullable) FIRUser *currentAuthUser;
/// Firebase Cloud Functions handle (for privileged operations)
@property (nonatomic, strong, readonly) FIRFunctions *functions;

@property (nonatomic, strong, nullable) NSString *currentToken;

+ (void)cleanupUnauthenticatedFirestoreUsers_OneTime;
#pragma mark - Authentication State Management

/// Start observing Firebase Auth state changes. Handler is called on sign-in or sign-out events.
- (void)startAuthStateMonitoringWithHandler:(nullable FUAuthStateHandler)handler;
/// Stop observing Auth state changes.
- (void)stopAuthStateMonitoring;
/// Reload the current user’s Firebase Auth data (e.g. to get updated profile/claims).
- (void)reloadCurrentUserWithCompletion:(FUUserCompletion)completion;
/// Restore and validate session on app launch (auth/user doc consistency, token state).
- (void)restoreSessionOnLaunchWithCompletion:(FUCompletion)completion;
/// Validate current auth state (disabled account, blocked profile, email verification if required).
- (void)validateCurrentAuthSessionWithCompletion:(FUCompletion)completion;
/// Refresh ID token when needed to reduce expired-token edge cases.
- (void)refreshIDTokenIfNeededWithCompletion:(FUCompletion)completion;

#pragma mark - Sign In Methods (Google, Apple, Phone)

/// Sign in using Google credentials (ID token and access token).
- (void)signInWithGoogleIDToken:(NSString *)idToken
                    accessToken:(NSString *)accessToken
                     completion:(FUUserCompletion)completion;

/// Sign in using Apple ID credentials (ID token and raw nonce).
- (void)signInWithAppleIDToken:(NSString *)idToken
                       rawNonce:(NSString *)nonce
                     completion:(FUUserCompletion)completion;

/// Sign in using phone number (requires verification ID and code from SMS).
- (void)signInWithPhoneVerificationID:(NSString *)verificationID
                        verificationCode:(NSString *)verificationCode
                             completion:(FUUserCompletion)completion;


- (void)handlePostSignInForAuthResult:(FIRAuthDataResult *)authResult
                           isNewUser:(BOOL)isNew
                           completion:(FUUserCompletion)completion ;
#pragma mark - Sign Out & Account Deletion

/// Sign out the current user and clear all cached data.
- (void)signOutCurrentUserWithCompletion:(nullable FUCompletion)completion;
/// Permanently delete the current user's account (requires recent login).
- (void)deleteCurrentUserAccountWithCompletion:(FUCompletion)completion;

#pragma mark - User Profile Management (Firebase Auth + Firestore)

/// Update the current user’s profile with multiple values at once (email, displayName, etc.).
/// Accepts a dictionary of FUUpdateKey* keys. Automatically updates both Auth profile and Firestore document.
- (void)updateCurrentUserProfileWithValues:(NSDictionary<NSString *, id> *)values
                                completion:(FUCompletion)completion;

/// Update another user’s profile in Firestore (admin only, requires appropriate privileges).
/// Values dictionary can include keys for Firestore fields or custom claims.
- (void)updateUserProfileForUID:(NSString *)userUID
                         values:(NSDictionary<NSString *, id> *)values
                     completion:(FUCompletion)completion;

/// Update the current user's email (Firebase Auth and Firestore).
- (void)updateCurrentUserEmail:(NSString *)email
                    completion:(FUCompletion)completion;
/// Update the current user's phone number (will send verification SMS internally).
- (void)updateCurrentUserPhoneNumber:(NSString *)phoneNumber
                          completion:(FUCompletion)completion;
/// Update the current user's display name (Firebase Auth and Firestore).
- (void)updateCurrentUserDisplayName:(NSString *)displayName
                          completion:(FUCompletion)completion;

#pragma mark - Multi-Provider Account Management

/// Link an email/password (Gmail) provider to the current user’s account.
- (void)linkEmailProviderWithEmail:(NSString *)email
                          password:(NSString *)password
                        completion:(FUUserCompletion)completion;
/// Link a phone number provider to the current user’s account (will send verification SMS).
- (void)linkPhoneNumberProviderWithNumber:(NSString *)phoneNumber
                               completion:(FUUserCompletion)completion;
/// Link an Apple ID provider to the current user’s account.
- (void)linkAppleProviderWithIDToken:(NSString *)idToken
                               nonce:(NSString *)nonce
                          completion:(FUUserCompletion)completion;
/// Unlink a provider (by provider ID, e.g. @"google.com", @"apple.com", @"phone", @"password") from current user.
- (void)unlinkProvider:(NSString *)providerID
            completion:(FUUserCompletion)completion;
/// Fetch the list of linked sign-in providers for the current user.
- (void)fetchLinkedProvidersWithCompletion:(void(^)(NSArray<NSString *> *providers, NSError * _Nullable error))completion;

#pragma mark - Provider-Specific Updates

/// Update (change) the current user's phone number by verifying a new number and updating it.
- (void)updatePhoneNumberForCurrentUser:(NSString *)phoneNumber
                             completion:(FUCompletion)completion;

#pragma mark - Photo/Avatar Management

/// Upload a user avatar image to Firebase Storage (resizing if necessary). Returns the download URL.
- (void)uploadUserAvatar:(UIImage *)avatarImage
            maxDimension:(CGFloat)maxDimension
             maxFileSize:(NSUInteger)maxFileSize
                progress:(FUProgressHandler)progress
              completion:(FUURLCompletion)completion;
/// Update the current user's profile photo URL in Firebase Auth and Firestore.
- (void)updateUserAvatarWithURL:(NSURL *)avatarURL
                     completion:(FUCompletion)completion;
/// Delete the current user's avatar from storage and clear the photo URL in profile.
- (void)deleteUserAvatarWithCompletion:(FUCompletion)completion;
/// Fetch a user's avatar URL (download URL from Firebase Storage) by their UID.
- (void)fetchUserAvatarURLForUID:(NSString *)userUID
                      completion:(FUURLCompletion)completion;

#pragma mark - Firestore User Document Management

/// Create a Firestore user document for the given UID with initial data (if not already exists).
- (void)createUserDocumentForUID:(NSString *)userUID
                     initialData:(NSDictionary *)data
                      completion:(FUCompletion)completion;
/// Update fields in an existing Firestore user document for the given UID.
- (void)updateUserDocumentForUID:(NSString * _Nullable)userUID
                          fields:(NSDictionary<NSString *, id> * _Nullable)fields
                      completion:(FUCompletion _Nullable)completion;
/// Fetch a user’s Firestore document data by UID.
- (void)fetchUserDocumentForUID:(NSString *)userUID
                     completion:(void(^)(NSDictionary * _Nullable document, NSError * _Nullable error))completion;
/// Delete a user’s Firestore document by UID.
- (void)deleteUserDocumentForUID:(NSString *)userUID
                      completion:(FUCompletion)completion;

#pragma mark - User Listing & Querying

/// Observe all users matching a Firestore query in real-time. Returns a listener handle for removal.
- (id<FIRListenerRegistration>)observeAllUsersWithQuery:(FIRQuery *)query
                                             completion:(FUUsersListCompletion)completion;
/// Fetch users matching a Firestore query once (no real-time updates).
- (void)fetchUsersWithQuery:(FIRQuery *)query
                 completion:(FUUsersListCompletion)completion;
/// Search users by a specific field value (e.g., username, email). Returns all matching user models.
- (void)searchUsersWithField:(NSString *)fieldName
                       value:(id)value
                  completion:(FUUsersListCompletion)completion;

#pragma mark - Permissions & Roles

/// Bulk update a specific permission flag (allow/deny) for multiple users at once.
- (void)updatePermission:(UserPermission)flag
                 enabled:(BOOL)enabled
              forUserIDs:(NSArray<NSString *> *)userIDs
              completion:(FUCompletion)completion;
/// Check if the current user has a given permission.
- (BOOL)currentUserCan:(UserPermission)flag;
/// Start listening to the current user’s permission subcollection (keeps currentUser.permissions updated).
- (void)startListeningCurrentUserPermissionsWithChange:(void (^_Nullable)(NSDictionary<NSString *, NSNumber *> *  _Nullable perms))onChange;

/// Stop listening to the current user’s permission subcollection.
- (void)stopListeningCurrentUserPermissions;
/// Start/stop a real-time listener on current user's `isBlocked` field.
- (void)startListeningCurrentUserBlockedState;
- (void)stopListeningCurrentUserBlockedState;
/// Fast check against locally cached current user model.
- (BOOL)isCurrentUserBlocked;

#pragma mark - Security & Reauthentication

/// Reauthenticate the current user via SMS (will send a verification code to the user's phone).
- (void)reauthenticateWithPhoneNumber:(NSString *)phoneNumber
                           completion:(FUCompletion)completion;

#pragma mark - Batch Operations

/// Batch update specified fields for multiple user documents. Returns an array of errors (empty on success).
- (void)batchUpdateUsers:(NSArray<NSString *> *)userUIDs
                  fields:(NSDictionary<NSString *, id> *)fields
              completion:(void(^)(NSArray<NSError *> *errors))completion;
/// Batch delete multiple user documents. Returns an array of errors (empty on success).
- (void)batchDeleteUsers:(NSArray<NSString *> *)userUIDs
              completion:(void(^)(NSArray<NSError *> *errors))completion;

#pragma mark - Analytics & Monitoring

/// Log a custom user activity event (e.g., login, logout, profile_update) with optional parameters.
- (void)logUserActivity:(NSString *)activity
             parameters:(NSDictionary *)parameters;
/// Track a numeric user engagement metric (e.g., time spent, score, etc.).
- (void)trackUserEngagementMetric:(NSString *)metric
                            value:(NSNumber *)value;

#pragma mark - User Session Caching

/// Cache the given user model to disk for quick retrieval (e.g., for offline use or session persistence).
- (void)cacheUser:(UserModel *)user;
/// Load the cached user from disk (if any) and set as currentUser.
- (void)loadCachedUser;
/// Clear any saved user data from disk and user defaults (e.g., on logout or user switch).
- (void)clearUserDefaults;
/// Clear cached data and sign out the current user (convenience).
- (void)logoutAndClearAll;

#pragma mark - User ID <-> UID Mapping (if applicable)

/// Asynchronously get Firebase UID for a given custom userID (e.g., username) if such mapping exists.
+ (void)getUidByUserID:(NSString *)userID
            completion:(void (^)(NSString * _Nullable uid, NSError * _Nullable error))completion;
/// Synchronously get Firebase UID for a given custom userID from cache (if loaded).
+ (NSString * _Nullable)uidForID:(NSString *)userID;
/// Get a cached UserModel by custom userID (if available).
+ (UserModel * _Nullable)userModelForID:(NSString *)userID;

+ (UserModel *)userModelFromUsersArrayForID:(NSString *)userID;

/// Get custom userID for a given Firebase UID (if available in cache).
+ (NSString * _Nullable)iDForUid:(NSString *)uid;

/// Utility: Show a prompt on the top-most view controller (e.g., for entering verification codes or displaying alerts).
+ (void)showPromptOnTopController;

- (BOOL)isUserLoggedIn;


- (void)getUserWithUID:(NSString *)uid
            completion:(void (^)(UserModel * _Nullable user, NSError * _Nullable error))completion;


- (void)updateUser:(UserModel *)user
        completion:(void (^)(BOOL success, NSError * _Nullable updateError))completion;

// UserManager.h

/// Upload a user image (e.g., avatar) to `/users/{uid}/{imageName}` in Firebase Storage.
/// Returns the download URL string on success.
- (void)uploadUserImage:(UIImage *)image
          userImageName:(NSString *)imageName
             completion:(void (^)(NSError * _Nullable error, NSString * _Nullable imageURL))completion;

/// Create/Upsert a user document at `UsersCol/<uid>`
/// - Forces PPUserTokenID (device token) and `loginSource = UserLoginSourcePPUsers`
/// - Returns `userID` (the Firebase UID) on success
- (void)addUser:(UserModel *)user
     completion:(void (^)(NSError * _Nullable error, NSString * _Nullable userID))completion;

- (void)getOtherUserModelFromFirestoreWithUID:(NSString *)uid completion:(void (^)(UserModel * _Nullable user, NSError * _Nullable error))completion;
- (void)updateCurrentUserWithPPUserTokenID:(NSString *)PPUserTokenID;


// ================================================================================

- (NSString *)profileNameAndTitleWithMode:(ProfileGreetingShorteningMode)mode ;
@end

NS_ASSUME_NONNULL_END






NS_ASSUME_NONNULL_BEGIN

@interface PPAuthManager : NSObject

/// Shared instance (singleton)
+ (instancetype)shared;

/// Call this at app startup to detect fresh install and enforce sign-out if needed
- (void)handleFreshInstall;

/// Explicit sign out (clears Firebase Auth + Firestore cache)
- (void)signOutUserWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Returns YES if a Firebase user is currently signed in
- (BOOL)isUserSignedIn;

@end

NS_ASSUME_NONNULL_END





