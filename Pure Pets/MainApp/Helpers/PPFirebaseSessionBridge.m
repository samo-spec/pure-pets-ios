//
//  PPFirebaseSessionBridge.m
//  Pure Pets
//

#import "PPFirebaseSessionBridge.h"
#import <FirebaseAuth/FirebaseAuth.h>
@import FirebaseAuth;
#if __has_include(<FirebaseAppCheck/FirebaseAppCheck.h>)
@import FirebaseAppCheck;
#define PP_SESSION_HAS_FIREBASE_APPCHECK 1
#else
#define PP_SESSION_HAS_FIREBASE_APPCHECK 0
#endif

NSErrorDomain const PPFirebaseSessionBridgeErrorDomain = @"PPFirebaseSessionBridge";

static void PPFirebaseSessionCompleteOnMain(void (^completion)(NSError * _Nullable error), NSError * _Nullable error)
{
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(error);
    });
}

static NSError *PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCode code,
                                       NSString *localizedKey,
                                       NSString *fallback,
                                       NSError * _Nullable underlying)
{
    NSString *message = kLang(localizedKey) ?: fallback ?: kLang(@"SomethingWentWrong") ?: @"Something went wrong.";
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey: message,
        @"PPFirebaseSessionLocalizedKey": localizedKey ?: @""
    } mutableCopy];
    if (underlying) {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:PPFirebaseSessionBridgeErrorDomain code:code userInfo:userInfo.copy];
}

