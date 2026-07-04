#import "PPDataViewVC.h"
#import "PPDataViewInput.h"
#import "PPDataViewVM.h"
#import "PPFilterModels.h"
#import <Pure_Pets-Swift.h>

#import "PPUniversalCell.h"
#import "PPCollectionLayoutManager.h"
#import "PPImageLoaderManager.h"
#import "PPFilterSheetVC.h"
#import "PPAdSharingHelper.h"
#import "PPAnalytics.h"
#import "CartManager.h"
#import "UIViewController+PPBottomSurface.h"
#import "CartViewController.h"
#import "PPRootTabBarController.h"
#import "PPModrenSegmrnted.h"
#import "PPNavigationController.h"
#import "PPSearchViewController.h"
#import "PPHUD.h"
#import "UIView+Badge.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#if DEBUG
#define PPDataViewLog(...) NSLog(__VA_ARGS__)
#else
#define PPDataViewLog(...)
#endif

static const CGFloat kPPSectionsTabBarHeight = 58.0;
static const CGFloat kPPAccessoryFilterHeight = 48.0;
static const NSInteger kPPPremiumVisibleCellAnimationLimit = 12;
static const CGFloat kPPPremiumCellBaseEntranceYOffset = 18.0;
static const CGFloat kPPPremiumCellSectionEntranceXOffset = 18.0;
static const CGFloat kPPAdsPinterestMaximumHeightToWidthRatio = 2.10;
static const CGFloat kPPAdsPinterestMaximumViewportFraction = 0.58;
static const CGFloat kPPAdsPinterestMinimumContentAllowance = 130.0;
static const CGFloat kPPDataViewNavigationChromeCornerRadius = 24.0;
static const CGFloat kPPDataViewSelectorCornerRadius = 21.0;
static const CGFloat kPPDataViewSectionsSegmentedCornerRadius = 29.0;

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

static NSArray<NSNumber *> *PPDataViewSectionPresentationOrder(void)
{
    static NSArray<NSNumber *> *order;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        order = @[
            @(PPDataSectionAccessories),
            @(PPDataSectionAds),
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

static UIColor *PPDataViewAppForegroundSurfaceColor(void)
{
    return AppForgroundColr ?: PPDataViewChromeElevatedSurfaceColor();
}

static UIColor *PPDataViewFilterIslandSurfaceColor(void)
{
    BOOL isRTL = Language.isRTL;
    UIColor *light = isRTL
        ? [UIColor colorWithRed:1.00 green:0.965 blue:0.972 alpha:0.94]
        : [UIColor colorWithRed:0.970 green:0.978 blue:0.988 alpha:0.94];
    UIColor *dark = isRTL
        ? [UIColor colorWithRed:0.145 green:0.118 blue:0.132 alpha:0.82]
        : [UIColor colorWithRed:0.115 green:0.122 blue:0.145 alpha:0.82];
    return PPDataViewDynamicColor(light, dark);
}

static UIColor *PPDataViewFilterIslandWashColor(void)
{
    BOOL isRTL = Language.isRTL;
    UIColor *light = isRTL
        ? [UIColor colorWithRed:1.00 green:0.885 blue:0.915 alpha:0.78]
        : [UIColor colorWithRed:0.900 green:0.940 blue:1.000 alpha:0.70];
    UIColor *dark = isRTL
        ? [UIColor colorWithRed:0.270 green:0.135 blue:0.180 alpha:0.56]
        : [UIColor colorWithRed:0.120 green:0.180 blue:0.265 alpha:0.54];
    return PPDataViewDynamicColor(light, dark);
}

static UIColor *PPDataViewFilterIslandStrokeColor(BOOL hasActiveFilters)
{
    UIColor *light = hasActiveFilters
        ? [UIColor colorWithRed:0.95 green:0.70 blue:0.78 alpha:0.40]
        : [UIColor colorWithRed:0.82 green:0.76 blue:0.78 alpha:0.24];
    UIColor *dark = hasActiveFilters
        ? [UIColor colorWithRed:1.00 green:0.72 blue:0.84 alpha:0.26]
        : [UIColor colorWithWhite:1.0 alpha:0.10];
    return PPDataViewDynamicColor(light, dark);
}

@interface PPDataViewControlIslandView : UIView
- (void)pp_applyActiveFilterCount:(NSInteger)count animated:(BOOL)animated;
@end

@interface PPDataViewControlIslandView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, assign) NSInteger activeFilterCount;
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
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemThickMaterial;
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
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.surfaceGradientLayer.masksToBounds = YES;
    [self.layer insertSublayer:self.surfaceGradientLayer above:self.blurView.layer];

    [self pp_applyActiveFilterCount:0 animated:NO];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat radius = MIN(PPDataViewPillRadiusForHeight(CGRectGetHeight(self.bounds), 24.0), 32.0);
    self.layer.cornerRadius = radius;
    self.blurView.layer.cornerRadius = radius;
    self.surfaceGradientLayer.frame = self.bounds;
    self.surfaceGradientLayer.cornerRadius = radius;

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius];
    self.layer.shadowPath = shadowPath.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyActiveFilterCount:self.activeFilterCount animated:NO];
}

