#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "PPUserSigningController.h"
#import "SplashViewController.h"
#import "PPRootTabBarController.h"
#import "PPCheckoutCoordinator.h"
#import "DeepLinkRouter.h"
#import "PPOverlayCoordinator.h"
@import FirebaseAuth;
@import GoogleSignIn;
#import "ChNotificationRouter.h"
#import "PPOrder.h"
#import "PPOrderDetailsRouter.h"
#import <Pure_Pets-Swift.h>


@interface SceneDelegate ()
@property (nonatomic, strong) ChManager *cm;
@property (nonatomic, assign) BOOL didShowMainVC;
@property (nonatomic, strong) id authListenerHandle;
@property (nonatomic, strong) NSDictionary *pendingChatNotification;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *handledNotificationIDs;
@property (nonatomic, copy) NSString *activeUserScopedListenersUID;
@property (nonatomic, copy) NSString *pendingUserScopedListenersUID;

@end

static NSString *PPSceneTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPSceneScalarString(id value)
{
    NSString *stringValue = PPSceneTrimmedString(value);
    if (stringValue.length > 0) return stringValue;

    if ([value isKindOfClass:NSNumber.class]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.minimumFractionDigits = 0;
        formatter.maximumFractionDigits = 2;
        return [formatter stringFromNumber:(NSNumber *)value] ?: [(NSNumber *)value stringValue];
    }

    return @"";
}

static NSDictionary *PPSceneSafeDictionary(id value)
{
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPSceneFirstScalarForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    NSDictionary *safeSource = PPSceneSafeDictionary(source);
    for (NSString *key in keys) {
        NSString *value = PPSceneScalarString(safeSource[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPSceneOrderIDFromPayload(NSDictionary *payload)
{
    NSDictionary *safePayload = PPSceneSafeDictionary(payload);
    NSDictionary *meta = PPSceneSafeDictionary(safePayload[@"meta"]);
    NSArray<NSString *> *keys = @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"];
    NSString *orderID = PPSceneFirstScalarForKeys(safePayload, keys);
    if (orderID.length == 0) {
        orderID = PPSceneFirstScalarForKeys(meta, keys);
    }
    return orderID;
}

static NSString *PPSceneNotificationIDFromPayload(NSDictionary *payload)
{
    NSDictionary *safePayload = PPSceneSafeDictionary(payload);
    NSDictionary *meta = PPSceneSafeDictionary(safePayload[@"meta"]);
    NSString *notificationID = PPSceneFirstScalarForKeys(safePayload, @[@"notificationId"]);
    return notificationID.length > 0
        ? notificationID
        : PPSceneFirstScalarForKeys(meta, @[@"notificationId"]);
}

@implementation SceneDelegate

- (BOOL)pp_consumeNotificationIdentityForPayload:(NSDictionary *)payload
{
    NSString *notificationID = PPSceneNotificationIDFromPayload(payload);
    if (notificationID.length == 0) return YES;
    if (!self.handledNotificationIDs) {
        self.handledNotificationIDs = [NSMutableOrderedSet orderedSet];
    }
    if ([self.handledNotificationIDs containsObject:notificationID]) {
        return NO;
    }
    [self.handledNotificationIDs addObject:notificationID];
    while (self.handledNotificationIDs.count > 128) {
        [self.handledNotificationIDs removeObjectAtIndex:0];
    }
    return YES;
}

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
    UNNotificationResponse *response =
            connectionOptions.notificationResponse;

        if (response) {
            NSDictionary *payload = response.notification.request.content.userInfo;
            if ([AppDelegate pp_isNotificationPayloadRoutable:payload] &&
                [self pp_consumeNotificationIdentityForPayload:payload]) {
                self.pendingChatNotification = payload;
            }
        }

    [self setNavigationBarAppearance];
   

    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[PPNovaMotionWindow alloc] initWithWindowScene:windowScene];
    UIColor *launchBackgroundColor = [UIColor colorNamed:@"AppForegroundColor"] ?:
        AppForgroundColr ?: UIColor.systemBackgroundColor;
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
    if (!self.window.rootViewController ||
        [self.window.rootViewController isKindOfClass:SplashViewController.class]) return;

    NSDictionary *pendingNotification = self.pendingChatNotification;
    self.pendingChatNotification = nil;
    [self pp_handleNotificationTap:pendingNotification];
}

- (void)handleRemoteNotificationUserInfo:(NSDictionary *)userInfo {
    NSDictionary *safeUserInfo = PPSceneSafeDictionary(userInfo);
    if (![AppDelegate pp_isNotificationPayloadRoutable:safeUserInfo]) return;
    if (![self pp_consumeNotificationIdentityForPayload:safeUserInfo]) return;
    if (!self.window.rootViewController ||
        [self.window.rootViewController isKindOfClass:SplashViewController.class] ||
        self.window.windowScene.activationState == UISceneActivationStateUnattached) {
        self.pendingChatNotification = safeUserInfo;
        NSLog(@"PPLAB Scene notification tap deferred | rootReady=%@ splashActive=%@",
              self.window.rootViewController ? @"yes" : @"no",
              [self.window.rootViewController isKindOfClass:SplashViewController.class] ? @"yes" : @"no");
        return;
    }
    [self pp_handleNotificationTap:safeUserInfo];
}

- (void)notificationRoutingRootDidBecomeReady {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self notificationRoutingRootDidBecomeReady];
        });
        return;
    }
    NSLog(@"PPLAB Scene notification routing root ready | hasPending=%@",
          self.pendingChatNotification ? @"yes" : @"no");
    [self tryHandlePendingChatNotification];
}
 


