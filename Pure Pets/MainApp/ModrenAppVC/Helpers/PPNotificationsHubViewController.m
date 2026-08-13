//
//  PPNotificationsHubViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//

#import "PPNotificationsHubViewController.h"
#import "PPPetRemindersViewController.h"
#import "UserChatsViewController.h"
#import "PPOrderDetailsRouter.h"
#import "PPOrder.h"
#import "ChNotificationRouter.h"
#import "AppClasses.h"
#import "Language.h"
#import <Pure_Pets-Swift.h>
@import Firebase;
@import FirebaseFirestore;
@import FirebaseAuth;

static CGFloat const kPPHubTopBarHeight = 52.0;
static CGFloat const kPPHubActionButtonSize = 48.0;
static CGFloat const kPPHubHeroHorizontalInset = 20.0;
static CGFloat const kPPHubHeroTopInset = 8.0;
static CGFloat const kPPHubContentTopGap = 12.0;
// The root tab controller owns the floating Command Deck clearance and raises
// visible list insets dynamically. Keep only the screen's intrinsic breathing
// room here so a measured deck can also shrink or hide without leaving a hole.
static CGFloat const kPPHubListBaseBottomInset = PPSpaceMD;
static NSInteger const kPPHubSegmentIconTag = 4701;
static NSInteger const kPPHubSegmentTitleTag = 4702;

static NSString *PPHubTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPHubScalarString(id value)
{
    NSString *stringValue = PPHubTrimmedString(value);
    if (stringValue.length > 0) return stringValue;

    if ([value isKindOfClass:NSNumber.class]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.minimumFractionDigits = 0;
        formatter.maximumFractionDigits = 2;
        return [formatter stringFromNumber:(NSNumber *)value] ?: [(NSNumber *)value stringValue];
    }

    return @"";
}

static NSDate *PPHubDateFromValue(id value)
{
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)value doubleValue]];
    }
    return nil;
}

