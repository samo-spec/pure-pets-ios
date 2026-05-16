//
//  PPPaymentSelectionViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import "PPSelectPaymentVC.h"
#import "PPSelectPaymentVC+Helper.h"
#import "PPAddressPickerView.h"
#import "PPCheckoutCoordinator.h"
#import "PPPaymentManager.h"
#import "CartManager.h"
#import "PPCartCalculator.h"
#import "PPAddressesManager.h"
#import "UserModel.h"
#import "AddressFormVC.h"
#import "UserManager.h"
#import "PPCommerceFeedbackManager.h"
#import "OrderDetailsViewController.h"
#import "Styling.h"
#import "PetCareHelpers.h"

#import "PPSelectAddressVC.h"
#import <QuartzCore/QuartzCore.h>

@import FirebaseAuth;

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

static NSString * const PPOrderCheckoutPreflightErrorDomain = @"PPOrderCheckoutPreflight";

static NSString *PPPaymentHeroAnimationName(void)
{
    return @"PurePetsCard3";
}

static NSDictionary *PPPaymentHeroLocalJSON(void)
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:PPPaymentHeroAnimationName() withExtension:@"json"];
    if (!url) {
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:nil];
    if (data.length == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError || ![json isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    return json;
}

static NSArray<NSNumber *> *PPPaymentHeroLottieRGBA(UIColor *color)
{
    UIColor *resolved = color ?: UIColor.labelColor;
    CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
    if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
        const CGFloat *components = CGColorGetComponents(resolved.CGColor);
        size_t count = CGColorGetNumberOfComponents(resolved.CGColor);
        if (components && count >= 3) {
            r = components[0];
            g = components[1];
            b = components[2];
            a = (count >= 4) ? components[3] : 1.0;
        } else if (components && count >= 2) {
            r = components[0];
            g = components[0];
            b = components[0];
            a = components[1];
        }
    }
    return @[@(r), @(g), @(b), @(a)];
}

static NSString *PPPaymentHeroLottieColorKey(UIColor *color)
{
    NSArray<NSNumber *> *rgba = PPPaymentHeroLottieRGBA(color);
    return [NSString stringWithFormat:@"%.3f-%.3f-%.3f-%.3f",
            rgba[0].doubleValue,
            rgba[1].doubleValue,
            rgba[2].doubleValue,
            rgba[3].doubleValue];
}

static BOOL PPPaymentHeroLottieColorArrayIsLight(NSArray *colorArray)
{
    if (![colorArray isKindOfClass:NSArray.class] || colorArray.count < 3) {
        return NO;
    }
    CGFloat r = [colorArray[0] doubleValue];
    CGFloat g = [colorArray[1] doubleValue];
    CGFloat b = [colorArray[2] doubleValue];
    return ((r + g + b) / 3.0) > 0.86;
}

static void PPPaymentHeroApplyLottieRGBA(NSMutableArray *colorArray, NSArray<NSNumber *> *rgba)
{
    if (![colorArray isKindOfClass:NSMutableArray.class] || colorArray.count < 3) {
        return;
    }
    colorArray[0] = rgba[0];
    colorArray[1] = rgba[1];
    colorArray[2] = rgba[2];
    if (colorArray.count >= 4 && rgba.count >= 4) {
        colorArray[3] = rgba[3];
    }
}

static void PPPaymentHeroRetintLottieColorObject(NSMutableDictionary *colorObject,
                                                  NSArray<NSNumber *> *primaryRGBA,
                                                  NSArray<NSNumber *> *highlightRGBA)
{
    if (![colorObject isKindOfClass:NSMutableDictionary.class]) {
        return;
    }

    id k = colorObject[@"k"];
    if ([k isKindOfClass:NSMutableArray.class]) {
        NSMutableArray *array = (NSMutableArray *)k;
        if (array.count >= 3 && [array[0] isKindOfClass:NSNumber.class]) {
            PPPaymentHeroApplyLottieRGBA(array, PPPaymentHeroLottieColorArrayIsLight(array) ? highlightRGBA : primaryRGBA);
            return;
        }

        for (id frame in array) {
            if (![frame isKindOfClass:NSMutableDictionary.class]) {
                continue;
            }
            NSMutableDictionary *frameDict = (NSMutableDictionary *)frame;
            for (NSString *key in @[@"s", @"e", @"k"]) {
                id value = frameDict[key];
                if ([value isKindOfClass:NSMutableArray.class]) {
                    NSMutableArray *colorArray = (NSMutableArray *)value;
                    PPPaymentHeroApplyLottieRGBA(colorArray, PPPaymentHeroLottieColorArrayIsLight(colorArray) ? highlightRGBA : primaryRGBA);
                }
            }
        }
    }
}

static void PPPaymentHeroRetintLottieNode(id node,
                                          NSArray<NSNumber *> *primaryRGBA,
                                          NSArray<NSNumber *> *highlightRGBA)
{
    if ([node isKindOfClass:NSMutableDictionary.class]) {
        NSMutableDictionary *dict = (NSMutableDictionary *)node;
        NSString *type = [dict[@"ty"] isKindOfClass:NSString.class] ? dict[@"ty"] : nil;
        if (([type isEqualToString:@"fl"] || [type isEqualToString:@"st"]) &&
            [dict[@"c"] isKindOfClass:NSMutableDictionary.class]) {
            PPPaymentHeroRetintLottieColorObject(dict[@"c"], primaryRGBA, highlightRGBA);
        }
        for (id value in dict.allValues) {
            PPPaymentHeroRetintLottieNode(value, primaryRGBA, highlightRGBA);
        }
    } else if ([node isKindOfClass:NSMutableArray.class]) {
        for (id value in (NSMutableArray *)node) {
            PPPaymentHeroRetintLottieNode(value, primaryRGBA, highlightRGBA);
        }
    }
}

static NSDictionary *PPPaymentHeroRetintedLottieJSON(NSDictionary *jsonDict,
                                                     UIColor *primaryColor,
                                                     UIColor *highlightColor)
{
    if (![jsonDict isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
    if (!data) {
        return jsonDict;
    }

    id mutableJSON = [NSJSONSerialization JSONObjectWithData:data
                                                     options:NSJSONReadingMutableContainers
                                                       error:nil];
    if (![mutableJSON isKindOfClass:NSMutableDictionary.class]) {
        return jsonDict;
    }

    PPPaymentHeroRetintLottieNode(mutableJSON,
                                  PPPaymentHeroLottieRGBA(primaryColor),
                                  PPPaymentHeroLottieRGBA(highlightColor));
    return mutableJSON;
}

static LOTComposition *PPPaymentPremiumHeroCompositionWithTint(UIColor *primaryColor,
                                                               UIColor *highlightColor)
{
    NSDictionary *json = PPPaymentHeroLocalJSON();
    if (!json) {
        return nil;
    }

    NSDictionary *retintedJSON = PPPaymentHeroRetintedLottieJSON(json, primaryColor, highlightColor) ?: json;
    return [LOTComposition animationFromJSON:retintedJSON];
}

#pragma mark - ViewController

@interface PPSelectPaymentVC ()
@property (nonatomic, strong, nullable) UIVisualEffectView *dimOverlay;
@property (nonatomic, strong) UILabel *collectionHintLabel;
@property (nonatomic, strong) NSArray<PPAddressModel *> *Addresses;
@property (nonatomic, strong) PPAddressModel *selectedAddress;
@property (nonatomic, strong) PPCheckoutCoordinator *checkoutCoordinator;
@property (nonatomic, assign) BOOL isCheckoutInProgress;
@property (nonatomic, strong) id<FIRListenerRegistration> addressesListener;
@property (nonatomic, strong) PPAddressPickerView *locView;
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) UIView *heroFillView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIView *heroLargeOrbView;
@property (nonatomic, strong) UIView *heroSmallOrbView;
@property (nonatomic, strong) UIView *heroIconPlateView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) LOTAnimationView *heroAnimationView;
@property (nonatomic, strong) UIButton *heroBackButton;
@property (nonatomic, strong) UIView *heroSecureBadgeView;
@property (nonatomic, strong) UIView *paymentBackgroundGlowTopView;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, strong) UIView *bottomSecondaryGlowView;
@property (nonatomic, strong) UIView *bottomTrailGlowView;
@property (nonatomic, strong) PPInsetLabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) PaddedLabel *heroSubtitleLabel;
@property (nonatomic, assign) BOOL didAnimatePaymentHeroEntrance;
@property (nonatomic, assign) BOOL didStartPaymentHeroAmbientMotion;
@property (nonatomic, assign) NSInteger heroAnimationLoadToken;
@property (nonatomic, copy) NSString *currentHeroAnimationName;

- (void)pp_preparePaymentHeroEntranceState;
- (void)pp_animatePaymentHeroEntranceIfNeeded;
- (void)pp_applyPaymentHeroTheme;
- (void)pp_configurePaymentHeroAnimationIfNeeded;
- (void)pp_revealPaymentHeroAnimation;
- (void)pp_buildPaymentBackgroundAtmosphereIfNeeded;
- (void)pp_beginPaymentHeroAmbientMotionIfNeeded;
- (void)pp_stopPaymentHeroAmbientMotion;
@end


