//
//  PPCheckoutCoordinator 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//


#import "PPCheckoutCoordinator.h"

#import "CartManager.h"
#import "PPOrderManager.h"
#import "PPPaymentManager.h"
#import "PPOrder.h"
#import "PPAddressModel.h"
#import "PPAddressesManager.h"
#import <math.h>


@interface PPCheckoutCoordinator ()

@property (nonatomic, weak) UIViewController *presentingVC;
@property (nonatomic, copy) PPCheckoutCompletion completion;

@property (nonatomic, strong) PPOrder *currentOrder;
@property (nonatomic, strong, nullable) PPAddressModel *selectedAddress;
@property (nonatomic, copy) NSString *selectedPaymentMethodId;
@property (nonatomic, strong) id<FIRListenerRegistration> orderListener;
@property (nonatomic, assign) BOOL isCheckoutInProgress;

- (NSError *)checkoutInventoryErrorFromIssues:(NSArray<NSDictionary *> *)issues;
- (void)completeWithPendingVerification:(NSError *)error;

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
    NSString *customDomain = PPCheckoutTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsCustomDomain"]);
    if (customDomain.length > 0) {
        return [FIRFunctions functionsForCustomDomain:customDomain];
    }

    NSString *region = PPCheckoutTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsRegion"]);
    if (region.length == 0) {
        region = @"us-central1";
    }
    return [FIRFunctions functionsForRegion:region];
}

@implementation PPCheckoutCoordinator

- (instancetype)initWithPresentingViewController:(UIViewController *)viewController
{
    self = [super init];
    if (self) {
        _presentingVC = viewController;
    }
    return self;
}