static NSDictionary *PPHubSafeDictionary(id value)
{
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPHubFirstStringForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    for (NSString *key in keys) {
        NSString *value = PPHubTrimmedString(source[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPHubFirstScalarForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    for (NSString *key in keys) {
        NSString *value = PPHubScalarString(source[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPHubOrderIDFromPayload(NSDictionary *payload)
{
    NSDictionary *safePayload = PPHubSafeDictionary(payload);
    NSDictionary *meta = PPHubSafeDictionary(safePayload[@"meta"]);
    NSArray<NSString *> *keys = @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"];
    NSString *orderID = PPHubFirstScalarForKeys(safePayload, keys);
    if (orderID.length == 0) {
        orderID = PPHubFirstScalarForKeys(meta, keys);
    }
    return orderID;
}

static NSString *PPHubLocalizedValueFromDictionary(NSDictionary *source, NSArray<NSString *> *arKeys, NSArray<NSString *> *enKeys)
{
    NSArray<NSString *> *primaryKeys = Language.isRTL ? arKeys : enKeys;
    NSArray<NSString *> *fallbackKeys = Language.isRTL ? enKeys : arKeys;
    NSString *primary = PPHubFirstStringForKeys(source, primaryKeys);
    if (primary.length > 0) return primary;
    return PPHubFirstStringForKeys(source, fallbackKeys);
}

static NSString *PPHubLocalizedNestedValue(id nestedValue)
{
    NSDictionary *dictionary = PPHubSafeDictionary(nestedValue);
    if (dictionary.count == 0) return PPHubTrimmedString(nestedValue);
    return PPHubLocalizedValueFromDictionary(dictionary,
                                            @[@"ar", @"arabic", @"titleAr", @"bodyAr", @"valueAr", @"textAr"],
                                            @[@"en", @"english", @"titleEn", @"bodyEn", @"valueEn", @"textEn"]);
}

static BOOL PPHubStringEquals(NSString *lhs, NSString *rhs)
{
    return [PPHubTrimmedString(lhs) caseInsensitiveCompare:PPHubTrimmedString(rhs)] == NSOrderedSame;
}

static BOOL PPHubStringHasPrefix(NSString *value, NSString *prefix)
{
    return [PPHubTrimmedString(value) rangeOfString:prefix options:NSCaseInsensitiveSearch | NSAnchoredSearch].location != NSNotFound;
}

static BOOL PPHubIsProviderOnlyNotificationPayload(NSDictionary *payload)
{
    NSDictionary *safePayload = PPHubSafeDictionary(payload);
    NSString *type = [[PPHubFirstStringForKeys(safePayload, @[@"notificationType", @"type"]) lowercaseString] copy];
    NSString *route = [[PPHubTrimmedString(safePayload[@"route"]) lowercaseString] copy];
    NSString *targetAppId = [[PPHubFirstStringForKeys(safePayload, @[@"targetApp", @"targetAppId", @"appId"]) lowercaseString] copy];
    NSString *audience = [[PPHubTrimmedString(safePayload[@"audience"]) lowercaseString] copy];
    NSString *customerOrderID = PPHubOrderIDFromPayload(safePayload);

    return [targetAppId isEqualToString:@"pro_ios"] ||
           [audience isEqualToString:@"delivery_providers"] ||
           [type hasPrefix:@"drivers_delivery_"] ||
           [type isEqualToString:@"provider_new_fulfillment"] ||
           ([route isEqualToString:@"fulfillment_order"] && customerOrderID.length == 0);
}

static NSString *PPHubOrderReferenceFromTitle(NSString *title)
{
    NSString *safeTitle = PPHubTrimmedString(title);
    NSString *prefix = @"New Order ";
    if (!PPHubStringHasPrefix(safeTitle, prefix) || safeTitle.length <= prefix.length) {
        return @"";
    }
    return PPHubTrimmedString([safeTitle substringFromIndex:prefix.length]);
}

static NSString *PPHubOrderReferenceFromBody(NSString *body)
{
    NSString *safeBody = PPHubTrimmedString(body);
    if (safeBody.length == 0) return @"";

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*(#[^\\s]+)\\s+"
                                                                           options:0
                                                                             error:&error];
    if (error) return @"";

    NSTextCheckingResult *match = [regex firstMatchInString:safeBody options:0 range:NSMakeRange(0, safeBody.length)];
    if (!match || match.numberOfRanges < 2) return @"";
    return [safeBody substringWithRange:[match rangeAtIndex:1]];
}

static NSString *PPHubDisplayOrderReference(NSString *reference)
{
    NSString *safeReference = PPHubTrimmedString(reference);
    if (safeReference.length == 0) return @"";
    if ([safeReference hasPrefix:@"#"]) return safeReference;
    return [NSString stringWithFormat:@"#%@", safeReference];
}

static NSString *PPHubOrderReferenceFromPayload(NSDictionary *payload, NSDictionary *meta)
{
    NSString *reference = PPHubFirstScalarForKeys(meta, @[@"orderReference", @"orderNumber", @"parentOrderNumber", @"orderId", @"parentOrderId"]);
    if (reference.length == 0) {
        reference = PPHubFirstScalarForKeys(payload, @[@"orderReference", @"orderNumber", @"orderId", @"parentOrderNumber", @"parentOrderId"]);
    }
    return PPHubDisplayOrderReference(reference);
}

static BOOL PPHubParseOrderSummaryBody(NSString *body, NSString **itemCount, NSString **amount, NSString **currency)
{
    NSString *safeBody = PPHubTrimmedString(body);
    if (safeBody.length == 0) return NO;

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*(\\d+)\\s+item\\(s\\)\\s*•\\s*([0-9]+(?:\\.[0-9]+)?)\\s*([A-Za-z]+)\\s*$"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    if (error) return NO;

    NSTextCheckingResult *match = [regex firstMatchInString:safeBody options:0 range:NSMakeRange(0, safeBody.length)];
    if (!match || match.numberOfRanges < 4) return NO;

    if (itemCount) *itemCount = [safeBody substringWithRange:[match rangeAtIndex:1]];
    if (amount) *amount = [safeBody substringWithRange:[match rangeAtIndex:2]];
    if (currency) *currency = [safeBody substringWithRange:[match rangeAtIndex:3]];
    return YES;
}

static NSString *PPHubNotificationType(NSDictionary *payload, NSDictionary *meta)
{
    NSString *type = PPHubFirstStringForKeys(payload, @[@"notificationType", @"type", @"key", @"eventKey", @"route"]);
    if (type.length == 0) {
        type = PPHubFirstStringForKeys(meta, @[@"notificationType", @"type", @"key", @"eventKey", @"route"]);
    }
    return [[type lowercaseString] copy];
}

static NSString *PPHubNotificationStatus(NSDictionary *payload, NSDictionary *meta)
{
    NSString *status = PPHubFirstStringForKeys(payload, @[@"status", @"fulfillmentStatus", @"toStatus", @"paymentStatus", @"deliveryStatus"]);
    if (status.length == 0) {
        status = PPHubFirstStringForKeys(meta, @[@"status", @"fulfillmentStatus", @"toStatus", @"paymentStatus", @"deliveryStatus"]);
    }
    return [[status lowercaseString] copy];
}

static NSString *PPHubCustomerDeliveryTitleKey(NSString *type, NSString *rawTitle, NSString *rawBody)
{
    if ([type isEqualToString:@"customer_delivery_requested"] ||
        PPHubStringEquals(rawTitle, @"Your Order Is Ready")) {
        return @"notifications_inbox_customer_delivery_requested_title";
    }
    if ([type isEqualToString:@"customer_delivery_assigned"] ||
        PPHubStringEquals(rawTitle, @"Delivery Partner Assigned")) {
        return @"notifications_inbox_customer_delivery_assigned_title";
    }
    if ([type isEqualToString:@"customer_delivery_on_the_way"] ||
        PPHubStringEquals(rawTitle, @"Your Order Is On the Way")) {
        return @"notifications_inbox_customer_delivery_on_the_way_title";
    }
    if ([type isEqualToString:@"customer_delivery_delivered"] ||
        PPHubStringEquals(rawTitle, @"Order Delivered")) {
        return @"notifications_inbox_customer_delivery_delivered_title";
    }
    if ([type isEqualToString:@"customer_delivery_completed"] ||
        PPHubStringEquals(rawTitle, @"Order Completed")) {
        return @"notifications_inbox_customer_delivery_completed_title";
    }
    if ([type isEqualToString:@"customer_delivery_cancelled"] ||
        PPHubStringEquals(rawBody, @"The delivery for your order has been cancelled. Please contact support if you need assistance.")) {
        return @"notifications_inbox_customer_delivery_update_title";
    }
    if ([type isEqualToString:@"customer_delivery_failed"] ||
        PPHubStringEquals(rawBody, @"We were unable to complete your delivery. Our team will review the order and update you shortly.")) {
        return @"notifications_inbox_customer_delivery_update_title";
    }
    if ([type isEqualToString:@"customer_delivery_delayed"] ||
        PPHubStringEquals(rawBody, @"Your delivery needs a little more time. Our team is reviewing the order and will update you shortly.")) {
        return @"notifications_inbox_customer_delivery_update_title";
    }
    return @"";
}

static NSString *PPHubCustomerDeliveryBodyKey(NSString *type, NSString *rawBody)
{
    if ([type isEqualToString:@"customer_delivery_requested"] ||
        PPHubStringEquals(rawBody, @"Your order is packed and ready for shipment. A delivery partner will be assigned shortly.")) {
        return @"notifications_inbox_customer_delivery_requested_body";
    }
    if ([type isEqualToString:@"customer_delivery_assigned"] ||
        PPHubStringEquals(rawBody, @"A delivery partner has been assigned to your order and will collect it shortly.")) {
        return @"notifications_inbox_customer_delivery_assigned_body";
    }
    if ([type isEqualToString:@"customer_delivery_on_the_way"] ||
        PPHubStringEquals(rawBody, @"Your order has been collected and is now on its way to you.")) {
        return @"notifications_inbox_customer_delivery_on_the_way_body";
    }
    if ([type isEqualToString:@"customer_delivery_delivered"] ||
        PPHubStringEquals(rawBody, @"Your order has been delivered successfully. Thank you for choosing Pure Pets.")) {
        return @"notifications_inbox_customer_delivery_delivered_body";
    }
    if ([type isEqualToString:@"customer_delivery_completed"] ||
        PPHubStringEquals(rawBody, @"Your order has been completed successfully. Thank you for shopping with Pure Pets.")) {
        return @"notifications_inbox_customer_delivery_completed_body";
    }
    if ([type isEqualToString:@"customer_delivery_cancelled"] ||
        PPHubStringEquals(rawBody, @"The delivery for your order has been cancelled. Please contact support if you need assistance.")) {
        return @"notifications_inbox_customer_delivery_cancelled_body";
    }
    if ([type isEqualToString:@"customer_delivery_failed"] ||
        PPHubStringEquals(rawBody, @"We were unable to complete your delivery. Our team will review the order and update you shortly.")) {
        return @"notifications_inbox_customer_delivery_failed_body";
    }
    if ([type isEqualToString:@"customer_delivery_delayed"] ||
        PPHubStringEquals(rawBody, @"Your delivery needs a little more time. Our team is reviewing the order and will update you shortly.")) {
        return @"notifications_inbox_customer_delivery_delayed_body";
    }
    return @"";
}

static NSString *PPHubOrderStatusTitleKey(NSString *type, NSString *status, NSString *rawTitle)
{
    if ([type isEqualToString:@"order_payment_status"] ||
        PPHubStringEquals(rawTitle, @"Cash Payment Collected | تم تحصيل الدفع")) {
        return @"notifications_inbox_order_cash_collected_title";
    }

    BOOL isOrderStatus = [type isEqualToString:@"order_status"] || ([type hasPrefix:@"order"] && ![type isEqualToString:@"order_payment_status"]);
    if ((isOrderStatus && [status isEqualToString:@"paid"]) ||
        PPHubStringEquals(rawTitle, @"Payment Confirmed | تم تأكيد الدفع")) {
        return @"notifications_inbox_order_payment_confirmed_title";
    }
    if ((isOrderStatus && [status isEqualToString:@"processing"]) ||
        PPHubStringEquals(rawTitle, @"Order Processing | جاري تجهيز الطلب")) {
        return @"notifications_inbox_order_processing_title";
    }
    if ((isOrderStatus && [status isEqualToString:@"shipped"]) ||
        PPHubStringEquals(rawTitle, @"Order Shipped | تم شحن الطلب")) {
        return @"notifications_inbox_order_shipped_title";
    }
    if ((isOrderStatus && [status isEqualToString:@"delivered"]) ||
        PPHubStringEquals(rawTitle, @"Order Delivered | تم تسليم الطلب")) {
        return @"notifications_inbox_order_delivered_title";
    }
    if ((isOrderStatus && ([status isEqualToString:@"cancelled"] || [status isEqualToString:@"canceled"])) ||
        PPHubStringEquals(rawTitle, @"Order Cancelled | تم إلغاء الطلب")) {
        return @"notifications_inbox_order_cancelled_title";
    }
    if ((isOrderStatus && [status isEqualToString:@"failed"]) ||
        PPHubStringEquals(rawTitle, @"Payment Failed | فشل الدفع")) {
        return @"notifications_inbox_order_failed_title";
    }
    return @"";
}

static NSString *PPHubOrderStatusBodyFormatKey(NSString *type, NSString *status, NSString *rawTitle, NSString *rawBody)
{
    if ([type isEqualToString:@"order_payment_status"] ||
        PPHubStringEquals(rawTitle, @"Cash Payment Collected | تم تحصيل الدفع") ||
        [rawBody containsString:@"cash payment was collected successfully."]) {
        return @"notifications_inbox_order_cash_collected_body_format";
    }

    BOOL isOrderStatus = [type isEqualToString:@"order_status"] || ([type hasPrefix:@"order"] && ![type isEqualToString:@"order_payment_status"]);
    if ((isOrderStatus && [status isEqualToString:@"paid"]) ||
        PPHubStringEquals(rawTitle, @"Payment Confirmed | تم تأكيد الدفع") ||
        [rawBody containsString:@"is confirmed and paid."]) {
        return @"notifications_inbox_order_payment_confirmed_body_format";
    }
    if ((isOrderStatus && [status isEqualToString:@"processing"]) ||
        PPHubStringEquals(rawTitle, @"Order Processing | جاري تجهيز الطلب") ||
        [rawBody containsString:@"is now being prepared."]) {
        return @"notifications_inbox_order_processing_body_format";
    }
    if ((isOrderStatus && [status isEqualToString:@"shipped"]) ||
        PPHubStringEquals(rawTitle, @"Order Shipped | تم شحن الطلب") ||
        [rawBody containsString:@"is on the way."]) {
        return @"notifications_inbox_order_shipped_body_format";
    }
    if ((isOrderStatus && [status isEqualToString:@"delivered"]) ||
        PPHubStringEquals(rawTitle, @"Order Delivered | تم تسليم الطلب") ||
        [rawBody containsString:@"has been delivered."]) {
        return @"notifications_inbox_order_delivered_body_format";
    }
    if ((isOrderStatus && ([status isEqualToString:@"cancelled"] || [status isEqualToString:@"canceled"])) ||
        PPHubStringEquals(rawTitle, @"Order Cancelled | تم إلغاء الطلب") ||
        [rawBody containsString:@"was cancelled."]) {
        return @"notifications_inbox_order_cancelled_body_format";
    }
    if ((isOrderStatus && [status isEqualToString:@"failed"]) ||
        PPHubStringEquals(rawTitle, @"Payment Failed | فشل الدفع") ||
        [rawBody containsString:@"could not be completed."]) {
        return @"notifications_inbox_order_failed_body_format";
    }
    return @"";
}

static NSString *PPHubLocalizedNotificationTitle(NSString *rawTitle, NSString *rawBody, NSDictionary *payload)
{
    NSDictionary *safePayload = PPHubSafeDictionary(payload);
    NSDictionary *meta = PPHubSafeDictionary(safePayload[@"meta"]);
    NSString *type = PPHubNotificationType(safePayload, meta);
    NSString *status = PPHubNotificationStatus(safePayload, meta);

    NSString *titleKey = PPHubFirstStringForKeys(safePayload, @[@"titleLocalizationKey", @"titleKey", @"titleLocKey"]);
    if (titleKey.length == 0) titleKey = PPHubFirstStringForKeys(meta, @[@"titleLocalizationKey", @"titleKey", @"titleLocKey"]);
    if (titleKey.length > 0) return kLang(titleKey);

    NSString *localized = PPHubLocalizedValueFromDictionary(safePayload,
                                                           @[@"titleAr", @"title_ar", @"arTitle", @"titleArabic", @"title_arabic"],
                                                           @[@"titleEn", @"title_en", @"enTitle", @"titleEnglish", @"title_english"]);
    if (localized.length == 0) {
        localized = PPHubLocalizedValueFromDictionary(meta,
                                                      @[@"titleAr", @"title_ar", @"arTitle", @"titleArabic", @"title_arabic"],
                                                      @[@"titleEn", @"title_en", @"enTitle", @"titleEnglish", @"title_english"]);
    }
    if (localized.length > 0) return localized;

    for (NSString *key in @[@"localizedTitle", @"titleLocalized", @"titleI18n", @"title_i18n", @"titleMap"]) {
        localized = PPHubLocalizedNestedValue(safePayload[key]);
        if (localized.length > 0) return localized;
        localized = PPHubLocalizedNestedValue(meta[key]);
        if (localized.length > 0) return localized;
    }

    NSString *customerDeliveryKey = PPHubCustomerDeliveryTitleKey(type, rawTitle, rawBody);
    if (customerDeliveryKey.length > 0) return kLang(customerDeliveryKey);

    NSString *orderStatusKey = PPHubOrderStatusTitleKey(type, status, rawTitle);
    if (orderStatusKey.length > 0) return kLang(orderStatusKey);

    if ([type isEqualToString:@"drivers_delivery_requested"] ||
        [type isEqualToString:@"delivery_requested"] ||
        PPHubStringEquals(rawTitle, @"New Delivery Request")) {
        return kLang(@"notifications_inbox_new_delivery_request_title");
    }

    if ([type isEqualToString:@"drivers_delivery_request_closed"] ||
        [type isEqualToString:@"delivery_request_closed"] ||
        PPHubStringEquals(rawTitle, @"Delivery Request Closed")) {
        return kLang(@"notifications_inbox_delivery_request_closed_title");
    }

    if ([type isEqualToString:@"provider_new_fulfillment"] ||
        [type isEqualToString:@"fulfillment_order"] ||
        [status isEqualToString:@"new_request"] ||
        PPHubStringHasPrefix(rawTitle, @"New Order ")) {
        NSString *orderReference = PPHubFirstScalarForKeys(meta, @[@"orderNumber", @"parentOrderNumber", @"orderReference", @"orderId", @"parentOrderId"]);
        if (orderReference.length == 0) {
            orderReference = PPHubFirstScalarForKeys(safePayload, @[@"orderNumber", @"orderReference", @"orderId"]);
        }
        if (orderReference.length == 0) orderReference = PPHubOrderReferenceFromTitle(rawTitle);
        NSString *format = kLang(@"notifications_inbox_new_order_title_format");
        return orderReference.length > 0 ? [NSString stringWithFormat:format, orderReference] : kLang(@"notifications_inbox_new_order_title");
    }

    return PPHubTrimmedString(rawTitle);
}

static NSString *PPHubLocalizedNotificationBody(NSString *rawBody, NSString *rawTitle, NSDictionary *payload)
{
    NSDictionary *safePayload = PPHubSafeDictionary(payload);
    NSDictionary *meta = PPHubSafeDictionary(safePayload[@"meta"]);
    NSString *type = PPHubNotificationType(safePayload, meta);
    NSString *status = PPHubNotificationStatus(safePayload, meta);

    NSString *bodyKey = PPHubFirstStringForKeys(safePayload, @[@"bodyLocalizationKey", @"bodyKey", @"bodyLocKey"]);
    if (bodyKey.length == 0) bodyKey = PPHubFirstStringForKeys(meta, @[@"bodyLocalizationKey", @"bodyKey", @"bodyLocKey"]);
    if (bodyKey.length > 0) return kLang(bodyKey);

    NSString *localized = PPHubLocalizedValueFromDictionary(safePayload,
                                                           @[@"bodyAr", @"body_ar", @"arBody", @"bodyArabic", @"body_arabic", @"messageAr", @"message_ar"],
                                                           @[@"bodyEn", @"body_en", @"enBody", @"bodyEnglish", @"body_english", @"messageEn", @"message_en"]);
    if (localized.length == 0) {
        localized = PPHubLocalizedValueFromDictionary(meta,
                                                      @[@"bodyAr", @"body_ar", @"arBody", @"bodyArabic", @"body_arabic", @"messageAr", @"message_ar"],
                                                      @[@"bodyEn", @"body_en", @"enBody", @"bodyEnglish", @"body_english", @"messageEn", @"message_en"]);
    }
    if (localized.length > 0) return localized;

    for (NSString *key in @[@"localizedBody", @"bodyLocalized", @"bodyI18n", @"body_i18n", @"bodyMap"]) {
        localized = PPHubLocalizedNestedValue(safePayload[key]);
        if (localized.length > 0) return localized;
        localized = PPHubLocalizedNestedValue(meta[key]);
        if (localized.length > 0) return localized;
    }

    NSString *customerDeliveryKey = PPHubCustomerDeliveryBodyKey(type, rawBody);
    if (customerDeliveryKey.length > 0) return kLang(customerDeliveryKey);

    NSString *orderFormatKey = PPHubOrderStatusBodyFormatKey(type, status, rawTitle, rawBody);
    if (orderFormatKey.length > 0) {
        NSString *reference = PPHubOrderReferenceFromPayload(safePayload, meta);
        if (reference.length == 0) reference = PPHubOrderReferenceFromBody(rawBody);
        if (reference.length == 0) reference = kLang(@"notifications_inbox_order_reference_fallback");
        return [NSString stringWithFormat:kLang(orderFormatKey), reference];
    }

    if ([type isEqualToString:@"drivers_delivery_requested"] ||
        [type isEqualToString:@"delivery_requested"] ||
        PPHubStringEquals(rawTitle, @"New Delivery Request") ||
        PPHubStringEquals(rawBody, @"A new order is ready for pickup. Please review the details and accept the delivery request.")) {
        return kLang(@"notifications_inbox_new_delivery_request_body");
    }

    if ([type isEqualToString:@"drivers_delivery_request_closed"] ||
        [type isEqualToString:@"delivery_request_closed"] ||
        PPHubStringEquals(rawTitle, @"Delivery Request Closed") ||
        PPHubStringEquals(rawBody, @"This delivery request is no longer available.")) {
        return kLang(@"notifications_inbox_delivery_request_closed_body");
    }

    if ([type isEqualToString:@"provider_new_fulfillment"] ||
        [type isEqualToString:@"fulfillment_order"] ||
        [status isEqualToString:@"new_request"] ||
        PPHubStringHasPrefix(rawTitle, @"New Order ")) {
        NSString *itemCount = PPHubFirstScalarForKeys(meta, @[@"itemCount", @"itemsCount"]);
        NSString *amount = PPHubFirstScalarForKeys(meta, @[@"subtotal", @"amount", @"total"]);
        NSString *currency = PPHubFirstScalarForKeys(meta, @[@"currency"]);
        if (itemCount.length == 0 || amount.length == 0 || currency.length == 0) {
            itemCount = itemCount.length ? itemCount : PPHubFirstScalarForKeys(safePayload, @[@"itemCount", @"itemsCount"]);
            amount = amount.length ? amount : PPHubFirstScalarForKeys(safePayload, @[@"subtotal", @"amount", @"total"]);
            currency = currency.length ? currency : PPHubFirstScalarForKeys(safePayload, @[@"currency"]);
        }
        if (itemCount.length == 0 || amount.length == 0 || currency.length == 0) {
            NSString *parsedCount = nil;
            NSString *parsedAmount = nil;
            NSString *parsedCurrency = nil;
            if (PPHubParseOrderSummaryBody(rawBody, &parsedCount, &parsedAmount, &parsedCurrency)) {
                if (itemCount.length == 0) itemCount = parsedCount;
                if (amount.length == 0) amount = parsedAmount;
                if (currency.length == 0) currency = parsedCurrency;
            }
        }
        if (itemCount.length > 0 && amount.length > 0 && currency.length > 0) {
            return [NSString stringWithFormat:kLang(@"notifications_inbox_order_items_total_format"), itemCount, amount, currency];
        }
    }

    return PPHubTrimmedString(rawBody);
}

static NSString *PPHubInboxCategoryTitle(NSDictionary *payload)
{
    NSDictionary *meta = PPHubSafeDictionary(payload[@"meta"]);
    NSString *type = PPHubNotificationType(payload, meta);
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubOrderIDFromPayload(payload);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return kLang(@"notifications_inbox_category_chat") ?: @"";
    }
    if (orderID.length > 0 || [type hasPrefix:@"order"]) {
        return kLang(@"notifications_inbox_category_orders") ?: @"";
    }
    return kLang(@"notifications_inbox_category_updates") ?: @"";
}

static UIColor *PPHubInboxAccentColor(NSDictionary *payload)
{
    NSDictionary *meta = PPHubSafeDictionary(payload[@"meta"]);
    NSString *type = PPHubNotificationType(payload, meta);
    NSString *status = PPHubNotificationStatus(payload, meta);
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return [GM appPrimaryColor];
    }
    if ([status containsString:@"deliver"] || [status containsString:@"paid"]) {
        return [UIColor ppSuccess];
    }
    if ([status containsString:@"ship"]) {
        return [UIColor ppInfo];
    }
    if ([status containsString:@"fail"] || [status containsString:@"cancel"]) {
        return [UIColor ppError];
    }
    return [UIColor ppWarning];
}

static NSString *PPHubInboxSymbolName(NSDictionary *payload)
{
    NSDictionary *meta = PPHubSafeDictionary(payload[@"meta"]);
    NSString *type = PPHubNotificationType(payload, meta);
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubOrderIDFromPayload(payload);
    NSString *status = PPHubNotificationStatus(payload, meta);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return @"ellipsis.message.fill";
    }
    if (orderID.length > 0 || [type hasPrefix:@"order"]) {
        if ([status containsString:@"deliver"]) return @"checkmark.seal.fill";
        if ([status containsString:@"ship"]) return @"shippingbox.fill";
        if ([status containsString:@"fail"] || [status containsString:@"cancel"]) return @"xmark.octagon.fill";
        return @"bag.fill.badge.plus";
    }
    return @"bell.badge.fill";
}

@interface PPHubTopTabsView : UIView
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *contentClipView;
@property (nonatomic, strong) UIView *selectionIndicator;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, strong) NSLayoutConstraint *indicatorLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *indicatorWidthConstraint;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) void (^onSelectionChanged)(NSInteger index);
- (instancetype)initWithTitles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons;
- (void)selectIndex:(NSInteger)index animated:(BOOL)animated;
- (void)updateTitles:(NSArray<NSString *> *)titles;
@end

@implementation PPHubTopTabsView

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    _surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor = [UIColor ppSecondarySurface];
    _surfaceView.layer.cornerRadius = PPCornerMedium;
    _surfaceView.layer.masksToBounds = YES;
    _surfaceView.layer.borderWidth = 0.75;
    [_surfaceView pp_setBorderColor:[UIColor ppBorder]];
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:_surfaceView];

    _contentClipView = [[UIView alloc] initWithFrame:CGRectZero];
    _contentClipView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentClipView.backgroundColor = UIColor.clearColor;
    _contentClipView.layer.masksToBounds = YES;
    _contentClipView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        _contentClipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_contentClipView];

    _selectionIndicator = [[UIView alloc] initWithFrame:CGRectZero];
    _selectionIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionIndicator.backgroundColor = [UIColor ppPrimary];
    _selectionIndicator.layer.cornerRadius = PPCornerSmall;
    _selectionIndicator.layer.masksToBounds = YES;
    _selectionIndicator.hidden = YES;
    _selectionIndicator.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        _selectionIndicator.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_contentClipView addSubview:_selectionIndicator];

    UIStackView *stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.spacing = PPSpaceXS;
    stackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_contentClipView addSubview:stackView];
    self.stackView = stackView;

    UIImageSymbolConfiguration *symbolConfig = nil;
    if (@available(iOS 13.0, *)) {
        symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.5 weight:UIImageSymbolWeightSemibold];
    }

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSUInteger count = MIN(titles.count, icons.count);
    for (NSUInteger index = 0; index < count; index++) {
        UIButton *button = [self pp_makeSegmentButtonWithTitle:titles[index]
                                                       iconName:icons[index]
                                                          index:(NSInteger)index
                                                   symbolConfig:symbolConfig];
        [button addTarget:self action:@selector(pp_handleTap:) forControlEvents:UIControlEventTouchUpInside];
        [stackView addArrangedSubview:button];
        [buttons addObject:button];
    }
    self.tabButtons = buttons.copy;

    self.indicatorLeadingConstraint = [self.selectionIndicator.leadingAnchor constraintEqualToAnchor:self.contentClipView.leadingAnchor constant:5.0];
    self.indicatorWidthConstraint = [self.selectionIndicator.widthAnchor constraintEqualToConstant:100.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.surfaceView.heightAnchor constraintEqualToConstant:kPPHubTopBarHeight],

        [self.contentClipView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:PPSpaceXS],
        [self.contentClipView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPSpaceXS],
        [self.contentClipView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSpaceXS],
        [self.contentClipView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-PPSpaceXS],

        self.indicatorLeadingConstraint,
        [self.selectionIndicator.topAnchor constraintEqualToAnchor:self.contentClipView.topAnchor],
        [self.selectionIndicator.bottomAnchor constraintEqualToAnchor:self.contentClipView.bottomAnchor],
        self.indicatorWidthConstraint,

        [stackView.topAnchor constraintEqualToAnchor:self.contentClipView.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:self.contentClipView.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.contentClipView.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.contentClipView.bottomAnchor],
    ]];

    self.selectedIndex = NSNotFound;
    return self;
}