@implementation PPSelectPaymentVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
     [[CartManager sharedManager] refreshPricingConfiguration];
    [self pp_applyPaymentHeroTheme];
    [self.summaryView setCheckoutLoading:self.isCheckoutInProgress];
    [self pp_startSummaryBottomGlowMotionIfNeeded];
    [_summaryView pp_startTrustBannerShimmer];
    [self pp_setupInitialAddressState];
    [self pp_refreshCheckoutCallToAction];

    [self pp_navBarSetVisible:NO animated:NO];

    UINavigationBar *navBar = self.navigationController.navigationBar;

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];

        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor; // 🔥 THIS removes the line

        navBar.standardAppearance = appearance;
        navBar.scrollEdgeAppearance = appearance;
        navBar.compactAppearance = appearance;
    }

    navBar.translucent = YES;
    navBar.backgroundColor = UIColor.clearColor;
    navBar.alpha = 0.0;  navBar.layer.shadowOpacity = 0.0;  self.extendedLayoutIncludesOpaqueBars = YES;
    self.edgesForExtendedLayout = UIRectEdgeAll;


}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
     [self.heroAnimationView stop];
    [self pp_stopPaymentHeroAmbientMotion];
    [self pp_stopSummaryBottomGlowMotion];
    // [_summaryView pp_stopTrustBannerShimmer];

    [self pp_navBarSetVisible:YES animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.availableMethods = [PaymentMethod defaultMethods];
    self.userInstruments = @[];
    self.view.backgroundColor = AppBageColor();
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.title = kLang(@"SelectPaymentMethod");

     [self pp_buildPaymentBackgroundAtmosphereIfNeeded];
    [self pp_buildSummaryBottomGlowIfNeeded];
    [self pp_setupHeroSection];
    [self setlocViewViewAtTop];
    [self setSummuryViewAtBottom];
    [self setupPaymentCollection];
    [self pp_applyDefaultSelectionIfNeeded];
    [self pp_refreshCheckoutCallToAction];
    [self fetchUserPaymentInstruments];
    [self pp_refreshLatestAddressesForCheckout:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleAddressDidChangeNotification:)
                                                 name:PPAddressesDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleUserDidSyncNotification:)
                                                 name:PPUserManagerDidSyncCurrentUserNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleUserDidSignOutNotification:)
                                                 name:PPUserManagerDidSignOutNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handlePricingConfigurationDidChangeNotification:)
                                                 name:kCartPricingConfigurationDidChangeNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.heroCardView) {
        [self pp_applyPaymentHeroTheme];
    }
    if (!CGRectIsEmpty(self.heroCardView.bounds)) {
        self.heroCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroCardView.bounds
                                                                        cornerRadius:self.heroCardView.layer.cornerRadius].CGPath;
    }
    if (!CGRectIsEmpty(self.heroFillView.bounds)) {
        self.heroGradientLayer.frame = self.heroFillView.bounds;
        self.heroGradientLayer.cornerRadius = self.heroFillView.layer.cornerRadius;
    }
    if (self.heroLargeOrbView && !CGRectIsEmpty(self.heroLargeOrbView.bounds)) {
        self.heroLargeOrbView.layer.cornerRadius = CGRectGetWidth(self.heroLargeOrbView.bounds) * 0.5;
        self.heroLargeOrbView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.heroLargeOrbView.bounds].CGPath;
    }
    if (self.heroSmallOrbView && !CGRectIsEmpty(self.heroSmallOrbView.bounds)) {
        self.heroSmallOrbView.layer.cornerRadius = CGRectGetWidth(self.heroSmallOrbView.bounds) * 0.5;
        self.heroSmallOrbView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.heroSmallOrbView.bounds].CGPath;
    }
    if (self.paymentBackgroundGlowTopView && !CGRectIsEmpty(self.paymentBackgroundGlowTopView.bounds)) {
        self.paymentBackgroundGlowTopView.layer.cornerRadius = CGRectGetWidth(self.paymentBackgroundGlowTopView.bounds) * 0.5;
        self.paymentBackgroundGlowTopView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.paymentBackgroundGlowTopView.bounds].CGPath;
    }
    if (!CGRectIsEmpty(self.bottomGlowView.bounds)) {
        self.bottomGlowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bottomGlowView.bounds].CGPath;
    }
    if (!CGRectIsEmpty(self.bottomSecondaryGlowView.bounds)) {
        self.bottomSecondaryGlowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bottomSecondaryGlowView.bounds].CGPath;
    }
    if (!CGRectIsEmpty(self.bottomTrailGlowView.bounds)) {
        self.bottomTrailGlowView.layer.cornerRadius = CGRectGetWidth(self.bottomTrailGlowView.bounds) * 0.5;
        self.bottomTrailGlowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bottomTrailGlowView.bounds].CGPath;
    }

    [self.heroCardView bringSubviewToFront:self.heroSubtitleLabel];
    [self.view bringSubviewToFront:self.paymentBackgroundGlowTopView];
}

- (void)pp_buildPaymentBackgroundAtmosphereIfNeeded
{
    if (self.paymentBackgroundGlowTopView) return;

    UIView *topGlowView = [[UIView alloc] init];
    topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    topGlowView.userInteractionEnabled = NO;
    topGlowView.clipsToBounds = NO;
    topGlowView.layer.cornerRadius = 136.0;
    topGlowView.layer.shadowRadius = 68.0;
    topGlowView.layer.shadowOpacity = 0.28;
    topGlowView.layer.shadowOffset = CGSizeZero;
    if (self.heroCardView.superview == self.view) {
        [self.view insertSubview:topGlowView belowSubview:self.heroCardView];
    } else {
        [self.view addSubview:topGlowView];
        [self.view sendSubviewToBack:topGlowView];
    }

    [NSLayoutConstraint activateConstraints:@[
        [topGlowView.widthAnchor constraintEqualToConstant:272.0],
        [topGlowView.heightAnchor constraintEqualToConstant:272.0],
        [topGlowView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-82.0],
        [topGlowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:104.0]
    ]];

    self.paymentBackgroundGlowTopView = topGlowView;
}

- (void)pp_buildSummaryBottomGlowIfNeeded
{
    if (self.bottomGlowView || self.bottomSecondaryGlowView || self.bottomTrailGlowView) return;

    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIView *glow = [[UIView alloc] init];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.userInteractionEnabled = NO;
    glow.backgroundColor = [brandColor colorWithAlphaComponent:0.080];
    glow.alpha = 0.52;
    glow.layer.cornerRadius = 170.0;
    glow.layer.shadowColor = [brandColor colorWithAlphaComponent:0.55].CGColor;
    glow.layer.shadowOpacity = 0.24;
    glow.layer.shadowRadius = 48.0;
    glow.layer.shadowOffset = CGSizeZero;

    UIView *secondaryGlow = [[UIView alloc] init];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22];
    secondaryGlow.alpha = 0.36;
    secondaryGlow.layer.cornerRadius = 128.0;
    secondaryGlow.layer.shadowColor = UIColor.whiteColor.CGColor;
    secondaryGlow.layer.shadowOpacity = 0.18;
    secondaryGlow.layer.shadowRadius = 34.0;
    secondaryGlow.layer.shadowOffset = CGSizeZero;

    UIView *trailGlow = [[UIView alloc] init];
    trailGlow.translatesAutoresizingMaskIntoConstraints = NO;
    trailGlow.userInteractionEnabled = NO;
    trailGlow.backgroundColor = [brandColor colorWithAlphaComponent:0.070];
    trailGlow.alpha = 0.46;
    trailGlow.layer.cornerRadius = 210.0;
    trailGlow.layer.shadowColor = [brandColor colorWithAlphaComponent:0.48].CGColor;
    trailGlow.layer.shadowOpacity = 0.22;
    trailGlow.layer.shadowRadius = 58.0;
    trailGlow.layer.shadowOffset = CGSizeZero;

    [self.view addSubview:trailGlow];
    [self.view addSubview:secondaryGlow];
    [self.view addSubview:glow];

    [NSLayoutConstraint activateConstraints:@[
        [trailGlow.widthAnchor constraintEqualToConstant:420.0],
        [trailGlow.heightAnchor constraintEqualToConstant:420.0],
        [trailGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:150.0],
        [trailGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:176.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:256.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:256.0],
        [secondaryGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:72.0],
        [secondaryGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:86.0],

        [glow.widthAnchor constraintEqualToConstant:340.0],
        [glow.heightAnchor constraintEqualToConstant:340.0],
        [glow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:116.0],
        [glow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-134.0]
    ]];

    self.bottomGlowView = glow;
    self.bottomSecondaryGlowView = secondaryGlow;
    self.bottomTrailGlowView = trailGlow;

    self.bottomGlowView.alpha = 0;
    self.bottomSecondaryGlowView.alpha = 0;
    self.bottomTrailGlowView.alpha = 0;


    [self pp_startSummaryBottomGlowMotionIfNeeded];
}

