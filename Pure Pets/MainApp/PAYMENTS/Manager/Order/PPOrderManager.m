//
//  PPOrderManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/02/2026.
//


#import "PPOrderManager.h"
#import "PPFulfillmentOrder.h"
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <FirebaseAuth/FirebaseAuth.h>
@import FirebaseFunctions;
@import FirebaseStorage;
#import <math.h>
#import "PPAddressModel.h"
#import "CountryModel.h"
#import "CitiesManager.h"
#import "PPFirebaseSessionBridge.h"

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

static NSString *const PPOrderInventoryErrorDomain = @"PPOrderInventory";
static NSString *const PPOrderSupportErrorDomain = @"PPOrderSupport";

static NSString *const PPOrderRequestStatusPendingReview = @"pending_review";
static NSString *const PPOrderRequestStatusApproved = @"approved";
static NSString *const PPOrderRequestStatusRejected = @"rejected";
static NSString *const PPOrderRequestStatusCompleted = @"completed";
static NSString *const PPOrderRequestStatusRefunded = @"refunded";
static NSString *const PPOrderRequestStatusPartiallyRefunded = @"partially_refunded";
static NSString *const PPOrderRequestStatusCancelled = @"cancelled";
static NSString *const PPOrderRequestStatusClosed = @"closed";

static NSInteger const PPOrderReturnWindowDays = 7;
static NSInteger const PPOrderReplacementWindowDays = 7;
static NSInteger const PPOrderRefundWindowDays = 14;
static NSInteger const PPOrderComplaintWindowDays = 30;
static NSInteger const PPOrderSupportMaxAttachmentCount = 4;
static NSInteger const PPOrderSupportAttachmentMaxKB = 900;

static NSString *PPOrderNormalizedPaymentMethodKey(NSString *paymentMethodID, NSString *paymentProvider);

static NSString *PPOrderItemsSignature(NSArray<NSDictionary *> *items) {
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

static BOOL PPOrderMatchesCart(PPOrder *order, NSArray<NSDictionary *> *items, double amount, NSString *addressID) {
    if (!order) return NO;
    if (fabs(order.amount - amount) > 0.01) return NO;
    if (addressID.length > 0 && ![order.shippingAddressId isEqualToString:addressID]) return NO;
    NSString *candidateSignature = PPOrderItemsSignature(order.items);
    NSString *targetSignature = PPOrderItemsSignature(items);
    return [candidateSignature isEqualToString:targetSignature];
}

static BOOL PPOrderMatchesCartForPaymentMethod(PPOrder *order, NSArray<NSDictionary *> *items, double amount, NSString *addressID, NSString *paymentMethodID) {
    if (!PPOrderMatchesCart(order, items, amount, addressID)) {
        return NO;
    }
    NSString *expectedMethod = PPOrderNormalizedPaymentMethodKey(paymentMethodID, nil);
    NSString *actualMethod = PPOrderNormalizedPaymentMethodKey(order.paymentMethodId, order.paymentProvider);
    return [expectedMethod isEqualToString:actualMethod];
}

static BOOL PPOrderIsRecent(PPOrder *order, NSTimeInterval now, NSTimeInterval maxAge) {
    NSTimeInterval createdTime = order.createdAt.timeIntervalSince1970;
    if (createdTime <= 0) return NO;
    return ((now - createdTime) <= maxAge);
}

static NSString *PPOrderItemIDFromDict(NSDictionary *item) {
    if (![item isKindOfClass:NSDictionary.class]) return @"";
    NSString *itemID = item[@"id"];
    if (![itemID isKindOfClass:NSString.class] || itemID.length == 0) {
        itemID = item[@"itemID"];
    }
    return [itemID isKindOfClass:NSString.class] ? itemID : @"";
}

static NSInteger PPOrderItemQtyFromDict(NSDictionary *item) {
    if (![item isKindOfClass:NSDictionary.class]) return 0;
    id rawQty = item[@"qty"] ?: item[@"quantity"];
    if (![rawQty respondsToSelector:@selector(integerValue)]) return 0;
    return MAX(0, [rawQty integerValue]);
}

static NSString *PPOrderItemNameFromDict(NSDictionary *item) {
    if (![item isKindOfClass:NSDictionary.class]) return @"";
    NSString *name = item[@"name"];
    return [name isKindOfClass:NSString.class] ? name : @"";
}

static NSString *PPOrderTrimmedString(NSString *value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPOrderNormalizedStatusString(id value) {
    NSString *normalized = [[PPOrderTrimmedString(value) lowercaseString] copy];
    if (normalized.length == 0) return @"";
    normalized = [normalized stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([normalized containsString:@"__"]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return normalized;
}

static BOOL PPOrderStatusContainsToken(NSString *status, NSString *token) {
    if (status.length == 0 || token.length == 0) return NO;
    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", status];
    NSString *wrappedToken = [NSString stringWithFormat:@"_%@_", token];
    return [wrappedStatus containsString:wrappedToken];
}

static BOOL PPOrderIsPaidLikeStatus(NSString *status) {
    return PPOrderStatusContainsToken(status, @"paid") ||
           PPOrderStatusContainsToken(status, @"success") ||
           PPOrderStatusContainsToken(status, @"succeeded") ||
           PPOrderStatusContainsToken(status, @"captured") ||
           PPOrderStatusContainsToken(status, @"authorized") ||
           PPOrderStatusContainsToken(status, @"completed");
}

static NSString *PPOrderNormalizedPaymentMethodKey(NSString *paymentMethodID, NSString *paymentProvider) {
    return [PPOrder normalizedPaymentMethodFromRawValue:paymentMethodID provider:paymentProvider];
}

static BOOL PPOrderHasCapturedPayment(PPOrder *order) {
    return [order hasCapturedPayment];
}

static NSString *PPOrderResolvedPaymentProviderForMethod(NSString *paymentMethodID) {
    return [PPOrderNormalizedPaymentMethodKey(paymentMethodID, nil) isEqualToString:@"cash"] ? @"CASH" : @"QIB";
}

static FIRFunctions *PPOrderFunctionsClient(void) {
    static FIRFunctions *functions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *customDomain = PPOrderTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsCustomDomain"]);
        if (customDomain.length > 0) {
            functions = [FIRFunctions functionsForCustomDomain:customDomain];
        } else {
            NSString *region = PPOrderTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsRegion"]);
            if (region.length == 0) {
                region = @"us-central1";
            }
            functions = [FIRFunctions functionsForRegion:region];
        }
    });
    // App Check tokens are auto-attached by FIRFunctions when FIRAppCheck is
    // configured globally in AppDelegate. The previous private-API invocation
    // (setUseAppCheckLimitedUseTokens: via NSInvocation) was removed — it
    // silently failed on SDK 12.12.0 and blocked token attachment entirely.
    return functions;
}

static FIRFunctions *PPOrderDefaultFunctionsClient(void) {
    static FIRFunctions *functions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *region = PPOrderTrimmedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"PPQIBFunctionsRegion"]);
        if (region.length == 0) {
            region = @"us-central1";
        }
        functions = [FIRFunctions functionsForRegion:region];
    });
    return functions;
}

static NSString *PPOrderFunctionsMessageCandidate(id value, NSInteger depth) {
    if (!value || depth > 4) return @"";

    if ([value isKindOfClass:NSString.class]) {
        return PPOrderTrimmedString((NSString *)value);
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
            NSString *candidate = PPOrderFunctionsMessageCandidate(dictionary[key], depth + 1);
            if (candidate.length > 0) {
                return candidate;
            }
        }
        for (id nestedValue in dictionary.allValues) {
            NSString *candidate = PPOrderFunctionsMessageCandidate(nestedValue, depth + 1);
            if (candidate.length > 0) {
                return candidate;
            }
        }
        return @"";
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id nestedValue in (NSArray *)value) {
            NSString *candidate = PPOrderFunctionsMessageCandidate(nestedValue, depth + 1);
            if (candidate.length > 0) {
                return candidate;
            }
        }
        return @"";
    }
    if ([value isKindOfClass:NSError.class]) {
        NSError *nestedError = (NSError *)value;
        NSString *candidate = PPOrderFunctionsMessageCandidate(nestedError.userInfo, depth + 1);
        if (candidate.length > 0) {
            return candidate;
        }

        candidate = PPOrderTrimmedString(nestedError.localizedFailureReason);
        if (candidate.length > 0) {
            return candidate;
        }

        return PPOrderTrimmedString(nestedError.localizedDescription);
    }

    if ([value respondsToSelector:@selector(stringValue)]) {
        return PPOrderTrimmedString([value stringValue]);
    }
    return @"";
}

static NSString *PPOrderLocalizedKnownBackendMessage(NSString *message) {
    NSString *trimmed = PPOrderTrimmedString(message);
    if (trimmed.length == 0) return @"";

    NSString *lowercase = trimmed.lowercaseString;
    if (([lowercase containsString:@"item "] || [lowercase containsString:@"cart item"]) &&
        ([lowercase containsString:@"unavailable"] ||
         [lowercase containsString:@"not available"] ||
         [lowercase containsString:@"no longer available"] ||
         [lowercase containsString:@"out of stock"])) {
        return kLang(@"checkout_item_unavailable_review_cart");
    }
    if ([lowercase containsString:@"inventory"] || [lowercase containsString:@"stock"]) {
        return kLang(@"checkout_items_unavailable_review_cart");
    }
    if ([lowercase containsString:@"must be a positive number"] ||
        [lowercase containsString:@"invalid price"]) {
        return kLang(@"checkout_item_price_invalid");
    }
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

static NSString *PPOrderFunctionsServerMessageFromError(NSError *error) {
    if (!error) return @"";

    NSString *candidate = PPOrderFunctionsMessageCandidate(error.userInfo, 0);
    if (candidate.length == 0) {
        candidate = PPOrderTrimmedString(error.localizedFailureReason);
    }
    if (candidate.length == 0) {
        candidate = PPOrderTrimmedString(error.localizedDescription);
    }
    return PPOrderLocalizedKnownBackendMessage(candidate);
}

static BOOL PPOrderTextContainsAnyToken(NSString *text, NSArray<NSString *> *tokens) {
    NSString *lowercase = [PPOrderTrimmedString(text).lowercaseString copy];
    if (lowercase.length == 0) return NO;
    for (NSString *token in tokens ?: @[]) {
        if (![token isKindOfClass:NSString.class] || token.length == 0) continue;
        if ([lowercase containsString:token.lowercaseString]) {
            return YES;
        }
    }
    return NO;
}

static BOOL PPOrderErrorLooksLikeAppCheck(NSError *error, NSString *serverMessage) {
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@",
                          error.domain ?: @"",
                          error.localizedDescription ?: @"",
                          error.localizedFailureReason ?: @"",
                          serverMessage ?: @""];
    return PPOrderTextContainsAnyToken(combined, @[
        @"app check", @"appcheck", @"app attest", @"appattest", @"devicecheck"
    ]);
}

