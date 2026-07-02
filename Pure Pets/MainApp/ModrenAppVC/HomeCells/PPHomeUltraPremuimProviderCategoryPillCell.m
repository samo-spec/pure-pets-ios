//
//  PPHomeUltraPremuimProviderCategoryPillCell.m
//  Pure Pets
//

#import "PPHomeUltraPremuimProviderCategoryPillCell.h"
#import "PPHomeProviderCategoryPillCell.h"

static UIColor *PPHomeUltraProviderDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIColor *PPHomeUltraProviderResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traitCollection];
    }
    return color;
}

static UIColor *PPHomeUltraProviderBlend(UIColor *baseColor,
                                         UIColor *overlayColor,
                                         CGFloat amount,
                                         UITraitCollection *traitCollection)
{
    UIColor *base = PPHomeUltraProviderResolvedColor(baseColor, traitCollection);
    UIColor *overlay = PPHomeUltraProviderResolvedColor(overlayColor, traitCollection);

    CGFloat baseRed = 0.0, baseGreen = 0.0, baseBlue = 0.0, baseAlpha = 0.0;
    CGFloat overlayRed = 0.0, overlayGreen = 0.0, overlayBlue = 0.0, overlayAlpha = 0.0;
    if (![base getRed:&baseRed green:&baseGreen blue:&baseBlue alpha:&baseAlpha] ||
        ![overlay getRed:&overlayRed green:&overlayGreen blue:&overlayBlue alpha:&overlayAlpha]) {
        return baseColor ?: overlayColor ?: UIColor.clearColor;
    }

    CGFloat t = MIN(MAX(amount, 0.0), 1.0);
    return [UIColor colorWithRed:(baseRed * (1.0 - t)) + (overlayRed * t)
                           green:(baseGreen * (1.0 - t)) + (overlayGreen * t)
                            blue:(baseBlue * (1.0 - t)) + (overlayBlue * t)
                           alpha:(baseAlpha * (1.0 - t)) + (overlayAlpha * t)];
}

static UIColor *PPHomeUltraProviderBrandAccent(void)
{
    return AppPrimaryClr ?: PPHomeUltraProviderDynamicColor([UIColor colorWithRed:0.922 green:0.208 blue:0.486 alpha:1.0],
                                                            [UIColor colorWithRed:0.996 green:0.525 blue:0.690 alpha:1.0]);
}

static UIColor *PPHomeUltraProviderAccentColorForItem(PPHomeProviderCategoryItem *item,
                                                      UITraitCollection *traitCollection)
{
    UIColor *brand = PPHomeUltraProviderBrandAccent();
    NSString *identifier = item.identifier ?: @"";
    if ([identifier isEqualToString:@"pharmacy"]) {
        return PPHomeUltraProviderBlend(brand,
                                        PPHomeUltraProviderDynamicColor([UIColor colorWithRed:0.447 green:0.651 blue:0.988 alpha:1.0],
                                                                        [UIColor colorWithRed:0.525 green:0.765 blue:0.992 alpha:1.0]),
                                        0.18,
                                        traitCollection);
    }
    return PPHomeUltraProviderBlend(brand,
                                    PPHomeUltraProviderDynamicColor([UIColor colorWithRed:0.996 green:0.655 blue:0.404 alpha:1.0],
                                                                    [UIColor colorWithRed:0.996 green:0.765 blue:0.518 alpha:1.0]),
                                    0.06,
                                    traitCollection);
}

@implementation PPHomeUltraPremuimProviderCategoryPillCell {
    UIButton *_button;
    UIView *_surfaceView;
    CAGradientLayer *_surfaceGradientLayer;
    CAShapeLayer *_surfaceLiquidBorderLayer;
    UIView *_ambientOrbView;
    UIView *_accentBarView;
    UIView *_iconPlateView;
    UIImageView *_iconView;
    UIStackView *_textStackView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIView *_chevronPlateView;
    UIImageView *_chevronView;
    PPHomeProviderCategoryItem *_item;
    BOOL _selectedState;
}

