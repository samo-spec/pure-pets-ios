//
//  PPBottomBarView.m
//  PurePets
//

#import "PPRootTabBarController.h"
#import "PPHomeViewController.h"
#import "PPSearchViewController.h"
#import "SettingVC.h"
#import "PPCommerceFeedbackManager.h"
#import "UserModel.h"
#import "PPRolePermission.h"
#import "UserManager.h"
#import "AppClasses.h"
#import "PPIntroViewController.h"
#import "PPUserMenuViewController.h"
#import "PPModernAvatarRenderer.h"
#if __has_include(<Lottie/Lottie.h>)
#import <Lottie/Lottie.h>
#elif __has_include("Lottie.h")
#import "Lottie.h"
#elif __has_include(<lottie-ios_Oc/Lottie.h>)
#import <lottie-ios_Oc/Lottie.h>
#elif __has_include(<lottie_ios_Oc/Lottie.h>)
#import <lottie_ios_Oc/Lottie.h>
#else
@class LOTAnimationView;
#endif

#import "SettingVC.h"
#import "PPNotificationsHubViewController.h"
#import "PPNovaChatViewController.h"
#import "ChMessagingController.h"
#import "CartManager.h"
#import "PPBottomSurfaceCoordinator.h"
#import "UIViewController+PPBottomSurface.h"
#import <Pure_Pets-Swift.h>
#import <SDWebImage/SDImageCache.h>
#import <objc/runtime.h>

// ...




static NSString * const kPPBlockedOverlaySupportPhoneNumber = @"+97459997720";
typedef NS_ENUM(NSInteger, PPRootTabIndex) {
    PPRootTabIndexHome = 0,
    PPRootTabIndexMyAds = 1,
    PPRootTabIndexAdd = 2,
    PPRootTabIndexChats = 3,
    PPRootTabIndexMenu = 4,
    // Legacy names kept as aliases for existing profile/menu helper paths.
    PPRootTabIndexOrders = PPRootTabIndexMenu,
    PPRootTabIndexSettings = PPRootTabIndexMenu
};
static NSString * const PPNovaFloatingVisibilityDidChangeNotification = @"PPNovaFloatingVisibilityDidChangeNotification";
static NSString * const PPNovaFloatingVisibilityValueKey = @"visible";
static NSString * const PPNovaFloatingVisibleDefaultsKey = @"pp_nova_floating_visible";
static NSString * const PPHomeConfigCacheKey = @"PPHomeConfig.cache.v1";
static NSString * const PPHomeConfigCacheNovaFloatingVisibleKey = @"novaFloatingVisible";
static CGFloat const PPCartFloatingBarHeight = 56.0;
static CGFloat const PPCartFloatingBarRestingBottomConstant = 16.0;
static CGFloat const PPCartFloatingBarHiddenBottomConstant = 28.0;
static CGFloat const PPCartFloatingBarClearancePadding = 12.0;

@class PPPremiumDockBarDelegate;
@class PPCartFloatingBarCoordinator;

@interface PPRootTabBarController () <UINavigationControllerDelegate>
{
    BOOL _useLegacyBar;
    BOOL _hasSetUseLegacyBar;
}
@property (nonatomic, strong) UIButton *leadingTabButton;
@property (nonatomic, strong) UIButton *trailingTabButton;
@property (nonatomic, strong) UIButton *emptyCard;

@property (nonatomic, strong) UITabBar *premiumTabbarView;
@property (nonatomic, strong) PPPremiumDockBarDelegate *premiumDockDelegate;
@property (nonatomic, strong) UIView *premiumBottomFadeView;
- (void)pp_premiumDockDidSelectItem:(UITabBarItem *)item;
- (void)pp_setupPremiumBottomFade;
- (void)pp_updatePremiumBottomFadeAppearance;
@property (nonatomic, strong) NSArray<UITabBarItem *> *premiumTabItems;
@property (nonatomic, strong) UIButton *premiumNovaButton;
@property (nonatomic, strong, nullable) LOTAnimationView *premiumNovaLottieView;
@property (nonatomic, strong, nullable) LOTAnimationView *guestProfileLottieView;
@property (nonatomic, strong, nullable) LOTColorValueCallback *guestProfileLottieColorCallback;
@property (nonatomic, assign) BOOL guestProfileLottieLoading;
@property (nonatomic, assign) BOOL guestProfileLottieReady;
@property (nonatomic, assign) BOOL premiumNovaVisibleByConfiguration;
@property (nonatomic, assign) BOOL premiumBottomNavigationHidden;
@property (nonatomic, assign) BOOL premiumNavigationDidAnimateIn;
@property (nonatomic, strong) CAGradientLayer *bottomFadeLayer;
@property (nonatomic, strong) CALayer *tabBarTopSeparatorLayer;
@property (nonatomic, assign) CGFloat premiumDockAppliedItemWidth;
@property (nonatomic, assign) NSInteger premiumMyAdsRootTabIndex;
@property (nonatomic, strong, nullable) UIControl *blockedOverlayView;
@property (nonatomic, strong, nullable) UIView *blockedOverlayCardView;
@property (nonatomic, strong, nullable) LOTAnimationView *blockedHeaderAnimationView;
@property (nonatomic, strong, nullable) UIButton *blockedContactButton;
@property (nonatomic, strong, nullable) NSLayoutConstraint *blockedOverlayTopConstraint;
@property (nonatomic, assign) NSInteger pp_lastSelectedIndex;
@property (nonatomic, strong, nullable) UIViewController *addActionPlaceholderViewController;
@property (nonatomic, assign) BOOL didAttemptIntroPresentation;
@property (nonatomic, strong, nullable) PPIntroViewController *activeIntroViewController;
@property (nonatomic, strong) PPCartFloatingBarCoordinator *cartFloatingBarCoordinator;
- (CGFloat)pp_bottomNavigationContentClearance;
- (void)pp_applyBottomNavigationClearanceToVisibleLists;
- (void)pp_applyBottomNavigationClearance:(CGFloat)clearance toListViewsInView:(UIView *)view;
- (UIViewController *)pp_makeAddActionPlaceholderViewController;
- (UIViewController *)pp_makeSettingsRootViewController;
- (void)pp_applyPremiumTabBarItemMetrics:(UITabBarItem *)item centerAction:(BOOL)centerAction;
- (void)pp_refreshLegacyTabBarTitleLayout;
- (nullable UILabel *)pp_tabBarTitleLabelForItem:(UITabBarItem *)item;
- (nullable UILabel *)pp_titleLabelInView:(UIView *)view matchingTitle:(NSString *)title;
- (nullable UINavigationController *)pp_preferredNavigationControllerForSearchExperience;
- (nullable PPSearchViewController *)pp_existingSearchControllerInNavigationController:(UINavigationController *)navigationController;
- (void)pp_openSearchExperienceFromCurrentContextOpeningAccessories:(BOOL)openAccessories;
- (void)pp_setupPremiumBottomNavigation;
- (void)pp_setupPremiumNovaButton;
- (void)pp_novaButtonTapped;
- (void)pp_handleNovaFloatingVisibilityUpdate:(NSNotification *)notification;
- (BOOL)pp_cachedNovaFloatingVisibility;
- (void)pp_updatePremiumNovaButtonVisibility;
- (NSInteger)pp_resolvedMyAdsRootTabIndex;
- (BOOL)pp_isResolvedMyAdsRootTabIndex:(NSInteger)index;
- (UIImage *)pp_premiumSymbolForTabIndex:(NSInteger)index selected:(BOOL)selected;
- (UIImage *)pp_profileTabItemImageSelected:(BOOL)selected;
- (UIImage *)pp_userMenuTabAvatarImageSelected:(BOOL)selected;
- (void)pp_prepareGuestProfileAnimationIfNeeded;
- (void)pp_applyGuestProfileAnimationTint;
- (void)pp_refreshProfileTabPresentation;
- (void)pp_layoutGuestProfileAnimation;
- (void)pp_updateGuestProfileAnimationPlayback;
- (void)pp_refreshGuestProfileAnimationAfterSelection;
- (void)pp_handleProfileAuthenticationChange:(NSNotification *)notification;
- (void)pp_handleReduceMotionStatusChange:(NSNotification *)notification;
- (void)pp_applyPremiumTabSelectionAnimated:(BOOL)animated;
- (void)pp_animatePremiumBottomNavigationEntranceIfNeeded;
- (void)pp_premiumControlTouchDown:(UIButton *)sender;
- (void)pp_premiumControlTouchUp:(UIButton *)sender;
- (void)pp_setPremiumBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated;
- (void)pp_updatePremiumChatsBadgeWithCount:(NSInteger)count;
- (void)pp_updateTabBarSelectionIndicatorIfNeeded;
 - (UIImage *)pp_tabBarSelectionIndicatorImageForItemSize:(CGSize)itemSize
                                           indicatorSize:(CGSize)indicatorSize
                                               fillColor:(UIColor *)fillColor
                                             strokeColor:(UIColor *)strokeColor;
- (void)pp_raiseBelowIOS26AddButtonAboveSystemTabBar;
@end

#pragma mark - Premium Dock Delegate

// The premium dock is a standalone UITabBar. Its delegate must NOT be the
// UITabBarController itself: UIKit would then run its items-vs-viewControllers
// consistency check on the dock's foreign items and crash on selection
// (NSInternalInconsistencyException: "No view controller matches the UITabBarItem").
// Routing selection through a dedicated object avoids that association.
@interface PPPremiumDockBarDelegate : NSObject <UITabBarDelegate>
@property (nonatomic, weak) PPRootTabBarController *controller;
@end

@implementation PPPremiumDockBarDelegate
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    [self.controller pp_premiumDockDidSelectItem:item];
}
@end

@interface PPPremiumDockTabBar : UITabBar
@property (nonatomic, strong) UIFont *pp_titleFont;
@end

@implementation PPPremiumDockTabBar

- (nullable UILabel *)pp_titleLabelInView:(UIView *)view matchingTitle:(NSString *)title
{
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if ([label.text isEqualToString:title]) {
            return label;
        }
    }
    for (UIView *subview in view.subviews) {
        UILabel *matchingLabel = [self pp_titleLabelInView:subview matchingTitle:title];
        if (matchingLabel) {
            return matchingLabel;
        }
    }
    return nil;
}

- (nullable UIView *)pp_itemViewForItem:(UITabBarItem *)item
{
    @try {
        id candidate = [item valueForKey:@"view"];
        return [candidate isKindOfClass:UIView.class] ? candidate : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    for (UITabBarItem *item in self.items) {
        if (item.title.length == 0) {
            continue;
        }

        UIView *itemView = [self pp_itemViewForItem:item];
        if (!itemView || CGRectGetWidth(itemView.bounds) <= 0.0) {
            continue;
        }

        UILabel *titleLabel = [self pp_titleLabelInView:itemView matchingTitle:item.title];
        if (!titleLabel) {
            continue;
        }

        titleLabel.font = self.pp_titleFont ?: titleLabel.font;
        titleLabel.numberOfLines = 1;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.82;
        titleLabel.allowsDefaultTighteningForTruncation = YES;

        // UIKit can preserve a launch-time label width calculated before the
        // dock's constraints settle. Expand only the title's horizontal frame
        // inside its own item while preserving UIKit's vertical placement.
        CGFloat availableWidth = MAX(0.0, CGRectGetWidth(itemView.bounds) - 8.0);
        CGRect labelFrameInItem = [itemView convertRect:titleLabel.frame
                                               fromView:titleLabel.superview];
        labelFrameInItem.origin.x = (CGRectGetWidth(itemView.bounds) - availableWidth) * 0.5;
        labelFrameInItem.size.width = availableWidth;
        CGRect resolvedFrame = [titleLabel.superview convertRect:labelFrameInItem
                                                         fromView:itemView];
        titleLabel.frame = CGRectMake(CGRectGetMinX(resolvedFrame),
                                      CGRectGetMinY(titleLabel.frame),
                                      CGRectGetWidth(resolvedFrame),
                                      CGRectGetHeight(titleLabel.frame));
        titleLabel.preferredMaxLayoutWidth = availableWidth;
    }
}

@end

static char PPListBaseContentInsetKey;
static char PPListBaseIndicatorInsetKey;
static char PPListAppliedBottomClearanceKey;
static void *kPPTabBarHiddenObservationContext = &kPPTabBarHiddenObservationContext;

// Gradient-backed view: the layer auto-resizes with the view's bounds, so the
// bottom fade tracks layout without manual frame updates.
@interface PPBottomFadeView : UIView
@end

@implementation PPBottomFadeView
+ (Class)layerClass { return [CAGradientLayer class]; }
@end

static NSString *PPCartFloatingBarCountText(NSInteger itemCount)
{
    NSString *format = itemCount == 1 ? kLang(@"myitems_count_single") : kLang(@"myitems_count_format");
    if (format.length == 0) {
        format = itemCount == 1 ? @"1 item" : @"%ld items";
    }
    if (itemCount == 1 && ![format containsString:@"%"]) {
        return format;
    }
    return [NSString stringWithFormat:format, (long)itemCount];
}

static NSString *PPCartFloatingBarAmountText(double totalAmount)
{
    NSString *formatted = [GM formatPrice:@(MAX(0.0, totalAmount)) currencyCode:kLang(@"Rials")];
    if (formatted.length == 0) {
        NSString *currencyCode = kLang(@"Rials");
        if (currencyCode.length == 0) {
            currencyCode = @"QAR";
        }
        formatted = [NSString stringWithFormat:@"%.2f %@", MAX(0.0, totalAmount), currencyCode];
    }
    return formatted;
}

@interface PPCartFloatingBarState : NSObject
@property (nonatomic, assign) NSInteger itemCount;
@property (nonatomic, assign) double totalAmount;
@property (nonatomic, assign, getter=isVisible) BOOL visible;
@end

@implementation PPCartFloatingBarState
@end

@interface PPCartFloatingBarView : UIControl
@property (nonatomic, strong) UIButton *materialView;
@property (nonatomic, strong) UIView *tintOverlayView;
@property (nonatomic, strong) UIView *highlightGlowView;
@property (nonatomic, strong) UIView *iconOrbView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *countBadgeLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *ctaContainerView;
@property (nonatomic, strong) UILabel *ctaLabel;
@property (nonatomic, strong) UIImageView *ctaChevronView;
@property (nonatomic, strong) CAGradientLayer *borderGradientLayer;
@property (nonatomic, strong) CAShapeLayer *borderMaskLayer;
@property (nonatomic, strong) UIImpactFeedbackGenerator *tapFeedbackGenerator;
@property (nonatomic, assign, getter=isCollapsed) BOOL collapsed;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *expandedConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *collapsedConstraints;
- (void)setCollapsed:(BOOL)collapsed animated:(BOOL)animated;
@end

@implementation PPCartFloatingBarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.accessibilityTraits = UIAccessibilityTraitButton;

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleSystemUltraThinMaterialLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemChromeMaterial;
    }
    self.materialView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
    self.materialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.materialView.userInteractionEnabled = NO;
    self.materialView.clipsToBounds = YES;
    self.materialView.layer.cornerRadius = 28.0;
    [self addSubview:self.materialView];

    self.tintOverlayView = [[UIView alloc] init];
    self.tintOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tintOverlayView.userInteractionEnabled = NO;
    [self.materialView addSubview:self.tintOverlayView];

    self.highlightGlowView = [[UIView alloc] init];
    self.highlightGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.highlightGlowView.userInteractionEnabled = NO;
    self.highlightGlowView.alpha = 0.92;
    [self.materialView addSubview:self.highlightGlowView];

    UIView *contentView = self.materialView;

    self.iconOrbView = [[UIView alloc] init];
    self.iconOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconOrbView.userInteractionEnabled = NO;
    self.iconOrbView.layer.cornerRadius = 20.0;
    self.iconOrbView.layer.shadowOpacity = 0.16;
    self.iconOrbView.layer.shadowRadius = 14.0;
    self.iconOrbView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [contentView addSubview:self.iconOrbView];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                                                              weight:UIImageSymbolWeightSemibold
                                                                                               scale:UIImageSymbolScaleMedium];
    self.iconImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"cart.fill" withConfiguration:iconConfig]];
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.iconOrbView addSubview:self.iconImageView];

    self.countBadgeLabel = [[UILabel alloc] init];
    self.countBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countBadgeLabel.font = [GM boldFontWithSize:11.0];
    self.countBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.countBadgeLabel.layer.cornerRadius = 11.0;
    self.countBadgeLabel.layer.masksToBounds = YES;
    [contentView addSubview:self.countBadgeLabel];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:16.0];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.82;
    [contentView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:13.0];
    self.subtitleLabel.numberOfLines = 1;
    self.subtitleLabel.adjustsFontSizeToFitWidth = YES;
    self.subtitleLabel.minimumScaleFactor = 0.84;
    [contentView addSubview:self.subtitleLabel];

    self.ctaContainerView = [[UIView alloc] init];
    self.ctaContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaContainerView.userInteractionEnabled = NO;
    self.ctaContainerView.layer.cornerRadius = 19.0;
    [contentView addSubview:self.ctaContainerView];

    self.ctaLabel = [[UILabel alloc] init];
    self.ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaLabel.font = [GM boldFontWithSize:13.0];
    self.ctaLabel.textAlignment = NSTextAlignmentCenter;
    [self.ctaContainerView addSubview:self.ctaLabel];

    UIImageSymbolConfiguration *chevronConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                                                                 weight:UIImageSymbolWeightBold
                                                                                                  scale:UIImageSymbolScaleSmall];
    self.ctaChevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward" withConfiguration:chevronConfig]];
    self.ctaChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaChevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.ctaContainerView addSubview:self.ctaChevronView];

    self.borderGradientLayer = [CAGradientLayer layer];
    self.borderGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.borderGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    self.borderMaskLayer = [CAShapeLayer layer];
    self.borderMaskLayer.lineWidth = 1.0;
    self.borderMaskLayer.fillColor = UIColor.clearColor.CGColor;
    self.borderMaskLayer.strokeColor = UIColor.blackColor.CGColor;
    self.borderGradientLayer.mask = self.borderMaskLayer;
    [self.layer addSublayer:self.borderGradientLayer];

    self.layer.shadowOpacity = 0.24;
    self.layer.shadowRadius = 34.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    self.layer.masksToBounds = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.materialView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.materialView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.materialView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.materialView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.tintOverlayView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.tintOverlayView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.tintOverlayView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.tintOverlayView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],

        [self.highlightGlowView.widthAnchor constraintEqualToConstant:138.0],
        [self.highlightGlowView.heightAnchor constraintEqualToConstant:138.0],
        [self.highlightGlowView.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [self.highlightGlowView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:-28.0],

        [self.iconOrbView.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [self.iconOrbView.widthAnchor constraintEqualToConstant:40.0],
        [self.iconOrbView.heightAnchor constraintEqualToConstant:40.0],

        [self.iconImageView.centerXAnchor constraintEqualToAnchor:self.iconOrbView.centerXAnchor],
        [self.iconImageView.centerYAnchor constraintEqualToAnchor:self.iconOrbView.centerYAnchor],

        [self.countBadgeLabel.heightAnchor constraintEqualToConstant:22.0],
        [self.countBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:22.0],

        [self.ctaContainerView.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [self.ctaContainerView.heightAnchor constraintEqualToConstant:38.0],
        [self.ctaContainerView.widthAnchor constraintGreaterThanOrEqualToConstant:108.0],

        [self.ctaLabel.leadingAnchor constraintEqualToAnchor:self.ctaContainerView.leadingAnchor constant:14.0],
        [self.ctaLabel.centerYAnchor constraintEqualToAnchor:self.ctaContainerView.centerYAnchor],

        [self.ctaChevronView.leadingAnchor constraintEqualToAnchor:self.ctaLabel.trailingAnchor constant:8.0],
        [self.ctaChevronView.trailingAnchor constraintEqualToAnchor:self.ctaContainerView.trailingAnchor constant:-12.0],
        [self.ctaChevronView.centerYAnchor constraintEqualToAnchor:self.ctaContainerView.centerYAnchor]
    ]];

    self.expandedConstraints = @[
        [self.iconOrbView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [self.countBadgeLabel.leadingAnchor constraintEqualToAnchor:self.iconOrbView.trailingAnchor constant:10.0],
        [self.countBadgeLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:10.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.countBadgeLabel.trailingAnchor constant:10.0],
        [self.titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:9.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.ctaContainerView.leadingAnchor constant:-12.0],

        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.countBadgeLabel.trailingAnchor constant:10.0],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3.0],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.ctaContainerView.leadingAnchor constant:-12.0],
        [self.subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-14.0],

        [self.ctaContainerView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-14.0]
    ];

    self.collapsedConstraints = @[
        [self.iconOrbView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:10.0],
        [self.countBadgeLabel.leadingAnchor constraintEqualToAnchor:self.iconOrbView.trailingAnchor constant:6.0],
        [self.countBadgeLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-10.0],
        [self.countBadgeLabel.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor]
    ];

    [NSLayoutConstraint activateConstraints:self.expandedConstraints];

    [self addTarget:self action:@selector(pp_touchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    if (@available(iOS 10.0, *)) {
        self.tapFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    }

    [self pp_applyAppearance];
    [self pp_applyState:nil];
    return self;
}

- (void)setCollapsed:(BOOL)collapsed
{
    [self setCollapsed:collapsed animated:NO];
}

- (void)setCollapsed:(BOOL)collapsed animated:(BOOL)animated
{
    if (_collapsed == collapsed) {
        return;
    }
    _collapsed = collapsed;

    void (^changes)(void) = ^{
        if (collapsed) {
            [NSLayoutConstraint deactivateConstraints:self.expandedConstraints];
            [NSLayoutConstraint activateConstraints:self.collapsedConstraints];
            self.titleLabel.alpha = 0.0;
            self.subtitleLabel.alpha = 0.0;
            self.ctaContainerView.alpha = 0.0;
        } else {
            [NSLayoutConstraint deactivateConstraints:self.collapsedConstraints];
            [NSLayoutConstraint activateConstraints:self.expandedConstraints];
            self.titleLabel.alpha = 1.0;
            self.subtitleLabel.alpha = 1.0;
            self.ctaContainerView.alpha = 1.0;
        }
        [self layoutIfNeeded];
    };

    if (animated) {
        [UIView animateWithDuration:0.35
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat radius = CGRectGetHeight(self.bounds) * 0.5;
    self.materialView.layer.cornerRadius = radius;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius].CGPath;
    self.borderGradientLayer.frame = self.bounds;
    self.borderMaskLayer.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 0.5, 0.5)
                                                           cornerRadius:MAX(0.0, radius - 0.5)].CGPath;
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    [self pp_applyAppearance];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyAppearance];
        }
    }
}

