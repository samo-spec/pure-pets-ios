//
//  PPOrder.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/02/2026.
//


#import "PPOrder.h"
#import "CountryModel.h"

static BOOL PPOrderStatusContainsToken(NSString *status, NSString *token);
static NSDate *PPOrderDateFromValue(id value, NSDate *fallback);

static NSString *PPOrderTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPOrderUppercaseAlphaNumericString(id value)
{
    NSString *trimmed = [[PPOrderTrimmedString(value) uppercaseString] copy];
    if (trimmed.length == 0) return @"";

    NSMutableString *result = [NSMutableString stringWithCapacity:trimmed.length];
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    for (NSUInteger index = 0; index < trimmed.length; index += 1) {
        unichar character = [trimmed characterAtIndex:index];
        if ([allowed characterIsMember:character]) {
            [result appendFormat:@"%C", character];
        }
    }
    return result.copy;
}

static NSString *PPOrderNormalizedPublicOrderNumberString(id value)
{
    NSString *uppercased = [[PPOrderTrimmedString(value) uppercaseString] copy];
    if (uppercased.length == 0) return @"";

    NSMutableString *result = [NSMutableString stringWithCapacity:uppercased.length];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
    for (NSUInteger index = 0; index < uppercased.length; index += 1) {
        unichar character = [uppercased characterAtIndex:index];
        if ([allowed characterIsMember:character]) {
            [result appendFormat:@"%C", character];
        }
    }
    return result.copy;
}

static NSString *PPOrderLegacyDisplayOrderReference(NSString *orderId)
{
    NSString *normalized = PPOrderUppercaseAlphaNumericString(orderId);
    if (normalized.length == 0) return @"";

    NSString *tail = normalized.length > 12 ? [normalized substringFromIndex:(normalized.length - 12)] : normalized;
    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    for (NSUInteger index = 0; index < tail.length; index += 4) {
        NSUInteger chunkLength = MIN((NSUInteger)4, tail.length - index);
        [groups addObject:[tail substringWithRange:NSMakeRange(index, chunkLength)]];
    }
    return [NSString stringWithFormat:@"PP-%@", [groups componentsJoinedByString:@"-"]];
}

