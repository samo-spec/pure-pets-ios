//
//  PPOptionCell.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//

#import "PPOptionCell.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "UserModel.h"

typedef NS_ENUM(NSInteger, PPOptionCellIconStyle) {
    PPOptionCellIconStyleAvatar = 0,
    PPOptionCellIconStyleSymbol = 1
};

@interface PPOptionCell ()
- (UIColor *)pp_unselectedCheckPlateBorderColor;
- (void)pp_refreshCheckPlateBorderColor;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) CAGradientLayer *iconPlateGradientLayer;
@property (nonatomic, strong) UIView *onlineIndicatorView;
@property (nonatomic, strong) UIView *verifiedBadgeView;
@property (nonatomic, strong) UIImageView *verifiedBadgeIcon;
@property (nonatomic, strong) UIView *trailingActionPlate;
@property (nonatomic, strong) UIImageView *trailingChevronView;
@property (nonatomic, strong) UIView *checkPlateView;
@property (nonatomic, strong) UIImageView *checkImageView;
@property (nonatomic, strong) NSLayoutConstraint *titleTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleCenterConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cardLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cardTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *iconPlateWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *iconPlateHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *circleImageWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *circleImageHeightConstraint;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, assign) PPOptionCellIconStyle iconStyle;
@property (nonatomic, assign, getter=isOptionSelected) BOOL optionSelected;
@property (nonatomic, assign) BOOL isActionPortalMode;
@end


@implementation PPOptionCell

- (UIColor *)pp_unselectedCheckPlateBorderColor {
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.28];
        }
    }
    return [UIColor colorWithWhite:0.0 alpha:0.18];
}

