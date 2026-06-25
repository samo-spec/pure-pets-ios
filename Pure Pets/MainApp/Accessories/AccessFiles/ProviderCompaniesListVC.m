//
//  ProviderCompaniesListVC.m
//  Pure Pets
//

#import "ProviderCompaniesListVC.h"

#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "ProviderStorefrontProductsVC.h"
#import "UserManager.h"
#import "UserModel.h"
@import FirebaseFunctions;

static NSString *PPProviderCompaniesSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static CGFloat PPProviderCompaniesBottomNavigationClearanceForController(UIViewController *controller)
{
    if (!controller || !controller.tabBarController || CGRectIsEmpty(controller.view.bounds)) {
        return 0.0;
    }

    UITabBarController *tabBarController = controller.tabBarController;
    if (PPIOS26()) {
        SEL clearanceSelector = NSSelectorFromString(@"pp_bottomNavigationContentClearance");
        if ([tabBarController respondsToSelector:clearanceSelector]) {
            CGFloat (*clearanceIMP)(id, SEL) = (CGFloat (*)(id, SEL))[tabBarController methodForSelector:clearanceSelector];
            CGFloat rootClearance = clearanceIMP ? clearanceIMP(tabBarController, clearanceSelector) : 0.0;
            if (rootClearance > 0.0) {
                return ceil(rootClearance);
            }
        }
    }

    UIView *bottomNavigationView = nil;
    SEL anchorSelector = NSSelectorFromString(@"pp_novaAmbientBottomNavigationAnchorView");
    if ([tabBarController respondsToSelector:anchorSelector]) {
        UIView *(*anchorIMP)(id, SEL) = (UIView *(*)(id, SEL))[tabBarController methodForSelector:anchorSelector];
        bottomNavigationView = anchorIMP ? anchorIMP(tabBarController, anchorSelector) : nil;
    }
    if (!bottomNavigationView && !tabBarController.tabBar.hidden && tabBarController.tabBar.alpha > 0.01) {
        bottomNavigationView = tabBarController.tabBar;
    }
    if (!bottomNavigationView ||
        bottomNavigationView.hidden ||
        bottomNavigationView.alpha <= 0.01 ||
        !bottomNavigationView.superview) {
        return 0.0;
    }

    CGRect navigationFrame = [bottomNavigationView.superview convertRect:bottomNavigationView.frame
                                                                  toView:controller.view];
    if (CGRectIsEmpty(navigationFrame)) {
        return 0.0;
    }

    CGFloat safeBottomY = CGRectGetMaxY(controller.view.bounds) - controller.view.safeAreaInsets.bottom;
    CGFloat overlapAboveSafeArea = MAX(0.0, safeBottomY - CGRectGetMinY(navigationFrame));
    return ceil(overlapAboveSafeArea + 12.0);
}

static UIColor *PPProviderCompaniesDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIColor *PPProviderCompaniesHeroSurfaceColor(void)
{
    return PPProviderCompaniesDynamicColor([UIColor colorWithWhite:1.0 alpha:0.92],
                                           [UIColor colorWithWhite:0.10 alpha:0.94]);
}

static UIColor *PPProviderCompaniesHeroStrokeColor(void)
{
    return PPProviderCompaniesDynamicColor([UIColor colorWithWhite:0.0 alpha:0.055],
                                           [UIColor colorWithWhite:1.0 alpha:0.10]);
}

static UIColor *PPProviderCompaniesHeroSecondarySurfaceColor(void)
{
    return PPProviderCompaniesDynamicColor([UIColor colorWithWhite:0.965 alpha:0.86],
                                           [UIColor colorWithWhite:1.0 alpha:0.07]);
}

static UIFont *PPProviderCompaniesScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    UIFont *resolvedFont = font ?: [UIFont preferredFontForTextStyle:textStyle];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:resolvedFont];
    }
    return resolvedFont;
}

static void PPProviderCompaniesApplyContinuousCorners(UIView *view, CGFloat radius)
{
    view.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static NSString *PPProviderCompaniesNormalizedIdentifier(NSString *identifier)
{
    return [[PPProviderCompaniesSafeString(identifier)
             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            lowercaseString];
}

static BOOL PPProviderCompaniesIsPharmacyCategory(NSString *identifier)
{
    return [[PPProviderCompaniesNormalizedIdentifier(identifier) lowercaseString] isEqualToString:@"pharmacy"];
}

static NSString *PPProviderCompaniesTitleForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_pharmacies_title") ?: @"Pharmacies";
    }
    return kLang(@"provider_marketplace_title") ?: @"Marketplace";
}

static NSString *PPProviderCompaniesHeroTitleForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return PPProviderCompaniesTitleForCategoryIdentifier(identifier);
    }
    return kLang(@"provider_marketplace_hero_title") ?: @"Carefully chosen essentials";
}

static NSString *PPProviderCompaniesSubtitleForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_pharmacies_subtitle") ?: @"Verified pet medicines from trusted pharmacies.";
    }
    return kLang(@"provider_marketplace_subtitle") ?: @"Trusted providers offering food, accessories, and essentials.";
}

static NSString *PPProviderCompaniesCellSubtitleForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_companies_cell_subtitle_pharmacy") ?: @"Verified medicines and care essentials.";
    }
    return kLang(@"provider_companies_cell_subtitle_marketplace") ?: @"Food, accessories, and daily care.";
}

static NSString *PPProviderCompaniesSectionTitleForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_companies_section_title_pharmacy") ?: @"Approved pharmacies";
    }
    return kLang(@"provider_companies_section_title_marketplace") ?: @"Trusted marketplace providers";
}

static NSString *PPProviderCompaniesCountText(NSInteger count, NSString *identifier)
{
    NSString *format = PPProviderCompaniesIsPharmacyCategory(identifier)
        ? (kLang(@"provider_companies_count_pharmacy_format") ?: @"%ld pharmacies")
        : (kLang(@"provider_companies_count_marketplace_format") ?: @"%ld providers");
    return [NSString stringWithFormat:format, (long)MAX(count, 0)];
}

static NSString *PPProviderCompaniesItemsCountText(NSInteger count, NSString *identifier)
{
    NSString *format = PPProviderCompaniesIsPharmacyCategory(identifier)
        ? (kLang(@"provider_storefront_items_count_pharmacy_format") ?: @"%ld medicines")
        : (kLang(@"provider_storefront_items_count_marketplace_format") ?: @"%ld products");
    return [NSString stringWithFormat:format, (long)MAX(count, 0)];
}

static NSString *PPProviderCompaniesSymbolNameForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return @"cross.case.fill";
    }
    return @"square.grid.2x2.fill";
}

typedef NS_ENUM(NSInteger, PPProviderCompaniesLoadState) {
    PPProviderCompaniesLoadStateIdle = 0,
    PPProviderCompaniesLoadStateLoading,
    PPProviderCompaniesLoadStateLoaded,
    PPProviderCompaniesLoadStateEmpty,
    PPProviderCompaniesLoadStateError,
};

typedef NS_ENUM(NSInteger, PPProviderCompaniesDiscoveryMode) {
    PPProviderCompaniesDiscoveryModeRecommended = 0,
    PPProviderCompaniesDiscoveryModeFeatured,
    PPProviderCompaniesDiscoveryModeTopSellers,
    PPProviderCompaniesDiscoveryModeNewest,
};

static NSString *PPProviderCompaniesDiscoveryTitle(PPProviderCompaniesDiscoveryMode mode)
{
    switch (mode) {
        case PPProviderCompaniesDiscoveryModeFeatured:
            return kLang(@"provider_companies_discovery_featured") ?: @"Featured";
        case PPProviderCompaniesDiscoveryModeTopSellers:
            return kLang(@"provider_companies_discovery_top_sellers") ?: @"Top sellers";
        case PPProviderCompaniesDiscoveryModeNewest:
            return kLang(@"provider_companies_discovery_newest") ?: @"Newest";
        case PPProviderCompaniesDiscoveryModeRecommended:
        default:
            return kLang(@"provider_companies_discovery_recommended") ?: @"Recommended";
    }
}

static NSString *PPProviderCompaniesDiscoverySymbol(PPProviderCompaniesDiscoveryMode mode)
{
    switch (mode) {
        case PPProviderCompaniesDiscoveryModeFeatured:
            return @"checkmark.seal.fill";
        case PPProviderCompaniesDiscoveryModeTopSellers:
            return @"chart.bar.fill";
        case PPProviderCompaniesDiscoveryModeNewest:
            return @"clock.fill";
        case PPProviderCompaniesDiscoveryModeRecommended:
        default:
            return @"sparkles";
    }
}

@interface PPProviderCompanyEntry : NSObject
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, strong) NSArray<PetAccessory *> *items;
@property (nonatomic, strong, nullable) UserModel *user;
@property (nonatomic, assign) NSInteger productCount;
@property (nonatomic, strong, nullable) NSDate *latestCreatedAt;
@end

@implementation PPProviderCompanyEntry
@end

static NSString *PPProviderCompaniesCellDisplaySubtitle(PPProviderCompanyEntry *entry, NSString *identifier)
{
    NSString *about = PPProviderCompaniesSafeString(entry.user.UserAbout);
    NSString *fallback = PPProviderCompaniesCellSubtitleForCategoryIdentifier(identifier);
    if (about.length == 0) {
        return fallback;
    }

    NSString *normalizedAbout =
        [about stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalizedAbout.length == 0) {
        return fallback;
    }

    if ([normalizedAbout localizedCaseInsensitiveContainsString:fallback]) {
        return normalizedAbout;
    }

    return [NSString stringWithFormat:@"%@ • %@", fallback, normalizedAbout];
}

@interface PPProviderCompanyCell : UITableViewCell
- (void)configureWithEntry:(PPProviderCompanyEntry *)entry
        categoryIdentifier:(NSString *)categoryIdentifier;
- (void)pp_runEntranceAnimationWithDelay:(NSTimeInterval)delay;
@end

