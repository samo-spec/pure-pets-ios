#import "PPIntroViewController.h"
#import "AppClasses.h"

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

static NSString * const PPIntroDidShowDefaultsKey = @"PPIntroV3DidShow";
static CGFloat const PPIntroScreenMargin = 24.0;
static CGFloat const PPIntroVisualHeight = 292.0;
static NSInteger const PPIntroVisualSurfaceTag = 100;
static NSInteger const PPIntroHeroBackdropTag = 101;
static NSInteger const PPIntroHeadlineTag = 103;
static NSInteger const PPIntroBodyTag = 104;

@interface PPIntroPanel ()
@property (nonatomic, copy) NSString *eyebrow;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, copy) NSString *lottieName;
@end

@implementation PPIntroPanel
- (instancetype)initWithImage:(NSString *)imageName
                    lottieName:(NSString *)lottieName
                      headline:(NSString *)headline
                          body:(NSString *)body {
    self = [super init];
    if (self) {
        _imageName = [imageName copy];
        _lottieName = [lottieName copy];
        _headline = [headline copy];
        _body = [body copy];
    }
    return self;
}
@end

@interface PPIntroViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) CAGradientLayer *backgroundGradient;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *middleGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UILabel *brandKickerLabel;
@property (nonatomic, strong, nullable) LOTAnimationView *ambientLottieView;
@property (nonatomic, strong) UIButton *skipButton;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *panelStack;
@property (nonatomic, strong) UIStackView *indicatorStack;
@property (nonatomic, strong) NSArray<UIView *> *indicatorViews;
@property (nonatomic, strong) UIButton *ctaButton;
@property (nonatomic, strong) UIStackView *ctaContentStack;
@property (nonatomic, strong) UILabel *ctaTitleLabel;
@property (nonatomic, strong) UIImageView *ctaIconView;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) NSArray<PPIntroPanel *> *panels;
@property (nonatomic, copy, nullable) dispatch_block_t dismissalCompletion;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL didLayoutOnce;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL ambientMotionRunning;
@end

@implementation PPIntroViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _panels = [self pp_defaultPanels];
        _currentIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_buildBackdrop];
    [self pp_buildHeader];
    [self pp_buildScrollView];
    [self pp_buildFooter];
    [self pp_applyTraitColors];
}



- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.backgroundGradient.frame = self.view.bounds;
    self.topGlowView.layer.cornerRadius = CGRectGetHeight(self.topGlowView.bounds) * 0.5;
    self.middleGlowView.layer.cornerRadius = CGRectGetHeight(self.middleGlowView.bounds) * 0.5;
    self.bottomGlowView.layer.cornerRadius = CGRectGetHeight(self.bottomGlowView.bounds) * 0.5;
    if (!self.didLayoutOnce) {
        self.didLayoutOnce = YES;
        [self pp_scrollToPanel:0 animated:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_startAmbientMotionIfNeeded];
    [self pp_animateEntranceIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self pp_stopAmbientMotion];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyTraitColors];
}

#pragma mark - Persistence

+ (BOOL)shouldShowIntro {
    return ![[NSUserDefaults standardUserDefaults] boolForKey:PPIntroDidShowDefaultsKey];
}

+ (void)markIntroAsShown {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PPIntroDidShowDefaultsKey];
}

- (void)showOverWindow:(UIWindow *)window completion:(dispatch_block_t)completion {
    self.dismissalCompletion = completion;
    self.view.frame = window.bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.alpha = 0.0;
    [window addSubview:self.view];
    [window bringSubviewToFront:self.view];
    [self pp_startAmbientMotionIfNeeded];
    [self pp_animateEntranceIfNeeded];
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.32;
    [UIView animateWithDuration:duration animations:^{
        self.view.alpha = 1.0;
    }];
}

#pragma mark - Backdrop

- (void)pp_buildBackdrop {
    self.backgroundGradient = [CAGradientLayer layer];
    self.backgroundGradient.startPoint = CGPointMake(0.12, 0.0);
    self.backgroundGradient.endPoint = CGPointMake(0.88, 1.0);
    [self.view.layer insertSublayer:self.backgroundGradient atIndex:0];

    self.topGlowView = [[UIView alloc] init];
    self.topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.topGlowView];

    self.middleGlowView = [[UIView alloc] init];
    self.middleGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.middleGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.middleGlowView];

    self.bottomGlowView = [[UIView alloc] init];
    self.bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.bottomGlowView];

    [NSLayoutConstraint activateConstraints:@[
        [self.topGlowView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:1.36],
        [self.topGlowView.heightAnchor constraintEqualToConstant:220.0],
        [self.topGlowView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-72.0],
        [self.topGlowView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-100.0],
        [self.middleGlowView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:1.18],
        [self.middleGlowView.heightAnchor constraintEqualToConstant:300.0],
        [self.middleGlowView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:24.0],
        [self.middleGlowView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:82.0],
        [self.bottomGlowView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:1.62],
        [self.bottomGlowView.heightAnchor constraintEqualToConstant:260.0],
        [self.bottomGlowView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:74.0],
        [self.bottomGlowView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:144.0],
    ]];
}

