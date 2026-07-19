//
//  PPHomeUltraPremuimPetCareCell.m
//  Pure Pets
//

#import "PPHomeUltraPremuimPetCareCell.h"
#import "AppClasses.h"
#import "PPHomePresentationTokens.h"

 static NSString * const PPUltraCareGlowTopAnimationKey = @"pp.home.ultraCare.glow.top";
static NSString * const PPUltraCareGlowBottomAnimationKey = @"pp.home.ultraCare.glow.bottom";
static NSString * const PPUltraCareOrbitAnimationKey = @"pp.home.ultraCare.orbit";
static NSString * const PPUltraCarePulseAnimationKey = @"pp.home.ultraCare.pulse";
static NSString * const PPUltraCareFloatingCircleAnimationKeyPrefix = @"pp.home.ultraCare.floatingCircle";
static BOOL const PPUltraCareGlowsFaded = YES;
static CGFloat const PPUltraCareSurfaceCornerRadius = 24.0;
static CGFloat const PPUltraCareHeroPortalSize = 94.0;
static CGFloat const PPUltraCareOrbitCarrierSize = 78.0;
static CGFloat const PPUltraCareHeroInnerSize = 66.0;
static CGFloat const PPUltraCareFallbackIconSize = 27.0;
static CGFloat const PPUltraCareAnimationSize = 122.0;

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
- (UIView *)pp_makeFloatingAmbientCircleView;
- (CAGradientLayer *)pp_makeAmbientGlowLayer;
- (void)pp_applyAmbientGlowColor:(UIColor *)color
                            view:(UIView *)view
                   gradientLayer:(CAGradientLayer *)gradientLayer
                       peakAlpha:(CGFloat)peakAlpha;
- (void)pp_applyFloatingAmbientCirclePaletteWithAccent:(UIColor *)accent
                                                  dark:(BOOL)dark;
- (void)pp_updateAdaptiveLayout;
@end

