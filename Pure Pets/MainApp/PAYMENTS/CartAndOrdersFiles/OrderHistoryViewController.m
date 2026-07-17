//
//  OrderHistoryViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/06/2025.
//

#import "OrderHistoryViewController.h"
#import "OrderCell.h"
#import "PPOrderStatusAppearance.h"
#import "OrderDetailsViewController.h"
#import "PPMarketplaceHeroCardStyle.h"
#import "PPOrder.h"
#import "UserManager.h"
#import "AppClasses.h"
#import "PPEmptyStateHelper.h"
#import "ChManager.h"
#import "CountryModel.h"
#import "PPS.h"
#import "CartManager.h"
#import "PPBackgroundView.h"
#import "PPOrderSupportComposerViewController.h"

#import <QuartzCore/QuartzCore.h>
@import FirebaseAuth;
@import FirebaseFirestore;

static NSString * const kOrderHistoryCellID = @"OrderCell";
static NSInteger const kOrderHistoryPageSize = 12;
static CGFloat const kOrderHistoryRowHeight = 128.0;
static CGFloat const kOrderHistoryContentBottomInset = 132.0;
//static NSString * const kOrderSupportPhoneNumber = @"+97459997720";

static NSString * const kOrderHistoryFilterAll = @"all";
static NSString * const kOrderHistoryFilterPending = @"pending";
static NSString * const kOrderHistoryFilterPaid = @"paid";
static NSString * const kOrderHistoryFilterProcessing = @"processing";
static NSString * const kOrderHistoryFilterShipped = @"shipped";
static NSString * const kOrderHistoryFilterDelivered = @"delivered";
static NSString * const kOrderHistoryFilterCancelled = @"cancelled";
static NSString * const kOrderHistoryFilterFailed = @"failed";

static NSString *PPOrderHistoryTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPOrderHistoryNormalizedStatus(id value)
{
    NSString *status = [[PPOrderHistoryTrimmedString(value) lowercaseString] copy];
    if (status.length == 0) return @"";
    status = [status stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    status = [status stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([status containsString:@"__"]) {
        status = [status stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return status;
}

static BOOL PPOrderHistoryStatusMatchesAnyKeyword(NSString *statusKey, NSArray<NSString *> *keywords)
{
    if (statusKey.length == 0 || keywords.count == 0) return NO;

    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", statusKey];
    for (NSString *keyword in keywords) {
        NSString *normalizedKeyword = PPOrderHistoryNormalizedStatus(keyword);
        if (normalizedKeyword.length == 0) continue;

        if ([statusKey isEqualToString:normalizedKeyword]) return YES;
        if ([normalizedKeyword containsString:@"_"]) {
            if ([statusKey containsString:normalizedKeyword]) return YES;
        } else {
            NSString *wrappedKeyword = [NSString stringWithFormat:@"_%@_", normalizedKeyword];
            if ([wrappedStatus containsString:wrappedKeyword]) return YES;
        }
    }
    return NO;
}

static NSString *PPOrderHistoryCanonicalFilterKeyForStatus(NSString *statusKey)
{
    NSString *normalized = PPOrderHistoryNormalizedStatus(statusKey);
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"cancelled", @"canceled"])) {
        return kOrderHistoryFilterCancelled;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"failed", @"rejected", @"declined", @"expired", @"error", @"voided", @"returned_to_store"])) {
        return kOrderHistoryFilterFailed;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"delivered", @"completed", @"fulfilled", @"payment_pending", @"payment_confirmed"])) {
        return kOrderHistoryFilterDelivered;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"shipped", @"shipping", @"out_for_delivery", @"in_transit", @"picked_up"])) {
        return kOrderHistoryFilterShipped;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"processing", @"preparing", @"packed", @"confirmed", @"ready_to_ship", @"delivery_requested", @"delivery_assigned", @"awaiting_handover", @"delivery_reassigned"])) {
        return kOrderHistoryFilterProcessing;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"paid", @"success", @"approved", @"verified", @"captured", @"authorized"])) {
        return kOrderHistoryFilterPaid;
    }
    return kOrderHistoryFilterPending;
}

#pragma mark - PPPassThroughHeaderContainer (Custom passthrough view to avoid touch blocking)

@interface PPPassThroughHeaderContainer : UIView
@end

@implementation PPPassThroughHeaderContainer

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // Traverse subviews in reverse order to check interactive hits (searchContainer, heroCard, etc.)
    for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
        if (!subview.hidden && subview.userInteractionEnabled && subview.alpha > 0.01) {
            CGPoint localPoint = [self convertPoint:point toView:subview];
            if ([subview pointInside:localPoint withEvent:event]) {
                return YES;
            }
        }
    }
    return NO;
}

@end

#pragma mark - OrderHistoryViewController Private Interface

@interface OrderHistoryViewController () <UITableViewDataSource, UITableViewDelegate, PPSDelegate, UIScrollViewDelegate>

// Passthrough header layout
@property (nonatomic, strong) PPPassThroughHeaderContainer *headerContainer;

// Hero Card views
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIButton *searchToggleButton;
@property (nonatomic, assign) BOOL searchExpanded;
@property (nonatomic, strong) PPBackgroundView *heroGlassBackground;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;

// Metrics display panel
@property (nonatomic, strong) UIView *summaryPanel;
@property (nonatomic, strong) UIVisualEffectView *summaryBlurView;
@property (nonatomic, strong) UIView *summaryDividerView;
@property (nonatomic, strong) UILabel *ordersMetricValueLabel;
@property (nonatomic, strong) UILabel *ordersMetricCaptionLabel;
@property (nonatomic, strong) UILabel *spentMetricValueLabel;
@property (nonatomic, strong) UILabel *spentMetricCaptionLabel;
@property (nonatomic, strong) UILabel *activeMetricLabel;

// Main table and search
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) UILabel *filterSummaryLabel;

// Loaders and configs
@property (nonatomic, strong) UIActivityIndicatorView *initialLoader;
@property (nonatomic, strong) UIActivityIndicatorView *paginationLoader;
@property (nonatomic, strong) PPEmptyStateConfig *emptyStateConfig;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, assign) CGFloat fixedHeaderHeight;

// Data state variables
@property (nonatomic, strong) NSMutableArray<PPOrder *> *orders;
@property (nonatomic, strong) NSArray<PPOrder *> *displayedOrders;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *accessoryCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *inFlightAccessoryIDs;
@property (nonatomic, strong, nullable) FIRDocumentSnapshot *lastDocument;

@property (nonatomic, copy) NSString *selectedStatusFilterKey;
@property (nonatomic, assign) NSInteger pageSize;
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, assign) BOOL isFetchingInitial;
@property (nonatomic, assign) BOOL isFetchingMore;
@property (nonatomic, assign) BOOL hasMorePages;
@property (nonatomic, assign) BOOL didPrepareHeroEntrance;
@property (nonatomic, assign) BOOL didRunHeroEntrance;
@property (nonatomic, assign) BOOL didCaptureNavigationBarHiddenState;
@property (nonatomic, assign) BOOL previousNavigationBarHiddenState;
@property (nonatomic, strong) NSDateFormatter *orderDateFormatter;
@property (nonatomic, copy, nullable) dispatch_block_t loadingTimeoutBlock;
@property (nonatomic, copy, nullable) NSString *lastFetchErrorMessage;

@end

#pragma mark - OrderHistoryViewController Implementation

@implementation OrderHistoryViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupDefaults];
    [self setupViews];
    [self fetchOrdersReset:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_applyNavigationPresentationForCurrentContextAnimated:animated];
    [self pp_prepareHeroEntranceIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_restoreNavigationBarPresentationIfNeededAnimated:animated];
    [self.heroGlassBackground stopAnimations];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_runHeroEntranceIfNeeded];
    [self.heroGlassBackground startAnimations];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutViews];
    [self pp_prepareHeroEntranceIfNeeded];
}

- (void)dealloc
{
    [self.heroGlassBackground stopAnimations];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self.heroGlassBackground stopAnimations];
    [self.heroGlassBackground reapplyPalette];
    [self.heroGlassBackground startAnimations];
    [self pp_applyHeroMaterialWithAccent:[self pp_currentHeroAccentColor]];
}

#pragma mark - Setup

