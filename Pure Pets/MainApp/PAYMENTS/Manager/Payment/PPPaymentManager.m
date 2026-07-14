//
//  PPPaymentManager.m
//  Pure Pets
//
//  Production-ready QIB payment manager (Simulator-safe)
//

#import "PPPaymentManager.h"
@import FirebaseFunctions;
@import FirebaseAuth;
@import FirebaseCore;
#if __has_include(<FirebaseAppCheck/FirebaseAppCheck.h>)
@import FirebaseAppCheck;
#define PP_PAYMENT_HAS_FIREBASE_APPCHECK 1
#else
#define PP_PAYMENT_HAS_FIREBASE_APPCHECK 0
#endif
#import "CountryModel.h"
#import "CitiesManager.h"
#import "PPFirebaseSessionBridge.h"
#import <SafariServices/SafariServices.h>
#import <objc/runtime.h>

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

@implementation UIViewController (QIBFullscreenPresentationFix)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(presentViewController:animated:completion:);
        SEL swizzledSelector = @selector(pp_qib_presentViewController:animated:completion:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod = class_addMethod(class,
                                            originalSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)pp_qib_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (viewControllerToPresent && [NSStringFromClass([viewControllerToPresent class]) containsString:@"QPWebViewController"]) {
        if (@available(iOS 13.0, *)) {
            if (viewControllerToPresent.modalPresentationStyle != UIModalPresentationFullScreen) {
                NSLog(@"[PPORDER] Forcing UIModalPresentationFullScreen for QIB WebViewController");
                viewControllerToPresent.modalPresentationStyle = UIModalPresentationFullScreen;
            }
        }
    }
    // Call original method
    [self pp_qib_presentViewController:viewControllerToPresent animated:flag completion:completion];
}
@end

@protocol PPPaymentQIBSendRequestCapable <NSObject>
- (void)sendRequest;
@end

@interface PPPaymentManager () <SFSafariViewControllerDelegate>

@property (nonatomic, strong) id qpParams; // intentionally id (avoids linker crash)
@property (nonatomic, copy) PPPaymentCompletion completion;

@property (nonatomic, copy) NSString *paymentAttemptId;
@property (nonatomic, assign) BOOL isRequestInFlight;
@property (nonatomic, copy) NSString *activeQIBSessionId;

// Orphaned-request detection: catches QIB SDK dismissals that never call qpResponse:.
@property (nonatomic, weak) UIViewController *paymentPresenterVC;
@property (nonatomic, assign) BOOL sdkDidPresent;
@property (nonatomic, strong) NSDate *requestStartDate;
@property (nonatomic, strong) SFSafariViewController *hostedCheckoutVC;

- (void)pp_prepareCallableAuthContextForOrder:(PPOrder *)order
                                    completion:(void (^)(NSString *idToken,
                                                         NSString *appCheckToken,
                                                         NSError *error))completion;
- (void)createQIBSessionForOrder:(PPOrder *)order
                        currency:(NSString *)currency
                  viewController:(UIViewController *)viewController
                           phone:(NSString *)phone
                         idToken:(NSString *)idToken
                   appCheckToken:(NSString *)appCheckToken
                allowQARFallback:(BOOL)allowQARFallback;
- (void)pp_startHostedQIBCheckoutWithURLString:(NSString *)urlString
                                         order:(PPOrder *)order
                                viewController:(UIViewController *)viewController;
#if !TARGET_OS_SIMULATOR
- (void)qpResponse:(NSDictionary *)response;
#endif

@end

static NSString * const PPPaymentOfficialEmailFallback = @"admin@pure-pets.net";

static UIViewController *PPPaymentTopViewControllerFromRoot(UIViewController *rootViewController)
{
    UIViewController *current = rootViewController;
    while (current) {
        UIViewController *next = current.presentedViewController;
        if (next && !next.isBeingDismissed) {
            current = next;
            continue;
        }
        if ([current isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)current).visibleViewController;
            if (visible && visible != current) {
                current = visible;
                continue;
            }
        }
        if ([current isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)current).selectedViewController;
            if (selected && selected != current) {
                current = selected;
                continue;
            }
        }
        break;
    }
    return current;
}

static UIWindow *PPPaymentActiveWindow(void)
{
    UIApplication *application = UIApplication.sharedApplication;
    UIWindow *fallbackWindow = application.keyWindow ?: application.windows.firstObject;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive &&
                windowScene.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }

            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }

            if (!fallbackWindow && windowScene.windows.count > 0) {
                fallbackWindow = windowScene.windows.firstObject;
            }
        }
    }

    return fallbackWindow;
}

static UIViewController *PPPaymentResolvedPresenter(UIViewController *preferredController)
{
    UIViewController *preferredTop = PPPaymentTopViewControllerFromRoot(preferredController);
    if (preferredTop.view.window) {
        return preferredTop;
    }

    UIWindow *window = preferredController.view.window ?: PPPaymentActiveWindow();
    UIViewController *windowTop = PPPaymentTopViewControllerFromRoot(window.rootViewController);
    return windowTop ?: preferredTop ?: preferredController;
}

static NSString *PPPaymentTrimmedString(NSString *value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPPaymentSafeString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return PPPaymentTrimmedString((NSString *)value);
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return PPPaymentTrimmedString([value stringValue]);
    }
    return @"";
}

static NSString *PPPaymentNormalizedStatusString(id value)
{
    NSString *normalized = [[PPPaymentSafeString(value) lowercaseString] copy];
    if (normalized.length == 0) return @"";

    normalized = [normalized stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([normalized containsString:@"__"]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return normalized;
}

static BOOL PPPaymentStatusMatchesAnyKeyword(NSString *status, NSArray<NSString *> *keywords)
{
    if (status.length == 0 || keywords.count == 0) return NO;

    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", status];
    for (NSString *keyword in keywords ?: @[]) {
        NSString *normalizedKeyword = PPPaymentNormalizedStatusString(keyword);
        if (normalizedKeyword.length == 0) continue;
        if ([status isEqualToString:normalizedKeyword]) return YES;
        if ([wrappedStatus containsString:[NSString stringWithFormat:@"_%@_", normalizedKeyword]]) return YES;
        if ([status containsString:normalizedKeyword]) return YES;
    }
    return NO;
}

static NSString *PPPaymentStatusFromStringCandidate(NSString *value)
{
    NSString *trimmed = PPPaymentTrimmedString(value);
    if (trimmed.length == 0) return @"";

    NSString *normalized = PPPaymentNormalizedStatusString(trimmed);
    if (normalized.length > 0 &&
        (PPPaymentStatusMatchesAnyKeyword(normalized, @[@"success", @"succeeded", @"paid", @"approved", @"authorized", @"captured", @"completed"]) ||
         PPPaymentStatusMatchesAnyKeyword(normalized, @[@"failed", @"failure", @"declined", @"rejected", @"cancelled", @"canceled", @"cancel", @"error", @"expired", @"voided", @"force_close", @"forceclose"]) ||
         PPPaymentStatusMatchesAnyKeyword(normalized, @[@"pending", @"processing", @"initiated", @"created", @"in_progress", @"verifying", @"verification_pending"]))) {
        return normalized;
    }

    NSString *lower = trimmed.lowercaseString;
    NSArray<NSString *> *patterns = @[
        @"status=success",
        @"status=succeeded",
        @"status=paid",
        @"status=approved",
        @"status=authorized",
        @"status=captured",
        @"status=completed",
        @"status=failed",
        @"status=failure",
        @"status=declined",
        @"status=rejected",
        @"status=cancelled",
        @"status=canceled",
        @"status=cancel",
        @"status=error",
        @"status=expired",
        @"status=voided",
        @"status=pending",
        @"status=processing",
        @"status=initiated",
        @"status=created",
        @"status=in_progress",
        @"status=verifying",
        @"status=verification_pending"
    ];
    for (NSString *pattern in patterns) {
        NSRange range = [lower rangeOfString:pattern];
        if (range.location == NSNotFound) continue;

        NSArray<NSString *> *parts = [pattern componentsSeparatedByString:@"="];
        return parts.count == 2 ? PPPaymentNormalizedStatusString(parts.lastObject) : @"";
    }

    return @"";
}

static NSString *PPPaymentExtractStringValueForKeys(id object, NSArray<NSString *> *keys, NSInteger depth)
{
    if (!object || depth > 4) return @"";

    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = (NSDictionary *)object;
        for (NSString *key in keys ?: @[]) {
            NSString *value = PPPaymentSafeString(dictionary[key]);
            if (value.length > 0) return value;
        }

        NSArray<NSString *> *nestedKeys = @[@"data", @"response", @"payload", @"result", @"paymentResponse", @"body"];
        for (NSString *nestedKey in nestedKeys) {
            NSString *nestedValue = PPPaymentExtractStringValueForKeys(dictionary[nestedKey], keys, depth + 1);
            if (nestedValue.length > 0) return nestedValue;
        }

        for (id value in dictionary.allValues) {
            NSString *nestedValue = PPPaymentExtractStringValueForKeys(value, keys, depth + 1);
            if (nestedValue.length > 0) return nestedValue;
        }
        return @"";
    }

    if ([object isKindOfClass:NSArray.class]) {
        for (id value in (NSArray *)object) {
            NSString *nestedValue = PPPaymentExtractStringValueForKeys(value, keys, depth + 1);
            if (nestedValue.length > 0) return nestedValue;
        }
        return @"";
    }

    return PPPaymentSafeString(object);
}

static NSString *PPPaymentExtractStatusFromResponseObject(id object, NSInteger depth)
{
    if (!object || depth > 4) return @"";

    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = (NSDictionary *)object;
        NSArray<NSString *> *keys = @[@"status", @"paymentStatus", @"transactionStatus", @"result", @"responseStatus"];
        for (NSString *key in keys) {
            NSString *status = PPPaymentStatusFromStringCandidate(PPPaymentSafeString(dictionary[key]));
            if (status.length > 0) return status;
        }

        NSArray<NSString *> *nestedKeys = @[@"data", @"response", @"payload", @"result", @"paymentResponse", @"body"];
        for (NSString *nestedKey in nestedKeys) {
            NSString *status = PPPaymentExtractStatusFromResponseObject(dictionary[nestedKey], depth + 1);
            if (status.length > 0) return status;
        }

        for (id value in dictionary.allValues) {
            NSString *status = PPPaymentExtractStatusFromResponseObject(value, depth + 1);
            if (status.length > 0) return status;
        }
        return @"";
    }

    if ([object isKindOfClass:NSArray.class]) {
        for (id value in (NSArray *)object) {
            NSString *status = PPPaymentExtractStatusFromResponseObject(value, depth + 1);
            if (status.length > 0) return status;
        }
        return @"";
    }

    return PPPaymentStatusFromStringCandidate(PPPaymentSafeString(object));
}