- (void)pp_startSummaryBottomGlowMotionIfNeeded
{
    if (!self.bottomGlowView && !self.bottomSecondaryGlowView && !self.bottomTrailGlowView) return;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.bottomGlowView.layer removeAnimationForKey:@"pp_payment_bottom_glow_breath"];
        [self.bottomSecondaryGlowView.layer removeAnimationForKey:@"pp_payment_bottom_secondary_glow_breath"];
        [self.bottomTrailGlowView.layer removeAnimationForKey:@"pp_payment_bottom_trail_glow_breath"];
        self.bottomGlowView.transform = CGAffineTransformIdentity;
        self.bottomSecondaryGlowView.transform = CGAffineTransformIdentity;
        self.bottomTrailGlowView.transform = CGAffineTransformIdentity;
        self.bottomGlowView.alpha = 0.52;
        self.bottomSecondaryGlowView.alpha = 0.36;
        self.bottomTrailGlowView.alpha = 0.46;
        return;
    }

    [self pp_addBreathingGlowToView:self.bottomGlowView
                                 key:@"pp_payment_bottom_glow_breath"
                           fromAlpha:0.42
                             toAlpha:0.62
                           fromScale:0.95
                             toScale:1.08
                            duration:6.4];
    [self pp_addBreathingGlowToView:self.bottomSecondaryGlowView
                                 key:@"pp_payment_bottom_secondary_glow_breath"
                           fromAlpha:0.28
                             toAlpha:0.43
                           fromScale:1.04
                             toScale:0.96
                            duration:7.4];
    [self pp_addBreathingGlowToView:self.bottomTrailGlowView
                                 key:@"pp_payment_bottom_trail_glow_breath"
                           fromAlpha:0.34
                             toAlpha:0.52
                           fromScale:0.96
                             toScale:1.10
                            duration:8.2];
}

- (void)pp_addBreathingGlowToView:(UIView *)view
                               key:(NSString *)key
                         fromAlpha:(CGFloat)fromAlpha
                           toAlpha:(CGFloat)toAlpha
                         fromScale:(CGFloat)fromScale
                           toScale:(CGFloat)toScale
                          duration:(CFTimeInterval)duration
{
    if (!view || [view.layer animationForKey:key]) return;

    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @(fromAlpha);
    opacity.toValue = @(toAlpha);

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @(fromScale);
    scale.toValue = @(toScale);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[opacity, scale];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_stopSummaryBottomGlowMotion
{
    [self.bottomGlowView.layer removeAnimationForKey:@"pp_payment_bottom_glow_breath"];
    [self.bottomSecondaryGlowView.layer removeAnimationForKey:@"pp_payment_bottom_secondary_glow_breath"];
    [self.bottomTrailGlowView.layer removeAnimationForKey:@"pp_payment_bottom_trail_glow_breath"];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self pp_animatePaymentHeroEntranceIfNeeded];
    [self pp_beginPaymentHeroAmbientMotionIfNeeded];
    [self pp_configurePaymentHeroAnimationIfNeeded];

    // Reveal the summary view after the push transition and Auto Layout
    // have fully settled, so there is no layout-driven jump.
    if (self.summaryView && self.summaryView.alpha < 1.0) {
        [UIView animateWithDuration:0.45
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.summaryView.alpha = 1.0;
            self.summaryView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)setSummuryViewAtBottom
{
    self.summaryView = [[PPPremuimChekoutView alloc] init];
    [self.view addSubview:self.summaryView];
    self.summaryView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.summaryView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.summaryView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.summaryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    // Suppress the internal cardView entrance animation; this VC uses
    // its own entrance in viewDidAppear: instead.
    [self.summaryView skipCardEntranceAnimation];

    __weak typeof(self) weakSelf = self;
    self.summaryView.onTapCheckOut = ^{
        NSLog(@"Checkout tapped on PPSelectPaymentVC+Helper");
        [weakSelf finishPayments];
    };

    // Configure all data inside performWithoutAnimation so internal
    // setters (e.g. setShowsItemsPreview:) don't fire their own
    // UIView animations that conflict with the entrance reveal.
    PPCartSummary *summary = [PPCartCalculator currentSummary];
    BOOL showShowCollectionPreview = CartManager.sharedManager.cartItems.count > 3;

    [UIView performWithoutAnimation:^{
        [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:NO];
        self.summaryView.showDetails = !showShowCollectionPreview;
        [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];
        self.summaryView.showsItemsPreview = showShowCollectionPreview;
        [self.summaryView setCheckoutBTNTitle:kLang(@"payment_pay_now") image:[UIImage pp_symbolNamed:@"creditcard.fill" pointSize:18
                                                                                        weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:NO]];
        [self.summaryView layoutIfNeeded];
    }];

    if ([CartManager sharedManager].cartItems.count > 0) {
        [_summaryView pp_startTrustBannerShimmer];
    }

    // Start fully hidden. viewDidAppear: will reveal with a spring
    // animation after the push transition and Auto Layout have settled.
    self.summaryView.alpha = 0.0;
    self.summaryView.transform = CGAffineTransformMakeTranslation(0.0, 20.0);
}

- (void)setlocViewViewAtTop
{
    self.locView = [PPAddressPickerView showInViewController:self width:self.view.hx_w - 42];
    [self.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
    __weak typeof(self) weakSelf = self;
    self.locView.onPickAddress = ^{
        [weakSelf pp_presentAddressPickerOrPrompt];
    };
    [self.locView expandAndLock];

    // Re-anchor the address picker below the hero card instead of safe-area top
    self.locView.topConstraint.active = NO;
    self.locView.topConstraint = [self.locView.topAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:16.0];
    self.locView.topConstraint.active = YES;

    [self pp_setupInitialAddressState];
}

- (NSString *)pp_paymentHeroTextForKey:(NSString *)key fallbackKey:(NSString *)fallbackKey
{
    NSString *value = kLang(key);
    if (![value isKindOfClass:NSString.class] ||
        value.length == 0 ||
        [value isEqualToString:key]) {
        value = kLang(fallbackKey);
    }
    if (![value isKindOfClass:NSString.class] ||
        value.length == 0 ||
        [value isEqualToString:fallbackKey]) {
        return @"";
    }
    return value;
}

- (UIButton *)pp_makePaymentHeroBackButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityLabel = kLang(@"Back");

    UIImage *backImage = [UIImage pp_symbolNamed:PPChevronName
                                       pointSize:17.0
                                          weight:UIImageSymbolWeightSemibold
                                           scale:UIImageSymbolScaleMedium
                                         palette:@[UIColor.labelColor, UIColor.labelColor]
                                    makeTemplate:YES];
    UIColor *buttonFill = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:1.0 alpha:0.72];
    }];
    UIColor *buttonStroke = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor colorWithWhite:1.0 alpha:0.10]
            : [UIColor colorWithWhite:0.0 alpha:0.05];
    }];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.image = backImage;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
        config.baseForegroundColor = UIColor.labelColor;
        config.background.backgroundColor = buttonFill;
        config.background.strokeColor = buttonStroke;
        config.background.strokeWidth = 1.0;
        button.configuration = config;
    } else {
        [button setImage:backImage forState:UIControlStateNormal];
        button.tintColor = UIColor.labelColor;
        button.backgroundColor = buttonFill;
        button.layer.cornerRadius = 20.0;
        button.layer.borderWidth = 1.0;
        [button pp_setBorderColor:[buttonStroke resolvedColorWithTraitCollection:self.traitCollection]];
    }

    [button addTarget:self action:@selector(onBack:) forControlEvents:UIControlEventTouchUpInside];
    [button setContentCompressionResistancePriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisHorizontal];
    return button;
}

- (UIView *)pp_makePaymentHeroSecureBadgeWithBrandColor:(UIColor *)brandColor
{
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    badge.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat alpha = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.16 : 0.10;
        return [brandColor colorWithAlphaComponent:alpha];
    }];
    badge.layer.cornerRadius = 14.0;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    badge.layer.borderWidth = 0.8;
    [badge pp_setBorderColor:[brandColor colorWithAlphaComponent:0.14]];
    badge.layer.masksToBounds = YES;
    self.heroSecureBadgeView = badge;

    self.heroEyebrowLabel = [[PPInsetLabel alloc] init];
    self.heroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroEyebrowLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.heroEyebrowLabel.textColor = [brandColor colorWithAlphaComponent:0.94];
    self.heroEyebrowLabel.textAlignment = NSTextAlignmentCenter;
    self.heroEyebrowLabel.numberOfLines = 1;
    self.heroEyebrowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.heroEyebrowLabel.adjustsFontSizeToFitWidth = YES;
    self.heroEyebrowLabel.minimumScaleFactor = 0.82;
    self.heroEyebrowLabel.textInsets = UIEdgeInsetsMake(6.0, 12.0, 6.0, 12.0);
    self.heroEyebrowLabel.text = kLang(@"payment_screen_eyebrow");
    [badge addSubview:self.heroEyebrowLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroEyebrowLabel.topAnchor constraintEqualToAnchor:badge.topAnchor],
        [self.heroEyebrowLabel.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor],
        [self.heroEyebrowLabel.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor],
        [self.heroEyebrowLabel.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor]
    ]];

    [badge setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                          forAxis:UILayoutConstraintAxisHorizontal];
    [badge setContentHuggingPriority:UILayoutPriorityRequired
                              forAxis:UILayoutConstraintAxisHorizontal];
    return badge;
}