- (void)pp_refreshCheckPlateBorderColor {
    if (self.checkPlateView.layer.borderWidth > 0.0) {
        self.checkPlateView.layer.borderColor = [self pp_unselectedCheckPlateBorderColor].CGColor;
    }
}

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
        _iconPlateView.clipsToBounds = YES;
        [_cardView addSubview:_iconPlateView];

        _iconPlateGradientLayer = [CAGradientLayer layer];
        _iconPlateGradientLayer.startPoint = CGPointMake(0.0, 0.0);
        _iconPlateGradientLayer.endPoint = CGPointMake(1.0, 1.0);
        [_iconPlateView.layer insertSublayer:_iconPlateGradientLayer atIndex:0];

        _circleImageView = [[UIImageView alloc] init];
        _circleImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _circleImageView.contentMode = UIViewContentModeScaleAspectFit;
        _circleImageView.clipsToBounds = YES;
        _circleImageView.tintColor = [self pp_accentColor];
        [_iconPlateView addSubview:_circleImageView];

        _onlineIndicatorView = [UIView new];
        _onlineIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        _onlineIndicatorView.backgroundColor = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
        _onlineIndicatorView.layer.cornerRadius = 6.5;
        _onlineIndicatorView.layer.borderWidth = 2.0;
        _onlineIndicatorView.layer.borderColor = UIColor.whiteColor.CGColor;
        _onlineIndicatorView.hidden = YES;
        [_cardView addSubview:_onlineIndicatorView];

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

        _trailingActionPlate = [UIView new];
        _trailingActionPlate.translatesAutoresizingMaskIntoConstraints = NO;
        _trailingActionPlate.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent:0.045];
        _trailingActionPlate.layer.cornerRadius = 16.0;
        _trailingActionPlate.layer.cornerCurve = kCACornerCurveContinuous;
        _trailingActionPlate.hidden = YES;
        [_cardView addSubview:_trailingActionPlate];

        NSString *chevronName = Language.isRTL ? @"chevron.left" : @"chevron.right";
        UIImageSymbolConfiguration *chevConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.5 weight:UIImageSymbolWeightBold];
        _trailingChevronView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:chevronName withConfiguration:chevConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        _trailingChevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _trailingChevronView.tintColor = AppTertiaryTextClr ?: UIColor.tertiaryLabelColor;
        _trailingChevronView.contentMode = UIViewContentModeCenter;
        [_trailingActionPlate addSubview:_trailingChevronView];

        _verifiedBadgeView = [UIView new];
        _verifiedBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
        _verifiedBadgeView.backgroundColor = [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.12];
        _verifiedBadgeView.layer.cornerRadius = 10.0;
        _verifiedBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
        _verifiedBadgeView.hidden = YES;
        [_cardView addSubview:_verifiedBadgeView];

        UIImageSymbolConfiguration *sealConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold];
        _verifiedBadgeIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"checkmark.seal.fill" withConfiguration:sealConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        _verifiedBadgeIcon.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
        _verifiedBadgeIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _verifiedBadgeIcon.contentMode = UIViewContentModeCenter;
        [_verifiedBadgeView addSubview:_verifiedBadgeIcon];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:([Styling fontBold:16.5] ?: [UIFont systemFontOfSize:16.5 weight:UIFontWeightBold])];
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
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4.0],
            self.cardLeadingConstraint = [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:_preferredHorizontalInset],
            self.cardTrailingConstraint = [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-_preferredHorizontalInset],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4.0],
            [_cardView.heightAnchor constraintGreaterThanOrEqualToConstant:62.0],

            [_iconPlateView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14.0],
            [_iconPlateView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_iconPlateView.topAnchor constraintGreaterThanOrEqualToAnchor:_cardView.topAnchor constant:8.0],
            [_iconPlateView.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-8.0],
            self.iconPlateWidthConstraint = [_iconPlateView.widthAnchor constraintEqualToConstant:48.0],
            self.iconPlateHeightConstraint = [_iconPlateView.heightAnchor constraintEqualToConstant:48.0],

            [_circleImageView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
            [_circleImageView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
            self.circleImageWidthConstraint = [_circleImageView.widthAnchor constraintEqualToConstant:31.0],
            self.circleImageHeightConstraint = [_circleImageView.heightAnchor constraintEqualToConstant:31.0],

            [_onlineIndicatorView.trailingAnchor constraintEqualToAnchor:_iconPlateView.trailingAnchor constant:2.0],
            [_onlineIndicatorView.bottomAnchor constraintEqualToAnchor:_iconPlateView.bottomAnchor constant:2.0],
            [_onlineIndicatorView.widthAnchor constraintEqualToConstant:13.0],
            [_onlineIndicatorView.heightAnchor constraintEqualToConstant:13.0],

            [_checkPlateView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
            [_checkPlateView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_checkPlateView.widthAnchor constraintEqualToConstant:26.0],
            [_checkPlateView.heightAnchor constraintEqualToConstant:26.0],

            [_checkImageView.centerXAnchor constraintEqualToAnchor:_checkPlateView.centerXAnchor],
            [_checkImageView.centerYAnchor constraintEqualToAnchor:_checkPlateView.centerYAnchor],

            [_trailingActionPlate.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14.0],
            [_trailingActionPlate.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
            [_trailingActionPlate.widthAnchor constraintEqualToConstant:32.0],
            [_trailingActionPlate.heightAnchor constraintEqualToConstant:32.0],

            [_trailingChevronView.centerXAnchor constraintEqualToAnchor:_trailingActionPlate.centerXAnchor],
            [_trailingChevronView.centerYAnchor constraintEqualToAnchor:_trailingActionPlate.centerYAnchor],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconPlateView.trailingAnchor constant:13.0],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_checkPlateView.leadingAnchor constant:-10.0],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_trailingActionPlate.leadingAnchor constant:-10.0],
            self.titleTopConstraint = [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:15.0],
            self.titleCenterConstraint = [_titleLabel.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],

            [_verifiedBadgeView.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:6.0],
            [_verifiedBadgeView.trailingAnchor constraintLessThanOrEqualToAnchor:_checkPlateView.leadingAnchor constant:-6.0],
            [_verifiedBadgeView.trailingAnchor constraintLessThanOrEqualToAnchor:_trailingActionPlate.leadingAnchor constant:-6.0],
            [_verifiedBadgeView.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
            [_verifiedBadgeView.widthAnchor constraintEqualToConstant:20.0],
            [_verifiedBadgeView.heightAnchor constraintEqualToConstant:20.0],

            [_verifiedBadgeIcon.centerXAnchor constraintEqualToAnchor:_verifiedBadgeView.centerXAnchor],
            [_verifiedBadgeIcon.centerYAnchor constraintEqualToAnchor:_verifiedBadgeView.centerYAnchor],

            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_checkPlateView.leadingAnchor constant:-10.0],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_trailingActionPlate.leadingAnchor constant:-10.0],
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

