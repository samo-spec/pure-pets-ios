//
//  PPNotificationsHubViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//

#import "PPNotificationsHubViewController.h"
#import "PPPetRemindersViewController.h"
#import "UserChatsViewController.h"
#import "OrderDetailsViewController.h"
#import "PPOrder.h"
#import "ChNotificationRouter.h"
#import "AppClasses.h"
#import "Language.h"
@import FirebaseFirestore;
@import UserNotifications;

static CGFloat const kPPHubTopBarHeight = 46.0;
static CGFloat const kPPHubActionButtonSize = 44.0;

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
    NSString *status = PPHubFirstStringForKeys(payload, @[@"status", @"paymentStatus", @"deliveryStatus"]);
    if (status.length == 0) {
        status = PPHubFirstStringForKeys(meta, @[@"status", @"paymentStatus", @"deliveryStatus"]);
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
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubTrimmedString(payload[@"orderId"]);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return kLang(@"notifications_inbox_category_chat") ?: @"Chats";
    }
    if (orderID.length > 0 || [type hasPrefix:@"order"]) {
        return kLang(@"notifications_inbox_category_orders") ?: @"Orders";
    }
    return kLang(@"notifications_inbox_category_updates") ?: @"Updates";
}

static UIColor *PPHubInboxAccentColor(NSDictionary *payload)
{
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *status = [[PPHubTrimmedString(payload[@"status"]) lowercaseString] copy];
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return [GM appPrimaryColor];
    }
    if ([status containsString:@"deliver"] || [status containsString:@"paid"]) {
        return UIColor.systemGreenColor;
    }
    if ([status containsString:@"ship"]) {
        return UIColor.systemBlueColor;
    }
    if ([status containsString:@"fail"] || [status containsString:@"cancel"]) {
        return UIColor.systemRedColor;
    }
    return UIColor.systemOrangeColor;
}

static NSString *PPHubInboxSymbolName(NSDictionary *payload)
{
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubTrimmedString(payload[@"orderId"]);
    NSString *status = [[PPHubTrimmedString(payload[@"status"]) lowercaseString] copy];

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
@property (nonatomic, strong) UIButton *contentClipView;
@property (nonatomic, strong) UIView *selectionIndicator;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, strong) NSLayoutConstraint *indicatorLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *indicatorWidthConstraint;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) void (^onSelectionChanged)(NSInteger index);
- (instancetype)initWithTitles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons;
- (void)selectIndex:(NSInteger)index animated:(BOOL)animated;
@end

