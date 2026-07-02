//
//  PPOrder.m
//  Pure Pets
//
//  Production-ready Order Model
//

#import "PPOrder.h"
#import "CountryModel.h"
@import FirebaseFirestore;

static BOOL PPOrderStatusContainsToken(NSString *status, NSString *token);

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

static NSString *PPOrderNormalizedDeliveryStatusString(id value)
{
    NSString *normalized = PPOrderNormalizedStatusString(value);
    if (normalized.length == 0) return @"";

    if (PPOrderStatusContainsToken(normalized, @"cancelled") ||
        PPOrderStatusContainsToken(normalized, @"canceled")) {
        return @"delivery_cancelled";
    }
    if (PPOrderStatusContainsToken(normalized, @"returned_to_store")) {
        return @"returned_to_store";
    }
    if (PPOrderStatusContainsToken(normalized, @"failed") ||
        PPOrderStatusContainsToken(normalized, @"rejected") ||
        PPOrderStatusContainsToken(normalized, @"declined") ||
        PPOrderStatusContainsToken(normalized, @"expired") ||
        PPOrderStatusContainsToken(normalized, @"voided") ||
        PPOrderStatusContainsToken(normalized, @"error")) {
        return @"delivery_failed";
    }
    if (PPOrderStatusContainsToken(normalized, @"completed") ||
        PPOrderStatusContainsToken(normalized, @"fulfilled")) {
        return @"completed";
    }
    if (PPOrderStatusContainsToken(normalized, @"delivered")) {
        return @"delivered";
    }
    if ([normalized isEqualToString:@"payment_pending"] ||
        [normalized isEqualToString:@"payment_confirmed"]) {
        return normalized;
    }
    if ([normalized isEqualToString:@"picked_up"]) {
        return @"picked_up";
    }
    if ([normalized isEqualToString:@"handed_over"]) {
        return @"picked_up";
    }
    if ([normalized isEqualToString:@"in_transit"] ||
        [normalized isEqualToString:@"out_for_delivery"] ||
        PPOrderStatusContainsToken(normalized, @"shipped") ||
        PPOrderStatusContainsToken(normalized, @"shipping")) {
        return @"in_transit";
    }
    if ([normalized isEqualToString:@"delivery_assigned"] ||
        [normalized isEqualToString:@"awaiting_handover"]) {
        return normalized;
    }
    if ([normalized isEqualToString:@"ready_to_ship"] ||
        [normalized isEqualToString:@"delivery_requested"] ||
        [normalized isEqualToString:@"delivery_reassigned"]) {
        return normalized;
    }
    if ([normalized isEqualToString:@"ready_for_delivery"] ||
        [normalized isEqualToString:@"ready"]) {
        return @"delivery_requested";
    }
    return @"";
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
    order.processedAt = [self parseDateFromValue:data[@"processedAt"]];
    order.readyAt = [self parseDateFromValue:data[@"readyAt"]];
    order.readyToShipAt = [self parseDateFromValue:data[@"readyToShipAt"]];
    order.deliveryRequestedAt = [self parseDateFromValue:data[@"deliveryRequestedAt"]];
    order.deliveryAcceptedAt = [self parseDateFromValue:data[@"deliveryAcceptedAt"]];
    order.pickedUpAt = [self parseDateFromValue:data[@"pickedUpAt"]];
    order.inTransitAt = [self parseDateFromValue:data[@"inTransitAt"]];
    order.shippedAt = [self parseDateFromValue:data[@"shippedAt"]];
    order.deliveredAt = [self parseDateFromValue:data[@"deliveredAt"]];
    order.paymentPendingAt = [self parseDateFromValue:data[@"paymentPendingAt"]];
    order.paymentConfirmedAt = [self parseDateFromValue:data[@"paymentConfirmedAt"]];
    order.completedAt = [self parseDateFromValue:data[@"completedAt"]];
    order.deliveryFailedAt = [self parseDateFromValue:data[@"deliveryFailedAt"]];
    order.returnedToStoreAt = [self parseDateFromValue:data[@"returnedToStoreAt"]];
    order.cancelledAt = [self parseDateFromValue:data[@"cancelledAt"] ?: data[@"canceledAt"]];
    order.paymentCollectedAt = [self parseDateFromValue:data[@"paymentCollectedAt"]];
    order.estimatedDeliveryAt = [self parseDateFromValue:data[@"estimatedDeliveryAt"]];

    order.deliveryStatus = PPOrderTrimmedString(data[@"deliveryStatus"]);
    order.deliveryUserId = PPOrderTrimmedString(data[@"deliveryUserId"] ?: data[@"deliveryUid"]);

    // Per-owner fulfillment fields (Phase 15 — additive, backward-compatible)
    if ([data[@"fulfillmentOrderIDs"] isKindOfClass:NSArray.class]) {
        order.fulfillmentOrderIDs = data[@"fulfillmentOrderIDs"];
    }
    if ([data[@"fulfillmentSummary"] isKindOfClass:NSDictionary.class]) {
        order.fulfillmentSummary = data[@"fulfillmentSummary"];
    }

    return order;
}

