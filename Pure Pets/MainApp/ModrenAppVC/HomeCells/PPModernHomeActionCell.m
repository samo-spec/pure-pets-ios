#import "PPModernHomeActionCell.h"

static inline UIColor *PPModernHomeActionDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

@interface PPModernHomeActionCell ()

@property (nonatomic, strong) UIButton *tapButton;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *signalLineView;
@property (nonatomic, strong) UIView *pinView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) CAGradientLayer *surfaceLayer;
@property (nonatomic, strong) CAGradientLayer *livingLayer;
@property (nonatomic, copy) NSString *currentTitle;
@property (nonatomic, copy) NSString *currentIconName;
@property (nonatomic, strong) UIColor *currentSignalColor;
@property (nonatomic, assign) BOOL didRunEntrance;

@end

@implementation PPModernHomeActionCell

+ (NSString *)reuseIdentifier
{
    return @"PPModernHomeActionCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}



#pragma mark - UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.tapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.tapButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.tapButton.adjustsImageWhenHighlighted = NO;
    self.tapButton.backgroundColor = UIColor.clearColor;
    self.tapButton.clipsToBounds = NO;
    self.tapButton.layer.masksToBounds = NO;
    [self.tapButton addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.contentView addSubview:self.tapButton];

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.userInteractionEnabled = NO;
    self.surfaceView.layer.cornerRadius = 24.0;
    self.surfaceView.layer.borderWidth = 1.0;
    self.surfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.tapButton addSubview:self.surfaceView];

    self.surfaceLayer = [CAGradientLayer layer];
    self.surfaceLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.surfaceView.layer insertSublayer:self.surfaceLayer atIndex:0];

    self.livingLayer = [CAGradientLayer layer];
    self.livingLayer.startPoint = CGPointMake(0.0, 0.5);
    self.livingLayer.endPoint = CGPointMake(1.0, 0.5);
    self.livingLayer.locations = @[@0.0, @0.48, @1.0];
    [self.surfaceView.layer insertSublayer:self.livingLayer above:self.surfaceLayer];

    self.signalLineView = [[UIView alloc] init];
    self.signalLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.signalLineView.userInteractionEnabled = NO;
    self.signalLineView.layer.cornerRadius = 1.5;
    self.signalLineView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.signalLineView];

    self.iconPlateView = [[UIView alloc] init];
    self.iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconPlateView.userInteractionEnabled = NO;
    self.iconPlateView.layer.cornerRadius = 18.0;
    self.iconPlateView.layer.borderWidth = 1.0;
    self.iconPlateView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.iconPlateView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.clipsToBounds = NO;
    [self.iconPlateView addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontSizeToFitWidth = NO;
    self.titleLabel.userInteractionEnabled = NO;
    [self.surfaceView addSubview:self.titleLabel];

    UIImage *chevronImage = nil;
    if (@available(iOS 13.0, *)) {
        chevronImage = [UIImage systemImageNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")];
    }
    self.chevronView = [[UIImageView alloc] initWithImage:[chevronImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronView.userInteractionEnabled = NO;
    [self.surfaceView addSubview:self.chevronView];

    self.pinView = [[UIView alloc] init];
    self.pinView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinView.userInteractionEnabled = NO;
    self.pinView.layer.cornerRadius = 2.5;
    self.pinView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.pinView];

    [self.iconPlateView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.chevronView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                       forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.tapButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.tapButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.tapButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.tapButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.surfaceView.topAnchor constraintEqualToAnchor:self.tapButton.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.tapButton.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.tapButton.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.tapButton.bottomAnchor],

        [self.signalLineView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:10.0],
        [self.signalLineView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.signalLineView.widthAnchor constraintEqualToConstant:3.0],
        [self.signalLineView.heightAnchor constraintEqualToConstant:28.0],

        [self.iconPlateView.leadingAnchor constraintEqualToAnchor:self.signalLineView.trailingAnchor constant:9.0],
        [self.iconPlateView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconPlateView.widthAnchor constraintEqualToConstant:38.0],
        [self.iconPlateView.heightAnchor constraintEqualToConstant:38.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconPlateView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconPlateView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:18.0],
        [self.iconView.heightAnchor constraintEqualToConstant:18.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconPlateView.trailingAnchor constant:9.0],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],

        [self.chevronView.leadingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:8.0],
        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-12.0],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:11.0],
        [self.chevronView.heightAnchor constraintEqualToConstant:13.0],

        [self.pinView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:9.0],
        [self.pinView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-11.0],
        [self.pinView.widthAnchor constraintEqualToConstant:5.0],
        [self.pinView.heightAnchor constraintEqualToConstant:5.0],
    ]];

    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOpacity = 0.05;
    self.layer.shadowRadius = 12.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [self pp_applyTheme];
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName
{
    self.currentTitle = PPSafeString(title);
    self.currentIconName = PPSafeString(systemIconName);
    self.currentSignalColor = [self pp_signalColorForTitle:self.currentTitle];
    [self pp_applyContent];
}

