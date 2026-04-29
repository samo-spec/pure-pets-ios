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

    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
    self.tabBar.semanticContentAttribute = semantic;
    self.view.backgroundColor = AppClearClr;
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
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleUserAccessUpdate:)
               name:PPUserManagerDidUpdateUserAccessNotification
             object:nil];
    //[self configureTabBarIndicatorColor];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UserManager.sharedManager startListeningCurrentUserBlockedState];
    [self pp_applyBlockedState:(UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) animated:NO];
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

- (void)pp_setBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    NSMutableArray<UIView *> *bottomNavigationViews = [NSMutableArray array];
    if (self.tabBar) [bottomNavigationViews addObject:self.tabBar];
    if (self.bottomBar) [bottomNavigationViews addObject:self.bottomBar];
    if (self.emptyCard) [bottomNavigationViews addObject:self.emptyCard];

    if (!hidden) {
        for (UIView *view in bottomNavigationViews) {
            view.hidden = NO;
        }
    }

    void (^changes)(void) = ^{
        for (UIView *view in bottomNavigationViews) {
            view.alpha = hidden ? 0.0 : 1.0;
        }
    };

    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        for (UIView *view in bottomNavigationViews) {
            view.hidden = hidden;
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
     
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self pp_updateBlockedOverlayTopInset];
    [self pp_updateTabBarSelectionIndicatorIfNeeded];
    
}

#pragma mark - Blocked Overlay

- (void)pp_handleBlockedStateNotification:(NSNotification *)notification {
    NSNumber *blockedValue = notification.userInfo[PPUserManagerBlockedStateUserInfoKey];
    BOOL isBlocked = [blockedValue respondsToSelector:@selector(boolValue)]
        ? blockedValue.boolValue
        : (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked);
    [self pp_applyBlockedState:isBlocked animated:YES];
}

- (void)pp_handleUserAccessUpdate:(NSNotification *)notification {
    BOOL effectivelyBlocked = [notification.userInfo[@"effectivelyBlocked"] boolValue];
    [self pp_applyBlockedState:effectivelyBlocked animated:YES];
}

