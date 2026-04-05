//
//  PPHomeServicesCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/12/2025.
//


#import "PPHomeServicesCell.h"

static inline UIColor *PPHomeServiceRGBA(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [UIColor colorWithRed:red / 255.0
                           green:green / 255.0
                            blue:blue / 255.0
                           alpha:alpha];
}

@interface PPHomeServicesCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *accentGlowView;
@property (nonatomic, strong) UIImageView *watermarkView;
@property (nonatomic, strong) UIView *iconChipView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *chevronPillView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *compactConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *featuredConstraints;

@property (nonatomic, strong, nullable) PPHomeServiceItem *currentService;
@property (nonatomic, assign) BOOL usesCompactLayout;

@end

@implementation PPHomeServicesCell

+ (NSString *)reuseIdentifier {
    return @"PPHomeServicesCell";
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
    }
    return self;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _cardView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = UIColor.clearColor;
    _cardView.adjustsImageWhenHighlighted = NO;
    _cardView.clipsToBounds = NO;
    _cardView.layer.masksToBounds = NO;
    _cardView.layer.cornerRadius = PPCornerMedium;
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    _cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    _cardView.layer.shadowOpacity = 0.06;
    _cardView.layer.shadowRadius = 12.0;
    
    UIButtonConfiguration *config = _cardView.configuration;
    config.background.cornerRadius = PPCornerMedium;
    _cardView .configuration = config;
    
    
    _cardView.layer.shadowOffset = CGSizeMake(0, 8.0);
    [self.contentView addSubview:_cardView];

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.userInteractionEnabled = NO;
    _surfaceView.layer.cornerRadius = PPCornerMedium;
    _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _surfaceView.layer.masksToBounds = YES;
    [_cardView addSubview:_surfaceView];

    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _gradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_surfaceView.layer insertSublayer:_gradientLayer atIndex:0];

    _accentGlowView = [[UIView alloc] init];
    _accentGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    _accentGlowView.userInteractionEnabled = NO;
    _accentGlowView.alpha = 0.18;
    _accentGlowView.layer.cornerRadius = 56.0;
    [_surfaceView addSubview:_accentGlowView];

    _watermarkView = [[UIImageView alloc] init];
    _watermarkView.translatesAutoresizingMaskIntoConstraints = NO;
    _watermarkView.userInteractionEnabled = NO;
    _watermarkView.contentMode = UIViewContentModeScaleAspectFit;
    _watermarkView.alpha = 0.08;
    [_surfaceView addSubview:_watermarkView];

    _iconChipView = [[UIView alloc] init];
    _iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconChipView.userInteractionEnabled = NO;
    _iconChipView.layer.cornerRadius = PPCornerMedium;
    _iconChipView.layer.cornerCurve = kCACornerCurveContinuous;
    _iconChipView.hidden=NO;
    [_surfaceView addSubview:_iconChipView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.hidden = YES;
    [_iconChipView addSubview:_iconView];

    _eyebrowLabel = [[UILabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.font = [GM MidFontWithSize:PPFontCaption1];
    _eyebrowLabel.text = [kLang(@"services") uppercaseString];
    _eyebrowLabel.hidden = YES;
    [_surfaceView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:PPFontHeadline];
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_surfaceView addSubview:_titleLabel];

    _chevronPillView = [[UIView alloc] init];
    _chevronPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronPillView.userInteractionEnabled = NO;
    _chevronPillView.layer.cornerRadius = 15.0;
    _chevronPillView.layer.cornerCurve = kCACornerCurveContinuous;
    [_surfaceView addSubview:_chevronPillView];

    _chevronView = [[UIImageView alloc] init];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [_chevronPillView addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_surfaceView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor],

        [_accentGlowView.widthAnchor constraintEqualToConstant:124.0],
        [_accentGlowView.heightAnchor constraintEqualToConstant:124.0],
        [_accentGlowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:-40.0],
        [_accentGlowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:34.0],

        [_watermarkView.centerXAnchor constraintEqualToAnchor:_surfaceView.centerXAnchor constant:-0.0],
        [_watermarkView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor constant:-0.0],
        [_watermarkView.widthAnchor constraintEqualToConstant:44.0],
        [_watermarkView.heightAnchor constraintEqualToConstant:44.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconChipView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconChipView.centerYAnchor],
        [_iconView.widthAnchor constraintLessThanOrEqualToAnchor:_iconChipView.widthAnchor multiplier:0.58],
        [_iconView.heightAnchor constraintLessThanOrEqualToAnchor:_iconChipView.heightAnchor multiplier:0.58],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:18.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_surfaceView.trailingAnchor constant:-18.0],

        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_surfaceView.trailingAnchor constant:-18.0],

        [_chevronPillView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [_chevronView.centerXAnchor constraintEqualToAnchor:_chevronPillView.centerXAnchor],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_chevronPillView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:16.0],
        [_chevronView.heightAnchor constraintEqualToConstant:16.0],
    ]];

    self.compactConstraints = @[
        [_iconChipView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:4.0],
        [_iconChipView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:12.0],
        [_iconChipView.widthAnchor constraintEqualToConstant:32.0],
        [_iconChipView.heightAnchor constraintEqualToConstant:32.0],

        [_chevronPillView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:12.0],
        [_chevronPillView.widthAnchor constraintEqualToConstant:28.0],
        [_chevronPillView.heightAnchor constraintEqualToConstant:28.0],
        
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:12.0],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_chevronPillView.centerYAnchor constant:0.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronPillView.leadingAnchor constant:-10.0],

        
    ];

    self.featuredConstraints = @[
        [_iconChipView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:18.0],
        [_iconChipView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:18.0],
        [_iconChipView.widthAnchor constraintEqualToConstant:52.0],
        [_iconChipView.heightAnchor constraintEqualToConstant:52.0],

        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_iconChipView.bottomAnchor constant:14.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:8.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:18.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_surfaceView.trailingAnchor constant:-86.0],
        [_titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_surfaceView.bottomAnchor constant:-18.0],

        [_chevronPillView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-18.0],
        [_chevronPillView.widthAnchor constraintEqualToConstant:28.0],
        [_chevronPillView.heightAnchor constraintEqualToConstant:28.0],
    ];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    [self updateLayoutModeIfNeeded];
    self.gradientLayer.frame = self.surfaceView.bounds;
    self.cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self applyAppearanceForCurrentService];
        }
    } else {
        [self applyAppearanceForCurrentService];
    }
}

