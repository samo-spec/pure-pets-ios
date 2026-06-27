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
#import "PPAddressModel.h"
#import "CitiesManager.h"

#import "PPProviderCompanyPremiumCardCell.h"

#import <QuartzCore/QuartzCore.h>

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
    return PPProviderCompaniesDynamicColor([UIColor colorWithWhite:1.0 alpha:0.99],
                                           [UIColor colorWithWhite:0.15 alpha:0.99]);
}

static UIColor *PPProviderCompaniesHeroStrokeColor(void)
{
    return PPProviderCompaniesDynamicColor([UIColor colorWithWhite:0.0 alpha:0.035],
                                           [UIColor colorWithWhite:1.0 alpha:0.06]);
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
    return kLang(@"provider_companies_title_marketplace") ?: kLang(@"provider_marketplace_title") ?: @"Provider Market";
}

static NSString *PPProviderCompaniesHeroTitleForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return PPProviderCompaniesTitleForCategoryIdentifier(identifier);
    }
    return kLang(@"provider_marketplace_hero_title") ?: @"Trusted providers";
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

static NSString *PPProviderCompaniesHeroEyebrowText(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_companies_hero_eyebrow_pharmacy") ?: @"Pharmacies";
    }
    return kLang(@"provider_companies_hero_eyebrow_marketplace") ?: @"Marketplace";
}

static NSString *PPProviderCompaniesHeroSupportText(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_companies_hero_support_pharmacy") ?: @"Search trusted pharmacies.";
    }
    return kLang(@"provider_companies_hero_support_marketplace") ?: @"Search, compare, open the shop.";
}

static NSString *PPProviderCompaniesHeroModeSummary(PPProviderCompaniesDiscoveryMode mode)
{
    switch (mode) {
        case PPProviderCompaniesDiscoveryModeFeatured:
            return kLang(@"provider_companies_hero_mode_summary_featured") ?: @"Verified providers first";
        case PPProviderCompaniesDiscoveryModeTopSellers:
            return kLang(@"provider_companies_hero_mode_summary_top_sellers") ?: @"Most complete catalogs";
        case PPProviderCompaniesDiscoveryModeNewest:
            return kLang(@"provider_companies_hero_mode_summary_newest") ?: @"Recently added storefronts";
        case PPProviderCompaniesDiscoveryModeRecommended:
        default:
            return kLang(@"provider_companies_hero_mode_summary_recommended") ?: @"Best overall match";
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

    return normalizedAbout;
}

static NSString *PPProviderCompaniesCityForEntry(PPProviderCompanyEntry *entry)
{
    if (![entry.user isKindOfClass:UserModel.class]) {
        return @"";
    }

    for (PPAddressModel *address in [entry.user addresses] ?: @[]) {
        if (![address isKindOfClass:PPAddressModel.class] || address.cityID <= 0) {
            continue;
        }
        NSString *cityName = [CitiesManager.shared cityNameForID:address.cityID];
        if (cityName.length > 0) {
            return cityName;
        }
    }

    return @"";
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
    UIImageView *_avatarVerifiedIconView;
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
    _ambientAccentView.alpha = 0.0;
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
    _avatarShellView.layer.masksToBounds = NO;
    _avatarShellView.layer.borderWidth = 1.0;
    [_avatarShellView pp_setShadowColor:UIColor.blackColor];
    _avatarShellView.layer.shadowOpacity = 0.075;
    _avatarShellView.layer.shadowRadius = 16.0;
    _avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [_avatarShellView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [_cardView addSubview:_avatarShellView];

    _avatarImageView = [[UIImageView alloc] init];
    _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    PPProviderCompaniesApplyContinuousCorners(_avatarImageView, 26.0);
    _avatarImageView.layer.masksToBounds = YES;
    _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    [_avatarShellView addSubview:_avatarImageView];

    _avatarStatusDotView = [[UIView alloc] init];
    _avatarStatusDotView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarStatusDotView.layer.borderWidth = 2.5;
    _avatarStatusDotView.layer.masksToBounds = YES;
    [_avatarStatusDotView pp_setBorderColor:PPProviderCompaniesHeroSurfaceColor()];
    [_cardView addSubview:_avatarStatusDotView];

    _avatarVerifiedIconView = [[UIImageView alloc] init];
    _avatarVerifiedIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarVerifiedIconView.contentMode = UIViewContentModeScaleAspectFit;
    _avatarVerifiedIconView.tintColor = [UIColor colorWithRed:0.14 green:0.52 blue:0.34 alpha:1.0];
    [_avatarStatusDotView addSubview:_avatarVerifiedIconView];

    _badgeStackView = [[UIStackView alloc] init];
    _badgeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeStackView.axis = UILayoutConstraintAxisHorizontal;
    _badgeStackView.alignment = UIStackViewAlignmentCenter;
    _badgeStackView.distribution = UIStackViewDistributionFill;
    _badgeStackView.spacing = 7.0;
    _badgeStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_cardView addSubview:_badgeStackView];

    _statusBadgeLabel = [self pp_badgeLabel];
    [_badgeStackView addArrangedSubview:_statusBadgeLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:19.0],
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
    _metaStackView.spacing = 4.0;
    _metaStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _metaStackView.layoutMargins = UIEdgeInsetsMake(3.0, 7.0, 3.0, 7.0);
    _metaStackView.layoutMarginsRelativeArrangement = YES;
    _metaStackView.layer.borderWidth = 0.25;
    _metaStackView.layer.masksToBounds = YES;
    PPProviderCompaniesApplyContinuousCorners(_metaStackView, 14.0);
    [_badgeStackView addArrangedSubview:_metaStackView];

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
    _chevronContainerView.layer.borderWidth = 0.0;
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
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

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
        [_avatarHaloView.widthAnchor constraintEqualToConstant:74.0],
        [_avatarHaloView.heightAnchor constraintEqualToConstant:74.0],

        [_avatarShellView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16.0],
        [_avatarShellView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16.0],
        [_avatarShellView.widthAnchor constraintEqualToConstant:60.0],
        [_avatarShellView.heightAnchor constraintEqualToConstant:60.0],

        [_avatarImageView.centerXAnchor constraintEqualToAnchor:_avatarShellView.centerXAnchor],
        [_avatarImageView.centerYAnchor constraintEqualToAnchor:_avatarShellView.centerYAnchor],
        [_avatarImageView.widthAnchor constraintEqualToConstant:50.0],
        [_avatarImageView.heightAnchor constraintEqualToConstant:50.0],

        [_avatarStatusDotView.trailingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:-2.0],
        [_avatarStatusDotView.bottomAnchor constraintEqualToAnchor:_avatarShellView.bottomAnchor constant:-2.0],
        [_avatarStatusDotView.widthAnchor constraintEqualToConstant:15.0],
        [_avatarStatusDotView.heightAnchor constraintEqualToConstant:15.0],

        [_avatarVerifiedIconView.centerXAnchor constraintEqualToAnchor:_avatarStatusDotView.centerXAnchor],
        [_avatarVerifiedIconView.centerYAnchor constraintEqualToAnchor:_avatarStatusDotView.centerYAnchor],
        [_avatarVerifiedIconView.widthAnchor constraintEqualToConstant:10.0],
        [_avatarVerifiedIconView.heightAnchor constraintEqualToConstant:10.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_chevronContainerView.leadingAnchor constant:-12.0],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_badgeStackView.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:7.0],
        [_badgeStackView.leadingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:12.0],
        [_badgeStackView.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronContainerView.leadingAnchor constant:-12.0],
        [_badgeStackView.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],

        [_statusBadgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],
        [_ratingPillView.heightAnchor constraintEqualToConstant:25.0],
        [_ratingPillView.widthAnchor constraintGreaterThanOrEqualToConstant:62.0],
        [_metaStackView.heightAnchor constraintEqualToConstant:26.0],
        [_metaStackView.widthAnchor constraintLessThanOrEqualToConstant:104.0],
        [_badgeStackView.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-12.0],

        [_metaIconView.widthAnchor constraintEqualToConstant:12.5],
        [_metaIconView.heightAnchor constraintEqualToConstant:12.5],

        [_ratingStarView.widthAnchor constraintEqualToConstant:13.0],
        [_ratingStarView.heightAnchor constraintEqualToConstant:13.0],
        [_ratingStackView.topAnchor constraintEqualToAnchor:_ratingPillView.topAnchor constant:3.5],
        [_ratingStackView.leadingAnchor constraintEqualToAnchor:_ratingPillView.leadingAnchor constant:8.0],
        [_ratingStackView.trailingAnchor constraintEqualToAnchor:_ratingPillView.trailingAnchor constant:-8.0],
        [_ratingStackView.bottomAnchor constraintEqualToAnchor:_ratingPillView.bottomAnchor constant:-3.5],

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
    label.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.0], UIFontTextStyleCaption1);
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = NSTextAlignmentCenter;
    PPProviderCompaniesApplyContinuousCorners(label, 13.0);
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 1.0;
    label.contentMode = UIViewContentModeCenter;
    label.textInsets = UIEdgeInsetsMake(3.0, 10.0, 3.0, 10.0);
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
    _avatarHaloView.backgroundColor = [accent colorWithAlphaComponent:0.032];
    [_avatarShellView pp_setBorderColor:[accent colorWithAlphaComponent:0.18]];
    _avatarShellView.backgroundColor = PPProviderCompaniesDynamicColor([UIColor colorWithWhite:1.0 alpha:0.82],
                                                                       [UIColor colorWithWhite:1.0 alpha:0.10]);
    _avatarShellView.layer.shadowOpacity = 0.080;
    _avatarShellView.layer.shadowRadius = 16.0;
    _avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    _chevronContainerView.backgroundColor = [accent colorWithAlphaComponent:0.055];

    BOOL showVerified = entry.user.isVerified;
    BOOL showActive = !showVerified && [PPProviderCompaniesSafeString(entry.user.accountStatus) isEqualToString:@"active"];
    _statusBadgeLabel.hidden = YES;
    _avatarStatusDotView.hidden = !showVerified && !showActive;
    if (showVerified) {
        UIColor *verifiedColor = [UIColor colorWithRed:0.14 green:0.52 blue:0.34 alpha:1.0];
        _avatarStatusDotView.backgroundColor = verifiedColor;
        if (@available(iOS 13.0, *)) {
            _avatarVerifiedIconView.image =
                [[UIImage systemImageNamed:@"checkmark.seal.fill"
                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:9.0
                                                                                           weight:UIImageSymbolWeightBold]]
                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        _avatarVerifiedIconView.tintColor = UIColor.whiteColor;
    } else if (showActive) {
        _avatarStatusDotView.backgroundColor = accent;
        _avatarVerifiedIconView.image = nil;
    } else {
        _statusBadgeLabel.text = nil;
        _avatarVerifiedIconView.image = nil;
    }

    _titleLabel.text = title;
    NSString *subtitle = PPProviderCompaniesCellDisplaySubtitle(entry, categoryIdentifier);
    _subtitleLabel.text = subtitle;
    _subtitleLabel.hidden = subtitle.length == 0;
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

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@, %@, %@",
                               title,
                               _subtitleLabel.text ?: @"",
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
    PPProviderCompaniesApplyContinuousCorners(_cardView, 28.0);
    _cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_cardView.bounds cornerRadius:28.0].CGPath;
    _ambientAccentView.layer.cornerRadius = CGRectGetWidth(_ambientAccentView.bounds) * 0.5;
    _avatarHaloView.layer.cornerRadius = CGRectGetWidth(_avatarHaloView.bounds) * 0.5;
    PPProviderCompaniesApplyContinuousCorners(_avatarShellView, CGRectGetWidth(_avatarShellView.bounds) * 0.5);
    PPProviderCompaniesApplyContinuousCorners(_avatarImageView, CGRectGetWidth(_avatarImageView.bounds) * 0.5);
    _avatarShellView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_avatarShellView.bounds
                                                                   cornerRadius:CGRectGetWidth(_avatarShellView.bounds) * 0.5].CGPath;
    PPProviderCompaniesApplyContinuousCorners(_ratingPillView, CGRectGetHeight(_ratingPillView.bounds) * 0.5);
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
    _subtitleLabel.hidden = NO;
    _metaLabel.text = nil;
    _ratingValueLabel.text = nil;
    _ratingCountLabel.text = nil;
    _ratingCountLabel.hidden = NO;
    _ratingPillView.accessibilityLabel = nil;
    _statusBadgeLabel.text = nil;
    _statusBadgeLabel.hidden = YES;
    _avatarStatusDotView.hidden = NO;
    _avatarVerifiedIconView.image = nil;
    self.accessibilityHint = nil;
    self.accessibilityLabel = nil;
}

