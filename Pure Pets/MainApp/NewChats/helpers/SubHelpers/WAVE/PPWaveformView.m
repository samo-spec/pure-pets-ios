#import "PPWaveformView.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *PPBlendColors(UIColor *c1, UIColor *c2, CGFloat t) {
    t = MIN(MAX(t, 0), 1);
    CGFloat r1 = 0.0, g1 = 0.0, b1 = 0.0, a1 = 1.0;
    CGFloat r2 = 0.0, g2 = 0.0, b2 = 0.0, a2 = 1.0;
    if (![c1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1]) {
        CGFloat white = 0.0;
        CGFloat alpha = 1.0;
        [c1 getWhite:&white alpha:&alpha];
        r1 = g1 = b1 = white;
        a1 = alpha;
    }
    if (![c2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) {
        CGFloat white = 0.0;
        CGFloat alpha = 1.0;
        [c2 getWhite:&white alpha:&alpha];
        r2 = g2 = b2 = white;
        a2 = alpha;
    }
    return [UIColor colorWithRed:r1+(r2-r1)*t
                           green:g1+(g2-g1)*t
                            blue:b1+(b2-b1)*t
                           alpha:a1+(a2-a1)*t];
}

static const NSInteger kPPWaveformBarCount = 42;
static const CGFloat   kPPWaveformMinLevel = 0.018f;
static const CGFloat   kPPWaveformIdleLevel = 0.055f;
static const CGFloat   kPPWaveformMinimumBarWidth = 2.2f;
static const CGFloat   kPPWaveformCompactSpacing = 1.6f;
static const CGFloat   kPPWaveformRegularSpacing = 2.1f;

// Voice-meter tuning: visible at conversational levels without becoming jumpy.
static const float kPPWaveformNoiseGate = 0.035f;
static const float kPPWaveformCompression = 0.46f;
static const float kPPWaveformMaxVisual = 0.88f;
static const float kPPWaveformIdleFloor = 0.07f;

@interface PPWaveformView ()
@property (nonatomic, strong) NSMutableArray<NSNumber *> *samples;
@property (nonatomic, assign) BOOL isFrozen;
@property (nonatomic, assign) CGFloat playbackProgress;
@property (nonatomic, assign) CGFloat smoothedLevel;
@property (nonatomic, assign) CGFloat smoothingFactor;
@property (nonatomic, strong) CADisplayLink *ambientDisplayLink;
@property (nonatomic, assign) CGFloat ambientPhase;
@property (nonatomic, assign) CFTimeInterval lastSampleTimestamp;
@end

@implementation PPWaveformView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.layer.cornerRadius = 6;

    _samples = [NSMutableArray array];
    _playbackProgress = 0;
    _smoothingFactor = 0.32;
    _smoothedLevel = 0.0;
    _lastSampleTimestamp = 0.0;
    _visualState = PPWaveformVisualStatePreview;

    return self;
}

- (void)dealloc
{
    [self pp_stopAmbientDisplayLink];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self pp_updateAmbientDisplayLink];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(132, 28);
}

#pragma mark - Private helpers

// WhatsApp-like normalization from dB (not always used, but for completeness)
- (float)pp_normalizedLevelFromDecibels:(float)db {
    const float minDb = -60.0f;
    if (db < minDb) return 0.0f;
    float n = (db - minDb) / -minDb; // 0..1
    if (n < kPPWaveformNoiseGate) return 0.0f;
    n = powf(n, kPPWaveformCompression); // compress loud spikes
    return fminf(fmaxf(n, 0.0f), 1.0f);
}

- (BOOL)pp_shouldRunAmbientMotion
{
    if (UIAccessibilityIsReduceMotionEnabled()) return NO;
    if (!self.window) return NO;
    if (self.isFrozen) return NO;
    return (self.visualState == PPWaveformVisualStateRecording ||
            self.visualState == PPWaveformVisualStateLocked);
}