- (BOOL)shouldUseCompactLayoutForBounds:(CGRect)bounds {
    return CGRectGetHeight(bounds) < 100.0 || CGRectGetWidth(bounds) < 180.0;
}

- (void)updateLayoutModeIfNeeded {
    BOOL compact = [self shouldUseCompactLayoutForBounds:self.bounds];
    BOOL didApplyCurrentMode =
    compact ? self.compactConstraints.firstObject.isActive : self.featuredConstraints.firstObject.isActive;
    if (compact == self.usesCompactLayout && didApplyCurrentMode) {
        return;
    }

    self.usesCompactLayout = compact;
    [NSLayoutConstraint deactivateConstraints:compact ? self.featuredConstraints : self.compactConstraints];
    [NSLayoutConstraint activateConstraints:compact ? self.compactConstraints : self.featuredConstraints];

    self.eyebrowLabel.hidden = compact;
    self.watermarkView.hidden = compact;

    self.surfaceView.layer.cornerRadius = compact ? PPCornerMedium : PPCornerHero;
    self.iconChipView.layer.cornerRadius = compact ? PPCornerSmall + 4 : PPCornerMedium;
    self.chevronPillView.layer.cornerRadius = compact ? 15.0 : 17.0;

    self.titleLabel.font = compact ? [GM boldFontWithSize:PPFontHeadline] : [GM boldFontWithSize:PPFontTitle2];
    self.titleLabel.numberOfLines = compact ? 1 : 2;
    self.titleLabel.lineBreakMode = compact ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping;

    [self applyAppearanceForCurrentService];
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];

    self.onTap = nil;
    self.onTapMenu = nil;
    self.currentService = nil;

    [self.cardView removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    self.cardView.menu = nil;
    self.cardView.showsMenuAsPrimaryAction = NO;

    self.iconView.image = nil;
    self.watermarkView.image = nil;
    self.titleLabel.text = nil;
}

#pragma mark - Helpers

- (void)handleTap {
    if (self.onTap) {
        self.onTap();
    }
}

- (UIColor *)accentColorForService:(PPHomeServiceItem *)service {
    
    
    switch (service.type) {
        case PPHomeServiceTypeVet:
            return PPHomeServiceRGBA(35.0, 118.0, 171.0, 1.0);
        case PPHomeServiceTypeGrooming:
            return PPHomeServiceRGBA(219.0, 127.0, 69.0, 1.0);
        case PPHomeServiceTypeTraining:
            return PPHomeServiceRGBA(122.0, 94.0, 193.0, 1.0);
        case PPHomeServiceTypeFood:
        default:
            return PPHomeServiceRGBA(86.0, 132.0, 60.0, 1.0);
    }
}

