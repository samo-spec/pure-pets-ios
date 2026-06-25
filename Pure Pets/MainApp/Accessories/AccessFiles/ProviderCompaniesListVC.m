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

static NSString *PPProviderCompaniesSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
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

static NSString *PPProviderCompaniesSubtitleForCategoryIdentifier(NSString *identifier)
{
    if (PPProviderCompaniesIsPharmacyCategory(identifier)) {
        return kLang(@"provider_pharmacies_subtitle") ?: @"Verified pet medicines from trusted pharmacies.";
    }
    return kLang(@"provider_marketplace_subtitle") ?: @"Trusted providers offering food, accessories, and essentials.";
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

@interface PPProviderCompanyEntry : NSObject
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, strong) NSArray<PetAccessory *> *items;
@property (nonatomic, strong, nullable) UserModel *user;
@property (nonatomic, assign) NSInteger productCount;
@property (nonatomic, strong, nullable) NSDate *latestCreatedAt;
@end

@implementation PPProviderCompanyEntry
@end

@interface PPProviderCompanyCell : UITableViewCell
- (void)configureWithEntry:(PPProviderCompanyEntry *)entry
        categoryIdentifier:(NSString *)categoryIdentifier;
@end

@implementation PPProviderCompanyCell {
    UIView *_cardView;
    UIView *_glowView;
    UIView *_avatarShellView;
    UIView *_chevronContainerView;
    UIImageView *_avatarImageView;
    PPInsetLabel *_categoryBadgeLabel;
    PPInsetLabel *_statusBadgeLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UILabel *_metaLabel;
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
    _cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.84] ?: UIColor.whiteColor;
    _cardView.layer.cornerRadius = 28.0;
    _cardView.layer.borderWidth = 1.0;
    _cardView.layer.masksToBounds = NO;
    [_cardView pp_setBorderColor:[[UIColor colorWithWhite:0.88 alpha:1.0] colorWithAlphaComponent:0.76]];
    [_cardView pp_setShadowColor:UIColor.blackColor];
    _cardView.layer.shadowOpacity = 0.045;
    _cardView.layer.shadowRadius = 18.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [self.contentView addSubview:_cardView];

    _glowView = [[UIView alloc] init];
    _glowView.translatesAutoresizingMaskIntoConstraints = NO;
    _glowView.userInteractionEnabled = NO;
    _glowView.alpha = 0.18;
    [_cardView addSubview:_glowView];

    _avatarShellView = [[UIView alloc] init];
    _avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarShellView.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.08];
    _avatarShellView.layer.cornerRadius = 32.0;
    _avatarShellView.layer.masksToBounds = YES;
    _avatarShellView.layer.borderWidth = 1.0;
    [_avatarShellView pp_setBorderColor:[AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.14]];
    [_cardView addSubview:_avatarShellView];

    _avatarImageView = [[UIImageView alloc] init];
    _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarImageView.layer.cornerRadius = 26.0;
    _avatarImageView.layer.masksToBounds = YES;
    _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    [_avatarShellView addSubview:_avatarImageView];

    _categoryBadgeLabel = [self pp_badgeLabel];
    [_cardView addSubview:_categoryBadgeLabel];

    _statusBadgeLabel = [self pp_badgeLabel];
    [_cardView addSubview:_statusBadgeLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:19.0] ?: [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    _titleLabel.textColor = AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0];
    _titleLabel.numberOfLines = 2;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _subtitleLabel.textColor = AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_subtitleLabel];

    _metaLabel = [[UILabel alloc] init];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _metaLabel.textColor = [AppPrimaryTextClr ?: [UIColor colorWithWhite:0.12 alpha:1.0] colorWithAlphaComponent:0.72];
    _metaLabel.adjustsFontForContentSizeCategory = YES;
    _metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardView addSubview:_metaLabel];

    _chevronContainerView = [[UIView alloc] init];
    _chevronContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronContainerView.layer.masksToBounds = YES;
    _chevronContainerView.backgroundColor = [UIColor colorWithWhite:0.985 alpha:1.0];
    [_cardView addSubview:_chevronContainerView];

    _chevronView = [[UIImageView alloc] init];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        NSString *chevronName = Language.isRTL ? @"arrow.left" : @"arrow.right";
        _chevronView.image = [[UIImage systemImageNamed:chevronName
                                      withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                                weight:UIImageSymbolWeightSemibold]]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _chevronView.tintColor = [AppPrimaryTextClr ?: [UIColor colorWithWhite:0.12 alpha:1.0] colorWithAlphaComponent:0.62];
    [_chevronContainerView addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_glowView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:12.0],
        [_glowView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:18.0],
        [_glowView.widthAnchor constraintEqualToConstant:56.0],
        [_glowView.heightAnchor constraintEqualToConstant:56.0],

        [_avatarShellView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16.0],
        [_avatarShellView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_avatarShellView.widthAnchor constraintEqualToConstant:64.0],
        [_avatarShellView.heightAnchor constraintEqualToConstant:64.0],

        [_avatarImageView.centerXAnchor constraintEqualToAnchor:_avatarShellView.centerXAnchor],
        [_avatarImageView.centerYAnchor constraintEqualToAnchor:_avatarShellView.centerYAnchor],
        [_avatarImageView.widthAnchor constraintEqualToConstant:52.0],
        [_avatarImageView.heightAnchor constraintEqualToConstant:52.0],

        [_categoryBadgeLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16.0],
        [_categoryBadgeLabel.leadingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:14.0],
        [_categoryBadgeLabel.heightAnchor constraintEqualToConstant:30.0],

        [_statusBadgeLabel.centerYAnchor constraintEqualToAnchor:_categoryBadgeLabel.centerYAnchor],
        [_statusBadgeLabel.leadingAnchor constraintEqualToAnchor:_categoryBadgeLabel.trailingAnchor constant:8.0],
        [_statusBadgeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_cardView.trailingAnchor constant:-22.0],
        [_statusBadgeLabel.heightAnchor constraintEqualToConstant:30.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_categoryBadgeLabel.bottomAnchor constant:12.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_categoryBadgeLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-22.0],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:5.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_metaLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:8.0],
        [_metaLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_metaLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_metaLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-16.0],

        [_chevronContainerView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16.0],
        [_chevronContainerView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-16.0],
        [_chevronContainerView.widthAnchor constraintEqualToConstant:36.0],
        [_chevronContainerView.heightAnchor constraintEqualToConstant:36.0],

        [_chevronView.centerXAnchor constraintEqualToAnchor:_chevronContainerView.centerXAnchor],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_chevronContainerView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:16.0],
        [_chevronView.heightAnchor constraintEqualToConstant:16.0]
    ]];
}