- (void)setupDefaults
{
    self.pageSize = kOrderHistoryPageSize;
    self.searchText = @"";
    self.selectedStatusFilterKey = kOrderHistoryFilterAll;
    self.hasMorePages = YES;
    self.isFetchingInitial = NO;
    self.isFetchingMore = NO;
    self.fixedHeaderHeight = 0.0;
    self.searchExpanded = NO;
    self.orders = [NSMutableArray array];
    self.displayedOrders = @[];
    self.accessoryCache = [NSMutableDictionary dictionary];
    self.inFlightAccessoryIDs = [NSMutableSet set];
    self.orderDateFormatter = [[NSDateFormatter alloc] init];
    self.orderDateFormatter.locale = [NSLocale currentLocale];
    [self.orderDateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM yyyy h:mm a"];
    self.view.backgroundColor = AppBackgroundClr;
    [self emptyViewConfiger];
}

- (void)setupNavigationBar
{
    BOOL showBack = (self.navigationController.viewControllers.count > 1);
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"OrderHistory") showBack:showBack];

    UIButton *supportButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"headphones.dots" target:self action:@selector(contactSupportTapped)];
    UIButton *refreshButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"arrow.clockwise" target:self action:@selector(refreshOrders)];
    UIBarButtonItem *supportItem = [[UIBarButtonItem alloc] initWithCustomView:supportButton];
    UIBarButtonItem *refreshItem = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
    self.navigationItem.rightBarButtonItems = @[refreshItem, supportItem];
}

- (BOOL)pp_isPresentedAsRootTab
{
    return self.tabBarController != nil &&
    self.navigationController != nil &&
    self.navigationController.viewControllers.firstObject == self;
}

- (void)pp_applyNavigationPresentationForCurrentContextAnimated:(BOOL)animated
{
    if ([self pp_isPresentedAsRootTab]) {
        if (!self.didCaptureNavigationBarHiddenState) {
            self.previousNavigationBarHiddenState = self.navigationController.navigationBarHidden;
            self.didCaptureNavigationBarHiddenState = YES;
        }
        [self.navigationController setNavigationBarHidden:YES animated:animated];
        self.navigationItem.rightBarButtonItems = nil;
        return;
    }

    [self pp_restoreNavigationBarPresentationIfNeededAnimated:NO];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self setupNavigationBar];
    
    // Transparent navigation bar for clean layering overlay
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    } else {
        [self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
        [self.navigationController.navigationBar setShadowImage:[[UIImage alloc] init]];
    }
}

- (void)pp_restoreNavigationBarPresentationIfNeededAnimated:(BOOL)animated
{
    if (!self.didCaptureNavigationBarHiddenState || !self.navigationController) {
        return;
    }
    [self.navigationController setNavigationBarHidden:self.previousNavigationBarHiddenState animated:animated];
    self.didCaptureNavigationBarHiddenState = NO;
}

- (void)emptyViewConfiger
{
    self.emptyStateConfig = [PPEmptyStateConfig new];
    self.emptyStateConfig.animationName = @""; 
    self.emptyStateConfig.isNetworkFile = NO;
    self.emptyStateConfig.buttonTitle = kLang(@"empty_retry_button");
    self.emptyStateConfig.target = self;
    self.emptyStateConfig.action = @selector(refreshOrders);
}

- (void)setupViews
{
    [self setupBackdrop];

    UITableViewStyle tableStyle = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        tableStyle = UITableViewStyleInsetGrouped;
    }

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:tableStyle];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = AppClearClr;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = kOrderHistoryRowHeight;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.layoutMargins = UIEdgeInsetsZero;
    self.tableView.separatorInset = UIEdgeInsetsZero;
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, kOrderHistoryContentBottomInset, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        self.tableView.insetsContentViewsToSafeArea = NO;
    }
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:[OrderCell class] forCellReuseIdentifier:kOrderHistoryCellID];
    [self.view addSubview:self.tableView];

    [self setupHeroHeader];

    self.searchView = [[PPS alloc] initWithFrame:CGRectZero];
    self.searchView.delegate = self;
    self.searchView.blurEnabled = NO;
    self.searchView.shadowEnabled = NO;
    self.searchView.debounceInterval = 0.16;
    self.searchView.fuzzyEnabled = YES;
    self.searchView.caseInsensitive = YES;
    self.searchView.diacriticsInsensitive = YES;
    self.searchView.minRelevanceScore = 0.35;
    self.searchView.maxResults = 120;
    self.searchView.showsPrimaryButton = YES;
    self.searchView.showsSecondaryButton = NO;
    self.searchView.backgroundColor = AppClearClr;
    self.searchView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.searchView.textField.placeholder = kLang(@"SearchHere");
    self.searchView.textField.textAlignment = [Language alignmentForCurrentLanguage];

    UIImage *filterImage = nil;
    if (@available(iOS 13.0, *)) {
        filterImage = [UIImage pp_symbolNamed:@"circle.grid.2x2.topleft.checkmark.filled"
                                pointSize:18
                                   weight:UIImageSymbolWeightSemibold
                                    scale:UIImageSymbolScaleLarge
                                  palette:@[UIColor.grayColor, AppPrimaryClr]
                             makeTemplate:YES];
    }
    [self.searchView configurePrimaryButtonWithImage:filterImage
                                              target:self
                                              action:@selector(presentStatusFilterFallbackMenu)];
    [self.heroSurfaceView addSubview:self.searchView];

    self.filterSummaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.filterSummaryLabel.font = [GM MidFontWithSize:12];
    self.filterSummaryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.filterSummaryLabel.textColor = UIColor.secondaryLabelColor;
    [self.heroSurfaceView addSubview:self.filterSummaryLabel];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshOrders) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    self.initialLoader = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.initialLoader.color = [GM appPrimaryColor];
    self.initialLoader.hidesWhenStopped = YES;
    [self.view addSubview:self.initialLoader];

    self.paginationLoader = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.paginationLoader.color = [GM appPrimaryColor];
    self.paginationLoader.hidesWhenStopped = YES;

    [self refreshStatusFilterMenu];
    [self refreshHeroHeader];
    [self pp_prepareHeroEntranceIfNeeded];
}

- (void)layoutViews
{
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;

    self.tableView.frame = self.view.bounds;
    [self layoutHeroHeader];
    [self pp_applyPremiumBottomContentInset];
    [self.view bringSubviewToFront:self.headerContainer];
    [self.view bringSubviewToFront:self.initialLoader];
    self.initialLoader.center = self.view.center;
}

- (void)pp_applyPremiumBottomContentInset
{
    if (!self.tableView) {
        return;
    }
    CGFloat fixedHeaderClearance = self.fixedHeaderHeight > 0.0 ? self.fixedHeaderHeight + 2.0 : 4.0;
    UIEdgeInsets contentInset = self.tableView.contentInset;
    contentInset.top = MAX(4.0, fixedHeaderClearance);
    contentInset.bottom = MAX(contentInset.bottom, kOrderHistoryContentBottomInset);
    self.tableView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;
    indicatorInset.top = MAX(4.0, fixedHeaderClearance);
    indicatorInset.bottom = MAX(indicatorInset.bottom, kOrderHistoryContentBottomInset);
    self.tableView.scrollIndicatorInsets = indicatorInset;
}

- (void)setupBackdrop
{
    [self pp_setupBackgroundGlows];
}

- (void)pp_setupBackgroundGlows {
    UIView *glow1 = [UIView new];
    glow1.translatesAutoresizingMaskIntoConstraints = NO;
    glow1.backgroundColor = [bageColor colorWithAlphaComponent:0.026];
    glow1.layer.cornerRadius = 88.0;
    glow1.clipsToBounds = YES;
    [self.view addSubview:glow1];

    UIView *glow2 = [UIView new];
    glow2.translatesAutoresizingMaskIntoConstraints = NO;
    glow2.backgroundColor = [UIColor.systemPurpleColor colorWithAlphaComponent:0.018];
    glow2.layer.cornerRadius = 110.0;
    glow2.clipsToBounds = YES;
    [self.view addSubview:glow2];

    UIView *glow3 = [UIView new];
    glow3.translatesAutoresizingMaskIntoConstraints = NO;
    glow3.backgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.024];
    glow3.layer.cornerRadius = 80.0;
    glow3.clipsToBounds = YES;
    [self.view addSubview:glow3];

    UIBlurEffect *blurEffect;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    //UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    //blurView.translatesAutoresizingMaskIntoConstraints = NO;
    //[self.view addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [glow1.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [glow1.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:26.0],
        [glow1.widthAnchor constraintEqualToConstant:176.0],
        [glow1.heightAnchor constraintEqualToConstant:176.0],

        [glow2.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [glow2.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-28.0],
        [glow2.widthAnchor constraintEqualToConstant:220.0],
        [glow2.heightAnchor constraintEqualToConstant:220.0],

        [glow3.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [glow3.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-160.0],
        [glow3.widthAnchor constraintEqualToConstant:160.0],
        [glow3.heightAnchor constraintEqualToConstant:160.0],

      
    ]];
}