static NSString *PPPaymentExtractTransactionIdFromResponse(NSDictionary *response)
{
    return PPPaymentExtractStringValueForKeys(response,
                                              @[@"transactionId", @"transactionID", @"transaction_id", @"paymentId", @"paymentID", @"payment_id"],
                                              0);
}

static BOOL PPPaymentResponseIsCancellation(NSDictionary *response)
{
    // PPPaymentStatusFromStringCandidate now recognises "force_close" / "forceclose"
    // (added to the failure/cancel keyword group above), so the generic extractor
    // will return "force_close" when the QIB SDK sends {status: "force_close"} on dismiss.
    NSString *status = PPPaymentExtractStatusFromResponseObject(response, 0);
    return PPPaymentStatusMatchesAnyKeyword(status, @[@"cancelled", @"canceled", @"cancel", @"force_close", @"forceclose"]);
}

static BOOL PPPaymentResponseIsExplicitSuccess(NSDictionary *response)
{
    NSString *status = PPPaymentExtractStatusFromResponseObject(response, 0);
    return PPPaymentStatusMatchesAnyKeyword(status, @[@"success", @"succeeded", @"paid", @"approved", @"authorized", @"captured", @"completed"]);
}

static BOOL PPPaymentResponseIsExplicitFailure(NSDictionary *response)
{
    NSString *status = PPPaymentExtractStatusFromResponseObject(response, 0);
    return PPPaymentStatusMatchesAnyKeyword(status, @[@"failed", @"failure", @"declined", @"rejected", @"error", @"expired", @"voided"]);
}

static BOOL PPPaymentResponseHasTerminalResult(NSDictionary *response)
{
    NSString *status = PPPaymentExtractStatusFromResponseObject(response, 0);
    if (PPPaymentStatusMatchesAnyKeyword(status, @[@"success", @"succeeded", @"paid", @"approved", @"authorized", @"captured", @"completed"])) {
        return YES;
    }
    if (PPPaymentStatusMatchesAnyKeyword(status, @[@"failed", @"failure", @"declined", @"rejected", @"cancelled", @"canceled", @"cancel", @"error", @"expired", @"voided", @"force_close", @"forceclose"])) {
        return YES;
    }
    if (PPPaymentStatusMatchesAnyKeyword(status, @[@"pending", @"processing", @"initiated", @"created", @"in_progress", @"verifying", @"verification_pending"])) {
        // Pending/processing responses are NEVER terminal regardless of whether
        // a transactionId is present.  The QIB SDK sometimes returns a
        // transactionId alongside a pending status when the user cancels mid-flow.
        // Treating that as terminal would bypass cancellation detection and push
        // the app into a stuck verification/pending-review state.
        return NO;
    }

    NSString *transactionId = PPPaymentExtractTransactionIdFromResponse(response);
    return transactionId.length > 0;
}

static BOOL PPPaymentIsSupportedCheckoutCurrency(NSString *currencyCode)
{
    NSString *normalized = [PPPaymentTrimmedString(currencyCode).uppercaseString copy];
    if (normalized.length != 3) {
        return NO;
    }

    static NSSet<NSString *> *supportedCurrencies;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportedCurrencies = [NSSet setWithArray:@[@"QAR", @"USD", @"EUR", @"GBP", @"SAR", @"AED", @"KWD", @"BHD", @"OMR"]];
    });
    return [supportedCurrencies containsObject:normalized];
}

static NSString *PPPaymentCheckoutCurrencyOrDefault(NSString *currencyCode)
{
    NSString *normalized = [PPPaymentTrimmedString(currencyCode).uppercaseString copy];
    return PPPaymentIsSupportedCheckoutCurrency(normalized) ? normalized : @"QAR";
}

static NSString *PPPaymentResolvedCurrencyCode(void)
{
    return PPPaymentCheckoutCurrencyOrDefault([CountryModel safeCurrentCurrencyCode]);
}

static NSString *PPPaymentResolvedCountryISOCode(void)
{
    NSString *countryCode = [[CountryModel safeCurrentCountryISOCode] uppercaseString];
    return countryCode.length == 2 ? countryCode : @"QA";
}

static NSString *PPPaymentEffectiveCurrencyForOrder(PPOrder *order)
{
    NSString *currentCurrency = [PPPaymentTrimmedString([CountryModel safeCurrentCurrencyCode]).uppercaseString copy];
    if (PPPaymentIsSupportedCheckoutCurrency(currentCurrency)) {
        return currentCurrency;
    }

    return PPPaymentCheckoutCurrencyOrDefault(order.currency);
}

static NSString *PPPaymentFirstValidString(NSArray *values)
{
    for (id value in values ?: @[]) {
        NSString *trimmed = PPPaymentSafeString(value);
        if (trimmed.length > 0) {
            return trimmed;
        }
    }
    return @"";
}

static NSDictionary *PPPaymentResolvedSessionDictionary(NSDictionary *rawSession)
{
    if (![rawSession isKindOfClass:NSDictionary.class]) {
        return @{};
    }

    // Accept multiple Cloud Function response envelopes.
    id nested = rawSession[@"session"];
    if ([nested isKindOfClass:NSDictionary.class]) {
        return (NSDictionary *)nested;
    }
    nested = rawSession[@"data"];
    if ([nested isKindOfClass:NSDictionary.class]) {
        return (NSDictionary *)nested;
    }
    return rawSession;
}

