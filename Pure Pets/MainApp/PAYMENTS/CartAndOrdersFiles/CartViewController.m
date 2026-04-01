
//  CartViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.

#import "CartViewController.h"
#import "BBCheckoutSummaryView.h"
#import "CartManager.h"
#import "PPOrderManager.h"
#import "PPSPinnerView.h"
#import "ChManager.h"
#import "AppClasses.h"
#import "PPCommerceFeedbackManager.h"

static NSString *const kCartSupportPhoneNumber = @"+97459997720";

@interface CustomTextViewCell : XLFormTextViewCell @end

@implementation CustomTextViewCell
- (void)configure {
    [super configure];
    self.textView.layer.cornerRadius = 12;
    self.textView.layer.masksToBounds = YES;
    self.textView.backgroundColor = GM.AppForegroundColor;
}

@end

@interface CartViewController ()
@property (nonatomic, strong) PPSPinnerView *spinner;

@property (nonatomic, strong) UITableView *cartTableView;
@property (nonatomic, strong) BBCheckoutSummaryView *summaryView;
@property (nonatomic, strong) UIView *undoContainerView;
@property (nonatomic, strong) UILabel *undoLabel;
@property (nonatomic, strong) UIButton *undoButton;
@property (nonatomic, strong) CartItem *lastRemovedCartItem;
@property (nonatomic, assign) NSInteger lastRemovedCartIndex;
@property (nonatomic, assign) NSUInteger undoPresentationToken;

@property (nonatomic,
           strong,
           nullable) NSLayoutConstraint *tableBottomConstraint;
@property (nonatomic, strong, readonly) PPEmptyStateConfig *config;
@property (nonatomic, assign) BOOL isPerformingTableMutation;
@end

@implementation CartViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);

    // Table
    self.cartTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.cartTableView.dataSource = self;
    self.cartTableView.delegate = self;
    self.cartTableView.backgroundColor = UIColor.clearColor;
    self.cartTableView.separatorColor = UIColor.clearColor;
    self.cartTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cartTableView.showsHorizontalScrollIndicator = NO;
    self.cartTableView.showsVerticalScrollIndicator = NO;

    [self.cartTableView registerClass:[CartTableViewCell class] forCellReuseIdentifier:@"CartTableViewCell"];
    [self.cartTableView registerClass:[PPCartTableCell class] forCellReuseIdentifier:@"PPCartTableCell"];

    [self.view addSubview:self.cartTableView];
    self.cartTableView.contentInset = UIEdgeInsetsMake(16, 0,16, 0);
        
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    // Ensure summary view exists before using it
    [self setSummuryViewAtBottom];
    [self pp_setupUndoBarIfNeeded];

    [NSLayoutConstraint activateConstraints:@[
        [self.cartTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.cartTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.cartTableView.topAnchor constraintEqualToAnchor:safe.topAnchor]
    ]];

    // Set the bottom constraint ONCE, after summaryView is present
  

    // Empty state config (reused)
    [self emptyViewConfiger];

    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateViewFromSync)
                                                 name:kCartUpdatedNotification
                                               object:nil];
    
    // Initial UI
    [self setupFormFooterFrom:@"LOAD"];
    [self updateTotalLabel];
    [self pp_applyEmptyStateIfNeeded];
    
    self.cartTableView.layer.cornerRadius = 32;
    self.cartTableView.clipsToBounds = YES;
    
    self.cartTableView.layer.maskedCorners  = kCALayerMinXMinYCorner|kCALayerMaxXMinYCorner
    ;}
