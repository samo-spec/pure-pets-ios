//
//  ChManager 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//


// ChManager.m
// Pure Pets
//
// Created by Mohammed Ahmed on [Date].

static NSString * const kPresenceCol  = @"UserPresence";
static NSString * const kFieldOnline  = @"online";
static NSString * const kFieldisOnline  = @"isOnline";
static NSString * const kFieldLastSeen = @"lastSeen";
static NSString * const kPPSupportAvatarToken = @"purepets://support-logo";
static NSString * const PURE_PETS_OFFICIAL_USER_ID = @"PUIDPOFFICILAL20262214";

#import "ChManager.h"
#import <UIKit/UIKit.h>
#import "PPOverlayCoordinator.h"
#import "UserManager.h"
#import "UserModel.h"
#import "PPFirebaseSessionBridge.h"

static NSDate *PPThreadActivityDate(ChatThreadModel *thread) {
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return [NSDate distantPast];
    }
    NSDate *lastMessageAt = thread.lastMessageAt;
    NSDate *timestamp = thread.timestamp;
    if (lastMessageAt && timestamp) {
        return ([lastMessageAt compare:timestamp] == NSOrderedAscending) ? timestamp : lastMessageAt;
    }
    return lastMessageAt ?: (timestamp ?: [NSDate distantPast]);
}

static NSString *PPSupportTrimmedString(id value) {
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static UserModel *PPSupportUserFromConfig(NSDictionary *config) {
    NSString *supportUserId = PPSupportTrimmedString(config[@"supportUserId"]);

    if (supportUserId.length == 0) {
        NSLog(@"⚠️ [SupportChat] CommerceConfig/supportChat is missing supportUserId. "
              @"Falling back to official UID: %@", PURE_PETS_OFFICIAL_USER_ID);
        supportUserId = PURE_PETS_OFFICIAL_USER_ID;
    }

    if (![supportUserId isEqualToString:PURE_PETS_OFFICIAL_USER_ID]) {
        NSLog(@"⚠️ [SupportChat] Firestore supportUserId (%@) does not match official UID (%@). "
              @"Using the canonical support account for this session.",
              supportUserId, PURE_PETS_OFFICIAL_USER_ID);
        supportUserId = PURE_PETS_OFFICIAL_USER_ID;
    }

    UserModel *supportUser = [UserModel new];
    supportUser.ID = supportUserId;
    supportUser.UserName = kLang(@"Support") ?: @"Support";
    supportUser.UserImageUrl = [NSURL URLWithString:kPPSupportAvatarToken];
    return supportUser;
}

static void PPSupportPresentUnavailableAlert(UIViewController *controller, NSString *message) {
    if (!controller) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        // Resolve + verify the presenter can actually present right now
        void (^tryPresent)(int) = ^(int attempt) {
            UIViewController *presenter = [PPOverlayCoordinator pp_resolvedPresenterFrom:controller];
            if (!presenter || ![PPOverlayCoordinator pp_canPresentFrom:presenter]) {
                if (attempt < 1) {
                    // VC may be mid-transition — retry once after a short delay
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                        UIViewController *retry = [PPOverlayCoordinator pp_resolvedPresenterFrom:controller];
                        if (retry && [PPOverlayCoordinator pp_canPresentFrom:retry]) {
                            UIAlertController *alert =
                                [UIAlertController alertControllerWithTitle:(kLang(@"Support") ?: @"Support")
                                                                    message:(message.length ? message : (kLang(@"Support chat is temporarily unavailable.") ?: @"Support chat is temporarily unavailable."))
                                                             preferredStyle:UIAlertControllerStyleAlert];
                            [alert addAction:[UIAlertAction actionWithTitle:(kLang(@"OK") ?: @"OK")
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:nil]];
                            [retry presentViewController:alert animated:YES completion:nil];
                        }
                    });
                }
                return;
            }

            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:(kLang(@"Support") ?: @"Support")
                                                    message:(message.length ? message : (kLang(@"Support chat is temporarily unavailable.") ?: @"Support chat is temporarily unavailable."))
                                             preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:(kLang(@"OK") ?: @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
            [presenter presentViewController:alert animated:YES completion:nil];
        };
        tryPresent(0);
    });
}


@interface ChManager ()
@property (nonatomic, strong) FIRFirestore *firestore;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> listener;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<FIRListenerRegistration>> *presenceListeners;
@property (nonatomic, strong) NSMutableSet<NSString *> *mutedThreadIDsStorage;

@property (nonatomic, strong) NSMutableDictionary<NSString *, id<FIRListenerRegistration>> *threadMessageListeners;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *knownMessageIDsByThread;
@property (nonatomic, assign) BOOL didFinishInitialMessageSync;
@property (nonatomic, strong) NSMutableSet<NSString *> *initialSyncedThreads;
//@property (nonatomic, strong) id<FIRListenerRegistration> globalDeliveryListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> globalIncomingListener;

- (void)sendChatPushToUserID:(NSString *)toUserID
                       title:(NSString *)title
                        body:(NSString *)body
                    threadID:(NSString *)threadID
                    senderID:(NSString *)senderID
                   messageID:(nullable NSString *)messageID
                  completion:(void (^ _Nullable)(BOOL didAcceptPush))completion;

- (void)pp_openSupportChatViaFirestoreFallbackWithSupportUser:(UserModel *)supportUser
                                                   customerID:(NSString *)customerID
                                                   completion:(void (^)(ChatThreadModel * _Nullable thread, NSError * _Nullable error))completion;

@end

@implementation ChManager
+ (instancetype)sharedManager {
    static ChManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ChManager alloc] init];
        sharedInstance.firestore = [FIRFirestore firestore];
        sharedInstance.presenceListeners = [NSMutableDictionary dictionary];
        
        sharedInstance.threadMessageListeners = [NSMutableDictionary dictionary];
        if (!sharedInstance.knownMessageIDsByThread) {
            sharedInstance.knownMessageIDsByThread = [NSMutableDictionary dictionary];
        }        sharedInstance.didFinishInitialMessageSync = NO;
        sharedInstance.initialSyncedThreads = [NSMutableSet set];
        
        sharedInstance.liveUnreadCounts = [NSMutableDictionary dictionary];
        sharedInstance.mutedThreadIDsStorage = [NSMutableSet set];
    });
    return sharedInstance;
}

- (NSString *)pp_authenticatedUIDForRequestedUID:(nullable NSString *)requestedUID
{
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (!authUID.length) {
        return @"";
    }
    if (requestedUID.length > 0 && ![requestedUID isEqualToString:authUID]) {
        NSLog(@"⚠️ [ChatAuth] UID mismatch for chat query. requested=%@ auth=%@. Using auth UID.", requestedUID, authUID);
    }
    return authUID;
}

- (NSArray<NSString *> *)pp_identityCandidatesForRequestedUID:(nullable NSString *)requestedUID
{
    NSMutableOrderedSet<NSString *> *ids = [NSMutableOrderedSet orderedSet];
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *modelID = UserManager.sharedManager.currentUser.ID ?: @"";
    NSString *requested = requestedUID ?: @"";

    if (authUID.length) [ids addObject:authUID];
    if (requested.length) [ids addObject:requested];
    if (modelID.length) [ids addObject:modelID];

    return ids.array ?: @[];
}

- (BOOL)pp_array:(NSArray<NSString *> * _Nullable)array containsAnyIdentity:(NSArray<NSString *> *)identityCandidates
{
    if (![array isKindOfClass:NSArray.class] || identityCandidates.count == 0) return NO;
    for (NSString *candidate in identityCandidates) {
        if (candidate.length > 0 && [array containsObject:candidate]) {
            return YES;
        }
    }
    return NO;
}

- (void)pp_openSupportChatWithUser:(UserModel *)supportUser
                         customerID:(NSString *)customerID
                    fromController:(UIViewController *)controller
{
    if (!supportUser || supportUser.ID.length == 0 || customerID.length == 0 || !controller) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    __weak UIViewController *weakController = controller;

    [self pp_openSupportChatViaCloudFunctionWithCustomerID:customerID completion:^(NSString * _Nullable threadId, NSError * _Nullable error) {
        UIViewController *strongController = weakController;
        if (!strongController) return;

        if (error || !threadId.length) {
            NSLog(@"❌ [SupportChat] Failed to create support thread: %@", error.localizedDescription ?: @"unknown error");
            if (error && [PPFirebaseSessionBridge isAuthOrAppCheckError:error]) {
                NSLog(@"⚠️ [SupportChat] Falling back to Firestore support thread open after credential preflight failure.");
                [weakSelf pp_openSupportChatViaFirestoreFallbackWithSupportUser:supportUser
                                                                     customerID:customerID
                                                                     completion:^(ChatThreadModel * _Nullable fallbackThread, NSError * _Nullable fallbackError) {
                    if (fallbackThread && !fallbackError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [PPOverlayCoordinator pp_openChatThread:fallbackThread fromVC:strongController];
                        });
                        return;
                    }

                    NSLog(@"❌ [SupportChat] Firestore fallback failed: %@", fallbackError.localizedDescription ?: @"unknown error");
                    NSString *fallbackMessage = fallbackError ? [PPFirebaseSessionBridge publicMessageForError:fallbackError fallbackKey:@"pp_support_open_failed"] : (kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now.");
                    PPSupportPresentUnavailableAlert(strongController, fallbackMessage);
                }];
                return;
            }
            NSString *message = error ? [PPFirebaseSessionBridge publicMessageForError:error fallbackKey:@"pp_support_open_failed"] : (kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now.");
            PPSupportPresentUnavailableAlert(strongController, message);
            return;
        }

        // Fetch the created/existing thread
        FIRFirestore *db = weakSelf.firestore ?: [FIRFirestore firestore];
        FIRDocumentReference *threadRef = [[db collectionWithPath:@"Chats"] documentWithPath:threadId];
        [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable readError) {
            if (readError || !snapshot.exists) {
                NSLog(@"❌ [SupportChat] Failed to read support thread after creation: %@", readError.localizedDescription);
                PPSupportPresentUnavailableAlert(strongController, kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now.");
                return;
            }

            ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:snapshot.data];
            thread.ID = snapshot.documentID;
            thread.otherUser = supportUser;

            dispatch_async(dispatch_get_main_queue(), ^{
                [PPOverlayCoordinator pp_openChatThread:thread fromVC:strongController];
            });
        }];
    }];
}