static NSString *PPOrderNormalizedStatusString(id value)
{
    NSString *normalized = [[PPOrderTrimmedString(value) lowercaseString] copy];
    if (normalized.length == 0) return @"";

    normalized = [normalized stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([normalized containsString:@"__"]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return normalized;
}

static NSString *PPOrderResolvedDefaultCurrencyCode(void)
{
    NSString *currencyCode = [[CountryModel safeCurrentCurrencyCode] uppercaseString];
    return currencyCode.length == 3 ? currencyCode : @"QAR";
}

static NSString *PPOrderNormalizedPaymentMethodString(id value, id provider)
{
    NSString *normalized = PPOrderNormalizedStatusString(value);
    if (normalized.length == 0) {
        normalized = PPOrderNormalizedStatusString(provider);
    }
    if ([normalized isEqualToString:@"cash"] ||
        [normalized isEqualToString:@"cod"] ||
        [normalized isEqualToString:@"cash_on_delivery"]) {
        return @"cash";
    }
    return @"qib";
}

static BOOL PPOrderLegacyHasCapturedPayment(NSString *paymentMethod, NSString *status, NSString *transactionID, NSDate *paidAt, NSDate *paymentCollectedAt)
{
    if ([paymentMethod isEqualToString:@"cash"]) {
        return (transactionID.length > 0 ||
                [paidAt isKindOfClass:NSDate.class] ||
                [paymentCollectedAt isKindOfClass:NSDate.class]);
    }

    return (transactionID.length > 0 ||
            [paidAt isKindOfClass:NSDate.class] ||
            PPOrderStatusContainsToken(status, @"paid") ||
            PPOrderStatusContainsToken(status, @"success") ||
            PPOrderStatusContainsToken(status, @"approved") ||
            PPOrderStatusContainsToken(status, @"verified") ||
            PPOrderStatusContainsToken(status, @"processing") ||
            PPOrderStatusContainsToken(status, @"preparing") ||
            PPOrderStatusContainsToken(status, @"packed") ||
            PPOrderStatusContainsToken(status, @"shipped") ||
            PPOrderStatusContainsToken(status, @"delivered") ||
            PPOrderStatusContainsToken(status, @"fulfilled"));
}

static NSString *PPOrderNormalizedPaymentStatusString(id value, id paymentMethod, id status, id transactionId, id paidAt, id paymentCollectedAt)
{
    NSString *normalized = PPOrderNormalizedStatusString(value);
    if ([normalized isEqualToString:@"pending"] ||
        [normalized isEqualToString:@"pending_collection"] ||
        [normalized isEqualToString:@"paid"] ||
        [normalized isEqualToString:@"failed"] ||
        [normalized isEqualToString:@"cancelled"]) {
        return normalized;
    }

    NSString *method = PPOrderNormalizedPaymentMethodString(paymentMethod, nil);
    NSString *statusKey = PPOrderNormalizedStatusString(status);
    NSString *transactionKey = PPOrderTrimmedString(transactionId);
    NSDate *paidDate = PPOrderDateFromValue(paidAt, nil);
    NSDate *collectedDate = PPOrderDateFromValue(paymentCollectedAt, nil);

    if (PPOrderLegacyHasCapturedPayment(method, statusKey, transactionKey, paidDate, collectedDate)) {
        return @"paid";
    }
    if (PPOrderStatusContainsToken(statusKey, @"failed") ||
        PPOrderStatusContainsToken(statusKey, @"rejected") ||
        PPOrderStatusContainsToken(statusKey, @"declined") ||
        PPOrderStatusContainsToken(statusKey, @"expired") ||
        PPOrderStatusContainsToken(statusKey, @"voided") ||
        PPOrderStatusContainsToken(statusKey, @"error")) {
        return @"failed";
    }
    if (PPOrderStatusContainsToken(statusKey, @"cancelled") ||
        PPOrderStatusContainsToken(statusKey, @"canceled")) {
        return @"cancelled";
    }
    return [method isEqualToString:@"cash"] ? @"pending_collection" : @"pending";
}


static BOOL PPOrderStatusContainsToken(NSString *status, NSString *token)
{
    if (status.length == 0 || token.length == 0) return NO;
    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", status];
    NSString *wrappedToken = [NSString stringWithFormat:@"_%@_", token];
    return [wrappedStatus containsString:wrappedToken];
}

static NSDate *PPOrderDateFromValue(id value, NSDate *fallback)
{
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return ((FIRTimestamp *)value).dateValue ?: fallback;
    }
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    return fallback;
}

static PPOrderStatus PPOrderStatusFromRawValue(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = PPOrderNormalizedStatusString(value);
        if (PPOrderStatusContainsToken(normalized, @"paid") ||
            PPOrderStatusContainsToken(normalized, @"success") ||
            PPOrderStatusContainsToken(normalized, @"approved") ||
            PPOrderStatusContainsToken(normalized, @"verified") ||
            PPOrderStatusContainsToken(normalized, @"completed") ||
            PPOrderStatusContainsToken(normalized, @"processing") ||
            PPOrderStatusContainsToken(normalized, @"preparing") ||
            PPOrderStatusContainsToken(normalized, @"packed") ||
            PPOrderStatusContainsToken(normalized, @"shipped") ||
            PPOrderStatusContainsToken(normalized, @"delivery") ||
            PPOrderStatusContainsToken(normalized, @"delivered") ||
            PPOrderStatusContainsToken(normalized, @"fulfilled")) {
            return PPOrderStatusPaid;
        }
        if (PPOrderStatusContainsToken(normalized, @"failed") ||
            PPOrderStatusContainsToken(normalized, @"rejected") ||
            PPOrderStatusContainsToken(normalized, @"cancelled") ||
            PPOrderStatusContainsToken(normalized, @"canceled") ||
            PPOrderStatusContainsToken(normalized, @"cancel") ||
            PPOrderStatusContainsToken(normalized, @"expired")) {
            return PPOrderStatusFailed;
        }
        return PPOrderStatusPending;
    }

    if ([value respondsToSelector:@selector(integerValue)]) {
        NSInteger raw = [value integerValue];
        if (raw == PPOrderStatusPaid) return PPOrderStatusPaid;
        if (raw == PPOrderStatusFailed) return PPOrderStatusFailed;
    }

    return PPOrderStatusPending;
}

