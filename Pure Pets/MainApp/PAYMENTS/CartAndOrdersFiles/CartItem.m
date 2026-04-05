//
//  CartItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.
//


#import "CartItem.h"
#import "PetAccessory.h"

@implementation CartItem

#pragma mark - Computed Properties

- (BOOL)hasDiscount
{
    return self.originalPrice > 0.0f && self.originalPrice > self.price + 0.009f;
}

- (float)discountPerUnit
{
    return self.hasDiscount ? (self.originalPrice - self.price) : 0.0f;
}

- (float)lineSubtotal
{
    return self.price * (float)MAX(self.quantity, 0);
}

- (float)lineSubtotalBeforeDiscount
{
    float base = self.hasDiscount ? self.originalPrice : self.price;
    return base * (float)MAX(self.quantity, 0);
}

- (float)lineDiscountTotal
{
    return self.hasDiscount ? (self.discountPerUnit * (float)MAX(self.quantity, 0)) : 0.0f;
}

#pragma mark - Init from Accessory

- (instancetype)initWithAccessory:(PetAccessory *)accessory quantity:(NSInteger)qty {
    self = [super init];
    if (self) {
        _itemID = accessory.accessoryID ?: @"";
        _name = accessory.name ?: @"";

        float basePrice = [accessory.price floatValue];
        float finalPrice = [accessory.finalPrice floatValue];

        // effectivePrice = finalPrice if a discount exists, otherwise basePrice
        if (finalPrice > 0.0f && finalPrice < basePrice - 0.009f) {
            _price = finalPrice;
            _originalPrice = basePrice;
        } else {
            _price = basePrice;
            _originalPrice = basePrice;
        }

        _quantity = MAX(qty, 0);
        _stockQuantity = MAX(accessory.quantity, 0);

        NSString *firstImage = @"";
        if ([accessory.imageURLsArray isKindOfClass:NSArray.class] &&
            accessory.imageURLsArray.count > 0 &&
            [accessory.imageURLsArray.firstObject isKindOfClass:NSString.class]) {
            firstImage = accessory.imageURLsArray.firstObject ?: @"";
        }
        _imageURL = firstImage;

        NSLog(@"[CartItem] Created | id=%@ | basePrice=%.2f | finalPrice=%.2f | effectivePrice=%.2f | discount=%@ | qty=%ld",
              _itemID, basePrice, finalPrice, _price,
              self.hasDiscount ? @"YES" : @"NO", (long)_quantity);
    }
    return self;
}

#pragma mark - Firestore

- (NSDictionary *)firestoreDictionary
{
    NSMutableDictionary *dict = [@{
        @"id": self.itemID ?: @"",
        @"type": self.type ?: @"",
        @"name": self.name ?: @"",
        @"price": @(self.price),
        @"originalPrice": @(self.originalPrice),
        @"qty": @(MAX(self.quantity, 0))
    } mutableCopy];
    if (self.stockQuantity != NSNotFound) {
        dict[@"stockQuantity"] = @(MAX(self.stockQuantity, 0));
    }
    if (self.hasDiscount) {
        dict[@"discountPerUnit"] = @(self.discountPerUnit);
        dict[@"lineDiscount"] = @(self.lineDiscountTotal);
    }
    return dict;
}

#pragma mark - Init from Dictionary (local persistence / Firestore snapshot)

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

        // Restore originalPrice if present; fallback to price for pre-migration data
        if ([dict[@"originalPrice"] respondsToSelector:@selector(floatValue)]) {
            float stored = [dict[@"originalPrice"] floatValue];
            _originalPrice = stored > 0.0f ? stored : _price;
        } else {
            _originalPrice = _price;
        }

        _imageURL = dict[@"imageURL"] ?: @"";
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