- (void)setSummuryViewAtBottom
{
    self.summaryView = [[BBCheckoutSummaryView alloc] init];
    
    [self.view addSubview:self.summaryView];
     [self.summaryView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.summaryView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.summaryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    __weak typeof(self) weakSelf = self;
     self.summaryView.onTapCheckOut = ^{
         NSLog(@"🛒 Checkout tapped on CART      +Helper");
        [weakSelf checkoutTapped];
    };
    // Update summary with cart data
    CGFloat itemsTotal = 0.0;
    for (CartItem *item in CartManager.sharedManager.cartItems) {itemsTotal += item.price * item.quantity; }
    [self.summaryView updateTotalsWithItems:itemsTotal shipping:[CartManager sharedManager].deliveryFee showTitle:YES];
    self.summaryView.showDetails =YES;
    [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];
    self.summaryView.showsItemsPreview =  NO;
    [self.summaryView setCardBackgroundImage:PPImage(@"4444")];
    [self.summaryView setCheckoutBTNTitle:kLang(@"Checkout") image: [UIImage pp_symbolNamed:Language.isRTL ? @"arrow.left" : @"arrow.right" pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:NO]];


    
    
}




// Constraint flow: anchor tableView.bottom to summaryView.top after summaryView is laid out
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [_summaryView layoutIfNeeded];
    [_summaryView setNeedsLayout];

    // Anchor tableView AFTER summaryView has final frame
    if (!self.tableBottomConstraint &&
        self.summaryView.bounds.size.height > 0) {

        self.tableBottomConstraint =
        [self.cartTableView.bottomAnchor
         constraintEqualToAnchor:self.summaryView.topAnchor
                         constant:-0];

        self.tableBottomConstraint.active = YES;
    }
}

- (void)reloadFormData {
    CGFloat totalPrice = 0;
    NSInteger totalQty = 0;

    for (CartItem *item in [CartManager sharedManager].cartItems) {
        totalPrice += item.price * item.quantity;
        totalQty += item.quantity;
    }

    (void)totalPrice;
    (void)totalQty;
}
- (void)setupFormFooterFrom:(NSString *)setupFrom {
    
  // // [self pp_applyEmptyStateIfNeeded];
}


-(void)startEditingCartItems
{
    UIAlertController *menu = [UIAlertController
                               alertControllerWithTitle:kLang(@"cart_support_menu_title")
                               message:nil
                               preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *callAction = [UIAlertAction actionWithTitle:kLang(@"Call")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses callPhoneNumber:kCartSupportPhoneNumber fromViewController:self];
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
        UIBarButtonItem *sourceButton = self.navigationItem.rightBarButtonItem;
        if (sourceButton) {
            popover.barButtonItem = sourceButton;
        } else {
            popover.sourceView = self.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                            CGRectGetMinY(self.view.bounds) + 44.0,
                                            1.0,
                                            1.0);
        }
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:menu animated:YES completion:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
    [CartManager.sharedManager refreshPricingConfiguration];
  
    if(PPIOS26())
    {
        [super viewWillAppear:animated];
        [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"cartTitle") showBack:NO];
         self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(@"xmark") style:UIBarButtonItemStylePlain target:self action:@selector(onDissmiss)];
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(@"headphones.dots") style:UIBarButtonItemStylePlain target:self action:@selector(startEditingCartItems)];
        
    }
    else
    {
        [super viewWillAppear:animated];
        [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"cartTitle") showBack:YES];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(@"headphones.dots")
                                                                                    style:UIBarButtonItemStylePlain
                                                                                   target:self
                                                                                   action:@selector(startEditingCartItems)];

    }

    [self.summaryView setCheckoutLoading:NO];
    
    if ([CartManager sharedManager].cartItems.count > 0) {
        _summaryView.alpha = 1;
    } else {
        _summaryView.alpha = 0;
    }
   //
    
    
    [_summaryView layoutSubviews];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //[[NSNotificationCenter defaultCenter]   postNotificationName:PPExpandSystemTabBarNotification  object:nil];
    [_summaryView pp_stopTrustBannerShimmer];
    [self pp_hideUndoBarAnimated:NO clearPayload:NO];
}

- (void)continueShopping
{
   // [[NSNotificationCenter defaultCenter] tionName:PPRouteToSearchAccessoriesNotificationKey  object:nil];
}


- (void)emptyViewConfiger {

    _config = [PPEmptyStateConfig new];
    _config.animationName = @"Shopping Cart Empty.json";
    _config.title =  kLang(@"empty_cart_title");
    _config.subTitle = kLang(@"empty_cart_subtitle");
    _config.buttonTitle = kLang(@"continue_shopping");
    _config.target = self;
    _config.action = @selector(continueShopping);
    _config.isNetworkFile = YES;
    
    if ([CartManager sharedManager].cartItems.count == 0) {
        // self.checkoutButton.alpha = 0;
    } else {
        // self.checkoutButton.alpha = 1;
    }
}