- (void)pp_openSupportChatViaFirestoreFallbackWithSupportUser:(UserModel *)supportUser
                                                   customerID:(NSString *)customerID
                                                   completion:(void (^)(ChatThreadModel * _Nullable thread, NSError * _Nullable error))completion
{
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *resolvedCustomerID = authUID.length > 0 ? authUID : (customerID ?: @"");
    NSString *supportUserID = PURE_PETS_OFFICIAL_USER_ID;

    if (resolvedCustomerID.length == 0 || supportUserID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"ChManager"
                                                code:401
                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"pp_auth_sign_in_required") ?: @"Please sign in to continue."}]);
        }
        return;
    }

    if ([resolvedCustomerID isEqualToString:supportUserID]) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"ChManager"
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now."}]);
        }
        return;
    }

    NSString *threadID = ([resolvedCustomerID compare:supportUserID] == NSOrderedAscending)
        ? [NSString stringWithFormat:@"%@_%@", resolvedCustomerID, supportUserID]
        : [NSString stringWithFormat:@"%@_%@", supportUserID, resolvedCustomerID];

    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];
    FIRDocumentReference *threadRef = [[db collectionWithPath:@"Chats"] documentWithPath:threadID];
    NSArray<NSString *> *members = @[resolvedCustomerID, supportUserID];

    NSDictionary *canonicalMetadata = @{
        @"members": members,
        @"conversationType": @"support",
        @"threadType": @"support",
        @"supportThread": @(YES),
        @"supportUserId": supportUserID,
        @"customerId": resolvedCustomerID,
        @"sourcePlatform": @"ios",
        @"supportDisplayName": @"Pure Pets",
        @"supportPhotoUrl": @"",
        @"supportStatus": @"waiting_for_agent",
        @"sourceScreen": @"support_chat",
        @"sourceType": @"general",
        @"sourceEntityId": @""
    };

    NSDictionary *(^supportCreatePayload)(void) = ^NSDictionary *{
        NSMutableDictionary *data = [canonicalMetadata mutableCopy];
        [data addEntriesFromDictionary:@{
            @"members": members,
            @"lastMessage": @"",
            @"lastUpdated": [FIRFieldValue fieldValueForServerTimestamp],
            @"timestamp": [FIRFieldValue fieldValueForServerTimestamp],
            @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"mutedBy": @[],
            @"binnedBy": @[],
            @"reportedBy": @[],
            @"reportCount": @(0),
            @"assignedTo": @""
        }];
        return data.copy;
    };

    void (^finishWithSnapshot)(FIRDocumentSnapshot * _Nullable) = ^(FIRDocumentSnapshot * _Nullable snapshot) {
        NSDictionary *threadData = snapshot.exists ? (snapshot.data ?: @{}) : @{
            @"members": members,
            @"conversationType": @"support",
            @"threadType": @"support",
            @"supportThread": @(YES),
            @"supportUserId": supportUserID,
            @"customerId": resolvedCustomerID,
            @"supportDisplayName": @"Pure Pets",
            @"supportPhotoUrl": @"",
            @"supportStatus": @"waiting_for_agent"
        };

        ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:threadData];
        thread.ID = threadID;
        thread.memberIDs = members;
        thread.otherUser = supportUser;
        thread.supportThread = YES;
        thread.supportUserID = supportUserID;
        thread.supportDisplayName = @"Pure Pets";
        thread.supportPhotoURLString = @"";
        if (!thread.timestamp) {
            thread.timestamp = [NSDate date];
        }
        [[ChManager sharedManager] startListeningForThreadMessages:@[thread]];
        if (completion) completion(thread, nil);
    };

    [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        if (snapshot.exists) {
            [threadRef setData:canonicalMetadata merge:YES completion:^(NSError * _Nullable mergeError) {
                if (mergeError) {
                    NSLog(@"⚠️ [SupportChat] Could not canonicalize fallback support metadata: %@", mergeError.localizedDescription ?: @"unknown error");
                }
                [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable refreshedSnapshot, NSError * _Nullable refreshError) {
                    if (refreshError || !refreshedSnapshot.exists) {
                        finishWithSnapshot(snapshot);
                        return;
                    }
                    finishWithSnapshot(refreshedSnapshot);
                }];
            }];
            return;
        }

        [threadRef setData:supportCreatePayload() completion:^(NSError * _Nullable createError) {
            if (createError) {
                if (completion) completion(nil, createError);
                return;
            }

            [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable createdSnapshot, NSError * _Nullable readError) {
                if (readError || !createdSnapshot.exists) {
                    finishWithSnapshot(nil);
                    return;
                }
                finishWithSnapshot(createdSnapshot);
            }];
        }];
    }];
}

- (void)pp_openSupportChatViaCloudFunctionWithCustomerID:(NSString *)customerID
                                              completion:(void (^)(NSString * _Nullable threadId, NSError * _Nullable error))completion
{
    NSURL *url = [NSURL URLWithString:@"https://us-central1-pure-pets-49199.cloudfunctions.net/openSupportChat"];
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"ChManager" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Invalid function URL"}]);
        return;
    }

    NSDictionary *payload = @{ @"customerId": customerID ?: @"" };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!jsonData || jsonError) {
        if (completion) completion(nil, jsonError);
        return;
    }

    [self pp_sendOpenSupportChatPayload:jsonData
                                    url:url
                    forceCredentialRefresh:NO
                             didRetryAuth:NO
                             completion:completion];
}

- (void)pp_sendOpenSupportChatPayload:(NSData *)jsonData
                                  url:(NSURL *)url
                 forceCredentialRefresh:(BOOL)forceCredentialRefresh
                           didRetryAuth:(BOOL)didRetryAuth
                             completion:(void (^)(NSString * _Nullable threadId, NSError * _Nullable error))completion
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    PPFirebaseSessionAuthorizationOptions options =
        PPFirebaseSessionAuthorizationOptionRequireSignedIn |
        PPFirebaseSessionAuthorizationOptionIncludeAppCheck;
    if (forceCredentialRefresh) {
        options |= PPFirebaseSessionAuthorizationOptionForceRefreshAuth;
        options |= PPFirebaseSessionAuthorizationOptionForceRefreshAppCheck;
    }

    [PPFirebaseSessionBridge authorizeRequest:request options:options completion:^(NSError * _Nullable authError) {
        if (authError) {
            if (!didRetryAuth && [PPFirebaseSessionBridge isAuthOrAppCheckError:authError]) {
                NSLog(@"⚠️ [SupportChat] Credential preflight failed before request. Retrying with forced refresh: %@",
                      authError.localizedDescription ?: @"unknown error");
                [self pp_sendOpenSupportChatPayload:jsonData
                                                url:url
                              forceCredentialRefresh:YES
                                       didRetryAuth:YES
                                         completion:completion];
                return;
            }
            NSLog(@"❌ [SupportChat] Credential preflight failed after retry=%d: %@",
                  didRetryAuth, authError.localizedDescription ?: @"unknown error");
            if (completion) completion(nil, authError);
            return;
        }

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                if (!didRetryAuth && [PPFirebaseSessionBridge isAuthOrAppCheckError:error]) {
                    [self pp_sendOpenSupportChatPayload:jsonData url:url forceCredentialRefresh:YES didRetryAuth:YES completion:completion];
                    return;
                }
                if (completion) completion(nil, error);
                return;
            }

            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            NSData *responseData = data ?: [NSData data];

            if (http.statusCode >= 400) {
                NSString *body = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                NSLog(@"❌ [SupportChat] Cloud Function returned %ld: %@", (long)http.statusCode, body ?: @"<no body>");
                NSDictionary *errorDict = nil;
                if (responseData.length > 0) {
                    errorDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
                }
                NSString *message = nil;
                if ([errorDict isKindOfClass:NSDictionary.class]) {
                    id directMessage = errorDict[@"message"];
                    id errorValue = errorDict[@"error"];
                    if ([directMessage isKindOfClass:NSString.class]) {
                        message = directMessage;
                    } else if ([errorValue isKindOfClass:NSString.class]) {
                        message = errorValue;
                    } else if ([errorValue isKindOfClass:NSDictionary.class] &&
                               [errorValue[@"message"] isKindOfClass:NSString.class]) {
                        message = errorValue[@"message"];
                    } else if ([errorValue isKindOfClass:NSDictionary.class] &&
                               [errorValue[@"status"] isKindOfClass:NSString.class]) {
                        message = errorValue[@"status"];
                    }
                }
                if (!message.length) message = kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now.";
                NSError *httpError = [NSError errorWithDomain:@"ChManager"
                                                         code:http.statusCode
                                                     userInfo:@{NSLocalizedDescriptionKey: message}];
                if (!didRetryAuth && [PPFirebaseSessionBridge isAuthOrAppCheckError:httpError]) {
                    [self pp_sendOpenSupportChatPayload:jsonData url:url forceCredentialRefresh:YES didRetryAuth:YES completion:completion];
                    return;
                }
                if (completion) completion(nil, [PPFirebaseSessionBridge publicErrorForError:httpError fallbackKey:@"pp_support_open_failed"]);
                return;
            }

            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            NSString *threadId = [result isKindOfClass:NSDictionary.class] ? ([result[@"threadId"] isKindOfClass:NSString.class] ? result[@"threadId"] : @"") : @"";

            if (!threadId.length) {
                NSError *responseError = [NSError errorWithDomain:@"ChManager"
                                                              code:500
                                                          userInfo:@{NSLocalizedDescriptionKey: kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now."}];
                if (completion) completion(nil, responseError);
                return;
            }

            if (completion) completion(threadId, nil);
        }];
        [task resume];
    }];
}

- (void)openSupportChatFromController:(UIViewController *)controller
{
    if (!controller) {
        return;
    }

    if (![FIRAuth auth].currentUser) {
        [UserManager showPromptOnTopController];
        return;
    }

    FIRFirestore *db = self.firestore ?: [FIRFirestore firestore];
    FIRDocumentReference *supportRef = [[db collectionWithPath:@"CommerceConfig"] documentWithPath:@"supportChat"];

    [supportRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        if (error) {
            NSLog(@"❌ [SupportChat] Failed to load support config: %@", error.localizedDescription);
            PPSupportPresentUnavailableAlert(controller, [PPFirebaseSessionBridge publicMessageForError:error fallbackKey:@"pp_support_config_failed"]);
            return;
        }

        UserModel *supportUser = PPSupportUserFromConfig(snapshot.data ?: @{});
        if (!supportUser) {
            NSLog(@"❌ [SupportChat] Missing supportUserId in CommerceConfig/supportChat");
            PPSupportPresentUnavailableAlert(controller, kLang(@"Support chat is not configured yet.") ?: @"Support chat is not configured yet.");
            return;
        }

        NSString *customerID = [FIRAuth auth].currentUser.uid ?: @"";
        if (customerID.length == 0) {
            [UserManager showPromptOnTopController];
            return;
        }

        [self pp_openSupportChatWithUser:supportUser customerID:customerID fromController:controller];
    }];
}


