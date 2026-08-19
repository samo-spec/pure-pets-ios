//
//  OrderHistoryViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/06/2025.
//

#import "OrderHistoryViewController.h"
#import "OrderCell.h"
#import "PPOrderStatusAppearance.h"
#import "PPOrderDetailsRouter.h"
#import "PPOrder.h"
#import "UserManager.h"
#import "AppClasses.h"
#import "PPEmptyStateHelper.h"
#import "ChManager.h"
#import "CountryModel.h"
#import "PPS.h"
#import "CartManager.h"
#import "PPBackgroundView.h"
#import <Pure_Pets-Swift.h>
#import "PPOrderSupportComposerViewController.h"

#import <QuartzCore/QuartzCore.h>
@import FirebaseAuth;
@import FirebaseFirestore;

static NSString * const kOrderHistoryCellID = @"OrderCell";
static NSInteger const kOrderHistoryPageSize = 12;
static CGFloat const kOrderHistoryEstimatedRowHeight = 132.0;
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

@interface OrderHistoryViewController () <UITableViewDataSource, UITableViewDelegate, PPSDelegate, UIScrollViewDelegate, PPOrderHistorySurfaceControllerDelegate>

// SwiftUI owns presentation and local discovery state. This controller remains
// the single Firebase, pagination, support, and routing owner.
@property (nonatomic, strong) PPOrderHistorySurfaceController *orderHistorySurfaceController;

// Passthrough header layout
@property (nonatomic, strong) PPPassThroughHeaderContainer *headerContainer;

// Hero Card views
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroFillView;
@property (nonatomic, strong) UIButton *searchToggleButton;
@property (nonatomic, strong) UIButton *heroSupportButton;
@property (nonatomic, assign) BOOL searchExpanded;
@property (nonatomic, strong) PPBackgroundView *ambientGlassBackground;
@property (nonatomic, strong) PPWorldGlassBackgroundHostingController *worldGlassBackgroundController;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;

// Metrics display panel
@property (nonatomic, strong) UIView *summaryPanel;
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
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedOrderIDs;
@property (nonatomic, strong, nullable) FIRDocumentSnapshot *lastDocument;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> ordersListener;
@property (nonatomic, copy, nullable) NSString *ordersListenerUserID;
@property (nonatomic, strong, nullable) FIRAuthStateDidChangeListenerHandle authStateListenerHandle;

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
@property (nonatomic, assign) BOOL didCaptureInteractivePopState;
@property (nonatomic, assign) BOOL previousInteractivePopEnabled;
@property (nonatomic, strong) NSDateFormatter *orderDateFormatter;
@property (nonatomic, strong) NSNumberFormatter *orderAmountFormatter;
@property (nonatomic, copy, nullable) dispatch_block_t loadingTimeoutBlock;
@property (nonatomic, copy, nullable) NSString *lastFetchErrorMessage;
@property (nonatomic, copy, nullable) NSString *renderedAccentFilterKey;
@property (nonatomic, assign) BOOL orderHistorySnapshotFromCache;

@end

#pragma mark - OrderHistoryViewController Implementation

@implementation OrderHistoryViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupDefaults];
    [self setupViews];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_reduceMotionStatusDidChange)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
    [self fetchOrdersReset:YES];
    [self pp_startOrderHistoryAuthObservation];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.worldGlassBackgroundController.isFaded = YES;
    [self pp_applyNavigationPresentationForCurrentContextAnimated:animated];
    [self pp_publishOrderHistorySnapshot];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_restoreNavigationBarPresentationIfNeededAnimated:animated];
    self.worldGlassBackgroundController.isFaded = YES;
    [self.ambientGlassBackground stopAnimations];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.orderHistorySurfaceController) {
        return;
    }
    [self pp_runHeroEntranceIfNeeded];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [self.ambientGlassBackground startAnimations];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutViews];
    [self pp_prepareHeroEntranceIfNeeded];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.authStateListenerHandle) {
        [[FIRAuth auth] removeAuthStateDidChangeListener:self.authStateListenerHandle];
        self.authStateListenerHandle = nil;
    }
    [self stopOrdersRealtimeListener];
    [self.ambientGlassBackground stopAnimations];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.orderHistorySurfaceController) {
        return;
    }
    [self.ambientGlassBackground stopAnimations];
    [self.ambientGlassBackground reapplyPalette];
    if (self.view.window && !UIAccessibilityIsReduceMotionEnabled()) {
        [self.ambientGlassBackground startAnimations];
    }
    [self pp_applyHeroSurfaceWithAccent:[self pp_currentHeroAccentColor]];
}

- (void)pp_reduceMotionStatusDidChange
{
    if (self.orderHistorySurfaceController) {
        return;
    }
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    self.ambientGlassBackground.PPHeroApexUseShimmer = !reduceMotion;
    [self.ambientGlassBackground stopAnimations];
    if (reduceMotion) {
        NSArray<UIView *> *heroViews = @[
            self.heroCard,
            self.heroEyebrowLabel,
            self.heroTitleLabel,
            self.heroSubtitleLabel,
            self.summaryPanel,
            self.ordersMetricValueLabel,
            self.ordersMetricCaptionLabel,
            self.spentMetricValueLabel,
            self.spentMetricCaptionLabel,
            self.activeMetricLabel,
            self.searchToggleButton,
            self.heroSupportButton,
            self.searchView,
            self.filterSummaryLabel
        ];
        for (UIView *view in heroViews) {
            [view.layer removeAllAnimations];
            view.transform = CGAffineTransformIdentity;
            view.alpha = 1.0;
        }
        self.searchView.alpha = self.searchExpanded ? 1.0 : 0.0;
        self.filterSummaryLabel.alpha = self.searchExpanded ? 1.0 : 0.0;
        self.didPrepareHeroEntrance = YES;
        self.didRunHeroEntrance = YES;
        for (UITableViewCell *visibleCell in self.tableView.visibleCells) {
            if ([visibleCell isKindOfClass:OrderCell.class]) {
                [(OrderCell *)visibleCell playEntranceWithOrdinal:0 animated:NO];
            }
        }
    } else if (self.view.window) {
        [self.ambientGlassBackground startAnimations];
    }
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
    self.animatedOrderIDs = [NSMutableSet set];
    self.orderDateFormatter = [[NSDateFormatter alloc] init];
    NSString *localeIdentifier = [Language isRTL] ? @"ar_QA" : @"en_QA";
    self.orderDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier];
    [self.orderDateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM yyyy h:mm a"];
    self.orderAmountFormatter = [[NSNumberFormatter alloc] init];
    self.orderAmountFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    self.orderAmountFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier];
    self.orderAmountFormatter.minimumFractionDigits = 2;
    self.orderAmountFormatter.maximumFractionDigits = 2;
    self.orderAmountFormatter.usesGroupingSeparator = YES;
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
    if (self.orderHistorySurfaceController) {
        if (!self.didCaptureNavigationBarHiddenState && self.navigationController) {
            self.previousNavigationBarHiddenState = self.navigationController.navigationBarHidden;
            self.didCaptureNavigationBarHiddenState = YES;
        }
        [self.navigationController setNavigationBarHidden:YES animated:animated];
        UIGestureRecognizer *interactivePop = self.navigationController.interactivePopGestureRecognizer;
        BOOL isPushed = self.navigationController.viewControllers.firstObject != self;
        if (interactivePop && isPushed) {
            if (!self.didCaptureInteractivePopState) {
                self.previousInteractivePopEnabled = interactivePop.enabled;
                self.didCaptureInteractivePopState = YES;
            }
            interactivePop.enabled = YES;
        }
        self.navigationItem.leftBarButtonItems = nil;
        self.navigationItem.rightBarButtonItems = nil;
        [self pp_publishOrderHistorySnapshot];
        return;
    }

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
    if (self.didCaptureInteractivePopState &&
        self.navigationController.interactivePopGestureRecognizer) {
        self.navigationController.interactivePopGestureRecognizer.enabled =
            self.previousInteractivePopEnabled;
        self.didCaptureInteractivePopState = NO;
    }
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
    if (@available(iOS 17.0, *)) {
        [self pp_installOrderHistorySurface];
        return;
    }

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
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = kOrderHistoryEstimatedRowHeight;
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
    self.searchView.textField.accessibilityLabel = kLang(@"SearchHere");

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
    self.searchView.btn1.accessibilityLabel = kLang(@"order_history_filter_accessibility");
    [self.heroSurfaceView addSubview:self.searchView];

    self.filterSummaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.filterSummaryLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                                    scaledFontForFont:[GM MidFontWithSize:PPFontCaption1]];
    self.filterSummaryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.filterSummaryLabel.textColor = UIColor.secondaryLabelColor;
    self.filterSummaryLabel.adjustsFontForContentSizeCategory = YES;
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
}

