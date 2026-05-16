#import "AppDelegate.h"
#import "PPImageLoaderManager.h"
#import "XLFormRowFullWidthTextFieldCell.h"
#import <TargetConditionals.h>
#import "PPPaymentManager.h"
#import "PPFirestoreErrorNotifier.h"
#import "PPOfflineBannerView.h"
#if __has_include(<FirebaseAppCheck/FirebaseAppCheck.h>)
@import FirebaseAppCheck;
#define PP_HAS_FIREBASE_APPCHECK 1
#else
#define PP_HAS_FIREBASE_APPCHECK 0
#endif

@import FirebaseAnalytics;
@import FirebaseCrashlytics;
@import GoogleSignIn;
@interface AppDelegate ()

@end

#if PP_HAS_FIREBASE_APPCHECK
static void PPFetchAppCheckTokenFromProvider(id<FIRAppCheckProvider> provider,
                                             BOOL limitedUse,
                                             void (^handler)(FIRAppCheckToken * _Nullable, NSError * _Nullable)) {
    if (!provider) {
        if (handler) {
            handler(nil, [NSError errorWithDomain:@"PPAppCheckError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing provider"}]);
        }
        return;
    }
    if (limitedUse && [provider respondsToSelector:@selector(getLimitedUseTokenWithCompletion:)]) {
        [provider getLimitedUseTokenWithCompletion:handler];
    } else {
        [provider getTokenWithCompletion:handler];
    }
}

static BOOL PPAppCheckErrorLooksLikeAppAttestFailure(NSError *error) {
    if (!error) return NO;
    NSString *domain = error.domain ?: @"";
    if ([domain containsString:@"AppCheck"] || [domain containsString:@"AppAttest"]) {
        return YES;
    }
    return NO;
}

@interface PPResilientAppCheckProvider : NSObject <FIRAppCheckProvider>
- (instancetype)initWithAppAttestProvider:(id<FIRAppCheckProvider>)appAttestProvider
                      deviceCheckProvider:(id<FIRAppCheckProvider>)deviceCheckProvider;
@end

@interface PPResilientAppCheckProvider ()
@property (nonatomic, strong, nullable) id<FIRAppCheckProvider> appAttestProvider;
@property (nonatomic, strong, nullable) id<FIRAppCheckProvider> deviceCheckProvider;
@property (atomic, assign) BOOL usingDeviceCheckFallback;
@end

@implementation PPResilientAppCheckProvider

- (instancetype)initWithAppAttestProvider:(id<FIRAppCheckProvider>)appAttestProvider
                      deviceCheckProvider:(id<FIRAppCheckProvider>)deviceCheckProvider {
    self = [super init];
    if (self) {
        _appAttestProvider = appAttestProvider;
        _deviceCheckProvider = deviceCheckProvider;
        _usingDeviceCheckFallback = NO;
    }
    return self;
}

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken * _Nullable, NSError * _Nullable))handler {
    [self pp_getTokenLimitedUse:NO completion:handler];
}

- (void)getLimitedUseTokenWithCompletion:(void (^)(FIRAppCheckToken * _Nullable, NSError * _Nullable))handler {
    [self pp_getTokenLimitedUse:YES completion:handler];
}

- (void)pp_getTokenLimitedUse:(BOOL)limitedUse completion:(void (^)(FIRAppCheckToken * _Nullable, NSError * _Nullable))handler {
    id<FIRAppCheckProvider> deviceCheckProvider = self.deviceCheckProvider;
    if (self.usingDeviceCheckFallback || !self.appAttestProvider) {
        PPFetchAppCheckTokenFromProvider(deviceCheckProvider, limitedUse, handler);
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPFetchAppCheckTokenFromProvider(self.appAttestProvider, limitedUse, ^(FIRAppCheckToken * _Nullable token, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            if (handler) {
                handler(token, error);
            }
            return;
        }

        if (!error || !PPAppCheckErrorLooksLikeAppAttestFailure(error)) {
            if (handler) {
                handler(token, error);
            }
            return;
        }

        self.usingDeviceCheckFallback = YES;
        NSLog(@"[AppCheck] App Attest failed for Pure Pets IOS. Falling back to DeviceCheck for this launch. Error: %@",
              error.localizedDescription ?: @"unknown error");
        PPFetchAppCheckTokenFromProvider(deviceCheckProvider, limitedUse, ^(FIRAppCheckToken * _Nullable fallbackToken, NSError * _Nullable fallbackError) {
            if (fallbackToken || !fallbackError) {
                if (handler) {
                    handler(fallbackToken, nil);
                }
                return;
            }

            if (handler) {
                handler(nil, fallbackError ?: error);
            }
        });
    });
}

