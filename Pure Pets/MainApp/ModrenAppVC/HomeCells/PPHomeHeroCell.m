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
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CAGradientLayer *ambientGlowLayer;
@property (nonatomic, strong) CAGradientLayer *bottomShadeLayer;
@property (nonatomic, strong) CAGradientLayer *locationTopFadeLayer;
@property (nonatomic, strong) CAGradientLayer *locationLiquidBorderLayer;
@property (nonatomic, strong) CAShapeLayer *locationLiquidBorderMaskLayer;
@property (nonatomic, strong) UIView *orbViewA;
@property (nonatomic, strong) UIView *orbViewB;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UIView *statusPillView;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) UILabel *supportLabel;
@property (nonatomic, strong) UIControl *locationControl;
@property (nonatomic, strong) UIView *locationIconPlateView;
@property (nonatomic, strong) UIImageView *locationIconView;
@property (nonatomic, strong) UILabel *locationTitleLabel;
@property (nonatomic, strong) UILabel *locationMetaLabel;
@property (nonatomic, strong) UIView *locationStatusChipView;
@property (nonatomic, strong) UIView *locationStatusDotView;
@property (nonatomic, strong) UILabel *locationStatusLabel;
@property (nonatomic, strong) UIImageView *locationChevronView;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) NSLayoutConstraint *actionButtonHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *actionButtonWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *orbViewAWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *orbViewAHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *headlineTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *supportTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *supportMaxWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *lottieWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *lottieHeightConstraint;
@property (nonatomic, copy) NSString *paletteLocationSeed;
@property (nonatomic, strong) LOTAnimationView *lottieHeaderView;
@property (nonatomic, copy) NSString *currentLottiePath;
@property (nonatomic, assign) NSInteger lottieLoopToken;
@property (nonatomic, assign) PPHomeHeroLocationState currentLocationState;
@property (nonatomic, copy) NSString *lastAnimationSignature;
@property (nonatomic, assign) CGFloat lastResolvedLayoutWidth;
@property (nonatomic, copy) NSString *currentGreetingText;
@property (nonatomic, copy) NSString *currentUserNameText;

// Order peek strip (one-line banner below hero card)
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
- (void)pp_updateLocationLiquidBorderWithAccent:(UIColor *)accent;
@end

static inline UIColor *PPBlendColors(UIColor *a, UIColor *b, CGFloat t)
{
    if (!a) return b;
    if (!b) return a;
    t = fmax(0.0, fmin(1.0, t));

    CGFloat ar = 0.0, ag = 0.0, ab = 0.0, aa = 0.0;
    CGFloat br = 0.0, bg = 0.0, bb = 0.0, ba = 0.0;

    if (![a getRed:&ar green:&ag blue:&ab alpha:&aa]) {
        CGColorRef c = a.CGColor;
        size_t count = CGColorGetNumberOfComponents(c);
        const CGFloat *components = CGColorGetComponents(c);
        if (count >= 3) {
            ar = components[0];
            ag = components[1];
            ab = components[2];
            aa = (count >= 4 ? components[3] : 1.0);
        }
    }

    if (![b getRed:&br green:&bg blue:&bb alpha:&ba]) {
        CGColorRef c = b.CGColor;
        size_t count = CGColorGetNumberOfComponents(c);
        const CGFloat *components = CGColorGetComponents(c);
        if (count >= 3) {
            br = components[0];
            bg = components[1];
            bb = components[2];
            ba = (count >= 4 ? components[3] : 1.0);
        }
    }

    return [UIColor colorWithRed:(ar + (br - ar) * t)
                           green:(ag + (bg - ag) * t)
                            blue:(ab + (bb - ab) * t)
                           alpha:(aa + (ba - aa) * t)];
}

static inline UIColor *PPLocationAccentColor(NSString *seed)
{
    NSString *safeSeed = PPSafeString(seed);
    if (safeSeed.length == 0) {
        return [UIColor hx_colorWithHexStr:@"#FFC36B" alpha:1.0];
    }

    NSUInteger hash = safeSeed.hash;
    CGFloat hue = (CGFloat)(hash % 360) / 360.0;
    CGFloat saturation = 0.48 + (CGFloat)((hash >> 8) % 28) / 100.0;
    CGFloat brightness = 0.88 + (CGFloat)((hash >> 16) % 9) / 100.0;
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
}

static inline CGFloat PPClampUnit(CGFloat value)
{
    if (!isfinite((double)value)) {
        return 0.0;
    }
    return fmax(0.0, fmin(1.0, value));
}

static inline CGFloat PPLerpFloat(CGFloat start, CGFloat end, CGFloat progress)
{
    if (!isfinite((double)start)) {
        start = 0.0;
    }
    if (!isfinite((double)end)) {
        end = start;
    }
    progress = PPClampUnit(progress);
    return start + ((end - start) * progress);
}

static inline CGPoint PPLerpPoint(CGPoint start, CGPoint end, CGFloat progress)
{
    return CGPointMake(PPLerpFloat(start.x, end.x, progress),
                       PPLerpFloat(start.y, end.y, progress));
}

static inline CGFloat PPHomeHeroResolvedWidth(CGFloat width)
{
    return (isfinite((double)width) && width > 0.0) ? width : UIScreen.mainScreen.bounds.size.width;
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

static inline UIColor *PPHomeHeroColor(uint32_t hex, CGFloat alpha)
{
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >>  8) & 0xFF) / 255.0
                            blue:((hex      ) & 0xFF) / 255.0
                           alpha:alpha];
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
                    PPHomeHeroColor(0x0A0820, 1.0),
                    PPHomeHeroColor(0x12103A, 1.0),
                    PPHomeHeroColor(0x1C1854, 1.0),
                    PPHomeHeroColor(0x251F6E, 1.0),
                    PPHomeHeroColor(0x312882, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.04, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.96, 1.0)]
            },
            @{
                @"minute" : @300,
                @"colors" : @[
                    PPHomeHeroColor(0x0E0C28, 1.0),
                    PPHomeHeroColor(0x1A1444, 1.0),
                    PPHomeHeroColor(0x2E2060, 1.0),
                    PPHomeHeroColor(0x48286A, 1.0),
                    PPHomeHeroColor(0x6A3478, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.06, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.94, 0.98)]
            },
            @{
                @"minute" : @360,
                @"colors" : @[
                    PPHomeHeroColor(0x2A1640, 1.0),
                    PPHomeHeroColor(0x6E2E5C, 1.0),
                    PPHomeHeroColor(0xC05670, 1.0),
                    PPHomeHeroColor(0xF08A5E, 1.0),
                    PPHomeHeroColor(0xFFC26A, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.0, 0.08)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(1.0, 0.90)]
            },
            @{
                @"minute" : @450,
                @"colors" : @[
                    PPHomeHeroColor(0x5E2848, 1.0),
                    PPHomeHeroColor(0xA84860, 1.0),
                    PPHomeHeroColor(0xE87858, 1.0),
                    PPHomeHeroColor(0xFFA94E, 1.0),
                    PPHomeHeroColor(0xFFD878, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.0, 0.06)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.98, 0.94)]
            },
            @{
                @"minute" : @600,
                @"colors" : @[
                    PPHomeHeroColor(0x1858A8, 1.0),
                    PPHomeHeroColor(0x3388D0, 1.0),
                    PPHomeHeroColor(0x50B8E2, 1.0),
                    PPHomeHeroColor(0x78DEC6, 1.0),
                    PPHomeHeroColor(0xF2DA82, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.02, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.98, 1.0)]
            },
            @{
                @"minute" : @780,
                @"colors" : @[
                    PPHomeHeroColor(0x0860B0, 1.0),
                    PPHomeHeroColor(0x1A8CCC, 1.0),
                    PPHomeHeroColor(0x30B8DA, 1.0),
                    PPHomeHeroColor(0x62DCC0, 1.0),
                    PPHomeHeroColor(0xFAE090, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.94, 1.0)]
            },
            @{
                @"minute" : @960,
                @"colors" : @[
                    PPHomeHeroColor(0x2050B8, 1.0),
                    PPHomeHeroColor(0x4874D8, 1.0),
                    PPHomeHeroColor(0x7878D4, 1.0),
                    PPHomeHeroColor(0xC878AE, 1.0),
                    PPHomeHeroColor(0xF5A870, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.04, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.98, 0.98)]
            },
            @{
                @"minute" : @1080,
                @"colors" : @[
                    PPHomeHeroColor(0x2E1870, 1.0),
                    PPHomeHeroColor(0x6C3890, 1.0),
                    PPHomeHeroColor(0xC05098, 1.0),
                    PPHomeHeroColor(0xF08050, 1.0),
                    PPHomeHeroColor(0xFFC05A, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.0, 0.02)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(1.0, 0.86)]
            },
            @{
                @"minute" : @1170,
                @"colors" : @[
                    PPHomeHeroColor(0x101440, 1.0),
                    PPHomeHeroColor(0x1E2868, 1.0),
                    PPHomeHeroColor(0x303E88, 1.0),
                    PPHomeHeroColor(0x5050A0, 1.0),
                    PPHomeHeroColor(0x8860B0, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.04, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.98, 0.96)]
            },
            @{
                @"minute" : @1260,
                @"colors" : @[
                    PPHomeHeroColor(0x0C0E30, 1.0),
                    PPHomeHeroColor(0x181850, 1.0),
                    PPHomeHeroColor(0x2E2468, 1.0),
                    PPHomeHeroColor(0x4C3080, 1.0),
                    PPHomeHeroColor(0x6E3C90, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.06, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.96, 1.0)]
            },
            @{
                @"minute" : @1380,
                @"colors" : @[
                    PPHomeHeroColor(0x080618, 1.0),
                    PPHomeHeroColor(0x0E0C2E, 1.0),
                    PPHomeHeroColor(0x161448, 1.0),
                    PPHomeHeroColor(0x201C5E, 1.0),
                    PPHomeHeroColor(0x2C2472, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.05, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.95, 1.0)]
            },
            @{
                @"minute" : @1440,
                @"colors" : @[
                    PPHomeHeroColor(0x0A0820, 1.0),
                    PPHomeHeroColor(0x12103A, 1.0),
                    PPHomeHeroColor(0x1C1854, 1.0),
                    PPHomeHeroColor(0x251F6E, 1.0),
                    PPHomeHeroColor(0x312882, 1.0)
                ],
                @"start" : [NSValue valueWithCGPoint:CGPointMake(0.04, 0.0)],
                @"end" : [NSValue valueWithCGPoint:CGPointMake(0.96, 1.0)]
            }
        ];
    });
    return anchors;
}

