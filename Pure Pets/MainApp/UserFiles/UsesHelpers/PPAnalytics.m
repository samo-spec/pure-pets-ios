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
}

static NSDictionary *PPItemDictionary(NSString *itemID,
                                      NSString *name,
                                      NSString *category,
                                      double price,
                                      NSInteger quantity) {
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithCapacity:6];
    if (itemID.length)   item[@"item_id"]       = itemID;
    if (name.length)     item[@"item_name"]     = name;
    if (category.length) item[@"item_category"] = category;
    if (price > 0)       item[@"price"]         = @(price);
    if (quantity > 0)    item[@"quantity"]      = @(quantity);
    item[@"currency"] = kPPCurrency;
    return item;
}

static NSArray *PPItemsFromCartItems(NSArray<CartItem *> *cartItems) {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:cartItems.count];
    for (CartItem *ci in cartItems) {
        NSString *iid  = [ci respondsToSelector:@selector(itemID)]   ? [ci valueForKey:@"itemID"]   : nil;
        NSString *name = [ci respondsToSelector:@selector(name)]     ? [ci valueForKey:@"name"]     : nil;
        NSNumber *priceNum = [ci respondsToSelector:@selector(price)] ? [ci valueForKey:@"price"]   : nil;
        NSNumber *qtyNum   = [ci respondsToSelector:@selector(quantity)] ? [ci valueForKey:@"quantity"] : @(1);
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
    if (term.length == 0) return;
    NSDictionary *p = @{
        kFIRParameterSearchTerm: term,
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

@end
