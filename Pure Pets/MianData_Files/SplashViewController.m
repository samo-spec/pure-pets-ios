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
    PPSplashLoadingPhaseFinalizing,
    PPSplashLoadingPhaseReady
};

static NSString * const PPSplashAtmosphereDriftAnimationKey =
    @"pp.splash.atmosphere.drift";

#pragma mark - Living Mark

/// The launch progress is carried by the Pure Pets mark itself. Three quiet
/// contours map to the three visible launch phases and resolve around the logo,
/// keeping progress honest without introducing a second, generic loading UI.
@interface PPSplashLivingMarkView : UIView
@property (nonatomic, strong) CAGradientLayer *haloLayer;
@property (nonatomic, strong) CALayer *pedestalLayer;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *trackLayers;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *progressLayers;
@property (nonatomic, strong) UIView *logoWrapperView;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) CALayer *markSheenContainerLayer;
@property (nonatomic, strong) CAGradientLayer *markSheenLayer;
@property (nonatomic, strong) CALayer *markSheenMaskLayer;
@property (nonatomic, assign) NSInteger activeStepCount;
@property (nonatomic, assign, getter=isReady) BOOL ready;
@property (nonatomic, assign) BOOL usesFallback;
@property (nonatomic, assign) BOOL didPlayEntrance;
- (void)setActiveStepCount:(NSInteger)activeStepCount animated:(BOOL)animated;
- (void)setReady:(BOOL)ready usesFallback:(BOOL)usesFallback animated:(BOOL)animated;
- (void)playEntrance;
- (void)stopMotion;
- (void)settleForSnapshot;
- (void)pp_applyTheme;
- (void)pp_commonInit;
@end

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

    // A quiet, borderless raised surface separates the identity from the
    // atmospheric field. It remains inset from the progress contour so the
    // loading state stays crisp and visually independent.
    CALayer *pedestalLayer = [CALayer layer];
    pedestalLayer.borderWidth = 0.0;
    pedestalLayer.masksToBounds = NO;
    pedestalLayer.opacity = 0.0f;
    [self.layer addSublayer:pedestalLayer];
    self.pedestalLayer = pedestalLayer;

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

    UIImage *brandImage = [[UIImage imageNamed:@"logoImag"]
        imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (!brandImage) {
        brandImage = [[UIImage imageNamed:@"PurePetsMark"]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    if (!brandImage) {
        brandImage = [[UIImage imageNamed:@"PureIconTransFilledV3"]
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
    [logoWrapperView addSubview:logoImageView];
    self.logoImageView = logoImageView;

    CAGradientLayer *markSheenLayer = [CAGradientLayer layer];
    markSheenLayer.startPoint = CGPointMake(0.0, 0.5);
    markSheenLayer.endPoint = CGPointMake(1.0, 0.5);
    markSheenLayer.locations = @[@0.42, @0.50, @0.58];
    markSheenLayer.opacity = 0.0f;
    CALayer *markSheenContainerLayer = [CALayer layer];
    CALayer *markSheenMaskLayer = [CALayer layer];
    markSheenMaskLayer.contents = (__bridge id)brandImage.CGImage;
    markSheenMaskLayer.contentsGravity = kCAGravityResizeAspect;
    markSheenContainerLayer.mask = markSheenMaskLayer;
    [markSheenContainerLayer addSublayer:markSheenLayer];
    [logoWrapperView.layer addSublayer:markSheenContainerLayer];
    self.markSheenContainerLayer = markSheenContainerLayer;
    self.markSheenLayer = markSheenLayer;
    self.markSheenMaskLayer = markSheenMaskLayer;

    _activeStepCount = 0;
    [self setActiveStepCount:1 animated:NO];
    [self pp_applyTheme];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    self.haloLayer.frame = CGRectInset(self.bounds, -side * 0.08, -side * 0.08);
    self.haloLayer.cornerRadius = CGRectGetWidth(self.haloLayer.bounds) * 0.5;

    // Keep the raised surface comfortably inside the contour's inner edge.
    // At the default 232pt mark field this creates a ~153pt pedestal with a
    // 12–13pt optical inset from the widest progress stroke.
    CGFloat pedestalDiameter = side * 0.66;
    self.pedestalLayer.frame = CGRectMake(center.x - pedestalDiameter * 0.5,
                                          center.y - pedestalDiameter * 0.5,
                                          pedestalDiameter,
                                          pedestalDiameter);
    self.pedestalLayer.cornerRadius = pedestalDiameter * 0.5;
    self.pedestalLayer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:self.pedestalLayer.bounds].CGPath;

    // The PurePetsMark vector identity is 1:1 square, perfectly centered,
    // and matches the LaunchScreen optical size (112.5pt at 232pt side).
    CGFloat visualMarkSize = side * 0.485;
    self.logoWrapperView.frame = CGRectMake(center.x - visualMarkSize * 0.5,
                                            center.y - visualMarkSize * 0.5,
                                            visualMarkSize,
                                            visualMarkSize);
    self.logoImageView.frame = self.logoWrapperView.bounds;
    self.markSheenContainerLayer.frame = self.logoWrapperView.bounds;
    self.markSheenLayer.frame = CGRectMake(-CGRectGetWidth(self.logoWrapperView.bounds),
                                           0.0,
                                           CGRectGetWidth(self.logoWrapperView.bounds) * 3.0,
                                           CGRectGetHeight(self.logoWrapperView.bounds));
    self.markSheenMaskLayer.frame = self.logoWrapperView.bounds;

    CGFloat radius = side * 0.385;
    CGFloat gap = (CGFloat)(M_PI * 14.0 / 180.0);
    CGFloat segmentSpan = ((CGFloat)(M_PI * 2.0) - gap * 3.0) / 3.0;
    CGFloat firstStart = (CGFloat)-M_PI_2;
    [self.trackLayers enumerateObjectsUsingBlock:^(CAShapeLayer *trackLayer,
                                                    NSUInteger index,
                                                    BOOL *stop) {
        CGFloat start = firstStart + (segmentSpan + gap) * (CGFloat)index;
        CGFloat end = start + segmentSpan;
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center
                                                            radius:radius
                                                        startAngle:start
                                                          endAngle:end
                                                         clockwise:YES];
        trackLayer.frame = self.bounds;
        trackLayer.path = path.CGPath;

        CAShapeLayer *progressLayer = self.progressLayers[index];
        progressLayer.frame = self.bounds;
        progressLayer.path = path.CGPath;
    }];
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
            draw.duration = 0.42;
            draw.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                  :1.0
                                                                                  :0.32
                                                                                  :1.0];
            [progressLayer addAnimation:draw forKey:@"pp.progress.draw"];
        }
    }];
    [CATransaction commit];

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
    CATransform3D visibleTransform = presentationLayer
        ? presentationLayer.transform
        : self.haloLayer.transform;
    [self.haloLayer removeAnimationForKey:@"pp.halo.entrance"];
    [self.haloLayer removeAnimationForKey:@"pp.halo.resolve"];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.haloLayer.opacity = 1.0f;
    self.haloLayer.transform = CATransform3DIdentity;
    [CATransaction commit];

    BOOL needsResolution = visibleOpacity < 0.995 ||
        !CATransform3DEqualToTransform(visibleTransform, CATransform3DIdentity);
    if (!animated || UIAccessibilityIsReduceMotionEnabled() || !needsResolution) {
        return;
    }

    CABasicAnimation *resolveOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    resolveOpacity.fromValue = @(visibleOpacity);
    resolveOpacity.toValue = @1.0;
    CABasicAnimation *resolveTransform = [CABasicAnimation animationWithKeyPath:@"transform"];
    resolveTransform.fromValue = [NSValue valueWithCATransform3D:visibleTransform];
    resolveTransform.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    CAAnimationGroup *resolve = [CAAnimationGroup animation];
    resolve.animations = @[resolveOpacity, resolveTransform];
    resolve.duration = 0.28;
    resolve.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                              :1.0
                                                                              :0.32
                                                                              :1.0];
    [self.haloLayer addAnimation:resolve forKey:@"pp.halo.resolve"];

}