- (void)configureWithQuickAction:(PPHomeQuickActionModel *)quickAction
{
    self.currentTitle = PPSafeString(quickAction.title);
    self.currentIconName = PPSafeString(quickAction.iconName);
    self.currentSignalColor = [self pp_signalColorForQuickActionType:quickAction.type];
    [self pp_applyContent];
}

- (void)pp_applyContent
{
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.tapButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.surfaceView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.text = self.currentTitle;
    self.tapButton.accessibilityLabel = self.currentTitle;

    UIImage *icon = nil;
    if (@available(iOS 13.0, *)) {
        icon = [UIImage systemImageNamed:(self.currentIconName.length > 0 ? self.currentIconName : @"sparkles")];
    }
    if (!icon && self.currentIconName.length > 0) {
        icon = [UIImage imageNamed:self.currentIconName];
    }
    if (@available(iOS 13.0, *)) {
        icon = icon ?: [UIImage systemImageNamed:@"sparkles"];
    }
    self.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UIImage *chevronImage = nil;
    if (@available(iOS 13.0, *)) {
        chevronImage = [UIImage systemImageNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")];
    }
    self.chevronView.image = [chevronImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self pp_applyTheme];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
    [self pp_startLivingMotionIfNeeded];
    [self pp_runEntranceIfNeeded];
}

#pragma mark - Theme

- (void)pp_applyTheme
{
    UIColor *top = PPModernHomeActionDynamicColor([UIColor colorWithWhite:1.0 alpha:0.94],
                                                  [UIColor colorWithWhite:0.16 alpha:0.94]);
    UIColor *bottom = PPModernHomeActionDynamicColor([UIColor colorWithWhite:0.94 alpha:0.90],
                                                     [UIColor colorWithWhite:0.09 alpha:0.94]);
    UIColor *border = PPModernHomeActionDynamicColor([[UIColor blackColor] colorWithAlphaComponent:0.055],
                                                     [[UIColor whiteColor] colorWithAlphaComponent:0.075]);
    UIColor *plate = PPModernHomeActionDynamicColor([[UIColor whiteColor] colorWithAlphaComponent:0.70],
                                                    [[UIColor whiteColor] colorWithAlphaComponent:0.055]);
    UIColor *plateBorder = PPModernHomeActionDynamicColor([[UIColor blackColor] colorWithAlphaComponent:0.04],
                                                          [[UIColor whiteColor] colorWithAlphaComponent:0.08]);
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *secondaryColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    UIColor *signal = self.currentSignalColor ?: [self pp_neutralSignalColor];

    self.surfaceLayer.colors = @[
        (__bridge id)top.CGColor,
        (__bridge id)bottom.CGColor
    ];
    self.surfaceView.backgroundColor = bottom;
    [self.surfaceView pp_setBorderColor:border];

    self.livingLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.14].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];

    self.iconPlateView.backgroundColor = plate;
    [self.iconPlateView pp_setBorderColor:plateBorder];
    self.titleLabel.textColor = titleColor;
    self.iconView.tintColor = signal;
    self.signalLineView.backgroundColor = [signal colorWithAlphaComponent:0.75];
    self.pinView.backgroundColor = [secondaryColor colorWithAlphaComponent:0.18];
    self.chevronView.tintColor = [secondaryColor colorWithAlphaComponent:0.74];
}

- (UIColor *)pp_neutralSignalColor
{
    return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.38 green:0.42 blue:0.48 alpha:1.0],
                                          [UIColor colorWithRed:0.72 green:0.75 blue:0.80 alpha:1.0]);
}

- (UIColor *)pp_signalColorForTitle:(NSString *)title
{
    (void)title;
    return [self pp_neutralSignalColor];
}

