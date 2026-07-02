//
//  PPHomeMarketplaceHeroCell.m
//  Pure Pets
//

#import "PPHomeMarketplaceHeroCell.h"
#import "PetCareHelpers.h"

static NSString * const PPHomeMarketplaceHeroFloatMotionKey = @"pp.home.marketplaceHero.float";
static NSString * const PPHomeMarketplaceHeroGlowMotionKey = @"pp.home.marketplaceHero.glow";
static NSString * const PPHomeMarketplaceHeroTopGlowBreathKey = @"pp.home.marketplaceHero.topGlowBreath";
static NSString * const PPHomeMarketplaceHeroSupportGlowBreathKey = @"pp.home.marketplaceHero.supportGlowBreath";
static NSString * const PPHomeMarketplaceHeroHaloBreathKey = @"pp.home.marketplaceHero.haloBreath";
static NSString * const PPHomeMarketplaceHeroPrimaryTileBreathKey = @"pp.home.marketplaceHero.primaryTileBreath";
static NSString * const PPHomeMarketplaceHeroSecondaryTileBreathKey = @"pp.home.marketplaceHero.secondaryTileBreath";

static UIColor *MarketHeroGoldColor(void) {
    return [UIColor colorWithRed:0.78 green:0.62 blue:0.30 alpha:1.0];
}

static UIColor *PPMarketHeroColor(uint32_t hex, CGFloat alpha)
{
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >>  8) & 0xFF) / 255.0
                            blue:((hex      ) & 0xFF) / 255.0
                           alpha:alpha];
}

static UIColor *PPMarketHeroDynamicColor(UIColor *light, UIColor *dark)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
        }];
    }
    return light;
}

static UIColor *PPMarketHeroResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traitCollection];
    }
    return color;
}

static UIColor *PPMarketHeroBlend(UIColor *baseColor,
                                  UIColor *overlayColor,
                                  CGFloat amount,
                                  UITraitCollection *traitCollection)
{
    UIColor *base = PPMarketHeroResolvedColor(baseColor, traitCollection);
    UIColor *overlay = PPMarketHeroResolvedColor(overlayColor, traitCollection);

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

static UIColor *PPMarketHeroAccentColor(void)
{
    return AppPrimaryClr ?: PPMarketHeroColor(0xEA6D54, 1.0);
}

static UIColor *PPMarketHeroLabelIconColor(void)
{
    if (@available(iOS 13.0, *)) {
        return UIColor.labelColor;
    }
    return PPMarketHeroColor(0x1D2420, 1.0);
}

static UIFont *PPMarketHeroScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
}

static NSTextAlignment PPMarketHeroTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

static UISemanticContentAttribute PPMarketHeroSemanticAttribute(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static BOOL PPMarketHeroReduceMotion(void)
{
    return UIAccessibilityIsReduceMotionEnabled();
}

@interface PPHomeMarketplaceHeroCell ()

@property (nonatomic, strong) UIControl *surfaceControl;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *surfaceTextLightLayer;
@property (nonatomic, strong) CAGradientLayer *surfaceVignetteLayer;
@property (nonatomic, strong) UIView *topAccentView;
@property (nonatomic, strong) UIView *ambientGlowView;
@property (nonatomic, strong) UIView *ambientSupportGlowView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIView *eyebrowPillView;
@property (nonatomic, strong) UIImageView *eyebrowIconView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *ctaView;
@property (nonatomic, strong) CAGradientLayer *ctaGradientLayer;
@property (nonatomic, strong) UILabel *ctaLabel;
@property (nonatomic, strong) UIImageView *ctaIconView;
@property (nonatomic, strong) UIView *visualContainerView;
@property (nonatomic, strong) UIView *visualHaloView;
@property (nonatomic, strong) CAGradientLayer *visualHaloGradientLayer;
@property (nonatomic, strong) UIView *storefrontPlateView;
@property (nonatomic, strong) CAGradientLayer *storefrontGradientLayer;
@property (nonatomic, strong) UIImageView *storefrontIconView;
@property (nonatomic, strong) UIView *primaryProductTileView;
@property (nonatomic, strong) UIImageView *primaryProductIconView;
@property (nonatomic, strong) UIView *secondaryProductTileView;
@property (nonatomic, strong) UIImageView *secondaryProductIconView;
@property (nonatomic, strong) UIView *routeLineView;
@property (nonatomic, strong) NSLayoutConstraint *visualWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *visualHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentTrailingToVisualConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentTrailingToSurfaceConstraint;
@property (nonatomic, assign) BOOL visualHiddenForReadableText;

@end

@implementation PPHomeMarketplaceHeroCell

+ (NSString *)reuseIdentifier
{
    return @"PPHomeMarketplaceHeroCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildInterface];
    [self configureDefaultContent];
    [self refreshThemeAppearance];
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self pp_stopAmbientMotion];
    self.onTap = nil;
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.surfaceControl.transform = CGAffineTransformIdentity;
    [self configureDefaultContent];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startAmbientMotionIfNeeded];
    } else {
        [self pp_stopAmbientMotion];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self pp_updateAdaptiveLayout];

    CGRect surfaceBounds = self.surfaceControl.bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.surfaceGradientLayer.frame = surfaceBounds;
    self.surfaceTextLightLayer.frame = surfaceBounds;
    self.surfaceVignetteLayer.frame = surfaceBounds;
    self.surfaceGradientLayer.cornerRadius = self.surfaceControl.layer.cornerRadius;
    self.surfaceTextLightLayer.cornerRadius = self.surfaceControl.layer.cornerRadius;
    self.surfaceVignetteLayer.cornerRadius = self.surfaceControl.layer.cornerRadius;
    self.ctaGradientLayer.frame = self.ctaView.bounds;
    self.ctaGradientLayer.cornerRadius = self.ctaView.layer.cornerRadius;
    self.visualHaloGradientLayer.frame = self.visualHaloView.bounds;
    self.visualHaloGradientLayer.cornerRadius = CGRectGetWidth(self.visualHaloView.bounds) * 0.5;
    self.storefrontGradientLayer.frame = self.storefrontPlateView.bounds;
    self.storefrontGradientLayer.cornerRadius = self.storefrontPlateView.layer.cornerRadius;
    [CATransaction commit];

    self.contentView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.surfaceControl.frame
                                   cornerRadius:self.surfaceControl.layer.cornerRadius].CGPath;

    if (self.window) {
        [self pp_startAmbientMotionIfNeeded];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL contentSizeChanged =
        ![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory];
    [self refreshThemeAppearance];
    if (contentSizeChanged) {
        [self pp_updateAdaptiveLayout];
    }
}

