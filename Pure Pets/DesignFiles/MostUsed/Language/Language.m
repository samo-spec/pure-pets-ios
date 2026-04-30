//
//  Language.m
//

#import "Language.h"
#import "PPRootTabBarController.h"
@import UIKit;  // <— needed for UIApplication/scenes

static NSBundle *bundle = nil;
static NSString *cachedLanguageCode = nil;
static BOOL isSettingLanguage = NO;
static BOOL isReloadingLanguageRoot = NO;
NSString *const LanguageCodeIdIndentifier = @"AppLanguage";
// You already use this in your app:
static NSString * const kLanguageDidChangeNotification = @"LanguageDidChangeNotification";

@implementation Language

+ (void)pp_applySemanticAppearance
{
    UISemanticContentAttribute attr = [self semanticAttributeForCurrentLanguage];
    [UIView appearance].semanticContentAttribute = attr;
    [UINavigationBar appearance].semanticContentAttribute = attr;
    [UITabBar appearance].semanticContentAttribute = attr;
    [UITableView appearance].semanticContentAttribute = attr;
    [UICollectionView appearance].semanticContentAttribute = attr;
}

+ (void)pp_applySemanticToWindow:(nullable UIWindow *)window
{
    if (!window) {
        return;
    }

    UISemanticContentAttribute attr = [self semanticAttributeForCurrentLanguage];
    window.semanticContentAttribute = attr;
    window.rootViewController.view.semanticContentAttribute = attr;
    [window setNeedsLayout];
    [window layoutIfNeeded];
}

+ (NSString *)_normalize:(NSString *)code {
    
  
    if (code.length == 0) return @"en";
    NSString *lower = code.lowercaseString;
    NSString *base  = [[lower componentsSeparatedByString:@"-"] firstObject] ?: lower;
    if ([LanguageCode containsObject:base]) return base;
    if ([base hasPrefix:@"ar"]) return @"ar";
    return @"en";
}

+ (void)pp_loadLanguage:(NSString *)language notifyChange:(BOOL)notifyChange {
    NSString *norm = [self _normalize:language];
    NSString *path = [[NSBundle mainBundle] pathForResource:norm ofType:@"lproj"];

    DLog(@"[Language] loadLanguage: %@ -> normalized=%@ (path=%@ notify=%d)", language, norm, path ?: @"<main bundle>", (int)notifyChange);

    if (path) {
        bundle = [NSBundle bundleWithPath:path];
    } else {
        bundle = [NSBundle mainBundle];
    }
    cachedLanguageCode = norm;

    // Cache selection
    [[NSUserDefaults standardUserDefaults] setObject:norm forKey:LanguageCodeIdIndentifier];
    [[NSUserDefaults standardUserDefaults] setObject:@[norm] forKey:@"AppleLanguages"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (!notifyChange) {
        return;
    }

    // Notify app
    [[NSNotificationCenter defaultCenter] postNotificationName:kLanguageDidChangeNotification object:nil];
    DLog(@"[Language] posted %@ (isRTL=%d)", kLanguageDidChangeNotification, (int)[self isRTL]);
}

+ (void)setLanguage:(NSString *)language {
    NSString *norm = [self _normalize:language];
    BOOL didChange = ![norm isEqualToString:[self currentLanguageCode]];
    BOOL needsBundle = (bundle == nil);

    if (isSettingLanguage) {
        [self pp_loadLanguage:norm notifyChange:NO];
        return;
    }

    isSettingLanguage = YES;
    [self pp_loadLanguage:norm notifyChange:(didChange && !needsBundle)];
    isSettingLanguage = NO;
}

+ (NSString *)currentLanguageCode {
    if (cachedLanguageCode.length > 0) {
        return cachedLanguageCode;
    }

    id savedObject = [[NSUserDefaults standardUserDefaults] objectForKey:LanguageCodeIdIndentifier];
    NSString *saved = [savedObject isKindOfClass:NSString.class] ? (NSString *)savedObject : nil;
    if (!saved && [savedObject isKindOfClass:NSArray.class]) {
        saved = [(NSArray *)savedObject firstObject];
    }
    if (![saved isKindOfClass:NSString.class]) {
        saved = nil;
    }

    if (saved.length > 0) {
        NSString *norm = [self _normalize:saved];
        cachedLanguageCode = norm;
        return norm;
    }

    NSString *system = [NSLocale preferredLanguages].firstObject ?: @"en";
    NSString *norm = [self _normalize:system];
    cachedLanguageCode = norm;
    return norm;
}

+ (NSInteger)languageVal {
    return [[self currentLanguageCode] isEqualToString:@"en"] ? 0 : 1;
}

#pragma mark - 🔴 MAIN ENTRY: user explicitly chose a language

+ (void)userSelectedLanguage:(NSString *)selectedLanguage {
    DLog(@"[Language] userSelectedLanguage: %@", selectedLanguage);
    NSString *norm = [self _normalize:selectedLanguage];
    BOOL didChange = ![norm isEqualToString:[self currentLanguageCode]];

    // 1) Persist & load bundle, post notification
    [self setLanguage:norm];
    [self pp_applySemanticAppearance];
    if (!didChange || isReloadingLanguageRoot) {
        return;
    }

    isReloadingLanguageRoot = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL reloadedViaSceneDelegate = NO;
        void (^finishReload)(void) = ^{
            isReloadingLanguageRoot = NO;
        };

        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:UIWindowScene.class]) {
                    continue;
                }

                UIWindowScene *windowScene = (UIWindowScene *)scene;
                id delegate = windowScene.delegate;
                if ([delegate respondsToSelector:@selector(reloadRootViewControllerForLanguageChange)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [delegate performSelector:@selector(reloadRootViewControllerForLanguageChange)];
#pragma clang diagnostic pop
                    reloadedViaSceneDelegate = YES;
                    continue;
                }

                for (UIWindow *window in windowScene.windows) {
                    [self pp_applySemanticToWindow:window];
                }
            }
        }

        if (reloadedViaSceneDelegate) {
            finishReload();
            return;
        }

        UIWindow *window = [self pp_transitionWindow];
        if (!window) {
            NSLog(@"[Language] No active window available yet; semantic appearance updated for next scene.");
            finishReload();
            return;
        }

        [self pp_applySemanticToWindow:window];

        PPRootTabBarController *rootVC = [[PPRootTabBarController alloc] init];
        rootVC.view.semanticContentAttribute = [self semanticAttributeForCurrentLanguage];
        [self pp_swapRootViewController:rootVC onWindow:window];
        finishReload();
    });
}


