//
//  PPHomePremiumSearchCell.m
//  Pure Pets
//
//  Created by Kilo on 02/05/2026.
//

#import "PPHomePremiumSearchCell.h"
#import <QuartzCore/QuartzCore.h>

static UISemanticContentAttribute PPPSB_CurrentSemantic(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static NSTextAlignment PPPSB_CurrentTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

#if __has_include(<Lottie/Lottie.h>) || __has_include("Lottie.h") || __has_include(<lottie-ios_Oc/Lottie.h>) || __has_include(<lottie_ios_Oc/Lottie.h>)
#define PPPSB_HAS_LOTTIE 1
#else
#define PPPSB_HAS_LOTTIE 0
#endif

static CGFloat const PPPSBChromeCornerRadius = 22.0;
static CGFloat const PPPSBCompactWidthThreshold = 280.0;
static NSString * const PPPSBLeadingFireLottiePrimaryPath = @"LottieAnimations/Fire.json";
static NSString * const PPPSBLeadingFireLottieRootPath = @"Fire.json";
static NSString * const PPPSBSignalPulseAnimationKey = @"pp.home.premiumSearch.signalPulse";
static NSString * const PPPSBIconBreathAnimationKey = @"pp.home.premiumSearch.iconBreath";

static NSArray<NSString *> *PPPSB_SmartSearchPlaceholdersForWidth(CGFloat width)
{
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    BOOL prefersExpandedExamples = (width <= 0.0 || width >= PPPSBCompactWidthThreshold);

    NSString *basePlaceholder = prefersExpandedExamples
        ? (kLang(@"home_nav_search_base_placeholder")         ?: @"What does your pet need today?")
        : (kLang(@"home_nav_search_base_placeholder_compact") ?: @"Search here");
    NSString *safeBase = PPSafeString(basePlaceholder);
    if (safeBase.length > 0) {
        [items addObject:safeBase];
    }

    NSArray<NSString *> *candidates = prefersExpandedExamples
        ? @[
            kLang(@"home_nav_search_example_cats")        ?: @"Cats for sale",
            kLang(@"home_nav_search_example_vets")        ?: @"Nearby vets",
            kLang(@"home_nav_search_example_food")        ?: @"Dog food",
            kLang(@"home_nav_search_example_accessories") ?: @"Pet accessories",
            kLang(@"home_nav_search_example_grooming")    ?: @"Pet grooming",
            kLang(@"home_nav_search_example_training")    ?: @"Dog training",
            kLang(@"home_nav_search_example_birds")       ?: @"Birds for sale",
            kLang(@"home_nav_search_example_toys")        ?: @"Pet toys & games",
            kLang(@"home_nav_search_example_adopt")       ?: @"Adopt a pet",
            kLang(@"home_nav_search_example_fish")        ?: @"Aquarium fish",
            kLang(@"home_nav_search_example_boarding")    ?: @"Pet boarding",
            kLang(@"home_nav_search_example_pharmacy")    ?: @"Pet pharmacy",
        ]
        : @[
            kLang(@"home_nav_search_example_cats_compact")        ?: @"Cats",
            kLang(@"home_nav_search_example_vets_compact")        ?: @"Vet",
            kLang(@"home_nav_search_example_food_compact")        ?: @"Food",
            kLang(@"home_nav_search_example_accessories_compact") ?: @"Gear",
            kLang(@"home_nav_search_example_grooming_compact")    ?: @"Groom",
            kLang(@"home_nav_search_example_training_compact")    ?: @"Train",
            kLang(@"home_nav_search_example_birds_compact")       ?: @"Birds",
            kLang(@"home_nav_search_example_toys_compact")        ?: @"Toys",
            kLang(@"home_nav_search_example_adopt_compact")       ?: @"Adopt",
            kLang(@"home_nav_search_example_fish_compact")        ?: @"Fish",
            kLang(@"home_nav_search_example_boarding_compact")    ?: @"Board",
            kLang(@"home_nav_search_example_pharmacy_compact")    ?: @"Meds",
        ];

    for (NSString *candidate in candidates) {
        NSString *safeCandidate = PPSafeString(candidate);
        if (safeCandidate.length > 0 && ![items containsObject:safeCandidate]) {
            [items addObject:safeCandidate];
        }
    }

    if (items.count == 0) {
        [items addObject:(kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets")];
    }

    return items.copy;
}

static NSString *PPPSB_DefaultSmartSearchPlaceholderForWidth(CGFloat width)
{
    NSArray<NSString *> *items = PPPSB_SmartSearchPlaceholdersForWidth(width);
    NSString *first = items.firstObject;
    return first ?: (kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets");
}

@implementation PPHomePremiumSearchCell {
    UIView *_chromeView;
    UIButton *_glassChromeButton;
    UIVisualEffectView *_chromeBlurView;
    UIView *_leadingChipView;
    UIImageView *_leadingIconView;
    LOTAnimationView *_leadingLottieView;
    NSString *_leadingLottieSignature;
    UIStackView *_textStackView;
    UIStackView *_signalRowView;
    UIView *_signalDotView;
    UILabel *_signalLabel;
    UILabel *_placeholderLabel;
    UIView *_trailingSearchView;
    UIImageView *_trailingSearchIconView;
    BOOL _signalAnimationsConfigured;
    NSUInteger _placeholderColorIndex;
    NSUInteger _placeholderTransitionGeneration;
    UIViewPropertyAnimator *_placeholderSettleAnimator;
    UIButton *_tapButton;
}

+ (NSString *)reuseIdentifier
{
    return @"PPPremuimSearchbarCell";
}

- (BOOL)pp_usesSystemGlassChrome
{
    return _glassChromeButton != nil;
}


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildInterface];

    return self;
}

- (void)pp_buildInterface
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.semanticContentAttribute = PPPSB_CurrentSemantic();
    self.contentView.semanticContentAttribute = PPPSB_CurrentSemantic();
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSearchField;

    self.layer.shadowOpacity = 0.0f;
    self.layer.shadowRadius = 0.0f;
    self.layer.shadowOffset = CGSizeZero;
 /*
 if (@available(iOS 26.0, *)) {
     UIButtonConfiguration *configuration =
     [UIButtonConfiguration glassButtonConfiguration];
     configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
     configuration.contentInsets = NSDirectionalEdgeInsetsZero;
     configuration.baseForegroundColor = UIColor.clearColor;
     configuration.background.backgroundColor = UIColor.clearColor;
 }
 */
    UIView *chromeView = nil;
    if (@available(iOS 26.0, *)) {
        UIButton *glassButton = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
        glassButton.backgroundColor = UIColor.clearColor;
        glassButton.userInteractionEnabled = NO;

        UIButtonConfiguration *configuration = glassButton.configuration;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        configuration.background.cornerRadius = PPPSBChromeCornerRadius ;
        configuration.baseForegroundColor = UIColor.clearColor;
        configuration.background.backgroundColor = UIColor.clearColor;

        glassButton.configuration = configuration;

        chromeView = glassButton;
        _glassChromeButton = glassButton;

       
        
    } else {
        chromeView = [[UIView alloc] initWithFrame:self.contentView.bounds];
    }
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.backgroundColor = UIColor.clearColor;

    chromeView.userInteractionEnabled = NO;
    chromeView.layer.cornerRadius = PPPSBChromeCornerRadius ;
    chromeView.layer.masksToBounds = NO;


    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:chromeView];
    
    self.contentView.clipsToBounds = NO;
    self.contentView.layer.masksToBounds = NO;
    
    
    _chromeView = chromeView;
    [chromeView.heightAnchor constraintEqualToConstant:44.0].active = YES;

    if (!PPIOS26()) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        blurView.alpha = 0.0;
        [chromeView insertSubview:blurView atIndex:0];
        _chromeBlurView = blurView;
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:chromeView.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:chromeView.bottomAnchor],
        ]];


    }

    UIView *leadingChipView = [UIView new];
    leadingChipView.translatesAutoresizingMaskIntoConstraints = NO;
    leadingChipView.userInteractionEnabled = NO;
    leadingChipView.layer.cornerRadius = 14.0;
    leadingChipView.clipsToBounds = YES;
    leadingChipView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        leadingChipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [chromeView addSubview:leadingChipView];
    _leadingChipView = leadingChipView;

    UIImageView *leadingIconView =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"flame.fill"
                                                         pointSize:12
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[AppPrimaryClr ?: AppPrimaryClrShiner ?: UIColor.systemOrangeColor]
                                                      makeTemplate:YES]];
    leadingIconView.translatesAutoresizingMaskIntoConstraints = NO;
    leadingIconView.contentMode = UIViewContentModeScaleAspectFit;
    leadingIconView.userInteractionEnabled = NO;
    leadingIconView.alpha = 1.0;
    [leadingChipView addSubview:leadingIconView];
    _leadingIconView = leadingIconView;