- (void)setupHeroHeader
{
    // Passthrough container initialization to prevent empty spaces from blocking touches
    self.headerContainer = [[PPPassThroughHeaderContainer alloc] initWithFrame:CGRectZero];
    self.headerContainer.backgroundColor = UIColor.clearColor;

    // Hero Card Shadow Container
    self.heroCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroCard.backgroundColor = UIColor.clearColor;
    self.heroCard.isAccessibilityElement = YES;
    self.heroCard.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.heroCard.layer.cornerRadius = 30.0;
    self.heroCard.layer.masksToBounds = NO;
    [self.heroCard pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:0.22]];
    self.heroCard.layer.shadowOpacity = 0.11;
    self.heroCard.layer.shadowRadius = 24.0;
    self.heroCard.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        self.heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.headerContainer addSubview:self.heroCard];

    // Card Surface View (Continuous corners)
    self.heroSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroSurfaceView.layer.cornerRadius = 30.0;
    self.heroSurfaceView.layer.masksToBounds = YES;
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        self.heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroCard addSubview:self.heroSurfaceView];

    // Complete hero-card background. Keep all legacy blur/gradient/orb material out
    // of this surface so PPBackgroundView is the single background source.
    PPBackgroundView *glass = [PPBackgroundView new];
    [self.heroSurfaceView insertSubview:glass atIndex:0];
    self.heroGlassBackground = glass;

    // Search Toggle Button (replaces trail icon)
    self.searchToggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.searchToggleButton.layer.cornerRadius = 22.0;
    self.searchToggleButton.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"cart"];
        [self.searchToggleButton setImage:img forState:UIControlStateNormal];
        self.searchToggleButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
   // [self.searchToggleButton addTarget:self action:@selector(searchToggleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.heroSurfaceView addSubview:self.searchToggleButton];

    UIBlurEffect *btnBlur;
    if (@available(iOS 13.0, *)) {
        btnBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        btnBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    UIVisualEffectView *btnBlurView = [[UIVisualEffectView alloc] initWithEffect:btnBlur];
    btnBlurView.frame = CGRectMake(0.0, 0.0, 44.0, 44.0);
    btnBlurView.userInteractionEnabled = NO;
    btnBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.searchToggleButton insertSubview:btnBlurView atIndex:0];

    self.heroEyebrowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroEyebrowLabel.font = [GM boldFontWithSize:11.0];
    self.heroEyebrowLabel.textColor = UIColor.secondaryLabelColor;
    self.heroEyebrowLabel.numberOfLines = 1;
    self.heroEyebrowLabel.adjustsFontSizeToFitWidth = YES;
    self.heroEyebrowLabel.minimumScaleFactor = 0.78;
    self.heroEyebrowLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroSurfaceView addSubview:self.heroEyebrowLabel];

    self.heroTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroTitleLabel.font = [GM boldFontWithSize:32.0];
    self.heroTitleLabel.textColor = UIColor.labelColor;
    self.heroTitleLabel.numberOfLines = 2;
    self.heroTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleLabel.minimumScaleFactor = 0.82;
    self.heroTitleLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroSurfaceView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroSubtitleLabel.font = [GM MidFontWithSize:14.5];
    self.heroSubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.numberOfLines = 3;
    self.heroSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroSurfaceView addSubview:self.heroSubtitleLabel];

    // Summary Metric Panel Container
    self.summaryPanel = [[UIView alloc] initWithFrame:CGRectZero];
    self.summaryPanel.backgroundColor = UIColor.clearColor;
    self.summaryPanel.layer.cornerRadius = 24.0;
    self.summaryPanel.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.summaryPanel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroSurfaceView addSubview:self.summaryPanel];

    // Transparent glass blur for the summary panel
    UIBlurEffect *summaryBlur;
    if (@available(iOS 13.0, *)) {
        summaryBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        summaryBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    self.summaryBlurView = [[UIVisualEffectView alloc] initWithEffect:summaryBlur];
    self.summaryBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.summaryPanel addSubview:self.summaryBlurView];

    self.summaryDividerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.summaryDividerView.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.45];
    [self.summaryPanel addSubview:self.summaryDividerView];

    self.ordersMetricValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.ordersMetricValueLabel.font = [GM boldFontWithSize:36.0];
    self.ordersMetricValueLabel.textColor = UIColor.labelColor;
    self.ordersMetricValueLabel.adjustsFontSizeToFitWidth = YES;
    self.ordersMetricValueLabel.minimumScaleFactor = 0.7;
    self.ordersMetricValueLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.ordersMetricValueLabel];

    self.ordersMetricCaptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.ordersMetricCaptionLabel.font = [GM MidFontWithSize:13.0];
    self.ordersMetricCaptionLabel.textColor = UIColor.secondaryLabelColor;
    self.ordersMetricCaptionLabel.numberOfLines = 1;
    self.ordersMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
    self.ordersMetricCaptionLabel.minimumScaleFactor = 0.8;
    self.ordersMetricCaptionLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.ordersMetricCaptionLabel];

    self.spentMetricValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.spentMetricValueLabel.font = [GM boldFontWithSize:25.0];
    self.spentMetricValueLabel.textColor = UIColor.labelColor;
    self.spentMetricValueLabel.adjustsFontSizeToFitWidth = YES;
    self.spentMetricValueLabel.minimumScaleFactor = 0.66;
    self.spentMetricValueLabel.textAlignment = NSTextAlignmentRight;
    self.spentMetricValueLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.spentMetricValueLabel];

    self.spentMetricCaptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.spentMetricCaptionLabel.font = [GM MidFontWithSize:13.0];
    self.spentMetricCaptionLabel.textColor = UIColor.secondaryLabelColor;
    self.spentMetricCaptionLabel.textAlignment = NSTextAlignmentRight;
    self.spentMetricCaptionLabel.numberOfLines = 1;
    self.spentMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
    self.spentMetricCaptionLabel.minimumScaleFactor = 0.78;
    self.spentMetricCaptionLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.spentMetricCaptionLabel];

    self.activeMetricLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.activeMetricLabel.font = [GM boldFontWithSize:12.0];
    self.activeMetricLabel.textAlignment = NSTextAlignmentCenter;
    self.activeMetricLabel.layer.cornerRadius = 14.0;
    self.activeMetricLabel.layer.masksToBounds = YES;
    self.activeMetricLabel.adjustsFontSizeToFitWidth = YES;
    self.activeMetricLabel.minimumScaleFactor = 0.76;
    self.activeMetricLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.activeMetricLabel];

    [self.view addSubview:self.headerContainer];
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)layoutHeroHeader
{
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat safeTop = PPStatusBarHeight + 12.0;
    BOOL isRTL = ([Language languageVal] == 1);
    CGFloat horizontalMargin = 16.0;
    CGFloat cardWidth = MIN(MAX(0.0, width - (horizontalMargin * 2.0)), 720.0);
    CGFloat cardX = floor((width - cardWidth) * 0.5);
    CGFloat padding = 24.0;
    CGFloat contentWidth = MAX(0.0, cardWidth - (padding * 2.0));

    self.headerContainer.frame = CGRectMake(0.0, 0.0, width, 1.0);

    // Initial Layout sizing pass
    CGFloat textX = padding;
    CGFloat textWidth = MAX(0.0, contentWidth - 44.0 - 14.0);
    if (isRTL) {
        textX = padding + 44.0 + 14.0;
    }

    CGFloat toggleX = isRTL ? padding : cardWidth - padding - 44.0;
    self.searchToggleButton.frame = CGRectMake(toggleX, 24.0, 44.0, 44.0);

    self.heroEyebrowLabel.frame = CGRectMake(textX, 22.0, textWidth, 16.0);

    CGSize titleSize = [self.heroTitleLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    self.heroTitleLabel.frame = CGRectMake(textX,
                                           CGRectGetMaxY(self.heroEyebrowLabel.frame) + 5.0,
                                           textWidth,
                                           MAX(38.0, ceil(titleSize.height)));

    CGSize subtitleSize = [self.heroSubtitleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
    self.heroSubtitleLabel.frame = CGRectMake(padding,
                                              CGRectGetMaxY(self.heroTitleLabel.frame) + 8.0,
                                              contentWidth,
                                              MAX(20.0, ceil(subtitleSize.height)));

    CGFloat summaryY = MAX(CGRectGetMaxY(self.heroSubtitleLabel.frame) + 18.0,
                           CGRectGetMaxY(self.searchToggleButton.frame) + 18.0);
    self.summaryPanel.frame = CGRectMake(padding, summaryY, contentWidth, 116.0);
    self.summaryBlurView.frame = self.summaryPanel.bounds;

    CGFloat metricPadding = 16.0;
    CGFloat metricGap = 14.0;
    CGFloat metricColumnWidth = floor((contentWidth - (metricPadding * 2.0) - metricGap) * 0.5);

    CGFloat leadingMetricX = metricPadding;
    CGFloat trailingMetricX = contentWidth - metricPadding - metricColumnWidth;
    if (isRTL) {
        leadingMetricX = trailingMetricX;
        trailingMetricX = metricPadding;
    }

    self.ordersMetricValueLabel.frame = CGRectMake(leadingMetricX, 14.0, metricColumnWidth, 42.0);
    self.ordersMetricCaptionLabel.frame = CGRectMake(leadingMetricX,
                                                     CGRectGetMaxY(self.ordersMetricValueLabel.frame) + 2.0,
                                                     metricColumnWidth,
                                                     18.0);

    self.spentMetricValueLabel.frame = CGRectMake(trailingMetricX, 18.0, metricColumnWidth, 34.0);
    self.spentMetricCaptionLabel.frame = CGRectMake(trailingMetricX,
                                                    CGRectGetMaxY(self.spentMetricValueLabel.frame) + 4.0,
                                                    metricColumnWidth,
                                                    18.0);
    self.summaryDividerView.frame = CGRectMake(floor((contentWidth - 1.0) * 0.5),
                                               18.0,
                                               1.0,
                                               54.0);

    [self.activeMetricLabel sizeToFit];
    CGFloat badgeWidth = MIN(contentWidth - (metricPadding * 2.0),
                             MAX(124.0, CGRectGetWidth(self.activeMetricLabel.bounds) + 22.0));
    CGFloat badgeX = isRTL ? contentWidth - metricPadding - badgeWidth : metricPadding;
    self.activeMetricLabel.frame = CGRectMake(badgeX,
                                              CGRectGetHeight(self.summaryPanel.bounds) - 38.0,
                                              badgeWidth,
                                              28.0);

    // Inner Search Bar coordinates inside Card surface
    CGFloat searchY = CGRectGetMaxY(self.summaryPanel.frame) + 16.0;
    self.searchView.frame = CGRectMake(padding, searchY, contentWidth, 52.0);
    self.filterSummaryLabel.frame = CGRectMake(padding + 8.0,
                                               CGRectGetMaxY(self.searchView.frame) + 6.0,
                                               contentWidth - 16.0,
                                               16.0);

    CGFloat finalHeroHeight;
    if (self.searchExpanded) {
        finalHeroHeight = CGRectGetMaxY(self.filterSummaryLabel.frame) + 20.0;
        self.searchView.alpha = 1.0;
        self.filterSummaryLabel.alpha = 1.0;
    } else {
        finalHeroHeight = CGRectGetMaxY(self.summaryPanel.frame) + 20.0;
        self.searchView.alpha = 0.0;
        self.filterSummaryLabel.alpha = 0.0;
    }

    self.heroCard.frame = CGRectMake(cardX, safeTop, cardWidth, finalHeroHeight);
    self.heroSurfaceView.frame = self.heroCard.bounds;
    self.heroGlassBackground.frame = self.heroSurfaceView.bounds;

    self.headerContainer.frame = CGRectMake(0.0,
                                            0.0,
                                            width,
                                            CGRectGetMaxY(self.heroCard.frame) + 10.0);
    self.fixedHeaderHeight = CGRectGetHeight(self.headerContainer.bounds);

    self.heroCard.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroCard.bounds
                                                                cornerRadius:self.heroCard.layer.cornerRadius].CGPath;
    [self.view bringSubviewToFront:self.headerContainer];
}

- (void)refreshHeroHeader
{
    BOOL isRTL = ([Language languageVal] == 1);
    NSTextAlignment leadingAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    NSTextAlignment trailingAlignment = isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;

    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroEyebrowLabel.textAlignment = leadingAlignment;
    self.heroTitleLabel.textAlignment = leadingAlignment;
    self.heroSubtitleLabel.textAlignment = leadingAlignment;
    self.ordersMetricValueLabel.textAlignment = leadingAlignment;
    self.ordersMetricCaptionLabel.textAlignment = leadingAlignment;
    self.spentMetricValueLabel.textAlignment = trailingAlignment;
    self.spentMetricCaptionLabel.textAlignment = trailingAlignment;

    self.heroEyebrowLabel.text = kLang(@"order_history_hero_eyebrow");
    self.heroTitleLabel.text = kLang(@"OrderHistory");
    self.heroSubtitleLabel.text = kLang(@"order_history_hero_subtitle");

    NSArray<PPOrder *> *summaryOrders = [self pp_hasSearchOrFilter] ? self.displayedOrders : self.orders;
    NSInteger visibleCount = summaryOrders.count;
    NSInteger activeCount = [self activeOrdersCountForOrders:summaryOrders];
    double totalSpent = [self totalSpentForOrders:summaryOrders];
    NSString *currencyCode = [self preferredCurrencyCodeForOrders:summaryOrders];

    self.ordersMetricValueLabel.text = [NSString stringWithFormat:@"%ld", (long)visibleCount];
    self.ordersMetricCaptionLabel.text = kLang(@"order_history_metric_orders");
    self.spentMetricValueLabel.text = [self formattedSummaryAmount:totalSpent currency:currencyCode];
    self.spentMetricCaptionLabel.text = kLang(@"order_history_metric_spent");

    UIColor *accent = [self pp_currentHeroAccentColor];

    [self pp_applyHeroMaterialWithAccent:accent];
    self.summaryPanel.backgroundColor = [accent colorWithAlphaComponent:0.06];
    self.activeMetricLabel.backgroundColor = [accent colorWithAlphaComponent:0.14];
    self.activeMetricLabel.textColor = accent;
    

    
    NSString *scopeTitle = [self pp_hasSearchOrFilter] ? kLang(@"order_history_scope_filtered") : kLang(@"order_history_scope_all");
    self.activeMetricLabel.text = [NSString stringWithFormat:@"%@ • %@ %ld",
                                   scopeTitle.length > 0 ? scopeTitle : [self displayTitleForStatusFilterKey:self.selectedStatusFilterKey],
                                   kLang(@"order_history_metric_active"),
                                   (long)activeCount];
    
    self.heroCard.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@ %@. %@ %@.",
                                        self.heroTitleLabel.text ?: @"",
                                        self.heroSubtitleLabel.text ?: @"",
                                        self.ordersMetricCaptionLabel.text ?: @"",
                                        self.ordersMetricValueLabel.text ?: @"0",
                                        self.spentMetricCaptionLabel.text ?: @"",
                                        self.spentMetricValueLabel.text ?: @""];

    [self layoutHeroHeader];
    [self pp_applyPremiumBottomContentInset];
}

