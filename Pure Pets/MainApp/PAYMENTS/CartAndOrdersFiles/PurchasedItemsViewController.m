#import "PurchasedItemsViewController.h"
#import "AccessViewerVC.h"
#import "AppClasses.h"
#import "CartItem.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PPEmptyStateHelper.h"
#import "PPHUD.h"
#import "PPOrder.h"
#import "UserManager.h"
@import FirebaseAuth;
@import FirebaseFirestore;
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <Pure_Pets-Swift.h>

static NSString * const PPPurchasedItemCellID = @"PPPurchasedItemCell";
static NSInteger const PPPurchasedItemsOrderLimit = 120;

static NSString *PPPurchasedTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *PPPurchasedNormalizedStatusString(id value)
{
    NSString *normalized = [[PPPurchasedTrimmedString(value) lowercaseString] copy];
    if (normalized.length == 0) return @"";
    normalized = [normalized stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([normalized containsString:@"__"]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return normalized;
}

static BOOL PPPurchasedStatusMatchesKeyword(NSString *statusKey, NSString *keyword)
{
    NSString *status = PPPurchasedNormalizedStatusString(statusKey);
    NSString *needle = PPPurchasedNormalizedStatusString(keyword);
    if (status.length == 0 || needle.length == 0) return NO;
    if ([status isEqualToString:needle]) return YES;
    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", status];
    NSString *wrappedNeedle = [NSString stringWithFormat:@"_%@_", needle];
    return [wrappedStatus containsString:wrappedNeedle] || [status containsString:needle];
}

static NSString *PPPurchasedCategoryKeyForAccessory(PetAccessory *accessory, NSString *fallbackName)
{
    NSString *text = [NSString stringWithFormat:@"%@ %@", accessory.name ?: fallbackName ?: @"", accessory.desc ?: @""].lowercaseString;

    NSArray<NSString *> *foodKeywords = @[
        @"طعام", @"أكل", @"غذاء", @"وجبة", @"دراي", @"رطب", @"مكافآت", @"لحم", @"دجاج", @"سمك", @"سالمون", @"تونا", @"حبوب", @"حليب",
        @"food", @"dry", @"wet", @"treat", @"snack", @"meat", @"chicken", @"fish", @"salmon", @"tuna", @"kibble", @"feed"
    ];
    for (NSString *keyword in foodKeywords) {
        if ([text containsString:keyword]) return @"food";
    }

    NSArray<NSString *> *healthKeywords = @[
        @"علاج", @"دواء", @"صحة", @"عناية", @"فيتامين", @"شامبو", @"نظافة", @"معقم", @"قطرة", @"مرهم", @"بخاخ", @"طبي", @"براغيث", @"ديدان",
        @"care", @"health", @"med", @"vitamin", @"shampoo", @"hygiene", @"spray", @"drops", @"vet", @"flea", @"tick", @"supplement", @"deworm"
    ];
    for (NSString *keyword in healthKeywords) {
        if ([text containsString:keyword]) return @"health";
    }

    return @"accessories";
}

static NSString *PPPurchasedCategoryTagText(NSString *categoryKey)
{
    if ([categoryKey isEqualToString:@"food"]) {
        return [NSString stringWithFormat:@"🏷️ %@", kLang(@"purchased_filter_food") ?: @"أغذية وتغذية"];
    } else if ([categoryKey isEqualToString:@"health"]) {
        return [NSString stringWithFormat:@"🏷️ %@", kLang(@"purchased_filter_health") ?: @"عناية وصحة"];
    } else {
        return [NSString stringWithFormat:@"🏷️ %@", kLang(@"purchased_filter_accessories") ?: @"مستلزمات وألعاب"];
    }
}

static NSInteger PPPurchasedDaysBetweenDates(NSDate *fromDateTime, NSDate *toDateTime)
{
    if (!fromDateTime || !toDateTime) return 0;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *difference = [calendar components:NSCalendarUnitDay
                                               fromDate:fromDateTime
                                                 toDate:toDateTime
                                                options:0];
    return MAX(0, [difference day]);
}

@interface PPPurchasedProduct : NSObject
@property (nonatomic, copy) NSString *itemID;
@property (nonatomic, copy) NSString *fallbackName;
@property (nonatomic, copy) NSString *fallbackImageURL;
@property (nonatomic, assign) double fallbackPrice;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) NSInteger purchaseCount;
@property (nonatomic, strong, nullable) NSDate *latestPurchaseDate;
@property (nonatomic, strong, nullable) PetAccessory *accessory;
@property (nonatomic, assign) BOOL productDocumentMissing;
@end

@implementation PPPurchasedProduct
@end

@interface PPPurchasedItemCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *productImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *buyButton;
@property (nonatomic, copy, nullable) void (^buyHandler)(void);
- (void)configureWithItem:(PPPurchasedProduct *)item
            dateFormatter:(NSDateFormatter *)dateFormatter
              unavailable:(BOOL)unavailable
                   reason:(NSString *)reason;
@end

@implementation PPPurchasedItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        [self pp_setupViews];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.productImageView.image = nil;
    self.buyHandler = nil;
    self.cardView.transform = CGAffineTransformIdentity;
    self.cardView.alpha = 1.0;
}

