//
//  PPOrderStatusStepperView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import "PPOrderStatusStepperView.h"
#import "OrderSupportFunc.h"


@interface PPOrderStatusStepperView ()

@property (nonatomic, copy) NSArray<NSString *> *steps;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL showsFailure;
@property (nonatomic, strong, nullable) UIColor *progressTintColor;
@property (nonatomic, strong) NSMutableArray<UIView *> *haloViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *dotViews;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *iconViews;
@property (nonatomic, strong) NSMutableArray<UILabel *> *labelViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *connectorViews;

@end



@implementation PPOrderStatusStepperView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _steps = @[];
        _currentIndex = 0;
        _showsFailure = NO;
        _haloViews = [NSMutableArray array];
        _dotViews = [NSMutableArray array];
        _iconViews = [NSMutableArray array];
        _labelViews = [NSMutableArray array];
        _connectorViews = [NSMutableArray array];
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)configureWithSteps:(NSArray<NSString *> *)steps
              currentIndex:(NSInteger)currentIndex
              showsFailure:(BOOL)showsFailure
                 tintColor:(UIColor *)tintColor
{
    self.steps = [steps isKindOfClass:NSArray.class] ? steps : @[];
    if (self.steps.count == 0) {
        self.currentIndex = 0;
    } else {
        self.currentIndex = MAX(0, MIN(currentIndex, (NSInteger)self.steps.count - 1));
    }
    self.showsFailure = showsFailure;
    self.progressTintColor = tintColor;
    [self rebuildViews];
    [self setNeedsLayout];
}

- (void)rebuildViews
{
    for (UIView *view in self.dotViews) {
        [view removeFromSuperview];
    }
    for (UIView *view in self.haloViews) {
        [view removeFromSuperview];
    }
    for (UIImageView *view in self.iconViews) {
        [view removeFromSuperview];
    }
    for (UILabel *view in self.labelViews) {
        [view removeFromSuperview];
    }
    for (UIView *view in self.connectorViews) {
        [view removeFromSuperview];
    }
    [self.haloViews removeAllObjects];
    [self.dotViews removeAllObjects];
    [self.iconViews removeAllObjects];
    [self.labelViews removeAllObjects];
    [self.connectorViews removeAllObjects];

    NSInteger count = self.steps.count;
    if (count <= 0) return;

    for (NSInteger i = 0; i < count; i++) {
        UIView *halo = [[UIView alloc] initWithFrame:CGRectZero];
        halo.layer.cornerRadius = 18.0;
        halo.layer.masksToBounds = NO;
        halo.hidden = YES;
        [self addSubview:halo];
        [self.haloViews addObject:halo];

        UIView *dot = [[UIView alloc] initWithFrame:CGRectZero];
        dot.layer.cornerRadius = 11.0;
        dot.layer.masksToBounds = YES;
        dot.layer.borderWidth = 1.0;
        [self addSubview:dot];
        [self.dotViews addObject:dot];

        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        if (@available(iOS 13.0, *)) {
            icon.preferredSymbolConfiguration =
            [UIImageSymbolConfiguration configurationWithPointSize:11
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        }
        [dot addSubview:icon];
        [self.iconViews addObject:icon];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = self.steps[i];
        label.font = [GM MidFontWithSize:11];
        label.textColor = UIColor.secondaryLabelColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 1;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.72;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:label];
        [self.labelViews addObject:label];
    }

    for (NSInteger i = 0; i < MAX(0, count - 1); i++) {
        UIView *connector = [[UIView alloc] initWithFrame:CGRectZero];
        connector.layer.cornerRadius = 1.0;
        connector.layer.masksToBounds = YES;
        [self insertSubview:connector atIndex:0];
        [self.connectorViews addObject:connector];
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window) {
        [self stopCurrentStatusMotion];
        return;
    }

    [self setNeedsLayout];
}

- (NSInteger)visualIndexForLogicalIndex:(NSInteger)logicalIndex
{
    if ([Language languageVal] == 1) {
        return MAX(0, (NSInteger)self.steps.count - 1 - logicalIndex);
    }
    return logicalIndex;
}

- (CGFloat)centerXForVisualIndex:(NSInteger)visualIndex
{
    NSInteger count = self.steps.count;
    if (count <= 0) return 0.0;

    CGFloat maxDotSize = 30.0;
    CGFloat leadingInset = 8.0;
    CGFloat trailingInset = 8.0;
    CGFloat minCenter = leadingInset + (maxDotSize * 0.5);
    CGFloat maxCenter = MAX(minCenter, self.bounds.size.width - trailingInset - (maxDotSize * 0.5));
    if (count == 1) return (minCenter + maxCenter) * 0.5;

    CGFloat progress = (CGFloat)visualIndex / (CGFloat)(count - 1);
    return minCenter + ((maxCenter - minCenter) * progress);
}