- (void)pp_applyActiveFilterCount:(NSInteger)count animated:(BOOL)animated
{
    self.activeFilterCount = MAX(0, count);
    BOOL hasActiveFilters = self.activeFilterCount > 0;
    
    UIColor *surface = PPDataViewFilterIslandSurfaceColor();
    UIColor *wash = PPDataViewFilterIslandWashColor();
    UIColor *border = PPDataViewFilterIslandStrokeColor(hasActiveFilters);

    void (^updates)(void) = ^{
        BOOL isRTL = Language.isRTL;
        self.surfaceGradientLayer.startPoint = isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
        self.surfaceGradientLayer.endPoint = isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
        self.blurView.hidden = UIAccessibilityIsReduceTransparencyEnabled();
        self.backgroundColor = self.blurView.hidden ? [surface colorWithAlphaComponent:0.96] : UIColor.clearColor;
        self.layer.borderWidth = hasActiveFilters ? 1.0 : 0.75;
        self.layer.borderColor = border.CGColor;
        self.layer.shadowColor = PPDataViewChromeShadowColor().CGColor;
        self.layer.shadowOpacity = hasActiveFilters ? 0.09 : 0.06;
        self.layer.shadowRadius = hasActiveFilters ? 13.0 : 10.0;
        self.layer.shadowOffset = CGSizeMake(0.0, hasActiveFilters ? 4.5 : 3.0);

        UIColor *top = [surface colorWithAlphaComponent:hasActiveFilters ? 0.94 : 0.86];
        UIColor *mid = [wash colorWithAlphaComponent:hasActiveFilters ? 0.56 : 0.42];
        UIColor *bottom = [surface colorWithAlphaComponent:hasActiveFilters ? 0.74 : 0.60];
        self.surfaceGradientLayer.colors = @[
            (__bridge id)top.CGColor,
            (__bridge id)mid.CGColor,
            (__bridge id)bottom.CGColor
        ];
        self.surfaceGradientLayer.locations = @[@0.0, @0.52, @1.0];
        self.surfaceGradientLayer.opacity = hasActiveFilters ? 0.62 : 0.48;
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
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    updates();
    [CATransaction commit];
}

@end


@interface PPDropdownFilterChipButton : UIButton
@property (nonatomic, copy) NSString *chipIconName;
- (void)pp_applyChipTitle:(NSString *)title active:(BOOL)active;
@end

@interface PPDropdownFilterChipButton ()
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
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.showsMenuAsPrimaryAction = YES;
    self.layer.masksToBounds = NO;
    self.backgroundColor = UIColor.clearColor;
    self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.surfaceGradientLayer.masksToBounds = YES;
    [self.layer insertSublayer:self.surfaceGradientLayer atIndex:0];

    self.strokeLayer = [CAShapeLayer layer];
    self.strokeLayer.fillColor = UIColor.clearColor.CGColor;
    [self.layer addSublayer:self.strokeLayer];

    [self.heightAnchor constraintEqualToConstant:40.0].active = YES;
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat radius = PPDataViewPillRadiusForHeight(CGRectGetHeight(self.bounds), 20.0);
    self.layer.cornerRadius = radius;
    self.surfaceGradientLayer.frame = self.bounds;
    self.surfaceGradientLayer.cornerRadius = radius;

    CGRect strokeRect = CGRectInset(self.bounds, 0.5, 0.5);
    CGFloat strokeRadius = MAX(0.0, radius - 0.5);
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:strokeRadius];
    self.strokeLayer.frame = self.bounds;
    self.strokeLayer.path = strokePath.CGPath;
    self.layer.shadowPath = strokePath.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyPremiumLayerStateAnimated:NO];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = highlighted ? 0.82 : 1.0;
        return;
    }

    CGFloat scale = highlighted ? 0.975 : 1.0;
    [UIView animateWithDuration:highlighted ? 0.12 : 0.20
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformMakeScale(scale, scale);
        self.alpha = highlighted ? 0.90 : 1.0;
    } completion:nil];
}

- (void)pp_applyChipTitle:(NSString *)title active:(BOOL)active
{
    self.ppActive = active;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    NSString *safeTitle = title.length > 0 ? title : @"";
    UIColor *brand = PPDataViewAccentColor();
    UIColor *fg = active ? PPDataViewChromeTextColor() : PPDataViewChromeSecondaryTextColor();
    UIColor *accentedFG = active ? brand : fg;
    UIFont *baseFont = active ? [GM boldFontWithSize:13] : [GM MidFontWithSize:13];
    if (!baseFont) {
        baseFont = [UIFont systemFontOfSize:13.0 weight:(active ? UIFontWeightSemibold : UIFontWeightMedium)];
    }
    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:baseFont];
    NSDictionary *textAttrs = @{
        NSFontAttributeName            : font,
        NSForegroundColorAttributeName : fg
    };

    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] init];

    NSString *iconName = [self.chipIconName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (iconName.length > 0) {
        UIImageSymbolConfiguration *iconCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:11
                                                            weight:UIImageSymbolWeightMedium];
        UIImage *icon = [[UIImage systemImageNamed:iconName
                                 withConfiguration:iconCfg]
                         imageWithTintColor:accentedFG
                              renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (icon) {
            NSTextAttachment *att = [[NSTextAttachment alloc] init];
            att.image = icon;
            att.bounds = CGRectMake(0, -1.5, 14, 14);
            [attrTitle appendAttributedString:
             [NSAttributedString attributedStringWithAttachment:att]];
            [attrTitle appendAttributedString:
             [[NSAttributedString alloc] initWithString:@" " attributes:textAttrs]];
        }
    }

    [attrTitle appendAttributedString:
     [[NSAttributedString alloc] initWithString:safeTitle attributes:textAttrs]];

    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(7, 13, 7, 11);
    cfg.baseForegroundColor = accentedFG;
    cfg.attributedTitle = attrTitle;

    UIImageSymbolConfiguration *chevCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:9
                                                        weight:UIImageSymbolWeightSemibold];
    cfg.image = [UIImage systemImageNamed:@"chevron.down" withConfiguration:chevCfg];
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.imagePadding = 6.0;
    cfg.background.backgroundColor = UIColor.clearColor;
    cfg.background.strokeColor = UIColor.clearColor;
    cfg.background.strokeWidth = 0.0;

    self.configuration = cfg;
    self.tintColor = accentedFG;

    [self pp_applyPremiumLayerStateAnimated:self.window != nil];
}

- (void)pp_applyPremiumLayerStateAnimated:(BOOL)animated
{
    UIColor *brand = PPDataViewAccentColor();
    UIColor *surface = PPDataViewAppForegroundSurfaceColor();
    BOOL active = self.isPPActive;

    void (^updates)(void) = ^{
        UIColor *top = active
            ? PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.88],
                                     [UIColor colorWithWhite:1.0 alpha:0.14])
            : [surface colorWithAlphaComponent:0.94];
        UIColor *middle = active
            ? [brand colorWithAlphaComponent:0.10]
            : [surface colorWithAlphaComponent:0.76];
        UIColor *bottom = active
            ? PPDataViewDynamicColor([UIColor colorWithWhite:1.0 alpha:0.48],
                                     [UIColor colorWithWhite:1.0 alpha:0.06])
            : [surface colorWithAlphaComponent:0.58];

        self.surfaceGradientLayer.colors = @[
            (__bridge id)top.CGColor,
            (__bridge id)middle.CGColor,
            (__bridge id)bottom.CGColor
        ];
        self.surfaceGradientLayer.locations = @[@0.0, @0.54, @1.0];
        self.surfaceGradientLayer.opacity = active ? 1.0 : 0.84;

        self.strokeLayer.strokeColor = (active
                                        ? [brand colorWithAlphaComponent:0.22]
                                        : [surface colorWithAlphaComponent:0.56]).CGColor;
        self.strokeLayer.lineWidth = active ? 0.8 : 0.75;

        self.layer.shadowColor = PPDataViewChromeShadowColor().CGColor;
        self.layer.shadowOpacity = active ? 0.09 : 0.06;
        self.layer.shadowRadius = active ? 7.0 : 6.0;
        self.layer.shadowOffset = CGSizeMake(0.0, active ? 2.5 : 2.0);
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
}

@end

@interface PPDataViewVC () <PPUniversalCellDelegate,UITabBarDelegate,UIGestureRecognizerDelegate,UICollectionViewDataSourcePrefetching, PPPinterestLayoutDelegate>//UITabBarDelegate
 // Input
