//
//  PPHomeSearchBarCell.m
//  Pure Pets
//
//  Premium minimal search bar. One glass pill. One icon. One statement.
//  Quiet authority through restraint — no chips, no signals, no decoration.
//

#import "PPHomeSmartSearchTitleView.h"
#import "PPHomePresentationTokens.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static UISemanticContentAttribute PPSSB_CurrentSemantic(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static NSTextAlignment PPSSB_CurrentTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

static CGFloat const PPSSBExpandedChromeHeight = 48.0;
static CGFloat const PPSSBCollapsedChromeHeight = 40.0;
static CGFloat const PPSSBChromeCornerRadius = 24.0;
static CGFloat const PPSSBExpandedChipSide = 34.0;
static CGFloat const PPSSBCollapsedChipSide = 28.0;
static CGFloat const PPSSBExpandedSearchSide = 30.0;
static CGFloat const PPSSBCollapsedSearchSide = 26.0;
static CGFloat const PPSSBExpandedHorizontalInset = 7.0;
static CGFloat const PPSSBCollapsedHorizontalInset = 6.0;
static CGFloat const PPSSBExpandedTextGap = 10.0;
static CGFloat const PPSSBCollapsedTextGap = 8.0;
static CGFloat const PPSSBCompactWidthThreshold = 280.0;
static NSString * const PPSSBLeadingFireLottiePrimaryPath = @"LottieAnimations/Fire.json";
static NSString * const PPSSBLeadingFireLottieRootPath = @"Fire.json";

static CGFloat PPSSBInterpolate(CGFloat start, CGFloat end, CGFloat progress)
{
    return start + ((end - start) * PPHomeClamp(progress, 0.0, 1.0));
}

static UIFont *PPSSBScaledFont(UIFont *font,
                               UIFontTextStyle textStyle,
                               CGFloat maximumPointSize)
{
    UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:textStyle];
    return [metrics scaledFontForFont:font maximumPointSize:maximumPointSize];
}

@implementation PPHomeSmartSearchTitleView {
    UIView *_chromeView;
    UIButton *_glassChromeButton;
    UIVisualEffectView *_chromeBlurView;
    UIView *_chromeTintOverlay;
    UIView *_chromeSeparatorView;
    UIView *_leadingChipView;
    UIImageView *_leadingIconView;
#if __has_include(<Lottie/Lottie.h>) || __has_include("Lottie.h") || __has_include(<lottie-ios_Oc/Lottie.h>) || __has_include(<lottie_ios_Oc/Lottie.h>)
#define PPSSB_HAS_LOTTIE 1
#else
#define PPSSB_HAS_LOTTIE 0
#endif
#if PPSSB_HAS_LOTTIE
    LOTAnimationView *_leadingLottieView;
    NSString *_leadingLottieSignature;
#endif
    UIStackView *_textStackView;
    UIStackView *_signalRowView;
    UIView *_signalDotView;
    UILabel *_signalLabel;
    UILabel *_placeholderLabel;
    UIView *_trailingOrbView;
    UIImageView *_chevronView;
    BOOL _signalAnimationsConfigured;
    NSUInteger _placeholderColorIndex;
    UIColor *_currentCycleColor; // preserves the last cycling color across palette reloads
    CGFloat _collapseProgress;
    CGFloat _overscrollProgress;
    NSLayoutConstraint *_chromeHeightConstraint;
    NSLayoutConstraint *_leadingChipWidthConstraint;
    NSLayoutConstraint *_leadingChipHeightConstraint;
    NSLayoutConstraint *_trailingOrbWidthConstraint;
    NSLayoutConstraint *_trailingOrbHeightConstraint;
    NSLayoutConstraint *_leadingChipLeadingConstraint;
    NSLayoutConstraint *_textLeadingConstraint;
    NSLayoutConstraint *_textTrailingConstraint;
    NSLayoutConstraint *_trailingOrbTrailingConstraint;
}

@synthesize placeholderLabel = _placeholderLabel;

- (BOOL)pp_usesSystemGlassChrome
{
    return _glassChromeButton != nil;
}