static NSString *PPFirebaseSessionCombinedErrorText(NSError *error)
{
    if (!error) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (error.domain.length) [parts addObject:error.domain];
    if (error.localizedDescription.length) [parts addObject:error.localizedDescription];
    if ([error.userInfo[NSLocalizedFailureReasonErrorKey] isKindOfClass:NSString.class]) {
        [parts addObject:error.userInfo[NSLocalizedFailureReasonErrorKey]];
    }
    if ([error.userInfo[@"details"] isKindOfClass:NSString.class]) {
        [parts addObject:error.userInfo[@"details"]];
    }
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    if ([underlying isKindOfClass:NSError.class]) {
        [parts addObject:PPFirebaseSessionCombinedErrorText(underlying)];
    }
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

static BOOL PPFirebaseSessionTextContainsAnyToken(NSString *text,
                                                  NSArray<NSString *> *tokens)
{
    if (text.length == 0) return NO;
    NSString *lower = text.lowercaseString;
    for (NSString *token in tokens) {
        if (token.length > 0 && [lower containsString:token.lowercaseString]) {
            return YES;
        }
    }
    return NO;
}

static NSString *PPFirebaseSessionLocalizedString(NSString * _Nullable key, NSString *fallback)
{
    if (key.length > 0) {
        NSString *resolved = [Language get:key alter:nil];
        if (resolved.length > 0 && ![resolved isEqualToString:key]) {
            return resolved;
        }
    }
    return fallback ?: @"";
}

static NSString *PPFirebaseSessionFallbackMessage(NSString * _Nullable fallbackKey)
{
    NSString *fallback = PPFirebaseSessionLocalizedString(fallbackKey, @"");
    if (fallback.length) return fallback;
    return PPFirebaseSessionLocalizedString(@"SomethingWentWrong", @"Something went wrong.");
}

static NSDictionary * _Nullable PPFirebaseSessionResolveChatErrorDescriptor(NSString * _Nullable text)
{
    if (text.length == 0) return nil;

    static NSArray<NSDictionary<NSString *, id> *> *descriptors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        descriptors = @[
            @{
                @"tokens": @[@"the conversation recipient is not active", @"recipient is not active", @"support assignee is not active"],
                @"titleKey": @"chat_recipient_inactive_title",
                @"defaultTitle": @"Recipient Unavailable",
                @"messageKey": @"chat_recipient_inactive_message",
                @"defaultMessage": @"This user's account is currently inactive and cannot receive messages. Please choose another user or try again later.",
            },
            @{
                @"tokens": @[@"messaging is unavailable between these accounts"],
                @"titleKey": @"chat_peer_blocked_title",
                @"defaultTitle": @"Messaging Unavailable",
                @"messageKey": @"chat_peer_blocked_message",
                @"defaultMessage": @"Messaging is unavailable between these accounts because one of the accounts has blocked the conversation.",
            },
            @{
                @"tokens": @[@"staff conversations must be initiated by an authorized staff member"],
                @"titleKey": @"chat_staff_initiation_title",
                @"defaultTitle": @"Direct Chat Unavailable",
                @"messageKey": @"chat_staff_initiation_message",
                @"defaultMessage": @"You cannot start a direct chat with this staff account. Please contact Pure Pets Support instead.",
            },
            @{
                @"tokens": @[
                    @"chat is not available for this account",
                    @"this staff account is not active",
                    @"not allowed to use support chat",
                    @"support chat is not available for this account",
                    @"support access is not available for this staff account",
                    @"you are not a participant in this conversation",
                    @"you can only unsend your own messages",
                    @"this account cannot modify chat messages",
                ],
                @"titleKey": @"chat_account_unavailable_title",
                @"defaultTitle": @"Chat Unavailable",
                @"messageKey": @"chat_account_unavailable_message",
                @"defaultMessage": @"Messaging is not available for your account right now. Please contact Pure Pets Support if you need help.",
            },
            @{
                @"tokens": @[@"a conversation needs another participant", @"a message needs another recipient"],
                @"titleKey": @"Warning",
                @"defaultTitle": @"Warning",
                @"messageKey": @"CannotChatWithSelf",
                @"defaultMessage": @"You cannot start a conversation with yourself. Please choose another user.",
            },
            @{
                @"tokens": @[
                    @"the requested pet advertisement is not available",
                    @"the requested pet advertisement is not publicly available",
                    @"the advertisement does not belong to this conversation",
                ],
                @"titleKey": @"chat_ad_unavailable_title",
                @"defaultTitle": @"Listing Unavailable",
                @"messageKey": @"chat_ad_unavailable_message",
                @"defaultMessage": @"This listing is no longer available for messaging.",
            },
            @{
                @"tokens": @[
                    @"community messaging is currently unavailable",
                    @"community chat participant profile was not found",
                    @"messaging is not available for this community record state",
                    @"the requested community conversation context is not available",
                    @"the community record does not belong to these conversation participants",
                ],
                @"titleKey": @"chat_community_unavailable_title",
                @"defaultTitle": @"Messaging Unavailable",
                @"messageKey": @"chat_community_unavailable_message",
                @"defaultMessage": @"Messaging is currently unavailable for this community item.",
            },
            @{
                @"tokens": @[@"this message can no longer be unsent"],
                @"titleKey": @"chat_unsend_window_expired_title",
                @"defaultTitle": @"Unable to Unsend",
                @"messageKey": @"chat_unsend_window_expired_message",
                @"defaultMessage": @"Messages can only be unsent within 15 minutes of sending.",
            },
            @{
                @"tokens": @[
                    @"conversation not found",
                    @"the conversation was not found",
                    @"support conversation not found",
                    @"the conversation message was not found",
                ],
                @"titleKey": @"chat_thread_not_found_title",
                @"defaultTitle": @"Conversation Unavailable",
                @"messageKey": @"chat_thread_not_found_message",
                @"defaultMessage": @"This conversation could not be found or is no longer available.",
            },
            @{
                @"tokens": @[
                    @"support threads must use supportchatcommand",
                    @"support threads use a separate canonical command",
                    @"support thread preferences use supportchatcommand",
                    @"support conversations use the support lifecycle",
                    @"the support conversation changed",
                    @"reopen the support conversation before replying",
                    @"this support conversation is historical",
                ],
                @"titleKey": @"chat_start_failed_title",
                @"defaultTitle": @"Unable to Start Chat",
                @"messageKey": @"pp_support_open_failed",
                @"defaultMessage": @"Could not open support chat right now.",
            },
        ];
    });

    NSString *lower = text.lowercaseString;
    for (NSDictionary<NSString *, id> *descriptor in descriptors) {
        NSArray<NSString *> *tokens = descriptor[@"tokens"];
        if (PPFirebaseSessionTextContainsAnyToken(lower, tokens)) {
            return descriptor;
        }
    }
    return nil;
}

