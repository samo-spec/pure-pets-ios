#import "PurchasedItemsViewController.h"
#import "AccessViewerVC.h"
#import "AppClasses.h"
#import "CartItem.h"
#import "CartManager.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PPEmptyStateHelper.h"
#import "PPHUD.h"
#import "PPOrder.h"
#import "UserManager.h"
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>

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

@interface PPPurchasedProduct : NSObject
@property (nonatomic, copy) NSString *itemID;
@property (nonatomic, copy) NSString *fallbackName;
@property (nonatomic, copy) NSString *fallbackImageURL;
@property (nonatomic, assign) double fallbackPrice;
@property (nonatomic, assign) NSInteger quantity;
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
    self.cardView.layer.cornerRadius = 22.0;
    self.cardView.layer.masksToBounds = NO;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.07;
    self.cardView.layer.shadowRadius = 18.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 10);
    [self.contentView addSubview:self.cardView];

    self.productImageView = [[UIImageView alloc] init];
    self.productImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.productImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.productImageView.clipsToBounds = YES;
    self.productImageView.layer.cornerRadius = 18.0;
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

@interface PurchasedItemsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *loader;
@property (nonatomic, strong) PPEmptyStateConfig *emptyStateConfig;
@property (nonatomic, strong) NSArray<PPPurchasedProduct *> *items;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, assign) BOOL hasLoadedOnce;
@end

@implementation PurchasedItemsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.items = @[];
    self.view.backgroundColor = AppBageColor();
    [self pp_setupDateFormatter];
    [self pp_setupNavigation];
    [self pp_setupTableView];
    [self pp_setupLoader];
    [self pp_loadPurchasedItemsRefreshing:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_setupNavigation];
}

#pragma mark - Setup

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
    UIButton *refreshButton = [PPButtonHelper pp_buttonWithTitleForBar:nil
                                                              imageName:@"arrow.clockwise"
                                                                target:self
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
                [self pp_finishLoadingRefreshing:refreshing];
            });
            return;
        }

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
                entry.latestPurchaseDate = purchaseDate;
                deduped[itemID] = entry;
            } else {
                if (!entry.latestPurchaseDate || [purchaseDate compare:entry.latestPurchaseDate] == NSOrderedDescending) {
                    entry.latestPurchaseDate = purchaseDate;
                    entry.fallbackName = [self pp_orderItemString:rawItem keys:@[@"name", @"title", @"itemName", @"productName"]];
                    entry.fallbackImageURL = [self pp_orderItemString:rawItem keys:@[@"imageURL", @"imageUrl", @"image", @"photo", @"icon"]];
                    double price = [self pp_orderItemDouble:rawItem keys:@[@"price", @"finalPrice", @"unitPrice"]];
                    if (price > 0.0) entry.fallbackPrice = price;
                }
                NSInteger quantity = [self pp_orderItemQuantity:rawItem];
                if (quantity > 0) entry.quantity = quantity;
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
    if (accessory.quantity <= 0) {
        if (reason) *reason = kLang(@"Out of stock") ?: @"Out of stock";
        return YES;
    }
    return NO;
}

#pragma mark - Actions

- (void)pp_addPurchasedItemToCart:(PPPurchasedProduct *)product
{
    NSString *reason = nil;
    if ([self pp_isAccessoryUnavailable:product.accessory reason:&reason]) {
        [PPHUD showError:reason];
        return;
    }

    CartItem *item = [[CartItem alloc] initWithAccessory:product.accessory quantity:1];
    [[CartManager sharedManager] addItem:item
                presentingViewController:self
                              completion:^(BOOL didAdd, BOOL didCancel) {
        if (didCancel) { return; }
        if (didAdd) {
            [PPFunc triggerLightHaptic];
            [PPHUD showSuccess:kLang(@"ItemAddedToCart") ?: kLang(@"purchased_item_added_to_cart") ?: @"Item added to cart"];
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

#pragma mark - UITableView

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
