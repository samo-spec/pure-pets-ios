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

static UISemanticContentAttribute PPSSB_CurrentSemantic(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static NSTextAlignment PPSSB_CurrentTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

static CGFloat const PPSSBChromeCornerRadius = 22.0;
static CGFloat const PPSSBCompactWidthThreshold = 280.0;
static NSString * const PPSSBLeadingFireLottiePrimaryPath = @"LottieAnimations/Fire.json";
static NSString * const PPSSBLeadingFireLottieRootPath = @"Fire.json";

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
}

@synthesize placeholderLabel = _placeholderLabel;

- (BOOL)pp_usesSystemGlassChrome
{
    return _glassChromeButton != nil;
}

- (void)pp_configureSystemGlassChromeIfNeeded
{
    if (!_glassChromeButton) {
        //return;
    }

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration =
            [UIButtonConfiguration glassButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        configuration.baseForegroundColor = UIColor.clearColor;
        configuration.baseBackgroundColor = UIColor.clearColor;

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
    return CGSizeMake(UIViewNoIntrinsicMetric, 46.0);
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0.0 && isfinite(size.width) && size.width > 0.0) {
        width = size.width;
    }
    return CGSizeMake(MAX(width, 1.0), 46.0);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    CGRect initialFrame = CGRectEqualToRect(frame, CGRectZero)
        ? CGRectMake(0.0, 0.0, 240.0, 46.0)
        : frame;
    self = [super initWithFrame:initialFrame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPSSB_CurrentSemantic();
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel =
        kLang(@"home_nav_search_accessibility") ?:
        (kLang(@"home_search_hint") ?: @"Open smart search");
    self.accessibilityHint = kLang(@"home_search_hint") ?: @"What are you looking for?";
    self.clipsToBounds = NO;
    _showSmartPillBackground = NO;
    _collapseProgress = 0.0;
    _overscrollProgress = 0.0;

    [self pp_setShadowColor:[UIColor colorWithWhite:0.02 alpha:0.7]];
    self.layer.shadowOpacity = 0.0f;
    self.layer.shadowRadius = 0.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 0.0);

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
    _chromeHeightConstraint = [chromeView.heightAnchor constraintEqualToConstant:46.0];

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

    _leadingChipWidthConstraint = [leadingChipView.widthAnchor constraintEqualToConstant:32.0];
    _leadingChipHeightConstraint = [leadingChipView.heightAnchor constraintEqualToConstant:32.0];
    _trailingOrbWidthConstraint = [trailingOrbView.widthAnchor constraintEqualToConstant:26.0];
    _trailingOrbHeightConstraint = [trailingOrbView.heightAnchor constraintEqualToConstant:26.0];

    [NSLayoutConstraint activateConstraints:@[
        [chromeView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [chromeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [chromeView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        _chromeHeightConstraint,

        [leadingChipView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor constant:7.0],
        [leadingChipView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        _leadingChipWidthConstraint,
        _leadingChipHeightConstraint,

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
        [textStackView.trailingAnchor constraintEqualToAnchor:trailingOrbView.leadingAnchor constant:-10.0],

        [trailingOrbView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor constant:-7.0],
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
    CGFloat width = CGRectGetWidth(self.bounds);
    BOOL compact = width < PPSSBCompactWidthThreshold;
    BOOL accessibilityText =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    _signalRowView.hidden = accessibilityText;
    _signalRowView.alpha = (compact ? 0.92 : 1.0) * (1.0 - _collapseProgress);
    _textStackView.spacing = (compact ? 0.0 : 0.5) * (1.0 - _collapseProgress);
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
            expandedRadius + ((PPHomeControlCornerRadius - expandedRadius) * _collapseProgress);
        [self pp_configureSystemGlassChromeIfNeeded];
    } else {
        _chromeView.layer.cornerRadius =
            PPSSBChromeCornerRadius +
            ((PPHomeControlCornerRadius - PPSSBChromeCornerRadius) * _collapseProgress);
    }
    _leadingChipView.layer.cornerRadius = 16.0 - (3.0 * _collapseProgress);
    _trailingOrbView.layer.cornerRadius = 13.0;
    _signalDotView.layer.cornerRadius = 2.75;
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
        AppPrimaryClr ?: UIColor.systemPinkColor,
        UIColor.labelColor,
        UIColor.systemTealColor,
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
        self->_chromeHeightConstraint.constant = 46.0 - (6.0 * collapse);
        self->_leadingChipWidthConstraint.constant = 32.0 - (4.0 * collapse);
        self->_leadingChipHeightConstraint.constant = 32.0 - (4.0 * collapse);
        self->_trailingOrbWidthConstraint.constant = 26.0 - (2.0 * collapse);
        self->_trailingOrbHeightConstraint.constant = 26.0 - (2.0 * collapse);
        self->_signalRowView.alpha = (1.0 - collapse) *
            (CGRectGetWidth(self.bounds) < PPSSBCompactWidthThreshold ? 0.92 : 1.0);
        self->_signalRowView.transform =
            CGAffineTransformMakeScale(1.0 - (0.04 * collapse), 1.0 - (0.04 * collapse));
        self->_textStackView.transform = CGAffineTransformMakeTranslation(0.0, -3.5 * collapse);
        self->_leadingChipView.alpha = 1.0 - (0.10 * collapse);
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
- (void)pp_applyPalette
{
    UIColor *textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *accentColor = AppPrimaryClr ?: AppPrimaryClrShiner ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
    UIColor *surfaceColor = AppForgroundColr ?: [UIColor secondarySystemBackgroundColor];
    UIColor *liquidBorderColor = AppForgroundColr ?: surfaceColor;
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
            ? UIBlurEffectStyleSystemThinMaterialDark
            : UIBlurEffectStyleSystemThinMaterialLight;
        _chromeBlurView.effect = [UIBlurEffect effectWithStyle:blurStyle];

        CGFloat tintAlpha = reduceTransparency
            ? 1.0
            : ((isDark ? 0.28 : 0.14) + (0.14 * _collapseProgress));
        _chromeTintOverlay.backgroundColor = [surfaceColor colorWithAlphaComponent:tintAlpha];
        _chromeView.layer.borderWidth = isDark ? 0.78f : 0.92f;
        [_chromeView pp_setBorderColor:[liquidBorderColor colorWithAlphaComponent:isDark ? 0.30 : 0.58]];
    }

    _leadingChipView.backgroundColor =
    [AppForgroundColr colorWithAlphaComponent:isDark ? 0.24 : 0.12];
    _leadingChipView.layer.borderWidth = 0.0f;
    [_leadingChipView pp_setBorderColor:[AppBackgroundClr colorWithAlphaComponent:isDark ? 0.22 : 1.0]];
    _leadingIconView.tintColor = AppForgroundColr;

    _signalDotView.backgroundColor = AppSecondaryTextClr ?: accentColor;
    _signalLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.72 : 0.58];
    // Preserve active cycle color; only fall back to default before the first rotation fires
    _placeholderLabel.textColor = _currentCycleColor
        ?: [textColor colorWithAlphaComponent:isDark ? 0.96 : 0.90];

    _trailingOrbView.backgroundColor = UIColor.clearColor;
    _trailingOrbView.layer.borderWidth = 0.0f;
    _chevronView.tintColor = [textColor colorWithAlphaComponent:isDark ? 0.74 : 0.54];

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
        self.layer.shadowOpacity = 0.0f;
        self.layer.shadowRadius = 0.0f;
        self.layer.shadowPath = nil;
        self->_chromeView.alpha = isPressed ? 0.96 : 1.0;
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
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_applyPalette];
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