@implementation PPOrder

- (NSDictionary *)firestoreData
{
    NSString *statusString = PPOrderNormalizedStatusString(self.rawStatus);
    if (statusString.length == 0) {
        statusString = @"pending";
        if (self.status == PPOrderStatusPaid) statusString = @"paid";
        else if (self.status == PPOrderStatusFailed) statusString = @"failed";
    }

    return @{
        @"orderId": self.orderId,
        @"orderNumber": self.orderNumber.length > 0 ? self.orderNumber : [self displayOrderReference],
        @"userId": self.userId,
        @"status": statusString,
        @"amount": @(self.amount),
        @"shippingFee": @(MAX(0.0, self.shippingFee)),
        @"totalAmount": @(self.totalAmount),
        @"currency": self.currency ?: PPOrderResolvedDefaultCurrencyCode(),
        @"paymentMethodId": self.paymentMethodId.length > 0 ? self.paymentMethodId : @"qib",
        @"paymentStatus": self.paymentStatus.length > 0 ? self.paymentStatus : ([self isCashOnDelivery] ? @"pending_collection" : @"pending"),
        @"paymentProvider": self.paymentProvider ?: @"QIB",
        @"verificationStatus": self.verificationStatus.length > 0 ? self.verificationStatus : ([self isCashOnDelivery] ? @"not_applicable" : @"pending"),
        @"items": self.items ?: @[],
        @"shippingAddressId": self.shippingAddressId ?: @"",
        @"shippingAddressSnapshot": self.shippingAddressSnapshot ?: @{},
        @"createdAt": self.createdAt ?: [FIRTimestamp timestamp],
        @"updatedAt": self.updatedAt ?: [FIRTimestamp timestamp],
        @"statusUpdatedAt": self.statusUpdatedAt ?: self.updatedAt ?: [FIRTimestamp timestamp],
        @"paidAt": self.paidAt ?: [NSNull null],
        @"processedAt": self.processedAt ?: [NSNull null],
        @"shippedAt": self.shippedAt ?: [NSNull null],
        @"deliveredAt": self.deliveredAt ?: [NSNull null],
        @"cancelledAt": self.cancelledAt ?: [NSNull null],
        @"paymentCollectedAt": self.paymentCollectedAt ?: [NSNull null],
        @"estimatedDeliveryAt": self.estimatedDeliveryAt ?: [NSNull null],
        @"transactionId": self.transactionId ?: [NSNull null],
        @"paymentResponse": self.paymentResponse ?: [NSNull null],
        @"failureReason": self.failureReason ?: [NSNull null],
        @"paymentAttemptId": self.paymentAttemptId ?: [NSNull null],
        @"qibSessionId": self.qibSessionId ?: [NSNull null],
        @"inventoryDeducted": @NO,
        @"inventoryLowStockItemIDs": @[]
    };
}