@end

@interface ProviderCompaniesListVC () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *tableBackgroundMiddleGlowView;
@property (nonatomic, strong) UIView *tableBackgroundBottomGlowView;
@property (nonatomic, strong) CAGradientLayer *tableBackgroundMiddleGlowLayer;
@property (nonatomic, strong) CAGradientLayer *tableBackgroundBottomGlowLayer;
@property (nonatomic, strong) UIView *headerContainerView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIVisualEffectView *heroFrostedMaterialView;
@property (nonatomic, strong) CAGradientLayer *heroSurfaceGradientLayer;
@property (nonatomic, strong) CAShapeLayer *heroSurfaceEdgeHighlightLayer;
@property (nonatomic, strong) UIView *heroAmbientGlowView;
@property (nonatomic, strong) UIView *heroAmbientAccentView;
@property (nonatomic, strong) UIView *heroAmbientSupportView;
@property (nonatomic, strong) UIView *heroContentContainerView;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) PPInsetLabel *heroTitleCountBadgeLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIView *heroTrailIconPlateView;
@property (nonatomic, strong) UIImageView *heroTrailIconView;
@property (nonatomic, strong) UIStackView *heroMetricsStackView;
@property (nonatomic, strong) UIView *heroCountMetricView;
@property (nonatomic, strong) UILabel *heroCountMetricTitleLabel;
@property (nonatomic, strong) UILabel *heroCountMetricValueLabel;
@property (nonatomic, strong) UIView *heroModeMetricView;
@property (nonatomic, strong) UILabel *heroModeMetricTitleLabel;
@property (nonatomic, strong) UILabel *heroModeMetricValueLabel;
@property (nonatomic, strong) UIView *heroTrustMetricView;
@property (nonatomic, strong) UILabel *heroTrustMetricTitleLabel;
@property (nonatomic, strong) UILabel *heroTrustMetricValueLabel;
@property (nonatomic, strong) UIButton *heroLayoutToggleButton;
@property (nonatomic, strong) UIView *heroSearchChromeView;
@property (nonatomic, strong) UIImageView *heroSearchIconView;
@property (nonatomic, strong) UITextField *heroSearchTextField;
@property (nonatomic, strong) UIView *heroProofRailView;
@property (nonatomic, strong) UIScrollView *heroDiscoveryScrollView;
@property (nonatomic, strong) UIStackView *heroDiscoveryStackView;
@property (nonatomic, strong) NSArray<UIButton *> *heroDiscoveryButtons;
@property (nonatomic, strong) NSLayoutConstraint *heroContainerHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSurfaceTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSurfaceBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroContentHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSearchChromeBottomConstraint;

@property (nonatomic, strong) UIView *stateContainerView;
@property (nonatomic, strong) UIImageView *stateIconView;
@property (nonatomic, strong) UILabel *stateTitleLabel;
@property (nonatomic, strong) UILabel *stateSubtitleLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *allEntries;
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *visibleEntries;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) PPProviderCompaniesLoadState loadState;
@property (nonatomic, strong, nullable) NSError *lastLoadError;
@property (nonatomic, assign) BOOL heroEntrancePrepared;
@property (nonatomic, assign) BOOL heroEntranceCompleted;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedCompanyCellKeys;
@property (nonatomic, assign) BOOL searchChromeFocused;
@property (nonatomic, assign) BOOL heroDiscoveryInitialOffsetApplied;
@property (nonatomic, assign) BOOL heroPinnedScrollPositionApplied;
@property (nonatomic, assign) CGFloat heroCollapseProgress;
@property (nonatomic, assign) BOOL heroCollapsed;
@property (nonatomic, assign) BOOL applyingHeroCollapseLayout;
@property (nonatomic, assign) BOOL heroAmbientMotionStarted;
@property (nonatomic, assign) BOOL prefersCompactListLayout;
@property (nonatomic, assign) PPProviderCompaniesDiscoveryMode selectedDiscoveryMode;
- (UIButton *)pp_makeDiscoveryButtonForMode:(PPProviderCompaniesDiscoveryMode)mode;
- (void)pp_updateDiscoveryButtonAppearances;
- (void)pp_handleDiscoveryButton:(UIButton *)button;
- (UIView *)pp_makeHeroMetricViewWithTitleLabel:(UILabel * __strong *)titleLabel
                                     valueLabel:(UILabel * __strong *)valueLabel;
- (void)pp_handleLayoutToggleButton;
- (void)pp_updateLayoutToggleAppearanceAnimated:(BOOL)animated;
- (void)pp_focusHeroSearchTextField;
- (void)pp_alignDiscoveryRailForCurrentLanguageIfNeeded;
- (void)pp_updateBottomNavigationInsetsIfNeeded;
- (void)pp_applyHeroCollapseProgress:(CGFloat)progress animated:(BOOL)animated;
- (void)pp_updatePinnedHeroForCurrentScrollPosition;
- (void)pp_updateHeroSurfaceGeometry;
- (void)pp_hideDecorativeHeroContent;
- (void)pp_handleHeroSearchTextChanged:(UITextField *)textField;
- (CGFloat)pp_expandedHeroHeight;
- (CGFloat)pp_expandedHeroContentHeight;
- (CGFloat)pp_collapsedHeroHeight;
- (CGFloat)pp_heroCollapseDistance;
- (CAGradientLayer *)pp_makeBackgroundGlowLayer;
- (void)pp_applyBackgroundGlowColor:(UIColor *)color
                               view:(UIView *)view
                      gradientLayer:(CAGradientLayer *)gradientLayer
                          peakAlpha:(CGFloat)peakAlpha;
- (void)pp_addHeroAmbientSequenceToView:(UIView *)view
                                  delay:(CFTimeInterval)delay
                                 travel:(CGFloat)travel
                             scaleDelta:(CGFloat)scaleDelta
                           opacityFloor:(CGFloat)opacityFloor
                                    key:(NSString *)key;