#pragma mark - Empty State (Reusable Block)

- (void)pp_applyEmptyStateIfNeeded
{
    // Guard: tableView must exist
    if (!self.cartTableView) return;

    NSInteger itemsCount = [CartManager sharedManager].cartItems.count;

    // If has data → remove empty state
    if (itemsCount > 0) {
        self.cartTableView.backgroundView = nil;
        return;
    }

    // -------- Empty State View --------
    UIView *container = [[UIView alloc] initWithFrame:self.cartTableView.bounds];
    container.backgroundColor = UIColor.clearColor;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    // Icon / animation placeholder
    UIImageView *icon = [[UIImageView alloc] initWithImage:
                          [UIImage systemImageNamed:@"cart"]];
    icon.tintColor = UIColor.secondaryLabelColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    // Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kLang(@"empty_cart_title");
    titleLabel.font = [GM boldFontWithSize:20];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;

    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = kLang(@"empty_cart_subtitle");
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;

    // Action button
    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [actionButton setTitle:kLang(@"continue_shopping") forState:UIControlStateNormal];
    actionButton.titleLabel.font = [GM boldFontWithSize:16];
    actionButton.tintColor = UIColor.whiteColor;
    actionButton.backgroundColor = AppPrimaryClr;
    actionButton.layer.cornerRadius = 14;
    actionButton.contentEdgeInsets = UIEdgeInsetsMake(12, 24, 12, 24);
    [actionButton addTarget:self
                     action:@selector(onDissmiss)
           forControlEvents:UIControlEventTouchUpInside];

    // Assemble
    [stack addArrangedSubview:icon];
    [stack addArrangedSubview:titleLabel];
    [stack addArrangedSubview:subtitleLabel];
    [stack addArrangedSubview:actionButton];

    [container addSubview:stack];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-24],

        [icon.widthAnchor constraintEqualToConstant:56],
        [icon.heightAnchor constraintEqualToConstant:56]
    ]];

    self.cartTableView.backgroundView = container;
}

 
- (void)showOders {
    OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)updateTotalLabel {
    CGFloat itemsTotal = 0.0;
    NSInteger totalQty = 0;

    for (CartItem *item in [CartManager sharedManager].cartItems) {
        itemsTotal += item.price * item.quantity;
        totalQty += item.quantity;
    }

    // Shipping policy: 0 if cart empty, otherwise 22
    CGFloat shipping = ([CartManager sharedManager].cartItems.count == 0) ? 0.0 : [CartManager sharedManager].deliveryFee;

    // Keep summary in sync
    [self.summaryView updateTotalsWithItems:itemsTotal shipping:shipping showTitle:YES];

    // Show/hide summary
    self.summaryView.alpha = ([CartManager sharedManager].cartItems.count > 0) ? 1.0 : 0.0;

    // Empty state
    [self pp_applyEmptyStateIfNeeded];

    (void)totalQty; // kept for future UI uses
}

// Guard: Only reload if not mutating table (prevents reload/deleteRows conflict)
- (void)updateViewFromSync
{
    if (self.isPerformingTableMutation) {
        NSLog(@"[CART] 🔁 Skipping reload during table mutation");
        return;
    }

    [self.cartTableView reloadData];
    [self updateTotalLabel];
}

- (void)pp_notifyCartBadgeAndCollections
{
    if ([self.delegate respondsToSelector:@selector(loadItemsCountInBadge)]) {
        [self.delegate loadItemsCountInBadge];
    }
    if ([self.delegate respondsToSelector:@selector(updateCartAndReloadCollection)]) {
        [self.delegate updateCartAndReloadCollection];
    }
}

- (CartItem *)pp_cloneCartItem:(CartItem *)item
{
    if (!item) return nil;
    CartItem *copy = [[CartItem alloc] init];
    copy.itemID = item.itemID ?: @"";
    copy.name = item.name ?: @"";
    copy.quantity = item.quantity;
    copy.price = item.price;
    copy.imageURL = item.imageURL ?: @"";
    copy.type = item.type ?: @"";
    return copy;
}

