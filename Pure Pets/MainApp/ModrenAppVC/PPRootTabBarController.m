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
#import "PPNovaChatViewController.h"

// ...




static NSString * const kPPBlockedOverlaySupportPhoneNumber = @"+97459997720";
static NSInteger const PPRootTabIndexHome = 0;
static NSInteger const PPRootTabIndexChats = 1;
static NSInteger const PPRootTabIndexAdd = 2;
static NSInteger const PPRootTabIndexOrders = 3;
static NSInteger const PPRootTabIndexSettings = 4;
static NSString * const PPNovaFloatingVisibilityDidChangeNotification = @"PPNovaFloatingVisibilityDidChangeNotification";
static NSString * const PPNovaFloatingVisibilityValueKey = @"visible";

@class PPPremiumDockBarDelegate;

@interface PPRootTabBarController ()
@property (nonatomic, strong) UIButton *leadingTabButton;
@property (nonatomic, strong) UIButton *emptyCard;
@property (nonatomic, strong) PPNewBottomBar *bottomBar;
@property (nonatomic, strong) UITabBar *premiumTabDockView;
@property (nonatomic, strong) PPPremiumDockBarDelegate *premiumDockDelegate;
@property (nonatomic, strong) UIView *premiumBottomFadeView;
- (void)pp_premiumDockDidSelectItem:(UITabBarItem *)item;
- (void)pp_setupPremiumBottomFade;
@property (nonatomic, strong) NSArray<UITabBarItem *> *premiumTabItems;
@property (nonatomic, strong) UIButton *premiumNovaButton;
@property (nonatomic, strong, nullable) LOTAnimationView *premiumNovaLottieView;
@property (nonatomic, assign) BOOL premiumNovaVisibleByConfiguration;
@property (nonatomic, assign) BOOL premiumBottomNavigationHidden;
@property (nonatomic, assign) BOOL premiumNavigationDidAnimateIn;
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
- (void)pp_setupPremiumBottomNavigation;
- (void)pp_setupPremiumNovaButton;
- (void)pp_novaButtonTapped;
- (void)pp_handleNovaFloatingVisibilityUpdate:(NSNotification *)notification;
- (UIImage *)pp_premiumSymbolForTabIndex:(NSInteger)index selected:(BOOL)selected;
- (void)pp_applyPremiumTabSelectionAnimated:(BOOL)animated;
- (void)pp_animatePremiumBottomNavigationEntranceIfNeeded;
- (void)pp_premiumControlTouchDown:(UIButton *)sender;
- (void)pp_premiumControlTouchUp:(UIButton *)sender;
- (void)pp_setPremiumBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated;
- (void)pp_updatePremiumChatsBadgeWithCount:(NSInteger)count;
- (void)pp_updateTabBarSelectionIndicatorIfNeeded;
- (void)pp_updateTabBarTopSeparatorIfNeeded;
- (UIImage *)pp_tabBarSelectionIndicatorImageForItemSize:(CGSize)itemSize
                                           indicatorSize:(CGSize)indicatorSize
                                               fillColor:(UIColor *)fillColor
                                             strokeColor:(UIColor *)strokeColor;
@end

#pragma mark - Premium Dock Delegate

// The premium dock is a standalone UITabBar. Its delegate must NOT be the
// UITabBarController itself: UIKit would then run its items-vs-viewControllers
// consistency check on the dock's foreign items and crash on selection
// (NSInternalInconsistencyException: "No view controller matches the UITabBarItem").
// Routing selection through a dedicated object avoids that association.
@interface PPPremiumDockBarDelegate : NSObject <UITabBarDelegate>
@property (nonatomic, weak) PPRootTabBarController *controller;
@end

@implementation PPPremiumDockBarDelegate
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    [self.controller pp_premiumDockDidSelectItem:item];
}
@end

// Gradient-backed view: the layer auto-resizes with the view's bounds, so the
// bottom fade tracks layout without manual frame updates.
@interface PPBottomFadeView : UIView
@end

@implementation PPBottomFadeView
+ (Class)layerClass { return [CAGradientLayer class]; }
@end