- (void)pp_applyAppearance
{
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *brandColor = AppPrimaryClr ?: [UIColor colorWithRed:0.90 green:0.10 blue:0.35 alpha:1.0];
    UIColor *secondaryBrandColor = [brandColor colorWithAlphaComponent:dark ? 0.72 : 0.52];
    UIColor *titleColor = dark ? UIColor.whiteColor : [UIColor colorWithWhite:0.08 alpha:1.0];
    UIColor *subtitleColor = dark ? [UIColor colorWithWhite:0.82 alpha:1.0] : [UIColor colorWithWhite:0.38 alpha:1.0];

    self.tintOverlayView.backgroundColor = dark
        ? [UIColor colorWithWhite:0.10 alpha:0.74]
        : [UIColor colorWithWhite:1.0 alpha:0.54];
    self.highlightGlowView.backgroundColor = [brandColor colorWithAlphaComponent:dark ? 0.18 : 0.13];
    self.highlightGlowView.layer.cornerRadius = 69.0;

    self.iconOrbView.backgroundColor = dark
        ? [brandColor colorWithAlphaComponent:0.22]
        : [brandColor colorWithAlphaComponent:0.12];
    self.iconOrbView.layer.shadowColor = [brandColor colorWithAlphaComponent:0.26].CGColor;
    self.iconImageView.tintColor = brandColor;

    self.countBadgeLabel.backgroundColor = [brandColor colorWithAlphaComponent:dark ? 0.20 : 0.14];
    self.countBadgeLabel.textColor = brandColor;

    self.titleLabel.textColor = titleColor;
    self.subtitleLabel.textColor = subtitleColor;

    self.ctaContainerView.backgroundColor = dark
        ? [brandColor colorWithAlphaComponent:0.20]
        : [brandColor colorWithAlphaComponent:0.12];
    self.ctaLabel.textColor = brandColor;
    self.ctaChevronView.tintColor = brandColor;

    UIColor *borderColor = [GM AppForegroundColor] ?: (dark ? [UIColor colorWithWhite:0.2 alpha:1.0] : [UIColor colorWithWhite:0.9 alpha:1.0]);
    self.borderGradientLayer.colors = @[
        (__bridge id)borderColor.CGColor,
        (__bridge id)borderColor.CGColor
    ];
    self.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:(dark ? 0.52 : 0.16)].CGColor;
}

- (void)pp_applyState:(nullable PPCartFloatingBarState *)state
{
    NSInteger itemCount = MAX(0, state.itemCount);
    double totalAmount = MAX(0.0, state.totalAmount);

    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *titleColor = dark ? UIColor.whiteColor : [UIColor colorWithWhite:0.08 alpha:1.0];
    UIColor *subtitleColor = dark ? [UIColor colorWithWhite:0.82 alpha:1.0] : [UIColor colorWithWhite:0.38 alpha:1.0];
    UIColor *brandColor = AppPrimaryClr ?: [UIColor colorWithRed:0.90 green:0.10 blue:0.35 alpha:1.0];

    self.titleLabel.attributedText =
        [[NSAttributedString alloc] initWithString:(kLang(@"Cart") ?: @"Cart")
                                        attributes:@{NSFontAttributeName: [GM boldFontWithSize:16.0],
                                                     NSForegroundColorAttributeName: titleColor}];
    self.subtitleLabel.attributedText =
        [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ · %@",
                                                    PPCartFloatingBarCountText(itemCount),
                                                    PPCartFloatingBarAmountText(totalAmount)]
                                        attributes:@{NSFontAttributeName: [GM MidFontWithSize:13.0],
                                                     NSForegroundColorAttributeName: subtitleColor}];
    self.countBadgeLabel.text = itemCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)itemCount];
    self.ctaLabel.attributedText =
        [[NSAttributedString alloc] initWithString:(kLang(@"checkout_review_cart_action") ?: @"Review Cart")
                                        attributes:@{NSFontAttributeName: [GM boldFontWithSize:13.0],
                                                     NSForegroundColorAttributeName: brandColor}];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@",
                               self.titleLabel.text ?: @"",
                               self.subtitleLabel.text ?: @"",
                               self.ctaLabel.text ?: @""];
    self.accessibilityHint = kLang(@"a11y_btn_checkout_hint") ?: @"Double-tap to review your cart";
}

- (void)prepareForTapFeedback
{
    if (@available(iOS 10.0, *)) {
        [self.tapFeedbackGenerator prepare];
    }
}

- (void)emitTapFeedback
{
    if (@available(iOS 10.0, *)) {
        if ([self.tapFeedbackGenerator respondsToSelector:@selector(impactOccurredWithIntensity:)]) {
            [self.tapFeedbackGenerator impactOccurredWithIntensity:0.72];
        } else {
            [self.tapFeedbackGenerator impactOccurred];
        }
    }
}

- (void)pp_touchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:nil];
}

- (void)pp_touchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end

@interface PPCartFloatingBarCoordinator : NSObject
@property (nonatomic, weak) PPRootTabBarController *hostController;
@property (nonatomic, weak, nullable) UIViewController *activeSourceViewController;
@property (nonatomic, copy, nullable) PPCartFloatingBarOpenHandler openCartHandler;
@property (nonatomic, strong) PPCartFloatingBarState *state;
@property (nonatomic, strong, nullable) PPBottomFadeView *floatingBarFadeView;
@property (nonatomic, strong, nullable) PPCartFloatingBarView *floatingBarView;
@property (nonatomic, strong, nullable) NSLayoutConstraint *floatingBarBottomConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *floatingBarLeadingConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *floatingBarTrailingConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *floatingBarWidthConstraint;
@property (nonatomic, assign) BOOL isCollapsed;
@property (nonatomic, strong, nullable) NSTimer *collapseTimer;
@property (nonatomic, assign) BOOL preparedForPremiumReveal;
- (BOOL)isEligibleFloatingCartSourceViewController:(UIViewController *)viewController;
- (void)refreshForCurrentVisibleControllerAnimated:(BOOL)animated;
- (nullable UIViewController *)topVisibleViewControllerFrom:(nullable UIViewController *)viewController;
- (nullable UIViewController *)topVisibleViewControllerFrom:(nullable UIViewController *)viewController
                                         visitedControllers:(NSMutableSet<NSValue *> *)visitedControllers;
- (CGFloat)expectedBottomClearanceForVisibleFloatingCart;
- (void)collapseFloatingBarAnimated:(BOOL)animated;
- (void)expandFloatingBarAnimated:(BOOL)animated;
- (void)startCollapseTimer;
- (void)invalidateCollapseTimer;
@end

@implementation PPCartFloatingBarCoordinator

- (instancetype)initWithHostController:(PPRootTabBarController *)hostController
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _hostController = hostController;
    _state = [PPCartFloatingBarState new];
    return self;
}

- (void)activateForSourceViewController:(UIViewController *)viewController
                        openCartHandler:(PPCartFloatingBarOpenHandler)openCartHandler
                               animated:(BOOL)animated
{
    self.activeSourceViewController = viewController;
    self.openCartHandler = [openCartHandler copy];
    [self hostViewDidLayoutSubviews];

    CartManager *cartManager = [CartManager sharedManager];
    BOOL canPrepareCartReveal = ([cartManager totalItemsCount] > 0 &&
                                 [self isEligibleFloatingCartSourceViewController:viewController]);
    if (!animated && canPrepareCartReveal) {
        if (!self.state.isVisible) {
            [self prepareHiddenFloatingBarForPremiumReveal];
        }
        return;
    }

    [self updateVisibilityAnimated:animated];
}

- (void)deactivateForSourceViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (self.activeSourceViewController != viewController) {
        return;
    }
    self.activeSourceViewController = nil;
    self.openCartHandler = nil;
    [self invalidateCollapseTimer];
    [self updateVisibilityAnimated:animated];
}

- (void)hostViewDidLayoutSubviews
{
    if (!self.state.isVisible || !self.floatingBarView || !self.hostController) {
        return;
    }
    if (self.floatingBarFadeView) {
        [self.hostController.view bringSubviewToFront:self.floatingBarFadeView];
    }
    [self.hostController.view bringSubviewToFront:self.floatingBarView];
}

- (CGFloat)currentBottomClearance
{
    if (!self.state.isVisible || !self.floatingBarView || self.floatingBarView.hidden) {
        return 0.0;
    }

    UIView *hostView = self.hostController.view;
    if (!hostView || CGRectIsEmpty(hostView.bounds)) {
        return 0.0;
    }

    CGRect floatingFrame = [self.floatingBarView.superview convertRect:self.floatingBarView.frame toView:hostView];
    CGFloat safeBottomY = CGRectGetMaxY(hostView.bounds) - hostView.safeAreaInsets.bottom;
    CGFloat overlapAboveSafeArea = MAX(0.0, safeBottomY - CGRectGetMinY(floatingFrame));
    return ceil(overlapAboveSafeArea + PPCartFloatingBarClearancePadding);
}

- (CGFloat)restingBottomClearance
{
    return ceil(MAX(0.0, PPCartFloatingBarHeight - PPCartFloatingBarRestingBottomConstant) + PPCartFloatingBarClearancePadding);
}

- (CGFloat)expectedBottomClearanceForVisibleFloatingCart
{
    UIViewController *source = self.activeSourceViewController;
    if (!source || !self.hostController) {
        return 0.0;
    }

    CartManager *cartManager = [CartManager sharedManager];
    if ([cartManager totalItemsCount] <= 0 ||
        ![self isEligibleFloatingCartSourceViewController:source] ||
        ![self isActiveSourceCurrentlyVisible]) {
        return 0.0;
    }

    UIViewController *visible = [self topVisibleViewControllerFrom:self.hostController.selectedViewController ?: self.hostController];
    PPBottomSurfaceKind resolvedKind =
        [[PPBottomSurfaceCoordinator sharedCoordinator] resolvedSurfaceKindForController:visible];
    if (resolvedKind != PPBottomSurfaceKindFloatingCartSurface) {
        return 0.0;
    }

    CGFloat measuredClearance = [self currentBottomClearance];
    if (measuredClearance > 0.0) {
        return measuredClearance;
    }

    return [self restingBottomClearance];
}

- (void)handleCartUpdatedAnimated:(BOOL)animated
{
    [self updateVisibilityAnimated:animated];
    if (self.state.isVisible) {
        if (self.isCollapsed) {
            [self expandFloatingBarAnimated:animated];
        } else {
            [self startCollapseTimer];
        }
    }
}

- (void)refreshForCurrentVisibleControllerAnimated:(BOOL)animated
{
    UIViewController *visible = [self topVisibleViewControllerFrom:self.hostController.selectedViewController ?: self.hostController];
    PPBottomSurfaceKind resolvedKind =
        [[PPBottomSurfaceCoordinator sharedCoordinator] resolvedSurfaceKindForController:visible];
    if (resolvedKind != PPBottomSurfaceKindFloatingCartSurface) {
        if (self.state.isVisible || self.activeSourceViewController) {
            self.activeSourceViewController = nil;
            self.openCartHandler = nil;
            [self updateVisibilityAnimated:animated];
        }
        return;
    }
    [self updateVisibilityAnimated:animated];
}

- (void)handleTap
{
    [self.floatingBarView emitTapFeedback];
    if (self.isCollapsed) {
        [self expandFloatingBarAnimated:YES];
        return;
    }
    if (self.openCartHandler) {
        self.openCartHandler();
    }
}

- (void)refreshActiveSourceInsetsIfNeeded
{
    UIViewController *source = self.activeSourceViewController;
    if (!source) {
        return;
    }

    SEL sellerInsetSelector = NSSelectorFromString(@"pp_updateBottomNavigationInsetsIfNeeded");
    if ([source respondsToSelector:sellerInsetSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [source performSelector:sellerInsetSelector];
#pragma clang diagnostic pop
    }

    SEL collectionInsetSelector = NSSelectorFromString(@"updateCollectionContentInset");
    if ([source respondsToSelector:collectionInsetSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [source performSelector:collectionInsetSelector];
#pragma clang diagnostic pop
    }
}

- (BOOL)isEligibleFloatingCartSourceViewController:(UIViewController *)viewController
{
    if (!viewController) {
        return NO;
    }

    for (Class candidateClass = viewController.class;
         candidateClass && candidateClass != UIViewController.class;
         candidateClass = class_getSuperclass(candidateClass)) {
        NSString *className = NSStringFromClass(candidateClass);
        if ([className isEqualToString:@"PPDataViewVC"] ||
            [className isEqualToString:@"SellerProfileVC"]) {
            return YES;
        }
    }

    return NO;
}

- (UIViewController *)topVisibleViewControllerFrom:(UIViewController *)viewController
{
    return [self topVisibleViewControllerFrom:viewController visitedControllers:[NSMutableSet set]];
}

- (UIViewController *)topVisibleViewControllerFrom:(UIViewController *)viewController
                                visitedControllers:(NSMutableSet<NSValue *> *)visitedControllers
{
    if (!viewController) {
        return nil;
    }

    NSValue *viewControllerPointer = [NSValue valueWithNonretainedObject:viewController];
    if ([visitedControllers containsObject:viewControllerPointer]) {
        return viewController;
    }
    [visitedControllers addObject:viewControllerPointer];

    UIViewController *presented = viewController.presentedViewController;
    if (presented && presented != viewController && !presented.isBeingDismissed) {
        return [self topVisibleViewControllerFrom:presented visitedControllers:visitedControllers];
    }

    if ([viewController isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController = (UINavigationController *)viewController;
        UIViewController *candidate = navigationController.visibleViewController ?: navigationController.topViewController;
        if (candidate && candidate != viewController) {
            return [self topVisibleViewControllerFrom:candidate visitedControllers:visitedControllers];
        }
        return viewController;
    }

    if ([viewController isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabController = (UITabBarController *)viewController;
        UIViewController *candidate = tabController.selectedViewController;
        if (candidate && candidate != viewController) {
            return [self topVisibleViewControllerFrom:candidate visitedControllers:visitedControllers];
        }
        return viewController;
    }

    return viewController;
}

- (BOOL)isActiveSourceCurrentlyVisible
{
    UIViewController *source = self.activeSourceViewController;
    if (!source || !self.hostController) {
        return NO;
    }

    UIViewController *visible = [self topVisibleViewControllerFrom:self.hostController.selectedViewController ?: self.hostController];
    return visible == source;
}

- (BOOL)shouldShowFloatingCartForSourceViewController:(UIViewController *)source
{
    if (!source) {
        return NO;
    }

    CartManager *cartManager = [CartManager sharedManager];
    if ([cartManager totalItemsCount] <= 0 ||
        ![self isEligibleFloatingCartSourceViewController:source] ||
        ![self isActiveSourceCurrentlyVisible]) {
        return NO;
    }

    UIViewController *visible = [self topVisibleViewControllerFrom:self.hostController.selectedViewController ?: self.hostController];
    PPBottomSurfaceKind resolvedKind =
        [[PPBottomSurfaceCoordinator sharedCoordinator] resolvedSurfaceKindForController:visible];
    return resolvedKind == PPBottomSurfaceKindFloatingCartSurface;
}

- (BOOL)hostShouldKeepBottomNavigationHidden
{
    UIViewController *selected = self.hostController.selectedViewController;
    UIViewController *visible = selected;
    if ([selected isKindOfClass:UINavigationController.class]) {
        visible = ((UINavigationController *)selected).topViewController ?: selected;
    }
    if ([self isEligibleFloatingCartSourceViewController:visible]) {
        return NO;
    }
    return visible.hidesBottomBarWhenPushed;
}

- (void)prepareHiddenFloatingBarForPremiumReveal
{
    PPRootTabBarController *host = self.hostController;
    UIViewController *source = self.activeSourceViewController;
    if (!host || !source) {
        return;
    }

    CartManager *cartManager = [CartManager sharedManager];
    self.state.itemCount = MAX(0, [cartManager totalItemsCount]);
    self.state.totalAmount = [cartManager totalAmount];

    [self ensureFloatingBarIfNeeded];
    [self.floatingBarView pp_applyState:self.state];
    [self.floatingBarView prepareForTapFeedback];
    [self pp_applyFloatingFadeAppearance];

    self.state.visible = NO;
    self.preparedForPremiumReveal = YES;
    self.floatingBarFadeView.hidden = YES;
    self.floatingBarFadeView.alpha = 0.0;
    self.floatingBarView.hidden = YES;
    self.floatingBarView.alpha = 0.0;
    self.floatingBarView.transform = UIAccessibilityIsReduceMotionEnabled()
        ? CGAffineTransformIdentity
        : CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 24.0),
                                  CGAffineTransformMakeScale(0.97, 0.97));
    self.floatingBarBottomConstraint.constant = PPCartFloatingBarHiddenBottomConstant;
    [host.view layoutIfNeeded];
    [host pp_applyBottomNavigationClearanceToVisibleLists];
    [self refreshActiveSourceInsetsIfNeeded];
}

- (void)updateVisibilityAnimated:(BOOL)animated
{
    PPRootTabBarController *host = self.hostController;
    if (!host) {
        return;
    }

    UIViewController *source = self.activeSourceViewController;
    CartManager *cartManager = [CartManager sharedManager];
    NSInteger itemCount = MAX(0, [cartManager totalItemsCount]);
    double totalAmount = [cartManager totalAmount];
    BOOL shouldShow = (source != nil &&
                       [self shouldShowFloatingCartForSourceViewController:source]);

    self.state.itemCount = itemCount;
    self.state.totalAmount = totalAmount;

    if (shouldShow) {
        [self ensureFloatingBarIfNeeded];
        [self.floatingBarView pp_applyState:self.state];
        [self.floatingBarView prepareForTapFeedback];
        [self pp_applyFloatingFadeAppearance];
    }

    BOOL wasVisible = self.state.isVisible;
    if (wasVisible == shouldShow) {
        if (shouldShow) {
            [host pp_setPremiumBottomNavigationHidden:YES animated:NO];
            [host pp_applyBottomNavigationClearanceToVisibleLists];
            [self refreshActiveSourceInsetsIfNeeded];
            [source setNeedsStatusBarAppearanceUpdate];
            [self hostViewDidLayoutSubviews];
            
            if (self.isCollapsed) {
                [self expandFloatingBarAnimated:YES];
            } else {
                [self startCollapseTimer];
            }
        }
        return;
    }

    self.state.visible = shouldShow;
    if (shouldShow) {
        [self ensureFloatingBarIfNeeded];
        [self pp_applyFloatingFadeAppearance];
        PPCartFloatingBarView *barView = self.floatingBarView;
        PPBottomFadeView *fadeView = self.floatingBarFadeView;
        fadeView.hidden = NO;
        fadeView.alpha = self.preparedForPremiumReveal ? fadeView.alpha : 0.0;
        barView.hidden = NO;
        if (!self.preparedForPremiumReveal) {
            barView.alpha = 0.0;
            barView.transform = UIAccessibilityIsReduceMotionEnabled()
                ? CGAffineTransformIdentity
                : CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 24.0),
                                          CGAffineTransformMakeScale(0.97, 0.97));
        }
        self.floatingBarBottomConstraint.constant = PPCartFloatingBarHiddenBottomConstant;
        
        self.isCollapsed = NO;
        self.floatingBarWidthConstraint.active = NO;
        self.floatingBarLeadingConstraint.active = YES;
        [self.floatingBarView setCollapsed:NO animated:NO];
        
        [host.view layoutIfNeeded];
        [host pp_setPremiumBottomNavigationHidden:YES animated:animated];
        if (fadeView) {
            [host.view bringSubviewToFront:fadeView];
        }
        [host.view bringSubviewToFront:barView];
        [host.view layoutIfNeeded];

        void (^showChanges)(void) = ^{
            fadeView.alpha = 1.0;
            self.floatingBarBottomConstraint.constant = PPCartFloatingBarRestingBottomConstant;
            barView.alpha = 1.0;
            barView.transform = CGAffineTransformIdentity;
            [host.view layoutIfNeeded];
        };
        void (^showCompletion)(BOOL) = ^(__unused BOOL finished) {
            self.preparedForPremiumReveal = NO;
            [host pp_applyBottomNavigationClearanceToVisibleLists];
            [self refreshActiveSourceInsetsIfNeeded];
            [self startCollapseTimer];
        };
        if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
            showChanges();
            showCompletion(YES);
        } else {
            [UIView animateWithDuration:[PPBottomSurfaceCoordinator transitionInDuration]
                                  delay:0.0
                 usingSpringWithDamping:[PPBottomSurfaceCoordinator transitionInSpringDamping]
                  initialSpringVelocity:[PPBottomSurfaceCoordinator transitionInSpringVelocity]
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:showChanges
                             completion:showCompletion];
        }
        return;
    }

    PPCartFloatingBarView *barView = self.floatingBarView;
    PPBottomFadeView *fadeView = self.floatingBarFadeView;
    [self invalidateCollapseTimer];
    void (^hideChanges)(void) = ^{
        fadeView.alpha = 0.0;
        self.floatingBarBottomConstraint.constant = PPCartFloatingBarHiddenBottomConstant;
        barView.alpha = 0.0;
        barView.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 20.0),
                                      CGAffineTransformMakeScale(0.97, 0.97));
        [host.view layoutIfNeeded];
    };
    void (^hideCompletion)(BOOL) = ^(__unused BOOL finished) {
        self.preparedForPremiumReveal = NO;
        fadeView.hidden = YES;
        barView.hidden = YES;
        barView.transform = CGAffineTransformIdentity;
        if (![self hostShouldKeepBottomNavigationHidden]) {
            [host pp_setPremiumBottomNavigationHidden:NO animated:animated];
        }
        [host pp_applyBottomNavigationClearanceToVisibleLists];
        [self refreshActiveSourceInsetsIfNeeded];
    };
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        hideChanges();
        hideCompletion(YES);
    } else {
        [UIView animateWithDuration:[PPBottomSurfaceCoordinator transitionOutDuration]
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                         animations:hideChanges
                         completion:hideCompletion];
    }
}