static NSArray<UIColor *> *PPInterpolatePaletteStops(NSArray<UIColor *> *fromColors,
                                                     NSArray<UIColor *> *toColors,
                                                     CGFloat progress)
{
    NSUInteger count = MIN(fromColors.count, toColors.count);
    NSMutableArray<UIColor *> *colors = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger idx = 0; idx < count; idx++) {
        [colors addObject:PPBlendColors(fromColors[idx], toColors[idx], progress)];
    }
    return colors.copy;
}

static inline NSString *PPTrimHeroLine(NSString *line)
{
    NSString *safe = PPSafeString(line);
    safe = [safe stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    safe = [safe stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    return [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
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

    self.heroShadowView = [[UIView alloc] init];
    self.heroShadowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroShadowView.backgroundColor = UIColor.clearColor;
    [self.heroShadowView pp_setShadowColor:[UIColor colorWithWhite:0.03 alpha:1.0]];
    self.heroShadowView.layer.shadowOpacity = 0.10;
    self.heroShadowView.layer.shadowRadius = 24.0;
    self.heroShadowView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    if (@available(iOS 13.0, *)) {
        self.heroShadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.heroShadowView];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = [UIColor hx_colorWithHexStr:@"#17171E" alpha:1.0];
    self.heroSurfaceView.layer.cornerRadius = PPCornerCard + 8.0;
    self.heroSurfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroShadowView addSubview:self.heroSurfaceView];

    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.gradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.gradientLayer.needsDisplayOnBoundsChange = YES;
    [self.heroSurfaceView.layer insertSublayer:self.gradientLayer atIndex:0];

    self.ambientGlowLayer = [CAGradientLayer layer];
    self.ambientGlowLayer.startPoint = CGPointMake(0.1, 0.1);
    self.ambientGlowLayer.endPoint = CGPointMake(0.9, 1.0);
    self.ambientGlowLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    self.ambientGlowLayer.opacity = 0.72;
    self.ambientGlowLayer.hidden = NO;
    [self.heroSurfaceView.layer addSublayer:self.ambientGlowLayer];

    self.bottomShadeLayer = [CAGradientLayer layer];
    self.bottomShadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bottomShadeLayer.endPoint = CGPointMake(0.5, 1.0);
    self.bottomShadeLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.24].CGColor
    ];
    [self.heroSurfaceView.layer addSublayer:self.bottomShadeLayer];

    self.orbViewA = [[UIView alloc] init];
    self.orbViewA.translatesAutoresizingMaskIntoConstraints = NO;
    self.orbViewA.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.orbViewA.userInteractionEnabled = NO;
    [self.heroSurfaceView addSubview:self.orbViewA];

    self.orbViewB = [[UIView alloc] init];
    self.orbViewB.translatesAutoresizingMaskIntoConstraints = NO;
    self.orbViewB.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.04];
    self.orbViewB.userInteractionEnabled = NO;
    [self.heroSurfaceView addSubview:self.orbViewB];

    self.brandLabel = [[UILabel alloc] init];
    self.brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.brandLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.heroSurfaceView addSubview:self.brandLabel];
    self.brandLabel.hidden = NO;
    self.statusPillView = [[UIView alloc] init];
    self.statusPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusPillView.layer.cornerRadius = 15.0;
    self.statusPillView.layer.masksToBounds = YES;
    self.statusPillView.hidden = NO;
    self.brandLabel.alpha = 1.0;
    [self.heroSurfaceView addSubview:self.statusPillView];

    self.statusIconView = [[UIImageView alloc] init];
    self.statusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.statusPillView addSubview:self.statusIconView];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [GM boldFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.statusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    self.statusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.statusPillView addSubview:self.statusLabel];

    self.headlineLabel = [[UILabel alloc] init];
    self.headlineLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headlineLabel.numberOfLines = 2;
    //self.headlineLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.headlineLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.headlineLabel.font = [GM boldFontWithSize:32] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    self.headlineLabel.textColor = UIColor.whiteColor;
    self.headlineLabel.adjustsFontSizeToFitWidth = YES;
    self.headlineLabel.minimumScaleFactor = 0.76;
    self.headlineLabel.allowsDefaultTighteningForTruncation = YES;
   // self.headlineLabel.backgroundColor = UIColor.redColor;
    [self.heroSurfaceView addSubview:self.headlineLabel];

    self.supportLabel = [[UILabel alloc] init];
    self.supportLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.supportLabel.numberOfLines = 2;
    self.supportLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.supportLabel.font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.supportLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    self.supportLabel.adjustsFontSizeToFitWidth = YES;
    self.supportLabel.minimumScaleFactor = 0.84;
    [self.heroSurfaceView addSubview:self.supportLabel];

    self.locationControl = [[UIControl alloc] init];
    self.locationControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
    self.locationControl.layer.cornerRadius = 25;
    self.locationControl.layer.borderWidth = 0.0;
    [self.locationControl pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.0]];
    self.locationControl.layer.masksToBounds = YES;
    self.locationControl.accessibilityTraits = UIAccessibilityTraitButton;
    self.locationControl.exclusiveTouch = YES;
    if (@available(iOS 13.0, *)) {
        self.locationControl.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.locationControl addTarget:self action:@selector(pp_handleLocationTap) forControlEvents:UIControlEventTouchUpInside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    [self.heroSurfaceView addSubview:self.locationControl];

 
    self.locationIconPlateView = [[UIView alloc] init];
    self.locationIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationIconPlateView.userInteractionEnabled = NO;
    self.locationIconPlateView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    self.locationIconPlateView.layer.cornerRadius = 19.0;
    self.locationIconPlateView.layer.borderWidth = 1.0;
    self.locationIconPlateView.layer.masksToBounds = YES;
    [self.locationIconPlateView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    if (@available(iOS 13.0, *)) {
        self.locationIconPlateView.layer.cornerCurve = kCACornerCurveCircular;
    }
    [self.locationControl addSubview:self.locationIconPlateView];

    self.locationIconView = [[UIImageView alloc] init];
    self.locationIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.locationIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    [self.locationIconPlateView addSubview:self.locationIconView];

    self.locationTitleLabel = [[UILabel alloc] init];
    self.locationTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationTitleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.locationTitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    self.locationTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.locationTitleLabel.numberOfLines = 1;
    [self.locationControl addSubview:self.locationTitleLabel];

    self.locationMetaLabel = [[UILabel alloc] init];
    self.locationMetaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationMetaLabel.font = [GM MidFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.locationMetaLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.74];
    self.locationMetaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.locationMetaLabel.numberOfLines = 1;
    self.locationMetaLabel.hidden = YES;
    [self.locationControl addSubview:self.locationMetaLabel];

    self.locationStatusChipView = [[UIView alloc] init];
    self.locationStatusChipView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationStatusChipView.userInteractionEnabled = NO;
    self.locationStatusChipView.hidden = NO;
    self.locationStatusChipView.alpha = 1.0;
    self.locationStatusChipView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    self.locationStatusChipView.layer.cornerRadius = PPCornerMedium;
    self.locationStatusChipView.layer.borderWidth = 1.0;
   // self.locationStatusChipView.layer.borderColor = [UIColor clearColor].CGColor;
    [self.locationStatusChipView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];

    self.locationStatusChipView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.locationStatusChipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.locationControl addSubview:self.locationStatusChipView];

    self.locationStatusDotView = [[UIView alloc] init];
    self.locationStatusDotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationStatusDotView.userInteractionEnabled = NO;
    self.locationStatusDotView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    self.locationStatusDotView.layer.cornerRadius = 4.0;
    [self.locationStatusChipView addSubview:self.locationStatusDotView];

    self.locationStatusLabel = [[UILabel alloc] init];
    self.locationStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationStatusLabel.font = [GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    self.locationStatusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    self.locationStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.locationStatusLabel.numberOfLines = 1;
    self.locationStatusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.locationStatusLabel.adjustsFontSizeToFitWidth = YES;
    self.locationStatusLabel.minimumScaleFactor = 0.86;
    [self.locationStatusChipView addSubview:self.locationStatusLabel];

    self.locationChevronView = [[UIImageView alloc] init];
    self.locationChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationChevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.locationChevronView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.90];
    [self.locationStatusChipView addSubview:self.locationChevronView];

    [self.locationTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                             forAxis:UILayoutConstraintAxisHorizontal];
    [self.locationMetaLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                            forAxis:UILayoutConstraintAxisHorizontal];
    [self.locationStatusChipView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                                 forAxis:UILayoutConstraintAxisHorizontal];
    [self.locationStatusChipView setContentHuggingPriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];

    self.locationTopFadeLayer = [CAGradientLayer layer];
    self.locationTopFadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.locationTopFadeLayer.endPoint = CGPointMake(0.5, 1.0);
    self.locationTopFadeLayer.needsDisplayOnBoundsChange = YES;
    [self.locationControl.layer addSublayer:self.locationTopFadeLayer];

    self.locationLiquidBorderLayer = [CAGradientLayer layer];
    self.locationLiquidBorderLayer.startPoint = CGPointMake(0.0, 0.0);
    self.locationLiquidBorderLayer.endPoint = CGPointMake(1.0, 1.0);
    self.locationLiquidBorderLayer.needsDisplayOnBoundsChange = YES;
    self.locationLiquidBorderMaskLayer = [CAShapeLayer layer];
    self.locationLiquidBorderMaskLayer.fillColor = UIColor.clearColor.CGColor;
    self.locationLiquidBorderMaskLayer.strokeColor = UIColor.whiteColor.CGColor;
    self.locationLiquidBorderMaskLayer.lineWidth = 1.15;
    self.locationLiquidBorderLayer.mask = self.locationLiquidBorderMaskLayer;
    [self.locationControl.layer addSublayer:self.locationLiquidBorderLayer];
    [self pp_updateLocationLiquidBorderWithAccent:PPLocationAccentColor(@"")];

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.layer.cornerRadius = PPButtonHeightLG / 2.0;
    self.actionButton.layer.masksToBounds = YES;
    self.actionButton.layer.borderWidth = 0.85;
    [self.actionButton pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    if (@available(iOS 13.0, *)) {
        self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.actionButton.titleLabel.font = [GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    self.actionButton.contentEdgeInsets = UIEdgeInsetsMake(0, PPSpaceXL, 0, PPSpaceXL);
    [self.actionButton addTarget:self action:@selector(pp_handleLocationActionTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.actionButton addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    [self.heroSurfaceView addSubview:self.actionButton];

    self.lottieHeaderView = [[LOTAnimationView alloc] init];
    self.lottieHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.lottieHeaderView.backgroundColor = UIColor.clearColor;
    self.lottieHeaderView.userInteractionEnabled = NO;
    self.lottieHeaderView.contentMode = UIViewContentModeScaleAspectFill;
    self.lottieHeaderView.alpha = 1.0;
    [self.heroSurfaceView addSubview:self.lottieHeaderView];
    [self.heroSurfaceView bringSubviewToFront:self.statusPillView];
    [self.heroSurfaceView bringSubviewToFront:self.headlineLabel];
    [self.heroSurfaceView bringSubviewToFront:self.supportLabel];

    // ── Order Peek Strip (one-line banner below hero card) ──
    [self pp_buildOrderPeekStrip];

    self.orbViewAWidthConstraint = [self.orbViewA.widthAnchor constraintEqualToConstant:178.0];
    self.orbViewAHeightConstraint = [self.orbViewA.heightAnchor constraintEqualToConstant:178.0];
    self.headlineTrailingConstraint =
        [self.headlineLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-178.0];
    self.supportMaxWidthConstraint =
        [self.supportLabel.widthAnchor constraintLessThanOrEqualToConstant:190.0];
    self.supportTrailingConstraint =
        [self.supportLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-126.0];
    self.lottieWidthConstraint = [self.lottieHeaderView.widthAnchor constraintEqualToConstant:86.0];
    self.lottieHeightConstraint = [self.lottieHeaderView.heightAnchor constraintEqualToConstant:86.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroShadowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.heroShadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.heroShadowView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.heroShadowView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.heroShadowView.topAnchor],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.heroShadowView.leadingAnchor],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.heroShadowView.trailingAnchor],
        [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.heroShadowView.bottomAnchor],

        self.orbViewAWidthConstraint,
        self.orbViewAHeightConstraint,
        [self.orbViewA.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:38.0],
        [self.orbViewA.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:-38.0],

        [self.orbViewB.widthAnchor constraintEqualToConstant:0.0],
        [self.orbViewB.heightAnchor constraintEqualToConstant:0.0],
        [self.orbViewB.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-34.0],
        [self.orbViewB.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:48.0],

        [self.brandLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.brandLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.brandLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-140.0],

        [self.statusPillView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-20.0],
        [self.statusPillView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:16.0],
        [self.statusPillView.heightAnchor constraintEqualToConstant:28.0],

        [self.statusIconView.leadingAnchor constraintEqualToAnchor:self.statusPillView.leadingAnchor constant:11.0],
        [self.statusIconView.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.statusIconView.heightAnchor constraintEqualToConstant:12.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusIconView.trailingAnchor constant:6.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusPillView.trailingAnchor constant:-12.0],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],

        [self.headlineLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.headlineLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:44.0],
        self.headlineTrailingConstraint,

        [self.supportLabel.leadingAnchor constraintEqualToAnchor:self.headlineLabel.leadingAnchor],
        [self.supportLabel.topAnchor constraintEqualToAnchor:self.headlineLabel.bottomAnchor constant:8.0],
        self.supportMaxWidthConstraint,
        self.supportTrailingConstraint,

        [self.locationControl.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:12],
        [self.locationControl.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-12],
        [self.locationControl.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-12],
        [self.locationControl.heightAnchor constraintEqualToConstant:56.0],

        [self.locationIconPlateView.leadingAnchor constraintEqualToAnchor:self.locationControl.leadingAnchor constant:12.0],
        [self.locationIconPlateView.centerYAnchor constraintEqualToAnchor:self.locationControl.centerYAnchor],
        [self.locationIconPlateView.widthAnchor constraintEqualToConstant:32.0],
        [self.locationIconPlateView.heightAnchor constraintEqualToConstant:32.0],

        [self.locationIconView.centerXAnchor constraintEqualToAnchor:self.locationIconPlateView.centerXAnchor],
        [self.locationIconView.centerYAnchor constraintEqualToAnchor:self.locationIconPlateView.centerYAnchor],
        [self.locationIconView.widthAnchor constraintEqualToConstant:15.0],
        [self.locationIconView.heightAnchor constraintEqualToConstant:15.0],

        [self.locationStatusChipView.trailingAnchor constraintEqualToAnchor:self.locationControl.trailingAnchor constant:-10.0],
        [self.locationStatusChipView.centerYAnchor constraintEqualToAnchor:self.locationControl.centerYAnchor],
        [self.locationStatusChipView.heightAnchor constraintEqualToConstant:36.0],
        [self.locationStatusChipView.widthAnchor constraintEqualToConstant:122.0],
       // [self.locationStatusChipView.widthAnchor constraintLessThanOrEqualToAnchor:self.locationControl.widthAnchor multiplier:0.44],

        [self.locationStatusDotView.leadingAnchor constraintEqualToAnchor:self.locationStatusChipView.leadingAnchor constant:12.0],
        [self.locationStatusDotView.centerYAnchor constraintEqualToAnchor:self.locationStatusChipView.centerYAnchor],
        [self.locationStatusDotView.widthAnchor constraintEqualToConstant:8.0],
        [self.locationStatusDotView.heightAnchor constraintEqualToConstant:8.0],

        [self.locationChevronView.trailingAnchor constraintEqualToAnchor:self.locationStatusChipView.trailingAnchor constant:-12.0],
        [self.locationChevronView.centerYAnchor constraintEqualToAnchor:self.locationStatusChipView.centerYAnchor],
        [self.locationChevronView.widthAnchor constraintEqualToConstant:10.0],
        [self.locationChevronView.heightAnchor constraintEqualToConstant:10.0],

        [self.locationStatusLabel.leadingAnchor constraintEqualToAnchor:self.locationStatusDotView.trailingAnchor constant:8.0],
        [self.locationStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.locationChevronView.leadingAnchor constant:-8.0],
        [self.locationStatusLabel.centerYAnchor constraintEqualToAnchor:self.locationStatusChipView.centerYAnchor],

        [self.locationTitleLabel.leadingAnchor constraintEqualToAnchor:self.locationIconPlateView.trailingAnchor constant:14.0],
        [self.locationTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.locationStatusChipView.leadingAnchor constant:-16.0],
        [self.locationTitleLabel.centerYAnchor constraintEqualToAnchor:self.locationControl.centerYAnchor],

        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-18.0],

        [self.lottieHeaderView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-12.0],
        self.lottieWidthConstraint,
        self.lottieHeightConstraint,
        [self.lottieHeaderView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-10.0],
     ]];

    // Peek strip constraints — sits below hero surface, overlapping ~14pt behind it
    {
        static CGFloat const kPeekStripHeight = 38.0;
        static CGFloat const kPeekStripOverlap = 10.0;
        [NSLayoutConstraint activateConstraints:@[
            [self.orderPeekStrip.topAnchor constraintEqualToAnchor:self.heroShadowView.bottomAnchor constant:-kPeekStripOverlap],
            [self.orderPeekStrip.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceLG],
            [self.orderPeekStrip.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceLG],
            [self.orderPeekStrip.heightAnchor constraintEqualToConstant:kPeekStripHeight],
        ]];
    }
    
    

    self.actionButtonHeightConstraint = [self.actionButton.heightAnchor constraintEqualToConstant:0.0];
    self.actionButtonWidthConstraint = [self.actionButton.widthAnchor constraintEqualToConstant:0.0];
    self.actionButtonHeightConstraint.active = YES;
    self.actionButtonWidthConstraint.active = YES;
    self.actionButton.hidden = NO;

    [self pp_applyPaletteForCurrentTime];
    [self pp_startAmbientAnimationsIfNeeded];
     
    self.locationControl.hidden = YES;

    return self;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (self.window) {
        [self pp_startAmbientAnimationsIfNeeded];
        [self pp_updateLocationPulseForState:self.currentLocationState];
        return;
    }

    [self.orbViewA.layer removeAnimationForKey:@"pp.hero.breatheA"];
    [self.orbViewB.layer removeAnimationForKey:@"pp.hero.breatheB"];
    [self.ambientGlowLayer removeAnimationForKey:@"pp.hero.glow"];
    [self.locationStatusDotView.layer removeAnimationForKey:@"pp.hero.location.dotPulse"];
}

