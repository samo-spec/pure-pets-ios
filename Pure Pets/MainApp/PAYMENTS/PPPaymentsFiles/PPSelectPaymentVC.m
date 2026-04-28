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

#import "PPSelectAddressVC.h"
#import <QuartzCore/QuartzCore.h>

@import FirebaseAuth;

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

static NSString * const PPOrderCheckoutPreflightErrorDomain = @"PPOrderCheckoutPreflight";



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
@property (nonatomic, strong) UIView *heroTintView;
@property (nonatomic, strong) UIView *heroAmbientGlow;
@property (nonatomic, strong) UIView *heroSecondaryGlow;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, strong) UIView *bottomSecondaryGlowView;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@end

@implementation PPSelectPaymentVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.availableMethods = [PaymentMethod defaultMethods];
    self.userInstruments = @[];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.title = kLang(@"SelectPaymentMethod");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    [self pp_configureNavigationChrome];
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
        UIColor *heroBorderDynamic = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.68 * 0.18 : 0.68;
            return [[UIColor whiteColor] colorWithAlphaComponent:a];
        }];
        [self.heroCardView pp_setBorderColor:[heroBorderDynamic resolvedColorWithTraitCollection:self.traitCollection]];
        self.heroCardView.layer.shadowOpacity =
            (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.03 : 0.08;
    }
    if (!CGRectIsEmpty(self.heroCardView.bounds)) {
        self.heroCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroCardView.bounds
                                                                        cornerRadius:self.heroCardView.layer.cornerRadius].CGPath;
    }
    if (!CGRectIsEmpty(self.bottomGlowView.bounds)) {
        self.bottomGlowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bottomGlowView.bounds].CGPath;
    }
    if (!CGRectIsEmpty(self.bottomSecondaryGlowView.bounds)) {
        self.bottomSecondaryGlowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bottomSecondaryGlowView.bounds].CGPath;
    }
}

