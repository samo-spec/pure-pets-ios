//
//  PPHomeProviderUnifiedCategoryCardCell.m
//  Pure Pets
//

#import "PPHomeProviderUnifiedCategoryCardCell.h"
#import "PPMarketplaceHeroCardStyle.h"
#import "PetCareHelpers.h"

BOOL PPHomeUseUnifiedProviderCategoryCard = YES;

static UIColor *PPHomeUnifiedProviderDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIColor *PPHomeUnifiedProviderResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traitCollection];
    }
    return color;
}

static UIColor *PPHomeUnifiedProviderMarketplaceHeroAccentColor(void)
{
    return PPPetCareAccentColor() ?: PPMarketplaceHeroCardAccentColor();
}

#pragma mark - Premium Custom Subviews

@interface PPHomeFadingSeparatorView : UIView
- (void)updateColors:(UIColor *)color;
@end

@implementation PPHomeFadingSeparatorView

+ (Class)layerClass {
    return [CAGradientLayer class];
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = NO;
        CAGradientLayer *grad = (CAGradientLayer *)self.layer;
        grad.startPoint = CGPointMake(0.5, 0.0);
        grad.endPoint = CGPointMake(0.5, 1.0);
        grad.locations = @[@0.0, @0.5, @1.0];
    }
    return self;
}

- (void)updateColors:(UIColor *)color {
    CAGradientLayer *grad = (CAGradientLayer *)self.layer;
    grad.colors = @[
        (id)UIColor.clearColor.CGColor,
        (id)color.CGColor,
        (id)UIColor.clearColor.CGColor
    ];
}

@end

@interface PPHomeIconPlateView : UIView
- (void)updateGradientWithBaseColor:(UIColor *)baseColor isDark:(BOOL)isDark;
@end

@implementation PPHomeIconPlateView

+ (Class)layerClass {
    return [CAGradientLayer class];
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = NO;
        self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        if (@available(iOS 13.0, *)) {
            self.layer.cornerCurve = kCACornerCurveContinuous;
        }
        CAGradientLayer *grad = (CAGradientLayer *)self.layer;
        grad.startPoint = CGPointMake(0.0, 0.0);
        grad.endPoint = CGPointMake(0.0, 1.0);
    }
    return self;
}

- (void)updateGradientWithBaseColor:(UIColor *)baseColor isDark:(BOOL)isDark {
    CAGradientLayer *grad = (CAGradientLayer *)self.layer;
    UIColor *topColor = [baseColor colorWithAlphaComponent:isDark ? 0.20 : 0.11];
    UIColor *bottomColor = [baseColor colorWithAlphaComponent:isDark ? 0.10 : 0.045];
    grad.colors = @[(id)topColor.CGColor, (id)bottomColor.CGColor];
}

@end

#pragma mark - Button

@interface PPHomeProviderUnifiedCategorySectionButton : UIControl

@property (nonatomic, strong, nullable) PPHomeProviderCategoryItem *item;
@property (nonatomic, copy, nullable) void (^onTap)(PPHomeProviderCategoryItem *item);

- (void)configureWithItem:(nullable PPHomeProviderCategoryItem *)item;
- (void)refreshStyle;
- (void)resetPresentation;

@end

@implementation PPHomeProviderUnifiedCategorySectionButton {
    UIView *_pressedOverlayView;
    PPHomeIconPlateView *_iconPlateView;
    UIImageView *_iconView;
    UIStackView *_textStackView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_chevronImageView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildUI];
    [self pp_applyTypography];
    [self refreshStyle];
    return self;
}