- (UIColor *)pp_currentHeroAccentColor
{
    return [self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll]
    ? ([GM appPrimaryColor] ?: AppPrimaryClr ?: UIColor.systemOrangeColor)
    : [self colorForStatusFilterKey:self.selectedStatusFilterKey];
}- (void)pp_applyHeroMaterialWithAccent:(UIColor *)accent
{
    UIColor *resolvedAccent = accent ?: ([GM appPrimaryColor] ?: AppPrimaryClr ?: UIColor.systemOrangeColor);
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    PPMarketplaceHeroCardApplySurfaceChrome(self.heroCard, 30.0, self.traitCollection);
    self.heroCard.layer.shadowOpacity = isDark ? 0.22 : 0.07;
    self.heroCard.layer.shadowRadius = isDark ? 18.0 : 20.0;
    self.heroCard.layer.shadowOffset = CGSizeMake(0.0, isDark ? 8.0 : 10.0);

    self.searchToggleButton.backgroundColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.18 : 0.105];
    [self.searchToggleButton pp_setBorderColor:[resolvedAccent colorWithAlphaComponent:isDark ? 0.20 : 0.16]];
    self.searchToggleButton.tintColor = resolvedAccent;

    self.heroSurfaceView.layer.borderWidth = 0.0;

    self.summaryDividerView.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:isDark ? 0.34 : 0.45];
    self.initialLoader.color = resolvedAccent;
    self.paginationLoader.color = resolvedAccent;
}

- (void)pp_prepareHeroEntranceIfNeeded
{
    if (self.didRunHeroEntrance || self.didPrepareHeroEntrance || !self.heroCard || !self.searchView) {
        return;
    }
    self.didPrepareHeroEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.didRunHeroEntrance = YES;
        self.heroCard.alpha = 1.0;
        self.searchView.alpha = 1.0;
        self.heroEyebrowLabel.alpha = 1.0;
        self.heroTitleLabel.alpha = 1.0;
        self.heroSubtitleLabel.alpha = 1.0;
        self.summaryPanel.alpha = 1.0;
        self.heroCard.transform = CGAffineTransformIdentity;
        self.searchView.transform = CGAffineTransformIdentity;
        self.heroEyebrowLabel.transform = CGAffineTransformIdentity;
        self.heroTitleLabel.transform = CGAffineTransformIdentity;
        self.heroSubtitleLabel.transform = CGAffineTransformIdentity;
        self.summaryPanel.transform = CGAffineTransformIdentity;
        return;
    }

    self.heroCard.alpha = 0.0;
    self.heroCard.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 12.0), 1.018, 1.018);
    self.searchView.alpha = 0.0;
    self.searchView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.filterSummaryLabel.alpha = 0.0;
    self.filterSummaryLabel.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.heroEyebrowLabel.alpha = 0.0;
    self.heroEyebrowLabel.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroTitleLabel.alpha = 0.0;
    self.heroTitleLabel.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.heroSubtitleLabel.alpha = 0.0;
    self.heroSubtitleLabel.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.summaryPanel.alpha = 0.0;
    self.summaryPanel.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
}