- (void)layoutSubviews {
    [super layoutSubviews];
    self.iconPlateGradientLayer.frame = self.iconPlateView.bounds;
    self.iconPlateGradientLayer.cornerRadius = self.iconPlateView.layer.cornerRadius;
    if (self.isUserOption && self.onlineIndicatorView) {
        if (@available(iOS 13.0, *)) {
            self.onlineIndicatorView.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.12 alpha:1.0] : UIColor.whiteColor).CGColor;
        }
    }
    [self pp_refreshCheckPlateBorderColor];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshCheckPlateBorderColor];
        }
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.circleImageView.image = nil;
    self.circleImageView.tintColor = [self pp_accentColor];
    self.circleImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.circleImageView.layer.cornerRadius = 0.0;
    self.iconPlateView.layer.cornerRadius = 16.0;
    self.iconPlateGradientLayer.colors = nil;
    self.iconStyle = PPOptionCellIconStyleAvatar;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.titleLabel.numberOfLines = 2;
    self.subtitleLabel.hidden = YES;
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.cardView.transform = CGAffineTransformIdentity;
    self.accentColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    self.premiumCardStyleEnabled = NO;
    self.isUserOption = NO;
    self.isActionPortalMode = NO;
    self.preferredHorizontalInset = 0.0;
    self.onlineIndicatorView.hidden = YES;
    self.verifiedBadgeView.hidden = YES;
    self.trailingActionPlate.hidden = YES;
    self.checkPlateView.hidden = NO;
    self.checkPlateView.backgroundColor = UIColor.clearColor;
    self.checkPlateView.layer.borderWidth = 1.5;
    self.checkPlateView.layer.borderColor = [self pp_unselectedCheckPlateBorderColor].CGColor;
    self.checkImageView.hidden = YES;
    self.checkPlateView.alpha = 1.0;
    self.checkPlateView.transform = CGAffineTransformIdentity;
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

- (void)configureAsActionPortalWithTitle:(nullable NSString *)title
                                subtitle:(nullable NSString *)subtitle
                                actionID:(nullable NSString *)actionID
                              systemIcon:(nullable NSString *)systemIcon
                             accentColor:(nullable UIColor *)accentColor
                                selected:(BOOL)selected
{
    self.isActionPortalMode = YES;
    self.premiumCardStyleEnabled = YES;
    self.cardView.layer.cornerRadius = 24.0;
    self.preferredHorizontalInset = 0.0;
    
    // Vibrant Chromatic Identity per action
    UIColor *c1 = nil;
    UIColor *c2 = nil;
    NSString *icon = systemIcon ?: @"plus.circle.fill";
    
    if ([actionID isEqualToString:@"addPetForAdoption"] || [actionID containsString:@"Adopt"]) {
        c1 = [UIColor colorWithRed:0.98 green:0.36 blue:0.36 alpha:1.0]; // Warm Coral
        c2 = [UIColor colorWithRed:1.00 green:0.56 blue:0.40 alpha:1.0]; // Golden Amber
        if (!systemIcon.length) icon = @"heart.fill";
    } else if ([actionID isEqualToString:@"newAd"] || [actionID containsString:@"Ad"]) {
        c1 = [UIColor colorWithRed:0.90 green:0.00 blue:0.27 alpha:1.0]; // Pure Pets Crimson
        c2 = [UIColor colorWithRed:1.00 green:0.30 blue:0.46 alpha:1.0]; // Radiant Rose
        if (!systemIcon.length) icon = @"square.and.pencil";
    } else if ([actionID isEqualToString:@"addUsedButton"] || [actionID containsString:@"Accessory"] || [actionID containsString:@"Used"]) {
        c1 = [UIColor colorWithRed:0.15 green:0.42 blue:0.94 alpha:1.0]; // Royal Azure
        c2 = [UIColor colorWithRed:0.00 green:0.72 blue:0.88 alpha:1.0]; // Vivid Cyan
        if (!systemIcon.length) icon = @"tag.fill";
    } else {
        UIColor *base = accentColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
        c1 = base;
        c2 = [base colorWithAlphaComponent:0.72];
    }
    
    self.accentColor = c1;
    self.iconPlateGradientLayer.colors = @[(id)c1.CGColor, (id)c2.CGColor];
    self.iconPlateView.backgroundColor = UIColor.clearColor;
    
    // Icon sizing: 52x52 squircle plate
    self.iconPlateWidthConstraint.constant = 52.0;
    self.iconPlateHeightConstraint.constant = 52.0;
    self.iconPlateView.layer.cornerRadius = 18.0;
    
    self.circleImageWidthConstraint.constant = 26.0;
    self.circleImageHeightConstraint.constant = 26.0;
    self.circleImageView.layer.cornerRadius = 0.0;
    self.circleImageView.clipsToBounds = NO;
    self.circleImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightBold];
    UIImage *img = [UIImage systemImageNamed:icon withConfiguration:symCfg];
    if (!img) img = [UIImage imageNamed:icon];
    self.circleImageView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.circleImageView.tintColor = UIColor.whiteColor;
    
    // Typography
    self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
                            scaledFontForFont:([Styling fontBold:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold])];
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    
    self.subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                               scaledFontForFont:([Styling fontRegular:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular])];
    self.subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    
    [self pp_configureTextWithTitle:title subtitle:subtitle];
    
    self.trailingActionPlate.hidden = NO;
    self.checkPlateView.hidden = YES;
    self.onlineIndicatorView.hidden = YES;
    self.verifiedBadgeView.hidden = YES;
    
    [self pp_applyVisualStyle];
}