- (void)pp_applyTraitColors {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    self.backgroundGradient.colors = dark
        ? @[(id)[UIColor colorWithRed:0.055 green:0.047 blue:0.067 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.020 green:0.018 blue:0.027 alpha:1.0].CGColor]
        : @[(id)[UIColor colorWithRed:1.0 green:0.992 blue:0.986 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.975 green:0.957 blue:0.953 alpha:1.0].CGColor];
    self.topGlowView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.11 : 0.075];
    self.middleGlowView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.075 : 0.045];
    self.bottomGlowView.backgroundColor = [(AppPrimaryClrShiner ?: accent) colorWithAlphaComponent:dark ? 0.09 : 0.06];
    self.brandLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.brandKickerLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.footerLabel.textColor = AppTertiaryTextClr ?: UIColor.tertiaryLabelColor;
    [self.skipButton setTitleColor:[(AppSecondaryTextClr ?: UIColor.secondaryLabelColor) colorWithAlphaComponent:0.92]
                         forState:UIControlStateNormal];
    [self pp_updateIndicatorsAnimated:NO];
}

#pragma mark - Header

- (void)pp_buildHeader {
    UIView *brandContainer = [[UIView alloc] init];
    brandContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:brandContainer];

    self.logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"PPLogo"]];
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoView.contentMode = UIViewContentModeScaleAspectFit;
    [brandContainer addSubview:self.logoView];

    if ([[NSBundle mainBundle] pathForResource:@"NovaLoader" ofType:@"json"].length > 0) {
        self.ambientLottieView = [LOTAnimationView animationNamed:@"NovaLoader"];
        self.ambientLottieView.translatesAutoresizingMaskIntoConstraints = NO;
        self.ambientLottieView.contentMode = UIViewContentModeScaleAspectFit;
        self.ambientLottieView.loopAnimation = YES;
        self.ambientLottieView.animationSpeed = 0.42;
        self.ambientLottieView.alpha = 0.10;
        [brandContainer insertSubview:self.ambientLottieView belowSubview:self.logoView];
    }

    self.brandLabel = [[UILabel alloc] init];
    self.brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.brandLabel.text = kLang(@"AppName");
    self.brandLabel.font = [GM boldFontWithSize:17.0];
    [brandContainer addSubview:self.brandLabel];

    self.brandKickerLabel = [[UILabel alloc] init];
    self.brandKickerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.brandKickerLabel.text = kLang(@"intro_brand_kicker");
    self.brandKickerLabel.font = [GM MidFontWithSize:12.0];
    [brandContainer addSubview:self.brandKickerLabel];

    self.skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.skipButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.skipButton setTitle:kLang(@"intro_skip") forState:UIControlStateNormal];
    self.skipButton.titleLabel.font = [GM MidFontWithSize:15.0];
    self.skipButton.accessibilityLabel = kLang(@"intro_skip_accessibility");
    [self.skipButton addTarget:self action:@selector(pp_skipTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.skipButton addTarget:self action:@selector(pp_skipTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchUpOutside];
    [self.skipButton addTarget:self action:@selector(pp_handleDismiss) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.skipButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSMutableArray<NSLayoutConstraint *> *constraints = [@[
        [brandContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPIntroScreenMargin],
        [brandContainer.topAnchor constraintEqualToAnchor:safe.topAnchor constant:PPSpaceBase],
        [brandContainer.heightAnchor constraintEqualToConstant:48.0],
        [self.logoView.leadingAnchor constraintEqualToAnchor:brandContainer.leadingAnchor],
        [self.logoView.centerYAnchor constraintEqualToAnchor:brandContainer.centerYAnchor],
        [self.logoView.widthAnchor constraintEqualToConstant:42.0],
        [self.logoView.heightAnchor constraintEqualToConstant:42.0],
        [self.brandLabel.leadingAnchor constraintEqualToAnchor:self.logoView.trailingAnchor constant:PPSpaceSM],
        [self.brandLabel.topAnchor constraintEqualToAnchor:brandContainer.topAnchor constant:3.0],
        [self.brandKickerLabel.leadingAnchor constraintEqualToAnchor:self.brandLabel.leadingAnchor],
        [self.brandKickerLabel.topAnchor constraintEqualToAnchor:self.brandLabel.bottomAnchor constant:-2.0],
        [self.skipButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPIntroScreenMargin],
        [self.skipButton.centerYAnchor constraintEqualToAnchor:brandContainer.centerYAnchor],
        [self.skipButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        [self.skipButton.widthAnchor constraintGreaterThanOrEqualToConstant:60.0],
    ] mutableCopy];
    if (self.ambientLottieView) {
        [constraints addObjectsFromArray:@[
            [self.ambientLottieView.centerXAnchor constraintEqualToAnchor:self.logoView.centerXAnchor],
            [self.ambientLottieView.centerYAnchor constraintEqualToAnchor:self.logoView.centerYAnchor],
            [self.ambientLottieView.widthAnchor constraintEqualToConstant:76.0],
            [self.ambientLottieView.heightAnchor constraintEqualToConstant:76.0],
        ]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
}

#pragma mark - Panels

- (void)pp_buildScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.bounces = YES;
    self.scrollView.delegate = self;
    self.scrollView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.view addSubview:self.scrollView];

    self.panelStack = [[UIStackView alloc] init];
    self.panelStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelStack.axis = UILayoutConstraintAxisHorizontal;
    self.panelStack.alignment = UIStackViewAlignmentFill;
    self.panelStack.distribution = UIStackViewDistributionFillEqually;
    [self.scrollView addSubview:self.panelStack];

    for (PPIntroPanel *panel in self.panels) {
        UIView *page = [self pp_buildPanelPage:panel];
        [self.panelStack addArrangedSubview:page];
        [page.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor].active = YES;
        [page.heightAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.heightAnchor].active = YES;
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:82.0],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-170.0],
        [self.panelStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.panelStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.panelStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.panelStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.panelStack.heightAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.heightAnchor],
    ]];
}

