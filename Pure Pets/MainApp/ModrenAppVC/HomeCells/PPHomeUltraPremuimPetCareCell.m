//
//  PPHomeUltraPremuimPetCareCell.m
//  Pure Pets
//

#import "PPHomeUltraPremuimPetCareCell.h"
#import "AppClasses.h"

static NSString * const PPUltraCareDefaultAnimationName = @"ecg3";
static NSString * const PPUltraCareGlowTopAnimationKey = @"pp.home.ultraCare.glow.top";
static NSString * const PPUltraCareGlowBottomAnimationKey = @"pp.home.ultraCare.glow.bottom";
static NSString * const PPUltraCareOrbitAnimationKey = @"pp.home.ultraCare.orbit";
static NSString * const PPUltraCarePulseAnimationKey = @"pp.home.ultraCare.pulse";
static BOOL const PPUltraCareGlowsFaded = YES;
static CGFloat const PPUltraCareSurfaceCornerRadius = 28.0;
static CGFloat const PPUltraCareHeroPortalSize = 84.0;
static CGFloat const PPUltraCareOrbitCarrierSize = 72.0;
static CGFloat const PPUltraCareHeroInnerSize = 62.0;
static CGFloat const PPUltraCareFallbackIconSize = 28.0;
static CGFloat const PPUltraCareAnimationSize = 58.0;

static UIColor *PPUltraCareDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIColor *PPUltraCareResolvedColor(UIColor *color, UITraitCollection *traits)
{
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traits];
    }
    return color;
}

@interface PPHomeUltraPremuimPetCareCell ()
- (void)pp_stopAmbientMotion;
- (CAGradientLayer *)pp_makeAmbientGlowLayer;
- (void)pp_applyAmbientGlowColor:(UIColor *)color
                            view:(UIView *)view
                   gradientLayer:(CAGradientLayer *)gradientLayer
                       peakAlpha:(CGFloat)peakAlpha;
@end

@implementation PPHomeUltraPremuimPetCareCell {
    UIView *_surfaceView;
    CAGradientLayer *_surfaceGradientLayer;
    CAShapeLayer *_edgeHighlightLayer;

    UIView *_topAmbientGlowView;
    UIView *_bottomAmbientGlowView;
    CAGradientLayer *_topAmbientGlowLayer;
    CAGradientLayer *_bottomAmbientGlowLayer;
    UIView *_topAccentLineView;

    UIView *_heroPortalView;
    UIView *_heroInnerView;
    UIView *_orbitCarrierView;
    CAShapeLayer *_orbitRingLayer;
    CAShapeLayer *_pulseRingLayer;
    UIView *_orbitNodeView;
    LOTAnimationView *_careAnimationView;
    UIImageView *_fallbackIconView;

    PPInsetLabel *_eyebrowLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;

    UIView *_ctaView;
    UILabel *_ctaLabel;
    UIImageView *_ctaArrowView;

    NSString *_currentAnimationName;
    NSInteger _animationLoadToken;
    NSInteger _entranceToken;
    BOOL _animationLoading;
    BOOL _animationReady;
    BOOL _didRevealAnimation;
    BOOL _didPlayPostLayoutEntrance;
    BOOL _shouldDeferEntrance;
}

