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
@property (nonatomic, strong) UIView *orbViewA;
@property (nonatomic, strong) UIView *orbViewB;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UIView *statusPillView;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) UILabel *supportLabel;
@property (nonatomic, strong) UIControl *locationControl;
@property (nonatomic, strong) UIView *locationAccentWashView;
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
@property (nonatomic, copy) NSString *paletteLocationSeed;
@property (nonatomic, strong) LOTAnimationView *lottieHeaderView;
@property (nonatomic, copy) NSString *currentLottiePath;
@property (nonatomic, assign) NSInteger lottieLoopToken;
@property (nonatomic, assign) PPHomeHeroLocationState currentLocationState;
@property (nonatomic, copy) NSString *lastAnimationSignature;

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
    self.heroShadowView.layer.shadowColor = [UIColor colorWithWhite:0.03 alpha:1.0].CGColor;
    self.heroShadowView.layer.shadowOpacity = 0.08;
    self.heroShadowView.layer.shadowRadius = 18.0;
    self.heroShadowView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    if (@available(iOS 13.0, *)) {
        self.heroShadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.heroShadowView];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = [UIColor hx_colorWithHexStr:@"#17171E" alpha:1.0];
    self.heroSurfaceView.layer.cornerRadius = PPCornerHero;
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
    self.ambientGlowLayer.hidden = YES; // hidden = yes — ambient glow (design system: reduce visual noise)
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
    self.brandLabel.hidden = YES;
    self.statusPillView = [[UIView alloc] init];
    self.statusPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusPillView.layer.cornerRadius = 15.0;
    self.statusPillView.layer.masksToBounds = YES;
    self.statusPillView.hidden = YES;
    self.statusPillView.alpha = 0.0;
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
   // self.headlineLabel.backgroundColor = UIColor.redColor;

    [self.heroSurfaceView addSubview:self.headlineLabel];

    self.supportLabel = [[UILabel alloc] init];
    self.supportLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.supportLabel.numberOfLines = 2;
    self.supportLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.supportLabel.font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.supportLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    [self.heroSurfaceView addSubview:self.supportLabel];

    self.locationControl = [[UIControl alloc] init];
    self.locationControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.13];
    self.locationControl.layer.cornerRadius = PPCornerCard;
    self.locationControl.layer.borderWidth = 1.0;
    self.locationControl.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    self.locationControl.layer.masksToBounds = YES;
    self.locationControl.accessibilityTraits = UIAccessibilityTraitButton;
    if (@available(iOS 13.0, *)) {
        self.locationControl.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.locationControl addTarget:self action:@selector(pp_handleLocationTap) forControlEvents:UIControlEventTouchUpInside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    [self.heroSurfaceView addSubview:self.locationControl];

    self.locationAccentWashView = [[UIView alloc] init];
    self.locationAccentWashView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationAccentWashView.userInteractionEnabled = NO;
    self.locationAccentWashView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.locationAccentWashView.layer.cornerRadius = PPCornerMedium;
    self.locationAccentWashView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.locationAccentWashView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.locationControl addSubview:self.locationAccentWashView];

    self.locationIconPlateView = [[UIView alloc] init];
    self.locationIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationIconPlateView.userInteractionEnabled = NO;
    self.locationIconPlateView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    self.locationIconPlateView.layer.cornerRadius = PPCornerMedium;
    self.locationIconPlateView.layer.borderWidth = 1.0;
    self.locationIconPlateView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    if (@available(iOS 13.0, *)) {
        self.locationIconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
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
    self.locationStatusChipView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;

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

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.layer.cornerRadius = PPButtonHeightLG / 2.0;
    self.actionButton.layer.masksToBounds = YES;
    self.actionButton.layer.borderWidth = 0.85;
    self.actionButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
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
    self.lottieHeaderView.contentMode = UIViewContentModeScaleAspectFit;
    self.lottieHeaderView.alpha = 1.0;
    [self.heroSurfaceView addSubview:self.lottieHeaderView];

    // ── Order Peek Strip (one-line banner below hero card) ──
    [self pp_buildOrderPeekStrip];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroShadowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.heroShadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.heroShadowView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.heroShadowView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.heroShadowView.topAnchor],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.heroShadowView.leadingAnchor],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.heroShadowView.trailingAnchor],
        [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.heroShadowView.bottomAnchor],

        [self.orbViewA.widthAnchor constraintEqualToConstant:168.0],
        [self.orbViewA.heightAnchor constraintEqualToConstant:168.0],
        [self.orbViewA.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:28.0],
        [self.orbViewA.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:-28.0],

        [self.orbViewB.widthAnchor constraintEqualToConstant:0.0],
        [self.orbViewB.heightAnchor constraintEqualToConstant:0.0],
        [self.orbViewB.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-34.0],
        [self.orbViewB.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:48.0],

        [self.brandLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.brandLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.brandLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-140.0],

        [self.statusPillView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-20.0],
        [self.statusPillView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:20.0],
        [self.statusPillView.heightAnchor constraintEqualToConstant:28.0],

        [self.statusIconView.leadingAnchor constraintEqualToAnchor:self.statusPillView.leadingAnchor constant:11.0],
        [self.statusIconView.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.statusIconView.heightAnchor constraintEqualToConstant:12.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusIconView.trailingAnchor constant:6.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusPillView.trailingAnchor constant:-12.0],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],

        [self.headlineLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.headlineLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:22.0],
        [self.headlineLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-168.0],

        [self.supportLabel.leadingAnchor constraintEqualToAnchor:self.headlineLabel.leadingAnchor],
        [self.supportLabel.topAnchor constraintEqualToAnchor:self.headlineLabel.bottomAnchor constant:10.0],
        [self.supportLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.widthAnchor multiplier:0.52],
        [self.supportLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-126.0],

        [self.locationControl.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:18.0],
        [self.locationControl.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.locationControl.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-18.0],
        [self.locationControl.heightAnchor constraintEqualToConstant:58.0],

        [self.locationAccentWashView.trailingAnchor constraintEqualToAnchor:self.locationControl.trailingAnchor constant:-12.0],
        [self.locationAccentWashView.leadingAnchor constraintEqualToAnchor:self.locationStatusChipView.leadingAnchor constant:-8.0],
        [self.locationAccentWashView.topAnchor constraintEqualToAnchor:self.locationControl.topAnchor constant:11.0],
        [self.locationAccentWashView.bottomAnchor constraintEqualToAnchor:self.locationControl.bottomAnchor constant:-11.0],

        [self.locationIconPlateView.leadingAnchor constraintEqualToAnchor:self.locationControl.leadingAnchor constant:12.0],
        [self.locationIconPlateView.centerYAnchor constraintEqualToAnchor:self.locationControl.centerYAnchor],
        [self.locationIconPlateView.widthAnchor constraintEqualToConstant:38.0],
        [self.locationIconPlateView.heightAnchor constraintEqualToConstant:38.0],

        [self.locationIconView.centerXAnchor constraintEqualToAnchor:self.locationIconPlateView.centerXAnchor],
        [self.locationIconView.centerYAnchor constraintEqualToAnchor:self.locationIconPlateView.centerYAnchor],
        [self.locationIconView.widthAnchor constraintEqualToConstant:15.0],
        [self.locationIconView.heightAnchor constraintEqualToConstant:15.0],

        [self.locationStatusChipView.trailingAnchor constraintEqualToAnchor:self.locationControl.trailingAnchor constant:-12.0],
        [self.locationStatusChipView.centerYAnchor constraintEqualToAnchor:self.locationControl.centerYAnchor],
        [self.locationStatusChipView.heightAnchor constraintEqualToConstant:36.0],
        [self.locationStatusChipView.widthAnchor constraintGreaterThanOrEqualToConstant:92.0],
        [self.locationStatusChipView.widthAnchor constraintLessThanOrEqualToAnchor:self.locationControl.widthAnchor multiplier:0.44],

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
        [self.lottieHeaderView.widthAnchor constraintEqualToConstant:122],
        [self.lottieHeaderView.heightAnchor constraintEqualToConstant:122],
        [self.lottieHeaderView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:12.0],
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
    self.actionButton.hidden = YES;

    [self pp_applyPaletteForCurrentTime];
    [self pp_startAmbientAnimationsIfNeeded];
    return self;
}

