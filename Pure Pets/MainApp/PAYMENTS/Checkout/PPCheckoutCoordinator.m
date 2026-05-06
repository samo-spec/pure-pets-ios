//
//  PPCheckoutCoordinator 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//


#import "PPCheckoutCoordinator.h"

#import "CartManager.h"
#import "PPCartCalculator.h"
#import "PPOrderManager.h"
#import "PPPaymentManager.h"
#import "PPOrder.h"
#import "PPAddressModel.h"
#import "PPAddressesManager.h"
#import "PPNetworkRetryHelper.h"
#import "PPAnalytics.h"
@import FirebaseFunctions;
#import <math.h>

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

@interface PPCheckoutCoordinator ()

@property (nonatomic, weak) UIViewController *presentingVC;
@property (nonatomic, copy) PPCheckoutCompletion completion;

@property (nonatomic, strong) PPOrder *currentOrder;
@property (nonatomic, strong, nullable) PPAddressModel *selectedAddress;
@property (nonatomic, copy) NSString *selectedPaymentMethodId;
@property (nonatomic, strong) id<FIRListenerRegistration> orderListener;
@property (nonatomic, assign) BOOL isCheckoutInProgress;
@property (nonatomic, assign) NSInteger checkoutGeneration;
@property (nonatomic, assign) BOOL hasResolvedCheckout;

/// UUID generated once per checkout attempt.  Survives retries within the
/// same coordinator instance so that a network-timeout retry does not create
/// a duplicate order.  Cleared on success or explicit cancellation.
@property (nonatomic, copy, nullable) NSString *checkoutIdempotencyKey;

- (NSError *)checkoutInventoryErrorFromIssues:(NSArray<NSDictionary *> *)issues;
- (void)beginPaymentForOrder:(PPOrder *)order generation:(NSInteger)generation;
- (void)startListeningToOrder:(PPOrder *)order generation:(NSInteger)generation;
- (void)completeWithSuccess:(FIRDocumentSnapshot * _Nullable)snapshot generation:(NSInteger)generation;
- (void)completeWithFailure:(FIRDocumentSnapshot * _Nullable)snapshot generation:(NSInteger)generation;
- (void)completeWithPendingVerification:(NSError *)error generation:(NSInteger)generation;
- (void)completeWithCancellation:(PPOrder *)order generation:(NSInteger)generation;
- (void)failOrderWithError:(NSError *)error generation:(NSInteger)generation;
- (void)failOrderWithError:(NSError *)error retryable:(BOOL)retryable generation:(NSInteger)generation;
- (BOOL)pp_isCheckoutGenerationCurrent:(NSInteger)generation;
- (BOOL)pp_beginTerminalResolutionForGeneration:(NSInteger)generation label:(NSString *)label;
- (void)pp_fetchLatestOrderSnapshotForOrder:(PPOrder *)order
                                 generation:(NSInteger)generation
                                     reason:(NSString *)reason
                                 completion:(void (^)(FIRDocumentSnapshot * _Nullable snapshot,
                                                      PPOrder * _Nullable latestOrder,
                                                      NSError * _Nullable error))completion;
- (void)pp_scheduleOrderResolutionTimeoutForOrder:(PPOrder *)order generation:(NSInteger)generation;
- (void)pp_registerForAppResumeNotification;
- (void)pp_unregisterForAppResumeNotification;
- (void)pp_prepareOrderForRetryAfterLaunchFailureForOrder:(PPOrder *)order
                                               generation:(NSInteger)generation
                                               completion:(dispatch_block_t)completion;

@end

static NSString *PPCheckoutItemsSignature(NSArray<NSDictionary *> *items)
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSDictionary *item in items ?: @[]) {
        NSString *itemId = item[@"id"] ?: item[@"itemID"] ?: @"";
        NSInteger qty = [item[@"qty"] ?: item[@"quantity"] integerValue];
        double price = [item[@"price"] doubleValue];
        [parts addObject:[NSString stringWithFormat:@"%@|%ld|%.2f",
                          itemId,
                          (long)qty,
                          price]];
    }
    [parts sortUsingSelector:@selector(compare:)];
    return [parts componentsJoinedByString:@"#"];
}

static BOOL PPCheckoutOrderMatchesCart(PPOrder *order,
                                       NSArray<NSDictionary *> *items,
                                       double amount,
                                       NSString *addressID)
{
    if (!order) return NO;
    if (fabs(order.amount - amount) > 0.01) return NO;
    if (addressID.length > 0 && ![order.shippingAddressId isEqualToString:addressID]) return NO;
    NSString *candidateSignature = PPCheckoutItemsSignature(order.items);
    NSString *targetSignature = PPCheckoutItemsSignature(items);
    return [candidateSignature isEqualToString:targetSignature];
}

