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
@import FirebaseAuth;
static NSString * const PURE_PETS_OFFICIAL_USER_ID = @"PUIDPOFFICILAL20262214";
static NSString * const kPPSupportOfficialActorKey = @"support:official";
static NSString * const kPPChatNotificationsPreferenceKey = @"notificationsSet";
static NSString * const kPPMessagesPrivacyPreferenceKey = @"messagesPrivacyValue";
@import Firebase;
@import FirebaseFirestore;
@import FirebaseStorage;
@import FirebaseFunctions;
#import "ChManager.h"
#import "PPChatFeedbackManager.h"
#import <UIKit/UIKit.h>
#import "PPOverlayCoordinator.h"
#import "UserManager.h"
#import "UserModel.h"
#import "PPFirebaseSessionBridge.h"
#import "PPAlertHelper.h"
#import "PPInAppChatNotificationPresenter.h"

static BOOL PPChatAlertsAllowed(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL notificationsEnabled = YES;
    if ([defaults objectForKey:kPPChatNotificationsPreferenceKey]) {
        notificationsEnabled = [defaults boolForKey:kPPChatNotificationsPreferenceKey];
    }
    BOOL allowsIncomingConversations =
        [defaults integerForKey:kPPMessagesPrivacyPreferenceKey] != 1;
    return notificationsEnabled && allowsIncomingConversations;
}

static NSDate *PPThreadActivityDate(ChatThreadModel *thread) {
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return [NSDate distantPast];
    }
    NSDate *lastMessageAt = thread.lastMessageAt;
    NSDate *timestamp = thread.timestamp;

    BOOL hasValidLast = lastMessageAt && ![lastMessageAt isEqual:[NSDate distantPast]];
    BOOL hasValidTs   = timestamp && ![timestamp isEqual:[NSDate distantPast]];

    if (hasValidLast && hasValidTs) {
        return ([lastMessageAt compare:timestamp] == NSOrderedAscending) ? timestamp : lastMessageAt;
    }
    if (hasValidLast) return lastMessageAt;
    if (hasValidTs)   return timestamp;

    return [NSDate distantPast];
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

static NSString *PPSupportUserActorKey(NSString *uid) {
    NSString *safeUID = PPSupportTrimmedString(uid);
    return safeUID.length > 0 ? [NSString stringWithFormat:@"user:%@", safeUID] : @"";
}

static BOOL PPSupportArrayContainsString(id value, NSString *needle) {
    NSString *safeNeedle = PPSupportTrimmedString(needle);
    if (![value isKindOfClass:NSArray.class] || safeNeedle.length == 0) {
        return NO;
    }
    for (id candidate in (NSArray *)value) {
        if ([PPSupportTrimmedString(candidate) isEqualToString:safeNeedle]) {
            return YES;
        }
    }
    return NO;
}

static BOOL PPSupportThreadDataCanAcceptCustomerMessage(NSDictionary *data,
                                                        NSString *customerID,
                                                        NSString *supportUserID) {
    if (![data isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSString *safeCustomerID = PPSupportTrimmedString(customerID);
    NSString *safeSupportUserID = PPSupportTrimmedString(supportUserID).length > 0
        ? PPSupportTrimmedString(supportUserID)
        : PURE_PETS_OFFICIAL_USER_ID;
    if (safeCustomerID.length == 0 || safeSupportUserID.length == 0) {
        return NO;
    }

    BOOL hasCustomerUID = PPSupportArrayContainsString(data[@"participantUids"], safeCustomerID) ||
        PPSupportArrayContainsString(data[@"members"], safeCustomerID);
    BOOL hasSupportUID = PPSupportArrayContainsString(data[@"participantUids"], safeSupportUserID) ||
        PPSupportArrayContainsString(data[@"members"], safeSupportUserID);
    BOOL hasCustomerActor = PPSupportArrayContainsString(data[@"participantKeys"], PPSupportUserActorKey(safeCustomerID));
    BOOL hasSupportActor = PPSupportArrayContainsString(data[@"participantKeys"], kPPSupportOfficialActorKey);

    return hasCustomerUID && hasSupportUID && hasCustomerActor && hasSupportActor;
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
                            [PPAlertHelper showErrorIn:retry
                                                 title:(kLang(@"Support") ?: @"Support")
                                              subtitle:(message.length ? message : (kLang(@"Support chat is temporarily unavailable.") ?: @"Support chat is temporarily unavailable."))];
                        }
                    });
                }
                return;
            }

            [PPAlertHelper showErrorIn:presenter
                                 title:(kLang(@"Support") ?: @"Support")
                              subtitle:(message.length ? message : (kLang(@"Support chat is temporarily unavailable.") ?: @"Support chat is temporarily unavailable."))];
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
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<FIRListenerRegistration>> *activeMessageListeners;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *knownMessageIDsByThread;
@property (nonatomic, assign) BOOL didFinishInitialMessageSync;
@property (nonatomic, strong) NSMutableSet<NSString *> *initialSyncedThreads;
@property (nonatomic, strong) NSCache<NSString *, NSNumber *> *supportThreadClassificationCache;
//@property (nonatomic, strong) id<FIRListenerRegistration> globalDeliveryListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> globalIncomingListener;
@property (nonatomic, copy, nullable) NSString *globalIncomingListenerUserID;
@property (nonatomic, copy, nullable) NSString *globalUnreadListenerUserID;
@property (nonatomic, copy, nullable) NSString *deliverySyncInFlightUserID;
@property (nonatomic, copy, nullable) NSString *lastDeliverySyncUserID;
@property (nonatomic, strong, nullable) NSDate *lastDeliverySyncCompletedAt;