- (void)ensureFloatingBarIfNeeded
{
    if (self.floatingBarView || !self.hostController) {
        return;
    }

    UIView *hostView = self.hostController.view;

    PPBottomFadeView *fadeView = [[PPBottomFadeView alloc] init];
    fadeView.translatesAutoresizingMaskIntoConstraints = NO;
    fadeView.userInteractionEnabled = NO;
    fadeView.hidden = YES;
    fadeView.alpha = 0.0;
    [hostView addSubview:fadeView];
    self.floatingBarFadeView = fadeView;

    PPCartFloatingBarView *barView = [[PPCartFloatingBarView alloc] initWithFrame:CGRectZero];
    [barView addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    barView.hidden = YES;
    barView.alpha = 0.0;

    [hostView addSubview:barView];
    self.floatingBarView = barView;
    self.floatingBarBottomConstraint = [barView.bottomAnchor constraintEqualToAnchor:hostView.safeAreaLayoutGuide.bottomAnchor constant:PPCartFloatingBarHiddenBottomConstant];

    self.floatingBarLeadingConstraint = [barView.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor constant:16.0];
    self.floatingBarTrailingConstraint = [barView.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor constant:-16.0];
    self.floatingBarWidthConstraint = [barView.widthAnchor constraintEqualToConstant:92.0];

    [NSLayoutConstraint activateConstraints:@[
        [fadeView.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor],
        [fadeView.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor],
        [fadeView.bottomAnchor constraintEqualToAnchor:hostView.bottomAnchor],
        [fadeView.heightAnchor constraintEqualToConstant:164.0],

        self.floatingBarLeadingConstraint,
        self.floatingBarTrailingConstraint,
        self.floatingBarBottomConstraint,
        [barView.heightAnchor constraintEqualToConstant:PPCartFloatingBarHeight]
    ]];

    [self pp_applyFloatingFadeAppearance];
}

- (void)pp_applyFloatingFadeAppearance
{
    if (!self.floatingBarFadeView) {
        return;
    }

    UIColor *baseColor = AppForgroundColr ?: AppBackgroundClr ?: UIColor.whiteColor;
    if (@available(iOS 13.0, *)) {
        if (self.hostController.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            baseColor = [UIColor colorWithWhite:0.05 alpha:1.0];
        }
    }

    CAGradientLayer *gradientLayer = (CAGradientLayer *)self.floatingBarFadeView.layer;
    gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    gradientLayer.endPoint = CGPointMake(0.5, 1.0);
    gradientLayer.colors = @[
        (__bridge id)[baseColor colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)[baseColor colorWithAlphaComponent:0.06].CGColor,
        (__bridge id)[baseColor colorWithAlphaComponent:0.38].CGColor
    ];
    gradientLayer.locations = @[@0.0, @0.58, @1.0];
}

- (void)collapseFloatingBarAnimated:(BOOL)animated
{
    if (self.isCollapsed || !self.floatingBarView || self.floatingBarView.hidden) {
        return;
    }
    self.isCollapsed = YES;
    [self.collapseTimer invalidate];
    self.collapseTimer = nil;

    void (^changes)(void) = ^{
        self.floatingBarLeadingConstraint.active = NO;
        self.floatingBarWidthConstraint.active = YES;
        [self.floatingBarView setCollapsed:YES animated:NO];
        [self.hostController.view layoutIfNeeded];
    };

    if (animated) {
        [UIView animateWithDuration:0.35
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)expandFloatingBarAnimated:(BOOL)animated
{
    if (!self.isCollapsed || !self.floatingBarView || self.floatingBarView.hidden) {
        return;
    }
    self.isCollapsed = NO;

    void (^changes)(void) = ^{
        self.floatingBarWidthConstraint.active = NO;
        self.floatingBarLeadingConstraint.active = YES;
        [self.floatingBarView setCollapsed:NO animated:NO];
        [self.hostController.view layoutIfNeeded];
    };

    void (^completion)(BOOL) = ^(BOOL finished) {
        [self startCollapseTimer];
    };

    if (animated) {
        [UIView animateWithDuration:0.35
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:completion];
    } else {
        changes();
        completion(YES);
    }
}

- (void)startCollapseTimer
{
    [self.collapseTimer invalidate];
    self.collapseTimer = [NSTimer scheduledTimerWithTimeInterval:6.0
                                                         target:self
                                                       selector:@selector(collapseTimerFired)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)collapseTimerFired
{
    [self collapseFloatingBarAnimated:YES];
}

- (void)invalidateCollapseTimer
{
    [self.collapseTimer invalidate];
    self.collapseTimer = nil;
}

- (void)dealloc
{
    [_collapseTimer invalidate];
}

@end

@implementation PPRootTabBarController

- (BOOL)useLegacyBar {
    if (_hasSetUseLegacyBar) {
        return _useLegacyBar;
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PPUSE_LEGACY_BAR"];
}

- (void)setUseLegacyBar:(BOOL)useLegacyBar {
    _useLegacyBar = useLegacyBar;
    _hasSetUseLegacyBar = YES;
}

- (nullable UIViewController *)pp_viewControllerForRootTabIndex:(NSInteger)index
{
    NSArray<UIViewController *> *controllers = self.viewControllers;
    if (index < 0 || index >= (NSInteger)controllers.count) {
        return nil;
    }
    return controllers[(NSUInteger)index];
}

- (NSInteger)pp_resolvedMyAdsRootTabIndex
{
    return self.premiumMyAdsRootTabIndex != NSNotFound
        ? self.premiumMyAdsRootTabIndex
        : PPRootTabIndexMyAds;
}

- (BOOL)pp_isResolvedMyAdsRootTabIndex:(NSInteger)index
{
    return index == [self pp_resolvedMyAdsRootTabIndex];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    if (selectedIndex >= self.viewControllers.count) {
        NSLog(@"[PPRootTabBar] Ignoring invalid selectedIndex=%lu count=%lu",
              (unsigned long)selectedIndex,
              (unsigned long)self.viewControllers.count);
        [self pp_applyPremiumTabSelectionAnimated:NO];
        return;
    }
    [super setSelectedIndex:selectedIndex];
    [self pp_assertPremiumTabBarState];
    [self.cartFloatingBarCoordinator refreshForCurrentVisibleControllerAnimated:YES];
    if (self.premiumTabItems.count > 0) {
        [self pp_applyPremiumTabSelectionAnimated:NO];
    }
    [self pp_refreshGuestProfileAnimationAfterSelection];
    [self pp_applyBottomNavigationClearanceToVisibleLists];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
    self.tabBar.semanticContentAttribute = semantic;
    self.view.backgroundColor = AppClearClr;
    self.delegate = self;
    self.premiumMyAdsRootTabIndex = NSNotFound;
    // Home
    UINavigationController *homeNav =
    [self nav:[PPHomeViewController new]
         title:kLang(@"MainPage")
         icon:@"house" selectedImage:@"house.fill"];

    // Notifications
    //UINavigationController *notiNav = [self nav:[UserChatsViewController new] title:kLang(@"Notifications") icon:@"bell" selectedImage:@"bellLast"];

    // Add (center)
    UINavigationController *addNav = nil;
    if (self.useLegacyBar) {
        addNav = [self nav:[self pp_makeAddActionPlaceholderViewController]
                     title:kLang(@"Add")
                      icon:@"plus"
             selectedImage:@"plus.fill"];
    } else {
        addNav = [self nav:[self pp_makeAddActionPlaceholderViewController]
                     title:kLang(@"Add")
                      icon:@"plus"
             selectedImage:@"plus.fill"];
    }
    // Settings
    UINavigationController *settingsNav = [self nav:[self pp_makeSettingsRootViewController]   title:(kLang(@"menu_action_settings") ?: (kLang(@"Setting") ?: @"Settings"))  icon:@"slider.horizontal.3" selectedImage:@"slider.horizontal.3"];

    // User menu temporarily occupies the former Orders History tab slot.
    UINavigationController *cartNav = [self nav:[PPUserMenuViewController new]
                                          title:kLang(@"user_menu_tab_title")
                                           icon:@"person.crop.circle"
                                  selectedImage:@"person.crop.circle.fill"];
    cartNav.tabBarItem.image = [self pp_profileTabItemImageSelected:NO];
    cartNav.tabBarItem.selectedImage = [self pp_profileTabItemImageSelected:YES];
   
    
    UINavigationController *notiNav = [self nav:[PPNotificationsHubViewController new]  title:kLang(@"chatsTitle")   icon:@"messagenotfill" selectedImage:@"message.badge.waveform.fill"];

    notiNav.tabBarItem.accessibilityHint =
        NSLocalizedString(@"a11y_tab_notifications_hint", @"View pet reminders and chats");

    NSString *ordersTabTitle = kLang(@"menu_action_orders");
    if (![ordersTabTitle isKindOfClass:NSString.class] || ordersTabTitle.length == 0) {
        ordersTabTitle = kLang(@"OrderHistory");
    }
    UINavigationController *ordersNav =
        [self nav:[OrderHistoryViewController new]
            title:ordersTabTitle
             icon:@"cart.badge.clock"
    selectedImage:@"cart.badge.clock.fill"];
    ordersNav.tabBarItem.accessibilityLabel = kLang(@"a11y_tab_orders") ?: ordersTabTitle;
    ordersNav.tabBarItem.accessibilityHint = kLang(@"a11y_tab_orders_hint");
   /*
    UINavigationController *searchNav =
    [self nav:[OrderHistoryViewController new]
         title:kLang(@"Search")
          icon:@"magnifyingglass.circle.fill"];
    
    UINavigationController *cartNav =
    [self nav:[CartViewController new]
         title:kLang(@"Cart")
         icon:@"cart" selectedImage:@"cartLast"];
    
    
    */

    if (!self.useLegacyBar) {
        NSMutableArray<UIViewController *> *premiumRootControllers = [@[
            homeNav,
            ordersNav,
            addNav,
            notiNav,
            cartNav
        ] mutableCopy];
        self.premiumMyAdsRootTabIndex = PPRootTabIndexMyAds;
        self.viewControllers = premiumRootControllers.copy;
    } else {
        self.viewControllers = @[
            homeNav,
            ordersNav,
            addNav,
            notiNav,
            cartNav
        ];
        self.premiumMyAdsRootTabIndex = PPRootTabIndexMyAds;
    }

    // ── Centralized tab bar state management ──
    // Set self as delegate for every tab's navigation controller so
    // navigationController:didShowViewController:animated: fires after
    // every push/pop transition and can re-assert the correct tab bar state.
    for (UIViewController *vc in self.viewControllers) {
        if ([vc isKindOfClass:UINavigationController.class]) {
            [(UINavigationController *)vc setDelegate:self];
        }
    }

    // ── Accessibility: Tab bar items ──
    homeNav.tabBarItem.accessibilityLabel     = NSLocalizedString(@"a11y_tab_home", @"Home tab");
    homeNav.tabBarItem.accessibilityHint      = NSLocalizedString(@"a11y_tab_home_hint", @"Browse pet ads and services");
    ordersNav.tabBarItem.accessibilityLabel   = kLang(@"a11y_tab_orders") ?: ordersTabTitle;
    ordersNav.tabBarItem.accessibilityHint    = kLang(@"a11y_tab_orders_hint");
    addNav.tabBarItem.accessibilityLabel      = NSLocalizedString(@"a11y_tab_add", @"Add new post tab");
    notiNav.tabBarItem.accessibilityLabel     = kLang(@"chatsTitle") ?: NSLocalizedString(@"a11y_tab_notifications", @"Chats tab");
    notiNav.tabBarItem.accessibilityHint      = NSLocalizedString(@"a11y_tab_notifications_hint", @"View your chats and notifications");
    cartNav.tabBarItem.accessibilityLabel     = kLang(@"a11y_tab_user_menu");
    cartNav.tabBarItem.accessibilityHint      = kLang(@"a11y_tab_user_menu_hint");
    settingsNav.tabBarItem.accessibilityLabel = NSLocalizedString(@"a11y_tab_settings", @"Settings tab");
    settingsNav.tabBarItem.accessibilityHint  = NSLocalizedString(@"a11y_tab_settings_hint", @"App settings and account");

    [self pp_applyPremiumTabBarItemMetrics:homeNav.tabBarItem centerAction:NO];
    [self pp_applyPremiumTabBarItemMetrics:ordersNav.tabBarItem centerAction:NO];
    [self pp_applyPremiumTabBarItemMetrics:addNav.tabBarItem centerAction:YES];
    [self pp_applyPremiumTabBarItemMetrics:notiNav.tabBarItem centerAction:NO];
    [self pp_applyPremiumTabBarItemMetrics:cartNav.tabBarItem centerAction:NO];

    self.pp_lastSelectedIndex = self.selectedIndex;
    //[self addBottomFadeBelowTabBar];
    [self configureAppearance];

    [self pp_setupPremiumBottomNavigation];
    [self pp_refreshProfileTabPresentation];
    self.cartFloatingBarCoordinator = [[PPCartFloatingBarCoordinator alloc] initWithHostController:self];

    // ── KVO guard against UIKit tabBar flashes ──
    // UITabBarController internally sets self.tabBar.hidden = NO during pop
    // transitions. This KVO immediately reverts that on iOS 26+.
    if (!self.useLegacyBar) {
        [self.tabBar addObserver:self
                      forKeyPath:@"hidden"
                         options:NSKeyValueObservingOptionNew
                         context:kPPTabBarHiddenObservationContext];
    }

    [self updateUnreads];
    
    


    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showSystemTabBar)
                                                 name:PPShowSystemTabBarNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(updateUnreads)
               name:@"UnreadCountsUpdated"
             object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hideSystemTabBar)
                                                 name:PPHideSystemTabBarNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleRouteToSearchAccessories)
     name:PPRouteToSearchAccessoriesNotificationKey
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleBlockedStateNotification:)
               name:PPUserManagerDidUpdateBlockedStateNotification
             object:UserManager.sharedManager];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleUserAccessUpdate:)
               name:PPUserManagerDidUpdateUserAccessNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleNovaFloatingVisibilityUpdate:)
               name:PPNovaFloatingVisibilityDidChangeNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleProfileAuthenticationChange:)
               name:PPUserManagerDidSyncCurrentUserNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleProfileAuthenticationChange:)
               name:PPUserManagerDidSignOutNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleReduceMotionStatusChange:)
               name:UIAccessibilityReduceMotionStatusDidChangeNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleCartFloatingBarCartUpdated:)
               name:kCartUpdatedNotification
             object:nil];
    //[self configureTabBarIndicatorColor];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_assertPremiumTabBarState];
    [self pp_updatePremiumBottomFadeAppearance];
    [UserManager.sharedManager startListeningCurrentUserBlockedState];
    [self pp_applyBlockedState:(UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) animated:NO];
    [self pp_refreshProfileTabPresentation];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_refreshLegacyTabBarTitleLayout];
    [self pp_animatePremiumBottomNavigationEntranceIfNeeded];
    [self pp_assertPremiumTabBarState];
    [self pp_layoutGuestProfileAnimation];
    [self pp_updateGuestProfileAnimationPlayback];
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:self.selectedViewController animated:NO];
    [self pp_showIntroIfNeeded];
    [self becomeFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.guestProfileLottieView stop];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidShakeDevice];
    }
    [super motionEnded:motion withEvent:event];
}

#pragma mark - Centralized Tab Bar State

/// Single source of truth for which tab bar (system vs premium dock) is visible.
/// Called after every navigation push/pop transition and tab switch.
/// iOS 26+ → system tabBar permanently hidden, premium dock shown exclusively.
/// iOS < 26 → system tabBar visible, premium dock never created.
- (void)pp_assertPremiumTabBarState
{
    if (!self.useLegacyBar) {
        self.tabBar.hidden = YES;
        self.tabBar.alpha = 0.0;
        self.tabBar.userInteractionEnabled = NO;
    }
}

- (void)pp_showIntroIfNeeded {
    if (self.didAttemptIntroPresentation) return;
    self.didAttemptIntroPresentation = YES;

    if (![PPIntroViewController shouldShowIntro]) return;

    UIWindow *window = self.view.window;
    if (!window) {
        for (UIScene *candidateScene in UIApplication.sharedApplication.connectedScenes) {
            if ([candidateScene isKindOfClass:UIWindowScene.class]) {
                UIWindowScene *windowScene = (UIWindowScene *)candidateScene;
                if (windowScene.windows.count == 0) continue;
                window = windowScene.windows.firstObject;
                break;
            }
        }
    }
    if (!window) return;

    PPIntroViewController *intro = [[PPIntroViewController alloc] init];
    self.activeIntroViewController = intro;
    intro.view.frame = window.bounds;
    __weak typeof(self) weakSelf = self;
    [intro showOverWindow:window completion:^{
        weakSelf.activeIntroViewController = nil;
    }];
}

