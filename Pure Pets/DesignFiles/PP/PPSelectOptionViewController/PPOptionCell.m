//
//  PPOptionCell.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//

#import "PPOptionCell.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"

typedef NS_ENUM(NSInteger, PPOptionCellIconStyle) {
    PPOptionCellIconStyleAvatar = 0,
    PPOptionCellIconStyleSymbol = 1
};

@interface PPOptionCell ()
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIView *checkPlateView;
@property (nonatomic, strong) UIImageView *checkImageView;
@property (nonatomic, strong) NSLayoutConstraint *titleTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleCenterConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cardLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cardTrailingConstraint;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, assign) PPOptionCellIconStyle iconStyle;
@property (nonatomic, assign, getter=isOptionSelected) BOOL optionSelected;
@end

@implementation PPOptionCell

#pragma mark - Init

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.preservesSuperviewLayoutMargins = NO;
        self.layoutMargins = UIEdgeInsetsZero;
        self.contentView.preservesSuperviewLayoutMargins = NO;
        self.contentView.layoutMargins = UIEdgeInsetsZero;
        self.separatorInset = UIEdgeInsetsZero;
        if (@available(iOS 11.0, *)) {
            self.directionalLayoutMargins = NSDirectionalEdgeInsetsZero;
            self.contentView.directionalLayoutMargins = NSDirectionalEdgeInsetsZero;
            self.insetsLayoutMarginsFromSafeArea = NO;
        }
        self.accessibilityTraits = UIAccessibilityTraitButton;

        _accentColor = AppPrimaryClr ?: UIColor.systemPinkColor;
        _iconStyle = PPOptionCellIconStyleAvatar;
        _preferredHorizontalInset = 0.0;
        _premiumCardStyleEnabled = NO;

        _cardView = [[UIView alloc] init];
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        _cardView.backgroundColor = [self pp_surfaceColor];
        _cardView.layer.cornerRadius = 22.0;
        _cardView.layer.cornerCurve = kCACornerCurveContinuous;
        _cardView.layer.borderWidth = 0.8;
        _cardView.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.07].CGColor;
        _cardView.layer.shadowColor = UIColor.blackColor.CGColor;
        _cardView.layer.shadowOpacity = 0.024;
        _cardView.layer.shadowOffset = CGSizeMake(0.0, 3.0);
        _cardView.layer.shadowRadius = 8.0;
        [self.contentView addSubview:_cardView];

        _iconPlateView = [[UIView alloc] init];
        _iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconPlateView.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:0.10];
        _iconPlateView.layer.cornerRadius = 16.0;
        _iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
        [_cardView addSubview:_iconPlateView];

        _circleImageView = [[UIImageView alloc] init];
        _circleImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _circleImageView.contentMode = UIViewContentModeScaleAspectFit;
        _circleImageView.clipsToBounds = YES;
        _circleImageView.tintColor = [self pp_accentColor];
        [_iconPlateView addSubview:_circleImageView];

        _checkPlateView = [[UIView alloc] init];
        _checkPlateView.translatesAutoresizingMaskIntoConstraints = NO;
        _checkPlateView.backgroundColor = [self pp_accentColor];
        _checkPlateView.layer.cornerRadius = 13.0;
        _checkPlateView.layer.cornerCurve = kCACornerCurveContinuous;
        _checkPlateView.alpha = 0.0;
        _checkPlateView.transform = CGAffineTransformMakeScale(0.82, 0.82);
        [_cardView addSubview:_checkPlateView];

        UIImageSymbolConfiguration *checkConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                  weight:UIImageSymbolWeightBold
                                                                                                   scale:UIImageSymbolScaleMedium];
        _checkImageView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"checkmark" withConfiguration:checkConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        _checkImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _checkImageView.tintColor = UIColor.whiteColor;
        _checkImageView.contentMode = UIViewContentModeCenter;
        [_checkPlateView addSubview:_checkImageView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:([Styling fontMedium:16] ?: [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold])];
        _titleLabel.adjustsFontForContentSizeCategory = YES;
        _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
        _titleLabel.numberOfLines = 2;
        [_cardView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:([Styling fontRegular:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightRegular])];
        _subtitleLabel.adjustsFontForContentSizeCategory = YES;
        _subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
        _subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
        _subtitleLabel.numberOfLines = 2;
        [_cardView addSubview:_subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
            self.cardLeadingConstraint = [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:_preferredHorizontalInset],
            self.cardTrailingConstraint = [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-_preferredHorizontalInset],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],
            [_cardView.heightAnchor constraintGreaterThanOrEqualToConstant:64.0],

            [_iconPlateView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
            [_iconPlateView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_iconPlateView.topAnchor constraintGreaterThanOrEqualToAnchor:_cardView.topAnchor constant:8.0],
            [_iconPlateView.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-8.0],
            [_iconPlateView.widthAnchor constraintEqualToConstant:48.0],
            [_iconPlateView.heightAnchor constraintEqualToConstant:48.0],

            [_circleImageView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
            [_circleImageView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
            [_circleImageView.widthAnchor constraintEqualToConstant:31.0],
            [_circleImageView.heightAnchor constraintEqualToConstant:31.0],

            [_checkPlateView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
            [_checkPlateView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_checkPlateView.widthAnchor constraintEqualToConstant:26.0],
            [_checkPlateView.heightAnchor constraintEqualToConstant:26.0],

            [_checkImageView.centerXAnchor constraintEqualToAnchor:_checkPlateView.centerXAnchor],
            [_checkImageView.centerYAnchor constraintEqualToAnchor:_checkPlateView.centerYAnchor],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconPlateView.trailingAnchor constant:13.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_checkPlateView.leadingAnchor constant:-12.0],
            self.titleTopConstraint = [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:15.0],
            self.titleCenterConstraint = [_titleLabel.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],

            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0],
            self.subtitleBottomConstraint = [_subtitleLabel.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-13.0]
        ]];
        self.titleCenterConstraint.active = NO;
        self.subtitleBottomConstraint.active = NO;
        [self pp_applyTextLayoutForSubtitle:nil];
        [self pp_applyVisualStyle];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.circleImageView.image = nil;
    self.circleImageView.tintColor = [self pp_accentColor];
    self.circleImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.circleImageView.layer.cornerRadius = 0.0;
    self.iconPlateView.layer.cornerRadius = 16.0;
    self.iconStyle = PPOptionCellIconStyleAvatar;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.titleLabel.numberOfLines = 2;
    self.subtitleLabel.hidden = YES;
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.accentColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    self.premiumCardStyleEnabled = NO;
    self.preferredHorizontalInset = 0.0;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self setOptionSelected:NO animated:NO];
}

