//
//  PPFunc.h
//  Pure Pets
//
//  Created by SAM on 13/09/2025.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MainController.h"
#import "CompanyLocationVC.h"
@class MainKindsModel;

NS_ASSUME_NONNULL_BEGIN
 


// =======================================================
// MARK: - PPFunc
// Utility functions for icons and profile menu
// =======================================================

@interface PPFunc : NSObject
+ (NSString *)formattedPhoneNumber:(NSString *)raw;

+ (BOOL)PPUserCheck;
+ (void)reloadAppUI ;
+ (void)presentFloatingSheetFrom:(UIViewController *)presenter
                        sheetVC:(UIViewController *)sheetVC
                     detentStyle:(PPSheetDetentStyle)style;
+ (void)presentSheetFrom:(UIViewController *)presentingVC
                sheetVC:(UIViewController *)sheetVC
            detentStyle:(PPSheetDetentStyle)style;
+ (void)removeOldGradientsFromView:(UIView *)view ;
/// Places an icon at a given position inside a view
+ (void)PPPlaceIcon:(NSString *)icon
         onPostions:(IconPostions)Postions
             onView:(UIView *)view;

/// Shows profile menu popover from a given view

+ (UIView *)createEmptyModernCardView ;
+ (UIView *)createCircleViewHeight:(float)height ;

+ (UIImage *)fillEmptySidesWithBlur:(UIImage *)originalImage targetSize:(CGSize)targetSize;
+ (UIImage *)fillEmptySidesWithGradient:(UIImage *)originalImage targetSize:(CGSize)targetSize;
+ (NSDictionary *)ageInfoFromBirthday:(NSDate *)birthdate adultHood:(NSInteger)adultHood;

#pragma mark - 🔹 Add Bar Button (Right Side)
+ (void)addBarButtonToRightSide:(UIBarButtonItem *)barButton
                      inNavItem:(UINavigationItem *)navItem
             inNavigationController:(UINavigationController *)navController
                       animated:(BOOL)animated;
#pragma mark - 🔹 Remove Bar Button (Right Side)
+ (void)removeBarButtonFromRightSide:(UIBarButtonItem *)barButton
                            inNavItem:(UINavigationItem *)navItem
               inNavigationController:(UINavigationController *)navController
                            animated:(BOOL)animated;
@end
// ==================== END: PPFunc ======================





// =======================================================
// MARK: - UIImage Category (PPSymbol)
// Helpers for symbols, resizing, and template rendering
// =======================================================

@interface UIImage (PPSymbol)

+ (UIImage *)pp_symbolNamed:(NSString *)name;

/// Loads SF Symbol or asset with configuration
+ (UIImage *)pp_symbolNamed:(NSString *)name
                  pointSize:(CGFloat)pointSize
                     weight:(UIImageSymbolWeight)weight
                      scale:(UIImageSymbolScale)scale
                    palette:(NSArray<UIColor *> * _Nullable)palette
               makeTemplate:(BOOL)makeTemplate;

/// Resizes non-symbol image to match symbol point size
+ (UIImage *)pp_resizedImage:(UIImage *)image toPointSize:(CGFloat)pointSize;
+ (UIImage *)symbolicImageNamed:(NSString *)imageName
                         weight:(UIImageSymbolWeight)weight
                          scale:(UIImageSymbolScale)scale
                      pointSize:(CGFloat)pointSize;

@end

@interface UIImage (PPDominantColor)
- (UIColor *)pp_dominantColor;
@end

@interface UIImage (Crop)
- (void)pp_presentCircularCropperFromController:(UIViewController<TOCropViewControllerDelegate> *)controller;
+ (void)pp_presentCircularCropperWithImage:(UIImage *)image
                            fromController:(UIViewController<TOCropViewControllerDelegate> *)controller;
@end
// ==================== END: UIImage (PPSymbol) ==========








// =======================================================
// MARK: - UIButton Category (PPSymbol)
// Helpers for applying symbols and styles to buttons
// =======================================================

@interface UIButton (PPSymbol)

/// Applies a symbol or template image with tint/palette
- (void)pp_setSymbolNamed:(NSString *)name
                pointSize:(CGFloat)pointSize
                   weight:(UIImageSymbolWeight)weight
                    scale:(UIImageSymbolScale)scale
                     tint:(UIColor *)tint
                  palette:(NSArray<UIColor *> * _Nullable)palette;

/// Applies a circular style to the button
- (void)pp_setCircularStyleWithDiameter:(CGFloat)diameter
                             background:(UIColor *)background
                                   tint:(UIColor *)tint;