static BOOL PPFirebaseSessionErrorContainsBridgeCode(NSError *error,
                                                     PPFirebaseSessionBridgeErrorCode code)
{
    if (!error) return NO;
    if ([error.domain isEqualToString:PPFirebaseSessionBridgeErrorDomain] &&
        error.code == code) {
        return YES;
    }
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    return [underlying isKindOfClass:NSError.class] &&
           PPFirebaseSessionErrorContainsBridgeCode(underlying, code);
}

static void PPFirebaseSessionLogFailure(NSString *stage, NSError *error)
{
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    NSLog(@"[PPFirebaseSessionBridge] %@ failed domain=%@ code=%ld underlyingDomain=%@ underlyingCode=%ld",
          stage ?: @"request",
          error.domain ?: @"",
          (long)error.code,
          underlying.domain ?: @"",
          (long)underlying.code);
}

static NSError *PPFirebaseSessionRefreshError(NSError * _Nullable underlying)
{
    return PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                  @"pp_auth_session_refresh_failed",
                                  @"We could not refresh your session. Please try again.",
                                  underlying);
}

static NSError *PPFirebaseSessionMissingTokenError(void)
{
    return PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                  @"pp_auth_session_refresh_failed",
                                  @"We could not refresh your session. Please try again.",
                                  nil);
}

static void PPFirebaseSessionFallbackToCachedToken(FIRUser *user,
                                                   NSString *stage,
                                                   NSError * _Nullable originalError,
                                                   void (^completion)(NSString * _Nullable token, NSError * _Nullable error))
{
    NSError *(^fallbackError)(NSError * _Nullable) = ^NSError *(NSError * _Nullable candidate) {
        return candidate ?: PPFirebaseSessionMissingTokenError();
    };

    FIRUser *currentUser = [FIRAuth auth].currentUser;
    if (!currentUser.uid.length || ![currentUser.uid isEqualToString:user.uid]) {
        if (completion) completion(nil, fallbackError(originalError));
        return;
    }

    [currentUser getIDTokenForcingRefresh:NO completion:^(NSString * _Nullable cachedToken, NSError * _Nullable cachedError) {
        if (!cachedError && cachedToken.length > 0) {
            NSLog(@"[PPFirebaseSessionBridge] %@ using cached auth token after refresh failure",
                  stage ?: @"auth refresh");
            if (completion) completion(cachedToken, nil);
            return;
        }

        if (cachedError) {
            PPFirebaseSessionLogFailure(@"cached auth token fallback", cachedError);
        } else {
            NSLog(@"[PPFirebaseSessionBridge] cached auth token fallback failed: token was empty");
        }
        if (completion) completion(nil, fallbackError(originalError ?: cachedError));
    }];
}

