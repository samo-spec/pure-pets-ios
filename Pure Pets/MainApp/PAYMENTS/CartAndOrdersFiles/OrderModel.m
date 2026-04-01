//
//  OrderItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/07/2025.
//

#import "OrderModel.h"

@implementation OrderModel

- (instancetype)initWithDocumentID:(NSString *)docID dictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _orderID = docID;
        _status = [dict[@"status"] integerValue] ?: OrderStatusPending;
        _totalPrice = [dict[@"totalPrice"] floatValue];
        _totalQuantity = [dict[@"totalQuantity"] integerValue];
        
        FIRTimestamp *timestamp = dict[@"createdAt"];
        if ([timestamp isKindOfClass:[FIRTimestamp class]]) {
            _createdAt = timestamp.dateValue;
        } else {
            _createdAt = [NSDate date];
        }

        NSMutableArray *parsedItems = [NSMutableArray array];
        NSArray *itemsArray = dict[@"items"];
        for (NSDictionary *itemDict in itemsArray) {
            CartItem *item = [[CartItem alloc] initWithDictionary:itemDict];
            PetAccessory *ac = [[PetAccessoryManager sharedManager] getAccessoryID:item.itemID];
            item.imageURL = ac.imageURLsArray.firstObject;
            NSLog(@"itemDict %@",itemDict);
            NSLog(@"ac %@",ac);
            [parsedItems addObject:item];
        }
        _items = parsedItems;
    }
    return self;
}

@end