- (void)sendMessage:(ChatMessageModel *)msg
           inThread:(NSString *)threadID
           senderID:(NSString *)senderID
         completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *resolvedSenderID = [self pp_authenticatedUIDForRequestedUID:senderID];

    // ─────────────────────────────
    // 0️⃣ Validation
    // ─────────────────────────────
    if (!msg || threadID.length == 0 || resolvedSenderID.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([NSError errorWithDomain:@"ChManager"
                                                code:400
                                            userInfo:@{
                                                NSLocalizedDescriptionKey:
                                                @"Invalid message parameters"
                                            }]);
            });
        }
        return;
    }

    // Ensure ID & status
    if (!msg.ID.length) {
        msg.ID = NSUUID.UUID.UUIDString;
    }

    msg.senderID = resolvedSenderID;
    msg.status   = ChatMessageStatusSent;

    FIRFirestore *db = FIRFirestore.firestore;

    FIRDocumentReference *messageRef =
    [[[[db collectionWithPath:@"Chats"]
       documentWithPath:threadID]
      collectionWithPath:@"Messages"]
     documentWithPath:msg.ID];

    FIRDocumentReference *threadRef =
    [[db collectionWithPath:@"Chats"]
     documentWithPath:threadID];

    // ─────────────────────────────
    // 1️⃣ Optimistic local state
    // (UI must already reflect this)
    // ─────────────────────────────
    NSDictionary *messageData = [msg toDictionary];

    // ─────────────────────────────
    // 2️⃣ Write message (single source of truth)
    // ─────────────────────────────
    [messageRef setData:messageData
             completion:^(NSError * _Nullable error) {

        if (error) {
            NSLog(@"❌ [SendMessage] Message write failed — code=%ld domain=%@ desc=%@ info=%@",
                  (long)error.code, error.domain, error.localizedDescription, error.userInfo);

            // 🔍 Additional App Check diagnostic
            if ([error.domain isEqualToString:FIRFirestoreErrorDomain] &&
                error.code == FIRFirestoreErrorCodePermissionDenied) {
                NSLog(@"🔐 [SendMessage] PERMISSION_DENIED — possible App Check or security rules rejection on this device");
            }

            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(error);
                });
            }
            return;
        }

        // ─────────────────────────────
        // 3️⃣ Immediately mark as SENT
        // (prevents UI waiting for snapshot)
        // ─────────────────────────────
        __weak typeof(messageRef) messageRef = messageRef;
        [messageRef updateData:@{
            @"status": @(ChatMessageStatusSent),
            @"sentAt": [FIRFieldValue fieldValueForServerTimestamp]
        }];

        msg.status = ChatMessageStatusSent;

        // ─────────────────────────────
        // 4️⃣ Update parent thread (atomic + safe)
        // ─────────────────────────────
        NSString *lastMessageText = @"";

        switch (msg.messageType) {
            case ChatMessageTypeText:
                lastMessageText = msg.text ?: @"";
                break;
            case ChatMessageTypeAudio:
                lastMessageText = kLang(@"Audio message");
                break;
            case ChatMessageTypeImage:
                lastMessageText = kLang(@"Image");
                break;
            case ChatMessageTypeVideo:
                lastMessageText = kLang(@"Video");
                break;
            case ChatMessageTypeFile:
                lastMessageText = kLang(@"File");
                break;
            default:
                break;
        }

        [threadRef updateData:@{
            @"lastMessage": lastMessageText,
            @"senderID": resolvedSenderID,
            @"timestamp": [FIRFieldValue fieldValueForServerTimestamp],
            @"lastMessageAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"messagesCount": [FIRFieldValue fieldValueForIntegerIncrement:1]
        }];

        // ─────────────────────────────
        // 5️⃣ Push notification (fire-and-forget)
        // ─────────────────────────────
        if (msg.receiverID.length) {
            [self sendChatPushToUserID:msg.receiverID
                                 title:kLang(@"New Message")
                                  body:lastMessageText
                              threadID:threadID
                              senderID:resolvedSenderID
                             messageID:msg.ID
                            completion:^(BOOL didAcceptPush) {
                if (!didAcceptPush) return;
                [self markMessageAsDelivered:msg.ID threadID:threadID];
            }];
        }

        // ─────────────────────────────
        // 6️⃣ Completion (MAIN THREAD)
        // ─────────────────────────────
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }];
}



- (void)startGlobalIncomingMessageListenerForUser:(NSString *)userID
{
    NSString *resolvedUserID = [self pp_authenticatedUIDForRequestedUID:userID];
    if (!resolvedUserID.length) return;

    if (self.globalIncomingListener) {
        [self.globalIncomingListener remove];
    }

    // 🔐 Firestore Security Rules (best practices) for this collectionGroup query:
    // The client is querying:
    //   collectionGroup("Messages").where("receiverID" == myUID).where("status" == SENT)
    // You MUST enforce the same constraint server-side with Firestore rules.
    //
    // ✅ Recommended rules shape (paste into firestore.rules and adapt field names):
    //
    // rules_version = '2';
    // service cloud.firestore {
    //   match /databases/{database}/documents {
    //
    //     function signedIn() { return request.auth != null; }
    //     function uid() { return request.auth.uid; }
    //     function isAdmin() { return request.auth.token.role == 'admin'; } // optional custom-claims role
    //
    //     match /Chats/{threadId} {
    //       // Only members can read chat metadata
    //       allow read: if signedIn() && (uid() in resource.data.members);
    //     }
    //
    //     match /Chats/{threadId}/Messages/{messageId} {
    //       // Read: only sender or receiver can read a message
    //       allow get, list: if signedIn() &&
    //         (resource.data.senderID == uid() || resource.data.receiverID == uid());
    //
    //       // Create: sender can create messages only in threads they belong to,
    //       // and receiver must be another member of the same thread.
    //       allow create: if signedIn() &&
    //         request.resource.data.senderID == uid() &&
    //         (uid() in get(/databases/$(database)/documents/Chats/$(threadId)).data.members) &&
    //         (request.resource.data.receiverID in get(/databases/$(database)/documents/Chats/$(threadId)).data.members) &&
    //         request.resource.data.status == 0; // SENT on create (align with your enum)
    //
    //       // Update: receiver can advance status (SENT -> DELIVERED -> READ) and set timestamps.
    //       // Prevent edits to content fields.
    //       allow update: if signedIn() && (
    //         resource.data.receiverID == uid() || isAdmin()
    //       ) &&
    //       request.resource.data.diff(resource.data).changedKeys()
    //         .hasOnly(['status','deliveredAt','readAt']) &&
    //       request.resource.data.status >= resource.data.status;
    //
    //       // Delete: usually disallow (or restrict to admin tooling)
    //       allow delete: if false;
    //     }
    //   }
    // }
    //
    // ✅ Indexing: collectionGroup queries need a composite index for receiverID + status.
    // Firestore will prompt you with an index link if missing.
    //
    // ✅ Role model: prefer "membership" (members array on Chats) over broad roles.
    // Only use custom-claims roles (admin/support) for moderation tools.
    
    // U5: Limit unbounded chat query to 500 documents
    FIRQuery *query =
    [[[[[FIRFirestore firestore]
       collectionGroupWithID:@"Messages"]
      queryWhereField:@"receiverID" isEqualTo:resolvedUserID]
     queryWhereField:@"status" isEqualTo:@(ChatMessageStatusSent)]
     queryLimitedTo:500];

    NSLog(@"🔔 [GlobalIncoming] Listener started");
    __block BOOL didCompleteInitialSync = NO;

    // U4: Prevent retain cycle in global incoming listener
    __weak typeof(self) weakSelf = self;
    self.globalIncomingListener =
    [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error || !snapshot) {
            if (error) NSLog(@"⚠️ [GlobalIncoming] Listener error: %@", error.localizedDescription);
            return;
        }

        BOOL isInitialSync = !didCompleteInitialSync;

        for (FIRDocumentChange *change in snapshot.documentChanges) {

            if (change.type != FIRDocumentChangeTypeAdded) continue;

            NSString *threadID = change.document.reference.parent.parent.documentID;
            NSString *messageID = change.document.documentID;

            // Always advance to DELIVERED when receiver app observes SENT messages.
            // This runs for initial sync + incremental additions.
            [strongSelf markMessageAsDelivered:messageID threadID:threadID];

            // Suppress startup notification sounds for initial backlog.
            if (isInitialSync) continue;

            BOOL isChatOpen =
                strongSelf.activeThreadID.length &&
                [strongSelf.activeThreadID isEqualToString:threadID];

            if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
                !isChatOpen &&
                ![strongSelf.mutedThreadIDsStorage containsObject:threadID] &&
                !strongSelf.isHandlingNotificationHandoff) {

                NSLog(@"🔔 [GlobalIncoming] Sound fired");
                [ChManager playIncomingMessageFeedback];
            }
        }

        didCompleteInitialSync = YES;
    }];
}



// Refactored: syncPendingDeliveriesForUser:completion:
- (void)syncPendingDeliveriesForUser:(nullable NSString *)userID
                          completion:(nullable void (^)(void))completion
{
    // Always use authenticated UID to match Firestore security rules.
    NSString *resolvedUserID = [self pp_authenticatedUIDForRequestedUID:userID];

    if (resolvedUserID.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
        return;
    }

    NSLog(@"🔄 [DeliverySync] Checking pending deliveries for receiver=%@ ...", resolvedUserID);

    // NOTE:
    // - "Messages" is a SUBCOLLECTION under /Chats/{threadId}/Messages/{messageId}
    // - collectionGroup("Messages") is the correct way to query ALL Messages subcollections
    //   across ALL threads.
    // - Your security rules must enforce that only the authenticated receiver (and/or staff)
    //   can read these docs.

    FIRQuery *query =
    [[[[FIRFirestore firestore]
       collectionGroupWithID:@"Messages"]
      queryWhereField:@"receiverID" isEqualTo:resolvedUserID]
     queryWhereField:@"status" isEqualTo:@(ChatMessageStatusSent)];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ [DeliverySync] Query failed: %@", error.localizedDescription);

            // Helpful hint for the common permission failure
            // (e.g. auth not ready, user not a thread member, or rules too strict)
            if (error.code == FIRFirestoreErrorCodePermissionDenied) {
                NSLog(@"🚫 [DeliverySync] Permission denied. Ensure the user is authenticated and Firestore rules allow receiver to read Messages via collectionGroup.");
            }

            if (completion) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
            return;
        }

        if (snapshot.documents.count == 0) {
            NSLog(@"ℹ️ [DeliverySync] No pending deliveries.");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
            return;
        }

        // We already filtered status == SENT in the query, so we can update without
        // reading each document again.
        NSInteger updated = 0;

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            NSString *threadID = doc.reference.parent.parent.documentID;
            NSString *messageID = doc.documentID;

            if (threadID.length == 0 || messageID.length == 0) {
                continue;
            }

            FIRDocumentReference *ref =
            [[[[[FIRFirestore firestore]
               collectionWithPath:@"Chats"]
              documentWithPath:threadID]
             collectionWithPath:@"Messages"]
             documentWithPath:messageID];

            [ref updateData:@{
                @"status": @(ChatMessageStatusDelivered),
                @"deliveredAt": [FIRFieldValue fieldValueForServerTimestamp],
                @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
            } completion:^(NSError * _Nullable updateError) {
                if (updateError) {
                    NSLog(@"❌ [DeliverySync] Failed to mark delivered msg=%@ thread=%@: %@",
                          messageID, threadID, updateError.localizedDescription);
                }
            }];

            updated += 1;
        }

        NSLog(@"✅ [DeliverySync] Marked %ld message(s) as delivered.", (long)updated);

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }

    }];
}

+ (UIImage *)normalizedImage:(UIImage *)image
{
    if (!image) return nil;

    CGSize size = image.size;
    UIGraphicsImageRendererFormat *format =
        [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = image.scale;
    format.opaque = NO;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];

    UIImage *normalized =
        [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        }];

    return normalized;
}