- (void)configureAsUserDossierWithUser:(UserModel *)user selected:(BOOL)selected
{
    self.isUserOption = YES;
    self.isActionPortalMode = NO;
    self.premiumCardStyleEnabled = YES;
    self.cardView.layer.cornerRadius = 22.0;
    self.preferredHorizontalInset = 0.0;
    
    self.iconPlateGradientLayer.colors = nil;
    self.iconPlateWidthConstraint.constant = 48.0;
    self.iconPlateHeightConstraint.constant = 48.0;
    self.iconPlateView.layer.cornerRadius = 20.0;
    self.circleImageWidthConstraint.constant = 48.0;
    self.circleImageHeightConstraint.constant = 48.0;
    self.circleImageView.layer.cornerRadius = 20.0;
    self.circleImageView.clipsToBounds = YES;
    self.circleImageView.contentMode = UIViewContentModeScaleAspectFill;
    
    // Title
    NSString *name = user.UserName.length > 0 ? user.UserName :
        (user.FirstName.length > 0 ? [NSString stringWithFormat:@"%@ %@", user.FirstName, user.LastName ?: @""] : (kLang(@"Account") ?: @"Member"));
    
    // Subtitle: format phone or email or placeholder
    NSString *sub = user.MobileNo.length > 0 ? user.MobileNo : (user.UserEmail.length > 0 ? user.UserEmail : @"Pure Pets User");
    
    self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
                            scaledFontForFont:([Styling fontBold:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold])];
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    
    self.subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                               scaledFontForFont:([Styling fontRegular:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular])];
    self.subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    
    [self pp_configureTextWithTitle:name subtitle:sub];
    
    // Avatar image or monogram
    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:(name ?: @"") size:48 style:PPModernAvatarStyleGradient];
    self.circleImageView.image = placeholder;
    if (user.UserImageUrl.absoluteString.length > 0) {
        __weak typeof(self) weakSelf = self;
        [PPImageLoaderManager.shared setImageOnImageView:self.circleImageView
                                                     url:user.UserImageUrl.absoluteString
                                             placeholder:placeholder
                                              complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.circleImageView.contentMode = UIViewContentModeScaleAspectFill;
        }];
    }
    
    // Online indicator
    self.onlineIndicatorView.hidden = !user.isOnline;
    
    // Verified seal
    BOOL isVerified = user.isAdmin || user.isSuperAdmin;
    self.verifiedBadgeView.hidden = !isVerified;
    
    self.trailingActionPlate.hidden = NO;
    self.checkPlateView.hidden = YES;
    
    [self pp_applyVisualStyle];
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

    BOOL isPremium = self.premiumCardStyleEnabled;
    BOOL showSelector = isPremium && !self.isActionPortalMode && !self.isUserOption;

    void (^changes)(void) = ^{
        if (isPremium) {
            self.cardView.backgroundColor = selected ? selectedSurface : surface;
            self.cardView.layer.borderColor = borderColor.CGColor;
            self.cardView.layer.borderWidth = selected ? 1.2 : 0.8;
            self.cardView.layer.shadowOpacity = selected ? 0.04 : 0.024;
            self.iconPlateView.backgroundColor = iconBackground;
        } else {
            self.cardView.backgroundColor = AppBackgroundClrLigter ?: UIColor.clearColor;
            self.cardView.layer.borderColor = UIColor.clearColor.CGColor;
            self.cardView.layer.borderWidth = 0.0;
            self.cardView.layer.shadowOpacity = 0.0;
            self.iconPlateView.backgroundColor = UIColor.clearColor;
        }

        if (showSelector) {
            self.checkPlateView.hidden = NO;
            self.checkPlateView.alpha = 1.0;
            if (selected) {
                self.checkPlateView.backgroundColor = accent;
                self.checkPlateView.layer.borderWidth = 0.0;
                self.checkPlateView.layer.borderColor = UIColor.clearColor.CGColor;
                self.checkImageView.hidden = NO;
                self.checkImageView.tintColor = UIColor.whiteColor;
                self.checkPlateView.transform = CGAffineTransformIdentity;
            } else {
                self.checkPlateView.backgroundColor = UIColor.clearColor;
                self.checkPlateView.layer.borderWidth = 1.5;
                self.checkPlateView.layer.borderColor = [self pp_unselectedCheckPlateBorderColor].CGColor;
                self.checkImageView.hidden = YES;
                self.checkPlateView.transform = CGAffineTransformIdentity;
            }
        } else {
            self.checkPlateView.hidden = YES;
        }
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
    CGFloat scale = highlighted ? 0.975 : 1.0;
    NSTimeInterval duration = highlighted ? 0.08 : 0.22;
    if (highlighted) {
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [impact prepare];
            [impact impactOccurred];
        }
    }
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.transform = CGAffineTransformMakeScale(scale, scale);
        self.cardView.layer.shadowOpacity = highlighted ? 0.015 : 0.035;
        self.trailingActionPlate.transform = highlighted ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Private helpers