#if PPPSB_HAS_LOTTIE
    LOTAnimationView *leadingLottieView = [[LOTAnimationView alloc] init];
    leadingLottieView.translatesAutoresizingMaskIntoConstraints = NO;
    leadingLottieView.contentMode = UIViewContentModeScaleAspectFit;
    leadingLottieView.userInteractionEnabled = NO;
    leadingLottieView.backgroundColor = UIColor.clearColor;
    leadingLottieView.opaque = NO;
    leadingLottieView.hidden = YES;
    leadingLottieView.alpha = 1.0;
    [leadingChipView addSubview:leadingLottieView];
    _leadingLottieView = leadingLottieView;

    [NSLayoutConstraint activateConstraints:@[
        [leadingLottieView.centerXAnchor constraintEqualToAnchor:leadingChipView.centerXAnchor],
        [leadingLottieView.centerYAnchor constraintEqualToAnchor:leadingChipView.centerYAnchor],
        [leadingLottieView.widthAnchor constraintEqualToConstant:24.0],
        [leadingLottieView.heightAnchor constraintEqualToConstant:24.0],
    ]];
#endif

    UIStackView *textStackView = [[UIStackView alloc] init];
    textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    textStackView.axis = UILayoutConstraintAxisVertical;
    textStackView.alignment = UIStackViewAlignmentFill;
    textStackView.distribution = UIStackViewDistributionFill;
    textStackView.spacing = 1.0;
    textStackView.userInteractionEnabled = NO;
    [chromeView addSubview:textStackView];
    _textStackView = textStackView;

    UIStackView *signalRowView = [[UIStackView alloc] init];
    signalRowView.translatesAutoresizingMaskIntoConstraints = NO;
    signalRowView.axis = UILayoutConstraintAxisHorizontal;
    signalRowView.alignment = UIStackViewAlignmentCenter;
    signalRowView.spacing = 4.0;
    signalRowView.userInteractionEnabled = NO;
    [textStackView addArrangedSubview:signalRowView];
    _signalRowView = signalRowView;

    UIView *signalDotView = [UIView new];
    signalDotView.translatesAutoresizingMaskIntoConstraints = NO;
    signalDotView.userInteractionEnabled = NO;
    signalDotView.layer.cornerRadius = 2.75;
    signalDotView.layer.masksToBounds = YES;
    [signalRowView addArrangedSubview:signalDotView];
    _signalDotView = signalDotView;

    UILabel *signalLabel = [UILabel new];
    signalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    signalLabel.font = [GM MidFontWithSize:9.0] ?: [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold];
    signalLabel.textAlignment = PPPSB_CurrentTextAlignment();
    signalLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    signalLabel.adjustsFontSizeToFitWidth = YES;
    signalLabel.minimumScaleFactor = 0.84;
    signalLabel.numberOfLines = 1;
    signalLabel.userInteractionEnabled = NO;
    signalLabel.text = kLang(@"home_nav_search_trending") ?: @"Trending";
    [signalRowView addArrangedSubview:signalLabel];
    _signalLabel = signalLabel;

    UILabel *placeholderLabel = [UILabel new];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    placeholderLabel.textAlignment = PPPSB_CurrentTextAlignment();
    placeholderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    placeholderLabel.adjustsFontSizeToFitWidth = YES;
    placeholderLabel.allowsDefaultTighteningForTruncation = YES;
    placeholderLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    placeholderLabel.minimumScaleFactor = 0.82;
    placeholderLabel.numberOfLines = 1;
    placeholderLabel.userInteractionEnabled = NO;
    placeholderLabel.text = PPPSB_DefaultSmartSearchPlaceholderForWidth(CGRectGetWidth(self.bounds));
    [textStackView addArrangedSubview:placeholderLabel];
    _placeholderLabel = placeholderLabel;

    UIView *trailingSearchView = [UIView new];
    trailingSearchView.translatesAutoresizingMaskIntoConstraints = NO;
    trailingSearchView.userInteractionEnabled = NO;
    trailingSearchView.layer.cornerRadius = 13.0;
    trailingSearchView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        trailingSearchView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [chromeView addSubview:trailingSearchView];
    _trailingSearchView = trailingSearchView;

    UIImageView *trailingSearchIconView =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"magnifyingglass"
                                                         pointSize:16.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                                      makeTemplate:YES]];
    trailingSearchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    trailingSearchIconView.contentMode = UIViewContentModeScaleAspectFit;
    trailingSearchIconView.userInteractionEnabled = NO;
    [trailingSearchView addSubview:trailingSearchIconView];
    _trailingSearchIconView = trailingSearchIconView;

    // Tap Button to handle taps instead of relying on cell highlighting if we want to intercept.
    // Or we can use cell's selection. But original PPPremuimSearchbarCell used _tapButton.
    _tapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _tapButton.translatesAutoresizingMaskIntoConstraints = NO;
    _tapButton.backgroundColor = UIColor.clearColor;
    [_tapButton addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [_tapButton addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [_tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [_tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [_tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.contentView addSubview:_tapButton];

    [NSLayoutConstraint activateConstraints:@[
        [_tapButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor ],
        [_tapButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:4],
        [_tapButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
        [_tapButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [chromeView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:0.0],
        [chromeView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:4],
        [chromeView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
        [chromeView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-0.0],

        [leadingChipView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor constant:7.0],
        [leadingChipView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [leadingChipView.widthAnchor constraintEqualToConstant:32.0],
        [leadingChipView.heightAnchor constraintEqualToConstant:32.0],

        [leadingIconView.centerXAnchor constraintEqualToAnchor:leadingChipView.centerXAnchor],
        [leadingIconView.centerYAnchor constraintEqualToAnchor:leadingChipView.centerYAnchor],
        [leadingIconView.widthAnchor constraintEqualToConstant:14.0],
        [leadingIconView.heightAnchor constraintEqualToConstant:14.0],

        [signalDotView.widthAnchor constraintEqualToConstant:5.5],
        [signalDotView.heightAnchor constraintEqualToConstant:5.5],

        [textStackView.leadingAnchor constraintEqualToAnchor:leadingChipView.trailingAnchor constant:10.0],
        [textStackView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [textStackView.topAnchor constraintGreaterThanOrEqualToAnchor:chromeView.topAnchor constant:6.5],
        [textStackView.bottomAnchor constraintLessThanOrEqualToAnchor:chromeView.bottomAnchor constant:-6.5],
        [textStackView.trailingAnchor constraintEqualToAnchor:trailingSearchView.leadingAnchor constant:-10.0],

        [trailingSearchView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor constant:-7.0],
        [trailingSearchView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [trailingSearchView.widthAnchor constraintEqualToConstant:26.0],
        [trailingSearchView.heightAnchor constraintEqualToConstant:26.0],

        [trailingSearchIconView.centerXAnchor constraintEqualToAnchor:trailingSearchView.centerXAnchor],
        [trailingSearchIconView.centerYAnchor constraintEqualToAnchor:trailingSearchView.centerYAnchor],
        [trailingSearchIconView.widthAnchor constraintEqualToConstant:17.0],
        [trailingSearchIconView.heightAnchor constraintEqualToConstant:17.0]
    ]];

    [_placeholderLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [_signalLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                  forAxis:UILayoutConstraintAxisHorizontal];
    [_trailingSearchView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                         forAxis:UILayoutConstraintAxisHorizontal];

    [self pp_applyPalette];
    [self pp_updateInteractiveStateAnimated:YES focused:NO];
    [self pp_loadLeadingFireLottie];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    BOOL compact = width < PPPSBCompactWidthThreshold;
    _signalRowView.hidden = compact;
    _textStackView.spacing = compact ? 0.0 : 0.5;
    _signalLabel.font = compact
        ? ([GM MidFontWithSize:8.0] ?: [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold])
        : ([GM MidFontWithSize:9.0] ?: [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold]);
    _placeholderLabel.font = compact
        ? ([GM boldFontWithSize:12.75] ?: [UIFont systemFontOfSize:12.75 weight:UIFontWeightSemibold])
        : ([GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold]);
    _chromeView.layer.cornerRadius = 6;
    _leadingChipView.layer.cornerRadius = CGRectGetHeight(_leadingChipView.bounds) * 0.5;
    _trailingSearchView.layer.cornerRadius = CGRectGetHeight(_trailingSearchView.bounds) * 0.5;
    _signalDotView.layer.cornerRadius = 2.75;
    self.layer.shadowPath = nil;
    [self pp_updateLeadingFireLottiePlayback];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window) {
        [self pp_stopAmbientMotion];
        [self pp_stopLeadingFireLottie];
        return;
    }

    [self pp_updateLeadingFireLottiePlayback];
    [self pp_startAmbientMotionIfNeeded];
}

- (void)pp_startAmbientMotionIfNeeded
{
    if (_signalAnimationsConfigured || UIAccessibilityIsReduceMotionEnabled() || CGRectGetWidth(self.bounds) <= 0.0) {
        return;
    }

    _signalAnimationsConfigured = YES;

    CABasicAnimation *pulseScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseScale.fromValue = @(0.88);
    pulseScale.toValue = @(1.18);
    pulseScale.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    CABasicAnimation *pulseOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulseOpacity.fromValue = @(0.60);
    pulseOpacity.toValue = @(1.0);
    pulseOpacity.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    CAAnimationGroup *signalPulse = [CAAnimationGroup animation];
    signalPulse.duration = 2.2;
    signalPulse.repeatCount = HUGE_VALF;
    signalPulse.autoreverses = YES;
    signalPulse.animations = @[pulseScale, pulseOpacity];
    [_signalDotView.layer addAnimation:signalPulse forKey:PPPSBSignalPulseAnimationKey];

    CAKeyframeAnimation *iconBreath = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    iconBreath.values = @[@(1.0), @(1.055), @(1.0)];
    iconBreath.keyTimes = @[@(0.0), @(0.44), @(1.0)];
    iconBreath.duration = 4.8;
    iconBreath.repeatCount = HUGE_VALF;
    iconBreath.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
    ];
    [_trailingSearchIconView.layer addAnimation:iconBreath forKey:PPPSBIconBreathAnimationKey];
}

- (void)pp_stopAmbientMotion
{
    [_signalDotView.layer removeAnimationForKey:PPPSBSignalPulseAnimationKey];
    [_trailingSearchIconView.layer removeAnimationForKey:PPPSBIconBreathAnimationKey];
    _signalAnimationsConfigured = NO;
}

- (UIColor *)pp_nextPlaceholderColor
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    NSArray<UIColor *> *palette = @[
        [UIColor colorWithRed:0.96 green:0.40 blue:0.32 alpha:1.0],   // coral
        [UIColor colorWithRed:0.20 green:0.65 blue:0.85 alpha:1.0],   // ocean blue
        [UIColor colorWithRed:0.58 green:0.39 blue:0.87 alpha:1.0],   // amethyst
        [UIColor colorWithRed:0.18 green:0.75 blue:0.54 alpha:1.0],   // emerald
        [UIColor colorWithRed:0.94 green:0.60 blue:0.22 alpha:1.0],   // tangerine
        [UIColor colorWithRed:0.84 green:0.32 blue:0.62 alpha:1.0],   // rose
        [UIColor colorWithRed:0.30 green:0.55 blue:0.92 alpha:1.0],   // royal blue
        [UIColor colorWithRed:0.16 green:0.72 blue:0.42 alpha:1.0],   // jade
        [UIColor colorWithRed:0.78 green:0.52 blue:0.20 alpha:1.0],   // amber
        [UIColor colorWithRed:0.46 green:0.32 blue:0.78 alpha:1.0],   // indigo
        [UIColor colorWithRed:0.90 green:0.44 blue:0.46 alpha:1.0],   // blush
        [UIColor colorWithRed:0.22 green:0.60 blue:0.72 alpha:1.0],   // teal
    ];
    UIColor *base = palette[_placeholderColorIndex % palette.count];
    _placeholderColorIndex = (_placeholderColorIndex + 1) % palette.count;
    return isDark ? [base colorWithAlphaComponent:0.96] : [base colorWithAlphaComponent:0.88];
}

- (void)configureWithTrendingQuery:(NSString *)query
{
    [self pp_loadLeadingFireLottie];
    [self pp_applySearchPlaceholderText:query animated:YES accentMotion:YES];
}

- (void)setQueryText:(NSString *)text animated:(BOOL)animated
{
    [self pp_applySearchPlaceholderText:text animated:animated accentMotion:YES];
}

- (NSString *)pp_normalizedSearchPlaceholderText:(NSString *)text
{
    NSString *safeText = PPSafeString(text);
    if (safeText.length == 0) {
        safeText = PPPSB_DefaultSmartSearchPlaceholderForWidth(CGRectGetWidth(self.bounds));
    }
    return safeText;
}

- (void)pp_applySearchPlaceholderText:(NSString *)text
                             animated:(BOOL)animated
                         accentMotion:(BOOL)accentMotion
{
    NSString *safeText = [self pp_normalizedSearchPlaceholderText:text];
    self.accessibilityValue = safeText;
    self.accessibilityHint = kLang(@"home_search_hint") ?: @"What are you looking for?";
    self.accessibilityLabel = kLang(@"home_nav_search_accessibility") ?: @"Open smart search";

    if ([_placeholderLabel.text isEqualToString:safeText]) {
        return;
    }

    UIColor *nextColor = [self pp_nextPlaceholderColor];
    if (!animated || UIAccessibilityIsReduceMotionEnabled() || !self.window) {
        _placeholderTransitionGeneration++;
        [_placeholderSettleAnimator stopAnimation:YES];
        _placeholderSettleAnimator = nil;
        _placeholderLabel.text = safeText;
        _placeholderLabel.textColor = nextColor;
        _placeholderLabel.transform = CGAffineTransformIdentity;
        _placeholderLabel.alpha = 1.0;
        _signalRowView.alpha = 1.0;
        _leadingChipView.transform = CGAffineTransformIdentity;
        _trailingSearchView.transform = CGAffineTransformIdentity;
        _trailingSearchIconView.transform = CGAffineTransformIdentity;
        return;
    }

    [self pp_performPremiumPlaceholderTransitionToText:safeText
                                             textColor:nextColor
                                          accentMotion:accentMotion];
}

- (void)pp_performPremiumPlaceholderTransitionToText:(NSString *)safeText
                                           textColor:(UIColor *)textColor
                                        accentMotion:(BOOL)accentMotion
{
    _placeholderTransitionGeneration++;
    NSUInteger generation = _placeholderTransitionGeneration;
    [_placeholderSettleAnimator stopAnimation:YES];
    _placeholderSettleAnimator = nil;

    BOOL rtl = PPPSB_CurrentSemantic() == UISemanticContentAttributeForceRightToLeft;
    CGFloat inlineDirection = rtl ? -1.0 : 1.0;

    [UIView animateWithDuration:0.16
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_placeholderLabel.transform = CGAffineTransformMakeTranslation(0.0, -4.0);
        self->_placeholderLabel.alpha = 0.0;
        self->_signalRowView.alpha = 0.74;
        if (accentMotion) {
            self->_trailingSearchIconView.transform = CGAffineTransformMakeTranslation(inlineDirection * 1.5, 0.0);
        }
    } completion:^(__unused BOOL finished) {
        if (generation != self->_placeholderTransitionGeneration) {
            return;
        }

        self->_placeholderLabel.text = safeText;
        self->_placeholderLabel.textColor = textColor;
        self->_placeholderLabel.transform = CGAffineTransformMakeTranslation(0.0, 7.0);
        if (accentMotion) {
            self->_leadingChipView.transform = CGAffineTransformMakeScale(1.026, 1.026);
            self->_trailingSearchView.transform = CGAffineTransformMakeScale(1.024, 1.024);
            self->_trailingSearchIconView.transform = CGAffineTransformMakeTranslation(-inlineDirection * 1.2, 0.0);
        }

        UIViewPropertyAnimator *settleAnimator =
            [[UIViewPropertyAnimator alloc] initWithDuration:0.42
                                                controlPoint1:CGPointMake(0.4, 0.0)
                                                controlPoint2:CGPointMake(0.2, 1.0)
                                                   animations:^{
            self->_placeholderLabel.transform = CGAffineTransformIdentity;
            self->_placeholderLabel.alpha = 1.0;
            self->_signalRowView.alpha = 1.0;
            self->_leadingChipView.transform = CGAffineTransformIdentity;
            self->_trailingSearchView.transform = CGAffineTransformIdentity;
            self->_trailingSearchIconView.transform = CGAffineTransformIdentity;
        }];
        [settleAnimator addCompletion:^(__unused UIViewAnimatingPosition finalPosition) {
            if (generation == self->_placeholderTransitionGeneration) {
                self->_placeholderSettleAnimator = nil;
            }
        }];
        self->_placeholderSettleAnimator = settleAnimator;
        [settleAnimator startAnimation];
    }];
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    [self pp_applyPalette];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self pp_updateInteractiveStateAnimated:YES focused:highlighted];
}

- (void)pp_handleTap
{
    if (self.onTap) {
        self.onTap();
    }
}

- (void)pp_handleTouchDown
{
    [self pp_updateInteractiveStateAnimated:YES focused:YES];
}

- (void)pp_handleTouchUp
{
    [self pp_updateInteractiveStateAnimated:YES focused:NO];
}

- (void)pp_applyPalette
{
    UIColor *textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *accentColor = AppPrimaryClr ?: AppPrimaryClrShiner ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
    UIColor *surfaceColor = [AppBackgroundClr colorWithAlphaComponent:0.8] ?: [UIColor secondarySystemBackgroundColor];
    UIColor *liquidBorderColor = AppForgroundColr ?: surfaceColor;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL usesSystemGlassChrome = [self pp_usesSystemGlassChrome];

    _chromeView.backgroundColor = UIColor.clearColor;
    if (!PPIOS26()) {
        _chromeBlurView.alpha = 1.0;

        UIBlurEffectStyle blurStyle = isDark
            ? UIBlurEffectStyleSystemThinMaterialDark
            : UIBlurEffectStyleSystemThinMaterialLight;
        _chromeBlurView.effect = [UIBlurEffect effectWithStyle:blurStyle];

        _chromeView.layer.borderWidth = isDark ? 0.78f : 0.92f;
        [_chromeView pp_setBorderColor:[liquidBorderColor colorWithAlphaComponent:isDark ? 0.30 : 0.58]];
    }

    _leadingChipView.backgroundColor = AppClearClr;
    _leadingChipView.layer.borderWidth = 0.0f;
    _leadingChipView.clipsToBounds = YES;
    [_leadingChipView pp_setBorderColor:UIColor.clearColor];
    _leadingIconView.tintColor = accentColor;

    _trailingSearchView.backgroundColor = AppClearClr;
    _trailingSearchView.layer.borderWidth = 0.0f;
    [_trailingSearchView pp_setBorderColor:[textColor colorWithAlphaComponent:isDark ? 0.18 : 0.14]];
    _trailingSearchIconView.image = [UIImage pp_symbolNamed:@"magnifyingglass"
                                                  pointSize:16.0
                                                     weight:UIImageSymbolWeightSemibold
                                                      scale:UIImageSymbolScaleMedium
                                                    palette:@[[textColor colorWithAlphaComponent:isDark ? 0.78 : 0.62]]
                                               makeTemplate:YES];
    _trailingSearchIconView.tintColor = [textColor colorWithAlphaComponent:isDark ? 0.78 : 0.62];

    _signalDotView.backgroundColor = AppPrimaryClrShiner ?: accentColor;
    _signalLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.72 : 0.58];
    _placeholderLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.96 : 0.90];

    self.layer.shadowOpacity = 0.0f;
    self.layer.shadowRadius = 0.0f;
    self.layer.shadowPath = nil;
}

- (void)pp_loadLeadingFireLottie
{
#if PPPSB_HAS_LOTTIE
    if (!_leadingLottieView) {
        return;
    }
    if ([_leadingLottieSignature hasPrefix:@"loaded"]) {
        _leadingLottieView.hidden = NO;
        _leadingLottieView.alpha = 1.0;
        _leadingIconView.alpha = 0.0;
        [self pp_updateLeadingFireLottiePlayback];
        return;
    }
    if ([_leadingLottieSignature isEqualToString:@"loading"]) {
        return;
    }

    _leadingLottieSignature = @"loading";
    [self pp_fetchLeadingFireLottieAtStoragePath:PPPSBLeadingFireLottiePrimaryPath fallbackToRoot:YES];
#endif
}

- (void)pp_fetchLeadingFireLottieAtStoragePath:(NSString *)storagePath fallbackToRoot:(BOOL)fallbackToRoot
{
#if PPPSB_HAS_LOTTIE
    NSString *safeStoragePath = PPSafeString(storagePath);
    if (safeStoragePath.length == 0) {
        _leadingLottieSignature = nil;
        return;
    }

    __weak typeof(self) weakSelf = self;
    [AppClasses fetchLottieJSONFromFirebasePath:safeStoragePath
                                     completion:^(NSDictionary * _Nonnull jsonDict,
                                                  NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            if (error || ![jsonDict isKindOfClass:NSDictionary.class]) {
                if (fallbackToRoot) {
                    [self pp_fetchLeadingFireLottieAtStoragePath:PPPSBLeadingFireLottieRootPath fallbackToRoot:NO];
                    return;
                }
                self->_leadingLottieSignature = nil;
                self->_leadingIconView.alpha = 1.0;
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                if (fallbackToRoot) {
                    [self pp_fetchLeadingFireLottieAtStoragePath:PPPSBLeadingFireLottieRootPath fallbackToRoot:NO];
                    return;
                }
                self->_leadingLottieSignature = nil;
                self->_leadingIconView.alpha = 1.0;
                return;
            }

            self->_leadingLottieSignature = [NSString stringWithFormat:@"loaded:%@", safeStoragePath];
            [self->_leadingLottieView setSceneModel:composition];
            self->_leadingLottieView.loopAnimation = YES;
            self->_leadingLottieView.animationSpeed = 1.05;
            self->_leadingLottieView.animationProgress = 0.0;
            self->_leadingLottieView.hidden = NO;
            self->_leadingLottieView.alpha = 1.0;
            self->_leadingIconView.alpha = 0.0;

            [self pp_updateLeadingFireLottiePlayback];
        });
    }];
#endif
}

- (void)pp_stopLeadingFireLottie
{
#if PPPSB_HAS_LOTTIE
    [_leadingLottieView stop];
#endif
}

- (void)pp_updateLeadingFireLottiePlayback
{
#if PPPSB_HAS_LOTTIE
    if (!_leadingLottieView || _leadingLottieView.hidden || ![_leadingLottieSignature hasPrefix:@"loaded"]) {
        return;
    }

    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        [_leadingLottieView stop];
        _leadingLottieView.animationProgress = 0.42;
        return;
    }

    if (!_leadingLottieView.isAnimationPlaying) {
        [_leadingLottieView play];
    }
#endif
}

