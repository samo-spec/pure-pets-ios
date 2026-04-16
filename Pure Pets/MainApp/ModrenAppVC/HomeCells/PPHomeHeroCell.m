//
//  PPHomeHeroCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/10/26.
//

#import "PPHomeHeroCell.h"

@interface PPHomeHeroCell ()
@property (nonatomic, strong) UIView *heroShadowView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) CAGradientLayer *backgroundGradientLayer;
@property (nonatomic, strong) CAGradientLayer *bottomShadeLayer;
@property (nonatomic, strong) UIView *mirrorStageView;
@property (nonatomic, strong) UIVisualEffectView *mirrorGlassView;
@property (nonatomic, strong) UIView *mirrorTintView;
@property (nonatomic, strong) CAGradientLayer *mirrorGradientLayer;
@property (nonatomic, strong) CAGradientLayer *mirrorShineLayer;
@property (nonatomic, strong) UIView *accentOrbView;
@property (nonatomic, strong) UIView *secondaryOrbView;
@property (nonatomic, strong) UIView *trendingPillView;
@property (nonatomic, strong) UIImageView *trendingIconView;
@property (nonatomic, strong) UILabel *trendingLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) UILabel *supportLabel;
@property (nonatomic, strong) UILabel *mirrorMetaLabel;
@property (nonatomic, strong) UILabel *clockLabel;
@property (nonatomic, strong) UIView *signalBarContainer;
@property (nonatomic, strong) UIView *signalBarA;
@property (nonatomic, strong) UIView *signalBarB;
@property (nonatomic, strong) UIView *signalBarC;
@property (nonatomic, strong) UIControl *locationRail;
@property (nonatomic, strong) UIView *locationPlateView;
@property (nonatomic, strong) UIImageView *locationIconView;
@property (nonatomic, strong) UILabel *locationTitleLabel;
@property (nonatomic, strong) UILabel *locationMetaLabel;
@property (nonatomic, strong) UIView *locationChipView;
@property (nonatomic, strong) UIView *locationChipDotView;
@property (nonatomic, strong) UILabel *locationChipLabel;
@property (nonatomic, strong) UIImageView *locationChevronView;
@property (nonatomic, strong) NSLayoutConstraint *mirrorWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *headlineTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *supportWidthConstraint;
@property (nonatomic, strong) NSTimer *liveUpdateTimer;
@property (nonatomic, copy) NSString *paletteLocationSeed;
@property (nonatomic, copy) NSString *currentGreetingText;
@property (nonatomic, copy) NSString *currentUserNameText;
@property (nonatomic, copy) NSString *currentLocationText;
@property (nonatomic, copy) NSString *currentActionTitle;
@property (nonatomic, assign) PPHomeHeroLocationState currentLocationState;
@property (nonatomic, copy) NSString *lastAnimationSignature;
@property (nonatomic, assign) CGFloat lastResolvedLayoutWidth;
@property (nonatomic, assign) NSInteger lastRenderedMinute;

@property (nonatomic, strong) UIControl *orderPeekStrip;
@property (nonatomic, strong) UIVisualEffectView *orderPeekBlurView;
@property (nonatomic, strong) UIView *orderPeekTintOverlay;
@property (nonatomic, strong) UIImageView *orderPeekThumbnail;
@property (nonatomic, strong) UILabel *orderPeekReferenceLabel;
@property (nonatomic, strong) UIView *orderPeekStatusDot;
@property (nonatomic, strong) UILabel *orderPeekStatusLabel;
@property (nonatomic, strong) UIImageView *orderPeekChevron;
@property (nonatomic, assign) BOOL orderPeekVisible;
@property (nonatomic, assign) BOOL orderPeekExpanded;
@property (nonatomic, strong) UIColor *orderPeekStatusColor;
@end

static CGFloat const PPHomeHeroSurfaceRadius = 32.0;
static CGFloat const PPHomeHeroInnerRadius = 24.0;
static CGFloat const PPHomeHeroLocationRadius = 22.0;
static CGFloat const PPHomeHeroOrderPeekHeight = 42.0;
static CGFloat const PPHomeHeroOrderPeekOverlap = 10.0;

typedef NS_ENUM(NSInteger, PPHomeHeroSymbolWeight) {
    PPHomeHeroSymbolWeightRegular = 0,
    PPHomeHeroSymbolWeightMedium,
    PPHomeHeroSymbolWeightSemibold,
    PPHomeHeroSymbolWeightBold
};

static inline NSString *PPHomeHeroSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static inline UIColor *PPHomeHeroColor(NSUInteger hexValue, CGFloat alpha)
{
    return [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                           green:((hexValue >> 8) & 0xFF) / 255.0
                            blue:(hexValue & 0xFF) / 255.0
                           alpha:alpha];
}

static inline CGFloat PPHomeHeroClamp(CGFloat value)
{
    return fmax(0.0, fmin(1.0, value));
}

static inline CGFloat PPHomeHeroLerp(CGFloat start, CGFloat end, CGFloat progress)
{
    progress = PPHomeHeroClamp(progress);
    return start + ((end - start) * progress);
}

static inline CGPoint PPHomeHeroLerpPoint(CGPoint start, CGPoint end, CGFloat progress)
{
    return CGPointMake(PPHomeHeroLerp(start.x, end.x, progress),
                       PPHomeHeroLerp(start.y, end.y, progress));
}

static inline UIColor *PPHomeHeroBlendColors(UIColor *fromColor, UIColor *toColor, CGFloat progress)
{
    if (!fromColor) return toColor ?: UIColor.clearColor;
    if (!toColor) return fromColor;

    CGFloat fr = 0.0, fg = 0.0, fb = 0.0, fa = 0.0;
    CGFloat tr = 0.0, tg = 0.0, tb = 0.0, ta = 0.0;
    [fromColor getRed:&fr green:&fg blue:&fb alpha:&fa];
    [toColor getRed:&tr green:&tg blue:&tb alpha:&ta];

    return [UIColor colorWithRed:PPHomeHeroLerp(fr, tr, progress)
                           green:PPHomeHeroLerp(fg, tg, progress)
                            blue:PPHomeHeroLerp(fb, tb, progress)
                           alpha:PPHomeHeroLerp(fa, ta, progress)];
}

static inline NSString *PPHomeHeroTrimLine(NSString *value)
{
    NSString *safeValue = PPHomeHeroSafeString(value);
    safeValue = [safeValue stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    safeValue = [safeValue stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    return [safeValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static inline CGFloat PPHomeHeroResolvedWidth(CGFloat width)
{
    return width > 0.0 ? width : UIScreen.mainScreen.bounds.size.width;
}

static inline BOOL PPHomeHeroWidthIsTablet(CGFloat width)
{
    return PPHomeHeroResolvedWidth(width) >= 700.0;
}

static inline BOOL PPHomeHeroWidthIsWidePhone(CGFloat width)
{
    width = PPHomeHeroResolvedWidth(width);
    return width >= 430.0 && width < 700.0;
}

static inline BOOL PPHomeHeroWidthIsCompact(CGFloat width)
{
    return PPHomeHeroResolvedWidth(width) < 350.0;
}

static inline UIColor *PPHomeHeroAccentColor(NSString *seed)
{
    NSString *safeSeed = PPHomeHeroSafeString(seed);
    if (safeSeed.length == 0) {
        return PPHomeHeroColor(0xFFB86B, 1.0);
    }

    NSUInteger hash = safeSeed.hash;
    CGFloat hue = (CGFloat)(hash % 360) / 360.0;
    CGFloat saturation = 0.44 + (CGFloat)((hash >> 5) % 18) / 100.0;
    CGFloat brightness = 0.90 + (CGFloat)((hash >> 11) % 7) / 100.0;
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
}

static NSArray<UIColor *> *PPHomeHeroInterpolateColors(NSArray<UIColor *> *fromColors,
                                                       NSArray<UIColor *> *toColors,
                                                       CGFloat progress)
{
    NSUInteger count = MIN(fromColors.count, toColors.count);
    NSMutableArray<UIColor *> *colors = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger idx = 0; idx < count; idx++) {
        [colors addObject:PPHomeHeroBlendColors(fromColors[idx], toColors[idx], progress)];
    }
    return colors.copy;
}

static NSArray<NSDictionary<NSString *, id> *> *PPHomeHeroPaletteAnchors(void)
{
    static NSArray<NSDictionary<NSString *, id> *> *anchors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        anchors = @[
            @{
                @"minute" : @0,
                @"colors" : @[
                    PPHomeHeroColor(0x081522, 1.0),
                    PPHomeHeroColor(0x122742, 1.0),
                    PPHomeHeroColor(0x214A66, 1.0),
                    PPHomeHeroColor(0x2A6E84, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.06, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.96, 1.0)]
            },
            @{
                @"minute" : @330,
                @"colors" : @[
                    PPHomeHeroColor(0x1B1832, 1.0),
                    PPHomeHeroColor(0x61334D, 1.0),
                    PPHomeHeroColor(0xD36D6B, 1.0),
                    PPHomeHeroColor(0xF2B878, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.02, 0.08)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.96, 0.94)]
            },
            @{
                @"minute" : @540,
                @"colors" : @[
                    PPHomeHeroColor(0x0A4E86, 1.0),
                    PPHomeHeroColor(0x1F88C2, 1.0),
                    PPHomeHeroColor(0x4FD4D2, 1.0),
                    PPHomeHeroColor(0xF4E09A, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.98, 1.0)]
            },
            @{
                @"minute" : @900,
                @"colors" : @[
                    PPHomeHeroColor(0x22558D, 1.0),
                    PPHomeHeroColor(0x5076B8, 1.0),
                    PPHomeHeroColor(0xC66FA0, 1.0),
                    PPHomeHeroColor(0xF1A862, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.04, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(1.0, 0.92)]
            },
            @{
                @"minute" : @1110,
                @"colors" : @[
                    PPHomeHeroColor(0x17203F, 1.0),
                    PPHomeHeroColor(0x314A7B, 1.0),
                    PPHomeHeroColor(0x6E63A7, 1.0),
                    PPHomeHeroColor(0xE49C68, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.04, 0.04)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.96, 0.96)]
            },
            @{
                @"minute" : @1320,
                @"colors" : @[
                    PPHomeHeroColor(0x06111F, 1.0),
                    PPHomeHeroColor(0x10263D, 1.0),
                    PPHomeHeroColor(0x1B4365, 1.0),
                    PPHomeHeroColor(0x285D7C, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.08, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.92, 1.0)]
            },
            @{
                @"minute" : @1440,
                @"colors" : @[
                    PPHomeHeroColor(0x081522, 1.0),
                    PPHomeHeroColor(0x122742, 1.0),
                    PPHomeHeroColor(0x214A66, 1.0),
                    PPHomeHeroColor(0x2A6E84, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.06, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.96, 1.0)]
            }
        ];
    });
    return anchors;
}

