//
//  PPHomeActionCell.m
//  Pure Pets
//
//  Minimal premium Home action card.
//

#import "PPHomeActionCell.h"

static CGFloat const PPHomeActionCellCornerRadius = 22.0;
static CGFloat const PPHomeActionCellMinimumHeight = 64.0;
static CGFloat const PPHomeActionCellTrailingPadding = 12.0;
static CGFloat const PPHomeActionCellIconPlateSize = 36.0;
static CGFloat const PPHomeActionCellAccessoryPlateSize = 28.0;
static CGFloat const PPHomeActionCellAccentWidth = 3.0;
static CGFloat const PPHomeActionCellAccentHeight = 28.0;

static UIColor *PPHomeActionDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIColor *PPHomeActionResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traitCollection];
    }
    return color;
}

static UIColor *PPHomeActionBlend(UIColor *baseColor, UIColor *overlayColor, CGFloat amount)
{
    if (!baseColor) return overlayColor ?: UIColor.clearColor;
    if (!overlayColor) return baseColor;

    CGFloat baseRed = 0.0, baseGreen = 0.0, baseBlue = 0.0, baseAlpha = 0.0;
    CGFloat overlayRed = 0.0, overlayGreen = 0.0, overlayBlue = 0.0, overlayAlpha = 0.0;
    if (![baseColor getRed:&baseRed green:&baseGreen blue:&baseBlue alpha:&baseAlpha] ||
        ![overlayColor getRed:&overlayRed green:&overlayGreen blue:&overlayBlue alpha:&overlayAlpha]) {
        return baseColor;
    }

    CGFloat t = MIN(MAX(amount, 0.0), 1.0);
    return [UIColor colorWithRed:(baseRed * (1.0 - t)) + (overlayRed * t)
                           green:(baseGreen * (1.0 - t)) + (overlayGreen * t)
                            blue:(baseBlue * (1.0 - t)) + (overlayBlue * t)
                           alpha:(baseAlpha * (1.0 - t)) + (overlayAlpha * t)];
}

@interface PPHomeActionCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *surfaceHighlightLayer;
@property (nonatomic, strong) UIView *accentLineView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *accessoryPlateView;
@property (nonatomic, strong) UIImageView *accessoryIconView;
@property (nonatomic, copy) NSString *currentTitle;
@property (nonatomic, copy) NSString *currentIconName;
@property (nonatomic, strong) UIColor *currentAccentColor;

@end

@implementation PPHomeActionCell

+ (NSString *)reuseIdentifier
{
    return @"PPHomeActionCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildUI];
    [self pp_applyTypography];
    [self pp_applyTheme];
    [self pp_resetInteractiveState];
    return self;
}