- (void)pp_handleNotificationTap:(NSDictionary *)userInfo {

    NSDictionary *safeUserInfo = PPSceneSafeDictionary(userInfo);
    if (![AppDelegate pp_isNotificationPayloadRoutable:safeUserInfo]) return;

    NSDictionary *meta = [safeUserInfo[@"meta"] isKindOfClass:NSDictionary.class] ? safeUserInfo[@"meta"] : @{};
    NSString *type = [[PPSceneFirstScalarForKeys(safeUserInfo, @[@"notificationType", @"eventType", @"type"]) lowercaseString] copy];
    if (type.length == 0) {
        type = [[PPSceneFirstScalarForKeys(meta, @[@"notificationType", @"eventType", @"type"]) lowercaseString] copy];
    }

    NSString *threadID = PPSceneFirstScalarForKeys(safeUserInfo, @[@"threadID", @"threadId", @"conversationId", @"chatId", @"chatID", @"contextId"]);
    if (threadID.length == 0) {
        threadID = PPSceneFirstScalarForKeys(meta, @[@"threadID", @"threadId", @"conversationId", @"chatId", @"chatID", @"contextId"]);
    }

    NSString *orderId = PPSceneOrderIDFromPayload(safeUserInfo);
    NSString *route = [[PPSceneFirstScalarForKeys(safeUserInfo, @[@"route"]) lowercaseString] copy];
    if (route.length == 0) {
        route = [[PPSceneFirstScalarForKeys(meta, @[@"route"]) lowercaseString] copy];
    }

    NSString *petAdId = PPSceneFirstScalarForKeys(safeUserInfo, @[@"petAdId", @"petAdID", @"adId", @"adID", @"pet_ad_id"]);
    if (petAdId.length == 0) {
        petAdId = PPSceneFirstScalarForKeys(meta, @[@"petAdId", @"petAdID", @"adId", @"adID", @"pet_ad_id"]);
    }

    NSString *accessoryId = PPSceneFirstScalarForKeys(safeUserInfo, @[@"accessoryId", @"accessoryID", @"accessory_id"]);
    if (accessoryId.length == 0) {
        accessoryId = PPSceneFirstScalarForKeys(meta, @[@"accessoryId", @"accessoryID", @"accessory_id"]);
    }

    NSLog(@"PPLAB Scene notification tap start | type=%@ route=%@ orderId=%@ threadID=%@ petAdId=%@ accessoryId=%@",
          type ?: @"",
          route ?: @"",
          orderId ?: @"",
          threadID ?: @"",
          petAdId ?: @"",
          accessoryId ?: @"");

    if (threadID.length > 0 || [type isEqualToString:@"chat"] || [type containsString:@"chat"] || [route isEqualToString:@"chat"]) {
        [ChManager sharedManager].isHandlingNotificationHandoff = YES;
        NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
        if (uid.length > 0) {
            [[ChManager sharedManager] syncPendingDeliveriesForUser:nil completion:nil];
        }
        UIViewController *root = self.window.rootViewController ?: UIApplication.sharedApplication.keyWindow.rootViewController;
        UIViewController *topVC = [AppMgr topViewController] ?: root;
        [[ChNotificationRouter shared] handleChatNotification:userInfo fromViewController:topVC];
        return;
    }

    if (orderId.length > 0 ||
        [type hasPrefix:@"order"] ||
        [type containsString:@"order"] ||
        [type containsString:@"payment"] ||
        [route isEqualToString:@"orders"] ||
        [route isEqualToString:@"order"] ||
        [route isEqualToString:@"order_details"] ||
        [route isEqualToString:@"payments_order"]) {
        if (orderId.length > 0) {
            [ChManager sharedManager].isHandlingNotificationHandoff = YES;
            [self pp_navigateToOrderWithId:orderId];
            return;
        }
    }

    if (petAdId.length > 0 || [route isEqualToString:@"petad"] || [route isEqualToString:@"pet_ad"]) {
        if (petAdId.length > 0) {
            [[DeepLinkRouter shared] navigateToPetAdWithID:petAdId];
            return;
        }
    }

    if (accessoryId.length > 0 || [route isEqualToString:@"accessory"]) {
        if (accessoryId.length > 0) {
            [[DeepLinkRouter shared] navigateToAccessoryWithID:accessoryId];
            return;
        }
    }

    // Default: switch to Chats & Notifications tab
    UIViewController *root = self.window.rootViewController ?: UIApplication.sharedApplication.keyWindow.rootViewController;
    if ([root isKindOfClass:PPRootTabBarController.class]) {
        PPRootTabBarController *tabBar = (PPRootTabBarController *)root;
        if (![tabBar pp_openNotificationsInboxAnimated:YES]) {
            NSLog(@"PPLAB Scene notification route failed | route=%@", route ?: @"");
        }
    }
}