- (void)pp_configureSystemGlassChromeIfNeeded
{
    if (!_glassChromeButton) {
        return;
    }

    if (@available(iOS 26.0, *)) {
        BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        UIColor *surfaceColor = PPHomeSemanticCardSurfaceColor() ?: UIColor.secondarySystemBackgroundColor;
        CGFloat surfaceAlpha = (isDark ? 0.28 : 0.42) + (0.10 * _collapseProgress);
        UIButtonConfiguration *configuration =
            [UIButtonConfiguration glassButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        configuration.baseForegroundColor = UIColor.clearColor;
        configuration.baseBackgroundColor = [surfaceColor colorWithAlphaComponent:surfaceAlpha];

        UIBackgroundConfiguration *background =
            configuration.background ?: [UIBackgroundConfiguration clearConfiguration];
        background.backgroundInsets = NSDirectionalEdgeInsetsZero;
        background.backgroundColor = UIColor.clearColor;
        configuration.background = background;

        _glassChromeButton.configuration = configuration;
    }
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, PPSSBExpandedChromeHeight);
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0.0 && isfinite(size.width) && size.width > 0.0) {
        width = size.width;
    }
    return CGSizeMake(MAX(width, 1.0), PPSSBExpandedChromeHeight);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    CGRect initialFrame = CGRectEqualToRect(frame, CGRectZero)
        ? CGRectMake(0.0, 0.0, 240.0, PPSSBExpandedChromeHeight)
        : frame;
    self = [super initWithFrame:initialFrame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPSSB_CurrentSemantic();
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSearchField;
    self.accessibilityLabel =
        kLang(@"home_nav_search_accessibility") ?:
        (kLang(@"home_search_hint") ?: @"Open smart search");
    self.accessibilityHint = kLang(@"home_search_hint") ?: @"What are you looking for?";
    self.clipsToBounds = NO;
    _showSmartPillBackground = NO;
    _collapseProgress = 0.0;
    _overscrollProgress = 0.0;

    [self pp_setShadowColor:[UIColor colorWithWhite:0.02 alpha:1.0]];
    self.layer.shadowOpacity = 0.0f;
    self.layer.shadowRadius = 12.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 4.0);

    UIView *chromeView = nil;
    if (@available(iOS 26.0, *)) {
        UIButton *glassButton = [UIButton buttonWithType:UIButtonTypeSystem];
        glassButton.backgroundColor = UIColor.clearColor;
        glassButton.userInteractionEnabled = NO;
        chromeView = glassButton;
        _glassChromeButton = glassButton;
        [self pp_configureSystemGlassChromeIfNeeded];
    } else {
        chromeView = [[UIView alloc] initWithFrame:self.bounds];
    }
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.backgroundColor = UIColor.clearColor;
    chromeView.userInteractionEnabled = NO;
    chromeView.layer.cornerRadius = PPSSBChromeCornerRadius;
    chromeView.layer.masksToBounds = !PPIOS26();
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:chromeView];
    _chromeView = chromeView;
    _chromeHeightConstraint = [chromeView.heightAnchor constraintEqualToConstant:PPSSBExpandedChromeHeight];

    if (![self pp_usesSystemGlassChrome]) {
        // Legacy frosted fallback for pre-iOS 26 runtimes.
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

        UIView *chromeTint = [[UIView alloc] init];
        chromeTint.translatesAutoresizingMaskIntoConstraints = NO;
        chromeTint.userInteractionEnabled = NO;
        chromeTint.backgroundColor = UIColor.clearColor;
        [chromeView insertSubview:chromeTint aboveSubview:blurView];
        _chromeTintOverlay = chromeTint;
        [NSLayoutConstraint activateConstraints:@[
            [chromeTint.topAnchor constraintEqualToAnchor:chromeView.topAnchor],
            [chromeTint.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor],
            [chromeTint.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor],
            [chromeTint.bottomAnchor constraintEqualToAnchor:chromeView.bottomAnchor],
        ]];
    }

    UIView *separatorView = [[UIView alloc] init];
    separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    separatorView.userInteractionEnabled = NO;
    separatorView.alpha = 0.0;
    [chromeView addSubview:separatorView];
    _chromeSeparatorView = separatorView;
    CGFloat hairlineHeight = 1.0 / UIScreen.mainScreen.scale;
    [NSLayoutConstraint activateConstraints:@[
        [separatorView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor constant:16.0],
        [separatorView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor constant:-16.0],
        [separatorView.bottomAnchor constraintEqualToAnchor:chromeView.bottomAnchor],
        [separatorView.heightAnchor constraintEqualToConstant:hairlineHeight],
    ]];

    UIView *leadingChipView = [UIView new];
    leadingChipView.translatesAutoresizingMaskIntoConstraints = NO;
    leadingChipView.userInteractionEnabled = NO;
    leadingChipView.layer.cornerRadius = 16.0;
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
    leadingIconView.alpha = 0.0; // Start hidden - only show as fallback
    leadingIconView.hidden = YES; // Start hidden - only show as fallback
    [leadingChipView addSubview:leadingIconView];
    _leadingIconView = leadingIconView;

