//
//  PPDiscountBadge.h
//  Pure Pets
//
//  Design System — Discount percentage badge for product cards.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPDiscountBadge : UIView

/// Discount percentage (e.g., 25 for "25%").
@property (nonatomic, assign) NSInteger discountPercent;

/// Update the badge display.
- (void)configureWithPercent:(NSInteger)percent;

@end

NS_ASSUME_NONNULL_END
