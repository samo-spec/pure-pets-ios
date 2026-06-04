//
//  PPAuthStepIndicatorView.m
//  Pure Pets
//

#import "PPAuthStepIndicatorView.h"
#import "Language.h"

static NSString * const PPAuthStepDotMotionKey = @"pp_auth_step_dot_breath";
static NSString * const PPAuthStepHaloScaleKey = @"pp_auth_step_halo_scale";
static NSString * const PPAuthStepHaloOpacityKey = @"pp_auth_step_halo_opacity";
static NSString * const PPAuthStepIconMotionKey = @"pp_auth_step_icon_breath";
static NSString * const PPAuthStepLabelFloatKey = @"pp_auth_step_label_float";
static NSString * const PPAuthStepLabelOpacityKey = @"pp_auth_step_label_opacity";

@interface PPAuthStepIndicatorView ()
@property (nonatomic, copy) NSArray<NSString *> *stepTitles;
@property (nonatomic, strong) NSMutableArray<UIView *> *haloViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *dotViews;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *iconViews;
@property (nonatomic, strong) NSMutableArray<UILabel *> *labelViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *connectorViews;
@property (nonatomic, assign) NSInteger currentStepIndex;
@property (nonatomic, assign) NSInteger completedStepIndex;
@end

@implementation PPAuthStepIndicatorView

- (instancetype)initWithStepTitles:(NSArray<NSString *> *)stepTitles {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _stepTitles = [stepTitles copy] ?: @[];
        _currentStepIndex = 0;
        _completedStepIndex = -1;
        _haloViews = [NSMutableArray array];
        _dotViews = [NSMutableArray array];
        _iconViews = [NSMutableArray array];
        _labelViews = [NSMutableArray array];
        _connectorViews = [NSMutableArray array];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = UIColor.clearColor;
        self.clipsToBounds = NO;
        [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_applicationDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_reduceMotionStatusDidChange)
                                                     name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                                   object:nil];
        [self pp_rebuildViews];
        [self updateCurrentStepIndex:0 completedStepIndex:-1 animated:NO];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, 64.0);
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) {
        [self pp_stopCurrentStepMotion];
        return;
    }
    [self setNeedsLayout];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self restartCurrentStepMotionIfNeeded];
    });
}

- (void)restartCurrentStepMotionIfNeeded {
    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)stopCurrentStepMotion {
    [self pp_stopCurrentStepMotion];
}

- (void)pp_applicationDidBecomeActive {
    [self restartCurrentStepMotionIfNeeded];
}

- (void)pp_reduceMotionStatusDidChange {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopCurrentStepMotion];
        return;
    }
    [self restartCurrentStepMotionIfNeeded];
}

- (void)pp_rebuildViews {
    for (UIView *view in self.haloViews) [view removeFromSuperview];
    for (UIView *view in self.dotViews) [view removeFromSuperview];
    for (UIImageView *view in self.iconViews) [view removeFromSuperview];
    for (UILabel *view in self.labelViews) [view removeFromSuperview];
    for (UIView *view in self.connectorViews) [view removeFromSuperview];
    [self.haloViews removeAllObjects];
    [self.dotViews removeAllObjects];
    [self.iconViews removeAllObjects];
    [self.labelViews removeAllObjects];
    [self.connectorViews removeAllObjects];

    for (NSString *title in self.stepTitles) {
        UIView *halo = [[UIView alloc] initWithFrame:CGRectZero];
        halo.hidden = YES;
        halo.layer.masksToBounds = NO;
        [self addSubview:halo];
        [self.haloViews addObject:halo];

        UIView *dot = [[UIView alloc] initWithFrame:CGRectZero];
        dot.layer.masksToBounds = YES;
        dot.layer.borderWidth = 1.0;
        [self addSubview:dot];
        [self.dotViews addObject:dot];

        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        if (@available(iOS 13.0, *)) {
            icon.preferredSymbolConfiguration =
            [UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium];
        }
        [dot addSubview:icon];
        [self.iconViews addObject:icon];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = title ?: @"";
        label.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.72;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:label];
        [self.labelViews addObject:label];
    }

    for (NSInteger index = 0; index < MAX(0, (NSInteger)self.stepTitles.count - 1); index++) {
        UIView *connector = [[UIView alloc] initWithFrame:CGRectZero];
        connector.layer.cornerRadius = 1.0;
        connector.layer.masksToBounds = YES;
        [self insertSubview:connector atIndex:0];
        [self.connectorViews addObject:connector];
    }
}

