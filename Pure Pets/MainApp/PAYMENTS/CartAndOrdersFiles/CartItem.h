//
//  CartItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.
//

typedef NS_ENUM(NSInteger, OrderStatus)
{
    OrderStatusPending = 0,
    OrderStatusApproved,
    OrderStatusRejected,
    OrderStatusShipped,
    OrderStatusCanceled,
    OrderStatusDelivered
};



#import <Foundation/Foundation.h>
@class PetAccessory;

@interface CartItem : NSObject

@property (nonatomic, strong) NSString *itemID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) NSInteger stockQuantity; // NSNotFound when unknown
/// The effective (charged) unit price — always use this for calculations.
@property (nonatomic, assign) float price;
/// The original (pre-discount) unit price — display/reference only.
@property (nonatomic, assign) float originalPrice;
@property (nonatomic, strong) NSString *imageURL;
@property (nonatomic, strong) NSString *type;

/// YES when originalPrice > price (a discount is active).
@property (nonatomic, readonly) BOOL hasDiscount;
/// The per-unit discount amount (originalPrice − price). Returns 0 if no discount.
@property (nonatomic, readonly) float discountPerUnit;
/// Line subtotal at effective price: price × quantity.
@property (nonatomic, readonly) float lineSubtotal;
/// Line subtotal at original price: originalPrice × quantity.
@property (nonatomic, readonly) float lineSubtotalBeforeDiscount;
/// Total line-level discount: (originalPrice − price) × quantity.
@property (nonatomic, readonly) float lineDiscountTotal;

- (NSDictionary *)firestoreDictionary;
- (instancetype)initWithAccessory:(PetAccessory *)accessory quantity:(NSInteger)qty;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
// In your header file (.h)
+ (NSString *)stringFromOrderStatus:(OrderStatus)status;

@end