- (void)pp_installOrderHistorySurface API_AVAILABLE(ios(17.0))
{
    PPOrderHistorySurfaceController *surface =
        [[PPOrderHistorySurfaceController alloc] initWithDelegate:self];
    surface.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self addChildViewController:surface];
    [self.view addSubview:surface.view];
    [NSLayoutConstraint activateConstraints:@[
        [surface.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [surface.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [surface.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [surface.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [surface didMoveToParentViewController:self];
    self.orderHistorySurfaceController = surface;
    [self pp_publishOrderHistorySnapshot];
}

- (void)layoutViews
{
    if (self.orderHistorySurfaceController) {
        return;
    }
    self.ambientGlassBackground.frame = self.view.bounds;
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
    if (@available(iOS 15.0, *)) {
        self.worldGlassBackgroundController =
            [[PPWorldGlassBackgroundHostingController alloc] initWithIsFaded:NO];
        [self.worldGlassBackgroundController attachTo:self];
        return;
    }

    PPBackgroundView *background = [[PPBackgroundView alloc] initWithFrame:self.view.bounds];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.userInteractionEnabled = NO;
    background.accentStyle = PPHeroGlassAccentStyleFullScreenPage;
    background.PPHeroApexUseUnderFingerMotion = NO;
    background.PPHeroApexUseShimmer = !UIAccessibilityIsReduceMotionEnabled();
    [self.view addSubview:background];
    self.ambientGlassBackground = background;
}

- (void)setupHeroHeader
{
    // Passthrough container initialization to prevent empty spaces from blocking touches
    self.headerContainer = [[PPPassThroughHeaderContainer alloc] initWithFrame:CGRectZero];
    self.headerContainer.backgroundColor = UIColor.clearColor;

    // Hero Card Shadow Container
    self.heroCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroCard.backgroundColor = UIColor.clearColor;
    self.heroCard.isAccessibilityElement = NO;
    self.heroCard.layer.cornerRadius = PPCornerCard + 2.0;
    self.heroCard.layer.masksToBounds = NO;
    [self.heroCard pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:0.22]];
    self.heroCard.layer.shadowOpacity = 0.04;
    self.heroCard.layer.shadowRadius = 14.0;
    self.heroCard.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    if (@available(iOS 13.0, *)) {
        self.heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.headerContainer addSubview:self.heroCard];

    // Card Surface View (Continuous corners)
    self.heroSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroSurfaceView.layer.cornerRadius = PPCornerCard + 2.0;
    self.heroSurfaceView.layer.masksToBounds = YES;
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        self.heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroCard addSubview:self.heroSurfaceView];

    // One calm ledger surface. Brand color is reserved for state and actions.
    self.heroFillView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroFillView.userInteractionEnabled = NO;
    self.heroFillView.clipsToBounds = YES;
    [self.heroSurfaceView addSubview:self.heroFillView];

    // Search Toggle Button (replaces trail icon)
    self.searchToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.searchToggleButton.layer.cornerRadius = 22.0;
    self.searchToggleButton.clipsToBounds = YES;
    self.searchToggleButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.searchToggleButton addTarget:self action:@selector(searchToggleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.0, *)) {
        self.searchToggleButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroSurfaceView addSubview:self.searchToggleButton];

    // Use a normal button configuration on every supported OS. The search
    // control keeps its capsule shape and accent treatment without glass.
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        self.searchToggleButton.configuration = configuration;
    }
    [self pp_updateSearchTogglePresentation];

    self.heroSupportButton = [PPButtonHelper pp_buttonWithTitleForBar:nil
                                                            imageName:@"headphones.dots"
                                                               target:self
                                                               action:@selector(contactSupportTapped)];
    self.heroSupportButton.accessibilityLabel = kLang(@"Support");
    self.heroSupportButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.heroSurfaceView addSubview:self.heroSupportButton];

    self.heroEyebrowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroEyebrowLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                                  scaledFontForFont:[GM boldFontWithSize:11.0]];
    self.heroEyebrowLabel.textColor = UIColor.secondaryLabelColor;
    self.heroEyebrowLabel.numberOfLines = 1;
    self.heroEyebrowLabel.adjustsFontSizeToFitWidth = YES;
    self.heroEyebrowLabel.minimumScaleFactor = 0.78;
    self.heroEyebrowLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroSurfaceView addSubview:self.heroEyebrowLabel];

    self.heroTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle1]
                                scaledFontForFont:[GM boldFontWithSize:PPFontTitle1]];
    self.heroTitleLabel.textColor = UIColor.labelColor;
    self.heroTitleLabel.numberOfLines = 2;
    self.heroTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleLabel.minimumScaleFactor = 0.82;
    self.heroTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.heroTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.heroSurfaceView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroSubtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                                   scaledFontForFont:[GM MidFontWithSize:PPFontSubheadline]];
    self.heroSubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.numberOfLines = 2;
    self.heroSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroSurfaceView addSubview:self.heroSubtitleLabel];

    // A single journey strip replaces the previous nested dashboard card.
    self.summaryPanel = [[UIView alloc] initWithFrame:CGRectZero];
    self.summaryPanel.backgroundColor = AppBackgroundClr;
    self.summaryPanel.layer.cornerRadius = PPCorner16;
    self.summaryPanel.layer.masksToBounds = YES;
    self.summaryPanel.isAccessibilityElement = YES;
    self.summaryPanel.accessibilityTraits = UIAccessibilityTraitStaticText;
    [self.heroSurfaceView addSubview:self.summaryPanel];

    self.summaryDividerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.summaryDividerView.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.45];
    [self.summaryPanel addSubview:self.summaryDividerView];

    self.ordersMetricValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.ordersMetricValueLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3]
                                        scaledFontForFont:[GM boldFontWithSize:PPFontTitle3]];
    self.ordersMetricValueLabel.textColor = UIColor.labelColor;
    self.ordersMetricValueLabel.adjustsFontSizeToFitWidth = YES;
    self.ordersMetricValueLabel.minimumScaleFactor = 0.7;
    self.ordersMetricValueLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.ordersMetricValueLabel];

    self.ordersMetricCaptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.ordersMetricCaptionLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                                          scaledFontForFont:[GM MidFontWithSize:13.0]];
    self.ordersMetricCaptionLabel.textColor = UIColor.secondaryLabelColor;
    self.ordersMetricCaptionLabel.numberOfLines = 1;
    self.ordersMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
    self.ordersMetricCaptionLabel.minimumScaleFactor = 0.8;
    self.ordersMetricCaptionLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.ordersMetricCaptionLabel];

    self.spentMetricValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.spentMetricValueLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3]
                                       scaledFontForFont:[GM boldFontWithSize:PPFontTitle3]];
    self.spentMetricValueLabel.textColor = UIColor.labelColor;
    self.spentMetricValueLabel.adjustsFontSizeToFitWidth = YES;
    self.spentMetricValueLabel.minimumScaleFactor = 0.66;
    self.spentMetricValueLabel.textAlignment = NSTextAlignmentRight;
    self.spentMetricValueLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.spentMetricValueLabel];

    self.spentMetricCaptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.spentMetricCaptionLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                                         scaledFontForFont:[GM MidFontWithSize:13.0]];
    self.spentMetricCaptionLabel.textColor = UIColor.secondaryLabelColor;
    self.spentMetricCaptionLabel.textAlignment = NSTextAlignmentRight;
    self.spentMetricCaptionLabel.numberOfLines = 1;
    self.spentMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
    self.spentMetricCaptionLabel.minimumScaleFactor = 0.78;
    self.spentMetricCaptionLabel.adjustsFontForContentSizeCategory = YES;
    [self.summaryPanel addSubview:self.spentMetricCaptionLabel];

    self.activeMetricLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.activeMetricLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                                   scaledFontForFont:[GM boldFontWithSize:PPFontCaption1]];
    self.activeMetricLabel.textAlignment = NSTextAlignmentCenter;
    self.activeMetricLabel.layer.cornerRadius = PPCorner16;
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
    CGFloat safeTop = MAX(self.view.safeAreaInsets.top, PPStatusBarHeight) + PPSpaceSM;
    BOOL isRTL = ([Language languageVal] == 1);
    BOOL showsHeroSupport = [self pp_isPresentedAsRootTab];
    UIContentSizeCategory contentSizeCategory = self.traitCollection.preferredContentSizeCategory;
    BOOL usesAccessibilityLayout = UIContentSizeCategoryIsAccessibilityCategory(contentSizeCategory)
        || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraLarge]
        || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge];
    self.heroTitleLabel.numberOfLines = usesAccessibilityLayout ? 0 : 2;
    self.heroSubtitleLabel.numberOfLines = usesAccessibilityLayout ? 0 : 2;
    CGFloat horizontalMargin = PPSpaceBase;
    CGFloat cardWidth = MIN(MAX(0.0, width - (horizontalMargin * 2.0)), 720.0);
    CGFloat cardX = floor((width - cardWidth) * 0.5);
    CGFloat padding = PPSpaceLG;
    CGFloat contentWidth = MAX(0.0, cardWidth - (padding * 2.0));

    self.headerContainer.frame = CGRectMake(0.0, 0.0, width, 1.0);

    CGFloat actionWidth = 44.0 + (showsHeroSupport ? 52.0 : 0.0);
    CGFloat textX = padding;
    CGFloat textWidth = MAX(0.0, contentWidth - actionWidth - PPSpaceMD);
    if (isRTL) {
        textX = padding + actionWidth + PPSpaceMD;
    }
    if (usesAccessibilityLayout) {
        textX = padding;
        textWidth = contentWidth;
    }

    CGFloat toggleX = isRTL ? padding : cardWidth - padding - 44.0;
    self.searchToggleButton.frame = CGRectMake(toggleX, PPSpaceBase, 44.0, 44.0);

    self.heroSupportButton.hidden = !showsHeroSupport;
    self.heroSupportButton.frame = CGRectMake(isRTL ? padding + 52.0 : toggleX - 52.0,
                                              PPSpaceBase,
                                              44.0,
                                              44.0);

    CGFloat eyebrowWidth = usesAccessibilityLayout
        ? MAX(0.0, contentWidth - actionWidth - PPSpaceMD)
        : textWidth;
    CGFloat eyebrowX = (usesAccessibilityLayout && isRTL)
        ? padding + actionWidth + PPSpaceMD
        : textX;
    self.heroEyebrowLabel.frame = CGRectMake(eyebrowX, PPSpaceBase, eyebrowWidth, 17.0);

    CGSize titleSize = [self.heroTitleLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    CGFloat titleY = CGRectGetMaxY(self.heroEyebrowLabel.frame) + PPSpaceXS;
    if (usesAccessibilityLayout) {
        titleY = MAX(titleY, CGRectGetMaxY(self.searchToggleButton.frame) + PPSpaceSM);
    }
    self.heroTitleLabel.frame = CGRectMake(textX,
                                           titleY,
                                           textWidth,
                                           MAX(32.0, ceil(titleSize.height)));

    CGSize subtitleSize = [self.heroSubtitleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
    self.heroSubtitleLabel.frame = CGRectMake(padding,
                                              CGRectGetMaxY(self.heroTitleLabel.frame) + PPSpaceXS,
                                              contentWidth,
                                              MAX(20.0, ceil(subtitleSize.height)));

    CGFloat summaryY = MAX(CGRectGetMaxY(self.heroSubtitleLabel.frame) + PPSpaceBase,
                           CGRectGetMaxY(self.searchToggleButton.frame) + PPSpaceSM);
    CGFloat metricPadding = PPSpaceMD;
    CGFloat metricGap = PPSpaceMD;
    CGFloat summaryHeight = 60.0;
    BOOL usesThreeColumnSummary = !usesAccessibilityLayout && contentWidth >= 330.0;

    if (!usesAccessibilityLayout) {
        self.activeMetricLabel.numberOfLines = 1;
    }
    [self.activeMetricLabel sizeToFit];
    CGFloat preferredActiveWidth = CGRectGetWidth(self.activeMetricLabel.bounds) + (PPSpaceMD * 2.0);
    CGFloat activeWidth = MIN(136.0, MAX(104.0, preferredActiveWidth));
    CGFloat metricColumnWidth = usesThreeColumnSummary
        ? floor((contentWidth - (metricPadding * 2.0) - activeWidth - (metricGap * 2.0)) * 0.5)
        : floor((contentWidth - (metricPadding * 2.0) - metricGap) * 0.5);
    metricColumnWidth = MAX(0.0, metricColumnWidth);
    CGFloat metricValueHeight = ceil(MAX(self.ordersMetricValueLabel.font.lineHeight,
                                         self.spentMetricValueLabel.font.lineHeight));
    CGFloat metricCaptionHeight = ceil(MAX(self.ordersMetricCaptionLabel.font.lineHeight,
                                           self.spentMetricCaptionLabel.font.lineHeight));

    CGFloat leadingMetricX = metricPadding;
    CGFloat trailingMetricX = contentWidth - metricPadding - metricColumnWidth;
    if (isRTL) {
        leadingMetricX = trailingMetricX;
        trailingMetricX = metricPadding;
    }

    if (usesAccessibilityLayout) {
        self.summaryDividerView.hidden = NO;
        CGFloat fullMetricWidth = MAX(0.0, contentWidth - (metricPadding * 2.0));
        self.ordersMetricValueLabel.numberOfLines = 0;
        self.ordersMetricCaptionLabel.numberOfLines = 0;
        self.spentMetricValueLabel.numberOfLines = 0;
        self.spentMetricCaptionLabel.numberOfLines = 0;
        self.activeMetricLabel.numberOfLines = 0;
        self.ordersMetricValueLabel.adjustsFontSizeToFitWidth = NO;
        self.ordersMetricCaptionLabel.adjustsFontSizeToFitWidth = NO;
        self.spentMetricValueLabel.adjustsFontSizeToFitWidth = NO;
        self.spentMetricCaptionLabel.adjustsFontSizeToFitWidth = NO;
        self.activeMetricLabel.adjustsFontSizeToFitWidth = NO;

        CGFloat metricY = 12.0;
        CGFloat ordersValueHeight = MAX(self.ordersMetricValueLabel.font.lineHeight,
                                        ceil([self.ordersMetricValueLabel sizeThatFits:
                                              CGSizeMake(fullMetricWidth, CGFLOAT_MAX)].height));
        self.ordersMetricValueLabel.frame = CGRectMake(metricPadding,
                                                       metricY,
                                                       fullMetricWidth,
                                                       ordersValueHeight);
        metricY = CGRectGetMaxY(self.ordersMetricValueLabel.frame) + 2.0;
        CGFloat ordersCaptionHeight = MAX(self.ordersMetricCaptionLabel.font.lineHeight,
                                          ceil([self.ordersMetricCaptionLabel sizeThatFits:
                                                CGSizeMake(fullMetricWidth, CGFLOAT_MAX)].height));
        self.ordersMetricCaptionLabel.frame = CGRectMake(metricPadding,
                                                         metricY,
                                                         fullMetricWidth,
                                                         ordersCaptionHeight);
        metricY = CGRectGetMaxY(self.ordersMetricCaptionLabel.frame) + 12.0;
        self.summaryDividerView.frame = CGRectMake(metricPadding,
                                                   metricY,
                                                   fullMetricWidth,
                                                   1.0);
        metricY = CGRectGetMaxY(self.summaryDividerView.frame) + 10.0;
        CGFloat spentValueHeight = MAX(self.spentMetricValueLabel.font.lineHeight,
                                       ceil([self.spentMetricValueLabel sizeThatFits:
                                             CGSizeMake(fullMetricWidth, CGFLOAT_MAX)].height));
        self.spentMetricValueLabel.frame = CGRectMake(metricPadding,
                                                      metricY,
                                                      fullMetricWidth,
                                                      spentValueHeight);
        metricY = CGRectGetMaxY(self.spentMetricValueLabel.frame) + 2.0;
        CGFloat spentCaptionHeight = MAX(self.spentMetricCaptionLabel.font.lineHeight,
                                         ceil([self.spentMetricCaptionLabel sizeThatFits:
                                               CGSizeMake(fullMetricWidth, CGFLOAT_MAX)].height));
        self.spentMetricCaptionLabel.frame = CGRectMake(metricPadding,
                                                        metricY,
                                                        fullMetricWidth,
                                                        spentCaptionHeight);
        metricY = CGRectGetMaxY(self.spentMetricCaptionLabel.frame) + 12.0;

        CGFloat activeContentWidth = MAX(0.0, fullMetricWidth - 22.0);
        CGFloat activeHeight = MAX(32.0,
                                   ceil([self.activeMetricLabel sizeThatFits:
                                         CGSizeMake(activeContentWidth, CGFLOAT_MAX)].height) + 8.0);
        self.activeMetricLabel.frame = CGRectMake(metricPadding,
                                                  metricY,
                                                  fullMetricWidth,
                                                  activeHeight);
        self.activeMetricLabel.layer.cornerRadius = activeHeight * 0.5;
        summaryHeight = CGRectGetMaxY(self.activeMetricLabel.frame) + 12.0;
        self.spentMetricValueLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
        self.spentMetricCaptionLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    } else if (usesThreeColumnSummary) {
        self.ordersMetricValueLabel.numberOfLines = 1;
        self.ordersMetricCaptionLabel.numberOfLines = 1;
        self.spentMetricValueLabel.numberOfLines = 1;
        self.spentMetricCaptionLabel.numberOfLines = 1;
        self.activeMetricLabel.numberOfLines = 1;
        self.ordersMetricValueLabel.adjustsFontSizeToFitWidth = YES;
        self.ordersMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
        self.spentMetricValueLabel.adjustsFontSizeToFitWidth = YES;
        self.spentMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
        self.activeMetricLabel.adjustsFontSizeToFitWidth = YES;
        self.summaryDividerView.hidden = YES;
        CGFloat metricBlockHeight = metricValueHeight + metricCaptionHeight;
        CGFloat activeHeight = MAX(32.0, ceil(self.activeMetricLabel.font.lineHeight) + 12.0);
        summaryHeight = MAX(60.0, MAX(metricBlockHeight + 14.0, activeHeight + 16.0));
        CGFloat metricY = floor((summaryHeight - metricBlockHeight) * 0.5);
        self.ordersMetricValueLabel.frame = CGRectMake(leadingMetricX,
                                                       metricY,
                                                       metricColumnWidth,
                                                       metricValueHeight);
        self.ordersMetricCaptionLabel.frame = CGRectMake(leadingMetricX,
                                                         CGRectGetMaxY(self.ordersMetricValueLabel.frame),
                                                         metricColumnWidth,
                                                         metricCaptionHeight);
        self.spentMetricValueLabel.frame = CGRectMake(trailingMetricX,
                                                      metricY,
                                                      metricColumnWidth,
                                                      metricValueHeight);
        self.spentMetricCaptionLabel.frame = CGRectMake(trailingMetricX,
                                                        CGRectGetMaxY(self.spentMetricValueLabel.frame),
                                                        metricColumnWidth,
                                                        metricCaptionHeight);
        CGFloat badgeX = floor((contentWidth - activeWidth) * 0.5);
        self.activeMetricLabel.frame = CGRectMake(badgeX,
                                                  floor((summaryHeight - activeHeight) * 0.5),
                                                  activeWidth,
                                                  activeHeight);
        self.activeMetricLabel.layer.cornerRadius = activeHeight * 0.5;
    } else {
        self.ordersMetricValueLabel.numberOfLines = 1;
        self.ordersMetricCaptionLabel.numberOfLines = 1;
        self.spentMetricValueLabel.numberOfLines = 1;
        self.spentMetricCaptionLabel.numberOfLines = 1;
        self.activeMetricLabel.numberOfLines = 1;
        self.ordersMetricValueLabel.adjustsFontSizeToFitWidth = YES;
        self.ordersMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
        self.spentMetricValueLabel.adjustsFontSizeToFitWidth = YES;
        self.spentMetricCaptionLabel.adjustsFontSizeToFitWidth = YES;
        self.activeMetricLabel.adjustsFontSizeToFitWidth = YES;
        self.summaryDividerView.hidden = NO;
        CGFloat metricY = PPSpaceSM;
        CGFloat metricBlockHeight = metricValueHeight + metricCaptionHeight;
        self.ordersMetricValueLabel.frame = CGRectMake(leadingMetricX,
                                                       metricY,
                                                       metricColumnWidth,
                                                       metricValueHeight);
        self.ordersMetricCaptionLabel.frame = CGRectMake(leadingMetricX,
                                                         CGRectGetMaxY(self.ordersMetricValueLabel.frame),
                                                         metricColumnWidth,
                                                         metricCaptionHeight);
        self.spentMetricValueLabel.frame = CGRectMake(trailingMetricX,
                                                      metricY,
                                                      metricColumnWidth,
                                                      metricValueHeight);
        self.spentMetricCaptionLabel.frame = CGRectMake(trailingMetricX,
                                                        CGRectGetMaxY(self.spentMetricValueLabel.frame),
                                                        metricColumnWidth,
                                                        metricCaptionHeight);
        self.summaryDividerView.frame = CGRectMake(floor((contentWidth - 1.0) * 0.5),
                                                   metricY,
                                                   1.0,
                                                   metricBlockHeight);
        CGFloat badgeWidth = MIN(contentWidth - (metricPadding * 2.0),
                                 MAX(112.0, preferredActiveWidth));
        CGFloat activeHeight = MAX(24.0, ceil(self.activeMetricLabel.font.lineHeight) + 8.0);
        CGFloat badgeY = metricY + metricBlockHeight + PPSpaceSM;
        self.activeMetricLabel.frame = CGRectMake(floor((contentWidth - badgeWidth) * 0.5),
                                                  badgeY,
                                                  badgeWidth,
                                                  activeHeight);
        self.activeMetricLabel.layer.cornerRadius = activeHeight * 0.5;
        summaryHeight = CGRectGetMaxY(self.activeMetricLabel.frame) + PPSpaceSM;
    }

    self.summaryPanel.frame = CGRectMake(padding, summaryY, contentWidth, summaryHeight);

    // Inner Search Bar coordinates inside Card surface
    CGFloat searchY = CGRectGetMaxY(self.summaryPanel.frame) + PPSpaceMD;
    self.searchView.frame = CGRectMake(padding, searchY, contentWidth, 50.0);
    self.filterSummaryLabel.numberOfLines = usesAccessibilityLayout ? 0 : 1;
    CGFloat filterSummaryWidth = MAX(0.0, contentWidth - 16.0);
    CGFloat filterSummaryHeight = MAX(ceil(self.filterSummaryLabel.font.lineHeight),
                                      ceil([self.filterSummaryLabel sizeThatFits:
                                            CGSizeMake(filterSummaryWidth, CGFLOAT_MAX)].height));
    self.filterSummaryLabel.frame = CGRectMake(padding + 8.0,
                                               CGRectGetMaxY(self.searchView.frame) + 6.0,
                                               filterSummaryWidth,
                                               filterSummaryHeight);

    CGFloat finalHeroHeight;
    if (self.searchExpanded) {
        finalHeroHeight = CGRectGetMaxY(self.filterSummaryLabel.frame) + PPSpaceBase;
        self.searchView.alpha = 1.0;
        self.filterSummaryLabel.alpha = 1.0;
    } else {
        finalHeroHeight = CGRectGetMaxY(self.summaryPanel.frame) + PPSpaceBase;
        self.searchView.alpha = 0.0;
        self.filterSummaryLabel.alpha = 0.0;
    }
    self.searchView.userInteractionEnabled = self.searchExpanded;

    self.heroCard.frame = CGRectMake(cardX, safeTop, cardWidth, finalHeroHeight);
    self.heroSurfaceView.frame = self.heroCard.bounds;
    self.heroFillView.frame = self.heroSurfaceView.bounds;

    self.headerContainer.frame = CGRectMake(0.0,
                                            0.0,
                                            width,
                                            CGRectGetMaxY(self.heroCard.frame) + PPSpaceSM);
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

    [self pp_setMetricText:[NSString stringWithFormat:@"%ld", (long)visibleCount]
                  onLabel:self.ordersMetricValueLabel];
    self.ordersMetricCaptionLabel.text = kLang(@"order_history_metric_orders");
    [self pp_setMetricText:[self formattedSummaryAmount:totalSpent currency:currencyCode]
                  onLabel:self.spentMetricValueLabel];
    self.spentMetricCaptionLabel.text = kLang(@"order_history_metric_spent");

    UIColor *accent = [self pp_currentHeroAccentColor];

    [self pp_applyHeroSurfaceWithAccent:accent];
    self.activeMetricLabel.backgroundColor = [accent colorWithAlphaComponent:0.14];
    self.activeMetricLabel.textColor = accent;
    

    
    NSString *scopeTitle = [self pp_hasSearchOrFilter] ? kLang(@"order_history_scope_filtered") : kLang(@"order_history_scope_all");
    NSString *resolvedScope = scopeTitle.length > 0
        ? scopeTitle
        : [self displayTitleForStatusFilterKey:self.selectedStatusFilterKey];
    self.activeMetricLabel.text = [NSString stringWithFormat:kLang(@"order_history_metric_active_format"),
                                   resolvedScope,
                                   (long)activeCount];

    self.summaryPanel.accessibilityLabel = [NSString stringWithFormat:kLang(@"order_history_summary_accessibility_format"),
                                            self.ordersMetricValueLabel.text ?: @"0",
                                            self.spentMetricValueLabel.text ?: @"",
                                            (long)activeCount];
    [self pp_updateSearchTogglePresentation];

    [self layoutHeroHeader];
    [self pp_applyPremiumBottomContentInset];
    [self pp_updateHeroAccessibilityOrder];
}

- (void)pp_setMetricText:(NSString *)text onLabel:(UILabel *)label
{
    NSString *resolvedText = text ?: @"";
    if ([label.text isEqualToString:resolvedText]) {
        return;
    }

    BOOL shouldAnimate = self.didRunHeroEntrance && self.view.window && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        CATransition *transition = [CATransition animation];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFromTop;
        transition.duration = 0.24;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [label.layer addAnimation:transition forKey:@"PPOrderMetricChange"];
    }
    label.text = resolvedText;
}