- (void)updateCurrentStepIndex:(NSInteger)currentStepIndex
            completedStepIndex:(NSInteger)completedStepIndex
                       animated:(BOOL)animated {
    NSInteger maxIndex = MAX(0, (NSInteger)self.stepTitles.count - 1);
    self.currentStepIndex = MAX(0, MIN(currentStepIndex, maxIndex));
    self.completedStepIndex = completedStepIndex;
    [self pp_stopCurrentStepMotion];

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        [self setNeedsLayout];
        return;
    }

    [UIView animateWithDuration:0.38
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    } completion:nil];
}

- (NSInteger)pp_visualIndexForLogicalIndex:(NSInteger)logicalIndex {
    if ([Language isRTL]) {
        return MAX(0, (NSInteger)self.stepTitles.count - 1 - logicalIndex);
    }
    return logicalIndex;
}

- (CGFloat)pp_centerXForVisualIndex:(NSInteger)visualIndex {
    NSInteger count = self.stepTitles.count;
    CGFloat maxDotSize = 32.0;
    CGFloat sideInset = 12.0;
    CGFloat minCenter = sideInset + (maxDotSize * 0.5);
    CGFloat maxCenter = MAX(minCenter, CGRectGetWidth(self.bounds) - sideInset - (maxDotSize * 0.5));
    if (count <= 1) return (minCenter + maxCenter) * 0.5;
    CGFloat progress = (CGFloat)visualIndex / (CGFloat)(count - 1);
    return minCenter + ((maxCenter - minCenter) * progress);
}