+ (NSString *)reuseIdentifier
{
    return @"PPHomeUltraPremuimPetCareCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityIdentifier = @"home.ultraPetCare";

    [self pp_buildHierarchy];
    [self pp_applyTypography];
    [self pp_applyTheme];
    [self pp_applyStablePresentationState];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_reduceMotionStatusDidChange:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_contentSizeCategoryDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Construction

- (void)pp_buildHierarchy
{
    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.clipsToBounds = YES;
    _surfaceView.layer.borderWidth = 0.75;
    PPApplyContinuousCorners(_surfaceView, PPUltraCareSurfaceCornerRadius);
    [self.contentView addSubview:_surfaceView];

    _surfaceGradientLayer = [CAGradientLayer layer];
    _surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_surfaceView.layer insertSublayer:_surfaceGradientLayer atIndex:0];

    _topAmbientGlowView = [self pp_makeAmbientGlowView];
    _bottomAmbientGlowView = [self pp_makeAmbientGlowView];
    _topAmbientGlowLayer = [self pp_makeAmbientGlowLayer];
    _bottomAmbientGlowLayer = [self pp_makeAmbientGlowLayer];
    [_topAmbientGlowView.layer insertSublayer:_topAmbientGlowLayer atIndex:0];
    [_bottomAmbientGlowView.layer insertSublayer:_bottomAmbientGlowLayer atIndex:0];
    [_surfaceView addSubview:_topAmbientGlowView];
    [_surfaceView addSubview:_bottomAmbientGlowView];

    _edgeHighlightLayer = [CAShapeLayer layer];
    _edgeHighlightLayer.fillColor = UIColor.clearColor.CGColor;
    _edgeHighlightLayer.lineWidth = 0.7;
    [_surfaceView.layer addSublayer:_edgeHighlightLayer];

    _topAccentLineView = [[UIView alloc] init];
    _topAccentLineView.translatesAutoresizingMaskIntoConstraints = NO;
    _topAccentLineView.userInteractionEnabled = NO;
    _topAccentLineView.layer.cornerRadius = 2.0;
    PPApplyContinuousCorners(_topAccentLineView, 2.0);
    [_surfaceView addSubview:_topAccentLineView];

    _heroPortalView = [[UIView alloc] init];
    _heroPortalView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroPortalView.userInteractionEnabled = NO;
    _heroPortalView.layer.borderWidth = 0.99;
    PPApplyContinuousCorners(_heroPortalView, 22.0);
    [_surfaceView addSubview:_heroPortalView];

    _orbitCarrierView = [[UIView alloc] init];
    _orbitCarrierView.translatesAutoresizingMaskIntoConstraints = NO;
    _orbitCarrierView.userInteractionEnabled = NO;
    [_heroPortalView addSubview:_orbitCarrierView];

    _orbitRingLayer = [CAShapeLayer layer];
    _orbitRingLayer.fillColor = UIColor.clearColor.CGColor;
    _orbitRingLayer.lineWidth = 0.8;
    _orbitRingLayer.lineDashPattern = @[@1.4, @5.2];
    _orbitRingLayer.lineCap = kCALineCapRound;
    [_orbitCarrierView.layer addSublayer:_orbitRingLayer];

    _orbitNodeView = [[UIView alloc] init];
    _orbitNodeView.translatesAutoresizingMaskIntoConstraints = NO;
    _orbitNodeView.userInteractionEnabled = NO;
    _orbitNodeView.layer.cornerRadius = 3.0;
    [_orbitCarrierView addSubview:_orbitNodeView];

    _pulseRingLayer = [CAShapeLayer layer];
    _pulseRingLayer.fillColor = UIColor.clearColor.CGColor;
    _pulseRingLayer.lineWidth = 1.0;
    [_heroPortalView.layer addSublayer:_pulseRingLayer];

    _heroInnerView = [[UIView alloc] init];
    _heroInnerView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroInnerView.userInteractionEnabled = NO;
    _heroInnerView.layer.borderWidth = 0.7;
    PPApplyContinuousCorners(_heroInnerView, 22.0);
    [_heroPortalView addSubview:_heroInnerView];

    _fallbackIconView = [[UIImageView alloc] init];
    _fallbackIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _fallbackIconView.userInteractionEnabled = NO;
    _fallbackIconView.contentMode = UIViewContentModeScaleAspectFit;
    UIImageSymbolConfiguration *fallbackConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:25.0
                                                         weight:UIImageSymbolWeightMedium
                                                          scale:UIImageSymbolScaleMedium];
    _fallbackIconView.image =
        [[UIImage systemImageNamed:@"cross.case.fill" withConfiguration:fallbackConfiguration]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [_heroInnerView addSubview:_fallbackIconView];

    _careAnimationView = [[LOTAnimationView alloc] init];
    _careAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    _careAnimationView.userInteractionEnabled = NO;
    _careAnimationView.isAccessibilityElement = NO;
    _careAnimationView.accessibilityElementsHidden = YES;
    _careAnimationView.backgroundColor = UIColor.clearColor;
    _careAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    _careAnimationView.loopAnimation = YES;
    _careAnimationView.animationSpeed = 0.78;
    _careAnimationView.hidden = YES;
    [_heroInnerView addSubview:_careAnimationView];

    _eyebrowLabel = [[PPInsetLabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.numberOfLines = 1;
    _eyebrowLabel.adjustsFontSizeToFitWidth = YES;
    _eyebrowLabel.minimumScaleFactor = 0.86;
    _eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _eyebrowLabel.layer.borderWidth = 0.2;
    _eyebrowLabel.layer.masksToBounds = YES;
    _eyebrowLabel.textInsets = UIEdgeInsetsMake(1, 4, 1, 4);
    if (@available(iOS 13.0, *)) {
        _eyebrowLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.76;
    [_surfaceView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisVertical];
    [_surfaceView addSubview:_subtitleLabel];

    _ctaView = [[UIView alloc] init];
    _ctaView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaView.userInteractionEnabled = NO;
    _ctaView.layer.borderWidth = 0.1;
    PPApplyContinuousCorners(_ctaView, 16.0);
    [_surfaceView addSubview:_ctaView];

    _ctaLabel = [[UILabel alloc] init];
    _ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaLabel.numberOfLines = 1;
    _ctaLabel.adjustsFontSizeToFitWidth = YES;
    _ctaLabel.minimumScaleFactor = 0.82;
    [_ctaView addSubview:_ctaLabel];

    _ctaArrowView = [[UIImageView alloc] init];
    _ctaArrowView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaArrowView.contentMode = UIViewContentModeScaleAspectFit;
    [_ctaView addSubview:_ctaArrowView];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_topAmbientGlowView.widthAnchor constraintEqualToConstant:372.0],
        [_topAmbientGlowView.heightAnchor constraintEqualToConstant:372.0],
        [_topAmbientGlowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:138.0],
        [_topAmbientGlowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:-152.0],

        [_bottomAmbientGlowView.widthAnchor constraintEqualToConstant:312.0],
        [_bottomAmbientGlowView.heightAnchor constraintEqualToConstant:312.0],
        [_bottomAmbientGlowView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:-104.0],
        [_bottomAmbientGlowView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:112.0],

        [_topAccentLineView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:22.0],
        [_topAccentLineView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_topAccentLineView.widthAnchor constraintEqualToConstant:44.0],
        [_topAccentLineView.heightAnchor constraintEqualToConstant:4.0],

        [_heroPortalView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-18.0],
        [_heroPortalView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:18],
        [_heroPortalView.widthAnchor constraintEqualToConstant:PPUltraCareHeroPortalSize],
        [_heroPortalView.heightAnchor constraintEqualToConstant:PPUltraCareHeroPortalSize],

        [_orbitCarrierView.centerXAnchor constraintEqualToAnchor:_heroPortalView.centerXAnchor],
        [_orbitCarrierView.centerYAnchor constraintEqualToAnchor:_heroPortalView.centerYAnchor],
        [_orbitCarrierView.widthAnchor constraintEqualToConstant:PPUltraCareOrbitCarrierSize],
        [_orbitCarrierView.heightAnchor constraintEqualToConstant:PPUltraCareOrbitCarrierSize],

        [_orbitNodeView.centerXAnchor constraintEqualToAnchor:_orbitCarrierView.centerXAnchor],
        [_orbitNodeView.topAnchor constraintEqualToAnchor:_orbitCarrierView.topAnchor constant:1.0],
        [_orbitNodeView.widthAnchor constraintEqualToConstant:0],
        [_orbitNodeView.heightAnchor constraintEqualToConstant:0],

        [_heroInnerView.centerXAnchor constraintEqualToAnchor:_heroPortalView.centerXAnchor],
        [_heroInnerView.centerYAnchor constraintEqualToAnchor:_heroPortalView.centerYAnchor],
        [_heroInnerView.widthAnchor constraintEqualToConstant:PPUltraCareHeroInnerSize],
        [_heroInnerView.heightAnchor constraintEqualToConstant:PPUltraCareHeroInnerSize],

        [_fallbackIconView.centerXAnchor constraintEqualToAnchor:_heroInnerView.centerXAnchor],
        [_fallbackIconView.centerYAnchor constraintEqualToAnchor:_heroInnerView.centerYAnchor],
        [_fallbackIconView.widthAnchor constraintEqualToConstant:PPUltraCareFallbackIconSize],
        [_fallbackIconView.heightAnchor constraintEqualToConstant:PPUltraCareFallbackIconSize],

        [_careAnimationView.centerXAnchor constraintEqualToAnchor:_heroInnerView.centerXAnchor],
        [_careAnimationView.centerYAnchor constraintEqualToAnchor:_heroInnerView.centerYAnchor],
        [_careAnimationView.widthAnchor constraintEqualToConstant:PPUltraCareAnimationSize],
        [_careAnimationView.heightAnchor constraintEqualToConstant:PPUltraCareAnimationSize],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:18.0],
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:12.0],
        [_eyebrowLabel.heightAnchor constraintEqualToConstant:22.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_heroPortalView.leadingAnchor constant:-14.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:7.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_heroPortalView.leadingAnchor constant:-PPSpaceMD],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_ctaView.topAnchor constant:-PPSpaceXS],

        [_ctaView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:PPSpaceBase],
        [_ctaView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-14.0],
        [_ctaView.heightAnchor constraintEqualToConstant:32.0],
        //[_ctaView.trailingAnchor constraintEqualToAnchor:_heroPortalView.leadingAnchor constant:-PPSpaceMD],

        [_ctaLabel.leadingAnchor constraintEqualToAnchor:_ctaView.leadingAnchor constant:PPSpaceMD],
        [_ctaLabel.centerYAnchor constraintEqualToAnchor:_ctaView.centerYAnchor],
        [_ctaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_ctaArrowView.leadingAnchor constant:-PPSpaceSM],

        [_ctaArrowView.trailingAnchor constraintEqualToAnchor:_ctaView.trailingAnchor constant:-PPSpaceMD],
        [_ctaArrowView.centerYAnchor constraintEqualToAnchor:_ctaView.centerYAnchor],
        [_ctaArrowView.widthAnchor constraintEqualToConstant:13.0],
        [_ctaArrowView.heightAnchor constraintEqualToConstant:13.0],
    ]];
}