- (void)pp_setupViews
{
    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.cardView.layer.cornerRadius = 20.0;
    self.cardView.layer.masksToBounds = NO;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.06;
    self.cardView.layer.shadowRadius = 14.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 6);
    [self.contentView addSubview:self.cardView];

    self.productImageView = [[UIImageView alloc] init];
    self.productImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.productImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.productImageView.clipsToBounds = YES;
    self.productImageView.layer.cornerRadius = 14.0;
    self.productImageView.backgroundColor = AppBackgroundClr ?: UIColor.tertiarySystemBackgroundColor;
    [self.cardView addSubview:self.productImageView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = 2;

    self.metaLabel = [[UILabel alloc] init];
    self.metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaLabel.font = [GM fontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0];
    self.metaLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.metaLabel.numberOfLines = 1;

    self.dateLabel = [[UILabel alloc] init];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.font = [GM fontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0];
    self.dateLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.dateLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.dateLabel.numberOfLines = 1;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [GM fontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0];
    self.statusLabel.textColor = UIColor.systemRedColor;
    self.statusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.statusLabel.numberOfLines = 2;

    self.buyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.buyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.buyButton.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.buyButton.layer.cornerRadius = 17.0;
    self.buyButton.clipsToBounds = YES;
    [self.buyButton addTarget:self action:@selector(pp_buyTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.metaLabel,
        self.dateLabel,
        self.statusLabel
    ]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 4.0;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.cardView addSubview:textStack];
    [self.cardView addSubview:self.buyButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7.0],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7.0],

        [self.productImageView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:14.0],
        [self.productImageView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14.0],
        [self.productImageView.bottomAnchor constraintLessThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-14.0],
        [self.productImageView.widthAnchor constraintEqualToConstant:82.0],
        [self.productImageView.heightAnchor constraintEqualToConstant:82.0],

        [textStack.leadingAnchor constraintEqualToAnchor:self.productImageView.trailingAnchor constant:14.0],
        [textStack.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-14.0],
        [textStack.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14.0],

        [self.buyButton.leadingAnchor constraintEqualToAnchor:textStack.leadingAnchor],
        [self.buyButton.topAnchor constraintGreaterThanOrEqualToAnchor:textStack.bottomAnchor constant:10.0],
        [self.buyButton.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-14.0],
        [self.buyButton.heightAnchor constraintEqualToConstant:34.0],
        [self.buyButton.widthAnchor constraintGreaterThanOrEqualToConstant:112.0],
    ]];
}

- (void)configureWithItem:(PPPurchasedProduct *)item
            dateFormatter:(NSDateFormatter *)dateFormatter
              unavailable:(BOOL)unavailable
                   reason:(NSString *)reason
{
    PetAccessory *accessory = item.accessory;
    NSString *name = accessory.name.length > 0 ? accessory.name : item.fallbackName;
    self.titleLabel.text = name.length > 0 ? name : (kLang(@"purchased_item_unknown_product") ?: @"Product");

    double price = accessory ? [accessory.finalPrice doubleValue] : item.fallbackPrice;
    NSString *priceText = price > 0.0 ? [PetAccessory formatCurrency:@(price)] : @"";
    NSString *qtyText = item.quantity > 0
        ? [NSString stringWithFormat:@"%@ %ld", kLang(@"purchased_item_quantity") ?: @"Qty", (long)item.quantity]
        : @"";
    if (priceText.length > 0 && qtyText.length > 0) {
        self.metaLabel.text = [NSString stringWithFormat:@"%@  •  %@", priceText, qtyText];
    } else {
        self.metaLabel.text = priceText.length > 0 ? priceText : qtyText;
    }

    if (item.latestPurchaseDate) {
        self.dateLabel.text = [NSString stringWithFormat:@"%@ %@",
                               kLang(@"purchased_item_latest_purchase") ?: @"Latest purchase",
                               [dateFormatter stringFromDate:item.latestPurchaseDate]];
    } else {
        self.dateLabel.text = @"";
    }

    self.statusLabel.text = unavailable ? reason : @"";
    self.statusLabel.hidden = !unavailable;
    self.buyButton.enabled = !unavailable;
    self.buyButton.alpha = unavailable ? 0.52 : 1.0;

    NSString *buttonTitle = kLang(@"purchased_item_buy_again");
    if (buttonTitle.length == 0) buttonTitle = kLang(@"AddToCart");
    if (buttonTitle.length == 0) buttonTitle = @"Buy Again";

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
        configuration.title = buttonTitle;
        configuration.image = [UIImage systemImageNamed:@"cart.badge.plus"];
        configuration.imagePadding = 7.0;
        configuration.baseForegroundColor = unavailable ? UIColor.secondaryLabelColor : UIColor.whiteColor;
        configuration.baseBackgroundColor = unavailable ? UIColor.systemGray5Color : (AppPrimaryClr ?: UIColor.systemPinkColor);
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        self.buyButton.configuration = configuration;
    } else {
        [self.buyButton setTitle:buttonTitle forState:UIControlStateNormal];
        self.buyButton.backgroundColor = unavailable ? UIColor.systemGray5Color : (AppPrimaryClr ?: UIColor.systemPinkColor);
        [self.buyButton setTitleColor:unavailable ? UIColor.secondaryLabelColor : UIColor.whiteColor forState:UIControlStateNormal];
    }

    NSString *imageURL = @"";
    if ([accessory.imageURLsArray isKindOfClass:NSArray.class] &&
        [accessory.imageURLsArray.firstObject isKindOfClass:NSString.class]) {
        imageURL = accessory.imageURLsArray.firstObject;
    }
    if (imageURL.length == 0) imageURL = item.fallbackImageURL;
    if (imageURL.length > 0) {
        [GM setImageFromUrlString:imageURL imageView:self.productImageView phImage:@"placeholder"];
    } else {
        self.productImageView.image = [UIImage systemImageNamed:@"shippingbox.fill"];
    }
}