- (void)configureDefaultContent
{
    self.eyebrowLabel.text = kLang(@"home_marketplace_hero_eyebrow") ?: @"";
    self.titleLabel.text = kLang(@"home_marketplace_hero_title") ?: @"";
    self.subtitleLabel.text = kLang(@"home_marketplace_hero_subtitle") ?: @"";
    self.ctaLabel.text = kLang(@"home_marketplace_hero_cta") ?: @"";
    self.accessibilityLabel = kLang(@"home_marketplace_hero_accessibility_label") ?: @"";
    self.accessibilityHint = kLang(@"home_marketplace_hero_accessibility_hint") ?: @"";

    self.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.contentView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.surfaceControl.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.contentStackView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.eyebrowPillView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.eyebrowIconView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.eyebrowLabel.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.ctaView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.ctaIconView.image = [UIImage pp_symbolNamed:(Language.isRTL ? @"arrow.left" : @"arrow.right")
                                           pointSize:13.0
                                              weight:UIImageSymbolWeightBold
                                               scale:UIImageSymbolScaleMedium
                                             palette:@[UIColor.whiteColor]
                                        makeTemplate:YES];
    self.eyebrowLabel.textAlignment = PPMarketHeroTextAlignment();
    self.titleLabel.textAlignment = PPMarketHeroTextAlignment();
    self.subtitleLabel.textAlignment = PPMarketHeroTextAlignment();
    self.ctaLabel.textAlignment = PPMarketHeroTextAlignment();
}