- (void)pp_setupHeroSection
{
    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemBlueColor;

    self.heroCardView = [[UIView alloc] init];
    self.heroCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCardView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.heroCardView.backgroundColor = PPPetCareSurfaceColor();
    self.heroCardView.layer.cornerRadius = 32.0;
    self.heroCardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroCardView.layer.borderWidth = 0.8;
    [self.heroCardView pp_setBorderColor:PPPetCareBorderColor()];
    [self.heroCardView pp_setShadowColor:[UIColor blackColor]];
    self.heroCardView.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.0 : 0.08;
    self.heroCardView.layer.shadowRadius = 24.0;
    self.heroCardView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    self.heroCardView.layer.masksToBounds = NO;
    [self.view addSubview:self.heroCardView];

    self.heroFillView = [[UIView alloc] init];
    self.heroFillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroFillView.layer.cornerRadius = 32.0;
    self.heroFillView.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroFillView.clipsToBounds = YES;
    [self.heroCardView addSubview:self.heroFillView];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.heroFillView.layer insertSublayer:self.heroGradientLayer atIndex:0];

    self.heroLargeOrbView = [[UIView alloc] init];
    self.heroLargeOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroLargeOrbView.userInteractionEnabled = NO;
    self.heroLargeOrbView.layer.cornerRadius = 60.0;
    [self.heroFillView addSubview:self.heroLargeOrbView];

    self.heroSmallOrbView = [[UIView alloc] init];
    self.heroSmallOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSmallOrbView.userInteractionEnabled = NO;
    self.heroSmallOrbView.layer.cornerRadius = 24.0;
    [self.heroFillView addSubview:self.heroSmallOrbView];

    self.heroBackButton = [self pp_makePaymentHeroBackButton];
    [self.heroCardView addSubview:self.heroBackButton];

    self.heroIconPlateView = [[UIView alloc] init];
    self.heroIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconPlateView.layer.cornerRadius = 24.0;
    self.heroIconPlateView.layer.borderWidth = 0.0;
    self.heroIconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroCardView addSubview:self.heroIconPlateView];

    UIImage *paymentIcon = [UIImage systemImageNamed:@"creditcard.and.123"];
    if (!paymentIcon) {
        paymentIcon = [UIImage systemImageNamed:@"creditcard.fill"];
    }
    self.heroIconView = [[UIImageView alloc] initWithImage:[paymentIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroIconView.isAccessibilityElement = NO;
    [self.heroIconPlateView addSubview:self.heroIconView];

    self.heroAnimationView = [[LOTAnimationView alloc] init];
    self.heroAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroAnimationView.loopAnimation = YES;
    self.heroAnimationView.animationSpeed = 0.44;
    self.heroAnimationView.userInteractionEnabled = NO;
    self.heroAnimationView.backgroundColor = UIColor.clearColor;
    self.heroAnimationView.opaque = NO;
    self.heroAnimationView.hidden = YES;
    self.heroAnimationView.alpha = 0.0;
    [self.heroIconPlateView addSubview:self.heroAnimationView];

    UIView *secureBadge = [self pp_makePaymentHeroSecureBadgeWithBrandColor:brandColor];
    [self.heroCardView addSubview:secureBadge];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = [GM boldFontWithSize:24.0] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    self.heroTitleLabel.textColor = PPPetCareTextColor();
    self.heroTitleLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.heroTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleLabel.minimumScaleFactor = 0.76;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.text = [self pp_paymentHeroTextForKey:@"payment_screen_title"
                                                  fallbackKey:@"SelectPaymentMethod"];
    self.heroTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.heroTitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                         forAxis:UILayoutConstraintAxisVertical];

    self.heroSubtitleLabel = [[PaddedLabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.heroSubtitleLabel.textColor = UIColor.secondaryLabelColor;
     self.heroSubtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.heroSubtitleLabel.hidden = NO;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.text = kLang(@"payment_screen_subtitle");
    self.heroSubtitleLabel.numberOfLines = 2;
    [self.heroSubtitleLabel setLineSpacing:2.0];
    [self.heroCardView addSubview:self.heroTitleLabel];
    [self.heroCardView addSubview:self.heroSubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroCardView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:2.0],
        [self.heroCardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.heroCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.heroCardView.heightAnchor constraintEqualToConstant:204.0],

        [self.heroFillView.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor],
        [self.heroFillView.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor],
        [self.heroFillView.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor],
        [self.heroFillView.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor],

        [self.heroLargeOrbView.widthAnchor constraintEqualToConstant:110.0],
        [self.heroLargeOrbView.heightAnchor constraintEqualToConstant:110.0],
        [self.heroLargeOrbView.trailingAnchor constraintEqualToAnchor:self.heroFillView.trailingAnchor constant:10.0],
        [self.heroLargeOrbView.topAnchor constraintEqualToAnchor:self.heroFillView.topAnchor constant:8.0],

        [self.heroSmallOrbView.widthAnchor constraintEqualToConstant:48.0],
        [self.heroSmallOrbView.heightAnchor constraintEqualToConstant:48.0],
        [self.heroSmallOrbView.leadingAnchor constraintEqualToAnchor:self.heroFillView.leadingAnchor constant:30.0],
        [self.heroSmallOrbView.bottomAnchor constraintEqualToAnchor:self.heroFillView.bottomAnchor constant:16.0],

        [self.heroBackButton.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:18.0],
        [self.heroBackButton.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:20.0],
        [self.heroBackButton.widthAnchor constraintEqualToConstant:40.0],
        [self.heroBackButton.heightAnchor constraintEqualToConstant:40.0],

        [self.heroIconPlateView.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-28.0],
        [self.heroIconPlateView.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:18.0],
        [self.heroIconPlateView.widthAnchor constraintEqualToConstant:48.0],
        [self.heroIconPlateView.heightAnchor constraintEqualToConstant:48.0],

        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconPlateView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconPlateView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:22.0],
        [self.heroIconView.heightAnchor constraintEqualToConstant:22.0],

        [self.heroAnimationView.centerXAnchor constraintEqualToAnchor:self.heroIconPlateView.centerXAnchor],
        [self.heroAnimationView.centerYAnchor constraintEqualToAnchor:self.heroIconPlateView.centerYAnchor],
        [self.heroAnimationView.widthAnchor constraintEqualToConstant:92.0],
        [self.heroAnimationView.heightAnchor constraintEqualToConstant:92.0],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:self.heroBackButton.bottomAnchor constant:7.0],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:20.0],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-20.0],

        [secureBadge.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [secureBadge.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:-14.0],
        [secureBadge.heightAnchor constraintEqualToConstant:28.0],
        [secureBadge.widthAnchor constraintGreaterThanOrEqualToConstant:96.0],
        [secureBadge.widthAnchor constraintLessThanOrEqualToConstant:190.0],


        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:4.0],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroIconPlateView.leadingAnchor constant:-18],
       // [self.heroSubtitleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:34.0],
        [self.heroSubtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:secureBadge.topAnchor constant:-10.0],


    ]];

    [self.heroCardView bringSubviewToFront:self.heroBackButton];
    [self.heroCardView bringSubviewToFront:self.heroIconPlateView];
    [self.heroCardView bringSubviewToFront:secureBadge];
    [self.heroCardView bringSubviewToFront:self.heroTitleLabel];


    [self pp_applyPaymentHeroTheme];
    [self pp_preparePaymentHeroEntranceState];
}

- (void)pp_preparePaymentHeroEntranceState
{
    if (!self.heroCardView) return;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.paymentBackgroundGlowTopView.alpha = 1.0;
        self.paymentBackgroundGlowTopView.transform = CGAffineTransformIdentity;
        self.heroCardView.alpha = 1.0;
        self.heroCardView.transform = CGAffineTransformIdentity;
        for (UIView *view in @[self.heroLargeOrbView, self.heroSmallOrbView, self.heroIconPlateView, self.heroBackButton, self.heroIconView, self.heroTitleLabel, self.heroSubtitleLabel, self.heroSecureBadgeView]) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }

    self.heroCardView.alpha = 0.0;
    self.heroCardView.transform = CGAffineTransformMakeTranslation(0.0, 24.0);
    self.paymentBackgroundGlowTopView.alpha = 0.0;
    self.paymentBackgroundGlowTopView.transform = CGAffineTransformMakeScale(0.92, 0.92);

    for (UIView *view in @[self.heroLargeOrbView, self.heroSmallOrbView]) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeScale(0.92, 0.92);
    }

    NSArray<UIView *> *heroDetailViews = @[
        self.heroIconPlateView,
        self.heroBackButton,
        self.heroIconView,
        self.heroTitleLabel,
        self.heroSubtitleLabel,
        self.heroSecureBadgeView
    ];
    for (UIView *view in heroDetailViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    }

    self.heroAnimationView.alpha = 0.0;
    self.heroAnimationView.transform = CGAffineTransformMakeScale(0.88, 0.88);
}