- (void)pp_buildUI
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    [self addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDragEnter];
    [self addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchDragExit];
    [self addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];

    _pressedOverlayView = [[UIView alloc] init];
    _pressedOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    _pressedOverlayView.userInteractionEnabled = NO;
    _pressedOverlayView.alpha = 0.0;
    [self addSubview:_pressedOverlayView];

    _iconPlateView = [[PPHomeIconPlateView alloc] init];
    [self addSubview:_iconPlateView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.userInteractionEnabled = NO;
    _iconView.isAccessibilityElement = NO;
    [_iconPlateView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.90;
    _titleLabel.userInteractionEnabled = NO;
    _titleLabel.isAccessibilityElement = NO;
    if (@available(iOS 11.0, *)) {
        _titleLabel.adjustsFontForContentSizeCategory = YES;
    }

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.userInteractionEnabled = NO;
    _subtitleLabel.isAccessibilityElement = NO;
    if (@available(iOS 11.0, *)) {
        _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    }

    _textStackView = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _subtitleLabel]];
    _textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _textStackView.axis = UILayoutConstraintAxisVertical;
    _textStackView.alignment = UIStackViewAlignmentFill;
    _textStackView.distribution = UIStackViewDistributionFill;
    _textStackView.spacing = 5.0;
    _textStackView.userInteractionEnabled = NO;
    _textStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self addSubview:_textStackView];

    _chevronImageView = [[UIImageView alloc] init];
    _chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronImageView.contentMode = UIViewContentModeScaleAspectFit;
    _chevronImageView.userInteractionEnabled = NO;
    _chevronImageView.isAccessibilityElement = NO;
    [self addSubview:_chevronImageView];

    [_iconPlateView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_iconPlateView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_textStackView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [_pressedOverlayView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_pressedOverlayView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_pressedOverlayView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_pressedOverlayView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_iconPlateView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [_iconPlateView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_iconPlateView.widthAnchor constraintEqualToConstant:42.0],
        [_iconPlateView.heightAnchor constraintEqualToConstant:42.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:20.0],
        [_iconView.heightAnchor constraintEqualToConstant:20.0],

        [_chevronImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
        [_chevronImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_chevronImageView.widthAnchor constraintEqualToConstant:10.0],
        [_chevronImageView.heightAnchor constraintEqualToConstant:10.0],

        [_textStackView.leadingAnchor constraintEqualToAnchor:_iconPlateView.trailingAnchor constant:12.0],
        [_textStackView.trailingAnchor constraintEqualToAnchor:_chevronImageView.leadingAnchor constant:-8.0],
        [_textStackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_textStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:12.0],
        [_textStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-12.0],
    ]];
}

- (void)pp_applyTypography
{
    UIFont *titleBase = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    UIFont *subtitleBase = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];

    if (@available(iOS 11.0, *)) {
        _titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                            scaledFontForFont:titleBase
                            maximumPointSize:19.0];
        _subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                               scaledFontForFont:subtitleBase
                               maximumPointSize:14.0];
    } else {
        _titleLabel.font = titleBase;
        _subtitleLabel.font = subtitleBase;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat iconCornerRadius = 16.0;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _iconPlateView.layer.cornerRadius = iconCornerRadius;
    [CATransaction commit];
}

- (void)configureWithItem:(nullable PPHomeProviderCategoryItem *)item
{
    self.item = item;
    self.enabled = item != nil;
    self.alpha = item ? 1.0 : 0.46;
    self.accessibilityElementsHidden = item == nil;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _textStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;

    NSString *title = item ? (kLang(item.titleKey) ?: item.titleKey ?: @"") : @"";
    NSString *subtitle = item ? (kLang(item.subtitleKey) ?: item.subtitleKey ?: @"") : @"";
    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;
    _subtitleLabel.hidden = subtitle.length == 0;

    _iconView.image = item ? [[self pp_iconImageForItem:item] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;

    NSString *chevronSymbol = Language.isRTL ? @"chevron.left" : @"chevron.right";
    if (@available(iOS 13.0, *)) {
        _chevronImageView.image = [[UIImage systemImageNamed:chevronSymbol
                                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10.0
                                                                                                          weight:UIImageSymbolWeightBold]]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        _chevronImageView.image = [[UIImage imageNamed:chevronSymbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _chevronImageView.hidden = item == nil;

    NSMutableArray<NSString *> *accessibilityComponents = [NSMutableArray array];
    if (title.length > 0) {
        [accessibilityComponents addObject:title];
    }
    if (subtitle.length > 0) {
        [accessibilityComponents addObject:subtitle];
    }
    self.accessibilityLabel = [accessibilityComponents componentsJoinedByString:@". "];
    self.accessibilityIdentifier = [NSString stringWithFormat:@"home.providerUnifiedCategory.%@", item.identifier ?: @"unknown"];
    self.accessibilityTraits = UIAccessibilityTraitButton;

    [self refreshStyle];
    [self resetPresentation];
}

- (UIImage *)pp_iconImageForItem:(nullable PPHomeProviderCategoryItem *)item
{
    NSString *iconName = [item.systemIconName isKindOfClass:NSString.class]
        ? [item.systemIconName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    if (iconName.length == 0) {
        iconName = @"square.grid.2x2.fill";
    }

    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                            weight:UIImageSymbolWeightSemibold
                                                              scale:UIImageSymbolScaleMedium];
        image = [UIImage systemImageNamed:iconName withConfiguration:configuration];
    }
    if (!image) {
        image = [UIImage imageNamed:iconName];
    }
    if(!image)
    {
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:@"square.grid.2x2.fill"
                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                             weight:UIImageSymbolWeightSemibold]];
        }
    }

    return image ?: [UIImage new];
}