- (UIView *)pp_buildPanelPage:(PPIntroPanel *)panel {
    UIView *page = [[UIView alloc] init];
    page.translatesAutoresizingMaskIntoConstraints = NO;
    page.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *visualSurface = [[UIView alloc] init];
    visualSurface.translatesAutoresizingMaskIntoConstraints = NO;
    visualSurface.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    visualSurface.clipsToBounds = YES;
    PPApplyContinuousCorners(visualSurface, PPCornerHero);
    visualSurface.tag = PPIntroVisualSurfaceTag;
    [page addSubview:visualSurface];

    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIView *visualTint = [[UIView alloc] init];
    visualTint.translatesAutoresizingMaskIntoConstraints = NO;
    visualTint.backgroundColor = [accent colorWithAlphaComponent:0.12];
    visualTint.userInteractionEnabled = NO;
    [visualSurface addSubview:visualTint];

    UIView *stageGlow = [[UIView alloc] init];
    stageGlow.translatesAutoresizingMaskIntoConstraints = NO;
    stageGlow.backgroundColor = [accent colorWithAlphaComponent:0.16];
    stageGlow.userInteractionEnabled = NO;
    PPApplyContinuousCorners(stageGlow, 118.0);
    [visualSurface addSubview:stageGlow];

    UIView *heroBackdrop = [[UIView alloc] init];
    heroBackdrop.translatesAutoresizingMaskIntoConstraints = NO;
    heroBackdrop.backgroundColor = [(AppForgroundColr ?: UIColor.whiteColor) colorWithAlphaComponent:0.74];
    heroBackdrop.layer.borderWidth = 1.0;
    heroBackdrop.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.76].CGColor;
    PPApplyContinuousCorners(heroBackdrop, 78.0);
    PPApplyElevatedShadow(heroBackdrop);
    heroBackdrop.tag = PPIntroHeroBackdropTag;
    [visualSurface addSubview:heroBackdrop];

    LOTAnimationView *heroLottieView = [[LOTAnimationView alloc] init];
    heroLottieView.translatesAutoresizingMaskIntoConstraints = NO;
    heroLottieView.contentMode = UIViewContentModeScaleAspectFit;
    heroLottieView.loopAnimation = YES;
    heroLottieView.animationSpeed = 0.86;
    heroLottieView.alpha = 0.0;
    heroLottieView.userInteractionEnabled = NO;
    heroLottieView.clipsToBounds = YES;
    [heroBackdrop addSubview:heroLottieView];

    UIImageView *heroSymbolView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:panel.imageName]];
    heroSymbolView.translatesAutoresizingMaskIntoConstraints = NO;
    heroSymbolView.tintColor = accent;
    heroSymbolView.contentMode = UIViewContentModeScaleAspectFit;
    heroSymbolView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:72.0 weight:UIImageSymbolWeightLight];
    [heroBackdrop addSubview:heroSymbolView];

    UIView *smallAccentBadge = [[UIView alloc] init];
    smallAccentBadge.translatesAutoresizingMaskIntoConstraints = NO;
    smallAccentBadge.backgroundColor = accent;
    PPApplyContinuousCorners(smallAccentBadge, 22.0);
    PPApplyCardShadow(smallAccentBadge);
    [visualSurface addSubview:smallAccentBadge];

    UIImageView *smallAccentSymbol = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:panel.symbolName]];
    smallAccentSymbol.translatesAutoresizingMaskIntoConstraints = NO;
    smallAccentSymbol.tintColor = AppForgroundColr ?: UIColor.whiteColor;
    smallAccentSymbol.contentMode = UIViewContentModeScaleAspectFit;
    smallAccentSymbol.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    [smallAccentBadge addSubview:smallAccentSymbol];

    UIView *symbolBadge = [[UIView alloc] init];
    symbolBadge.translatesAutoresizingMaskIntoConstraints = NO;
    symbolBadge.backgroundColor = [(AppForgroundColr ?: UIColor.whiteColor) colorWithAlphaComponent:0.72];
    symbolBadge.layer.borderWidth = 1.0;
    symbolBadge.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.72].CGColor;
    PPApplyContinuousCorners(symbolBadge, 21.0);
    [visualSurface addSubview:symbolBadge];

    UIImageView *symbolView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]];
    symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    symbolView.tintColor = accent;
    symbolView.contentMode = UIViewContentModeScaleAspectFit;
    symbolView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
    [symbolBadge addSubview:symbolView];

    UILabel *visualKicker = [[UILabel alloc] init];
    visualKicker.translatesAutoresizingMaskIntoConstraints = NO;
    visualKicker.text = panel.eyebrow;
    visualKicker.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    visualKicker.font = [GM boldFontWithSize:12.0];
    visualKicker.numberOfLines = 1;
    [visualSurface addSubview:visualKicker];

    UILabel *headline = [[UILabel alloc] init];
    headline.translatesAutoresizingMaskIntoConstraints = NO;
    headline.text = panel.headline;
    headline.font = [GM boldFontWithSize:36.0];
    headline.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    headline.textAlignment = [Language alignmentForCurrentLanguage];
    headline.numberOfLines = 0;
    headline.adjustsFontSizeToFitWidth = YES;
    headline.minimumScaleFactor = 0.86;
    headline.tag = PPIntroHeadlineTag;
    [page addSubview:headline];

    UILabel *body = [[UILabel alloc] init];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    body.text = panel.body;
    body.font = [GM MidFontWithSize:16.0];
    body.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    body.textAlignment = [Language alignmentForCurrentLanguage];
    body.numberOfLines = 0;
    body.tag = PPIntroBodyTag;
    [page addSubview:body];

    [NSLayoutConstraint activateConstraints:@[
        [visualSurface.topAnchor constraintEqualToAnchor:page.topAnchor constant:PPSpaceMD*2],
        [visualSurface.leadingAnchor constraintEqualToAnchor:page.leadingAnchor constant:PPIntroScreenMargin],
        [visualSurface.trailingAnchor constraintEqualToAnchor:page.trailingAnchor constant:-PPIntroScreenMargin],
        [visualSurface.heightAnchor constraintEqualToConstant:PPIntroVisualHeight],
        [visualTint.topAnchor constraintEqualToAnchor:visualSurface.topAnchor],
        [visualTint.leadingAnchor constraintEqualToAnchor:visualSurface.leadingAnchor],
        [visualTint.trailingAnchor constraintEqualToAnchor:visualSurface.trailingAnchor],
        [visualTint.bottomAnchor constraintEqualToAnchor:visualSurface.bottomAnchor],
        [stageGlow.centerXAnchor constraintEqualToAnchor:heroBackdrop.centerXAnchor],
        [stageGlow.centerYAnchor constraintEqualToAnchor:heroBackdrop.centerYAnchor],
        [stageGlow.widthAnchor constraintEqualToConstant:236.0],
        [stageGlow.heightAnchor constraintEqualToConstant:236.0],
        [heroBackdrop.centerXAnchor constraintEqualToAnchor:visualSurface.centerXAnchor],
        [heroBackdrop.centerYAnchor constraintEqualToAnchor:visualSurface.centerYAnchor constant:-12.0],
        [heroBackdrop.widthAnchor constraintEqualToConstant:156.0],
        [heroBackdrop.heightAnchor constraintEqualToConstant:156.0],
        [heroLottieView.centerXAnchor constraintEqualToAnchor:heroBackdrop.centerXAnchor],
        [heroLottieView.centerYAnchor constraintEqualToAnchor:heroBackdrop.centerYAnchor],
        [heroLottieView.widthAnchor constraintEqualToAnchor:heroBackdrop.widthAnchor constant:26.0],
        [heroLottieView.heightAnchor constraintEqualToAnchor:heroBackdrop.heightAnchor constant:26.0],
        [heroSymbolView.centerXAnchor constraintEqualToAnchor:heroBackdrop.centerXAnchor],
        [heroSymbolView.centerYAnchor constraintEqualToAnchor:heroBackdrop.centerYAnchor],
        [heroSymbolView.widthAnchor constraintEqualToConstant:92.0],
        [heroSymbolView.heightAnchor constraintEqualToConstant:92.0],
        [smallAccentBadge.trailingAnchor constraintEqualToAnchor:heroBackdrop.trailingAnchor constant:10.0],
        [smallAccentBadge.bottomAnchor constraintEqualToAnchor:heroBackdrop.bottomAnchor constant:8.0],
        [smallAccentBadge.widthAnchor constraintEqualToConstant:44.0],
        [smallAccentBadge.heightAnchor constraintEqualToConstant:44.0],
        [smallAccentSymbol.centerXAnchor constraintEqualToAnchor:smallAccentBadge.centerXAnchor],
        [smallAccentSymbol.centerYAnchor constraintEqualToAnchor:smallAccentBadge.centerYAnchor],
        [symbolBadge.leadingAnchor constraintEqualToAnchor:visualSurface.leadingAnchor constant:PPSpaceBase],
        [symbolBadge.bottomAnchor constraintEqualToAnchor:visualSurface.bottomAnchor constant:-PPSpaceBase],
        [symbolBadge.widthAnchor constraintEqualToConstant:42.0],
        [symbolBadge.heightAnchor constraintEqualToConstant:42.0],
        [symbolView.centerXAnchor constraintEqualToAnchor:symbolBadge.centerXAnchor],
        [symbolView.centerYAnchor constraintEqualToAnchor:symbolBadge.centerYAnchor],
        [visualKicker.leadingAnchor constraintEqualToAnchor:symbolBadge.trailingAnchor constant:PPSpaceMD],
        [visualKicker.trailingAnchor constraintLessThanOrEqualToAnchor:visualSurface.trailingAnchor constant:-PPSpaceBase],
        [visualKicker.centerYAnchor constraintEqualToAnchor:symbolBadge.centerYAnchor],
        [headline.topAnchor constraintEqualToAnchor:visualSurface.bottomAnchor constant:PPSpaceXL],
        [headline.leadingAnchor constraintEqualToAnchor:page.leadingAnchor constant:PPIntroScreenMargin],
        [headline.trailingAnchor constraintEqualToAnchor:page.trailingAnchor constant:-PPIntroScreenMargin],
        [body.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:PPSpaceSM],
        [body.leadingAnchor constraintEqualToAnchor:headline.leadingAnchor],
        [body.trailingAnchor constraintEqualToAnchor:headline.trailingAnchor],
    ]];

    [self pp_loadPanelAnimationNamed:panel.lottieName
                            intoView:heroLottieView
                      fallbackSymbol:heroSymbolView];
    [self pp_prepareVisualStageGlow:stageGlow];

    return page;
}

