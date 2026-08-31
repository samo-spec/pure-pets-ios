//
//  SplashViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/10/2025.
//

#import "SplashViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "PPBackgroundView.h"
#import "SceneDelegate.h"

@import FirebaseFirestore;

typedef NS_ENUM(NSInteger, PPSplashLoadingPhase) {
    PPSplashLoadingPhaseBootstrapping = 0,
    PPSplashLoadingPhasePreparingContent,
    PPSplashLoadingPhaseReady
};

#pragma mark - Living Mark

/// One optical size owns the approved brand mark. `LaunchScreen.storyboard`
/// pins the identical constant at the identical center offset, so the
/// static-to-live handoff still never scales or moves the identity.
static const CGFloat PPSplashBrandMarkOpticalSide = 92.0;

/// The living carrier is sized by these adaptive sides. Halo, blob silhouette,
/// liquid border, and readiness cradle are all normalized against the value, so
/// one constant scales the entire carrier without disturbing the mark.
static const CGFloat PPSplashCarrierSideRegular = 184.0;
static const CGFloat PPSplashCarrierSideCompact = 176.0;
static const CGFloat PPSplashCarrierSideCompactAccessibility = 172.0;

/// The specular arc rides just inside the liquid border. Shrinking the side of
/// the shared geometry keeps the arc concentric with the morphing silhouette
/// without a layer transform that `settleForSnapshot` would have to restore.
static const CGFloat PPSplashLiquidHighlightInsetRatio = 0.972;

/// The static LaunchScreen hands one immutable identity anchor to UIKit. The
/// approved mark never moves or redraws. UIKit adds a soft organic carrier that
/// gently changes silhouette around the mark, plus three logical readiness
/// strokes beneath it. The identity stays fixed and progress stays truthful.
///
/// The carrier edge is a liquid membrane rather than a flat outline. Three
/// layers share the one morphing silhouette: a soft surface-tension rim, a
/// semantically directional sheen that varies the rim's apparent density, and
/// one specular arc just inside the edge.
@interface PPSplashLivingMarkView : UIView
@property (nonatomic, strong) CAGradientLayer *haloLayer;
@property (nonatomic, strong) CAShapeLayer *blobLayer;
@property (nonatomic, strong) CAShapeLayer *liquidRimLayer;
@property (nonatomic, strong) CAGradientLayer *liquidSheenLayer;
@property (nonatomic, strong) CAShapeLayer *liquidSheenMaskLayer;
@property (nonatomic, strong) CAShapeLayer *liquidHighlightLayer;
@property (nonatomic, strong) NSArray<UIBezierPath *> *blobPaths;
@property (nonatomic, strong) NSArray<UIBezierPath *> *liquidHighlightPaths;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *trackLayers;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *progressLayers;
@property (nonatomic, strong) UIView *logoWrapperView;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, assign) NSInteger activeStepCount;
@property (nonatomic, assign, getter=isReady) BOOL ready;
@property (nonatomic, assign) BOOL usesFallback;
@property (nonatomic, assign) BOOL didPlayEntrance;
- (void)setActiveStepCount:(NSInteger)activeStepCount animated:(BOOL)animated;
- (void)setReady:(BOOL)ready usesFallback:(BOOL)usesFallback animated:(BOOL)animated;
- (void)playEntrance;
- (void)resumeLivingMotionIfAllowed;
- (void)stopMotion;
- (void)settleForSnapshot;
- (void)pp_applyTheme;
- (void)pp_commonInit;
@end

static CGPoint PPSplashLogicalPoint(CGFloat x,
                                    CGFloat y,
                                    CGFloat side,
                                    BOOL rightToLeft)
{
    CGFloat logicalX = rightToLeft ? (1.0 - x) : x;
    return CGPointMake(logicalX * side, y * side);
}

typedef struct {
    CGPoint top;
    CGPoint right;
    CGPoint bottom;
    CGPoint left;
    CGPoint topRightControl1;
    CGPoint topRightControl2;
    CGPoint rightBottomControl1;
    CGPoint rightBottomControl2;
    CGPoint bottomLeftControl1;
    CGPoint bottomLeftControl2;
    CGPoint leftTopControl1;
    CGPoint leftTopControl2;
} PPSplashBlobGeometry;

static CGPoint PPSplashBlobPoint(CGPoint normalizedPoint,
                                 CGPoint center,
                                 CGFloat side)
{
    return CGPointMake(center.x + normalizedPoint.x * side,
                       center.y + normalizedPoint.y * side);
}

static UIBezierPath *PPSplashBlobPath(CGFloat side,
                                      CGPoint center,
                                      PPSplashBlobGeometry geometry)
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:PPSplashBlobPoint(geometry.top, center, side)];
    [path addCurveToPoint:PPSplashBlobPoint(geometry.right, center, side)
            controlPoint1:PPSplashBlobPoint(geometry.topRightControl1, center, side)
            controlPoint2:PPSplashBlobPoint(geometry.topRightControl2, center, side)];
    [path addCurveToPoint:PPSplashBlobPoint(geometry.bottom, center, side)
            controlPoint1:PPSplashBlobPoint(geometry.rightBottomControl1, center, side)
            controlPoint2:PPSplashBlobPoint(geometry.rightBottomControl2, center, side)];
    [path addCurveToPoint:PPSplashBlobPoint(geometry.left, center, side)
            controlPoint1:PPSplashBlobPoint(geometry.bottomLeftControl1, center, side)
            controlPoint2:PPSplashBlobPoint(geometry.bottomLeftControl2, center, side)];
    [path addCurveToPoint:PPSplashBlobPoint(geometry.top, center, side)
            controlPoint1:PPSplashBlobPoint(geometry.leftTopControl1, center, side)
            controlPoint2:PPSplashBlobPoint(geometry.leftTopControl2, center, side)];
    [path closePath];
    return path;
}