- (PPInsetLabel *)pp_badgeLabel
{
    PPInsetLabel *label = [[PPInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.cornerRadius = 15.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 1.0;
    label.contentMode = UIViewContentModeCenter;
    label.textInsets = UIEdgeInsetsMake(2.0, 12.0, 2.0, 12.0);
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
    _glowView.backgroundColor = [accent colorWithAlphaComponent:0.06];
    _glowView.layer.shadowColor = accent.CGColor;
    _glowView.layer.shadowOpacity = 0.05;
    _glowView.layer.shadowRadius = 12.0;
    _glowView.layer.shadowOffset = CGSizeZero;
    _chevronContainerView.backgroundColor = [accent colorWithAlphaComponent:0.05];

    _categoryBadgeLabel.text = PPProviderCompaniesTitleForCategoryIdentifier(categoryIdentifier);
    _categoryBadgeLabel.textColor = accent;
    _categoryBadgeLabel.backgroundColor = [accent colorWithAlphaComponent:0.08];
    [_categoryBadgeLabel pp_setBorderColor:[accent colorWithAlphaComponent:0.16]];

    BOOL showVerified = entry.user.isVerified;
    BOOL showActive = !showVerified && [PPProviderCompaniesSafeString(entry.user.accountStatus) isEqualToString:@"active"];
    _statusBadgeLabel.hidden = !showVerified && !showActive;
    if (showVerified || showActive) {
        NSString *statusText = showVerified
            ? (kLang(@"verified") ?: @"Verified")
            : (kLang(@"provider_company_status_active") ?: @"Active");
        UIColor *statusColor = showVerified ? [UIColor colorWithRed:0.14 green:0.52 blue:0.34 alpha:1.0] : accent;
        _statusBadgeLabel.text = statusText;
        _statusBadgeLabel.textColor = statusColor;
        _statusBadgeLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.08];
        [_statusBadgeLabel pp_setBorderColor:[statusColor colorWithAlphaComponent:0.16]];
    } else {
        _statusBadgeLabel.text = nil;
    }

    _titleLabel.text = title;
    _subtitleLabel.text = entry.user.UserAbout.length > 0
        ? entry.user.UserAbout
        : PPProviderCompaniesSubtitleForCategoryIdentifier(categoryIdentifier);
    _metaLabel.text = PPProviderCompaniesItemsCountText(entry.productCount, categoryIdentifier);

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:title size:60.0];
    _avatarImageView.image = placeholder ?: PPSYSImage(@"person.crop.circle.fill");
    NSString *imageURL = PPProviderCompaniesSafeString(entry.user.UserImageUrl.absoluteString);
    if (imageURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_avatarImageView
                                                       url:imageURL
                                               placeholder:_avatarImageView.image
                                                complation:nil];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@",
                               title,
                               PPProviderCompaniesTitleForCategoryIdentifier(categoryIdentifier),
                               _metaLabel.text ?: @""];
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self setNeedsLayout];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _cardView.transform = CGAffineTransformIdentity;
        return;
    }

    CGAffineTransform target = highlighted ? CGAffineTransformMakeScale(0.988, 0.988) : CGAffineTransformIdentity;
    NSTimeInterval duration = highlighted ? 0.10 : 0.22;
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:options
                     animations:^{
        self->_cardView.transform = target;
    } completion:nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_cardView.bounds cornerRadius:26.0].CGPath;
    _chevronContainerView.layer.cornerRadius = CGRectGetWidth(_chevronContainerView.bounds) * 0.5;
    _glowView.layer.cornerRadius = CGRectGetWidth(_glowView.bounds) * 0.5;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _cardView.transform = CGAffineTransformIdentity;
    _avatarImageView.image = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _metaLabel.text = nil;
    _statusBadgeLabel.text = nil;
    _statusBadgeLabel.hidden = NO;
    self.accessibilityLabel = nil;
}