+ (instancetype)orderFromSnapshot:(FIRDocumentSnapshot *)snapshot
{
    if (!snapshot) return nil;
    NSDictionary *data = snapshot.data;
    if (![data isKindOfClass:NSDictionary.class]) return nil;

    PPOrder *order = [PPOrder new];
    NSString *orderID = PPOrderTrimmedString(data[@"orderId"]);
    if (orderID.length == 0) {
        orderID = PPOrderTrimmedString(snapshot.documentID);
    }
    order.orderId = orderID ?: @"";
    NSString *orderNumber = PPOrderNormalizedPublicOrderNumberString(data[@"orderNumber"]);
    if (orderNumber.length == 0) {
        orderNumber = PPOrderNormalizedPublicOrderNumberString(data[@"displayOrderNumber"]);
    }
    order.orderNumber = orderNumber.length > 0 ? orderNumber : nil;

    NSString *userID = PPOrderTrimmedString(data[@"userId"]);
    if (userID.length == 0) {
        userID = PPOrderTrimmedString(data[@"uid"]);
    }
    order.userId = userID ?: @"";

    order.rawStatus = PPOrderNormalizedStatusString(data[@"status"]);
    order.status = PPOrderStatusFromRawValue(data[@"status"]);
    if (order.rawStatus.length == 0) {
        if (order.status == PPOrderStatusPaid) order.rawStatus = @"paid";
        else if (order.status == PPOrderStatusFailed) order.rawStatus = @"failed";
        else order.rawStatus = @"pending";
    }

    double amount = [data[@"amount"] respondsToSelector:@selector(doubleValue)] ? [data[@"amount"] doubleValue] : 0.0;
    double shippingFee = [data[@"shippingFee"] respondsToSelector:@selector(doubleValue)] ? [data[@"shippingFee"] doubleValue] : 0.0;
    double totalAmount = [data[@"totalAmount"] respondsToSelector:@selector(doubleValue)] ? [data[@"totalAmount"] doubleValue] : 0.0;
    if (totalAmount <= 0.0 && amount > 0.0) totalAmount = amount + MAX(0.0, shippingFee);
    if (amount <= 0.0 && totalAmount > 0.0) amount = totalAmount;
    order.amount = MAX(0.0, amount);
    order.shippingFee = MAX(0.0, shippingFee);
    order.totalAmount = MAX(0.0, totalAmount);

    NSString *currency = PPOrderTrimmedString(data[@"currency"]);
    order.currency = currency.length > 0 ? currency : PPOrderResolvedDefaultCurrencyCode();

    order.paymentMethodId = [self normalizedPaymentMethodFromRawValue:data[@"paymentMethodId"]
                                                             provider:data[@"paymentProvider"]];
    order.paymentStatus = [self normalizedPaymentStatusFromRawValue:data[@"paymentStatus"]
                                                      paymentMethod:order.paymentMethodId
                                                             status:data[@"status"]
                                                        transaction:data[@"transactionId"]
                                                             paidAt:data[@"paidAt"]
                                                  paymentCollectedAt:data[@"paymentCollectedAt"]];
    NSString *provider = PPOrderTrimmedString(data[@"paymentProvider"]);
    if (provider.length == 0) {
        provider = [order.paymentMethodId isEqualToString:@"cash"] ? @"CASH" : @"QIB";
    }
    order.paymentProvider = provider;
    NSString *verificationStatus = PPOrderTrimmedString(data[@"verificationStatus"]);
    if (verificationStatus.length == 0) {
        verificationStatus = [order.paymentMethodId isEqualToString:@"cash"] ? @"not_applicable" : @"pending";
    }
    order.verificationStatus = PPOrderNormalizedStatusString(verificationStatus);

    order.items = [data[@"items"] isKindOfClass:NSArray.class] ? data[@"items"] : @[];
    order.shippingAddressId = PPOrderTrimmedString(data[@"shippingAddressId"]);
    if (order.shippingAddressId.length == 0) {
        order.shippingAddressId = PPOrderTrimmedString(data[@"addressId"]);
    }
    order.shippingAddressSnapshot = [data[@"shippingAddressSnapshot"] isKindOfClass:NSDictionary.class] ? data[@"shippingAddressSnapshot"] : @{};

    NSDate *now = [NSDate date];
    order.createdAt = PPOrderDateFromValue(data[@"createdAt"], now);
    order.updatedAt = PPOrderDateFromValue(data[@"updatedAt"], order.createdAt ?: now);
    order.statusUpdatedAt = PPOrderDateFromValue(data[@"statusUpdatedAt"], order.updatedAt ?: order.createdAt ?: now);
    order.paidAt = PPOrderDateFromValue(data[@"paidAt"], nil);
    order.processedAt = PPOrderDateFromValue(data[@"processedAt"], nil);
    order.shippedAt = PPOrderDateFromValue(data[@"shippedAt"], nil);
    order.deliveredAt = PPOrderDateFromValue(data[@"deliveredAt"], nil);
    order.cancelledAt = PPOrderDateFromValue((data[@"cancelledAt"] ?: data[@"canceledAt"]), nil);
    order.paymentCollectedAt = PPOrderDateFromValue(data[@"paymentCollectedAt"], nil);
    order.estimatedDeliveryAt = PPOrderDateFromValue(data[@"estimatedDeliveryAt"], nil);

    NSString *transactionID = PPOrderTrimmedString(data[@"transactionId"]);
    order.transactionId = transactionID.length > 0 ? transactionID : nil;
    order.paymentResponse = [data[@"paymentResponse"] isKindOfClass:NSDictionary.class] ? data[@"paymentResponse"] : nil;

    NSString *failureReason = PPOrderTrimmedString(data[@"failureReason"]);
    if (failureReason.length == 0) {
        failureReason = PPOrderTrimmedString(data[@"cancelReason"]);
    }
    order.failureReason = failureReason.length > 0 ? failureReason : nil;
    
    NSString *paymentAttemptID = PPOrderTrimmedString(data[@"paymentAttemptId"]);
    order.paymentAttemptId = paymentAttemptID.length > 0 ? paymentAttemptID : nil;
    NSString *qibSessionID = PPOrderTrimmedString(data[@"qibSessionId"]);
    order.qibSessionId = qibSessionID.length > 0 ? qibSessionID : nil;

    return order;
}