@implementation PPSplashLivingMarkView

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
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;

    CAGradientLayer *haloLayer = [CAGradientLayer layer];
    if (@available(iOS 12.0, *)) {
        haloLayer.type = kCAGradientLayerRadial;
    }
    haloLayer.startPoint = CGPointMake(0.5, 0.5);
    haloLayer.endPoint = CGPointMake(1.0, 1.0);
    haloLayer.locations = @[@0.0, @0.46, @1.0];
    haloLayer.opacity = 0.0f;
    [self.layer addSublayer:haloLayer];
    self.haloLayer = haloLayer;

    CAShapeLayer *blobLayer = [CAShapeLayer layer];
    blobLayer.masksToBounds = NO;
    blobLayer.opacity = 0.0f;
    [self.layer addSublayer:blobLayer];
    self.blobLayer = blobLayer;

    // Liquid border, drawn as three cooperating passes over one silhouette.
    // The rim carries surface tension, the masked sheen makes that rim read as
    // a varying-density liquid edge, and the arc adds a single specular
    // reflection. None of them redraw or overlap the approved mark.
    CAShapeLayer *liquidRimLayer = [CAShapeLayer layer];
    liquidRimLayer.fillColor = UIColor.clearColor.CGColor;
    liquidRimLayer.lineJoin = kCALineJoinRound;
    liquidRimLayer.lineCap = kCALineCapRound;
    liquidRimLayer.opacity = 0.0f;
    [self.layer addSublayer:liquidRimLayer];
    self.liquidRimLayer = liquidRimLayer;

    // The mask strokes the same silhouette, so the gradient is only visible
    // along the border band instead of flooding the carrier interior.
    CAShapeLayer *liquidSheenMaskLayer = [CAShapeLayer layer];
    liquidSheenMaskLayer.fillColor = UIColor.clearColor.CGColor;
    liquidSheenMaskLayer.strokeColor = UIColor.blackColor.CGColor;
    liquidSheenMaskLayer.lineJoin = kCALineJoinRound;
    liquidSheenMaskLayer.lineCap = kCALineCapRound;
    self.liquidSheenMaskLayer = liquidSheenMaskLayer;

    CAGradientLayer *liquidSheenLayer = [CAGradientLayer layer];
    liquidSheenLayer.locations = @[@0.0, @0.46, @1.0];
    liquidSheenLayer.opacity = 0.0f;
    liquidSheenLayer.mask = liquidSheenMaskLayer;
    [self.layer addSublayer:liquidSheenLayer];
    self.liquidSheenLayer = liquidSheenLayer;

    CAShapeLayer *liquidHighlightLayer = [CAShapeLayer layer];
    liquidHighlightLayer.fillColor = UIColor.clearColor.CGColor;
    liquidHighlightLayer.lineCap = kCALineCapRound;
    liquidHighlightLayer.opacity = 0.0f;
    [self.layer addSublayer:liquidHighlightLayer];
    self.liquidHighlightLayer = liquidHighlightLayer;

    NSMutableArray<CAShapeLayer *> *trackLayers = [NSMutableArray arrayWithCapacity:3];
    NSMutableArray<CAShapeLayer *> *progressLayers = [NSMutableArray arrayWithCapacity:3];
    for (NSInteger index = 0; index < 3; index++) {
        CAShapeLayer *trackLayer = [CAShapeLayer layer];
        trackLayer.fillColor = UIColor.clearColor.CGColor;
        trackLayer.lineCap = kCALineCapRound;
        trackLayer.opacity = 0.0f;
        [self.layer addSublayer:trackLayer];
        [trackLayers addObject:trackLayer];

        CAShapeLayer *progressLayer = [CAShapeLayer layer];
        progressLayer.fillColor = UIColor.clearColor.CGColor;
        progressLayer.lineCap = kCALineCapRound;
        progressLayer.strokeEnd = 0.0;
        progressLayer.opacity = 0.0f;
        [self.layer addSublayer:progressLayer];
        [progressLayers addObject:progressLayer];
    }
    self.trackLayers = trackLayers.copy;
    self.progressLayers = progressLayers.copy;

    UIImage *brandImage = [[UIImage imageNamed:@"logo-new"]
        imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (!brandImage) {
        brandImage = [[UIImage imageNamed:@"newlogo"]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    UIView *logoWrapperView = [[UIView alloc] init];
    logoWrapperView.backgroundColor = UIColor.clearColor;
    logoWrapperView.userInteractionEnabled = NO;
    logoWrapperView.accessibilityElementsHidden = YES;
    // The static LaunchScreen uses the same optical size and center, so the
    // identity anchor never disappears while UIKit takes ownership.
    logoWrapperView.alpha = 1.0;
    logoWrapperView.transform = CGAffineTransformIdentity;
    [self addSubview:logoWrapperView];
    self.logoWrapperView = logoWrapperView;

    UIImageView *logoImageView = [[UIImageView alloc] initWithImage:brandImage];
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    logoImageView.userInteractionEnabled = NO;
    logoImageView.accessibilityElementsHidden = YES;
    logoImageView.accessibilityIgnoresInvertColors = YES;
    [logoWrapperView addSubview:logoImageView];
    self.logoImageView = logoImageView;

    _activeStepCount = 0;
    [self setActiveStepCount:1 animated:NO];
    [self pp_applyTheme];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    CGFloat originX = CGRectGetMidX(self.bounds) - side * 0.5;
    CGFloat originY = CGRectGetMidY(self.bounds) - side * 0.5;
    CGRect squareBounds = CGRectMake(0.0, 0.0, side, side);
    CGPoint center = CGPointMake(side * 0.5, side * 0.5);
    BOOL rightToLeft =
        self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

    self.haloLayer.frame = CGRectOffset(squareBounds, originX, originY);
    self.haloLayer.cornerRadius = CGRectGetWidth(self.haloLayer.bounds) * 0.5;

    // These silhouettes share the same cubic topology, so Core Animation can
    // interpolate them without scaling or moving the approved logo. Changes
    // stay deliberately small: the carrier feels alive, never gelatinous.
    PPSplashBlobGeometry settledGeometry = {
        {-0.045, -0.350}, {0.355, -0.035}, {0.035, 0.345}, {-0.350, 0.045},
        {0.160, -0.360}, {0.350, -0.230},
        {0.370, 0.170}, {0.230, 0.340},
        {-0.170, 0.360}, {-0.340, 0.230},
        {-0.370, -0.160}, {-0.220, -0.340}
    };
    PPSplashBlobGeometry inhaleGeometry = {
        {0.010, -0.330}, {0.370, 0.015}, {-0.020, 0.360}, {-0.335, -0.015},
        {0.190, -0.335}, {0.360, -0.200},
        {0.380, 0.210}, {0.190, 0.360},
        {-0.190, 0.365}, {-0.340, 0.190},
        {-0.335, -0.180}, {-0.180, -0.340}
    };
    PPSplashBlobGeometry exhaleGeometry = {
        {-0.030, -0.370}, {0.335, -0.055}, {0.055, 0.325}, {-0.370, 0.025},
        {0.160, -0.375}, {0.340, -0.220},
        {0.345, 0.150}, {0.210, 0.315},
        {-0.170, 0.340}, {-0.370, 0.230},
        {-0.380, -0.190}, {-0.230, -0.370}
    };
    BOOL wasMorphing = [self.blobLayer animationForKey:@"pp.blob.breathe"] != nil;
    [self.blobLayer removeAnimationForKey:@"pp.blob.breathe"];
    [self.liquidRimLayer removeAnimationForKey:@"pp.blob.breathe"];
    [self.liquidSheenMaskLayer removeAnimationForKey:@"pp.blob.breathe"];
    [self.liquidHighlightLayer removeAnimationForKey:@"pp.blob.breathe"];
    [self.liquidHighlightLayer removeAnimationForKey:@"pp.liquid.highlight.drift"];
    self.blobPaths = @[
        PPSplashBlobPath(side, center, settledGeometry),
        PPSplashBlobPath(side, center, inhaleGeometry),
        PPSplashBlobPath(side, center, exhaleGeometry)
    ];
    // The specular arc uses the same three silhouettes at a slightly smaller
    // side, so it stays concentric with the rim through the whole morph.
    CGFloat highlightSide = side * PPSplashLiquidHighlightInsetRatio;
    self.liquidHighlightPaths = @[
        PPSplashBlobPath(highlightSide, center, settledGeometry),
        PPSplashBlobPath(highlightSide, center, inhaleGeometry),
        PPSplashBlobPath(highlightSide, center, exhaleGeometry)
    ];

    UIBezierPath *settledPath = self.blobPaths.firstObject;
    self.blobLayer.frame = CGRectMake(originX, originY, side, side);
    self.blobLayer.path = settledPath.CGPath;
    self.blobLayer.shadowPath = nil;
    self.liquidRimLayer.frame = self.blobLayer.frame;
    self.liquidRimLayer.path = settledPath.CGPath;

    self.liquidSheenLayer.frame = self.blobLayer.frame;
    self.liquidSheenMaskLayer.frame = CGRectMake(0.0, 0.0, side, side);
    self.liquidSheenMaskLayer.path = settledPath.CGPath;
    // Light arrives from the semantic leading side, so the liquid edge reads
    // the same way in Arabic and English without mirroring the mark itself.
    self.liquidSheenLayer.startPoint = CGPointMake(rightToLeft ? 0.82 : 0.18, 0.0);
    self.liquidSheenLayer.endPoint = CGPointMake(rightToLeft ? 0.18 : 0.82, 1.0);

    self.liquidHighlightLayer.frame = self.blobLayer.frame;
    self.liquidHighlightLayer.path = self.liquidHighlightPaths.firstObject.CGPath;
    // The silhouette is authored clockwise from its top point, so the upper
    // leading quadrant is the closing segment in LTR and the opening one in RTL.
    self.liquidHighlightLayer.strokeStart = rightToLeft ? 0.035 : 0.775;
    self.liquidHighlightLayer.strokeEnd = rightToLeft ? 0.225 : 0.965;

    // Keep the brand identity aspect-fitted and centered at the exact optical
    // size LaunchScreen pins. The field assembles around the mark; the mark
    // itself never shifts during the static-to-live handoff.
    CGFloat visualMarkSize = PPSplashBrandMarkOpticalSide;
    self.logoWrapperView.frame = CGRectMake(originX + center.x - visualMarkSize * 0.5,
                                            originY + center.y - visualMarkSize * 0.5,
                                            visualMarkSize,
                                            visualMarkSize);
    self.logoImageView.frame = self.logoWrapperView.bounds;

    // Three small strokes form a supportive cradle beneath the mark with breathing vertical space below the center plate.
    // Their logical order mirrors for Arabic while the approved logo never mirrors.
    UIBezierPath *firstPath = [UIBezierPath bezierPath];
    [firstPath moveToPoint:PPSplashLogicalPoint(0.205, 0.865, side, rightToLeft)];
    [firstPath addCurveToPoint:PPSplashLogicalPoint(0.365, 0.910, side, rightToLeft)
                  controlPoint1:PPSplashLogicalPoint(0.255, 0.875, side, rightToLeft)
                  controlPoint2:PPSplashLogicalPoint(0.315, 0.905, side, rightToLeft)];

    UIBezierPath *secondPath = [UIBezierPath bezierPath];
    [secondPath moveToPoint:PPSplashLogicalPoint(0.420, 0.925, side, rightToLeft)];
    [secondPath addCurveToPoint:PPSplashLogicalPoint(0.580, 0.925, side, rightToLeft)
                   controlPoint1:PPSplashLogicalPoint(0.470, 0.940, side, rightToLeft)
                   controlPoint2:PPSplashLogicalPoint(0.530, 0.940, side, rightToLeft)];

    UIBezierPath *thirdPath = [UIBezierPath bezierPath];
    [thirdPath moveToPoint:PPSplashLogicalPoint(0.635, 0.910, side, rightToLeft)];
    [thirdPath addCurveToPoint:PPSplashLogicalPoint(0.795, 0.865, side, rightToLeft)
                  controlPoint1:PPSplashLogicalPoint(0.685, 0.905, side, rightToLeft)
                  controlPoint2:PPSplashLogicalPoint(0.745, 0.875, side, rightToLeft)];
    NSArray<UIBezierPath *> *paths = @[firstPath, secondPath, thirdPath];

    [self.trackLayers enumerateObjectsUsingBlock:^(CAShapeLayer *trackLayer,
                                                    NSUInteger index,
                                                    BOOL *stop) {
        trackLayer.frame = CGRectMake(originX, originY, side, side);
        trackLayer.path = paths[index].CGPath;

        CAShapeLayer *progressLayer = self.progressLayers[index];
        progressLayer.frame = trackLayer.frame;
        progressLayer.path = paths[index].CGPath;

    }];

    if (wasMorphing) {
        [self resumeLivingMotionIfAllowed];
    }
}

- (void)setActiveStepCount:(NSInteger)activeStepCount animated:(BOOL)animated
{
    NSInteger clampedCount = MIN(MAX(activeStepCount, 1), 3);
    NSInteger previousCount = _activeStepCount;
    _activeStepCount = clampedCount;

    BOOL shouldAnimate = animated && self.didPlayEntrance && !UIAccessibilityIsReduceMotionEnabled();
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.progressLayers enumerateObjectsUsingBlock:^(CAShapeLayer *progressLayer,
                                                       NSUInteger index,
                                                       BOOL *stop) {
        CGFloat target = ((NSInteger)index < clampedCount) ? 1.0 : 0.0;
        CGFloat fromValue = progressLayer.presentationLayer
            ? ((CAShapeLayer *)progressLayer.presentationLayer).strokeEnd
            : progressLayer.strokeEnd;
        progressLayer.strokeEnd = target;
        progressLayer.opacity = 1.0f;

        if (shouldAnimate && target > fromValue && (NSInteger)index >= previousCount) {
            CABasicAnimation *draw = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            draw.fromValue = @(fromValue);
            draw.toValue = @(target);
            draw.duration = 0.22;
            draw.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                  :1.0
                                                                                  :0.32
                                                                                  :1.0];
            [progressLayer addAnimation:draw forKey:@"pp.progress.draw"];
        }
    }];
    [CATransaction commit];
    [self pp_applyTheme];
}