- (void)pp_loadPanelAnimationNamed:(NSString *)animationName
                          intoView:(LOTAnimationView *)animationView
                    fallbackSymbol:(UIImageView *)fallbackSymbol
{
    if (animationName.length == 0 || !animationView) {
        return;
    }

    __weak LOTAnimationView *weakAnimationView = animationView;
    __weak UIImageView *weakFallbackSymbol = fallbackSymbol;
    [AppClasses setAnimationNamed:animationName
                            ToView:animationView
                         withSpeed:0.86
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LOTAnimationView *strongAnimationView = weakAnimationView;
            UIImageView *strongFallbackSymbol = weakFallbackSymbol;
            if (!strongAnimationView || !success) {
                return;
            }

            strongAnimationView.alpha = 0.0;
            strongFallbackSymbol.alpha = 0.0;
            if (!UIAccessibilityIsReduceMotionEnabled()) {
                [strongAnimationView play];
            }

            [UIView animateWithDuration:0.42
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                strongAnimationView.alpha = 1.0;
            } completion:nil];
        });
    }];
}

- (void)pp_prepareVisualStageGlow:(UIView *)glowView {
    if (!glowView || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breath.fromValue = @(0.42);
    breath.toValue = @(0.92);
    breath.duration = 4.6;
    breath.autoreverses = YES;
    breath.repeatCount = HUGE_VALF;
    breath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [glowView.layer addAnimation:breath forKey:@"pp_intro_stage_glow_breath"];

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @(0.94);
    scale.toValue = @(1.06);
    scale.duration = 5.8;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [glowView.layer addAnimation:scale forKey:@"pp_intro_stage_glow_scale"];
}

#pragma mark - Footer

- (void)pp_buildFooter {
    self.indicatorStack = [[UIStackView alloc] init];
    self.indicatorStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorStack.axis = UILayoutConstraintAxisHorizontal;
    self.indicatorStack.spacing = PPSpaceSM;
    self.indicatorStack.alignment = UIStackViewAlignmentCenter;
    self.indicatorStack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.view addSubview:self.indicatorStack];

    NSMutableArray<UIView *> *indicators = [NSMutableArray array];
    for (NSInteger index = 0; index < self.panels.count; index++) {
        UIView *indicator = [[UIView alloc] init];
        indicator.translatesAutoresizingMaskIntoConstraints = NO;
        PPApplyContinuousCorners(indicator, 2.0);
        [indicator.widthAnchor constraintEqualToConstant:index == 0 ? 24.0 : 8.0].active = YES;
        [indicator.heightAnchor constraintEqualToConstant:4.0].active = YES;
        [self.indicatorStack addArrangedSubview:indicator];
        [indicators addObject:indicator];
    }
    self.indicatorViews = indicators.copy;

    self.ctaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.ctaButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaButton.backgroundColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    self.ctaButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.ctaButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.ctaButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, PPSpaceXL, 0.0, PPSpaceXL);
    PPApplyContinuousCorners(self.ctaButton, 27.0);
    PPApplyButtonShadow(self.ctaButton);
    [self.ctaButton addTarget:self action:@selector(pp_ctaTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.ctaButton addTarget:self action:@selector(pp_ctaTouchUp:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpOutside];
    [self.ctaButton addTarget:self action:@selector(pp_ctaTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.ctaButton];

    self.ctaContentStack = [[UIStackView alloc] init];
    self.ctaContentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaContentStack.axis = UILayoutConstraintAxisHorizontal;
    self.ctaContentStack.alignment = UIStackViewAlignmentCenter;
    self.ctaContentStack.distribution = UIStackViewDistributionFill;
    self.ctaContentStack.spacing = PPSpaceSM;
    self.ctaContentStack.userInteractionEnabled = NO;
    [self.ctaButton addSubview:self.ctaContentStack];

    self.ctaTitleLabel = [[UILabel alloc] init];
    self.ctaTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaTitleLabel.font = [GM boldFontWithSize:17.0];
    self.ctaTitleLabel.textColor = AppForgroundColr ?: UIColor.whiteColor;
    self.ctaTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.ctaTitleLabel.numberOfLines = 1;
    self.ctaTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.ctaTitleLabel.minimumScaleFactor = 0.82;
    [self.ctaContentStack addArrangedSubview:self.ctaTitleLabel];

    self.ctaIconView = [[UIImageView alloc] init];
    self.ctaIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaIconView.tintColor = AppForgroundColr ?: UIColor.whiteColor;
    self.ctaIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.ctaContentStack addArrangedSubview:self.ctaIconView];

    self.footerLabel = [[UILabel alloc] init];
    self.footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerLabel.text = kLang(@"intro_footer");
    self.footerLabel.font = [GM MidFontWithSize:11.0];
    self.footerLabel.textAlignment = NSTextAlignmentCenter;
    self.footerLabel.numberOfLines = 1;
    [self.view addSubview:self.footerLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.indicatorStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.indicatorStack.bottomAnchor constraintEqualToAnchor:self.ctaButton.topAnchor constant:-PPSpaceXL],
        [self.ctaButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPIntroScreenMargin],
        [self.ctaButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPIntroScreenMargin],
        [self.ctaButton.heightAnchor constraintEqualToConstant:54.0],
        [self.ctaButton.bottomAnchor constraintEqualToAnchor:self.footerLabel.topAnchor constant:-PPSpaceMD],
        [self.ctaContentStack.centerXAnchor constraintEqualToAnchor:self.ctaButton.centerXAnchor],
        [self.ctaContentStack.centerYAnchor constraintEqualToAnchor:self.ctaButton.centerYAnchor],
        [self.ctaContentStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.ctaButton.leadingAnchor constant:PPSpaceXL],
        [self.ctaContentStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.ctaButton.trailingAnchor constant:-PPSpaceXL],
        [self.ctaIconView.widthAnchor constraintEqualToConstant:18.0],
        [self.ctaIconView.heightAnchor constraintEqualToConstant:18.0],
        [self.footerLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPIntroScreenMargin],
        [self.footerLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPIntroScreenMargin],
        [self.footerLabel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-PPSpaceBase],
    ]];
    [self pp_updateCTAForCurrentIndex];
}

