//
//  PetAdoptCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/08/2025.
//

#import "PetAdoptCollectionViewCell.h"
#import "AppClasses.h"

static NSString * const PPAdoptBreathingAnimationKey = @"pp_adopt_breathing";
static NSString * const PPAdoptGlowAnimationKey = @"pp_adopt_glow";

@interface PetAdoptCollectionViewCell ()

@property (nonatomic, strong) UIView *cardSurfaceView;
@property (nonatomic, strong) UIView *contentWrapView;
@property (nonatomic, strong) UIView *visualStageView;
@property (nonatomic, strong) UIView *visualGlassView;
@property (nonatomic, strong) UIView *visualOrbView;
@property (nonatomic, strong) UIView *ambientRoseView;
@property (nonatomic, strong) UIView *ambientMintView;
@property (nonatomic, strong) UIView *ambientPeachView;
@property (nonatomic, strong) UIView *hairlineView;
@property (nonatomic, strong) UIImageView *seedImageView;
@property (nonatomic, strong) UIView *badgePillView;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIView *ctaPillView;
@property (nonatomic, strong) UILabel *ctaLabel;
@property (nonatomic, strong) UIImageView *ctaIconView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *visualGradientLayer;
@property (nonatomic, strong) CAGradientLayer *ctaGradientLayer;
@property (nonatomic, strong) CAGradientLayer *hairlineGradientLayer;
@property (nonatomic, strong) NSLayoutConstraint *visualWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *visualHeightConstraint;
@property (nonatomic, assign) BOOL didRequestAnimation;
@property (nonatomic, assign) BOOL animationLoaded;
@property (nonatomic, assign) BOOL didRunEntrance;

@end

@implementation PetAdoptCollectionViewCell

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildViewHierarchy];
    [self pp_buildConstraints];
    [self pp_applyBaseStyle];
    [self pp_loadAnimationIfNeeded];
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onTap = nil;
    self.seedImageView.image = nil;
    self.seedImageView.hidden = YES;
    self.cardSurfaceView.transform = CGAffineTransformIdentity;
    self.contentWrapView.transform = CGAffineTransformIdentity;
    self.visualStageView.transform = CGAffineTransformIdentity;
    self.lottieHeaderView.transform = CGAffineTransformIdentity;
    self.ambientRoseView.transform = CGAffineTransformIdentity;
    self.ambientMintView.transform = CGAffineTransformIdentity;
    self.ambientPeachView.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;
    [self pp_applyCurrentDirection];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startLivingMotionIfNeeded];
        [self pp_playLottieIfPossible];
        [self pp_runEntranceIfNeeded];
    } else {
        [self pp_stopLivingMotion];
        [self.lottieHeaderView stop];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyBaseStyle];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self pp_refreshGeometry];
}

#pragma mark - Public

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                 seedImage:(nullable UIImage *)seedImage
{
    self.badgeLabel.text = kLang(@"AdoptPet");
    self.titleLabel.text = title ?: @"";
    self.subtitleLabel.text = subtitle ?: @"";
    self.ctaLabel.text = kLang(@"HomeAdoptCTA");
    [self pp_configureSeedImage:seedImage];
    [self pp_applyCurrentDirection];
    [self pp_applyBaseStyle];

    self.cardSurfaceView.accessibilityLabel =
        [NSString stringWithFormat:@"%@. %@",
         self.titleLabel.text ?: @"",
         self.subtitleLabel.text ?: @""];
    self.cardSurfaceView.accessibilityHint = self.ctaLabel.text ?: @"";

    [self setNeedsLayout];
}

#pragma mark - Build