static NSString *PPPaymentSessionValue(NSDictionary *session, NSArray<NSString *> *keys)
{
    for (NSString *key in keys ?: @[]) {
        NSString *value = PPPaymentSafeString(session[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPPaymentFunctionsRegion(void)
{
    NSString *configured = PPPaymentTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsRegion"]);
    return configured.length > 0 ? configured : @"us-central1";
}

static FIRFunctions *PPPaymentQIBFunctionsClient(void)
{
    NSString *customDomain = PPPaymentTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsCustomDomain"]);
    if (customDomain.length > 0) {
        return [FIRFunctions functionsForCustomDomain:customDomain];
    } else {
        return [FIRFunctions functionsForRegion:PPPaymentFunctionsRegion()];
    }
}


static NSString *PPPaymentFunctionsMessageCandidate(id value, NSInteger depth)
{
    if (!value || depth > 4) return @"";

    if ([value isKindOfClass:NSString.class]) {
        return PPPaymentTrimmedString((NSString *)value);
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = (NSDictionary *)value;
        NSArray<NSString *> *preferredKeys = @[
            @"message",
            @"error",
            @"reason",
            @"details",
            NSLocalizedFailureReasonErrorKey,
            NSLocalizedDescriptionKey
        ];
        for (NSString *key in preferredKeys) {
            NSString *candidate = PPPaymentFunctionsMessageCandidate(dictionary[key], depth + 1);
            if (candidate.length > 0) {
                return candidate;
            }
        }

        for (id nestedValue in dictionary.allValues) {
            NSString *candidate = PPPaymentFunctionsMessageCandidate(nestedValue, depth + 1);
            if (candidate.length > 0) {
                return candidate;
            }
        }
        return @"";
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id nestedValue in (NSArray *)value) {
            NSString *candidate = PPPaymentFunctionsMessageCandidate(nestedValue, depth + 1);
            if (candidate.length > 0) {
                return candidate;
            }
        }
        return @"";
    }
    if ([value isKindOfClass:NSError.class]) {
        NSError *nestedError = (NSError *)value;
        NSString *candidate = PPPaymentFunctionsMessageCandidate(nestedError.userInfo, depth + 1);
        if (candidate.length > 0) {
            return candidate;
        }

        candidate = PPPaymentTrimmedString(nestedError.localizedFailureReason);
        if (candidate.length > 0) {
            return candidate;
        }

        return PPPaymentTrimmedString(nestedError.localizedDescription);
    }

    return PPPaymentSafeString(value);
}

static NSString *PPPaymentLocalizedKnownBackendMessage(NSString *message)
{
    NSString *trimmed = PPPaymentTrimmedString(message);
    if (trimmed.length == 0) return @"";

    NSString *lowercase = trimmed.lowercaseString;
    if ([lowercase containsString:@"order not found"]) {
        return kLang(@"payment_backend_order_not_found");
    }
    if ([lowercase containsString:@"order is no longer pending"]) {
        return kLang(@"payment_backend_order_not_pending");
    }
    if ([lowercase containsString:@"requested amount does not match the order total"]) {
        return kLang(@"payment_backend_amount_changed");
    }
    if ([lowercase containsString:@"online payment is currently unavailable"]) {
        return kLang(@"payment_backend_online_payment_disabled");
    }
    return trimmed;
}

static NSString *PPPaymentFunctionsServerMessageFromError(NSError *error)
{
    if (!error) return @"";

    NSString *candidate = PPPaymentFunctionsMessageCandidate(error.userInfo, 0);
    if (candidate.length == 0) {
        candidate = PPPaymentTrimmedString(error.localizedFailureReason);
    }
    if (candidate.length == 0) {
        candidate = PPPaymentTrimmedString(error.localizedDescription);
    }
    return PPPaymentLocalizedKnownBackendMessage(candidate);
}

static BOOL PPPaymentTextContainsAnyToken(NSString *text, NSArray<NSString *> *tokens)
{
    NSString *lowercase = [PPPaymentTrimmedString(text).lowercaseString copy];
    if (lowercase.length == 0) return NO;
    for (NSString *token in tokens ?: @[]) {
        if (![token isKindOfClass:NSString.class] || token.length == 0) continue;
        if ([lowercase containsString:token.lowercaseString]) {
            return YES;
        }
    }
    return NO;
}

static BOOL PPPaymentErrorLooksLikeAppCheck(NSError *error, NSString *serverMessage)
{
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@",
                          error.domain ?: @"",
                          error.localizedDescription ?: @"",
                          error.localizedFailureReason ?: @"",
                          serverMessage ?: @""];
    return PPPaymentTextContainsAnyToken(combined, @[
        @"app check", @"appcheck", @"app attest", @"appattest", @"devicecheck"
    ]);
}

static BOOL PPPaymentErrorLooksLikeAuth(NSError *error, NSString *serverMessage)
{
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@",
                          error.domain ?: @"",
                          error.localizedDescription ?: @"",
                          error.localizedFailureReason ?: @"",
                          serverMessage ?: @""];
    return PPPaymentTextContainsAnyToken(combined, @[
        @"unauthenticated", @"auth token", @"id token", @"refresh your session"
    ]);
}

static BOOL PPPaymentErrorLooksLikeUnsafeInternal(NSError *error, NSString *serverMessage)
{
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@",
                          error.domain ?: @"",
                          error.localizedDescription ?: @"",
                          error.localizedFailureReason ?: @"",
                          serverMessage ?: @""];
    return PPPaymentTextContainsAnyToken(combined, @[
        @"internal error", @"print and inspect", @"firebasefunctions"
    ]);
}

static FIRFunctionsErrorCode PPPaymentFunctionsErrorCodeFromStatus(NSString *status)
{
    NSString *normalized = [PPPaymentTrimmedString(status).uppercaseString copy];
    if ([normalized isEqualToString:@"INVALID_ARGUMENT"]) return FIRFunctionsErrorCodeInvalidArgument;
    if ([normalized isEqualToString:@"FAILED_PRECONDITION"]) return FIRFunctionsErrorCodeFailedPrecondition;
    if ([normalized isEqualToString:@"NOT_FOUND"]) return FIRFunctionsErrorCodeNotFound;
    if ([normalized isEqualToString:@"PERMISSION_DENIED"]) return FIRFunctionsErrorCodePermissionDenied;
    if ([normalized isEqualToString:@"UNAUTHENTICATED"]) return FIRFunctionsErrorCodeUnauthenticated;
    if ([normalized isEqualToString:@"UNAVAILABLE"]) return FIRFunctionsErrorCodeUnavailable;
    if ([normalized isEqualToString:@"DEADLINE_EXCEEDED"]) return FIRFunctionsErrorCodeDeadlineExceeded;
    if ([normalized isEqualToString:@"UNIMPLEMENTED"]) return FIRFunctionsErrorCodeUnimplemented;
    if ([normalized isEqualToString:@"INTERNAL"]) return FIRFunctionsErrorCodeInternal;
    if ([normalized isEqualToString:@"CANCELLED"]) return FIRFunctionsErrorCodeCancelled;
    return FIRFunctionsErrorCodeUnknown;
}

static FIRFunctionsErrorCode PPPaymentFunctionsErrorCodeFromHTTPStatus(NSInteger statusCode)
{
    if (statusCode == 400) return FIRFunctionsErrorCodeInvalidArgument;
    if (statusCode == 401) return FIRFunctionsErrorCodeUnauthenticated;
    if (statusCode == 403) return FIRFunctionsErrorCodePermissionDenied;
    if (statusCode == 404) return FIRFunctionsErrorCodeNotFound;
    if (statusCode == 409) return FIRFunctionsErrorCodeFailedPrecondition;
    if (statusCode == 412) return FIRFunctionsErrorCodeFailedPrecondition;
    if (statusCode == 501) return FIRFunctionsErrorCodeUnimplemented;
    if (statusCode == 503) return FIRFunctionsErrorCodeUnavailable;
    if (statusCode == 504) return FIRFunctionsErrorCodeDeadlineExceeded;
    return FIRFunctionsErrorCodeUnknown;
}

static BOOL PPPaymentShouldRetryWithQARForCallableError(NSError *error)
{
    if (!error) return NO;

    if (error.code != FIRFunctionsErrorCodeInvalidArgument &&
        error.code != FIRFunctionsErrorCodeFailedPrecondition) {
        return NO;
    }

    NSString *message = PPPaymentFunctionsServerMessageFromError(error).lowercaseString;
    if (message.length == 0) {
        return NO;
    }

    return ([message containsString:@"currency"] &&
            ([message containsString:@"unsupported"] ||
             [message containsString:@"invalid"] ||
             [message containsString:@"qar"]));
}

