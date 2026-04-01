

//
//  UIViewController+PPNavBar.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 23/08/2025.
//

#import <UIKit/UIKit.h>
#import "PPNavigationController.h"


typedef NS_ENUM(NSUInteger, PPUserOnlineState) {
    PPUserOnlineStateOffline,
    PPUserOnlineStateOnline
};

@class UserModel;
@class ChatThreadModel;
 


NS_ASSUME_NONNULL_BEGIN

typedef void(^PPNavBarTapBlock)(void);

// Add near your other enums
typedef NS_ENUM(NSInteger, PPBarButtonPosition) {
    PPBarButtonPositionFirstLeft = 0,
    PPBarButtonPositionSecondLeft,
    PPBarButtonPositionFirstRight,
    PPBarButtonPositionSecondRight
};

typedef NS_ENUM(NSInteger, PPButtonConfigration) {
    PPButtonConfigrationGlass = 0,
    PPButtonConfigrationClearGlass,
    PPButtonConfigrationPromp,
    PPButtonConfigrationClearPromp,
    PPButtonConfigrationTinted,
    PPButtonConfigrationTintedBorderd,
    PPButtonConfigrationFilled
    
};


typedef NS_ENUM(NSInteger, PPNavBarBaseLayout) {
    PPNavBarBaseLayoutAuto = 0,   // uses Language.isRTL if available, otherwise system direction
    PPNavBarBaseLayoutLTR,        // [back][title][button]
    PPNavBarBaseLayoutRTL         // [button][title][back]
};

// Add near your other enums
typedef NS_ENUM(NSInteger, PPNavBarTitlePosition) {
    PPNavBarTitlePositionCenter = 0,
    PPNavBarTitlePositionLeft,
    PPNavBarTitlePositionRight,
    PPNavBarTitlePositionCenterSmall,
    PPNavBarTitlePositionTabBar
};

// ===== Associated keys =====
static const void *kPPNavBarViewKey  = &kPPNavBarViewKey;
static const void *kPPTitleLabelKey  = &kPPTitleLabelKey;
static const void *kPPLeftStackKey   = &kPPLeftStackKey;
static const void *kPPRightStackKey  = &kPPRightStackKey;
static const void *kPPButtonsDictKey = &kPPButtonsDictKey;
static const void *kPPTapBlockKey    = &kPPTapBlockKey;

// Base keys (so base layout can update/remove cleanly)
static NSString * const kPPKeyBaseBack   = @"__base_back";
static NSString * const kPPKeyBaseButton = @"__base_button";
static CGFloat    const kPPKeyBaseButtonSize = 44.0;
@interface UIViewController (PPNavBar)<UIGestureRecognizerDelegate>
- (void)pp_navBarForceRefresh;
- (void)pp_navBarResetAppearanceForBackgroundIsDark:(BOOL)isDark;
- (void)pp_disableTransparentStatusBar ;

// Safe Presentation Helper
- (void)safePresentViewController:(UIViewController *)vc
                         animated:(BOOL)animated
                       completion:(void (^)(void))completion;

- (void)pp_navBarForceTintColor:(UIColor *)tintColor;
- (void)pp_enableTransparentStatusBar;;
 

- (UIView * _Nullable)pp_navBarSetTitleViewCenteredSmallWidth:(UIView * _Nullable)titleView;

 
@property (nonatomic, strong) id presenceToken;


// Keep the old method working (center). New, flexible overloads:
- (UIView * _Nullable)pp_navBarForeTitleView:(UIView * _Nullable)navBarTitleView; // (unchanged behavior, center)

- (UIView * _Nullable)pp_navBarSetTitleView:(UIView * _Nullable)titleView
                                   position:(PPNavBarTitlePosition)position
                            replaceExisting:(BOOL)replaceExisting;

/// sugar
- (UIView * _Nullable)pp_navBarSetTitleViewOnLeft:(UIView * _Nullable)titleView replace:(BOOL)replaceExisting;
- (UIView * _Nullable)pp_navBarSetTitleViewOnRight:(UIView * _Nullable)titleView replace:(BOOL)replaceExisting;
- (UIView * _Nullable)pp_navBarSetTitleViewCentered:(UIView * _Nullable)titleView;
- (UIView *)pp_chatProfileHeaderViewWithUser:(UserModel *)user;
- (UIView *)pp_navBarAttachWithTitle:(NSString * _Nullable)titleString;
/// ===== Your original API (still works) =====
- (UIView *)pp_navBarWithOtherButton:(UIButton * _Nullable)otherBtn
                               title:(NSString * _Nullable)titleString;