static BOOL PPOrderErrorLooksLikeAuth(NSError *error, NSString *serverMessage) {
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@",
                          error.domain ?: @"",
                          error.localizedDescription ?: @"",
                          error.localizedFailureReason ?: @"",
                          serverMessage ?: @""];
    return PPOrderTextContainsAnyToken(combined, @[
        @"unauthenticated", @"auth token", @"id token", @"refresh your session"
    ]);
}

static BOOL PPOrderErrorLooksLikeUnsafeInternal(NSError *error, NSString *serverMessage) {
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@",
                          error.domain ?: @"",
                          error.localizedDescription ?: @"",
                          error.localizedFailureReason ?: @"",
                          serverMessage ?: @""];
    return PPOrderTextContainsAnyToken(combined, @[
        @"internal error", @"print and inspect", @"firebasefunctions"
    ]);
}

static NSString *PPOrderFriendlyFunctionsErrorMessage(NSError *error) {
    if (!error) return @"";

    NSString *domain = [PPOrderTrimmedString(error.domain).lowercaseString copy];
    BOOL isFunctionsError = [domain containsString:@"functions"];
    NSString *serverMessage = PPOrderFunctionsServerMessageFromError(error);
    if (PPOrderErrorLooksLikeAppCheck(error, serverMessage)) {
        return kLang(@"pp_app_check_unavailable");
    }
    if (PPOrderErrorLooksLikeAuth(error, serverMessage)) {
        return kLang(@"pp_auth_session_refresh_failed");
    }
    if (PPOrderErrorLooksLikeUnsafeInternal(error, serverMessage)) {
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
            return kLang(@"auth_register_required_title");
        case FIRFunctionsErrorCodePermissionDenied:
            return kLang(@"payment_backend_permission_denied");
        case FIRFunctionsErrorCodeDeadlineExceeded:
        case FIRFunctionsErrorCodeUnavailable:
            return kLang(@"payment_backend_unreachable");
        case FIRFunctionsErrorCodeFailedPrecondition:
            return serverMessage.length > 0 ? serverMessage : kLang(@"payment_backend_setup_incomplete");
        case FIRFunctionsErrorCodeInternal:
            // Cloud Run returned a non-Firebase-formatted error (e.g. IAM 401) or an
            // unhandled exception. The raw message ("An internal error has occurred,
            // print and inspect...") is never user-safe — show the generic unreachable
            // message and let the caller offer a retry.
            return kLang(@"payment_backend_unreachable");
        default:
            return serverMessage.length > 0 ? serverMessage : kLang(@"payment_backend_unreachable");
    }
}

