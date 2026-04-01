#import "PPWaveformView.h"

static UIColor *PPBlendColors(UIColor *c1, UIColor *c2, CGFloat t) {
    t = MIN(MAX(t, 0), 1);
    CGFloat r1,g1,b1,a1,r2,g2,b2,a2;
    [c1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [c2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    return [UIColor colorWithRed:r1+(r2-r1)*t
                           green:g1+(g2-g1)*t
                            blue:b1+(b2-b1)*t
                           alpha:a1+(a2-a1)*t];
}

static const NSInteger kPPWaveformBarCount = 40;
static const CGFloat   kPPWaveformMinLevel = 0.015f;
static const CGFloat   kPPWaveformIdleLevel = 0.02f;
static const CGFloat   kPPWaveformBarSpacing = 2.5f;

// WhatsApp-like waveform behavior tuning
static const float kPPWaveformNoiseGate = 0.08f;   // ignore tiny sounds
static const float kPPWaveformCompression = 0.55f; // non-linear compression
static const float kPPWaveformMaxVisual = 0.75f;   // cap visual height
static const float kPPWaveformIdleFloor = 0.03f;   // idle dots baseline

@interface PPWaveformView ()
@property (nonatomic, strong) NSMutableArray<NSNumber *> *samples;
@property (nonatomic, assign) BOOL isFrozen;
@property (nonatomic, assign) CGFloat playbackProgress;
@property (nonatomic, assign) CGFloat smoothedLevel;
@property (nonatomic, assign) CGFloat smoothingFactor;
@end

@implementation PPWaveformView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 4;

    _samples = [NSMutableArray array];
    _playbackProgress = 0;
    _smoothingFactor = 0.18;
    _smoothedLevel = 0.0;

    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(120, 20);
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

#pragma mark - API

- (void)addSample:(float)level {
    if (self.isFrozen) return;

    // level is expected normalized 0..1 (caller may pass raw)
    float n = fminf(fmaxf(level, 0.0f), 1.0f);

    // Noise gate + idle baseline
    if (n < kPPWaveformNoiseGate) {
        n = kPPWaveformIdleFloor;
    }

    // EMA smoothing (WhatsApp-like)
    float alpha = self.smoothingFactor; // ~0.18
    self.smoothedLevel = self.smoothedLevel * (1.0f - alpha) + n * alpha;

    float clamped = fminf(fmaxf(self.smoothedLevel, 0.0f), 1.0f);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.samples addObject:@(clamped)];
        if (self.samples.count > kPPWaveformBarCount) {
            [self.samples removeObjectAtIndex:0];
        }
        [self setNeedsDisplay];
    });
}

- (void)freeze {
    self.isFrozen = YES;
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
    [self.samples removeAllObjects];
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
    CGFloat centerY = height * 0.5;
    CGFloat maxAmplitude = height * kPPWaveformMaxVisual;

    UIColor *inactiveColor;
    UIColor *activeColor;
    UIColor *accentColor;

    switch (self.visualState) {
        case PPWaveformVisualStateRecording:
        case PPWaveformVisualStateLocked:
            inactiveColor = AppLightGrayColor;
            activeColor   = AppPrimaryClr;
            accentColor   = [AppPrimaryClr colorWithAlphaComponent:1.4];
            break;

        case PPWaveformVisualStatePreview:
            inactiveColor = [AppPrimaryClrDarker colorWithAlphaComponent:0.12];
            activeColor   = AppPrimaryClr;
            accentColor   = PPBlendColors(activeColor, AppPrimaryClrDarker, 0.18);
            break;
    }

    BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection ==
                  UIUserInterfaceLayoutDirectionRightToLeft);

    CGFloat barWidth = (width - (kPPWaveformBarSpacing * (kPPWaveformBarCount - 1)))
                       / kPPWaveformBarCount;
    CGFloat cornerRadius = barWidth * 0.5;

    NSInteger offset = kPPWaveformBarCount - self.samples.count;
    CGFloat playhead = self.playbackProgress * (kPPWaveformBarCount - 1);

    for (NSInteger i = 0; i < kPPWaveformBarCount; i++) {

        float level;
        if (i < offset) {
            level = (self.visualState == PPWaveformVisualStateRecording)
            ? kPPWaveformIdleLevel : 0;
        } else {
            level = self.samples[i - offset].floatValue;
        }

        if (level <= 0) continue;

        CGFloat halfHeight = MAX(level * maxAmplitude, 1.5);

        NSInteger visualIndex = isRTL ? i : (kPPWaveformBarCount - 1 - i);
        CGFloat x = visualIndex * (barWidth + kPPWaveformBarSpacing);

        UIColor *color = inactiveColor;

        if (self.isFrozen && i <= playhead) {
            color = activeColor;

            CGFloat distance = fabs(i - playhead);
            if (distance < 2.0) {
                CGFloat t = 1.0 - (distance / 2.0);
                color = PPBlendColors(activeColor, accentColor, t);
            }
        }

        CGRect barRect = CGRectMake(x,
                                    centerY - halfHeight,
                                    barWidth,
                                    halfHeight * 2);

        UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:barRect
                                   cornerRadius:cornerRadius];

        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextAddPath(ctx, path.CGPath);
        CGContextFillPath(ctx);
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