- (void)pp_buyTapped
{
    if (self.buyHandler) self.buyHandler();
}

@end

@interface PurchasedItemsViewController () <UITableViewDataSource, UITableViewDelegate, PPPurchasedItemsSurfaceControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *loader;
@property (nonatomic, strong) PPEmptyStateConfig *emptyStateConfig;
@property (nonatomic, strong) NSArray<PPPurchasedProduct *> *items;
@property (nonatomic, strong) NSDictionary<NSString *, PPPurchasedProduct *> *productsByID;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, assign) BOOL hasLoadedOnce;
@property (nonatomic, assign) NSInteger totalOrdersLoaded;
@property (nonatomic, strong) PPPurchasedItemsSurfaceController *surfaceController API_AVAILABLE(ios(15.0));
@end

@implementation PurchasedItemsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.items = @[];
    self.productsByID = @{};
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    [self pp_setupDateFormatter];

    if (@available(iOS 15.0, *)) {
        [self pp_installNextGenSurface];
    } else {
        [self pp_setupNavigation];
        [self pp_setupTableView];
        [self pp_setupLoader];
    }

    [self pp_loadPurchasedItemsRefreshing:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (@available(iOS 15.0, *)) {
        if (self.surfaceController) {
            [self.navigationController setNavigationBarHidden:YES animated:animated];
            NSInteger count = [CartManager sharedManager].cartItems.count;
            double cartTotal = [self pp_calculateCurrentCartTotal];
            NSString *formatted = cartTotal > 0.0 ? [PetAccessory formatCurrency:@(cartTotal)] : @"";
            [self.surfaceController updateCartBadgeWithCount:(int)count total:formatted];
            return;
        }
    }
    [self pp_setupNavigation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (@available(iOS 15.0, *)) {
        if (self.surfaceController) {
            [self.navigationController setNavigationBarHidden:NO animated:animated];
        }
    }
}

#pragma mark - NextGen Surface Installation

- (void)pp_installNextGenSurface API_AVAILABLE(ios(15.0))
{
    PPPurchasedItemsSurfaceController *surface = [[PPPurchasedItemsSurfaceController alloc] initWithDelegate:self];
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
    self.surfaceController = surface;

    // Publish initial loading state
    [self pp_publishNextGenSnapshotWithProducts:@[] totalOrders:0 isLoading:YES];
}

#pragma mark - Setup (Legacy / Fallback)

- (void)pp_setupDateFormatter
{
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.locale = NSLocale.currentLocale;
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy"];
}

- (void)pp_setupNavigation
{
    BOOL showBack = self.navigationController.viewControllers.count > 1;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:kLang(@"purchased_items_title")
                    showBack:showBack];
    UIButton *refreshButton = [self pp_ButtonWithSystemName:@"arrow.clockwise"
                                                     action:@selector(pp_refreshPulled)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
}

- (void)pp_setupTableView
{
    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) style = UITableViewStylePlain;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 132.0;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.tableView registerClass:PPPurchasedItemCell.class forCellReuseIdentifier:PPPurchasedItemCellID];
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(pp_refreshPulled) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    self.emptyStateConfig = [PPEmptyStateConfig new];
    self.emptyStateConfig.animationName = @"";
    self.emptyStateConfig.isNetworkFile = NO;
    self.emptyStateConfig.buttonTitle = kLang(@"empty_retry_button");
    self.emptyStateConfig.target = self;
    self.emptyStateConfig.action = @selector(pp_refreshPulled);

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)pp_setupLoader
{
    self.loader = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loader.translatesAutoresizingMaskIntoConstraints = NO;
    self.loader.hidesWhenStopped = YES;
    [self.view addSubview:self.loader];
    [NSLayoutConstraint activateConstraints:@[
        [self.loader.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loader.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

#pragma mark - Loading

- (NSString *)pp_currentUserID
{
    NSString *userID = PPPurchasedTrimmedString(UserManager.sharedManager.currentUser.ID);
    if (userID.length == 0) userID = [FIRAuth auth].currentUser.uid ?: @"";
    return userID;
}

- (void)pp_refreshPulled
{
    [self pp_loadPurchasedItemsRefreshing:YES];
}

- (void)pp_loadPurchasedItemsRefreshing:(BOOL)refreshing
{
    NSString *userID = [self pp_currentUserID];
    if (userID.length == 0) {
        self.errorMessage = kLang(@"UserNotAuthenticated") ?: @"Please sign in first.";
        self.items = @[];
        self.productsByID = @{};
        [self pp_finishLoadingRefreshing:refreshing];
        return;
    }

    if (!refreshing && !self.hasLoadedOnce) {
        [self.loader startAnimating];
    }
    self.errorMessage = @"";

    FIRFirestore *db = FIRFirestore.firestore;
    FIRQuery *query = [[[db collectionWithPath:@"Orders"] queryWhereField:@"userId" isEqualTo:userID]
                       queryOrderedByField:@"createdAt" descending:YES];
    query = [query queryLimitedTo:PPPurchasedItemsOrderLimit];

    __weak typeof(self) weakSelf = self;
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.errorMessage = error.localizedDescription ?: (kLang(@"Error") ?: @"Error");
                self.items = @[];
                self.productsByID = @{};
                [self pp_finishLoadingRefreshing:refreshing];
            });
            return;
        }

        NSInteger validOrdersCount = 0;
        for (FIRDocumentSnapshot *doc in snapshot.documents ?: @[]) {
            PPOrder *order = [PPOrder orderFromSnapshot:doc];
            if ([self pp_shouldIncludeOrderForPurchasedItems:order]) {
                validOrdersCount++;
            }
        }
        self.totalOrdersLoaded = validOrdersCount;

        NSArray<PPPurchasedProduct *> *snapshotItems = [self pp_purchasedProductsFromSnapshot:snapshot];
        NSArray<NSString *> *itemIDs = [self pp_itemIDsFromPurchasedProducts:snapshotItems];
        [self pp_resolveAccessoriesForProducts:snapshotItems
                                       itemIDs:itemIDs
                                    refreshing:refreshing];
    }];
}