- (UIBezierPath *)pp_pathForRect:(CGRect)rect
                         topLeft:(CGFloat)tl topRight:(CGFloat)tr
                      bottomLeft:(CGFloat)bl bottomRight:(CGFloat)br
{
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(tl, 0)];
    [p addLineToPoint:CGPointMake(CGRectGetWidth(rect) - tr, 0)];
    [p addArcWithCenter:CGPointMake(CGRectGetWidth(rect) - tr, tr)
                 radius:tr startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [p addLineToPoint:CGPointMake(CGRectGetWidth(rect), CGRectGetHeight(rect) - br)];
    [p addArcWithCenter:CGPointMake(CGRectGetWidth(rect) - br, CGRectGetHeight(rect) - br)
                 radius:br startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [p addLineToPoint:CGPointMake(bl, CGRectGetHeight(rect))];
    [p addArcWithCenter:CGPointMake(bl, CGRectGetHeight(rect) - bl)
                 radius:bl startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    [p addLineToPoint:CGPointMake(0, tl)];
    [p addArcWithCenter:CGPointMake(tl, tl)
                 radius:tl startAngle:M_PI endAngle:-M_PI_2 clockwise:YES];
    [p closePath];
    return p;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

   
    
    
    CGRect bounds = self.heroSurfaceView.bounds;
    if (CGRectIsEmpty(bounds)) return;

    self.gradientLayer.frame = bounds;
    self.ambientGlowLayer.frame = bounds;
    self.bottomShadeLayer.frame = bounds;

    self.heroShadowView.layer.cornerRadius = self.heroSurfaceView.layer.cornerRadius;
    self.heroShadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroShadowView.bounds
                                                                      cornerRadius:self.heroSurfaceView.layer.cornerRadius].CGPath;

    self.orbViewA.layer.cornerRadius = CGRectGetWidth(self.orbViewA.bounds) * 0.5;
    self.orbViewB.layer.cornerRadius = CGRectGetWidth(self.orbViewB.bounds) * 0.5;
    
    
    CGRect orderPeekStripbounds = self.orderPeekStrip.bounds;
    UIBezierPath *path = [self pp_pathForRect:orderPeekStripbounds topLeft:0 topRight:0 bottomLeft:12 bottomRight:12];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    self.orderPeekStrip.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.onLocationTap = nil;
    self.onLocationActionTap = nil;
    self.onOrderPeekTap = nil;
    self.lastAnimationSignature = nil;
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
    self.locationAccentWashView.alpha = 1.0;
    [self.locationStatusDotView.layer removeAnimationForKey:@"pp.hero.location.dotPulse"];
    [self.locationAccentWashView.layer removeAnimationForKey:@"pp.hero.location.washPulse"];

    self.lottieLoopToken += 1;
    [self.lottieHeaderView stop];
    self.currentLottiePath = nil;

    // Reset peek strip
    self.orderPeekVisible = NO;
    self.orderPeekExpanded = NO;
    self.orderPeekStrip.alpha = 0.0;
    self.orderPeekStrip.transform = CGAffineTransformMakeTranslation(0.0, -24.0);
    self.orderPeekStrip.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
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

    UIFont *firstLineFont = [GM boldFontWithSize:32] ?: [UIFont systemFontOfSize:32.0 weight:UIFontWeightBold];
    UIFont *secondLineFont = [GM boldFontWithSize:22] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightSemibold];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = Language.alignmentForCurrentLanguage;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.lineSpacing = 1.0;

    UIColor *textColor = UIColor.whiteColor;

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
        [result appendAttributedString:[self pp_tintedPawAttachmentForFont:secondLineFont color:textColor]];
    } else if (firstLine.length > 0) {
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
    NSString *chosenName = iconNames[arc4random_uniform((uint32_t)iconNames.count)];

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
    self.statusIconView.tintColor = AppForgroundColr;
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
    UIColor *accentWashFill = [liftedAccent colorWithAlphaComponent:0.11];
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
            accentWashFill = [liftedAccent colorWithAlphaComponent:0.16];
            chipFill = [UIColor colorWithWhite:1.0 alpha:0.20];
            chipBorder = [UIColor colorWithWhite:1.0 alpha:0.12];
            dotColor = [UIColor hx_colorWithHexStr:@"#FFD36B" alpha:1.0];
            break;

        case PPHomeHeroLocationStateReady:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.13];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
            iconPlateFill = [liftedAccent colorWithAlphaComponent:0.19];
            iconPlateBorder = [liftedAccent colorWithAlphaComponent:0.20];
            accentWashFill = [liftedAccent colorWithAlphaComponent:0.13];
            chipFill = [liftedAccent colorWithAlphaComponent:0.18];
            chipBorder = [liftedAccent colorWithAlphaComponent:0.20];
            dotColor = [UIColor colorWithWhite:1.0 alpha:0.96];
            break;
        case PPHomeHeroLocationStateUnset:
        default:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.13];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.09];
            iconPlateFill = [UIColor colorWithWhite:1.0 alpha:0.15];
            iconPlateBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            accentWashFill = [liftedAccent colorWithAlphaComponent:0.12];
            chipFill = [UIColor colorWithWhite:1.0 alpha:0.18];
            chipBorder = [UIColor colorWithWhite:1.0 alpha:0.12];
            break;
    }

    self.locationControl.backgroundColor = glassFill;
    self.locationControl.layer.borderColor = glassBorder.CGColor;
    self.locationAccentWashView.backgroundColor = accentWashFill;
    self.locationIconPlateView.backgroundColor = iconPlateFill;
    self.locationIconPlateView.layer.borderColor = iconPlateBorder.CGColor;
    self.locationStatusChipView.backgroundColor = chipFill;
    self.locationStatusChipView.layer.borderColor = chipBorder.CGColor;
    self.locationStatusLabel.text = [self pp_locationChipTextForState:locationState];
    self.locationStatusLabel.textColor = chipTextColor;
    self.locationStatusDotView.backgroundColor = dotColor;
    self.locationChevronView.tintColor = [chipTextColor colorWithAlphaComponent:(locationState == PPHomeHeroLocationStateDenied ? 0.72 : 0.88)];
    self.locationIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:(locationState == PPHomeHeroLocationStateDenied ? 0.94 : 0.98)];
    [self pp_updateLocationPulseForState:locationState];
}