@implementation PPRootTabBarController

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    [super setSelectedIndex:selectedIndex];
    if (self.premiumTabItems.count > 0) {
        [self pp_applyPremiumTabSelectionAnimated:NO];
    }
}

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

    [self pp_setupPremiumBottomNavigation];
    
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
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_handleNovaFloatingVisibilityUpdate:)
               name:PPNovaFloatingVisibilityDidChangeNotification
             object:nil];
    //[self configureTabBarIndicatorColor];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UserManager.sharedManager startListeningCurrentUserBlockedState];
    [self pp_applyBlockedState:(UserManager.sharedManager.isCurrentUserBlocked || UserManager.sharedManager.isCurrentUserEffectivelyBlocked) animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_animatePremiumBottomNavigationEntranceIfNeeded];
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
    [self pp_setPremiumBottomNavigationHidden:NO animated:YES];
}
- (void)showSystemTabBar
{
    [self pp_setPremiumBottomNavigationHidden:NO animated:YES];
}

- (void)hideSystemTabBar
{
    [self pp_setPremiumBottomNavigationHidden:YES animated:YES];
}

- (void)pp_setBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    [self pp_setPremiumBottomNavigationHidden:hidden animated:animated];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
     
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self pp_updateBlockedOverlayTopInset];
    [self pp_updateTabBarSelectionIndicatorIfNeeded];
    [self pp_applyPremiumTabSelectionAnimated:NO];
    
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
    [self pp_updatePremiumChatsBadgeWithCount:totalUnreadCount];

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
    UITabBar *dockTabBar = self.premiumTabDockView;
    if (!dockTabBar || dockTabBar.items.count == 0) {
        return;
    }

    CGSize tabBarSize = dockTabBar.bounds.size;
    if (tabBarSize.width <= 0.0 || tabBarSize.height <= 0.0) {
        return;
    }

    CGFloat itemWidth = floor(tabBarSize.width / MAX(1.0, (CGFloat)dockTabBar.items.count));
    if (itemWidth <= 0.0) {
        return;
    }

    CGSize itemSize = CGSizeMake(itemWidth, tabBarSize.height);
    CGSize indicatorSize = CGSizeMake(MIN(60.0, MAX(44.0, itemWidth - 18.0)), 34.0);
    UIColor *fillColor = [(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:(PPIOS26() ? 0.12 : 0.10)];
    UIColor *strokeColor = [(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.14];
    dockTabBar.selectionIndicatorImage =
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
                                          (itemSize.height - indicatorSize.height) * 0.5,
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

- (void)pp_setupPremiumBottomNavigation
{
    [self pp_setupPremiumBottomFade];
    [self addPlusTabBarButton];
    [self pp_setupPremiumNovaButton];

    if (!PPIOS26()) {
        // On iOS < 26 keep the original system tab bar visible and skip the custom dock
        self.tabBar.hidden = NO;
        self.tabBar.alpha = 1.0;
        self.tabBar.userInteractionEnabled = YES;
        return;
    }

    self.tabBar.hidden = YES;
    self.tabBar.alpha = 0.0;
    self.tabBar.userInteractionEnabled = NO;

    UITabBar *dockView = [[UITabBar alloc] init];
    dockView.translatesAutoresizingMaskIntoConstraints = NO;
    self.premiumDockDelegate = [[PPPremiumDockBarDelegate alloc] init];
    self.premiumDockDelegate.controller = self;
    dockView.delegate = self.premiumDockDelegate;
    dockView.itemPositioning = UITabBarItemPositioningFill;
    dockView.tintColor = AppPrimaryClr ?: UIColor.systemTealColor;
    dockView.unselectedItemTintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.76];
    dockView.backgroundColor = UIColor.clearColor;
    dockView.layer.masksToBounds = NO;
    dockView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:dockView];
    self.premiumTabDockView = dockView;
    
    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = UIColor.redColor;
    appearance.shadowColor = UIColor.clearColor;

    UIColor *normalIconColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.76];
    UIColor *selectedIconColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIFont *titleFont = [GM boldFontWithSize:10] ?: [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    NSDictionary<NSAttributedStringKey, id> *normalTitleAttributes =
        @{ NSFontAttributeName: titleFont, NSForegroundColorAttributeName: normalIconColor };
    NSDictionary<NSAttributedStringKey, id> *selectedTitleAttributes =
        @{ NSFontAttributeName: titleFont, NSForegroundColorAttributeName: selectedIconColor };

    NSArray<UITabBarItemAppearance *> *itemAppearances = @[
        appearance.stackedLayoutAppearance,
        appearance.inlineLayoutAppearance,
        appearance.compactInlineLayoutAppearance
    ];
    for (UITabBarItemAppearance *itemAppearance in itemAppearances) {
        itemAppearance.normal.iconColor = normalIconColor;
        itemAppearance.selected.iconColor = selectedIconColor;
        itemAppearance.normal.titleTextAttributes = normalTitleAttributes;
        itemAppearance.selected.titleTextAttributes = selectedTitleAttributes;
    }

    dockView.standardAppearance = appearance;
    if (@available(iOS 15.0, *)) {
        dockView.scrollEdgeAppearance = appearance;
    }
    dockView.clipsToBounds = NO;

    NSArray<NSNumber *> *visibleTabIndexes = @[
        @(PPRootTabIndexHome),
        @(PPRootTabIndexChats),
        @(PPRootTabIndexOrders),
        @(PPRootTabIndexSettings)
    ];
    NSMutableArray<UITabBarItem *> *items = [NSMutableArray arrayWithCapacity:visibleTabIndexes.count];
    for (NSNumber *tabIndexValue in visibleTabIndexes) {
        NSInteger index = tabIndexValue.integerValue;
        UITabBarItem *sourceItem = self.viewControllers[index].tabBarItem;
        UITabBarItem *item =
            [[UITabBarItem alloc] initWithTitle:sourceItem.title
                                         image:[self pp_premiumSymbolForTabIndex:index selected:NO]
                                 selectedImage:[self pp_premiumSymbolForTabIndex:index selected:YES]];
        item.tag = index;
        item.accessibilityLabel = sourceItem.accessibilityLabel ?: sourceItem.title;
        item.accessibilityHint = sourceItem.accessibilityHint;
        [items addObject:item];
    }
    dockView.items = items.copy;
    self.premiumTabItems = items.copy;

    CGFloat dockHeight = 64.0;
    if (@available(iOS 26.0, *)) {
        dockHeight = 86.0;
    }
    [NSLayoutConstraint activateConstraints:@[
        [dockView.leadingAnchor constraintEqualToAnchor:self.leadingTabButton.trailingAnchor constant:PPIOS26() ? -6 : 4],
        [dockView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-(PPIOS26() ? -2 : 4)],
        [dockView.topAnchor constraintEqualToAnchor:self.leadingTabButton.topAnchor constant:-2],
        [dockView.heightAnchor constraintEqualToConstant:dockHeight]
    ]];
    
   

    [self pp_applyPremiumTabSelectionAnimated:NO];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        dockView.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
        self.leadingTabButton.alpha = 0.0;
        self.leadingTabButton.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                    CGAffineTransformMakeScale(0.94, 0.94));
        self.premiumNovaButton.alpha = 0.0;
        self.premiumNovaButton.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 8.0),
                                    CGAffineTransformMakeScale(0.94, 0.94));
    }
    [self.view bringSubviewToFront:dockView];
    [self.view bringSubviewToFront:self.leadingTabButton];
    [self.view bringSubviewToFront:self.premiumNovaButton];
}