- (void)pp_runHeroEntranceIfNeeded
{
    if (self.didRunHeroEntrance || !self.heroCard || !self.searchView) {
        return;
    }
    [self pp_prepareHeroEntranceIfNeeded];
    self.didRunHeroEntrance = YES;
    [self.view layoutIfNeeded];

    [UIView animateWithDuration:0.44
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroCard.alpha = 1.0;
        self.heroCard.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.32
                          delay:0.06
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroEyebrowLabel.alpha = 1.0;
        self.heroEyebrowLabel.transform = CGAffineTransformIdentity;
        self.heroTitleLabel.alpha = 1.0;
        self.heroTitleLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSubtitleLabel.alpha = 1.0;
        self.heroSubtitleLabel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.48
                          delay:0.18
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.summaryPanel.alpha = 1.0;
        self.summaryPanel.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.25
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.searchView.alpha = 1.0;
        self.searchView.transform = CGAffineTransformIdentity;
        self.filterSummaryLabel.alpha = 1.0;
        self.filterSummaryLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (BOOL)pp_hasSearchOrFilter
{
    NSString *trimmedSearch = [self.searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmedSearch.length > 0 || ![self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll];
}

#pragma mark - Collapsing Header Scroll Interpolation

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Stopped collapse and fade scroll animation
}

#pragma mark - Search Expand/Collapse Action

- (void)searchToggleButtonTapped:(UIButton *)sender
{
    return;
    self.searchExpanded = !self.searchExpanded;

    // Smooth button icon rotate & morph transition
    [UIView transitionWithView:self.searchToggleButton
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
        if (@available(iOS 13.0, *)) {
            UIImage *image = self.searchExpanded
                ? [UIImage systemImageNamed:@"xmark"]
                : [UIImage systemImageNamed:@"magnifyingglass"];
            [self.searchToggleButton setImage:image forState:UIControlStateNormal];
        }
    } completion:nil];

    // Card expand/collapse spring animations
    [UIView animateWithDuration:0.52
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        [self layoutHeroHeader];
        [self pp_applyPremiumBottomContentInset];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (finished && self.searchExpanded) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    [self.searchView focus];
                } @catch (NSException *exception) {
                    NSLog(@"[PurePets] Focus exception caught: %@", exception);
                }
            });
        }
    }];

    if (!self.searchExpanded) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                [self.searchView unfocus];
            } @catch (NSException *exception) {
                NSLog(@"[PurePets] Unfocus exception caught: %@", exception);
            }
        });
    }
}

#pragma mark - Data Management

- (void)cancelLoadingTimeout
{
    if (self.loadingTimeoutBlock) {
        dispatch_block_cancel(self.loadingTimeoutBlock);
        self.loadingTimeoutBlock = nil;
    }
}

- (void)scheduleLoadingTimeout
{
    [self cancelLoadingTimeout];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.loadingTimeoutBlock = nil;

        if (strongSelf.initialLoader.isAnimating) {
            [strongSelf finishFetchingWithErrorMessage:nil reset:YES];
            [strongSelf showLoadingTimeoutErrorWithRetry];
        }
    });
    self.loadingTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);
}

- (void)showLoadingTimeoutErrorWithRetry
{
    if (self.presentedViewController) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"connection_timeout_title")
                                                                  message:kLang(@"connection_timeout_message")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"KLang_Retry")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [weakSelf fetchOrdersReset:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)fetchOrdersReset:(BOOL)reset
{
    if (reset) {
        if (self.isFetchingInitial) return;
        self.isFetchingInitial = YES;
        self.isFetchingMore = NO;
        self.hasMorePages = YES;
        self.lastDocument = nil;
        [self.orders removeAllObjects];
        [self.tableView reloadData];
        [self applyFiltersAndReload];
        [self.initialLoader startAnimating];
        [self scheduleLoadingTimeout];
    } else {
        if (self.isFetchingInitial || self.isFetchingMore || !self.hasMorePages || !self.lastDocument) return;
        self.isFetchingMore = YES;
        [self setPaginationLoading:YES];
    }

    NSString *userID = [self currentUserID];
    if (userID.length == 0) {
        [self finishFetchingWithErrorMessage:kLang(@"UserNotAuthenticated") reset:reset];
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query = [[db collectionWithPath:@"Orders"] queryWhereField:@"userId" isEqualTo:userID];
    query = [query queryOrderedByField:@"createdAt" descending:YES];
    if (!reset && self.lastDocument) {
        query = [query queryStartingAfterDocument:self.lastDocument];
    }
    query = [query queryLimitedTo:self.pageSize];

    __weak typeof(self) weakSelf = self;
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf handleOrdersSnapshot:snapshot error:error reset:reset];
        });
    }];
}

- (void)handleOrdersSnapshot:(FIRQuerySnapshot * _Nullable)snapshot error:(NSError * _Nullable)error reset:(BOOL)reset
{
    if (error) {
        [self finishFetchingWithErrorMessage:error.localizedDescription ?: kLang(@"Error") reset:reset];
        return;
    }

    NSArray<FIRDocumentSnapshot *> *documents = snapshot.documents ?: @[];
    self.hasMorePages = (documents.count >= self.pageSize);

    if (documents.count > 0) {
        self.lastDocument = documents.lastObject;
    } else if (reset) {
        self.lastDocument = nil;
    }

    if (reset) {
        [self.orders removeAllObjects];
    }

    for (FIRDocumentSnapshot *document in documents) {
        PPOrder *order = [PPOrder orderFromSnapshot:document];
        if (order) {
            [self.orders addObject:order];
        }
    }

    [self finishFetchingWithErrorMessage:nil reset:reset];
}

- (void)finishFetchingWithErrorMessage:(NSString * _Nullable)errorMessage reset:(BOOL)reset
{
    (void)reset;
    [self cancelLoadingTimeout];
    self.isFetchingInitial = NO;
    self.isFetchingMore = NO;
    [self.initialLoader stopAnimating];
    [self.refreshControl endRefreshing];
    [self setPaginationLoading:NO];

    self.lastFetchErrorMessage = errorMessage;
    [self applyFiltersAndReload];

    if (errorMessage.length > 0) {
        [self showErrorMessage:errorMessage];
    }
}

- (void)setPaginationLoading:(BOOL)loading
{
    if (!loading) {
        [self.paginationLoader stopAnimating];
        self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        return;
    }

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 44.0)];
    self.paginationLoader.center = CGPointMake(CGRectGetMidX(footer.bounds), CGRectGetMidY(footer.bounds));
    [footer addSubview:self.paginationLoader];
    [self.paginationLoader startAnimating];
    self.tableView.tableFooterView = footer;
}

- (NSString *)currentUserID
{
    NSString *userID = @"";
    id value = UserManager.sharedManager.currentUser.ID;
    if ([value isKindOfClass:NSString.class]) {
        userID = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (userID.length == 0) {
        userID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    return userID;
}

#pragma mark - Filter & Search Management

- (NSArray<NSDictionary *> *)statusFilterDefinitions
{
    return @[
        @{@"key": kOrderHistoryFilterAll, @"title": kLang(@"All")},
        @{@"key": kOrderHistoryFilterPending, @"title": kLang(@"Pending")},
        @{@"key": kOrderHistoryFilterPaid, @"title": kLang(@"Paid")},
        @{@"key": kOrderHistoryFilterProcessing, @"title": kLang(@"Processing")},
        @{@"key": kOrderHistoryFilterShipped, @"title": kLang(@"Shipped")},
        @{@"key": kOrderHistoryFilterDelivered, @"title": kLang(@"Delivered")},
        @{@"key": kOrderHistoryFilterCancelled, @"title": [self cancelledStatusTitle]},
        @{@"key": kOrderHistoryFilterFailed, @"title": kLang(@"Failed")}
    ];
}

- (NSString *)cancelledStatusTitle
{
    NSString *title = kLang(@"Canceled");
    if (![title isKindOfClass:NSString.class] || title.length == 0 || [title isEqualToString:@"Canceled"]) {
        title = kLang(@"order_request_status_cancelled");
    }
    return title.length > 0 ? title : @"Cancelled";
}

- (void)refreshStatusFilterMenu
{
    NSString *selectedTitle = [self displayTitleForStatusFilterKey:self.selectedStatusFilterKey];
    NSInteger count = [self countForStatusFilterKey:self.selectedStatusFilterKey];
    self.filterSummaryLabel.text = [NSString stringWithFormat:@"%@ • %ld", selectedTitle, (long)count];
    self.filterSummaryLabel.textColor = [self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll]
    ? UIColor.secondaryLabelColor
    : [GM appPrimaryColor];

    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
        __weak typeof(self) weakSelf = self;
        for (NSDictionary *filter in [self statusFilterDefinitions]) {
            NSString *key = PPOrderHistoryTrimmedString(filter[@"key"]);
            NSString *title = PPOrderHistoryTrimmedString(filter[@"title"]);
            NSInteger filterCount = [self countForStatusFilterKey:key];
            NSString *actionTitle = [NSString stringWithFormat:@"%@ (%ld)", title, (long)filterCount];
            UIAction *action = [UIAction actionWithTitle:actionTitle
                                                   image:nil
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
                (void)action;
                [weakSelf applyStatusFilterKey:key];
            }];
            action.state = [self.selectedStatusFilterKey isEqualToString:key] ? UIMenuElementStateOn : UIMenuElementStateOff;
            [actions addObject:action];
        }
        self.searchView.btn1.menu = [UIMenu menuWithTitle:@"" children:actions];
        self.searchView.btn1.showsMenuAsPrimaryAction = YES;
    }
}

