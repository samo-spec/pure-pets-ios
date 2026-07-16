//
//  PPPlaybackWaveformView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//

#import "PPPlaybackWaveformView.h"
#import <QuartzCore/QuartzCore.h>

static const NSInteger PPPlaybackMinimumBarCount = 24;
static const NSInteger PPPlaybackMaximumBarCount = 46;
static const CGFloat PPPlaybackPreferredBarWidth = 2.35;
static const CGFloat PPPlaybackPreferredSpacing = 2.05;
static const CGFloat PPPlaybackMinimumAmplitude = 0.10;
static const CGFloat PPPlaybackMaximumAmplitude = 0.90;
static const CFTimeInterval PPPlaybackRevealDuration = 0.42;

static CGFloat PPClamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
    return MIN(MAX(value, minimum), maximum);
}

static UIColor *PPPlaybackBlendColor(UIColor *fromColor, UIColor *toColor, CGFloat progress)
{
    progress = PPClamp(progress, 0.0, 1.0);
    CGFloat fromR = 0.0, fromG = 0.0, fromB = 0.0, fromA = 1.0;
    CGFloat toR = 0.0, toG = 0.0, toB = 0.0, toA = 1.0;

    if (![fromColor getRed:&fromR green:&fromG blue:&fromB alpha:&fromA]) {
        CGFloat white = 0.0;
        [fromColor getWhite:&white alpha:&fromA];
        fromR = fromG = fromB = white;
    }
    if (![toColor getRed:&toR green:&toG blue:&toB alpha:&toA]) {
        CGFloat white = 0.0;
        [toColor getWhite:&white alpha:&toA];
        toR = toG = toB = white;
    }

    return [UIColor colorWithRed:fromR + ((toR - fromR) * progress)
                           green:fromG + ((toG - fromG) * progress)
                            blue:fromB + ((toB - fromB) * progress)
                           alpha:fromA + ((toA - fromA) * progress)];
}

@interface PPPlaybackWaveformView ()
@property (nonatomic, copy) NSArray<NSNumber *> *rawSamples;
@property (nonatomic, copy) NSArray<NSNumber *> *displaySamples;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGFloat targetProgress;
@property (nonatomic, assign) CGFloat displayedProgress;
@property (nonatomic, assign) CGFloat progressVelocity;
@property (nonatomic, assign) CGFloat revealProgress;
@property (nonatomic, assign) CFTimeInterval previousFrameTimestamp;
@property (nonatomic, assign) CGSize sampledSize;
@end

@implementation PPPlaybackWaveformView

#pragma mark - Lifecycle

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.clipsToBounds = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.isAccessibilityElement = NO;
    _rawSamples = @[];
    _displaySamples = @[];
    _revealProgress = 1.0;
    return self;
}

- (void)dealloc
{
    [self pp_stopDisplayLink];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (!self.window) {
        [self pp_stopDisplayLink];
    } else {
        [self pp_updateAnimationState];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!CGSizeEqualToSize(self.bounds.size, self.sampledSize)) {
        self.sampledSize = self.bounds.size;
        [self pp_rebuildDisplaySamples];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self setNeedsDisplay];
}

#pragma mark - Public API

- (void)setActiveColor:(UIColor *)activeColor
{
    if ([_activeColor isEqual:activeColor]) return;
    _activeColor = activeColor;
    [self setNeedsDisplay];
}

- (void)setInactiveColor:(UIColor *)inactiveColor
{
    if ([_inactiveColor isEqual:inactiveColor]) return;
    _inactiveColor = inactiveColor;
    [self setNeedsDisplay];
}

- (void)setSamples:(nullable NSArray<NSNumber *> *)samples
{
    void (^update)(void) = ^{
        self.rawSamples = [self pp_sanitizedSamples:samples];
        [self pp_rebuildDisplaySamples];
        self.revealProgress = UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 0.0;
        self.previousFrameTimestamp = 0.0;
        [self pp_updateAnimationState];
        [self setNeedsDisplay];
    };
    NSThread.isMainThread ? update() : dispatch_async(dispatch_get_main_queue(), update);
}

- (void)setPlaybackProgress:(CGFloat)progress
{
    void (^update)(void) = ^{
        CGFloat clampedProgress = PPClamp(progress, 0.0, 1.0);
        self.targetProgress = clampedProgress;
        if (UIAccessibilityIsReduceMotionEnabled() || !self.window ||
            fabs(self.displayedProgress - clampedProgress) > 0.24) {
            self.displayedProgress = clampedProgress;
            self.progressVelocity = 0.0;
        }
        [self pp_updateAnimationState];
        [self setNeedsDisplay];
    };
    NSThread.isMainThread ? update() : dispatch_async(dispatch_get_main_queue(), update);
}