- (UIColor *)pp_currentHeroAccentColor
{
    return [self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll]
    ? ([GM appPrimaryColor] ?: AppPrimaryClr ?: UIColor.systemOrangeColor)
    : [self colorForStatusFilterKey:self.selectedStatusFilterKey];
}

- (void)pp_applyHeroSurfaceWithAccent:(UIColor *)accent
{
    UIColor *resolvedAccent = accent ?: ([GM appPrimaryColor] ?: AppPrimaryClr ?: UIColor.systemOrangeColor);
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    UIColor *surfaceColor = AppCardColor ?: UIColor.systemBackgroundColor;
    self.heroFillView.backgroundColor = surfaceColor;
    self.summaryPanel.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:isDark ? 0.72 : 0.82];
    self.heroCard.layer.cornerRadius = PPCornerCard + 2.0;
    self.heroCard.layer.borderWidth = 0.0;
    self.heroCard.layer.masksToBounds = NO;
    self.heroCard.layer.shadowOpacity = isDark ? 0.13 : 0.035;
    self.heroCard.layer.shadowRadius = isDark ? 14.0 : 12.0;
    self.heroCard.layer.shadowOffset = CGSizeMake(0.0, isDark ? 7.0 : 5.0);

    self.searchToggleButton.backgroundColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.18 : 0.105];
    [self.searchToggleButton pp_setBorderColor:[resolvedAccent colorWithAlphaComponent:isDark ? 0.22 : 0.18]];
    self.searchToggleButton.tintColor = resolvedAccent;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = self.searchToggleButton.configuration;
        configuration.baseBackgroundColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.18 : 0.105];
        configuration.baseForegroundColor = resolvedAccent;
        self.searchToggleButton.configuration = configuration;
    }

    self.heroSurfaceView.layer.borderWidth = 0.0;

    self.summaryPanel.layer.borderWidth = 0.0;
    self.searchView.strokeColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.22 : 0.14];
    self.searchView.backgroundColor = [surfaceColor colorWithAlphaComponent:1.0];

    NSString *accentKey = self.selectedStatusFilterKey ?: kOrderHistoryFilterAll;
    if (![self.renderedAccentFilterKey isEqualToString:accentKey]) {
        self.renderedAccentFilterKey = accentKey;
        self.ambientGlassBackground.accentColorOverride = resolvedAccent;
        [self.ambientGlassBackground reapplyPalette];
    }

    self.summaryDividerView.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:isDark ? 0.34 : 0.45];
    self.initialLoader.color = resolvedAccent;
    self.paginationLoader.color = resolvedAccent;
}