#if PPSSB_HAS_LOTTIE
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
    signalLabel.textAlignment = PPSSB_CurrentTextAlignment();
    signalLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    signalLabel.adjustsFontSizeToFitWidth = YES;
    signalLabel.minimumScaleFactor = 0.84;
    signalLabel.numberOfLines = 1;
    signalLabel.adjustsFontForContentSizeCategory = YES;
    signalLabel.userInteractionEnabled = NO;
    signalLabel.text = kLang(@"home_nav_search_trending") ?: @"Trending";
    [signalRowView addArrangedSubview:signalLabel];
    _signalLabel = signalLabel;

    UILabel *placeholderLabel = [UILabel new];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    placeholderLabel.textAlignment = PPSSB_CurrentTextAlignment();
    placeholderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    placeholderLabel.adjustsFontSizeToFitWidth = YES;
    placeholderLabel.allowsDefaultTighteningForTruncation = YES;
    placeholderLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    placeholderLabel.minimumScaleFactor = 0.82;
    placeholderLabel.numberOfLines = 1;
    placeholderLabel.adjustsFontForContentSizeCategory = YES;
    placeholderLabel.userInteractionEnabled = NO;
    placeholderLabel.text = kLang(@"home_nav_search_example_cats") ?: @"Cats for sale";
    [textStackView addArrangedSubview:placeholderLabel];
    _placeholderLabel = placeholderLabel;

    UIView *trailingOrbView = [UIView new];
    trailingOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    trailingOrbView.userInteractionEnabled = NO;
    trailingOrbView.layer.cornerRadius = 12.0;
    trailingOrbView.layer.masksToBounds = YES;
    trailingOrbView.backgroundColor = UIColor.clearColor;
    trailingOrbView.layer.borderWidth = 0.0f;
    if (@available(iOS 13.0, *)) {
        trailingOrbView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [chromeView addSubview:trailingOrbView];
    _trailingOrbView = trailingOrbView;

    UIImageView *chevronView =
    [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"magnifyingglass"
                                                         pointSize:16.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                                      makeTemplate:YES]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    chevronView.userInteractionEnabled = NO;
    chevronView.backgroundColor = UIColor.clearColor;
    [trailingOrbView addSubview:chevronView];
    _chevronView = chevronView;

    _leadingChipWidthConstraint = [leadingChipView.widthAnchor constraintEqualToConstant:PPSSBExpandedChipSide];
    _leadingChipHeightConstraint = [leadingChipView.heightAnchor constraintEqualToConstant:PPSSBExpandedChipSide];
    _trailingOrbWidthConstraint = [trailingOrbView.widthAnchor constraintEqualToConstant:PPSSBExpandedSearchSide];
    _trailingOrbHeightConstraint = [trailingOrbView.heightAnchor constraintEqualToConstant:PPSSBExpandedSearchSide];
    _leadingChipLeadingConstraint =
        [leadingChipView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor
                                                      constant:PPSSBExpandedHorizontalInset];
    _textLeadingConstraint =
        [textStackView.leadingAnchor constraintEqualToAnchor:leadingChipView.trailingAnchor
                                                    constant:PPSSBExpandedTextGap];
    _textTrailingConstraint =
        [textStackView.trailingAnchor constraintEqualToAnchor:trailingOrbView.leadingAnchor
                                                     constant:-PPSSBExpandedTextGap];
    _trailingOrbTrailingConstraint =
        [trailingOrbView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor
                                                       constant:-PPSSBExpandedHorizontalInset];

    [NSLayoutConstraint activateConstraints:@[
        [chromeView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [chromeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [chromeView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        _chromeHeightConstraint,

        _leadingChipLeadingConstraint,
        [leadingChipView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        _leadingChipWidthConstraint,
        _leadingChipHeightConstraint,

        [leadingIconView.centerXAnchor constraintEqualToAnchor:leadingChipView.centerXAnchor],
        [leadingIconView.centerYAnchor constraintEqualToAnchor:leadingChipView.centerYAnchor],
        [leadingIconView.widthAnchor constraintEqualToConstant:14.0],
        [leadingIconView.heightAnchor constraintEqualToConstant:14.0],

        [signalDotView.widthAnchor constraintEqualToConstant:5.5],
        [signalDotView.heightAnchor constraintEqualToConstant:5.5],

        _textLeadingConstraint,
        [textStackView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [textStackView.topAnchor constraintGreaterThanOrEqualToAnchor:chromeView.topAnchor constant:6.5],
        [textStackView.bottomAnchor constraintLessThanOrEqualToAnchor:chromeView.bottomAnchor constant:-6.5],
        _textTrailingConstraint,

        _trailingOrbTrailingConstraint,
        [trailingOrbView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        _trailingOrbWidthConstraint,
        _trailingOrbHeightConstraint,

        [chevronView.centerXAnchor constraintEqualToAnchor:trailingOrbView.centerXAnchor],
        [chevronView.centerYAnchor constraintEqualToAnchor:trailingOrbView.centerYAnchor],
        [chevronView.widthAnchor constraintEqualToConstant:17.0],
        [chevronView.heightAnchor constraintEqualToConstant:17.0]
    ]];

    [_placeholderLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [_signalLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                  forAxis:UILayoutConstraintAxisHorizontal];
    [_trailingOrbView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];

    [self pp_applyPalette];
    [self pp_updateInteractiveStateAnimated:YES];
    [self pp_loadLeadingFireLottie];

    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!self.userInteractionEnabled || self.hidden || self.alpha < 0.01) {
        return nil;
    }

    CGRect hitFrame = CGRectInset(self.bounds, -6.0, -6.0);
    if (CGRectContainsPoint(hitFrame, point)) {
        return self;
    }

    return nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.semanticContentAttribute = PPSSB_CurrentSemantic();
    _signalLabel.textAlignment = PPSSB_CurrentTextAlignment();
    _placeholderLabel.textAlignment = PPSSB_CurrentTextAlignment();

    CGFloat width = CGRectGetWidth(self.bounds);
    BOOL compact = width < PPSSBCompactWidthThreshold;
    BOOL accessibilityText =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    _signalRowView.hidden = accessibilityText;
    CGFloat secondaryVisibility = accessibilityText ? 0.0 : pow(1.0 - _collapseProgress, 1.35);
    _signalRowView.alpha = (compact ? 0.90 : 1.0) * secondaryVisibility;
    _textStackView.spacing = (compact ? 0.0 : 1.0) * secondaryVisibility;
    UIFont *signalFont = compact
        ? ([GM MidFontWithSize:8.0] ?: [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold])
        : ([GM MidFontWithSize:9.0] ?: [UIFont systemFontOfSize:9.0 weight:UIFontWeightSemibold]);
    UIFont *placeholderFont = compact
        ? ([GM boldFontWithSize:12.75] ?: [UIFont systemFontOfSize:12.75 weight:UIFontWeightSemibold])
        : ([GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold]);
    _signalLabel.font = PPSSBScaledFont(signalFont, UIFontTextStyleCaption2, 12.0);
    _placeholderLabel.font =
        PPSSBScaledFont(placeholderFont, UIFontTextStyleSubheadline, accessibilityText ? 18.0 : 16.0);
    if (@available(iOS 26.0, *)) {
        CGFloat chromeHeight = CGRectGetHeight(_chromeView.bounds);
        CGFloat expandedRadius = chromeHeight > 0.0 ? chromeHeight * 0.5 : PPSSBChromeCornerRadius;
        _chromeView.layer.cornerRadius =
            expandedRadius + (((PPSSBCollapsedChromeHeight * 0.5) - expandedRadius) * _collapseProgress);
        [self pp_configureSystemGlassChromeIfNeeded];
    } else {
        _chromeView.layer.cornerRadius =
            PPSSBChromeCornerRadius +
            (((PPSSBCollapsedChromeHeight * 0.5) - PPSSBChromeCornerRadius) * _collapseProgress);
    }
    _leadingChipView.layer.cornerRadius =
        MAX(12.0, MIN(_leadingChipHeightConstraint.constant, _leadingChipWidthConstraint.constant) * 0.5);
    _trailingOrbView.layer.cornerRadius =
        MAX(11.0, MIN(_trailingOrbHeightConstraint.constant, _trailingOrbWidthConstraint.constant) * 0.5);
    _signalDotView.layer.cornerRadius = 2.75;
    [self pp_updateChromeShadowPath];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window) {
        [_signalDotView.layer removeAnimationForKey:@"pp.home.premiumSearch.signalPulse"];
        _signalAnimationsConfigured = NO;
        return;
    }

    [_signalDotView.layer removeAnimationForKey:@"pp.home.premiumSearch.signalPulse"];
    _signalAnimationsConfigured = NO;
    [self pp_updateLeadingFireLottiePlayback];
}

- (UIColor *)pp_nextPlaceholderColor
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    NSArray<UIColor *> *palette = @[
        UIColor.labelColor,
        AppPrimaryClr ?: UIColor.systemPinkColor,
    ];
    UIColor *base = palette[_placeholderColorIndex % palette.count];
    _placeholderColorIndex = (_placeholderColorIndex + 1) % palette.count;
    return isDark ? [base colorWithAlphaComponent:0.96] : [base colorWithAlphaComponent:0.88];
}


- (void)setQueryText:(NSString *)text animated:(BOOL)animated
{
    NSString *safeText = PPSafeString(text);
    if (safeText.length == 0) {
        safeText = kLang(@"home_nav_search_example_cats") ?: @"Cats for sale";
    }
    if ([_placeholderLabel.text isEqualToString:safeText]) {
        return;
    }

    UIColor *nextColor = [self pp_nextPlaceholderColor];
    _currentCycleColor = nextColor;
    self.accessibilityValue = safeText;

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        _placeholderLabel.text = safeText;
        _placeholderLabel.textColor = nextColor;
        return;
    }

    [UIView animateWithDuration:PPHomeAnimationDurationFast
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_placeholderLabel.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        self->_placeholderLabel.text = safeText;
        self->_placeholderLabel.textColor = nextColor;
        [UIView animateWithDuration:PPHomeAnimationDurationNormal
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self->_placeholderLabel.alpha = 1.0;
        } completion:nil];
    }];
}

- (void)setCollapseProgress:(CGFloat)collapseProgress
         overscrollProgress:(CGFloat)overscrollProgress
                   animated:(BOOL)animated
{
    CGFloat collapse = PPHomeClamp(collapseProgress, 0.0, 1.0);
    CGFloat overscroll = PPHomeClamp(overscrollProgress, 0.0, 1.0);
    if (UIAccessibilityIsReduceMotionEnabled()) {
        overscroll = 0.0;
    }
    if (fabs(_collapseProgress - collapse) < 0.001 &&
        fabs(_overscrollProgress - overscroll) < 0.001) {
        return;
    }

    _collapseProgress = collapse;
    _overscrollProgress = overscroll;

    void (^updates)(void) = ^{
        CGFloat chromeHeight = PPSSBInterpolate(PPSSBExpandedChromeHeight,
                                                PPSSBCollapsedChromeHeight,
                                                collapse);
        CGFloat chipSide = PPSSBInterpolate(PPSSBExpandedChipSide,
                                            PPSSBCollapsedChipSide,
                                            collapse);
        CGFloat searchSide = PPSSBInterpolate(PPSSBExpandedSearchSide,
                                              PPSSBCollapsedSearchSide,
                                              collapse);
        self->_chromeHeightConstraint.constant = chromeHeight;
        self->_leadingChipWidthConstraint.constant = chipSide;
        self->_leadingChipHeightConstraint.constant = chipSide;
        self->_trailingOrbWidthConstraint.constant = searchSide;
        self->_trailingOrbHeightConstraint.constant = searchSide;
        self->_leadingChipLeadingConstraint.constant =
            PPSSBInterpolate(PPSSBExpandedHorizontalInset, PPSSBCollapsedHorizontalInset, collapse);
        self->_trailingOrbTrailingConstraint.constant =
            -PPSSBInterpolate(PPSSBExpandedHorizontalInset, PPSSBCollapsedHorizontalInset, collapse);
        CGFloat textGap = PPSSBInterpolate(PPSSBExpandedTextGap, PPSSBCollapsedTextGap, collapse);
        self->_textLeadingConstraint.constant = textGap;
        self->_textTrailingConstraint.constant = -textGap;

        BOOL compact = CGRectGetWidth(self.bounds) < PPSSBCompactWidthThreshold;
        CGFloat secondaryVisibility = pow(1.0 - collapse, 1.35);
        self->_signalRowView.alpha = secondaryVisibility * (compact ? 0.90 : 1.0);
        self->_signalRowView.transform =
            CGAffineTransformMakeTranslation(0.0, -2.0 * collapse);
        self->_textStackView.transform = CGAffineTransformMakeTranslation(0.0, -3.0 * collapse);
        self->_leadingChipView.alpha = 1.0 - (0.06 * collapse);
        self->_trailingOrbView.alpha = 0.94 + (0.06 * collapse);
        [self pp_applyPalette];
        [self pp_updateInteractiveStateAnimated:NO];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
    } else {
        [UIView animateWithDuration:PPHomeAnimationDurationNormal
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.2
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:updates
                         completion:nil];
    }
    [self pp_updateLeadingFireLottiePlayback];
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    // Nav-bar scroll-edge transitions can propagate tint updates while scrolling.
    // Reapplying the steady home-search palette keeps the title view colors locked.
    [self pp_applyPalette];
}
/*
 - (void)setHighlighted:(BOOL)highlighted
 {
     [super setHighlighted:highlighted];
     [self pp_updateInteractiveStateAnimated:YES];
 }

 */
- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self pp_updateInteractiveStateAnimated:YES];
}