- (void)pp_setupBlockedOverlayIfNeeded {
    if (self.blockedOverlayView) {
        return;
    }

    UIColor *primaryColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *primaryGlowColor = AppPrimaryClrShiner ?: [primaryColor colorWithAlphaComponent:0.94];
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *titleColor = AppForgroundColr ?: UIColor.labelColor;
    UIColor *secondaryTextColor = AppBackgroundClrLigter ?: UIColor.secondaryLabelColor;
    UIColor *whiteTint = UIColor.whiteColor;
    NSString *brandName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (brandName.length == 0) {
        brandName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: @"Pure Pets";
    }

    UIControl *overlay = [[UIControl alloc] init];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.backgroundColor = UIColor.clearColor;
    overlay.hidden = YES;
    overlay.alpha = 0.0;
    overlay.accessibilityViewIsModal = YES;
    [self.view addSubview:overlay];

    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIBlurEffect *backdropEffect = nil;
    if (@available(iOS 13.0, *)) {
        backdropEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    } else {
        backdropEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }

    UIVisualEffectView *backdropView = [[UIVisualEffectView alloc] initWithEffect:backdropEffect];
    backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    backdropView.userInteractionEnabled = NO;
    [overlay addSubview:backdropView];

    UIView *scrimView = [[UIView alloc] init];
    scrimView.translatesAutoresizingMaskIntoConstraints = NO;
    scrimView.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.34];
    scrimView.userInteractionEnabled = NO;
    [overlay addSubview:scrimView];

    UIView *topGlowView = [[UIView alloc] init];
    topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    topGlowView.userInteractionEnabled = NO;
    topGlowView.backgroundColor = [primaryColor colorWithAlphaComponent:0.20];
    topGlowView.layer.cornerRadius = 154.0;
    [topGlowView pp_setShadowColor:primaryColor];
    topGlowView.layer.shadowOpacity = 0.24f;
    topGlowView.layer.shadowRadius = 48.0f;
    topGlowView.layer.shadowOffset = CGSizeZero;
    [overlay addSubview:topGlowView];

    UIView *bottomGlowView = [[UIView alloc] init];
    bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlowView.userInteractionEnabled = NO;
    bottomGlowView.backgroundColor = [primaryGlowColor colorWithAlphaComponent:0.14];
    bottomGlowView.layer.cornerRadius = 144.0;
    [bottomGlowView pp_setShadowColor:primaryGlowColor];
    bottomGlowView.layer.shadowOpacity = 0.16f;
    bottomGlowView.layer.shadowRadius = 44.0f;
    bottomGlowView.layer.shadowOffset = CGSizeZero;
    [overlay addSubview:bottomGlowView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:contentView];

    self.blockedOverlayTopConstraint = [contentView.topAnchor constraintGreaterThanOrEqualToAnchor:overlay.topAnchor constant:120.0];
    NSLayoutConstraint *contentPreferredWidth =
        [contentView.widthAnchor constraintEqualToAnchor:overlay.widthAnchor constant:-40.0];
    contentPreferredWidth.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *contentVerticalCenter =
        [contentView.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor constant:-14.0];
    contentVerticalCenter.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [backdropView.topAnchor constraintEqualToAnchor:overlay.topAnchor],
        [backdropView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
        [backdropView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],
        [backdropView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],

        [scrimView.topAnchor constraintEqualToAnchor:overlay.topAnchor],
        [scrimView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
        [scrimView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],
        [scrimView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],

        [topGlowView.widthAnchor constraintEqualToConstant:308.0],
        [topGlowView.heightAnchor constraintEqualToConstant:308.0],
        [topGlowView.topAnchor constraintEqualToAnchor:overlay.topAnchor constant:-58.0],
        [topGlowView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:-84.0],

        [bottomGlowView.widthAnchor constraintEqualToConstant:288.0],
        [bottomGlowView.heightAnchor constraintEqualToConstant:288.0],
        [bottomGlowView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:74.0],
        [bottomGlowView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:54.0],

        self.blockedOverlayTopConstraint,
        contentPreferredWidth,
        contentVerticalCenter,
        [contentView.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [contentView.leadingAnchor constraintGreaterThanOrEqualToAnchor:overlay.leadingAnchor constant:20.0],
        [contentView.trailingAnchor constraintLessThanOrEqualToAnchor:overlay.trailingAnchor constant:-20.0],
        [contentView.widthAnchor constraintLessThanOrEqualToConstant:430.0],
        [contentView.bottomAnchor constraintLessThanOrEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-28.0]
    ]];

    UIView *brandPillView = [[UIView alloc] init];
    brandPillView.translatesAutoresizingMaskIntoConstraints = NO;
    brandPillView.backgroundColor = [whiteTint colorWithAlphaComponent:0.10];
    brandPillView.layer.cornerRadius = 20.0;
    brandPillView.layer.borderWidth = 1.0;
    [brandPillView pp_setBorderColor:[whiteTint colorWithAlphaComponent:0.12]];
    [brandPillView pp_setShadowColor:UIColor.blackColor];
    brandPillView.layer.shadowOpacity = 0.08f;
    brandPillView.layer.shadowRadius = 12.0f;
    brandPillView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    if (@available(iOS 13.0, *)) {
        brandPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *brandIconPlateView = [[UIView alloc] init];
    brandIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    brandIconPlateView.backgroundColor = [primaryColor colorWithAlphaComponent:0.18];
    brandIconPlateView.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) {
        brandIconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *brandIconView = [[UIImageView alloc] init];
    brandIconView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        brandIconView.image = [UIImage systemImageNamed:@"lock.shield.fill"];
    }
    brandIconView.contentMode = UIViewContentModeScaleAspectFit;
    brandIconView.tintColor = primaryColor;

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    brandLabel.text = brandName;
    brandLabel.textAlignment = NSTextAlignmentCenter;
    brandLabel.textColor = [whiteTint colorWithAlphaComponent:0.96];
    brandLabel.font = [GM boldFontWithSize:13];

    [brandIconPlateView addSubview:brandIconView];
    [brandPillView addSubview:brandIconPlateView];
    [brandPillView addSubview:brandLabel];

    [NSLayoutConstraint activateConstraints:@[
        [brandPillView.heightAnchor constraintEqualToConstant:40.0],
        [brandIconPlateView.leadingAnchor constraintEqualToAnchor:brandPillView.leadingAnchor constant:8.0],
        [brandIconPlateView.centerYAnchor constraintEqualToAnchor:brandPillView.centerYAnchor],
        [brandIconPlateView.widthAnchor constraintEqualToConstant:24.0],
        [brandIconPlateView.heightAnchor constraintEqualToConstant:24.0],
        [brandIconView.centerXAnchor constraintEqualToAnchor:brandIconPlateView.centerXAnchor],
        [brandIconView.centerYAnchor constraintEqualToAnchor:brandIconPlateView.centerYAnchor],
        [brandIconView.widthAnchor constraintEqualToConstant:13.0],
        [brandIconView.heightAnchor constraintEqualToConstant:13.0],
        [brandLabel.topAnchor constraintEqualToAnchor:brandPillView.topAnchor],
        [brandLabel.bottomAnchor constraintEqualToAnchor:brandPillView.bottomAnchor],
        [brandLabel.leadingAnchor constraintEqualToAnchor:brandIconPlateView.trailingAnchor constant:10.0],
        [brandLabel.trailingAnchor constraintEqualToAnchor:brandPillView.trailingAnchor constant:-14.0]
    ]];

    UIView *animationPlateView = [[UIView alloc] init];
    animationPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    animationPlateView.backgroundColor = [surfaceColor colorWithAlphaComponent:0.78];
    animationPlateView.layer.cornerRadius = 42.0;
    animationPlateView.layer.borderWidth = 1.0;
    [animationPlateView pp_setBorderColor:[whiteTint colorWithAlphaComponent:0.14]];
    [animationPlateView pp_setShadowColor:UIColor.blackColor];
    animationPlateView.layer.shadowOpacity = 0.18f;
    animationPlateView.layer.shadowRadius = 30.0f;
    animationPlateView.layer.shadowOffset = CGSizeMake(0.0, 20.0);
    if (@available(iOS 13.0, *)) {
        animationPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *animationGlowView = [[UIView alloc] init];
    animationGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    animationGlowView.userInteractionEnabled = NO;
    animationGlowView.backgroundColor = [primaryGlowColor colorWithAlphaComponent:0.16];
    animationGlowView.layer.cornerRadius = 56.0;
    [animationGlowView pp_setShadowColor:primaryGlowColor];
    animationGlowView.layer.shadowOpacity = 0.18f;
    animationGlowView.layer.shadowRadius = 24.0f;
    animationGlowView.layer.shadowOffset = CGSizeZero;

    [animationPlateView addSubview:animationGlowView];

    LOTAnimationView *headerAnimationView = [[LOTAnimationView alloc] init];
    headerAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    headerAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    headerAnimationView.loopAnimation = YES;
    headerAnimationView.animationSpeed = 1.0;
    [animationPlateView addSubview:headerAnimationView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"auth_account_blocked_title");
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = titleColor;
    titleLabel.font = [GM boldFontWithSize:30];
    titleLabel.numberOfLines = 0;
    titleLabel.alpha = 0.98;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"auth_account_blocked_message");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.textColor = [secondaryTextColor colorWithAlphaComponent:0.96];
    subtitleLabel.font = [GM MidFontWithSize:16];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.alpha = 0.98;

    UIButton *contactSupportButton =
    [self pp_makeBlockedOverlayButtonWithTitle:kLang(@"order_support_button")
                                    emphasized:YES
                                   destructive:NO
                                        action:@selector(pp_blockedContactSupportTapped)];

    UIButton *signOutButton =
    [self pp_makeBlockedOverlayButtonWithTitle:kLang(@"logout")
                                    emphasized:NO
                                   destructive:YES
                                        action:@selector(pp_blockedSignOutTapped)];

    UIStackView *actionStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        contactSupportButton,
        signOutButton
    ]];
    actionStack.translatesAutoresizingMaskIntoConstraints = NO;
    actionStack.axis = UILayoutConstraintAxisVertical;
    actionStack.alignment = UIStackViewAlignmentFill;
    actionStack.spacing = 12.0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        brandPillView,
        animationPlateView,
        titleLabel,
        subtitleLabel,
        actionStack
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16.0;
    [contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [animationPlateView.widthAnchor constraintEqualToConstant:172.0],
        [animationPlateView.heightAnchor constraintEqualToConstant:172.0],
        [animationGlowView.centerXAnchor constraintEqualToAnchor:animationPlateView.centerXAnchor],
        [animationGlowView.centerYAnchor constraintEqualToAnchor:animationPlateView.centerYAnchor],
        [animationGlowView.widthAnchor constraintEqualToConstant:112.0],
        [animationGlowView.heightAnchor constraintEqualToConstant:112.0],
        [headerAnimationView.centerXAnchor constraintEqualToAnchor:animationPlateView.centerXAnchor],
        [headerAnimationView.centerYAnchor constraintEqualToAnchor:animationPlateView.centerYAnchor],
        [headerAnimationView.widthAnchor constraintEqualToAnchor:animationPlateView.widthAnchor multiplier:0.74],
        [headerAnimationView.heightAnchor constraintEqualToAnchor:headerAnimationView.widthAnchor],
        [contactSupportButton.heightAnchor constraintEqualToConstant:56.0],
        [signOutButton.heightAnchor constraintEqualToConstant:52.0],
        [titleLabel.widthAnchor constraintEqualToAnchor:contentView.widthAnchor],
        [subtitleLabel.widthAnchor constraintEqualToAnchor:contentView.widthAnchor],
        [actionStack.widthAnchor constraintEqualToAnchor:contentView.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];

    [stack setCustomSpacing:22.0 afterView:brandPillView];
    [stack setCustomSpacing:18.0 afterView:animationPlateView];
    [stack setCustomSpacing:10.0 afterView:titleLabel];
    [stack setCustomSpacing:28.0 afterView:subtitleLabel];

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
    self.blockedOverlayCardView = contentView;
    self.blockedHeaderAnimationView = headerAnimationView;
    self.blockedContactButton = contactSupportButton;
}