- (void)pp_animatePaymentHeroEntranceIfNeeded
{
    if (self.didAnimatePaymentHeroEntrance || !self.heroCardView) return;
    self.didAnimatePaymentHeroEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.paymentBackgroundGlowTopView.alpha = 1.0;
        self.paymentBackgroundGlowTopView.transform = CGAffineTransformIdentity;
        self.heroCardView.alpha = 1.0;
        self.heroCardView.transform = CGAffineTransformIdentity;
        for (UIView *view in @[self.heroLargeOrbView, self.heroSmallOrbView, self.heroIconPlateView, self.heroBackButton, self.heroIconView, self.heroTitleLabel, self.heroSubtitleLabel, self.heroSecureBadgeView]) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }

    [UIView animateWithDuration:0.82
                          delay:0.05
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.paymentBackgroundGlowTopView.alpha = 1.0;
        self.paymentBackgroundGlowTopView.transform = CGAffineTransformIdentity;
    } completion:nil];

    for (UIView *view in @[self.heroLargeOrbView, self.heroSmallOrbView]) {
        [UIView animateWithDuration:0.82
                              delay:0.05
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    [UIView animateWithDuration:0.58
                          delay:0.08
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.14
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroCardView.alpha = 1.0;
        self.heroCardView.transform = CGAffineTransformIdentity;
    } completion:nil];

    NSArray<UIView *> *heroDetailViews = @[
        self.heroIconPlateView,
        self.heroBackButton,
        self.heroIconView,
        self.heroTitleLabel,
        self.heroSubtitleLabel,
        self.heroSecureBadgeView
    ];
    [heroDetailViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:0.46
                              delay:0.16 + (0.04 * idx)
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_applyPaymentHeroTheme
{
    if (!self.heroCardView) return;

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPPetCareAccentColor();
    self.heroCardView.backgroundColor = PPPetCareSurfaceColor();
    [self.heroCardView pp_setBorderColor:PPPetCareBorderColor()];
    self.heroCardView.layer.shadowOpacity = dark ? 0.0 : 0.08;

    self.paymentBackgroundGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.14 : 0.17];
    self.paymentBackgroundGlowTopView.layer.shadowColor = [accent colorWithAlphaComponent:dark ? 0.24 : 0.22].CGColor;
    self.paymentBackgroundGlowTopView.layer.shadowOpacity = 0.28;
    self.paymentBackgroundGlowTopView.layer.shadowRadius = 68.0;
    self.paymentBackgroundGlowTopView.layer.shadowOffset = CGSizeZero;

    self.heroGradientLayer.colors = @[
        (id)[accent colorWithAlphaComponent:dark ? 0.0 : 0.0].CGColor,
        (id)[UIColor clearColor].CGColor
    ];

    self.heroLargeOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.08];
    self.heroLargeOrbView.layer.shadowColor = [accent colorWithAlphaComponent:dark ? 0.20 : 0.16].CGColor;
    self.heroLargeOrbView.layer.shadowOpacity = dark ? 0.14 : 0.18;
    self.heroLargeOrbView.layer.shadowRadius = 38.0;
    self.heroLargeOrbView.layer.shadowOffset = CGSizeZero;

    self.heroSmallOrbView.backgroundColor = [accent colorWithAlphaComponent:0.0];
    self.heroSmallOrbView.layer.shadowOpacity = 0.0;

    self.heroIconPlateView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.11];
    [self.heroIconPlateView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.16]];
    self.heroIconView.tintColor = accent;

    self.heroTitleLabel.textColor = PPPetCareTextColor();
    self.heroSubtitleLabel.textColor = dark
        ? [UIColor colorWithWhite:1.0 alpha:0.70]
        : PPPetCareSecondaryTextColor();
    self.heroEyebrowLabel.textColor = [accent colorWithAlphaComponent:dark ? 0.92 : 0.82];
    self.heroSecureBadgeView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.15 : 0.09];
    [self.heroSecureBadgeView pp_setBorderColor:PPPetCareBorderColor()];
}

- (void)pp_configurePaymentHeroAnimationIfNeeded
{
    NSString *animationName = PPPaymentHeroAnimationName();
    if (animationName.length == 0 || !self.heroAnimationView) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.heroAnimationView stop];
        self.heroAnimationView.hidden = YES;
        self.heroAnimationView.alpha = 0.0;
        self.heroAnimationView.transform = CGAffineTransformIdentity;
        self.heroIconView.hidden = NO;
        self.heroIconView.alpha = 1.0;
        return;
    }

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    UIColor *accent = PPPetCareAccentColor() ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *resolvedAccent = accent;
    if (@available(iOS 13.0, *)) {
        resolvedAccent = [accent resolvedColorWithTraitCollection:self.traitCollection];
    }
    UIColor *highlight = dark ? [UIColor colorWithWhite:1.0 alpha:0.92] : UIColor.whiteColor;
    NSString *animationKey = [NSString stringWithFormat:@"%@|%@|%@",
                              animationName,
                              PPPaymentHeroLottieColorKey(resolvedAccent),
                              PPPaymentHeroLottieColorKey(highlight)];

    if ([self.currentHeroAnimationName isEqualToString:animationKey]) {
        BOOL needsReveal = self.heroAnimationView.hidden
            || self.heroAnimationView.alpha < 0.99
            || !CGAffineTransformEqualToTransform(self.heroAnimationView.transform, CGAffineTransformIdentity);
        if (needsReveal && self.heroAnimationView.sceneModel) {
            [self pp_revealPaymentHeroAnimation];
            return;
        }
        if (!self.heroAnimationView.hidden && !self.heroAnimationView.isAnimationPlaying) {
            [self.heroAnimationView play];
        }
        return;
    }

    self.currentHeroAnimationName = animationKey;
    self.heroAnimationLoadToken += 1;
    NSInteger token = self.heroAnimationLoadToken;

    [self.heroAnimationView stop];
    self.heroAnimationView.hidden = YES;
    self.heroAnimationView.alpha = 0.0;
    self.heroAnimationView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    self.heroIconView.hidden = NO;
    self.heroIconView.alpha = MAX(self.heroIconView.alpha, self.didAnimatePaymentHeroEntrance ? 1.0 : 0.0);

    LOTComposition *localComposition = PPPaymentPremiumHeroCompositionWithTint(resolvedAccent, highlight);
    if (localComposition) {
        self.heroAnimationView.animationSpeed = 0.44;
        [self.heroAnimationView setSceneModel:localComposition];
        [self pp_revealPaymentHeroAnimation];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [Styling setAnimationNamed:animationName
                        toView:self.heroAnimationView
                     withSpeed:0.44
                 loopAnimation:YES
                      autoplay:NO
                    completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.heroAnimationLoadToken != token) {
                return;
            }

            if (!success) {
                self.heroAnimationView.hidden = YES;
                self.heroIconView.hidden = NO;
                return;
            }

            [self pp_revealPaymentHeroAnimation];
        });
    }];
}

- (void)pp_revealPaymentHeroAnimation
{
    self.heroAnimationView.loopAnimation = YES;
    self.heroAnimationView.hidden = NO;
    self.heroIconView.hidden = YES;
    [self.heroAnimationView setNeedsLayout];
    [self.heroAnimationView layoutIfNeeded];
    [self.heroAnimationView play];

    [UIView animateWithDuration:0.26
                          delay:self.didAnimatePaymentHeroEntrance ? 0.08 : 0.34
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAnimationView.alpha = 1.0;
        self.heroAnimationView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_beginPaymentHeroAmbientMotionIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopPaymentHeroAmbientMotion];
        self.paymentBackgroundGlowTopView.transform = CGAffineTransformIdentity;
        self.heroLargeOrbView.transform = CGAffineTransformIdentity;
        self.heroSmallOrbView.transform = CGAffineTransformIdentity;
        return;
    }

    if (self.didStartPaymentHeroAmbientMotion) {
        return;
    }
    self.didStartPaymentHeroAmbientMotion = YES;

    [UIView animateWithDuration:6.0
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.paymentBackgroundGlowTopView.transform = CGAffineTransformMakeTranslation(-16.0, 12.0);
        self.heroLargeOrbView.transform = CGAffineTransformMakeTranslation(-16.0, 12.0);
    } completion:nil];

    [UIView animateWithDuration:7.4
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSmallOrbView.transform = CGAffineTransformMakeTranslation(18.0, -14.0);
    } completion:nil];
}

- (void)pp_stopPaymentHeroAmbientMotion
{
    self.didStartPaymentHeroAmbientMotion = NO;
    [self.paymentBackgroundGlowTopView.layer removeAllAnimations];
    [self.heroLargeOrbView.layer removeAllAnimations];
    [self.heroSmallOrbView.layer removeAllAnimations];
    self.paymentBackgroundGlowTopView.transform = CGAffineTransformIdentity;
    self.heroLargeOrbView.transform = CGAffineTransformIdentity;
    self.heroSmallOrbView.transform = CGAffineTransformIdentity;
}

- (NSString *)pp_trimmedAddressString:(id)value
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)pp_effectiveAddressID:(PPAddressModel *)address
{
    if (!address) return @"";
    NSString *documentID = [self pp_trimmedAddressString:address.documentID];
    if (documentID.length > 0) return documentID;
    return [self pp_trimmedAddressString:address.addressID];
}

- (NSString *)pp_bestAddressDisplayText:(PPAddressModel *)address
{
    if (!address) return @"";

    NSString *displayName = [self pp_trimmedAddressString:address.displayName];
    if (displayName.length > 0) return displayName;

    NSString *legacyLocation = [self pp_trimmedAddressString:address.locatioName];
    if (legacyLocation.length > 0) return legacyLocation;

    NSString *line1 = [self pp_trimmedAddressString:address.addressLine1];
    if (line1.length > 0) return line1;

    NSString *fullName = [self pp_trimmedAddressString:address.fullName];
    if (fullName.length > 0) return fullName;

    return @"";
}

