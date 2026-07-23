//
//  PPRootLegacyAdapter.m
//  Pure Pets
//
//  Implements PPRootLegacyAdapter by importing the actual ObjC headers
//  and calling the real APIs directly. Private-only selectors on
//  PPRootTabBarController are dispatched via respondsToSelector/performSelector
//  since they have no public header declaration.
//

#import "PPRootLegacyAdapter.h"
#import "UserManager.h"
#import "UserModel.h"
#import "CartManager.h"
#import "ChManager.h"
#import "PPBottomSurfaceCoordinator.h"
#import "PPRootTabBarController.h"

@implementation PPRootLegacyAdapter

#pragma mark - Session State

+ (BOOL)isUserLoggedIn {
    return [[UserManager sharedManager] isUserLoggedIn];
}

+ (BOOL)isCurrentUserBlocked {
    return [[UserManager sharedManager] isCurrentUserBlocked];
}

+ (BOOL)isCurrentUserEffectivelyBlocked {
    return [[UserManager sharedManager] isCurrentUserEffectivelyBlocked];
}

+ (nullable NSString *)currentUserDisplayName {
    UserModel *user = [UserManager sharedManager].currentUser;
    if (!user) return nil;
    NSString *best = [user PPBestDisplayName];
    if (best.length > 0) return best;
    return user.UserName;
}

+ (nullable NSURL *)currentUserImageURL {
    return [UserManager sharedManager].currentUser.UserImageUrl;
}

#pragma mark - Cart State

+ (NSInteger)cartTotalItemsCount {
    return [[CartManager sharedManager] totalItemsCount];
}

+ (double)cartTotalAmount {
    return [[CartManager sharedManager] totalAmount];
}

#pragma mark - Unread Counts

+ (NSInteger)totalUnreadChatsCount {
    NSDictionary<NSString *, NSNumber *> *counts = [ChManager sharedManager].liveUnreadCounts;
    if (!counts || counts.count == 0) return 0;
    NSInteger total = 0;
    for (NSNumber *val in counts.allValues) {
        total += val.integerValue;
    }
    return total;
}

#pragma mark - Bottom Surface

+ (void)applySurfaceForController:(nullable UIViewController *)controller
                         animated:(BOOL)animated {
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:controller
                                                                     animated:animated];
}

#pragma mark - Root Controller Actions
//
// The following methods target selectors that are declared privately
// inside PPRootTabBarController.m (not in the .h). We use
// respondsToSelector + performSelector to dispatch safely.
// pp_openChatThreadFromNotification:animated: IS public in the .h,
// so it is called directly with a cast.
//

+ (void)presentBottomSheetOn:(UITabBarController *)controller {
    SEL sel = NSSelectorFromString(@"presentBottomSheet");
    if ([controller respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [controller performSelector:sel];
#pragma clang diagnostic pop
    }
}

+ (void)novaButtonTappedOn:(UITabBarController *)controller {
    SEL sel = NSSelectorFromString(@"pp_novaButtonTapped");
    if ([controller respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [controller performSelector:sel];
#pragma clang diagnostic pop
    }
}

+ (void)openSearchExperienceOn:(UITabBarController *)controller
            openingAccessories:(BOOL)openAccessories {
    SEL sel = NSSelectorFromString(@"pp_openSearchExperienceFromCurrentContextOpeningAccessories:");
    if ([controller respondsToSelector:sel]) {
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:
                             [controller methodSignatureForSelector:sel]];
        inv.selector = sel;
        inv.target   = controller;
        [inv setArgument:&openAccessories atIndex:2];
        [inv invoke];
    }
}

+ (BOOL)openChatThreadOn:(UITabBarController *)controller
                  thread:(id)thread
                animated:(BOOL)animated {
    // Public method — declared in PPRootTabBarController.h
    if ([controller isKindOfClass:[PPRootTabBarController class]]) {
        return [(PPRootTabBarController *)controller
                pp_openChatThreadFromNotification:thread
                                         animated:animated];
    }
    return NO;
}

+ (void)blockedContactSupportTappedOn:(UITabBarController *)controller {
    SEL sel = NSSelectorFromString(@"pp_blockedContactSupportTapped");
    if ([controller respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [controller performSelector:sel];
#pragma clang diagnostic pop
    }
}

+ (void)blockedSignOutTappedOn:(UITabBarController *)controller {
    SEL sel = NSSelectorFromString(@"pp_blockedSignOutTapped");
    if ([controller respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [controller performSelector:sel];
#pragma clang diagnostic pop
    }
}

+ (void)showIntroIfNeededOn:(UITabBarController *)controller {
    SEL sel = NSSelectorFromString(@"pp_showIntroIfNeeded");
    if ([controller respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [controller performSelector:sel];
#pragma clang diagnostic pop
    }
}

+ (void)applyBottomNavigationClearanceOn:(UITabBarController *)controller {
    SEL sel = NSSelectorFromString(@"pp_applyBottomNavigationClearanceToVisibleLists");
    if ([controller respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [controller performSelector:sel];
#pragma clang diagnostic pop
    }
}

@end
