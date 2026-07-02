#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "PPUserSigningController.h"
#import "SplashViewController.h"
#import "PPRootTabBarController.h"
#import "PPCheckoutCoordinator.h"
@import FirebaseAuth;
@import GoogleSignIn;
#import "ChNotificationRouter.h"
#import "PPOrder.h"
#import "OrderDetailsViewController.h"
#import <Pure_Pets-Swift.h>


@interface SceneDelegate ()<UNUserNotificationCenterDelegate>
@property (nonatomic, strong) ChManager *cm;
@property (nonatomic, assign) BOOL didShowMainVC;
@property (nonatomic, strong) id authListenerHandle;
@property (nonatomic, strong) NSDictionary *pendingChatNotification;
@property (nonatomic, copy) NSString *activeUserScopedListenersUID;
@property (nonatomic, copy) NSString *pendingUserScopedListenersUID;

@end

@implementation SceneDelegate

- (void)pp_applyCurrentLanguageSemanticToWindow:(nullable UIWindow *)window
{
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    [UIView appearance].semanticContentAttribute = semantic;
    [UINavigationBar appearance].semanticContentAttribute = semantic;
    [UITabBar appearance].semanticContentAttribute = semantic;
    [UITableView appearance].semanticContentAttribute = semantic;
    [UICollectionView appearance].semanticContentAttribute = semantic;

    if (!window) {
        return;
    }

    window.semanticContentAttribute = semantic;
    window.rootViewController.view.semanticContentAttribute = semantic;
    [window setNeedsLayout];
    [window layoutIfNeeded];
}

- (NSInteger)pp_preservedSelectedTabIndexFromRootViewController:(nullable UIViewController *)rootViewController
{
    UIViewController *candidate = rootViewController;
    if ([candidate isKindOfClass:UINavigationController.class]) {
        candidate = ((UINavigationController *)candidate).viewControllers.firstObject;
    }

    if ([candidate isKindOfClass:PPRootTabBarController.class]) {
        return ((PPRootTabBarController *)candidate).selectedIndex;
    }

    return NSNotFound;
}

- (UIViewController *)pp_buildRootViewControllerForLanguageReloadFrom:(nullable UIViewController *)currentRootViewController
{
    PPRootTabBarController *rootViewController = [[PPRootTabBarController alloc] init];
    [rootViewController view];
    NSInteger selectedIndex = [self pp_preservedSelectedTabIndexFromRootViewController:currentRootViewController];
    if (selectedIndex != NSNotFound &&
        selectedIndex >= 0 &&
        selectedIndex < (NSInteger)rootViewController.viewControllers.count) {
        rootViewController.selectedIndex = selectedIndex;
    }

    rootViewController.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    return rootViewController;
}

- (void)pp_startUserScopedListenersIfPossible
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    NSString *uid = authUser.uid ?: @"";
    if (uid.length == 0) {
        NSLog(@"[SceneDelegate] No auth user; stopping user-scoped listeners.");
        [[AppDataListenerManager shared] stopAllListeners];
        [[ChManager sharedManager] stopListening];
        [[ChManager sharedManager] stopAllThreadMessageListeners];
        self.activeUserScopedListenersUID = nil;
        self.pendingUserScopedListenersUID = nil;
        return;
    }

    if ([self.activeUserScopedListenersUID isEqualToString:uid]) {
        return;
    }
    if ([self.pendingUserScopedListenersUID isEqualToString:uid]) {
        NSLog(@"[SceneDelegate] User-scoped listeners already pending for user: %@", uid);
        return;
    }
    self.pendingUserScopedListenersUID = uid;

    __weak typeof(self) weakSelf = self;
    [UserManager.sharedManager validateCurrentAuthSessionWithCompletion:^(NSError * _Nullable validationError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSString *latestUID = [FIRAuth auth].currentUser.uid ?: @"";
        if (![latestUID isEqualToString:uid]) {
            if ([self.pendingUserScopedListenersUID isEqualToString:uid]) {
                self.pendingUserScopedListenersUID = nil;
            }
            return;
        }

        if (validationError) {
            NSLog(@"[SceneDelegate] Auth session invalid. Stopping listeners: %@",
                  validationError.localizedDescription ?: @"unknown");
            [[AppDataListenerManager shared] stopAllListeners];
            [[ChManager sharedManager] stopListening];
            [[ChManager sharedManager] stopAllThreadMessageListeners];
            self.activeUserScopedListenersUID = nil;
            self.pendingUserScopedListenersUID = nil;
            return;
        }

        NSString *cachedUID = UserManager.sharedManager.currentUser.ID ?: @"";
        if (cachedUID.length > 0 && ![cachedUID isEqualToString:uid]) {
            NSLog(@"[SceneDelegate] UID mismatch during launch (auth=%@ cached=%@). Restoring session.", uid, cachedUID);
            [UserManager.sharedManager restoreSessionOnLaunchWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[SceneDelegate] Session restore error: %@", error.localizedDescription);
                    if ([self.pendingUserScopedListenersUID isEqualToString:uid]) {
                        self.pendingUserScopedListenersUID = nil;
                    }
                    return;
                }
                if ([self.pendingUserScopedListenersUID isEqualToString:uid]) {
                    self.pendingUserScopedListenersUID = nil;
                }
                [self pp_startUserScopedListenersIfPossible];
            }];
            return;
        }

        [[AppDataListenerManager shared] stopAllListeners];
        [[ChManager sharedManager] stopListening];
        [[ChManager sharedManager] stopAllThreadMessageListeners];

        [self startChatRealtimeListenersIfPossible];
        NSLog(@"👤 Starting app data listeners for user: %@", uid);
        [[AppDataListenerManager shared] startListenersForUser:uid];
        self.activeUserScopedListenersUID = uid;
        self.pendingUserScopedListenersUID = nil;
    }];
}