@property (nonatomic, strong) PPDataViewInput *input;
@property (nonatomic, assign) BOOL didInitialReload;
// ViewModel
@property (nonatomic, strong) PPDataViewVM *viewModel;
@property (nonatomic, assign) PPManagerCellLayoutMode cellLayoutMode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) PPCollectionLayoutManager *layoutManager;
@property (nonatomic, strong) PPDataViewControlIslandView *sectionsFiltersContainer;
@property (nonatomic, strong) UIView *filterChipContainer;
@property (nonatomic, strong) UIStackView *filterChipStackView;
@property (nonatomic, strong) NSMutableArray<PPDropdownFilterChipButton *> *filterChips;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, PPFilterState *> *filterStates;
// Scroll restore
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *scrollOffsetsBySection;
@property (nonatomic, strong) id imageLoader;

@property (nonatomic, strong) PPModrenSegmrnted *sectionsSegmentedControl;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewTop;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewMid;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewBottom;


@property (nonatomic, assign) CGFloat lastContentOffsetY;
@property (nonatomic, assign) BOOL isRestoringScrollOffset;
// Custom navigation bar center view
@property (nonatomic, strong) UIButton *navContainerView;
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
@property (nonatomic, strong) NSLayoutConstraint *filterChipHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterChipTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterChipBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cartButtonWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *navContainerWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subKindsTrailingToCartConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subKindsTrailingToContainerConstraint;
@property (nonatomic, strong) NSLayoutConstraint *centerCapsuleMinWidthConstraint;

@property (nonatomic, assign) BOOL isCartButtonVisible;
@property (nonatomic, assign) BOOL isSubKindsChevronHidden;
@property (nonatomic, assign) BOOL useCapsuleNavigation;
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
- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
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
- (BOOL)shouldShowFilterChipBarForSection:(PPDataSection)section;
- (void)syncFilterChipsForCurrentSection;
- (void)syncFilterChipsForSection:(PPDataSection)section;
- (void)updateFilterChipVisibilityForSection:(PPDataSection)section animated:(BOOL)animated;
- (void)refreshPresentedItemsAnimated:(BOOL)animated scrollToTop:(BOOL)scrollToTop;
- (void)refreshFilterChipTitles;
- (void)refreshFilterChipTitlesForSection:(PPDataSection)section;
- (PPFilterState *)pp_filterStateForSection:(PPDataSection)section;
- (void)sectionsSegmentedControlChanged:(PPModrenSegmrnted *)sender;
- (void)onCartTapped;
- (void)pp_openSearchController;
- (void)pp_applyTemporaryHiddenCartButtonState;
- (void)pp_refreshSearchActionsMenu;
- (void)pp_applyLayoutModeFromActionsMenu:(PPManagerCellLayoutMode)mode;
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
    [self updateCollectionContentInset];
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

    NSMutableArray<NSURL *> *urls = [NSMutableArray array];

    for (SubKindModel *subKind in mainKind.SubKindsArray) {
        if (subKind.subKindIconUrl.length) {
            NSURL *url = [NSURL URLWithString:subKind.subKindIconUrl];
            if (url) [urls addObject:url];
        }
    }

    if (urls.count == 0) return;
  

    [[SDWebImagePrefetcher sharedImagePrefetcher]
     prefetchURLs:urls
     progress:nil
     completed:^(NSUInteger finishedCount, NSUInteger skippedCount) {
        PPDataViewLog(@"[SubKind Prefetch] done=%lu skipped=%lu",
                      (unsigned long)finishedCount,
                      (unsigned long)skippedCount);
    }];
}


 
#pragma mark - Init

- (instancetype)initWithInput:(PPDataViewInput *)input
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;

    _input = input;
    return self;
}

 #pragma mark - Skeleton Loading

- (void)showSkeleton
{
    if (self.isShowingSkeleton) return;
    self.isShowingSkeleton = YES;

    NSMutableArray *items = [NSMutableArray array];
    NSInteger count = 8;

    for (NSInteger i = 0; i < count; i++) {
        PPUniversalCellViewModel *vm =
        [[PPUniversalCellViewModel alloc] initSkeleton];
        [items addObject:vm];
    }

    self.layoutManager.items = items;
    self.presentedItems = items;

    [self.layoutManager applyLayoutMode:self.layoutManager.currentLayoutMode
                       toCollectionView:self.collectionView
                               animated:NO];

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
    [super viewDidLoad];
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    }
    self.didFixInitialScroll = NO;
    _didlayout = NO;
    self.useCapsuleNavigation = NO;
    self.blurHashCache = [NSCache new];
    self.blurHashCache.countLimit = 200;
    self.blurHashQueue =
    dispatch_queue_create("com.purepets.blurhash.decode", DISPATCH_QUEUE_CONCURRENT);
    self.isPerformingCrossFade = NO;
    self.presentedItems = @[];
    self.pendingMotionReason = PPDataViewMotionReasonNone;
    self.pendingMotionDirection = 0;
    self.isAwaitingTransitionData = NO;
    self.animatedCellEntranceKeys = [NSMutableSet set];
    self.cellEntranceAnimationGeneration = 0;
    self.pendingCellEntranceAnimationLimit = 0;
    self.pendingCellEntranceMotionReason = PPDataViewMotionReasonNone;
    self.pendingCellEntranceDirection = 0;
    self.didRunSectionsSegmentedEntrance = NO;
    [self pp_applyPremiumDataViewBackgroundAppearance];
    [self emptyStateInit];
    [self setupSectionsTabBar];
    // 🔥 FIX: normalize AllKinds EARLY
    [self normalizeInitialMainKind];

    [self setupNavigation];
    [self setupViewModel];
   
    [self setupCollectionView];
    [self pp_applyPremiumDataViewBackgroundAppearance];
    [self showSkeleton];
    [self updateEmptyState];

    [self bindViewModel];
    [self handleInitialRoute];
    
    [self prefetchSubKindIcons];
    
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
    
     
}