- (void)pp_updateSearchTogglePresentation
{
    NSString *symbolName = self.searchExpanded ? @"xmark" : @"magnifyingglass";
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        image = [UIImage systemImageNamed:symbolName];
    }

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration = self.searchToggleButton.configuration;
        configuration.image = image;
        self.searchToggleButton.configuration = configuration;
    } else {
        [self.searchToggleButton setImage:image forState:UIControlStateNormal];
    }

    self.searchToggleButton.accessibilityLabel = self.searchExpanded
        ? kLang(@"order_history_search_close")
        : kLang(@"order_history_search_open");
    self.searchToggleButton.accessibilityValue = [self pp_hasSearchOrFilter]
        ? self.filterSummaryLabel.text
        : nil;
}

- (void)pp_updateHeroAccessibilityOrder
{
    NSMutableArray *elements = [NSMutableArray arrayWithObjects:
                                self.heroTitleLabel,
                                self.heroSubtitleLabel,
                                self.summaryPanel,
                                self.searchToggleButton,
                                nil];
    if (!self.heroSupportButton.hidden) {
        [elements addObject:self.heroSupportButton];
    }
    if (self.searchExpanded) {
        [elements addObject:self.searchView.textField];
        [elements addObject:self.searchView.btn1];
    }
    self.heroSurfaceView.accessibilityElements = elements;
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
        self.searchView.alpha = self.searchExpanded ? 1.0 : 0.0;
        self.filterSummaryLabel.alpha = self.searchExpanded ? 1.0 : 0.0;
        self.heroEyebrowLabel.alpha = 1.0;
        self.heroTitleLabel.alpha = 1.0;
        self.heroSubtitleLabel.alpha = 1.0;
        self.summaryPanel.alpha = 1.0;
        self.searchToggleButton.alpha = 1.0;
        self.heroSupportButton.alpha = 1.0;
        self.heroCard.transform = CGAffineTransformIdentity;
        self.searchView.transform = CGAffineTransformIdentity;
        self.filterSummaryLabel.transform = CGAffineTransformIdentity;
        self.heroEyebrowLabel.transform = CGAffineTransformIdentity;
        self.heroTitleLabel.transform = CGAffineTransformIdentity;
        self.heroSubtitleLabel.transform = CGAffineTransformIdentity;
        self.summaryPanel.transform = CGAffineTransformIdentity;
        self.searchToggleButton.transform = CGAffineTransformIdentity;
        self.heroSupportButton.transform = CGAffineTransformIdentity;
        return;
    }

    self.heroCard.alpha = 0.94;
    self.heroCard.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.searchView.alpha = self.searchExpanded ? 1.0 : 0.0;
    self.searchView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.filterSummaryLabel.alpha = self.searchExpanded ? 1.0 : 0.0;
    self.filterSummaryLabel.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.heroEyebrowLabel.alpha = 1.0;
    self.heroEyebrowLabel.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroTitleLabel.alpha = 1.0;
    self.heroTitleLabel.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.heroSubtitleLabel.alpha = 1.0;
    self.heroSubtitleLabel.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.summaryPanel.alpha = 1.0;
    self.summaryPanel.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.searchToggleButton.alpha = 1.0;
    self.searchToggleButton.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroSupportButton.alpha = 1.0;
    self.heroSupportButton.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
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
        self.searchToggleButton.transform = CGAffineTransformIdentity;
        self.heroSupportButton.transform = CGAffineTransformIdentity;
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
        self.searchView.alpha = self.searchExpanded ? 1.0 : 0.0;
        self.searchView.transform = CGAffineTransformIdentity;
        self.filterSummaryLabel.alpha = self.searchExpanded ? 1.0 : 0.0;
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
    (void)sender;
    self.searchExpanded = !self.searchExpanded;
    self.searchView.userInteractionEnabled = self.searchExpanded;

    UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
    [feedback selectionChanged];

    if (!self.searchExpanded) {
        [self.searchView unfocus];
    }

    [UIView transitionWithView:self.searchToggleButton
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
        [self pp_updateSearchTogglePresentation];
    } completion:nil];

    CGFloat previousTopInset = self.tableView.contentInset.top;
    CGPoint previousOffset = self.tableView.contentOffset;
    void (^layoutUpdates)(void) = ^{
        [self layoutHeroHeader];
        [self pp_applyPremiumBottomContentInset];
        [self pp_updateHeroAccessibilityOrder];
        CGFloat insetDelta = self.tableView.contentInset.top - previousTopInset;
        self.tableView.contentOffset = CGPointMake(previousOffset.x, previousOffset.y - insetDelta);
        [self.view layoutIfNeeded];
    };

    if (UIAccessibilityIsReduceMotionEnabled()) {
        layoutUpdates();
        if (self.searchExpanded) {
            [self.searchView focus];
        }
        return;
    }

    [UIView animateWithDuration:0.46
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState
                     animations:layoutUpdates
                     completion:^(BOOL finished) {
        if (finished && self.searchExpanded) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.searchView focus];
            });
        }
    }];
}