- (UIButton *)pp_makeSegmentButtonWithTitle:(NSString *)title
                                   iconName:(NSString *)iconName
                                      index:(NSInteger)index
                               symbolConfig:(UIImageSymbolConfiguration *)symbolConfig
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = index;
    button.backgroundColor = UIColor.clearColor;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.layer.cornerRadius = PPCornerSmall;
    button.layer.borderWidth = 0.0;
    button.layer.masksToBounds = YES;
    [button pp_setBorderColor:UIColor.clearColor];
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        image = [[UIImage systemImageNamed:iconName withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        image = [UIImage imageNamed:iconName];
    }

    UIImageView *iconView = [[UIImageView alloc] initWithImage:image];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tag = kPPHubSegmentIconTag;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.tag = kPPHubSegmentTitleTag;
    titleLabel.text = title ?: @"";
    UIFont *tabBaseFont = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout] scaledFontForFont:tabBaseFont];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.allowsDefaultTighteningForTruncation = YES;

    UIStackView *contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, titleLabel]];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisHorizontal;
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.distribution = UIStackViewDistributionFill;
    contentStack.spacing = PPSpaceMDHalf;
    contentStack.userInteractionEnabled = NO;
    contentStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [button addSubview:contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.widthAnchor constraintEqualToConstant:19.0],
        [iconView.heightAnchor constraintEqualToConstant:19.0],

        [contentStack.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [contentStack.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [contentStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:button.leadingAnchor constant:PPSpaceSM],
        [contentStack.trailingAnchor constraintLessThanOrEqualToAnchor:button.trailingAnchor constant:-PPSpaceSM],
        [contentStack.topAnchor constraintGreaterThanOrEqualToAnchor:button.topAnchor constant:4.0],
        [contentStack.bottomAnchor constraintLessThanOrEqualToAnchor:button.bottomAnchor constant:-4.0],
    ]];

    button.accessibilityLabel = title ?: @"";
    button.accessibilityTraits = UIAccessibilityTraitButton;
    return button;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    BOOL usesAccessibilityCategory = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    for (UIButton *button in self.tabButtons) {
        UILabel *titleLabel = [button viewWithTag:kPPHubSegmentTitleTag];
        titleLabel.hidden = usesAccessibilityCategory;
    }

    if (self.selectedIndex != NSNotFound) {
        [self pp_updateSelectionIndicatorForIndex:self.selectedIndex animated:NO];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (![self.traitCollection.preferredContentSizeCategory
          isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        BOOL usesAccessibilityCategory = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
        for (UIButton *button in self.tabButtons) {
            UILabel *titleLabel = [button viewWithTag:kPPHubSegmentTitleTag];
            titleLabel.hidden = usesAccessibilityCategory;
        }
        [self setNeedsLayout];
    }
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < 0 || index >= (NSInteger)self.tabButtons.count) return;
    self.selectedIndex = index;
    [self pp_updateSelectionIndicatorForIndex:index animated:animated];
    [self pp_refreshButtonAppearance];
}