#pragma mark - UINavigationControllerDelegate

/// Fires BEFORE the push/pop animation begins. Preemptively hide the system
/// tabBar so UIKit's internal transition machinery starts from hidden state.
- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [self pp_assertPremiumTabBarState];
    PPBottomSurfaceKind requestedKind =
        [[PPBottomSurfaceCoordinator sharedCoordinator] resolvedSurfaceKindForController:viewController];
    BOOL shouldHideBottomNavigation = requestedKind != PPBottomSurfaceKindPremiumTabBar;
    if (shouldHideBottomNavigation || !self.cartFloatingBarCoordinator.state.isVisible) {
        [self pp_setPremiumBottomNavigationHidden:shouldHideBottomNavigation animated:animated];
    }
    // After the transition completes, re-assert in case UIKit altered state mid-animation
    if (animated) {
        id<UIViewControllerTransitionCoordinator> coordinator = navigationController.transitionCoordinator;
        [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [self pp_assertPremiumTabBarState];
        }];
    }
}

/// Fires AFTER the push/pop animation completes. Final re-assertion.
- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [self pp_assertPremiumTabBarState];
    PPBottomSurfaceKind requestedKind =
        [[PPBottomSurfaceCoordinator sharedCoordinator] resolvedSurfaceKindForController:viewController];
    BOOL shouldHideBottomNavigation = requestedKind != PPBottomSurfaceKindPremiumTabBar;
    if (shouldHideBottomNavigation || !self.cartFloatingBarCoordinator.state.isVisible) {
        [self pp_setPremiumBottomNavigationHidden:shouldHideBottomNavigation animated:NO];
    }
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:viewController animated:animated];
    [self.cartFloatingBarCoordinator refreshForCurrentVisibleControllerAnimated:animated];
    [self pp_applyBottomNavigationClearanceToVisibleLists];
}

#pragma mark - KVO: prevent tabBar flash during navigation transitions

/// UIKit's UITabBarController internally toggles self.tabBar.hidden during
/// push/pop transitions. On iOS 26+ we observe the hidden property and
/// immediately revert any attempt to show the system tabBar.
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if (context == kPPTabBarHiddenObservationContext && !self.useLegacyBar) {
        if (object == self.tabBar && !self.tabBar.hidden) {
            self.tabBar.hidden = YES;
            self.tabBar.alpha = 0.0;
            self.tabBar.userInteractionEnabled = NO;
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)dealloc {
    if (!self.useLegacyBar) {
        @try { [self.tabBar removeObserver:self forKeyPath:@"hidden" context:kPPTabBarHiddenObservationContext]; }
        @catch (NSException *e) {}
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}




- (void)searchButtonTapped {
    [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:NO];
}



- (void)pp_handleRouteToSearchAccessories
{
    [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:YES];
}

- (nullable UINavigationController *)pp_preferredNavigationControllerForSearchExperience
{
    UIViewController *selectedVC = self.selectedViewController;
    BOOL shouldFallbackToHome =
        (self.selectedIndex == PPRootTabIndexAdd ||
         ![selectedVC isKindOfClass:UINavigationController.class]);

    if (shouldFallbackToHome) {
        if (self.viewControllers.count <= PPRootTabIndexHome) {
            return nil;
        }
        self.selectedIndex = PPRootTabIndexHome;
        selectedVC = self.viewControllers[PPRootTabIndexHome];
    }

    return [selectedVC isKindOfClass:UINavigationController.class]
        ? (UINavigationController *)selectedVC
        : nil;
}

- (nullable PPSearchViewController *)pp_existingSearchControllerInNavigationController:(UINavigationController *)navigationController
{
    for (UIViewController *viewController in navigationController.viewControllers.reverseObjectEnumerator) {
        if ([viewController isKindOfClass:PPSearchViewController.class]) {
            return (PPSearchViewController *)viewController;
        }
    }
    return nil;
}

- (void)pp_openSearchExperienceFromCurrentContextOpeningAccessories:(BOOL)openAccessories
{
    PPSearchViewController *searchController = [PPSearchViewController new];
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:searchController];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];

    if (openAccessories) {
        [searchController openAccessoriesAll];
        return;
    }
    [searchController focusSearchField];
}


- (void)openAccessoriesAll
{
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:self.selectedViewController animated:YES];
}
- (void)showSystemTabBar
{
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:self.selectedViewController animated:YES];
}

- (void)hideSystemTabBar
{
    [self pp_setPremiumBottomNavigationHidden:YES animated:YES];
}

- (void)pp_setBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    [self setPremiumTabDockViewHidden:hidden animation:animated];
}

- (BOOL)pp_openChatThreadFromNotification:(ChatThreadModel *)thread animated:(BOOL)animated
{
    if (!thread || self.viewControllers.count <= PPRootTabIndexChats) {
        return NO;
    }

    UIViewController *targetController = self.viewControllers[PPRootTabIndexChats];
    if (![targetController isKindOfClass:UINavigationController.class]) {
        return NO;
    }
    if (![self tabBarController:self shouldSelectViewController:targetController]) {
        return NO;
    }

    UINavigationController *chatNavigationController = (UINavigationController *)targetController;
    self.selectedIndex = PPRootTabIndexChats;
    [self tabBarController:self didSelectViewController:targetController];

    UIViewController *rootController = chatNavigationController.viewControllers.firstObject;
    if (rootController && chatNavigationController.viewControllers.count > 1) {
        [chatNavigationController setViewControllers:@[rootController] animated:NO];
    }

    ChMessagingController *chatController =
        [[ChMessagingController alloc] initWithChatThread:thread];
    chatController.keepsBottomNavigationVisibleForNotificationHandoff = YES;
    chatController.hidesBottomBarWhenPushed = NO;

    [self pp_setBottomNavigationHidden:NO animated:animated];
    [chatNavigationController pushViewController:chatController animated:animated];
    [self pp_applyPremiumTabSelectionAnimated:animated];
    return YES;
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
     
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // UIKit resolves system-tab title frames during the root's first layout
    // pass. Reconcile them after that pass so the final Arabic/English glyph
    // is never clipped on initial presentation.
    [self pp_refreshLegacyTabBarTitleLayout];
    [self pp_updatePremiumBottomFadeAppearance];
    [self pp_updateBlockedOverlayTopInset];
    [self pp_updateTabBarSelectionIndicatorIfNeeded];
    [self pp_applyPremiumTabSelectionAnimated:NO];
    [self pp_layoutGuestProfileAnimation];
    [self pp_applyBottomNavigationClearanceToVisibleLists];
    [self.cartFloatingBarCoordinator hostViewDidLayoutSubviews];
    [self pp_raiseBelowIOS26AddButtonAboveSystemTabBar];
    
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            self.premiumDockAppliedItemWidth = 0.0;
            [self pp_updatePremiumBottomFadeAppearance];
            [self pp_applyGuestProfileAnimationTint];
            [self pp_updateTabBarSelectionIndicatorIfNeeded];
            [self.cartFloatingBarCoordinator hostViewDidLayoutSubviews];
        }
    }
}

#pragma mark - Blocked Overlay

- (void)pp_handleBlockedStateNotification:(NSNotification *)notification {
    NSNumber *blockedValue = notification.userInfo[PPUserManagerBlockedStateUserInfoKey];
    BOOL isBlocked = [blockedValue respondsToSelector:@selector(boolValue)]
        ? blockedValue.boolValue
        : (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked);
    [self pp_applyBlockedState:isBlocked animated:YES];
}

- (void)pp_handleUserAccessUpdate:(NSNotification *)notification {
    BOOL effectivelyBlocked = [notification.userInfo[@"effectivelyBlocked"] boolValue];
    [self pp_applyBlockedState:effectivelyBlocked animated:YES];
}

- (void)pp_setupBlockedOverlayIfNeeded {
    if (self.blockedOverlayView) {
        return;
    }

    UIColor *primaryColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *primaryGlowColor = AppPrimaryClrShiner ?: [primaryColor colorWithAlphaComponent:0.94];
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *titleColor = AppForgroundColr ?: UIColor.labelColor;
    UIColor *secondaryTextColor = AppBackgroundClrLigter ?: UIColor.secondaryLabelColor;
    UIColor *whiteTint = UIColor.whiteColor;
    NSString *brandName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (brandName.length == 0) {
        brandName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: @"Pure Pets";
    }

    UIControl *overlay = [[UIControl alloc] init];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.backgroundColor = UIColor.clearColor;
    overlay.hidden = YES;
    overlay.alpha = 0.0;
    overlay.accessibilityViewIsModal = YES;
    [self.view addSubview:overlay];

    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIBlurEffect *backdropEffect = nil;
    if (@available(iOS 13.0, *)) {
        backdropEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    } else {
        backdropEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }

    UIVisualEffectView *backdropView = [[UIVisualEffectView alloc] initWithEffect:backdropEffect];
    backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    backdropView.userInteractionEnabled = NO;
    [overlay addSubview:backdropView];

    UIView *scrimView = [[UIView alloc] init];
    scrimView.translatesAutoresizingMaskIntoConstraints = NO;
    scrimView.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.34];
    scrimView.userInteractionEnabled = NO;
    [overlay addSubview:scrimView];

    UIView *topGlowView = [[UIView alloc] init];
    topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    topGlowView.userInteractionEnabled = NO;
    topGlowView.backgroundColor = [primaryColor colorWithAlphaComponent:0.20];
    topGlowView.layer.cornerRadius = 154.0;
    [topGlowView pp_setShadowColor:primaryColor];
    topGlowView.layer.shadowOpacity = 0.24f;
    topGlowView.layer.shadowRadius = 48.0f;
    topGlowView.layer.shadowOffset = CGSizeZero;
    [overlay addSubview:topGlowView];

    UIView *bottomGlowView = [[UIView alloc] init];
    bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlowView.userInteractionEnabled = NO;
    bottomGlowView.backgroundColor = [primaryGlowColor colorWithAlphaComponent:0.14];
    bottomGlowView.layer.cornerRadius = 144.0;
    [bottomGlowView pp_setShadowColor:primaryGlowColor];
    bottomGlowView.layer.shadowOpacity = 0.16f;
    bottomGlowView.layer.shadowRadius = 44.0f;
    bottomGlowView.layer.shadowOffset = CGSizeZero;
    [overlay addSubview:bottomGlowView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:contentView];

    self.blockedOverlayTopConstraint = [contentView.topAnchor constraintGreaterThanOrEqualToAnchor:overlay.topAnchor constant:120.0];
    NSLayoutConstraint *contentPreferredWidth =
        [contentView.widthAnchor constraintEqualToAnchor:overlay.widthAnchor constant:-40.0];
    contentPreferredWidth.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *contentVerticalCenter =
        [contentView.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor constant:-14.0];
    contentVerticalCenter.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [backdropView.topAnchor constraintEqualToAnchor:overlay.topAnchor],
        [backdropView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
        [backdropView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],
        [backdropView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],

        [scrimView.topAnchor constraintEqualToAnchor:overlay.topAnchor],
        [scrimView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
        [scrimView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],
        [scrimView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],

        [topGlowView.widthAnchor constraintEqualToConstant:308.0],
        [topGlowView.heightAnchor constraintEqualToConstant:308.0],
        [topGlowView.topAnchor constraintEqualToAnchor:overlay.topAnchor constant:-58.0],
        [topGlowView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:-84.0],

        [bottomGlowView.widthAnchor constraintEqualToConstant:288.0],
        [bottomGlowView.heightAnchor constraintEqualToConstant:288.0],
        [bottomGlowView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:74.0],
        [bottomGlowView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:54.0],

        self.blockedOverlayTopConstraint,
        contentPreferredWidth,
        contentVerticalCenter,
        [contentView.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [contentView.leadingAnchor constraintGreaterThanOrEqualToAnchor:overlay.leadingAnchor constant:20.0],
        [contentView.trailingAnchor constraintLessThanOrEqualToAnchor:overlay.trailingAnchor constant:-20.0],
        [contentView.widthAnchor constraintLessThanOrEqualToConstant:430.0],
        [contentView.bottomAnchor constraintLessThanOrEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-28.0]
    ]];

    UIView *brandPillView = [[UIView alloc] init];
    brandPillView.translatesAutoresizingMaskIntoConstraints = NO;
    brandPillView.backgroundColor = [whiteTint colorWithAlphaComponent:0.10];
    brandPillView.layer.cornerRadius = 20.0;
    brandPillView.layer.borderWidth = 1.0;
    [brandPillView pp_setBorderColor:[whiteTint colorWithAlphaComponent:0.12]];
    [brandPillView pp_setShadowColor:UIColor.blackColor];
    brandPillView.layer.shadowOpacity = 0.08f;
    brandPillView.layer.shadowRadius = 12.0f;
    brandPillView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    if (@available(iOS 13.0, *)) {
        brandPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *brandIconPlateView = [[UIView alloc] init];
    brandIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    brandIconPlateView.backgroundColor = [primaryColor colorWithAlphaComponent:0.18];
    brandIconPlateView.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) {
        brandIconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *brandIconView = [[UIImageView alloc] init];
    brandIconView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        brandIconView.image = [UIImage systemImageNamed:@"lock.shield.fill"];
    }
    brandIconView.contentMode = UIViewContentModeScaleAspectFit;
    brandIconView.tintColor = primaryColor;

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    brandLabel.text = brandName;
    brandLabel.textAlignment = NSTextAlignmentCenter;
    brandLabel.textColor = [whiteTint colorWithAlphaComponent:0.96];
    brandLabel.font = [GM boldFontWithSize:13];

    [brandIconPlateView addSubview:brandIconView];
    [brandPillView addSubview:brandIconPlateView];
    [brandPillView addSubview:brandLabel];

    [NSLayoutConstraint activateConstraints:@[
        [brandPillView.heightAnchor constraintEqualToConstant:40.0],
        [brandIconPlateView.leadingAnchor constraintEqualToAnchor:brandPillView.leadingAnchor constant:8.0],
        [brandIconPlateView.centerYAnchor constraintEqualToAnchor:brandPillView.centerYAnchor],
        [brandIconPlateView.widthAnchor constraintEqualToConstant:24.0],
        [brandIconPlateView.heightAnchor constraintEqualToConstant:24.0],
        [brandIconView.centerXAnchor constraintEqualToAnchor:brandIconPlateView.centerXAnchor],
        [brandIconView.centerYAnchor constraintEqualToAnchor:brandIconPlateView.centerYAnchor],
        [brandIconView.widthAnchor constraintEqualToConstant:13.0],
        [brandIconView.heightAnchor constraintEqualToConstant:13.0],
        [brandLabel.topAnchor constraintEqualToAnchor:brandPillView.topAnchor],
        [brandLabel.bottomAnchor constraintEqualToAnchor:brandPillView.bottomAnchor],
        [brandLabel.leadingAnchor constraintEqualToAnchor:brandIconPlateView.trailingAnchor constant:10.0],
        [brandLabel.trailingAnchor constraintEqualToAnchor:brandPillView.trailingAnchor constant:-14.0]
    ]];

    UIView *animationPlateView = [[UIView alloc] init];
    animationPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    animationPlateView.backgroundColor = [surfaceColor colorWithAlphaComponent:0.78];
    animationPlateView.layer.cornerRadius = 42.0;
    animationPlateView.layer.borderWidth = 1.0;
    [animationPlateView pp_setBorderColor:[whiteTint colorWithAlphaComponent:0.14]];
    [animationPlateView pp_setShadowColor:UIColor.blackColor];
    animationPlateView.layer.shadowOpacity = 0.18f;
    animationPlateView.layer.shadowRadius = 30.0f;
    animationPlateView.layer.shadowOffset = CGSizeMake(0.0, 20.0);
    if (@available(iOS 13.0, *)) {
        animationPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *animationGlowView = [[UIView alloc] init];
    animationGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    animationGlowView.userInteractionEnabled = NO;
    animationGlowView.backgroundColor = [primaryGlowColor colorWithAlphaComponent:0.16];
    animationGlowView.layer.cornerRadius = 56.0;
    [animationGlowView pp_setShadowColor:primaryGlowColor];
    animationGlowView.layer.shadowOpacity = 0.18f;
    animationGlowView.layer.shadowRadius = 24.0f;
    animationGlowView.layer.shadowOffset = CGSizeZero;

    [animationPlateView addSubview:animationGlowView];

    LOTAnimationView *headerAnimationView = [[LOTAnimationView alloc] init];
    headerAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    headerAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    headerAnimationView.loopAnimation = YES;
    headerAnimationView.animationSpeed = 1.0;
    [animationPlateView addSubview:headerAnimationView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"auth_account_blocked_title");
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = titleColor;
    titleLabel.font = [GM boldFontWithSize:30];
    titleLabel.numberOfLines = 0;
    titleLabel.alpha = 0.98;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"auth_account_blocked_message");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.textColor = [secondaryTextColor colorWithAlphaComponent:0.96];
    subtitleLabel.font = [GM MidFontWithSize:16];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.alpha = 0.98;

    UIButton *contactSupportButton =
    [self pp_makeBlockedOverlayButtonWithTitle:kLang(@"order_support_button")
                                    emphasized:YES
                                   destructive:NO
                                        action:@selector(pp_blockedContactSupportTapped)];

    UIButton *signOutButton =
    [self pp_makeBlockedOverlayButtonWithTitle:kLang(@"logout")
                                    emphasized:NO
                                   destructive:YES
                                        action:@selector(pp_blockedSignOutTapped)];

    UIStackView *actionStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        contactSupportButton,
        signOutButton
    ]];
    actionStack.translatesAutoresizingMaskIntoConstraints = NO;
    actionStack.axis = UILayoutConstraintAxisVertical;
    actionStack.alignment = UIStackViewAlignmentFill;
    actionStack.spacing = 12.0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        brandPillView,
        animationPlateView,
        titleLabel,
        subtitleLabel,
        actionStack
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16.0;
    [contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [animationPlateView.widthAnchor constraintEqualToConstant:172.0],
        [animationPlateView.heightAnchor constraintEqualToConstant:172.0],
        [animationGlowView.centerXAnchor constraintEqualToAnchor:animationPlateView.centerXAnchor],
        [animationGlowView.centerYAnchor constraintEqualToAnchor:animationPlateView.centerYAnchor],
        [animationGlowView.widthAnchor constraintEqualToConstant:112.0],
        [animationGlowView.heightAnchor constraintEqualToConstant:112.0],
        [headerAnimationView.centerXAnchor constraintEqualToAnchor:animationPlateView.centerXAnchor],
        [headerAnimationView.centerYAnchor constraintEqualToAnchor:animationPlateView.centerYAnchor],
        [headerAnimationView.widthAnchor constraintEqualToAnchor:animationPlateView.widthAnchor multiplier:0.74],
        [headerAnimationView.heightAnchor constraintEqualToAnchor:headerAnimationView.widthAnchor],
        [contactSupportButton.heightAnchor constraintEqualToConstant:56.0],
        [signOutButton.heightAnchor constraintEqualToConstant:52.0],
        [titleLabel.widthAnchor constraintEqualToAnchor:contentView.widthAnchor],
        [subtitleLabel.widthAnchor constraintEqualToAnchor:contentView.widthAnchor],
        [actionStack.widthAnchor constraintEqualToAnchor:contentView.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];

    [stack setCustomSpacing:22.0 afterView:brandPillView];
    [stack setCustomSpacing:18.0 afterView:animationPlateView];
    [stack setCustomSpacing:10.0 afterView:titleLabel];
    [stack setCustomSpacing:28.0 afterView:subtitleLabel];

    __weak LOTAnimationView *weakAnimationView = headerAnimationView;
    [AppClasses setAnimationNamed:@"contactUs"
                           ToView:headerAnimationView
                        withSpeed:1.0
                       completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LOTAnimationView *strongAnimationView = weakAnimationView;
            if (!strongAnimationView || !success) {
                return;
            }
            [strongAnimationView play];
        });
    }];

    self.blockedOverlayView = overlay;
    self.blockedOverlayCardView = contentView;
    self.blockedHeaderAnimationView = headerAnimationView;
    self.blockedContactButton = contactSupportButton;
}

