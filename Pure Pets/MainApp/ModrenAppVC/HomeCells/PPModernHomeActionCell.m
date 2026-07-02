#import "PPModernHomeActionCell.h"

static CGFloat const PPModernHomeActionCornerRadius = 20.0;
static CGFloat const PPModernHomeActionMinimumHeight = 48.0;
static CGFloat const PPModernHomeActionSignalLeading = 7.0;
static CGFloat const PPModernHomeActionSignalWidth = 4.0;
static CGFloat const PPModernHomeActionSignalHeight = 18.0;
static CGFloat const PPModernHomeActionIconPlateSize = 28.0;
static CGFloat const PPModernHomeActionIconGlyphSize = 15.5;
static CGFloat const PPModernHomeActionTitleSpacing = 8.0;
static CGFloat const PPModernHomeActionChevronSpacing = 8.0;
static CGFloat const PPModernHomeActionChevronWidth = 10.0;
static CGFloat const PPModernHomeActionTrailingPadding = 16.0;

static inline UIColor *PPModernHomeActionDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static inline UIColor *PPModernHomeActionLightSurfaceColor(void)
{
    return [UIColor colorWithWhite:1.0 alpha:1.0];
}

static inline UIColor *PPModernHomeActionResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traitCollection];
    }
    return color;
}