@implementation PPHomeHeroCell

+ (NSString *)reuseIdentifier
{
    return @"PPHomeHeroCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.lastRenderedMinute = NSNotFound;

    [self pp_buildHeroSurface];
    [self pp_buildOrderPeekStrip];
    [self pp_applyBaseStyle];
    [self pp_updateAdaptiveLayoutMetrics];
    [self pp_applyPaletteForCurrentTimeAnimated:NO force:YES];
    [self pp_startAmbientAnimationsIfNeeded];

    return self;
}

- (void)dealloc
{
    [self pp_stopLiveUpdates];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (self.window) {
        [self pp_startLiveUpdatesIfNeeded];
        [self pp_handleLiveUpdateTick];
    } else {
        [self pp_stopLiveUpdates];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_updateAdaptiveLayoutMetrics];

    self.backgroundGradientLayer.frame = self.heroSurfaceView.bounds;
    self.bottomShadeLayer.frame = self.heroSurfaceView.bounds;
    self.mirrorGradientLayer.frame = self.mirrorTintView.bounds;
    self.mirrorShineLayer.frame = self.mirrorTintView.bounds;

    self.heroShadowView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroShadowView.bounds
                                   cornerRadius:self.heroSurfaceView.layer.cornerRadius].CGPath;

    self.accentOrbView.layer.cornerRadius = CGRectGetWidth(self.accentOrbView.bounds) * 0.5;
    self.secondaryOrbView.layer.cornerRadius = CGRectGetWidth(self.secondaryOrbView.bounds) * 0.5;
    self.locationChipDotView.layer.cornerRadius = CGRectGetWidth(self.locationChipDotView.bounds) * 0.5;
    self.orderPeekStatusDot.layer.cornerRadius = CGRectGetWidth(self.orderPeekStatusDot.bounds) * 0.5;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self pp_updateAdaptiveLayoutMetrics];
    [self setNeedsLayout];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self pp_updateAdaptiveLayoutMetrics];
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.onLocationTap = nil;
    self.onLocationActionTap = nil;
    self.onOrderPeekTap = nil;
    self.lastAnimationSignature = nil;
    self.lastResolvedLayoutWidth = 0.0;
    self.lastRenderedMinute = NSNotFound;
    self.currentGreetingText = @"";
    self.currentUserNameText = @"";
    self.currentLocationText = @"";
    self.currentActionTitle = @"";
    self.paletteLocationSeed = @"";
    self.currentLocationState = PPHomeHeroLocationStateUnset;

    self.headlineLabel.text = @"";
    self.headlineLabel.attributedText = nil;
    self.supportLabel.text = @"";
    self.locationTitleLabel.text = @"";
    self.locationMetaLabel.text = @"";
    self.locationChipLabel.text = @"";
    self.clockLabel.text = @"";
    self.mirrorMetaLabel.text = @"";
    self.actionButton.hidden = YES;
    self.actionButton.alpha = 0.0;
    self.actionButton.transform = CGAffineTransformIdentity;
    [self.actionButton setTitle:@"" forState:UIControlStateNormal];
    self.trendingPillView.alpha = 1.0;
    self.trendingPillView.transform = CGAffineTransformIdentity;
    self.headlineLabel.alpha = 1.0;
    self.headlineLabel.transform = CGAffineTransformIdentity;
    self.supportLabel.alpha = 1.0;
    self.supportLabel.transform = CGAffineTransformIdentity;
    self.mirrorStageView.alpha = 1.0;
    self.mirrorStageView.transform = CGAffineTransformIdentity;
    self.locationRail.alpha = 1.0;
    self.locationRail.transform = CGAffineTransformIdentity;
    self.orderPeekThumbnail.image = nil;
    self.orderPeekReferenceLabel.text = @"";
    self.orderPeekStatusLabel.text = @"";
    self.orderPeekExpanded = NO;
    self.orderPeekVisible = NO;
    self.orderPeekStrip.alpha = 0.0;
    self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
    self.orderPeekChevron.transform = CGAffineTransformIdentity;
    [self pp_stopOrderPeekPulseAnimation];
    [self pp_applyPaletteForCurrentTimeAnimated:NO force:YES];
}

#pragma mark - Public

- (void)configureWithGreeting:(NSString *)greeting
                     userName:(NSString *)userName
                     location:(NSString *)location
                locationState:(PPHomeHeroLocationState)locationState
                  actionTitle:(nullable NSString *)actionTitle
{
    self.currentGreetingText = PPHomeHeroSafeString(greeting);
    self.currentUserNameText = PPHomeHeroTrimLine(userName);
    self.currentLocationText = PPHomeHeroTrimLine(location);
    self.currentActionTitle = PPHomeHeroSafeString(actionTitle);
    self.currentLocationState = locationState;
    self.paletteLocationSeed = self.currentLocationText;

    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    self.semanticContentAttribute = semantic;
    self.contentView.semanticContentAttribute = semantic;
    self.heroSurfaceView.semanticContentAttribute = semantic;
    self.locationRail.semanticContentAttribute = semantic;
    self.orderPeekStrip.semanticContentAttribute = semantic;

    self.headlineLabel.attributedText =
        [self pp_attributedHeadlineWithGreeting:self.currentGreetingText
                                       userName:self.currentUserNameText];
    self.supportLabel.text =
        [self pp_supportTextForLocation:self.currentLocationText state:locationState];

    NSString *locationTitle = self.currentLocationText.length > 0
        ? self.currentLocationText
        : (kLang(@"Select your location") ?: @"Select your location");
    self.locationTitleLabel.text = locationTitle;
    self.locationMetaLabel.text = [self pp_locationMetaTextForState:locationState];
    self.mirrorMetaLabel.text = [self pp_mirrorMetaTextForState:locationState];
    self.trendingLabel.text = [self pp_trendingLabelTextForState:locationState];

    NSString *resolvedActionTitle = self.currentActionTitle;
    if (resolvedActionTitle.length == 0) {
        resolvedActionTitle = [self pp_defaultActionTitleForState:locationState];
    }
    self.currentActionTitle = resolvedActionTitle;

    [self.actionButton setTitle:resolvedActionTitle forState:UIControlStateNormal];
    [self pp_applyPaletteForCurrentTimeAnimated:NO force:YES];
    [self pp_applyLocationStateAppearanceAnimated:NO];
    [self pp_updateAccessibility];
    [self pp_updateAdaptiveLayoutMetrics];

    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%ld|%@",
                           self.currentGreetingText,
                           self.currentUserNameText,
                           self.currentLocationText,
                           (long)locationState,
                           resolvedActionTitle];
    [self pp_runEntranceAnimationIfNeededWithSignature:signature];
}

