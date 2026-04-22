//
//  PPHomeLocationSheetViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/11/26.
//

#import "PPHomeLocationSheetViewController.h"


@implementation PPHomeLocationActionCard {
    UIView *_surfaceView;
    UIView *_accentBarView;
    UIView *_accentGlowView;
    UIView *_iconChipView;
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_chevronView;
    UIColor *_currentTintColor;
    BOOL _showsChevron;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.layer.shadowOpacity = 0.14f;
    self.layer.shadowRadius = 18.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [self pp_setShadowColor:[UIColor colorWithWhite:0.03 alpha:1.0]];

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.userInteractionEnabled = NO;
    _surfaceView.layer.cornerRadius = 24.0;
    _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _surfaceView.layer.borderWidth = 1.0;
    _surfaceView.clipsToBounds = YES;
    [self addSubview:_surfaceView];

    _accentGlowView = [[UIView alloc] init];
    _accentGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    _accentGlowView.userInteractionEnabled = NO;
    _accentGlowView.alpha = 0.20;
    _accentGlowView.layer.cornerRadius = 34.0;
    _accentGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    [_surfaceView addSubview:_accentGlowView];

    _accentBarView = [[UIView alloc] init];
    _accentBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _accentBarView.userInteractionEnabled = NO;
    _accentBarView.layer.cornerRadius = 1.5;
    _accentBarView.layer.cornerCurve = kCACornerCurveContinuous;
    [_surfaceView addSubview:_accentBarView];

    _iconChipView = [[UIView alloc] init];
    _iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconChipView.userInteractionEnabled = NO;
    _iconChipView.layer.cornerRadius = 20.0;
    _iconChipView.layer.cornerCurve = kCACornerCurveContinuous;
    [_surfaceView addSubview:_iconChipView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconChipView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_surfaceView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.64] ?: UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [_surfaceView addSubview:_subtitleLabel];

    UIImage *chevronImage =
        [UIImage pp_symbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                      pointSize:12
                         weight:UIImageSymbolWeightBold
                          scale:UIImageSymbolScaleSmall
                        palette:@[[AppPrimaryTextClr colorWithAlphaComponent:0.46] ?: UIColor.secondaryLabelColor]
                   makeTemplate:YES];
    _chevronView = [[UIImageView alloc] initWithImage:chevronImage];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [_surfaceView addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_accentGlowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:22.0],
        [_accentGlowView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_accentGlowView.widthAnchor constraintEqualToConstant:108.0],
        [_accentGlowView.heightAnchor constraintEqualToConstant:68.0],

        [_accentBarView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:14.0],
        [_accentBarView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_accentBarView.widthAnchor constraintEqualToConstant:3.0],
        [_accentBarView.heightAnchor constraintEqualToConstant:28.0],

        [_iconChipView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:24.0],
        [_iconChipView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_iconChipView.widthAnchor constraintEqualToConstant:40.0],
        [_iconChipView.heightAnchor constraintEqualToConstant:40.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconChipView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconChipView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:18.0],
        [_iconView.heightAnchor constraintEqualToConstant:18.0],

        [_chevronView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-22.0],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:12.0],
        [_chevronView.heightAnchor constraintEqualToConstant:12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconChipView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:17.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_surfaceView.bottomAnchor constant:-17.0],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:78.0]
    ]];

    [self addTarget:self action:@selector(pp_touchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchCancel];

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_surfaceView.layer.cornerRadius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyVisualState];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
                  iconName:(nullable NSString *)iconName
                 tintColor:(UIColor *)tintColor
               showsChevron:(BOOL)showsChevron
{
    UIColor *resolvedTint = tintColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    _currentTintColor = resolvedTint;
    _showsChevron = showsChevron;
    _titleLabel.text = PPSafeString(title);
    _subtitleLabel.text = PPSafeString(subtitle);
    _subtitleLabel.hidden = (PPSafeString(subtitle).length == 0);
    _chevronView.hidden = !showsChevron;
    _iconView.image =
        [UIImage pp_symbolNamed:PPSafeString(iconName)
                      pointSize:17
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[resolvedTint]
                   makeTemplate:YES];
    [self pp_applyVisualState];
}

