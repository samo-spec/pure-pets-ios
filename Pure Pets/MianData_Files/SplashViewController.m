//
//  SplashViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/10/2025.
//

#import "SplashViewController.h"
#import <QuartzCore/QuartzCore.h>

@import FirebaseFirestore;

typedef NS_ENUM(NSInteger, PPSplashLoadingPhase) {
    PPSplashLoadingPhaseBootstrapping = 0,
    PPSplashLoadingPhasePreparingContent,
    PPSplashLoadingPhaseFinalizing,
    PPSplashLoadingPhaseReady
};

@interface SplashViewController ()
@property (nonatomic, assign) BOOL didShowMainVC;
@property (nonatomic, assign) BOOL didStartInitialDataLoad;
@property (nonatomic, assign) BOOL didLoadMainKinds;
@property (nonatomic, assign) BOOL didLoadBanners;
@property (nonatomic, assign) PPSplashLoadingPhase currentLoadingPhase;
@property (nonatomic, copy, nullable) NSString *currentLoadingDetail;
@property (nonatomic, strong, nullable) NSDate *launchBeganAt;
@property (nonatomic, copy, nullable) dispatch_block_t launchTimeoutBlock;
@property (nonatomic, strong) CAGradientLayer *backgroundGradientLayer;
@property (nonatomic, strong) UIImageView *patternView;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIView *logoPlateView;
@property (nonatomic, strong) UIView *logoInnerSurfaceView;
@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *loadingCardView;
@property (nonatomic, strong) UIActivityIndicatorView *spinnerView;
@property (nonatomic, strong) UILabel *loadingTitleLabel;
@property (nonatomic, strong) UILabel *loadingStatusLabel;
@property (nonatomic, strong) UIStackView *progressStackView;
@property (nonatomic, strong) NSArray<UIView *> *progressSegments;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) LOTAnimationView *logoAnimationView;
- (BOOL)pp_isRTL;
- (void)pp_buildSplashInterface;
- (void)pp_applySplashTheme;
- (void)pp_applySplashCopy;
- (void)pp_beginSplashAnimationsIfNeeded;
- (void)pp_refreshLoadingProgressPresentation;
- (void)pp_updateLoadingPhase:(PPSplashLoadingPhase)phase detail:(NSString *)detail;
- (void)pp_scheduleLaunchTimeout;
- (void)pp_cancelLaunchTimeout;
- (void)pp_completeLaunchIfNeededForced:(BOOL)forced;
- (nullable UIWindow *)pp_transitionWindow;
- (void)pp_swapRootViewController:(UIViewController *)rootViewController
                         onWindow:(UIWindow *)window;
@end

@implementation SplashViewController
- (void)setupLogoLottieFromPath {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"purepets_logo_premium" ofType:@"json"];
    self.logoAnimationView = [LOTAnimationView animationWithFilePath:path];
    self.logoAnimationView.frame = CGRectMake(0, 0, 220, 220);
    self.logoAnimationView.center = self.view.center;
    self.logoAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    self.logoAnimationView.loopAnimation = YES;

    [self.view addSubview:self.logoAnimationView];
    [self.logoAnimationView play];
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"[Splash] viewDidLoad ✅");

    [self pp_buildSplashInterface];
    [self pp_applySplashTheme];
    [self pp_applySplashCopy];
    [self pp_updateLoadingPhase:PPSplashLoadingPhaseBootstrapping detail:self.currentLoadingDetail];

    [PPHUD dismiss];
    
    [self setupLogoLottieFromPath];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.backgroundGradientLayer.frame = self.view.bounds;
    self.topGlowView.layer.cornerRadius = CGRectGetHeight(self.topGlowView.bounds) * 0.5;
    self.bottomGlowView.layer.cornerRadius = CGRectGetHeight(self.bottomGlowView.bounds) * 0.5;
    
    self.backgroundGradientLayer.opacity = 0.3;
    //self.bottomGlowView.alpha = 0.5;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applySplashTheme];
        }
    } else {
        [self pp_applySplashTheme];
    }
}

- (BOOL)pp_isRTL
{
    return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:Language.semanticAttributeForCurrentLanguage] ==
        UIUserInterfaceLayoutDirectionRightToLeft;
}

