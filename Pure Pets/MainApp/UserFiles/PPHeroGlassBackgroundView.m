//
//  PPHeroGlassBackgroundView.m
//  Pure Pets
//
//  Reusable decorative glass background extracted from PPUserMenuViewController hero card.
//  Every value, color, timing, layer, and animation matches the original hero exactly.
//

#import "PPHeroGlassBackgroundView.h"
#import "PPMarketplaceHeroCardStyle.h"
#import "Language.h"

static NSString * const PPHeroGlassConstellationOpacityAnimationKey = @"pp.hero.glass.constellation.opacity";
static NSString * const PPHeroGlassDotPulseAnimationKey = @"pp.hero.glass.dot.pulse";

#pragma mark - Color helpers (exact copies from PPUserMenuViewController)

static UIColor *PPHeroGlassDotColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.26];
            }
            return [UIColor colorWithRed:0.530 green:0.485 blue:0.390 alpha:0.30];
        }];
    }
    return [UIColor colorWithWhite:0.35 alpha:0.22];
}

static UIColor *PPHeroGlassDotHaloColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.10];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.62];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.35];
}

static UIColor *PPHeroGlassConstellationLineColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.070];
            }
            return [UIColor colorWithRed:0.540 green:0.495 blue:0.410 alpha:0.105];
        }];
    }
    return [UIColor colorWithWhite:0.35 alpha:0.08];
}

static UIColor *PPHeroGlassAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

static BOOL PPHeroGlassIsDark(UITraitCollection *traitCollection)
{
    if (@available(iOS 13.0, *)) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static UIColor *PPHeroGlassSurfaceBaseColor(UITraitCollection *traitCollection)
{
    UIColor *fallback = [UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        fallback = PPMarketplaceHeroCardResolvedColor(
            [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
                return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor colorWithWhite:0.104 alpha:1.0]
                    : [UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:1.0];
            }],
            traitCollection
        );
    }
    return AppForgroundColr ?: fallback;
}

static UIColor *PPHeroGlassSurfaceHighlightColor(UIColor *surfaceBase,
                                                   BOOL darkMode,
                                                   UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(surfaceBase,
                                      UIColor.whiteColor,
                                      darkMode ? 0.08 : 0.20,
                                      traitCollection);
}

static UIColor *PPHeroGlassBackgroundAccentColor(UIColor *primaryAccent,
                                                  UIColor *surfaceBase,
                                                  BOOL darkMode,
                                                  UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(primaryAccent,
                                      surfaceBase,
                                      darkMode ? 0.12 : 0.18,
                                      traitCollection);
}

static UIColor *PPHeroGlassSurfaceTintColor(UIColor *surfaceBase,
                                             UIColor *backgroundAccent,
                                             BOOL darkMode,
                                             UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(surfaceBase,
                                      backgroundAccent,
                                      darkMode ? 0.095 : 0.038,
                                      traitCollection);
}

static UIColor *PPHeroGlassSurfaceTailColor(UIColor *surfaceTint,
                                             UIColor *backgroundAccent,
                                             BOOL darkMode,
                                             UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(surfaceTint,
                                      backgroundAccent,
                                      darkMode ? 0.062 : 0.024,
                                      traitCollection);
}

static UIColor *PPHeroGlassStrokeColor(BOOL darkMode)
{
    return [UIColor.whiteColor colorWithAlphaComponent:darkMode ? 0.12 : 0.78];
}

#pragma mark - Implementation

@interface PPHeroGlassBackgroundView ()
@property (nonatomic, strong) UIView *materialView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CAGradientLayer *depthLayer;
@property (nonatomic, strong) CAShapeLayer *constellationLayer;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *dotLayers;
@property (nonatomic, strong) UIView *accentView;
@property (nonatomic, assign) BOOL motionRunning;
@end

@implementation PPHeroGlassBackgroundView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self pp_commonInit];
    }
    return self;
}

