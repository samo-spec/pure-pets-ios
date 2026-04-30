//
//  PPHomePremiumCareCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/29/26.
//

#import "PPHomePremiumCareCell.h"

static NSString * const PPHomePremiumCareMedicineAnimationName = @"Health1";

@implementation PPHomePremiumCareCell {
    UIView *_surfaceView;
    CAGradientLayer *_gradientLayer;
    UIView *_topBackgroundGlowView;
    UIView *_middleBackgroundGlowView;
    UIView *_bottomLeadingGlowView;
    UIView *_largeOrbView;
    UIView *_smallOrbView;
    UIView *_iconPlateView;
    UIImageView *_iconImageView;
    LOTAnimationView *_careAnimationView;
    NSMutableArray<UIView *> *_backgroundDotViews;
    UILabel *_eyebrowLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
   // UIStackView *_pillStackView;
    //UILabel *_medicinePillLabel;
    //UILabel *_vetPillLabel;
    UIView *_ctaView;
    UILabel *_ctaLabel;
    UIImageView *_ctaIconView;
    NSString *_currentCareAnimationName;
    NSInteger _careAnimationLoadToken;
    BOOL _didRevealCurrentCareAnimation;
}

+ (NSString *)reuseIdentifier
{
    return @"PPHomePremiumCareCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self.contentView pp_setShadowColor:UIColor.blackColor];
    self.contentView.layer.shadowRadius = 24.0;
    self.contentView.layer.shadowOffset = CGSizeMake(0.0, 12.0);

    _surfaceView = [UIView new];
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.layer.cornerRadius = 34.0;
    _surfaceView.layer.borderWidth = 0.8;
    _surfaceView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:_surfaceView];

    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _gradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_surfaceView.layer insertSublayer:_gradientLayer atIndex:0];

    _topBackgroundGlowView = [self pp_makePetCareGlowViewWithRadius:136.0];
    [_surfaceView addSubview:_topBackgroundGlowView];

    _middleBackgroundGlowView = [self pp_makePetCareGlowViewWithRadius:108.0];
    [_surfaceView addSubview:_middleBackgroundGlowView];

    _bottomLeadingGlowView = [self pp_makePetCareGlowViewWithRadius:132.0];
    [_surfaceView addSubview:_bottomLeadingGlowView];

    _largeOrbView = [[UIView alloc] init];
    _largeOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _largeOrbView.userInteractionEnabled = NO;
    _largeOrbView.layer.cornerRadius = 60.0;
    [_surfaceView addSubview:_largeOrbView];

    _smallOrbView = [[UIView alloc] init];
    _smallOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _smallOrbView.userInteractionEnabled = NO;
    _smallOrbView.layer.cornerRadius = 24.0;
    [_surfaceView addSubview:_smallOrbView];

    _backgroundDotViews = [NSMutableArray arrayWithCapacity:5];
    for (NSInteger idx = 0; idx < 5; idx++) {
        UIView *dotView = [[UIView alloc] init];
        dotView.translatesAutoresizingMaskIntoConstraints = NO;
        dotView.userInteractionEnabled = NO;
        dotView.layer.cornerRadius = (idx % 2 == 0) ? 2.5 : 2.0;
        [_surfaceView addSubview:dotView];
        [_backgroundDotViews addObject:dotView];
    }

    _iconPlateView = [[UIView alloc] init];
    _iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconPlateView.layer.cornerRadius = 38.0;
    _iconPlateView.layer.borderWidth = 0.0;
    _iconPlateView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_iconPlateView];

    _iconImageView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"pills.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [_surfaceView addSubview:_iconImageView];

    _careAnimationView = [[LOTAnimationView alloc] init];
    _careAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    _careAnimationView.backgroundColor = UIColor.clearColor;
    _careAnimationView.userInteractionEnabled = NO;
    _careAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    _careAnimationView.loopAnimation = YES;
    _careAnimationView.animationSpeed = 0.84;
    _careAnimationView.hidden = YES;
    [_surfaceView addSubview:_careAnimationView];

    _eyebrowLabel = [[UILabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _eyebrowLabel.numberOfLines = 1;
    [_surfaceView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:26.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.8;
    [_surfaceView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _subtitleLabel.numberOfLines = 2;
    [_surfaceView addSubview:_subtitleLabel];

    /*_pillStackView = [[UIStackView alloc] init];
    _pillStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _pillStackView.axis = UILayoutConstraintAxisHorizontal;
    _pillStackView.alignment = UIStackViewAlignmentFill;
    _pillStackView.spacing = 8.0;
    _pillStackView.distribution = UIStackViewDistributionFillProportionally;
    [_surfaceView addSubview:_pillStackView];

    _medicinePillLabel = [self pp_makePillLabel];
    _vetPillLabel = [self pp_makePillLabel];
    
    _medicinePillLabel.hidden = YES;
    _medicinePillLabel.alpha = 0;
    
    _vetPillLabel.hidden = YES;
    _vetPillLabel.alpha = 0;
    
    
    [_pillStackView addArrangedSubview:_medicinePillLabel];
    [_pillStackView addArrangedSubview:_vetPillLabel];
*/
    _ctaView = [[UIView alloc] init];
    _ctaView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaView.layer.cornerRadius = 20.0;
    _ctaView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _ctaView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_ctaView];

    _ctaLabel = [[UILabel alloc] init];
    _ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [_ctaView addSubview:_ctaLabel];

    NSString *forwardSymbol = Language.isRTL ? @"arrow.left" : @"arrow.right";
    _ctaIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:forwardSymbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _ctaIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _ctaIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_ctaView addSubview:_ctaIconView];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_topBackgroundGlowView.widthAnchor constraintEqualToConstant:272.0],
        [_topBackgroundGlowView.heightAnchor constraintEqualToConstant:272.0],
        [_topBackgroundGlowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:-82.0],
        [_topBackgroundGlowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:104.0],

        [_middleBackgroundGlowView.widthAnchor constraintEqualToConstant:216.0],
        [_middleBackgroundGlowView.heightAnchor constraintEqualToConstant:216.0],
        [_middleBackgroundGlowView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:-96.0],
        [_middleBackgroundGlowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:68.0],

        [_bottomLeadingGlowView.widthAnchor constraintEqualToConstant:156.0],
        [_bottomLeadingGlowView.heightAnchor constraintEqualToConstant:156.0],
        [_bottomLeadingGlowView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:-106.0],
        [_bottomLeadingGlowView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:102.0],

        [_largeOrbView.widthAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.heightAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:24.0],
        [_largeOrbView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:-24.0],

        [_smallOrbView.widthAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.heightAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:30.0],
        [_smallOrbView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:16.0],

        [_iconPlateView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-22.0],
        [_iconPlateView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:22.0],
        [_iconPlateView.widthAnchor constraintEqualToConstant: 66.0],
        [_iconPlateView.heightAnchor constraintEqualToConstant:66.0],

        [_iconImageView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
        [_iconImageView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
        [_iconImageView.widthAnchor constraintEqualToConstant:25.0],
        [_iconImageView.heightAnchor constraintEqualToConstant:25.0],

        [_careAnimationView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor ],
        [_careAnimationView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor constant:3],
        [_careAnimationView.widthAnchor constraintEqualToConstant:52.0],
        [_careAnimationView.heightAnchor constraintEqualToConstant:52.0],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:20.0],
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:18.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:7.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-20.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],

        [_pillStackView.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_pillStackView.topAnchor constraintGreaterThanOrEqualToAnchor:_subtitleLabel.bottomAnchor constant:12.0],
        [_pillStackView.trailingAnchor constraintLessThanOrEqualToAnchor:_surfaceView.trailingAnchor constant:-20.0],
        [_pillStackView.heightAnchor constraintEqualToConstant:30.0],

        [_ctaView.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_ctaView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-20.0],
        [_ctaView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-18.0],
        [_ctaView.heightAnchor constraintEqualToConstant:40.0],
        [_ctaView.topAnchor constraintEqualToAnchor:_pillStackView.bottomAnchor constant:10.0],

        [_ctaLabel.leadingAnchor constraintEqualToAnchor:_ctaView.leadingAnchor constant:14.0],
        [_ctaLabel.centerYAnchor constraintEqualToAnchor:_ctaView.centerYAnchor],
        [_ctaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_ctaIconView.leadingAnchor constant:-10.0],

        [_ctaIconView.trailingAnchor constraintEqualToAnchor:_ctaView.trailingAnchor constant:-14.0],
        [_ctaIconView.centerYAnchor constraintEqualToAnchor:_ctaView.centerYAnchor],
        [_ctaIconView.widthAnchor constraintEqualToConstant:14.0],
        [_ctaIconView.heightAnchor constraintEqualToConstant:14.0],
    ]];

    NSArray<NSNumber *> *dotX = @[@16.0, @53.0, @95.0, @140.0, @177.0];
    NSArray<NSNumber *> *dotY = @[@14.0, @61.0, @28.0, @90.0, @48.0];
    for (NSUInteger idx = 0; idx < _backgroundDotViews.count; idx++) {
        UIView *dotView = _backgroundDotViews[idx];
        CGFloat size = (idx % 2 == 0) ? 5.0 : 4.0;
        [NSLayoutConstraint activateConstraints:@[
            [dotView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:((NSNumber *)dotX[idx]).doubleValue],
            [dotView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:((NSNumber *)dotY[idx]).doubleValue],
            [dotView.widthAnchor constraintEqualToConstant:size],
            [dotView.heightAnchor constraintEqualToConstant:size],
        ]];
    }

    [self pp_applyTheme];
    return self;
}

