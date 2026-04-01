//
//  OrderHistoryViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/06/2025.
//

#import "OrderHistoryViewController.h"
#import "OrderCell.h"
#import "OrderDetailsViewController.h"
#import "PPOrder.h"
#import "UserManager.h"
#import "AppClasses.h"
#import "PPEmptyStateHelper.h"
#import "ChManager.h"
#import "CountryModel.h"
#import "PPS.h"
#import "CartManager.h"
@import FirebaseAuth;
@import FirebaseFirestore;

static NSString * const kOrderHistoryCellID = @"OrderCell";
static NSInteger const kOrderHistoryPageSize = 12;
static CGFloat const kOrderHistoryRowHeight = 120.0;
static NSString * const kOrderSupportPhoneNumber = @"+97459997720";

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
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"failed", @"rejected", @"declined", @"expired", @"error", @"voided"])) {
        return kOrderHistoryFilterFailed;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"delivered", @"completed", @"fulfilled"])) {
        return kOrderHistoryFilterDelivered;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"])) {
        return kOrderHistoryFilterShipped;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"processing", @"preparing", @"packed", @"confirmed"])) {
        return kOrderHistoryFilterProcessing;
    }
    if (PPOrderHistoryStatusMatchesAnyKeyword(normalized, @[@"paid", @"success", @"approved", @"verified", @"captured", @"authorized"])) {
        return kOrderHistoryFilterPaid;
    }
    return kOrderHistoryFilterPending;
}

@interface OrderHistoryViewController () <UITableViewDataSource, UITableViewDelegate, PPSDelegate, UIScrollViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *searchContainer;
@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) UILabel *filterSummaryLabel;
@property (nonatomic, strong) UIActivityIndicatorView *initialLoader;
@property (nonatomic, strong) UIActivityIndicatorView *paginationLoader;
@property (nonatomic, strong) PPEmptyStateConfig *emptyStateConfig;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

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
@property (nonatomic, strong) NSDateFormatter *orderDateFormatter;

@end

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
    [self setupNavigationBar];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutViews];
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
    self.orders = [NSMutableArray array];
    self.displayedOrders = @[];
    self.accessoryCache = [NSMutableDictionary dictionary];
    self.inFlightAccessoryIDs = [NSMutableSet set];
    self.orderDateFormatter = [[NSDateFormatter alloc] init];
    self.orderDateFormatter.locale = [NSLocale currentLocale];
    [self.orderDateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM yyyy h:mm a"];
    self.view.backgroundColor = PPBackgroundColorForIOS26([GM backOffwhileColor]);
    [self emptyViewConfiger];
}

- (void)setupNavigationBar
{
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"OrderHistory") showBack:NO];

    UIButton *supportButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"headphones.dots" target:self action:@selector(contactSupportTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:supportButton];

    UIButton *refreshButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"arrow.clockwise" target:self action:@selector(refreshOrders)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
}

- (void)emptyViewConfiger
{
    self.emptyStateConfig = [PPEmptyStateConfig new];
    self.emptyStateConfig.animationName = @"Shopping Cart Empty.json";
    self.emptyStateConfig.isNetworkFile = YES;
    self.emptyStateConfig.buttonTitle = kLang(@"empty_retry_button");
    self.emptyStateConfig.target = self;
    self.emptyStateConfig.action = @selector(refreshOrders);
}

- (void)setupViews
{
    self.searchContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.searchContainer.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.searchContainer];

    self.searchView = [[PPS alloc] initWithFrame:CGRectZero];
    self.searchView.delegate = self;
    self.searchView.blurEnabled = YES;
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
    [self.searchContainer addSubview:self.searchView];

    self.filterSummaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.filterSummaryLabel.font = [GM MidFontWithSize:12];
    self.filterSummaryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.filterSummaryLabel.textColor = UIColor.secondaryLabelColor;
    [self.searchContainer addSubview:self.filterSummaryLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = AppClearClr;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = kOrderHistoryRowHeight;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.contentInset = UIEdgeInsetsMake(12, 0, 86, 0);
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.tableView registerClass:[OrderCell class] forCellReuseIdentifier:kOrderHistoryCellID];
    [self.view addSubview:self.tableView];

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
}

- (void)layoutViews
{
    CGFloat topInset = self.view.safeAreaInsets.top;
    CGFloat horizontalPadding = 14.0;
    CGFloat searchHeight = 56.0;
    CGFloat summaryHeight = 18.0;

    self.searchContainer.frame = CGRectMake(horizontalPadding,
                                            topInset + 4.0,
                                            self.view.bounds.size.width - (horizontalPadding * 2.0),
                                            searchHeight + summaryHeight + 10.0);
    self.searchView.frame = CGRectMake(0.0,
                                       0.0,
                                       self.searchContainer.bounds.size.width,
                                       searchHeight);
    self.filterSummaryLabel.frame = CGRectMake(6.0,
                                               CGRectGetMaxY(self.searchView.frame) + 6.0,
                                               self.searchContainer.bounds.size.width - 12.0,
                                               summaryHeight);

    CGFloat tableTop = CGRectGetMaxY(self.searchContainer.frame) + 8.0;
    self.tableView.frame = CGRectMake(0,
                                      tableTop,
                                      self.view.bounds.size.width,
                                      self.view.bounds.size.height - tableTop);

    self.initialLoader.center = self.view.center;
}

