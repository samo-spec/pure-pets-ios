//
//  PPRecordingWaveformView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/01/2026.
//

#import "PPRecordingWaveformView.h"
@implementation PPRecordingWaveformView {
    NSMutableArray<NSNumber *> *_levels;
}

- (instancetype)init {
    if (self = [super init]) {
        _levels = [NSMutableArray array];
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)addSample:(float)level {
    [_levels addObject:@(level)];
    if (_levels.count > 40) [_levels removeObjectAtIndex:0];
    [self setNeedsDisplay];
}

- (void)reset {
    [_levels removeAllObjects];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat midY = CGRectGetMidY(rect);

    CGFloat barWidth = 3;
    CGFloat spacing = 2;
    CGFloat x = 0;

    for (NSNumber *n in _levels) {
        CGFloat h = MAX(n.floatValue * rect.size.height * 0.9, 2);
        CGRect r = CGRectMake(x, midY - h/2, barWidth, h);
        CGContextSetFillColorWithColor(ctx, self.barColor.CGColor);
        CGContextFillRect(ctx, r);
        x += barWidth + spacing;
    }
}
@end