@end

@interface PPAppCheckProviderFactory : NSObject <FIRAppCheckProviderFactory>
@end

@implementation PPAppCheckProviderFactory

- (id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app
{
#if TARGET_OS_SIMULATOR
    return [[FIRAppCheckDebugProvider alloc] initWithApp:app];
#else
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSDictionary<NSString *, NSString *> *env = processInfo.environment ?: @{};
    NSString *forceEnv = env[@"PP_FORCE_APPCHECK_DEBUG_PROVIDER"];
    NSString *debugTokenEnv = env[@"FIRAAppCheckDebugToken"];
    BOOL forceFromEnv = [forceEnv isKindOfClass:[NSString class]] && [@[@"1", @"true", @"yes"] containsObject:[forceEnv lowercaseString]];
    BOOL hasDebugTokenEnv = [debugTokenEnv isKindOfClass:NSString.class] && debugTokenEnv.length > 0;
    
    if (forceFromEnv || hasDebugTokenEnv) {
        NSLog(@"[AppCheck] Using Debug provider for Pure Pets IOS.");
        return [[FIRAppCheckDebugProvider alloc] initWithApp:app];
    }
    
    if (@available(iOS 14.0, *)) {
        id<FIRAppCheckProvider> attestProvider = [[FIRAppAttestProvider alloc] initWithApp:app];
        if (attestProvider) {
            id<FIRAppCheckProvider> deviceCheckProvider = [[FIRDeviceCheckProvider alloc] initWithApp:app];
            if (deviceCheckProvider) {
                NSLog(@"[AppCheck] Using App Attest provider with DeviceCheck fallback.");
                return [[PPResilientAppCheckProvider alloc] initWithAppAttestProvider:attestProvider
                                                                   deviceCheckProvider:deviceCheckProvider];
            }
            NSLog(@"[AppCheck] Using App Attest provider.");
            return attestProvider;
        }
    }

    NSLog(@"[AppCheck] Using DeviceCheck provider (fallback).");
    return [[FIRDeviceCheckProvider alloc] initWithApp:app];
#endif
}

@end
#endif



@implementation AppDelegate



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[AppDelegate] didFinishLaunchingWithOptions (keys=%lu)", (unsigned long)(launchOptions.allKeys.count));
 
    //if(!PPIOS26()) {[self showUnsupportedVersionAlert];};
    [SDImageCache sharedImageCache].config.shouldUseWeakMemoryCache = NO;
    [SDImageCache sharedImageCache].config.maxDiskSize = 300 * 1024 * 1024; // 300 MB
    [SDImageCache sharedImageCache].config.maxMemoryCost = 200 * 1024 * 1024; // 200 MB
    [SDImageCache sharedImageCache].config.shouldRemoveExpiredDataWhenEnterBackground = YES;
    [SDImageCache sharedImageCache].config.shouldRemoveExpiredDataWhenTerminate = YES;

    NSString *lang = [Language currentLanguageCode];
    [Language setLanguage:lang];

    
    [[NSUserDefaults standardUserDefaults] setObject:@[lang] forKey:@"AppleLanguages"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    

    [[UINavigationBar appearance] setBarTintColor:UIColor.clearColor];
 

    [[UINavigationBar appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: AppPrimaryTextClr ?: UIColor.labelColor,
        NSFontAttributeName: [GM boldFontWithSize:18]
    }];
    
    
    [UITableView appearance].tintColor = AppPrimaryClr;
 
    UITabBarItem *itemAppearance = [UITabBarItem appearance];
    [itemAppearance setTitleTextAttributes:@{
        NSFontAttributeName: [GM fontWithSize:12],
        NSForegroundColorAttributeName: [AppSecondaryTextClr colorWithAlphaComponent:0.82] ?: UIColor.secondaryLabelColor
    } forState:UIControlStateNormal];

    [itemAppearance setTitleTextAttributes:@{
        NSFontAttributeName: [GM boldFontWithSize:12],
        NSForegroundColorAttributeName: AppPrimaryTextClr ?: UIColor.labelColor
    } forState:UIControlStateSelected];

    // ATT NOTE: No tracking SDKs are used. PrivacyInfo.xcprivacy declares NSPrivacyTracking=false.
    // If tracking SDKs are added in the future, implement ATTrackingManager prompt here.

    // ✅ Firebase setup`
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
       
        [self pp_configureAppCheckIfAvailable];
        [FIRApp configure];
        [self pp_enableAppCheckTokenAutoRefreshIfAvailable];
      
        [FIRMessaging messaging].delegate = self;
    });
    
    [[FIRConfiguration sharedInstance] setLoggerLevel:FIRLoggerLevelError];

    // ✅ Register global Firestore error observer (non-blocking banner)
    [PPFirestoreErrorNotifier registerGlobalObserver];

    // ✅ Start persistent offline status banner (M-19)
    [[PPOfflineBannerView sharedBanner] startMonitoring];

    // Detect fresh install and clear user if needed
    [[PPAuthManager shared] handleFreshInstall];
    [UsrMgr restoreSessionOnLaunchWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[AuthRestore] Session restore failed: %@", error.localizedDescription);
        } else {
            NSLog(@"[AuthRestore] Session restore completed.");
        }
    }];
    
    //[FIRAnalytics logEventWithName:@"test_event" parameters:@{@"status": @"app_opened"}];
    
   
    [self initFIRInstallations];
    // ✅ Google Maps
    [GMSServices setAbnormalTerminationReportingEnabled:YES];
    NSArray *keyParts = @[@"AIzaSyBl", @"VRMGGq60", @"XRi0oVs2", @"lSBub1Zb", @"5K1gees"];
    NSString *mapsAPIKey = [keyParts componentsJoinedByString:@""];
    [GMSServices provideAPIKey:mapsAPIKey];
    
    // ✅ Language
    //[Language setLanguage:[Language currentLanguageCode]];
    
 
    [[XLFormViewController cellClassesForRowDescriptorTypes] setObject:[XLFormRowDescriptorTypeTwoOptions class] forKey:@"TwoOptions"];
    [[XLFormViewController cellClassesForRowDescriptorTypes] setObject:[XLFormRowButton class] forKey:XLFormRowButtonKey];

    // ✅ Keyboard manager
    IQKeyboardManager.sharedManager.enable = YES;
    IQKeyboardManager.sharedManager.enableAutoToolbar = YES;
 

   // shouldShowToolbarPlaceholder
    // ✅ Push notifications
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;

    [center requestAuthorizationWithOptions:
     (UNAuthorizationOptionAlert |
      UNAuthorizationOptionSound |
      UNAuthorizationOptionBadge)
     completionHandler:^(BOOL granted, NSError * _Nullable error) {

        if (error) {
            NSLog(@"🔔 Notification permission request error: %@", error.localizedDescription);
        }
        NSLog(@"🔔 Notification permission granted: %d", granted);

        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [application registerForRemoteNotifications];
            });
        }
    }];

    [self pp_syncMessagingTokenIfAvailable];
    
    // ✅ Crashlytics
    NSString *userID = UserManager.sharedManager.currentUser.ID;
    if (userID) {
        [[FIRCrashlytics crashlytics] setUserID:userID];
    }
    [NewAppVC lockNavBarAppearanceWithTint:(AppPrimaryTextClr ?: UIColor.labelColor)
                          titleColor:(AppPrimaryTextClr ?: UIColor.labelColor)
                            statusStyle:UIStatusBarStyleLightContent];
    
    /*
     [[UIView appearance] setSemanticContentAttribute:GM.setSemantic];
     [[UINavigationBar appearance] setSemanticContentAttribute:GM.setSemantic];
     [[UITabBar appearance] setSemanticContentAttribute:GM.setSemantic];
     [[UITableView appearance] setSemanticContentAttribute:GM.setSemantic];
     [[UICollectionView appearance] setSemanticContentAttribute:GM.setSemantic];
     */
    if(PPIOS18())
    {
     
    }
    