- (void)pp_setupUndoBarIfNeeded
{
    if (self.undoContainerView) return;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.96];
    container.layer.cornerRadius = 14.0;
    container.layer.shadowColor = UIColor.blackColor.CGColor;
    container.layer.shadowOpacity = 0.12;
    container.layer.shadowOffset = CGSizeMake(0, 4);
    container.layer.shadowRadius = 8;
    container.alpha = 0.0;
    container.hidden = YES;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:14];
    label.textColor = AppPrimaryTextClr;
    label.numberOfLines = 2;
    label.text = kLang(@"cart_undo_message");
    label.textAlignment = Language.alignmentForCurrentLanguage;

    UIButton *undoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    undoButton.translatesAutoresizingMaskIntoConstraints = NO;
    undoButton.titleLabel.font = [GM boldFontWithSize:14];
    [undoButton setTitle:kLang(@"cart_undo_action") forState:UIControlStateNormal];
    [undoButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    [undoButton addTarget:self action:@selector(pp_undoLastRemovalTapped) forControlEvents:UIControlEventTouchUpInside];

    [container addSubview:label];
    [container addSubview:undoButton];
    [self.view addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [container.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-12],
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:52],

        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14],
        [label.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:undoButton.leadingAnchor constant:-10],

        [undoButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12],
        [undoButton.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];

    self.undoContainerView = container;
    self.undoLabel = label;
    self.undoButton = undoButton;
    self.lastRemovedCartIndex = NSNotFound;
}

- (void)pp_presentUndoForItem:(CartItem *)item originalIndex:(NSInteger)index
{
    self.lastRemovedCartItem = [self pp_cloneCartItem:item];
    self.lastRemovedCartIndex = index;
    self.undoLabel.text = kLang(@"cart_undo_message");
    [self.undoButton setTitle:kLang(@"cart_undo_action") forState:UIControlStateNormal];

    self.undoPresentationToken += 1;
    NSUInteger token = self.undoPresentationToken;

    self.undoContainerView.hidden = NO;
    [UIView animateWithDuration:0.22 animations:^{
        self.undoContainerView.alpha = 1.0;
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (token != self.undoPresentationToken) return;
        [self pp_hideUndoBarAnimated:YES clearPayload:YES];
    });
}

- (void)pp_hideUndoBarAnimated:(BOOL)animated clearPayload:(BOOL)clearPayload
{
    self.undoPresentationToken += 1;
    if (clearPayload) {
        self.lastRemovedCartItem = nil;
        self.lastRemovedCartIndex = NSNotFound;
    }

    if (!animated) {
        self.undoContainerView.alpha = 0.0;
        self.undoContainerView.hidden = YES;
        return;
    }

    [UIView animateWithDuration:0.2 animations:^{
        self.undoContainerView.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        self.undoContainerView.hidden = YES;
    }];
}

- (void)pp_undoLastRemovalTapped
{
    if (!self.lastRemovedCartItem) return;

    CartItem *restored = [self pp_cloneCartItem:self.lastRemovedCartItem];
    NSInteger preferredIndex = self.lastRemovedCartIndex;
    [self pp_hideUndoBarAnimated:YES clearPayload:YES];

    CartManager *manager = [CartManager sharedManager];
    CartItem *existing = [manager getCartItemForItemID:restored.itemID];
    if (existing) {
        NSInteger mergedQuantity = existing.quantity + restored.quantity;
        [manager updateQuantity:mergedQuantity forItem:existing completion:nil];
    } else {
        NSInteger safeIndex = MIN(MAX(preferredIndex, 0), manager.cartItems.count);
        [manager.cartItems insertObject:restored atIndex:safeIndex];
        [manager saveCart];

        if (UserManager.sharedManager.currentUser.ID.length > 0) {
            [manager syncCartToFirestore:@[restored]];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
        }
    }

    [self pp_notifyCartBadgeAndCollections];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartUndo];
}

