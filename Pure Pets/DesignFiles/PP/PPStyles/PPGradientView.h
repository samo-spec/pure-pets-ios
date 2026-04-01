//
//  UIView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2025.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPGradientDirection) {
    PPGradientDirectionLeftToRight,
    PPGradientDirectionRightToLeft,
    PPGradientDirectionTopToBottom,
    PPGradientDirectionBottomToTop
};


@interface UIView (PPViewDesign)
+ (CAGradientLayer *)halfGradientLayerWithFadeForColor:(UIColor *)gardColor
                                   direction:(PPGradientDirection)direction
                                                 frame:(CGRect)frame;
- (void)setBlackShadowOffset:(CGSize)offset radius:(CGFloat)radius
                       alpha:(CGFloat)alpha;
- (void)setShadow:(UIColor*)color offset:(CGSize)offset radius:(CGFloat)radius;
- (void)pp_ApplyCornerMask_tl:(CGFloat)tl
                           tr:(CGFloat)tr
                           bl:(CGFloat)bl
                           br:(CGFloat)br;

- (void)pp_applyGradientWithStartColor:(UIColor *)startColor
                              endColor:(UIColor *)endColor
                          cornerRadius:(CGFloat)cornerRadius;

- (void)pp_applyGradientWithStartColor:(UIColor *)startColor
                              endColor:(UIColor *)endColor
                          cornerRadius:(CGFloat)cornerRadius
                           shadowColor:(UIColor *)shadowColor
                         shadowOpacity:(float)shadowOpacity
                          shadowRadius:(CGFloat)shadowRadius
                          shadowOffset:(CGSize)shadowOffset;
+ (UIView *)blurredGradientViewWithColor:(UIColor *)gardColor
                               direction:(PPGradientDirection)direction
                                   frame:(CGRect)frame ;
- (void)pp_removeGradient;


- (void)pp_applyGradientWithColors:(NSArray<UIColor *> *)colors  cornerRadius:(CGFloat)cornerRadius shadowColor:(UIColor *)shadowColor shadowOpacity:(float)shadowOpacity shadowRadius:(CGFloat)shadowRadius shadowOffset:(CGSize)shadowOffse;

+ (CAGradientLayer *)gradientLayerWithColors:(NSArray<UIColor *> *)colors
                                   direction:(PPGradientDirection)direction
                                       frame:(CGRect)frame;


+ (CAGradientLayer *)gradientLayerWithFadeForColor:(UIColor *)gardColor
                                   direction:(PPGradientDirection)direction
                                             frame:(CGRect)frame ;
@end



@interface UIView (PPHXExtension)

@property (assign, nonatomic) CGFloat hx_maxy;
@property (assign, nonatomic) CGFloat hx_maxx;
@property (assign, nonatomic) CGFloat hx_x;
@property (assign, nonatomic) CGFloat hx_y;
@property (assign, nonatomic) CGFloat hx_w;
@property (assign, nonatomic) CGFloat hx_h;
@property (assign, nonatomic) CGFloat hx_centerX;
@property (assign, nonatomic) CGFloat hx_centerY;
@property (assign, nonatomic) CGSize hx_size;
@property (assign, nonatomic) CGPoint hx_origin;

@end

NS_ASSUME_NONNULL_END
