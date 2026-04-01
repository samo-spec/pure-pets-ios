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
@property (nonatomic, strong) UIImageView *locationIconView;
@property (nonatomic, strong) UILabel *locationTitleLabel;
@property (nonatomic, strong) UILabel *locationMetaLabel;
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
    self.heroShadowView.layer.shadowOpacity = PPShadowElevatedOpacity + 0.06;
    self.heroShadowView.layer.shadowRadius = PPShadowElevatedRadius + 2;
    self.heroShadowView.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    if (@available(iOS 13.0, *)) {
        self.heroShadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.heroShadowView];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = [UIColor hx_colorWithHexStr:@"#17171E" alpha:1.0];
    self.heroSurfaceView.layer.cornerRadius = PPCornerHero + 6;
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
        (id)[UIColor colorWithWhite:0.0 alpha:0.38].CGColor
    ];
    [self.heroSurfaceView.layer addSublayer:self.bottomShadeLayer];

    self.orbViewA = [[UIView alloc] init];
    self.orbViewA.translatesAutoresizingMaskIntoConstraints = NO;
    self.orbViewA.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    self.orbViewA.userInteractionEnabled = NO;
    [self.heroSurfaceView addSubview:self.orbViewA];

    self.orbViewB = [[UIView alloc] init];
    self.orbViewB.translatesAutoresizingMaskIntoConstraints = NO;
    self.orbViewB.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
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
    self.supportLabel.font = [GM MidFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.supportLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.74];
    [self.heroSurfaceView addSubview:self.supportLabel];

    self.locationControl = [[UIControl alloc] init];
    self.locationControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    self.locationControl.layer.cornerRadius = PPCornerLarge / 2;
    self.locationControl.layer.borderWidth = 1.0;
    self.locationControl.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    [self.locationControl addTarget:self action:@selector(pp_handleLocationTap) forControlEvents:UIControlEventTouchUpInside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveDown:) forControlEvents:UIControlEventTouchDown];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.locationControl addTarget:self action:@selector(pp_handleInteractiveUp:) forControlEvents:UIControlEventTouchCancel];
    [self.heroSurfaceView addSubview:self.locationControl];

    self.locationIconView = [[UIImageView alloc] init];
    self.locationIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.locationIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    [self.locationControl addSubview:self.locationIconView];

    self.locationTitleLabel = [[UILabel alloc] init];
    self.locationTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationTitleLabel.font = [GM boldFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.locationTitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    self.locationTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.locationTitleLabel.numberOfLines = 1;
    [self.locationControl addSubview:self.locationTitleLabel];

    self.locationMetaLabel = [[UILabel alloc] init];
    self.locationMetaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationMetaLabel.font = [GM MidFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.locationMetaLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    self.locationMetaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.locationMetaLabel.numberOfLines = 1;
    [self.locationControl addSubview:self.locationMetaLabel];

    self.locationChevronView = [[UIImageView alloc] init];
    self.locationChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationChevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.locationChevronView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.90];
    [self.locationControl addSubview:self.locationChevronView];

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.layer.cornerRadius = PPButtonHeightLG / 2.0;
    self.actionButton.layer.masksToBounds = YES;
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

    [NSLayoutConstraint activateConstraints:@[
        [self.heroShadowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.heroShadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.heroShadowView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.heroShadowView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.heroShadowView.topAnchor],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.heroShadowView.leadingAnchor],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.heroShadowView.trailingAnchor],
        [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.heroShadowView.bottomAnchor],

        [self.orbViewA.widthAnchor constraintEqualToConstant:180.0],
        [self.orbViewA.heightAnchor constraintEqualToConstant:180.0],
        [self.orbViewA.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:40.0],
        [self.orbViewA.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:-34.0],

        [self.orbViewB.widthAnchor constraintEqualToConstant:0.0],
        [self.orbViewB.heightAnchor constraintEqualToConstant:0.0],
        [self.orbViewB.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-34.0],
        [self.orbViewB.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:48.0],

        [self.brandLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:20.0],
        [self.brandLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:20.0],
        [self.brandLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-140.0],

        [self.statusPillView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.statusPillView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.statusPillView.heightAnchor constraintEqualToConstant:30.0],

        [self.statusIconView.leadingAnchor constraintEqualToAnchor:self.statusPillView.leadingAnchor constant:11.0],
        [self.statusIconView.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.statusIconView.heightAnchor constraintEqualToConstant:12.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusIconView.trailingAnchor constant:6.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusPillView.trailingAnchor constant:-12.0],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],

        [self.headlineLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:20.0],
        [self.headlineLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:16.0],
        [self.headlineLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-176.0],

        [self.supportLabel.leadingAnchor constraintEqualToAnchor:self.headlineLabel.leadingAnchor],
        [self.supportLabel.topAnchor constraintEqualToAnchor:self.headlineLabel.bottomAnchor constant:8.0],
        [self.supportLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.widthAnchor multiplier:0.54],
        [self.supportLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-132.0],

        [self.locationControl.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:20.0],
        [self.locationControl.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-20.0],
        [self.locationControl.heightAnchor constraintEqualToConstant:58.0],
        [self.locationControl.widthAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.widthAnchor multiplier:0.60],
        [self.locationControl.trailingAnchor constraintLessThanOrEqualToAnchor:self.actionButton.leadingAnchor constant:-10.0],

        [self.locationIconView.leadingAnchor constraintEqualToAnchor:self.locationControl.leadingAnchor constant:14.0],
        [self.locationIconView.centerYAnchor constraintEqualToAnchor:self.locationControl.centerYAnchor],
        [self.locationIconView.widthAnchor constraintEqualToConstant:14.0],
        [self.locationIconView.heightAnchor constraintEqualToConstant:14.0],

        [self.locationChevronView.trailingAnchor constraintEqualToAnchor:self.locationControl.trailingAnchor constant:-12.0],
        [self.locationChevronView.centerYAnchor constraintEqualToAnchor:self.locationControl.centerYAnchor],
        [self.locationChevronView.widthAnchor constraintEqualToConstant:10.0],
        [self.locationChevronView.heightAnchor constraintEqualToConstant:10.0],

        [self.locationTitleLabel.leadingAnchor constraintEqualToAnchor:self.locationIconView.trailingAnchor constant:10.0],
        [self.locationTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.locationChevronView.leadingAnchor constant:-8.0],
        [self.locationTitleLabel.topAnchor constraintEqualToAnchor:self.locationControl.topAnchor constant:11.0],

        [self.locationMetaLabel.leadingAnchor constraintEqualToAnchor:self.locationTitleLabel.leadingAnchor],
        [self.locationMetaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.locationChevronView.leadingAnchor constant:-8.0],
        [self.locationMetaLabel.topAnchor constraintEqualToAnchor:self.locationTitleLabel.bottomAnchor constant:2.0],

        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-20.0],

        [self.lottieHeaderView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-6.0],
        [self.lottieHeaderView.widthAnchor constraintEqualToConstant:130],
        [self.lottieHeaderView.heightAnchor constraintEqualToConstant:130],
        [self.lottieHeaderView.topAnchor constraintEqualToAnchor:self.statusPillView.topAnchor constant:8.0],
     ]];

    self.actionButtonHeightConstraint = [self.actionButton.heightAnchor constraintEqualToConstant:PPButtonHeightLG];
    self.actionButtonWidthConstraint = [self.actionButton.widthAnchor constraintEqualToConstant:128.0];
    self.actionButtonHeightConstraint.active = YES;
    self.actionButtonWidthConstraint.active = YES;

    [self pp_applyPaletteForCurrentTime];
    [self pp_startAmbientAnimationsIfNeeded];
    return self;
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
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.onLocationTap = nil;
    self.onLocationActionTap = nil;
    self.lastAnimationSignature = nil;
    self.paletteLocationSeed = @"";
    self.locationTitleLabel.text = @"";
    self.locationMetaLabel.text = @"";
    self.headlineLabel.text = @"";
    self.headlineLabel.attributedText = nil;
    self.supportLabel.text = @"";
    self.statusLabel.text = @"";
    self.actionButton.hidden = NO;
    self.actionButton.alpha = 1.0;
    self.actionButtonHeightConstraint.constant = PPButtonHeightLG;
    self.actionButtonWidthConstraint.constant = 128.0;
    self.locationControl.alpha = 1.0;
    self.locationControl.transform = CGAffineTransformIdentity;
    self.actionButton.transform = CGAffineTransformIdentity;

    self.lottieLoopToken += 1;
    [self.lottieHeaderView stop];
    self.currentLottiePath = nil;
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
    self.locationMetaLabel.text = [self pp_locationMetaTextForState:locationState];

    [self pp_setSymbolNamed:@"location.fill" onImageView:self.locationIconView pointSize:14.0];
    [self pp_setSymbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                onImageView:self.locationChevronView
                  pointSize:10.0];

    if (resolvedActionTitle.length == 0) {
        resolvedActionTitle = [self pp_defaultActionTitleForState:locationState];
    }
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

    return [NSString stringWithFormat:@"%@\n%@", line1, (kLang(@"Hero_Brand") ?: @"Trending now")]; //Hero_TrendingNow
}