- (void)pp_commonInit
{
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;

    // Card-level chrome: border, shadow, continuous corners
    // (identical to headerCardView setup in PPUserMenuViewController)
    self.layer.borderWidth = 1.0;
    PPApplyContinuousCorners(self, PPCornerHero - 6.0);
    PPApplyElevatedShadow(self);
    self.layer.shadowOpacity = 0.08f;
    self.layer.shadowRadius = 20.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    // Material container (clipped, receives gradient + constellation + dots)
    UIView *material = [UIView new];
    material.translatesAutoresizingMaskIntoConstraints = NO;
    material.userInteractionEnabled = NO;
    material.clipsToBounds = YES;
    material.backgroundColor = UIColor.clearColor;
    PPApplyContinuousCorners(material, PPCornerHero - 6.0);
    [self addSubview:material];
    self.materialView = material;

    [NSLayoutConstraint activateConstraints:@[
        [material.topAnchor constraintEqualToAnchor:self.topAnchor],
        [material.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [material.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [material.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    // Gradient layer
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.drawsAsynchronously = YES;
    gradient.startPoint = Language.isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    gradient.endPoint = Language.isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
    [material.layer insertSublayer:gradient atIndex:0];
    self.gradientLayer = gradient;

    // Depth layer
    CAGradientLayer *depth = [CAGradientLayer layer];
    depth.drawsAsynchronously = YES;
    depth.startPoint = CGPointMake(0.0, 0.0);
    depth.endPoint = CGPointMake(1.0, 1.0);
    [material.layer insertSublayer:depth above:gradient];
    self.depthLayer = depth;

    // Constellation line layer
    CAShapeLayer *constellation = [CAShapeLayer layer];
    constellation.fillColor = UIColor.clearColor.CGColor;
    constellation.lineWidth = 0.7;
    constellation.lineCap = kCALineCapRound;
    constellation.lineJoin = kCALineJoinRound;
    [material.layer insertSublayer:constellation above:depth];
    self.constellationLayer = constellation;

    // 14 dot layers
    NSMutableArray<CAShapeLayer *> *dotLayers = [NSMutableArray arrayWithCapacity:14];
    for (NSInteger index = 0; index < 14; index++) {
        CAShapeLayer *dot = [CAShapeLayer layer];
        dot.lineWidth = 0.75;
        dot.opacity = 0.0;
        [material.layer insertSublayer:dot above:constellation];
        [dotLayers addObject:dot];
    }
    self.dotLayers = dotLayers.copy;

    // Top accent bar
    UIView *accent = [UIView new];
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    accent.userInteractionEnabled = NO;
    accent.layer.cornerRadius = 2.0;
    accent.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        accent.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:accent];
    self.accentView = accent;

    [NSLayoutConstraint activateConstraints:@[
        [accent.topAnchor constraintEqualToAnchor:self.topAnchor],
        [accent.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:38.0],
        [accent.widthAnchor constraintEqualToConstant:44.0],
        [accent.heightAnchor constraintEqualToConstant:4.0]
    ]];

    // Apply initial palette
    [self reapplyPalette];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (CGRectIsEmpty(self.materialView.bounds)) {
        return;
    }

    CGRect materialBounds = self.materialView.bounds;
    CGFloat materialRadius = self.materialView.layer.cornerRadius;

    self.gradientLayer.frame = materialBounds;
    self.depthLayer.frame = materialBounds;
    self.gradientLayer.cornerRadius = materialRadius;
    self.depthLayer.cornerRadius = materialRadius;

    [self pp_layoutConstellationInBounds:materialBounds];

    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                   cornerRadius:self.layer.cornerRadius].CGPath;

    // Self-healing animation trigger: Auto-start animations once we are on-screen with valid bounds!
    if (self.window && !self.motionRunning) {
        [self startAnimations];
    }
}

#pragma mark - Constellation Layout

- (void)pp_layoutConstellationInBounds:(CGRect)bounds
{
    if (CGRectIsEmpty(bounds) || self.dotLayers.count == 0) {
        return;
    }

    static const CGFloat centers[][2] = {
        {0.090, 0.225}, {0.195, 0.150}, {0.355, 0.245}, {0.535, 0.135},
        {0.815, 0.205}, {0.905, 0.405}, {0.670, 0.405}, {0.445, 0.505},
        {0.150, 0.655}, {0.285, 0.805}, {0.510, 0.735}, {0.705, 0.805},
        {0.885, 0.690}, {0.770, 0.555}
    };
    static const CGFloat sizes[] = {
        2.6, 1.8, 2.2, 1.7, 2.8, 1.9, 2.4, 1.7, 2.1, 2.7, 1.8, 2.2, 1.7, 2.4
    };
    static const NSInteger connections[][2] = {
        {0, 1}, {1, 2}, {3, 4}, {4, 5}, {6, 7}, {8, 9}, {9, 10}, {10, 11}, {11, 12}, {12, 13}
    };

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    UIBezierPath *lines = [UIBezierPath bezierPath];

    NSUInteger dotCount = MIN(self.dotLayers.count, (NSUInteger)(sizeof(sizes) / sizeof(CGFloat)));
    for (NSUInteger index = 0; index < dotCount; index++) {
        CGFloat x = round(width * centers[index][0]);
        CGFloat y = round(height * centers[index][1]);
        CGFloat size = sizes[index];
        CGRect dotRect = CGRectMake(x - (size * 0.5), y - (size * 0.5), size, size);
        CAShapeLayer *dotLayer = self.dotLayers[index];
        dotLayer.frame = bounds;
        dotLayer.path = [UIBezierPath bezierPathWithOvalInRect:dotRect].CGPath;
        dotLayer.opacity = (index % 3 == 0) ? 0.92 : ((index % 3 == 1) ? 0.64 : 0.76);
    }

    NSUInteger connectionCount = (NSUInteger)(sizeof(connections) / sizeof(connections[0]));
    for (NSUInteger index = 0; index < connectionCount; index++) {
        NSInteger fromIndex = connections[index][0];
        NSInteger toIndex = connections[index][1];
        if (fromIndex >= (NSInteger)dotCount || toIndex >= (NSInteger)dotCount) {
            continue;
        }
        CGPoint fromPoint = CGPointMake(round(width * centers[fromIndex][0]), round(height * centers[fromIndex][1]));
        CGPoint toPoint = CGPointMake(round(width * centers[toIndex][0]), round(height * centers[toIndex][1]));
        [lines moveToPoint:fromPoint];
        [lines addLineToPoint:toPoint];
    }

    self.constellationLayer.frame = bounds;
    self.constellationLayer.path = lines.CGPath;
}

#pragma mark - Palette

- (void)reapplyPalette
{
    UIColor *brand = PPHeroGlassAccentColor();
    BOOL darkMode = PPHeroGlassIsDark(self.traitCollection);

    self.backgroundColor = UIColor.clearColor;
    self.materialView.backgroundColor = UIColor.clearColor;
    [self pp_setBorderColor:PPHeroGlassStrokeColor(darkMode)];
    [self pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    self.layer.shadowOpacity = 0.08f;
    self.layer.shadowRadius = 20.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    UIColor *surfaceBase = PPHeroGlassSurfaceBaseColor(self.traitCollection);
    UIColor *surfaceHighlight = PPHeroGlassSurfaceHighlightColor(surfaceBase, darkMode, self.traitCollection);
    UIColor *backgroundAccent = PPHeroGlassBackgroundAccentColor(brand, surfaceBase, darkMode, self.traitCollection);
    UIColor *surfaceTint = PPHeroGlassSurfaceTintColor(surfaceBase, backgroundAccent, darkMode, self.traitCollection);
    UIColor *surfaceTail = PPHeroGlassSurfaceTailColor(surfaceTint, backgroundAccent, darkMode, self.traitCollection);

    self.gradientLayer.opacity = darkMode ? 0.90 : 0.72;
    self.gradientLayer.colors = @[
        (id)PPMarketplaceHeroCardResolvedColor(surfaceHighlight, self.traitCollection).CGColor,
        (id)PPMarketplaceHeroCardResolvedColor(surfaceTint, self.traitCollection).CGColor,
        (id)PPMarketplaceHeroCardResolvedColor(surfaceTail, self.traitCollection).CGColor
    ];
    self.gradientLayer.locations = @[@0.0, @0.56, @1.0];
    self.gradientLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    self.gradientLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);

    self.depthLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.depthLayer.locations = @[@0.0, @1.0];
    self.depthLayer.opacity = 1.0;

    UIColor *dot = PPHeroGlassDotColor();
    UIColor *dotHalo = PPHeroGlassDotHaloColor();
    for (CAShapeLayer *dotLayer in self.dotLayers) {
        dotLayer.fillColor = dot.CGColor;
        dotLayer.strokeColor = dotHalo.CGColor;
    }
    self.constellationLayer.strokeColor = PPHeroGlassConstellationLineColor().CGColor;
    self.constellationLayer.opacity = darkMode ? 0.84 : 0.76;

    self.accentView.backgroundColor = [brand colorWithAlphaComponent:0.58];
}

#pragma mark - Animation Lifecycle

- (void)startAnimations
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self stopAnimations];
        return;
    }

    if (self.motionRunning ||
        !self.window ||
        !self.constellationLayer ||
        CGRectIsEmpty(self.materialView.bounds)) {
        return;
    }

    self.motionRunning = YES;
    [self.constellationLayer removeAllAnimations];
    for (CAShapeLayer *dotLayer in self.dotLayers) {
        [dotLayer removeAllAnimations];
    }

    // Constellation line opacity breathe
    CABasicAnimation *lineOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    lineOpacity.fromValue = @0.28;
    lineOpacity.toValue = @0.84;
    lineOpacity.duration = 6.8;
    lineOpacity.autoreverses = YES;
    lineOpacity.repeatCount = HUGE_VALF;
    lineOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.constellationLayer addAnimation:lineOpacity forKey:PPHeroGlassConstellationOpacityAnimationKey];

    // Dot pulse, drift, and scale
    CFTimeInterval now = CACurrentMediaTime();
    [self.dotLayers enumerateObjectsUsingBlock:^(CAShapeLayer *dotLayer, NSUInteger index, BOOL *stop) {
        CGFloat baseOpacity = dotLayer.opacity;
        CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scale.fromValue = @0.82;
        scale.toValue = @1.34;

        CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacity.fromValue = @(MAX(0.24, baseOpacity * 0.58));
        opacity.toValue = @(MIN(1.0, baseOpacity + 0.16));

        CABasicAnimation *driftY = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        driftY.fromValue = @(((NSInteger)index % 2 == 0) ? -0.7 : 0.5);
        driftY.toValue = @(((NSInteger)index % 2 == 0) ? 0.9 : -0.8);

        CABasicAnimation *driftX = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        driftX.fromValue = @(((NSInteger)index % 3 == 0) ? -0.45 : 0.25);
        driftX.toValue = @(((NSInteger)index % 3 == 0) ? 0.35 : -0.30);

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[scale, opacity, driftY, driftX];
        group.duration = 4.8 + ((index % 5) * 0.42);
        group.beginTime = now + (index * 0.115);
        group.autoreverses = YES;
        group.repeatCount = HUGE_VALF;
        group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        group.removedOnCompletion = YES;
        [dotLayer addAnimation:group forKey:PPHeroGlassDotPulseAnimationKey];
    }];
}

- (void)stopAnimations
{
    self.motionRunning = NO;
    [self.constellationLayer removeAnimationForKey:PPHeroGlassConstellationOpacityAnimationKey];
    for (CAShapeLayer *dotLayer in self.dotLayers) {
        [dotLayer removeAnimationForKey:PPHeroGlassDotPulseAnimationKey];
    }
}

#pragma mark - Window Lifecycle

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    if (!newWindow) {
        [self stopAnimations];
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self startAnimations];
    }
}

#pragma mark - Trait Changes

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self stopAnimations];
    [self reapplyPalette];
    [self startAnimations];
}

@end