- (void)setReady:(BOOL)ready usesFallback:(BOOL)usesFallback animated:(BOOL)animated
{
    BOOL didBecomeReady = !_ready && ready;
    _ready = ready;
    self.usesFallback = usesFallback;
    [self pp_applyTheme];

    if (!didBecomeReady) {
        return;
    }

    CALayer *presentationLayer = self.haloLayer.presentationLayer;
    CGFloat visibleOpacity = presentationLayer ? presentationLayer.opacity : self.haloLayer.opacity;
    [self.haloLayer removeAnimationForKey:@"pp.halo.entrance"];
    [self.haloLayer removeAnimationForKey:@"pp.halo.resolve"];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.haloLayer.opacity = 0.74f;
    [CATransaction commit];

    if (!animated || UIAccessibilityIsReduceMotionEnabled() || visibleOpacity >= 0.735) {
        return;
    }

    CABasicAnimation *resolveOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    resolveOpacity.fromValue = @(visibleOpacity);
    resolveOpacity.toValue = @0.74;
    resolveOpacity.duration = 0.20;
    resolveOpacity.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                     :1.0
                                                                                     :0.32
                                                                                     :1.0];
    [self.haloLayer addAnimation:resolveOpacity forKey:@"pp.halo.resolve"];
}

- (void)playEntrance
{
    if (self.didPlayEntrance) {
        return;
    }
    self.didPlayEntrance = YES;
    [self layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.haloLayer.opacity = self.isReady ? 0.74f : 0.56f;
        self.blobLayer.opacity = 1.0f;
        self.liquidRimLayer.opacity = 1.0f;
        self.liquidSheenLayer.opacity = 1.0f;
        self.liquidHighlightLayer.opacity = 1.0f;
        self.logoWrapperView.alpha = 1.0;
        self.logoWrapperView.transform = CGAffineTransformIdentity;
        for (CAShapeLayer *trackLayer in self.trackLayers) {
            trackLayer.opacity = 1.0f;
        }
        for (CAShapeLayer *progressLayer in self.progressLayers) {
            progressLayer.opacity = 1.0f;
        }
        return;
    }

    self.haloLayer.opacity = self.isReady ? 0.74f : 0.56f;
    CABasicAnimation *haloOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    haloOpacity.fromValue = @0.0;
    haloOpacity.toValue = @(self.haloLayer.opacity);
    haloOpacity.duration = 0.22;
    haloOpacity.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                  :1.0
                                                                                  :0.32
                                                                                  :1.0];
    [self.haloLayer addAnimation:haloOpacity forKey:@"pp.halo.entrance"];

    // Re-read the system setting before the remaining authored phases so a
    // setting change at the launch boundary settles every owned layer.
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self settleForSnapshot];
        return;
    }

    CFTimeInterval now = CACurrentMediaTime();

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.blobLayer.opacity = 1.0f;
    self.liquidRimLayer.opacity = 1.0f;
    self.liquidSheenLayer.opacity = 1.0f;
    self.liquidHighlightLayer.opacity = 1.0f;
    [CATransaction commit];
    CABasicAnimation *blobOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    blobOpacity.fromValue = @0.0;
    blobOpacity.toValue = @1.0;
    blobOpacity.duration = 0.20;
    blobOpacity.fillMode = kCAFillModeBackwards;
    blobOpacity.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                :1.0
                                                                                :0.32
                                                                                :1.0];
    [self.blobLayer addAnimation:blobOpacity forKey:@"pp.blob.entrance"];
    [self.liquidRimLayer addAnimation:blobOpacity forKey:@"pp.liquid.rim.entrance"];
    [self.liquidSheenLayer addAnimation:blobOpacity forKey:@"pp.liquid.sheen.entrance"];
    [self.liquidHighlightLayer addAnimation:blobOpacity forKey:@"pp.liquid.highlight.entrance"];

    [self.trackLayers enumerateObjectsUsingBlock:^(CAShapeLayer *trackLayer,
                                                    NSUInteger index,
                                                    BOOL *stop) {
        if (UIAccessibilityIsReduceMotionEnabled()) {
            trackLayer.opacity = 1.0f;
            self.progressLayers[index].opacity = 1.0f;
            return;
        }

        trackLayer.opacity = 1.0f;
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fade.fromValue = @0.0;
        fade.toValue = @1.0;
        fade.beginTime = now + 0.025 + (CFTimeInterval)index * 0.02;
        fade.duration = 0.16;
        fade.fillMode = kCAFillModeBackwards;
        fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [trackLayer addAnimation:fade forKey:@"pp.track.entrance"];

        CAShapeLayer *progressLayer = self.progressLayers[index];
        progressLayer.opacity = 1.0f;
        if ((NSInteger)index < self.activeStepCount) {
            CABasicAnimation *draw = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            draw.fromValue = @0.0;
            draw.toValue = @(progressLayer.strokeEnd);
            draw.beginTime = now + 0.04 + (CFTimeInterval)index * 0.02;
            draw.duration = 0.22;
            draw.fillMode = kCAFillModeBackwards;
            draw.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                  :1.0
                                                                                  :0.32
                                                                                  :1.0];
            [progressLayer addAnimation:draw forKey:@"pp.progress.entrance"];
        }
    }];

    [self resumeLivingMotionIfAllowed];
}

- (void)resumeLivingMotionIfAllowed
{
    if (!self.didPlayEntrance || UIAccessibilityIsReduceMotionEnabled() || !self.window ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
        self.blobPaths.count < 3 || self.liquidHighlightPaths.count < 3 ||
        [self.blobLayer animationForKey:@"pp.blob.breathe"]) {
        return;
    }

    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    if (processInfo.isLowPowerModeEnabled) {
        return;
    }
    if (@available(iOS 11.0, *)) {
        if (processInfo.thermalState >= NSProcessInfoThermalStateSerious) {
            return;
        }
    }

    CFTimeInterval breatheBeginTime = CACurrentMediaTime() + 0.04;
    // Every liquid layer shares one authored cadence, so the fill, rim, sheen
    // band, and specular arc deform as a single membrane instead of drifting
    // out of phase with each other.
    CAKeyframeAnimation *(^morphAnimation)(NSArray<UIBezierPath *> *) =
        ^CAKeyframeAnimation *(NSArray<UIBezierPath *> *paths) {
            NSMutableArray *pathValues = [NSMutableArray arrayWithCapacity:paths.count + 1];
            for (UIBezierPath *path in paths) {
                [pathValues addObject:(__bridge id)path.CGPath];
            }
            [pathValues addObject:(__bridge id)paths.firstObject.CGPath];

            CAKeyframeAnimation *breathe = [CAKeyframeAnimation animationWithKeyPath:@"path"];
            breathe.values = pathValues.copy;
            breathe.keyTimes = @[@0.0, @0.34, @0.68, @1.0];
            breathe.timingFunctions = @[
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
            ];
            breathe.duration = 3.2;
            // Two finite breaths cover the six-second launch timeout without
            // leaving an ambient loop alive if navigation is delayed by the OS.
            breathe.repeatCount = 1.0f;
            breathe.beginTime = breatheBeginTime;
            breathe.fillMode = kCAFillModeBackwards;
            breathe.removedOnCompletion = YES;
            return breathe;
        };

    CAKeyframeAnimation *breathe = morphAnimation(self.blobPaths);
    [self.blobLayer addAnimation:breathe forKey:@"pp.blob.breathe"];
    [self.liquidRimLayer addAnimation:breathe forKey:@"pp.blob.breathe"];
    [self.liquidSheenMaskLayer addAnimation:breathe forKey:@"pp.blob.breathe"];
    [self.liquidHighlightLayer addAnimation:morphAnimation(self.liquidHighlightPaths)
                                     forKey:@"pp.blob.breathe"];

    // The reflection slides a short distance along the same edge, the way light
    // travels across a moving liquid surface. It is finite and never restarts on
    // its own, so the launch surface still owns no ambient timeline.
    CGFloat highlightStart = self.liquidHighlightLayer.strokeStart;
    CGFloat highlightEnd = self.liquidHighlightLayer.strokeEnd;
    CAKeyframeAnimation *drift = [CAKeyframeAnimation animationWithKeyPath:@"strokeStart"];
    drift.values = @[@(highlightStart), @(highlightStart + 0.028), @(highlightStart)];
    drift.keyTimes = @[@0.0, @0.5, @1.0];
    drift.duration = 3.2;
    drift.repeatCount = 1.0f;
    drift.beginTime = breatheBeginTime;
    drift.fillMode = kCAFillModeBackwards;
    drift.removedOnCompletion = YES;
    drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.liquidHighlightLayer addAnimation:drift forKey:@"pp.liquid.highlight.drift"];

    CAKeyframeAnimation *driftEnd = [drift copy];
    driftEnd.keyPath = @"strokeEnd";
    driftEnd.values = @[@(highlightEnd), @(highlightEnd + 0.020), @(highlightEnd)];
    [self.liquidHighlightLayer addAnimation:driftEnd forKey:@"pp.liquid.highlight.drift.end"];
}

- (void)stopMotion
{
    [self.haloLayer removeAllAnimations];
    [self.blobLayer removeAllAnimations];
    [self.liquidRimLayer removeAllAnimations];
    [self.liquidSheenLayer removeAllAnimations];
    [self.liquidSheenMaskLayer removeAllAnimations];
    [self.liquidHighlightLayer removeAllAnimations];
    for (CAShapeLayer *layer in self.trackLayers) {
        [layer removeAllAnimations];
    }
    for (CAShapeLayer *layer in self.progressLayers) {
        [layer removeAllAnimations];
    }
}