@end
// ==================== END: UIButton (PPSymbol) =========








// =======================================================
// MARK: - PPQuickActionItem
// Model representing one quick action
// =======================================================

typedef void (^PPActionHandler)(UIView *sender);

typedef NS_ENUM(NSInteger, ConfigFor) {
    ConfigForAppVC,
    ConfigForCardCell,
    ConfigForViewData,
    ConfigForViewDataBottom,
    ConfigForAdsViewer,
    ConfigForPetsAds
};
@interface PPQuickActionItem : NSObject
@property (nonatomic, assign) ConfigFor configFor;
@property (nonatomic, copy) PPActionHandler handler;
@property (nonatomic, copy) NSString *titleKey;       // Localized title key
@property (nonatomic, copy) NSString *subTitleKey;
@property (nonatomic, copy) NSString *iconName;       // Normal icon
@property (nonatomic, copy) NSString *iconNameOnTap;  // Icon when tapped
//@property (nonatomic, copy, nullable) void (^handler)(void);
 @property (nonatomic) CGFloat buttonWidth;
@property (nonatomic) BOOL enabled;
@property (nonatomic, copy, nullable) UIMenu *menu;
+ (instancetype)itemWithTitleKey:(NSString * _Nullable)titleKey
                     subTitleKey:(NSString * _Nullable)subTitleKey
                         iconName:(NSString * _Nullable)iconName
                   iconNameOnTap:(NSString * _Nullable)iconNameOnTap
                            width:(CGFloat)width
                       configFor:(ConfigFor)configFor
                            menu:(UIMenu * _Nullable)menu
                         enabled:(BOOL)enabled
                         handler:(PPActionHandler _Nullable)handler;

+ (instancetype)itemWithTitleKey:(NSString * _Nullable)titleKey
                         iconName:(NSString *_Nullable)iconName
                   iconNameOnTap:(NSString * _Nullable)iconNameOnTap
                            width:(CGFloat)width
                       configFor:(ConfigFor)configFor
                            menu:(UIMenu * _Nullable)menu
                         handler:(PPActionHandler _Nullable)handler;



@end
// ==================== END: PPQuickActionItem ===========

@interface CustomMenuView : UIView <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray<MainKindsModel *> *mainKindsArray;
@property (nonatomic, strong) UIFont *customFont;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, copy) void (^selectionHandler)(MainKindsModel *mainKind);

- (void)showFromView:(UIView *)sourceView;
- (void)dismiss;

@end




// =======================================================
// MARK: - PPQuickActionsView
// Custom view containing multiple quick action buttons
// =======================================================

@interface PPQuickActionsView : UIView


+ (void)presentCustomMenuWithCategories:(NSArray<MainKindsModel *> *)mainKindsArray
                                  font:(UIFont *)font
                             tintColor:(UIColor *)tintColor
                             fromView:(UIView *)sourceView
                                handler:(void(^)(MainKindsModel *mainKind))actionHandler;


/// Provide the actions to render (max 4 per row recommended)
- (void)setActions:(NSArray<PPQuickActionItem *> *)actions;
- (void)setActionsForCardViewr:(NSArray<PPQuickActionItem *> *)actions ;
/// Styling properties
@property (nonatomic) CGFloat buttonHeight;                  // Default 80
@property (nonatomic) CGFloat cornerRadius;                  // Default 18
@property (nonatomic, strong) UIColor *backgroundColorForButton;
@property (nonatomic, strong) UIColor *tintColorForIcon;
@property (nonatomic) CGFloat buttonWidth;
- (instancetype)initWithFrame:(CGRect)frame Spacing:(float)spacing;
@end
// ==================== END: PPQuickActionsView ==========








// =======================================================
// MARK: - PPActionBuilder
// Helper to convert FTPopOverMenuModel → UIAction
// =======================================================

//typedef void(^PPActionHandler)(UIAction *action);

@interface PPActionBuilder : NSObject

/// Convert one menu model → UIAction
+ (UIAction *)actionFromMenuModel:(FTPopOverMenuModel *)model
                          handler:(PPActionHandler)handler;

/// Convert array of menu models → array of UIActions
+ (NSArray<UIAction *> *)actionsFromMenuModels:(NSArray<FTPopOverMenuModel *> *)models
                                       handler:(PPActionHandler)handler;

@end
// ==================== END: PPActionBuilder =============







// =======================================================
// MARK: - PPActionButton
// Factory for creating styled UIActions
// =======================================================

@interface PPActionButton : NSObject