- (UIButton *)pp_makeBlockedOverlayButtonWithTitle:(NSString *)title
                                        emphasized:(BOOL)emphasized
                                       destructive:(BOOL)destructive
                                            action:(SEL)action {
    UIColor *primaryColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *whiteTint = UIColor.whiteColor;
    UIColor *destructiveColor = UIColor.systemRedColor;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [GM boldFontWithSize:17];
    button.layer.cornerRadius = 18.0;
    button.layer.masksToBounds = NO;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (emphasized) {
        button.backgroundColor = primaryColor;
        [button setTitleColor:whiteTint forState:UIControlStateNormal];
        [button pp_setShadowColor:primaryColor];
        button.layer.shadowOpacity = 0.24f;
        button.layer.shadowRadius = 18.0f;
        button.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    } else {
        UIColor *foregroundColor = destructive ? destructiveColor : titleColor;
        button.backgroundColor = [surfaceColor colorWithAlphaComponent:0.88];
        button.layer.borderWidth = 1.0;
        [button pp_setBorderColor:[foregroundColor colorWithAlphaComponent:destructive ? 0.22 : 0.12]];
        [button setTitleColor:foregroundColor forState:UIControlStateNormal];
        [button pp_setShadowColor:UIColor.blackColor];
        button.layer.shadowOpacity = 0.06f;
        button.layer.shadowRadius = 10.0f;
        button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    }

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)pp_applyBlockedState:(BOOL)isBlocked animated:(BOOL)animated {
    BOOL shouldShow = isBlocked && UserManager.sharedManager.isUserLoggedIn;
    if (!shouldShow && !self.blockedOverlayView) {
        return;
    }

    [self pp_setupBlockedOverlayIfNeeded];
    [self pp_updateBlockedOverlayTopInset];

    if (shouldShow) {
        self.blockedOverlayView.hidden = NO;
        [self.view bringSubviewToFront:self.blockedOverlayView];
    }

    CGAffineTransform hiddenTransform =
        CGAffineTransformConcat(CGAffineTransformMakeScale(0.97, 0.97),
                                CGAffineTransformMakeTranslation(0.0, 18.0));
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;
    BOOL isPresenting = shouldShow && (self.blockedOverlayView.hidden || self.blockedOverlayView.alpha < 0.01f);

    if (shouldShow && isPresenting) {
        self.blockedOverlayView.alpha = 0.0;
        self.blockedOverlayCardView.alpha = 0.0;
        self.blockedOverlayCardView.transform = hiddenTransform;
    }

    void (^completion)(BOOL) = ^(BOOL finished) {
        (void)finished;
        if (!shouldShow) {
            self.blockedOverlayView.hidden = YES;
            [self.blockedHeaderAnimationView stop];
            self.blockedOverlayCardView.transform = hiddenTransform;
            self.blockedOverlayCardView.alpha = 0.0;
        } else {
            [self.blockedHeaderAnimationView play];
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.24
                         animations:^{
            self.blockedOverlayView.alpha = targetAlpha;
        } completion:completion];

        [UIView animateWithDuration:shouldShow ? 0.56 : 0.20
                              delay:0.0
             usingSpringWithDamping:shouldShow ? 0.86 : 1.0
              initialSpringVelocity:shouldShow ? 0.24 : 0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.blockedOverlayCardView.alpha = shouldShow ? 1.0 : 0.0;
            self.blockedOverlayCardView.transform = shouldShow ? CGAffineTransformIdentity : hiddenTransform;
        } completion:nil];
    } else {
        self.blockedOverlayView.alpha = targetAlpha;
        self.blockedOverlayCardView.alpha = shouldShow ? 1.0 : 0.0;
        self.blockedOverlayCardView.transform = shouldShow ? CGAffineTransformIdentity : hiddenTransform;
        completion(YES);
    }
}

- (void)pp_updateBlockedOverlayTopInset {
    if (!self.blockedOverlayTopConstraint || !self.blockedOverlayView) {
        return;
    }

    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat navBottom = 0.0;

    UINavigationController *activeNav = [self pp_activeNavigationController];
    if (activeNav && !activeNav.navigationBarHidden) {
        CGRect navFrameInRoot = [activeNav.view convertRect:activeNav.navigationBar.frame toView:self.view];
        navBottom = CGRectGetMaxY(navFrameInRoot);
    }

    self.blockedOverlayTopConstraint.constant = MAX(safeTop, navBottom) + 24.0;
}

- (UINavigationController *)pp_activeNavigationController {
    UIViewController *selected = self.selectedViewController;
    if ([selected isKindOfClass:UINavigationController.class]) {
        return (UINavigationController *)selected;
    }
    if (selected.navigationController) {
        return selected.navigationController;
    }
    return nil;
}

- (void)pp_blockedSignOutTapped {
    __weak typeof(self) weakSelf = self;
    [UserManager.sharedManager signOutCurrentUserWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (error) {
                [PPAlertHelper showErrorIn:strongSelf
                                     title:kLang(@"logout")
                                  subtitle:error.localizedDescription ?: @"Sign out failed."];
                return;
            }
            [strongSelf pp_applyBlockedState:NO animated:YES];
        });
    }];
}

- (void)pp_blockedContactSupportTapped {
    UIAlertController *menu = [UIAlertController
                               alertControllerWithTitle:kLang(@"cart_support_menu_title")
                               message:nil
                               preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:kLang(@"order_support_request_call")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses callPhoneNumber:kPPBlockedOverlaySupportPhoneNumber fromViewController:self];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:kLang(@"cart_support_chat")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses startWhatsAppWith:kPPBlockedOverlaySupportPhoneNumber fromViewController:self];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.blockedContactButton ?: self.view;
        popover.sourceRect = self.blockedContactButton ? self.blockedContactButton.bounds :
            CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:menu animated:YES completion:nil];
}


- (void)handleBarSelection:(PPBarTag)tag {

    switch (tag) {

        case PPBarTagHome:
            self.selectedIndex = PPRootTabIndexHome;
            break;

        case PPBarTagChats:
            self.selectedIndex = PPRootTabIndexChats;
            break;

        case PPBarTagOrdersHistory:
            self.selectedIndex = PPRootTabIndexMyAds;
            break;

        case PPBarTagNotifications:
            self.selectedIndex = PPRootTabIndexMenu;
            break;

        case PPBarTagSearch:
        {
            [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:NO];
            break;
        }
        case PPBarTagNewAd:
            [self presentBottomSheet];
            break;

        case PPBarTagCart:
           // [self openCart];
            break;
    }
}


// Show correct unread counts on tab index 1 (Chats / Notifications)
- (void)updateUnreads
{
    NSLog(@"[Chats] updateUnreads (live)");

    // 🔥 Pull from in-memory unread store (no Firestore hit)
    NSDictionary<NSString *, NSNumber *> *counts =
        [ChManager sharedManager].liveUnreadCounts;

    NSInteger totalUnreadCount = 0;
    for (NSNumber *value in counts.allValues) {
        totalUnreadCount += value.integerValue;
    }

    if (self.viewControllers.count <= PPRootTabIndexChats) return;

    UINavigationController *notiNav =
        (UINavigationController *)self.viewControllers[PPRootTabIndexChats];

    UITabBarItem *item = notiNav.tabBarItem;
    if (!item) return;

    if (totalUnreadCount > 0) {
        item.badgeValue =
            totalUnreadCount > 99 ? @"99+" :
            [NSString stringWithFormat:@"%ld", (long)totalUnreadCount];
    } else {
        item.badgeValue = nil;
    }

    if (@available(iOS 15.0, *)) {
        item.badgeColor = AppPrimaryClr;
    }
    [self pp_updatePremiumChatsBadgeWithCount:totalUnreadCount];

    NSLog(@"🔔 [TabUnread] total = %ld", (long)totalUnreadCount);
}


#pragma mark - Helpers

- (UIViewController *)pp_makeAddActionPlaceholderViewController
{
    if (self.addActionPlaceholderViewController) {
        return self.addActionPlaceholderViewController;
    }

    UIViewController *placeholder = [UIViewController new];
    placeholder.tabBarItem.accessibilityIdentifier = @"pp.root.add.placeholder";
    self.addActionPlaceholderViewController = placeholder;
    return placeholder;
}

- (UIViewController *)pp_makeSettingsRootViewController
{
     SettingVC *settingsViewController =
    [SettingVC new];
    if ([settingsViewController isKindOfClass:SettingVC.class]) {
        return settingsViewController;
    }
    return [SettingVC new];
}

- (UINavigationController *)nav:(UIViewController *)vc
                          title:(NSString *)title
                           icon:(NSString *)icon
                  selectedImage:(NSString *)selectedImage{

    PPNavigationController *nav =
    [[PPNavigationController alloc] initWithRootViewController:vc];

    nav.navigationBarHidden = NO;
    UIImageSymbolConfiguration *symbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                         weight:UIImageSymbolWeightMedium
                                                          scale:UIImageSymbolScaleMedium];
    UIImage *iconm = icon.length > 0
        ? [[UIImage systemImageNamed:icon withConfiguration:symbolConfiguration]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
        : nil;
    if (!iconm && icon.length > 0) {
        iconm = [UIImage pp_symbolNamed:icon
                              pointSize:20.0
                                 weight:UIImageSymbolWeightMedium
                                  scale:UIImageSymbolScaleMedium
                                palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                           makeTemplate:YES];
    }
    UIImage *selectedIcon = selectedImage.length > 0
        ? [[UIImage systemImageNamed:selectedImage withConfiguration:symbolConfiguration]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
        : nil;
    if (!selectedIcon && selectedImage.length > 0) {
        selectedIcon = [UIImage pp_symbolNamed:selectedImage
                                     pointSize:20.0
                                        weight:UIImageSymbolWeightMedium
                                         scale:UIImageSymbolScaleMedium
                                       palette:@[AppPrimaryClr ?: AppPrimaryTextClr ?: UIColor.labelColor]
                                  makeTemplate:YES];
    }
    UITabBarItem *item =
    [[UITabBarItem alloc] initWithTitle:title
                                  image:iconm
                          selectedImage:selectedIcon];// [UIImage systemImageNamed:[NSString stringWithFormat:@"%@.fill",icon]]];

    nav.tabBarItem = item;
    return nav;
}

- (void)pp_applyPremiumTabBarItemMetrics:(UITabBarItem *)item centerAction:(BOOL)centerAction
{
    if (!item) {
        return;
    }

    item.imageInsets = centerAction
        ? UIEdgeInsetsMake(-1.0, 0.0, 1.0, 0.0)
        : UIEdgeInsetsMake(1.0, 0.0, -1.0, 0.0);
    item.titlePositionAdjustment = centerAction
        ? UIOffsetMake(0.0, -1.0)
        : UIOffsetMake(0.0, 1.5);

    if (@available(iOS 13.0, *)) {
        BOOL preservesOriginalArtwork =
            item.image.renderingMode == UIImageRenderingModeAlwaysOriginal ||
            item.selectedImage.renderingMode == UIImageRenderingModeAlwaysOriginal;
        if (preservesOriginalArtwork) {
            return;
        }
        UIImageSymbolConfiguration *symbolConfiguration =
            [UIImageSymbolConfiguration configurationWithPointSize:centerAction ? 21.0 : 18.0
                                                         weight:centerAction ? UIImageSymbolWeightSemibold : UIImageSymbolWeightMedium
                                                          scale:UIImageSymbolScaleMedium];
        item.image = [[item.image imageWithConfiguration:symbolConfiguration]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        item.selectedImage = [[item.selectedImage imageWithConfiguration:symbolConfiguration]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
}

// Floating background (emulates iOS 26 look)
- (void)pp_configureFloatingBackgroundForAppearance:(UITabBarAppearance *)appearance {
    if (@available(iOS 26.0, *)) {
        [appearance configureWithTransparentBackground];
        appearance.backgroundEffect =
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        appearance.backgroundColor =
            [AppForgroundColr colorWithAlphaComponent:0.08];
    } else if (@available(iOS 13.0, *)) {
        [appearance configureWithDefaultBackground];
        appearance.backgroundEffect =
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        appearance.backgroundColor =
            [AppForgroundColr colorWithAlphaComponent:0.82];
    } else {
        appearance.backgroundImage = [UIImage new];
        appearance.shadowImage = [UIImage new];
    }
}

- (void)configureAppearance {
    // WHY: Keep the legacy UITabBar using the same compact premium item rhythm
    // as the custom dock: crisp symbols, small titles, and stable spacing.
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        [self pp_configureFloatingBackgroundForAppearance:appearance];
        
        UIFont *titleFont = [GM boldFontWithSize:10.0] ?: [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
        UIColor *normalIconColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.76];
        UIColor *selectedIconColor = AppPrimaryClr ?: UIColor.systemTealColor;
        NSDictionary<NSAttributedStringKey, id> *selectedTitle =
        @{ NSForegroundColorAttributeName: selectedIconColor,
           NSFontAttributeName: titleFont};
        
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedTitle;
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedTitle;
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedTitle;
        
        NSDictionary<NSAttributedStringKey, id> *normalTitle =
        @{ NSForegroundColorAttributeName: normalIconColor,
           NSFontAttributeName: titleFont};
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.stackedLayoutAppearance.selected.iconColor = selectedIconColor;
        appearance.inlineLayoutAppearance.selected.iconColor = selectedIconColor;
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedIconColor;
        appearance.stackedLayoutAppearance.normal.iconColor = normalIconColor;
        appearance.inlineLayoutAppearance.normal.iconColor = normalIconColor;
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalIconColor;
        
        if (@available(iOS 26.0, *)) {
            appearance.shadowColor = UIColor.clearColor;
        } else {
            appearance.shadowColor = UIColor.clearColor;
        }
        
        UIOffset titleOffset = UIOffsetMake(0.0, 1.5);

        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = titleOffset;

        appearance.inlineLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.inlineLayoutAppearance.selected.titlePositionAdjustment = titleOffset;

        appearance.compactInlineLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.compactInlineLayoutAppearance.selected.titlePositionAdjustment = titleOffset;
        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
        [self.tabBar pp_setShadowColor:UIColor.blackColor];
        self.tabBar.layer.shadowOpacity = 0.12;
        self.tabBar.layer.shadowRadius = 18.0;
        self.tabBar.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        self.tabBar.layer.masksToBounds = NO;
        
    } else {
        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
        @{ NSForegroundColorAttributeName: UIColor.clearColor };
        [[UITabBarItem appearance] setTitleTextAttributes:clearSelectedTitle forState:UIControlStateSelected];
    }

    // iOS <26: Set proper icon tinting on the tab bar
    if (self.useLegacyBar) {
        self.tabBar.tintColor = AppPrimaryClr;
        self.tabBar.unselectedItemTintColor = UIColor.secondaryLabelColor;
    }
}


- (void)pp_updateTabBarSelectionIndicatorIfNeeded
{
    UITabBar *dockTabBar = self.premiumTabbarView;
    if (!dockTabBar || dockTabBar.items.count == 0) {
        return;
    }

    CGSize tabBarSize = dockTabBar.bounds.size;
    if (tabBarSize.width <= 0.0 || tabBarSize.height <= 0.0) {
        return;
    }

    CGFloat itemWidth =
        floor(tabBarSize.width / MAX(1.0, (CGFloat)dockTabBar.items.count));
    if (itemWidth <= 0.0) {
        return;
    }

    CGSize itemSize = CGSizeMake(itemWidth, tabBarSize.height);
    CGSize indicatorSize =
        CGSizeMake(MIN(72.0, MAX(52.0, itemWidth - 12.0)),
                   MIN(48.0, MAX(44.0, tabBarSize.height - 28.0)));
    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *fillColor = [accent colorWithAlphaComponent:0.08];
    UIColor *strokeColor = [accent colorWithAlphaComponent:0.12];
    UIImage *indicatorImage =
        [self pp_tabBarSelectionIndicatorImageForItemSize:itemSize
                                            indicatorSize:indicatorSize
                                                fillColor:fillColor
                                              strokeColor:strokeColor];

    if (@available(iOS 26.0, *)) {
        BOOL geometryAlreadyApplied =
            fabs(self.premiumDockAppliedItemWidth - itemWidth) < 0.5 &&
            dockTabBar.standardAppearance.selectionIndicatorImage != nil;
        if (geometryAlreadyApplied) {
            return;
        }

        UITabBarAppearance *appearance = [dockTabBar.standardAppearance copy];
        appearance.stackedItemPositioning = UITabBarItemPositioningCentered;
        appearance.stackedItemWidth = itemWidth;
        appearance.stackedItemSpacing = 0.0;
        appearance.selectionIndicatorImage =
            [indicatorImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

        dockTabBar.itemPositioning = UITabBarItemPositioningCentered;
        dockTabBar.itemWidth = itemWidth;
        dockTabBar.itemSpacing = 0.0;
        dockTabBar.standardAppearance = appearance;
        dockTabBar.scrollEdgeAppearance = [appearance copy];
        self.premiumDockAppliedItemWidth = itemWidth;
        return;
    }

    dockTabBar.selectionIndicatorImage = indicatorImage;
}

- (UIImage *)pp_tabBarSelectionIndicatorImageForItemSize:(CGSize)itemSize
                                           indicatorSize:(CGSize)indicatorSize
                                               fillColor:(UIColor *)fillColor
                                             strokeColor:(UIColor *)strokeColor
{
    if (itemSize.width <= 0.0 || itemSize.height <= 0.0) {
        return nil;
    }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:itemSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        CGRect indicatorRect = CGRectMake((itemSize.width - indicatorSize.width) * 0.5,
                                          (itemSize.height - indicatorSize.height) * 0.5,
                                          indicatorSize.width,
                                          indicatorSize.height);
        CGFloat cornerRadius = MIN(16.0, indicatorSize.height * 0.5);
        UIBezierPath *path =
            [UIBezierPath bezierPathWithRoundedRect:indicatorRect
                                      cornerRadius:cornerRadius];
        [fillColor setFill];
        [path fill];
        [strokeColor setStroke];
        path.lineWidth = 0.75;
        [path stroke];
    }];
}

- (void)pp_setupPremiumBottomNavigation
{
    [self pp_setupPremiumBottomFade];
    [self addPlusTabBarButton];
    //[self addNovaTabBarButton];
    [self pp_setupPremiumNovaButton];

    if (self.useLegacyBar) {
        // On iOS < 26 keep the original system tab bar visible and skip the custom dock
        self.tabBar.hidden = NO;
        self.tabBar.alpha = 1.0;
        self.tabBar.userInteractionEnabled = YES;
        [self pp_raiseBelowIOS26AddButtonAboveSystemTabBar];
        return;
    }

    self.tabBar.hidden = YES;
    self.tabBar.alpha = 0.0;
    self.tabBar.userInteractionEnabled = NO;

    PPPremiumDockTabBar *dockView = [[PPPremiumDockTabBar alloc] init];
    dockView.translatesAutoresizingMaskIntoConstraints = NO;
    self.premiumDockDelegate = [[PPPremiumDockBarDelegate alloc] init];
    self.premiumDockDelegate.controller = self;
    dockView.delegate = self.premiumDockDelegate;
    dockView.itemPositioning = UITabBarItemPositioningFill;
    dockView.tintColor = AppPrimaryClr ?: UIColor.systemTealColor;
    dockView.unselectedItemTintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.76];
    dockView.backgroundColor = UIColor.clearColor;
    dockView.layer.masksToBounds = NO;
    dockView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:dockView];
    self.premiumTabbarView = dockView;
    
    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    if (@available(iOS 26.0, *)) {
        appearance.stackedItemPositioning = UITabBarItemPositioningFill;
        appearance.stackedItemWidth = 0.0;
        appearance.stackedItemSpacing = 0.0;
    }

    UIColor *normalIconColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.76];
    UIColor *selectedIconColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIFont *titleFont = [GM boldFontWithSize:10] ?: [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    dockView.pp_titleFont = titleFont;
    NSDictionary<NSAttributedStringKey, id> *normalTitleAttributes =
        @{ NSFontAttributeName: titleFont, NSForegroundColorAttributeName: normalIconColor };
    NSDictionary<NSAttributedStringKey, id> *selectedTitleAttributes =
        @{ NSFontAttributeName: titleFont, NSForegroundColorAttributeName: selectedIconColor };

    NSArray<UITabBarItemAppearance *> *itemAppearances = @[
        appearance.stackedLayoutAppearance,
        appearance.inlineLayoutAppearance,
        appearance.compactInlineLayoutAppearance
    ];
    for (UITabBarItemAppearance *itemAppearance in itemAppearances) {
        itemAppearance.normal.iconColor = normalIconColor;
        itemAppearance.selected.iconColor = selectedIconColor;
        itemAppearance.normal.titleTextAttributes = normalTitleAttributes;
        itemAppearance.selected.titleTextAttributes = selectedTitleAttributes;
    }

    dockView.standardAppearance = appearance;
    if (@available(iOS 15.0, *)) {
        dockView.scrollEdgeAppearance = appearance;
    }
    dockView.clipsToBounds = NO;

    NSInteger myAdsTabIndex = [self pp_resolvedMyAdsRootTabIndex];
    NSArray<NSNumber *> *visibleTabIndexes = @[
        @(PPRootTabIndexHome),
        @(myAdsTabIndex),
        @(PPRootTabIndexChats),
       // @(PPRootTabIndexSettings),
        @(PPRootTabIndexOrders)
    ];
    NSMutableArray<UITabBarItem *> *items = [NSMutableArray arrayWithCapacity:visibleTabIndexes.count];
    for (NSNumber *tabIndexValue in visibleTabIndexes) {
        NSInteger index = tabIndexValue.integerValue;
        UIViewController *sourceController = [self pp_viewControllerForRootTabIndex:index];
        if (!sourceController) {
            NSLog(@"[PPRootTabBar] Skipping premium dock item for unavailable tab index=%ld count=%lu",
                  (long)index,
                  (unsigned long)self.viewControllers.count);
            continue;
        }
        UITabBarItem *sourceItem = sourceController.tabBarItem;
        UITabBarItem *item =
            [[UITabBarItem alloc] initWithTitle:sourceItem.title
                                         image:[self pp_premiumSymbolForTabIndex:index selected:NO]
                                 selectedImage:[self pp_premiumSymbolForTabIndex:index selected:YES]];
        item.tag = index;
        item.accessibilityLabel = sourceItem.accessibilityLabel ?: sourceItem.title;
        item.accessibilityHint = sourceItem.accessibilityHint;
        [self pp_applyPremiumTabBarItemMetrics:item centerAction:(index == PPRootTabIndexAdd)];
        [items addObject:item];
    }
    dockView.items = items.copy;
    self.premiumTabItems = items.copy;

    CGFloat dockHeight = 64.0;
    if (@available(iOS 26.0, *)) {
        dockHeight = 83.0;
    }
    NSMutableArray<NSLayoutConstraint *> *dockConstraints = [NSMutableArray arrayWithArray:@[
        [dockView.topAnchor constraintEqualToAnchor:self.leadingTabButton.topAnchor constant:-4],
        [dockView.heightAnchor constraintEqualToConstant:dockHeight]
    ]];
    if (!self.useLegacyBar) {
     
        
        [dockConstraints addObject:
            [dockView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-2.0]];
        
            [dockConstraints addObject:
             [dockView.trailingAnchor constraintEqualToAnchor:self.leadingTabButton.leadingAnchor constant:10.0]];
            
        
    } else {
        [dockConstraints addObject:
            [dockView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:4.0]];
        [dockConstraints addObject:
            [dockView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-4.0]];
    }
    [NSLayoutConstraint activateConstraints:dockConstraints];
    dockView.backgroundColor = UIColor.clearColor;
    // Resolve the real dock width before assigning its initial selected item.
    // Otherwise UIKit can build and retain title labels using a transitional
    // launch-time width, intermittently producing Arabic ellipses.
    [self.view layoutIfNeeded];
    [self pp_applyPremiumTabSelectionAnimated:NO];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        dockView.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
        self.leadingTabButton.alpha = 0.0;
        self.leadingTabButton.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                    CGAffineTransformMakeScale(0.94, 0.94));
        self.premiumNovaButton.alpha = 0.0;
        self.premiumNovaButton.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 8.0),
                                    CGAffineTransformMakeScale(0.94, 0.94));
    }
    [self.view bringSubviewToFront:dockView];
    [self.view bringSubviewToFront:self.leadingTabButton];
    [self.view bringSubviewToFront:self.premiumNovaButton];
    [self pp_applyBottomNavigationClearanceToVisibleLists];
}