- (void)pp_stopHeroAmbientMotion;
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
        _prefersCompactListLayout = NO;
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
    self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self pp_hideDecorativeHeroContent];
    [self pp_applyPremiumSearchChromeAppearanceFocused:self.searchChromeFocused animated:NO];
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

    [self pp_updateHeroSurfaceGeometry];

    [self pp_alignDiscoveryRailForCurrentLanguageIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)pp_updateHeroSurfaceGeometry
{
    if (CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        return;
    }

    CGFloat surfaceRadius = 32.0;
    PPProviderCompaniesApplyContinuousCorners(self.heroSurfaceView, surfaceRadius);
    PPProviderCompaniesApplyContinuousCorners(self.heroFrostedMaterialView, surfaceRadius);
    self.heroFrostedMaterialView.layer.masksToBounds = YES;
    self.heroSurfaceGradientLayer.frame = self.heroSurfaceView.bounds;
    self.heroSurfaceGradientLayer.cornerRadius = surfaceRadius;
    self.heroSurfaceGradientLayer.masksToBounds = YES;

    CGRect highlightBounds = CGRectInset(self.heroSurfaceView.bounds, 0.75, 0.75);
    CGFloat highlightRadius = MAX(0.0, surfaceRadius - 0.75);
    self.heroSurfaceEdgeHighlightLayer.frame = self.heroSurfaceView.bounds;
    self.heroSurfaceEdgeHighlightLayer.path =
        [UIBezierPath bezierPathWithRoundedRect:highlightBounds
                                   cornerRadius:highlightRadius].CGPath;
    self.heroSurfaceEdgeHighlightLayer.fillColor = UIColor.clearColor.CGColor;
    self.heroSurfaceEdgeHighlightLayer.lineWidth = 0.7;
    if (self.heroSurfaceEdgeHighlightLayer.superlayer != self.heroSurfaceView.layer) {
        [self.heroSurfaceView.layer addSublayer:self.heroSurfaceEdgeHighlightLayer];
    }
    self.heroSurfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroSurfaceView.bounds cornerRadius:surfaceRadius].CGPath;
    self.heroAmbientGlowView.layer.cornerRadius = CGRectGetWidth(self.heroAmbientGlowView.bounds) * 0.5;
    self.heroAmbientAccentView.layer.cornerRadius = CGRectGetWidth(self.heroAmbientAccentView.bounds) * 0.5;
    self.heroAmbientSupportView.layer.cornerRadius = CGRectGetWidth(self.heroAmbientSupportView.bounds) * 0.5;
    self.tableBackgroundMiddleGlowView.layer.cornerRadius = CGRectGetWidth(self.tableBackgroundMiddleGlowView.bounds) * 0.5;
    self.tableBackgroundBottomGlowView.layer.cornerRadius = CGRectGetWidth(self.tableBackgroundBottomGlowView.bounds) * 0.5;
    self.tableBackgroundMiddleGlowLayer.frame = self.tableBackgroundMiddleGlowView.bounds;
    self.tableBackgroundMiddleGlowLayer.cornerRadius = CGRectGetWidth(self.tableBackgroundMiddleGlowView.bounds) * 0.5;
    self.tableBackgroundMiddleGlowLayer.masksToBounds = YES;
    self.tableBackgroundBottomGlowLayer.frame = self.tableBackgroundBottomGlowView.bounds;
    self.tableBackgroundBottomGlowLayer.cornerRadius = CGRectGetWidth(self.tableBackgroundBottomGlowView.bounds) * 0.5;
    self.tableBackgroundBottomGlowLayer.masksToBounds = YES;
    self.tableBackgroundMiddleGlowView.layer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:self.tableBackgroundMiddleGlowView.bounds].CGPath;
    self.tableBackgroundBottomGlowView.layer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:self.tableBackgroundBottomGlowView.bounds].CGPath;
    PPProviderCompaniesApplyContinuousCorners(self.heroSearchChromeView, CGRectGetHeight(self.heroSearchChromeView.bounds) * 0.5);
    self.heroSearchChromeView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroSearchChromeView.bounds
                                   cornerRadius:CGRectGetHeight(self.heroSearchChromeView.bounds) * 0.5].CGPath;
    self.heroLayoutToggleButton.layer.cornerRadius = CGRectGetWidth(self.heroLayoutToggleButton.bounds) * 0.5;
    PPProviderCompaniesApplyContinuousCorners(self.heroCountMetricView, 22.0);
    PPProviderCompaniesApplyContinuousCorners(self.heroModeMetricView, 22.0);
    PPProviderCompaniesApplyContinuousCorners(self.heroTrustMetricView, 22.0);
    PPProviderCompaniesApplyContinuousCorners(self.heroProofRailView, CGRectGetHeight(self.heroProofRailView.bounds) * 0.5);
    PPProviderCompaniesApplyContinuousCorners(self.heroTitleCountBadgeLabel,
                                             CGRectGetHeight(self.heroTitleCountBadgeLabel.bounds) * 0.5);
    self.heroTitleCountBadgeLabel.layer.shadowPath = nil;
    PPProviderCompaniesApplyContinuousCorners(self.heroTrailIconPlateView, 18.0);
    self.heroTrailIconPlateView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroTrailIconPlateView.bounds
                                   cornerRadius:18.0].CGPath;
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
    self.view.backgroundColor = AppBackgroundClr ?: [UIColor colorWithRed:0.982 green:0.976 blue:0.956 alpha:1.0];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    //self.title = PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    self.navigationItem.hidesBackButton = YES;
    if (@available(iOS 16.0, *)) {
        self.navigationItem.backBarButtonItem.hidden = YES;
    } else {
        // Fallback on earlier versions
    }

    self.tableBackgroundMiddleGlowView = [[UIView alloc] init];
    self.tableBackgroundMiddleGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableBackgroundMiddleGlowView.userInteractionEnabled = NO;
    self.tableBackgroundMiddleGlowView.clipsToBounds = NO;
    self.tableBackgroundMiddleGlowLayer = [self pp_makeBackgroundGlowLayer];
    [self.tableBackgroundMiddleGlowView.layer insertSublayer:self.tableBackgroundMiddleGlowLayer atIndex:0];
    [self.view addSubview:self.tableBackgroundMiddleGlowView];

    self.tableBackgroundBottomGlowView = [[UIView alloc] init];
    self.tableBackgroundBottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableBackgroundBottomGlowView.userInteractionEnabled = NO;
    self.tableBackgroundBottomGlowView.clipsToBounds = NO;
    self.tableBackgroundBottomGlowLayer = [self pp_makeBackgroundGlowLayer];
    [self.tableBackgroundBottomGlowView.layer insertSublayer:self.tableBackgroundBottomGlowLayer atIndex:0];
    [self.view addSubview:self.tableBackgroundBottomGlowView];

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
    [self.tableView registerClass:PPProviderCompanyPremiumCardCell.class
           forCellReuseIdentifier:PPProviderCompanyPremiumCardCell.reuseIdentifier];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableBackgroundMiddleGlowView.leadingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-60.0],
        [self.tableBackgroundMiddleGlowView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:112.0],
        [self.tableBackgroundMiddleGlowView.widthAnchor constraintEqualToConstant:228.0],
        [self.tableBackgroundMiddleGlowView.heightAnchor constraintEqualToConstant:228.0],

        [self.tableBackgroundBottomGlowView.centerXAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:96.0],
        [self.tableBackgroundBottomGlowView.centerYAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-123.0],
        [self.tableBackgroundBottomGlowView.widthAnchor constraintEqualToConstant:286.0],
        [self.tableBackgroundBottomGlowView.heightAnchor constraintEqualToConstant:286.0],

        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-22]
    ]];

    [self pp_buildHeader];
    [self pp_buildHeroSearchChrome];
    [self pp_buildStateView];
}

- (void)pp_updateBottomNavigationInsetsIfNeeded
{
    if (!self.tableView) {
        return;
    }

    CGFloat bottomInset = PPProviderCompaniesBottomNavigationClearanceForController(self);
    CGFloat topInset = ceil([self pp_expandedHeroHeight] + 8.0);
    UIEdgeInsets contentInset = self.tableView.contentInset;
    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;
    CGFloat previousTopInset = contentInset.top;
    CGFloat previousRelativeOffsetY = self.tableView.contentOffset.y + previousTopInset;
    if (fabs(contentInset.bottom - bottomInset) < 0.5 &&
        fabs(indicatorInset.bottom - bottomInset) < 0.5 &&
        fabs(contentInset.top - topInset) < 0.5) {
        return;
    }

    contentInset.top = topInset;
    contentInset.bottom = bottomInset;
    indicatorInset.top = topInset;
    indicatorInset.bottom = bottomInset;
    self.tableView.contentInset = contentInset;
    self.tableView.scrollIndicatorInsets = indicatorInset;

    if (!self.heroPinnedScrollPositionApplied) {
        self.heroPinnedScrollPositionApplied = YES;
        [self.tableView setContentOffset:CGPointMake(0.0, -topInset) animated:NO];
    } else if (fabs(previousTopInset - topInset) >= 0.5) {
        CGFloat restoredRelativeOffsetY = previousRelativeOffsetY <= 8.0 ? 0.0 : previousRelativeOffsetY;
        CGPoint restoredOffset = self.tableView.contentOffset;
        restoredOffset.y = restoredRelativeOffsetY - topInset;
        if (fabs(restoredOffset.y - self.tableView.contentOffset.y) >= 0.5) {
            [self.tableView setContentOffset:restoredOffset animated:NO];
        }
    }
}