- (void)playEntrance
{
    if (self.didPlayEntrance) {
        return;
    }
    self.didPlayEntrance = YES;
    [self layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.haloLayer.opacity = 1.0f;
        self.pedestalLayer.opacity = 1.0f;
        self.pedestalLayer.transform = CATransform3DIdentity;
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

    self.haloLayer.opacity = 1.0f;
    CAAnimationGroup *haloReveal = [CAAnimationGroup animation];
    CABasicAnimation *haloOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    haloOpacity.fromValue = @0.0;
    haloOpacity.toValue = @1.0;
    CABasicAnimation *haloScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    haloScale.fromValue = @0.94;
    haloScale.toValue = @1.0;
    haloReveal.animations = @[haloOpacity, haloScale];
    haloReveal.duration = 0.62;
    haloReveal.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                               :1.0
                                                                               :0.32
                                                                               :1.0];
    [self.haloLayer addAnimation:haloReveal forKey:@"pp.halo.entrance"];

    CFTimeInterval now = CACurrentMediaTime();

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.pedestalLayer.opacity = 1.0f;
    self.pedestalLayer.transform = CATransform3DIdentity;
    [CATransaction commit];
    CABasicAnimation *pedestalReveal = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pedestalReveal.fromValue = @0.0;
    pedestalReveal.toValue = @1.0;
    pedestalReveal.beginTime = now + 0.04;
    pedestalReveal.duration = 0.48;
    pedestalReveal.fillMode = kCAFillModeBackwards;
    pedestalReveal.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                   :1.0
                                                                                   :0.32
                                                                                   :1.0];
    [self.pedestalLayer addAnimation:pedestalReveal forKey:@"pp.pedestal.entrance"];

    self.logoWrapperView.transform = CGAffineTransformMakeScale(0.86, 0.86);
    self.logoWrapperView.alpha = 0.0;
    __weak typeof(self) weakLivingMark = self;
    [UIView animateWithDuration:0.66
                          delay:0.04
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        weakLivingMark.logoWrapperView.alpha = 1.0;
        weakLivingMark.logoWrapperView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (finished && !UIAccessibilityIsReduceMotionEnabled()) {
            [weakLivingMark pp_startMarkBreathingLoop];
        }
    }];

    CAKeyframeAnimation *sheenOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    sheenOpacity.values = @[@0.0, @0.18, @0.18, @0.0];
    sheenOpacity.keyTimes = @[@0.0, @0.24, @0.76, @1.0];
    CABasicAnimation *sheenTravel = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    sheenTravel.fromValue = @(-CGRectGetWidth(self.logoWrapperView.bounds));
    sheenTravel.toValue = @(CGRectGetWidth(self.logoWrapperView.bounds));
    CAAnimationGroup *sheenGroup = [CAAnimationGroup animation];
    sheenGroup.animations = @[sheenOpacity, sheenTravel];
    sheenGroup.beginTime = now + 0.10;
    sheenGroup.duration = 0.58;
    sheenGroup.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                :1.0
                                                                                :0.32
                                                                                :1.0];
    [self.markSheenLayer addAnimation:sheenGroup forKey:@"pp.mark.sheen"];

    [self.trackLayers enumerateObjectsUsingBlock:^(CAShapeLayer *trackLayer,
                                                    NSUInteger index,
                                                    BOOL *stop) {
        trackLayer.opacity = 1.0f;
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fade.fromValue = @0.0;
        fade.toValue = @1.0;
        fade.beginTime = now + 0.12 + (CFTimeInterval)index * 0.045;
        fade.duration = 0.34;
        fade.fillMode = kCAFillModeBackwards;
        fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [trackLayer addAnimation:fade forKey:@"pp.track.entrance"];

        CAShapeLayer *progressLayer = self.progressLayers[index];
        progressLayer.opacity = 1.0f;
        if ((NSInteger)index < self.activeStepCount) {
            CABasicAnimation *draw = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            draw.fromValue = @0.0;
            draw.toValue = @(progressLayer.strokeEnd);
            draw.beginTime = now + 0.16 + (CFTimeInterval)index * 0.055;
            draw.duration = 0.46;
            draw.fillMode = kCAFillModeBackwards;
            draw.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                  :1.0
                                                                                  :0.32
                                                                                  :1.0];
            [progressLayer addAnimation:draw forKey:@"pp.progress.entrance"];
        }
    }];

}

