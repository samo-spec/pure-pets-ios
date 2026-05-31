//
//  PPFirebaseSessionBridge.m
//  Pure Pets
//

#import "PPFirebaseSessionBridge.h"
#import <FirebaseAuth/FirebaseAuth.h>
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
        [user getIDTokenForcingRefresh:YES completion:^(__unused NSString * _Nullable token, NSError * _Nullable error) {
            if (error) {
                PPFirebaseSessionLogFailure(@"forced auth refresh", error);
                PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                                                                  @"pp_auth_session_refresh_failed",
                                                                                  @"We could not refresh your session. Please try again.",
                                                                                  error));
                return;
            }
            PPFirebaseSessionCompleteOnMain(completion, nil);
        }];
        return;
    }

    [user getIDTokenResultWithCompletion:^(FIRAuthTokenResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            PPFirebaseSessionLogFailure(@"cached auth token lookup", error);
            PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                                                              @"pp_auth_session_refresh_failed",
                                                                              @"We could not refresh your session. Please try again.",
                                                                              error));
            return;
        }

        NSDate *expiry = result.expirationDate ?: [NSDate distantPast];
        if ([expiry timeIntervalSinceNow] > 300) {
            PPFirebaseSessionCompleteOnMain(completion, nil);
            return;
        }

        [user getIDTokenForcingRefresh:YES completion:^(__unused NSString * _Nullable token, NSError * _Nullable forceError) {
            if (forceError) {
                PPFirebaseSessionLogFailure(@"expiring auth token refresh", forceError);
            }
            PPFirebaseSessionCompleteOnMain(completion,
                                            forceError ? PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                                                               @"pp_auth_session_refresh_failed",
                                                                               @"We could not refresh your session. Please try again.",
                                                                               forceError) : nil);
        }];
    }];
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
    [user getIDTokenForcingRefresh:forceAuth completion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error || token.length == 0) {
            if (!forceAuth) {
                [user getIDTokenForcingRefresh:YES completion:^(NSString * _Nullable refreshedToken, NSError * _Nullable refreshError) {
                    if (refreshError || refreshedToken.length == 0) {
                        if (refreshError) {
                            PPFirebaseSessionLogFailure(@"request auth token refresh fallback", refreshError);
                        } else {
                            NSLog(@"[PPFirebaseSessionBridge] request auth token refresh fallback failed: token was empty");
                        }
                        PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                                                                          @"pp_auth_session_refresh_failed",
                                                                                          @"We could not refresh your session. Please try again.",
                                                                                          refreshError ?: error));
                        return;
                    }
                    [request setValue:[NSString stringWithFormat:@"Bearer %@", refreshedToken] forHTTPHeaderField:@"Authorization"];
                    finishWithAppCheck();
                }];
                return;
            }
            if (error) {
                PPFirebaseSessionLogFailure(forceAuth ? @"forced request auth refresh" : @"request auth token lookup",
                                            error);
            } else {
                NSLog(@"[PPFirebaseSessionBridge] %@ failed: token was empty",
                      forceAuth ? @"forced request auth refresh" : @"request auth token lookup");
            }
            PPFirebaseSessionCompleteOnMain(completion, PPFirebaseSessionError(PPFirebaseSessionBridgeErrorCodeUnauthenticated,
                                                                              @"pp_auth_session_refresh_failed",
                                                                              @"We could not refresh your session. Please try again.",
                                                                              error));
            return;
        }
        [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
        finishWithAppCheck();
    }];
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
        return kLang(@"pp_app_check_unavailable") ?: @"We could not verify this device right now. Please try again.";
    }

    if ([self isAuthOrAppCheckError:error]) {
        NSString *text = PPFirebaseSessionCombinedErrorText(error);
        if ([text containsString:@"app check"] ||
            [text containsString:@"appcheck"] ||
            [text containsString:@"app attest"] ||
            [text containsString:@"appattest"] ||
            [text containsString:@"devicecheck"]) {
            return kLang(@"pp_app_check_unavailable") ?: @"We could not verify this device right now. Please try again.";
        }
        return kLang(@"pp_auth_session_refresh_failed") ?: @"We could not refresh your session. Please try again.";
    }

    NSString *fallback = fallbackKey.length ? (kLang(fallbackKey) ?: nil) : nil;
    if (fallback.length) return fallback;
    if (error.localizedDescription.length) return error.localizedDescription;
    return kLang(@"SomethingWentWrong") ?: @"Something went wrong.";
}

@end