- (void)refreshStyle
{
    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPHomeUnifiedProviderMarketplaceHeroAccentColor();
    UIColor *titleColor = PPMarketplaceHeroCardPrimaryTextColor();
    UIColor *subtitleColor = PPMarketplaceHeroCardSecondaryTextColor();
    UIColor *iconBorder = PPMarketplaceHeroCardStrokeColor(self.traitCollection);
    UIColor *pressedTint = [accent colorWithAlphaComponent:darkMode ? 0.14 : 0.075];

    _titleLabel.textColor = titleColor;
    _subtitleLabel.textColor = subtitleColor;
    _iconView.tintColor = accent;
    _chevronImageView.tintColor = [subtitleColor colorWithAlphaComponent:0.62];

    [_iconPlateView updateGradientWithBaseColor:accent isDark:darkMode];
    _iconPlateView.layer.borderColor = iconBorder.CGColor;
    _pressedOverlayView.backgroundColor = pressedTint;
}

- (void)resetPresentation
{
    self.transform = CGAffineTransformIdentity;
    _pressedOverlayView.alpha = 0.0;
}

- (void)pp_handleTouchDown
{
    if (!self.enabled || UIAccessibilityIsReduceMotionEnabled()) {
        _pressedOverlayView.alpha = self.enabled ? 0.95 : 0.0;
        return;
    }

    [UIView animateWithDuration:0.08
                          delay:0.0
                         options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                      animations:^{
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
        self->_pressedOverlayView.alpha = 1.0;
    } completion:nil];
}

- (void)pp_handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self resetPresentation];
        return;
    }

    [UIView animateWithDuration:0.26
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.40
                         options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                      animations:^{
        [self resetPresentation];
    } completion:nil];
}

- (void)pp_handleTap
{
    if (self.onTap && [self.item isKindOfClass:PPHomeProviderCategoryItem.class]) {
        self.onTap(self.item);
    }
}

@end

#pragma mark - Unified Card Cell

@implementation PPHomeProviderUnifiedCategoryCardCell {
    UIView *_surfaceView;
    PPHomeProviderUnifiedCategorySectionButton *_leftButton;
    PPHomeProviderUnifiedCategorySectionButton *_rightButton;
    PPHomeFadingSeparatorView *_separatorView;
    CAGradientLayer *_surfaceGradientLayer;
    UIView *_leftTopAccentView;
    UIView *_rightTopAccentView;
    UIView *_ambientGlowView;
    UIView *_ambientSupportGlowView;
}