- (void)pp_startMarkBreathingLoop
{
    if (UIAccessibilityIsReduceMotionEnabled() || NSProcessInfo.processInfo.isLowPowerModeEnabled) {
        return;
    }
    CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    breathe.fromValue = @1.0;
    breathe.toValue = @1.024;
    breathe.duration = 0.82;
    breathe.autoreverses = YES;
    breathe.repeatCount = HUGE_VALF;
    breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.logoWrapperView.layer addAnimation:breathe forKey:@"pp.mark.breathe"];
}

- (void)stopMotion
{
    [self.haloLayer removeAllAnimations];
    [self.pedestalLayer removeAllAnimations];
    [self.logoWrapperView.layer removeAllAnimations];
    [self.markSheenLayer removeAllAnimations];
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
    self.haloLayer.opacity = 1.0f;
    self.haloLayer.transform = CATransform3DIdentity;
    self.pedestalLayer.opacity = 1.0f;
    self.pedestalLayer.transform = CATransform3DIdentity;
    self.markSheenLayer.opacity = 0.0f;
    self.markSheenLayer.transform = CATransform3DIdentity;
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
}

- (void)pp_applyTheme
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL usesIncreasedContrast =
        self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;
    UIColor *brandColor = [(AppPrimaryClr ?: UIColor.systemPinkColor)
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *secondaryColor = [(AppSecondaryTextClr ?: UIColor.secondaryLabelColor)
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *pedestalColor = [(AppForgroundColr ?: UIColor.systemBackgroundColor)
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *progressColor = self.usesFallback
        ? [(AppInfoClr ?: brandColor) resolvedColorWithTraitCollection:self.traitCollection]
        : brandColor;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    CGFloat centerAlpha = usesIncreasedContrast
        ? (isDark ? 0.28 : 0.22)
        : (isDark ? 0.22 : 0.16);
    self.haloLayer.colors = @[
        (id)[brandColor colorWithAlphaComponent:centerAlpha].CGColor,
        (id)[brandColor colorWithAlphaComponent:centerAlpha * 0.36].CGColor,
        (id)UIColor.clearColor.CGColor
    ];

    self.pedestalLayer.backgroundColor = pedestalColor.CGColor;
    self.pedestalLayer.borderWidth = 0.0;
    self.pedestalLayer.shadowColor = UIColor.blackColor.CGColor;
    self.pedestalLayer.shadowOpacity = usesIncreasedContrast
        ? (isDark ? 0.44f : 0.16f)
        : (isDark ? 0.34f : 0.10f);
    self.pedestalLayer.shadowRadius = usesIncreasedContrast ? 18.0 : 22.0;
    self.pedestalLayer.shadowOffset = CGSizeMake(0.0, isDark ? 9.0 : 8.0);

    UIColor *trackColor = [secondaryColor colorWithAlphaComponent:
        usesIncreasedContrast ? (isDark ? 0.72 : 0.90) : (isDark ? 0.52 : 0.76)];
    CGFloat sheenAlpha = isDark ? 0.34 : 0.58;
    self.markSheenLayer.colors = @[
        (id)UIColor.clearColor.CGColor,
        (id)[UIColor.whiteColor colorWithAlphaComponent:sheenAlpha].CGColor,
        (id)UIColor.clearColor.CGColor
    ];
    CGFloat trackWidth = usesIncreasedContrast ? 3.0 : 2.0;
    CGFloat progressWidth = usesIncreasedContrast ? 5.5 : 4.5;
    for (CAShapeLayer *trackLayer in self.trackLayers) {
        trackLayer.strokeColor = trackColor.CGColor;
        trackLayer.lineWidth = trackWidth;
    }
    for (CAShapeLayer *progressLayer in self.progressLayers) {
        progressLayer.strokeColor = progressColor.CGColor;
        progressLayer.lineWidth = progressWidth;
    }
    [CATransaction commit];
}

@end

#pragma mark - Splash Controller

@interface SplashViewController ()
@property (nonatomic, assign) BOOL didShowMainVC;
@property (nonatomic, assign) BOOL didStartInitialDataLoad;
@property (nonatomic, assign) BOOL didLoadMainKinds;
@property (nonatomic, assign) BOOL didLoadBanners;
@property (nonatomic, assign) BOOL didUseFallbackLaunch;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) PPSplashLoadingPhase currentLoadingPhase;
@property (nonatomic, copy, nullable) NSString *currentLoadingDetail;
@property (nonatomic, strong, nullable) NSDate *launchBeganAt;
@property (nonatomic, copy, nullable) dispatch_block_t launchTimeoutBlock;
@property (nonatomic, strong) PPBackgroundView *ambientBackgroundView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) PPSplashLivingMarkView *livingMarkView;
@property (nonatomic, strong) NSLayoutConstraint *livingMarkWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *livingMarkHeightConstraint;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *statusGroupView;
@property (nonatomic, strong) UILabel *loadingTitleLabel;
@property (nonatomic, strong) UILabel *loadingStatusLabel;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong, nullable) UIViewPropertyAnimator *contentEntranceAnimator;
@property (nonatomic, strong, nullable) UIViewPropertyAnimator *statusEntranceAnimator;
@property (nonatomic, strong, nullable) UIViewPropertyAnimator *statusTextAnimator;
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