static NSString *PPCheckoutTrimmedString(NSString *value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPCheckoutNormalizedStatusString(id value)
{
    NSString *normalized = [[PPCheckoutTrimmedString(value) lowercaseString] copy];
    if (normalized.length == 0) return @"";

    normalized = [normalized stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([normalized containsString:@"__"]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return normalized;
}

static BOOL PPCheckoutStatusContainsToken(NSString *status, NSString *token)
{
    if (status.length == 0 || token.length == 0) return NO;
    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", status];
    NSString *wrappedToken = [NSString stringWithFormat:@"_%@_", token];
    return [wrappedStatus containsString:wrappedToken];
}

static BOOL PPCheckoutIsPaidLikeStatus(NSString *status)
{
    return PPCheckoutStatusContainsToken(status, @"paid") ||
           PPCheckoutStatusContainsToken(status, @"success") ||
           PPCheckoutStatusContainsToken(status, @"succeeded") ||
           PPCheckoutStatusContainsToken(status, @"captured") ||
           PPCheckoutStatusContainsToken(status, @"authorized") ||
           PPCheckoutStatusContainsToken(status, @"completed");
}

static BOOL PPCheckoutIsFailedLikeStatus(NSString *status)
{
    return PPCheckoutStatusContainsToken(status, @"failed") ||
           PPCheckoutStatusContainsToken(status, @"rejected") ||
           PPCheckoutStatusContainsToken(status, @"declined") ||
           PPCheckoutStatusContainsToken(status, @"cancelled") ||
           PPCheckoutStatusContainsToken(status, @"canceled") ||
           PPCheckoutStatusContainsToken(status, @"expired") ||
           PPCheckoutStatusContainsToken(status, @"error") ||
           PPCheckoutStatusContainsToken(status, @"voided");
}

static BOOL PPCheckoutIsPendingLikeStatus(NSString *status)
{
    return [status isEqualToString:@"pending"] ||
           [status isEqualToString:@"verification_pending"] ||
           PPCheckoutStatusContainsToken(status, @"verification_pending");
}

static BOOL PPCheckoutIsApprovedLikeStatus(NSString *status)
{
    return PPCheckoutStatusContainsToken(status, @"approved") ||
           PPCheckoutStatusContainsToken(status, @"verified");
}

static NSString *PPCheckoutNormalizedPaymentMethodID(NSString *paymentMethodID)
{
    NSString *normalized = PPCheckoutNormalizedStatusString(paymentMethodID);
    if ([normalized isEqualToString:@"cash"] ||
        [normalized isEqualToString:@"cod"] ||
        [normalized isEqualToString:@"cash_on_delivery"]) {
        return @"cash";
    }
    return @"qib";
}

static BOOL PPCheckoutBoolValue(id value)
{
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return NO;
}

static NSString *PPCheckoutFirstNormalizedStatusValue(NSDictionary *dictionary, NSArray<NSString *> *keys)
{
    for (NSString *key in keys ?: @[]) {
        NSString *candidate = PPCheckoutNormalizedStatusString(dictionary[key]);
        if (candidate.length > 0) {
            return candidate;
        }
    }
    return @"";
}

static BOOL PPCheckoutVerificationDataIndicatesSuccess(NSDictionary *data)
{
    NSString *status = PPCheckoutFirstNormalizedStatusValue(data, @[@"status", @"orderStatus"]);
    NSString *paymentStatus = PPCheckoutFirstNormalizedStatusValue(data, @[@"paymentStatus", @"orderPaymentStatus"]);
    NSString *verificationStatus = PPCheckoutFirstNormalizedStatusValue(data, @[@"verificationStatus", @"paymentVerificationStatus"]);

    return PPCheckoutIsPaidLikeStatus(status) ||
           PPCheckoutIsPaidLikeStatus(paymentStatus) ||
           PPCheckoutIsApprovedLikeStatus(verificationStatus) ||
           PPCheckoutBoolValue(data[@"ok"]) ||
           PPCheckoutBoolValue(data[@"success"]);
}

static BOOL PPCheckoutVerificationDataIndicatesFailure(NSDictionary *data)
{
    NSString *status = PPCheckoutFirstNormalizedStatusValue(data, @[@"status", @"orderStatus"]);
    NSString *paymentStatus = PPCheckoutFirstNormalizedStatusValue(data, @[@"paymentStatus", @"orderPaymentStatus"]);
    NSString *verificationStatus = PPCheckoutFirstNormalizedStatusValue(data, @[@"verificationStatus", @"paymentVerificationStatus"]);

    return PPCheckoutIsFailedLikeStatus(status) ||
           PPCheckoutIsFailedLikeStatus(paymentStatus) ||
           PPCheckoutIsFailedLikeStatus(verificationStatus);
}

static BOOL PPCheckoutVerificationDataIndicatesPending(NSDictionary *data)
{
    NSString *status = PPCheckoutFirstNormalizedStatusValue(data, @[@"status", @"verificationStatus", @"paymentVerificationStatus"]);
    NSString *paymentStatus = PPCheckoutFirstNormalizedStatusValue(data, @[@"paymentStatus", @"orderPaymentStatus"]);

    return PPCheckoutIsPendingLikeStatus(status) ||
           PPCheckoutIsPendingLikeStatus(paymentStatus);
}

static BOOL PPCheckoutOrderHasSuccessState(PPOrder *order)
{
    if (!order) return NO;
    NSString *status = PPCheckoutNormalizedStatusString(order.rawStatus);
    NSString *paymentStatus = PPCheckoutNormalizedStatusString(order.paymentStatus);
    NSString *verificationStatus = PPCheckoutNormalizedStatusString(order.verificationStatus);

    return [order hasCapturedPayment] ||
           PPCheckoutIsPaidLikeStatus(status) ||
           PPCheckoutIsPaidLikeStatus(paymentStatus) ||
           PPCheckoutIsApprovedLikeStatus(verificationStatus);
}

static BOOL PPCheckoutOrderHasFailureState(PPOrder *order)
{
    if (!order) return NO;
    NSString *status = PPCheckoutNormalizedStatusString(order.rawStatus);
    NSString *paymentStatus = PPCheckoutNormalizedStatusString(order.paymentStatus);
    NSString *verificationStatus = PPCheckoutNormalizedStatusString(order.verificationStatus);

    return PPCheckoutIsFailedLikeStatus(status) ||
           PPCheckoutIsFailedLikeStatus(paymentStatus) ||
           PPCheckoutIsFailedLikeStatus(verificationStatus);
}

static BOOL PPCheckoutAddressHasMinimumData(PPAddressModel *address)
{
    if (!address) return NO;

    NSString *effectiveID = address.documentID.length > 0 ? address.documentID : address.addressID;
    if (effectiveID.length == 0) return NO;

    if (address.documentID.length == 0) {
        address.documentID = effectiveID;
    }
    if (address.addressID.length == 0) {
        address.addressID = effectiveID;
    }

    NSString *line1 = PPCheckoutTrimmedString(address.addressLine1);
    NSString *fullName = PPCheckoutTrimmedString(address.fullName);
    NSString *locationName = PPCheckoutTrimmedString(address.locatioName);
    NSString *displayName = PPCheckoutTrimmedString(address.displayName);

    return (line1.length > 0 ||
            fullName.length > 0 ||
            locationName.length > 0 ||
            displayName.length > 0);
}

static FIRFunctions *PPCheckoutFunctionsClient(void)
{
    FIRFunctions *functions = nil;
    NSString *customDomain = PPCheckoutTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsCustomDomain"]);
    if (customDomain.length > 0) {
        functions = [FIRFunctions functionsForCustomDomain:customDomain];
    } else {
        NSString *region = PPCheckoutTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsRegion"]);
        if (region.length == 0) {
            region = @"us-central1";
        }
        functions = [FIRFunctions functionsForRegion:region];
    }

    SEL setter = NSSelectorFromString(@"setUseAppCheckLimitedUseTokens:");
    if (functions && [functions respondsToSelector:setter]) {
        NSMethodSignature *signature = [functions methodSignatureForSelector:setter];
        if (signature) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            BOOL enabled = YES;
            [invocation setSelector:setter];
            [invocation setTarget:functions];
            [invocation setArgument:&enabled atIndex:2];
            [invocation invoke];
        }
    }
    return functions;
}

NSNotificationName const PPAppDidBecomeActiveNotification = @"PPAppDidBecomeActive";
NSString *const PPCheckoutErrorIsRetryableKey = @"PPCheckoutErrorIsRetryable";

@implementation PPCheckoutCoordinator

- (instancetype)initWithPresentingViewController:(UIViewController *)viewController
{
    self = [super init];
    if (self) {
        _presentingVC = viewController;
    }
    return self;
}

- (BOOL)pp_isCheckoutGenerationCurrent:(NSInteger)generation
{
    return generation > 0 && generation == self.checkoutGeneration;
}

- (BOOL)pp_beginTerminalResolutionForGeneration:(NSInteger)generation label:(NSString *)label
{
    if (![self pp_isCheckoutGenerationCurrent:generation]) {
        PPORDERLog(@"Ignoring stale %@ callback | generation=%ld | activeGeneration=%ld",
                   label ?: @"terminal",
                   (long)generation,
                   (long)self.checkoutGeneration);
        return NO;
    }
    if (self.hasResolvedCheckout) {
        PPORDERLog(@"Ignoring duplicate %@ callback | generation=%ld",
                   label ?: @"terminal",
                   (long)generation);
        return NO;
    }
    self.hasResolvedCheckout = YES;
    return YES;
}

- (void)pp_fetchLatestOrderSnapshotForOrder:(PPOrder *)order
                                 generation:(NSInteger)generation
                                     reason:(NSString *)reason
                                 completion:(void (^)(FIRDocumentSnapshot * _Nullable snapshot,
                                                      PPOrder * _Nullable latestOrder,
                                                      NSError * _Nullable error))completion
{
    NSString *orderId = PPCheckoutTrimmedString(order.orderId ?: self.currentOrder.orderId);
    if (orderId.length == 0) {
        NSError *missingOrderError = [NSError errorWithDomain:@"Checkout"
                                                         code:1008
                                                     userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_order")}];
        if (completion) {
            completion(nil, nil, missingOrderError);
        }
        return;
    }

    PPORDERLog(@"Fetching latest order snapshot | orderId=%@ | reason=%@", orderId, reason ?: @"");
    FIRDocumentReference *orderRef = [[FIRFirestore.firestore collectionWithPath:@"Orders"] documentWithPath:orderId];
    [orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (![self pp_isCheckoutGenerationCurrent:generation]) {
            PPORDERLog(@"Ignoring stale snapshot fetch result | orderId=%@ | reason=%@", orderId, reason ?: @"");
            return;
        }

        PPOrder *latestOrder = nil;
        if (snapshot.exists) {
            latestOrder = [PPOrder orderFromSnapshot:snapshot];
            if (latestOrder) {
                self.currentOrder = latestOrder;
                PPORDERLog(@"Latest order snapshot | orderId=%@ | status=%@ | paymentStatus=%@ | verificationStatus=%@",
                           latestOrder.orderId ?: @"",
                           latestOrder.rawStatus ?: @"",
                           latestOrder.paymentStatus ?: @"",
                           latestOrder.verificationStatus ?: @"");
            }
        }

        if (completion) {
            completion(snapshot, latestOrder, error);
        }
    }];
}

- (void)pp_scheduleOrderResolutionTimeoutForOrder:(PPOrder *)order generation:(NSInteger)generation
{
    NSString *orderId = PPCheckoutTrimmedString(order.orderId);
    if (orderId.length == 0 || [order isCashOnDelivery]) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
            return;
        }

        PPORDERLog(@"Checkout resolution timeout | orderId=%@ | generation=%ld",
                   orderId,
                   (long)generation);
        [self pp_fetchLatestOrderSnapshotForOrder:order
                                       generation:generation
                                           reason:@"resolution_timeout"
                                       completion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                    PPOrder * _Nullable latestOrder,
                                                    NSError * _Nullable error) {
            if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
                return;
            }

            if (latestOrder && PPCheckoutOrderHasSuccessState(latestOrder)) {
                [self completeWithSuccess:snapshot generation:generation];
                return;
            }
            if (latestOrder && PPCheckoutOrderHasFailureState(latestOrder)) {
                [self completeWithFailure:snapshot generation:generation];
                return;
            }

            PPORDERLog(@"Checkout timeout resolved as pending verification | orderId=%@ | fetchError=%@",
                       orderId,
                       error.localizedDescription ?: @"");
            NSError *pendingError = [NSError errorWithDomain:@"Checkout"
                                                        code:1006
                                                    userInfo:@{NSLocalizedDescriptionKey:
                                                                   kLang(@"checkout_payment_confirmation_delayed")}];
            [self completeWithPendingVerification:pendingError generation:generation];
        }];
    });
}