- (void)pp_applyVisualState
{
    UIColor *resolvedTint = _currentTintColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *surfaceColor = isDark
        ? [UIColor colorWithRed:0.11 green:0.10 blue:0.14 alpha:0.96]
        : [UIColor colorWithRed:0.99 green:0.985 blue:0.975 alpha:0.97];
    UIColor *borderColor = isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.07]
        : [UIColor colorWithRed:0.83 green:0.80 blue:0.78 alpha:0.36];
    UIColor *titleColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.96] : [UIColor colorWithRed:0.11 green:0.10 blue:0.12 alpha:1.0];
    UIColor *subtitleColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.60] : [UIColor colorWithRed:0.28 green:0.27 blue:0.31 alpha:0.72];
    UIColor *iconPlateColor = isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.06]
        : [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.72];

    _surfaceView.backgroundColor = surfaceColor;
    [_surfaceView pp_setBorderColor:borderColor];
    _accentBarView.backgroundColor = resolvedTint;
    _accentGlowView.backgroundColor = [resolvedTint colorWithAlphaComponent:isDark ? 0.16 : 0.11];
    _iconChipView.backgroundColor = iconPlateColor;
    _iconChipView.layer.borderWidth = 1.0;
    [_iconChipView pp_setBorderColor:[resolvedTint colorWithAlphaComponent:isDark ? 0.16 : 0.10]];
    _titleLabel.textColor = titleColor;
    _subtitleLabel.textColor = subtitleColor;
    _iconView.tintColor = resolvedTint;
    _chevronView.tintColor = [titleColor colorWithAlphaComponent:_showsChevron ? 0.56 : 0.0];
}

- (void)pp_touchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.transform = CGAffineTransformMakeScale(0.98, 0.98);
        self.alpha = 0.97;
    } completion:nil];
}

- (void)pp_touchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.80
          initialSpringVelocity:0.30
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end





@implementation PPHomeLocationSheetViewController {
    UIView *_backdropView;
    CAGradientLayer *_backdropGradientLayer;
    UIView *_heroEyebrowView;
    UIScrollView *_scrollView;
    UIStackView *_contentStack;
    UIStackView *_recentStack;
    PPHomeLocationActionCard *_currentCard;
    PPHomeLocationActionCard *_useCurrentCard;
    PPHomeLocationActionCard *_changeAreaCard;
    PPHomeLocationActionCard *_settingsCard;
    UILabel *_recentTitleLabel;
    UIView *_heroSurfaceView;
    UIButton *_backButton;
    BOOL _didAnimateEntrance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_buildUI];
    [self pp_applyAppearance];
    [self pp_applySheetConfigurationIfNeeded];
    [self pp_reloadContent];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    _didAnimateEntrance = YES;
    NSArray<UIView *> *arrangedViews = _contentStack.arrangedSubviews ?: @[];
    [_recentStack.arrangedSubviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
    }];

    NSInteger index = 0;
    for (UIView *view in arrangedViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
        [UIView animateWithDuration:0.34
                              delay:0.03 * index
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
        index += 1;
    }
    
    
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _backdropGradientLayer.frame = _backdropView.bounds;
    _backdropGradientLayer.cornerRadius = _backdropView.layer.cornerRadius;
    _backButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_backButton.bounds cornerRadius:_backButton.layer.cornerRadius].CGPath;
    _heroSurfaceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_heroSurfaceView.bounds cornerRadius:_heroSurfaceView.layer.cornerRadius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyAppearance];
    [self pp_reloadContent];
}