- (void)pp_applyVisualStyle {
    BOOL premium = self.premiumCardStyleEnabled;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = premium ? UIColor.clearColor : (AppBackgroundClrLigter ?: UIColor.clearColor);

    CGFloat radius = self.isActionPortalMode ? 24.0 : (self.isUserOption ? 22.0 : 20.0);
    self.cardView.backgroundColor = premium ? [self pp_surfaceColor] : (AppBackgroundClrLigter ?: UIColor.clearColor);
    self.cardView.layer.cornerRadius = premium ? radius : 0.0;
    self.cardView.layer.borderWidth = premium ? 0.85 : 0.0;
    self.cardView.layer.borderColor = premium ? [[UIColor labelColor] colorWithAlphaComponent:0.07].CGColor : UIColor.clearColor.CGColor;
    self.cardView.layer.shadowOpacity = premium ? 0.035 : 0.0;
    self.cardView.layer.shadowOffset = premium ? CGSizeMake(0.0, 4.0) : CGSizeZero;
    self.cardView.layer.shadowRadius = premium ? 10.0 : 0.0;
    if (!self.isActionPortalMode) {
        self.iconPlateView.backgroundColor = premium ? [[self pp_accentColor] colorWithAlphaComponent:0.10] : UIColor.clearColor;
    }
    if (self.isActionPortalMode || self.isUserOption) {
        self.checkPlateView.hidden = YES;
    } else {
        self.checkPlateView.hidden = !premium;
    }
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
    if (self.isUserOption) {
        self.iconPlateWidthConstraint.constant = 48.0;
        self.iconPlateHeightConstraint.constant = 48.0;
        self.circleImageWidthConstraint.constant = 48.0;
        self.circleImageHeightConstraint.constant = 48.0;
        self.iconPlateView.layer.cornerRadius = 20.0;
        self.circleImageView.layer.cornerRadius = 20.0;
    } else {
        self.iconPlateWidthConstraint.constant = 48.0;
        self.iconPlateHeightConstraint.constant = 48.0;
        self.circleImageWidthConstraint.constant = 36.0;
        self.circleImageHeightConstraint.constant = 36.0;
        self.iconPlateView.layer.cornerRadius = 16.0;
        self.iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
        self.circleImageView.layer.cornerRadius = 0.0;
    }
    self.circleImageView.clipsToBounds = YES;
    self.circleImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.circleImageView.image = image;
    self.circleImageView.tintColor = nil;
    [self setOptionSelected:self.isOptionSelected animated:NO];
}

- (void)pp_applySymbolNamed:(NSString *)imageNamed useSmallIcon:(BOOL)useSmallIcon {
    self.iconStyle = PPOptionCellIconStyleSymbol;
    if (self.isUserOption) {
        self.iconPlateView.layer.cornerRadius = 20.0;
        self.circleImageView.layer.cornerRadius = 20.0;
        self.iconPlateWidthConstraint.constant = 48.0;
        self.iconPlateHeightConstraint.constant = 48.0;
        self.circleImageWidthConstraint.constant = 48.0;
        self.circleImageHeightConstraint.constant = 48.0;
    } else {
        self.iconPlateView.layer.cornerRadius = self.premiumCardStyleEnabled ? 16.0 : 20.0;
        self.circleImageView.layer.cornerRadius = 0.0;
    }
    self.circleImageView.clipsToBounds = self.isUserOption ? YES : NO;
    self.circleImageView.contentMode = self.isUserOption ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;
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
    if (!image) image = [UIImage imageNamed:safeName];
    if (!image) image = [UIImage systemImageNamed:@"tag.fill" withConfiguration:config];
    if (!image) image = [UIImage imageNamed:@"square-layout"];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIColor *)pp_surfaceColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.13 alpha:0.92]
                : [UIColor colorWithWhite:1.00 alpha:0.96];
        }];
    }
    return AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
}

- (UIColor *)pp_accentColor {
    return self.accentColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
}

@end