- (void)refreshThemeAppearance
{
    UIColor *primaryAccent = PPPetCareAccentColor() ?: PPMarketHeroAccentColor();
    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *surfaceBase = AppForgroundColr ?: PPMarketHeroDynamicColor([UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:1.0],
                                                                        [UIColor colorWithWhite:0.104 alpha:1.0]);
    UIColor *surfaceHighlight = PPMarketHeroBlend(surfaceBase,
                                                  UIColor.whiteColor,
                                                  darkMode ? 0.08 : 0.20,
                                                  self.traitCollection);
    UIColor *backgroundAccent = PPMarketHeroBlend(primaryAccent,
                                                  surfaceBase,
                                                  darkMode ? 0.12 : 0.18,
                                                  self.traitCollection);
    UIColor *surfaceTint = PPMarketHeroBlend(surfaceBase,
                                             backgroundAccent,
                                             darkMode ? 0.095 : 0.038,
                                             self.traitCollection);
    UIColor *surfaceTail = PPMarketHeroBlend(surfaceTint,
                                             backgroundAccent,
                                             darkMode ? 0.062 : 0.024,
                                             self.traitCollection);
    UIColor *textPrimary = PPMarketHeroColor(0x2A171D, 1.0);
    UIColor *textSecondary = PPMarketHeroColor(0x7A666C, 1.0);
    UIColor *stroke = [UIColor.whiteColor colorWithAlphaComponent:darkMode ? 0.26 : 0.78];
    UIColor *orbColor = [backgroundAccent colorWithAlphaComponent:darkMode ? 0.17 : 0.11];
    UIColor *supportGlowColor = PPMarketHeroBlend(backgroundAccent,
                                                  PPMarketHeroColor(0x00F5D4, 1.0),
                                                  darkMode ? 0.18 : 0.22,
                                                  self.traitCollection);
    UIColor *eyebrowFill = [primaryAccent colorWithAlphaComponent:0.09];
    UIColor *ctaEnd = PPMarketHeroColor(0xD91557, 0.82);

    self.surfaceControl.backgroundColor = [UIColor clearColor];
    self.surfaceGradientLayer.opacity = darkMode ? 0.85 : 0.60;
    self.surfaceGradientLayer.colors = @[
        (id)PPMarketHeroResolvedColor(surfaceHighlight, self.traitCollection).CGColor,
        (id)PPMarketHeroResolvedColor(surfaceTint, self.traitCollection).CGColor,
        (id)PPMarketHeroResolvedColor(surfaceTail, self.traitCollection).CGColor
    ];
    self.surfaceGradientLayer.locations = @[@0.0, @0.56, @1.0];
    self.surfaceGradientLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);

    self.surfaceTextLightLayer.colors = @[
        (id)[UIColor.clearColor CGColor],
        (id)[UIColor.clearColor CGColor],
        (id)[UIColor.clearColor CGColor]
    ];
    self.surfaceTextLightLayer.locations = @[@0.0, @0.46, @1.0];
    self.surfaceTextLightLayer.startPoint = Language.isRTL ? CGPointMake(0.72, 0.46) : CGPointMake(0.28, 0.46);
    self.surfaceTextLightLayer.endPoint = Language.isRTL ? CGPointMake(0.04, 1.0) : CGPointMake(0.96, 1.0);

    self.surfaceVignetteLayer.colors = @[
        (id)[UIColor.clearColor CGColor],
        (id)[UIColor.clearColor CGColor]
    ];
    self.surfaceVignetteLayer.locations = @[@0.0, @1.0];
    self.surfaceVignetteLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceVignetteLayer.endPoint = CGPointMake(1.0, 1.0);

    self.surfaceControl.layer.borderColor = stroke.CGColor;
    self.contentView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.contentView.layer.shadowOpacity = 0.08f;
    self.contentView.layer.shadowRadius = 20.0f;
    self.contentView.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    self.topAccentView.backgroundColor = [primaryAccent colorWithAlphaComponent:0.58];
    self.ambientGlowView.backgroundColor = orbColor;
    self.ambientGlowView.layer.shadowColor = UIColor.clearColor.CGColor;
    self.ambientGlowView.layer.shadowOpacity = 0.0f;
    self.ambientGlowView.layer.shadowRadius = 0.0f;
    self.ambientGlowView.layer.shadowOffset = CGSizeZero;
    self.ambientSupportGlowView.backgroundColor = [supportGlowColor colorWithAlphaComponent:darkMode ? 0.12 : 0.095];
    self.ambientSupportGlowView.layer.shadowColor = supportGlowColor.CGColor;
    self.ambientSupportGlowView.layer.shadowOpacity = darkMode ? 0.11f : 0.075f;
    self.ambientSupportGlowView.layer.shadowRadius = 18.0f;
    self.ambientSupportGlowView.layer.shadowOffset = CGSizeZero;

    self.eyebrowPillView.backgroundColor = eyebrowFill;
    self.eyebrowPillView.layer.borderColor = [primaryAccent colorWithAlphaComponent:0.16].CGColor;
    self.eyebrowIconView.tintColor = primaryAccent;
    self.eyebrowLabel.textColor = primaryAccent;

    self.titleLabel.textColor = textPrimary;
    self.subtitleLabel.textColor = textSecondary;
    self.ctaView.backgroundColor = UIColor.clearColor;
    self.ctaGradientLayer.colors = @[
        (id)[primaryAccent colorWithAlphaComponent:0.92].CGColor,
        (id)ctaEnd.CGColor
    ];
    self.ctaGradientLayer.locations = @[@0.0, @1.0];
    self.ctaGradientLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    self.ctaGradientLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
    self.ctaView.layer.borderWidth = 0.8;
    self.ctaView.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.28].CGColor;
    self.ctaView.layer.shadowColor = PPMarketHeroColor(0xBC2455, 1.0).CGColor;
    self.ctaView.layer.shadowOpacity = 0.11f;
    self.ctaView.layer.shadowRadius = 10.0f;
    self.ctaView.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    self.ctaLabel.textColor = UIColor.whiteColor;
    self.ctaIconView.tintColor = UIColor.whiteColor;

    self.visualHaloGradientLayer.colors = @[
        (id)[primaryAccent colorWithAlphaComponent:0.16].CGColor,
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor,
        (id)[UIColor.clearColor CGColor]
    ];
    self.visualHaloGradientLayer.locations = @[@0.0, @0.45, @1.0];

    self.storefrontGradientLayer.colors = @[
        (id)[primaryAccent colorWithAlphaComponent:0.20].CGColor,
        (id)[surfaceBase colorWithAlphaComponent:0.98].CGColor
    ];
    self.storefrontGradientLayer.startPoint = CGPointMake(0.12, 0.0);
    self.storefrontGradientLayer.endPoint = CGPointMake(0.92, 1.0);
    self.storefrontPlateView.layer.borderColor = stroke.CGColor;
    self.storefrontIconView.tintColor = PPMarketHeroColor(0x1D2420, 1.0);

    [self pp_applyProductTile:self.primaryProductTileView
                         icon:self.primaryProductIconView
                       accent:primaryAccent
                         dark:NO];
    [self pp_applyProductTile:self.secondaryProductTileView
                         icon:self.secondaryProductIconView
                       accent:PPMarketHeroColor(0x6EAFA2, 1.0)
                         dark:NO];
    self.routeLineView.backgroundColor = [primaryAccent colorWithAlphaComponent:0.22];
}