- (UIButton *)pp_makeBlockedOverlayButtonWithTitle:(NSString *)title
                                        emphasized:(BOOL)emphasized
                                       destructive:(BOOL)destructive
                                            action:(SEL)action {
    UIColor *primaryColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *whiteTint = UIColor.whiteColor;
    UIColor *destructiveColor = UIColor.systemRedColor;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [GM boldFontWithSize:17];
    button.layer.cornerRadius = 18.0;
    button.layer.masksToBounds = NO;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (emphasized) {
        button.backgroundColor = primaryColor;
        [button setTitleColor:whiteTint forState:UIControlStateNormal];
        [button pp_setShadowColor:primaryColor];
        button.layer.shadowOpacity = 0.24f;
        button.layer.shadowRadius = 18.0f;
        button.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    } else {
        UIColor *foregroundColor = destructive ? destructiveColor : titleColor;
        button.backgroundColor = [surfaceColor colorWithAlphaComponent:0.88];
        button.layer.borderWidth = 1.0;
        [button pp_setBorderColor:[foregroundColor colorWithAlphaComponent:destructive ? 0.22 : 0.12]];
        [button setTitleColor:foregroundColor forState:UIControlStateNormal];
        [button pp_setShadowColor:UIColor.blackColor];
        button.layer.shadowOpacity = 0.06f;
        button.layer.shadowRadius = 10.0f;
        button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
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
    }

    CGAffineTransform hiddenTransform =
        CGAffineTransformConcat(CGAffineTransformMakeScale(0.97, 0.97),
                                CGAffineTransformMakeTranslation(0.0, 18.0));
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;
    BOOL isPresenting = shouldShow && (self.blockedOverlayView.hidden || self.blockedOverlayView.alpha < 0.01f);

    if (shouldShow && isPresenting) {
        self.blockedOverlayView.alpha = 0.0;
        self.blockedOverlayCardView.alpha = 0.0;
        self.blockedOverlayCardView.transform = hiddenTransform;
    }

    void (^completion)(BOOL) = ^(BOOL finished) {
        (void)finished;
        if (!shouldShow) {
            self.blockedOverlayView.hidden = YES;
            [self.blockedHeaderAnimationView stop];
            self.blockedOverlayCardView.transform = hiddenTransform;
            self.blockedOverlayCardView.alpha = 0.0;
        } else {
            [self.blockedHeaderAnimationView play];
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.24
                         animations:^{
            self.blockedOverlayView.alpha = targetAlpha;
        } completion:completion];

        [UIView animateWithDuration:shouldShow ? 0.56 : 0.20
                              delay:0.0
             usingSpringWithDamping:shouldShow ? 0.86 : 1.0
              initialSpringVelocity:shouldShow ? 0.24 : 0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.blockedOverlayCardView.alpha = shouldShow ? 1.0 : 0.0;
            self.blockedOverlayCardView.transform = shouldShow ? CGAffineTransformIdentity : hiddenTransform;
        } completion:nil];
    } else {
        self.blockedOverlayView.alpha = targetAlpha;
        self.blockedOverlayCardView.alpha = shouldShow ? 1.0 : 0.0;
        self.blockedOverlayCardView.transform = shouldShow ? CGAffineTransformIdentity : hiddenTransform;
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

    self.blockedOverlayTopConstraint.constant = MAX(safeTop, navBottom) + 24.0;
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
            [AppForgroundColr colorWithAlphaComponent:0.08];
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
        [self.tabBar pp_setShadowColor:UIColor.blackColor];
        self.tabBar.layer.shadowOpacity = 0.12;
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


- (void)pp_updateTabBarSelectionIndicatorIfNeeded
{
    if (!self.tabBar || self.tabBar.items.count == 0) {
        return;
    }

    CGSize tabBarSize = self.tabBar.bounds.size;
    if (tabBarSize.width <= 0.0 || tabBarSize.height <= 0.0) {
        return;
    }

    CGFloat itemWidth = floor(tabBarSize.width / MAX(1.0, (CGFloat)self.tabBar.items.count));
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
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(14, 14, 14, 14);
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.18];
        cfg.background.cornerRadius = 18;
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
        showAddMenuButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        showAddMenuButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        showAddMenuButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        // Place image on top, title below, with spacing
       
        
        //showAddMenuButton.titleEdgeInsets = UIEdgeInsetsMake(imageSize.height + spacing, -imageSize.width, 0, 0);
        //showAddMenuButton.imageEdgeInsets = UIEdgeInsetsMake(-titleSize.height - spacing, 0, 0, -titleSize.width);
        showAddMenuButton.layer.cornerRadius = 26;
        showAddMenuButton.clipsToBounds = YES;
    }

    

    showAddMenuButton.tintColor = AppForgroundColr;
    showAddMenuButton.imageView.tintColor = AppForgroundColr;

    // Shadow + clipping — version-specific handling
    if (@available(iOS 26.0, *)) {
        // iOS 26+: Glass button — external shadow for depth, no clipping
        [showAddMenuButton pp_setShadowColor:UIColor.blackColor];
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
        [showAddMenuButton.centerYAnchor constraintEqualToAnchor:self.tabBar.centerYAnchor constant:-16],
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
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
        [self pp_applyBlockedState:YES animated:YES];
        return;
    }
    
    
    // Build options
    NSMutableArray<OptionModel *> *options = [NSMutableArray new];

    OptionModel *newAd   = [OptionModel optionWithID:@"newAd"
                                               title:kLang(@"newAd")
                                           imageName:@"new_adColor"
                                         systemImage:nil
                                               desc:kLang(@"newAd_desc")];

    OptionModel *addUsed = [OptionModel optionWithID:@"addUsedButton"
                                               title:kLang(@"addUsedButton")
                                           imageName:@"AccessiconColor"
                                         systemImage:nil
                                               desc:kLang(@"addUsedButton_desc")];

    OptionModel *adopt   = [OptionModel optionWithID:@"addPetForAdoption"
                                               title:kLang(@"addPetForAdoption")
                                           imageName:@"adoptionColor"
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
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
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
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
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
    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
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

    if (UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) {
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
         [bgButton pp_setShadowColor:AppShadowClr];
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