static void PPFirebaseSessionGetIDTokenWithRepair(FIRUser *user,
                                                  BOOL forceRefresh,
                                                  NSString *stage,
                                                  void (^completion)(NSString * _Nullable token, NSError * _Nullable error))
{
    [user getIDTokenForcingRefresh:forceRefresh completion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (!error && token.length > 0) {
            if (completion) completion(token, nil);
            return;
        }

        if (error) {
            PPFirebaseSessionLogFailure(stage, error);
        } else {
            NSLog(@"[PPFirebaseSessionBridge] %@ failed: token was empty", stage ?: @"auth token lookup");
        }

        [user reloadWithCompletion:^(NSError * _Nullable reloadError) {
            if (reloadError) {
                PPFirebaseSessionLogFailure(@"auth user reload", reloadError);
                if (forceRefresh) {
                    PPFirebaseSessionFallbackToCachedToken(user,
                                                           stage ?: @"forced auth refresh",
                                                           reloadError ?: error,
                                                           completion);
                    return;
                }
                if (completion) completion(nil, reloadError ?: error);
                return;
            }

            FIRUser *currentUser = [FIRAuth auth].currentUser;
            if (!currentUser.uid.length || ![currentUser.uid isEqualToString:user.uid]) {
                if (completion) completion(nil, error ?: PPFirebaseSessionMissingTokenError());
                return;
            }

            [currentUser getIDTokenForcingRefresh:forceRefresh completion:^(NSString * _Nullable repairedToken, NSError * _Nullable repairError) {
                if (!repairError && repairedToken.length > 0) {
                    if (completion) completion(repairedToken, nil);
                    return;
                }

                if (repairError) {
                    PPFirebaseSessionLogFailure(forceRefresh ? @"reloaded forced auth refresh" : @"reloaded auth token lookup",
                                                repairError);
                } else {
                    NSLog(@"[PPFirebaseSessionBridge] %@ failed: token was empty",
                          forceRefresh ? @"reloaded forced auth refresh" : @"reloaded auth token lookup");
                }

                if (!forceRefresh) {
                    [currentUser getIDTokenForcingRefresh:YES completion:^(NSString * _Nullable refreshedToken, NSError * _Nullable refreshError) {
                        if (!refreshError && refreshedToken.length > 0) {
                            if (completion) completion(refreshedToken, nil);
                            return;
                        }
                        if (refreshError) {
                            PPFirebaseSessionLogFailure(@"request auth token refresh fallback", refreshError);
                        } else {
                            NSLog(@"[PPFirebaseSessionBridge] request auth token refresh fallback failed: token was empty");
                        }
                        if (completion) completion(nil, refreshError ?: repairError ?: error ?: PPFirebaseSessionMissingTokenError());
                    }];
                    return;
                }

                PPFirebaseSessionFallbackToCachedToken(currentUser,
                                                       stage ?: @"forced auth refresh",
                                                       repairError ?: error,
                                                       completion);
            }];
        }];
    }];
}

static void PPFirebaseSessionTryForcedRefreshAfterCachedFailure(FIRUser *user,
                                                                NSString *stage,
                                                                NSError * _Nullable originalError,
                                                                void (^completion)(NSError * _Nullable error))
{
    FIRUser *currentUser = [FIRAuth auth].currentUser;
    if (!currentUser.uid.length || ![currentUser.uid isEqualToString:user.uid]) {
        PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionRefreshError(originalError));
        return;
    }

    PPFirebaseSessionGetIDTokenWithRepair(currentUser,
                                          YES,
                                          stage ?: @"cached auth token forced refresh fallback",
                                          ^(__unused NSString * _Nullable token, NSError * _Nullable forceError) {
        PPFirebaseSessionCompleteOnMain(completion, forceError ? PPFirebaseSessionRefreshError(forceError) : nil);
    });
}

static void PPFirebaseSessionEnsureCachedSession(FIRUser *user,
                                                 BOOL didReload,
                                                 void (^completion)(NSError * _Nullable error))
{
    [user getIDTokenResultWithCompletion:^(FIRAuthTokenResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            PPFirebaseSessionLogFailure(didReload ? @"reloaded cached auth token lookup" : @"cached auth token lookup",
                                        error);
            if (!didReload) {
                [user reloadWithCompletion:^(NSError * _Nullable reloadError) {
                    if (reloadError) {
                        PPFirebaseSessionLogFailure(@"auth user reload", reloadError);
                        PPFirebaseSessionTryForcedRefreshAfterCachedFailure(user,
                                                                            @"reload failure auth token refresh fallback",
                                                                            reloadError,
                                                                            completion);
                        return;
                    }

                    FIRUser *currentUser = [FIRAuth auth].currentUser;
                    if (!currentUser.uid.length || ![currentUser.uid isEqualToString:user.uid]) {
                        PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionRefreshError(error));
                        return;
                    }
                    PPFirebaseSessionEnsureCachedSession(currentUser, YES, completion);
                }];
                return;
            }

            PPFirebaseSessionTryForcedRefreshAfterCachedFailure(user,
                                                                @"cached auth token refresh fallback",
                                                                error,
                                                                completion);
            return;
        }

        NSDate *expiry = result.expirationDate ?: [NSDate distantPast];
        if ([expiry timeIntervalSinceNow] > 300) {
            PPFirebaseSessionCompleteOnMain(completion, nil);
            return;
        }

        PPFirebaseSessionGetIDTokenWithRepair(user, YES, @"expiring auth token refresh", ^(__unused NSString * _Nullable token, NSError * _Nullable forceError) {
            PPFirebaseSessionCompleteOnMain(completion, forceError ? PPFirebaseSessionRefreshError(forceError) : nil);
        });
    }];
}