- (void)pp_updateAdaptiveLayoutMetrics
{
    if (!self.headlineTrailingConstraint || !self.lottieWidthConstraint) {
        return;
    }

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

    CGFloat lottieSize = tablet ? 144.0 : (widePhone ? 122.0 : (compact ? 104.0 : 118.0));
    CGFloat orbSize = tablet ? 196.0 : (widePhone ? 176.0 : (compact ? 136.0 : 168.0));
    CGFloat reservedTrailingWidth = lottieSize + (tablet ? 34.0 : (compact ? 16.0 : 24.0));
    reservedTrailingWidth = MIN(reservedTrailingWidth, MAX(112.0, width - 140.0));
    CGFloat supportWidth = tablet ? MIN(width * 0.42, 336.0) : (widePhone ? 230.0 : (compact ? 154.0 : 186.0));

    self.orbViewAWidthConstraint.constant = orbSize;
    self.orbViewAHeightConstraint.constant = orbSize;
    self.lottieWidthConstraint.constant = lottieSize;
    self.lottieHeightConstraint.constant = lottieSize;
    self.headlineTrailingConstraint.constant = -reservedTrailingWidth;
    self.supportTrailingConstraint.constant = -(MAX(92.0, reservedTrailingWidth - 28.0));
    self.supportMaxWidthConstraint.constant = supportWidth;

    CGFloat primaryHeadlineSize = tablet ? 36.0 : (widePhone ? 32.0 : (compact ? 27.0 : 32.0));
    CGFloat supportFontSize = tablet ? 14.0 : (widePhone ? 13.0 : (compact ? 11.5 : 12.5));
    CGFloat locationTitleSize = tablet ? 15.0 : (compact ? 13.0 : 14.0);
    CGFloat locationStatusSize = tablet ? 12.0 : (compact ? 10.5 : 11.5);

    self.supportLabel.font = [GM MidFontWithSize:supportFontSize] ?: [UIFont systemFontOfSize:supportFontSize weight:UIFontWeightMedium];
    self.locationTitleLabel.font = [GM boldFontWithSize:locationTitleSize] ?: [UIFont systemFontOfSize:locationTitleSize weight:UIFontWeightSemibold];
    self.locationStatusLabel.font = [GM boldFontWithSize:locationStatusSize] ?: [UIFont systemFontOfSize:locationStatusSize weight:UIFontWeightSemibold];
    self.headlineLabel.font = [GM boldFontWithSize:primaryHeadlineSize] ?: [UIFont systemFontOfSize:primaryHeadlineSize weight:UIFontWeightBold];

    if (self.currentGreetingText.length > 0 || self.currentUserNameText.length > 0) {
        self.headlineLabel.attributedText =
            [self pp_attributedHeadlineWithGreeting:self.currentGreetingText
                                           userName:self.currentUserNameText];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self pp_updateAdaptiveLayoutMetrics];

  
    
    CGRect bounds = self.heroSurfaceView.bounds;
    if (CGRectIsEmpty(bounds) ||
        !isfinite((double)CGRectGetWidth(bounds)) ||
        !isfinite((double)CGRectGetHeight(bounds))) return;

    self.gradientLayer.frame = bounds;
    self.ambientGlowLayer.frame = bounds;
    self.bottomShadeLayer.frame = bounds;

    static CGFloat const kLocationFadeHeight = 16.0;
    CGRect locationBounds = self.locationControl.bounds;
    BOOL hasValidLocationBounds = !CGRectIsEmpty(locationBounds) &&
                                  isfinite((double)CGRectGetWidth(locationBounds)) &&
                                  isfinite((double)CGRectGetHeight(locationBounds));
    if (hasValidLocationBounds) {
        self.locationTopFadeLayer.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(locationBounds), MIN(kLocationFadeHeight, CGRectGetHeight(locationBounds) * 0.5));
        self.locationLiquidBorderLayer.frame = locationBounds;
        self.locationLiquidBorderMaskLayer.frame = locationBounds;
        CGFloat borderRadius = self.locationControl.layer.cornerRadius;
        borderRadius = isfinite((double)borderRadius) ? MAX(0.0, borderRadius - 0.65) : 0.0;
        self.locationLiquidBorderMaskLayer.path =
            [UIBezierPath bezierPathWithRoundedRect:CGRectInset(locationBounds, 0.65, 0.65)
                                      cornerRadius:borderRadius].CGPath;
    } else {
        self.locationTopFadeLayer.frame = CGRectZero;
        self.locationLiquidBorderLayer.frame = CGRectZero;
        self.locationLiquidBorderMaskLayer.frame = CGRectZero;
        self.locationLiquidBorderMaskLayer.path = nil;
    }

    self.heroShadowView.layer.cornerRadius = self.heroSurfaceView.layer.cornerRadius;
    CGRect shadowBounds = self.heroShadowView.bounds;
    CGFloat shadowRadius = self.heroSurfaceView.layer.cornerRadius;
    if (!CGRectIsEmpty(shadowBounds) &&
        isfinite((double)CGRectGetWidth(shadowBounds)) &&
        isfinite((double)CGRectGetHeight(shadowBounds)) &&
        isfinite((double)shadowRadius)) {
        self.heroShadowView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:shadowBounds
                                      cornerRadius:MAX(0.0, shadowRadius)].CGPath;
    } else {
        self.heroShadowView.layer.shadowPath = nil;
    }
    CGFloat iconPlateHeight = CGRectGetHeight(self.locationIconPlateView.bounds);
    self.locationIconPlateView.layer.cornerRadius = (isfinite((double)iconPlateHeight) && iconPlateHeight > 0.0) ? iconPlateHeight * 0.5 : 0.0;

    CGFloat orbAWidth = CGRectGetWidth(self.orbViewA.bounds);
    CGFloat orbBWidth = CGRectGetWidth(self.orbViewB.bounds);
    self.orbViewA.layer.cornerRadius = (isfinite((double)orbAWidth) && orbAWidth > 0.0) ? orbAWidth * 0.5 : 0.0;
    self.orbViewB.layer.cornerRadius = (isfinite((double)orbBWidth) && orbBWidth > 0.0) ? orbBWidth * 0.5 : 0.0;
    self.orderPeekStrip.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    
    self.headlineLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.statusLabel.textAlignment = Language.alignmentForCurrentLanguage;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self pp_updateAdaptiveLayoutMetrics];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
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
    self.currentGreetingText = @"";
    self.currentUserNameText = @"";
    self.lastResolvedLayoutWidth = 0.0;
    self.paletteLocationSeed = @"";
    self.locationTitleLabel.text = @"";
    self.locationMetaLabel.text = @"";
    self.locationStatusLabel.text = @"";
    self.headlineLabel.text = @"";
    self.headlineLabel.attributedText = nil;
    self.supportLabel.text = @"";
    self.statusLabel.text = @"";
    self.actionButton.hidden = YES;
    self.actionButton.alpha = 0.0;
    self.actionButtonHeightConstraint.constant = 0.0;
    self.actionButtonWidthConstraint.constant = 0.0;
    self.locationControl.alpha = 1.0;
    self.locationControl.transform = CGAffineTransformIdentity;
    self.actionButton.transform = CGAffineTransformIdentity;
    self.locationStatusDotView.transform = CGAffineTransformIdentity;
    [self.locationStatusDotView.layer removeAnimationForKey:@"pp.hero.location.dotPulse"];
    self.brandLabel.alpha = 1.0;
    self.brandLabel.transform = CGAffineTransformIdentity;
    self.statusPillView.alpha = 1.0;
    self.statusPillView.transform = CGAffineTransformIdentity;
    self.lottieHeaderView.transform = CGAffineTransformIdentity;

    self.lottieLoopToken += 1;
    [self.lottieHeaderView stop];
    self.currentLottiePath = nil;

    // Reset peek strip
    self.orderPeekVisible = NO;
    self.orderPeekExpanded = NO;
    self.orderPeekStrip.alpha = 0.0;
    self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
    [self.orderPeekStrip pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];
    self.orderPeekThumbnail.image = nil;
    self.orderPeekThumbnail.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    self.orderPeekReferenceLabel.text = @"";
    self.orderPeekStatusLabel.text = @"";
    self.orderPeekStatusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    self.orderPeekStatusDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.76 blue:0.26 alpha:1.0];
    self.orderPeekChevron.tintColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    self.orderPeekChevron.transform = CGAffineTransformIdentity;
    self.orderPeekTintOverlay.backgroundColor = [UIColor colorWithRed:0.12 green:0.10 blue:0.18 alpha:0.65];
    [self pp_stopOrderPeekPulseAnimation];
}