#pragma mark - UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.isAccessibilityElement = NO;

    self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.backgroundColor = UIColor.clearColor;
    self.actionButton.adjustsImageWhenHighlighted = NO;
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.clipsToBounds = NO;
    self.actionButton.layer.masksToBounds = NO;
    self.actionButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.actionButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.actionButton addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.actionButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self.actionButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.contentView addSubview:self.actionButton];

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.userInteractionEnabled = NO;
    self.surfaceView.layer.cornerRadius = PPHomeActionCellCornerRadius;
    self.surfaceView.layer.masksToBounds = YES;
    self.surfaceView.layer.borderWidth = 0.75;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.actionButton addSubview:self.surfaceView];

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.surfaceView.layer insertSublayer:self.surfaceGradientLayer atIndex:0];

    self.surfaceHighlightLayer = [CAGradientLayer layer];
    self.surfaceHighlightLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceHighlightLayer.endPoint = CGPointMake(1.0, 0.0);
    [self.surfaceView.layer addSublayer:self.surfaceHighlightLayer];

    self.accentLineView = [[UIView alloc] init];
    self.accentLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentLineView.userInteractionEnabled = NO;
    self.accentLineView.layer.cornerRadius = PPHomeActionCellAccentWidth * 0.5;
    self.accentLineView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.accentLineView];

    self.iconPlateView = [[UIView alloc] init];
    self.iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconPlateView.userInteractionEnabled = NO;
    self.iconPlateView.layer.cornerRadius = PPHomeActionCellIconPlateSize * 0.5;
    self.iconPlateView.layer.masksToBounds = YES;
    self.iconPlateView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        self.iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.iconPlateView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.userInteractionEnabled = NO;
    [self.iconPlateView addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.84;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.userInteractionEnabled = NO;
    [self.surfaceView addSubview:self.titleLabel];

    self.accessoryPlateView = [[UIView alloc] init];
    self.accessoryPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessoryPlateView.userInteractionEnabled = NO;
    self.accessoryPlateView.layer.cornerRadius = PPHomeActionCellAccessoryPlateSize * 0.5;
    self.accessoryPlateView.layer.masksToBounds = YES;
    self.accessoryPlateView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        self.accessoryPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.accessoryPlateView];

    self.accessoryIconView = [[UIImageView alloc] init];
    self.accessoryIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessoryIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.accessoryIconView.userInteractionEnabled = NO;
    [self.accessoryPlateView addSubview:self.accessoryIconView];

    [self.iconPlateView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.accessoryPlateView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                             forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.actionButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPHomeActionCellMinimumHeight],

        [self.surfaceView.topAnchor constraintEqualToAnchor:self.actionButton.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.actionButton.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.actionButton.bottomAnchor],

        [self.accentLineView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:10.0],
        [self.accentLineView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.accentLineView.widthAnchor constraintEqualToConstant:PPHomeActionCellAccentWidth],
        [self.accentLineView.heightAnchor constraintEqualToConstant:PPHomeActionCellAccentHeight],

        [self.iconPlateView.leadingAnchor constraintEqualToAnchor:self.accentLineView.trailingAnchor constant:10.0],
        [self.iconPlateView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconPlateView.widthAnchor constraintEqualToConstant:PPHomeActionCellIconPlateSize],
        [self.iconPlateView.heightAnchor constraintEqualToConstant:PPHomeActionCellIconPlateSize],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconPlateView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconPlateView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:18.0],
        [self.iconView.heightAnchor constraintEqualToConstant:18.0],

        [self.accessoryPlateView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPHomeActionCellTrailingPadding],
        [self.accessoryPlateView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.accessoryPlateView.widthAnchor constraintEqualToConstant:PPHomeActionCellAccessoryPlateSize],
        [self.accessoryPlateView.heightAnchor constraintEqualToConstant:PPHomeActionCellAccessoryPlateSize],

        [self.accessoryIconView.centerXAnchor constraintEqualToAnchor:self.accessoryPlateView.centerXAnchor],
        [self.accessoryIconView.centerYAnchor constraintEqualToAnchor:self.accessoryPlateView.centerYAnchor],
        [self.accessoryIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.accessoryIconView.heightAnchor constraintEqualToConstant:12.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconPlateView.trailingAnchor constant:10.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.accessoryPlateView.leadingAnchor constant:-8.0],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
    ]];
}

- (void)pp_applyTypography
{
    UIFont *titleBase = [GM boldFontWithSize:15.5] ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    if (@available(iOS 11.0, *)) {
        self.titleLabel.font =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                scaledFontForFont:titleBase
                  maximumPointSize:19.0];
        self.titleLabel.adjustsFontForContentSizeCategory = YES;
    } else {
        self.titleLabel.font = titleBase;
    }
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName
{
    self.currentTitle = PPSafeString(title);
    self.currentIconName = PPSafeString(systemIconName);
    self.currentAccentColor = [self pp_signalColorForIconName:self.currentIconName];
    [self pp_applyContent];
}

- (void)configureWithQuickAction:(PPHomeQuickActionModel *)quickAction
{
    self.currentTitle = PPSafeString(quickAction.title);
    self.currentIconName = PPSafeString(quickAction.iconName);
    self.currentAccentColor = [self pp_signalColorForQuickActionType:quickAction.type];
    [self pp_applyContent];
}

- (void)pp_applyContent
{
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.actionButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.text = self.currentTitle;

    NSString *safeIconName = [self.currentIconName isKindOfClass:NSString.class]
        ? [self.currentIconName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    UIImage *icon = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                           weight:UIImageSymbolWeightSemibold
                                                            scale:UIImageSymbolScaleMedium];
        NSString *symbolName = safeIconName.length > 0 ? safeIconName : @"sparkles";
        icon = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
        if (!icon) {
            icon = [UIImage systemImageNamed:@"sparkles" withConfiguration:configuration];
        }
    }
    if (!icon && safeIconName.length > 0) {
        icon = [UIImage imageNamed:safeIconName];
    }
    self.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self pp_updateAccessibility];
    [self pp_updateAccessoryState];
    [self pp_applyTheme];
    [self setNeedsLayout];
}

#pragma mark - Theme