#pragma mark - Public configuration

- (void)setPreferredHorizontalInset:(CGFloat)preferredHorizontalInset {
    _preferredHorizontalInset = MAX(0.0, preferredHorizontalInset);
    self.cardLeadingConstraint.constant = _preferredHorizontalInset;
    self.cardTrailingConstraint.constant = -_preferredHorizontalInset;
}

- (void)setPremiumCardStyleEnabled:(BOOL)premiumCardStyleEnabled {
    if (_premiumCardStyleEnabled == premiumCardStyleEnabled) return;
    _premiumCardStyleEnabled = premiumCardStyleEnabled;
    [self pp_applyVisualStyle];
    [self setOptionSelected:self.isOptionSelected animated:NO];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage *)image {
    [self pp_configureTextWithTitle:title subtitle:subtitle];
    [self pp_applyAvatarImage:(image ?: [PPModernAvatarRenderer avatarImageForName:(title ?: @"") size:44])];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageUrl:(NSString *)imageUrl {
    [self pp_configureTextWithTitle:title subtitle:subtitle];
    [self pp_applyAvatarImage:[PPModernAvatarRenderer avatarImageForName:(title ?: @"") size:44]];

    __weak typeof(self) weakSelf = self;
    [PPImageLoaderManager.shared setImageOnImageView:self.circleImageView
                                                 url:imageUrl
                                         placeholder:self.circleImageView.image
                                          complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.circleImageView.contentMode = UIViewContentModeScaleAspectFill;
    }];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageNamed:(NSString *)imageNamed {
    [self configureWithTitle:title subtitle:subtitle imageNamed:imageNamed useSmallIcon:NO];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageNamed:(NSString *)imageNamed useSmallIcon:(BOOL)useSmallIcon {
    [self configureWithTitle:title
                    subtitle:subtitle
                  imageNamed:imageNamed
                useSmallIcon:useSmallIcon
                 accentColor:nil
                    selected:self.isOptionSelected];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                imageNamed:(NSString *)imageNamed
              useSmallIcon:(BOOL)useSmallIcon
               accentColor:(UIColor *)accentColor
                  selected:(BOOL)selected {
    self.accentColor = accentColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    [self pp_configureTextWithTitle:title subtitle:subtitle];
    [self pp_applySymbolNamed:imageNamed useSmallIcon:useSmallIcon];
    [self setOptionSelected:selected animated:NO];
}

- (void)setOptionSelected:(BOOL)selected animated:(BOOL)animated {
    _optionSelected = selected;
    UIColor *accent = [self pp_accentColor];
    UIColor *surface = [self pp_surfaceColor];
    UIColor *selectedSurface = [accent colorWithAlphaComponent:0.105];
    UIColor *borderColor = selected ? [accent colorWithAlphaComponent:0.45] : [[UIColor labelColor] colorWithAlphaComponent:0.07];
    UIColor *iconBackground = nil;

    if (!self.premiumCardStyleEnabled && self.iconStyle == PPOptionCellIconStyleSymbol) {
        iconBackground = UIColor.clearColor;
        self.circleImageView.tintColor = AppButtonMixColorClr ?: accent;
    } else if (self.iconStyle == PPOptionCellIconStyleSymbol) {
        iconBackground = selected ? accent : [accent colorWithAlphaComponent:0.115];
        self.circleImageView.tintColor = selected ? UIColor.whiteColor : accent;
    } else {
        iconBackground = selected ? [accent colorWithAlphaComponent:0.18] : UIColor.clearColor;
        self.circleImageView.tintColor = nil;
    }

    void (^changes)(void) = ^{
        if (self.premiumCardStyleEnabled) {
            self.cardView.backgroundColor = selected ? selectedSurface : surface;
            self.cardView.layer.borderColor = borderColor.CGColor;
            self.cardView.layer.borderWidth = selected ? 1.15 : 0.8;
            self.cardView.layer.shadowOpacity = 0.024;
            self.iconPlateView.backgroundColor = iconBackground;
        } else {
            self.cardView.backgroundColor = AppBackgroundClrLigter ?: UIColor.clearColor;
            self.cardView.layer.borderColor = UIColor.clearColor.CGColor;
            self.cardView.layer.borderWidth = 0.0;
            self.cardView.layer.shadowOpacity = 0.0;
            self.iconPlateView.backgroundColor = UIColor.clearColor;
        }
        self.checkPlateView.backgroundColor = accent;
        self.checkPlateView.alpha = (selected && self.premiumCardStyleEnabled) ? 1.0 : 0.0;
        self.checkPlateView.transform = (selected && self.premiumCardStyleEnabled) ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.82, 0.82);
    };

    if (animated) {
        [UIView animateWithDuration:0.20
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }

    if (selected) {
        self.accessibilityTraits |= UIAccessibilityTraitSelected;
    } else {
        self.accessibilityTraits &= ~UIAccessibilityTraitSelected;
    }
}

#pragma mark - Touch feedback

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    if (!self.premiumCardStyleEnabled) return;
    CGFloat scale = highlighted ? 0.985 : 1.0;
    NSTimeInterval duration = highlighted ? 0.08 : 0.18;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.transform = CGAffineTransformMakeScale(scale, scale);
        self.cardView.layer.shadowOpacity = highlighted ? 0.012 : 0.024;
    } completion:nil];
}