- (void)startGlobalUnreadListenerForUser:(NSString *)userID
{
    NSString *resolvedUserID = [self pp_authenticatedUIDForRequestedUID:userID];
    if (!resolvedUserID.length) return;

    if (self.globalUnreadListener) {
        [self.globalUnreadListener remove];
    }

    FIRQuery *query =
    [[[[FIRFirestore firestore]
       collectionGroupWithID:@"Messages"]
      queryWhereField:@"receiverID" isEqualTo:resolvedUserID]
     queryWhereField:@"status"
          isLessThan:@(ChatMessageStatusRead)];

    NSLog(@"📡 Global unread listener started");

    __weak typeof(self) weakSelf = self;

    self.globalUnreadListener =
    [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) return;

        NSMutableDictionary *counts = [NSMutableDictionary dictionary];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSString *threadID = doc.reference.parent.parent.documentID;
            NSInteger c = [counts[threadID] integerValue];
            counts[threadID] = @(c + 1);
        }

        weakSelf.liveUnreadCounts = counts;

        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"UnreadCountsUpdated"
         object:nil];
    }];
}

/*
 const { onRequest } = require("firebase-functions/v2/https");
 const { logger } = require("firebase-functions/v2");
 const admin = require("firebase-admin");

 admin.initializeApp();

 exports.sendChatNotification = onRequest(
   { region: "us-central1", cors: true },
   async (req, res) => {
     // Set CORS headers
     res.set("Access-Control-Allow-Origin", "*");
     res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
     res.set("Access-Control-Allow-Headers", "Content-Type");

     // Handle preflight requests
     if (req.method === "OPTIONS") {
       return res.status(204).send("");
     }

     try {
       // Validate request method
       if (req.method !== "POST") {
         return res.status(405).json({ error: "Method not allowed" });
       }

       const { toUserId, title, body, threadId, senderId } = req.body;

       // Validate required parameters
       if (!toUserId || !threadId || !title || !body) {
         logger.warn("Missing required parameters", { body: req.body });
         return res.status(400).json({
           error: "Missing required parameters: toUserId, threadId, title, and body are required"
         });
       }

       // Optional: Add authentication check
       // const authHeader = req.headers.authorization;
       // if (!authHeader || !authHeader.startsWith("Bearer ")) {
       //   return res.status(401).json({ error: "Unauthorized" });
       // }

       // Get user document
       const userRef = admin.firestore().collection("UsersCol").doc(toUserId);
       const userSnap = await userRef.get();

       if (!userSnap.exists) {
         logger.info(`User not found: ${toUserId}`);
         return res.status(200).json({ success: true, message: "User not found" });
       }

       const userData = userSnap.data();
       const token = userData?.PPUserTokenID;

       if (!token) {
         logger.info(`No FCM token for user: ${toUserId}`);
         return res.status(200).json({ success: true, message: "No FCM token" });
       }

       // Get total unread count for all threads where user is receiver
       // This query needs to be efficient - consider caching or maintaining a counter
       const chatsQuery = await admin
         .firestore()
         .collectionGroup("Messages")
         .where("receiverID", "==", toUserId)
         .where("status", "in", [0, 1]) // Assuming: 0=sent, 1=delivered, 2=read
         .count()
         .get();

       const totalUnreadCount = chatsQuery.data().count;

       // Alternative: If you maintain an unread count per user in their document
       // const totalUnreadCount = userData.unreadCount || 0;

       // Prepare notification payload
       const message = {
         token,
         notification: {
           title: title.trim(),
           body: body.trim()
         },
         apns: {
           payload: {
             aps: {
               badge: totalUnreadCount,
               sound: "default",
               "content-available": 1
             }
           },
           headers: {
             "apns-priority": "10" // Immediate delivery
           }
         },
         android: {
           priority: "high",
           notification: {
             sound: "default",
             channelId: "chat_messages", // Create this channel in your Android app
             priority: "high"
           }
         },
         data: {
           threadId: threadId.toString(),
           senderId: senderId ? senderId.toString() : "",
           type: "chat",
           title: title.trim(),
           body: body.trim(),
           click_action: "FLUTTER_NOTIFICATION_CLICK"
         }
       };

       // Send notification
       const response = await admin.messaging().send(message);
       logger.info("Notification sent successfully", {
         messageId: response,
         toUserId,
         threadId,
         badgeCount: totalUnreadCount
       });

       return res.status(200).json({
         success: true,
         messageId: response,
         badgeCount: totalUnreadCount
       });

     } catch (error) {
       logger.error("Error sending notification:", error);
       
       // Check for specific FCM errors
       if (error.code === 'messaging/registration-token-not-registered') {
         // Token is no longer valid, remove it from user document
         try {
           await admin.firestore()
             .collection("UsersCol")
             .doc(toUserId)
             .update({ PPUserTokenID: admin.firestore.FieldValue.delete() });
           logger.info(`Removed invalid FCM token for user: ${toUserId}`);
         } catch (updateError) {
           logger.error("Failed to remove invalid token:", updateError);
         }
       }

       return res.status(500).json({
         success: false,
         error: error.message || "Internal server error"
       });
     }
   }
 );
 */
- (void)forceReloadThreads
{
    NSLog(@"🔄 [ChManager] forceReloadThreads BEGIN");

    // 1️⃣ Stop all listeners
    NSLog(@"🛑 [ChManager] Stopping ALL listeners");

    [self stopAllThreadMessageListeners];

    if (self.globalIncomingListener) {
        [self.globalIncomingListener remove];
        self.globalIncomingListener = nil;
        NSLog(@"🛑 [ChManager] GlobalIncomingListener removed");
    }

    if (self.globalUnreadListener) {
        [self.globalUnreadListener remove];
        self.globalUnreadListener = nil;
        NSLog(@"🛑 [ChManager] GlobalUnreadListener removed");
    }

    // 2️⃣ Reset state (CRITICAL)
    [self.initialSyncedThreads removeAllObjects];
    [self.knownMessageIDsByThread removeAllObjects];

    NSLog(@"♻️ [ChManager] Internal caches cleared");

    // 3️⃣ Restart observers
    NSString *myUserID = [self pp_authenticatedUIDForRequestedUID:UserManager.sharedManager.currentUser.ID];
    if (!myUserID.length) {
        NSLog(@"❌ [ChManager] forceReloadThreads aborted (no user)");
        return;
    }

    NSLog(@"▶️ [ChManager] Restarting observers for user=%@", myUserID);

    [self startGlobalIncomingMessageListenerForUser:myUserID];
    [self startGlobalUnreadListenerForUser:myUserID];

    NSLog(@"✅ [ChManager] forceReloadThreads DONE");
}



// --- PATCHED: startListeningForThreadMessages with thread-level initial sync tracking
- (void)startListeningForThreadMessages:(NSArray<ChatThreadModel *> *)threads
{
    NSLog(@"📡 [ChManager] startListeningForThreadMessages (PRODUCTION)");

    NSString *myUserID = [self pp_authenticatedUIDForRequestedUID:UserManager.sharedManager.currentUser.ID];
    if (!myUserID.length) {
        NSLog(@"❌ [ChManager] No current user — abort");
        return;
    }

    for (ChatThreadModel *thread in threads) {

        if (!thread.ID.length) continue;

        // 🔒 Prevent duplicate listeners
        if (self.threadMessageListeners[thread.ID]) {
            NSLog(@"⏭️ [ThreadListener] Already attached → %@", thread.ID);
            continue;
        }

        NSLog(@"🟢 [ThreadListener] Attaching → %@", thread.ID);

        // Init per-thread cache
        if (!self.knownMessageIDsByThread[thread.ID]) {
            self.knownMessageIDsByThread[thread.ID] = [NSMutableSet set];
        }

        FIRCollectionReference *messagesRef =
        [[[[FIRFirestore firestore]
           collectionWithPath:@"Chats"]
          documentWithPath:thread.ID]
         collectionWithPath:@"Messages"];

        FIRQuery *query =
        [messagesRef queryOrderedByField:@"timestamp"];

        __weak typeof(self) weakSelf = self;

        id<FIRListenerRegistration> listener =
        [query addSnapshotListener:^(FIRQuerySnapshot *snapshot,
                                     NSError *error) {

            if (error || !snapshot) {
                NSLog(@"❌ [ThreadListener] Error %@ → %@",
                      thread.ID, error.localizedDescription);
                return;
            }

            BOOL isInitialSync =
                ![weakSelf.initialSyncedThreads containsObject:thread.ID];

            if (isInitialSync) {
                NSLog(@"📥 [Thread %@] Initial snapshot (%lu docs)",
                      thread.ID, (unsigned long)snapshot.documents.count);
            }

            NSMutableSet *knownIDs =
                weakSelf.knownMessageIDsByThread[thread.ID];

            for (FIRDocumentChange *change in snapshot.documentChanges) {

                if (change.type != FIRDocumentChangeTypeAdded) continue;

                FIRDocumentSnapshot *doc = change.document;
                NSDictionary *data = doc.data;

                NSString *msgID = doc.documentID;
                NSString *senderID = data[@"senderID"];
                NSString *receiverID = data[@"receiverID"];
                NSInteger status = [data[@"status"] integerValue];

                // 🔁 Dedup
                if ([knownIDs containsObject:msgID]) {
                    continue;
                }
                [knownIDs addObject:msgID];

                BOOL isIncoming =
                    ![senderID isEqualToString:myUserID];

                BOOL isLocalWrite =
                    snapshot.metadata.hasPendingWrites &&
                    !isIncoming;

                BOOL isForActiveChat =
                    weakSelf.activeThreadID.length &&
                    [weakSelf.activeThreadID isEqualToString:thread.ID];

                // 🚫 Skip local optimistic writes
                if (isLocalWrite) {
                    continue;
                }

                // 📦 DELIVERY: mark receiver-side SENT messages as delivered,
                // including initial sync (covers pending backlog).
                if (isIncoming &&
                    status == ChatMessageStatusSent &&
                    [receiverID isEqualToString:myUserID]) {

                    NSLog(@"📦 [Delivery] msg=%@ thread=%@",
                          msgID, thread.ID);

                    [[ChManager sharedManager]
                     markMessageAsDelivered:msgID
                     threadID:thread.ID];
                }

                // 🚫 Skip initial sync side-effects after delivery update
                if (isInitialSync) {
                    continue;
                }

                // 🔔 SOUND (true new incoming only)
                if (!weakSelf.globalIncomingListener &&
                    isIncoming &&
                    !isForActiveChat &&
                    UIApplication.sharedApplication.applicationState ==
                        UIApplicationStateActive &&
                    !weakSelf.isHandlingNotificationHandoff &&
                    ![weakSelf.mutedThreadIDsStorage containsObject:thread.ID] &&
                    status < ChatMessageStatusRead) {

                    NSLog(@"🔔 [IncomingSound] thread=%@", thread.ID);
                    [ChManager playIncomingMessageFeedback];
                }
            }

            // ✅ Mark initial sync done ONCE
            if (isInitialSync) {
                [weakSelf.initialSyncedThreads addObject:thread.ID];
                NSLog(@"✅ [Thread %@] Initial sync DONE", thread.ID);
            }
        }];

        self.threadMessageListeners[thread.ID] = listener;
    }
}