- (void)pp_updateChromeShadowPath
{
    if (!_chromeView || CGRectIsEmpty(_chromeView.frame)) {
        self.layer.shadowPath = nil;
        return;
    }

    CGFloat radius = MAX(0.0, _chromeView.layer.cornerRadius);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:_chromeView.frame
                                                    cornerRadius:radius];
    self.layer.shadowPath = path.CGPath;
}

- (void)pp_applyShadowForPressedState:(BOOL)isPressed
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *shadowColor = isDark
        ? [UIColor blackColor]
        : [UIColor colorWithWhite:0.08 alpha:1.0];
    [self pp_setShadowColor:shadowColor];

    CGFloat restingOpacity = (isDark ? 0.18 : 0.07) + (0.05 * _collapseProgress);
    self.layer.shadowOpacity = isPressed ? (isDark ? 0.10f : 0.045f) : (float)restingOpacity;
    self.layer.shadowRadius = PPSSBInterpolate(12.0, 16.0, _collapseProgress);
    self.layer.shadowOffset = CGSizeMake(0.0, PPSSBInterpolate(4.0, 7.0, _collapseProgress));
    [self pp_updateChromeShadowPath];
}

- (void)pp_applyPalette
{
    UIColor *textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *accentColor = AppPrimaryClr ?: AppPrimaryClrShiner ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
    UIColor *surfaceColor = PPHomeSemanticCardSurfaceColor() ?: (AppForgroundColr ?: [UIColor secondarySystemBackgroundColor]);
    UIColor *separatorColor = PPHomeSemanticHairlineColor() ?: UIColor.separatorColor;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL usesSystemGlassChrome = [self pp_usesSystemGlassChrome];
    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();

    _chromeView.backgroundColor = UIColor.clearColor;
    if (usesSystemGlassChrome) {
        [self pp_configureSystemGlassChromeIfNeeded];
        _chromeView.layer.borderWidth = 0.0f;
        [_chromeView pp_setBorderColor:UIColor.clearColor];
        _chromeBlurView.alpha = 0.0;
        _chromeTintOverlay.backgroundColor = UIColor.clearColor;
    } else {
        _chromeBlurView.alpha = reduceTransparency ? 0.0 : 1.0;

        UIBlurEffectStyle blurStyle = isDark
            ? UIBlurEffectStyleSystemMaterialDark
            : UIBlurEffectStyleSystemMaterialLight;
        _chromeBlurView.effect = [UIBlurEffect effectWithStyle:blurStyle];

        CGFloat tintAlpha = reduceTransparency
            ? 1.0
            : ((isDark ? 0.36 : 0.50) + (0.14 * _collapseProgress));
        _chromeTintOverlay.backgroundColor = [surfaceColor colorWithAlphaComponent:tintAlpha];
        _chromeView.layer.borderWidth = isDark ? 0.72f : 0.64f;
        [_chromeView pp_setBorderColor:[separatorColor colorWithAlphaComponent:isDark ? 0.38 : 0.30]];
    }

    UIColor *chipColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    _leadingChipView.backgroundColor =
        [chipColor colorWithAlphaComponent:(isDark ? 0.15 : 0.10) + (0.03 * _collapseProgress)];
    _leadingChipView.layer.borderWidth = 0.0f;
    [_leadingChipView pp_setBorderColor:UIColor.clearColor];
    _leadingIconView.tintColor = accentColor;

    _signalDotView.backgroundColor = AppSecondaryTextClr ?: accentColor;
    _signalLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.72 : 0.58];
    // Preserve active cycle color; only fall back to default before the first rotation fires
    _placeholderLabel.textColor = _currentCycleColor
        ?: [textColor colorWithAlphaComponent:isDark ? 0.96 : 0.90];

    _trailingOrbView.backgroundColor =
        [textColor colorWithAlphaComponent:(isDark ? 0.055 : 0.035) + (0.025 * _collapseProgress)];
    _trailingOrbView.layer.borderWidth = 0.0f;
    _chevronView.tintColor = [textColor colorWithAlphaComponent:isDark ? 0.82 : 0.60];
    _chromeSeparatorView.backgroundColor =
        [separatorColor colorWithAlphaComponent:isDark ? 0.56 : 0.42];
    _chromeSeparatorView.alpha = 0.04 + (0.32 * _collapseProgress);

}