@implementation PPProviderCompanyCell {
    UIView *_cardView;
    UIView *_topAccentView;
    UIView *_ambientAccentView;
    UIView *_avatarShellView;
    UIView *_avatarHaloView;
    UIView *_avatarStatusDotView;
    UIView *_chevronContainerView;
    UIView *_ratingPillView;
    UIStackView *_badgeStackView;
    UIStackView *_metaStackView;
    UIStackView *_ratingStackView;
    UIImageView *_avatarImageView;
    UIImageView *_metaIconView;
    UIImageView *_ratingStarView;
    PPInsetLabel *_categoryBadgeLabel;
    PPInsetLabel *_statusBadgeLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UILabel *_metaLabel;
    UILabel *_ratingValueLabel;
    UILabel *_ratingCountLabel;
    UIImageView *_chevronView;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = PPProviderCompaniesHeroSurfaceColor();
    PPProviderCompaniesApplyContinuousCorners(_cardView, 28.0);
    _cardView.layer.borderWidth = 1.0;
    _cardView.layer.masksToBounds = NO;
    [_cardView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [_cardView pp_setShadowColor:UIColor.blackColor];
    _cardView.layer.shadowOpacity = 0.060;
    _cardView.layer.shadowRadius = 24.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.contentView addSubview:_cardView];

    _ambientAccentView = [[UIView alloc] init];
    _ambientAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    _ambientAccentView.userInteractionEnabled = NO;
    _ambientAccentView.alpha = 0.72;
    [_cardView addSubview:_ambientAccentView];

    _topAccentView = [[UIView alloc] init];
    _topAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    _topAccentView.userInteractionEnabled = NO;
    PPProviderCompaniesApplyContinuousCorners(_topAccentView, 2.0);
    [_cardView addSubview:_topAccentView];

    _avatarHaloView = [[UIView alloc] init];
    _avatarHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarHaloView.userInteractionEnabled = NO;
    _avatarHaloView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    [_cardView addSubview:_avatarHaloView];

    _avatarShellView = [[UIView alloc] init];
    _avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarShellView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    PPProviderCompaniesApplyContinuousCorners(_avatarShellView, 34.0);
    _avatarShellView.layer.masksToBounds = YES;
    _avatarShellView.layer.borderWidth = 1.0;
    [_avatarShellView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [_cardView addSubview:_avatarShellView];

    _avatarImageView = [[UIImageView alloc] init];
    _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    PPProviderCompaniesApplyContinuousCorners(_avatarImageView, 27.0);
    _avatarImageView.layer.masksToBounds = YES;
    _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    [_avatarShellView addSubview:_avatarImageView];

    _avatarStatusDotView = [[UIView alloc] init];
    _avatarStatusDotView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarStatusDotView.layer.borderWidth = 2.5;
    _avatarStatusDotView.layer.masksToBounds = YES;
    [_avatarStatusDotView pp_setBorderColor:PPProviderCompaniesHeroSurfaceColor()];
    [_cardView addSubview:_avatarStatusDotView];

    _badgeStackView = [[UIStackView alloc] init];
    _badgeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeStackView.axis = UILayoutConstraintAxisHorizontal;
    _badgeStackView.alignment = UIStackViewAlignmentCenter;
    _badgeStackView.distribution = UIStackViewDistributionFill;
    _badgeStackView.spacing = 8.0;
    _badgeStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_cardView addSubview:_badgeStackView];

    _statusBadgeLabel = [self pp_badgeLabel];
    [_badgeStackView addArrangedSubview:_statusBadgeLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:19.5],
                                                     UIFontTextStyleHeadline);
    _titleLabel.textColor = AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0];
    _titleLabel.numberOfLines = 2;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:13.5], UIFontTextStyleSubheadline);
    _subtitleLabel.textColor = AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_subtitleLabel];

    _metaStackView = [[UIStackView alloc] init];
    _metaStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _metaStackView.axis = UILayoutConstraintAxisHorizontal;
    _metaStackView.alignment = UIStackViewAlignmentCenter;
    _metaStackView.distribution = UIStackViewDistributionFill;
    _metaStackView.spacing = 5.0;
    _metaStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _metaStackView.layoutMargins = UIEdgeInsetsMake(3.0, 8.0, 3.0, 8.0);
    _metaStackView.layoutMarginsRelativeArrangement = YES;
    _metaStackView.layer.borderWidth = 0.25;
    _metaStackView.layer.masksToBounds = YES;
    PPProviderCompaniesApplyContinuousCorners(_metaStackView, 14.0);
    [_cardView addSubview:_metaStackView];

    _metaIconView = [[UIImageView alloc] init];
    _metaIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _metaIconView.contentMode = UIViewContentModeScaleAspectFit;
    _metaIconView.tintColor = [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.46];
    [_metaStackView addArrangedSubview:_metaIconView];

    _metaLabel = [[UILabel alloc] init];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:12.5], UIFontTextStyleCaption1);
    _metaLabel.textColor = [AppPrimaryTextClr ?: [UIColor colorWithWhite:0.12 alpha:1.0] colorWithAlphaComponent:0.66];
    _metaLabel.numberOfLines = 1;
    _metaLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _metaLabel.adjustsFontSizeToFitWidth = YES;
    _metaLabel.minimumScaleFactor = 0.84;
    _metaLabel.adjustsFontForContentSizeCategory = YES;
    _metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_metaLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [_metaLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                  forAxis:UILayoutConstraintAxisHorizontal];
    [_metaStackView addArrangedSubview:_metaLabel];

    _ratingPillView = [[UIView alloc] init];
    _ratingPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingPillView.isAccessibilityElement = YES;
    _ratingPillView.accessibilityTraits = UIAccessibilityTraitStaticText;
    _ratingPillView.layer.borderWidth = 0.65;
    _ratingPillView.layer.masksToBounds = YES;
    PPProviderCompaniesApplyContinuousCorners(_ratingPillView, 13.0);
    [_badgeStackView addArrangedSubview:_ratingPillView];
    [_ratingPillView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [_ratingPillView setContentHuggingPriority:UILayoutPriorityRequired
                                       forAxis:UILayoutConstraintAxisHorizontal];

    _ratingStarView = [[UIImageView alloc] init];
    _ratingStarView.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingStarView.contentMode = UIViewContentModeScaleAspectFit;
    [_ratingPillView addSubview:_ratingStarView];

    _ratingValueLabel = [[UILabel alloc] init];
    _ratingValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingValueLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:12.0], UIFontTextStyleCaption1);
    _ratingValueLabel.adjustsFontForContentSizeCategory = YES;
    _ratingValueLabel.textAlignment = NSTextAlignmentCenter;

    _ratingCountLabel = [[UILabel alloc] init];
    _ratingCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingCountLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:10.5], UIFontTextStyleCaption2);
    _ratingCountLabel.adjustsFontForContentSizeCategory = YES;
    _ratingCountLabel.textAlignment = NSTextAlignmentCenter;

    _ratingStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        _ratingStarView,
        _ratingValueLabel,
        _ratingCountLabel
    ]];
    _ratingStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingStackView.axis = UILayoutConstraintAxisHorizontal;
    _ratingStackView.alignment = UIStackViewAlignmentCenter;
    _ratingStackView.spacing = 4.0;
    _ratingStackView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [_ratingPillView addSubview:_ratingStackView];

    _chevronContainerView = [[UIView alloc] init];
    _chevronContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronContainerView.layer.masksToBounds = YES;
    _chevronContainerView.layer.borderWidth = 1.0;
    [_chevronContainerView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    _chevronContainerView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    [_cardView addSubview:_chevronContainerView];

    _chevronView = [[UIImageView alloc] init];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        NSString *chevronName = Language.isRTL ? @"arrow.left" : @"arrow.right";
        _chevronView.image = [[UIImage systemImageNamed:chevronName
                                      withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                weight:UIImageSymbolWeightBold]]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _chevronView.tintColor = [AppPrimaryTextClr ?: [UIColor colorWithWhite:0.12 alpha:1.0] colorWithAlphaComponent:0.54];
    [_chevronContainerView addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7.0],

        [_ambientAccentView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16.0],
        [_ambientAccentView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:18.0],
        [_ambientAccentView.widthAnchor constraintEqualToConstant:78.0],
        [_ambientAccentView.heightAnchor constraintEqualToConstant:78.0],

        [_topAccentView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [_topAccentView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:28.0],
        [_topAccentView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-28.0],
        [_topAccentView.heightAnchor constraintEqualToConstant:3.0],

        [_avatarHaloView.centerXAnchor constraintEqualToAnchor:_avatarShellView.centerXAnchor],
        [_avatarHaloView.centerYAnchor constraintEqualToAnchor:_avatarShellView.centerYAnchor],
        [_avatarHaloView.widthAnchor constraintEqualToConstant:78.0],
        [_avatarHaloView.heightAnchor constraintEqualToConstant:78.0],

        [_avatarShellView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:17.0],
        [_avatarShellView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:18.0],
        [_avatarShellView.widthAnchor constraintEqualToConstant:64.0],
        [_avatarShellView.heightAnchor constraintEqualToConstant:64.0],

        [_avatarImageView.centerXAnchor constraintEqualToAnchor:_avatarShellView.centerXAnchor],
        [_avatarImageView.centerYAnchor constraintEqualToAnchor:_avatarShellView.centerYAnchor],
        [_avatarImageView.widthAnchor constraintEqualToConstant:52.0],
        [_avatarImageView.heightAnchor constraintEqualToConstant:52.0],

        [_avatarStatusDotView.trailingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:-2.0],
        [_avatarStatusDotView.bottomAnchor constraintEqualToAnchor:_avatarShellView.bottomAnchor constant:-2.0],
        [_avatarStatusDotView.widthAnchor constraintEqualToConstant:15.0],
        [_avatarStatusDotView.heightAnchor constraintEqualToConstant:15.0],

        [_badgeStackView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:15.0],
        [_badgeStackView.leadingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:14.0],
        [_badgeStackView.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronContainerView.leadingAnchor constant:-12.0],
        [_badgeStackView.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [_statusBadgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],
        [_ratingPillView.heightAnchor constraintEqualToConstant:26.0],
        [_ratingPillView.widthAnchor constraintGreaterThanOrEqualToConstant:66.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_badgeStackView.bottomAnchor constant:8.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_badgeStackView.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_chevronContainerView.leadingAnchor constant:-12.0],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_metaStackView.topAnchor constraintEqualToAnchor:_avatarShellView.bottomAnchor constant:8.0],
        [_metaStackView.centerXAnchor constraintEqualToAnchor:_avatarShellView.centerXAnchor],
        [_metaStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:_cardView.leadingAnchor constant:11.0],
        [_metaStackView.widthAnchor constraintLessThanOrEqualToConstant:92.0],
        [_metaStackView.heightAnchor constraintEqualToConstant:28.0],
        [_metaStackView.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-14.0],

        [_metaIconView.widthAnchor constraintEqualToConstant:12.5],
        [_metaIconView.heightAnchor constraintEqualToConstant:12.5],

        [_ratingStarView.widthAnchor constraintEqualToConstant:13.0],
        [_ratingStarView.heightAnchor constraintEqualToConstant:13.0],
        [_ratingStackView.topAnchor constraintEqualToAnchor:_ratingPillView.topAnchor constant:4.0],
        [_ratingStackView.leadingAnchor constraintEqualToAnchor:_ratingPillView.leadingAnchor constant:9.0],
        [_ratingStackView.trailingAnchor constraintEqualToAnchor:_ratingPillView.trailingAnchor constant:-9.0],
        [_ratingStackView.bottomAnchor constraintEqualToAnchor:_ratingPillView.bottomAnchor constant:-4.0],

        [_chevronContainerView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-17.0],
        [_chevronContainerView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_chevronContainerView.widthAnchor constraintEqualToConstant:34.0],
        [_chevronContainerView.heightAnchor constraintEqualToConstant:34.0],

        [_chevronView.centerXAnchor constraintEqualToAnchor:_chevronContainerView.centerXAnchor],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_chevronContainerView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:14.0],
        [_chevronView.heightAnchor constraintEqualToConstant:14.0]
    ]];
}

- (PPInsetLabel *)pp_badgeLabel
{
    PPInsetLabel *label = [[PPInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.5], UIFontTextStyleCaption1);
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = NSTextAlignmentCenter;
    PPProviderCompaniesApplyContinuousCorners(label, 14.0);
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 1.0;
    label.contentMode = UIViewContentModeCenter;
    label.textInsets = UIEdgeInsetsMake(3.0, 11.0, 3.0, 11.0);
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    return label;
}

