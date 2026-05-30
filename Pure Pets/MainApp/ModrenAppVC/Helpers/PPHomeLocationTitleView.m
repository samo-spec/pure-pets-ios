#import "PPHomeLocationTitleView.h"
#import <math.h>

static CGFloat const PPHomeLocationTitleHeight = 46.0;
static CGFloat const PPHomeLocationChevronSize = 14.0;
static CGFloat const PPHomeLocationHaloInset = 6.0;
static CGFloat const PPHomeLocationTitleRestingAlpha = 1.0;
static CGFloat const PPHomeLocationTitleHighlightedAlpha = 0.98;

static BOOL PPHomeLocationTitleShouldReduceMotion(void)
{
    return UIAccessibilityIsReduceMotionEnabled();
}

@interface PPHomeLocationTitleView ()
@property (nonatomic, strong) UIView *haloView;
@property (nonatomic, strong) UIButton *glassChromeButton;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintOverlayView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *stateContainerView;
@property (nonatomic, strong) UIView *pulseRingView;
@property (nonatomic, strong) UIView *stateDotView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIColor *currentStatusColor;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL livingMotionRequested;
@property (nonatomic, assign) BOOL entrancePlayed;
@property (nonatomic, assign) BOOL pendingEntrance;
@end

@implementation PPHomeLocationTitleView

- (BOOL)pp_usesSystemGlassChrome
{
    return self.glassChromeButton != nil;
}

- (void)pp_configureSystemGlassChromeIfNeeded
{
    if (!self.glassChromeButton) {
        return;
    }

    if (@available(iOS 26.0, *)) {
        BOOL dark = ([self pp_currentHostInterfaceStyle] == UIUserInterfaceStyleDark);
        UIColor *surface = AppForgroundColr;
        if (!surface) {
            if (@available(iOS 13.0, *)) {
                surface = UIColor.secondarySystemBackgroundColor;
            } else {
                surface = [UIColor colorWithWhite:1.0 alpha:0.90];
            }
        }
        UIColor *liquidBorder = AppForgroundColr ?: surface;

        UIButtonConfiguration *configuration =
            [UIButtonConfiguration clearGlassButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        configuration.baseForegroundColor = UIColor.clearColor;

        UIBackgroundConfiguration *background =
            configuration.background ?: [UIBackgroundConfiguration clearConfiguration];
        background.backgroundInsets = NSDirectionalEdgeInsetsZero;
        background.backgroundColor = UIColor.clearColor;
        background.strokeColor = [liquidBorder colorWithAlphaComponent:dark ? 0.34 : 0.68];
        background.strokeWidth = 0.9;
        background.visualEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleClear];
        background.cornerRadius =
            CGRectGetHeight(self.bounds) > 0.0 ? CGRectGetHeight(self.bounds) * 0.5 : PPHomeLocationTitleHeight * 0.5;
        configuration.background = background;

        self.glassChromeButton.configuration = configuration;
    }
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_buildView];
        [self pp_applyAppearance];
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, PPHomeLocationTitleHeight);
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGFloat width = size.width > 0.0 ? size.width : 190.0;
    return CGSizeMake(width, PPHomeLocationTitleHeight);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat radius = CGRectGetHeight(self.bounds) * 0.5;
    self.blurView.layer.cornerRadius = radius;
    self.tintOverlayView.layer.cornerRadius = radius;
    self.glassChromeButton.layer.cornerRadius = radius;
    self.haloView.layer.cornerRadius = CGRectGetHeight(self.haloView.bounds) * 0.5;
    self.haloView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.haloView.bounds
                                   cornerRadius:self.haloView.layer.cornerRadius].CGPath;
    self.iconPlateView.layer.cornerRadius = CGRectGetHeight(self.iconPlateView.bounds) * 0.5;
    self.stateDotView.layer.cornerRadius = CGRectGetHeight(self.stateDotView.bounds) * 0.5;
    self.pulseRingView.layer.cornerRadius = CGRectGetHeight(self.pulseRingView.bounds) * 0.5;
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                   cornerRadius:radius].CGPath;
    [self pp_configureSystemGlassChromeIfNeeded];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self pp_applyForcedInterfaceStyleForCurrentEnvironment];

    if (self.window) {
        if (self.pendingEntrance) {
            self.pendingEntrance = NO;
            [self pp_runEntranceAnimation];
        }
        if (self.livingMotionRequested) {
            [self pp_startLivingAnimationsIfPossible];
        }
    } else {
        [self pp_removeLivingAnimations];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyForcedInterfaceStyleForCurrentEnvironment];
    [self pp_applyAppearance];
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    [self pp_applyAppearance];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    if (PPHomeLocationTitleShouldReduceMotion()) {
        self.alpha = highlighted ? PPHomeLocationTitleHighlightedAlpha : PPHomeLocationTitleRestingAlpha;
        return;
    }

    CGFloat scale = highlighted ? 0.965 : 1.0;
    NSTimeInterval duration = highlighted ? 0.10 : 0.20;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.36
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = CGAffineTransformMakeScale(scale, scale);
        self.alpha = highlighted ? PPHomeLocationTitleHighlightedAlpha : PPHomeLocationTitleRestingAlpha;
    } completion:nil];
}

