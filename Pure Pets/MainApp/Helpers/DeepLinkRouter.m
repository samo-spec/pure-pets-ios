//
//  DeepLinkRouter.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/05/2025.
//


#import "DeepLinkRouter.h"
#import <UIKit/UIKit.h>
#import "PetAd.h"
#import "PetAccessoryManager.h"
#import "AccessViewerVC.h"

@protocol PPPetAdViewerHostingControllerRouting <NSObject>
- (UIViewController *)initWithAd:(PetAd *)ad;
@end

@implementation DeepLinkRouter

+ (instancetype)shared {
    static DeepLinkRouter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DeepLinkRouter alloc] init];
    });
    return sharedInstance;
}

- (BOOL)handleURL:(NSURL *)url {
    if (!url) {
        NSLog(@"❌ DeepLinkRouter: nil URL passed to handleURL");
        return NO;
    }
    if (![[url scheme] isEqualToString:@"purepets"]) return NO;

    NSString *host = url.host;
    NSArray *pathComponents = url.pathComponents;
    if (!pathComponents) {
        NSLog(@"❌ DeepLinkRouter: nil pathComponents for URL: %@", url);
        return NO;
    }

    if ([host isEqualToString:@"petad"] && pathComponents.count > 1) {
        NSString *adID = pathComponents[1];
        [self navigateToPetAdWithID:adID];
        return YES;
    }

    if ([host isEqualToString:@"accessory"] && pathComponents.count > 1) {
        NSString *accessoryID = pathComponents[1];
        [self navigateToAccessoryWithID:accessoryID];
        return YES;
    }

    return NO;
}

#pragma mark - Navigation Handlers

- (void)navigateToPetAdWithID:(NSString *)adID {
    if (adID.length == 0) return;

    __weak typeof(self) weakSelf = self;
    [PetAdManager fetchAdsWithIDs:@[adID] completion:^(NSArray<PetAd *> *ads) {
        PetAd *ad = ads.firstObject;
        if (!ad) {
            NSLog(@"❌ DeepLinkRouter: pet ad not found for id %@", adID);
            return;
        }

        Class HostingClass = NSClassFromString(@"PPPetAdViewerHostingController");
        if (!HostingClass) {
            NSLog(@"❌ DeepLinkRouter: PPPetAdViewerHostingController unavailable");
            return;
        }

        id<PPPetAdViewerHostingControllerRouting> allocatedViewer =
            (id<PPPetAdViewerHostingControllerRouting>)[HostingClass alloc];
        UIViewController *vc = [allocatedViewer initWithAd:ad];
        vc.hidesBottomBarWhenPushed = YES;
        [(weakSelf ?: DeepLinkRouter.shared) pushToRootViewController:vc];
    }];
}

- (void)navigateToAccessoryWithID:(NSString *)accessoryID {
    if (accessoryID.length == 0) return;

    PetAccessory *cachedAccessory =
        [[PetAccessoryManager sharedManager] getAccessoryID:accessoryID];
    if (cachedAccessory) {
        AccessViewerVC *viewer = [AccessViewerVC new];
        viewer.accessAds = cachedAccessory;
        viewer.hidesBottomBarWhenPushed = YES;
        [self pushToRootViewController:viewer];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchAccessoriesWithIDs:@[accessoryID]
                                      completion:^(NSArray<PetAccessory *> *accessories) {
        PetAccessory *accessory = accessories.firstObject;
        if (!accessory) {
            NSLog(@"❌ DeepLinkRouter: accessory not found for id %@", accessoryID);
            return;
        }

        AccessViewerVC *viewer = [AccessViewerVC new];
        viewer.accessAds = accessory;
        viewer.hidesBottomBarWhenPushed = YES;
        [(weakSelf ?: DeepLinkRouter.shared) pushToRootViewController:viewer];
    }];
}

- (void)pushToRootViewController:(UIViewController *)vc {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow || w.rootViewController) {
                        window = w;
                        break;
                    }
                }
                if (window) break;
            }
        }
        if (!window) {
            window = UIApplication.sharedApplication.delegate.window ?: UIApplication.sharedApplication.keyWindow;
        }
        if (!window) {
            NSLog(@"❌ DeepLinkRouter: nil window, aborting push");
            return;
        }
        UIViewController *root = window.rootViewController;
        if (!root) {
            NSLog(@"❌ DeepLinkRouter: nil rootViewController, aborting push");
            return;
        }

        UIViewController *presenter = root;
        if ([presenter isKindOfClass:UITabBarController.class]) {
            UITabBarController *tab = (UITabBarController *)presenter;
            UIViewController *selected = tab.selectedViewController;
            if ([selected isKindOfClass:UINavigationController.class]) {
                presenter = selected;
            }
        }

        while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) {
            presenter = presenter.presentedViewController;
        }

        if ([presenter isKindOfClass:UINavigationController.class]) {
            [(UINavigationController *)presenter pushViewController:vc animated:YES];
        } else if (presenter.navigationController) {
            [presenter.navigationController pushViewController:vc animated:YES];
        } else {
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
            [presenter presentViewController:nav animated:YES completion:nil];
        }
    });
}

@end