- (void)pp_buildUI
{
    _backdropView = [[UIView alloc] init];
    _backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    _backdropView.backgroundColor = UIColor.clearColor;
    _backdropView.layer.cornerRadius = PPIOS26() ? 34.0 : 28.0;
    _backdropView.layer.cornerCurve = kCACornerCurveContinuous;
    _backdropView.clipsToBounds = YES;
    [self.view addSubview:_backdropView];

    _backdropGradientLayer = [CAGradientLayer layer];
    _backdropGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _backdropGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    _backdropGradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.99 green:0.985 blue:0.975 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.965 green:0.95 blue:0.935 alpha:1.0].CGColor
    ];
    [_backdropView.layer insertSublayer:_backdropGradientLayer atIndex:0];

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.backgroundColor = UIColor.clearColor;
    [_backdropView addSubview:_scrollView];

    UIImage *backIcon = [UIImage pp_symbolNamed:(Language.isRTL ? @"chevron.right" : @"chevron.left")
                                      pointSize:16
                                         weight:UIImageSymbolWeightSemibold
                                          scale:UIImageSymbolScaleMedium
                                        palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                   makeTemplate:YES];
    _backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_backButton setImage:backIcon forState:UIControlStateNormal];
    _backButton.tintColor = [UIColor colorWithRed:0.16 green:0.14 blue:0.18 alpha:1.0];
    _backButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    _backButton.layer.cornerRadius = 18.0;
    _backButton.layer.cornerCurve = kCACornerCurveContinuous;
    _backButton.layer.borderWidth = 1.0;
    [_backButton pp_setBorderColor:[UIColor colorWithRed:0.73 green:0.68 blue:0.70 alpha:0.28]];
    [_backButton pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _backButton.layer.shadowOpacity = 0.10f;
    _backButton.layer.shadowRadius = 16.0f;
    _backButton.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [_backButton addTarget:self action:@selector(pp_handleBack) forControlEvents:UIControlEventTouchUpInside];
    [_backdropView addSubview:_backButton];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    [_scrollView addSubview:contentView];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 16.0;
    _contentStack.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_contentStack];

    _heroSurfaceView = [[UIView alloc] init];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSurfaceView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    _heroSurfaceView.layer.cornerRadius = 30.0;
    _heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _heroSurfaceView.layer.borderWidth = 1.0;
    [_heroSurfaceView pp_setBorderColor:[UIColor colorWithRed:0.81 green:0.77 blue:0.78 alpha:0.34]];
    [_heroSurfaceView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _heroSurfaceView.layer.shadowOpacity = 0.10f;
    _heroSurfaceView.layer.shadowRadius = 24.0f;
    _heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);

    _heroEyebrowView = [[UIView alloc] init];
    _heroEyebrowView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroEyebrowView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    _heroEyebrowView.layer.cornerRadius = 13.0;
    _heroEyebrowView.layer.cornerCurve = kCACornerCurveContinuous;
    _heroEyebrowView.layer.borderWidth = 1.0;
    [_heroEyebrowView pp_setBorderColor:[UIColor colorWithRed:0.82 green:0.76 blue:0.78 alpha:0.26]];
    [_heroSurfaceView addSubview:_heroEyebrowView];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrowLabel.textColor = [UIColor colorWithRed:0.50 green:0.34 blue:0.39 alpha:1.0];
    eyebrowLabel.text = kLang(@"Nearby") ?: @"Nearby";
    eyebrowLabel.tag = 603;
    [_heroEyebrowView addSubview:eyebrowLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:26] ?: [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.textColor = [UIColor colorWithRed:0.10 green:0.09 blue:0.12 alpha:1.0];
    titleLabel.numberOfLines = 2;
    titleLabel.tag = 601;
    [_heroSurfaceView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.textColor = [UIColor colorWithRed:0.31 green:0.28 blue:0.32 alpha:0.78];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.tag = 602;
    [_heroSurfaceView addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_heroEyebrowView.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:18.0],
        [_heroEyebrowView.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18.0],
        [_heroEyebrowView.heightAnchor constraintEqualToConstant:26.0],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroEyebrowView.leadingAnchor constant:10.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:_heroEyebrowView.trailingAnchor constant:-10.0],
        [eyebrowLabel.centerYAnchor constraintEqualToAnchor:_heroEyebrowView.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:_heroEyebrowView.bottomAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-18.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-20.0]
    ]];

    _currentCard = [[PPHomeLocationActionCard alloc] init];
    _useCurrentCard = [[PPHomeLocationActionCard alloc] init];
    _changeAreaCard = [[PPHomeLocationActionCard alloc] init];
    _settingsCard = [[PPHomeLocationActionCard alloc] init];
    [_useCurrentCard addTarget:self action:@selector(pp_handleUseCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    [_changeAreaCard addTarget:self action:@selector(pp_handleChangeArea) forControlEvents:UIControlEventTouchUpInside];
    [_settingsCard addTarget:self action:@selector(pp_handleOpenSettings) forControlEvents:UIControlEventTouchUpInside];

    _recentTitleLabel = [[UILabel alloc] init];
    _recentTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _recentTitleLabel.font = [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _recentTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _recentTitleLabel.textColor = [UIColor colorWithRed:0.49 green:0.43 blue:0.46 alpha:1.0];

    _recentStack = [[UIStackView alloc] init];
    _recentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _recentStack.axis = UILayoutConstraintAxisVertical;
    _recentStack.spacing = 12.0;
    _recentStack.alignment = UIStackViewAlignmentFill;

    [_contentStack addArrangedSubview:_heroSurfaceView];
    [_contentStack addArrangedSubview:_currentCard];
    [_contentStack addArrangedSubview:_useCurrentCard];
    [_contentStack addArrangedSubview:_changeAreaCard];
    [_contentStack addArrangedSubview:_settingsCard];
    [_contentStack addArrangedSubview:_recentTitleLabel];
    [_contentStack addArrangedSubview:_recentStack];

    [NSLayoutConstraint activateConstraints:@[
        [_backdropView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_backdropView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_backdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_backdropView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_backButton.topAnchor constraintEqualToAnchor:_backdropView.topAnchor constant:14.0],
        [_backButton.leadingAnchor constraintEqualToAnchor:_backdropView.leadingAnchor constant:16.0],
        [_backButton.widthAnchor constraintEqualToConstant:36.0],
        [_backButton.heightAnchor constraintEqualToConstant:36.0],

        [_scrollView.topAnchor constraintEqualToAnchor:_backButton.bottomAnchor constant:8.0],
        [_scrollView.leadingAnchor constraintEqualToAnchor:_backdropView.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:_backdropView.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:_backdropView.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor],

        [_contentStack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:18.0],
        [_contentStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [_contentStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],
        [_contentStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-28.0]
    ]];

    _backdropGradientLayer.frame = self.view.bounds;
    _backdropGradientLayer.cornerRadius = _backdropView.layer.cornerRadius;
}

- (void)pp_applySheetConfigurationIfNeeded
{
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (!sheet) {
            return;
        }
        sheet.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent
        ];
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        sheet.prefersGrabberVisible = YES;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        sheet.preferredCornerRadius = PPIOS26() ? 34.0 : 28.0;
        if (@available(iOS 16.0, *)) {
            sheet.prefersEdgeAttachedInCompactHeight = YES;
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
        }
    }
}

- (void)pp_applyAppearance
{
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *topColor = isDark
        ? [UIColor colorWithRed:0.10 green:0.09 blue:0.12 alpha:1.0]
        : [UIColor colorWithRed:0.99 green:0.985 blue:0.975 alpha:1.0];
    UIColor *bottomColor = isDark
        ? [UIColor colorWithRed:0.14 green:0.12 blue:0.16 alpha:1.0]
        : [UIColor colorWithRed:0.965 green:0.95 blue:0.935 alpha:1.0];
    _backdropGradientLayer.colors = @[(id)topColor.CGColor, (id)bottomColor.CGColor];

    _backButton.tintColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.92] : [UIColor colorWithRed:0.16 green:0.14 blue:0.18 alpha:1.0];
    _backButton.backgroundColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.70];
    [_backButton pp_setBorderColor:isDark ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithRed:0.73 green:0.68 blue:0.70 alpha:0.28]];

    _heroSurfaceView.backgroundColor = isDark
        ? [UIColor colorWithRed:0.15 green:0.13 blue:0.17 alpha:0.94]
        : [UIColor colorWithWhite:1.0 alpha:0.58];
    [_heroSurfaceView pp_setBorderColor:isDark ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithRed:0.81 green:0.77 blue:0.78 alpha:0.34]];

    _heroEyebrowView.backgroundColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.72];
    [_heroEyebrowView pp_setBorderColor:isDark ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithRed:0.82 green:0.76 blue:0.78 alpha:0.26]];

    UILabel *eyebrowLabel = [_heroSurfaceView viewWithTag:603];
    eyebrowLabel.textColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.62] : [UIColor colorWithRed:0.50 green:0.34 blue:0.39 alpha:1.0];

    UILabel *titleLabel = [_heroSurfaceView viewWithTag:601];
    UILabel *subtitleLabel = [_heroSurfaceView viewWithTag:602];
    titleLabel.textColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.95] : [UIColor colorWithRed:0.10 green:0.09 blue:0.12 alpha:1.0];
    subtitleLabel.textColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.64] : [UIColor colorWithRed:0.31 green:0.28 blue:0.32 alpha:0.78];
    _recentTitleLabel.textColor = isDark ? [UIColor colorWithWhite:1.0 alpha:0.55] : [UIColor colorWithRed:0.49 green:0.43 blue:0.46 alpha:1.0];
}