- (UIColor *)pp_signalColorForQuickActionType:(PPHomeQuickActionType)type
{
    switch (type) {
        case PPHomeQuickActionTypeNearestVet:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.26 green:0.50 blue:0.46 alpha:1.0],
                                                  [UIColor colorWithRed:0.56 green:0.76 blue:0.72 alpha:1.0]);
        case PPHomeQuickActionTypeSellPet:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.54 green:0.42 blue:0.30 alpha:1.0],
                                                  [UIColor colorWithRed:0.78 green:0.67 blue:0.54 alpha:1.0]);
        case PPHomeQuickActionTypeAdopt:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.58 green:0.36 blue:0.46 alpha:1.0],
                                                  [UIColor colorWithRed:0.80 green:0.60 blue:0.68 alpha:1.0]);
        case PPHomeQuickActionTypeAddAd:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.34 green:0.42 blue:0.60 alpha:1.0],
                                                  [UIColor colorWithRed:0.62 green:0.68 blue:0.84 alpha:1.0]);
        case PPHomeQuickActionTypeRequestService:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.42 green:0.44 blue:0.49 alpha:1.0],
                                                  [UIColor colorWithRed:0.72 green:0.74 blue:0.80 alpha:1.0]);
    }
    return [self pp_neutralSignalColor];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGRect bounds = self.surfaceView.bounds;
    self.surfaceLayer.frame = bounds;
    self.livingLayer.frame = CGRectInset(bounds, -MAX(CGRectGetWidth(bounds), 90.0), 0.0);
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                   cornerRadius:24.0].CGPath;
    [CATransaction commit];
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    UICollectionViewLayoutAttributes *attributes = [layoutAttributes copy];
    CGRect frame = attributes.frame;
    frame.size.width = [self pp_preferredWidth];
    frame.size.height = layoutAttributes.frame.size.height;
    attributes.frame = frame;
    return attributes;
}

- (CGFloat)pp_preferredWidth
{
    CGFloat titleWidth = 0.0;
    if (self.currentTitle.length > 0) {
        NSDictionary *attributes = @{ NSFontAttributeName: self.titleLabel.font ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold] };
        CGRect titleRect = [self.currentTitle boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                           options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                        attributes:attributes
                                                           context:nil];
        titleWidth = ceil(CGRectGetWidth(titleRect));
    }

    CGFloat fixedWidth = 10.0 + 3.0 + 9.0 + 38.0 + 9.0 + 8.0 + 11.0 + 12.0;
    CGFloat naturalWidth = fixedWidth + MAX(22.0, titleWidth);
    return ceil(MIN(MAX(130.0, naturalWidth), 310.0));
}

#pragma mark - Motion

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startLivingMotionIfNeeded];
        [self pp_runEntranceIfNeeded];
    } else {
        [self pp_stopLivingMotion];
    }
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntrance || !self.window) {
        return;
    }
    self.didRunEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
        return;
    }

    self.alpha = 0.0;
    self.contentView.transform = CGAffineTransformMakeTranslation(0.0, 7.0);
    [UIView animateWithDuration:0.30
                          delay:0.015
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_startLivingMotionIfNeeded
{
    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopLivingMotion];
        return;
    }
    if ([self.livingLayer animationForKey:@"pp_quick_action_living"]) {
        return;
    }

    CGFloat travel = MAX(CGRectGetWidth(self.surfaceView.bounds), 96.0);
    CABasicAnimation *motion = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    motion.fromValue = @(-travel);
    motion.toValue = @(travel);
    motion.duration = 6.2;
    motion.repeatCount = HUGE_VALF;
    motion.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    motion.removedOnCompletion = NO;
    [self.livingLayer addAnimation:motion forKey:@"pp_quick_action_living"];

    CABasicAnimation *pin = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pin.fromValue = @0.18;
    pin.toValue = @0.52;
    pin.duration = 3.8;
    pin.autoreverses = YES;
    pin.repeatCount = HUGE_VALF;
    pin.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.pinView.layer addAnimation:pin forKey:@"pp_quick_action_pin_breathe"];
}

- (void)pp_stopLivingMotion
{
    [self.livingLayer removeAnimationForKey:@"pp_quick_action_living"];
    [self.pinView.layer removeAnimationForKey:@"pp_quick_action_pin_breathe"];
}

- (void)pp_handleTouchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.tapButton.transform = CGAffineTransformMakeScale(0.976, 0.976);
        self.iconPlateView.transform = CGAffineTransformMakeScale(0.93, 0.93);
        self.signalLineView.alpha = 1.0;
    } completion:nil];
}

- (void)pp_handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.tapButton.transform = CGAffineTransformIdentity;
        self.iconPlateView.transform = CGAffineTransformIdentity;
        self.signalLineView.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.tapButton.transform = CGAffineTransformIdentity;
        self.iconPlateView.transform = CGAffineTransformIdentity;
        self.signalLineView.alpha = 0.92;
    } completion:nil];
}

- (void)pp_handleTap
{
    if (self.onTap) {
        self.onTap();
    }
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self pp_stopLivingMotion];
    self.onTap = nil;
    self.currentTitle = nil;
    self.currentIconName = nil;
    self.currentSignalColor = nil;
    self.didRunEntrance = NO;
    self.titleLabel.text = nil;
    self.tapButton.accessibilityLabel = nil;
    self.iconView.image = nil;
    self.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.tapButton.transform = CGAffineTransformIdentity;
    self.iconPlateView.transform = CGAffineTransformIdentity;
    self.signalLineView.alpha = 0.92;
    [self pp_applyTheme];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyTheme];
        }
    }
}

@end