- (void)pp_setupPremiumBottomFade
{
    if (self.premiumBottomFadeView) {
        return;
    }
    PPBottomFadeView *fadeView = [[PPBottomFadeView alloc] init];
    fadeView.translatesAutoresizingMaskIntoConstraints = NO;
    fadeView.userInteractionEnabled = NO;
    fadeView.backgroundColor = UIColor.clearColor;

    UIColor *fadeColor = bageColor ?: AppBackgroundClr ?: UIColor.systemBackgroundColor;
    CAGradientLayer *gradientLayer = (CAGradientLayer *)fadeView.layer;
    gradientLayer.colors = @[
        (__bridge id)[fadeColor colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)fadeColor.CGColor
    ];
    gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    gradientLayer.endPoint = CGPointMake(0.5, 1.0);
    gradientLayer.locations = @[@0.0, @0.85];

    [self.view addSubview:fadeView];
    self.premiumBottomFadeView = fadeView;

    [NSLayoutConstraint activateConstraints:@[
        [fadeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [fadeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [fadeView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [fadeView.heightAnchor constraintEqualToConstant:70.0]
    ]];
}

- (void)pp_setupPremiumNovaButton
{
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.adjustsImageWhenHighlighted = NO;
    button.layer.cornerRadius = 27.0;
    PPApplyContinuousCorners(button, 27.0);
    button.layer.masksToBounds = NO;
    [button pp_setShadowColor:accentColor];
    button.layer.shadowOpacity = 0.10;
    button.layer.shadowRadius = 14.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration glassButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.baseForegroundColor = accentColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
        button.configuration = configuration;
    } else {
        button.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.88];
        button.layer.borderWidth = 0.5;
        [button pp_setBorderColor:[accentColor colorWithAlphaComponent:0.16]];
    }

    button.accessibilityLabel = kLang(@"nova_chat_accessibility") ?: @"Chat with Nova";
    button.accessibilityTraits = UIAccessibilityTraitButton;
    [button addTarget:self action:@selector(pp_novaButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_premiumControlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_premiumControlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.view addSubview:button];
    self.premiumNovaButton = button;
    self.premiumNovaVisibleByConfiguration = YES;

    LOTAnimationView *animationView = [[LOTAnimationView alloc] init];
    animationView.translatesAutoresizingMaskIntoConstraints = NO;
    animationView.userInteractionEnabled = NO;
    animationView.contentMode = UIViewContentModeScaleAspectFit;
    animationView.loopAnimation = YES;
    animationView.animationSpeed = 0.6;
    [button addSubview:animationView];
    self.premiumNovaLottieView = animationView;

    [NSLayoutConstraint activateConstraints:@[
        [button.centerXAnchor constraintEqualToAnchor:self.leadingTabButton.centerXAnchor],
        [button.bottomAnchor constraintEqualToAnchor:self.leadingTabButton.topAnchor constant:-10.0],
        [button.widthAnchor constraintEqualToConstant:54.0],
        [button.heightAnchor constraintEqualToConstant:54.0],
        [animationView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [animationView.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [animationView.widthAnchor constraintEqualToConstant:42.0],
        [animationView.heightAnchor constraintEqualToConstant:42.0]
    ]];

    __weak typeof(self) weakSelf = self;
    __weak LOTAnimationView *weakAnimationView = animationView;
    [AppClasses setAnimationNamed:@"Ncolored"
                            ToView:animationView
                         withSpeed:0.6
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            LOTAnimationView *strongAnimationView = weakAnimationView;
            if (!strongSelf || !strongAnimationView) {
                return;
            }
            if (success) {
                [strongAnimationView play];
                return;
            }
            strongAnimationView.hidden = YES;
            UIImageSymbolConfiguration *configuration =
                [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                 weight:UIImageSymbolWeightMedium];
            UIImage *fallbackIcon =
                [UIImage systemImageNamed:@"sparkles" withConfiguration:configuration];
            if (@available(iOS 26.0, *)) {
                UIButtonConfiguration *buttonConfiguration =
                    strongSelf.premiumNovaButton.configuration;
                buttonConfiguration.image = fallbackIcon;
                buttonConfiguration.baseForegroundColor = accentColor;
                strongSelf.premiumNovaButton.configuration = buttonConfiguration;
            } else {
                [strongSelf.premiumNovaButton setImage:fallbackIcon forState:UIControlStateNormal];
                strongSelf.premiumNovaButton.tintColor = accentColor;
            }
        });
    }];
}

- (void)pp_novaButtonTapped
{
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [feedback impactOccurred];
    }
    [PPNovaChatViewController presentNovaFromViewController:self];
}

