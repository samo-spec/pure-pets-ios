#import "PPDataViewVC.h"
#import "PPDataViewInput.h"
#import "PPDataViewVM.h"
#import "PPFilterModels.h"
#import <Pure_Pets-Swift.h>

#import "PPUniversalCell.h"
#import "PPCollectionLayoutManager.h"
#import "PPImageLoaderManager.h"
#import "BBDataViewFullDetailsCell.h"
#import "BBDataViewFullDetailsLayout.h"
#import "PPFilterSheetVC.h"
#import "PPAdSharingHelper.h"
#import "PPAnalytics.h"
#import "CartManager.h"
#import "UIViewController+PPBottomSurface.h"
#import "CartViewController.h"
#import "PPRootTabBarController.h"
#import "PPModrenSegmrnted.h"
#import "PPNavigationController.h"
#import "ChManager.h"
#import "PPOverlayCoordinator.h"
#import "PPSearchViewController.h"
#import "PPHUD.h"
#import "UIView+Badge.h"
#import "PPBackgroundView.h"
#import "PPSelectOptionViewController.h"
#import "OptionModel.h"
#import "UserManager.h"
#import "UserModel.h"
#import "PPModernAvatarRenderer.h"
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <QuartzCore/QuartzCore.h>
#import <SDWebImage/SDWebImagePrefetcher.h>
#import <os/signpost.h>
#import <math.h>

#if DEBUG
#define PPDataViewLog(...) NSLog(__VA_ARGS__)
#else
#define PPDataViewLog(...)
#endif

static const CGFloat kPPSectionsTabBarHeight = 48.0;
static const CGFloat kPPAccessoryFilterHeight = 44.0;
static const CGFloat kPPDropdownFilterChipHeight = 40.0;
static const CGFloat kPPProviderFilterChipHeight = 44.0;
static const CGFloat kPPProviderFilterChipAvatarDiameter = 30.0;
static const CGFloat kPPProviderFilterChipTrailingIconDiameter = 26.0;
static const CGFloat kPPFilterContextBarHeight = 44.0;
static const CGFloat kPPFilterContextBadgeHeight = 28.0;
static const CGFloat kPPFilterCollapseHandleHeight = 44.0;

static const CGFloat kPPFilterIslandTopPadding = 5.0;
static const CGFloat kPPFilterIslandRowSpacing = 6.0;
static const CGFloat kPPFilterIslandExpandedRowSpacing = 6.0;
static const CGFloat kPPFilterIslandBottomPadding = 10.0;
static const BOOL kPPDataViewPauseLegacyFilterIslandScrollCollapse = YES;
static const NSInteger kPPPremiumVisibleCellAnimationLimit = 12;
static const CGFloat kPPPremiumCellBaseEntranceYOffset = 18.0;
static const CGFloat kPPPremiumCellSectionEntranceXOffset = 18.0;
static const CGFloat kPPAdsPinterestMaximumHeightToWidthRatio = 2.15;
static const CGFloat kPPAdsPinterestMaximumViewportFraction = 0.68;
static const CGFloat kPPAdsPinterestMinimumContentAllowance = 164.0;
static const CGFloat kPPDataViewNavigationChromeCornerRadius = 18.0;
static const CGFloat kPPDataViewSectionsIslandCornerRadius = 22.0;
static const CGFloat kPPDataViewSelectorCornerRadius = 18.0;
static const CGFloat kPPDataViewSectionsSegmentedCornerRadius = 22.0;
static const CGFloat kPPDataViewHeaderCollapseDistance = 176.0;
static const CGFloat kPPDataViewHeaderCollapsedYOffset = -24.0;
static const CGFloat kPPDataViewHeaderCollapsedScaleX = 0.984;
static const CGFloat kPPDataViewHeaderCollapsedScaleY = 0.875;
static const CGFloat kPPDataViewCollectionChromeFallbackTopInset = 84.0;
static const CGFloat kPPDataViewCollectionChromeBreathingGap = 16.0;
static const CGFloat kPPDataViewHeaderDockStartProgress = 0.08;
static const CGFloat kPPDataViewHeaderDockTargetHorizontalInset = 5.0;
static const CGFloat kPPDataViewHeaderDockTargetVerticalInset = 3.0;
static const CGFloat kPPDataViewHeaderDockMinimumScale = 0.30;
static const CGFloat kPPDataViewHeaderDockMaximumScale = 0.72;
static const CGFloat kPPDataViewHeaderDockSnapshotStartProgress = 0.72;
static const CGFloat kPPDataViewHeaderDockedProgressThreshold = 0.985;
static const CGFloat kPPDataViewHeaderUndockedProgressThreshold = 0.72;
static const CGFloat kPPDataViewHeaderTitleUndockScaleDip = 0.026;

static NSString * const PPDataViewProviderIdentityTitleKey = @"title";
static NSString * const PPDataViewProviderIdentityPhotoURLKey = @"photoURL";

static os_log_t PPDataViewVCPerformanceLog(void)
{
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.purepets", "DataView");
    });
    return log;
}

static NSString *PPDataViewTrimmedString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    }
    if ([value isKindOfClass:NSURL.class]) {
        return [[(NSURL *)value absoluteString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    }
    return @"";
}

typedef NS_ENUM(NSInteger, PPDataViewMotionReason) {
    PPDataViewMotionReasonNone = 0,
    PPDataViewMotionReasonInitialLoad,
    PPDataViewMotionReasonSectionChange,
    PPDataViewMotionReasonSubKindChange,
    PPDataViewMotionReasonMainKindChange
};

static CGFloat PPCurrentSectionsTabBarHeight(void)
{
    return kPPSectionsTabBarHeight;
}

static CGFloat PPDataViewPillRadiusForHeight(CGFloat height, CGFloat fallback)
{
    if (!isfinite((double)height) || height <= 0.0) {
        return fallback;
    }
    return floor(height * 0.5);
}

static CGFloat PPDataViewClamp01(CGFloat value)
{
    if (!isfinite((double)value)) {
        return 0.0;
    }
    return MIN(MAX(value, 0.0), 1.0);
}

static CGFloat PPDataViewSmoothstep(CGFloat value)
{
    CGFloat t = PPDataViewClamp01(value);
    return t * t * (3.0 - (2.0 * t));
}

static NSArray<NSNumber *> *PPDataViewSectionPresentationOrder(void)
{
    static NSArray<NSNumber *> *order;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        order = @[
            @(PPDataSectionAds),
            @(PPDataSectionAccessories),
            @(PPDataSectionFood),
            @(PPDataSectionServices)
        ];
    });
    return order;
}

static UIColor *PPDataViewDynamicColor(UIColor *light, UIColor *dark)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
        }];
    }
    return light;
}

static UIColor *PPDataViewChromeSurfaceColor(void)
{
    return PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.78],
                                  [UIColor colorWithWhite:0.10 alpha:0.76]);
}

static UIColor *PPDataViewChromeElevatedSurfaceColor(void)
{
    return PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.92],
                                  [UIColor colorWithWhite:1.0 alpha:0.105]);
}

static UIColor *PPDataViewChromeStrokeColor(void)
{
    return PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.86],
                                  [UIColor colorWithWhite:1.0 alpha:0.13]);
}

static UIColor *PPDataViewChromeTextColor(void)
{
    return PPDataViewDynamicColor([UIColor colorWithRed:0.10 green:0.11 blue:0.14 alpha:1.0],
                                  [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *PPDataViewChromeSecondaryTextColor(void)
{
    return PPDataViewDynamicColor([UIColor colorWithRed:0.42 green:0.43 blue:0.49 alpha:1.0],
                                  [UIColor colorWithWhite:0.78 alpha:1.0]);
}

static UIColor *PPDataViewChromeShadowColor(void)
{
    return PPDataViewDynamicColor([UIColor colorWithRed:0.12 green:0.10 blue:0.14 alpha:1.0],
                                  [UIColor colorWithRed:0.00 green:0.00 blue:0.00 alpha:1.0]);
}

static UIColor *PPDataViewAccentColor(void)
{
    return AppPrimaryClr ?: [GM appPrimaryColor] ?: UIColor.systemPinkColor;
}

static UIImage *PPDataViewFilterIconImage(NSString *iconName, UIImageSymbolConfiguration *symbolConfiguration, UIColor *tintColor)
{
    NSString *trimmedIconName = [iconName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedIconName.length == 0) {
        return nil;
    }

    UIImage *image = [UIImage imageNamed:trimmedIconName];
    if (!image) {
        image = [UIImage systemImageNamed:trimmedIconName withConfiguration:symbolConfiguration];
    }
    if (!image) {
        return nil;
    }

    if (tintColor) {
        return [image imageWithTintColor:tintColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIColor *PPDataViewAppForegroundSurfaceColor(void)
{
    return AppForgroundColr ?: PPDataViewChromeElevatedSurfaceColor();
}

static id PPDataViewResolvedLayerColor(UIColor *color, UITraitCollection *traitCollection)
{
    UIColor *resolvedColor = color ?: UIColor.clearColor;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [resolvedColor resolvedColorWithTraitCollection:traitCollection];
    }
    return (__bridge id)resolvedColor.CGColor;
}

static UIColor *PPDataViewResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    UIColor *resolvedColor = color ?: UIColor.clearColor;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [resolvedColor resolvedColorWithTraitCollection:traitCollection];
    }
    return resolvedColor;
}

static UIColor *PPDataViewBlendColor(UIColor *baseColor,
                                     UIColor *overlayColor,
                                     CGFloat amount,
                                     UITraitCollection *traitCollection)
{
    UIColor *base = PPDataViewResolvedColor(baseColor, traitCollection);
    UIColor *overlay = PPDataViewResolvedColor(overlayColor, traitCollection);

    CGFloat baseRed = 0.0, baseGreen = 0.0, baseBlue = 0.0, baseAlpha = 0.0;
    CGFloat overlayRed = 0.0, overlayGreen = 0.0, overlayBlue = 0.0, overlayAlpha = 0.0;
    if (![base getRed:&baseRed green:&baseGreen blue:&baseBlue alpha:&baseAlpha] ||
        ![overlay getRed:&overlayRed green:&overlayGreen blue:&overlayBlue alpha:&overlayAlpha]) {
        return baseColor ?: overlayColor ?: UIColor.clearColor;
    }

    CGFloat t = MIN(MAX(amount, 0.0), 1.0);
    return [UIColor colorWithRed:(baseRed * (1.0 - t)) + (overlayRed * t)
                           green:(baseGreen * (1.0 - t)) + (overlayGreen * t)
                            blue:(baseBlue * (1.0 - t)) + (overlayBlue * t)
                           alpha:(baseAlpha * (1.0 - t)) + (overlayAlpha * t)];
}

static UIColor *PPDataViewProviderPillAccentColor(UITraitCollection *traitCollection)
{
    UIColor *brand = PPDataViewAccentColor();
    UIColor *warmProviderAccent =
        PPDataViewDynamicColor([UIColor colorWithRed:0.996 green:0.655 blue:0.404 alpha:1.0],
                               [UIColor colorWithRed:0.996 green:0.765 blue:0.518 alpha:1.0]);
    return PPDataViewBlendColor(brand, warmProviderAccent, 0.06, traitCollection);
}

static UIUserInterfaceStyle PPDataViewCurrentAppInterfaceStyle(UITraitCollection *traitCollection)
{
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle savedStyle = [[PPThemeManager sharedManager] loadUserInterfaceStyle];
        if (savedStyle == UIUserInterfaceStyleDark || savedStyle == UIUserInterfaceStyleLight) {
            return savedStyle;
        }

        UIUserInterfaceStyle resolvedStyle = traitCollection.userInterfaceStyle;
        if (resolvedStyle == UIUserInterfaceStyleDark) {
            return UIUserInterfaceStyleDark;
        }
    }

    return UIUserInterfaceStyleLight;
}

static BOOL PPDataViewCurrentAppAppearanceIsDark(UITraitCollection *traitCollection)
{
    return PPDataViewCurrentAppInterfaceStyle(traitCollection) == UIUserInterfaceStyleDark;
}

@interface PPDataViewNavigationMaterialView : UIView
- (void)pp_applyPremiumMaterialAnimated:(BOOL)animated;
- (void)pp_applyDockedForegroundProgress:(CGFloat)progress animated:(BOOL)animated;
@end

@interface PPDataViewNavigationMaterialView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *liquidBorderLayer;
@property (nonatomic, strong) CAShapeLayer *liquidBorderMaskLayer;
@property (nonatomic, strong) CAGradientLayer *liquidShineLayer;
@property (nonatomic, strong) CAShapeLayer *liquidShineMaskLayer;
@property (nonatomic, assign) CGFloat dockedForegroundProgress;
@end

@implementation PPDataViewNavigationMaterialView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.userInteractionEnabled = NO;
    self.blurView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.blurView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:self.blurView];

    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.surfaceGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    self.surfaceGradientLayer.masksToBounds = YES;
    [self.layer insertSublayer:self.surfaceGradientLayer above:self.blurView.layer];

    self.liquidBorderLayer = [CAGradientLayer layer];
    self.liquidBorderLayer.startPoint = CGPointMake(0.0, 0.5);
    self.liquidBorderLayer.endPoint = CGPointMake(1.0, 0.5);
    self.liquidBorderMaskLayer = [CAShapeLayer layer];
    self.liquidBorderMaskLayer.fillColor = UIColor.clearColor.CGColor;
    self.liquidBorderMaskLayer.strokeColor = UIColor.blackColor.CGColor;
    self.liquidBorderMaskLayer.lineCap = kCALineCapRound;
    self.liquidBorderMaskLayer.lineJoin = kCALineJoinRound;
    self.liquidBorderLayer.mask = self.liquidBorderMaskLayer;
    [self.layer addSublayer:self.liquidBorderLayer];

    self.liquidShineLayer = [CAGradientLayer layer];
    self.liquidShineLayer.startPoint = CGPointMake(0.0, 0.5);
    self.liquidShineLayer.endPoint = CGPointMake(1.0, 0.5);
    self.liquidShineMaskLayer = [CAShapeLayer layer];
    self.liquidShineMaskLayer.fillColor = UIColor.clearColor.CGColor;
    self.liquidShineMaskLayer.strokeColor = UIColor.blackColor.CGColor;
    self.liquidShineMaskLayer.lineCap = kCALineCapRound;
    self.liquidShineMaskLayer.lineJoin = kCALineJoinRound;
    self.liquidShineLayer.mask = self.liquidShineMaskLayer;
    [self.layer addSublayer:self.liquidShineLayer];

    [self pp_applyPremiumMaterialAnimated:NO];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat radius = PPDataViewPillRadiusForHeight(CGRectGetHeight(self.bounds),
                                                   kPPDataViewNavigationChromeCornerRadius);
    self.layer.cornerRadius = radius;
    self.blurView.layer.cornerRadius = radius;

    self.surfaceGradientLayer.frame = self.bounds;
    self.surfaceGradientLayer.cornerRadius = radius;
    self.liquidBorderLayer.frame = self.bounds;
    self.liquidShineLayer.frame = self.bounds;

    CGRect strokeRect = CGRectInset(self.bounds, 0.5, 0.5);
    CGFloat strokeRadius = MAX(radius - 0.5, 0.0);
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect
                                                          cornerRadius:strokeRadius];
    self.liquidBorderMaskLayer.frame = self.bounds;
    self.liquidBorderMaskLayer.path = strokePath.CGPath;
    self.liquidBorderMaskLayer.lineWidth = 0.45;

    CGRect shineRect = CGRectInset(self.bounds, 0.5, 0.5);
    CGFloat shineRadius = MAX(radius - 0.5, 0.0);
    UIBezierPath *shinePath = [UIBezierPath bezierPathWithRoundedRect:shineRect
                                                         cornerRadius:shineRadius];
    self.liquidShineMaskLayer.frame = self.bounds;
    self.liquidShineMaskLayer.path = shinePath.CGPath;
    self.liquidShineMaskLayer.lineWidth = 0.5;

    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:radius].CGPath;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self pp_updateLiquidMotion];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyPremiumMaterialAnimated:NO];
    [self pp_updateLiquidMotion];
}

- (void)pp_applyPremiumMaterialAnimated:(BOOL)animated
{
    BOOL isDark = PPDataViewCurrentAppAppearanceIsDark(self.traitCollection);
    CGFloat dockedProgress = PPDataViewSmoothstep(self.dockedForegroundProgress);

    UIColor *foregroundSurface = PPDataViewAppForegroundSurfaceColor();
    UIColor *surface = PPDataViewChromeSurfaceColor();
    UIColor *softHighlight = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.72],
                                                    [UIColor colorWithWhite:1.0 alpha:0.18]);
    UIColor *surfaceTop = [foregroundSurface colorWithAlphaComponent:isDark ? 0.24 : 0.58];
    UIColor *surfaceMid = [surface colorWithAlphaComponent:isDark ? 0.76 : 0.82];
    UIColor *surfaceBottom = [AppBackgroundClrLigter colorWithAlphaComponent:isDark ? 0.18 : 0.12];
    UIColor *borderLead = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.88],
                                                 [UIColor colorWithWhite:1.0 alpha:0.54]);
    UIColor *borderMid = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.58],
                                                [UIColor colorWithWhite:1.0 alpha:0.34]);
    UIColor *borderAccent = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.74],
                                                   [UIColor colorWithWhite:1.0 alpha:0.42]);

    void (^updates)(void) = ^{
        self.blurView.hidden = NO;
        CGFloat baseBlurAlpha = isDark ? 0.54 : 0.72;
        self.blurView.alpha = baseBlurAlpha * (1.0 - (0.90 * dockedProgress));
        self.backgroundColor = [foregroundSurface colorWithAlphaComponent:dockedProgress];

        self.surfaceGradientLayer.colors = @[
            PPDataViewResolvedLayerColor(surfaceTop, self.traitCollection),
            PPDataViewResolvedLayerColor(surfaceMid, self.traitCollection),
            PPDataViewResolvedLayerColor(surfaceBottom, self.traitCollection)
        ];
        self.surfaceGradientLayer.locations = @[@0.0, @0.48, @1.0];
        CGFloat baseSurfaceOpacity = isDark ? 0.76 : 0.68;
        self.surfaceGradientLayer.opacity = baseSurfaceOpacity * (1.0 - (0.90 * dockedProgress));

        self.liquidBorderLayer.colors = @[
            PPDataViewResolvedLayerColor(borderLead, self.traitCollection),
            PPDataViewResolvedLayerColor(borderMid, self.traitCollection),
            PPDataViewResolvedLayerColor(borderAccent, self.traitCollection),
            PPDataViewResolvedLayerColor(borderLead, self.traitCollection)
        ];
        self.liquidBorderLayer.locations = @[@0.0, @0.34, @0.68, @1.0];
        CGFloat baseBorderOpacity = isDark ? 0.92 : 0.90;
        self.liquidBorderLayer.opacity = baseBorderOpacity * (1.0 - (0.24 * dockedProgress));

        self.liquidShineLayer.colors = @[
            PPDataViewResolvedLayerColor([UIColor clearColor], self.traitCollection),
            PPDataViewResolvedLayerColor(softHighlight, self.traitCollection),
            PPDataViewResolvedLayerColor([UIColor clearColor], self.traitCollection)
        ];
        self.liquidShineLayer.locations = @[@0.08, @0.18, @0.30];
        CGFloat baseShineOpacity = isDark ? 0.34 : 0.38;
        self.liquidShineLayer.opacity = baseShineOpacity * (1.0 - (0.58 * dockedProgress));

        UIColor *shadowColor = PPDataViewChromeShadowColor();
        if (@available(iOS 13.0, *)) {
            shadowColor = [shadowColor resolvedColorWithTraitCollection:self.traitCollection];
        }
        self.layer.shadowColor = shadowColor.CGColor;
        self.layer.shadowOpacity = (isDark ? 0.16 : 0.075) + (dockedProgress * (isDark ? 0.025 : 0.018));
        self.layer.shadowRadius = (isDark ? 18.0 : 14.0) + (dockedProgress * 3.0);
        self.layer.shadowOffset = CGSizeMake(0.0,
                                             (isDark ? 8.0 : 6.0) + (dockedProgress * 1.5));
    };

    if (!animated || self.window == nil || UIAccessibilityIsReduceMotionEnabled()) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        updates();
        [CATransaction commit];
        return;
    }

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.34];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithControlPoints:0.18 :0.84 :0.24 :1.0]];
    updates();
    [CATransaction commit];
}

- (void)pp_applyDockedForegroundProgress:(CGFloat)progress animated:(BOOL)animated
{
    CGFloat clampedProgress = PPDataViewClamp01(progress);
    if (fabs(self.dockedForegroundProgress - clampedProgress) < 0.005) {
        return;
    }

    self.dockedForegroundProgress = clampedProgress;
    [self pp_applyPremiumMaterialAnimated:animated];
}

- (void)pp_updateLiquidMotion
{
    [self.liquidShineLayer removeAnimationForKey:@"pp.nav.liquid.shine"];
    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CABasicAnimation *shine = [CABasicAnimation animationWithKeyPath:@"locations"];
    shine.fromValue = @[@-0.34, @-0.22, @-0.08];
    shine.toValue = @[@1.08, @1.22, @1.36];
    shine.duration = 22.0;
    shine.repeatCount = HUGE_VALF;
    shine.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    shine.removedOnCompletion = NO;
    [self.liquidShineLayer addAnimation:shine forKey:@"pp.nav.liquid.shine"];
}

@end

@interface PPDataViewControlIslandView : UIView
@property (nonatomic, assign) BOOL useAccentColor;
- (void)pp_applyActiveFilterCount:(NSInteger)count animated:(BOOL)animated;
- (void)pp_applyAccentColor:(UIColor *)accentColor animated:(BOOL)animated;
- (void)pp_applyScrollCollapseProgress:(CGFloat)progress animated:(BOOL)animated;
- (UIColor *)pp_contentAccentColorForTraitCollection:(UITraitCollection *)traitCollection;
@end

@interface PPDataViewControlIslandView ()
@property (nonatomic, strong) PPBackgroundView *heroBackgroundView;
@property (nonatomic, strong, nullable) UIColor *baseAccentColorOverride;
@property (nonatomic, assign) NSInteger activeFilterCount;
@property (nonatomic, assign) CGFloat scrollCollapseProgress;
@end

@implementation PPDataViewControlIslandView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    PPBackgroundView *glass = [PPBackgroundView new];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.accentStyle = PPHeroGlassAccentStyleCornerGlow;
    glass.cornerGlowOpacityMultiplier = 0.018;
    //glass.glowDirection = PPIsRL ? PPHeroGlowDirectionLeftDirect : PPHeroGlowDirectionRightDirection;
    //glass.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
    glass.accentStyle = PPHeroGlassAccentStyleSolid;
    glass.overrideCornerRadius = kPPDataViewSectionsIslandCornerRadius;
    UIColor *solidSurface =
        PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.90],
                               [UIColor colorWithWhite:0.12 alpha:0.88]);
    glass.overrideSolidColor = solidSurface;
    [self insertSubview:glass atIndex:0];
    self.heroBackgroundView = glass;

    [NSLayoutConstraint activateConstraints:@[
        [glass.topAnchor constraintEqualToAnchor:self.topAnchor],
        [glass.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [glass.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [glass.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    [self pp_applyActiveFilterCount:0 animated:NO];
    return self;
}

- (void)setUseAccentColor:(BOOL)useAccentColor
{
    if (_useAccentColor == useAccentColor) {
        return;
    }

    _useAccentColor = useAccentColor;
    [self pp_applyActiveFilterCount:self.activeFilterCount animated:self.window != nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat cornerRadius = kPPDataViewSectionsIslandCornerRadius;
    self.layer.cornerRadius = cornerRadius;
    self.heroBackgroundView.overrideCornerRadius = cornerRadius;

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius];
    self.layer.shadowPath = shadowPath.CGPath;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
       // [self.heroBackgroundView startAnimations];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyActiveFilterCount:self.activeFilterCount animated:NO];
}

- (void)pp_applyAccentColor:(UIColor *)accentColor animated:(BOOL)animated
{
    self.baseAccentColorOverride = accentColor;

    void (^updates)(void) = ^{
        if (self.activeFilterCount <= 0) {
            self.heroBackgroundView.overrideCenterGlowColor = self.baseAccentColorOverride;
            self.heroBackgroundView.overrideBottomGlowColor = self.baseAccentColorOverride;
        }
        [self.heroBackgroundView reapplyPalette];
    };

    if (!animated || self.window == nil || UIAccessibilityIsReduceMotionEnabled()) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        updates();
        [CATransaction commit];
        return;
    }

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.22];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    updates();
    [CATransaction commit];
}

- (UIColor *)pp_contentAccentColorForTraitCollection:(UITraitCollection *)traitCollection
{
    UIColor *fallback = PPDataViewProviderPillAccentColor(traitCollection);
    if (!self.useAccentColor) {
        return fallback;
    }
    return self.baseAccentColorOverride ?: fallback;
}

- (void)pp_applyActiveFilterCount:(NSInteger)count animated:(BOOL)animated
{
    self.activeFilterCount = MAX(0, count);
    BOOL selected = self.activeFilterCount > 0;

    BOOL darkMode = PPDataViewCurrentAppAppearanceIsDark(self.traitCollection);
    UIColor *accent = [self pp_contentAccentColorForTraitCollection:self.traitCollection];
    UIColor *resolvedAccent = selected ? accent : self.baseAccentColorOverride;
    CGFloat collapseProgress = MIN(MAX(self.scrollCollapseProgress, 0.0), 1.0);
    UIColor *solidSurface =
        PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:(selected ? 0.94 : 0.90)],
                               [UIColor colorWithWhite:(selected ? 0.145 : 0.12) alpha:0.88]);

    void (^updates)(void) = ^{
        self.heroBackgroundView.overrideCenterGlowColor = resolvedAccent;
        self.heroBackgroundView.overrideBottomGlowColor = resolvedAccent;
        self.heroBackgroundView.overrideSolidColor = solidSurface;
        self.heroBackgroundView.alpha = darkMode
            ? 1.0
            : (1.0 - (collapseProgress * 0.035));
        
        [self.heroBackgroundView reapplyPalette];
        self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.layer.borderColor = PPDataViewResolvedColor(
            [UIColor.whiteColor colorWithAlphaComponent:darkMode ? (0.24 + collapseProgress * 0.08) : (0.62 + collapseProgress * 0.10)],
            self.traitCollection
        ).CGColor;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        CGFloat baseShadowOpacity = darkMode ? (selected ? 0.13 : 0.085) : (selected ? 0.065 : 0.038);
        self.layer.shadowOpacity = baseShadowOpacity + (collapseProgress * (darkMode ? 0.035 : 0.030));
        self.layer.shadowRadius = (selected ? 16.0 : 12.0) + (collapseProgress * 4.0);
        self.layer.shadowOffset = CGSizeMake(0.0, (selected ? 8.0 : 6.0) + (collapseProgress * 2.0));
    };

    if (!animated || self.window == nil || UIAccessibilityIsReduceMotionEnabled()) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        updates();
        [CATransaction commit];
        return;
    }

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.22];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    updates();
    [CATransaction commit];
}

- (void)pp_applyScrollCollapseProgress:(CGFloat)progress animated:(BOOL)animated
{
    CGFloat clampedProgress = MIN(MAX(progress, 0.0), 1.0);
    if (fabs(self.scrollCollapseProgress - clampedProgress) < 0.005) {
        return;
    }

    self.scrollCollapseProgress = clampedProgress;
    [self pp_applyActiveFilterCount:self.activeFilterCount animated:animated];
}

@end


@interface PPDropdownFilterChipButton : UIButton
@property (nonatomic, copy) NSString *chipIconName;
@property (nonatomic, assign) BOOL ppHidesTrailingChevron;
@property (nonatomic, assign) BOOL ppUsesActionSurface;
@property (nonatomic, assign) BOOL ppUseAccentColor;
@property (nonatomic, strong, nullable) UIColor *ppAccentColorOverride;
- (void)pp_applyChipTitle:(NSString *)title active:(BOOL)active;
@end

@interface PPDropdownFilterChipButton ()
@property (nonatomic, strong) UIView *materialView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAShapeLayer *strokeLayer;
@property (nonatomic, assign, getter=isPPActive) BOOL ppActive;
- (void)pp_applyPremiumLayerStateAnimated:(BOOL)animated;
@end

@implementation PPDropdownFilterChipButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.showsMenuAsPrimaryAction = YES;
    self.layer.masksToBounds = NO;
    self.backgroundColor = UIColor.clearColor;
    self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.alpha = 1.0;
    self.imageView.alpha = 1.0;
    [self setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.materialView = [[UIView alloc] initWithFrame:CGRectZero];
    self.materialView.userInteractionEnabled = NO;
    self.materialView.clipsToBounds = YES;
    self.materialView.backgroundColor = UIColor.clearColor;
    [self insertSubview:self.materialView atIndex:0];

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.surfaceGradientLayer.locations = @[@0.0, @0.46, @1.0];
    self.surfaceGradientLayer.masksToBounds = YES;
    [self.materialView.layer insertSublayer:self.surfaceGradientLayer atIndex:0];

    self.strokeLayer = [CAShapeLayer layer];
    self.strokeLayer.fillColor = UIColor.clearColor.CGColor;
    self.strokeLayer.lineWidth = 1.0;
    [self.materialView.layer addSublayer:self.strokeLayer];

    self.layer.shadowRadius = 12.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    self.layer.shadowOpacity = 0.10;
    self.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.18].CGColor;

    [self.heightAnchor constraintEqualToConstant:kPPDropdownFilterChipHeight].active = YES;
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat radius = MIN(18.0, PPDataViewPillRadiusForHeight(CGRectGetHeight(self.bounds), 18.0));
    self.layer.cornerRadius = radius;
    self.materialView.frame = self.bounds;
    self.materialView.layer.cornerRadius = radius;
    [self sendSubviewToBack:self.materialView];

    self.surfaceGradientLayer.frame = self.materialView.bounds;
    self.surfaceGradientLayer.cornerRadius = radius;

    CGRect strokeRect = CGRectInset(self.materialView.bounds, 0.7, 0.7);
    CGFloat strokeRadius = radius;
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:strokeRadius];
    self.strokeLayer.frame = self.materialView.bounds;
    self.strokeLayer.path = strokePath.CGPath;
    self.layer.shadowPath = strokePath.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyPremiumLayerStateAnimated:NO];
}

- (void)setPPUseAccentColor:(BOOL)ppUseAccentColor
{
    if (_ppUseAccentColor == ppUseAccentColor) {
        return;
    }

    _ppUseAccentColor = ppUseAccentColor;
    [self pp_applyPremiumLayerStateAnimated:self.window != nil];
}

- (void)setPPAccentColorOverride:(UIColor *)ppAccentColorOverride
{
    if (_ppAccentColorOverride == ppAccentColorOverride ||
        [_ppAccentColorOverride isEqual:ppAccentColorOverride]) {
        return;
    }

    _ppAccentColorOverride = ppAccentColorOverride;
    [self pp_applyPremiumLayerStateAnimated:self.window != nil];
}

- (UIColor *)pp_effectiveAccentColor
{
    return (self.ppUseAccentColor && self.ppAccentColorOverride)
        ? self.ppAccentColorOverride
        : PPDataViewAccentColor();
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = highlighted ? 0.96 : 1.0;
        return;
    }

    CGFloat scale = highlighted ? 0.972 : 1.0;
    [UIView animateWithDuration:highlighted ? 0.12 : 0.20
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformMakeScale(scale, scale);
        self.alpha = highlighted ? 0.98 : 1.0;
    } completion:nil];
}

- (void)pp_applyChipTitle:(NSString *)title active:(BOOL)active
{
    self.ppActive = active;
    self.alpha = 1.0;

    NSString *safeTitle = title.length > 0 ? title : @"";
    UIColor *brand = [self pp_effectiveAccentColor];
    BOOL action = self.ppUsesActionSurface;
    UIColor *premiumText = PPDataViewDynamicColor([UIColor colorWithRed:0.105 green:0.104 blue:0.132 alpha:1.0],
                                                  [UIColor colorWithWhite:0.94 alpha:1.0]);
    UIColor *quietText = PPDataViewDynamicColor([UIColor colorWithRed:0.215 green:0.212 blue:0.252 alpha:1.0],
                                                [UIColor colorWithWhite:0.86 alpha:1.0]);
    BOOL useAccentBackground = self.ppUseAccentColor && self.ppAccentColorOverride;
    UIColor *quietSymbol = PPDataViewDynamicColor([UIColor colorWithRed:0.37 green:0.36 blue:0.43 alpha:1.0],
                                                  [UIColor colorWithWhite:0.78 alpha:1.0]);
    UIColor *accentedFG = action ? premiumText : (active ? premiumText : quietText);
    UIColor *symbolFG = action
        ? premiumText
        : (useAccentBackground ? (active ? premiumText : quietSymbol) : (active ? brand : quietSymbol));
    UIFont *baseFont = action
        ? [GM MidFontWithSize:12.4]
        : (active ? [GM boldFontWithSize:13.2] : [GM MidFontWithSize:13.0]);
    if (!baseFont) {
        baseFont = [UIFont systemFontOfSize:(action ? 12.4 : 13.0)
                                      weight:(active ? UIFontWeightSemibold : UIFontWeightMedium)];
    }
    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:baseFont];
    NSDictionary *textAttrs = @{
        NSFontAttributeName            : font,
        NSForegroundColorAttributeName : accentedFG
    };

    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] init];

    NSString *iconName = [self.chipIconName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (iconName.length > 0) {
        UIImageSymbolConfiguration *iconCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:12.8
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleSmall];
        UIImage *icon = PPDataViewFilterIconImage(iconName, iconCfg, symbolFG);
        if (icon) {
            NSTextAttachment *att = [[NSTextAttachment alloc] init];
            att.image = icon;
            CGFloat symbolSize = action ? 13.5 : 14.0;
            att.bounds = CGRectMake(0.0, -2.0, symbolSize, symbolSize);
            [attrTitle appendAttributedString:
             [NSAttributedString attributedStringWithAttachment:att]];
            [attrTitle appendAttributedString:
             [[NSAttributedString alloc] initWithString:@" " attributes:textAttrs]];
        }
    }

    [attrTitle appendAttributedString:
     [[NSAttributedString alloc] initWithString:safeTitle attributes:textAttrs]];

    if (!self.ppHidesTrailingChevron) {
        UIImageSymbolConfiguration *chevCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:12
                                                            weight:UIImageSymbolWeightSemibold];
        UIImage *chevron = [[UIImage systemImageNamed:@"chevron.down" withConfiguration:chevCfg]
                            imageWithTintColor:symbolFG
                            renderingMode:UIImageRenderingModeAlwaysTemplate];
        if (chevron) {
            NSTextAttachment *chevronAttachment = [[NSTextAttachment alloc] init];
            chevronAttachment.image = chevron;
            //chevronAttachment.bounds = CGRectMake(0.0, -1.2, 9.0, 9.0);
            [attrTitle appendAttributedString:[[NSAttributedString alloc] initWithString:@"  " attributes:textAttrs]];
            [attrTitle appendAttributedString:[NSAttributedString attributedStringWithAttachment:chevronAttachment]];
        }
    }

    // ─── iOS 26+ non-active: clear glass + capsule ───
    if (@available(iOS 26.0, *)) {
        if (!active && !action) {
            UIButtonConfiguration *config = [UIButtonConfiguration prominentGlassButtonConfiguration];
            config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            config.attributedTitle = attrTitle;
            config.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 16.0, 6.0, 14.0);
            UIColor *chipBackground = [AppForgroundColr colorWithAlphaComponent:0.5];
            if (useAccentBackground) {
                chipBackground = [PPDataViewBlendColor(chipBackground, brand, 0.16, self.traitCollection) colorWithAlphaComponent:0.62];
            }
            config.baseBackgroundColor = chipBackground;
            config.background.backgroundColor = chipBackground;
            config.background.cornerRadius = MIN(18.0, PPDataViewPillRadiusForHeight(kPPDropdownFilterChipHeight, 18.0));
            self.configuration = config;
            self.materialView.hidden = YES;
            self.tintColor = accentedFG;

            self.layer.shadowOpacity = 0.0;
            self.layer.shadowRadius = 0.0;

            [self setNeedsLayout];
            return;
        }
        
    }
    else
    {
        self.materialView.hidden = NO;
    }

    // ─── Active / iOS < 26: existing custom rendering ───
    self.configuration = nil;
    self.contentEdgeInsets = action ? UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0) : UIEdgeInsetsMake(6.0, 16.0, 6.0, 14.0);
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.tintColor = accentedFG;
    [self setAttributedTitle:attrTitle forState:UIControlStateNormal];
    [self setAttributedTitle:attrTitle forState:UIControlStateHighlighted];
    [self setAttributedTitle:attrTitle forState:UIControlStateSelected];
    [self setTitleColor:accentedFG forState:UIControlStateNormal];
    [self setTitleColor:accentedFG forState:UIControlStateHighlighted];
    [self setTitleColor:accentedFG forState:UIControlStateSelected];

    [self pp_applyPremiumLayerStateAnimated:self.window != nil];
}

- (void)pp_applyPremiumLayerStateAnimated:(BOOL)animated
{
    UIColor *brand = [self pp_effectiveAccentColor];
    BOOL active = self.isPPActive;
    BOOL usesAccentBackground = self.ppUseAccentColor && self.ppAccentColorOverride;

    // ─── iOS 26+ non-active: glass handles all visuals ───
    if (@available(iOS 26.0, *)) {
        if (!active && !self.ppUsesActionSurface) {
            self.materialView.hidden = YES;
            self.layer.shadowOpacity = 0.0;
            self.layer.shadowRadius = 0.0;
            return;
        }
        self.materialView.hidden = NO;
    }

    void (^updates)(void) = ^{
        BOOL action = self.ppUsesActionSurface;
        UIColor *top;
        UIColor *middle;
        UIColor *bottom;
        UIColor *stroke;
        if (action) {
            top = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.88],
                                         [UIColor colorWithWhite:0.19 alpha:0.94]);
            middle = PPDataViewDynamicColor([UIColor colorWithWhite:0.985 alpha:0.80],
                                            [UIColor colorWithWhite:0.15 alpha:0.92]);
            bottom = PPDataViewDynamicColor([UIColor colorWithWhite:0.97 alpha:0.76],
                                            [UIColor colorWithWhite:0.11 alpha:0.90]);
            stroke = [brand colorWithAlphaComponent:active ? 0.34 : 0.20];
        } else {
            top = PPDataViewDynamicColor([UIColor colorWithRed:1.000 green:0.998 blue:0.996 alpha:1.0],
                                         [UIColor colorWithWhite:0.205 alpha:1.0]);
            middle = PPDataViewDynamicColor([UIColor colorWithRed:0.996 green:0.982 blue:0.988 alpha:1.0],
                                            [UIColor colorWithWhite:0.165 alpha:1.0]);
            bottom = PPDataViewDynamicColor([UIColor colorWithRed:0.968 green:0.958 blue:0.966 alpha:1.0],
                                            [UIColor colorWithWhite:0.115 alpha:1.0]);
            stroke = active
                ? [brand colorWithAlphaComponent:0.38]
                : PPDataViewDynamicColor([UIColor colorWithRed:0.730 green:0.680 blue:0.710 alpha:0.44],
                                         [UIColor colorWithWhite:1.0 alpha:0.14]);
        }

        if (usesAccentBackground) {
            BOOL dark = PPDataViewCurrentAppAppearanceIsDark(self.traitCollection);
            CGFloat accentBlend = (active || action)
                ? (action ? (dark ? 0.28 : 0.14) : (dark ? 0.46 : 0.24))
                : (dark ? 0.32 : 0.14);
            top = PPDataViewBlendColor(top, brand, accentBlend, self.traitCollection);
            middle = PPDataViewBlendColor(middle, brand, accentBlend * 0.82, self.traitCollection);
            bottom = PPDataViewBlendColor(bottom, brand, accentBlend * 0.68, self.traitCollection);
            stroke = [brand colorWithAlphaComponent:action ? 0.24 : (active ? 0.42 : 0.28)];
        } else if (action) {
            BOOL dark = PPDataViewCurrentAppAppearanceIsDark(self.traitCollection);
            CGFloat quietAccentBlend = dark ? 0.22 : 0.10;
            top = PPDataViewBlendColor(top, brand, quietAccentBlend, self.traitCollection);
            middle = PPDataViewBlendColor(middle, brand, quietAccentBlend * 0.78, self.traitCollection);
            bottom = PPDataViewBlendColor(bottom, brand, quietAccentBlend * 0.56, self.traitCollection);
        }
        
        
        if (@available(iOS 26.0, *)) {
            CGFloat leadAlpha = usesAccentBackground ? 0.22 : 0.18;
            CGFloat midAlpha = usesAccentBackground ? 0.08 : 0.04;
            self.surfaceGradientLayer.colors = @[
                (__bridge id)[brand colorWithAlphaComponent:leadAlpha].CGColor,
                (__bridge id)[brand colorWithAlphaComponent:midAlpha].CGColor,
                (__bridge id)[brand colorWithAlphaComponent:0.18].CGColor
            ];
            
            UIButtonConfiguration *config = self.configuration;
            config.background.cornerRadius = 18;
            config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            config.background.strokeWidth =  (active || action) ? 0.75 : 0.25;
            self.configuration = config;
            

        }
        else
        {
            self.surfaceGradientLayer.colors = @[
                (__bridge id)top.CGColor,
                (__bridge id)middle.CGColor,
                (__bridge id)bottom.CGColor
            ];
            

            self.strokeLayer.strokeColor = stroke.CGColor;
            self.strokeLayer.lineWidth = active ? 1.15 : (action ? 0.75 : 1.0);

            self.layer.shadowColor = (action || active)
                ? [brand colorWithAlphaComponent:0.26].CGColor
                : [UIColor colorWithWhite:0.0 alpha:0.18].CGColor;
            self.layer.shadowOpacity = active ? 0.15 : (action ? 0.055 : 0.10);
            self.layer.shadowRadius = active ? 14.0 : (action ? 8.0 : 11.0);
            self.layer.shadowOffset = CGSizeMake(0.0, active ? 6.0 : (action ? 3.0 : 5.0));
        }
        self.surfaceGradientLayer.locations = @[@0.0, @0.46, @1.0];
        self.surfaceGradientLayer.opacity = 1.0;
        
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        updates();
        [CATransaction commit];
        return;
    }

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.18];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    updates();
    [CATransaction commit];
    self.layer.cornerRadius = MIN(18.0, PPDataViewPillRadiusForHeight(CGRectGetHeight(self.bounds), 18.0));
}

@end

@interface PPPremiumCollapseButton : UIButton
@property (nonatomic, assign) BOOL expanded;
@end

@implementation PPPremiumCollapseButton

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = highlighted ? 0.92 : 1.0;
        return;
    }

    CGFloat scale = highlighted ? 0.96 : 1.0;
    [UIView animateWithDuration:highlighted ? 0.10 : 0.18
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformMakeScale(scale, scale);
        self.alpha = highlighted ? 0.94 : 1.0;
    } completion:nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    // Re-apply the transform to protect it from UIKit resetting it
    self.imageView.transform = self.expanded
        ? CGAffineTransformMakeRotation((CGFloat)M_PI)
        : CGAffineTransformIdentity;
}

@end

@interface PPDataViewVC () <PPUniversalCellDelegate,UITabBarDelegate,UIGestureRecognizerDelegate,UICollectionViewDataSourcePrefetching, PPPinterestLayoutDelegate, BBDataViewFullDetailsCellDelegate>//UITabBarDelegate
 // Input
@property (nonatomic, strong) PPDataViewInput *input;
@property (nonatomic, assign) BOOL didInitialReload;
// ViewModel
@property (nonatomic, strong) PPDataViewVM *viewModel;
@property (nonatomic, assign) PPManagerCellLayoutMode cellLayoutMode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) PPCollectionLayoutManager *layoutManager;
@property (nonatomic, strong) PPDataViewControlIslandView *sectionsFiltersContainer;
@property (nonatomic, strong) UIView *filterContextBar;
@property (nonatomic, strong) UIView *filterContextBadgeView;
@property (nonatomic, strong) UIImageView *filterContextIconView;
@property (nonatomic, strong) UILabel *filterContextLabel;
@property (nonatomic, strong) UIView *filterChipContainer;
@property (nonatomic, strong) UIStackView *filterChipStackView;
@property (nonatomic, strong) UIButton *providerFilterChipButton;
@property (nonatomic, strong) UIImageView *providerFilterChipAvatarView;
@property (nonatomic, strong) UIImageView *providerFilterChipTrailingIconView;
@property (nonatomic, strong) UILabel *providerFilterChipTitleLabel;
@property (nonatomic, strong) UILabel *providerFilterChipRatingLabel;
@property (nonatomic, strong) UILabel *providerFilterChipSubtitleLabel;
@property (nonatomic, strong) PPPremiumCollapseButton *filterCollapseButton;
@property (nonatomic, strong) NSMutableArray<PPDropdownFilterChipButton *> *filterChips;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, PPFilterState *> *filterStates;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *selectedProviderIDsBySection;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *providerIdentityCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *providerIdentityFetchesInFlight;
@property (nonatomic, strong) NSMutableSet<NSString *> *providerIdentityHydratedProviderIDs;
// Scroll restore
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *scrollOffsetsBySection;
@property (nonatomic, strong) id imageLoader;

@property (nonatomic, strong) ModernSegmentedControlBridge *sectionsSegmentedControl;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewTop;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewMid;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewBottom;
@property (nonatomic, strong) NSCache<NSString *, UIColor *> *pp_topCellColorCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *pp_inFlightColorExtractions;


@property (nonatomic, assign) CGFloat lastContentOffsetY;
@property (nonatomic, assign) BOOL isRestoringScrollOffset;
// Custom navigation bar center view
@property (nonatomic, strong) PPDataViewNavigationMaterialView *navContainerView;
@property (nonatomic, strong) UIButton *KindsButton;
@property (nonatomic, strong) UIButton *subKindsButton;
@property (nonatomic, strong) UIView *navSeparatorLine;
@property (nonatomic, strong) UIButton *centerCapsuleButton;
@property (nonatomic, strong) UIButton *cartButton;
@property (nonatomic, strong, nullable) UIButton *navCartButton;
@property (nonatomic, strong, nullable) UIButton *navSearchActionsButton;
 @property (nonatomic, strong)  PPEmptyStateConfig *emptyStateConfig;
@property (nonatomic, strong) NSLayoutConstraint *mainKindsWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *sectionsWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *sectionsTabBarHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterContextBarHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterChipHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterChipStackHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterChipTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *providerFilterChipTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *providerFilterChipHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *collectionViewTopAnchorConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cartButtonWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *navContainerWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subKindsTrailingToCartConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subKindsTrailingToContainerConstraint;
@property (nonatomic, strong) NSLayoutConstraint *centerCapsuleMinWidthConstraint;

@property (nonatomic, assign) BOOL isCartButtonVisible;
@property (nonatomic, assign) BOOL isSubKindsChevronHidden;
@property (nonatomic, assign) BOOL useCapsuleNavigation;
@property (nonatomic, assign) BOOL filterBadgesCollapsed;
@property (nonatomic, assign) BOOL didCaptureFilterBadgesCollapsedStateForFullDetails;
@property (nonatomic, assign) BOOL filterBadgesCollapsedBeforeFullDetails;
// Skeleton loading stateAppForgroundColr
@property (nonatomic, assign) BOOL isShowingSkeleton;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPUniversalCellViewModel *> *dataSource;
@property (nonatomic, assign) BOOL didApplyInitialSnapshot;
@property (nonatomic, assign) BOOL didlayout;
@property (nonatomic, assign) BOOL didFixInitialScroll;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *blurHashCache;
@property (nonatomic, strong) dispatch_queue_t blurHashQueue;
@property (nonatomic, assign) BOOL isPerformingCrossFade;
@property (nonatomic, copy) NSString *lastSubKindsTitle;
@property (nonatomic, assign) CGSize lastSectionsIndicatorSize;
@property (nonatomic, copy) NSArray<PPUniversalCellViewModel *> *presentedItems;
@property (nonatomic, assign) PPDataViewMotionReason pendingMotionReason;
@property (nonatomic, assign) NSInteger pendingMotionDirection;
@property (nonatomic, assign) BOOL isAwaitingTransitionData;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedCellEntranceKeys;
@property (nonatomic, assign) NSInteger cellEntranceAnimationGeneration;
@property (nonatomic, assign) NSInteger pendingCellEntranceAnimationLimit;
@property (nonatomic, assign) PPDataViewMotionReason pendingCellEntranceMotionReason;
@property (nonatomic, assign) NSInteger pendingCellEntranceDirection;
@property (nonatomic, assign) BOOL didRunSectionsSegmentedEntrance;
@property (nonatomic, assign) CGFloat premiumHeaderCollapseProgress;
@property (nonatomic, assign) CGFloat premiumHeaderDockProgress;
@property (nonatomic, assign) BOOL premiumHeaderIsDocked;
@property (nonatomic, assign) BOOL isUpdatingCollectionInsetForHeaderMotion;
@property (nonatomic, strong) UIImageView *navDockedIslandSnapshotView;
@property (nonatomic, strong) NSMapTable<SDWebImagePrefetchToken *, NSSet<NSString *> *> *ownedPrefetchURLsByToken;
@property (nonatomic, assign) BOOL didEmitFirstVisibleContentSignpost;
@property (nonatomic, assign) BOOL pendingFilterScrollToTop;
@property (nonatomic, assign) BOOL  DidFinishLayout;
- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (NSMapTable<SDWebImagePrefetchToken *, NSSet<NSString *> *> *)pp_ownedPrefetchTokenMap;
- (void)pp_cancelOwnedPrefetchesForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)pp_cancelAllOwnedPrefetches;
- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit;
- (void)pp_installPinterestHeightGuardIfNeeded;
- (void)updateSectionsTabBarSelectionIndicatorIfNeeded;
- (void)saveCurrentSectionScrollOffset;
- (void)restoreScrollOffsetForCurrentSection;
- (CGFloat)preferredTopContentOffsetY;
- (void)pp_handleCartUpdated:(NSNotification *)note;
- (NSInteger)currentCartItemCount;
- (void)updateCartBadge;
- (void)updateCartButtonVisibilityForSection:(PPDataSection)section;
- (void)updateCartButtonVisibilityForSection:(PPDataSection)section animated:(BOOL)animated;
- (void)updateCartButtonVisibility;
- (void)persistSectionSelection:(PPDataSection)section;
- (void)updateSectionsTabBarSelectionForSection:(PPDataSection)section;
- (void)activateSection:(PPDataSection)section userInitiated:(BOOL)userInitiated;
- (NSInteger)pp_segmentIndexForSection:(PPDataSection)section;
- (PPDataSection)pp_sectionForSegmentIndex:(NSInteger)segmentIndex;
- (BOOL)sectionHasFilterChipBarForSection:(PPDataSection)section;
- (BOOL)shouldShowFilterChipBarForSection:(PPDataSection)section;
- (void)syncFilterChipsForCurrentSection;
- (void)syncFilterChipsForSection:(PPDataSection)section;
- (void)updateFilterChipVisibilityForSection:(PPDataSection)section animated:(BOOL)animated;
- (void)updateFilterCollapseButtonForSection:(PPDataSection)section expanded:(BOOL)expanded animated:(BOOL)animated;
- (void)updateFilterContextBarForSection:(PPDataSection)section;
- (void)updateProviderFilterChipForSection:(PPDataSection)section expanded:(BOOL)expanded animated:(BOOL)animated;
- (void)providerFilterChipTapped:(UIButton *)sender;
- (NSString *)filterContextTitleForSection:(PPDataSection)section;
- (void)pp_applyFilterContextBarAppearance;
- (BOOL)pp_controlIslandUsesAccentColor;
- (UIColor *)pp_controlIslandAccentColor;
- (UIColor *)pp_controlIslandContentAccentColor;
- (BOOL)pp_sectionSupportsProviderFilter:(PPDataSection)section;
- (NSArray<OptionModel *> *)providerOptionsForCurrentSection;
- (NSArray<OptionModel *> *)providerOptionsForSection:(PPDataSection)section sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems;
- (NSString *)selectedProviderIDForSection:(PPDataSection)section;
- (void)setSelectedProviderID:(NSString *)providerID forSection:(PPDataSection)section;
- (void)clearSelectedProviderForSection:(PPDataSection)section;
- (BOOL)pp_reconcileSelectedProviderForSection:(PPDataSection)section sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems;
- (void)pp_applyProviderChipContentForSection:(PPDataSection)section providerCount:(NSInteger)providerCount;
- (void)pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:(BOOL)animated;
- (NSString *)pp_providerIDForViewModel:(PPUniversalCellViewModel *)viewModel;
- (NSString *)pp_providerTitleForViewModel:(PPUniversalCellViewModel *)viewModel fallbackID:(NSString *)providerID;
- (NSString *)pp_providerRatingBadgeTextForProviderID:(NSString *)providerID sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems;
- (NSString *)pp_providerPhotoURLForProviderID:(NSString *)providerID sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems;
- (NSString *)pp_providerPhotoURLForViewModel:(PPUniversalCellViewModel *)viewModel fallbackID:(NSString *)providerID;
- (UIImage *)pp_providerPlaceholderImage;
- (void)pp_updateProviderChipAvatarForProviderID:(NSString *)providerID title:(NSString *)title sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems;
- (NSString *)pp_providerSheetSubtitleForCount:(NSInteger)count;
- (NSString *)pp_shortProviderIdentifier:(NSString *)providerID;
- (NSDictionary<NSString *, NSString *> *)pp_cachedProviderIdentityForProviderID:(NSString *)providerID;
- (void)pp_storeProviderIdentityForProviderID:(NSString *)providerID title:(NSString *)title photoURL:(NSString *)photoURL;
- (void)pp_prefetchProviderIdentitiesForSection:(PPDataSection)section sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems;
- (void)pp_hydrateProviderIdentitiesForIDs:(NSArray<NSString *> *)providerIDs section:(PPDataSection)section completion:(dispatch_block_t)completion;
- (NSString *)pp_realProviderTitleForID:(NSString *)providerID sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems;
- (BOOL)pp_providerTitleIsGeneric:(NSString *)title providerID:(NSString *)providerID;
- (void)pp_presentProviderFilterSheetForSection:(PPDataSection)section options:(NSArray<OptionModel *> *)options selectedOption:(OptionModel *)selectedOption;
- (CGFloat)pp_currentCollectionChromeBottomY;
- (CGFloat)pp_targetCollectionTopInsetFollowingChrome;
- (CGFloat)pp_currentCollectionLayoutTopInset;
- (BOOL)pp_shouldPinCollectionTopForChromeOffset:(CGPoint)currentOffset
                              previousTopOffsetY:(CGFloat)previousTopOffsetY;
- (void)pp_updateCollectionContentInsetPreservingTopAnchor;
- (void)pp_collapseFilterIslandForUserScrollIfNeededAnimated:(BOOL)animated;
- (void)pp_collapseFilterIslandForFullDetailsIfNeededAnimated:(BOOL)animated;
- (void)pp_restoreFilterIslandAfterLeavingFullDetailsIfNeededAnimated:(BOOL)animated;
- (void)toggleFilterBadgesCollapsed:(id)sender;
- (void)refreshPresentedItemsAnimated:(BOOL)animated scrollToTop:(BOOL)scrollToTop;
- (BOOL)pp_presentedItemsContainOnlySkeletons;
- (void)pp_clearSkeletonPresentationForEmptyStateIfNeeded;
- (void)refreshFilterChipTitles;
- (void)refreshFilterChipTitlesForSection:(PPDataSection)section;
- (void)openFilters;
- (PPFilterState *)pp_filterStateForSection:(PPDataSection)section;
- (NSInteger)pp_activeFilterCountForSection:(PPDataSection)section;
- (PPFilterState *)pp_freshFilterStateForSection:(PPDataSection)section;
- (NSArray<PPAccessoryCategoryModel *> *)pp_accessoryFilterCategoriesForCurrentContext;
- (void)sectionsSegmentedControlChanged:(ModernSegmentedControlBridge *)sender;
- (void)onCartTapped;
- (void)pp_openSearchController;
- (void)pp_applyTemporaryHiddenCartButtonState;
- (void)pp_refreshSearchActionsMenu;
- (void)pp_applyLayoutModeFromActionsMenu:(PPManagerCellLayoutMode)mode;
- (void)pp_applyLayoutModeInternal:(PPManagerCellLayoutMode)mode saveToDefaults:(BOOL)saveToDefaults;
- (void)pp_applyLayoutModeInternal:(PPManagerCellLayoutMode)mode
                     saveToDefaults:(BOOL)saveToDefaults
                            animated:(BOOL)animated;
- (PPManagerCellLayoutMode)pp_sanitizedDataViewLayoutMode:(PPManagerCellLayoutMode)mode;
- (BOOL)pp_isDataViewLayoutMode:(PPManagerCellLayoutMode)mode;
- (BOOL)pp_isFullDetailsLayoutMode;
- (UICollectionViewLayout *)pp_collectionLayoutForDataViewMode:(PPManagerCellLayoutMode)mode;
- (void)pp_applyCollectionBehaviorForLayoutMode:(PPManagerCellLayoutMode)mode;
- (NSIndexPath *)pp_centerAnchorIndexPathForLayoutSwitch;
- (void)pp_scrollToAnchorIndexPath:(NSIndexPath *)indexPath
                         fullDetails:(BOOL)fullDetails
                            animated:(BOOL)animated;
- (void)pp_refreshCollectionLayoutAfterSnapshotPreservingOffset:(BOOL)preserveOffset;
- (CGPoint)pp_fullDetailsCenteredOffsetForProposedOffset:(CGPoint)proposedOffset
                                                velocity:(CGPoint)velocity;
- (void)pp_settleFullDetailsCarouselIfNeededAnimated:(BOOL)animated;
- (CGFloat)preferredNavigationCenterViewWidth;
- (CGFloat)pp_widthForBarButtonItem:(UIBarButtonItem *)item fallback:(CGFloat)fallback;
- (PPFilterState *)pp_currentFilterState;
- (void)pp_restoreNavigationOwnership;
- (void)pp_removeForeignHomeSearchViewsFromView:(UIView *)view;
- (void)pp_handleForegroundRestore:(NSNotification *)notification;
- (void)pp_refreshVisibleUniversalCellsAppearance;
- (void)pp_applyPremiumNavigationBarAppearance;
- (void)pp_applyPremiumNavigationChromeAppearance;
- (void)pp_applyPremiumNavIconButtonAppearance:(UIButton *)button emphasized:(BOOL)emphasized;
- (void)pp_applyPremiumNavSearchButtonAppearance;
- (void)pp_applyPremiumMainKindsButtonSurface;
- (void)pp_applyPremiumSubKindsButtonSurface;
- (NSString *)pp_centerCapsuleNavigationTitle;
- (void)pp_applyExperimentalCenterCapsuleAppearance;
- (void)pp_syncExperimentalCenterCapsuleState;
- (NSString *)pp_mainKindsSelectorCaption;
- (NSString *)pp_subKindsSelectorCaption;
- (BOOL)pp_mainKindsSelectorIsActive;
- (BOOL)pp_subKindsSelectorIsActive;
- (void)pp_applyPremiumSelectorButton:(UIButton *)button
                          primaryText:(NSString *)primaryText
                              caption:(NSString *)caption
                           emphasized:(BOOL)emphasized;
- (void)pp_updateMainKindsButtonTitleAnimated:(BOOL)animated;
- (NSString *)pp_currentMainKindsDisplayTitle;
- (NSString *)pp_currentSubKindsDisplayTitle;
- (void)pp_applyPremiumSectionsSegmentedAppearance;
- (CGFloat)pp_headerCollapseProgressForScrollView:(UIScrollView *)scrollView;
- (CGFloat)pp_headerDockProgressForCollapseProgress:(CGFloat)progress;
- (CGRect)pp_navigationTitleDockRectInView;
- (CGAffineTransform)pp_controlIslandDockTransformForProgress:(CGFloat)dockProgress
                                                 reduceMotion:(BOOL)reduceMotion;
- (void)pp_applyNavigationTitleDockProgress:(CGFloat)dockProgress;
- (void)pp_promoteNavigationTitleContainerForDockProgress:(CGFloat)dockProgress
                                         snapshotProgress:(CGFloat)snapshotProgress;
- (CGFloat)pp_dockedIslandSnapshotProgressForDockProgress:(CGFloat)dockProgress;
- (CGAffineTransform)pp_navigationTitleTransformForDockProgress:(CGFloat)dockProgress
                                           previousDockProgress:(CGFloat)previousDockProgress
                                                   reduceMotion:(BOOL)reduceMotion;
- (void)pp_installDockedIslandSnapshotIfNeeded;
- (void)pp_removeDockedIslandSnapshotAnimated:(BOOL)animated;
- (void)pp_updateDockedIslandSnapshotFrame;
- (void)pp_runNavigationTitleDockHaloAnimation;
- (void)pp_updatePremiumHeaderCollapseForScrollView:(UIScrollView *)scrollView animated:(BOOL)animated;
- (void)pp_applyPremiumHeaderCollapseProgress:(CGFloat)progress animated:(BOOL)animated;
- (void)pp_updatePremiumChromeShadowPaths;
- (void)pp_applyPremiumDataViewBackgroundAppearance;
- (void)pp_installPremiumBackgroundGlowViewsIfNeeded;
- (void)pp_layoutPremiumBackgroundGlowViews;
- (void)pp_updatePremiumBackgroundGlowAppearance;
- (BOOL)pp_allowsPremiumMotion;
- (void)pp_beginMotionTransition:(PPDataViewMotionReason)reason direction:(NSInteger)direction;
- (NSInteger)pp_directionForSubKindID:(NSInteger)newSubKindID comparedToCurrentSubKindID:(NSInteger)currentSubKindID;
- (void)updateSectionsTabBarSelectionForSection:(PPDataSection)section animated:(BOOL)animated;
- (void)updateSubKindsButtonTitle:(NSString *)title animated:(BOOL)animated;
- (void)updateSubKindsButtonTitle:(NSString *)title
                          subKind:(nullable SubKindModel *)subKind
                         animated:(BOOL)animated;
- (void)pp_applyNavigationChangeAnimationToButton:(UIButton *)button updates:(dispatch_block_t)updates;
- (void)pp_applyFeedbackPulseToView:(UIView *)view;
- (void)pp_prepareSectionsSegmentedEntranceInitialState;
- (void)pp_runSectionsSegmentedEntranceIfNeeded;
- (void)pp_setSectionsSegmentedEntranceVisibleWithoutAnimation;
- (void)pp_anchorSkeletonLoadingBelowChromeIfNeeded;
- (NSArray<UICollectionViewCell *> *)pp_sortedVisibleCollectionCells;
- (NSString *)pp_cellAnimationKeyForIndexPath:(NSIndexPath *)indexPath;
- (void)pp_prepareCellEntranceAnimationsForReason:(PPDataViewMotionReason)reason direction:(NSInteger)direction;
- (void)pp_animatePreparedVisibleCellsIfNeeded;
- (void)pp_animateCellIfNeeded:(UICollectionViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)pp_applyPresentedItemsAnimated:(BOOL)animated
                           scrollToTop:(BOOL)scrollToTop
                          motionReason:(PPDataViewMotionReason)motionReason
                       motionDirection:(NSInteger)motionDirection;
- (void)pp_performPremiumContentTransitionForReason:(PPDataViewMotionReason)motionReason
                                    motionDirection:(NSInteger)motionDirection
                                        scrollToTop:(BOOL)scrollToTop;
@end
@implementation PPDataViewVC

- (void)setUseCapsuleNavigation:(BOOL)useCapsuleNavigation
{
    if (_useCapsuleNavigation == useCapsuleNavigation) {
        return;
    }

    _useCapsuleNavigation = useCapsuleNavigation;
    [self pp_syncExperimentalCenterCapsuleState];
}

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindFloatingCartSurface;
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if(!_didlayout && self.viewModel.currentSubKindID == 0)
    {
        _didlayout = YES;
        [self updateNavMainKindTitle];
    }

}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] setSuppressedForCriticalFlow:YES];
    [self pp_applyBottomSurfaceAnimated:animated];

    UINavigationController *nav = self.navigationController;
    if (!nav) return;

    UIGestureRecognizer *pop = nav.interactivePopGestureRecognizer;

    // 🔥 CRITICAL FIX
    pop.delegate = nil;          // reset UIKit internal state
    pop.enabled = YES;
    pop.delegate = self;         // reattach
    [self updateCartBadge];

    // Recover from any interrupted cross-fade path to avoid "dead" taps.
    self.isPerformingCrossFade = NO;
    if (self.collectionView) {
        self.collectionView.userInteractionEnabled = YES;
        self.collectionView.alpha = 1.0;
        for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        }
    }
    [self pp_applyPremiumNavigationBarAppearance];
    [self pp_applyPremiumNavigationChromeAppearance];
    [self pp_applyPremiumSectionsSegmentedAppearance];
    [self pp_restoreNavigationOwnership];
    [self pp_refreshVisibleUniversalCellsAppearance];

    if (self.layoutManager && self.layoutManager.currentLayoutMode == PPCellLayoutModeDataViewFullDetails) {
        [self pp_collapseFilterIslandForFullDetailsIfNeededAnimated:NO];
    }

    NSString *kindName = self.input.mainKind.KindNameEn;
    if (kindName.length) {
        [PPAnalytics logViewCategoryWithCategory:kindName listName:nil];
        [PPAnalytics logViewItemListWithCategory:kindName
                                        listName:@"home_feed"
                                       itemCount:self.presentedItems.count];
    }
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] hideNova];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] setSuppressedForCriticalFlow:NO];

    UIGestureRecognizer *pop = self.navigationController.interactivePopGestureRecognizer;
    if (pop.delegate == self) {
        pop.delegate = nil;
    }
}
-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_restoreNavigationOwnership];
    if (self.sectionsFiltersContainer) {
        [self.view bringSubviewToFront:self.sectionsFiltersContainer];
    }
    [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
    [self prefetchSubKindIcons];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.isPerformingCrossFade = NO;
    self.isAwaitingTransitionData = NO;
    self.pendingMotionReason = PPDataViewMotionReasonNone;
    self.pendingCellEntranceAnimationLimit = 0;
    self.pendingCellEntranceMotionReason = PPDataViewMotionReasonNone;
    [self.animatedCellEntranceKeys removeAllObjects];
    if (self.collectionView) {
        self.collectionView.userInteractionEnabled = YES;
        self.collectionView.alpha = 1.0;
        for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        BOOL changed = [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
        if (changed) {
            [self pp_applyPremiumDataViewBackgroundAppearance];
            [self pp_applyPremiumNavigationBarAppearance];
            [self pp_applyPremiumNavigationChromeAppearance];
            [self pp_applyPremiumSectionsSegmentedAppearance];
        }
        if (changed && self.lastSubKindsTitle.length > 0) {
            [self updateSubKindsButtonTitle:self.lastSubKindsTitle];
            [self refreshFilterChipTitles];
            [self pp_restoreNavigationOwnership];
            [self pp_refreshVisibleUniversalCellsAppearance];
        }
    }
}

- (void)prefetchSubKindIcons
{
    MainKindsModel *mainKind = self.input.mainKind;
    if (!mainKind || mainKind.SubKindsArray.count == 0) return;

    NSMutableArray<NSString *> *urlStrings = [NSMutableArray array];

    for (SubKindModel *subKind in mainKind.SubKindsArray) {
        if (subKind.subKindIconUrl.length) {
            NSURL *url = [NSURL URLWithString:subKind.subKindIconUrl];
            if (url) [urlStrings addObject:url.absoluteString];
        }
    }

    if (urlStrings.count == 0) return;

    __weak typeof(self) weakSelf = self;
    __block SDWebImagePrefetchToken *token = nil;
    token = [[PPImageLoaderManager shared]
             prefetchURLsReturningToken:urlStrings
                              completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token) {
                [weakSelf.ownedPrefetchURLsByToken removeObjectForKey:token];
            }
        });
    }];
    if (token) {
        [[self pp_ownedPrefetchTokenMap] setObject:[NSSet setWithArray:urlStrings] forKey:token];
    }
}


 
#pragma mark - Init

- (instancetype)initWithInput:(PPDataViewInput *)input
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;

    os_log_t log = PPDataViewVCPerformanceLog();
    os_signpost_id_t initSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, initSignpostID, "destination.init");

    _input = input;

    os_signpost_interval_end(log, initSignpostID, "destination.init");
    return self;
}

 #pragma mark - Skeleton Loading

- (void)showSkeleton
{
    if (self.isShowingSkeleton) return;
    self.isShowingSkeleton = YES;

    // Remove empty state from background immediately
    [PPEmptyStateHelper removeEmptyStateFromListView:self.collectionView];
    if (self.sectionsFiltersContainer) {
        [self pp_setSectionsSegmentedEntranceVisibleWithoutAnimation];
        [self.view bringSubviewToFront:self.sectionsFiltersContainer];
    }

    NSMutableArray *items = [NSMutableArray array];
    NSInteger count = 8;

    for (NSInteger i = 0; i < count; i++) {
        PPUniversalCellViewModel *vm =
        [[PPUniversalCellViewModel alloc] initSkeletonForDataSection:self.viewModel.currentSection];
        [items addObject:vm];
    }

    self.layoutManager.items = items;
    self.presentedItems = items;

    [self.layoutManager applyLayoutMode:self.layoutManager.currentLayoutMode
                       toCollectionView:self.collectionView
                               animated:NO];
    [self updateCollectionContentInset];
    [self pp_anchorSkeletonLoadingBelowChromeIfNeeded];

    [self performCrossFadeReload];
}

- (void)hideSkeleton
{
    if (!self.isShowingSkeleton) return;
    self.isShowingSkeleton = NO;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    os_log_t log = PPDataViewVCPerformanceLog();
    os_signpost_id_t viewDidLoadSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, viewDidLoadSignpostID, "destination.viewDidLoad");

    [super viewDidLoad];
    self.DidFinishLayout = NO;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    }
    self.didFixInitialScroll = NO;
    self.filterBadgesCollapsed = YES; // Default filter state is collapsed
    _didlayout = NO;
    self.useCapsuleNavigation = NO;
    self.blurHashCache = [NSCache new];
    self.blurHashCache.countLimit = 200;
    self.pp_topCellColorCache = [NSCache new];
    self.pp_topCellColorCache.countLimit = 100;
    self.pp_inFlightColorExtractions = [NSMutableSet set];
    self.blurHashQueue =
    dispatch_queue_create("com.purepets.blurhash.decode", DISPATCH_QUEUE_CONCURRENT);
    self.isPerformingCrossFade = NO;
    self.presentedItems = @[];
    self.ownedPrefetchURLsByToken = [NSMapTable strongToStrongObjectsMapTable];
    self.didEmitFirstVisibleContentSignpost = NO;
    self.pendingMotionReason = PPDataViewMotionReasonNone;
    self.pendingMotionDirection = 0;
    self.isAwaitingTransitionData = NO;
    self.animatedCellEntranceKeys = [NSMutableSet set];
    self.cellEntranceAnimationGeneration = 0;
    self.pendingCellEntranceAnimationLimit = 0;
    self.pendingCellEntranceMotionReason = PPDataViewMotionReasonNone;
    self.pendingCellEntranceDirection = 0;
    self.didRunSectionsSegmentedEntrance = NO;
    self.premiumHeaderCollapseProgress = 0.0;

    [self emptyStateInit];
    [self setupSectionsTabBar];
    // 🔥 FIX: normalize AllKinds EARLY
    [self normalizeInitialMainKind];

    [self setupNavigation];
    [self setupViewModel];
   
    [self setupCollectionView];
    [self pp_applyPremiumDataViewBackgroundAppearance];
    [self updateEmptyState];

    [self bindViewModel];

    // viewDidLoad is already on the main thread. Start the route transaction
    // now so request creation is not delayed by another main-queue turn.
    [self handleInitialRoute];

    self.title=nil;
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pp_handleAdDidUpload:)
     name:PPAdDidFinishUploadNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pp_handleCartUpdated:)
     name:kCartUpdatedNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pp_handleForegroundRestore:)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pp_handleForegroundRestore:)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
    
     
    os_signpost_interval_end(log, viewDidLoadSignpostID, "destination.viewDidLoad");
}

- (void)dealloc
{
    [self pp_cancelAllOwnedPrefetches];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PPAdDidFinishUploadNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kCartUpdatedNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    UIGestureRecognizer *pop = self.navigationController.interactivePopGestureRecognizer;
    if (pop.delegate == self) {
        pop.delegate = nil;
    }
}

- (void)pp_handleForegroundRestore:(NSNotification *)notification
{
    (void)notification;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_handleForegroundRestore:notification];
        });
        return;
    }

    if (self.navigationController.topViewController != self) {
        return;
    }

    [self pp_restoreNavigationOwnership];
    [self pp_refreshVisibleUniversalCellsAppearance];
}

- (void)pp_restoreNavigationOwnership
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_restoreNavigationOwnership];
        });
        return;
    }
    if (!self.isViewLoaded) {
        return;
    }

    UINavigationController *nav = self.navigationController;
    if (nav && nav.topViewController != self) {
        return;
    }

    self.title = nil;
    self.navigationItem.title = nil;
    if (nav.navigationBar) {
        [self pp_removeForeignHomeSearchViewsFromView:nav.navigationBar];
    }
    if (self.navContainerView && self.navigationItem.titleView != self.navContainerView) {
        self.navigationItem.titleView = self.navContainerView;
    }

    [self pp_applyTemporaryHiddenCartButtonState];
    [self pp_applyPremiumNavigationBarAppearance];
    [self pp_applyPremiumNavigationChromeAppearance];
    self.navContainerView.hidden = NO;
    self.navContainerView.alpha = 1.0;
    [self.navContainerView setNeedsLayout];
    [self.navContainerView layoutIfNeeded];
    [self updateCartBadge];
}

- (void)pp_removeForeignHomeSearchViewsFromView:(UIView *)view
{
    for (UIView *subview in view.subviews.copy) {
        NSString *className = NSStringFromClass(subview.class);
        if ([className containsString:@"PPHomeSmartSearchTitleView"]) {
            [subview removeFromSuperview];
            continue;
        }
        [self pp_removeForeignHomeSearchViewsFromView:subview];
    }
}

- (void)pp_refreshVisibleUniversalCellsAppearance
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_refreshVisibleUniversalCellsAppearance];
        });
        return;
    }

    for (__kindof UICollectionViewCell *cell in self.collectionView.visibleCells) {
        if ([PPUniversalCell pp_isUniversalCell:cell]) {
            [(PPUniversalCell *)cell refreshThemeAppearance];
        } else {
            [cell setNeedsLayout];
        }
    }
}

- (void)pp_applyPremiumNavigationBarAppearance
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar) {
        return;
    }

    navigationBar.prefersLargeTitles = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    navigationBar.translucent = YES;
    navigationBar.tintColor = PPDataViewChromeTextColor();

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName : PPDataViewChromeTextColor(),
        NSFontAttributeName : [GM boldFontWithSize:17.0]
    };

    navigationBar.standardAppearance = appearance;
    navigationBar.scrollEdgeAppearance = appearance;
    navigationBar.compactAppearance = appearance;
    if (@available(iOS 15.0, *)) {
        navigationBar.compactScrollEdgeAppearance = appearance;
    }
    self.navigationItem.standardAppearance = [appearance copy];
    self.navigationItem.scrollEdgeAppearance = [appearance copy];
    self.navigationItem.compactAppearance = [appearance copy];
    if (@available(iOS 15.0, *)) {
        self.navigationItem.compactScrollEdgeAppearance = [appearance copy];
    }
}

- (void)pp_applyPremiumNavIconButtonAppearance:(UIButton *)button emphasized:(BOOL)emphasized
{
    if (!button) {
        return;
    }

    UIColor *accent = PPDataViewAccentColor();
    UIColor *foreground = emphasized ? accent : PPDataViewChromeTextColor();
    UIColor *surface = emphasized
        ? [accent colorWithAlphaComponent:0.115]
        : PPDataViewChromeElevatedSurfaceColor();
    UIColor *stroke = emphasized
        ? [accent colorWithAlphaComponent:0.28]
        : PPDataViewChromeStrokeColor();

    UIButtonConfiguration *configuration = button.configuration;
    if (!configuration) {
        configuration = [UIButtonConfiguration plainButtonConfiguration];
    }
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(2.0, 7.0, 2.0, 7.0);
    configuration.baseForegroundColor = foreground;
    configuration.background.backgroundColor = surface;
    configuration.background.strokeColor = stroke;
    configuration.background.strokeWidth = 0.8;
    button.configuration = configuration;

    button.tintColor = foreground;
    button.backgroundColor = UIColor.clearColor;
    button.clipsToBounds = NO;
    button.layer.masksToBounds = NO;
    button.layer.cornerRadius = 18.0; // fallback until layout updates it to half height
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.borderWidth = 0.0;
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityTraits = UIAccessibilityTraitButton;
    [button pp_setShadowColor:PPDataViewChromeShadowColor()];
    button.layer.shadowOpacity = emphasized ? 0.05 : 0.035;
    button.layer.shadowRadius = emphasized ? 8.0 : 6.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 3.0);
}

- (void)pp_applyPremiumNavSearchButtonAppearance
{
    UIButton *button = self.navSearchActionsButton;
    if (!button) {
        return;
    }

    [self pp_applyPremiumNavIconButtonAppearance:button emphasized:NO];

    UIImageSymbolConfiguration *symbolConfiguration =
    [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];
    UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
    configuration.image = [[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:symbolConfiguration]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    configuration.imagePadding = 0.0;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
    configuration.baseForegroundColor = PPDataViewChromeTextColor();
    button.configuration = configuration;
    button.tintColor = PPDataViewChromeTextColor();
    button.showsMenuAsPrimaryAction = YES;
    if (@available(iOS 15.0, *)) {
        button.changesSelectionAsPrimaryAction = NO;
    }
    button.accessibilityLabel = kLang(@"PPDataViewSearchMenuA11y");
    button.accessibilityHint = kLang(@"PPDataViewSearchMenuHint");
}

- (void)pp_applyPremiumSelectorButton:(UIButton *)button
                          primaryText:(NSString *)primaryText
                              caption:(NSString *)caption
                           emphasized:(BOOL)emphasized
{
    if (!button) {
        return;
    }

    NSString *resolvedPrimary = primaryText.length > 0 ? primaryText : (kLang(@"All") ?: @"All");
    NSString *resolvedCaption = caption.length > 0 ? caption : @"";
    UIColor *accent = PPDataViewAccentColor();
    UIColor *primaryColor = PPDataViewChromeTextColor();
    UIColor *captionColor = emphasized
        ? [accent colorWithAlphaComponent:0.82]
        : PPDataViewChromeSecondaryTextColor();
    UIColor *chevronColor = emphasized ? captionColor : [PPDataViewChromeSecondaryTextColor() colorWithAlphaComponent:0.82];
    BOOL shouldShowChevron = (button != self.subKindsButton) || !self.isSubKindsChevronHidden;

    NSMutableParagraphStyle *centeredStyle = [[NSMutableParagraphStyle alloc] init];
    centeredStyle.alignment = NSTextAlignmentCenter;
    centeredStyle.lineBreakMode = NSLineBreakByTruncatingTail;

    centeredStyle.lineSpacing = -0.6;
    centeredStyle.paragraphSpacing = 0;
    centeredStyle.lineHeightMultiple = 0.96;

    UIFont *baseTitleFont = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    UIFont *baseCaptionFont = [GM MidFontWithSize:9.2] ?: [UIFont systemFontOfSize:9.2 weight:UIFontWeightMedium];
    UIFont *titleFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:baseTitleFont
                                                                                         maximumPointSize:16.4];
    UIFont *captionFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption2] scaledFontForFont:baseCaptionFont
                                                                                         maximumPointSize:10.8];

    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:resolvedPrimary
                                                                              attributes:@{
        NSFontAttributeName : titleFont,
        NSForegroundColorAttributeName : primaryColor,
        NSParagraphStyleAttributeName : centeredStyle
    }];

    UIButtonConfiguration *configuration = button.configuration;
    if (!configuration) {
        configuration = [UIButtonConfiguration plainButtonConfiguration];
    }
    CGFloat selectorRadius = CGRectGetHeight(button.bounds) > 0.0
        ? CGRectGetHeight(button.bounds) * 0.5
        : kPPDataViewSelectorCornerRadius;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.background.cornerRadius = selectorRadius;

    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;

    configuration.contentInsets = NSDirectionalEdgeInsetsMake(3.0, 8.0, 3.0, 8.0);

    configuration.attributedSubtitle =
    [[NSAttributedString alloc] initWithString:resolvedCaption
                                    attributes:@{
        NSFontAttributeName : captionFont,
        NSForegroundColorAttributeName : captionColor,
        NSParagraphStyleAttributeName : centeredStyle
    }];
    configuration.attributedTitle = title;
    configuration.titleLineBreakMode = NSLineBreakByTruncatingTail;
    configuration.subtitleLineBreakMode = NSLineBreakByTruncatingTail;
    configuration.baseForegroundColor = primaryColor;

    // Use native UIButtonConfiguration trailing image alignment instead of a hacky NSTextAttachment.
    // This perfectly centers the arrow vertically with the text line-height and adapts to RTL direction.
    if (shouldShowChevron) {
        UIImage *chevron =
        [UIImage pp_symbolNamed:@"chevron.down"
                      pointSize:9.4
                         weight:UIImageSymbolWeightBold
                          scale:UIImageSymbolScaleSmall
                        palette:@[chevronColor]
                   makeTemplate:NO];
        configuration.image = chevron;
        configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
        configuration.imagePadding = 7.5; // Added elegant horizontal breathing room next to the value
    } else {
        configuration.image = nil;
        configuration.imagePadding = 0.0;
    }
    configuration.background.backgroundColor = UIColor.clearColor;
    configuration.background.strokeColor = UIColor.clearColor;
    configuration.background.strokeWidth = 0.0;
    configuration.background.cornerRadius = selectorRadius;
    button.configuration = configuration;

    button.tintColor = emphasized ? accent : PPDataViewChromeSecondaryTextColor();
    button.backgroundColor = UIColor.clearColor;
    button.layer.cornerRadius = selectorRadius;
    button.layer.shadowOpacity = 0.0;
    button.layer.shadowRadius = 0.0;
    button.layer.shadowOffset = CGSizeZero;
    button.layer.shadowColor = nil;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.clipsToBounds = NO;
    button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.86;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.accessibilityTraits = emphasized ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
}

- (NSString *)pp_mainKindsSelectorCaption
{
    return kLang(@"data_nav_species") ?: @"Species";
}

- (NSString *)pp_subKindsSelectorCaption
{
    return kLang(@"data_nav_breed") ?: @"Breed";
}

- (BOOL)pp_mainKindsSelectorIsActive
{
    return self.input.mainKind != nil && self.input.sourceTarget != PPDeepLinkTargetAllCategories;
}

- (BOOL)pp_subKindsSelectorIsActive
{
    return self.viewModel.currentSubKindID != 0;
}

- (void)pp_applyPremiumMainKindsButtonSurface
{
    [self pp_applyPremiumSelectorButton:self.KindsButton
                            primaryText:[self pp_currentMainKindsDisplayTitle]
                                caption:[self pp_mainKindsSelectorCaption]
                             emphasized:[self pp_mainKindsSelectorIsActive]];
}

- (void)pp_applyPremiumSubKindsButtonSurface
{
    if (!self.subKindsButton) {
        return;
    }

    [self pp_applyPremiumSelectorButton:self.subKindsButton
                            primaryText:self.lastSubKindsTitle ?: [self pp_currentSubKindsDisplayTitle]
                                caption:[self pp_subKindsSelectorCaption]
                             emphasized:[self pp_subKindsSelectorIsActive]];
}

- (NSString *)pp_centerCapsuleNavigationTitle
{
    NSString *mainTitle = [self pp_currentMainKindsDisplayTitle];
    NSString *subTitle = self.lastSubKindsTitle ?: [self pp_currentSubKindsDisplayTitle];

    if (mainTitle.length == 0) {
        return subTitle.length > 0 ? subTitle : (kLang(@"All") ?: @"All");
    }
    if (subTitle.length == 0) {
        return mainTitle;
    }

    return [NSString stringWithFormat:@"%@ • %@", mainTitle, subTitle];
}

- (void)pp_applyExperimentalCenterCapsuleAppearance
{
    if (!self.centerCapsuleButton) {
        return;
    }

    UIColor *accentColor = AppPrimaryClr ?: PPDataViewChromeTextColor();
    UIButtonConfiguration *configuration = self.centerCapsuleButton.configuration;
    if (!configuration) {
        configuration = [UIButtonConfiguration plainButtonConfiguration];
    }

    configuration.title = [self pp_centerCapsuleNavigationTitle];
    configuration.image = nil;
    configuration.imagePadding = 6.0;
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(4.0, 12.0, 4.0, 12.0);
    configuration.baseForegroundColor = PPDataViewChromeTextColor();
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.background.cornerRadius = 19.0;
    configuration.background.strokeWidth = 0.0;
    configuration.background.strokeColor = UIColor.clearColor;
    configuration.background.backgroundColor = [accentColor colorWithAlphaComponent:0.08];
    self.centerCapsuleButton.configuration = configuration;

    self.centerCapsuleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.centerCapsuleButton.accessibilityTraits = UIAccessibilityTraitButton;
    self.centerCapsuleButton.accessibilityLabel = configuration.title;
    [self.centerCapsuleButton invalidateIntrinsicContentSize];
    self.centerCapsuleButton.showsMenuAsPrimaryAction = YES;
    self.centerCapsuleButton.titleLabel.numberOfLines = 1;
    self.centerCapsuleButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.centerCapsuleButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.centerCapsuleButton.titleLabel.minimumScaleFactor = 0.84;
    self.centerCapsuleButton.titleLabel.adjustsFontForContentSizeCategory = YES;

    if (!PPIOS26()) {
        self.centerCapsuleButton.layer.cornerRadius = 19.0;
        self.centerCapsuleButton.clipsToBounds = YES;
    }
}

- (void)pp_syncExperimentalCenterCapsuleState
{
    if (!self.navContainerView) {
        return;
    }

    [self pp_applyExperimentalCenterCapsuleAppearance];

    BOOL showingCapsule = self.useCapsuleNavigation && self.centerCapsuleButton != nil;
    self.centerCapsuleButton.menu = self.subKindsButton.menu ?: [self subKindsMenu];
    self.KindsButton.hidden = showingCapsule;
    self.subKindsButton.hidden = showingCapsule;
    self.navSeparatorLine.hidden = showingCapsule;
    self.centerCapsuleButton.hidden = !showingCapsule;

    self.KindsButton.userInteractionEnabled = !showingCapsule;
    self.subKindsButton.userInteractionEnabled = !showingCapsule;
    self.centerCapsuleButton.userInteractionEnabled = showingCapsule;
    self.KindsButton.accessibilityElementsHidden = showingCapsule;
    self.subKindsButton.accessibilityElementsHidden = showingCapsule;
    self.centerCapsuleButton.accessibilityElementsHidden = !showingCapsule;

    if (self.centerCapsuleButton) {
        [self.navContainerView bringSubviewToFront:self.centerCapsuleButton];
    }
    if (self.cartButton) {
        [self.navContainerView bringSubviewToFront:self.cartButton];
    }
}

- (void)pp_applyPremiumNavigationChromeAppearance
{
    if (!self.navContainerView) {
        return;
    }

    self.navContainerView.backgroundColor = UIColor.clearColor;
    self.navContainerView.clipsToBounds = NO;
    self.navContainerView.layer.masksToBounds = NO;
    self.navContainerView.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    if (@available(iOS 13.0, *)) {
        self.navContainerView.overrideUserInterfaceStyle =
            PPDataViewCurrentAppInterfaceStyle(self.traitCollection);
    }
    CGFloat chromeRadius = CGRectGetHeight(self.navContainerView.bounds) > 0.0
        ? CGRectGetHeight(self.navContainerView.bounds) * 0.5
        : kPPDataViewNavigationChromeCornerRadius;
    self.navContainerView.layer.cornerRadius = chromeRadius;
    if (@available(iOS 13.0, *)) {
        self.navContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    for (UIView *subview in self.navContainerView.subviews) {
        if ([subview isKindOfClass:UIVisualEffectView.class]) {
            subview.layer.cornerRadius = chromeRadius;
            if (@available(iOS 13.0, *)) {
                subview.layer.cornerCurve = kCACornerCurveContinuous;
            }
        }
    }
    self.navContainerView.layer.borderWidth = 0.0;
    self.navContainerView.isAccessibilityElement = NO;
    [self.navContainerView pp_applyPremiumMaterialAnimated:NO];
    [self.navContainerView pp_applyDockedForegroundProgress:[self pp_dockedIslandSnapshotProgressForDockProgress:self.premiumHeaderDockProgress]
                                                   animated:NO];

    [self pp_applyPremiumMainKindsButtonSurface];
    [self pp_applyPremiumSubKindsButtonSurface];
    [self pp_syncExperimentalCenterCapsuleState];
    [self pp_applyPremiumNavIconButtonAppearance:self.cartButton emphasized:NO];
    [self pp_applyPremiumNavSearchButtonAppearance];
     [self pp_applyTemporaryHiddenCartButtonState];
}

- (void)pp_applyPremiumSectionsSegmentedAppearance
{
    if (!self.sectionsSegmentedControl) {
        return;
    }

    BOOL currentSectionHasFilters = [self sectionHasFilterChipBarForSection:self.viewModel.currentSection];
    NSInteger activeFilterCount = (self.filterStates && currentSectionHasFilters)
        ? [self pp_activeFilterCountForSection:self.viewModel.currentSection]
        : 0;
    [self.sectionsFiltersContainer pp_applyActiveFilterCount:activeFilterCount animated:NO];

    self.sectionsSegmentedControl.containerBackgroundColor = UIColor.clearColor;
    self.sectionsSegmentedControl.hidesContainerChrome = YES;
    UIColor *accentBase = [self pp_controlIslandContentAccentColor];
    if ([self pp_controlIslandUsesAccentColor]) {
        self.sectionsSegmentedControl.normalTextColor =
            PPDataViewBlendColor(PPDataViewChromeSecondaryTextColor(), accentBase, 0.36, self.traitCollection);
        self.sectionsSegmentedControl.selectedTextColor = accentBase;
    } else {
        self.sectionsSegmentedControl.normalTextColor = PPDataViewChromeSecondaryTextColor();
        self.sectionsSegmentedControl.selectedTextColor = PPDataViewChromeTextColor();
    }
    CGFloat h, s, b, a;
    if ([accentBase getHue:&h saturation:&s brightness:&b alpha:&a]) {
        self.sectionsSegmentedControl.selectedSegmentColor = [UIColor colorWithHue:h saturation:MIN(s * 1.12, 1.0) brightness:MIN(b * 1.06, 1.0) alpha:a];
    } else {
        self.sectionsSegmentedControl.selectedSegmentColor = accentBase;
    }
    self.sectionsSegmentedControl.normalFont = [GM MidFontWithSize:14.2];
    self.sectionsSegmentedControl.selectedFont = [GM boldFontWithSize:14.6];
    CGFloat segmentedRadius =
        PPDataViewPillRadiusForHeight(CGRectGetHeight(self.sectionsSegmentedControl.bounds),
                                      kPPDataViewSectionsSegmentedCornerRadius);
    self.sectionsSegmentedControl.layer.cornerRadius = segmentedRadius;
    self.sectionsSegmentedControl.layer.borderWidth = 0.0;
    [self.sectionsSegmentedControl pp_setBorderColor:UIColor.clearColor];
    [self.sectionsSegmentedControl pp_setShadowColor:UIColor.clearColor];
    self.sectionsSegmentedControl.layer.shadowOpacity = 0.0;
    self.sectionsSegmentedControl.layer.shadowRadius = 0.0;
    self.sectionsSegmentedControl.layer.shadowOffset = CGSizeZero;
    if (@available(iOS 13.0, *)) {
        self.sectionsSegmentedControl.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self pp_applyFilterContextBarAppearance];
}

- (CGFloat)pp_headerCollapseProgressForScrollView:(UIScrollView *)scrollView
{
    if (!scrollView || [self pp_isFullDetailsLayoutMode]) {
        return 0.0;
    }

    CGFloat topOrigin = -scrollView.adjustedContentInset.top;
    CGFloat travel = MAX(0.0, scrollView.contentOffset.y - topOrigin);
    if (travel <= 0.0) {
        return 0.0;
    }
    return MIN(1.0, travel / kPPDataViewHeaderCollapseDistance);
}

- (CGFloat)pp_headerDockProgressForCollapseProgress:(CGFloat)progress
{
    CGFloat normalized =
        (PPDataViewClamp01(progress) - kPPDataViewHeaderDockStartProgress) /
        MAX(0.01, 1.0 - kPPDataViewHeaderDockStartProgress);
    return PPDataViewSmoothstep(normalized);
}

- (CGRect)pp_navigationTitleDockRectInView
{
    if (!self.navContainerView ||
        !self.view ||
        !self.navContainerView.window ||
        !self.view.window ||
        self.navContainerView.window != self.view.window ||
        CGRectIsEmpty(self.navContainerView.bounds)) {
        return CGRectNull;
    }

    [self.view layoutIfNeeded];
    [self.navigationController.navigationBar layoutIfNeeded];
    [self.navContainerView layoutIfNeeded];

    CGRect targetRect = [self.navContainerView convertRect:self.navContainerView.bounds
                                                    toView:self.view];
    if (CGRectIsNull(targetRect) ||
        CGRectIsEmpty(targetRect) ||
        CGRectGetWidth(targetRect) <= 1.0 ||
        CGRectGetHeight(targetRect) <= 1.0) {
        return CGRectNull;
    }

    return CGRectInset(targetRect,
                       kPPDataViewHeaderDockTargetHorizontalInset,
                       kPPDataViewHeaderDockTargetVerticalInset);
}

- (CGAffineTransform)pp_controlIslandDockTransformForProgress:(CGFloat)dockProgress
                                                 reduceMotion:(BOOL)reduceMotion
{
    CGFloat progress = PPDataViewClamp01(dockProgress);
    if (progress <= 0.001) {
        return CGAffineTransformIdentity;
    }

    // Under Reduce Motion: translate toward the dock target without scale.
    // The island still reaches the nav bar, but the morph is suppressed.
    if (reduceMotion) {
        if (!self.sectionsFiltersContainer ||
            CGRectIsEmpty(self.sectionsFiltersContainer.bounds)) {
            return CGAffineTransformIdentity;
        }
        CGRect targetRect = [self pp_navigationTitleDockRectInView];
        if (CGRectIsNull(targetRect) || CGRectIsEmpty(targetRect)) {
            return CGAffineTransformMakeTranslation(0.0,
                kPPDataViewHeaderCollapsedYOffset * progress);
        }
        CGPoint islandCenter = self.sectionsFiltersContainer.center;
        CGPoint targetCenter = CGPointMake(CGRectGetMidX(targetRect),
                                           CGRectGetMidY(targetRect));
        return CGAffineTransformMakeTranslation(
            (targetCenter.x - islandCenter.x) * progress,
            (targetCenter.y - islandCenter.y) * progress);
    }

    if (!self.sectionsFiltersContainer ||
        CGRectIsEmpty(self.sectionsFiltersContainer.bounds)) {
        return CGAffineTransformIdentity;
    }

    CGRect targetRect = [self pp_navigationTitleDockRectInView];
    CGSize islandSize = self.sectionsFiltersContainer.bounds.size;
    if (CGRectIsNull(targetRect) ||
        CGRectIsEmpty(targetRect) ||
        islandSize.width <= 1.0 ||
        islandSize.height <= 1.0) {
        CGFloat fallbackScaleX =
            1.0 - ((1.0 - kPPDataViewHeaderCollapsedScaleX) * progress);
        CGFloat fallbackScaleY =
            1.0 - ((1.0 - kPPDataViewHeaderCollapsedScaleY) * progress);
        CGFloat fallbackYOffset = kPPDataViewHeaderCollapsedYOffset * progress;
        return CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, fallbackYOffset),
                                      fallbackScaleX,
                                      fallbackScaleY);
    }

    CGFloat targetScale =
        MIN(CGRectGetWidth(targetRect) / islandSize.width,
            CGRectGetHeight(targetRect) / islandSize.height);
    targetScale = MIN(kPPDataViewHeaderDockMaximumScale,
                      MAX(kPPDataViewHeaderDockMinimumScale, targetScale));
    CGFloat scale = 1.0 + ((targetScale - 1.0) * progress);

    CGPoint islandCenter = self.sectionsFiltersContainer.center;
    CGPoint targetCenter = CGPointMake(CGRectGetMidX(targetRect), CGRectGetMidY(targetRect));
    CGFloat translateX = (targetCenter.x - islandCenter.x) * progress;
    CGFloat translateY = (targetCenter.y - islandCenter.y) * progress;

    return CGAffineTransformScale(CGAffineTransformMakeTranslation(translateX, translateY),
                                  scale,
                                  scale);
}

- (void)pp_applyNavigationTitleDockProgress:(CGFloat)dockProgress
{
    CGFloat progress = PPDataViewClamp01(dockProgress);

    // The island is absorbed behind the navigation title. The title remains
    // the stable, readable owner before, during, and after the handoff.
    self.KindsButton.alpha = 1.0;
    self.subKindsButton.alpha = 1.0;
    self.centerCapsuleButton.alpha = 1.0;
    self.navSeparatorLine.alpha = 1.0;
    self.navContainerView.alpha = 1.0;
    CGFloat snapshotProgress = [self pp_dockedIslandSnapshotProgressForDockProgress:progress];
    self.sectionsFiltersContainer.layer.zPosition =
        snapshotProgress > 0.001 ? 0.0 : (progress > 0.01 ? 6.0 : 0.0);
    [self pp_promoteNavigationTitleContainerForDockProgress:progress
                                           snapshotProgress:snapshotProgress];
}

- (void)pp_promoteNavigationTitleContainerForDockProgress:(CGFloat)dockProgress
                                         snapshotProgress:(CGFloat)snapshotProgress
{
    if (!self.navContainerView) {
        return;
    }

    BOOL shouldPromote = dockProgress >= kPPDataViewHeaderDockSnapshotStartProgress ||
        snapshotProgress > 0.001;
    UIView *titleSuperview = self.navContainerView.superview;
    self.navContainerView.hidden = NO;
    self.navContainerView.alpha = 1.0;
    self.navContainerView.userInteractionEnabled = YES;

    if (self.navigationItem.titleView != self.navContainerView) {
        self.navigationItem.titleView = self.navContainerView;
    }

    if (shouldPromote) {
        if (titleSuperview) {
            titleSuperview.hidden = NO;
            titleSuperview.alpha = 1.0;
            [titleSuperview bringSubviewToFront:self.navContainerView];
            UIView *navigationBarContentView = titleSuperview.superview;
            if (navigationBarContentView) {
                [navigationBarContentView bringSubviewToFront:titleSuperview];
            }
            titleSuperview.layer.zPosition = 30.0;
        }

        self.navContainerView.layer.zPosition = 40.0;
        self.navDockedIslandSnapshotView.layer.zPosition = 0.0;
    } else {
        self.navContainerView.layer.zPosition = 0.0;
        titleSuperview.layer.zPosition = 0.0;
    }

    if (self.navDockedIslandSnapshotView) {
        [self.navContainerView bringSubviewToFront:self.KindsButton];
        [self.navContainerView bringSubviewToFront:self.navSeparatorLine];
        [self.navContainerView bringSubviewToFront:self.subKindsButton];
        [self.navContainerView bringSubviewToFront:self.centerCapsuleButton];
        [self.navContainerView bringSubviewToFront:self.cartButton];
    }
}

- (CGFloat)pp_dockedIslandSnapshotProgressForDockProgress:(CGFloat)dockProgress
{
    CGFloat normalized =
        (PPDataViewClamp01(dockProgress) - kPPDataViewHeaderDockSnapshotStartProgress) /
        MAX(0.01, 1.0 - kPPDataViewHeaderDockSnapshotStartProgress);
    return PPDataViewSmoothstep(normalized);
}

- (CGAffineTransform)pp_navigationTitleTransformForDockProgress:(CGFloat)dockProgress
                                           previousDockProgress:(CGFloat)previousDockProgress
                                                   reduceMotion:(BOOL)reduceMotion
{
    if (reduceMotion) {
        return CGAffineTransformIdentity;
    }

    CGFloat progress = PPDataViewClamp01(dockProgress);
    BOOL isUndocking = progress < previousDockProgress - 0.002;
    if (!isUndocking || previousDockProgress < kPPDataViewHeaderUndockedProgressThreshold) {
        return CGAffineTransformIdentity;
    }

    CGFloat releaseArc = sin(M_PI * progress);
    CGFloat scale = 1.0 - (kPPDataViewHeaderTitleUndockScaleDip * MAX(0.0, releaseArc));
    return CGAffineTransformMakeScale(scale, scale);
}

- (void)pp_updateDockedIslandSnapshotFrame
{
    if (!self.navDockedIslandSnapshotView || !self.navContainerView) {
        return;
    }

    CGRect frame = CGRectInset(self.navContainerView.bounds,
                               kPPDataViewHeaderDockTargetHorizontalInset,
                               kPPDataViewHeaderDockTargetVerticalInset);
    self.navDockedIslandSnapshotView.frame = frame;
    CGFloat radius = PPDataViewPillRadiusForHeight(CGRectGetHeight(frame),
                                                   kPPDataViewNavigationChromeCornerRadius);
    self.navDockedIslandSnapshotView.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        self.navDockedIslandSnapshotView.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

- (void)pp_installDockedIslandSnapshotIfNeeded
{
    if (!self.navContainerView ||
        !self.sectionsFiltersContainer ||
        CGRectIsEmpty(self.navContainerView.bounds) ||
        CGRectIsEmpty(self.sectionsFiltersContainer.bounds)) {
        return;
    }

    [self pp_updateDockedIslandSnapshotFrame];
    if (self.navDockedIslandSnapshotView) {
        return;
    }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:self.sectionsFiltersContainer.bounds.size
                                               format:format];
    UIImage *snapshotImage =
        [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        (void)rendererContext;
        [self.sectionsFiltersContainer drawViewHierarchyInRect:self.sectionsFiltersContainer.bounds
                                            afterScreenUpdates:NO];
    }];

    UIImageView *snapshotView = [[UIImageView alloc] initWithImage:snapshotImage];
    snapshotView.userInteractionEnabled = NO;
    snapshotView.clipsToBounds = YES;
    snapshotView.contentMode = UIViewContentModeScaleAspectFit;
    snapshotView.alpha = 0.0;
    snapshotView.accessibilityElementsHidden = YES;
    self.navDockedIslandSnapshotView = snapshotView;
    NSUInteger insertionIndex = MIN((NSUInteger)1, self.navContainerView.subviews.count);
    [self.navContainerView insertSubview:snapshotView atIndex:insertionIndex];
    [self.navContainerView bringSubviewToFront:self.KindsButton];
    [self.navContainerView bringSubviewToFront:self.navSeparatorLine];
    [self.navContainerView bringSubviewToFront:self.subKindsButton];
    [self.navContainerView bringSubviewToFront:self.centerCapsuleButton];
    [self.navContainerView bringSubviewToFront:self.cartButton];
    [self pp_updateDockedIslandSnapshotFrame];
}

- (void)pp_removeDockedIslandSnapshotAnimated:(BOOL)animated
{
    UIImageView *snapshotView = self.navDockedIslandSnapshotView;
    if (!snapshotView) {
        return;
    }

    self.navDockedIslandSnapshotView = nil;
    void (^removeBlock)(void) = ^{
        [snapshotView removeFromSuperview];
    };

    if (!animated || !snapshotView.window || UIAccessibilityIsReduceMotionEnabled()) {
        removeBlock();
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseOut
                     animations:^{
        snapshotView.alpha = 0.0;
        snapshotView.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:^(__unused BOOL finished) {
        removeBlock();
    }];
}

- (void)pp_runNavigationTitleDockHaloAnimation
{
    if (!self.navContainerView ||
        !self.navContainerView.window ||
        CGRectIsEmpty(self.navContainerView.bounds) ||
        UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    UIColor *accent = [self pp_controlIslandContentAccentColor] ?: PPDataViewAccentColor();
    CGFloat radius = PPDataViewPillRadiusForHeight(CGRectGetHeight(self.navContainerView.bounds),
                                                   kPPDataViewNavigationChromeCornerRadius);

    for (NSInteger index = 0; index < 2; index++) {
        CAShapeLayer *haloLayer = [CAShapeLayer layer];
        CGFloat haloOutset = index == 0 ? 7.0 : 12.0;
        haloLayer.frame = CGRectInset(self.navContainerView.bounds, -haloOutset, -haloOutset);
        CGRect haloBounds = haloLayer.bounds;
        haloLayer.path =
            [UIBezierPath bezierPathWithRoundedRect:CGRectInset(haloBounds, 1.0, 1.0)
                                       cornerRadius:radius + haloOutset].CGPath;
        haloLayer.fillColor = UIColor.clearColor.CGColor;
        haloLayer.strokeColor = [accent colorWithAlphaComponent:(index == 0 ? 0.30 : 0.18)].CGColor;
        haloLayer.lineWidth = index == 0 ? 1.20 : 0.85;
        haloLayer.opacity = 0.0;
        haloLayer.transform = CATransform3DMakeScale(0.94, 0.94, 1.0);
        [self.navContainerView.layer addSublayer:haloLayer];

        CAKeyframeAnimation *opacityAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        opacityAnimation.values = @[@0.0, @(index == 0 ? 0.34 : 0.20), @0.08, @0.0];
        opacityAnimation.keyTimes = @[@0.0, @0.18, @0.58, @1.0];

        CAKeyframeAnimation *scaleAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        scaleAnimation.values = @[@0.96, @1.035, @(index == 0 ? 1.22 : 1.30)];
        scaleAnimation.keyTimes = @[@0.0, @0.28, @1.0];

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[opacityAnimation, scaleAnimation];
        group.duration = index == 0 ? 0.28 : 0.30;
        group.beginTime = CACurrentMediaTime() + (index == 0 ? 0.0 : 0.035);
        group.timingFunction =
            [CAMediaTimingFunction functionWithControlPoints:0.18 :0.82 :0.24 :1.0];
        group.removedOnCompletion = YES;
        [haloLayer addAnimation:group forKey:@"pp.dataview.titleDockHalo"];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)((group.duration + (index == 0 ? 0.02 : 0.05)) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [haloLayer removeFromSuperlayer];
        });
    }
}

- (void)pp_updatePremiumHeaderCollapseForScrollView:(UIScrollView *)scrollView animated:(BOOL)animated
{
    if (scrollView != self.collectionView) {
        return;
    }

    [self pp_applyPremiumHeaderCollapseProgress:[self pp_headerCollapseProgressForScrollView:scrollView]
                                       animated:animated];
}

- (void)pp_applyPremiumHeaderCollapseProgress:(CGFloat)progress animated:(BOOL)animated
{
    CGFloat clampedProgress = MIN(MAX(progress, 0.0), 1.0);
    if (fabs(self.premiumHeaderCollapseProgress - clampedProgress) < 0.002) {
        CGFloat dockProgress = [self pp_headerDockProgressForCollapseProgress:clampedProgress];
        CGFloat snapshotProgress = [self pp_dockedIslandSnapshotProgressForDockProgress:dockProgress];
        [self pp_updateDockedIslandSnapshotFrame];
        [self.navContainerView pp_applyDockedForegroundProgress:snapshotProgress animated:animated];
        [self pp_applyNavigationTitleDockProgress:dockProgress];
        return;
    }

    self.premiumHeaderCollapseProgress = clampedProgress;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    BOOL canAnimate = animated && self.view.window != nil && !reduceMotion;

    CGFloat previousDockProgress = self.premiumHeaderDockProgress;
    CGFloat dockProgress = [self pp_headerDockProgressForCollapseProgress:clampedProgress];
    CGFloat snapshotProgress = [self pp_dockedIslandSnapshotProgressForDockProgress:dockProgress];
    BOOL shouldInstallSnapshot = snapshotProgress > 0.001;
    BOOL didReachDock = !self.premiumHeaderIsDocked &&
        dockProgress >= kPPDataViewHeaderDockedProgressThreshold;
    BOOL didLeaveDock = self.premiumHeaderIsDocked &&
        dockProgress <= kPPDataViewHeaderUndockedProgressThreshold;

    if (shouldInstallSnapshot) {
        [self pp_installDockedIslandSnapshotIfNeeded];
        [self pp_updateDockedIslandSnapshotFrame];
    } else {
        [self pp_removeDockedIslandSnapshotAnimated:animated];
    }

    CGAffineTransform islandTransform =
        [self pp_controlIslandDockTransformForProgress:dockProgress
                                          reduceMotion:reduceMotion];
    CGAffineTransform titleTransform =
        [self pp_navigationTitleTransformForDockProgress:dockProgress
                                    previousDockProgress:previousDockProgress
                                            reduceMotion:reduceMotion];
    CGFloat searchScale = reduceMotion ? 1.0 : (1.0 - (0.020 * clampedProgress));
    CGAffineTransform searchTransform = CGAffineTransformMakeScale(searchScale, searchScale);
    CGFloat contextAlpha = MAX(0.0, 1.0 - (1.35 * dockProgress));
    CGAffineTransform contextTransform = reduceMotion
        ? CGAffineTransformIdentity
        : CGAffineTransformMakeTranslation(0.0, -10.0 * dockProgress);
    CGFloat islandPresentationAlpha = MAX(0.0, 1.0 - snapshotProgress);
    CGFloat snapshotHandoffAlpha = sin(M_PI * snapshotProgress);

    void (^updates)(void) = ^{
        if (self.sectionsFiltersContainer) {
            if (self.didRunSectionsSegmentedEntrance || self.sectionsFiltersContainer.alpha > 0.5) {
                self.sectionsFiltersContainer.transform = islandTransform;
                self.sectionsFiltersContainer.alpha = islandPresentationAlpha;
            }
            self.sectionsFiltersContainer.userInteractionEnabled = snapshotProgress < 0.94;
            self.sectionsFiltersContainer.accessibilityElementsHidden = snapshotProgress >= 0.94;
            [self.sectionsFiltersContainer pp_applyScrollCollapseProgress:clampedProgress animated:NO];
        }
        if (self.navDockedIslandSnapshotView) {
            [self pp_updateDockedIslandSnapshotFrame];
            self.navDockedIslandSnapshotView.alpha = snapshotHandoffAlpha;
            self.navDockedIslandSnapshotView.transform =
                reduceMotion
                ? CGAffineTransformIdentity
                : CGAffineTransformMakeScale(0.986 + (0.014 * snapshotProgress),
                                              0.982 + (0.018 * snapshotProgress));
        }
        self.filterContextBar.alpha = contextAlpha;
        self.filterContextBar.transform = contextTransform;
        self.navContainerView.transform = titleTransform;
        [self.navContainerView pp_applyDockedForegroundProgress:snapshotProgress animated:canAnimate];
        [self pp_applyNavigationTitleDockProgress:dockProgress];
        self.navSearchActionsButton.transform = searchTransform;
        [self pp_updatePremiumChromeShadowPaths];
    };

    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        if (didReachDock) {
            [self pp_runNavigationTitleDockHaloAnimation];
        }
        [self pp_applyNavigationTitleDockProgress:dockProgress];
    };

    if (canAnimate) {
        [UIView animateWithDuration:0.28
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionCurveEaseOut
                         animations:updates
                         completion:completion];
    } else {
        updates();
        completion(YES);
    }

    self.premiumHeaderDockProgress = dockProgress;
    if (didReachDock) {
        self.premiumHeaderIsDocked = YES;
    } else if (didLeaveDock) {
        self.premiumHeaderIsDocked = NO;
    }
}

- (BOOL)pp_controlIslandUsesAccentColor
{
    return self.sectionsFiltersContainer.useAccentColor;
}

- (UIColor *)pp_controlIslandAccentColor
{
    return self.input.accentColor ?: PPDataViewAccentColor();
}

- (UIColor *)pp_controlIslandContentAccentColor
{
    if ([self pp_controlIslandUsesAccentColor]) {
        return [self pp_controlIslandAccentColor];
    }
    return PPDataViewProviderPillAccentColor(self.traitCollection);
}

- (void)pp_applyFilterContextBarAppearance
{
    if (!self.filterContextBar) {
        return;
    }

    BOOL darkMode = PPDataViewCurrentAppAppearanceIsDark(self.traitCollection);
    UIColor *accent = [self pp_controlIslandContentAccentColor];
    BOOL useIslandAccent = [self pp_controlIslandUsesAccentColor];
    UIColor *surface = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.54],
                                             [UIColor colorWithWhite:1.0 alpha:0.075]);
    UIColor *badgeSurface = PPDataViewBlendColor(surface,
                                                accent,
                                                darkMode ? 0.18 : 0.055,
                                                self.traitCollection);
    UIColor *stroke = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.62],
                                             [UIColor colorWithWhite:1.0 alpha:0.14]);

    self.filterContextBar.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.filterContextBar.backgroundColor = badgeSurface;
    CGFloat contextRadius = PPDataViewPillRadiusForHeight(kPPFilterContextBarHeight, 16.0);
    self.filterContextBar.layer.cornerRadius = contextRadius;
    self.filterContextBar.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.filterContextBar.layer.borderColor = PPDataViewResolvedColor(stroke, self.traitCollection).CGColor;
    self.filterContextBar.layer.shadowColor = [accent colorWithAlphaComponent:0.24].CGColor;
    self.filterContextBar.layer.shadowOpacity = darkMode ? 0.075 : 0.045;
    self.filterContextBar.layer.shadowRadius = 9.0;
    self.filterContextBar.layer.shadowOffset = CGSizeMake(0.0, 3.0);

    if (@available(iOS 13.0, *)) {
        self.filterContextBar.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.filterContextBadgeView.backgroundColor = AppClearClr;//badgeSurface
    self.filterContextBadgeView.layer.cornerRadius = kPPFilterContextBadgeHeight * 0.5;
    self.filterContextBadgeView.layer.borderWidth = 0.0 / UIScreen.mainScreen.scale;
    self.filterContextBadgeView.layer.borderColor =
        PPDataViewResolvedColor([UIColor.whiteColor colorWithAlphaComponent:darkMode ? 0.14 : 0.78],
                                self.traitCollection).CGColor;
    if (@available(iOS 13.0, *)) {
        self.filterContextBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.filterContextIconView.tintColor = accent;
    self.filterContextLabel.textColor = PPDataViewChromeTextColor();
    self.filterContextLabel.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:([GM boldFontWithSize:12.2] ?: [UIFont systemFontOfSize:12.2 weight:UIFontWeightSemibold])
                                                                                   maximumPointSize:14.0];
    self.filterContextLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.filterCollapseButton.tintColor = useIslandAccent
        ? accent
        : PPDataViewAccentColor();

    if (self.providerFilterChipButton) {
        BOOL dark = PPDataViewCurrentAppAppearanceIsDark(self.traitCollection);
        UIColor *chipSurface = PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.84],
                                                     [UIColor colorWithWhite:1.0 alpha:0.105]);
        if (useIslandAccent) {
            chipSurface = PPDataViewBlendColor(chipSurface,
                                               accent,
                                               dark ? 0.24 : 0.12,
                                               self.traitCollection);
        }
        UIColor *chipStroke = PPDataViewBlendColor(chipSurface,
                                                  accent,
                                                  dark ? 0.26 : 0.18,
                                                  self.traitCollection);
        UIColor *primaryTextColor = PPDataViewChromeTextColor();
        UIColor *secondaryTextColor = PPDataViewChromeSecondaryTextColor();
        self.providerFilterChipButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        self.providerFilterChipButton.tintColor = primaryTextColor;
        self.providerFilterChipButton.backgroundColor = chipSurface;
        CGFloat providerChipRadius = PPDataViewPillRadiusForHeight(kPPProviderFilterChipHeight, 18.0);
        self.providerFilterChipButton.layer.cornerRadius = providerChipRadius;
        self.providerFilterChipButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.providerFilterChipButton.layer.borderColor = PPDataViewResolvedColor(chipStroke, self.traitCollection).CGColor;
        self.providerFilterChipButton.layer.shadowColor = [accent colorWithAlphaComponent:0.32].CGColor;
        self.providerFilterChipButton.layer.shadowOpacity = dark ? 0.08 : 0.055;
        self.providerFilterChipButton.layer.shadowRadius = 10.0;
        self.providerFilterChipButton.layer.shadowOffset = CGSizeMake(0.0, 4.0);
        if (@available(iOS 13.0, *)) {
            self.providerFilterChipButton.layer.cornerCurve = kCACornerCurveContinuous;
        }
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *configuration = self.providerFilterChipButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
            configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            configuration.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
            configuration.image = nil;
            configuration.imagePadding = 0.0;
            configuration.title = @"";
            configuration.subtitle = @"";
            configuration.baseForegroundColor = primaryTextColor;
            configuration.background.backgroundColor = UIColor.clearColor;
            configuration.background.cornerRadius = providerChipRadius;
            configuration.background.strokeColor = UIColor.clearColor;
            configuration.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
                NSMutableDictionary *attributes = [incoming mutableCopy];
                attributes[NSFontAttributeName] = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
                attributes[NSForegroundColorAttributeName] = primaryTextColor;
                return attributes;
            };
            configuration.subtitleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
                NSMutableDictionary *attributes = [incoming mutableCopy];
                attributes[NSFontAttributeName] = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
                attributes[NSForegroundColorAttributeName] = secondaryTextColor;
                return attributes;
            };
            self.providerFilterChipButton.configuration = configuration;
        } else {
            [self.providerFilterChipButton setTitleColor:primaryTextColor forState:UIControlStateNormal];
            [self.providerFilterChipButton setImage:nil forState:UIControlStateNormal];
            [self.providerFilterChipButton setTitle:@"" forState:UIControlStateNormal];
            self.providerFilterChipButton.contentEdgeInsets = UIEdgeInsetsZero;
            self.providerFilterChipButton.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
        }
        self.providerFilterChipTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
        self.providerFilterChipTitleLabel.textColor = primaryTextColor;
        self.providerFilterChipTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        self.providerFilterChipRatingLabel.font = [GM boldFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
        self.providerFilterChipRatingLabel.textColor = primaryTextColor;
        self.providerFilterChipRatingLabel.backgroundColor =
            PPDataViewBlendColor(chipSurface, accent, dark ? 0.30 : 0.13, self.traitCollection);
        self.providerFilterChipRatingLabel.layer.cornerRadius = 9.0;
        self.providerFilterChipRatingLabel.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.providerFilterChipRatingLabel.layer.borderColor =
            PPDataViewResolvedColor([accent colorWithAlphaComponent:dark ? 0.30 : 0.18],
                                    self.traitCollection).CGColor;
        self.providerFilterChipRatingLabel.clipsToBounds = YES;
        self.providerFilterChipSubtitleLabel.font = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        self.providerFilterChipSubtitleLabel.textColor = secondaryTextColor;
        self.providerFilterChipSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        self.providerFilterChipAvatarView.backgroundColor =
            PPDataViewBlendColor(chipSurface, accent, dark ? 0.20 : 0.12, self.traitCollection);
        self.providerFilterChipAvatarView.tintColor = accent;
        NSString *selectedProviderID = [self selectedProviderIDForSection:self.viewModel.currentSection];
        self.providerFilterChipAvatarView.layer.cornerRadius = selectedProviderID.length > 0
            ? kPPProviderFilterChipAvatarDiameter * 0.5
            : 11.0;
        self.providerFilterChipAvatarView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.providerFilterChipAvatarView.layer.borderColor =
            PPDataViewResolvedColor([UIColor.whiteColor colorWithAlphaComponent:dark ? 0.12 : 0.78],
                                    self.traitCollection).CGColor;
        self.providerFilterChipAvatarView.clipsToBounds = YES;
        self.providerFilterChipTrailingIconView.backgroundColor =
            PPDataViewBlendColor(chipSurface, accent, dark ? 0.24 : 0.14, self.traitCollection);
        self.providerFilterChipTrailingIconView.tintColor = selectedProviderID.length > 0
            ? [UIColor colorWithRed:0.31 green:0.86 blue:0.57 alpha:1.0]
            : accent;
        self.providerFilterChipTrailingIconView.layer.cornerRadius = kPPProviderFilterChipTrailingIconDiameter * 0.5;
        self.providerFilterChipTrailingIconView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.providerFilterChipTrailingIconView.layer.borderColor =
            PPDataViewResolvedColor([UIColor.whiteColor colorWithAlphaComponent:dark ? 0.10 : 0.70],
                                    self.traitCollection).CGColor;
        self.providerFilterChipTrailingIconView.clipsToBounds = YES;
    }
}

- (void)pp_updatePremiumChromeShadowPaths
{
    if (self.navContainerView && !CGRectIsEmpty(self.navContainerView.bounds)) {
        CGFloat radius = CGRectGetHeight(self.navContainerView.bounds) > 0.0
            ? CGRectGetHeight(self.navContainerView.bounds) * 0.5
            : kPPDataViewNavigationChromeCornerRadius;
        self.navContainerView.layer.cornerRadius = radius;
        for (UIView *subview in self.navContainerView.subviews) {
            if ([subview isKindOfClass:UIVisualEffectView.class]) {
                subview.layer.cornerRadius = radius;
                if (@available(iOS 13.0, *)) {
                    subview.layer.cornerCurve = kCACornerCurveContinuous;
                }
            }
        }
        self.navContainerView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.navContainerView.bounds
                                   cornerRadius:radius].CGPath;
    }

    if (self.sectionsFiltersContainer && !CGRectIsEmpty(self.sectionsFiltersContainer.bounds)) {
        CGFloat islandRadius = self.sectionsFiltersContainer.layer.cornerRadius > 0.0
            ? self.sectionsFiltersContainer.layer.cornerRadius
            : kPPDataViewSectionsIslandCornerRadius;
        self.sectionsFiltersContainer.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.sectionsFiltersContainer.bounds
                                   cornerRadius:islandRadius].CGPath;
    }

    if (self.sectionsSegmentedControl && !CGRectIsEmpty(self.sectionsSegmentedControl.bounds)) {
        CGFloat radius =
            PPDataViewPillRadiusForHeight(CGRectGetHeight(self.sectionsSegmentedControl.bounds),
                                          kPPDataViewSectionsSegmentedCornerRadius);
        self.sectionsSegmentedControl.layer.cornerRadius = radius;
        self.sectionsSegmentedControl.layer.shadowPath = nil;
    }

    if (self.filterContextBar && !CGRectIsEmpty(self.filterContextBar.bounds)) {
        CGFloat radius = MIN(18.0, PPDataViewPillRadiusForHeight(CGRectGetHeight(self.filterContextBar.bounds), 18.0));
        self.filterContextBar.layer.cornerRadius = radius;
        self.filterContextBar.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.filterContextBar.bounds
                                       cornerRadius:radius].CGPath;
    }

    if (self.providerFilterChipButton && !CGRectIsEmpty(self.providerFilterChipButton.bounds)) {
        CGFloat radius = self.providerFilterChipButton.layer.cornerRadius > 0.0
            ? self.providerFilterChipButton.layer.cornerRadius
            : PPDataViewPillRadiusForHeight(CGRectGetHeight(self.providerFilterChipButton.bounds), 18.0);
        self.providerFilterChipButton.layer.cornerRadius = radius;
        self.providerFilterChipButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.providerFilterChipButton.bounds
                                   cornerRadius:radius].CGPath;
    }


    UIButton *navCartButton = self.navCartButton;
    if (navCartButton && !CGRectIsEmpty(navCartButton.bounds)) {
        CGFloat radius = CGRectGetHeight(navCartButton.bounds) * 0.5;
        navCartButton.layer.cornerRadius = radius;
        navCartButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:navCartButton.bounds cornerRadius:radius].CGPath;
    }


    if (self.KindsButton && !CGRectIsEmpty(self.KindsButton.bounds)) {
        CGFloat radius = CGRectGetHeight(self.KindsButton.bounds) * 0.5;
        self.KindsButton.layer.cornerRadius = radius;
        self.KindsButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.KindsButton.bounds cornerRadius:radius].CGPath;
    }

    if (self.subKindsButton && !CGRectIsEmpty(self.subKindsButton.bounds)) {
        CGFloat radius = CGRectGetHeight(self.subKindsButton.bounds) * 0.5;
        self.subKindsButton.layer.cornerRadius = radius;
        self.subKindsButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.subKindsButton.bounds cornerRadius:radius].CGPath;
    }

    if (self.centerCapsuleButton && !CGRectIsEmpty(self.centerCapsuleButton.bounds)) {
        CGFloat radius = CGRectGetHeight(self.centerCapsuleButton.bounds) * 0.5;
        self.centerCapsuleButton.layer.cornerRadius = radius;
        self.centerCapsuleButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.centerCapsuleButton.bounds cornerRadius:radius].CGPath;
    }

    if (self.cartButton && !CGRectIsEmpty(self.cartButton.bounds)) {
        CGFloat radius = CGRectGetHeight(self.cartButton.bounds) * 0.5;
        self.cartButton.layer.cornerRadius = radius;
        self.cartButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cartButton.bounds cornerRadius:radius].CGPath;
    }

    UIButton *searchButton = self.navSearchActionsButton;
    if (searchButton && !CGRectIsEmpty(searchButton.bounds)) {
        CGFloat radius = CGRectGetHeight(searchButton.bounds) * 0.5;
        searchButton.layer.cornerRadius = radius;
        searchButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:searchButton.bounds cornerRadius:radius].CGPath;
    }
}

- (BOOL)pp_allowsPremiumMotion
{
    return self.view.window != nil && !UIAccessibilityIsReduceMotionEnabled();
}

- (void)pp_beginMotionTransition:(PPDataViewMotionReason)reason direction:(NSInteger)direction
{
    if (reason == PPDataViewMotionReasonNone) {
        return;
    }

    self.pendingMotionReason = reason;
    self.pendingMotionDirection = (direction > 0) ? 1 : ((direction < 0) ? -1 : 0);
    self.isAwaitingTransitionData = YES;
}

- (NSInteger)pp_directionForSubKindID:(NSInteger)newSubKindID comparedToCurrentSubKindID:(NSInteger)currentSubKindID
{
    if (newSubKindID == currentSubKindID) {
        return 0;
    }

    NSArray<SubKindModel *> *subKinds = self.input.mainKind.SubKindsArray ?: @[];
    NSInteger newIndex = (newSubKindID == 0) ? 0 : NSNotFound;
    NSInteger currentIndex = (currentSubKindID == 0) ? 0 : NSNotFound;

    for (NSInteger idx = 0; idx < (NSInteger)subKinds.count; idx++) {
        SubKindModel *candidate = subKinds[idx];
        NSInteger resolvedIndex = idx + 1; // Reserve 0 for the "All" state.
        if (candidate.ID == newSubKindID) {
            newIndex = resolvedIndex;
        }
        if (candidate.ID == currentSubKindID) {
            currentIndex = resolvedIndex;
        }
    }

    if (newIndex == NSNotFound || currentIndex == NSNotFound) {
        return (newSubKindID > currentSubKindID) ? 1 : -1;
    }

    if (newIndex == currentIndex) {
        return 0;
    }

    return (newIndex > currentIndex) ? 1 : -1;
}

- (void)pp_applyNavigationChangeAnimationToButton:(UIButton *)button updates:(dispatch_block_t)updates
{
    if (!button || !updates) {
        if (updates) {
            updates();
        }
        return;
    }

    if (![self pp_allowsPremiumMotion]) {
        updates();
        return;
    }

    [UIView transitionWithView:button
                      duration:0.24
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionBeginFromCurrentState |
                               UIViewAnimationOptionAllowUserInteraction
                    animations:updates
                    completion:nil];
}

- (void)pp_applyFeedbackPulseToView:(UIView *)view
{
    if (!view) {
        return;
    }

    [view.layer removeAllAnimations];
    if (![self pp_allowsPremiumMotion]) {
        view.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        view.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.38
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionCurveEaseInOut |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_prepareSectionsSegmentedEntranceInitialState
{
    if (!self.sectionsFiltersContainer) {
        return;
    }

    CGAffineTransform startTransform =
        CGAffineTransformTranslate(CGAffineTransformIdentity, 0.0, -12.0);
    startTransform = CGAffineTransformScale(startTransform, 0.985, 0.985);

    self.sectionsFiltersContainer.alpha = 0.0;
    self.sectionsFiltersContainer.transform = startTransform;
    self.sectionsSegmentedControl.userInteractionEnabled = NO;
}

- (void)pp_setSectionsSegmentedEntranceVisibleWithoutAnimation
{
    self.sectionsFiltersContainer.alpha = 1.0;
    self.sectionsFiltersContainer.transform = CGAffineTransformIdentity;
    self.sectionsSegmentedControl.userInteractionEnabled = YES;
    [self pp_updatePremiumHeaderCollapseForScrollView:self.collectionView animated:NO];
}

- (void)pp_runSectionsSegmentedEntranceIfNeeded
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_runSectionsSegmentedEntranceIfNeeded];
        });
        return;
    }

    if (self.didRunSectionsSegmentedEntrance || !self.sectionsFiltersContainer) {
        return;
    }

    self.didRunSectionsSegmentedEntrance = YES;

    if (![self pp_allowsPremiumMotion]) {
        [self pp_setSectionsSegmentedEntranceVisibleWithoutAnimation];
        return;
    }

    [self.sectionsFiltersContainer.layer removeAllAnimations];
    self.sectionsSegmentedControl.userInteractionEnabled = NO;

    [UIView animateWithDuration:0.46
                          delay:0.04
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.10
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.sectionsFiltersContainer.alpha = 1.0;
        self.sectionsFiltersContainer.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        self.sectionsSegmentedControl.userInteractionEnabled = YES;
        [self pp_updatePremiumHeaderCollapseForScrollView:self.collectionView animated:NO];
    }];
}

- (NSArray<UICollectionViewCell *> *)pp_sortedVisibleCollectionCells
{
    if (!self.collectionView) {
        return @[];
    }

    return [self.collectionView.visibleCells sortedArrayUsingComparator:^NSComparisonResult(UICollectionViewCell * _Nonnull firstCell, UICollectionViewCell * _Nonnull secondCell) {
        NSIndexPath *firstIndexPath = [self.collectionView indexPathForCell:firstCell];
        NSIndexPath *secondIndexPath = [self.collectionView indexPathForCell:secondCell];
        if (!firstIndexPath || !secondIndexPath) {
            return NSOrderedSame;
        }
        if (firstIndexPath.section != secondIndexPath.section) {
            return (firstIndexPath.section < secondIndexPath.section) ? NSOrderedAscending : NSOrderedDescending;
        }
        if (firstIndexPath.item == secondIndexPath.item) {
            return NSOrderedSame;
        }
        return (firstIndexPath.item < secondIndexPath.item) ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (NSString *)pp_cellAnimationKeyForIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath) {
        return @"";
    }

    return [NSString stringWithFormat:@"%ld.%ld.%ld",
            (long)self.cellEntranceAnimationGeneration,
            (long)indexPath.section,
            (long)indexPath.item];
}

- (void)pp_prepareCellEntranceAnimationsForReason:(PPDataViewMotionReason)reason direction:(NSInteger)direction
{
    self.cellEntranceAnimationGeneration += 1;
    [self.animatedCellEntranceKeys removeAllObjects];
    self.pendingCellEntranceMotionReason = reason;
    self.pendingCellEntranceDirection = (direction > 0) ? 1 : ((direction < 0) ? -1 : 0);
    self.pendingCellEntranceAnimationLimit = (reason == PPDataViewMotionReasonNone)
        ? 0
        : MIN((NSInteger)self.presentedItems.count, kPPPremiumVisibleCellAnimationLimit);
}

- (void)pp_animatePreparedVisibleCellsIfNeeded
{
    if (self.pendingCellEntranceAnimationLimit <= 0 || ![self pp_allowsPremiumMotion]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView layoutIfNeeded];
        for (UICollectionViewCell *cell in [self pp_sortedVisibleCollectionCells]) {
            NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
            [self pp_animateCellIfNeeded:cell atIndexPath:indexPath];
        }
    });
}

- (void)pp_animateCellIfNeeded:(UICollectionViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if ([self pp_isFullDetailsLayoutMode]) {
        return;
    }
    if (!cell || !indexPath || self.pendingCellEntranceAnimationLimit <= 0) {
        return;
    }

    if (indexPath.item >= self.pendingCellEntranceAnimationLimit) {
        return;
    }

    NSString *key = [self pp_cellAnimationKeyForIndexPath:indexPath];
    if (key.length == 0 || [self.animatedCellEntranceKeys containsObject:key]) {
        return;
    }
    [self.animatedCellEntranceKeys addObject:key];

    if (![self pp_allowsPremiumMotion]) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat directionX = 0.0;
    if (self.pendingCellEntranceMotionReason == PPDataViewMotionReasonSectionChange) {
        directionX = (CGFloat)self.pendingCellEntranceDirection * kPPPremiumCellSectionEntranceXOffset;
    } else if (self.pendingCellEntranceMotionReason == PPDataViewMotionReasonMainKindChange) {
        directionX = (CGFloat)self.pendingCellEntranceDirection * 10.0;
    }

    CGFloat directionY = kPPPremiumCellBaseEntranceYOffset + (CGFloat)MIN((NSInteger)indexPath.item, 4) * 3.0;
    if (self.pendingCellEntranceMotionReason == PPDataViewMotionReasonInitialLoad) {
        directionY += 6.0;
    }

    CGAffineTransform startTransform = CGAffineTransformTranslate(CGAffineTransformIdentity,
                                                                  directionX,
                                                                  directionY);
    startTransform = CGAffineTransformScale(startTransform, 0.985, 0.985);

    cell.alpha = 0.0;
    cell.transform = startTransform;

    NSTimeInterval delay = MIN((NSTimeInterval)indexPath.item * 0.035, 0.28);
    [UIView animateWithDuration:0.50
                          delay:delay
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_applyPresentedItemsAnimated:(BOOL)animated
                           scrollToTop:(BOOL)scrollToTop
                          motionReason:(PPDataViewMotionReason)motionReason
                       motionDirection:(NSInteger)motionDirection
{
    BOOL shouldUsePremiumTransition =
        motionReason != PPDataViewMotionReasonNone &&
        animated &&
        !self.isShowingSkeleton &&
        self.presentedItems.count <= 120 &&
        [self pp_allowsPremiumMotion];

    if (shouldUsePremiumTransition) {
        [self pp_performPremiumContentTransitionForReason:motionReason
                                          motionDirection:motionDirection
                                              scrollToTop:scrollToTop];
        return;
    }

    self.layoutManager.items = self.presentedItems;
    [self applySnapshotAnimated:animated];
    [self refreshFilterChipTitles];
    [self pp_prepareCellEntranceAnimationsForReason:motionReason direction:motionDirection];
    [self pp_animatePreparedVisibleCellsIfNeeded];

    if (scrollToTop) {
        [self scrollCollectionViewToTopAfterReload:YES];
    }

    [self updateEmptyState];
}

- (void)pp_performPremiumContentTransitionForReason:(PPDataViewMotionReason)motionReason
                                    motionDirection:(NSInteger)motionDirection
                                        scrollToTop:(BOOL)scrollToTop
{
    NSArray<UICollectionViewCell *> *outgoingCells = [self pp_sortedVisibleCollectionCells];
    if (outgoingCells.count == 0 || self.isPerformingCrossFade) {
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        [self refreshFilterChipTitles];
        [self pp_prepareCellEntranceAnimationsForReason:motionReason direction:motionDirection];
        [self pp_animatePreparedVisibleCellsIfNeeded];
        if (scrollToTop) {
            [self scrollCollectionViewToTopAfterReload:YES];
        }
        [self updateEmptyState];
        return;
    }

    self.isPerformingCrossFade = YES;
    self.collectionView.userInteractionEnabled = NO;

    CGFloat normalizedDirection = (motionDirection > 0) ? 1.0 : ((motionDirection < 0) ? -1.0 : 0.0);
    CGFloat exitX = (motionReason == PPDataViewMotionReasonSectionChange) ? (-normalizedDirection * 14.0) : 0.0;
    CGFloat exitY = (motionReason == PPDataViewMotionReasonMainKindChange) ? -16.0 : -10.0;

    [UIView animateKeyframesWithDuration:0.18
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionBeginFromCurrentState |
                                         UIViewAnimationOptionAllowUserInteraction |
                                         UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
        [outgoingCells enumerateObjectsUsingBlock:^(UICollectionViewCell * _Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
            NSTimeInterval relativeStart = MIN((NSTimeInterval)idx * 0.03, 0.12) / 0.18;
            [UIView addKeyframeWithRelativeStartTime:relativeStart
                                    relativeDuration:0.86
                                          animations:^{
                CGFloat stagedY = exitY - (CGFloat)MIN((NSInteger)idx, 4) * 2.0;
                CGAffineTransform transition = CGAffineTransformTranslate(CGAffineTransformIdentity,
                                                                          exitX,
                                                                          stagedY);
                cell.transform = CGAffineTransformScale(transition, 0.985, 0.985);
                cell.alpha = 0.0;
            }];
        }];
    } completion:^(__unused BOOL finished) {
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        [self.collectionView layoutIfNeeded];
        [self refreshFilterChipTitles];
        [self pp_prepareCellEntranceAnimationsForReason:motionReason direction:motionDirection];
        [self pp_animatePreparedVisibleCellsIfNeeded];

        if (scrollToTop) {
            [self scrollCollectionViewToTopAfterReload:YES];
        }

        self.collectionView.userInteractionEnabled = YES;
        self.isPerformingCrossFade = NO;
        [self updateEmptyState];
    }];
}


- (void)pp_handleAdDidUpload:(NSNotification *)note
{
    PetAd *ad = note.userInfo[@"ad"];
    BOOL isEditing = [note.userInfo[@"isEditing"] boolValue];

    PPDataViewLog(@"🔔 [PPDataViewVC] Ad %@ %@ notification received",
          ad.adID,
          isEditing ? @"UPDATED" : @"CREATED");

    // ✅ Only react if we are currently on Ads section
    if (self.viewModel.currentSection != PPDataSectionAds) {
        PPDataViewLog(@"ℹ️ [PPDataViewVC] Ignored (current section is not Ads)");
        return;
    }

    PPDataViewLog(@"🔄 [PPDataViewVC] Reloading Ads section");

    // Optional: show skeleton only if list is empty
    if (self.layoutManager.items.count == 0) {
        [self showSkeleton];
    }

    // 🔥 Reload Ads data from ViewModel
    [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {

        PPDataViewLog(@"✅ [PPDataViewVC] Ads reload finished");

        // Scroll to top ONLY if new ad was created
        if (!isEditing) {
            [self scrollCollectionViewToTopAfterReload:YES];
        }
    }];
}


- (void)normalizeInitialMainKind
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        if (!self.input.mainKind && self.input.mainKindsArr.count > 0) {
            self.input.mainKind = self.input.mainKindsArr.firstObject;
        }
    }
}

- (void)emptyStateInit
{
    self.emptyStateConfig = [PPEmptyStateConfig new];
    self.emptyStateConfig.animationName = @"404.json";
    self.emptyStateConfig.title      = kLang(@"empty_no_results_title");
    self.emptyStateConfig.subTitle  = kLang(@"empty_no_results_subtitle");
    self.emptyStateConfig.buttonTitle  = kLang(@"empty_retry_button");
    self.emptyStateConfig.target       = self;
    self.emptyStateConfig.action       = @selector(retryReloadData);
    self.emptyStateConfig.isNetworkFile = YES;
    self.didInitialReload = NO;
    self.scrollOffsetsBySection = [NSMutableDictionary dictionary];
}

#pragma mark - Routing
- (void)handleInitialRoute
{
    os_signpost_event_emit(PPDataViewVCPerformanceLog(), OS_SIGNPOST_ID_EXCLUSIVE,
                           "DataViewRouteStart", "sourceTarget=%ld", (long)self.input.sourceTarget);
    PPDataViewLog(@"\n================ handleInitialRoute =================");
    PPDataViewLog(@"[VC] sourceTarget = %ld", (long)self.input.sourceTarget);

    NSString *key =
    [self sectionKeyForMainKind:
     (self.input.sourceTarget == PPDeepLinkTargetAllCategories)
     ? nil
     : self.input.mainKind];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    PPDataSection section;

    if ([self.input.initialSectionOverride respondsToSelector:@selector(integerValue)]) {
        section = (PPDataSection)self.input.initialSectionOverride.integerValue;
        PPDataViewLog(@"[Route] Forced section %ld from input override", (long)section);
    } else if ([defaults objectForKey:key] != nil) {
        section = (PPDataSection)[defaults integerForKey:key];
        PPDataViewLog(@"[Route] Restored section %ld for key %@", (long)section, key);
    } else {
        section = PPDataSectionAds;
        PPDataViewLog(@"[Route] No saved section, defaulting to Ads for key %@", key);
    }

    if (section < PPDataSectionAds || section > PPDataSectionServices) {
        section = PPDataSectionAds;
    }

    PPDataViewLog(@"[ROUTE] Initial switchToSection = %ld",
          (long)section);

    
    
    PPDataViewLog(@"[VC] resolved section = %ld", (long)section);
    //bar  PPDataViewLog(@"[VC] section control ready");

    [self updateSectionsTabBarSelectionForSection:section];
    
    PPDataViewLog(@"[VC] calling switchToSection:%ld", (long)section);
    [self activateSection:section userInitiated:NO];
    
    self.viewModel.currentSubKindID = 0;
    if (self.input.mainKind) {
        [self updateNavMainKindTitle];
        [self updateSubKindsButtonTitle:[self pp_currentSubKindsDisplayTitle]];
    }

    [self.scrollOffsetsBySection removeAllObjects];
    PPDataViewLog(@"[VC] scrollOffsetsBySection cleared");
    

}

#pragma mark - Setup
- (void)setupViewModel
{
    self.viewModel =
    [[PPDataViewVM alloc]initWithMainKind:self.input.mainKind sourceTarget:self.input.sourceTarget];
}

-(void)retryReloadData
{
    [self showSkeleton];
    __weak typeof(self) weakSelf = self;
    [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {
        if (!error) { return; }
        [weakSelf hideSkeleton];
        [weakSelf pp_clearSkeletonPresentationForEmptyStateIfNeeded];
        [weakSelf updateEmptyState];
    }];
}
 
- (BOOL)pp_presentedItemsContainOnlySkeletons
{
    if (self.presentedItems.count == 0) {
        return NO;
    }

    for (PPUniversalCellViewModel *viewModel in self.presentedItems) {
        if (!viewModel.isSkeleton) {
            return NO;
        }
    }

    return YES;
}

- (void)pp_clearSkeletonPresentationForEmptyStateIfNeeded
{
    if (self.viewModel.isLoading || ![self pp_presentedItemsContainOnlySkeletons]) {
        return;
    }

    self.presentedItems = @[];
    self.layoutManager.items = @[];
    [self applySnapshotAnimated:NO];
}

- (void)updateEmptyState {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateEmptyState];
        });
        return;
    }

    if (self.isShowingSkeleton || self.isPerformingCrossFade) return;

    [self pp_clearSkeletonPresentationForEmptyStateIfNeeded];

    [PPEmptyStateHelper updateEmptyStateForListView:self.collectionView
                                          dataCount:self.presentedItems.count
                                             config:self.emptyStateConfig
                                     delayWhenEmpty:NO];
    if (self.presentedItems.count == 0) {
        [[NovaAmbientAssistantCoordinator sharedCoordinator] emptyStateDidAppear];
    }
}

- (void)setupCollectionView
{
    self.layoutManager = [PPCollectionLayoutManager new];

    
    BOOL userChangedLayout = [[NSUserDefaults standardUserDefaults] boolForKey:@"PPLayoutModeChangedByUser"];
    PPManagerCellLayoutMode resolvedMode;
    if (userChangedLayout) {
        PPManagerCellLayoutMode savedMode =
        (PPManagerCellLayoutMode)[[NSUserDefaults standardUserDefaults]
                                  integerForKey:kPPLayoutModeKey];
        resolvedMode = [self pp_sanitizedDataViewLayoutMode:savedMode];
    } else {
        PPDataSection currentSec = self.viewModel ? self.viewModel.currentSection : PPDataSectionAds;
        if (currentSec == PPDataSectionAds) {
            resolvedMode = PPCellLayoutModePinterest;
        } else {
            resolvedMode = PPCellLayoutModeVertical;
        }
    }

    self.layoutManager.currentLayoutMode = resolvedMode;
    
    UICollectionViewLayout *layout =
    [self pp_collectionLayoutForDataViewMode:self.layoutManager.currentLayoutMode];

    self.collectionView =
    [[UICollectionView alloc] initWithFrame:CGRectZero
                       collectionViewLayout:layout];
    [self pp_installPinterestHeightGuardIfNeeded];

    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 11.0, *)) {
        BOOL fullDetails = (self.layoutManager.currentLayoutMode == PPCellLayoutModeDataViewFullDetails);
        self.collectionView.contentInsetAdjustmentBehavior = fullDetails
            ? UIScrollViewContentInsetAdjustmentNever
            : UIScrollViewContentInsetAdjustmentAutomatic;
    }
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.prefetchingEnabled = YES;
    self.collectionView.prefetchDataSource = self;
    [self pp_applyCollectionBehaviorForLayoutMode:self.layoutManager.currentLayoutMode];
    if (@available(iOS 13.0, *)) {
       // self.collectionView.automaticallyAdjustsScrollIndicatorInsets = NO;
    }
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];
    [self.collectionView registerClass:[BBDataViewFullDetailsCell class]
            forCellWithReuseIdentifier:[BBDataViewFullDetailsCell reuseIdentifier]];
    [self configureDataSource];
    [self.view insertSubview:self.collectionView atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        self.collectionViewTopAnchorConstraint =
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                                         constant:-0],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self pp_refreshSearchActionsMenu];
    
}

#pragma mark - Pinterest Height Guard

- (void)pp_installPinterestHeightGuardIfNeeded
{
    UICollectionViewLayout *layout = self.collectionView.collectionViewLayout;
    if (![layout isKindOfClass:PPPinterestLayout.class]) {
        return;
    }

    ((PPPinterestLayout *)layout).delegate = self;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(PPPinterestLayout *)layout
heightForItemAtIndexPath:(NSIndexPath *)indexPath
                withWidth:(CGFloat)width
{
    CGFloat proposedHeight =
        [(id<PPPinterestLayoutDelegate>)self.layoutManager collectionView:collectionView
                                                                   layout:layout
                                              heightForItemAtIndexPath:indexPath
                                                               withWidth:width];
    if (!isfinite(proposedHeight) || proposedHeight <= 0.0) {
        proposedHeight = MAX(width, kPPPinterestMinCellHeight);
    }

    if (self.layoutManager.currentLayoutMode != PPCellLayoutModePinterest ||
        self.viewModel.currentSection != PPDataSectionAds ||
        indexPath.item >= self.presentedItems.count) {
        return proposedHeight;
    }

    id item = self.presentedItems[indexPath.item];
    if (![item isKindOfClass:PPUniversalCellViewModel.class]) {
        return proposedHeight;
    }

    PPUniversalCellViewModel *viewModel = (PPUniversalCellViewModel *)item;
    BOOL isAd = viewModel.modelContext == PPCellForAds ||
                viewModel.modelContext == PPCellForHomeAds;
    if (!isAd || !isfinite(width) || width <= 0.0) {
        return proposedHeight;
    }

    CGFloat widthLimit = ceil(width * kPPAdsPinterestMaximumHeightToWidthRatio);
    CGFloat viewportHeight = CGRectGetHeight(collectionView.bounds);
    CGFloat viewportLimit = isfinite(viewportHeight) && viewportHeight > 0.0
        ? ceil(viewportHeight * kPPAdsPinterestMaximumViewportFraction)
        : widthLimit;
    CGFloat minimumFunctionalHeight =
        ceil(width + kPPAdsPinterestMinimumContentAllowance);
    CGFloat maximumHeight =
        MAX(minimumFunctionalHeight, MIN(widthLimit, viewportLimit));

    return MIN(proposedHeight, maximumHeight);
}

#pragma mark - Background

/*
 - (void)pp_applyPremiumDataViewBackgroundAppearance
 {
     self.view.backgroundColor = AppBackgroundClr;
     if (!self.collectionView) {
         return;
     }

     self.collectionView.backgroundColor = AppClearClr;
     [self pp_installPremiumBackgroundGlowViewsIfNeeded];
     [self pp_updatePremiumBackgroundGlowAppearance];
 }
 */

- (void)pp_applyPremiumDataViewBackgroundAppearance {
    // self.view.backgroundColor = AppBackgroundClr;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.view.backgroundColor = AppBackgroundClr;
        if (self.collectionView) {
            self.collectionView.backgroundColor = AppClearClr;
            [self pp_installPremiumBackgroundGlowViewsIfNeeded];
            [self pp_updatePremiumBackgroundGlowAppearance];
        }
    });
}

- (UIView *)pp_makePremiumBackgroundGlowView
{
    UIView *glowView = [[UIView alloc] initWithFrame:CGRectZero];
    glowView.userInteractionEnabled = NO;
    glowView.backgroundColor = UIColor.clearColor;
    glowView.clipsToBounds = NO;
    glowView.layer.masksToBounds = NO;
    glowView.layer.shadowOffset = CGSizeZero;
    return glowView;
}

- (void)pp_insertPremiumBackgroundGlowView:(UIView *)glowView
{
    if (!glowView || glowView.superview == self.view) {
        return;
    }

    if (self.collectionView.superview == self.view) {
        [self.view insertSubview:glowView belowSubview:self.collectionView];
    } else {
        [self.view addSubview:glowView];
    }
}

- (void)pp_installPremiumBackgroundGlowViewsIfNeeded
{
    if (!self.pp_premiumBackgroundGlowViewTop) {
        self.pp_premiumBackgroundGlowViewTop = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewMid) {
        self.pp_premiumBackgroundGlowViewMid = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewBottom) {
        self.pp_premiumBackgroundGlowViewBottom = [self pp_makePremiumBackgroundGlowView];
    }

    [self pp_insertPremiumBackgroundGlowView:self.pp_premiumBackgroundGlowViewTop];
    [self pp_insertPremiumBackgroundGlowView:self.pp_premiumBackgroundGlowViewMid];
    [self pp_insertPremiumBackgroundGlowView:self.pp_premiumBackgroundGlowViewBottom];

    if (self.collectionView.superview == self.view) {
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewTop belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewMid belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewBottom belowSubview:self.collectionView];
    }
}

- (void)pp_applyPremiumGlowView:(UIView *)glowView
                          color:(UIColor *)color
                   surfaceAlpha:(CGFloat)surfaceAlpha
                  shadowOpacity:(CGFloat)shadowOpacity
                   shadowRadius:(CGFloat)shadowRadius
{
    if (!glowView || !color) {
        return;
    }

    glowView.alpha = 1.0;
    glowView.backgroundColor = [color colorWithAlphaComponent:surfaceAlpha];
    glowView.layer.shadowColor = color.CGColor;
    glowView.layer.shadowOpacity = shadowOpacity;
    glowView.layer.shadowRadius = shadowRadius;
}

- (void)pp_updatePremiumBackgroundGlowAppearance
{
    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    UIColor *primaryColor = [GM appPrimaryColor] ?: AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *secondaryColor = AppPrimaryClrShiner ?: [primaryColor colorWithAlphaComponent:1.0];
    UIColor *ambientColor = isDark ? UIColor.whiteColor : UIColor.blackColor;

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewTop
                            color:primaryColor
                     surfaceAlpha:isDark ? 0.085 : 0.044
                    shadowOpacity:isDark ? 0.10f : 0.055f
                     shadowRadius:isDark ? 68.0 : 58.0];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewMid
                            color:secondaryColor
                     surfaceAlpha:isDark ? 0.070 : 0.032
                    shadowOpacity:isDark ? 0.082f : 0.038f
                     shadowRadius:isDark ? 58.0 : 48.0];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewBottom
                            color:ambientColor
                     surfaceAlpha:isDark ? 0.034 : 0.014
                    shadowOpacity:isDark ? 0.052f : 0.024f
                     shadowRadius:isDark ? 50.0 : 42.0];
}

- (void)pp_layoutPremiumBackgroundGlowViews
{
    [self pp_installPremiumBackgroundGlowViewsIfNeeded];

    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds) || !self.collectionView) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;

    CGFloat topSize = MIN(306.0, MAX(216.0, width * 0.62));
    CGFloat midSize = MIN(252.0, MAX(184.0, width * 0.49));
    CGFloat bottomSize = MIN(288.0, MAX(196.0, width * 0.56));

    self.pp_premiumBackgroundGlowViewTop.frame =
        CGRectMake(width - (topSize * 0.60),
                   safeTop - (topSize * 0.70),
                   topSize,
                   topSize);

    self.pp_premiumBackgroundGlowViewMid.frame =
        CGRectMake(-(midSize * 0.44),
                   MAX(152.0, height * 0.28),
                   midSize,
                   midSize);

    self.pp_premiumBackgroundGlowViewBottom.frame =
        CGRectMake(width - (bottomSize * 0.54),
                   height - (bottomSize * 0.60),
                   bottomSize,
                   bottomSize);

    NSArray<UIView *> *glowViews = @[
        self.pp_premiumBackgroundGlowViewTop,
        self.pp_premiumBackgroundGlowViewMid,
        self.pp_premiumBackgroundGlowViewBottom
    ];

    for (UIView *glowView in glowViews) {
        CGFloat radius = CGRectGetWidth(glowView.bounds) * 0.5;
        glowView.layer.cornerRadius = radius;
        glowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:glowView.bounds].CGPath;
    }

    if (self.collectionView.superview == self.view) {
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewBottom belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewMid belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewTop belowSubview:self.collectionView];
    }
}


 
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if(!self.DidFinishLayout)
    {
        [self pp_applyPremiumDataViewBackgroundAppearance];
        [self pp_layoutPremiumBackgroundGlowViews];
        [self pp_applyPremiumNavigationChromeAppearance];
        [self pp_applyPremiumSectionsSegmentedAppearance];
        [self pp_updatePremiumChromeShadowPaths];
        [self updateCollectionContentInset];
        [self pp_anchorSkeletonLoadingBelowChromeIfNeeded];
        [self updateSectionsTabBarSelectionIndicatorIfNeeded];
        [self reloadNavigationCenterViewLayout];
        if ([self.collectionView.collectionViewLayout isKindOfClass:BBDataViewFullDetailsLayout.class]) {
            [(BBDataViewFullDetailsLayout *)self.collectionView.collectionViewLayout invalidateForViewportChange];
        }
        self.DidFinishLayout = YES;
    }
    [self pp_updatePremiumHeaderCollapseForScrollView:self.collectionView animated:NO];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self updateCollectionContentInset];
}


/// Smoothly scrolls collection view to top (safe and async)
- (void)scrollCollectionViewToTopAfterReload:(BOOL)animated
{
    UICollectionView *cv = self.collectionView;
    if (!cv) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        [cv layoutIfNeeded];

        if ([self pp_isFullDetailsLayoutMode]) {
            CGPoint leadingOffset = CGPointMake(-cv.adjustedContentInset.left,
                                                -cv.adjustedContentInset.top);
            [cv setContentOffset:leadingOffset animated:animated];
            return;
        }

        CGPoint topOffset = CGPointMake(0, [self preferredTopContentOffsetY]);
        [cv setContentOffset:topOffset animated:animated];
    });
}

- (void)persistCurrentSection
{
    PPDataSection section = self.viewModel.currentSection;
    [self persistSectionSelection:section];
}

- (void)persistSectionSelection:(PPDataSection)section
{
    NSString *key = [self sectionKeyForMainKind:self.input.mainKind];
    [[NSUserDefaults standardUserDefaults] setInteger:section forKey:key];
    PPDataViewLog(@"[Persist] Saved section %ld for key %@", (long)section, key);
}

- (void)refreshsubKindsMenu
{
    if (!self.subKindsButton) {
        return;
    }
    self.subKindsButton.menu = [self subKindsMenu];
    self.centerCapsuleButton.menu = [self subKindsMenu];
    [self pp_syncExperimentalCenterCapsuleState];
}


 - (void)bindViewModel
{
    __weak typeof(self) weakSelf = self;

    self.viewModel.onReloadData = ^{
        PPDataViewLog(@"\n================ onReloadData =================");
        PPDataViewLog(@"[VC] currentSection = %ld", (long)weakSelf.viewModel.currentSection);
        PPDataViewLog(@"[VC] items.count = %ld", (long)weakSelf.viewModel.items.count);

        BOOL isTransitionResetPhase =
            weakSelf.isAwaitingTransitionData &&
            weakSelf.viewModel.isLoading &&
            weakSelf.viewModel.items.count == 0;

        if (isTransitionResetPhase) {
            BOOL alreadyShowingSkeleton = weakSelf.isShowingSkeleton;
            if (!alreadyShowingSkeleton) {
                [weakSelf showSkeleton];
            }
            if (alreadyShowingSkeleton) {
                // Startup already installed the single skeleton snapshot. The
                // VM loading signal must not rebuild it or force another layout.
                return;
            }
            [weakSelf updateSectionsTabBarSelectionForSection:weakSelf.viewModel.currentSection animated:NO];
            [weakSelf pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
            [weakSelf syncFilterChipsForCurrentSection];
            [weakSelf persistCurrentSection];
            [weakSelf updateCollectionContentInset];
            [weakSelf updateCartButtonVisibility];
            return;
        }

        BOOL wasShowingSkeleton = weakSelf.isShowingSkeleton;
        BOOL isInitialContentLoad = wasShowingSkeleton && !weakSelf.didApplyInitialSnapshot;
        [weakSelf hideSkeleton];

        BOOL shouldScrollToTop = weakSelf.pendingFilterScrollToTop;
        weakSelf.pendingFilterScrollToTop = NO;
        if (isInitialContentLoad) {
            weakSelf.pendingMotionReason = PPDataViewMotionReasonNone;
        }

        if (isInitialContentLoad) {
            os_log_t log = PPDataViewVCPerformanceLog();
            os_signpost_id_t firstFrameSignpostID = os_signpost_id_generate(log);
            os_signpost_interval_begin(log, firstFrameSignpostID, "destination.firstFrame");
            os_signpost_id_t meaningfulContentSignpostID = os_signpost_id_generate(log);
            os_signpost_interval_begin(log, meaningfulContentSignpostID, "ui.firstMeaningfulContent");

            // The skeleton is replaced as soon as the VM transaction commits.
            // The old fixed cross-dissolve made first content wait 250 ms.
            [weakSelf refreshPresentedItemsAnimated:NO scrollToTop:shouldScrollToTop];
            weakSelf.didApplyInitialSnapshot = YES;

            os_signpost_interval_end(log, firstFrameSignpostID, "destination.firstFrame", "itemsCount=%ld", (long)weakSelf.presentedItems.count);
            os_signpost_interval_end(log, meaningfulContentSignpostID, "ui.firstMeaningfulContent", "itemsCount=%ld", (long)weakSelf.presentedItems.count);
        } else {
            [weakSelf refreshPresentedItemsAnimated:wasShowingSkeleton || weakSelf.didApplyInitialSnapshot
                                         scrollToTop:shouldScrollToTop];
            weakSelf.didApplyInitialSnapshot = YES;
        }
        [weakSelf updateSectionsTabBarSelectionForSection:weakSelf.viewModel.currentSection animated:NO];
        [weakSelf pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
        [weakSelf syncFilterChipsForCurrentSection];
        // ✅ THIS IS THE FIX
          [weakSelf persistCurrentSection];
        
        [weakSelf updateEmptyState];
        
        // 3️⃣ Force nav container relayout
        //[weakSelf updateNavSectionTitle];
        
        
        [weakSelf updateCollectionContentInset];

        if (!weakSelf.didFixInitialScroll) {
            weakSelf.didFixInitialScroll = YES;

            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf updateCollectionContentInset];
                [weakSelf.collectionView layoutIfNeeded];
                CGPoint topOffset =
                CGPointMake(0, [weakSelf preferredTopContentOffsetY]);
                [weakSelf.collectionView setContentOffset:topOffset animated:NO];
            });
        } else {
            [weakSelf restoreScrollOffsetForCurrentSection];
        }
        [weakSelf updateCartButtonVisibility];
        [weakSelf pp_prefetchTopImagesWithLimit:16];
        
        if(weakSelf.viewModel.currentSubKindID > 0)
        {
            [weakSelf refreshsubKindsMenu];
            SubKindModel *subKind = [weakSelf.input.mainKind subKindForID:weakSelf.viewModel.currentSubKindID];
            [weakSelf updateSubKindsButtonTitle:subKind.SubKindName subKind:subKind];
        }
    };

    self.viewModel.onInitialSectionsDataLoaded = ^{
        [weakSelf pp_runSectionsSegmentedEntranceIfNeeded];
        [weakSelf pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
    };

    self.viewModel.onAppendData = ^(NSArray<NSIndexPath *> *indexPaths) {
        PPDataViewLog(@"\n================ onAppendData =================");
        PPDataViewLog(@"[VC] indexPaths.count = %ld", (long)indexPaths.count);
        PPDataViewLog(@"[VC] items.count BEFORE = %ld", (long)weakSelf.viewModel.items.count);
        PPDataViewLog(@"[VC] didInitialReload = %@", weakSelf.didInitialReload ? @"YES" : @"NO");

        [weakSelf refreshPresentedItemsAnimated:YES scrollToTop:NO];
        [weakSelf updateEmptyState];
        [weakSelf syncFilterChipsForCurrentSection];
        [weakSelf pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
        //[weakSelf updateNavSectionTitle];

        [weakSelf refreshsubKindsMenu];
        [weakSelf updateCartButtonVisibility];
        [weakSelf updateCollectionContentInset];
        [weakSelf pp_refreshCollectionLayoutAfterSnapshotPreservingOffset:YES];
        [weakSelf pp_prefetchImagesAtIndexPaths:indexPaths];
    };

    self.viewModel.onError = ^(NSError * _Nonnull error) {
        PPDataViewLog(@"[PPDataViewVC] data error: %@", error.localizedDescription ?: @"unknown");
        [weakSelf hideSkeleton];
        [weakSelf pp_clearSkeletonPresentationForEmptyStateIfNeeded];
        [weakSelf updateEmptyState];
    };
}


#pragma mark - Collection Content Inset Fix

/* Top Inset Code */
- (CGFloat)pp_currentCollectionChromeBottomY
{
    UIView *island = self.sectionsFiltersContainer;
    if (!self.view ||
        !island ||
        !island.superview ||
        island.hidden ||
        CGRectIsEmpty(island.bounds)) {
        return NAN;
    }

    // Keep scroll geometry stable while the island animates. Mutating the top
    // inset from presentation-layer transforms cancels UIKit deceleration at
    // the dock boundary and forces the user to begin a second scroll gesture.
    CALayer *islandLayer = island.layer;
    CGPoint anchorPoint = islandLayer.anchorPoint;
    CGSize islandSize = island.bounds.size;
    CGRect untransformedFrame = CGRectMake(
        island.center.x - (islandSize.width * anchorPoint.x),
        island.center.y - (islandSize.height * anchorPoint.y),
        islandSize.width,
        islandSize.height
    );
    CGRect chromeFrame = [island.superview convertRect:untransformedFrame toView:self.view];
    CGFloat resolvedBottomY = CGRectGetMaxY(chromeFrame);
    if (CGRectIsEmpty(chromeFrame) || !isfinite((double)resolvedBottomY)) {
        return NAN;
    }

    CGFloat displayScale = MAX(UIScreen.mainScreen.scale, 1.0);
    return ceil(resolvedBottomY * displayScale) / displayScale;
}

- (CGFloat)pp_targetCollectionTopInsetFollowingChrome
{
    if (!self.collectionView || [self pp_isFullDetailsLayoutMode]) {
        return 0.0;
    }

    CGFloat chromeBottomY = [self pp_currentCollectionChromeBottomY];
    if (!isfinite((double)chromeBottomY)) {
        return kPPDataViewCollectionChromeFallbackTopInset;
    }

    CGFloat layoutTopInset = [self pp_currentCollectionLayoutTopInset];
    CGFloat automaticTopAdjustment =
        MAX(0.0, self.collectionView.adjustedContentInset.top - self.collectionView.contentInset.top);
    CGRect collectionFrame = self.collectionView.superview
        ? [self.collectionView.superview convertRect:self.collectionView.frame toView:self.view]
        : self.collectionView.frame;
    CGFloat collectionTopY = CGRectGetMinY(collectionFrame);
    CGFloat desiredContentTopY = chromeBottomY + kPPDataViewCollectionChromeBreathingGap;
    CGFloat targetTopInset =
        desiredContentTopY - collectionTopY - automaticTopAdjustment - layoutTopInset;

    if (!isfinite((double)targetTopInset)) {
        return kPPDataViewCollectionChromeFallbackTopInset;
    }

    CGFloat displayScale = MAX(UIScreen.mainScreen.scale, 1.0);
    return MAX(0.0, ceil(targetTopInset * displayScale) / displayScale);
}

// Ensures collectionView has proper bottom inset for tab bar & safe area, and always bounces vertically.
- (void)updateCollectionContentInset
{
    if (!self.collectionView) { return; }

    // Resolve the complete filter island before measuring its clearance. The
    // island is fixed to the view while the collection scrolls underneath it.
    [self.view layoutIfNeeded];

    BOOL fullDetails = [self pp_isFullDetailsLayoutMode];
    CGFloat targetTopInset = 0.0;

    if (!fullDetails) {
        targetTopInset = [self pp_targetCollectionTopInsetFollowingChrome];
    }

    CGFloat targetBottomInset = 16.0;
    BOOL resolvedBottomInsetFromNavigationFrame = NO;
    if (fullDetails) {
        UIView *bottomNavigationView = nil;
        SEL anchorSelector = NSSelectorFromString(@"pp_novaAmbientBottomNavigationAnchorView");
        if ([self.tabBarController respondsToSelector:anchorSelector]) {
            UIView *(*anchorIMP)(id, SEL) = (UIView *(*)(id, SEL))[self.tabBarController methodForSelector:anchorSelector];
            bottomNavigationView = anchorIMP ? anchorIMP(self.tabBarController, anchorSelector) : nil;
        }
        if (!bottomNavigationView &&
            self.tabBarController &&
            !self.tabBarController.tabBar.hidden &&
            self.tabBarController.tabBar.alpha > 0.01) {
            bottomNavigationView = self.tabBarController.tabBar;
        }
        if (bottomNavigationView &&
            !bottomNavigationView.hidden &&
            bottomNavigationView.alpha > 0.01 &&
            bottomNavigationView.superview) {
            CGRect navigationFrame = [bottomNavigationView.superview convertRect:bottomNavigationView.frame
                                                                          toView:self.view];
            if (!CGRectIsEmpty(navigationFrame)) {
                targetBottomInset = MAX(0.0, CGRectGetMaxY(self.collectionView.frame) - CGRectGetMinY(navigationFrame));
                resolvedBottomInsetFromNavigationFrame = YES;
            }
        }
    }

    CGFloat rootClearance = 0.0;
    SEL clearanceSelector = NSSelectorFromString(@"pp_bottomNavigationContentClearance");
    if ([self.tabBarController respondsToSelector:clearanceSelector]) {
        CGFloat (*clearanceIMP)(id, SEL) = (CGFloat (*)(id, SEL))[self.tabBarController methodForSelector:clearanceSelector];
        rootClearance = clearanceIMP ? clearanceIMP(self.tabBarController, clearanceSelector) : 0.0;
    }

    if (rootClearance > 0.0) {
        CGFloat rootTargetBottomInset = ceil(rootClearance);
        targetBottomInset = MAX(targetBottomInset, rootTargetBottomInset);
    } else if (!resolvedBottomInsetFromNavigationFrame) {
        CGFloat bottomInset = 0.0;
        if (self.tabBarController &&
            !self.tabBarController.tabBar.hidden &&
            self.tabBarController.tabBar.alpha > 0.01) {
            bottomInset += self.tabBarController.tabBar.bounds.size.height;
        }
        bottomInset += self.view.safeAreaInsets.bottom;
        targetBottomInset = bottomInset + (fullDetails ? 0.0 : 16.0);
    }
    UIEdgeInsets currentInset = self.collectionView.contentInset;
    CGFloat previousAdjustedTop = self.collectionView.adjustedContentInset.top;
    CGPoint previousOffset = self.collectionView.contentOffset;
    CGFloat topDelta = currentInset.top - targetTopInset;
    if (topDelta < 0) { topDelta = -topDelta; }
    CGFloat bottomDelta = currentInset.bottom - targetBottomInset;
    if (bottomDelta < 0) { bottomDelta = -bottomDelta; }

    // Never rewrite the scroll geometry while UIKit owns an active gesture or
    // deceleration transaction. A programmatic contentOffset compensation in
    // this phase cancels momentum and leaves the list parked at the dock seam.
    BOOL shouldDeferTopInset =
        !fullDetails &&
        topDelta >= 0.5 &&
        (self.collectionView.isTracking ||
         self.collectionView.isDragging ||
         self.collectionView.isDecelerating);
    if (shouldDeferTopInset) {
        targetTopInset = currentInset.top;
        topDelta = 0.0;
    }

    if (topDelta < 0.5 && bottomDelta < 0.5) {
        return;
    }
 
    UIEdgeInsets inset = currentInset;
    inset.top = targetTopInset;
    inset.bottom = targetBottomInset; // breathing space

    self.collectionView.contentInset = inset;
    self.collectionView.scrollIndicatorInsets = inset;

    if (!fullDetails && topDelta >= 0.5) {
        BOOL shouldPinRestingTop =
            !self.collectionView.isDragging &&
            !self.collectionView.isDecelerating &&
            previousOffset.y <= 1.0;
        if (shouldPinRestingTop) {
            CGPoint targetOffset =
                CGPointMake(previousOffset.x, -self.collectionView.adjustedContentInset.top);
            if (fabs(targetOffset.y - self.collectionView.contentOffset.y) >= 0.5) {
                self.isUpdatingCollectionInsetForHeaderMotion = YES;
                [self.collectionView setContentOffset:targetOffset animated:NO];
                self.isUpdatingCollectionInsetForHeaderMotion = NO;
            }
        } else {
            CGFloat adjustedTopDelta =
                self.collectionView.adjustedContentInset.top - previousAdjustedTop;
            if (fabs(adjustedTopDelta) >= 0.5) {
                CGPoint correctedOffset =
                    CGPointMake(previousOffset.x, previousOffset.y - adjustedTopDelta);
                if (fabs(correctedOffset.y - self.collectionView.contentOffset.y) >= 0.5) {
                    self.isUpdatingCollectionInsetForHeaderMotion = YES;
                    [self.collectionView setContentOffset:correctedOffset animated:NO];
                    self.isUpdatingCollectionInsetForHeaderMotion = NO;
                }
            }
        }
    }

    if (fullDetails &&
        [self.collectionView.collectionViewLayout isKindOfClass:BBDataViewFullDetailsLayout.class]) {
        [(BBDataViewFullDetailsLayout *)self.collectionView.collectionViewLayout invalidateForViewportChange];
        [self.collectionView setNeedsLayout];
    }
}

- (CGFloat)pp_currentCollectionLayoutTopInset
{
    UICollectionViewLayout *layout = self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:UICollectionViewFlowLayout.class]) {
        return MAX(0.0, ((UICollectionViewFlowLayout *)layout).sectionInset.top);
    }
    if ([layout isKindOfClass:PPPinterestLayout.class]) {
        return MAX(0.0, ((PPPinterestLayout *)layout).sectionInset.top);
    }

    // PurePetsLayoutKit's adaptive layout keeps sectionInset internal to
    // Swift. Its first item frame is the reliable cross-language source for
    // the same top padding exposed directly by the Pinterest layout.
    if (self.collectionView.numberOfSections > 0 &&
        [self.collectionView numberOfItemsInSection:0] > 0) {
        UICollectionViewLayoutAttributes *firstAttributes =
            [layout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        if (firstAttributes) {
            CGFloat firstItemMinY = CGRectGetMinY(firstAttributes.frame);
            if (!isfinite((double)firstItemMinY)) {
                return 0.0;
            }
            return MAX(0.0, firstItemMinY);
        }
    }
    return 0.0;
}

- (BOOL)pp_shouldPinCollectionTopForChromeOffset:(CGPoint)currentOffset
                              previousTopOffsetY:(CGFloat)previousTopOffsetY
{
    if (!self.collectionView ||
        self.collectionView.isDragging ||
        self.collectionView.isDecelerating) {
        return NO;
    }

    if (currentOffset.y <= previousTopOffsetY + 1.0) {
        return YES;
    }

    if (currentOffset.y <= 1.0) {
        return YES;
    }

    return NO;
}

- (void)pp_updateCollectionContentInsetPreservingTopAnchor
{
    if (!self.collectionView) {
        return;
    }

    CGFloat previousTopOffsetY = [self preferredTopContentOffsetY];
    CGPoint currentOffset = self.collectionView.contentOffset;
    BOOL shouldPinToChrome =
        [self pp_shouldPinCollectionTopForChromeOffset:currentOffset
                                    previousTopOffsetY:previousTopOffsetY];

    [self updateCollectionContentInset];

    if (!shouldPinToChrome) {
        return;
    }

    CGPoint targetOffset = CGPointMake(currentOffset.x, [self preferredTopContentOffsetY]);
    if (fabs(self.collectionView.contentOffset.y - targetOffset.y) >= 0.5 ||
        fabs(self.collectionView.contentOffset.x - targetOffset.x) >= 0.5) {
        [self.collectionView setContentOffset:targetOffset animated:NO];
    }
}

- (void)pp_anchorSkeletonLoadingBelowChromeIfNeeded
{
    if (!self.isShowingSkeleton || !self.collectionView) {
        return;
    }

    if (self.sectionsFiltersContainer) {
        self.sectionsFiltersContainer.hidden = NO;
        self.sectionsFiltersContainer.alpha = 1.0;
        self.sectionsFiltersContainer.transform = CGAffineTransformIdentity;
        [self.view bringSubviewToFront:self.sectionsFiltersContainer];
        [self pp_updatePremiumHeaderCollapseForScrollView:self.collectionView animated:NO];
    }

    if (self.collectionView.isDragging || self.collectionView.isDecelerating) {
        return;
    }

    CGPoint targetOffset = CGPointMake(0.0, [self preferredTopContentOffsetY]);
    if (fabs(self.collectionView.contentOffset.y - targetOffset.y) >= 0.5 ||
        fabs(self.collectionView.contentOffset.x - targetOffset.x) >= 0.5) {
        [self.collectionView setContentOffset:targetOffset animated:NO];
    }
}

- (void)saveCurrentSectionScrollOffset
{
    if (!self.collectionView) { return; }
    if ([self pp_isFullDetailsLayoutMode]) { return; }
    CGPoint currentOffset = self.collectionView.contentOffset;
    CGFloat preferredTopY = [self preferredTopContentOffsetY];
    CGPoint normalizedOffset = CGPointMake(currentOffset.x,
                                            MAX(0.0, currentOffset.y - preferredTopY));
    self.scrollOffsetsBySection[@(self.viewModel.currentSection)] =
    [NSValue valueWithCGPoint:normalizedOffset];
}

- (void)restoreScrollOffsetForCurrentSection
{
    if (!self.collectionView) { return; }
    if ([self pp_isFullDetailsLayoutMode]) {
        [self pp_scrollToAnchorIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]
                             fullDetails:YES
                                animated:NO];
        return;
    }

    NSNumber *sectionKey = @(self.viewModel.currentSection);
    NSValue *savedOffset = self.scrollOffsetsBySection[sectionKey];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (![sectionKey isEqualToNumber:@(self.viewModel.currentSection)]) {
            return;
        }

        [self updateCollectionContentInset];
        [self.collectionView layoutIfNeeded];

        CGFloat minY = -self.collectionView.adjustedContentInset.top;
        CGFloat maxY = self.collectionView.contentSize.height -
        self.collectionView.bounds.size.height +
        self.collectionView.adjustedContentInset.bottom;
        if (maxY < minY) {
            maxY = minY;
        }

        CGFloat preferredTopY = [self preferredTopContentOffsetY];
        CGPoint targetOffset = CGPointMake(0.0, preferredTopY);
        if (savedOffset) {
            CGPoint normalizedOffset = savedOffset.CGPointValue;
            targetOffset = CGPointMake(normalizedOffset.x,
                                       preferredTopY + MAX(0.0, normalizedOffset.y));
        }
        CGFloat clampedY = targetOffset.y;
        if (clampedY < preferredTopY) { clampedY = preferredTopY; }
        if (clampedY < minY) { clampedY = minY; }
        if (clampedY > maxY) { clampedY = maxY; }
        CGPoint clampedOffset = CGPointMake(0, clampedY);
        self.isRestoringScrollOffset = YES;
        [self.collectionView setContentOffset:clampedOffset animated:NO];
        self.isRestoringScrollOffset = NO;
        CGPoint normalizedOffset = CGPointMake(clampedOffset.x,
                                                MAX(0.0, clampedY - preferredTopY));
        self.scrollOffsetsBySection[sectionKey] = [NSValue valueWithCGPoint:normalizedOffset];
        self.lastContentOffsetY = clampedY;
    });
}

- (CGFloat)preferredTopContentOffsetY
{
    if (!self.collectionView) {
        return 0.0;
    }
    return -self.collectionView.adjustedContentInset.top;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) { return; }
    if (self.isUpdatingCollectionInsetForHeaderMotion) { return; }
    [self pp_updatePremiumHeaderCollapseForScrollView:scrollView animated:NO];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidScroll];
    if (self.isRestoringScrollOffset) { return; }
    if (self.layoutManager.items.count == 0) { return; }
    if ([self pp_isFullDetailsLayoutMode]) { return; }
    if (!scrollView.isTracking && !scrollView.isDragging && !scrollView.isDecelerating) { return; }
    CGFloat y = scrollView.contentOffset.y;
    if (ABS(y - self.lastContentOffsetY) < 6.0) { return; }
    self.lastContentOffsetY = y;
    [self saveCurrentSectionScrollOffset];
    [self pp_updateMirrorColorForScrollOffset];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }

    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidScroll];
    [self pp_collapseFilterIslandForUserScrollIfNeededAnimated:YES];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                      withVelocity:(CGPoint)velocity
               targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (scrollView != self.collectionView || ![self pp_isFullDetailsLayoutMode] || !targetContentOffset) {
        return;
    }
    *targetContentOffset = [self pp_fullDetailsCenteredOffsetForProposedOffset:*targetContentOffset
                                                                      velocity:velocity];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView == self.collectionView && !decelerate) {
        if ([self pp_isFullDetailsLayoutMode]) {
            [self pp_settleFullDetailsCarouselIfNeededAnimated:YES];
        } else {
            [self pp_updateCollectionContentInsetPreservingTopAnchor];
        }
        [self pp_updatePremiumHeaderCollapseForScrollView:scrollView animated:YES];
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == self.collectionView) {
        if ([self pp_isFullDetailsLayoutMode]) {
            [self pp_settleFullDetailsCarouselIfNeededAnimated:YES];
        } else {
            [self pp_updateCollectionContentInsetPreservingTopAnchor];
        }
        [self pp_updatePremiumHeaderCollapseForScrollView:scrollView animated:YES];
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView == self.collectionView) {
        if (![self pp_isFullDetailsLayoutMode]) {
            [self pp_updateCollectionContentInsetPreservingTopAnchor];
        }
        [self pp_updatePremiumHeaderCollapseForScrollView:scrollView animated:YES];
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
    }
}

- (void)pp_handleCartUpdated:(NSNotification *)note
{
    (void)note;
    [self updateCartBadge];
    [self updateCollectionContentInset];
}

- (NSInteger)currentCartItemCount
{
    return [CartManager.sharedManager totalItemsCount];
}

- (void)updateCartBadge
{
    if (!self.navCartButton) {
        return;
    }

    UIButton *badgeHost = self.navCartButton;
    [badgeHost removeBadge];

    NSInteger count = [self currentCartItemCount];

    [self pp_applyPremiumNavIconButtonAppearance:self.navCartButton emphasized:YES];

    if (count <= 0) {
        UIButtonConfiguration *config = self.navCartButton.configuration;
        if (config) {
            config.background.backgroundColor = UIColor.clearColor;
            config.background.strokeColor = UIColor.clearColor;
            self.navCartButton.configuration = config;
        }
        self.navCartButton.layer.shadowOpacity = 0.0;
        return;
    }

    NSString *badgeText = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    UIColor *badgeColor = AppPrimaryClr ?: UIColor.systemPinkColor;

    void (^applyBadge)(void) = ^{
        UIButton *host = self.navCartButton;
        if (!host) return;

        [host layoutIfNeeded];
        if (CGRectIsEmpty(host.bounds)) return;

        [host removeBadge];
        [host addBadgeWithContent:badgeText
                       badgeColor:badgeColor
                           offset:CGPointMake(-10, 10)
                      badgeRadius:9.5];
    };

    applyBadge();

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
        applyBadge();
    });
}

#pragma mark - Actions

- (void)onBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onCartTapped
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    CartViewController *vc = [[CartViewController alloc] init];
    PPNavigationController *nav =
    [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)pp_openSearchController
{
    if (self.presentedViewController) {
        return;
    }

    PPSearchViewController *searchVC = [[PPSearchViewController alloc] init];
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:searchVC];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:nav from:self animated:YES completion:nil];
}

- (void)pp_applyTemporaryHiddenCartButtonState
{
    if (!self.navCartButton) {
        return;
    }

    self.navCartButton.hidden = YES;
    self.navCartButton.alpha = 0.0;
    self.navCartButton.userInteractionEnabled = NO;
    self.navCartButton.accessibilityElementsHidden = YES;
}

- (void)updateCartButtonVisibility
{
    [self updateCartButtonVisibilityForSection:self.viewModel.currentSection animated:NO];
}

- (void)updateCartButtonVisibilityForSection:(PPDataSection)section
{
    [self updateCartButtonVisibilityForSection:section animated:NO];
}

- (void)updateCartButtonVisibilityForSection:(PPDataSection)section animated:(BOOL)animated
{
    if (!self.cartButton || !self.cartButtonWidthConstraint) {
        return;
    }

    // Search now lives in the right navbar slot. Keep this legacy center button
    // retained for rollback safety, but do not present it in the title view.
    BOOL shouldShow = NO;
    self.isCartButtonVisible = shouldShow;
    self.cartButton.userInteractionEnabled = shouldShow;
    self.cartButton.accessibilityElementsHidden = !shouldShow;

    if (self.subKindsTrailingToCartConstraint && self.subKindsTrailingToContainerConstraint) {
        self.subKindsTrailingToCartConstraint.active = shouldShow;
        self.subKindsTrailingToContainerConstraint.active = !shouldShow;
    }

    void (^layoutChanges)(void) = ^{
        self.cartButtonWidthConstraint.constant = shouldShow ? 36.0 : 1.0;
        self.cartButton.alpha = shouldShow ? 1.0 : 0.0;
        self.cartButton.transform = shouldShow ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.9, 0.9);
        [self reloadNavigationCenterViewLayout];
        [self.navContainerView layoutIfNeeded];
        [self.navigationController.navigationBar layoutIfNeeded];
    };

    if (shouldShow) {
        self.cartButton.hidden = NO;
    }

    BOOL shouldAnimate = animated && self.view.window != nil;
    if (shouldShow) {
        self.cartButton.transform = shouldAnimate ? CGAffineTransformMakeScale(0.9, 0.9) : CGAffineTransformIdentity;
    } else {
        self.cartButton.transform = CGAffineTransformIdentity;
    }
    if (shouldAnimate) {
        [UIView animateWithDuration:0.26
                              delay:0
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:layoutChanges
                         completion:^(__unused BOOL finished) {
            if (!shouldShow) {
                self.cartButton.hidden = YES;
            }
            self.cartButton.transform = CGAffineTransformIdentity;
            [self updateCartBadge];
        }];
    } else {
        layoutChanges();
        if (!shouldShow) {
            self.cartButton.hidden = YES;
            self.cartButton.transform = CGAffineTransformIdentity;
        }
        [self updateCartBadge];
    }
}

- (void)openFilters
{
    if (self.presentedViewController) {
        return;
    }

    PPFilterSheetVC *vc = [PPFilterSheetVC new];
     vc.currentSection = self.viewModel.currentSection;
    vc.filterState = [[self pp_currentFilterState] copy];
    __weak typeof(self) weakSelf = self;
    vc.resultCountProvider = ^NSInteger(PPFilterState *state) {
        PPDataViewVC *strongSelf = weakSelf;
        if (!strongSelf) {
            return 0;
        }
        return [strongSelf.viewModel previewResultCountForFilterState:state];
    };
    vc.onApply = ^(PPFilterState *applied) {

        PPDataViewVC *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.filterStates[@(strongSelf.viewModel.currentSection)] = applied;
        strongSelf.pendingFilterScrollToTop = YES;
        [strongSelf.viewModel applyFilterState:applied];
        [strongSelf syncFilterChipsForCurrentSection];
        [strongSelf refreshFilterChipTitles];

    };
    [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyleFull ];

}
 

#pragma mark - Diffable Data Source

- (void)configureDataSource
{
    __weak typeof(self) weakSelf = self;

    self.dataSource =
    [[UICollectionViewDiffableDataSource alloc]
     initWithCollectionView:self.collectionView
     cellProvider:^UICollectionViewCell *
     (UICollectionView *collectionView,
      NSIndexPath *indexPath,
      PPUniversalCellViewModel *vm) {

        if (weakSelf.layoutManager.currentLayoutMode == PPCellLayoutModeDataViewFullDetails) {
            BBDataViewFullDetailsCell *fullDetailsCell =
            [collectionView dequeueReusableCellWithReuseIdentifier:[BBDataViewFullDetailsCell reuseIdentifier]
                                                      forIndexPath:indexPath];

            if (!vm) {
                fullDetailsCell.hidden = YES;
                return fullDetailsCell;
            }

            fullDetailsCell.hidden = NO;
            vm.indexPath = indexPath;
            [fullDetailsCell configureWithViewModel:vm
                                        imageLoader:^(UIImageView *iv,
                                                      NSString *url,
                                                      UIImage *placeholder,
                                                      UIView *card) {
                (void)card;
                UIImage *fallback = placeholder ?: vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
                iv.contentMode = UIViewContentModeScaleAspectFill;
                iv.clipsToBounds = YES;
                iv.image = fallback;
                [[PPImageLoaderManager shared] setImageOnImageView:iv
                                                               url:url
                                                       placeholder:fallback
                                                   transitionStyle:PPImageTransitionStyleNone
                                                        complation:nil];
            }
                                           delegate:weakSelf];
            return fullDetailsCell;
        }

        PPUniversalCell *cell = (PPUniversalCell *)[PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];

        if (!vm) {
            cell.hidden = YES;
            return cell;
        }

        cell.hidden = NO;
        vm.indexPath = indexPath;

        BOOL isAdContext = (vm.modelContext == PPCellForAds || vm.modelContext == PPCellForHomeAds);
        cell.delegate = weakSelf;
        cell.dataViewPresentation = YES;
        cell.hideTopBadge = isAdContext;
        cell.showsSubtitle = YES;

        [cell applyViewModel:vm
                     context:vm.modelContext
                  layoutMode:weakSelf.layoutManager.currentLayoutMode
                discountMode:PPDiscountStyleBadge
                 imageLoader:^(UIImageView *iv,
                               NSString *url,
                               UIImage *placeholder,
                               UIView *card) {
            
            
            UIImage *fallback =
            vm.placeholder ?: [UIImage imageNamed:@"placeholder"];

            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;

            // 1️⃣ Set placeholder immediately
            iv.image = fallback;

            // Capture identity
            NSString *currentHash = vm.blurHash;
            __weak UIImageView *weakIV = iv;

            // 2️⃣ Async blurhash (SAFE)
            if (currentHash.length > 0) {
                PPDataViewVC *strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                [strongSelf asyncBlurHashImageForHash:currentHash
                                           size:CGSizeMake(40, 40)
                                      completion:^(UIImage * _Nullable blurImg) {

                    if (!blurImg) return;
                    if (!weakIV) return;

                    // Cell reuse protection
                    if (![currentHash isEqualToString:vm.blurHash]) {
                        return;
                    }

                    // 🔒 DO NOT override real image
                    [UIView performWithoutAnimation:^{
                        if (weakIV.image == fallback) {
                            weakIV.image = blurImg;
                        }
                    }];
                }];
            }

            // 3️⃣ Load real image (FINAL AUTHORITY)
            [[PPImageLoaderManager shared]
             setImageOnImageView:iv
                             url:url
                      placeholder:fallback
                    transitionStyle:PPImageTransitionStyleNone
                       complation:nil];
        }];

        return cell;
    }];
}

#pragma mark - Collection Prefetch

- (NSArray<NSString *> *)pp_imageURLsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (indexPaths.count == 0 || self.presentedItems.count == 0) {
        return @[];
    }

    NSArray<PPUniversalCellViewModel *> *items = self.presentedItems;
    NSMutableOrderedSet<NSString *> *urls = [NSMutableOrderedSet orderedSet];

    for (NSIndexPath *indexPath in indexPaths) {
        NSInteger itemIndex = indexPath.item;
        if (itemIndex < 0 || itemIndex >= (NSInteger)items.count) {
            continue;
        }

        PPUniversalCellViewModel *vm = items[itemIndex];
        if (vm.imageURL.length > 0) {
            [urls addObject:vm.imageURL];
        }
    }

    return urls.array;
}

- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSArray<NSString *> *urls = [self pp_imageURLsFromIndexPaths:indexPaths];
    if (urls.count == 0) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    __block SDWebImagePrefetchToken *token = nil;
    token = [[PPImageLoaderManager shared]
             prefetchURLsReturningToken:urls
                              completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token) {
                [weakSelf.ownedPrefetchURLsByToken removeObjectForKey:token];
            }
        });
    }];
    if (token) {
        [[self pp_ownedPrefetchTokenMap] setObject:[NSSet setWithArray:urls] forKey:token];
    }
}

- (NSMapTable<SDWebImagePrefetchToken *, NSSet<NSString *> *> *)pp_ownedPrefetchTokenMap
{
    if (!self.ownedPrefetchURLsByToken) {
        self.ownedPrefetchURLsByToken = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self.ownedPrefetchURLsByToken;
}

- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit
{
    if (limit <= 0 || self.presentedItems.count == 0) {
        return;
    }

    NSInteger upperBound = MIN((NSInteger)self.presentedItems.count, limit);
    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:(NSUInteger)upperBound];
    for (NSInteger i = 0; i < upperBound; i++) {
        [indexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    }
    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    [self pp_cancelOwnedPrefetchesForIndexPaths:indexPaths];
}

- (void)pp_cancelOwnedPrefetchesForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (indexPaths.count == 0 || self.ownedPrefetchURLsByToken.count == 0) {
        return;
    }

    NSSet<NSString *> *cancelledURLs =
    [NSSet setWithArray:[self pp_imageURLsFromIndexPaths:indexPaths]];
    if (cancelledURLs.count == 0) {
        return;
    }

    NSMutableArray<SDWebImagePrefetchToken *> *tokensToCancel = [NSMutableArray array];
    NSEnumerator<SDWebImagePrefetchToken *> *keyEnumerator =
    self.ownedPrefetchURLsByToken.keyEnumerator;
    SDWebImagePrefetchToken *token = nil;
    while ((token = keyEnumerator.nextObject)) {
        NSSet<NSString *> *tokenURLs = [self.ownedPrefetchURLsByToken objectForKey:token];
        // A batch can be shared by several index paths. Cancel it only when
        // every URL owned by this controller is leaving the prefetch window.
        if ([tokenURLs isSubsetOfSet:cancelledURLs]) {
            [tokensToCancel addObject:token];
        }
    }

    for (SDWebImagePrefetchToken *token in tokensToCancel) {
        [[PPImageLoaderManager shared] cancelPrefetchToken:token];
        [self.ownedPrefetchURLsByToken removeObjectForKey:token];
    }
}

- (void)pp_cancelAllOwnedPrefetches
{
    if (self.ownedPrefetchURLsByToken.count == 0) {
        return;
    }

    NSMutableArray<SDWebImagePrefetchToken *> *tokens = [NSMutableArray array];
    NSEnumerator<SDWebImagePrefetchToken *> *keyEnumerator =
    self.ownedPrefetchURLsByToken.keyEnumerator;
    SDWebImagePrefetchToken *token = nil;
    while ((token = keyEnumerator.nextObject)) {
        [tokens addObject:token];
    }

    [self.ownedPrefetchURLsByToken removeAllObjects];
    for (SDWebImagePrefetchToken *token in tokens) {
        [[PPImageLoaderManager shared] cancelPrefetchToken:token];
    }
}

- (void)collectionView:(UICollectionView *)collectionView
      willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    (void)collectionView;
    if (!self.didEmitFirstVisibleContentSignpost &&
        !self.isShowingSkeleton &&
        self.presentedItems.count > 0) {
        self.didEmitFirstVisibleContentSignpost = YES;
        os_signpost_event_emit(PPDataViewVCPerformanceLog(), OS_SIGNPOST_ID_EXCLUSIVE,
                               "DataViewFirstVisibleContent", "item=%ld", (long)indexPath.item);
    }
    [self pp_animateCellIfNeeded:cell atIndexPath:indexPath];
}

- (void)applySnapshotAnimated:(BOOL)animated
{
    if (!self.viewModel || !self.dataSource) return;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applySnapshotAnimated:animated];
        });
        return;
    }

    os_log_t log = PPDataViewVCPerformanceLog();

    os_signpost_id_t buildSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, buildSignpostID, "ui.snapshotBuild");

    NSDiffableDataSourceSnapshot<NSNumber *, PPUniversalCellViewModel *> *snapshot =
    [NSDiffableDataSourceSnapshot new];

    NSNumber *section = @(self.viewModel.currentSection);
    [snapshot appendSectionsWithIdentifiers:@[section]];
    [snapshot appendItemsWithIdentifiers:self.presentedItems
               intoSectionWithIdentifier:section];

    os_signpost_interval_end(log, buildSignpostID, "ui.snapshotBuild");

    BOOL shouldAnimate = animated && self.view.window != nil;
    if (self.presentedItems.count > 120) {
        shouldAnimate = NO;
    }

    os_signpost_id_t snapshotSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, snapshotSignpostID, "ui.snapshotApply",
                               "animated=%d items=%lu", shouldAnimate, (unsigned long)self.presentedItems.count);
    [self.dataSource applySnapshot:snapshot animatingDifferences:shouldAnimate];
    os_signpost_interval_end(log, snapshotSignpostID, "ui.snapshotApply",
                             "items=%lu", (unsigned long)self.presentedItems.count);

    // Also emit a reload event for general ui update tracking
    os_signpost_id_t reloadSignpostID = os_signpost_id_generate(log);
    os_signpost_event_emit(log, reloadSignpostID, "ui.reload", "itemsCount=%lu", (unsigned long)self.presentedItems.count);
}

- (double)resolvedPriceForViewModel:(PPUniversalCellViewModel *)vm
{
    NSNumber *price = vm.finalPrice ?: vm.price;
    return MAX(0.0, price.doubleValue);
}

- (NSArray<PPUniversalCellViewModel *> *)filteredPresentedItemsFromSourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    // The VM now applies all data-model-level filters (condition, gender, service type,
    // hasOffer, price, sort).  Provider filtering stays presentation-only so it can
    // use the currently loaded marketplace rows without introducing a second query.
    NSArray<PPUniversalCellViewModel *> *items = sourceItems ?: @[];
    PPDataSection section = self.viewModel ? self.viewModel.currentSection : PPDataSectionAds;
    if (![self pp_sectionSupportsProviderFilter:section]) {
        [self clearSelectedProviderForSection:section];
        return items;
    }
    BOOL didClearProvider = [self pp_reconcileSelectedProviderForSection:section sourceItems:items];
    NSString *selectedProviderID = [self selectedProviderIDForSection:section];
    if (selectedProviderID.length == 0) {
        if (didClearProvider) {
            [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:self.view.window != nil];
        }
        return items;
    }

    NSMutableArray<PPUniversalCellViewModel *> *filtered = [NSMutableArray arrayWithCapacity:items.count];
    for (PPUniversalCellViewModel *viewModel in items) {
        NSString *providerID = PPDataViewTrimmedString([self pp_providerIDForViewModel:viewModel]);
        if ([providerID isEqualToString:selectedProviderID]) {
            [filtered addObject:viewModel];
        }
    }
    return filtered.copy;
}

- (void)refreshPresentedItemsAnimated:(BOOL)animated scrollToTop:(BOOL)scrollToTop
{
    // Keep the server-backed view model intact while the screen applies lightweight
    // presentation-only price filtering and sorting for the accessories experience.
    NSArray<PPUniversalCellViewModel *> *sourceItems = self.viewModel.items ?: @[];
    [self pp_prefetchProviderIdentitiesForSection:self.viewModel.currentSection sourceItems:sourceItems];
    self.presentedItems = [self filteredPresentedItemsFromSourceItems:sourceItems];
    PPDataViewMotionReason motionReason = self.pendingMotionReason;
    if (motionReason == PPDataViewMotionReasonNone &&
        !self.didApplyInitialSnapshot &&
        self.presentedItems.count > 0) {
        motionReason = PPDataViewMotionReasonInitialLoad;
    }

    NSInteger motionDirection = self.pendingMotionDirection;
    [self pp_applyPresentedItemsAnimated:animated
                             scrollToTop:scrollToTop
                            motionReason:motionReason
                         motionDirection:motionDirection];

    self.isAwaitingTransitionData = NO;
    self.pendingMotionReason = PPDataViewMotionReasonNone;
    self.pendingMotionDirection = 0;
}

- (void)refreshFilterChipTitles
{
    [self refreshFilterChipTitlesForSection:self.viewModel.currentSection];
}

- (void)refreshFilterChipTitlesForSection:(PPDataSection)section
{
    PPFilterState *state = [self pp_filterStateForSection:section];
    NSArray<PPFilterGroup *> *groups = state.groups;
    NSInteger activeFilterCount = [self pp_activeFilterCountForSection:section];
    [self.sectionsFiltersContainer pp_applyActiveFilterCount:activeFilterCount animated:self.view.window != nil];
    if (section == self.viewModel.currentSection) {
        [self updateFilterCollapseButtonForSection:section
                                          expanded:[self shouldShowFilterChipBarForSection:section]
                                          animated:self.view.window != nil];
    }

    for (NSInteger i = 0; i < (NSInteger)self.filterChips.count && i < (NSInteger)groups.count; i++) {
        PPDropdownFilterChipButton *chip = self.filterChips[i];
        PPFilterGroup *group = groups[i];
        chip.ppUseAccentColor = [self pp_controlIslandUsesAccentColor];
        chip.ppAccentColorOverride = [self pp_controlIslandAccentColor];
        BOOL opensFilterSheet =
            (section == PPDataSectionAccessories) && [group.filterID isEqualToString:PPFilterIDSort];
        NSString *title = opensFilterSheet
            ? (kLang(@"filterPPAction") ?: @"Filter")
            : (group.isActive ? group.selectedTitle : group.title);
        [chip pp_applyChipTitle:title active:group.isActive];
        chip.menu = opensFilterSheet ? nil : [self pp_menuForFilterGroup:group chipIndex:i];
        chip.accessibilityLabel = opensFilterSheet ? (kLang(@"filterPPAction") ?: @"Filter") : group.title;
        chip.accessibilityValue = group.selectedTitle;
        chip.accessibilityTraits = group.isActive
            ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected)
            : UIAccessibilityTraitButton;
    }
}





- (NSString *)titleForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:         return kLang(@"Ads");
        case PPDataSectionAccessories: return kLang(@"Accessories");
        case PPDataSectionFood:        return kLang(@"Food");
        case PPDataSectionServices:    return kLang(@"services");
        default:                       return @"";
    }
}







                                          


                                      


                                     













- (NSString *)iconForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:         return @"megaphone";
        case PPDataSectionAccessories: return @"bag";
        case PPDataSectionFood:        return @"cart";
        case PPDataSectionServices:    return @"cross.case";
        default:                       return @"";
    }
}

- (NSString *)selectedIconForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:         return @"megaphone.fill";
        case PPDataSectionAccessories: return @"bag.fill";
        case PPDataSectionFood:        return @"cart.fill";
        case PPDataSectionServices:    return @"cross.case.fill";
        default:                       return [self iconForSection:section];
    }
}

- (UITabBarItem *)tabBarItemForSection:(PPDataSection)section
{
    NSString *title = [self titleForSection:section];
    NSString *iconName = [self iconForSection:section];

    UIImage *icon =
    [UIImage pp_symbolNamed:iconName
                  pointSize:18
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleMedium
                    palette:@[AppPrimaryClr]
               makeTemplate:YES];

    UIImage *selectedIcon =
    [UIImage pp_symbolNamed:[self selectedIconForSection:section]
                  pointSize:19
                     weight:UIImageSymbolWeightBold
                      scale:UIImageSymbolScaleMedium
                    palette:@[AppPrimaryClr]
               makeTemplate:YES];

    UITabBarItem *item =
    [[UITabBarItem alloc] initWithTitle:title
                                  image:icon
                          selectedImage:selectedIcon];
    item.tag = section;
    return item;
}

- (UIImage *)sectionsSelectionIndicatorImage
{
    CGSize size = self.lastSectionsIndicatorSize;
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        size = CGSizeMake(72.0, PPCurrentSectionsTabBarHeight());
    }
    CGFloat radius = 18.0;
    UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:size];

    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGRect rect = CGRectInset((CGRect){CGPointZero, size}, 2.0, 2.0);
        UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
        [[AppPrimaryClr colorWithAlphaComponent:0.12] setFill];
        [path fill];
        [[UIColor colorWithWhite:1.0 alpha:0.22] setStroke];
        path.lineWidth = 1.0;
        [path stroke];
    }];

    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(radius + 2.0,
                                                               radius + 2.0,
                                                               radius + 2.0,
                                                               radius + 2.0)
                                 resizingMode:UIImageResizingModeStretch];
}

- (void)updateSectionsTabBarSelectionIndicatorIfNeeded
{
    return;
}

- (void)configureSectionTabBarAppearance:(UITabBarAppearance *)appearance
{
    if (!appearance) {
        return;
    }

    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.30];
    appearance.shadowColor = UIColor.clearColor;

    NSDictionary *normalAttributes = @{
        NSFontAttributeName : [GM MidFontWithSize:14],
        NSForegroundColorAttributeName : UIColor.secondaryLabelColor
    };
    NSDictionary *selectedAttributes = @{
        NSFontAttributeName : [GM boldFontWithSize:14],
        NSForegroundColorAttributeName : AppPrimaryClr
    };

    NSArray<UITabBarItemAppearance *> *appearances = @[
        appearance.stackedLayoutAppearance,
        appearance.inlineLayoutAppearance,
        appearance.compactInlineLayoutAppearance
    ];

    for (UITabBarItemAppearance *itemAppearance in appearances) {
        itemAppearance.normal.iconColor = UIColor.secondaryLabelColor;
        itemAppearance.selected.iconColor = AppPrimaryClr;
        itemAppearance.normal.titleTextAttributes = normalAttributes;
        itemAppearance.selected.titleTextAttributes = selectedAttributes;
        itemAppearance.normal.titlePositionAdjustment = UIOffsetMake(0, 0.0);
        itemAppearance.selected.titlePositionAdjustment = UIOffsetMake(0, 0.0);
    }
}

- (void)updateSectionsTabBarSelectionForSection:(PPDataSection)section
{
    [self updateSectionsTabBarSelectionForSection:section animated:NO];
}

- (NSInteger)pp_segmentIndexForSection:(PPDataSection)section
{
    NSArray<NSNumber *> *orderedSections = PPDataViewSectionPresentationOrder();
    NSUInteger index = [orderedSections indexOfObject:@(section)];
    if (index == NSNotFound) {
        return 0;
    }
    return (NSInteger)index;
}

- (PPDataSection)pp_sectionForSegmentIndex:(NSInteger)segmentIndex
{
    NSArray<NSNumber *> *orderedSections = PPDataViewSectionPresentationOrder();
    if (segmentIndex < 0 || segmentIndex >= (NSInteger)orderedSections.count) {
        return PPDataSectionAccessories;
    }
    return (PPDataSection)orderedSections[(NSUInteger)segmentIndex].integerValue;
}

- (void)updateSectionsTabBarSelectionForSection:(PPDataSection)section animated:(BOOL)animated
{
    if (!self.sectionsSegmentedControl || self.sectionsSegmentedControl.numberOfSegments == 0) {
        return;
    }

    NSInteger selectedIndex = [self pp_segmentIndexForSection:section];
    if (selectedIndex < 0 || selectedIndex >= self.sectionsSegmentedControl.numberOfSegments) {
        selectedIndex = 0;
    }

    [self.sectionsSegmentedControl setSelectedIndex:selectedIndex animated:animated];
}

- (void)activateSection:(PPDataSection)section userInitiated:(BOOL)userInitiated
{
    if (section < PPDataSectionAds || section > PPDataSectionServices) {
        return;
    }

    os_log_t log = PPDataViewVCPerformanceLog();
    os_signpost_id_t switchSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, switchSignpostID, "section.switch", "fromSection=%ld toSection=%ld", (long)self.viewModel.currentSection, (long)section);

    BOOL isSameSection = (section == self.viewModel.currentSection);
    BOOL shouldSwitchSection = !isSameSection || self.viewModel.items.count == 0;

    [self updateSectionsTabBarSelectionForSection:section animated:userInitiated];

    if (userInitiated) {
        [PPFunc triggerLightHaptic];
    }

    // Clear previous empty state after the section control has accepted the tap.
    [PPEmptyStateHelper removeEmptyStateFromListView:self.collectionView];

    if (!shouldSwitchSection) {
        if (userInitiated) {
            [self pp_applyFeedbackPulseToView:self.sectionsSegmentedControl];
        }
        [self scrollCollectionViewToTopAfterReload:YES];
        os_signpost_interval_end(log, switchSignpostID, "section.switch", "status=no_switch");
        return;
    }

    if (!isSameSection) {
        [self saveCurrentSectionScrollOffset];
    }

    PPDataViewMotionReason motionReason =
        (!self.didApplyInitialSnapshot && self.presentedItems.count == 0)
        ? PPDataViewMotionReasonInitialLoad
        : PPDataViewMotionReasonSectionChange;
    NSInteger motionDirection = (section > self.viewModel.currentSection) ? 1 : ((section < self.viewModel.currentSection) ? -1 : 0);
    [self pp_beginMotionTransition:motionReason direction:motionDirection];

    [self persistSectionSelection:section];
    [self updateCartButtonVisibilityForSection:section animated:NO];
    [self.viewModel setFilterState:[self pp_filterStateForSection:section] forSection:section];

    BOOL userChangedLayout = [[NSUserDefaults standardUserDefaults] boolForKey:@"PPLayoutModeChangedByUser"];
    if (!userChangedLayout) {
        PPManagerCellLayoutMode defaultMode = (section == PPDataSectionAds) ? PPCellLayoutModePinterest : PPCellLayoutModeVertical;
        if (self.layoutManager.currentLayoutMode != defaultMode) {
            [self pp_applyLayoutModeInternal:defaultMode
                               saveToDefaults:NO
                                      animated:NO];
        }
    }

    [self.viewModel switchToSection:section];
    [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:userInitiated];

    os_signpost_interval_end(log, switchSignpostID, "section.switch", "status=switched");
}

- (BOOL)sectionHasFilterChipBarForSection:(PPDataSection)section
{
    return [self pp_filterStateForSection:section].groups.count > 0;
}

- (BOOL)shouldShowFilterChipBarForSection:(PPDataSection)section
{
    return [self sectionHasFilterChipBarForSection:section] && !self.filterBadgesCollapsed;
}

- (void)syncFilterChipsForCurrentSection
{
    [self syncFilterChipsForSection:self.viewModel.currentSection];
}

- (void)syncFilterChipsForSection:(PPDataSection)section
{
    PPFilterState *state = [self pp_filterStateForSection:section];
    NSArray<PPFilterGroup *> *groups = state.groups;
    BOOL usesAccessoryFilterRow = (section == PPDataSectionAccessories);

    self.filterChipStackView.distribution = usesAccessoryFilterRow
        ? UIStackViewDistributionFill
        : UIStackViewDistributionFillEqually;

    if (!self.filterChips) {
        self.filterChips = [NSMutableArray array];
    }

    NSInteger existingCount = self.filterChips.count;
    NSInteger targetCount = groups.count;

    // 1. Remove extra chips if targetCount < existingCount
    if (existingCount > targetCount) {
        for (NSInteger i = existingCount - 1; i >= targetCount; i--) {
            PPDropdownFilterChipButton *chip = self.filterChips[i];
            [self.filterChipStackView removeArrangedSubview:chip];
            [chip removeFromSuperview];
            [self.filterChips removeObjectAtIndex:i];
        }
    }

    // 2. Configure or create chips
    for (NSInteger i = 0; i < targetCount; i++) {
        PPFilterGroup *group = groups[i];
        BOOL opensFilterSheet =
            usesAccessoryFilterRow && [group.filterID isEqualToString:PPFilterIDSort];
        
        PPDropdownFilterChipButton *chip = nil;
        if (i < self.filterChips.count) {
            chip = self.filterChips[i];
            [chip removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        } else {
            chip = [[PPDropdownFilterChipButton alloc] init];
            [self.filterChips addObject:chip];
            [self.filterChipStackView addArrangedSubview:chip];
        }

        chip.chipIconName = opensFilterSheet ? @"line.3.horizontal.decrease.circle.fill" : group.chipIconName;
        chip.ppHidesTrailingChevron = opensFilterSheet;
        chip.ppUsesActionSurface = opensFilterSheet;
        chip.ppUseAccentColor = [self pp_controlIslandUsesAccentColor];
        chip.ppAccentColorOverride = [self pp_controlIslandAccentColor];
        chip.tag = i;
        chip.enabled = YES;
        chip.alpha = 1.0;
        chip.showsMenuAsPrimaryAction = !opensFilterSheet;
        
        if (opensFilterSheet) {
            chip.menu = nil;
            [chip addTarget:self action:@selector(openFilters) forControlEvents:UIControlEventTouchUpInside];
            
            NSLayoutConstraint *widthConstraint = nil;
            for (NSLayoutConstraint *c in chip.constraints) {
                if (c.firstAttribute == NSLayoutAttributeWidth && c.relation == NSLayoutRelationEqual) {
                    widthConstraint = c;
                    break;
                }
            }
            if (widthConstraint) {
                widthConstraint.constant = 96.0;
                widthConstraint.active = YES;
            } else {
                [chip.widthAnchor constraintEqualToConstant:96.0].active = YES;
            }
            [chip setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [chip setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        } else {
            chip.menu = [self pp_menuForFilterGroup:group chipIndex:i];
            for (NSLayoutConstraint *c in chip.constraints) {
                if (c.firstAttribute == NSLayoutAttributeWidth) {
                    c.active = NO;
                }
            }
            [chip setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
            [chip setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        }
        if (group.filterID.length > 0) {
            chip.accessibilityIdentifier = [NSString stringWithFormat:@"pp.dataView.filter.%@", group.filterID];
        }
    }

    [self refreshFilterChipTitlesForSection:section];
}

- (void)updateFilterChipVisibilityForSection:(PPDataSection)section animated:(BOOL)animated
{
    if (!self.filterChipContainer || !self.filterChipHeightConstraint) {
        return;
    }

    BOOL canShowFilters = [self sectionHasFilterChipBarForSection:section];
    BOOL shouldShow = [self shouldShowFilterChipBarForSection:section];
    [self syncFilterChipsForSection:section];
    NSInteger activeFilterCount = canShowFilters ? [self pp_activeFilterCountForSection:section] : 0;
    [self.sectionsFiltersContainer pp_applyActiveFilterCount:activeFilterCount animated:animated && self.view.window != nil];
    [self updateFilterContextBarForSection:section];
    [self updateProviderFilterChipForSection:section expanded:shouldShow animated:animated];
    [self updateFilterCollapseButtonForSection:section expanded:shouldShow animated:animated];

    self.filterChipContainer.hidden = NO;
    if (shouldShow && animated && self.filterChipContainer.alpha <= 0.01 && !UIAccessibilityIsReduceMotionEnabled()) {
        self.filterChipContainer.transform = CGAffineTransformMakeTranslation(0.0, -5.0);
    }

    void (^layoutChanges)(void) = ^{
        self.filterChipTopConstraint.constant = shouldShow ? kPPFilterIslandExpandedRowSpacing : 0.0;
        self.filterChipHeightConstraint.constant = shouldShow ? kPPAccessoryFilterHeight : 0.0;
        self.filterChipStackHeightConstraint.constant = shouldShow ? kPPAccessoryFilterHeight - 4.0 : 0.0;
        self.filterChipContainer.alpha = shouldShow ? 1.0 : 0.0;
        self.filterChipContainer.transform = shouldShow
            ? CGAffineTransformIdentity
            : (UIAccessibilityIsReduceMotionEnabled()
               ? CGAffineTransformIdentity
               : CGAffineTransformMakeTranslation(0.0, -5.0));
        [self.view layoutIfNeeded];
    };

    if (!animated || self.view.window == nil) {
        layoutChanges();
        self.filterChipContainer.hidden = !shouldShow;
        [self pp_updateCollectionContentInsetPreservingTopAnchor];
        return;
    }

    UIViewAnimationOptions options =
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction |
        UIViewAnimationOptionCurveEaseInOut;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:options
                         animations:layoutChanges
                         completion:^(__unused BOOL finished) {
            self.filterChipContainer.hidden = !shouldShow;
            [self pp_updateCollectionContentInsetPreservingTopAnchor];
        }];
        return;
    }

    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:options
                     animations:layoutChanges
                     completion:^(__unused BOOL finished) {
        self.filterChipContainer.hidden = !shouldShow;
        [self pp_updateCollectionContentInsetPreservingTopAnchor];
    }];
}

- (void)pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:(BOOL)animated
{
    if (!self.viewModel || !self.providerFilterChipButton) {
        [self updateCollectionContentInset];
        return;
    }

    BOOL shouldAnimate = animated && self.view.window != nil;
    [self updateFilterContextBarForSection:self.viewModel.currentSection];
    [self updateFilterChipVisibilityForSection:self.viewModel.currentSection animated:shouldAnimate];

    [self.providerFilterChipTitleLabel invalidateIntrinsicContentSize];
    [self.providerFilterChipRatingLabel invalidateIntrinsicContentSize];
    [self.providerFilterChipSubtitleLabel invalidateIntrinsicContentSize];
    [self.providerFilterChipButton setNeedsLayout];
    [self.sectionsFiltersContainer setNeedsLayout];
    [self pp_updatePremiumChromeShadowPaths];
    [self pp_updateCollectionContentInsetPreservingTopAnchor];
}

- (void)updateFilterContextBarForSection:(PPDataSection)section
{
    if (!self.filterContextBar || !self.filterContextLabel) {
        return;
    }

    NSString *title = [self filterContextTitleForSection:section];
    self.filterContextLabel.text = title;
    self.filterContextBarHeightConstraint.constant = kPPFilterContextBarHeight;
    self.filterContextBar.hidden = NO;
    self.filterContextBar.alpha = 1.0;
    self.filterContextBar.accessibilityLabel = title;
    [self pp_applyFilterContextBarAppearance];
}

- (void)updateProviderFilterChipForSection:(PPDataSection)section
                                  expanded:(BOOL)expanded
                                  animated:(BOOL)animated
{
    if (!self.providerFilterChipButton || !self.providerFilterChipHeightConstraint) {
        return;
    }

    BOOL supportsProviderFilter = [self pp_sectionSupportsProviderFilter:section];
    if (!supportsProviderFilter) {
        [self clearSelectedProviderForSection:section];
    }
    NSArray<OptionModel *> *providerOptions =
        supportsProviderFilter ? [self providerOptionsForSection:section sourceItems:self.viewModel.items ?: @[]] : @[];
    NSInteger providerCount = providerOptions.count;
    BOOL shouldShow = supportsProviderFilter && expanded && providerCount > 0;
    [self pp_applyProviderChipContentForSection:section providerCount:providerCount];
    self.providerFilterChipTopConstraint.constant = shouldShow ? kPPFilterIslandExpandedRowSpacing : 0.0;
    self.providerFilterChipHeightConstraint.constant = shouldShow ? kPPProviderFilterChipHeight : 0.0;
    self.providerFilterChipButton.accessibilityElementsHidden = !shouldShow;
    self.providerFilterChipButton.hidden = NO;

    void (^updates)(void) = ^{
        self.providerFilterChipButton.alpha = shouldShow ? 1.0 : 0.0;
        self.providerFilterChipButton.transform = shouldShow
            ? CGAffineTransformIdentity
            : (UIAccessibilityIsReduceMotionEnabled()
               ? CGAffineTransformIdentity
               : CGAffineTransformMakeTranslation(0.0, -4.0));
        [self.view layoutIfNeeded];
    };

    if (!animated || self.view.window == nil || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
        self.providerFilterChipButton.hidden = !shouldShow;
        return;
    }

    [UIView animateWithDuration:0.28
                          delay:0.0
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseInOut
                     animations:updates
                     completion:^(__unused BOOL finished) {
        self.providerFilterChipButton.hidden = !shouldShow;
    }];
}

- (void)providerFilterChipTapped:(UIButton *)sender
{
    if (![self pp_sectionSupportsProviderFilter:self.viewModel.currentSection]) {
        return;
    }
    NSArray<OptionModel *> *options = [self providerOptionsForCurrentSection];
    if (options.count == 0) {
        [PPHUD showInfo:kLang(@"dataview_provider_filter_empty_message") ?: @""];
        return;
    }

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.10
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                         animations:^{
            sender.transform = CGAffineTransformMakeScale(0.985, 0.985);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.18
                                  delay:0.0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                             animations:^{
                sender.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    }

    PPDataSection section = self.viewModel.currentSection;
    NSString *selectedProviderID = [self selectedProviderIDForSection:section];
    __weak typeof(self) weakSelf = self;
    NSMutableArray<NSString *> *providerIDs = [NSMutableArray arrayWithCapacity:options.count];
    for (OptionModel *option in options) {
        NSString *providerID = PPDataViewTrimmedString(option.optID);
        if (providerID.length > 0) {
            [providerIDs addObject:providerID];
        }
    }

    [self pp_hydrateProviderIdentitiesForIDs:providerIDs section:section completion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        NSArray<OptionModel *> *hydratedOptions = [self providerOptionsForSection:section
                                                                      sourceItems:self.viewModel.items ?: @[]];
        if (hydratedOptions.count == 0) {
            [PPHUD showInfo:kLang(@"dataview_provider_filter_empty_message") ?: @""];
            return;
        }

        OptionModel *selectedOption = nil;
        for (OptionModel *option in hydratedOptions) {
            if (selectedProviderID.length > 0 &&
                [PPDataViewTrimmedString(option.optID) isEqualToString:selectedProviderID]) {
                selectedOption = option;
                break;
            }
        }
        [self pp_presentProviderFilterSheetForSection:section
                                              options:hydratedOptions
                                       selectedOption:selectedOption];
    }];
}

- (void)pp_presentProviderFilterSheetForSection:(PPDataSection)section
                                        options:(NSArray<OptionModel *> *)options
                                 selectedOption:(OptionModel *)selectedOption
{
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc =
    [[PPSelectOptionViewController alloc] initWithOptions:options
                                                    title:kLang(@"dataview_provider_sheet_title")
                                                      row:nil
                                        presentationStyle:PPSelectOptionPresentationSheet
                                            showSearchBar:NO
                                               completion:^(id  _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![selectedObject isKindOfClass:OptionModel.class]) {
                return;
            }
            OptionModel *option = (OptionModel *)selectedObject;
            NSString *currentProviderID = [self selectedProviderIDForSection:section];
            NSString *optionProviderID = PPDataViewTrimmedString(option.optID);
            if (currentProviderID.length > 0 && [currentProviderID isEqualToString:optionProviderID]) {
                [self clearSelectedProviderForSection:section];
            } else {
                [self setSelectedProviderID:optionProviderID forSection:section];
            }
            [self refreshPresentedItemsAnimated:YES scrollToTop:YES];
            [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:YES];
            [self updateEmptyState];
        });
    }];
    vc.selectedOption = selectedOption;
    vc.usesCompactPremiumHero = YES;
    vc.usesCompactOptionIcons = YES;
    vc.useUsersOption = YES;
    vc.preferredPremiumDetentFraction = options.count > 6 ? 0.74 : 0.62;
    vc.premiumHeroAccentColor = PPDataViewProviderPillAccentColor(self.traitCollection);
    [vc configurePremiumHeroWithEyebrow:kLang(@"dataview_provider_sheet_eyebrow")
                                  title:kLang(@"dataview_provider_sheet_title")
                               subtitle:kLang(@"dataview_provider_sheet_subtitle")
                             symbolName:@"storefront.fill"
                              badgeText:[NSString stringWithFormat:kLang(@"dataview_provider_sheet_badge_format"), (long)options.count]];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (NSString *)filterContextTitleForSection:(PPDataSection)section
{
    NSString *selectedProviderID = [self selectedProviderIDForSection:section];
    if ([self pp_sectionSupportsProviderFilter:section] && selectedProviderID.length > 0) {
        for (OptionModel *option in [self providerOptionsForCurrentSection]) {
            if ([PPDataViewTrimmedString(option.optID) isEqualToString:selectedProviderID]) {
                NSString *format = kLang(@"dataview_filter_context_selected_provider_format");
                return format.length > 0
                    ? [NSString stringWithFormat:format, option.title ?: @""]
                    : option.title;
            }
        }
        NSString *providerTitle = [self pp_realProviderTitleForID:selectedProviderID
                                                       sourceItems:self.viewModel.items ?: @[]];
        if (providerTitle.length > 0) {
            NSString *format = kLang(@"dataview_filter_context_selected_provider_format");
            return format.length > 0
                ? [NSString stringWithFormat:format, providerTitle]
                : providerTitle;
        }
    }

    NSString *key = @"dataview_filter_context_products";
    if (section == PPDataSectionAds) {
        key = @"dataview_filter_context_listings";
    } else if (section == PPDataSectionServices) {
        key = @"dataview_filter_context_services";
    }

    NSString *localized = kLang(key);
    return localized.length > 0 ? localized : @"All provider products";
}

- (BOOL)pp_sectionSupportsProviderFilter:(PPDataSection)section
{
    return section == PPDataSectionAccessories || section == PPDataSectionFood;
}

- (NSArray<OptionModel *> *)providerOptionsForCurrentSection
{
    PPDataSection section = self.viewModel ? self.viewModel.currentSection : PPDataSectionAds;
    NSArray<PPUniversalCellViewModel *> *sourceItems = self.viewModel.items ?: @[];
    return [self providerOptionsForSection:section sourceItems:sourceItems];
}

- (NSArray<OptionModel *> *)providerOptionsForSection:(PPDataSection)section
                                           sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    if (![self pp_sectionSupportsProviderFilter:section]) {
        return @[];
    }
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *providersByID = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *orderedIDs = [NSMutableArray array];
    for (PPUniversalCellViewModel *viewModel in sourceItems ?: @[]) {
        if (viewModel.isSkeleton) {
            continue;
        }
        NSString *providerID = [self pp_providerIDForViewModel:viewModel];
        if (providerID.length == 0) {
            continue;
        }
        NSMutableDictionary<NSString *, id> *entry = providersByID[providerID];
        if (!entry) {
            NSString *title = [self pp_realProviderTitleForID:providerID sourceItems:@[viewModel]];
            NSString *photoURL = [self pp_providerPhotoURLForViewModel:viewModel fallbackID:providerID];
            entry = [@{
                @"title": title.length > 0 ? title : providerID,
                @"photoURL": photoURL ?: @"",
                @"count": @0
            } mutableCopy];
            providersByID[providerID] = entry;
            [orderedIDs addObject:providerID];
            [self pp_hydrateProviderIdentitiesForIDs:@[providerID] section:section completion:nil];
        } else if (PPDataViewTrimmedString(entry[@"photoURL"]).length == 0) {
            NSString *photoURL = [self pp_providerPhotoURLForViewModel:viewModel fallbackID:providerID];
            if (photoURL.length > 0) {
                entry[@"photoURL"] = photoURL;
            }
        }
        NSInteger count = [entry[@"count"] integerValue] + 1;
        entry[@"count"] = @(count);
    }

    [orderedIDs sortUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        NSInteger leftCount = [providersByID[left][@"count"] integerValue];
        NSInteger rightCount = [providersByID[right][@"count"] integerValue];
        if (leftCount != rightCount) {
            return leftCount > rightCount ? NSOrderedAscending : NSOrderedDescending;
        }
        NSString *leftTitle = providersByID[left][@"title"] ?: @"";
        NSString *rightTitle = providersByID[right][@"title"] ?: @"";
        return [leftTitle localizedCaseInsensitiveCompare:rightTitle];
    }];

    NSMutableArray<OptionModel *> *options = [NSMutableArray arrayWithCapacity:orderedIDs.count];
    for (NSString *providerID in orderedIDs) {
        NSDictionary<NSString *, id> *entry = providersByID[providerID];
        NSInteger count = [entry[@"count"] integerValue];
        NSString *photoURL = PPDataViewTrimmedString(entry[@"photoURL"]);
        OptionModel *option =
        [[OptionModel alloc] initWithID:providerID
                                  title:entry[@"title"] ?: providerID
                               subtitle:[self pp_providerSheetSubtitleForCount:count]
                              imageName:photoURL.length > 0 ? photoURL : nil
                        systemImageName:photoURL.length > 0 ? nil : @"storefront.fill"];
        option.sortOrder = options.count;
        [options addObject:option];
    }
    return options.copy;
}

- (NSString *)selectedProviderIDForSection:(PPDataSection)section
{
    NSString *providerID = self.selectedProviderIDsBySection[@(section)];
    return PPDataViewTrimmedString(providerID);
}

- (void)setSelectedProviderID:(NSString *)providerID forSection:(PPDataSection)section
{
    if (![self pp_sectionSupportsProviderFilter:section]) {
        [self clearSelectedProviderForSection:section];
        return;
    }
    if (!self.selectedProviderIDsBySection) {
        self.selectedProviderIDsBySection = [NSMutableDictionary dictionary];
    }
    NSString *cleanProviderID =
    [providerID isKindOfClass:NSString.class]
    ? [providerID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
    : @"";
    if (cleanProviderID.length == 0) {
        [self clearSelectedProviderForSection:section];
        return;
    }
    self.selectedProviderIDsBySection[@(section)] = cleanProviderID;
}

- (void)clearSelectedProviderForSection:(PPDataSection)section
{
    [self.selectedProviderIDsBySection removeObjectForKey:@(section)];
}

- (BOOL)pp_reconcileSelectedProviderForSection:(PPDataSection)section
                                   sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    if (![self pp_sectionSupportsProviderFilter:section]) {
        BOOL hadSelection = ([self selectedProviderIDForSection:section].length > 0);
        [self clearSelectedProviderForSection:section];
        return hadSelection;
    }

    NSString *selectedProviderID = [self selectedProviderIDForSection:section];
    if (selectedProviderID.length == 0) {
        return NO;
    }

    for (PPUniversalCellViewModel *viewModel in sourceItems ?: @[]) {
        NSString *providerID = PPDataViewTrimmedString([self pp_providerIDForViewModel:viewModel]);
        if ([providerID isEqualToString:selectedProviderID]) {
            return NO;
        }
    }
    [self clearSelectedProviderForSection:section];
    return YES;
}

- (void)pp_applyProviderChipContentForSection:(PPDataSection)section providerCount:(NSInteger)providerCount
{
    if (!self.providerFilterChipButton) {
        return;
    }

    NSString *selectedProviderID = [self selectedProviderIDForSection:section];
    NSString *title = kLang(@"dataview_filter_by_provider");
    NSString *subtitle = providerCount > 0
        ? [NSString stringWithFormat:kLang(@"dataview_provider_filter_count_format"), (long)providerCount]
        : kLang(@"dataview_provider_filter_empty_title");
    NSString *ratingText = @"";
    NSArray<OptionModel *> *providerOptions =
        [self providerOptionsForSection:section sourceItems:self.viewModel.items ?: @[]];

    if (selectedProviderID.length > 0) {
        for (OptionModel *option in providerOptions) {
            if ([PPDataViewTrimmedString(option.optID) isEqualToString:selectedProviderID]) {
                NSString *realTitle = [self pp_realProviderTitleForID:selectedProviderID
                                                           sourceItems:self.viewModel.items ?: @[]];
                NSString *optionTitle = PPDataViewTrimmedString(option.title);
                BOOL optionTitleLooksReal =
                    optionTitle.length > 0 &&
                    ![optionTitle isEqualToString:selectedProviderID] &&
                    ![self pp_providerTitleIsGeneric:optionTitle providerID:selectedProviderID];
                title = realTitle.length > 0 ? realTitle : (optionTitleLooksReal ? optionTitle : title);
                subtitle = kLang(@"dataview_provider_filter_selected_subtitle");
                ratingText = [self pp_providerRatingBadgeTextForProviderID:selectedProviderID
                                                                sourceItems:self.viewModel.items ?: @[]] ?: @"";
                break;
            }
        }
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = self.providerFilterChipButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        configuration.image = nil;
        configuration.title = @"";
        configuration.subtitle = @"";
        self.providerFilterChipButton.configuration = configuration;
    } else {
        [self.providerFilterChipButton setTitle:@"" forState:UIControlStateNormal];
        [self.providerFilterChipButton setImage:nil forState:UIControlStateNormal];
    }
    self.providerFilterChipTitleLabel.text = title;
    self.providerFilterChipSubtitleLabel.text = subtitle;
    self.providerFilterChipRatingLabel.text = ratingText;
    self.providerFilterChipRatingLabel.hidden = (ratingText.length == 0);
    [self.providerFilterChipTitleLabel invalidateIntrinsicContentSize];
    [self.providerFilterChipRatingLabel invalidateIntrinsicContentSize];
    [self.providerFilterChipSubtitleLabel invalidateIntrinsicContentSize];
    UIImageSymbolConfiguration *iconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                        weight:UIImageSymbolWeightBold
                                                         scale:UIImageSymbolScaleSmall];
    NSString *symbolName = selectedProviderID.length > 0 ? @"checkmark.seal.fill" : @"storefront.fill";
    self.providerFilterChipTrailingIconView.image =
        [[UIImage systemImageNamed:symbolName withConfiguration:iconConfig]
         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (selectedProviderID.length > 0) {
        self.providerFilterChipTrailingIconView.tintColor = [UIColor colorWithRed:0.31 green:0.86 blue:0.57 alpha:1.0];
    } else {
        self.providerFilterChipTrailingIconView.tintColor = [self pp_controlIslandAccentColor];
    }
    [self pp_updateProviderChipAvatarForProviderID:selectedProviderID
                                             title:title
                                       sourceItems:self.viewModel.items ?: @[]];
    self.providerFilterChipButton.accessibilityLabel =
        ratingText.length > 0 ? [NSString stringWithFormat:@"%@ %@", title, ratingText] : title;
    self.providerFilterChipButton.accessibilityHint = subtitle;
}

- (NSString *)pp_providerRatingBadgeTextForProviderID:(NSString *)providerID
                                          sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    if (providerID.length == 0) {
        return @"";
    }

    double rating = 0.0;
    UserModel *cachedUser = [UserManager userModelForID:providerID];
    if (cachedUser.providerRatingValue > 0.0) {
        rating = cachedUser.providerRatingValue;
    }

    if (rating <= 0.0) {
        for (PPUniversalCellViewModel *viewModel in sourceItems ?: @[]) {
            NSString *itemProviderID = [self pp_providerIDForViewModel:viewModel];
            if (![itemProviderID isEqualToString:providerID]) {
                continue;
            }
            id model = viewModel.ModelObject;
            NSArray<NSString *> *ratingSelectors = @[
                @"providerRatingValue",
                @"providerRating",
                @"averageProviderRating",
                @"ownerRatingValue",
                @"sellerRatingValue"
            ];
            for (NSString *selectorName in ratingSelectors) {
                SEL selector = NSSelectorFromString(selectorName);
                if (![model respondsToSelector:selector]) {
                    continue;
                }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id value = [model performSelector:selector];
#pragma clang diagnostic pop
                if ([value respondsToSelector:@selector(doubleValue)] && [value doubleValue] > 0.0) {
                    rating = [value doubleValue];
                    break;
                }
            }
            if (rating > 0.0) {
                break;
            }
        }
    }

    if (rating <= 0.0) {
        return @"";
    }
    rating = MAX(0.0, MIN(5.0, rating));
    NSString *ratingValue = [NSString stringWithFormat:@"%.1f", rating];
    return [NSString stringWithFormat:@"  ★ %@  ", ratingValue];
}

- (NSString *)pp_providerIDForViewModel:(PPUniversalCellViewModel *)viewModel
{
    id model = viewModel.ModelObject;
    if ([model isKindOfClass:PetAd.class]) {
        return PPDataViewTrimmedString(((PetAd *)model).ownerID);
    }
    if ([model isKindOfClass:PetAccessory.class]) {
        return PPDataViewTrimmedString(((PetAccessory *)model).ownerID);
    }
    if ([model isKindOfClass:ServiceModel.class]) {
        return PPDataViewTrimmedString(((ServiceModel *)model).serviceOwnerID);
    }
    NSArray<NSString *> *selectors = @[@"ownerID", @"providerID", @"providerId", @"userID", @"sellerID"];
    for (NSString *selectorName in selectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([model respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id value = [model performSelector:selector];
#pragma clang diagnostic pop
            NSString *providerID = PPDataViewTrimmedString(value);
            if (providerID.length > 0) {
                return providerID;
            }
        }
    }
    return @"";
}

- (NSString *)pp_providerTitleForViewModel:(PPUniversalCellViewModel *)viewModel fallbackID:(NSString *)providerID
{
    NSCharacterSet *trimSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *cleanProviderID = [providerID isKindOfClass:NSString.class]
        ? [providerID stringByTrimmingCharactersInSet:trimSet]
        : @"";
    BOOL (^isDisplayableName)(NSString *) = ^BOOL(NSString *value) {
        NSString *trimmed = [value isKindOfClass:NSString.class]
            ? [value stringByTrimmingCharactersInSet:trimSet]
            : @"";
        if (trimmed.length == 0) {
            return NO;
        }
        return cleanProviderID.length == 0 || ![trimmed isEqualToString:cleanProviderID];
    };

    id model = viewModel.ModelObject;
    if ([model isKindOfClass:PetAd.class]) {
        NSString *ownerName = [((PetAd *)model).ownerName stringByTrimmingCharactersInSet:trimSet] ?: @"";
        if (isDisplayableName(ownerName)) {
            return ownerName;
        }
    }

    NSArray<NSString *> *selectors = @[
        @"providerDisplayName",
        @"providerName",
        @"providerBusinessName",
        @"ownerDisplayName",
        @"ownerName",
        @"sellerDisplayName",
        @"sellerName",
        @"storeName",
        @"shopName",
        @"companyName",
        @"CompanyName",
        @"businessName",
        @"legalName"
    ];
    for (NSString *selectorName in selectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([model respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id value = [model performSelector:selector];
#pragma clang diagnostic pop
            if ([value isKindOfClass:NSString.class]) {
                NSString *title = [(NSString *)value stringByTrimmingCharactersInSet:trimSet];
                if (isDisplayableName(title)) {
                    return title;
                }
            }
        }
    }

    if ([model isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = (NSDictionary *)model;
        NSArray<NSString *> *keys = @[
            @"providerDisplayName",
            @"providerName",
            @"providerBusinessName",
            @"ownerDisplayName",
            @"ownerName",
            @"sellerDisplayName",
            @"sellerName",
            @"storeName",
            @"shopName",
            @"companyName",
            @"CompanyName",
            @"businessName",
            @"legalName"
        ];
        for (NSString *key in keys) {
            id value = dictionary[key];
            if ([value isKindOfClass:NSString.class]) {
                NSString *title = [(NSString *)value stringByTrimmingCharactersInSet:trimSet];
                if (isDisplayableName(title)) {
                    return title;
                }
            }
        }
    }

    if (cleanProviderID.length > 0) {
        NSDictionary<NSString *, NSString *> *cachedIdentity = [self pp_cachedProviderIdentityForProviderID:cleanProviderID];
        NSString *identityTitle = PPDataViewTrimmedString(cachedIdentity[PPDataViewProviderIdentityTitleKey]);
        if (identityTitle.length > 0 && isDisplayableName(identityTitle)) {
            return identityTitle;
        }

        UserModel *cachedUser = [UserManager userModelForID:cleanProviderID];
        if (!cachedUser) {
            cachedUser = [UserManager userModelFromUsersArrayForID:cleanProviderID];
        }
        NSArray<NSString *> *cachedNames = @[
            cachedUser.UserName ?: @"",
            cachedUser.FirstName.length > 0 && cachedUser.LastName.length > 0
                ? [NSString stringWithFormat:@"%@ %@", cachedUser.FirstName, cachedUser.LastName]
                : @"",
            cachedUser.FirstName ?: @"",
            [cachedUser respondsToSelector:@selector(bestDisplayName)]
                ? ([cachedUser bestDisplayName] ?: @"")
                : @""
        ];
        for (NSString *candidate in cachedNames) {
            NSString *title = [candidate stringByTrimmingCharactersInSet:trimSet];
            if (isDisplayableName(title)) {
                return title;
            }
        }
    }

    NSString *genericProviderTitle = kLang(@"service_view_provider_title");
    return genericProviderTitle.length > 0 ? genericProviderTitle : @"Provider";
}

- (NSString *)pp_providerPhotoURLForProviderID:(NSString *)providerID
                                   sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    if (providerID.length == 0) {
        return @"";
    }

    UserModel *cachedUser = [UserManager userModelForID:providerID];
    if (!cachedUser) {
        cachedUser = [UserManager userModelFromUsersArrayForID:providerID];
    }
    NSString *cachedURL = cachedUser.UserImageUrl.absoluteString ?: @"";
    if (cachedURL.length > 0) {
        return cachedURL;
    }
    NSDictionary<NSString *, NSString *> *cachedIdentity = [self pp_cachedProviderIdentityForProviderID:providerID];
    NSString *identityPhotoURL = PPDataViewTrimmedString(cachedIdentity[PPDataViewProviderIdentityPhotoURLKey]);
    if (identityPhotoURL.length > 0) {
        return identityPhotoURL;
    }

    for (PPUniversalCellViewModel *viewModel in sourceItems ?: @[]) {
        NSString *itemProviderID = [self pp_providerIDForViewModel:viewModel];
        if ([itemProviderID isEqualToString:providerID]) {
            NSString *photoURL = [self pp_providerPhotoURLForViewModel:viewModel fallbackID:providerID];
            if (photoURL.length > 0) {
                return photoURL;
            }
        }
    }
    return @"";
}

- (NSString *)pp_providerPhotoURLForViewModel:(PPUniversalCellViewModel *)viewModel
                                   fallbackID:(NSString *)providerID
{
    if (providerID.length > 0) {
        UserModel *cachedUser = [UserManager userModelForID:providerID];
        if (!cachedUser) {
            cachedUser = [UserManager userModelFromUsersArrayForID:providerID];
        }
        NSString *cachedURL = cachedUser.UserImageUrl.absoluteString ?: @"";
        if (cachedURL.length > 0) {
            return cachedURL;
        }
        NSDictionary<NSString *, NSString *> *cachedIdentity = [self pp_cachedProviderIdentityForProviderID:providerID];
        NSString *identityPhotoURL = PPDataViewTrimmedString(cachedIdentity[PPDataViewProviderIdentityPhotoURLKey]);
        if (identityPhotoURL.length > 0) {
            return identityPhotoURL;
        }
    }

    id model = viewModel.ModelObject;
    NSArray<NSString *> *selectors = @[
        @"providerImageURL",
        @"providerImageUrl",
        @"providerPhotoURL",
        @"providerPhotoUrl",
        @"providerLogoURL",
        @"providerLogoUrl",
        @"ownerImageURL",
        @"ownerImageUrl",
        @"ownerPhotoURL",
        @"ownerPhotoUrl",
        @"ownerLogoURL",
        @"ownerLogoUrl",
        @"sellerImageURL",
        @"sellerImageUrl",
        @"sellerPhotoURL",
        @"sellerPhotoUrl",
        @"storeImageURL",
        @"storeImageUrl",
        @"storeLogoURL",
        @"storeLogoUrl",
        @"companyLogoURL",
        @"companyLogoUrl"
    ];
    for (NSString *selectorName in selectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([model respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id value = [model performSelector:selector];
#pragma clang diagnostic pop
            if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
                return value;
            }
            if ([value isKindOfClass:NSURL.class] && [(NSURL *)value absoluteString].length > 0) {
                return [(NSURL *)value absoluteString];
            }
        }
    }
    return @"";
}

- (NSString *)pp_displayTitleForProviderUser:(UserModel *)user fallbackID:(NSString *)providerID
{
    if (![user isKindOfClass:UserModel.class]) {
        return @"";
    }

    NSCharacterSet *trimSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    if ([user respondsToSelector:@selector(bestDisplayName)]) {
        NSString *bestName = [user bestDisplayName] ?: @"";
        if (bestName.length > 0) {
            [candidates addObject:bestName];
        }
    }
    if (user.UserName.length > 0) {
        [candidates addObject:user.UserName];
    }
    if (user.FirstName.length > 0 && user.LastName.length > 0) {
        [candidates addObject:[NSString stringWithFormat:@"%@ %@", user.FirstName, user.LastName]];
    }
    if (user.FirstName.length > 0) {
        [candidates addObject:user.FirstName];
    }

    for (NSString *candidate in candidates) {
        NSString *title = [candidate stringByTrimmingCharactersInSet:trimSet] ?: @"";
        if (title.length > 0 && ![self pp_providerTitleIsGeneric:title providerID:providerID]) {
            return title;
        }
    }
    return @"";
}

- (BOOL)pp_providerTitleIsGeneric:(NSString *)title providerID:(NSString *)providerID
{
    NSString *cleanTitle = PPDataViewTrimmedString(title);
    if (cleanTitle.length == 0) {
        return YES;
    }

    NSString *cleanProviderID = PPDataViewTrimmedString(providerID);
    if (cleanProviderID.length > 0 && [cleanTitle isEqualToString:cleanProviderID]) {
        return YES;
    }
    if (cleanProviderID.length > 0 && [cleanTitle isEqualToString:[self pp_shortProviderIdentifier:cleanProviderID]]) {
        return YES;
    }

    NSMutableArray<NSString *> *genericTitles = [NSMutableArray arrayWithObjects:
        @"Provider",
        @"Service Provider",
        @"مقدم الخدمة",
        @"مزود",
        nil];
    NSArray<NSString *> *localizedKeys = @[
        @"service_view_provider_title",
        @"dataview_filter_by_provider"
    ];
    for (NSString *key in localizedKeys) {
        NSString *localized = PPDataViewTrimmedString(kLang(key));
        if (localized.length > 0) {
            [genericTitles addObject:localized];
        }
    }

    for (NSString *generic in genericTitles) {
        if ([cleanTitle localizedCaseInsensitiveCompare:generic] == NSOrderedSame) {
            return YES;
        }
    }
    return NO;
}

- (NSDictionary<NSString *, NSString *> *)pp_cachedProviderIdentityForProviderID:(NSString *)providerID
{
    NSString *cleanProviderID = PPDataViewTrimmedString(providerID);
    if (cleanProviderID.length == 0) {
        return nil;
    }
    if (!self.providerIdentityCache) {
        self.providerIdentityCache = [NSMutableDictionary dictionary];
    }

    NSDictionary<NSString *, NSString *> *cached = self.providerIdentityCache[cleanProviderID];
    if (cached.count > 0) {
        return cached;
    }

    UserModel *cachedUser = [UserManager userModelForID:cleanProviderID];
    if (!cachedUser) {
        cachedUser = [UserManager userModelFromUsersArrayForID:cleanProviderID];
    }
    NSString *title = [self pp_displayTitleForProviderUser:cachedUser fallbackID:cleanProviderID];
    NSString *photoURL = PPDataViewTrimmedString(cachedUser.UserImageUrl);
    if (title.length > 0 || photoURL.length > 0) {
        [self pp_storeProviderIdentityForProviderID:cleanProviderID title:title photoURL:photoURL];
    }
    return self.providerIdentityCache[cleanProviderID];
}

- (void)pp_storeProviderIdentityForProviderID:(NSString *)providerID
                                        title:(NSString *)title
                                     photoURL:(NSString *)photoURL
{
    NSString *cleanProviderID = PPDataViewTrimmedString(providerID);
    if (cleanProviderID.length == 0) {
        return;
    }
    if (!self.providerIdentityCache) {
        self.providerIdentityCache = [NSMutableDictionary dictionary];
    }

    NSMutableDictionary<NSString *, NSString *> *merged =
        [self.providerIdentityCache[cleanProviderID] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *cleanTitle = PPDataViewTrimmedString(title);
    NSString *cleanPhotoURL = PPDataViewTrimmedString(photoURL);
    if (cleanTitle.length > 0 && ![self pp_providerTitleIsGeneric:cleanTitle providerID:cleanProviderID]) {
        merged[PPDataViewProviderIdentityTitleKey] = cleanTitle;
    }
    if (cleanPhotoURL.length > 0) {
        merged[PPDataViewProviderIdentityPhotoURLKey] = cleanPhotoURL;
    }
    if (merged.count > 0) {
        self.providerIdentityCache[cleanProviderID] = merged.copy;
    }
}

- (void)pp_fetchProviderIdentityForProviderID:(NSString *)providerID
                                      section:(PPDataSection)section
                                   completion:(dispatch_block_t)completion
{
    NSString *cleanProviderID = PPDataViewTrimmedString(providerID);
    if (cleanProviderID.length == 0) {
        if (completion) completion();
        return;
    }

    if (!self.providerIdentityFetchesInFlight) {
        self.providerIdentityFetchesInFlight = [NSMutableSet set];
    }
    if (!self.providerIdentityHydratedProviderIDs) {
        self.providerIdentityHydratedProviderIDs = [NSMutableSet set];
    }
    BOOL prefetchOnly = (completion == nil);
    if (prefetchOnly && [self.providerIdentityHydratedProviderIDs containsObject:cleanProviderID]) {
        return;
    }
    if (prefetchOnly && [self.providerIdentityFetchesInFlight containsObject:cleanProviderID]) {
        return;
    }
    [self.providerIdentityFetchesInFlight addObject:cleanProviderID];

    NSDictionary<NSString *, NSString *> *cached = [self pp_cachedProviderIdentityForProviderID:cleanProviderID];
    __block NSString *resolvedTitle = PPDataViewTrimmedString(cached[PPDataViewProviderIdentityTitleKey]);
    __block NSString *resolvedPhotoURL = PPDataViewTrimmedString(cached[PPDataViewProviderIdentityPhotoURLKey]);

    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    [[UserManager sharedManager] getUserWithUID:cleanProviderID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        if (!error && [user isKindOfClass:UserModel.class]) {
            NSString *userTitle = [self pp_displayTitleForProviderUser:user fallbackID:cleanProviderID];
            NSString *userPhotoURL = PPDataViewTrimmedString(user.UserImageUrl);
            if (userTitle.length > 0) {
                resolvedTitle = userTitle;
            }
            if (userPhotoURL.length > 0) {
                resolvedPhotoURL = userPhotoURL;
            }
        }
        dispatch_group_leave(group);
    }];

    NSString *profileID = [NSString stringWithFormat:@"%@_%@", cleanProviderID, @"marketplace"];
    FIRDocumentReference *profileRef =
        [[[FIRFirestore firestore] collectionWithPath:@"providerProfiles"] documentWithPath:profileID];
    dispatch_group_enter(group);
    [profileRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!error && snapshot.exists) {
            NSDictionary *data = [snapshot.data isKindOfClass:NSDictionary.class] ? snapshot.data : @{};
            NSDictionary *form = [data[@"form"] isKindOfClass:NSDictionary.class] ? data[@"form"] : @{};
            NSDictionary *userSummary = [data[@"userSummary"] isKindOfClass:NSDictionary.class] ? data[@"userSummary"] : @{};

            NSString *profileTitle = PPDataViewTrimmedString(form[@"fullName"]);
            if (profileTitle.length == 0) {
                profileTitle = PPDataViewTrimmedString(userSummary[@"displayName"]);
            }
            if (profileTitle.length == 0) {
                profileTitle = PPDataViewTrimmedString(data[@"displayName"]);
            }
            if (profileTitle.length == 0) {
                profileTitle = PPDataViewTrimmedString(form[@"businessName"]);
            }
            if (profileTitle.length == 0) {
                profileTitle = PPDataViewTrimmedString(data[@"businessName"]);
            }

            NSString *profilePhotoURL = PPDataViewTrimmedString(userSummary[@"photoURL"]);
            if (profilePhotoURL.length == 0) {
                profilePhotoURL = PPDataViewTrimmedString(data[@"avatarURL"]);
            }
            if (profilePhotoURL.length == 0) {
                profilePhotoURL = PPDataViewTrimmedString(data[@"photoURL"]);
            }

            if (profileTitle.length > 0 && ![self pp_providerTitleIsGeneric:profileTitle providerID:cleanProviderID]) {
                resolvedTitle = profileTitle;
            }
            if (profilePhotoURL.length > 0) {
                resolvedPhotoURL = profilePhotoURL;
            }
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self.providerIdentityFetchesInFlight removeObject:cleanProviderID];
        [self.providerIdentityHydratedProviderIDs addObject:cleanProviderID];
        [self pp_storeProviderIdentityForProviderID:cleanProviderID
                                             title:resolvedTitle
                                          photoURL:resolvedPhotoURL];
        if (section == self.viewModel.currentSection && self.providerFilterChipButton) {
            [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:self.view.window != nil];
        }
        if (completion) {
            completion();
        }
    });
}

- (void)pp_hydrateProviderIdentitiesForIDs:(NSArray<NSString *> *)providerIDs
                                   section:(PPDataSection)section
                                completion:(dispatch_block_t)completion
{
    NSMutableOrderedSet<NSString *> *uniqueIDs = [NSMutableOrderedSet orderedSet];
    for (NSString *providerID in providerIDs ?: @[]) {
        NSString *cleanProviderID = PPDataViewTrimmedString(providerID);
        if (cleanProviderID.length > 0) {
            [uniqueIDs addObject:cleanProviderID];
        }
    }
    if (uniqueIDs.count == 0) {
        if (completion) completion();
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    for (NSString *providerID in uniqueIDs) {
        if ([self.providerIdentityHydratedProviderIDs containsObject:providerID]) {
            continue;
        }
        dispatch_group_enter(group);
        [self pp_fetchProviderIdentityForProviderID:providerID section:section completion:^{
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion();
        }
    });
}

- (void)pp_prefetchProviderIdentitiesForSection:(PPDataSection)section
                                    sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    if (![self pp_sectionSupportsProviderFilter:section]) {
        return;
    }

    NSMutableOrderedSet<NSString *> *providerIDs = [NSMutableOrderedSet orderedSet];
    for (PPUniversalCellViewModel *viewModel in sourceItems ?: @[]) {
        if (viewModel.isSkeleton) {
            continue;
        }
        NSString *providerID = [self pp_providerIDForViewModel:viewModel];
        if (providerID.length > 0) {
            [providerIDs addObject:providerID];
        }
    }
    [self pp_hydrateProviderIdentitiesForIDs:providerIDs.array section:section completion:nil];
}

- (NSString *)pp_realProviderTitleForID:(NSString *)providerID
                             sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    NSString *cleanProviderID = PPDataViewTrimmedString(providerID);
    if (cleanProviderID.length == 0) {
        return @"";
    }

    NSDictionary<NSString *, NSString *> *identity = [self pp_cachedProviderIdentityForProviderID:cleanProviderID];
    NSString *identityTitle = PPDataViewTrimmedString(identity[PPDataViewProviderIdentityTitleKey]);
    if (identityTitle.length > 0 && ![self pp_providerTitleIsGeneric:identityTitle providerID:cleanProviderID]) {
        return identityTitle;
    }

    for (PPUniversalCellViewModel *viewModel in sourceItems ?: @[]) {
        NSString *itemProviderID = [self pp_providerIDForViewModel:viewModel];
        if (![itemProviderID isEqualToString:cleanProviderID]) {
            continue;
        }
        NSString *title = [self pp_providerTitleForViewModel:viewModel fallbackID:cleanProviderID];
        if (title.length > 0 && ![self pp_providerTitleIsGeneric:title providerID:cleanProviderID]) {
            return title;
        }
    }

    return @"";
}

- (UIImage *)pp_providerPlaceholderImage
{
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:10.8
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleSmall];
        UIImage *disclosure = [UIImage systemImageNamed:@"chevron.down"
                                        withConfiguration:configuration];
        if (disclosure) {
            return [disclosure imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    return [UIImage imageNamed:@"providers.png"] ?: [UIImage imageNamed:@"providers"];
}

- (void)pp_updateProviderChipAvatarForProviderID:(NSString *)providerID
                                           title:(NSString *)title
                                     sourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    if (!self.providerFilterChipAvatarView) {
        return;
    }

    NSString *cleanProviderID = PPDataViewTrimmedString(providerID);
    UIImage *placeholder = nil;
    if (cleanProviderID.length > 0) {
        placeholder = [PPModernAvatarRenderer avatarImageForName:PPDataViewTrimmedString(title)
                                                            size:kPPProviderFilterChipAvatarDiameter];
    }
    placeholder = placeholder ?: [self pp_providerPlaceholderImage];
    self.providerFilterChipAvatarView.image = placeholder;
    self.providerFilterChipAvatarView.contentMode = cleanProviderID.length > 0
        ? UIViewContentModeScaleAspectFit
        : UIViewContentModeCenter;
    self.providerFilterChipAvatarView.tintColor = [self pp_controlIslandContentAccentColor];
    self.providerFilterChipAvatarView.layer.cornerRadius = cleanProviderID.length > 0
        ? kPPProviderFilterChipAvatarDiameter * 0.5
        : 11.0;

    NSString *photoURL = [self pp_providerPhotoURLForProviderID:providerID sourceItems:sourceItems];
    if (cleanProviderID.length == 0 || photoURL.length == 0) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    NSString *expectedProviderID = [providerID copy];
    [PPImageLoaderManager.shared setImageOnImageView:self.providerFilterChipAvatarView
                                                 url:photoURL
                                         placeholder:placeholder
                                          complation:^(__unused UIImage * _Nonnull image,
                                                       __unused NSString * _Nullable urlString) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        NSString *currentProviderID = [self selectedProviderIDForSection:self.viewModel.currentSection];
        if (![currentProviderID isEqualToString:expectedProviderID]) {
            self.providerFilterChipAvatarView.image = [self pp_providerPlaceholderImage];
            return;
        }
        self.providerFilterChipAvatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.providerFilterChipAvatarView.accessibilityLabel = title ?: @"";
    }];
}

- (NSString *)pp_providerSheetSubtitleForCount:(NSInteger)count
{
    NSString *format = (count == 1)
        ? kLang(@"dataview_provider_sheet_item_count_one")
        : kLang(@"dataview_provider_sheet_item_count_many");
    return [NSString stringWithFormat:format, (long)count];
}

- (NSString *)pp_shortProviderIdentifier:(NSString *)providerID
{
    NSString *cleanID = [providerID isKindOfClass:NSString.class] ? providerID : @"";
    if (cleanID.length <= 6) {
        return cleanID.length > 0 ? cleanID : @"--";
    }
    return [cleanID substringToIndex:6];
}

- (void)updateFilterCollapseButtonForSection:(PPDataSection)section expanded:(BOOL)expanded animated:(BOOL)animated
{
    if (!self.filterCollapseButton) {
        return;
    }

    BOOL hasFilters = [self sectionHasFilterChipBarForSection:section];
    NSString *labelKey = expanded
        ? @"dataview_filters_collapse_accessibility"
        : @"dataview_filters_expand_accessibility";
    NSInteger activeFilterCount = [self pp_activeFilterCountForSection:section];
    NSString *baseTitle = kLang(labelKey) ?: @"";
    NSString *titleText = baseTitle;
    if (!expanded && activeFilterCount > 0) {
        NSString *format = kLang(@"dataview_filters_expand_active_count_format");
        titleText = format.length > 0
            ? [NSString stringWithFormat:format, (long)activeFilterCount]
            : [NSString stringWithFormat:@"%@ · %ld", baseTitle ?: @"", (long)activeFilterCount];
    }
    self.filterCollapseButton.accessibilityLabel = baseTitle;
    NSString *activeCountAccessibilityFormat = kLang(@"dataview_filters_active_count_accessibility_format");
    self.filterCollapseButton.accessibilityValue = activeFilterCount > 0 && activeCountAccessibilityFormat.length > 0
        ? [NSString stringWithFormat:activeCountAccessibilityFormat, (long)activeFilterCount]
        : nil;
    self.filterCollapseButton.enabled = hasFilters;
    self.filterCollapseButton.userInteractionEnabled = hasFilters;
    if (hasFilters) {
        self.filterCollapseButton.hidden = NO;
    }

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:11.5
                                                        weight:UIImageSymbolWeightBold
                                                         scale:UIImageSymbolScaleSmall];
    UIImage *chevron = [[UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolConfig]
                        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.filterCollapseButton setImage:chevron forState:UIControlStateNormal];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.filterCollapseButton.configuration;
        UIFont *btnFont =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:([GM boldFontWithSize:11.8] ?: [UIFont systemFontOfSize:11.8 weight:UIFontWeightBold])
                                                                           maximumPointSize:13.2];
        UIColor *titleColor = [self pp_controlIslandUsesAccentColor]
            ? [self pp_controlIslandContentAccentColor]
            : PPDataViewAccentColor();
        config.attributedTitle = [[NSAttributedString alloc] initWithString:titleText attributes:@{
            NSFontAttributeName: btnFont,
            NSForegroundColorAttributeName: titleColor
        }];
        self.filterCollapseButton.configuration = config;
    } else {
        UIFont *btnFont =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:([GM boldFontWithSize:11.8] ?: [UIFont systemFontOfSize:11.8 weight:UIFontWeightBold])
                                                                           maximumPointSize:13.2];
        UIColor *titleColor = [self pp_controlIslandUsesAccentColor]
            ? [self pp_controlIslandContentAccentColor]
            : PPDataViewAccentColor();
        self.filterCollapseButton.titleLabel.font = btnFont;
        [self.filterCollapseButton setTitle:titleText forState:UIControlStateNormal];
        [self.filterCollapseButton setTitleColor:titleColor forState:UIControlStateNormal];
    }

    if ([self.filterCollapseButton isKindOfClass:[PPPremiumCollapseButton class]]) {
        ((PPPremiumCollapseButton *)self.filterCollapseButton).expanded = expanded;
    }

    void (^updates)(void) = ^{
        self.filterCollapseButton.alpha = hasFilters ? 1.0 : 0.0;
        self.filterCollapseButton.imageView.transform = expanded
            ? CGAffineTransformMakeRotation((CGFloat)M_PI)
            : CGAffineTransformIdentity;
    };

    if (!animated || self.view.window == nil || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
        self.filterCollapseButton.hidden = !hasFilters;
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:updates
                     completion:^(__unused BOOL finished) {
        self.filterCollapseButton.hidden = !hasFilters;
    }];
}

- (void)toggleFilterBadgesCollapsed:(id)sender
{
    if (![self sectionHasFilterChipBarForSection:self.viewModel.currentSection]) {
        return;
    }

    self.filterBadgesCollapsed = !self.filterBadgesCollapsed;

    os_log_t log = PPDataViewVCPerformanceLog();
    os_signpost_id_t filterToggleSignpostID = os_signpost_id_generate(log);
    if (!self.filterBadgesCollapsed) {
        os_signpost_interval_begin(log, filterToggleSignpostID, "filter.expand");
    } else {
        os_signpost_interval_begin(log, filterToggleSignpostID, "filter.collapse");
    }

    [PPFunc triggerLightHaptic];
    [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:YES];

    if (!self.filterBadgesCollapsed) {
        os_signpost_interval_end(log, filterToggleSignpostID, "filter.expand");
    } else {
        os_signpost_interval_end(log, filterToggleSignpostID, "filter.collapse");
    }
}

- (void)pp_collapseFilterIslandForUserScrollIfNeededAnimated:(BOOL)animated
{
    if (kPPDataViewPauseLegacyFilterIslandScrollCollapse) {
        return;
    }

    if (self.isRestoringScrollOffset || [self pp_isFullDetailsLayoutMode]) {
        return;
    }

    if (self.filterBadgesCollapsed ||
        ![self sectionHasFilterChipBarForSection:self.viewModel.currentSection]) {
        return;
    }

    self.filterBadgesCollapsed = YES;
    [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:animated];
}

- (void)pp_collapseFilterIslandForFullDetailsIfNeededAnimated:(BOOL)animated
{
    if (!self.didCaptureFilterBadgesCollapsedStateForFullDetails) {
        self.filterBadgesCollapsedBeforeFullDetails = self.filterBadgesCollapsed;
        self.didCaptureFilterBadgesCollapsedStateForFullDetails = YES;
    }

    if (![self sectionHasFilterChipBarForSection:self.viewModel.currentSection]) {
        [self updateCollectionContentInset];
        return;
    }
    if (self.filterBadgesCollapsed) {
        [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
        return;
    }

    self.filterBadgesCollapsed = YES;
    [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:animated];
}

- (void)pp_restoreFilterIslandAfterLeavingFullDetailsIfNeededAnimated:(BOOL)animated
{
    if (self.didCaptureFilterBadgesCollapsedStateForFullDetails) {
        self.filterBadgesCollapsed = self.filterBadgesCollapsedBeforeFullDetails;
        self.didCaptureFilterBadgesCollapsedStateForFullDetails = NO;
        self.filterBadgesCollapsedBeforeFullDetails = NO;
    }

    [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:animated];
}

// ---------- Dynamic filter menu builder ----------

- (UIMenu *)pp_menuForFilterGroup:(PPFilterGroup *)group chipIndex:(NSInteger)chipIndex
{
    __weak typeof(self) weakSelf = self;
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    for (PPFilterOption *opt in group.options) {
        NSString *optionIconName = [opt.iconName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        UIImageSymbolConfiguration *optionIconConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleSmall];
        UIImage *optionImage = PPDataViewFilterIconImage(optionIconName, optionIconConfig, nil);
        UIAction *action =
        [UIAction actionWithTitle:opt.title
                            image:optionImage
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull act) {
            [weakSelf pp_filterGroupChangedToValue:opt.value forGroupAtIndex:chipIndex];
        }];
        action.state = (group.selectedValue == opt.value) ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:action];
    }
    return [UIMenu menuWithTitle:@"" children:actions];
}

- (void)pp_filterGroupChangedToValue:(NSInteger)value forGroupAtIndex:(NSInteger)chipIndex
{
    PPFilterState *state = [self pp_currentFilterState];
    if (chipIndex < 0 || chipIndex >= (NSInteger)state.groups.count) return;

    PPFilterGroup *group = state.groups[chipIndex];
    group.selectedValue = value;

    os_log_t log = PPDataViewVCPerformanceLog();
    os_signpost_id_t applyFilterSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, applyFilterSignpostID, "filter.apply", "filterID=%{public}@", group.filterID ?: @"");

    [PPFunc triggerLightHaptic];
    self.pendingFilterScrollToTop = YES;
    [self.viewModel applyFilterState:state];

    os_signpost_interval_end(log, applyFilterSignpostID, "filter.apply");
}

- (PPFilterState *)pp_currentFilterState
{
    PPDataSection section = self.viewModel ? self.viewModel.currentSection : PPDataSectionAds;
    return [self pp_filterStateForSection:section];
}

- (PPFilterState *)pp_filterStateForSection:(PPDataSection)section
{
    if (!self.filterStates) {
        self.filterStates = [NSMutableDictionary dictionary];
    }

    NSNumber *key = @(section);
    PPFilterState *state = self.filterStates[key];
    if (!state) {
        state = [self pp_freshFilterStateForSection:section];
        self.filterStates[key] = state;
    } else if (section == PPDataSectionAccessories) {
        PPFilterGroup *categoryGroup = [state groupForID:PPFilterIDAccessoryCategory];
        PPFilterGroup *legacyPriceGroup = [state groupForID:PPFilterIDPrice];
        if ((!categoryGroup || categoryGroup.options.count <= 1) &&
            [self pp_accessoryFilterCategoriesForCurrentContext].count > 0) {
            state = [self pp_freshFilterStateForSection:section];
            self.filterStates[key] = state;
        } else if (legacyPriceGroup) {
            state = [self pp_freshFilterStateForSection:section];
            self.filterStates[key] = state;
        }
    }
    return state;
}

- (NSInteger)pp_activeFilterCountForSection:(PPDataSection)section
{
    if (![self sectionHasFilterChipBarForSection:section]) {
        return 0;
    }

    NSInteger count = [self pp_filterStateForSection:section].activeFilterCount;
    if ([self pp_sectionSupportsProviderFilter:section] &&
        [self selectedProviderIDForSection:section].length > 0) {
        count += 1;
    }
    return count;
}

- (PPFilterState *)pp_freshFilterStateForSection:(PPDataSection)section
{
    if (section == PPDataSectionAccessories) {
        return [PPFilterConfigProvider accessoriesFilterStateWithCategories:[self pp_accessoryFilterCategoriesForCurrentContext]];
    }
    return [PPFilterConfigProvider defaultFilterStateForSection:section];
}

- (NSArray<PPAccessoryCategoryModel *> *)pp_accessoryFilterCategoriesForCurrentContext
{
    NSMutableArray<PPAccessoryCategoryModel *> *categories = [NSMutableArray array];
    MainKindsModel *mainKind = self.input.mainKind;

    if (mainKind && self.input.sourceTarget != PPDeepLinkTargetAllCategories) {
        NSArray<PPAccessoryCategoryModel *> *cachedCategories =
            [[MainKindsArrayManager shared] accessoryCategoriesForMainKindID:mainKind.ID] ?: @[];
        [categories addObjectsFromArray:cachedCategories.count > 0 ? cachedCategories : (mainKind.accessoryCategories ?: @[])];
    } else {
        NSArray<MainKindsModel *> *sourceKinds = [MainKindsArrayManager shared].MainKindsArray.count > 0
            ? [MainKindsArrayManager shared].MainKindsArray
            : (self.input.mainKindsArr ?: @[]);
        for (MainKindsModel *kind in sourceKinds) {
            [categories addObjectsFromArray:kind.accessoryCategories ?: @[]];
        }
    }

    NSMutableArray<PPAccessoryCategoryModel *> *uniqueCategories = [NSMutableArray arrayWithCapacity:categories.count];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];
    for (PPAccessoryCategoryModel *category in categories) {
        NSString *categoryID = category.categoryID.length > 0 ? category.categoryID : category.documentID;
        if (categoryID.length == 0 || [seenIDs containsObject:categoryID]) {
            continue;
        }
        [seenIDs addObject:categoryID];
        [uniqueCategories addObject:category];
    }
    return uniqueCategories.copy;
}

#pragma mark - Custom Navigation Center View

- (NSString *)pp_currentMainKindsDisplayTitle
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        return self.input.title.length > 0 ? self.input.title : (kLang(@"All") ?: @"All");
    }

    NSString *title = self.input.mainKind.KindName;
    if (title.length == 0) {
        title = self.input.mainKind.KindNameEn;
    }
    return title.length > 0 ? title : (kLang(@"All") ?: @"All");
}

- (NSString *)pp_currentSubKindsDisplayTitle
{
    if (self.viewModel.currentSubKindID == 0) {
        return kLang(@"All") ?: @"All";
    }

    SubKindModel *subKind = [self.input.mainKind subKindForID:self.viewModel.currentSubKindID];
    NSString *title = subKind.SubKindName;
    return title.length > 0 ? title : (kLang(@"All") ?: @"All");
}

// Updates the main kinds button title in the navigation bar
- (void)updateNavMainKindTitle
{
    if (!self.KindsButton) return;
    [self pp_updateMainKindsButtonTitleAnimated:(self.pendingMotionReason == PPDataViewMotionReasonMainKindChange)];
}

- (void)pp_updateMainKindsButtonTitleAnimated:(BOOL)animated
{
    NSString *title = [self pp_currentMainKindsDisplayTitle];

    void (^applyMainKindChange)(void) = ^{
        [self pp_applyPremiumMainKindsButtonSurface];
        self.KindsButton.accessibilityLabel =
        [NSString stringWithFormat:@"%@, %@", [self pp_mainKindsSelectorCaption], title];
        [self.KindsButton invalidateIntrinsicContentSize];
        [self pp_syncExperimentalCenterCapsuleState];
        [self reloadNavigationCenterViewLayout];
    };

    if (animated && [self pp_allowsPremiumMotion]) {
        [self pp_applyNavigationChangeAnimationToButton:self.KindsButton updates:applyMainKindChange];
        [self pp_applyFeedbackPulseToView:self.KindsButton];
    } else {
        applyMainKindChange();
    }
}


-(UIMenu *)mainMenu
{
    return  [PPHomeHelper MainKindsMenuWithHandler:^(MainKindsModel *model) {
        // 1️⃣ Ignore if same main kind
        if (model.ID == self.input.mainKind.ID) {
            return;
        }

        self.input.mainKind = model;
        [self.filterStates removeObjectForKey:@(PPDataSectionAccessories)];
        self.KindsButton.menu = [self mainMenu];

        [self pp_beginMotionTransition:PPDataViewMotionReasonMainKindChange direction:0];
        self.viewModel.currentSubKindID = 0;

        if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
            self.input.sourceTarget = PPDeepLinkTargetNone;
            [self pp_setSubKindsChevronHidden:NO];
        }
        self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;

        [self updateNavMainKindTitle];
        [self updateSubKindsButtonTitle:[self pp_currentSubKindsDisplayTitle] animated:YES];
        [self refreshsubKindsMenu];

        [self reloadNavigationCenterViewLayout];

        // 4️⃣ Clear saved scroll positions (VERY IMPORTANT)
        [self.scrollOffsetsBySection removeAllObjects];

        // 5️⃣ Reset layout cache (Pinterest safety)
        [self resetLayoutForSectionChange];

        // 6️⃣ Restore last selected section for this MainKind
        NSString *key = [self sectionKeyForMainKind:model];
        PPDataSection lastSection =
        (PPDataSection)[[NSUserDefaults standardUserDefaults] integerForKey:key];

        if (lastSection >= PPDataSectionAds &&
            lastSection <= PPDataSectionServices) {
            self.viewModel.pendingRestoreSection = lastSection;

            [self updateSectionsTabBarSelectionForSection:lastSection];
            [self updateCartButtonVisibilityForSection:lastSection];
        }

        [self.viewModel switchToMainKind:model];
        [[NovaAmbientAssistantCoordinator sharedCoordinator] categoryDidOpen:model.KindName ?: model.KindNameEn];
        [self prefetchSubKindIcons];

    }];
}
// Modified to add a second navigation button: sectionsButton
-(void)setupKindsView
{
    _navContainerView = [PPDataViewNavigationMaterialView new];
    self.navContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.navContainerView.isAccessibilityElement = NO;

    self.KindsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.KindsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.KindsButton.showsMenuAsPrimaryAction = YES;
    self.KindsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.KindsButton.accessibilityLabel =
    [NSString stringWithFormat:@"%@, %@", [self pp_mainKindsSelectorCaption], [self pp_currentMainKindsDisplayTitle]];
    self.KindsButton.accessibilityTraits = UIAccessibilityTraitButton;
    self.KindsButton.menu = [self mainMenu];
    self.KindsButton.layer.actions = @{
        @"position" : [NSNull null],
        @"bounds"   : [NSNull null],
        @"transform": [NSNull null],
        @"opacity"  : [NSNull null]
    };
 
 
    UIButton *sectionsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    sectionsBtn.translatesAutoresizingMaskIntoConstraints = NO;

    // Configuration (iOS 16+ best practice)
    UIButtonConfiguration *cfg;
    if (@available(iOS 26.0, *)) {
        cfg = [UIButtonConfiguration plainButtonConfiguration];
    } else {
        cfg = [UIButtonConfiguration plainButtonConfiguration];
    }
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(3, 10, 2, 10);
    cfg.imagePadding = 2;
    cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
    cfg.baseForegroundColor = UIColor.labelColor;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.background.cornerRadius = kPPDataViewSelectorCornerRadius;


    UIImage *chevron =
    [UIImage pp_symbolNamed:@"chevron.down" pointSize:16 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClr] makeTemplate:NO];
    cfg.image = chevron;

    sectionsBtn.configuration = cfg;
    sectionsBtn.showsMenuAsPrimaryAction = YES;
   // sectionsBtn.menu = [self subKindsMenu];

    // HARD LOCK against navbar / layout animations
    sectionsBtn.layer.actions = @{
        @"position" : [NSNull null],
        @"bounds"   : [NSNull null],
        @"transform": [NSNull null],
        @"opacity"  : [NSNull null]
    };

    // Content rules (no jumps, RTL safe)
    sectionsBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    sectionsBtn.titleLabel.numberOfLines = 1;
    sectionsBtn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    // Assign
    self.subKindsButton = sectionsBtn;
    self.subKindsButton.accessibilityTraits = UIAccessibilityTraitButton;

    self.KindsButton.configuration = cfg;
    self.subKindsButton.configuration = cfg;
    
    if (!PPIOS26()) {
        self.KindsButton.layer.cornerRadius = kPPDataViewSelectorCornerRadius;
        self.KindsButton.clipsToBounds = YES;
        self.subKindsButton.layer.cornerRadius = kPPDataViewSelectorCornerRadius;
        self.subKindsButton.clipsToBounds = YES;
    }

    self.subKindsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.centerCapsuleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.centerCapsuleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.centerCapsuleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.centerCapsuleButton.showsMenuAsPrimaryAction = YES;
    self.centerCapsuleButton.hidden = YES;
    self.centerCapsuleButton.layer.actions = @{
        @"position" : [NSNull null],
        @"bounds"   : [NSNull null],
        @"transform": [NSNull null],
        @"opacity"  : [NSNull null]
    };
    UIColor *capsuleAccentColor = AppPrimaryClr ?: PPDataViewChromeTextColor();
    UIButtonConfiguration *capsuleConfiguration = [UIButtonConfiguration plainButtonConfiguration];
    capsuleConfiguration.background.strokeWidth = 0.0;
    capsuleConfiguration.background.strokeColor = UIColor.clearColor;
    capsuleConfiguration.background.backgroundColor = [capsuleAccentColor colorWithAlphaComponent:0.00];
    capsuleConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(4.0, 12.0, 4.0, 12.0);
    capsuleConfiguration.imagePadding = 6.0;
    capsuleConfiguration.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
    capsuleConfiguration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    self.centerCapsuleButton.configuration = capsuleConfiguration;

    self.cartButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cartButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cartButton.showsMenuAsPrimaryAction = NO;
    self.cartButton.menu = nil;
    self.cartButton.hidden = YES;
    self.cartButton.alpha = 0.0;
    self.cartButton.userInteractionEnabled = NO;
    self.cartButton.accessibilityElementsHidden = YES;

    if (!PPIOS26()) {
        self.cartButton.layer.cornerRadius = 20;
        self.cartButton.clipsToBounds = YES;
    }


    self.mainKindsWidthConstraint =
    [self.KindsButton.widthAnchor constraintEqualToConstant:112];
    self.sectionsWidthConstraint =
    [self.subKindsButton.widthAnchor constraintEqualToConstant:140];
    self.cartButtonWidthConstraint =
    [self.cartButton.widthAnchor constraintEqualToConstant:1.0];
    self.navContainerWidthConstraint =
    [self.navContainerView.widthAnchor constraintEqualToConstant:267];
    self.centerCapsuleMinWidthConstraint =
    [self.centerCapsuleButton.widthAnchor constraintGreaterThanOrEqualToConstant:140.0];
    self.mainKindsWidthConstraint.priority = UILayoutPriorityRequired;
    self.sectionsWidthConstraint.priority = UILayoutPriorityRequired;
    self.cartButtonWidthConstraint.priority = UILayoutPriorityRequired;
    self.navContainerWidthConstraint.priority = UILayoutPriorityRequired;
    self.centerCapsuleMinWidthConstraint.priority = UILayoutPriorityRequired;
    self.mainKindsWidthConstraint.active = YES;
    self.sectionsWidthConstraint.active = YES;
    self.cartButtonWidthConstraint.active = YES;
    self.navContainerWidthConstraint.active = YES;
    self.centerCapsuleMinWidthConstraint.active = YES;

    self.navSeparatorLine = [UIView new];
    self.navSeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    self.navSeparatorLine.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.35] ?: [UIColor colorWithWhite:0.5 alpha:0.3];
    self.navSeparatorLine.hidden = self.useCapsuleNavigation;

    [self.navContainerView addSubview:self.KindsButton];
    [self.navContainerView addSubview:self.navSeparatorLine];
    [self.navContainerView addSubview:self.subKindsButton];
    [self.navContainerView addSubview:self.centerCapsuleButton];
    [self.navContainerView addSubview:self.cartButton];

    // Legacy center action retained hidden; search now lives in the right navbar slot.
 
    
    CGFloat inset = 3.0;
    self.subKindsTrailingToCartConstraint =
    [self.subKindsButton.trailingAnchor constraintEqualToAnchor:self.cartButton.leadingAnchor constant:-inset];
    self.subKindsTrailingToContainerConstraint =
    [self.subKindsButton.trailingAnchor constraintEqualToAnchor:self.navContainerView.trailingAnchor constant:-inset];
    self.subKindsTrailingToContainerConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        // Vertical
        [self.KindsButton.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:inset],
        [self.KindsButton.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-inset],
        [self.subKindsButton.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:inset],
        [self.subKindsButton.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-inset],
        [self.cartButton.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:inset],
        [self.cartButton.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-inset],

        // Separator vertical layout in center
        [self.navSeparatorLine.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:12.0],
        [self.navSeparatorLine.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-12.0],
        [self.navSeparatorLine.widthAnchor constraintEqualToConstant:1.0],

        // Horizontal (Kinds → Separator → SubKinds)
        [self.KindsButton.leadingAnchor constraintEqualToAnchor:self.navContainerView.leadingAnchor constant:inset],
        [self.cartButton.trailingAnchor constraintEqualToAnchor:self.navContainerView.trailingAnchor constant:-inset],
        [self.KindsButton.trailingAnchor constraintEqualToAnchor:self.navSeparatorLine.leadingAnchor  constant:-4.0],
        [self.navSeparatorLine.trailingAnchor constraintEqualToAnchor:self.subKindsButton.leadingAnchor constant:-4.0],

        [self.centerCapsuleButton.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:4.0],
        [self.centerCapsuleButton.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-4.0],
        [self.centerCapsuleButton.centerXAnchor constraintEqualToAnchor:self.navContainerView.centerXAnchor],
        [self.centerCapsuleButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.navContainerView.leadingAnchor constant:inset],
        [self.centerCapsuleButton.trailingAnchor constraintLessThanOrEqualToAnchor:self.cartButton.leadingAnchor constant:-inset],

        // Height
        [self.navContainerView.heightAnchor constraintEqualToConstant:46.0]
    ]];
    

    // Width is recalculated against the live navigation bar to avoid compact-screen overlap.
   
    
    sectionsBtn.menu = [self subKindsMenu];
    
    self.viewModel.currentSubKindID = 0;
    [self updateNavMainKindTitle];
    [self updateSubKindsButtonTitle:[self pp_currentSubKindsDisplayTitle]];

    // AllCategories mode: show the section header title & hide chevron until user picks a kind
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        [self updateNavMainKindTitle];
        [self updateSubKindsButtonTitle:kLang(@"All") ?: @"All"];
        [self pp_setSubKindsChevronHidden:YES];
    }

    sectionsBtn.menu = [self subKindsMenu];
    [self pp_applyPremiumNavigationChromeAppearance];
    [self pp_syncExperimentalCenterCapsuleState];
    [self updateCartButtonVisibility];
}

// Centralized nav resize logic (single source of truth)

- (void)reloadNavigationCenterViewLayout
{
    [UIView performWithoutAnimation:^{
        if (!self.navContainerView) {
            return;
        }

        CGFloat targetWidth = [self preferredNavigationCenterViewWidth];
        if (targetWidth > 0.0) {
            self.navContainerWidthConstraint.constant = targetWidth;
            CGRect frame = self.navContainerView.frame;
            frame.size = CGSizeMake(targetWidth, 46.0);
            self.navContainerView.frame = frame;
            self.navContainerView.bounds = (CGRect){CGPointZero, frame.size};
        }

        // ✅ FORCE layout pass FIRST (fixes AllKinds → first switch)
        [self.navContainerView layoutIfNeeded];

        [self.KindsButton invalidateIntrinsicContentSize];
        [self.subKindsButton invalidateIntrinsicContentSize];
        [self.cartButton invalidateIntrinsicContentSize];

        CGFloat visibleChromeWidth = MAX(176.0, self.navContainerWidthConstraint.constant);
        CGFloat outerInset = 3.0;
        CGFloat separatorGap = 4.0;
        CGFloat separatorWidth = 1.0;
        CGFloat cartWidth = self.isCartButtonVisible ? 36.0 : 1.0;
        CGFloat fixedChromeWidth = (outerInset * 2.0) + (separatorGap * 2.0) + separatorWidth;
        if (self.isCartButtonVisible) {
            fixedChromeWidth += outerInset + cartWidth;
        }
        CGFloat availableSelectorWidth = MAX(0.0, visibleChromeWidth - fixedChromeWidth);
        CGFloat mainWidth = floor(availableSelectorWidth * 0.5);
        CGFloat sectionWidth = MAX(0.0, availableSelectorWidth - mainWidth);

        self.mainKindsWidthConstraint.constant = mainWidth;
        self.sectionsWidthConstraint.constant = sectionWidth;

        [self.navContainerView setNeedsLayout];
        [self.navContainerView layoutIfNeeded];
    }];
}

- (CGFloat)preferredNavigationCenterViewWidth
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar) {
        return 220.0;
    }

    CGFloat navBarWidth = CGRectGetWidth(navigationBar.bounds);
    if (navBarWidth <= 0.0) {
        return self.navContainerWidthConstraint.constant > 0.0 ? self.navContainerWidthConstraint.constant : 220.0;
    }

    CGFloat leftWidth = [self pp_widthForBarButtonItem:self.navigationItem.leftBarButtonItem fallback:40.0];
    CGFloat rightWidth = [self pp_widthForBarButtonItem:self.navigationItem.rightBarButtonItem fallback:40.0];
    UIEdgeInsets layoutMargins = navigationBar.layoutMargins;
    CGFloat sideMargins = layoutMargins.left + layoutMargins.right;
    CGFloat breathingRoom = 20.0;

    CGFloat availableWidth = navBarWidth - sideMargins - leftWidth - rightWidth - breathingRoom;
    if (availableWidth <= 0.0) {
        return self.navContainerWidthConstraint.constant > 0.0 ? self.navContainerWidthConstraint.constant : 220.0;
    }

    CGFloat resolvedWidth = floor(availableWidth);
    if (resolvedWidth < 218.0) {
        return MAX(176.0, resolvedWidth);
    }
    return MIN(resolvedWidth, 292.0);
}

- (CGFloat)pp_widthForBarButtonItem:(UIBarButtonItem *)item fallback:(CGFloat)fallback
{
    if (!item) {
        return fallback;
    }

    UIView *customView = item.customView;
    if (customView) {
        CGFloat width = CGRectGetWidth(customView.bounds);
        if (width <= 0.0) {
            CGSize fittingSize = [customView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
            width = fittingSize.width;
        }
        if (width > 0.0) {
            return ceil(width);
        }
    }

    if (item.width > 0.0) {
        return item.width;
    }

    return fallback;
}
- (UIButton *)glassButtonWithTitle:(NSString *)title menu:(UIMenu *)menu iconNamed:(NSString *)icon dataViewNavBarButtonKind:(PPDataViewNavBarButtonKind)buttonKind
{
    UIButton *btn = [PPButtonHelper pp_buttonForDataVCNavBar:title imageName:icon target:self dataViewNavBarButtonKind:buttonKind];
    btn.translatesAutoresizingMaskIntoConstraints = NO;

    
    UIColor *color = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.85];

    btn.layer.masksToBounds = YES;
    btn.clipsToBounds = YES;
    
    UIImage *img = [UIImage pp_symbolNamed:icon pointSize:16 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:buttonKind == PPDataViewNavBarButtonKindSections ? @[AppForgroundColr] : @[color]  makeTemplate:YES];
    [btn setImage:img forState:UIControlStateNormal];
    UIButtonConfiguration *cfg;
    if (@available(iOS 26.0, *)) {
        cfg = UIButtonConfiguration.glassButtonConfiguration;
    } else {
        // Fallback on earlier versions
    }
    cfg.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                          attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:18],
        NSForegroundColorAttributeName: AppForgroundColr
    }];
     
    cfg.baseForegroundColor =  AppForgroundColr;
    cfg.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    cfg.background.backgroundColor =  [AppPrimaryClr colorWithAlphaComponent:1.0];

    cfg.imagePadding = 6;
    // Remove any fixed-size assumptions (do not set titlePadding)
    
    btn.configuration = cfg;
    
    // 🔒 Prevent title wrapping (Arabic & RTL safe)
    btn.titleLabel.numberOfLines = 1;
    btn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    btn.titleLabel.adjustsFontSizeToFitWidth = YES;
    btn.titleLabel.minimumScaleFactor = 0.85;
    btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    btn.tintColor =  buttonKind == PPDataViewNavBarButtonKindSections ? AppForgroundColr : color;
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    
    // Do NOT add width/height constraints inside this helper
    return btn;
}


#pragma mark - SubKinds Button
- (void)updateSubKindsButtonTitle:(NSString *)title
{
    [self updateSubKindsButtonTitle:title subKind:nil animated:NO];
}

- (void)updateSubKindsButtonTitle:(NSString *)title animated:(BOOL)animated
{
    [self updateSubKindsButtonTitle:title subKind:nil animated:animated];
}
// Update subKindsButton styling: Use light appearance only when current interface style is Light
- (void)updateSubKindsButtonTitle:(NSString *)title subKind:(nullable SubKindModel *)subKind
{
    [self updateSubKindsButtonTitle:title subKind:subKind animated:NO];
}

- (void)updateSubKindsButtonTitle:(NSString *)title
                          subKind:(nullable SubKindModel *)subKind
                         animated:(BOOL)animated
{
    if (!self.subKindsButton) return;
    if (!title || title.length == 0) return;
    self.lastSubKindsTitle = title;

    void (^applyButtonTitleChange)(void) = ^{
        [self pp_applyPremiumSelectorButton:self.subKindsButton
                                primaryText:title
                                    caption:[self pp_subKindsSelectorCaption]
                                 emphasized:[self pp_subKindsSelectorIsActive]];
        self.subKindsButton.accessibilityLabel =
        [NSString stringWithFormat:@"%@, %@", [self pp_subKindsSelectorCaption], title];
        [self.subKindsButton invalidateIntrinsicContentSize];
        [self pp_syncExperimentalCenterCapsuleState];

        if (animated && [self pp_allowsPremiumMotion]) {
            [self reloadNavigationCenterViewLayout];
        } else {
            [UIView performWithoutAnimation:^{
                [self reloadNavigationCenterViewLayout];
            }];
        }
    };

    if (animated) {
        [self pp_applyNavigationChangeAnimationToButton:self.subKindsButton updates:applyButtonTitleChange];
        [self pp_applyFeedbackPulseToView:self.subKindsButton];
    } else {
        applyButtonTitleChange();
    }

    if (subKind) {
        PPDataViewLog(@"subKind %ld %@ %@ ",subKind.ID,subKind.SubKindName,subKind.SubKindImageName);
    }
}

/// Shows or hides the chevron-down image on the subKindsButton.
- (void)pp_setSubKindsChevronHidden:(BOOL)hidden
{
    if (!self.subKindsButton) return;
    self.isSubKindsChevronHidden = hidden;
    [self pp_applyPremiumSubKindsButtonSurface];
    UIButtonConfiguration *cfg = self.subKindsButton.configuration;
    cfg.image = nil;
    cfg.imagePadding = 0.0;
    self.subKindsButton.configuration = cfg;
}


- (void)resetLayoutForSectionChange
{
    PPManagerCellLayoutMode mode = self.layoutManager.currentLayoutMode;
    [self pp_applyCollectionBehaviorForLayoutMode:mode];
    if (mode == PPCellLayoutModeDataViewFullDetails) {
        [self.collectionView setCollectionViewLayout:[self pp_collectionLayoutForDataViewMode:mode]
                                            animated:NO];
    } else {
        [self.layoutManager applyLayoutMode:mode
                           toCollectionView:self.collectionView
                                   animated:NO];
    }
    [self pp_installPinterestHeightGuardIfNeeded];
}

- (void)performCrossFadeReload
{
    if (!self.collectionView) { return; }
    [self pp_installPinterestHeightGuardIfNeeded];

    if (!self.view.window || UIAccessibilityIsReduceMotionEnabled()) {
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        return;
    }

    if (self.isPerformingCrossFade) {
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        return;
    }

    self.isPerformingCrossFade = YES;
    self.collectionView.userInteractionEnabled = NO;

    [UIView transitionWithView:self.collectionView
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionBeginFromCurrentState |
                               UIViewAnimationOptionAllowUserInteraction
                    animations:^{
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        [self.collectionView layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.collectionView.userInteractionEnabled = YES;
        self.isPerformingCrossFade = NO;
        [self updateEmptyState];
    }];
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    if (!universalModel || !universalModel.ModelObject) {
        PPDataViewLog(@"[DataVC][TapCard] payload is nil");
        return;
    }

    PPDataViewLog(@"[DataVC][TapCard] context=%ld payload=%@",
          universalModel.modelContext,
          universalModel.ModelObject);

    // Centralized routing (best practice)
    [PPOverlayCoordinator pp_openDetailForObject:universalModel.ModelObject
                                          fromVC:self
                                      routingNav:nil];
}

 

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)vm
                              quantity:(NSInteger)quantity
{
    PPDataViewLog(@"[DataVC][Quantity] id=%@ qty=%ld",
          vm.ModelID,
          (long)quantity);
    
    PetAccessory *accessory = (PetAccessory *)vm.ModelObject;
    if (!accessory) return;
    NSInteger maxStock = MAX(accessory.quantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (maxStock <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock")];
        safeQuantity = 0;
    } else if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only"),
                         (long)maxStock,
                         kLang(@"left in stock")]];
    }

    if (safeQuantity == 0) {
        // Removed last item
        [PPFunc triggerWarningHaptic];
        [[CartManager sharedManager] removeItemForAccessory:accessory];

    } else {
        CartManager *cart = [CartManager sharedManager];
        CartItem *existing = [cart getCartItemForItemID:accessory.accessoryID];
        CartItem *item = [[CartItem alloc] initWithAccessory:accessory quantity:safeQuantity];

        if (existing) {
            [cart updateQuantity:safeQuantity forItem:item completion:nil];
        } else {
            __weak typeof(self) weakSelf = self;
            [cart addItem:item
presentingViewController:self
               completion:^(BOOL didAdd, BOOL didCancel) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) { return; }
                if (didCancel) {
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kCartUpdatedNotification
                                      object:nil];
                    return;
                }
                if (!didAdd) {
                    [PPHUD showError:kLang(@"Out of stock")];
                    return;
                }
                if (safeQuantity == 1) {
                    [PPFunc triggerLightHaptic];
                    [PPHUD showSuccess:(kLang(@"ItemAddedToCart") ?: @"Item added to cart")];
                } else {
                    [PPFunc triggerMediumHaptic];
                }
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:kCartUpdatedNotification
                                  object:nil];
            }];
            return;
        }
        
        if (safeQuantity == 1) {
            // First add
            [PPFunc triggerLightHaptic];
        }
        else {
            // Increment / decrement
            [PPFunc triggerMediumHaptic];
        }
    }
   

    // 🔔 Notify cart change (already your system)
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kCartUpdatedNotification //@"PPCartDidChangeNotification"
                      object:nil];
}


- (NSString *)sectionKeyForMainKind:(MainKindsModel *)mainKind
{
    // All kinds mode
    if (!mainKind) {
        return kPPAllKindsSectionKey;
    }

    // Persist per MainKind ID (pp.lastSection.<kindID>)
    return [NSString stringWithFormat:@"pp.lastSection.%ld",
            (long)mainKind.ID];
}

- (BOOL)pp_isFullDetailsLayoutMode
{
    return self.layoutManager.currentLayoutMode == PPCellLayoutModeDataViewFullDetails;
}

- (UICollectionViewLayout *)pp_collectionLayoutForDataViewMode:(PPManagerCellLayoutMode)mode
{
    if (mode == PPCellLayoutModeDataViewFullDetails) {
        return [[BBDataViewFullDetailsLayout alloc] init];
    }
    return [self.layoutManager layoutForMode:mode];
}

- (void)pp_applyCollectionBehaviorForLayoutMode:(PPManagerCellLayoutMode)mode
{
    if (!self.collectionView) { return; }

    BOOL fullDetails = (mode == PPCellLayoutModeDataViewFullDetails);
    self.collectionView.alwaysBounceVertical = !fullDetails;
    self.collectionView.alwaysBounceHorizontal = fullDetails;
    self.collectionView.directionalLockEnabled = fullDetails;
    self.collectionView.pagingEnabled = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = !fullDetails;
    self.collectionView.decelerationRate = fullDetails
        ? UIScrollViewDecelerationRateFast
        : UIScrollViewDecelerationRateNormal;
    self.collectionView.scrollsToTop = !fullDetails;
    if (@available(iOS 11.0, *)) {
        self.collectionView.contentInsetAdjustmentBehavior = fullDetails
            ? UIScrollViewContentInsetAdjustmentNever
            : UIScrollViewContentInsetAdjustmentAutomatic;
    }
}

- (NSIndexPath *)pp_centerAnchorIndexPathForLayoutSwitch
{
    if (!self.collectionView || self.presentedItems.count == 0) {
        return [NSIndexPath indexPathForItem:0 inSection:0];
    }

    CGPoint visibleCenter = CGPointMake(self.collectionView.contentOffset.x + CGRectGetWidth(self.collectionView.bounds) * 0.5,
                                        self.collectionView.contentOffset.y + CGRectGetHeight(self.collectionView.bounds) * 0.5);
    NSIndexPath *bestIndexPath = nil;
    CGFloat bestDistance = CGFLOAT_MAX;

    for (NSIndexPath *indexPath in self.collectionView.indexPathsForVisibleItems) {
        if (indexPath.item < 0 || indexPath.item >= (NSInteger)self.presentedItems.count) {
            continue;
        }
        UICollectionViewLayoutAttributes *attributes =
            [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
        if (!attributes) { continue; }
        CGFloat dx = attributes.center.x - visibleCenter.x;
        CGFloat dy = attributes.center.y - visibleCenter.y;
        CGFloat distance = (dx * dx) + (dy * dy);
        if (distance < bestDistance) {
            bestDistance = distance;
            bestIndexPath = indexPath;
        }
    }

    if (bestIndexPath) {
        return bestIndexPath;
    }
    return [NSIndexPath indexPathForItem:0 inSection:0];
}

- (void)pp_scrollToAnchorIndexPath:(NSIndexPath *)indexPath
                         fullDetails:(BOOL)fullDetails
                            animated:(BOOL)animated
{
    if (!self.collectionView || !indexPath) { return; }
    if (indexPath.item < 0 || indexPath.item >= (NSInteger)self.presentedItems.count) { return; }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCollectionContentInset];
        if (fullDetails &&
            [self.collectionView.collectionViewLayout isKindOfClass:BBDataViewFullDetailsLayout.class]) {
            [(BBDataViewFullDetailsLayout *)self.collectionView.collectionViewLayout invalidateForViewportChange];
        } else {
            [self.collectionView.collectionViewLayout invalidateLayout];
        }
        [self.collectionView layoutIfNeeded];
        if (fullDetails) {
            UICollectionViewLayoutAttributes *attributes =
            [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
            if (!attributes) { return; }

            CGFloat x = attributes.center.x - (CGRectGetWidth(self.collectionView.bounds) * 0.5);
            CGFloat minX = -self.collectionView.adjustedContentInset.left;
            CGFloat maxX = MAX(minX,
                               self.collectionView.contentSize.width -
                               CGRectGetWidth(self.collectionView.bounds) +
                               self.collectionView.adjustedContentInset.right);
            x = MIN(MAX(x, minX), maxX);

            CGPoint targetOffset = CGPointMake(x, -self.collectionView.adjustedContentInset.top);
            [self.collectionView setContentOffset:targetOffset animated:animated];
            if (!animated) {
                [self.collectionView layoutIfNeeded];
                [self pp_refreshVisibleUniversalCellsAppearance];
            }
            return;
        }

        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionTop
                                            animated:animated];
        if (!animated) {
            CGPoint offset = self.collectionView.contentOffset;
            CGFloat preferredTopY = [self preferredTopContentOffsetY];
            if (offset.y < preferredTopY) {
                offset.y = preferredTopY;
                [self.collectionView setContentOffset:offset animated:NO];
            }
            [self.collectionView layoutIfNeeded];
            [self pp_refreshVisibleUniversalCellsAppearance];
        }
    });
}

- (void)pp_refreshCollectionLayoutAfterSnapshotPreservingOffset:(BOOL)preserveOffset
{
    if (!self.collectionView) { return; }

    dispatch_async(dispatch_get_main_queue(), ^{
        CGPoint previousOffset = self.collectionView.contentOffset;
        [self updateCollectionContentInset];
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView layoutIfNeeded];

        if ([self pp_isFullDetailsLayoutMode]) {
            CGPoint offset = self.collectionView.contentOffset;
            offset.y = -self.collectionView.adjustedContentInset.top;
            [self.collectionView setContentOffset:[self pp_fullDetailsCenteredOffsetForProposedOffset:offset
                                                                                             velocity:CGPointZero]
                                         animated:NO];
            [self.collectionView layoutIfNeeded];
        } else if (preserveOffset && !CGPointEqualToPoint(previousOffset, CGPointZero)) {
            CGFloat minY = -self.collectionView.adjustedContentInset.top;
            CGFloat maxY = self.collectionView.contentSize.height -
            CGRectGetHeight(self.collectionView.bounds) +
            self.collectionView.adjustedContentInset.bottom;
            if (maxY < minY) { maxY = minY; }
            previousOffset.y = MIN(MAX(previousOffset.y, minY), maxY);
            [self.collectionView setContentOffset:previousOffset animated:NO];
        }

        [self pp_refreshVisibleUniversalCellsAppearance];
    });
}

- (CGPoint)pp_fullDetailsCenteredOffsetForProposedOffset:(CGPoint)proposedOffset
                                                velocity:(CGPoint)velocity
{
    UICollectionViewLayout *layout = self.collectionView.collectionViewLayout;
    if (![layout isKindOfClass:BBDataViewFullDetailsLayout.class]) {
        return proposedOffset;
    }
    return [(BBDataViewFullDetailsLayout *)layout targetContentOffsetForProposedContentOffset:proposedOffset
                                                                        withScrollingVelocity:velocity];
}

- (void)pp_settleFullDetailsCarouselIfNeededAnimated:(BOOL)animated
{
    if (![self pp_isFullDetailsLayoutMode] || !self.collectionView) {
        return;
    }

    CGPoint targetOffset = [self pp_fullDetailsCenteredOffsetForProposedOffset:self.collectionView.contentOffset
                                                                      velocity:CGPointZero];
    CGFloat distance = hypot(targetOffset.x - self.collectionView.contentOffset.x,
                             targetOffset.y - self.collectionView.contentOffset.y);
    if (distance < 0.5) {
        return;
    }

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    if (!animated || reduceMotion) {
        [self.collectionView setContentOffset:targetOffset animated:NO];
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        [self.collectionView setContentOffset:targetOffset];
        [self.collectionView layoutIfNeeded];
    } completion:nil];
}
 
- (PPManagerCellLayoutMode)pp_currentActionsMenuLayoutMode
{
    PPManagerCellLayoutMode currentMode = self.layoutManager.currentLayoutMode;
    if ([self pp_isDataViewLayoutMode:currentMode]) {
        return currentMode;
    }

    PPManagerCellLayoutMode savedMode =
    (PPManagerCellLayoutMode)[[NSUserDefaults standardUserDefaults] integerForKey:kPPLayoutModeKey];
    PPManagerCellLayoutMode sanitizedMode = [self pp_sanitizedDataViewLayoutMode:savedMode];
    if ([self pp_isDataViewLayoutMode:sanitizedMode]) {
        return sanitizedMode;
    }

    return PPCellLayoutModePinterest;
}

- (BOOL)pp_isDataViewLayoutMode:(PPManagerCellLayoutMode)mode
{
    return mode == PPCellLayoutModeHorizontalRow ||
           mode == PPCellLayoutModeVertical ||
           mode == PPCellLayoutModePinterest ||
           mode == PPCellLayoutModeDataViewFullDetails;
}

- (PPManagerCellLayoutMode)pp_sanitizedDataViewLayoutMode:(PPManagerCellLayoutMode)mode
{
    if (mode == PPCellLayoutModeFullWidth || mode == PPCellLayoutModeHorizontalRow) {
        return PPCellLayoutModeHorizontalRow;
    }
    if ([self pp_isDataViewLayoutMode:mode]) {
        return mode;
    }
    return PPCellLayoutModePinterest;
}

- (void)pp_refreshSearchActionsMenu
{
    if (!self.navSearchActionsButton) {
        return;
    }

    self.navSearchActionsButton.menu = [self actionsArrayFrom:self collectionView:self.collectionView];
    [self pp_applyPremiumNavSearchButtonAppearance];
}

- (void)pp_applyLayoutModeFromActionsMenu:(PPManagerCellLayoutMode)mode
{
    [self pp_applyLayoutModeInternal:mode saveToDefaults:YES];
}

- (void)pp_applyLayoutModeInternal:(PPManagerCellLayoutMode)mode saveToDefaults:(BOOL)saveToDefaults
{
    [self pp_applyLayoutModeInternal:mode
                       saveToDefaults:saveToDefaults
                              animated:YES];
}

- (void)pp_applyLayoutModeInternal:(PPManagerCellLayoutMode)mode
                     saveToDefaults:(BOOL)saveToDefaults
                            animated:(BOOL)animated
{
    mode = [self pp_sanitizedDataViewLayoutMode:mode];
    if (![self pp_isDataViewLayoutMode:mode]) {
        return;
    }

    if (saveToDefaults) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PPLayoutModeChangedByUser"];
        [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kPPLayoutModeKey];
    }

    if (!self.layoutManager || !self.collectionView) {
        [self pp_refreshSearchActionsMenu];
        return;
    }

    if (self.layoutManager.currentLayoutMode == mode) {
        if (saveToDefaults) {
            [PPFunc triggerLightHaptic];
        }
        if (mode == PPCellLayoutModeDataViewFullDetails) {
            [self pp_collapseFilterIslandForFullDetailsIfNeededAnimated:animated];
        }
        [self pp_refreshSearchActionsMenu];
        return;
    }

    BOOL enteringFullDetails = (mode == PPCellLayoutModeDataViewFullDetails);
    BOOL leavingFullDetails = (self.layoutManager.currentLayoutMode == PPCellLayoutModeDataViewFullDetails);
    BOOL forcesTopOnLayoutSwitch =
        mode == PPCellLayoutModeHorizontalRow ||
        mode == PPCellLayoutModePinterest ||
        mode == PPCellLayoutModeVertical;
    NSIndexPath *anchorIndexPath = enteringFullDetails
        ? [NSIndexPath indexPathForItem:0 inSection:0]
        : (forcesTopOnLayoutSwitch
           ? [NSIndexPath indexPathForItem:0 inSection:0]
           : [self pp_centerAnchorIndexPathForLayoutSwitch]);
    BOOL shouldAnimate = animated &&
        self.view.window != nil &&
        !UIAccessibilityIsReduceMotionEnabled();
    BOOL isAutomaticSectionLayoutSwap = !saveToDefaults && !animated;

    PPDataViewLog(@"PPManagerCellLayoutMode selected %ld", (long)mode);
    if (saveToDefaults) {
        [PPFunc triggerLightHaptic];
    }
    self.layoutManager.items = self.presentedItems;
    [self pp_applyCollectionBehaviorForLayoutMode:mode];

    if (enteringFullDetails) {
        self.layoutManager.currentLayoutMode = mode;
        [self pp_collapseFilterIslandForFullDetailsIfNeededAnimated:NO];
        UICollectionViewLayout *layout = [self pp_collectionLayoutForDataViewMode:mode];
        [self.collectionView setCollectionViewLayout:layout animated:shouldAnimate];
    } else {
        [self.layoutManager applyLayoutMode:mode
                           toCollectionView:self.collectionView
                                   animated:shouldAnimate && !leavingFullDetails];
        if (leavingFullDetails) {
            [self pp_restoreFilterIslandAfterLeavingFullDetailsIfNeededAnimated:NO];
        } else if (!isAutomaticSectionLayoutSwap) {
            [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
        }
    }

    [self pp_installPinterestHeightGuardIfNeeded];
    [self.collectionView.collectionViewLayout invalidateLayout];
    if (isAutomaticSectionLayoutSwap) {
        [self updateCollectionContentInset];
        [self.collectionView layoutIfNeeded];
        [self pp_refreshVisibleUniversalCellsAppearance];
        [self pp_refreshSearchActionsMenu];
        return;
    }

    [self applySnapshotAnimated:NO];
    [self.collectionView reloadData];
    [self updateCollectionContentInset];
    [self.collectionView layoutIfNeeded];
    [self pp_scrollToAnchorIndexPath:anchorIndexPath
                         fullDetails:enteringFullDetails
                            animated:shouldAnimate];
    if (!enteringFullDetails) {
        [self pp_refreshVisibleUniversalCellsAppearance];
    }
    [self pp_refreshSearchActionsMenu];
}


// Navigation bar setup with custom center view (main kinds + sections menu)
- (void)setupNavigation
{
    [self pp_applyPremiumNavigationBarAppearance];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:PPChevronName] style:UIBarButtonItemStylePlain target:self action:@selector(onBack)];

    [self setupKindsView];
    [self pp_applyPremiumNavigationChromeAppearance];
    self.navigationItem.titleView = self.navContainerView;

    UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
    [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];
    cartNavBtn.accessibilityLabel = kLang(@"Cart");
    [self pp_applyPremiumNavIconButtonAppearance:cartNavBtn emphasized:YES];
    cartNavBtn.clipsToBounds = NO;
    [cartNavBtn.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [cartNavBtn.heightAnchor constraintEqualToConstant:44.0].active = YES;
    self.navCartButton = cartNavBtn;
    [self pp_applyTemporaryHiddenCartButtonState];

    UIButton *searchNavBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    searchNavBtn.translatesAutoresizingMaskIntoConstraints = NO;
    searchNavBtn.clipsToBounds = NO;
    [searchNavBtn.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [searchNavBtn.heightAnchor constraintEqualToConstant:44.0].active = YES;
    self.navSearchActionsButton = searchNavBtn;
    [self pp_refreshSearchActionsMenu];

    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithCustomView:searchNavBtn];
    [self reloadNavigationCenterViewLayout];

    [self updateCartBadge];
}

- (UIMenu *)actionsArrayFrom:(UIViewController *)controller collectionView:(UICollectionView *)collectionView
{
    (void)controller;
    (void)collectionView;

    __weak typeof(self) weakSelf = self;
    PPManagerCellLayoutMode currentMode = [self pp_currentActionsMenuLayoutMode];

    UIAction *searchPPAction =
    [PPActionButton actionWithTitle:kLang(@"searchOnly")
                    systemImageName:@"magnifyingglass"
                               font:[GM MidFontWithSize:15.0]
                              color:PPDataViewChromeTextColor()
                            handler:^(__unused UIAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [PPFunc triggerLightHaptic];
        [self pp_openSearchController];
    }];
    searchPPAction.discoverabilityTitle = kLang(@"searchOnly");

    UIAction *filterPPAction =
    [PPActionButton actionWithTitle:kLang(@"filterPPAction")
                    systemImageName:@"line.3.horizontal.decrease.circle"
                               font:[GM MidFontWithSize:15.0]
                              color:PPDataViewChromeTextColor()
                            handler:^(__unused UIAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [PPFunc triggerLightHaptic];
        [self openFilters];
    }];

    UIAction *(^layoutAction)(NSString *, NSString *, PPManagerCellLayoutMode, BOOL) =
    ^UIAction *(NSString *title, NSString *systemImageName, PPManagerCellLayoutMode mode, BOOL primary) {
        UIAction *action =
        [PPActionButton actionWithTitle:title
                        systemImageName:systemImageName
                                   font:(primary ? [GM boldFontWithSize:15.0] : [GM MidFontWithSize:15.0])
                                  color:(currentMode == mode ? PPDataViewAccentColor() : PPDataViewChromeTextColor())
                                handler:^(__unused UIAction *menuAction) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self pp_applyLayoutModeFromActionsMenu:mode];
        }];
        action.state = (currentMode == mode) ? UIMenuElementStateOn : UIMenuElementStateOff;
        return action;
    };

    UIAction *layoutPintrestPPAction =
    layoutAction(kLang(@"PPCellLayoutPinterest"),
                 @"square.grid.2x2.fill",
                 PPCellLayoutModePinterest,
                 YES);

    UIAction *layoutLargePPAction =
    layoutAction(kLang(@"PPCellLayoutVertical"),
                 @"rectangle.portrait.fill",
                 PPCellLayoutModeVertical,
                 YES);

    UIAction *layoutHorizontalRowPPAction =
    layoutAction(kLang(@"PPCellLayoutHorizontalRow"),
                 @"rectangle.grid.1x2.fill",
                 PPCellLayoutModeHorizontalRow,
                 YES);

    UIAction *layoutFullDetailsPPAction =
    layoutAction(kLang(@"PPCellLayoutFullDetails"),
                 @"doc.text.image",
                 PPCellLayoutModeDataViewFullDetails,
                 YES);

    UIMenu *utilityMenu =
    [UIMenu menuWithTitle:@""
                   image:nil
              identifier:nil
                 options:UIMenuOptionsDisplayInline
                children:@[searchPPAction, filterPPAction]];

    UIMenuOptions layoutMenuOptions = UIMenuOptionsDisplayInline;
    if (@available(iOS 16.0, *)) {
        layoutMenuOptions |= UIMenuOptionsDisplayAsPalette;
    }
    UIMenu *layoutMenu =
    [UIMenu menuWithTitle:@""
                   image:nil
              identifier:nil
                 options:layoutMenuOptions
                children:@[layoutHorizontalRowPPAction,
                           layoutPintrestPPAction,
                           layoutLargePPAction,
                           layoutFullDetailsPPAction]];

    return [UIMenu menuWithTitle:(kLang(@"PPDataViewActionsTitle") ?: @"")
                           image:nil
                      identifier:nil
                         options:0
                        children:@[utilityMenu, layoutMenu]];
}

- (PPDataSection)sectionFromDeepLinkTarget:(PPDeepLinkTarget)target
{
    switch (target) {

        case PPDeepLinkTargetAllCategories:
            return PPDataSectionAds; // default section for “All kinds”

        case PPDeepLinkTargetAds:
            return PPDataSectionAds;

        case PPDeepLinkTargetAccessories:
            return PPDataSectionAccessories;

        case PPDeepLinkTargetFood:
            return PPDataSectionFood;

        case PPDeepLinkTargetServices:
            return PPDataSectionServices;

        default:
            return PPDataSectionAds;
    }
}
 
- (void)selectSectionButton:(UIButton *)selectedButton
{
    
}

#pragma mark - Sections TabBar

- (void)setupSectionsTabBar
{
    NSMutableArray<PPModrenSegmrntedItem *> *sectionItems = [NSMutableArray array];
    for (NSNumber *sectionNumber in PPDataViewSectionPresentationOrder()) {
        PPDataSection section = (PPDataSection)sectionNumber.integerValue;
        [sectionItems addObject:
            [PPModrenSegmrntedItem itemWithTitle:[self titleForSection:section]
                                        iconName:[self iconForSection:section]
                                selectedIconName:[self selectedIconForSection:section]]];
    }
    ModernSegmentedControlBridge *sectionsControl = [[ModernSegmentedControlBridge alloc] initWithItems:sectionItems];
    sectionsControl.translatesAutoresizingMaskIntoConstraints = NO;
    sectionsControl.accessibilityIdentifier = @"pp.data.sectionsTabBar";
    [sectionsControl setSelectedIndex:[self pp_segmentIndexForSection:PPDataSectionAds] animated:NO];
    [sectionsControl addTarget:self
                        action:@selector(sectionsSegmentedControlChanged:)
              forControlEvents:UIControlEventValueChanged];

    self.sectionsSegmentedControl = sectionsControl;

    PPDataViewControlIslandView *controlIsland = [[PPDataViewControlIslandView alloc] init];
    controlIsland.translatesAutoresizingMaskIntoConstraints = NO;
    controlIsland.accessibilityIdentifier = @"pp.data.sectionsFiltersIsland";
    controlIsland.layer.actions = @{
        @"position"      : [NSNull null],
        @"bounds"        : [NSNull null],
        @"transform"     : [NSNull null],
        @"opacity"       : [NSNull null],
        @"zPosition"     : [NSNull null],
        @"shadowPath"    : [NSNull null],
        @"shadowOpacity" : [NSNull null],
        @"shadowRadius"  : [NSNull null],
        @"shadowOffset"  : [NSNull null]
    };
    self.sectionsFiltersContainer = controlIsland;

    if (self.input.accentColor) {
        controlIsland.useAccentColor = NO;
        if (controlIsland.useAccentColor) {
            [controlIsland pp_applyAccentColor:self.input.accentColor animated:NO];
        }
    }

    [self.view addSubview:controlIsland];
    [controlIsland addSubview:sectionsControl];
    [self pp_applyPremiumSectionsSegmentedAppearance];

    self.sectionsTabBarHeightConstraint =
    [sectionsControl.heightAnchor constraintEqualToConstant:PPCurrentSectionsTabBarHeight()];
    self.sectionsTabBarHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [controlIsland.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [controlIsland.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPIOS26() ? 18.0 : 16.0],
        [controlIsland.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:PPIOS26() ? -18.0 :  -16.0],
        [sectionsControl.topAnchor constraintEqualToAnchor:controlIsland.topAnchor constant:kPPFilterIslandTopPadding],
        [sectionsControl.leadingAnchor constraintEqualToAnchor:controlIsland.leadingAnchor constant:6.0],
        [sectionsControl.trailingAnchor constraintEqualToAnchor:controlIsland.trailingAnchor constant:-6.0]
    ]];
    [self pp_prepareSectionsSegmentedEntranceInitialState];

    UIView *filterContextBar = [[UIView alloc] init];
    filterContextBar.translatesAutoresizingMaskIntoConstraints = NO;
    filterContextBar.backgroundColor = UIColor.clearColor;
    filterContextBar.clipsToBounds = NO;
    filterContextBar.accessibilityIdentifier = @"pp.data.filters.filterContextBar";
    filterContextBar.userInteractionEnabled = YES;
    filterContextBar.accessibilityTraits = UIAccessibilityTraitButton;
    self.filterContextBar = filterContextBar;
    [controlIsland addSubview:filterContextBar];

    // Add tap gesture to filter context bar to trigger expand/collapse
    UITapGestureRecognizer *contextBarTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleFilterBadgesCollapsed:)];
    [filterContextBar addGestureRecognizer:contextBarTap];

    UIView *filterBadgeView = [[UIView alloc] init];
    filterBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    filterBadgeView.backgroundColor = UIColor.clearColor;
    filterBadgeView.clipsToBounds = YES;
    filterBadgeView.userInteractionEnabled = NO;
    self.filterContextBadgeView = filterBadgeView;
    [filterContextBar addSubview:filterBadgeView];

    UIImageSymbolConfiguration *contextIconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:11.8
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleSmall];
    UIImageView *contextIconView =
        [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"storefront.fill"
                                                    withConfiguration:contextIconConfig]
                                      imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    contextIconView.translatesAutoresizingMaskIntoConstraints = NO;
    contextIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.filterContextIconView = contextIconView;
    [filterBadgeView addSubview:contextIconView];

    UILabel *contextLabel = [[UILabel alloc] init];
    contextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    contextLabel.font = [GM boldFontWithSize:11.8] ?: [UIFont systemFontOfSize:11.8 weight:UIFontWeightSemibold];
    contextLabel.adjustsFontForContentSizeCategory = YES;
    contextLabel.numberOfLines = 1;
    contextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    contextLabel.text = [self filterContextTitleForSection:self.viewModel.currentSection];
    self.filterContextLabel = contextLabel;
    [filterBadgeView addSubview:contextLabel];
    
    UIView *filterContainer = [[UIView alloc] init];
    filterContainer.translatesAutoresizingMaskIntoConstraints = NO;
    filterContainer.backgroundColor = UIColor.clearColor;
    filterContainer.clipsToBounds = NO;
    filterContainer.hidden = YES;
    filterContainer.alpha = 0.0;

    self.filterChipContainer = filterContainer;

    [controlIsland addSubview:filterContainer];

    UIButton *providerFilterChip = [UIButton buttonWithType:UIButtonTypeSystem];
    providerFilterChip.translatesAutoresizingMaskIntoConstraints = NO;
    providerFilterChip.accessibilityIdentifier = @"pp.data.filters.providerChip";
    providerFilterChip.accessibilityTraits = UIAccessibilityTraitButton;
    providerFilterChip.hidden = YES;
    providerFilterChip.alpha = 0.0;
    providerFilterChip.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    providerFilterChip.adjustsImageWhenHighlighted = NO;
    providerFilterChip.clipsToBounds = NO;
    providerFilterChip.layer.cornerRadius = PPDataViewPillRadiusForHeight(kPPProviderFilterChipHeight, 18.0);
    if (@available(iOS 13.0, *)) {
        providerFilterChip.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
        configuration.image = nil;
        configuration.imagePadding = 0.0;
        configuration.baseForegroundColor = PPDataViewProviderPillAccentColor(self.traitCollection);
        configuration.background.cornerRadius = PPDataViewPillRadiusForHeight(kPPProviderFilterChipHeight, 18.0);
        configuration.title = @"";
        configuration.subtitle = @"";
        providerFilterChip.configuration = configuration;
        providerFilterChip.layer.cornerRadius = PPDataViewPillRadiusForHeight(kPPProviderFilterChipHeight, 18.0);
    } else {
        [providerFilterChip setTitle:@"" forState:UIControlStateNormal];
        [providerFilterChip setImage:nil forState:UIControlStateNormal];
        providerFilterChip.tintColor = PPDataViewProviderPillAccentColor(self.traitCollection);
        providerFilterChip.contentEdgeInsets = UIEdgeInsetsZero;
        providerFilterChip.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    }
    UIImageView *providerAvatarView = [[UIImageView alloc] initWithImage:[self pp_providerPlaceholderImage]];
    providerAvatarView.translatesAutoresizingMaskIntoConstraints = NO;
    providerAvatarView.userInteractionEnabled = NO;
    providerAvatarView.contentMode = UIViewContentModeScaleAspectFit;
    providerAvatarView.isAccessibilityElement = NO;
    self.providerFilterChipAvatarView = providerAvatarView;
    [providerFilterChip addSubview:providerAvatarView];

    UIImageSymbolConfiguration *providerTrailingIconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                        weight:UIImageSymbolWeightBold
                                                         scale:UIImageSymbolScaleSmall];
    UIImageView *providerTrailingIconView =
        [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"storefront.fill"
                                                    withConfiguration:providerTrailingIconConfig]
                                      imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    providerTrailingIconView.translatesAutoresizingMaskIntoConstraints = NO;
    providerTrailingIconView.userInteractionEnabled = NO;
    providerTrailingIconView.contentMode = UIViewContentModeCenter;
    providerTrailingIconView.isAccessibilityElement = NO;
    self.providerFilterChipTrailingIconView = providerTrailingIconView;
    [providerFilterChip addSubview:providerTrailingIconView];

    UILabel *providerTitleLabel = [[UILabel alloc] init];
    providerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    providerTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    providerTitleLabel.textColor = PPDataViewProviderPillAccentColor(self.traitCollection);
    providerTitleLabel.adjustsFontForContentSizeCategory = YES;
    providerTitleLabel.numberOfLines = 1;
    providerTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    providerTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    providerTitleLabel.text = kLang(@"dataview_filter_by_provider");
    [providerTitleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisHorizontal];
    [providerTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    self.providerFilterChipTitleLabel = providerTitleLabel;

    UILabel *providerRatingLabel = [[UILabel alloc] init];
    providerRatingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    providerRatingLabel.font = [GM boldFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    providerRatingLabel.textColor = PPDataViewProviderPillAccentColor(self.traitCollection);
    providerRatingLabel.textAlignment = NSTextAlignmentCenter;
    providerRatingLabel.adjustsFontForContentSizeCategory = YES;
    providerRatingLabel.numberOfLines = 1;
    providerRatingLabel.lineBreakMode = NSLineBreakByClipping;
    providerRatingLabel.hidden = YES;
    providerRatingLabel.isAccessibilityElement = NO;
    providerRatingLabel.layer.cornerRadius = 9.0;
    providerRatingLabel.clipsToBounds = YES;
    [providerRatingLabel setContentHuggingPriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];
    [providerRatingLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                         forAxis:UILayoutConstraintAxisHorizontal];
    [providerRatingLabel.heightAnchor constraintGreaterThanOrEqualToConstant:18.0].active = YES;
    self.providerFilterChipRatingLabel = providerRatingLabel;

    UILabel *providerSubtitleLabel = [[UILabel alloc] init];
    providerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    providerSubtitleLabel.font = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    providerSubtitleLabel.textColor = PPDataViewChromeSecondaryTextColor();
    providerSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    providerSubtitleLabel.numberOfLines = 1;
    providerSubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    providerSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    providerSubtitleLabel.text = kLang(@"dataview_provider_filter_empty_title");
    self.providerFilterChipSubtitleLabel = providerSubtitleLabel;

    UIView *providerTitleSpacer = [[UIView alloc] init];
    providerTitleSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    providerTitleSpacer.userInteractionEnabled = NO;
    [providerTitleSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow
                                           forAxis:UILayoutConstraintAxisHorizontal];
    [providerTitleSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                         forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *providerTitleRowStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        providerTitleLabel,
        providerRatingLabel,
        providerTitleSpacer
    ]];
    providerTitleRowStack.translatesAutoresizingMaskIntoConstraints = NO;
    providerTitleRowStack.axis = UILayoutConstraintAxisHorizontal;
    providerTitleRowStack.alignment = UIStackViewAlignmentCenter;
    providerTitleRowStack.distribution = UIStackViewDistributionFill;
    providerTitleRowStack.spacing = 6.0;
    providerTitleRowStack.userInteractionEnabled = NO;
    providerTitleRowStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIStackView *providerTextStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        providerTitleRowStack,
        providerSubtitleLabel
    ]];
    providerTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    providerTextStack.axis = UILayoutConstraintAxisVertical;
    providerTextStack.alignment = UIStackViewAlignmentFill;
    providerTextStack.distribution = UIStackViewDistributionFill;
    providerTextStack.spacing = 1.0;
    providerTextStack.userInteractionEnabled = NO;
    providerTextStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [providerFilterChip addSubview:providerTextStack];

    [providerFilterChip addTarget:self
                           action:@selector(providerFilterChipTapped:)
                 forControlEvents:UIControlEventTouchUpInside];
    self.providerFilterChipButton = providerFilterChip;
    [controlIsland addSubview:providerFilterChip];

    PPPremiumCollapseButton *collapseButton = [PPPremiumCollapseButton buttonWithType:UIButtonTypeCustom];
    collapseButton.translatesAutoresizingMaskIntoConstraints = NO;
    collapseButton.backgroundColor = UIColor.clearColor;
    collapseButton.tintColor = PPDataViewAccentColor();
    collapseButton.alpha = 0.0;
    collapseButton.hidden = YES;
    collapseButton.accessibilityIdentifier = @"pp.data.filters.collapseToggle";
    collapseButton.accessibilityTraits = UIAccessibilityTraitButton;
    [collapseButton addTarget:self
                       action:@selector(toggleFilterBadgesCollapsed:)
             forControlEvents:UIControlEventTouchUpInside];
    
    collapseButton.layer.cornerRadius = kPPFilterCollapseHandleHeight * 0.5;
    if (@available(iOS 13.0, *)) {
        collapseButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    collapseButton.layer.masksToBounds = YES;
    
    collapseButton.backgroundColor = [UIColor clearColor];
    
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);
        configuration.imagePadding = 5.0;

        configuration.imagePlacement = NSDirectionalRectEdgeTrailing; // RTL-safe chevron placement
        configuration.baseForegroundColor = PPDataViewAccentColor();
        collapseButton.configuration = configuration;
    } else {
        collapseButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);
        collapseButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, 5.0, 0.0, -5.0);
    }
    
    self.filterCollapseButton = collapseButton;
    [filterContextBar addSubview:collapseButton];

    self.filterChipHeightConstraint =
    [filterContainer.heightAnchor constraintEqualToConstant:0.0];
    self.filterChipHeightConstraint.active = YES;
    self.filterChipTopConstraint =
    [filterContainer.topAnchor constraintEqualToAnchor:providerFilterChip.bottomAnchor constant:0.0];
    self.filterChipTopConstraint.active = YES;
    self.providerFilterChipTopConstraint =
        [providerFilterChip.topAnchor constraintEqualToAnchor:sectionsControl.bottomAnchor constant:0.0];
    self.providerFilterChipTopConstraint.active = YES;
    self.providerFilterChipHeightConstraint =
        [providerFilterChip.heightAnchor constraintEqualToConstant:0.0];
    self.providerFilterChipHeightConstraint.active = YES;
    self.filterContextBarHeightConstraint =
        [filterContextBar.heightAnchor constraintEqualToConstant:kPPFilterContextBarHeight];
    self.filterContextBarHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [filterContextBar.leadingAnchor constraintEqualToAnchor:controlIsland.leadingAnchor constant:10.0],
        [filterContextBar.trailingAnchor constraintEqualToAnchor:controlIsland.trailingAnchor constant:-10.0],

        [providerFilterChip.leadingAnchor constraintEqualToAnchor:controlIsland.leadingAnchor constant:10.0],
        [providerFilterChip.trailingAnchor constraintEqualToAnchor:controlIsland.trailingAnchor constant:-10.0],

        [filterContextBar.topAnchor constraintEqualToAnchor:filterContainer.bottomAnchor constant:kPPFilterIslandRowSpacing],
        [controlIsland.bottomAnchor constraintEqualToAnchor:filterContextBar.bottomAnchor constant:kPPFilterIslandBottomPadding],

        [providerAvatarView.leadingAnchor constraintEqualToAnchor:providerFilterChip.leadingAnchor constant:12.0],
        [providerAvatarView.centerYAnchor constraintEqualToAnchor:providerFilterChip.centerYAnchor],
        [providerAvatarView.widthAnchor constraintEqualToConstant:kPPProviderFilterChipAvatarDiameter],
        [providerAvatarView.heightAnchor constraintEqualToConstant:kPPProviderFilterChipAvatarDiameter],

        [providerTrailingIconView.trailingAnchor constraintEqualToAnchor:providerFilterChip.trailingAnchor constant:-10.0],
        [providerTrailingIconView.centerYAnchor constraintEqualToAnchor:providerFilterChip.centerYAnchor],
        [providerTrailingIconView.widthAnchor constraintEqualToConstant:kPPProviderFilterChipTrailingIconDiameter],
        [providerTrailingIconView.heightAnchor constraintEqualToConstant:kPPProviderFilterChipTrailingIconDiameter],

        [providerTextStack.leadingAnchor constraintEqualToAnchor:providerAvatarView.trailingAnchor constant:8.0],
        [providerTextStack.trailingAnchor constraintEqualToAnchor:providerTrailingIconView.leadingAnchor constant:-8.0],
        [providerTextStack.centerYAnchor constraintEqualToAnchor:providerFilterChip.centerYAnchor],
        [providerTextStack.topAnchor constraintGreaterThanOrEqualToAnchor:providerFilterChip.topAnchor constant:3.0],
        [providerTextStack.bottomAnchor constraintLessThanOrEqualToAnchor:providerFilterChip.bottomAnchor constant:-3.0],

        [filterBadgeView.leadingAnchor constraintEqualToAnchor:filterContextBar.leadingAnchor constant:8.0],
        [filterBadgeView.centerYAnchor constraintEqualToAnchor:filterContextBar.centerYAnchor],
        [filterBadgeView.trailingAnchor constraintLessThanOrEqualToAnchor:collapseButton.leadingAnchor constant:-6.0],
        [filterBadgeView.heightAnchor constraintEqualToConstant:kPPFilterContextBadgeHeight],

        [contextIconView.leadingAnchor constraintEqualToAnchor:filterBadgeView.leadingAnchor constant:10.0],
        [contextIconView.centerYAnchor constraintEqualToAnchor:filterBadgeView.centerYAnchor],
        [contextIconView.widthAnchor constraintEqualToConstant:13.0],
        [contextIconView.heightAnchor constraintEqualToConstant:13.0],

        [contextLabel.leadingAnchor constraintEqualToAnchor:contextIconView.trailingAnchor constant:5.0],
        [contextLabel.trailingAnchor constraintEqualToAnchor:filterBadgeView.trailingAnchor constant:-10.0],
        [contextLabel.centerYAnchor constraintEqualToAnchor:filterBadgeView.centerYAnchor],

        [filterContainer.leadingAnchor constraintEqualToAnchor:controlIsland.leadingAnchor constant:10.0],
        [filterContainer.trailingAnchor constraintEqualToAnchor:controlIsland.trailingAnchor constant:-10.0],
        [collapseButton.trailingAnchor constraintEqualToAnchor:filterContextBar.trailingAnchor constant:-2.0],
        [collapseButton.centerYAnchor constraintEqualToAnchor:filterContextBar.centerYAnchor],
        [collapseButton.widthAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [collapseButton.heightAnchor constraintEqualToConstant:kPPFilterCollapseHandleHeight]
    ]];
    [collapseButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [collapseButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [filterBadgeView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [providerFilterChip setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self pp_applyFilterContextBarAppearance];

    // Dynamic filter chips — created from PPFilterState for the initial section
    self.filterChips = [NSMutableArray array];
    UIStackView *chipsStack = [[UIStackView alloc] init];
    chipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    chipsStack.axis = UILayoutConstraintAxisHorizontal;
    chipsStack.alignment = UIStackViewAlignmentFill;
    chipsStack.distribution = UIStackViewDistributionFillEqually;
    chipsStack.spacing = 8.0;
    self.filterChipStackView = chipsStack;
    [filterContainer addSubview:chipsStack];

    [NSLayoutConstraint activateConstraints:@[
        [chipsStack.topAnchor constraintEqualToAnchor:filterContainer.topAnchor constant:2.0],
        [chipsStack.leadingAnchor constraintEqualToAnchor:filterContainer.leadingAnchor],
        [chipsStack.trailingAnchor constraintEqualToAnchor:filterContainer.trailingAnchor],
        [chipsStack.bottomAnchor constraintEqualToAnchor:filterContainer.bottomAnchor constant:-2.0],
    ]];
    self.filterChipStackHeightConstraint = [chipsStack.heightAnchor constraintEqualToConstant:0.0];
    self.filterChipStackHeightConstraint.active = YES;

    // Initialize per-section filter state dictionary
    self.filterStates = [NSMutableDictionary dictionary];
    self.selectedProviderIDsBySection = [NSMutableDictionary dictionary];

    PPDataSection initialFilterSection = self.viewModel ? self.viewModel.currentSection : PPDataSectionAds;
    [self syncFilterChipsForSection:initialFilterSection];
    [self pp_syncProviderFilterChipLayoutForCurrentSectionAnimated:NO];
}

- (void)sectionsSegmentedControlChanged:(ModernSegmentedControlBridge *)sender
{
    NSInteger selectedIndex = sender.selectedIndex;
    if (selectedIndex < 0 || selectedIndex >= sender.numberOfSegments) {
        return;
    }

    [self activateSection:[self pp_sectionForSegmentIndex:selectedIndex] userInitiated:YES];
}

- (UIMenu *)sectionsMenu
{
    NSMutableArray *actions = [NSMutableArray array];


    for (NSNumber *sectionNumber in PPDataViewSectionPresentationOrder()) {
        PPDataSection section = (PPDataSection)sectionNumber.integerValue;

        UIAction *action =
        [UIAction actionWithTitle:[self titleForSection:section]
                            image:[UIImage pp_symbolNamed:[self iconForSection:section] pointSize:16 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleDefault palette:@[AppPrimaryClr] makeTemplate:YES]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull act) {
            [self activateSection:section userInitiated:YES];
        }];

        action.state =
        (section == self.viewModel.currentSection)
        ? UIMenuElementStateOn
        : UIMenuElementStateOff;
        
        // Apply attributed title
        UIFont *useFont =  [GM boldFontWithSize:16];
        UIColor *useColor =  UIColor.labelColor;
        
        NSDictionary *attributes = @{
            NSFontAttributeName: useFont,
            NSForegroundColorAttributeName: useColor
        };
        
        NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:[self titleForSection:section] attributes:attributes];
        // KVC hack removed

        [actions addObject:action];    }

    return [UIMenu menuWithTitle:@"" children:actions];
}

// Synchronous version of subKindsMenu: builds all actions immediately, uses placeholder icons synchronously.
// When no mainKind is selected, returns the main kinds menu so the user picks a kind first.
- (UIMenu *)subKindsMenu
{
    
    PPDataViewLog(@"[SubKindsMenu] currentSubKindID = %ld",
          (long)self.viewModel.currentSubKindID);
    
    
    NSMutableArray *actions = [NSMutableArray array];

    MainKindsModel *mainKind = self.input.mainKind;
    if (!mainKind || mainKind.SubKindsArray.count == 0) {
        // No main kind selected → show main kinds menu so user picks one first
        return [self mainMenu];
    }

    for (SubKindModel *subKind in mainKind.SubKindsArray) {
        // Synchronously get a placeholder image if possible, else nil
        
        if (subKind.subKindIconBlurHash.length > 0) {
            // If you have a synchronous blurhash decode helper, use it here.
         //   if ([PPBlurHashBridge respondsToSelector:@selector(imageFrom:syncSize:punch:)]) {
         //       placeholder = [PPBlurHashBridge imageFrom:subKind.subKindIconBlurHash syncSize:CGSizeMake(100, 100) punch:0.5 ];
         //  }
        }
        
        UIImage *btnImg =
        [PPImageButtonHelper imageFor44ptButton:PPImage(subKind.SubKindImageName)];
        UIAction *action =
        [UIAction actionWithTitle:subKind.SubKindName
                            image:btnImg
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull act) {
            AudioServicesPlaySystemSound(1104);

            if (self.viewModel.currentSubKindID == subKind.ID) return;

            if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
                self.input.sourceTarget = PPDeepLinkTargetNone;
                self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;
            }

            NSString *key = [self subKindKeyForMainKind:self.input.mainKind];
            [[NSUserDefaults standardUserDefaults] setInteger:subKind.ID forKey:key];

            [self.scrollOffsetsBySection removeAllObjects];
            NSInteger direction =
            [self pp_directionForSubKindID:subKind.ID
                comparedToCurrentSubKindID:self.viewModel.currentSubKindID];
            [self pp_beginMotionTransition:PPDataViewMotionReasonSubKindChange
                                  direction:direction];
            [self.viewModel reloadForSubKind:subKind];
            [self updateSubKindsButtonTitle:subKind.SubKindName
                                    subKind:subKind
                                   animated:YES];
            [[NovaAmbientAssistantCoordinator sharedCoordinator] categoryDidOpen:subKind.SubKindName];
             self.subKindsButton.menu = [self subKindsMenu];
        }];

        // Selected state
        action.state =
        (subKind.ID == self.viewModel.currentSubKindID)
        ? UIMenuElementStateOn
        : UIMenuElementStateOff;

        // Attributed title (same style as subKindsMenu)
        UIFont *useFont = [GM boldFontWithSize:16];
        UIColor *useColor = UIColor.labelColor;

        NSDictionary *attributes = @{
            NSFontAttributeName : useFont,
            NSForegroundColorAttributeName : useColor
        };

        NSAttributedString *attrTitle =
        [[NSAttributedString alloc] initWithString:subKind.SubKindName
                                        attributes:attributes];

        // ⚠️ KVC hack (same as your subKindsMenu) removed

        [actions addObject:action];
    }
    
    
    // ─────────────────────────────────────────────
    // 🔹 ALL (clear subkind filter)
    // ─────────────────────────────────────────────

    UIAction *allAction =
    [UIAction actionWithTitle:kLang(@"All")
                        image:[UIImage systemImageNamed:@"circle.grid.3x3.fill"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull act) {

        AudioServicesPlaySystemSound(1104);

        PPDataViewLog(@"🔄 SubKind = ALL (clear filter)");

        if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
            self.input.sourceTarget = PPDeepLinkTargetNone;
            self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;
        }

        // Persist "All" (0 means no subkind)
        NSString *key = [self subKindKeyForMainKind:self.input.mainKind];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:key];

        NSInteger previousSubKindID = self.viewModel.currentSubKindID;
        // Clear filter in ViewModel
        self.viewModel.currentSubKindID = 0;

        // Reset scroll cache
        [self.scrollOffsetsBySection removeAllObjects];

        // Reload current section WITHOUT subkind constraint
        NSInteger direction =
        [self pp_directionForSubKindID:0
            comparedToCurrentSubKindID:previousSubKindID];
        [self pp_beginMotionTransition:PPDataViewMotionReasonSubKindChange
                              direction:direction];
        [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {
            
        }];

        [self updateSubKindsButtonTitle:[self pp_currentSubKindsDisplayTitle] animated:YES];
        [[NovaAmbientAssistantCoordinator sharedCoordinator] categoryDidOpen:self.input.mainKind.KindName];

        // Refresh menu states
        self.subKindsButton.menu = [self subKindsMenu];
    }];

    // Selected state: ON when no subkind is selected
    allAction.state =
    (self.viewModel.currentSubKindID == 0)
    ? UIMenuElementStateOn
    : UIMenuElementStateOff;

    // Attributed title (same style)
    UIFont *allFont = [GM boldFontWithSize:16];
    UIColor *allColor = AppSecondaryTextClr;

    NSAttributedString *allAttrTitle =
    [[NSAttributedString alloc] initWithString:kLang(@"all")
                                    attributes:@{
        NSFontAttributeName : allFont,
        NSForegroundColorAttributeName : allColor
    }];
    // KVC hack removed
    // Add as LAST item
    [actions addObject:allAction];
    return [UIMenu menuWithTitle:@"" children:actions];
}

- (NSString *)subKindKeyForMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) { return @"pp.lastSubKind.all"; }
    return [NSString stringWithFormat:@"pp.lastSubKind.%ld", (long)mainKind.ID];
}

-(void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAdSharingHelper sharePetAd:(PetAd *)universalModel.ModelObject fromViewController:self];
    });
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer ==
        self.navigationController.interactivePopGestureRecognizer) {
        // Disable on root VC
        return self.navigationController.viewControllers.count > 1;
    }
    return YES;
}


-(void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel
{
    
    PPDataViewLog(@"[AdsVC] PPUniversalCell_tapEdit");
    
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        AddNewAd *vc = (AddNewAd *)[AddNewAd  new];
        vc.mode = AdEditorModeEdit;
        vc.editingAd = (PetAd *)universalModel.ModelObject;                 // the existing PetAd you want to edit
        //vc.delegate = self;                // optional to get callbacks
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:nav animated:YES completion:nil];
    }
    else  if(universalModel.cellSection == CellSectionAccessories && [universalModel.ModelObject isKindOfClass:[PetAccessory class]])
    {
        // Edit
        AddNewAccessory *editVC = [AddNewAccessory new];
        editVC.editingAccessory = (PetAccessory *)universalModel.ModelObject;   ;   // prefill from this model
        editVC.onFinish = ^(PetAccessory *result, BOOL isEdit) {
            // refresh list, etc.
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
            
        };
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editVC];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:nav animated:YES completion:nil];
    }
}



-(void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel
{
    PPDataViewLog(@"[AdsVC] PPUniversalCell_tapDelete");
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        [GM showDeleteConfirmationFrom:self
                                 title:kLang(@"Confirm Deletion")
                               message:kLang(@"Are you sure you want to delete this item?")
                            completion:^(BOOL confirmed) {
            if (confirmed) {
                // Perform delete action
                [PetAdManager.sharedManager deletePetAd:(PetAd *)universalModel.ModelObject completion:^(NSError * _Nonnull error) {
                    [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
                }];
            }
        }];
    }
}

-(void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    BOOL nextVisible = !universalModel.isPubliclyVisible;
    void (^handleResult)(NSError * _Nullable error) = ^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"listing_visibility_failed")];
                return;
            }
            NSString *message = nextVisible ? kLang(@"listing_visible_success") : kLang(@"listing_hidden_success");
            [AppManager.sharedInstance showSnakBar:message withColor:GM.appPrimaryColor andDuration:0.6 containerView:self.view];
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
        });
    };

    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        [[PetAdManager sharedManager] updatePetAdID:ad.adID
                                         visibility:(nextVisible ? PetAdVisibilityPublic : PetAdVisibilityHidden)
                                         completion:handleResult];
    } else if(universalModel.cellSection == CellSectionAccessories && [universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        PetAccessory *accessory = (PetAccessory *)universalModel.ModelObject;
        [[PetAccessoryManager sharedManager] updateAccessoryID:accessory.accessoryID
                                               showInAppMarket:nextVisible
                                                    completion:handleResult];
    }
}

#pragma mark - BBDataViewFullDetailsCellDelegate

- (void)fullDetailsCellDidRequestOpen:(BBDataViewFullDetailsCell *)cell
                            viewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)cell;
    [self PPUniversalCell_tapCard:viewModel];
}

- (void)fullDetailsCellDidRequestShare:(BBDataViewFullDetailsCell *)cell
                             viewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)cell;
    if ([viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
        [PetAccessory sharePetAccessory:(PetAccessory *)viewModel.ModelObject
                     fromViewController:self];
        return;
    }
    if ([viewModel.ModelObject isKindOfClass:PetAd.class]) {
        [self PPUniversalCell_tapShare:viewModel];
        return;
    }
    [self PPUniversalCell_tapCard:viewModel];
}

- (void)fullDetailsCellDidRequestChat:(BBDataViewFullDetailsCell *)cell
                            viewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)cell;
    if (!PPIsUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSString *ownerID = [self pp_chatOwnerIDForFullDetailsViewModel:viewModel];
    if (ownerID.length == 0) {
        [PPHUD showInfo:kLang(@"bb_dataview_full_details_contact_unavailable")];
        return;
    }

    NSString *currentUID = UserManager.sharedManager.currentUser.ID ?: PPCurrentFIRAuthUser.uid ?: @"";
    if ([ownerID isEqualToString:currentUID]) {
        [PPHUD showInfo:kLang(@"bb_dataview_full_details_chat_self_unavailable")];
        return;
    }

    [PPHUD showLoading:kLang(@"bb_dataview_full_details_opening_chat")];
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) { return; }
            [PPHUD dismiss];

            if (error || !user || user.ID.length == 0) {
                [PPHUD showError:kLang(@"bb_dataview_full_details_contact_unavailable")];
                return;
            }

            [ChManager.sharedManager createOrGetChatThreadWithUser:user
                                                        completion:^(ChatThreadModel * _Nullable thread, NSError * _Nullable chatError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (chatError || !thread) {
                        [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:chatError.localizedDescription ?: @""];
                        return;
                    }
                    [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
                });
            }];
        });
    }];
}

- (NSString *)pp_chatOwnerIDForFullDetailsViewModel:(PPUniversalCellViewModel *)viewModel
{
    id model = viewModel.ModelObject;
    if ([model isKindOfClass:PetAd.class]) {
        return ((PetAd *)model).ownerID;
    }
    if ([model isKindOfClass:ServiceModel.class]) {
        return ((ServiceModel *)model).serviceOwnerID;
    }
    if ([model respondsToSelector:@selector(ownerID)]) {
        return [model performSelector:@selector(ownerID)];
    }
    if ([model respondsToSelector:@selector(userID)]) {
        return [model performSelector:@selector(userID)];
    }
    return @"";
}

- (void)fullDetailsCellDidRequestEdit:(BBDataViewFullDetailsCell *)cell
                            viewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)cell;
    [self PPUniversalCell_tapEdit:viewModel];
}

- (void)fullDetailsCellDidRequestDelete:(BBDataViewFullDetailsCell *)cell
                              viewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)cell;
    [self PPUniversalCell_tapDelete:viewModel];
}

- (void)fullDetailsCellDidRequestVisibilityToggle:(BBDataViewFullDetailsCell *)cell
                                        viewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)cell;
    [self PPUniversalCell_tapVisibilityToggle:viewModel];
}

- (void)fullDetailsCell:(BBDataViewFullDetailsCell *)cell
 didRequestQuantityDelta:(NSInteger)delta
              viewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)cell;
    if (![viewModel.ModelObject isKindOfClass:PetAccessory.class]) { return; }
    PetAccessory *accessory = (PetAccessory *)viewModel.ModelObject;
    NSInteger currentQuantity = [[CartManager sharedManager] quantityForAccessory:accessory];
    NSInteger nextQuantity = MAX(0, currentQuantity + delta);
    [self PPUniversalCell_changeQuantity:viewModel quantity:nextQuantity];
}

- (void)asyncBlurHashImageForHash:(NSString *)hash
                             size:(CGSize)size
                        completion:(void (^)(UIImage * _Nullable image))completion
{
    if (!hash.length) {
        if (completion) completion(nil);
        return;
    }

    // 1️⃣ Check cache FIRST (cheap, thread-safe)
    UIImage *cached = [self.blurHashCache objectForKey:hash];
    if (cached) {
        if (completion) completion(cached);
        return;
    }

    // 2️⃣ Decode off-main
    dispatch_async(self.blurHashQueue, ^{
        UIImage *img =
        [PPBlurHashBridge imageFrom:hash
                            syncSize:size
                               punch:1.0];

        if (!img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
            return;
        }

        // 3️⃣ Cache + return on main
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.blurHashCache setObject:img forKey:hash];
            if (completion) completion(img);
        });
    });
}

#pragma mark - Mirror Top Cell Image Color

- (void)pp_updateMirrorColorForScrollOffset
{
    if (!self.collectionView) {
        return;
    }
    
    CGPoint topPoint = CGPointMake(CGRectGetMidX(self.collectionView.bounds),
                                   self.collectionView.contentOffset.y + self.collectionView.adjustedContentInset.top + 20.0);
    
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:topPoint];
    
    if (!indexPath) {
        NSArray<NSIndexPath *> *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
        if (visibleIndexPaths.count > 0) {
            NSIndexPath *minIP = visibleIndexPaths.firstObject;
            for (NSIndexPath *ip in visibleIndexPaths) {
                if (ip.section < minIP.section || (ip.section == minIP.section && ip.item < minIP.item)) {
                    minIP = ip;
                }
            }
            indexPath = minIP;
        }
    }
    
    if (!indexPath) {
        return;
    }
    
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if (![PPUniversalCell pp_isUniversalCell:cell]) {
        return;
    }
    
    PPUniversalCell *universalCell = (PPUniversalCell *)cell;
    UIImage *image = universalCell.imageView.image;
    if (!image) {
        return;
    }
    
    PPUniversalCellViewModel *vm = [self.dataSource itemIdentifierForIndexPath:indexPath];
    if (!vm) {
        return;
    }
    
    NSString *cacheKey = vm.imageURL ?: vm.ModelID;
    if (!cacheKey) {
        return;
    }
    
    UIColor *cachedColor = [self.pp_topCellColorCache objectForKey:cacheKey];
    if (cachedColor) {
        [self pp_applyMirrorColorToIslandBackground:cachedColor];
    } else {
        if ([self.pp_inFlightColorExtractions containsObject:cacheKey]) {
            return;
        }
        
        [self.pp_inFlightColorExtractions addObject:cacheKey];
        __weak typeof(self) weakSelf = self;
        [self pp_extractAverageColorFromImage:image completion:^(UIColor * _Nullable color) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            [strongSelf.pp_inFlightColorExtractions removeObject:cacheKey];
            if (color) {
                [strongSelf.pp_topCellColorCache setObject:color forKey:cacheKey];
                
                CGPoint currentTopPoint = CGPointMake(CGRectGetMidX(strongSelf.collectionView.bounds),
                                                     strongSelf.collectionView.contentOffset.y + strongSelf.collectionView.adjustedContentInset.top + 20.0);
                NSIndexPath *currentIP = [strongSelf.collectionView indexPathForItemAtPoint:currentTopPoint];
                if ([currentIP isEqual:indexPath]) {
                    [strongSelf pp_applyMirrorColorToIslandBackground:color];
                }
            }
        }];
    }
}

- (void)pp_extractAverageColorFromImage:(UIImage *)image completion:(void(^)(UIColor * _Nullable color))completion
{
    if (!image) {
        if (completion) completion(nil);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        int width = 8;
        int height = 8;
        int numPixels = width * height;
        unsigned char rgba[8 * 8 * 4] = {0};
        CGContextRef context = CGBitmapContextCreate(rgba, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        
        if (context) {
            CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
            CGContextRelease(context);
        }
        CGColorSpaceRelease(colorSpace);
        
        double sumR = 0, sumG = 0, sumB = 0, sumA = 0;
        CGFloat maxScore = -1.0;
        UIColor *vibrantColor = nil;
        
        for (int i = 0; i < numPixels; i++) {
            int offset = i * 4;
            CGFloat r = ((CGFloat)rgba[offset]) / 255.0;
            CGFloat g = ((CGFloat)rgba[offset+1]) / 255.0;
            CGFloat b = ((CGFloat)rgba[offset+2]) / 255.0;
            CGFloat a = ((CGFloat)rgba[offset+3]) / 255.0;
            
            sumR += r * a;
            sumG += g * a;
            sumB += b * a;
            sumA += a;
            
            if (a < 0.3) {
                continue;
            }
            
            CGFloat maxVal = MAX(r, MAX(g, b));
            CGFloat minVal = MIN(r, MIN(g, b));
            CGFloat delta = maxVal - minVal;
            CGFloat saturation = (maxVal > 0) ? (delta / maxVal) : 0.0;
            
            // Penalize background neutrals (pure white background, dark black shadows)
            CGFloat brightness = maxVal;
            CGFloat weight = 1.0;
            if (brightness > 0.85) {
                weight = MAX(0.0, (1.0 - brightness) / 0.15);
            } else if (brightness < 0.15) {
                weight = MAX(0.0, brightness / 0.15);
            }
            
            CGFloat score = saturation * weight;
            if (score > maxScore) {
                maxScore = score;
                vibrantColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
            }
        }
        
        UIColor *finalColor = nil;
        if (maxScore > 0.12 && vibrantColor) {
            finalColor = vibrantColor;
        } else if (sumA > 0) {
            finalColor = [UIColor colorWithRed:sumR / sumA
                                         green:sumG / sumA
                                          blue:sumB / sumA
                                         alpha:1.0];
        }
        
        if (finalColor) {
            CGFloat h = 0, s = 0, v = 0, al = 0;
            if ([finalColor getHue:&h saturation:&s brightness:&v alpha:&al]) {
                // Boost saturation by 45% and ensure brightness is high (for a vibrant glow)
                s = MIN(1.0, s * 1.45);
                v = MIN(1.0, MAX(0.70, v * 1.15));
                finalColor = [UIColor colorWithHue:h saturation:s brightness:v alpha:al];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(finalColor);
            }
        });
    });
}

- (void)pp_applyMirrorColorToIslandBackground:(UIColor *)color
{
    if (!color) return;
    
    UIColor *currentOverride = self.sectionsFiltersContainer.heroBackgroundView.overrideCenterGlowColor;
    if ([currentOverride isEqual:color]) {
        return;
    }
    
    [UIView transitionWithView:self.sectionsFiltersContainer.heroBackgroundView
                      duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
        self.sectionsFiltersContainer.heroBackgroundView.overrideCenterGlowColor = color;
        self.sectionsFiltersContainer.heroBackgroundView.overrideBottomGlowColor = color;
    } completion:nil];
}

@end
    

    