- (void)pp_updateAmbientDisplayLink
{
    if ([self pp_shouldRunAmbientMotion]) {
        [self pp_startAmbientDisplayLink];
    } else {
        [self pp_stopAmbientDisplayLink];
    }
}

- (void)pp_startAmbientDisplayLink
{
    if (self.ambientDisplayLink) return;

    self.ambientDisplayLink =
        [CADisplayLink displayLinkWithTarget:self selector:@selector(pp_ambientTick:)];
    if (@available(iOS 10.0, *)) {
        self.ambientDisplayLink.preferredFramesPerSecond = 30;
    }
    [self.ambientDisplayLink addToRunLoop:NSRunLoop.mainRunLoop
                                  forMode:NSRunLoopCommonModes];
}

- (void)pp_stopAmbientDisplayLink
{
    [self.ambientDisplayLink invalidate];
    self.ambientDisplayLink = nil;
}

- (void)pp_ambientTick:(CADisplayLink *)displayLink
{
    self.ambientPhase += displayLink.duration * 4.35;
    if (self.ambientPhase > M_PI * 2.0) {
        self.ambientPhase = fmod(self.ambientPhase, M_PI * 2.0);
    }
    [self setNeedsDisplay];
}

#pragma mark - API

- (void)setVisualState:(PPWaveformVisualState)visualState
{
    if (_visualState == visualState) return;
    _visualState = visualState;
    [self pp_updateAmbientDisplayLink];
    [self setNeedsDisplay];
}

- (void)addSample:(float)level {
    if (self.isFrozen) return;

    // level is expected normalized 0..1 (caller may pass raw)
    float n = fminf(fmaxf(level, 0.0f), 1.0f);

    if (n < kPPWaveformNoiseGate) {
        n = kPPWaveformIdleFloor;
    } else {
        n = powf(n, kPPWaveformCompression);
    }

    float alpha = n > self.smoothedLevel ? self.smoothingFactor : 0.22f;
    self.smoothedLevel = self.smoothedLevel * (1.0f - alpha) + n * alpha;

    float clamped = fminf(fmaxf(self.smoothedLevel, kPPWaveformIdleFloor), 1.0f);
    self.lastSampleTimestamp = CACurrentMediaTime();

    void (^appendSample)(void) = ^{
        [self.samples addObject:@(clamped)];
        if (self.samples.count > kPPWaveformBarCount) {
            [self.samples removeObjectAtIndex:0];
        }
        [self setNeedsDisplay];
    };

    if (NSThread.isMainThread) {
        appendSample();
    } else {
        dispatch_async(dispatch_get_main_queue(), appendSample);
    }
}

- (void)freeze {
    self.isFrozen = YES;
    [self pp_updateAmbientDisplayLink];
    if (self.samples.count > kPPWaveformBarCount) {
        self.samples = [[self.samples subarrayWithRange:
                         NSMakeRange(self.samples.count - kPPWaveformBarCount,
                                     kPPWaveformBarCount)] mutableCopy];
    }
    [self setNeedsDisplay];
}

- (void)reset {
    self.isFrozen = NO;
    self.playbackProgress = 0;
    self.smoothedLevel = 0.0;
    self.lastSampleTimestamp = CACurrentMediaTime();
    [self.samples removeAllObjects];
    [self pp_updateAmbientDisplayLink];
    [self setNeedsDisplay];
}

- (void)setPlaybackProgress:(CGFloat)progress {
    _playbackProgress = fmin(fmax(progress, 0), 1);
    [self setNeedsDisplay];
}