- (void)startChatRealtimeListenersIfPossible
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    NSString *resolvedUID = authUser.uid ?: @"";
    if (!resolvedUID.length) return;

    [[ChManager sharedManager] startGlobalUnreadListenerForUser:resolvedUID];
    [[ChManager sharedManager] startGlobalIncomingMessageListenerForUser:resolvedUID];
    [[ChManager sharedManager] syncPendingDeliveriesForUser:nil completion:^{
        
    }];
}


- (void)applySavedInterfaceStyleToWindow:(UIWindow *)window {
    [[PPThemeManager sharedManager] applySavedInterfaceStyleToWindow:window];
    
    NSLog(@"[AppDelegate] [Language languageVal] %ld",[Language languageVal]);
    if([Language languageVal] != 0 && [Language languageVal] != 1)
        [Language setLanguage:LanguageCode[1]];
    
    [self pp_applyCurrentLanguageSemanticToWindow:window];
    
}

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions
{
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    UNNotificationResponse *response =
            connectionOptions.notificationResponse;

        if (response) {
            self.pendingChatNotification =
                response.notification.request.content.userInfo;
        }
    
    [self setNavigationBarAppearance];
   
    
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[PPNovaMotionWindow alloc] initWithWindowScene:windowScene];
    UIColor *launchBackgroundColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    self.window.backgroundColor = launchBackgroundColor;
    [self applySavedInterfaceStyleToWindow:self.window];
    SplashViewController *splash = [SplashViewController new];
    splash.view.backgroundColor = launchBackgroundColor;
    splash.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.window.rootViewController = splash;
    [self pp_applyCurrentLanguageSemanticToWindow:self.window];
    [self.window makeKeyAndVisible];
    
    __weak typeof(self) weakSelf = self;
    self.authListenerHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth * _Nonnull auth, FIRUser * _Nullable user) {
        [weakSelf pp_startUserScopedListenersIfPossible];
    }];
    /*
     // ✅ Start chat if logged in
     FIRUser *authUser = [FIRAuth auth].currentUser;
     if (authUser) {
         self.cm = ChManager.sharedManager;
         [self.cm observeChatThreadsForUserID:authUser.uid completion:^(NSArray<ChatThreadModel *> *threads, NSError *error) {
             if (!error) [self.cm startListeningForThreadMessages:threads];
             
             NSString *uid = UserManager.sharedManager.currentUser.ID;

             [[AppDataListenerManager shared] startListenersForUser:uid];
         }];
     }
     
    
     
     */
    
}

- (void)tryHandlePendingChatNotification {

    if (!self.pendingChatNotification) return;
    if (!self.window.rootViewController) return;

    [self pp_handleNotificationTap:self.pendingChatNotification];
    self.pendingChatNotification = nil;
}
 


