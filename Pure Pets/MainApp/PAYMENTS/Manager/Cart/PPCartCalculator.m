//
//  PPCartCalculator.m
//  Pure Pets
//

#import "PPCartCalculator.h"
#import "CartManager.h"
#import "CartItem.h"

#pragma mark - PPCartSummary (private setters)

@interface PPCartSummary ()
@property (nonatomic, readwrite) NSInteger totalQuantity;
@property (nonatomic, readwrite) NSInteger uniqueItems;
@property (nonatomic, readwrite) double subtotal;
@property (nonatomic, readwrite) double discountTotal;
@property (nonatomic, readwrite) double subtotalBeforeDiscount;
@property (nonatomic, readwrite) double finalTotal;
@property (nonatomic, readwrite) double shippingFee;
@property (nonatomic, readwrite) BOOL hasAnyDiscount;
@end

@implementation PPCartSummary
@end

#pragma mark - PPCartCalculator

@implementation PPCartCalculator

+ (PPCartSummary *)currentSummary
{
    CartManager *cart = [CartManager sharedManager];
    double shipping = cart.cartItems.count == 0 ? 0.0 : MAX(0.0, cart.deliveryFee);
    return [self summaryForItems:cart.cartItems shippingFee:shipping];
}

+ (PPCartSummary *)summaryForItems:(NSArray<CartItem *> *)items
                       shippingFee:(double)shippingFee
{
    PPCartSummary *s = [PPCartSummary new];

    NSInteger totalQty = 0;
    double subtotal = 0.0;
    double discountTotal = 0.0;
    double subtotalBefore = 0.0;
    BOOL anyDiscount = NO;

    for (CartItem *item in items) {
        NSInteger qty = MAX(item.quantity, 0);
        float effective = item.price;
        float original  = item.originalPrice > 0.0f ? item.originalPrice : effective;

        totalQty += qty;
        subtotal += (double)(effective * (float)qty);

        double lineBefore = (double)(original * (float)qty);
        subtotalBefore += lineBefore;

        if (item.hasDiscount) {
            anyDiscount = YES;
            discountTotal += (double)(item.discountPerUnit * (float)qty);
        }
    }

    s.totalQuantity = totalQty;
    s.uniqueItems = (NSInteger)items.count;
    s.subtotal = MAX(0.0, subtotal);
    s.discountTotal = MAX(0.0, discountTotal);
    s.subtotalBeforeDiscount = MAX(0.0, subtotalBefore);
    s.shippingFee = MAX(0.0, shippingFee);
    s.finalTotal = MAX(0.0, s.subtotal + s.shippingFee);
    s.hasAnyDiscount = anyDiscount;

    return s;
}

+ (void)logDetailedSummary:(PPCartSummary *)summary
                     items:(NSArray<CartItem *> *)items
{
    NSLog(@"[PPCartCalculator] ═══════════════════════════════════");
    NSLog(@"[PPCartCalculator]  Cart Summary  (%ld items, %ld units)",
          (long)summary.uniqueItems, (long)summary.totalQuantity);
    NSLog(@"[PPCartCalculator] ───────────────────────────────────");

    for (CartItem *item in items) {
        NSLog(@"[PPCartCalculator]  📦 %@ | qty=%ld | effective=%.2f | original=%.2f | discount=%@ (%.2f/unit) | lineTotal=%.2f",
              item.name ?: item.itemID,
              (long)item.quantity,
              item.price,
              item.originalPrice,
              item.hasDiscount ? @"YES" : @"NO",
              item.discountPerUnit,
              item.lineSubtotal);
    }

    NSLog(@"[PPCartCalculator] ───────────────────────────────────");
    if (summary.hasAnyDiscount) {
        NSLog(@"[PPCartCalculator]  Before discount : %.2f", summary.subtotalBeforeDiscount);
        NSLog(@"[PPCartCalculator]  Discount total  : -%.2f", summary.discountTotal);
    }
    NSLog(@"[PPCartCalculator]  Subtotal        : %.2f", summary.subtotal);
    NSLog(@"[PPCartCalculator]  Shipping        : %.2f", summary.shippingFee);
    NSLog(@"[PPCartCalculator]  Final total     : %.2f", summary.finalTotal);
    NSLog(@"[PPCartCalculator] ═══════════════════════════════════");
}

@end