- (void)pp_buildSplashInterface
{
    self.view.backgroundColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    self.view.semanticContentAttribute = GM.setSemantic;
    self.view.clipsToBounds = YES;

    CAGradientLayer *backgroundGradientLayer = [CAGradientLayer layer];
    backgroundGradientLayer.startPoint = CGPointMake(0.08, 0.0);
    backgroundGradientLayer.endPoint = CGPointMake(0.92, 1.0);
    [self.view.layer insertSublayer:backgroundGradientLayer atIndex:0];
    self.backgroundGradientLayer = backgroundGradientLayer;

    UIView *topGlowView = [[UIView alloc] init];
    topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    topGlowView.userInteractionEnabled = NO;
    [self.view addSubview:topGlowView];
    self.topGlowView = topGlowView;

    UIView *bottomGlowView = [[UIView alloc] init];
    bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlowView.userInteractionEnabled = NO;
    [self.view addSubview:bottomGlowView];
    self.bottomGlowView = bottomGlowView;

    UIImage *patternImage = [[UIImage imageNamed:@"chat3"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *patternView = [[UIImageView alloc] initWithImage:patternImage];
    patternView.translatesAutoresizingMaskIntoConstraints = NO;
    patternView.contentMode = UIViewContentModeScaleAspectFill;
    patternView.userInteractionEnabled = NO;
    [self.view addSubview:patternView];
    self.patternView = patternView;

    UIStackView *contentStackView = [[UIStackView alloc] init];
    contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    contentStackView.axis = UILayoutConstraintAxisVertical;
    contentStackView.alignment = UIStackViewAlignmentCenter;
    contentStackView.distribution = UIStackViewDistributionFill;
    contentStackView.spacing = 22.0;
    contentStackView.alpha = 0.0;
    contentStackView.transform = CGAffineTransformMakeTranslation(0.0, 22.0);
    [self.view addSubview:contentStackView];
    self.contentStackView = contentStackView;

    UIView *logoPlateView = [[UIView alloc] init];
    logoPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    logoPlateView.layer.cornerRadius = 42.0;
    logoPlateView.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        logoPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [logoPlateView.widthAnchor constraintEqualToConstant:172.0].active = YES;
    [logoPlateView.heightAnchor constraintEqualToConstant:172.0].active = YES;
    [contentStackView addArrangedSubview:logoPlateView];
    self.logoPlateView = logoPlateView;

    UIView *logoInnerSurfaceView = [[UIView alloc] init];
    logoInnerSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    logoInnerSurfaceView.layer.cornerRadius = 34.0;
    logoInnerSurfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        logoInnerSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [logoPlateView addSubview:logoInnerSurfaceView];
    self.logoInnerSurfaceView = logoInnerSurfaceView;

    UIImage *logoImage = [[UIImage imageNamed:@"PureIconTransFilledV3"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *logoView = [[UIImageView alloc] initWithImage:logoImage];
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    logoView.contentMode = UIViewContentModeScaleAspectFit;
    [logoInnerSurfaceView addSubview:logoView];
    self.logoView = logoView;

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    brandLabel.textAlignment = NSTextAlignmentCenter;
    brandLabel.numberOfLines = 1;
    brandLabel.font = [GM boldFontWithSize:34.0] ?: [UIFont systemFontOfSize:34.0 weight:UIFontWeightBlack];
    [contentStackView addArrangedSubview:brandLabel];
    self.brandLabel = brandLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [subtitleLabel.widthAnchor constraintLessThanOrEqualToConstant:308.0].active = YES;
    [contentStackView addArrangedSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UIView *loadingCardView = [[UIView alloc] init];
    loadingCardView.translatesAutoresizingMaskIntoConstraints = NO;
    loadingCardView.layer.cornerRadius = 26.0;
    loadingCardView.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        loadingCardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    CGFloat cardWidth = MIN(MAX(CGRectGetWidth(UIScreen.mainScreen.bounds) - 56.0, 264.0), 340.0);
    [loadingCardView.widthAnchor constraintEqualToConstant:cardWidth].active = YES;
    [contentStackView addArrangedSubview:loadingCardView];
    self.loadingCardView = loadingCardView;

    UIStackView *cardContentStack = [[UIStackView alloc] init];
    cardContentStack.translatesAutoresizingMaskIntoConstraints = NO;
    cardContentStack.axis = UILayoutConstraintAxisVertical;
    cardContentStack.alignment = UIStackViewAlignmentFill;
    cardContentStack.distribution = UIStackViewDistributionFill;
    cardContentStack.spacing = 14.0;
    [loadingCardView addSubview:cardContentStack];

    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.spacing = 12.0;
    [cardContentStack addArrangedSubview:headerStack];

    UIActivityIndicatorView *spinnerView = nil;
    if (@available(iOS 13.0, *)) {
        spinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        spinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    spinnerView.translatesAutoresizingMaskIntoConstraints = NO;
    spinnerView.hidesWhenStopped = NO;
    [spinnerView.widthAnchor constraintEqualToConstant:22.0].active = YES;
    [spinnerView.heightAnchor constraintEqualToConstant:22.0].active = YES;
    [spinnerView startAnimating];
    [headerStack addArrangedSubview:spinnerView];
    self.spinnerView = spinnerView;

    UIStackView *textStack = [[UIStackView alloc] init];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.distribution = UIStackViewDistributionFill;
    textStack.spacing = 3.0;
    [headerStack addArrangedSubview:textStack];

    UILabel *loadingTitleLabel = [[UILabel alloc] init];
    loadingTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    loadingTitleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    loadingTitleLabel.numberOfLines = 1;
    [textStack addArrangedSubview:loadingTitleLabel];
    self.loadingTitleLabel = loadingTitleLabel;

    UILabel *loadingStatusLabel = [[UILabel alloc] init];
    loadingStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    loadingStatusLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    loadingStatusLabel.numberOfLines = 2;
    [textStack addArrangedSubview:loadingStatusLabel];
    self.loadingStatusLabel = loadingStatusLabel;

    UIStackView *progressStackView = [[UIStackView alloc] init];
    progressStackView.translatesAutoresizingMaskIntoConstraints = NO;
    progressStackView.axis = UILayoutConstraintAxisHorizontal;
    progressStackView.alignment = UIStackViewAlignmentFill;
    progressStackView.distribution = UIStackViewDistributionFillEqually;
    progressStackView.spacing = 8.0;
    [cardContentStack addArrangedSubview:progressStackView];
    self.progressStackView = progressStackView;

    NSMutableArray<UIView *> *progressSegments = [NSMutableArray array];
    for (NSInteger idx = 0; idx < 3; idx++) {
        UIView *segment = [[UIView alloc] init];
        segment.translatesAutoresizingMaskIntoConstraints = NO;
        segment.layer.cornerRadius = 3.0;
        segment.layer.masksToBounds = YES;
        [segment.heightAnchor constraintEqualToConstant:6.0].active = YES;
        [progressStackView addArrangedSubview:segment];
        [progressSegments addObject:segment];
    }
    self.progressSegments = progressSegments.copy;

    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 2;
    footerLabel.font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    footerLabel.alpha = 0.0;
    footerLabel.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    [self.view addSubview:footerLabel];
    self.footerLabel = footerLabel;

    [NSLayoutConstraint activateConstraints:@[
        [topGlowView.widthAnchor constraintEqualToConstant:292.0],
        [topGlowView.heightAnchor constraintEqualToConstant:292.0],
        [topGlowView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:116.0],
        [topGlowView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-118.0],

        [bottomGlowView.widthAnchor constraintEqualToConstant:252.0],
        [bottomGlowView.heightAnchor constraintEqualToConstant:252.0],
        [bottomGlowView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-132.0],
        [bottomGlowView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:138.0],

        [patternView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [patternView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [patternView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [patternView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [contentStackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [contentStackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-42.0],
        [contentStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [contentStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-28.0],
        [contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:36.0],

        [logoInnerSurfaceView.leadingAnchor constraintEqualToAnchor:logoPlateView.leadingAnchor constant:12.0],
        [logoInnerSurfaceView.trailingAnchor constraintEqualToAnchor:logoPlateView.trailingAnchor constant:-12.0],
        [logoInnerSurfaceView.topAnchor constraintEqualToAnchor:logoPlateView.topAnchor constant:12.0],
        [logoInnerSurfaceView.bottomAnchor constraintEqualToAnchor:logoPlateView.bottomAnchor constant:-12.0],

        [logoView.centerXAnchor constraintEqualToAnchor:logoInnerSurfaceView.centerXAnchor],
        [logoView.centerYAnchor constraintEqualToAnchor:logoInnerSurfaceView.centerYAnchor],
        [logoView.widthAnchor constraintEqualToConstant:104.0],
        [logoView.heightAnchor constraintEqualToConstant:104.0],

        [cardContentStack.leadingAnchor constraintEqualToAnchor:loadingCardView.leadingAnchor constant:18.0],
        [cardContentStack.trailingAnchor constraintEqualToAnchor:loadingCardView.trailingAnchor constant:-18.0],
        [cardContentStack.topAnchor constraintEqualToAnchor:loadingCardView.topAnchor constant:18.0],
        [cardContentStack.bottomAnchor constraintEqualToAnchor:loadingCardView.bottomAnchor constant:-18.0],

        [footerLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [footerLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [footerLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-22.0]
    ]];
    
    
    
}

- (void)pp_applySplashTheme
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *primaryColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *primaryGlowColor = AppPrimaryClrShiner ?: [primaryColor colorWithAlphaComponent:0.9];
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *secondaryTextColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    UIColor *whiteTint = UIColor.whiteColor;

    self.view.backgroundColor = surfaceColor;
    self.backgroundGradientLayer.colors = @[
        (__bridge id)[surfaceColor colorWithAlphaComponent:1.0].CGColor,
        (__bridge id)[surfaceColor colorWithAlphaComponent:isDark ? 0.96 : 0.98].CGColor,
        (__bridge id)[primaryColor colorWithAlphaComponent:isDark ? 0.16 : 0.10].CGColor,
        (__bridge id)[surfaceColor colorWithAlphaComponent:1.0].CGColor
    ];
    self.backgroundGradientLayer.locations = @[@0.0, @0.38, @0.78, @1.0];

    self.patternView.tintColor = primaryColor;
    self.patternView.alpha = isDark ? 0.05 : 0.035;

    self.topGlowView.backgroundColor = [primaryColor colorWithAlphaComponent:isDark ? 0.22 : 0.12];
    self.topGlowView.layer.shadowColor = primaryColor.CGColor;
    self.topGlowView.layer.shadowOpacity = isDark ? 0.18f : 0.12f;
    self.topGlowView.layer.shadowRadius = 60.0f;
    self.topGlowView.layer.shadowOffset = CGSizeZero;

    self.bottomGlowView.backgroundColor = [primaryGlowColor colorWithAlphaComponent:isDark ? 0.18 : 0.10];
    self.bottomGlowView.layer.shadowColor = primaryGlowColor.CGColor;
    self.bottomGlowView.layer.shadowOpacity = isDark ? 0.16f : 0.10f;
    self.bottomGlowView.layer.shadowRadius = 54.0f;
    self.bottomGlowView.layer.shadowOffset = CGSizeZero;

    self.logoPlateView.backgroundColor = [whiteTint colorWithAlphaComponent:isDark ? 0.06 : 0.42];
    self.logoPlateView.layer.borderWidth = 1.0f;
    self.logoPlateView.layer.borderColor = [[whiteTint colorWithAlphaComponent:isDark ? 0.08 : 0.22] CGColor];
    self.logoPlateView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.logoPlateView.layer.shadowOpacity = isDark ? 0.34f : 0.10f;
    self.logoPlateView.layer.shadowRadius = isDark ? 26.0f : 24.0f;
    self.logoPlateView.layer.shadowOffset = CGSizeMake(0.0, 12.0);

    self.logoInnerSurfaceView.backgroundColor = [surfaceColor colorWithAlphaComponent:isDark ? 0.94 : 0.96];
    self.logoInnerSurfaceView.layer.borderWidth = 1.0f;
    self.logoInnerSurfaceView.layer.borderColor =
        [[whiteTint colorWithAlphaComponent:isDark ? 0.06 : 0.20] CGColor];

    self.logoView.tintColor = primaryColor;

    self.brandLabel.textColor = titleColor;
    self.subtitleLabel.textColor = [secondaryTextColor colorWithAlphaComponent:isDark ? 0.94 : 0.88];

    self.loadingCardView.backgroundColor = [surfaceColor colorWithAlphaComponent:isDark ? 0.74 : 0.90];
    self.loadingCardView.layer.borderWidth = 1.0f;
    self.loadingCardView.layer.borderColor = [[whiteTint colorWithAlphaComponent:isDark ? 0.08 : 0.18] CGColor];
    self.loadingCardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.loadingCardView.layer.shadowOpacity = isDark ? 0.22f : 0.08f;
    self.loadingCardView.layer.shadowRadius = 18.0f;
    self.loadingCardView.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    self.spinnerView.color = primaryColor;
    self.loadingTitleLabel.textColor = titleColor;
    self.loadingStatusLabel.textColor = [secondaryTextColor colorWithAlphaComponent:isDark ? 0.92 : 0.82];
    self.footerLabel.textColor = [secondaryTextColor colorWithAlphaComponent:isDark ? 0.86 : 0.78];

    [self pp_updateLoadingPhase:self.currentLoadingPhase detail:self.currentLoadingDetail];
}

- (void)pp_applySplashCopy
{
    BOOL isRTL = [self pp_isRTL];
    NSInteger currentYear = [[NSCalendar currentCalendar] component:NSCalendarUnitYear fromDate:[NSDate date]];

    self.brandLabel.text = @"Pure Pets";
    self.subtitleLabel.text = isRTL
        ? @"كل ما يحتاجه حيوانك الأليف، في تجربة حديثة وسريعة ومريحة."
        : @"Everything your pet needs, in one modern, calm, and reliable experience.";
    self.loadingTitleLabel.text = isRTL ? @"نجهز تجربتك الآن" : @"Preparing your experience";
    self.footerLabel.text =
        isRTL
            ? [NSString stringWithFormat:@"Pure Pets © %ld\nجميع الحقوق محفوظة.", (long)currentYear]
            : [NSString stringWithFormat:@"Pure Pets © %ld\nAll rights reserved.", (long)currentYear];

    self.currentLoadingDetail = isRTL
        ? @"نحمّل الأقسام والواجهة الرئيسية"
        : @"Loading categories and your home feed";
}

- (void)pp_beginSplashAnimationsIfNeeded
{
    if (self.contentStackView.alpha > 0.99f) {
        return;
    }

    [UIView animateWithDuration:0.72
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.contentStackView.alpha = 1.0;
        self.contentStackView.transform = CGAffineTransformIdentity;
        self.footerLabel.alpha = 1.0;
        self.footerLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    if (![self.logoPlateView.layer animationForKey:@"pp.splash.logoPulse"]) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.fromValue = @(0.985);
        pulse.toValue = @(1.02);
        pulse.duration = 2.3;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.logoPlateView.layer addAnimation:pulse forKey:@"pp.splash.logoPulse"];
    }

    if (![self.topGlowView.layer animationForKey:@"pp.splash.topGlow"]) {
        CABasicAnimation *topDriftX = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        topDriftX.fromValue = @(-10.0);
        topDriftX.toValue = @(12.0);
        topDriftX.duration = 6.4;
        topDriftX.autoreverses = YES;
        topDriftX.repeatCount = HUGE_VALF;
        topDriftX.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.topGlowView.layer addAnimation:topDriftX forKey:@"pp.splash.topGlow"];
    }

    if (![self.bottomGlowView.layer animationForKey:@"pp.splash.bottomGlow"]) {
        CABasicAnimation *bottomDriftX = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        bottomDriftX.fromValue = @(10.0);
        bottomDriftX.toValue = @(-12.0);
        bottomDriftX.duration = 7.2;
        bottomDriftX.autoreverses = YES;
        bottomDriftX.repeatCount = HUGE_VALF;
        bottomDriftX.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.bottomGlowView.layer addAnimation:bottomDriftX forKey:@"pp.splash.bottomGlow"];
    }
}

- (void)pp_refreshLoadingProgressPresentation
{
    BOOL isRTL = [self pp_isRTL];
    NSInteger completedTasks = (self.didLoadMainKinds ? 1 : 0) + (self.didLoadBanners ? 1 : 0);
    PPSplashLoadingPhase phase = PPSplashLoadingPhaseBootstrapping;
    NSString *detail = nil;

    if (completedTasks <= 0) {
        phase = PPSplashLoadingPhaseBootstrapping;
        detail = isRTL ? @"نحمّل الأقسام والواجهة الرئيسية" : @"Loading categories and your home feed";
    } else if (!self.didLoadMainKinds) {
        phase = PPSplashLoadingPhasePreparingContent;
        detail = isRTL ? @"نرتب الأقسام الرئيسية لك" : @"Finishing your categories and browse paths";
    } else if (!self.didLoadBanners) {
        phase = PPSplashLoadingPhaseFinalizing;
        detail = isRTL ? @"نضيف أبرز العروض والواجهات" : @"Adding highlights, banners, and home moments";
    } else {
        phase = PPSplashLoadingPhaseReady;
        detail = isRTL ? @"كل شيء أصبح جاهزًا تقريبًا" : @"Everything is ready to go";
    }

    [self pp_updateLoadingPhase:phase detail:detail];
}

- (void)pp_updateLoadingPhase:(PPSplashLoadingPhase)phase detail:(NSString *)detail
{
    self.currentLoadingPhase = phase;
    self.currentLoadingDetail = detail ?: self.currentLoadingDetail;

    NSString *safeDetail = self.currentLoadingDetail ?: @"";
    if (self.loadingStatusLabel.text.length == 0 || ![self.loadingStatusLabel.text isEqualToString:safeDetail]) {
        [UIView transitionWithView:self.loadingStatusLabel
                          duration:0.22
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
            self.loadingStatusLabel.text = safeDetail;
        } completion:nil];
    } else {
        self.loadingStatusLabel.text = safeDetail;
    }

    NSInteger activeSegments = MIN(MAX((NSInteger)phase + 1, 1), (NSInteger)self.progressSegments.count);
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *activeColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *secondaryBase = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    UIColor *inactiveColor = [secondaryBase colorWithAlphaComponent:isDark ? 0.18 : 0.14];

    [self.progressSegments enumerateObjectsUsingBlock:^(UIView *segment, NSUInteger idx, BOOL *stop) {
        BOOL isActive = ((NSInteger)idx < activeSegments);
        [UIView animateWithDuration:0.22 animations:^{
            segment.backgroundColor = isActive ? activeColor : inactiveColor;
            segment.alpha = isActive ? 1.0 : (isDark ? 0.72 : 0.88);
            segment.transform = isActive ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.98, 1.0);
        }];
    }];

    NSString *title = self.loadingTitleLabel.text ?: @"";
    self.loadingCardView.accessibilityLabel =
        safeDetail.length > 0 ? [NSString stringWithFormat:@"%@. %@", title, safeDetail] : title;
}

- (void)pp_scheduleLaunchTimeout
{
    [self pp_cancelLaunchTimeout];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.didShowMainVC) {
            return;
        }

        NSLog(@"[Splash] ⏱ Launch timeout reached. Proceeding with available data.");
        [self pp_completeLaunchIfNeededForced:YES];
    });

    self.launchTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);
}

- (void)pp_cancelLaunchTimeout
{
    if (!self.launchTimeoutBlock) {
        return;
    }

    dispatch_block_cancel(self.launchTimeoutBlock);
    self.launchTimeoutBlock = nil;
}
/*
 self.CardID = d[@"CardID"];
 self.UserID = d[@"UserID"];
 self.CageID = d[@"CageID"];
 */

- (void)normalizeArchivesIsDeleted
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚀 Starting ArchiveCol isDeleted normalization");

    [[db collectionWithPath:@"ArchiveCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed to fetch ArchiveCol: %@", error);
            return;
        }

        NSArray<FIRDocumentSnapshot *> *docs = snapshot.documents;
        if (docs.count == 0) {
            NSLog(@"ℹ️ No archive documents found");
            return;
        }

        const NSInteger batchLimit = 450; // safe margin
        NSInteger totalUpdated = 0;

        for (NSInteger i = 0; i < docs.count; i += batchLimit) {

            FIRWriteBatch *batch = [db batch];
            NSRange range = NSMakeRange(i, MIN(batchLimit, docs.count - i));
            NSArray *chunk = [docs subarrayWithRange:range];

            for (FIRDocumentSnapshot *doc in chunk) {

                NSNumber *isDeleted = doc.data[@"isDeleted"];

                // Skip if already correct
                if ([isDeleted isKindOfClass:NSNumber.class] &&
                    isDeleted.integerValue == 0) {
                    continue;
                }

                FIRDocumentReference *ref =
                [[db collectionWithPath:@"ArchiveCol"]
                 documentWithPath:doc.documentID];

                [batch setData:@{ @"isDeleted": @0 }
                    forDocument:ref
                          merge:YES];

                totalUpdated++;
            }

            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ Batch commit failed: %@", error);
                } else {
                    NSLog(@"✅ Batch committed (%lu docs)",
                          (unsigned long)chunk.count);
                }
            }];
        }

        NSLog(@"🎯 ArchiveCol normalization completed. Updated: %ld",
              (long)totalUpdated);
    }];
}