#pragma mark - Navigation

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pageWidth = CGRectGetWidth(scrollView.bounds);
    if (pageWidth <= 0.0) return;
    CGFloat rawProgress = scrollView.contentOffset.x / pageWidth;
    NSInteger nearestIndex = MAX(0, MIN((NSInteger)self.panels.count - 1, (NSInteger)lround(rawProgress)));
    if (nearestIndex != self.currentIndex) {
        self.currentIndex = nearestIndex;
        [self pp_updateCTAForCurrentIndex];
        [self pp_updateIndicatorsAnimated:YES];
        [self pp_animateCurrentPanelContent];
        UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
        [feedback selectionChanged];
    }

    if (UIAccessibilityIsReduceMotionEnabled()) return;
    for (NSInteger index = 0; index < self.panelStack.arrangedSubviews.count; index++) {
        UIView *page = self.panelStack.arrangedSubviews[index];
        UIView *heroBackdrop = [page viewWithTag:PPIntroHeroBackdropTag];
        CGFloat distance = rawProgress - (CGFloat)index;
        heroBackdrop.transform = CGAffineTransformMakeTranslation(distance * 18.0, 0.0);
    }
}

- (void)pp_scrollToPanel:(NSInteger)index animated:(BOOL)animated {
    NSInteger safeIndex = MAX(0, MIN((NSInteger)self.panels.count - 1, index));
    CGFloat x = CGRectGetWidth(self.scrollView.bounds) * (CGFloat)safeIndex;
    [self.scrollView setContentOffset:CGPointMake(x, 0.0) animated:animated];
    if (!animated) {
        self.currentIndex = safeIndex;
        [self pp_updateCTAForCurrentIndex];
        [self pp_updateIndicatorsAnimated:NO];
    }
}