- (void)createOrGetChatThreadWithUser:(UserModel *)user
                           completion:(void (^)(ChatThreadModel *thread, NSError *error))completion
{
    if (!user.ID.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"Chat"
                                                            code:400
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Invalid user"}]);
        return;
    }

    NSString *currentUserID = [self pp_authenticatedUIDForRequestedUID:UserManager.sharedManager.currentUser.ID];
    if (!currentUserID.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"Chat"
                                                code:401
                                            userInfo:@{NSLocalizedDescriptionKey:@"Missing authenticated user"}]);
        }
        return;
    }
    if ([currentUserID isEqualToString:user.ID]) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"Chat"
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey:@"Cannot start chat with yourself"}]);
        }
        return;
    }

    // 🔒 Deterministic thread ID (CRITICAL)
    NSString *a = currentUserID;
    NSString *b = user.ID;
    NSString *threadID =
        ([a compare:b] == NSOrderedAscending)
            ? [NSString stringWithFormat:@"%@_%@", a, b]
            : [NSString stringWithFormat:@"%@_%@", b, a];

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *threadRef =
        [[db collectionWithPath:@"Chats"] documentWithPath:threadID];

    // 🔒 Atomic creation (idempotent)
    [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot,
                                           NSError *error) {

        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        // Thread already exists
        if (snapshot.exists) {
            ChatThreadModel *thread =
                [[ChatThreadModel alloc] initWithDictionary:snapshot.data];
            thread.ID = snapshot.documentID;
            thread.otherUser = user;

            // 🔥 ENSURE LISTENER IS ATTACHED
            [[ChManager sharedManager] startListeningForThreadMessages:@[thread]];
            
            if (completion) completion(thread, nil);
            return;
        }

        // Thread does NOT exist → create ONCE
        NSDictionary *data = @{
            @"members": @[a, b],
            @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"lastMessage": @"",
            @"lastUpdated": [FIRFieldValue fieldValueForServerTimestamp],
            @"timestamp": [FIRFieldValue fieldValueForServerTimestamp],
            @"mutedBy": @[],
            @"binnedBy": @[],
            @"reportedBy": @[],
            @"reportCount": @(0)
        };

        [threadRef setData:data completion:^(NSError *err) {

            if (err) {
                if (completion) completion(nil, err);
                return;
            }

            ChatThreadModel *thread = [[ChatThreadModel alloc] init];
            thread.ID = threadID;
            thread.memberIDs = @[a, b];
            thread.timestamp = [NSDate date];
            thread.otherUser = user;
            // 🔥 ATTACH LISTENER IMMEDIATELY
            [[ChManager sharedManager] startListeningForThreadMessages:@[thread]];
            
            
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"UnreadCountsUpdated"
             object:nil];
            
            
            if (completion) completion(thread, nil);
        }];
    }];
}







- (_Nullable id<FIRListenerRegistration>) getListenerFromObserveChatThreadsForUserID:(NSString *)userID
                                completion:(void (^)(NSArray<ChatThreadModel *> *threads,
                                                     NSError * _Nullable error))completion
{
    NSString *resolvedUserID = [self pp_authenticatedUIDForRequestedUID:userID];
    if (resolvedUserID.length == 0) {
        if (completion) {
            completion(@[],
                       [NSError errorWithDomain:@"ChManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey:
                                                  @"Invalid userID"}]);
        }
        return nil;
    }
    NSArray<NSString *> *identityCandidates = [self pp_identityCandidatesForRequestedUID:userID];

    FIRCollectionReference *colRef =
        [self.firestore collectionWithPath:@"Chats"];

    FIRQuery *query =
        [[colRef queryWhereField:@"members" arrayContains:resolvedUserID]
         queryOrderedByField:@"timestamp"];

    NSLog(@"📡 [ChManager] Attaching chat threads listener for requested=%@ resolved=%@", userID, resolvedUserID);

    // U4: Prevent retain cycle in chat threads listener
    __weak typeof(self) weakSelf = self;
    id<FIRListenerRegistration> listener =
    [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot,
                                 NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
            NSLog(@"❌ [ChManager] Snapshot error: %@ (code=%ld, authUID=%@, requestedUserID=%@)",
                  error.localizedDescription,
                  (long)error.code,
                  authUID,
                  userID ?: @"");
            if (completion) completion(nil, error);
            return;
        }

        NSMutableArray<ChatThreadModel *> *results = [NSMutableArray array];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            ChatThreadModel *thread =
                [[ChatThreadModel alloc] initWithDictionary:doc.data];
            thread.ID = doc.documentID;
            // Recompute per-user flags in case current user changed
            thread.isMuted = [strongSelf pp_array:thread.mutedBy containsAnyIdentity:identityCandidates];
            thread.isBinned = [strongSelf pp_array:thread.binnedBy containsAnyIdentity:identityCandidates];
            thread.isReportedByMe = [strongSelf pp_array:thread.reportedBy containsAnyIdentity:identityCandidates];

            id msgCount = doc.data[@"messagesCount"];
            thread.messagesCount =
                [msgCount respondsToSelector:@selector(integerValue)]
                ? [msgCount integerValue]
                : 0;

            // Skip empty threads (no messages yet)
            if (thread.messagesCount == 0) {
                continue;
            }

            [results addObject:thread];
        }

        // Sort by last message time (latest first)
        NSArray *sorted =
        [results sortedArrayUsingComparator:^NSComparisonResult(ChatThreadModel *a,
                                                                ChatThreadModel *b) {
            NSDate *dateA = PPThreadActivityDate(a);
            NSDate *dateB = PPThreadActivityDate(b);
            NSComparisonResult cmp = [dateB compare:dateA];
            if (cmp != NSOrderedSame) return cmp;
            return [a.ID compare:b.ID];
        }];

        if (completion) {
            completion(sorted, nil);
        }
    }];

    return listener;
}

- (_Nullable id<FIRListenerRegistration>)observeChatThreadsWithUnreadCountsForUserID:(NSString *)userID
                                 completion:(void (^)(NSArray<ChatThreadModel *> *threads,
                                                      NSError * _Nullable error))completion
{
    NSString *resolvedUserID = [self pp_authenticatedUIDForRequestedUID:userID];
    if (resolvedUserID.length == 0) {
        if (completion) {
            completion(@[],
                       [NSError errorWithDomain:@"ChManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey:
                                                  @"Invalid userID"}]);
        }
        return nil;
    }
    NSArray<NSString *> *identityCandidates = [self pp_identityCandidatesForRequestedUID:userID];

    FIRCollectionReference *colRef =
        [self.firestore collectionWithPath:@"Chats"];

    FIRQuery *query =
        [[colRef queryWhereField:@"members" arrayContains:resolvedUserID]
         queryOrderedByField:@"timestamp"];

    NSLog(@"📡 [ChManager] Observing chat threads (+ unread) requested=%@ resolved=%@", userID, resolvedUserID);

    __weak typeof(self) weakSelf = self;
    id<FIRListenerRegistration> listener =
    [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot,
                                 NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
            NSLog(@"❌ [ChManager] Threads snapshot error: %@ (code=%ld, authUID=%@, requestedUserID=%@)",
                  error.localizedDescription,
                  (long)error.code,
                  authUID,
                  userID ?: @"");
            strongSelf.mutedThreadIDsStorage = [NSMutableSet set];
            if (completion) completion(nil, error);
            return;
        }

        if (!snapshot || snapshot.documents.count == 0) {
            strongSelf.mutedThreadIDsStorage = [NSMutableSet set];
            if (completion) completion(@[], nil);
            return;
        }

        NSMutableArray<ChatThreadModel *> *threads =
            [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        NSMutableSet<NSString *> *mutedSet = [NSMutableSet set];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            ChatThreadModel *thread =
                [[ChatThreadModel alloc] initWithDictionary:doc.data];
            thread.ID = doc.documentID;

            id msgCount = doc.data[@"messagesCount"];
            thread.messagesCount =
                [msgCount respondsToSelector:@selector(integerValue)]
                ? [msgCount integerValue]
                : 0;

            // Skip empty threads (design decision)
            if (thread.messagesCount == 0) {
                continue;
            }

            thread.isMuted = [strongSelf pp_array:thread.mutedBy containsAnyIdentity:identityCandidates];
            thread.isBinned = [strongSelf pp_array:thread.binnedBy containsAnyIdentity:identityCandidates];
            thread.isReportedByMe = [strongSelf pp_array:thread.reportedBy containsAnyIdentity:identityCandidates];

            if (thread.isMuted) {
                [mutedSet addObject:thread.ID];
            }

            [threads addObject:thread];
        }

        // 🔽 Sort newest first
        [threads sortUsingComparator:^NSComparisonResult(ChatThreadModel *a,
                                                         ChatThreadModel *b) {
            NSDate *dateA = PPThreadActivityDate(a);
            NSDate *dateB = PPThreadActivityDate(b);
            NSComparisonResult cmp = [dateB compare:dateA];
            if (cmp != NSOrderedSame) return cmp;
            return [a.ID compare:b.ID];
        }];

      
        for (ChatThreadModel *thread in threads) {
            NSNumber *count = [ChManager sharedManager].liveUnreadCounts[thread.ID];
            thread.unreadCount = count.integerValue;
        }

            strongSelf.mutedThreadIDsStorage = mutedSet;
            if (completion) {
                completion([threads copy], nil);
            }
      
    }];

    return listener;
}

- (NSSet<NSString *> *)mutedThreadIDs
{
    return [self.mutedThreadIDsStorage copy] ?: [NSSet set];
}
 

-(void)dealloc
{
    [self stopListening];
}

- (void)stopListening {
    if (self.listener) {
        [self.listener remove];
        self.listener = nil;
    }

    if (self.globalIncomingListener) {
        [self.globalIncomingListener remove];
        self.globalIncomingListener = nil;
    }

    if (self.globalUnreadListener) {
        [self.globalUnreadListener remove];
        self.globalUnreadListener = nil;
    }

    [self.liveUnreadCounts removeAllObjects];
}

 


#pragma mark - Media Send APIs

 

- (void)markMessageAsDelivered:(NSString *)messageID
                       threadID:(NSString *)threadID
{
    if (!messageID.length || !threadID.length) return;

    FIRDocumentReference *ref =
    [[[[[FIRFirestore firestore]
       collectionWithPath:@"Chats"]
      documentWithPath:threadID]
     collectionWithPath:@"Messages"] documentWithPath:messageID];

    [ref getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                     NSError * _Nullable error) {
        if (error || !snapshot.exists) return;

        NSInteger currentStatus = [snapshot.data[@"status"] integerValue];
        if (currentStatus >= ChatMessageStatusDelivered) return;

        [ref updateData:@{
            @"status": @(ChatMessageStatusDelivered),
            @"deliveredAt": [FIRFieldValue fieldValueForServerTimestamp]
        }];
    }];
}