- (void)pp_navigateToOrderWithId:(NSString *)orderId {
    if (orderId.length == 0) return;

    FIRDocumentReference *orderRef = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderId];
    __weak typeof(self) weakSelf = self;
    [orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !snapshot.exists) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order")];
                return;
            }

            NSString *authenticatedUID = PPSceneTrimmedString([FIRAuth auth].currentUser.uid);
            if (authenticatedUID.length == 0) {
                authenticatedUID = PPSceneTrimmedString(UserManager.sharedManager.currentUser.ID);
            }
            NSDictionary *data = PPSceneSafeDictionary(snapshot.data);
            NSString *orderOwnerUID = PPSceneFirstScalarForKeys(data, @[@"userId", @"uid", @"ownerUid", @"ownerUID", @"customerId", @"customerUid", @"customerUID", @"buyerUid", @"user_id"]);
            if (authenticatedUID.length == 0 ||
                (orderOwnerUID.length > 0 && ![orderOwnerUID isEqualToString:authenticatedUID])) {
                NSLog(@"PPLAB Scene order route rejected | orderId=%@ hasAuth=%@ ownerMatch=no",
                      PPSceneTrimmedString(orderId),
                      authenticatedUID.length > 0 ? @"yes" : @"no");
                [PPHUD showError:kLang(@"order_support_unavailable_no_order")];
                return;
            }

            PPOrder *order = [PPOrder orderFromSnapshot:snapshot];
            if (!order) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order")];
                return;
            }

            UIViewController *detailsVC = [PPOrderDetailsRouter controllerWithOrder:order];
            [strongSelf pp_pushOrderDetails:detailsVC];
        });
    }];
}

- (void)pp_pushOrderDetails:(UIViewController *)vc {
    if (!vc) return;
    UIWindow *window = self.window ?: UIApplication.sharedApplication.keyWindow;
    UIViewController *root = window.rootViewController;
    if (!root) return;

    UIViewController *presenter = [PPOverlayCoordinator pp_resolvedPresenterFrom:root] ?: root;

    if ([presenter isKindOfClass:UINavigationController.class]) {
        [(UINavigationController *)presenter pushViewController:vc animated:YES];
    } else if (presenter.navigationController) {
        [presenter.navigationController pushViewController:vc animated:YES];
    } else {
        PPNavigationController *wrapper = [[PPNavigationController alloc] initWithRootViewController:vc];
        wrapper.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:wrapper animated:YES completion:nil];
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
        if ([currentRootViewController isKindOfClass:[PPRootTabBarController class]]) {
            PPRootTabBarController *rootTab = (PPRootTabBarController *)currentRootViewController;
            if (rootTab.swiftCoordinator) {
                [rootTab.swiftCoordinator stop];
                rootTab.swiftCoordinator = nil;
            }
        }
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

@end