+ (nullable UIWindow *)pp_transitionWindow
{
    UIWindow *window = AppManager.sharedInstance.topViewController.view.window;
    if (window) {
        return window;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive &&
                windowScene.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }

            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.isKeyWindow) {
                    return candidate;
                }
            }

            if (windowScene.windows.firstObject) {
                return windowScene.windows.firstObject;
            }
        }
    }

    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow) {
            return candidate;
        }
    }

    UIWindow *fallback = UIApplication.sharedApplication.windows.firstObject;
    if (!fallback) {
        NSLog(@"❌ SplashVC: no UIWindow available");
    }
    return fallback;
}

+ (void)pp_swapRootViewController:(UIViewController *)rootViewController
                         onWindow:(UIWindow *)window
{
    [self pp_applySemanticAppearance];
    window.semanticContentAttribute = [self semanticAttributeForCurrentLanguage];
    rootViewController.view.semanticContentAttribute = [self semanticAttributeForCurrentLanguage];

    [UIView transitionWithView:window
                      duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
        BOOL previousAnimationState = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        window.rootViewController = rootViewController;
        [window makeKeyAndVisible];
        [window layoutIfNeeded];
        [UIView setAnimationsEnabled:previousAnimationState];
    } completion:nil];
}




#pragma mark - Strings

+ (NSString *)get:(NSString *)key alter:(NSString *)alternate {
    if (!bundle) {
        // Ensure bundle loads cached language at first call
        [self pp_loadLanguage:[self currentLanguageCode] notifyChange:NO];
    }
    NSString *val = [bundle localizedStringForKey:key value:alternate table:nil];
    // Optional debug (comment out if noisy)
    // DLog(@"[Language] get key='%@' → '%@'", key, val ?: key);
    return val ?: key;
}

#pragma mark - Direction helpers

+ (BOOL)isRTL {
    return Language.languageVal == 1;
}

+ (UISemanticContentAttribute)semanticAttributeForCurrentLanguage {
    return [Language languageVal] == 1
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

+ (NSTextAlignment)alignmentForCurrentLanguage {
    return ([Language languageVal] == 1) ? NSTextAlignmentRight : NSTextAlignmentLeft;
}



@end