- (void)pp_buildViewHierarchy {
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;

    _cardSurfaceView = [[UIView alloc] init];
    _cardSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardSurfaceView.clipsToBounds = YES;
    _cardSurfaceView.isAccessibilityElement = YES;
    _cardSurfaceView.accessibilityTraits = UIAccessibilityTraitButton;
    [self.contentView addSubview:_cardSurfaceView];

    _surfaceGradientLayer = [CAGradientLayer layer];
    [_cardSurfaceView.layer insertSublayer:_surfaceGradientLayer atIndex:0];

    _ambientRoseView = [self pp_makeAtmosphereViewWithColor:[UIColor hx_colorWithHexStr:@"#F4A4BE"]
                                                      alpha:0.18
                                                shadowAlpha:0.16];
    [_cardSurfaceView addSubview:_ambientRoseView];

    _ambientMintView = [self pp_makeAtmosphereViewWithColor:[UIColor hx_colorWithHexStr:@"#BFEBD4"]
                                                      alpha:0.20
                                                shadowAlpha:0.14];
    [_cardSurfaceView addSubview:_ambientMintView];

    _ambientPeachView = [self pp_makeAtmosphereViewWithColor:[UIColor hx_colorWithHexStr:@"#FFD3AC"]
                                                       alpha:0.17
                                                 shadowAlpha:0.12];
    [_cardSurfaceView addSubview:_ambientPeachView];

    _hairlineView = [[UIView alloc] init];
    _hairlineView.translatesAutoresizingMaskIntoConstraints = NO;
    _hairlineView.userInteractionEnabled = NO;
    [_cardSurfaceView addSubview:_hairlineView];

    _hairlineGradientLayer = [CAGradientLayer layer];
    [_hairlineView.layer addSublayer:_hairlineGradientLayer];

    _contentWrapView = [[UIView alloc] init];
    _contentWrapView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentWrapView.backgroundColor = UIColor.clearColor;
    [_cardSurfaceView addSubview:_contentWrapView];

    _visualStageView = [[UIView alloc] init];
    _visualStageView.translatesAutoresizingMaskIntoConstraints = NO;
    _visualStageView.clipsToBounds = NO;
    [_cardSurfaceView addSubview:_visualStageView];

    _visualOrbView = [self pp_makeAtmosphereViewWithColor:[UIColor hx_colorWithHexStr:@"#FFFFFF"]
                                                     alpha:0.76
                                               shadowAlpha:0.12];
    [_visualStageView addSubview:_visualOrbView];

    _visualGlassView = [[UIView alloc] init];
    _visualGlassView.translatesAutoresizingMaskIntoConstraints = NO;
    _visualGlassView.clipsToBounds = YES;
    _visualGlassView.layer.borderWidth = 1.0;
    [_visualStageView addSubview:_visualGlassView];

    _visualGradientLayer = [CAGradientLayer layer];
    [_visualGlassView.layer insertSublayer:_visualGradientLayer atIndex:0];

    _seedImageView = [[UIImageView alloc] init];
    _seedImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _seedImageView.contentMode = UIViewContentModeScaleAspectFit;
    _seedImageView.alpha = 0.12;
    _seedImageView.hidden = YES;
    [_visualGlassView addSubview:_seedImageView];

    _lottieHeaderView = [[LOTAnimationView alloc] init];
    _lottieHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    _lottieHeaderView.backgroundColor = UIColor.clearColor;
    _lottieHeaderView.opaque = NO;
    _lottieHeaderView.userInteractionEnabled = NO;
    _lottieHeaderView.contentMode = UIViewContentModeScaleAspectFit;
    _lottieHeaderView.loopAnimation = YES;
    _lottieHeaderView.hidden = YES;
    [_visualGlassView addSubview:_lottieHeaderView];

    _badgePillView = [[UIView alloc] init];
    _badgePillView.translatesAutoresizingMaskIntoConstraints = NO;
    _badgePillView.layer.borderWidth = 1.0;
    _badgePillView.clipsToBounds = YES;
    [_contentWrapView addSubview:_badgePillView];

    _badgeLabel = [[UILabel alloc] init];
    _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeLabel.font = [GM boldFontWithSize:12.5];
    _badgeLabel.numberOfLines = 1;
    _badgeLabel.adjustsFontSizeToFitWidth = YES;
    _badgeLabel.minimumScaleFactor = 0.78;
    [_badgePillView addSubview:_badgeLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:26.0];
    _titleLabel.numberOfLines = 2;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    [_contentWrapView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:14.5];
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [_contentWrapView addSubview:_subtitleLabel];

    _ctaPillView = [[UIView alloc] init];
    _ctaPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaPillView.clipsToBounds = YES;
    _ctaPillView.layer.borderWidth = 0.0;
    [_contentWrapView addSubview:_ctaPillView];

    _ctaGradientLayer = [CAGradientLayer layer];
    [_ctaPillView.layer insertSublayer:_ctaGradientLayer atIndex:0];

    _ctaLabel = [[UILabel alloc] init];
    _ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaLabel.font = [GM boldFontWithSize:15.5];
    _ctaLabel.numberOfLines = 1;
    _ctaLabel.adjustsFontSizeToFitWidth = YES;
    _ctaLabel.minimumScaleFactor = 0.78;
    [_ctaPillView addSubview:_ctaLabel];

    _ctaIconView = [[UIImageView alloc] init];
    _ctaIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_ctaPillView addSubview:_ctaIconView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleTap)];
    [_cardSurfaceView addGestureRecognizer:tap];

    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                        action:@selector(pp_handlePress:)];
    press.minimumPressDuration = 0.01;
    press.cancelsTouchesInView = NO;
    [_cardSurfaceView addGestureRecognizer:press];
}