- (void)migrateChildsArrayToSubcollectionOnce
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚀 Starting ChildsArray → ChildsCol migration");

    [[db collectionWithPath:@"CagesCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed fetching cages: %@", error);
            return;
        }

        for (FIRDocumentSnapshot *cageDoc in snapshot.documents) {

            NSDictionary *cageData = cageDoc.data;
            NSArray *childsArray = cageData[@"ChildsArray"];

            if (![childsArray isKindOfClass:[NSArray class]] ||
                childsArray.count == 0) {
                continue;
            }

            FIRWriteBatch *batch = [db batch];
            NSInteger migratedCount = 0;

            for (NSDictionary *childDict in childsArray) {

                if (![childDict isKindOfClass:[NSDictionary class]]) continue;

                NSString *childID =
                childDict[@"ID"] ?: [[NSUUID UUID] UUIDString];

                FIRDocumentReference *childRef =
                [[[[db collectionWithPath:@"CagesCol"]
                   documentWithPath:cageDoc.documentID]
                  collectionWithPath:@"ChildsCol"]
                 documentWithPath:childID];

                NSMutableDictionary *safeData = [NSMutableDictionary dictionary];

                // Required
                safeData[@"ID"] = childID;
                safeData[@"CageID"] = childDict[@"CageID"] ?: cageDoc.documentID;
                safeData[@"CardID"] = childDict[@"CardID"] ?: @"";
                safeData[@"ChildRingID"] = childDict[@"ChildRingID"] ?: @"";
                safeData[@"UserID"] = cageData[@"UserID"] ?: @"";

                // Dates
                safeData[@"addingDate"] =
                childDict[@"addingDate"] ?: [NSDate date];

                safeData[@"lastUpdated"] =
                childDict[@"lastUpdated"] ?: [NSDate date];

                // Status
                safeData[@"isDeleted"] =
                childDict[@"isDeleted"] ?: @0;

                safeData[@"isSold"] =
                childDict[@"isSold"] ?: @0;

                // Archive (normalize)
                NSString *archiveID = childDict[@"archiveID"];
                safeData[@"archiveID"] =
                archiveID.length ? archiveID : @"";

                NSString *masterArchiveID = childDict[@"masterArchiveID"];
                safeData[@"masterArchiveID"] =
                masterArchiveID.length ? masterArchiveID : @"";

                // Movement defaults
                safeData[@"childBox"] =
                childDict[@"childBox"] ?: @(0);

                safeData[@"childBoxID"] =
                childDict[@"childBoxID"] ?: @"";

                safeData[@"cameFrom"] =
                childDict[@"cameFrom"] ?: @(0);

                // UPSERT (merge)
                [batch setData:safeData
                    forDocument:childRef
                          merge:YES];

                migratedCount++;
            }

            // Update childsCount ONLY from migrated data
            FIRDocumentReference *cageRef =
            [[db collectionWithPath:@"CagesCol"]
             documentWithPath:cageDoc.documentID];

            [batch updateData:@{
                @"childsCount": @(migratedCount)
            } forDocument:cageRef];

            // COMMIT PER CAGE
            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ Migration failed for cage %@: %@",
                          cageDoc.documentID, error);
                } else {
                    NSLog(@"✅ Cage %@ migrated (%ld childs)",
                          cageDoc.documentID, (long)migratedCount);
                }
            }];
        }
    }];
}