- (void)settleForSnapshot
{
    [self stopMotion];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.haloLayer.opacity = self.isReady ? 0.74f : 0.56f;
    self.haloLayer.transform = CATransform3DIdentity;
    UIBezierPath *settledPath = self.blobPaths.firstObject;
    self.blobLayer.opacity = 1.0f;
    self.blobLayer.transform = CATransform3DIdentity;
    self.blobLayer.path = settledPath.CGPath;
    self.liquidRimLayer.opacity = 1.0f;
    self.liquidRimLayer.transform = CATransform3DIdentity;
    self.liquidRimLayer.path = settledPath.CGPath;
    self.liquidSheenLayer.opacity = 1.0f;
    self.liquidSheenLayer.transform = CATransform3DIdentity;
    self.liquidSheenMaskLayer.path = settledPath.CGPath;
    self.liquidHighlightLayer.opacity = 1.0f;
    self.liquidHighlightLayer.transform = CATransform3DIdentity;
    self.liquidHighlightLayer.path = self.liquidHighlightPaths.firstObject.CGPath;
    self.logoWrapperView.alpha = 1.0;
    self.logoWrapperView.transform = CGAffineTransformIdentity;
    [self.trackLayers enumerateObjectsUsingBlock:^(CAShapeLayer *trackLayer,
                                                    NSUInteger index,
                                                    BOOL *stop) {
        trackLayer.opacity = 1.0f;
        CAShapeLayer *progressLayer = self.progressLayers[index];
        progressLayer.opacity = 1.0f;
        progressLayer.strokeEnd = ((NSInteger)index < self.activeStepCount) ? 1.0 : 0.0;
    }];
    [CATransaction commit];
    [self pp_applyTheme];
}

- (void)pp_applyTheme
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL usesIncreasedContrast =
        self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;
    UIColor *brandColor = [[UIColor ppPrimary]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *secondaryColor = [[UIColor ppTextSecondary]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *surfaceColor = [[UIColor ppSurface]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *softRoseColor = [[UIColor ppSoftRose]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *premiumColor = [[UIColor ppPremiumAccent]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *progressColor = self.usesFallback
        ? [[UIColor ppCareAccent] resolvedColorWithTraitCollection:self.traitCollection]
        : brandColor;
    UIColor *appForegroundColor = [UIColor colorNamed:@"AppForegroundColor"] ?:
        AppForgroundColr ?: [UIColor whiteColor];
    UIColor *plateColor = [appForegroundColor colorWithAlphaComponent:0.7];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    CGFloat centerAlpha = usesIncreasedContrast
        ? (isDark ? 0.22 : 0.16)
        : (isDark ? 0.16 : 0.10);
    self.haloLayer.colors = @[
        (id)[brandColor colorWithAlphaComponent:centerAlpha].CGColor,
        (id)[brandColor colorWithAlphaComponent:centerAlpha * 0.36].CGColor,
        (id)UIColor.clearColor.CGColor
    ];

    self.blobLayer.fillColor = plateColor.CGColor;
    self.blobLayer.shadowOpacity = 0.0f;

    // Liquid border using appforground color with 0.7 alpha and 0.75 width
    CGFloat rimWidth = 0.75;
    self.liquidRimLayer.strokeColor = plateColor.CGColor;
    self.liquidRimLayer.lineWidth = rimWidth;

    // A slightly wider mask lets the sheen soften the rim's outer boundary
    self.liquidSheenMaskLayer.lineWidth = rimWidth + 0.3;
    self.liquidSheenLayer.colors = @[
        (id)plateColor.CGColor,
        (id)UIColor.clearColor.CGColor,
        (id)plateColor.CGColor
    ];

    self.liquidHighlightLayer.strokeColor = plateColor.CGColor;
    self.liquidHighlightLayer.lineWidth = 0.75;

    UIColor *trackColor = [secondaryColor colorWithAlphaComponent:
        usesIncreasedContrast ? (isDark ? 0.68 : 0.82) : (isDark ? 0.34 : 0.28)];
    CGFloat trackWidth = usesIncreasedContrast ? 3.0 : 2.25;
    CGFloat progressWidth = usesIncreasedContrast ? 5.5 : 4.5;
    for (CAShapeLayer *trackLayer in self.trackLayers) {
        trackLayer.strokeColor = trackColor.CGColor;
        trackLayer.lineWidth = trackWidth;
    }
    [self.progressLayers enumerateObjectsUsingBlock:^(CAShapeLayer *progressLayer,
                                                       NSUInteger index,
                                                       BOOL *stop) {
        UIColor *segmentColor = index == 2 && self.isReady && !self.usesFallback
            ? premiumColor
            : progressColor;
        progressLayer.strokeColor = segmentColor.CGColor;
        progressLayer.lineWidth = progressWidth;
    }];
    [CATransaction commit];
}

@end

#pragma mark - Splash Controller

@interface SplashViewController ()
@property (nonatomic, assign) BOOL didShowMainVC;
@property (nonatomic, assign) BOOL didStartInitialDataLoad;
@property (nonatomic, assign) BOOL didLoadMainKinds;
@property (nonatomic, assign) BOOL didUseFallbackLaunch;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL viewIsVisible;
@property (nonatomic, assign) CGSize lastAdaptiveLayoutSize;
@property (nonatomic, assign) PPSplashLoadingPhase currentLoadingPhase;
@property (nonatomic, copy, nullable) NSString *currentLoadingDetail;
@property (nonatomic, strong, nullable) NSDate *launchBeganAt;
@property (nonatomic, copy, nullable) dispatch_block_t launchTimeoutBlock;
@property (nonatomic, strong) PPBackgroundView *ambientBackgroundView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) PPSplashLivingMarkView *livingMarkView;
@property (nonatomic, strong) NSLayoutConstraint *livingMarkWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *livingMarkHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *livingMarkCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *identityBottomConstraint;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *statusGroupView;
@property (nonatomic, strong) UIStackView *statusTextStackView;
@property (nonatomic, strong) NSLayoutConstraint *statusTopConstraint;
@property (nonatomic, strong) UILabel *loadingTitleLabel;
@property (nonatomic, strong) UILabel *loadingStatusLabel;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong, nullable) id<UIViewAnimating> contentEntranceAnimator;
@property (nonatomic, strong, nullable) id<UIViewAnimating> statusEntranceAnimator;
@property (nonatomic, strong, nullable) id<UIViewAnimating> statusTextAnimator;
- (void)pp_buildSplashInterface;
- (void)pp_applySplashTheme;
- (void)pp_applySplashCopy;
- (void)pp_applyContentSizeLayout;
- (void)pp_beginSplashAnimationsIfNeeded;
- (void)pp_startSplashAtmosphereMotion;
- (void)pp_stopSplashAtmosphereMotion;
- (void)pp_refreshLoadingProgressPresentation;
- (void)pp_updateLoadingPhase:(PPSplashLoadingPhase)phase detail:(NSString *)detail;
- (void)pp_scheduleLaunchTimeout;
- (void)pp_cancelLaunchTimeout;
- (void)pp_completeLaunchIfNeededForced:(BOOL)forced;
- (void)pp_prepareSplashForSnapshot;
- (void)pp_reduceMotionStatusDidChange:(NSNotification *)notification;
- (void)pp_processEnvironmentDidChange:(NSNotification *)notification;
- (void)pp_applicationDidEnterBackground:(NSNotification *)notification;
- (void)pp_applicationDidBecomeActive:(NSNotification *)notification;
- (nullable UIWindow *)pp_transitionWindow;
- (void)pp_swapRootViewController:(UIViewController *)rootViewController
                          onWindow:(UIWindow *)window;
@end

@implementation SplashViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"[Splash] viewDidLoad ✅");

    [self pp_buildSplashInterface];
    [self pp_applySplashTheme];
    [self pp_applySplashCopy];
    [self pp_updateLoadingPhase:PPSplashLoadingPhaseBootstrapping detail:self.currentLoadingDetail];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_reduceMotionStatusDidChange:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_processEnvironmentDidChange:)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
    if (@available(iOS 11.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_processEnvironmentDidChange:)
                                                     name:NSProcessInfoThermalStateDidChangeNotification
                                                   object:nil];
    }

    [PPHUD dismiss];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    BOOL colorAppearanceChanged = !previousTraitCollection ||
        [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
    BOOL contrastChanged = previousTraitCollection &&
        self.traitCollection.accessibilityContrast != previousTraitCollection.accessibilityContrast;
    if (colorAppearanceChanged || contrastChanged) {
        [self pp_applySplashTheme];
    }
    if (!previousTraitCollection ||
        ![self.traitCollection.preferredContentSizeCategory
            isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self pp_applyContentSizeLayout];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (!CGSizeEqualToSize(self.lastAdaptiveLayoutSize, self.view.bounds.size)) {
        self.lastAdaptiveLayoutSize = self.view.bounds.size;
        [self pp_applyContentSizeLayout];
    }
}

- (void)pp_reduceMotionStatusDidChange:(NSNotification *)notification
{
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        if (self.viewIsVisible && !self.didShowMainVC) {
            [self.livingMarkView resumeLivingMotionIfAllowed];
        }
        return;
    }

    [self.contentEntranceAnimator stopAnimation:YES];
    [self.statusEntranceAnimator stopAnimation:YES];
    [self.statusTextAnimator stopAnimation:YES];
    self.contentEntranceAnimator = nil;
    self.statusEntranceAnimator = nil;
    self.statusTextAnimator = nil;

    [self pp_stopSplashAtmosphereMotion];
    [self.livingMarkView settleForSnapshot];
    self.ambientBackgroundView.alpha = 1.0;
    self.brandLabel.alpha = 1.0;
    self.brandLabel.transform = CGAffineTransformIdentity;
    self.subtitleLabel.alpha = 1.0;
    self.subtitleLabel.transform = CGAffineTransformIdentity;
    self.statusGroupView.alpha = 1.0;
    self.statusGroupView.transform = CGAffineTransformIdentity;
    self.loadingTitleLabel.alpha = 1.0;
    self.loadingStatusLabel.alpha = 1.0;
    self.footerLabel.alpha = 1.0;
}

- (void)pp_applicationDidEnterBackground:(NSNotification *)notification
{
    if (!self.viewIsVisible) {
        return;
    }

    [self pp_stopSplashAtmosphereMotion];
    [self.livingMarkView settleForSnapshot];
    [self.contentEntranceAnimator stopAnimation:YES];
    [self.statusEntranceAnimator stopAnimation:YES];
    [self.statusTextAnimator stopAnimation:YES];
    self.contentEntranceAnimator = nil;
    self.statusEntranceAnimator = nil;
    self.statusTextAnimator = nil;
}