- (NSArray<UIColor *> *)gradientColorsForService:(PPHomeServiceItem *)service {
    BOOL darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    switch (service.type) {
        case PPHomeServiceTypeVet:
            return darkMode
            ? @[PPHomeServiceRGBA(33.0, 46.0, 61.0, 1.0), PPHomeServiceRGBA(16.0, 24.0, 32.0, 1.0)]
            : @[PPHomeServiceRGBA(248.0, 252.0, 255.0, 1.0), PPHomeServiceRGBA(230.0, 242.0, 251.0, 1.0)];
        case PPHomeServiceTypeGrooming:
            return darkMode
            ? @[PPHomeServiceRGBA(58.0, 43.0, 34.0, 1.0), PPHomeServiceRGBA(34.0, 25.0, 19.0, 1.0)]
            : @[PPHomeServiceRGBA(255.0, 248.0, 242.0, 1.0), PPHomeServiceRGBA(252.0, 235.0, 218.0, 1.0)];
        case PPHomeServiceTypeTraining:
            return darkMode
            ? @[PPHomeServiceRGBA(49.0, 38.0, 63.0, 1.0), PPHomeServiceRGBA(29.0, 22.0, 37.0, 1.0)]
            : @[PPHomeServiceRGBA(249.0, 246.0, 255.0, 1.0), PPHomeServiceRGBA(235.0, 228.0, 249.0, 1.0)];
        case PPHomeServiceTypeFood:
        default:
            return darkMode
            ? @[PPHomeServiceRGBA(40.0, 50.0, 33.0, 1.0), PPHomeServiceRGBA(23.0, 29.0, 19.0, 1.0)]
            : @[PPHomeServiceRGBA(247.0, 250.0, 241.0, 1.0), PPHomeServiceRGBA(231.0, 241.0, 218.0, 1.0)];
    }
}

- (UIImage *)configuredImageForService:(PPHomeServiceItem *)service
                             pointSize:(CGFloat)pointSize
                                weight:(UIImageSymbolWeight)weight
                       alwaysTemplate:(BOOL)alwaysTemplate {
    UIImage *systemImage = [UIImage systemImageNamed:service.systemIconName];
    if (systemImage) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
        UIImage *configured = [systemImage imageWithConfiguration:config];
        return alwaysTemplate ? [configured imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : configured;
    }

    return PPImage(service.systemIconName);
}

- (void)applyAppearanceForCurrentService {
    PPHomeServiceItem *service = self.currentService;
    if (!service) {
        return;
    }

    BOOL darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accentColor = [self accentColorForService:service];
    NSArray<UIColor *> *gradientColors = [self gradientColorsForService:service];

    self.gradientLayer.colors = @[(id)gradientColors.firstObject.CGColor,
                                  (id)gradientColors.lastObject.CGColor];
    self.surfaceView.layer.borderWidth = 0.0;
    self.surfaceView.layer.borderColor = [accentColor colorWithAlphaComponent:darkMode ? 0.24 : 0.10].CGColor;

    UIButtonConfiguration *config = _cardView.configuration;
    //config.background.strokeColor = [accentColor colorWithAlphaComponent:darkMode ? 0.24 : 0.10];
 //   config.background.strokeColor = [accentColor colorWithAlphaComponent:darkMode ? 0.24 : 0.10];
    _cardView .configuration = config;
    
    [_cardView setNeedsLayout];
    self.surfaceView.layer.cornerRadius = _cardView.layer.cornerRadius;
    
    self.accentGlowView.backgroundColor = [accentColor colorWithAlphaComponent:darkMode ? 0.14 : 0.16];
    self.iconChipView.backgroundColor = darkMode
    ? [UIColor.whiteColor colorWithAlphaComponent:0.08]
    : [UIColor.whiteColor colorWithAlphaComponent:0.62];
    self.chevronPillView.backgroundColor = darkMode
    ? [UIColor.whiteColor colorWithAlphaComponent:0.18]
    : [accentColor colorWithAlphaComponent:0.10];

    self.titleLabel.textColor = darkMode ? UIColor.whiteColor : PPHomeServiceRGBA(17.0, 24.0, 31.0, 1.0);
    self.eyebrowLabel.textColor = darkMode
    ? [UIColor.whiteColor colorWithAlphaComponent:0.64]
    : [accentColor colorWithAlphaComponent:0.82];
    self.chevronView.tintColor = darkMode ? UIColor.whiteColor : accentColor;

    UIImage *iconImage = [self configuredImageForService:service
                                               pointSize:self.usesCompactLayout ? 18.0 : 24.0
                                                  weight:UIImageSymbolWeightSemibold
                                         alwaysTemplate:YES];
    UIImage *watermarkImage = [self configuredImageForService:service
                                                    pointSize:self.usesCompactLayout ? 42.0 : 72.0
                                                       weight:UIImageSymbolWeightMedium
                                              alwaysTemplate:YES];

    self.iconView.image = iconImage;
    self.iconView.tintColor = darkMode ? UIColor.whiteColor : accentColor;
    
  

    
    self.watermarkView.image = watermarkImage;
    self.watermarkView.tintColor = [accentColor colorWithAlphaComponent:darkMode ? 0.18 : 0.10];
    self.watermarkView.alpha = self.usesCompactLayout ? 0.16 : (darkMode ? 0.16 : 0.10);

    UIImageSymbolConfiguration *chevronConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:self.usesCompactLayout ? 11.0 : 12.0
                                                     weight:UIImageSymbolWeightBold];
    NSString *chevronName = Language.isRTL ? @"chevron.left" : @"chevron.right";
    self.chevronView.image = [[[UIImage systemImageNamed:chevronName]
                               imageWithConfiguration:chevronConfig]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.chevronView.tintColor = [accentColor colorWithAlphaComponent:darkMode ? 0.92 : 0.82];
    self.iconView.tintColor = darkMode ? UIColor.whiteColor : accentColor;
    self.cardView.accessibilityLabel = service.title;
    self.cardView.accessibilityHint = kLang(@"Open") ?: @"Open";
}

