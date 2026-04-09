//
//  PPBottomBarView.m
//  PurePets
//

#import "PPRootTabBarController.h"
#import "PPHomeViewController.h"
#import "PPSearchViewController.h"
#import "MyItemsViewController.h"
#import "SettingVC.h"
#import "PPCommerceFeedbackManager.h"
#import "UserModel.h"
#import "PPRolePermission.h"
#import "UserManager.h"
#import "AppClasses.h"
#if __has_include(<Lottie/Lottie.h>)
#import <Lottie/Lottie.h>
#elif __has_include("Lottie.h")
#import "Lottie.h"
#elif __has_include(<lottie-ios_Oc/Lottie.h>)
#import <lottie-ios_Oc/Lottie.h>
#elif __has_include(<lottie_ios_Oc/Lottie.h>)
#import <lottie_ios_Oc/Lottie.h>
#else
@class LOTAnimationView;
#endif

#import "SettingVC.h"
#import "PPNotificationsHubViewController.h"

// ...




static NSString * const kPPBlockedOverlaySupportPhoneNumber = @"+97459997720";
static NSInteger const PPRootTabIndexHome = 0;
static NSInteger const PPRootTabIndexChats = 1;
static NSInteger const PPRootTabIndexAdd = 2;
static NSInteger const PPRootTabIndexOrders = 3;
static NSInteger const PPRootTabIndexSettings = 4;

@interface PPRootTabBarController ()
@property (nonatomic, strong) UIButton *leadingTabButton;
@property (nonatomic, strong) UIButton *emptyCard;
 @property (nonatomic, strong) PPNewBottomBar *bottomBar;
@property (nonatomic, strong) CAGradientLayer *bottomFadeLayer;
@property (nonatomic, strong) CALayer *tabBarTopSeparatorLayer;
@property (nonatomic, strong, nullable) UIControl *blockedOverlayView;
@property (nonatomic, strong, nullable) UIView *blockedOverlayCardView;
@property (nonatomic, strong, nullable) LOTAnimationView *blockedHeaderAnimationView;
@property (nonatomic, strong, nullable) UIButton *blockedContactButton;
@property (nonatomic, strong, nullable) NSLayoutConstraint *blockedOverlayTopConstraint;
@property (nonatomic, assign) NSInteger pp_lastSelectedIndex;
@property (nonatomic, strong, nullable) UIViewController *addActionPlaceholderViewController;
- (UIViewController *)pp_makeAddActionPlaceholderViewController;
- (UIViewController *)pp_makeSettingsRootViewController;
- (nullable UINavigationController *)pp_preferredNavigationControllerForSearchExperience;
- (nullable PPSearchViewController *)pp_existingSearchControllerInNavigationController:(UINavigationController *)navigationController;
- (void)pp_openSearchExperienceFromCurrentContextOpeningAccessories:(BOOL)openAccessories;
- (void)pp_updateTabBarSelectionIndicatorIfNeeded;
- (void)pp_updateTabBarTopSeparatorIfNeeded;
- (UIImage *)pp_tabBarSelectionIndicatorImageForItemSize:(CGSize)itemSize
                                           indicatorSize:(CGSize)indicatorSize
                                               fillColor:(UIColor *)fillColor
                                             strokeColor:(UIColor *)strokeColor;
@end