- (void)configureWithGreeting:(NSString *)greeting
                     userName:(NSString *)userName
                     location:(NSString *)location
                locationState:(PPHomeHeroLocationState)locationState
                  actionTitle:(nullable NSString *)actionTitle
{
    NSString *safeGreeting = PPSafeString(greeting);
    NSString *safeUserName = PPTrimHeroLine(userName);
    NSString *safeLocation = PPTrimHeroLine(location);
    NSString *resolvedActionTitle = PPSafeString(actionTitle);

    self.currentGreetingText = safeGreeting;
    self.currentUserNameText = safeUserName;

    self.paletteLocationSeed = safeLocation;
    self.currentLocationState = locationState;

    [self pp_applyPaletteForCurrentTime];
    [self pp_configureBrandLabel];
    [self pp_applyStatusForState:locationState];

    self.headlineLabel.attributedText = [self pp_attributedHeadlineWithGreeting:safeGreeting userName:safeUserName];
    self.supportLabel.text = [self pp_supportTextForLocation:safeLocation state:locationState];
    self.locationTitleLabel.text = safeLocation.length > 0 ? safeLocation : (kLang(@"Select your location") ?: @"Select your location");

    self.locationMetaLabel.text = @"";
    self.locationMetaLabel.hidden = YES;
    self.locationControl.accessibilityLabel = self.locationTitleLabel.text;
    self.locationControl.accessibilityValue = [self pp_locationChipTextForState:locationState];

    [self pp_setSymbolNamed:[self pp_locationSymbolNameForState:locationState]
                onImageView:self.locationIconView
                  pointSize:15.0];
    [self pp_setSymbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                onImageView:self.locationChevronView
                  pointSize:10.0];

    if (resolvedActionTitle.length == 0) {
        resolvedActionTitle = [self pp_defaultActionTitleForState:locationState];
    }
    self.locationControl.accessibilityHint = resolvedActionTitle;
    [self pp_applyLocationState:locationState actionTitle:resolvedActionTitle];

    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%ld|%@",
                           safeGreeting,
                           safeUserName,
                           safeLocation,
                           (long)locationState,
                           resolvedActionTitle];
    [self pp_runEntranceAnimationIfNeededWithSignature:signature];

    [self setNeedsLayout];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_applyPaletteForCurrentTime];
        [self pp_updateLottieForCurrentTimeIfNeeded];
    });
}