static inline UIColor *PPModernHomeActionBlendColors(UIColor *baseColor, UIColor *overlayColor, CGFloat amount)
{
    CGFloat baseRed = 0.0, baseGreen = 0.0, baseBlue = 0.0, baseAlpha = 0.0;
    CGFloat overlayRed = 0.0, overlayGreen = 0.0, overlayBlue = 0.0, overlayAlpha = 0.0;
    if (![baseColor getRed:&baseRed green:&baseGreen blue:&baseBlue alpha:&baseAlpha] ||
        ![overlayColor getRed:&overlayRed green:&overlayGreen blue:&overlayBlue alpha:&overlayAlpha]) {
        return baseColor ?: overlayColor ?: UIColor.clearColor;
    }

    CGFloat t = MIN(MAX(amount, 0.0), 1.0);
    return [UIColor colorWithRed:(baseRed * (1.0 - t)) + (overlayRed * t)
                           green:(baseGreen * (1.0 - t)) + (overlayGreen * t)
                            blue:(baseBlue * (1.0 - t)) + (overlayBlue * t)
                           alpha:(baseAlpha * (1.0 - t)) + (overlayAlpha * t)];
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
@property (nonatomic, strong) CAGradientLayer *signalMotionLayer;
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
    self.surfaceView.layer.cornerRadius = PPModernHomeActionCornerRadius;
    self.surfaceView.layer.borderWidth = 0.95;
    self.surfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.tapButton addSubview:self.surfaceView];

    self.surfaceLayer = [CAGradientLayer layer];
    self.surfaceLayer.startPoint = CGPointMake(0.0, 0.5);
    self.surfaceLayer.endPoint = CGPointMake(0.5, 1.0);
    [self.surfaceView.layer insertSublayer:self.surfaceLayer atIndex:0];

  
   
 
    self.signalLineView = [[UIView alloc] init];
    self.signalLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.signalLineView.userInteractionEnabled = NO;
    self.signalLineView.layer.cornerRadius = PPModernHomeActionSignalWidth * 0.5;
    self.signalLineView.layer.masksToBounds = NO;
    [self.surfaceView addSubview:self.signalLineView];

    self.signalMotionLayer = [CAGradientLayer layer];
    self.signalMotionLayer.startPoint = CGPointMake(0.5, 0.0);
    self.signalMotionLayer.endPoint = CGPointMake(0.5, 1.0);
    self.signalMotionLayer.locations = @[@0.0, @0.42, @1.0];
    [self.signalLineView.layer addSublayer:self.signalMotionLayer];

    self.iconPlateView = [[UIView alloc] init];
    self.iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconPlateView.userInteractionEnabled = NO;
    self.iconPlateView.layer.cornerRadius = PPModernHomeActionIconPlateSize * 0.5;
    self.iconPlateView.layer.borderWidth = 0.0;
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
    UIFont *titleFont = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    if (@available(iOS 11.0, *)) {
        self.titleLabel.font =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:titleFont
                                                                             maximumPointSize:17.5];
        self.titleLabel.adjustsFontForContentSizeCategory = YES;
    } else {
        self.titleLabel.font = titleFont;
    }
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.88;
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
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                       forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.tapButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.tapButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.tapButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.tapButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.tapButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPModernHomeActionMinimumHeight],

        [self.surfaceView.topAnchor constraintEqualToAnchor:self.tapButton.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.tapButton.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.tapButton.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.tapButton.bottomAnchor],

        [self.signalLineView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPModernHomeActionSignalLeading],
        [self.signalLineView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.signalLineView.widthAnchor constraintEqualToConstant:PPModernHomeActionSignalWidth],
        [self.signalLineView.heightAnchor constraintEqualToConstant:PPModernHomeActionSignalHeight],

        [self.iconPlateView.leadingAnchor constraintEqualToAnchor:self.signalLineView.trailingAnchor constant:10.0],
        [self.iconPlateView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconPlateView.widthAnchor constraintEqualToConstant:PPModernHomeActionIconPlateSize],
        [self.iconPlateView.heightAnchor constraintEqualToConstant:PPModernHomeActionIconPlateSize],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconPlateView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconPlateView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:PPModernHomeActionIconGlyphSize],
        [self.iconView.heightAnchor constraintEqualToConstant:PPModernHomeActionIconGlyphSize],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconPlateView.trailingAnchor constant:PPModernHomeActionTitleSpacing],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],

        [self.chevronView.leadingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:PPModernHomeActionChevronSpacing],
        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPModernHomeActionTrailingPadding],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:PPModernHomeActionChevronWidth],
        [self.chevronView.heightAnchor constraintEqualToConstant:12.0],

        [self.pinView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:8.0],
        [self.pinView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-10.0],
        [self.pinView.widthAnchor constraintEqualToConstant:4.5],
        [self.pinView.heightAnchor constraintEqualToConstant:4.5],
    ]];

    [self pp_setShadowColor:UIColor.blackColor];
    //self.layer.shadowOpacity = 0.0;
    //self.layer.shadowRadius = 0.0;
    //self.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    
    self.layer.shadowOpacity = 0.07;
    self.layer.shadowRadius = 13.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 7.0);
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

    NSString *safeIconName = [self.currentIconName isKindOfClass:NSString.class]
        ? [self.currentIconName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    UIImage *icon = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:14.5
                                                            weight:UIImageSymbolWeightSemibold];
        icon = [UIImage systemImageNamed:(safeIconName.length > 0 ? safeIconName : @"sparkles")
                       withConfiguration:configuration];
        if (!icon) {
            icon = [UIImage systemImageNamed:@"sparkles" withConfiguration:configuration];
        }
    }
    if (!icon && safeIconName.length > 0) {
        icon = [UIImage imageNamed:safeIconName];
    }
    self.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UIImage *chevronImage = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:11.0
                                                            weight:UIImageSymbolWeightSemibold];
        chevronImage = [UIImage systemImageNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                               withConfiguration:configuration];
    }
    self.chevronView.image = [chevronImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self pp_applyTheme];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
    [self pp_startSignalMotionIfNeeded];
    [self pp_runEntranceIfNeeded];
}

#pragma mark - Theme

