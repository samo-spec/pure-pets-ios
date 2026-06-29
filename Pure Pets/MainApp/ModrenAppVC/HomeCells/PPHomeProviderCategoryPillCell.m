//
//  PPHomeProviderCategoryPillCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 6/25/26.
//

#import "PPHomeProviderCategoryPillCell.h"


static UIColor *PPHomeProviderCategoryResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traitCollection];
    }
    return color;
}

static UIColor *PPHomeProviderCategoryBlend(UIColor *baseColor,
                                            UIColor *overlayColor,
                                            CGFloat amount,
                                            UITraitCollection *traitCollection)
{
    UIColor *base = PPHomeProviderCategoryResolvedColor(baseColor, traitCollection);
    UIColor *overlay = PPHomeProviderCategoryResolvedColor(overlayColor, traitCollection);
    CGFloat baseRed = 0.0, baseGreen = 0.0, baseBlue = 0.0, baseAlpha = 0.0;
    CGFloat overlayRed = 0.0, overlayGreen = 0.0, overlayBlue = 0.0, overlayAlpha = 0.0;
    if (![base getRed:&baseRed green:&baseGreen blue:&baseBlue alpha:&baseAlpha] ||
        ![overlay getRed:&overlayRed green:&overlayGreen blue:&overlayBlue alpha:&overlayAlpha]) {
        return baseColor ?: overlayColor ?: UIColor.clearColor;
    }

    CGFloat t = MIN(MAX(amount, 0.0), 1.0);
    return [UIColor colorWithRed:(baseRed * (1.0 - t)) + (overlayRed * t)
                           green:(baseGreen * (1.0 - t)) + (overlayGreen * t)
                            blue:(baseBlue * (1.0 - t)) + (overlayBlue * t)
                           alpha:(baseAlpha * (1.0 - t)) + (overlayAlpha * t)];
}



@implementation PPHomeProviderCategoryItem

+ (instancetype)itemWithIdentifier:(NSString *)identifier
                          titleKey:(NSString *)titleKey
                       subtitleKey:(NSString *)subtitleKey
                        systemIcon:(NSString *)systemIconName
                             route:(PPHomeProviderCategoryRoute)route
{
    PPHomeProviderCategoryItem *item = [PPHomeProviderCategoryItem new];
    item.identifier = identifier ?: @"";
    item.titleKey = titleKey ?: @"";
    item.subtitleKey = subtitleKey ?: @"";
    item.systemIconName = systemIconName ?: @"circle";
    item.route = route;
    return item;
}

@end



@implementation PPHomeProviderCategoryPillCell {
    UIButton *_button;
    UIView *_surfaceView;
    UIView *_glowView;
    UIView *_iconContainerView;
    UIImageView *_iconView;
    UIButton *_favButton;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    PPHomeProviderCategoryItem *_item;
    NSString *_currentTitle;
    NSString *_currentSubtitle;
    BOOL _selectedState;
}