#pragma mark - Copy

- (void)pp_configureBrandLabel
{
    NSString *brandText = kLang(@"Hero_Brand") ?: @"Pure Pets";
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = Language.alignmentForCurrentLanguage;
   // paragraph.baseWritingDirection = Language.isRTL ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;

    NSDictionary *attributes = @{
        NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.76],
        NSParagraphStyleAttributeName : paragraph,
        NSFontAttributeName : ([GM boldFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]),
        NSKernAttributeName : Language.isRTL ? @(0.0) : @(1.1)
    };
    self.brandLabel.attributedText = [[NSAttributedString alloc] initWithString:[brandText uppercaseString]
                                                                     attributes:attributes];
}

- (NSString *)pp_headlineTextWithGreeting:(NSString *)greeting
                                 userName:(NSString *)userName
{
    NSArray<NSString *> *rawLines =
        [PPSafeString(greeting) componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *cleanLines = [NSMutableArray arrayWithCapacity:2];
    for (NSString *candidate in rawLines) {
        NSString *trimmed = PPTrimHeroLine(candidate);
        if (trimmed.length > 0) {
            [cleanLines addObject:trimmed];
        }
        if (cleanLines.count == 2) break;
    }

    NSString *line1 = cleanLines.count > 0 ? cleanLines.firstObject : (kLang(@"Hello") ?: @"Hello");
    NSString *line2 = cleanLines.count > 1 ? cleanLines[1] : @"";

    if (userName.length > 0) {
        if (Language.isRTL) {
            return [NSString stringWithFormat:@"%@\nيا %@", line1, userName];
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
    NSString *headline = [self pp_headlineTextWithGreeting:greeting userName:userName];

    // Strip the paw emoji — we replace it with a tinted SF Symbol below
    headline = [headline stringByReplacingOccurrencesOfString:@"\U0001F43E" withString:@""];
    headline = [headline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    NSArray<NSString *> *lines =
        [headline componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    NSString *firstLine = lines.count > 0 ? PPSafeString(lines.firstObject) : @"";
    NSString *secondLine = lines.count > 1 ? PPSafeString(lines[1]) : @"";
    if (secondLine.length == 0 && lines.count > 2) {
        NSMutableArray<NSString *> *tailLines = [NSMutableArray array];
        for (NSUInteger idx = 1; idx < lines.count; idx++) {
            NSString *candidate = PPSafeString(lines[idx]);
            if (candidate.length > 0) {
                [tailLines addObject:candidate];
            }
        }
        secondLine = [tailLines componentsJoinedByString:@" "];
    }

    CGFloat width = PPHomeHeroResolvedWidth(CGRectGetWidth(self.contentView.bounds));
    BOOL compact = PPHomeHeroWidthIsCompact(width);
    BOOL widePhone = PPHomeHeroWidthIsWidePhone(width);
    BOOL tablet = PPHomeHeroWidthIsTablet(width);
    CGFloat firstLineSize = tablet ? 36.0 : (widePhone ? 32.0 : (compact ? 26.0 : 32.0));
    CGFloat secondLineSize = tablet ? 24.0 : (widePhone ? 28.0 : (compact ? 21.0 : 22.0));

    UIFont *firstLineFont = [GM boldFontWithSize:firstLineSize] ?: [UIFont systemFontOfSize:firstLineSize weight:UIFontWeightBold];
    UIFont *secondLineFont = [GM boldFontWithSize:secondLineSize] ?: [UIFont systemFontOfSize:secondLineSize weight:UIFontWeightSemibold];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = Language.alignmentForCurrentLanguage;
    paragraph.baseWritingDirection = Language.isRTL ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.lineSpacing = 1.0;

    UIColor *textColor = UIColor.whiteColor;
    BOOL shouldAppendDecorativeAttachment = YES;
    if (Language.isRTL) {
        if (@available(iOS 18.0, *)) {
            shouldAppendDecorativeAttachment = YES;
        } else {
            shouldAppendDecorativeAttachment = NO;
        }
    }

    NSMutableAttributedString *result =
        [[NSMutableAttributedString alloc] initWithString:firstLine
                                               attributes:@{
        NSFontAttributeName : firstLineFont,
        NSForegroundColorAttributeName : textColor,
        NSParagraphStyleAttributeName : paragraph
    }];

    if (secondLine.length > 0) {
        NSAttributedString *secondLineAttributed =
            [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", secondLine]
                                            attributes:@{
            NSFontAttributeName : secondLineFont,
            NSForegroundColorAttributeName : [textColor colorWithAlphaComponent:0.90],
            NSParagraphStyleAttributeName : paragraph
        }];
        [result appendAttributedString:secondLineAttributed];
        if (shouldAppendDecorativeAttachment) {
            [result appendAttributedString:[self pp_tintedPawAttachmentForFont:secondLineFont color:textColor]];
        }
    } else if (firstLine.length > 0 && shouldAppendDecorativeAttachment) {
        [result appendAttributedString:[self pp_tintedPawAttachmentForFont:firstLineFont color:textColor]];
    }

    return result;
}

/// Builds a tinted pawprint SF Symbol attachment that matches the greeting text color.
- (NSAttributedString *)pp_tintedPawAttachmentForFont:(UIFont *)font color:(UIColor *)color
{
    // Randomly pick a pet-themed icon on each call
    static NSArray<NSString *> *iconNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iconNames = @[@"pawprint1", @"pawprint2", @"pawprint3", @"pawprint4", @"pawprint5",  ];
    });
    NSString *iconSeed = self.currentUserNameText.length > 0
        ? self.currentUserNameText
        : self.currentGreetingText;
    NSUInteger iconIndex = iconNames.count > 0 ? (iconSeed.hash % iconNames.count) : 0;
    NSString *chosenName = iconNames[iconIndex];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    CGFloat iconSize = font.pointSize * 0.82;

    // Try custom asset first, fall back to SF Symbol
    UIImage *icon = [UIImage imageNamed:chosenName];
    if (icon) {
        // Force template rendering so the greeting text color is applied as tint
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        icon = [self pp_resizeImage:icon toSize:CGSizeMake(iconSize, iconSize) tintColor:color];
    } else {
        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:iconSize
                                                            weight:UIImageSymbolWeightSemibold];
        icon = [[UIImage systemImageNamed:chosenName withConfiguration:config]
                imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    attachment.image = icon;
    attachment.bounds = CGRectMake(0.0, font.descender * 0.3, iconSize, iconSize);

    NSMutableAttributedString *pawString =
        [[NSMutableAttributedString alloc] initWithString:@" "];
    [pawString appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
    [pawString addAttributes:@{
        NSForegroundColorAttributeName : color,
        NSFontAttributeName : font
    } range:NSMakeRange(0, pawString.length)];
    return pawString;
}

/// Resize a raster image and force-tint it to the greeting text color.
- (UIImage *)pp_resizeImage:(UIImage *)image toSize:(CGSize)size tintColor:(UIColor *)tintColor
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    // Draw the image as a mask, then fill with the greeting text color
    CGContextTranslateCTM(ctx, 0, size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGContextClipToMask(ctx, CGRectMake(0, 0, size.width, size.height), image.CGImage);
    [tintColor setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [result imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (NSString *)pp_statusTextForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return kLang(@"Hero_FindingNearby") ?: @"Finding nearby";
        case PPHomeHeroLocationStateDenied:
            return kLang(@"Hero_LocationNeeded") ?: @"Location needed";
        case PPHomeHeroLocationStateReady:
            return kLang(@"Hero_Brand") ?: @"Hero_Brand";
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
            NSString *safeLocation = PPTrimHeroLine(location);
            if (safeLocation.length > 0 &&
                ![safeLocation isEqualToString:(kLang(@"Select your location") ?: @"Select your location")]) {
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

- (NSString *)pp_locationChipTextForState:(PPHomeHeroLocationState)state
{
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            return kLang(@"Hero_LocationChipLoading") ?: @"Locating";
        case PPHomeHeroLocationStateDenied:
            return kLang(@"Hero_LocationChipDenied") ?: @"Allow access";
        case PPHomeHeroLocationStateReady:
            return kLang(@"Hero_LocationChipReady") ?: @"Change your location";
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

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyPaletteForCurrentTime];
            [self pp_applyStatusForState:self.currentLocationState];
            [self pp_refreshBorderColors];
        }
    }
}

- (void)pp_refreshBorderColors
{
    [self.locationControl pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    [self.locationIconPlateView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.08]];
    [self.locationStatusChipView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.11]];
    [self.actionButton pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    [self.orderPeekStrip pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];
    
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    [self.heroShadowView pp_setShadowColor:[UIColor colorWithWhite:0.03 alpha:(isDark ? 0.56 : 0.34)]];
    self.heroShadowView.layer.shadowOpacity = isDark ? 0.14 : 0.09;
    self.heroShadowView.layer.shadowRadius = 24.0;
    self.heroShadowView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
}

#pragma mark - State Styling

- (void)pp_applyStatusForState:(PPHomeHeroLocationState)state
{
    NSString *iconName = @"flame.fill";
    switch (state) {
        case PPHomeHeroLocationStateLoading:
            iconName = @"location.north.line.fill";
            break;
        case PPHomeHeroLocationStateDenied:
            iconName = @"location.slash.fill";
            break;
        case PPHomeHeroLocationStateReady:
            iconName = @"flame.fill";
            break;
        case PPHomeHeroLocationStateUnset:
        default:
            iconName = @"map.fill";
            break;
    }

    self.statusLabel.text = [self pp_statusTextForState:state];
    [self pp_setSymbolNamed:iconName onImageView:self.statusIconView pointSize:12.0];
    UIColor *accent = PPLocationAccentColor(self.paletteLocationSeed);
    UIColor *liftedAccent = PPBlendColors(accent, UIColor.whiteColor, 0.26);
    self.statusIconView.tintColor = liftedAccent ?: AppForgroundColr;
}

- (void)pp_applyLocationState:(PPHomeHeroLocationState)locationState
                  actionTitle:(nullable NSString *)actionTitle
{
    self.currentLocationState = locationState;
    (void)actionTitle;
    self.actionButton.hidden = YES;
    self.actionButton.alpha = 0.0;
    self.actionButtonHeightConstraint.constant = 0.0;
    self.actionButtonWidthConstraint.constant = 0.0;
    [self.actionButton setTitle:@"" forState:UIControlStateNormal];

    UIColor *accent = PPLocationAccentColor(self.paletteLocationSeed);
    UIColor *liftedAccent = PPBlendColors(accent, UIColor.whiteColor, 0.26);
    UIColor *glassFill = [UIColor colorWithWhite:1.0 alpha:0.13];
    UIColor *glassBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
    UIColor *iconPlateFill = [UIColor colorWithWhite:1.0 alpha:0.17];
    UIColor *iconPlateBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
    UIColor *accentWashFill = [UIColor colorWithWhite:1.0 alpha:0.08];
    UIColor *chipFill = [UIColor colorWithWhite:1.0 alpha:0.17];
    UIColor *chipBorder = [UIColor colorWithWhite:1.0 alpha:0.11];
    UIColor *chipTextColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    UIColor *dotColor = [liftedAccent colorWithAlphaComponent:0.98];

    switch (locationState) {
        case PPHomeHeroLocationStateDenied:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.11];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            iconPlateFill = [UIColor colorWithWhite:1.0 alpha:0.16];
            iconPlateBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            accentWashFill = [UIColor colorWithWhite:1.0 alpha:0.10];
            chipFill = [UIColor colorWithWhite:1.0 alpha:0.92];
            chipBorder = [UIColor colorWithWhite:1.0 alpha:0.0];
            chipTextColor = [UIColor hx_colorWithHexStr:@"#151725" alpha:1.0];
            dotColor = [UIColor hx_colorWithHexStr:@"#FF8C54" alpha:1.0];
            break;

        case PPHomeHeroLocationStateLoading:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.11];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            iconPlateFill = [UIColor colorWithWhite:1.0 alpha:0.17];
            iconPlateBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
            accentWashFill = [UIColor colorWithWhite:1.0 alpha:0.12];
            chipFill = [UIColor colorWithWhite:1.0 alpha:0.20];
            chipBorder = [UIColor colorWithWhite:1.0 alpha:0.12];
            dotColor = [UIColor hx_colorWithHexStr:@"#FFD36B" alpha:1.0];
            break;

        case PPHomeHeroLocationStateReady:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.13];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
            iconPlateFill = [UIColor colorWithWhite:1.0 alpha:0.20];
            iconPlateBorder = [UIColor colorWithWhite:1.0 alpha:0.12];
            accentWashFill = [UIColor colorWithWhite:1.0 alpha:0.10];
            chipFill = [UIColor colorWithWhite:1.0 alpha:0.17];
            chipBorder = [UIColor colorWithWhite:1.0 alpha:0.11];
            dotColor = [UIColor colorWithWhite:1.0 alpha:0.96];
            break;
        case PPHomeHeroLocationStateUnset:
        default:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.13];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.09];
            iconPlateFill = [UIColor colorWithWhite:1.0 alpha:0.15];
            iconPlateBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            accentWashFill = [UIColor colorWithWhite:1.0 alpha:0.06];
            chipFill = [UIColor colorWithWhite:1.0 alpha:0.18];
            chipBorder = [UIColor colorWithWhite:1.0 alpha:0.12];
            break;
    }

    self.locationControl.backgroundColor = glassFill;
    self.locationTopFadeLayer.colors = @[
        (id)glassFill.CGColor,
        (id)[glassFill colorWithAlphaComponent:0.0].CGColor
    ];
    [self.locationControl pp_setBorderColor:glassBorder];
    [self pp_updateLocationLiquidBorderWithAccent:accent];
    self.locationIconPlateView.backgroundColor = iconPlateFill;
    [self.locationIconPlateView pp_setBorderColor:iconPlateBorder];
    self.locationStatusChipView.backgroundColor = chipFill;
    [self.locationStatusChipView pp_setBorderColor:chipBorder];
    self.locationStatusLabel.text = [self pp_locationChipTextForState:locationState];
    self.locationStatusLabel.textColor = chipTextColor;
    self.locationStatusDotView.backgroundColor = dotColor;
    self.locationChevronView.tintColor = [chipTextColor colorWithAlphaComponent:(locationState == PPHomeHeroLocationStateDenied ? 0.72 : 0.88)];
    self.locationIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:(locationState == PPHomeHeroLocationStateDenied ? 0.94 : 0.98)];
    [self pp_updateLocationPulseForState:locationState];
}

