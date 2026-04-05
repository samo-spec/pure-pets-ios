//
//  PPCartCalculator.h
//  Pure Pets
//
//  Centralized, single-source-of-truth calculator for all cart totals.
//  Every screen that displays cart pricing MUST use this — no local math.
//

#import <Foundation/Foundation.h>
@class CartItem;

NS_ASSUME_NONNULL_BEGIN

/// Immutable snapshot of cart totals at a point in time.
@interface PPCartSummary : NSObject

/// Sum of all item quantities (A×2 + B×3 = 5).
@property (nonatomic, readonly) NSInteger totalQuantity;
/// Number of distinct line items (A + B = 2).
@property (nonatomic, readonly) NSInteger uniqueItems;
/// Sum of (effectivePrice × qty) across all items.
@property (nonatomic, readonly) double subtotal;
/// Sum of ((originalPrice − effectivePrice) × qty) across all items.
@property (nonatomic, readonly) double discountTotal;
/// Sum of (originalPrice × qty) — what the cart would cost without any discounts.
@property (nonatomic, readonly) double subtotalBeforeDiscount;
/// subtotal + shipping.
@property (nonatomic, readonly) double finalTotal;
/// Shipping fee applied.
@property (nonatomic, readonly) double shippingFee;
/// YES if any item in the cart has a discount.
@property (nonatomic, readonly) BOOL hasAnyDiscount;

@end

/// Thread-safe, stateless calculator.  Call `currentSummary` any time.
@interface PPCartCalculator : NSObject

/// Compute a summary from the current CartManager state.
+ (PPCartSummary *)currentSummary;

/// Compute a summary from an arbitrary item array + shipping fee.
+ (PPCartSummary *)summaryForItems:(NSArray<CartItem *> *)items
                       shippingFee:(double)shippingFee;

/// Log all line-level detail + totals.  Useful for checkout debugging.
+ (void)logDetailedSummary:(PPCartSummary *)summary
                     items:(NSArray<CartItem *> *)items;

@end

NS_ASSUME_NONNULL_END