- (void)layoutSubviews {
    [super layoutSubviews];

    NSInteger count = self.stepTitles.count;
    if (count <= 0) return;

    UIColor *accentColor = AppPrimaryClr ?: [GM appPrimaryColor];
    UIColor *pendingColor = [UIColor tertiarySystemFillColor];
    UIColor *pendingBorder = [UIColor quaternaryLabelColor];
    CGFloat maxDotSize = 32.0;
    CGFloat doneDotSize = 26.0;
    CGFloat pendingDotSize = 24.0;
    CGFloat dotY = 4.0;
    CGFloat labelTop = dotY + maxDotSize + 9.0;
    CGFloat labelHeight = MAX(22.0, CGRectGetHeight(self.bounds) - labelTop);
    BOOL shouldAnimate = (self.window != nil && !UIAccessibilityIsReduceMotionEnabled());

    NSMutableArray<NSNumber *> *centersX = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *dotSizes = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *visualCenters = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger index = 0; index < count; index++) {
        [visualCenters addObject:@0.0];
        [dotSizes addObject:@(pendingDotSize)];
    }
    for (NSInteger index = 0; index < count; index++) {
        NSInteger visualIndex = [self pp_visualIndexForLogicalIndex:index];
        visualCenters[visualIndex] = @([self pp_centerXForVisualIndex:visualIndex]);
    }

    for (NSInteger index = 0; index < count; index++) {
        NSInteger visualIndex = [self pp_visualIndexForLogicalIndex:index];
        CGFloat centerX = [self pp_centerXForVisualIndex:visualIndex];
        [centersX addObject:@(centerX)];

        UIView *halo = self.haloViews[index];
        UIView *dot = self.dotViews[index];
        UIImageView *icon = self.iconViews[index];
        UILabel *label = self.labelViews[index];
        BOOL completed = (index <= self.completedStepIndex);
        BOOL current = (index == self.currentStepIndex);
        BOOL pending = (!completed && !current);
        CGFloat dotSize = current ? maxDotSize : (completed ? doneDotSize : pendingDotSize);
        CGFloat dotOriginY = dotY + ((maxDotSize - dotSize) * 0.5);
        dotSizes[index] = @(dotSize);

        CGFloat leftBoundary = (visualIndex == 0) ? 0.0 : (([visualCenters[visualIndex - 1] doubleValue] + centerX) * 0.5);
        CGFloat rightBoundary = (visualIndex == count - 1) ? CGRectGetWidth(self.bounds) : ((centerX + [visualCenters[visualIndex + 1] doubleValue]) * 0.5);
        CGFloat labelX = leftBoundary + 3.0;
        CGFloat labelWidth = MAX(32.0, rightBoundary - leftBoundary - 6.0);
        label.frame = CGRectMake(labelX, labelTop, labelWidth, labelHeight);

        dot.frame = CGRectMake(centerX - (dotSize * 0.5), dotOriginY, dotSize, dotSize);
        dot.layer.cornerRadius = dotSize * 0.5;
        dot.layer.borderWidth = current ? 1.4 : 1.0;
        icon.frame = CGRectInset(dot.bounds, current ? 7.0 : 5.0, current ? 7.0 : 5.0);

        [self pp_removeMotionFromDot:dot halo:halo icon:icon label:label];
        halo.hidden = !current;
        halo.frame = CGRectZero;

        if (completed) {
            dot.backgroundColor = accentColor;
            [dot pp_setBorderColor:accentColor];
            icon.image = [UIImage systemImageNamed:@"checkmark"];
            icon.tintColor = UIColor.whiteColor;
            label.textColor = accentColor;
            label.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
            label.alpha = 0.92;
        } else if (current) {
            dot.backgroundColor = accentColor;
            [dot pp_setBorderColor:accentColor];
            icon.image = [UIImage systemImageNamed:@"smallcircle.filled.circle.fill"];
            icon.tintColor = UIColor.whiteColor;
            label.textColor = accentColor;
            label.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
            label.alpha = 1.0;

            CGFloat haloSize = dotSize + 14.0;
            halo.frame = CGRectMake(centerX - (haloSize * 0.5),
                                    dotOriginY - ((haloSize - dotSize) * 0.5),
                                    haloSize,
                                    haloSize);
            halo.layer.cornerRadius = haloSize * 0.5;
            halo.backgroundColor = [accentColor colorWithAlphaComponent:0.16];
            halo.layer.borderWidth = 1.2;
            [halo pp_setBorderColor:[accentColor colorWithAlphaComponent:0.24]];
            halo.layer.shadowColor = accentColor.CGColor;
            halo.layer.shadowOpacity = shouldAnimate ? 0.18 : 0.08;
            halo.layer.shadowRadius = shouldAnimate ? 9.0 : 4.0;
            halo.layer.shadowOffset = CGSizeZero;
            halo.hidden = NO;

            if (shouldAnimate) {
                [self pp_applyCurrentMotionToDot:dot halo:halo icon:icon label:label];
            }
        } else if (pending) {
            dot.backgroundColor = pendingColor;
            [dot pp_setBorderColor:pendingBorder];
            icon.image = nil;
            label.textColor = UIColor.secondaryLabelColor;
            label.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
            label.alpha = 0.58;
        }
    }

    for (NSInteger index = 0; index < self.connectorViews.count; index++) {
        UIView *connector = self.connectorViews[index];
        CGFloat leftCenter = [centersX[index] doubleValue];
        CGFloat rightCenter = [centersX[index + 1] doubleValue];
        CGFloat leftDotSize = [dotSizes[index] doubleValue];
        CGFloat rightDotSize = [dotSizes[index + 1] doubleValue];
        CGFloat minX = MIN(leftCenter, rightCenter) + (leftDotSize * 0.5) + 5.0;
        CGFloat maxX = MAX(leftCenter, rightCenter) - (rightDotSize * 0.5) - 5.0;
        connector.frame = CGRectMake(minX,
                                     dotY + (maxDotSize * 0.5) - 1.0,
                                     MAX(0.0, maxX - minX),
                                     2.0);
        BOOL progressed = (index < self.currentStepIndex || index <= self.completedStepIndex);
        connector.backgroundColor = progressed ? accentColor : [UIColor quaternarySystemFillColor];
    }
}