- (void)pp_reduceMotionStatusDidChange:(NSNotification *)notification
{
    if (!UIAccessibilityIsReduceMotionEnabled()) {
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
    ambientBackgroundView.accentColorOverride = [UIColor ppPremiumAccent];
    ambientBackgroundView.overrideSurfaceColor = [UIColor ppElevatedSurface];
    // Begin on the exact solid LaunchScreen canvas. The authored atmosphere
    // arrives only after UIKit owns the frame, avoiding a launch-boundary flash.
    ambientBackgroundView.alpha = 0.0;
    [self.view addSubview:ambientBackgroundView];
    self.ambientBackgroundView = ambientBackgroundView;

    UIStackView *contentStackView = [[UIStackView alloc] init];
    contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    contentStackView.axis = UILayoutConstraintAxisVertical;
    contentStackView.alignment = UIStackViewAlignmentCenter;
    contentStackView.distribution = UIStackViewDistributionFill;
    contentStackView.spacing = 0.0;
    contentStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:contentStackView];
    self.contentStackView = contentStackView;

    PPSplashLivingMarkView *livingMarkView = [[PPSplashLivingMarkView alloc] init];
    livingMarkView.translatesAutoresizingMaskIntoConstraints = NO;
    self.livingMarkWidthConstraint = [livingMarkView.widthAnchor constraintEqualToConstant:232.0];
    self.livingMarkHeightConstraint = [livingMarkView.heightAnchor constraintEqualToConstant:232.0];
    self.livingMarkWidthConstraint.active = YES;
    self.livingMarkHeightConstraint.active = YES;
    [contentStackView addArrangedSubview:livingMarkView];
    self.livingMarkView = livingMarkView;

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    brandLabel.textAlignment = NSTextAlignmentCenter;
    brandLabel.numberOfLines = 1;
    UIFont *brandBaseFont = [GM boldFontWithSize:PPFontLargeTitle] ?:
        [UIFont systemFontOfSize:34.0 weight:UIFontWeightBlack];
    brandLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle]
        scaledFontForFont:brandBaseFont
        maximumPointSize:50.0];
    brandLabel.adjustsFontForContentSizeCategory = YES;
    brandLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    brandLabel.alpha = 0.0;
    brandLabel.transform = CGAffineTransformMakeTranslation(0.0, PPSpaceSM);
    [contentStackView addArrangedSubview:brandLabel];
    self.brandLabel = brandLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    UIFont *subtitleBaseFont = [GM MidFontWithSize:PPFontHeadline] ?:
        [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
    subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:subtitleBaseFont
        maximumPointSize:27.0];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleLabel.alpha = 0.0;
    subtitleLabel.transform = CGAffineTransformMakeTranslation(0.0, PPSpaceSM);
    [contentStackView addArrangedSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UIView *statusGroupView = [[UIView alloc] init];
    statusGroupView.translatesAutoresizingMaskIntoConstraints = NO;
    statusGroupView.backgroundColor = UIColor.clearColor;
    statusGroupView.isAccessibilityElement = YES;
    statusGroupView.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    statusGroupView.alpha = 0.0;
    statusGroupView.transform = CGAffineTransformMakeTranslation(0.0, PPSpaceSM);
    [contentStackView addArrangedSubview:statusGroupView];
    self.statusGroupView = statusGroupView;

    UIStackView *statusTextStack = [[UIStackView alloc] init];
    statusTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    statusTextStack.axis = UILayoutConstraintAxisVertical;
    statusTextStack.alignment = UIStackViewAlignmentFill;
    statusTextStack.distribution = UIStackViewDistributionFill;
    statusTextStack.spacing = PPSpaceXXS;
    statusTextStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [statusGroupView addSubview:statusTextStack];

    UILabel *loadingTitleLabel = [[UILabel alloc] init];
    loadingTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *loadingTitleBaseFont = [GM boldFontWithSize:PPFontSubheadline] ?:
        [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    loadingTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:loadingTitleBaseFont
        maximumPointSize:24.0];
    loadingTitleLabel.adjustsFontForContentSizeCategory = YES;
    loadingTitleLabel.textAlignment = NSTextAlignmentCenter;
    loadingTitleLabel.numberOfLines = 0;
    loadingTitleLabel.isAccessibilityElement = NO;
    [statusTextStack addArrangedSubview:loadingTitleLabel];
    self.loadingTitleLabel = loadingTitleLabel;

    UILabel *loadingStatusLabel = [[UILabel alloc] init];
    loadingStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *loadingStatusBaseFont = [GM MidFontWithSize:PPFontFootnote] ?:
        [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    loadingStatusLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
        scaledFontForFont:loadingStatusBaseFont
        maximumPointSize:21.0];
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

    NSLayoutConstraint *contentFluidWidth =
        [contentStackView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-48.0];
    contentFluidWidth.priority = UILayoutPriorityRequired - 1.0;
    NSLayoutConstraint *contentMaximumWidth =
        [contentStackView.widthAnchor constraintLessThanOrEqualToConstant:430.0];
    NSLayoutConstraint *contentPreferredWidth =
        [contentStackView.widthAnchor constraintEqualToConstant:430.0];
    contentPreferredWidth.priority = UILayoutPriorityRequired - 2.0;
    // Match the static LaunchScreen's optical mark anchor exactly at default
    // content size. The surrounding safety constraints are allowed to override
    // this preference on compact or large-accessibility layouts.
    NSLayoutConstraint *markContinuityPosition =
        [livingMarkView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor
                                                     constant:-110.0];
    markContinuityPosition.priority = UILayoutPriorityDefaultHigh;

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
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
        [contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:safeArea.topAnchor
                                                                 constant:PPSpaceBase],
        [contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:footerLabel.topAnchor
                                                                 constant:-PPSpaceXXL],
        contentFluidWidth,
        contentMaximumWidth,
        contentPreferredWidth,
        markContinuityPosition,

        [brandLabel.widthAnchor constraintEqualToAnchor:contentStackView.widthAnchor],
        [subtitleLabel.widthAnchor constraintEqualToAnchor:contentStackView.widthAnchor],
        [statusGroupView.widthAnchor constraintEqualToAnchor:contentStackView.widthAnchor],

        [statusTextStack.leadingAnchor constraintEqualToAnchor:statusGroupView.leadingAnchor],
        [statusTextStack.trailingAnchor constraintEqualToAnchor:statusGroupView.trailingAnchor],
        [statusTextStack.topAnchor constraintEqualToAnchor:statusGroupView.topAnchor],
        [statusTextStack.bottomAnchor constraintEqualToAnchor:statusGroupView.bottomAnchor],

        [footerLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:PPSpaceXL],
        [footerLabel.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-PPSpaceXL],
        [footerLabel.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-PPSpaceMD]
    ]];

    [contentStackView setCustomSpacing:PPSpaceXL afterView:livingMarkView];
    [contentStackView setCustomSpacing:PPSpaceSM afterView:brandLabel];
    [contentStackView setCustomSpacing:PPSpaceXXL afterView:subtitleLabel];

    self.view.accessibilityElements = @[brandLabel, subtitleLabel, statusGroupView];
    [self pp_applyContentSizeLayout];
}

