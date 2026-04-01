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

@protocol PPPaymentQIBSendRequestCapable <NSObject>
- (void)sendRequest;
@end

@interface PPPaymentManager ()

@property (nonatomic, strong) id qpParams; // intentionally id (avoids linker crash)
@property (nonatomic, copy) PPPaymentCompletion completion;

@property (nonatomic, copy) NSString *paymentAttemptId;
@property (nonatomic, assign) BOOL isRequestInFlight;
@property (nonatomic, copy) NSString *activeQIBSessionId;

@end

static NSString * const PPPaymentSimulatedPaymentSuccessDefaultsKey = @"PPSimulatedPaymentSuccessEnabled";

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

static FIRFunctions *PPPaymentFunctionsClient(void)
{
    NSString *customDomain = PPPaymentTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsCustomDomain"]);
    if (customDomain.length > 0) {
        return [FIRFunctions functionsForCustomDomain:customDomain];
    }
    return [FIRFunctions functionsForRegion:PPPaymentFunctionsRegion()];
}

static NSString *PPPaymentFriendlyFunctionsErrorMessage(NSError *error)
{
    if (!error) return @"";

    NSString *domain = [PPPaymentTrimmedString(error.domain).lowercaseString copy];
    BOOL isFunctionsError = [domain containsString:@"functions"];
    NSString *serverMessage = PPPaymentTrimmedString(error.localizedDescription);
    if (!isFunctionsError) {
        return serverMessage;
    }

    switch ((FIRFunctionsErrorCode)error.code) {
        case FIRFunctionsErrorCodeUnimplemented:
        case FIRFunctionsErrorCodeNotFound:
            return kLang(@"payment_backend_unavailable");
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
        NSLog(@"[PAYMENT] ⚠️ Unable to load QIBPayment.framework: %@", loadError.localizedDescription);
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
        [self failWithMessage:kLang(@"payment_phone_required")];
        return;
    }

    self.isRequestInFlight = YES;
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
    if (self.completion) {
        self.completion(response, nil);
    }
    [self reset];
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
    if (gatewayId.length == 0 || secretKey.length == 0) {
        if (sessionToken.length > 0 || paymentURL.length > 0) {
            [self failWithMessage:kLang(@"payment_secure_flow_required")];
            return;
        }
        [self failWithMessage:kLang(@"payment_secure_session_unavailable")];
        return;
    }

    NSLog(@"[PAYMENT] ⚠️ Using legacy gateway bootstrap. Migrate backend to tokenized/hosted session.");
    // U7: secretKey is required by QIB SDK for legacy flow but should NOT be logged or persisted.
    // TODO: Migrate to server-side tokenized sessions to eliminate client-side secret handling.
    if (secretKey.length > 0) {
        NSLog(@"[PAYMENT] ⚠️ secretKey present in session — server should migrate to tokenized flow");
    }

    dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_SIMULATOR
        PPQIBTryLoadFrameworkBundle();
#endif

        UIViewController *presenter = vc;
        while (presenter.presentedViewController &&
               !presenter.presentedViewController.isBeingDismissed) {
            presenter = presenter.presentedViewController;
        }
        if ([presenter isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)presenter).visibleViewController;
            if (visible) presenter = visible;
        }
        if ([presenter isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)presenter).selectedViewController;
            if (selected) presenter = selected;
        }
        if (!presenter) {
            [self failWithMessage:kLang(@"payment_unable_to_open_screen")];
            return;
        }

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
            NSLog(@"[PAYMENT] ❌ QIB SDK class not found. Expected QPRequestParameters from QIBPayment.framework.");
            [self failWithMessage:kLang(@"payment_qib_sdk_missing")];
            return;
        }

        SEL initSelector = @selector(initWithViewController:);
        id params = nil;
        @try {
            if ([paramsClass instancesRespondToSelector:initSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id allocInstance = [paramsClass alloc];
                params = [allocInstance performSelector:initSelector withObject:presenter];
#pragma clang diagnostic pop
            } else if ([paramsClass instancesRespondToSelector:@selector(init)]) {
                params = [[paramsClass alloc] init];
            }
        } @catch (__unused NSException *exception) {
            params = nil;
        }

        if (!params) {
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

        NSString *sessionCurrency = PPPaymentResolvedCurrencyCode();
        if (sessionCurrency.length != 3) {
            sessionCurrency = @"QAR";
        }

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
        [(id<PPPaymentQIBSendRequestCapable>)params sendRequest];
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

    [[functions HTTPSCallableWithName:@"createQibSession"]
     callWithObject:payload
     completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error || ![result.data isKindOfClass:NSDictionary.class]) {
            if (allowQARFallback && ![safeCurrency isEqualToString:@"QAR"]) {
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
            [self failWithError:resolvedError];
            return;
        }

        NSDictionary *session = (NSDictionary *)result.data;
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
    if (self.completion) {
        self.completion(nil, error);
    }
    [self reset];
}

- (void)reset
{
    self.qpParams = nil;
    self.completion = nil;
    self.paymentAttemptId = nil;
    self.activeQIBSessionId = nil;
    self.isRequestInFlight = NO;
}

@end