- (void)applyStatusFilterKey:(NSString *)filterKey
{
    NSString *resolvedKey = PPOrderHistoryTrimmedString(filterKey);
    if (resolvedKey.length == 0) {
        resolvedKey = kOrderHistoryFilterAll;
    }
    self.selectedStatusFilterKey = resolvedKey;
    [self refreshStatusFilterMenu];
    [self applyFiltersAndReload];
}

- (NSInteger)countForStatusFilterKey:(NSString *)filterKey
{
    if (filterKey.length == 0 || [filterKey isEqualToString:kOrderHistoryFilterAll]) {
        return self.orders.count;
    }

    NSInteger count = 0;
    for (PPOrder *order in self.orders) {
        if ([[self canonicalStatusFilterKeyForOrder:order] isEqualToString:filterKey]) {
            count += 1;
        }
    }
    return count;
}

- (void)applyFiltersAndReload
{
    NSMutableArray<PPOrder *> *results = [NSMutableArray array];
    NSString *query = [self.searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    for (PPOrder *order in self.orders) {
        if (![self orderMatchesSelectedStatus:order]) continue;
        if (![self order:order matchesSearchQuery:query]) continue;
        [results addObject:order];
    }

    self.displayedOrders = results.copy;
    [self refreshStatusFilterMenu];
    [self refreshHeroHeader];
    [self updateEmptyState];
    [self.tableView reloadData];
}

- (BOOL)orderMatchesSelectedStatus:(PPOrder *)order
{
    if (!order) return NO;
    if (self.selectedStatusFilterKey.length == 0 ||
        [self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll]) {
        return YES;
    }
    return [[self canonicalStatusFilterKeyForOrder:order] isEqualToString:self.selectedStatusFilterKey];
}

- (BOOL)order:(PPOrder *)order matchesSearchQuery:(NSString *)query
{
    if (query.length == 0) return YES;
    if (!order) return NO;

    if ([self string:[order displayOrderReference] contains:query]) return YES;
    if ([self string:order.orderId contains:query]) return YES;
    if ([self string:order.transactionId contains:query]) return YES;
    if ([self string:order.paymentProvider contains:query]) return YES;
    if ([self string:order.failureReason contains:query]) return YES;
    if ([self string:[self displayTitleForOrder:order] contains:query]) return YES;
    if ([self string:[self displayTitleForStatusFilterKey:[self canonicalStatusFilterKeyForOrder:order]] contains:query]) return YES;
    if ([self string:[PPOrderHistoryTrimmedString(order.rawStatus) stringByReplacingOccurrencesOfString:@"_" withString:@" "] contains:query]) return YES;
    if ([self string:[self formattedAmountForOrder:order] contains:query]) return YES;
    if ([self string:[self formattedDate:order.createdAt] contains:query]) return YES;

    NSDictionary *snapshot = [order.shippingAddressSnapshot isKindOfClass:NSDictionary.class] ? order.shippingAddressSnapshot : nil;
    if (snapshot) {
        NSArray<NSString *> *snapshotKeys = @[@"displayName", @"address", @"addressLine1", @"addressLine2", @"locatioName", @"postalCode"];
        for (NSString *key in snapshotKeys) {
            if ([self string:PPOrderHistoryTrimmedString(snapshot[key]) contains:query]) {
                return YES;
            }
        }
    }

    for (id item in order.items ?: @[]) {
        if ([item isKindOfClass:NSString.class]) {
            if ([self string:PPOrderHistoryTrimmedString(item) contains:query]) return YES;
            continue;
        }
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *itemDict = (NSDictionary *)item;
        NSString *name = PPOrderHistoryTrimmedString(itemDict[@"name"] ?: itemDict[@"title"]);
        NSString *itemID = [self itemIDFromOrderItem:itemDict];
        if ([self string:name contains:query]) return YES;
        if ([self string:itemID contains:query]) return YES;
    }

    return NO;
}

- (BOOL)string:(NSString *)value contains:(NSString *)query
{
    if (query.length == 0) return YES;
    if (![value isKindOfClass:NSString.class] || value.length == 0) return NO;
    NSRange range = [value rangeOfString:query options:NSCaseInsensitiveSearch];
    return range.location != NSNotFound;
}

- (void)updateEmptyState
{
    if (self.isFetchingInitial) {
        [PPEmptyStateHelper removeEmptyStateFromListView:self.tableView];
        return;
    }

    if (self.displayedOrders.count > 0) {
        self.lastFetchErrorMessage = nil;
        [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                              dataCount:self.displayedOrders.count
                                                 config:self.emptyStateConfig];
        return;
    }

    BOOL isErrorState = (self.lastFetchErrorMessage.length > 0);
    NSString *trimmed = [self.searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasSearchOrFilter = (trimmed.length > 0 && ![trimmed isEqualToString:@""]) ||
    ![self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll];

    NSString *title;
    NSString *subTitle;
    NSString *buttonTitle;

    if (isErrorState) {
        title = kLang(@"load_error_title") ?: @"";
        if (![title isKindOfClass:NSString.class] || title.length == 0 || [title isEqualToString:@"load_error_title"]) {
            title = @"Unable to Load";
        }
        subTitle = kLang(@"load_error_retry") ?: @"";
        if (![subTitle isKindOfClass:NSString.class] || subTitle.length == 0 || [subTitle isEqualToString:@"load_error_retry"]) {
            subTitle = @"Something went wrong. Pull to refresh or tap Retry.";
        }
        buttonTitle = kLang(@"retry") ?: @"";
        if (![buttonTitle isKindOfClass:NSString.class] || buttonTitle.length == 0 || [buttonTitle isEqualToString:@"retry"]) {
            buttonTitle = kLang(@"empty_retry_button") ?: @"Retry";
        }
        self.emptyStateConfig.animationName = @"404.json";
        self.emptyStateConfig.isNetworkFile = NO;
    } else {
        title = hasSearchOrFilter ? kLang(@"empty_no_results_title") : kLang(@"NoOrders");
        if (![title isKindOfClass:NSString.class] || title.length == 0 || [title isEqualToString:@"NoOrders"]) {
            title = hasSearchOrFilter ? (kLang(@"empty_no_results_title") ?: @"") : (kLang(@"OrderHistory") ?: @"");
        }
        subTitle = hasSearchOrFilter ? (kLang(@"orders_empty_filtered") ?: @"") : @"";
        buttonTitle = kLang(@"empty_retry_button") ?: @"";
        self.emptyStateConfig.animationName = @"";
        self.emptyStateConfig.isNetworkFile = YES;
    }

    self.emptyStateConfig.title = title ?: @"";
    self.emptyStateConfig.subTitle = subTitle;
    self.emptyStateConfig.buttonTitle = buttonTitle;
    self.emptyStateConfig.target = self;
    self.emptyStateConfig.action = @selector(refreshOrders);

    [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                          dataCount:0
                                             config:self.emptyStateConfig];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return self.displayedOrders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OrderCell *cell = [tableView dequeueReusableCellWithIdentifier:kOrderHistoryCellID forIndexPath:indexPath];
    if (indexPath.row >= (NSInteger)self.displayedOrders.count) {
        NSLog(@"❌ [OrderHistory] displayedOrders out of bounds: row=%ld count=%lu", (long)indexPath.row, (unsigned long)self.displayedOrders.count);
        return cell;
    }
    PPOrder *order = self.displayedOrders[indexPath.row];
    [self configureCell:cell withOrder:order];
    return cell;
}

- (void)configureCell:(OrderCell *)cell withOrder:(PPOrder *)order
{
    if (!order || !cell) return;

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.clearColor;
    cell.preservesSuperviewLayoutMargins = NO;
    cell.layoutMargins = UIEdgeInsetsZero;
    
    NSString *statusKey = [self customerStatusKeyForOrder:order];
    NSString *statusText = [self displayTitleForOrder:order];
    
    cell.nameLabel.text = [order displayOrderReference];
    cell.quantityLabel.text = [self primaryDescriptionForOrder:order];
    cell.priceLabel.text = [self formattedAmountForOrder:order];
    cell.priceLabel.textColor = UIColor.labelColor;

    [cell configureStatusText:statusText ?: @""
                    statusKey:statusKey ?: @""
                     dateText:[self formattedDate:order.createdAt] ?: @""];

    NSInteger quantity = [self totalQuantityForOrder:order];
    if (quantity > 0 && cell.quantityLabel.text.length == 0) {
        cell.quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)quantity];
    }
    cell.itemImageView.image = [UIImage imageNamed:@"placeholder"];

    NSString *embeddedImageURL = [self firstEmbeddedImageURLForOrder:order];
    if (embeddedImageURL.length > 0) {
        [GM setImageFromUrlString:embeddedImageURL imageView:cell.itemImageView phImage:@"placeholder"];
        return;
    }

    NSString *firstItemID = [self firstItemIDForOrder:order];
    if (firstItemID.length == 0) return;

    NSDictionary *cached = self.accessoryCache[firstItemID];
    NSString *cachedImage = [self imageURLFromAccessoryData:cached];
    if (cachedImage.length > 0) {
        [GM setImageFromUrlString:cachedImage imageView:cell.itemImageView phImage:@"placeholder"];
        return;
    }

    [self fetchAccessoryPreviewForItemID:firstItemID orderID:order.orderId];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    (void)indexPath;
    return kOrderHistoryRowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.01;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return [[UIView alloc] initWithFrame:CGRectZero];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.01;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    (void)cell;
    if (self.displayedOrders.count == 0) return;
    if (indexPath.row >= (NSInteger)self.displayedOrders.count - 3) {
        [self fetchOrdersReset:NO];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.displayedOrders.count) return;
    PPOrder *selectedOrder = self.displayedOrders[indexPath.row];
    OrderDetailsViewController *detailsVC = [[OrderDetailsViewController alloc] initWithOrder:selectedOrder];
    detailsVC.order = selectedOrder;
    [self.navigationController pushViewController:detailsVC animated:YES];
}