+ (NSString *)reuseIdentifier
{
    return @"PPHomeUltraPremuimProviderCategoryPillCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildUI];
    [self pp_applyTypography];
    [self pp_applySelection:NO animated:NO];
    return self;
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    _button = [UIButton buttonWithType:UIButtonTypeCustom];
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    _button.adjustsImageWhenHighlighted = NO;
    _button.backgroundColor = UIColor.clearColor;
    _button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [_button addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [_button addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [_button addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [_button addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [_button addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.contentView addSubview:_button];

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.userInteractionEnabled = NO;
    _surfaceView.clipsToBounds = YES;
    _surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_button addSubview:_surfaceView];

    _surfaceGradientLayer = [CAGradientLayer layer];
    _surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_surfaceView.layer insertSublayer:_surfaceGradientLayer atIndex:0];

    _surfaceLiquidBorderLayer = [CAShapeLayer layer];
    _surfaceLiquidBorderLayer.fillColor = UIColor.clearColor.CGColor;
    _surfaceLiquidBorderLayer.lineWidth = 0.85;
    [_surfaceView.layer addSublayer:_surfaceLiquidBorderLayer];

    _ambientOrbView = [[UIView alloc] init];
    _ambientOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _ambientOrbView.userInteractionEnabled = NO;
    _ambientOrbView.alpha = 0.0;
    if (@available(iOS 13.0, *)) {
        _ambientOrbView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_ambientOrbView];

    _accentBarView = [[UIView alloc] init];
    _accentBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _accentBarView.userInteractionEnabled = NO;
    if (@available(iOS 13.0, *)) {
        _accentBarView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_accentBarView];

    _iconPlateView = [[UIView alloc] init];
    _iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconPlateView.userInteractionEnabled = NO;
    _iconPlateView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    if (@available(iOS 13.0, *)) {
        _iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_iconPlateView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.userInteractionEnabled = NO;
    [_iconPlateView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.textAlignment = NSTextAlignmentNatural;
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.86;
    _titleLabel.userInteractionEnabled = NO;
    if (@available(iOS 11.0, *)) {
        _titleLabel.adjustsFontForContentSizeCategory = YES;
    }

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.textAlignment = NSTextAlignmentNatural;
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.adjustsFontSizeToFitWidth = YES;
    _subtitleLabel.minimumScaleFactor = 0.88;
    _subtitleLabel.userInteractionEnabled = NO;
    if (@available(iOS 11.0, *)) {
        _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    }

    _textStackView = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _subtitleLabel]];
    _textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _textStackView.axis = UILayoutConstraintAxisVertical;
    _textStackView.alignment = UIStackViewAlignmentFill;
    _textStackView.distribution = UIStackViewDistributionFill;
    _textStackView.spacing = 1.0;
    _textStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [_surfaceView addSubview:_textStackView];

    _chevronPlateView = [[UIView alloc] init];
    _chevronPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronPlateView.userInteractionEnabled = NO;
    _chevronPlateView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    if (@available(iOS 13.0, *)) {
        _chevronPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_chevronPlateView];

    _chevronView = [[UIImageView alloc] init];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    _chevronView.userInteractionEnabled = NO;
    [_chevronPlateView addSubview:_chevronView];

    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    //[_subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    //[_textStackView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_chevronPlateView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_chevronPlateView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [_button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_button.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_surfaceView.topAnchor constraintEqualToAnchor:_button.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:_button.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:_button.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:_button.bottomAnchor],

        [_ambientOrbView.widthAnchor constraintEqualToConstant:72.0],
        [_ambientOrbView.heightAnchor constraintEqualToConstant:72.0],
        [_ambientOrbView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:20.0],
        [_ambientOrbView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor constant:-16.0],

        [_iconPlateView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:12.0],
        [_iconPlateView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_iconPlateView.widthAnchor constraintEqualToConstant:40.0],
        [_iconPlateView.heightAnchor constraintEqualToConstant:40.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:19.0],
        [_iconView.heightAnchor constraintEqualToConstant:19.0],

        [_chevronPlateView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-12.0],
        [_chevronPlateView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_chevronPlateView.widthAnchor constraintEqualToConstant:30.0],
        [_chevronPlateView.heightAnchor constraintEqualToConstant:30.0],

        [_chevronView.centerXAnchor constraintEqualToAnchor:_chevronPlateView.centerXAnchor],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_chevronPlateView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:12.0],
        [_chevronView.heightAnchor constraintEqualToConstant:12.0],

        [_textStackView.leadingAnchor constraintEqualToAnchor:_iconPlateView.trailingAnchor constant:12.0],
        [_textStackView.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronPlateView.leadingAnchor constant:-10.0],
        [_textStackView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor constant:1.0],
        [_textStackView.topAnchor constraintGreaterThanOrEqualToAnchor:_surfaceView.topAnchor constant:10.0],
        [_textStackView.bottomAnchor constraintLessThanOrEqualToAnchor:_surfaceView.bottomAnchor constant:-9.0],

        [_accentBarView.leadingAnchor constraintEqualToAnchor:_textStackView.leadingAnchor],
        [_accentBarView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:10.0],
        [_accentBarView.widthAnchor constraintEqualToConstant:24.0],
        [_accentBarView.heightAnchor constraintEqualToConstant:3.0],
    ]];

    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.055;
    self.layer.shadowRadius = 14.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 8.0);
}