@end

@interface ProviderCompaniesListVC () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerContainerView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroLiquidBorderView;
@property (nonatomic, strong) UIView *heroGlowView;
@property (nonatomic, strong) UIView *heroOrbView;
@property (nonatomic, strong) UIView *heroIconShellView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) PPInsetLabel *heroCategoryBadgeLabel;
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
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *allEntries;
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *visibleEntries;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) PPProviderCompaniesLoadState loadState;
@property (nonatomic, strong, nullable) NSError *lastLoadError;
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
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_buildUI];
    [self pp_applyHeaderContent];
    [self loadProviders];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect frame = self.headerContainerView.frame;
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width > 0.0 && fabs(frame.size.width - width) > 0.5) {
        frame.size.width = width;
        self.headerContainerView.frame = frame;
        self.tableView.tableHeaderView = self.headerContainerView;
    }

    if (!CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        self.heroSurfaceView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.heroSurfaceView.bounds cornerRadius:34.0].CGPath;
        self.heroLiquidBorderView.layer.cornerRadius = 33.0;
    }

    if (!CGRectIsEmpty(self.heroIconShellView.bounds)) {
        self.heroIconShellView.layer.cornerRadius = CGRectGetWidth(self.heroIconShellView.bounds) * 0.5;
        self.heroGlowView.layer.cornerRadius = CGRectGetWidth(self.heroGlowView.bounds) * 0.5;
        self.heroOrbView.layer.cornerRadius = CGRectGetWidth(self.heroOrbView.bounds) * 0.5;
    }
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
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerClass:PPProviderCompanyCell.class forCellReuseIdentifier:@"PPProviderCompanyCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self pp_buildHeader];
    [self pp_buildStateView];
    [self pp_buildSearchController];
}