- (void)pp_buildHeader
{
    self.headerContainerView = [[UIView alloc] init];//[PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed];
    self.headerContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerContainerView.backgroundColor = UIColor.clearColor;
    self.headerContainerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.headerContainerView.clipsToBounds = NO;
    [self.view addSubview:self.headerContainerView];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = UIColor.clearColor;
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPProviderCompaniesApplyContinuousCorners(self.heroSurfaceView, 0.0);
    self.heroSurfaceView.layer.borderWidth = 0.75;
    self.heroSurfaceView.layer.masksToBounds = NO;
    [self.heroSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.heroSurfaceView.layer.shadowOpacity = 0.04;
    self.heroSurfaceView.layer.shadowRadius = 20.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [self.headerContainerView addSubview:self.heroSurfaceView];

    self.heroSurfaceGradientLayer = [CAGradientLayer layer];
    self.heroSurfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroSurfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.heroSurfaceGradientLayer.locations = @[@0.0, @0.55, @1.0];
    [self.heroSurfaceView.layer insertSublayer:self.heroSurfaceGradientLayer atIndex:0];

    self.heroSurfaceEdgeHighlightLayer = [CAShapeLayer layer];
    self.heroSurfaceEdgeHighlightLayer.fillColor = UIColor.clearColor.CGColor;
    self.heroSurfaceEdgeHighlightLayer.lineWidth = 0.7;

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    self.heroFrostedMaterialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.heroFrostedMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroFrostedMaterialView.userInteractionEnabled = NO;
    self.heroFrostedMaterialView.clipsToBounds = YES;
    self.heroFrostedMaterialView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroSurfaceView addSubview:self.heroFrostedMaterialView];

    self.heroAmbientGlowView = [[UIView alloc] init];
    self.heroAmbientGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAmbientGlowView.userInteractionEnabled = NO;
    self.heroAmbientGlowView.alpha = 0.0;
    self.heroAmbientGlowView.hidden = YES;
    [self.heroSurfaceView insertSubview:self.heroAmbientGlowView belowSubview:self.heroFrostedMaterialView];

    self.heroAmbientAccentView = [[UIView alloc] init];
    self.heroAmbientAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAmbientAccentView.userInteractionEnabled = NO;
    self.heroAmbientAccentView.alpha = 0.0;
    self.heroAmbientAccentView.hidden = YES;
    [self.heroSurfaceView insertSubview:self.heroAmbientAccentView belowSubview:self.heroFrostedMaterialView];

    self.heroAmbientSupportView = [[UIView alloc] init];
    self.heroAmbientSupportView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAmbientSupportView.userInteractionEnabled = NO;
    self.heroAmbientSupportView.alpha = 0.0;
    self.heroAmbientSupportView.hidden = YES;
    [self.heroSurfaceView insertSubview:self.heroAmbientSupportView belowSubview:self.heroFrostedMaterialView];

    self.heroContentContainerView = [[UIView alloc] init];
    self.heroContentContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContentContainerView.backgroundColor = UIColor.clearColor;
    self.heroContentContainerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroContentContainerView.clipsToBounds = YES;
    [self.heroSurfaceView addSubview:self.heroContentContainerView];

    self.heroEyebrowLabel = [[UILabel alloc] init];
    self.heroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroEyebrowLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.0], UIFontTextStyleCaption1);
    self.heroEyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroEyebrowLabel.numberOfLines = 1;
    self.heroEyebrowLabel.hidden = YES;
    self.heroEyebrowLabel.accessibilityElementsHidden = YES;
    [self.heroContentContainerView addSubview:self.heroEyebrowLabel];

    self.heroLayoutToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.heroLayoutToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroLayoutToggleButton.clipsToBounds = NO;
    self.heroLayoutToggleButton.accessibilityHint =
        kLang(@"provider_companies_layout_toggle_hint") ?: @"Changes the provider layout";
    [self.heroLayoutToggleButton addTarget:self
                                    action:@selector(pp_handleLayoutToggleButton)
                          forControlEvents:UIControlEventTouchUpInside];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:18.0]
                                                             ?: [UIFont systemFontOfSize:18.0
                                                                                  weight:UIFontWeightBold],
                                                             UIFontTextStyleHeadline);
    self.heroTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.heroTitleLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroContentContainerView addSubview:self.heroTitleLabel];

    self.heroTitleCountBadgeLabel = [[PPInsetLabel alloc] init];
    self.heroTitleCountBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleCountBadgeLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.0]
                                                                       ?: [UIFont systemFontOfSize:11.0
                                                                                            weight:UIFontWeightSemibold],
                                                                       UIFontTextStyleCaption1);
    self.heroTitleCountBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.heroTitleCountBadgeLabel.numberOfLines = 1;
    self.heroTitleCountBadgeLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleCountBadgeLabel.minimumScaleFactor = 0.86;
    self.heroTitleCountBadgeLabel.adjustsFontForContentSizeCategory = YES;
    self.heroTitleCountBadgeLabel.textInsets = UIEdgeInsetsMake(3.0, 9.0, 3.0, 9.0);
    self.heroTitleCountBadgeLabel.layer.borderWidth = 0.75;
    self.heroTitleCountBadgeLabel.clipsToBounds = YES;
    self.heroTitleCountBadgeLabel.layer.masksToBounds = YES;
    [self.heroTitleCountBadgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                                   forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroTitleCountBadgeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroContentContainerView addSubview:self.heroTitleCountBadgeLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:13.5], UIFontTextStyleSubheadline);
    self.heroSubtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.numberOfLines = 1;
    self.heroSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.heroSubtitleLabel.hidden = YES;
    self.heroSubtitleLabel.accessibilityElementsHidden = YES;
    [self.heroContentContainerView addSubview:self.heroSubtitleLabel];

    self.heroTrailIconPlateView = [[UIView alloc] init];
    self.heroTrailIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTrailIconPlateView.userInteractionEnabled = NO;
    self.heroTrailIconPlateView.accessibilityElementsHidden = YES;
    self.heroTrailIconPlateView.hidden = YES;
    self.heroTrailIconPlateView.layer.borderWidth = 1.0;
    self.heroTrailIconPlateView.layer.masksToBounds = NO;
    [self.heroTrailIconPlateView pp_setShadowColor:UIColor.blackColor];
    self.heroTrailIconPlateView.layer.shadowOpacity = 0.035;
    self.heroTrailIconPlateView.layer.shadowRadius = 12.0;
    self.heroTrailIconPlateView.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    [self.heroSurfaceView addSubview:self.heroTrailIconPlateView];

    self.heroTrailIconView = [[UIImageView alloc] init];
    self.heroTrailIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTrailIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroTrailIconView.accessibilityElementsHidden = YES;
    [self.heroTrailIconPlateView addSubview:self.heroTrailIconView];

    self.heroMetricsStackView = [[UIStackView alloc] init];
    self.heroMetricsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroMetricsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.heroMetricsStackView.alignment = UIStackViewAlignmentFill;
    self.heroMetricsStackView.distribution = UIStackViewDistributionFillEqually;
    self.heroMetricsStackView.spacing = 10.0;
    self.heroMetricsStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroMetricsStackView.hidden = YES;
    self.heroMetricsStackView.accessibilityElementsHidden = YES;
    self.heroMetricsStackView.userInteractionEnabled = NO;
    [self.heroContentContainerView addSubview:self.heroMetricsStackView];

    self.heroCountMetricView = [self pp_makeHeroMetricViewWithTitleLabel:&_heroCountMetricTitleLabel
                                                              valueLabel:&_heroCountMetricValueLabel];
    self.heroModeMetricView = [self pp_makeHeroMetricViewWithTitleLabel:&_heroModeMetricTitleLabel
                                                             valueLabel:&_heroModeMetricValueLabel];
    self.heroTrustMetricView = [self pp_makeHeroMetricViewWithTitleLabel:&_heroTrustMetricTitleLabel
                                                              valueLabel:&_heroTrustMetricValueLabel];
    [self.heroMetricsStackView addArrangedSubview:self.heroCountMetricView];
    [self.heroMetricsStackView addArrangedSubview:self.heroModeMetricView];
    [self.heroMetricsStackView addArrangedSubview:self.heroTrustMetricView];

    self.heroSearchChromeView = [[UIView alloc] init];
    self.heroSearchChromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSearchChromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchChromeView.layer.borderWidth = 1.0;
    self.heroSearchChromeView.layer.masksToBounds = NO;
    PPProviderCompaniesApplyContinuousCorners(self.heroSearchChromeView, 23.0);
    [self.heroSurfaceView addSubview:self.heroSearchChromeView];
    UITapGestureRecognizer *searchChromeTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_focusHeroSearchTextField)];
    searchChromeTap.cancelsTouchesInView = NO;
    searchChromeTap.delegate = self;
    [self.heroSearchChromeView addGestureRecognizer:searchChromeTap];

    self.heroSearchIconView = [[UIImageView alloc] init];
    self.heroSearchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSearchIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.heroSearchChromeView addSubview:self.heroSearchIconView];

    self.heroSearchTextField = [[UITextField alloc] init];
    self.heroSearchTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSearchTextField.borderStyle = UITextBorderStyleNone;
    self.heroSearchTextField.backgroundColor = UIColor.clearColor;
    self.heroSearchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.heroSearchTextField.returnKeyType = UIReturnKeySearch;
    self.heroSearchTextField.enablesReturnKeyAutomatically = NO;
    self.heroSearchTextField.delegate = self;
    self.heroSearchTextField.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSearchTextField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchTextField.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:14.5], UIFontTextStyleSubheadline);
    self.heroSearchTextField.adjustsFontForContentSizeCategory = YES;
    self.heroSearchTextField.placeholder = kLang(@"provider_companies_search_placeholder") ?: @"Search providers";
    [self.heroSearchTextField addTarget:self
                                 action:@selector(pp_handleHeroSearchTextChanged:)
                       forControlEvents:UIControlEventEditingChanged];
    [self.heroSearchChromeView addSubview:self.heroSearchTextField];
    [self.heroSearchChromeView addSubview:self.heroLayoutToggleButton];

    self.heroProofRailView = [[UIView alloc] init];
    self.heroProofRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroProofRailView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    self.heroProofRailView.layer.borderWidth = 0.75;
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
    self.heroDiscoveryStackView.spacing = 6.0;
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


    self.heroContainerHeightConstraint = [self.headerContainerView.heightAnchor constraintEqualToConstant:0];
    self.heroSurfaceTopConstraint = [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.headerContainerView.topAnchor constant:0];
    self.heroSurfaceBottomConstraint = [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.headerContainerView.bottomAnchor constant:0.0];
    self.heroProofRailLeadingConstraint = [self.heroProofRailView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:4.0];
    self.heroProofRailTrailingConstraint = [self.heroProofRailView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-4.0];
    self.heroProofRailBottomConstraint = [self.heroProofRailView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-8.0];
    self.heroProofRailHeightConstraint = [self.heroProofRailView.heightAnchor constraintEqualToConstant:38.0];
    self.heroSearchChromeBottomConstraint = [self.heroProofRailView.topAnchor constraintEqualToAnchor:self.heroSearchChromeView.bottomAnchor constant:7.0];
    self.heroContentHeightConstraint = [self.heroContentContainerView.heightAnchor constraintEqualToConstant:24.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0.0],
        [self.headerContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:2.0],
        [self.headerContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-2.0],
        self.heroContainerHeightConstraint,

        self.heroSurfaceTopConstraint,
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.headerContainerView.leadingAnchor constant:0.0],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.headerContainerView.trailingAnchor constant:-0.0],
        self.heroSurfaceBottomConstraint,

        [self.heroFrostedMaterialView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [self.heroFrostedMaterialView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.heroFrostedMaterialView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.heroFrostedMaterialView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [self.heroAmbientSupportView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.heroAmbientSupportView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-90.0],
        [self.heroAmbientSupportView.widthAnchor constraintEqualToConstant:30.0],
        [self.heroAmbientSupportView.heightAnchor constraintEqualToConstant:30.0],

        [self.heroAmbientGlowView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:24.0],
        [self.heroAmbientGlowView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-54.0],
        [self.heroAmbientGlowView.widthAnchor constraintEqualToConstant:44.0],
        [self.heroAmbientGlowView.heightAnchor constraintEqualToConstant:44.0],

        [self.heroAmbientAccentView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:31.0],
        [self.heroAmbientAccentView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.heroAmbientAccentView.widthAnchor constraintEqualToConstant:24.0],
        [self.heroAmbientAccentView.heightAnchor constraintEqualToConstant:24.0],

        [self.heroContentContainerView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:PPStatusBarHeight + 10.0],
        [self.heroContentContainerView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:16.0],
        [self.heroContentContainerView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-16.0],
        self.heroContentHeightConstraint,

        [self.heroEyebrowLabel.topAnchor constraintEqualToAnchor:self.heroContentContainerView.topAnchor],
        [self.heroEyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroContentContainerView.leadingAnchor],
        [self.heroEyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroEyebrowLabel.heightAnchor constraintEqualToConstant:0.0],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:self.heroContentContainerView.topAnchor],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroContentContainerView.leadingAnchor],
        [self.heroTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroTitleCountBadgeLabel.leadingAnchor constant:-8.0],
        [self.heroTitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.heroContentContainerView.bottomAnchor],

        [self.heroTitleCountBadgeLabel.trailingAnchor constraintEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroTitleCountBadgeLabel.centerYAnchor constraintEqualToAnchor:self.heroTitleLabel.centerYAnchor constant:2],
        [self.heroTitleCountBadgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],
        [self.heroTitleCountBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:52.0],
        [self.heroTitleCountBadgeLabel.widthAnchor constraintLessThanOrEqualToConstant:122.0],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroContentContainerView.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroSubtitleLabel.heightAnchor constraintEqualToConstant:0.0],

        [self.heroTrailIconPlateView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:8.0],
        [self.heroTrailIconPlateView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-12.0],
        [self.heroTrailIconPlateView.widthAnchor constraintEqualToConstant:34.0],
        [self.heroTrailIconPlateView.heightAnchor constraintEqualToConstant:34.0],

        [self.heroTrailIconView.centerXAnchor constraintEqualToAnchor:self.heroTrailIconPlateView.centerXAnchor],
        [self.heroTrailIconView.centerYAnchor constraintEqualToAnchor:self.heroTrailIconPlateView.centerYAnchor],
        [self.heroTrailIconView.widthAnchor constraintEqualToConstant:19.0],
        [self.heroTrailIconView.heightAnchor constraintEqualToConstant:19.0],

        [self.heroMetricsStackView.topAnchor constraintEqualToAnchor:self.heroSubtitleLabel.bottomAnchor constant:0.0],
        [self.heroMetricsStackView.leadingAnchor constraintEqualToAnchor:self.heroContentContainerView.leadingAnchor],
        [self.heroMetricsStackView.trailingAnchor constraintEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroMetricsStackView.heightAnchor constraintEqualToConstant:0.0],

        self.heroProofRailLeadingConstraint,
        self.heroProofRailTrailingConstraint,
        self.heroProofRailBottomConstraint,
        self.heroProofRailHeightConstraint,
        self.heroSearchChromeBottomConstraint,

        [self.heroSearchChromeView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:14.0],
        [self.heroSearchChromeView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-14.0],
        [self.heroSearchChromeView.heightAnchor constraintEqualToConstant:44.0],

        [self.heroSearchIconView.leadingAnchor constraintEqualToAnchor:self.heroSearchChromeView.leadingAnchor constant:15.0],
        [self.heroSearchIconView.centerYAnchor constraintEqualToAnchor:self.heroSearchChromeView.centerYAnchor],
        [self.heroSearchIconView.widthAnchor constraintEqualToConstant:18.0],
        [self.heroSearchIconView.heightAnchor constraintEqualToConstant:18.0],

        [self.heroLayoutToggleButton.trailingAnchor constraintEqualToAnchor:self.heroSearchChromeView.trailingAnchor constant:-4.0],
        [self.heroLayoutToggleButton.centerYAnchor constraintEqualToAnchor:self.heroSearchChromeView.centerYAnchor],
        [self.heroLayoutToggleButton.widthAnchor constraintEqualToConstant:36.0],
        [self.heroLayoutToggleButton.heightAnchor constraintEqualToConstant:36.0],

        [self.heroSearchTextField.leadingAnchor constraintEqualToAnchor:self.heroSearchIconView.trailingAnchor constant:9.0],
        [self.heroSearchTextField.trailingAnchor constraintEqualToAnchor:self.heroLayoutToggleButton.leadingAnchor constant:-7.0],
        [self.heroSearchTextField.topAnchor constraintEqualToAnchor:self.heroSearchChromeView.topAnchor constant:6.0],
        [self.heroSearchTextField.bottomAnchor constraintEqualToAnchor:self.heroSearchChromeView.bottomAnchor constant:-6.0],

        [self.heroDiscoveryScrollView.topAnchor constraintEqualToAnchor:self.heroProofRailView.topAnchor constant:3.0],
        [self.heroDiscoveryScrollView.leadingAnchor constraintEqualToAnchor:self.heroProofRailView.leadingAnchor constant:3.0],
        [self.heroDiscoveryScrollView.trailingAnchor constraintEqualToAnchor:self.heroProofRailView.trailingAnchor constant:-3.0],
        [self.heroDiscoveryScrollView.bottomAnchor constraintEqualToAnchor:self.heroProofRailView.bottomAnchor constant:-3.0],

        [self.heroDiscoveryStackView.topAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.topAnchor],
        [self.heroDiscoveryStackView.leadingAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.leadingAnchor],
        [self.heroDiscoveryStackView.trailingAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.trailingAnchor],
        [self.heroDiscoveryStackView.bottomAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.bottomAnchor],
        [self.heroDiscoveryStackView.heightAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.frameLayoutGuide.heightAnchor],
        [self.heroDiscoveryStackView.widthAnchor constraintGreaterThanOrEqualToAnchor:self.heroDiscoveryScrollView.frameLayoutGuide.widthAnchor],
    ]];

    [self pp_updateDiscoveryButtonAppearances];
    [self pp_updateLayoutToggleAppearanceAnimated:NO];
    [self pp_applyHeroMaterialPalette];
    [self pp_hideDecorativeHeroContent];
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
        selected ? [GM boldFontWithSize:11.5] : [GM MidFontWithSize:11.5],
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
    configuration.imagePadding = 3.5;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(5.0, 9.0, 5.0, 9.0);
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
    button.layer.shadowOpacity = selected ? 0.08 : 0.0;
    button.layer.shadowRadius = selected ? 6.0 : 0.0;
    button.layer.shadowOffset = selected ? CGSizeMake(0.0, 2.0) : CGSizeZero;
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
    [button.heightAnchor constraintEqualToConstant:32.0].active = YES;
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

