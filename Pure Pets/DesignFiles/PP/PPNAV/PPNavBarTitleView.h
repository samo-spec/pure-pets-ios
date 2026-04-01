//
//  PPNavBarTitleView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/01/2026.
//


@interface PPNavBarTitleView : UIView

- (instancetype)initWithTitle:(nullable NSString *)title
                      subtitle:(nullable NSString *)subtitle
                          icon:(nullable UIImage *)icon
                ppIconPostion:(NSInteger)ppIconPostion;

@property (assign) NSInteger ppIconPostion;
/// Control blur style if needed
@property (nonatomic, assign) UIBlurEffectStyle blurStyle;

/// Max width guard (default 240)
@property (nonatomic, assign) CGFloat maxWidth;

/// Update content safely after init
- (void)updateTitle:(NSString *)title
           subtitle:(nullable NSString *)subtitle
               icon:(nullable UIImage *)icon;

@end

 