- (void)dealloc
{
    [[PPImageLoaderManager shared] cancelAllPrefetching];
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
        if ([cell isKindOfClass:PPUniversalCell.class]) {
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
    configuration.image = [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:symbolConfiguration];
    configuration.imagePadding = 0.0;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(2.0, 7.0, 2.0, 7.0);
    configuration.baseForegroundColor = PPDataViewChromeTextColor();
    button.configuration = configuration;
    button.tintColor = PPDataViewChromeTextColor();
    button.showsMenuAsPrimaryAction = YES;
    if (@available(iOS 15.0, *)) {
        button.changesSelectionAsPrimaryAction = NO;
    }
    button.accessibilityLabel = kLang(@"PPDataViewSearchMenuA11y");
    button.accessibilityHint = kLang(@"PPDataViewSearchMenuHint");
    button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
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

    centeredStyle.lineSpacing = -1.5;
    centeredStyle.paragraphSpacing = 0;
    centeredStyle.lineHeightMultiple = 0.78;

    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:resolvedPrimary
                                                                              attributes:@{
        NSFontAttributeName : [GM boldFontWithSize:14.2],
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

    configuration.contentInsets = NSDirectionalEdgeInsetsMake(2.0, 6.0, 2.0, 6.0);
    // Tighten spacing between Species/Breed caption and selected value (reduces the gap significantly)

    configuration.attributedSubtitle =
    [[NSAttributedString alloc] initWithString:resolvedCaption
                                    attributes:@{
        NSFontAttributeName : [GM MidFontWithSize:8.3],
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
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.82;
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

    self.centerCapsuleButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
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
    self.navContainerView.layer.borderWidth = 0.65;
    [self.navContainerView pp_setBorderColor:PPDataViewChromeStrokeColor()];
    [self.navContainerView pp_setShadowColor:PPDataViewChromeShadowColor()];
    self.navContainerView.layer.shadowOpacity = 0.075;
    self.navContainerView.layer.shadowRadius = 14.0;
    self.navContainerView.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    UIButtonConfiguration *configuration = self.navContainerView.configuration;
    if (!configuration) {
        configuration = [UIButtonConfiguration plainButtonConfiguration];
    }
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.background.cornerRadius = chromeRadius;
    configuration.contentInsets = NSDirectionalEdgeInsetsZero;
    configuration.baseForegroundColor = PPDataViewChromeTextColor();
    configuration.background.backgroundColor = PPDataViewChromeSurfaceColor();
    configuration.background.strokeColor = PPDataViewChromeStrokeColor();
    configuration.background.strokeWidth = 0.65;

    self.navContainerView.configuration = configuration;
    self.navContainerView.isAccessibilityElement = NO;

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

    self.sectionsFiltersContainer.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    BOOL showsCurrentFilterRow = [self shouldShowFilterChipBarForSection:self.viewModel.currentSection];
    NSInteger activeFilterCount = (self.filterStates && showsCurrentFilterRow) ? [self pp_currentFilterState].activeFilterCount : 0;
    [self.sectionsFiltersContainer pp_applyActiveFilterCount:activeFilterCount animated:NO];

    self.sectionsSegmentedControl.containerBackgroundColor = UIColor.clearColor;
    self.sectionsSegmentedControl.hidesContainerChrome = YES;
    self.sectionsSegmentedControl.normalTextColor = PPDataViewChromeSecondaryTextColor();
    self.sectionsSegmentedControl.selectedTextColor = PPDataViewChromeTextColor();
    self.sectionsSegmentedControl.selectedSegmentColor = PPDataViewAccentColor();
    self.sectionsSegmentedControl.normalFont = [GM MidFontWithSize:13.2];
    self.sectionsSegmentedControl.selectedFont = [GM boldFontWithSize:13.6];
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
        CGFloat islandRadius =
            MIN(PPDataViewPillRadiusForHeight(CGRectGetHeight(self.sectionsFiltersContainer.bounds), 24.0), 32.0);
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
        [weakSelf updateEmptyState];
    }];
}
 
 - (void)updateEmptyState {
    if (self.isShowingSkeleton || self.isPerformingCrossFade) return;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateEmptyState];
        });
        return;
    }
    [PPEmptyStateHelper updateEmptyStateForListView:self.collectionView
                                          dataCount:self.presentedItems.count
                                             config:self.emptyStateConfig];
    if (self.presentedItems.count == 0) {
        [[NovaAmbientAssistantCoordinator sharedCoordinator] emptyStateDidAppear];
    }
 }

- (void)setupCollectionView
{
    self.layoutManager = [PPCollectionLayoutManager new];

    
    PPManagerCellLayoutMode savedMode =
    (PPManagerCellLayoutMode)[[NSUserDefaults standardUserDefaults]
                              integerForKey:kPPLayoutModeKey];

    if (savedMode >= PPCellLayoutModeSquare &&
        savedMode <= PPCellLayoutModePinterest) {
        self.layoutManager.currentLayoutMode = savedMode;
    } else {
        self.layoutManager.currentLayoutMode = PPCellLayoutModePinterest;
    }
    
    UICollectionViewLayout *layout = [self.layoutManager layoutForMode:self.layoutManager.currentLayoutMode];

    self.collectionView =
    [[UICollectionView alloc] initWithFrame:CGRectZero
                       collectionViewLayout:layout];
    [self pp_installPinterestHeightGuardIfNeeded];

    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.prefetchingEnabled = YES;
    self.collectionView.prefetchDataSource = self;
    self.collectionView.decelerationRate = UIScrollViewDecelerationRateNormal;
    if (@available(iOS 13.0, *)) {
       // self.collectionView.automaticallyAdjustsScrollIndicatorInsets = NO;
    }
    [self.collectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:@"PPUniversalCell"];
    [self configureDataSource];
    [self.view insertSubview:self.collectionView atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
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
                     surfaceAlpha:isDark ? 0.12 : 0.070
                    shadowOpacity:isDark ? 0.15f : 0.095f
                     shadowRadius:isDark ? 80.0 : 72.0];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewMid
                            color:secondaryColor
                     surfaceAlpha:isDark ? 0.095 : 0.052
                    shadowOpacity:isDark ? 0.12f : 0.070f
                     shadowRadius:isDark ? 70.0 : 62.0];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewBottom
                            color:ambientColor
                     surfaceAlpha:isDark ? 0.045 : 0.024
                    shadowOpacity:isDark ? 0.075f : 0.040f
                     shadowRadius:isDark ? 60.0 : 52.0];
}