- (UIView *)pp_makeHeroMetricViewWithTitleLabel:(UILabel * __strong *)titleLabel
                                     valueLabel:(UILabel * __strong *)valueLabel
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = PPProviderCompaniesHeroSurfaceColor();
    container.layer.borderWidth = 1.0;
    container.layer.masksToBounds = YES;
    [container pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    PPProviderCompaniesApplyContinuousCorners(container, 22.0);

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:11.0], UIFontTextStyleCaption1);
    title.textColor = [AppSecondaryTextClr ?: UIColor.secondaryLabelColor colorWithAlphaComponent:0.88];
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.numberOfLines = 1;
    title.adjustsFontForContentSizeCategory = YES;
    [container addSubview:title];

    UILabel *value = [[UILabel alloc] init];
    value.translatesAutoresizingMaskIntoConstraints = NO;
    value.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:17.0], UIFontTextStyleHeadline);
    value.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    value.textAlignment = Language.alignmentForCurrentLanguage;
    value.numberOfLines = 2;
    value.adjustsFontForContentSizeCategory = YES;
    [container addSubview:value];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:container.topAnchor constant:10.0],
        [title.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12.0],
        [title.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12.0],

        [value.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2.0],
        [value.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12.0],
        [value.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12.0],
        [value.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-10.0]
    ]];

    if (titleLabel) {
        *titleLabel = title;
    }
    if (valueLabel) {
        *valueLabel = value;
    }
    return container;
}

- (void)pp_handleLayoutToggleButton
{
    self.prefersCompactListLayout = !self.prefersCompactListLayout;
    [self pp_updateLayoutToggleAppearanceAnimated:YES];
    [self pp_applyHeaderContent];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [feedback prepare];
    [feedback impactOccurred];

    self.animatedCompanyCellKeys = [NSMutableSet set];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [UIView performWithoutAnimation:^{
            [self.tableView reloadData];
            [self.tableView layoutIfNeeded];
        }];
        return;
    }

    [self.tableView.layer removeAllAnimations];
    UIView *outgoingSnapshot = [self.tableView snapshotViewAfterScreenUpdates:NO];
    outgoingSnapshot.frame = self.tableView.frame;
    outgoingSnapshot.userInteractionEnabled = NO;
    if (outgoingSnapshot) {
        [self.view insertSubview:outgoingSnapshot aboveSubview:self.tableView];
    }

    self.tableView.alpha = 0.0;
    self.tableView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    [UIView performWithoutAnimation:^{
        [self.tableView reloadData];
        [self.tableView layoutIfNeeded];
    }];

    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        outgoingSnapshot.alpha = 0.0;
        outgoingSnapshot.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -6.0),
                                    CGAffineTransformMakeScale(0.996, 0.996));
    } completion:^(__unused BOOL finished) {
        [outgoingSnapshot removeFromSuperview];
    }];

    [UIView animateWithDuration:0.36
                          delay:0.04
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    }];
}