static NSError *PPOrderWrappedCallableError(NSError *error) {
    if (!error) return nil;
    NSString *friendlyMessage = PPOrderFriendlyFunctionsErrorMessage(error);
    if (friendlyMessage.length == 0 || [friendlyMessage isEqualToString:error.localizedDescription]) {
        return error;
    }

    NSMutableDictionary *userInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = friendlyMessage;
    return [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
}

static BOOL PPOrderIsSupportedCheckoutCurrency(NSString *currencyCode) {
    NSString *normalized = [PPOrderTrimmedString(currencyCode).uppercaseString copy];
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

static NSString *PPOrderCheckoutCurrencyOrDefault(NSString *currencyCode) {
    NSString *normalized = [PPOrderTrimmedString(currencyCode).uppercaseString copy];
    return PPOrderIsSupportedCheckoutCurrency(normalized) ? normalized : @"QAR";
}

static NSString *PPOrderResolvedCurrencyCode(void) {
    return PPOrderCheckoutCurrencyOrDefault([CountryModel safeCurrentCurrencyCode]);
}

static NSString *PPOrderAddressEffectiveID(PPAddressModel *address) {
    if (!address) return @"";
    NSString *effectiveID = address.documentID.length > 0 ? address.documentID : address.addressID;
    if (effectiveID.length == 0) return @"";
    if (address.documentID.length == 0) {
        address.documentID = effectiveID;
    }
    if (address.addressID.length == 0) {
        address.addressID = effectiveID;
    }
    return effectiveID;
}

static BOOL PPOrderAddressHasMinimumData(PPAddressModel *address) {
    if (!address) return NO;
    if (PPOrderAddressEffectiveID(address).length == 0) return NO;

    // Mirror the server-side hasValidShippingSnapshot requirements exactly so
    // we reject incomplete addresses on the client before the server does.
    // Server requires: fullName, addressLine1, postalCode all non-empty;
    //                  cityID > 0; stateID > 0.
    if (PPOrderTrimmedString(address.fullName).length == 0) return NO;
    if (PPOrderTrimmedString(address.addressLine1).length == 0) return NO;
    if (PPOrderTrimmedString(address.postalCode).length == 0) return NO;
    if (address.cityID <= 0) return NO;
    if (address.stateID <= 0) return NO;
    return YES;
}

static NSDictionary *PPOrderShippingSnapshotFromAddress(PPAddressModel *address, NSString *expectedUserID) {
    NSString *effectiveID = PPOrderAddressEffectiveID(address);
    if (!address || !PPOrderAddressHasMinimumData(address) || effectiveID.length == 0) {
        return nil;
    }
    NSString *ownerUID = expectedUserID ?: @"";
    if (ownerUID.length == 0) {
        ownerUID = address.userID ?: @"";
    }
    if (ownerUID.length == 0) {
        ownerUID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    if (ownerUID.length == 0) {
        return nil;
    }
    NSMutableDictionary *snapshot = [[address toDictionary] mutableCopy];
    snapshot[@"addressID"] = effectiveID;
    snapshot[@"userID"] = ownerUID ?: @"";
    snapshot[@"displayName"] = address.displayName ?: @"";
    NSString *addressPhone = PPOrderTrimmedString(address.phoneNumber);
    snapshot[@"phoneNumber"] = addressPhone ?: @"";
    snapshot[@"phone"] = addressPhone ?: @"";
    return snapshot.copy;
}

static NSMutableDictionary<NSString *, NSMutableDictionary *> *PPAggregateRequestedItems(NSArray<NSDictionary *> *items) {
    NSMutableDictionary<NSString *, NSMutableDictionary *> *aggregated = [NSMutableDictionary dictionary];
    for (NSDictionary *item in items ?: @[]) {
        NSString *itemID = PPOrderItemIDFromDict(item);
        NSInteger qty = PPOrderItemQtyFromDict(item);
        if (itemID.length == 0 || qty <= 0) continue;

        NSMutableDictionary *entry = aggregated[itemID];
        if (!entry) {
            entry = [@{
                @"itemID": itemID,
                @"name": PPOrderItemNameFromDict(item) ?: @"",
                @"requestedQty": @(0)
            } mutableCopy];
            aggregated[itemID] = entry;
        }

        NSInteger currentQty = [entry[@"requestedQty"] integerValue];
        entry[@"requestedQty"] = @(currentQty + qty);

        NSString *existingName = entry[@"name"];
        if (existingName.length == 0) {
            entry[@"name"] = PPOrderItemNameFromDict(item) ?: @"";
        }
    }
    return aggregated;
}

static NSString *PPOrderSupportSafeString(id value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSDate *PPOrderSupportDateFromValue(id value) {
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return ((FIRTimestamp *)value).dateValue;
    }
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    return nil;
}

static NSArray<NSString *> *PPOrderSupportStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (id entry in (NSArray *)value) {
        NSString *string = PPOrderSupportSafeString(entry);
        if (string.length > 0) [result addObject:string];
    }
    return result.copy;
}

static BOOL PPOrderStatusMatchesAnyKeyword(NSString *statusKey, NSArray<NSString *> *keywords) {
    if (statusKey.length == 0) return NO;
    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", statusKey];
    for (NSString *keyword in keywords ?: @[]) {
        NSString *normalizedKeyword = PPOrderNormalizedStatusString(keyword);
        if (normalizedKeyword.length == 0) continue;
        if ([statusKey isEqualToString:normalizedKeyword]) return YES;
        if ([wrappedStatus containsString:[NSString stringWithFormat:@"_%@_", normalizedKeyword]]) return YES;
        if ([statusKey containsString:normalizedKeyword]) return YES;
    }
    return NO;
}

static BOOL PPOrderStatusIsCancelledLike(NSString *statusKey) {
    return PPOrderStatusMatchesAnyKeyword(statusKey, @[@"cancelled", @"canceled"]);
}

static BOOL PPOrderStatusIsDeliveredLike(NSString *statusKey) {
    return PPOrderStatusMatchesAnyKeyword(statusKey, @[@"delivered", @"completed", @"fulfilled"]);
}

static BOOL PPOrderStatusIsShippedLike(NSString *statusKey) {
    return PPOrderStatusMatchesAnyKeyword(statusKey, @[@"shipped", @"shipping", @"in_transit", @"out_for_delivery"]);
}

static BOOL PPOrderStatusIsPackingLike(NSString *statusKey) {
    return PPOrderStatusMatchesAnyKeyword(statusKey, @[@"processing", @"preparing", @"packed", @"confirmed"]);
}

static BOOL PPOrderStatusIsPaidLike(NSString *statusKey) {
    return PPOrderStatusMatchesAnyKeyword(statusKey, @[@"paid", @"success", @"approved", @"verified", @"captured", @"authorized", @"processing", @"preparing", @"packed", @"shipped", @"delivered", @"fulfilled"]);
}

static BOOL PPOrderStatusIsFailureLike(NSString *statusKey) {
    return PPOrderStatusMatchesAnyKeyword(statusKey, @[@"failed", @"rejected", @"cancelled", @"canceled", @"expired", @"error", @"voided"]);
}

static BOOL PPOrderRequestStatusIsOpen(NSString *statusKey) {
    NSString *normalized = PPOrderNormalizedStatusString(statusKey);
    if (normalized.length == 0) return YES;
    return ![@[
        PPOrderRequestStatusRejected,
        PPOrderRequestStatusCompleted,
        PPOrderRequestStatusRefunded,
        PPOrderRequestStatusPartiallyRefunded,
        PPOrderRequestStatusCancelled,
        PPOrderRequestStatusClosed
    ] containsObject:normalized];
}

static NSString *PPOrderRequestTypeForAction(PPOrderCustomerActionType actionType) {
    switch (actionType) {
        case PPOrderCustomerActionTypeCancel: return @"cancel";
        case PPOrderCustomerActionTypeReturn: return @"return";
        case PPOrderCustomerActionTypeRefund: return @"refund";
        case PPOrderCustomerActionTypeReplacement: return @"replacement";
        case PPOrderCustomerActionTypeComplaint: return @"complaint";
        case PPOrderCustomerActionTypeSupport: return @"support";
        case PPOrderCustomerActionTypeTrack: return @"track";
    }
    return @"support";
}

static NSDate *PPOrderSupportBestDate(NSArray<NSDate *> *candidates) {
    for (NSDate *candidate in candidates ?: @[]) {
        if ([candidate isKindOfClass:NSDate.class]) return candidate;
    }
    return nil;
}

static NSInteger PPOrderSupportElapsedDaysSince(NSDate *anchor, NSDate *referenceDate) {
    if (![anchor isKindOfClass:NSDate.class] || ![referenceDate isKindOfClass:NSDate.class]) {
        return NSIntegerMax;
    }
    NSTimeInterval seconds = [referenceDate timeIntervalSinceDate:anchor];
    if (seconds <= 0) return 0;
    return (NSInteger)floor(seconds / (60.0 * 60.0 * 24.0));
}

static BOOL PPOrderSupportHasOpenRequestForType(NSArray<PPOrderSupportRequest *> *requests, NSString *requestType) {
    NSString *normalizedType = PPOrderNormalizedStatusString(requestType);
    for (PPOrderSupportRequest *request in requests ?: @[]) {
        if ([[PPOrderNormalizedStatusString(request.type) copy] isEqualToString:normalizedType] &&
            PPOrderRequestStatusIsOpen(request.status)) {
            return YES;
        }
    }
    return NO;
}

static NSDictionary *PPOrderReasonOption(NSString *code, NSString *title, NSString *subtitle, BOOL requiresItemSelection) {
    return @{
        @"code": code ?: @"",
        @"title": title ?: @"",
        @"subtitle": subtitle ?: @"",
        @"requiresItemSelection": @(requiresItemSelection)
    };
}

static NSData *PPOrderCompressedJPEGData(UIImage *image, NSInteger maxSizeKB) {
    if (![image isKindOfClass:UIImage.class]) return nil;
    CGFloat compression = 0.82;
    NSData *data = UIImageJPEGRepresentation(image, compression);
    NSInteger maxBytes = MAX(100, maxSizeKB) * 1024;
    while (data.length > maxBytes && compression > 0.3) {
        compression -= 0.08;
        data = UIImageJPEGRepresentation(image, compression);
    }
    return data;
}

@implementation PPOrderSupportAttachment

+ (instancetype)attachmentFromDictionary:(NSDictionary *)dictionary
{
    PPOrderSupportAttachment *attachment = [PPOrderSupportAttachment new];
    attachment.attachmentURL = PPOrderSupportSafeString(dictionary[@"url"] ?: dictionary[@"attachmentURL"]);
    attachment.storagePath = PPOrderSupportSafeString(dictionary[@"storagePath"]);
    attachment.mimeType = PPOrderSupportSafeString(dictionary[@"mimeType"]);
    attachment.fileName = PPOrderSupportSafeString(dictionary[@"fileName"]);
    attachment.sizeBytes = [dictionary[@"sizeBytes"] respondsToSelector:@selector(integerValue)] ? [dictionary[@"sizeBytes"] integerValue] : 0;
    return attachment;
}

- (NSDictionary *)dictionaryValue
{
    return @{
        @"url": self.attachmentURL ?: @"",
        @"storagePath": self.storagePath ?: @"",
        @"mimeType": self.mimeType ?: @"image/jpeg",
        @"fileName": self.fileName ?: @"evidence.jpg",
        @"sizeBytes": @(MAX(0, self.sizeBytes))
    };
}

@end

@implementation PPOrderSupportRequest

+ (instancetype)requestFromSnapshot:(FIRDocumentSnapshot *)snapshot
{
    return [self requestFromDictionary:snapshot.data ?: @{} documentID:snapshot.documentID];
}

+ (instancetype)requestFromDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID
{
    PPOrderSupportRequest *request = [PPOrderSupportRequest new];
    request.requestId = PPOrderSupportSafeString(dictionary[@"requestId"]);
    if (request.requestId.length == 0) request.requestId = PPOrderSupportSafeString(documentID);
    request.orderId = PPOrderSupportSafeString(dictionary[@"orderId"]);
    request.userId = PPOrderSupportSafeString(dictionary[@"userId"]);
    request.type = PPOrderNormalizedStatusString(dictionary[@"type"]);
    request.reasonCode = PPOrderNormalizedStatusString(dictionary[@"reasonCode"]);
    request.reasonTitle = PPOrderSupportSafeString(dictionary[@"reasonTitle"]);
    request.issueCategory = PPOrderNormalizedStatusString(dictionary[@"issueCategory"]);
    request.subject = PPOrderSupportSafeString(dictionary[@"subject"]);
    request.notes = PPOrderSupportSafeString(dictionary[@"notes"]);
    request.status = PPOrderNormalizedStatusString(dictionary[@"status"]);
    request.finalResolution = PPOrderNormalizedStatusString(dictionary[@"finalResolution"]);
    request.dedupeKey = PPOrderSupportSafeString(dictionary[@"dedupeKey"]);
    request.itemIDs = PPOrderSupportStringArray(dictionary[@"itemIDs"]);
    request.itemSnapshots = [dictionary[@"itemSnapshots"] isKindOfClass:NSArray.class] ? dictionary[@"itemSnapshots"] : @[];

    NSMutableArray<PPOrderSupportAttachment *> *attachments = [NSMutableArray array];
    for (NSDictionary *rawAttachment in ([dictionary[@"attachments"] isKindOfClass:NSArray.class] ? dictionary[@"attachments"] : @[])) {
        if (![rawAttachment isKindOfClass:NSDictionary.class]) continue;
        [attachments addObject:[PPOrderSupportAttachment attachmentFromDictionary:rawAttachment]];
    }
    request.attachments = attachments.copy;

    request.resolutionMetadata = [dictionary[@"resolution"] isKindOfClass:NSDictionary.class] ? dictionary[@"resolution"] : nil;
    request.adminReview = [dictionary[@"adminReview"] isKindOfClass:NSDictionary.class] ? dictionary[@"adminReview"] : nil;
    request.submittedAt = PPOrderSupportDateFromValue(dictionary[@"submittedAt"]);
    request.resolvedAt = PPOrderSupportDateFromValue(dictionary[@"resolvedAt"]);
    request.createdAt = PPOrderSupportDateFromValue(dictionary[@"createdAt"]) ?: [NSDate date];
    request.updatedAt = PPOrderSupportDateFromValue(dictionary[@"updatedAt"]) ?: request.createdAt;
    return request;
}

@end

@implementation PPOrderTimelineEvent

+ (instancetype)eventFromSnapshot:(FIRDocumentSnapshot *)snapshot
{
    return [self eventFromDictionary:snapshot.data ?: @{} documentID:snapshot.documentID];
}

+ (instancetype)eventFromDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID
{
    PPOrderTimelineEvent *event = [PPOrderTimelineEvent new];
    event.eventId = PPOrderSupportSafeString(dictionary[@"eventId"]);
    if (event.eventId.length == 0) event.eventId = PPOrderSupportSafeString(documentID);
    event.type = PPOrderNormalizedStatusString(dictionary[@"type"]);
    event.status = PPOrderNormalizedStatusString(dictionary[@"status"]);
    event.actorType = PPOrderNormalizedStatusString(dictionary[@"actorType"]);
    event.summary = PPOrderSupportSafeString(dictionary[@"summary"]);
    event.metadata = [dictionary[@"metadata"] isKindOfClass:NSDictionary.class] ? dictionary[@"metadata"] : nil;
    event.createdAt = PPOrderSupportDateFromValue(dictionary[@"createdAt"]) ?: [NSDate date];
    return event;
}

@end

@implementation PPOrderEligibilityDecision
@end

@implementation PPOrderSupportDraft
@end

@implementation PPOrderManager

+ (instancetype)shared
{
    static PPOrderManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [PPOrderManager new];
    });
    return mgr;
}

+ (NSString *)displayTitleForActionType:(PPOrderCustomerActionType)actionType
{
    switch (actionType) {
        case PPOrderCustomerActionTypeTrack: return kLang(@"order_action_track");
        case PPOrderCustomerActionTypeCancel: return kLang(@"order_action_cancel");
        case PPOrderCustomerActionTypeReturn: return kLang(@"order_action_return");
        case PPOrderCustomerActionTypeRefund: return kLang(@"order_action_refund");
        case PPOrderCustomerActionTypeReplacement: return kLang(@"order_action_replacement");
        case PPOrderCustomerActionTypeComplaint: return kLang(@"order_action_report_issue");
        case PPOrderCustomerActionTypeSupport: return kLang(@"order_action_support_case");
    }
    return kLang(@"order_action_support_case");
}

+ (NSString *)displayTitleForRequestType:(NSString *)requestType
{
    NSString *normalized = PPOrderNormalizedStatusString(requestType);
    if ([normalized isEqualToString:@"cancel"]) return kLang(@"order_action_cancel");
    if ([normalized isEqualToString:@"return"]) return kLang(@"order_action_return");
    if ([normalized isEqualToString:@"refund"]) return kLang(@"order_action_refund");
    if ([normalized isEqualToString:@"replacement"]) return kLang(@"order_action_replacement");
    if ([normalized isEqualToString:@"complaint"]) return kLang(@"order_action_report_issue");
    return kLang(@"order_action_support_case");
}