- (CGFloat)pp_bottomNavigationContentClearance
{
    CGFloat floatingCartClearance = [self.cartFloatingBarCoordinator currentBottomClearance];
    if (floatingCartClearance > 0.0) {
        return floatingCartClearance;
    }

    CGFloat expectedFloatingCartClearance = [self.cartFloatingBarCoordinator expectedBottomClearanceForVisibleFloatingCart];
    if (expectedFloatingCartClearance > 0.0) {
        return expectedFloatingCartClearance;
    }

    if (self.premiumBottomNavigationHidden) {
        return 0.0;
    }

    CGFloat extraBreathingRoom = 12.0;
    if (!self.useLegacyBar && self.leadingTabButton && !self.leadingTabButton.hidden) {
        CGRect buttonFrame = [self.leadingTabButton.superview convertRect:self.leadingTabButton.frame
                                                                    toView:self.view];
        CGRect dockFrame = CGRectNull;
        if (self.premiumTabbarView && !self.premiumTabbarView.hidden) {
            dockFrame = [self.premiumTabbarView.superview convertRect:self.premiumTabbarView.frame
                                                                toView:self.view];
        }

        CGRect visibleBarFrame = CGRectIsNull(dockFrame) ? buttonFrame : CGRectUnion(buttonFrame, dockFrame);
        if (!CGRectIsEmpty(visibleBarFrame)) {
            CGFloat safeBottomY = CGRectGetMaxY(self.view.bounds) - self.view.safeAreaInsets.bottom;
            CGFloat overlapAboveSafeArea = MAX(0.0, safeBottomY - CGRectGetMinY(visibleBarFrame));
            return ceil(overlapAboveSafeArea + extraBreathingRoom);
        }
    }

    if (!self.tabBar.hidden && self.tabBar.alpha > 0.01) {
        return extraBreathingRoom;
    }

    return 0.0;
}

- (CGFloat)pp_currentBottomNavigationContentClearance
{
    return [self pp_bottomNavigationContentClearance];
}

- (void)pp_handleCartFloatingBarCartUpdated:(NSNotification *)notification
{
    (void)notification;
    UIViewController *visible = [self.cartFloatingBarCoordinator topVisibleViewControllerFrom:self.selectedViewController ?: self];
    if (visible) {
        [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:visible animated:YES];
    }
    [self.cartFloatingBarCoordinator handleCartUpdatedAnimated:YES];
}

- (void)pp_applyBottomNavigationClearanceToVisibleLists
{
    CGFloat clearance = [self pp_bottomNavigationContentClearance];
    for (UIViewController *controller in self.viewControllers) {
        if (!controller.isViewLoaded) {
            continue;
        }
        [self pp_applyBottomNavigationClearance:clearance toListViewsInView:controller.view];
    }
}

- (void)pp_applyBottomNavigationClearance:(CGFloat)clearance toListViewsInView:(UIView *)view
{
    if (!view) {
        return;
    }

    BOOL isSupportedList = [view isKindOfClass:UITableView.class] || [view isKindOfClass:UICollectionView.class];
    if (isSupportedList) {
        UIScrollView *scrollView = (UIScrollView *)view;
        if (CGRectGetHeight(scrollView.bounds) >= 180.0) {
            NSValue *baseContentValue = objc_getAssociatedObject(scrollView, &PPListBaseContentInsetKey);
            NSValue *baseIndicatorValue = objc_getAssociatedObject(scrollView, &PPListBaseIndicatorInsetKey);
            UIEdgeInsets baseContentInset = baseContentValue ? baseContentValue.UIEdgeInsetsValue : scrollView.contentInset;
            UIEdgeInsets baseIndicatorInset = baseIndicatorValue ? baseIndicatorValue.UIEdgeInsetsValue : scrollView.scrollIndicatorInsets;
            NSNumber *previousClearanceValue = objc_getAssociatedObject(scrollView, &PPListAppliedBottomClearanceKey);
            CGFloat previousClearance = previousClearanceValue ? previousClearanceValue.doubleValue : 0.0;

            if (baseContentValue) {
                UIEdgeInsets expectedContentInset = baseContentInset;
                expectedContentInset.bottom = MAX(baseContentInset.bottom, previousClearance);
                if (!UIEdgeInsetsEqualToEdgeInsets(scrollView.contentInset, expectedContentInset)) {
                    UIEdgeInsets refreshedBase = scrollView.contentInset;
                    refreshedBase.bottom = scrollView.contentInset.bottom > expectedContentInset.bottom
                        ? scrollView.contentInset.bottom
                        : baseContentInset.bottom;
                    baseContentInset = refreshedBase;
                }
            }
            if (baseIndicatorValue) {
                UIEdgeInsets expectedIndicatorInset = baseIndicatorInset;
                expectedIndicatorInset.bottom = MAX(baseIndicatorInset.bottom, previousClearance);
                if (!UIEdgeInsetsEqualToEdgeInsets(scrollView.scrollIndicatorInsets, expectedIndicatorInset)) {
                    UIEdgeInsets refreshedBase = scrollView.scrollIndicatorInsets;
                    refreshedBase.bottom = scrollView.scrollIndicatorInsets.bottom > expectedIndicatorInset.bottom
                        ? scrollView.scrollIndicatorInsets.bottom
                        : baseIndicatorInset.bottom;
                    baseIndicatorInset = refreshedBase;
                }
            }

            objc_setAssociatedObject(scrollView,
                                     &PPListBaseContentInsetKey,
                                     [NSValue valueWithUIEdgeInsets:baseContentInset],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(scrollView,
                                     &PPListBaseIndicatorInsetKey,
                                     [NSValue valueWithUIEdgeInsets:baseIndicatorInset],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(scrollView,
                                     &PPListAppliedBottomClearanceKey,
                                     @(clearance),
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            UIEdgeInsets contentInset = baseContentInset;
            contentInset.bottom = MAX(baseContentInset.bottom, clearance);
            UIEdgeInsets indicatorInset = baseIndicatorInset;
            indicatorInset.bottom = MAX(baseIndicatorInset.bottom, clearance);

            if (!UIEdgeInsetsEqualToEdgeInsets(scrollView.contentInset, contentInset)) {
                scrollView.contentInset = contentInset;
            }
            if (!UIEdgeInsetsEqualToEdgeInsets(scrollView.scrollIndicatorInsets, indicatorInset)) {
                scrollView.scrollIndicatorInsets = indicatorInset;
            }
        }
    }

    for (UIView *subview in view.subviews) {
        [self pp_applyBottomNavigationClearance:clearance toListViewsInView:subview];
    }
}

- (void)pp_setupPremiumBottomFade
{
    if (self.premiumBottomFadeView) {
        [self pp_updatePremiumBottomFadeAppearance];
        return;
    }
    PPBottomFadeView *fadeView = [[PPBottomFadeView alloc] init];
    fadeView.translatesAutoresizingMaskIntoConstraints = NO;
    fadeView.userInteractionEnabled = NO;
    fadeView.backgroundColor = UIColor.clearColor;

    CAGradientLayer *gradientLayer = (CAGradientLayer *)fadeView.layer;
    gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    gradientLayer.endPoint = CGPointMake(0.5, 1.0);
    gradientLayer.locations = @[@0.0, @0.85];

    [self.view addSubview:fadeView];
    self.premiumBottomFadeView = fadeView;
    [self pp_updatePremiumBottomFadeAppearance];

    if (self.useLegacyBar) {
        fadeView.alpha = 0.0;
    }

    [NSLayoutConstraint activateConstraints:@[
        [fadeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [fadeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [fadeView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [fadeView.heightAnchor constraintEqualToConstant:70.0]
    ]];
}

- (void)pp_updatePremiumBottomFadeAppearance
{
    if (!self.premiumBottomFadeView) {
        return;
    }

    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *fadeColor = isDark
        ? UIColor.blackColor
        : (bageColor ?: AppBackgroundClr ?: UIColor.systemBackgroundColor);

    CAGradientLayer *gradientLayer = (CAGradientLayer *)self.premiumBottomFadeView.layer;
    gradientLayer.colors = @[
        (__bridge id)[fadeColor colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)fadeColor.CGColor
    ];
}

- (void)pp_setupPremiumNovaButton
{
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.adjustsImageWhenHighlighted = NO;
    button.layer.cornerRadius = 27.0;
    PPApplyContinuousCorners(button, 27.0);
    button.layer.masksToBounds = NO;
    [button pp_setShadowColor:accentColor];
    button.layer.shadowOpacity = 0.10;
    button.layer.shadowRadius = 14.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration glassButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.baseForegroundColor = accentColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
        button.configuration = configuration;
    } else {
        button.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.88];
        button.layer.borderWidth = 0.5;
        [button pp_setBorderColor:[accentColor colorWithAlphaComponent:0.16]];
    }

    button.accessibilityLabel = kLang(@"nova_chat_accessibility") ?: @"Chat with Nova";
    button.accessibilityTraits = UIAccessibilityTraitButton;
    [button addTarget:self action:@selector(pp_novaButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_premiumControlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_premiumControlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.view addSubview:button];
    self.premiumNovaButton = button;
    self.premiumNovaVisibleByConfiguration = [self pp_cachedNovaFloatingVisibility];

    LOTAnimationView *animationView = [[LOTAnimationView alloc] init];
    animationView.translatesAutoresizingMaskIntoConstraints = NO;
    animationView.userInteractionEnabled = NO;
    animationView.contentMode = UIViewContentModeScaleAspectFit;
    animationView.loopAnimation = YES;
    animationView.animationSpeed = 0.6;
    [button addSubview:animationView];
    self.premiumNovaLottieView = animationView;

    NSMutableArray<NSLayoutConstraint *> *novaConstraints = [NSMutableArray array];
    if (@available(iOS 26.0, *)) {
        [novaConstraints addObject:[button.centerXAnchor constraintEqualToAnchor:self.leadingTabButton.centerXAnchor]];
    } else {
        [novaConstraints addObject:[button.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0]];
    }
    [novaConstraints addObjectsFromArray:@[
        [button.bottomAnchor constraintEqualToAnchor:self.leadingTabButton.topAnchor constant:-10.0],
        [button.widthAnchor constraintEqualToConstant:58.0],
        [button.heightAnchor constraintEqualToConstant:58.0],
        [animationView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [animationView.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [animationView.widthAnchor constraintEqualToConstant:38.0],
        [animationView.heightAnchor constraintEqualToConstant:38.0]
    ]];
    [NSLayoutConstraint activateConstraints:novaConstraints];
    [self pp_updatePremiumNovaButtonVisibility];

    __weak typeof(self) weakSelf = self;
    __weak LOTAnimationView *weakAnimationView = animationView;
    [AppClasses setAnimationNamed:@"Ncolored"
                            ToView:animationView
                         withSpeed:0.6
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            LOTAnimationView *strongAnimationView = weakAnimationView;
            if (!strongSelf || !strongAnimationView) {
                return;
            }
            if (success) {
                [strongAnimationView play];
                return;
            }
            strongAnimationView.hidden = YES;
            UIImageSymbolConfiguration *configuration =
                [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                 weight:UIImageSymbolWeightMedium];
            UIImage *fallbackIcon =
                [UIImage systemImageNamed:@"sparkles" withConfiguration:configuration];
            if (@available(iOS 26.0, *)) {
                UIButtonConfiguration *buttonConfiguration =
                    strongSelf.premiumNovaButton.configuration;
                buttonConfiguration.image = fallbackIcon;
                buttonConfiguration.baseForegroundColor = accentColor;
                strongSelf.premiumNovaButton.configuration = buttonConfiguration;
            } else {
                [strongSelf.premiumNovaButton setImage:fallbackIcon forState:UIControlStateNormal];
                strongSelf.premiumNovaButton.tintColor = accentColor;
            }
        });
    }];
}

- (BOOL)pp_cachedNovaFloatingVisibility
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:PPNovaFloatingVisibleDefaultsKey] != nil) {
        return [defaults boolForKey:PPNovaFloatingVisibleDefaultsKey];
    }

    NSDictionary *homeConfig = [defaults dictionaryForKey:PPHomeConfigCacheKey];
    id cachedNovaVisible = homeConfig[PPHomeConfigCacheNovaFloatingVisibleKey];
    if ([cachedNovaVisible respondsToSelector:@selector(boolValue)]) {
        return [cachedNovaVisible boolValue];
    }
    return YES;
}

- (void)pp_updatePremiumNovaButtonVisibility
{
    BOOL visible = self.premiumNovaVisibleByConfiguration && !self.premiumBottomNavigationHidden;
    self.premiumNovaButton.hidden = !visible;
    self.premiumNovaButton.userInteractionEnabled = visible;
    if (!visible) {
        self.premiumNovaButton.alpha = 0.0;
    } else if (self.premiumNavigationDidAnimateIn || UIAccessibilityIsReduceMotionEnabled()) {
        self.premiumNovaButton.alpha = 1.0;
    }
}

- (void)pp_novaButtonTapped
{
    if (!self.premiumNovaVisibleByConfiguration || self.premiumBottomNavigationHidden) {
        return;
    }
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [feedback impactOccurred];
    }
    [PPNovaChatViewController presentNovaFromViewController:self];
}

- (void)pp_handleNovaFloatingVisibilityUpdate:(NSNotification *)notification
{
    id visibleValue = notification.userInfo[PPNovaFloatingVisibilityValueKey];
    if (![visibleValue respondsToSelector:@selector(boolValue)]) {
        return;
    }
    self.premiumNovaVisibleByConfiguration = [visibleValue boolValue];
    [NSUserDefaults.standardUserDefaults setBool:self.premiumNovaVisibleByConfiguration
                                          forKey:PPNovaFloatingVisibleDefaultsKey];
    [self pp_updatePremiumNovaButtonVisibility];
}

- (UIImage *)pp_premiumSymbolForTabIndex:(NSInteger)index selected:(BOOL)selected
{
    NSString *normalSymbolName = @"circle";
    NSString *selectedSymbolName = @"circle.fill";
    if (index == PPRootTabIndexMenu) {
        return [self pp_profileTabItemImageSelected:selected];
    }
    if ([self pp_isResolvedMyAdsRootTabIndex:index]) {
        normalSymbolName = @"cart.badge.clock";
        selectedSymbolName = @"cart.badge.clock.fill";
        return [UIImage pp_symbolNamed:(selected ? selectedSymbolName : normalSymbolName)
                             pointSize:selected ? 19.0 : 17.0
                                weight:selected ? UIImageSymbolWeightSemibold : UIImageSymbolWeightRegular
                                  scale:UIImageSymbolScaleMedium
                                palette:@[selected ? (AppPrimaryClr ?: UIColor.systemTealColor) : UIColor.secondaryLabelColor]
                           makeTemplate:YES];
    }
    switch (index) {
        case PPRootTabIndexHome:
            normalSymbolName = @"house";
            selectedSymbolName = @"house.fill";
            break;
        case PPRootTabIndexAdd:
            normalSymbolName = @"plus";
            selectedSymbolName = @"plus.fill";
            break;
        case PPRootTabIndexChats:
            normalSymbolName = @"message.badge.waveform";
            selectedSymbolName = @"message.badge.waveform.fill";
            break;
        default:
            break;
    }
    UIImageSymbolConfiguration *symbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:selected ? 18.0 : 16.0
                                                         weight:selected ? UIImageSymbolWeightSemibold : UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleDefault];
    return [UIImage imageNamed:(selected ? selectedSymbolName : normalSymbolName)] ?: [UIImage systemImageNamed:(selected ? selectedSymbolName : normalSymbolName)
                   withConfiguration:symbolConfiguration];
}

- (BOOL)pp_isGuestProfileTabState
{
    return !PPIsUserLoggedIn;
}

- (UIImage *)pp_profileTabItemImageSelected:(BOOL)selected
{
    if ([self pp_isGuestProfileTabState] && self.guestProfileLottieReady) {
        static UIImage *transparentProfileImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
            format.opaque = NO;
            format.scale = UIScreen.mainScreen.scale;
            UIGraphicsImageRenderer *renderer =
                [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(32.0, 32.0) format:format];
            transparentProfileImage = [[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
            }] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        });
        return transparentProfileImage;
    }
    return [self pp_userMenuTabAvatarImageSelected:selected];
}