- (void)pp_updateLayoutToggleAppearanceAnimated:(BOOL)animated
{
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    UIColor *backgroundColor = self.prefersCompactListLayout
        ? [accent colorWithAlphaComponent:0.12]
        : PPProviderCompaniesHeroSurfaceColor();
    UIColor *strokeColor = self.prefersCompactListLayout
        ? [accent colorWithAlphaComponent:0.28]
        : PPProviderCompaniesHeroStrokeColor();
    UIColor *foregroundColor = self.prefersCompactListLayout
        ? accent
        : [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.74];
    NSString *symbolName = self.prefersCompactListLayout ? @"square.grid.2x2.fill" : @"rectangle.grid.1x2.fill";
    NSString *accessibilityLabel = self.prefersCompactListLayout
        ? (kLang(@"provider_companies_layout_toggle_grid") ?: @"Show premium cards")
        : (kLang(@"provider_companies_layout_toggle_list") ?: @"Show compact list");

    void (^changes)(void) = ^{
        self.heroLayoutToggleButton.backgroundColor = backgroundColor;
        self.heroLayoutToggleButton.layer.borderWidth = 1.0;
        [self.heroLayoutToggleButton pp_setBorderColor:strokeColor];
        self.heroLayoutToggleButton.layer.shadowColor = UIColor.blackColor.CGColor;
        self.heroLayoutToggleButton.layer.shadowOpacity = 0.06;
        self.heroLayoutToggleButton.layer.shadowRadius = 10.0;
        self.heroLayoutToggleButton.layer.shadowOffset = CGSizeMake(0.0, 5.0);
        self.heroLayoutToggleButton.tintColor = foregroundColor;
        [self.heroLayoutToggleButton setImage:[[UIImage systemImageNamed:symbolName
                                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                                          weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleDefault]]
                                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                  forState:UIControlStateNormal];
        self.heroLayoutToggleButton.accessibilityLabel = accessibilityLabel;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
    } else {
        self.heroLayoutToggleButton.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [UIView animateWithDuration:0.34
                              delay:0.0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            changes();
            self.heroLayoutToggleButton.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_focusHeroSearchTextField
{
    [self.heroSearchTextField becomeFirstResponder];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isDescendantOfView:self.heroLayoutToggleButton]) {
        return NO;
    }
    return YES;
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

- (void)pp_buildHeroSearchChrome
{
    self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.definesPresentationContext = YES;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:NO];
}

- (void)pp_dismissHeroSearchChromeAndClear:(BOOL)clearQuery
{
    if (clearQuery) {
        self.heroSearchTextField.text = @"";
        self.searchQuery = @"";
        [self pp_applySearchFilter];
    }

    self.searchChromeFocused = NO;
    if ([self.heroSearchTextField isFirstResponder]) {
        [self.heroSearchTextField resignFirstResponder];
    }
    self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:YES];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)pp_applyPremiumSearchChromeAppearanceFocused:(BOOL)focused animated:(BOOL)animated
{
    if (!self.heroSearchChromeView || !self.heroSearchTextField) {
        return;
    }

    self.heroSearchChromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchTextField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchTextField.textAlignment = Language.alignmentForCurrentLanguage;

    void (^applyBlock)(void) = ^{
        UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
        UIColor *surfaceColor = focused
            ? PPProviderCompaniesHeroSurfaceColor()
            : [PPProviderCompaniesHeroSecondarySurfaceColor() colorWithAlphaComponent:0.98];
        UIColor *strokeColor = focused
            ? [accent colorWithAlphaComponent:0.28]
            : PPProviderCompaniesHeroStrokeColor();

        self.heroSearchChromeView.transform = focused && !UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformMakeScale(1.008, 1.008)
            : CGAffineTransformIdentity;
        self.heroSearchChromeView.backgroundColor = surfaceColor;
        [self.heroSearchChromeView pp_setBorderColor:strokeColor];
        self.heroSearchChromeView.layer.shadowColor = UIColor.blackColor.CGColor;
        self.heroSearchChromeView.layer.shadowOpacity = focused ? 0.062 : 0.032;
        self.heroSearchChromeView.layer.shadowRadius = focused ? 13.0 : 9.0;
        self.heroSearchChromeView.layer.shadowOffset = CGSizeMake(0.0, focused ? 6.0 : 3.0);

        self.heroSearchTextField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        self.heroSearchTextField.tintColor = accent;
        self.heroSearchTextField.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:14.5], UIFontTextStyleSubheadline);
        self.heroSearchTextField.attributedPlaceholder =
            [[NSAttributedString alloc] initWithString:(self.heroSearchTextField.placeholder ?: @"")
                                            attributes:@{
                NSForegroundColorAttributeName: [AppSecondaryTextClr ?: UIColor.secondaryLabelColor colorWithAlphaComponent:(focused ? 0.76 : 0.62)],
                NSFontAttributeName: PPProviderCompaniesScaledFont([GM MidFontWithSize:14.5], UIFontTextStyleSubheadline)
            }];

        self.heroSearchIconView.tintColor = focused
            ? accent
            : [AppSecondaryTextClr ?: UIColor.secondaryLabelColor colorWithAlphaComponent:0.72];
        if (@available(iOS 13.0, *)) {
            self.heroSearchIconView.image =
                [[UIImage systemImageNamed:@"magnifyingglass"
                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.5
                                                                                           weight:focused ? UIImageSymbolWeightBold : UIImageSymbolWeightSemibold]]
                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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
    self.heroSurfaceView.transform = CGAffineTransformMakeScale(1.016, 1.016);
    self.heroAmbientGlowView.alpha = 0.0;
    self.heroAmbientAccentView.alpha = 0.0;
    self.heroAmbientSupportView.alpha = 0.0;
    self.heroAmbientGlowView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    self.heroAmbientAccentView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    self.heroAmbientSupportView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    self.heroContentContainerView.alpha = 0.0;
    self.heroContentContainerView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.heroTrailIconPlateView.alpha = 0.0;
    self.heroTrailIconPlateView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroSearchChromeView.alpha = 0.0;
    self.heroSearchChromeView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroProofRailView.alpha = 0.0;
    self.heroProofRailView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [self pp_hideDecorativeHeroContent];
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
                               self.heroAmbientGlowView,
                               self.heroAmbientAccentView,
                               self.heroAmbientSupportView,
                               self.heroContentContainerView,
                               self.heroTrailIconPlateView,
                               self.heroSearchChromeView,
                               self.heroProofRailView]) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        [self pp_hideDecorativeHeroContent];
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.28
                          delay:0.04
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAmbientSupportView.alpha = 1.0;
        self.heroAmbientSupportView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.30
                          delay:0.10
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAmbientGlowView.alpha = 1.0;
        self.heroAmbientGlowView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.26
                          delay:0.16
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAmbientAccentView.alpha = 1.0;
        self.heroAmbientAccentView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.38
                          delay:0.08
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroContentContainerView.alpha = 1.0;
        self.heroContentContainerView.transform = CGAffineTransformIdentity;
        self.heroTrailIconPlateView.alpha = 1.0;
        self.heroTrailIconPlateView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:0.12
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroSearchChromeView.alpha = 1.0;
        self.heroSearchChromeView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.18
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroProofRailView.alpha = 1.0;
        self.heroProofRailView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [self pp_hideDecorativeHeroContent];
    }];
}

- (void)pp_startHeroAmbientMotionIfNeeded
{
    [self pp_hideDecorativeHeroContent];
    [self pp_stopHeroAmbientMotion];
    if (UIAccessibilityIsReduceMotionEnabled() || !self.heroEntranceCompleted || !self.view.window) {
        return;
    }

    self.heroAmbientMotionStarted = YES;
    UIUserInterfaceLayoutDirection layoutDirection =
        [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.heroSurfaceView.semanticContentAttribute];
    CGFloat trailingTravel = layoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? -6.0 : 6.0;

    [self pp_addHeroAmbientSequenceToView:self.heroAmbientSupportView
                                    delay:0.00
                                   travel:trailingTravel * 0.90
                               scaleDelta:0.030
                             opacityFloor:0.70
                                      key:@"PPProviderCompaniesHeroAmbientSupportLine"];
    [self pp_addHeroAmbientSequenceToView:self.heroAmbientGlowView
                                    delay:0.20
                                   travel:trailingTravel
                               scaleDelta:0.040
                             opacityFloor:0.76
                                      key:@"PPProviderCompaniesHeroAmbientGlowLine"];
    [self pp_addHeroAmbientSequenceToView:self.heroAmbientAccentView
                                    delay:0.40
                                   travel:trailingTravel * 1.10
                               scaleDelta:0.048
                             opacityFloor:0.82
                                      key:@"PPProviderCompaniesHeroAmbientAccentLine"];
}

- (CAGradientLayer *)pp_makeBackgroundGlowLayer
{
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.startPoint = CGPointMake(0.5, 0.5);
    layer.endPoint = CGPointMake(1.0, 1.0);
    layer.locations = @[@0.0, @0.44, @1.0];
    layer.drawsAsynchronously = YES;
    if (@available(iOS 12.0, *)) {
        layer.type = kCAGradientLayerRadial;
    }
    return layer;
}

- (void)pp_applyBackgroundGlowColor:(UIColor *)color
                               view:(UIView *)view
                      gradientLayer:(CAGradientLayer *)gradientLayer
                          peakAlpha:(CGFloat)peakAlpha
{
    if (!view || !gradientLayer) {
        return;
    }

    UIColor *safeColor = color ?: UIColor.clearColor;
    UIColor *resolvedColor = safeColor;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [safeColor resolvedColorWithTraitCollection:self.traitCollection];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.backgroundColor = UIColor.clearColor;
    view.layer.shadowOpacity = 0.0;
    gradientLayer.hidden = NO;
    gradientLayer.colors = @[
        (__bridge id)[resolvedColor colorWithAlphaComponent:peakAlpha].CGColor,
        (__bridge id)[resolvedColor colorWithAlphaComponent:peakAlpha].CGColor,
        (__bridge id)[resolvedColor colorWithAlphaComponent:peakAlpha].CGColor
    ];
    [CATransaction commit];
}