- (void)updateTitles:(NSArray<NSString *> *)titles
{
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.surfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentClipView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.stackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    NSUInteger count = MIN(titles.count, self.tabButtons.count);
    for (NSUInteger index = 0; index < count; index++) {
        UIButton *button = self.tabButtons[index];
        NSString *title = titles[index] ?: @"";
        UILabel *titleLabel = [button viewWithTag:kPPHubSegmentTitleTag];
        titleLabel.text = title;
        titleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        button.accessibilityLabel = title;
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)pp_handleTap:(UIButton *)sender
{
    NSInteger index = sender.tag;
    if (index == self.selectedIndex) return;
    [self selectIndex:index animated:YES];
    if (self.onSelectionChanged) {
        self.onSelectionChanged(index);
    }
}

- (void)pp_updateSelectionIndicatorForIndex:(NSInteger)index animated:(BOOL)animated
{
    CGFloat containerWidth = CGRectGetWidth(self.contentClipView.bounds);
    if (containerWidth <= 0.0 || self.tabButtons.count == 0) return;

    CGFloat tabWidth = floor(containerWidth / (CGFloat)self.tabButtons.count);
    CGFloat width = MAX(68.0, tabWidth - PPSpaceSM);
    CGFloat leading = (tabWidth * (CGFloat)index) + ((tabWidth - width) * 0.5);

    self.indicatorLeadingConstraint.constant = leading;
    self.indicatorWidthConstraint.constant = width;
    self.selectionIndicator.hidden = NO;

    void (^animations)(void) = ^{
        [self.surfaceView layoutIfNeeded];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        animations();
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.56
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:animations
                     completion:nil];
}

- (void)pp_refreshButtonAppearance
{
    UIColor *inactiveColor = [UIColor ppTextSecondary];
    UIColor *selectedColor = UIColor.whiteColor;
    for (NSInteger index = 0; index < (NSInteger)self.tabButtons.count; index++) {
        BOOL isSelected = (index == self.selectedIndex);
        UIButton *button = self.tabButtons[index];
        UIImageView *iconView = [button viewWithTag:kPPHubSegmentIconTag];
        UILabel *titleLabel = [button viewWithTag:kPPHubSegmentTitleTag];
        UIColor *contentColor = isSelected ? selectedColor : inactiveColor;
        button.backgroundColor = UIColor.clearColor;
        [button pp_setBorderColor:UIColor.clearColor];
        button.tintColor = contentColor;
        iconView.tintColor = contentColor;
        titleLabel.textColor = contentColor;
        button.alpha = 1.0;
        button.accessibilityTraits = UIAccessibilityTraitButton | (isSelected ? UIAccessibilityTraitSelected : 0);
    }
}

@end

@interface PPNotificationInboxItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *documentID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *categoryTitle;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, copy) NSDictionary *payload;
@property (nonatomic, assign) BOOL isRead;
@end