- (void)pp_updateLocationLiquidBorderWithAccent:(UIColor *)accent
{
    UIColor *resolvedAccent = accent ?: UIColor.whiteColor;
    self.locationLiquidBorderLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.84].CGColor,
        (id)[resolvedAccent colorWithAlphaComponent:0.42].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.72].CGColor
    ];
    self.locationLiquidBorderLayer.locations = @[@0.0, @0.32, @0.66, @1.0];

    if (!UIAccessibilityIsReduceMotionEnabled() &&
        ![self.locationLiquidBorderLayer animationForKey:@"pp.hero.location.liquidBorder"]) {
        CABasicAnimation *shimmer = [CABasicAnimation animationWithKeyPath:@"locations"];
        shimmer.fromValue = @[@-0.34, @0.0, @0.34, @0.68];
        shimmer.toValue = @[@0.32, @0.66, @1.0, @1.34];
        shimmer.duration = 5.6;
        shimmer.repeatCount = HUGE_VALF;
        [self.locationLiquidBorderLayer addAnimation:shimmer forKey:@"pp.hero.location.liquidBorder"];
    }
}

#pragma mark - Palette

- (void)pp_applyPaletteForCurrentTime
{
    NSDate *now = NSDate.date;
    NSDateComponents *components =
        [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                        fromDate:now];
    NSInteger minutesOfDay = (components.hour * 60) + components.minute;
    UIColor *accent = PPLocationAccentColor(self.paletteLocationSeed);
    UIColor *liftedAccent = PPBlendColors(accent, UIColor.whiteColor, 0.22);

    NSArray<NSDictionary<NSString *, id> *> *paletteAnchors = PPHomeHeroPaletteAnchors();

    NSDictionary<NSString *, id> *fromPalette = paletteAnchors.firstObject;
    NSDictionary<NSString *, id> *toPalette = paletteAnchors.lastObject;
    for (NSUInteger idx = 0; idx + 1 < paletteAnchors.count; idx++) {
        NSDictionary<NSString *, id> *candidate = paletteAnchors[idx];
        NSDictionary<NSString *, id> *next = paletteAnchors[idx + 1];
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
    CGFloat paletteProgress =
        (toMinute > fromMinute)
            ? ((CGFloat)(minutesOfDay - fromMinute) / (CGFloat)(toMinute - fromMinute))
            : 0.0;

    NSArray<UIColor *> *baseColors =
        PPInterpolatePaletteStops(fromPalette[@"colors"], toPalette[@"colors"], paletteProgress);
    CGPoint start =
        PPLerpPoint([fromPalette[@"start"] CGPointValue],
                    [toPalette[@"start"] CGPointValue],
                    paletteProgress);
    CGPoint end =
        PPLerpPoint([fromPalette[@"end"] CGPointValue],
                    [toPalette[@"end"] CGPointValue],
                    paletteProgress);

    NSArray<NSNumber *> *accentMixes = @[@0.04, @0.08, @0.14, @0.22, @0.18];
    NSMutableArray<UIColor *> *resolvedColors = [NSMutableArray arrayWithCapacity:baseColors.count];
    NSMutableArray *gradientColors = [NSMutableArray arrayWithCapacity:baseColors.count];
    for (NSUInteger idx = 0; idx < baseColors.count; idx++) {
        UIColor *base = baseColors[idx];
        CGFloat deepenMix = (idx == 0) ? 0.08 : (idx == baseColors.count - 1 ? 0.03 : 0.05);
        UIColor *deepened = PPBlendColors(base, UIColor.blackColor, deepenMix);
        UIColor *accentSource = (idx >= 3) ? liftedAccent : accent;
        UIColor *resolved =
            PPBlendColors(deepened, accentSource, [accentMixes[idx] doubleValue]);
        [resolvedColors addObject:resolved];
        [gradientColors addObject:(id)resolved.CGColor];
    }

    UIColor *glowPrimary =
        [PPBlendColors(resolvedColors[2], liftedAccent, 0.38) colorWithAlphaComponent:0.36];
    UIColor *glowSecondary =
        [PPBlendColors(resolvedColors[4], liftedAccent, 0.30) colorWithAlphaComponent:0.28];
    UIColor *statusPillFill =
        [PPBlendColors(resolvedColors[1], UIColor.whiteColor, 0.16) colorWithAlphaComponent:0.24];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.gradientLayer.startPoint = start;
    self.gradientLayer.endPoint = end;
    self.gradientLayer.colors = gradientColors;
    self.gradientLayer.locations = @[@0.0, @0.16, @0.42, @0.74, @1.0];
    self.ambientGlowLayer.colors = @[
        (id)glowPrimary.CGColor,
        (id)[glowSecondary colorWithAlphaComponent:0.12].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    self.bottomShadeLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.06].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.22].CGColor
    ];
    [CATransaction commit];

    self.orbViewA.backgroundColor = [glowPrimary colorWithAlphaComponent:0.20];
    self.orbViewB.backgroundColor = [glowSecondary colorWithAlphaComponent:0.22];
    self.statusPillView.backgroundColor = statusPillFill;
    self.brandLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.80];
}