#pragma mark - Build

- (void)pp_buildInterface
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.contentView.layer.masksToBounds = NO;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    UIControl *surface = [[UIControl alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = UIColor.clearColor;
    surface.clipsToBounds = YES;
    surface.layer.cornerRadius = PPCornerHero - 6.0;
    surface.layer.borderWidth = 1.0;
    surface.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        surface.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surface addTarget:self action:@selector(pp_touchDown) forControlEvents:UIControlEventTouchDown];
    [surface addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [surface addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:surface];
    self.surfaceControl = surface;

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.drawsAsynchronously = YES;
    [surface.layer insertSublayer:self.surfaceGradientLayer atIndex:0];

    self.surfaceTextLightLayer = [CAGradientLayer layer];
    self.surfaceTextLightLayer.drawsAsynchronously = YES;
    if (@available(iOS 12.0, *)) {
        self.surfaceTextLightLayer.type = kCAGradientLayerRadial;
    }
    [surface.layer insertSublayer:self.surfaceTextLightLayer above:self.surfaceGradientLayer];

    self.surfaceVignetteLayer = [CAGradientLayer layer];
    self.surfaceVignetteLayer.drawsAsynchronously = YES;
    [surface.layer insertSublayer:self.surfaceVignetteLayer above:self.surfaceTextLightLayer];

    UIView *ambientGlow = [[UIView alloc] init];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.layer.cornerRadius = 58.0;
    ambientGlow.alpha = 1.0;
    [surface addSubview:ambientGlow];
    self.ambientGlowView = ambientGlow;

    UIView *supportGlow = [[UIView alloc] init];
    supportGlow.translatesAutoresizingMaskIntoConstraints = NO;
    supportGlow.userInteractionEnabled = NO;
    supportGlow.layer.cornerRadius = 66.0;
    [surface addSubview:supportGlow];
    self.ambientSupportGlowView = supportGlow;
    
    UIView *topAccent = [[UIView alloc] init];
    topAccent.translatesAutoresizingMaskIntoConstraints = NO;
    topAccent.userInteractionEnabled = NO;
    topAccent.layer.cornerRadius = 2.0;
    if (@available(iOS 13.0, *)) {
        topAccent.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surface addSubview:topAccent];
    self.topAccentView = topAccent;

    [self pp_buildContentStackInSurface:surface];
    [self pp_buildVisualClusterInSurface:surface];

    [NSLayoutConstraint activateConstraints:@[
        [surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [ambientGlow.widthAnchor constraintEqualToConstant:116.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:116.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:surface.topAnchor constant:-34.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:Language.isRTL ? 22.0 : -12.0],

        [supportGlow.widthAnchor constraintEqualToConstant:132.0],
        [supportGlow.heightAnchor constraintEqualToConstant:132.0],
        [supportGlow.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:48.0],
        [supportGlow.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:Language.isRTL ? -26.0 : 28.0],

        [topAccent.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [topAccent.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:30.0],
        [topAccent.widthAnchor constraintEqualToConstant:44.0],
        [topAccent.heightAnchor constraintEqualToConstant:4.0],

        [self.contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:surface.topAnchor constant:PPSpaceLG],
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceLG],
        [self.contentStackView.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [self.contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-PPSpaceLG],

        [self.visualContainerView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceMD],
        [self.visualContainerView.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
    ]];

    self.visualWidthConstraint = [self.visualContainerView.widthAnchor constraintEqualToConstant:118.0];
    self.visualHeightConstraint = [self.visualContainerView.heightAnchor constraintEqualToConstant:132.0];
    self.contentTrailingToVisualConstraint =
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.visualContainerView.leadingAnchor constant:-PPSpaceMD];
    self.contentTrailingToSurfaceConstraint =
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceLG];
    self.contentTrailingToVisualConstraint.active = YES;
    self.visualWidthConstraint.active = YES;
    self.visualHeightConstraint.active = YES;
}

- (void)pp_buildContentStackInSurface:(UIView *)surface
{
    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.layer.cornerRadius = 13.0;
    eyebrowPill.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        eyebrowPill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.eyebrowPillView = eyebrowPill;

    UIImageView *eyebrowIcon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"storefront.fill"
                                                         pointSize:11.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[PPMarketHeroAccentColor()]
                                                      makeTemplate:YES]];
    eyebrowIcon.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowIcon.contentMode = UIViewContentModeScaleAspectFit;
    eyebrowIcon.isAccessibilityElement = NO;
    [eyebrowPill addSubview:eyebrowIcon];
    self.eyebrowIconView = eyebrowIcon;

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = PPMarketHeroScaledFont([GM MidFontWithSize:11.0], UIFontTextStyleCaption1);
    eyebrowLabel.adjustsFontForContentSizeCategory = YES;
    eyebrowLabel.adjustsFontSizeToFitWidth = YES;
    eyebrowLabel.minimumScaleFactor = 0.86;
    eyebrowLabel.numberOfLines = 1;
    eyebrowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [eyebrowPill addSubview:eyebrowLabel];
    self.eyebrowLabel = eyebrowLabel;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPMarketHeroScaledFont([GM boldFontWithSize:24.0], UIFontTextStyleTitle2);
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.numberOfLines = 2;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    titleLabel.adjustsFontSizeToFitWidth = NO;
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPMarketHeroScaledFont([GM MidFontWithSize:14.0], UIFontTextStyleSubheadline);
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.numberOfLines = 3;
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleLabel.adjustsFontSizeToFitWidth = NO;
    self.subtitleLabel = subtitleLabel;

    UIView *cta = [[UIView alloc] init];
    cta.translatesAutoresizingMaskIntoConstraints = NO;
    cta.userInteractionEnabled = NO;
    cta.layer.cornerRadius = 18.0;
    cta.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        cta.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.ctaView = cta;

    self.ctaGradientLayer = [CAGradientLayer layer];
    self.ctaGradientLayer.drawsAsynchronously = YES;
    [cta.layer insertSublayer:self.ctaGradientLayer atIndex:0];

    UILabel *ctaLabel = [[UILabel alloc] init];
    ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    ctaLabel.font = PPMarketHeroScaledFont([GM boldFontWithSize:13.0], UIFontTextStyleCallout);
    ctaLabel.adjustsFontForContentSizeCategory = YES;
    ctaLabel.numberOfLines = 1;
    ctaLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [cta addSubview:ctaLabel];
    self.ctaLabel = ctaLabel;

    UIImageView *ctaIcon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:(Language.isRTL ? @"arrow.left" : @"arrow.right")
                                                         pointSize:13.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[UIColor.whiteColor]
                                                      makeTemplate:YES]];
    ctaIcon.translatesAutoresizingMaskIntoConstraints = NO;
    ctaIcon.contentMode = UIViewContentModeScaleAspectFit;
    [cta addSubview:ctaIcon];
    self.ctaIconView = ctaIcon;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        eyebrowPill,
        titleLabel,
        subtitleLabel,
        cta
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentLeading;
    stack.spacing = PPSpaceSM;
    stack.userInteractionEnabled = NO;
    [stack setCustomSpacing:PPSpaceMD afterView:eyebrowPill];
    [stack setCustomSpacing:PPSpaceSM afterView:titleLabel];
    [stack setCustomSpacing:PPSpaceMD afterView:subtitleLabel];
    [surface addSubview:stack];
    self.contentStackView = stack;