- (void)pp_removeNavBar;
- (void)onBack:(UIButton *)sender;
- (void)onDissmiss;
- (void)onBackBar:(UIBarButtonItem *)sender;
- (UIButton *)pp_ButtonWithSystemName:(NSString *)symbolName action:(SEL _Nullable)action;
- (UIButton *)pp_ButtonForNav:(NSString *)imageName action:(SEL)action ;
/// ===== New: one-call “base” layout you described =====
/// Passing (button=nil, title=nil, showBack=NO) removes the bar (your [nil][nil][nil] rule).
- (UIView * _Nullable)pp_navBarApplyBase:(PPNavBarBaseLayout)layout
                                  button:(UIButton * _Nullable)button
                                   title:(NSString * _Nullable)title
                                showBack:(BOOL)showBack;

/// Sugar for your names:
- (UIView * _Nullable)PPLTRNavigationBarWithButton:(UIButton * _Nullable)button
                                             title:(NSString * _Nullable)title
                                          showBack:(BOOL)showBack;
- (UIView * _Nullable)PPRTLNavigationBarWithButton:(UIButton * _Nullable)button
                                             title:(NSString * _Nullable)title
                                          showBack:(BOOL)showBack;

/// ===== Extra controls (optional) =====
- (void)pp_navBarSetTitle:(NSString * _Nullable)titleString;
- (void)pp_navBarSetVisible:(BOOL)visible animated:(BOOL)animated;




// Keyed icon buttons (advanced)
- (UIButton *)pp_navBarSetRightIcon:(NSString *)systemImage key:(NSString *)key
                             target:(id _Nullable)target action:(SEL _Nullable)action
                                tap:(PPNavBarTapBlock _Nullable)tapBlock;
- (UIButton *)pp_navBarSetLeftIcon:(NSString *)systemImage  key:(NSString *)key
                            target:(id _Nullable)target action:(SEL _Nullable)action
                               tap:(PPNavBarTapBlock _Nullable)tapBlock;
- (void)pp_navBarHideButtonForKey:(NSString *)key hidden:(BOOL)hidden animated:(BOOL)animated;
- (void)pp_navBarRemoveButtonForKey:(NSString *)key;

- (void)forceReplaceRightButtonWith:(UIButton *)btn;
- (void)forceReplaceLeftButtonWith:(UIButton *)btn;

- (UIView * _Nullable)pp_viewWithImageName:(NSString * _Nullable)imageName andTitle:(NSString * _Nullable)title;

/** 🔻 Added new methods for forcing custom views on left/right of nav bar */
- (UIView * _Nullable)PPNavBarForceLeftView:(UIView *)navBarTitleView;
- (UIView * _Nullable)PPNavBarForceRightView:(UIView *)navBarTitleView;


//-(void)onBack;
- (UIView * _Nullable)pp_viewWithImage:(UIImage * _Nullable)imageName
                                andTitle:(NSString * _Nullable)title
                             andSubtitle:(NSString * _Nullable)subtitle
                               userModel:(UserModel * _Nullable)usr;

- (UIView * _Nullable)pp_Profile26Image:(UIImage * _Nullable)image
                              andTitle:(NSString * _Nullable)title
                           andSubtitle:(NSString * _Nullable)subtitle
                              userModel:(UserModel * _Nullable)usr;
- (void)_pp_addRightButton:(UIButton *)btn key:(NSString *)key;

- (UIView * _Nullable)pp_viewWithTitle:(NSString * _Nullable)title
                              Subtitle:(NSString * _Nullable)subtitle
                                 Image:(UIImage * _Nullable)image
                         showBackround:(BOOL)showBackround;
- (UIButton * _Nullable)pp_viewWithTitle:(NSString * _Nullable)title
                                Subtitle:(NSString * _Nullable)subtitle
                               textColor:(UIColor * _Nullable)textColor
                                   Image:(UIImage * _Nullable)image
                           showBackround:(BOOL)showBackround;

- (void)onBack;

- (void)addLiquidGlassBorderToView:(UIView *)view;
- (UIButton *)pp_ZeroButtonWithSystemName:(NSString *)imageName action:(nullable SEL)action;

/// Lock navigation & status bar to fixed tint and text color (no auto theme switching)
+ (void)lockNavBarAppearanceWithTint:(UIColor *)tintColor
                          titleColor:(UIColor *)titleColor
                         statusStyle:(UIStatusBarStyle)statusStyle;