- (void)pp_invokeChatCallableNamed:(NSString *)callableName
                           payload:(NSDictionary *)payload
                        completion:(void (^)(NSDictionary * _Nullable data,
                                             NSError * _Nullable error))completion;
- (void)pp_invokeChatCommandForThreadID:(NSString *)threadID
                                  action:(NSString *)action
                                 payload:(nullable NSDictionary *)payload
                              completion:(void (^)(NSDictionary * _Nullable data,
                                                   NSError * _Nullable error))completion;

- (void)pp_presentForegroundChatNotificationForThreadID:(NSString *)threadID
                                                message:(ChatMessageModel *)message
                                         receiverUserID:(NSString *)receiverUserID;

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
        sharedInstance.activeMessageListeners = [NSMutableDictionary dictionary];
        if (!sharedInstance.knownMessageIDsByThread) {
            sharedInstance.knownMessageIDsByThread = [NSMutableDictionary dictionary];
        }        sharedInstance.didFinishInitialMessageSync = NO;
        sharedInstance.initialSyncedThreads = [NSMutableSet set];
        sharedInstance.supportThreadClassificationCache = [NSCache new];
        sharedInstance.supportThreadClassificationCache.countLimit = 200;
        
        sharedInstance.liveUnreadCounts = [NSMutableDictionary dictionary];
        sharedInstance.latestUnreadMessages = [NSMutableDictionary dictionary];
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

- (void)pp_invokeChatCallableNamed:(NSString *)callableName
                           payload:(NSDictionary *)payload
                        completion:(void (^)(NSDictionary * _Nullable data,
                                             NSError * _Nullable error))completion
{
    NSString *safeName = PPSupportTrimmedString(callableName);
    if (safeName.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"ChManager"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                            kLang(@"SomethingWentWrong")}]);
        }
        return;
    }

    FIRHTTPSCallable *callable =
        [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:safeName];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:payload ?: @{}
                  completion:^(FIRHTTPSCallableResult * _Nullable result,
                               NSError * _Nullable error) {
        NSDictionary *data = [result.data isKindOfClass:NSDictionary.class]
            ? (NSDictionary *)result.data
            : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(data, error);
        });
    }];
}

