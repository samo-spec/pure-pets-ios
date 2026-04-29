//
//  Styling.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 21/08/2025.
//

//
//  Styling.h
//  PurePetsAdmin
//

#import <UIKit/UIKit.h>
#import "PPHUD.h"
#import "PPAlertHelper.h"
@class XLFormRowDescriptor;
@class LOTAnimationView;
NS_ASSUME_NONNULL_BEGIN

 

@interface UIView (CornerMask)

+ (void)applyCornerMaskToGradientLayer:(CAGradientLayer *)layer
                                    tl:(CGFloat)tl
                                    tr:(CGFloat)tr
                                    bl:(CGFloat)bl
                                    br:(CGFloat)br;

@end



@interface Styling : NSObject

/// Reusable style helper: rounded corners, border, shadow
+ (void)applyStyleWithCornerRadius:(CGFloat)cornerRadius
                     backgroundColor:(UIColor *)backgroundColor
                         borderColor:(nullable UIColor *)borderColor
                         borderWidth:(CGFloat)borderWidth
                           addShadow:(BOOL)addShadow
                              toView:(UIView *)view;

/// Short version → references full method but ignores backgroundColor & borderWidth
+ (void)applyStyleWithCornerRadius:(CGFloat)cornerRadius
                        borderColor:(nullable UIColor *)borderColor
                          addShadow:(BOOL)addShadow
                             toView:(UIView *)view;

/// Preset: Card style (rounded, shadow, white bg)
+ (void)applyCardStyleToView:(UIView *)view;

/// Preset: Button style (rounded pill, primary bg, shadow)
+ (void)applyIconButtonStyle:(UIButton *)button
                   tintColor:(UIColor *)tintColor
             backgroundColor:(UIColor *)backgroundColor;

/// Preset: Header style (flat bg, no shadow, bold look)
+ (void)applyHeaderStyleToView:(UIView *)view;

+ (UIFont *)fontBold:(CGFloat)size;
+ (UIFont *)fontMedium:(CGFloat)size;
+ (UIFont *)fontRegular:(CGFloat)size;

+ (void)applyButtonTextStyle:(UIButton *)button
                        size:(CGFloat)pointSize
                      weight:(UIFontWeight)weight
                       scale:(UIFontTextStyle)scale; // e.g. UIFontTextStyleBody

+ (void)applyButtonIconStyle:(UIButton *)button
                   tintColor:(UIColor *)tintColor
             backgroundColor:(UIColor *)backgroundColor
                cornerRadius:(CGFloat)cornerRadius
            symbolPointSize:(CGFloat)pointSize
                     weight:(UIImageSymbolWeight)weight
                       scale:(UIImageSymbolScale)scale;

/// Apply rounded corners + shadow to a grouped table cell
+ (void)applyGroupCellStyle:(UITableViewCell *)cell
               atIndexPath:(NSIndexPath *)indexPath
                inTableView:(UITableView *)tableView;

// ✅ Lottie Helpers
+ (void)setAnimationNamed:(NSString *)fileName
                   toView:(LOTAnimationView *)lot
                withSpeed:(float)animationSpeed
               completion:(void (^)(BOOL success))completion;

+ (void)setAnimationNamed:(NSString *)fileName
                   toView:(LOTAnimationView *)lot
                withSpeed:(float)animationSpeed
            loopAnimation:(BOOL)loopAnimation
                 autoplay:(BOOL)autoplay
               completion:(void (^)(BOOL success))completion;

+ (void)fetchLottieJSONFromFirebasePath:(NSString *)storagePath
                             completion:(void (^)(NSDictionary *jsonDict, NSError *error))completion;

+ (void)setRowFonts:(XLFormRowDescriptor *)row;
+ (void)setRowButtonStyle:(XLFormRowDescriptor *)row;

+ (void)setupFormAppearance;

+ (void)applyGlobalStyleToRow:(XLFormRowDescriptor *)row;

/// Apply background style to a cell (Row-Card or Section-Card mode)
+ (void)applyBackgroundStyleForTableView:(UITableView *)tableView
                                    cell:(UITableViewCell *)cell
                               indexPath:(NSIndexPath *)indexPath
                           useRowCardMode:(BOOL)useRowCardMode;

