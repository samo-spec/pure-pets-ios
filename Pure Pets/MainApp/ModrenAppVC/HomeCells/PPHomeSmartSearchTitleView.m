//
//  PPHomeSearchBarCell.m
//  Pure Pets
//
//  Premium minimal search bar. One glass pill. One icon. One statement.
//  Quiet authority through restraint — no chips, no signals, no decoration.
//

#import "PPHomeSearchBarCell.h"
#import <QuartzCore/QuartzCore.h>

@implementation PPHomeSmartSearchTitleView {
    UIView *_chromeView;
    UIButton *_glassChromeButton;
    UIVisualEffectView *_chromeBlurView;
    UIView *_chromeTintOverlay;
    UIView *_leadingChipView;
    UIImageView *_leadingIconView;
    UIStackView *_textStackView;
    UIStackView *_signalRowView;
    UIView *_signalDotView;
    UILabel *_signalLabel;
    UILabel *_placeholderLabel;
    UIView *_trailingOrbView;
    UIImageView *_chevronView;
    BOOL _signalAnimationsConfigured;
    NSUInteger _placeholderColorIndex;
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
        UIColor *liquidBorderColor = AppForgroundColr ?: UIColor.whiteColor;
        UIButtonConfiguration *configuration =
            [UIButtonConfiguration clearGlassButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        configuration.baseForegroundColor = UIColor.clearColor;

        UIBackgroundConfiguration *background =
            configuration.background ?: [UIBackgroundConfiguration clearConfiguration];
        background.backgroundInsets = NSDirectionalEdgeInsetsZero;
        background.backgroundColor = UIColor.clearColor;
        background.strokeColor = [liquidBorderColor colorWithAlphaComponent:isDark ? 0.34 : 0.68];
        background.strokeWidth = 0.9;
        background.visualEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleClear];
        background.cornerRadius = CGRectGetHeight(self.bounds) > 0.0 ? CGRectGetHeight(self.bounds) * 0.5 : 21.0;
        configuration.background = background;

        _glassChromeButton.configuration = configuration;
    }
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 44.0);
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0.0 && isfinite(size.width) && size.width > 0.0) {
        width = size.width;
    }
    return CGSizeMake(MAX(width, 1.0), 44.0);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    CGRect initialFrame = CGRectEqualToRect(frame, CGRectZero)
        ? CGRectMake(0.0, 0.0, 240.0, 44.0)
        : frame;
    self = [super initWithFrame:initialFrame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel =
        kLang(@"home_nav_search_accessibility") ?:
        (kLang(@"home_search_hint") ?: @"Open smart search");
    self.accessibilityHint = kLang(@"home_search_hint") ?: @"What are you looking for?";
    self.clipsToBounds = NO;
    _showSmartPillBackground = NO;

    [self pp_setShadowColor:[UIColor colorWithWhite:0.02 alpha:1.0]];
    self.layer.shadowOpacity = 0.0f;
    self.layer.shadowRadius = 0.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 8.0);

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
    chromeView.layer.cornerRadius = 21.0;
    chromeView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:chromeView];
    _chromeView = chromeView;
    [chromeView.heightAnchor constraintEqualToConstant:44.0].active = YES;

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
    leadingChipView.layer.cornerRadius = 14.0;
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
    [leadingChipView addSubview:leadingIconView];
    _leadingIconView = leadingIconView;

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
    signalLabel.textAlignment = PPHomeCurrentTextAlignment();
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
    placeholderLabel.textAlignment = PPHomeCurrentTextAlignment();
    placeholderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    placeholderLabel.adjustsFontSizeToFitWidth = YES;
    placeholderLabel.allowsDefaultTighteningForTruncation = YES;
    placeholderLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    placeholderLabel.minimumScaleFactor = 0.82;
    placeholderLabel.numberOfLines = 1;
    placeholderLabel.userInteractionEnabled = NO;
    placeholderLabel.text = kLang(@"home_nav_search_example_cats") ?: @"Cats for sale";
    [textStackView addArrangedSubview:placeholderLabel];
    _placeholderLabel = placeholderLabel;

    UIView *trailingOrbView = [UIView new];
    trailingOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    trailingOrbView.userInteractionEnabled = NO;
    trailingOrbView.layer.cornerRadius = 12.0;
    trailingOrbView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        trailingOrbView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [chromeView addSubview:trailingOrbView];
    _trailingOrbView = trailingOrbView;

        NSString *forwardChevron = Language.isRTL ? @"chevron.left" : @"chevron.right";
    UIImageView *chevronView =
    [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:forwardChevron
                                                         pointSize:11
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                                      makeTemplate:YES]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    chevronView.userInteractionEnabled = NO;
    //chevronView.
    chevronView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.0];
    [trailingOrbView addSubview:chevronView];
    _chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [chromeView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [chromeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [chromeView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [chromeView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [leadingChipView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor constant:7.0],
        [leadingChipView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [leadingChipView.widthAnchor constraintEqualToConstant:28.0],
        [leadingChipView.heightAnchor constraintEqualToConstant:28.0],

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
        [trailingOrbView.widthAnchor constraintEqualToConstant:24.0],
        [trailingOrbView.heightAnchor constraintEqualToConstant:24.0],

        [chevronView.centerXAnchor constraintEqualToAnchor:trailingOrbView.centerXAnchor],
        [chevronView.centerYAnchor constraintEqualToAnchor:trailingOrbView.centerYAnchor],
        [chevronView.widthAnchor constraintEqualToConstant:14.0],
        [chevronView.heightAnchor constraintEqualToConstant:14.0]
    ]];

    [_placeholderLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [_signalLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                  forAxis:UILayoutConstraintAxisHorizontal];
    [_trailingOrbView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];

    [self pp_applyPalette];
    [self pp_updateInteractiveStateAnimated:YES];

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
    BOOL compact = width < 280.0;
    _signalRowView.hidden = compact;
    _textStackView.spacing = compact ? 0.0 : 0.5;
    _signalLabel.font = compact
        ? ([GM MidFontWithSize:8.0] ?: [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold])
        : ([GM MidFontWithSize:9.0] ?: [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold]);
    _placeholderLabel.font = compact
        ? ([GM boldFontWithSize:12.75] ?: [UIFont systemFontOfSize:12.75 weight:UIFontWeightSemibold])
        : ([GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold]);
    _chromeView.layer.cornerRadius = CGRectGetHeight(self.bounds) * 0.5;
    _leadingChipView.layer.cornerRadius = CGRectGetHeight(_leadingChipView.bounds) * 0.5;
    _trailingOrbView.layer.cornerRadius = CGRectGetHeight(_trailingOrbView.bounds) * 0.5;
    _signalDotView.layer.cornerRadius = CGRectGetHeight(_signalDotView.bounds) * 0.5;
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                   cornerRadius:CGRectGetHeight(self.bounds) * 0.5].CGPath;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window) {
        [_signalDotView.layer removeAnimationForKey:@"pp.home.smartSearch.signalPulse"];
        _signalAnimationsConfigured = NO;
        return;
    }

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
    signalPulse.duration = 1.6;
    signalPulse.repeatCount = HUGE_VALF;
    signalPulse.autoreverses = YES;
    signalPulse.animations = @[pulseScale, pulseOpacity];
    [_signalDotView.layer addAnimation:signalPulse forKey:@"pp.home.smartSearch.signalPulse"];
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
    self.accessibilityValue = safeText;

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        _placeholderLabel.text = safeText;
        _placeholderLabel.textColor = nextColor;
        return;
    }

    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self->_placeholderLabel.transform = CGAffineTransformMakeTranslation(0.0, -1.5);
        self->_placeholderLabel.alpha = 0.0;
        self->_signalRowView.alpha = 0.72;
    } completion:^(__unused BOOL finished) {
        self->_placeholderLabel.text = safeText;
        self->_placeholderLabel.textColor = nextColor;
        self->_placeholderLabel.transform = CGAffineTransformMakeTranslation(0.0, 2.0);

        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            self->_placeholderLabel.transform = CGAffineTransformIdentity;
            self->_placeholderLabel.alpha = 1.0;
            self->_signalRowView.alpha = 1.0;
        } completion:nil];
    }];

    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self->_leadingChipView.transform = CGAffineTransformMakeScale(1.04, 1.04);
        self->_trailingOrbView.transform = CGAffineTransformMakeScale(1.03, 1.03);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.24 delay:0.0 usingSpringWithDamping:0.82 initialSpringVelocity:0.25 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self->_leadingChipView.transform = CGAffineTransformIdentity;
            self->_trailingOrbView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
        }];
    }];
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    // Nav-bar scroll-edge transitions can propagate tint updates while scrolling.
    // Reapplying the steady home-search palette keeps the title view colors locked.
    [self pp_applyPalette];
}

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

    _chromeView.backgroundColor = UIColor.clearColor;
    if (usesSystemGlassChrome) {
        [self pp_configureSystemGlassChromeIfNeeded];
        _chromeView.layer.borderWidth = 0.0f;
        [_chromeView pp_setBorderColor:UIColor.clearColor];
        _chromeBlurView.alpha = 0.0;
        _chromeTintOverlay.backgroundColor = UIColor.clearColor;
    } else {
        _chromeBlurView.alpha = 1.0;

        UIBlurEffectStyle blurStyle = isDark
            ? UIBlurEffectStyleSystemThinMaterialDark
            : UIBlurEffectStyleSystemThinMaterialLight;
        _chromeBlurView.effect = [UIBlurEffect effectWithStyle:blurStyle];

        CGFloat tintAlpha = isDark ? 0.28 : 0.14;
        _chromeTintOverlay.backgroundColor = [surfaceColor colorWithAlphaComponent:tintAlpha];
        _chromeView.layer.borderWidth = isDark ? 0.78f : 0.92f;
        [_chromeView pp_setBorderColor:[liquidBorderColor colorWithAlphaComponent:isDark ? 0.30 : 0.58]];
    }

    _leadingChipView.backgroundColor =
        [accentColor colorWithAlphaComponent:isDark ? 0.24 : 0.12];
    _leadingChipView.layer.borderWidth = 1.0f;
    [_leadingChipView pp_setBorderColor:[accentColor colorWithAlphaComponent:isDark ? 0.22 : 0.14]];
    _leadingIconView.tintColor = accentColor;

    _signalDotView.backgroundColor = AppPrimaryClrShiner ?: accentColor;
    _signalLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.72 : 0.58];
    _placeholderLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.96 : 0.90];

    _trailingOrbView.backgroundColor =
        [textColor colorWithAlphaComponent:isDark ? 0.10 : 0.05];
    _trailingOrbView.layer.borderWidth = 1.0f;
    [_trailingOrbView pp_setBorderColor:[textColor colorWithAlphaComponent:isDark ? 0.10 : 0.06]];
    _chevronView.tintColor = [textColor colorWithAlphaComponent:isDark ? 0.74 : 0.54];
    self.layer.shadowOpacity = usesSystemGlassChrome
        ? (isDark ? 0.10f : 0.025f)
        : (isDark ? 0.16f : 0.04f);
}

