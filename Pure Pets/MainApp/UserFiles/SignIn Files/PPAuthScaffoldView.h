//
//  PPAuthScaffoldView.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPAuthScaffoldView : UIView

@property (nonatomic, strong, readonly) UIView *topAccentView;
@property (nonatomic, strong, readonly) UIView *bottomAccentView;

+ (NSArray<NSString *> *)defaultStepTitles;
+ (UIStackView *)headerStackWithTitle:(NSString *)title
                              subtitle:(NSString *)subtitle
                               eyebrow:(nullable NSString *)eyebrow;
+ (void)applyPremiumCardStyleToView:(UIView *)view;
+ (void)applyPrimaryButtonStyleToButton:(UIButton *)button enabled:(BOOL)enabled loading:(BOOL)loading;
+ (void)applySecondaryButtonStyleToButton:(UIButton *)button;
+ (void)applyInputStyleToView:(UIView *)view;
+ (void)addPressMotionToControl:(UIControl *)control;

@end

NS_ASSUME_NONNULL_END
