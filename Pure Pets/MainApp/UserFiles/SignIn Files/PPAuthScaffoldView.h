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
+ (void)applyFocusStyleToInputView:(UIView *)view focused:(BOOL)focused;
+ (void)addPressMotionToControl:(UIControl *)control;
+ (void)animateEntranceForViews:(NSArray<UIView *> *)views
                    inContainer:(UIView *)container;

@end

NS_ASSUME_NONNULL_END