- (UIImage *)pp_userMenuTabAvatarImageSelected:(BOOL)selected
{
    CGFloat canvas = 32.0;
    CGFloat avatarSize = selected ? 28.0 : 26.0;
    CGRect avatarRect = CGRectMake((canvas - avatarSize) * 0.5,
                                   (canvas - avatarSize) * 0.5,
                                   avatarSize,
                                   avatarSize);

    UserModel *user = UserManager.sharedManager.currentUser ?: PPCurrentUser;
    BOOL loggedIn = PPIsUserLoggedIn && user;
    NSString *displayName = loggedIn ? PPSafeString(user.PPBestDisplayName) : @"PurePets";
    if (loggedIn && displayName.length == 0) {
        displayName = PPSafeString(user.UserName);
    }
    if (loggedIn && displayName.length == 0) {
        displayName = kLang(@"Guest");
    }

    UIImage *avatar = [PPModernAvatarRenderer avatarImageForName:displayName
                                                            size:avatarSize
                                                           style:PPModernAvatarStyleGlass];
    NSString *avatarCacheKey = PPSafeString(user.UserImageUrl.absoluteString);
    if (avatarCacheKey.length > 0) {
        UIImage *cachedAvatar = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:avatarCacheKey];
        if (!cachedAvatar) {
            cachedAvatar = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:avatarCacheKey];
        }
        if (cachedAvatar) {
            avatar = cachedAvatar;
        }
    }

    UIColor *secondaryColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    UIColor *ringColor = selected
        ? (AppPrimaryClr ?: UIColor.systemBlueColor)
        : [secondaryColor colorWithAlphaComponent:0.28];

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    format.scale = UIScreen.mainScreen.scale;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(canvas, canvas) format:format];

    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGContextRef ctx = context.CGContext;
        CGContextSaveGState(ctx);
        UIBezierPath *clipPath = [UIBezierPath bezierPathWithOvalInRect:avatarRect];
        [clipPath addClip];
        [avatar drawInRect:avatarRect];
        CGContextRestoreGState(ctx);

        CGFloat ringWidth = selected ? 2.0 : 1.0;
        UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(avatarRect, -ringWidth * 0.45, -ringWidth * 0.45)];
        ringPath.lineWidth = ringWidth;
        [ringColor setStroke];
        [ringPath stroke];
    }];

    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)pp_prepareGuestProfileAnimationIfNeeded
{
    if (![self pp_isGuestProfileTabState] ||
        self.guestProfileLottieReady ||
        self.guestProfileLottieLoading) {
        return;
    }

    self.guestProfileLottieLoading = YES;
    __weak typeof(self) weakSelf = self;
    [AppClasses fetchLottieJSONFromFirebasePath:@"Profile.lottie"
                                     completion:^(NSDictionary *jsonDict, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            strongSelf.guestProfileLottieLoading = NO;
            if (error || ![jsonDict isKindOfClass:NSDictionary.class]) {
                NSLog(@"[PPRootTabBarController] Profile.lottie failed to load: %@",
                      error.localizedDescription ?: @"Invalid animation data");
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                NSLog(@"[PPRootTabBarController] Profile.lottie could not create a composition.");
                return;
            }

            LOTAnimationView *animationView = strongSelf.guestProfileLottieView;
            if (!animationView) {
                animationView = [[LOTAnimationView alloc] init];
                animationView.userInteractionEnabled = NO;
                animationView.isAccessibilityElement = NO;
                animationView.accessibilityElementsHidden = YES;
                animationView.backgroundColor = UIColor.clearColor;
                animationView.contentMode = UIViewContentModeScaleAspectFill;
                animationView.clipsToBounds = YES;
                animationView.loopAnimation = YES;
                animationView.animationSpeed = 0.85;
                animationView.hidden = YES;
                strongSelf.guestProfileLottieView = animationView;
            }

            [animationView setSceneModel:composition];
            strongSelf.guestProfileLottieReady = YES;
            [strongSelf pp_applyGuestProfileAnimationTint];
            [strongSelf pp_refreshProfileTabPresentation];
        });
    }];
}

- (void)pp_applyGuestProfileAnimationTint
{
    LOTAnimationView *animationView = self.guestProfileLottieView;
    if (!animationView || !self.guestProfileLottieReady) {
        return;
    }

    UIColor *primaryColor = AppSecondaryTextClr ?: UIColor.systemPinkColor;
    if (@available(iOS 13.0, *)) {
        primaryColor = [primaryColor resolvedColorWithTraitCollection:self.traitCollection];
    }

    LOTColorValueCallback *colorCallback =
        [LOTColorValueCallback withCGColor:primaryColor.CGColor];
    self.guestProfileLottieColorCallback = colorCallback;
    animationView.tintColor = primaryColor;

    // The bundled animation names its paint nodes "F" and "S", so target the
    // shared Color property instead of relying on exported Fill/Stroke names.
    [animationView setValueDelegate:colorCallback
                         forKeypath:[LOTKeypath keypathWithString:@"**.Color"]];
}

- (UITabBarItem *)pp_guestProfileAnimationTabItem
{
    if (!self.useLegacyBar) {
        for (UITabBarItem *item in self.premiumTabItems) {
            if (item.tag == PPRootTabIndexOrders) {
                return item;
            }
        }
        return nil;
    }

    if (self.viewControllers.count <= PPRootTabIndexOrders) {
        return nil;
    }
    return self.viewControllers[PPRootTabIndexOrders].tabBarItem;
}

- (UIView *)pp_viewForTabBarItem:(UITabBarItem *)item
{
    if (!item) {
        return nil;
    }

    @try {
        UIView *itemView = [item valueForKey:@"view"];
        return [itemView isKindOfClass:UIView.class] ? itemView : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

- (UIImageView *)pp_bestTabIconImageViewInView:(UIView *)view
{
    UIImageView *bestImageView = nil;
    CGFloat bestArea = 0.0;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UIImageView.class]) {
            CGFloat width = CGRectGetWidth(subview.bounds);
            CGFloat height = CGRectGetHeight(subview.bounds);
            CGFloat area = width * height;
            if (width >= 10.0 && height >= 10.0 &&
                width <= 48.0 && height <= 48.0 &&
                area > bestArea) {
                bestImageView = (UIImageView *)subview;
                bestArea = area;
            }
        }

        UIImageView *nestedImageView = [self pp_bestTabIconImageViewInView:subview];
        if (nestedImageView) {
            CGFloat nestedArea =
                CGRectGetWidth(nestedImageView.bounds) * CGRectGetHeight(nestedImageView.bounds);
            if (nestedArea > bestArea) {
                bestImageView = nestedImageView;
                bestArea = nestedArea;
            }
        }
    }
    return bestImageView;
}

- (void)pp_refreshProfileTabPresentation
{
    BOOL isGuest = [self pp_isGuestProfileTabState];
    if (isGuest) {
        [self pp_prepareGuestProfileAnimationIfNeeded];
    }

    UIImage *normalImage = [self pp_profileTabItemImageSelected:NO];
    UIImage *selectedImage = [self pp_profileTabItemImageSelected:YES];

    if (self.viewControllers.count > PPRootTabIndexOrders) {
        UITabBarItem *sourceItem = self.viewControllers[PPRootTabIndexOrders].tabBarItem;
        sourceItem.image = normalImage;
        sourceItem.selectedImage = selectedImage;
    }
    for (UITabBarItem *item in self.premiumTabItems) {
        if (item.tag == PPRootTabIndexOrders) {
            item.image = normalImage;
            item.selectedImage = selectedImage;
            break;
        }
    }

    if (!isGuest || !self.guestProfileLottieReady) {
        [self.guestProfileLottieView stop];
        self.guestProfileLottieView.hidden = YES;
        [self.guestProfileLottieView removeFromSuperview];
    }

    [self.tabBar setNeedsLayout];
    [self.premiumTabbarView setNeedsLayout];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_layoutGuestProfileAnimation];
        [self pp_updateGuestProfileAnimationPlayback];
    });
}

- (nullable UILabel *)pp_titleLabelInView:(UIView *)view matchingTitle:(NSString *)title
{
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if ([label.text isEqualToString:title]) {
            return label;
        }
    }

    for (UIView *subview in view.subviews) {
        UILabel *matchingLabel = [self pp_titleLabelInView:subview matchingTitle:title];
        if (matchingLabel) {
            return matchingLabel;
        }
    }
    return nil;
}

- (nullable UILabel *)pp_tabBarTitleLabelForItem:(UITabBarItem *)item
{
    if (item.title.length == 0) {
        return nil;
    }

    UIView *itemView = [self pp_viewForTabBarItem:item];
    if (!itemView || CGRectIsEmpty(itemView.bounds)) {
        return nil;
    }
    return [self pp_titleLabelInView:itemView matchingTitle:item.title];
}

- (void)pp_refreshLegacyTabBarTitleLayout
{
    if (!self.useLegacyBar || self.tabBar.hidden || CGRectGetWidth(self.tabBar.bounds) <= 0.0) {
        return;
    }

    for (UITabBarItem *item in self.tabBar.items) {
        UIView *itemView = [self pp_viewForTabBarItem:item];
        UILabel *titleLabel = [self pp_tabBarTitleLabelForItem:item];
        if (!itemView || !titleLabel || !titleLabel.superview) {
            continue;
        }

        // UITabBar may retain a narrower launch-time title frame even after
        // its item widths settle. Keep a small visual inset while making the
        // label span the resolved item width, centered for both RTL and LTR.
        CGFloat titleWidth = MAX(0.0, CGRectGetWidth(itemView.bounds) - 6.0);
        if (titleWidth <= 0.0) {
            continue;
        }

        CGRect titleFrameInItem = [itemView convertRect:titleLabel.frame
                                               fromView:titleLabel.superview];
        titleFrameInItem.origin.x = (CGRectGetWidth(itemView.bounds) - titleWidth) * 0.5;
        titleFrameInItem.size.width = titleWidth;
        CGRect resolvedTitleFrame = [titleLabel.superview convertRect:titleFrameInItem
                                                              fromView:itemView];

        titleLabel.numberOfLines = 1;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.78;
        titleLabel.allowsDefaultTighteningForTruncation = YES;
        titleLabel.frame = CGRectMake(CGRectGetMinX(resolvedTitleFrame),
                                      CGRectGetMinY(titleLabel.frame),
                                      CGRectGetWidth(resolvedTitleFrame),
                                      CGRectGetHeight(titleLabel.frame));
        titleLabel.preferredMaxLayoutWidth = titleWidth;
        [titleLabel setNeedsDisplay];
    }
}

- (void)pp_layoutGuestProfileAnimation
{
    LOTAnimationView *animationView = self.guestProfileLottieView;
    if (![self pp_isGuestProfileTabState] || !self.guestProfileLottieReady || !animationView) {
        return;
    }

    UITabBarItem *item = [self pp_guestProfileAnimationTabItem];
    UIView *itemView = [self pp_viewForTabBarItem:item];
    if (!itemView || CGRectIsEmpty(itemView.bounds)) {
        return;
    }
    [itemView layoutIfNeeded];

    UITabBar *displayedTabBar = !self.useLegacyBar ? self.premiumTabbarView : self.tabBar;
    UIView *animationHostView = displayedTabBar.superview ?: self.view;
    if (!displayedTabBar || !animationHostView) {
        return;
    }

    // Keep custom content outside UIKit's private UITabBarButton hierarchy.
    // UIKit changes that hierarchy's alpha/visibility during selection, which
    // caused the guest animation to disappear until the item was deselected.
    if (animationView.superview != animationHostView) {
        [animationView removeFromSuperview];
        [animationHostView addSubview:animationView];
    }
    if (displayedTabBar.superview == animationHostView) {
        [animationHostView insertSubview:animationView aboveSubview:displayedTabBar];
    } else {
        [animationHostView bringSubviewToFront:animationView];
    }

    UIImageView *iconImageView = [self pp_bestTabIconImageViewInView:itemView];
    CGPoint iconCenterInItem = CGPointMake(CGRectGetMidX(itemView.bounds),
                                           MIN(24.0, CGRectGetMidY(itemView.bounds)));
    CGPoint iconCenter = [animationHostView convertPoint:iconCenterInItem fromView:itemView];
    if (iconImageView && !CGRectIsEmpty(iconImageView.bounds)) {
        CGRect iconRect =
            [animationHostView convertRect:iconImageView.bounds fromView:iconImageView];
        iconCenter = CGPointMake(CGRectGetMidX(iconRect), CGRectGetMidY(iconRect));
    }

    BOOL selected = self.selectedIndex == PPRootTabIndexOrders;
    CGFloat animationSize = selected ? 34.0 : 32.0;
    animationView.bounds = CGRectMake(0.0, 0.0, animationSize, animationSize);
    animationView.center = iconCenter;
    animationView.layer.cornerRadius = animationSize * 0.5;
    animationView.layer.zPosition = 0.0;
    animationView.alpha = 1.0;
    animationView.layer.opacity = 1.0;
    animationView.transform = CGAffineTransformIdentity;
}

- (void)pp_updateGuestProfileAnimationPlayback
{
    LOTAnimationView *animationView = self.guestProfileLottieView;
    BOOL shouldShow =
        [self pp_isGuestProfileTabState] &&
        self.guestProfileLottieReady &&
        animationView.superview &&
        self.view.window &&
        !self.premiumBottomNavigationHidden;

    if (!shouldShow) {
        [animationView stop];
        animationView.hidden = YES;
        return;
    }

    animationView.hidden = NO;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [animationView stop];
        animationView.animationProgress = 0.42;
    } else if (!animationView.isAnimationPlaying) {
        [animationView play];
    }
}

- (void)pp_refreshGuestProfileAnimationAfterSelection
{
    [self pp_layoutGuestProfileAnimation];
    [self pp_updateGuestProfileAnimationPlayback];

    // UIKit may finish updating the selected tab item on the next run loop.
    // Reattach after that update so the custom Lottie never remains in an old
    // item view or underneath the selected icon presentation.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_layoutGuestProfileAnimation];
        [self pp_updateGuestProfileAnimationPlayback];
    });
}

- (void)pp_handleProfileAuthenticationChange:(__unused NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_refreshProfileTabPresentation];
    });
}

- (void)pp_handleReduceMotionStatusChange:(__unused NSNotification *)notification
{
    [self pp_updateGuestProfileAnimationPlayback];
}

- (void)pp_premiumDockDidSelectItem:(UITabBarItem *)item
{
    NSInteger index = item.tag;
    UIViewController *viewController = [self pp_viewControllerForRootTabIndex:index];
    if (!viewController) {
        [self pp_applyPremiumTabSelectionAnimated:NO];
        return;
    }
    if (![self tabBarController:self shouldSelectViewController:viewController]) {
        [self pp_applyPremiumTabSelectionAnimated:NO];
        return;
    }

    BOOL isChangingTabs = self.selectedIndex != (NSUInteger)index;
    if (!isChangingTabs) {
        // Same tab tapped: pop one level toward root on each tap
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)viewController;
            if (nav.viewControllers.count > 1) {
                [nav popViewControllerAnimated:YES];
            }
        }
        return;
    }

    [super setSelectedIndex:(NSUInteger)index];
    [self tabBarController:self didSelectViewController:viewController];
    [self pp_applyPremiumTabSelectionAnimated:YES];
    [self pp_refreshGuestProfileAnimationAfterSelection];
}

- (void)pp_applyPremiumTabSelectionAnimated:(BOOL)animated
{
    NSUInteger activeIndex =
        self.selectedIndex == PPRootTabIndexAdd ? self.pp_lastSelectedIndex : self.selectedIndex;
    UITabBarItem *selectedItem = nil;
    for (UITabBarItem *item in self.premiumTabItems) {
        if (item.tag == (NSInteger)activeIndex) {
            selectedItem = item;
            break;
        }
    }
    if (!selectedItem || self.premiumTabbarView.selectedItem == selectedItem) {
        return;
    }
    void (^updates)(void) = ^{
        self.premiumTabbarView.selectedItem = selectedItem;
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView transitionWithView:self.premiumTabbarView
                          duration:0.22
                           options:UIViewAnimationOptionTransitionCrossDissolve |
                                   UIViewAnimationOptionBeginFromCurrentState |
                                   UIViewAnimationOptionAllowUserInteraction
                        animations:updates
                        completion:^(__unused BOOL finished) {
            [self pp_refreshGuestProfileAnimationAfterSelection];
        }];
    } else {
        updates();
        [self pp_refreshGuestProfileAnimationAfterSelection];
    }
}

- (void)pp_animatePremiumBottomNavigationEntranceIfNeeded
{
    if (self.useLegacyBar) {
        return;
    }
    if (self.premiumNavigationDidAnimateIn) {
        return;
    }
    self.premiumNavigationDidAnimateIn = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.premiumTabbarView.transform = CGAffineTransformIdentity;
        self.leadingTabButton.alpha = 1.0;
        self.leadingTabButton.transform = CGAffineTransformIdentity;
        self.premiumNovaButton.alpha = self.premiumNovaVisibleByConfiguration ? 1.0 : 0.0;
        self.premiumNovaButton.transform = CGAffineTransformIdentity;
        [self pp_updatePremiumNovaButtonVisibility];
        return;
    }

    [UIView animateWithDuration:0.46
                          delay:0.03
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.premiumTabbarView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.40
                          delay:0.08
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.leadingTabButton.alpha = 1.0;
        self.leadingTabButton.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.42
                          delay:0.14
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.premiumNovaButton.alpha = self.premiumNovaVisibleByConfiguration ? 1.0 : 0.0;
        self.premiumNovaButton.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [self pp_updatePremiumNovaButtonVisibility];
    }];
}

- (void)pp_premiumControlTouchDown:(UIButton *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:nil];
}

- (void)pp_premiumControlTouchUp:(UIButton *)sender
{
    if (sender == self.leadingTabButton || sender == self.premiumNovaButton) {
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.20
                              delay:0.0
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.30
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            sender.transform = CGAffineTransformIdentity;
        } completion:nil];
        return;
    }
    [self pp_applyPremiumTabSelectionAnimated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)pp_updatePremiumChatsBadgeWithCount:(NSInteger)count
{
    UITabBarItem *chatsItem = nil;
    for (UITabBarItem *item in self.premiumTabItems) {
        if (item.tag == PPRootTabIndexChats) {
            chatsItem = item;
            break;
        }
    }
    if (!chatsItem) {
        return;
    }
    chatsItem.badgeValue =
        count > 0 ? (count > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count]) : nil;
    if (@available(iOS 10.0, *)) {
        chatsItem.badgeColor = AppPrimaryClr ?: UIColor.systemTealColor;
    }
}