@implementation PPHomeUltraPremuimPetCareCell {
    UIView *_surfaceView;
    CAGradientLayer *_surfaceGradientLayer;
    CAShapeLayer *_edgeHighlightLayer;

    UIView *_topAmbientGlowView;
    UIView *_bottomAmbientGlowView;
    CAGradientLayer *_topAmbientGlowLayer;
    CAGradientLayer *_bottomAmbientGlowLayer;
    NSArray<UIView *> *_floatingAmbientCircleViews;
    UIView *_topAccentLineView;

    UIView *_heroPortalView;
    UIView *_heroInnerView;
    UIView *_orbitCarrierView;
    CAShapeLayer *_orbitRingLayer;
    CAShapeLayer *_pulseRingLayer;
    UIView *_orbitNodeView;

    UIImageView *_fallbackIconView;

    PPInsetLabel *_eyebrowLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;

    UIView *_ctaView;
    UILabel *_ctaLabel;
    UIImageView *_ctaArrowView;
    NSLayoutConstraint *_contentLeadingToPortalConstraint;
    NSLayoutConstraint *_contentLeadingToSurfaceConstraint;
    NSLayoutConstraint *_ctaHeightConstraint;

    NSString *_currentAnimationName;
    NSInteger _animationLoadToken;
    NSInteger _entranceToken;
    BOOL _animationLoading;
    BOOL _animationReady;
    BOOL _didRevealAnimation;
    BOOL _didPlayPostLayoutEntrance;
    BOOL _shouldDeferEntrance;

    LOTAnimationView *_lottieHeaderView;
    NSString *_currentLottiePath;
    NSInteger _lottieLoopToken;
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

    NSMutableArray<UIView *> *floatingAmbientCircleViews = [NSMutableArray arrayWithCapacity:5];
    for (NSUInteger idx = 0; idx < 5; idx++) {
        UIView *circleView = [self pp_makeFloatingAmbientCircleView];
        circleView.hidden = YES;
        [_surfaceView addSubview:circleView];
        [floatingAmbientCircleViews addObject:circleView];
    }
    _floatingAmbientCircleViews = [floatingAmbientCircleViews copy];

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
    PPApplyContinuousCorners(_heroPortalView, 18.0);
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
    PPApplyContinuousCorners(_heroInnerView, 18.0);
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

    _lottieHeaderView = [[LOTAnimationView alloc] init];
    _lottieHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    _lottieHeaderView.userInteractionEnabled = NO;
    _lottieHeaderView.isAccessibilityElement = NO;
    _lottieHeaderView.accessibilityElementsHidden = YES;
    _lottieHeaderView.backgroundColor = UIColor.clearColor;
    _lottieHeaderView.contentMode = UIViewContentModeScaleAspectFill;
    _lottieHeaderView.hidden = YES;
    _lottieHeaderView.alpha = 1.0;
    [_surfaceView addSubview:_lottieHeaderView];

    _eyebrowLabel = [[PPInsetLabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.numberOfLines = 1;
    _eyebrowLabel.adjustsFontSizeToFitWidth = YES;
    _eyebrowLabel.minimumScaleFactor = 0.86;
    _eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _eyebrowLabel.layer.borderWidth = 0.2;
    _eyebrowLabel.layer.masksToBounds = YES;
    _eyebrowLabel.textInsets = UIEdgeInsetsMake(3.0, 10.0, 3.0, 10.0);
    if (@available(iOS 13.0, *)) {
        _eyebrowLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.numberOfLines = 2;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    [_surfaceView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [_subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisVertical];
    [_surfaceView addSubview:_subtitleLabel];
    //_subtitleLabel.hidden = YES;
    _ctaView = [[UIView alloc] init];
    _ctaView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaView.userInteractionEnabled = NO;
    _ctaView.layer.borderWidth = 0.1;
    PPApplyContinuousCorners(_ctaView, PPHomeControlCornerRadius);
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

    UIView *circle0 = _floatingAmbientCircleViews[0];
    UIView *circle1 = _floatingAmbientCircleViews[1];
    UIView *circle2 = _floatingAmbientCircleViews[2];
    UIView *circle3 = _floatingAmbientCircleViews[3];
    UIView *circle4 = _floatingAmbientCircleViews[4];

    _contentLeadingToPortalConstraint =
        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroPortalView.trailingAnchor
                                                    constant:18.0];
    _contentLeadingToSurfaceConstraint =
        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor
                                                    constant:20.0];
    _ctaHeightConstraint =
        [_ctaView.heightAnchor constraintEqualToConstant:PPHomeButtonHeight];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_topAmbientGlowView.widthAnchor constraintEqualToConstant:372.0],
        [_topAmbientGlowView.heightAnchor constraintEqualToConstant:372.0],
        [_topAmbientGlowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:78.0],
        [_topAmbientGlowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:-82.0],

        [_bottomAmbientGlowView.widthAnchor constraintEqualToConstant:312.0],
        [_bottomAmbientGlowView.heightAnchor constraintEqualToConstant:312.0],
        [_bottomAmbientGlowView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:-54.0],
        [_bottomAmbientGlowView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:112.0],

        [circle0.widthAnchor constraintEqualToConstant:18.0],
        [circle0.heightAnchor constraintEqualToAnchor:circle0.widthAnchor],
        [circle0.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-30.0],
        [circle0.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:12.0],

        [circle1.widthAnchor constraintEqualToConstant:10.0],
        [circle1.heightAnchor constraintEqualToAnchor:circle1.widthAnchor],
        [circle1.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:32.0],
        [circle1.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:48.0],

        [circle2.widthAnchor constraintEqualToConstant:13.0],
        [circle2.heightAnchor constraintEqualToAnchor:circle2.widthAnchor],
        [circle2.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-104.0],
        [circle2.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-24.0],

        [circle3.widthAnchor constraintEqualToConstant:17.0],
        [circle3.heightAnchor constraintEqualToAnchor:circle3.widthAnchor],
        [circle3.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-70.0],
        [circle3.bottomAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:34.0],

        [circle4.widthAnchor constraintEqualToConstant:18.0],
        [circle4.heightAnchor constraintEqualToAnchor:circle4.widthAnchor],
        [circle4.centerXAnchor constraintEqualToAnchor:_surfaceView.centerXAnchor constant:24.0],
        [circle4.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:82.0],

        [_topAccentLineView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:20.0],
        [_topAccentLineView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_topAccentLineView.widthAnchor constraintEqualToConstant:54.0],
        [_topAccentLineView.heightAnchor constraintEqualToConstant:4.0],

        [_heroPortalView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:20.0],
        [_heroPortalView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor constant:1.0],
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

        [_lottieHeaderView.centerXAnchor constraintEqualToAnchor:_heroInnerView.centerXAnchor],
        [_lottieHeaderView.centerYAnchor constraintEqualToAnchor:_heroInnerView.centerYAnchor],
        [_lottieHeaderView.widthAnchor constraintEqualToConstant:PPUltraCareAnimationSize],
        [_lottieHeaderView.heightAnchor constraintEqualToConstant:PPUltraCareAnimationSize],

        _contentLeadingToPortalConstraint,
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:20.0],
        [_eyebrowLabel.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_surfaceView.trailingAnchor constant:-20.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:7.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-20.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:5.0],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_ctaView.topAnchor constant:-PPSpaceXS],

        [_ctaView.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_ctaView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-16.0],
        _ctaHeightConstraint,
        [_ctaView.widthAnchor constraintLessThanOrEqualToAnchor:_titleLabel.widthAnchor],
        [_ctaView.widthAnchor constraintGreaterThanOrEqualToConstant:128.0],

        [_ctaLabel.leadingAnchor constraintEqualToAnchor:_ctaView.leadingAnchor constant:PPSpaceMD],
        [_ctaLabel.centerYAnchor constraintEqualToAnchor:_ctaView.centerYAnchor],
        [_ctaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_ctaArrowView.leadingAnchor constant:-PPSpaceSM],

        [_ctaArrowView.trailingAnchor constraintEqualToAnchor:_ctaView.trailingAnchor constant:-PPSpaceMD],
        [_ctaArrowView.centerYAnchor constraintEqualToAnchor:_ctaView.centerYAnchor],
        [_ctaArrowView.widthAnchor constraintEqualToConstant:13.0],
        [_ctaArrowView.heightAnchor constraintEqualToConstant:13.0],
    ]];

    [self pp_updateAdaptiveLayout];
}