+ (NSString *)reuseIdentifier
{
    return @"PPHomeProviderCategoryPillCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    _button = [UIButton buttonWithType:UIButtonTypeCustom];
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    _button.adjustsImageWhenHighlighted = NO;
    _button.backgroundColor = UIColor.clearColor;
    [_button addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [_button addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [_button addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [_button addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [_button addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.contentView addSubview:_button];

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.userInteractionEnabled = NO;
    _surfaceView.layer.borderWidth = 1.0;
    _surfaceView.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_button addSubview:_surfaceView];

    _glowView = [[UIView alloc] init];
    _glowView.translatesAutoresizingMaskIntoConstraints = NO;
    _glowView.userInteractionEnabled = NO;
    _glowView.alpha = 0.0;
    _glowView.hidden = YES;
    _glowView.layer.shadowOffset = CGSizeZero;
    [_surfaceView addSubview:_glowView];

    _iconContainerView = [[UIView alloc] init];
    _iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconContainerView.userInteractionEnabled = NO;
    _iconContainerView.layer.cornerRadius = 16.0;
    _iconContainerView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _iconContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_iconContainerView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.userInteractionEnabled = NO;
    [_iconContainerView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    _titleLabel.textAlignment = NSTextAlignmentNatural;
    _titleLabel.numberOfLines = 2;
    _titleLabel.userInteractionEnabled = NO;
    if (@available(iOS 11.0, *)) {
        _titleLabel.adjustsFontForContentSizeCategory = YES;
    }
    [_surfaceView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _subtitleLabel.textAlignment = NSTextAlignmentNatural;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.userInteractionEnabled = NO;
    if (@available(iOS 11.0, *)) {
        _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    }
    [_surfaceView addSubview:_subtitleLabel];
    _subtitleLabel.hidden = YES;

    _favButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _favButton.translatesAutoresizingMaskIntoConstraints = NO;
    _favButton.tintColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.6];
    _favButton.clipsToBounds = YES;
    UIImage *favImage = [UIImage systemImageNamed:@"heart"
                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                  weight:UIImageSymbolWeightSemibold]];
    [_favButton setImage:[favImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [_favButton addTarget:self action:@selector(pp_handleFavTap) forControlEvents:UIControlEventTouchUpInside];
    [_surfaceView addSubview:_favButton];

    [NSLayoutConstraint activateConstraints:@[
        [_button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_button.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_surfaceView.topAnchor constraintEqualToAnchor:_button.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:_button.leadingAnchor constant:0.0],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:_button.trailingAnchor constant:-0.0],
        [_surfaceView.heightAnchor constraintEqualToAnchor:_button.heightAnchor constant:0.0],

        [_glowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:0.0],
        [_glowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-0.0],
        [_glowView.widthAnchor constraintEqualToConstant:64.0],
        [_glowView.heightAnchor constraintEqualToAnchor:_button.heightAnchor],

[_iconContainerView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:12.0],
         [_iconContainerView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:12],
         [_iconContainerView.widthAnchor constraintEqualToConstant:42.0],
         [_iconContainerView.heightAnchor constraintEqualToConstant:42.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconContainerView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconContainerView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:20.0],
        [_iconView.heightAnchor constraintEqualToConstant:20.0],

        [_favButton.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [_favButton.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_favButton.widthAnchor constraintEqualToConstant:28.0],
        [_favButton.heightAnchor constraintEqualToConstant:28.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconContainerView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_favButton.leadingAnchor constant:-8.0],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconContainerView.centerYAnchor constant:-0.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_iconContainerView.trailingAnchor constant:12.0],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_favButton.leadingAnchor constant:-8.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
    ]];

    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.045;
    self.layer.shadowRadius = 16.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 8.0);
}

- (void)configureWithItem:(PPHomeProviderCategoryItem *)item selected:(BOOL)selected
{
    if (!item) {
        item = [PPHomeProviderCategoryItem itemWithIdentifier:@"marketplace"
                                                     titleKey:@"provider_marketplace_title"
                                                  subtitleKey:@"provider_marketplace_subtitle"
                                                   systemIcon:@"pet-shop"
                                                        route:PPHomeProviderCategoryRouteServices];
    }
    if([item.identifier isEqualToString:@"marketplace"])
    {
        item.systemIconName = @"pet-shop";
        [_button pp_ApplyCornerMask_tl:0 tr:20 bl:0 br:20];
    }
    else
    {
        
    }
    _item = item;
    _selectedState = selected;
    _currentTitle = kLang(item.titleKey) ?: item.titleKey;
    _currentSubtitle = kLang(item.subtitleKey) ?: item.subtitleKey;
    _titleLabel.text = _currentTitle;
    _subtitleLabel.text = _currentSubtitle;
    _button.accessibilityLabel = _currentTitle;
    _button.accessibilityHint = _currentSubtitle;
    _button.accessibilityTraits = UIAccessibilityTraitButton;

    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                            weight:UIImageSymbolWeightSemibold];
        image = [UIImage systemImageNamed:item.systemIconName withConfiguration:configuration];
        if (!image) {
            image = [UIImage imageNamed:item.systemIconName];
        }
    }
    if (!image) {
        image = [UIImage imageNamed:item.systemIconName];
    }
    _iconView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UIImage *favImage = [UIImage systemImageNamed:@"heart"
                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                  weight:UIImageSymbolWeightSemibold]];
    [_favButton setImage:[favImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];

    [self pp_applySelection:NO animated:NO];
}

- (void)pp_applySelection:(BOOL)selected animated:(BOOL)animated
{
    (void)selected;
    _selectedState = NO;

    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *titleColor = AppPrimaryTextClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0],
                                                                                  [UIColor colorWithWhite:0.95 alpha:1.0]);
    UIColor *subtitleColor = AppSecondaryTextClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.39 green:0.42 blue:0.46 alpha:1.0],
                                                                                       [UIColor colorWithWhite:0.72 alpha:1.0]);
    UIColor *accent = AppPrimaryClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.85 green:0.24 blue:0.23 alpha:1.0],
                                                                          [UIColor colorWithRed:0.99 green:0.54 blue:0.49 alpha:1.0]);
    UIColor *foregroundSurface = AppForgroundColr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.996 green:0.992 blue:0.992 alpha:1.0],
                                                                                        [UIColor colorWithWhite:0.11 alpha:1.0]);
    UIColor *backgroundSurface = PPHomeProviderCategoryBlend(foregroundSurface,
                                                             accent,
                                                             darkMode ? 0.035 : 0.007,
                                                             self.traitCollection);
    UIColor *liquidBase = PPHomeProviderCategoryBlend(foregroundSurface,
                                                      UIColor.whiteColor,
                                                      darkMode ? 0.08 : 0.34,
                                                      self.traitCollection);
    UIColor *border = PPHomeProviderCategoryBlend(liquidBase,
                                                  accent,
                                                  darkMode ? 0.18 : 0.10,
                                                  self.traitCollection);
    UIColor *resolvedAccent = PPHomeProviderCategoryResolvedColor(accent, self.traitCollection);

    void (^changes)(void) = ^{
        self->_surfaceView.backgroundColor = backgroundSurface;
        self->_surfaceView.layer.borderWidth = darkMode ? 1.05 : 1.15;
        [self->_surfaceView pp_setBorderColor:[border colorWithAlphaComponent:darkMode ? 0.58 : 0.74]];
        self->_iconContainerView.backgroundColor = [accent colorWithAlphaComponent:darkMode ? 0.16 : 0.09];
        self->_iconContainerView.layer.borderWidth = 0.75;
        [self->_iconContainerView pp_setBorderColor:[border colorWithAlphaComponent:darkMode ? 0.30 : 0.40]];
        self->_titleLabel.textColor = titleColor;
        self->_subtitleLabel.textColor = subtitleColor;
        self->_iconView.tintColor = accent;
        self->_favButton.backgroundColor = PPHomeProviderCategoryBlend(foregroundSurface,
                                                                       accent,
                                                                       darkMode ? 0.12 : 0.035,
                                                                       self.traitCollection);
        self->_favButton.tintColor = [titleColor colorWithAlphaComponent:0.55];
        self->_glowView.alpha = 0;// darkMode ? 0.14 : 0.11;
        self->_glowView.backgroundColor = [accent colorWithAlphaComponent:darkMode ? 0.12 : 0.07];
        self->_glowView.layer.shadowColor = resolvedAccent.CGColor;
        self->_glowView.layer.shadowOpacity = darkMode ? 0.08 : 0.05;
        self->_glowView.layer.shadowRadius = darkMode ? 16.0 : 13.0;
        self.layer.shadowColor = AppPrimaryTextClr.CGColor;
        self.layer.shadowOpacity = darkMode ? 0.075 : 0.045;
        self.layer.shadowRadius = darkMode ? 18.0 : 15.0;
        self.layer.shadowOffset = CGSizeMake(0.0, darkMode ? 9.0 : 7.0);
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.18
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.42
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    return layoutAttributes;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat radius = 22.0;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceView.layer.cornerRadius = radius;
    _favButton.layer.cornerRadius = CGRectGetWidth(_favButton.bounds) * 0.5;
    _glowView.layer.cornerRadius = CGRectGetWidth(_glowView.bounds) * 0.5;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:radius].CGPath;
    [CATransaction commit];
}