@implementation PPFirebaseSessionBridge

+ (void)ensureFreshAuthSessionForcingRefresh:(BOOL)forceRefresh
                                  completion:(void (^)(NSError * _Nullable error))completion
{
    FIRUser *user = [FIRAuth auth].currentUser;
    if (!user.uid.length) {
        PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                                                          @"pp_auth_sign_in_required",
                                                                          @"Please sign in to continue.",
                                                                          nil));
        return;
    }

    if (forceRefresh) {
        PPFirebaseSessionGetIDTokenWithRepair(user, YES, @"forced auth refresh", ^(__unused NSString * _Nullable token, NSError * _Nullable error) {
            PPFirebaseSessionCompleteOnMain(completion, error ? PPFirebaseSessionRefreshError(error) : nil);
        });
        return;
    }

    PPFirebaseSessionEnsureCachedSession(user, NO, completion);
}

+ (void)authorizeRequest:(NSMutableURLRequest *)request
                 options:(PPFirebaseSessionAuthorizationOptions)options
              completion:(void (^)(NSError * _Nullable error))completion
{
    if (!request) {
        PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeInvalidRequest,
                                                                          @"SomethingWentWrong",
                                                                          @"Something went wrong.",
                                                                          nil));
        return;
    }

    FIRUser *user = [FIRAuth auth].currentUser;
    BOOL requireSignedIn = (options & PPFirebaseSessionAuthorizationOptionRequireSignedIn) != 0;
    if (requireSignedIn && !user.uid.length) {
        PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                                                          @"pp_auth_sign_in_required",
                                                                          @"Please sign in to continue.",
                                                                          nil));
        return;
    }

    void (^finishWithAppCheck)(void) = ^{
        if ((options & PPFirebaseSessionAuthorizationOptionIncludeAppCheck) == 0) {
            PPFirebaseSessionCompleteOnMain(completion, nil);
            return;
        }

#if PP_SESSION_HAS_FIREBASE_APPCHECK
        BOOL forceAppCheck = (options & PPFirebaseSessionAuthorizationOptionForceRefreshAppCheck) != 0;
        [[FIRAppCheck appCheck] tokenForcingRefresh:forceAppCheck completion:^(FIRAppCheckToken * _Nullable token, NSError * _Nullable error) {
            if (error || token.token.length == 0) {
                if (error) {
                    PPFirebaseSessionLogFailure(forceAppCheck ? @"forced App Check refresh" : @"App Check token lookup",
                                                error);
                } else {
                    NSLog(@"[PPFirebaseSessionBridge] %@ failed: token was empty",
                          forceAppCheck ? @"forced App Check refresh" : @"App Check token lookup");
                }
                PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeAppCheckUnavailable,
                                                                                  @"pp_app_check_unavailable",
                                                                                  @"We could not verify this device right now. Please try again.",
                                                                                  error));
                return;
            }
            [request setValue:token.token forHTTPHeaderField:@"X-Firebase-AppCheck"];
            PPFirebaseSessionCompleteOnMain(completion, nil);
        }];