+ (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style;
+ (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style configType:(PPButtonConfigration)configType;
@end

NS_ASSUME_NONNULL_END



 

/*
// Reusable containers (image, title, subtitle, badge) + tap support
- (UIView *)addContainerOnLeftWithImageurl:(NSString * _Nullable)url
                     imagePlaceHolderName:(NSString * _Nullable)placeholder
                                    title:(NSString * _Nullable)title
                                 subtitle:(NSString * _Nullable)subtitle
                                    badge:(NSInteger)badge;

- (UIView *)addContainerOnRightWithImageurl:(NSString * _Nullable)url
                       imagePlaceHolderName:(NSString * _Nullable)placeholder
                                      title:(NSString * _Nullable)title
                                   subtitle:(NSString * _Nullable)subtitle
                                      badge:(NSInteger)badge;

// Optional: set a tap block on any returned container (you asked for tap support)
- (void)pp_setTapOnNavContainer:(UIView *)container block:(PPNavBarTapBlock)block;
*/








/*
 
 
 //
 //  UIViewController.h
 //  PurePetsAdmin
 //
 //  Created by Mohammed Ahmed on 23/08/2025.
 //


 #import <UIKit/UIKit.h>

 NS_ASSUME_NONNULL_BEGIN

 typedef void(^PPNavBarTapBlock)(void);

 typedef NS_ENUM(NSInteger, PPNavBarBaseLayout) {
     PPNavBarBaseLayoutAuto = 0,   // uses Language.isRTL if available, otherwise system direction
     PPNavBarBaseLayoutLTR,        // [back][title][button]
     PPNavBarBaseLayoutRTL         // [button][title][back]
 };

 // ===== Associated keys =====
 static const void *kPPNavBarViewKey  = &kPPNavBarViewKey;
 static const void *kPPTitleLabelKey  = &kPPTitleLabelKey;
 static const void *kPPLeftStackKey   = &kPPLeftStackKey;
 static const void *kPPRightStackKey  = &kPPRightStackKey;
 static const void *kPPButtonsDictKey = &kPPButtonsDictKey;
 static const void *kPPTapBlockKey    = &kPPTapBlockKey;

 // Base keys (so base layout can update/remove cleanly)
 static NSString * const kPPKeyBaseBack   = @"__base_back";
 static NSString * const kPPKeyBaseButton = @"__base_button";

 @interface UIViewController (PPNavBar)

 /// ===== Your original API (still works) =====
 - (UIView *)pp_navBarWithOtherButton:(UIButton * _Nullable)otherBtn
                                title:(NSString * _Nullable)titleString;
 - (void)pp_removeNavBar;


 - (UIButton *)pp_ButtonWithSystemName:(NSString *)symbolName action:(SEL)action;

 /// ===== New: one-call “base” layout you described =====
 /// Passing (button=nil, title=nil, showBack=NO) removes the bar (your [nil][nil][nil] rule).
 - (UIView * _Nullable)pp_navBarApplyBase:(PPNavBarBaseLayout)layout
                                   button:(UIButton * _Nullable)button
                                    title:(NSString * _Nullable)title
                                 showBack:(BOOL)showBack;

 /// Sugar for your names:
 - (UIView * _Nullable)PPLTRNavigationBarWithButton:(UIButton * _Nullable)button
                                              title:(NSString * _Nullable)title
                                           showBack:(BOOL)showBack;
 - (UIView * _Nullable)PPRTLNavigationBarWithButton:(UIButton * _Nullable)button
                                              title:(NSString * _Nullable)title
                                           showBack:(BOOL)showBack;

 /// ===== Extra controls (optional) =====
 - (void)pp_navBarSetTitle:(NSString * _Nullable)titleString;
 - (void)pp_navBarSetVisible:(BOOL)visible animated:(BOOL)animated;

 // Keyed icon buttons (advanced)
 - (UIButton *)pp_navBarSetRightIcon:(NSString *)systemImage key:(NSString *)key
                              target:(id _Nullable)target action:(SEL _Nullable)action
                                 tap:(PPNavBarTapBlock _Nullable)tapBlock;
 - (UIButton *)pp_navBarSetLeftIcon:(NSString *)systemImage  key:(NSString *)key
                              target:(id _Nullable)target action:(SEL _Nullable)action
                                 tap:(PPNavBarTapBlock _Nullable)tapBlock;
 - (void)pp_navBarHideButtonForKey:(NSString *)key hidden:(BOOL)hidden animated:(BOOL)animated;
 - (void)pp_navBarRemoveButtonForKey:(NSString *)key;


 - (void)forceReplaceRightButtonWith:(UIButton *)btn;
 - (void)forceReplaceLeftButtonWith:(UIButton *)btn;

 - (UIView * _Nullable)pp_navBarForeTitleView:(UIView *)navBarTitleView;
 - (UIView * _Nullable)pp_viewWithImage:(NSString *)imageName andTitle:(NSString *)title;

 @end

 NS_ASSUME_NONNULL_END



 
 
 */