+ (NSString *)displayTitleForRequestStatus:(NSString *)status
{
    NSString *normalized = PPOrderNormalizedStatusString(status);
    if ([normalized isEqualToString:PPOrderRequestStatusPendingReview]) return kLang(@"order_request_status_pending_review");
    if ([normalized isEqualToString:PPOrderRequestStatusApproved]) return kLang(@"order_request_status_approved");
    if ([normalized isEqualToString:PPOrderRequestStatusRejected]) return kLang(@"order_request_status_rejected");
    if ([normalized isEqualToString:PPOrderRequestStatusCompleted]) return kLang(@"order_request_status_completed");
    if ([normalized isEqualToString:PPOrderRequestStatusRefunded]) return kLang(@"order_request_status_refunded");
    if ([normalized isEqualToString:PPOrderRequestStatusPartiallyRefunded]) return kLang(@"order_request_status_partially_refunded");
    if ([normalized isEqualToString:PPOrderRequestStatusCancelled]) return kLang(@"order_request_status_cancelled");
    if ([normalized isEqualToString:PPOrderRequestStatusClosed]) return kLang(@"order_request_status_closed");
    return kLang(@"order_request_status_pending_review");
}

- (void)createPendingOrderWithItems:(NSArray<NSDictionary *> *)items
                              amount:(double)amount
                            address:(PPAddressModel * _Nullable)address
                           completion:(void (^)(PPOrder *, NSError *))completion
{
    [self createPendingOrderWithItems:items
                               amount:amount
                             address:address
                     paymentMethodId:nil
                           completion:completion];
}

- (void)createPendingOrderWithItems:(NSArray<NSDictionary *> *)items
                              amount:(double)amount
                            address:(PPAddressModel * _Nullable)address
                    paymentMethodId:(NSString *)paymentMethodId
                          completion:(void (^)(PPOrder *, NSError *))completion
{
    [self createPendingOrderWithItems:items
                               amount:amount
                              address:address
                      paymentMethodId:paymentMethodId
                       idempotencyKey:nil
                           completion:completion];
}

- (void)createPendingOrderWithItems:(NSArray<NSDictionary *> *)items
                              amount:(double)amount
                            address:(PPAddressModel * _Nullable)address
                    paymentMethodId:(NSString *)paymentMethodId
                     idempotencyKey:(NSString *)idempotencyKey
                          completion:(void (^)(PPOrder *, NSError *))completion
{
    NSString *userId = [FIRAuth auth].currentUser.uid ?: @"";
    if (userId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PPOrder"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_register_required_subtitle")}];
        if (completion) completion(nil, error);
        return;
    }
    if (address.userID.length > 0 && ![address.userID isEqualToString:userId]) {
        NSError *ownershipError = [NSError errorWithDomain:@"PPOrder"
                                                      code:403
                                                  userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_address")}];
        if (completion) completion(nil, ownershipError);
        return;
    }
    NSMutableDictionary *shippingSnapshot = [PPOrderShippingSnapshotFromAddress(address, userId) mutableCopy];
    if (!shippingSnapshot) {
        NSError *addressError = [NSError errorWithDomain:@"PPOrder"
                                                    code:422
                                                userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_address")}];
        if (completion) completion(nil, addressError);
        return;
    }
    NSString *shippingAddressID = PPOrderAddressEffectiveID(address);
    NSString *resolvedPaymentMethodID = PPOrderNormalizedPaymentMethodKey(paymentMethodId, nil);
    NSString *resolvedPaymentProvider = PPOrderResolvedPaymentProviderForMethod(resolvedPaymentMethodID);

    FIRFunctions *functions = PPOrderFunctionsClient();
    NSMutableDictionary *payload = [@{
        @"items": items ?: @[],
        @"shippingAddressId": shippingAddressID ?: @"",
        @"currency": PPOrderResolvedCurrencyCode(),
        @"paymentProvider": resolvedPaymentProvider,
        @"paymentMethodId": resolvedPaymentMethodID
    } mutableCopy];
    if (idempotencyKey.length > 0) {
        payload[@"idempotencyKey"] = idempotencyKey;
    }

    PPORDERLog(@"Create pending order | items=%lu | amount=%.2f | addressId=%@ | paymentMethod=%@ | provider=%@",
               (unsigned long)items.count,
               amount,
               shippingAddressID ?: @"",
               resolvedPaymentMethodID ?: @"",
               resolvedPaymentProvider ?: @"");

    [PPFirebaseSessionBridge ensureFreshAuthSessionForcingRefresh:NO completion:^(NSError * _Nullable authError) {
        if (authError) {
            PPORDERLog(@"Create pending order auth preflight failed | paymentMethod=%@ | error=%@",
                       resolvedPaymentMethodID ?: @"",
                       authError.localizedDescription ?: @"Unknown");
            if (completion) completion(nil, authError);
            return;
        }

        [[functions HTTPSCallableWithName:@"createPendingOrder"]
         callWithObject:payload
         completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
            if (error || ![result.data isKindOfClass:NSDictionary.class]) {
                NSError *resolvedError = PPOrderWrappedCallableError(error);
                NSError *finalError = resolvedError ?: [NSError errorWithDomain:@"PPOrder"
                                                                           code:500
                                                                       userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_generic_error")}];
                PPORDERLog(@"Create pending order failed | paymentMethod=%@ | error=%@",
                           resolvedPaymentMethodID ?: @"",
                           finalError.localizedDescription ?: @"Unknown");
                if (completion) completion(nil, finalError);
                return;
            }

            NSDictionary *root = (NSDictionary *)result.data;
            NSDictionary *orderDict = [root[@"order"] isKindOfClass:NSDictionary.class] ? root[@"order"] : root;
            NSString *orderId = PPOrderTrimmedString(root[@"orderId"]);
            if (orderId.length == 0) {
                orderId = PPOrderTrimmedString(orderDict[@"orderId"]);
            }

            PPOrder *order = [PPOrder new];
            order.orderId = orderId ?: @"";
            NSString *orderNumber = PPOrderTrimmedString(root[@"orderNumber"]);
            if (orderNumber.length == 0) {
                orderNumber = PPOrderTrimmedString(orderDict[@"orderNumber"]);
            }
            if (orderNumber.length == 0) {
                orderNumber = PPOrderTrimmedString(root[@"displayOrderNumber"]);
            }
            if (orderNumber.length == 0) {
                orderNumber = PPOrderTrimmedString(orderDict[@"displayOrderNumber"]);
            }
            order.orderNumber = orderNumber.length > 0 ? orderNumber.uppercaseString : nil;
            order.userId = userId;
            order.status = PPOrderStatusPending;
            order.rawStatus = @"pending";
            order.amount = [orderDict[@"amount"] respondsToSelector:@selector(doubleValue)] ? [orderDict[@"amount"] doubleValue] : amount;
            order.shippingFee = [orderDict[@"shippingFee"] respondsToSelector:@selector(doubleValue)] ? [orderDict[@"shippingFee"] doubleValue] : 0.0;
            double totalAmount = [orderDict[@"totalAmount"] respondsToSelector:@selector(doubleValue)] ? [orderDict[@"totalAmount"] doubleValue] : order.amount;
            order.totalAmount = totalAmount > 0 ? totalAmount : order.amount;
            NSString *currency = PPOrderTrimmedString(orderDict[@"currency"]);
            order.currency = currency.length > 0 ? currency : PPOrderResolvedCurrencyCode();
            order.paymentMethodId = [PPOrder normalizedPaymentMethodFromRawValue:orderDict[@"paymentMethodId"]
                                                                        provider:orderDict[@"paymentProvider"]];
            order.paymentStatus = [PPOrder normalizedPaymentStatusFromRawValue:orderDict[@"paymentStatus"]
                                                                 paymentMethod:order.paymentMethodId
                                                                        status:order.rawStatus
                                                                   transaction:nil
                                                                        paidAt:nil
                                                             paymentCollectedAt:nil];
            NSString *provider = PPOrderTrimmedString(orderDict[@"paymentProvider"]);
            order.paymentProvider = provider.length > 0 ? provider : resolvedPaymentProvider;
            NSString *verificationStatus = PPOrderTrimmedString(orderDict[@"verificationStatus"]);
            order.verificationStatus = verificationStatus.length > 0
            ? PPOrderNormalizedStatusString(verificationStatus)
            : ([order isCashOnDelivery] ? @"not_applicable" : @"pending");
            order.items = [orderDict[@"items"] isKindOfClass:NSArray.class] ? orderDict[@"items"] : (items ?: @[]);
            NSString *resolvedShippingID = PPOrderTrimmedString(orderDict[@"shippingAddressId"]);
            order.shippingAddressId = resolvedShippingID.length > 0 ? resolvedShippingID : (shippingAddressID ?: @"");
            order.shippingAddressSnapshot = [orderDict[@"shippingAddressSnapshot"] isKindOfClass:NSDictionary.class] ? orderDict[@"shippingAddressSnapshot"] : shippingSnapshot.copy;

            NSNumber *createdAtMillis = [orderDict[@"createdAtMillis"] respondsToSelector:@selector(doubleValue)] ? orderDict[@"createdAtMillis"] : nil;
            NSDate *createdAt = createdAtMillis ? [NSDate dateWithTimeIntervalSince1970:(createdAtMillis.doubleValue / 1000.0)] : NSDate.date;
            NSNumber *updatedAtMillis = [orderDict[@"updatedAtMillis"] respondsToSelector:@selector(doubleValue)] ? orderDict[@"updatedAtMillis"] : nil;
            NSDate *updatedAt = updatedAtMillis ? [NSDate dateWithTimeIntervalSince1970:(updatedAtMillis.doubleValue / 1000.0)] : createdAt;
            order.createdAt = createdAt;
            order.updatedAt = updatedAt;

            PPORDERLog(@"Create pending order resolved | orderId=%@ | orderNumber=%@ | paymentMethod=%@ | paymentStatus=%@",
                       order.orderId ?: @"",
                       order.orderNumber ?: @"",
                       order.paymentMethodId ?: @"",
                       order.paymentStatus ?: @"");

            if (completion) completion(order, nil);
        }];
    }];
}

- (void)fetchOrCreatePendingOrderWithItems:(NSArray<NSDictionary *> *)items
                                     amount:(double)amount
                                    address:(PPAddressModel * _Nullable)address
                                  completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion
{
    [self fetchOrCreatePendingOrderWithItems:items
                                      amount:amount
                                     address:address
                             paymentMethodId:nil
                                   completion:completion];
}

- (void)fetchOrCreatePendingOrderWithItems:(NSArray<NSDictionary *> *)items
                                     amount:(double)amount
                                    address:(PPAddressModel * _Nullable)address
                            paymentMethodId:(NSString *)paymentMethodId
                                  completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion
{
    [self fetchOrCreatePendingOrderWithItems:items
                                      amount:amount
                                     address:address
                             paymentMethodId:paymentMethodId
                              idempotencyKey:nil
                                   completion:completion];
}

- (void)fetchOrCreatePendingOrderWithItems:(NSArray<NSDictionary *> *)items
                                     amount:(double)amount
                                    address:(PPAddressModel * _Nullable)address
                            paymentMethodId:(NSString *)paymentMethodId
                             idempotencyKey:(NSString *)idempotencyKey
                                  completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion
{
    NSString *userId = [FIRAuth auth].currentUser.uid ?: @"";
    if (userId.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PPOrder"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_register_required_subtitle")}];
        if (completion) completion(nil, error);
        return;
    }
    if (address.userID.length > 0 && ![address.userID isEqualToString:userId]) {
        NSError *ownershipError = [NSError errorWithDomain:@"PPOrder"
                                                      code:403
                                                  userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_address")}];
        if (completion) completion(nil, ownershipError);
        return;
    }
    NSMutableDictionary *shippingSnapshot = [PPOrderShippingSnapshotFromAddress(address, userId) mutableCopy];
    if (!shippingSnapshot) {
        NSError *addressError = [NSError errorWithDomain:@"PPOrder"
                                                    code:422
                                                userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_address")}];
        if (completion) completion(nil, addressError);
        return;
    }
    NSString *shippingAddressID = PPOrderAddressEffectiveID(address);
    NSString *resolvedPaymentMethodID = PPOrderNormalizedPaymentMethodKey(paymentMethodId, nil);

    PPORDERLog(@"Fetch or create pending order | items=%lu | amount=%.2f | addressId=%@ | paymentMethod=%@",
               (unsigned long)items.count,
               amount,
               shippingAddressID ?: @"",
               resolvedPaymentMethodID ?: @"");

    FIRFirestore *db = FIRFirestore.firestore;
    FIRCollectionReference *ordersRef = [db collectionWithPath:@"Orders"];
    FIRQuery *pendingQuery = [[ordersRef queryWhereField:@"userId" isEqualTo:userId]
                              queryWhereField:@"status" in:@[@"pending", @"failed", @"cancelled", @"abandoned"]];

    [pendingQuery getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            if (completion) completion(nil, error ?: [NSError errorWithDomain:@"PPOrder"
                                                                         code:500
                                                                     userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_generic_error")}]);
            return;
        }

        PPOrder *bestMatch = nil;
        NSTimeInterval newestTime = 0;
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        NSTimeInterval maxAge = 24 * 60 * 60; // Reuse orders for 24h

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PPOrder *candidate = [PPOrder orderFromSnapshot:doc];
            if (!candidate) continue;
            // Match cart irrespective of payment method
            if (!PPOrderMatchesCart(candidate, items, amount, shippingAddressID ?: @"")) continue;
            if (!PPOrderIsRecent(candidate, now, maxAge)) continue;

            NSTimeInterval createdTime = candidate.createdAt.timeIntervalSince1970;
            if (createdTime > newestTime) {
                newestTime = createdTime;
                bestMatch = candidate;
            }
        }

        if (bestMatch) {
            NSString *actualMethod = PPOrderNormalizedPaymentMethodKey(bestMatch.paymentMethodId, bestMatch.paymentProvider);
            BOOL needsMethodUpdate = ![resolvedPaymentMethodID isEqualToString:actualMethod];
            BOOL needsStatusUpdate = ![bestMatch.rawStatus isEqualToString:@"pending"];

            if (!needsMethodUpdate && !needsStatusUpdate) {
                PPORDERLog(@"Reusing pending order directly | orderId=%@ | paymentMethod=%@",
                           bestMatch.orderId ?: @"",
                           bestMatch.paymentMethodId ?: @"");
                if (completion) completion(bestMatch, nil);
                return;
            }

            PPORDERLog(@"Preparing existing order for reuse/retry | orderId=%@ | oldStatus=%@ | paymentMethod=%@",
                       bestMatch.orderId ?: @"",
                       bestMatch.rawStatus ?: @"",
                       resolvedPaymentMethodID ?: @"");

            FIRFunctions *functions = PPOrderFunctionsClient();
            NSDictionary *payload = @{
                @"orderId": bestMatch.orderId ?: @"",
                @"shippingAddressId": shippingAddressID ?: @"",
                @"paymentMethodId": resolvedPaymentMethodID ?: @"",
                @"shippingAddressSnapshot": shippingSnapshot.copy ?: @{}
            };

            [[functions HTTPSCallableWithName:@"prepareOrderForRetry"]
             callWithObject:payload
             completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable callableError) {
                if (callableError || ![result.data isKindOfClass:NSDictionary.class]) {
                    // Fallback path: if callable is unavailable, create a new pending order.
                    PPORDERLog(@"prepareOrderForRetry unavailable, creating new pending order | orderId=%@ | error=%@",
                               bestMatch.orderId ?: @"",
                               callableError.localizedDescription ?: @"Invalid response");
                    [self createPendingOrderWithItems:items amount:amount address:address paymentMethodId:resolvedPaymentMethodID idempotencyKey:idempotencyKey completion:completion];
                    return;
                }

                bestMatch.status = PPOrderStatusPending;
                bestMatch.rawStatus = @"pending";
                bestMatch.paymentMethodId = resolvedPaymentMethodID;
                if ([resolvedPaymentMethodID isEqualToString:@"cash"]) {
                    bestMatch.paymentStatus = @"pending_collection";
                    bestMatch.paymentProvider = @"CASH";
                    bestMatch.verificationStatus = @"not_applicable";
                } else {
                    bestMatch.paymentStatus = @"pending";
                    bestMatch.paymentProvider = @"QIB";
                    bestMatch.verificationStatus = @"pending";
                }
                bestMatch.failureReason = nil;
                bestMatch.transactionId = nil;
                bestMatch.paymentResponse = nil;
                bestMatch.shippingAddressId = shippingAddressID ?: @"";
                bestMatch.shippingAddressSnapshot = shippingSnapshot.copy;
                bestMatch.updatedAt = NSDate.date;
                PPORDERLog(@"Order updated via prepareOrderForRetry | orderId=%@ | paymentMethod=%@",
                           bestMatch.orderId ?: @"",
                           bestMatch.paymentMethodId ?: @"");
                if (completion) completion(bestMatch, nil);
            }];
            return;
        }

        // ── No match found: Create new order ──────────
        [self createPendingOrderWithItems:items amount:amount address:address paymentMethodId:resolvedPaymentMethodID idempotencyKey:idempotencyKey completion:completion];
    }];
}

