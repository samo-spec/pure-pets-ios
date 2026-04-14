#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPCornerBlurView : UIView

@property (nonatomic, copy, nullable) void (^layoutSubviewsBlock)(void);
@property (nonatomic, strong, nullable) UIVisualEffectView *blurView;

- (void)applyBlurStyle:(UIBlurEffectStyle)style
             tintColor:(nullable UIColor *)tintColor;

@end

NS_ASSUME_NONNULL_END
