#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeLocationTitleView : UIControl

- (void)configureWithTitle:(NSString *)title
               statusColor:(UIColor *)statusColor
                   loading:(BOOL)loading
         accessibilityHint:(nullable NSString *)accessibilityHint
                  animated:(BOOL)animated;

- (void)playEntranceIfNeeded;
- (void)startLivingMotion;
- (void)stopLivingMotion;

@end

NS_ASSUME_NONNULL_END
