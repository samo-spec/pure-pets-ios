// PPAnalytics.m
// See PPAnalytics.h for behavior contract.

#import "PPAnalytics.h"

@import FirebaseAnalytics;

#import "PetAccessory.h"
#import "PetAd.h"
#import "CartItem.h"

static NSString * const kPPCurrency = @"QAR";

static NSString *PPCategoryNameForPetCategory(PetCategory category) {
    switch (category) {
        case PetCategoryBirds:   return @"birds";
        case PetCategoryFish:    return @"fish";
        case PetCategoryCats:    return @"cats";
        case PetCategoryDogs:    return @"dogs";
        case PetCategoryCamel:   return @"camel";
        case PetCategoryHorse:   return @"horse";
        case PetCategorySheep:   return @"sheep";
        case PetCategoryDeer:    return @"deer";
        case PetCategoryFalcon:  return @"falcon";
        case PetCategoryUnknown:
        default:                 return @"other";
    }
}

static NSString *PPChannelName(PPContactChannel channel) {
    switch (channel) {
        case PPContactChannelCall:     return @"call";
        case PPContactChannelChat:     return @"chat";
        case PPContactChannelWhatsapp: return @"whatsapp";
        case PPContactChannelSupport:  return @"support";
    }
    return @"unknown";
}

static NSString *PPAnalyticsStringValue(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return trimmed.length > 0 ? trimmed : nil;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return nil;
}

static NSNumber *PPAnalyticsNumberValue(id value) {
    if ([value isKindOfClass:NSNumber.class]) {
        return (NSNumber *)value;
    }
    if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
        return @([(NSString *)value doubleValue]);
    }
    return nil;
}

static id PPAnalyticsSafeValueForKey(id object, NSString *key) {
    if (!object || key.length == 0) {
        return nil;
    }
    @try {
        id value = [object valueForKey:key];
        return [value isKindOfClass:NSNull.class] ? nil : value;
    } @catch (NSException *exception) {
        return nil;
    }
}

static NSString *PPAnalyticsStringByReplacingPattern(NSString *text,
                                                     NSString *pattern,
                                                     NSString *replacement) {
    if (text.length == 0 || pattern.length == 0) {
        return text;
    }
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    if (!regex) {
        return text;
    }
    return [regex stringByReplacingMatchesInString:text
                                           options:0
                                             range:NSMakeRange(0, text.length)
                                      withTemplate:replacement ?: @""];
}

static NSString *PPAnalyticsSanitizedFreeTextParam(NSString *text) {
    NSString *safe = PPAnalyticsStringValue(text);
    if (safe.length == 0) {
        return nil;
    }
    safe = PPAnalyticsStringByReplacingPattern(safe,
                                               @"\\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}\\b",
                                               @"[redacted]");
    safe = PPAnalyticsStringByReplacingPattern(safe,
                                               @"\\+?\\d[\\d\\s().-]{6,}\\d",
                                               @"[redacted]");
    if (safe.length > 64) {
        safe = [[safe substringToIndex:64] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return safe.length > 0 ? safe : nil;
}

static NSDictionary *PPItemDictionary(NSString *itemID,
                                      NSString *name,
                                      NSString *category,
                                      double price,
                                      NSInteger quantity) {
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithCapacity:6];
    NSString *safeItemID = PPAnalyticsStringValue(itemID);
    NSString *safeName = PPAnalyticsStringValue(name);
    NSString *safeCategory = PPAnalyticsStringValue(category);
    if (safeItemID.length)   item[@"item_id"]       = safeItemID;
    if (safeName.length)     item[@"item_name"]     = safeName;
    if (safeCategory.length) item[@"item_category"] = safeCategory;
    if (price > 0)       item[@"price"]         = @(price);
    if (quantity > 0)    item[@"quantity"]      = @(quantity);
    item[@"currency"] = kPPCurrency;
    return item;
}

static NSArray *PPItemsFromCartItems(NSArray<CartItem *> *cartItems) {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:cartItems.count];
    for (CartItem *ci in cartItems) {
        NSString *iid = PPAnalyticsStringValue(PPAnalyticsSafeValueForKey(ci, @"itemID"));
        NSString *name = PPAnalyticsStringValue(PPAnalyticsSafeValueForKey(ci, @"name"));
        NSNumber *priceNum = PPAnalyticsNumberValue(PPAnalyticsSafeValueForKey(ci, @"price"));
        NSNumber *qtyNum = PPAnalyticsNumberValue(PPAnalyticsSafeValueForKey(ci, @"quantity")) ?: @(1);
        if (iid.length == 0) continue;
        [items addObject:PPItemDictionary(iid, name, nil, priceNum.doubleValue, qtyNum.integerValue)];
    }
    return items;
}