- (void)migrateArchiveDetails_Safe_NoDelete
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚨 STARTING SAFE ARCHIVE DETAILS MIGRATION (NO DELETE)");

    [[db collectionWithPath:@"ArchiveCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed to fetch ArchiveCol: %@", error);
            return;
        }

        for (FIRDocumentSnapshot *archiveDoc in snapshot.documents)
        {
            NSDictionary *data = archiveDoc.data ?: @{};
            NSArray *oldDetails = data[@"archiveDetails"];

            if (![oldDetails isKindOfClass:[NSArray class]] || oldDetails.count == 0) {
                continue; // nothing to migrate
            }

            NSString *archiveID = archiveDoc.documentID;
            NSLog(@"🔄 Migrating archive (SAFE) %@", archiveID);

            FIRWriteBatch *batch = [db batch];
            NSInteger migratedCount = 0;

            for (NSDictionary *oldDetail in oldDetails)
            {
                if (![oldDetail isKindOfClass:[NSDictionary class]]) continue;

                NSString *detailID =
                oldDetail[@"ID"] ?: [NSUUID UUID].UUIDString;

                FIRDocumentReference *detailRef =
                [[archiveDoc.reference
                  collectionWithPath:@"ArchiveDetailsCol"]
                 documentWithPath:detailID];

                NSMutableDictionary *newDetail = [NSMutableDictionary dictionary];

                // ========= REQUIRED =========
                newDetail[@"ID"] = detailID;
                newDetail[@"masterArchiveID"] = archiveID;

                // ========= SAFE COPY =========
                if (oldDetail[@"CardID"])
                    newDetail[@"CardID"] = oldDetail[@"CardID"];

                if (oldDetail[@"UserID"])
                    newDetail[@"UserID"] = oldDetail[@"UserID"];

                if (oldDetail[@"CageID"])
                    newDetail[@"CageID"] = oldDetail[@"CageID"];

                // ========= FLAGS =========
                newDetail[@"CardInfo"] =
                oldDetail[@"CardInfo"] ?: @0;

                newDetail[@"isDeleted"] =
                oldDetail[@"isDeleted"] ?: @0;

                newDetail[@"isSold"] =
                oldDetail[@"isSold"] ?: @0;

                // ========= DATES =========
                NSDate *cardArchiveDate = nil;

                id oldDate = oldDetail[@"cardArchiveDate"];
                if ([oldDate isKindOfClass:[NSDate class]]) {
                    cardArchiveDate = oldDate;
                } else if ([oldDate isKindOfClass:[FIRTimestamp class]]) {
                    cardArchiveDate = [(FIRTimestamp *)oldDate dateValue];
                } else if ([data[@"archiveDate"] isKindOfClass:[NSDate class]]) {
                    cardArchiveDate = data[@"archiveDate"];
                } else {
                    cardArchiveDate = [NSDate date];
                }

                newDetail[@"cardArchiveDate"] =
                [FIRTimestamp timestampWithDate:cardArchiveDate];

                // lastUpdated — only add if missing
                newDetail[@"lastUpdated"] =
                [FIRTimestamp timestampWithDate:[NSDate date]];

                // ========= MERGE (CRITICAL) =========
                [batch setData:newDetail
                     forDocument:detailRef
                         merge:YES];

                migratedCount++;
            }

            // ========= UPDATE METADATA (NO DELETE) =========
            [batch updateData:@{
                @"detailsCount": @(migratedCount),
                @"lastUpdated": [FIRTimestamp timestampWithDate:[NSDate date]]
            } forDocument:archiveDoc.reference];

            // ========= COMMIT =========
            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ SAFE MIGRATION FAILED for %@: %@",
                          archiveID, error);
                } else {
                    NSLog(@"✅ SAFE MIGRATION DONE for %@ (%ld details)",
                          archiveID, (long)migratedCount);
                }
            }];
        }

        NSLog(@"🚨 SAFE MIGRATION LOOP FINISHED");
    }];
}