- (void)pp_handleNovaFloatingVisibilityUpdate:(NSNotification *)notification
{
    id visibleValue = notification.userInfo[PPNovaFloatingVisibilityValueKey];
    if (![visibleValue respondsToSelector:@selector(boolValue)]) {
        return;
    }
    self.premiumNovaVisibleByConfiguration = [visibleValue boolValue];
    self.premiumNovaButton.hidden =
        !self.premiumNovaVisibleByConfiguration || self.premiumBottomNavigationHidden;
}

- (UIImage *)pp_premiumSymbolForTabIndex:(NSInteger)index selected:(BOOL)selected
{
    NSString *normalSymbolName = @"circle";
    NSString *selectedSymbolName = @"circle.fill";
    switch (index) {
        case PPRootTabIndexHome:
            normalSymbolName = @"house";
            selectedSymbolName = @"house.fill";
            break;
        case PPRootTabIndexChats:
            normalSymbolName = @"bubble.left.and.bubble.right";
            selectedSymbolName = @"bubble.left.and.bubble.right.fill";
            break;
        case PPRootTabIndexOrders:
            normalSymbolName = @"bag";
            selectedSymbolName = @"bag.fill";
            break;
        case PPRootTabIndexSettings:
            normalSymbolName = @"slider.horizontal.3";
            selectedSymbolName = @"slider.horizontal.3";
            break;
        default:
            break;
    }
    UIImageSymbolConfiguration *symbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:19.0
                                                         weight:UIImageSymbolWeightMedium
                                                          scale:UIImageSymbolScaleMedium];
    return [UIImage systemImageNamed:(selected ? selectedSymbolName : normalSymbolName)
                   withConfiguration:symbolConfiguration];
}

