#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PPHomePromoCarouselActionHandling <NSObject>

/// action: raw PPBannerOnTapAction value
/// source: 0 card, 1 primary CTA, 2 secondary CTA
- (void)homePromoCarouselDidRequestAction:(NSInteger)action
                                    value:(NSString *)value
                                   cardID:(NSString *)cardID
                                   source:(NSInteger)source;

@end

@interface PPHomePromoCarouselBridge : NSObject

+ (UIViewController *)makeCarouselWithActionHandler:(nullable id<PPHomePromoCarouselActionHandling>)handler;
+ (CGFloat)recommendedHeightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