- (void)configureOrderPeekWithReference:(nullable NSString *)reference
                            statusTitle:(nullable NSString *)statusTitle
                            statusColor:(nullable UIColor *)statusColor
                        previewImageURL:(nullable NSString *)previewImageURL
                               expanded:(BOOL)expanded
                               animated:(BOOL)animated
{
    NSString *safeReference = PPHomeHeroSafeString(reference);
    if (safeReference.length == 0) {
        [self hideOrderPeek:animated];
        return;
    }

    self.orderPeekReferenceLabel.text = safeReference;
    self.orderPeekStatusLabel.text = PPHomeHeroSafeString(statusTitle);
    [self pp_applyOrderPeekStyleWithStatusColor:statusColor expanded:expanded];
    [self pp_updateOrderPeekChevronForExpanded:expanded animated:(self.orderPeekVisible && animated)];

    NSString *safeURL = PPHomeHeroSafeString(previewImageURL);
    if (safeURL.length > 0) {
        [GM setImageFromUrlString:safeURL imageView:self.orderPeekThumbnail phImage:@"placeholder"];
    } else {
        self.orderPeekThumbnail.image = [UIImage imageNamed:@"placeholder"];
    }

    [self pp_startOrderPeekPulseAnimation];

    if (self.orderPeekVisible) {
        return;
    }

    self.orderPeekVisible = YES;
    if (!animated) {
        self.orderPeekStrip.alpha = 1.0;
        self.orderPeekStrip.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.52
                          delay:0.08
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.orderPeekStrip.alpha = 1.0;
        self.orderPeekStrip.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hideOrderPeek:(BOOL)animated
{
    if (!self.orderPeekVisible) {
        return;
    }

    self.orderPeekVisible = NO;
    [self pp_stopOrderPeekPulseAnimation];

    if (!animated) {
        self.orderPeekStrip.alpha = 0.0;
        self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.orderPeekStrip.alpha = 0.0;
        self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
    } completion:nil];
}

#pragma mark - Build

- (void)pp_buildHeroSurface
{
    self.heroShadowView = [[UIView alloc] init];
    self.heroShadowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroShadowView.backgroundColor = UIColor.clearColor;
    self.heroShadowView.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    self.heroShadowView.layer.shadowOpacity = 0.16;
    self.heroShadowView.layer.shadowRadius = 28.0;
    self.heroShadowView.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    [self.contentView addSubview:self.heroShadowView];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = PPHomeHeroColor(0x101826, 1.0);
    self.heroSurfaceView.layer.cornerRadius = PPHomeHeroSurfaceRadius;
    self.heroSurfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
        self.heroShadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroShadowView addSubview:self.heroSurfaceView];

    self.backgroundGradientLayer = [CAGradientLayer layer];
    self.backgroundGradientLayer.startPoint = CGPointMake(0.02, 0.0);
    self.backgroundGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.backgroundGradientLayer.locations = @[@0.0, @0.28, @0.68, @1.0];
    [self.heroSurfaceView.layer insertSublayer:self.backgroundGradientLayer atIndex:0];

    self.bottomShadeLayer = [CAGradientLayer layer];
    self.bottomShadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bottomShadeLayer.endPoint = CGPointMake(0.5, 1.0);
    [self.heroSurfaceView.layer addSublayer:self.bottomShadeLayer];

    self.accentOrbView = [[UIView alloc] init];
    self.accentOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentOrbView.userInteractionEnabled = NO;
    self.accentOrbView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [self.heroSurfaceView addSubview:self.accentOrbView];

    self.secondaryOrbView = [[UIView alloc] init];
    self.secondaryOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.secondaryOrbView.userInteractionEnabled = NO;
    self.secondaryOrbView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    [self.heroSurfaceView addSubview:self.secondaryOrbView];

    self.mirrorStageView = [[UIView alloc] init];
    self.mirrorStageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mirrorStageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    self.mirrorStageView.layer.cornerRadius = PPHomeHeroInnerRadius;
    self.mirrorStageView.layer.borderWidth = 1.0;
    self.mirrorStageView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    self.mirrorStageView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.mirrorStageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroSurfaceView addSubview:self.mirrorStageView];

    UIBlurEffectStyle mirrorBlurStyle = UIBlurEffectStyleDark;
    if (@available(iOS 13.0, *)) {
        mirrorBlurStyle = UIBlurEffectStyleSystemUltraThinMaterialDark;
    }
    UIBlurEffect *mirrorBlurEffect = [UIBlurEffect effectWithStyle:mirrorBlurStyle];
    self.mirrorGlassView = [[UIVisualEffectView alloc] initWithEffect:mirrorBlurEffect];
    self.mirrorGlassView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mirrorGlassView.userInteractionEnabled = NO;
    [self.mirrorStageView addSubview:self.mirrorGlassView];

    self.mirrorTintView = [[UIView alloc] init];
    self.mirrorTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mirrorTintView.userInteractionEnabled = NO;
    [self.mirrorGlassView.contentView addSubview:self.mirrorTintView];

    self.mirrorGradientLayer = [CAGradientLayer layer];
    self.mirrorGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.mirrorGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.mirrorTintView.layer addSublayer:self.mirrorGradientLayer];

    self.mirrorShineLayer = [CAGradientLayer layer];
    self.mirrorShineLayer.startPoint = CGPointMake(0.0, 0.0);
    self.mirrorShineLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.mirrorTintView.layer addSublayer:self.mirrorShineLayer];

    self.trendingPillView = [[UIView alloc] init];
    self.trendingPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.trendingPillView.layer.cornerRadius = 15.0;
    self.trendingPillView.layer.borderWidth = 1.0;
    self.trendingPillView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    if (@available(iOS 13.0, *)) {
        self.trendingPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroSurfaceView addSubview:self.trendingPillView];

    self.trendingIconView = [[UIImageView alloc] init];
    self.trendingIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.trendingIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.trendingIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    [self.trendingPillView addSubview:self.trendingIconView];

    self.trendingLabel = [[UILabel alloc] init];
    self.trendingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.trendingLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.trendingLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    [self.trendingPillView addSubview:self.trendingLabel];

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.layer.cornerRadius = 16.0;
    self.actionButton.layer.borderWidth = 1.0;
    self.actionButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    self.actionButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.actionButton.tintColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    self.actionButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    [self.actionButton addTarget:self action:@selector(pp_handleLocationActionTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    [self.heroSurfaceView addSubview:self.actionButton];

    self.headlineLabel = [[UILabel alloc] init];
    self.headlineLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headlineLabel.numberOfLines = 2;
    self.headlineLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.headlineLabel.adjustsFontSizeToFitWidth = YES;
    self.headlineLabel.minimumScaleFactor = 0.82;
    self.headlineLabel.allowsDefaultTighteningForTruncation = YES;
    [self.heroSurfaceView addSubview:self.headlineLabel];

    self.supportLabel = [[UILabel alloc] init];
    self.supportLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.supportLabel.numberOfLines = 2;
    self.supportLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.supportLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.80];
    [self.heroSurfaceView addSubview:self.supportLabel];

    self.mirrorMetaLabel = [[UILabel alloc] init];
    self.mirrorMetaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.mirrorMetaLabel.numberOfLines = 2;
    self.mirrorMetaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.mirrorMetaLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.90];
    [self.mirrorStageView addSubview:self.mirrorMetaLabel];

    self.clockLabel = [[UILabel alloc] init];
    self.clockLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.clockLabel.numberOfLines = 1;
    self.clockLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.clockLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    [self.mirrorStageView addSubview:self.clockLabel];

    self.signalBarContainer = [[UIView alloc] init];
    self.signalBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.signalBarContainer.userInteractionEnabled = NO;
    [self.mirrorStageView addSubview:self.signalBarContainer];

    self.signalBarA = [self pp_makeSignalBar];
    self.signalBarB = [self pp_makeSignalBar];
    self.signalBarC = [self pp_makeSignalBar];
    [self.signalBarContainer addSubview:self.signalBarA];
    [self.signalBarContainer addSubview:self.signalBarB];
    [self.signalBarContainer addSubview:self.signalBarC];

    self.locationRail = [[UIControl alloc] init];
    self.locationRail.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationRail.layer.cornerRadius = PPHomeHeroLocationRadius;
    self.locationRail.layer.borderWidth = 1.0;
    self.locationRail.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    self.locationRail.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.locationRail.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.locationRail addTarget:self action:@selector(pp_handleLocationTap) forControlEvents:UIControlEventTouchUpInside];
    [self.locationRail addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.locationRail addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.locationRail addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.locationRail addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    [self.heroSurfaceView addSubview:self.locationRail];

    self.locationPlateView = [[UIView alloc] init];
    self.locationPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationPlateView.layer.cornerRadius = 18.0;
    self.locationPlateView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.locationPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.locationRail addSubview:self.locationPlateView];

    self.locationIconView = [[UIImageView alloc] init];
    self.locationIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.locationIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    [self.locationPlateView addSubview:self.locationIconView];

    self.locationTitleLabel = [[UILabel alloc] init];
    self.locationTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationTitleLabel.numberOfLines = 1;
    self.locationTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.locationTitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    [self.locationRail addSubview:self.locationTitleLabel];

    self.locationMetaLabel = [[UILabel alloc] init];
    self.locationMetaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationMetaLabel.numberOfLines = 1;
    self.locationMetaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.locationMetaLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    [self.locationRail addSubview:self.locationMetaLabel];

    self.locationChipView = [[UIView alloc] init];
    self.locationChipView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationChipView.layer.cornerRadius = 17.0;
    self.locationChipView.layer.borderWidth = 1.0;
    self.locationChipView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.locationChipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.locationRail addSubview:self.locationChipView];

    self.locationChipDotView = [[UIView alloc] init];
    self.locationChipDotView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.locationChipView addSubview:self.locationChipDotView];

    self.locationChipLabel = [[UILabel alloc] init];
    self.locationChipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationChipLabel.numberOfLines = 1;
    self.locationChipLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.locationChipView addSubview:self.locationChipLabel];

    self.locationChevronView = [[UIImageView alloc] init];
    self.locationChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationChevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.locationChipView addSubview:self.locationChevronView];

    self.mirrorWidthConstraint = [self.mirrorStageView.widthAnchor constraintEqualToConstant:132.0];
    self.headlineTrailingConstraint =
        [self.headlineLabel.trailingAnchor constraintEqualToAnchor:self.mirrorStageView.leadingAnchor constant:-18.0];
    self.supportWidthConstraint = [self.supportLabel.widthAnchor constraintLessThanOrEqualToConstant:210.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroShadowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.heroShadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.heroShadowView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.heroShadowView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.heroShadowView.topAnchor],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.heroShadowView.leadingAnchor],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.heroShadowView.trailingAnchor],
        [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.heroShadowView.bottomAnchor],

        [self.accentOrbView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:-44.0],
        [self.accentOrbView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:36.0],
        [self.accentOrbView.widthAnchor constraintEqualToConstant:180.0],
        [self.accentOrbView.heightAnchor constraintEqualToConstant:180.0],

        [self.secondaryOrbView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:54.0],
        [self.secondaryOrbView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:-34.0],
        [self.secondaryOrbView.widthAnchor constraintEqualToConstant:124.0],
        [self.secondaryOrbView.heightAnchor constraintEqualToConstant:124.0],

        [self.mirrorStageView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:14.0],
        [self.mirrorStageView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-14.0],
        [self.mirrorStageView.bottomAnchor constraintEqualToAnchor:self.locationRail.topAnchor constant:-14.0],
        self.mirrorWidthConstraint,

        [self.mirrorGlassView.topAnchor constraintEqualToAnchor:self.mirrorStageView.topAnchor],
        [self.mirrorGlassView.leadingAnchor constraintEqualToAnchor:self.mirrorStageView.leadingAnchor],
        [self.mirrorGlassView.trailingAnchor constraintEqualToAnchor:self.mirrorStageView.trailingAnchor],
        [self.mirrorGlassView.bottomAnchor constraintEqualToAnchor:self.mirrorStageView.bottomAnchor],

        [self.mirrorTintView.topAnchor constraintEqualToAnchor:self.mirrorGlassView.contentView.topAnchor],
        [self.mirrorTintView.leadingAnchor constraintEqualToAnchor:self.mirrorGlassView.contentView.leadingAnchor],
        [self.mirrorTintView.trailingAnchor constraintEqualToAnchor:self.mirrorGlassView.contentView.trailingAnchor],
        [self.mirrorTintView.bottomAnchor constraintEqualToAnchor:self.mirrorGlassView.contentView.bottomAnchor],

        [self.trendingPillView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.trendingPillView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:20.0],
        [self.trendingPillView.heightAnchor constraintEqualToConstant:30.0],

        [self.trendingIconView.leadingAnchor constraintEqualToAnchor:self.trendingPillView.leadingAnchor constant:10.0],
        [self.trendingIconView.centerYAnchor constraintEqualToAnchor:self.trendingPillView.centerYAnchor],
        [self.trendingIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.trendingIconView.heightAnchor constraintEqualToConstant:12.0],

        [self.trendingLabel.leadingAnchor constraintEqualToAnchor:self.trendingIconView.trailingAnchor constant:6.0],
        [self.trendingLabel.trailingAnchor constraintEqualToAnchor:self.trendingPillView.trailingAnchor constant:-10.0],
        [self.trendingLabel.centerYAnchor constraintEqualToAnchor:self.trendingPillView.centerYAnchor],

        [self.actionButton.centerYAnchor constraintEqualToAnchor:self.trendingPillView.centerYAnchor],
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.mirrorStageView.leadingAnchor constant:-18.0],
        [self.actionButton.heightAnchor constraintEqualToConstant:32.0],

        [self.headlineLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.headlineLabel.topAnchor constraintEqualToAnchor:self.trendingPillView.bottomAnchor constant:18.0],
        self.headlineTrailingConstraint,

        [self.supportLabel.leadingAnchor constraintEqualToAnchor:self.headlineLabel.leadingAnchor],
        [self.supportLabel.topAnchor constraintEqualToAnchor:self.headlineLabel.bottomAnchor constant:10.0],
        self.supportWidthConstraint,
        [self.supportLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.mirrorStageView.leadingAnchor constant:-24.0],

        [self.mirrorMetaLabel.topAnchor constraintEqualToAnchor:self.mirrorStageView.topAnchor constant:16.0],
        [self.mirrorMetaLabel.leadingAnchor constraintEqualToAnchor:self.mirrorStageView.leadingAnchor constant:14.0],
        [self.mirrorMetaLabel.trailingAnchor constraintEqualToAnchor:self.mirrorStageView.trailingAnchor constant:-14.0],

        [self.clockLabel.topAnchor constraintEqualToAnchor:self.mirrorMetaLabel.bottomAnchor constant:6.0],
        [self.clockLabel.leadingAnchor constraintEqualToAnchor:self.mirrorMetaLabel.leadingAnchor],
        [self.clockLabel.trailingAnchor constraintEqualToAnchor:self.mirrorMetaLabel.trailingAnchor],

        [self.signalBarContainer.leadingAnchor constraintEqualToAnchor:self.mirrorStageView.leadingAnchor constant:14.0],
        [self.signalBarContainer.trailingAnchor constraintEqualToAnchor:self.mirrorStageView.trailingAnchor constant:-14.0],
        [self.signalBarContainer.bottomAnchor constraintEqualToAnchor:self.mirrorStageView.bottomAnchor constant:-18.0],
        [self.signalBarContainer.heightAnchor constraintEqualToConstant:82.0],

        [self.signalBarB.centerXAnchor constraintEqualToAnchor:self.signalBarContainer.centerXAnchor],
        [self.signalBarB.bottomAnchor constraintEqualToAnchor:self.signalBarContainer.bottomAnchor],
        [self.signalBarB.widthAnchor constraintEqualToConstant:16.0],
        [self.signalBarB.heightAnchor constraintEqualToConstant:72.0],

        [self.signalBarA.trailingAnchor constraintEqualToAnchor:self.signalBarB.leadingAnchor constant:-10.0],
        [self.signalBarA.bottomAnchor constraintEqualToAnchor:self.signalBarContainer.bottomAnchor],
        [self.signalBarA.widthAnchor constraintEqualToConstant:12.0],
        [self.signalBarA.heightAnchor constraintEqualToConstant:52.0],

        [self.signalBarC.leadingAnchor constraintEqualToAnchor:self.signalBarB.trailingAnchor constant:10.0],
        [self.signalBarC.bottomAnchor constraintEqualToAnchor:self.signalBarContainer.bottomAnchor],
        [self.signalBarC.widthAnchor constraintEqualToConstant:12.0],
        [self.signalBarC.heightAnchor constraintEqualToConstant:42.0],

        [self.locationRail.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:18.0],
        [self.locationRail.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.locationRail.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-18.0],
        [self.locationRail.heightAnchor constraintEqualToConstant:66.0],

        [self.locationPlateView.leadingAnchor constraintEqualToAnchor:self.locationRail.leadingAnchor constant:12.0],
        [self.locationPlateView.centerYAnchor constraintEqualToAnchor:self.locationRail.centerYAnchor],
        [self.locationPlateView.widthAnchor constraintEqualToConstant:42.0],
        [self.locationPlateView.heightAnchor constraintEqualToConstant:42.0],

        [self.locationIconView.centerXAnchor constraintEqualToAnchor:self.locationPlateView.centerXAnchor],
        [self.locationIconView.centerYAnchor constraintEqualToAnchor:self.locationPlateView.centerYAnchor],
        [self.locationIconView.widthAnchor constraintEqualToConstant:16.0],
        [self.locationIconView.heightAnchor constraintEqualToConstant:16.0],

        [self.locationTitleLabel.leadingAnchor constraintEqualToAnchor:self.locationPlateView.trailingAnchor constant:12.0],
        [self.locationTitleLabel.topAnchor constraintEqualToAnchor:self.locationRail.topAnchor constant:12.0],
        [self.locationTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.locationChipView.leadingAnchor constant:-10.0],

        [self.locationMetaLabel.leadingAnchor constraintEqualToAnchor:self.locationTitleLabel.leadingAnchor],
        [self.locationMetaLabel.bottomAnchor constraintEqualToAnchor:self.locationRail.bottomAnchor constant:-12.0],
        [self.locationMetaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.locationChipView.leadingAnchor constant:-10.0],

        [self.locationChipView.trailingAnchor constraintEqualToAnchor:self.locationRail.trailingAnchor constant:-12.0],
        [self.locationChipView.centerYAnchor constraintEqualToAnchor:self.locationRail.centerYAnchor],
        [self.locationChipView.heightAnchor constraintEqualToConstant:34.0],
        [self.locationChipView.widthAnchor constraintGreaterThanOrEqualToConstant:102.0],
        [self.locationChipView.widthAnchor constraintLessThanOrEqualToAnchor:self.locationRail.widthAnchor multiplier:0.44],

        [self.locationChipDotView.leadingAnchor constraintEqualToAnchor:self.locationChipView.leadingAnchor constant:11.0],
        [self.locationChipDotView.centerYAnchor constraintEqualToAnchor:self.locationChipView.centerYAnchor],
        [self.locationChipDotView.widthAnchor constraintEqualToConstant:8.0],
        [self.locationChipDotView.heightAnchor constraintEqualToConstant:8.0],

        [self.locationChevronView.trailingAnchor constraintEqualToAnchor:self.locationChipView.trailingAnchor constant:-11.0],
        [self.locationChevronView.centerYAnchor constraintEqualToAnchor:self.locationChipView.centerYAnchor],
        [self.locationChevronView.widthAnchor constraintEqualToConstant:10.0],
        [self.locationChevronView.heightAnchor constraintEqualToConstant:10.0],

        [self.locationChipLabel.leadingAnchor constraintEqualToAnchor:self.locationChipDotView.trailingAnchor constant:7.0],
        [self.locationChipLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.locationChevronView.leadingAnchor constant:-7.0],
        [self.locationChipLabel.centerYAnchor constraintEqualToAnchor:self.locationChipView.centerYAnchor]
    ]];

    [self.locationTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                             forAxis:UILayoutConstraintAxisHorizontal];
    [self.locationMetaLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                            forAxis:UILayoutConstraintAxisHorizontal];
    [self.locationChipView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                           forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)pp_buildOrderPeekStrip
{
    self.orderPeekStrip = [[UIControl alloc] init];
    self.orderPeekStrip.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekStrip.layer.cornerRadius = 14.0;
    self.orderPeekStrip.layer.borderWidth = 1.0;
    self.orderPeekStrip.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    self.orderPeekStrip.layer.masksToBounds = YES;
    self.orderPeekStrip.alpha = 0.0;
    self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
    if (@available(iOS 13.0, *)) {
        self.orderPeekStrip.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleOrderPeekTap) forControlEvents:UIControlEventTouchUpInside];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    [self.contentView insertSubview:self.orderPeekStrip belowSubview:self.heroShadowView];

    UIBlurEffectStyle peekBlurStyle = UIBlurEffectStyleDark;
    if (@available(iOS 13.0, *)) {
        peekBlurStyle = UIBlurEffectStyleSystemChromeMaterialDark;
    }
    UIBlurEffect *peekBlur = [UIBlurEffect effectWithStyle:peekBlurStyle];
    self.orderPeekBlurView = [[UIVisualEffectView alloc] initWithEffect:peekBlur];
    self.orderPeekBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekBlurView.userInteractionEnabled = NO;
    [self.orderPeekStrip addSubview:self.orderPeekBlurView];

    self.orderPeekTintOverlay = [[UIView alloc] init];
    self.orderPeekTintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekTintOverlay.userInteractionEnabled = NO;
    self.orderPeekTintOverlay.backgroundColor = [PPHomeHeroColor(0x1A2030, 1.0) colorWithAlphaComponent:0.74];
    [self.orderPeekStrip addSubview:self.orderPeekTintOverlay];

    self.orderPeekThumbnail = [[UIImageView alloc] init];
    self.orderPeekThumbnail.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekThumbnail.layer.cornerRadius = 11.0;
    self.orderPeekThumbnail.layer.masksToBounds = YES;
    self.orderPeekThumbnail.contentMode = UIViewContentModeScaleAspectFill;
    self.orderPeekThumbnail.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    [self.orderPeekStrip addSubview:self.orderPeekThumbnail];

    self.orderPeekReferenceLabel = [[UILabel alloc] init];
    self.orderPeekReferenceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekReferenceLabel.numberOfLines = 1;
    self.orderPeekReferenceLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    self.orderPeekReferenceLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.orderPeekReferenceLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.orderPeekStrip addSubview:self.orderPeekReferenceLabel];

    self.orderPeekStatusDot = [[UIView alloc] init];
    self.orderPeekStatusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekStatusDot.backgroundColor = PPHomeHeroColor(0xF6B24D, 1.0);
    [self.orderPeekStrip addSubview:self.orderPeekStatusDot];

    self.orderPeekStatusLabel = [[UILabel alloc] init];
    self.orderPeekStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekStatusLabel.numberOfLines = 1;
    self.orderPeekStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.orderPeekStatusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    [self.orderPeekStrip addSubview:self.orderPeekStatusLabel];

    self.orderPeekChevron = [[UIImageView alloc] init];
    self.orderPeekChevron.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekChevron.contentMode = UIViewContentModeScaleAspectFit;
    self.orderPeekChevron.tintColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    [self pp_setSymbolNamed:@"chevron.down"
                onImageView:self.orderPeekChevron
                  pointSize:10.0
                     weight:PPHomeHeroSymbolWeightSemibold];
    [self.orderPeekStrip addSubview:self.orderPeekChevron];

    [NSLayoutConstraint activateConstraints:@[
        [self.orderPeekStrip.topAnchor constraintEqualToAnchor:self.heroShadowView.bottomAnchor constant:-PPHomeHeroOrderPeekOverlap],
        [self.orderPeekStrip.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [self.orderPeekStrip.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [self.orderPeekStrip.heightAnchor constraintEqualToConstant:PPHomeHeroOrderPeekHeight],

        [self.orderPeekBlurView.topAnchor constraintEqualToAnchor:self.orderPeekStrip.topAnchor],
        [self.orderPeekBlurView.leadingAnchor constraintEqualToAnchor:self.orderPeekStrip.leadingAnchor],
        [self.orderPeekBlurView.trailingAnchor constraintEqualToAnchor:self.orderPeekStrip.trailingAnchor],
        [self.orderPeekBlurView.bottomAnchor constraintEqualToAnchor:self.orderPeekStrip.bottomAnchor],

        [self.orderPeekTintOverlay.topAnchor constraintEqualToAnchor:self.orderPeekStrip.topAnchor],
        [self.orderPeekTintOverlay.leadingAnchor constraintEqualToAnchor:self.orderPeekStrip.leadingAnchor],
        [self.orderPeekTintOverlay.trailingAnchor constraintEqualToAnchor:self.orderPeekStrip.trailingAnchor],
        [self.orderPeekTintOverlay.bottomAnchor constraintEqualToAnchor:self.orderPeekStrip.bottomAnchor],

        [self.orderPeekThumbnail.leadingAnchor constraintEqualToAnchor:self.orderPeekStrip.leadingAnchor constant:14.0],
        [self.orderPeekThumbnail.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekThumbnail.widthAnchor constraintEqualToConstant:22.0],
        [self.orderPeekThumbnail.heightAnchor constraintEqualToConstant:22.0],

        [self.orderPeekReferenceLabel.leadingAnchor constraintEqualToAnchor:self.orderPeekThumbnail.trailingAnchor constant:10.0],
        [self.orderPeekReferenceLabel.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekReferenceLabel.widthAnchor constraintLessThanOrEqualToConstant:160.0],

        [self.orderPeekStatusDot.leadingAnchor constraintEqualToAnchor:self.orderPeekReferenceLabel.trailingAnchor constant:10.0],
        [self.orderPeekStatusDot.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekStatusDot.widthAnchor constraintEqualToConstant:6.0],
        [self.orderPeekStatusDot.heightAnchor constraintEqualToConstant:6.0],

        [self.orderPeekStatusLabel.leadingAnchor constraintEqualToAnchor:self.orderPeekStatusDot.trailingAnchor constant:6.0],
        [self.orderPeekStatusLabel.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.orderPeekChevron.leadingAnchor constant:-10.0],

        [self.orderPeekChevron.trailingAnchor constraintEqualToAnchor:self.orderPeekStrip.trailingAnchor constant:-14.0],
        [self.orderPeekChevron.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekChevron.widthAnchor constraintEqualToConstant:10.0],
        [self.orderPeekChevron.heightAnchor constraintEqualToConstant:10.0]
    ]];
}

- (UIView *)pp_makeSignalBar
{
    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.layer.cornerRadius = 6.0;
    bar.layer.masksToBounds = YES;
    return bar;
}

- (void)pp_applyBaseStyle
{
    CGFloat surfaceRadius = PPIOS26() ? 34.0 : PPHomeHeroSurfaceRadius;
    self.heroSurfaceView.layer.cornerRadius = surfaceRadius;
    self.heroShadowView.layer.cornerRadius = surfaceRadius;
    self.locationRail.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    self.actionButton.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [self.actionButton setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.96] forState:UIControlStateNormal];
    self.trendingLabel.font = [GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    self.headlineLabel.textColor = UIColor.whiteColor;
    self.supportLabel.font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.locationTitleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.locationMetaLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.locationChipLabel.font = [GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    self.mirrorMetaLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.clockLabel.font = [UIFont monospacedDigitSystemFontOfSize:21.0 weight:UIFontWeightSemibold];
    self.orderPeekReferenceLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.orderPeekStatusLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
}

#pragma mark - Adaptive Layout

- (void)pp_updateAdaptiveLayoutMetrics
{
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.bounds);
    }
    width = PPHomeHeroResolvedWidth(width);

    if (fabs(width - self.lastResolvedLayoutWidth) < 0.5) {
        return;
    }
    self.lastResolvedLayoutWidth = width;

    BOOL compact = PPHomeHeroWidthIsCompact(width);
    BOOL widePhone = PPHomeHeroWidthIsWidePhone(width);
    BOOL tablet = PPHomeHeroWidthIsTablet(width);

    self.mirrorWidthConstraint.constant = tablet ? 178.0 : (widePhone ? 156.0 : (compact ? 112.0 : 132.0));
    self.supportWidthConstraint.constant = tablet ? 330.0 : (widePhone ? 248.0 : (compact ? 172.0 : 210.0));

    CGFloat headlinePrimarySize = tablet ? 38.0 : (widePhone ? 35.0 : (compact ? 27.0 : 31.0));
    CGFloat headlineSecondarySize = tablet ? 24.0 : (widePhone ? 22.0 : (compact ? 18.0 : 20.0));
    CGFloat supportSize = tablet ? 13.5 : (compact ? 11.0 : 12.5);
    CGFloat mirrorMetaSize = tablet ? 11.5 : 11.0;
    CGFloat clockSize = tablet ? 24.0 : (compact ? 17.0 : 21.0);
    CGFloat titleSize = tablet ? 15.0 : (compact ? 13.0 : 14.0);
    CGFloat chipSize = tablet ? 12.0 : (compact ? 10.5 : 11.5);
    CGFloat pillSize = tablet ? 12.0 : 11.5;
    CGFloat actionSize = tablet ? 13.5 : 13.0;

    self.trendingLabel.font = [GM boldFontWithSize:pillSize] ?: [UIFont systemFontOfSize:pillSize weight:UIFontWeightSemibold];
    self.supportLabel.font = [GM MidFontWithSize:supportSize] ?: [UIFont systemFontOfSize:supportSize weight:UIFontWeightMedium];
    self.locationTitleLabel.font = [GM boldFontWithSize:titleSize] ?: [UIFont systemFontOfSize:titleSize weight:UIFontWeightSemibold];
    self.locationMetaLabel.font = [GM MidFontWithSize:MAX(10.0, chipSize - 0.8)] ?: [UIFont systemFontOfSize:MAX(10.0, chipSize - 0.8) weight:UIFontWeightMedium];
    self.locationChipLabel.font = [GM boldFontWithSize:chipSize] ?: [UIFont systemFontOfSize:chipSize weight:UIFontWeightSemibold];
    self.mirrorMetaLabel.font = [GM boldFontWithSize:mirrorMetaSize] ?: [UIFont systemFontOfSize:mirrorMetaSize weight:UIFontWeightSemibold];
    self.clockLabel.font = [UIFont monospacedDigitSystemFontOfSize:clockSize weight:UIFontWeightSemibold];
    self.actionButton.titleLabel.font = [GM boldFontWithSize:actionSize] ?: [UIFont systemFontOfSize:actionSize weight:UIFontWeightSemibold];

    if (self.currentGreetingText.length > 0 || self.currentUserNameText.length > 0) {
        self.headlineLabel.attributedText =
            [self pp_attributedHeadlineWithGreeting:self.currentGreetingText
                                           userName:self.currentUserNameText
                                   primaryFontSize:headlinePrimarySize
                                 secondaryFontSize:headlineSecondarySize];
    }

    BOOL showActionButton = (self.currentActionTitle.length > 0 &&
                             self.currentLocationState != PPHomeHeroLocationStateLoading &&
                             !compact);
    self.actionButton.hidden = !showActionButton;
    self.actionButton.alpha = showActionButton ? 1.0 : 0.0;
}