@implementation PPHubTopTabsView

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;

    _surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0 : 0];
    _surfaceView.layer.cornerRadius = 28.0;
    _surfaceView.layer.masksToBounds = NO;
    _surfaceView.layer.borderWidth = 0.0;
     [_surfaceView pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:0.20]];
    _surfaceView.layer.shadowOpacity = 0.12;
    _surfaceView.layer.shadowRadius = 14.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:_surfaceView];

    // Content clip view — clips indicator within rounded corners while surface keeps shadow
    _contentClipView =   [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule configType:PPButtonConfigrationGlass];
    _contentClipView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentClipView.backgroundColor = UIColor.clearColor;
     _contentClipView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _contentClipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_contentClipView];

    _selectionIndicator = [[UIView alloc] initWithFrame:CGRectZero];
    _selectionIndicator.translatesAutoresizingMaskIntoConstraints = NO;

    _selectionIndicator.backgroundColor = AppClearClr;// brand;
    _selectionIndicator.layer.cornerRadius = 22.0;
    _selectionIndicator.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _selectionIndicator.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_contentClipView addSubview:_selectionIndicator];

    UIStackView *stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.spacing = 0.0;
    [_contentClipView addSubview:stackView];

    UIImageSymbolConfiguration *symbolConfig = nil;
    if (@available(iOS 13.0, *)) {
        symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    }

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSUInteger count = MIN(titles.count, icons.count);
    for (NSUInteger index = 0; index < count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = (NSInteger)index;
        button.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.72;
        button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 8.0, 0.0, 8.0);

        UIImage *image = nil;
        if (@available(iOS 13.0, *)) {
            image = [[UIImage systemImageNamed:icons[index] withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            image = [UIImage imageNamed:icons[index]];
        }
        [button setImage:image forState:UIControlStateNormal];
        [button setTitle:[NSString stringWithFormat:@"  %@", titles[index]] forState:UIControlStateNormal];
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

        [self.contentClipView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.contentClipView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.contentClipView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.contentClipView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        self.indicatorLeadingConstraint,
        [self.selectionIndicator.topAnchor constraintEqualToAnchor:self.contentClipView.topAnchor constant:2.0],
        [self.selectionIndicator.bottomAnchor constraintEqualToAnchor:self.contentClipView.bottomAnchor constant:-2.0],
        self.indicatorWidthConstraint,

        [stackView.topAnchor constraintEqualToAnchor:self.contentClipView.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:self.contentClipView.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.contentClipView.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.contentClipView.bottomAnchor],
    ]];

    self.selectedIndex = NSNotFound;
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                                         cornerRadius:self.surfaceView.layer.cornerRadius];
    self.surfaceView.layer.shadowPath = shadowPath.CGPath;

    if (self.selectedIndex != NSNotFound) {
        [self pp_updateSelectionIndicatorForIndex:self.selectedIndex animated:NO];
    }
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < 0 || index >= (NSInteger)self.tabButtons.count) return;
    self.selectedIndex = index;
    [self pp_updateSelectionIndicatorForIndex:index animated:animated];
    [self pp_refreshButtonAppearance];
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
    CGFloat containerWidth = CGRectGetWidth(self.surfaceView.bounds);
    if (containerWidth <= 0.0 || self.tabButtons.count == 0) return;

    CGFloat tabWidth = floor(containerWidth / (CGFloat)self.tabButtons.count);
    CGFloat width = MAX(68.0, tabWidth - 10.0);
    CGFloat leading = (tabWidth * (CGFloat)index) + ((tabWidth - width) * 0.5);

    self.indicatorLeadingConstraint.constant = leading;
    self.indicatorWidthConstraint.constant = width;

    void (^animations)(void) = ^{
        [self.surfaceView layoutIfNeeded];
    };

    if (!animated) {
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
    UIColor *inactiveColor = AppSecondaryTextClr;
    for (NSInteger index = 0; index < (NSInteger)self.tabButtons.count; index++) {
        BOOL isSelected = (index == self.selectedIndex);
        UIButton *button = self.tabButtons[index];
        UIColor *titleColor = isSelected ? AppPrimaryClr : inactiveColor;
        button.tintColor = titleColor;
        [button setTitleColor:titleColor forState:UIControlStateNormal];
        button.alpha = isSelected ? 1.0 : 0.92;
    }
}

@end

@interface PPNotificationInboxItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *categoryTitle;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, copy) NSDictionary *payload;
@end

@implementation PPNotificationInboxItem
@end

@interface PPNotificationInboxCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
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

    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.82 : 0.96];
    _cardView.layer.cornerRadius = 24.0;
    _cardView.layer.masksToBounds = NO;
    [_cardView pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:0.16]];
    _cardView.layer.shadowOpacity = 0.10;
    _cardView.layer.shadowRadius = 14.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:_cardView];

    _iconContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    _iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconContainerView.layer.cornerRadius = 20.0;
    _iconContainerView.layer.masksToBounds = YES;
    [_cardView addSubview:_iconContainerView];

    _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconContainerView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:16.0];
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.numberOfLines = 2;
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:13.0];
    _subtitleLabel.textColor = UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 2;
    [_cardView addSubview:_subtitleLabel];

    _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.font = [GM MidFontWithSize:12.0];
    _metaLabel.textColor = UIColor.tertiaryLabelColor;
    _metaLabel.numberOfLines = 1;
    [_cardView addSubview:_metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16.0],
        [self.iconContainerView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:40.0],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:40.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:18.0],
        [self.iconView.heightAnchor constraintEqualToConstant:18.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:16.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:14.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.metaLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:8.0],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.metaLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-16.0],
    ]];

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
}

