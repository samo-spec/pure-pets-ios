//
//  PetAdoptCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/08/2025.
//

#import "PetAdoptCollectionViewCell.h"
#import "AppClasses.h"

@interface PetAdoptCollectionViewCell ()

@property (nonatomic, strong) UIView *cardSurfaceView;
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;
@property (nonatomic, strong) UIView *shineOverlayView;
@property (nonatomic, strong) CAGradientLayer *shineGradientLayer;

@property (nonatomic, strong) UIView *ambientWarmGlowView;
@property (nonatomic, strong) UIView *ambientMintGlowView;
@property (nonatomic, strong) UIView *accentDotView;

@property (nonatomic, strong) UIStackView *contentRowStack;
@property (nonatomic, strong) UIView *textContainerView;
@property (nonatomic, strong) UIView *visualContainerView;
@property (nonatomic, strong) UIView *visualHaloView;
@property (nonatomic, strong) UIView *visualHaloSecondaryView;
@property (nonatomic, strong) UIView *visualStageView;
@property (nonatomic, strong) CAGradientLayer *visualStageGradientLayer;
@property (nonatomic, strong) UIView *stageGlossView;
@property (nonatomic, strong) UIImageView *seedImageView;

@property (nonatomic, strong) UIView *badgePillView;
@property (nonatomic, strong) UIStackView *badgeStackView;
@property (nonatomic, strong) UIImageView *badgeIconView;
@property (nonatomic, strong) UILabel *badgeLabel;

@property (nonatomic, strong) UIView *ctaPillView;
@property (nonatomic, strong) CAGradientLayer *ctaGradientLayer;
@property (nonatomic, strong) UIStackView *ctaStackView;
@property (nonatomic, strong) UIView *ctaIconBadgeView;
@property (nonatomic, strong) UILabel *ctaLabel;
@property (nonatomic, strong) UIImageView *ctaIconView;

@property (nonatomic, assign) BOOL didRequestAnimation;
@property (nonatomic, assign) BOOL animationLoaded;
@property (nonatomic, assign) BOOL idleAnimationStarted;
@property (nonatomic, strong) UIView *ContView;
@end

@implementation PetAdoptCollectionViewCell

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self pp_buildViewHierarchy];
        [self pp_buildConstraints];
        [self pp_applyBaseStyle];
        [self pp_loadAnimationIfNeeded];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onTap = nil;
    self.seedImageView.image = nil;
    self.seedImageView.hidden = YES;
    [self pp_applyCurrentDirection];
}

- (void)pp_refreshVisualGeometry {
    CGRect cardBounds = self.cardSurfaceView.bounds;
    if (CGRectIsEmpty(cardBounds)) {
        return;
    }

    CGFloat corners = 24.0f;
    self.cardSurfaceView.layer.cornerRadius = corners;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.bgGradientLayer.frame = cardBounds;
    self.bgGradientLayer.cornerRadius = corners;
    self.shineGradientLayer.frame = self.shineOverlayView.bounds;
    self.ctaGradientLayer.frame = self.ctaPillView.bounds;
    self.visualStageGradientLayer.frame = self.visualStageView.bounds;
    [CATransaction commit];

    self.shineOverlayView.layer.cornerRadius = corners;
    self.ContView.layer.cornerRadius = corners;
    self.ContView.layer.cornerCurve = kCACornerCurveContinuous;

    self.badgePillView.layer.cornerRadius = CGRectGetHeight(self.badgePillView.bounds) * 0.5;
    self.ctaPillView.layer.cornerRadius = CGRectGetHeight(self.ctaPillView.bounds) * 0.5;
    self.ctaGradientLayer.cornerRadius = self.ctaPillView.layer.cornerRadius;
    self.ctaIconBadgeView.layer.cornerRadius = 2;

    self.ambientWarmGlowView.layer.cornerRadius = CGRectGetWidth(self.ambientWarmGlowView.bounds) * 0.5;
    self.ambientMintGlowView.layer.cornerRadius = CGRectGetWidth(self.ambientMintGlowView.bounds) * 0.5;
    self.accentDotView.layer.cornerRadius = CGRectGetWidth(self.accentDotView.bounds) * 0.5;
    self.visualHaloView.layer.cornerRadius = CGRectGetWidth(self.visualHaloView.bounds) * 0.5;
    self.visualHaloSecondaryView.layer.cornerRadius = CGRectGetWidth(self.visualHaloSecondaryView.bounds) * 0.5;
    self.visualStageView.layer.cornerRadius = MIN(30.0, CGRectGetHeight(self.visualStageView.bounds) * 0.24);
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:corners].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshThemeColors];
        }
    }
}