- (void)pp_removeItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath) return;
    if (indexPath.row >= CartManager.sharedManager.cartItems.count) return;
    if (self.isPerformingTableMutation) return;

    self.isPerformingTableMutation = YES;

    CartItem *item = CartManager.sharedManager.cartItems[indexPath.row];
    CartItem *removedSnapshot = [self pp_cloneCartItem:item];
    NSInteger removedIndex = indexPath.row;

    [[CartManager sharedManager] removeItem:item];
    [[CartManager sharedManager] saveCart];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartItemRemoved];

    [self.cartTableView performBatchUpdates:^{
        [self.cartTableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
    } completion:^(__unused BOOL finished) {
        self.isPerformingTableMutation = NO;
        [self updateTotalLabel];
        [self pp_notifyCartBadgeAndCollections];
        [self pp_presentUndoForItem:removedSnapshot originalIndex:removedIndex];
    }];
}

- (void)checkoutTapped {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [self.summaryView setCheckoutLoading:NO];
        [UserManager showPromptOnTopController];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    if ([CartManager sharedManager].cartItems.count == 0) {
        [self.summaryView setCheckoutLoading:NO];
        [PPHUD showError:kLang(@"empty_cart_title")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [self.summaryView setCheckoutLoading:YES];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    // Order is created in PPCheckoutCoordinator from payment screen.
    PPSelectPaymentVC *vc = [[PPSelectPaymentVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [CartManager sharedManager].cartItems.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    PPCartTableCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPCartTableCell"];
        if (!cell) cell = [[PPCartTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PPCartTableCell"];
        
        CartItem *item = [CartManager sharedManager].cartItems[indexPath.row];
        [cell configureWithItem:item];
    __weak typeof(cell) weakCell = cell;
    cell.onAction = ^(CartItem *item, NSString *action) {
        if ([action isEqualToString:@"plus"] || [action isEqualToString:@"minus"]) {
            __strong typeof(weakCell) strongCell = weakCell;
            NSIndexPath *currentIndexPath = [tableView indexPathForCell:strongCell];
            if (currentIndexPath) {
                [tableView reloadRowsAtIndexPaths:@[currentIndexPath]
                                 withRowAnimation:UITableViewRowAnimationAutomatic];
            }

            [[CartManager sharedManager] updateQuantity:item.quantity
                                                forItem:item
                                             completion:nil];
            [self updateTotalLabel];
            return;
        }
        if ([action isEqualToString:@"remove"]) {
            __strong typeof(weakCell) cell = weakCell;
            NSIndexPath *currentIndexPath =
                [tableView indexPathForCell:cell];
            if (!currentIndexPath) return;
            [self pp_removeItemAtIndexPath:currentIndexPath];
        }
    };

    cell.layer.masksToBounds = NO;
    cell.clipsToBounds = NO;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 104;
}

// Enable swipe-to-delete (SAFE)
- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (style != UITableViewCellEditingStyleDelete) return;
    [self pp_removeItemAtIndexPath:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= CartManager.sharedManager.cartItems.count) return nil;

    UIContextualAction *removeAction =
    [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                            title:kLang(@"cart_swipe_remove")
                                          handler:^(__unused UIContextualAction * _Nonnull action,
                                                    __unused UIView * _Nonnull sourceView,
                                                    void (^ _Nonnull completionHandler)(BOOL)) {
        [self pp_removeItemAtIndexPath:indexPath];
        completionHandler(YES);
    }];

    if (@available(iOS 13.0, *)) {
        removeAction.image = [UIImage systemImageNamed:@"trash.fill"];
    }
    removeAction.backgroundColor = [UIColor systemRedColor];

    UISwipeActionsConfiguration *config =
    [UISwipeActionsConfiguration configurationWithActions:@[removeAction]];
    config.performsFirstActionWithFullSwipe = YES;
    return config;
}

- (NSString *)tableView:(UITableView *)tableView
titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    (void)indexPath;
    return kLang(@"cart_swipe_remove");
}
/*
 // Remove from CartManager (single source of truth)
 [[CartManager sharedManager] removeItem:item];
 [[CartManager sharedManager] saveCart];
 */
- (void)syncCartToFirestore:(NSArray<CartItem *> *)items {
    // U8: Use authenticated UID from FIRAuth as primary source, with UserManager fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) {
        userID = UserManager.sharedManager.currentUser.ID;
    }

    if (!userID || userID.length == 0) {
        NSLog(@"⚠️ [Cart] Cannot sync — no authenticated user");
        return;
    }

    // U6: Validate cart items before Firestore write
    if (items.count == 0) {
        NSLog(@"⚠️ [Cart] syncCartToFirestore called with empty items array");
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSString *orderID = [NSString stringWithFormat:@"order_%@", [[NSUUID UUID] UUIDString]];

    FIRDocumentReference *orderRef = [[[[db collectionWithPath:@"UsersCol"]
                                        documentWithPath:userID]
                                       collectionWithPath:@"orders"]
                                      documentWithPath:orderID];

    NSMutableDictionary *orderSummary = [NSMutableDictionary dictionary];
    NSMutableArray *itemData = [NSMutableArray array];
    NSInteger totalQty = 0;
    float totalPrice = 0;

    for (CartItem *item in items) {
        // U6: Validate each item before including in order
        if (item.itemID.length == 0 || item.name.length == 0) {
            NSLog(@"⚠️ [Cart] Skipping invalid item (missing ID or name)");
            continue;
        }
        NSInteger safeQty = MAX(1, MIN(item.quantity, 9999));
        float safePrice = MAX(0.0f, MIN(item.price, 999999.0f));
        totalQty += safeQty;
        totalPrice += safePrice * safeQty;
        [itemData addObject:@{
             @"itemID": item.itemID,
             @"name": item.name,
             @"quantity": @(safeQty),
             @"price": @(safePrice)
        }];
    }

    if (itemData.count == 0) {
        NSLog(@"⚠️ [Cart] No valid items to sync after validation");
        return;
    }

    orderSummary[@"totalQuantity"] = @(totalQty);
    orderSummary[@"totalPrice"] = @(totalPrice);
    orderSummary[@"createdAt"] = [FIRTimestamp timestamp];
    orderSummary[@"items"] = itemData;
    orderSummary[@"status"] = @(0);

    FIRWriteBatch *batch = [db batch];
    [batch setData:orderSummary forDocument:orderRef];

    [batch commitWithCompletion:^(NSError *_Nullable error) {
        if (error) {
            NSLog(@"❌ Batch upload failed: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Order %@ uploaded successfully", orderID);
            [[CartManager sharedManager] clearCart];
            [self.cartTableView reloadData];
            [self updateTotalLabel];
            
            [self.delegate loadItemsCountInBadge];

            if ([self.delegate respondsToSelector:@selector(updateCartAndReloadCollection)]) {
                [self.delegate updateCartAndReloadCollection];
            }
            
        }
    }];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    NSInteger rows = [tableView numberOfRowsInSection:section];

    UIBezierPath *maskPath;
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGRect bounds = cell.bounds;

    if (row == 0 && row == rows - 1) {
        // Single cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:12];
    } else if (row == 0) {
        // First cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                         byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                               cornerRadii:CGSizeMake(20, 20)];
    } else if (row == rows - 1) {
        // Last cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                         byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                               cornerRadii:CGSizeMake(20, 20)];
    } else {
        // Middle cell
        maskPath = [UIBezierPath bezierPathWithRect:bounds];
    }

    maskLayer.path = maskPath.CGPath;
    cell.layer.mask = maskLayer;
}

@end























//
//  PPPaymentSheettHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

@implementation PPPaymentSheettHelper

#pragma mark - Public API

+ (void)showPaymentSheetIn:(UIViewController *)vc
             selectedMethod:(NSString *)methodName
                  onConfirm:(dispatch_block_t)confirm
                   onCancel:(dispatch_block_t)cancel {

    if (@available(iOS 15.0, *)) {
        // 🧊 Modern iOS Action Sheet
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"payment_confirm_title")
                                                                       message:[NSString stringWithFormat:kLang(@"payment_pay_using_format"), methodName ?: @""]
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:kLang(@"payment_confirm_action")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            if (confirm) confirm();
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"payment_cancel_action")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * _Nonnull action) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            if (cancel) cancel();
        }];

        [alert addAction:confirmAction];
        [alert addAction:cancelAction];

        // 🧭 Customize sheet appearance (iOS 15+)
        if (@available(iOS 15.0, *)) {
            alert.sheetPresentationController.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            alert.sheetPresentationController.prefersGrabberVisible = YES;
            alert.sheetPresentationController.preferredCornerRadius = 22;
        }

        // iPad: actionSheet requires sourceView to avoid crash
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = vc.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 0, 0);
        }
        [vc presentViewController:alert animated:YES completion:nil];
    }
    else {
        // 🌫️ Fallback custom blur alert
        [self showLegacyBlurSheetIn:vc methodName:methodName onConfirm:confirm onCancel:cancel];
    }
}