- (void)markMessagesAsReadInThread:(NSString *)threadID
                          fromUser:(NSString *)senderID
{
    NSString *myUserID = [FIRAuth auth].currentUser.uid ?: UserManager.sharedManager.currentUser.ID;
    if (!threadID.length || !senderID.length || !myUserID.length) return;

    FIRCollectionReference *messagesRef =
    [[[[FIRFirestore firestore]
       collectionWithPath:@"Chats"]
      documentWithPath:threadID]
     collectionWithPath:@"Messages"];

    // ✅ Only messages SENT BY other user AND RECEIVED by me
    FIRQuery *query =
    [[[messagesRef queryWhereField:@"senderID" isEqualTo:senderID]
      queryWhereField:@"receiverID" isEqualTo:myUserID]
     queryWhereField:@"status" isLessThan:@(ChatMessageStatusRead)];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snap, NSError *error) {

        if (error) {
            NSLog(@"❌ [Read] Query failed: %@", error.localizedDescription);
            return;
        }

        if (snap.documents.count == 0) {
            NSLog(@"ℹ️ [Read] No unread messages to mark");
            return;
        }

        FIRWriteBatch *batch = [[FIRFirestore firestore] batch];

        for (FIRDocumentSnapshot *doc in snap.documents) {
            NSLog(@"✏️ [Read] Marking message %@ as READ", doc.documentID);

            NSInteger currentStatus = [doc.data[@"status"] integerValue];

            // 🔒 Enforce pipeline: must be Delivered before Read
            NSMutableDictionary *updates = [@{
                @"status": @(ChatMessageStatusRead),
                @"readAt": [FIRFieldValue fieldValueForServerTimestamp]
            } mutableCopy];

            if (currentStatus < ChatMessageStatusDelivered) {
                updates[@"deliveredAt"] = [FIRFieldValue fieldValueForServerTimestamp];
            }

            [batch updateData:updates forDocument:doc.reference];
        }

        [batch commitWithCompletion:^(NSError * _Nullable err) {
            if (err) {
                NSLog(@"❌ [Read] Batch commit failed: %@", err.localizedDescription);
            } else {
                NSLog(@"✅ [Read] Marked %lu messages as READ",
                      (unsigned long)snap.documents.count);
                 
            }
        }];
    }];
}


- (void)sendImageMessage:(UIImage *)image
                 message:(ChatMessageModel *)msg
                inThread:(NSString *)threadID
                progress:(void (^)(CGFloat progress))progress
              completion:(void (^)(NSError * _Nullable error))completion
{
    if (!image || !msg || !threadID.length) {
        if (completion) {
            completion([NSError errorWithDomain:@"ChManager"
                                            code:400
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                   @"Invalid image message params"}]);
        }
        return;
    }

    msg.isUploading = YES;
    msg.transferProgress = 0;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *imageData = UIImageJPEGRepresentation(image, 0.82);
        if (!imageData) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion([NSError errorWithDomain:@"ChManager"
                                                    code:500
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                           @"Failed to encode image"}]);
                });
            }
            return;
        }

        FIRStorageReference *ref =
            [[[FIRStorage storage] reference]
             child:[NSString stringWithFormat:@"chat_media/images/%@.jpg", msg.ID]];

        FIRStorageMetadata *metadata = [FIRStorageMetadata new];
        metadata.contentType = @"image/jpeg";
        msg.mimeType = metadata.contentType;
        FIRStorageUploadTask *task =
            [ref putData:imageData metadata:metadata];

        // 🔁 PROGRESS
        [task observeStatus:FIRStorageTaskStatusProgress
                    handler:^(FIRStorageTaskSnapshot *snap) {
            if (snap.progress.totalUnitCount <= 0) return;

            CGFloat p =
                (CGFloat)snap.progress.completedUnitCount /
                (CGFloat)snap.progress.totalUnitCount;

            msg.transferProgress = p;

            if (progress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(p);
                });
            }
        }];

        // ❌ FAILURE
        [task observeStatus:FIRStorageTaskStatusFailure
                    handler:^(FIRStorageTaskSnapshot *snap) {

            msg.isUploading = NO;
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(snap.error ?: [NSError errorWithDomain:@"ChManager"
                                                                 code:500
                                                             userInfo:nil]);
                });
            }
        }];

        // ✅ SUCCESS
        [task observeStatus:FIRStorageTaskStatusSuccess
                    handler:^(__unused FIRStorageTaskSnapshot *snap) {

            [ref downloadURLWithCompletion:^(NSURL *URL, NSError *error) {

                if (error || !URL) {
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(error);
                        });
                    }
                    return;
                }

                msg.fileURL = URL.absoluteString;
                msg.isUploading = NO;
                msg.transferProgress = 1.0;

                [self sendMessage:msg
                         inThread:threadID
                         senderID:msg.senderID
                       completion:^(NSError * _Nullable error) {

                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(error);
                        });
                    }
                }];
            }];
        }];
    });
}

- (void)uploadVideoThumbnail:(UIImage *)image
                     message:(ChatMessageModel *)msg
                  completion:(void (^)(NSString *thumbURL))completion
{
    if (!image || !msg) {
        completion(nil);
        return;
    }

    NSData *data = UIImageJPEGRepresentation(image, 0.75);
    if (!data) {
        completion(nil);
        return;
    }

    FIRStorageReference *ref =
        [[[FIRStorage storage] reference]
         child:[NSString stringWithFormat:@"chat_media/video_thumbnails/%@.jpg", msg.ID]];

    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"image/jpeg";
    FIRStorageUploadTask *task =
        [ref putData:data metadata:metadata];

    [task observeStatus:FIRStorageTaskStatusSuccess handler:^(FIRStorageTaskSnapshot *snap) {

        [ref downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
            completion(URL.absoluteString);
        }];
    }];
}


// Enhanced: uploadVideoThumbnail with logging and main-thread safety
- (void)uploadVideoThumbnail:(UIImage *)image
                   messageID:(NSString *)msgID
                  completion:(void (^)(NSString *thumbURL))completion
{
    NSLog(@"🖼️ [VideoThumb] START msgID=%@", msgID);

    if (!image || msgID.length == 0) {
        NSLog(@"❌ [VideoThumb] Invalid params image=%@ msgID=%@",
              image ? @"YES" : @"NO", msgID);
        if (completion) completion(nil);
        return;
    }

    NSData *data = UIImageJPEGRepresentation(image, 0.7);
    if (!data) {
        NSLog(@"❌ [VideoThumb] JPEG encode failed msgID=%@", msgID);
        if (completion) completion(nil);
        return;
    }

    NSLog(@"⬆️ [VideoThumb] Uploading (%lu bytes) msgID=%@",
          (unsigned long)data.length, msgID);

    FIRStorageReference *ref =
        [[[FIRStorage storage] reference]
         child:[NSString stringWithFormat:@"chat_media/video_thumbnails/%@.jpg", msgID]];

    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"image/jpeg";
    FIRStorageUploadTask *task =
        [ref putData:data metadata:metadata];

    [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snap) {
        NSLog(@"❌ [VideoThumb] Upload failed msgID=%@ error=%@",
              msgID, snap.error.localizedDescription);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }];

    [task observeStatus:FIRStorageTaskStatusSuccess handler:^(FIRStorageTaskSnapshot *snap) {

        NSLog(@"✅ [VideoThumb] Upload success msgID=%@", msgID);

        [ref downloadURLWithCompletion:^(NSURL *URL, NSError *error) {

            if (error || !URL) {
                NSLog(@"❌ [VideoThumb] URL fetch failed msgID=%@ error=%@",
                      msgID, error.localizedDescription);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil);
                    });
                }
                return;
            }

            NSLog(@"🔗 [VideoThumb] URL=%@ msgID=%@", URL.absoluteString, msgID);

            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(URL.absoluteString);
                });
            }
        }];
    }];
}


// Send a video message: uploads thumbnail (if any), then video, then writes to Firestore
- (void)sendVideoMessage:(NSURL *)videoURL
                 message:(ChatMessageModel *)msg
                inThread:(NSString *)threadID
              completion:(void (^)(NSError * _Nullable error))completion
{
    NSLog(@"🎬 [VideoSend] START id=%@", msg.ID);

    if (!videoURL || !msg || threadID.length == 0 || msg.senderID.length == 0) {
        NSError *err =
            [NSError errorWithDomain:@"ChManager"
                                code:400
                            userInfo:@{NSLocalizedDescriptionKey:
                                       @"Invalid video message params"}];
        if (completion) completion(err);
        return;
    }

    NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
    if (!videoData) {
        NSError *err =
            [NSError errorWithDomain:@"ChManager"
                                code:500
                            userInfo:@{NSLocalizedDescriptionKey:
                                       @"Failed to read local video data"}];
        if (completion) completion(err);
        return;
    }

    FIRStorageReference *videoRef =
        [[[FIRStorage storage] reference]
         child:[NSString stringWithFormat:@"chat_media/videos/%@.mp4", msg.ID]];

    msg.isUploading = YES;
    msg.transferProgress = 0;

    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"video/mp4";
    msg.mimeType = metadata.contentType;
    FIRStorageUploadTask *task =
        [videoRef putData:videoData metadata:metadata];

    [task observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snap) {
        msg.transferProgress =
            (CGFloat)snap.progress.completedUnitCount /
            (CGFloat)snap.progress.totalUnitCount;
    }];

    [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snap) {
        msg.isUploading = NO;
        if (completion) completion(snap.error);
    }];

    [task observeStatus:FIRStorageTaskStatusSuccess handler:^(FIRStorageTaskSnapshot *snap) {

        [videoRef downloadURLWithCompletion:^(NSURL *URL, NSError *error) {

            if (error || !URL) {
                if (completion) completion(error);
                return;
            }

            msg.fileURL = URL.absoluteString;
            msg.isUploading = NO;
            msg.transferProgress = 1.0;

            [self sendMessage:msg
                     inThread:threadID
                     senderID:msg.senderID
                   completion:^(NSError * _Nullable error) {

                if (completion) completion(error);
            }];
        }];
    }];
}

+ (CGFloat)heightForMessage:(NSString *)text onController:(ChMessagingController *)cont {
    UIFont *font = [UIFont systemFontOfSize:15];

    CGRect rect = [text boundingRectWithSize:CGSizeMake(MAX_BUBBLE_WIDTH(cont.view) - 20, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{NSFontAttributeName: font}
                                     context:nil];

    CGFloat verticalPadding = 20; // padding inside the cell (top + bottom + spacing)
    return ceil(rect.size.height) + verticalPadding;
}


- (void)setTyping:(BOOL)isTyping
         inThread:(NSString *)threadID
           byUser:(NSString *)userID
{
    if (!threadID || !userID) return;

    FIRDocumentReference *threadRef = [[FIRFirestore.firestore collectionWithPath:@"Chats"] documentWithPath:threadID];

    NSString *fieldPath = [NSString stringWithFormat:@"typingStatus.%@", userID];

    [threadRef updateData:@{fieldPath: @(isTyping)} completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to update typing status: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Typing status updated: %@ = %d", userID, isTyping);
        }
    }];
}
- (void)startListeningForOtherUserTypingInThread:(NSString *)threadID
                                      otherUser:(NSString *)otherUserID
                                     completion:(void (^)(BOOL isTyping))completion
{
    [self listenForOtherUserTypingInThread:threadID otherUser:otherUserID completion:completion];
}
// Listen for the typing status of the OTHER user in a thread
- (nullable id<FIRListenerRegistration>)listenForOtherUserTypingInThread:(NSString *)threadID
                                      otherUser:(NSString *)otherUserID
                                     completion:(void (^)(BOOL isTyping))completion
{
    if (threadID.length == 0 || otherUserID.length == 0) return nil;

    FIRDocumentReference *threadRef =
    [[self.firestore collectionWithPath:@"Chats"] documentWithPath:threadID];

    // Remove existing listener for safety
    id<FIRListenerRegistration> existing =
        self.presenceListeners[[NSString stringWithFormat:@"%@_%@", threadID, otherUserID]];
    if (existing) {
        [existing remove];
    }

    NSString *listenerKey = [NSString stringWithFormat:@"%@_%@", threadID, otherUserID];

    __weak typeof(self) weakSelf = self;
    id<FIRListenerRegistration> listener =
    [threadRef addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {

        if (error || !snapshot.exists) return;

        NSDictionary *typingStatus = snapshot.data[@"typingStatus"];
        if (![typingStatus isKindOfClass:[NSDictionary class]]) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            return;
        }

        BOOL isTyping = [typingStatus[otherUserID] boolValue];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(isTyping);
        });
    }];

    weakSelf.presenceListeners[listenerKey] = listener;
    return listener;
}