- (void)pp_buildHeader
{
    self.headerContainerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 196.0)];
    self.headerContainerView.backgroundColor = UIColor.clearColor;
    self.headerContainerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.84] ?: UIColor.whiteColor;
    self.heroSurfaceView.layer.cornerRadius = 34.0;
    self.heroSurfaceView.layer.borderWidth = 1.0;
    self.heroSurfaceView.layer.masksToBounds = NO;
    [self.heroSurfaceView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.64]];
    [self.heroSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.heroSurfaceView.layer.shadowOpacity = 0.07;
    self.heroSurfaceView.layer.shadowRadius = 24.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.headerContainerView addSubview:self.heroSurfaceView];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    if (@available(iOS 13.0, *)) {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.layer.cornerRadius = 34.0;
    blurView.layer.masksToBounds = YES;
    [self.heroSurfaceView addSubview:blurView];

    self.heroLiquidBorderView = [[UIView alloc] init];
    self.heroLiquidBorderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroLiquidBorderView.userInteractionEnabled = NO;
    self.heroLiquidBorderView.layer.borderWidth = 1.0;
    self.heroLiquidBorderView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroLiquidBorderView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroLiquidBorderView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.58]];
    [self.heroSurfaceView addSubview:self.heroLiquidBorderView];

    self.heroGlowView = [[UIView alloc] init];
    self.heroGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroGlowView.userInteractionEnabled = NO;
    self.heroGlowView.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.12];
    self.heroGlowView.alpha = 0.52;
    self.heroGlowView.layer.shadowColor = (AppPrimaryClr ?: UIColor.systemRedColor).CGColor;
    self.heroGlowView.layer.shadowOpacity = 0.12;
    self.heroGlowView.layer.shadowRadius = 22.0;
    self.heroGlowView.layer.shadowOffset = CGSizeZero;
    [self.heroSurfaceView addSubview:self.heroGlowView];

    self.heroOrbView = [[UIView alloc] init];
    self.heroOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroOrbView.userInteractionEnabled = NO;
    self.heroOrbView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.44];
    [self.heroSurfaceView addSubview:self.heroOrbView];

    self.heroIconShellView = [[UIView alloc] init];
    self.heroIconShellView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconShellView.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.08];
    self.heroIconShellView.layer.borderWidth = 1.0;
    self.heroIconShellView.layer.masksToBounds = YES;
    [self.heroIconShellView pp_setBorderColor:[AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.18]];
    [self.heroSurfaceView addSubview:self.heroIconShellView];

    self.heroIconView = [[UIImageView alloc] init];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroIconView.tintColor = AppPrimaryClr ?: UIColor.systemRedColor;
    [self.heroIconShellView addSubview:self.heroIconView];

    self.eyebrowLabel = [[UILabel alloc] init];
    self.eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eyebrowLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.eyebrowLabel.textColor = [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.56];
    self.eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.heroSurfaceView addSubview:self.eyebrowLabel];

    self.headerTitleLabel = [[UILabel alloc] init];
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.font = [GM boldFontWithSize:30.0] ?: [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
    self.headerTitleLabel.textColor = AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0];
    self.headerTitleLabel.numberOfLines = 2;
    self.headerTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.heroSurfaceView addSubview:self.headerTitleLabel];

    self.headerSubtitleLabel = [[UILabel alloc] init];
    self.headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerSubtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.headerSubtitleLabel.textColor = AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
    self.headerSubtitleLabel.numberOfLines = 2;
    self.headerSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.heroSurfaceView addSubview:self.headerSubtitleLabel];

    self.heroCategoryBadgeLabel = [[PPInsetLabel alloc] init];
    self.heroCategoryBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCategoryBadgeLabel.font = [GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    self.heroCategoryBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.heroCategoryBadgeLabel.adjustsFontForContentSizeCategory = YES;
    self.heroCategoryBadgeLabel.textInsets = UIEdgeInsetsMake(2.0, 12.0, 2.0, 12.0);
    self.heroCategoryBadgeLabel.layer.cornerRadius = 15.0;
    self.heroCategoryBadgeLabel.layer.masksToBounds = YES;
    self.heroCategoryBadgeLabel.layer.borderWidth = 1.0;
    [self.heroSurfaceView addSubview:self.heroCategoryBadgeLabel];

    self.countBadgeLabel = [[PPInsetLabel alloc] init];
    self.countBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countBadgeLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.countBadgeLabel.textColor = AppPrimaryClr ?: [UIColor colorWithRed:0.84 green:0.25 blue:0.22 alpha:1.0];
    self.countBadgeLabel.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.10];
    self.countBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.countBadgeLabel.textInsets = UIEdgeInsetsMake(3.0, 12.0, 3.0, 12.0);
    self.countBadgeLabel.layer.cornerRadius = 16.0;
    self.countBadgeLabel.layer.masksToBounds = YES;
    self.countBadgeLabel.layer.borderWidth = 1.0;
    [self.countBadgeLabel pp_setBorderColor:[AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.16]];
    [self.heroSurfaceView addSubview:self.countBadgeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.headerContainerView.topAnchor constant:16.0],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.headerContainerView.leadingAnchor constant:20.0],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.headerContainerView.trailingAnchor constant:-20.0],
        [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.headerContainerView.bottomAnchor constant:-10.0],

        [blurView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [self.heroLiquidBorderView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:1.0],
        [self.heroLiquidBorderView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:1.0],
        [self.heroLiquidBorderView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-1.0],
        [self.heroLiquidBorderView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-1.0],

        [self.heroGlowView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.heroGlowView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-28.0],
        [self.heroGlowView.widthAnchor constraintEqualToConstant:92.0],
        [self.heroGlowView.heightAnchor constraintEqualToConstant:92.0],

        [self.heroOrbView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:32.0],
        [self.heroOrbView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-42.0],
        [self.heroOrbView.widthAnchor constraintEqualToConstant:66.0],
        [self.heroOrbView.heightAnchor constraintEqualToConstant:66.0],

        [self.heroIconShellView.centerYAnchor constraintEqualToAnchor:self.heroSurfaceView.centerYAnchor],
        [self.heroIconShellView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-22.0],
        [self.heroIconShellView.widthAnchor constraintEqualToConstant:82.0],
        [self.heroIconShellView.heightAnchor constraintEqualToConstant:82.0],

        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconShellView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconShellView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:34.0],
        [self.heroIconView.heightAnchor constraintEqualToConstant:34.0],

        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:20.0],
        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:22.0],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.countBadgeLabel.leadingAnchor constant:-12.0],

        [self.countBadgeLabel.centerYAnchor constraintEqualToAnchor:self.eyebrowLabel.centerYAnchor],
        [self.countBadgeLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.countBadgeLabel.heightAnchor constraintEqualToConstant:32.0],
        [self.countBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:96.0],

        [self.headerTitleLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:10.0],
        [self.headerTitleLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.headerTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconShellView.leadingAnchor constant:-18.0],

        [self.headerSubtitleLabel.topAnchor constraintEqualToAnchor:self.headerTitleLabel.bottomAnchor constant:8.0],
        [self.headerSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.headerTitleLabel.leadingAnchor],
        [self.headerSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.headerTitleLabel.trailingAnchor],

        [self.heroCategoryBadgeLabel.topAnchor constraintEqualToAnchor:self.headerSubtitleLabel.bottomAnchor constant:16.0],
        [self.heroCategoryBadgeLabel.leadingAnchor constraintEqualToAnchor:self.headerSubtitleLabel.leadingAnchor],
        [self.heroCategoryBadgeLabel.heightAnchor constraintEqualToConstant:30.0],
        [self.heroCategoryBadgeLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-18.0]
    ]];

    self.tableView.tableHeaderView = self.headerContainerView;
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
    self.searchController.searchBar.placeholder = kLang(@"provider_companies_search_placeholder") ?: @"Search providers";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
}