#pragma mark - Copy

- (NSString *)pp_headlineTextWithGreeting:(NSString *)greeting
                                 userName:(NSString *)userName
{
    NSArray<NSString *> *rawLines =
        [PPHomeHeroSafeString(greeting) componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    NSMutableArray<NSString *> *cleanLines = [NSMutableArray arrayWithCapacity:2];
    for (NSString *candidate in rawLines) {
        NSString *trimmed = PPHomeHeroTrimLine(candidate);
        if (trimmed.length > 0) {
            [cleanLines addObject:trimmed];
        }
        if (cleanLines.count == 2) break;
    }

    NSString *line1 = cleanLines.count > 0 ? cleanLines.firstObject : (kLang(@"Hello") ?: @"Hello");
    NSString *line2 = cleanLines.count > 1 ? cleanLines[1] : @"";

    if (userName.length > 0) {
        if (Language.isRTL) {
            return [NSString stringWithFormat:@"%@\n%@", line1, userName];
        }
        return [NSString stringWithFormat:@"%@,\n%@", line1, userName];
    }

    if (line2.length > 0) {
        return [NSString stringWithFormat:@"%@\n%@", line1, line2];
    }

    return line1;
}

- (NSAttributedString *)pp_attributedHeadlineWithGreeting:(NSString *)greeting
                                                 userName:(NSString *)userName
{
    CGFloat width = PPHomeHeroResolvedWidth(CGRectGetWidth(self.contentView.bounds));
    BOOL compact = PPHomeHeroWidthIsCompact(width);
    BOOL widePhone = PPHomeHeroWidthIsWidePhone(width);
    BOOL tablet = PPHomeHeroWidthIsTablet(width);
    CGFloat primarySize = tablet ? 38.0 : (widePhone ? 35.0 : (compact ? 27.0 : 31.0));
    CGFloat secondarySize = tablet ? 24.0 : (widePhone ? 22.0 : (compact ? 18.0 : 20.0));

    return [self pp_attributedHeadlineWithGreeting:greeting
                                          userName:userName
                                  primaryFontSize:primarySize
                                secondaryFontSize:secondarySize];
}

- (NSAttributedString *)pp_attributedHeadlineWithGreeting:(NSString *)greeting
                                                 userName:(NSString *)userName
                                         primaryFontSize:(CGFloat)primaryFontSize
                                       secondaryFontSize:(CGFloat)secondaryFontSize
{
    NSString *headline = [self pp_headlineTextWithGreeting:greeting userName:userName];
    NSArray<NSString *> *lines =
        [headline componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];

    NSString *firstLine = lines.count > 0 ? PPHomeHeroSafeString(lines.firstObject) : @"";
    NSString *secondLine = lines.count > 1 ? PPHomeHeroSafeString(lines[1]) : @"";

    UIFont *primaryFont = [GM boldFontWithSize:primaryFontSize] ?: [UIFont systemFontOfSize:primaryFontSize weight:UIFontWeightBold];
    UIFont *secondaryFont = [GM boldFontWithSize:secondaryFontSize] ?: [UIFont systemFontOfSize:secondaryFontSize weight:UIFontWeightSemibold];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = Language.alignmentForCurrentLanguage;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.lineSpacing = 1.0;

    NSMutableAttributedString *result =
        [[NSMutableAttributedString alloc] initWithString:firstLine
                                               attributes:@{
        NSFontAttributeName : primaryFont,
        NSForegroundColorAttributeName : UIColor.whiteColor,
        NSParagraphStyleAttributeName : paragraph
    }];

    if (secondLine.length > 0) {
        NSAttributedString *tail =
            [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", secondLine]
                                            attributes:@{
            NSFontAttributeName : secondaryFont,
            NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.92],
            NSParagraphStyleAttributeName : paragraph
        }];
        [result appendAttributedString:tail];
    }

    return result;
}