- (NSAttributedString *)pp_attributedHeadlineWithGreeting:(NSString *)greeting
                                                 userName:(NSString *)userName
{
    NSString *headline = [self pp_headlineTextWithGreeting:greeting userName:userName];
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

    NSMutableAttributedString *result =
        [[NSMutableAttributedString alloc] initWithString:firstLine
                                               attributes:@{
        NSFontAttributeName : firstLineFont,
        NSForegroundColorAttributeName : UIColor.whiteColor,
        NSParagraphStyleAttributeName : paragraph
    }];

    if (secondLine.length > 0) {
        NSAttributedString *secondLineAttributed =
            [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", secondLine]
                                            attributes:@{
            NSFontAttributeName : secondLineFont,
            NSForegroundColorAttributeName : UIColor.whiteColor,
            NSParagraphStyleAttributeName : paragraph
        }];
        [result appendAttributedString:secondLineAttributed];
    }

    return result;
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
    self.statusIconView.tintColor = AppPrimaryClr;
}

- (void)pp_applyLocationState:(PPHomeHeroLocationState)locationState
                  actionTitle:(nullable NSString *)actionTitle
{
    self.currentLocationState = locationState;

    BOOL showAction = (PPSafeString(actionTitle).length > 0 && locationState != PPHomeHeroLocationStateLoading);
    self.actionButton.hidden = !showAction;
    self.actionButton.alpha = showAction ? 1.0 : 0.0;
    self.actionButtonHeightConstraint.constant = showAction ? PPButtonHeightLG : 0.0;

    if (showAction) {
        [self.actionButton setTitle:actionTitle forState:UIControlStateNormal];
        CGFloat measuredWidth =
            ceil([actionTitle sizeWithAttributes:@{
                NSFontAttributeName : (self.actionButton.titleLabel.font ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold])
            }].width) + PPSpace4XL;
        self.actionButtonWidthConstraint.constant = MAX(128.0, MIN(180.0, measuredWidth));
    } else {
        self.actionButtonWidthConstraint.constant = 0.0;
        [self.actionButton setTitle:@"" forState:UIControlStateNormal];
    }

    UIColor *glassFill = [UIColor colorWithWhite:1.0 alpha:0.15];
    UIColor *glassBorder = [UIColor colorWithWhite:1.0 alpha:0.10];
    UIColor *buttonFill = [UIColor colorWithWhite:1.0 alpha:0.16];
    UIColor *buttonTitleColor = UIColor.whiteColor;

    switch (locationState) {
        case PPHomeHeroLocationStateDenied:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.12];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            buttonFill = [UIColor colorWithWhite:1.0 alpha:0.96];
            buttonTitleColor = [UIColor hx_colorWithHexStr:@"#12131A" alpha:1.0];
            break;

        case PPHomeHeroLocationStateLoading:
            glassFill = [UIColor colorWithWhite:1.0 alpha:0.12];
            glassBorder = [UIColor colorWithWhite:1.0 alpha:0.08];
            buttonFill = [UIColor colorWithWhite:1.0 alpha:0.14];
            break;

        case PPHomeHeroLocationStateReady:
        case PPHomeHeroLocationStateUnset:
        default:
            break;
    }

    self.locationControl.backgroundColor = glassFill;
    self.locationControl.layer.borderColor = glassBorder.CGColor;
    self.actionButton.backgroundColor = buttonFill;
    [self.actionButton setTitleColor:buttonTitleColor forState:UIControlStateNormal];
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
        (id)[UIColor colorWithWhite:0.0 alpha:0.10].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.34].CGColor
    ];
    [CATransaction commit];

    self.orbViewA.backgroundColor = [glowPrimary colorWithAlphaComponent:0.18];
    self.orbViewB.backgroundColor = [glowSecondary colorWithAlphaComponent:0.22];
    self.statusPillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    self.brandLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.76];
}