- (UIView *)pp_makeAmbientGlowView
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowRadius = 54.0;
    view.layer.shadowOpacity = 0.22;
    return view;
}

- (CAGradientLayer *)pp_makeAmbientGlowLayer
{
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.startPoint = CGPointMake(0.5, 0.5);
    layer.endPoint = CGPointMake(1.0, 1.0);
    layer.locations = @[@0.0, @0.44, @1.0];
    layer.drawsAsynchronously = YES;
    layer.hidden = !PPUltraCareGlowsFaded;
    if (@available(iOS 12.0, *)) {
        layer.type = kCAGradientLayerRadial;
    }
    return layer;
}

- (void)pp_applyAmbientGlowColor:(UIColor *)color
                            view:(UIView *)view
                   gradientLayer:(CAGradientLayer *)gradientLayer
                       peakAlpha:(CGFloat)peakAlpha
{
    UIColor *safeColor = color ?: UIColor.clearColor;
    UIColor *resolvedColor = PPUltraCareResolvedColor(safeColor, self.traitCollection);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (PPUltraCareGlowsFaded) {
        view.backgroundColor = UIColor.clearColor;
        view.layer.shadowOpacity = 0.0;
        gradientLayer.hidden = NO;
        gradientLayer.colors = @[
            (id)[resolvedColor colorWithAlphaComponent:peakAlpha].CGColor,
            (id)[resolvedColor colorWithAlphaComponent:(peakAlpha * 0.34)].CGColor,
            (id)[resolvedColor colorWithAlphaComponent:0.0].CGColor
        ];
    } else {
        gradientLayer.hidden = YES;
        view.backgroundColor = [safeColor colorWithAlphaComponent:peakAlpha];
        view.layer.shadowOpacity = 0.22;
        [view pp_setShadowColor:view.backgroundColor];
    }
    [CATransaction commit];
}