- (NSString *)pp_trendingLabelTextForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return kLang(@"Hero_FindingNearby") ?: @"Finding nearby";
        case PPHomeHeroLocationStateDenied:
            return kLang(@"Hero_LocationNeeded") ?: @"Location needed";
        case PPHomeHeroLocationStateReady:
            return kLang(@"Hero_TrendingNow") ?: @"Trending now";
        case PPHomeHeroLocationStateUnset:
        default:
            return kLang(@"Hero_SetYourArea") ?: @"Set your area";
    }
}

- (NSString *)pp_supportTextForLocation:(NSString *)location
                                  state:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return kLang(@"Hero_LoadingDescription") ?: @"We are preparing nearby pets, accessories, and services.";

        case PPHomeHeroLocationStateDenied:
            return kLang(@"Hero_DeniedDescription") ?: @"Enable location to unlock nearby pets, accessories, and services.";

        case PPHomeHeroLocationStateReady: {
            NSString *safeLocation = PPHomeHeroTrimLine(location);
            NSString *defaultLocation = kLang(@"Select your location") ?: @"Select your location";
            if (safeLocation.length > 0 && ![safeLocation isEqualToString:defaultLocation]) {
                NSString *format = kLang(@"Hero_ReadyDescriptionFormat") ?: @"Fresh pets, accessories, and services around %@.";
                return [NSString stringWithFormat:format, safeLocation];
            }
            return kLang(@"Hero_ReadyDescriptionFallback") ?: @"Fresh pets, accessories, and services are ready for your area.";
        }

        case PPHomeHeroLocationStateUnset:
        default:
            return kLang(@"Hero_UnsetDescription") ?: @"Set your area to see what is trending around you.";
    }
}