- (void)configureWithItem:(PPNotificationInboxItem *)item formatter:(NSDateFormatter *)formatter
{
    self.titleLabel.text = item.title ?: @"";
    self.subtitleLabel.text = item.subtitle ?: @"";
    NSString *dateText = @"";
    if ([item.timestamp isKindOfClass:NSDate.class]) {
        dateText = [formatter stringFromDate:item.timestamp] ?: @"";
    }
    if (dateText.length > 0 && item.categoryTitle.length > 0) {
        self.metaLabel.text = [NSString stringWithFormat:@"%@ • %@", item.categoryTitle, dateText];
    } else {
        self.metaLabel.text = item.categoryTitle.length > 0 ? item.categoryTitle : dateText;
    }

    UIColor *accent = item.accentColor ?: [GM appPrimaryColor] ?: UIColor.systemOrangeColor;
    self.iconContainerView.backgroundColor = [accent colorWithAlphaComponent:0.14];
    self.iconView.tintColor = accent;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
        self.iconView.image = [UIImage systemImageNamed:item.symbolName ?: @"bell.fill" withConfiguration:config];
    } else {
        self.iconView.image = [UIImage imageNamed:item.symbolName ?: @"bell.fill"];
    }
}

@end

@interface PPNotificationsInboxViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) NSArray<PPNotificationInboxItem *> *items;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
- (void)reloadNotifications;
@end