+ (NSString *)reuseIdentifier
{
    return @"PPHomeProviderUnifiedCategoryCardCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildUI];
    [self pp_applyStyle];
    return self;
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.clipsToBounds = YES;
    _surfaceView.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:_surfaceView];

    _surfaceGradientLayer = [CAGradientLayer layer];
    _surfaceGradientLayer.drawsAsynchronously = YES;
    [_surfaceView.layer insertSublayer:_surfaceGradientLayer atIndex:0];

    _ambientGlowView = [[UIView alloc] init];
    _ambientGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    _ambientGlowView.userInteractionEnabled = NO;
    _ambientGlowView.layer.cornerRadius = 58.0;
    _ambientGlowView.hidden = YES;
    [self.contentView insertSubview:_ambientGlowView belowSubview:_surfaceView];

    _ambientSupportGlowView = [[UIView alloc] init];
    _ambientSupportGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    _ambientSupportGlowView.userInteractionEnabled = NO;
    _ambientSupportGlowView.layer.cornerRadius = 66.0;

    _ambientSupportGlowView.hidden = YES;
    [self.contentView insertSubview:_ambientSupportGlowView belowSubview:_surfaceView];

    _leftButton = [[PPHomeProviderUnifiedCategorySectionButton alloc] initWithFrame:CGRectZero];
    _rightButton = [[PPHomeProviderUnifiedCategorySectionButton alloc] initWithFrame:CGRectZero];
    [_surfaceView addSubview:_leftButton];
    [_surfaceView addSubview:_rightButton];

    _leftTopAccentView = [[UIView alloc] init];
    _leftTopAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    _leftTopAccentView.userInteractionEnabled = NO;
    _leftTopAccentView.layer.cornerRadius = 2.0;
    if (@available(iOS 13.0, *)) {
        _leftTopAccentView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_leftTopAccentView];

    _rightTopAccentView = [[UIView alloc] init];
    _rightTopAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    _rightTopAccentView.userInteractionEnabled = NO;
    _rightTopAccentView.layer.cornerRadius = 2.0;
    if (@available(iOS 13.0, *)) {
        _rightTopAccentView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_rightTopAccentView];

    _separatorView = [[PPHomeFadingSeparatorView alloc] init];
    [_surfaceView addSubview:_separatorView];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_surfaceView.leftAnchor constraintEqualToAnchor:self.contentView.leftAnchor],
        [_surfaceView.rightAnchor constraintEqualToAnchor:self.contentView.rightAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_ambientGlowView.widthAnchor constraintEqualToConstant:116.0],
        [_ambientGlowView.heightAnchor constraintEqualToConstant:116.0],
        [_ambientGlowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:-34.0],
        [_ambientGlowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:Language.isRTL ? 22.0 : -12.0],

        [_ambientSupportGlowView.widthAnchor constraintEqualToConstant:132.0],
        [_ambientSupportGlowView.heightAnchor constraintEqualToConstant:132.0],
        [_ambientSupportGlowView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:48.0],
        [_ambientSupportGlowView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:Language.isRTL ? -26.0 : 28.0],

        [_leftButton.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_leftButton.leftAnchor constraintEqualToAnchor:_surfaceView.leftAnchor],
        [_leftButton.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor],

        [_rightButton.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_rightButton.leftAnchor constraintEqualToAnchor:_leftButton.rightAnchor],
        [_rightButton.rightAnchor constraintEqualToAnchor:_surfaceView.rightAnchor],
        [_rightButton.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor],
        [_leftButton.widthAnchor constraintEqualToAnchor:_rightButton.widthAnchor],

        [_leftTopAccentView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_leftTopAccentView.centerXAnchor constraintEqualToAnchor:_leftButton.centerXAnchor],
        [_leftTopAccentView.widthAnchor constraintEqualToConstant:44.0],
        [_leftTopAccentView.heightAnchor constraintEqualToConstant:4.0],

        [_rightTopAccentView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_rightTopAccentView.centerXAnchor constraintEqualToAnchor:_rightButton.centerXAnchor],
        [_rightTopAccentView.widthAnchor constraintEqualToConstant:44.0],
        [_rightTopAccentView.heightAnchor constraintEqualToConstant:4.0],

        [_separatorView.centerXAnchor constraintEqualToAnchor:_surfaceView.centerXAnchor],
        [_separatorView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_separatorView.widthAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        [_separatorView.heightAnchor constraintEqualToConstant:58.0],
    ]];

    self.isAccessibilityElement = NO;
    self.accessibilityElements = @[_leftButton, _rightButton];
}