- (void)pp_buildConstraints {
    UILayoutGuide *layoutGuide = self.contentView.layoutMarginsGuide;
    self.contentView.layoutMargins = UIEdgeInsetsMake(0, 0, 0, 0);

    self.visualWidthConstraint = [_visualStageView.widthAnchor constraintEqualToConstant:150.0];
    self.visualHeightConstraint = [_visualStageView.heightAnchor constraintEqualToAnchor:_cardSurfaceView.heightAnchor multiplier:0.92];

    [NSLayoutConstraint activateConstraints:@[
        [_cardSurfaceView.topAnchor constraintEqualToAnchor:layoutGuide.topAnchor],
        [_cardSurfaceView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor],
        [_cardSurfaceView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor],
        [_cardSurfaceView.bottomAnchor constraintEqualToAnchor:layoutGuide.bottomAnchor],

        [_ambientRoseView.widthAnchor constraintEqualToAnchor:_cardSurfaceView.widthAnchor multiplier:0.58],
        [_ambientRoseView.heightAnchor constraintEqualToAnchor:_ambientRoseView.widthAnchor],
        [_ambientRoseView.trailingAnchor constraintEqualToAnchor:_cardSurfaceView.trailingAnchor constant:54.0],
        [_ambientRoseView.topAnchor constraintEqualToAnchor:_cardSurfaceView.topAnchor constant:-54.0],

        [_ambientMintView.widthAnchor constraintEqualToAnchor:_cardSurfaceView.widthAnchor multiplier:0.46],
        [_ambientMintView.heightAnchor constraintEqualToAnchor:_ambientMintView.widthAnchor],
        [_ambientMintView.leadingAnchor constraintEqualToAnchor:_cardSurfaceView.leadingAnchor constant:-44.0],
        [_ambientMintView.bottomAnchor constraintEqualToAnchor:_cardSurfaceView.bottomAnchor constant:48.0],

        [_ambientPeachView.widthAnchor constraintEqualToAnchor:_cardSurfaceView.widthAnchor multiplier:0.34],
        [_ambientPeachView.heightAnchor constraintEqualToAnchor:_ambientPeachView.widthAnchor],
        [_ambientPeachView.centerXAnchor constraintEqualToAnchor:_cardSurfaceView.centerXAnchor],
        [_ambientPeachView.centerYAnchor constraintEqualToAnchor:_cardSurfaceView.centerYAnchor constant:20.0],

        [_hairlineView.topAnchor constraintEqualToAnchor:_cardSurfaceView.topAnchor],
        [_hairlineView.leadingAnchor constraintEqualToAnchor:_cardSurfaceView.leadingAnchor],
        [_hairlineView.trailingAnchor constraintEqualToAnchor:_cardSurfaceView.trailingAnchor],
        [_hairlineView.heightAnchor constraintEqualToConstant:1.0],

        [_contentWrapView.topAnchor constraintEqualToAnchor:_cardSurfaceView.topAnchor constant:20.0],
        [_contentWrapView.bottomAnchor constraintEqualToAnchor:_cardSurfaceView.bottomAnchor constant:-20.0],
        [_contentWrapView.leadingAnchor constraintEqualToAnchor:_cardSurfaceView.leadingAnchor constant:22.0],

        [_visualStageView.centerYAnchor constraintEqualToAnchor:_cardSurfaceView.centerYAnchor],
        [_visualStageView.trailingAnchor constraintEqualToAnchor:_cardSurfaceView.trailingAnchor constant:-8.0],
        self.visualWidthConstraint,
        self.visualHeightConstraint,

        [_contentWrapView.trailingAnchor constraintEqualToAnchor:_visualStageView.leadingAnchor constant:-14.0],

        [_visualOrbView.centerXAnchor constraintEqualToAnchor:_visualStageView.centerXAnchor],
        [_visualOrbView.centerYAnchor constraintEqualToAnchor:_visualStageView.centerYAnchor constant:6.0],
        [_visualOrbView.widthAnchor constraintEqualToAnchor:_visualStageView.widthAnchor multiplier:0.92],
        [_visualOrbView.heightAnchor constraintEqualToAnchor:_visualOrbView.widthAnchor],

        [_visualGlassView.centerXAnchor constraintEqualToAnchor:_visualStageView.centerXAnchor],
        [_visualGlassView.centerYAnchor constraintEqualToAnchor:_visualStageView.centerYAnchor],
        [_visualGlassView.widthAnchor constraintEqualToAnchor:_visualStageView.widthAnchor multiplier:0.94],
        [_visualGlassView.heightAnchor constraintEqualToAnchor:_visualStageView.heightAnchor multiplier:0.82],

        [_seedImageView.centerXAnchor constraintEqualToAnchor:_visualGlassView.centerXAnchor],
        [_seedImageView.bottomAnchor constraintEqualToAnchor:_visualGlassView.bottomAnchor constant:-12.0],
        [_seedImageView.widthAnchor constraintEqualToAnchor:_visualGlassView.widthAnchor multiplier:0.58],
        [_seedImageView.heightAnchor constraintEqualToAnchor:_visualGlassView.heightAnchor multiplier:0.30],

        [_lottieHeaderView.centerXAnchor constraintEqualToAnchor:_visualGlassView.centerXAnchor],
        [_lottieHeaderView.centerYAnchor constraintEqualToAnchor:_visualGlassView.centerYAnchor constant:-1.0],
        [_lottieHeaderView.widthAnchor constraintEqualToAnchor:_visualGlassView.widthAnchor multiplier:1.58],
        [_lottieHeaderView.heightAnchor constraintEqualToAnchor:_visualGlassView.heightAnchor multiplier:1.58],

        [_badgePillView.topAnchor constraintEqualToAnchor:_contentWrapView.topAnchor],
        [_badgePillView.leadingAnchor constraintEqualToAnchor:_contentWrapView.leadingAnchor],
        [_badgePillView.trailingAnchor constraintLessThanOrEqualToAnchor:_contentWrapView.trailingAnchor],

        [_badgeLabel.topAnchor constraintEqualToAnchor:_badgePillView.topAnchor constant:7.0],
        [_badgeLabel.leadingAnchor constraintEqualToAnchor:_badgePillView.leadingAnchor constant:12.0],
        [_badgeLabel.trailingAnchor constraintEqualToAnchor:_badgePillView.trailingAnchor constant:-12.0],
        [_badgeLabel.bottomAnchor constraintEqualToAnchor:_badgePillView.bottomAnchor constant:-7.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_badgePillView.bottomAnchor constant:10.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_contentWrapView.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_contentWrapView.trailingAnchor],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_contentWrapView.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_contentWrapView.trailingAnchor],
        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_ctaPillView.topAnchor constant:-10.0],

        [_ctaPillView.leadingAnchor constraintEqualToAnchor:_contentWrapView.leadingAnchor],
        [_ctaPillView.bottomAnchor constraintEqualToAnchor:_contentWrapView.bottomAnchor],
        [_ctaPillView.heightAnchor constraintEqualToConstant:44.0],
        [_ctaPillView.widthAnchor constraintLessThanOrEqualToAnchor:_contentWrapView.widthAnchor],
        [_ctaPillView.widthAnchor constraintGreaterThanOrEqualToConstant:142.0],

        [_ctaLabel.centerYAnchor constraintEqualToAnchor:_ctaPillView.centerYAnchor],
        [_ctaLabel.leadingAnchor constraintEqualToAnchor:_ctaPillView.leadingAnchor constant:18.0],

        [_ctaIconView.leadingAnchor constraintEqualToAnchor:_ctaLabel.trailingAnchor constant:10.0],
        [_ctaIconView.trailingAnchor constraintEqualToAnchor:_ctaPillView.trailingAnchor constant:-14.0],
        [_ctaIconView.centerYAnchor constraintEqualToAnchor:_ctaPillView.centerYAnchor],
        [_ctaIconView.widthAnchor constraintEqualToConstant:18.0],
        [_ctaIconView.heightAnchor constraintEqualToConstant:18.0],
    ]];
}