- (void)pp_updateInteractiveStateAnimated:(BOOL)animated
{
    void (^changes)(void) = ^{
        BOOL isPressed = self.highlighted;
        BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        BOOL usesSystemGlassChrome = [self pp_usesSystemGlassChrome];
        CGFloat chromeScale = usesSystemGlassChrome ? 0.992 : 0.988;
        self->_chromeView.transform = isPressed ? CGAffineTransformMakeScale(chromeScale, chromeScale) : CGAffineTransformIdentity;
        self->_leadingChipView.transform = isPressed ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self->_trailingOrbView.transform = isPressed ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
        CGFloat idleShadow = usesSystemGlassChrome ? (isDark ? 0.10f : 0.05f) : (isDark ? 0.16f : 0.08f);
        CGFloat pressedShadow = usesSystemGlassChrome ? (isDark ? 0.14f : 0.08f) : (isDark ? 0.20f : 0.12f);
        self.layer.shadowOpacity = self->_showSmartPillBackground ? (isPressed ? pressedShadow : idleShadow) : 0.0f;
        self.layer.shadowRadius = isPressed ? (usesSystemGlassChrome ? 16.0f : 18.0f) : (usesSystemGlassChrome ? 12.0f : 14.0f);
        self->_chromeView.alpha = self.enabled ? (isPressed ? 0.98 : 1.0) : 0.72;
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView animateWithDuration:self.highlighted ? 0.12 : 0.24
                          delay:0.0
         usingSpringWithDamping:self.highlighted ? 1.0 : 0.82
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

@end