- (void)startCheckoutWithCompletion:(PPCheckoutCompletion)completion
{
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(PPCheckoutResultFailed, nil, error);
            }
            return;
        }

        PPAddressModel *fallbackAddress = nil;
        for (PPAddressModel *candidate in addresses ?: @[]) {
            if (candidate.isDefault) {
                fallbackAddress = candidate;
                break;
            }
        }
        if (!fallbackAddress && addresses.count > 0) {
            fallbackAddress = addresses.firstObject;
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
    NSLog(@"[CHECKOUT] 🔵 Start checkout flow");

    if (self.isCheckoutInProgress) {
        NSLog(@"[CHECKOUT] ⏳ Checkout already in progress, ignoring duplicate trigger");
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
    CartManager *cart = CartManager.sharedManager;

    // 1️⃣ Validate cart
    if (cart.isCartEmpty) {
        NSLog(@"[CHECKOUT] ❌ Cart empty — aborting");
        NSError *error = [NSError errorWithDomain:@"Checkout"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_cart_empty")}];
        if (completion) completion(PPCheckoutResultFailed, nil, error);
        return;
    }

    self.isCheckoutInProgress = YES;

    double cartSubtotal = [cart subtotalAmount];
    double cartTotal = [cart totalAmount];

    NSLog(@"[CHECKOUT] 🧾 Cart validated | items=%lu | subtotal=%.2f | total=%.2f",
          (unsigned long)cart.cartItems.count,
          cartSubtotal,
          cartTotal);

    // 2️⃣ Lock cart
    [cart setValue:@(YES) forKey:@"_isLocked"];
    NSLog(@"[CHECKOUT] 🔒 Cart locked");

    NSArray<NSDictionary *> *items = [cart.cartItems valueForKey:@"firestoreDictionary"];

    // 3️⃣ Live stock validation before payment
    NSLog(@"[CHECKOUT] 📦 Validating live inventory...");
    [[PPOrderManager shared]
     validateInventoryForItems:items
     completion:^(BOOL inStock, NSArray<NSDictionary *> *issues, NSError * _Nullable inventoryError) {
        if (inventoryError || !inStock) {
            NSError *error = inventoryError ?: [self checkoutInventoryErrorFromIssues:issues];
            NSLog(@"[CHECKOUT] ❌ Inventory validation failed: %@", error.localizedDescription);
            [cart setValue:@(NO) forKey:@"_isLocked"];
            self.isCheckoutInProgress = NO;
            if (completion) completion(PPCheckoutResultFailed, nil, error);
            return;
        }

        // Reuse in-memory order while staying on same payment screen/session.
        if (self.currentOrder.orderId.length > 0 &&
            self.currentOrder.status == PPOrderStatusPending &&
            [self.currentOrder.paymentMethodId isEqualToString:self.selectedPaymentMethodId] &&
            PPCheckoutOrderMatchesCart(self.currentOrder, items, cartSubtotal, self.selectedAddress.documentID)) {
            NSLog(@"[CHECKOUT] ♻️ Reusing in-memory order | orderId=%@", self.currentOrder.orderId);
            if ([self.selectedPaymentMethodId isEqualToString:@"cash"]) {
                [self completeWithSuccess:nil];
            } else {
                [self startListeningToOrder:self.currentOrder];
                [self beginPaymentForOrder:self.currentOrder];
            }
            return;
        }
        if (self.currentOrder.orderId.length > 0) {
            // Cart changed or order state drifted; avoid charging stale order details.
            self.currentOrder = nil;
        }

        // 4️⃣ Reuse or create pending order
        NSLog(@"[CHECKOUT] 📦 Resolving pending order in Firestore...");
        [[PPOrderManager shared]
         fetchOrCreatePendingOrderWithItems:items
         amount:cartSubtotal
         address:self.selectedAddress
         paymentMethodId:self.selectedPaymentMethodId
         completion:^(PPOrder *order, NSError *error) {
            if (error || !order) {
                NSLog(@"[CHECKOUT] ❌ Failed to resolve pending order: %@", error.localizedDescription);
                [cart setValue:@(NO) forKey:@"_isLocked"];
                self.isCheckoutInProgress = NO;
                if (completion) completion(PPCheckoutResultFailed, nil, error);
                return;
            }

            NSLog(@"[CHECKOUT] ✅ Pending order ready | orderId=%@", order.orderId);
            self.currentOrder = order;

            if ([self.selectedPaymentMethodId isEqualToString:@"cash"] || [order isCashOnDelivery]) {
                NSLog(@"[CHECKOUT] 💵 Cash on delivery order placed");
                [self completeWithSuccess:nil];
                return;
            }

            // 5️⃣ Observe order status
            NSLog(@"[CHECKOUT] 👂 Listening to order status changes");
            [self startListeningToOrder:order];

            // 6️⃣ Start payment
            [self beginPaymentForOrder:order];
        }];
    }];
}

#pragma mark - Firestore Order Listener

- (void)beginPaymentForOrder:(PPOrder *)order
{
    if ([order isCashOnDelivery]) {
        NSLog(@"[CHECKOUT] ℹ️ Skipping QIB flow for cash on delivery");
        [self completeWithSuccess:nil];
        return;
    }

    NSLog(@"[CHECKOUT] 💳 Starting QIB payment");

    [[PPPaymentManager shared]
     startPaymentForOrder:order
     fromViewController:self.presentingVC
     completion:^(NSDictionary *response, NSError *error) {

        if (error || !response) {
            NSLog(@"[CHECKOUT] ❌ Payment SDK failed: %@", error.localizedDescription);
            [self failOrderWithError:error];
            return;
        }

        NSLog(@"[CHECKOUT] 🟢 Payment response received: %@", response);

        NSString *paymentAttemptId = PPCheckoutTrimmedString(order.paymentAttemptId);
        NSString *qibSessionId = PPCheckoutTrimmedString(order.qibSessionId);
        if (paymentAttemptId.length == 0 || qibSessionId.length == 0) {
            NSError *bindingError =
            [NSError errorWithDomain:@"Checkout"
                                code:1007
                            userInfo:@{NSLocalizedDescriptionKey:
                                           kLang(@"payment_secure_session_unavailable")}];
            [self failOrderWithError:bindingError];
            return;
        }

        // 6️⃣ Verify payment via Cloud Function
        NSLog(@"[CHECKOUT] ☁️ Verifying payment with Cloud Function...");

        FIRFunctions *functions = PPCheckoutFunctionsClient();

        [[functions HTTPSCallableWithName:@"verifyQibPayment"]
         callWithObject:@{
            @"orderId": order.orderId,
            @"paymentAttemptId": paymentAttemptId,
            @"qibSessionId": qibSessionId,
            @"paymentResponse": response
        }
         completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {

            if (error) {
                NSLog(@"[CHECKOUT] ❌ Verification failed: %@", error.localizedDescription);
                [self failOrderWithError:error];
                return;
            }

            NSDictionary *verificationData = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            NSString *verificationStatus = PPCheckoutNormalizedStatusString(verificationData[@"status"]);
            if ([verificationStatus isEqualToString:@"verification_pending"] ||
                [verificationStatus isEqualToString:@"pending"]) {
                NSLog(@"[CHECKOUT] ⏳ Verification pending: %@", verificationData);
                NSError *pendingError =
                [NSError errorWithDomain:@"Checkout"
                                    code:1006
                                userInfo:@{NSLocalizedDescriptionKey:
                                               kLang(@"checkout_payment_verification_pending")}];
                [self completeWithPendingVerification:pendingError];
                return;
            }

            NSLog(@"[CHECKOUT] 🎉 Payment verified successfully: %@", verificationData);
        }];
    }];
}

- (void)startListeningToOrder:(PPOrder *)order
{
    FIRFirestore *db = FIRFirestore.firestore;
    if (self.orderListener) {
        [self.orderListener remove];
        self.orderListener = nil;
    }
    
    // U4: Prevent retain cycle in order listener
    __weak typeof(self) weakSelf = self;
    self.orderListener =
    [[[db collectionWithPath:@"Orders"] documentWithPath:order.orderId]  addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // U9: Log errors instead of silently returning
        if (error) {
            NSLog(@"⚠️ [Checkout] Order listener error: %@", error.localizedDescription);
            return;
        }
        if (!snapshot.exists) return;
        
        NSString *status = PPCheckoutNormalizedStatusString(snapshot.data[@"status"]);
        
        if (PPCheckoutIsPaidLikeStatus(status)) {
            [strongSelf completeWithSuccess:snapshot];
        }
        else if (PPCheckoutIsFailedLikeStatus(status)) {
            [strongSelf completeWithFailure:snapshot];
        }
    }];
}

#pragma mark - Completion

- (void)completeWithSuccess:(FIRDocumentSnapshot * _Nullable)snapshot
{
    if (snapshot) {
        PPOrder *updatedOrder = [PPOrder orderFromSnapshot:snapshot];
        if (updatedOrder) {
            self.currentOrder = updatedOrder;
        }
    }

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

- (void)completeWithFailure:(FIRDocumentSnapshot *)snapshot
{
    PPOrder *updatedOrder = [PPOrder orderFromSnapshot:snapshot];
    if (updatedOrder) {
        self.currentOrder = updatedOrder;
    }

    [self cleanup];
    
    NSString *reason = snapshot.data[@"failureReason"] ?: kLang(@"checkout_payment_failed_default");
    NSError *error =
    [NSError errorWithDomain:@"Checkout"
                        code:1002
                    userInfo:@{NSLocalizedDescriptionKey: reason}];
    
    if (self.completion) {
        self.completion(PPCheckoutResultFailed, self.currentOrder, error);
    }
}

- (void)completeWithPendingVerification:(NSError *)error
{
    [self cleanup];

    if (self.completion) {
        self.completion(PPCheckoutResultPendingVerification, self.currentOrder, error);
    }
}

- (void)failOrderWithError:(NSError *)error
{
    // Force next attempt to re-resolve order from Firestore.
    self.currentOrder = nil;

    [self cleanup];
    
    if (self.completion) {
        self.completion(PPCheckoutResultFailed, self.currentOrder, error);
    }
}

- (void)cleanup
{
    if (self.orderListener) {
        [self.orderListener remove];
        self.orderListener = nil;
    }
    
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
        NSString *itemID = issue[@"itemID"];
        NSInteger requested = [issue[@"requestedQty"] integerValue];
        NSInteger available = [issue[@"availableQty"] integerValue];
        NSString *title = name.length > 0 ? name : (itemID.length > 0 ? itemID : kLang(@"checkout_item_fallback"));

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

@end