- (void)pp_updateSurfaceGradientLayout
{
    CGFloat cornerRadius = 24.0;
    [self.contentView layoutIfNeeded];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceView.layer.cornerRadius = cornerRadius;
    CGRect surfaceBounds = _surfaceView.bounds;
    BOOL hasValidSurfaceBounds = !CGRectIsEmpty(surfaceBounds) &&
                                 isfinite((double)CGRectGetWidth(surfaceBounds)) &&
                                 isfinite((double)CGRectGetHeight(surfaceBounds));
    _surfaceGradientLayer.frame = hasValidSurfaceBounds ? surfaceBounds : CGRectZero;
    _surfaceGradientLayer.cornerRadius = cornerRadius;

    CGRect surfaceFrame = _surfaceView.frame;
    if (!CGRectIsEmpty(surfaceFrame)) {
        self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                           cornerRadius:cornerRadius].CGPath;
    } else {
        self.layer.shadowPath = nil;
    }
    [CATransaction commit];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_updateSurfaceGradientLayout];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self pp_updateSurfaceGradientLayout];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self setNeedsLayout];
        [self.contentView setNeedsLayout];
        [self pp_updateSurfaceGradientLayout];
        [self pp_startAmbientMotionIfNeeded];
    } else {
        [self pp_stopAmbientMotion];
    }
}

- (void)pp_startAmbientMotionIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopAmbientMotion];
        return;
    }
    if (!self.window || CGRectIsEmpty(self.bounds)) {
        return;
    }

    if (![_ambientGlowView.layer animationForKey:@"pp.home.providerUnified.glow"]) {
        CABasicAnimation *glowDriftX = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        glowDriftX.fromValue = @0.0;
        glowDriftX.toValue = @(Language.isRTL ? -20.0 : 20.0);

        CABasicAnimation *glowDriftY = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        glowDriftY.fromValue = @0.0;
        glowDriftY.toValue = @16.0;

        CAAnimationGroup *glowDrift = [CAAnimationGroup animation];
        glowDrift.animations = @[glowDriftX, glowDriftY];
        glowDrift.duration = 3.8;
        glowDrift.autoreverses = YES;
        glowDrift.repeatCount = HUGE_VALF;
        glowDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        glowDrift.removedOnCompletion = YES;
        [_ambientGlowView.layer addAnimation:glowDrift forKey:@"pp.home.providerUnified.glow"];
    }

    [self pp_applyBreathingGlowToView:_ambientGlowView
                                  key:@"pp.home.providerUnified.topGlowBreath"
                            fromAlpha:0.54
                              toAlpha:0.90
                            fromScale:0.90
                              toScale:1.18
                             duration:3.7];

    [self pp_applyBreathingGlowToView:_ambientSupportGlowView
                                  key:@"pp.home.providerUnified.supportGlowBreath"
                            fromAlpha:0.66
                              toAlpha:0.98
                            fromScale:0.94
                              toScale:1.08
                             duration:4.1];
}

- (void)pp_stopAmbientMotion
{
    [_ambientGlowView.layer removeAllAnimations];
    [_ambientSupportGlowView.layer removeAllAnimations];
}

- (void)pp_applyBreathingGlowToView:(UIView *)view
                                key:(NSString *)key
                          fromAlpha:(CGFloat)fromAlpha
                            toAlpha:(CGFloat)toAlpha
                          fromScale:(CGFloat)fromScale
                            toScale:(CGFloat)toScale
                           duration:(CFTimeInterval)duration
{
    if (!view || [view.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @(fromAlpha);
    opacityAnimation.toValue = @(toAlpha);

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @(fromScale);
    scaleAnimation.toValue = @(toScale);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[opacityAnimation, scaleAnimation];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    group.removedOnCompletion = YES;
    [view.layer addAnimation:group forKey:key];
}

- (void)configureWithLeftItem:(nullable PPHomeProviderCategoryItem *)leftItem
                    rightItem:(nullable PPHomeProviderCategoryItem *)rightItem
{
    __weak typeof(self) weakSelf = self;
    _leftButton.onTap = ^(PPHomeProviderCategoryItem *item) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.onTap) {
            return;
        }
        self.onTap(item);
    };
    _rightButton.onTap = _leftButton.onTap;

    [_leftButton configureWithItem:leftItem];
    [_rightButton configureWithItem:rightItem];
    self.accessibilityElements = @[_leftButton, _rightButton];
    [self pp_applyStyle];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self pp_updateSurfaceGradientLayout];
}