- (void)configureWithEntry:(PPProviderCompanyEntry *)entry
        categoryIdentifier:(NSString *)categoryIdentifier
{
    NSString *title = [PPProviderCompaniesSafeString([entry.user bestDisplayName]) copy];
    if (title.length == 0) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (entry.user.FirstName.length > 0) [parts addObject:entry.user.FirstName];
        if (entry.user.LastName.length > 0) [parts addObject:entry.user.LastName];
        title = parts.count > 0 ? [parts componentsJoinedByString:@" "] : PPProviderCompaniesSafeString(entry.user.UserName);
    }
    if (title.length == 0) {
        title = PPProviderCompaniesTitleForCategoryIdentifier(categoryIdentifier);
    }

    UIColor *accent = AppPrimaryClr ?: [UIColor colorWithRed:0.84 green:0.25 blue:0.22 alpha:1.0];
    _ambientAccentView.backgroundColor = [accent colorWithAlphaComponent:0.060];
    _ambientAccentView.layer.shadowColor = accent.CGColor;
    _ambientAccentView.layer.shadowOpacity = 0.080;
    _ambientAccentView.layer.shadowRadius = 18.0;
    _ambientAccentView.layer.shadowOffset = CGSizeZero;
    _topAccentView.backgroundColor = [accent colorWithAlphaComponent:0.38];
    _avatarHaloView.backgroundColor = [accent colorWithAlphaComponent:0.035];
    [_avatarShellView pp_setBorderColor:[accent colorWithAlphaComponent:0.16]];
    _chevronContainerView.backgroundColor = [accent colorWithAlphaComponent:0.055];

    BOOL showVerified = entry.user.isVerified;
    BOOL showActive = !showVerified && [PPProviderCompaniesSafeString(entry.user.accountStatus) isEqualToString:@"active"];
    _statusBadgeLabel.hidden = !showVerified && !showActive;
    _avatarStatusDotView.hidden = !showVerified && !showActive;
    if (showVerified || showActive) {
        NSString *statusText = showVerified
            ? (kLang(@"verified") ?: @"Verified")
            : (kLang(@"provider_company_status_active") ?: @"Active");
        UIColor *statusColor = showVerified ? [UIColor colorWithRed:0.14 green:0.52 blue:0.34 alpha:1.0] : accent;
        _statusBadgeLabel.text = statusText;
        _statusBadgeLabel.textColor = statusColor;
        _statusBadgeLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.075];
        [_statusBadgeLabel pp_setBorderColor:[statusColor colorWithAlphaComponent:0.14]];
        _avatarStatusDotView.backgroundColor = statusColor;
    } else {
        _statusBadgeLabel.text = nil;
    }

    _titleLabel.text = title;
    _subtitleLabel.text = PPProviderCompaniesCellDisplaySubtitle(entry, categoryIdentifier);
    _metaLabel.text = PPProviderCompaniesItemsCountText(entry.productCount, categoryIdentifier);
    if (@available(iOS 13.0, *)) {
        NSString *metaSymbolName = PPProviderCompaniesSymbolNameForCategoryIdentifier(categoryIdentifier);
        _metaIconView.image = [[UIImage systemImageNamed:metaSymbolName
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12.5
                                                                                                         weight:UIImageSymbolWeightSemibold]]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _metaStackView.backgroundColor = [accent colorWithAlphaComponent:0.070];
    [_metaStackView pp_setBorderColor:[accent colorWithAlphaComponent:0.145]];
    _metaIconView.tintColor = [accent colorWithAlphaComponent:0.72];
    _metaLabel.textColor = accent;

    UIColor *ratingColor = [UIColor colorWithRed:0.76 green:0.54 blue:0.12 alpha:1.0];
    BOOL hasProviderRating = entry.user.providerReviewCount > 0 && entry.user.providerRatingValue > 0.0;
    NSString *ratingSymbolName = hasProviderRating ? @"star.fill" : @"star";
    if (@available(iOS 13.0, *)) {
        _ratingStarView.image =
            [[UIImage systemImageNamed:ratingSymbolName
                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11.5
                                                                                       weight:UIImageSymbolWeightBold]]
             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _ratingStarView.tintColor = ratingColor;
    _ratingPillView.backgroundColor = [ratingColor colorWithAlphaComponent:0.075];
    [_ratingPillView pp_setBorderColor:[ratingColor colorWithAlphaComponent:0.18]];
    _ratingValueLabel.textColor = ratingColor;
    _ratingCountLabel.textColor = [ratingColor colorWithAlphaComponent:0.72];
    if (hasProviderRating) {
        _ratingValueLabel.text = [NSString stringWithFormat:@"%.1f", entry.user.providerRatingValue];
        _ratingCountLabel.hidden = NO;
        _ratingCountLabel.text =
            [NSString stringWithFormat:(kLang(@"provider_rating_compact_count_format") ?: @"(%ld)"),
             (long)entry.user.providerReviewCount];
        _ratingPillView.accessibilityLabel =
            [NSString stringWithFormat:(kLang(@"provider_rating_accessibility_format") ?: @"Rated %.1f out of 5 from %ld reviews"),
             entry.user.providerRatingValue,
             (long)entry.user.providerReviewCount];
    } else {
        _ratingValueLabel.text = kLang(@"provider_rating_new") ?: @"New";
        _ratingCountLabel.hidden = YES;
        _ratingCountLabel.text = nil;
        _ratingPillView.accessibilityLabel =
            kLang(@"provider_rating_no_reviews") ?: @"No provider ratings yet";
    }

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:title size:60.0];
    _avatarImageView.image = placeholder ?: PPSYSImage(@"person.crop.circle.fill");
    NSString *imageURL = PPProviderCompaniesSafeString(entry.user.UserImageUrl.absoluteString);
    if (imageURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_avatarImageView
                                                       url:imageURL
                                               placeholder:_avatarImageView.image
                                                complation:nil];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@, %@",
                               title,
                               PPProviderCompaniesTitleForCategoryIdentifier(categoryIdentifier),
                               _metaLabel.text ?: @"",
                               _ratingPillView.accessibilityLabel ?: @""];
    self.accessibilityHint = kLang(@"a11y_cell_tap_hint") ?: @"Double-tap to view details";
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self setNeedsLayout];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _cardView.transform = CGAffineTransformIdentity;
        _cardView.alpha = highlighted ? 0.92 : 1.0;
        return;
    }

    CGAffineTransform target = highlighted ? CGAffineTransformMakeScale(0.982, 0.982) : CGAffineTransformIdentity;
    CGFloat alpha = highlighted ? 0.94 : 1.0;
    NSTimeInterval duration = highlighted ? 0.09 : 0.24;
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:options
                     animations:^{
        self->_cardView.transform = target;
        self->_cardView.alpha = alpha;
    } completion:nil];
}

- (void)pp_runEntranceAnimationWithDelay:(NSTimeInterval)delay
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _cardView.alpha = 1.0;
        _cardView.transform = CGAffineTransformIdentity;
        return;
    }

    _cardView.alpha = 0.0;
    _cardView.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 10.0), 0.985, 0.985);

    [UIView animateWithDuration:0.34
                          delay:delay
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_cardView.alpha = 1.0;
        self->_cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_cardView.bounds cornerRadius:22.0].CGPath;
    _ambientAccentView.layer.cornerRadius = CGRectGetWidth(_ambientAccentView.bounds) * 0.5;
    _avatarHaloView.layer.cornerRadius = CGRectGetWidth(_avatarHaloView.bounds) * 0.5;
    PPProviderCompaniesApplyContinuousCorners(_avatarShellView, CGRectGetWidth(_avatarShellView.bounds) * 0.5);
    PPProviderCompaniesApplyContinuousCorners(_avatarImageView, CGRectGetWidth(_avatarImageView.bounds) * 0.5);
    PPProviderCompaniesApplyContinuousCorners(_metaStackView, CGRectGetHeight(_metaStackView.bounds) * 0.5);
    _chevronContainerView.layer.cornerRadius = CGRectGetWidth(_chevronContainerView.bounds) * 0.5;
    _avatarStatusDotView.layer.cornerRadius = CGRectGetWidth(_avatarStatusDotView.bounds) * 0.5;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _cardView.transform = CGAffineTransformIdentity;
    _cardView.alpha = 1.0;
    _avatarImageView.image = nil;
    _metaIconView.image = nil;
    _ratingStarView.image = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _metaLabel.text = nil;
    _ratingValueLabel.text = nil;
    _ratingCountLabel.text = nil;
    _ratingCountLabel.hidden = NO;
    _ratingPillView.accessibilityLabel = nil;
    _statusBadgeLabel.text = nil;
    _statusBadgeLabel.hidden = NO;
    _avatarStatusDotView.hidden = NO;
    self.accessibilityHint = nil;
    self.accessibilityLabel = nil;
}

@end

@interface ProviderCompaniesListVC () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerContainerView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroLiquidBorderView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) CAGradientLayer *heroBorderSheenLayer;
@property (nonatomic, strong) UIView *heroGlowView;
@property (nonatomic, strong) UIView *heroOrbView;
@property (nonatomic, strong) UIView *heroIconShellView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) PPInsetLabel *heroCategoryBadgeLabel;
@property (nonatomic, strong) UIStackView *heroTopBadgeStackView;
@property (nonatomic, strong) UIView *heroProofRailView;
@property (nonatomic, strong) UIScrollView *heroDiscoveryScrollView;
@property (nonatomic, strong) UIStackView *heroDiscoveryStackView;
@property (nonatomic, strong) NSArray<UIButton *> *heroDiscoveryButtons;
@property (nonatomic, strong) UIView *heroSeparatorView;
@property (nonatomic, strong) NSLayoutConstraint *heroContainerHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSurfaceTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSurfaceBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailHeightConstraint;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) PPInsetLabel *countBadgeLabel;
@property (nonatomic, strong) UIView *stateContainerView;
@property (nonatomic, strong) UIImageView *stateIconView;
@property (nonatomic, strong) UILabel *stateTitleLabel;
@property (nonatomic, strong) UILabel *stateSubtitleLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIButton *navigationSearchButton;
@property (nonatomic, strong) UIBarButtonItem *navigationSearchBarButtonItem;
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *allEntries;
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *visibleEntries;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) PPProviderCompaniesLoadState loadState;
@property (nonatomic, strong, nullable) NSError *lastLoadError;
@property (nonatomic, assign) BOOL heroEntrancePrepared;
@property (nonatomic, assign) BOOL heroEntranceCompleted;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedCompanyCellKeys;
@property (nonatomic, assign) BOOL searchBarFocused;
@property (nonatomic, assign) BOOL searchBarPresented;
@property (nonatomic, assign) BOOL heroDiscoveryInitialOffsetApplied;
@property (nonatomic, assign) BOOL heroPinnedScrollPositionApplied;
@property (nonatomic, assign) CGFloat heroCollapseProgress;
@property (nonatomic, assign) BOOL heroCollapsed;
@property (nonatomic, assign) PPProviderCompaniesDiscoveryMode selectedDiscoveryMode;
- (UIButton *)pp_makeDiscoveryButtonForMode:(PPProviderCompaniesDiscoveryMode)mode;
- (void)pp_updateDiscoveryButtonAppearances;
- (void)pp_handleDiscoveryButton:(UIButton *)button;
- (void)pp_alignDiscoveryRailForCurrentLanguageIfNeeded;
- (void)pp_updateBottomNavigationInsetsIfNeeded;
- (void)pp_applyHeroCollapseProgress:(CGFloat)progress animated:(BOOL)animated;
- (void)pp_updatePinnedHeroForCurrentScrollPosition;
- (CGFloat)pp_expandedHeroHeight;
- (CGFloat)pp_collapsedHeroHeight;
- (CGFloat)pp_heroCollapseDistance;
- (void)pp_refreshProviderRatingSummaries;
@end

@implementation ProviderCompaniesListVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        _selectedProviderCategoryIdentifier = @"marketplace";
        _allEntries = @[];
        _visibleEntries = @[];
        _searchQuery = @"";
        _animatedCompanyCellKeys = [NSMutableSet set];
        _selectedDiscoveryMode = PPProviderCompaniesDiscoveryModeRecommended;
    }
    return self;
}

- (void)dealloc
{
    [self pp_stopHeroAmbientMotion];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_buildUI];
    [self pp_applyHeaderContent];
    [self pp_prepareHeroEntranceIfNeeded];
    [self loadProviders];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_prepareHeroEntranceIfNeeded];
    if (self.searchBarPresented) {
        [self pp_applyPremiumSearchBarAppearanceFocused:self.searchBarFocused animated:NO];
    } else {
        [self pp_applyNavigationSearchButtonFocused:NO animated:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_runHeroEntranceIfNeeded];
    [self pp_startHeroAmbientMotionIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_stopHeroAmbientMotion];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (!CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        self.heroGradientLayer.frame = self.heroSurfaceView.bounds;
        self.heroGradientLayer.cornerRadius = 32.0;
        self.heroSurfaceView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.heroSurfaceView.bounds cornerRadius:32.0].CGPath;
        PPProviderCompaniesApplyContinuousCorners(self.heroLiquidBorderView, 31.0);
        self.heroBorderSheenLayer.frame = self.heroLiquidBorderView.bounds;
        self.heroBorderSheenLayer.cornerRadius = 31.0;
        PPProviderCompaniesApplyContinuousCorners(self.heroProofRailView, 24.0);
    }

    if (!CGRectIsEmpty(self.heroIconShellView.bounds)) {
        PPProviderCompaniesApplyContinuousCorners(self.heroIconShellView, CGRectGetWidth(self.heroIconShellView.bounds) * 0.5);
        PPProviderCompaniesApplyContinuousCorners(self.heroGlowView, CGRectGetWidth(self.heroGlowView.bounds) * 0.5);
        PPProviderCompaniesApplyContinuousCorners(self.heroOrbView, CGRectGetWidth(self.heroOrbView.bounds) * 0.5);
    }

    [self pp_alignDiscoveryRailForCurrentLanguageIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            return;
        }
    }
    [self pp_applyHeroMaterialPalette];
}