#if DEBUG
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];
#endif
    
    
    UIFont *headerFont = [GM MidFontWithSize:16.0];
    UIColor *headerColor = [AppSecondaryTextClr colorWithAlphaComponent:0.6] ?: UIColor.labelColor;
 
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UITableViewHeaderFooterView class]]] setFont:headerFont];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UITableViewHeaderFooterView class]]] setTextColor:headerColor];
        
    [[UITableViewHeaderFooterView appearance] setTintColor:[UIColor clearColor]];
  
    //#if DEBUG
    //[PPPaymentManager setSimulatedPaymentSuccessEnabled:NO];
    //#endif

    return YES;
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    if (!url) {
        return NO;
    }

    if ([self.currentAuthorizationFlow resumeExternalUserAgentFlowWithURL:url]) {
        self.currentAuthorizationFlow = nil;
        return YES;
    }

    if ([GIDSignIn.sharedInstance handleURL:url]) {
        return YES;
    }

    if ([url.scheme isEqualToString:@"purepets"]) {
        [[DeepLinkRouter shared] handleURL:url];
        return YES;
    }

    return NO;
}


- (void)pp_linkFirebaseAppCheckSymbolsIfAvailable
{
#if PP_HAS_FIREBASE_APPCHECK
    (void)[FIRAppCheck class];
    (void)[FIRAppCheckDebugProviderFactory class];
    if (@available(iOS 14.0, *)) {
        (void)[FIRAppAttestProvider class];
    }
    (void)[FIRDeviceCheckProviderFactory class];
#endif
}