- (void)pp_buildSummaryBottomGlowIfNeeded
{
    if (self.bottomGlowView || self.bottomSecondaryGlowView) return;

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

    [self.view addSubview:secondaryGlow];
    [self.view addSubview:glow];

    [NSLayoutConstraint activateConstraints:@[
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
    [self pp_startSummaryBottomGlowMotionIfNeeded];
}

- (void)pp_startSummaryBottomGlowMotionIfNeeded
{
    if (!self.bottomGlowView && !self.bottomSecondaryGlowView) return;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.bottomGlowView.layer removeAnimationForKey:@"pp_payment_bottom_glow_breath"];
        [self.bottomSecondaryGlowView.layer removeAnimationForKey:@"pp_payment_bottom_secondary_glow_breath"];
        self.bottomGlowView.transform = CGAffineTransformIdentity;
        self.bottomSecondaryGlowView.transform = CGAffineTransformIdentity;
        self.bottomGlowView.alpha = 0.52;
        self.bottomSecondaryGlowView.alpha = 0.36;
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
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

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

- (void)pp_configureNavigationChrome
{
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
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
    self.locView = [PPAddressPickerView showInViewController:self width:self.view.hx_w - 32];
    [self.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
    __weak typeof(self) weakSelf = self;
    self.locView.onPickAddress = ^{
        [weakSelf pp_presentAddressPickerOrPrompt];
    };
    [self.locView expandAndLock];

    // Re-anchor the address picker below the hero card instead of safe-area top
    self.locView.topConstraint.active = NO;
    self.locView.topConstraint = [self.locView.topAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:10.0];
    self.locView.topConstraint.active = YES;

    [self pp_setupInitialAddressState];
}

- (void)pp_setupHeroSection
{
    self.heroCardView = [[UIView alloc] init];
    self.heroCardView.translatesAutoresizingMaskIntoConstraints = NO;
    UIColor *heroSurfaceColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.19 green:0.19 blue:0.21 alpha:0.88];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.88];
    }];
    self.heroCardView.backgroundColor = heroSurfaceColor;
    self.heroCardView.layer.cornerRadius = 34.0;
    self.heroCardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroCardView.layer.borderWidth = 1.0;
    UIColor *heroBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.68 * 0.18 : 0.68;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [self.heroCardView pp_setBorderColor:[heroBorderColor resolvedColorWithTraitCollection:self.traitCollection]];
    [self.heroCardView pp_setShadowColor:[UIColor blackColor]];
    self.heroCardView.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.03 : 0.08;
    self.heroCardView.layer.shadowRadius = 24.0;
    self.heroCardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    self.heroCardView.layer.masksToBounds = NO;
    [self.view addSubview:self.heroCardView];

    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    self.heroTintView = [[UIView alloc] init];
    self.heroTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTintView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.25 green:0.22 blue:0.20 alpha:0.38];
        }
        return [[UIColor colorWithRed:0.99 green:0.97 blue:0.95 alpha:1.0] colorWithAlphaComponent:0.58];
    }];
    self.heroTintView.layer.cornerRadius = 34.0;
    self.heroTintView.layer.masksToBounds = YES;
    self.heroTintView.userInteractionEnabled = NO;
    [self.heroCardView addSubview:self.heroTintView];

    self.heroAmbientGlow = [[UIView alloc] init];
    self.heroAmbientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAmbientGlow.backgroundColor = [brandColor colorWithAlphaComponent:0.10];
    self.heroAmbientGlow.userInteractionEnabled = NO;
    self.heroAmbientGlow.layer.cornerRadius = 94.0;
    [self.heroAmbientGlow pp_setShadowColor:[brandColor colorWithAlphaComponent:0.50]];
    self.heroAmbientGlow.layer.shadowOpacity = 0.16;
    self.heroAmbientGlow.layer.shadowRadius = 42.0;
    self.heroAmbientGlow.layer.shadowOffset = CGSizeZero;
    [self.heroCardView addSubview:self.heroAmbientGlow];

    self.heroSecondaryGlow = [[UIView alloc] init];
    self.heroSecondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSecondaryGlow.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.34 * 0.18 : 0.28;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    self.heroSecondaryGlow.userInteractionEnabled = NO;
    self.heroSecondaryGlow.layer.cornerRadius = 58.0;
    UIColor *secGlowShadow = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.45 * 0.18 : 0.45;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [self.heroSecondaryGlow pp_setShadowColor:[secGlowShadow resolvedColorWithTraitCollection:self.traitCollection]];
    self.heroSecondaryGlow.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.04 : 0.20;
    self.heroSecondaryGlow.layer.shadowRadius = 22.0;
    self.heroSecondaryGlow.layer.shadowOffset = CGSizeZero;
    [self.heroCardView addSubview:self.heroSecondaryGlow];

    UIView *eyebrowContainer = [[UIView alloc] init];
    eyebrowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowContainer.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.74 * 0.18 : 0.74;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    eyebrowContainer.layer.cornerRadius = 14.0;
    eyebrowContainer.layer.cornerCurve = kCACornerCurveContinuous;
    eyebrowContainer.layer.borderWidth = 1.0;
    [eyebrowContainer pp_setBorderColor:[brandColor colorWithAlphaComponent:0.10]];
    eyebrowContainer.layer.masksToBounds = YES;

    self.heroEyebrowLabel = [[UILabel alloc] init];
    self.heroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroEyebrowLabel.font = [GM MidFontWithSize:12.0];
    self.heroEyebrowLabel.textColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.heroEyebrowLabel.textAlignment = NSTextAlignmentCenter;
    self.heroEyebrowLabel.numberOfLines = 1;
    self.heroEyebrowLabel.adjustsFontSizeToFitWidth = YES;
    self.heroEyebrowLabel.minimumScaleFactor = 0.82;
    self.heroEyebrowLabel.text = kLang(@"payment_screen_eyebrow");
    [eyebrowContainer addSubview:self.heroEyebrowLabel];

    UIButton *heroBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
    heroBackButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *backImage = [UIImage pp_symbolNamed:PPChevronName
                                       pointSize:18.0
                                          weight:UIImageSymbolWeightSemibold
                                           scale:UIImageSymbolScaleMedium
                                         palette:@[UIColor.labelColor, UIColor.labelColor]
                                    makeTemplate:YES];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.image = backImage;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
        config.baseForegroundColor = UIColor.labelColor;
        config.background.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.76];
        config.background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.52];
        config.background.strokeWidth = 1.0;
        heroBackButton.configuration = config;
    } else {
        [heroBackButton setImage:backImage forState:UIControlStateNormal];
        heroBackButton.tintColor = UIColor.labelColor;
        heroBackButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.76];
        heroBackButton.layer.cornerRadius = 20.0;
        heroBackButton.layer.borderWidth = 1.0;
        [heroBackButton pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.52]];
    }
    heroBackButton.accessibilityLabel = NSLocalizedString(@"Back", @"Navigate back");
    [heroBackButton addTarget:self action:@selector(onBack:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *heroNavTitleLabel = [[UILabel alloc] init];
    heroNavTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    heroNavTitleLabel.font = [GM boldFontWithSize:17.0];
    heroNavTitleLabel.textColor = UIColor.labelColor;
    heroNavTitleLabel.textAlignment = NSTextAlignmentCenter;
    heroNavTitleLabel.numberOfLines = 2;
    heroNavTitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    heroNavTitleLabel.adjustsFontSizeToFitWidth = YES;
    heroNavTitleLabel.minimumScaleFactor = 0.72;
    heroNavTitleLabel.text = kLang(@"SelectPaymentMethod");
    heroNavTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [heroNavTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [heroNavTitleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                         forAxis:UILayoutConstraintAxisHorizontal];
    [eyebrowContainer setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];
    [heroBackButton setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *heroTopRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        heroBackButton,
        heroNavTitleLabel,
        eyebrowContainer
    ]];
    heroTopRow.translatesAutoresizingMaskIntoConstraints = NO;
    heroTopRow.axis = UILayoutConstraintAxisHorizontal;
    heroTopRow.alignment = UIStackViewAlignmentCenter;
    heroTopRow.spacing = 10.0;
    heroTopRow.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.heroCardView addSubview:heroTopRow];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = [GM boldFontWithSize:24.0];
    self.heroTitleLabel.textColor = UIColor.labelColor;
    self.heroTitleLabel.numberOfLines = 2;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.text = kLang(@"payment_screen_title");
    [self.heroCardView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = [GM MidFontWithSize:13.0];
    self.heroSubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.numberOfLines = 0;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.text = kLang(@"payment_screen_subtitle");
    [self.heroCardView addSubview:self.heroSubtitleLabel];

    UILabel *deliveryLabel = [[UILabel alloc] init];
    deliveryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    deliveryLabel.font = [GM boldFontWithSize:16.0];
    deliveryLabel.textColor = UIColor.labelColor;
    deliveryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    deliveryLabel.text = kLang(@"payment_section_delivery");
    [self.heroCardView addSubview:deliveryLabel];

    UILabel *deliverySubtitleLabel = [[UILabel alloc] init];
    deliverySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    deliverySubtitleLabel.font = [GM MidFontWithSize:13.0];
    deliverySubtitleLabel.textColor = UIColor.secondaryLabelColor;
    deliverySubtitleLabel.numberOfLines = 2;
    deliverySubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    deliverySubtitleLabel.text = kLang(@"payment_section_delivery_subtitle");
    [self.heroCardView addSubview:deliverySubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroCardView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:4.0],
        [self.heroCardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.heroCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],

        [self.heroTintView.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor],
        [self.heroTintView.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor],
        [self.heroTintView.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor],
        [self.heroTintView.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor],

        [self.heroAmbientGlow.widthAnchor constraintEqualToConstant:174.0],
        [self.heroAmbientGlow.heightAnchor constraintEqualToConstant:174.0],
        [self.heroAmbientGlow.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:-74.0],
        [self.heroAmbientGlow.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:74.0],

        [self.heroSecondaryGlow.widthAnchor constraintEqualToConstant:104.0],
        [self.heroSecondaryGlow.heightAnchor constraintEqualToConstant:104.0],
        [self.heroSecondaryGlow.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:34.0],
        [self.heroSecondaryGlow.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:-26.0],

        [heroTopRow.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:14.0],
        [heroTopRow.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:20.0],
        [heroTopRow.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-20.0],

        [heroBackButton.widthAnchor constraintEqualToConstant:40.0],
        [heroBackButton.heightAnchor constraintEqualToConstant:40.0],
        [eyebrowContainer.heightAnchor constraintGreaterThanOrEqualToConstant:32.0],
        [eyebrowContainer.widthAnchor constraintLessThanOrEqualToConstant:136.0],

        [self.heroEyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowContainer.topAnchor constant:7.0],
        [self.heroEyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowContainer.bottomAnchor constant:-7.0],
        [self.heroEyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowContainer.leadingAnchor constant:12.0],
        [self.heroEyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowContainer.trailingAnchor constant:-12.0],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:heroTopRow.bottomAnchor constant:14.0],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:20.0],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-20.0],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:8.0],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],

        [deliveryLabel.topAnchor constraintEqualToAnchor:self.heroSubtitleLabel.bottomAnchor constant:14.0],
        [deliveryLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [deliveryLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],

        [deliverySubtitleLabel.topAnchor constraintEqualToAnchor:deliveryLabel.bottomAnchor constant:5.0],
        [deliverySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [deliverySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],
        [deliverySubtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:-16.0],
    ]];
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


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self pp_configureNavigationChrome];
    [[CartManager sharedManager] refreshPricingConfiguration];
    [self.summaryView setCheckoutLoading:self.isCheckoutInProgress];
    [self pp_startSummaryBottomGlowMotionIfNeeded];
    [_summaryView pp_startTrustBannerShimmer];
    [self pp_setupInitialAddressState];
    [self pp_refreshCheckoutCallToAction];

}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self pp_stopSummaryBottomGlowMotion];
  // [_summaryView pp_stopTrustBannerShimmer];
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