- (void)pp_applyStyle
{
    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *primaryAccent = PPHomeUnifiedProviderMarketplaceHeroAccentColor();
    UIColor *surfaceBase = PPMarketplaceHeroCardSurfaceBaseColor(self.traitCollection);
    UIColor *surfaceHighlight = PPMarketplaceHeroCardBlend(surfaceBase,
                                                          UIColor.whiteColor,
                                                          darkMode ? 0.08 : 0.20,
                                                          self.traitCollection);
    UIColor *backgroundAccent = PPMarketplaceHeroCardBlend(primaryAccent,
                                                          surfaceBase,
                                                          darkMode ? 0.12 : 0.18,
                                                          self.traitCollection);
    UIColor *surfaceTint = PPMarketplaceHeroCardBlend(surfaceBase,
                                                     backgroundAccent,
                                                     darkMode ? 0.095 : 0.038,
                                                     self.traitCollection);
    UIColor *surfaceTail = PPMarketplaceHeroCardBlend(surfaceTint,
                                                     backgroundAccent,
                                                     darkMode ? 0.062 : 0.024,
                                                     self.traitCollection);
    UIColor *stroke = [UIColor.whiteColor colorWithAlphaComponent:darkMode ? 0.12 : 0.78];

    _surfaceView.backgroundColor = UIColor.clearColor;
    _surfaceView.layer.borderColor = stroke.CGColor;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceGradientLayer.opacity = darkMode ? 0.84 : 0.66;
    _surfaceGradientLayer.colors = @[
        (id)PPMarketplaceHeroCardResolvedColor(surfaceHighlight, self.traitCollection).CGColor,
        (id)PPMarketplaceHeroCardResolvedColor(surfaceTint, self.traitCollection).CGColor,
        (id)PPMarketplaceHeroCardResolvedColor(surfaceTail, self.traitCollection).CGColor
    ];
    _surfaceGradientLayer.locations = @[@0.0, @0.56, @1.0];
    _surfaceGradientLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    _surfaceGradientLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
    [CATransaction commit];
    [self pp_updateSurfaceGradientLayout];

    UIColor *topAccentColor = [primaryAccent colorWithAlphaComponent:0.58];
    _leftTopAccentView.backgroundColor = topAccentColor;
    _rightTopAccentView.backgroundColor = topAccentColor;

    UIColor *orbColor = [backgroundAccent colorWithAlphaComponent:darkMode ? 0.17 : 0.11];
    _ambientGlowView.backgroundColor = orbColor;

    UIColor *supportGlowColor = PPMarketplaceHeroCardBlend(backgroundAccent,
                                                          PPMarketplaceHeroCardColor(0x00F5D4, 1.0),
                                                          darkMode ? 0.18 : 0.22,
                                                          self.traitCollection);
    _ambientSupportGlowView.backgroundColor = [supportGlowColor colorWithAlphaComponent:darkMode ? 0.12 : 0.095];

    UIColor *separatorColor = PPHomeUnifiedProviderDynamicColor([UIColor colorWithRed:0.805 green:0.710 blue:0.748 alpha:0.35],
                                                                [AppPrimaryClr colorWithAlphaComponent:0.18]);
    [_separatorView updateColors:separatorColor];

    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.08f;
    self.layer.shadowRadius = 20.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    [_leftButton refreshStyle];
    [_rightButton refreshStyle];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self pp_stopAmbientMotion];
    self.onTap = nil;
    _leftButton.onTap = nil;
    _rightButton.onTap = nil;
    [_leftButton configureWithItem:nil];
    [_rightButton configureWithItem:nil];
    [_leftButton resetPresentation];
    [_rightButton resetPresentation];
    self.accessibilityElements = @[_leftButton, _rightButton];
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    return layoutAttributes;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyStyle];
        }
    }
}

@end