static NSString *PPPaymentFriendlyFunctionsErrorMessage(NSError *error)
{
    if (!error) return @"";

    NSString *domain = [PPPaymentTrimmedString(error.domain).lowercaseString copy];
    BOOL isFunctionsError = [domain containsString:@"functions"];
    NSString *serverMessage = PPPaymentFunctionsServerMessageFromError(error);
    if (PPPaymentErrorLooksLikeAppCheck(error, serverMessage)) {
        return kLang(@"pp_app_check_unavailable");
    }
    if (PPPaymentErrorLooksLikeAuth(error, serverMessage)) {
        return kLang(@"pp_auth_session_refresh_failed");
    }
    if (PPPaymentErrorLooksLikeUnsafeInternal(error, serverMessage)) {
        return kLang(@"payment_backend_unreachable");
    }
    if (!isFunctionsError) {
        return serverMessage;
    }

    switch ((FIRFunctionsErrorCode)error.code) {
        case FIRFunctionsErrorCodeUnimplemented:
            return kLang(@"payment_backend_unavailable");
        case FIRFunctionsErrorCodeNotFound:
            return serverMessage.length > 0 ? serverMessage : kLang(@"payment_backend_order_not_found");
        case FIRFunctionsErrorCodeUnauthenticated:
            if ([FIRAuth auth].currentUser.uid.length > 0) {
                return kLang(@"payment_backend_unreachable");
            }
            return kLang(@"auth_register_required_title");
        case FIRFunctionsErrorCodePermissionDenied:
            return kLang(@"payment_backend_permission_denied");
        case FIRFunctionsErrorCodeInternal:
            return kLang(@"payment_backend_unreachable");
        case FIRFunctionsErrorCodeDeadlineExceeded:
        case FIRFunctionsErrorCodeUnavailable:
            return kLang(@"payment_backend_unreachable");
        case FIRFunctionsErrorCodeFailedPrecondition:
            return serverMessage.length > 0 ? serverMessage : kLang(@"payment_backend_setup_incomplete");
        default:
            return serverMessage;
    }
}

static BOOL PPPaymentTrySetValueForKey(id target, NSString *key, id value)
{
    if (!target || key.length == 0 || !value) {
        return NO;
    }
    @try {
        [target setValue:value forKey:key];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static void PPPaymentSetValueForCandidateKeys(id target, NSArray<NSString *> *keys, id value)
{
    for (NSString *candidate in keys ?: @[]) {
        if (PPPaymentTrySetValueForKey(target, candidate, value)) {
            return;
        }
    }
}

static BOOL PPPaymentShouldRequireHostedQIBCheckoutForRuntime(void)
{
    // Phase 2 hosted checkout is not yet implemented on the server.
    // Allow legacy QIB SDK (Phase 1) on all iOS versions for now.
    return NO;
}

static NSURL *PPPaymentHostedCheckoutURLFromString(NSString *urlString)
{
    NSString *trimmed = PPPaymentTrimmedString(urlString);
    if (trimmed.length == 0) {
        return nil;
    }

    NSURLComponents *components = [NSURLComponents componentsWithString:trimmed];
    NSString *scheme = components.scheme.lowercaseString ?: @"";
    if (![scheme isEqualToString:@"https"] || components.host.length == 0) {
        return nil;
    }
    return components.URL;
}

static NSDictionary *PPPaymentHostedCheckoutClosedResponse(void)
{
    return @{
        @"source": @"qib_hosted_checkout",
        @"status": @"hosted_checkout_closed",
        @"verification": @"server_authoritative"
    };
}

#if !TARGET_OS_SIMULATOR
static void PPQIBTryLoadFrameworkBundle(void)
{
    NSString *frameworksPath = [[NSBundle mainBundle] privateFrameworksPath];
    if (frameworksPath.length == 0) return;

    NSString *bundlePath = [frameworksPath stringByAppendingPathComponent:@"QIBPayment.framework"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    if (!bundle || bundle.isLoaded) return;

    NSError *loadError = nil;
    BOOL loaded = [bundle loadAndReturnError:&loadError];
    if (!loaded && loadError) {
        PPORDERLog(@"Unable to load QIBPayment.framework | error=%@", loadError.localizedDescription ?: @"Unknown");
    }
}
#endif

@implementation PPPaymentManager



+ (instancetype)shared
{
    static PPPaymentManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [PPPaymentManager new];
    });
    return mgr;
}

- (NSError *)pp_callableAuthContextErrorWithMessage:(NSString *)message
                                               code:(NSInteger)code
                                         underlying:(NSError *)underlying
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = message.length > 0 ? message : kLang(@"payment_backend_unreachable");
    if (underlying) {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:@"PPPayment" code:code userInfo:userInfo];
}

- (void)pp_prepareAppCheckContextForOrder:(PPOrder *)order
                                  idToken:(NSString *)idToken
                               completion:(void (^)(NSString *idToken,
                                                    NSString *appCheckToken,
                                                    NSError *error))completion
{
#if PP_PAYMENT_HAS_FIREBASE_APPCHECK
    [[FIRAppCheck appCheck] tokenForcingRefresh:YES completion:^(FIRAppCheckToken *token, NSError *error) {
        if (error || token.token.length == 0) {
            PPORDERLog(@"Payment App Check context failed | orderId=%@ | error=%@",
                       order.orderId ?: @"",
                       error.localizedDescription ?: @"missing_app_check_token");
            NSError *contextError =
            [self pp_callableAuthContextErrorWithMessage:kLang(@"payment_backend_unreachable")
                                                     code:401
                                               underlying:error];
            if (completion) {
                completion(idToken ?: @"", @"", contextError);
            }
            return;
        }

        PPORDERLog(@"Payment App Check context ready | orderId=%@ | tokenPresent=1 | tokenType=regular",
                   order.orderId ?: @"");
        if (completion) {
            completion(idToken ?: @"", token.token ?: @"", nil);
        }
    }];
#else
    NSError *contextError =
    [self pp_callableAuthContextErrorWithMessage:kLang(@"payment_backend_unreachable")
                                             code:401
                                       underlying:nil];
    if (completion) {
        completion(idToken ?: @"", @"", contextError);
    }
#endif
}

- (void)pp_prepareCallableAuthContextForOrder:(PPOrder *)order
                                    completion:(void (^)(NSString *idToken,
                                                         NSString *appCheckToken,
                                                         NSError *error))completion
{
    FIRUser *user = [FIRAuth auth].currentUser;
    NSString *uid = user.uid ?: @"";
    if (uid.length == 0) {
        NSError *contextError =
        [self pp_callableAuthContextErrorWithMessage:kLang(@"auth_register_required_subtitle")
                                                 code:401
                                           underlying:nil];
        if (completion) {
            completion(@"", @"", contextError);
        }
        return;
    }

    [user getIDTokenForcingRefresh:NO completion:^(NSString *token, NSError *error) {
        if (!error && token.length > 0) {
            PPORDERLog(@"Payment Auth context ready | orderId=%@ | uidPresent=1",
                       order.orderId ?: @"");
            [self pp_prepareAppCheckContextForOrder:order idToken:token completion:completion];
            return;
        }

        PPORDERLog(@"Payment Auth context cached token failed | orderId=%@ | uidPresent=%d | error=%@",
                   order.orderId ?: @"",
                   uid.length > 0,
                   error.localizedDescription ?: @"missing_id_token");
        [PPFirebaseSessionBridge ensureFreshAuthSessionForcingRefresh:YES completion:^(NSError * _Nullable authError) {
            if (authError) {
                PPORDERLog(@"Payment Auth context failed | orderId=%@ | uidPresent=%d | error=%@",
                           order.orderId ?: @"",
                           uid.length > 0,
                           authError.localizedDescription ?: @"missing_id_token");
                if (completion) {
                    completion(@"", @"", authError);
                }
                return;
            }

            [user getIDTokenForcingRefresh:NO completion:^(NSString *refreshedToken, NSError *refreshedError) {
                if (refreshedError || refreshedToken.length == 0) {
                    PPORDERLog(@"Payment Auth context refresh replay failed | orderId=%@ | uidPresent=%d | error=%@",
                               order.orderId ?: @"",
                               uid.length > 0,
                               refreshedError.localizedDescription ?: @"missing_id_token");
                    if (completion) {
                        completion(@"", @"", refreshedError);
                    }
                    return;
                }

                PPORDERLog(@"Payment Auth context repaired | orderId=%@ | uidPresent=1",
                           order.orderId ?: @"");
                [self pp_prepareAppCheckContextForOrder:order idToken:refreshedToken completion:completion];
            }];
        }];
    }];
}