- (void)pp_refreshThemeColors
{
    [self pp_setShadowColor:[UIColor colorWithRed:0.11 green:0.17 blue:0.22 alpha:1.0]];
    [self pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.6]];
    [self pp_applyGradientForRTL:Language.isRTL];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self pp_refreshVisualGeometry];

    if (!self.idleAnimationStarted && CGRectGetWidth(self.cardSurfaceView.bounds) > 0.0) {
        self.idleAnimationStarted = YES;
        [self pp_startIdleFloatAnimation];
    }
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
    [self pp_refreshVisualGeometry];
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    [self pp_refreshVisualGeometry];
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

    self.lottieHeaderView.hidden = !self.animationLoaded;
    [self pp_applyCurrentDirection];
    [self pp_applyGradientForRTL:Language.isRTL];

    self.ContView.accessibilityLabel =
        [NSString stringWithFormat:@"%@. %@",
                                   self.titleLabel.text ?: @"",
                                   self.subtitleLabel.text ?: @""];
    self.ContView.accessibilityHint = self.ctaLabel.text;

    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    if (!CGRectIsEmpty(self.cardSurfaceView.bounds)) {
        [self layoutIfNeeded];
        [self pp_refreshVisualGeometry];
    }
}

#pragma mark - Actions

- (void)handleTap {
    if (self.onTap) {
        self.onTap();
    }
}

#pragma mark - Build View Hierarchy