#pragma mark - Styling

- (void)pp_applyBaseStyle {
    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    CGFloat cornerRadius = 30.0;
    self.cardSurfaceView.layer.cornerRadius = cornerRadius;
    self.layer.cornerRadius = cornerRadius;
    if (@available(iOS 13.0, *)) {
        self.cardSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.visualGlassView.layer.cornerCurve = kCACornerCurveContinuous;
        self.badgePillView.layer.cornerCurve = kCACornerCurveContinuous;
        self.ctaPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [self pp_setShadowColor:[UIColor colorWithRed:0.13 green:0.08 blue:0.10 alpha:1.0]];
    self.layer.shadowOpacity = isDark ? 0.24 : 0.13;
    self.layer.shadowRadius = isDark ? 22.0 : 26.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 14.0);

    UIColor *surfaceA = isDark ? [UIColor hx_colorWithHexStr:@"#1C2025"] : [UIColor colorWithWhite:1.0 alpha:0.98];
    UIColor *surfaceB = isDark ? [UIColor hx_colorWithHexStr:@"#14171C"] : [UIColor hx_colorWithHexStr:@"#F7FAF7"];
    UIColor *surfaceC = isDark ? [UIColor hx_colorWithHexStr:@"#211A20"] : [UIColor hx_colorWithHexStr:@"#FFF3F7"];
    self.surfaceGradientLayer.colors = @[(id)surfaceA.CGColor, (id)surfaceB.CGColor, (id)surfaceC.CGColor];
    self.surfaceGradientLayer.locations = @[@0.0, @0.56, @1.0];

    UIColor *ink = isDark ? [UIColor colorWithWhite:0.96 alpha:1.0] : [UIColor hx_colorWithHexStr:@"#14181F"];
    UIColor *muted = isDark ? [UIColor colorWithWhite:0.78 alpha:1.0] : [UIColor hx_colorWithHexStr:@"#66717D"];
    UIColor *rose = AppPrimaryClr ?: [UIColor hx_colorWithHexStr:@"#C22D5A"];

    self.titleLabel.textColor = ink;
    self.subtitleLabel.textColor = muted;
    self.badgeLabel.textColor = rose;
    self.badgePillView.backgroundColor = [rose colorWithAlphaComponent:isDark ? 0.14 : 0.08];
    [self.badgePillView pp_setBorderColor:[rose colorWithAlphaComponent:isDark ? 0.24 : 0.13]];

    self.visualGradientLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:isDark ? 0.13 : 0.84].CGColor,
        (id)[UIColor hx_colorWithHexStr:isDark ? @"#232B2A" : @"#EEF8F1"].CGColor,
        (id)[UIColor hx_colorWithHexStr:isDark ? @"#2A1F26" : @"#FCECF2"].CGColor
    ];
    self.visualGradientLayer.locations = @[@0.0, @0.55, @1.0];
    [self.visualGlassView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:isDark ? 0.10 : 0.70]];

    self.ctaGradientLayer.colors = @[
        (id)[rose colorWithAlphaComponent:1.0].CGColor,
        (id)[[UIColor hx_colorWithHexStr:@"#A91F49"] colorWithAlphaComponent:1.0].CGColor
    ];
    self.ctaLabel.textColor = UIColor.whiteColor;
    self.ctaIconView.tintColor = UIColor.whiteColor;

    self.hairlineGradientLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:isDark ? 0.10 : 0.86].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    self.hairlineGradientLayer.locations = @[@0.0, @0.50, @1.0];

    [self pp_applyCurrentDirection];
}