- (void)pp_stopCurrentStepMotion {
    NSInteger count = MIN(self.dotViews.count, self.haloViews.count);
    for (NSInteger index = 0; index < count; index++) {
        UIImageView *icon = index < self.iconViews.count ? self.iconViews[index] : nil;
        UILabel *label = index < self.labelViews.count ? self.labelViews[index] : nil;
        [self pp_removeMotionFromDot:self.dotViews[index]
                                halo:self.haloViews[index]
                                icon:icon
                               label:label];
    }
}

- (void)pp_removeMotionFromDot:(UIView *)dot halo:(UIView *)halo icon:(UIImageView *)icon label:(UILabel *)label {
    [dot.layer removeAnimationForKey:PPAuthStepDotMotionKey];
    [halo.layer removeAnimationForKey:PPAuthStepHaloScaleKey];
    [halo.layer removeAnimationForKey:PPAuthStepHaloOpacityKey];
    [icon.layer removeAnimationForKey:PPAuthStepIconMotionKey];
    [label.layer removeAnimationForKey:PPAuthStepLabelFloatKey];
    [label.layer removeAnimationForKey:PPAuthStepLabelOpacityKey];
}

- (void)pp_applyScalePulseToLayer:(CALayer *)layer key:(NSString *)key from:(CGFloat)fromScale to:(CGFloat)toScale duration:(CFTimeInterval)duration delay:(CFTimeInterval)delay {
    if (!layer || [layer animationForKey:key]) return;
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation.fromValue = @(fromScale);
    animation.toValue = @(toScale);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.beginTime = CACurrentMediaTime() + delay;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:animation forKey:key];
}

- (void)pp_applyOpacityPulseToLayer:(CALayer *)layer key:(NSString *)key from:(CGFloat)fromValue to:(CGFloat)toValue duration:(CFTimeInterval)duration delay:(CFTimeInterval)delay {
    if (!layer || [layer animationForKey:key]) return;
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(fromValue);
    animation.toValue = @(toValue);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.beginTime = CACurrentMediaTime() + delay;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:animation forKey:key];
}

- (void)pp_applyCurrentMotionToDot:(UIView *)dot halo:(UIView *)halo icon:(UIImageView *)icon label:(UILabel *)label {
    [self pp_applyScalePulseToLayer:dot.layer key:PPAuthStepDotMotionKey from:1.0 to:1.055 duration:1.85 delay:0.0];
    [self pp_applyScalePulseToLayer:halo.layer key:PPAuthStepHaloScaleKey from:1.0 to:1.16 duration:2.65 delay:0.08];
    [self pp_applyOpacityPulseToLayer:halo.layer key:PPAuthStepHaloOpacityKey from:0.42 to:0.86 duration:2.65 delay:0.08];
    [self pp_applyScalePulseToLayer:icon.layer key:PPAuthStepIconMotionKey from:1.0 to:1.08 duration:1.85 delay:0.18];

    if (![label.layer animationForKey:PPAuthStepLabelFloatKey]) {
        CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.fromValue = @(0.0);
        floatAnimation.toValue = @(-1.2);
        floatAnimation.duration = 2.1;
        floatAnimation.autoreverses = YES;
        floatAnimation.repeatCount = HUGE_VALF;
        floatAnimation.beginTime = CACurrentMediaTime() + 0.16;
        floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [label.layer addAnimation:floatAnimation forKey:PPAuthStepLabelFloatKey];
    }
    [self pp_applyOpacityPulseToLayer:label.layer key:PPAuthStepLabelOpacityKey from:0.82 to:1.0 duration:2.1 delay:0.16];
}

@end