@implementation PPRootTabBarController
 

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.delegate = self;
    // Home
    UINavigationController *homeNav =
    [self nav:[PPHomeViewController new]
         title:kLang(@"MainPage")
         icon:@"house" selectedImage:@"house.fill"];

    // Notifications
    //UINavigationController *notiNav = [self nav:[UserChatsViewController new] title:kLang(@"Notifications") icon:@"bell" selectedImage:@"bellLast"];

    // Add (center)
    UINavigationController *addNav = [self nav:[self pp_makeAddActionPlaceholderViewController] title:nil  icon:@"" selectedImage:@""];
    // Settings
    UINavigationController *settingsNav = [self nav:[self pp_makeSettingsRootViewController]   title:(kLang(@"menu_action_settings") ?: (kLang(@"Setting") ?: @"Settings"))  icon:@"gearshape" selectedImage:@"gearshape.fill"];

    // Cart
    
    UINavigationController *cartNav = [self nav:[OrderHistoryViewController new] title:kLang(@"menu_action_orders") icon:@"cart.badge.clock" selectedImage:@"checklist"];
   
    
    UINavigationController *notiNav = [self nav:[PPNotificationsHubViewController new]  title:kLang(@"Notifications")   icon:@"bell" selectedImage:@"bellLast"];

    notiNav.tabBarItem.accessibilityHint =
        NSLocalizedString(@"a11y_tab_notifications_hint", @"View pet reminders and chats");
    /*
     
     
     UINavigationController *cartNav =
     [self nav:[[MyItemsViewController alloc]initWithMode:MyItemsModeFavorites]
          title:kLang(@"showfav")
          icon:@"suit.heart" selectedImage:@"pawlove"];
     
     
     
     UINavigationController *cartNav =
     [self nav:[MyItemsViewController new]
          title:kLang(@"showfav")
          icon:@"suit.heart" selectedImage:@"pawlove"];
     
     */
   /*
    UINavigationController *searchNav =
    [self nav:[OrderHistoryViewController new]
         title:kLang(@"Search")
          icon:@"magnifyingglass.circle.fill"];
    
    UINavigationController *cartNav =
    [self nav:[CartViewController new]
         title:kLang(@"Cart")
         icon:@"cart" selectedImage:@"cartLast"];
    
    
    */

    self.viewControllers = @[
        homeNav,
        notiNav,
        addNav,
        cartNav,
        settingsNav
    ];

    // ── Accessibility: Tab bar items ──
    homeNav.tabBarItem.accessibilityLabel     = NSLocalizedString(@"a11y_tab_home", @"Home tab");
    homeNav.tabBarItem.accessibilityHint      = NSLocalizedString(@"a11y_tab_home_hint", @"Browse pet ads and services");
    notiNav.tabBarItem.accessibilityLabel     = NSLocalizedString(@"a11y_tab_notifications", @"Notifications tab");
    notiNav.tabBarItem.accessibilityHint      = NSLocalizedString(@"a11y_tab_notifications_hint", @"View your chats and notifications");
    addNav.tabBarItem.accessibilityLabel      = NSLocalizedString(@"a11y_tab_add", @"Add new post tab");
    cartNav.tabBarItem.accessibilityLabel     = NSLocalizedString(@"a11y_tab_orders", @"Orders tab");
    cartNav.tabBarItem.accessibilityHint      = NSLocalizedString(@"a11y_tab_orders_hint", @"View your order history");
    settingsNav.tabBarItem.accessibilityLabel = NSLocalizedString(@"a11y_tab_settings", @"Settings tab");
    settingsNav.tabBarItem.accessibilityHint  = NSLocalizedString(@"a11y_tab_settings_hint", @"App settings and account");

    self.pp_lastSelectedIndex = self.selectedIndex;
    //[self addBottomFadeBelowTabBar];
    [self configureAppearance];

    [self addPlusTabBarButton];
    
    [self updateUnreads];
    
    


    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showSystemTabBar)
                                                 name:PPShowSystemTabBarNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(updateUnreads)
               name:@"UnreadCountsUpdated"
             object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hideSystemTabBar)
                                                 name:PPHideSystemTabBarNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleRouteToSearchAccessories)
     name:PPRouteToSearchAccessoriesNotificationKey
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleBlockedStateNotification:)
               name:PPUserManagerDidUpdateBlockedStateNotification
             object:UserManager.sharedManager];
    //[self configureTabBarIndicatorColor];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UserManager.sharedManager startListeningCurrentUserBlockedState];
    [self pp_applyBlockedState:UserManager.sharedManager.isCurrentUserBlocked animated:NO];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}




- (void)searchButtonTapped {
    [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:NO];
}



- (void)pp_handleRouteToSearchAccessories
{
    [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:YES];
}

- (nullable UINavigationController *)pp_preferredNavigationControllerForSearchExperience
{
    UIViewController *selectedVC = self.selectedViewController;
    BOOL shouldFallbackToHome =
        (self.selectedIndex == PPRootTabIndexAdd ||
         ![selectedVC isKindOfClass:UINavigationController.class]);

    if (shouldFallbackToHome) {
        if (self.viewControllers.count <= PPRootTabIndexHome) {
            return nil;
        }
        self.selectedIndex = PPRootTabIndexHome;
        selectedVC = self.viewControllers[PPRootTabIndexHome];
    }

    return [selectedVC isKindOfClass:UINavigationController.class]
        ? (UINavigationController *)selectedVC
        : nil;
}

- (nullable PPSearchViewController *)pp_existingSearchControllerInNavigationController:(UINavigationController *)navigationController
{
    for (UIViewController *viewController in navigationController.viewControllers.reverseObjectEnumerator) {
        if ([viewController isKindOfClass:PPSearchViewController.class]) {
            return (PPSearchViewController *)viewController;
        }
    }
    return nil;
}

- (void)pp_openSearchExperienceFromCurrentContextOpeningAccessories:(BOOL)openAccessories
{
    UINavigationController *navigationController =
        [self pp_preferredNavigationControllerForSearchExperience];
    if (!navigationController) {
        return;
    }

    PPSearchViewController *searchController =
        [self pp_existingSearchControllerInNavigationController:navigationController];

    if (searchController) {
        if (navigationController.topViewController != searchController) {
            [navigationController popToViewController:searchController animated:YES];
        }
    } else {
        searchController = [PPSearchViewController new];
        [navigationController pushViewController:searchController animated:YES];
    }

    if (openAccessories) {
        [searchController openAccessoriesAll];
        return;
    }
    [searchController focusSearchField];
}


- (void)openAccessoriesAll
{
    [UIView animateWithDuration:0.25 animations:^{
        self.tabBar.alpha = 1.0;
        //self.tabBar.transform = CGAffineTransformIdentity;
    }];
}
- (void)showSystemTabBar
{
    [UIView animateWithDuration:0.25 animations:^{
        self.tabBar.alpha = 1.0;
        //self.tabBar.transform = CGAffineTransformIdentity;
    }];
}

- (void)hideSystemTabBar
{
    [UIView animateWithDuration:0.25 animations:^{
        self.tabBar.alpha = 0.0;
       // self.tabBar.transform =
       // CGAffineTransformMakeTranslation(0, self.tabBar.bounds.size.height);
    }];
}


- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self pp_updateBlockedOverlayTopInset];
    [self pp_updateTabBarSelectionIndicatorIfNeeded];
    [self pp_updateTabBarTopSeparatorIfNeeded];
}

#pragma mark - Blocked Overlay

- (void)pp_handleBlockedStateNotification:(NSNotification *)notification {
    NSNumber *blockedValue = notification.userInfo[PPUserManagerBlockedStateUserInfoKey];
    BOOL isBlocked = [blockedValue respondsToSelector:@selector(boolValue)]
        ? blockedValue.boolValue
        : UserManager.sharedManager.isCurrentUserBlocked;
    [self pp_applyBlockedState:isBlocked animated:YES];
}

- (void)pp_setupBlockedOverlayIfNeeded {
    if (self.blockedOverlayView) {
        return;
    }

    UIControl *overlay = [[UIControl alloc] init];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.52];
    overlay.hidden = YES;
    overlay.alpha = 0.0;
    [self.view addSubview:overlay];

    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.96];
    card.layer.cornerRadius = 22.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.08].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.10;
    card.layer.shadowRadius = 18.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [overlay addSubview:card];

    self.blockedOverlayTopConstraint = [card.topAnchor constraintEqualToAnchor:overlay.topAnchor constant:120.0];
    [NSLayoutConstraint activateConstraints:@[
        self.blockedOverlayTopConstraint,
        [card.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:16.0],
        [card.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-16.0],
        [card.bottomAnchor constraintLessThanOrEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-16.0]
    ]];

    LOTAnimationView *headerAnimationView = [[LOTAnimationView alloc] init];
    headerAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    headerAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    headerAnimationView.loopAnimation = YES;
    headerAnimationView.animationSpeed = 1.0;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"auth_account_blocked_title");
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.font = [GM boldFontWithSize:24];
    titleLabel.numberOfLines = 0;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"auth_account_blocked_message");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.numberOfLines = 0;

    UIButton *signOutButton =
    [self pp_makeBlockedOverlayButtonWithTitle:kLang(@"logout")
                                        filled:YES
                                        action:@selector(pp_blockedSignOutTapped)];

    UIButton *contactSupportButton =
    [self pp_makeBlockedOverlayButtonWithTitle:kLang(@"order_support_button")
                                        filled:NO
                                        action:@selector(pp_blockedContactSupportTapped)];

    UIStackView *labelsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        titleLabel,
        subtitleLabel
    ]];
    labelsStack.translatesAutoresizingMaskIntoConstraints = NO;
    labelsStack.axis = UILayoutConstraintAxisVertical;
    labelsStack.alignment = UIStackViewAlignmentFill;
    labelsStack.spacing = 6.0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        headerAnimationView,
        labelsStack,
        signOutButton,
        contactSupportButton
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 14.0;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [headerAnimationView.heightAnchor constraintEqualToConstant:170.0],
        [signOutButton.heightAnchor constraintEqualToConstant:48.0],
        [contactSupportButton.heightAnchor constraintEqualToConstant:48.0],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0]
    ]];

    __weak LOTAnimationView *weakAnimationView = headerAnimationView;
    [AppClasses setAnimationNamed:@"contactUs"
                           ToView:headerAnimationView
                        withSpeed:1.0
                       completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LOTAnimationView *strongAnimationView = weakAnimationView;
            if (!strongAnimationView || !success) {
                return;
            }
            [strongAnimationView play];
        });
    }];

    self.blockedOverlayView = overlay;
    self.blockedOverlayCardView = card;
    self.blockedHeaderAnimationView = headerAnimationView;
    self.blockedContactButton = contactSupportButton;
}

- (UIButton *)pp_makeBlockedOverlayButtonWithTitle:(NSString *)title
                                             filled:(BOOL)filled
                                             action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [GM boldFontWithSize:16];
    button.layer.cornerRadius = 12.0;
    button.layer.masksToBounds = YES;

    if (filled) {
        button.backgroundColor = UIColor.systemRedColor;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    } else {
        button.backgroundColor = UIColor.clearColor;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = (AppPrimaryClr ?: UIColor.systemBlueColor).CGColor;
        [button setTitleColor:AppPrimaryClr ?: UIColor.systemBlueColor forState:UIControlStateNormal];
    }

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)pp_applyBlockedState:(BOOL)isBlocked animated:(BOOL)animated {
    BOOL shouldShow = isBlocked && UserManager.sharedManager.isUserLoggedIn;
    if (!shouldShow && !self.blockedOverlayView) {
        return;
    }

    [self pp_setupBlockedOverlayIfNeeded];
    [self pp_updateBlockedOverlayTopInset];

    if (shouldShow) {
        self.blockedOverlayView.hidden = NO;
        [self.view bringSubviewToFront:self.blockedOverlayView];
        [self.blockedHeaderAnimationView play];
    }

    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;
    void (^completion)(BOOL) = ^(BOOL finished) {
        (void)finished;
        if (!shouldShow) {
            self.blockedOverlayView.hidden = YES;
            [self.blockedHeaderAnimationView stop];
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                         animations:^{
            self.blockedOverlayView.alpha = targetAlpha;
        } completion:completion];
    } else {
        self.blockedOverlayView.alpha = targetAlpha;
        completion(YES);
    }
}