- (void)pp_reloadContent
{
    UILabel *titleLabel = [_heroSurfaceView viewWithTag:601];
    UILabel *subtitleLabel = [_heroSurfaceView viewWithTag:602];
    titleLabel.text = PPSafeString(self.sheetTitleText);
    subtitleLabel.text = PPSafeString(self.sheetSubtitleText);

    [_currentCard configureWithTitle:(self.currentLocationTitle.length > 0 ? self.currentLocationTitle : (kLang(@"Select your location") ?: @"Select your location"))
                            subtitle:PPSafeString(self.currentLocationSubtitle)
                            iconName:@"location.fill"
                           tintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                         showsChevron:NO];

    [_useCurrentCard configureWithTitle:(kLang(@"home_location_sheet_use_current") ?: @"Use current location")
                               subtitle:(kLang(@"home_location_sheet_use_current_subtitle") ?: @"Refresh nearby pets and services using GPS")
                               iconName:@"location.north.fill"
                              tintColor:UIColor.systemBlueColor
                            showsChevron:YES];

    [_changeAreaCard configureWithTitle:(kLang(@"home_location_sheet_change_area") ?: @"Change area")
                               subtitle:(kLang(@"home_location_sheet_change_area_subtitle") ?: @"Pick another city or neighborhood")
                               iconName:@"map.fill"
                              tintColor:UIColor.systemOrangeColor
                            showsChevron:YES];

    [_settingsCard configureWithTitle:(kLang(@"Open Settings") ?: @"Open Settings")
                             subtitle:(kLang(@"home_location_sheet_open_settings_subtitle") ?: @"Allow location access to keep nearby results accurate")
                             iconName:@"gearshape.fill"
                            tintColor:UIColor.systemIndigoColor
                          showsChevron:YES];
    _useCurrentCard.hidden = !self.showsUseCurrentLocationAction;
    _settingsCard.hidden = !self.showsOpenSettingsAction;

    _recentTitleLabel.text = kLang(@"home_location_sheet_recent_title") ?: @"Recent locations";
    _recentTitleLabel.hidden = (self.recentLocations.count == 0);

    for (UIView *subview in _recentStack.arrangedSubviews.copy) {
        [_recentStack removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }

    NSInteger index = 0;
    for (NSDictionary *record in self.recentLocations ?: @[]) {
        PPHomeLocationActionCard *card = [[PPHomeLocationActionCard alloc] init];
        card.tag = index;
        NSString *title = PPSafeString(record[@"title"]);
        NSString *subtitle = PPSafeString(record[@"subtitle"]);
        if (subtitle.length == 0) {
            subtitle = kLang(@"home_location_sheet_recent_subtitle") ?: @"Tap to reuse this location";
        }
        [card configureWithTitle:title
                        subtitle:subtitle
                        iconName:@"clock.arrow.circlepath"
                       tintColor:[UIColor colorWithRed:0.18 green:0.61 blue:0.58 alpha:1.0]
                     showsChevron:YES];
        [card addTarget:self action:@selector(pp_handleRecentLocationTap:) forControlEvents:UIControlEventTouchUpInside];
        [_recentStack addArrangedSubview:card];
        index += 1;
    }
    _recentStack.hidden = (self.recentLocations.count == 0);
}

- (void)pp_handleUseCurrentLocation
{
    [self pp_dismissThenRun:self.onUseCurrentLocation];
}

- (void)pp_handleChangeArea
{
    [self pp_dismissThenRun:self.onChangeArea];
}

- (void)pp_handleOpenSettings
{
    [self pp_dismissThenRun:self.onOpenSettings];
}

- (void)pp_handleRecentLocationTap:(PPHomeLocationActionCard *)sender
{
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.recentLocations.count) {
        return;
    }

    NSDictionary *record = self.recentLocations[(NSUInteger)index];
    void (^selectBlock)(void) = ^{
        if (self.onSelectRecentLocation) {
            self.onSelectRecentLocation(record);
        }
    };
    [self pp_dismissThenRun:selectBlock];
}

- (void)pp_handleBack
{
    [self pp_dismissThenRun:nil];
}

- (void)pp_dismissThenRun:(dispatch_block_t)block
{
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:block];
    } else if (block) {
        block();
    }
}

@end