- (void)pp_processEnvironmentDidChange:(NSNotification *)notification
{
    if (!self.viewIsVisible || self.didShowMainVC) {
        return;
    }

    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    BOOL underThermalPressure = NO;
    if (@available(iOS 11.0, *)) {
        underThermalPressure = processInfo.thermalState >= NSProcessInfoThermalStateSerious;
    }
    if (processInfo.isLowPowerModeEnabled || underThermalPressure) {
        [self.livingMarkView settleForSnapshot];
    } else {
        [self.livingMarkView resumeLivingMotionIfAllowed];
    }
}

- (void)pp_applicationDidBecomeActive:(NSNotification *)notification
{
    if (!self.viewIsVisible || self.didShowMainVC) {
        return;
    }

    [self pp_startSplashAtmosphereMotion];
    [self.livingMarkView settleForSnapshot];
    [self.livingMarkView resumeLivingMotionIfAllowed];
}

#pragma mark - Interface

- (void)pp_buildSplashInterface
{
    // SceneDelegate installs this controller programmatically, but clearing the
    // container keeps the composition deterministic if the controller is ever
    // reintroduced through an archived scene.
    for (UIView *legacySubview in self.view.subviews.copy) {
        [legacySubview removeFromSuperview];
    }

    UIColor *launchCanvasColor = [UIColor colorNamed:@"AppForegroundColor"] ?:
        AppForgroundColr ?: UIColor.systemBackgroundColor;
    self.view.backgroundColor = launchCanvasColor;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.view.clipsToBounds = YES;

    PPBackgroundView *ambientBackgroundView = [[PPBackgroundView alloc] init];
    ambientBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    ambientBackgroundView.userInteractionEnabled = NO;
    ambientBackgroundView.PPHeroApexUseShimmer = NO;
    ambientBackgroundView.PPHeroApexUseUnderFingerMotion = NO;
    ambientBackgroundView.overrideBorders = YES;
    ambientBackgroundView.overrideBorderColor = UIColor.clearColor;
    // The bridge treats values <= 0.5 as "unset" and falls back to a 30pt
    // card radius. A sub-point explicit value keeps the full-screen field square.
    ambientBackgroundView.overrideCornerRadius = 0.51;
    ambientBackgroundView.accentStyle = PPHeroGlassAccentStyleBBBaseBackground;
    ambientBackgroundView.accentColorOverride = [UIColor ppSoftRose];
    ambientBackgroundView.overrideSurfaceColor = [UIColor ppElevatedSurface];
    // Begin on the exact solid LaunchScreen canvas. The authored atmosphere
    // arrives only after UIKit owns the frame, avoiding a launch-boundary flash.
    ambientBackgroundView.alpha = 0.0;
    [self.view addSubview:ambientBackgroundView];
    self.ambientBackgroundView = ambientBackgroundView;

    UIStackView *contentStackView = [[UIStackView alloc] init];
    contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    contentStackView.axis = UILayoutConstraintAxisVertical;
    contentStackView.alignment = UIStackViewAlignmentFill;
    contentStackView.distribution = UIStackViewDistributionFill;
    contentStackView.spacing = PPSpaceXS;
    contentStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:contentStackView];
    self.contentStackView = contentStackView;

    PPSplashLivingMarkView *livingMarkView = [[PPSplashLivingMarkView alloc] init];
    livingMarkView.translatesAutoresizingMaskIntoConstraints = NO;
    livingMarkView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.livingMarkWidthConstraint =
        [livingMarkView.widthAnchor constraintEqualToConstant:PPSplashCarrierSideRegular];
    self.livingMarkHeightConstraint =
        [livingMarkView.heightAnchor constraintEqualToConstant:PPSplashCarrierSideRegular];
    self.livingMarkWidthConstraint.active = YES;
    self.livingMarkHeightConstraint.active = YES;
    [self.view addSubview:livingMarkView];
    self.livingMarkView = livingMarkView;

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    brandLabel.textAlignment = NSTextAlignmentCenter;
    brandLabel.numberOfLines = 2;
    UIFont *brandBaseFont = [GM boldFontWithSize:PPFontTitle1] ?:
        [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    brandLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle1]
        scaledFontForFont:brandBaseFont
        maximumPointSize:40.0];
    brandLabel.adjustsFontForContentSizeCategory = YES;
    brandLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    brandLabel.alpha = 0.0;
    [contentStackView addArrangedSubview:brandLabel];
    self.brandLabel = brandLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    UIFont *subtitleBaseFont = [GM MidFontWithSize:PPFontSubheadline] ?:
        [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:subtitleBaseFont
        maximumPointSize:24.0];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleLabel.alpha = 0.0;
    [contentStackView addArrangedSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UIView *statusGroupView = [[UIView alloc] init];
    statusGroupView.translatesAutoresizingMaskIntoConstraints = NO;
    statusGroupView.backgroundColor = UIColor.clearColor;
    statusGroupView.isAccessibilityElement = YES;
    statusGroupView.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    statusGroupView.alpha = 0.0;
    [self.view addSubview:statusGroupView];
    self.statusGroupView = statusGroupView;

    UIStackView *statusTextStack = [[UIStackView alloc] init];
    statusTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    statusTextStack.axis = UILayoutConstraintAxisVertical;
    statusTextStack.alignment = UIStackViewAlignmentFill;
    statusTextStack.distribution = UIStackViewDistributionFill;
    statusTextStack.spacing = PPSpaceXS;
    statusTextStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [statusGroupView addSubview:statusTextStack];
    self.statusTextStackView = statusTextStack;

    UILabel *loadingTitleLabel = [[UILabel alloc] init];
    loadingTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *loadingTitleBaseFont = [GM boldFontWithSize:PPFontHeadline] ?:
        [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    loadingTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:loadingTitleBaseFont
        maximumPointSize:30.0];
    loadingTitleLabel.adjustsFontForContentSizeCategory = YES;
    loadingTitleLabel.textAlignment = NSTextAlignmentCenter;
    loadingTitleLabel.numberOfLines = 0;
    loadingTitleLabel.isAccessibilityElement = NO;
    [statusTextStack addArrangedSubview:loadingTitleLabel];
    self.loadingTitleLabel = loadingTitleLabel;

    UILabel *loadingStatusLabel = [[UILabel alloc] init];
    loadingStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *loadingStatusBaseFont = [GM MidFontWithSize:PPFontSubheadline] ?:
        [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    loadingStatusLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:loadingStatusBaseFont
        maximumPointSize:24.0];
    loadingStatusLabel.adjustsFontForContentSizeCategory = YES;
    loadingStatusLabel.textAlignment = NSTextAlignmentCenter;
    loadingStatusLabel.numberOfLines = 0;
    loadingStatusLabel.isAccessibilityElement = NO;
    [statusTextStack addArrangedSubview:loadingStatusLabel];
    self.loadingStatusLabel = loadingStatusLabel;

    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 2;
    UIFont *footerBaseFont = [GM MidFontWithSize:PPFontCaption2] ?:
        [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    footerLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption2]
        scaledFontForFont:footerBaseFont
        maximumPointSize:16.0];
    footerLabel.adjustsFontForContentSizeCategory = YES;
    footerLabel.alpha = 0.0;
    footerLabel.accessibilityElementsHidden = YES;
    [self.view addSubview:footerLabel];
    self.footerLabel = footerLabel;

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *contentFluidWidth =
        [contentStackView.widthAnchor constraintEqualToAnchor:safeArea.widthAnchor constant:-64.0];
    contentFluidWidth.priority = UILayoutPriorityRequired - 1.0;
    NSLayoutConstraint *contentMaximumWidth =
        [contentStackView.widthAnchor constraintLessThanOrEqualToConstant:340.0];
    self.identityBottomConstraint =
        [contentStackView.bottomAnchor constraintEqualToAnchor:livingMarkView.topAnchor
                                                       constant:-PPSpaceMD];
    self.identityBottomConstraint.priority = UILayoutPriorityRequired - 1.0;

    // Match the static LaunchScreen's exact logo anchor. Collision constraints
    // may override this preference only when accessibility content cannot fit.
    self.livingMarkCenterYConstraint =
        [livingMarkView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor
                                                     constant:-110.0];
    self.livingMarkCenterYConstraint.priority = UILayoutPriorityDefaultHigh;

    NSLayoutConstraint *statusFluidWidth =
        [statusGroupView.widthAnchor constraintEqualToAnchor:safeArea.widthAnchor constant:-72.0];
    statusFluidWidth.priority = UILayoutPriorityRequired - 1.0;
    NSLayoutConstraint *statusMaximumWidth =
        [statusGroupView.widthAnchor constraintLessThanOrEqualToConstant:340.0];
    self.statusTopConstraint =
        [statusGroupView.topAnchor constraintEqualToAnchor:livingMarkView.bottomAnchor
                                                   constant:PPSpaceSM];
    self.statusTopConstraint.priority = UILayoutPriorityRequired - 1.0;

    [NSLayoutConstraint activateConstraints:@[
        [ambientBackgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [ambientBackgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [ambientBackgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [ambientBackgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [contentStackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [contentStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor
                                                                    constant:PPSpaceXL],
        [contentStackView.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor
                                                                   constant:-PPSpaceXL],
        contentFluidWidth,
        contentMaximumWidth,
        [contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:safeArea.topAnchor
                                                                 constant:PPSpaceBase],
        self.identityBottomConstraint,

        [livingMarkView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        self.livingMarkCenterYConstraint,

        [statusGroupView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [statusGroupView.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor
                                                                    constant:PPSpaceXL],
        [statusGroupView.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor
                                                                   constant:-PPSpaceXL],
        self.statusTopConstraint,
        [statusGroupView.bottomAnchor constraintLessThanOrEqualToAnchor:footerLabel.topAnchor
                                                                 constant:-PPSpaceLG],
        statusFluidWidth,
        statusMaximumWidth,

        [statusTextStack.leadingAnchor constraintEqualToAnchor:statusGroupView.leadingAnchor],
        [statusTextStack.trailingAnchor constraintEqualToAnchor:statusGroupView.trailingAnchor],
        [statusTextStack.topAnchor constraintEqualToAnchor:statusGroupView.topAnchor],
        [statusTextStack.bottomAnchor constraintEqualToAnchor:statusGroupView.bottomAnchor],

        [footerLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:PPSpaceXL],
        [footerLabel.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-PPSpaceXL],
        [footerLabel.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-PPSpaceMD]
    ]];

    self.view.accessibilityElements = @[brandLabel, subtitleLabel, statusGroupView];
    [self pp_applyContentSizeLayout];
}

- (void)pp_applySplashTheme
{
    UIColor *canvasColor = [UIColor colorNamed:@"AppForegroundColor"] ?:
        AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *titleColor = [[UIColor ppTextPrimary]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *secondaryTextColor = [[UIColor ppTextSecondary]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *primaryColor = [[UIColor ppPrimary]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *elevatedSurface = [[UIColor ppElevatedSurface]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *homeSoftRose = [[UIColor ppSoftRose]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *identityMist = [PPColorUtils blendColor:homeSoftRose
                                           withColor:primaryColor
                                              factor:0.16];

    self.view.backgroundColor = canvasColor;
    self.ambientBackgroundView.accentColorOverride = identityMist;
    self.ambientBackgroundView.overrideSurfaceColor = elevatedSurface;
    [self.ambientBackgroundView reapplyPalette];
    [self.livingMarkView pp_applyTheme];

    self.brandLabel.textColor = titleColor;
    self.subtitleLabel.textColor = secondaryTextColor;
    self.loadingTitleLabel.textColor = titleColor;
    self.loadingStatusLabel.textColor = secondaryTextColor;
    self.footerLabel.textColor = [secondaryTextColor colorWithAlphaComponent:0.78];
}

- (void)pp_applySplashCopy
{
    NSInteger currentYear = [[NSCalendar currentCalendar] component:NSCalendarUnitYear
                                                            fromDate:[NSDate date]];

    self.brandLabel.text = kLang(@"AppName");
    self.subtitleLabel.text = kLang(@"splash_product_promise");
    self.loadingTitleLabel.text = kLang(@"splash_loading_title");
    self.footerLabel.text = [NSString localizedStringWithFormat:kLang(@"splash_footer_format"),
                                                             (long)currentYear];
    self.currentLoadingDetail = kLang(@"splash_loading_boot");
}

- (void)pp_applyContentSizeLayout
{
    BOOL usesAccessibilitySizes =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
    BOOL usesCompactHeight = viewHeight > 0.0 && viewHeight < 720.0;
    CGFloat markDimension = usesCompactHeight ? PPSplashCarrierSideCompact
                                              : PPSplashCarrierSideRegular;
    if (usesAccessibilitySizes && usesCompactHeight) {
        markDimension = PPSplashCarrierSideCompactAccessibility;
    }
    self.livingMarkWidthConstraint.constant = markDimension;
    self.livingMarkHeightConstraint.constant = markDimension;
    self.identityBottomConstraint.constant = usesCompactHeight ? -PPSpaceSM : -PPSpaceMD;
    self.statusTopConstraint.constant = usesCompactHeight ? PPSpaceXS : PPSpaceSM;
    self.brandLabel.numberOfLines = 2;
    self.footerLabel.numberOfLines = usesAccessibilitySizes ? 2 : 1;
    self.contentStackView.spacing = usesAccessibilitySizes ? PPSpaceXXS : PPSpaceXS;
    self.statusTextStackView.spacing = usesAccessibilitySizes ? PPSpaceXXS : PPSpaceXS;
}

#pragma mark - Motion and Progress

- (void)pp_startSplashAtmosphereMotion
{
    // PPBackgroundView can own an infinite ambient timeline. Launch opts out:
    // the field is a static token-driven atmosphere and all visible motion is
    // finite, causal, and owned by the readiness signature below.
    [self.ambientBackgroundView stopAnimations];
    self.ambientBackgroundView.transform = CGAffineTransformIdentity;
}

- (void)pp_stopSplashAtmosphereMotion
{
    [self.ambientBackgroundView stopAnimations];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ambientBackgroundView.layer.transform = CATransform3DIdentity;
    [CATransaction commit];
}

- (void)pp_beginSplashAnimationsIfNeeded
{
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    [self.livingMarkView playEntrance];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.ambientBackgroundView.alpha = 1.0;
        self.brandLabel.alpha = 1.0;
        self.subtitleLabel.alpha = 1.0;
        self.statusGroupView.alpha = 1.0;
        self.footerLabel.alpha = 1.0;
        return;
    }

    __weak typeof(self) weakSelf = self;
    UICubicTimingParameters *entranceTiming =
        [[UICubicTimingParameters alloc] initWithControlPoint1:CGPointMake(0.23, 1.0)
                                                 controlPoint2:CGPointMake(0.32, 1.0)];
    UIViewPropertyAnimator *copyAnimator =
        [[UIViewPropertyAnimator alloc] initWithDuration:0.22
                                        timingParameters:entranceTiming];
    [copyAnimator addAnimations:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.ambientBackgroundView.alpha = 1.0;
        self.brandLabel.alpha = 1.0;
        self.subtitleLabel.alpha = 1.0;
    }];
    self.contentEntranceAnimator = copyAnimator;
    [copyAnimator startAnimationAfterDelay:0.02];

    UIViewPropertyAnimator *statusAnimator =
        [[UIViewPropertyAnimator alloc] initWithDuration:0.18
                                        timingParameters:entranceTiming];
    [statusAnimator addAnimations:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.statusGroupView.alpha = 1.0;
        self.footerLabel.alpha = 1.0;
    }];
    self.statusEntranceAnimator = statusAnimator;
    [statusAnimator startAnimationAfterDelay:0.04];
}

- (void)pp_refreshLoadingProgressPresentation
{
    // A late manager callback must not overwrite the timeout/fallback state
    // that will be captured by the root-handoff snapshot.
    if (self.didShowMainVC) {
        return;
    }

    PPSplashLoadingPhase phase = PPSplashLoadingPhaseBootstrapping;
    NSString *detail = nil;

    if (!self.didStartInitialDataLoad) {
        phase = PPSplashLoadingPhaseBootstrapping;
        detail = kLang(@"splash_loading_boot");
    } else if (!self.didLoadMainKinds) {
        phase = PPSplashLoadingPhasePreparingContent;
        detail = kLang(@"splash_loading_categories");
    } else {
        phase = PPSplashLoadingPhaseReady;
        detail = kLang(@"splash_loading_ready");
    }

    [self pp_updateLoadingPhase:phase detail:detail];
}

- (void)pp_updateLoadingPhase:(PPSplashLoadingPhase)phase detail:(NSString *)detail
{
    PPSplashLoadingPhase previousPhase = self.currentLoadingPhase;
    self.currentLoadingPhase = phase;
    self.currentLoadingDetail = detail ?: self.currentLoadingDetail;

    BOOL isReady = phase == PPSplashLoadingPhaseReady;
    NSString *titleKey = @"splash_loading_title";
    if (isReady) {
        titleKey = self.didUseFallbackLaunch ? @"splash_continue_title" : @"splash_ready_title";
    }

    NSString *title = kLang(titleKey) ?: @"";
    NSString *safeDetail = self.currentLoadingDetail ?: @"";
    NSString *previousTitle = self.loadingTitleLabel.text ?: @"";
    NSString *previousDetail = self.loadingStatusLabel.text ?: @"";
    BOOL didCopyChange =
        ![previousTitle isEqualToString:title] ||
        ![previousDetail isEqualToString:safeDetail];

    CALayer *titlePresentation = self.loadingTitleLabel.layer.presentationLayer;
    CALayer *detailPresentation = self.loadingStatusLabel.layer.presentationLayer;
    CGFloat visibleTitleOpacity = titlePresentation
        ? titlePresentation.opacity
        : self.loadingTitleLabel.alpha;
    CGFloat visibleDetailOpacity = detailPresentation
        ? detailPresentation.opacity
        : self.loadingStatusLabel.alpha;
    [self.statusTextAnimator stopAnimation:YES];
    self.statusTextAnimator = nil;
    self.loadingTitleLabel.text = title;
    self.loadingStatusLabel.text = safeDetail;

    if (didCopyChange && self.view.window && !UIAccessibilityIsReduceMotionEnabled()) {
        // Continue from any in-flight presentation value. For a fresh update,
        // use only a quiet opacity delta so clustered cache callbacks cannot flash.
        self.loadingTitleLabel.alpha = MIN(visibleTitleOpacity, 0.88);
        self.loadingStatusLabel.alpha = MIN(visibleDetailOpacity, 0.82);

        __weak typeof(self) weakSelf = self;
        UICubicTimingParameters *statusTiming =
            [[UICubicTimingParameters alloc] initWithControlPoint1:CGPointMake(0.23, 1.0)
                                                     controlPoint2:CGPointMake(0.32, 1.0)];
        UIViewPropertyAnimator *textAnimator =
            [[UIViewPropertyAnimator alloc] initWithDuration:0.20
                                            timingParameters:statusTiming];
        [textAnimator addAnimations:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.loadingTitleLabel.alpha = 1.0;
            self.loadingStatusLabel.alpha = 1.0;
        }];
        self.statusTextAnimator = textAnimator;
        [textAnimator startAnimation];
    } else {
        self.loadingTitleLabel.alpha = 1.0;
        self.loadingStatusLabel.alpha = 1.0;
    }

    // The three visible steps map one-to-one to the controller's actual state:
    // UIKit bootstrap, content preparation, and a terminal ready/fallback handoff.
    NSInteger activeSteps = MIN(MAX((NSInteger)phase + 1, 1), 3);

    BOOL shouldAnimate = self.view.window != nil && self.didAnimateEntrance;
    [self.livingMarkView setActiveStepCount:activeSteps animated:shouldAnimate];
    [self.livingMarkView setReady:isReady
                    usesFallback:self.didUseFallbackLaunch
                         animated:shouldAnimate && previousPhase != phase];
    [self pp_applySplashTheme];

    self.statusGroupView.accessibilityLabel =
        [NSString localizedStringWithFormat:kLang(@"splash_loading_accessibility_format"),
                                             title,
                                             safeDetail];
    self.statusGroupView.accessibilityValue =
        [NSString localizedStringWithFormat:kLang(@"splash_progress_accessibility_format"),
                                             (long)activeSteps,
                                             3L];
}

#pragma mark - Launch Timeout

- (void)pp_scheduleLaunchTimeout
{
    [self pp_cancelLaunchTimeout];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.didShowMainVC) {
            return;
        }

        NSLog(@"[Splash] ⏱ Launch timeout reached. Proceeding with available data.");
        [self pp_completeLaunchIfNeededForced:YES];
    });

    self.launchTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);
}

- (void)pp_cancelLaunchTimeout
{
    if (!self.launchTimeoutBlock) {
        return;
    }

    dispatch_block_cancel(self.launchTimeoutBlock);
    self.launchTimeoutBlock = nil;
}
/*
 self.CardID = d[@"CardID"];
 self.UserID = d[@"UserID"];
 self.CageID = d[@"CageID"];
 */

- (void)normalizeArchivesIsDeleted
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚀 Starting ArchiveCol isDeleted normalization");

    [[db collectionWithPath:@"ArchiveCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed to fetch ArchiveCol: %@", error);
            return;
        }

        NSArray<FIRDocumentSnapshot *> *docs = snapshot.documents;
        if (docs.count == 0) {
            NSLog(@"ℹ️ No archive documents found");
            return;
        }

        const NSInteger batchLimit = 450; // safe margin
        NSInteger totalUpdated = 0;

        for (NSInteger i = 0; i < docs.count; i += batchLimit) {

            FIRWriteBatch *batch = [db batch];
            NSRange range = NSMakeRange(i, MIN(batchLimit, docs.count - i));
            NSArray *chunk = [docs subarrayWithRange:range];

            for (FIRDocumentSnapshot *doc in chunk) {

                NSNumber *isDeleted = doc.data[@"isDeleted"];

                // Skip if already correct
                if ([isDeleted isKindOfClass:NSNumber.class] &&
                    isDeleted.integerValue == 0) {
                    continue;
                }

                FIRDocumentReference *ref =
                [[db collectionWithPath:@"ArchiveCol"]
                 documentWithPath:doc.documentID];

                [batch setData:@{ @"isDeleted": @0 }
                    forDocument:ref
                          merge:YES];

                totalUpdated++;
            }

            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ Batch commit failed: %@", error);
                } else {
                    NSLog(@"✅ Batch committed (%lu docs)",
                          (unsigned long)chunk.count);
                }
            }];
        }

        NSLog(@"🎯 ArchiveCol normalization completed. Updated: %ld",
              (long)totalUpdated);
    }];
}