#pragma mark - Motion

- (void)pp_startAmbientAnimationsIfNeeded
{
    if ([self.orbViewA.layer animationForKey:@"pp.hero.breatheA"]) {
        return;
    }

    CABasicAnimation *breatheA = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    breatheA.fromValue = @(0.96);
    breatheA.toValue = @(1.07);
    breatheA.duration = 6.0;
    breatheA.autoreverses = YES;
    breatheA.repeatCount = HUGE_VALF;
    breatheA.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.orbViewA.layer addAnimation:breatheA forKey:@"pp.hero.breatheA"];

    CABasicAnimation *breatheB = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    breatheB.fromValue = @(0.94);
    breatheB.toValue = @(1.08);
    breatheB.duration = 7.4;
    breatheB.autoreverses = YES;
    breatheB.repeatCount = HUGE_VALF;
    breatheB.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.orbViewB.layer addAnimation:breatheB forKey:@"pp.hero.breatheB"];

    CABasicAnimation *glow = [CABasicAnimation animationWithKeyPath:@"opacity"];
    glow.fromValue = @(0.85);
    glow.toValue = @(1.0);
    glow.duration = 4.8;
    glow.autoreverses = YES;
    glow.repeatCount = HUGE_VALF;
    [self.ambientGlowLayer addAnimation:glow forKey:@"pp.hero.glow"];
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

    [UIView animateWithDuration:0.52
                          delay:0.05
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.15
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
    self.lottieHeaderView.alpha = 0.92;

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

@end
