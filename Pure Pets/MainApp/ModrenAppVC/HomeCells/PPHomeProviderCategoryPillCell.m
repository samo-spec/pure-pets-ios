//
//  PPHomeProviderCategoryPillCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 6/25/26.
//

#import "PPHomeProviderCategoryPillCell.h"




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
    UIView *_chevronContainerView;
    UIImageView *_iconView;
    UIImageView *_chevronView;
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
    _chevronContainerView = [[UIView alloc] init];
    _chevronContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronContainerView.userInteractionEnabled = NO;
    _chevronContainerView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _chevronContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_chevronContainerView];

    _chevronView = [[UIImageView alloc] init];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    _chevronView.userInteractionEnabled = NO;
    [_chevronContainerView addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_button.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_surfaceView.topAnchor constraintEqualToAnchor:_button.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:_button.leadingAnchor constant:6.0],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:_button.trailingAnchor constant:-6.0],
        [_surfaceView.heightAnchor constraintEqualToAnchor:_button.heightAnchor constant:2.0],

        [_glowView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:12.0],
        [_glowView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [_glowView.widthAnchor constraintEqualToConstant:64.0],
        [_glowView.heightAnchor constraintEqualToConstant:64.0],

        [_iconContainerView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:16.0],
        [_iconContainerView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:16],
        [_iconContainerView.widthAnchor constraintEqualToConstant:42.0],
        [_iconContainerView.heightAnchor constraintEqualToConstant:42.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconContainerView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconContainerView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:20.0],
        [_iconView.heightAnchor constraintEqualToConstant:20.0],

        [_chevronContainerView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [_chevronContainerView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
        [_chevronContainerView.widthAnchor constraintEqualToConstant:28.0],
        [_chevronContainerView.heightAnchor constraintEqualToConstant:28.0],

        [_chevronView.centerXAnchor constraintEqualToAnchor:_chevronContainerView.centerXAnchor],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_chevronContainerView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:12.0],
        [_chevronView.heightAnchor constraintEqualToConstant:12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconContainerView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_chevronContainerView.leadingAnchor constant:-8.0],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconContainerView.centerYAnchor constant:-0.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_iconContainerView.trailingAnchor constant:12.0],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_chevronContainerView.leadingAnchor constant:-8.0],
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
                                                   systemIcon:@"square.grid.2x2.fill"
                                                        route:PPHomeProviderCategoryRouteServices];
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
            image = [UIImage systemImageNamed:@"circle.fill" withConfiguration:configuration];
        }
    }
    if (!image) {
        image = [UIImage imageNamed:item.systemIconName];
    }
    _iconView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    NSString *chevronName = Language.isRTL ? @"arrow.left" : @"arrow.right";
    UIImage *chevronImage = nil;
    if (@available(iOS 13.0, *)) {
        chevronImage = [UIImage systemImageNamed:chevronName
                               withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                                 weight:UIImageSymbolWeightSemibold]];
    }
    _chevronView.image = [chevronImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self pp_applySelection:NO animated:NO];
}

- (void)pp_applySelection:(BOOL)selected animated:(BOOL)animated
{
    (void)selected;
    _selectedState = NO;

    UIColor *backgroundSurface = PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.996 green:0.992 blue:0.979 alpha:1.0],
                                                                    [UIColor colorWithWhite:0.11 alpha:1.0]);
    UIColor *titleColor = AppPrimaryTextClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0],
                                                                                  [UIColor colorWithWhite:0.95 alpha:1.0]);
    UIColor *subtitleColor = AppSecondaryTextClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.39 green:0.42 blue:0.46 alpha:1.0],
                                                                                       [UIColor colorWithWhite:0.72 alpha:1.0]);
    UIColor *accent = AppPrimaryClr ?: PPHomeProviderCategoryDynamicColor([UIColor colorWithRed:0.85 green:0.24 blue:0.23 alpha:1.0],
                                                                          [UIColor colorWithRed:0.99 green:0.54 blue:0.49 alpha:1.0]);
    UIColor *border = PPHomeProviderCategoryDynamicColor([[UIColor colorWithWhite:0.91 alpha:1.0] colorWithAlphaComponent:1.0],
                                                         [[UIColor whiteColor] colorWithAlphaComponent:0.10]);

    void (^changes)(void) = ^{
        self->_surfaceView.backgroundColor = backgroundSurface;
        [self->_surfaceView pp_setBorderColor:border];
        self->_iconContainerView.backgroundColor = [accent colorWithAlphaComponent:0.08];
        self->_chevronContainerView.backgroundColor = PPHomeProviderCategoryDynamicColor([UIColor colorWithWhite:0.985 alpha:1.0],
                                                                                        [UIColor colorWithWhite:0.17 alpha:1.0]);
        self->_titleLabel.textColor = titleColor;
        self->_subtitleLabel.textColor = subtitleColor;
        self->_iconView.tintColor = accent;
        self->_chevronView.tintColor = [titleColor colorWithAlphaComponent:0.66];
        self->_glowView.alpha = 0.10;
        self->_glowView.backgroundColor = [accent colorWithAlphaComponent:0.06];
        self->_glowView.layer.shadowColor = accent.CGColor;
        self->_glowView.layer.shadowOpacity = 0.04;
        self->_glowView.layer.shadowRadius = 12.0;
        self.layer.shadowOpacity = 0.045;
        self.layer.shadowRadius = 16.0;
        self.layer.shadowOffset = CGSizeMake(0.0, 8.0);
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
    CGFloat radius = 26.0;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceView.layer.cornerRadius = radius;
    _chevronContainerView.layer.cornerRadius = CGRectGetWidth(_chevronContainerView.bounds) * 0.5;
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
    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self->_surfaceView.transform = CGAffineTransformMakeScale(0.982, 0.982);
        [self->_surfaceView pp_setBorderColor:[accent colorWithAlphaComponent:0.16]];
        self->_iconContainerView.backgroundColor = [accent colorWithAlphaComponent:0.13];
        self->_chevronContainerView.backgroundColor = [accent colorWithAlphaComponent:0.10];
        self->_chevronView.tintColor = [titleColor colorWithAlphaComponent:0.84];
        self->_glowView.alpha = 0.22;
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
    _chevronView.image = nil;
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