- (void)pp_premiumDockDidSelectItem:(UITabBarItem *)item
{
    NSInteger index = item.tag;
    if (index < 0 || index >= (NSInteger)self.viewControllers.count) {
        return;
    }
    UIViewController *viewController = self.viewControllers[index];
    if (![self tabBarController:self shouldSelectViewController:viewController]) {
        [self pp_applyPremiumTabSelectionAnimated:NO];
        return;
    }

    BOOL isChangingTabs = self.selectedIndex != (NSUInteger)index;
    if (!isChangingTabs) {
        // Same tab tapped: pop one level toward root on each tap
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)viewController;
            if (nav.viewControllers.count > 1) {
                [nav popViewControllerAnimated:YES];
            }
        }
        return;
    }

    [super setSelectedIndex:(NSUInteger)index];
    [self tabBarController:self didSelectViewController:viewController];
    [self pp_applyPremiumTabSelectionAnimated:YES];
}

- (void)pp_applyPremiumTabSelectionAnimated:(BOOL)animated
{
    NSUInteger activeIndex =
        self.selectedIndex == PPRootTabIndexAdd ? self.pp_lastSelectedIndex : self.selectedIndex;
    UITabBarItem *selectedItem = nil;
    for (UITabBarItem *item in self.premiumTabItems) {
        if (item.tag == (NSInteger)activeIndex) {
            selectedItem = item;
            break;
        }
    }
    if (!selectedItem || self.premiumTabDockView.selectedItem == selectedItem) {
        return;
    }
    void (^updates)(void) = ^{
        self.premiumTabDockView.selectedItem = selectedItem;
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView transitionWithView:self.premiumTabDockView
                          duration:0.22
                           options:UIViewAnimationOptionTransitionCrossDissolve |
                                   UIViewAnimationOptionBeginFromCurrentState |
                                   UIViewAnimationOptionAllowUserInteraction
                        animations:updates
                        completion:nil];
    } else {
        updates();
    }
}

- (void)pp_animatePremiumBottomNavigationEntranceIfNeeded
{
    if (self.premiumNavigationDidAnimateIn) {
        return;
    }
    self.premiumNavigationDidAnimateIn = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.premiumTabDockView.transform = CGAffineTransformIdentity;
        self.leadingTabButton.alpha = 1.0;
        self.leadingTabButton.transform = CGAffineTransformIdentity;
        self.premiumNovaButton.alpha = 1.0;
        self.premiumNovaButton.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.46
                          delay:0.03
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.premiumTabDockView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.40
                          delay:0.08
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.leadingTabButton.alpha = 1.0;
        self.leadingTabButton.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.42
                          delay:0.14
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.premiumNovaButton.alpha = 1.0;
        self.premiumNovaButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_premiumControlTouchDown:(UIButton *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:nil];
}

- (void)pp_premiumControlTouchUp:(UIButton *)sender
{
    if (sender == self.leadingTabButton || sender == self.premiumNovaButton) {
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.20
                              delay:0.0
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.30
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            sender.transform = CGAffineTransformIdentity;
        } completion:nil];
        return;
    }
    [self pp_applyPremiumTabSelectionAnimated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)pp_updatePremiumChatsBadgeWithCount:(NSInteger)count
{
    UITabBarItem *chatsItem = nil;
    for (UITabBarItem *item in self.premiumTabItems) {
        if (item.tag == PPRootTabIndexChats) {
            chatsItem = item;
            break;
        }
    }
    if (!chatsItem) {
        return;
    }
    chatsItem.badgeValue =
        count > 0 ? (count > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count]) : nil;
    if (@available(iOS 10.0, *)) {
        chatsItem.badgeColor = AppPrimaryClr ?: UIColor.systemTealColor;
    }
}