- (void)pp_invokeChatCommandForThreadID:(NSString *)threadID
                                  action:(NSString *)action
                                 payload:(nullable NSDictionary *)payload
                              completion:(void (^)(NSDictionary * _Nullable data,
                                                   NSError * _Nullable error))completion
{
    NSString *safeThreadID = PPSupportTrimmedString(threadID);
    NSString *safeAction = PPSupportTrimmedString(action);
    if (safeThreadID.length == 0 || safeAction.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"ChManager"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                            kLang(@"SomethingWentWrong")}]);
        }
        return;
    }

    NSNumber *cachedSupport = [self.supportThreadClassificationCache objectForKey:safeThreadID];
    void (^invokeForClassification)(BOOL) = ^(BOOL supportThread) {
        [self.supportThreadClassificationCache setObject:@(supportThread) forKey:safeThreadID];
        NSMutableDictionary *command = [payload mutableCopy] ?: [NSMutableDictionary dictionary];
        command[@"action"] = safeAction;
        command[@"threadId"] = safeThreadID;
        [self pp_invokeChatCallableNamed:(supportThread ? @"supportChatCommand" : @"chatMessageCommand")
                                 payload:command.copy
                              completion:completion];
    };
    if (cachedSupport) {
        invokeForClassification(cachedSupport.boolValue);
        return;
    }

    FIRDocumentReference *threadRef =
        [[self.firestore collectionWithPath:@"Chats"] documentWithPath:safeThreadID];
    [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                           NSError * _Nullable readError) {
        if (readError || !snapshot.exists) {
            NSError *resolvedError = readError ?: [NSError errorWithDomain:@"ChManager"
                                                                       code:404
                                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                                                  kLang(@"SomethingWentWrong")}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, resolvedError);
            });
            return;
        }
        NSDictionary *threadData = snapshot.data ?: @{};
        BOOL supportThread = [threadData[@"supportThread"] boolValue] ||
            [PPSupportTrimmedString(threadData[@"conversationType"]) isEqualToString:@"support"] ||
            [PPSupportTrimmedString(threadData[@"conversationType"]) isEqualToString:@"user_support"] ||
            [PPSupportTrimmedString(threadData[@"threadType"]) isEqualToString:@"support"];
        invokeForClassification(supportThread);
    }];
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
                NSString *message = readError
                    ? [PPFirebaseSessionBridge publicMessageForError:readError fallbackKey:@"pp_support_open_failed"]
                    : (kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now.");
                PPSupportPresentUnavailableAlert(strongController, message);
                return;
            }

            NSDictionary *threadData = snapshot.data ?: @{};
            if (!PPSupportThreadDataCanAcceptCustomerMessage(threadData, customerID, PURE_PETS_OFFICIAL_USER_ID)) {
                NSLog(@"❌ [SupportChat] Server-created thread is missing canonical participants");
                PPSupportPresentUnavailableAlert(
                    strongController,
                    kLang(@"pp_support_open_failed") ?: @"Could not open support chat right now."
                );
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

- (void)pp_openSupportChatViaCloudFunctionWithCustomerID:(NSString *)customerID
                                              completion:(void (^)(NSString * _Nullable threadId, NSError * _Nullable error))completion
{
    NSString *safeCustomerID = PPSupportTrimmedString(customerID);
    if (safeCustomerID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"ChManager"
                                                 code:401
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                            kLang(@"pp_support_open_failed")}]);
        }
        return;
    }

    [self pp_invokeChatCallableNamed:@"supportChatCommand"
                             payload:@{
                                 @"action": @"create_or_get",
                                 @"sourceApp": @"user_ios",
                                 @"sourcePlatform": @"ios",
                             }
                          completion:^(NSDictionary * _Nullable data,
                                       NSError * _Nullable error) {
        NSString *threadId = PPSupportTrimmedString(data[@"threadId"]);
        if (completion) completion(threadId.length > 0 ? threadId : nil, error);
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
            PPSupportPresentUnavailableAlert(controller, kLang(@"pp_support_config_failed"));
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
    NSString *resolvedReceiverID = msg.receiverID ?: @"";
    if (!msg ||
        threadID.length == 0 ||
        resolvedSenderID.length == 0 ||
        resolvedReceiverID.length == 0 ||
        [resolvedReceiverID isEqualToString:resolvedSenderID]) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([NSError errorWithDomain:@"ChManager"
                                                code:400
                                            userInfo:@{
                                                NSLocalizedDescriptionKey:
                                                kLang(@"chat_invalid_message_parameters")
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

    NSMutableDictionary *serverMessage = [[msg toDictionary] mutableCopy];
    [serverMessage removeObjectsForKeys:@[
        @"ID", @"id", @"senderID", @"receiverID", @"timestamp",
        @"createdAt", @"status", @"read", @"readBy", @"hiddenFrom"
    ]];
    if (msg.fileURL.length > 0 || msg.thumbnailURL.length > 0) {
        serverMessage[@"mediaThreadId"] = threadID;
    }

    BOOL isSupportMessage = [resolvedReceiverID isEqualToString:PURE_PETS_OFFICIAL_USER_ID];
    NSDictionary *payload = @{
        @"action": isSupportMessage ? @"send_customer_message" : @"send",
        @"threadId": threadID,
        @"messageId": msg.ID,
        @"receiverID": resolvedReceiverID,
        @"text": msg.text ?: @"",
        @"sourceApp": @"user_ios",
        @"sourcePlatform": @"ios",
        @"message": serverMessage.copy,
    };
    NSString *callableName = isSupportMessage ? @"supportChatCommand" : @"chatMessageCommand";
    [self pp_invokeChatCallableNamed:callableName
                             payload:payload
                          completion:^(__unused NSDictionary * _Nullable data,
                                       NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ [ChatSend] Callable failed — code=%ld domain=%@",
                  (long)error.code,
                  error.domain ?: @"");
            if (completion) completion(error);
            return;
        }

        msg.status = ChatMessageStatusSent;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"forceReloadThreads" object:nil];
        if (completion) completion(nil);
    }];
}
- (void)pp_presentForegroundChatNotificationForThreadID:(NSString *)threadID
                                                message:(ChatMessageModel *)message
                                         receiverUserID:(NSString *)receiverUserID
{
    if (threadID.length == 0 || !message) {
        return;
    }

    if (receiverUserID.length > 0 &&
        message.senderID.length > 0 &&
        [message.senderID isEqualToString:receiverUserID]) {
        return;
    }

    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
        !PPChatAlertsAllowed() ||
        self.isHandlingNotificationHandoff ||
        [self.mutedThreadIDsStorage containsObject:threadID] ||
        (self.activeThreadID.length && [self.activeThreadID isEqualToString:threadID])) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [ChManager fetchThreadWithID:threadID completion:^(ChatThreadModel * _Nullable thread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !thread) {
                return;
            }

            if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
                !PPChatAlertsAllowed() ||
                strongSelf.isHandlingNotificationHandoff ||
                [strongSelf.mutedThreadIDsStorage containsObject:threadID] ||
                (strongSelf.activeThreadID.length && [strongSelf.activeThreadID isEqualToString:threadID])) {
                return;
            }

            NSMutableDictionary<NSString *, id> *userInfo = [@{
                @"type": @"chat",
                @"threadID": threadID,
                @"threadId": threadID
            } mutableCopy];

            if (message.ID.length > 0) {
                userInfo[@"messageID"] = message.ID;
                userInfo[@"messageId"] = message.ID;
            }
            if (message.senderID.length > 0) {
                userInfo[@"senderID"] = message.senderID;
                userInfo[@"senderId"] = message.senderID;
            }

            [[PPInAppChatNotificationPresenter sharedPresenter]
             showChatNotificationForThread:thread
                                    message:message
                                   userInfo:userInfo.copy];
        });
    }];
}