- (NSArray<PPPurchasedProduct *> *)pp_purchasedProductsFromSnapshot:(FIRQuerySnapshot *)snapshot
{
    NSMutableDictionary<NSString *, PPPurchasedProduct *> *deduped = [NSMutableDictionary dictionary];

    for (FIRDocumentSnapshot *document in snapshot.documents ?: @[]) {
        PPOrder *order = [PPOrder orderFromSnapshot:document];
        if (![order isKindOfClass:PPOrder.class]) continue;
        if (![self pp_shouldIncludeOrderForPurchasedItems:order]) continue;

        NSDate *purchaseDate = order.completedAt ?: order.deliveredAt ?: order.paidAt ?: order.paymentCollectedAt ?: order.createdAt;
        for (id rawItem in order.items ?: @[]) {
            NSString *itemID = [self pp_orderItemID:rawItem];
            if (itemID.length == 0) continue;

            PPPurchasedProduct *entry = deduped[itemID];
            if (!entry) {
                entry = [PPPurchasedProduct new];
                entry.itemID = itemID;
                entry.fallbackName = [self pp_orderItemString:rawItem keys:@[@"name", @"title", @"itemName", @"productName"]];
                entry.fallbackImageURL = [self pp_orderItemString:rawItem keys:@[@"imageURL", @"imageUrl", @"image", @"photo", @"icon"]];
                entry.fallbackPrice = [self pp_orderItemDouble:rawItem keys:@[@"price", @"finalPrice", @"unitPrice"]];
                entry.quantity = [self pp_orderItemQuantity:rawItem];
                entry.purchaseCount = 1;
                entry.latestPurchaseDate = purchaseDate;
                deduped[itemID] = entry;
            } else {
                entry.purchaseCount += 1;
                NSInteger quantity = [self pp_orderItemQuantity:rawItem];
                entry.quantity += (quantity > 0 ? quantity : 1);

                if (!entry.latestPurchaseDate || [purchaseDate compare:entry.latestPurchaseDate] == NSOrderedDescending) {
                    entry.latestPurchaseDate = purchaseDate;
                    NSString *name = [self pp_orderItemString:rawItem keys:@[@"name", @"title", @"itemName", @"productName"]];
                    if (name.length > 0) entry.fallbackName = name;
                    NSString *img = [self pp_orderItemString:rawItem keys:@[@"imageURL", @"imageUrl", @"image", @"photo", @"icon"]];
                    if (img.length > 0) entry.fallbackImageURL = img;
                    double price = [self pp_orderItemDouble:rawItem keys:@[@"price", @"finalPrice", @"unitPrice"]];
                    if (price > 0.0) entry.fallbackPrice = price;
                }
            }
        }
    }

    NSArray *values = deduped.allValues;
    return [values sortedArrayUsingComparator:^NSComparisonResult(PPPurchasedProduct *left, PPPurchasedProduct *right) {
        NSDate *leftDate = left.latestPurchaseDate ?: NSDate.distantPast;
        NSDate *rightDate = right.latestPurchaseDate ?: NSDate.distantPast;
        return [rightDate compare:leftDate];
    }];
}