- (void)pp_buildViewHierarchy {
    CGFloat corners = MAX(26.0, PPCornersHome);

    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;

    [self pp_setShadowColor:[UIColor colorWithRed:0.11 green:0.17 blue:0.22 alpha:1.0]];
    self.layer.shadowOpacity = 0.16f;
    self.layer.shadowRadius = 28.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.6]];
    self.layer.borderWidth = 0.9;
    self.layer.cornerRadius = corners;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    
    _ContView = [[UIView alloc] init];
    _ContView.translatesAutoresizingMaskIntoConstraints = NO;
    _ContView.backgroundColor = UIColor.clearColor;
    _ContView.clipsToBounds = NO;
    _ContView.accessibilityTraits = UIAccessibilityTraitButton;
    _ContView.userInteractionEnabled = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [_ContView addGestureRecognizer:tap];

    [self.contentView addSubview:_ContView];

    _cardSurfaceView = [[UIView alloc] init];
    _cardSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardSurfaceView.backgroundColor = UIColor.clearColor;
    _cardSurfaceView.clipsToBounds = YES;
    _cardSurfaceView.userInteractionEnabled = NO;
    _cardSurfaceView.layer.cornerRadius = corners;
    if (@available(iOS 13.0, *)) {
        _cardSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    _bgGradientLayer = [CAGradientLayer layer];
    [_cardSurfaceView.layer insertSublayer:_bgGradientLayer atIndex:0];
    
    
    [_ContView addSubview:_cardSurfaceView];

   

    _ambientWarmGlowView = [self pp_makeGlowViewWithColor:[UIColor hx_colorWithHexStr:@"#FFCEB4"]
                                                    alpha:0.42
                                              shadowAlpha:0.18];
    [_cardSurfaceView addSubview:_ambientWarmGlowView];

    _ambientMintGlowView = [self pp_makeGlowViewWithColor:[UIColor hx_colorWithHexStr:@"#D3F1DF"]
                                                    alpha:0.36
                                              shadowAlpha:0.14];
    [_cardSurfaceView addSubview:_ambientMintGlowView];

    _accentDotView = [self pp_makeGlowViewWithColor:[UIColor hx_colorWithHexStr:@"#F5A66E"]
                                              alpha:0.90
                                        shadowAlpha:0.12];
    [_cardSurfaceView addSubview:_accentDotView];

    _shineOverlayView = [[UIView alloc] init];
    _shineOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    _shineOverlayView.userInteractionEnabled = NO;
    _shineOverlayView.backgroundColor = UIColor.clearColor;
    _shineGradientLayer = [CAGradientLayer layer];
    _shineGradientLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    _shineGradientLayer.locations = @[@0.0, @0.30, @0.82];
    [_shineOverlayView.layer addSublayer:_shineGradientLayer];
    [_cardSurfaceView addSubview:_shineOverlayView];

    _contentRowStack = [[UIStackView alloc] init];
    _contentRowStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentRowStack.axis = UILayoutConstraintAxisHorizontal;
    _contentRowStack.alignment = UIStackViewAlignmentFill;
    _contentRowStack.distribution = UIStackViewDistributionFill;
    _contentRowStack.spacing = 14.0;
    [_cardSurfaceView addSubview:_contentRowStack];

    _textContainerView = [[UIView alloc] init];
    _textContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _textContainerView.backgroundColor = UIColor.clearColor;
    [_contentRowStack addArrangedSubview:_textContainerView];

    _visualContainerView = [[UIView alloc] init];
    _visualContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _visualContainerView.backgroundColor = UIColor.clearColor;
    _visualContainerView.clipsToBounds = NO;
    [_contentRowStack addArrangedSubview:_visualContainerView];

    [_visualContainerView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                          forAxis:UILayoutConstraintAxisHorizontal];
    [_visualContainerView setContentHuggingPriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisHorizontal];

    _visualHaloView = [self pp_makeGlowViewWithColor:[UIColor hx_colorWithHexStr:@"#FFD4BC"]
                                               alpha:0.40
                                         shadowAlpha:0.16];
    [_visualContainerView addSubview:_visualHaloView];

    _visualHaloSecondaryView = [self pp_makeGlowViewWithColor:[UIColor hx_colorWithHexStr:@"#CDE2FF"]
                                                        alpha:0.42
                                                  shadowAlpha:0.12];
    [_visualContainerView addSubview:_visualHaloSecondaryView];

    _visualStageView = [[UIView alloc] init];
    _visualStageView.translatesAutoresizingMaskIntoConstraints = NO;
    _visualStageView.clipsToBounds = NO;
    _visualStageView.layer.borderWidth = 0.0;
    if (@available(iOS 13.0, *)) {
        _visualStageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_visualContainerView addSubview:_visualStageView];

    _visualStageGradientLayer = [CAGradientLayer layer];
    [_visualStageView.layer insertSublayer:_visualStageGradientLayer atIndex:0];

    _stageGlossView = [[UIView alloc] init];
    _stageGlossView.translatesAutoresizingMaskIntoConstraints = NO;
    _stageGlossView.userInteractionEnabled = NO;
    [_visualStageView addSubview:_stageGlossView];

    _seedImageView = [[UIImageView alloc] init];
    _seedImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _seedImageView.contentMode = UIViewContentModeScaleAspectFit;
    _seedImageView.alpha = 0.0;
    _seedImageView.hidden = YES;
    [_visualStageView addSubview:_seedImageView];

    _lottieHeaderView = [[LOTAnimationView alloc] init];
    _lottieHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    _lottieHeaderView.userInteractionEnabled = NO;
    _lottieHeaderView.backgroundColor = UIColor.clearColor;
    _lottieHeaderView.opaque = NO;
    _lottieHeaderView.contentMode = UIViewContentModeScaleAspectFit;
    _lottieHeaderView.loopAnimation = YES;
    _lottieHeaderView.hidden = YES;
    [_visualStageView addSubview:_lottieHeaderView];

    _badgePillView = [[UIView alloc] init];
    _badgePillView.translatesAutoresizingMaskIntoConstraints = NO;
    _badgePillView.layer.borderWidth = 1.0;
    _badgePillView.layer.cornerRadius = 12;
    _badgePillView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _badgePillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_textContainerView addSubview:_badgePillView];

    _badgeStackView = [[UIStackView alloc] init];
    _badgeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeStackView.axis = UILayoutConstraintAxisHorizontal;
    _badgeStackView.alignment = UIStackViewAlignmentLeading;
    _badgeStackView.spacing = 7.0;
    [_badgePillView addSubview:_badgeStackView];

    _badgeIconView = [[UIImageView alloc] init];
    _badgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    _badgeIconView.image = [self pp_systemImage:@"sparkles" fallback:@"pawprint.fill"];
   

    _badgeLabel = [[UILabel alloc] init];
    _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeLabel.font = [GM boldFontWithSize:13.5];
    _badgeLabel.adjustsFontForContentSizeCategory = YES;
    _badgeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_badgeStackView addArrangedSubview:_badgeLabel];
    [_badgeStackView addArrangedSubview:_badgeIconView];
    
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:24.0];
    _titleLabel.numberOfLines = 2;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    [_textContainerView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:14.5];
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [_textContainerView addSubview:_subtitleLabel];

    _ctaPillView = [[UIView alloc] init];
    _ctaPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaPillView.clipsToBounds = YES;
    _ctaPillView.layer.borderWidth = 1.0;
    _ctaPillView.layer.cornerRadius = 16;
    if (@available(iOS 13.0, *)) {
        _ctaPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_textContainerView addSubview:_ctaPillView];

    _ctaGradientLayer = [CAGradientLayer layer];
    [_ctaPillView.layer insertSublayer:_ctaGradientLayer atIndex:0];

    _ctaStackView = [[UIStackView alloc] init];
    _ctaStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaStackView.axis = UILayoutConstraintAxisHorizontal;
    _ctaStackView.alignment = UIStackViewAlignmentCenter;
    _ctaStackView.spacing = 10.0;
    [_ctaPillView addSubview:_ctaStackView];

    _ctaLabel = [[UILabel alloc] init];
    _ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaLabel.font = [GM boldFontWithSize:15.5];
    _ctaLabel.adjustsFontForContentSizeCategory = YES;
    [_ctaStackView addArrangedSubview:_ctaLabel];

    _ctaIconBadgeView = [[UIView alloc] init];
    _ctaIconBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaIconBadgeView.clipsToBounds = YES;
    [_ctaStackView addArrangedSubview:_ctaIconBadgeView];

    _ctaIconView = [[UIImageView alloc] init];
    _ctaIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_ctaIconBadgeView addSubview:_ctaIconView];
}

