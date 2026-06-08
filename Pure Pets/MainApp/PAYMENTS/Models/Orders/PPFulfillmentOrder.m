#import "PPFulfillmentOrder.h"

@implementation PPFulfillmentOrder

+ (instancetype)fromDictionary:(NSDictionary *)dict fulfillmentID:(NSString *)fulfillmentID
{
    PPFulfillmentOrder *f = [[PPFulfillmentOrder alloc] init];
    f.fulfillmentID = fulfillmentID ?: @"";
    f.parentOrderId = [dict[@"parentOrderId"] isKindOfClass:NSString.class] ? dict[@"parentOrderId"] : @"";
    f.ownerID = [dict[@"ownerID"] isKindOfClass:NSString.class] ? dict[@"ownerID"] : @"";
    f.ownerType = [dict[@"ownerType"] isKindOfClass:NSString.class] ? dict[@"ownerType"] : @"platform";
    f.status = [dict[@"status"] isKindOfClass:NSString.class] ? dict[@"status"] : @"new_request";

    NSArray *items = [dict[@"items"] isKindOfClass:NSArray.class] ? dict[@"items"] : @[];
    f.itemCount = items.count;

    NSDictionary *money = [dict[@"money"] isKindOfClass:NSDictionary.class] ? dict[@"money"] : @{};
    f.subtotal = [money[@"subtotal"] respondsToSelector:@selector(doubleValue)] ? [money[@"subtotal"] doubleValue] : 0.0;
    f.providerNet = [money[@"providerNet"] respondsToSelector:@selector(doubleValue)] ? [money[@"providerNet"] doubleValue] : 0.0;
    f.currency = [money[@"currency"] isKindOfClass:NSString.class] ? money[@"currency"] : @"QAR";

    return f;
}

@end