- (void)migrateChildsArrayToSubcollectionOnce
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚀 Starting ChildsArray → ChildsCol migration");

    [[db collectionWithPath:@"CagesCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed fetching cages: %@", error);
            return;
        }

        for (FIRDocumentSnapshot *cageDoc in snapshot.documents) {

            NSDictionary *cageData = cageDoc.data;
            NSArray *childsArray = cageData[@"ChildsArray"];

            if (![childsArray isKindOfClass:[NSArray class]] ||
                childsArray.count == 0) {
                continue;
            }

            FIRWriteBatch *batch = [db batch];
            NSInteger migratedCount = 0;

            for (NSDictionary *childDict in childsArray) {

                if (![childDict isKindOfClass:[NSDictionary class]]) continue;

                NSString *childID =
                childDict[@"ID"] ?: [[NSUUID UUID] UUIDString];

                FIRDocumentReference *childRef =
                [[[[db collectionWithPath:@"CagesCol"]
                   documentWithPath:cageDoc.documentID]
                  collectionWithPath:@"ChildsCol"]
                 documentWithPath:childID];

                NSMutableDictionary *safeData = [NSMutableDictionary dictionary];

                // Required
                safeData[@"ID"] = childID;
                safeData[@"CageID"] = childDict[@"CageID"] ?: cageDoc.documentID;
                safeData[@"CardID"] = childDict[@"CardID"] ?: @"";
                safeData[@"ChildRingID"] = childDict[@"ChildRingID"] ?: @"";
                safeData[@"UserID"] = cageData[@"UserID"] ?: @"";

                // Dates
                safeData[@"addingDate"] =
                childDict[@"addingDate"] ?: [NSDate date];

                safeData[@"lastUpdated"] =
                childDict[@"lastUpdated"] ?: [NSDate date];

                // Status
                safeData[@"isDeleted"] =
                childDict[@"isDeleted"] ?: @0;

                safeData[@"isSold"] =
                childDict[@"isSold"] ?: @0;

                // Archive (normalize)
                NSString *archiveID = childDict[@"archiveID"];
                safeData[@"archiveID"] =
                archiveID.length ? archiveID : @"";

                NSString *masterArchiveID = childDict[@"masterArchiveID"];
                safeData[@"masterArchiveID"] =
                masterArchiveID.length ? masterArchiveID : @"";

                // Movement defaults
                safeData[@"childBox"] =
                childDict[@"childBox"] ?: @(0);

                safeData[@"childBoxID"] =
                childDict[@"childBoxID"] ?: @"";

                safeData[@"cameFrom"] =
                childDict[@"cameFrom"] ?: @(0);

                // UPSERT (merge)
                [batch setData:safeData
                    forDocument:childRef
                          merge:YES];

                migratedCount++;
            }

            // Update childsCount ONLY from migrated data
            FIRDocumentReference *cageRef =
            [[db collectionWithPath:@"CagesCol"]
             documentWithPath:cageDoc.documentID];

            [batch updateData:@{
                @"childsCount": @(migratedCount)
            } forDocument:cageRef];

            // COMMIT PER CAGE
            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ Migration failed for cage %@: %@",
                          cageDoc.documentID, error);
                } else {
                    NSLog(@"✅ Cage %@ migrated (%ld childs)",
                          cageDoc.documentID, (long)migratedCount);
                }
            }];
        }
    }];
}