#pragma mark - Data

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
    self.isFetchingInitial = NO;
    self.isFetchingMore = NO;
    [self.initialLoader stopAnimating];
    [self.refreshControl endRefreshing];
    [self setPaginationLoading:NO];
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

#pragma mark - Filter & Search

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
        [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                              dataCount:self.displayedOrders.count
                                                 config:self.emptyStateConfig];
        return;
    }

    NSString *trimmed = [self.searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasSearchOrFilter = (trimmed.length > 0 &&
                              ![trimmed isEqualToString:@""]) ||
    ![self.selectedStatusFilterKey isEqualToString:kOrderHistoryFilterAll];

    NSString *title = hasSearchOrFilter ? kLang(@"empty_no_results_title") : kLang(@"NoOrders");
    if (![title isKindOfClass:NSString.class] || title.length == 0 || [title isEqualToString:@"NoOrders"]) {
        title = hasSearchOrFilter ? (kLang(@"empty_no_results_title") ?: @"") : (kLang(@"OrderHistory") ?: @"");
    }

    self.emptyStateConfig.title = title ?: @"";
    self.emptyStateConfig.subTitle = hasSearchOrFilter ? (kLang(@"orders_empty_filtered") ?: @"") : @"";
    self.emptyStateConfig.buttonTitle = kLang(@"empty_retry_button") ?: @"";
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
    cell.nameLabel.text = [self formattedAmountForOrder:order];

    NSString *statusText = [self displayTitleForOrder:order];
    UIColor *statusColor = [self statusColorForOrder:order];
    NSString *statusDisplay = [NSString stringWithFormat:@"● %@", statusText ?: @""];
    NSMutableAttributedString *statusAttr = [[NSMutableAttributedString alloc] initWithString:statusDisplay];
    if (statusDisplay.length > 0) {
        [statusAttr addAttributes:@{
            NSForegroundColorAttributeName: statusColor,
            NSFontAttributeName: [GM boldFontWithSize:13]
        } range:NSMakeRange(0, 1)];
    }
    if (statusDisplay.length > 1) {
        [statusAttr addAttributes:@{
            NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
            NSFontAttributeName: [GM MidFontWithSize:14]
        } range:NSMakeRange(1, statusDisplay.length - 1)];
    }
    cell.priceLabel.attributedText = statusAttr;

    NSInteger quantity = [self totalQuantityForOrder:order];
    cell.quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)quantity];
    cell.dateLabel.text = [self formattedDate:order.createdAt];
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

#pragma mark - Status Helpers

- (NSString *)normalizedStatusKeyForOrder:(PPOrder *)order
{
    NSString *status = PPOrderHistoryNormalizedStatus(order.rawStatus);
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
    return [self displayTitleForStatusFilterKey:[self canonicalStatusFilterKeyForOrder:order]];
}

- (UIColor *)statusColorForOrder:(PPOrder *)order
{
    NSString *filterKey = [self canonicalStatusFilterKeyForOrder:order];
    if ([filterKey isEqualToString:kOrderHistoryFilterPending]) {
        return UIColor.systemOrangeColor;
    }
    if ([filterKey isEqualToString:kOrderHistoryFilterPaid]) {
        return [GM appPrimaryColor];
    }
    if ([filterKey isEqualToString:kOrderHistoryFilterProcessing]) {
        return UIColor.systemOrangeColor;
    }
    if ([filterKey isEqualToString:kOrderHistoryFilterShipped]) {
        return UIColor.systemBlueColor;
    }
    if ([filterKey isEqualToString:kOrderHistoryFilterDelivered]) {
        return UIColor.systemGreenColor;
    }
    if ([filterKey isEqualToString:kOrderHistoryFilterCancelled] ||
        [filterKey isEqualToString:kOrderHistoryFilterFailed]) {
        return UIColor.systemRedColor;
    }
    return UIColor.systemGrayColor;
}

#pragma mark - Accessory Preview

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

#pragma mark - Formatting

- (NSString *)formattedAmountForOrder:(PPOrder *)order
{
    NSString *currency = PPOrderHistoryTrimmedString(order.currency);
    if (currency.length == 0) currency = PPOrderHistoryTrimmedString([CountryModel safeCurrentCurrencyCode]);
    if (currency.length == 0) currency = @"QAR";

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
    totalAmount = MAX(0.0, totalAmount);

    return [NSString stringWithFormat:@"%.2f %@", totalAmount, currency];
}

- (NSString *)formattedDate:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) return @"";
    return [self.orderDateFormatter stringFromDate:date];
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

#pragma mark - Alerts

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