#pragma mark - Data Management

- (void)pp_startOrderHistoryAuthObservation
{
    if (self.authStateListenerHandle) return;

    __weak typeof(self) weakSelf = self;
    self.authStateListenerHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(
        FIRAuth * _Nonnull auth,
        FIRUser * _Nullable user
    ) {
        (void)auth;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            NSString *nextUserID = PPOrderHistoryTrimmedString(user.uid);
            NSString *listeningUserID = PPOrderHistoryTrimmedString(self.ordersListenerUserID);
            if ([nextUserID isEqualToString:listeningUserID]) return;

            [self stopOrdersRealtimeListener];
            [self cancelLoadingTimeout];
            [self.orders removeAllObjects];
            self.displayedOrders = @[];
            self.lastDocument = nil;
            self.isFetchingInitial = NO;
            self.isFetchingMore = NO;
            self.hasMorePages = YES;
            self.orderHistorySnapshotFromCache = NO;
            self.lastFetchErrorMessage = nextUserID.length == 0
                ? kLang(@"UserNotAuthenticated")
                : nil;
            [self applyFiltersAndReload];

            if (nextUserID.length > 0) {
                [self fetchOrdersReset:YES];
            }
        });
    }];
}

- (void)pp_publishOrderHistorySnapshot
{
    if (!self.orderHistorySurfaceController) {
        return;
    }

    PPOrderHistorySnapshotDescriptor *snapshot = [PPOrderHistorySnapshotDescriptor new];
    NSMutableArray<PPOrderHistoryItemDescriptor *> *items = [NSMutableArray arrayWithCapacity:self.orders.count];

    for (PPOrder *order in self.orders ?: @[]) {
        if (![order isKindOfClass:PPOrder.class]) continue;

        PPOrderHistoryItemDescriptor *item = [PPOrderHistoryItemDescriptor new];
        item.identifier = PPOrderHistoryTrimmedString(order.orderId);
        if (item.identifier.length == 0) {
            item.identifier = PPOrderHistoryTrimmedString([order displayOrderReference]);
        }
        item.reference = PPOrderHistoryTrimmedString([order displayOrderReference]);
        item.statusKey = [self customerStatusKeyForOrder:order] ?: @"";
        item.filterKey = [self canonicalStatusFilterKeyForOrder:order] ?: kOrderHistoryFilterPending;
        item.statusTitle = [self displayTitleForOrder:order] ?: @"";
        item.dateText = [self formattedDate:order.createdAt] ?: @"";
        item.primaryDescription = [self primaryDescriptionForOrder:order] ?: @"";
        item.amountText = [self formattedAmountForOrder:order] ?: @"";
        item.quantity = [self totalQuantityForOrder:order];
        item.progressStage = [self pp_progressStageForFilterKey:item.filterKey];
        item.isActive = ![item.filterKey isEqualToString:kOrderHistoryFilterDelivered] &&
            ![item.filterKey isEqualToString:kOrderHistoryFilterCancelled] &&
            ![item.filterKey isEqualToString:kOrderHistoryFilterFailed];

        NSString *imageURL = [self firstEmbeddedImageURLForOrder:order];
        NSString *firstItemID = [self firstItemIDForOrder:order];
        if (imageURL.length == 0 && firstItemID.length > 0) {
            imageURL = [self imageURLFromAccessoryData:self.accessoryCache[firstItemID]];
            if (imageURL.length == 0) {
                [self fetchAccessoryPreviewForItemID:firstItemID orderID:order.orderId];
            }
        }
        item.imageURL = imageURL ?: @"";
        item.searchIndex = [self pp_searchIndexForOrder:order item:item];
        [items addObject:item];
    }

    NSMutableArray<PPOrderHistoryFilterDescriptor *> *filters = [NSMutableArray array];
    for (NSDictionary *definition in [self statusFilterDefinitions]) {
        NSString *key = PPOrderHistoryTrimmedString(definition[@"key"]);
        PPOrderHistoryFilterDescriptor *filter = [PPOrderHistoryFilterDescriptor new];
        filter.key = key.length > 0 ? key : kOrderHistoryFilterAll;
        filter.title = PPOrderHistoryTrimmedString(definition[@"title"]);
        filter.count = [self countForStatusFilterKey:filter.key];
        [filters addObject:filter];
    }

    snapshot.items = items;
    snapshot.filters = filters;
    snapshot.totalCount = self.orders.count;
    snapshot.activeCount = [self activeOrdersCountForOrders:self.orders];
    snapshot.totalSpentText = [self formattedSummaryAmount:[self totalSpentForOrders:self.orders]
                                                  currency:[self preferredCurrencyCodeForOrders:self.orders]];
    snapshot.errorMessage = self.lastFetchErrorMessage;
    BOOL awaitingFirstRequest = self.orders.count == 0 &&
        self.ordersListener == nil &&
        self.lastFetchErrorMessage.length == 0;
    snapshot.isInitialLoading = self.isFetchingInitial || awaitingFirstRequest;
    snapshot.isLoadingMore = self.isFetchingMore;
    snapshot.hasMore = self.hasMorePages;
    snapshot.showsBackButton = [self pp_shouldShowOrderHistoryBackButton];
    snapshot.isShowingCachedData = self.orderHistorySnapshotFromCache;
    BOOL isModalRoot = (self.navigationController &&
                        self.navigationController.viewControllers.firstObject == self &&
                        self.navigationController.presentingViewController != nil) ||
                       (self.navigationController == nil && self.presentingViewController != nil);
    snapshot.navigationSymbol = isModalRoot ? @"xmark" : @"chevron.backward";
    snapshot.navigationAccessibilityLabel = isModalRoot
        ? kLang(@"Close")
        : kLang(@"Back");
    [self.orderHistorySurfaceController applySnapshot:snapshot];
}