- (void)validateInventoryForItems:(NSArray<NSDictionary *> *)items
                       completion:(void (^)(BOOL inStock,
                                            NSArray<NSDictionary *> *issues,
                                            NSError * _Nullable error))completion
{
    NSMutableDictionary<NSString *, NSMutableDictionary *> *aggregated = PPAggregateRequestedItems(items);
    if (aggregated.count == 0) {
        NSError *error = [NSError errorWithDomain:PPOrderInventoryErrorDomain
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_items_unavailable_fallback")}];
        if (completion) completion(NO, @[], error);
        return;
    }

    FIRFirestore *db = FIRFirestore.firestore;
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t syncQueue = dispatch_queue_create("com.purepets.order.inventory.validation", DISPATCH_QUEUE_SERIAL);

    NSMutableArray<NSDictionary *> *issues = [NSMutableArray array];
    __block NSError *firstError = nil;

    for (NSString *itemID in aggregated.allKeys) {
        NSMutableDictionary *entry = aggregated[itemID];
        NSInteger requestedQty = [entry[@"requestedQty"] integerValue];
        NSString *name = entry[@"name"] ?: @"";
        if (requestedQty <= 0) continue;

        dispatch_group_enter(group);
        FIRDocumentReference *ref = [[db collectionWithPath:@"petAccessories"] documentWithPath:itemID];
        [ref getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            dispatch_async(syncQueue, ^{
                if (error) {
                    if (!firstError) firstError = error;
                    dispatch_group_leave(group);
                    return;
                }

                NSInteger availableQty = 0;
                if (snapshot.exists) {
                    id rawQty = snapshot.data[@"quantity"];
                    if ([rawQty respondsToSelector:@selector(integerValue)]) {
                        availableQty = MAX(0, [rawQty integerValue]);
                    }
                }

                if (!snapshot.exists || availableQty < requestedQty) {
                    [issues addObject:@{
                        @"itemID": itemID ?: @"",
                        @"name": name ?: @"",
                        @"requestedQty": @(requestedQty),
                        @"availableQty": @(availableQty)
                    }];
                }
                dispatch_group_leave(group);
            });
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (issues.count > 0) {
            if (completion) completion(NO, issues.copy, nil);
            return;
        }

        if (firstError) {
            NSError *wrapped = [NSError errorWithDomain:PPOrderInventoryErrorDomain
                                                   code:101
                                               userInfo:@{
                NSLocalizedDescriptionKey: kLang(@"checkout_generic_error"),
                NSUnderlyingErrorKey: firstError
            }];
            if (completion) completion(NO, @[], wrapped);
            return;
        }

        if (completion) completion(YES, @[], nil);
    });
}

- (PPOrderEligibilityDecision *)eligibilityForAction:(PPOrderCustomerActionType)actionType
                                               order:(PPOrder *)order
                                            requests:(NSArray<PPOrderSupportRequest *> *)requests
                                       referenceDate:(NSDate *)referenceDate
{
    PPOrderEligibilityDecision *decision = [PPOrderEligibilityDecision new];
    decision.actionType = actionType;
    decision.actionTitle = [PPOrderManager displayTitleForActionType:actionType];

    if (!order) {
        decision.eligible = NO;
        decision.message = kLang(@"order_support_unavailable_no_order");
        return decision;
    }

    NSString *statusKey = PPOrderNormalizedStatusString(order.rawStatus.length > 0 ? order.rawStatus : @"pending");
    BOOL hasCapturedPayment = PPOrderHasCapturedPayment(order);
    decision.statusKey = statusKey;
    NSDate *now = referenceDate ?: [NSDate date];
    NSMutableArray<NSDate *> *paymentCandidates = [NSMutableArray array];
    if (order.paymentCollectedAt) [paymentCandidates addObject:order.paymentCollectedAt];
    if (order.paidAt) [paymentCandidates addObject:order.paidAt];
    if (order.statusUpdatedAt) [paymentCandidates addObject:order.statusUpdatedAt];
    if (order.updatedAt) [paymentCandidates addObject:order.updatedAt];
    if (order.createdAt) [paymentCandidates addObject:order.createdAt];

    NSMutableArray<NSDate *> *deliveryCandidates = [NSMutableArray array];
    if (order.deliveredAt) [deliveryCandidates addObject:order.deliveredAt];
    if (order.statusUpdatedAt) [deliveryCandidates addObject:order.statusUpdatedAt];
    if (order.updatedAt) [deliveryCandidates addObject:order.updatedAt];
    if (order.createdAt) [deliveryCandidates addObject:order.createdAt];

    NSDate *paymentDate = PPOrderSupportBestDate(paymentCandidates.copy);
    NSDate *deliveryDate = PPOrderSupportBestDate(deliveryCandidates.copy);
    NSInteger daysSincePayment = PPOrderSupportElapsedDaysSince(paymentDate, now);
    NSInteger daysSinceDelivery = PPOrderSupportElapsedDaysSince(deliveryDate, now);
    NSString *requestType = PPOrderRequestTypeForAction(actionType);

    if (PPOrderSupportHasOpenRequestForType(requests, requestType)) {
        decision.eligible = NO;
        decision.message = [NSString stringWithFormat:kLang(@"order_action_existing_request_message"), decision.actionTitle];
        return decision;
    }

    switch (actionType) {
        case PPOrderCustomerActionTypeTrack:
            decision.eligible = YES;
            decision.message = kLang(@"order_action_track_hint");
            break;

        case PPOrderCustomerActionTypeCancel:
            if (PPOrderStatusIsCancelledLike(statusKey) || PPOrderStatusIsFailureLike(statusKey)) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_cancel_unavailable_closed");
            } else if ([statusKey isEqualToString:@"pending"] || PPOrderStatusIsPackingLike(statusKey)) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_cancel_unavailable_preparing");
            } else if (PPOrderStatusIsShippedLike(statusKey) || PPOrderStatusIsDeliveredLike(statusKey)) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_cancel_unavailable_fulfillment");
            } else {
                decision.eligible = YES;
                decision.message = kLang(@"order_action_cancel_hint");
            }
            break;

        case PPOrderCustomerActionTypeReturn:
            if (!PPOrderStatusIsDeliveredLike(statusKey)) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_return_unavailable_not_delivered");
            } else if (daysSinceDelivery > PPOrderReturnWindowDays) {
                decision.eligible = NO;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_return_unavailable_window"), (long)PPOrderReturnWindowDays];
            } else {
                decision.eligible = YES;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_return_hint"), (long)PPOrderReturnWindowDays];
            }
            break;

        case PPOrderCustomerActionTypeRefund:
            if (!(hasCapturedPayment || PPOrderStatusIsCancelledLike(statusKey))) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_refund_unavailable_unpaid");
            } else if (PPOrderStatusIsShippedLike(statusKey)) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_refund_unavailable_after_shipment");
            } else if (daysSincePayment > PPOrderRefundWindowDays) {
                decision.eligible = NO;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_refund_unavailable_window"), (long)PPOrderRefundWindowDays];
            } else {
                decision.eligible = YES;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_refund_hint"), (long)PPOrderRefundWindowDays];
            }
            break;

        case PPOrderCustomerActionTypeReplacement:
            if (!PPOrderStatusIsDeliveredLike(statusKey)) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_replacement_unavailable_not_delivered");
            } else if (daysSinceDelivery > PPOrderReplacementWindowDays) {
                decision.eligible = NO;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_replacement_unavailable_window"), (long)PPOrderReplacementWindowDays];
            } else {
                decision.eligible = YES;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_replacement_hint"), (long)PPOrderReplacementWindowDays];
            }
            break;

        case PPOrderCustomerActionTypeComplaint:
            if (!(order.createdAt || PPOrderStatusIsFailureLike(statusKey) || PPOrderStatusIsCancelledLike(statusKey) || hasCapturedPayment || [order.paymentStatus isEqualToString:@"pending_collection"])) {
                decision.eligible = NO;
                decision.message = kLang(@"order_action_complaint_unavailable_not_started");
            } else if (daysSincePayment > PPOrderComplaintWindowDays) {
                decision.eligible = NO;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_complaint_unavailable_window"), (long)PPOrderComplaintWindowDays];
            } else {
                decision.eligible = YES;
                decision.message = [NSString stringWithFormat:kLang(@"order_action_complaint_hint"), (long)PPOrderComplaintWindowDays];
            }
            break;

        case PPOrderCustomerActionTypeSupport:
            decision.eligible = YES;
            decision.message = kLang(@"order_action_support_hint");
            break;
    }

    return decision;
}