- (void)pp_applyTypography
{
    UIFont *titleBase = [GM boldFontWithSize:15.5] ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    UIFont *subtitleBase = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];

    if (@available(iOS 11.0, *)) {
        _titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                            scaledFontForFont:titleBase
                            maximumPointSize:17.0];
        _subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                               scaledFontForFont:subtitleBase
                               maximumPointSize:12.5];
    } else {
        _titleLabel.font = titleBase;
        _subtitleLabel.font = subtitleBase;
    }
}

- (void)layoutSubviews
{
    [self.contentView layoutIfNeeded];
    [super layoutSubviews];

    CGFloat cornerRadius = 22.0;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceView.layer.cornerRadius = cornerRadius;
    _iconPlateView.layer.cornerRadius = 15.0;
    _chevronPlateView.layer.cornerRadius = CGRectGetHeight(_chevronPlateView.bounds) * 0.5;
    _accentBarView.layer.cornerRadius = CGRectGetHeight(_accentBarView.bounds) * 0.5;
    _ambientOrbView.layer.cornerRadius = CGRectGetWidth(_ambientOrbView.bounds) * 0.5;
    _surfaceGradientLayer.frame = _surfaceView.bounds;
    CGFloat highlightInset = 0.65;
    CGRect highlightBounds = CGRectInset(_surfaceView.bounds, highlightInset, highlightInset);
    _surfaceLiquidBorderLayer.frame = _surfaceView.bounds;
    _surfaceLiquidBorderLayer.path =
        [UIBezierPath bezierPathWithRoundedRect:highlightBounds
                                   cornerRadius:MAX(0.0, cornerRadius - highlightInset)].CGPath;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:cornerRadius].CGPath;
    [CATransaction commit];
}

- (void)configureWithItem:(PPHomeProviderCategoryItem *)item selected:(BOOL)selected
{
    if (!item) {
        item = [PPHomeProviderCategoryItem itemWithIdentifier:@"marketplace"
                                                     titleKey:@"provider_marketplace_title"
                                                  subtitleKey:@"provider_marketplace_subtitle"
                                                   systemIcon:@"pet-shop"
                                                        route:PPHomeProviderCategoryRouteServices];
    }

    _item = item;
    _selectedState = selected;

    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _textStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    NSString *title = kLang(item.titleKey) ?: item.titleKey ?: @"";
    NSString *subtitle = kLang(item.subtitleKey) ?: item.subtitleKey ?: @"";

    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;
    _subtitleLabel.hidden = subtitle.length == 0;

    _button.accessibilityIdentifier = [NSString stringWithFormat:@"home.providerCategory.%@", item.identifier ?: @"unknown"];
    _button.accessibilityLabel = title;
    _button.accessibilityHint = subtitle.length > 0 ? subtitle : nil;
    _button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);

    _iconView.image = [[self pp_iconImageForItem:item] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _chevronView.image = [[self pp_chevronImage] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self pp_applySelection:selected animated:NO];
}

