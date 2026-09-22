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
        _size = accessory.size ?: @"";

        _sellableUnitId = accessory.sellableUnitId.length > 0 ? accessory.sellableUnitId : _itemID;
        _variantId = accessory.variantId.length > 0 ? accessory.variantId : (_sellableUnitId ?: accessory.colorID);
        _variantCombinationKey = accessory.variantCombinationKey ?: @"";
        _productFamilyId = accessory.productFamilyId ?: @"";
        _sku = accessory.sku ?: @"";
        _barcode = accessory.barcode ?: @"";
        _isVariant = accessory.isVariant || (_variantCombinationKey.length > 0);
        _selectedOptions = [accessory.selectedOptions copy];

        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if ([accessory.selectedOptions isKindOfClass:NSDictionary.class] && accessory.selectedOptions.count > 0) {
            NSArray *sortedKeys = [accessory.selectedOptions.allKeys sortedArrayUsingSelector:@selector(compare:)];
            for (NSString *key in sortedKeys) {
                NSString *val = [NSString stringWithFormat:@"%@", accessory.selectedOptions[key]];
                if (val.length > 0) {
                    NSString *localizedKey = [key.lowercaseString isEqualToString:@"color"] ? kLang(@"Color") :
                                             [key.lowercaseString isEqualToString:@"size"] ? kLang(@"Size") : key.capitalizedString;
                    [parts addObject:[NSString stringWithFormat:@"%@: %@", localizedKey, val]];
                }
            }
        }
        if (parts.count == 0) {
            if (accessory.colorName.length > 0) {
                [parts addObject:[NSString stringWithFormat:@"%@: %@", kLang(@"Color"), accessory.colorName]];
            }
            if (accessory.size.length > 0) {
                [parts addObject:[NSString stringWithFormat:@"%@: %@", kLang(@"Size"), accessory.size]];
            }
        }
        _optionsSummary = [parts componentsJoinedByString:@" · "];

        NSLog(@"[CartItem] Created | id=%@ | sellableId=%@ | variantKey=%@ | options=%@ | basePrice=%.2f | finalPrice=%.2f | effectivePrice=%.2f | discount=%@ | qty=%ld",
              _itemID, _sellableUnitId, _variantCombinationKey, _optionsSummary,
              basePrice, finalPrice, _price,
              self.hasDiscount ? @"YES" : @"NO", (long)_quantity);
    }
    return self;
}

#pragma mark - Firestore

- (NSDictionary *)firestoreDictionary
{
    NSMutableDictionary *dict = [@{
        @"id": self.itemID ?: @"",
        @"itemID": self.itemID ?: @"",
        @"type": self.type ?: @"",
        @"name": self.name ?: @"",
        @"price": @(self.price),
        @"originalPrice": @(self.originalPrice),
        @"qty": @(MAX(self.quantity, 0)),
        @"quantity": @(MAX(self.quantity, 0))
    } mutableCopy];
    if (self.size.length > 0) {
        dict[@"size"] = self.size;
    }
    if (self.sellableUnitId.length > 0) {
        dict[@"sellableUnitId"] = self.sellableUnitId;
    }
    if (self.variantId.length > 0) {
        dict[@"variantId"] = self.variantId;
    }
    if (self.variantCombinationKey.length > 0) {
        dict[@"variantCombinationKey"] = self.variantCombinationKey;
    }
    if (self.productFamilyId.length > 0) {
        dict[@"productFamilyId"] = self.productFamilyId;
    }
    if (self.sku.length > 0) {
        dict[@"sku"] = self.sku;
    }
    if (self.barcode.length > 0) {
        dict[@"barcode"] = self.barcode;
    }
    if (self.isVariant) {
        dict[@"isVariant"] = @(YES);
    }
    if (self.selectedOptions.count > 0) {
        dict[@"selectedOptions"] = self.selectedOptions;
    }
    if (self.selectedOptionsSnapshot.count > 0) {
        dict[@"selectedOptionsSnapshot"] = self.selectedOptionsSnapshot;
    }
    if (self.optionsSummary.length > 0) {
        dict[@"optionsSummary"] = self.optionsSummary;
    }
    if (self.imageURL.length > 0) {
        dict[@"imageURL"] = self.imageURL;
    }
    if (self.providerID.length > 0) {
        dict[@"providerID"] = self.providerID;
    }
    // F-25: `stockQuantity` is deliberately NOT persisted.
    //
    // It used to be written into `UsersCol/{uid}/cartItems/{id}` and read back, so
    // a cart opened days later rendered availability from a frozen snapshot taken
    // at add-to-cart time. The stored number only ever aged, never corrected
    // itself, and it fed the add-to-cart ceiling — so a customer could be shown,
    // and allowed to increase, stock that no longer existed.
    //
    // The field remains an in-memory hint resolved from the live catalogue; a
    // restored cart starts with `NSNotFound` ("unknown"), which the add-to-cart
    // guard already treats as fail-closed (`CartManager.m:395-410`).
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
        _itemID = dict[@"itemID"] ?: dict[@"id"] ?: @"";
        _name = dict[@"name"] ?: @"";
        _size = dict[@"size"] ?: @"";
        _quantity = [dict[@"quantity"] ?: dict[@"qty"] integerValue];
        // F-25: a persisted `stockQuantity` from an older build is ignored rather
        // than trusted. Stock is re-resolved from the live catalogue; until then it
        // is explicitly unknown, which the add-to-cart guard fails closed on.
        _stockQuantity = NSNotFound;
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

        _sellableUnitId = dict[@"sellableUnitId"] ?: _itemID;
        _variantId = dict[@"variantId"] ?: _sellableUnitId;
        _variantCombinationKey = dict[@"variantCombinationKey"] ?: @"";
        _productFamilyId = dict[@"productFamilyId"] ?: @"";
        _sku = dict[@"sku"] ?: @"";
        _barcode = dict[@"barcode"] ?: @"";
        _isVariant = [dict[@"isVariant"] boolValue] || (_variantCombinationKey.length > 0);
        if ([dict[@"selectedOptions"] isKindOfClass:NSDictionary.class]) {
            _selectedOptions = [dict[@"selectedOptions"] copy];
        }
        if ([dict[@"selectedOptionsSnapshot"] isKindOfClass:NSArray.class]) {
            _selectedOptionsSnapshot = [dict[@"selectedOptionsSnapshot"] copy];
        }
        _optionsSummary = dict[@"optionsSummary"] ?: @"";
        if (_optionsSummary.length == 0) {
            NSMutableArray<NSString *> *parts = [NSMutableArray array];
            if (_selectedOptions.count > 0) {
                NSArray *sortedKeys = [_selectedOptions.allKeys sortedArrayUsingSelector:@selector(compare:)];
                for (NSString *key in sortedKeys) {
                    NSString *val = [NSString stringWithFormat:@"%@", _selectedOptions[key]];
                    if (val.length > 0) {
                        NSString *localizedKey = [key.lowercaseString isEqualToString:@"color"] ? kLang(@"Color") :
                                                 [key.lowercaseString isEqualToString:@"size"] ? kLang(@"Size") : key.capitalizedString;
                        [parts addObject:[NSString stringWithFormat:@"%@: %@", localizedKey, val]];
                    }
                }
            } else if (_size.length > 0) {
                [parts addObject:[NSString stringWithFormat:@"%@: %@", kLang(@"Size"), _size]];
            }
            _optionsSummary = [parts componentsJoinedByString:@" · "];
        }
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