#pragma mark - Layout and appearance

- (void)layoutSubviews
{
    [super layoutSubviews];

    _surfaceGradientLayer.frame = _surfaceView.bounds;
    _surfaceGradientLayer.cornerRadius = PPUltraCareSurfaceCornerRadius;

    CGFloat glowDiameter = CGRectGetWidth(_topAmbientGlowView.bounds);
    _topAmbientGlowView.layer.cornerRadius = glowDiameter * 0.5;
    _bottomAmbientGlowView.layer.cornerRadius = CGRectGetWidth(_bottomAmbientGlowView.bounds) * 0.5;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _topAmbientGlowLayer.frame = _topAmbientGlowView.bounds;
    _topAmbientGlowLayer.cornerRadius = glowDiameter * 0.5;
    _topAmbientGlowLayer.masksToBounds = YES;
    _bottomAmbientGlowLayer.frame = _bottomAmbientGlowView.bounds;
    _bottomAmbientGlowLayer.cornerRadius = CGRectGetWidth(_bottomAmbientGlowView.bounds) * 0.5;
    _bottomAmbientGlowLayer.masksToBounds = YES;
    [CATransaction commit];

    _heroPortalView.layer.cornerRadius = CGRectGetHeight(_heroPortalView.bounds) * 0.5;
    _heroInnerView.layer.cornerRadius = CGRectGetHeight(_heroInnerView.bounds) * 0.5;
    _eyebrowLabel.layer.cornerRadius = CGRectGetHeight(_eyebrowLabel.bounds) * 0.5;

    CGRect orbitBounds = _orbitCarrierView.bounds;
    _orbitRingLayer.frame = orbitBounds;
    _orbitRingLayer.path =
        [UIBezierPath bezierPathWithOvalInRect:CGRectInset(orbitBounds, 1.5, 1.5)].CGPath;

    CGRect pulseBounds = CGRectInset(_heroPortalView.bounds, 8.0, 8.0);
    _pulseRingLayer.frame = _heroPortalView.bounds;
    _pulseRingLayer.path = [UIBezierPath bezierPathWithOvalInRect:pulseBounds].CGPath;

    CGRect highlightBounds = CGRectInset(_surfaceView.bounds, 0.75, 0.75);
    CGFloat highlightRadius = MAX(0.0, PPUltraCareSurfaceCornerRadius - 0.75);
    _edgeHighlightLayer.frame = _surfaceView.bounds;
    _edgeHighlightLayer.path =
        [UIBezierPath bezierPathWithRoundedRect:highlightBounds
                                   cornerRadius:highlightRadius].CGPath;

    self.contentView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:_surfaceView.frame
                                   cornerRadius:PPUltraCareSurfaceCornerRadius].CGPath;

    [_surfaceView bringSubviewToFront:_topAccentLineView];
    [_surfaceView bringSubviewToFront:_heroPortalView];
    [_surfaceView bringSubviewToFront:_eyebrowLabel];
    [_surfaceView bringSubviewToFront:_titleLabel];
    [_surfaceView bringSubviewToFront:_subtitleLabel];
    [_surfaceView bringSubviewToFront:_ctaView];
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