[NSLayoutConstraint activateConstraints:@[
         [titleLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
         [subtitleLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
         [cta.widthAnchor constraintLessThanOrEqualToAnchor:stack.widthAnchor],

         [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],
         [eyebrowIcon.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:10.0],
         [eyebrowIcon.centerYAnchor constraintEqualToAnchor:eyebrowPill.centerYAnchor],
         [eyebrowIcon.widthAnchor constraintEqualToConstant:13.0],
         [eyebrowIcon.heightAnchor constraintEqualToConstant:13.0],

         [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowIcon.trailingAnchor constant:6.0],
         [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-10.0],
         [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:5.0],
         [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-5.0],

         [cta.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        [ctaLabel.leadingAnchor constraintEqualToAnchor:cta.leadingAnchor constant:PPSpaceMD - 2.0],
        [ctaLabel.centerYAnchor constraintEqualToAnchor:cta.centerYAnchor],
        [ctaIcon.leadingAnchor constraintEqualToAnchor:ctaLabel.trailingAnchor constant:PPSpaceSM - 1.0],
        [ctaIcon.trailingAnchor constraintEqualToAnchor:cta.trailingAnchor constant:-(PPSpaceMD - 2.0)],
        [ctaIcon.centerYAnchor constraintEqualToAnchor:cta.centerYAnchor],
        [ctaIcon.widthAnchor constraintEqualToConstant:15.0],
        [ctaIcon.heightAnchor constraintEqualToConstant:15.0],
    ]];
}

- (void)pp_buildVisualClusterInSurface:(UIView *)surface
{
    UIView *visual = [[UIView alloc] init];
    visual.translatesAutoresizingMaskIntoConstraints = NO;
    visual.userInteractionEnabled = NO;
    [surface addSubview:visual];
    self.visualContainerView = visual;

    UIView *halo = [[UIView alloc] init];
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    halo.userInteractionEnabled = NO;
    halo.layer.cornerRadius = 60.0;
    halo.clipsToBounds = YES;
    [visual addSubview:halo];
    self.visualHaloView = halo;

    self.visualHaloGradientLayer = [CAGradientLayer layer];
    if (@available(iOS 12.0, *)) {
        self.visualHaloGradientLayer.type = kCAGradientLayerRadial;
        self.visualHaloGradientLayer.startPoint = CGPointMake(0.5, 0.5);
        self.visualHaloGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    }
    [halo.layer insertSublayer:self.visualHaloGradientLayer atIndex:0];

    UIView *plate = [[UIView alloc] init];
    plate.translatesAutoresizingMaskIntoConstraints = NO;
    plate.layer.cornerRadius = 32.0;
    plate.layer.borderWidth = 1.0;
    plate.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        plate.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [visual addSubview:plate];
    self.storefrontPlateView = plate;

    self.storefrontGradientLayer = [CAGradientLayer layer];
    [plate.layer insertSublayer:self.storefrontGradientLayer atIndex:0];

    UIImageView *storefrontIcon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"storefront.fill"
                                                         pointSize:42.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleLarge
                                                           palette:@[PPMarketHeroLabelIconColor()]
                                                      makeTemplate:YES]];
    storefrontIcon.translatesAutoresizingMaskIntoConstraints = NO;
    storefrontIcon.contentMode = UIViewContentModeScaleAspectFit;
    [plate addSubview:storefrontIcon];
    self.storefrontIconView = storefrontIcon;

    UIView *routeLine = [[UIView alloc] init];
    routeLine.translatesAutoresizingMaskIntoConstraints = NO;
    routeLine.layer.cornerRadius = 1.0;
    [visual addSubview:routeLine];
    self.routeLineView = routeLine;

    self.primaryProductTileView = [self pp_makeProductTileWithSymbol:@"bag.fill"];
    self.primaryProductIconView = (UIImageView *)self.primaryProductTileView.subviews.firstObject;
    [visual addSubview:self.primaryProductTileView];

    self.secondaryProductTileView = [self pp_makeProductTileWithSymbol:@"shippingbox.fill"];
    self.secondaryProductIconView = (UIImageView *)self.secondaryProductTileView.subviews.firstObject;
    [visual addSubview:self.secondaryProductTileView];

    [NSLayoutConstraint activateConstraints:@[
        [halo.centerXAnchor constraintEqualToAnchor:visual.centerXAnchor],
        [halo.centerYAnchor constraintEqualToAnchor:visual.centerYAnchor],
        [halo.widthAnchor constraintEqualToConstant:120.0],
        [halo.heightAnchor constraintEqualToConstant:120.0],

        [plate.centerXAnchor constraintEqualToAnchor:visual.centerXAnchor],
        [plate.centerYAnchor constraintEqualToAnchor:visual.centerYAnchor constant:-2.0],
        [plate.widthAnchor constraintEqualToConstant:88.0],
        [plate.heightAnchor constraintEqualToConstant:88.0],

        [storefrontIcon.centerXAnchor constraintEqualToAnchor:plate.centerXAnchor],
        [storefrontIcon.centerYAnchor constraintEqualToAnchor:plate.centerYAnchor],
        [storefrontIcon.widthAnchor constraintEqualToConstant:47.0],
        [storefrontIcon.heightAnchor constraintEqualToConstant:47.0],

        [routeLine.centerXAnchor constraintEqualToAnchor:visual.centerXAnchor],
        [routeLine.topAnchor constraintEqualToAnchor:plate.bottomAnchor constant:8.0],
        [routeLine.widthAnchor constraintEqualToConstant:40.0],
        [routeLine.heightAnchor constraintEqualToConstant:2.0],

        [self.primaryProductTileView.widthAnchor constraintEqualToConstant:42.0],
        [self.primaryProductTileView.heightAnchor constraintEqualToConstant:42.0],
        [self.primaryProductTileView.trailingAnchor constraintEqualToAnchor:visual.trailingAnchor constant:-2.0],
        [self.primaryProductTileView.topAnchor constraintEqualToAnchor:visual.topAnchor constant:16.0],

        [self.secondaryProductTileView.widthAnchor constraintEqualToConstant:36.0],
        [self.secondaryProductTileView.heightAnchor constraintEqualToConstant:36.0],
        [self.secondaryProductTileView.leadingAnchor constraintEqualToAnchor:visual.leadingAnchor constant:2.0],
        [self.secondaryProductTileView.bottomAnchor constraintEqualToAnchor:visual.bottomAnchor constant:-18.0],
    ]];
}