- (void)startPaymentForOrder:(PPOrder *)order
          fromViewController:(UIViewController *)viewController
                  completion:(PPPaymentCompletion)completion
{
    PPORDERLog(@"Payment request started | orderId=%@ | workflowStatus=%@ | paymentStatus=%@ | method=%@",
               order.orderId ?: @"",
               order.rawStatus ?: @"",
               order.paymentStatus ?: @"",
               order.paymentMethodId ?: @"");
    if (!order) {
        NSError *orderMissingError =
        [NSError errorWithDomain:@"PPPayment"
                            code:400
                        userInfo:@{NSLocalizedDescriptionKey:
                                       kLang(@"checkout_invalid_order")}];
        if (completion) {
            completion(nil, orderMissingError);
        }
        return;
    }

    if (order.status != PPOrderStatusPending) {
        NSError *invalidStateError =
        [NSError errorWithDomain:@"PPPayment"
                            code:409
                        userInfo:@{NSLocalizedDescriptionKey:
                                       kLang(@"payment_request_invalid_state")}];
        if (completion) {
            completion(nil, invalidStateError);
        }
        return;
    }

    // Auto-reset stale requests: if a previous payment has been in-flight
    // for over 2 minutes, the QIB SDK almost certainly dismissed without
    // calling qpResponse:.  Reset so the user can retry.
    if (self.isRequestInFlight && self.requestStartDate) {
        NSTimeInterval elapsed = -[self.requestStartDate timeIntervalSinceNow];
        if (elapsed > 120) {
            PPORDERLog(@"Auto-resetting stale payment request | elapsed=%.0fs", elapsed);
            [self reset];
        }
    }

    if (self.isRequestInFlight) {
        NSError *inFlightError =
        [NSError errorWithDomain:@"PPPayment"
                            code:409
                        userInfo:@{NSLocalizedDescriptionKey:
                                       kLang(@"payment_request_in_progress")}];
        if (completion) {
            completion(nil, inFlightError);
        }
        return;
    }

    self.completion = completion;

    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length == 0) {
        [self failWithMessage:kLang(@"auth_register_required_subtitle")];
        return;
    }

#if TARGET_OS_SIMULATOR
    [self failWithMessage:kLang(@"payment_requires_real_device")];
    return;
#endif

    NSString *phone = [self normalizedPhoneForQIBForOrder:order];
    if (phone.length == 0) {
        PPORDERLog(@"Payment blocked | reason=missing_phone | orderId=%@", order.orderId ?: @"");
        [self failWithMessage:kLang(@"payment_phone_required")];
        return;
    }

    self.isRequestInFlight = YES;
    self.requestStartDate = [NSDate date];
    self.paymentAttemptId = [NSUUID UUID].UUIDString;
    NSString *requestedCurrency = PPPaymentEffectiveCurrencyForOrder(order);
    if (requestedCurrency.length == 3) {
        order.currency = requestedCurrency;
    }

    __weak typeof(self) weakSelf = self;
    [PPFirebaseSessionBridge ensureFreshAuthSessionForcingRefresh:NO completion:^(NSError * _Nullable authError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isRequestInFlight) {
            PPORDERLog(@"Payment request cancelled before session start | orderId=%@",
                       order.orderId ?: @"");
            return;
        }
        if (authError) {
            PPORDERLog(@"Payment auth bridge preflight failed | orderId=%@ | error=%@",
                       order.orderId ?: @"",
                       authError.localizedDescription ?: @"");
            [self failWithError:authError];
            return;
        }

        // FIRFunctions attaches App Check automatically from AppDelegate's provider.
        // Keep this bridge auth-only so iOS devices do not hit forced App Attest
        // re-attestation before opening the QIB SDK.
        [self createQIBSessionForOrder:order
                              currency:requestedCurrency
                        viewController:viewController
                                 phone:phone
                               idToken:@""
                         appCheckToken:@""
                      allowQARFallback:YES];
    }];
}

#pragma mark - QIB Callbacks (Device only)

#if !TARGET_OS_SIMULATOR
- (void)qpResponse:(NSDictionary *)response
{
    // Guard: ignore if already reset (prevents double-callback from QIB SDK)
    if (!self.completion) {
        PPORDERLog(@"Ignoring QIB callback after reset | keys=%@",
                   ([response isKindOfClass:NSDictionary.class] ? [response allKeys] : @[]));
        return;
    }

    NSDictionary *safeResponse = [response isKindOfClass:NSDictionary.class] ? response : @{};

    // Only treat as cancellation when the SDK explicitly signals it.
    // Non-terminal and ambiguous responses (empty dict, unknown status,
    // transactionId without a status) are forwarded to verifyQibPayment so
    // the server can authoritatively check with QIB's gateway.  This prevents
    // real payments from being silently lost when the SDK's status is unclear
    // — the server will return "failure" if no payment was made, giving the
    // user a retryable error instead of an invisible dropped payment.
    BOOL looksLikeCancellation = PPPaymentResponseIsCancellation(safeResponse);

    NSString *statusForLog = PPPaymentExtractStatusFromResponseObject(safeResponse, 0) ?: @"(empty)";
    BOOL isTerminal = PPPaymentResponseHasTerminalResult(safeResponse);
    BOOL isExplicitSuccess = PPPaymentResponseIsExplicitSuccess(safeResponse);
    BOOL isExplicitFailure = PPPaymentResponseIsExplicitFailure(safeResponse);
    PPORDERLog(@"QIB callback received | terminal=%d | success=%d | failure=%d | cancellation=%d | status=%@ | keys=%@",
               isTerminal, isExplicitSuccess, isExplicitFailure, looksLikeCancellation,
               statusForLog, safeResponse.allKeys ?: @[]);

    // Capture completion and reset BEFORE invoking the callback.
    // This prevents re-entrant or duplicate callbacks from corrupting state.
    PPPaymentCompletion capturedCompletion = self.completion;
    [self reset];

    if (looksLikeCancellation) {
        PPORDERLog(@"QIB payment cancelled by user | status=%@",
                   PPPaymentExtractStatusFromResponseObject(safeResponse, 0) ?: @"(empty)");
        NSError *cancelError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSUserCancelledError
                        userInfo:@{NSLocalizedDescriptionKey: kLang(@"payment_cancelled_by_user")}];
        capturedCompletion(safeResponse, cancelError);
        return;
    }

    capturedCompletion(safeResponse, nil);
}
#endif

#pragma mark - Hosted QIB Checkout

- (void)pp_startHostedQIBCheckoutWithURLString:(NSString *)urlString
                                         order:(PPOrder *)order
                                viewController:(UIViewController *)viewController
{
    NSURL *checkoutURL = PPPaymentHostedCheckoutURLFromString(urlString);
    if (!checkoutURL) {
        PPORDERLog(@"Hosted QIB checkout blocked | reason=invalid_payment_url | orderId=%@",
                   order.orderId ?: @"");
        [self failWithMessage:kLang(@"payment_secure_session_unavailable")];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = PPPaymentResolvedPresenter(viewController);
        if (!presenter) {
            PPORDERLog(@"Hosted QIB checkout blocked | reason=no_presenter | orderId=%@",
                       order.orderId ?: @"");
            [self failWithMessage:kLang(@"payment_unable_to_open_screen")];
            return;
        }

        SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:checkoutURL];
        safariVC.delegate = self;
        safariVC.modalPresentationStyle = UIModalPresentationFullScreen;
        if (@available(iOS 10.0, *)) {
            safariVC.preferredControlTintColor = AppPrimaryClr;
        }

        self.hostedCheckoutVC = safariVC;
        self.paymentPresenterVC = presenter;
        self.sdkDidPresent = YES;
        PPORDERLog(@"Launching hosted QIB checkout | orderId=%@ | qibSessionId=%@",
                   order.orderId ?: @"",
                   self.activeQIBSessionId ?: @"");
        [presenter presentViewController:safariVC animated:YES completion:nil];
    });
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    if (controller != self.hostedCheckoutVC) {
        return;
    }

    PPPaymentCompletion capturedCompletion = self.completion;
    NSDictionary *response = PPPaymentHostedCheckoutClosedResponse();
    self.hostedCheckoutVC = nil;
    [self reset];

    if (capturedCompletion) {
        capturedCompletion(response, nil);
    }
}

#pragma mark - QIB Launch