- (BOOL)pp_shouldIncludeOrderForPurchasedItems:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class] || order.items.count == 0) {
        return NO;
    }

    NSString *status = [PPOrder normalizedStatusFromRawValue:[order customerVisibleStatusKey]];
    NSArray<NSString *> *failureStatuses = @[
        @"abandoned",
        @"cancelled",
        @"canceled",
        @"declined",
        @"delivery_cancelled",
        @"delivery_delayed",
        @"error",
        @"expired",
        @"failed",
        @"payment_failed",
        @"rejected",
        @"voided"
    ];
    for (NSString *failureStatus in failureStatuses) {
        if (PPPurchasedStatusMatchesKeyword(status, failureStatus)) {
            return NO;
        }
    }

    return YES;
}

- (NSArray<NSString *> *)pp_itemIDsFromPurchasedProducts:(NSArray<PPPurchasedProduct *> *)products
{
    NSMutableArray<NSString *> *itemIDs = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (PPPurchasedProduct *product in products ?: @[]) {
        if (product.itemID.length == 0 || [seen containsObject:product.itemID]) continue;
        [seen addObject:product.itemID];
        [itemIDs addObject:product.itemID];
    }
    return itemIDs.copy;
}

- (void)pp_resolveAccessoriesForProducts:(NSArray<PPPurchasedProduct *> *)products
                                 itemIDs:(NSArray<NSString *> *)itemIDs
                              refreshing:(BOOL)refreshing
{
    if (itemIDs.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.items = products ?: @[];
            NSMutableDictionary *map = [NSMutableDictionary dictionary];
            for (PPPurchasedProduct *p in self.items) {
                if (p.itemID.length > 0) map[p.itemID] = p;
            }
            self.productsByID = map.copy;
            [self pp_finishLoadingRefreshing:refreshing];
        });
        return;
    }

    [PetAccessoryManager fetchAccessoriesWithIDs:itemIDs completion:^(NSArray<PetAccessory *> *accessories) {
        NSMutableDictionary<NSString *, PetAccessory *> *accessoryByID = [NSMutableDictionary dictionary];
        for (PetAccessory *accessory in accessories ?: @[]) {
            if (![accessory isKindOfClass:PetAccessory.class] || accessory.accessoryID.length == 0) continue;
            accessoryByID[accessory.accessoryID] = accessory;
        }

        for (PPPurchasedProduct *product in products ?: @[]) {
            product.accessory = accessoryByID[product.itemID];
            product.productDocumentMissing = (product.accessory == nil);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.items = products ?: @[];
            NSMutableDictionary *map = [NSMutableDictionary dictionary];
            for (PPPurchasedProduct *p in self.items) {
                if (p.itemID.length > 0) map[p.itemID] = p;
            }
            self.productsByID = map.copy;
            [self pp_finishLoadingRefreshing:refreshing];
        });
    }];
}

- (void)pp_finishLoadingRefreshing:(BOOL)refreshing
{
    self.hasLoadedOnce = YES;
    [self.loader stopAnimating];
    if (refreshing) [self.refreshControl endRefreshing];
    [self pp_updateEmptyState];
    [self.tableView reloadData];

    if (@available(iOS 15.0, *)) {
        [self pp_publishNextGenSnapshotWithProducts:self.items
                                        totalOrders:self.totalOrdersLoaded
                                          isLoading:NO];
    }
}

- (double)pp_calculateCurrentCartTotal
{
    double total = 0.0;
    for (CartItem *item in [CartManager sharedManager].cartItems ?: @[]) {
        total += item.lineSubtotal;
    }
    return total;
}