@implementation PPNotificationsInboxViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.items = @[];

    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    }
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = 100.0;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsMake(8.0, 0.0, 32.0, 0.0);
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:PPNotificationInboxCell.class forCellReuseIdentifier:@"PPNotificationInboxCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIView *emptyView = [[UIView alloc] initWithFrame:CGRectZero];
    emptyView.backgroundColor = UIColor.clearColor;

    UIImageView *emptyIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    emptyIconView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIconView.tintColor = UIColor.secondaryLabelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:42.0 weight:UIImageSymbolWeightRegular];
        emptyIconView.image = [UIImage systemImageNamed:@"bell.slash.fill" withConfiguration:config];
    }
    [emptyView addSubview:emptyIconView];

    self.emptyTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyTitleLabel.font = [GM boldFontWithSize:20.0];
    self.emptyTitleLabel.textColor = UIColor.labelColor;
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.text = kLang(@"notifications_inbox_empty_title") ?: @"No notifications yet";
    [emptyView addSubview:self.emptyTitleLabel];

    self.emptySubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptySubtitleLabel.font = [GM MidFontWithSize:14.0];
    self.emptySubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.numberOfLines = 0;
    self.emptySubtitleLabel.text = kLang(@"notifications_inbox_empty_subtitle") ?: @"Order updates and chat alerts will show up here.";
    [emptyView addSubview:self.emptySubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [emptyIconView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [emptyIconView.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:-38.0],

        [self.emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIconView.bottomAnchor constant:16.0],
        [self.emptyTitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:28.0],
        [self.emptyTitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-28.0],

        [self.emptySubtitleLabel.topAnchor constraintEqualToAnchor:self.emptyTitleLabel.bottomAnchor constant:8.0],
        [self.emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:34.0],
        [self.emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-34.0],
    ]];
    self.tableView.backgroundView = emptyView;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:@"PPRemoteNotificationTapped"
                                               object:nil];

    [self reloadNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pp_handleRefreshNotification:(NSNotification *)notification
{
    (void)notification;
    [self reloadNotifications];
}

- (void)reloadNotifications
{
    __weak typeof(self) weakSelf = self;
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        NSMutableArray<PPNotificationInboxItem *> *items = [NSMutableArray array];
        for (UNNotification *notification in notifications ?: @[]) {
            UNNotificationContent *content = notification.request.content;
            NSDictionary *payload = [content.userInfo isKindOfClass:NSDictionary.class] ? content.userInfo : @{};

            NSString *rawTitle = PPHubTrimmedString(content.title);
            NSString *title = PPHubLocalizedNotificationTitle(rawTitle, PPHubTrimmedString(content.body), payload);
            if (title.length == 0) {
                title = PPHubInboxCategoryTitle(payload);
            }

            NSString *rawSubtitle = PPHubTrimmedString(content.body);
            NSString *subtitle = PPHubLocalizedNotificationBody(rawSubtitle, rawTitle, payload);
            if (subtitle.length == 0) {
                subtitle = PPHubTrimmedString(payload[@"message"] ?: payload[@"status"]);
            }

            PPNotificationInboxItem *item = [PPNotificationInboxItem new];
            item.identifier = PPHubTrimmedString(notification.request.identifier);
            item.title = title;
            item.subtitle = subtitle;
            item.categoryTitle = PPHubInboxCategoryTitle(payload);
            item.symbolName = PPHubInboxSymbolName(payload);
            item.accentColor = PPHubInboxAccentColor(payload);
            item.timestamp = notification.date;
            item.payload = payload;
            [items addObject:item];
        }

        [items sortUsingComparator:^NSComparisonResult(PPNotificationInboxItem *a, PPNotificationInboxItem *b) {
            NSDate *first = a.timestamp ?: [NSDate distantPast];
            NSDate *second = b.timestamp ?: [NSDate distantPast];
            return [second compare:first];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.items = items.copy;
            [strongSelf.tableView reloadData];
            strongSelf.tableView.backgroundView.hidden = (strongSelf.items.count > 0);
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
    NSDictionary *payload = item.payload ?: @{};
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubTrimmedString(payload[@"orderId"]);
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        [[ChNotificationRouter shared] handleChatNotification:payload fromViewController:self];
        return;
    }

    if (orderID.length == 0 && ![type hasPrefix:@"order"]) {
        return;
    }

    if (orderID.length == 0) {
        [PPHUD showInfo:kLang(@"notifications_inbox_empty_subtitle") ?: @"Notifications"];
        return;
    }

    FIRDocumentReference *orderRef = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    __weak typeof(self) weakSelf = self;
    [orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !snapshot.exists) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order data is unavailable right now."];
                return;
            }

            PPOrder *order = [PPOrder orderFromSnapshot:snapshot];
            if (!order) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order data is unavailable right now."];
                return;
            }

            OrderDetailsViewController *detailsVC = [[OrderDetailsViewController alloc] initWithOrder:order];
            detailsVC.order = order;
            [strongSelf.navigationController pushViewController:detailsVC animated:YES];
        });
    }];
}

@end