#pragma mark - Motion

- (void)pp_startAmbientAnimationsIfNeeded
{
    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    if ([self.orbViewA.layer animationForKey:@"pp.hero.breatheA"]) {
        return;
    }

    CABasicAnimation *breatheA = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    breatheA.fromValue = @(0.98);
    breatheA.toValue = @(1.03);
    breatheA.duration = 7.2;
    breatheA.autoreverses = YES;
    breatheA.repeatCount = HUGE_VALF;
    breatheA.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.orbViewA.layer addAnimation:breatheA forKey:@"pp.hero.breatheA"];

    CABasicAnimation *breatheB = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    breatheB.fromValue = @(0.97);
    breatheB.toValue = @(1.04);
    breatheB.duration = 8.6;
    breatheB.autoreverses = YES;
    breatheB.repeatCount = HUGE_VALF;
    breatheB.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.orbViewB.layer addAnimation:breatheB forKey:@"pp.hero.breatheB"];

    CABasicAnimation *glow = [CABasicAnimation animationWithKeyPath:@"opacity"];
    glow.fromValue = @(0.58);
    glow.toValue = @(0.82);
    glow.duration = 7.4;
    glow.autoreverses = YES;
    glow.repeatCount = HUGE_VALF;
    [self.ambientGlowLayer addAnimation:glow forKey:@"pp.hero.glow"];
}

- (void)pp_updateLocationPulseForState:(PPHomeHeroLocationState)state
{
    [self.locationStatusDotView.layer removeAnimationForKey:@"pp.hero.location.dotPulse"];
    self.locationStatusDotView.transform = CGAffineTransformIdentity;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    if (state != PPHomeHeroLocationStateReady && state != PPHomeHeroLocationStateLoading) {
        return;
    }

    CABasicAnimation *dotPulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    dotPulse.fromValue = @(0.92);
    dotPulse.toValue = @(1.14);
    dotPulse.duration = (state == PPHomeHeroLocationStateLoading ? 0.92 : 1.38);
    dotPulse.autoreverses = YES;
    dotPulse.repeatCount = HUGE_VALF;
    dotPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.locationStatusDotView.layer addAnimation:dotPulse forKey:@"pp.hero.location.dotPulse"];

    CABasicAnimation *washPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    washPulse.fromValue = @(0.72);
    washPulse.toValue = @(1.0);
    washPulse.duration = (state == PPHomeHeroLocationStateLoading ? 1.4 : 2.1);
    washPulse.autoreverses = YES;
    washPulse.repeatCount = HUGE_VALF;
    washPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
}

- (void)pp_runEntranceAnimationIfNeededWithSignature:(NSString *)signature
{
    NSString *safeSignature = PPSafeString(signature);
    if (safeSignature.length == 0 || [self.lastAnimationSignature isEqualToString:safeSignature]) {
        return;
    }
    self.lastAnimationSignature = safeSignature;

    NSArray<UIView *> *animatedViews = @[
        self.brandLabel,
        self.statusPillView,
        self.headlineLabel,
        self.supportLabel,
        self.locationControl
    ];

    for (UIView *view in animatedViews) {
        if (view.hidden) continue;
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    }

    [UIView animateWithDuration:0.45
                          delay:0.00
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.brandLabel.alpha = 1.0;
        self.brandLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.44
                          delay:0.04
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.10
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.statusPillView.alpha = 1.0;
        self.statusPillView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.62
                          delay:0.08
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.headlineLabel.alpha = 1.0;
        self.headlineLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.56
                          delay:0.13
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.supportLabel.alpha = 1.0;
        self.supportLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.58
                          delay:0.18
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.14
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.locationControl.alpha = 1.0;
        self.locationControl.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (!self.actionButton.hidden) {
        [UIView animateWithDuration:0.58
                              delay:0.22
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.14
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.actionButton.alpha = 1.0;
            self.actionButton.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

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

#pragma mark - Actions

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

#pragma mark - Symbols

- (void)pp_setSymbolNamed:(NSString *)symbolName
              onImageView:(UIImageView *)imageView
                pointSize:(CGFloat)pointSize
{
    if (!imageView) return;

    UIImage *symbol = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightSemibold];
        symbol = [[UIImage systemImageNamed:symbolName]
                  imageByApplyingSymbolConfiguration:configuration];
        symbol = [symbol imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    imageView.image = symbol;
}

#pragma mark - Lottie

- (void)pp_playLottieLoopWithDelay2s
{
    self.lottieLoopToken += 1;
    NSInteger token = self.lottieLoopToken;

    self.lottieHeaderView.hidden = NO;
    self.lottieHeaderView.alpha = 1;

    [self.lottieHeaderView stop];
    self.lottieHeaderView.loopAnimation = NO;
    self.lottieHeaderView.animationProgress = 0.0;

    __weak typeof(self) weakSelf = self;
    [self.lottieHeaderView playWithCompletion:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.lottieLoopToken != token) {
                return;
            }

            NSTimeInterval delay = finished ? 2.0 : 0.5;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) innerSelf = weakSelf;
                if (!innerSelf || innerSelf.lottieLoopToken != token) {
                    return;
                }
                [innerSelf pp_playLottieLoopWithDelay2s];
            });
        });
    }];
}

- (NSString *)pp_lottieFirebasePathForCurrentTime
{
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:NSDate.date];

    if (hour < 9) {
        return @"Woman playing with a dog";
    }
    if (hour < 12) {
        return @"Boy Giving Food To Bird";
    }
    if (hour < 17) {
        return @"Man playing with a dog";
    }
    if (hour < 20) {
        return @"Womanlovingpetcats";//Boy Giving Food To Rabbit New //Loader cat  //Loader cat new
    }
    if (hour < 23) {
        return @"evening chair cat and girl";
    }
    return @"man playing with cat during free time";
}

- (void)pp_updateLottieForCurrentTimeIfNeeded
{
    NSString *path = [self pp_lottieFirebasePathForCurrentTime];
    if (path.length == 0) return;

    if (self.currentLottiePath.length > 0 && [self.currentLottiePath isEqualToString:path]) {
        if (!self.lottieHeaderView.isAnimationPlaying) {
            [self pp_playLottieLoopWithDelay2s];
        }
        return;
    }

    self.currentLottiePath = path;
    self.lottieHeaderView.alpha = 0.90;
    __weak typeof(self) weakSelf = self;
    NSString *storagePath = [NSString stringWithFormat:@"LottieAnimations/%@.json", path];
    [AppClasses fetchLottieJSONFromFirebasePath:storagePath completion:^(NSDictionary * _Nonnull jsonDict,
                                                                        NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                strongSelf.currentLottiePath = nil;
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                strongSelf.currentLottiePath = nil;
                return;
            }

            [strongSelf.lottieHeaderView setSceneModel:composition];
            [strongSelf.lottieHeaderView setNeedsLayout];
            [strongSelf.lottieHeaderView layoutIfNeeded];
            [strongSelf.heroSurfaceView bringSubviewToFront:strongSelf.lottieHeaderView];
            [strongSelf pp_playLottieLoopWithDelay2s];
        });
    }];
}

#pragma mark - Order Peek Strip