- (void)pp_buildUI
{
    self.view.backgroundColor = AppBageColor() ?: [UIColor colorWithRed:0.982 green:0.976 blue:0.956 alpha:1.0];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.title = PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 132.0;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerClass:PPProviderCompanyCell.class forCellReuseIdentifier:@"PPProviderCompanyCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-22]
    ]];

    [self pp_buildHeader];
    [self pp_buildStateView];
    [self pp_buildSearchController];
}

- (void)pp_updateBottomNavigationInsetsIfNeeded
{
    if (!self.tableView) {
        return;
    }

    CGFloat bottomInset = PPProviderCompaniesBottomNavigationClearanceForController(self);
    CGFloat topInset = [self pp_expandedHeroHeight] + 8.0;
    UIEdgeInsets contentInset = self.tableView.contentInset;
    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;
    if (fabs(contentInset.bottom - bottomInset) < 0.5 &&
        fabs(indicatorInset.bottom - bottomInset) < 0.5 &&
        fabs(contentInset.top - topInset) < 0.5) {
        return;
    }

    contentInset.top = topInset;
    contentInset.bottom = bottomInset;
    indicatorInset.top = [self pp_collapsedHeroHeight] + 10.0;
    indicatorInset.bottom = bottomInset;
    self.tableView.contentInset = contentInset;
    self.tableView.scrollIndicatorInsets = indicatorInset;

    if (!self.heroPinnedScrollPositionApplied) {
        self.heroPinnedScrollPositionApplied = YES;
        [self.tableView setContentOffset:CGPointMake(0.0, -topInset) animated:NO];
    }
}

- (void)pp_buildHeader
{
    self.headerContainerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), [self pp_expandedHeroHeight])];
    self.headerContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerContainerView.backgroundColor = UIColor.clearColor;
    self.headerContainerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.headerContainerView.clipsToBounds = NO;
    [self.view addSubview:self.headerContainerView];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = PPProviderCompaniesHeroSurfaceColor();
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPProviderCompaniesApplyContinuousCorners(self.heroSurfaceView, 32.0);
    self.heroSurfaceView.layer.borderWidth = 0.55;
    self.heroSurfaceView.layer.masksToBounds = NO;
    [self.heroSurfaceView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [self.heroSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.heroSurfaceView.layer.shadowOpacity = 0.035;
    self.heroSurfaceView.layer.shadowRadius = 14.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    [self.headerContainerView addSubview:self.heroSurfaceView];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.heroGradientLayer.locations = @[@0.0, @0.52, @1.0];
    self.heroGradientLayer.masksToBounds = YES;
    [self.heroSurfaceView.layer insertSublayer:self.heroGradientLayer atIndex:0];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    if (@available(iOS 13.0, *)) {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.alpha = 0.54;
    PPProviderCompaniesApplyContinuousCorners(blurView, 32.0);
    blurView.layer.masksToBounds = YES;
    [self.heroSurfaceView addSubview:blurView];

    self.heroLiquidBorderView = [[UIView alloc] init];
    self.heroLiquidBorderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroLiquidBorderView.userInteractionEnabled = NO;
    self.heroLiquidBorderView.layer.borderWidth = 0.45;
    self.heroLiquidBorderView.layer.masksToBounds = YES;
    [self.heroLiquidBorderView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.34]];
    [self.heroSurfaceView addSubview:self.heroLiquidBorderView];

    self.heroBorderSheenLayer = [CAGradientLayer layer];
    self.heroBorderSheenLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroBorderSheenLayer.endPoint = CGPointMake(1.0, 1.0);
    self.heroBorderSheenLayer.locations = @[@0.0, @0.44, @1.0];
    self.heroBorderSheenLayer.opacity = 0.16;
    self.heroBorderSheenLayer.masksToBounds = YES;
    [self.heroLiquidBorderView.layer insertSublayer:self.heroBorderSheenLayer atIndex:0];

    self.heroGlowView = [[UIView alloc] init];
    self.heroGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroGlowView.userInteractionEnabled = NO;
    self.heroGlowView.backgroundColor =
        PPProviderCompaniesDynamicColor([UIColor colorWithWhite:0.0 alpha:0.035],
                                        [UIColor colorWithWhite:1.0 alpha:0.055]);
    self.heroGlowView.alpha = 0.26;
    self.heroGlowView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.heroGlowView.layer.shadowOpacity = 0.0;
    self.heroGlowView.layer.shadowRadius = 0.0;
    self.heroGlowView.layer.shadowOffset = CGSizeZero;
    [self.heroSurfaceView addSubview:self.heroGlowView];

    self.heroOrbView = [[UIView alloc] init];
    self.heroOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroOrbView.userInteractionEnabled = NO;
    self.heroOrbView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    self.heroOrbView.layer.borderWidth = 0.55;
    [self.heroOrbView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [self.heroSurfaceView addSubview:self.heroOrbView];

    self.heroIconShellView = [[UIView alloc] init];
    self.heroIconShellView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconShellView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92] ?: PPProviderCompaniesHeroSecondarySurfaceColor();
    self.heroIconShellView.layer.borderWidth = 0.65;
    self.heroIconShellView.layer.masksToBounds = YES;
    [self.heroIconShellView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [self.heroSurfaceView addSubview:self.heroIconShellView];

    self.heroIconView = [[UIImageView alloc] init];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroIconView.tintColor = AppPrimaryClr ?: UIColor.systemRedColor;
    [self.heroIconShellView addSubview:self.heroIconView];

    self.eyebrowLabel = [[UILabel alloc] init];
    self.eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eyebrowLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.5], UIFontTextStyleCaption1);
    self.eyebrowLabel.textColor = [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.58];
    self.eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.eyebrowLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroSurfaceView addSubview:self.eyebrowLabel];

    self.headerTitleLabel = [[UILabel alloc] init];
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.font = PPProviderCompaniesScaledFont([GM BlackFontWithSize:31.0], UIFontTextStyleTitle1);
    self.headerTitleLabel.textColor = AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0];
    self.headerTitleLabel.numberOfLines = 2;
    self.headerTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.heroSurfaceView addSubview:self.headerTitleLabel];

    self.headerSubtitleLabel = [[UILabel alloc] init];
    self.headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerSubtitleLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:14.5], UIFontTextStyleSubheadline);
    self.headerSubtitleLabel.textColor = AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
    self.headerSubtitleLabel.numberOfLines = 2;
    self.headerSubtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.headerSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.heroSurfaceView addSubview:self.headerSubtitleLabel];

    self.heroCategoryBadgeLabel = [[PPInsetLabel alloc] init];
    self.heroCategoryBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCategoryBadgeLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.5], UIFontTextStyleCaption1);
    self.heroCategoryBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.heroCategoryBadgeLabel.adjustsFontForContentSizeCategory = YES;
    self.heroCategoryBadgeLabel.textInsets = UIEdgeInsetsMake(2.0, 12.0, 2.0, 12.0);
    self.heroCategoryBadgeLabel.layer.cornerRadius = 15.0;
    self.heroCategoryBadgeLabel.layer.masksToBounds = YES;
    self.heroCategoryBadgeLabel.layer.borderWidth = 0.55;

    self.countBadgeLabel = [[PPInsetLabel alloc] init];
    self.countBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countBadgeLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.5], UIFontTextStyleCaption1);
    self.countBadgeLabel.textColor = AppPrimaryClr ?: [UIColor colorWithRed:0.84 green:0.25 blue:0.22 alpha:1.0];
    self.countBadgeLabel.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92] ?: PPProviderCompaniesHeroSecondarySurfaceColor();
    self.countBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.countBadgeLabel.textInsets = UIEdgeInsetsMake(2.0, 10.0, 2.0, 10.0);
    PPProviderCompaniesApplyContinuousCorners(self.countBadgeLabel, 15.0);
    self.countBadgeLabel.layer.masksToBounds = YES;
    self.countBadgeLabel.layer.borderWidth = 0.55;

    self.heroTopBadgeStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.heroCategoryBadgeLabel,
        self.countBadgeLabel
    ]];
    self.heroTopBadgeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTopBadgeStackView.axis = UILayoutConstraintAxisHorizontal;
    self.heroTopBadgeStackView.alignment = UIStackViewAlignmentCenter;
    self.heroTopBadgeStackView.distribution = UIStackViewDistributionFill;
    self.heroTopBadgeStackView.spacing = 8.0;
    self.heroTopBadgeStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroSurfaceView addSubview:self.heroTopBadgeStackView];
    [self.heroCategoryBadgeLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                                 forAxis:UILayoutConstraintAxisHorizontal];
    [self.countBadgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                          forAxis:UILayoutConstraintAxisHorizontal];

    self.heroProofRailView = [[UIView alloc] init];
    self.heroProofRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroProofRailView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    self.heroProofRailView.layer.borderWidth = 0.55;
    self.heroProofRailView.layer.masksToBounds = YES;
    [self.heroProofRailView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [self.heroSurfaceView addSubview:self.heroProofRailView];

    self.heroDiscoveryScrollView = [[UIScrollView alloc] init];
    self.heroDiscoveryScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDiscoveryScrollView.backgroundColor = UIColor.clearColor;
    self.heroDiscoveryScrollView.showsHorizontalScrollIndicator = NO;
    self.heroDiscoveryScrollView.alwaysBounceHorizontal = NO;
    self.heroDiscoveryScrollView.directionalLockEnabled = YES;
    self.heroDiscoveryScrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroProofRailView addSubview:self.heroDiscoveryScrollView];

    self.heroDiscoveryStackView = [[UIStackView alloc] init];
    self.heroDiscoveryStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDiscoveryStackView.axis = UILayoutConstraintAxisHorizontal;
    self.heroDiscoveryStackView.alignment = UIStackViewAlignmentCenter;
    self.heroDiscoveryStackView.distribution = UIStackViewDistributionFill;
    self.heroDiscoveryStackView.spacing = 7.0;
    self.heroDiscoveryStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroDiscoveryScrollView addSubview:self.heroDiscoveryStackView];

    NSMutableArray<UIButton *> *discoveryButtons = [NSMutableArray arrayWithCapacity:4];
    for (NSInteger rawMode = PPProviderCompaniesDiscoveryModeRecommended;
         rawMode <= PPProviderCompaniesDiscoveryModeNewest;
         rawMode++) {
        UIButton *button = [self pp_makeDiscoveryButtonForMode:(PPProviderCompaniesDiscoveryMode)rawMode];
        [self.heroDiscoveryStackView addArrangedSubview:button];
        [discoveryButtons addObject:button];
    }
    self.heroDiscoveryButtons = discoveryButtons.copy;

    self.heroSeparatorView = [[UIView alloc] init];
    self.heroSeparatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSeparatorView.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.36];
    PPProviderCompaniesApplyContinuousCorners(self.heroSeparatorView, 1.5);
    self.heroSeparatorView.hidden = YES;
    [self.heroSurfaceView addSubview:self.heroSeparatorView];
    self.eyebrowLabel.hidden = YES;

    self.heroContainerHeightConstraint = [self.headerContainerView.heightAnchor constraintEqualToConstant:[self pp_expandedHeroHeight]];
    self.heroSurfaceTopConstraint = [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.headerContainerView.topAnchor constant:14.0];
    self.heroSurfaceBottomConstraint = [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.headerContainerView.bottomAnchor constant:-14.0];
    self.heroProofRailLeadingConstraint = [self.heroProofRailView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:18.0];
    self.heroProofRailTrailingConstraint = [self.heroProofRailView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0];
    self.heroProofRailBottomConstraint = [self.heroProofRailView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-18.0];
    self.heroProofRailHeightConstraint = [self.heroProofRailView.heightAnchor constraintEqualToConstant:50.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerContainerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.headerContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.headerContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.heroContainerHeightConstraint,

        self.heroSurfaceTopConstraint,
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.headerContainerView.leadingAnchor constant:16.0],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.headerContainerView.trailingAnchor constant:-16.0],
        self.heroSurfaceBottomConstraint,

        [blurView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [self.heroLiquidBorderView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:1.0],
        [self.heroLiquidBorderView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:1.0],
        [self.heroLiquidBorderView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-1.0],
        [self.heroLiquidBorderView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-1.0],

        [self.heroGlowView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.heroGlowView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-20.0],
        [self.heroGlowView.widthAnchor constraintEqualToConstant:116.0],
        [self.heroGlowView.heightAnchor constraintEqualToConstant:116.0],

        [self.heroOrbView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:28.0],
        [self.heroOrbView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-34.0],
        [self.heroOrbView.widthAnchor constraintEqualToConstant:42.0],
        [self.heroOrbView.heightAnchor constraintEqualToConstant:42.0],

        [self.heroIconShellView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:22.0],
        [self.heroIconShellView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-22.0],
        [self.heroIconShellView.widthAnchor constraintEqualToConstant:76.0],
        [self.heroIconShellView.heightAnchor constraintEqualToConstant:76.0],

        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconShellView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconShellView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:31.0],
        [self.heroIconView.heightAnchor constraintEqualToConstant:31.0],

        [self.heroSeparatorView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:24.0],
        [self.heroSeparatorView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:20.0],
        [self.heroSeparatorView.widthAnchor constraintEqualToConstant:3.0],
        [self.heroSeparatorView.heightAnchor constraintEqualToConstant:46.0],

        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:22.0],
        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroSeparatorView.trailingAnchor constant:12.0],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconShellView.leadingAnchor constant:-16.0],

        [self.headerTitleLabel.topAnchor constraintEqualToAnchor:self.heroTopBadgeStackView.bottomAnchor constant:14.0],
        [self.headerTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.headerTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconShellView.leadingAnchor constant:-18.0],

        [self.headerSubtitleLabel.topAnchor constraintEqualToAnchor:self.headerTitleLabel.bottomAnchor constant:8.0],
        [self.headerSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.headerTitleLabel.leadingAnchor],
        [self.headerSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.headerTitleLabel.trailingAnchor],
        [self.headerSubtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.heroProofRailView.topAnchor constant:-16.0],

        [self.heroTopBadgeStackView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.heroTopBadgeStackView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.heroTopBadgeStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconShellView.leadingAnchor constant:-16.0],
        [self.heroTopBadgeStackView.heightAnchor constraintGreaterThanOrEqualToConstant:30.0],

        [self.heroCategoryBadgeLabel.heightAnchor constraintEqualToConstant:30.0],
        [self.countBadgeLabel.heightAnchor constraintEqualToConstant:30.0],

        self.heroProofRailLeadingConstraint,
        self.heroProofRailTrailingConstraint,
        self.heroProofRailBottomConstraint,
        self.heroProofRailHeightConstraint,

        [self.heroDiscoveryScrollView.topAnchor constraintEqualToAnchor:self.heroProofRailView.topAnchor constant:5.0],
        [self.heroDiscoveryScrollView.leadingAnchor constraintEqualToAnchor:self.heroProofRailView.leadingAnchor constant:5.0],
        [self.heroDiscoveryScrollView.trailingAnchor constraintEqualToAnchor:self.heroProofRailView.trailingAnchor constant:-5.0],
        [self.heroDiscoveryScrollView.bottomAnchor constraintEqualToAnchor:self.heroProofRailView.bottomAnchor constant:-5.0],

        [self.heroDiscoveryStackView.topAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.topAnchor],
        [self.heroDiscoveryStackView.leadingAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.leadingAnchor],
        [self.heroDiscoveryStackView.trailingAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.trailingAnchor],
        [self.heroDiscoveryStackView.bottomAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.bottomAnchor],
        [self.heroDiscoveryStackView.heightAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.frameLayoutGuide.heightAnchor],
        [self.heroDiscoveryStackView.widthAnchor constraintGreaterThanOrEqualToAnchor:self.heroDiscoveryScrollView.frameLayoutGuide.widthAnchor],
    ]];

    [self pp_updateDiscoveryButtonAppearances];
    [self pp_applyHeroMaterialPalette];
    [self pp_applyHeroCollapseProgress:0.0 animated:NO];
}