- (void)migrateArchiveDetails_Safe_NoDelete
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚨 STARTING SAFE ARCHIVE DETAILS MIGRATION (NO DELETE)");

    [[db collectionWithPath:@"ArchiveCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed to fetch ArchiveCol: %@", error);
            return;
        }

        for (FIRDocumentSnapshot *archiveDoc in snapshot.documents)
        {
            NSDictionary *data = archiveDoc.data ?: @{};
            NSArray *oldDetails = data[@"archiveDetails"];

            if (![oldDetails isKindOfClass:[NSArray class]] || oldDetails.count == 0) {
                continue; // nothing to migrate
            }

            NSString *archiveID = archiveDoc.documentID;
            NSLog(@"🔄 Migrating archive (SAFE) %@", archiveID);

            FIRWriteBatch *batch = [db batch];
            NSInteger migratedCount = 0;

            for (NSDictionary *oldDetail in oldDetails)
            {
                if (![oldDetail isKindOfClass:[NSDictionary class]]) continue;

                NSString *detailID =
                oldDetail[@"ID"] ?: [NSUUID UUID].UUIDString;

                FIRDocumentReference *detailRef =
                [[archiveDoc.reference
                  collectionWithPath:@"ArchiveDetailsCol"]
                 documentWithPath:detailID];

                NSMutableDictionary *newDetail = [NSMutableDictionary dictionary];

                // ========= REQUIRED =========
                newDetail[@"ID"] = detailID;
                newDetail[@"masterArchiveID"] = archiveID;

                // ========= SAFE COPY =========
                if (oldDetail[@"CardID"])
                    newDetail[@"CardID"] = oldDetail[@"CardID"];

                if (oldDetail[@"UserID"])
                    newDetail[@"UserID"] = oldDetail[@"UserID"];

                if (oldDetail[@"CageID"])
                    newDetail[@"CageID"] = oldDetail[@"CageID"];

                // ========= FLAGS =========
                newDetail[@"CardInfo"] =
                oldDetail[@"CardInfo"] ?: @0;

                newDetail[@"isDeleted"] =
                oldDetail[@"isDeleted"] ?: @0;

                newDetail[@"isSold"] =
                oldDetail[@"isSold"] ?: @0;

                // ========= DATES =========
                NSDate *cardArchiveDate = nil;

                id oldDate = oldDetail[@"cardArchiveDate"];
                if ([oldDate isKindOfClass:[NSDate class]]) {
                    cardArchiveDate = oldDate;
                } else if ([oldDate isKindOfClass:[FIRTimestamp class]]) {
                    cardArchiveDate = [(FIRTimestamp *)oldDate dateValue];
                } else if ([data[@"archiveDate"] isKindOfClass:[NSDate class]]) {
                    cardArchiveDate = data[@"archiveDate"];
                } else {
                    cardArchiveDate = [NSDate date];
                }

                newDetail[@"cardArchiveDate"] =
                [FIRTimestamp timestampWithDate:cardArchiveDate];

                // lastUpdated — only add if missing
                newDetail[@"lastUpdated"] =
                [FIRTimestamp timestampWithDate:[NSDate date]];

                // ========= MERGE (CRITICAL) =========
                [batch setData:newDetail
                     forDocument:detailRef
                         merge:YES];

                migratedCount++;
            }

            // ========= UPDATE METADATA (NO DELETE) =========
            [batch updateData:@{
                @"detailsCount": @(migratedCount),
                @"lastUpdated": [FIRTimestamp timestampWithDate:[NSDate date]]
            } forDocument:archiveDoc.reference];

            // ========= COMMIT =========
            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ SAFE MIGRATION FAILED for %@: %@",
                          archiveID, error);
                } else {
                    NSLog(@"✅ SAFE MIGRATION DONE for %@ (%ld details)",
                          archiveID, (long)migratedCount);
                }
            }];
        }

        NSLog(@"🚨 SAFE MIGRATION LOOP FINISHED");
    }];
}

