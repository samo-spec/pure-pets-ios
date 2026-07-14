//
//  PPOrderProgressTimelineRowView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//
#import "PPOrderProgressTimelineRowView.h"
#import "OrderSupportFunc.h"

@interface PPOrderProgressTimelineRowView ()

@property (nonatomic, strong) UIView *markerHaloView;
@property (nonatomic, strong) UIView *markerView;
@property (nonatomic, strong) UIImageView *markerIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *subtitleText;
@property (nonatomic, copy) NSString *metaText;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, assign) PPOrderProgressTimelineRowState rowState;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL isRTL;
@property (nonatomic, strong) UIColor *accentColor;

@end

@implementation PPOrderProgressTimelineRowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;

        _markerHaloView = [[UIView alloc] initWithFrame:CGRectZero];
        _markerHaloView.hidden = YES;
        [self addSubview:_markerHaloView];

        _markerView = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_markerView];

        _markerIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _markerIconView.contentMode = UIViewContentModeScaleAspectFit;
        [_markerView addSubview:_markerIconView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.numberOfLines = 2;
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.numberOfLines = 0;
        [self addSubview:_subtitleLabel];

        _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _metaLabel.numberOfLines = 1;
        [self addSubview:_metaLabel];
    }
    return self;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self refreshCurrentStatusMotion];
}

- (BOOL)pp_shouldRunCurrentStatusMotion
{
    BOOL isCurrentLike = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure);
    return (isCurrentLike && self.window != nil && !self.hidden && !UIAccessibilityIsReduceMotionEnabled());
}

- (void)pp_addScalePulseToLayer:(CALayer *)layer
                            key:(NSString *)key
                      fromScale:(CGFloat)fromScale
                        toScale:(CGFloat)toScale
                       duration:(CFTimeInterval)duration
                     beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation.fromValue = @(fromScale);
    animation.toValue = @(toScale);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_addOpacityPulseToLayer:(CALayer *)layer
                              key:(NSString *)key
                             from:(CGFloat)fromValue
                               to:(CGFloat)toValue
                         duration:(CFTimeInterval)duration
                       beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(fromValue);
    animation.toValue = @(toValue);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_addVerticalFloatToLayer:(CALayer *)layer
                               key:(NSString *)key
                          distance:(CGFloat)distance
                          duration:(CFTimeInterval)duration
                        beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    animation.fromValue = @(0.0);
    animation.toValue = @(-fabs(distance));
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_stopCurrentStatusMotion
{
    [self.markerView.layer removeAnimationForKey:PPOrderTimelineCurrentMarkerMotionKey];
    [self.markerHaloView.layer removeAnimationForKey:PPOrderTimelineCurrentHaloScaleKey];
    [self.markerHaloView.layer removeAnimationForKey:PPOrderTimelineCurrentHaloOpacityKey];
    [self.markerIconView.layer removeAnimationForKey:PPOrderTimelineCurrentIconMotionKey];
    [self.titleLabel.layer removeAnimationForKey:PPOrderTimelineCurrentTitleFloatKey];
    [self.titleLabel.layer removeAnimationForKey:PPOrderTimelineCurrentTitleOpacityKey];
}