- (void)pp_applyCurrentDirection {
    BOOL isRTL = Language.isRTL;
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    self.contentView.semanticContentAttribute = semantic;
    self.cardSurfaceView.semanticContentAttribute = semantic;
    self.contentWrapView.semanticContentAttribute = semantic;
    self.badgePillView.semanticContentAttribute = semantic;
    self.ctaPillView.semanticContentAttribute = semantic;
    self.visualStageView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.visualGlassView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    self.titleLabel.textAlignment = alignment;
    self.subtitleLabel.textAlignment = alignment;
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.ctaLabel.textAlignment = alignment;
    self.ctaIconView.image = [self pp_systemImage:(isRTL ? @"arrow.left" : @"arrow.right")
                                        fallback:@"arrow.right"];

    self.surfaceGradientLayer.startPoint = isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
    self.visualGradientLayer.startPoint = isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    self.visualGradientLayer.endPoint = isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
    self.ctaGradientLayer.startPoint = isRTL ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    self.ctaGradientLayer.endPoint = isRTL ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);
}

- (void)pp_refreshGeometry {
    CGFloat cornerRadius = 30.0;
    CGFloat width = CGRectGetWidth(self.bounds);
    BOOL compact = width > 0.0 && width < 370.0;
    self.titleLabel.font = [GM boldFontWithSize:compact ? 22.0 : 26.0];
    self.subtitleLabel.font = [GM MidFontWithSize:compact ? 13.5 : 14.5];
    CGFloat visualWidth = CGRectGetWidth(self.cardSurfaceView.bounds) * (compact ? 0.36 : 0.40);
    self.visualWidthConstraint.constant = MAX(compact ? 112.0 : 132.0, MIN(visualWidth, compact ? 138.0 : 168.0));

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.surfaceGradientLayer.frame = self.cardSurfaceView.bounds;
    self.surfaceGradientLayer.cornerRadius = cornerRadius;
    self.visualGradientLayer.frame = self.visualGlassView.bounds;
    self.visualGradientLayer.cornerRadius = self.visualGlassView.layer.cornerRadius;
    self.ctaGradientLayer.frame = self.ctaPillView.bounds;
    self.ctaGradientLayer.cornerRadius = self.ctaPillView.layer.cornerRadius;
    self.hairlineGradientLayer.frame = self.hairlineView.bounds;
    [CATransaction commit];

    self.cardSurfaceView.layer.cornerRadius = cornerRadius;
    self.visualGlassView.layer.cornerRadius = MIN(34.0, CGRectGetHeight(self.visualGlassView.bounds) * 0.24);
    self.badgePillView.layer.cornerRadius = CGRectGetHeight(self.badgePillView.bounds) * 0.5;
    self.ctaPillView.layer.cornerRadius = CGRectGetHeight(self.ctaPillView.bounds) * 0.5;
    self.ambientRoseView.layer.cornerRadius = CGRectGetWidth(self.ambientRoseView.bounds) * 0.5;
    self.ambientMintView.layer.cornerRadius = CGRectGetWidth(self.ambientMintView.bounds) * 0.5;
    self.ambientPeachView.layer.cornerRadius = CGRectGetWidth(self.ambientPeachView.bounds) * 0.5;
    self.visualOrbView.layer.cornerRadius = CGRectGetWidth(self.visualOrbView.bounds) * 0.5;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;
}

