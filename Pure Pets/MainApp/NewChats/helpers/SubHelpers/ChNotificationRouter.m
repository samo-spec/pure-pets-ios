//
//  ChNotificationRouter.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//


// ChNotificationRouter.m

#import "ChNotificationRouter.h"
#import <Pure_Pets-Swift.h>
#import "ChatThreadModel.h"
#import "PPRootTabBarController.h"
#import "PPOverlayCoordinator.h"

static NSString *PPChatRouterThreadIDFromPayload(NSDictionary *userInfo)
{
    if (![userInfo isKindOfClass:NSDictionary.class]) return @"";
    NSDictionary *meta = [userInfo[@"meta"] isKindOfClass:NSDictionary.class] ? userInfo[@"meta"] : @{};
    NSArray<NSString *> *keys = @[@"conversationId", @"conversationID", @"threadID", @"threadId", @"chatId", @"chatID", @"contextId"];
    for (NSString *key in keys) {
        id value = userInfo[key] ?: meta[key];
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
            return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
    }
    return @"";
}

static UIViewController *PPChatRouterVisibleMessagingController(UIViewController *controller,
                                                                 NSString *threadID)
{
    if (!controller || threadID.length == 0) return nil;

    if (controller.presentedViewController) {
        UIViewController *presented =
            PPChatRouterVisibleMessagingController(controller.presentedViewController, threadID);
        if (presented) return presented;
    }

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController = (UINavigationController *)controller;
        UIViewController *visible =
            PPChatRouterVisibleMessagingController(navigationController.visibleViewController ?: navigationController.topViewController,
                                                   threadID);
        if (visible) return visible;
    }

    if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabController = (UITabBarController *)controller;
        UIViewController *selected =
            PPChatRouterVisibleMessagingController(tabController.selectedViewController, threadID);
        if (selected) return selected;
    }

    if ([controller isKindOfClass:PPMessagingSwiftUIHostController.class]) {
        return controller;
    }

    for (UIViewController *child in controller.childViewControllers.reverseObjectEnumerator) {
        UIViewController *visible = PPChatRouterVisibleMessagingController(child, threadID);
        if (visible) return visible;
    }

    return nil;
}

static PPRootTabBarController *PPChatRouterRootTabControllerInHierarchy(UIViewController *controller)
{
    if (!controller) return nil;

    if ([controller isKindOfClass:PPRootTabBarController.class]) {
        return (PPRootTabBarController *)controller;
    }

    if ([controller.tabBarController isKindOfClass:PPRootTabBarController.class]) {
        return (PPRootTabBarController *)controller.tabBarController;
    }

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController = (UINavigationController *)controller;
        PPRootTabBarController *visibleRoot =
            PPChatRouterRootTabControllerInHierarchy(navigationController.visibleViewController ?: navigationController.topViewController);
        if (visibleRoot) return visibleRoot;

        for (UIViewController *child in navigationController.viewControllers.reverseObjectEnumerator) {
            PPRootTabBarController *root = PPChatRouterRootTabControllerInHierarchy(child);
            if (root) return root;
        }
    }

    if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabController = (UITabBarController *)controller;
        PPRootTabBarController *selectedRoot =
            PPChatRouterRootTabControllerInHierarchy(tabController.selectedViewController);
        if (selectedRoot) return selectedRoot;

        for (UIViewController *child in tabController.viewControllers.reverseObjectEnumerator) {
            PPRootTabBarController *root = PPChatRouterRootTabControllerInHierarchy(child);
            if (root) return root;
        }
    }

    for (UIViewController *child in controller.childViewControllers.reverseObjectEnumerator) {
        PPRootTabBarController *root = PPChatRouterRootTabControllerInHierarchy(child);
        if (root) return root;
    }

    return nil;
}

static PPRootTabBarController *PPChatRouterRootTabControllerForController(UIViewController *controller)
{
    UIViewController *windowRoot =
        controller.view.window.rootViewController ?:
        UIApplication.sharedApplication.keyWindow.rootViewController;

    PPRootTabBarController *root = PPChatRouterRootTabControllerInHierarchy(windowRoot);
    if (root) return root;

    return PPChatRouterRootTabControllerInHierarchy(controller);
}

