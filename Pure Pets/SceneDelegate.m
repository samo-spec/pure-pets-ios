#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "PPUserSigningController.h"
#import "SplashViewController.h"
#import "PPCheckoutCoordinator.h"
@import GoogleSignIn;
#import "ChNotificationRouter.h"


@interface SceneDelegate ()<UNUserNotificationCenterDelegate>
@property (nonatomic, strong) ChManager *cm;
@property (nonatomic, assign) BOOL didShowMainVC;
@property (nonatomic, strong) id authListenerHandle;
@property (nonatomic, strong) NSDictionary *pendingChatNotification;
@property (nonatomic, copy) NSString *activeUserScopedListenersUID;

@end

@implementation SceneDelegate

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
        return;
    }

    if ([self.activeUserScopedListenersUID isEqualToString:uid]) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [UserManager.sharedManager validateCurrentAuthSessionWithCompletion:^(NSError * _Nullable validationError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSString *latestUID = [FIRAuth auth].currentUser.uid ?: @"";
        if (![latestUID isEqualToString:uid]) {
            return;
        }

        if (validationError) {
            NSLog(@"[SceneDelegate] Auth session invalid. Stopping listeners: %@",
                  validationError.localizedDescription ?: @"unknown");
            [[AppDataListenerManager shared] stopAllListeners];
            [[ChManager sharedManager] stopListening];
            [[ChManager sharedManager] stopAllThreadMessageListeners];
            self.activeUserScopedListenersUID = nil;
            return;
        }

        NSString *cachedUID = UserManager.sharedManager.currentUser.ID ?: @"";
        if (cachedUID.length > 0 && ![cachedUID isEqualToString:uid]) {
            NSLog(@"[SceneDelegate] UID mismatch during launch (auth=%@ cached=%@). Restoring session.", uid, cachedUID);
            [UserManager.sharedManager restoreSessionOnLaunchWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[SceneDelegate] Session restore error: %@", error.localizedDescription);
                    return;
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
    SettingVC *vc = [[SettingVC alloc]init];
    UIUserInterfaceStyle savedStyle = [vc loadUserInterfaceStyle];
    if (savedStyle != UIUserInterfaceStyleUnspecified) {
        window.overrideUserInterfaceStyle = savedStyle;
    }
    
    NSLog(@"[AppDelegate] [Language languageVal] %ld",[Language languageVal]);
    if([Language languageVal] != 0 && [Language languageVal] != 1)
        [Language userSelectedLanguage:LanguageCode[1]];
    
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
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    [self applySavedInterfaceStyleToWindow:self.window];
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    SplashViewController *splash = [SplashViewController new];
    self.window.rootViewController = splash;
    [self.window makeKeyAndVisible];
    
    __weak typeof(self) weakSelf = self;
    self.authListenerHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth * _Nonnull auth, FIRUser * _Nullable user) {
        [weakSelf pp_startUserScopedListenersIfPossible];
    }];
    [self pp_startUserScopedListenersIfPossible];
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

    UIViewController *topVC =
    [AppMgr topViewController];

    [[ChNotificationRouter shared]
        handleChatNotification:self.pendingChatNotification
          fromViewController:topVC];

    self.pendingChatNotification = nil;
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
    
    [[UINavigationBar appearance] setSemanticContentAttribute:Language.semanticAttributeForCurrentLanguage];
    [[UIView appearance] setSemanticContentAttribute:Language.semanticAttributeForCurrentLanguage];
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
UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
[UIView appearance].semanticContentAttribute = attr;
self.window.semanticContentAttribute = attr;

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
}

#pragma mark - Deep links
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    for (UIOpenURLContext *urlContext in URLContexts) {
        NSURL *url = urlContext.URL;
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

    UIViewController *topVC = [AppMgr topViewController];
    
    // 🔑 Mark handoff
    [ChManager sharedManager].isHandlingNotificationHandoff = YES;

    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length > 0) {
        [[ChManager sharedManager] syncPendingDeliveriesForUser:nil completion:nil];
    }

     
        [[ChNotificationRouter shared]
            handleChatNotification:userInfo
              fromViewController:topVC];
 
    completionHandler();
}

@end