- (void)pp_prepareOrderForRetryAfterLaunchFailureForOrder:(PPOrder *)order
                                               generation:(NSInteger)generation
                                               completion:(dispatch_block_t)completion
{
    NSString *orderId = PPCheckoutTrimmedString(order.orderId);
    NSString *shippingAddressId = PPCheckoutTrimmedString(order.shippingAddressId);
    NSDictionary *shippingAddressSnapshot =
        [order.shippingAddressSnapshot isKindOfClass:NSDictionary.class] ? order.shippingAddressSnapshot : @{};

    if (orderId.length == 0 || shippingAddressId.length == 0 || shippingAddressSnapshot.count == 0 || [order isCashOnDelivery]) {
        if (completion) {
            completion();
        }
        return;
    }

    PPORDERLog(@"Preparing order for payment retry after launch failure | generation=%ld | orderId=%@",
               (long)generation,
               orderId);

    FIRFunctions *functions = PPCheckoutFunctionsClient();
    [[functions HTTPSCallableWithName:@"prepareOrderForRetry"]
     callWithObject:@{
        @"orderId": orderId,
        @"shippingAddressId": shippingAddressId,
        @"shippingAddressSnapshot": shippingAddressSnapshot
    }
     completion:^(__unused FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            PPORDERLog(@"prepareOrderForRetry failed after launch error | generation=%ld | orderId=%@ | error=%@",
                       (long)generation,
                       orderId,
                       error.localizedDescription ?: @"");
        } else {
            PPORDERLog(@"Order prepared for retry after launch error | generation=%ld | orderId=%@",
                       (long)generation,
                       orderId);
        }

        if (completion) {
            completion();
        }
    }];
}

