//
//  PPOrder.m
//  Pure Pets
//
//  Production-ready Order Model
//

#import "PPOrder.h"
#import "PPFormatSupport.h"
@import FirebaseFirestore;

static NSString *PPOrderTrimmedString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return @"";
}

static NSString *PPOrderResolvedDefaultCurrencyCode(void)
{
    return @"QAR";
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

static BOOL PPOrderStatusContainsToken(NSString *status, NSString *token)
{
    if (status.length == 0 || token.length == 0) return NO;
    if ([status isEqualToString:token]) return YES;
    NSString *wrapped = [NSString stringWithFormat:@"_%@_", status];
    return [wrapped containsString:[NSString stringWithFormat:@"_%@_", token]] || [status containsString:token];
}

static PPOrderStatus PPOrderStatusFromRawValue(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = PPOrderNormalizedStatusString(value);
        if (PPOrderStatusContainsToken(normalized, @"abandoned")) {
            return PPOrderStatusAbandoned;
        }
        if (PPOrderStatusContainsToken(normalized, @"cancelled") || PPOrderStatusContainsToken(normalized, @"canceled")) {
            return PPOrderStatusCancelled;
        }
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
            PPOrderStatusContainsToken(normalized, @"error") ||
            PPOrderStatusContainsToken(normalized, @"declined")) {
            return PPOrderStatusFailed;
        }
    }
    return PPOrderStatusPending;
}

static NSString *PPOrderNormalizedPaymentMethodString(id value, id fallbackProvider)
{
    NSString *raw = PPOrderTrimmedString(value).lowercaseString;
    if (raw.length == 0) raw = PPOrderTrimmedString(fallbackProvider).lowercaseString;
    if ([raw containsString:@"cash"] || [raw containsString:@"cod"]) return @"cash";
    if ([raw containsString:@"qib"] || [raw containsString:@"card"] || [raw containsString:@"online"]) return @"qib";
    if ([raw containsString:@"apple"]) return @"apple_pay";
    return @"qib";
}

static NSString *PPOrderNormalizedPaymentStatusString(id value, id paymentMethodId, id legacyStatus, id transactionId, id paidAt, id paymentCollectedAt)
{
    NSString *raw = PPOrderTrimmedString(value).lowercaseString;
    NSString *normalizedMethod = PPOrderNormalizedPaymentMethodString(paymentMethodId, nil);

    if ([raw containsString:@"paid"] || [raw containsString:@"success"] || [raw containsString:@"captured"] || [raw containsString:@"approved"]) {
        return @"paid";
    }

    if ([raw containsString:@"failed"] || [raw containsString:@"declined"] || [raw containsString:@"rejected"] || [raw containsString:@"error"]) {
        return @"failed";
    }
    
    if ([raw containsString:@"cancel"] || [raw containsString:@"abandoned"]) {
        return @"cancelled";
    }

    if (PPOrderTrimmedString(transactionId).length > 0) return @"paid";
    if (paidAt != nil || paymentCollectedAt != nil) return @"paid";

    NSString *legacyRaw = PPOrderNormalizedStatusString(legacyStatus);
    if ([legacyRaw isEqualToString:@"paid"] || [legacyRaw isEqualToString:@"completed"]) {
        return @"paid";
    }

    if ([normalizedMethod isEqualToString:@"cash"]) {
        return @"pending_collection";
    }

    return @"pending";
}

static NSString *PPOrderNormalizedVerificationStatusString(id value, id paymentMethodId, id transactionId)
{
    NSString *raw = PPOrderTrimmedString(value).lowercaseString;
    NSString *normalizedMethod = PPOrderNormalizedPaymentMethodString(paymentMethodId, nil);

    if ([raw containsString:@"verified"] || [raw containsString:@"success"] || [raw containsString:@"approved"]) {
        return @"verified";
    }

    if ([raw containsString:@"failed"] || [raw containsString:@"error"] || [raw containsString:@"rejected"]) {
        return @"failed";
    }

    if (PPOrderTrimmedString(transactionId).length > 0) {
        return @"verified";
    }

    if ([normalizedMethod isEqualToString:@"cash"]) {
        return @"not_applicable";
    }

    return @"pending";
}

@implementation PPOrder