- (void)pp_handleNotificationTap:(NSDictionary *)userInfo {

    NSString *type = [[userInfo[@"type"] isKindOfClass:NSString.class] ? userInfo[@"type"] : @"" lowercaseString];
    NSString *threadID = userInfo[@"threadID"] ?: userInfo[@"threadId"];
    NSString *orderId = [userInfo[@"orderId"] isKindOfClass:NSString.class] ? userInfo[@"orderId"] : @"";

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        [ChManager sharedManager].isHandlingNotificationHandoff = YES;
        NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
        if (uid.length > 0) {
            [[ChManager sharedManager] syncPendingDeliveriesForUser:nil completion:nil];
        }
        UIViewController *topVC = [AppMgr topViewController];
        [[ChNotificationRouter shared] handleChatNotification:userInfo fromViewController:topVC];
        return;
    }

    if (orderId.length > 0 || [type hasPrefix:@"order"]) {
        if (orderId.length == 0) return;
        [ChManager sharedManager].isHandlingNotificationHandoff = YES;
        [self pp_navigateToOrderWithId:orderId];
        return;
    }
}

- (void)pp_navigateToOrderWithId:(NSString *)orderId {

    FIRDocumentReference *orderRef = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderId];
    __weak typeof(self) weakSelf = self;
    [orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !snapshot.exists) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order data is unavailable right now."];
                return;
            }

            PPOrder *order = [PPOrder orderFromSnapshot:snapshot];
            if (!order) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order data is unavailable right now."];
                return;
            }

            OrderDetailsViewController *detailsVC = [[OrderDetailsViewController alloc] initWithOrder:order];
            detailsVC.order = order;
            [strongSelf pp_pushOrderDetails:detailsVC];
        });
    }];
}

- (void)pp_pushOrderDetails:(UIViewController *)vc {

    UIWindow *window = self.window;
    UIViewController *root = window.rootViewController;
    UINavigationController *nav = nil;

    if ([root isKindOfClass:UINavigationController.class]) {
        nav = (UINavigationController *)root;
    } else {
        nav = root.navigationController;
    }

    if (nav) {
        [nav pushViewController:vc animated:YES];
    } else {
        UINavigationController *wrapper = [[UINavigationController alloc] initWithRootViewController:vc];
        wrapper.modalPresentationStyle = UIModalPresentationFullScreen;
        [root presentViewController:wrapper animated:YES completion:nil];
    }
}

- (void)setNavigationBarAppearance {
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground]; // 👈 makes nav bar fully transparent
    appearance.backgroundEffect = nil; // remove blur if you want totally clear
    appearance.backgroundColor = UIColor.clearColor;
    
    // Title style
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: GM.PrimaryTextColor,
        NSFontAttributeName: [GM boldFontWithSize:18]
    };
    [[UINavigationBar appearance] setBarTintColor:UIColor.clearColor]; // back button arrow color
    
    // Apply globally
    [[UINavigationBar appearance] setStandardAppearance:appearance];
    [[UINavigationBar appearance] setScrollEdgeAppearance:appearance];
    [[UINavigationBar appearance] setCompactAppearance:appearance];
    [[UINavigationBar appearance] setTintColor:GM.SecondaryTextColor];
    
    
    NSLog(@"mykey found");
 
    appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground]; // 👈 makes nav bar fully transparent
    appearance.backgroundEffect = nil; // remove blur if you want totally clear
    appearance.backgroundColor = UIColor.clearColor;
 
    // Title style
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: GM.PrimaryTextColor,
        NSFontAttributeName: [GM boldFontWithSize:18]
    };

    // Apply globally
    [[UINavigationBar appearance] setStandardAppearance:appearance];
    [[UINavigationBar appearance] setScrollEdgeAppearance:appearance];
    [[UINavigationBar appearance] setCompactAppearance:appearance];
    [[UINavigationBar appearance] setTintColor:GM.SecondaryTextColor]; // back button arrow color

    // 🔹 Hide back button title
    if (@available(iOS 14.0, *)) {
        UIBarButtonItemAppearance *backButtonAppearance = [[UIBarButtonItemAppearance alloc] init];
        backButtonAppearance.normal.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.clearColor};
        appearance.backButtonAppearance = backButtonAppearance;
    } else {
        [[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(-1000, 0)
                                                             forBarMetrics:UIBarMetricsDefault];
        
    }
    
    
 
}
- (void)loadMainAppAfterLogin {
    if (self.didShowMainVC) return;
    self.didShowMainVC = YES;
    /*
     
     NSLog(@"🎉 Loading Main App UI…");
     
     UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
     UINavigationController *rootNav =
 
     rootNav.navigationBar.prefersLargeTitles = NO;
     
     dispatch_async(dispatch_get_main_queue(), ^{
     self.window.rootViewController = rootNav;
     [self.window makeKeyAndVisible];
     });
     
     */
    
}