- (void)pp_setupInitialAddressState
{
    [self.addressesListener remove];
    self.addressesListener = nil;
    self.Addresses = @[];
    self.selectedAddress = nil;
    [self.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];

    if (![self pp_hasAuthenticatedUser]) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    self.addressesListener = [PPADDRESS listenToAddressesWithBlock:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error) {
            PPORDERLog(@"Address listener error | error=%@", error.localizedDescription ?: @"Unknown");
            return;
        }
        [weakSelf pp_applyAddresses:addresses ?: @[]];
    }];

    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_applyAddresses:(NSArray<PPAddressModel *> *)addresses
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.Addresses = addresses ?: @[];
        UserModel *currentUser = UsrMgr.currentUser;
        if (currentUser) {
            currentUser.Addresses = strongSelf.Addresses.mutableCopy;
            [UsrMgr cacheUser:currentUser];
        }
        PPAddressModel *preferred = [strongSelf pp_preferredAddressFrom:strongSelf.Addresses];
        strongSelf.selectedAddress = preferred;
        PPORDERLog(@"Addresses refreshed | count=%lu | selectedAddressId=%@",
                   (unsigned long)strongSelf.Addresses.count,
                   [strongSelf pp_effectiveAddressID:preferred]);

        NSString *addressText = [strongSelf pp_bestAddressDisplayText:preferred];
        if (addressText.length > 0) {
            [strongSelf.locView setAddressText:addressText];
        } else {
            [strongSelf.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
        }
    });
}

- (PPAddressModel *)pp_preferredAddressFrom:(NSArray<PPAddressModel *> *)addresses
{
    if (addresses.count == 0) return nil;

    NSString *selectedID = [self pp_effectiveAddressID:self.selectedAddress];
    if (selectedID.length > 0) {
        for (PPAddressModel *address in addresses) {
            NSString *candidateID = [self pp_effectiveAddressID:address];
            if ([candidateID isEqualToString:selectedID]) {
                return address;
            }
        }
    }

    for (PPAddressModel *address in addresses) {
        if (address.isDefault) {
            return address;
        }
    }

    return addresses.firstObject;
}

- (void)pp_presentAddressPickerOrPrompt
{
    __weak typeof(self) weakSelf = self;
    void (^presentPicker)(NSArray<PPAddressModel *> *) = ^(NSArray<PPAddressModel *> *addresses) {
        PPSelectAddressVC *vc =
        [[PPSelectAddressVC alloc] initWithOptions:addresses
                                                        title:kLang(@"select_delivery_location_title")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                    completion:^(id  _Nullable selectedObject) {
            PPAddressModel *selected = (PPAddressModel *)selectedObject;
            if (!selected) return;
            weakSelf.selectedAddress = selected;
            NSString *selectedText = [weakSelf pp_bestAddressDisplayText:selected];
            [weakSelf.locView setAddressText:selectedText.length > 0 ? selectedText : kLang(@"PleaseSelectDeliveryLocation")];
        }];
        [PPFunc presentSheetFrom:weakSelf sheetVC:vc detentStyle:PPSheetDetentStyle80];
        
    };

    if (self.Addresses.count > 0) {
        presentPicker(self.Addresses);
        return;
    }

    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (!error && addresses.count > 0) {
            [weakSelf pp_applyAddresses:addresses];
            presentPicker(weakSelf.Addresses);
            return;
        }

        [weakSelf.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
        [PPAlertHelper showConfirmationIn:weakSelf
                                    title:kLang(@"addr_empty_title")
                                 subtitle:kLang(@"addr_empty_subtitle")
                            confirmButton:kLang(@"addr_empty_btn_add")
                             cancelButton:kLang(@"addr_empty_btn_notnow")
                                     icon:[UIImage systemImageNamed:@"house.circle"]
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if (!didConfirm) return;
            [weakSelf pp_goToAddNewAddressScreen];
        } cancelBlock:^{}];
    }];
}
- (void)pp_goToAddNewAddressScreen {
    AddressFormVC *formVC = [[AddressFormVC alloc] initWithAddress:nil];
    [self.navigationController pushViewController:formVC animated:YES];
}

- (void)pp_handleAddressDidChangeNotification:(NSNotification *)notification
{
    NSString *uid = [notification.userInfo[@"uid"] isKindOfClass:NSString.class] ? notification.userInfo[@"uid"] : @"";
    NSString *currentUID = [PPADDRESS currentAuthenticatedUserID] ?: @"";
    if (uid.length > 0 &&
        currentUID.length > 0 &&
        ![uid isEqualToString:currentUID]) {
        return;
    }
    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_handleUserDidSyncNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_handleUserDidSignOutNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_applyAddresses:@[]];
}

- (void)pp_handlePricingConfigurationDidChangeNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshCheckoutPricingPresentation];
}

- (void)pp_refreshCheckoutPricingPresentation
{
    PPCartSummary *summary = [PPCartCalculator currentSummary];

    [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:NO];
    [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];

    [self pp_applyDefaultSelectionIfNeeded];
    [self.paymentCollection reloadData];
}

- (void)setupPaymentCollection {
    if (self.paymentCollection) return;

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 16.0;
    layout.minimumLineSpacing = 16.0;
    layout.sectionInset = UIEdgeInsetsMake(12.0, 16.0, 24.0, 16.0);
    layout.estimatedItemSize = CGSizeZero;
    self.paymentCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.paymentCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.paymentCollection.delegate = self;
    self.paymentCollection.dataSource = self;
    self.paymentCollection.backgroundColor = UIColor.clearColor;
    self.paymentCollection.alwaysBounceVertical = YES;
    self.paymentCollection.showsVerticalScrollIndicator = NO;
    [self.paymentCollection registerClass:[PPPaymentMethodCell class] forCellWithReuseIdentifier:@"PaymentMethodCell"];
    [self.paymentCollection registerClass:[PPPaymentSectionHeaderView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                      withReuseIdentifier:@"PPPaymentSectionHeaderView"];
    [self.paymentCollection registerClass:[UICollectionReusableView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                      withReuseIdentifier:@"FooterView"];
    
    
    
    [self.view addSubview:self.paymentCollection];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.paymentCollection.topAnchor constraintEqualToAnchor:self.locView.bottomAnchor constant:10.0],
        [self.paymentCollection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.paymentCollection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.paymentCollection.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-10.0]
    ]];
    
    [self.locView attachToScrollView:self.paymentCollection];
}
#pragma mark - Setup Payment Collection

- (void)fetchUserPaymentInstruments {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length == 0) {
        self.userInstruments = @[];
        [self.paymentCollection reloadData];
        [self pp_refreshCheckoutCallToAction];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.instrumentManager listenForInstrumentsForUser:uid
                                             completion:^(NSArray<UserPaymentInstrument *> * _Nullable instruments, NSError * _Nullable error) {
        [PPHUD dismiss];
        if (!error) {
            PPORDERLog(@"Payment instruments loaded | count=%lu", (unsigned long)instruments.count);
            weakSelf.userInstruments = instruments ?: @[];
            [weakSelf pp_applyDefaultSelectionIfNeeded];
            [weakSelf.paymentCollection reloadData];
            [weakSelf pp_refreshCheckoutCallToAction];
            [UIView performWithoutAnimation:^{
                
            }];

        } else {
            PPORDERLog(@"Payment instruments failed to load | error=%@", error.localizedDescription ?: @"Unknown");
            [PPHUD showError:kLang(@"payment_load_methods_failed")];
        }
    }];
}



-(void)showPaymentSheetFull:(BOOL)showFull
{
    (void)showFull;
    PPPaymentFormViewController *paymentFormVC = [PPPaymentFormViewController new];
    paymentFormVC.mode = PPPaymentFormModeAdd;
    paymentFormVC.isEditingExisting = NO;
    self.paymentFormVC = paymentFormVC;
    [self.navigationController pushViewController:paymentFormVC animated:YES];
}

- (void)setupHint
{
    self.collectionHintLabel = [[UILabel alloc] init];
    self.collectionHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionHintLabel.font = [GM MidFontWithSize:14];
    self.collectionHintLabel.textColor = UIColor.secondaryLabelColor;
    self.collectionHintLabel.textAlignment = NSTextAlignmentCenter;
    self.collectionHintLabel.numberOfLines = 2;
}
- (void)updateCollectionHintText {
    if (self.userInstruments.count == 0) {
        self.collectionHintLabel.text = nil;//kLang(@"PaymentHintAddNew");
    } else {
        self.collectionHintLabel.text = nil;//kLang(@"PaymentHintMoreOptions");
    }
}

- (BOOL)pp_isAddressCheckoutValid:(PPAddressModel *)address
{
    if (!address) return NO;
    NSString *effectiveID = [self pp_effectiveAddressID:address];
    if (effectiveID.length == 0) return NO;
    if (address.documentID.length == 0) {
        address.documentID = effectiveID;
    }
    if (address.addressID.length == 0) {
        address.addressID = effectiveID;
    }

    NSString *line1 = [self pp_trimmedAddressString:address.addressLine1];
    NSString *fullName = [self pp_trimmedAddressString:address.fullName];
    NSString *legacyLocation = [self pp_trimmedAddressString:address.locatioName];
    NSString *displayName = [self pp_trimmedAddressString:[address displayName]];
    BOOL hasUsableText = line1.length > 0 || fullName.length > 0 || legacyLocation.length > 0 || displayName.length > 0;
    if (!hasUsableText) return NO;

    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length > 0 &&
        address.userID.length > 0 &&
        ![address.userID isEqualToString:uid]) {
        return NO;
    }
    return YES;
}