- (UIImage *)pp_iconImageForItem:(PPHomeProviderCategoryItem *)item
{
    NSString *iconName = [item.systemIconName isKindOfClass:NSString.class]
        ? [item.systemIconName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (iconName.length == 0) {
        iconName = @"square.grid.2x2.fill";
    }
    if ([item.identifier isEqualToString:@"marketplace"]) {
        iconName = @"pet-shop";
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
    if (!image && @available(iOS 13.0, *)) {
        image = [UIImage systemImageNamed:@"square.grid.2x2.fill"
                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                        weight:UIImageSymbolWeightSemibold]];
    }
    return image ?: [UIImage new];
}

- (UIImage *)pp_chevronImage
{
    NSString *chevronName = Language.isRTL ? @"arrow.left" : @"arrow.right";
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        image = [UIImage systemImageNamed:chevronName
                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                        weight:UIImageSymbolWeightSemibold]];
    }
    return image ?: [UIImage imageNamed:chevronName];
}

- (void)pp_applySelection:(BOOL)selected animated:(BOOL)animated
{
    _selectedState = selected;

    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPHomeUltraProviderAccentColorForItem(_item ?: [PPHomeProviderCategoryItem new],
                                                            self.traitCollection);
    UIColor *surfaceBase = PPHomeUltraProviderDynamicColor([UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:0.62],
                                                           [UIColor colorWithWhite:0.104 alpha:0.28]);
    UIColor *surfaceHighlight = PPHomeUltraProviderBlend(surfaceBase,
                                                         UIColor.whiteColor,
                                                         darkMode ? 0.07 : 0.18,
                                                         self.traitCollection);
    UIColor *surfaceTint = PPHomeUltraProviderBlend(surfaceBase,
                                                    accent,
                                                    selected ? (darkMode ? 0.16 : 0.095) : (darkMode ? 0.10 : 0.048),
                                                    self.traitCollection);
    UIColor *titleColor = AppPrimaryTextClr ?: PPHomeUltraProviderDynamicColor([UIColor colorWithRed:0.110 green:0.110 blue:0.129 alpha:1.0],
                                                                                [UIColor colorWithWhite:0.965 alpha:1.0]);
    UIColor *subtitleColor = AppSecondaryTextClr ?: PPHomeUltraProviderDynamicColor([UIColor colorWithRed:0.446 green:0.458 blue:0.485 alpha:1.0],
                                                                                     [UIColor colorWithWhite:0.735 alpha:1.0]);
    UIColor *iconPlateColor = [accent colorWithAlphaComponent:selected ? (darkMode ? 0.24 : 0.14) : (darkMode ? 0.16 : 0.08)];
    UIColor *chevronPlateColor = PPHomeUltraProviderBlend(surfaceBase,
                                                          accent,
                                                          selected ? (darkMode ? 0.18 : 0.09) : (darkMode ? 0.11 : 0.04),
                                                          self.traitCollection);

    UIColor *liquidBorderBase = [UIColor.whiteColor colorWithAlphaComponent:darkMode ? 0.12 : 0.32];
    UIColor *liquidBorderHighlight = [UIColor.whiteColor colorWithAlphaComponent:darkMode ? (selected ? 0.26 : 0.18)
                                                                                 : (selected ? 0.68 : 0.48)];
    UIColor *plateLiquidBorder = [UIColor.whiteColor colorWithAlphaComponent:darkMode ? (selected ? 0.14 : 0.10)
                                                                             : (selected ? 0.42 : 0.28)];

    void (^styleChanges)(void) = ^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self->_surfaceGradientLayer.colors = @[
            (id)PPHomeUltraProviderResolvedColor(surfaceHighlight, self.traitCollection).CGColor,
            (id)PPHomeUltraProviderResolvedColor(surfaceTint, self.traitCollection).CGColor,
            (id)PPHomeUltraProviderResolvedColor(PPHomeUltraProviderBlend(surfaceTint,
                                                                          accent,
                                                                          darkMode ? 0.08 : 0.085,
                                                                          self.traitCollection),
                                                self.traitCollection).CGColor
        ];
        self->_surfaceGradientLayer.locations = @[@0.0, @0.52, @1.0];
        self->_surfaceGradientLayer.opacity = selected ? (darkMode ? 0.56f : 0.66f) : (darkMode ? 0.33f : 0.42f);
        self->_surfaceLiquidBorderLayer.strokeColor =
            PPHomeUltraProviderResolvedColor(liquidBorderHighlight, self.traitCollection).CGColor;
        self->_surfaceLiquidBorderLayer.opacity = selected ? 1.0f : 0.92f;
        [CATransaction commit];

        self->_surfaceView.backgroundColor = surfaceBase;
        [self->_surfaceView pp_setBorderColor:liquidBorderBase];

        self->_iconPlateView.backgroundColor = iconPlateColor;
        [self->_iconPlateView pp_setBorderColor:plateLiquidBorder];

        self->_chevronPlateView.backgroundColor = chevronPlateColor;
        [self->_chevronPlateView pp_setBorderColor:[plateLiquidBorder colorWithAlphaComponent:darkMode ? 0.86 : 0.92]];

        self->_ambientOrbView.backgroundColor = AppClearClr; //orbColor;
        self->_ambientOrbView.transform = selected ? CGAffineTransformIdentity
                                                   : CGAffineTransformMakeScale(0.94, 0.94);
        self->_ambientOrbView.alpha = selected ? 1.0 : 0.80;

        self->_accentBarView.backgroundColor = accent;
        self->_accentBarView.alpha = selected ? 1.0 : 0.88;

        self->_iconView.tintColor = accent;
        self->_chevronView.tintColor = [titleColor colorWithAlphaComponent:selected ? 0.96 : 0.70];
        self->_titleLabel.textColor = titleColor;
        self->_subtitleLabel.textColor = subtitleColor;

        self.layer.shadowOpacity = darkMode ? 0.0 : (selected ? 0.085 : 0.055);
        self.layer.shadowRadius = selected ? 18.0 : 14.0;
        self.layer.shadowOffset = CGSizeMake(0.0, selected ? 10.0 : 8.0);
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.20
                              delay:0.0
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:styleChanges
                         completion:nil];
    } else {
        styleChanges();
    }
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
        self->_surfaceView.transform = CGAffineTransformMakeScale(0.985, 0.985);
        self->_iconPlateView.transform = CGAffineTransformMakeScale(0.96, 0.96);
        self->_chevronPlateView.transform = CGAffineTransformMakeScale(0.96, 0.96);
        self->_ambientOrbView.alpha = 1.0;
        self.layer.shadowOpacity = MAX(self.layer.shadowOpacity, 0.08);
    } completion:nil];
}