- (void)startCheckoutWithCompletion:(PPCheckoutCompletion)completion
{
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error) {
            PPORDERLog(@"Checkout blocked | reason=address_fetch_failed | error=%@",
                       error.localizedDescription ?: @"unknown");
            if (completion) {
                completion(PPCheckoutResultFailed, nil, error);
            }
            return;
        }

        if (addresses.count == 0) {
            PPORDERLog(@"Checkout blocked | reason=no_address_on_file");
            NSError *noAddressError = [NSError errorWithDomain:@"Checkout"
                                                          code:1011
                                                      userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_no_address_on_file")}];
            if (completion) {
                completion(PPCheckoutResultFailed, nil, noAddressError);
            }
            return;
        }

        PPAddressModel *fallbackAddress = nil;
        for (PPAddressModel *candidate in addresses) {
            if (candidate.isDefault) {
                fallbackAddress = candidate;
                break;
            }
        }
        if (!fallbackAddress) {
            fallbackAddress = addresses.firstObject;
            PPORDERLog(@"Checkout fallback | reason=no_default_address | usingFirst=%@ | totalAddresses=%lu",
                       fallbackAddress.documentID ?: fallbackAddress.addressID ?: @"",
                       (unsigned long)addresses.count);
        }
        [self startCheckoutWithAddress:fallbackAddress completion:completion];
    }];
}

- (BOOL)pp_isValidCheckoutAddress:(PPAddressModel *)address
{
    return PPCheckoutAddressHasMinimumData(address);
}

- (void)startCheckoutWithAddress:(PPAddressModel * _Nullable)address
                      completion:(PPCheckoutCompletion)completion
{
    [self startCheckoutWithAddress:address paymentMethodId:nil completion:completion];
}

- (void)startCheckoutWithAddress:(PPAddressModel * _Nullable)address
                 paymentMethodId:(NSString *)paymentMethodId
                      completion:(PPCheckoutCompletion)completion
{
    PPORDERLog(@"Start checkout flow");

    // M-11: Offline pre-check — block checkout when there is no connectivity
    if (![PPNetworkRetryHelper isNetworkAvailable]) {
        PPORDERLog(@"Checkout blocked | reason=offline");
        NSError *offlineError = [NSError errorWithDomain:@"Checkout"
                                                    code:1010
                                                userInfo:@{NSLocalizedDescriptionKey: kLang(@"offline_action_message")}];
        if (self.presentingVC) {
            [PPAlertHelper showWarningIn:self.presentingVC
                                   title:kLang(@"offline_action_title")
                                subtitle:kLang(@"offline_action_message")
                              completion:nil];
        }
        if (completion) {
            completion(PPCheckoutResultFailed, nil, offlineError);
        }
        return;
    }

    if (self.isCheckoutInProgress) {
        NSError *inProgressError = [NSError errorWithDomain:@"Checkout"
                                                       code:1009
                                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"payment_request_in_progress")}];
        PPORDERLog(@"Checkout blocked | reason=already_in_progress");
        if (completion) {
            completion(PPCheckoutResultFailed, self.currentOrder, inProgressError);
        }
        return;
    }
    if (![self pp_isValidCheckoutAddress:address]) {
        NSError *addressError = [NSError errorWithDomain:@"Checkout"
                                                    code:1005
                                                userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_address")}];
        if (completion) {
            completion(PPCheckoutResultFailed, nil, addressError);
        }
        return;
    }
    self.selectedAddress = address;
    self.selectedPaymentMethodId = PPCheckoutNormalizedPaymentMethodID(paymentMethodId);

    self.completion = completion;
    self.hasResolvedCheckout = NO;
    self.checkoutGeneration += 1;
    NSInteger generation = self.checkoutGeneration;

    // Generate a stable idempotency key for this checkout attempt.
    // If one already exists (retry after a transient failure), keep it so
    // the backend can deduplicate the order creation request.
    if (!self.checkoutIdempotencyKey) {
        self.checkoutIdempotencyKey = [[NSUUID UUID] UUIDString];
    }
    PPORDERLog(@"Checkout idempotency key | generation=%ld | key=%@",
               (long)generation,
               self.checkoutIdempotencyKey);

    CartManager *cart = CartManager.sharedManager;

    // 1️⃣ Validate cart
    if (cart.isCartEmpty) {
        PPORDERLog(@"Checkout blocked | reason=cart_empty");
        NSError *error = [NSError errorWithDomain:@"Checkout"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_cart_empty")}];
        if (completion) completion(PPCheckoutResultFailed, nil, error);
        return;
    }

    self.isCheckoutInProgress = YES;

    PPCartSummary *checkoutSummary = [PPCartCalculator currentSummary];
    double cartSubtotal = checkoutSummary.subtotal;
    double cartTotal = checkoutSummary.finalTotal;

    [PPCartCalculator logDetailedSummary:checkoutSummary items:cart.cartItems];

    PPORDERLog(@"Cart validated | generation=%ld | items=%lu | subtotal=%.2f | total=%.2f | paymentMethod=%@ | addressId=%@",
               (long)generation,
               (unsigned long)cart.cartItems.count,
               cartSubtotal,
               cartTotal,
               self.selectedPaymentMethodId ?: @"",
               self.selectedAddress.documentID ?: self.selectedAddress.addressID ?: @"");

    [PPAnalytics logBeginCheckoutWithCartItems:cart.cartItems grandTotal:cartTotal];

    // 2️⃣ Lock cart
    [cart setValue:@(YES) forKey:@"_isLocked"];
    PPORDERLog(@"Cart locked | generation=%ld", (long)generation);

    NSArray<NSDictionary *> *items = [cart.cartItems valueForKey:@"firestoreDictionary"];

    // 3️⃣ Live stock validation before payment
    PPORDERLog(@"Validating live inventory | generation=%ld", (long)generation);
    [[PPOrderManager shared]
     validateInventoryForItems:items
     completion:^(BOOL inStock, NSArray<NSDictionary *> *issues, NSError * _Nullable inventoryError) {
        if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
            PPORDERLog(@"Ignoring stale inventory validation callback | generation=%ld", (long)generation);
            return;
        }
        if (inventoryError || !inStock) {
            NSError *error = inventoryError ?: [self checkoutInventoryErrorFromIssues:issues];
            PPORDERLog(@"Inventory validation failed | generation=%ld | error=%@", (long)generation, error.localizedDescription ?: @"");
            [self failOrderWithError:error generation:generation];
            return;
        }

        if (self.currentOrder.orderId.length > 0) {
            // Always re-resolve pending orders from Firestore before payment launch so
            // we do not charge against a stale in-memory snapshot.
            PPORDERLog(@"Discarding in-memory pending order before payment launch refresh | generation=%ld | orderId=%@",
                       (long)generation,
                       self.currentOrder.orderId ?: @"");
            self.currentOrder = nil;
        }

        // 4️⃣ Reuse or create pending order
        PPORDERLog(@"Resolving pending order in Firestore | generation=%ld", (long)generation);
        [[PPOrderManager shared]
         fetchOrCreatePendingOrderWithItems:items
         amount:cartSubtotal
         address:self.selectedAddress
         paymentMethodId:self.selectedPaymentMethodId
         idempotencyKey:self.checkoutIdempotencyKey
         completion:^(PPOrder *order, NSError *error) {
            if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
                PPORDERLog(@"Ignoring stale pending-order callback | generation=%ld", (long)generation);
                return;
            }
            if (error || !order) {
                PPORDERLog(@"Failed to resolve pending order | generation=%ld | error=%@",
                           (long)generation,
                           error.localizedDescription ?: @"");
                [self failOrderWithError:error generation:generation];
                return;
            }

            PPORDERLog(@"Pending order ready | generation=%ld | orderId=%@ | paymentMethod=%@",
                       (long)generation,
                       order.orderId ?: @"",
                       order.paymentMethodId ?: @"");
            self.currentOrder = order;

            if ([self.selectedPaymentMethodId isEqualToString:@"cash"] || [order isCashOnDelivery]) {
                PPORDERLog(@"Cash on delivery order ready | generation=%ld | orderId=%@", (long)generation, order.orderId ?: @"");
                [self completeWithSuccess:nil generation:generation];
                return;
            }

            // 5️⃣ Observe order status
            PPORDERLog(@"Listening to order updates | generation=%ld | orderId=%@", (long)generation, order.orderId ?: @"");
            [self startListeningToOrder:order generation:generation];

            // 6️⃣ Start payment
            [self beginPaymentForOrder:order generation:generation];
        }];
    }];
}