+ (UIMenu *)appActionsArrayfor:(nullable UIViewController *)superVC;
+ (UIMenu *)userActionsArrayfor:(nullable UIViewController *)superVC;


+ (UIMenu *)actionsArrayfor:(nullable UIViewController *)superVC
                 mainKinds:(NSArray<MainKindsModel *> *)mainKinds
                    handler:(void (^)(MainKindsModel *model))handler;
/// Create a UIAction with custom styling
+ (UIAction *)actionWithTitle:(NSString *)title
              systemImageName:(nullable NSString *)systemImageName
                         font:(nullable UIFont *)font
                        color:(nullable UIColor *)color
                      handler:(void (^)(UIAction *action))handler;
+ (UIMenu *)generateActionsForMainKind:(NSArray<MainKindsModel *> *)mainKindsArray
                             tintColor:(UIColor *)tintColor
                               handler:(void (^)(MainKindsModel *category))actionHandler;
/// 🔥 Preset Actions
+ (UIAction *)deleteActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)editActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)shareActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)infoActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)showProfileActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)showFavoritesActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)showMyAdsActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)servicesManagerActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)showProtectionActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)orderHistoryActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)settingsActionWithHandler:(void (^)(UIAction *action))handler;
+ (UIAction *)supportActionWithHandler:(void (^)(UIAction *action))handler;


+ (NSArray *)menuArray;
+ (UIMenu *)actionsArrayfor:(nullable UIViewController *)vc;

+ (UIMenu *)generateActionsForMainKind:(NSArray<MainKindsModel *> *)mainKindsArray
                                                font:(UIFont *)font
                                              tintColor:(UIColor *)tintColor
                                              rowHeight:(CGFloat)rowHeight
                                                 handler:(void(^)(MainKindsModel *mainKind))actionHandler;
// Helper function to determine the image for a PetCategory object
+ (UIImage *)imageForMainKind:(MainKindsModel *)mainKind;
+ (NSString *)pp_convertArabicToEnglish:(NSString *)str;
@end
// ==================== END: PPActionButton ==============








// =======================================================
// MARK: - PaddedLabel
// UILabel subclass with custom text insets
// =======================================================

@interface PaddedLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets textInsets;
- (void)setLineSpacing:(CGFloat)spacing;
- (void)setLineSpacing:(CGFloat)spacing text:(NSString *)text;
@end
// ==================== END: PaddedLabel =================








typedef NS_ENUM(NSInteger, PPIconButtonStyle) {
    PPIconButtonStyleGlass,   // blurred/glassy background (iOS 15+)
    PPIconButtonStylePlain,   // plain background
    PPIconButtonStyleTinted,  // apple's tinted style
    PPIconButtonStyleFilled,  // filled style
    PPIconButtonStyleGray,
    PPIconButtonStyleMine,// gray style
};

// =======================================================
// MARK: - PPButtonHelper
// Helper to create consistent styled buttons
// =======================================================

@interface PPButtonHelper : NSObject
+ (UIButton *)buttonWithTitle:(nullable NSString *)title
                    imageName:(nullable NSString *)imageName
                        style:(PPButtonTitleStyle)style
                       target:(nullable id)target
                       action:(nullable SEL)action;
+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                        buttonSide:(float)side
                            target:(id)target
                            action:(SEL)action;
+ (void)pp_setButton:(UIButton *)button title:(NSString *)title color:(UIColor *)color;
+ (UIButton *)pp_buttonSectionsTitle:(nullable NSString *)title;
+ (UIButton *)pp_glassBackgroundButtonWithCornerRadius:(CGFloat)radius
                                           maskedEdges:(CACornerMask)masked;
+ (UIButton *)buttonWithImageNamed:(nullable NSString *)imageName
               selectedImageNamed:(nullable NSString *)selectedImageNamed
                             width:(float)width
                            height:(float)height
                              menu:(nullable UIMenu *)menu
                            target:(nullable id)target
                            action:(nullable SEL)action;
+ (UIButton *)iconButtonTitle:(NSString *)title
                        Named:(NSString *)imageName
                         size:(CGFloat)btnSize
                         tint:(UIColor *)tint
              backgroundColor:(UIColor *)bg
                        style:(PPIconButtonStyle)style
                       target:(id)target
                       action:(nullable SEL)action
                accessibility:(NSString *)axLabel;

/// Creates a styled button with system/asset image
+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                            target:(id)target
                            action:(SEL)action;