- (void)pp_publishNextGenSnapshotWithProducts:(NSArray<PPPurchasedProduct *> *)products
                                  totalOrders:(NSInteger)totalOrders
                                    isLoading:(BOOL)isLoading API_AVAILABLE(ios(15.0))
{
    if (!self.surfaceController) return;

    PPPurchasedItemsSnapshotDescriptor *snapshot = [PPPurchasedItemsSnapshotDescriptor new];
    snapshot.isInitialLoading = isLoading;
    snapshot.showsBackButton = (self.navigationController.viewControllers.count > 1 || self.presentingViewController != nil);

    NSMutableArray<PPPurchasedItemDescriptor *> *itemDescriptors = [NSMutableArray arrayWithCapacity:products.count];
    NSInteger foodCount = 0;
    NSInteger accessoriesCount = 0;
    NSInteger healthCount = 0;
    NSInteger popularCount = 0;
    NSInteger readyForRefillCount = 0;
    NSInteger totalUnitsRestocked = 0;

    NSDate *now = [NSDate date];

    for (PPPurchasedProduct *product in products) {
        PetAccessory *accessory = product.accessory;
        PPPurchasedItemDescriptor *desc = [PPPurchasedItemDescriptor new];
        desc.id = product.itemID ?: @"";

        NSString *name = accessory.name.length > 0 ? accessory.name : product.fallbackName;
        desc.name = name.length > 0 ? name : (kLang(@"purchased_item_unknown_product") ?: @"Product");

        NSString *imageURL = @"";
        if ([accessory.imageURLsArray isKindOfClass:NSArray.class] && accessory.imageURLsArray.count > 0) {
            imageURL = accessory.imageURLsArray.firstObject;
        }
        if (imageURL.length == 0) imageURL = product.fallbackImageURL ?: @"";
        desc.imageURL = imageURL;

        double currentPrice = accessory ? [accessory.finalPrice doubleValue] : product.fallbackPrice;
        desc.price = currentPrice;
        desc.formattedPrice = currentPrice > 0.0 ? [PetAccessory formatCurrency:@(currentPrice)] : @"";

        if (accessory && accessory.price && [accessory.price doubleValue] > currentPrice) {
            desc.hasDiscount = YES;
            desc.originalPrice = [accessory.price doubleValue];
            desc.formattedOriginalPrice = [PetAccessory formatCurrency:accessory.price];
        }

        desc.purchaseCount = MAX(1, product.purchaseCount);
        desc.totalUnitsPurchased = MAX(1, product.quantity);
        totalUnitsRestocked += desc.totalUnitsPurchased;

        desc.latestPurchaseDate = product.latestPurchaseDate;
        if (product.latestPurchaseDate) {
            desc.latestPurchaseDateText = [NSString stringWithFormat:kLang(@"purchased_cadence_last_date") ?: @"Last order: %@",
                                           [self.dateFormatter stringFromDate:product.latestPurchaseDate]];
        } else {
            desc.latestPurchaseDateText = @"";
        }

        NSString *unavailReason = nil;
        desc.isOutOfStock = [self pp_isAccessoryUnavailable:accessory reason:&unavailReason];
        desc.stockQuantity = accessory ? accessory.quantity : 0;
        if (desc.isOutOfStock) {
            desc.stockStatusText = kLang(@"purchased_stock_out_of_stock") ?: @"Out of Stock";
        } else if (accessory && accessory.quantity > 0 && accessory.quantity <= 5) {
            desc.stockStatusText = [NSString stringWithFormat:kLang(@"purchased_stock_remaining_format") ?: @"%ld left", (long)accessory.quantity];
        } else {
            desc.stockStatusText = kLang(@"purchased_stock_available") ?: @"In Stock";
        }

        desc.categoryKey = PPPurchasedCategoryKeyForAccessory(accessory, product.fallbackName);
        if ([desc.categoryKey isEqualToString:@"food"]) foodCount++;
        else if ([desc.categoryKey isEqualToString:@"health"]) healthCount++;
        else accessoriesCount++;

        desc.categoryTagText = PPPurchasedCategoryTagText(desc.categoryKey);
        desc.weightOrSizeText = accessory.weightText.length > 0 ? accessory.weightText : (accessory.size ?: @"");

        NSInteger daysSince = PPPurchasedDaysBetweenDates(product.latestPurchaseDate, now);
        desc.isReadyForRefill = (desc.purchaseCount >= 2 && daysSince >= 14) || desc.purchaseCount >= 3;
        if (desc.isReadyForRefill) readyForRefillCount++;

        if (desc.purchaseCount >= 2) popularCount++;

        desc.cadenceBadgeText = desc.purchaseCount > 1
            ? [NSString stringWithFormat:kLang(@"purchased_cadence_times_format") ?: @"Ordered %ld times", (long)desc.purchaseCount]
            : (kLang(@"purchased_cadence_once") ?: @"Ordered once");

        desc.searchIndex = [NSString stringWithFormat:@"%@ %@ %@ %@",
                            desc.name, desc.weightOrSizeText, desc.categoryTagText, desc.latestPurchaseDateText].lowercaseString;

        [itemDescriptors addObject:desc];
    }

    snapshot.items = itemDescriptors;
    snapshot.totalDistinctCount = itemDescriptors.count;
    snapshot.totalOrdersCount = totalOrders;
    snapshot.totalUnitsRestocked = totalUnitsRestocked;
    snapshot.readyForRefillCount = readyForRefillCount;

    // Quick Reorder Items: Top 5 by purchaseCount or latest purchase
    NSArray<PPPurchasedItemDescriptor *> *sortedForQuick = [itemDescriptors sortedArrayUsingComparator:^NSComparisonResult(PPPurchasedItemDescriptor *a, PPPurchasedItemDescriptor *b) {
        if (a.purchaseCount != b.purchaseCount) {
            return a.purchaseCount < b.purchaseCount ? NSOrderedDescending : NSOrderedAscending;
        }
        NSDate *dateA = a.latestPurchaseDate ?: NSDate.distantPast;
        NSDate *dateB = b.latestPurchaseDate ?: NSDate.distantPast;
        return [dateB compare:dateA];
    }];
    snapshot.quickReorderItems = [sortedForQuick subarrayWithRange:NSMakeRange(0, MIN(sortedForQuick.count, 6))];

    // Filter Chips
    snapshot.filters = @[
        [[PPPurchasedFilterDescriptor alloc] initWithId:@"all"
                                                  title:kLang(@"purchased_filter_all") ?: @"All"
                                                   icon:@"sparkles"
                                                  count:(int)itemDescriptors.count],
        [[PPPurchasedFilterDescriptor alloc] initWithId:@"food"
                                                  title:kLang(@"purchased_filter_food") ?: @"Food & Treats"
                                                   icon:@"fork.knife"
                                                  count:(int)foodCount],
        [[PPPurchasedFilterDescriptor alloc] initWithId:@"accessories"
                                                  title:kLang(@"purchased_filter_accessories") ?: @"Supplies & Toys"
                                                   icon:@"pawprint.fill"
                                                  count:(int)accessoriesCount],
        [[PPPurchasedFilterDescriptor alloc] initWithId:@"health"
                                                  title:kLang(@"purchased_filter_health") ?: @"Care & Health"
                                                   icon:@"cross.case.fill"
                                                  count:(int)healthCount],
        [[PPPurchasedFilterDescriptor alloc] initWithId:@"popular"
                                                  title:kLang(@"purchased_filter_popular") ?: @"Most Repeated"
                                                   icon:@"flame.fill"
                                                  count:(int)popularCount]
    ];

    snapshot.cartBadgeCount = [CartManager sharedManager].cartItems.count;
    double cartTotal = [self pp_calculateCurrentCartTotal];
    snapshot.cartTotalFormatted = cartTotal > 0.0 ? [PetAccessory formatCurrency:@(cartTotal)] : @"";

    [self.surfaceController applySnapshot:snapshot];
}