- (void)pp_layoutPremiumBackgroundGlowViews
{
    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds) || !self.collectionView) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;

    CGFloat topSize = MIN(340.0, MAX(236.0, width * 0.70));
    CGFloat midSize = MIN(288.0, MAX(204.0, width * 0.56));
    CGFloat bottomSize = MIN(324.0, MAX(216.0, width * 0.64));

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
    [self pp_applyPremiumDataViewBackgroundAppearance];
    [self pp_layoutPremiumBackgroundGlowViews];
    [self pp_applyPremiumNavigationChromeAppearance];
    [self pp_applyPremiumSectionsSegmentedAppearance];
    [self pp_updatePremiumChromeShadowPaths];
    [self updateCollectionContentInset];
    [self updateSectionsTabBarSelectionIndicatorIfNeeded];
    [self reloadNavigationCenterViewLayout];
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
        // Force layout pass (CRITICAL for Pinterest)
        [cv layoutIfNeeded];

        if (cv.contentSize.height <= cv.bounds.size.height) {
            return; // nothing to scroll
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
        [weakSelf hideSkeleton];
        PPDataViewLog(@"\n================ onReloadData =================");
        PPDataViewLog(@"[VC] currentSection = %ld", (long)weakSelf.viewModel.currentSection);
        PPDataViewLog(@"[VC] items.count = %ld", (long)weakSelf.viewModel.items.count);

        BOOL isTransitionResetPhase =
            weakSelf.isAwaitingTransitionData &&
            weakSelf.viewModel.isLoading &&
            weakSelf.viewModel.items.count == 0;

        if (isTransitionResetPhase) {
            [weakSelf updateSectionsTabBarSelectionForSection:weakSelf.viewModel.currentSection animated:NO];
            [weakSelf updateFilterChipVisibilityForSection:weakSelf.viewModel.currentSection animated:NO];
            [weakSelf syncFilterChipsForCurrentSection];
            [weakSelf persistCurrentSection];
            [weakSelf updateCollectionContentInset];
            [weakSelf updateCartButtonVisibility];
            return;
        }

        [weakSelf refreshPresentedItemsAnimated:weakSelf.didApplyInitialSnapshot
                                     scrollToTop:NO];
        weakSelf.didApplyInitialSnapshot = YES;
        [weakSelf updateSectionsTabBarSelectionForSection:weakSelf.viewModel.currentSection animated:NO];
        [weakSelf updateFilterChipVisibilityForSection:weakSelf.viewModel.currentSection animated:NO];
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
    };

    self.viewModel.onAppendData = ^(NSArray<NSIndexPath *> *indexPaths) {
        PPDataViewLog(@"\n================ onAppendData =================");
        PPDataViewLog(@"[VC] indexPaths.count = %ld", (long)indexPaths.count);
        PPDataViewLog(@"[VC] items.count BEFORE = %ld", (long)weakSelf.viewModel.items.count);
        PPDataViewLog(@"[VC] didInitialReload = %@", weakSelf.didInitialReload ? @"YES" : @"NO");

        [weakSelf refreshPresentedItemsAnimated:YES scrollToTop:NO];
        [weakSelf updateEmptyState];
        [weakSelf syncFilterChipsForCurrentSection];
        //[weakSelf updateNavSectionTitle];
        
        [weakSelf refreshsubKindsMenu];
        [weakSelf updateCollectionContentInset];
        [weakSelf updateCartButtonVisibility];
        [weakSelf pp_prefetchImagesAtIndexPaths:indexPaths];
    };

    self.viewModel.onError = ^(NSError * _Nonnull error) {
        PPDataViewLog(@"[PPDataViewVC] data error: %@", error.localizedDescription ?: @"unknown");
        [weakSelf hideSkeleton];
        [weakSelf updateEmptyState];
    };
}


#pragma mark - Collection Content Inset Fix

// Ensures collectionView has proper bottom inset for tab bar & safe area, and always bounces vertically.
- (void)updateCollectionContentInset
{
    if (!self.collectionView) { return; }

    CGFloat targetTopInset =
    [self shouldShowFilterChipBarForSection:self.viewModel.currentSection]
    ? (PPCurrentSectionsTabBarHeight() + kPPAccessoryFilterHeight + 12.0)
    : (PPCurrentSectionsTabBarHeight() + (PPIOS26() ? 2.0 : 12.0));
    CGRect sectionsFrame = self.sectionsFiltersContainer.frame;
    CGRect safeAreaFrame = self.view.safeAreaLayoutGuide.layoutFrame;

    if (!CGRectIsEmpty(sectionsFrame) && !CGRectIsEmpty(safeAreaFrame)) {
        CGFloat maxVisibleY = CGRectGetMaxY(sectionsFrame);

        targetTopInset =
        MAX(0.0, maxVisibleY - CGRectGetMinY(safeAreaFrame) + 6.0);
    }

    CGFloat targetBottomInset = 16.0;
    CGFloat rootClearance = 0.0;
    SEL clearanceSelector = NSSelectorFromString(@"pp_bottomNavigationContentClearance");
    if ([self.tabBarController respondsToSelector:clearanceSelector]) {
        CGFloat (*clearanceIMP)(id, SEL) = (CGFloat (*)(id, SEL))[self.tabBarController methodForSelector:clearanceSelector];
        rootClearance = clearanceIMP ? clearanceIMP(self.tabBarController, clearanceSelector) : 0.0;
    }

    if (rootClearance > 0.0) {
        targetBottomInset = ceil(rootClearance);
    } else {
        CGFloat bottomInset = 0.0;
        if (self.tabBarController &&
            !self.tabBarController.tabBar.hidden &&
            self.tabBarController.tabBar.alpha > 0.01) {
            bottomInset += self.tabBarController.tabBar.bounds.size.height;
        }
        bottomInset += self.view.safeAreaInsets.bottom;
        targetBottomInset = bottomInset + 16.0;
    }
    UIEdgeInsets currentInset = self.collectionView.contentInset;
    CGFloat topDelta = currentInset.top - targetTopInset;
    if (topDelta < 0) { topDelta = -topDelta; }
    CGFloat bottomDelta = currentInset.bottom - targetBottomInset;
    if (bottomDelta < 0) { bottomDelta = -bottomDelta; }
    if (topDelta < 0.5 && bottomDelta < 0.5) {
        return;
    }
 
    UIEdgeInsets inset = currentInset;
    inset.top = targetTopInset;
    inset.bottom = targetBottomInset; // breathing space

    self.collectionView.contentInset = inset;
    self.collectionView.scrollIndicatorInsets = inset;
}

- (void)saveCurrentSectionScrollOffset
{
    if (!self.collectionView) { return; }
    CGPoint currentOffset = self.collectionView.contentOffset;
    CGFloat preferredTopY = [self preferredTopContentOffsetY];
    if (currentOffset.y < preferredTopY) {
        currentOffset.y = preferredTopY;
    }
    self.scrollOffsetsBySection[@(self.viewModel.currentSection)] =
    [NSValue valueWithCGPoint:currentOffset];
}

- (void)restoreScrollOffsetForCurrentSection
{
    if (!self.collectionView) { return; }

    NSValue *savedOffset =
    self.scrollOffsetsBySection[@(self.viewModel.currentSection)];
    CGPoint targetOffset = CGPointMake(0, [self preferredTopContentOffsetY]);
    if (savedOffset) {
        targetOffset = savedOffset.CGPointValue;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView layoutIfNeeded];

        CGFloat minY = -self.collectionView.adjustedContentInset.top;
        CGFloat maxY = self.collectionView.contentSize.height -
        self.collectionView.bounds.size.height +
        self.collectionView.adjustedContentInset.bottom;
        if (maxY < minY) {
            maxY = minY;
        }

        CGFloat preferredTopY = [self preferredTopContentOffsetY];
        CGFloat clampedY = targetOffset.y;
        if (clampedY < preferredTopY) { clampedY = preferredTopY; }
        if (clampedY < minY) { clampedY = minY; }
        if (clampedY > maxY) { clampedY = maxY; }
        CGPoint clampedOffset = CGPointMake(0, clampedY);
        self.isRestoringScrollOffset = YES;
        [self.collectionView setContentOffset:clampedOffset animated:NO];
        self.isRestoringScrollOffset = NO;
        self.scrollOffsetsBySection[@(self.viewModel.currentSection)] =
        [NSValue valueWithCGPoint:clampedOffset];
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
    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidScroll];
    if (self.isRestoringScrollOffset) { return; }
    if (self.layoutManager.items.count == 0) { return; }
    if (!scrollView.isTracking && !scrollView.isDragging && !scrollView.isDecelerating) { return; }
    CGFloat y = scrollView.contentOffset.y;
    if (ABS(y - self.lastContentOffsetY) < 6.0) { return; }
    self.lastContentOffsetY = y;
    [self saveCurrentSectionScrollOffset];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView == self.collectionView && !decelerate) {
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == self.collectionView) {
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView == self.collectionView) {
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
        self.cartButtonWidthConstraint.constant = shouldShow ? 36.0 : 0.0;
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
        [strongSelf.viewModel applyFilterState:applied];
        [strongSelf syncFilterChipsForCurrentSection];
        [strongSelf refreshFilterChipTitles];
        [strongSelf refreshPresentedItemsAnimated:YES scrollToTop:YES];

    };
    [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle80 ];

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

        PPUniversalCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell"
                                                  forIndexPath:indexPath];

        if (!vm) {
            cell.hidden = YES;
            return cell;
        }

        cell.hidden = NO;
        vm.indexPath = indexPath;

        BOOL isAdContext = (vm.modelContext == PPCellForAds || vm.modelContext == PPCellForHomeAds);
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

        cell.delegate = weakSelf;

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
    [[PPImageLoaderManager shared] prefetchURLs:urls];
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
    if (indexPaths.count == 0) {
        return;
    }
    [[PPImageLoaderManager shared] cancelAllPrefetching];
}