@implementation PPNotificationInboxItem
@end

@interface PPNotificationInboxCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *unreadRailView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
- (void)configureWithItem:(PPNotificationInboxItem *)item formatter:(NSDateFormatter *)formatter;
@end

@implementation PPNotificationInboxCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [UIColor ppSurface];
    _cardView.layer.cornerRadius = PPCornerCard;
    _cardView.layer.masksToBounds = YES;
    _cardView.layer.borderWidth = 0.75;
    [_cardView pp_setBorderColor:[UIColor ppBorder]];
    _cardView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:_cardView];

    _unreadRailView = [[UIView alloc] initWithFrame:CGRectZero];
    _unreadRailView.translatesAutoresizingMaskIntoConstraints = NO;
    _unreadRailView.backgroundColor = [UIColor ppPrimary];
    _unreadRailView.layer.cornerRadius = 1.5;
    _unreadRailView.userInteractionEnabled = NO;
    [_cardView addSubview:_unreadRailView];

    _iconContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    _iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconContainerView.layer.cornerRadius = PPCorner16;
    _iconContainerView.layer.masksToBounds = YES;
    [_cardView addSubview:_iconContainerView];

    _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconContainerView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *titleBaseFont = [GM boldFontWithSize:16.5] ?: [UIFont systemFontOfSize:16.5 weight:UIFontWeightSemibold];
    _titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:titleBaseFont];
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.textColor = [UIColor ppTextPrimary];
    _titleLabel.numberOfLines = 0;
    _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _titleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *subtitleBaseFont = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    _subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:subtitleBaseFont];
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    _subtitleLabel.textColor = [UIColor ppTextSecondary];
    _subtitleLabel.numberOfLines = 0;
    _subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _subtitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_cardView addSubview:_subtitleLabel];

    _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *metaBaseFont = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _metaLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:metaBaseFont];
    _metaLabel.adjustsFontForContentSizeCategory = YES;
    _metaLabel.textColor = [UIColor ppTextSecondary];
    _metaLabel.numberOfLines = 2;
    _metaLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _metaLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_cardView addSubview:_metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceXS],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceXS],

        [self.unreadRailView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:PPSpaceXS],
        [self.unreadRailView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.unreadRailView.widthAnchor constraintEqualToConstant:3.0],
        [self.unreadRailView.heightAnchor constraintEqualToConstant:32.0],

        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:PPSpaceBase],
        [self.iconContainerView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:46.0],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:46.0],
        [self.iconContainerView.topAnchor constraintGreaterThanOrEqualToAnchor:self.cardView.topAnchor constant:PPSpaceBase],
        [self.iconContainerView.bottomAnchor constraintLessThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-PPSpaceBase],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:20.0],
        [self.iconView.heightAnchor constraintEqualToConstant:20.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:PPSpaceBase],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:PPSpaceMD],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-PPSpaceBase],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:PPSpaceXS],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.metaLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:PPSpaceSM],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.metaLabel.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-PPSpaceBase],
    ]];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                                                cornerRadius:self.cardView.layer.cornerRadius].CGPath;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.metaLabel.text = @"";
    self.iconView.image = nil;
    self.cardView.transform = CGAffineTransformIdentity;
    self.cardView.alpha = 1.0;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    CGAffineTransform transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    CGFloat alpha = highlighted ? 0.92 : 1.0;
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        self.cardView.transform = transform;
        self.cardView.alpha = alpha;
        return;
    }

    [UIView animateWithDuration:highlighted ? 0.12 : 0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.transform = transform;
        self.cardView.alpha = alpha;
    } completion:nil];
}

- (void)configureWithItem:(PPNotificationInboxItem *)item formatter:(NSDateFormatter *)formatter
{
    self.titleLabel.text = item.title ?: @"";
    self.subtitleLabel.text = item.subtitle ?: @"";
    UIFont *titleBaseFont = item.isRead
        ? ([GM MidFontWithSize:16.5] ?: [UIFont systemFontOfSize:16.5 weight:UIFontWeightMedium])
        : ([GM boldFontWithSize:16.5] ?: [UIFont systemFontOfSize:16.5 weight:UIFontWeightSemibold]);
    self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:titleBaseFont];
    self.unreadRailView.hidden = item.isRead;
    self.cardView.backgroundColor = item.isRead ? [UIColor ppSurface] : [UIColor ppElevatedSurface];
    NSString *dateText = @"";
    if ([item.timestamp isKindOfClass:NSDate.class]) {
        dateText = [formatter stringFromDate:item.timestamp] ?: @"";
    }
    if (dateText.length > 0 && item.categoryTitle.length > 0) {
        self.metaLabel.text = [NSString stringWithFormat:@"%@ • %@", item.categoryTitle, dateText];
    } else {
        self.metaLabel.text = item.categoryTitle.length > 0 ? item.categoryTitle : dateText;
    }

    UIColor *accent = item.accentColor ?: [UIColor ppPrimary];
    self.iconContainerView.backgroundColor = [accent colorWithAlphaComponent:0.14];
    self.iconView.tintColor = accent;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
        self.iconView.image = [UIImage systemImageNamed:item.symbolName ?: @"bell.fill" withConfiguration:config];
    } else {
        self.iconView.image = [UIImage imageNamed:item.symbolName ?: @"bell.fill"];
    }

    NSMutableArray<NSString *> *accessibilityParts = [NSMutableArray array];
    if (item.title.length > 0) [accessibilityParts addObject:item.title];
    if (item.subtitle.length > 0) [accessibilityParts addObject:item.subtitle];
    if (self.metaLabel.text.length > 0) [accessibilityParts addObject:self.metaLabel.text];
    self.accessibilityLabel = [accessibilityParts componentsJoinedByString:@", "];
    self.accessibilityValue = item.isRead ? nil : (kLang(@"New") ?: @"");
}

@end

typedef NS_ENUM(NSInteger, PPNotificationsInboxState) {
    PPNotificationsInboxStateLoading,
    PPNotificationsInboxStateContent,
    PPNotificationsInboxStateEmpty,
    PPNotificationsInboxStateError,
};

@interface PPNotificationsInboxViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *stateView;
@property (nonatomic, strong) UIImageView *stateIconView;
@property (nonatomic, strong) UIActivityIndicatorView *stateActivityIndicator;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIButton *stateRetryButton;
@property (nonatomic, strong) NSArray<PPNotificationInboxItem *> *items;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> inboxListener;
@property (nonatomic, assign) FIRAuthStateDidChangeListenerHandle authStateListenerHandle;
@property (nonatomic, assign) NSUInteger inboxLoadGeneration;
@property (nonatomic, assign) PPNotificationsInboxState inboxState;
@property (nonatomic, copy) NSString *observedUID;
- (void)reloadNotifications;
- (void)pp_renderInboxState:(PPNotificationsInboxState)state;
@end