#pragma mark - Firestore Order Listener

- (void)beginPaymentForOrder:(PPOrder *)order generation:(NSInteger)generation
{
    if ([order isCashOnDelivery]) {
        PPORDERLog(@"Skipping QIB flow for cash order | generation=%ld | orderId=%@",
                   (long)generation,
                   order.orderId ?: @"");
        [self completeWithSuccess:nil generation:generation];
        return;
    }

    PPORDERLog(@"Starting QIB payment | generation=%ld | orderId=%@",
               (long)generation,
               order.orderId ?: @"");

    [[PPPaymentManager shared]
     startPaymentForOrder:order
     fromViewController:self.presentingVC
     completion:^(NSDictionary *response, NSError *error) {
        if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
            PPORDERLog(@"Ignoring stale payment callback | generation=%ld", (long)generation);
            return;
        }

        if (error && error.code == NSUserCancelledError) {
            PPORDERLog(@"Payment cancelled by user | generation=%ld | orderId=%@",
                       (long)generation,
                       order.orderId ?: @"");
            [self completeWithCancellation:order generation:generation];
            return;
        }

        if (error || !response) {
            NSError *launchError = error;
            if (!launchError) {
                launchError = [NSError errorWithDomain:@"Checkout"
                                                  code:1002
                                              userInfo:@{NSLocalizedDescriptionKey:
                                                             kLang(@"checkout_payment_failed_default")}];
            }
            PPORDERLog(@"Payment SDK failed | generation=%ld | orderId=%@ | error=%@",
                       (long)generation,
                       order.orderId ?: @"",
                       launchError.localizedDescription ?: @"");
            [self pp_prepareOrderForRetryAfterLaunchFailureForOrder:order
                                                         generation:generation
                                                         completion:^{
                if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
                    return;
                }
                [self failOrderWithError:launchError retryable:YES generation:generation];
            }];
            return;
        }

        PPORDERLog(@"Payment response received | generation=%ld | orderId=%@", (long)generation, order.orderId ?: @"");

        NSString *paymentAttemptId = PPCheckoutTrimmedString(order.paymentAttemptId);
        NSString *qibSessionId = PPCheckoutTrimmedString(order.qibSessionId);
        if (paymentAttemptId.length == 0 || qibSessionId.length == 0) {
            NSError *bindingError =
            [NSError errorWithDomain:@"Checkout"
                                code:1007
                            userInfo:@{NSLocalizedDescriptionKey:
                                           kLang(@"payment_secure_session_unavailable")}];
            PPORDERLog(@"Payment binding missing secure identifiers | generation=%ld | orderId=%@",
                       (long)generation,
                       order.orderId ?: @"");
            [self pp_prepareOrderForRetryAfterLaunchFailureForOrder:order
                                                         generation:generation
                                                         completion:^{
                if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
                    return;
                }
                [self failOrderWithError:bindingError retryable:YES generation:generation];
            }];
            return;
        }

        // 6️⃣ Verify payment via Cloud Function
        PPORDERLog(@"Verifying payment with Cloud Function | generation=%ld | orderId=%@",
                   (long)generation,
                   order.orderId ?: @"");
        // Start the delayed-confirmation timeout only after the customer leaves the QIB UI
        // and we begin backend verification. This avoids showing a false "don't pay again"
        // warning while the user is still entering card details inside the gateway screen.
        [self pp_scheduleOrderResolutionTimeoutForOrder:order generation:generation];

        FIRFunctions *functions = PPCheckoutFunctionsClient();

        [[functions HTTPSCallableWithName:@"verifyQibPayment"]
         callWithObject:@{
            @"orderId": order.orderId,
            @"paymentAttemptId": paymentAttemptId,
            @"qibSessionId": qibSessionId,
            @"paymentResponse": response
        }
         completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
            if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
                PPORDERLog(@"Ignoring stale verification callback | generation=%ld", (long)generation);
                return;
            }

            if (error) {
                PPORDERLog(@"Verification callable failed | generation=%ld | orderId=%@ | error=%@",
                           (long)generation,
                           order.orderId ?: @"",
                           error.localizedDescription ?: @"");
                [self pp_fetchLatestOrderSnapshotForOrder:order
                                               generation:generation
                                                   reason:@"verification_error"
                                               completion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                            PPOrder * _Nullable latestOrder,
                                                            NSError * _Nullable fetchError) {
                    if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
                        return;
                    }
                    if (latestOrder && PPCheckoutOrderHasSuccessState(latestOrder)) {
                        [self completeWithSuccess:snapshot generation:generation];
                        return;
                    }
                    if (latestOrder && PPCheckoutOrderHasFailureState(latestOrder)) {
                        [self completeWithFailure:snapshot generation:generation];
                        return;
                    }

                    PPORDERLog(@"Verification fallback resolved as pending | generation=%ld | fetchError=%@",
                               (long)generation,
                               fetchError.localizedDescription ?: @"");
                    NSError *pendingError = [NSError errorWithDomain:@"Checkout"
                                                                code:1006
                                                            userInfo:@{NSLocalizedDescriptionKey:
                                                                           kLang(@"checkout_payment_confirmation_delayed")}];
                    [self completeWithPendingVerification:pendingError generation:generation];
                }];
                return;
            }

            NSDictionary *verificationData = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            if (PPCheckoutVerificationDataIndicatesPending(verificationData)) {
                PPORDERLog(@"Verification pending | generation=%ld | orderId=%@",
                           (long)generation,
                           order.orderId ?: @"");
                NSError *pendingError =
                [NSError errorWithDomain:@"Checkout"
                                    code:1006
                                userInfo:@{NSLocalizedDescriptionKey:
                                               kLang(@"checkout_payment_verification_pending")}];
                [self completeWithPendingVerification:pendingError generation:generation];
                return;
            }

            if (PPCheckoutVerificationDataIndicatesFailure(verificationData)) {
                NSString *failureReason = PPCheckoutTrimmedString(verificationData[@"message"]);
                if (failureReason.length == 0) {
                    failureReason = kLang(@"checkout_payment_failed_default");
                }
                PPORDERLog(@"Verification reported failure | generation=%ld | orderId=%@ | reason=%@",
                           (long)generation,
                           order.orderId ?: @"",
                           failureReason);
                NSError *verificationFailure = [NSError errorWithDomain:@"Checkout"
                                                                   code:1002
                                                               userInfo:@{NSLocalizedDescriptionKey: failureReason}];
                [self failOrderWithError:verificationFailure retryable:YES generation:generation];
                return;
            }

            if (PPCheckoutVerificationDataIndicatesSuccess(verificationData)) {
                PPORDERLog(@"Verification reported success | generation=%ld | orderId=%@",
                           (long)generation,
                           order.orderId ?: @"");
                [self pp_fetchLatestOrderSnapshotForOrder:order
                                               generation:generation
                                                   reason:@"verification_success"
                                               completion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                            PPOrder * _Nullable latestOrder,
                                                            NSError * _Nullable fetchError) {
                    if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
                        return;
                    }
                    if (latestOrder && PPCheckoutOrderHasSuccessState(latestOrder)) {
                        [self completeWithSuccess:snapshot generation:generation];
                        return;
                    }
                    if (latestOrder && PPCheckoutOrderHasFailureState(latestOrder)) {
                        [self completeWithFailure:snapshot generation:generation];
                        return;
                    }
                    PPORDERLog(@"Verification success awaiting Firestore terminal state | generation=%ld | fetchError=%@",
                               (long)generation,
                               fetchError.localizedDescription ?: @"");
                }];
                return;
            }

            PPORDERLog(@"Verification returned non-terminal payload | generation=%ld | orderId=%@ | payload=%@",
                       (long)generation,
                       order.orderId ?: @"",
                       verificationData);
        }];
    }];
}