#pragma mark - Build Constraints

- (void)pp_buildConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [_ContView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_ContView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_ContView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_ContView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_cardSurfaceView.topAnchor constraintEqualToAnchor:_ContView.topAnchor],
        [_cardSurfaceView.leadingAnchor constraintEqualToAnchor:_ContView.leadingAnchor],
        [_cardSurfaceView.trailingAnchor constraintEqualToAnchor:_ContView.trailingAnchor],
        [_cardSurfaceView.bottomAnchor constraintEqualToAnchor:_ContView.bottomAnchor],

        [_shineOverlayView.topAnchor constraintEqualToAnchor:_cardSurfaceView.topAnchor],
        [_shineOverlayView.leadingAnchor constraintEqualToAnchor:_cardSurfaceView.leadingAnchor],
        [_shineOverlayView.trailingAnchor constraintEqualToAnchor:_cardSurfaceView.trailingAnchor],
        [_shineOverlayView.bottomAnchor constraintEqualToAnchor:_cardSurfaceView.bottomAnchor],

        [_contentRowStack.topAnchor constraintEqualToAnchor:_cardSurfaceView.topAnchor constant:18.0],
        [_contentRowStack.leadingAnchor constraintEqualToAnchor:_cardSurfaceView.leadingAnchor constant:18.0],
        [_contentRowStack.trailingAnchor constraintEqualToAnchor:_cardSurfaceView.trailingAnchor constant:-18.0],
        [_contentRowStack.bottomAnchor constraintEqualToAnchor:_cardSurfaceView.bottomAnchor constant:-18.0],

        [_visualContainerView.widthAnchor constraintEqualToConstant:148.0],
        [_visualContainerView.widthAnchor constraintLessThanOrEqualToAnchor:_cardSurfaceView.widthAnchor multiplier:0.42],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [_ambientWarmGlowView.widthAnchor constraintEqualToConstant:118.0],
        [_ambientWarmGlowView.heightAnchor constraintEqualToConstant:118.0],
        [_ambientWarmGlowView.trailingAnchor constraintEqualToAnchor:_cardSurfaceView.trailingAnchor constant:26.0],
        [_ambientWarmGlowView.topAnchor constraintEqualToAnchor:_cardSurfaceView.topAnchor constant:-22.0],

        [_ambientMintGlowView.widthAnchor constraintEqualToConstant:88.0],
        [_ambientMintGlowView.heightAnchor constraintEqualToConstant:88.0],
        [_ambientMintGlowView.leadingAnchor constraintEqualToAnchor:_cardSurfaceView.leadingAnchor constant:8.0],
        [_ambientMintGlowView.bottomAnchor constraintEqualToAnchor:_cardSurfaceView.bottomAnchor constant:14.0],

        [_accentDotView.widthAnchor constraintEqualToConstant:18.0],
        [_accentDotView.heightAnchor constraintEqualToConstant:18.0],
        [_accentDotView.leadingAnchor constraintEqualToAnchor:_visualContainerView.leadingAnchor constant:8.0],
        [_accentDotView.topAnchor constraintEqualToAnchor:_visualContainerView.topAnchor constant:16.0],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [_visualHaloView.widthAnchor constraintEqualToConstant:158.0],
        [_visualHaloView.heightAnchor constraintEqualToConstant:158.0],
        [_visualHaloView.centerXAnchor constraintEqualToAnchor:_visualContainerView.centerXAnchor constant:4.0],
        [_visualHaloView.centerYAnchor constraintEqualToAnchor:_visualContainerView.centerYAnchor constant:2.0],

        [_visualHaloSecondaryView.widthAnchor constraintEqualToConstant:74.0],
        [_visualHaloSecondaryView.heightAnchor constraintEqualToConstant:74.0],
        [_visualHaloSecondaryView.centerXAnchor constraintEqualToAnchor:_visualHaloView.centerXAnchor constant:34.0],
        [_visualHaloSecondaryView.centerYAnchor constraintEqualToAnchor:_visualHaloView.centerYAnchor constant:-40.0],

        [_visualStageView.centerXAnchor constraintEqualToAnchor:_visualContainerView.centerXAnchor],
        [_visualStageView.centerYAnchor constraintEqualToAnchor:_visualContainerView.centerYAnchor],
        [_visualStageView.widthAnchor constraintEqualToAnchor:_visualContainerView.widthAnchor multiplier:0.94],
        [_visualStageView.heightAnchor constraintEqualToAnchor:_cardSurfaceView.heightAnchor multiplier:0.80],

        [_stageGlossView.topAnchor constraintEqualToAnchor:_visualStageView.topAnchor],
        [_stageGlossView.leadingAnchor constraintEqualToAnchor:_visualStageView.leadingAnchor],
        [_stageGlossView.trailingAnchor constraintEqualToAnchor:_visualStageView.trailingAnchor],
        [_stageGlossView.heightAnchor constraintEqualToAnchor:_visualStageView.heightAnchor multiplier:0.42],

        [_seedImageView.centerXAnchor constraintEqualToAnchor:_visualStageView.centerXAnchor],
        [_seedImageView.bottomAnchor constraintEqualToAnchor:_visualStageView.bottomAnchor constant:-12.0],
        [_seedImageView.widthAnchor constraintEqualToAnchor:_visualStageView.widthAnchor multiplier:0.74],
        [_seedImageView.heightAnchor constraintEqualToAnchor:_visualStageView.heightAnchor multiplier:0.34],

        [_lottieHeaderView.centerXAnchor constraintEqualToAnchor:_visualStageView.centerXAnchor],
        [_lottieHeaderView.centerYAnchor constraintEqualToAnchor:_visualStageView.centerYAnchor constant:-2.0],
        [_lottieHeaderView.widthAnchor constraintEqualToAnchor:_visualStageView.widthAnchor multiplier:1.6],
        [_lottieHeaderView.heightAnchor constraintEqualToAnchor:_visualStageView.heightAnchor multiplier:1.6],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [_badgePillView.topAnchor constraintEqualToAnchor:_textContainerView.topAnchor constant:2.0],
        [_badgePillView.leadingAnchor constraintEqualToAnchor:_textContainerView.leadingAnchor],
        [_badgePillView.widthAnchor constraintLessThanOrEqualToAnchor:_textContainerView.widthAnchor],

        [_badgeStackView.topAnchor constraintEqualToAnchor:_badgePillView.topAnchor constant:8.0],
        [_badgeStackView.leadingAnchor constraintEqualToAnchor:_badgePillView.leadingAnchor constant:12.0],
        [_badgeStackView.trailingAnchor constraintEqualToAnchor:_badgePillView.trailingAnchor constant:-14.0],
        [_badgeStackView.bottomAnchor constraintEqualToAnchor:_badgePillView.bottomAnchor constant:-8.0],

        [_badgeIconView.widthAnchor constraintEqualToConstant:13.0],
        [_badgeIconView.heightAnchor constraintEqualToConstant:13.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_badgePillView.bottomAnchor constant:8.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_badgeStackView.leadingAnchor constant:0.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_textContainerView.trailingAnchor ],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_textContainerView.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_textContainerView.trailingAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [_ctaPillView.leadingAnchor constraintEqualToAnchor:_textContainerView.leadingAnchor],
        [_ctaPillView.bottomAnchor constraintEqualToAnchor:_textContainerView.bottomAnchor constant:-2.0],
        [_ctaPillView.widthAnchor constraintLessThanOrEqualToAnchor:_textContainerView.widthAnchor],
        [_ctaPillView.heightAnchor constraintEqualToConstant:44],
        
        [_ctaStackView.topAnchor constraintEqualToAnchor:_ctaPillView.topAnchor constant:8.0],
        [_ctaStackView.leadingAnchor constraintEqualToAnchor:_ctaPillView.leadingAnchor constant:14.0],
        [_ctaStackView.trailingAnchor constraintEqualToAnchor:_ctaPillView.trailingAnchor constant:-8.0],
        [_ctaStackView.bottomAnchor constraintEqualToAnchor:_ctaPillView.bottomAnchor constant:-8.0],

        [_ctaIconBadgeView.widthAnchor constraintEqualToConstant:28.0],
        [_ctaIconBadgeView.heightAnchor constraintEqualToConstant:28.0],

        [_ctaIconView.centerXAnchor constraintEqualToAnchor:_ctaIconBadgeView.centerXAnchor],
        [_ctaIconView.centerYAnchor constraintEqualToAnchor:_ctaIconBadgeView.centerYAnchor],
        [_ctaIconView.widthAnchor constraintEqualToConstant:22.0],
        [_ctaIconView.heightAnchor constraintEqualToConstant:22.0],

        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_ctaPillView.topAnchor constant:-14.0],
    ]];
}