- (void)pp_applyHeaderContent
{
    NSString *title = self.selectedProviderCategoryTitleKey.length > 0
        ? (kLang(self.selectedProviderCategoryTitleKey) ?: PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier))
        : PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    NSString *subtitle = self.selectedProviderCategorySubtitleKey.length > 0
        ? (kLang(self.selectedProviderCategorySubtitleKey) ?: PPProviderCompaniesSubtitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier))
        : PPProviderCompaniesSubtitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);

    self.eyebrowLabel.text = PPProviderCompaniesSectionTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    self.headerTitleLabel.text = title;
    self.headerSubtitleLabel.text = subtitle;
    self.heroCategoryBadgeLabel.text = title;
    self.heroCategoryBadgeLabel.textColor = AppPrimaryClr ?: UIColor.systemRedColor;
    self.heroCategoryBadgeLabel.backgroundColor = [AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.08];
    [self.heroCategoryBadgeLabel pp_setBorderColor:[AppPrimaryClr ?: UIColor.systemRedColor colorWithAlphaComponent:0.16]];
    self.countBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", PPProviderCompaniesCountText(self.visibleEntries.count, self.selectedProviderCategoryIdentifier)];

    if (@available(iOS 13.0, *)) {
        self.heroIconView.image = [[UIImage systemImageNamed:PPProviderCompaniesSymbolNameForCategoryIdentifier(self.selectedProviderCategoryIdentifier)
                                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:34.0
                                                                                                         weight:UIImageSymbolWeightSemibold]]
                                  imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        self.heroIconView.image = [UIImage imageNamed:PPProviderCompaniesSymbolNameForCategoryIdentifier(self.selectedProviderCategoryIdentifier)];
    }
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
        }
    });
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

