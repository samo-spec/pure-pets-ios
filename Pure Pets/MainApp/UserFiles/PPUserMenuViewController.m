//
//  PPUserMenuViewController.m
//  Pure Pets
//
//  Reinvented for PurePets Category-Defining iOS & iPadOS Architecture.
//

#import "PPUserMenuViewController.h"
#import "ProfileVC.h"
#import "SettingVC.h"
#import "CartViewController.h"
#import "OrderHistoryViewController.h"
#import "PurchasedItemsViewController.h"
#import "MyItemsViewController.h"
#import "CompanyLocationVC.h"
#import "LeaveFeedbackViewController.h"
#import "MainController.h"
#import "PPUserSigningManager.h"
#import "Language.h"
#import "PPHUD.h"
#import "Styling.h"
#import "CitiesManager.h"
#import "UserManager.h"
#import <UserNotifications/UserNotifications.h>
#import <Pure_Pets-Swift.h>

@interface PPUserMenuViewController () <PPUserMenuHostingDelegate>
@property (nonatomic, strong) PPUserMenuHostingController *hostingController;
@property (nonatomic, strong) PPPureLensHostPresenter *pureLensPresenter;
@property (nonatomic, assign) BOOL didCaptureNavigationBarHiddenState;
@property (nonatomic, assign) BOOL previousNavigationBarHiddenState;
@end

@implementation PPUserMenuViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    
    self.navigationItem.title = nil;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:nil showBack:NO];
    
    self.pureLensPresenter = [PPPureLensHostPresenter new];

    // Embed Category-Defining SwiftUI Host Controller
    self.hostingController = [PPUserMenuHostingController new];
    self.hostingController.delegate = self;
    
    [self addChildViewController:self.hostingController];
    self.hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hostingController.view];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self.hostingController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_applyMenuNavigationChromeAnimated:animated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.hostingController refreshState];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_restoreMenuNavigationChromeIfNeededAnimated:animated];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    [self.hostingController refreshState];
}

#pragma mark - Navigation Chrome

- (BOOL)pp_isPresentedAsRootTab
{
    return self.tabBarController != nil &&
           self.navigationController != nil &&
           self.navigationController.viewControllers.firstObject == self;
}

- (void)pp_applyMenuNavigationChromeAnimated:(BOOL)animated
{
    self.navigationItem.title = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItems = nil;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:nil showBack:NO];

    if (![self pp_isPresentedAsRootTab]) {
        return;
    }

    if (!self.didCaptureNavigationBarHiddenState) {
        self.previousNavigationBarHiddenState = self.navigationController.navigationBarHidden;
        self.didCaptureNavigationBarHiddenState = YES;
    }
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)pp_restoreMenuNavigationChromeIfNeededAnimated:(BOOL)animated
{
    if (!self.didCaptureNavigationBarHiddenState || !self.navigationController) {
        return;
    }

    [self.navigationController setNavigationBarHidden:self.previousNavigationBarHiddenState animated:animated];
    self.didCaptureNavigationBarHiddenState = NO;
}

#pragma mark - PPUserMenuHostingDelegate