// Optional: Stop listening for the typing status of the other user in a thread
- (void)stopListeningForOtherUserTypingInThread:(NSString *)threadID
                                      otherUser:(NSString *)otherUserID
{
    NSString *key = [NSString stringWithFormat:@"%@_%@", threadID, otherUserID];
    id<FIRListenerRegistration> listener = self.presenceListeners[key];
    if (listener) {
        [listener remove];
        [self.presenceListeners removeObjectForKey:key];
    }
}

+ (NSString *)formattedLastSeen:(id)date {
    if (!date) return @"unknown";
    
    NSDate *targetDate = nil;
    
    // Check if it's a Firebase Timestamp
    if ([date isKindOfClass:[FIRTimestamp class]]) {
        targetDate = [date dateValue];
    }
    // Check if it's already an NSDate
    else if ([date isKindOfClass:[NSDate class]]) {
        targetDate = (NSDate *)date;
    }
    // Check if it's a string that can be converted
    else if ([date isKindOfClass:[NSString class]]) {
        // Try to parse from string if needed
        // Add your string-to-date parsing logic here
        return @"unknown";
    }
    else {
        return @"unknown";
    }
    
    if (!targetDate) return @"unknown";

    NSTimeInterval secondsAgo = [[NSDate date] timeIntervalSinceDate:targetDate];

    if (secondsAgo < 60) {
        return @"just now";
    } else if (secondsAgo < 3600) {
        NSInteger minutes = secondsAgo / 60;
        return [NSString stringWithFormat:@"%ld minute%@ ago", (long)minutes, minutes == 1 ? @"" : @"s"];
    } else if (secondsAgo < 86400) {
        NSInteger hours = secondsAgo / 3600;
        return [NSString stringWithFormat:@"%ld hour%@ ago", (long)hours, hours == 1 ? @"" : @"s"];
    } else {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        return [formatter stringFromDate:targetDate];
    }
}

- (void)setOnline:(BOOL)isOnline
         forUserID:(NSString *)userID
        completion:(void(^)(NSError * _Nullable error))completion
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser) {
        FIRDocumentReference *ref =
        [[self.firestore collectionWithPath:kPresenceCol] documentWithPath:userID];
        
        // Use server timestamp for lastSeen
        NSDictionary *data = @{
            @"uid": userID ?: @"",
            @"online": @(isOnline),
            @"lastSeen": [FIRFieldValue fieldValueForServerTimestamp],
            @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
        };
        
        NSLog(@"OnlineStatus ---- >>>>>> %@  ---- userID: %@ ",isOnline ? @"YES" : @"NO",userID);
        
        [ref setData:data merge:YES completion:^(NSError * _Nullable error) {
            if (completion) completion(error);
        }];
    }
}

- (void)updateLastSeenForUserID:(NSString *)userID
                    completion:(void(^)(NSError * _Nullable error))completion
{
    FIRDocumentReference *ref =
      [[self.firestore collectionWithPath:kPresenceCol] documentWithPath:userID];

    NSDictionary *data = @{
      @"uid": userID ?: @"",
      @"online": @NO,
      @"lastSeen":[FIRFieldValue fieldValueForServerTimestamp],
      @"updatedAt":[FIRFieldValue fieldValueForServerTimestamp]
    };

    [ref setData:data merge:YES completion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}
 

#pragma mark - Chat Push (Cloud Function)
- (void)sendChatPushToUserID:(NSString *)toUserID
                       title:(NSString *)title
                        body:(NSString *)body
                    threadID:(NSString *)threadID
                    senderID:(NSString *)senderID
{
    [self sendChatPushToUserID:toUserID
                         title:title
                          body:body
                      threadID:threadID
                      senderID:senderID
                     messageID:nil
                    completion:nil];
}

- (void)sendChatPushToUserID:(NSString *)toUserID
                       title:(NSString *)title
                        body:(NSString *)body
                    threadID:(NSString *)threadID
                    senderID:(NSString *)senderID
                   messageID:(nullable NSString *)messageID
                  completion:(void (^ _Nullable)(BOOL didAcceptPush))completion
{
    void (^finish)(BOOL) = ^(BOOL accepted) {
        if (!completion) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(accepted);
        });
    };

    // ─────────────────────────────
    // 1️⃣ Preconditions
    // ─────────────────────────────
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        NSLog(@"⚠️ [Push] Skipped — user not authenticated");
        finish(NO);
        return;
    }

    if (toUserID.length == 0 ||
        senderID.length == 0 ||
        threadID.length == 0) {

        NSLog(@"❌ [Push] Invalid params → to=%@ sender=%@ thread=%@",
              toUserID, senderID, threadID);
        finish(NO);
        return;
    }

    // Prevent self-push
    if ([toUserID isEqualToString:senderID]) {
        NSLog(@"ℹ️ [Push] Skipped — self message");
        finish(NO);
        return;
    }

    // ─────────────────────────────
    // 2️⃣ Endpoint + payload
    // ─────────────────────────────
    NSURL *url = [NSURL URLWithString:
        @"https://us-central1-pure-pets-49199.cloudfunctions.net/sendChatNotification"];
    if (!url) {
        NSLog(@"❌ [Push] Invalid function URL");
        finish(NO);
        return;
    }

    NSDictionary *payload = @{
        @"toUserId"  : toUserID,
        @"senderId"  : senderID,
        @"threadId"  : threadID,
        @"messageId" : messageID ?: @"",
        @"title"     : title ?: @"",
        @"body"      : body ?: @""
    };

    NSError *jsonError = nil;
    NSData *jsonData =
        [NSJSONSerialization dataWithJSONObject:payload
                                        options:0
                                          error:&jsonError];

    if (!jsonData || jsonError) {
        NSLog(@"❌ [Push] JSON error: %@", jsonError.localizedDescription);
        finish(NO);
        return;
    }

    __block void (^authorizeAndSendRequest)(BOOL forceAuthRefresh);
    authorizeAndSendRequest = ^(BOOL forceAuthRefresh) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        request.timeoutInterval = 15;
        request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        request.HTTPBody = jsonData;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        PPFirebaseSessionAuthorizationOptions options =
            PPFirebaseSessionAuthorizationOptionRequireSignedIn;
        if (forceAuthRefresh) {
            options |= PPFirebaseSessionAuthorizationOptionForceRefreshAuth;
        }

        [PPFirebaseSessionBridge authorizeRequest:request
                                          options:options
                                       completion:^(NSError * _Nullable authError) {
            if (authError) {
                NSLog(@"❌ [Push][Auth] Credential preparation failed after forceRefresh=%d: %@",
                      forceAuthRefresh,
                      authError.localizedDescription ?: @"unknown");
                authorizeAndSendRequest = nil;
                finish(NO);
                return;
            }

            NSURLSessionConfiguration *config =
                [NSURLSessionConfiguration ephemeralSessionConfiguration];
            NSURLSession *session =
                [NSURLSession sessionWithConfiguration:config];

            NSURLSessionDataTask *task =
            [session dataTaskWithRequest:request
                       completionHandler:^(NSData *data,
                                           NSURLResponse *response,
                                           NSError *error) {

                if (error) {
                    NSLog(@"❌ [Push][Network] %@", error.localizedDescription);
                    authorizeAndSendRequest = nil;
                    finish(NO);
                    return;
                }

                NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
                NSString *resp =
                    data ? [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding] : @"<no body>";

                if (http.statusCode == 401 && !forceAuthRefresh) {
                    NSLog(@"⚠️ [Push][Server] 401 received. Retrying once with refreshed Auth credentials.");
                    authorizeAndSendRequest(YES);
                    return;
                }

                if (http.statusCode != 200) {
                    NSLog(@"🚨 [Push][Server] %ld → %@",
                          (long)http.statusCode, resp);
                    authorizeAndSendRequest = nil;
                    finish(NO);
                    return;
                }

                NSLog(@"✅ [Push] Delivered → %@", resp);

                BOOL accepted = NO;
                if (data.length > 0) {
                    NSDictionary *json =
                        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    NSString *messageId = [json[@"messageId"] description];
                    accepted = messageId.length > 0;
                }
                authorizeAndSendRequest = nil;
                finish(accepted);
            }];

            [task resume];
        }];
    };

    // ─────────────────────────────
    // 4️⃣ Require Firebase ID token and retry once after a server 401
    // ─────────────────────────────
    authorizeAndSendRequest(NO);
}

 


#pragma mark - Chat Availability (Cloud Function HTTP)
#pragma mark - Chat Availability (Cloud Function HTTP)

- (void)checkChatAvailabilityForUser:(NSString *)toUserID
                          completion:(void (^)(BOOL available, NSString * _Nullable reason))completion
{
    if (toUserID.length == 0) {
        if (completion) completion(NO, @"invalid_uid");
        return;
    }

    NSURL *url = [NSURL URLWithString:
        @"https://us-central1-pure-pets-49199.cloudfunctions.net/checkChatAvailability"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15;

    NSDictionary *payload = @{
        @"uid": toUserID ?: @""
    };

    NSData *bodyData =
        [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    request.HTTPBody = bodyData;

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession]
     dataTaskWithRequest:request
     completionHandler:^(NSData * _Nullable data,
                         NSURLResponse * _Nullable response,
                         NSError * _Nullable error) {

        if (error) {
            NSLog(@"❌ [ChatAvailability][HTTP] Error: %@", error.localizedDescription);
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @"network_error");
                });
            }
            return;
        }

        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSString *responseString =
            [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        NSLog(@"📡 [ChatAvailability][HTTP] Status Code: %ld", (long)http.statusCode);
        NSLog(@"📨 [ChatAvailability][HTTP] Response: %@", responseString);

        NSDictionary *json =
            [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        BOOL available = [json[@"available"] boolValue];
        NSString *reason = json[@"reason"];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(available, reason);
            });
        }
    }];

    [task resume];
}
- (void)checkUserAvailabilityForUser:(NSString *)toUserID
                          completion:(void (^)(BOOL available, NSString * _Nullable reason))completion
{
    if (toUserID.length == 0) {
        if (completion) completion(NO, @"invalid_uid");
        return;
    }

    NSURL *url = [NSURL URLWithString:
        @"https://us-central1-pure-pets-49199.cloudfunctions.net/checkUserAvailability"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15;

    NSDictionary *payload = @{
        @"uid": toUserID ?: @""
    };

    NSData *bodyData =
        [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    request.HTTPBody = bodyData;

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession]
     dataTaskWithRequest:request
     completionHandler:^(NSData * _Nullable data,
                         NSURLResponse * _Nullable response,
                         NSError * _Nullable error) {

        if (error) {
            NSLog(@"❌ [ChatAvailability][HTTP] Error: %@", error.localizedDescription);
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @"network_error");
                });
            }
            return;
        }

        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSString *responseString =
            [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        NSLog(@"📡 [ChatAvailability][HTTP] Status Code: %ld", (long)http.statusCode);
        NSLog(@"📨 [ChatAvailability][HTTP] Response: %@", responseString);

        NSDictionary *json =
            [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        BOOL available = [json[@"available"] boolValue];
        NSString *reason = json[@"reason"];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(available, reason);
            });
        }
    }];

    [task resume];
}
- (void)getLocalUnreadCountsForUser:(NSString *)userID
                      fromChats:(NSArray<ChatThreadModel *> *)chatsArr
                     completion:(void (^)(NSArray<ChatThreadModel *> *countedChatsArr))completion {

     completion(chatsArr);

    
}
  