- (void)startQIBWithSession:(NSDictionary *)session
                      order:(PPOrder *)order
            viewController:(UIViewController *)vc
                     phone:(NSString *)phone
          requestedCurrency:(NSString *)requestedCurrency
{
    NSDictionary *resolvedSession = PPPaymentResolvedSessionDictionary(session);
    NSString *gatewayId = PPPaymentSessionValue(resolvedSession, @[
        @"gatewayId", @"gatewayID", @"GatewayId", @"gateway_id"
    ]);
    // TODO(H-14-phase2): Remove secretKey extraction — Phase 2 uses paymentUrl instead.
    NSString *secretKey = PPPaymentSessionValue(resolvedSession, @[
        @"secretKey", @"secret", @"SecretKey", @"secret_key"
    ]);
    NSString *sessionToken = PPPaymentSessionValue(resolvedSession, @[
        @"sessionToken", @"token", @"session_token"
    ]);
    NSString *paymentURL = PPPaymentSessionValue(resolvedSession, @[
        @"paymentUrl", @"paymentURL", @"hostedPaymentUrl", @"hosted_url"
    ]);
    NSString *serverPaymentAttemptId = PPPaymentSessionValue(resolvedSession, @[
        @"paymentAttemptId", @"payment_attempt_id"
    ]);
    NSString *serverQibSessionId = PPPaymentSessionValue(resolvedSession, @[
        @"sessionId", @"qibSessionId", @"qib_session_id"
    ]);
    if (serverPaymentAttemptId.length > 0) {
        self.paymentAttemptId = serverPaymentAttemptId;
        order.paymentAttemptId = serverPaymentAttemptId;
    }
    if (serverQibSessionId.length > 0) {
        self.activeQIBSessionId = serverQibSessionId;
        order.qibSessionId = serverQibSessionId;
    }
    // Validate binding IDs — without these, QIB payment may succeed but
    // server-side verification will fail, leaving the order stuck in pending.
    if (serverPaymentAttemptId.length == 0 || serverQibSessionId.length == 0) {
        PPORDERLog(@"Session missing binding IDs | orderId=%@ | hasAttemptId=%d | hasSessionId=%d",
                   order.orderId ?: @"",
                   (serverPaymentAttemptId.length > 0),
                   (serverQibSessionId.length > 0));
        [self failWithMessage:kLang(@"payment_session_incomplete")];
        return;
    }

    if (paymentURL.length > 0) {
        PPORDERLog(@"Using hosted QIB checkout | orderId=%@ | qibSessionId=%@",
                   order.orderId ?: @"",
                   self.activeQIBSessionId ?: @"");
        [self pp_startHostedQIBCheckoutWithURLString:paymentURL
                                               order:order
                                      viewController:vc];
        return;
    }

    if (PPPaymentShouldRequireHostedQIBCheckoutForRuntime()) {
        PPORDERLog(@"Legacy QIB SDK blocked on this iOS runtime | orderId=%@ | hasPaymentURL=%d | hasToken=%d",
                   order.orderId ?: @"",
                   (paymentURL.length > 0),
                   (sessionToken.length > 0));
        [self failWithMessage:kLang(@"payment_secure_flow_required")];
        return;
    }

    if (gatewayId.length == 0 || secretKey.length == 0) {
        [self failWithMessage:kLang(@"payment_secure_session_unavailable")];
        return;
    }

    // ─── H-14 LEGACY FLOW (PHASE 1) ────────────────────────────────────────
    // The QIB SDK (QPRequestParameters) requires secretKey on the client.
    // The secret is fetched from the createQibSession Cloud Function, which
    // reads it from Firebase Secret Manager — it is NOT embedded in the binary.
    //
    // However, the secret still transits through the client, which is a
    // residual security risk. This path is only used on iOS runtimes where
     // checkout contract above.
    //
    // Migration checklist (H-14-phase2):
     //   [ ] createQibSession Cloud Function returns paymentUrl instead of secretKey
    //   [x] iOS opens paymentUrl in SFSafariViewController (see gate above)
    //   [ ] Remove QPRequestParameters + secretKey injection below
    //   [ ] Remove PPQIBTryLoadFrameworkBundle dependency
    // ────────────────────────────────────────────────────────────────────────
    PPORDERLog(@"Using legacy QIB bootstrap | orderId=%@ | currency=%@",
               order.orderId ?: @"",
               requestedCurrency ?: @"");
    if (secretKey.length > 0) {
        PPORDERLog(@"QIB session contains server-managed secret bootstrap | orderId=%@", order.orderId ?: @"");
    }

    dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_SIMULATOR
        PPQIBTryLoadFrameworkBundle();
#endif

        UIViewController *presenter = PPPaymentResolvedPresenter(vc);
        if (!presenter) {
            PPORDERLog(@"Payment blocked | reason=no_presenter | orderId=%@", order.orderId ?: @"");
            [self failWithMessage:kLang(@"payment_unable_to_open_screen")];
            return;
        }
        PPORDERLog(@"Resolved payment presenter | orderId=%@ | presenter=%@",
                   order.orderId ?: @"",
                   NSStringFromClass(presenter.class));

        Class paramsClass = Nil;
        NSArray<NSString *> *candidateClassNames = @[
            @"QPRequestParameters",
            @"QIBPayment.QPRequestParameters",
            @"_TtC10QIBPayment19QPRequestParameters"
        ];
        for (NSString *candidate in candidateClassNames) {
            Class resolved = NSClassFromString(candidate);
            if (resolved) {
                paramsClass = resolved;
                break;
            }
        }
        if (!paramsClass) {
            PPORDERLog(@"QIB SDK class missing | orderId=%@", order.orderId ?: @"");
            [self failWithMessage:kLang(@"payment_qib_sdk_missing")];
            return;
        }

        SEL initSelector = @selector(initWithViewController:);
        id params = nil;
        if ([paramsClass instancesRespondToSelector:initSelector]) {
            id allocInstance = [paramsClass alloc];
            IMP imp = [allocInstance methodForSelector:initSelector];
            id (*initWithVC)(id, SEL, UIViewController *) = (id (*)(id, SEL, UIViewController *))imp;
            params = initWithVC(allocInstance, initSelector, presenter);
            PPORDERLog(@"QIB SDK params initialized via initWithViewController: | orderId=%@ | class=%@",
                       order.orderId ?: @"", NSStringFromClass(paramsClass));
        } else if ([paramsClass instancesRespondToSelector:@selector(init)]) {
            params = [[paramsClass alloc] init];
            PPORDERLog(@"QIB SDK params initialized via init (no initWithViewController:) | orderId=%@ | class=%@",
                       order.orderId ?: @"", NSStringFromClass(paramsClass));
        } else {
            PPORDERLog(@"QIB SDK params class responds to neither initWithViewController: nor init | orderId=%@ | class=%@",
                       order.orderId ?: @"", NSStringFromClass(paramsClass));
        }

        if (!params) {
            PPORDERLog(@"QIB SDK init failed | orderId=%@", order.orderId ?: @"");
            [self failWithMessage:kLang(@"payment_qib_sdk_init_failed")];
            return;
        }

        // Some SDK variants expose parent/view controller as a writable property
        // instead of an init argument.
        PPPaymentSetValueForCandidateKeys(params, @[@"parentViewController", @"viewController"], presenter);
        PPPaymentSetValueForCandidateKeys(params, @[@"delegate"], self);

    NSString *mode = PPPaymentSessionValue(resolvedSession, @[
        @"mode", @"paymentMode", @"environment", @"env"
    ]);
    if (mode.length == 0) {
        mode = @"live";
    }

    NSString *sessionCurrency = PPPaymentSessionValue(resolvedSession, @[
        @"currency", @"currencyCode"
    ]).uppercaseString;
    if (sessionCurrency.length != 3) {
        sessionCurrency = PPPaymentTrimmedString(requestedCurrency).uppercaseString;
    }
    if (sessionCurrency.length != 3) {
        sessionCurrency = PPPaymentTrimmedString(order.currency).uppercaseString;
    }
    if (sessionCurrency.length != 3) {
        sessionCurrency = PPPaymentResolvedCurrencyCode();
    }
    if (sessionCurrency.length != 3) {
        sessionCurrency = @"QAR";
    }
    order.currency = sessionCurrency;

    PPORDERLog(@"Launching legacy QIB bootstrap | orderId=%@ | mode=%@ | currency=%@ | requestedCurrency=%@ | qibSessionId=%@",
               order.orderId ?: @"",
               mode ?: @"",
               sessionCurrency ?: @"",
               requestedCurrency ?: @"",
               self.activeQIBSessionId ?: @"");

        NSDictionary *shipping = [order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]
            ? order.shippingAddressSnapshot
            : @{};
        NSString *addressLine1 = [shipping[@"addressLine1"] isKindOfClass:NSString.class]
            ? shipping[@"addressLine1"]
            : @"";
        NSString *fallbackLocation = [shipping[@"locatioName"] isKindOfClass:NSString.class]
            ? shipping[@"locatioName"]
            : @"";
        NSString *displayName = [shipping[@"displayName"] isKindOfClass:NSString.class]
            ? shipping[@"displayName"]
            : @"";

        NSString *countryISO = PPPaymentResolvedCountryISOCode();

        NSNumber *amountNumber = @((order.totalAmount > 0 ? order.totalAmount : order.amount));
        PPPaymentSetValueForCandidateKeys(params, @[@"gatewayId", @"gatewayID", @"GatewayId", @"gateway_id"], gatewayId);
        PPPaymentSetValueForCandidateKeys(params, @[@"secretKey", @"secret", @"SecretKey", @"secret_key"], secretKey);
        PPPaymentSetValueForCandidateKeys(params, @[@"mode", @"paymentMode", @"environment", @"env"], mode);
        PPPaymentSetValueForCandidateKeys(params, @[@"amount"], amountNumber);
        PPPaymentSetValueForCandidateKeys(params, @[@"currency", @"currencyCode"], sessionCurrency);
        PPPaymentSetValueForCandidateKeys(params, @[@"referenceId", @"referenceID", @"reference_id"], order.orderId ?: @"");
        PPPaymentSetValueForCandidateKeys(params, @[@"productDescription", @"productDesc"], @"Pure Pets Order");
        PPPaymentSetValueForCandidateKeys(params, @[@"name"], PPCurrentUser.UserName ?: @"Pure Pets");
        NSString *sdkEmail = PPPaymentTrimmedString(PPCurrentUser.UserEmail);
        PPPaymentSetValueForCandidateKeys(params, @[@"email"], sdkEmail.length > 0 ? sdkEmail : PPPaymentOfficialEmailFallback);
        PPPaymentSetValueForCandidateKeys(params, @[@"phone"], phone ?: @"");
        PPPaymentSetValueForCandidateKeys(params, @[@"address"], (addressLine1.length > 0 ? addressLine1 : (fallbackLocation.length > 0 ? fallbackLocation : @"Address")));
        PPPaymentSetValueForCandidateKeys(params, @[@"city"], (fallbackLocation.length > 0 ? fallbackLocation : (displayName.length > 0 ? displayName : @"City")));
        PPPaymentSetValueForCandidateKeys(params, @[@"state"], countryISO);
        PPPaymentSetValueForCandidateKeys(params, @[@"country"], countryISO);

        if (![params respondsToSelector:@selector(sendRequest)]) {
            [self failWithMessage:kLang(@"payment_qib_sdk_missing")];
            return;
        }

        self.qpParams = params;
        self.paymentPresenterVC = presenter;
        self.sdkDidPresent = NO;
        PPORDERLog(@"Launching QIB request | orderId=%@ | paymentAttemptId=%@ | qibSessionId=%@",
                   order.orderId ?: @"",
                   self.paymentAttemptId ?: @"",
                   self.activeQIBSessionId ?: @"");
        @try {
            [(id<PPPaymentQIBSendRequestCapable>)params sendRequest];
        } @catch (NSException *exception) {
            PPORDERLog(@"QIB sendRequest threw exception | name=%@ | reason=%@",
                       exception.name ?: @"", exception.reason ?: @"");
            [self failWithMessage:kLang(@"payment_qib_sdk_error")];
            return;
        }

        // Begin monitoring for orphaned payment requests: if the QIB SDK
        // dismisses its UI without calling qpResponse:, detect that and
        // auto-cancel so the user isn't stuck with a spinner forever.
        [self pp_beginOrphanedPaymentMonitoring];
    });
}