- (NSArray<PPOrderEligibilityDecision *> *)eligibilityDecisionsForOrder:(PPOrder *)order
                                                               requests:(NSArray<PPOrderSupportRequest *> *)requests
                                                          referenceDate:(NSDate *)referenceDate
{
    NSMutableArray<PPOrderEligibilityDecision *> *decisions = [NSMutableArray array];
    NSArray<NSNumber *> *actions = @[
        @(PPOrderCustomerActionTypeTrack),
        @(PPOrderCustomerActionTypeCancel),
        @(PPOrderCustomerActionTypeReturn),
        @(PPOrderCustomerActionTypeRefund),
        @(PPOrderCustomerActionTypeReplacement),
        @(PPOrderCustomerActionTypeComplaint),
        @(PPOrderCustomerActionTypeSupport)
    ];
    for (NSNumber *actionNumber in actions) {
        [decisions addObject:[self eligibilityForAction:actionNumber.integerValue
                                                  order:order
                                               requests:requests
                                          referenceDate:referenceDate ?: [NSDate date]]];
    }
    return decisions.copy;
}

- (NSArray<NSDictionary *> *)reasonOptionsForAction:(PPOrderCustomerActionType)actionType
{
    switch (actionType) {
        case PPOrderCustomerActionTypeCancel:
            return @[
                PPOrderReasonOption(@"ordered_by_mistake", kLang(@"order_reason_cancel_mistake_title"), kLang(@"order_reason_cancel_mistake_subtitle"), NO),
                PPOrderReasonOption(@"changed_mind", kLang(@"order_reason_changed_mind_title"), kLang(@"order_reason_changed_mind_subtitle"), NO),
                PPOrderReasonOption(@"wrong_address", kLang(@"order_reason_wrong_address_title"), kLang(@"order_reason_wrong_address_subtitle"), NO),
                PPOrderReasonOption(@"found_alternative", kLang(@"order_reason_found_alternative_title"), kLang(@"order_reason_found_alternative_subtitle"), NO)
            ];
        case PPOrderCustomerActionTypeReturn:
            return @[
                PPOrderReasonOption(@"item_not_as_described", kLang(@"order_reason_not_as_described_title"), kLang(@"order_reason_not_as_described_subtitle"), YES),
                PPOrderReasonOption(@"changed_mind", kLang(@"order_reason_changed_mind_title"), kLang(@"order_reason_changed_mind_subtitle"), YES),
                PPOrderReasonOption(@"quality_issue", kLang(@"order_reason_quality_issue_title"), kLang(@"order_reason_quality_issue_subtitle"), YES),
                PPOrderReasonOption(@"arrived_damaged", kLang(@"order_reason_arrived_damaged_title"), kLang(@"order_reason_arrived_damaged_subtitle"), YES)
            ];
        case PPOrderCustomerActionTypeRefund:
            return @[
                PPOrderReasonOption(@"duplicate_payment", kLang(@"order_reason_duplicate_payment_title"), kLang(@"order_reason_duplicate_payment_subtitle"), NO),
                PPOrderReasonOption(@"payment_issue", kLang(@"order_reason_payment_issue_title"), kLang(@"order_reason_payment_issue_subtitle"), NO),
                PPOrderReasonOption(@"cancelled_but_charged", kLang(@"order_reason_cancelled_but_charged_title"), kLang(@"order_reason_cancelled_but_charged_subtitle"), NO),
                PPOrderReasonOption(@"missing_item", kLang(@"order_reason_missing_item_title"), kLang(@"order_reason_missing_item_subtitle"), YES)
            ];
        case PPOrderCustomerActionTypeReplacement:
            return @[
                PPOrderReasonOption(@"damaged_item", kLang(@"order_reason_damaged_item_title"), kLang(@"order_reason_damaged_item_subtitle"), YES),
                PPOrderReasonOption(@"wrong_item", kLang(@"order_reason_wrong_item_title"), kLang(@"order_reason_wrong_item_subtitle"), YES),
                PPOrderReasonOption(@"defective_item", kLang(@"order_reason_defective_item_title"), kLang(@"order_reason_defective_item_subtitle"), YES)
            ];
        case PPOrderCustomerActionTypeComplaint:
            return @[
                PPOrderReasonOption(@"damaged_item", kLang(@"order_reason_damaged_item_title"), kLang(@"order_reason_damaged_item_subtitle"), YES),
                PPOrderReasonOption(@"wrong_item", kLang(@"order_reason_wrong_item_title"), kLang(@"order_reason_wrong_item_subtitle"), YES),
                PPOrderReasonOption(@"missing_item", kLang(@"order_reason_missing_item_title"), kLang(@"order_reason_missing_item_subtitle"), YES),
                PPOrderReasonOption(@"late_delivery", kLang(@"order_reason_late_delivery_title"), kLang(@"order_reason_late_delivery_subtitle"), NO),
                PPOrderReasonOption(@"duplicate_payment", kLang(@"order_reason_duplicate_payment_title"), kLang(@"order_reason_duplicate_payment_subtitle"), NO),
                PPOrderReasonOption(@"payment_issue", kLang(@"order_reason_payment_issue_title"), kLang(@"order_reason_payment_issue_subtitle"), NO)
            ];
        case PPOrderCustomerActionTypeSupport:
            return @[
                PPOrderReasonOption(@"order_question", kLang(@"order_reason_order_question_title"), kLang(@"order_reason_order_question_subtitle"), NO),
                PPOrderReasonOption(@"delivery_update", kLang(@"order_reason_delivery_update_title"), kLang(@"order_reason_delivery_update_subtitle"), NO),
                PPOrderReasonOption(@"billing_question", kLang(@"order_reason_billing_question_title"), kLang(@"order_reason_billing_question_subtitle"), NO),
                PPOrderReasonOption(@"other", kLang(@"order_reason_other_title"), kLang(@"order_reason_other_subtitle"), NO)
            ];
        case PPOrderCustomerActionTypeTrack:
            return @[];
    }
    return @[];
}