- (void)pp_setPremiumBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (!self.useLegacyBar) {
        self.tabBar.hidden = YES;
        self.tabBar.alpha = 0.0;
        self.tabBar.userInteractionEnabled = NO;
    } else {
        if (!hidden) {
            self.tabBar.hidden = NO;
        }
        self.tabBar.userInteractionEnabled = !hidden;
    }
    self.premiumBottomNavigationHidden = hidden;
    [self pp_updateGuestProfileAnimationPlayback];
    NSMutableArray<UIView *> *navigationViews = [NSMutableArray arrayWithCapacity:4];
    if (!self.useLegacyBar && self.premiumTabbarView) {
        [navigationViews addObject:self.premiumTabbarView];
    }
    if (self.premiumBottomFadeView && !self.useLegacyBar) {
        [navigationViews addObject:self.premiumBottomFadeView];
    }
    if (self.leadingTabButton && !self.useLegacyBar) {
        [navigationViews addObject:self.leadingTabButton];
    }
    if (self.premiumNovaButton) {
        [navigationViews addObject:self.premiumNovaButton];
    }

    if (!hidden) {
        for (UIView *view in navigationViews) {
            view.hidden = NO;
        }
        [self pp_updatePremiumNovaButtonVisibility];
    }
    void (^changes)(void) = ^{
        BOOL showNova = self.premiumNovaVisibleByConfiguration && !hidden;
        if (!self.useLegacyBar) {
            self.tabBar.alpha = 0.0;
            self.premiumTabbarView.alpha = hidden ? 0.0 : 1.0;
            self.premiumBottomFadeView.alpha = hidden ? 0.0 : 1.0;
        } else {
            self.tabBar.alpha = hidden ? 0.0 : 1.0;
            self.premiumTabbarView.alpha = 0.0;
            self.premiumBottomFadeView.alpha = 0.0;
        }
        self.leadingTabButton.alpha = (!self.useLegacyBar && !hidden) ? 1.0 : 0.0;
        self.premiumNovaButton.alpha = showNova ? 1.0 : 0.0;
        if (!UIAccessibilityIsReduceMotionEnabled()) {
            self.premiumTabbarView.transform =
                hidden ? CGAffineTransformMakeTranslation(0.0, 10.0) : CGAffineTransformIdentity;
            self.tabBar.transform =
                (self.useLegacyBar && hidden) ? CGAffineTransformMakeTranslation(0.0, 10.0) : CGAffineTransformIdentity;
            self.leadingTabButton.transform =
                hidden ? CGAffineTransformMakeTranslation(0.0, 8.0) : CGAffineTransformIdentity;
            self.premiumNovaButton.transform =
                hidden ? CGAffineTransformMakeTranslation(0.0, 8.0) : CGAffineTransformIdentity;
        } else {
            self.premiumTabbarView.transform = CGAffineTransformIdentity;
            self.tabBar.transform = CGAffineTransformIdentity;
            self.leadingTabButton.transform = CGAffineTransformIdentity;
            self.premiumNovaButton.transform = CGAffineTransformIdentity;
        }
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        for (UIView *view in navigationViews) {
            view.hidden = hidden;
        }
        [self pp_updatePremiumNovaButtonVisibility];
        if (!self.useLegacyBar) {
            self.tabBar.hidden = YES;
            self.tabBar.alpha = 0.0;
            self.tabBar.transform = CGAffineTransformIdentity;
            self.tabBar.userInteractionEnabled = NO;
        } else {
            self.tabBar.hidden = hidden;
            if (!hidden) {
                self.tabBar.alpha = 1.0;
            }
            self.tabBar.transform = CGAffineTransformIdentity;
            self.tabBar.userInteractionEnabled = !hidden;
        }
        [self pp_applyBottomNavigationClearanceToVisibleLists];
        [self pp_layoutGuestProfileAnimation];
        [self pp_updateGuestProfileAnimationPlayback];
    };
    if (!animated) {
        changes();
        completion(YES);
        return;
    }
    if (hidden || UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:[PPBottomSurfaceCoordinator transitionOutDuration]
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                         animations:changes
                         completion:completion];
        return;
    }
    [UIView animateWithDuration:[PPBottomSurfaceCoordinator transitionInDuration]
                          delay:0.0
         usingSpringWithDamping:[PPBottomSurfaceCoordinator transitionInSpringDamping]
          initialSpringVelocity:[PPBottomSurfaceCoordinator transitionInSpringVelocity]
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseOut
                     animations:changes
                     completion:completion];
}

- (void)setPremiumTabDockViewHidden:(BOOL)hidden animation:(BOOL)animated
{
    [self pp_setPremiumBottomNavigationHidden:hidden animated:animated];
}

- (void)pp_activateFloatingCartBarForSourceViewController:(UIViewController *)viewController
                                          openCartHandler:(PPCartFloatingBarOpenHandler)openCartHandler
                                                 animated:(BOOL)animated
{
    [self.cartFloatingBarCoordinator activateForSourceViewController:viewController
                                                     openCartHandler:openCartHandler
                                                            animated:animated];
}

- (void)pp_deactivateFloatingCartBarForSourceViewController:(UIViewController *)viewController
                                                   animated:(BOOL)animated
{
    [self.cartFloatingBarCoordinator deactivateForSourceViewController:viewController animated:animated];
}

- (UIView *)pp_novaAmbientBottomNavigationAnchorView
{
    if (!self.useLegacyBar &&
        self.premiumTabbarView &&
        !self.premiumTabbarView.hidden &&
        self.premiumTabbarView.alpha > 0.01) {
        return self.premiumTabbarView;
    }

    if (!self.tabBar.hidden && self.tabBar.alpha > 0.01) {
        return self.tabBar;
    }

    return nil;
}

- (void)setpremiumTabbarViewHidden:(BOOL)hidden animation:(BOOL)animated
{
    [self setPremiumTabDockViewHidden:hidden animation:animated];
}

- (void)addPlusTabBarButton {

    

    UIButton *showAddMenuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    showAddMenuButton.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *symbolConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:19
                                                     weight:UIImageSymbolWeightSemibold
                                                      scale:UIImageSymbolScaleLarge];

    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIImage *icon = [[[UIImage systemImageNamed:@"plus" withConfiguration:symbolConfig] imageWithTintColor:accentColor]
                     imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration =
            [UIButtonConfiguration glassButtonConfiguration];
        configuration.image = icon;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.baseForegroundColor = accentColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(16.0, 16.0, 16.0, 16.0);
        configuration.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.00];
        configuration.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.00];
        showAddMenuButton.configuration = configuration;
        showAddMenuButton.tintColor = accentColor;
    } else {
        [showAddMenuButton setImage:icon forState:UIControlStateNormal];
        showAddMenuButton.backgroundColor =
            [UIColor.systemBackgroundColor colorWithAlphaComponent:0.92];
        showAddMenuButton.tintColor = accentColor;
        showAddMenuButton.layer.borderWidth = 0.5;
        [showAddMenuButton pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.10]];
    }
    showAddMenuButton.layer.cornerRadius = 28.0;
    PPApplyContinuousCorners(showAddMenuButton, 28.0);
    [showAddMenuButton pp_setShadowColor:UIColor.blackColor];
    showAddMenuButton.layer.shadowOpacity = 0.04;
    showAddMenuButton.layer.shadowRadius = 8.0;
    showAddMenuButton.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    showAddMenuButton.layer.masksToBounds = NO;

    [showAddMenuButton addTarget:self action:@selector(presentBottomSheet) forControlEvents:UIControlEventTouchUpInside];
    [showAddMenuButton addTarget:self action:@selector(pp_premiumControlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [showAddMenuButton addTarget:self action:@selector(pp_premiumControlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    // ── Accessibility: Add new post button ──
    showAddMenuButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_add_new", @"Add new post");
    showAddMenuButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_add_new_hint", @"Create a new pet ad, accessory listing, or adoption post");
    showAddMenuButton.accessibilityTraits = UIAccessibilityTraitButton;

    [self.view addSubview:showAddMenuButton];
    self.leadingTabButton = showAddMenuButton;

    if (self.useLegacyBar) {
        showAddMenuButton.hidden = YES;
    }

    if (@available(iOS 26.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [showAddMenuButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
            [showAddMenuButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-2.0],
            [showAddMenuButton.widthAnchor constraintEqualToConstant:52.0],
            [showAddMenuButton.heightAnchor constraintEqualToConstant:52.0]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [showAddMenuButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [showAddMenuButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:2.0],
            [showAddMenuButton.widthAnchor constraintEqualToConstant:58.0],
            [showAddMenuButton.heightAnchor constraintEqualToConstant:58.0]
        ]];
        [self pp_raiseBelowIOS26AddButtonAboveSystemTabBar];
    }
}



- (void)addNovaTabBarButton {

    

    UIButton *NovaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    NovaButton.translatesAutoresizingMaskIntoConstraints = NO;
    NovaButton.adjustsImageWhenHighlighted = NO;
 

    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIImage *icon = [UIImage imageNamed:@"letter-n"]  ;
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration =
            [UIButtonConfiguration glassButtonConfiguration];
        configuration.image = icon;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.baseForegroundColor = accentColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(16.0, 16.0, 16.0, 16.0);
        configuration.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.00];
        configuration.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.00];
        NovaButton.configuration = configuration;
        NovaButton.tintColor = accentColor;
    } else {
        [NovaButton setImage:icon forState:UIControlStateNormal];
        NovaButton.backgroundColor =
            [UIColor.systemBackgroundColor colorWithAlphaComponent:0.92];
        NovaButton.tintColor = accentColor;
        NovaButton.layer.borderWidth = 0.5;
        [NovaButton pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.10]];
    }
    NovaButton.layer.cornerRadius = 28.0;
    PPApplyContinuousCorners(NovaButton, 28.0);
    [NovaButton pp_setShadowColor:UIColor.blackColor];
    NovaButton.layer.shadowOpacity = 0.06;
    NovaButton.layer.shadowRadius = 16.0;
    NovaButton.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    NovaButton.layer.masksToBounds = NO;

    [NovaButton addTarget:self action:@selector(presentBottomSheet) forControlEvents:UIControlEventTouchUpInside];
    [NovaButton addTarget:self action:@selector(pp_premiumControlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [NovaButton addTarget:self action:@selector(pp_premiumControlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    // ── Accessibility: Add new post button ──
    NovaButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_add_new", @"show ai assistant");
    NovaButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_add_new_hint", @"show ai assistant");
    NovaButton.accessibilityTraits = UIAccessibilityTraitButton;

    [self.view addSubview:NovaButton];
    self.trailingTabButton = NovaButton;

    if (@available(iOS 26.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [NovaButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
            [NovaButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:10.0],
            [NovaButton.widthAnchor constraintEqualToConstant:58.0],
            [NovaButton.heightAnchor constraintEqualToConstant:58.0]
        ]];
        // Symbol effect (iOS 26+ only)
        __weak UIButton *weakButton = NovaButton;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakButton.imageView addSymbolEffect:[[NSSymbolWiggleEffect wiggleForwardEffect] effectWithByLayer]
                                         options:[NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:3.0]]];
        });
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [NovaButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [NovaButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:2.0],
            [NovaButton.widthAnchor constraintEqualToConstant:58.0],
            [NovaButton.heightAnchor constraintEqualToConstant:58.0]
        ]];
        [self pp_raiseBelowIOS26AddButtonAboveSystemTabBar];
    }
}

- (void)pp_raiseBelowIOS26AddButtonAboveSystemTabBar
{
    if (!self.useLegacyBar || !self.leadingTabButton) {
        return;
    }

    self.leadingTabButton.hidden = self.premiumBottomNavigationHidden;
    self.leadingTabButton.layer.zPosition = 1000.0;
    self.leadingTabButton.layer.masksToBounds = NO;
    [self.view bringSubviewToFront:self.leadingTabButton];
    
     self.trailingTabButton.layer.zPosition = 1001.0;
    self.trailingTabButton.layer.masksToBounds = NO;
    [self.view bringSubviewToFront:self.trailingTabButton];
    
    
}

- (void)leadingTabTapped {
    // Example: open profile
   
}



- (NSString *)pp_addActionPickerBadgeTextForCount:(NSUInteger)count
{
    NSString *format =
        count == 1 ? kLang(@"create_picker_count_single") : kLang(@"create_picker_count_format");
    if (count == 1 && ![format containsString:@"%"]) {
        return format;
    }
    return [NSString stringWithFormat:format, (long)count];
}

- (NSArray<OptionModel *> *)pp_addActionPickerOptions
{
    OptionModel *newAd =
        [OptionModel optionWithID:@"newAd"
                            title:kLang(@"newAd")
                        imageName:nil
                      systemImage:@"pawprint.fill"
                             desc:kLang(@"newAd_desc")];
    newAd.sortOrder = 0;

    OptionModel *addUsed =
        [OptionModel optionWithID:@"addUsedButton"
                            title:kLang(@"addUsedButton")
                        imageName:nil
                      systemImage:@"tag.fill"
                             desc:kLang(@"addUsedButton_desc")];
    addUsed.sortOrder = 1;

    OptionModel *adopt =
        [OptionModel optionWithID:@"addPetForAdoption"
                            title:kLang(@"addPetForAdoption")
                        imageName:nil
                      systemImage:@"heart.circle.fill"
                             desc:kLang(@"addPetForAdoption_desc")];
    adopt.sortOrder = 2;

    NSMutableArray<OptionModel *> *options = [NSMutableArray arrayWithObject:newAd];
    if (PPAllwedUsedAccessoriesEnabled()) {
        [options addObject:addUsed];
    }
    [options addObject:adopt];
    return options.copy;
}

- (void)presentBottomSheet {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [feedback impactOccurred];
    }
    
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return;
    }
    NSArray<OptionModel *> *options = [self pp_addActionPickerOptions];

    PPSelectOptionViewController *vc =
    [[PPSelectOptionViewController alloc] initWithOptions:options
                                                   title:@""
                                                     row:nil
                                        presentationStyle:PPSelectOptionPresentationMain
                                               completion:^(id selectedObj) {

        OptionModel *op = (OptionModel *)selectedObj;

        if ([op.optID isEqualToString:@"newAd"]) {
            [self openNewAdEditor];
        }
        else if ([op.optID isEqualToString:@"addUsedButton"]) {
            [self openAddUsedAccessory];
        }
        else if ([op.optID isEqualToString:@"addPetForAdoption"]) {
            [self openAdoptionEditor];
        }
    }];
    vc.usesCompactOptionIcons = YES;
    vc.usesCompactPremiumHero = NO;
    vc.preferredMainDetentHeight = 520.0;
    vc.premiumHeroAccentColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    [vc configurePremiumHeroWithEyebrow:kLang(@"create_picker_eyebrow")
                                  title:kLang(@"create_picker_title")
                               subtitle:kLang(@"create_picker_subtitle")
                             symbolName:@"plus.app.fill"
                              badgeText:[self pp_addActionPickerBadgeTextForCount:options.count]];
    
    [PPFunc presentFloatingSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle35];

    //[PPHomeHelper presentViewControllerSafely:vc
                                         //from:self
                                     //animated:YES
                                  // completion:nil];
}



- (void)openNewAdEditor {
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return;
    }
    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermPostAds, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add ads.")];
        return;
    }
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    AddNewAd *vc = [AddNewAd new];
    vc.mode = AdEditorModeCreate;
    vc.FromVC = @"AppVC";
    vc.pp_transitionStyle = PPTransitionStyleNone;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}


- (void)openAddUsedAccessory {
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Account blocked")
                          subtitle:kLang(@"Your account is blocked. You can't add accessories right now.")];
        return;
    }

    if (!PPAllwedUsedAccessoriesEnabled()) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"used_accessories_disabled_title")
                            subtitle:kLang(@"used_accessories_disabled_message")
                          completion:nil];
        return;
    }

    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermSellUsed, kPermManageStore, kPermPostAds, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add used accessories.")];
        return;
    }

    AddNewAccessory *vc = [AddNewAccessory  new];
    vc.FromVC = @"AppVC";
    vc.accessKindType = AccessTypeAccessory;
    vc.pp_transitionStyle = PPTransitionStyleNone;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openAdoptionEditor {
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return;
    }
    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermAdoption, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add adoption posts.")];
        return;
    }
    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] init];
    vc.modalInPresentation = NO;
    vc.pp_transitionStyle = PPTransitionStyleNone;

    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (BOOL)pp_currentUserHasAnyPermissionInKeys:(NSArray<NSString *> *)permissionKeys {
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (!currentUser) {
        return NO;
    }
    return [currentUser hasAnyPermissionInKeys:permissionKeys];
}




- (BOOL)tabBarController:(UITabBarController *)tabBarController
shouldSelectViewController:(UIViewController *)viewController {

    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return NO;
    }

    NSUInteger index =
    [tabBarController.viewControllers indexOfObject:viewController];
    if (index == NSNotFound) {
        return NO;
    }

    if (index == PPRootTabIndexChats) { // Chats tab
        if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return NO; }
    }
    if (index == PPRootTabIndexAdd) { // Add tab index
        [self presentBottomSheet];
        return NO;
    }

    return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController
   didSelectViewController:(UIViewController *)viewController
{
    NSUInteger index = [tabBarController.viewControllers indexOfObject:viewController];
    if (index == NSNotFound) {
        return;
    }
    if ((NSInteger)index != self.pp_lastSelectedIndex) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventRootTabSelected];
    }
    self.pp_lastSelectedIndex = (NSInteger)index;
    [self.cartFloatingBarCoordinator refreshForCurrentVisibleControllerAnimated:YES];
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:viewController animated:YES];
    [self pp_refreshGuestProfileAnimationAfterSelection];
}


#pragma mark - Search Tab Apple-style Focus

- (void)activateSearchIfNeeded
{
    [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:NO];
}

@end












/*
 
 
 - (UIButton *)createCategoriesBackground
 {
     UIButton *bgButton;
     if (@available(iOS 26.0, *)) {
         // 🧊 iOS 26+ system glass button
         UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
         
         cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
         cfg.background.backgroundColor = UIColor.clearColor;
         cfg.baseBackgroundColor = UIColor.clearColor;
         cfg.background.cornerRadius = 0;

         
         bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
         bgButton.configuration = cfg;
         bgButton.alpha = 0.75;
       } else {
          
  
         // 🌫️ Fallback for iOS <26
         bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
         bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
         bgButton.layer.cornerRadius = 16;
         bgButton.layer.masksToBounds = YES;
         [bgButton pp_setShadowColor:AppShadowClr];
         bgButton.layer.shadowOpacity = 0.15;
         bgButton.layer.shadowRadius = 8;
         bgButton.layer.shadowOffset = CGSizeMake(0, 4);
     }

     bgButton.translatesAutoresizingMaskIntoConstraints = NO;
     return bgButton;
 }
 
 - (void)setupBottomBar {
     
     self.emptyCard = [self createCategoriesBackground];
     self.emptyCard.translatesAutoresizingMaskIntoConstraints = NO;
     [self.view addSubview:self.emptyCard];

    
     self.emptyCard.alpha = 1;
     self.emptyCard.backgroundColor = UIColor.clearColor;

     self.bottomBar = [[PPNewBottomBar alloc] init];
     self.bottomBar.barBackStyle = BarBackStyleClear;
  
     
     if(!self.useLegacyBar)
     {
         [self.bottomBar configureTabBarItems:@[
             @{@"tag":@(PPBarTagHome),@"icon"Cus", @"title":kLang(@"MainPage")}, //homeCus
             @{@"tag":@(PPBarTagChats), @"icon":@"notificationCus",  @"title":kLang(@"Notifications")} ,
             @{@"tag":@(PPBarTagOrdersHistory), @"icon":@"ordersCus",  @"title": kLang(@"Orders")},
         ]];
     }
     else
     {
         [self.bottomBar configureWithItems:@[
             @{@"tag":@(PPBarTagHome),@"icon":@"PPhouseCus", @"title":kLang(@"home")},
             @{@"tag":@(PPBarTagChats), @"icon":@"bell",  @"title":kLang(@"Notifications")} ,
             @{@"tag":@(PPBarTagOrdersHistory), @"icon":@"clock", @"title": kLang(@"Orders")},
     ]];
     }

     __weak typeof(self) weakSelf = self;

     self.bottomBar.onTabBarTapped =
     ^(PPBarTag barTag, UIBarItem *barItem) {

         [weakSelf handleBarSelection:barTag];
     };

     self.bottomBar.onButtonTapped =
     ^(NSInteger index, UIButton *button) {

        // [weakSelf handleActionButton:index];
     };

     self.bottomBar.onSearchTapped = ^{
        // [weakSelf openSearch];
     };

     [self.view addSubview:self.bottomBar];

     [NSLayoutConstraint activateConstraints:@[
         [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
         [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
         [self.bottomBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:10],
         [self.bottomBar.heightAnchor constraintEqualToConstant:64]
     ]];
     
     
     [NSLayoutConstraint activateConstraints:@[
         [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0],
         [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-0],
         [self.emptyCard.topAnchor constraintEqualToAnchor:self.bottomBar.topAnchor constant:-12],
         [self.emptyCard.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
     ]];
     
     
     [self.bottomBar selectItemWithTag:PPBarTagHome animated:YES];
 }

 #pragma mark - Bottom Fade Shadow

 - (void)addBottomFadeBelowTabBar {
     return;
     if (self.bottomFadeLayer) return;

     CAGradientLayer *fade = [CAGradientLayer layer];
     fade.colors = @[
         
         (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
         (__bridge id)[AppForgroundColr colorWithAlphaComponent:0.5].CGColor
     ];

     fade.startPoint = CGPointMake(0.5, 0.0);
     fade.endPoint   = CGPointMake(0.5, 1.0);

     fade.locations = @[@0.0, @1.0];

     [self.view.layer addSublayer:fade  ];

     self.bottomFadeLayer = fade;
 }

 */

/*
 MainController Tab Bar Architecture

 - System tab bar is owned by PPRootTabBarController
 - MainController overlays a custom cards tab bar
 - Overlay is attached ONLY while MainController is visible
 - System tab bar is never removed, only visually replaced

 This follows Apple best practices (2026).
 */
