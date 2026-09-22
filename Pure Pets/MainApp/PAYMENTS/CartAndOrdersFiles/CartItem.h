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
@property (nonatomic, assign) double price;
/// The original (pre-discount) unit price — display/reference only.
@property (nonatomic, assign) double originalPrice;
@property (nonatomic, strong) NSString *imageURL;
@property (nonatomic, strong) NSString *providerID;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, copy, nullable) NSString *size;

#pragma mark - Variant & Options Metadata

/// Sellable unit / variant identifier (matches variant productId)
@property (nonatomic, copy, nullable) NSString *sellableUnitId;
/// Unified variant identifier (sellableUnitId or legacy color ID)
@property (nonatomic, copy, nullable) NSString *variantId;
/// Canonical option combination key (e.g. "color=red|size=m")
@property (nonatomic, copy, nullable) NSString *variantCombinationKey;
/// Parent product family identifier if this item belongs to an option family
@property (nonatomic, copy, nullable) NSString *productFamilyId;
/// Exact SKU for this variant
@property (nonatomic, copy, nullable) NSString *sku;
/// Exact barcode for this variant
@property (nonatomic, copy, nullable) NSString *barcode;
/// Flag indicating whether this item represents a family variant
@property (nonatomic, assign) BOOL isVariant;
/// Selected options dictionary: optionId -> valueId
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *selectedOptions;
/// Detailed option snapshots for display and reconciliation
@property (nonatomic, strong, nullable) NSArray<NSDictionary *> *selectedOptionsSnapshot;
/// Human-readable option summary (e.g. "Color: Red · Size: M" or "اللون: أحمر · المقاس: M")
@property (nonatomic, copy, nullable) NSString *optionsSummary;

/// YES when originalPrice > price (a discount is active).
@property (nonatomic, readonly) BOOL hasDiscount;
/// The per-unit discount amount (originalPrice − price). Returns 0 if no discount.
@property (nonatomic, readonly) double discountPerUnit;
/// Line subtotal at effective price: price × quantity.
@property (nonatomic, readonly) double lineSubtotal;
/// Line subtotal at original price: originalPrice × quantity.
@property (nonatomic, readonly) double lineSubtotalBeforeDiscount;
/// Total line-level discount: (originalPrice − price) × quantity.
@property (nonatomic, readonly) double lineDiscountTotal;

- (NSDictionary *)firestoreDictionary;
- (instancetype)initWithAccessory:(PetAccessory *)accessory quantity:(NSInteger)qty;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
// In your header file (.h)
+ (NSString *)stringFromOrderStatus:(OrderStatus)status;

@end