- (void)pp_applyTheme
{
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *signal = PPModernHomeActionResolvedColor(self.currentSignalColor ?: [self pp_neutralSignalColor],
                                                      self.traitCollection);
    UIColor *surfaceBase = isDark
        ? [UIColor colorWithRed:0.075 green:0.083 blue:0.105 alpha:1.0]
        : PPModernHomeActionLightSurfaceColor();
    UIColor *top = PPModernHomeActionBlendColors(surfaceBase, signal, isDark ? 0.10 : 0.019);
    UIColor *bottom = PPModernHomeActionBlendColors(surfaceBase, signal, isDark ? 0.18 : 0.035);
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
 
    self.surfaceLayer.colors = @[
        (__bridge id)top.CGColor,
        (__bridge id)bottom.CGColor
    ];
    self.surfaceView.backgroundColor = bottom;
 
    UIColor *liquidBorder = PPModernHomeActionBlendColors(surfaceBase, signal, isDark ? 0.52 : 0.34);
    self.surfaceView.layer.borderWidth = isDark ? 0.85 : 0.95;
    self.surfaceView.layer.borderColor = [liquidBorder colorWithAlphaComponent:isDark ? 0.62 : 0.32].CGColor;
    self.signalMotionLayer.colors = @[
        (__bridge id)[signal colorWithAlphaComponent:0.84].CGColor,
        (__bridge id)[signal colorWithAlphaComponent:1.0].CGColor,
        (__bridge id)[signal colorWithAlphaComponent:0.94].CGColor
    ];

    self.iconPlateView.backgroundColor = [signal colorWithAlphaComponent:isDark ? 0.30 : 0.14];
    [self.iconPlateView pp_setBorderColor:[signal colorWithAlphaComponent:isDark ? 0.30 : 0.20]];
    self.titleLabel.textColor = titleColor;
    self.iconView.tintColor = signal;
    self.signalLineView.backgroundColor = [signal colorWithAlphaComponent:isDark ? 0.24 : 0.17];
    self.signalLineView.alpha = 0.99;
    self.signalLineView.layer.shadowColor = UIColor.clearColor.CGColor;// signal.CGColor;
    self.signalLineView.layer.shadowOpacity = isDark ? 0.30 : 0.18;
    self.signalLineView.layer.shadowRadius = isDark ? 7.0 : 5.5;
    self.signalLineView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    self.pinView.backgroundColor = [signal colorWithAlphaComponent:isDark ? 0.34 : 0.22];
    self.chevronView.tintColor = [signal colorWithAlphaComponent:isDark ? 0.76 : 0.58];
    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOpacity = isDark ? 0.12f : 0.07f;
    self.layer.shadowRadius = isDark ? 15.0f : 13.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, isDark ? 8.0 : 7.0);
}

- (UIColor *)pp_neutralSignalColor
{
    return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.37 green:0.47 blue:0.67 alpha:1.0],
                                          [UIColor colorWithRed:0.66 green:0.76 blue:0.96 alpha:1.0]);
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
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.00 green:0.58 blue:0.48 alpha:1.0],
                                                  [UIColor colorWithRed:0.32 green:0.88 blue:0.72 alpha:1.0]);
        case PPHomeQuickActionTypeSellPet:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.84 green:0.46 blue:0.14 alpha:1.0],
                                                  [UIColor colorWithRed:1.00 green:0.68 blue:0.30 alpha:1.0]);
        case PPHomeQuickActionTypeAdopt:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.43 green:0.44 blue:0.73 alpha:1.0],
                                                  [UIColor colorWithRed:1.00 green:0.50 blue:0.66 alpha:1.0]);
        case PPHomeQuickActionTypeAddAd:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.43 green:0.30 blue:0.92 alpha:1.0],
                                                  [UIColor colorWithRed:0.72 green:0.58 blue:1.00 alpha:1.0]);
        case PPHomeQuickActionTypeRequestService:
            return PPModernHomeActionDynamicColor([UIColor colorWithRed:0.16 green:0.43 blue:0.92 alpha:1.0],
                                                  [UIColor colorWithRed:0.48 green:0.70 blue:1.00 alpha:1.0]);
    }
    return [self pp_neutralSignalColor];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.surfaceLayer.frame = self.surfaceView.bounds;
    self.surfaceLayer.borderWidth = 0.0;
    self.surfaceLayer.cornerRadius = PPModernHomeActionCornerRadius;
    self.surfaceLayer.opacity = 0.7;
    self.signalMotionLayer.frame = self.signalLineView.bounds;
    self.signalMotionLayer.cornerRadius = PPModernHomeActionSignalWidth * 0.5;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:PPModernHomeActionCornerRadius].CGPath;
    [CATransaction commit];
    
 }

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    UICollectionViewLayoutAttributes *attributes = [layoutAttributes copy];
    CGRect frame = attributes.frame;
    frame.size.width = [self pp_preferredWidth];
    frame.size.height = MAX(layoutAttributes.frame.size.height, PPModernHomeActionMinimumHeight);
    attributes.frame = frame;
    return attributes;
}