- (BOOL)hasFulfillmentOrders
{
    return self.fulfillmentOrderIDs.count > 0;
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

- (NSDictionary *)firestoreData
{
    return [self exportToDictionary];
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

- (BOOL)requiresPostDeliveryPaymentConfirmation
{
    return [self isCashOnDelivery] && ![self hasCapturedPayment];
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
    NSString *explicitStatus = PPOrderNormalizedDeliveryStatusString(self.deliveryStatus);
    if (explicitStatus.length > 0) {
        return explicitStatus;
    }

    NSString *raw = PPOrderNormalizedStatusString(self.rawStatus);
    if (PPOrderStatusContainsToken(raw, @"cancelled") ||
        PPOrderStatusContainsToken(raw, @"canceled")) {
        return @"delivery_cancelled";
    }
    if (PPOrderStatusContainsToken(raw, @"returned_to_store")) {
        return @"returned_to_store";
    }
    if (PPOrderStatusContainsToken(raw, @"failed") ||
        PPOrderStatusContainsToken(raw, @"rejected") ||
        PPOrderStatusContainsToken(raw, @"declined") ||
        PPOrderStatusContainsToken(raw, @"expired") ||
        PPOrderStatusContainsToken(raw, @"voided") ||
        PPOrderStatusContainsToken(raw, @"error")) {
        return @"delivery_failed";
    }
    if (PPOrderStatusContainsToken(raw, @"completed") ||
        PPOrderStatusContainsToken(raw, @"fulfilled")) {
        return @"completed";
    }
    if (PPOrderStatusContainsToken(raw, @"delivered")) {
        return [self requiresPostDeliveryPaymentConfirmation] ? @"payment_pending" : @"delivered";
    }
    if (PPOrderStatusContainsToken(raw, @"shipped") ||
        PPOrderStatusContainsToken(raw, @"shipping") ||
        PPOrderStatusContainsToken(raw, @"out_for_delivery") ||
        PPOrderStatusContainsToken(raw, @"in_transit")) {
        return self.inTransitAt ? @"in_transit" : @"picked_up";
    }
    if (PPOrderStatusContainsToken(raw, @"ready")) {
        return (self.deliveryUserId.length > 0 || self.deliveryAcceptedAt != nil)
            ? @"awaiting_handover"
            : @"delivery_requested";
    }
    if (PPOrderStatusContainsToken(raw, @"processing") ||
        PPOrderStatusContainsToken(raw, @"preparing") ||
        PPOrderStatusContainsToken(raw, @"packed") ||
        PPOrderStatusContainsToken(raw, @"confirmed") ||
        PPOrderStatusContainsToken(raw, @"paid") ||
        PPOrderStatusContainsToken(raw, @"success") ||
        PPOrderStatusContainsToken(raw, @"approved") ||
        PPOrderStatusContainsToken(raw, @"verified")) {
        return @"ready_to_ship";
    }

    if (self.status == PPOrderStatusFailed || self.status == PPOrderStatusCancelled || self.status == PPOrderStatusAbandoned) {
        return @"delivery_failed";
    }
    return @"preparing_for_shipment";
}

- (NSString *)customerVisibleStatusKey
{
    NSString *delivery = [self effectiveDeliveryStatus];
    NSString *raw = PPOrderNormalizedStatusString(self.rawStatus);

    if ([delivery isEqualToString:@"delivery_cancelled"] ||
        PPOrderStatusContainsToken(raw, @"cancelled") ||
        PPOrderStatusContainsToken(raw, @"canceled")) {
        return @"delivery_cancelled";
    }
    if ([delivery isEqualToString:@"delivery_failed"] ||
        [delivery isEqualToString:@"returned_to_store"] ||
        PPOrderStatusContainsToken(raw, @"returned_to_store") ||
        PPOrderStatusContainsToken(raw, @"failed") ||
        PPOrderStatusContainsToken(raw, @"rejected") ||
        PPOrderStatusContainsToken(raw, @"declined") ||
        PPOrderStatusContainsToken(raw, @"expired") ||
        PPOrderStatusContainsToken(raw, @"voided") ||
        PPOrderStatusContainsToken(raw, @"error")) {
        return @"delivery_delayed";
    }
    if ([delivery isEqualToString:@"completed"] ||
        PPOrderStatusContainsToken(raw, @"completed") ||
        PPOrderStatusContainsToken(raw, @"fulfilled")) {
        return @"completed";
    }
    if ([delivery isEqualToString:@"delivered"] ||
        [delivery isEqualToString:@"payment_pending"] ||
        [delivery isEqualToString:@"payment_confirmed"] ||
        PPOrderStatusContainsToken(raw, @"delivered")) {
        return @"delivered";
    }
    if ([delivery isEqualToString:@"picked_up"] ||
        [delivery isEqualToString:@"in_transit"] ||
        PPOrderStatusContainsToken(raw, @"shipped") ||
        PPOrderStatusContainsToken(raw, @"shipping") ||
        PPOrderStatusContainsToken(raw, @"out_for_delivery") ||
        PPOrderStatusContainsToken(raw, @"in_transit")) {
        return @"on_the_way";
    }
    if ([delivery isEqualToString:@"delivery_assigned"] ||
        [delivery isEqualToString:@"awaiting_handover"] ||
        self.deliveryAcceptedAt != nil) {
        return @"delivery_partner_assigned";
    }
    if ([delivery isEqualToString:@"ready_to_ship"] ||
        [delivery isEqualToString:@"delivery_requested"] ||
        [delivery isEqualToString:@"delivery_reassigned"] ||
        self.deliveryRequestedAt != nil ||
        self.readyToShipAt != nil ||
        self.readyAt != nil) {
        return @"ready_for_delivery";
    }
    if (PPOrderStatusContainsToken(raw, @"pending") ||
        PPOrderStatusContainsToken(raw, @"created") ||
        PPOrderStatusContainsToken(raw, @"placed") ||
        PPOrderStatusContainsToken(raw, @"waiting")) {
        return @"pending";
    }
    return @"preparing_for_shipment";
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