- (void)startListeningToOrder:(PPOrder *)order generation:(NSInteger)generation
{
    FIRFirestore *db = FIRFirestore.firestore;
    if (self.orderListener) {
        [self.orderListener remove];
        self.orderListener = nil;
    }

    // H-08: Register for app-resume notifications so we can re-check
    // payment status after the user returns from a banking app.
    [self pp_registerForAppResumeNotification];

    // U4: Prevent retain cycle in order listener
    __weak typeof(self) weakSelf = self;
    self.orderListener =
    [[[db collectionWithPath:@"Orders"] documentWithPath:order.orderId]  addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (![strongSelf pp_isCheckoutGenerationCurrent:generation] || strongSelf.hasResolvedCheckout) {
            PPORDERLog(@"Ignoring stale order listener callback | generation=%ld", (long)generation);
            return;
        }
        
        // U9: Log errors instead of silently returning
        if (error) {
            PPORDERLog(@"Order listener error | generation=%ld | orderId=%@ | error=%@",
                       (long)generation,
                       order.orderId ?: @"",
                       error.localizedDescription ?: @"");
            [strongSelf pp_fetchLatestOrderSnapshotForOrder:order
                                                 generation:generation
                                                     reason:@"listener_error"
                                                 completion:^(FIRDocumentSnapshot * _Nullable latestSnapshot,
                                                              PPOrder * _Nullable latestOrder,
                                                              NSError * _Nullable fetchError) {
                if (![strongSelf pp_isCheckoutGenerationCurrent:generation] || strongSelf.hasResolvedCheckout) {
                    return;
                }
                if (latestOrder && PPCheckoutOrderHasSuccessState(latestOrder)) {
                    [strongSelf completeWithSuccess:latestSnapshot generation:generation];
                    return;
                }
                if (latestOrder && PPCheckoutOrderHasFailureState(latestOrder)) {
                    [strongSelf completeWithFailure:latestSnapshot generation:generation];
                    return;
                }
                PPORDERLog(@"Listener error fallback stayed non-terminal | generation=%ld | fetchError=%@",
                           (long)generation,
                           fetchError.localizedDescription ?: @"");
            }];
            return;
        }
        if (!snapshot.exists) {
            PPORDERLog(@"Order listener snapshot missing | generation=%ld | orderId=%@", (long)generation, order.orderId ?: @"");
            return;
        }

        PPOrder *observedOrder = [PPOrder orderFromSnapshot:snapshot];
        if (observedOrder) {
            strongSelf.currentOrder = observedOrder;
            PPORDERLog(@"Order snapshot observed | generation=%ld | orderId=%@ | status=%@ | paymentStatus=%@ | verificationStatus=%@",
                       (long)generation,
                       observedOrder.orderId ?: @"",
                       observedOrder.rawStatus ?: @"",
                       observedOrder.paymentStatus ?: @"",
                       observedOrder.verificationStatus ?: @"");
        }

        if (observedOrder && PPCheckoutOrderHasSuccessState(observedOrder)) {
            [strongSelf completeWithSuccess:snapshot generation:generation];
        }
        else if (observedOrder && PPCheckoutOrderHasFailureState(observedOrder)) {
            [strongSelf completeWithFailure:snapshot generation:generation];
        }
        else {
            PPORDERLog(@"Order snapshot still pending | generation=%ld | orderId=%@",
                       (long)generation,
                       observedOrder.orderId ?: order.orderId ?: @"");
        }
    }];
}

