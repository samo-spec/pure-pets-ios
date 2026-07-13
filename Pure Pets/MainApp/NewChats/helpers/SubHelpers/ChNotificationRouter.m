//
//  ChNotificationRouter.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//


// ChNotificationRouter.m

#import "ChNotificationRouter.h"
#import "ChMessagingController.h"
#import "ChatThreadModel.h"
#import "PPRootTabBarController.h"
#import "PPFunc.h" // your sheet presenter

static NSString *PPChatRouterThreadIDFromPayload(NSDictionary *userInfo)
{
    id value = userInfo[@"conversationId"] ?: userInfo[@"threadID"] ?: userInfo[@"threadId"];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static ChMessagingController *PPChatRouterVisibleMessagingController(UIViewController *controller,
                                                                     NSString *threadID)
{
    if (!controller || threadID.length == 0) return nil;

    if (controller.presentedViewController) {
        ChMessagingController *presented =
            PPChatRouterVisibleMessagingController(controller.presentedViewController, threadID);
        if (presented) return presented;
    }

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController = (UINavigationController *)controller;
        ChMessagingController *visible =
            PPChatRouterVisibleMessagingController(navigationController.visibleViewController ?: navigationController.topViewController,
                                                   threadID);
        if (visible) return visible;
    }

    if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabController = (UITabBarController *)controller;
        ChMessagingController *selected =
            PPChatRouterVisibleMessagingController(tabController.selectedViewController, threadID);
        if (selected) return selected;
    }

    if ([controller isKindOfClass:ChMessagingController.class]) {
        ChMessagingController *chatController = (ChMessagingController *)controller;
        NSString *visibleThreadID = chatController.chatThread.ID ?: @"";
        if ([visibleThreadID isEqualToString:threadID]) {
            return chatController;
        }
    }

    for (UIViewController *child in controller.childViewControllers.reverseObjectEnumerator) {
        ChMessagingController *visible = PPChatRouterVisibleMessagingController(child, threadID);
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

static void PPChatRouterPresentThreadFallback(ChatThreadModel *thread,
                                              UIViewController *presentingVC)
{
    if (!presentingVC.view.window) {
        presentingVC = UIApplication.sharedApplication.keyWindow.rootViewController;
    }
    if (!presentingVC) {
        [ChManager sharedManager].isHandlingNotificationHandoff = NO;
        return;
    }

    ChMessagingController *chatVC =
        [[ChMessagingController alloc] initWithChatThread:thread];

    [PPFunc presentSheetFrom:presentingVC
                     sheetVC:chatVC
                 detentStyle:PPSheetDetentStyleSemiLargAndLarge];
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

    if (threadID.length == 0 || !presentingVC) {
        NSLog(@"❌ [NotificationRouter] Missing threadID");
        [ChManager sharedManager].isHandlingNotificationHandoff = NO;
        return;
    }

    UIViewController *searchRoot =
        presentingVC.view.window.rootViewController ?:
        UIApplication.sharedApplication.keyWindow.rootViewController ?:
        presentingVC;
    ChMessagingController *visibleChat =
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
            NSLog(@"❌ [NotificationRouter] Thread not found");
            [ChManager sharedManager].isHandlingNotificationHandoff = NO;
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *currentRoot =
                presentingVC.view.window.rootViewController ?:
                UIApplication.sharedApplication.keyWindow.rootViewController ?:
                presentingVC;
            ChMessagingController *visibleChat =
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
                        [ChManager sharedManager].isHandlingNotificationHandoff = NO;
                    }
                    return;
                }
                PPChatRouterPresentThreadFallback(thread, presentingVC);
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