#pragma mark - Styling

- (void)pp_applyBaseStyle {
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [self pp_applyCurrentDirection];
    [self pp_applyGradientForRTL:Language.isRTL];
}

#pragma mark - Direction

- (void)pp_applyCurrentDirection {
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    for (UIView *view in @[
        self.contentView,
        self.ContView,
        self.cardSurfaceView,
        self.contentRowStack,
        self.textContainerView,
        self.badgePillView,
        self.badgeStackView,
        self.ctaPillView,
        self.ctaStackView
    ]) {
        view.semanticContentAttribute = semantic;
    }

    self.visualContainerView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.visualStageView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    self.titleLabel.textAlignment = alignment;
    self.subtitleLabel.textAlignment = alignment;
    //self.badgeLabel.textAlignment = alignment;
    self.ctaLabel.textAlignment = alignment;

    NSString *arrowName = Language.isRTL ? @"arrow.left" : @"arrow.right";
    self.ctaIconView.image = [self pp_systemImage:arrowName fallback:@"arrow.right"];
}

#pragma mark - Color System

- (void)pp_applyGradientForRTL:(BOOL)isRTL {
    UIColor *lightCream = [UIColor hx_colorWithHexStr:@"#FAF2E7"];
    UIColor *softSand = [UIColor hx_colorWithHexStr:@"#F3E5D3"];
    UIColor *warmBeige = [UIColor hx_colorWithHexStr:@"#EAD2B7"];
   // UIColor *lightCaramel = [UIColor hx_colorWithHexStr:@"#DDB892"];

 
     
    
    self.bgGradientLayer.colors = @[
        (id)[lightCream colorWithAlphaComponent:1.0].CGColor,
        (id)[softSand colorWithAlphaComponent:1.0].CGColor,
        (id)[warmBeige colorWithAlphaComponent:1.0].CGColor,
    ];

    // Direction: top → bottom
    self.bgGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bgGradientLayer.endPoint = CGPointMake(0.5, 1.0);

    // Smooth distribution (must match colors count = 3)
    self.bgGradientLayer.locations = @[@0.0, @0.5, @1.0];

   //
   // self.bgGradientLayer.startPoint = isRTL ? CGPointMake(1.0, 0.22) : CGPointMake(0.0, 0.22);
   // self.bgGradientLayer.endPoint = isRTL ? CGPointMake(0.0, 0.92) : CGPointMake(1.0, 0.92);

    self.shineGradientLayer.startPoint = isRTL ? CGPointMake(0.96, 0.02) : CGPointMake(0.04, 0.02);
    self.shineGradientLayer.endPoint = isRTL ? CGPointMake(0.28, 0.48) : CGPointMake(0.72, 0.48);

    self.visualStageGradientLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.96].CGColor,
        (id)[UIColor hx_colorWithHexStr:@"#F0F7F2"].CGColor,
        (id)[UIColor hx_colorWithHexStr:@"#F8EFE7"].CGColor
    ];
    self.visualStageGradientLayer.locations = @[@0.0, @0.58, @1.0];
    self.visualStageGradientLayer.startPoint = CGPointMake(isRTL ? 1.0 : 0.0, 0.0);
    self.visualStageGradientLayer.endPoint = CGPointMake(isRTL ? 0.0 : 1.0, 1.0);

    [self.visualStageView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.0]];
    self.stageGlossView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.76];
    
    self.badgePillView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.0];
    [self.badgePillView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.0]];
    self.badgeLabel.textColor = [UIColor hx_colorWithHexStr:@"#344351"];
    self.badgeIconView.tintColor = [AppPrimaryClr colorWithAlphaComponent:1];

    self.titleLabel.textColor = [UIColor hx_colorWithHexStr:@"#152030"];
    self.subtitleLabel.textColor = [UIColor hx_colorWithHexStr:@"#5F6A79"];

    self.ctaGradientLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.90].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.74].CGColor
    ];
    self.ctaGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.ctaGradientLayer.endPoint = CGPointMake(1.0, 0.5);
   
    self.ctaLabel.textColor = [UIColor hx_colorWithHexStr:@"#20313A"];
    self.ctaIconBadgeView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    self.ctaIconView.tintColor = UIColor.whiteColor;
    
    [self.ctaPillView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.9]];
    self.ctaPillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.6];

    self.ctaPillView.layer.cornerRadius = 18.0;
    self.visualStageView.layer.cornerRadius = 4.0;
    self.badgePillView.layer.cornerRadius = 4.0;
    self.ctaIconBadgeView.layer.cornerRadius = 14.0;

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
                        withSpeed:0.95f
                       completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        strongSelf.animationLoaded = success;
        strongSelf.lottieHeaderView.hidden = !success;
        if (success) {
            strongSelf.lottieHeaderView.alpha = 1.0;
            [strongSelf.lottieHeaderView play];
        }
    }];
}