- (void)collectionView:(UICollectionView *)collectionView
      willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    (void)collectionView;
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

    NSDiffableDataSourceSnapshot<NSNumber *, PPUniversalCellViewModel *> *snapshot =
    [NSDiffableDataSourceSnapshot new];

    NSNumber *section = @(self.viewModel.currentSection);
    [snapshot appendSectionsWithIdentifiers:@[section]];
    [snapshot appendItemsWithIdentifiers:self.presentedItems
               intoSectionWithIdentifier:section];

    BOOL shouldAnimate = animated && self.view.window != nil;
    if (self.presentedItems.count > 120) {
        shouldAnimate = NO;
    }

    if (!shouldAnimate && [self.dataSource respondsToSelector:@selector(applySnapshotUsingReloadData:)]) {
        [self.dataSource applySnapshotUsingReloadData:snapshot];
    } else {
        [self.dataSource applySnapshot:snapshot
                    animatingDifferences:shouldAnimate];
    }
}

- (double)resolvedPriceForViewModel:(PPUniversalCellViewModel *)vm
{
    NSNumber *price = vm.finalPrice ?: vm.price;
    return MAX(0.0, price.doubleValue);
}

- (NSArray<PPUniversalCellViewModel *> *)filteredPresentedItemsFromSourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    // The VM now applies all data-model-level filters (condition, gender, service type,
    // hasOffer, price, sort).  The VC simply passes items through — this method is kept
    // as an integration point for any future presentation-only transforms.
    return sourceItems ?: @[];
}