- (void)pp_updateEmptyState
{
    if (self.items.count > 0) {
        [PPEmptyStateHelper removeEmptyStateFromListView:self.tableView];
        return;
    }

    NSString *title = self.errorMessage.length > 0
        ? (kLang(@"Error") ?: @"Error")
        : (kLang(@"purchased_items_empty_title") ?: @"No purchased items yet.");
    NSString *message = self.errorMessage.length > 0 ? self.errorMessage : @"";
    self.emptyStateConfig.title = title;
    self.emptyStateConfig.subTitle = message;
    self.emptyStateConfig.buttonTitle = self.errorMessage.length > 0 ? (kLang(@"empty_retry_button") ?: @"Retry") : @"";
    [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                          dataCount:0
                                             config:self.emptyStateConfig];
}

#pragma mark - Order Item Parsing

- (id)pp_valueFromRawItem:(id)rawItem keys:(NSArray<NSString *> *)keys
{
    if (![rawItem isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *dictionary = (NSDictionary *)rawItem;
    for (NSString *key in keys) {
        id value = dictionary[key];
        if (value && ![value isKindOfClass:NSNull.class]) return value;
    }

    NSArray<NSString *> *nestedKeys = @[@"product", @"item", @"accessory", @"snapshot"];
    for (NSString *nestedKey in nestedKeys) {
        NSDictionary *nested = [dictionary[nestedKey] isKindOfClass:NSDictionary.class] ? dictionary[nestedKey] : nil;
        if (!nested) continue;

        for (NSString *key in keys) {
            id value = nested[key];
            if (value && ![value isKindOfClass:NSNull.class]) return value;
        }
    }

    return nil;
}

- (NSString *)pp_orderItemID:(id)rawItem
{
    if ([rawItem isKindOfClass:NSString.class]) return PPPurchasedTrimmedString(rawItem);
    return PPPurchasedTrimmedString([self pp_valueFromRawItem:rawItem keys:@[@"id", @"itemID", @"productId", @"productID"]]);
}

- (NSString *)pp_orderItemString:(id)rawItem keys:(NSArray<NSString *> *)keys
{
    return PPPurchasedTrimmedString([self pp_valueFromRawItem:rawItem keys:keys]);
}

- (NSInteger)pp_orderItemQuantity:(id)rawItem
{
    id value = [self pp_valueFromRawItem:rawItem keys:@[@"qty", @"quantity", @"count"]];
    return [value respondsToSelector:@selector(integerValue)] ? MAX(0, [value integerValue]) : 0;
}

- (double)pp_orderItemDouble:(id)rawItem keys:(NSArray<NSString *> *)keys
{
    id value = [self pp_valueFromRawItem:rawItem keys:keys];
    return [value respondsToSelector:@selector(doubleValue)] ? MAX(0.0, [value doubleValue]) : 0.0;
}

#pragma mark - Availability

- (BOOL)pp_isAccessoryUnavailable:(PetAccessory *)accessory reason:(NSString **)reason
{
    if (!accessory) {
        if (reason) *reason = kLang(@"purchased_item_unavailable") ?: @"This item is no longer available.";
        return YES;
    }
    if (accessory.isDeleted || accessory.isBlocked || accessory.isDisabled) {
        if (reason) *reason = kLang(@"purchased_item_unavailable") ?: @"This item is no longer available.";
        return YES;
    }
    if (!accessory.showInAppMarket) {
        if (reason) *reason = kLang(@"purchased_item_hidden") ?: @"This item is currently hidden.";
        return YES;
    }
    if (accessory.isOutOfStock || accessory.quantity <= 0) {
        if (reason) *reason = kLang(@"Out of stock") ?: @"Out of stock";
        return YES;
    }
    return NO;
}

#pragma mark - Actions

- (void)pp_addPurchasedItemToCart:(PPPurchasedProduct *)product
{
    [self pp_addPurchasedItemToCart:product quantity:1];
}

- (void)pp_addPurchasedItemToCart:(PPPurchasedProduct *)product quantity:(NSInteger)quantity
{
    NSString *reason = nil;
    if ([self pp_isAccessoryUnavailable:product.accessory reason:&reason]) {
        [PPHUD showError:reason];
        return;
    }

    CartItem *item = [[CartItem alloc] initWithAccessory:product.accessory quantity:MAX(1, quantity)];
    __weak typeof(self) weakSelf = self;
    [[CartManager sharedManager] addItem:item
                presentingViewController:self
                               completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || didCancel) return;
        if (didAdd) {
            [PPFunc triggerLightHaptic];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [PPAddToCartSuccessToast showWithTitle:kLang(@"ItemAddedToCart") ?: kLang(@"purchased_item_added_to_cart") ?: @"Item added to cart"];
            });
            if (@available(iOS 15.0, *)) {
                if (self.surfaceController) {
                    NSInteger count = [CartManager sharedManager].cartItems.count;
                    double cartTotal = [self pp_calculateCurrentCartTotal];
                    NSString *formatted = cartTotal > 0.0 ? [PetAccessory formatCurrency:@(cartTotal)] : @"";
                    [self.surfaceController updateCartBadgeWithCount:(int)count total:formatted];
                }
            }
        } else {
            [PPHUD showError:kLang(@"Out of stock") ?: @"Out of stock"];
        }
    }];
}