+ (void)playIncomingMessageFeedback
{
    // 1️⃣ Respect app foreground
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }
    
    [[PPChatFeedbackManager shared]
            playFeedbackForEvent:
                PPChatFeedbackEventIncomingOutsideChat];
   
}


- (void)stopAllThreadMessageListeners {
    for (id<FIRListenerRegistration> listener in self.threadMessageListeners.allValues) {
        [listener remove];
    }
    [self.threadMessageListeners removeAllObjects];
}

/*
 // Force parent chat doc to emit update
        FIRDocumentReference *threadRef = [[[FIRFirestore firestore]
                                             collectionWithPath:@"Chats"]
                                             documentWithPath:threadID];
        [threadRef updateData:@{@"lastReadAt": [FIRTimestamp timestamp]}];
 

 */
- (void)deleteChatThreadWithID:(NSString *)threadID
                    completion:(void (^)(NSError * _Nullable error))completion {
    FIRDocumentReference *chatDoc = [[self.firestore collectionWithPath:@"Chats"] documentWithPath:threadID];
    
    [chatDoc deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)muteThreadWithID:(NSString *)threadID
                 muted:(BOOL)muted
             completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *myUID = [FIRAuth auth].currentUser.uid ?: UserManager.sharedManager.currentUser.ID ?: @"";
    if (!threadID.length || !myUID.length) {
        if (completion) completion([NSError errorWithDomain:@"ChManager"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Invalid params"}]);
        return;
    }
    FIRDocumentReference *ref =
    [[self.firestore collectionWithPath:@"Chats"] documentWithPath:threadID];
    id value = muted
        ? [FIRFieldValue fieldValueForArrayUnion:@[myUID]]
        : [FIRFieldValue fieldValueForArrayRemove:@[myUID]];

    [ref updateData:@{@"mutedBy": value}
         completion:^(NSError * _Nullable error) {
        if (!error) {
            if (muted) {
                [self.mutedThreadIDsStorage addObject:threadID];
            } else {
                [self.mutedThreadIDsStorage removeObject:threadID];
            }
        }
        if (completion) completion(error);
    }];
}

- (void)binThreadWithID:(NSString *)threadID
                binned:(BOOL)binned
            completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *myUID = [FIRAuth auth].currentUser.uid ?: UserManager.sharedManager.currentUser.ID ?: @"";
    if (!threadID.length || !myUID.length) {
        if (completion) completion([NSError errorWithDomain:@"ChManager"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Invalid params"}]);
        return;
    }
    FIRDocumentReference *ref =
    [[self.firestore collectionWithPath:@"Chats"] documentWithPath:threadID];
    id value = binned
        ? [FIRFieldValue fieldValueForArrayUnion:@[myUID]]
        : [FIRFieldValue fieldValueForArrayRemove:@[myUID]];

    [ref updateData:@{@"binnedBy": value}
         completion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)reportThread:(ChatThreadModel *)thread
              reason:(nullable NSString *)reason
          completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *myUID = [FIRAuth auth].currentUser.uid ?: UserManager.sharedManager.currentUser.ID ?: @"";
    if (!thread.ID.length || !myUID.length) {
        if (completion) completion([NSError errorWithDomain:@"ChManager"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Invalid params"}]);
        return;
    }
    if ([thread.reportedBy containsObject:myUID]) {
        if (completion) completion(nil);
        return;
    }

    // Mark reported on thread (idempotent)
    FIRDocumentReference *threadRef =
    [[self.firestore collectionWithPath:@"Chats"] documentWithPath:thread.ID];
    [threadRef updateData:@{
        @"reportedBy": [FIRFieldValue fieldValueForArrayUnion:@[myUID]],
        @"reportCount": [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    }];

    // Create / upsert report doc
    NSString *reportID = [NSString stringWithFormat:@"%@_%@", thread.ID, myUID];
    FIRDocumentReference *reportRef =
    [[self.firestore collectionWithPath:@"ChatReports"] documentWithPath:reportID];

    UserModel *otherUser = [ChatThreadModel resolveOtherUserFromThread:thread];
    NSDictionary *clientInfo = @{
        @"platform": @"ios",
        @"osVersion": UIDevice.currentDevice.systemVersion ?: @"",
        @"locale": NSLocale.currentLocale.localeIdentifier ?: @"",
        @"timeZone": NSTimeZone.localTimeZone.name ?: @"",
        @"appVersion": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
        @"appBuild": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @""
    };

    NSDictionary *analysis = @{
        @"clientTags": @[@"user_report"],
        @"messageCount": @(thread.messagesCount),
        @"lastMessageLength": @(thread.lastMessage.length),
        @"source": @"client"
    };

    NSMutableDictionary *payload = [@{
        @"reportId": reportID,
        @"threadId": thread.ID ?: @"",
        @"reporterId": myUID,
        @"reportedUserId": otherUser.ID ?: @"",
        @"memberIDs": thread.memberIDs ?: @[],
        @"reason": reason ?: @"",
        @"status": @"pending",
        @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp],
        @"lastMessage": thread.lastMessage ?: @"",
        @"messagesCount": @(thread.messagesCount),
        @"client": clientInfo,
        @"analysis": analysis
    } mutableCopy];

    if (thread.lastMessageAt) {
        payload[@"lastMessageAt"] = thread.lastMessageAt;
    }

    [reportRef setData:payload merge:YES completion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

// MARK: - startChatWith SelectUser
- (void)startChatWith:(UserModel *)user fromController:(UIViewController *)controller {
    //NSString *userID = UserManager.sharedManager.currentUser.ID;
    
    [ChManager.sharedManager createOrGetChatThreadWithUser:user completion:^(ChatThreadModel * _Nullable thread, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to create chat thread: %@", error.localizedDescription);
            return;
        }
        
        // Push chat messaging controller
        ChMessagingController *chatVC = [[ChMessagingController alloc] initWithChatThread:thread];
        [PPFunc presentSheetFrom:controller
                         sheetVC:chatVC
                     detentStyle:PPSheetDetentStyleSemiLargAndLarge];
    }];
    
}


//// END OF ONLINE
///
///



+ (void)setOnline:(BOOL)online orText:(NSString *)TXT onLabel:(UILabel *)label{
    if (online) {
        NSTextAttachment *dotAttachment = [[NSTextAttachment alloc] init];
        dotAttachment.bounds = CGRectMake(0, -2, 8, 8);
        dotAttachment.image = [self createCircleWithColor:UIColor.systemGreenColor size:8];

        NSAttributedString *dotString = [NSAttributedString attributedStringWithAttachment:dotAttachment];
        NSMutableAttributedString *status = [[NSMutableAttributedString alloc] initWithAttributedString:dotString];
        [status appendAttributedString:[[NSAttributedString alloc] initWithString:kLang(@"Online")  attributes:@{NSFontAttributeName: label.font}]];

    label.attributedText = status;
    } else {
        label.text = TXT;
    }
}


+ (UIImage *)createCircleWithColor:(UIColor *)color size:(CGFloat)size {
    CGRect rect = CGRectMake(0, 0, size, size);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
+ (void)fetchThreadWithID:(NSString *)threadID
               completion:(ChThreadFetchCompletion)completion {

    if (threadID.length == 0) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];

    [[[db collectionWithPath:@"Chats"]
      documentWithPath:threadID]
     getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {

        if (error || !snapshot.exists) {
            NSLog(@"❌ [ChatThread] Fetch failed: %@", error.localizedDescription);
            if (completion) completion(nil);
            return;
        }
        
    
        ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:snapshot.data];
        thread.ID = snapshot.documentID;
 

        if (completion) completion(thread);
    }];
}

+ (void)chatWith:(UserModel *)user FromController:(UIViewController *)controller
{
    //NSLog(@"Selected user for new chat: %@", user.UserName);

        [[ChManager sharedManager] createOrGetChatThreadWithUser:user completion:^(ChatThreadModel * _Nullable chatThread, NSError * _Nullable error) {
            if (error) {
                //NSLog(@"❌ Failed to create chat thread: %@", error.localizedDescription);
                return;
            }

            // Push chat messaging controller
            ChMessagingController *chatVC = [[ChMessagingController alloc] initWithChatThread:chatThread];
            [PPFunc presentSheetFrom:controller
                             sheetVC:chatVC
                         detentStyle:PPSheetDetentStyleSemiLargAndLarge];
        }];
}
@end
/*
 
 - (void)sendChatPushToUserID:(NSString *)toUserID
                        title:(NSString *)title
                         body:(NSString *)body
                     threadID:(NSString *)threadID
                     senderID:(NSString *)senderID
 {
     FIRUser *authUser = [FIRAuth auth].currentUser;
     if (!authUser) {
         NSLog(@"⚠️ [Chat] Push skipped — Firebase user not authenticated");
         return;
     }

     if (toUserID.length == 0 || threadID.length == 0) {
         NSLog(@"❌ [Chat] Invalid push parameters");
         return;
     }
     
     NSURL *url = [NSURL URLWithString:
     @"https://us-central1-pure-pets-49199.cloudfunctions.net/sendChatNotification"];

     NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
     request.HTTPMethod = @"POST";
     request.timeoutInterval = 15;

     NSDictionary *payload = @{
         @"toUserId": toUserID ?: @"",
         @"title": title ?: @"",
         @"body": body ?: @"",
         @"threadId": threadID ?: @"",
         @"senderId": senderID ?: @""
     };

     NSData *bodyData =
         [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
     request.HTTPBody = bodyData;

     [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

     NSURLSessionDataTask *task =
     [[NSURLSession sharedSession]
      dataTaskWithRequest:request
      completionHandler:^(NSData * _Nullable data,
                          NSURLResponse * _Nullable response,
                          NSError * _Nullable error) {

         NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;

         if (error) {
             NSLog(@"❌ [Chat][HTTP] Error: %@", error.localizedDescription);
             return;
         }

         NSString *responseString =
             [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

         NSLog(@"📡 [Chat][HTTP] Status Code: %ld", (long)http.statusCode);
         NSLog(@"📨 [Chat][HTTP] Response: %@", responseString);
     }];

     [task resume];
     
 }
 */
