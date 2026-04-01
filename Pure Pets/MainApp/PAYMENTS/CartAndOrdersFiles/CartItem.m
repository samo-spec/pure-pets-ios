//
//  CartItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.
//


#import "CartItem.h"


@implementation CartItem

- (instancetype)initWithAccessory:(PetAccessory *)accessory quantity:(NSInteger)qty {
    self = [super init];
    if (self) {
        _itemID = accessory.accessoryID ?: @"";
        _name = accessory.name ?: @"";
        _price = [accessory.price floatValue];
        _quantity = MAX(qty, 0);
        _stockQuantity = MAX(accessory.quantity, 0);
        //_type = accessory.ty;
        NSString *firstImage = @"";
        if ([accessory.imageURLsArray isKindOfClass:NSArray.class] &&
            accessory.imageURLsArray.count > 0 &&
            [accessory.imageURLsArray.firstObject isKindOfClass:NSString.class]) {
            firstImage = accessory.imageURLsArray.firstObject ?: @"";
        }
        _imageURL = firstImage;
    }
    return self;
}

- (NSDictionary *)firestoreDictionary
{
    NSMutableDictionary *dict = [@{
        @"id": self.itemID ?: @"",
        @"type": self.type ?: @"",
        @"name": self.name ?: @"",
        @"price": @(self.price),
        @"qty": @(MAX(self.quantity, 0))
    } mutableCopy];
    if (self.stockQuantity != NSNotFound) {
        dict[@"stockQuantity"] = @(MAX(self.stockQuantity, 0));
    }
    return dict;
}


- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _itemID = dict[@"itemID"] ?: @"";
        _name = dict[@"name"] ?: @"";
        _quantity = [dict[@"quantity"] integerValue];
        if ([dict[@"stockQuantity"] respondsToSelector:@selector(integerValue)]) {
            _stockQuantity = MAX(0, [dict[@"stockQuantity"] integerValue]);
        } else {
            _stockQuantity = NSNotFound;
        }
        _price = [dict[@"price"] floatValue];
          _imageURL = dict[@"imageURL"] ?: @""; // optional, if stored
    }
    return self;
}


// ORDER



// In your implementation file (.m)
+ (NSString *)stringFromOrderStatus:(OrderStatus)status {
    switch (status) {
        case OrderStatusPending: return kLang(@"Pending");
        case OrderStatusShipped: return kLang(@"Shipped");
        case OrderStatusDelivered: return kLang(@"Delivered");
        case OrderStatusApproved: return kLang(@"Approved");
        case OrderStatusRejected: return kLang(@"Rejected");
        default: return kLang(@"Unknown");
    }
}

@end