- (CGFloat)pp_preferredWidth
{
    CGFloat titleWidth = 0.0;
    if (self.currentTitle.length > 0) {
        NSDictionary *attributes = @{ NSFontAttributeName: self.titleLabel.font ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold] };
        CGRect titleRect = [self.currentTitle boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                           options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                        attributes:attributes
                                                           context:nil];
        titleWidth = ceil(CGRectGetWidth(titleRect));
    }

    CGFloat fixedWidth =
        PPModernHomeActionSignalLeading +
        PPModernHomeActionSignalWidth +
        10.0 +
        PPModernHomeActionIconPlateSize +
        PPModernHomeActionTitleSpacing +
        PPModernHomeActionChevronSpacing +
        PPModernHomeActionChevronWidth +
        PPModernHomeActionTrailingPadding;
    CGFloat naturalWidth = fixedWidth + MAX(32.0, titleWidth);
    return ceil(MIN(MAX(104.0, naturalWidth), 260.0));
}

#pragma mark - Motion

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startSignalMotionIfNeeded];
        [self pp_runEntranceIfNeeded];
    } else {
        [self pp_stopSignalMotion];
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

- (void)pp_startSignalMotionIfNeeded
{
    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopSignalMotion];
        return;
    }
    if ([self.signalMotionLayer animationForKey:@"pp_quick_action_signal_scan"] ) {
        return;
    }

    [self pp_stopSignalMotion];

    
 
    CABasicAnimation *signalScan = [CABasicAnimation animationWithKeyPath:@"locations"];
    signalScan.fromValue = @[@0.0, @0.16, @0.34];
    signalScan.toValue = @[@0.66, @0.84, @1.0];
    signalScan.duration = 3.15;
    signalScan.autoreverses = YES;
    signalScan.repeatCount = HUGE_VALF;
    signalScan.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    signalScan.removedOnCompletion = NO;
    [self.signalMotionLayer addAnimation:signalScan forKey:@"pp_quick_action_signal_scan"];

    CABasicAnimation *pin = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pin.fromValue = @0.24;
    pin.toValue = @0.62;
    pin.duration = 4.6;
    pin.autoreverses = YES;
    pin.repeatCount = HUGE_VALF;
    pin.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.pinView.layer addAnimation:pin forKey:@"pp_quick_action_pin_breathe"];
}

- (void)pp_stopSignalMotion
{
   
    [self.signalMotionLayer removeAnimationForKey:@"pp_quick_action_signal_scan"];
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
        self.surfaceView.transform = CGAffineTransformMakeScale(0.965, 0.965);
        self.iconPlateView.transform = CGAffineTransformMakeScale(0.965, 0.965);
        self.signalLineView.alpha = 1.0;
    } completion:nil];
}

- (void)pp_handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.surfaceView.transform = CGAffineTransformIdentity;
        self.iconPlateView.transform = CGAffineTransformIdentity;
        self.signalLineView.alpha = 0.94;
        return;
    }

    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.surfaceView.transform = CGAffineTransformIdentity;
        self.iconPlateView.transform = CGAffineTransformIdentity;
        self.signalLineView.alpha = 0.94;
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
    [self pp_stopSignalMotion];
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
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.iconPlateView.transform = CGAffineTransformIdentity;
    self.signalLineView.alpha = 0.94;
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