- (void)pp_openProduct:(PPPurchasedProduct *)product
{
    NSString *reason = nil;
    if ([self pp_isAccessoryUnavailable:product.accessory reason:&reason]) {
        [PPHUD showInfo:reason];
        return;
    }

    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = product.accessory;
    viewer.ParentVC = self;
    [self.navigationController pushViewController:viewer animated:YES];
}

#pragma mark - PPPurchasedItemsSurfaceControllerDelegate

- (void)purchasedItemsSurfaceDidRequestBack
{
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)purchasedItemsSurfaceDidRequestRefresh
{
    [self pp_loadPurchasedItemsRefreshing:YES];
}

- (void)purchasedItemsSurfaceDidRequestAddToCart:(NSString *)itemID quantity:(NSInteger)quantity
{
    PPPurchasedProduct *product = self.productsByID[itemID];
    if (!product || !product.accessory) {
        [PPHUD showError:kLang(@"purchased_item_unavailable") ?: @"This item is no longer available."];
        return;
    }
    [self pp_addPurchasedItemToCart:product quantity:quantity];
}

- (void)purchasedItemsSurfaceDidRequestOpenProduct:(NSString *)itemID
{
    PPPurchasedProduct *product = self.productsByID[itemID];
    if (!product) return;
    [self pp_openProduct:product];
}

- (void)purchasedItemsSurfaceDidRequestOpenCart
{
    CartViewController *vc = [CartViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)purchasedItemsSurfaceDidRequestExploreStore
{
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UITableView (Legacy Fallback)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPPurchasedItemCell *cell = [tableView dequeueReusableCellWithIdentifier:PPPurchasedItemCellID forIndexPath:indexPath];
    PPPurchasedProduct *item = self.items[indexPath.row];
    NSString *reason = nil;
    BOOL unavailable = [self pp_isAccessoryUnavailable:item.accessory reason:&reason];
    [cell configureWithItem:item dateFormatter:self.dateFormatter unavailable:unavailable reason:reason ?: @""];

    __weak typeof(self) weakSelf = self;
    __weak typeof(item) weakItem = item;
    cell.buyHandler = ^{
        __strong typeof(weakSelf) self = weakSelf;
        __strong typeof(weakItem) item = weakItem;
        if (!self || !item) return;
        [self pp_addPurchasedItemToCart:item];
    };

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        cell.cardView.alpha = 0.0;
        cell.cardView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
        [UIView animateWithDuration:0.34
                              delay:MIN(indexPath.row, 8) * 0.035
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.12
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            cell.cardView.alpha = 1.0;
            cell.cardView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 14.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 18.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.items.count) return;
    [self pp_openProduct:self.items[indexPath.row]];
}

@end