#pragma mark - Actions

- (void)pp_handleTap {
    [self pp_emitTapFeedback];
    if (self.onTap) {
        self.onTap();
    }
}

- (void)pp_handlePress:(UILongPressGestureRecognizer *)gesture {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    if (gesture.state == UIGestureRecognizerStateBegan) {
        [UIView animateWithDuration:0.10
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.cardSurfaceView.transform = CGAffineTransformMakeScale(0.982, 0.982);
            self.contentWrapView.transform = CGAffineTransformMakeTranslation(0.0, 1.0);
        } completion:nil];
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled ||
               gesture.state == UIGestureRecognizerStateFailed) {
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.22
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.cardSurfaceView.transform = CGAffineTransformIdentity;
            self.contentWrapView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_emitTapFeedback {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
}

#pragma mark - Lottie

- (void)pp_loadAnimationIfNeeded {
    if (self.didRequestAnimation) {
        return;
    }

    self.didRequestAnimation = YES;
    self.animationLoaded = NO;
    self.lottieHeaderView.hidden = YES;

    __weak typeof(self) weakSelf = self;
    [AppClasses setAnimationNamed:@"WomanPlayingWithCat"
                           ToView:self.lottieHeaderView
                        withSpeed:0.92f
                       completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.animationLoaded = success;
        strongSelf.lottieHeaderView.hidden = !success;
        strongSelf.lottieHeaderView.alpha = success ? 1.0 : 0.0;
        [strongSelf pp_playLottieIfPossible];
    }];
}

- (void)pp_playLottieIfPossible {
    if (!self.window || !self.animationLoaded || self.lottieHeaderView.hidden) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.lottieHeaderView stop];
        self.lottieHeaderView.animationProgress = 0.42;
        return;
    }

    if (!self.lottieHeaderView.isAnimationPlaying) {
        [self.lottieHeaderView play];
    }
}