- (void)pp_updateInteractiveStateAnimated:(BOOL)animated
{
    void (^changes)(void) = ^{
        BOOL isPressed = self.highlighted;
        BOOL usesSystemGlassChrome = [self pp_usesSystemGlassChrome];
        CGFloat pressedScale = isPressed ? (usesSystemGlassChrome ? 0.992 : 0.988) : 1.0;
        CGFloat stretchScale = 1.0 + (0.03 * self->_overscrollProgress);
        self->_chromeView.transform =
            CGAffineTransformMakeScale(pressedScale * stretchScale, pressedScale * stretchScale);
        CGFloat leadingScale = (1.0 - (0.08 * self->_collapseProgress)) * (isPressed ? 0.96 : 1.0);
        self->_leadingChipView.transform = CGAffineTransformMakeScale(leadingScale, leadingScale);
        self->_trailingOrbView.transform = isPressed ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self->_chromeView.alpha = isPressed ? 0.96 : 1.0;
        [self pp_applyShadowForPressedState:isPressed];
    };

    if (!animated) {
        changes();
        return;
    }

    BOOL isPressed = self.highlighted;
    [UIView animateWithDuration:isPressed ? 0.12 : 0.24
                          delay:0.0
         usingSpringWithDamping:isPressed ? 1.0 : 0.82
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:nil];
}

