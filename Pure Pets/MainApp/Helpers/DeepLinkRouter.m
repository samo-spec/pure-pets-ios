//
//  DeepLinkRouter.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/05/2025.
//


#import "DeepLinkRouter.h"
#import <UIKit/UIKit.h>

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
    //ViewerVC *vc = [[ViewerVC alloc] initWithAdID:adID];
    //[self pushToRootViewController:vc];
}

- (void)navigateToAccessoryWithID:(NSString *)accessoryID {
   // PetAccessoryDetailViewController *vc = [[PetAccessoryDetailViewController alloc] initWithAccessoryID:accessoryID];
   // [self pushToRootViewController:vc];
}

- (void)pushToRootViewController:(UIViewController *)vc {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.delegate.window;
        if (!window) {
            NSLog(@"❌ DeepLinkRouter: nil window, aborting push");
            return;
        }
        UIViewController *root = window.rootViewController;
        if (![root isKindOfClass:[UINavigationController class]]) {
            NSLog(@"❌ DeepLinkRouter: rootViewController is not UINavigationController, aborting push");
            return;
        }
        UINavigationController *nav = (UINavigationController *)root;
        [nav pushViewController:vc animated:YES];
    });
}

@end