- (void)userMenuDidSelectAction:(PPUserMenuActionType)action
{
    switch (action) {
        case PPUserMenuActionTypeProfile: {
            if (![PPFunc PPUserCheck]) return;
            ProfileVC *vc = [ProfileVC new];
            vc.view.layer.cornerRadius = 42.0;
            vc.view.backgroundColor = AppBackgroundClr;
            vc.view.clipsToBounds = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeLogin:
            [self pp_presentLogin];
            break;
        case PPUserMenuActionTypeFavorites: {
            if (![PPFunc PPUserCheck]) return;
            MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeMyAds: {
            if (![PPFunc PPUserCheck]) return;
            MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeMyAds];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeCart: {
            if (![PPFunc PPUserCheck]) return;
            CartViewController *vc = [CartViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypePurchased: {
            if (![PPFunc PPUserCheck]) return;
            PurchasedItemsViewController *vc = [PurchasedItemsViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeOrders: {
            if (![PPFunc PPUserCheck]) return;
            OrderHistoryViewController *vc = [OrderHistoryViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeProduction: {
            if (![PPFunc PPUserCheck]) return;
            MainController *vc = [MainController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeSettings: {
            SettingVC *vc = [SettingVC new];
            vc.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeSupport: {
            CompanyLocationVC *vc = [CompanyLocationVC new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionTypeLogout:
            [self pp_presentLogoutFlow];
            break;
        case PPUserMenuActionTypePureLens:
            [self.pureLensPresenter presentFromViewController:self];
            break;
        case PPUserMenuActionTypeToggleAppearance: {
            UIUserInterfaceStyle currentTheme = [[PPThemeManager sharedManager] loadUserInterfaceStyle];
            UIUserInterfaceStyle visualStyle = self.traitCollection.userInterfaceStyle;
            UIUserInterfaceStyle nextStyle;
            NSString *toastKey;
            if (visualStyle == UIUserInterfaceStyleDark) {
                nextStyle = UIUserInterfaceStyleLight;
                toastKey = @"quick_access_light_mode_toast";
            } else if (currentTheme == UIUserInterfaceStyleLight) {
                nextStyle = UIUserInterfaceStyleUnspecified;
                toastKey = @"settings_theme_system_active";
            } else {
                nextStyle = UIUserInterfaceStyleDark;
                toastKey = @"quick_access_dark_mode_toast";
            }
            [[PPThemeManager sharedManager] saveUserInterfaceStyle:nextStyle];
            [[PPThemeManager sharedManager] applyInterfaceStyleGlobally:nextStyle];
            [PPFunc triggerLightHaptic];
            [PPHUD showSuccess:kLang(toastKey)];
            [self.hostingController refreshState];
            break;
        }
        case PPUserMenuActionTypeSwitchLanguage: {
            NSInteger currentLanguage = [Language languageVal];
            if (currentLanguage == 1) {
                [Language userSelectedLanguage:@"en"];
            } else {
                [Language userSelectedLanguage:@"ar"];
            }
            [PPFunc triggerLightHaptic];
            [self.hostingController refreshState];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [PPHUD showSuccess:kLang(currentLanguage == 1 ? @"quick_access_lang_en_toast" : @"quick_access_lang_ar_toast")];
            });
            break;
        }
        case PPUserMenuActionTypeRequestNotifications: {
            [PPFunc triggerLightHaptic];
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        [[UIApplication sharedApplication] registerForRemoteNotifications];
                        [PPHUD showSuccess:kLang(@"Allow Alerts")];
                    } else {
                        [PPHUD showInfo:kLang(@"quick_access_notifications_toast")];
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    }
                    [self.hostingController refreshState];
                });
            }];
            break;
        }
        case PPUserMenuActionTypeRequestLocation: {
            [PPFunc triggerLightHaptic];
            [PPHUD showInfo:kLang(@"quick_access_location_toast")];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
            break;
        }
    }
}

- (void)pp_presentLogin
{
    [PPUserSigningManager presentSignInFrom:self
                            withCountryCode:CitiesManager.shared.CurrentCountry.countryCode
                          presentationStyle:PPSignInPresentationStyleSheet
                       autoDismissOnSuccess:YES
                                     success:^(UserModel *user) {
        [PPFunc reloadAppUI];
        [[AppDataListenerManager shared] stopAllListeners];
        [[AppDataListenerManager shared] startListenersForUser:PPCurrentUser.ID];
        [self.hostingController refreshState];
    } failure:nil cancelled:nil];
}

- (void)pp_presentLogoutFlow
{
    if (!PPIsUserLoggedIn) {
        [self pp_presentLogin];
        return;
    }
    LeaveFeedbackViewController *feedbackVC = [[LeaveFeedbackViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    feedbackVC.onLogout = ^{
        [GM clearUserProfileDefaults];
        [PPFunc reloadAppUI];
        [weakSelf.hostingController refreshState];
    };
    [PPFunc presentSheetFrom:self sheetVC:feedbackVC detentStyle:PPSheetDetentStyle70];
}

@end