- (void)setShowSmartPillBackground:(BOOL)showSmartPillBackground
{
    if (_showSmartPillBackground == showSmartPillBackground) return;
    _showSmartPillBackground = showSmartPillBackground;
    [self pp_applySmartPillBackgroundVisibility];
}

- (void)pp_applySmartPillBackgroundVisibility
{
    [self pp_applyPalette];
    [self pp_updateInteractiveStateAnimated:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL colorChanged =
        [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
    BOOL contentSizeChanged =
        previousTraitCollection &&
        ![self.traitCollection.preferredContentSizeCategory
            isEqualToString:previousTraitCollection.preferredContentSizeCategory];
    if (colorChanged || contentSizeChanged) {
        [self pp_applyPalette];
        [self setNeedsLayout];
    }
}

- (void)pp_loadLeadingFireLottie
{
#if PPSSB_HAS_LOTTIE
    if (!_leadingLottieView) {
        return;
    }
    if ([_leadingLottieSignature hasPrefix:@"loaded"]) {
        _leadingLottieView.hidden = NO;
        _leadingLottieView.alpha = 1.0;
        _leadingIconView.alpha = 0.0;
        _leadingIconView.hidden = YES;
        [self pp_updateLeadingFireLottiePlayback];
        return;
    }
    if ([_leadingLottieSignature isEqualToString:@"loading"]) {
        return;
    }

    _leadingLottieSignature = @"loading";
    [self pp_fetchLeadingFireLottieAtStoragePath:PPSSBLeadingFireLottiePrimaryPath fallbackToRoot:YES];
#endif
}

- (void)pp_fetchLeadingFireLottieAtStoragePath:(NSString *)storagePath fallbackToRoot:(BOOL)fallbackToRoot
{
#if PPSSB_HAS_LOTTIE
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
                    [self pp_fetchLeadingFireLottieAtStoragePath:PPSSBLeadingFireLottieRootPath fallbackToRoot:NO];
                    return;
                }
                self->_leadingLottieSignature = nil;
                self->_leadingIconView.alpha = 1.0;
                self->_leadingIconView.hidden = NO; // Show flame icon as fallback
                self->_leadingLottieView.hidden = YES; // Hide Lottie view
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                if (fallbackToRoot) {
                    [self pp_fetchLeadingFireLottieAtStoragePath:PPSSBLeadingFireLottieRootPath fallbackToRoot:NO];
                    return;
                }
                self->_leadingLottieSignature = nil;
                self->_leadingIconView.alpha = 1.0;
                self->_leadingIconView.hidden = NO; // Show flame icon as fallback
                self->_leadingLottieView.hidden = YES; // Hide Lottie view
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
            self->_leadingIconView.hidden = YES; // Keep flame icon hidden when Lottie loads

            [self pp_updateLeadingFireLottiePlayback];
        });
    }];
#endif
}

- (void)pp_stopLeadingFireLottie
{
#if PPSSB_HAS_LOTTIE
    [_leadingLottieView stop];
#endif
}

- (void)pp_updateLeadingFireLottiePlayback
{
#if PPSSB_HAS_LOTTIE
    if (!_leadingLottieView || _leadingLottieView.hidden || ![_leadingLottieSignature hasPrefix:@"loaded"]) {
        return;
    }

    if (!self.window || UIAccessibilityIsReduceMotionEnabled() || _collapseProgress > 0.18) {
        [_leadingLottieView stop];
        _leadingLottieView.animationProgress = 0.42;
        return;
    }

    if (!_leadingLottieView.isAnimationPlaying) {
        [_leadingLottieView play];
    }
#endif
}

- (void)configureWithTrendingQuery:(nullable NSString *)query
{
    NSString *safeQuery = PPSafeString(query);
    if (safeQuery.length == 0) {
        safeQuery = kLang(@"home_nav_search_example_cats") ?: @"Cats for sale";
    }
    [self setQueryText:safeQuery animated:YES];
}



@end