- (void)pp_applySearchFilter
{
    NSString *query = PPProviderCompaniesNormalizedIdentifier(self.searchQuery);
    if (query.length == 0) {
        self.visibleEntries = self.allEntries ?: @[];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PPProviderCompanyEntry *entry, NSDictionary *bindings) {
            NSString *displayName = [[self pp_displayNameForEntry:entry] lowercaseString];
            NSString *about = [PPProviderCompaniesSafeString(entry.user.UserAbout) lowercaseString];
            return [displayName containsString:query] || [about containsString:query];
        }];
        self.visibleEntries = [self.allEntries filteredArrayUsingPredicate:predicate] ?: @[];
    }

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
    self.stateContainerView.hidden = (state == PPProviderCompaniesLoadStateLoaded);
    self.tableView.hidden = (state == PPProviderCompaniesLoadStateLoading ||
                             state == PPProviderCompaniesLoadStateEmpty ||
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
            self.tableView.hidden = YES;
            self.stateIconView.hidden = NO;
            BOOL isSearching = (PPProviderCompaniesNormalizedIdentifier(self.searchQuery).length > 0 && self.allEntries.count > 0);
            if (@available(iOS 13.0, *)) {
                NSString *iconName = isSearching
                    ? @"magnifyingglass"
                    : (PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier) ? @"cross.case" : @"shippingbox");
                self.stateIconView.image = [[UIImage systemImageNamed:iconName
                                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:40.0
                                                                                                              weight:UIImageSymbolWeightRegular]]
                                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            if (isSearching) {
                self.stateTitleLabel.text = kLang(@"provider_companies_no_results_title") ?: @"No matching providers";
                self.stateSubtitleLabel.text = kLang(@"provider_companies_no_results_subtitle") ?: @"Try a different name or clear the search.";
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
    return 152.0;
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

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    self.searchQuery = PPProviderCompaniesSafeString(searchController.searchBar.text);
    [self pp_applySearchFilter];
}

@end