static void PPAnalyticsLogEvent(NSString *eventName, NSDictionary *params) {
    if ([FIRAnalytics class] == nil) return;
    [FIRAnalytics logEventWithName:eventName parameters:params];
#ifdef DEBUG
    DLog(@"[PPAnalytics] %@ %@", eventName, params);
#endif
}

@implementation PPAnalytics

#pragma mark - Single-item events

+ (void)logViewItemWithItemID:(NSString *)itemID
                         name:(NSString *)name
                     category:(NSString *)category
                        price:(double)price {
    if (itemID.length == 0) return;
    NSDictionary *item = PPItemDictionary(itemID, name, category, price, 0);
    NSDictionary *params = @{
        kFIRParameterCurrency: kPPCurrency,
        kFIRParameterValue:    @(price),
        kFIRParameterItems:    @[item],
    };
    PPAnalyticsLogEvent(kFIREventViewItem, params);
}

+ (void)logSelectItemWithItemID:(NSString *)itemID
                           name:(NSString *)name
                       category:(NSString *)category
                          price:(double)price
                     listName:(NSString *)listName {
    if (itemID.length == 0) return;
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    p[kFIRParameterItems] = @[PPItemDictionary(itemID, name, category, price, 0)];
    if (listName.length) p[kFIRParameterItemListName] = listName;
    PPAnalyticsLogEvent(kFIREventSelectItem, p);
}

+ (void)logViewItemListWithCategory:(NSString *)category
                           listName:(NSString *)listName
                          itemCount:(NSUInteger)itemCount {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (category.length) p[kFIRParameterItemCategory] = category;
    if (listName.length) p[kFIRParameterItemListName] = listName;
    p[@"item_count"] = @(itemCount);
    PPAnalyticsLogEvent(kFIREventViewItemList, p);
}

+ (void)logViewCategoryWithCategory:(NSString *)category
                           listName:(NSString *)listName {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (category.length) p[kFIRParameterItemCategory] = category;
    if (listName.length) p[kFIRParameterItemListName] = listName;
    PPAnalyticsLogEvent(@"view_category", p);
}

+ (void)logSearchWithTerm:(NSString *)term resultCount:(NSUInteger)resultCount {
    NSString *sanitizedTerm = PPAnalyticsSanitizedFreeTextParam(term);
    if (sanitizedTerm.length == 0) return;
    NSDictionary *p = @{
        kFIRParameterSearchTerm: sanitizedTerm,
        @"result_count":         @(resultCount),
    };
    PPAnalyticsLogEvent(kFIREventSearch, p);
}

+ (void)logContactIntentForItemID:(NSString *)itemID
                         category:(NSString *)category
                          channel:(PPContactChannel)channel {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    p[@"channel"] = PPChannelName(channel);
    if (itemID.length)   p[@"item_id"]       = itemID;
    if (category.length) p[@"item_category"] = category;
    PPAnalyticsLogEvent(@"contact_intent", p);
}

#pragma mark - Cart / checkout / purchase

+ (void)logAddToCartItemID:(NSString *)itemID
                       name:(NSString *)name
                   category:(NSString *)category
                      price:(double)price
                   quantity:(NSInteger)quantity {
    if (itemID.length == 0) return;
    NSDictionary *item = PPItemDictionary(itemID, name, category, price, MAX(quantity, 1));
    NSDictionary *params = @{
        kFIRParameterCurrency: kPPCurrency,
        kFIRParameterValue:    @(price * MAX(quantity, 1)),
        kFIRParameterItems:    @[item],
    };
    PPAnalyticsLogEvent(kFIREventAddToCart, params);
}

+ (void)logBeginCheckoutWithCartItems:(NSArray<CartItem *> *)cartItems
                           grandTotal:(double)grandTotal {
    NSArray *items = PPItemsFromCartItems(cartItems);
    if (items.count == 0) return;
    NSDictionary *p = @{
        kFIRParameterCurrency: kPPCurrency,
        kFIRParameterValue:    @(grandTotal),
        kFIRParameterItems:    items,
    };
    PPAnalyticsLogEvent(kFIREventBeginCheckout, p);
}

+ (void)logPurchaseWithTransactionID:(NSString *)transactionID
                          cartItems:(NSArray<CartItem *> *)cartItems
                         grandTotal:(double)grandTotal {
    NSArray *items = PPItemsFromCartItems(cartItems);
    if (transactionID.length == 0 || items.count == 0) return;
    NSDictionary *p = @{
        kFIRParameterTransactionID: transactionID,
        kFIRParameterCurrency:      kPPCurrency,
        kFIRParameterValue:         @(grandTotal),
        kFIRParameterItems:         items,
    };
    PPAnalyticsLogEvent(kFIREventPurchase, p);
}