- (void)pp_updateBlockedOverlayTopInset {
    if (!self.blockedOverlayTopConstraint || !self.blockedOverlayView) {
        return;
    }

    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat navBottom = 0.0;

    UINavigationController *activeNav = [self pp_activeNavigationController];
    if (activeNav && !activeNav.navigationBarHidden) {
        CGRect navFrameInRoot = [activeNav.view convertRect:activeNav.navigationBar.frame toView:self.view];
        navBottom = CGRectGetMaxY(navFrameInRoot);
    }

    self.blockedOverlayTopConstraint.constant = MAX(safeTop, navBottom) + 10.0;
}

- (UINavigationController *)pp_activeNavigationController {
    UIViewController *selected = self.selectedViewController;
    if ([selected isKindOfClass:UINavigationController.class]) {
        return (UINavigationController *)selected;
    }
    if (selected.navigationController) {
        return selected.navigationController;
    }
    return nil;
}

- (void)pp_blockedSignOutTapped {
    __weak typeof(self) weakSelf = self;
    [UserManager.sharedManager signOutCurrentUserWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (error) {
                [PPAlertHelper showErrorIn:strongSelf
                                     title:kLang(@"logout")
                                  subtitle:error.localizedDescription ?: @"Sign out failed."];
                return;
            }
            [strongSelf pp_applyBlockedState:NO animated:YES];
        });
    }];
}

- (void)pp_blockedContactSupportTapped {
    UIAlertController *menu = [UIAlertController
                               alertControllerWithTitle:kLang(@"cart_support_menu_title")
                               message:nil
                               preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:kLang(@"order_support_request_call")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses callPhoneNumber:kPPBlockedOverlaySupportPhoneNumber fromViewController:self];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:kLang(@"cart_support_chat")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses startWhatsAppWith:kPPBlockedOverlaySupportPhoneNumber fromViewController:self];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.blockedContactButton ?: self.view;
        popover.sourceRect = self.blockedContactButton ? self.blockedContactButton.bounds :
            CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:menu animated:YES completion:nil];
}


- (void)handleBarSelection:(PPBarTag)tag {

    switch (tag) {

        case PPBarTagHome:
            self.selectedIndex = PPRootTabIndexHome;
            break;

        case PPBarTagChats:
            self.selectedIndex = PPRootTabIndexChats;
            break;

        case PPBarTagOrdersHistory:
            self.selectedIndex = PPRootTabIndexOrders;
            break;

        case PPBarTagNotifications:
            self.selectedIndex = PPRootTabIndexSettings;
            break;

        case PPBarTagSearch:
        {
            [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:NO];
            break;
        }
        case PPBarTagNewAd:
            [self presentBottomSheet];
            break;

        case PPBarTagCart:
           // [self openCart];
            break;
    }
}


// Show correct unread counts on tab index 1 (Chats / Notifications)
- (void)updateUnreads
{
    NSLog(@"[Chats] updateUnreads (live)");

    // 🔥 Pull from in-memory unread store (no Firestore hit)
    NSDictionary<NSString *, NSNumber *> *counts =
        [ChManager sharedManager].liveUnreadCounts;

    NSInteger totalUnreadCount = 0;
    for (NSNumber *value in counts.allValues) {
        totalUnreadCount += value.integerValue;
    }

    if (self.viewControllers.count <= 1) return;

    UINavigationController *notiNav =
        (UINavigationController *)self.viewControllers[1];

    UITabBarItem *item = notiNav.tabBarItem;
    if (!item) return;

    if (totalUnreadCount > 0) {
        item.badgeValue =
            totalUnreadCount > 99 ? @"99+" :
            [NSString stringWithFormat:@"%ld", (long)totalUnreadCount];
    } else {
        item.badgeValue = nil;
    }

    if (@available(iOS 15.0, *)) {
        item.badgeColor = AppPrimaryClr;
    }

    NSLog(@"🔔 [TabUnread] total = %ld", (long)totalUnreadCount);
}


#pragma mark - Helpers

- (UIViewController *)pp_makeAddActionPlaceholderViewController
{
    if (self.addActionPlaceholderViewController) {
        return self.addActionPlaceholderViewController;
    }

    UIViewController *placeholder = [UIViewController new];
    placeholder.tabBarItem.accessibilityIdentifier = @"pp.root.add.placeholder";
    self.addActionPlaceholderViewController = placeholder;
    return placeholder;
}

- (UIViewController *)pp_makeSettingsRootViewController
{
     SettingVC *settingsViewController =
    [SettingVC new];
    if ([settingsViewController isKindOfClass:SettingVC.class]) {
        return settingsViewController;
    }
    return [SettingVC new];
}

- (UINavigationController *)nav:(UIViewController *)vc
                          title:(NSString *)title
                           icon:(NSString *)icon
                  selectedImage:(NSString *)selectedImage{

    PPNavigationController *nav =
    [[PPNavigationController alloc] initWithRootViewController:vc];

    nav.navigationBarHidden = NO;
    UIImage *iconm = [UIImage pp_symbolNamed:icon pointSize:16 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleLarge palette:@[AppPrimaryTextClr ] makeTemplate:YES];
    UITabBarItem *item =
    [[UITabBarItem alloc] initWithTitle:title
                                  image:iconm
                          selectedImage:[UIImage pp_symbolNamed:selectedImage]];// [UIImage systemImageNamed:[NSString stringWithFormat:@"%@.fill",icon]]];

    nav.tabBarItem = item;
    return nav;
}