- (void)duplicateUserDocToCustomID {
    /*
    NSString *targetUID = @"wFiEt8lUWCQkcJE1K4DBHmUMZaD2";
    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *usersCol = [db collectionWithPath:@"UsersCol"];

    // 1️⃣ Find the existing document where uid == targetUID
    FIRQuery *query = [usersCol queryWhereField:@"uid" isEqualTo:targetUID];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Error fetching documents: %@", error.localizedDescription);
            return;
        }

        if (snapshot.documents.count == 0) {
            NSLog(@"⚠️ No document found for uid %@", targetUID);
            return;
        }

        NSLog(@"✅ Found %lu document(s) to duplicate", (unsigned long)snapshot.documents.count);

        // 2️⃣ Take the first document (assuming UID is unique)
        FIRDocumentSnapshot *sourceDoc = snapshot.documents.firstObject;
        NSDictionary *data = sourceDoc.data;

        // 3️⃣ Add or update a new document with custom ID = targetUID
        FIRDocumentReference *newDocRef = [usersCol documentWithPath:targetUID];
        [newDocRef setData:data completion:^(NSError * _Nullable err) {
            if (err) {
                NSLog(@"❌ Failed to create new document: %@", err.localizedDescription);
            } else {
                NSLog(@"🔥 Successfully created new document with ID %@", targetUID);
            }
        }];
    }]; */
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_cancelLaunchTimeout];
    [PPHUD dismiss];
}