- (void)pp_applyTypography
{
    UIFont *eyebrowBase = [GM boldFontWithSize:10.0]
        ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    UIFont *titleBase = [GM boldFontWithSize:21.0]
        ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    UIFont *subtitleBase = [GM MidFontWithSize:11.5]
        ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    UIFont *ctaBase = [GM boldFontWithSize:11.5]
        ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];

    if (@available(iOS 11.0, *)) {
        _eyebrowLabel.font =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                scaledFontForFont:eyebrowBase maximumPointSize:13.0];
        _titleLabel.font =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3]
                scaledFontForFont:titleBase maximumPointSize:25.0];
        _subtitleLabel.font =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                scaledFontForFont:subtitleBase maximumPointSize:15.0];
        _ctaLabel.font =
            [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                scaledFontForFont:ctaBase maximumPointSize:15.0];
    } else {
        _eyebrowLabel.font = eyebrowBase;
        _titleLabel.font = titleBase;
        _subtitleLabel.font = subtitleBase;
        _ctaLabel.font = ctaBase;
    }
}

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPPetCareAccentColor() ?: AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *textColor = PPPetCareTextColor() ?: UIColor.labelColor;
    UIColor *secondaryTextColor = PPPetCareSecondaryTextColor() ?: UIColor.secondaryLabelColor;

    UIColor *lightStart = [UIColor colorWithRed:0.965 green:0.986 blue:0.978 alpha:1.0];
    UIColor *lightMiddle = [UIColor colorWithRed:0.995 green:0.998 blue:0.996 alpha:1.0];
    UIColor *lightEnd = [UIColor colorWithRed:0.940 green:0.970 blue:0.960 alpha:1.0];
    UIColor *darkStart = [UIColor colorWithRed:0.050 green:0.070 blue:0.066 alpha:1.0];
    UIColor *darkMiddle = [UIColor colorWithRed:0.075 green:0.095 blue:0.090 alpha:1.0];
    UIColor *darkEnd = [UIColor colorWithRed:0.045 green:0.060 blue:0.058 alpha:1.0];

    NSArray<UIColor *> *gradientColors = dark
        ? @[darkStart, darkMiddle, darkEnd]
        : @[lightStart, lightMiddle, lightEnd];
    _surfaceGradientLayer.colors = @[
        (id)PPUltraCareResolvedColor(gradientColors[0], self.traitCollection).CGColor,
        (id)PPUltraCareResolvedColor(gradientColors[1], self.traitCollection).CGColor,
        (id)PPUltraCareResolvedColor(gradientColors[2], self.traitCollection).CGColor
    ];
    _surfaceGradientLayer.locations = @[@0.0, @0.58, @1.0];

    UIColor *surfaceBorder =
        dark ? [accent colorWithAlphaComponent:0.22] : [UIColor.whiteColor colorWithAlphaComponent:0.94];
    [_surfaceView pp_setBorderColor:surfaceBorder];

    UIColor *bottomGlowColor = [UIColor colorNamed:@"NewBg"];
    CGFloat ambientGlowPeakAlpha = dark ? 0.14 : 0.11;
    [self pp_applyAmbientGlowColor:accent
                             view:_topAmbientGlowView
                    gradientLayer:_topAmbientGlowLayer
                        peakAlpha:ambientGlowPeakAlpha];
    [self pp_applyAmbientGlowColor:bottomGlowColor
                             view:_bottomAmbientGlowView
                    gradientLayer:_bottomAmbientGlowLayer
                        peakAlpha:dark ? 0.14 : 0.15];

    UIColor *portalFill =
        PPUltraCareDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.28],
                                [UIColor.whiteColor colorWithAlphaComponent:0.055]);
    _heroPortalView.backgroundColor = portalFill;
    [_heroPortalView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.28 : 0.16]];

    UIColor *innerFill =
        PPUltraCareDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.36],
                                [accent colorWithAlphaComponent:0.10]);
    _heroInnerView.backgroundColor = innerFill;
    [_heroInnerView pp_setBorderColor:[UIColor.whiteColor colorWithAlphaComponent:dark ? 0.08 : 0.82]];

    UIColor *ringColor = [accent colorWithAlphaComponent:dark ? 0.40 : 0.28];
    _orbitRingLayer.strokeColor = PPUltraCareResolvedColor(ringColor, self.traitCollection).CGColor;
    _pulseRingLayer.strokeColor =
        PPUltraCareResolvedColor([accent colorWithAlphaComponent:dark ? 0.22 : 0.16],
                                 self.traitCollection).CGColor;
    _orbitNodeView.backgroundColor = accent;
    _orbitNodeView.layer.shadowColor =
        PPUltraCareResolvedColor(accent, self.traitCollection).CGColor;
    _orbitNodeView.layer.shadowOpacity = dark ? 0.34 : 0.24;
    _orbitNodeView.layer.shadowRadius = 5.0;
    _orbitNodeView.layer.shadowOffset = CGSizeZero;
    _fallbackIconView.tintColor = accent;

    _topAccentLineView.backgroundColor = [AppPrimaryClrDarker colorWithAlphaComponent:dark ? 0.88 : 0.82];
    _eyebrowLabel.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.10];
    [_eyebrowLabel pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.14]];
    _eyebrowLabel.textColor = accent;
    _titleLabel.textColor = textColor;
    _subtitleLabel.textColor = secondaryTextColor;

    UIColor *ctaFill = [accent colorWithAlphaComponent:dark ? 0.16 : 0.09];
    _ctaView.backgroundColor = ctaFill;
    [_ctaView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.22 : 0.12]];
    _ctaLabel.textColor = textColor;
    _ctaArrowView.tintColor = accent;

    UIColor *edgeColor = dark
        ? [UIColor.whiteColor colorWithAlphaComponent:0.055]
        : [UIColor.whiteColor colorWithAlphaComponent:0.74];
    _edgeHighlightLayer.strokeColor =
        PPUltraCareResolvedColor(edgeColor, self.traitCollection).CGColor;

    self.contentView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.contentView.layer.shadowOpacity = dark ? 0.0 : 0.075;
    self.contentView.layer.shadowRadius = 20.0;
    self.contentView.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    [self setNeedsLayout];
    [self pp_startBackgroundMotionIfNeeded];
}