- (void)startGlobalIncomingMessageListenerForUser:(NSString *)userID
{
    NSString *resolvedUserID = [self pp_authenticatedUIDForRequestedUID:userID];
    if (!resolvedUserID.length) return;

    if (self.globalIncomingListener &&
        [self.globalIncomingListenerUserID isEqualToString:resolvedUserID]) {
        NSLog(@"🔔 [GlobalIncoming] Listener already active for user=%@ — skipping duplicate start", resolvedUserID);
        return;
    }

    if (self.globalIncomingListener) {
        [self.globalIncomingListener remove];
        self.globalIncomingListener = nil;
    }
    self.globalIncomingListenerUserID = resolvedUserID;

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
                PPChatAlertsAllowed() &&
                !isChatOpen &&
                ![strongSelf.mutedThreadIDsStorage containsObject:threadID] &&
                !strongSelf.isHandlingNotificationHandoff) {

                NSLog(@"🔔 [GlobalIncoming] Sound fired");
                [ChManager playIncomingMessageFeedback];
                ChatMessageModel *message =
                    [[ChatMessageModel alloc] initWithDictionary:change.document.data ?: @{}];
                if (message.ID.length == 0) {
                    message.ID = messageID;
                }
                [strongSelf pp_presentForegroundChatNotificationForThreadID:threadID
                                                                    message:message
                                                             receiverUserID:resolvedUserID];
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

    if ([self.deliverySyncInFlightUserID isEqualToString:resolvedUserID]) {
        NSLog(@"🔄 [DeliverySync] Already in flight for receiver=%@ — skipping duplicate request.", resolvedUserID);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
        return;
    }

    if ([self.lastDeliverySyncUserID isEqualToString:resolvedUserID] &&
        self.lastDeliverySyncCompletedAt &&
        [[NSDate date] timeIntervalSinceDate:self.lastDeliverySyncCompletedAt] < 12.0) {
        NSLog(@"🔄 [DeliverySync] Recently synced receiver=%@ — skipping duplicate warm-up request.", resolvedUserID);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
        return;
    }

    self.deliverySyncInFlightUserID = resolvedUserID;
    NSLog(@"🔄 [DeliverySync] Checking pending deliveries for receiver=%@ ...", resolvedUserID);

    // NOTE:
    // - "Messages" is a SUBCOLLECTION under /Chats/{threadId}/Messages/{messageId}
    // - collectionGroup("Messages") is the correct way to query ALL Messages subcollections
    //   across ALL threads.
    // - Your security rules must enforce that only the authenticated receiver (and/or staff)
    //   can read these docs.

    FIRQuery *query =
    [[[[[FIRFirestore firestore]
       collectionGroupWithID:@"Messages"]
      queryWhereField:@"receiverID" isEqualTo:resolvedUserID]
     queryWhereField:@"status" isEqualTo:@(ChatMessageStatusSent)]
     queryLimitedTo:500];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            DLog(@"[DeliverySync] Query failed | domain=%@ code=%ld", error.domain ?: @"", (long)error.code);

            // Helpful hint for the common permission failure
            // (e.g. auth not ready, user not a thread member, or rules too strict)
            if (error.code == FIRFirestoreErrorCodePermissionDenied) {
                NSLog(@"🚫 [DeliverySync] Permission denied. Ensure the user is authenticated and Firestore rules allow receiver to read Messages via collectionGroup.");
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.deliverySyncInFlightUserID = nil;
                if (completion) completion();
            });
            return;
        }

        if (snapshot.documents.count == 0) {
            NSLog(@"ℹ️ [DeliverySync] No pending deliveries.");
            self.lastDeliverySyncUserID = resolvedUserID;
            self.lastDeliverySyncCompletedAt = [NSDate date];
            self.deliverySyncInFlightUserID = nil;
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
            return;
        }

        NSMutableOrderedSet<NSString *> *threadIDs = [NSMutableOrderedSet orderedSet];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSString *threadID = doc.reference.parent.parent.documentID;
            if (threadID.length > 0) [threadIDs addObject:threadID];
        }

        dispatch_group_t updateGroup = dispatch_group_create();
        for (NSString *threadID in threadIDs) {
            dispatch_group_enter(updateGroup);
            __block void (^acknowledgePage)(void) = nil;
            acknowledgePage = ^{
                [self pp_invokeChatCommandForThreadID:threadID
                                               action:@"mark_delivered"
                                              payload:nil
                                           completion:^(NSDictionary * _Nullable data,
                                                        NSError * _Nullable commandError) {
                    if (commandError) {
                        DLog(@"[DeliverySync] Command failed | domain=%@ code=%ld",
                             commandError.domain ?: @"",
                             (long)commandError.code);
                        acknowledgePage = nil;
                        dispatch_group_leave(updateGroup);
                        return;
                    }
                    if ([data[@"hasMore"] boolValue] &&
                        [data[@"acknowledgedMessageCount"] integerValue] > 0) {
                        acknowledgePage();
                        return;
                    }
                    acknowledgePage = nil;
                    dispatch_group_leave(updateGroup);
                }];
            };
            if (acknowledgePage) {
                acknowledgePage();
            } else {
                dispatch_group_leave(updateGroup);
            }
        }

        DLog(@"[DeliverySync] Awaiting %lu server command(s)",
             (unsigned long)threadIDs.count);
        dispatch_group_notify(updateGroup, dispatch_get_main_queue(), ^{
            self.lastDeliverySyncUserID = resolvedUserID;
            self.lastDeliverySyncCompletedAt = [NSDate date];
            self.deliverySyncInFlightUserID = nil;
            if (completion) completion();
        });

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

    if (self.globalUnreadListener &&
        [self.globalUnreadListenerUserID isEqualToString:resolvedUserID]) {
        NSLog(@"📡 Global unread listener already active for user=%@ — skipping duplicate start", resolvedUserID);
        return;
    }

    if (self.globalUnreadListener) {
        [self.globalUnreadListener remove];
        self.globalUnreadListener = nil;
    }
    self.globalUnreadListenerUserID = resolvedUserID;

    FIRQuery *query =
    [[[[[FIRFirestore firestore]
       collectionGroupWithID:@"Messages"]
      queryWhereField:@"receiverID" isEqualTo:resolvedUserID]
     queryWhereField:@"status"
          isLessThan:@(ChatMessageStatusRead)]
     queryLimitedTo:500];

    NSLog(@"📡 Global unread listener started");

    __weak typeof(self) weakSelf = self;

    self.globalUnreadListener =
    [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) return;

        NSMutableDictionary *counts = [NSMutableDictionary dictionary];
        NSMutableDictionary *latestMessages = [NSMutableDictionary dictionary];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSString *threadID = doc.reference.parent.parent.documentID;
            NSInteger c = [counts[threadID] integerValue];
            counts[threadID] = @(c + 1);

            ChatMessageModel *msg = [[ChatMessageModel alloc] initWithDictionary:doc.data ?: @{}];
            if (msg.ID.length == 0) {
                msg.ID = doc.documentID;
            }
            if (threadID.length > 0) {
                ChatMessageModel *existing = latestMessages[threadID];
                if (!existing || [msg.timestamp compare:existing.timestamp] == NSOrderedDescending) {
                    latestMessages[threadID] = msg;
                }
            }
        }

        weakSelf.liveUnreadCounts = counts;
        weakSelf.latestUnreadMessages = latestMessages;

        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"UnreadCountsUpdated"
         object:nil];
    }];
}