// Floating background (emulates iOS 26 look)
- (void)pp_configureFloatingBackgroundForAppearance:(UITabBarAppearance *)appearance {
    if (@available(iOS 26.0, *)) {
        [appearance configureWithTransparentBackground];
        appearance.backgroundEffect =
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        appearance.backgroundColor =
            [AppForgroundColr colorWithAlphaComponent:0.28];
    } else if (@available(iOS 13.0, *)) {
        [appearance configureWithDefaultBackground];
        appearance.backgroundEffect =
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        appearance.backgroundColor =
            [AppForgroundColr colorWithAlphaComponent:0.82];
    } else {
        appearance.backgroundImage = [UIImage new];
        appearance.shadowImage = [UIImage new];
    }
}

- (void)configureAppearance {
    // WHY: Make selected title invisible while keeping normal visible.
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        [self pp_configureFloatingBackgroundForAppearance:appearance];
        
        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
        @{ NSForegroundColorAttributeName: [AppPrimaryTextClr colorWithAlphaComponent:1.0] ,
           NSFontAttributeName: [GM boldFontWithSize:PPFontCaption1]};
        
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        
        NSDictionary<NSAttributedStringKey, id> *normalTitle =
        @{ NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.72],
           NSFontAttributeName: [GM MidFontWithSize:PPFontCaption2]};
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.stackedLayoutAppearance.selected.iconColor = AppPrimaryClr ?: UIColor.systemTealColor;
        appearance.inlineLayoutAppearance.selected.iconColor = AppPrimaryClr ?: UIColor.systemTealColor;
        appearance.compactInlineLayoutAppearance.selected.iconColor = AppPrimaryClr ?: UIColor.systemTealColor;
        appearance.stackedLayoutAppearance.normal.iconColor = [UIColor.labelColor colorWithAlphaComponent:0.72];
        appearance.inlineLayoutAppearance.normal.iconColor = [UIColor.labelColor colorWithAlphaComponent:0.72];
        appearance.compactInlineLayoutAppearance.normal.iconColor = [UIColor.labelColor colorWithAlphaComponent:0.72];
        
        if (@available(iOS 26.0, *)) {
            appearance.shadowColor = UIColor.clearColor;
        } else {
            appearance.shadowColor = UIColor.clearColor;
        }
        
        // 🫁 Add breathing space between icon and title
        UIOffset titleOffset = UIOffsetMake(0, 3);

        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = titleOffset;

        appearance.inlineLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.inlineLayoutAppearance.selected.titlePositionAdjustment = titleOffset;

        appearance.compactInlineLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.compactInlineLayoutAppearance.selected.titlePositionAdjustment = titleOffset;
        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
        self.tabBar.layer.shadowColor = UIColor.blackColor.CGColor;
        self.tabBar.layer.shadowOpacity = 0.08;
        self.tabBar.layer.shadowRadius = 18.0;
        self.tabBar.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        self.tabBar.layer.masksToBounds = NO;
        
    } else {
        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
        @{ NSForegroundColorAttributeName: UIColor.clearColor };
        [[UITabBarItem appearance] setTitleTextAttributes:clearSelectedTitle forState:UIControlStateSelected];
    }

    // iOS <26: Set proper icon tinting on the tab bar
    if (!PPIOS26()) {
        self.tabBar.tintColor = AppPrimaryClr;
        self.tabBar.unselectedItemTintColor = UIColor.secondaryLabelColor;
    }
}

- (void)pp_updateTabBarTopSeparatorIfNeeded
{
    if (!self.tabBar) {
        return;
    }

    if (!self.tabBarTopSeparatorLayer) {
        self.tabBarTopSeparatorLayer = [CALayer layer];
        [self.tabBar.layer addSublayer:self.tabBarTopSeparatorLayer];
    }

    CGFloat scale = UIScreen.mainScreen.scale ?: 1.0;
    CGFloat lineHeight = 1.0 / MAX(scale, 1.0);
    CGFloat horizontalInset = 24.0;
    CGFloat availableWidth = MAX(0.0, CGRectGetWidth(self.tabBar.bounds) - (horizontalInset * 2.0));
    self.tabBarTopSeparatorLayer.frame = CGRectMake(horizontalInset, 0.0, availableWidth, lineHeight);
    self.tabBarTopSeparatorLayer.backgroundColor =
        [[UIColor labelColor] colorWithAlphaComponent:0.10].CGColor;
    self.tabBarTopSeparatorLayer.hidden =
        self.tabBar.hidden || self.tabBar.alpha < 0.01 || availableWidth <= 0.0;
}