@implementation PPNotificationsInboxViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.items = @[];

    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar_QA" : @"en_QA"];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 112.0;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsMake(PPSpaceSM, 0.0, kPPHubListBaseBottomInset, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:PPNotificationInboxCell.class forCellReuseIdentifier:@"PPNotificationInboxCell"];

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = [UIColor ppPrimary];
    refreshControl.accessibilityLabel = kLang(@"empty_retry_button") ?: @"";
    [refreshControl addTarget:self action:@selector(reloadNotifications) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refreshControl;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIView *emptyView = [[UIView alloc] initWithFrame:CGRectZero];
    emptyView.backgroundColor = UIColor.clearColor;
    emptyView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.stateView = emptyView;

    UIImageView *emptyIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    emptyIconView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIconView.tintColor = [UIColor ppTextSecondary];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:42.0 weight:UIImageSymbolWeightRegular];
        emptyIconView.image = [UIImage systemImageNamed:@"bell.slash.fill" withConfiguration:config];
    }
    [emptyView addSubview:emptyIconView];
    self.stateIconView = emptyIconView;

    self.stateActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.stateActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateActivityIndicator.color = [UIColor ppPrimary];
    self.stateActivityIndicator.hidesWhenStopped = YES;
    [emptyView addSubview:self.stateActivityIndicator];

    self.emptyTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *stateTitleBaseFont = [GM boldFontWithSize:20.0] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightBold];
    self.emptyTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2] scaledFontForFont:stateTitleBaseFont];
    self.emptyTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.emptyTitleLabel.textColor = [UIColor ppTextPrimary];
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.text = kLang(@"notifications_inbox_empty_title") ?: @"";
    [emptyView addSubview:self.emptyTitleLabel];

    self.emptySubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *stateSubtitleBaseFont = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    self.emptySubtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:stateSubtitleBaseFont];
    self.emptySubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.emptySubtitleLabel.textColor = [UIColor ppTextSecondary];
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.numberOfLines = 0;
    self.emptySubtitleLabel.text = kLang(@"notifications_inbox_empty_subtitle") ?: @"";
    [emptyView addSubview:self.emptySubtitleLabel];

    self.stateRetryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.stateRetryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateRetryButton.tintColor = [UIColor ppPrimary];
    self.stateRetryButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
                                             scaledFontForFont:([GM boldFontWithSize:15.0]
                                                                ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold])];
    self.stateRetryButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.stateRetryButton setTitle:(kLang(@"retry") ?: @"") forState:UIControlStateNormal];
    [self.stateRetryButton addTarget:self action:@selector(reloadNotifications) forControlEvents:UIControlEventTouchUpInside];
    self.stateRetryButton.contentEdgeInsets = UIEdgeInsetsMake(PPSpaceSM, PPSpaceBase, PPSpaceSM, PPSpaceBase);
    self.stateRetryButton.layer.cornerRadius = PPCornerSmall;
    self.stateRetryButton.layer.borderWidth = 0.75;
    [self.stateRetryButton pp_setBorderColor:[UIColor ppBorder]];
    [emptyView addSubview:self.stateRetryButton];

    [NSLayoutConstraint activateConstraints:@[
        [emptyIconView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [emptyIconView.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:-38.0],

        [self.stateActivityIndicator.centerXAnchor constraintEqualToAnchor:emptyIconView.centerXAnchor],
        [self.stateActivityIndicator.centerYAnchor constraintEqualToAnchor:emptyIconView.centerYAnchor],

        [self.emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIconView.bottomAnchor constant:PPSpaceBase],
        [self.emptyTitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:28.0],
        [self.emptyTitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-28.0],

        [self.emptySubtitleLabel.topAnchor constraintEqualToAnchor:self.emptyTitleLabel.bottomAnchor constant:PPSpaceSM],
        [self.emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:34.0],
        [self.emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-34.0],

        [self.stateRetryButton.topAnchor constraintEqualToAnchor:self.emptySubtitleLabel.bottomAnchor constant:PPSpaceBase],
        [self.stateRetryButton.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [self.stateRetryButton.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
    ]];
    self.tableView.backgroundView = emptyView;
    [self pp_renderInboxState:PPNotificationsInboxStateLoading];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:@"PPRemoteNotificationTapped"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageNotification:)
                                                 name:@"LanguageDidChangeNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageNotification:)
                                                 name:PPLanguageDidChangeNotification
                                               object:nil];

    __weak typeof(self) weakSelf = self;
    self.authStateListenerHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth * _Nonnull auth, FIRUser * _Nullable user) {
        (void)auth;
        (void)user;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf reloadNotifications];
    }];

    [self reloadNotifications];
}

- (void)dealloc
{
    [self.inboxListener remove];
    self.inboxListener = nil;
    if (self.authStateListenerHandle) {
        [[FIRAuth auth] removeAuthStateDidChangeListener:self.authStateListenerHandle];
        self.authStateListenerHandle = 0;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pp_handleRefreshNotification:(NSNotification *)notification
{
    (void)notification;
    [self reloadNotifications];
}

- (void)pp_handleLanguageNotification:(NSNotification *)notification
{
    (void)notification;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.stateView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar_QA" : @"en_QA"];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];
    self.tableView.refreshControl.accessibilityLabel = kLang(@"empty_retry_button") ?: @"";
    [self.stateRetryButton setTitle:(kLang(@"retry") ?: @"") forState:UIControlStateNormal];
    [self pp_renderInboxState:self.inboxState];
    [self.tableView reloadData];
}

- (void)pp_renderInboxState:(PPNotificationsInboxState)state
{
    self.inboxState = state;
    BOOL hasItems = self.items.count > 0;
    self.tableView.backgroundView.hidden = hasItems || state == PPNotificationsInboxStateContent;

    [self.stateActivityIndicator stopAnimating];
    self.stateIconView.hidden = NO;
    self.stateRetryButton.hidden = YES;

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:38.0
                                                        weight:UIImageSymbolWeightRegular];

    switch (state) {
        case PPNotificationsInboxStateLoading:
            self.stateIconView.hidden = YES;
            [self.stateActivityIndicator startAnimating];
            self.emptyTitleLabel.text = kLang(@"Loading") ?: @"";
            self.emptySubtitleLabel.text = kLang(@"notifications_hub_hero_notifications_subtitle") ?: @"";
            break;
        case PPNotificationsInboxStateError:
            self.stateIconView.image = [UIImage systemImageNamed:@"wifi.exclamationmark"
                                                withConfiguration:symbolConfig];
            self.stateIconView.tintColor = [UIColor ppAccentText];
            self.emptyTitleLabel.text = kLang(@"load_error_title") ?: @"";
            self.emptySubtitleLabel.text = kLang(@"connection_timeout_message") ?: (kLang(@"notifications_inbox_empty_subtitle") ?: @"");
            self.stateRetryButton.hidden = NO;
            break;
        case PPNotificationsInboxStateEmpty:
            self.stateIconView.image = [UIImage systemImageNamed:@"bell.slash"
                                                withConfiguration:symbolConfig];
            self.stateIconView.tintColor = [UIColor ppTextSecondary];
            self.emptyTitleLabel.text = kLang(@"notifications_inbox_empty_title") ?: @"";
            self.emptySubtitleLabel.text = kLang(@"notifications_inbox_empty_subtitle") ?: @"";
            break;
        case PPNotificationsInboxStateContent:
            break;
    }

    NSString *stateLabel = self.emptyTitleLabel.text ?: @"";
    self.stateView.accessibilityLabel = stateLabel;
    self.stateView.accessibilityElements = self.stateRetryButton.hidden
        ? @[self.emptyTitleLabel, self.emptySubtitleLabel]
        : @[self.emptyTitleLabel, self.emptySubtitleLabel, self.stateRetryButton];
}

- (void)reloadNotifications
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadNotifications];
        });
        return;
    }

    DLog(@"[NotificationsInbox] Reload started");
    [self.inboxListener remove];
    self.inboxListener = nil;
    NSString *uid = PPHubTrimmedString([FIRAuth auth].currentUser.uid);
    NSString *previousUID = self.observedUID ?: @"";
    if (![previousUID isEqualToString:uid]) {
        self.observedUID = uid;
        self.items = @[];
        [self.tableView reloadData];
    }

    NSUInteger generation = ++self.inboxLoadGeneration;
    if (self.items.count == 0) {
        [self pp_renderInboxState:PPNotificationsInboxStateLoading];
    }

    if (uid.length == 0) {
        [self.tableView.refreshControl endRefreshing];
        [self pp_renderInboxState:PPNotificationsInboxStateEmpty];
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *inboxCollection = [[[db collectionWithPath:@"UsersCol"]
                                                documentWithPath:uid]
                                               collectionWithPath:@"inbox"];
    FIRQuery *query = [[inboxCollection queryOrderedByField:@"createdAt" descending:YES] queryLimitedTo:50];

    __weak typeof(self) weakSelf = self;
    self.inboxListener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || generation != strongSelf.inboxLoadGeneration) return;

        if (error) {
            DLog(@"[NotificationsInbox] Read failed | domain=%@ code=%ld",
                 error.domain ?: @"",
                 (long)error.code);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (generation != strongSelf.inboxLoadGeneration) return;
                [strongSelf.tableView.refreshControl endRefreshing];
                if (strongSelf.items.count == 0) {
                    [strongSelf pp_renderInboxState:PPNotificationsInboxStateError];
                } else {
                    [strongSelf pp_renderInboxState:PPNotificationsInboxStateContent];
                    [PPHUD showInfo:kLang(@"load_error_title") ?: @""];
                }
            });
            return;
        }

        NSMutableArray<PPNotificationInboxItem *> *items = [NSMutableArray array];
        for (FIRDocumentSnapshot *document in snapshot.documents ?: @[]) {
            NSDictionary *payload = [document.data isKindOfClass:NSDictionary.class] ? document.data : @{};
            if (PPHubIsProviderOnlyNotificationPayload(payload)) {
                continue;
            }

            NSString *rawTitle = PPHubTrimmedString(payload[@"title"]);
            NSString *rawBody = PPHubTrimmedString(payload[@"body"]);
            NSString *title = PPHubLocalizedNotificationTitle(rawTitle, rawBody, payload);
            if (title.length == 0) {
                title = PPHubInboxCategoryTitle(payload);
            }

            NSString *subtitle = PPHubLocalizedNotificationBody(rawBody, rawTitle, payload);
            if (subtitle.length == 0) {
                subtitle = PPHubTrimmedString(payload[@"message"] ?: payload[@"status"]);
            }

            PPNotificationInboxItem *item = [PPNotificationInboxItem new];
            item.identifier = PPHubTrimmedString(payload[@"notificationId"] ?: document.documentID);
            item.documentID = PPHubTrimmedString(document.documentID);
            item.title = title;
            item.subtitle = subtitle;
            item.categoryTitle = PPHubInboxCategoryTitle(payload);
            item.symbolName = PPHubInboxSymbolName(payload);
            item.accentColor = PPHubInboxAccentColor(payload);
            item.timestamp = PPHubDateFromValue(payload[@"createdAt"] ?: payload[@"occurredAt"] ?: payload[@"updatedAt"]);
            item.payload = payload;
            item.isRead = [payload[@"isRead"] boolValue] || [payload[@"read"] boolValue];
            [items addObject:item];
        }

        [items sortUsingComparator:^NSComparisonResult(PPNotificationInboxItem *a, PPNotificationInboxItem *b) {
            NSDate *first = a.timestamp ?: [NSDate distantPast];
            NSDate *second = b.timestamp ?: [NSDate distantPast];
            return [second compare:first];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != strongSelf.inboxLoadGeneration) return;
            strongSelf.items = items.copy;
            [strongSelf.tableView reloadData];
            [strongSelf.tableView.refreshControl endRefreshing];
            [strongSelf pp_renderInboxState:strongSelf.items.count > 0
                ? PPNotificationsInboxStateContent
                : PPNotificationsInboxStateEmpty];
        });
    }];
}