- (BOOL)pp_isTruthyValue:(NSString *)value
{
    NSString *trimmed = [value isKindOfClass:[NSString class]]
        ? [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString]
        : @"";
    if (trimmed.length == 0) {
        return NO;
    }
    return [@[@"1", @"true", @"yes", @"y", @"on"] containsObject:trimmed];
}

- (BOOL)pp_shouldForceDebugAppCheckProvider
{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSDictionary<NSString *, NSString *> *env = processInfo.environment ?: @{};
    NSString *forceEnv = env[@"PP_FORCE_APPCHECK_DEBUG_PROVIDER"];
    NSString *debugTokenEnv = env[@"FIRAAppCheckDebugToken"];

    if ([self pp_isTruthyValue:forceEnv]) {
        return YES;
    }
    // If a debug token is explicitly provided, prefer the debug provider.
    if ([debugTokenEnv isKindOfClass:[NSString class]] && debugTokenEnv.length > 0) {
        return YES;
    }
    return YES;
}

- (BOOL)pp_shouldUseDebugAppCheckProvider
{
#if TARGET_OS_SIMULATOR
    return YES;
#else
  #if DEBUG
    return YES;
  #else
    return [self pp_shouldForceDebugAppCheckProvider];
  #endif
#endif
}

- (void)pp_configureAppCheckIfAvailable
{
    [self pp_linkFirebaseAppCheckSymbolsIfAvailable];

#if !PP_HAS_FIREBASE_APPCHECK
    NSLog(@"[AppCheck] SDK not linked; skipping runtime provider setup.");
    return;
#endif

    PPAppCheckProviderFactory *providerFactory = [[PPAppCheckProviderFactory alloc] init];
    [FIRAppCheck setAppCheckProviderFactory:providerFactory];
    
    NSDictionary<NSString *, NSString *> *env = [NSProcessInfo processInfo].environment ?: @{};
    NSString *debugTokenHint = env[@"FIRAAppCheckDebugToken"];
    BOOL hasExplicitToken = [debugTokenHint isKindOfClass:[NSString class]] && debugTokenHint.length > 0;
    if (!hasExplicitToken && [self pp_shouldUseDebugAppCheckProvider]) {
        NSLog(@"[AppCheck] Debug provider active. If requests are blocked, copy the debug token and add it in Firebase Console > App Check > Manage debug tokens.");
    }
}

- (void)pp_enableAppCheckTokenAutoRefreshIfAvailable
{
#if PP_HAS_FIREBASE_APPCHECK
    if (![FIRApp defaultApp]) {
        return;
    }

    FIRAppCheck *appCheck = [FIRAppCheck appCheck];
    appCheck.isTokenAutoRefreshEnabled = YES;
#endif
}

- (void)pp_storeFCMTokenLocally:(NSString *)fcmToken
{
    NSString *trimmed = [fcmToken isKindOfClass:[NSString class]]
        ? [fcmToken stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (trimmed.length == 0) return;

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:trimmed forKey:@"PPUserTokenID"];
    [prefs setObject:trimmed forKey:@"deviceToken"];
    [prefs synchronize];
}