- (UIView *)pp_makeAmbientGlowView
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.hidden = YES;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowRadius = 42.0;
    view.layer.shadowOpacity = 0.16;
    return view;
}

- (UIView *)pp_makeFloatingAmbientCircleView
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.isAccessibilityElement = NO;
    view.accessibilityElementsHidden = YES;
    view.layer.borderWidth = 0.55;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowOpacity = 0.08;
    view.layer.shadowRadius = 6.0;
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

- (void)pp_applyFloatingAmbientCirclePaletteWithAccent:(UIColor *)accent
                                                  dark:(BOOL)dark
{
    UIColor *safeAccent = accent ?: AppPrimaryClr ?: [UIColor colorWithRed:0.949 green:0.149 blue:0.455 alpha:1.0];
    UIColor *resolvedAccent = PPUltraCareResolvedColor(safeAccent, self.traitCollection);
    NSArray<NSNumber *> *fillAlphas = dark
        ? @[@0.14, @0.08, @0.105, @0.055, @0.05]
        : @[@0.55, @0.025, @0.03, @0.02, @0.01];
    NSArray<NSNumber *> *borderAlphas = dark
        ? @[@0.10, @0.06, @0.08, @0.05, @0.055]
        : @[@0.14, @0.08, @0.11, @0.06, @0.07];
    NSArray<NSNumber *> *shadowRadii = @[@8.0, @5.0, @6.5, @4.0, @4.5];

    [_floatingAmbientCircleViews enumerateObjectsUsingBlock:^(UIView * _Nonnull circleView,
                                                              NSUInteger idx,
                                                              BOOL * _Nonnull stop) {
        (void)stop;
        NSUInteger styleIndex = MIN(idx, fillAlphas.count - 1);
        CGFloat fillAlpha = [fillAlphas[styleIndex] doubleValue];
        CGFloat borderAlpha = [borderAlphas[styleIndex] doubleValue];

        circleView.backgroundColor = [safeAccent colorWithAlphaComponent:fillAlpha];
        [circleView pp_setBorderColor:[UIColor.whiteColor colorWithAlphaComponent:borderAlpha]];
        circleView.layer.shadowColor = resolvedAccent.CGColor;
        circleView.layer.shadowOpacity = dark ? 0.12 : 0.07;
        circleView.layer.shadowRadius = [shadowRadii[styleIndex] doubleValue];
    }];
}

#pragma mark - Layout and appearance

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self pp_updateAdaptiveLayout];
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

    for (UIView *circleView in _floatingAmbientCircleViews) {
        CGFloat circleRadius = CGRectGetWidth(circleView.bounds) * 0.5;
        PPApplyContinuousCorners(circleView, circleRadius);
        circleView.layer.shadowPath =
            [UIBezierPath bezierPathWithOvalInRect:circleView.bounds].CGPath;
    }

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

    for (UIView *circleView in _floatingAmbientCircleViews) {
        [_surfaceView bringSubviewToFront:circleView];
    }
     [_surfaceView bringSubviewToFront:_topAccentLineView];
    [_surfaceView bringSubviewToFront:_heroPortalView];
    [_surfaceView bringSubviewToFront:_eyebrowLabel];
    [_surfaceView bringSubviewToFront:_titleLabel];
    [_surfaceView bringSubviewToFront:_subtitleLabel];
    [_surfaceView bringSubviewToFront:_ctaView];
    [_surfaceView bringSubviewToFront:_lottieHeaderView];
}