- (NSString *)pp_locationMetaTextForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return kLang(@"Hero_LocationMetaLoading") ?: @"Checking nearby area";
        case PPHomeHeroLocationStateDenied:
            return kLang(@"Hero_LocationMetaDenied") ?: @"Location access is off";
        case PPHomeHeroLocationStateReady:
            return kLang(@"Hero_LocationMetaReady") ?: @"Tap to update area";
        case PPHomeHeroLocationStateUnset:
        default:
            return kLang(@"Hero_LocationMetaUnset") ?: @"Choose your area";
    }
}

- (NSString *)pp_mirrorMetaTextForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return kLang(@"Hero_FindingNearby") ?: @"Finding nearby";
        case PPHomeHeroLocationStateDenied:
            return kLang(@"Hero_LocationNeeded") ?: @"Location needed";
        case PPHomeHeroLocationStateReady:
            return kLang(@"Hero_Brand") ?: @"Pure Pets";
        case PPHomeHeroLocationStateUnset:
        default:
            return kLang(@"Hero_TrendingNow") ?: @"Trending now";
    }
}

- (NSString *)pp_locationChipTextForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return kLang(@"Hero_LocationChipLoading") ?: @"Locating";
        case PPHomeHeroLocationStateDenied:
            return kLang(@"Hero_LocationChipDenied") ?: @"Allow access";
        case PPHomeHeroLocationStateReady:
            return Language.isRTL ? @"غيرك موقعك" : (kLang(@"Hero_LocationChipReady") ?: @"Change your location");
        case PPHomeHeroLocationStateUnset:
        default:
            return kLang(@"Hero_LocationChipUnset") ?: @"Choose area";
    }
}

- (NSString *)pp_locationSymbolNameForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return @"location.north.line.fill";
        case PPHomeHeroLocationStateDenied:
            return @"location.slash.fill";
        case PPHomeHeroLocationStateReady:
            return @"location.fill";
        case PPHomeHeroLocationStateUnset:
        default:
            return @"map.fill";
    }
}

- (NSString *)pp_trendingSymbolNameForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return @"location.north.line.fill";
        case PPHomeHeroLocationStateDenied:
            return @"exclamationmark.triangle.fill";
        case PPHomeHeroLocationStateReady:
            return @"chart.line.uptrend.xyaxis";
        case PPHomeHeroLocationStateUnset:
        default:
            return @"sparkles";
    }
}

- (NSString *)pp_defaultActionTitleForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateDenied:
            return kLang(@"Open Settings") ?: @"Open Settings";
        case PPHomeHeroLocationStateReady:
            return kLang(@"Hero_ChangeArea") ?: @"Change area";
        case PPHomeHeroLocationStateUnset:
            return kLang(@"Hero_LocationCTA") ?: @"Choose area";
        case PPHomeHeroLocationStateLoading:
        default:
            return @"";
    }
}

#pragma mark - State + Palette