- (UIView *)pp_makePetCareGlowViewWithRadius:(CGFloat)radius
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.clipsToBounds = NO;
    view.layer.cornerRadius = radius;
    view.layer.shadowRadius = 68.0;
    view.layer.shadowOpacity = 0.28;
    view.layer.shadowOffset = CGSizeZero;
    return view;
}

- (UILabel *)pp_makePillLabel
{
    PPHomeInsetLabel *label = [[PPHomeInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.82;
    label.contentInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    label.layer.cornerRadius = 15.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [label.heightAnchor constraintEqualToConstant:30.0].active = YES;
    [label.widthAnchor constraintGreaterThanOrEqualToConstant:92.0].active = YES;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    return label;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _gradientLayer.frame = _surfaceView.bounds;
    _gradientLayer.cornerRadius = _surfaceView.layer.cornerRadius;
    _topBackgroundGlowView.layer.cornerRadius = CGRectGetHeight(_topBackgroundGlowView.bounds) * 0.5;
    _middleBackgroundGlowView.layer.cornerRadius = CGRectGetHeight(_middleBackgroundGlowView.bounds) * 0.5;
    _bottomLeadingGlowView.layer.cornerRadius = CGRectGetHeight(_bottomLeadingGlowView.bounds) * 0.5;
    _largeOrbView.layer.cornerRadius = CGRectGetHeight(_largeOrbView.bounds) * 0.5;
    _smallOrbView.layer.cornerRadius = CGRectGetHeight(_smallOrbView.bounds) * 0.5;
    _iconPlateView.layer.cornerRadius = CGRectGetHeight(_iconPlateView.bounds) * 0.5;

    self.contentView.layer.shadowRadius = 24.0;
    self.contentView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:_surfaceView.bounds
                                   cornerRadius:_surfaceView.layer.cornerRadius].CGPath;

    _bottomLeadingGlowView.layer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:_bottomLeadingGlowView.bounds].CGPath;

    _middleBackgroundGlowView.layer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:_middleBackgroundGlowView.bounds].CGPath;

    _topBackgroundGlowView.layer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:_topBackgroundGlowView.bounds].CGPath;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self pp_stopBackgroundMotion];
    _careAnimationLoadToken += 1;
    [_careAnimationView stop];
    _careAnimationView.hidden = YES;
    _careAnimationView.alpha = 0.0;
    _iconImageView.hidden = NO;
    _currentCareAnimationName = nil;
    _eyebrowLabel.text = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _medicinePillLabel.text = nil;
    _vetPillLabel.text = nil;
    _ctaLabel.text = nil;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startBackgroundMotionIfNeeded];
    } else {
        [self pp_stopBackgroundMotion];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyTheme];
        }
    }
}