#pragma mark - Ambient Animation

- (void)pp_startIdleFloatAnimation {
    [UIView animateWithDuration:4.4
                          delay:0.0
                        options:UIViewAnimationOptionRepeat |
                                UIViewAnimationOptionAutoreverse |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.ambientWarmGlowView.transform = CGAffineTransformMakeTranslation(-6.0, 4.0);
        self.ambientMintGlowView.transform = CGAffineTransformMakeTranslation(5.0, -5.0);
        self.visualHaloView.transform = CGAffineTransformMakeTranslation(-5.0, 6.0);
        self.visualHaloSecondaryView.transform = CGAffineTransformMakeTranslation(6.0, -4.0);
        self.accentDotView.transform = CGAffineTransformMakeTranslation(-3.0, 4.0);
        self.visualStageView.transform = CGAffineTransformMakeTranslation(0.0, -2.5);
        self.lottieHeaderView.transform = CGAffineTransformMakeTranslation(0.0, -2.5);
    } completion:nil];
}

#pragma mark - Helpers

- (void)pp_configureSeedImage:(nullable UIImage *)seedImage {
    if (!seedImage) {
        self.seedImageView.image = nil;
        self.seedImageView.hidden = YES;
        return;
    }

    self.seedImageView.image = [seedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.seedImageView.tintColor = [[UIColor hx_colorWithHexStr:@"#314B5D"] colorWithAlphaComponent:0.18];
    self.seedImageView.hidden = NO;
}

- (UIView *)pp_makeGlowViewWithColor:(UIColor *)color
                               alpha:(CGFloat)alpha
                         shadowAlpha:(CGFloat)shadowAlpha
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [color colorWithAlphaComponent:alpha];
    view.userInteractionEnabled = NO;
    [view pp_setShadowColor:color];
    view.layer.shadowOpacity = shadowAlpha;
    view.layer.shadowRadius = 26.0;
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