- (BOOL)pp_checkoutMethodRequiresPhone:(NSString *)paymentMethodID
{
    NSString *normalized = [[paymentMethodID ?: @"" lowercaseString] copy];
    return ![normalized isEqualToString:@"cash"];
}

- (NSError *)pp_checkoutValidationErrorForAddress:(PPAddressModel *)address paymentMethodId:(NSString *)paymentMethodID
{
    if (paymentMethodID.length == 0) {
        return [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain
                                   code:1000
                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_payment_method_unavailable")}];
    }

    if (![self pp_isAddressCheckoutValid:address]) {
        return [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain
                                   code:1001
                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_address")}];
    }

    if ([self pp_checkoutMethodRequiresPhone:paymentMethodID]) {
        NSString *phone = [self pp_trimmedAddressString:address.phoneNumber];
        if (phone.length == 0) {
            phone = [self pp_trimmedAddressString:PPCurrentUser.MobileNo];
        }
        if (phone.length == 0) {
            return [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain
                                       code:1002
                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"payment_phone_required")}];
        }
    }

    return nil;
}

- (BOOL)pp_hasAuthenticatedUser
{
    return [FIRAuth auth].currentUser.uid.length > 0;
}

- (void)pp_refreshLatestAddressesForCheckout:(void (^)(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error))completion
{
    if (![self pp_hasAuthenticatedUser]) {
        [self pp_applyAddresses:@[]];
        if (completion) {
            completion(@[], nil);
        }
        return;
    }

    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (!error) {
            [self pp_applyAddresses:addresses ?: @[]];
        }
        if (completion) completion(addresses, error);
    }];
}

- (NSString *)pp_trimmedCheckoutMessage:(NSString *)message
{
    if (![message isKindOfClass:NSString.class]) return @"";
    return [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)pp_checkoutMessage:(NSString *)message containsAnyToken:(NSArray<NSString *> *)tokens
{
    NSString *lowercase = [self pp_trimmedCheckoutMessage:message].lowercaseString;
    if (lowercase.length == 0) return NO;
    for (NSString *token in tokens ?: @[]) {
        if (![token isKindOfClass:NSString.class] || token.length == 0) continue;
        if ([lowercase containsString:token.lowercaseString]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_checkoutMessageContainsTechnicalIdentifier:(NSString *)message
{
    NSString *trimmed = [self pp_trimmedCheckoutMessage:message];
    if (trimmed.length == 0) return NO;

    static NSRegularExpression *uuidExpression;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uuidExpression = [NSRegularExpression regularExpressionWithPattern:@"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
                                                                    options:0
                                                                      error:nil];
    });
    NSRange fullRange = NSMakeRange(0, trimmed.length);
    if ([uuidExpression firstMatchInString:trimmed options:0 range:fullRange]) {
        return YES;
    }

    return [self pp_checkoutMessage:trimmed containsAnyToken:@[
        @"firebase",
        @"functions",
        @"exception",
        @"qibsessionid",
        @"paymentattemptid",
        @"backend response",
        @"payload",
        @"domain=",
        @"code="
    ]];
}

- (NSString *)pp_userFacingCheckoutFailureMessageForError:(NSError *)error retryable:(BOOL)retryable
{
    NSString *rawReason = [self pp_trimmedCheckoutMessage:error.localizedDescription];
    if (rawReason.length == 0) {
        return retryable ? kLang(@"payment_retryable_failure_message") : kLang(@"checkout_generic_error");
    }

    if ([error.domain isEqualToString:@"Checkout"] && error.code == 1001) {
        return kLang(@"checkout_cart_empty_message");
    }

    if ([error.domain isEqualToString:@"Checkout"] && error.code == 1005) {
        return kLang(@"checkout_invalid_address");
    }

    if ([error.domain isEqualToString:@"Checkout"] && error.code == 1003 &&
        [self pp_checkoutMessageContainsTechnicalIdentifier:rawReason]) {
        return kLang(@"checkout_items_unavailable_review_cart");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"must be a positive number", @"invalid price"]]) {
        return kLang(@"checkout_item_price_invalid");
    }

    BOOL mentionsItem = [self pp_checkoutMessage:rawReason containsAnyToken:@[@"item ", @"cart item", @"product"]];
    BOOL unavailable = [self pp_checkoutMessage:rawReason containsAnyToken:@[@"unavailable", @"not available", @"no longer available", @"out of stock"]];
    if (mentionsItem && unavailable) {
        return kLang(@"checkout_item_unavailable_review_cart");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"inventory", @"stock"]]) {
        return kLang(@"checkout_items_unavailable_review_cart");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"cart is empty", @"empty cart"]]) {
        return kLang(@"checkout_cart_empty_message");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"address"]]) {
        return kLang(@"checkout_invalid_address");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"phone"]]) {
        return kLang(@"payment_phone_required");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"payment request already", @"already in progress"]]) {
        return kLang(@"payment_request_in_progress");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"payment method"]]) {
        return kLang(@"checkout_payment_method_unavailable");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"offline", @"internet", @"network"]]) {
        return kLang(@"offline_action_message");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"permission denied", @"not allowed"]]) {
        return kLang(@"payment_backend_permission_denied");
    }

    if ([self pp_checkoutMessageContainsTechnicalIdentifier:rawReason]) {
        return retryable ? kLang(@"payment_retryable_failure_message") : kLang(@"checkout_generic_error");
    }

    if (retryable && [self pp_checkoutMessage:rawReason containsAnyToken:@[@"payment failed", @"gateway", @"sdk"]]) {
        return kLang(@"payment_retryable_failure_message");
    }

    return rawReason;
}

- (NSString *)pp_userFacingCheckoutPendingMessageForError:(NSError *)error
{
    NSString *rawReason = [self pp_trimmedCheckoutMessage:error.localizedDescription];
    if (rawReason.length == 0 || [self pp_checkoutMessageContainsTechnicalIdentifier:rawReason]) {
        return kLang(@"checkout_payment_verification_pending");
    }
    return rawReason;
}

- (BOOL)pp_checkoutFailureNeedsCartReviewForError:(NSError *)error userMessage:(NSString *)message
{
    NSString *rawReason = [self pp_trimmedCheckoutMessage:error.localizedDescription];
    NSString *safeMessage = [self pp_trimmedCheckoutMessage:message];
    if ([error.domain isEqualToString:@"Checkout"] && (error.code == 1001 || error.code == 1003)) {
        return YES;
    }
    if ([safeMessage isEqualToString:kLang(@"checkout_item_unavailable_review_cart")] ||
        [safeMessage isEqualToString:kLang(@"checkout_items_unavailable_review_cart")] ||
        [safeMessage isEqualToString:kLang(@"checkout_item_price_invalid")] ||
        [safeMessage isEqualToString:kLang(@"checkout_cart_empty_message")]) {
        return YES;
    }
    return [self pp_checkoutMessage:rawReason containsAnyToken:@[
        @"item ",
        @"cart item",
        @"inventory",
        @"stock",
        @"invalid price",
        @"positive number"
    ]];
}


- (void)finishPayments
{
    PPORDERLog(@"Checkout tapped | items=%lu | inProgress=%d",
               (unsigned long)CartManager.sharedManager.cartItems.count,
               self.isCheckoutInProgress);
    if (![self pp_hasAuthenticatedUser]) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"auth_register_required_title")
                            subtitle:kLang(@"auth_register_required_subtitle")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        PPORDERLog(@"Checkout blocked | reason=unauthenticated");
        return;
    }
    if (self.isCheckoutInProgress) {
        [PPHUD showInfo:kLang(@"payment_request_in_progress")];
        PPORDERLog(@"Checkout blocked | reason=already_in_progress");
        return;
    }

    NSString *selectedPaymentMethodID = [self pp_selectedCheckoutPaymentMethodID];
    if (selectedPaymentMethodID.length == 0) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"checkout_failed_title")
                          subtitle:kLang(@"checkout_payment_method_unavailable")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        PPORDERLog(@"Checkout blocked | reason=no_payment_method");
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_refreshLatestAddressesForCheckout:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable addressError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (addressError) {
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"checkout_failed_title")
                                  subtitle:kLang(@"checkout_address_refresh_failed")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                PPORDERLog(@"Checkout blocked | reason=address_refresh_failed | error=%@",
                           addressError.localizedDescription ?: @"Unknown");
                return;
            }

            PPAddressModel *resolvedAddress = [self pp_preferredAddressFrom:addresses ?: @[]];
            NSString *selectedID = [self pp_effectiveAddressID:self.selectedAddress];
            if (selectedID.length > 0) {
                for (PPAddressModel *candidate in addresses ?: @[]) {
                    NSString *candidateID = [self pp_effectiveAddressID:candidate];
                    if ([candidateID isEqualToString:selectedID]) {
                        resolvedAddress = candidate;
                        break;
                    }
                }
            }

            NSError *validationError = [self pp_checkoutValidationErrorForAddress:resolvedAddress
                                                                  paymentMethodId:selectedPaymentMethodID];
            if (validationError) {
                NSString *title = validationError.code == 1001
                    ? kLang(@"select_delivery_location_title")
                    : kLang(@"checkout_failed_title");
                [PPAlertHelper showWarningIn:self
                                       title:title
                                    subtitle:validationError.localizedDescription ?: kLang(@"checkout_generic_error")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                PPORDERLog(@"Checkout blocked | reason=preflight_failed | paymentMethod=%@ | error=%@",
                           selectedPaymentMethodID,
                           validationError.localizedDescription ?: @"Unknown");
                return;
            }
            self.selectedAddress = resolvedAddress;
            NSString *resolvedText = [self pp_bestAddressDisplayText:resolvedAddress];
            [self.locView setAddressText:resolvedText.length > 0 ? resolvedText : kLang(@"PleaseSelectDeliveryLocation")];

            if (!self.checkoutCoordinator) {
                self.checkoutCoordinator =
                [[PPCheckoutCoordinator alloc] initWithPresentingViewController:self];
            }

            [self pp_startCheckoutWithPaymentMethodId:selectedPaymentMethodID];
        });
    }];
}