- (void)reset
{
    [self pp_stopDisplayLink];
    self.rawSamples = @[];
    self.displaySamples = @[];
    self.targetProgress = 0.0;
    self.displayedProgress = 0.0;
    self.progressVelocity = 0.0;
    self.revealProgress = 1.0;
    self.previousFrameTimestamp = 0.0;
    [self setNeedsDisplay];
}

+ (NSArray<NSNumber *> *)idleSamples
{
    static NSArray<NSNumber *> *samples;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:40];
        for (NSInteger index = 0; index < 40; index++) {
            CGFloat cadence = 0.075 + (0.018 * sin(index * 0.82)) +
                              (0.010 * sin(index * 0.29 + 1.4));
            [values addObject:@(MAX(cadence, 0.05))];
        }
        samples = values.copy;
    });
    return samples;
}

#pragma mark - Sample Processing

- (NSArray<NSNumber *> *)pp_sanitizedSamples:(nullable NSArray<NSNumber *> *)samples
{
    if (![samples isKindOfClass:NSArray.class] || samples.count == 0) return @[];

    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:samples.count];
    for (id value in samples) {
        if (![value respondsToSelector:@selector(doubleValue)]) continue;
        CGFloat amplitude = PPClamp([value doubleValue], 0.0, 1.0);
        // Square-root compression preserves speech detail without exaggerating peaks.
        amplitude = sqrt(amplitude);
        [result addObject:@(PPClamp(amplitude, PPPlaybackMinimumAmplitude, 1.0))];
    }
    return result.copy;
}

- (NSInteger)pp_barCountForWidth:(CGFloat)width
{
    NSInteger count = (NSInteger)floor((width + PPPlaybackPreferredSpacing) /
                                       (PPPlaybackPreferredBarWidth + PPPlaybackPreferredSpacing));
    return MIN(MAX(count, PPPlaybackMinimumBarCount), PPPlaybackMaximumBarCount);
}

- (void)pp_rebuildDisplaySamples
{
    if (self.rawSamples.count == 0 || CGRectGetWidth(self.bounds) <= 0.0) {
        self.displaySamples = self.rawSamples;
        [self setNeedsDisplay];
        return;
    }

    NSInteger targetCount = [self pp_barCountForWidth:CGRectGetWidth(self.bounds)];
    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:targetCount];
    for (NSInteger bar = 0; bar < targetCount; bar++) {
        CGFloat sourcePosition = ((CGFloat)bar + 0.5) * self.rawSamples.count / targetCount;
        NSInteger sourceStart = MAX(0, (NSInteger)floor((CGFloat)bar * self.rawSamples.count / targetCount));
        NSInteger sourceEnd = MIN((NSInteger)self.rawSamples.count,
                                  MAX(sourceStart + 1, (NSInteger)ceil(((CGFloat)bar + 1.0) * self.rawSamples.count / targetCount)));
        CGFloat peak = 0.0;
        CGFloat sum = 0.0;
        for (NSInteger index = sourceStart; index < sourceEnd; index++) {
            CGFloat value = self.rawSamples[index].doubleValue;
            peak = MAX(peak, value);
            sum += value;
        }
        CGFloat average = sum / MAX(sourceEnd - sourceStart, 1);
        CGFloat shaped = (peak * 0.42) + (average * 0.58);
        CGFloat contour = 0.98 + (0.02 * sin(sourcePosition * 0.31));
        [result addObject:@(PPClamp(shaped * contour, PPPlaybackMinimumAmplitude, 1.0))];
    }
    self.displaySamples = result.copy;
    [self setNeedsDisplay];
}

#pragma mark - Motion

- (void)pp_updateAnimationState
{
    BOOL progressNeedsSettling = fabs(self.targetProgress - self.displayedProgress) > 0.0005 ||
                                     fabs(self.progressVelocity) > 0.0005;
    BOOL revealNeedsFinishing = self.revealProgress < 1.0;
    if (self.window && !UIAccessibilityIsReduceMotionEnabled() &&
        (progressNeedsSettling || revealNeedsFinishing)) {
        [self pp_startDisplayLink];
    } else {
        if (UIAccessibilityIsReduceMotionEnabled()) {
            self.displayedProgress = self.targetProgress;
            self.revealProgress = 1.0;
        }
        [self pp_stopDisplayLink];
    }
}

- (void)pp_startDisplayLink
{
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(pp_tick:)];
    if (@available(iOS 15.0, *)) {
        self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30.0, 60.0, 60.0);
    } else {
        self.displayLink.preferredFramesPerSecond = 60;
    }
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)pp_stopDisplayLink
{
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.previousFrameTimestamp = 0.0;
}