#pragma mark - Drawing (Refactored)

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    if (width <= 1.0 || height <= 1.0) return;

    CGFloat centerY = height * 0.5;
    CGFloat maxAmplitude = height * kPPWaveformMaxVisual * 0.5;

    UIColor *primaryColor = self.activeColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    UIColor *secondaryPrimaryColor = self.accentColor ?: (AppPrimaryClrDarker ?: primaryColor);
    UIColor *inactiveOverride = self.inactiveColor;
    UIColor *inactiveColor;
    UIColor *activeColor;
    UIColor *accentColor;

    switch (self.visualState) {
        case PPWaveformVisualStateRecording:
        case PPWaveformVisualStateLocked:
            inactiveColor = inactiveOverride ?: [UIColor.secondaryLabelColor colorWithAlphaComponent:0.18];
            activeColor   = [primaryColor colorWithAlphaComponent:0.72];
            accentColor   = [primaryColor colorWithAlphaComponent:0.96];
            break;

        case PPWaveformVisualStatePreview:
            inactiveColor = inactiveOverride ?: [secondaryPrimaryColor colorWithAlphaComponent:0.16];
            activeColor   = [primaryColor colorWithAlphaComponent:0.92];
            accentColor   = PPBlendColors(activeColor, secondaryPrimaryColor, 0.18);
            break;
    }

    BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection ==
                  UIUserInterfaceLayoutDirectionRightToLeft);

    CGFloat spacing = width < 150.0 ? kPPWaveformCompactSpacing : kPPWaveformRegularSpacing;
    NSInteger barCount = MIN(kPPWaveformBarCount,
                             MAX(18, (NSInteger)floor((width + spacing) /
                                                      (kPPWaveformMinimumBarWidth + spacing))));
    CGFloat barWidth = (width - (spacing * (barCount - 1))) / barCount;
    barWidth = MAX(kPPWaveformMinimumBarWidth, barWidth);
    CGFloat totalWidth = (barWidth * barCount) + (spacing * (barCount - 1));
    CGFloat startX = MAX(0.0, (width - totalWidth) * 0.5);
    CGFloat cornerRadius = MAX(1.0, barWidth * 0.5);

    NSInteger availableSamples = MIN((NSInteger)self.samples.count, barCount);
    NSInteger sampleStartIndex = MAX((NSInteger)self.samples.count - availableSamples, 0);
    NSInteger offset = barCount - availableSamples;
    CGFloat playhead = self.playbackProgress * (barCount - 1);
    BOOL isLive = !self.isFrozen &&
        (self.visualState == PPWaveformVisualStateRecording ||
         self.visualState == PPWaveformVisualStateLocked);
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    CFTimeInterval sampleAge = CACurrentMediaTime() - self.lastSampleTimestamp;

    CGRect centerLineRect = CGRectMake(startX,
                                       centerY - 0.5,
                                       MIN(totalWidth, width),
                                       1.0);
    UIColor *centerLineColor = [inactiveColor colorWithAlphaComponent:isLive ? 0.30 : 0.22];
    UIBezierPath *centerLine =
        [UIBezierPath bezierPathWithRoundedRect:centerLineRect cornerRadius:0.5];
    CGContextSetFillColorWithColor(ctx, centerLineColor.CGColor);
    CGContextAddPath(ctx, centerLine.CGPath);
    CGContextFillPath(ctx);

    for (NSInteger i = 0; i < barCount; i++) {

        float level;
        if (i < offset) {
            level = (self.visualState == PPWaveformVisualStateRecording)
            ? kPPWaveformIdleLevel : 0;
        } else {
            level = self.samples[sampleStartIndex + (i - offset)].floatValue;
        }

        if (isLive) {
            CGFloat ambient = reduceMotion ? 0.0 : (0.026 * sin(self.ambientPhase + (i * 0.48)));
            CGFloat idleLift = (sampleAge > 0.18 && sampleAge < 1.1) ? 0.014 : 0.0;
            level = fminf(1.0f, fmaxf(kPPWaveformIdleFloor, level + ambient + idleLift));
        }

        if (level <= 0) continue;

        CGFloat halfHeight = MAX(level * maxAmplitude, 1.7);

        NSInteger visualIndex = isRTL ? (barCount - 1 - i) : i;
        CGFloat x = startX + visualIndex * (barWidth + spacing);

        UIColor *color = inactiveColor;

        if (self.isFrozen && i <= playhead) {
            color = activeColor;

            CGFloat distance = fabs(i - playhead);
            if (distance < 2.0) {
                CGFloat t = 1.0 - (distance / 2.0);
                color = PPBlendColors(activeColor, accentColor, t);
            }
        } else if (isLive) {
            CGFloat recency = (CGFloat)i / MAX((CGFloat)(barCount - 1), 1.0);
            color = PPBlendColors([inactiveColor colorWithAlphaComponent:0.72],
                                  activeColor,
                                  MAX(0.18, recency));
            if (i >= barCount - 6) {
                color = PPBlendColors(color, accentColor, 0.42);
            }
        }

        CGRect barRect = CGRectMake(x,
                                    centerY - halfHeight,
                                    barWidth,
                                    halfHeight * 2);

        if (isLive && level > 0.18) {
            CGContextSaveGState(ctx);
            CGContextSetShadowWithColor(ctx,
                                        CGSizeMake(0.0, 0.0),
                                        3.4,
                                        [primaryColor colorWithAlphaComponent:0.16].CGColor);
        }

        UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:barRect
                                   cornerRadius:cornerRadius];

        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextAddPath(ctx, path.CGPath);
        CGContextFillPath(ctx);

        if (isLive && level > 0.18) {
            CGContextRestoreGState(ctx);
        }
    }
}