- (void)markItemReadIfNeeded:(PPNotificationInboxItem *)item
{
    if (item.isRead || item.documentID.length == 0) return;

    NSString *uid = PPHubTrimmedString([FIRAuth auth].currentUser.uid);
    if (uid.length == 0) return;

    FIRDocumentReference *inboxRef = [[[[[FIRFirestore firestore] collectionWithPath:@"UsersCol"]
                                        documentWithPath:uid]
                                       collectionWithPath:@"inbox"]
                                       documentWithPath:item.documentID];
    __weak typeof(self) weakSelf = self;
    [inboxRef updateData:@{@"isRead": @YES} completion:^(NSError * _Nullable error) {
        if (error) {
            DLog(@"[NotificationsInbox] Read acknowledgement failed | domain=%@ code=%ld",
                 error.domain ?: @"",
                 (long)error.code);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            item.isRead = YES;
            [strongSelf.tableView reloadData];
        });
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPNotificationInboxCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPNotificationInboxCell" forIndexPath:indexPath];
    if (indexPath.row < (NSInteger)self.items.count) {
        [cell configureWithItem:self.items[indexPath.row] formatter:self.dateFormatter];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.items.count) return;

    PPNotificationInboxItem *item = self.items[indexPath.row];
    [self markItemReadIfNeeded:item];
    NSDictionary *payload = item.payload ?: @{};
    NSDictionary *meta = PPHubSafeDictionary(payload[@"meta"]);
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubOrderIDFromPayload(payload);
    NSString *type = PPHubNotificationType(payload, meta);
    NSLog(@"PPLAB NotificationsHub select start | type=%@ orderId=%@ threadID=%@",
          type ?: @"",
          orderID ?: @"",
          threadID ?: @"");

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        [[ChNotificationRouter shared] handleChatNotification:payload fromViewController:self];
        return;
    }

    if (orderID.length == 0 && ![type hasPrefix:@"order"]) {
        return;
    }

    if (orderID.length == 0) {
        [PPHUD showInfo:kLang(@"notifications_inbox_empty_subtitle") ?: @""];
        return;
    }

    FIRDocumentReference *orderRef = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    __weak typeof(self) weakSelf = self;
    [orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !snapshot.exists) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @""];
                return;
            }

            PPOrder *order = [PPOrder orderFromSnapshot:snapshot];
            if (!order) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @""];
                return;
            }

            UIViewController *detailsVC = [PPOrderDetailsRouter controllerWithOrder:order];
            [strongSelf.navigationController pushViewController:detailsVC animated:YES];
        });
    }];
}

@end

@interface PPNotificationsHubViewController ()
@property (nonatomic, strong) UIView *heroContainerView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) PPHubTopTabsView *tabsView;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *contentContainerView;
@property (nonatomic, strong) UIViewController *activeChild;
@property (nonatomic, strong) NSArray<UIViewController *> *childControllers;
@property (nonatomic, strong) PPPetRemindersViewController *remindersVC;
@property (nonatomic, strong) UserChatsViewController *chatsVC;
@property (nonatomic, strong) PPNotificationsInboxViewController *notificationsVC;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, assign) BOOL didPlayHeroEntrance;
@property (nonatomic, assign) BOOL hasStoredPreviousNavigationBarHidden;
@property (nonatomic, assign) BOOL previousNavigationBarHidden;
@end

@implementation PPNotificationsHubViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.selectedIndex = 0;

    self.chatsVC = [UserChatsViewController new];
    self.chatsVC.shouldHideStories = YES;
    self.remindersVC = [PPPetRemindersViewController new];
    self.notificationsVC = [PPNotificationsInboxViewController new];
    self.childControllers = @[self.chatsVC, self.remindersVC, self.notificationsVC];

    [self pp_setupNavigationChrome];
    [self pp_setupBackdrop];
    [self pp_setupTopChrome];
    [self pp_setupContentContainer];
    [self pp_showChildAtIndex:self.selectedIndex animated:NO];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageNotification:)
                                                 name:@"LanguageDidChangeNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageNotification:)
                                                 name:PPLanguageDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!self.hasStoredPreviousNavigationBarHidden) {
        self.previousNavigationBarHidden = self.navigationController.navigationBarHidden;
        self.hasStoredPreviousNavigationBarHidden = YES;
    }
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self pp_setupNavigationChrome];
    [self pp_applyNavigationItems];
    [self pp_refreshActionButtonForIndex:self.selectedIndex];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_playHeroEntranceIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.hasStoredPreviousNavigationBarHidden) {
        [self.navigationController setNavigationBarHidden:self.previousNavigationBarHidden animated:animated];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
}

#pragma mark - Setup

- (void)pp_setupNavigationChrome
{
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:nil showBack:NO];
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)pp_setupBackdrop
{
    self.view.backgroundColor = [UIColor ppBackground];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            self.view.backgroundColor = [UIColor ppBackground];
        }
    }
}

- (void)pp_handleLanguageNotification:(NSNotification *)notification
{
    (void)notification;
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    NSTextAlignment alignment = [Language alignmentForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
    self.heroContainerView.semanticContentAttribute = semantic;
    self.heroSurfaceView.semanticContentAttribute = semantic;
    self.contentContainerView.semanticContentAttribute = semantic;
    self.heroEyebrowLabel.semanticContentAttribute = semantic;
    self.heroTitleLabel.semanticContentAttribute = semantic;
    self.heroSubtitleLabel.semanticContentAttribute = semantic;
    self.heroEyebrowLabel.textAlignment = alignment;
    self.heroTitleLabel.textAlignment = alignment;
    self.heroSubtitleLabel.textAlignment = alignment;
    self.heroEyebrowLabel.text = kLang(@"notifications_hub_hero_eyebrow") ?: @"";
    [self.tabsView updateTitles:@[
        kLang(@"pet_chats_tab") ?: @"",
        kLang(@"pet_reminders_tab") ?: @"",
        kLang(@"notifications_inbox_tab") ?: @""
    ]];
    [self.tabsView selectIndex:self.selectedIndex animated:NO];
    [self pp_refreshHeroTextForIndex:self.selectedIndex animated:NO];
    [self pp_refreshActionButtonForIndex:self.selectedIndex];
}

- (void)pp_setupTopChrome
{
    if (self.heroContainerView) return;

    self.heroContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContainerView.backgroundColor = UIColor.clearColor;
    self.heroContainerView.clipsToBounds = YES;
    self.heroContainerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:self.heroContainerView];

    self.heroSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = [UIColor ppBackground];
    self.heroSurfaceView.layer.masksToBounds = YES;
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroContainerView addSubview:self.heroSurfaceView];

    self.heroEyebrowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *eyebrowBaseFont = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.heroEyebrowLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:eyebrowBaseFont];
    self.heroEyebrowLabel.adjustsFontForContentSizeCategory = YES;
    self.heroEyebrowLabel.textColor = [UIColor ppAccentText];
    self.heroEyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.heroEyebrowLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroEyebrowLabel.text = kLang(@"notifications_hub_hero_eyebrow");
    [self.heroSurfaceView addSubview:self.heroEyebrowLabel];

    self.heroTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *titleBaseFont = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    self.heroTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle] scaledFontForFont:titleBaseFont];
    self.heroTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.heroTitleLabel.textColor = [UIColor ppTextPrimary];
    self.heroTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.heroTitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroTitleLabel.numberOfLines = 2;
    self.heroTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.heroSurfaceView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *subtitleBaseFont = [GM MidFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightRegular];
    self.heroSubtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:subtitleBaseFont];
    self.heroSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.heroSubtitleLabel.textColor = [UIColor ppTextSecondary];
    self.heroSubtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.heroSubtitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSubtitleLabel.numberOfLines = 0;
    [self.heroSurfaceView addSubview:self.heroSubtitleLabel];

    // This header and the child-content container share the available vertical
    // space. Without an intrinsic-height preference, any multiline label may
    // expand to consume that space and push the tabs/list below the viewport.
    // Keep the text chain at its natural Dynamic Type height; the child content
    // receives the remaining room.
    for (UILabel *label in @[self.heroEyebrowLabel, self.heroTitleLabel, self.heroSubtitleLabel]) {
        [label setContentHuggingPriority:UILayoutPriorityRequired
                                forAxis:UILayoutConstraintAxisVertical];
        [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisVertical];
    }

    NSArray<NSString *> *titles = @[
        (kLang(@"pet_chats_tab") ?: @""),
        (kLang(@"pet_reminders_tab") ?: @""),
        (kLang(@"notifications_inbox_tab") ?: @"")
    ];
    NSArray<NSString *> *icons = @[
        @"ellipsis.message.fill",
        @"bell.badge.fill",
        @"app.badge.fill"
    ];
    self.tabsView = [[PPHubTopTabsView alloc] initWithTitles:titles icons:icons];
    __weak typeof(self) weakSelf = self;
    self.tabsView.onSelectionChanged = ^(NSInteger index) {
        [weakSelf pp_showChildAtIndex:index animated:YES];
    };
    [self.heroSurfaceView addSubview:self.tabsView];

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.backgroundColor = [UIColor ppSurface];
    self.actionButton.tintColor = [UIColor ppPrimary];
    self.actionButton.layer.cornerRadius = PPCorner16;
    self.actionButton.clipsToBounds = YES;
    self.actionButton.layer.borderWidth = 0.75;
    [self.actionButton pp_setBorderColor:[UIColor ppBorder]];
    self.actionButton.accessibilityHint = kLang(@"empty_retry_button") ?: @"";
    if (@available(iOS 13.0, *)) {
        self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.actionButton addTarget:self action:@selector(pp_handleActionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.heroSurfaceView addSubview:self.actionButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor],
        [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor],

        [self.actionButton.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:PPSpaceXS],
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.actionButton.widthAnchor constraintEqualToConstant:kPPHubActionButtonSize],
        [self.actionButton.heightAnchor constraintEqualToConstant:kPPHubActionButtonSize],

        [self.heroEyebrowLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:PPSpaceXS],
        [self.heroEyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.heroEyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.actionButton.leadingAnchor constant:-12.0],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:self.heroEyebrowLabel.bottomAnchor constant:PPSpaceXXS],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroEyebrowLabel.leadingAnchor],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor constant:-12.0],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:PPSpaceXS],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroEyebrowLabel.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor constant:-12.0],

        [self.tabsView.topAnchor constraintEqualToAnchor:self.heroSubtitleLabel.bottomAnchor constant:PPSpaceMD],
        [self.tabsView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.tabsView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.tabsView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-PPSpaceSM],
        [self.tabsView.heightAnchor constraintEqualToConstant:kPPHubTopBarHeight],
    ]];

    self.heroContainerView.alpha = 0.0;
    self.heroContainerView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);

    [self pp_refreshHeroTextForIndex:self.selectedIndex animated:NO];
    [self pp_applyNavigationItems];
}