#pragma mark - Legacy Blur Implementation

+ (void)showLegacyBlurSheetIn:(UIViewController *)vc
                   methodName:(NSString *)methodName
                    onConfirm:(dispatch_block_t)confirm
                     onCancel:(dispatch_block_t)cancel {

    UIView *container = [[UIView alloc] initWithFrame:vc.view.bounds];
    container.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    container.alpha = 0;
    [vc.view addSubview:container];

    // Blur background card
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.layer.cornerRadius = 18;
    blurView.layer.masksToBounds = YES;
    blurView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.text = kLang(@"payment_confirm_title");
    title.font = [GM boldFontWithSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *message = [[UILabel alloc] init];
    message.text = [NSString stringWithFormat:kLang(@"payment_pay_using_format"), methodName ?: @""];
    message.textAlignment = NSTextAlignmentCenter;
    message.textColor = UIColor.secondaryLabelColor;
    message.numberOfLines = 0;
    message.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [confirmBtn setTitle:kLang(@"payment_confirm_action") forState:UIControlStateNormal];
    confirmBtn.titleLabel.font = [GM boldFontWithSize:17];
    confirmBtn.translatesAutoresizingMaskIntoConstraints = NO;
    confirmBtn.backgroundColor = AppPrimaryClr;
    confirmBtn.tintColor = UIColor.whiteColor;
    confirmBtn.layer.cornerRadius = 10;
    [confirmBtn addTarget:self action:@selector(_confirmTap:) forControlEvents:UIControlEventTouchUpInside];
    confirmBtn.tag = 1; // tag to identify action

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelBtn setTitle:kLang(@"payment_cancel_action") forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [GM MidFontWithSize:16];
    cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    cancelBtn.backgroundColor = [UIColor.systemGray5Color colorWithAlphaComponent:0.6];
    cancelBtn.tintColor = UIColor.labelColor;
    cancelBtn.layer.cornerRadius = 10;
    [cancelBtn addTarget:self action:@selector(_confirmTap:) forControlEvents:UIControlEventTouchUpInside];
    cancelBtn.tag = 2;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:container];
    [container addSubview:blurView];
    [blurView.contentView addSubview:title];
    [blurView.contentView addSubview:message];
    [blurView.contentView addSubview:confirmBtn];
    [blurView.contentView addSubview:cancelBtn];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [blurView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [blurView.widthAnchor constraintEqualToAnchor:container.widthAnchor multiplier:0.85],
        [title.topAnchor constraintEqualToAnchor:blurView.topAnchor constant:24],
        [title.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor constant:16],
        [title.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor constant:-16],
        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [message.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [message.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [confirmBtn.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:20],
        [confirmBtn.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor constant:20],
        [confirmBtn.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor constant:-20],
        [confirmBtn.heightAnchor constraintEqualToConstant:44],
        [cancelBtn.topAnchor constraintEqualToAnchor:confirmBtn.bottomAnchor constant:12],
        [cancelBtn.leadingAnchor constraintEqualToAnchor:confirmBtn.leadingAnchor],
        [cancelBtn.trailingAnchor constraintEqualToAnchor:confirmBtn.trailingAnchor],
        [cancelBtn.heightAnchor constraintEqualToConstant:42],
        [cancelBtn.bottomAnchor constraintEqualToAnchor:blurView.bottomAnchor constant:-24]
    ]];

    // Fade-in animation
    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 1.0;
    }];

    // Store actions in associated objects
    objc_setAssociatedObject(confirmBtn, @"confirmBlock", confirm, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(cancelBtn, @"cancelBlock", cancel, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(container, @"containerView", container, OBJC_ASSOCIATION_ASSIGN);
}

#pragma mark - Button Actions

+ (void)_confirmTap:(UIButton *)sender {
    dispatch_block_t confirmBlock = objc_getAssociatedObject(sender, @"confirmBlock");
    dispatch_block_t cancelBlock = objc_getAssociatedObject(sender, @"cancelBlock");
    UIView *container = objc_getAssociatedObject(sender, @"containerView");

    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 0.0;
    } completion:^(BOOL finished) {
        [container removeFromSuperview];
        if (sender.tag == 1 && confirmBlock) confirmBlock();
        else if (sender.tag == 2 && cancelBlock) cancelBlock();
    }];
}