- (void)pp_updateAdaptiveLayout
{
    BOOL accessibilityCategory =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    BOOL usesFullWidthContent = _contentLeadingToSurfaceConstraint.active;
    if (usesFullWidthContent != accessibilityCategory) {
        _contentLeadingToPortalConstraint.active = !accessibilityCategory;
        _contentLeadingToSurfaceConstraint.active = accessibilityCategory;
    }
    _heroPortalView.hidden = accessibilityCategory;
    _lottieHeaderView.hidden = accessibilityCategory || !_animationReady;
    _ctaHeightConstraint.constant = accessibilityCategory ? 52.0 : PPHomeButtonHeight;
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
    CGFloat ambientGlowPeakAlpha = 0.0;
    [self pp_applyAmbientGlowColor:accent
                             view:_topAmbientGlowView
                    gradientLayer:_topAmbientGlowLayer
                        peakAlpha:ambientGlowPeakAlpha];
    [self pp_applyAmbientGlowColor:bottomGlowColor
                             view:_bottomAmbientGlowView
                    gradientLayer:_bottomAmbientGlowLayer
                        peakAlpha:0.0];
    [self pp_applyFloatingAmbientCirclePaletteWithAccent:accent dark:dark];
    for (UIView *circleView in _floatingAmbientCircleViews) {
        circleView.alpha = 0.0;
    }

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
    _orbitNodeView.layer.shadowOpacity = dark ? 0.18 : 0.12;
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
    self.contentView.layer.shadowOpacity = dark ? 0.06 : 0.04;
    self.contentView.layer.shadowRadius = 10.0;
    self.contentView.layer.shadowOffset = CGSizeMake(0.0, 5.0);

    [self setNeedsLayout];
    [self pp_stopAmbientMotion];
}

#pragma mark - Configuration
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
    [self pp_stopAmbientMotion];
}