- (FIRCollectionReference *)pp_requestsCollectionForOrderID:(NSString *)orderID
{
    return [[[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID] collectionWithPath:@"requests"];
}

- (FIRCollectionReference *)pp_eventsCollectionForOrderID:(NSString *)orderID
{
    return [[[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID] collectionWithPath:@"events"];
}

- (NSArray<PPOrderTimelineEvent *> *)pp_fallbackTimelineForOrder:(PPOrder *)order
{
    NSMutableArray<PPOrderTimelineEvent *> *events = [NSMutableArray array];

    if (order.createdAt) {
        PPOrderTimelineEvent *created = [PPOrderTimelineEvent new];
        created.eventId = @"local_created";
        created.type = @"order_created";
        created.status = @"pending";
        created.actorType = @"system";
        created.summary = kLang(@"order_timeline_created_summary");
        created.createdAt = order.createdAt;
        [events addObject:created];
    }

    if (order.paidAt || order.paymentCollectedAt || [order.paymentStatus isEqualToString:@"paid"] || (!order.isCashOnDelivery && PPOrderStatusIsPaidLike(PPOrderNormalizedStatusString(order.rawStatus)))) {
        PPOrderTimelineEvent *paid = [PPOrderTimelineEvent new];
        paid.eventId = [order isCashOnDelivery] ? @"local_payment_collected" : @"local_paid";
        paid.type = [order isCashOnDelivery] ? @"payment_collected" : @"payment_verified";
        paid.status = @"paid";
        paid.actorType = @"system";
        paid.summary = [order isCashOnDelivery] ? kLang(@"order_timeline_payment_collected_title") : kLang(@"order_timeline_paid_summary");
        paid.createdAt = order.paymentCollectedAt ?: order.paidAt ?: order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt ?: [NSDate date];
        [events addObject:paid];
    }

    if (order.processedAt || PPOrderStatusIsPackingLike(PPOrderNormalizedStatusString(order.rawStatus))) {
        PPOrderTimelineEvent *processing = [PPOrderTimelineEvent new];
        processing.eventId = @"local_processing";
        processing.type = @"fulfillment_processing";
        processing.status = @"processing";
        processing.actorType = @"system";
        processing.summary = kLang(@"order_timeline_processing_summary");
        processing.createdAt = order.processedAt ?: order.statusUpdatedAt ?: order.updatedAt ?: [NSDate date];
        [events addObject:processing];
    }

    if (order.shippedAt || PPOrderStatusIsShippedLike(PPOrderNormalizedStatusString(order.rawStatus))) {
        PPOrderTimelineEvent *shipped = [PPOrderTimelineEvent new];
        shipped.eventId = @"local_shipped";
        shipped.type = @"fulfillment_shipped";
        shipped.status = @"shipped";
        shipped.actorType = @"system";
        shipped.summary = kLang(@"order_timeline_shipped_summary");
        shipped.createdAt = order.shippedAt ?: order.statusUpdatedAt ?: order.updatedAt ?: [NSDate date];
        [events addObject:shipped];
    }

    if (order.deliveredAt || PPOrderStatusIsDeliveredLike(PPOrderNormalizedStatusString(order.rawStatus))) {
        PPOrderTimelineEvent *delivered = [PPOrderTimelineEvent new];
        delivered.eventId = @"local_delivered";
        delivered.type = @"fulfillment_delivered";
        delivered.status = @"delivered";
        delivered.actorType = @"system";
        delivered.summary = kLang(@"order_timeline_delivered_summary");
        delivered.createdAt = order.deliveredAt ?: order.statusUpdatedAt ?: order.updatedAt ?: [NSDate date];
        [events addObject:delivered];
    }

    if (order.cancelledAt || PPOrderStatusIsCancelledLike(PPOrderNormalizedStatusString(order.rawStatus))) {
        PPOrderTimelineEvent *cancelled = [PPOrderTimelineEvent new];
        cancelled.eventId = @"local_cancelled";
        cancelled.type = @"order_cancelled";
        cancelled.status = @"cancelled";
        cancelled.actorType = @"customer";
        cancelled.summary = kLang(@"order_timeline_cancelled_summary");
        cancelled.createdAt = order.cancelledAt ?: order.statusUpdatedAt ?: order.updatedAt ?: [NSDate date];
        [events addObject:cancelled];
    }

    return [events sortedArrayUsingComparator:^NSComparisonResult(PPOrderTimelineEvent * _Nonnull left, PPOrderTimelineEvent * _Nonnull right) {
        return [left.createdAt compare:right.createdAt];
    }];
}

- (NSArray<PPOrderTimelineEvent *> *)pp_fallbackRequestEventsForRequest:(PPOrderSupportRequest *)request
{
    NSMutableArray<PPOrderTimelineEvent *> *events = [NSMutableArray array];

    PPOrderTimelineEvent *submitted = [PPOrderTimelineEvent new];
    submitted.eventId = @"local_request_submitted";
    submitted.type = @"request_submitted";
    submitted.status = PPOrderRequestStatusPendingReview;
    submitted.actorType = @"customer";
    submitted.summary = kLang(@"order_request_timeline_submitted");
    submitted.createdAt = request.submittedAt ?: request.createdAt ?: [NSDate date];
    [events addObject:submitted];

    if (request.status.length > 0 &&
        ![PPOrderNormalizedStatusString(request.status) isEqualToString:PPOrderRequestStatusPendingReview]) {
        PPOrderTimelineEvent *state = [PPOrderTimelineEvent new];
        state.eventId = @"local_request_state";
        state.type = @"request_status_updated";
        state.status = request.status;
        state.actorType = @"system";
        state.summary = [PPOrderManager displayTitleForRequestStatus:request.status];
        state.createdAt = request.updatedAt ?: request.createdAt ?: [NSDate date];
        [events addObject:state];
    }

    return [events sortedArrayUsingComparator:^NSComparisonResult(PPOrderTimelineEvent * _Nonnull left, PPOrderTimelineEvent * _Nonnull right) {
        return [left.createdAt compare:right.createdAt];
    }];
}

- (id<FIRListenerRegistration>)listenToSupportRequestsForOrderID:(NSString *)orderID
                                                          update:(void (^)(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable error))update
{
    if (orderID.length == 0) return nil;
    FIRQuery *query = [[self pp_requestsCollectionForOrderID:orderID] queryOrderedByField:@"createdAt" descending:YES];
    return [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (update) update(@[], error);
            return;
        }
        NSMutableArray<PPOrderSupportRequest *> *requests = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [requests addObject:[PPOrderSupportRequest requestFromSnapshot:doc]];
        }
        if (update) update(requests.copy, nil);
    }];
}

- (void)fetchSupportRequestsForOrderID:(NSString *)orderID
                            completion:(void (^)(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable error))completion
{
    if (orderID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    FIRQuery *query = [[self pp_requestsCollectionForOrderID:orderID] queryOrderedByField:@"createdAt" descending:YES];
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray<PPOrderSupportRequest *> *requests = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
            [requests addObject:[PPOrderSupportRequest requestFromSnapshot:doc]];
        }
        if (completion) completion(requests.copy, error);
    }];
}

- (id<FIRListenerRegistration>)listenToTimelineEventsForOrder:(PPOrder *)order
                                                       update:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))update
{
    if (!order.orderId.length) return nil;
    FIRQuery *query = [[self pp_eventsCollectionForOrderID:order.orderId] queryOrderedByField:@"createdAt" descending:NO];
    return [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (update) update([self pp_fallbackTimelineForOrder:order], error);
            return;
        }
        NSMutableArray<PPOrderTimelineEvent *> *events = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [events addObject:[PPOrderTimelineEvent eventFromSnapshot:doc]];
        }
        if (events.count == 0) {
            events = [[self pp_fallbackTimelineForOrder:order] mutableCopy];
        }
        if (update) update(events.copy, nil);
    }];
}

- (void)fetchTimelineEventsForOrder:(PPOrder *)order
                         completion:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))completion
{
    if (!order.orderId.length) {
        if (completion) completion([self pp_fallbackTimelineForOrder:order], nil);
        return;
    }
    FIRQuery *query = [[self pp_eventsCollectionForOrderID:order.orderId] queryOrderedByField:@"createdAt" descending:NO];
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray<PPOrderTimelineEvent *> *events = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
            [events addObject:[PPOrderTimelineEvent eventFromSnapshot:doc]];
        }
        if (events.count == 0) {
            events = [[self pp_fallbackTimelineForOrder:order] mutableCopy];
        }
        if (completion) completion(events.copy, error);
    }];
}

- (id<FIRListenerRegistration>)listenToRequestEventsForOrderID:(NSString *)orderID
                                                      requestID:(NSString *)requestID
                                                         update:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))update
{
    if (orderID.length == 0 || requestID.length == 0) return nil;
    FIRQuery *query = [[[[self pp_requestsCollectionForOrderID:orderID] documentWithPath:requestID] collectionWithPath:@"events"] queryOrderedByField:@"createdAt" descending:NO];
    return [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (update) update(@[], error);
            return;
        }
        NSMutableArray<PPOrderTimelineEvent *> *events = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
            [events addObject:[PPOrderTimelineEvent eventFromSnapshot:doc]];
        }
        if (update) update(events.copy, nil);
    }];
}

- (void)fetchRequestEventsForOrderID:(NSString *)orderID
                            requestID:(NSString *)requestID
                           completion:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))completion
{
    if (orderID.length == 0 || requestID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    FIRQuery *query = [[[[self pp_requestsCollectionForOrderID:orderID] documentWithPath:requestID] collectionWithPath:@"events"] queryOrderedByField:@"createdAt" descending:NO];
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray<PPOrderTimelineEvent *> *events = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
            [events addObject:[PPOrderTimelineEvent eventFromSnapshot:doc]];
        }
        if (completion) completion(events.copy, error);
    }];
}