@end



























//
//  PPBottomAlertSheet.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

 #import "Styling.h"
#import "Language.h"

@interface PPBottomAlertSheet ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@end

@implementation PPBottomAlertSheet

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
   
    
    self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor systemBackgroundColor]);
    self.view.layer.cornerRadius = 24;
    self.view.layer.masksToBounds = YES;

    // 📄 Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = self.sheetTitle ?: kLang(@"payment_confirm_title");
    _titleLabel.font = [UIFont boldSystemFontOfSize:20];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 📜 Message
    _messageLabel = [[UILabel alloc] init];
    _messageLabel.text = self.message ?: @"";
    _messageLabel.font = [UIFont systemFontOfSize:16];
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.textColor = UIColor.secondaryLabelColor;
    _messageLabel.numberOfLines = 0;
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // ✅ Confirm button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration tintedButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseBackgroundColor = AppPrimaryClr;
        cfg.baseForegroundColor = UIColor.whiteColor;
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"payment_confirm_action")
                                                              attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:17]}];
        _confirmButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        _confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_confirmButton setTitle:kLang(@"payment_confirm_action") forState:UIControlStateNormal];
        _confirmButton.backgroundColor = AppPrimaryClr;
        _confirmButton.tintColor = UIColor.whiteColor;
        _confirmButton.layer.cornerRadius = 12;
    }
    _confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_confirmButton addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];

    // ❌ Cancel button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration grayButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = UIColor.labelColor;
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"payment_cancel_action")
                                                              attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]}];
        _cancelButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelButton setTitle:kLang(@"payment_cancel_action") forState:UIControlStateNormal];
        _cancelButton.backgroundColor = [UIColor systemGray5Color];
        _cancelButton.layer.cornerRadius = 12;
    }
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:_titleLabel];
    [self.view addSubview:_messageLabel];
    [self.view addSubview:_confirmButton];
    [self.view addSubview:_cancelButton];

    // 📐 Constraints
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:28],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [_messageLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_messageLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [_messageLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [_confirmButton.topAnchor constraintEqualToAnchor:_messageLabel.bottomAnchor constant:24],
        [_confirmButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [_confirmButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],
        [_confirmButton.heightAnchor constraintEqualToConstant:48],

        [_cancelButton.topAnchor constraintEqualToAnchor:_confirmButton.bottomAnchor constant:12],
        [_cancelButton.leadingAnchor constraintEqualToAnchor:_confirmButton.leadingAnchor],
        [_cancelButton.trailingAnchor constraintEqualToAnchor:_confirmButton.trailingAnchor],
        [_cancelButton.heightAnchor constraintEqualToConstant:46],
        [_cancelButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

#pragma mark - Presentation

- (void)presentIn:(UIViewController *)parentVC {
    if (@available(iOS 15.0, *)) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = self.sheetPresentationController;
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 24;
        [parentVC presentViewController:self animated:YES completion:nil];
    } else {
        // Legacy fallback — fade from bottom
        self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [parentVC presentViewController:self animated:YES completion:nil];
    }
}

#pragma mark - Actions

- (void)confirmTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onConfirm) self.onConfirm();
    }];
}

- (void)cancelTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onCancel) self.onCancel();
    }];
}


// Remove notification observer on dealloc
- (void)dealloc {
   // [[NSNotificationCenter defaultCenter] removeObserverBlocks]; kCartUpdatedNotification
}


@end