- (void)pp_updateInteractiveStateAnimated:(BOOL)animated focused:(BOOL)focused
{
    void (^changes)(void) = ^{
        BOOL isPressed = focused || self.highlighted;
        BOOL usesSystemGlassChrome = [self pp_usesSystemGlassChrome];
        CGFloat chromeScale = usesSystemGlassChrome ? 0.992 : 0.988;
        self->_chromeView.transform = isPressed ? CGAffineTransformMakeScale(chromeScale, chromeScale) : CGAffineTransformIdentity;
        self->_leadingChipView.transform = isPressed ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self->_trailingSearchView.transform = isPressed ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self.layer.shadowOpacity = 0.0f;
        self.layer.shadowRadius = 0.0f;
        self.layer.shadowPath = nil;
        self->_chromeView.alpha = isPressed ? 0.96 : 1.0;
    };

    if (!animated) {
        changes();
        return;
    }

    BOOL isPressed = focused || self.highlighted;
    [UIView animateWithDuration:isPressed ? 0.12 : 0.24
                          delay:0.0
         usingSpringWithDamping:isPressed ? 1.0 : 0.82
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_applyPalette];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTap = nil;
    _placeholderTransitionGeneration++;
    [_placeholderSettleAnimator stopAnimation:YES];
    _placeholderSettleAnimator = nil;
    [self pp_stopAmbientMotion];
    _chromeView.transform = CGAffineTransformIdentity;
    _chromeView.alpha = 1.0;
    _leadingChipView.transform = CGAffineTransformIdentity;
    _trailingSearchView.transform = CGAffineTransformIdentity;
    _trailingSearchIconView.transform = CGAffineTransformIdentity;
#if PPPSB_HAS_LOTTIE
    if (_leadingLottieView && [_leadingLottieSignature hasPrefix:@"loaded"]) {
        _leadingLottieView.loopAnimation = YES;
        _leadingLottieView.hidden = NO;
        _leadingLottieView.alpha = 1.0;
        _leadingIconView.alpha = 0.0;
    }
#endif
    _placeholderLabel.text = PPPSB_DefaultSmartSearchPlaceholderForWidth(CGRectGetWidth(self.bounds));
    _placeholderLabel.transform = CGAffineTransformIdentity;
    _placeholderLabel.alpha = 1.0;
    _signalRowView.alpha = 1.0;
    [self pp_applyPalette];
    if (self.window) {
        [self pp_startAmbientMotionIfNeeded];
        [self pp_updateLeadingFireLottiePlayback];
    }
}

@end
