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

- (double)discountPerUnit
{
    return self.hasDiscount ? (self.originalPrice - self.price) : 0.0;
}

- (double)lineSubtotal
{
    return self.price * (double)MAX(self.quantity, 0);
}

- (double)lineSubtotalBeforeDiscount
{
    double base = self.hasDiscount ? self.originalPrice : self.price;
    return base * (double)MAX(self.quantity, 0);
}

- (double)lineDiscountTotal
{
    return self.hasDiscount ? (self.discountPerUnit * (double)MAX(self.quantity, 0)) : 0.0;
}

#pragma mark - Init from Accessory

- (instancetype)initWithAccessory:(PetAccessory *)accessory quantity:(NSInteger)qty {
    self = [super init];
    if (self) {
        _itemID = accessory.accessoryID ?: @"";
        _name = accessory.name ?: @"";

        double basePrice = [accessory.price doubleValue];
        double finalPrice = [accessory.finalPrice doubleValue];

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
        _providerID = accessory.ownerID ?: @"";

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
        _price = [dict[@"price"] doubleValue];

        // Restore originalPrice if present; fallback to price for pre-migration data
        if ([dict[@"originalPrice"] respondsToSelector:@selector(doubleValue)]) {
            double stored = [dict[@"originalPrice"] doubleValue];
            _originalPrice = stored > 0.0f ? stored : _price;
        } else {
            _originalPrice = _price;
        }

        _imageURL = dict[@"imageURL"] ?: @"";
        _providerID = [dict[@"providerID"] isKindOfClass:NSString.class] ? dict[@"providerID"] : @"";
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