- (void)pp_updateCTAForCurrentIndex {
    BOOL lastPage = self.currentIndex == (NSInteger)self.panels.count - 1;
    NSString *title = kLang(lastPage ? @"intro_begin" : @"intro_continue");
    UIImage *image = [UIImage systemImageNamed:lastPage ? @"sparkles" : @"arrow.right"];
    BOOL isRTL = [Language semanticAttributeForCurrentLanguage] == UISemanticContentAttributeForceRightToLeft;
    if (isRTL && !lastPage) {
        image = [UIImage systemImageNamed:@"arrow.left"];
    }
    [self.ctaButton setTitle:nil forState:UIControlStateNormal];
    [self.ctaButton setImage:nil forState:UIControlStateNormal];
    self.ctaButton.tintColor = AppForgroundColr ?: UIColor.whiteColor;
    self.ctaButton.imageEdgeInsets = UIEdgeInsetsZero;
    self.ctaButton.titleEdgeInsets = UIEdgeInsetsZero;
    self.ctaButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.ctaContentStack.semanticContentAttribute = isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    self.ctaTitleLabel.text = title;
    self.ctaTitleLabel.textColor = AppForgroundColr ?: UIColor.whiteColor;
    self.ctaIconView.tintColor = AppForgroundColr ?: UIColor.whiteColor;
    self.ctaIconView.image = [image imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightBold]];
    self.ctaButton.accessibilityLabel = title;
}