#pragma mark - Configuration

- (void)configure
{
    [self configureWithAnimationName:PPUltraCareDefaultAnimationName];
}

- (void)configureWithAnimationName:(NSString *)animationName
{
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _surfaceView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;
    _eyebrowLabel.textAlignment = alignment;
    _titleLabel.textAlignment = alignment;
    _subtitleLabel.textAlignment = alignment;
    _ctaLabel.textAlignment = alignment;

    _eyebrowLabel.text = kLang(@"home_premium_care_eyebrow") ?: @"";
    _titleLabel.text = kLang(@"home_premium_care_title") ?: @"";
    _subtitleLabel.text = kLang(@"home_premium_care_subtitle") ?: @"";
    _ctaLabel.text = kLang(@"home_premium_care_cta") ?: @"";

    NSString *arrowName = Language.isRTL ? @"arrow.left" : @"arrow.right";
    UIImageSymbolConfiguration *arrowConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                         weight:UIImageSymbolWeightSemibold];
    _ctaArrowView.image =
        [[UIImage systemImageNamed:arrowName withConfiguration:arrowConfiguration]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    self.accessibilityLabel =
        [NSString stringWithFormat:@"%@. %@",
                                   _titleLabel.text ?: @"",
                                   _subtitleLabel.text ?: @""];
    self.accessibilityHint = _ctaLabel.text;

    [self pp_applyTheme];
    [self pp_configureCareAnimationNamed:animationName];
    [self pp_startBackgroundMotionIfNeeded];
}

- (void)pp_configureCareAnimationNamed:(NSString *)animationName
{
    NSString *safeName = PPSafeString(animationName);
    if (safeName.length == 0) {
        safeName = PPUltraCareDefaultAnimationName;
    }

    if ([_currentAnimationName isEqualToString:safeName]) {
        if (_careAnimationView.sceneModel) {
            _animationReady = YES;
            [self pp_revealConfiguredCareAnimation];
            return;
        }
        if (_animationLoading) {
            return;
        }
    }

    _currentAnimationName = [safeName copy];
    _animationLoadToken += 1;
    NSInteger loadToken = _animationLoadToken;
    _animationLoading = YES;
    _animationReady = NO;
    _didRevealAnimation = NO;
    [_careAnimationView stop];
    _careAnimationView.hidden = YES;
    _careAnimationView.alpha = 0.0;
    _careAnimationView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    _fallbackIconView.hidden = NO;
    _fallbackIconView.alpha = 1.0;

    __weak typeof(self) weakSelf = self;
    [AppClasses setAnimationNamed:safeName
                            ToView:_careAnimationView
                         withSpeed:0.48
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_animationLoadToken != loadToken) {
                return;
            }

            strongSelf->_animationLoading = NO;
            strongSelf->_animationReady = success && strongSelf->_careAnimationView.sceneModel;
            if (!strongSelf->_animationReady) {
                strongSelf->_careAnimationView.hidden = YES;
                strongSelf->_fallbackIconView.hidden = NO;
                strongSelf->_fallbackIconView.alpha = 1.0;
                return;
            }
            [strongSelf pp_revealConfiguredCareAnimation];
        });
    }];
}