#pragma mark - Language

- (void)reloadRootViewControllerForLanguageChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = self.window ?: UIApplication.sharedApplication.windows.firstObject;
        if (!window) {
            return;
        }

        UIViewController *currentRootViewController = window.rootViewController;
        UIViewController *newRootViewController = [self pp_buildRootViewControllerForLanguageReloadFrom:currentRootViewController];
        [self pp_applyCurrentLanguageSemanticToWindow:window];

        [UIView transitionWithView:window
                          duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
            BOOL wereAnimationsEnabled = [UIView areAnimationsEnabled];
            [UIView setAnimationsEnabled:NO];
            window.rootViewController = newRootViewController;
            [self pp_applyCurrentLanguageSemanticToWindow:window];
            [window makeKeyAndVisible];
            [UIView setAnimationsEnabled:wereAnimationsEnabled];
        } completion:nil];
    });

 }

 

#pragma mark - Lifecycle
- (void)sceneDidBecomeActive:(UIScene *)scene { [self updateUserOnlineStatus:YES];    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
[self tryHandlePendingChatNotification];
[self pp_startUserScopedListenersIfPossible];

// H-08: Notify in-flight payment flows to re-check order status after app resume.
[[NSNotificationCenter defaultCenter] postNotificationName:PPAppDidBecomeActiveNotification object:nil];
}
- (void)sceneWillResignActive:(UIScene *)scene { [self updateUserOnlineStatus:NO]; }
- (void)sceneDidEnterBackground:(UIScene *)scene { [self updateUserOnlineStatus:NO]; }
- (void)sceneDidDisconnect:(UIScene *)scene {
    if (self.authListenerHandle) {
        [[FIRAuth auth] removeAuthStateDidChangeListener:self.authListenerHandle];
        self.authListenerHandle = nil;
    }
    [[AppDataListenerManager shared] stopAllListeners];
    [[ChManager sharedManager] stopListening];
    [[ChManager sharedManager] stopAllThreadMessageListeners];
    self.activeUserScopedListenersUID = nil;
    self.pendingUserScopedListenersUID = nil;
}

#pragma mark - Deep links
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    for (UIOpenURLContext *urlContext in URLContexts) {
        NSURL *url = urlContext.URL;
        if ([[FIRAuth auth] canHandleURL:url]) {
            continue;
        }
        if ([[url scheme] isEqualToString:@"purepets"]) {
            [[DeepLinkRouter shared] handleURL:url];
        }
        AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
        if ([appDelegate.currentAuthorizationFlow resumeExternalUserAgentFlowWithURL:url]) {
            appDelegate.currentAuthorizationFlow = nil;
        } else {
            [GIDSignIn.sharedInstance handleURL:url];
        }
    }
}

#pragma mark - Firestore User Status
- (void)updateUserOnlineStatus:(BOOL)isOnline {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) return;
    if (!authUser.uid.length) {
        NSLog(@"[SceneDelegate] Skipping: missing UID for documentWithPath:");
        return;
    }
    
    FIRDocumentReference *userRef = [[[FIRFirestore firestore] collectionWithPath:@"UserPresence"]
                                     documentWithPath:authUser.uid];
    NSMutableDictionary *data = [@{
        @"uid": authUser.uid,
        @"online": @(isOnline),
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } mutableCopy];
    if (!isOnline) data[@"lastSeen"] = [FIRFieldValue fieldValueForServerTimestamp];
    
    [userRef setData:data merge:YES completion:^(NSError * _Nullable error) {
        if (error) NSLog(@"[SceneDelegate] User status update failed: %@", error.localizedDescription);
    }];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {

    NSDictionary *userInfo =
        response.notification.request.content.userInfo;

    [self pp_handleNotificationTap:userInfo];

    completionHandler();
}

@end