- (void)pp_buildOrderPeekStrip
{
    // Container — tappable control, inserted BEHIND the hero surface
    self.orderPeekStrip = [[UIControl alloc] init];
    self.orderPeekStrip.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekStrip.backgroundColor = UIColor.clearColor;
    self.orderPeekStrip.layer.cornerRadius = PPCornerMedium;
    self.orderPeekStrip.layer.borderWidth = 1.0;
    [self.orderPeekStrip pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];
    self.orderPeekStrip.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.orderPeekStrip.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.orderPeekStrip.alpha = 0.0;
    self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleOrderPeekTap) forControlEvents:UIControlEventTouchUpInside];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.orderPeekStrip addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    // Insert behind heroShadowView so the overlap is hidden
    [self.contentView insertSubview:self.orderPeekStrip belowSubview:self.heroShadowView];

    // Blur background
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    self.orderPeekBlurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.orderPeekBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekBlurView.userInteractionEnabled = NO;
    [self.orderPeekStrip addSubview:self.orderPeekBlurView];

    // Warm overlay tint
    self.orderPeekTintOverlay = [[UIView alloc] init];
    self.orderPeekTintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekTintOverlay.backgroundColor = [UIColor colorWithRed:0.12 green:0.10 blue:0.18 alpha:0.65];
    self.orderPeekTintOverlay.userInteractionEnabled = NO;
    [self.orderPeekStrip addSubview:self.orderPeekTintOverlay];

    // Thumbnail (small circular image)
    self.orderPeekThumbnail = [[UIImageView alloc] init];
    self.orderPeekThumbnail.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekThumbnail.contentMode = UIViewContentModeScaleAspectFill;
    self.orderPeekThumbnail.clipsToBounds = YES;
    self.orderPeekThumbnail.layer.cornerRadius = 11.0;
    self.orderPeekThumbnail.layer.masksToBounds = YES;
    self.orderPeekThumbnail.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [self.orderPeekStrip addSubview:self.orderPeekThumbnail];

    // Order reference label
    self.orderPeekReferenceLabel = [[UILabel alloc] init];
    self.orderPeekReferenceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekReferenceLabel.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.orderPeekReferenceLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.94];
    self.orderPeekReferenceLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.orderPeekReferenceLabel.numberOfLines = 1;
    self.orderPeekReferenceLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.orderPeekStrip addSubview:self.orderPeekReferenceLabel];

    // Status dot
    self.orderPeekStatusDot = [[UIView alloc] init];
    self.orderPeekStatusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekStatusDot.layer.cornerRadius = 3.0;
    self.orderPeekStatusDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.76 blue:0.26 alpha:1.0];
    [self.orderPeekStrip addSubview:self.orderPeekStatusDot];

    // Status label
    self.orderPeekStatusLabel = [[UILabel alloc] init];
    self.orderPeekStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekStatusLabel.font = [GM MidFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.orderPeekStatusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    self.orderPeekStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.orderPeekStatusLabel.numberOfLines = 1;
    [self.orderPeekStrip addSubview:self.orderPeekStatusLabel];

    // Chevron
    self.orderPeekChevron = [[UIImageView alloc] init];
    self.orderPeekChevron.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderPeekChevron.contentMode = UIViewContentModeScaleAspectFit;
    self.orderPeekChevron.tintColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    NSString *chevronName = @"chevron.down";
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:10.0 weight:UIImageSymbolWeightSemibold];
        self.orderPeekChevron.image = [UIImage systemImageNamed:chevronName withConfiguration:config];
    }
    [self.orderPeekStrip addSubview:self.orderPeekChevron];

    // Constraints for blur + tint overlay (fill)
    [NSLayoutConstraint activateConstraints:@[
        [self.orderPeekBlurView.topAnchor constraintEqualToAnchor:self.orderPeekStrip.topAnchor],
        [self.orderPeekBlurView.leadingAnchor constraintEqualToAnchor:self.orderPeekStrip.leadingAnchor],
        [self.orderPeekBlurView.trailingAnchor constraintEqualToAnchor:self.orderPeekStrip.trailingAnchor],
        [self.orderPeekBlurView.bottomAnchor constraintEqualToAnchor:self.orderPeekStrip.bottomAnchor],

        [self.orderPeekTintOverlay.topAnchor constraintEqualToAnchor:self.orderPeekStrip.topAnchor],
        [self.orderPeekTintOverlay.leadingAnchor constraintEqualToAnchor:self.orderPeekStrip.leadingAnchor],
        [self.orderPeekTintOverlay.trailingAnchor constraintEqualToAnchor:self.orderPeekStrip.trailingAnchor],
        [self.orderPeekTintOverlay.bottomAnchor constraintEqualToAnchor:self.orderPeekStrip.bottomAnchor],
    ]];

    // Content constraints
    CGFloat hPad = 14.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.orderPeekThumbnail.leadingAnchor constraintEqualToAnchor:self.orderPeekStrip.leadingAnchor constant:hPad],
        [self.orderPeekThumbnail.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekThumbnail.widthAnchor constraintEqualToConstant:22.0],
        [self.orderPeekThumbnail.heightAnchor constraintEqualToConstant:22.0],

        [self.orderPeekReferenceLabel.leadingAnchor constraintEqualToAnchor:self.orderPeekThumbnail.trailingAnchor constant:PPSpaceSM],
        [self.orderPeekReferenceLabel.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekReferenceLabel.widthAnchor constraintLessThanOrEqualToConstant:160.0],

        [self.orderPeekStatusDot.leadingAnchor constraintEqualToAnchor:self.orderPeekReferenceLabel.trailingAnchor constant:PPSpaceSM],
        [self.orderPeekStatusDot.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekStatusDot.widthAnchor constraintEqualToConstant:6.0],
        [self.orderPeekStatusDot.heightAnchor constraintEqualToConstant:6.0],

        [self.orderPeekStatusLabel.leadingAnchor constraintEqualToAnchor:self.orderPeekStatusDot.trailingAnchor constant:PPSpaceXS],
        [self.orderPeekStatusLabel.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.orderPeekChevron.leadingAnchor constant:-PPSpaceSM],

        [self.orderPeekChevron.trailingAnchor constraintEqualToAnchor:self.orderPeekStrip.trailingAnchor constant:-hPad],
        [self.orderPeekChevron.centerYAnchor constraintEqualToAnchor:self.orderPeekStrip.centerYAnchor],
        [self.orderPeekChevron.widthAnchor constraintEqualToConstant:10.0],
        [self.orderPeekChevron.heightAnchor constraintEqualToConstant:10.0],
    ]];
}

- (void)pp_handleOrderPeekTap
{
    if (self.onOrderPeekTap) {
        self.onOrderPeekTap();
    }
}

- (void)pp_stopOrderPeekPulseAnimation
{
    [self.orderPeekStatusDot.layer removeAnimationForKey:@"pp.orderPeek.dotPulse"];
    [self.orderPeekTintOverlay.layer removeAnimationForKey:@"pp.orderPeek.tintPulse"];
}

- (void)pp_startOrderPeekPulseAnimation
{
    if ([self.orderPeekStatusDot.layer animationForKey:@"pp.orderPeek.dotPulse"] == nil) {
        CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scaleAnimation.fromValue = @(0.86);
        scaleAnimation.toValue = @(1.18);

        CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacityAnimation.fromValue = @(0.58);
        opacityAnimation.toValue = @(1.0);

        CAAnimationGroup *pulseGroup = [CAAnimationGroup animation];
        pulseGroup.animations = @[scaleAnimation, opacityAnimation];
        pulseGroup.duration = 1.08;
        pulseGroup.autoreverses = YES;
        pulseGroup.repeatCount = HUGE_VALF;
        pulseGroup.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.orderPeekStatusDot.layer addAnimation:pulseGroup forKey:@"pp.orderPeek.dotPulse"];
    }

    if ([self.orderPeekTintOverlay.layer animationForKey:@"pp.orderPeek.tintPulse"] == nil) {
        CABasicAnimation *tintAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        tintAnimation.fromValue = @(0.86);
        tintAnimation.toValue = @(1.0);
        tintAnimation.duration = 1.25;
        tintAnimation.autoreverses = YES;
        tintAnimation.repeatCount = HUGE_VALF;
        tintAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.orderPeekTintOverlay.layer addAnimation:tintAnimation forKey:@"pp.orderPeek.tintPulse"];
    }
}

- (void)pp_applyOrderPeekStyleWithStatusColor:(UIColor *)statusColor expanded:(BOOL)expanded
{
    UIColor *resolvedStatusColor = statusColor ?: [UIColor colorWithRed:1.0 green:0.76 blue:0.26 alpha:1.0];
    UIColor *baseSurfaceColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
    UIColor *tintColor = PPBlendColors(baseSurfaceColor, resolvedStatusColor, expanded ? 0.42 : 0.32);

    self.orderPeekStatusColor = resolvedStatusColor;
    self.orderPeekExpanded = expanded;
    self.orderPeekTintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:(expanded ? 0.78 : 0.68)];
    [self.orderPeekStrip pp_setBorderColor:[resolvedStatusColor colorWithAlphaComponent:(expanded ? 0.34 : 0.24)]];
    self.orderPeekThumbnail.backgroundColor = [resolvedStatusColor colorWithAlphaComponent:(expanded ? 0.24 : 0.16)];
    self.orderPeekStatusDot.backgroundColor = resolvedStatusColor;
    self.orderPeekStatusLabel.textColor = resolvedStatusColor;
    self.orderPeekChevron.tintColor = resolvedStatusColor;
}

- (void)pp_updateOrderPeekChevronForExpanded:(BOOL)expanded animated:(BOOL)animated
{
    void (^updates)(void) = ^{
        self.orderPeekChevron.transform = expanded
            ? CGAffineTransformMakeRotation((CGFloat)M_PI)
            : CGAffineTransformIdentity;
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

- (void)configureOrderPeekWithReference:(nullable NSString *)reference
                            statusTitle:(nullable NSString *)statusTitle
                            statusColor:(nullable UIColor *)statusColor
                        previewImageURL:(nullable NSString *)previewImageURL
                               expanded:(BOOL)expanded
                               animated:(BOOL)animated
{
    NSString *safeRef = PPSafeString(reference);
    NSString *safeStatus = PPSafeString(statusTitle);

    if (safeRef.length == 0) {
        [self hideOrderPeek:animated];
        return;
    }

    self.orderPeekReferenceLabel.text = safeRef;
    self.orderPeekStatusLabel.text = safeStatus;
    [self pp_applyOrderPeekStyleWithStatusColor:statusColor expanded:expanded];
    [self pp_updateOrderPeekChevronForExpanded:expanded animated:(self.orderPeekVisible && animated)];
    [self pp_startOrderPeekPulseAnimation];

    // Load thumbnail
    NSString *safeURL = PPSafeString(previewImageURL);
    if (safeURL.length > 0) {
        self.orderPeekThumbnail.hidden = NO;
        [GM setImageFromUrlString:safeURL imageView:self.orderPeekThumbnail phImage:@"placeholder"];
    } else {
        self.orderPeekThumbnail.hidden = NO;
        self.orderPeekThumbnail.image = [UIImage imageNamed:@"placeholder"];
    }

    if (self.orderPeekVisible) {
        return;
    }
    self.orderPeekVisible = YES;

    if (!animated) {
        self.orderPeekStrip.alpha = 1.0;
        self.orderPeekStrip.transform = CGAffineTransformIdentity;
        return;
    }

    // Spring slide-up animation
    [UIView animateWithDuration:0.52
                          delay:0.15
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.4
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

    [UIView animateWithDuration:0.28
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.orderPeekStrip.alpha = 0.0;
        self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
    } completion:nil];
}

@end