#pragma mark - Checkout Execution & Retry (H-07)

/// Starts the QIB checkout flow.  Called both from the initial checkout tap
/// and from the "Retry Payment" action after a retryable failure or timeout.
/// The coordinator's checkoutIdempotencyKey is preserved across failures,
/// so the backend safely deduplicates order creation on retry.
- (void)pp_startCheckoutWithPaymentMethodId:(NSString *)paymentMethodId
{
    self.isCheckoutInProgress = YES;
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self.summaryView setCheckoutLoading:YES];
    PPORDERLog(@"Checkout starting | paymentMethod=%@ | addressId=%@",
               paymentMethodId,
               [self pp_effectiveAddressID:self.selectedAddress]);

    __weak typeof(self) weakSelf = self;
    [self.checkoutCoordinator startCheckoutWithAddress:self.selectedAddress
                                        paymentMethodId:paymentMethodId
                                             completion:^(PPCheckoutResult result,
                                                          PPOrder *order,
                                                          NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf pp_handleCheckoutResult:result
                                          order:order
                                          error:error
                                paymentMethodId:paymentMethodId];
        });
    }];
}

/// Handles every terminal checkout result.  Success, cancellation, and
/// non-retryable failures behave exactly as before.  For retryable QIB
/// payment failures and timeouts a "Retry Payment" button is offered.
- (void)pp_handleCheckoutResult:(PPCheckoutResult)result
                          order:(PPOrder * _Nullable)order
                          error:(NSError * _Nullable)error
                paymentMethodId:(NSString *)paymentMethodId
{
    self.isCheckoutInProgress = NO;
    [self.summaryView setCheckoutLoading:NO];
    PPORDERLog(@"Checkout completed | result=%ld | orderId=%@ | error=%@",
               (long)result,
               order.orderId ?: @"",
               error.localizedDescription ?: @"");

    if (result == PPCheckoutResultSuccess) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        NSString *successMessage = error.localizedDescription.length > 0
            ? error.localizedDescription
            : ((order && [order isCashOnDelivery])
               ? kLang(@"checkout_cod_success_subtitle")
               : kLang(@"order_paid_success_subtitle"));
        [self pp_openOrderDetailsForOrder:order
                           successMessage:successMessage
                        presentationState:PPOrderDetailsEntryPresentationStateCheckoutSuccess];

    } else if (result == PPCheckoutResultPendingVerification) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

        // H-07: Offer retry for timeout / pending-verification states.
        BOOL isRetryable = [error.userInfo[PPCheckoutErrorIsRetryableKey] boolValue];
        NSString *pendingMessage = [self pp_userFacingCheckoutPendingMessageForError:error];

        if (isRetryable) {
            __weak typeof(self) weakRetry = self;
            [PPAlertHelper showConfirmationIn:self
                                        title:kLang(@"payment_pending_title")
                                     subtitle:pendingMessage
                                confirmButton:kLang(@"retry_payment")
                                 cancelButton:kLang(@"view_order_status")
                                         icon:nil
                                 confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
                __strong typeof(weakRetry) retryStrong = weakRetry;
                if (!retryStrong) return;
                PPORDERLog(@"User chose retry after pending verification | paymentMethod=%@", paymentMethodId);
                [retryStrong pp_startCheckoutWithPaymentMethodId:paymentMethodId];
            }
                                  cancelBlock:^{
                __strong typeof(weakRetry) retryStrong = weakRetry;
                if (!retryStrong) return;
                PPORDERLog(@"User chose view order after pending verification | orderId=%@", order.orderId ?: @"");
                [retryStrong pp_openOrderDetailsForOrder:order
                                          successMessage:pendingMessage
                                       presentationState:PPOrderDetailsEntryPresentationStateVerificationPending];
            }];
        } else {
            [self pp_openOrderDetailsForOrder:order
                               successMessage:pendingMessage
                            presentationState:PPOrderDetailsEntryPresentationStateVerificationPending];
        }

    } else if (result == PPCheckoutResultCancelled) {
        PPORDERLog(@"Payment cancelled by user | orderId=%@", order.orderId ?: @"");
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

        // Return user to the payment screen with a clear choice:
        // choose another payment method or cancel the order entirely.
        __weak typeof(self) weakCancel = self;
        [PPAlertHelper showConfirmationIn:self
                                    title:kLang(@"payment_cancelled_title")
                                 subtitle:kLang(@"payment_cancelled_choose_method_message")
                            confirmButton:kLang(@"payment_cancelled_choose_another")
                             cancelButton:kLang(@"payment_cancelled_cancel_order")
                                     icon:nil
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            // User wants to pick a different payment method — stay on this screen.
            PPORDERLog(@"User chose to select another payment method after cancel");
        }
                              cancelBlock:^{
            __strong typeof(weakCancel) strongCancel = weakCancel;
            if (!strongCancel) return;
            PPORDERLog(@"User chose to cancel order after payment cancel");
            [strongCancel.navigationController popViewControllerAnimated:YES];
        }];

    } else {
        // PPCheckoutResultFailed
        // H-07: Offer retry for QIB payment failures (SDK error, verification
        // failure, Firestore-confirmed decline).  Validation errors (out-of-stock,
        // invalid address, etc.) remain non-retryable.
        BOOL isRetryable = [error.userInfo[PPCheckoutErrorIsRetryableKey] boolValue];
        NSString *rawReason = error.localizedDescription ?: @"";
        NSString *reason = [self pp_userFacingCheckoutFailureMessageForError:error retryable:isRetryable];
        BOOL needsCartReview = [self pp_checkoutFailureNeedsCartReviewForError:error userMessage:reason];
        PPORDERLog(@"Checkout failed | rawError=%@ | retryable=%d", rawReason, isRetryable);

        if (isRetryable) {
            __weak typeof(self) weakRetry = self;
            [PPAlertHelper showConfirmationIn:self
                                        title:kLang(@"payment_failed_title")
                                     subtitle:reason
                                confirmButton:kLang(@"retry_payment")
                                 cancelButton:kLang(@"cancel")
                                         icon:nil
                                 confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
                __strong typeof(weakRetry) retryStrong = weakRetry;
                if (!retryStrong) return;
                PPORDERLog(@"User chose retry after payment failure | paymentMethod=%@", paymentMethodId);
                [retryStrong pp_startCheckoutWithPaymentMethodId:paymentMethodId];
            }
                                  cancelBlock:nil];
        } else if (needsCartReview) {
            __weak typeof(self) weakReview = self;
            [PPAlertHelper showConfirmationIn:self
                                        title:kLang(@"checkout_review_cart_title")
                                     subtitle:reason
                                confirmButton:kLang(@"checkout_review_cart_action")
                                 cancelButton:kLang(@"OK")
                                         icon:nil
                                 confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
                if (!didConfirm) return;
                __strong typeof(weakReview) strongReview = weakReview;
                [strongReview.navigationController popViewControllerAnimated:YES];
            }
                                  cancelBlock:nil];
        } else {
            [PPAlertHelper showErrorIn:self title:kLang(@"checkout_failed_title") subtitle:reason];
        }
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
    }
}


-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self.view bringSubviewToFront:self.summaryView];
    self.summaryView.userInteractionEnabled = YES;
 }


- (void)dealloc
{
    [self.addressesListener remove];
    self.addressesListener = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pp_openOrderDetailsForOrder:(PPOrder *)order
                     successMessage:(NSString *)message
                  presentationState:(PPOrderDetailsEntryPresentationState)presentationState
{
    if (!order) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"order_placed_title")
                            subtitle:message.length > 0 ? message : kLang(@"order_paid_success_subtitle")];
        return;
    }

    OrderDetailsViewController *detailsVC = [[OrderDetailsViewController alloc] initWithOrder:order];
    detailsVC.entryPresentationState = presentationState;
    detailsVC.entryPresentationMessage = message ?: @"";
    [self.navigationController pushViewController:detailsVC animated:YES];
}
@end