- (NSInteger)pp_progressStageForFilterKey:(NSString *)filterKey
{
    if ([filterKey isEqualToString:kOrderHistoryFilterDelivered]) return 4;
    if ([filterKey isEqualToString:kOrderHistoryFilterShipped]) return 3;
    if ([filterKey isEqualToString:kOrderHistoryFilterProcessing]) return 2;
    if ([filterKey isEqualToString:kOrderHistoryFilterPaid]) return 1;
    if ([filterKey isEqualToString:kOrderHistoryFilterCancelled] ||
        [filterKey isEqualToString:kOrderHistoryFilterFailed]) return 0;
    return 1;
}

- (BOOL)pp_shouldShowOrderHistoryBackButton
{
    BOOL pushed = self.navigationController &&
        self.navigationController.viewControllers.firstObject != self;
    BOOL presented = self.presentingViewController != nil ||
        self.navigationController.presentingViewController != nil;
    return pushed || presented;
}

- (NSString *)pp_searchIndexForOrder:(PPOrder *)order
                                item:(PPOrderHistoryItemDescriptor *)item
{
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    NSArray<NSString *> *baseValues = @[
        item.reference ?: @"",
        PPOrderHistoryTrimmedString(order.orderId),
        PPOrderHistoryTrimmedString(order.transactionId),
        PPOrderHistoryTrimmedString(order.paymentProvider),
        PPOrderHistoryTrimmedString(order.failureReason),
        item.statusTitle ?: @"",
        item.statusKey ?: @"",
        item.filterKey ?: @"",
        item.dateText ?: @"",
        item.amountText ?: @"",
        item.primaryDescription ?: @""
    ];
    for (NSString *value in baseValues) {
        if (value.length > 0) [tokens addObject:value];
    }

    NSDictionary *address = [order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]
        ? order.shippingAddressSnapshot
        : nil;
    for (id value in address.allValues ?: @[]) {
        NSString *text = PPOrderHistoryTrimmedString(value);
        if (text.length > 0) [tokens addObject:text];
    }

    for (id rawItem in order.items ?: @[]) {
        if ([rawItem isKindOfClass:NSString.class]) {
            NSString *text = PPOrderHistoryTrimmedString(rawItem);
            if (text.length > 0) [tokens addObject:text];
            continue;
        }
        if (![rawItem isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *dictionary = (NSDictionary *)rawItem;
        NSArray *values = @[
            dictionary[@"name"] ?: @"",
            dictionary[@"title"] ?: @"",
            dictionary[@"id"] ?: @"",
            dictionary[@"itemID"] ?: @"",
            dictionary[@"productId"] ?: @"",
            dictionary[@"productID"] ?: @""
        ];
        for (id value in values) {
            NSString *text = PPOrderHistoryTrimmedString(value);
            if (text.length > 0) [tokens addObject:text];
        }
    }
    return [tokens componentsJoinedByString:@" \u2022 "];
}

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

        BOOL isStillLoading = strongSelf.orderHistorySurfaceController
            ? strongSelf.isFetchingInitial
            : strongSelf.initialLoader.isAnimating;
        if (isStillLoading) {
            if (strongSelf.orderHistorySurfaceController) {
                [strongSelf finishFetchingWithErrorMessage:kLang(@"connection_timeout_message")
                                                     reset:YES];
            } else {
                [strongSelf finishFetchingWithErrorMessage:nil reset:YES];
                [strongSelf showLoadingTimeoutErrorWithRetry];
            }
        }
    });
    self.loadingTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);
}