#pragma mark - PPSDelegate

- (void)searchView:(PPS *)view didChangeText:(NSString *)text
{
    (void)view;
    self.searchText = text ?: @"";
    [self applyFiltersAndReload];
}

- (void)searchViewDidEndEditing:(PPS *)view
{
    self.searchText = view.textField.text ?: @"";
    [self applyFiltersAndReload];
}

- (void)searchViewDidSubmit:(PPS *)view
{
    [view unfocus];
}

#pragma mark - Actions

- (void)refreshOrders
{
    [self.searchView unfocus];
    [self fetchOrdersReset:YES];
}

- (void)presentStatusFilterFallbackMenu
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"OrderHistory")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *filter in [self statusFilterDefinitions]) {
        NSString *key = PPOrderHistoryTrimmedString(filter[@"key"]);
        NSString *title = PPOrderHistoryTrimmedString(filter[@"title"]);
        NSInteger count = [self countForStatusFilterKey:key];
        NSString *actionTitle = [NSString stringWithFormat:@"%@ (%ld)", title, (long)count];
        [sheet addAction:[UIAlertAction actionWithTitle:actionTitle
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction * _Nonnull action) {
            [self applyStatusFilterKey:key];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.searchView.btn1;
        sheet.popoverPresentationController.sourceRect = self.searchView.btn1.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)contactSupportTapped
{
    UIAlertController *menu = [UIAlertController
                               alertControllerWithTitle:kLang(@"cart_support_menu_title")
                               message:nil
                               preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *callAction = [UIAlertAction actionWithTitle:kLang(@"order_support_request_call")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses callPhoneNumber:kOrderSupportPhoneNumber fromViewController:self];
    }];
    [menu addAction:callAction];

    UIAlertAction *chatAction = [UIAlertAction actionWithTitle:kLang(@"cart_support_chat")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull action) {
        if (!UserManager.sharedManager.isUserLoggedIn) {
            [UserManager showPromptOnTopController];
            return;
        }
        [[ChManager sharedManager] openSupportChatFromController:self];
    }];
    [menu addAction:chatAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [menu addAction:cancelAction];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        UIBarButtonItem *sourceButton = self.navigationItem.leftBarButtonItem;
        if (sourceButton) {
            popover.barButtonItem = sourceButton;
        } else {
            popover.sourceView = self.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMinY(self.view.bounds) + 44.0, 1.0, 1.0);
        }
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:menu animated:YES completion:nil];
}

#pragma mark - Status Calculations & Mappings

- (NSString *)normalizedStatusKeyForOrder:(PPOrder *)order
{
    NSString *status = PPOrderHistoryNormalizedStatus([order effectiveDeliveryStatus]);
    if (status.length > 0) {
        return status;
    }

    status = PPOrderHistoryNormalizedStatus(order.rawStatus);
    if (status.length > 0) {
        return status;
    }

    switch (order.status) {
        case PPOrderStatusPaid:
            return kOrderHistoryFilterPaid;
        case PPOrderStatusFailed:
            return kOrderHistoryFilterFailed;
        case PPOrderStatusPending:
        default:
            return kOrderHistoryFilterPending;
    }
}

- (NSString *)canonicalStatusFilterKeyForOrder:(PPOrder *)order
{
    return PPOrderHistoryCanonicalFilterKeyForStatus([self normalizedStatusKeyForOrder:order]);
}

- (NSString *)customerStatusKeyForOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return @"preparing_for_shipment";
    }
    NSString *statusKey = PPOrderHistoryNormalizedStatus([order customerVisibleStatusKey]);
    return statusKey.length > 0 ? statusKey : @"preparing_for_shipment";
}

- (NSString *)displayTitleForCustomerStatusKey:(NSString *)statusKey
{
    NSString *key = PPOrderHistoryNormalizedStatus(statusKey);
    if ([key isEqualToString:@"pending"]) return kLang(@"order_placed_title") ?: kLang(@"Pending");
    if ([key isEqualToString:@"ready_for_delivery"]) return kLang(@"Ready for Delivery");
    if ([key isEqualToString:@"delivery_partner_assigned"]) return kLang(@"Delivery Partner Assigned");
    if ([key isEqualToString:@"on_the_way"]) return kLang(@"On the Way");
    if ([key isEqualToString:@"delivered"]) return kLang(@"Delivered");
    if ([key isEqualToString:@"completed"]) return kLang(@"Completed");
    if ([key isEqualToString:@"delivery_cancelled"]) return kLang(@"Delivery Cancelled");
    if ([key isEqualToString:@"delivery_delayed"]) return kLang(@"Delivery Delayed");
    return kLang(@"Preparing for Shipment");
}

- (NSString *)displayTitleForStatusFilterKey:(NSString *)filterKey
{
    NSString *key = PPOrderHistoryTrimmedString(filterKey);
    if ([key isEqualToString:kOrderHistoryFilterPending]) return kLang(@"Pending");
    if ([key isEqualToString:kOrderHistoryFilterPaid]) return kLang(@"Paid");
    if ([key isEqualToString:kOrderHistoryFilterProcessing]) return kLang(@"Processing");
    if ([key isEqualToString:kOrderHistoryFilterShipped]) return kLang(@"Shipped");
    if ([key isEqualToString:kOrderHistoryFilterDelivered]) return kLang(@"Delivered");
    if ([key isEqualToString:kOrderHistoryFilterCancelled]) return [self cancelledStatusTitle];
    if ([key isEqualToString:kOrderHistoryFilterFailed]) return kLang(@"Failed");
    return kLang(@"All");
}

- (NSString *)displayTitleForOrder:(PPOrder *)order
{
    return [self displayTitleForCustomerStatusKey:[self customerStatusKeyForOrder:order]];
}

- (UIColor *)statusColorForOrder:(PPOrder *)order
{
    return PPOrderStatusAccentColorForKey([self customerStatusKeyForOrder:order]);
}

- (UIColor *)colorForStatusFilterKey:(NSString *)filterKey
{
    return PPOrderStatusAccentColorForKey(filterKey);
}

#pragma mark - Accessory Preview Fetching

- (void)fetchAccessoryPreviewForItemID:(NSString *)itemID orderID:(NSString *)orderID
{
    if (itemID.length == 0) return;
    if (self.accessoryCache[itemID] != nil) return;
    if ([self.inFlightAccessoryIDs containsObject:itemID]) return;

    [self.inFlightAccessoryIDs addObject:itemID];
    __weak typeof(self) weakSelf = self;
    [self fetchAccessoryDataForID:itemID completion:^(NSDictionary * _Nullable data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.inFlightAccessoryIDs removeObject:itemID];
            if (!data) return;

            weakSelf.accessoryCache[itemID] = data;
            NSIndexPath *indexPath = [weakSelf indexPathForOrderID:orderID];
            if (!indexPath) return;
            if (indexPath.row >= weakSelf.displayedOrders.count) return;
            [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        });
    }];
}