- (void)pp_tick:(CADisplayLink *)displayLink
{
    CFTimeInterval delta = self.previousFrameTimestamp > 0.0
        ? displayLink.timestamp - self.previousFrameTimestamp
        : displayLink.duration;
    self.previousFrameTimestamp = displayLink.timestamp;
    delta = MIN(MAX(delta, 1.0 / 120.0), 1.0 / 20.0);

    if (self.revealProgress < 1.0) {
        self.revealProgress = MIN(1.0, self.revealProgress + (delta / PPPlaybackRevealDuration));
    }

    // Damped spring: responsive enough for scrubbing, calm enough for timed playback updates.
    CGFloat displacement = self.targetProgress - self.displayedProgress;
    self.progressVelocity += displacement * 220.0 * delta;
    self.progressVelocity *= exp(-22.0 * delta);
    self.displayedProgress += self.progressVelocity * delta;
    if (fabs(displacement) < 0.0005 && fabs(self.progressVelocity) < 0.0005) {
        self.displayedProgress = self.targetProgress;
        self.progressVelocity = 0.0;
    }

    [self setNeedsDisplay];
    [self pp_updateAnimationState];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context || self.displaySamples.count == 0 || CGRectIsEmpty(rect)) return;

    UIColor *active = self.activeColor ?: UIColor.labelColor;
    UIColor *inactive = self.inactiveColor ?: [UIColor.secondaryLabelColor colorWithAlphaComponent:0.24];
    UIColor *highlight = PPPlaybackBlendColor(active, UIColor.whiteColor,
                                              self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.22 : 0.10);

    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    NSInteger count = self.displaySamples.count;
    CGFloat spacing = width < 150.0 ? 1.7 : PPPlaybackPreferredSpacing;
    CGFloat barWidth = MAX(1.8, (width - (spacing * (count - 1))) / count);
    CGFloat totalWidth = (barWidth * count) + (spacing * (count - 1));
    CGFloat originX = MAX(0.0, (width - totalWidth) * 0.5);
    CGFloat progressPosition = PPClamp(self.displayedProgress, 0.0, 1.0) * MAX(count - 1, 1);
    BOOL isRTL = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

    CGContextSetAllowsAntialiasing(context, true);
    CGContextSetShouldAntialias(context, true);

    for (NSInteger sampleIndex = 0; sampleIndex < count; sampleIndex++) {
        NSInteger visualIndex = isRTL ? count - 1 - sampleIndex : sampleIndex;
        CGFloat x = originX + (visualIndex * (barWidth + spacing));
        CGFloat amplitude = self.displaySamples[sampleIndex].doubleValue;

        CGFloat staggerStart = ((CGFloat)sampleIndex / MAX(count - 1, 1)) * 0.34;
        CGFloat localReveal = PPClamp((self.revealProgress - staggerStart) / 0.66, 0.0, 1.0);
        localReveal = 1.0 - pow(1.0 - localReveal, 3.0);
        CGFloat barHeight = MAX(2.0, amplitude * height * PPPlaybackMaximumAmplitude * localReveal);
        CGRect barRect = CGRectMake(x, centerY - (barHeight * 0.5), barWidth, barHeight);

        CGFloat playedCoverage = PPClamp((self.displayedProgress * count) - sampleIndex, 0.0, 1.0);
        UIColor *barColor = PPPlaybackBlendColor(inactive, active, playedCoverage);
        CGFloat playheadDistance = fabs(progressPosition - sampleIndex);
        if (playheadDistance < 1.65 && self.displayedProgress > 0.0) {
            CGFloat focus = 1.0 - (playheadDistance / 1.65);
            barColor = PPPlaybackBlendColor(barColor, highlight, focus * 0.72);
        }

        UIBezierPath *barPath = [UIBezierPath bezierPathWithRoundedRect:barRect
                                                           cornerRadius:MIN(barWidth * 0.5, barHeight * 0.5)];
        CGContextSetFillColorWithColor(context, barColor.CGColor);
        CGContextAddPath(context, barPath.CGPath);
        CGContextFillPath(context);
    }

    if (self.displayedProgress > 0.001 && self.displayedProgress < 0.999 && !UIAccessibilityIsReduceMotionEnabled()) {
        CGFloat logicalX = originX + (progressPosition * (barWidth + spacing)) + (barWidth * 0.5);
        CGFloat playheadX = isRTL ? width - logicalX : logicalX;
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, CGSizeZero, 4.0,
                                    [active colorWithAlphaComponent:0.28].CGColor);
        CGContextSetFillColorWithColor(context, [highlight colorWithAlphaComponent:0.72].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(playheadX - 1.25, centerY - 1.25, 2.5, 2.5));
        CGContextRestoreGState(context);
    }
}

@end