- (NSError *)pp_callableHTTPErrorWithStatusCode:(NSInteger)statusCode
                                   responseBody:(NSDictionary *)responseBody
                                fallbackMessage:(NSString *)fallbackMessage
                                     underlying:(NSError *)underlying
{
    NSDictionary *errorBody = [responseBody[@"error"] isKindOfClass:NSDictionary.class] ? responseBody[@"error"] : nil;
    NSString *status = PPPaymentSafeString(errorBody[@"status"]);
    NSString *message = PPPaymentFunctionsMessageCandidate(errorBody ?: responseBody, 0);
    if (message.length == 0) {
        message = fallbackMessage.length > 0 ? fallbackMessage : kLang(@"payment_backend_unreachable");
    }

    FIRFunctionsErrorCode code = status.length > 0
        ? PPPaymentFunctionsErrorCodeFromStatus(status)
        : PPPaymentFunctionsErrorCodeFromHTTPStatus(statusCode);
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = message;
    userInfo[@"httpStatusCode"] = @(statusCode);
    if (status.length > 0) {
        userInfo[@"status"] = status;
    }
    if (responseBody) {
        userInfo[@"responseBody"] = responseBody;
    }
    if (underlying) {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:@"FirebaseFunctionsManualCallable" code:code userInfo:userInfo];
}

- (void)pp_callCreateQIBSessionWithPayload:(NSDictionary *)payload
                                   idToken:(NSString *)idToken
                             appCheckToken:(NSString *)appCheckToken
                                completion:(void (^)(NSDictionary *session, NSError *error))completion
{
    FIRHTTPSCallable *callable = [PPPaymentQIBFunctionsClient() HTTPSCallableWithName:@"createQibSession"];
    callable.timeoutInterval = 60.0;
    
    PPORDERLog(@"Creating QIB session via FIRFunctions HTTPSCallable | functionName=createQibSession");
    
    [callable callWithObject:payload ?: @{} completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            PPORDERLog(@"QIB FIRFunctions callable failed | error=%@", error.localizedDescription ?: @"");
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        
        NSDictionary *json = nil;
        if ([result.data isKindOfClass:NSDictionary.class]) {
            json = (NSDictionary *)result.data;
        }
        
        id finalResult = json[@"result"];
        if (!finalResult || finalResult == [NSNull null]) {
            finalResult = json[@"data"];
        }
        if (![finalResult isKindOfClass:NSDictionary.class] && [json[@"sessionId"] isKindOfClass:NSString.class]) {
            finalResult = json;
        }
        
        if (![finalResult isKindOfClass:NSDictionary.class]) {
            NSError *parseError = [self pp_callableHTTPErrorWithStatusCode:200
                                                              responseBody:json ?: @{}
                                                           fallbackMessage:kLang(@"payment_create_session_failed")
                                                                underlying:nil];
            PPORDERLog(@"QIB FIRFunctions callable response invalid | bodyKeys=%@", json.allKeys ?: @[]);
            if (completion) {
                completion(nil, parseError);
            }
            return;
        }
        
        if (completion) {
            completion((NSDictionary *)finalResult, nil);
        }
    }];
}

- (void)createQIBSessionForOrder:(PPOrder *)order
                        currency:(NSString *)currency
                  viewController:(UIViewController *)viewController
                           phone:(NSString *)phone
                         idToken:(NSString *)idToken
                   appCheckToken:(NSString *)appCheckToken
                allowQARFallback:(BOOL)allowQARFallback
{
    NSString *safeCurrency = PPPaymentTrimmedString(currency).uppercaseString;
    if (safeCurrency.length != 3) {
        safeCurrency = PPPaymentEffectiveCurrencyForOrder(order);
    }
    if (safeCurrency.length != 3) {
        safeCurrency = PPPaymentResolvedCurrencyCode();
        if (safeCurrency.length != 3) {
            safeCurrency = @"QAR";
        }
    }

    NSString *userEmail = @"";
    if ([FIRAuth auth].currentUser.email.length > 0) {
        userEmail = [FIRAuth auth].currentUser.email;
    } else if (PPCurrentUser.UserEmail != nil && PPCurrentUser.UserEmail.length > 0) {
        userEmail = PPCurrentUser.UserEmail;
    } else {
        userEmail = PPPaymentOfficialEmailFallback;
    }

    NSString *userName = @"";
    if ([FIRAuth auth].currentUser.displayName.length > 0) {
        userName = [FIRAuth auth].currentUser.displayName;
    } else if (PPCurrentUser.UserName != nil) {
        userName = PPCurrentUser.UserName;
    } else {
        userName = @"Pure Pets";
    }

    NSDictionary *payload = @{
        @"orderId": order.orderId ?: @"",
        @"amount": @((order.totalAmount > 0 ? order.totalAmount : order.amount)),
        @"currency": safeCurrency,
        @"phone": phone ?: @"",
        @"email": userEmail ?: @"",
        @"name": userName ?: @"",
        @"paymentAttemptId": self.paymentAttemptId ?: @""
    };

    PPORDERLog(@"Creating QIB session | orderId=%@ | currency=%@ | amount=%.2f | authUIDPresent=%d",
               order.orderId ?: @"",
               safeCurrency ?: @"",
               (order.totalAmount > 0 ? order.totalAmount : order.amount),
               [FIRAuth auth].currentUser.uid.length > 0);

    [self pp_callCreateQIBSessionWithPayload:payload
                                     idToken:idToken
                               appCheckToken:appCheckToken
                                  completion:^(NSDictionary *session, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || ![session isKindOfClass:NSDictionary.class]) {
                if (allowQARFallback &&
                    ![safeCurrency isEqualToString:@"QAR"] &&
                    PPPaymentShouldRetryWithQARForCallableError(error)) {
                    PPORDERLog(@"Retrying QIB session creation with QAR fallback | orderId=%@ | failedCurrency=%@ | error=%@",
                               order.orderId ?: @"",
                               safeCurrency ?: @"",
                               error.localizedDescription ?: @"");
                    [self createQIBSessionForOrder:order
                                          currency:@"QAR"
                                    viewController:viewController
                                             phone:phone
                                           idToken:idToken
                                     appCheckToken:appCheckToken
                                  allowQARFallback:NO];
                    return;
                }

                NSError *resolvedError = error;
                if (resolvedError) {
                    NSString *friendly = PPPaymentFriendlyFunctionsErrorMessage(resolvedError);
                    if (friendly.length > 0) {
                        NSMutableDictionary *userInfo = [resolvedError.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
                        userInfo[NSLocalizedDescriptionKey] = friendly;
                        userInfo[NSUnderlyingErrorKey] = resolvedError;
                        resolvedError = [NSError errorWithDomain:@"PPPayment" code:resolvedError.code userInfo:userInfo];
                    }
                } else {
                    resolvedError = [NSError errorWithDomain:@"PPPayment"
                                                         code:500
                                                     userInfo:@{NSLocalizedDescriptionKey:
                                                                    kLang(@"payment_create_session_failed")}];
                }
                PPORDERLog(@"Create QIB session failed | orderId=%@ | error=%@",
                           order.orderId ?: @"",
                           resolvedError.localizedDescription ?: @"");
                [self failWithError:resolvedError];
                return;
            }

            PPORDERLog(@"QIB session created | orderId=%@ | responseKeys=%@",
                       order.orderId ?: @"",
                       session.allKeys ?: @[]);
            [self startQIBWithSession:session
                                order:order
                      viewController:viewController
                               phone:phone
                    requestedCurrency:safeCurrency];
        });
    }];
}