#pragma mark - Private helpers

- (void)pp_applyVisualStyle {
    BOOL premium = self.premiumCardStyleEnabled;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = premium ? UIColor.clearColor : (AppBackgroundClrLigter ?: UIColor.clearColor);

    self.cardView.backgroundColor = premium ? [self pp_surfaceColor] : (AppBackgroundClrLigter ?: UIColor.clearColor);
    self.cardView.layer.cornerRadius = premium ? 22.0 : 0.0;
    self.cardView.layer.borderWidth = premium ? 0.8 : 0.0;
    self.cardView.layer.borderColor = premium ? [[UIColor labelColor] colorWithAlphaComponent:0.07].CGColor : UIColor.clearColor.CGColor;
    self.cardView.layer.shadowOpacity = premium ? 0.024 : 0.0;
    self.cardView.layer.shadowOffset = premium ? CGSizeMake(0.0, 3.0) : CGSizeZero;
    self.cardView.layer.shadowRadius = premium ? 8.0 : 0.0;
    self.iconPlateView.backgroundColor = premium ? [[self pp_accentColor] colorWithAlphaComponent:0.10] : UIColor.clearColor;
    self.checkPlateView.hidden = !premium;
}

- (void)pp_configureTextWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    NSString *safeTitle = title ?: @"";
    NSString *safeSubtitle = subtitle ?: @"";
    self.titleLabel.text = safeTitle;
    self.subtitleLabel.text = safeSubtitle;
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self pp_applyTextLayoutForSubtitle:safeSubtitle];
    self.accessibilityLabel = safeSubtitle.length ? [NSString stringWithFormat:@"%@, %@", safeTitle, safeSubtitle] : safeTitle;
}