@interface PPNotificationsHubViewController ()
@property (nonatomic, strong) UIView *backgroundTopGlowView;
@property (nonatomic, strong) UIView *backgroundMidGlowView;
@property (nonatomic, strong) UIView *backgroundBottomGlowView;
@property (nonatomic, strong) UIView *topChromeContainerView;
@property (nonatomic, strong) PPHubTopTabsView *tabsView;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *contentContainerView;
@property (nonatomic, strong) UIViewController *activeChild;
@property (nonatomic, strong) NSArray<UIViewController *> *childControllers;
@property (nonatomic, strong) PPPetRemindersViewController *remindersVC;
@property (nonatomic, strong) UserChatsViewController *chatsVC;
@property (nonatomic, strong) PPNotificationsInboxViewController *notificationsVC;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation PPNotificationsHubViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = AppPageColor();
    self.selectedIndex = 0;

    self.chatsVC = [UserChatsViewController new];
    self.remindersVC = [PPPetRemindersViewController new];
    self.notificationsVC = [PPNotificationsInboxViewController new];
    self.childControllers = @[self.chatsVC, self.remindersVC, self.notificationsVC];

    [self pp_setupNavigationChrome];
    [self pp_setupBackdrop];
    [self pp_setupTopChrome];
    [self pp_setupContentContainer];
    [self pp_showChildAtIndex:self.selectedIndex animated:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_setupNavigationChrome];
    [self pp_applyNavigationItems];
    [self pp_refreshActionButtonForIndex:self.selectedIndex];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;

    CGFloat topSize = MIN(360.0, MAX(248.0, width * 0.74));
    CGFloat midSize = MIN(300.0, MAX(210.0, width * 0.58));
    CGFloat bottomSize = MIN(340.0, MAX(220.0, width * 0.66));

    self.backgroundTopGlowView.frame = CGRectMake(width - (topSize * 0.62),
                                                  safeTop - (topSize * 0.72),
                                                  topSize, topSize);

    self.backgroundMidGlowView.frame = CGRectMake(-(midSize * 0.44),
                                                  MAX(112.0, height * 0.28),
                                                  midSize, midSize);

    self.backgroundBottomGlowView.frame = CGRectMake(width - (bottomSize * 0.56),
                                                     height - (bottomSize * 0.62),
                                                     bottomSize, bottomSize);

    NSArray<UIView *> *glowViews = @[
        self.backgroundTopGlowView,
        self.backgroundMidGlowView,
        self.backgroundBottomGlowView
    ];

    for (UIView *glowView in glowViews) {
        CGFloat radius = CGRectGetWidth(glowView.bounds) * 0.5;
        glowView.layer.cornerRadius = radius;
        glowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:glowView.bounds].CGPath;
    }
    self.backgroundMidGlowView.alpha = 0.5;

    CGFloat chromeWidth = floor(width * 0.90);
    self.topChromeContainerView.frame = CGRectMake(0.0, 0.0, chromeWidth, kPPHubTopBarHeight);
    self.actionButton.frame = CGRectMake(0.0, 0.0, kPPHubActionButtonSize, kPPHubActionButtonSize);
    [self pp_applyNavigationItems];

    self.contentContainerView.frame = self.view.bounds;
    self.activeChild.view.frame = self.contentContainerView.bounds;
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
    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    self.backgroundTopGlowView.clipsToBounds = NO;
    self.backgroundTopGlowView.layer.masksToBounds = NO;
    self.backgroundTopGlowView.layer.shadowOffset = CGSizeZero;
    [self.view insertSubview:self.backgroundTopGlowView atIndex:0];

    self.backgroundMidGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundMidGlowView.userInteractionEnabled = NO;
    self.backgroundMidGlowView.clipsToBounds = NO;
    self.backgroundMidGlowView.layer.masksToBounds = NO;
    self.backgroundMidGlowView.layer.shadowOffset = CGSizeZero;
    self.backgroundMidGlowView.alpha = 0.5;
    [self.view insertSubview:self.backgroundMidGlowView atIndex:0];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    self.backgroundBottomGlowView.clipsToBounds = NO;
    self.backgroundBottomGlowView.layer.masksToBounds = NO;
    self.backgroundBottomGlowView.layer.shadowOffset = CGSizeZero;
    [self.view insertSubview:self.backgroundBottomGlowView atIndex:0];

    [self pp_updateGlowAppearance];
}