- (void)forceReloadThreads
{
    NSLog(@"🔄 [ChManager] forceReloadThreads BEGIN");

    // 1️⃣ Stop all listeners
    NSLog(@"🛑 [ChManager] Stopping ALL listeners");

    [self stopAllThreadMessageListeners];

    if (self.globalIncomingListener) {
        [self.globalIncomingListener remove];
        self.globalIncomingListener = nil;
        self.globalIncomingListenerUserID = nil;
        NSLog(@"🛑 [ChManager] GlobalIncomingListener removed");
    }

    if (self.globalUnreadListener) {
        [self.globalUnreadListener remove];
        self.globalUnreadListener = nil;
        self.globalUnreadListenerUserID = nil;
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
        [[messagesRef queryOrderedByField:@"timestamp"] queryLimitedToLast:200];

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

- (void)startObservingMessagesInThreadID:(NSString *)threadID
                                   limit:(NSInteger)limit
                              completion:(ChMessageObservationCompletion)completion
{
    if (threadID.length == 0 || !completion) {
        return;
    }

    [self stopObservingMessagesInThreadID:threadID];

    NSString *myUserID = [self pp_authenticatedUIDForRequestedUID:nil];
    if (myUserID.length == 0) {
        NSError *error = [NSError errorWithDomain:@"ChManager"
                                               code:401
                                           userInfo:@{NSLocalizedDescriptionKey: @"Chat authentication is unavailable."}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], NO, NO, error);
        });
        return;
    }

    NSInteger resolvedLimit = MAX(1, limit);
    FIRCollectionReference *messagesRef =
    [[[self.firestore collectionWithPath:@"Chats"]
       documentWithPath:threadID]
      collectionWithPath:@"Messages"];
    FIRQuery *query =
    [[messagesRef queryOrderedByField:@"timestamp"] queryLimitedToLast:resolvedLimit];

    __weak typeof(self) weakSelf = self;
    id<FIRListenerRegistration> listener =
    [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot,
                                 NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (error || !snapshot) {
            NSLog(@"❌ [ChatMessages] Snapshot failed thread=%@ code=%ld: %@",
                  threadID,
                  (long)error.code,
                  error.localizedDescription ?: @"unknown error");
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], NO, NO, error ?: [NSError errorWithDomain:@"ChManager"
                                                                         code:500
                                                                     userInfo:@{NSLocalizedDescriptionKey: @"Chat messages could not be loaded."}]);
            });
            return;
        }

        NSMutableArray<ChatMessageModel *> *messages =
            [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *document in snapshot.documents) {
            ChatMessageModel *message =
                [[ChatMessageModel alloc] initWithDictionary:document.data ?: @{}];
            if (document.documentID.length > 0) {
                message.ID = document.documentID;
            }
            [messages addObject:message];

            if (message.status == ChatMessageStatusSent &&
                [message.receiverID isEqualToString:myUserID] &&
                ![message.senderID isEqualToString:myUserID]) {
                [strongSelf markMessageAsDelivered:message.ID threadID:threadID];
            }
        }

        BOOL canLoadOlder = snapshot.documents.count >= resolvedLimit;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(messages.copy, YES, canLoadOlder, nil);
        });
    }];

    if (listener) {
        self.activeMessageListeners[threadID] = listener;
    }
}