- (void)pp_revealConfiguredCareAnimation
{
    if (!_animationReady || !_careAnimationView.sceneModel) {
        return;
    }
    if (_shouldDeferEntrance && !_didPlayPostLayoutEntrance) {
        _careAnimationView.hidden = YES;
        _careAnimationView.alpha = 0.0;
        _fallbackIconView.hidden = NO;
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [_careAnimationView stop];
        _careAnimationView.animationProgress = 0.42;
        _careAnimationView.hidden = NO;
        _careAnimationView.alpha = 1.0;
        _careAnimationView.transform = CGAffineTransformIdentity;
        _fallbackIconView.hidden = YES;
        _fallbackIconView.alpha = 0.0;
        _didRevealAnimation = YES;
        return;
    }

    if (_didRevealAnimation &&
        !_careAnimationView.hidden &&
        _careAnimationView.alpha >= 0.99) {
        if (!_careAnimationView.isAnimationPlaying && self.window) {
            _careAnimationView.loopAnimation = YES;
            [_careAnimationView playFromProgress:0.0
                                     toProgress:1.0
                                 withCompletion:nil];
        }
        return;
    }

    _didRevealAnimation = YES;
    _careAnimationView.hidden = NO;
    _careAnimationView.alpha = 0.0;
    _careAnimationView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    _fallbackIconView.hidden = NO;
    _fallbackIconView.alpha = 1.0;

    if (self.window) {
        _careAnimationView.loopAnimation = YES;
        [_careAnimationView playFromProgress:0.0
                                 toProgress:1.0
                             withCompletion:nil];
    }

    [UIView animateWithDuration:0.46
                          delay:_didPlayPostLayoutEntrance ? 0.10 : 0.04
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_careAnimationView.alpha = 1.0;
        self->_careAnimationView.transform = CGAffineTransformIdentity;
        self->_fallbackIconView.alpha = 0.0;
        self->_fallbackIconView.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(__unused BOOL finished) {
        self->_fallbackIconView.hidden = YES;
        self->_fallbackIconView.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - Entrance choreography

- (NSArray<UIView *> *)pp_copyViews
{
    return @[_topAccentLineView, _eyebrowLabel, _titleLabel, _subtitleLabel, _ctaView];
}

- (void)pp_preparePostLayoutEntranceState
{
    _entranceToken += 1;
    _didPlayPostLayoutEntrance = NO;
    _shouldDeferEntrance = YES;
    [self pp_stopAmbientMotion];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        _shouldDeferEntrance = NO;
        [self pp_applyStablePresentationState];
        [self pp_revealConfiguredCareAnimation];
        return;
    }

    _topAmbientGlowView.alpha = 0.0;
    _bottomAmbientGlowView.alpha = 0.0;
    _topAmbientGlowView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(9.0, -6.0),
                                CGAffineTransformMakeScale(0.98, 0.98));
    _bottomAmbientGlowView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(-7.0, 6.0),
                                CGAffineTransformMakeScale(0.98, 0.98));

    CGFloat heroDirection = Language.isRTL ? -10.0 : 10.0;
    _heroPortalView.alpha = 0.0;
    _heroPortalView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(heroDirection, 0.0),
                                CGAffineTransformMakeScale(0.965, 0.965));

    [[self pp_copyViews] enumerateObjectsUsingBlock:^(UIView * _Nonnull view,
                                                       NSUInteger idx,
                                                       BOOL * _Nonnull stop) {
        (void)stop;
        view.alpha = 0.0;
        CGFloat offset = 7.0 + MIN((CGFloat)idx, 2.0);
        view.transform = CGAffineTransformMakeTranslation(0.0, offset);
    }];

    _didRevealAnimation = NO;
    [_careAnimationView stop];
    _careAnimationView.animationProgress = 0.0;
    _careAnimationView.hidden = YES;
    _careAnimationView.alpha = 0.0;
    _careAnimationView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    _fallbackIconView.hidden = NO;
    _fallbackIconView.alpha = 0.0;
}

- (void)pp_playPostLayoutEntranceWithDelay:(NSTimeInterval)delay
{
    if (_didPlayPostLayoutEntrance) {
        return;
    }
    _didPlayPostLayoutEntrance = YES;
    _shouldDeferEntrance = NO;
    _entranceToken += 1;
    NSInteger entranceToken = _entranceToken;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_applyStablePresentationState];
        [self pp_revealConfiguredCareAnimation];
        return;
    }

    [UIView animateWithDuration:0.62
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_topAmbientGlowView.alpha = 1.0;
        self->_bottomAmbientGlowView.alpha = 1.0;
        self->_topAmbientGlowView.transform = CGAffineTransformIdentity;
        self->_bottomAmbientGlowView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.48
                          delay:delay + 0.02
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_heroPortalView.alpha = 1.0;
        self->_heroPortalView.transform = CGAffineTransformIdentity;
        self->_fallbackIconView.alpha = 1.0;
    } completion:nil];

    [[self pp_copyViews] enumerateObjectsUsingBlock:^(UIView * _Nonnull view,
                                                       NSUInteger idx,
                                                       BOOL * _Nonnull stop) {
        (void)stop;
        NSTimeInterval viewDelay = delay + 0.08 + MIN((NSTimeInterval)idx * 0.055, 0.18);
        [UIView animateWithDuration:0.42
                              delay:viewDelay
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    if (_animationReady) {
        [self pp_revealConfiguredCareAnimation];
    } else {
        [self pp_configureCareAnimationNamed:_currentAnimationName ?: PPUltraCareDefaultAnimationName];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)((delay + 0.64) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self->_entranceToken == entranceToken && self.window) {
            [self pp_startBackgroundMotionIfNeeded];
        }
    });
}

- (void)pp_applyStablePresentationState
{
    _topAmbientGlowView.alpha = 1.0;
    _bottomAmbientGlowView.alpha = 1.0;
    _topAmbientGlowView.transform = CGAffineTransformIdentity;
    _bottomAmbientGlowView.transform = CGAffineTransformIdentity;
    _heroPortalView.alpha = 1.0;
    _heroPortalView.transform = CGAffineTransformIdentity;
    _fallbackIconView.alpha = 1.0;
    _fallbackIconView.transform = CGAffineTransformIdentity;
    for (UIView *view in [self pp_copyViews]) {
        view.alpha = 1.0;
        view.transform = CGAffineTransformIdentity;
    }
}