- (void)pp_applyTextLayoutForSubtitle:(NSString *)subtitle {
    BOOL hasSubtitle = subtitle.length > 0;
    self.titleTopConstraint.active = hasSubtitle;
    self.titleCenterConstraint.active = !hasSubtitle;
    self.subtitleBottomConstraint.active = hasSubtitle;
    self.subtitleLabel.hidden = !hasSubtitle;
}

- (void)pp_applyAvatarImage:(UIImage *)image {
    self.iconStyle = PPOptionCellIconStyleAvatar;
    self.iconPlateView.layer.cornerRadius = self.premiumCardStyleEnabled ? 24.0 : 20.0;
    self.circleImageView.layer.cornerRadius = self.premiumCardStyleEnabled ? 22.0 : 20.0;
    self.circleImageView.clipsToBounds = YES;
    self.circleImageView.contentMode = self.premiumCardStyleEnabled ? UIViewContentModeScaleAspectFill : UIViewContentModeScaleAspectFit;
    self.circleImageView.image = image;
    self.circleImageView.tintColor = nil;
    [self setOptionSelected:self.isOptionSelected animated:NO];
}

- (void)pp_applySymbolNamed:(NSString *)imageNamed useSmallIcon:(BOOL)useSmallIcon {
    self.iconStyle = PPOptionCellIconStyleSymbol;
    self.iconPlateView.layer.cornerRadius = self.premiumCardStyleEnabled ? 16.0 : 20.0;
    self.circleImageView.layer.cornerRadius = 0.0;
    self.circleImageView.clipsToBounds = NO;
    self.circleImageView.contentMode = UIViewContentModeCenter;
    self.circleImageView.image = [self pp_symbolImageNamed:imageNamed useSmallIcon:useSmallIcon];
    self.circleImageView.tintColor = self.premiumCardStyleEnabled ? [self pp_accentColor] : AppButtonMixColorClr;
    [self pp_applyVisualStyle];
}

- (UIImage *)pp_symbolImageNamed:(NSString *)imageNamed useSmallIcon:(BOOL)useSmallIcon {
    NSString *safeName = imageNamed.length ? imageNamed : @"tag.fill";
    CGFloat pointSize = useSmallIcon ? 18.0 : 20.0;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                        weight:UIImageSymbolWeightSemibold
                                                                                         scale:UIImageSymbolScaleMedium];
    UIImage *image = [UIImage systemImageNamed:safeName withConfiguration:config];
    if (!image) image = [UIImage systemImageNamed:@"tag.fill" withConfiguration:config];
    if (!image) image = [UIImage imageNamed:safeName];
    if (!image) image = [UIImage imageNamed:@"square-layout"];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIColor *)pp_surfaceColor {
    return AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
}

- (UIColor *)pp_accentColor {
    return self.accentColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
}

@end