- (void)pp_handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _surfaceView.transform = CGAffineTransformIdentity;
        _iconPlateView.transform = CGAffineTransformIdentity;
        _chevronPlateView.transform = CGAffineTransformIdentity;
        [self pp_applySelection:_selectedState animated:NO];
        return;
    }

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.40
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_surfaceView.transform = CGAffineTransformIdentity;
        self->_iconPlateView.transform = CGAffineTransformIdentity;
        self->_chevronPlateView.transform = CGAffineTransformIdentity;
        [self pp_applySelection:self->_selectedState animated:NO];
    } completion:nil];
}

- (void)pp_handleTap
{
    if (self.onTap && _item) {
        self.onTap(_item);
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTap = nil;
    _item = nil;
    _selectedState = NO;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _subtitleLabel.hidden = NO;
    _iconView.image = nil;
    _chevronView.image = nil;
    _button.accessibilityIdentifier = nil;
    _button.accessibilityLabel = nil;
    _button.accessibilityHint = nil;
    _button.accessibilityTraits = UIAccessibilityTraitButton;
    _surfaceView.transform = CGAffineTransformIdentity;
    _iconPlateView.transform = CGAffineTransformIdentity;
    _chevronPlateView.transform = CGAffineTransformIdentity;
    [self pp_applySelection:NO animated:NO];
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
            [self pp_applySelection:_selectedState animated:NO];
        }
    }
}

@end