+ (instancetype)orderFromSnapshot:(FIRDocumentSnapshot *)snapshot
{
    if (!snapshot || !snapshot.exists || ![snapshot.data isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    return [self orderFromDictionary:snapshot.data documentID:snapshot.documentID];
}

+ (instancetype)orderFromDictionary:(NSDictionary *)data documentID:(NSString *)documentID
{
    if (![data isKindOfClass:NSDictionary.class]) return nil;
    PPOrder *order = [[PPOrder alloc] init];

    order.orderId = documentID ?: PPOrderTrimmedString(data[@"orderId"]);
    order.orderNumber = PPOrderTrimmedString(data[@"orderNumber"]);
    order.userId = PPOrderTrimmedString(data[@"userId"]);

    order.rawStatus = PPOrderTrimmedString(data[@"status"]);
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
    order.paymentProvider = PPOrderTrimmedString(data[@"paymentProvider"]);
    order.verificationStatus = [self normalizedVerificationStatusFromRawValue:data[@"verificationStatus"]
                                                                paymentMethod:order.paymentMethodId
                                                                  transaction:data[@"transactionId"]];

    order.transactionId = PPOrderTrimmedString(data[@"transactionId"]);
    order.qibSessionId = PPOrderTrimmedString(data[@"qibSessionId"]);
    order.paymentAttemptId = PPOrderTrimmedString(data[@"paymentAttemptId"]);
    if ([data[@"paymentResponse"] isKindOfClass:NSDictionary.class]) {
        order.paymentResponse = data[@"paymentResponse"];
    }

    if ([data[@"items"] isKindOfClass:NSArray.class]) {
        order.items = data[@"items"];
    } else {
        order.items = @[];
    }

    order.shippingAddressId = PPOrderTrimmedString(data[@"shippingAddressId"]);
    if ([data[@"shippingAddressSnapshot"] isKindOfClass:NSDictionary.class]) {
        order.shippingAddressSnapshot = data[@"shippingAddressSnapshot"];
    }

    order.failureReason = PPOrderTrimmedString(data[@"failureReason"]);

    order.createdAt = [self parseDateFromValue:data[@"createdAt"]];
    order.updatedAt = [self parseDateFromValue:data[@"updatedAt"]];
    order.statusUpdatedAt = [self parseDateFromValue:data[@"statusUpdatedAt"]];
    order.paidAt = [self parseDateFromValue:data[@"paidAt"]];
    order.paymentCollectedAt = [self parseDateFromValue:data[@"paymentCollectedAt"]];

    order.deliveryStatus = PPOrderTrimmedString(data[@"deliveryStatus"]);

    return order;
}

- (NSDictionary<NSString *, id> *)exportToDictionary
{
    NSString *statusString = @"pending";
    if (self.rawStatus.length > 0) {
        statusString = self.rawStatus;
    } else {
        if (self.status == PPOrderStatusPaid) statusString = @"paid";
        else if (self.status == PPOrderStatusFailed) statusString = @"failed";
        else if (self.status == PPOrderStatusCancelled) statusString = @"cancelled";
        else if (self.status == PPOrderStatusAbandoned) statusString = @"abandoned";
    }

    return @{
        @"orderId": self.orderId ?: @"",
        @"orderNumber": self.orderNumber.length > 0 ? self.orderNumber : [self displayOrderReference],
        @"userId": self.userId ?: @"",
        @"status": statusString,
        @"deliveryStatus": self.deliveryStatus.length > 0 ? self.deliveryStatus : [self effectiveDeliveryStatus],
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
        @"statusUpdatedAt": self.statusUpdatedAt ?: [FIRTimestamp timestamp],
        @"paidAt": self.paidAt ?: [NSNull null],
        @"paymentCollectedAt": self.paymentCollectedAt ?: [NSNull null],
        @"transactionId": self.transactionId ?: @"",
        @"qibSessionId": self.qibSessionId ?: @"",
        @"paymentAttemptId": self.paymentAttemptId ?: @"",
        @"paymentResponse": self.paymentResponse ?: @{},
        @"failureReason": self.failureReason ?: @""
    };
}

- (BOOL)hasCapturedPayment
{
    if ([self.paymentStatus isEqualToString:@"paid"]) return YES;
    if (self.paidAt != nil) return YES;
    if (self.transactionId.length > 0) return YES;
    
    NSString *raw = self.rawStatus.lowercaseString;
    if ([raw containsString:@"paid"] || [raw containsString:@"success"] || [raw containsString:@"captured"] || [raw containsString:@"approved"]) {
        return YES;
    }
    return NO;
}

- (BOOL)isCashOnDelivery
{
    return [self.paymentMethodId isEqualToString:@"cash"];
}

- (NSString *)displayOrderReference
{
    if (self.orderNumber.length > 0) {
        return self.orderNumber;
    }
    if (self.orderId.length > 0) {
        return [self.orderId substringToIndex:MIN((NSUInteger)8, self.orderId.length)];
    }
    return @"—";
}

- (NSString *)effectiveDeliveryStatus
{
    if (self.deliveryStatus.length > 0) {
        return self.deliveryStatus;
    }
    if (self.status == PPOrderStatusPending) {
        return @"preparing";
    }
    if (self.status == PPOrderStatusFailed) {
        return @"cancelled";
    }
    return @"pending";
}

+ (NSDate *)parseDateFromValue:(id)value
{
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        NSTimeInterval interval = [value doubleValue];
        if (interval > 1e10) { 
            interval /= 1000.0;
        }
        return [NSDate dateWithTimeIntervalSince1970:interval];
    }
    if ([value isKindOfClass:NSString.class]) {
        static NSISO8601DateFormatter *formatter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSISO8601DateFormatter alloc] init];
            formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        });
        NSDate *date = [formatter dateFromString:value];
        if (!date) {
            static NSISO8601DateFormatter *fallbackFormatter = nil;
            static dispatch_once_t fallbackOnceToken;
            dispatch_once(&fallbackOnceToken, ^{
                fallbackFormatter = [[NSISO8601DateFormatter alloc] init];
                fallbackFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
            });
            date = [fallbackFormatter dateFromString:value];
        }
        return date;
    }
    return nil;
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

+ (NSString *)normalizedVerificationStatusFromRawValue:(id)value
                                         paymentMethod:(id)paymentMethod
                                           transaction:(id)transactionId
{
    return PPOrderNormalizedVerificationStatusString(value, paymentMethod, transactionId);
}

@end