- (void)pp_addHeroAmbientSequenceToView:(UIView *)view
                                  delay:(CFTimeInterval)delay
                                 travel:(CGFloat)travel
                             scaleDelta:(CGFloat)scaleDelta
                           opacityFloor:(CGFloat)opacityFloor
                                    key:(NSString *)key
{
    if (!view || key.length == 0) {
        return;
    }

    CFTimeInterval duration = 4.6;
    CFTimeInterval beginTime = CACurrentMediaTime() + delay;

    CAKeyframeAnimation *translation = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    translation.values = @[@0.0, @(travel * 0.52), @(travel), @(travel * 0.34), @0.0];
    translation.keyTimes = @[@0.0, @0.30, @0.54, @0.78, @1.0];

    CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    scale.values = @[@1.0, @(1.0 + scaleDelta), @1.0];
    scale.keyTimes = @[@0.0, @0.52, @1.0];

    CAKeyframeAnimation *opacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacity.values = @[@1.0, @(opacityFloor), @1.0];
    opacity.keyTimes = @[@0.0, @0.52, @1.0];

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[translation, scale, opacity];
    group.duration = duration;
    group.beginTime = beginTime;
    group.repeatCount = HUGE_VALF;
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeBoth;
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_stopHeroAmbientMotion
{
    self.heroAmbientMotionStarted = NO;
    [self.heroAmbientSupportView.layer removeAnimationForKey:@"PPProviderCompaniesHeroAmbientSupportLine"];
    [self.heroAmbientGlowView.layer removeAnimationForKey:@"PPProviderCompaniesHeroAmbientGlowLine"];
    [self.heroAmbientAccentView.layer removeAnimationForKey:@"PPProviderCompaniesHeroAmbientAccentLine"];
}


- (CGFloat)pp_expandedHeroHeight
{
    CGFloat contentHeight = [self pp_expandedHeroContentHeight];
    CGFloat requiredHeight =
        PPStatusBarHeight +
        10.0 +  // compact title top inset below status bar
        contentHeight +
        7.0 +   // title to search
        44.0 +  // search chrome
        7.0 +   // search to discovery rail
        38.0 +  // discovery rail
        8.0;    // discovery rail bottom inset
    return ceil(MAX(136.0, requiredHeight));
}

- (CGFloat)pp_expandedHeroContentHeight
{
    return 0.0;
}

- (CGFloat)pp_collapsedHeroHeight
{
    return [self pp_expandedHeroHeight];
}

- (CGFloat)pp_heroCollapseDistance
{
    return MAX(1.0, [self pp_expandedHeroHeight] - [self pp_collapsedHeroHeight]);
}

- (void)pp_applyHeroCollapseProgress:(CGFloat)progress animated:(BOOL)animated
{
    progress = MAX(0.0, MIN(1.0, progress));
    if (progress < 0.012) {
        progress = 0.0;
    } else if (progress > 0.988) {
        progress = 1.0;
    }
    _heroCollapseProgress = progress;

    CGFloat currentHeight = [self pp_expandedHeroHeight];
    CGFloat topInset = 0.0;
    CGFloat bottomInset = 0.0;
    CGFloat railSideInset = 16.0;
    CGFloat railBottomInset = 12.0;
    CGFloat railHeight = 38.0;
    CGFloat searchRailGap = 7.0;
    CGFloat contentHeight = [self pp_expandedHeroContentHeight];
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    CGFloat surfaceShadowOpacity = dark ? 0.14 : 0.045;
    CGFloat surfaceShadowRadius = dark ? 22.0 : 18.0;
    CGFloat surfaceShadowY = 8.0;
    CGFloat contentAlpha = 1.0;
    CGFloat eyebrowAlpha = 0.0;
    CGFloat titleAlpha = 1.0;
    CGFloat subtitleAlpha = 0.0;
    CGFloat metricsAlpha = 0.0;
    CGFloat layoutToggleScale = 1.0;
    CGFloat searchScale = self.searchChromeFocused ? 1.008 : 1.0;
    CGFloat proofRailScale = 1.0;
    CGFloat ambientAlpha = self.heroEntranceCompleted ? 1.0 : 0.0;

    void (^updates)(void) = ^{
        self.heroContainerHeightConstraint.constant = currentHeight;
        self.heroSurfaceTopConstraint.constant = topInset;
        self.heroSurfaceBottomConstraint.constant = bottomInset;
        self.heroContentHeightConstraint.constant = contentHeight;
        self.heroProofRailLeadingConstraint.constant = railSideInset;
        self.heroProofRailTrailingConstraint.constant = -railSideInset;
        self.heroProofRailBottomConstraint.constant = -railBottomInset;
        self.heroProofRailHeightConstraint.constant = railHeight;
        self.heroSearchChromeBottomConstraint.constant = searchRailGap;

        self.heroSurfaceView.layer.shadowOpacity = surfaceShadowOpacity;
        self.heroSurfaceView.layer.shadowRadius = surfaceShadowRadius;
        self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, surfaceShadowY);

        self.heroContentContainerView.alpha = contentAlpha;
        self.heroEyebrowLabel.alpha = eyebrowAlpha;
        self.heroTitleLabel.alpha = titleAlpha;
        self.heroTitleCountBadgeLabel.alpha = titleAlpha;
        self.heroSubtitleLabel.alpha = subtitleAlpha;
        self.heroTrailIconPlateView.alpha = contentAlpha;
        self.heroMetricsStackView.alpha = metricsAlpha;
        self.heroAmbientGlowView.alpha = ambientAlpha;
        self.heroAmbientAccentView.alpha = ambientAlpha;
        self.heroAmbientSupportView.alpha = ambientAlpha;
        self.heroContentContainerView.transform = CGAffineTransformIdentity;
        self.heroTrailIconPlateView.transform = CGAffineTransformIdentity;
        self.heroAmbientGlowView.transform = CGAffineTransformIdentity;
        self.heroAmbientAccentView.transform = CGAffineTransformIdentity;
        self.heroAmbientSupportView.transform = CGAffineTransformIdentity;
        self.heroLayoutToggleButton.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(layoutToggleScale, layoutToggleScale);
        self.heroProofRailView.alpha = 1.0;
        self.heroProofRailView.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(proofRailScale, proofRailScale);
        self.heroSearchChromeView.alpha = 1.0;
        self.heroSearchChromeView.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(searchScale, searchScale);
        [self pp_hideDecorativeHeroContent];

        [self.view layoutIfNeeded];
        [self pp_updateHeroSurfaceGeometry];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        self.applyingHeroCollapseLayout = YES;
        updates();
        self.applyingHeroCollapseLayout = NO;
    } else {
        self.applyingHeroCollapseLayout = YES;
        [UIView animateWithDuration:0.32
                              delay:0.0
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.12
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:updates
                         completion:^(BOOL finished) {
            self.applyingHeroCollapseLayout = NO;
        }];
    }

    self.heroCollapsed = YES;
}

- (void)pp_updatePinnedHeroForCurrentScrollPosition
{
    if (self.applyingHeroCollapseLayout || !self.tableView || !self.heroContainerHeightConstraint) {
        return;
    }

    CGFloat topInset = self.tableView.adjustedContentInset.top;
    CGFloat offset = self.tableView.contentOffset.y + topInset;
    CGFloat collapseDistance = [self pp_heroCollapseDistance];
    CGFloat snapThreshold = collapseDistance * 0.12;
    if (offset <= snapThreshold) {
        offset = 0.0;
    }
    CGFloat progress = offset <= 0.0 ? 0.0 : MIN(1.0, offset / collapseDistance);
    if (self.searchChromeFocused) {
        progress = 1.0;
    }
    [self pp_applyHeroCollapseProgress:progress animated:NO];
}

- (void)pp_hideDecorativeHeroContent
{
    self.heroEyebrowLabel.hidden = YES;
    self.heroEyebrowLabel.accessibilityElementsHidden = YES;
    self.heroSubtitleLabel.hidden = YES;
    self.heroSubtitleLabel.accessibilityElementsHidden = YES;
    self.heroTrailIconPlateView.hidden = YES;
    self.heroTrailIconPlateView.accessibilityElementsHidden = YES;
    self.heroMetricsStackView.hidden = YES;
    self.heroMetricsStackView.accessibilityElementsHidden = YES;
    self.heroContentContainerView.hidden = YES;
    self.heroContentContainerView.accessibilityElementsHidden = YES;
    self.heroTitleLabel.hidden = YES;
    self.heroTitleLabel.accessibilityElementsHidden = YES;
    self.heroTitleCountBadgeLabel.hidden = YES;
    self.heroTitleCountBadgeLabel.accessibilityElementsHidden = YES;
    self.heroProofRailView.hidden = NO;
    self.heroProofRailView.userInteractionEnabled = YES;
    self.heroDiscoveryScrollView.hidden = NO;
    self.heroDiscoveryScrollView.userInteractionEnabled = YES;
}

- (void)pp_applyHeroMaterialPalette
{
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    UIColor *surface = PPProviderCompaniesHeroSurfaceColor();
    UIColor *backgroundBase = AppBackgroundClr ?: (dark ? [UIColor colorWithWhite:0.05 alpha:1.0] : UIColor.whiteColor);
    UIColor *foregroundBase = [UIColor colorNamed:@"AppForegroundColor"] ?: surface;
    UIColor *surfaceBorder =
        dark ? [accent colorWithAlphaComponent:0.22] : [UIColor.whiteColor colorWithAlphaComponent:0.94];
    UIColor *edgeColor =
        dark ? [UIColor.whiteColor colorWithAlphaComponent:0.055] : [UIColor.whiteColor colorWithAlphaComponent:0.74];

    UIBlurEffectStyle blurStyle = dark ? UIBlurEffectStyleDark : UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemThinMaterial;
    }
    self.heroFrostedMaterialView.effect = [UIBlurEffect effectWithStyle:blurStyle];
    self.heroFrostedMaterialView.contentView.backgroundColor =
        [surface colorWithAlphaComponent:(dark ? 0.16 : 0.10)];

    self.heroSurfaceView.backgroundColor = UIColor.clearColor;
    self.heroSurfaceGradientLayer.colors = @[
        (__bridge id)[foregroundBase colorWithAlphaComponent:(dark ? 0.36 : 0.2)].CGColor,
        (__bridge id)[foregroundBase colorWithAlphaComponent:(dark ? 0.28 : 0.4)].CGColor,
        (__bridge id)[ [UIColor colorNamed:@"NewBg"]  colorWithAlphaComponent:(dark ? 0.22 : 0.4)].CGColor
    ];
    [self.heroSurfaceView pp_setBorderColor:surfaceBorder];
    self.heroSurfaceEdgeHighlightLayer.strokeColor = edgeColor.CGColor;
    [self.heroSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.heroSurfaceView.layer.shadowOpacity = dark ? 0.14 : 0.045;
    self.heroSurfaceView.layer.shadowRadius = dark ? 22.0 : 18.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    self.heroAmbientGlowView.hidden = NO;
    self.heroAmbientAccentView.hidden = NO;
    self.heroAmbientSupportView.hidden = NO;
    self.heroAmbientGlowView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.20 : 0.13)];
    self.heroAmbientGlowView.layer.shadowOpacity = 0.0;
    self.heroAmbientGlowView.layer.shadowRadius = 0.0;
    self.heroAmbientGlowView.layer.shadowOffset = CGSizeZero;
    self.heroAmbientGlowView.layer.borderWidth = 0.0;

    self.heroAmbientAccentView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.12 : 0.08)];
    self.heroAmbientAccentView.layer.shadowOpacity = 0.0;
    self.heroAmbientAccentView.layer.shadowRadius = 0.0;
    self.heroAmbientAccentView.layer.shadowOffset = CGSizeZero;
    self.heroAmbientAccentView.layer.borderWidth = 0.0;

    self.heroAmbientSupportView.backgroundColor =
        dark ? [[UIColor whiteColor] colorWithAlphaComponent:0.09]
             : [accent colorWithAlphaComponent:0.055];
    self.heroAmbientSupportView.layer.shadowOpacity = 0.0;
    self.heroAmbientSupportView.layer.shadowRadius = 0.0;
    self.heroAmbientSupportView.layer.shadowOffset = CGSizeZero;
    self.heroAmbientSupportView.layer.borderWidth = 0.0;

    [self pp_applyBackgroundGlowColor:accent
                                 view:self.tableBackgroundMiddleGlowView
                        gradientLayer:self.tableBackgroundMiddleGlowLayer
                            peakAlpha:(dark ? 0.11 : 0.082)];
    self.tableBackgroundMiddleGlowView.layer.shadowRadius = 0.0;
    self.tableBackgroundMiddleGlowView.layer.shadowOffset = CGSizeZero;
    self.tableBackgroundMiddleGlowView.layer.borderWidth = 0.0;

    UIColor *bottomGlowColor = [UIColor colorNamed:@"NewBg"] ?: accent;
    [self pp_applyBackgroundGlowColor:bottomGlowColor
                                 view:self.tableBackgroundBottomGlowView
                        gradientLayer:self.tableBackgroundBottomGlowLayer
                            peakAlpha:(dark ? 0.10 : 0.095)];
    self.tableBackgroundBottomGlowView.layer.shadowRadius = 0.0;
    self.tableBackgroundBottomGlowView.layer.shadowOffset = CGSizeZero;
    self.tableBackgroundBottomGlowView.layer.borderWidth = 0.0;

    self.heroTrailIconPlateView.backgroundColor = [surface colorWithAlphaComponent:(dark ? 0.70 : 0.82)];
    [self.heroTrailIconPlateView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.18 : 0.58)]];
    self.heroTrailIconPlateView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.heroTrailIconPlateView.layer.shadowOpacity = dark ? 0.10 : 0.035;
    self.heroTrailIconPlateView.layer.shadowRadius = 14.0;
    self.heroTrailIconPlateView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    self.heroTrailIconView.tintColor = [accent colorWithAlphaComponent:0.92];

    self.heroEyebrowLabel.textColor = [accent colorWithAlphaComponent:0.92];
    self.heroTitleCountBadgeLabel.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.18 : 0.095)];
    self.heroTitleCountBadgeLabel.textColor = [accent colorWithAlphaComponent:(dark ? 0.96 : 0.92)];
    [self.heroTitleCountBadgeLabel pp_setBorderColor:[accent colorWithAlphaComponent:(dark ? 0.30 : 0.16)]];
    self.heroTitleCountBadgeLabel.layer.shadowColor = accent.CGColor;
    self.heroTitleCountBadgeLabel.layer.shadowOpacity = 0.0;
    self.heroTitleCountBadgeLabel.layer.shadowRadius = 0.0;
    self.heroTitleCountBadgeLabel.layer.shadowOffset = CGSizeZero;
    self.heroProofRailView.backgroundColor = [surface colorWithAlphaComponent:(dark ? 0.44 : 0.58)];
    [self.heroProofRailView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.12 : 0.38)]];
    for (UIView *metricView in @[self.heroCountMetricView, self.heroModeMetricView, self.heroTrustMetricView]) {
        metricView.backgroundColor = [surface colorWithAlphaComponent:(dark ? 0.76 : 0.88)];
        [metricView pp_setBorderColor:[accent colorWithAlphaComponent:(dark ? 0.14 : 0.08)]];
    }
    [self pp_applyPremiumSearchChromeAppearanceFocused:self.searchChromeFocused animated:NO];
    [self pp_updateLayoutToggleAppearanceAnimated:NO];
    [self pp_updateDiscoveryButtonAppearances];
}