- (void)fetchAccessoryDataForID:(NSString *)itemID completion:(void (^)(NSDictionary * _Nullable data))completion
{
    if (itemID.length == 0) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *primaryRef = [[db collectionWithPath:@"petAccessories"] documentWithPath:itemID];

    [primaryRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!error && snapshot.exists) {
            if (completion) completion([self normalizedAccessoryDataFromSnapshotData:snapshot.data]);
            return;
        }

        FIRDocumentReference *fallbackRef = [[db collectionWithPath:@"Accessories"] documentWithPath:itemID];
        [fallbackRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable fallbackSnapshot, NSError * _Nullable fallbackError) {
            if (fallbackError || !fallbackSnapshot.exists) {
                if (completion) completion(nil);
                return;
            }
            if (completion) completion([self normalizedAccessoryDataFromSnapshotData:fallbackSnapshot.data]);
        }];
    }];
}

- (NSDictionary *)normalizedAccessoryDataFromSnapshotData:(NSDictionary *)data
{
    if (![data isKindOfClass:NSDictionary.class]) return nil;

    NSString *name = PPOrderHistoryTrimmedString(data[@"name"]);
    if (name.length == 0) {
        name = PPOrderHistoryTrimmedString(data[@"title"]);
    }

    id rawPrice = data[@"finalPrice"] ?: data[@"price"];
    double price = [rawPrice respondsToSelector:@selector(doubleValue)] ? [rawPrice doubleValue] : 0.0;
    NSString *imageURL = [self imageURLFromAccessoryData:data];

    return @{
        @"name": name ?: @"",
        @"price": @(MAX(0.0, price)),
        @"imageURL": imageURL ?: @""
    };
}

- (NSString *)imageURLFromAccessoryData:(NSDictionary *)data
{
    if (![data isKindOfClass:NSDictionary.class]) return @"";

    NSArray<NSString *> *keys = @[@"image", @"imageURL", @"imageUrl", @"photo", @"icon"];
    for (NSString *key in keys) {
        NSString *value = PPOrderHistoryTrimmedString(data[key]);
        if (value.length > 0) return value;
    }

    id imageURLs = data[@"imageURLsArray"];
    if ([imageURLs isKindOfClass:NSArray.class]) {
        NSArray *arr = (NSArray *)imageURLs;
        if (arr.count > 0) {
            NSString *value = PPOrderHistoryTrimmedString(arr.firstObject);
            if (value.length > 0) return value;
        }
    }

    return @"";
}

- (NSIndexPath * _Nullable)indexPathForOrderID:(NSString *)orderID
{
    if (orderID.length == 0) return nil;

    NSUInteger index = [self.displayedOrders indexOfObjectPassingTest:^BOOL(PPOrder * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
        return [obj.orderId isEqualToString:orderID];
    }];
    if (index == NSNotFound) return nil;
    return [NSIndexPath indexPathForRow:index inSection:0];
}

#pragma mark - Formatting Utilities

- (NSString *)formattedAmountForOrder:(PPOrder *)order
{
    NSString *currency = PPOrderHistoryTrimmedString(order.currency);
    if (currency.length == 0) currency = PPOrderHistoryTrimmedString([CountryModel safeCurrentCurrencyCode]);
    if (currency.length == 0) currency = @"QAR";
    return [NSString stringWithFormat:@"%.2f %@", [self displayAmountValueForOrder:order], currency];
}

- (NSString *)formattedDate:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) return @"";
    return [self.orderDateFormatter stringFromDate:date];
}

- (NSString *)formattedSummaryAmount:(double)amount currency:(NSString *)currency
{
    NSString *resolvedCurrency = PPOrderHistoryTrimmedString(currency);
    if (resolvedCurrency.length == 0) {
        resolvedCurrency = PPOrderHistoryTrimmedString([CountryModel safeCurrentCurrencyCode]);
    }
    if (resolvedCurrency.length == 0) {
        resolvedCurrency = @"QAR";
    }
    return [NSString stringWithFormat:@"%.2f %@", MAX(0.0, amount), resolvedCurrency];
}

- (NSString *)preferredCurrencyCodeForOrders:(NSArray<PPOrder *> *)orders
{
    for (PPOrder *order in orders ?: @[]) {
        NSString *currency = PPOrderHistoryTrimmedString(order.currency);
        if (currency.length > 0) {
            return currency;
        }
    }
    NSString *fallback = PPOrderHistoryTrimmedString([CountryModel safeCurrentCurrencyCode]);
    return fallback.length > 0 ? fallback : @"QAR";
}

- (double)displayAmountValueForOrder:(PPOrder *)order
{
    double totalAmount = order.totalAmount;
    double effectiveShippingFee = MAX(0.0, order.shippingFee);
    if (effectiveShippingFee <= 0.0 &&
        totalAmount <= MAX(0.0, order.amount) + 0.009 &&
        order.amount > 0.0) {
        effectiveShippingFee = MAX(0.0, [CartManager sharedManager].deliveryFee);
    }
    double recomputedTotal = MAX(0.0, order.amount) + effectiveShippingFee;
    if (recomputedTotal > totalAmount) {
        totalAmount = recomputedTotal;
    }
    if (totalAmount <= 0.0) {
        totalAmount = order.amount;
    }
    return MAX(0.0, totalAmount);
}

- (double)totalSpentForOrders:(NSArray<PPOrder *> *)orders
{
    double total = 0.0;
    for (PPOrder *order in orders ?: @[]) {
        total += [self displayAmountValueForOrder:order];
    }
    return total;
}

- (NSInteger)activeOrdersCountForOrders:(NSArray<PPOrder *> *)orders
{
    NSInteger count = 0;
    for (PPOrder *order in orders ?: @[]) {
        NSString *statusKey = [self canonicalStatusFilterKeyForOrder:order];
        BOOL isActive = ![statusKey isEqualToString:kOrderHistoryFilterDelivered] &&
        ![statusKey isEqualToString:kOrderHistoryFilterCancelled] &&
        ![statusKey isEqualToString:kOrderHistoryFilterFailed];
        if (isActive) {
            count += 1;
        }
    }
    return count;
}

- (NSString *)primaryDescriptionForOrder:(PPOrder *)order
{
    NSString *firstItemName = @"";
    for (id item in order.items ?: @[]) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *itemDict = (NSDictionary *)item;
        firstItemName = PPOrderHistoryTrimmedString(itemDict[@"name"] ?: itemDict[@"title"]);
        if (firstItemName.length > 0) {
            break;
        }
    }

    NSInteger quantity = [self totalQuantityForOrder:order];
    if (firstItemName.length > 0 && quantity > 0) {
        return [NSString stringWithFormat:@"%@ • %@: %ld", firstItemName, kLang(@"QuantityLabel"), (long)quantity];
    }
    if (firstItemName.length > 0) {
        return firstItemName;
    }
    if (quantity > 0) {
        return [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)quantity];
    }
    return @"";
}

- (NSInteger)totalQuantityForOrder:(PPOrder *)order
{
    NSInteger quantity = 0;
    for (id item in order.items ?: @[]) {
        quantity += [self quantityForOrderItem:item];
    }
    if (quantity <= 0) {
        quantity = order.items.count;
    }
    return MAX(0, quantity);
}

- (NSInteger)quantityForOrderItem:(id)item
{
    if ([item isKindOfClass:NSDictionary.class]) {
        NSDictionary *itemDict = (NSDictionary *)item;
        id rawQty = itemDict[@"qty"] ?: itemDict[@"quantity"];
        if ([rawQty respondsToSelector:@selector(integerValue)]) {
            NSInteger qty = [rawQty integerValue];
            return MAX(0, qty);
        }
    }
    if ([item isKindOfClass:NSString.class]) {
        return 1;
    }
    return 0;
}

- (NSString *)firstEmbeddedImageURLForOrder:(PPOrder *)order
{
    for (id item in order.items ?: @[]) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *url = [self imageURLFromAccessoryData:(NSDictionary *)item];
        if (url.length > 0) return url;
    }
    return @"";
}

- (NSString *)firstItemIDForOrder:(PPOrder *)order
{
    for (id item in order.items ?: @[]) {
        NSString *itemID = [self itemIDFromOrderItem:item];
        if (itemID.length > 0) return itemID;
    }
    return @"";
}

- (NSString *)itemIDFromOrderItem:(id)item
{
    if ([item isKindOfClass:NSString.class]) {
        return PPOrderHistoryTrimmedString(item);
    }
    if (![item isKindOfClass:NSDictionary.class]) return @"";

    NSDictionary *itemDict = (NSDictionary *)item;
    NSString *itemID = PPOrderHistoryTrimmedString(itemDict[@"id"]);
    if (itemID.length == 0) itemID = PPOrderHistoryTrimmedString(itemDict[@"itemID"]);
    if (itemID.length == 0) itemID = PPOrderHistoryTrimmedString(itemDict[@"productId"]);
    if (itemID.length == 0) itemID = PPOrderHistoryTrimmedString(itemDict[@"productID"]);
    return itemID;
}

#pragma mark - Error Handling

- (void)showErrorMessage:(NSString *)message
{
    if (message.length == 0 || self.presentedViewController) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Error")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