- (void)pp_applyLocationStateAppearanceAnimated:(BOOL)animated
{
    UIColor *accent = PPHomeHeroAccentColor(self.paletteLocationSeed);
    UIColor *softAccent = PPHomeHeroBlendColors(accent, UIColor.whiteColor, 0.28);
    UIColor *chipBackground = [softAccent colorWithAlphaComponent:0.20];
    UIColor *chipBorder = [softAccent colorWithAlphaComponent:0.24];
    UIColor *chipTextColor = UIColor.whiteColor;
    UIColor *dotColor = [softAccent colorWithAlphaComponent:1.0];
    UIColor *plateBackground = [softAccent colorWithAlphaComponent:0.22];
    UIColor *plateBorder = [softAccent colorWithAlphaComponent:0.24];
    UIColor *railFill = [UIColor colorWithWhite:1.0 alpha:0.14];
    UIColor *railBorder = [UIColor colorWithWhite:1.0 alpha:0.10];

    switch (self.currentLocationState) {
        case PPHomeHeroLocationStateDenied:
            chipBackground = [UIColor colorWithWhite:1.0 alpha:0.94];
            chipBorder = [UIColor clearColor];
            chipTextColor = PPHomeHeroColor(0x172031, 1.0);
            dotColor = PPHomeHeroColor(0xFF8C54, 1.0);
            plateBackground = [UIColor colorWithWhite:1.0 alpha:0.16];
            plateBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
            railFill = [UIColor colorWithWhite:1.0 alpha:0.11];
            railBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            break;

        case PPHomeHeroLocationStateLoading:
            chipBackground = [softAccent colorWithAlphaComponent:0.18];
            chipBorder = [softAccent colorWithAlphaComponent:0.20];
            dotColor = PPHomeHeroColor(0xFFD36B, 1.0);
            plateBackground = [softAccent colorWithAlphaComponent:0.20];
            railFill = [UIColor colorWithWhite:1.0 alpha:0.12];
            break;

        case PPHomeHeroLocationStateReady:
            break;

        case PPHomeHeroLocationStateUnset:
        default:
            chipBackground = [UIColor colorWithWhite:1.0 alpha:0.16];
            chipBorder = [UIColor colorWithWhite:1.0 alpha:0.12];
            dotColor = [softAccent colorWithAlphaComponent:0.98];
            plateBackground = [UIColor colorWithWhite:1.0 alpha:0.16];
            plateBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
            railFill = [UIColor colorWithWhite:1.0 alpha:0.13];
            railBorder = [UIColor colorWithWhite:1.0 alpha:0.09];
            break;
    }

    void (^updates)(void) = ^{
        self.locationRail.backgroundColor = railFill;
        self.locationRail.layer.borderColor = railBorder.CGColor;
        self.locationPlateView.backgroundColor = plateBackground;
        self.locationPlateView.layer.borderColor = plateBorder.CGColor;
        self.locationPlateView.layer.borderWidth = 1.0;
        self.locationChipView.backgroundColor = chipBackground;
        self.locationChipView.layer.borderColor = chipBorder.CGColor;
        self.locationChipLabel.text = [self pp_locationChipTextForState:self.currentLocationState];
        self.locationChipLabel.textColor = chipTextColor;
        self.locationChipDotView.backgroundColor = dotColor;
        self.locationChevronView.tintColor = [chipTextColor colorWithAlphaComponent:0.88];
    };

    if (animated) {
        [UIView animateWithDuration:0.28 animations:updates];
    } else {
        updates();
    }

    [self pp_setSymbolNamed:[self pp_locationSymbolNameForState:self.currentLocationState]
                onImageView:self.locationIconView
                  pointSize:16.0
                     weight:PPHomeHeroSymbolWeightSemibold];
    [self pp_setSymbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                onImageView:self.locationChevronView
                  pointSize:10.0
                     weight:PPHomeHeroSymbolWeightSemibold];
    [self pp_setSymbolNamed:[self pp_trendingSymbolNameForState:self.currentLocationState]
                onImageView:self.trendingIconView
                  pointSize:12.0
                     weight:PPHomeHeroSymbolWeightSemibold];

    [self pp_updateLocationPulseForState:self.currentLocationState];
}

- (void)pp_applyPaletteForCurrentTimeAnimated:(BOOL)animated force:(BOOL)force
{
    NSDate *now = NSDate.date;
    NSDateComponents *components =
        [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:now];
    NSInteger minutesOfDay = (components.hour * 60) + components.minute;
    if (!force && self.lastRenderedMinute == minutesOfDay) {
        [self pp_updateClockText];
        return;
    }
    self.lastRenderedMinute = minutesOfDay;

    NSArray<NSDictionary<NSString *, id> *> *anchors = PPHomeHeroPaletteAnchors();
    NSDictionary<NSString *, id> *fromPalette = anchors.firstObject;
    NSDictionary<NSString *, id> *toPalette = anchors.lastObject;
    for (NSUInteger idx = 0; idx + 1 < anchors.count; idx++) {
        NSDictionary<NSString *, id> *candidate = anchors[idx];
        NSDictionary<NSString *, id> *next = anchors[idx + 1];
        NSInteger startMinute = [candidate[@"minute"] integerValue];
        NSInteger endMinute = [next[@"minute"] integerValue];
        if (minutesOfDay >= startMinute && minutesOfDay <= endMinute) {
            fromPalette = candidate;
            toPalette = next;
            break;
        }
    }

    NSInteger fromMinute = [fromPalette[@"minute"] integerValue];
    NSInteger toMinute = [toPalette[@"minute"] integerValue];
    CGFloat progress = (toMinute > fromMinute)
        ? ((CGFloat)(minutesOfDay - fromMinute) / (CGFloat)(toMinute - fromMinute))
        : 0.0;

    NSArray<UIColor *> *baseColors =
        PPHomeHeroInterpolateColors(fromPalette[@"colors"], toPalette[@"colors"], progress);
    CGPoint start = PPHomeHeroLerpPoint([fromPalette[@"start"] CGPointValue],
                                        [toPalette[@"start"] CGPointValue],
                                        progress);
    CGPoint end = PPHomeHeroLerpPoint([fromPalette[@"end"] CGPointValue],
                                      [toPalette[@"end"] CGPointValue],
                                      progress);

    UIColor *accent = PPHomeHeroAccentColor(self.paletteLocationSeed);
    UIColor *liftedAccent = PPHomeHeroBlendColors(accent, UIColor.whiteColor, 0.26);
    NSArray<NSNumber *> *mixes = @[@0.04, @0.08, @0.14, @0.20];
    NSMutableArray *gradientColors = [NSMutableArray arrayWithCapacity:baseColors.count];
    NSMutableArray<UIColor *> *resolvedColors = [NSMutableArray arrayWithCapacity:baseColors.count];

    for (NSUInteger idx = 0; idx < baseColors.count; idx++) {
        UIColor *deepened = PPHomeHeroBlendColors(baseColors[idx], UIColor.blackColor, idx == 0 ? 0.18 : 0.10);
        UIColor *resolved = PPHomeHeroBlendColors(deepened,
                                                  (idx >= 2 ? liftedAccent : accent),
                                                  [mixes[idx] doubleValue]);
        [resolvedColors addObject:resolved];
        [gradientColors addObject:(id)resolved.CGColor];
    }

    UIColor *mirrorTop = [PPHomeHeroBlendColors(resolvedColors[1], liftedAccent, 0.38) colorWithAlphaComponent:0.74];
    UIColor *mirrorBottom = [PPHomeHeroBlendColors(resolvedColors.lastObject, UIColor.whiteColor, 0.22) colorWithAlphaComponent:0.42];
    UIColor *shineColor = [UIColor colorWithWhite:1.0 alpha:0.26];
    UIColor *pillColor = [PPHomeHeroBlendColors(resolvedColors[1], UIColor.whiteColor, 0.14) colorWithAlphaComponent:0.22];

    [CATransaction begin];
    [CATransaction setAnimationDuration:(animated ? 0.75 : 0.0)];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    self.backgroundGradientLayer.startPoint = start;
    self.backgroundGradientLayer.endPoint = end;
    self.backgroundGradientLayer.colors = gradientColors;
    self.mirrorGradientLayer.colors = @[
        (id)mirrorTop.CGColor,
        (id)[mirrorBottom colorWithAlphaComponent:0.30].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.06].CGColor
    ];
    self.bottomShadeLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.08].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.24].CGColor
    ];
    self.mirrorShineLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)shineColor.CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    self.mirrorShineLayer.locations = @[@0.12, @0.52, @0.92];
    [CATransaction commit];

    self.trendingPillView.backgroundColor = pillColor;
    self.actionButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.accentOrbView.backgroundColor = [mirrorTop colorWithAlphaComponent:0.24];
    self.secondaryOrbView.backgroundColor = [mirrorBottom colorWithAlphaComponent:0.26];
    self.mirrorStageView.layer.borderColor = [liftedAccent colorWithAlphaComponent:0.20].CGColor;
    self.signalBarA.backgroundColor = [liftedAccent colorWithAlphaComponent:0.52];
    self.signalBarB.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    self.signalBarC.backgroundColor = [accent colorWithAlphaComponent:0.58];
    self.orderPeekTintOverlay.backgroundColor =
        [PPHomeHeroBlendColors(PPHomeHeroColor(0x1A2030, 1.0), accent, 0.24) colorWithAlphaComponent:0.72];

    [self pp_updateClockText];
}

#pragma mark - Live Updates

- (void)pp_startLiveUpdatesIfNeeded
{
    if (self.liveUpdateTimer) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.liveUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            [timer invalidate];
            return;
        }
        [self pp_handleLiveUpdateTick];
    }];
    self.liveUpdateTimer.tolerance = 6.0;
}

- (void)pp_stopLiveUpdates
{
    [self.liveUpdateTimer invalidate];
    self.liveUpdateTimer = nil;
}

- (void)pp_handleLiveUpdateTick
{
    [self pp_applyPaletteForCurrentTimeAnimated:YES force:NO];
}

- (void)pp_updateClockText
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = NSLocale.currentLocale;
        formatter.calendar = NSCalendar.currentCalendar;
        [formatter setLocalizedDateFormatFromTemplate:@"jm"];
    });

    self.clockLabel.text = [formatter stringFromDate:NSDate.date];
}

#pragma mark - Motion