+ (UIButton *)pp_NavBarButtonWithSystemName:(NSString *)imageName action:(SEL)action controller:(UIViewController *)controller;
//+ (UIButton *)pp_NavBarButtonWithSystemName:(NSString *)imageName action:(SEL)action;

+ (UIButton *)createButtonWithSystemName:(NSString *)systemName  pointSize:(CGFloat)pointSize;


+ (UIButton *)createButtonWithSystemName:(NSString *)systemName;

+ (UIButton *)pp_buttonWithTitle:(nullable NSString *)title
                            font:(nullable UIFont *)font
                       imageName:(nullable NSString *)imageName
                          target:(id)target
                          config:(UIButtonConfiguration *)config
                          action:(SEL)action;
+ (UIButton *)pp_buttonWithTitle:(nullable NSString *)title
                            font:(nullable UIFont *)font
                       textColor:(nullable UIColor *)textColor
                         corners:(float)corners
                       imageName:(nullable NSString *)imageName
                          target:(id)target
                          config:(UIButtonConfiguration *)config
                         btnSize:(CGFloat)btnSize
                          action:(nullable SEL)action;
+ (UIButton *)pp_buttonWithTitleForBar:(nullable NSString *)title
                       imageName:(nullable NSString *)imageName
                          target:(id)target
                                action:(nullable SEL)action;
+ (UIButton *)createTintWithSystemName:(NSString *)systemName pointSize:(CGFloat)pointSize;
+ (void)pp_setButton:(UIButton *)button title:(NSString *)title;
+ (UIButton *)pp_buttonForDataVCNavBar:(nullable NSString *)title
                       imageName:(nullable NSString *)imageName
                          target:(id)target
              dataViewNavBarButtonKind:(PPDataViewNavBarButtonKind)buttonKind;
@end
// ==================== END: PPButtonHelper ==============


 


 

@interface UIButton (PPStyle)

- (void)pp_setBgColor:(nullable UIColor *)bgColor;
- (void)pp_setIconWithImageName:(nullable NSString *)imageName
               systemImageName:(nullable NSString *)systemImageName
                      tintColor:(UIColor *)tintColor
                       alignment:(PPIconAlignment)alignment
                       iconSize:(CGFloat)iconSize
                       animated:(BOOL)animated;

- (void)pp_setTitle:(NSString *)title
               font:(UIFont *)font
          textColor:(UIColor *)textColor
          animation:(BOOL)animated;

- (void)pp_setTitle:(NSString *)title
               font:(UIFont *)font
              color:(UIColor *)color;
@end

 

// =======================================================
// MARK: - PPColorHelper
// Extracts main colors from an image (pastel/lightened)
// =======================================================

@interface PPColorHelper : NSObject