- (void)pp_updateGlowAppearance
{
    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    UIColor *primaryColor = NewBgColor ?: AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *secondaryColor = AppPrimaryClr ?: [primaryColor colorWithAlphaComponent:1.0];
    UIColor *bottomFadeColor = isDark
        ? UIColor.blackColor
        : [UIColor colorWithRed:0.98 green:0.66 blue:0.46 alpha:1.0];

    [self pp_applyGlowView:self.backgroundTopGlowView
                    color:AppSurfColor
             surfaceAlpha:isDark ? 0.13 : 0.075
            shadowOpacity:isDark ? 0.16f : 0.10f
             shadowRadius:isDark ? 82.0 : 74.0];

    [self pp_applyGlowView:self.backgroundMidGlowView
                    color:secondaryColor
             surfaceAlpha:isDark ? 0.10 : 0.055
            shadowOpacity:isDark ? 0.12f : 0.075f
             shadowRadius:isDark ? 72.0 : 64.0];

    [self pp_applyGlowView:self.backgroundBottomGlowView
                    color:bottomFadeColor
             surfaceAlpha:isDark ? 0.030 : 0.050
            shadowOpacity:isDark ? 0.08f : 0.045f
             shadowRadius:isDark ? 62.0 : 54.0];
}

- (void)pp_applyGlowView:(UIView *)glowView
                   color:(UIColor *)color
            surfaceAlpha:(CGFloat)surfaceAlpha
           shadowOpacity:(CGFloat)shadowOpacity
            shadowRadius:(CGFloat)shadowRadius
{
    if (!glowView || !color) return;

    glowView.alpha = 1.0;
    glowView.backgroundColor = [color colorWithAlphaComponent:surfaceAlpha];
    glowView.layer.shadowColor = AppClearClr.CGColor;
    glowView.layer.shadowOpacity = 0;
    glowView.layer.shadowRadius = 0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self pp_updateGlowAppearance];
            self.view.backgroundColor = AppSurfColor;
        }
    }
}

- (void)pp_setupTopChrome
{
    CGFloat initialWidth = floor(CGRectGetWidth(self.view.bounds) * 0.95);
    self.topChromeContainerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, initialWidth, kPPHubTopBarHeight)];
    self.topChromeContainerView.backgroundColor = UIColor.clearColor;

    NSArray<NSString *> *titles = @[
        (kLang(@"pet_chats_tab") ?: @"Chats"),
        (kLang(@"pet_reminders_tab") ?: @"Reminders"),
        (kLang(@"notifications_inbox_tab") ?: @"Notifications")
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
    [self.topChromeContainerView addSubview:self.tabsView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tabsView.topAnchor constraintEqualToAnchor:self.topChromeContainerView.topAnchor],
        [self.tabsView.leadingAnchor constraintEqualToAnchor:self.topChromeContainerView.leadingAnchor],
        [self.tabsView.trailingAnchor constraintEqualToAnchor:self.topChromeContainerView.trailingAnchor],
        [self.tabsView.bottomAnchor constraintEqualToAnchor:self.topChromeContainerView.bottomAnchor],
    ]];

    
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration glassButtonConfiguration];
        
        self.actionButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
    } else {
        self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
   
    }

    
    self.actionButton.frame = CGRectMake(0.0, 0.0, kPPHubActionButtonSize, kPPHubActionButtonSize);
    self.actionButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.0 : 0.96];
    self.actionButton.tintColor = [GM appPrimaryColor];
    self.actionButton.layer.cornerRadius = kPPHubActionButtonSize * 0.5;
    self.actionButton.clipsToBounds = NO;
    self.actionButton.layer.borderWidth = 1.0;
    if(!PPIOS26())
    {
        [self.actionButton pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.14]];
    }
    
    [self.actionButton pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:0.18]];
    self.actionButton.layer.shadowOpacity = 0.10;
    self.actionButton.layer.shadowRadius = 10.0;
    self.actionButton.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    self.actionButton.accessibilityHint = kLang(@"empty_retry_button") ?: @"";
    if (@available(iOS 13.0, *)) {
        self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.actionButton addTarget:self action:@selector(pp_handleActionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    self.actionButton = [self pp_ButtonWithSystemName:@"square.and.pencil" action:@selector(pp_handleActionButtonTapped)];
    [self pp_applyNavigationItems];
}

- (void)pp_setupContentContainer
{
    self.contentContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentContainerView.backgroundColor = UIColor.clearColor;
    self.contentContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentContainerView];
}