- (void)showLoadingTimeoutErrorWithRetry
{
    if (self.orderHistorySurfaceController) {
        self.lastFetchErrorMessage = kLang(@"connection_timeout_message");
        [self pp_publishOrderHistorySnapshot];
        return;
    }
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
        if (reset) {
            [self stopOrdersRealtimeListener];
        }
        NSLog(@"PPBackend > ORDERS_HISTORY : Fetch aborted | reason=UserNotAuthenticated | reset=%d", reset);
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

    NSLog(@"PPBackend > ORDERS_HISTORY : Query dispatch | userID=%@ | reset=%d | pageSize=%ld | startAfterDoc=%@",
          userID,
          reset,
          (long)self.pageSize,
          self.lastDocument.documentID ?: @"none");

    if (reset) {
        [self startOrdersRealtimeListenerWithQuery:query userID:userID];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"PPBackend > ORDERS_HISTORY : Pagination getDocuments response | count=%lu | isFromCache=%d | error=%@",
                  (unsigned long)snapshot.documents.count,
                  snapshot.metadata.isFromCache,
                  error.localizedDescription ?: @"none");
            [weakSelf handleOrdersSnapshot:snapshot error:error reset:reset];
        });
    }];
}

- (void)startOrdersRealtimeListenerWithQuery:(FIRQuery *)query userID:(NSString *)userID
{
    NSString *safeUserID = [userID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (safeUserID.length == 0) {
        [self stopOrdersRealtimeListener];
        [self finishFetchingWithErrorMessage:kLang(@"UserNotAuthenticated") reset:YES];
        return;
    }

    [self stopOrdersRealtimeListener];
    self.ordersListenerUserID = safeUserID;
    NSLog(@"PPBackend > ORDERS_HISTORY : Realtime listener starting | userID=%@ | pageSize=%ld | collection=Orders",
          safeUserID,
          (long)self.pageSize);

    __weak typeof(self) weakSelf = self;
    self.ordersListener = [query addSnapshotListenerWithIncludeMetadataChanges:YES
                                                                       listener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (![strongSelf.ordersListenerUserID isEqualToString:safeUserID]) return;
            NSLog(@"PPBackend > ORDERS_HISTORY : Realtime snapshot received | count=%lu | isFromCache=%d | hasPendingWrites=%d | error=%@",
                  (unsigned long)snapshot.documents.count,
                  snapshot.metadata.isFromCache,
                  snapshot.metadata.hasPendingWrites,
                  error.localizedDescription ?: @"none");
            [strongSelf handleOrdersSnapshot:snapshot error:error reset:YES];
        });
    }];
}

- (void)stopOrdersRealtimeListener
{
    if (self.ordersListener) {
        NSLog(@"PPBackend > ORDERS_HISTORY : Realtime listener stopped for userID=%@", self.ordersListenerUserID ?: @"unknown");
    }
    [self.ordersListener remove];
    self.ordersListener = nil;
    self.ordersListenerUserID = nil;
}

- (void)handleOrdersSnapshot:(FIRQuerySnapshot * _Nullable)snapshot error:(NSError * _Nullable)error reset:(BOOL)reset
{
    if (error) {
        NSLog(@"PPBackend > ORDERS_HISTORY : Snapshot error | domain=%@ | code=%ld | description=%@",
              error.domain,
              (long)error.code,
              error.localizedDescription);
        BOOL permissionDenied = [error.domain isEqualToString:FIRFirestoreErrorDomain] &&
            error.code == FIRFirestoreErrorCodePermissionDenied;
        NSString *message = permissionDenied
            ? kLang(@"order_history_permission_denied")
            : (error.localizedDescription ?: kLang(@"Error"));
        [self finishFetchingWithErrorMessage:message reset:reset];
        return;
    }

    self.orderHistorySnapshotFromCache = snapshot.metadata.isFromCache;

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

    NSInteger parsedCount = 0;
    for (FIRDocumentSnapshot *document in documents) {
        PPOrder *order = [PPOrder orderFromSnapshot:document];
        if (order) {
            [self.orders addObject:order];
            parsedCount += 1;
            NSLog(@"PPBackend > ORDERS_HISTORY : ↳ Order [#%@] status=%ld rawStatus=%@ amount=%.2f itemsCount=%lu createdAt=%@",
                  order.orderId ?: @"",
                  (long)order.status,
                  order.rawStatus ?: @"",
                  order.amount,
                  (unsigned long)order.items.count,
                  order.createdAt);
        }
    }

    NSLog(@"PPBackend > ORDERS_HISTORY : Snapshot processed | totalRawDocs=%lu | successfullyParsed=%ld | cumulativeOrders=%lu | hasMorePages=%d",
          (unsigned long)documents.count,
          (long)parsedCount,
          (unsigned long)self.orders.count,
          self.hasMorePages);

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
    if (self.orderHistorySurfaceController) {
        [self pp_publishOrderHistorySnapshot];
        return;
    }
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
    NSString *authenticatedUserID = PPOrderHistoryTrimmedString([FIRAuth auth].currentUser.uid);
    return authenticatedUserID;
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
    return title ?: @"";
}