/// Extracts the two most dominant lightened colors from an image.
/// @param image Source UIImage
/// @param amount How much to lighten (0.0 = none, 0.2 = pastel-like)
+ (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image
                                        lightenAmount:(CGFloat)amount;

/// Lightens a given color by a specific amount
+ (UIColor *)lightenColor:(UIColor *)color amount:(CGFloat)amount;

/// Apply a gradient background to a view, with support for shadows
/// @param view Target view
/// @param startColor First color of gradient
/// @param endColor Second color of gradient
/// @param degrees Gradient angle in degrees (0 = left→right, 90 = top→bottom)
+ (void)setBackgroundGradientOnView:(UIView *)view
                               from:(UIColor *)startColor
                                  to:(UIColor *)endColor
                               angle:(CGFloat)degrees;



@end
// ==================== END: PPColorHelper ===============


NS_ASSUME_NONNULL_END






// =======================================================
// MARK: - pp_applyTwoToneTopColor
// Extracts main colors from an image (pastel/lightened)
// =======================================================
NS_ASSUME_NONNULL_BEGIN

@interface UIView (PPTwoTone)

/// Adds (or updates) a 50/50 vertical two-tone background with rounded corners and proper shadow.
/// - The split is crisp at 50% using duplicated color stops.
/// - Shadow is on the view's layer (not clipped), gradient is clipped via a mask.
/// - Call `pp_updateTwoToneIfNeeded` in layout to keep frames/paths correct.
- (void)pp_applyTwoToneTopColor:(UIColor *)topColor
                    bottomColor:(UIColor *)bottomColor
                   cornerRadius:(CGFloat)cornerRadius
                    shadowColor:(UIColor *)shadowColor
                  shadowOpacity:(CGFloat)shadowOpacity
                   shadowRadius:(CGFloat)shadowRadius
                   shadowOffset:(CGSize)shadowOffset;

/// Call this whenever bounds change (e.g., in viewDidLayoutSubviews).
- (void)pp_updateTwoToneIfNeeded;

@end

NS_ASSUME_NONNULL_END








NS_ASSUME_NONNULL_BEGIN

@interface LocationLabelUtils : NSObject

// Basic method with default styling
+ (void)updateLocationLabel:(UILabel *)label
               withCountry:(NSString *)country
                  isRTL:(BOOL)isRTL;

// Advanced method with full customization
+ (void)updateLocationLabel:(UILabel *)label
               withCountry:(NSString *)country
                  isRTL:(BOOL)isRTL
                pinImage:(UIImage * _Nullable)pinImage
                fontSize:(CGFloat)fontSize
               textColor:(UIColor *)textColor
      verticalOffset:(CGFloat)verticalOffset;

// Helper to get country from UserManager
+ (NSString *)getCurrentUserCountry;

@end




NS_ASSUME_NONNULL_END






















NS_ASSUME_NONNULL_BEGIN




@interface PPButtonFactory : NSObject
+ (UIButton *)buttonWithTitle:(NSString *)title
                   systemName:(NSString * _Nullable)systemName   // SF Symbol or nil
                   assetName:(NSString * _Nullable)assetName     // fallback image name or nil
                 imageOnRight:(BOOL)imageOnRight
                        height:(CGFloat)height                   // e.g. 44
                         style:(PPButtonStyle)style
                       target:(id)target
                       action:(SEL)action;

// Optional: update enabled look consistently
+ (void)applyEnabled:(BOOL)enabled toButton:(UIButton *)button;

// (from before) press animation
+ (void)pp_addPressAnimationToButton:(UIButton *)btn;

/*
 + (UIButton *)menuButtonWithTitle:(NSString *)title
                       systemImage:(NSString * _Nullable)systemImage
                             items:(NSArray<NSDictionary *> *)items
                    primaryHandler:(void (^ _Nullable)(void))primaryAction
                            target:(id _Nullable)target;
 */
+ (nullable UIMenu *)menuWithItems:(NSArray<NSDictionary *> *)items
                    primaryHandler:(void (^ _Nullable)(void))primaryHandler;
@end


















NS_ASSUME_NONNULL_END


















































#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPQuantityAnimationStyle) {
    PPQuantityAnimationStyleNone,
    PPQuantityAnimationStyleFloat,
    PPQuantityAnimationStyleFade
};

typedef NS_ENUM(NSInteger, PPCollapsingBehavior) {
    PPCollapsingBehaviorNone,
    PPCollapsingBehaviorCollapseOnOutsideTap
};

@class PPQuantityButton;

@protocol PPQuantityButtonDelegate <NSObject>
@optional
- (void)quantityButton:(PPQuantityButton *)button didChangeQuantity:(NSInteger)quantity;
@end

@interface PPQuantityButton : UIView

@property (nonatomic, weak) id<PPQuantityButtonDelegate> delegate;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) PPQuantityAnimationStyle animationStyle;
@property (nonatomic, assign) PPCollapsingBehavior collapsingBehavior;
 @property (nonatomic, copy) void (^didChangeQuantity)(PPQuantityButton *button,NSInteger quantity);
- (instancetype)initWithFrame:(CGRect)frame;
- (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated;
- (void)expandAnimated:(BOOL)animated;
- (void)collapseAnimated:(BOOL)animated;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UIButton *minusOrTrashButton;
@property (nonatomic, strong) UILabel *quantityLabel;
@property (nonatomic, assign) BOOL isExpanded;


@end


   
 
@interface UIScrollView (ScrollHelpers)

/// Smoothly scrolls to top with natural deceleration animation
- (void)pp_scrollToTopAnimated:(BOOL)animated;

@end



@interface PPImageButtonHelper : NSObject

/// Resize any image to fit inside a 44x44 button (aspect fit, centered)
+ (UIImage *)imageFor44ptButton:(UIImage *)image;

/// Advanced: custom button size (still aspect-fit & centered)
+ (UIImage *)image:(UIImage *)image
   forButtonSize:(CGSize)buttonSize
      imageInset:(CGFloat)inset;

@end


@interface AdvancedGlassView : UIView

@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CAShapeLayer *borderLayer;

// الطرق العامة
- (void)setupGlassEffect;
- (void)updateColorsForStyle:(UIUserInterfaceStyle)style
            withTransformer:(UIColor* (^)(UIColor *, UIUserInterfaceStyle))transformer;

@end



NS_ASSUME_NONNULL_END