- (void)pp_updateTabBarSelectionIndicatorIfNeeded
{
    if (!self.tabBar || self.tabBar.items.count == 0) {
        return;
    }

    CGSize tabBarSize = self.tabBar.bounds.size;
    if (tabBarSize.width <= 0.0 || tabBarSize.height <= 0.0) {
        return;
    }

    CGFloat itemWidth = floor(tabBarSize.width / (CGFloat)self.tabBar.items.count);
    if (itemWidth <= 0.0) {
        return;
    }

    CGSize itemSize = CGSizeMake(itemWidth, tabBarSize.height);
    CGSize indicatorSize = CGSizeMake(MIN(60.0, MAX(44.0, itemWidth - 18.0)), 34.0);
    UIColor *fillColor = [(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:(PPIOS26() ? 0.12 : 0.10)];
    UIColor *strokeColor = [(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.14];
    self.tabBar.selectionIndicatorImage =
        [self pp_tabBarSelectionIndicatorImageForItemSize:itemSize
                                            indicatorSize:indicatorSize
                                                fillColor:fillColor
                                              strokeColor:strokeColor];
}

- (UIImage *)pp_tabBarSelectionIndicatorImageForItemSize:(CGSize)itemSize
                                           indicatorSize:(CGSize)indicatorSize
                                               fillColor:(UIColor *)fillColor
                                             strokeColor:(UIColor *)strokeColor
{
    if (itemSize.width <= 0.0 || itemSize.height <= 0.0) {
        return nil;
    }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:itemSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        CGRect indicatorRect = CGRectMake((itemSize.width - indicatorSize.width) * 0.5,
                                          6.0,
                                          indicatorSize.width,
                                          indicatorSize.height);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:indicatorRect cornerRadius:17.0];
        [fillColor setFill];
        [path fill];
        [strokeColor setStroke];
        path.lineWidth = 0.75;
        [path stroke];
    }];
}

- (void)addPlusTabBarButton {


    UIButton *showAddMenuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    showAddMenuButton.translatesAutoresizingMaskIntoConstraints = NO;
    showAddMenuButton.adjustsImageWhenHighlighted = NO;

    UIImageSymbolConfiguration *symbolConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:17
                                                     weight:UIImageSymbolWeightSemibold
                                                      scale:UIImageSymbolScaleLarge];

    UIImage *icon =
    [[UIImage systemImageNamed:@"plus"
              withConfiguration:symbolConfig]
     imageWithTintColor:AppPrimaryClr
     renderingMode:UIImageRenderingModeAlwaysOriginal];
 
    // Keep launch-safe classic layout on iOS < 26.
    if (@available(iOS 26.0, *)) {
        
        UIButtonConfiguration *cfg;
        cfg = [UIButtonConfiguration glassButtonConfiguration];
        
        cfg.imagePlacement = NSDirectionalRectEdgeTop;

        // 🔒 FIXED spacing (Apple HIG default)
        cfg.imagePadding = 2;
        cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;

        // 🔒 Normalize internal layout
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(16, 8, 14, 8);
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.22];

        cfg.attributedTitle =
        [[NSAttributedString alloc] initWithString:kLang(@"new") attributes:@{ NSFontAttributeName : [GM boldFontWithSize:13],  NSForegroundColorAttributeName : AppPrimaryTextClr }];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        cfg.background.cornerRadius = 14;
        cfg.image = icon;
        
        cfg.baseForegroundColor = AppForgroundColr;

        showAddMenuButton.configuration = cfg;
        
        
        CAGradientLayer *g = [CAGradientLayer layer];
        g.colors = @[
            (__bridge id)[AppForgroundColr colorWithAlphaComponent:1.2].CGColor,
            (__bridge id)[AppForgroundColr colorWithAlphaComponent:1.0].CGColor
        ];
        g.frame = CGRectMake(0, 0, 56, 56);
        g.cornerRadius = 16;
        
        //[showAddMenuButton.layer insertSublayer:g atIndex:0];
    }
    else {
        icon =
        [[UIImage systemImageNamed:@"plus"
                  withConfiguration:symbolConfig]
         imageWithTintColor:AppForgroundColr
         renderingMode:UIImageRenderingModeAlwaysTemplate];
        
        // Legacy APIs for iOS < 18
        [showAddMenuButton setImage:icon forState:UIControlStateNormal];
         showAddMenuButton.titleLabel.font = [GM MidFontWithSize:11];
        showAddMenuButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        showAddMenuButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        showAddMenuButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        // Place image on top, title below, with spacing
        CGFloat spacing = 5.0;
        CGSize imageSize = showAddMenuButton.imageView.image.size;
        CGSize titleSize = [showAddMenuButton.titleLabel.text sizeWithAttributes:@{NSFontAttributeName: showAddMenuButton.titleLabel.font}];
        //showAddMenuButton.titleEdgeInsets = UIEdgeInsetsMake(imageSize.height + spacing, -imageSize.width, 0, 0);
        //showAddMenuButton.imageEdgeInsets = UIEdgeInsetsMake(-titleSize.height - spacing, 0, 0, -titleSize.width);
        showAddMenuButton.layer.cornerRadius = 28;
        showAddMenuButton.clipsToBounds = YES;
    }

    

    showAddMenuButton.tintColor = AppForgroundColr;
    showAddMenuButton.imageView.tintColor = AppForgroundColr;

    // Shadow + clipping — version-specific handling
    if (@available(iOS 26.0, *)) {
        // iOS 26+: Glass button — external shadow for depth, no clipping
        showAddMenuButton.layer.shadowColor = UIColor.blackColor.CGColor;
        showAddMenuButton.layer.shadowOpacity = 0.08;
        showAddMenuButton.layer.shadowRadius = 10;
        showAddMenuButton.layer.shadowOffset = CGSizeMake(0, 4);
        showAddMenuButton.layer.masksToBounds = NO;
        showAddMenuButton.clipsToBounds = NO;
    }
    // iOS <26: cornerRadius + clipsToBounds already set above — keep them intact

    [showAddMenuButton addTarget:self action:@selector(presentBottomSheet) forControlEvents:UIControlEventTouchUpInside];

    // ── Accessibility: Add new post button ──
    showAddMenuButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_add_new", @"Add new post");
    showAddMenuButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_add_new_hint", @"Create a new pet ad, accessory listing, or adoption post");
    showAddMenuButton.accessibilityTraits = UIAccessibilityTraitButton;

    [self.tabBar addSubview:showAddMenuButton];
    self.leadingTabButton = showAddMenuButton;

    [NSLayoutConstraint activateConstraints:@[
        [showAddMenuButton.centerXAnchor constraintEqualToAnchor:self.tabBar.centerXAnchor],
        [showAddMenuButton.centerYAnchor constraintEqualToAnchor:self.tabBar.centerYAnchor constant:-10],
        [showAddMenuButton.widthAnchor constraintEqualToConstant:56],
        [showAddMenuButton.heightAnchor constraintEqualToConstant:56]
    ]];
    
    // 🔒 Force DARK mode for glass button only
    if (@available(iOS 13.0, *)) {
        showAddMenuButton.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
}