- (void)pp_alignDiscoveryRailForCurrentLanguageIfNeeded
{
    if (self.heroDiscoveryInitialOffsetApplied || !self.heroDiscoveryScrollView) {
        return;
    }

    [self.heroDiscoveryScrollView layoutIfNeeded];
    [self.heroDiscoveryStackView layoutIfNeeded];

    CGFloat visibleWidth = CGRectGetWidth(self.heroDiscoveryScrollView.bounds);
    CGFloat contentWidth = MAX(self.heroDiscoveryScrollView.contentSize.width,
                               CGRectGetMaxX(self.heroDiscoveryStackView.frame));
    if (visibleWidth <= 1.0 || contentWidth <= 1.0) {
        return;
    }

    UIEdgeInsets adjustedInsets = self.heroDiscoveryScrollView.contentInset;
    if (@available(iOS 11.0, *)) {
        adjustedInsets = self.heroDiscoveryScrollView.adjustedContentInset;
    }

    self.heroDiscoveryInitialOffsetApplied = YES;
    CGFloat maxOffsetX = MAX(-adjustedInsets.left, contentWidth - visibleWidth + adjustedInsets.right);
    CGFloat offsetX = Language.isRTL ? maxOffsetX : -adjustedInsets.left;
    [self.heroDiscoveryScrollView setContentOffset:CGPointMake(offsetX, -adjustedInsets.top) animated:NO];
}

- (void)pp_applyDiscoveryAppearanceToButton:(UIButton *)button
{
    PPProviderCompaniesDiscoveryMode mode = (PPProviderCompaniesDiscoveryMode)button.tag;
    BOOL selected = (mode == self.selectedDiscoveryMode);
    BOOL highlighted = button.highlighted;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    UIColor *foreground = selected
        ? accent
        : [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.64];
    UIColor *background = selected
        ? [accent colorWithAlphaComponent:(highlighted ? 0.15 : 0.10)]
        : ([AppForgroundColr colorWithAlphaComponent:(highlighted ? 0.86 : 0.64)]
           ?: PPProviderCompaniesHeroSecondarySurfaceColor());
    UIColor *stroke = selected
        ? [accent colorWithAlphaComponent:0.24]
        : [[UIColor whiteColor] colorWithAlphaComponent:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.18 : 0.66)];

    UIFont *discoveryFont = PPProviderCompaniesScaledFont(
        selected ? [GM boldFontWithSize:12.0] : [GM MidFontWithSize:12.0],
        UIFontTextStyleCaption1
    );
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = PPProviderCompaniesDiscoveryTitle(mode);
    configuration.image =
        [[UIImage systemImageNamed:PPProviderCompaniesDiscoverySymbol(mode)
                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11.5
                                                                                   weight:selected ? UIImageSymbolWeightBold : UIImageSymbolWeightSemibold]]
         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = 5.0;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(7.0, 11.0, 7.0, 11.0);
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.baseForegroundColor = foreground;
    configuration.baseBackgroundColor = background;
    configuration.background.backgroundColor = background;
    configuration.background.strokeColor = stroke;
    configuration.background.strokeWidth = selected ? 1.0 : 0.65;
    UIFont *finalDiscoveryFont = discoveryFont;
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
        NSMutableDictionary *attrs = [incoming mutableCopy];
        attrs[NSFontAttributeName] = finalDiscoveryFont;
        return attrs;
    };
    button.configuration = configuration;
    button.layer.shadowColor = accent.CGColor;
    button.layer.shadowOpacity = selected ? 0.10 : 0.0;
    button.layer.shadowRadius = selected ? 8.0 : 0.0;
    button.layer.shadowOffset = selected ? CGSizeMake(0.0, 3.0) : CGSizeZero;
    button.transform = highlighted && !UIAccessibilityIsReduceMotionEnabled()
        ? CGAffineTransformMakeScale(0.975, 0.975)
        : CGAffineTransformIdentity;
    button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
}

- (UIButton *)pp_makeDiscoveryButtonForMode:(PPProviderCompaniesDiscoveryMode)mode
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = mode;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityLabel = PPProviderCompaniesDiscoveryTitle(mode);
    button.accessibilityHint = kLang(@"provider_companies_discovery_hint") ?: @"Changes how providers are shown";
    [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [button.heightAnchor constraintEqualToConstant:40.0].active = YES;
    [button addTarget:self action:@selector(pp_handleDiscoveryButton:) forControlEvents:UIControlEventTouchUpInside];

    __weak typeof(self) weakSelf = self;
    button.configurationUpdateHandler = ^(UIButton *updatedButton) {
        [weakSelf pp_applyDiscoveryAppearanceToButton:updatedButton];
    };
    [self pp_applyDiscoveryAppearanceToButton:button];
    return button;
}

- (void)pp_updateDiscoveryButtonAppearances
{
    for (UIButton *button in self.heroDiscoveryButtons) {
        button.selected = ((PPProviderCompaniesDiscoveryMode)button.tag == self.selectedDiscoveryMode);
        [button setNeedsUpdateConfiguration];
        [self pp_applyDiscoveryAppearanceToButton:button];
    }
}

- (void)pp_handleDiscoveryButton:(UIButton *)button
{
    PPProviderCompaniesDiscoveryMode mode = (PPProviderCompaniesDiscoveryMode)button.tag;
    if (mode == self.selectedDiscoveryMode) {
        return;
    }

    self.selectedDiscoveryMode = mode;
    [self pp_updateDiscoveryButtonAppearances];

    UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
    [feedback prepare];
    [feedback selectionChanged];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_applySearchFilter];
        return;
    }

    [UIView transitionWithView:self.tableView
                      duration:0.24
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionAllowUserInteraction |
                               UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
        [self pp_applySearchFilter];
    } completion:nil];
}

- (void)pp_buildStateView
{
    self.stateContainerView = [[UIView alloc] init];
    self.stateContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateContainerView.hidden = YES;
    [self.view addSubview:self.stateContainerView];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [self.stateContainerView addSubview:stack];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.color = AppPrimaryClr ?: UIColor.systemRedColor;
    [stack addArrangedSubview:self.loadingIndicator];

    self.stateIconView = [[UIImageView alloc] init];
    self.stateIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.stateIconView.tintColor = [AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0] colorWithAlphaComponent:0.72];
    [self.stateIconView.widthAnchor constraintEqualToConstant:42.0].active = YES;
    [self.stateIconView.heightAnchor constraintEqualToConstant:42.0].active = YES;
    [stack addArrangedSubview:self.stateIconView];

    self.stateTitleLabel = [[UILabel alloc] init];
    self.stateTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateTitleLabel.font = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    self.stateTitleLabel.textColor = AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0];
    self.stateTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.stateTitleLabel.numberOfLines = 2;
    [stack addArrangedSubview:self.stateTitleLabel];

    self.stateSubtitleLabel = [[UILabel alloc] init];
    self.stateSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateSubtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.stateSubtitleLabel.textColor = AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
    self.stateSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.stateSubtitleLabel.numberOfLines = 3;
    [stack addArrangedSubview:self.stateSubtitleLabel];

    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.backgroundColor = AppPrimaryClr ?: UIColor.systemRedColor;
    self.retryButton.layer.cornerRadius = 16.0;
    self.retryButton.layer.masksToBounds = YES;
    self.retryButton.titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [self.retryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.retryButton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 18.0, 12.0, 18.0);
    [self.retryButton addTarget:self action:@selector(pp_handleRetryTap) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:self.retryButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.stateContainerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stateContainerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:32.0],
        [self.stateContainerView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [self.stateContainerView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-28.0],

        [stack.topAnchor constraintEqualToAnchor:self.stateContainerView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.stateContainerView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.stateContainerView.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.stateContainerView.bottomAnchor]
    ]];
}