#pragma mark - Motion

- (void)pp_runEntranceIfNeeded {
    if (self.didRunEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = 1.0;
        self.cardSurfaceView.transform = CGAffineTransformIdentity;
        return;
    }

    self.didRunEntrance = YES;
    self.alpha = 0.0;
    self.cardSurfaceView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 14.0),
                                                            CGAffineTransformMakeScale(0.985, 0.985));
    [UIView animateWithDuration:0.44
                          delay:0.04
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.alpha = 1.0;
        self.cardSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_startLivingMotionIfNeeded {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopLivingMotion];
        return;
    }

    if ([self.visualStageView.layer animationForKey:PPAdoptBreathingAnimationKey]) {
        return;
    }

    [self pp_addFloatAnimationToView:self.visualStageView
                                 key:PPAdoptBreathingAnimationKey
                            duration:5.6
                         translation:CGPointMake(0.0, -3.0)];
    [self pp_addFloatAnimationToView:self.lottieHeaderView
                                 key:PPAdoptBreathingAnimationKey
                            duration:5.6
                         translation:CGPointMake(0.0, -2.0)];
    [self pp_addFloatAnimationToView:self.ambientRoseView
                                 key:PPAdoptGlowAnimationKey
                            duration:7.4
                         translation:CGPointMake(-8.0, 5.0)];
    [self pp_addFloatAnimationToView:self.ambientMintView
                                 key:PPAdoptGlowAnimationKey
                            duration:8.2
                         translation:CGPointMake(6.0, -6.0)];
    [self pp_addFloatAnimationToView:self.ambientPeachView
                                 key:PPAdoptGlowAnimationKey
                            duration:9.0
                         translation:CGPointMake(5.0, 4.0)];
}

- (void)pp_stopLivingMotion {
    for (UIView *view in @[self.visualStageView, self.lottieHeaderView, self.ambientRoseView, self.ambientMintView, self.ambientPeachView]) {
        [view.layer removeAnimationForKey:PPAdoptBreathingAnimationKey];
        [view.layer removeAnimationForKey:PPAdoptGlowAnimationKey];
        view.transform = CGAffineTransformIdentity;
    }
}

- (void)pp_addFloatAnimationToView:(UIView *)view
                               key:(NSString *)key
                          duration:(NSTimeInterval)duration
                       translation:(CGPoint)translation
{
    if (!view) {
        return;
    }

    CABasicAnimation *xAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    xAnimation.fromValue = @0.0;
    xAnimation.toValue = @(translation.x);
    xAnimation.duration = duration;
    xAnimation.autoreverses = YES;
    xAnimation.repeatCount = HUGE_VALF;
    xAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    xAnimation.removedOnCompletion = NO;

    CABasicAnimation *yAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    yAnimation.fromValue = @0.0;
    yAnimation.toValue = @(translation.y);
    yAnimation.duration = duration;
    yAnimation.autoreverses = YES;
    yAnimation.repeatCount = HUGE_VALF;
    yAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    yAnimation.removedOnCompletion = NO;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[xAnimation, yAnimation];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.removedOnCompletion = NO;
    [view.layer addAnimation:group forKey:key];
}

#pragma mark - Helpers

- (void)pp_configureSeedImage:(nullable UIImage *)seedImage {
    if (!seedImage) {
        self.seedImageView.image = nil;
        self.seedImageView.hidden = YES;
        return;
    }

    self.seedImageView.image = [seedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.seedImageView.tintColor = [[UIColor hx_colorWithHexStr:@"#26313A"] colorWithAlphaComponent:0.32];
    self.seedImageView.hidden = NO;
}

- (UIView *)pp_makeAtmosphereViewWithColor:(UIColor *)color
                                     alpha:(CGFloat)alpha
                               shadowAlpha:(CGFloat)shadowAlpha
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.backgroundColor = [color colorWithAlphaComponent:alpha];
    [view pp_setShadowColor:color];
    view.layer.shadowOpacity = shadowAlpha;
    view.layer.shadowRadius = 30.0;
    view.layer.shadowOffset = CGSizeZero;
    return view;
}

- (nullable UIImage *)pp_systemImage:(NSString *)name fallback:(NSString *)fallbackName {
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:name];
        if (!image && fallbackName.length > 0) {
            image = [UIImage systemImageNamed:fallbackName];
        }
        return image;
    }
    return nil;
}

@end