#pragma mark - Completion

- (void)completeWithSuccess:(FIRDocumentSnapshot * _Nullable)snapshot generation:(NSInteger)generation
{
    if (![self pp_beginTerminalResolutionForGeneration:generation label:@"success"]) {
        return;
    }

    if (snapshot) {
        PPOrder *updatedOrder = [PPOrder orderFromSnapshot:snapshot];
        if (updatedOrder) {
            self.currentOrder = updatedOrder;
        }
    }

    PPORDERLog(@"Checkout success | generation=%ld | orderId=%@", (long)generation, self.currentOrder.orderId ?: @"");

    [PPAnalytics logPurchaseWithTransactionID:(self.currentOrder.orderId ?: @"")
                                    cartItems:CartManager.sharedManager.cartItems
                                   grandTotal:self.currentOrder.totalAmount];

    // Order placed — clear idempotency key so any future checkout gets a fresh key.
    self.checkoutIdempotencyKey = nil;

    // Prevent repeated "paid" callbacks while we perform inventory transaction.
    if (self.orderListener) {
        [self.orderListener remove];
        self.orderListener = nil;
    }

    [self cleanup];
    [CartManager.sharedManager clearCart];

    if (self.completion) {
        self.completion(PPCheckoutResultSuccess, self.currentOrder, nil);
    }
}

- (void)completeWithFailure:(FIRDocumentSnapshot * _Nullable)snapshot generation:(NSInteger)generation
{
    if (![self pp_beginTerminalResolutionForGeneration:generation label:@"failure"]) {
        return;
    }

    if (snapshot) {
        PPOrder *updatedOrder = [PPOrder orderFromSnapshot:snapshot];
        if (updatedOrder) {
            self.currentOrder = updatedOrder;
        }
    }

    [self cleanup];
    
    NSString *reason = [snapshot.data[@"failureReason"] isKindOfClass:NSString.class]
        ? snapshot.data[@"failureReason"]
        : kLang(@"checkout_payment_failed_default");
    PPORDERLog(@"Checkout failure | generation=%ld | orderId=%@ | reason=%@",
               (long)generation,
               self.currentOrder.orderId ?: @"",
               reason ?: @"");
    NSError *error =
    [NSError errorWithDomain:@"Checkout"
                        code:1002
                    userInfo:@{NSLocalizedDescriptionKey: reason,
                               PPCheckoutErrorIsRetryableKey: @YES}];
    
    if (self.completion) {
        self.completion(PPCheckoutResultFailed, self.currentOrder, error);
    }
}

- (void)completeWithPendingVerification:(NSError *)error generation:(NSInteger)generation
{
    if (![self pp_beginTerminalResolutionForGeneration:generation label:@"pending_verification"]) {
        return;
    }

    PPORDERLog(@"Checkout pending verification | generation=%ld | orderId=%@ | message=%@",
               (long)generation,
               self.currentOrder.orderId ?: @"",
               error.localizedDescription ?: @"");
    [self cleanup];

    // H-07: Mark pending-verification as retryable so the caller can
    // offer "Retry Payment" alongside "View Order Status".
    NSMutableDictionary *enrichedUserInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
    enrichedUserInfo[PPCheckoutErrorIsRetryableKey] = @YES;
    NSError *retryableError = [NSError errorWithDomain:error.domain
                                                  code:error.code
                                              userInfo:[enrichedUserInfo copy]];

    if (self.completion) {
        self.completion(PPCheckoutResultPendingVerification, self.currentOrder, retryableError);
    }
}

- (void)completeWithCancellation:(PPOrder *)order generation:(NSInteger)generation
{
    if (![self pp_beginTerminalResolutionForGeneration:generation label:@"cancelled"]) {
        return;
    }

    PPORDERLog(@"Checkout cancelled | generation=%ld | orderId=%@",
               (long)generation, order.orderId ?: @"");

    NSString *orderId = PPCheckoutTrimmedString(order.orderId);
    if (orderId.length > 0) {
        FIRDocumentReference *orderRef =
            [[FIRFirestore.firestore collectionWithPath:@"Orders"] documentWithPath:orderId];
        [orderRef updateData:@{
            @"status": @"cancelled",
            @"paymentStatus": @"cancelled",
            @"cancelledAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"statusUpdatedAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"cancellationReason": @"payment_cancelled_by_user"
        } completion:^(NSError * _Nullable firestoreError) {
            if (firestoreError) {
                PPORDERLog(@"Failed to cancel order in Firestore | orderId=%@ | error=%@",
                           orderId, firestoreError.localizedDescription ?: @"");
            } else {
                PPORDERLog(@"Order cancelled in Firestore | orderId=%@", orderId);
            }
        }];
    }

    // User explicitly cancelled — clear idempotency key so next checkout starts fresh.
    self.checkoutIdempotencyKey = nil;

    self.currentOrder = nil;
    [self cleanup];

    if (self.completion) {
        NSError *cancelError =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSUserCancelledError
                        userInfo:@{NSLocalizedDescriptionKey: kLang(@"payment_cancelled_by_user")}];
        self.completion(PPCheckoutResultCancelled, order, cancelError);
    }
}