- (void)leadingTabTapped {
    // Example: open profile
   
}



- (void)presentBottomSheet {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [feedback impactOccurred];
    }
    
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return;
    }
    
    
    // Build options
    NSMutableArray<OptionModel *> *options = [NSMutableArray new];

    OptionModel *newAd   = [OptionModel optionWithID:@"newAd"
                                               title:kLang(@"newAd")
                                           imageName:@"new_ad"
                                         systemImage:nil
                                               desc:kLang(@"newAd_desc")];

    OptionModel *addUsed = [OptionModel optionWithID:@"addUsedButton"
                                               title:kLang(@"addUsedButton")
                                           imageName:@"Accessicon"
                                         systemImage:nil
                                               desc:kLang(@"addUsedButton_desc")];

    OptionModel *adopt   = [OptionModel optionWithID:@"addPetForAdoption"
                                               title:kLang(@"addPetForAdoption")
                                           imageName:@"adoption"
                                         systemImage:nil
                                               desc:kLang(@"addPetForAdoption_desc")];

    [options addObjectsFromArray:@[newAd, addUsed, adopt]];

    PPSelectOptionViewController *vc =
    [[PPSelectOptionViewController alloc] initWithOptions:options
                                                   title:@""
                                                     row:nil
                                        presentationStyle:PPSelectOptionPresentationMain
                                               completion:^(id selectedObj) {

        OptionModel *op = (OptionModel *)selectedObj;

        if ([op.optID isEqualToString:@"newAd"]) {
            [self openNewAdEditor];
        }
        else if ([op.optID isEqualToString:@"addUsedButton"]) {
            [self openAddUsedAccessory];
        }
        else if ([op.optID isEqualToString:@"addPetForAdoption"]) {
            [self openAdoptionEditor];
        }
    }];

    [PPHomeHelper presentViewControllerSafely:vc
                                         from:self
                                     animated:YES
                                   completion:nil];
}



- (void)openNewAdEditor {
    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return;
    }
    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermPostAds, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add ads.")];
        return;
    }
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    AddNewAd *vc = [AddNewAd new];
    vc.mode = AdEditorModeCreate;
    vc.FromVC = @"AppVC";
    vc.pp_transitionStyle = PPTransitionStyleNone;

    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}


- (void)openAddUsedAccessory {
    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Account blocked")
                          subtitle:kLang(@"Your account is blocked. You can't add accessories right now.")];
        return;
    }

    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermSellUsed, kPermManageStore, kPermPostAds, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add used accessories.")];
        return;
    }

    AddNewAccessory *vc = [AddNewAccessory  new];
    vc.FromVC = @"AppVC";
    vc.accessKindType = AccessTypeAccessory;
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (void)openAdoptionEditor {
    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return;
    }
    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermAdoption, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add adoption posts.")];
        return;
    }
    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] init];
    vc.modalInPresentation = NO;
    vc.pp_transitionStyle = PPTransitionStyleNone;

    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (BOOL)pp_currentUserHasAnyPermissionInKeys:(NSArray<NSString *> *)permissionKeys {
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (!currentUser) {
        return NO;
    }
    return [currentUser hasAnyPermissionInKeys:permissionKeys];
}




