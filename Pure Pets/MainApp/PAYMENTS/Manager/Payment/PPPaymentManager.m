//
//  PPPaymentManager.m
//  Pure Pets
//
//  Production-ready QIB payment manager (Simulator-safe)
//

#import "PPPaymentManager.h"
@import FirebaseFunctions;
@import FirebaseAuth;
#import "CountryModel.h"
#import "CitiesManager.h"

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

@protocol PPPaymentQIBSendRequestCapable <NSObject>
- (void)sendRequest;
@end

@interface PPPaymentManager ()

@property (nonatomic, strong) id qpParams; // intentionally id (avoids linker crash)
@property (nonatomic, copy) PPPaymentCompletion completion;

@property (nonatomic, copy) NSString *paymentAttemptId;
@property (nonatomic, assign) BOOL isRequestInFlight;
@property (nonatomic, copy) NSString *activeQIBSessionId;

// Orphaned-request detection: catches QIB SDK dismissals that never call qpResponse:.
@property (nonatomic, weak) UIViewController *paymentPresenterVC;
@property (nonatomic, assign) BOOL sdkDidPresent;
@property (nonatomic, strong) NSDate *requestStartDate;

@end

static NSString * const PPPaymentSimulatedPaymentSuccessDefaultsKey = @"PPSimulatedPaymentSuccessEnabled";

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
         PPPaymentStatusMatchesAnyKeyword(normalized, @[@"failed", @"failure", @"declined", @"rejected", @"cancelled", @"canceled", @"cancel", @"error", @"expired", @"voided"]) ||
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
    NSString *status = PPPaymentExtractStatusFromResponseObject(response, 0);
    return PPPaymentStatusMatchesAnyKeyword(status, @[@"cancelled", @"canceled", @"cancel"]);
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
    if (PPPaymentStatusMatchesAnyKeyword(status, @[@"failed", @"failure", @"declined", @"rejected", @"cancelled", @"canceled", @"cancel", @"error", @"expired", @"voided"])) {
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

static NSString *PPPaymentResolvedCurrencyCode(void)
{
    NSString *currencyCode = [[CountryModel safeCurrentCurrencyCode] uppercaseString];
    if (currencyCode.length == 3) {
        return currencyCode;
    }
    return @"QAR";
}

static NSString *PPPaymentResolvedCountryISOCode(void)
{
    NSString *countryCode = [[CountryModel safeCurrentCountryISOCode] uppercaseString];
    return countryCode.length == 2 ? countryCode : @"QA";
}

static NSString *PPPaymentEffectiveCurrencyForOrder(PPOrder *order)
{
    // Payment currency must follow the currently selected country (not a stale pending order snapshot).
    NSString *currentCurrency = PPPaymentResolvedCurrencyCode();
    if (currentCurrency.length == 3) {
        return currentCurrency;
    }

    NSString *orderCurrency = PPPaymentTrimmedString(order.currency).uppercaseString;
    if (orderCurrency.length == 3) {
        return orderCurrency;
    }
    return @"QAR";
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

static void PPPaymentConfigureLimitedUseTokensIfSupported(FIRFunctions *functions)
{
    if (!functions) return;

    SEL setter = NSSelectorFromString(@"setUseAppCheckLimitedUseTokens:");
    if (![functions respondsToSelector:setter]) {
        return;
    }

    NSMethodSignature *signature = [functions methodSignatureForSelector:setter];
    if (!signature) {
        return;
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    BOOL enabled = YES;
    [invocation setSelector:setter];
    [invocation setTarget:functions];
    [invocation setArgument:&enabled atIndex:2];
    [invocation invoke];
}

static FIRFunctions *PPPaymentFunctionsClient(void)
{
    FIRFunctions *functions = nil;
    NSString *customDomain = PPPaymentTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsCustomDomain"]);
    if (customDomain.length > 0) {
        functions = [FIRFunctions functionsForCustomDomain:customDomain];
    } else {
        functions = [FIRFunctions functionsForRegion:PPPaymentFunctionsRegion()];
    }
    PPPaymentConfigureLimitedUseTokensIfSupported(functions);
    return functions;
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
    if (!isFunctionsError) {
        return serverMessage;
    }

    switch ((FIRFunctionsErrorCode)error.code) {
        case FIRFunctionsErrorCodeUnimplemented:
            return kLang(@"payment_backend_unavailable");
        case FIRFunctionsErrorCodeNotFound:
            return serverMessage.length > 0 ? serverMessage : kLang(@"payment_backend_order_not_found");
        case FIRFunctionsErrorCodeUnauthenticated:
            return kLang(@"auth_register_required_title");
        case FIRFunctionsErrorCodePermissionDenied:
            return kLang(@"payment_backend_permission_denied");
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

+ (BOOL)isSimulatedPaymentSuccessEnabled
{
#if DEBUG
    return [[NSUserDefaults standardUserDefaults] boolForKey:PPPaymentSimulatedPaymentSuccessDefaultsKey];
#else
    return NO;
#endif
}

+ (void)setSimulatedPaymentSuccessEnabled:(BOOL)enabled
{
#if DEBUG
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:PPPaymentSimulatedPaymentSuccessDefaultsKey];
#else
    (void)enabled;
#endif
}

+ (instancetype)shared
{
    static PPPaymentManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [PPPaymentManager new];
    });
    return mgr;
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
    [self createQIBSessionForOrder:order
                          currency:requestedCurrency
                    viewController:viewController
                             phone:phone
                  allowQARFallback:YES];
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

    // When the QIB SDK returns a non-terminal response (empty dict, no
    // recognizable status, no transactionId) it almost always means the user
    // tapped "Cancel" inside the SDK UI and the SDK dismissed itself without
    // setting a proper cancel status.  Treat this as a user cancellation
    // instead of silently ignoring it (which would leave the app stuck in a
    // loading state until the checkout timeout fires).
    BOOL isTerminal = PPPaymentResponseHasTerminalResult(safeResponse);
    BOOL looksLikeCancellation = PPPaymentResponseIsCancellation(safeResponse);

    if (!isTerminal && !looksLikeCancellation) {
        PPORDERLog(@"QIB returned non-terminal response — treating as user cancellation | status=%@ | keys=%@",
                   PPPaymentExtractStatusFromResponseObject(safeResponse, 0) ?: @"(empty)",
                   safeResponse.allKeys ?: @[]);
        looksLikeCancellation = YES;
    }

    // QIB SDK sometimes returns a transactionId with no recognizable status
    // (e.g. user closed the webview mid-payment).  PPPaymentResponseHasTerminalResult
    // marks that as terminal, but without an explicit success or failure status the
    // response is ambiguous and must NOT advance the order into verification.
    // Treat it as a user cancellation.
    if (isTerminal && !looksLikeCancellation &&
        !PPPaymentResponseIsExplicitSuccess(safeResponse) &&
        !PPPaymentResponseIsExplicitFailure(safeResponse)) {
        PPORDERLog(@"QIB returned ambiguous terminal response (transactionId only, no status) — treating as cancellation | keys=%@",
                   safeResponse.allKeys ?: @[]);
        looksLikeCancellation = YES;
    }

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

    if (gatewayId.length == 0 || secretKey.length == 0) {
        // ─── H-14 SECURE FLOW GATE ─────────────────────────────────────────────
        // When the createQibSession Cloud Function returns a paymentUrl (Phase 2
        // hosted checkout), this path should open the URL in a secure in-app
        // browser instead of failing.
        //
        // TODO(H-14-phase2): Implement hosted checkout handler:
        //   1. Open paymentURL in SFSafariViewController or WKWebView
        //   2. Register a URL scheme / universal link callback for payment result
        //   3. Call verifyQibPayment Cloud Function to confirm the result server-side
        //   4. Remove the entire legacy secretKey / QPRequestParameters flow below
        // ────────────────────────────────────────────────────────────────────────
        if (sessionToken.length > 0 || paymentURL.length > 0) {
            PPORDERLog(@"Secure session received but hosted checkout not yet implemented | orderId=%@ | hasToken=%d | hasURL=%d",
                       order.orderId ?: @"",
                       (sessionToken.length > 0),
                       (paymentURL.length > 0));
            [self failWithMessage:kLang(@"payment_secure_flow_required")];
            return;
        }
        [self failWithMessage:kLang(@"payment_secure_session_unavailable")];
        return;
    }

    // ─── H-14 LEGACY FLOW (PHASE 1) ────────────────────────────────────────
    // The QIB SDK (QPRequestParameters) requires secretKey on the client.
    // The secret is fetched from the createQibSession Cloud Function, which
    // reads it from Firebase Secret Manager — it is NOT embedded in the binary.
    //
    // However, the secret still transits through the client, which is a
    // residual security risk. This entire legacy block should be removed
    // once QIB provides a hosted checkout API (Phase 2).
    //
    // Migration checklist (H-14-phase2):
    //   [ ] QIB provides hosted-checkout / server-to-server endpoint
    //   [ ] createQibSession Cloud Function returns paymentUrl instead of secretKey
    //   [ ] iOS opens paymentUrl in SFSafariViewController (see gate above)
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
        PPPaymentSetValueForCandidateKeys(params, @[@"email"], PPCurrentUser.UserEmail ?: @"");
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

- (void)createQIBSessionForOrder:(PPOrder *)order
                        currency:(NSString *)currency
                  viewController:(UIViewController *)viewController
                           phone:(NSString *)phone
                allowQARFallback:(BOOL)allowQARFallback
{
    FIRFunctions *functions = PPPaymentFunctionsClient();
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

    NSDictionary *payload = @{
        @"orderId": order.orderId ?: @"",
        @"amount": @((order.totalAmount > 0 ? order.totalAmount : order.amount)),
        @"currency": safeCurrency,
        @"phone": phone ?: @"",
        @"paymentAttemptId": self.paymentAttemptId ?: @""
    };

    PPORDERLog(@"Creating QIB session | orderId=%@ | currency=%@ | amount=%.2f",
               order.orderId ?: @"",
               safeCurrency ?: @"",
               (order.totalAmount > 0 ? order.totalAmount : order.amount));

    [[functions HTTPSCallableWithName:@"createQibSession"]
     callWithObject:payload
     completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error || ![result.data isKindOfClass:NSDictionary.class]) {
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

        NSDictionary *session = (NSDictionary *)result.data;
        PPORDERLog(@"QIB session created | orderId=%@ | responseKeys=%@",
                   order.orderId ?: @"",
                   session.allKeys ?: @[]);
        [self startQIBWithSession:session
                            order:order
                  viewController:viewController
                           phone:phone
                requestedCurrency:safeCurrency];
    }];
}

#pragma mark - Helpers

- (NSString *)normalizedPhoneForQIBForOrder:(PPOrder *)order
{
    NSDictionary *shipping = [order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]
        ? order.shippingAddressSnapshot
        : @{};

    NSString *raw = PPPaymentFirstValidString(@[
        shipping[@"MobileNo"] ?: @"",
        shipping[@"mobile"] ?: @"",
        shipping[@"phoneNumber"] ?: @"",
        shipping[@"phone"] ?: @"",
        shipping[@"contactPhone"] ?: @"",
        PPCurrentUser.MobileNo ?: @"",
        [FIRAuth auth].currentUser.phoneNumber ?: @""
    ]);
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

    // Already international (e.g. +974...) -> keep as is.
    if (looksInternational) {
        return [NSString stringWithFormat:@"+%@", digits];
    }

    CountryModel *country = [CountryModel safeUserCountryModel] ?: [CitiesManager.shared CurrentCountry];
    NSString *countryCode = [country.countryCode isKindOfClass:NSString.class] ? country.countryCode : @"";
    countryCode = [[countryCode stringByReplacingOccurrencesOfString:@"+" withString:@""]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (countryCode.length == 0) {
        return [NSString stringWithFormat:@"+%@", digits];
    }

    // Local formats often begin with trunk 0; remove it before prefixing.
    if ([digits hasPrefix:@"0"] && digits.length > 1) {
        digits = [digits substringFromIndex:1];
    }

    if (![digits hasPrefix:countryCode]) {
        digits = [countryCode stringByAppendingString:digits];
    }

    return [NSString stringWithFormat:@"+%@", digits];
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