#pragma mark - Configuration

- (void)configureSkeleton {
    self.currentService = nil;
    self.onTap = nil;
    self.onTapMenu = nil;
    [self.cardView removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    self.cardView.menu = nil;
    self.cardView.showsMenuAsPrimaryAction = NO;

    self.titleLabel.text = @" ";
    self.eyebrowLabel.hidden = YES;
    self.watermarkView.hidden = NO;
    self.gradientLayer.colors = @[(id)[AppForgroundColr colorWithAlphaComponent:0.18].CGColor,
                                  (id)[AppForgroundColr colorWithAlphaComponent:0.10].CGColor];
    self.surfaceView.layer.borderWidth = 0.0;
    self.accentGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    self.iconChipView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.35];
    self.chevronPillView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.0];
    self.iconView.image = nil;
    self.watermarkView.image = nil;
}

- (void)configureWithService:(PPHomeServiceItem *)service {
    self.currentService = service;
    self.titleLabel.text = service.title;

    [self.cardView removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    self.cardView.menu = nil;
    self.cardView.showsMenuAsPrimaryAction = NO;

    [self updateLayoutModeIfNeeded];
    [self applyAppearanceForCurrentService];

    UIMenu *menu = nil;

    if (service.type == PPHomeServiceTypeGrooming) {
        menu = [PPHomeHelper groomingMenuWithHandler:^(MainKindsModel * _Nonnull category) {
            if (self.onTapMenu) {
                self.onTapMenu(service, category);
            }
        }];
    } else if (service.type == PPHomeServiceTypeTraining) {
        menu = [PPHomeHelper trainingMenuWithHandler:^(MainKindsModel * _Nonnull category) {
            if (self.onTapMenu) {
                self.onTapMenu(service, category);
            }
        }];
    } else if (service.type == PPHomeServiceTypeVet) {
        [self.cardView addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    } else {
        menu = [PPHomeHelper accessoriesMenuWithHandler:^(MainKindsModel * _Nonnull category) {
            if (self.onTapMenu) {
                self.onTapMenu(service, category);
            }
        }];
    }

    if (menu) {
        [PPMenuHelper presentMenuFromButton:self.cardView
                                       Menu:menu
                                 destructive:nil
                                     handler:^(NSInteger index, NSString *title) {
        }];
    } else {
        self.cardView.menu = nil;
        self.cardView.showsMenuAsPrimaryAction = NO;
    }
}

#pragma mark - Highlight

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];

    CGFloat scale = highlighted ? PPTapScaleDown : 1.0;
    CGFloat lift = highlighted ? -2.0 : 0.0;
    CGFloat shadowOpacity = highlighted ? 0.10 : 0.06;

    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, lift),
                                                          CGAffineTransformMakeScale(scale, scale));
        self.cardView.layer.shadowOpacity = shadowOpacity;
    } completion:nil];
}

@end