- (void)refreshCurrentStatusMotion
{
    if (![self pp_shouldRunCurrentStatusMotion]) {
        [self pp_stopCurrentStatusMotion];
        return;
    }

    BOOL isFailure = (self.rowState == PPOrderProgressTimelineRowStateFailure);
    [self pp_addScalePulseToLayer:self.markerView.layer
                              key:PPOrderTimelineCurrentMarkerMotionKey
                        fromScale:1.0
                          toScale:1.055
                         duration:1.85
                       beginDelay:0.0];
    [self pp_addScalePulseToLayer:self.markerHaloView.layer
                              key:PPOrderTimelineCurrentHaloScaleKey
                        fromScale:1.0
                          toScale:(isFailure ? 1.13 : 1.18)
                         duration:2.75
                       beginDelay:0.05];
    [self pp_addOpacityPulseToLayer:self.markerHaloView.layer
                                key:PPOrderTimelineCurrentHaloOpacityKey
                               from:0.30
                                 to:(isFailure ? 0.72 : 0.82)
                           duration:2.75
                         beginDelay:0.05];
    [self pp_addScalePulseToLayer:self.markerIconView.layer
                              key:PPOrderTimelineCurrentIconMotionKey
                        fromScale:1.0
                          toScale:1.08
                         duration:1.85
                       beginDelay:0.14];
    [self pp_addVerticalFloatToLayer:self.titleLabel.layer
                                 key:PPOrderTimelineCurrentTitleFloatKey
                            distance:1.1
                            duration:2.25
                          beginDelay:0.12];
    [self pp_addOpacityPulseToLayer:self.titleLabel.layer
                                key:PPOrderTimelineCurrentTitleOpacityKey
                               from:0.82
                                 to:1.0
                           duration:2.25
                         beginDelay:0.12];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                  metaText:(NSString *)metaText
                symbolName:(NSString *)symbolName
                     state:(PPOrderProgressTimelineRowState)state
                  expanded:(BOOL)expanded
                 tintColor:(UIColor *)tintColor
                     isRTL:(BOOL)isRTL
{
    self.titleText = title ?: @"";
    self.subtitleText = subtitle ?: @"";
    self.metaText = metaText ?: @"";
    self.symbolName = symbolName ?: @"circle";
    self.rowState = state;
    self.expanded = expanded;
    self.isRTL = isRTL;
    self.accentColor = tintColor ?: [GM appPrimaryColor];

    NSTextAlignment alignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.titleLabel.textAlignment = alignment;
    self.subtitleLabel.textAlignment = alignment;
    self.metaLabel.textAlignment = alignment;
    self.titleLabel.text = self.titleText;
    self.subtitleLabel.text = self.subtitleText;
    self.metaLabel.text = self.metaText;

    UIColor *accent = self.accentColor ?: [GM appPrimaryColor];
    UIColor *errorColor = UIColor.systemRedColor;
    UIColor *upcomingFill = [UIColor tertiarySystemFillColor];
    UIColor *upcomingBorder = [UIColor quaternaryLabelColor];
    UIColor *titleColor = UIColor.labelColor;
    UIColor *subtitleColor = UIColor.secondaryLabelColor;
    UIColor *metaColor = UIColor.tertiaryLabelColor;
    UIColor *markerFill = accent;
    UIColor *markerBorder = accent;
    UIColor *iconTint = UIColor.whiteColor;
    BOOL showHalo = NO;

    switch (state) {
        case PPOrderProgressTimelineRowStateFailure:
            markerFill = errorColor;
            markerBorder = errorColor;
            titleColor = errorColor;
            subtitleColor = [errorColor colorWithAlphaComponent:0.86];
            metaColor = [errorColor colorWithAlphaComponent:0.72];
            showHalo = YES;
            self.titleLabel.font = [GM boldFontWithSize:16];
            break;
        case PPOrderProgressTimelineRowStateCurrent:
            markerFill = accent;
            markerBorder = accent;
            titleColor = accent;
            subtitleColor = UIColor.labelColor;
            metaColor = [accent colorWithAlphaComponent:0.78];
            showHalo = YES;
            self.titleLabel.font = [GM boldFontWithSize:17];
            break;
        case PPOrderProgressTimelineRowStateCompleted:
            markerFill = accent;
            markerBorder = accent;
            titleColor = UIColor.labelColor;
            subtitleColor = UIColor.secondaryLabelColor;
            metaColor = UIColor.tertiaryLabelColor;
            self.titleLabel.font = [GM boldFontWithSize:15];
            break;
        case PPOrderProgressTimelineRowStateUpcoming:
        default:
            markerFill = upcomingFill;
            markerBorder = upcomingBorder;
            iconTint = UIColor.secondaryLabelColor;
            titleColor = UIColor.secondaryLabelColor;
            subtitleColor = UIColor.tertiaryLabelColor;
            metaColor = UIColor.tertiaryLabelColor;
            self.titleLabel.font = [GM MidFontWithSize:15];
            break;
    }

    self.subtitleLabel.font = [GM MidFontWithSize:13];
    self.metaLabel.font = [GM MidFontWithSize:12];
    self.titleLabel.textColor = titleColor;
    self.subtitleLabel.textColor = subtitleColor;
    self.metaLabel.textColor = metaColor;

    self.markerView.backgroundColor = markerFill;
    [self.markerView pp_setBorderColor:markerBorder];
    self.markerView.layer.borderWidth = showHalo ? 1.3 : 1.0;
    self.markerIconView.image = PPOrderStepperImage(self.symbolName);
    self.markerIconView.tintColor = iconTint;

    self.markerHaloView.hidden = !showHalo;
    self.markerHaloView.backgroundColor = [(showHalo ? markerFill : accent) colorWithAlphaComponent:0.18];
    self.markerHaloView.layer.borderWidth = 1.0;
    [self.markerHaloView pp_setBorderColor:[(showHalo ? markerFill : accent) colorWithAlphaComponent:0.26]];

    BOOL showsSecondaryDetails = expanded;
    self.subtitleLabel.hidden = !showsSecondaryDetails || self.subtitleText.length == 0;
    self.metaLabel.hidden = !showsSecondaryDetails || self.metaText.length == 0;
    [self setNeedsLayout];
    [self refreshCurrentStatusMotion];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
    CGFloat contentWidth = MAX(110.0, width - 56.0);
    CGFloat topPadding = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 8.0 : 6.0;
    CGFloat bottomPadding = self.expanded ? 12.0 : 10.0;
    CGFloat titleHeight = ceil([self.titleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)].height);
    CGFloat detailsHeight = 0.0;
    if (self.expanded) {
        if (self.subtitleText.length > 0) {
            detailsHeight += 6.0 + ceil([self.subtitleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)].height);
        }
        if (self.metaText.length > 0) {
            detailsHeight += 4.0 + ceil([self.metaLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)].height);
        }
    }

    CGFloat minimumHeight = self.expanded ? 78.0 : 54.0;
    return MAX(minimumHeight, topPadding + titleHeight + detailsHeight + bottomPadding);
}