- (void)pp_startAmbientAnimationsIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    if (![self.accentOrbView.layer animationForKey:@"pp.hero.orbA"]) {
        CABasicAnimation *orbA = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        orbA.fromValue = @(0.96);
        orbA.toValue = @(1.04);
        orbA.duration = 7.0;
        orbA.autoreverses = YES;
        orbA.repeatCount = HUGE_VALF;
        orbA.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.accentOrbView.layer addAnimation:orbA forKey:@"pp.hero.orbA"];
    }

    if (![self.secondaryOrbView.layer animationForKey:@"pp.hero.orbB"]) {
        CABasicAnimation *orbB = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        orbB.fromValue = @(0.94);
        orbB.toValue = @(1.06);
        orbB.duration = 8.8;
        orbB.autoreverses = YES;
        orbB.repeatCount = HUGE_VALF;
        orbB.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.secondaryOrbView.layer addAnimation:orbB forKey:@"pp.hero.orbB"];
    }

    if (![self.mirrorShineLayer animationForKey:@"pp.hero.shine"]) {
        CABasicAnimation *shine = [CABasicAnimation animationWithKeyPath:@"opacity"];
        shine.fromValue = @(0.42);
        shine.toValue = @(0.92);
        shine.duration = 3.4;
        shine.autoreverses = YES;
        shine.repeatCount = HUGE_VALF;
        [self.mirrorShineLayer addAnimation:shine forKey:@"pp.hero.shine"];
    }

    [self pp_startSignalBarAnimation:self.signalBarA key:@"pp.hero.barA" duration:1.8 delay:0.0];
    [self pp_startSignalBarAnimation:self.signalBarB key:@"pp.hero.barB" duration:1.3 delay:0.1];
    [self pp_startSignalBarAnimation:self.signalBarC key:@"pp.hero.barC" duration:2.0 delay:0.18];
}

- (void)pp_startSignalBarAnimation:(UIView *)bar
                               key:(NSString *)key
                          duration:(CFTimeInterval)duration
                             delay:(CFTimeInterval)delay
{
    if ([bar.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale.y"];
    pulse.fromValue = @(0.70);
    pulse.toValue = @(1.06);
    pulse.duration = duration;
    pulse.beginTime = CACurrentMediaTime() + delay;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [bar.layer addAnimation:pulse forKey:key];
}

- (void)pp_updateLocationPulseForState:(PPHomeHeroLocationState)state
{
    [self.locationChipDotView.layer removeAnimationForKey:@"pp.hero.location.dot"];
    [self.locationChipView.layer removeAnimationForKey:@"pp.hero.location.chip"];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    if (state != PPHomeHeroLocationStateReady && state != PPHomeHeroLocationStateLoading) {
        return;
    }

    CABasicAnimation *dotPulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    dotPulse.fromValue = @(0.88);
    dotPulse.toValue = @(1.12);
    dotPulse.duration = (state == PPHomeHeroLocationStateLoading ? 0.92 : 1.34);
    dotPulse.autoreverses = YES;
    dotPulse.repeatCount = HUGE_VALF;
    dotPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.locationChipDotView.layer addAnimation:dotPulse forKey:@"pp.hero.location.dot"];

    CABasicAnimation *chipGlow = [CABasicAnimation animationWithKeyPath:@"opacity"];
    chipGlow.fromValue = @(0.84);
    chipGlow.toValue = @(1.0);
    chipGlow.duration = (state == PPHomeHeroLocationStateLoading ? 1.18 : 1.9);
    chipGlow.autoreverses = YES;
    chipGlow.repeatCount = HUGE_VALF;
    chipGlow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.locationChipView.layer addAnimation:chipGlow forKey:@"pp.hero.location.chip"];
}

- (void)pp_runEntranceAnimationIfNeededWithSignature:(NSString *)signature
{
    NSString *safeSignature = PPHomeHeroSafeString(signature);
    if (safeSignature.length == 0 || [self.lastAnimationSignature isEqualToString:safeSignature]) {
        return;
    }
    self.lastAnimationSignature = safeSignature;

    NSArray<UIView *> *animatedViews = @[
        self.trendingPillView,
        self.actionButton,
        self.headlineLabel,
        self.supportLabel,
        self.mirrorStageView,
        self.locationRail
    ];

    for (UIView *view in animatedViews) {
        if (view.hidden) continue;
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    }

    [UIView animateWithDuration:0.34
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.trendingPillView.alpha = 1.0;
        self.trendingPillView.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (!self.actionButton.hidden) {
        [UIView animateWithDuration:0.36
                              delay:0.04
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.actionButton.alpha = 1.0;
            self.actionButton.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    [UIView animateWithDuration:0.52
                          delay:0.08
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.14
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.headlineLabel.alpha = 1.0;
        self.headlineLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.14
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.supportLabel.alpha = 1.0;
        self.supportLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.56
                          delay:0.16
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.mirrorStageView.alpha = 1.0;
        self.mirrorStageView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.58
                          delay:0.20
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.locationRail.alpha = 1.0;
        self.locationRail.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Order Peek

- (void)pp_applyOrderPeekStyleWithStatusColor:(UIColor *)statusColor expanded:(BOOL)expanded
{
    UIColor *resolvedStatusColor = statusColor ?: PPHomeHeroColor(0xF6B24D, 1.0);
    UIColor *tintColor = PPHomeHeroBlendColors(PPHomeHeroColor(0x1A2030, 1.0), resolvedStatusColor, expanded ? 0.38 : 0.28);

    self.orderPeekStatusColor = resolvedStatusColor;
    self.orderPeekExpanded = expanded;
    self.orderPeekTintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:(expanded ? 0.80 : 0.72)];
    self.orderPeekStrip.layer.borderColor = [resolvedStatusColor colorWithAlphaComponent:(expanded ? 0.34 : 0.24)].CGColor;
    self.orderPeekThumbnail.backgroundColor = [resolvedStatusColor colorWithAlphaComponent:(expanded ? 0.24 : 0.16)];
    self.orderPeekStatusDot.backgroundColor = resolvedStatusColor;
    self.orderPeekStatusLabel.textColor = resolvedStatusColor;
    self.orderPeekChevron.tintColor = resolvedStatusColor;
}

- (void)pp_updateOrderPeekChevronForExpanded:(BOOL)expanded animated:(BOOL)animated
{
    void (^updates)(void) = ^{
        self.orderPeekChevron.transform = expanded ? CGAffineTransformMakeRotation((CGFloat)M_PI) : CGAffineTransformIdentity;
    };

    if (!animated) {
        updates();
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:updates
                     completion:nil];
}

- (void)pp_startOrderPeekPulseAnimation
{
    if ([self.orderPeekStatusDot.layer animationForKey:@"pp.orderPeek.dot"]) {
        return;
    }

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @(0.86);
    scale.toValue = @(1.18);

    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @(0.58);
    opacity.toValue = @(1.0);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[scale, opacity];
    group.duration = 1.08;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.orderPeekStatusDot.layer addAnimation:group forKey:@"pp.orderPeek.dot"];
}

- (void)pp_stopOrderPeekPulseAnimation
{
    [self.orderPeekStatusDot.layer removeAnimationForKey:@"pp.orderPeek.dot"];
}

#pragma mark - Accessibility

- (void)pp_updateAccessibility
{
    self.locationRail.accessibilityTraits = UIAccessibilityTraitButton;
    self.locationRail.accessibilityLabel = self.locationTitleLabel.text;
    self.locationRail.accessibilityValue = self.locationChipLabel.text;
    self.locationRail.accessibilityHint = self.currentActionTitle;

    self.actionButton.accessibilityLabel = self.currentActionTitle;
    self.orderPeekStrip.accessibilityTraits = UIAccessibilityTraitButton;
    self.orderPeekStrip.accessibilityLabel = self.orderPeekReferenceLabel.text;
    self.orderPeekStrip.accessibilityValue = self.orderPeekStatusLabel.text;
}

#pragma mark - Interaction

- (void)pp_handleInteractiveDown:(UIView *)sender
{
    [UIView animateWithDuration:PPAnimDurationFast animations:^{
        sender.transform = CGAffineTransformMakeScale(PPTapScaleDown, PPTapScaleDown);
        sender.alpha = 0.92;
    }];
}

- (void)pp_handleInteractiveUp:(UIView *)sender
{
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0.0
         usingSpringWithDamping:PPAnimSpringDamping
          initialSpringVelocity:PPAnimSpringVelocity
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (void)pp_handleLocationTap
{
    if (self.onLocationTap) {
        self.onLocationTap();
        return;
    }
    if (self.onLocationActionTap) {
        self.onLocationActionTap();
    }
}

- (void)pp_handleLocationActionTap
{
    if (self.onLocationActionTap) {
        self.onLocationActionTap();
        return;
    }
    if (self.onLocationTap) {
        self.onLocationTap();
    }
}

- (void)pp_handleOrderPeekTap
{
    if (self.onOrderPeekTap) {
        self.onOrderPeekTap();
    }
}

#pragma mark - Symbols

- (void)pp_setSymbolNamed:(NSString *)symbolName
              onImageView:(UIImageView *)imageView
                pointSize:(CGFloat)pointSize
                   weight:(PPHomeHeroSymbolWeight)weight
{
    if (!imageView) return;

    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolWeight resolvedWeight = UIImageSymbolWeightRegular;
        switch (weight) {
            case PPHomeHeroSymbolWeightMedium:
                resolvedWeight = UIImageSymbolWeightMedium;
                break;
            case PPHomeHeroSymbolWeightSemibold:
                resolvedWeight = UIImageSymbolWeightSemibold;
                break;
            case PPHomeHeroSymbolWeightBold:
                resolvedWeight = UIImageSymbolWeightBold;
                break;
            case PPHomeHeroSymbolWeightRegular:
            default:
                resolvedWeight = UIImageSymbolWeightRegular;
                break;
        }
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:resolvedWeight];
        image = [[UIImage systemImageNamed:symbolName withConfiguration:configuration]
                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    if (!image) {
        image = [[UIImage imageNamed:symbolName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    imageView.image = image;
}

@end