#else
        PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeAppCheckUnavailable,
                                                                          @"pp_app_check_unavailable",
                                                                          @"We could not verify this device right now. Please try again.",
                                                                          nil));
#endif
    };

    if (!user.uid.length) {
        finishWithAppCheck();
        return;
    }

    BOOL forceAuth = (options & PPFirebaseSessionAuthorizationOptionForceRefreshAuth) != 0;
    PPFirebaseSessionGetIDTokenWithRepair(user,
                                          forceAuth,
                                          forceAuth ? @"forced request auth refresh" : @"request auth token lookup",
                                          ^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error || token.length == 0) {
            PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionRefreshError(error));
            return;
        }
        [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
        finishWithAppCheck();
    });
}

+ (BOOL)isAuthOrAppCheckError:(NSError *)error
{
    if (!error) return NO;
    if ([error.domain isEqualToString:PPFirebaseSessionBridgeErrorDomain]) {
        return error.code == PPFirebaseSessionBridgeErrorCodeUnauthenticated ||
               error.code == PPFirebaseSessionBridgeErrorCodeAppCheckUnavailable;
    }

    NSInteger code = error.code;
    if (code == 16 || code == 401 || code == 403) {
        return YES;
    }

    NSString *text = PPFirebaseSessionCombinedErrorText(error);
    return [text containsString:@"unauthenticated"] ||
           [text containsString:@"auth token"] ||
           [text containsString:@"id token"] ||
           [text containsString:@"app check"] ||
           [text containsString:@"appcheck"] ||
           [text containsString:@"app attest"] ||
           [text containsString:@"appattest"] ||
           [text containsString:@"devicecheck"];
}

+ (NSString *)publicMessageForText:(NSString * _Nullable)text
                        fallbackKey:(NSString * _Nullable)fallbackKey
{
    if (text.length == 0) {
        return PPFirebaseSessionFallbackMessage(fallbackKey);
    }

    NSString *lower = text.lowercaseString;
    if (PPFirebaseSessionTextContainsAnyToken(lower, @[
        @"app check", @"appcheck", @"app attest", @"appattest", @"devicecheck"
    ])) {
        return PPFirebaseSessionLocalizedString(@"pp_app_check_unavailable",
                                               @"We could not verify this device right now. Please try again.");
    }

    if (PPFirebaseSessionTextContainsAnyToken(lower, @[
        @"unauthenticated", @"auth token", @"id token", @"user token", @"session refresh"
    ])) {
        return PPFirebaseSessionLocalizedString(@"pp_auth_session_refresh_failed",
                                               @"We could not refresh your session. Please try again.");
    }

    if (PPFirebaseSessionTextContainsAnyToken(lower, @[
        @"client is offline",
        @"network is unavailable",
        @"network connection was lost",
        @"the internet connection appears to be offline",
        @"failed to get document because the client is offline"
    ])) {
        return PPFirebaseSessionLocalizedString(@"offline_action_message",
                                               PPFirebaseSessionFallbackMessage(@"SomethingWentWrong"));
    }

    NSDictionary *chatDescriptor = PPFirebaseSessionResolveChatErrorDescriptor(text);
    if (chatDescriptor) {
        return PPFirebaseSessionLocalizedString(chatDescriptor[@"messageKey"],
                                               chatDescriptor[@"defaultMessage"]);
    }

    if (PPFirebaseSessionTextContainsAnyToken(lower, @[
        @"an internal error has occurred",
        @"print and inspect",
        @"firebasefunctions",
        @"functionsinternal",
        @"internal error",
        @"permission denied",
        @"missing or insufficient permissions"
    ])) {
        return PPFirebaseSessionFallbackMessage(fallbackKey);
    }

    return text;
}