- (CGFloat)markerCenterY
{
    CGFloat markerSize = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 28.0 : 22.0;
    CGFloat topPadding = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 8.0 : 6.0;
    return topPadding + (markerSize * 0.5) + 2.0;
}

- (CGFloat)trackCenterXForWidth:(CGFloat)width
{
    return self.isRTL ? (width - 18.0) : 18.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat trackCenterX = [self trackCenterXForWidth:width];
    CGFloat markerSize = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 28.0 : 22.0;
    CGFloat markerCenterY = [self markerCenterY];
    CGFloat markerX = trackCenterX - (markerSize * 0.5);
    CGFloat markerY = markerCenterY - (markerSize * 0.5);
    self.markerView.frame = CGRectMake(markerX, markerY, markerSize, markerSize);
    self.markerView.layer.cornerRadius = markerSize * 0.5;

    CGFloat haloSize = markerSize + 12.0;
    self.markerHaloView.frame = CGRectMake(trackCenterX - (haloSize * 0.5),
                                           markerCenterY - (haloSize * 0.5),
                                           haloSize,
                                           haloSize);
    self.markerHaloView.layer.cornerRadius = haloSize * 0.5;
    self.markerIconView.frame = CGRectInset(self.markerView.bounds,
                                            (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                                             self.rowState == PPOrderProgressTimelineRowStateFailure) ? 6.0 : 4.5,
                                            (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                                             self.rowState == PPOrderProgressTimelineRowStateFailure) ? 6.0 : 4.5);

    CGFloat contentLeading = self.isRTL ? 0.0 : 46.0;
    CGFloat contentWidth = MAX(0.0, width - 46.0);
    CGFloat contentTop = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 8.0 : 6.0;
    CGFloat y = contentTop;

    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
    self.titleLabel.frame = CGRectMake(contentLeading, y, contentWidth, ceil(titleSize.height));
    y = CGRectGetMaxY(self.titleLabel.frame);

    if (!self.subtitleLabel.hidden) {
        y += 6.0;
        CGSize subtitleSize = [self.subtitleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
        self.subtitleLabel.frame = CGRectMake(contentLeading, y, contentWidth, ceil(subtitleSize.height));
        y = CGRectGetMaxY(self.subtitleLabel.frame);
    } else {
        self.subtitleLabel.frame = CGRectZero;
    }

    if (!self.metaLabel.hidden) {
        y += 4.0;
        CGSize metaSize = [self.metaLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
        self.metaLabel.frame = CGRectMake(contentLeading, y, contentWidth, ceil(metaSize.height));
    } else {
        self.metaLabel.frame = CGRectZero;
    }

    [self refreshCurrentStatusMotion];
}

@end
