//
//  HXCompatibilityCategories.h
//  Pure Pets
//
//  Lightweight shim providing UIView layout and UIColor hex helpers
//  originally supplied by the old ObjC HXPhotoPicker categories.
//

#import <UIKit/UIKit.h>

#pragma mark - UIView (HXLayout)

@interface UIView (HXLayout)

@property (nonatomic, assign) CGFloat hx_x;
@property (nonatomic, assign) CGFloat hx_y;
@property (nonatomic, assign) CGFloat hx_w;
@property (nonatomic, assign) CGFloat hx_h;
@property (nonatomic, assign) CGFloat hx_centerX;
@property (nonatomic, assign) CGFloat hx_centerY;
@property (nonatomic, assign, readonly) CGFloat hx_maxx;
@property (nonatomic, assign, readonly) CGFloat hx_maxy;
@property (nonatomic, assign) CGSize  hx_size;
@property (nonatomic, assign) CGPoint hx_origin;

/// Legacy alias: bare .height / .width / .size / .centerX / .centerY on UIView
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGSize  size;
@property (nonatomic, assign) CGFloat centerX;
@property (nonatomic, assign) CGFloat centerY;

@end

#pragma mark - UIColor (HXHex)

@interface UIColor (HXHex)

+ (UIColor *)colorWithHexString:(NSString *)hexString;
+ (UIColor *)hx_colorWithHexStr:(NSString *)hexString;
+ (UIColor *)hx_colorWithR:(CGFloat)r g:(CGFloat)g b:(CGFloat)b a:(CGFloat)a;
+ (BOOL)hx_colorIsWhite:(UIColor *)color;
- (NSString *)hx_hexStringWithColor;

@end