+ (void)applyCorner:(CGFloat)cornerRadius
   backgroundColor:(UIColor *)backgroundColor
             toView:(UIView *)view;


// New signature
+ (void)applyBackgroundStyleForTableView:(UITableView *)tableView
                                   cell:(UITableViewCell *)cell
                              indexPath:(NSIndexPath *)indexPath
                          useRowCardMode:(BOOL)useRowCardMode
                        buttonRowIndex:(NSInteger)buttonRowIndex
                          buttonSection:(NSInteger)buttonSection;


/// Unified container creator – supports both iOS 26+ and older
+ (UIButton *)createContainerInParent:(UIView *)parentView withBgColor:(UIColor * _Nullable)backgroundColor;

+ (void)applyCornerMaskToView:(UIView *)view
                           tl:(CGFloat)tl
                           tr:(CGFloat)tr
                           bl:(CGFloat)bl
                           br:(CGFloat)br;

+ (void)addLiquidGlassBorderToView:(UIView *)view;
+ (void)addLiquidGlassBorderToView:(UIView *)view cornerRadius:(float)cornerRadius;
+ (nullable UIView *)addBgForOldIOSOn:(UIView *)container Corners:(float)corners
                          Constraints:(nullable void (^)(UIView *bgView))constraintsBlock;
+ (void)addLiquidGlassBorderToView:(UIView *)view  cornerRadius:(float)cornerRadius color:(UIColor *)color;

+ (void)addBlurToView:(UIView *)targetView
           blurStyle:(UIBlurEffectStyle)style
        cornerRadius:(CGFloat)cornerRadius
               alpha:(CGFloat)alpha
     insertAtPosition:(NSInteger)index;

#pragma mark - Design System Presets (PPDesignTokens)

/// Apply elevated card style — rounded corners, continuous curve, shadow.
/// Uses PPCornerLarge (24pt) and elevated shadow preset.
+ (void)applyElevatedCardStyleToView:(UIView *)view;

/// Apply subtle card style — lighter shadow, standard corners.
/// Uses PPCornerMedium (18pt) and card shadow preset.
+ (void)applySubtleCardStyleToView:(UIView *)view;

/// Apply primary CTA button style — filled background, pill shape.
/// Sets background to AppPrimaryClr, white title, PPCornerPill, min height PPButtonHeightLG.
+ (void)applyPrimaryCTAStyleToButton:(UIButton *)button;

/// Apply secondary CTA button style — bordered, transparent.
/// Sets border, AppPrimaryClr tint, PPCornerPill.
+ (void)applySecondaryCTAStyleToButton:(UIButton *)button;

/// Apply glass overlay style — translucent white background with border.
/// Suitable for chips, pills, overlays on gradients.
+ (void)applyGlassStyleToView:(UIView *)view cornerRadius:(CGFloat)cornerRadius;

@end







/* ********************************************************************** UISegmentedControl ************************************************************************************ */

@interface UISegmentedControl (Rounded)

- (void)applyRoundedStyleWithRadius:(CGFloat)radius
                         tintColor:(UIColor *)tint
                      backgroundColor:(UIColor *)background;

@end
NS_ASSUME_NONNULL_END






 

NS_ASSUME_NONNULL_BEGIN
static NSString * const kUserInterfaceStyleKey = @"UserInterfaceStylePreference";

@interface PPThemeManager : NSObject

+ (instancetype)sharedManager;

/// حفظ النمط (Light / Dark / System)
- (void)saveUserInterfaceStyle:(UIUserInterfaceStyle)style;

/// استرجاع النمط المحفوظ
- (UIUserInterfaceStyle)loadUserInterfaceStyle;

/// تطبيق النمط الحالي على نافذة التطبيق
- (void)applySavedInterfaceStyleToWindow:(UIWindow *)window;

/// تبديل النمط الحالي (Light ↔️ Dark)
- (void)toggleUserInterfaceStyleForWindow:(UIWindow *)window;

/// Apply a specific style (Light / Dark / System) with animation
- (void)applyInterfaceStyle:(UIUserInterfaceStyle)style toWindow:(UIWindow *)window;

@end

NS_ASSUME_NONNULL_END