- (void)pp_applyTheme
{
    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPHomeActionResolvedColor(self.currentAccentColor ?: [self pp_defaultAccentColor],
                                                self.traitCollection);
    UIColor *baseSurface = darkMode
        ? [UIColor colorWithRed:0.090 green:0.096 blue:0.116 alpha:1.0]
        : [UIColor colorWithRed:0.995 green:0.992 blue:0.986 alpha:1.0];
    UIColor *liftedSurface = PPHomeActionBlend(baseSurface, UIColor.whiteColor, darkMode ? 0.02 : 0.42);
    UIColor *settledSurface = PPHomeActionBlend(baseSurface, accent, darkMode ? 0.12 : 0.045);
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *secondaryColor = [titleColor colorWithAlphaComponent:darkMode ? 0.74 : 0.58];
    UIColor *strokeColor = PPHomeActionBlend(baseSurface, accent, darkMode ? 0.48 : 0.32);
    UIColor *plateFill = PPHomeActionBlend(baseSurface, accent, darkMode ? 0.22 : 0.10);
    UIColor *plateStroke = [accent colorWithAlphaComponent:darkMode ? 0.26 : 0.16];

    self.surfaceView.backgroundColor = baseSurface;
    self.surfaceView.layer.borderWidth = darkMode ? 0.9 : 0.75;
    [self.surfaceView pp_setBorderColor:[strokeColor colorWithAlphaComponent:darkMode ? 0.70 : 0.38]];
    self.surfaceGradientLayer.colors = @[
        (__bridge id)liftedSurface.CGColor,
        (__bridge id)settledSurface.CGColor
    ];
    self.surfaceGradientLayer.locations = @[@0.0, @1.0];

    self.surfaceHighlightLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(darkMode ? 0.12 : 0.24)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    self.surfaceHighlightLayer.locations = @[@0.0, @0.42];

    self.accentLineView.backgroundColor = accent;
    self.iconPlateView.backgroundColor = plateFill;
    [self.iconPlateView pp_setBorderColor:plateStroke];
    self.iconView.tintColor = accent;

    self.titleLabel.textColor = titleColor;

    self.accessoryPlateView.backgroundColor = [baseSurface colorWithAlphaComponent:darkMode ? 0.62 : 0.86];
    [self.accessoryPlateView pp_setBorderColor:[accent colorWithAlphaComponent:(darkMode ? 0.20 : 0.14)]];
    self.accessoryIconView.tintColor = secondaryColor;

    [self.actionButton pp_setShadowColor:[accent colorWithAlphaComponent:darkMode ? 0.30 : 0.18]];
    self.actionButton.layer.shadowOpacity = darkMode ? 0.14f : 0.07f;
    self.actionButton.layer.shadowRadius = darkMode ? 16.0f : 12.0f;
    self.actionButton.layer.shadowOffset = CGSizeMake(0.0, darkMode ? 8.0 : 6.0);
}

- (UIColor *)pp_defaultAccentColor
{
    return AppPrimaryClr ?: PPHomeActionDynamicColor([UIColor colorWithRed:0.94 green:0.53 blue:0.31 alpha:1.0],
                                                     [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0]);
}

- (UIColor *)pp_signalColorForQuickActionType:(PPHomeQuickActionType)type
{
    switch (type) {
        case PPHomeQuickActionTypeNearestVet:
            return PPHomeActionDynamicColor([UIColor colorWithRed:0.23 green:0.62 blue:0.86 alpha:1.0],
                                            [UIColor colorWithRed:0.47 green:0.76 blue:0.98 alpha:1.0]);
        case PPHomeQuickActionTypeSellPet:
            return PPHomeActionDynamicColor([UIColor colorWithRed:0.93 green:0.49 blue:0.26 alpha:1.0],
                                            [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0]);
        case PPHomeQuickActionTypeAdopt:
            return PPHomeActionDynamicColor([UIColor colorWithRed:0.88 green:0.35 blue:0.48 alpha:1.0],
                                            [UIColor colorWithRed:0.96 green:0.60 blue:0.72 alpha:1.0]);
        case PPHomeQuickActionTypeAddAd:
            return PPHomeActionDynamicColor([UIColor colorWithRed:0.32 green:0.57 blue:0.92 alpha:1.0],
                                            [UIColor colorWithRed:0.56 green:0.75 blue:0.98 alpha:1.0]);
        case PPHomeQuickActionTypeRequestService:
            return PPHomeActionDynamicColor([UIColor colorWithRed:0.31 green:0.69 blue:0.54 alpha:1.0],
                                            [UIColor colorWithRed:0.56 green:0.86 blue:0.72 alpha:1.0]);
    }
}