- (void)dealloc
{
    [self pp_cancelLaunchTimeout];
    [PPHUD dismiss];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"[Splash] viewDidAppear - start data loading");

    [self pp_beginSplashAnimationsIfNeeded];
    [self startInitialDataLoad];
}

#pragma mark - 🔹 Data Loading Sequence

- (void)startInitialDataLoad
{
    if (self.didShowMainVC || self.didStartInitialDataLoad) {
        NSLog(@"[Splash] ⚠️ Launch work already started, skipping duplicate request.");
        return;
    }

    self.didStartInitialDataLoad = YES;
    self.didLoadMainKinds = NO;
    self.didLoadBanners = NO;
    self.launchBeganAt = [NSDate date];
    [self pp_scheduleLaunchTimeout];
    [self pp_refreshLoadingProgressPresentation];

    dispatch_group_t group = dispatch_group_create();

    __block BOOL didLeaveKindsGroup = NO;
    dispatch_group_enter(group);
    [PPMainKindsManager loadMainDataCompletionHandler:^(int result) {
        if (didLeaveKindsGroup) return;
        didLeaveKindsGroup = YES;

        NSLog(@"[Splash] ✅ MainKinds loaded (result = %d)", result);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.didLoadMainKinds = YES;
            [self pp_refreshLoadingProgressPresentation];
        });
        dispatch_group_leave(group);
    }];

    __block BOOL didLeaveBannerGroup = NO;
    dispatch_group_enter(group);

    if (PPBannersManager.sharedManager.bannerGroups.count > 0) {
        NSLog(@"[PPBannersManager] ✅ LOADED BEFORE");

        self.didLoadBanners = YES;
        [self pp_refreshLoadingProgressPresentation];
        dispatch_group_leave(group);
    } else {
        [[PPBannersManager sharedManager] fetchBannersOnceWithCompletion:^(NSArray<MainBannerModel *> * _Nullable bannerGroups, NSError * _Nullable error) {
            if (didLeaveBannerGroup) return; // 🚫 prevents double leave
            didLeaveBannerGroup = YES;

            if (error) {
                NSLog(@"[Splash] ⚠️ Error fetching banners: %@", error.localizedDescription);
            } else {
                NSLog(@"[Splash] ✅ Banners fetched: %lu items", (unsigned long)bannerGroups.count);
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error) {
                    self.didLoadBanners = YES;
                }
                [self pp_refreshLoadingProgressPresentation];
            });
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"[Splash] 🎬 All data loaded (MainKinds=%@, Banners=%@)",
              self.didLoadMainKinds ? @"✅" : @"❌",
              self.didLoadBanners ? @"✅" : @"❌");

        [self pp_completeLaunchIfNeededForced:NO];
    });
}