- (void)pp_buildSearchController
{
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.placeholder = kLang(@"provider_companies_search_placeholder") ?: @"Search providers";
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchController.searchBar.tintColor = AppPrimaryClr ?: UIColor.systemRedColor;
    self.searchController.searchBar.barTintColor = UIColor.clearColor;
    self.searchController.searchBar.backgroundImage = [UIImage new];
    self.searchController.searchBar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.searchController = nil;
    self.definesPresentationContext = YES;
    [self pp_applyPremiumSearchBarAppearanceFocused:NO animated:NO];
    [self pp_buildNavigationSearchButton];
}

- (void)pp_buildNavigationSearchButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityLabel = kLang(@"provider_companies_search_placeholder") ?: @"Search providers";
    button.accessibilityTraits = UIAccessibilityTraitButton;
    button.tintColor = AppPrimaryClr ?: UIColor.systemRedColor;
    button.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    button.layer.borderWidth = 1.0;
    button.layer.masksToBounds = NO;
    PPProviderCompaniesApplyContinuousCorners(button, 19.0);
    [button pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.035;
    button.layer.shadowRadius = 9.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    [button addTarget:self action:@selector(pp_handleNavigationSearchTap) forControlEvents:UIControlEventTouchUpInside];

    if (@available(iOS 13.0, *)) {
        UIImage *image = [[UIImage systemImageNamed:@"magnifyingglass"
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                                    weight:UIImageSymbolWeightSemibold]]
                          imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [button setImage:image forState:UIControlStateNormal];
    } else {
        [button setTitle:(kLang(@"provider_companies_search_placeholder") ?: @"Search") forState:UIControlStateNormal];
        button.titleLabel.font = [GM boldFontWithSize:10.0] ?: [UIFont boldSystemFontOfSize:10.0];
    }

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:38.0],
        [button.heightAnchor constraintEqualToConstant:38.0]
    ]];

    self.navigationSearchButton = button;
    self.navigationSearchBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItem = self.navigationSearchBarButtonItem;
    [self pp_applyNavigationSearchButtonFocused:NO animated:NO];
}

- (void)pp_applyNavigationSearchButtonFocused:(BOOL)focused animated:(BOOL)animated
{
    UIButton *button = self.navigationSearchButton;
    if (!button) {
        return;
    }

    void (^applyBlock)(void) = ^{
        UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
        button.tintColor = accent;
        button.backgroundColor = focused ? [accent colorWithAlphaComponent:0.10] : PPProviderCompaniesHeroSecondarySurfaceColor();
        [button pp_setBorderColor:focused ? [accent colorWithAlphaComponent:0.26] : PPProviderCompaniesHeroStrokeColor()];
        button.layer.shadowOpacity = focused ? 0.060 : 0.035;
        button.layer.shadowRadius = focused ? 13.0 : 9.0;
        button.layer.shadowOffset = CGSizeMake(0.0, focused ? 7.0 : 4.0);
        button.transform = focused && !UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformMakeScale(0.94, 0.94)
            : CGAffineTransformIdentity;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        applyBlock();
        return;
    }

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:applyBlock
                     completion:nil];
}

- (void)pp_handleNavigationSearchTap
{
    [self pp_applyNavigationSearchButtonFocused:YES animated:YES];
    [self pp_presentNavigationSearchBar];
}

- (void)pp_presentNavigationSearchBar
{
    if (self.searchBarPresented) {
        self.searchController.active = YES;
        [self.searchController.searchBar becomeFirstResponder];
        return;
    }

    self.searchBarPresented = YES;
    self.searchBarFocused = YES;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    [self pp_applyPremiumSearchBarAppearanceFocused:YES animated:NO];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.searchController.active = YES;
        [self.searchController.searchBar becomeFirstResponder];
        [self pp_applyPremiumSearchBarAppearanceFocused:YES animated:YES];
    });
}

- (void)pp_dismissNavigationSearchBarAndClear:(BOOL)clearQuery
{
    if (clearQuery) {
        self.searchController.searchBar.text = @"";
        self.searchQuery = @"";
        [self pp_applySearchFilter];
    }

    self.searchBarFocused = NO;
    self.searchBarPresented = NO;
    self.searchController.active = NO;
    self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = self.navigationSearchBarButtonItem;
    [self pp_applyNavigationSearchButtonFocused:NO animated:YES];
}

- (void)pp_applyPremiumSearchBarAppearanceFocused:(BOOL)focused animated:(BOOL)animated
{
    UISearchBar *searchBar = self.searchController.searchBar;
    if (!searchBar) {
        return;
    }

    searchBar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    searchBar.tintColor = AppPrimaryClr ?: UIColor.systemRedColor;

    void (^applyBlock)(void) = ^{
        searchBar.transform = focused && !UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformMakeScale(1.012, 1.012)
            : CGAffineTransformIdentity;

        if (@available(iOS 13.0, *)) {
            UITextField *textField = searchBar.searchTextField;
            UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
            UIColor *surfaceColor = focused ? PPProviderCompaniesHeroSurfaceColor() : PPProviderCompaniesHeroSecondarySurfaceColor();
            UIColor *borderColor = focused
                ? [accent colorWithAlphaComponent:0.26]
                : PPProviderCompaniesHeroStrokeColor();

            textField.backgroundColor = surfaceColor;
            textField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
            textField.tintColor = accent;
            textField.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:15.0], UIFontTextStyleSubheadline);
            textField.textAlignment = Language.alignmentForCurrentLanguage;
            textField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
            textField.layer.cornerRadius = 18.0;
            if (@available(iOS 13.0, *)) {
                textField.layer.cornerCurve = kCACornerCurveContinuous;
            }
            textField.layer.masksToBounds = NO;
            textField.layer.borderWidth = focused ? 1.15 : 1.0;
            [textField pp_setBorderColor:borderColor];
            textField.layer.shadowColor = UIColor.blackColor.CGColor;
            textField.layer.shadowOpacity = focused ? 0.065 : 0.028;
            textField.layer.shadowRadius = focused ? 14.0 : 8.0;
            textField.layer.shadowOffset = CGSizeMake(0.0, focused ? 7.0 : 3.0);

            UIImageView *leftIconView = (UIImageView *)textField.leftView;
            if ([leftIconView isKindOfClass:UIImageView.class]) {
                leftIconView.tintColor = focused
                    ? accent
                    : [AppSecondaryTextClr ?: UIColor.secondaryLabelColor colorWithAlphaComponent:0.72];
            }

            textField.attributedPlaceholder =
                [[NSAttributedString alloc] initWithString:(searchBar.placeholder ?: @"")
                                                attributes:@{
                    NSForegroundColorAttributeName: [AppSecondaryTextClr ?: UIColor.secondaryLabelColor colorWithAlphaComponent:(focused ? 0.74 : 0.62)],
                    NSFontAttributeName: PPProviderCompaniesScaledFont([GM MidFontWithSize:15.0], UIFontTextStyleSubheadline)
                }];
        }
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        applyBlock();
        return;
    }

    [UIView animateWithDuration:focused ? 0.20 : 0.24
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:applyBlock
                     completion:nil];
}

- (void)pp_prepareHeroEntranceIfNeeded
{
    if (self.heroEntranceCompleted || self.heroEntrancePrepared || !self.heroSurfaceView) {
        return;
    }

    self.heroEntrancePrepared = YES;
    self.heroSurfaceView.alpha = 0.0;
    self.heroSurfaceView.transform = CGAffineTransformMakeScale(1.018, 1.018);
    self.heroIconShellView.alpha = 0.0;
    self.heroIconShellView.transform = CGAffineTransformMakeScale(0.94, 0.94);
    self.eyebrowLabel.alpha = 0.0;
    self.eyebrowLabel.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.headerTitleLabel.alpha = 0.0;
    self.headerTitleLabel.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.headerSubtitleLabel.alpha = 0.0;
    self.headerSubtitleLabel.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.heroTopBadgeStackView.alpha = 0.0;
    self.heroTopBadgeStackView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroProofRailView.alpha = 0.0;
    self.heroProofRailView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
}

- (void)pp_runHeroEntranceIfNeeded
{
    if (self.heroEntranceCompleted || !self.heroEntrancePrepared) {
        return;
    }

    self.heroEntranceCompleted = YES;
    [self.view layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in @[self.heroSurfaceView,
                               self.heroIconShellView,
                               self.eyebrowLabel,
                               self.headerTitleLabel,
                               self.headerSubtitleLabel,
                               self.heroTopBadgeStackView,
                               self.heroProofRailView]) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.06
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroIconShellView.alpha = 1.0;
        self.heroIconShellView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:0.10
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.eyebrowLabel.alpha = 1.0;
        self.eyebrowLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.40
                          delay:0.15
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.headerTitleLabel.alpha = 1.0;
        self.headerTitleLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.38
                          delay:0.20
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.headerSubtitleLabel.alpha = 1.0;
        self.headerSubtitleLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.25
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroTopBadgeStackView.alpha = 1.0;
        self.heroTopBadgeStackView.transform = CGAffineTransformIdentity;
        self.heroProofRailView.alpha = 1.0;
        self.heroProofRailView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_startHeroAmbientMotionIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled() || !self.heroEntranceCompleted) {
        return;
    }
    if ([self.heroGlowView.layer animationForKey:@"PPProviderCompaniesHeroBreath"]) {
        return;
    }

    CABasicAnimation *glowBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    glowBreath.fromValue = @(0.58);
    glowBreath.toValue = @(0.92);
    glowBreath.duration = 2.8;
    glowBreath.autoreverses = YES;
    glowBreath.repeatCount = HUGE_VALF;
    glowBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.heroGlowView.layer addAnimation:glowBreath forKey:@"PPProviderCompaniesHeroBreath"];

    CABasicAnimation *iconBreath = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    iconBreath.fromValue = @(1.0);
    iconBreath.toValue = @(1.025);
    iconBreath.duration = 3.2;
    iconBreath.autoreverses = YES;
    iconBreath.repeatCount = HUGE_VALF;
    iconBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.heroIconShellView.layer addAnimation:iconBreath forKey:@"PPProviderCompaniesIconBreath"];
}

- (void)pp_stopHeroAmbientMotion
{
    [self.heroGlowView.layer removeAnimationForKey:@"PPProviderCompaniesHeroBreath"];
    [self.heroIconShellView.layer removeAnimationForKey:@"PPProviderCompaniesIconBreath"];
}

- (CGFloat)pp_expandedHeroHeight
{
    return 308.0;
}

- (CGFloat)pp_collapsedHeroHeight
{
    return 82.0;
}

- (CGFloat)pp_heroCollapseDistance
{
    return MAX(1.0, [self pp_expandedHeroHeight] - [self pp_collapsedHeroHeight] - 36.0);
}