- (void)pp_applyNavigationItems
{
    if (!self.topChromeContainerView || !self.actionButton) return;
    self.navigationItem.titleView = self.topChromeContainerView;
   /// UIBarButtonItem *tabsItem = [[UIBarButtonItem alloc] initWithCustomView:self.topChromeContainerView];
      
    //UIBarButtonItem *actionItem = [[UIBarButtonItem alloc] initWithCustomView:self.actionButton];

    if(!Language.isRTL)
    {
       // self.navigationItem.rightBarButtonItem = tabsItem;
       // self.navigationItem.leftBarButtonItem = actionItem;
    }
    else
    {
       // self.navigationItem.leftBarButtonItem = tabsItem;
        
    }
}

#pragma mark - Child Flow

- (void)pp_showChildAtIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < 0 || index >= (NSInteger)self.childControllers.count) return;

    UIViewController *nextChild = self.childControllers[index];
    if (self.activeChild == nextChild) {
        [self pp_refreshActionButtonForIndex:index];
        [self.tabsView selectIndex:index animated:animated];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
        return;
    }

    UIViewController *previousChild = self.activeChild;
    self.selectedIndex = index;
    [self.tabsView selectIndex:index animated:animated];

    if (previousChild) {
        [previousChild willMoveToParentViewController:nil];
    }

    [self addChildViewController:nextChild];
    nextChild.view.frame = self.contentContainerView.bounds;
    nextChild.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    if (!animated || !previousChild) {
        [previousChild.view removeFromSuperview];
        [previousChild removeFromParentViewController];
        [self.contentContainerView addSubview:nextChild.view];
        [nextChild didMoveToParentViewController:self];
        self.activeChild = nextChild;
        [self pp_refreshActionButtonForIndex:index];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
        return;
    }

    nextChild.view.alpha = 0.0;
    nextChild.view.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [self.contentContainerView addSubview:nextChild.view];

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
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
    }];
}

- (void)pp_refreshActionButtonForIndex:(NSInteger)index
{
    NSString *symbolName = @"arrow.clockwise";
    NSString *accessibilityLabel = kLang(@"empty_retry_button") ?: @"Refresh";
    BOOL enabled = YES;

    switch (index) {
        case 0:
            symbolName = @"square.and.pencil";
            accessibilityLabel = kLang(@"empty_chats_button") ?: @"Start chat";
            enabled = [self.chatsVC respondsToSelector:@selector(startNewChat)];
            break;
        case 1:
            symbolName = @"plus";
            accessibilityLabel = kLang(@"pet_reminder_add") ?: @"Add Reminder";
            enabled = [self.remindersVC respondsToSelector:@selector(pp_addReminder)];
            break;
        case 2:
        default:
            symbolName = @"arrow.clockwise";
            accessibilityLabel = kLang(@"empty_retry_button") ?: @"Refresh";
            enabled = YES;
            break;
    }

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:symCfg];

    if (@available(iOS 26.0, *)) {
        // Update the existing glass configuration in-place — no button recreation
        UIButtonConfiguration *btnCfg = self.actionButton.configuration;
        if (!btnCfg) {
            btnCfg = [UIButtonConfiguration glassButtonConfiguration];
        }
        btnCfg.image = image;
        self.actionButton.configuration = btnCfg;
    } else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *btnCfg = self.actionButton.configuration;
        if (btnCfg) {
            btnCfg.image = image;
            self.actionButton.configuration = btnCfg;
        } else {
            [self.actionButton setImage:image forState:UIControlStateNormal];
        }
    } else {
        [self.actionButton setImage:image forState:UIControlStateNormal];
    }

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