- (void)stopObservingMessagesInThreadID:(NSString *)threadID
{
    if (threadID.length == 0) {
        return;
    }

    id<FIRListenerRegistration> listener = self.activeMessageListeners[threadID];
    [listener remove];
    [self.activeMessageListeners removeObjectForKey:threadID];
}

- (void)createOrGetChatThreadWithUser:(UserModel *)user
                           completion:(void (^)(ChatThreadModel *thread, NSError *error))completion
{
    [self createOrGetChatThreadWithUser:user
                            contextType:nil
                              contextID:nil
                             completion:completion];
}

- (void)createOrGetChatThreadWithUser:(UserModel *)user
                          contextType:(nullable NSString *)contextType
                            contextID:(nullable NSString *)contextID
                           completion:(void (^)(ChatThreadModel *thread, NSError *error))completion
{
    if (!user.ID.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"Chat"
                                                            code:400
                                                        userInfo:@{NSLocalizedDescriptionKey:
                                                                       kLang(@"SomethingWentWrong")}]);
        return;
    }

    NSString *currentUserID = [self pp_authenticatedUIDForRequestedUID:UserManager.sharedManager.currentUser.ID];
    if (!currentUserID.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"Chat"
                                                code:401
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                           kLang(@"SomethingWentWrong")}]);
        }
        return;
    }
    if ([currentUserID isEqualToString:user.ID]) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"Chat"
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                           kLang(@"SomethingWentWrong")}]);
        }
        return;
    }

    NSString *safeContextType = [PPSupportTrimmedString(contextType) lowercaseString];
    NSString *safeContextID = PPSupportTrimmedString(contextID);
    if ((safeContextType.length == 0) != (safeContextID.length == 0)) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"Chat"
                                                code:400
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                           kLang(@"SomethingWentWrong")}]);
        }
        return;
    }

    NSMutableDictionary *payload = [@{
        @"action": @"create_or_get",
        @"receiverID": user.ID,
        @"sourceApp": @"user_ios",
        @"sourcePlatform": @"ios",
    } mutableCopy];
    if (safeContextType.length > 0) {
        payload[@"contextType"] = safeContextType;
        payload[@"contextId"] = safeContextID;
    }

    [self pp_invokeChatCallableNamed:@"chatMessageCommand"
                             payload:payload.copy
                          completion:^(NSDictionary * _Nullable data,
                                       NSError * _Nullable error) {
        NSString *threadID = PPSupportTrimmedString(data[@"threadID"]);
        if (error || threadID.length == 0) {
            if (completion) {
                completion(nil, error ?: [NSError errorWithDomain:@"Chat"
                                                              code:500
                                                          userInfo:@{NSLocalizedDescriptionKey:
                                                                         kLang(@"SomethingWentWrong")}]);
            }
            return;
        }

        FIRDocumentReference *threadRef =
            [[self.firestore collectionWithPath:@"Chats"] documentWithPath:threadID];
        [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                               NSError * _Nullable readError) {
            if (readError || !snapshot.exists) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(nil, readError ?: [NSError errorWithDomain:@"Chat"
                                                                         code:404
                                                                     userInfo:@{NSLocalizedDescriptionKey:
                                                                                    kLang(@"SomethingWentWrong")}]);
                    }
                });
                return;
            }

            ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:snapshot.data ?: @{}];
            thread.ID = snapshot.documentID;
            thread.otherUser = user;
            [[ChManager sharedManager] startListeningForThreadMessages:@[thread]];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"forceReloadThreads" object:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(thread, nil);
            });
        }];
    }];
    return;

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
            if (thread.messagesCount == 0 && thread.lastMessage.length == 0) {
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
            if (thread.messagesCount == 0 && thread.lastMessage.length == 0) {
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
        self.globalIncomingListenerUserID = nil;
    }

    if (self.globalUnreadListener) {
        [self.globalUnreadListener remove];
        self.globalUnreadListener = nil;
        self.globalUnreadListenerUserID = nil;
    }

    [self.liveUnreadCounts removeAllObjects];
    [self.latestUnreadMessages removeAllObjects];
}

 