- (BOOL)tabBarController:(UITabBarController *)tabBarController
shouldSelectViewController:(UIViewController *)viewController {

    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return NO;
    }

    NSUInteger index =
    [tabBarController.viewControllers indexOfObject:viewController];

    if (index == PPRootTabIndexChats) { // Chats tab
        if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return NO; }
    }
    if (index == PPRootTabIndexOrders) {
        if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return NO; }
    }
    
    if (index == PPRootTabIndexAdd) { // Add tab index
        [self presentBottomSheet];
        return NO;
    }

    return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController
   didSelectViewController:(UIViewController *)viewController
{
    NSUInteger index = [tabBarController.viewControllers indexOfObject:viewController];
    if (index == NSNotFound) {
        return;
    }
    if ((NSInteger)index != self.pp_lastSelectedIndex) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventRootTabSelected];
    }
    self.pp_lastSelectedIndex = (NSInteger)index;
}


#pragma mark - Search Tab Apple-style Focus

- (void)activateSearchIfNeeded
{
    [self pp_openSearchExperienceFromCurrentContextOpeningAccessories:NO];
}

@end












/*
 
 
 - (UIButton *)createCategoriesBackground
 {
     UIButton *bgButton;
     if (@available(iOS 26.0, *)) {
         // 🧊 iOS 26+ system glass button
         UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
         
         cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
         cfg.background.backgroundColor = UIColor.clearColor;
         cfg.baseBackgroundColor = UIColor.clearColor;
         cfg.background.cornerRadius = 0;

         
         bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
         bgButton.configuration = cfg;
         bgButton.alpha = 0.75;
       } else {
          
  
         // 🌫️ Fallback for iOS <26
         bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
         bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
         bgButton.layer.cornerRadius = 16;
         bgButton.layer.masksToBounds = YES;
         bgButton.layer.shadowColor = AppShadowClr.CGColor;
         bgButton.layer.shadowOpacity = 0.15;
         bgButton.layer.shadowRadius = 8;
         bgButton.layer.shadowOffset = CGSizeMake(0, 4);
     }

     bgButton.translatesAutoresizingMaskIntoConstraints = NO;
     return bgButton;
 }
 
 - (void)setupBottomBar {
     
     self.emptyCard = [self createCategoriesBackground];
     self.emptyCard.translatesAutoresizingMaskIntoConstraints = NO;
     [self.view addSubview:self.emptyCard];

    
     self.emptyCard.alpha = 1;
     self.emptyCard.backgroundColor = UIColor.clearColor;

     self.bottomBar = [[PPNewBottomBar alloc] init];
     self.bottomBar.barBackStyle = BarBackStyleClear;
  
     
     if(PPIOS26())
     {
         [self.bottomBar configureTabBarItems:@[
             @{@"tag":@(PPBarTagHome),@"icon":@"homeCus", @"title":kLang(@"MainPage")}, //homeCus
             @{@"tag":@(PPBarTagChats), @"icon":@"notificationCus",  @"title":kLang(@"Notifications")} ,
             @{@"tag":@(PPBarTagOrdersHistory), @"icon":@"ordersCus",  @"title": kLang(@"Orders")},
         ]];
     }
     else
     {
         [self.bottomBar configureWithItems:@[
             @{@"tag":@(PPBarTagHome),@"icon":@"PPhouseCus", @"title":kLang(@"home")},
             @{@"tag":@(PPBarTagChats), @"icon":@"bell",  @"title":kLang(@"Notifications")} ,
             @{@"tag":@(PPBarTagOrdersHistory), @"icon":@"clock", @"title": kLang(@"Orders")},
     ]];
     }

     __weak typeof(self) weakSelf = self;

     self.bottomBar.onTabBarTapped =
     ^(PPBarTag barTag, UIBarItem *barItem) {

         [weakSelf handleBarSelection:barTag];
     };

     self.bottomBar.onButtonTapped =
     ^(NSInteger index, UIButton *button) {

        // [weakSelf handleActionButton:index];
     };

     self.bottomBar.onSearchTapped = ^{
        // [weakSelf openSearch];
     };

     [self.view addSubview:self.bottomBar];

     [NSLayoutConstraint activateConstraints:@[
         [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
         [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
         [self.bottomBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:10],
         [self.bottomBar.heightAnchor constraintEqualToConstant:64]
     ]];
     
     
     [NSLayoutConstraint activateConstraints:@[
         [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0],
         [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-0],
         [self.emptyCard.topAnchor constraintEqualToAnchor:self.bottomBar.topAnchor constant:-12],
         [self.emptyCard.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
     ]];
     
     
     [self.bottomBar selectItemWithTag:PPBarTagHome animated:YES];
 }

 #pragma mark - Bottom Fade Shadow

 - (void)addBottomFadeBelowTabBar {
     return;
     if (self.bottomFadeLayer) return;

     CAGradientLayer *fade = [CAGradientLayer layer];
     fade.colors = @[
         
         (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
         (__bridge id)[AppForgroundColr colorWithAlphaComponent:0.5].CGColor
     ];

     fade.startPoint = CGPointMake(0.5, 0.0);
     fade.endPoint   = CGPointMake(0.5, 1.0);

     fade.locations = @[@0.0, @1.0];

     [self.view.layer addSublayer:fade  ];

     self.bottomFadeLayer = fade;
 }

 */

/*
 MainController Tab Bar Architecture

 - System tab bar is owned by PPRootTabBarController
 - MainController overlays a custom cards tab bar
 - Overlay is attached ONLY while MainController is visible
 - System tab bar is never removed, only visually replaced

 This follows Apple best practices (2026).
 */