- (UIView *)pp_makeProductTileWithSymbol:(NSString *)symbolName
{
    UIView *tile = [[UIView alloc] init];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.layer.cornerRadius = 15.0;
    tile.layer.borderWidth = 1.0;
    tile.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        tile.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *icon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:symbolName
                                                         pointSize:15.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[PPMarketHeroAccentColor()]
                                                      makeTemplate:YES]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [tile addSubview:icon];

    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18.0],
        [icon.heightAnchor constraintEqualToConstant:18.0],
    ]];

    return tile;
}

#pragma mark - State

- (void)pp_applyProductTile:(UIView *)tile
                       icon:(UIImageView *)icon
                     accent:(UIColor *)accent
                     dark:(BOOL)dark
{
    UIColor *surfaceBase = UIColor.whiteColor;
    tile.backgroundColor = [surfaceBase colorWithAlphaComponent:0.90];
    tile.layer.borderColor = PPMarketHeroColor(0xE6CCD4, 0.30).CGColor;
    tile.layer.shadowColor = PPMarketHeroColor(0x29312E, 1.0).CGColor;
    tile.layer.shadowOpacity = 0.08f;
    tile.layer.shadowRadius = 12.0f;
    tile.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    icon.tintColor = accent ?: PPMarketHeroAccentColor();
}