- (void)pp_setupContentContainer
{
    self.contentContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentContainerView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.contentContainerView];

    NSLayoutConstraint *minimumContentHeight =
        [self.contentContainerView.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin];
    minimumContentHeight.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.heroContainerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                                         constant:kPPHubHeroTopInset],
        [self.heroContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor
                                                             constant:kPPHubHeroHorizontalInset],
        [self.heroContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                              constant:-kPPHubHeroHorizontalInset],

        [self.contentContainerView.topAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor
                                                            constant:kPPHubContentTopGap],
        [self.contentContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        minimumContentHeight,
    ]];
}

- (void)pp_applyNavigationItems
{
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

#pragma mark - Hero

- (NSString *)pp_heroTitleForIndex:(NSInteger)index
{
    switch (index) {
        case 0:
            return kLang(@"pet_chats_tab") ?: @"";
        case 1:
            return kLang(@"pet_reminders_tab") ?: @"";
        case 2:
        default:
            return kLang(@"notifications_inbox_tab") ?: @"";
    }
}

- (NSString *)pp_heroSubtitleForIndex:(NSInteger)index
{
    switch (index) {
        case 0:
            return kLang(@"notifications_hub_hero_chats_subtitle_no_stories");
        case 1:
            return kLang(@"notifications_hub_hero_reminders_subtitle");
        case 2:
        default:
            return kLang(@"notifications_hub_hero_notifications_subtitle");
    }
}

- (void)pp_refreshHeroTextForIndex:(NSInteger)index animated:(BOOL)animated
{
    if (!self.heroTitleLabel || !self.heroSubtitleLabel) return;

    NSString *title = [self pp_heroTitleForIndex:index] ?: @"";
    NSString *subtitle = [self pp_heroSubtitleForIndex:index] ?: @"";

    void (^updates)(void) = ^{
        self.heroTitleLabel.text = title;
        self.heroSubtitleLabel.text = subtitle;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled() || self.heroTitleLabel.text.length == 0) {
        updates();
        return;
    }

    [UIView transitionWithView:self.heroSurfaceView
                      duration:0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:updates
                    completion:nil];
}

- (void)pp_playHeroEntranceIfNeeded
{
    if (self.didPlayHeroEntrance || !self.heroContainerView) return;
    self.didPlayHeroEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroContainerView.alpha = 1.0;
        self.heroContainerView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.02
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.24
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroContainerView.alpha = 1.0;
        self.heroContainerView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Child Flow

- (void)pp_installChildView:(UIView *)childView
{
    if (!childView) return;
    childView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainerView addSubview:childView];
    [NSLayoutConstraint activateConstraints:@[
        [childView.topAnchor constraintEqualToAnchor:self.contentContainerView.topAnchor],
        [childView.leadingAnchor constraintEqualToAnchor:self.contentContainerView.leadingAnchor],
        [childView.trailingAnchor constraintEqualToAnchor:self.contentContainerView.trailingAnchor],
        [childView.bottomAnchor constraintEqualToAnchor:self.contentContainerView.bottomAnchor],
    ]];
}

- (void)pp_showChildAtIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < 0 || index >= (NSInteger)self.childControllers.count) return;
    BOOL shouldAnimate = animated && !UIAccessibilityIsReduceMotionEnabled();

    UIViewController *nextChild = self.childControllers[index];
    if (self.activeChild == nextChild) {
        self.selectedIndex = index;
        [self pp_refreshActionButtonForIndex:index];
        [self pp_refreshHeroTextForIndex:index animated:shouldAnimate];
        [self.tabsView selectIndex:index animated:shouldAnimate];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
        return;
    }

    UIViewController *previousChild = self.activeChild;
    self.selectedIndex = index;
    [self.tabsView selectIndex:index animated:shouldAnimate];
    [self pp_refreshHeroTextForIndex:index animated:shouldAnimate];

    if (previousChild) {
        [previousChild willMoveToParentViewController:nil];
    }

    [self addChildViewController:nextChild];

    if (!shouldAnimate || !previousChild) {
        [previousChild.view removeFromSuperview];
        [previousChild removeFromParentViewController];
        [self pp_installChildView:nextChild.view];
        [nextChild didMoveToParentViewController:self];
        self.activeChild = nextChild;
        [self pp_refreshActionButtonForIndex:index];
        [self pp_refreshHeroTextForIndex:index animated:shouldAnimate];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
        return;
    }

    nextChild.view.alpha = 0.0;
    nextChild.view.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [self pp_installChildView:nextChild.view];

    [UIView animateWithDuration:0.26
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowAnimatedContent
                     animations:^{
        previousChild.view.alpha = 0.0;
        previousChild.view.transform = CGAffineTransformMakeTranslation(0.0, -8.0);
        nextChild.view.alpha = 1.0;
        nextChild.view.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [previousChild.view removeFromSuperview];
        previousChild.view.alpha = 1.0;
        previousChild.view.transform = CGAffineTransformIdentity;
        [previousChild removeFromParentViewController];
        [nextChild didMoveToParentViewController:self];
        self.activeChild = nextChild;
        [self pp_refreshActionButtonForIndex:index];
        [self pp_refreshHeroTextForIndex:index animated:shouldAnimate];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
    }];
}

- (void)pp_refreshActionButtonForIndex:(NSInteger)index
{
    NSString *symbolName = @"arrow.clockwise";
    NSString *accessibilityLabel = kLang(@"empty_retry_button") ?: @"";
    BOOL enabled = YES;

    switch (index) {
        case 0:
            symbolName = @"square.and.pencil";
            accessibilityLabel = kLang(@"empty_chats_button") ?: @"";
            enabled = [self.chatsVC respondsToSelector:@selector(startNewChat)];
            break;
        case 1:
            symbolName = @"plus";
            accessibilityLabel = kLang(@"pet_reminder_add") ?: @"";
            enabled = [self.remindersVC respondsToSelector:@selector(pp_addReminder)];
            break;
        case 2:
        default:
            symbolName = @"arrow.clockwise";
            accessibilityLabel = kLang(@"empty_retry_button") ?: @"";
            enabled = YES;
            break;
    }

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:symCfg];

    self.actionButton.configuration = nil;
    [self.actionButton setImage:image forState:UIControlStateNormal];

    self.actionButton.accessibilityLabel = accessibilityLabel;
    self.actionButton.enabled = enabled;
    self.actionButton.alpha = enabled ? 1.0 : 0.45;
}

- (void)pp_handleActionButtonTapped
{
    switch (self.selectedIndex) {
        case 0:
            [self pp_invokeAction:@selector(startNewChat) onTarget:self.chatsVC];
            break;
        case 1:
            [self pp_invokeAction:@selector(pp_addReminder) onTarget:self.remindersVC];
            break;
        case 2:
        default:
            [self.notificationsVC reloadNotifications];
            break;
    }
}

- (void)pp_invokeAction:(SEL)selector onTarget:(id)target
{
    if (!target || ![target respondsToSelector:selector]) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [target performSelector:selector];
#pragma clang diagnostic pop
}

@end
