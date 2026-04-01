//
//  PPColorUtils.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/09/2025.
//


#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, PPColorToneAdjustment) {
    PPColorToneAdjustmentNone,
    PPColorToneAdjustmentLighten,
    PPColorToneAdjustmentDarken
};
typedef void(^PPColorUtilsCompletion)(NSArray<UIColor *> *colors);

@interface PPColorUtils : NSObject


@property (nonatomic, strong, readonly) CAGradientLayer *bgGradientLayer;

+ (instancetype)shared;

/// Async dominant color extraction with cache
+ (void)extractGradientColorsAsyncFromImage:(UIImage *)image
                             lightenAmount:(CGFloat)lightenAmount
                                 completion:(PPColorUtilsCompletion)completion;

+ (UIColor *)pp_averageColorFromImage:(UIImage *)image;
/// Clear memory cache (call on memory warning)
+ (void)clearCache;
/// Extract up to `maxColors` dominant colors from image.
/// - image: source image
/// - maxColors: max number of colors to return (2–5 recommended)
/// - lightenAmount: amount to lighten each color (0.0 – 0.6)
+ (NSArray<UIColor *> *)extractDominantColorsFromImage:(UIImage *)image
                                             maxColors:(NSInteger)maxColors
                                         lightenAmount:(CGFloat)lightenAmount;

/// Convenience: returns exactly 3 colors (start / middle / end)
+ (NSArray<UIColor *> *)extractGradientColorsFromImage:(UIImage *)image
                                        lightenAmount:(CGFloat)lightenAmount;


+ (UIColor *)blendColor:(UIColor *)color
              withColor:(UIColor *)background
                 factor:(CGFloat)factor;


/// Set gradient background on a view
- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees
                            onView:(UIView *)view;

/// Extract two main colors with lighten
- (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image
                                     andLightenAmount:(float)amount;

/// Extracts dominant color from UIImageView and applies gradient background to target view
/// @param imageView Source UIImageView
/// @param targetView View to apply gradient to
/// @param adjustment PPColorToneAdjustment (None / Lighten / Darken)
/// @param degree Gradient direction in degrees (0 = left to right, 90 = top to bottom)
+ (void)applyGradientFromImage:(UIImageView *)imageView
                   toView:(UIView *)targetView
         withToneAdjustment:(PPColorToneAdjustment)adjustment
                    degree:(CGFloat)degree;


+ (UIImage *)imageNamed:(NSString *)name
              pointSize:(CGFloat)pointSize
                 weight:(UIImageSymbolWeight)weight
                  scale:(UIImageSymbolScale)scale
                palette:(nullable NSArray<UIColor *> *)palette
           fallbackTint:(nullable UIColor *)fallbackTint
         renderOriginal:(BOOL)original;


+ (UIButton *)buttonWithSymbolName:(NSString *)name
                         pointSize:(CGFloat)pointSize
                            weight:(UIImageSymbolWeight)weight
                             scale:(UIImageSymbolScale)scale
                           palette:(nullable NSArray<UIColor *> *)palette
                      fallbackTint:(nullable UIColor *)fallbackTint
                    renderOriginal:(BOOL)original
                            target:(nullable id)target
                            action:(nullable SEL)action;


+ (void)setSymImage:(NSString *)image toButton:(UIButton *)button;

+ (UIImageSymbolConfiguration *)imageConfig:(CGFloat)pointSize
                 weight:(UIImageSymbolWeight)weight
                  scale:(UIImageSymbolScale)scale
                palette:(NSArray<UIColor *> * _Nullable)palette
           fallbackTint:(UIColor * _Nullable)fallbackTint
                             renderOriginal:(BOOL)original;


+ (UIColor *)pp_selectedCellColorFromPrimary;
+ (UIColor *)pp_selectedCellColorFromPrimaryFull;
+ (UIColor *)pp_selectedCellColorFromPrimaryWithAlpha:(float)cusAlpha;


@end


// Safe color fallback: if 'c' is nil, use fallback
static inline UIColor *PPColorOr(UIColor *c, UIColor *fallback) {
    return c ?: fallback;
}


 

@interface UIColor (HXEExtension)
+ (UIColor *)hx_colorWithHexStr:(NSString *)string;
+ (UIColor *)hx_colorWithHexStr:(NSString *)string alpha:(CGFloat)alpha;
+ (UIColor *)hx_colorWithR:(CGFloat)red g:(CGFloat)green b:(CGFloat)blue a:(CGFloat)alpha;
+ (NSString *)hx_hexStringWithColor:(UIColor *)color;
- (BOOL)hx_colorIsWhite;
@end







@interface UIView (PPGradient)

- (void)setBackgroundGradientFrom:(UIColor *)start
                     middleColor:(UIColor *)middle
                               to:(UIColor *)end
                            angle:(CGFloat)degrees
                      cornerRadius:(CGFloat)radius;

@end
NS_ASSUME_NONNULL_END