- (void)configureWithTitle:(NSString *)title
               statusColor:(UIColor *)statusColor
                   loading:(BOOL)loading
         accessibilityHint:(NSString *)accessibilityHint
                  animated:(BOOL)animated
{
    NSString *safeTitle = [[title ?: @"" stringByReplacingOccurrencesOfString:@"\n" withString:@" "]
                           stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    safeTitle = [safeTitle stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    BOOL titleChanged = ![self.titleLabel.text isEqualToString:safeTitle];
    self.currentStatusColor = statusColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    self.loading = loading;

    void (^applyTitle)(void) = ^{
        self.titleLabel.text = safeTitle;
    };

    if (animated && titleChanged && !PPHomeLocationTitleShouldReduceMotion()) {
        [UIView transitionWithView:self.titleLabel
                          duration:0.22
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                        animations:applyTitle
                        completion:nil];
    } else {
        applyTitle();
    }

    UIImage *iconImage = nil;
    UIImage *chevronImage = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        UIImageSymbolConfiguration *chevronConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:13.5
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium];
        iconImage = [[UIImage systemImageNamed:(loading ? @"arrow.triangle.2.circlepath" : @"location.fill")
                             withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        chevronImage = [[UIImage systemImageNamed:@"chevron.down"
                                withConfiguration:chevronConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    self.iconView.image = iconImage;
    self.chevronView.image = chevronImage;
    self.iconView.hidden = (iconImage == nil);
    self.chevronView.hidden = (chevronImage == nil);

    self.accessibilityLabel = safeTitle;
    self.accessibilityHint = accessibilityHint;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    [self pp_applySemanticDirection];
    [self pp_applyAppearance];

    if (animated && titleChanged && !PPHomeLocationTitleShouldReduceMotion()) {
        self.stateDotView.transform = CGAffineTransformMakeScale(0.7, 0.7);
        [UIView animateWithDuration:0.24
                              delay:0.02
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.2
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.stateDotView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    if (self.livingMotionRequested && self.window) {
        [self pp_startLivingAnimationsIfPossible];
    }
}

- (void)playEntranceIfNeeded
{
    if (self.entrancePlayed) {
        return;
    }
    self.entrancePlayed = YES;

    if (!self.window) {
        self.pendingEntrance = YES;
        return;
    }

    [self pp_runEntranceAnimation];
}

- (void)startLivingMotion
{
    self.livingMotionRequested = YES;
    [self pp_startLivingAnimationsIfPossible];
}

- (void)stopLivingMotion
{
    self.livingMotionRequested = NO;
    [self pp_removeLivingAnimations];
}

#pragma mark - Private

- (UIUserInterfaceStyle)pp_currentHostInterfaceStyle
{
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle style = self.window.traitCollection.userInterfaceStyle;
        if (style == UIUserInterfaceStyleUnspecified && self.superview) {
            style = self.superview.traitCollection.userInterfaceStyle;
        }
        if (style == UIUserInterfaceStyleUnspecified) {
            style = UIScreen.mainScreen.traitCollection.userInterfaceStyle;
        }
        if (style == UIUserInterfaceStyleUnspecified) {
            style = UITraitCollection.currentTraitCollection.userInterfaceStyle;
        }
        if (style == UIUserInterfaceStyleDark) {
            return UIUserInterfaceStyleDark;
        }
    }

    return UIUserInterfaceStyleLight;
}

- (void)pp_applyForcedInterfaceStyleForCurrentEnvironment
{
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle targetStyle = [self pp_currentHostInterfaceStyle];
        if (self.overrideUserInterfaceStyle == targetStyle) {
            return;
        }
        self.overrideUserInterfaceStyle = targetStyle;
    }
}

- (void)pp_buildView
{
    [self pp_applyForcedInterfaceStyleForCurrentEnvironment];
    self.backgroundColor = UIColor.clearColor;
    self.alpha = PPHomeLocationTitleRestingAlpha;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.layer.shadowRadius = 12.0;
    self.isAccessibilityElement = YES;

    self.haloView = [[UIView alloc] init];
    self.haloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.haloView.userInteractionEnabled = NO;
    self.haloView.alpha = 0.0;
    self.haloView.clipsToBounds = NO;
    self.haloView.layer.masksToBounds = NO;
    self.haloView.layer.shadowOffset = CGSizeZero;
    self.haloView.layer.shadowRadius = 0.0;
    [self addSubview:self.haloView];

    if (@available(iOS 26.0, *)) {
        self.glassChromeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.glassChromeButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.glassChromeButton.backgroundColor = UIColor.clearColor;
        self.glassChromeButton.userInteractionEnabled = NO;
        self.glassChromeButton.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            self.glassChromeButton.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [self addSubview:self.glassChromeButton];
        [self pp_configureSystemGlassChromeIfNeeded];
    }

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemThinMaterial;
    }
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.userInteractionEnabled = NO;
    self.blurView.clipsToBounds = YES;
    self.blurView.backgroundColor = UIColor.clearColor;
    self.blurView.layer.borderWidth = 0.92;
    [self addSubview:self.blurView];

    self.tintOverlayView = [[UIView alloc] init];
    self.tintOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tintOverlayView.userInteractionEnabled = NO;
    self.tintOverlayView.clipsToBounds = YES;
    [self.blurView.contentView addSubview:self.tintOverlayView];

    self.iconPlateView = [[UIView alloc] init];
    self.iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconPlateView.clipsToBounds = YES;
    self.iconPlateView.userInteractionEnabled = NO;
    self.iconPlateView.layer.borderWidth = 1.0;

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.userInteractionEnabled = NO;
    [self.iconPlateView addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.74;
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    self.stateContainerView = [[UIView alloc] init];
    self.stateContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateContainerView.userInteractionEnabled = NO;

    self.pulseRingView = [[UIView alloc] init];
    self.pulseRingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pulseRingView.userInteractionEnabled = NO;
    self.pulseRingView.layer.borderWidth = 1.0;
    [self.stateContainerView addSubview:self.pulseRingView];

    self.stateDotView = [[UIView alloc] init];
    self.stateDotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateDotView.userInteractionEnabled = NO;
    [self.stateContainerView addSubview:self.stateDotView];

    self.chevronView = [[UIImageView alloc] init];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronView.userInteractionEnabled = NO;

    self.contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconPlateView,
        self.titleLabel,
        self.stateContainerView,
        self.chevronView
    ]];
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.axis = UILayoutConstraintAxisHorizontal;
    self.contentStackView.alignment = UIStackViewAlignmentCenter;
    self.contentStackView.distribution = UIStackViewDistributionFill;
    self.contentStackView.spacing = 10.0;
    self.contentStackView.userInteractionEnabled = NO;
    [self.blurView.contentView addSubview:self.contentStackView];

    if (self.glassChromeButton) {
        [NSLayoutConstraint activateConstraints:@[
            [self.glassChromeButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.glassChromeButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.glassChromeButton.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.glassChromeButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:PPHomeLocationTitleHeight],

        [self.haloView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPHomeLocationHaloInset],
        [self.haloView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPHomeLocationHaloInset],
        [self.haloView.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPHomeLocationHaloInset],
        [self.haloView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPHomeLocationHaloInset],

        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.tintOverlayView.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor],
        [self.tintOverlayView.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor],
        [self.tintOverlayView.topAnchor constraintEqualToAnchor:self.blurView.contentView.topAnchor],
        [self.tintOverlayView.bottomAnchor constraintEqualToAnchor:self.blurView.contentView.bottomAnchor],

        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor constant:7.0],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor constant:-7.0],
        [self.contentStackView.centerYAnchor constraintEqualToAnchor:self.blurView.contentView.centerYAnchor],

        [self.iconPlateView.widthAnchor constraintEqualToConstant:28.0],
        [self.iconPlateView.heightAnchor constraintEqualToConstant:28.0],
        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconPlateView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconPlateView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:14.0],
        [self.iconView.heightAnchor constraintEqualToConstant:14.0],

        [self.stateContainerView.widthAnchor constraintEqualToConstant:10.0],
        [self.stateContainerView.heightAnchor constraintEqualToConstant:10.0],
        [self.pulseRingView.centerXAnchor constraintEqualToAnchor:self.stateContainerView.centerXAnchor],
        [self.pulseRingView.centerYAnchor constraintEqualToAnchor:self.stateContainerView.centerYAnchor],
        [self.pulseRingView.widthAnchor constraintEqualToConstant:9.0],
        [self.pulseRingView.heightAnchor constraintEqualToConstant:9.0],
        [self.stateDotView.centerXAnchor constraintEqualToAnchor:self.stateContainerView.centerXAnchor],
        [self.stateDotView.centerYAnchor constraintEqualToAnchor:self.stateContainerView.centerYAnchor],
        [self.stateDotView.widthAnchor constraintEqualToConstant:5.0],
        [self.stateDotView.heightAnchor constraintEqualToConstant:5.0],

        [self.chevronView.widthAnchor constraintEqualToConstant:PPHomeLocationChevronSize],
        [self.chevronView.heightAnchor constraintEqualToConstant:PPHomeLocationChevronSize],
    ]];

    [self pp_applySemanticDirection];
}