- (void)pp_applyTheme
{
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPPetCareAccentColor();
    UIColor *surfaceColor = PPPetCareSurfaceColor();
    UIColor *titleColor = PPPetCareTextColor();
    UIColor *secondaryColor = PPPetCareSecondaryTextColor();
    UIColor *borderColor = PPPetCareBorderColor();
    UIColor *glowHighlight = [UIColor colorWithWhite:1.0 alpha:isDark ? 0.03 : 0.4];
    UIColor *controlFillColor = [accent colorWithAlphaComponent:isDark ? 0.15 : 0.09];
    UIColor *controlBorderColor = borderColor;

    _surfaceView.backgroundColor = surfaceColor;
    [_surfaceView pp_setBorderColor:borderColor];
    self.contentView.layer.shadowOpacity = isDark ? 0.0 : 0.08;
    self.contentView.layer.shadowRadius = 24.0;
    self.contentView.layer.shadowOffset = CGSizeMake(0.0, 12.0);

    _gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _gradientLayer.endPoint = CGPointMake(1.0, 1.0);
    _gradientLayer.colors = @[
        (id)[AppPrimaryClrShiner colorWithAlphaComponent:isDark ? 0.20 : 0.16].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    _gradientLayer.locations = @[@0.0, @1.0];

    _topBackgroundGlowView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.14 : 0.06];
    [_topBackgroundGlowView pp_setShadowColor:[accent colorWithAlphaComponent:isDark ? 0.24 : 0.12]];
    _topBackgroundGlowView.layer.shadowOpacity = 0.16;
    _topBackgroundGlowView.layer.shadowRadius = 48.0;
    _topBackgroundGlowView.layer.shadowOffset = CGSizeZero;

    _middleBackgroundGlowView.backgroundColor = glowHighlight;
    [_middleBackgroundGlowView pp_setShadowColor:glowHighlight];
    _middleBackgroundGlowView.layer.shadowOpacity = 0.18;
    _middleBackgroundGlowView.layer.shadowRadius = 68.0;
    _middleBackgroundGlowView.layer.shadowOffset = CGSizeZero;
    _middleBackgroundGlowView.alpha=0.4;
    _bottomLeadingGlowView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.10 : 0.12];
    [_bottomLeadingGlowView pp_setShadowColor:[accent colorWithAlphaComponent:isDark ? 0.16 : 0.18]];
    _bottomLeadingGlowView.layer.shadowOpacity = 0.28;
    _bottomLeadingGlowView.layer.shadowRadius = 68.0;
    _bottomLeadingGlowView.layer.shadowOffset = CGSizeZero;

    _largeOrbView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.12 : 0.08];
    _smallOrbView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.0 : 0.0];

    _iconPlateView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.18 : 0.11];
    [_iconPlateView pp_setBorderColor:[accent colorWithAlphaComponent:isDark ? 0.24 : 0.16]];
    _iconImageView.tintColor = accent;
    _eyebrowLabel.textColor = [accent colorWithAlphaComponent:isDark ? 0.92 : 0.82];
    _titleLabel.textColor = titleColor;
    _subtitleLabel.textColor = secondaryColor;
    _ctaView.backgroundColor = controlFillColor;
    [_ctaView pp_setBorderColor:controlBorderColor];
    _ctaLabel.textColor = titleColor;
    _ctaIconView.tintColor = titleColor;

    for (UILabel *pill in @[_medicinePillLabel, _vetPillLabel]) {
        pill.textColor = titleColor;
        pill.backgroundColor = controlFillColor;
        [pill pp_setBorderColor:controlBorderColor];
    }

    [_backgroundDotViews enumerateObjectsUsingBlock:^(UIView * _Nonnull dotView, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        dotView.backgroundColor = (idx % 2 == 0) ? accent : UIColor.whiteColor;
        dotView.alpha = isDark ? 0.20 : 0.16;
        dotView.layer.cornerRadius = CGRectGetWidth(dotView.bounds) > 0.0
            ? CGRectGetWidth(dotView.bounds) * 0.5
            : ((idx % 2 == 0) ? 2.5 : 2.0);
    }];

    if (!CGAffineTransformEqualToTransform(_topBackgroundGlowView.transform, CGAffineTransformIdentity) ||
        !CGAffineTransformEqualToTransform(_middleBackgroundGlowView.transform, CGAffineTransformIdentity) ||
        !CGAffineTransformEqualToTransform(_bottomLeadingGlowView.transform, CGAffineTransformIdentity)) {
        [self pp_startBackgroundMotionIfNeeded];
    }
}