- (void)pp_completeLaunchIfNeededForced:(BOOL)forced
{
    if (self.didShowMainVC) {
        return;
    }

    self.didShowMainVC = YES;
    [self pp_cancelLaunchTimeout];

    NSString *completionDetail =
        forced
            ? ([self pp_isRTL] ? @"سندخل بما أصبح جاهزًا الآن" : @"Continuing with what is ready now")
            : ([self pp_isRTL] ? @"كل شيء جاهز للانطلاق" : @"Everything is ready to launch");
    [self pp_updateLoadingPhase:PPSplashLoadingPhaseReady detail:completionDetail];

    NSTimeInterval elapsed = self.launchBeganAt ? [[NSDate date] timeIntervalSinceDate:self.launchBeganAt] : 0.0;
    NSTimeInterval remainingDelay = MAX(0.0, 1.0 - elapsed);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remainingDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self transitionToMainApp];
    });
}

#pragma mark - 🔹 Transition to Main App

- (void)transitionToMainApp
{
    NSLog(@"[Splash] 🚀 Transitioning to main AppVC");
    [[NSUserDefaults standardUserDefaults] setInteger:LastBootOneUI forKey:@"lastBoot"];

    PPRootTabBarController *rootVC = [[PPRootTabBarController alloc] init];
    rootVC.view.semanticContentAttribute = GM.setSemantic;

    UIWindow *window = [self pp_transitionWindow];
    if (!window) {
        NSLog(@"[Splash] ❌ Failed to locate the active window for root transition");
        self.didShowMainVC = NO;
        return;
    }

    [self pp_swapRootViewController:rootVC onWindow:window];
}

- (nullable UIWindow *)pp_transitionWindow
{
    UIWindow *window = self.view.window;
    if (window) {
        return window;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive &&
                windowScene.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }

            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.isKeyWindow) {
                    return candidate;
                }
            }

            if (windowScene.windows.firstObject) {
                return windowScene.windows.firstObject;
            }
        }
    }

    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow) {
            return candidate;
        }
    }

    UIWindow *fallback = UIApplication.sharedApplication.windows.firstObject;
    if (!fallback) {
        NSLog(@"❌ SplashVC: no UIWindow available");
    }
    return fallback;
}

- (void)pp_swapRootViewController:(UIViewController *)rootViewController
                         onWindow:(UIWindow *)window
{
    window.semanticContentAttribute = GM.setSemantic;

    [UIView transitionWithView:window
                      duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
        BOOL previousAnimationState = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        window.rootViewController = rootViewController;
        [window makeKeyAndVisible];
        [window layoutIfNeeded];
        [UIView setAnimationsEnabled:previousAnimationState];
    } completion:nil];
}

@end