- (void)pp_applySemanticDirection
{
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentStackView.semanticContentAttribute = self.semanticContentAttribute;
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
}

- (void)pp_applyAppearance
{
    [self pp_applyForcedInterfaceStyleForCurrentEnvironment];
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = ([self pp_currentHostInterfaceStyle] == UIUserInterfaceStyleDark);
    }

    UIColor *accent = AppPrimaryClr ?: AppPrimaryClrShiner ?: UIColor.systemBlueColor;
    UIColor *text = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *surface = AppForgroundColr;
    if (!surface) {
        if (@available(iOS 13.0, *)) {
            surface = UIColor.secondarySystemBackgroundColor;
        } else {
            surface = [UIColor colorWithWhite:1.0 alpha:0.90];
        }
    }
    UIColor *liquidBorder = AppForgroundColr ?: surface;
    UIColor *status = self.currentStatusColor ?: accent;
    BOOL usesSystemGlassChrome = [self pp_usesSystemGlassChrome];

    if (usesSystemGlassChrome) {
        [self pp_configureSystemGlassChromeIfNeeded];
        self.blurView.effect = nil;
        self.blurView.backgroundColor = UIColor.clearColor;
        self.blurView.contentView.backgroundColor = UIColor.clearColor;
        self.tintOverlayView.backgroundColor = UIColor.clearColor;
        self.blurView.layer.borderWidth = 0.0f;
        self.blurView.layer.borderColor = UIColor.clearColor.CGColor;
    } else {
        UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
        if (@available(iOS 13.0, *)) {
            blurStyle = dark
                ? UIBlurEffectStyleSystemThinMaterialDark
                : UIBlurEffectStyleSystemThinMaterialLight;
        }
        self.blurView.effect = [UIBlurEffect effectWithStyle:blurStyle];
        self.tintOverlayView.backgroundColor = [surface colorWithAlphaComponent:(dark ? 0.28 : 0.14)];
        self.blurView.layer.borderWidth = dark ? 0.78f : 0.92f;
        self.blurView.layer.borderColor =
            [liquidBorder colorWithAlphaComponent:(dark ? 0.50 : 0.80)].CGColor;
    }

    self.haloView.backgroundColor = UIColor.clearColor;
    self.haloView.layer.shadowColor = status.CGColor;
    self.haloView.layer.shadowOpacity = 0.0f;
    self.layer.shadowColor = [UIColor colorWithWhite:0.02 alpha:1.0].CGColor;
    self.layer.shadowOpacity = usesSystemGlassChrome
        ? (dark ? 0.10f : 0.025f)
        : (dark ? 0.16f : 0.04f);

    self.iconPlateView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.24 : 0.12)];
    self.iconPlateView.layer.borderColor =
        [accent colorWithAlphaComponent:(dark ? 0.22 : 0.14)].CGColor;
    self.iconView.tintColor = accent;
    self.titleLabel.textColor = text;
    self.chevronView.tintColor = [text colorWithAlphaComponent:(dark ? 0.74 : 0.54)];
    self.stateDotView.backgroundColor = status;
    self.pulseRingView.layer.borderColor = [[status colorWithAlphaComponent:0.45] CGColor];
}