- (void)loadWaveformFromAudioURL:(NSURL *)url {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        AVAsset *asset = [AVAsset assetWithURL:url];
        AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        if (!track) return;

        NSError *error = nil;
        AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
        if (error) return;

        NSDictionary *settings = @{
            AVFormatIDKey: @(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: @16,
            AVLinearPCMIsBigEndianKey: @NO,
            AVLinearPCMIsFloatKey: @NO,
            AVLinearPCMIsNonInterleaved: @NO
        };

        AVAssetReaderTrackOutput *output =
        [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];

        output.alwaysCopiesSampleData = NO;
        [reader addOutput:output];
        [reader startReading];

        NSMutableData *audioData = [NSMutableData data];

        while (reader.status == AVAssetReaderStatusReading) {
            CMSampleBufferRef buffer = [output copyNextSampleBuffer];
            if (!buffer) break;

            CMBlockBufferRef block = CMSampleBufferGetDataBuffer(buffer);
            size_t length = CMBlockBufferGetDataLength(block);

            SInt16 *data = malloc(length);
            CMBlockBufferCopyDataBytes(block, 0, length, data);
            [audioData appendBytes:data length:length];
            free(data);

            CFRelease(buffer);
        }

        if (audioData.length == 0) return;

        SInt16 *samples = (SInt16 *)audioData.bytes;
        NSUInteger sampleCount = audioData.length / sizeof(SInt16);

        NSUInteger targetBars = kPPWaveformBarCount;
        NSUInteger samplesPerBar = MAX(sampleCount / targetBars, 1);

        NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:targetBars];

        for (NSUInteger i = 0; i < targetBars; i++) {
            SInt16 maxVal = 0;

            for (NSUInteger j = 0; j < samplesPerBar; j++) {
                NSUInteger index = i * samplesPerBar + j;
                if (index >= sampleCount) break;
                SInt16 val = abs(samples[index]);
                if (val > maxVal) maxVal = val;
            }

            float normalized = (float)maxVal / 32767.0f;
            normalized = powf(fmaxf(normalized, kPPWaveformMinLevel), kPPWaveformCompression);
            if (normalized < kPPWaveformNoiseGate) normalized = kPPWaveformIdleFloor;
            normalized = fminf(fmaxf(normalized, 0.0f), 1.0f);
            [result addObject:@(normalized)];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.samples = result.mutableCopy;
            self.isFrozen = YES;   // ready for playback mode
            [self setNeedsDisplay];
        });
    });
}

@end
