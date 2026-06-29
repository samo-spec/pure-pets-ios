//
//  PPProviderCompanyCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 6/28/26.
//

@interface PPProviderCompanyEntry : NSObject
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, strong) NSArray<PetAccessory *> *items;
@property (nonatomic, strong, nullable) UserModel *user;
@property (nonatomic, copy) NSString *profileDisplayName;
@property (nonatomic, copy) NSString *profileCityText;
@property (nonatomic, copy) NSString *profileAvatarURLString;
@property (nonatomic, strong) NSArray<NSString *> *profileCoverImageURLs;
@property (nonatomic, assign) NSInteger productCount;
@property (nonatomic, strong, nullable) NSDate *latestCreatedAt;
@end


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
        return kLang(@"provider_pharmacies_title") ?: @"Pharmacies";
    }
    return kLang(@"provider_marketplace_title") ?: @"Marketplace";
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
    return @"storefront.fill";
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
    (void)identifier;
    return @"";
}

static NSString *PPProviderCompaniesHeroSupportText(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_companies_hero_support_pharmacy_short") ?: @"Choose a trusted pharmacy first.";
    }
    return kLang(@"provider_companies_hero_support_marketplace_short") ?: @"Choose a trusted provider first.";
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
    return [PPProviderCompaniesSafeString(entry.profileCityText)
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}







@interface PPProviderCompanyCell : UITableViewCell
@property (nonatomic, copy, nullable) void (^onFavTap)(PPProviderCompanyEntry *entry);
+ (CGFloat)preferredHeightForTableWidth:(CGFloat)tableWidth;
- (void)configureWithEntry:(PPProviderCompanyEntry *)entry
        categoryIdentifier:(NSString *)categoryIdentifier;
- (void)pp_runEntranceAnimationWithDelay:(NSTimeInterval)delay;
@end