+ (NSError *)publicErrorForError:(NSError *)error
                     fallbackKey:(NSString *)fallbackKey
{
    NSString *message = [self publicMessageForError:error fallbackKey:fallbackKey];
    NSInteger code = error.code ?: PPFirebaseSessionBridgeErrorCodeInvalidRequest;
    NSMutableDictionary *userInfo = [@{NSLocalizedDescriptionKey: message} mutableCopy];
    if (error) {
        userInfo[NSUnderlyingErrorKey] = error;
    }
    return [NSError errorWithDomain:PPFirebaseSessionBridgeErrorDomain
                               code:code
                           userInfo:userInfo.copy];
}

+ (NSString *)publicMessageForError:(NSError *)error
                         fallbackKey:(NSString *)fallbackKey
{
    if (PPFirebaseSessionErrorContainsBridgeCode(error, PPFirebaseSessionBridgeErrorCodeAppCheckUnavailable)) {
        return PPFirebaseSessionLocalizedString(@"pp_app_check_unavailable",
                                               @"We could not verify this device right now. Please try again.");
    }

    if ([self isAuthOrAppCheckError:error]) {
        NSString *text = PPFirebaseSessionCombinedErrorText(error);
        if ([text containsString:@"app check"] ||
            [text containsString:@"appcheck"] ||
            [text containsString:@"app attest"] ||
            [text containsString:@"appattest"] ||
            [text containsString:@"devicecheck"]) {
            return PPFirebaseSessionLocalizedString(@"pp_app_check_unavailable",
                                                   @"We could not verify this device right now. Please try again.");
        }
        return PPFirebaseSessionLocalizedString(@"pp_auth_session_refresh_failed",
                                               @"We could not refresh your session. Please try again.");
    }

    if (error.localizedDescription.length) {
        NSDictionary *directDescriptor = PPFirebaseSessionResolveChatErrorDescriptor(error.localizedDescription);
        if (directDescriptor) {
            return PPFirebaseSessionLocalizedString(directDescriptor[@"messageKey"],
                                                   directDescriptor[@"defaultMessage"]);
        }
        NSString *publicText = [self publicMessageForText:error.localizedDescription
                                              fallbackKey:fallbackKey];
        if (publicText.length && ![publicText isEqualToString:error.localizedDescription]) {
            return publicText;
        }
    }

    NSString *combinedText = PPFirebaseSessionCombinedErrorText(error);
    NSDictionary *combinedDescriptor = PPFirebaseSessionResolveChatErrorDescriptor(combinedText);
    if (combinedDescriptor) {
        return PPFirebaseSessionLocalizedString(combinedDescriptor[@"messageKey"],
                                               combinedDescriptor[@"defaultMessage"]);
    }

    NSString *fallback = PPFirebaseSessionLocalizedString(fallbackKey, @"");
    if (fallback.length) return fallback;
    if (error.localizedDescription.length) return error.localizedDescription;
    return PPFirebaseSessionFallbackMessage(fallbackKey);
}

+ (NSString *)publicChatTitleForError:(NSError * _Nullable)error
{
    if (!error || [self isAuthOrAppCheckError:error]) {
        return PPFirebaseSessionLocalizedString(@"chat_start_failed_title",
                                               @"Unable to Start Chat");
    }

    NSDictionary *descriptor =
        PPFirebaseSessionResolveChatErrorDescriptor(error.localizedDescription) ?:
        PPFirebaseSessionResolveChatErrorDescriptor(PPFirebaseSessionCombinedErrorText(error));
    if (descriptor) {
        return PPFirebaseSessionLocalizedString(descriptor[@"titleKey"],
                                               descriptor[@"defaultTitle"]);
    }

    return PPFirebaseSessionLocalizedString(@"chat_start_failed_title",
                                           @"Unable to Start Chat");
}

+ (NSString *)publicChatMessageForError:(NSError * _Nullable)error
                             fallbackKey:(NSString * _Nullable)fallbackKey
{
    NSString *effectiveFallbackKey = fallbackKey.length > 0 ? fallbackKey : @"chat_start_failed_message";
    if (!error) {
        return PPFirebaseSessionFallbackMessage(effectiveFallbackKey);
    }
    return [self publicMessageForError:error fallbackKey:effectiveFallbackKey];
}

@end