static void PPChatRouterPresentThreadFullscreen(ChatThreadModel *thread,
                                                UIViewController *sourceVC)
{
    if (!thread) {
        [ChManager sharedManager].isHandlingNotificationHandoff = NO;
        return;
    }

    UIViewController *presentingVC = [PPOverlayCoordinator pp_resolvedPresenterFrom:sourceVC];
    if (!presentingVC) {
        presentingVC = sourceVC.view.window.rootViewController ?:
                       UIApplication.sharedApplication.keyWindow.rootViewController;
    }

    if (!presentingVC) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.rootViewController) {
                        presentingVC = [PPOverlayCoordinator pp_resolvedPresenterFrom:w.rootViewController] ?: w.rootViewController;
                        break;
                    }
                }
                if (presentingVC) break;
            }
        }
    }

    if (!presentingVC) {
        [ChManager sharedManager].isHandlingNotificationHandoff = NO;
        return;
    }

    [PPOverlayCoordinator pp_openChatThread:thread fromVC:presentingVC];
}

@implementation ChNotificationRouter

+ (instancetype)shared {
    static ChNotificationRouter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ChNotificationRouter alloc] init];
    });
    return instance;
}

- (void)handleChatNotification:(NSDictionary *)userInfo
           fromViewController:(UIViewController *)presentingVC {

    NSString *threadID = PPChatRouterThreadIDFromPayload(userInfo);

    if (!presentingVC) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.rootViewController) {
                        presentingVC = w.rootViewController;
                        break;
                    }
                }
                if (presentingVC) break;
            }
        }
        if (!presentingVC) {
            presentingVC = UIApplication.sharedApplication.keyWindow.rootViewController;
        }
    }

    if (threadID.length == 0 || !presentingVC) {
        NSLog(@"❌ [NotificationRouter] Missing threadID=%@ presentingVC=%@", threadID ?: @"", presentingVC ? @"present" : @"nil");
        [ChManager sharedManager].isHandlingNotificationHandoff = NO;
        return;
    }

    UIViewController *searchRoot =
        presentingVC.view.window.rootViewController ?:
        UIApplication.sharedApplication.keyWindow.rootViewController ?:
        presentingVC;
    UIViewController *visibleChat =
        PPChatRouterVisibleMessagingController(searchRoot, threadID);
    if (visibleChat) {
        [ChManager sharedManager].activeThreadID = threadID;
        [ChManager sharedManager].isHandlingNotificationHandoff = NO;
        NSLog(@"[NotificationRouter] Chat already visible for thread %@", threadID);
        return;
    }

    [ChManager fetchThreadWithID:threadID
                            completion:^(ChatThreadModel *thread) {

        if (!thread) {
            NSLog(@"❌ [NotificationRouter] Thread not found for ID: %@", threadID);
            [ChManager sharedManager].isHandlingNotificationHandoff = NO;
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *currentRoot =
                presentingVC.view.window.rootViewController ?:
                UIApplication.sharedApplication.keyWindow.rootViewController ?:
                presentingVC;
            UIViewController *visibleChat =
                PPChatRouterVisibleMessagingController(currentRoot, threadID);
            if (visibleChat) {
                [ChManager sharedManager].activeThreadID = threadID;
                [ChManager sharedManager].isHandlingNotificationHandoff = NO;
                NSLog(@"[NotificationRouter] Chat became visible for thread %@", threadID);
                return;
            }

            PPRootTabBarController *rootTabController =
                PPChatRouterRootTabControllerForController(presentingVC);

            void (^openInRoot)(void) = ^{
                if (rootTabController) {
                    if (![rootTabController pp_openChatThreadFromNotification:thread animated:YES]) {
                        PPChatRouterPresentThreadFullscreen(thread, rootTabController);
                    }
                    return;
                }
                PPChatRouterPresentThreadFullscreen(thread, presentingVC);
            };

            if (rootTabController.presentedViewController &&
                !rootTabController.presentedViewController.isBeingDismissed) {
                [rootTabController dismissViewControllerAnimated:NO completion:openInRoot];
                return;
            }

            openInRoot();
        });
    }];
}

@end
