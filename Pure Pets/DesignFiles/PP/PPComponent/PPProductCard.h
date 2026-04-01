//
//  PPProductCard.h
//  Pure Pets
//
//  Design System — Product card with image, price, rating, add-to-cart, and discount badge.
//  Follows Apple HIG spacing, touch targets, and design tokens from PPDesignTokens.h.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPProductCard : UICollectionViewCell

+ (NSString *)reuseIdentifier;

/// Configure the product card.
/// @param title         Product name
/// @param price         Current price string (e.g., "45 ر.ق")
/// @param originalPrice Original price (nil if no discount)
/// @param imageURL      Product image URL string (loaded externally)
/// @param rating        Star rating 0.0–5.0
/// @param reviewCount   Number of reviews
/// @param discountPct   Discount percentage (0 = no discount)
/// @param currency      Currency label (e.g., "ر.ق")
- (void)configureWithTitle:(NSString *)title
                     price:(NSString *)price
             originalPrice:(nullable NSString *)originalPrice
                  imageURL:(nullable NSString *)imageURL
                    rating:(CGFloat)rating
               reviewCount:(NSInteger)reviewCount
               discountPct:(NSInteger)discountPct
                  currency:(NSString *)currency;

/// Block called when "add to cart" is tapped.
@property (nonatomic, copy, nullable) void(^onAddToCart)(void);

/// Block called when the card is tapped (navigate to detail).
@property (nonatomic, copy, nullable) void(^onTap)(void);

/// The product image view (for external image loading, e.g., SDWebImage/Kingfisher).
@property (nonatomic, strong, readonly) UIImageView *productImageView;

@end

NS_ASSUME_NONNULL_END