#pragma mark - Palette

- (void)pp_applyPaletteForCurrentTime
{
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:NSDate.date];
    UIColor *accent = PPLocationAccentColor(self.paletteLocationSeed);

    NSArray<UIColor *> *baseColors = nil;
    CGPoint start = CGPointMake(0.0, 0.0);
    CGPoint end = CGPointMake(1.0, 1.0);

    if (hour < 6) {
        baseColors = @[
            [UIColor hx_colorWithHexStr:@"#12131D" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#1A2142" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#202C5B" alpha:1.0]
        ];
    } else if (hour < 11) {
        baseColors = @[
            [UIColor hx_colorWithHexStr:@"#FFB660" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#FF7B43" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#C3472C" alpha:1.0]
        ];
        start = CGPointMake(0.0, 0.1);
        end = CGPointMake(1.0, 0.95);
    } else if (hour < 17) {
        baseColors = @[
            [UIColor hx_colorWithHexStr:@"#F6C163" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#EF7C40" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#8644C7" alpha:1.0]
        ];
        start = CGPointMake(0.05, 0.0);
        end = CGPointMake(1.0, 1.0);
    } else if (hour < 21) {
        baseColors = @[
            [UIColor hx_colorWithHexStr:@"#2E2B6E" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#6C2F96" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#FF7A46" alpha:1.0]
        ];
        start = CGPointMake(0.0, 0.0);
        end = CGPointMake(1.0, 0.88);
    } else {
        baseColors = @[
            [UIColor hx_colorWithHexStr:@"#111625" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#1B2A48" alpha:1.0],
            [UIColor hx_colorWithHexStr:@"#303C72" alpha:1.0]
        ];
    }

    NSMutableArray *blendedColors = [NSMutableArray arrayWithCapacity:baseColors.count];
    for (NSUInteger idx = 0; idx < baseColors.count; idx++) {
        UIColor *base = baseColors[idx];
        UIColor *deepened = PPBlendColors(base, UIColor.blackColor, idx == 0 ? 0.06 : 0.12);
        [blendedColors addObject:PPBlendColors(deepened, accent, 0.08)];
    }

    NSMutableArray *gradientColors = [NSMutableArray arrayWithCapacity:blendedColors.count];
    for (UIColor *color in blendedColors) {
        [gradientColors addObject:(id)color.CGColor];
    }

    UIColor *glowPrimary = [PPBlendColors(accent, UIColor.whiteColor, 0.18) colorWithAlphaComponent:0.34];
    UIColor *glowSecondary = [PPBlendColors(accent, UIColor.whiteColor, 0.45) colorWithAlphaComponent:0.18];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.gradientLayer.startPoint = start;
    self.gradientLayer.endPoint = end;
    self.gradientLayer.colors = gradientColors;
    self.gradientLayer.locations = @[@0.0, @0.55, @1.0];
    self.ambientGlowLayer.colors = @[
        (id)glowPrimary.CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.02].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    self.bottomShadeLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.08].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.24].CGColor
    ];
    [CATransaction commit];

    self.orbViewA.backgroundColor = [glowPrimary colorWithAlphaComponent:0.12];
    self.orbViewB.backgroundColor = [glowSecondary colorWithAlphaComponent:0.14];
    self.statusPillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    self.brandLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.76];
}