+ (PPOrderStatus)statusFromRawValue:(id)value
{
    return PPOrderStatusFromRawValue(value);
}

+ (NSString *)normalizedStatusFromRawValue:(id)value
{
    return PPOrderNormalizedStatusString(value);
}

+ (NSString *)normalizedPaymentMethodFromRawValue:(id)value provider:(id)provider
{
    return PPOrderNormalizedPaymentMethodString(value, provider);
}

+ (NSString *)normalizedPaymentStatusFromRawValue:(id)value
                                    paymentMethod:(id)paymentMethod
                                           status:(id)status
                                      transaction:(id)transactionId
                                           paidAt:(id)paidAt
                                paymentCollectedAt:(id)paymentCollectedAt
{
    return PPOrderNormalizedPaymentStatusString(value, paymentMethod, status, transactionId, paidAt, paymentCollectedAt);
}

- (BOOL)isCashOnDelivery
{
    return [self.paymentMethodId isEqualToString:@"cash"];
}

- (BOOL)hasCapturedPayment
{
    return [self.paymentStatus isEqualToString:@"paid"] ||
           PPOrderLegacyHasCapturedPayment(self.paymentMethodId,
                                          PPOrderNormalizedStatusString(self.rawStatus),
                                          PPOrderTrimmedString(self.transactionId),
                                          self.paidAt,
                                          self.paymentCollectedAt);
}

- (NSString *)displayOrderReference
{
    NSString *explicitNumber = PPOrderNormalizedPublicOrderNumberString(self.orderNumber);
    if (explicitNumber.length > 0) {
        return explicitNumber;
    }
    return PPOrderLegacyDisplayOrderReference(self.orderId);
}

@end