- (void)pp_updateIndicatorsAnimated:(BOOL)animated {
    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    void (^changes)(void) = ^{
        for (NSInteger index = 0; index < self.indicatorViews.count; index++) {
            UIView *indicator = self.indicatorViews[index];
            BOOL selected = index == self.currentIndex;
            indicator.backgroundColor = selected ? accent : [accent colorWithAlphaComponent:0.20];
            for (NSLayoutConstraint *constraint in indicator.constraints) {
                if (constraint.firstAttribute == NSLayoutAttributeWidth) {
                    constraint.constant = selected ? 24.0 : 8.0;
                }
            }
        }
        [self.indicatorStack layoutIfNeeded];
    };
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }
    [UIView animateWithDuration:0.32 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:changes completion:nil];
}

- (void)pp_ctaTapped:(UIButton *)sender {
    [self pp_ctaTouchUp:sender];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    if (self.currentIndex < (NSInteger)self.panels.count - 1) {
        [self pp_scrollToPanel:self.currentIndex + 1 animated:YES];
        return;
    }
    [self pp_handleDismiss];
}

- (void)pp_ctaTouchDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.975, 0.975);
    }];
}

- (void)pp_ctaTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.30
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_skipTouchDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10 animations:^{
        sender.alpha = 0.56;
    }];
}

- (void)pp_skipTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.18 animations:^{
        sender.alpha = 1.0;
    }];
}

- (void)pp_handleDismiss {
    [PPIntroViewController markIntroAsShown];
    [self pp_stopAmbientMotion];
    dispatch_block_t completion = self.dismissalCompletion;
    self.dismissalCompletion = nil;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.view removeFromSuperview];
        if (completion) completion();
        return;
    }
    [UIView animateWithDuration:0.34
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.view.alpha = 0.0;
        self.view.transform = CGAffineTransformMakeScale(1.025, 1.025);
    } completion:^(__unused BOOL finished) {
        [self.view removeFromSuperview];
        if (completion) completion();
    }];
}

#pragma mark - Motion