- (void)pp_applyHeaderContent
{
    [self pp_applyHeroMaterialPalette];

    NSString *identifier = self.selectedProviderCategoryIdentifier;
    NSInteger sourceCount = self.loadState == PPProviderCompaniesLoadStateLoaded ? self.visibleEntries.count : self.allEntries.count;
    sourceCount = MAX(sourceCount, self.visibleEntries.count);
    NSString *heroTitle = PPProviderCompaniesTitleForCategoryIdentifier(identifier);
    NSString *heroSubtitle = PPProviderCompaniesHeroSupportText(identifier);
    NSString *countValue = PPProviderCompaniesCountText(sourceCount, identifier);
    NSString *modeTitle = kLang(@"provider_companies_metric_mode_title") ?: @"View";
    NSString *trustTitle = kLang(@"provider_companies_metric_trust_title") ?: @"Focus";
    NSString *layoutTitle = kLang(@"provider_companies_metric_layout_title") ?: @"Layout";

    self.heroEyebrowLabel.text = PPProviderCompaniesHeroEyebrowText(identifier);
    self.heroTitleLabel.text = heroTitle;
    self.heroTitleCountBadgeLabel.text = countValue;
    self.heroTitleCountBadgeLabel.accessibilityLabel = countValue;
    self.heroSubtitleLabel.text = heroSubtitle;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                           weight:UIImageSymbolWeightSemibold];
        self.heroTrailIconView.image =
            [[UIImage systemImageNamed:PPProviderCompaniesSymbolNameForCategoryIdentifier(identifier)
                     withConfiguration:configuration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        self.heroTrailIconView.image = nil;
    }
    self.heroCountMetricTitleLabel.text = kLang(@"provider_companies_metric_count_title") ?: @"Available now";
    self.heroCountMetricValueLabel.text = countValue;
    self.heroModeMetricTitleLabel.text = modeTitle;
    self.heroModeMetricValueLabel.text = PPProviderCompaniesDiscoveryTitle(self.selectedDiscoveryMode);
    self.heroTrustMetricTitleLabel.text = trustTitle;
    self.heroTrustMetricValueLabel.text = PPProviderCompaniesHeroModeSummary(self.selectedDiscoveryMode);

    NSString *layoutValue = self.prefersCompactListLayout
        ? (kLang(@"provider_companies_layout_mode_list") ?: @"Compact")
        : (kLang(@"provider_companies_layout_mode_grid") ?: @"Showcase");
    self.heroLayoutToggleButton.accessibilityValue = layoutValue;
    self.heroLayoutToggleButton.accessibilityHint =
        [NSString stringWithFormat:@"%@. %@",
         layoutTitle,
         self.prefersCompactListLayout
            ? (kLang(@"provider_companies_layout_toggle_grid") ?: @"Show premium cards")
            : (kLang(@"provider_companies_layout_toggle_list") ?: @"Show compact list")];
    self.heroSurfaceView.isAccessibilityElement = NO;
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

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.searchChromeFocused = YES;
    [self pp_applyPremiumSearchChromeAppearanceFocused:YES animated:YES];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
    [self pp_setPremiumTabDockHidden:YES animated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.searchChromeFocused = NO;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:YES];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
    [self pp_setPremiumTabDockHidden:NO animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    self.searchQuery = @"";
    [self pp_applySearchFilter];
    return YES;
}

- (void)pp_handleHeroSearchTextChanged:(UITextField *)textField
{
    self.searchQuery = PPProviderCompaniesSafeString(textField.text);
    [self pp_applySearchFilter];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.visibleEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPProviderCompanyEntry *entry = self.visibleEntries[indexPath.row];
    if (self.prefersCompactListLayout) {
        PPProviderCompanyCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderCompanyCell"
                                                                      forIndexPath:indexPath];
        [cell configureWithEntry:entry categoryIdentifier:self.selectedProviderCategoryIdentifier];
        return cell;
    }

    PPProviderCompanyPremiumCardCell *cell =
        [tableView dequeueReusableCellWithIdentifier:PPProviderCompanyPremiumCardCell.reuseIdentifier
                                        forIndexPath:indexPath];
    [cell configureWithViewModel:[self pp_premiumCardViewModelForEntry:entry]];
    return cell;
}


- (PPProviderCompanyPremiumCardViewModel *)pp_premiumCardViewModelForEntry:(PPProviderCompanyEntry *)entry
{
    PPProviderCompanyPremiumCardViewModel *model = [[PPProviderCompanyPremiumCardViewModel alloc] init];

    NSString *title = PPProviderCompaniesSafeString([entry.user bestDisplayName]);
    if (title.length == 0) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (entry.user.FirstName.length > 0) [parts addObject:entry.user.FirstName];
        if (entry.user.LastName.length > 0) [parts addObject:entry.user.LastName];
        title = parts.count > 0 ? [parts componentsJoinedByString:@" "] : PPProviderCompaniesSafeString(entry.user.UserName);
    }
    if (title.length == 0) {
        title = PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    }

    model.providerIdentifier = PPProviderCompaniesSafeString(entry.ownerID);
    model.title = title;
    model.subtitle = PPProviderCompaniesCellDisplaySubtitle(entry, self.selectedProviderCategoryIdentifier);
    model.categoryText = PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    model.countTitleText = PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
        ? (kLang(@"provider_companies_count_title_pharmacy") ?: @"Medicines")
        : (kLang(@"provider_companies_count_title_marketplace") ?: @"Products");
    model.countValueText = [NSString stringWithFormat:@"%ld", (long)MAX(entry.productCount, 0)];
    model.cityText = PPProviderCompaniesCityForEntry(entry);
    model.accentColor = AppPrimaryClr ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    model.verified = entry.user.isVerified;
    model.active = [PPProviderCompaniesSafeString(entry.user.accountStatus) isEqualToString:@"active"];
    model.accessoryStyle = PPProviderCompanyPremiumCardAccessoryStyleHeart;

    if (entry.user.providerReviewCount > 0 && entry.user.providerRatingValue > 0.0) {
        model.ratingText = [NSString stringWithFormat:@"%.1f", entry.user.providerRatingValue];
        model.ratingCountText = [NSString stringWithFormat:@"(%ld)", (long)entry.user.providerReviewCount];
    } else {
        model.ratingText = @"New";
        model.ratingCountText = @"";
    }

    NSString *coverImageURLString = @"";
    if (entry.user.coverImageUrls && entry.user.coverImageUrls.count > 0) {
        coverImageURLString = PPProviderCompaniesSafeString(entry.user.coverImageUrls[0]);
    }
    if (coverImageURLString.length == 0 && entry.items.count > 0) {
        PetAccessory *latestProduct = entry.items.firstObject;
        if (latestProduct.imageURLsArray && latestProduct.imageURLsArray.count > 0) {
            coverImageURLString = PPProviderCompaniesSafeString(latestProduct.imageURLsArray[0]);
        }
    }
    if (coverImageURLString.length > 0) {
        model.imageURL = [NSURL URLWithString:coverImageURLString];
    }

    model.placeholderImage = [UIImage imageNamed:@"providers_placeholder"];

    return model;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.prefersCompactListLayout) {
        return UITableViewAutomaticDimension;
    }
    return [PPProviderCompanyPremiumCardCell preferredHeightForTableWidth:CGRectGetWidth(tableView.bounds)];
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
    if (indexPath.row >= self.visibleEntries.count) {
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
    if ([cell isKindOfClass:PPProviderCompanyCell.class]) {
        [(PPProviderCompanyCell *)cell pp_runEntranceAnimationWithDelay:delay];
    } else if ([cell isKindOfClass:PPProviderCompanyPremiumCardCell.class]) {
        [(PPProviderCompanyPremiumCardCell *)cell pp_runEntranceAnimationWithDelay:delay];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.tableView) {
        return;
    }

    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)pp_setPremiumTabDockHidden:(BOOL)hidden animated:(BOOL)animated
{
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)self.tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
        return;
    }
    if ([self.tabBarController respondsToSelector:@selector(pp_setBottomNavigationHidden:animated:)]) {
        [(id)self.tabBarController pp_setBottomNavigationHidden:hidden animated:animated];
        return;
    }
}

@end