- (void)pp_setPremiumBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (PPIOS26()) {
        self.tabBar.hidden = YES;
        self.tabBar.alpha = 0.0;
    } else {
        self.tabBar.hidden = hidden;
        self.tabBar.alpha = hidden ? 0.0 : 1.0;
    }
    self.premiumBottomNavigationHidden = hidden;
    NSMutableArray<UIView *> *navigationViews = [NSMutableArray arrayWithCapacity:3];
    if (self.premiumTabDockView) {
        [navigationViews addObject:self.premiumTabDockView];
    }
    if (self.leadingTabButton) {
        [navigationViews addObject:self.leadingTabButton];
    }
    if (self.premiumNovaButton) {
        [navigationViews addObject:self.premiumNovaButton];
    }

    if (!hidden) {
        for (UIView *view in navigationViews) {
            view.hidden = NO;
        }
        self.premiumNovaButton.hidden = !self.premiumNovaVisibleByConfiguration;
    }
    void (^changes)(void) = ^{
        self.premiumTabDockView.alpha = 1.0;
        self.leadingTabButton.alpha = hidden ? 0.0 : 1.0;
        self.premiumNovaButton.alpha = hidden ? 0.0 : 1.0;
        if (!UIAccessibilityIsReduceMotionEnabled()) {
            self.premiumTabDockView.transform =
                hidden ? CGAffineTransformMakeTranslation(0.0, 10.0) : CGAffineTransformIdentity;
            self.leadingTabButton.transform =
                hidden ? CGAffineTransformMakeTranslation(0.0, 8.0) : CGAffineTransformIdentity;
            self.premiumNovaButton.transform =
                hidden ? CGAffineTransformMakeTranslation(0.0, 8.0) : CGAffineTransformIdentity;
        } else {
            self.premiumTabDockView.transform = CGAffineTransformIdentity;
            self.leadingTabButton.transform = CGAffineTransformIdentity;
            self.premiumNovaButton.transform = CGAffineTransformIdentity;
        }
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        for (UIView *view in navigationViews) {
            view.hidden = hidden;
        }
    };
    if (!animated) {
        changes();
        completion(YES);
        return;
    }
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}

- (void)addPlusTabBarButton {


    UIButton *showAddMenuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    showAddMenuButton.translatesAutoresizingMaskIntoConstraints = NO;
    showAddMenuButton.adjustsImageWhenHighlighted = NO;

    UIImageSymbolConfiguration *symbolConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:17
                                                     weight:UIImageSymbolWeightSemibold
                                                      scale:UIImageSymbolScaleLarge];

    UIImage *icon = [[UIImage systemImageNamed:@"plus" withConfiguration:symbolConfig]
                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration =
            [UIButtonConfiguration glassButtonConfiguration];
        configuration.image = icon;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.baseForegroundColor = accentColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(16.0, 16.0, 16.0, 16.0);
        showAddMenuButton.configuration = configuration;
    } else {
        [showAddMenuButton setImage:icon forState:UIControlStateNormal];
        showAddMenuButton.backgroundColor =
            [UIColor.systemBackgroundColor colorWithAlphaComponent:0.92];
        showAddMenuButton.tintColor = accentColor;
        showAddMenuButton.layer.borderWidth = 0.5;
        [showAddMenuButton pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.10]];
    }
    showAddMenuButton.layer.cornerRadius = 28.0;
    PPApplyContinuousCorners(showAddMenuButton, 28.0);
    [showAddMenuButton pp_setShadowColor:UIColor.blackColor];
    showAddMenuButton.layer.shadowOpacity = 0.06;
    showAddMenuButton.layer.shadowRadius = 16.0;
    showAddMenuButton.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    showAddMenuButton.layer.masksToBounds = NO;

    [showAddMenuButton addTarget:self action:@selector(presentBottomSheet) forControlEvents:UIControlEventTouchUpInside];
    [showAddMenuButton addTarget:self action:@selector(pp_premiumControlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [showAddMenuButton addTarget:self action:@selector(pp_premiumControlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    // ── Accessibility: Add new post button ──
    showAddMenuButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_add_new", @"Add new post");
    showAddMenuButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_add_new_hint", @"Create a new pet ad, accessory listing, or adoption post");
    showAddMenuButton.accessibilityTraits = UIAccessibilityTraitButton;

    [self.view addSubview:showAddMenuButton];
    self.leadingTabButton = showAddMenuButton;

    [NSLayoutConstraint activateConstraints:@[
        [showAddMenuButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [showAddMenuButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:2.0],
        [showAddMenuButton.widthAnchor constraintEqualToConstant:58.0],
        [showAddMenuButton.heightAnchor constraintEqualToConstant:58.0]
    ]];

    if (@available(iOS 17.0, *)) {
        __weak UIButton *weakButton = showAddMenuButton;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakButton.imageView addSymbolEffect:[[NSSymbolWiggleEffect wiggleForwardEffect] effectWithByLayer]
                                         options:[NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:3.0]]];
        });
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