- (void)pp_runEntranceAnimation
{
    if (PPHomeLocationTitleShouldReduceMotion()) {
        self.alpha = PPHomeLocationTitleRestingAlpha;
        self.transform = CGAffineTransformIdentity;
        return;
    }

    self.alpha = 0.0;
    self.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -3.0),
                                             CGAffineTransformMakeScale(0.94, 0.94));
    [UIView animateWithDuration:0.42
                          delay:0.03
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.alpha = PPHomeLocationTitleRestingAlpha;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_startLivingAnimationsIfPossible
{
    if (!self.window || !self.livingMotionRequested) {
        return;
    }

    [self pp_removeLivingAnimations];

    if (PPHomeLocationTitleShouldReduceMotion()) {
        self.haloView.alpha = 0.0;
        self.pulseRingView.alpha = 0.35;
        return;
    }

    CAAnimationGroup *pulse = [CAAnimationGroup animation];
    CABasicAnimation *ringScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    ringScale.fromValue = @(0.82);
    ringScale.toValue = @(1.62);
    CABasicAnimation *ringOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ringOpacity.fromValue = @(0.46);
    ringOpacity.toValue = @(0.0);
    pulse.animations = @[ringScale, ringOpacity];
    pulse.duration = 2.7;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.pulseRingView.layer addAnimation:pulse forKey:@"pp_location_state_pulse"];

    if (self.loading) {
        CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotation.fromValue = @(0.0);
        rotation.toValue = @(M_PI * 2.0);
        rotation.duration = 1.2;
        rotation.repeatCount = HUGE_VALF;
        rotation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        [self.iconView.layer addAnimation:rotation forKey:@"pp_location_loading_rotation"];
    }
}

- (void)pp_removeLivingAnimations
{
    [self.haloView.layer removeAnimationForKey:@"pp_location_halo_opacity"];
    [self.haloView.layer removeAnimationForKey:@"pp_location_halo_scale"];
    [self.pulseRingView.layer removeAnimationForKey:@"pp_location_state_pulse"];
    [self.iconView.layer removeAnimationForKey:@"pp_location_loading_rotation"];
    self.haloView.alpha = 0.0;
    self.pulseRingView.alpha = 1.0;
    self.iconView.transform = CGAffineTransformIdentity;
}

@end