- (void)refreshPresentedItemsAnimated:(BOOL)animated scrollToTop:(BOOL)scrollToTop
{
    // Keep the server-backed view model intact while the screen applies lightweight
    // presentation-only price filtering and sorting for the accessories experience.
    NSArray<PPUniversalCellViewModel *> *sourceItems = self.viewModel.items ?: @[];
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
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    self.filterChipContainer.semanticContentAttribute = semantic;
    self.filterChipStackView.semanticContentAttribute = semantic;

    PPFilterState *state = [self pp_filterStateForSection:section];
    NSArray<PPFilterGroup *> *groups = state.groups;
    NSInteger activeFilterCount = [self shouldShowFilterChipBarForSection:section] ? state.activeFilterCount : 0;
    [self.sectionsFiltersContainer pp_applyActiveFilterCount:activeFilterCount animated:self.view.window != nil];

    for (NSInteger i = 0; i < (NSInteger)self.filterChips.count && i < (NSInteger)groups.count; i++) {
        PPDropdownFilterChipButton *chip = self.filterChips[i];
        PPFilterGroup *group = groups[i];
        NSString *title = group.isActive ? group.selectedTitle : group.title;
        [chip pp_applyChipTitle:title active:group.isActive];
        chip.menu = [self pp_menuForFilterGroup:group chipIndex:i];
        chip.accessibilityLabel = group.title;
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

    BOOL isSameSection = (section == self.viewModel.currentSection);
    BOOL shouldSwitchSection = !isSameSection || self.viewModel.items.count == 0;

    [self updateSectionsTabBarSelectionForSection:section animated:userInitiated];

    if (userInitiated) {
        [PPFunc triggerLightHaptic];
    }

    if (!shouldSwitchSection) {
        if (userInitiated) {
            [self pp_applyFeedbackPulseToView:self.sectionsSegmentedControl];
        }
        [self scrollCollectionViewToTopAfterReload:YES];
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
    [self updateFilterChipVisibilityForSection:section animated:userInitiated];
    [self.viewModel switchToSection:section];
}

- (BOOL)shouldShowFilterChipBarForSection:(PPDataSection)section
{
    return (section == PPDataSectionAccessories);
}

- (void)syncFilterChipsForCurrentSection
{
    [self syncFilterChipsForSection:self.viewModel.currentSection];
}

- (void)syncFilterChipsForSection:(PPDataSection)section
{
    PPFilterState *state = [self pp_filterStateForSection:section];
    NSArray<PPFilterGroup *> *groups = state.groups;

    for (PPDropdownFilterChipButton *chip in self.filterChips) {
        [self.filterChipStackView removeArrangedSubview:chip];
        [chip removeFromSuperview];
    }
    [self.filterChips removeAllObjects];

    for (NSInteger i = 0; i < (NSInteger)groups.count; i++) {
        PPFilterGroup *group = groups[i];
        PPDropdownFilterChipButton *chip = [[PPDropdownFilterChipButton alloc] init];
        chip.chipIconName = group.chipIconName;
        chip.tag = i;
        chip.showsMenuAsPrimaryAction = YES;
        chip.menu = [self pp_menuForFilterGroup:group chipIndex:i];
        if (group.filterID.length > 0) {
            chip.accessibilityIdentifier = [NSString stringWithFormat:@"pp.dataView.filter.%@", group.filterID];
        }
        [self.filterChips addObject:chip];
        [self.filterChipStackView addArrangedSubview:chip];
    }

    [self refreshFilterChipTitlesForSection:section];
}

- (void)updateFilterChipVisibilityForSection:(PPDataSection)section animated:(BOOL)animated
{
    if (!self.filterChipContainer || !self.filterChipHeightConstraint) {
        return;
    }

    BOOL shouldShow = [self shouldShowFilterChipBarForSection:section];
    [self syncFilterChipsForSection:section];
    PPFilterState *state = [self pp_filterStateForSection:section];
    NSInteger activeFilterCount = shouldShow ? state.activeFilterCount : 0;
    [self.sectionsFiltersContainer pp_applyActiveFilterCount:activeFilterCount animated:animated && self.view.window != nil];

    self.filterChipContainer.hidden = NO;
    if (shouldShow && animated && self.filterChipContainer.alpha <= 0.01 && !UIAccessibilityIsReduceMotionEnabled()) {
        self.filterChipContainer.transform = CGAffineTransformMakeTranslation(0.0, -5.0);
    }

    void (^layoutChanges)(void) = ^{
        self.filterChipTopConstraint.constant = shouldShow ? 8.0 : 0.0;
        self.filterChipHeightConstraint.constant = shouldShow ? kPPAccessoryFilterHeight : 0.0;
        self.filterChipBottomConstraint.constant = shouldShow ? -12.0 : -4.0;
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
        [self updateCollectionContentInset];
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
            [self updateCollectionContentInset];
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
        [self updateCollectionContentInset];
    }];
}

// ---------- Dynamic filter menu builder ----------

- (UIMenu *)pp_menuForFilterGroup:(PPFilterGroup *)group chipIndex:(NSInteger)chipIndex
{
    __weak typeof(self) weakSelf = self;
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    for (PPFilterOption *opt in group.options) {
        NSString *optionIconName = [opt.iconName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        UIImage *optionImage = optionIconName.length > 0 ? [UIImage systemImageNamed:optionIconName] : nil;
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

    [PPFunc triggerLightHaptic];
    [self.viewModel applyFilterState:state];
    [self refreshPresentedItemsAnimated:YES scrollToTop:YES];
    [self pp_prefetchTopImagesWithLimit:12];
    [self updateEmptyState];
}

- (PPFilterState *)pp_currentFilterState
{
    return [self pp_filterStateForSection:self.viewModel.currentSection];
}

- (PPFilterState *)pp_filterStateForSection:(PPDataSection)section
{
    if (!self.filterStates) {
        self.filterStates = [NSMutableDictionary dictionary];
    }

    NSNumber *key = @(section);
    PPFilterState *state = self.filterStates[key];
    if (!state) {
        state = [PPFilterConfigProvider defaultFilterStateForSection:section];
        self.filterStates[key] = state;
    }
    return state;
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
    _navContainerView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
    self.navContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.navContainerView.isAccessibilityElement = NO;
    self.navContainerView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    
    if (!PPIOS26()) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.layer.cornerRadius = kPPDataViewNavigationChromeCornerRadius;
        blurView.clipsToBounds = YES;
        if (@available(iOS 13.0, *)) {
            blurView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        blurView.userInteractionEnabled = NO;
        [self.navContainerView insertSubview:blurView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.navContainerView.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.navContainerView.trailingAnchor]
        ]];
    }
    self.KindsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.KindsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.KindsButton.showsMenuAsPrimaryAction = YES;
    self.KindsButton.semanticContentAttribute = UISemanticContentAttributeUnspecified;
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
    sectionsBtn.semanticContentAttribute = UISemanticContentAttributeUnspecified;

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
    self.centerCapsuleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.centerCapsuleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.centerCapsuleButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
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

    self.cartButton = [self pp_ZeroButtonWithSystemName:@"magnifyingglass"
                                                  action:nil];
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
    [self.cartButton.widthAnchor constraintEqualToConstant:0];
    self.navContainerWidthConstraint =
    [self.navContainerView.widthAnchor constraintEqualToConstant:220];
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

        CGFloat inset = 5.0;
        CGFloat visibleChromeWidth = MAX(176.0, self.navContainerWidthConstraint.constant);
        CGFloat hiddenCartWidth = self.isCartButtonVisible ? 36.0 : 0.0;
        CGFloat insetCount = self.isCartButtonVisible ? 4.0 : 3.0;
        CGFloat availableSelectorWidth = MAX(150.0, visibleChromeWidth - (inset * insetCount) - hiddenCartWidth);
        CGFloat mainWidth = floor(availableSelectorWidth * 0.5);
        CGFloat cartWidth = self.isCartButtonVisible ? 36.0 : 0.0;
        CGFloat chromeWidth = (inset * insetCount) + mainWidth + cartWidth;
        CGFloat sectionWidth = MAX(0.0, visibleChromeWidth - chromeWidth);

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
    btn.semanticContentAttribute =Language.semanticAttributeForCurrentLanguage;
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
    btn.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    
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
    [self.layoutManager applyLayoutMode:self.layoutManager.currentLayoutMode
                       toCollectionView:self.collectionView
                               animated:NO];
    [self pp_installPinterestHeightGuardIfNeeded];
}

- (void)performCrossFadeReload
{
    if (!self.collectionView) { return; }
    [self pp_installPinterestHeightGuardIfNeeded];

    if (!self.view.window) {
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
    [self.collectionView.layer removeAllAnimations];

    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.collectionView.alpha = 0.0;
    } completion:^(BOOL finished) {

        // Reload data while invisible
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        [self.collectionView layoutIfNeeded];

        [UIView animateWithDuration:0.22
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.collectionView.alpha = 1.0;
        } completion:^(BOOL finished) {
            self.collectionView.userInteractionEnabled = YES;
            self.isPerformingCrossFade = NO;
            
           // [self updateNavSectionTitle];
        }];
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
 
- (PPManagerCellLayoutMode)pp_currentActionsMenuLayoutMode
{
    PPManagerCellLayoutMode currentMode = self.layoutManager.currentLayoutMode;
    if (currentMode >= PPCellLayoutModeSquare &&
        currentMode <= PPCellLayoutModePinterest) {
        return currentMode;
    }

    PPManagerCellLayoutMode savedMode =
    (PPManagerCellLayoutMode)[[NSUserDefaults standardUserDefaults] integerForKey:kPPLayoutModeKey];
    if (savedMode >= PPCellLayoutModeSquare &&
        savedMode <= PPCellLayoutModePinterest) {
        return savedMode;
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
    if (mode < PPCellLayoutModeSquare || mode > PPCellLayoutModePinterest) {
        return;
    }

    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kPPLayoutModeKey];

    if (!self.layoutManager || !self.collectionView) {
        [self pp_refreshSearchActionsMenu];
        return;
    }

    if (self.layoutManager.currentLayoutMode == mode) {
        [PPFunc triggerLightHaptic];
        [self pp_refreshSearchActionsMenu];
        return;
    }

    PPDataViewLog(@"PPManagerCellLayoutMode selected %ld", (long)mode);
    [PPFunc triggerLightHaptic];
    [self.layoutManager applyLayoutMode:mode
                       toCollectionView:self.collectionView
                               animated:YES];
    [self pp_installPinterestHeightGuardIfNeeded];
    [self performCrossFadeReload];
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

    UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
    [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];
    cartNavBtn.accessibilityLabel = kLang(@"Cart");
    [self pp_applyPremiumNavIconButtonAppearance:cartNavBtn emphasized:YES];
    cartNavBtn.clipsToBounds = NO;
    [cartNavBtn.widthAnchor constraintEqualToConstant:42.0].active = YES;
    [cartNavBtn.heightAnchor constraintEqualToConstant:42.0].active = YES;
    self.navCartButton = cartNavBtn;
    [self pp_applyTemporaryHiddenCartButtonState];

    UIButton *searchNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    searchNavBtn.translatesAutoresizingMaskIntoConstraints = NO;
    searchNavBtn.clipsToBounds = NO;
    [searchNavBtn.widthAnchor constraintEqualToConstant:42.0].active = YES;
    [searchNavBtn.heightAnchor constraintEqualToConstant:42.0].active = YES;
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

    UIAction *layoutSquirePPAction =
    layoutAction(kLang(@"PPCellLayoutSquare"),
                 @"square.fill",
                 PPCellLayoutModeSquare,
                 NO);

    UIAction *layoutFullPPAction =
    layoutAction(kLang(@"PPCellLayoutFullWidth"),
                 @"rectangle.fill",
                 PPCellLayoutModeFullWidth,
                 NO);

    UIMenuOptions primaryLayoutOptions = UIMenuOptionsDisplayInline;
    if (@available(iOS 17.0, *)) {
        primaryLayoutOptions = UIMenuOptionsDisplayAsPalette;
    }

    UIMenu *primaryLayoutMenu =
    [UIMenu menuWithTitle:(kLang(@"PPDataViewPrimaryLayouts") ?: @"")
                   image:[UIImage systemImageNamed:@"rectangle.grid.1x2"]
              identifier:nil
                 options:primaryLayoutOptions
                children:@[layoutPintrestPPAction, layoutLargePPAction]];

    UIMenu *utilityMenu =
    [UIMenu menuWithTitle:@""
                   image:nil
              identifier:nil
                 options:UIMenuOptionsDisplayInline
                children:@[searchPPAction, filterPPAction]];

    UIMenu *secondaryLayoutMenu =
    [UIMenu menuWithTitle:(kLang(@"PPDataViewMoreLayouts") ?: @"")
                   image:nil
              identifier:nil
                 options:UIMenuOptionsDisplayInline
                children:@[layoutSquirePPAction, layoutFullPPAction]];

    return [UIMenu menuWithTitle:(kLang(@"PPDataViewActionsTitle") ?: @"")
                           image:nil
                      identifier:nil
                         options:0
                        children:@[primaryLayoutMenu, utilityMenu, secondaryLayoutMenu]];
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
    PPModrenSegmrnted *sectionsControl = [[PPModrenSegmrnted alloc] initWithItems:sectionItems];
    sectionsControl.translatesAutoresizingMaskIntoConstraints = NO;
    sectionsControl.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    sectionsControl.accessibilityIdentifier = @"pp.data.sectionsTabBar";
    [sectionsControl setSelectedIndex:[self pp_segmentIndexForSection:PPDataSectionAds] animated:NO];
    [sectionsControl addTarget:self
                        action:@selector(sectionsSegmentedControlChanged:)
              forControlEvents:UIControlEventValueChanged];

    self.sectionsSegmentedControl = sectionsControl;

    PPDataViewControlIslandView *controlIsland = [[PPDataViewControlIslandView alloc] init];
    controlIsland.translatesAutoresizingMaskIntoConstraints = NO;
    controlIsland.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    controlIsland.accessibilityIdentifier = @"pp.data.sectionsFiltersIsland";
    self.sectionsFiltersContainer = controlIsland;

    [self.view addSubview:controlIsland];
    [controlIsland addSubview:sectionsControl];
    [self pp_applyPremiumSectionsSegmentedAppearance];

    self.sectionsTabBarHeightConstraint =
    [sectionsControl.heightAnchor constraintEqualToConstant:PPCurrentSectionsTabBarHeight()];
    self.sectionsTabBarHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [controlIsland.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPIOS26() ? 8.0 : 12.0],
        [controlIsland.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [controlIsland.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [sectionsControl.topAnchor constraintEqualToAnchor:controlIsland.topAnchor constant:4.0],
        [sectionsControl.leadingAnchor constraintEqualToAnchor:controlIsland.leadingAnchor constant:4.0],
        [sectionsControl.trailingAnchor constraintEqualToAnchor:controlIsland.trailingAnchor constant:-4.0]
    ]];
    [self pp_prepareSectionsSegmentedEntranceInitialState];
    
    UIView *filterContainer = [[UIView alloc] init];
    filterContainer.translatesAutoresizingMaskIntoConstraints = NO;
    filterContainer.backgroundColor = UIColor.clearColor;
    filterContainer.clipsToBounds = NO;
    filterContainer.hidden = YES;
    filterContainer.alpha = 0.0;
    filterContainer.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.filterChipContainer = filterContainer;

    [controlIsland addSubview:filterContainer];

    self.filterChipHeightConstraint =
    [filterContainer.heightAnchor constraintEqualToConstant:0.0];
    self.filterChipHeightConstraint.active = YES;
    self.filterChipTopConstraint =
    [filterContainer.topAnchor constraintEqualToAnchor:self.sectionsSegmentedControl.bottomAnchor constant:0.0];
    self.filterChipTopConstraint.active = YES;

    self.filterChipBottomConstraint = [filterContainer.bottomAnchor constraintEqualToAnchor:controlIsland.bottomAnchor constant:-8.0];
    self.filterChipBottomConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [filterContainer.leadingAnchor constraintEqualToAnchor:controlIsland.leadingAnchor constant:12.0],
        [filterContainer.trailingAnchor constraintEqualToAnchor:controlIsland.trailingAnchor constant:-12.0]
    ]];

    // Dynamic filter chips — created from PPFilterState for the initial section
    self.filterChips = [NSMutableArray array];
    UIStackView *chipsStack = [[UIStackView alloc] init];
    chipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    chipsStack.axis = UILayoutConstraintAxisHorizontal;
    chipsStack.alignment = UIStackViewAlignmentFill;
    chipsStack.distribution = UIStackViewDistributionFillEqually;
    chipsStack.spacing = 8.0;
    chipsStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.filterChipStackView = chipsStack;
    [filterContainer addSubview:chipsStack];

    [NSLayoutConstraint activateConstraints:@[
        [chipsStack.topAnchor constraintEqualToAnchor:filterContainer.topAnchor constant:4.0],
        [chipsStack.leadingAnchor constraintEqualToAnchor:filterContainer.leadingAnchor],
        [chipsStack.trailingAnchor constraintEqualToAnchor:filterContainer.trailingAnchor],
        [chipsStack.bottomAnchor constraintEqualToAnchor:filterContainer.bottomAnchor constant:-4.0],
    ]];

    // Initialize per-section filter state dictionary
    self.filterStates = [NSMutableDictionary dictionary];

    [self syncFilterChipsForCurrentSection];
}

- (void)sectionsSegmentedControlChanged:(PPModrenSegmrnted *)sender
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

@end
    

    