#pragma mark - Helpers

- (NSString *)normalizedPhoneForQIBForOrder:(PPOrder *)order
{
    NSDictionary *shipping = [order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]
        ? order.shippingAddressSnapshot
        : @{};

    NSArray<NSString *> *candidates = @[
        PPCurrentUser.MobileNo ?: @"",
        [FIRAuth auth].currentUser.phoneNumber ?: @"",
        shipping[@"MobileNo"] ?: @"",
        shipping[@"mobile"] ?: @"",
        shipping[@"phoneNumber"] ?: @"",
        shipping[@"phone"] ?: @"",
        shipping[@"contactPhone"] ?: @""
    ];

    for (NSString *rawValue in candidates) {
        NSString *normalized = [self pp_normalizedValidPhoneForQIBFromRaw:rawValue];
        if (normalized.length > 0) {
            return normalized;
        }
    }
    return nil;
}

- (NSString *)pp_normalizedValidPhoneForQIBFromRaw:(NSString *)rawPhone
{
    NSString *raw = PPPaymentTrimmedString(rawPhone);
    raw = [raw stringByApplyingTransform:NSStringTransformToLatin reverse:NO] ?: raw;
    if (raw.length == 0) return nil;

    BOOL looksInternational = [raw hasPrefix:@"+"] || [raw hasPrefix:@"00"];

    NSCharacterSet *nonDigits =
        [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *digits =
        [[raw componentsSeparatedByCharactersInSet:nonDigits]
         componentsJoinedByString:@""];
    if (digits.length == 0) return nil;

    if (looksInternational && [digits hasPrefix:@"00"] && digits.length > 2) {
        digits = [digits substringFromIndex:2];
    }

    if (!looksInternational) {
        // Egypt mobile numbers are commonly stored locally as 01XXXXXXXXX.
        // Do not prefix those with the app's Qatar default.
        if ([digits hasPrefix:@"01"] && digits.length == 11) {
            digits = [@"20" stringByAppendingString:[digits substringFromIndex:1]];
        } else {
            CountryModel *country = [CountryModel safeUserCountryModel] ?: [CitiesManager.shared CurrentCountry];
            NSString *countryCode = [country.countryCode isKindOfClass:NSString.class] ? country.countryCode : @"";
            countryCode = [[countryCode stringByReplacingOccurrencesOfString:@"+" withString:@""]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (countryCode.length == 0) {
                countryCode = @"974";
            }

            // Local formats often begin with trunk 0; remove it before prefixing.
            if ([digits hasPrefix:@"0"] && digits.length > 1) {
                digits = [digits substringFromIndex:1];
            }

            if (![digits hasPrefix:countryCode]) {
                digits = [countryCode stringByAppendingString:digits];
            }
        }
    }

    // E.164 payloads must be real-sized phone numbers. This rejects values like +974123.
    if (digits.length >= 8 && digits.length <= 15) {
        return [NSString stringWithFormat:@"+%@", digits];
    }
    return nil;
}

- (void)failWithMessage:(NSString *)msg
{
    NSError *err =
    [NSError errorWithDomain:@"PPPayment"
                        code:400
                    userInfo:@{NSLocalizedDescriptionKey: msg}];
    [self failWithError:err];
}

- (void)failWithError:(NSError *)error
{
    PPORDERLog(@"Payment flow failed | error=%@", error.localizedDescription ?: @"");

    // Capture completion and reset BEFORE invoking the callback to
    // prevent re-entrant or duplicate callbacks (same pattern as qpResponse:).
    PPPaymentCompletion capturedCompletion = self.completion;
    [self reset];

    if (capturedCompletion) {
        capturedCompletion(nil, error);
    }
}

- (void)reset
{
    SFSafariViewController *hostedCheckoutVC = self.hostedCheckoutVC;
    self.hostedCheckoutVC = nil;
    if (hostedCheckoutVC.presentingViewController && !hostedCheckoutVC.isBeingDismissed) {
        [hostedCheckoutVC dismissViewControllerAnimated:NO completion:nil];
    }

    // Break the retain cycle: self → qpParams → delegate(strong) → self.
    // Must nil the delegate BEFORE releasing qpParams, in case the SDK
    // retains the params object internally.
    if (self.qpParams) {
        PPPaymentSetValueForCandidateKeys(self.qpParams, @[@"delegate"], nil);
    }
    self.qpParams = nil;
    self.completion = nil;
    self.paymentAttemptId = nil;
    self.activeQIBSessionId = nil;
    self.isRequestInFlight = NO;
    self.paymentPresenterVC = nil;
    self.sdkDidPresent = NO;
    self.requestStartDate = nil;
}

#pragma mark - Orphaned Payment Detection

/// Periodically checks whether the QIB SDK has dismissed its modal UI
/// without calling `qpResponse:`.  When detected, the pending request
/// is resolved as a user-cancellation so the spinner doesn't hang forever.
- (void)pp_beginOrphanedPaymentMonitoring
{
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.completion) return; // Already resolved via qpResponse:

        UIViewController *presenter = self.paymentPresenterVC;

        // Presenter deallocated → definitely orphaned.
        if (!presenter) {
            PPORDERLog(@"Payment presenter deallocated while payment in flight — treating as cancellation");
            [self pp_resolveOrphanedPaymentAsCancellation];
            return;
        }

        if (presenter.presentedViewController) {
            // SDK is still presenting its UI.
            self.sdkDidPresent = YES;
            [self pp_beginOrphanedPaymentMonitoring];
            return;
        }

        // Presenter has no presented VC.
        if (self.sdkDidPresent) {
            // SDK was visible and is now gone → dismissed without callback.
            PPORDERLog(@"QIB SDK dismissed without calling qpResponse: — treating as cancellation");
            [self pp_resolveOrphanedPaymentAsCancellation];
            return;
        }

        // SDK hasn't appeared yet (still loading). Give it up to 30 seconds
        // from when `sendRequest` was called.
        NSTimeInterval elapsed = self.requestStartDate
            ? -[self.requestStartDate timeIntervalSinceNow]
            : 0;
        if (elapsed > 30) {
            PPORDERLog(@"QIB SDK never presented after %.0fs — treating as cancellation", elapsed);
            [self pp_resolveOrphanedPaymentAsCancellation];
            return;
        }

        // Keep waiting.
        [self pp_beginOrphanedPaymentMonitoring];
    });
}

- (void)pp_resolveOrphanedPaymentAsCancellation
{
    PPPaymentCompletion capturedCompletion = self.completion;
    [self reset];

    if (capturedCompletion) {
        NSError *cancelError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSUserCancelledError
                        userInfo:@{NSLocalizedDescriptionKey:
                                       kLang(@"payment_cancelled_by_user")}];
        capturedCompletion(@{}, cancelError);
    }
}

@end