- (void)duplicateUserDocToCustomID {
    /*
    NSString *targetUID = @"wFiEt8lUWCQkcJE1K4DBHmUMZaD2";
    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *usersCol = [db collectionWithPath:@"UsersCol"];

    // 1️⃣ Find the existing document where uid == targetUID
    FIRQuery *query = [usersCol queryWhereField:@"uid" isEqualTo:targetUID];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Error fetching documents: %@", error.localizedDescription);
            return;
        }

        if (snapshot.documents.count == 0) {
            NSLog(@"⚠️ No document found for uid %@", targetUID);
            return;
        }

        NSLog(@"✅ Found %lu document(s) to duplicate", (unsigned long)snapshot.documents.count);

        // 2️⃣ Take the first document (assuming UID is unique)
        FIRDocumentSnapshot *sourceDoc = snapshot.documents.firstObject;
        NSDictionary *data = sourceDoc.data;

        // 3️⃣ Add or update a new document with custom ID = targetUID
        FIRDocumentReference *newDocRef = [usersCol documentWithPath:targetUID];
        [newDocRef setData:data completion:^(NSError * _Nullable err) {
            if (err) {
                NSLog(@"❌ Failed to create new document: %@", err.localizedDescription);
            } else {
                NSLog(@"Successfully created new document with ID %@", targetUID);
            }
        }];
    }]; */
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.viewIsVisible = NO;
    [self pp_stopSplashAtmosphereMotion];
    [self.livingMarkView stopMotion];
    [self.contentEntranceAnimator stopAnimation:YES];
    [self.statusEntranceAnimator stopAnimation:YES];
    [self.statusTextAnimator stopAnimation:YES];
    [self pp_cancelLaunchTimeout];
    [PPHUD dismiss];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self pp_stopSplashAtmosphereMotion];
    [self.livingMarkView stopMotion];
    [self.contentEntranceAnimator stopAnimation:YES];
    [self.statusEntranceAnimator stopAnimation:YES];
    [self.statusTextAnimator stopAnimation:YES];
    [self pp_cancelLaunchTimeout];
    [PPHUD dismiss];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"[Splash] viewDidAppear - start data loading");

    self.viewIsVisible = YES;
    [self pp_startSplashAtmosphereMotion];
    [self pp_beginSplashAnimationsIfNeeded];
    [self startInitialDataLoad];
}

#pragma mark - 🔹 Data Loading Sequence

- (void)startInitialDataLoad
{
    if (self.didShowMainVC || self.didStartInitialDataLoad) {
        NSLog(@"[Splash] ⚠️ Launch work already started, skipping duplicate request.");
        return;
    }

    self.didStartInitialDataLoad = YES;
    self.didLoadMainKinds = NO;
    // Home offers are owned by the authenticated Campaign Action Rail V2
    // projection and load after session restoration. They are intentionally
    // outside the Splash completion model.
    self.launchBeganAt = [NSDate date];
    [self pp_scheduleLaunchTimeout];
    [self pp_refreshLoadingProgressPresentation];

    dispatch_group_t group = dispatch_group_create();

    __block BOOL didLeaveKindsGroup = NO;
    dispatch_group_enter(group);
    [PPMainKindsManager loadMainDataCompletionHandler:^(int result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (didLeaveKindsGroup) {
                return;
            }
            didLeaveKindsGroup = YES;

            BOOL didSucceed = result != 0;
            NSLog(@"[Splash] %@ MainKinds terminal callback (result = %d)",
                  didSucceed ? @"✅" : @"⚠️",
                  result);
            self.didLoadMainKinds = didSucceed;
            [self pp_refreshLoadingProgressPresentation];
            dispatch_group_leave(group);
        });
    }];

    NSLog(@"[Splash] ℹ️ Home offers deferred to Campaign Action Rail V2 after session restoration.");

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"[Splash] 🎬 Startup callback terminal (MainKinds=%@, HomeOffers=deferred)",
              self.didLoadMainKinds ? @"✅" : @"❌");

        // Preserve the navigation contract: the terminal category callback
        // still fails open, while authenticated Home offers load after handoff.
        [self pp_completeLaunchIfNeededForced:NO];
    });
}

- (void)pp_completeLaunchIfNeededForced:(BOOL)forced
{
    if (self.didShowMainVC) {
        return;
    }

    self.didShowMainVC = YES;
    BOOL didCompleteAllLaunchData = self.didLoadMainKinds;
    self.didUseFallbackLaunch = forced || !didCompleteAllLaunchData;
    [self pp_cancelLaunchTimeout];

    NSString *completionKey = self.didUseFallbackLaunch
        ? @"splash_loading_fallback"
        : @"splash_loading_ready";
    NSString *completionDetail = kLang(completionKey);
    [self pp_updateLoadingPhase:PPSplashLoadingPhaseReady detail:completionDetail];

    NSTimeInterval elapsed = self.launchBeganAt ? [[NSDate date] timeIntervalSinceDate:self.launchBeganAt] : 0.0;
    NSTimeInterval remainingDelay = MAX(0.0, 2.5 - elapsed);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remainingDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self transitionToMainApp];
    });
}

- (void)pp_prepareSplashForSnapshot
{
    [self.contentEntranceAnimator stopAnimation:YES];
    [self.statusEntranceAnimator stopAnimation:YES];
    [self.statusTextAnimator stopAnimation:YES];
    self.contentEntranceAnimator = nil;
    self.statusEntranceAnimator = nil;
    self.statusTextAnimator = nil;
    [self pp_stopSplashAtmosphereMotion];
    [self.livingMarkView settleForSnapshot];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ambientBackgroundView.alpha = 1.0;
    self.brandLabel.alpha = 1.0;
    self.brandLabel.transform = CGAffineTransformIdentity;
    self.subtitleLabel.alpha = 1.0;
    self.subtitleLabel.transform = CGAffineTransformIdentity;
    self.statusGroupView.alpha = 1.0;
    self.statusGroupView.transform = CGAffineTransformIdentity;
    self.loadingTitleLabel.alpha = 1.0;
    self.loadingStatusLabel.alpha = 1.0;
    self.footerLabel.alpha = 1.0;
    [self.view layoutIfNeeded];
    [CATransaction commit];

    // Only cancel layers owned by this splash. Avoid recursively stripping
    // animations from UIKit/private sublayers during the root handoff.
    NSArray<CALayer *> *ownedLayers = @[
        self.ambientBackgroundView.layer,
        self.brandLabel.layer,
        self.subtitleLabel.layer,
        self.statusGroupView.layer,
        self.loadingTitleLabel.layer,
        self.loadingStatusLabel.layer,
        self.footerLabel.layer
    ];
    for (CALayer *layer in ownedLayers) {
        [layer removeAllAnimations];
    }
}

#pragma mark - 🔹 Transition to Main App

- (void)transitionToMainApp
{
    NSLog(@"[Splash] 🚀 Transitioning to main AppVC");
    [[NSUserDefaults standardUserDefaults] setInteger:LastBootOneUI forKey:@"lastBoot"];

    PPRootTabBarController *rootVC = [[PPRootTabBarController alloc] init];
    rootVC.view.semanticContentAttribute = GM.setSemantic;

    UIWindow *window = [self pp_transitionWindow];
    if (!window) {
        NSLog(@"[Splash] ❌ Failed to locate the active window for root transition");
        self.didShowMainVC = NO;
        return;
    }

    // Resolve any in-flight entrance/progress motion before taking the window-level
    // cover. Home may hold this snapshot while its first presentation is prepared.
    [self pp_prepareSplashForSnapshot];

    // Capture a static snapshot of the splash interface to overlay on the window.
    // This snapshot covers the screen seamlessly during the Home screen's remote
    // config and initial data bootstrap process, preventing any visual stacking.
    UIView *coverView = [self.view snapshotViewAfterScreenUpdates:YES];
    if (!coverView) {
        coverView = [[UIView alloc] initWithFrame:window.bounds];
        coverView.backgroundColor = self.view.backgroundColor;
    } else {
        coverView.frame = window.bounds;
    }
    coverView.tag = 99182;
    coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    coverView.opaque = YES;
    coverView.userInteractionEnabled = YES;
    coverView.isAccessibilityElement = YES;
    coverView.accessibilityViewIsModal = YES;
    coverView.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    coverView.accessibilityLabel = self.statusGroupView.accessibilityLabel ?:
        kLang(@"splash_loading_title");
    coverView.accessibilityValue = self.statusGroupView.accessibilityValue;
    coverView.backgroundColor = coverView.backgroundColor ?: self.view.backgroundColor ?: window.backgroundColor ?: UIColor.systemBackgroundColor;

    [self pp_swapRootViewController:rootVC onWindow:window];
    id sceneDelegate = window.windowScene.delegate;
    if ([sceneDelegate isKindOfClass:SceneDelegate.class]) {
        [(SceneDelegate *)sceneDelegate notificationRoutingRootDidBecomeReady];
    }
    coverView.frame = window.bounds;
    [[window viewWithTag:99182] removeFromSuperview];
    [window addSubview:coverView];
    [window bringSubviewToFront:coverView];
}

- (nullable UIWindow *)pp_transitionWindow
{
    UIWindow *window = self.view.window;
    if (window) {
        return window;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive &&
                windowScene.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }

            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.isKeyWindow) {
                    return candidate;
                }
            }

            if (windowScene.windows.firstObject) {
                return windowScene.windows.firstObject;
            }
        }
    }

    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow) {
            return candidate;
        }
    }

    UIWindow *fallback = UIApplication.sharedApplication.windows.firstObject;
    if (!fallback) {
        NSLog(@"❌ SplashVC: no UIWindow available");
    }
    return fallback;
}

- (void)pp_swapRootViewController:(UIViewController *)rootViewController
                         onWindow:(UIWindow *)window
{
    window.semanticContentAttribute = GM.setSemantic;

    // Swap root view controller instantly without transitions to avoid cross-dissolving
    // while Home is in an unbootstrapped/empty state.
    BOOL previousAnimationState = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    window.rootViewController = rootViewController;
    [window makeKeyAndVisible];
    [window layoutIfNeeded];
    [UIView setAnimationsEnabled:previousAnimationState];
}

@end