#pragma mark - Media Send APIs

 

- (void)markMessageAsDelivered:(NSString *)messageID
                       threadID:(NSString *)threadID
{
    if (messageID.length == 0 || threadID.length == 0) return;
    [self pp_invokeChatCommandForThreadID:threadID
                                   action:@"mark_delivered"
                                  payload:@{@"messageId": messageID}
                               completion:^(__unused NSDictionary * _Nullable data,
                                            NSError * _Nullable error) {
        if (error) {
            NSLog(@"⚠️ [ChatReceipt] Delivery acknowledgement failed — code=%ld domain=%@",
                  (long)error.code,
                  error.domain ?: @"");
        }
    }];
}

- (void)markMessagesAsReadInThread:(NSString *)threadID
                          fromUser:(NSString *)senderID
{
    (void)senderID;
    if (threadID.length == 0) return;
    __weak typeof(self) weakSelf = self;
    [self pp_invokeChatCommandForThreadID:threadID
                                   action:@"mark_read"
                                  payload:nil
                               completion:^(NSDictionary * _Nullable data,
                                            NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            NSLog(@"⚠️ [ChatReceipt] Read acknowledgement failed — code=%ld domain=%@",
                  (long)error.code,
                  error.domain ?: @"");
            return;
        }

        NSMutableDictionary *counts = [strongSelf.liveUnreadCounts mutableCopy]
            ?: [NSMutableDictionary dictionary];
        NSMutableDictionary *latest = [strongSelf.latestUnreadMessages mutableCopy]
            ?: [NSMutableDictionary dictionary];
        BOOL changed = counts[threadID] != nil || latest[threadID] != nil;
        [counts removeObjectForKey:threadID];
        [latest removeObjectForKey:threadID];
        strongSelf.liveUnreadCounts = counts;
        strongSelf.latestUnreadMessages = latest;
        if (changed) {
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"UnreadCountsUpdated"
             object:nil];
        }

        if ([data[@"hasMore"] boolValue] && [data[@"acknowledgedMessageCount"] integerValue] > 0) {
            [strongSelf markMessagesAsReadInThread:threadID fromUser:@""];
        }
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
                                                   kLang(@"chat_invalid_image_parameters")}]);
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
                                                           kLang(@"chat_image_encoding_failed")}]);
                });
            }
            return;
        }

        FIRStorageReference *ref =
            [[[FIRStorage storage] reference]
              child:[NSString stringWithFormat:@"Chats/%@/media/images/%@.jpg", threadID, msg.ID]];

        FIRStorageMetadata *metadata = [FIRStorageMetadata new];
        metadata.contentType = @"image/jpeg";
        metadata.customMetadata = @{
            @"uploaded_by": [FIRAuth auth].currentUser.uid ?: @"",
            @"thread_id": threadID ?: @"",
            @"message_id": msg.ID ?: @"",
            @"media_type": @"image"
        };
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
                                       kLang(@"chat_invalid_video_parameters")}];
        if (completion) completion(err);
        return;
    }

    NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
    if (!videoData) {
        NSError *err =
            [NSError errorWithDomain:@"ChManager"
                                code:500
                            userInfo:@{NSLocalizedDescriptionKey:
                                       kLang(@"chat_video_read_failed")}];
        if (completion) completion(err);
        return;
    }

    FIRStorageReference *videoRef =
        [[[FIRStorage storage] reference]
          child:[NSString stringWithFormat:@"Chats/%@/media/videos/%@.mp4", threadID, msg.ID]];

    msg.isUploading = YES;
    msg.transferProgress = 0;

    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"video/mp4";
    metadata.customMetadata = @{
        @"uploaded_by": [FIRAuth auth].currentUser.uid ?: @"",
        @"thread_id": threadID ?: @"",
        @"message_id": msg.ID ?: @"",
        @"media_type": @"video"
    };
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