- (void)pp_configureCareAnimationNamed:(NSString *)animationName
{
    NSString *safeName = PPSafeString(animationName);
    if (safeName.length == 0) {
     }

    if ([_currentAnimationName isEqualToString:safeName]) {
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
    _fallbackIconView.hidden = NO;
    _fallbackIconView.alpha = 1.0;

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
    [_floatingAmbientCircleViews enumerateObjectsUsingBlock:^(UIView * _Nonnull circleView,
                                                              NSUInteger idx,
                                                              BOOL * _Nonnull stop) {
        (void)stop;
        CGFloat direction = (idx % 2 == 0) ? 1.0 : -1.0;
        if (Language.isRTL) {
            direction *= -1.0;
        }
        circleView.alpha = 0.0;
        circleView.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(direction * (2.0 + (CGFloat)idx),
                                                                     4.0 + MIN((CGFloat)idx, 2.0)),
                                    CGAffineTransformMakeScale(0.92, 0.92));
    }];

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

    [_floatingAmbientCircleViews enumerateObjectsUsingBlock:^(UIView * _Nonnull circleView,
                                                              NSUInteger idx,
                                                              BOOL * _Nonnull stop) {
        (void)stop;
        NSTimeInterval circleDelay = delay + 0.05 + MIN((NSTimeInterval)idx * 0.035, 0.14);
        [UIView animateWithDuration:0.52
                              delay:circleDelay
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            circleView.alpha = 1.0;
            circleView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

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

    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)((delay + 0.64) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self->_entranceToken == entranceToken && self.window) {
            [self pp_stopAmbientMotion];
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
    for (UIView *circleView in _floatingAmbientCircleViews) {
        circleView.alpha = 1.0;
        circleView.transform = CGAffineTransformIdentity;
        circleView.layer.opacity = 1.0;
    }
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

- (void)pp_addFloatingCircleAnimationToView:(UIView *)view
                                      index:(NSUInteger)index
                                          x:(CGFloat)x
                                          y:(CGFloat)y
                                   duration:(NSTimeInterval)duration
                                 minOpacity:(CGFloat)minOpacity
                                 maxOpacity:(CGFloat)maxOpacity
{
    NSString *key =
        [NSString stringWithFormat:@"%@.%lu",
                                   PPUltraCareFloatingCircleAnimationKeyPrefix,
                                   (unsigned long)index];
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

    CABasicAnimation *scale =
        [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @0.985;
    scale.toValue = @1.035;

    CABasicAnimation *opacity =
        [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @(maxOpacity);
    opacity.toValue = @(minOpacity);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[xAnimation, yAnimation, scale, opacity];
    group.duration = duration;
    group.beginTime = CACurrentMediaTime() + MIN((NSTimeInterval)index * 0.18, 0.64);
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

    CGFloat circleXOffsets[] = {3.0, -2.5, -4.0, 2.0, 3.5};
    CGFloat circleYOffsets[] = {8.0, -6.0, 7.0, -5.0, 5.0};
    NSTimeInterval circleDurations[] = {4.8, 5.6, 6.4, 4.2, 5.1};
    CGFloat circleMinOpacities[] = {0.72, 0.62, 0.68, 0.56, 0.60};
    NSUInteger circleCount = MIN(_floatingAmbientCircleViews.count, (NSUInteger)5);
    for (NSUInteger idx = 0; idx < circleCount; idx++) {
        [self pp_addFloatingCircleAnimationToView:_floatingAmbientCircleViews[idx]
                                            index:idx
                                                x:circleXOffsets[idx]
                                                y:circleYOffsets[idx]
                                         duration:circleDurations[idx]
                                       minOpacity:circleMinOpacities[idx]
                                       maxOpacity:1.0];
    }

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

    [self pp_updateLottieForCurrentTimeIfNeeded];
}

- (void)pp_stopAmbientMotion
{
    [_topAmbientGlowView.layer removeAnimationForKey:PPUltraCareGlowTopAnimationKey];
    [_bottomAmbientGlowView.layer removeAnimationForKey:PPUltraCareGlowBottomAnimationKey];
    [_orbitCarrierView.layer removeAnimationForKey:PPUltraCareOrbitAnimationKey];
    [_pulseRingLayer removeAnimationForKey:PPUltraCarePulseAnimationKey];
    [_floatingAmbientCircleViews enumerateObjectsUsingBlock:^(UIView * _Nonnull circleView,
                                                              NSUInteger idx,
                                                              BOOL * _Nonnull stop) {
        (void)stop;
        NSString *key =
            [NSString stringWithFormat:@"%@.%lu",
                                       PPUltraCareFloatingCircleAnimationKeyPrefix,
                                       (unsigned long)idx];
        [circleView.layer removeAnimationForKey:key];
    }];
}

- (void)pp_stopBackgroundMotion
{
    [self pp_stopAmbientMotion];
     _lottieLoopToken += 1;
    [_lottieHeaderView stop];
    _lottieHeaderView.hidden = YES;
}

#pragma mark - Lifecycle

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_stopAmbientMotion];
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
    _currentLottiePath = nil;

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
        [self pp_stopAmbientMotion];
    }
}

- (void)pp_contentSizeCategoryDidChange:(__unused NSNotification *)notification
{
    [self pp_applyTypography];
    [self pp_updateAdaptiveLayout];
    [self setNeedsLayout];
}

#pragma mark - Lottie

- (void)pp_playLottieLoopWithDelay2s
{
    _lottieLoopToken += 1;
    _lottieHeaderView.hidden = NO;
    _lottieHeaderView.alpha = 1;
    [_lottieHeaderView stop];
    _lottieHeaderView.loopAnimation = NO;
    _lottieHeaderView.animationProgress = 0.42;
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

- (void)pp_updateLottieForCurrentTimeIfNeeded
{
    NSString *path = [self pp_lottieFirebasePathForCurrentTime];
    if (path.length == 0) return;

    if (_currentLottiePath.length > 0 && [_currentLottiePath isEqualToString:path]) {
        if (!_lottieHeaderView.isAnimationPlaying) {
            [self pp_playLottieLoopWithDelay2s];
        }
        return;
    }

    _currentLottiePath = path;
    _lottieHeaderView.alpha = 0.90;
    __weak typeof(self) weakSelf = self;
    NSString *storagePath = [NSString stringWithFormat:@"LottieAnimations/%@.json", path];
    [AppClasses fetchLottieJSONFromFirebasePath:storagePath completion:^(NSDictionary * _Nonnull jsonDict,
                                                                        NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                strongSelf->_currentLottiePath = nil;
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                strongSelf->_currentLottiePath = nil;
                return;
            }

            [strongSelf->_lottieHeaderView setSceneModel:composition];
            [strongSelf->_lottieHeaderView setNeedsLayout];
            [strongSelf->_lottieHeaderView layoutIfNeeded];
            [strongSelf->_surfaceView bringSubviewToFront:strongSelf->_lottieHeaderView];
            [strongSelf pp_playLottieLoopWithDelay2s];
        });
    }];
}

@end