- (void)pp_syncMessagingTokenIfAvailable
{
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable fcmToken, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[FIRMessaging] tokenWithCompletion error: %@", error.localizedDescription);
            return;
        }

        NSString *trimmed = [fcmToken isKindOfClass:[NSString class]]
            ? [fcmToken stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            : @"";
        if (trimmed.length == 0) {
            NSLog(@"[FIRMessaging] tokenWithCompletion returned empty token");
            return;
        }

        [self pp_storeFCMTokenLocally:trimmed];

        if (UserManager.sharedManager.currentUser.ID.length) {
            [UserManager.sharedManager updateCurrentUserWithPPUserTokenID:trimmed];
            NSLog(@"[FIRMessaging] Synced FCM token to Firestore for current user");
        } else {
            NSLog(@"[FIRMessaging] Stored FCM token locally (user not logged in yet)");
        }
    }];
}

- (void)pp_setupAlertFonts {
    if (@available(iOS 9.0, *)) {
        UILabel *appearance = [UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]];
        appearance.font = [GM MidFontWithSize:16];
        UIButton *appearanceBTN = [UIButton appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]];
        appearanceBTN.font = [GM MidFontWithSize:16];
        [appearanceBTN.titleLabel setFont:[GM MidFontWithSize:16]];
        appearanceBTN.alpha = 0.2;
    }
}

- (NSString *)pp_redactedTokenPreview:(NSString *)token
{
    NSString *trimmed = [token isKindOfClass:[NSString class]]
        ? [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (trimmed.length == 0) {
        return @"<empty>";
    }
    if (trimmed.length <= 8) {
        return [NSString stringWithFormat:@"<len=%lu>", (unsigned long)trimmed.length];
    }
    NSString *prefix = [trimmed substringToIndex:4];
    NSString *suffix = [trimmed substringFromIndex:trimmed.length - 4];
    return [NSString stringWithFormat:@"%@…%@ (len=%lu)", prefix, suffix, (unsigned long)trimmed.length];
}


- (void)clearAudioCache {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *dirs = @[
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject,
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
        NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject,
        NSTemporaryDirectory()
    ];

    for (NSString *dir in dirs) {
        NSArray *files = [fm subpathsOfDirectoryAtPath:dir error:nil];

        for (NSString *file in files) {
            NSString *ext = file.pathExtension.lowercaseString;

            if ([ext isEqualToString:@"m4a"] ||
                [ext isEqualToString:@"aac"] ||
                [ext isEqualToString:@"mp3"]) {

                NSString *full = [dir stringByAppendingPathComponent:file];
                [fm removeItemAtPath:full error:nil];
                NSLog(@"Deleted audio %@", full);
            }
        }
    }

    NSLog(@"Audio cache cleared");
}



 
- (void)showUnsupportedVersionAlert {
    // Localized title & message
    NSString *title = kLang(@"Unsupported iOS Version");
    NSString *message = kLang(@"This version of the app is available on iOS 26 and above.");
    NSString *okButton = kLang(@"OK");

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:okButton
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        // Exit gracefully
        exit(0);
    }];

    [alert addAction:okAction];

   /*
    UILabel *titleLabel = [alert valueForKey:@"_titleLabel"];
    if ([titleLabel isKindOfClass:[UILabel class]]) {
        titleLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    }
    */

    

    [AppMgr.topViewController presentViewController:alert animated:YES completion:nil];
}


- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSString *type = userInfo[@"type"];
    NSString *threadID = userInfo[@"threadID"] ?: userInfo[@"threadId"];
    NSString *orderId = [userInfo[@"orderId"] isKindOfClass:NSString.class] ? userInfo[@"orderId"] : @"";
    NSString *status = [userInfo[@"status"] isKindOfClass:NSString.class] ? userInfo[@"status"] : @"";
    NSString *paymentStatus = [userInfo[@"paymentStatus"] isKindOfClass:NSString.class] ? userInfo[@"paymentStatus"] : @"";
    NSLog(@"[Push] didReceiveRemoteNotification | type=%@ | orderId=%@ | status=%@ | paymentStatus=%@ | threadID=%@",
          type ?: @"",
          orderId,
          status,
          paymentStatus,
          threadID ?: @"");
    if ([type hasPrefix:@"order"]) {
        NSLog(@"[Push] 📦 Order notification received in background | orderId=%@ | status=%@ | paymentStatus=%@",
              orderId,
              status,
              paymentStatus);
    }
    if ([type isEqualToString:@"chat"] || threadID.length > 0) {

        NSString *uid = [FIRAuth auth].currentUser.uid;
        if (!uid.length) {
            completionHandler(UIBackgroundFetchResultNoData);
            return;
        }

        __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }];

        [[ChManager sharedManager] syncPendingDeliveriesForUser:nil
                                                     completion:^{
            completionHandler(UIBackgroundFetchResultNewData);
            if (bgTask != UIBackgroundTaskInvalid) {
                [application endBackgroundTask:bgTask];
                bgTask = UIBackgroundTaskInvalid;
            }
        }];

        return;
    }

    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    (void)center;
    NSDictionary *userInfo = notification.request.content.userInfo ?: @{};
    NSString *type = [userInfo[@"type"] isKindOfClass:NSString.class] ? userInfo[@"type"] : @"";
    NSString *orderId = [userInfo[@"orderId"] isKindOfClass:NSString.class] ? userInfo[@"orderId"] : @"";
    NSString *status = [userInfo[@"status"] isKindOfClass:NSString.class] ? userInfo[@"status"] : @"";
    NSString *paymentStatus = [userInfo[@"paymentStatus"] isKindOfClass:NSString.class] ? userInfo[@"paymentStatus"] : @"";
    if (type.length > 0 || orderId.length > 0) {
        NSLog(@"[Push] willPresentNotification | type=%@ | orderId=%@ | status=%@ | paymentStatus=%@",
              type,
              orderId,
              status,
              paymentStatus);
    }
    if (!completionHandler) return;
    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionList |
                          UNNotificationPresentationOptionSound |
                          UNNotificationPresentationOptionBadge);
    } else {
        completionHandler(UNNotificationPresentationOptionAlert |
                          UNNotificationPresentationOptionSound |
                          UNNotificationPresentationOptionBadge);
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    (void)center;
    NSDictionary *userInfo = response.notification.request.content.userInfo ?: @{};
    NSString *type = [userInfo[@"type"] isKindOfClass:NSString.class] ? userInfo[@"type"] : @"";
    NSString *orderId = [userInfo[@"orderId"] isKindOfClass:NSString.class] ? userInfo[@"orderId"] : @"";
    NSString *status = [userInfo[@"status"] isKindOfClass:NSString.class] ? userInfo[@"status"] : @"";
    NSString *paymentStatus = [userInfo[@"paymentStatus"] isKindOfClass:NSString.class] ? userInfo[@"paymentStatus"] : @"";
    NSLog(@"[Push] Notification tapped | type=%@ | orderId=%@ | status=%@ | paymentStatus=%@",
          type,
          orderId,
          status,
          paymentStatus);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PPRemoteNotificationTapped"
                                                        object:nil
                                                      userInfo:userInfo];
    if (completionHandler) {
        completionHandler();
    }
}


- (void)initFIRInstallations {
    
    [[FIRInstallations installations] installationIDWithCompletion:^(NSString * _Nullable identifier,
                                                                     NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[Installations] ❌ Failed to get installationID: %@", error.localizedDescription);
            return;
        }
        NSLog(@"[Installations] ✅ Installation ID ready (len=%lu)", (unsigned long)identifier.length);
    }];
    
    
    [[FIRInstallations installations] authTokenWithCompletion:^(FIRInstallationsAuthTokenResult * _Nullable tokenResult,
                                                                NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[Installations] ❌ Failed to get auth token: %@", error.localizedDescription);
            return;
        }
        NSLog(@"[Installations] 🔑 Auth token refreshed (expires=%@)", tokenResult.expirationDate);
       // UsrMgr.currentUser.PPUserTokenID =  tokenResult.authToken;
        UsrMgr.currentToken =  tokenResult.authToken;
    }];

    
    
    
}

// Handle device token registration for APNs
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [FIRMessaging messaging].APNSToken = deviceToken;
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:
                       [NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSLog(@"[FIRMessaging] didRegisterForRemoteNotifications (APNs token %@)", [self pp_redactedTokenPreview:token]);
    [self pp_syncMessagingTokenIfAvailable];
}

// Failed to register for remote notifications
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"[FIRMessaging] Failed to register for remote notifications: %@", error);
}

// Handle incoming FCM token refresh
- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"[FIRMessaging] didReceiveRegistrationToken (%@)", [self pp_redactedTokenPreview:fcmToken]);
    [self pp_storeFCMTokenLocally:fcmToken];

    if (fcmToken.length && UserManager.sharedManager.currentUser.ID.length) {
        [UserManager.sharedManager updateCurrentUserWithPPUserTokenID:fcmToken];
        NSLog(@"[FIRMessaging] Updated user with new FCM token");
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self pp_syncMessagingTokenIfAvailable];
}
 
// Clean up any observers
- (void)dealloc {
    NSLog(@"[AppDelegate] dealloc: removing observers");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



@end