- (BOOL)shouldRunCurrentStatusMotion
{
    return (self.window != nil && !UIAccessibilityIsReduceMotionEnabled());
}

- (void)removeCurrentStatusMotionFromDot:(UIView *)dot
                                    halo:(UIView *)halo
                                    icon:(UIImageView *)icon
                                   label:(UILabel *)label
{
    NSArray<NSString *> *dotKeys = @[PPOrderStepperCurrentDotMotionKey, PPOrderStepperLegacyDotPulseKey];
    for (NSString *key in dotKeys) {
        [dot.layer removeAnimationForKey:key];
    }

    NSArray<NSString *> *haloKeys = @[
        PPOrderStepperCurrentHaloScaleKey,
        PPOrderStepperCurrentHaloOpacityKey,
        PPOrderStepperLegacyHaloScaleKey,
        PPOrderStepperLegacyHaloOpacityKey
    ];
    for (NSString *key in haloKeys) {
        [halo.layer removeAnimationForKey:key];
    }

    [icon.layer removeAnimationForKey:PPOrderStepperCurrentIconMotionKey];
    [label.layer removeAnimationForKey:PPOrderStepperCurrentLabelFloatKey];
    [label.layer removeAnimationForKey:PPOrderStepperCurrentLabelOpacityKey];
}

- (void)stopCurrentStatusMotion
{
    NSInteger count = MIN(self.dotViews.count, self.haloViews.count);
    for (NSInteger index = 0; index < count; index++) {
        UIImageView *icon = (index < self.iconViews.count) ? self.iconViews[index] : nil;
        UILabel *label = (index < self.labelViews.count) ? self.labelViews[index] : nil;
        [self removeCurrentStatusMotionFromDot:self.dotViews[index]
                                          halo:self.haloViews[index]
                                          icon:icon
                                         label:label];
    }
}

- (void)applyScalePulseToLayer:(CALayer *)layer
                           key:(NSString *)key
                     fromScale:(CGFloat)fromScale
                       toScale:(CGFloat)toScale
                      duration:(CFTimeInterval)duration
                    beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    anim.fromValue = @(fromScale);
    anim.toValue = @(toScale);
    anim.duration = duration;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:anim forKey:key];
}

- (void)applyOpacityPulseToLayer:(CALayer *)layer
                             key:(NSString *)key
                            from:(CGFloat)fromValue
                              to:(CGFloat)toValue
                        duration:(CFTimeInterval)duration
                      beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.fromValue = @(fromValue);
    anim.toValue = @(toValue);
    anim.duration = duration;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:anim forKey:key];
}

- (void)applyVerticalFloatToLayer:(CALayer *)layer
                              key:(NSString *)key
                         distance:(CGFloat)distance
                         duration:(CFTimeInterval)duration
                       beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    anim.fromValue = @(0.0);
    anim.toValue = @(-fabs(distance));
    anim.duration = duration;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:anim forKey:key];
}

