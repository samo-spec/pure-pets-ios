//
//  PPPlaybackWaveformView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//

 #import "PPPlaybackWaveformView.h"

@implementation PPPlaybackWaveformView {
    NSArray<NSNumber *> *_samples;
    CGFloat _progress;
    NSMutableArray<NSNumber *> *_smoothedSamples;
}

- (instancetype)init {
    if (self = [super init]) {
        self.backgroundColor = UIColor.clearColor;
        _progress = 0;
        _smoothedSamples = [NSMutableArray array];
    }
    return self;
}

- (void)setSamples:(NSArray<NSNumber *> *)samples {
    _samples = [samples copy];

    [_smoothedSamples removeAllObjects];
    if (_samples.count > 0) {
        for (NSInteger i = 0; i < _samples.count; i++) {
            [_smoothedSamples addObject:@(_samples[i].floatValue)];
        }
    }

    [self setNeedsDisplay];
}

- (void)setPlaybackProgress:(CGFloat)progress {
    _progress = MIN(MAX(progress, 0), 1);
    [self setNeedsDisplay];
}

- (void)reset {
    _samples = nil;
    _progress = 0;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    if (_samples.count == 0) return;

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextClearRect(ctx, rect);

    CGFloat midY = CGRectGetMidY(rect);
    CGFloat height = rect.size.height;

    CGFloat totalWidth = rect.size.width;
    NSInteger count = _samples.count;
    if (count == 0) return;

    CGFloat step = totalWidth / count;
    CGFloat barWidth = step * 0.55;

    NSInteger playedCount = (NSInteger)round(count * _progress);

    // Cap visual height (WhatsApp-like)
    CGFloat maxAmplitude = height * 0.75;

    for (NSInteger i = 0; i < count; i++) {
        // Smooth interpolation between frames (plane-like motion)
        CGFloat target = _samples[i].floatValue;
        CGFloat current = (_smoothedSamples.count > i)
            ? _smoothedSamples[i].floatValue
            : target;

        // EMA smoothing (prevents ticking)
        CGFloat alpha = 0.25; // lower = smoother
        CGFloat smoothed = current + (target - current) * alpha;

        if (_smoothedSamples.count > i) {
            _smoothedSamples[i] = @(smoothed);
        }

        CGFloat level = smoothed;

        // Safety clamp
        level = fminf(fmaxf(level, 0.0f), 1.0f);

        CGFloat h = MAX(level * maxAmplitude, 2.0);

        CGRect barRect = CGRectMake(
            i * step + (step - barWidth) / 2.0,
            midY - h / 2.0,
            barWidth,
            h
        );

        UIColor *color =
            (i <= playedCount) ? self.activeColor : self.inactiveColor;

        UIBezierPath *path =
            [UIBezierPath bezierPathWithRoundedRect:barRect
                                        cornerRadius:barRect.size.width / 2.0];

        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextAddPath(ctx, path.CGPath);
        CGContextFillPath(ctx);
    }
}

+ (NSArray<NSNumber *> *)idleSamples
{
    static NSArray<NSNumber *> *samples;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *arr = [NSMutableArray array];
        // Flat, calm baseline (WhatsApp-like)
        for (NSInteger i = 0; i < 40; i++) {
            [arr addObject:@(0.02)];
        }
        samples = [arr copy];
    });
    return samples;
}
@end