+ (CGFloat)heightForMessage:(NSString *)text onController:(UIViewController *)cont {
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
    if (threadID.length == 0 || userID.length == 0) return;
    [self pp_invokeChatCommandForThreadID:threadID
                                   action:@"set_typing"
                                  payload:@{@"isTyping": @(isTyping)}
                               completion:^(__unused NSDictionary * _Nullable data,
                                            NSError * _Nullable error) {
        if (error) {
            NSLog(@"⚠️ [ChatTyping] Command failed — code=%ld domain=%@",
                  (long)error.code,
                  error.domain ?: @"");
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

    for (id<FIRListenerRegistration> listener in self.activeMessageListeners.allValues) {
        [listener remove];
    }
    [self.activeMessageListeners removeAllObjects];
}

- (void)deleteChatThreadWithID:(NSString *)threadID
                    completion:(void (^)(NSError * _Nullable error))completion {
    [self pp_invokeChatCommandForThreadID:threadID
                                   action:@"set_binned"
                                  payload:@{@"enabled": @YES}
                               completion:^(__unused NSDictionary * _Nullable data,
                                            NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)unsendMessageWithID:(NSString *)messageID
                   threadID:(NSString *)threadID
                 completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *trimmedMessageID =
        [messageID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *trimmedThreadID =
        [threadID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedMessageID.length == 0 || trimmedThreadID.length == 0) {
        NSError *error = [NSError errorWithDomain:@"ChManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        kLang(@"chat_unsend_failed")}];
        if (completion) completion(error);
        return;
    }

    [PPFirebaseSessionBridge ensureFreshAuthSessionForcingRefresh:NO
                                                       completion:^(NSError * _Nullable authError) {
        if (authError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(authError);
            });
            return;
        }

        FIRHTTPSCallable *callable =
            [[FIRFunctions functionsForRegion:@"us-central1"]
             HTTPSCallableWithName:@"unsendChatMessage"];
        NSDictionary *payload = @{
            @"threadID": trimmedThreadID,
            @"messageID": trimmedMessageID,
        };
        [callable callWithObject:payload
                     completion:^(__unused FIRHTTPSCallableResult * _Nullable result,
                                  NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(error);
            });
        }];
    }];
}

- (void)muteThreadWithID:(NSString *)threadID
                 muted:(BOOL)muted
             completion:(void (^)(NSError * _Nullable error))completion
{
    if (!threadID.length) {
        if (completion) completion([NSError errorWithDomain:@"ChManager"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                                  kLang(@"SomethingWentWrong")}]);
        return;
    }
    [self pp_invokeChatCommandForThreadID:threadID
                                   action:@"set_muted"
                                  payload:@{@"enabled": @(muted)}
                               completion:^(__unused NSDictionary * _Nullable data,
                                            NSError * _Nullable error) {
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
    if (!threadID.length) {
        if (completion) completion([NSError errorWithDomain:@"ChManager"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                                  kLang(@"SomethingWentWrong")}]);
        return;
    }
    [self pp_invokeChatCommandForThreadID:threadID
                                   action:@"set_binned"
                                  payload:@{@"enabled": @(binned)}
                               completion:^(__unused NSDictionary * _Nullable data,
                                            NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)reportThread:(ChatThreadModel *)thread
              reason:(nullable NSString *)reason
          completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *myUID = [self pp_authenticatedUIDForRequestedUID:nil];
    if (!thread.ID.length || !myUID.length || thread.supportThread) {
        if (completion) completion([NSError errorWithDomain:@"ChManager"
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                                  kLang(@"SomethingWentWrong")}]);
        return;
    }
    if ([thread.reportedBy containsObject:myUID]) {
        if (completion) completion(nil);
        return;
    }

    [self pp_invokeChatCallableNamed:@"chatMessageCommand"
                             payload:@{
                                 @"action": @"report",
                                 @"threadId": thread.ID,
                                 @"reason": reason ?: @"",
                             }
                          completion:^(__unused NSDictionary * _Nullable data,
                                       NSError * _Nullable error) {
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
        
        // Open chat messaging screen
        [PPOverlayCoordinator pp_openChatThread:thread fromVC:controller];
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

            // Open chat messaging screen
            [PPOverlayCoordinator pp_openChatThread:chatThread fromVC:controller];
        }];
}
@end