- (void)pp_startAmbientMotionIfNeeded {
    if (self.ambientMotionRunning || UIAccessibilityIsReduceMotionEnabled()) return;
    self.ambientMotionRunning = YES;
    [self.ambientLottieView play];

    CABasicAnimation *topDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    topDrift.fromValue = @(-18.0);
    topDrift.toValue = @(18.0);
    topDrift.duration = 7.6;
    topDrift.autoreverses = YES;
    topDrift.repeatCount = HUGE_VALF;
    topDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.topGlowView.layer addAnimation:topDrift forKey:@"pp_intro_top_drift"];

    CABasicAnimation *middleDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    middleDrift.fromValue = @(-14.0);
    middleDrift.toValue = @(18.0);
    middleDrift.duration = 8.8;
    middleDrift.autoreverses = YES;
    middleDrift.repeatCount = HUGE_VALF;
    middleDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.middleGlowView.layer addAnimation:middleDrift forKey:@"pp_intro_middle_drift"];

    CABasicAnimation *middleBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    middleBreath.fromValue = @(0.46);
    middleBreath.toValue = @(0.86);
    middleBreath.duration = 6.2;
    middleBreath.autoreverses = YES;
    middleBreath.repeatCount = HUGE_VALF;
    middleBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.middleGlowView.layer addAnimation:middleBreath forKey:@"pp_intro_middle_breath"];

    CABasicAnimation *bottomBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    bottomBreath.fromValue = @(0.62);
    bottomBreath.toValue = @(1.0);
    bottomBreath.duration = 4.8;
    bottomBreath.autoreverses = YES;
    bottomBreath.repeatCount = HUGE_VALF;
    bottomBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.bottomGlowView.layer addAnimation:bottomBreath forKey:@"pp_intro_bottom_breath"];
}

- (void)pp_stopAmbientMotion {
    self.ambientMotionRunning = NO;
    [self.ambientLottieView stop];
    [self.topGlowView.layer removeAllAnimations];
    [self.middleGlowView.layer removeAllAnimations];
    [self.bottomGlowView.layer removeAllAnimations];
}

- (void)pp_animateEntranceIfNeeded {
    if (self.didAnimateEntrance) return;
    self.didAnimateEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    NSArray<UIView *> *views = @[self.logoView, self.brandLabel, self.brandKickerLabel, self.skipButton,
                                self.indicatorStack, self.ctaButton, self.footerLabel];
    for (UIView *view in views) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    }
    [UIView animateWithDuration:0.46 delay:0.05 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.logoView.alpha = 1.0;
        self.logoView.transform = CGAffineTransformIdentity;
        self.brandLabel.alpha = 1.0;
        self.brandLabel.transform = CGAffineTransformIdentity;
        self.brandKickerLabel.alpha = 1.0;
        self.brandKickerLabel.transform = CGAffineTransformIdentity;
        self.skipButton.alpha = 1.0;
        self.skipButton.transform = CGAffineTransformIdentity;
    } completion:nil];
    [self pp_animateCurrentPanelContent];
    [UIView animateWithDuration:0.48 delay:0.28 usingSpringWithDamping:0.86 initialSpringVelocity:0.18 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.indicatorStack.alpha = 1.0;
        self.indicatorStack.transform = CGAffineTransformIdentity;
        self.ctaButton.alpha = 1.0;
        self.ctaButton.transform = CGAffineTransformIdentity;
        self.footerLabel.alpha = 1.0;
        self.footerLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_animateCurrentPanelContent {
    if (UIAccessibilityIsReduceMotionEnabled() || self.currentIndex >= self.panelStack.arrangedSubviews.count) return;
    UIView *page = self.panelStack.arrangedSubviews[self.currentIndex];
    NSArray<UIView *> *views = @[[page viewWithTag:PPIntroVisualSurfaceTag], [page viewWithTag:PPIntroHeadlineTag], [page viewWithTag:PPIntroBodyTag]];
    NSArray<NSNumber *> *delays = @[@0.04, @0.13, @0.20];
    for (NSInteger index = 0; index < views.count; index++) {
        UIView *view = views[index];
        view.alpha = 0.0;
        view.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 14.0),
                                                  CGAffineTransformMakeScale(0.985, 0.985));
        [UIView animateWithDuration:0.48
                              delay:delays[index].doubleValue
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Content

- (NSArray<PPIntroPanel *> *)pp_defaultPanels {
    PPIntroPanel *care = [[PPIntroPanel alloc] initWithImage:@"heart.circle.fill"
                                                  lottieName:@"intro1"
                                                    headline:kLang(@"intro_panel1_title")
                                                        body:kLang(@"intro_panel1_subtitle")];
    care.eyebrow = kLang(@"intro_panel1_eyebrow");
    care.symbolName = @"heart.text.square.fill";

    PPIntroPanel *routine = [[PPIntroPanel alloc] initWithImage:@"calendar.badge.checkmark"
                                                     lottieName:@"intro2"
                                                       headline:kLang(@"intro_panel2_title")
                                                           body:kLang(@"intro_panel2_subtitle")];
    routine.eyebrow = kLang(@"intro_panel2_eyebrow");
    routine.symbolName = @"checkmark.seal.fill";

    PPIntroPanel *connected = [[PPIntroPanel alloc] initWithImage:@"sparkles"
                                                       lottieName:@"intro3"
                                                         headline:kLang(@"intro_panel3_title")
                                                             body:kLang(@"intro_panel3_subtitle")];
    connected.eyebrow = kLang(@"intro_panel3_eyebrow");
    connected.symbolName = @"sparkles";
    return @[care, routine, connected];
}

@end