#pragma mark - Model conveniences

+ (void)logViewItemForAccessory:(PetAccessory *)accessory {
    if (accessory == nil) return;
    NSString *iid  = accessory.accessoryID;
    NSString *name = accessory.name;
    double price   = accessory.finalPrice.doubleValue;
    NSString *category = [NSString stringWithFormat:@"acc-%ld", (long)accessory.petMainCategoryID];
    [self logViewItemWithItemID:iid name:name category:category price:price];
}

+ (void)logViewItemForAd:(PetAd *)ad {
    if (ad == nil) return;
    NSString *iid  = ad.adID;
    NSString *name = ad.adTitle;
    NSString *category = PPCategoryNameForPetCategory(ad.category);
    [self logViewItemWithItemID:iid name:name category:category price:0];
}

+ (void)logContactIntentForAd:(PetAd *)ad channel:(PPContactChannel)channel {
    if (ad == nil) return;
    [self logContactIntentForItemID:ad.adID
                           category:PPCategoryNameForPetCategory(ad.category)
                            channel:channel];
}

+ (void)logContactIntentForAccessory:(PetAccessory *)accessory channel:(PPContactChannel)channel {
    if (accessory == nil) return;
    NSString *category = [NSString stringWithFormat:@"acc-%ld", (long)accessory.petMainCategoryID];
    [self logContactIntentForItemID:accessory.accessoryID category:category channel:channel];
}

#pragma mark - Nova chat

+ (void)logNovaOpenedWithSessionID:(NSString *)sessionID {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (sessionID.length) p[@"nova_session_id"] = sessionID;
    PPAnalyticsLogEvent(@"nova_opened", p);
}

+ (void)logNovaMessageSentWithCharCount:(NSUInteger)charCount
                                isArabic:(BOOL)isArabic
                              sessionID:(NSString *)sessionID {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (sessionID.length) p[@"nova_session_id"] = sessionID;
    p[@"char_count"] = @(charCount);
    p[@"language"] = isArabic ? @"ar" : @"en";
    PPAnalyticsLogEvent(@"nova_message_sent", p);
}

+ (void)logNovaShowcaseShownWithItemCount:(NSUInteger)itemCount
                                sessionID:(NSString *)sessionID {
    [self logNovaShowcaseShownWithItemCount:itemCount
                                  sessionID:sessionID
                                     source:nil];
}

+ (void)logNovaShowcaseShownWithItemCount:(NSUInteger)itemCount
                                sessionID:(NSString *)sessionID
                                   source:(nullable NSString *)source {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (sessionID.length) p[@"nova_session_id"] = sessionID;
    if (source.length) p[@"showcase_source"] = source;
    p[@"item_count"] = @(itemCount);
    PPAnalyticsLogEvent(@"nova_showcase_shown", p);
}

+ (void)logNovaShowcaseResolutionFailedWithRequestedCount:(NSUInteger)requestedCount
                                             resolvedCount:(NSUInteger)resolvedCount
                                                 sessionID:(NSString *)sessionID {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (sessionID.length) p[@"nova_session_id"] = sessionID;
    p[@"requested_count"] = @(requestedCount);
    p[@"resolved_count"] = @(resolvedCount);
    PPAnalyticsLogEvent(@"nova_showcase_resolution_failed", p);
}

+ (void)logNovaPreviewOpenedWithItemKind:(nullable NSString *)itemKind
                                  itemID:(nullable NSString *)itemID
                               sessionID:(NSString *)sessionID {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (sessionID.length) p[@"nova_session_id"] = sessionID;
    if (itemKind.length) p[@"item_kind"] = itemKind;
    if (itemID.length) p[@"item_id"] = itemID;
    p[@"item_list_name"] = @"nova_chat";
    PPAnalyticsLogEvent(@"nova_preview_opened", p);
}

+ (void)logNovaErrorWithCode:(NSInteger)gRPCCode
                      domain:(nullable NSString *)domain
                     attempt:(NSInteger)attempt
                   sessionID:(NSString *)sessionID {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (sessionID.length) p[@"nova_session_id"] = sessionID;
    p[@"error_code"] = @(gRPCCode);
    if (domain.length) p[@"error_domain"] = domain;
    p[@"attempt"] = @(attempt);
    PPAnalyticsLogEvent(@"nova_error", p);
}

+ (void)logNovaClosedWithSessionID:(NSString *)sessionID
                      messageCount:(NSUInteger)messageCount {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    if (sessionID.length) p[@"nova_session_id"] = sessionID;
    p[@"message_count"] = @(messageCount);
    PPAnalyticsLogEvent(@"nova_closed", p);
}

@end