#pragma mark - Motion

- (void)pp_startAmbientAnimationsIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
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
    glow.fromValue = @(0.72);
    glow.toValue = @(0.90);
    glow.duration = 6.2;
    glow.autoreverses = YES;
    glow.repeatCount = HUGE_VALF;
    [self.ambientGlowLayer addAnimation:glow forKey:@"pp.hero.glow"];
}

- (void)pp_updateLocationPulseForState:(PPHomeHeroLocationState)state
{
    [self.locationStatusDotView.layer removeAnimationForKey:@"pp.hero.location.dotPulse"];
    [self.locationAccentWashView.layer removeAnimationForKey:@"pp.hero.location.washPulse"];
    self.locationStatusDotView.transform = CGAffineTransformIdentity;
    self.locationAccentWashView.alpha = 1.0;

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
    [self.locationAccentWashView.layer addAnimation:washPulse forKey:@"pp.hero.location.washPulse"];
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
        self.headlineLabel,
        self.supportLabel,
        self.locationControl,
        self.actionButton
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
        return @"Man Giving Food To Fish";
    }
    if (hour < 17) {
        return @"Man playing with a dog";
    }
    if (hour < 20) {
        return @"CatPlaying";
    }
    if (hour < 23) {
        return @"evening chair cat and girl";
    }
    return @"CatPlaying";
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
    self.orderPeekStrip.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
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
    self.orderPeekStrip.layer.borderColor = [resolvedStatusColor colorWithAlphaComponent:(expanded ? 0.34 : 0.24)].CGColor;
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