- (void)pp_applySplashTheme
{
    UIColor *canvasColor = [UIColor colorNamed:@"AppForegroundColor"] ?:
        AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *secondaryTextColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    UIColor *elevatedSurface = [[UIColor ppElevatedSurface]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *homeSoftRose = [[UIColor ppSoftRose]
        resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *premiumGold = [[UIColor ppPremiumAccent]
        resolvedColorWithTraitCollection:self.traitCollection];
    // Blend premium gold accent into elevated surface mist for splash identity
    UIColor *goldMist = [PPColorUtils blendColor:premiumGold
                                       withColor:homeSoftRose
                                          factor:0.58];

    self.view.backgroundColor = canvasColor;
    self.ambientBackgroundView.accentColorOverride = goldMist;
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
    CGFloat markDimension = usesAccessibilitySizes ? 188.0 : 232.0;
    self.livingMarkWidthConstraint.constant = markDimension;
    self.livingMarkHeightConstraint.constant = markDimension;
    self.brandLabel.numberOfLines = usesAccessibilitySizes ? 2 : 1;
    self.footerLabel.numberOfLines = usesAccessibilitySizes ? 2 : 1;

    [self.contentStackView setCustomSpacing:usesAccessibilitySizes ? PPSpaceBase : PPSpaceXL
                                  afterView:self.livingMarkView];
    [self.contentStackView setCustomSpacing:usesAccessibilitySizes ? PPSpaceXS : PPSpaceSM
                                  afterView:self.brandLabel];
    [self.contentStackView setCustomSpacing:usesAccessibilitySizes ? PPSpaceXL : PPSpaceXXL
                                  afterView:self.subtitleLabel];
    [self.view setNeedsLayout];
}

#pragma mark - Motion and Progress

- (void)pp_startSplashAtmosphereMotion
{
    // The shared field owns adaptive aurora motion and automatically reduces
    // itself for accessibility, Low Power Mode, thermal pressure, and inactive
    // application state. Shimmer and touch parallax remain explicitly disabled.
    [self.ambientBackgroundView startAnimations];
    [self.ambientBackgroundView.layer
        removeAnimationForKey:PPSplashAtmosphereDriftAnimationKey];

    if (UIAccessibilityIsReduceMotionEnabled() ||
        NSProcessInfo.processInfo.isLowPowerModeEnabled) {
        self.ambientBackgroundView.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat readingDirection =
        self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft
            ? -1.0
            : 1.0;
    CGAffineTransform openingTransform = CGAffineTransformMakeScale(1.045, 1.045);
    openingTransform = CGAffineTransformTranslate(openingTransform,
                                                  readingDirection * 6.0,
                                                  -6.0);
    CGAffineTransform passingTransform = CGAffineTransformMakeScale(1.022, 1.022);
    passingTransform = CGAffineTransformTranslate(passingTransform,
                                                  readingDirection * -3.0,
                                                  2.5);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ambientBackgroundView.layer.transform = CATransform3DIdentity;
    [CATransaction commit];

    CAKeyframeAnimation *fieldSettle =
        [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    fieldSettle.values = @[
        [NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(openingTransform)],
        [NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(passingTransform)],
        [NSValue valueWithCATransform3D:CATransform3DIdentity]
    ];
    fieldSettle.keyTimes = @[@0.0, @0.58, @1.0];
    fieldSettle.calculationMode = kCAAnimationCubic;
    fieldSettle.timingFunctions = @[
        [CAMediaTimingFunction functionWithControlPoints:0.20 :0.0 :0.0 :1.0],
        [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0]
    ];
    fieldSettle.duration = 1.80;
    fieldSettle.fillMode = kCAFillModeBackwards;
    [self.ambientBackgroundView.layer addAnimation:fieldSettle
                                            forKey:PPSplashAtmosphereDriftAnimationKey];
}

- (void)pp_stopSplashAtmosphereMotion
{
    [self.ambientBackgroundView stopAnimations];
    [self.ambientBackgroundView.layer
        removeAnimationForKey:PPSplashAtmosphereDriftAnimationKey];
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
        self.brandLabel.transform = CGAffineTransformIdentity;
        self.subtitleLabel.alpha = 1.0;
        self.subtitleLabel.transform = CGAffineTransformIdentity;
        self.statusGroupView.alpha = 1.0;
        self.statusGroupView.transform = CGAffineTransformIdentity;
        self.footerLabel.alpha = 1.0;
        return;
    }

    __weak typeof(self) weakSelf = self;
    UICubicTimingParameters *entranceTiming =
        [[UICubicTimingParameters alloc] initWithControlPoint1:CGPointMake(0.23, 1.0)
                                                 controlPoint2:CGPointMake(0.32, 1.0)];
    UIViewPropertyAnimator *copyAnimator =
        [[UIViewPropertyAnimator alloc] initWithDuration:0.44
                                        timingParameters:entranceTiming];
    [copyAnimator addAnimations:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.ambientBackgroundView.alpha = 1.0;
        self.brandLabel.alpha = 1.0;
        self.brandLabel.transform = CGAffineTransformIdentity;
        self.subtitleLabel.alpha = 1.0;
        self.subtitleLabel.transform = CGAffineTransformIdentity;
    }];
    self.contentEntranceAnimator = copyAnimator;
    [copyAnimator startAnimationAfterDelay:0.08];

    UIViewPropertyAnimator *statusAnimator =
        [[UIViewPropertyAnimator alloc] initWithDuration:0.34
                                        timingParameters:entranceTiming];
    [statusAnimator addAnimations:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.statusGroupView.alpha = 1.0;
        self.statusGroupView.transform = CGAffineTransformIdentity;
        self.footerLabel.alpha = 1.0;
    }];
    self.statusEntranceAnimator = statusAnimator;
    [statusAnimator startAnimationAfterDelay:0.16];
}

- (void)pp_refreshLoadingProgressPresentation
{
    // A late manager callback must not overwrite the timeout/fallback state
    // that will be captured by the root-handoff snapshot.
    if (self.didShowMainVC) {
        return;
    }

    NSInteger completedTasks = (self.didLoadMainKinds ? 1 : 0) + (self.didLoadBanners ? 1 : 0);
    PPSplashLoadingPhase phase = PPSplashLoadingPhaseBootstrapping;
    NSString *detail = nil;

    if (completedTasks <= 0) {
        phase = PPSplashLoadingPhaseBootstrapping;
        detail = kLang(@"splash_loading_boot");
    } else if (!self.didLoadMainKinds) {
        phase = PPSplashLoadingPhasePreparingContent;
        detail = kLang(@"splash_loading_categories");
    } else if (!self.didLoadBanners) {
        phase = PPSplashLoadingPhaseFinalizing;
        detail = kLang(@"splash_loading_highlights");
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

    NSInteger completedTasks = (self.didLoadMainKinds ? 1 : 0) + (self.didLoadBanners ? 1 : 0);
    NSInteger activeSteps = MIN(1 + completedTasks, 3);
    if (isReady && !self.didUseFallbackLaunch) {
        activeSteps = 3;
    }

    BOOL shouldAnimate = self.view.window != nil && self.didAnimateEntrance;
    [self.livingMarkView setActiveStepCount:activeSteps animated:shouldAnimate];
    [self.livingMarkView setReady:isReady
                    usesFallback:self.didUseFallbackLaunch
                         animated:shouldAnimate && previousPhase != phase];

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
    self.didLoadBanners = NO;
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

    __block BOOL didLeaveBannerGroup = NO;
    dispatch_group_enter(group);

    if (PPBannersManager.sharedManager.bannerGroups.count > 0) {
        NSLog(@"[PPBannersManager] ✅ LOADED BEFORE");

        didLeaveBannerGroup = YES;
        self.didLoadBanners = YES;
        [self pp_refreshLoadingProgressPresentation];
        dispatch_group_leave(group);
    } else {
        [[PPBannersManager sharedManager] fetchBannersOnceWithCompletion:^(NSArray<MainBannerModel *> * _Nullable bannerGroups, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (didLeaveBannerGroup) {
                    return;
                }
                didLeaveBannerGroup = YES;

                BOOL didSucceed = error == nil;
                if (!didSucceed) {
                    NSLog(@"[Splash] ⚠️ Error fetching banners: %@", error.localizedDescription);
                } else {
                    NSLog(@"[Splash] ✅ Banners fetched: %lu items", (unsigned long)bannerGroups.count);
                }

                self.didLoadBanners = didSucceed;
                [self pp_refreshLoadingProgressPresentation];
                dispatch_group_leave(group);
            });
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"[Splash] 🎬 Startup callbacks terminal (MainKinds=%@, Banners=%@)",
              self.didLoadMainKinds ? @"✅" : @"❌",
              self.didLoadBanners ? @"✅" : @"❌");

        // Preserve the legacy navigation contract: terminal callbacks still
        // fail open. Presentation truthfully distinguishes complete from partial.
        [self pp_completeLaunchIfNeededForced:NO];
    });
}

- (void)pp_completeLaunchIfNeededForced:(BOOL)forced
{
    if (self.didShowMainVC) {
        return;
    }

    self.didShowMainVC = YES;
    BOOL didCompleteAllLaunchData = self.didLoadMainKinds && self.didLoadBanners;
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