- (void)pp_callCreateOrderSupportRequestWithPayload:(NSDictionary *)payload
                                             draft:(PPOrderSupportDraft *)draft
                                             order:(PPOrder *)order
                                       requestType:(NSString *)requestType
                            forceCredentialRefresh:(BOOL)forceCredentialRefresh
                                      didRetryAuth:(BOOL)didRetryAuth
                                        completion:(void (^)(PPOrderSupportRequest * _Nullable request, BOOL deduplicated, NSError * _Nullable error))completion
{
    void (^callCreateRequest)(void) = ^{
        [[PPOrderDefaultFunctionsClient() HTTPSCallableWithName:@"createOrderSupportRequest"]
         callWithObject:payload ?: @{}
         completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
            if (error) {
                if (!didRetryAuth && [PPFirebaseSessionBridge isAuthOrAppCheckError:error]) {
                    [self pp_callCreateOrderSupportRequestWithPayload:payload
                                                                draft:draft
                                                                order:order
                                                          requestType:requestType
                                               forceCredentialRefresh:YES
                                                         didRetryAuth:YES
                                                           completion:completion];
                    return;
                }
                if (completion) {
                    completion(nil, NO, PPOrderWrappedCallableError(error) ?: error);
                }
                return;
            }

            NSDictionary *data = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            NSString *requestID = PPOrderSupportSafeString(data[@"requestId"]);
            BOOL deduplicated = [data[@"deduplicated"] boolValue];

            PPOrderSupportRequest *request = nil;
            if (requestID.length > 0) {
                request = [PPOrderSupportRequest requestFromDictionary:@{
                    @"requestId": requestID,
                    @"orderId": order.orderId ?: @"",
                    @"userId": [FIRAuth auth].currentUser.uid ?: @"",
                    @"type": requestType ?: @"support",
                    @"reasonCode": draft.reasonCode ?: @"other",
                    @"reasonTitle": draft.reasonTitle ?: @"",
                    @"issueCategory": draft.issueCategory ?: @"",
                    @"subject": draft.subject ?: @"",
                    @"notes": draft.notes ?: @"",
                    @"itemIDs": draft.selectedItemIDs ?: @[],
                    @"attachments": [[draft.attachments valueForKey:@"dictionaryValue"] isKindOfClass:NSArray.class] ? [draft.attachments valueForKey:@"dictionaryValue"] : @[],
                    @"status": data[@"status"] ?: PPOrderRequestStatusPendingReview,
                    @"finalResolution": data[@"finalResolution"] ?: PPOrderRequestStatusPendingReview,
                    @"createdAt": [NSDate date],
                    @"updatedAt": [NSDate date]
                } documentID:requestID];
            }

            if (completion) completion(request, deduplicated, nil);
        }];
    };

    if (!forceCredentialRefresh) {
        callCreateRequest();
        return;
    }

    [PPFirebaseSessionBridge ensureFreshAuthSessionForcingRefresh:YES completion:^(NSError * _Nullable authError) {
        if (authError) {
            if (completion) {
                completion(nil, NO, [PPFirebaseSessionBridge publicErrorForError:authError
                                                                     fallbackKey:@"pp_order_support_submit_failed"]);
            }
            return;
        }

        callCreateRequest();
    }];
}

- (void)submitSupportDraft:(PPOrderSupportDraft *)draft
                  forOrder:(PPOrder *)order
                completion:(void (^)(PPOrderSupportRequest * _Nullable request, BOOL deduplicated, NSError * _Nullable error))completion
{
    if (!order.orderId.length) {
        NSError *error = [NSError errorWithDomain:PPOrderSupportErrorDomain
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"order_missing_id")}];
        if (completion) completion(nil, NO, error);
        return;
    }

    NSString *requestType = PPOrderRequestTypeForAction(draft.actionType);
    NSDictionary *payload = @{
        @"orderId": order.orderId ?: @"",
        @"requestType": requestType ?: @"support",
        @"reasonCode": draft.reasonCode ?: @"other",
        @"reasonTitle": draft.reasonTitle ?: @"",
        @"issueCategory": draft.issueCategory ?: @"",
        @"subject": draft.subject ?: @"",
        @"notes": draft.notes ?: @"",
        @"itemIDs": draft.selectedItemIDs ?: @[],
        @"attachments": [[draft.attachments valueForKey:@"dictionaryValue"] isKindOfClass:NSArray.class] ? [draft.attachments valueForKey:@"dictionaryValue"] : @[]
    };

    [self pp_callCreateOrderSupportRequestWithPayload:payload
                                               draft:draft
                                               order:order
                                         requestType:requestType
                              forceCredentialRefresh:NO
                                        didRetryAuth:NO
                                          completion:completion];
}

- (void)uploadEvidenceImages:(NSArray<UIImage *> *)images
                    forOrder:(PPOrder *)order
             draftIdentifier:(NSString *)draftIdentifier
                    progress:(void (^)(double progress))progress
                  completion:(void (^)(NSArray<PPOrderSupportAttachment *> *attachments, NSError * _Nullable error))completion
{
    if (images.count == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    if (images.count > PPOrderSupportMaxAttachmentCount) {
        NSError *error = [NSError errorWithDomain:PPOrderSupportErrorDomain
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"order_support_too_many_photos")}];
        if (completion) completion(@[], error);
        return;
    }

    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length == 0) {
        NSError *error = [NSError errorWithDomain:PPOrderSupportErrorDomain
                                             code:402
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_register_required_subtitle")}];
        if (completion) completion(@[], error);
        return;
    }

    NSString *folderID = draftIdentifier.length > 0 ? draftIdentifier : NSUUID.UUID.UUIDString;
    FIRStorageReference *rootRef = [FIRStorage storage].reference;
    NSMutableArray<PPOrderSupportAttachment *> *attachments = [NSMutableArray array];

    __block NSInteger currentIndex = 0;
    __weak typeof(self) weakSelf = self;
    __block void (^uploadNext)(void) = ^{
        if (currentIndex >= (NSInteger)images.count) {
            if (completion) completion(attachments.copy, nil);
            return;
        }

        UIImage *image = images[currentIndex];
        NSData *jpeg = PPOrderCompressedJPEGData(image, PPOrderSupportAttachmentMaxKB);
        if (!jpeg) {
            NSError *error = [NSError errorWithDomain:PPOrderSupportErrorDomain
                                                 code:403
                                             userInfo:@{NSLocalizedDescriptionKey: kLang(@"order_support_upload_failed")}];
            if (completion) completion(@[], error);
            return;
        }

        NSString *fileName = [NSString stringWithFormat:@"%@.jpg", NSUUID.UUID.UUIDString.lowercaseString];
        NSString *storagePath = [NSString stringWithFormat:@"orderSupport/%@/%@/%@/%@", uid, order.orderId ?: @"unknown_order", folderID, fileName];
        FIRStorageReference *ref = [rootRef child:storagePath];
        FIRStorageMetadata *metadata = [FIRStorageMetadata new];
        metadata.contentType = @"image/jpeg";

        FIRStorageUploadTask *task = [ref putData:jpeg metadata:metadata completion:^(FIRStorageMetadata * _Nullable __unused meta, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(@[], error);
                return;
            }

            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable urlError) {
                if (urlError || !URL) {
                    NSError *wrapped = urlError ?: [NSError errorWithDomain:PPOrderSupportErrorDomain
                                                                       code:404
                                                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"order_support_upload_failed")}];
                    if (completion) completion(@[], wrapped);
                    return;
                }

                PPOrderSupportAttachment *attachment = [PPOrderSupportAttachment new];
                attachment.attachmentURL = URL.absoluteString ?: @"";
                attachment.storagePath = storagePath ?: @"";
                attachment.mimeType = @"image/jpeg";
                attachment.fileName = fileName ?: @"evidence.jpg";
                attachment.sizeBytes = jpeg.length;
                [attachments addObject:attachment];

                currentIndex += 1;
                if (progress) {
                    progress((double)currentIndex / (double)MAX(1, images.count));
                }
                uploadNext();
            }];
        }];

        [task observeStatus:FIRStorageTaskStatusProgress handler:^(__unused FIRStorageTaskSnapshot *snapshot) {
            if (!progress) return;
            double base = (double)currentIndex / (double)MAX(1, images.count);
            double partial = snapshot.progress.totalUnitCount > 0
                ? ((double)snapshot.progress.completedUnitCount / (double)snapshot.progress.totalUnitCount) / (double)MAX(1, images.count)
                : 0.0;
            progress(MIN(0.99, base + partial));
        }];
        (void)weakSelf;
    };
    uploadNext();
}

#pragma mark - Fulfillment (Phase 15 — read-only, customer-side)

- (void)fetchFulfillmentOrdersWithIDs:(NSArray<NSString *> *)fulfillmentIDs
                           completion:(void (^)(NSArray<PPFulfillmentOrder *> *orders))completion
{
    if (fulfillmentIDs.count == 0) {
        if (completion) completion(@[]);
        return;
    }
    FIRFirestore *db = [FIRFirestore firestore];
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<PPFulfillmentOrder *> *results = [NSMutableArray array];

    for (NSString *fid in fulfillmentIDs) {
        dispatch_group_enter(group);
        [[[db collectionWithPath:@"FulfillmentOrders"] documentWithPath:fid]
         getDocumentWithCompletion:^(FIRDocumentSnapshot *snap, NSError *error) {
            if (snap.exists && [snap.data isKindOfClass:NSDictionary.class]) {
                PPFulfillmentOrder *fo = [PPFulfillmentOrder fromDictionary:snap.data fulfillmentID:snap.documentID];
                [results addObject:fo];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion([results copy]);
    });
}

- (id<FIRListenerRegistration>)observeFulfillmentEventsForFulfillmentID:(NSString *)fulfillmentID
                                                               onChange:(void (^)(NSArray<NSDictionary *> *events))onChange
{
    if (!onChange || fulfillmentID.length == 0) return nil;
    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *q = [[[[db collectionWithPath:@"FulfillmentOrders"] documentWithPath:fulfillmentID]
                    collectionWithPath:@"events"] queryOrderedByField:@"createdAt" descending:YES];
    q = [q queryLimitedTo:30];
    return [q addSnapshotListener:^(FIRQuerySnapshot *snap, NSError *error) {
        if (error || !onChange) return;
        NSMutableArray<NSDictionary *> *events = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snap.documents) {
            NSMutableDictionary *entry = [[doc data] isKindOfClass:NSDictionary.class] ? [[doc data] mutableCopy] : [NSMutableDictionary dictionary];
            entry[@"eventId"] = doc.documentID;
            [events addObject:[entry copy]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ onChange([events copy]); });
    }];
}

@end