- (void)refreshStatusFilterMenu
{
    NSString *selectedTitle = [self displayTitleForStatusFilterKey:self.selectedStatusFilterKey];
    NSInteger count = [self countForStatusFilterKey:self.selectedStatusFilterKey];
    self.filterSummaryLabel.text = [NSString stringWithFormat:kLang(@"order_history_filter_count_format"),
                                    selectedTitle,
                                    (long)count];
    self.filterSummaryLabel.textColor = [self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll]
    ? UIColor.secondaryLabelColor
    : [self colorForStatusFilterKey:self.selectedStatusFilterKey];

    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
        __weak typeof(self) weakSelf = self;
        for (NSDictionary *filter in [self statusFilterDefinitions]) {
            NSString *key = PPOrderHistoryTrimmedString(filter[@"key"]);
            NSString *title = PPOrderHistoryTrimmedString(filter[@"title"]);
            NSInteger filterCount = [self countForStatusFilterKey:key];
            NSString *actionTitle = [NSString stringWithFormat:kLang(@"order_history_filter_action_format"),
                                     title,
                                     (long)filterCount];
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
    [self pp_updateSearchTogglePresentation];
}

- (void)applyStatusFilterKey:(NSString *)filterKey
{
    NSString *resolvedKey = PPOrderHistoryTrimmedString(filterKey);
    if (resolvedKey.length == 0) {
        resolvedKey = kOrderHistoryFilterAll;
    }
    BOOL didChange = ![self.selectedStatusFilterKey isEqualToString:resolvedKey];
    self.selectedStatusFilterKey = resolvedKey;
    if (didChange) {
        UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
        [feedback selectionChanged];
    }
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
    NSLog(@"PPBackend > ORDERS_HISTORY : Filter & search applied | statusFilter=%@ | searchQuery='%@' | totalOrders=%lu | displayedOrders=%lu",
          self.selectedStatusFilterKey,
          query ?: @"",
          (unsigned long)self.orders.count,
          (unsigned long)self.displayedOrders.count);
    if (self.orderHistorySurfaceController) {
        [self pp_publishOrderHistorySnapshot];
        return;
    }
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
    SEL recoveryAction = @selector(refreshOrders);

    if (isErrorState) {
        title = kLang(@"load_error_title") ?: @"";
        subTitle = kLang(@"load_error_retry") ?: @"";
        buttonTitle = kLang(@"retry") ?: kLang(@"empty_retry_button");
        self.emptyStateConfig.animationName = @"404.json";
        self.emptyStateConfig.isNetworkFile = NO;
    } else {
        title = hasSearchOrFilter ? kLang(@"empty_no_results_title") : kLang(@"NoOrders");
        subTitle = hasSearchOrFilter ? (kLang(@"orders_empty_filtered") ?: @"") : @"";
        buttonTitle = hasSearchOrFilter ? kLang(@"ClearFilters") : kLang(@"empty_retry_button");
        recoveryAction = hasSearchOrFilter ? @selector(clearSearchAndFilters) : @selector(refreshOrders);
        self.emptyStateConfig.animationName = @"";
        self.emptyStateConfig.isNetworkFile = YES;
    }

    self.emptyStateConfig.title = title ?: @"";
    self.emptyStateConfig.subTitle = subTitle;
    self.emptyStateConfig.buttonTitle = buttonTitle;
    self.emptyStateConfig.target = self;
    self.emptyStateConfig.action = recoveryAction;

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
    cell.nameLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
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

    cell.isAccessibilityElement = YES;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    cell.accessibilityLabel = [NSString stringWithFormat:kLang(@"order_history_row_accessibility_format"),
                               cell.nameLabel.text ?: @"",
                               statusText ?: @"",
                               cell.quantityLabel.text ?: @"",
                               cell.priceLabel.text ?: @"",
                               [self formattedDate:order.createdAt] ?: @""];
    cell.accessibilityHint = kLang(@"order_history_row_accessibility_hint");
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
    return UITableViewAutomaticDimension;
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
    if ([cell isKindOfClass:OrderCell.class] && indexPath.row < (NSInteger)self.displayedOrders.count) {
        PPOrder *order = self.displayedOrders[indexPath.row];
        NSString *animationIdentity = order.orderId.length > 0
            ? order.orderId
            : [order displayOrderReference];
        BOOL shouldAnimate = animationIdentity.length > 0 &&
            ![self.animatedOrderIDs containsObject:animationIdentity] &&
            !tableView.isDragging &&
            !tableView.isDecelerating;
        if (animationIdentity.length > 0) {
            [self.animatedOrderIDs addObject:animationIdentity];
        }
        [(OrderCell *)cell playEntranceWithOrdinal:indexPath.row animated:shouldAnimate];
    }
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
    UIViewController *detailsVC = [PPOrderDetailsRouter controllerWithOrder:selectedOrder];
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

- (void)clearSearchAndFilters
{
    self.searchView.textField.text = @"";
    self.searchText = @"";
    self.selectedStatusFilterKey = kOrderHistoryFilterAll;
    [self refreshStatusFilterMenu];
    [self applyFiltersAndReload];
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
        NSString *actionTitle = [NSString stringWithFormat:kLang(@"order_history_filter_action_format"),
                                 title,
                                 (long)count];
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

#pragma mark - PPOrderHistorySurfaceControllerDelegate

- (void)orderHistorySurfaceDidRequestBack
{
    if (self.navigationController &&
        self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)orderHistorySurfaceDidRequestRefresh
{
    [self refreshOrders];
}

- (void)orderHistorySurfaceDidRequestLoadMore
{
    [self fetchOrdersReset:NO];
}

- (void)orderHistorySurfaceDidRequestSupport
{
    [self contactSupportTapped];
}

- (void)orderHistorySurfaceDidOpenOrder:(NSString *)orderID
{
    NSString *safeOrderID = PPOrderHistoryTrimmedString(orderID);
    if (safeOrderID.length == 0) return;

    PPOrder *selectedOrder = nil;
    for (PPOrder *order in self.orders ?: @[]) {
        NSString *identity = PPOrderHistoryTrimmedString(order.orderId);
        if (identity.length == 0) {
            identity = PPOrderHistoryTrimmedString([order displayOrderReference]);
        }
        if ([identity isEqualToString:safeOrderID]) {
            selectedOrder = order;
            break;
        }
    }
    if (!selectedOrder) return;

    UIViewController *detailsVC = [PPOrderDetailsRouter controllerWithOrder:selectedOrder];
    [self.navigationController pushViewController:detailsVC animated:YES];
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
    // The model intentionally falls back to a preparation delivery state. Preserve a
    // genuine customer-visible pending phase so the filter agrees with the row copy.
    if ([[self customerStatusKeyForOrder:order] isEqualToString:@"pending"]) {
        return kOrderHistoryFilterPending;
    }
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
    if ([key isEqualToString:@"ready_for_delivery"] ||
        [key isEqualToString:@"ready_to_ship"] ||
        [key isEqualToString:@"delivery_requested"] ||
        [key isEqualToString:@"delivery_reassigned"] ||
        [key isEqualToString:@"ready_for_pickup"] ||
        [key isEqualToString:@"ready"]) return kLang(@"Ready for Delivery");
    if ([key isEqualToString:@"delivery_partner_assigned"] ||
        [key isEqualToString:@"delivery_assigned"] ||
        [key isEqualToString:@"awaiting_handover"]) return kLang(@"Delivery Partner Assigned");
    if ([key isEqualToString:@"on_the_way"] ||
        [key isEqualToString:@"picked_up"] ||
        [key isEqualToString:@"handed_over"] ||
        [key isEqualToString:@"in_transit"]) return kLang(@"On the Way");
    if ([key isEqualToString:@"delivered"] ||
        [key isEqualToString:@"payment_pending"] ||
        [key isEqualToString:@"payment_confirmed"]) return kLang(@"Delivered");
    if ([key isEqualToString:@"completed"]) return kLang(@"Completed");
    if ([key isEqualToString:@"delivery_cancelled"]) return kLang(@"Delivery Cancelled");
    if ([key isEqualToString:@"delivery_failed"] ||
        [key isEqualToString:@"failed"]) return kLang(@"Delivery Failed");
    if ([key isEqualToString:@"returned_to_store"] ||
        [key isEqualToString:@"returned"]) return kLang(@"Returned to Store");
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
            if (weakSelf.orderHistorySurfaceController) {
                [weakSelf pp_publishOrderHistorySnapshot];
                return;
            }
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

- (NSString *)pp_localizedDecimalString:(double)value
{
    NSString *formatted = [self.orderAmountFormatter stringFromNumber:@(MAX(0.0, value))];
    return formatted.length > 0 ? formatted : @"0.00";
}

- (NSString *)formattedAmountForOrder:(PPOrder *)order
{
    NSString *currency = PPOrderHistoryTrimmedString(order.currency);
    if (currency.length == 0) currency = PPOrderHistoryTrimmedString([CountryModel safeCurrentCurrencyCode]);
    if (currency.length == 0) currency = @"QAR";
    return [NSString stringWithFormat:@"%@ %@",
            [self pp_localizedDecimalString:[self displayAmountValueForOrder:order]],
            currency];
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
    return [NSString stringWithFormat:@"%@ %@",
            [self pp_localizedDecimalString:amount],
            resolvedCurrency];
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
    if (self.orderHistorySurfaceController) {
        return;
    }
    if (message.length == 0 || self.presentedViewController) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Error")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