- (void)pp_applyHeroCollapseProgress:(CGFloat)progress animated:(BOOL)animated
{
    progress = MAX(0.0, MIN(1.0, progress));
    _heroCollapseProgress = progress;

    CGFloat expandedHeight = [self pp_expandedHeroHeight];
    CGFloat collapsedHeight = [self pp_collapsedHeroHeight];
    CGFloat currentHeight = expandedHeight + ((collapsedHeight - expandedHeight) * progress);
    CGFloat topInset = 14.0 - (8.0 * progress);
    CGFloat bottomInset = -14.0 + (8.0 * progress);
    CGFloat railSideInset = 18.0 - (4.0 * progress);
    CGFloat railBottomInset = -18.0 + (9.0 * progress);
    CGFloat railHeight = 50.0;
    CGFloat textShift = -22.0 * progress;
    CGFloat badgeShift = -18.0 * progress;
    CGFloat iconShift = -18.0 * progress;
    CGFloat textAlpha = 1.0 - progress;
    CGFloat badgeAlpha = 1.0 - progress;
    CGFloat iconAlpha = 1.0 - progress;
    CGFloat surfaceShadowOpacity = 0.035 - (0.017 * progress);
    CGFloat surfaceShadowRadius = 14.0 - (4.0 * progress);
    CGFloat glowAlpha = 0.26 - (0.18 * progress);

    void (^updates)(void) = ^{
        self.heroContainerHeightConstraint.constant = currentHeight;
        self.heroSurfaceTopConstraint.constant = topInset;
        self.heroSurfaceBottomConstraint.constant = bottomInset;
        self.heroProofRailLeadingConstraint.constant = railSideInset;
        self.heroProofRailTrailingConstraint.constant = -railSideInset;
        self.heroProofRailBottomConstraint.constant = railBottomInset;
        self.heroProofRailHeightConstraint.constant = railHeight;

        self.heroSurfaceView.layer.shadowOpacity = surfaceShadowOpacity;
        self.heroSurfaceView.layer.shadowRadius = surfaceShadowRadius;
        self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 7.0 - (2.0 * progress));
        self.heroGlowView.alpha = glowAlpha;
        self.heroOrbView.alpha = 1.0 - (0.25 * progress);

        self.heroIconShellView.alpha = iconAlpha;
        self.heroIconShellView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, iconShift),
                                                                   CGAffineTransformMakeScale(1.0 - (0.08 * progress),
                                                                                              1.0 - (0.08 * progress)));
        self.heroTopBadgeStackView.alpha = badgeAlpha;
        self.heroTopBadgeStackView.transform = CGAffineTransformMakeTranslation(0.0, badgeShift);

        CGAffineTransform titleTransform = CGAffineTransformMakeTranslation(0.0, textShift);
        self.headerTitleLabel.alpha = textAlpha;
        self.headerTitleLabel.transform = titleTransform;
        self.headerSubtitleLabel.alpha = textAlpha;
        self.headerSubtitleLabel.transform = CGAffineTransformMakeTranslation(0.0, textShift * 0.82);
        self.eyebrowLabel.alpha = textAlpha;
        self.eyebrowLabel.transform = CGAffineTransformMakeTranslation(0.0, textShift * 0.55);

        self.heroProofRailView.alpha = 1.0;
        self.heroProofRailView.transform = CGAffineTransformIdentity;

        [self.view layoutIfNeeded];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
    } else {
        [UIView animateWithDuration:0.32
                              delay:0.0
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.12
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:updates
                         completion:nil];
    }

    BOOL collapsed = (progress >= 0.98);
    if (collapsed != self.heroCollapsed) {
        self.heroCollapsed = collapsed;
        if (!UIAccessibilityIsReduceMotionEnabled()) {
            UIImpactFeedbackGenerator *feedback =
                [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
            [feedback prepare];
            [feedback impactOccurred];
        }
    }
}

- (void)pp_updatePinnedHeroForCurrentScrollPosition
{
    if (!self.tableView || !self.heroContainerHeightConstraint) {
        return;
    }

    CGFloat offsetY = self.tableView.contentOffset.y + self.tableView.contentInset.top;
    CGFloat progress = offsetY / [self pp_heroCollapseDistance];
    [self pp_applyHeroCollapseProgress:progress animated:NO];
}

- (void)pp_applyHeroMaterialPalette
{
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    self.heroGradientLayer.colors = @[
        (__bridge id)[(dark ? [UIColor colorWithWhite:0.13 alpha:1.0] : UIColor.whiteColor) colorWithAlphaComponent:(dark ? 0.18 : 0.26)].CGColor,
        (__bridge id)[[accent colorWithAlphaComponent:(dark ? 0.026 : 0.014)] CGColor],
        (__bridge id)[[UIColor colorWithRed:0.80 green:0.66 blue:0.40 alpha:(dark ? 0.018 : 0.010)] CGColor]
    ];
    self.heroBorderSheenLayer.colors = @[
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.72 : 0.96)].CGColor,
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.46 : 0.76)].CGColor,
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.26 : 0.54)].CGColor
    ];
    [self.heroSurfaceView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.34 : 0.82)]];
    [self.heroLiquidBorderView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.52 : 0.94)]];

    self.heroGlowView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.030 : 0.016)];
    self.heroGlowView.layer.shadowColor = accent.CGColor;
    self.heroGlowView.layer.shadowOpacity = 0.0;
    self.heroGlowView.layer.shadowRadius = 0.0;
    self.heroGlowView.layer.shadowOffset = CGSizeZero;
    self.heroOrbView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.030 : 0.018)];
    [self.heroOrbView pp_setBorderColor:[accent colorWithAlphaComponent:(dark ? 0.070 : 0.045)]];
    self.heroIconShellView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92] ?: PPProviderCompaniesHeroSecondarySurfaceColor();
    [self.heroIconShellView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.34 : 0.74)]];
    self.heroProofRailView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    [self.heroProofRailView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.30 : 0.68)]];
    self.countBadgeLabel.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92] ?: PPProviderCompaniesHeroSecondarySurfaceColor();
    [self.countBadgeLabel pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.30 : 0.68)]];
    [self pp_updateDiscoveryButtonAppearances];
}

- (void)pp_applyHeaderContent
{
    NSString *title = self.selectedProviderCategoryTitleKey.length > 0
        ? (kLang(self.selectedProviderCategoryTitleKey) ?: PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier))
        : PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    NSString *subtitle = self.selectedProviderCategorySubtitleKey.length > 0
        ? (kLang(self.selectedProviderCategorySubtitleKey) ?: PPProviderCompaniesSubtitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier))
        : PPProviderCompaniesSubtitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);

    //self.eyebrowLabel.text = PPProviderCompaniesSectionTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    self.headerTitleLabel.text = PPProviderCompaniesHeroTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    self.headerSubtitleLabel.text = subtitle;
    self.heroCategoryBadgeLabel.text = title;
    self.heroCategoryBadgeLabel.textColor = AppPrimaryClr ?: UIColor.systemRedColor;
    self.heroCategoryBadgeLabel.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.08];
    [self.heroCategoryBadgeLabel pp_setBorderColor:[AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.16]];
    self.countBadgeLabel.text = PPProviderCompaniesCountText(self.visibleEntries.count,
                                                             self.selectedProviderCategoryIdentifier);
    self.countBadgeLabel.textColor = AppPrimaryClr ?: UIColor.systemRedColor;
    self.heroSeparatorView.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.36];
    [self pp_applyHeroMaterialPalette];

    if (@available(iOS 13.0, *)) {
        self.heroIconView.image =  [[UIImage imageNamed:@"pet-shop"]
                                  imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        self.heroIconView.image = [UIImage imageNamed:PPProviderCompaniesSymbolNameForCategoryIdentifier(self.selectedProviderCategoryIdentifier)];
    }
    self.heroIconView.tintColor = AppPrimaryClr ?: UIColor.systemRedColor;

    self.heroSurfaceView.isAccessibilityElement = NO;
    self.countBadgeLabel.accessibilityLabel =
        PPProviderCompaniesCountText(self.visibleEntries.count, self.selectedProviderCategoryIdentifier);
}

- (void)loadProviders
{
    self.lastLoadError = nil;
    [self pp_setLoadState:PPProviderCompaniesLoadStateLoading error:nil];

    __weak typeof(self) weakSelf = self;
    void (^completion)(NSArray<PetAccessory *> *, NSError * _Nullable) = ^(NSArray<PetAccessory *> *accessories, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            [self pp_hydrateEntriesFromAccessories:accessories ?: @[] seedError:error];
        });
    };

    if (PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)) {
        [PetAccessoryManager fetchPublicPharmacyAccessoriesWithCompletion:completion];
    } else {
        [PetAccessoryManager fetchPublicMarketplaceAccessoriesWithCompletion:completion];
    }
}

- (void)pp_hydrateEntriesFromAccessories:(NSArray<PetAccessory *> *)accessories
                               seedError:(NSError * _Nullable)seedError
{
    if (accessories.count == 0) {
        if (seedError) {
            [self pp_setLoadState:PPProviderCompaniesLoadStateError error:seedError];
        } else {
            self.allEntries = @[];
            self.visibleEntries = @[];
            [self pp_setLoadState:PPProviderCompaniesLoadStateEmpty error:nil];
        }
        return;
    }

    NSMutableDictionary<NSString *, NSMutableArray<PetAccessory *> *> *grouped = [NSMutableDictionary dictionary];
    for (PetAccessory *item in accessories) {
        NSString *ownerID = PPProviderCompaniesSafeString(item.ownerID);
        if (ownerID.length == 0) {
            continue;
        }
        NSMutableArray<PetAccessory *> *bucket = grouped[ownerID];
        if (!bucket) {
            bucket = [NSMutableArray array];
            grouped[ownerID] = bucket;
        }
        [bucket addObject:item];
    }

    if (grouped.count == 0) {
        self.allEntries = @[];
        self.visibleEntries = @[];
        [self pp_setLoadState:PPProviderCompaniesLoadStateEmpty error:nil];
        return;
    }

    NSMutableArray<PPProviderCompanyEntry *> *entries = [NSMutableArray arrayWithCapacity:grouped.count];
    [grouped enumerateKeysAndObjectsUsingBlock:^(NSString *ownerID, NSMutableArray<PetAccessory *> *items, BOOL *stop) {
        [items sortUsingComparator:^NSComparisonResult(PetAccessory *lhs, PetAccessory *rhs) {
            NSDate *leftDate = lhs.createdAt ?: NSDate.distantPast;
            NSDate *rightDate = rhs.createdAt ?: NSDate.distantPast;
            return [rightDate compare:leftDate];
        }];

        PPProviderCompanyEntry *entry = [PPProviderCompanyEntry new];
        entry.ownerID = ownerID;
        entry.items = items.copy;
        entry.productCount = items.count;
        entry.latestCreatedAt = items.firstObject.createdAt;
        [entries addObject:entry];
    }];

    dispatch_group_t group = dispatch_group_create();
    __block NSError *profileError = seedError;
    NSString *currentUID = [UserManager sharedManager].currentUser.ID ?: @"";

    for (PPProviderCompanyEntry *entry in entries) {
        dispatch_group_enter(group);

        if (currentUID.length > 0 &&
            [entry.ownerID isEqualToString:currentUID] &&
            [UserManager sharedManager].currentUser) {
            entry.user = [UserManager sharedManager].currentUser;
            dispatch_group_leave(group);
            continue;
        }

        [[UserManager sharedManager] getOtherUserModelFromFirestoreWithUID:entry.ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
            if (user) {
                entry.user = user;
            } else if (error && !profileError) {
                profileError = error;
            }
            dispatch_group_leave(group);
        }];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSPredicate *resolvedPredicate = [NSPredicate predicateWithBlock:^BOOL(PPProviderCompanyEntry *entry, NSDictionary *bindings) {
            return [self pp_displayNameForEntry:entry].length > 0;
        }];
        NSArray<PPProviderCompanyEntry *> *resolvedEntries = [entries filteredArrayUsingPredicate:resolvedPredicate];
        resolvedEntries = [resolvedEntries sortedArrayUsingComparator:^NSComparisonResult(PPProviderCompanyEntry *lhs, PPProviderCompanyEntry *rhs) {
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }

            NSDate *leftDate = lhs.latestCreatedAt ?: NSDate.distantPast;
            NSDate *rightDate = rhs.latestCreatedAt ?: NSDate.distantPast;
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }

            return [[self pp_displayNameForEntry:lhs] localizedCaseInsensitiveCompare:[self pp_displayNameForEntry:rhs]];
        }];

        self.allEntries = resolvedEntries ?: @[];
        [self pp_applySearchFilter];

        if (self.allEntries.count == 0) {
            [self pp_setLoadState:(profileError ? PPProviderCompaniesLoadStateError : PPProviderCompaniesLoadStateEmpty)
                            error:profileError];
        } else {
            [self pp_setLoadState:PPProviderCompaniesLoadStateLoaded error:nil];
            [self pp_refreshProviderRatingSummaries];
        }
    });
}