#pragma mark - Ambient motion

- (void)pp_addFloatAnimationToView:(UIView *)view
                               key:(NSString *)key
                                 x:(CGFloat)x
                                 y:(CGFloat)y
                          duration:(NSTimeInterval)duration
{
    if (!view || [view.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *xAnimation =
        [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    xAnimation.fromValue = @0.0;
    xAnimation.toValue = @(x);

    CABasicAnimation *yAnimation =
        [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    yAnimation.fromValue = @0.0;
    yAnimation.toValue = @(y);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[xAnimation, yAnimation];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction =
        [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_startBackgroundMotionIfNeeded
{
    if (_shouldDeferEntrance || !self.window) {
        return;
    }
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopBackgroundMotion];
        if (_animationReady) {
            [_careAnimationView stop];
            _careAnimationView.animationProgress = 0.42;
        }
        return;
    }

    [self pp_addFloatAnimationToView:_topAmbientGlowView
                                key:PPUltraCareGlowTopAnimationKey
                                  x:-5.0
                                  y:4.0
                           duration:5.8];
    [self pp_addFloatAnimationToView:_bottomAmbientGlowView
                                key:PPUltraCareGlowBottomAnimationKey
                                  x:4.0
                                  y:-3.0
                           duration:6.6];

    if (![_orbitCarrierView.layer animationForKey:PPUltraCareOrbitAnimationKey]) {
        CABasicAnimation *orbit =
            [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        orbit.fromValue = @0.0;
        orbit.toValue = @(M_PI * 2.0);
        orbit.duration = 16.0;
        orbit.repeatCount = HUGE_VALF;
        orbit.timingFunction =
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        [_orbitCarrierView.layer addAnimation:orbit forKey:PPUltraCareOrbitAnimationKey];
    }

    if (![_pulseRingLayer animationForKey:PPUltraCarePulseAnimationKey]) {
        CABasicAnimation *scale =
            [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scale.fromValue = @0.985;
        scale.toValue = @1.035;

        CABasicAnimation *opacity =
            [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacity.fromValue = @0.22;
        opacity.toValue = @0.06;

        CAAnimationGroup *pulse = [CAAnimationGroup animation];
        pulse.animations = @[scale, opacity];
        pulse.duration = 3.8;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunction =
            [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];
        [_pulseRingLayer addAnimation:pulse forKey:PPUltraCarePulseAnimationKey];
    }

    if (_animationReady && !_careAnimationView.isAnimationPlaying) {
        _careAnimationView.hidden = NO;
        _careAnimationView.alpha = 1.0;
        _careAnimationView.loopAnimation = YES;
        _fallbackIconView.hidden = YES;
        _fallbackIconView.alpha = 0.0;
        [_careAnimationView playFromProgress:0.0
                                 toProgress:1.0
                             withCompletion:nil];
    }
}

- (void)pp_stopAmbientMotion
{
    [_topAmbientGlowView.layer removeAnimationForKey:PPUltraCareGlowTopAnimationKey];
    [_bottomAmbientGlowView.layer removeAnimationForKey:PPUltraCareGlowBottomAnimationKey];
    [_orbitCarrierView.layer removeAnimationForKey:PPUltraCareOrbitAnimationKey];
    [_pulseRingLayer removeAnimationForKey:PPUltraCarePulseAnimationKey];
}

- (void)pp_stopBackgroundMotion
{
    [self pp_stopAmbientMotion];
    [_careAnimationView stop];
}

#pragma mark - Lifecycle

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startBackgroundMotionIfNeeded];
    } else {
        [self pp_stopBackgroundMotion];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _animationLoadToken += 1;
    _entranceToken += 1;
    [self pp_stopBackgroundMotion];

    _currentAnimationName = nil;
    _animationLoading = NO;
    _animationReady = NO;
    _didRevealAnimation = NO;
    _didPlayPostLayoutEntrance = NO;
    _shouldDeferEntrance = NO;

    [_careAnimationView stop];
    _careAnimationView.hidden = YES;
    _careAnimationView.alpha = 0.0;
    _careAnimationView.transform = CGAffineTransformIdentity;
    _fallbackIconView.hidden = NO;
    _fallbackIconView.alpha = 1.0;
    _fallbackIconView.transform = CGAffineTransformIdentity;

    _eyebrowLabel.text = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _ctaLabel.text = nil;
    [self pp_applyStablePresentationState];
}

- (void)pp_reduceMotionStatusDidChange:(__unused NSNotification *)notification
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopBackgroundMotion];
        [self pp_applyStablePresentationState];
        [self pp_revealConfiguredCareAnimation];
    } else {
        [self pp_startBackgroundMotionIfNeeded];
    }
}

- (void)pp_contentSizeCategoryDidChange:(__unused NSNotification *)notification
{
    [self pp_applyTypography];
    [self setNeedsLayout];
}

@end