- (void)pp_addPetCareGlowTranslationToView:(UIView *)view
                                       key:(NSString *)key
                                         x:(CGFloat)x
                                         y:(CGFloat)y
                                  duration:(NSTimeInterval)duration
{
    if (!view || key.length == 0 || [view.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *xAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    xAnimation.fromValue = @0.0;
    xAnimation.toValue = @(x);

    CABasicAnimation *yAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    yAnimation.fromValue = @0.0;
    yAnimation.toValue = @(y);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[xAnimation, yAnimation];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_startBackgroundMotionIfNeeded
{
    if (!self.window) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopBackgroundMotion];
        return;
    }

    [self pp_addPetCareGlowTranslationToView:_topBackgroundGlowView
                                         key:@"pp.home.premiumCare.petCareGlowTop"
                                           x:-16.0
                                           y:12.0
                                    duration:6.0];
    [self pp_addPetCareGlowTranslationToView:_middleBackgroundGlowView
                                         key:@"pp.home.premiumCare.petCareGlowMiddle"
                                           x:12.0
                                           y:-10.0
                                    duration:6.0];
    [self pp_addPetCareGlowTranslationToView:_bottomLeadingGlowView
                                         key:@"pp.home.premiumCare.petCareGlowBottom"
                                           x:18.0
                                           y:-14.0
                                    duration:7.4];

    [_backgroundDotViews enumerateObjectsUsingBlock:^(UIView * _Nonnull dotView, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        NSString *animationKey =
            [NSString stringWithFormat:@"pp.home.premiumCare.backgroundDot.%lu", (unsigned long)idx];
        if ([dotView.layer animationForKey:animationKey]) {
            return;
        }
        CABasicAnimation *scaleAnimation =
            [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scaleAnimation.fromValue = @0.76;
        scaleAnimation.toValue = @1.34;

        CABasicAnimation *opacityAnimation =
            [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacityAnimation.fromValue = @(dotView.alpha * 0.45);
        opacityAnimation.toValue = @(MIN(dotView.alpha + 0.20, 0.42));

        CABasicAnimation *floatAnimation =
            [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.fromValue = @0.0;
        floatAnimation.toValue = @(-3.0 - ((double)(idx % 2) * 1.5));

        CAAnimationGroup *dotAnimation = [CAAnimationGroup animation];
        dotAnimation.animations = @[scaleAnimation, opacityAnimation, floatAnimation];
        dotAnimation.duration = 2.6 + ((double)idx * 0.35);
        dotAnimation.autoreverses = YES;
        dotAnimation.repeatCount = HUGE_VALF;
        dotAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [dotView.layer addAnimation:dotAnimation forKey:animationKey];
    }];
}

- (void)pp_stopBackgroundMotion
{
    [_topBackgroundGlowView.layer removeAnimationForKey:@"pp.home.premiumCare.petCareGlowTop"];
    [_middleBackgroundGlowView.layer removeAnimationForKey:@"pp.home.premiumCare.petCareGlowMiddle"];
    [_bottomLeadingGlowView.layer removeAnimationForKey:@"pp.home.premiumCare.petCareGlowBottom"];
    [_backgroundDotViews enumerateObjectsUsingBlock:^(UIView * _Nonnull dotView, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        NSString *animationKey =
            [NSString stringWithFormat:@"pp.home.premiumCare.backgroundDot.%lu", (unsigned long)idx];
        [dotView.layer removeAnimationForKey:animationKey];
        dotView.transform = CGAffineTransformIdentity;
    }];

    _topBackgroundGlowView.alpha = 1.0;
    _topBackgroundGlowView.transform = CGAffineTransformIdentity;
    _middleBackgroundGlowView.alpha = 1.0;
    _middleBackgroundGlowView.transform = CGAffineTransformIdentity;
    _bottomLeadingGlowView.alpha = 1.0;
    _bottomLeadingGlowView.transform = CGAffineTransformIdentity;
}

- (void)configure
{
    [self configureWithAnimationName:PPHomePremiumCareMedicineAnimationName];
}

- (void)configureWithAnimationName:(NSString *)animationName
{
    (void)animationName;
    [self pp_applyTheme];
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _surfaceView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _ctaLabel.textAlignment = Language.alignmentForCurrentLanguage;

    _eyebrowLabel.text = kLang(@"home_premium_care_eyebrow") ?: @"Premium care";
    _titleLabel.text = kLang(@"home_premium_care_title") ?: @"Medicines and vets";
    _subtitleLabel.text = kLang(@"home_premium_care_subtitle") ?: @"Pet medicine and veterinarian care in one refined place.";
    _medicinePillLabel.text = kLang(@"pet_care_medicines") ?: @"Medicines";
    _vetPillLabel.text = kLang(@"pet_care_veterinarians") ?: @"Veterinarians";
    _ctaLabel.text = kLang(@"home_premium_care_cta") ?: @"Open care center";

    NSString *forwardSymbol = Language.isRTL ? @"arrow.left" : @"arrow.right";
    _ctaIconView.image = [[UIImage systemImageNamed:forwardSymbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _iconImageView.image = [[UIImage systemImageNamed:@"pills.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self pp_configureCareAnimationNamed:PPHomePremiumCareMedicineAnimationName];
    [self pp_startBackgroundMotionIfNeeded];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@",
                               _titleLabel.text ?: @"",
                               _subtitleLabel.text ?: @""];
}

- (void)pp_configureCareAnimationNamed:(NSString *)animationName
{
    (void)animationName;
    NSString *safeName = PPHomePremiumCareMedicineAnimationName;

    if ([_currentCareAnimationName isEqualToString:safeName]) {
        BOOL needsReveal = _careAnimationView.hidden
            || _careAnimationView.alpha < 0.99
            || _iconImageView.hidden == NO
            || _iconImageView.alpha > 0.01
            || !CGAffineTransformEqualToTransform(_careAnimationView.transform, CGAffineTransformIdentity);
        if (needsReveal && _careAnimationView.sceneModel) {
            [self pp_revealConfiguredCareAnimation];
            return;
        }
        if (!_careAnimationView.hidden && !_careAnimationView.isAnimationPlaying) {
            [_careAnimationView play];
        }
        return;
    }

    _currentCareAnimationName = safeName;
    _careAnimationLoadToken += 1;
    NSInteger token = _careAnimationLoadToken;
    _didRevealCurrentCareAnimation = NO;

    [_careAnimationView stop];
    _careAnimationView.hidden = YES;
    _careAnimationView.alpha = 0.0;
    _careAnimationView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    _iconImageView.hidden = NO;
    _iconImageView.alpha = 1.0;
    _iconImageView.transform = CGAffineTransformIdentity;

    __weak typeof(self) weakSelf = self;
    [AppClasses setAnimationNamed:safeName
                            ToView:_careAnimationView
                         withSpeed:0.84
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_careAnimationLoadToken != token) {
                return;
            }

            if (!success) {
                strongSelf->_careAnimationView.hidden = YES;
                strongSelf->_iconImageView.hidden = NO;
                return;
            }

            [strongSelf pp_revealConfiguredCareAnimation];
        });
    }];
}

- (void)pp_revealConfiguredCareAnimation
{
    BOOL isAlreadyRevealed =
        _didRevealCurrentCareAnimation
        && !_careAnimationView.hidden
        && _careAnimationView.alpha >= 0.99
        && CGAffineTransformEqualToTransform(_careAnimationView.transform, CGAffineTransformIdentity);
    if (isAlreadyRevealed) {
        if (!_careAnimationView.isAnimationPlaying) {
            [_careAnimationView play];
        }
        _iconImageView.hidden = YES;
        _iconImageView.alpha = 0.0;
        _iconImageView.transform = CGAffineTransformIdentity;
        return;
    }

    _didRevealCurrentCareAnimation = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _careAnimationView.hidden = NO;
        _careAnimationView.alpha = 1.0;
        _careAnimationView.transform = CGAffineTransformIdentity;
        _iconImageView.hidden = YES;
        _iconImageView.alpha = 0.0;
        _iconImageView.transform = CGAffineTransformIdentity;
        if (!_careAnimationView.isAnimationPlaying) {
            [_careAnimationView play];
        }
        return;
    }

    _careAnimationView.loopAnimation = YES;
    _careAnimationView.hidden = NO;
    [_careAnimationView setNeedsLayout];
    [_careAnimationView layoutIfNeeded];
    [_careAnimationView play];

    _careAnimationView.alpha = 0.0;
    _careAnimationView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    _iconImageView.hidden = NO;
    _iconImageView.alpha = 1.0;
    _iconImageView.transform = CGAffineTransformMakeScale(0.90, 0.90);

    [UIView animateWithDuration:0.26
                          delay:0.08
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self->_careAnimationView.alpha = 1.0;
        self->_careAnimationView.transform = CGAffineTransformIdentity;
        self->_iconImageView.alpha = 0.0;
        self->_iconImageView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        self->_iconImageView.hidden = YES;
        self->_iconImageView.transform = CGAffineTransformIdentity;
    }];
}

@end