- (void)failOrderWithError:(NSError *)error generation:(NSInteger)generation
{
    [self failOrderWithError:error retryable:NO generation:generation];
}

- (void)failOrderWithError:(NSError *)error retryable:(BOOL)retryable generation:(NSInteger)generation
{
    if (![self pp_beginTerminalResolutionForGeneration:generation label:@"error"]) {
        return;
    }

    PPORDERLog(@"Checkout error | generation=%ld | orderId=%@ | retryable=%d | error=%@",
               (long)generation,
               self.currentOrder.orderId ?: @"",
               retryable,
               error.localizedDescription ?: @"");
    // Force next attempt to re-resolve order from Firestore.
    self.currentOrder = nil;

    // Clear idempotency key so a retry starts with a fresh key.
    // Without this, backend deduplication may return the old failed order.
    self.checkoutIdempotencyKey = nil;

    [self cleanup];

    // H-07: Enrich the error with the retryable flag so the presentation
    // layer can offer a "Retry Payment" action for QIB payment failures
    // while keeping non-retryable validation errors (out-of-stock, etc.)
    // as simple dismissible alerts.
    NSError *deliveredError = error;
    if (retryable) {
        NSMutableDictionary *enrichedUserInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
        enrichedUserInfo[PPCheckoutErrorIsRetryableKey] = @YES;
        deliveredError = [NSError errorWithDomain:error.domain
                                             code:error.code
                                         userInfo:[enrichedUserInfo copy]];
    }

    if (self.completion) {
        self.completion(PPCheckoutResultFailed, self.currentOrder, deliveredError);
    }
}

- (void)cleanup
{
    if (self.orderListener) {
        [self.orderListener remove];
        self.orderListener = nil;
    }
    
    // H-08: Stop listening for app-resume when checkout is no longer active.
    [self pp_unregisterForAppResumeNotification];
    
    [CartManager.sharedManager setValue:@(NO) forKey:@"_isLocked"];
    self.isCheckoutInProgress = NO;
    self.selectedPaymentMethodId = @"";
}

- (NSError *)checkoutInventoryErrorFromIssues:(NSArray<NSDictionary *> *)issues
{
    if (issues.count == 0) {
        return [NSError errorWithDomain:@"Checkout"
                                   code:1003
                               userInfo:@{
            NSLocalizedDescriptionKey: kLang(@"checkout_items_unavailable_default")
        }];
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSInteger maxLines = MIN(3, issues.count);
    for (NSInteger i = 0; i < maxLines; i++) {
        NSDictionary *issue = issues[i];
        NSString *name = issue[@"name"];
        NSInteger requested = [issue[@"requestedQty"] integerValue];
        NSInteger available = [issue[@"availableQty"] integerValue];
        NSString *title = name.length > 0 ? name : kLang(@"checkout_item_fallback");

        NSString *line = nil;
        if (available <= 0) {
            line = [NSString stringWithFormat:kLang(@"checkout_item_out_of_stock_format"), title];
        } else {
            line = [NSString stringWithFormat:kLang(@"checkout_item_limited_stock_format"),
                    title, (long)available, (long)requested];
        }
        [lines addObject:line];
    }

    if (issues.count > maxLines) {
        [lines addObject:[NSString stringWithFormat:kLang(@"checkout_more_items_format"),
                          (long)(issues.count - maxLines)]];
    }

    NSString *message = [lines componentsJoinedByString:@"\n"];
    return [NSError errorWithDomain:@"Checkout"
                               code:1003
                           userInfo:@{NSLocalizedDescriptionKey: message ?: kLang(@"checkout_items_unavailable_fallback")}];
}

- (void)dealloc {
    [self.orderListener remove];
    self.orderListener = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PPAppDidBecomeActiveNotification
                                                  object:nil];
}

#pragma mark - App Resume Checkpoint (H-08)

- (void)pp_registerForAppResumeNotification
{
    // Remove first to avoid duplicate registrations when reusing an order.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PPAppDidBecomeActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidBecomeActive)
                                                 name:PPAppDidBecomeActiveNotification
                                               object:nil];
}

- (void)pp_unregisterForAppResumeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PPAppDidBecomeActiveNotification
                                                  object:nil];
}

- (void)handleAppDidBecomeActive
{
    // Only act when a QIB payment is actively in flight.
    if (!self.isCheckoutInProgress) return;
    if (self.hasResolvedCheckout) return;

    NSString *orderId = PPCheckoutTrimmedString(self.currentOrder.orderId);
    if (orderId.length == 0) return;

    NSInteger generation = self.checkoutGeneration;
    if (generation <= 0) return;

    PPORDERLog(@"App resumed during active checkout | generation=%ld | orderId=%@",
               (long)generation, orderId);

    // Supplementary one-shot fetch to catch status changes that occurred
    // while the app was backgrounded (e.g. user completed OTP in banking app).
    // The existing Firestore listener will reconnect on its own, but there is
    // a window where the listener has not yet delivered the latest snapshot.
    // This fetch closes that gap.
    [self pp_fetchLatestOrderSnapshotForOrder:self.currentOrder
                                   generation:generation
                                       reason:@"app_did_become_active"
                                   completion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                PPOrder * _Nullable latestOrder,
                                                NSError * _Nullable error) {
        // Generation and resolution guards are already enforced inside
        // pp_fetchLatestOrderSnapshotForOrder and the terminal methods below.
        if (![self pp_isCheckoutGenerationCurrent:generation] || self.hasResolvedCheckout) {
            return;
        }

        if (latestOrder && PPCheckoutOrderHasSuccessState(latestOrder)) {
            PPORDERLog(@"App resume detected payment success | generation=%ld | orderId=%@",
                       (long)generation, orderId);
            [self completeWithSuccess:snapshot generation:generation];
            return;
        }

        if (latestOrder && PPCheckoutOrderHasFailureState(latestOrder)) {
            PPORDERLog(@"App resume detected payment failure | generation=%ld | orderId=%@",
                       (long)generation, orderId);
            [self completeWithFailure:snapshot generation:generation];
            return;
        }

        // Still pending — the Firestore listener will deliver subsequent updates.
        PPORDERLog(@"App resume: order still pending | generation=%ld | orderId=%@",
                   (long)generation, orderId);
    }];
}

@end