- (void)pp_updateAdaptiveLayout
{
    CGFloat width = CGRectGetWidth(self.bounds);
    BOOL accessibilityCategory =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    BOOL hideVisual = accessibilityCategory || (width > 0.0 && width < 335.0);

    if (hideVisual == self.visualHiddenForReadableText) {
        return;
    }

    self.visualHiddenForReadableText = hideVisual;
    self.visualContainerView.hidden = hideVisual;
    self.contentTrailingToVisualConstraint.active = !hideVisual;
    self.contentTrailingToSurfaceConstraint.active = hideVisual;
}

- (void)pp_touchDown
{
    if (PPMarketHeroReduceMotion()) {
        self.surfaceControl.alpha = 0.94;
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.surfaceControl.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:nil];
}

- (void)pp_touchUp
{
    if (PPMarketHeroReduceMotion()) {
        self.surfaceControl.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.surfaceControl.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_handleTap
{
    if (self.onTap) {
        self.onTap();
    }
}

- (void)pp_startAmbientMotionIfNeeded
{
    if (PPMarketHeroReduceMotion()) {
        [self pp_stopAmbientMotion];
        return;
    }
    if (!self.window || CGRectIsEmpty(self.bounds) || CGRectIsEmpty(self.visualContainerView.bounds)) {
        return;
    }
    if (![self.visualContainerView.layer animationForKey:PPHomeMarketplaceHeroFloatMotionKey]) {
        CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.fromValue = @0.0;
        floatAnimation.toValue = @(-7.0);
        floatAnimation.duration = 3.1;
        floatAnimation.autoreverses = YES;
        floatAnimation.repeatCount = HUGE_VALF;
        floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        floatAnimation.removedOnCompletion = YES;
        [self.visualContainerView.layer addAnimation:floatAnimation forKey:PPHomeMarketplaceHeroFloatMotionKey];
    }

    if (![self.ambientGlowView.layer animationForKey:PPHomeMarketplaceHeroGlowMotionKey]) {
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
        [self.ambientGlowView.layer addAnimation:glowDrift forKey:PPHomeMarketplaceHeroGlowMotionKey];
    }

    [self pp_applyBreathingGlowToView:self.ambientGlowView
                                  key:PPHomeMarketplaceHeroTopGlowBreathKey
                            fromAlpha:0.54
                              toAlpha:0.90
                            fromScale:0.90
                              toScale:1.18
                             duration:3.7];

    [self pp_applyBreathingGlowToView:self.ambientSupportGlowView
                                  key:PPHomeMarketplaceHeroSupportGlowBreathKey
                            fromAlpha:0.66
                              toAlpha:0.98
                            fromScale:0.94
                              toScale:1.08
                             duration:4.1];

    [self pp_applyBreathingGlowToView:self.visualHaloView
                                  key:PPHomeMarketplaceHeroHaloBreathKey
                            fromAlpha:0.78
                              toAlpha:1.0
                            fromScale:0.95
                              toScale:1.075
                             duration:3.4];

    [self pp_applyBreathAnimationToTile:self.primaryProductTileView
                                    key:PPHomeMarketplaceHeroPrimaryTileBreathKey
                                  delay:0.04
                               duration:2.8
                              amplitude:0.078
                                   lift:-3.4
                             lowOpacity:0.84];
    [self pp_applyBreathAnimationToTile:self.secondaryProductTileView
                                    key:PPHomeMarketplaceHeroSecondaryTileBreathKey
                                  delay:0.48
                               duration:3.2
                              amplitude:0.082
                                   lift:-3.8
                             lowOpacity:0.82];
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

- (void)pp_applyBreathAnimationToTile:(UIView *)tile
                                  key:(NSString *)key
                                delay:(CFTimeInterval)delay
                             duration:(CFTimeInterval)duration
                            amplitude:(CGFloat)amplitude
                                 lift:(CGFloat)lift
                           lowOpacity:(CGFloat)lowOpacity
{
    if (!tile || [tile.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @(1.0 - (amplitude * 0.42));
    scaleAnimation.toValue = @(1.0 + amplitude);

    CABasicAnimation *liftAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    liftAnimation.fromValue = @0.0;
    liftAnimation.toValue = @(lift);

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @(lowOpacity);
    opacityAnimation.toValue = @1.0;

    CAAnimationGroup *breathAnimation = [CAAnimationGroup animation];
    breathAnimation.animations = @[scaleAnimation, liftAnimation, opacityAnimation];
    breathAnimation.duration = duration;
    breathAnimation.beginTime = [tile.layer convertTime:CACurrentMediaTime() fromLayer:nil] + delay;
    breathAnimation.autoreverses = YES;
    breathAnimation.repeatCount = HUGE_VALF;
    breathAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    breathAnimation.removedOnCompletion = YES;
    [tile.layer addAnimation:breathAnimation forKey:key];
}

- (void)pp_stopAmbientMotion
{
    [self.visualContainerView.layer removeAnimationForKey:PPHomeMarketplaceHeroFloatMotionKey];
    [self.ambientGlowView.layer removeAnimationForKey:PPHomeMarketplaceHeroGlowMotionKey];
    [self.ambientGlowView.layer removeAnimationForKey:PPHomeMarketplaceHeroTopGlowBreathKey];
    [self.ambientSupportGlowView.layer removeAnimationForKey:PPHomeMarketplaceHeroSupportGlowBreathKey];
    [self.visualHaloView.layer removeAnimationForKey:PPHomeMarketplaceHeroHaloBreathKey];
    [self.primaryProductTileView.layer removeAnimationForKey:PPHomeMarketplaceHeroPrimaryTileBreathKey];
    [self.secondaryProductTileView.layer removeAnimationForKey:PPHomeMarketplaceHeroSecondaryTileBreathKey];
    self.visualContainerView.transform = CGAffineTransformIdentity;
    self.ambientGlowView.transform = CGAffineTransformIdentity;
    self.ambientSupportGlowView.transform = CGAffineTransformIdentity;
    self.visualHaloView.transform = CGAffineTransformIdentity;
    self.primaryProductTileView.transform = CGAffineTransformIdentity;
    self.secondaryProductTileView.transform = CGAffineTransformIdentity;
}

- (NSString *)pp_lottieFirebasePathForCurrentTime
{
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:NSDate.date];
    return @"Boy Giving Food To Bird";
    if (hour < 9) {
        return @"Woman playing with a dog";
    }
    if (hour < 12) {
        return @"Boy Giving Food To Bird";
    }
    if (hour < 17) {
        return @"Man playing with a dog";
    }
    if (hour < 20) {
        return @"Womanlovingpetcats";
    }
    if (hour < 23) {
        return @"evening chair cat and girl";
    }
    return @"man playing with cat during free time";
}



@end