- (UIColor *)pp_signalColorForIconName:(NSString *)iconName
{
    NSString *safeIconName = PPSafeString(iconName);
    if ([safeIconName containsString:@"hourglass"]) {
        return PPHomeActionDynamicColor([UIColor colorWithRed:0.73 green:0.60 blue:0.31 alpha:1.0],
                                        [UIColor colorWithRed:0.92 green:0.76 blue:0.45 alpha:1.0]);
    }
    if ([safeIconName containsString:@"slash"] || [safeIconName containsString:@"wrench"]) {
        return PPHomeActionDynamicColor([UIColor colorWithRed:0.41 green:0.56 blue:0.84 alpha:1.0],
                                        [UIColor colorWithRed:0.63 green:0.78 blue:0.98 alpha:1.0]);
    }
    return [self pp_defaultAccentColor];
}

#pragma mark - Interaction

- (void)pp_handleTap
{
    if (self.onTap) {
        self.onTap();
    }
}

- (void)pp_handleTouchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.actionButton.alpha = 0.96;
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.actionButton.transform = CGAffineTransformMakeScale(0.988, 0.988);
        self.actionButton.alpha = 0.97;
        self.surfaceView.transform = CGAffineTransformMakeTranslation(0.0, 1.0);
        self.iconPlateView.transform = CGAffineTransformMakeScale(0.96, 0.96);
        self.accessoryPlateView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:nil];
}

- (void)pp_handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_resetInteractiveState];
        return;
    }

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        [self pp_resetInteractiveState];
    } completion:nil];
}

- (void)pp_resetInteractiveState
{
    self.actionButton.transform = CGAffineTransformIdentity;
    self.actionButton.alpha = 1.0;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.iconPlateView.transform = CGAffineTransformIdentity;
    self.accessoryPlateView.transform = CGAffineTransformIdentity;
}

- (void)pp_updateAccessoryState
{
    BOOL interactive = (self.onTap != nil);
    self.actionButton.enabled = interactive;
    self.accessoryPlateView.hidden = !interactive;
    self.accessoryIconView.hidden = !interactive;

    if (!interactive) {
        return;
    }

    UIImage *accessoryImage = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:11.5
                                                           weight:UIImageSymbolWeightSemibold
                                                            scale:UIImageSymbolScaleSmall];
        accessoryImage =
            [UIImage systemImageNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                     withConfiguration:configuration];
    }
    self.accessoryIconView.image = [accessoryImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark - Accessibility

- (void)pp_updateAccessibility
{
    NSString *title = PPSafeString(self.currentTitle);
    self.actionButton.accessibilityLabel = title;
    self.actionButton.accessibilityHint = self.onTap ? nil : @"";
    self.actionButton.accessibilityTraits = self.onTap
        ? UIAccessibilityTraitButton
        : UIAccessibilityTraitStaticText;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.surfaceGradientLayer.frame = self.surfaceView.bounds;
    self.surfaceHighlightLayer.frame = self.surfaceView.bounds;
    self.actionButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.actionButton.bounds
                                   cornerRadius:PPHomeActionCellCornerRadius].CGPath;
}

- (CGFloat)pp_preferredWidth
{
    NSString *safeTitle = PPSafeString(self.currentTitle);
    if (safeTitle.length == 0) {
        return 132.0;
    }

    UIFont *font = self.titleLabel.font ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    CGRect titleBounds =
        [safeTitle boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                             attributes:@{ NSFontAttributeName: font }
                                context:nil];

    CGFloat fixedWidth =
        10.0 + PPHomeActionCellAccentWidth + 10.0 +
        PPHomeActionCellIconPlateSize + 10.0 +
        8.0 + PPHomeActionCellAccessoryPlateSize + PPHomeActionCellTrailingPadding;
    return ceil(MAX(132.0, fixedWidth + CGRectGetWidth(titleBounds)));
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    UICollectionViewLayoutAttributes *attributes = [layoutAttributes copy];
    CGRect frame = attributes.frame;
    frame.size.width = [self pp_preferredWidth];
    frame.size.height = MAX(frame.size.height, PPHomeActionCellMinimumHeight);
    attributes.frame = frame;
    return attributes;
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTap = nil;
    self.currentTitle = nil;
    self.currentIconName = nil;
    self.currentAccentColor = nil;
    self.titleLabel.text = nil;
    self.iconView.image = nil;
    self.accessoryIconView.image = nil;
    self.actionButton.accessibilityLabel = nil;
    [self pp_resetInteractiveState];
    [self pp_applyTheme];
}

- (void)setOnTap:(void (^)(void))onTap
{
    _onTap = [onTap copy];
    [self pp_updateAccessoryState];
    [self pp_updateAccessibility];
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