- (void)applyCurrentStatusMotionToDot:(UIView *)dot
                                  halo:(UIView *)halo
                                  icon:(UIImageView *)icon
                                 label:(UILabel *)label
                            errorState:(BOOL)isError
{
    if (![self shouldRunCurrentStatusMotion]) return;

    [self applyScalePulseToLayer:dot.layer
                             key:PPOrderStepperCurrentDotMotionKey
                       fromScale:1.0
                         toScale:1.055
                        duration:1.85
                      beginDelay:0.0];

    [self applyScalePulseToLayer:halo.layer
                             key:PPOrderStepperCurrentHaloScaleKey
                       fromScale:1.0
                         toScale:(isError ? 1.12 : 1.16)
                        duration:2.65
                      beginDelay:0.08];
    [self applyOpacityPulseToLayer:halo.layer
                               key:PPOrderStepperCurrentHaloOpacityKey
                              from:0.42
                                to:(isError ? 0.78 : 0.86)
                          duration:2.65
                        beginDelay:0.08];

    [self applyScalePulseToLayer:icon.layer
                             key:PPOrderStepperCurrentIconMotionKey
                       fromScale:1.0
                         toScale:1.08
                        duration:1.85
                      beginDelay:0.18];

    [self applyVerticalFloatToLayer:label.layer
                                key:PPOrderStepperCurrentLabelFloatKey
                           distance:1.2
                           duration:2.1
                         beginDelay:0.16];
    [self applyOpacityPulseToLayer:label.layer
                               key:PPOrderStepperCurrentLabelOpacityKey
                              from:0.82
                                to:1.0
                          duration:2.1
                        beginDelay:0.16];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    NSInteger count = self.steps.count;
    if (count <= 0) return;

    UIColor *accentColor = self.progressTintColor ?: [GM appPrimaryColor];
    UIColor *pendingColor = [UIColor tertiarySystemFillColor];
    UIColor *pendingBorder = [UIColor quaternaryLabelColor];
    UIColor *errorColor = UIColor.systemRedColor;

    CGFloat maxDotSize = 30.0;
    CGFloat completedDotSize = 24.0;
    CGFloat pendingDotSize = 22.0;
    CGFloat dotY = 10.0;
    CGFloat labelTop = dotY + maxDotSize + 14.0;
    CGFloat labelHeight = 28.0;
    BOOL shouldAnimateCurrentStatus = [self shouldRunCurrentStatusMotion];

    NSMutableArray<NSNumber *> *centersX = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *dotSizes = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *visualCenters = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        [visualCenters addObject:@0.0];
        [dotSizes addObject:@(pendingDotSize)];
    }

    for (NSInteger i = 0; i < count; i++) {
        NSInteger visualIndex = [self visualIndexForLogicalIndex:i];
        CGFloat centerX = [self centerXForVisualIndex:visualIndex];
        visualCenters[visualIndex] = @(centerX);
    }

    BOOL hasNextStep = (!self.showsFailure && self.currentIndex < (count - 1));

    for (NSInteger i = 0; i < count; i++) {
        NSInteger visualIndex = [self visualIndexForLogicalIndex:i];
        CGFloat centerX = [self centerXForVisualIndex:visualIndex];
        [centersX addObject:@(centerX)];

        UIView *dot = self.dotViews[i];
        UIView *halo = self.haloViews[i];
        UIImageView *icon = self.iconViews[i];
        UILabel *label = self.labelViews[i];
        NSString *baseSymbol = PPOrderStepperSymbolForTitle(self.steps[i], i);

        CGFloat leftBoundary = (visualIndex == 0)
        ? 0.0
        : (([visualCenters[visualIndex - 1] doubleValue] + centerX) * 0.5);
        CGFloat rightBoundary = (visualIndex == (count - 1))
        ? self.bounds.size.width
        : ((centerX + [visualCenters[visualIndex + 1] doubleValue]) * 0.5);
        CGFloat labelInset = 4.0;
        CGFloat labelX = MAX(0.0, leftBoundary + labelInset);
        CGFloat labelWidth = MAX(28.0, rightBoundary - leftBoundary - (labelInset * 2.0));
        label.frame = CGRectMake(labelX, labelTop, labelWidth, labelHeight);

        BOOL isCompleted = (i < self.currentIndex);
        BOOL isCurrent = (i == self.currentIndex);
        BOOL isPending = (i > self.currentIndex);
        BOOL isError = (self.showsFailure && isCurrent);
        CGFloat dotSize = (isCurrent || isError) ? maxDotSize : (isCompleted ? completedDotSize : pendingDotSize);
        CGFloat dotOriginY = dotY + ((maxDotSize - dotSize) * 0.5);
        dotSizes[i] = @(dotSize);

        dot.frame = CGRectMake(centerX - (dotSize * 0.5), dotOriginY, dotSize, dotSize);
        dot.layer.cornerRadius = dotSize * 0.5;
        dot.layer.borderWidth = (isCurrent || isError) ? 1.4 : 1.0;
        CGFloat iconInset = (isCurrent || isError) ? 6.0 : 4.5;
        icon.frame = CGRectInset(dot.bounds, iconInset, iconInset);

        BOOL isActiveStatus = (isCurrent || isError);
        BOOL shouldKeepCurrentMotion = (isActiveStatus && shouldAnimateCurrentStatus);
        if (shouldKeepCurrentMotion) {
            [dot.layer removeAnimationForKey:PPOrderStepperLegacyDotPulseKey];
            [halo.layer removeAnimationForKey:PPOrderStepperLegacyHaloScaleKey];
            [halo.layer removeAnimationForKey:PPOrderStepperLegacyHaloOpacityKey];
        } else {
            [self removeCurrentStatusMotionFromDot:dot halo:halo icon:icon label:label];
        }
        halo.hidden = !(isCurrent || isError);
        halo.frame = CGRectZero;
        halo.layer.shadowOpacity = 0.0;
        halo.layer.shadowRadius = 0.0;
        halo.layer.shadowOffset = CGSizeZero;

        if (isError) {
            dot.backgroundColor = errorColor;
            [dot pp_setBorderColor:errorColor];
            icon.image = PPOrderStepperImage(@"xmark");
            icon.tintColor = UIColor.whiteColor;
            label.textColor = errorColor;
            label.font = [GM boldFontWithSize:12];
        } else if (isCompleted) {
            dot.backgroundColor = accentColor;
            [dot pp_setBorderColor:accentColor];
            icon.image = PPOrderStepperImage(baseSymbol.length > 0 ? baseSymbol : @"checkmark");
            icon.tintColor = UIColor.whiteColor;
            label.textColor = accentColor;
            label.font = [GM MidFontWithSize:11];
        } else if (isCurrent) {
            dot.backgroundColor = accentColor;
            [dot pp_setBorderColor:accentColor];
            icon.image = PPOrderStepperImage(baseSymbol.length > 0 ? baseSymbol : @"smallcircle.filled.circle.fill");
            icon.tintColor = UIColor.whiteColor;
            label.textColor = accentColor;
            label.font = [GM boldFontWithSize:12];
        } else if (isPending) {
            dot.backgroundColor = pendingColor;
            [dot pp_setBorderColor:pendingBorder];
            icon.image = PPOrderStepperImage(baseSymbol.length > 0 ? baseSymbol : @"circle");
            icon.tintColor = UIColor.secondaryLabelColor;
            label.textColor = UIColor.secondaryLabelColor;
            label.font = [GM MidFontWithSize:11];
        }

        if (isCurrent || isError) {
            UIColor *haloColor = isError ? errorColor : accentColor;
            CGFloat haloSize = dotSize + 14.0;
            halo.frame = CGRectMake(centerX - (haloSize * 0.5),
                                    dotOriginY - ((haloSize - dotSize) * 0.5),
                                    haloSize,
                                    haloSize);
            halo.layer.cornerRadius = haloSize * 0.5;
            halo.backgroundColor = [haloColor colorWithAlphaComponent:isError ? 0.14 : 0.18];
            halo.layer.borderWidth = 1.2;
            [halo pp_setBorderColor:[haloColor colorWithAlphaComponent:0.28]];
            halo.layer.shadowColor = haloColor.CGColor;
            halo.layer.shadowOpacity = shouldAnimateCurrentStatus ? (isError ? 0.16 : 0.18) : 0.08;
            halo.layer.shadowRadius = shouldAnimateCurrentStatus ? 9.0 : 4.0;
            halo.layer.shadowOffset = CGSizeZero;
            halo.hidden = NO;
            [self applyCurrentStatusMotionToDot:dot
                                           halo:halo
                                           icon:icon
                                          label:label
                                     errorState:isError];
        }
        icon.hidden = (icon.image == nil);
    }

    for (NSInteger i = 0; i < self.connectorViews.count; i++) {
        UIView *connector = self.connectorViews[i];
        CGFloat leftCenter = [centersX[i] doubleValue];
        CGFloat rightCenter = [centersX[i + 1] doubleValue];
        CGFloat leftDotSize = [dotSizes[i] doubleValue];
        CGFloat rightDotSize = [dotSizes[i + 1] doubleValue];
        CGFloat minX = MIN(leftCenter, rightCenter) + (leftDotSize * 0.5) + 5.0;
        CGFloat maxX = MAX(leftCenter, rightCenter) - (rightDotSize * 0.5) - 5.0;
        connector.frame = CGRectMake(minX, dotY + (maxDotSize * 0.5) - 1.0, MAX(0.0, maxX - minX), 2.0);
        [connector.layer removeAnimationForKey:@"pp_stepper_connector_pulse"];

        BOOL isCompletedConnector = (i < self.currentIndex);
        BOOL isCurrentConnector = (!self.showsFailure && i == self.currentIndex && hasNextStep);
        if (self.showsFailure && i == (self.currentIndex - 1)) {
            connector.backgroundColor = errorColor;
        } else if (isCurrentConnector) {
            connector.backgroundColor = [accentColor colorWithAlphaComponent:0.38];
        } else {
            connector.backgroundColor = isCompletedConnector ? accentColor : [UIColor quaternarySystemFillColor];
        }
    }
}

@end