- (void)pp_handleTouchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    UIColor *accent = AppPrimaryClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.85 green:0.24 blue:0.23 alpha:1.0],
                                                                          [UIColor colorWithRed:0.99 green:0.54 blue:0.49 alpha:1.0]);
    UIColor *titleColor = AppPrimaryTextClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0],
                                                                                  [UIColor colorWithWhite:0.95 alpha:1.0]);
    UIColor *foregroundSurface = AppForgroundColr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.996 green:0.992 blue:0.992 alpha:1.0],
                                                                                        [UIColor colorWithWhite:0.11 alpha:1.0]);
    UIColor *pressBorder = PPHomeProviderCategoryBlend(foregroundSurface,
                                                       [UIColor colorNamed:@"AppBageGlows"],
                                                       0.26,
                                                       self.traitCollection);
    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self->_surfaceView.transform = CGAffineTransformMakeScale(0.982, 0.982);
        [self->_surfaceView pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.86]];
        self->_iconContainerView.backgroundColor = [accent colorWithAlphaComponent:0.13];
        self->_glowView.alpha = 0;//0.12;
        self->_glowView.backgroundColor = [accent colorWithAlphaComponent:0.12];
        self->_glowView.layer.shadowOpacity = 0.10;
        self->_glowView.layer.shadowRadius = 18.0;
        self.layer.shadowOpacity = 0.065;
        self.layer.shadowRadius = 18.0;
        self.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    } completion:nil];
}

- (void)pp_handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _surfaceView.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.34
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_surfaceView.transform = CGAffineTransformIdentity;
        [self pp_applySelection:NO animated:NO];
    } completion:nil];
}

- (void)pp_handleTap
{
    if (self.onTap && _item) {
        self.onTap(_item);
    }
}

- (void)pp_handleFavTap
{
    if (self.onFavTap && _item) {
        self.onFavTap(_item);
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTap = nil;
    _item = nil;
    _currentTitle = nil;
    _currentSubtitle = nil;
    _selectedState = NO;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _button.accessibilityLabel = nil;
    _button.accessibilityHint = nil;
    _button.accessibilityTraits = UIAccessibilityTraitButton;
    _surfaceView.transform = CGAffineTransformIdentity;
    _iconView.image = nil;
    [self pp_applySelection:NO animated:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applySelection:_selectedState animated:NO];
        }
    }
}

@end