- (void)pp_refreshProviderRatingSummaries
{
    NSMutableOrderedSet<NSString *> *providerIDs = [NSMutableOrderedSet orderedSet];
    for (PPProviderCompanyEntry *entry in self.allEntries) {
        if (entry.ownerID.length > 0) {
            [providerIDs addObject:entry.ownerID];
        }
    }
    if (providerIDs.count == 0 || ![UserManager sharedManager].isUserLoggedIn) {
        return;
    }

    NSArray<NSString *> *requestedProviderIDs =
        providerIDs.count > 50
            ? [[providerIDs array] subarrayWithRange:NSMakeRange(0, 50)]
            : providerIDs.array;
    FIRHTTPSCallable *callable =
        [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"getProviderReviewSummaries"];
    __weak typeof(self) weakSelf = self;
    [callable callWithObject:@{@"providerIDs": requestedProviderIDs}
                  completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error || ![result.data isKindOfClass:NSDictionary.class]) {
            return;
        }
        NSDictionary *summaries = [(NSDictionary *)result.data objectForKey:@"summaries"];
        if (![summaries isKindOfClass:NSDictionary.class]) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            for (PPProviderCompanyEntry *entry in strongSelf.allEntries) {
                NSDictionary *summary = summaries[entry.ownerID];
                if (![summary isKindOfClass:NSDictionary.class]) {
                    continue;
                }
                entry.user.providerRatingValue =
                    MAX(0.0, MIN(5.0, [summary[@"providerRatingValue"] doubleValue]));
                entry.user.providerReviewCount =
                    MAX(0, [summary[@"providerReviewCount"] integerValue]);
            }
            [strongSelf pp_applySearchFilter];
        });
    }];
}

- (NSString *)pp_displayNameForEntry:(PPProviderCompanyEntry *)entry
{
    if (![entry.user isKindOfClass:UserModel.class]) {
        return @"";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (entry.user.FirstName.length > 0) [parts addObject:entry.user.FirstName];
    if (entry.user.LastName.length > 0) [parts addObject:entry.user.LastName];
    if (parts.count > 0) {
        return [parts componentsJoinedByString:@" "];
    }

    NSString *bestName = PPProviderCompaniesSafeString([entry.user bestDisplayName]);
    if (bestName.length > 0) {
        return bestName;
    }
    bestName = PPProviderCompaniesSafeString([entry.user PPBestDisplayName]);
    if (bestName.length > 0) {
        return bestName;
    }
    return PPProviderCompaniesSafeString(entry.user.UserName);
}

- (NSArray<PPProviderCompanyEntry *> *)pp_sortedEntries:(NSArray<PPProviderCompanyEntry *> *)entries
                                                  mode:(PPProviderCompaniesDiscoveryMode)mode
{
    return [entries sortedArrayUsingComparator:^NSComparisonResult(PPProviderCompanyEntry *lhs,
                                                                    PPProviderCompanyEntry *rhs) {
        BOOL leftVerified = lhs.user.isVerified;
        BOOL rightVerified = rhs.user.isVerified;
        NSDate *leftDate = lhs.latestCreatedAt ?: NSDate.distantPast;
        NSDate *rightDate = rhs.latestCreatedAt ?: NSDate.distantPast;

        if (mode == PPProviderCompaniesDiscoveryModeNewest) {
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
            if (leftVerified != rightVerified) {
                return leftVerified ? NSOrderedAscending : NSOrderedDescending;
            }
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }
        } else if (mode == PPProviderCompaniesDiscoveryModeTopSellers) {
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }
            if (leftVerified != rightVerified) {
                return leftVerified ? NSOrderedAscending : NSOrderedDescending;
            }
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
        } else {
            if (leftVerified != rightVerified) {
                return leftVerified ? NSOrderedAscending : NSOrderedDescending;
            }
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
        }

        return [[self pp_displayNameForEntry:lhs]
            localizedCaseInsensitiveCompare:[self pp_displayNameForEntry:rhs]];
    }];
}

- (void)pp_applySearchFilter
{
    NSArray<PPProviderCompanyEntry *> *candidates = self.allEntries ?: @[];
    NSString *query = PPProviderCompaniesNormalizedIdentifier(self.searchQuery);
    if (query.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PPProviderCompanyEntry *entry, NSDictionary *bindings) {
            NSString *displayName = [[self pp_displayNameForEntry:entry] lowercaseString];
            NSString *about = [PPProviderCompaniesSafeString(entry.user.UserAbout) lowercaseString];
            return [displayName containsString:query] || [about containsString:query];
        }];
        candidates = [candidates filteredArrayUsingPredicate:predicate] ?: @[];
    }

    if (self.selectedDiscoveryMode == PPProviderCompaniesDiscoveryModeFeatured) {
        NSPredicate *featuredPredicate =
            [NSPredicate predicateWithBlock:^BOOL(PPProviderCompanyEntry *entry, NSDictionary *bindings) {
                return entry.user.isVerified;
            }];
        candidates = [candidates filteredArrayUsingPredicate:featuredPredicate] ?: @[];
    }

    self.visibleEntries =
        [self pp_sortedEntries:candidates mode:self.selectedDiscoveryMode] ?: @[];
    [self pp_applyHeaderContent];
    [self.tableView reloadData];

    if (self.loadState == PPProviderCompaniesLoadStateLoaded && self.visibleEntries.count == 0) {
        [self pp_setLoadState:PPProviderCompaniesLoadStateEmpty error:nil];
    } else if (self.loadState == PPProviderCompaniesLoadStateEmpty && self.allEntries.count > 0 && self.visibleEntries.count > 0) {
        [self pp_setLoadState:PPProviderCompaniesLoadStateLoaded error:nil];
    }
}

- (void)pp_setLoadState:(PPProviderCompaniesLoadState)state
                  error:(NSError * _Nullable)error
{
    self.loadState = state;
    self.lastLoadError = error;
    BOOL hasSourceEntries = (self.allEntries.count > 0);
    self.stateContainerView.hidden = (state == PPProviderCompaniesLoadStateLoaded);
    self.tableView.hidden = (state == PPProviderCompaniesLoadStateLoading ||
                             state == PPProviderCompaniesLoadStateError);

    self.stateIconView.hidden = YES;
    self.retryButton.hidden = YES;
    [self.loadingIndicator stopAnimating];

    switch (state) {
        case PPProviderCompaniesLoadStateLoading: {
            self.stateContainerView.hidden = NO;
            self.tableView.hidden = YES;
            [self.loadingIndicator startAnimating];
            self.stateTitleLabel.text = kLang(@"provider_companies_loading_title") ?: @"Loading providers";
            self.stateSubtitleLabel.text = kLang(@"provider_companies_loading_subtitle") ?: @"We’re gathering the latest providers for this category.";
            break;
        }

        case PPProviderCompaniesLoadStateEmpty: {
            self.stateContainerView.hidden = NO;
            self.tableView.hidden = !hasSourceEntries;
            self.stateIconView.hidden = NO;
            BOOL isSearching =
                (PPProviderCompaniesNormalizedIdentifier(self.searchQuery).length > 0 && hasSourceEntries);
            BOOL isFeaturedFiltering =
                (!isSearching &&
                 hasSourceEntries &&
                 self.selectedDiscoveryMode == PPProviderCompaniesDiscoveryModeFeatured);
            if (@available(iOS 13.0, *)) {
                NSString *iconName = isSearching
                    ? @"magnifyingglass"
                    : (isFeaturedFiltering
                       ? @"checkmark.seal"
                       : (PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
                          ? @"cross.case"
                          : @"shippingbox"));
                self.stateIconView.image = [[UIImage systemImageNamed:iconName
                                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:40.0
                                                                                                              weight:UIImageSymbolWeightRegular]]
                                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            if (isSearching) {
                self.stateTitleLabel.text = kLang(@"provider_companies_no_results_title") ?: @"No matching providers";
                self.stateSubtitleLabel.text = kLang(@"provider_companies_no_results_subtitle") ?: @"Try a different name or clear the search.";
            } else if (isFeaturedFiltering) {
                self.stateTitleLabel.text =
                    kLang(@"provider_companies_no_featured_title") ?: @"No featured providers yet";
                self.stateSubtitleLabel.text =
                    kLang(@"provider_companies_no_featured_subtitle") ?: @"Choose another view to see all available providers.";
            } else {
                self.stateTitleLabel.text = PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
                    ? (kLang(@"provider_companies_empty_title_pharmacy") ?: @"No pharmacies yet")
                    : (kLang(@"provider_companies_empty_title_marketplace") ?: @"No providers yet");
                self.stateSubtitleLabel.text = PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
                    ? (kLang(@"provider_companies_empty_subtitle_pharmacy") ?: @"Approved pet medicine providers will appear here once products are available.")
                    : (kLang(@"provider_companies_empty_subtitle_marketplace") ?: @"Trusted marketplace providers will appear here once products are published.");
            }
            break;
        }

        case PPProviderCompaniesLoadStateError: {
            self.stateContainerView.hidden = NO;
            self.tableView.hidden = YES;
            self.stateIconView.hidden = NO;
            self.retryButton.hidden = NO;
            if (@available(iOS 13.0, *)) {
                self.stateIconView.image = [[UIImage systemImageNamed:@"wifi.exclamationmark"
                                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:38.0
                                                                                                              weight:UIImageSymbolWeightRegular]]
                                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            self.stateTitleLabel.text = kLang(@"provider_companies_error_title") ?: @"Couldn’t load providers";
            self.stateSubtitleLabel.text = kLang(@"provider_companies_error_subtitle") ?: @"Check your connection and try again.";
            [self.retryButton setTitle:kLang(@"provider_retry") ?: @"Retry" forState:UIControlStateNormal];
            break;
        }

        case PPProviderCompaniesLoadStateLoaded:
        case PPProviderCompaniesLoadStateIdle:
        default:
            self.stateContainerView.hidden = YES;
            self.tableView.hidden = NO;
            break;
    }

    [self pp_applyHeaderContent];
}

- (void)pp_handleRetryTap
{
    [self loadProviders];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    self.searchBarFocused = YES;
    [self pp_applyPremiumSearchBarAppearanceFocused:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    self.searchBarFocused = NO;
    [self pp_applyPremiumSearchBarAppearanceFocused:NO animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self pp_dismissNavigationSearchBarAndClear:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.visibleEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPProviderCompanyCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderCompanyCell" forIndexPath:indexPath];
    if (indexPath.row < self.visibleEntries.count) {
        [cell configureWithEntry:self.visibleEntries[indexPath.row]
              categoryIdentifier:self.selectedProviderCategoryIdentifier];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.visibleEntries.count) {
        return;
    }

    PPProviderCompanyEntry *entry = self.visibleEntries[indexPath.row];
    ProviderStorefrontProductsVC *storefrontVC =
        [[ProviderStorefrontProductsVC alloc] initWithSeller:entry.user
                                                       items:entry.items
                                          categoryIdentifier:self.selectedProviderCategoryIdentifier];
    storefrontVC.parentVC = self;
    [self.navigationController pushViewController:storefrontVC animated:YES];
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![cell isKindOfClass:PPProviderCompanyCell.class] || indexPath.row >= self.visibleEntries.count) {
        return;
    }

    PPProviderCompanyEntry *entry = self.visibleEntries[indexPath.row];
    NSString *ownerKey = PPProviderCompaniesSafeString(entry.ownerID);
    if (ownerKey.length == 0) {
        ownerKey = [NSString stringWithFormat:@"%@-%ld",
                    PPProviderCompaniesNormalizedIdentifier(self.selectedProviderCategoryIdentifier),
                    (long)indexPath.row];
    }

    if ([self.animatedCompanyCellKeys containsObject:ownerKey]) {
        return;
    }

    [self.animatedCompanyCellKeys addObject:ownerKey];
    NSTimeInterval delay = MIN(indexPath.row, 6) * 0.035;
    [(PPProviderCompanyCell *)cell pp_runEntranceAnimationWithDelay:delay];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.tableView) {
        return;
    }

    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    self.searchQuery = PPProviderCompaniesSafeString(searchController.searchBar.text);
    [self pp_applySearchFilter];
}

@end
