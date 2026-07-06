#import "PPBottomSurfaceCoordinator.h"
#import "UIViewController+PPBottomSurface.h"
#import "PPRootTabBarController.h"
#import "CartManager.h"
#import <objc/runtime.h>

@interface PPBottomSurfaceCoordinator ()
@property (nonatomic, assign, readwrite) PPBottomSurfaceKind activeSurfaceKind;
@property (nonatomic, weak, readwrite, nullable) UIViewController *activeController;
@property (nonatomic, assign) NSUInteger transitionToken;
@end

@implementation PPBottomSurfaceCoordinator

+ (instancetype)sharedCoordinator
{
    static PPBottomSurfaceCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coordinator = [[PPBottomSurfaceCoordinator alloc] init];
    });
    return coordinator;
}

+ (NSTimeInterval)transitionOutDuration
{
    return 0.24;
}

+ (NSTimeInterval)transitionInDuration
{
    return 0.46;
}

+ (CGFloat)transitionInSpringDamping
{
    return 0.88;
}

+ (CGFloat)transitionInSpringVelocity
{
    return 0.20;
}

- (PPBottomSurfaceKind)resolvedSurfaceKindForController:(UIViewController *)controller
{
    UIViewController *targetController = [self pp_targetControllerFromController:controller];
    if (!targetController) {
        return PPBottomSurfaceKindNone;
    }

    PPBottomSurfaceKind preferredKind = [targetController pp_preferredBottomSurfaceKind];
    BOOL hasOverride = [self pp_controllerOverridesPreferredKind:targetController];

    if (!hasOverride &&
        preferredKind == PPBottomSurfaceKindPremiumTabBar &&
        targetController.hidesBottomBarWhenPushed) {
        return PPBottomSurfaceKindNone;
    }

    switch (preferredKind) {
        case PPBottomSurfaceKindFloatingCartSurface:
            if ([self pp_canShowFloatingCartSurfaceForController:targetController]) {
                return PPBottomSurfaceKindFloatingCartSurface;
            }
            return [self pp_fallbackKindForController:targetController];

        case PPBottomSurfaceKindViewerCartBottomBar:
        case PPBottomSurfaceKindSummaryBottomBar:
            if (!targetController.isViewLoaded) {
                return preferredKind;
            }
            return [self pp_controllerOwnedSurfaceViewForController:targetController kind:preferredKind]
                ? preferredKind
                : [self pp_fallbackKindForController:targetController];

        case PPBottomSurfaceKindPremiumTabBar:
        case PPBottomSurfaceKindNone:
        default:
            return preferredKind;
    }
}

- (void)applySurfaceForController:(UIViewController *)controller animated:(BOOL)animated
{
    UIViewController *targetController = [self pp_targetControllerFromController:controller];
    if (!targetController) {
        return;
    }

    PPRootTabBarController *targetRootController = [self pp_rootControllerForController:targetController];
    if (!targetRootController) {
        return;
    }

    PPBottomSurfaceKind requestedKind = [self resolvedSurfaceKindForController:targetController];
    UIViewController *previousController = self.activeController;
    PPBottomSurfaceKind previousKind = self.activeSurfaceKind;
    PPRootTabBarController *previousRootController = [self pp_rootControllerForController:previousController];

    if (previousController == targetController && previousKind == requestedKind) {
        self.activeController = targetController;
        self.activeSurfaceKind = requestedKind;
        [self pp_refreshStateForController:targetController kind:requestedKind];
        [self pp_presentSurfaceKind:requestedKind
                      forController:targetController
                              root:targetRootController
                          animated:NO
                             token:self.transitionToken];
        return;
    }

    BOOL reusesPersistentSurface =
        (previousKind == requestedKind &&
         (requestedKind == PPBottomSurfaceKindPremiumTabBar ||
          requestedKind == PPBottomSurfaceKindFloatingCartSurface));

    self.transitionToken += 1;
    NSUInteger token = self.transitionToken;

    if (reusesPersistentSurface) {
        self.activeController = targetController;
        self.activeSurfaceKind = requestedKind;
        [self pp_refreshStateForController:targetController kind:requestedKind];
        [self pp_presentSurfaceKind:requestedKind
                      forController:targetController
                              root:targetRootController
                          animated:NO
                             token:token];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_hideSurfaceKind:previousKind
               fromController:previousController
                         root:(previousRootController ?: targetRootController)
                     animated:animated
                   completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.transitionToken != token) {
            return;
        }

        strongSelf.activeController = targetController;
        strongSelf.activeSurfaceKind = requestedKind;
        [strongSelf pp_refreshStateForController:targetController kind:requestedKind];
        [strongSelf pp_presentSurfaceKind:requestedKind
                            forController:targetController
                                    root:targetRootController
                                animated:animated
                                   token:token];
    }];
}

#pragma mark - Resolution

- (PPBottomSurfaceKind)pp_fallbackKindForController:(UIViewController *)controller
{
    return controller.hidesBottomBarWhenPushed
        ? PPBottomSurfaceKindNone
        : PPBottomSurfaceKindPremiumTabBar;
}

- (BOOL)pp_controllerOverridesPreferredKind:(UIViewController *)controller
{
    Method defaultMethod = class_getInstanceMethod(UIViewController.class, @selector(pp_preferredBottomSurfaceKind));
    Method controllerMethod = class_getInstanceMethod(controller.class, @selector(pp_preferredBottomSurfaceKind));
    if (!defaultMethod || !controllerMethod) {
        return NO;
    }
    return method_getImplementation(defaultMethod) != method_getImplementation(controllerMethod);
}

- (BOOL)pp_canShowFloatingCartSurfaceForController:(UIViewController *)controller
{
    if (![self pp_isFloatingCartEligibleController:controller]) {
        return NO;
    }

    if ([[CartManager sharedManager] totalItemsCount] <= 0) {
        return NO;
    }

    return [self pp_floatingCartOpenHandlerForController:controller] != nil;
}

- (BOOL)pp_isFloatingCartEligibleController:(UIViewController *)controller
{
    if ([controller respondsToSelector:@selector(pp_isFloatingCartEligible)]) {
        BOOL (*eligibleFunc)(id, SEL) = (BOOL (*)(id, SEL))[controller methodForSelector:@selector(pp_isFloatingCartEligible)];
        if (eligibleFunc) {
            return eligibleFunc(controller, @selector(pp_isFloatingCartEligible));
        }
    }

    for (Class candidateClass = controller.class;
         candidateClass && candidateClass != UIViewController.class;
         candidateClass = class_getSuperclass(candidateClass)) {
        NSString *className = NSStringFromClass(candidateClass);
        if ([className isEqualToString:@"PPDataViewVC"] ||
            [className isEqualToString:@"SellerProfileVC"]) {
            return YES;
        }
    }
    return NO;
}

- (nullable UIViewController *)pp_targetControllerFromController:(UIViewController *)controller
{
    UIViewController *targetController = controller;
    while (targetController) {
        UIViewController *presentedController = targetController.presentedViewController;
        if (presentedController) {
            targetController = presentedController;
            continue;
        }
        if ([targetController isKindOfClass:UINavigationController.class]) {
            UINavigationController *navigationController = (UINavigationController *)targetController;
            UIViewController *nextController =
                navigationController.visibleViewController ?: navigationController.topViewController;
            if (!nextController || nextController == targetController) {
                break;
            }
            targetController = nextController;
            continue;
        }
        if ([targetController isKindOfClass:UITabBarController.class]) {
            UITabBarController *tabBarController = (UITabBarController *)targetController;
            UIViewController *nextController = tabBarController.selectedViewController;
            if (!nextController || nextController == targetController) {
                break;
            }
            targetController = nextController;
            continue;
        }
        break;
    }
    return targetController;
}

- (nullable PPRootTabBarController *)pp_rootControllerForController:(UIViewController *)controller
{
    UIViewController *candidateController = controller;
    while (candidateController) {
        if ([candidateController isKindOfClass:PPRootTabBarController.class]) {
            return (PPRootTabBarController *)candidateController;
        }
        candidateController = candidateController.parentViewController;
    }
    if ([controller.tabBarController isKindOfClass:PPRootTabBarController.class]) {
        return (PPRootTabBarController *)controller.tabBarController;
    }
    return nil;
}

#pragma mark - Presentation

- (void)pp_hideSurfaceKind:(PPBottomSurfaceKind)kind
             fromController:(UIViewController *)controller
                       root:(PPRootTabBarController *)rootController
                   animated:(BOOL)animated
                 completion:(dispatch_block_t)completion
{
    switch (kind) {
        case PPBottomSurfaceKindPremiumTabBar: {
            [rootController setPremiumTabDockViewHidden:YES animation:animated];
            [self pp_completeAfterDuration:([self pp_shouldAnimate:animated] ? [[self class] transitionOutDuration] : 0.0)
                                     block:completion];
            return;
        }

        case PPBottomSurfaceKindFloatingCartSurface: {
            if (controller) {
                [rootController pp_deactivateFloatingCartBarForSourceViewController:controller animated:animated];
            }
            [self pp_completeAfterDuration:([self pp_shouldAnimate:animated] ? [[self class] transitionOutDuration] : 0.0)
                                     block:completion];
            return;
        }

        case PPBottomSurfaceKindViewerCartBottomBar:
        case PPBottomSurfaceKindSummaryBottomBar: {
            UIView *surfaceView = [self pp_controllerOwnedSurfaceViewForController:controller kind:kind];
            [self pp_hideManagedSurfaceView:surfaceView
                              inController:controller
                                  animated:animated
                                completion:completion];
            return;
        }

        case PPBottomSurfaceKindNone:
        default:
            if (completion) {
                completion();
            }
            return;
    }
}

- (void)pp_presentSurfaceKind:(PPBottomSurfaceKind)kind
                forController:(UIViewController *)controller
                        root:(PPRootTabBarController *)rootController
                    animated:(BOOL)animated
                       token:(NSUInteger)token
{
    if (token != self.transitionToken) {
        return;
    }

    switch (kind) {
        case PPBottomSurfaceKindPremiumTabBar:
            [rootController setPremiumTabDockViewHidden:NO animation:animated];
            [self pp_refreshStateForController:controller kind:kind];
            return;

        case PPBottomSurfaceKindFloatingCartSurface: {
            PPCartFloatingBarOpenHandler openHandler = [self pp_floatingCartOpenHandlerForController:controller];
            if (openHandler) {
                [rootController pp_activateFloatingCartBarForSourceViewController:controller
                                                                   openCartHandler:openHandler
                                                                          animated:animated];
            } else {
                [rootController setPremiumTabDockViewHidden:NO animation:animated];
            }
            [self pp_refreshStateForController:controller kind:kind];
            return;
        }

        case PPBottomSurfaceKindViewerCartBottomBar:
        case PPBottomSurfaceKindSummaryBottomBar: {
            [rootController setPremiumTabDockViewHidden:YES animation:NO];
            UIView *surfaceView = [self pp_controllerOwnedSurfaceViewForController:controller kind:kind];
            [self pp_showManagedSurfaceView:surfaceView
                              inController:controller
                                  animated:animated];
            [self pp_refreshStateForController:controller kind:kind];
            return;
        }

        case PPBottomSurfaceKindNone:
        default:
            [rootController setPremiumTabDockViewHidden:YES animation:NO];
            [self pp_refreshStateForController:controller kind:kind];
            return;
    }
}

- (void)pp_hideManagedSurfaceView:(UIView *)surfaceView
                     inController:(UIViewController *)controller
                         animated:(BOOL)animated
                       completion:(dispatch_block_t)completion
{
    if (!surfaceView || !controller.isViewLoaded) {
        if (completion) {
            completion();
        }
        return;
    }

    [controller.view layoutIfNeeded];
    UIView *containerView = surfaceView.superview ?: controller.view;
    [containerView layoutIfNeeded];

    void (^applyHiddenState)(void) = ^{
        surfaceView.alpha = 0.0;
        surfaceView.transform = [self pp_reduceMotionEnabled]
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeTranslation(0.0, [self pp_translationDistanceForSurfaceView:surfaceView inController:controller]);
    };

    void (^finalizeHiddenState)(void) = ^{
        surfaceView.hidden = YES;
        surfaceView.userInteractionEnabled = NO;
        surfaceView.transform = CGAffineTransformIdentity;
        if (completion) {
            completion();
        }
    };

    if (![self pp_shouldAnimate:animated]) {
        applyHiddenState();
        finalizeHiddenState();
        return;
    }

    [UIView animateWithDuration:[[self class] transitionOutDuration]
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                     animations:applyHiddenState
                     completion:^(__unused BOOL finished) {
        finalizeHiddenState();
    }];
}

- (void)pp_showManagedSurfaceView:(UIView *)surfaceView
                     inController:(UIViewController *)controller
                         animated:(BOOL)animated
{
    if (!surfaceView || !controller.isViewLoaded) {
        return;
    }

    [controller.view layoutIfNeeded];
    UIView *containerView = surfaceView.superview ?: controller.view;
    [containerView layoutIfNeeded];
    [containerView bringSubviewToFront:surfaceView];

    surfaceView.hidden = NO;
    surfaceView.userInteractionEnabled = YES;
    surfaceView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;
    surfaceView.transform = [self pp_reduceMotionEnabled]
        ? CGAffineTransformIdentity
        : CGAffineTransformMakeTranslation(0.0, [self pp_translationDistanceForSurfaceView:surfaceView inController:controller]);

    if (![self pp_shouldAnimate:animated]) {
        surfaceView.alpha = 1.0;
        surfaceView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:[[self class] transitionInDuration]
                          delay:0.0
         usingSpringWithDamping:[[self class] transitionInSpringDamping]
          initialSpringVelocity:[[self class] transitionInSpringVelocity]
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        surfaceView.alpha = 1.0;
        surfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (CGFloat)pp_translationDistanceForSurfaceView:(UIView *)surfaceView
                                   inController:(UIViewController *)controller
{
    CGFloat height = CGRectGetHeight(surfaceView.bounds);
    if (height <= 1.0) {
        CGSize fittingSize = [surfaceView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        height = fittingSize.height;
    }
    CGFloat safeBottom = controller.view.safeAreaInsets.bottom;
    return MAX(24.0, ceil(height + safeBottom + 8.0));
}

#pragma mark - Controller Integration

- (nullable UIView *)pp_controllerOwnedSurfaceViewForController:(UIViewController *)controller
                                                           kind:(PPBottomSurfaceKind)kind
{
    if ([controller respondsToSelector:@selector(pp_bottomSurfaceView)]) {
        UIView * (*surfaceFunc)(id, SEL) = (UIView * (*)(id, SEL))[controller methodForSelector:@selector(pp_bottomSurfaceView)];
        if (surfaceFunc) {
            UIView *customView = surfaceFunc(controller, @selector(pp_bottomSurfaceView));
            if ([customView isKindOfClass:UIView.class]) {
                return customView;
            }
        }
    }

    NSString *key = nil;
    switch (kind) {
        case PPBottomSurfaceKindViewerCartBottomBar:
            key = @"bottomBar";
            break;
        case PPBottomSurfaceKindSummaryBottomBar:
            key = @"summaryView";
            break;
        default:
            break;
    }

    if (key.length == 0) {
        return nil;
    }

    @try {
        id candidate = [controller valueForKey:key];
        return [candidate isKindOfClass:UIView.class] ? (UIView *)candidate : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

- (nullable PPCartFloatingBarOpenHandler)pp_floatingCartOpenHandlerForController:(UIViewController *)controller
{
    SEL actionSelector = NULL;
    if ([controller respondsToSelector:NSSelectorFromString(@"pp_openCart")]) {
        actionSelector = NSSelectorFromString(@"pp_openCart");
    } else if ([controller respondsToSelector:NSSelectorFromString(@"onCartTapped")]) {
        actionSelector = NSSelectorFromString(@"onCartTapped");
    }

    if (!actionSelector) {
        return nil;
    }

    __weak UIViewController *weakController = controller;
    return ^{
        UIViewController *strongController = weakController;
        if (!strongController || ![strongController respondsToSelector:actionSelector]) {
            return;
        }
        void (*function)(id, SEL) = (void (*)(id, SEL))[strongController methodForSelector:actionSelector];
        if (function) {
            function(strongController, actionSelector);
        }
    };
}

- (void)pp_refreshStateForController:(UIViewController *)controller kind:(PPBottomSurfaceKind)kind
{
    if (!controller || !controller.isViewLoaded) {
        return;
    }

    switch (kind) {
        case PPBottomSurfaceKindViewerCartBottomBar:
            [self pp_invokeIfSupported:NSSelectorFromString(@"pp_syncBottomBarState") onTarget:controller];
            [self pp_invokeIfSupported:NSSelectorFromString(@"pp_updateViewportLayout") onTarget:controller];
            [self pp_invokeIfSupported:NSSelectorFromString(@"pp_updateBottomBarVisibility") onTarget:controller];
            break;

        case PPBottomSurfaceKindSummaryBottomBar:
            [self pp_invokeIfSupported:NSSelectorFromString(@"pp_updateSummaryPresentationHeightIfNeeded") onTarget:controller];
            break;

        case PPBottomSurfaceKindFloatingCartSurface:
        case PPBottomSurfaceKindPremiumTabBar:
        case PPBottomSurfaceKindNone:
        default:
            break;
    }

    [self pp_invokeIfSupported:NSSelectorFromString(@"pp_updateBottomNavigationInsetsIfNeeded") onTarget:controller];
    [self pp_invokeIfSupported:NSSelectorFromString(@"updateCollectionContentInset") onTarget:controller];
    [controller.view layoutIfNeeded];
}

- (void)pp_invokeIfSupported:(SEL)selector onTarget:(id)target
{
    if (!target || !selector || ![target respondsToSelector:selector]) {
        return;
    }
    void (*function)(id, SEL) = (void (*)(id, SEL))[target methodForSelector:selector];
    if (function) {
        function(target, selector);
    }
}

#pragma mark - Animation Helpers

- (BOOL)pp_reduceMotionEnabled
{
    return UIAccessibilityIsReduceMotionEnabled();
}

- (BOOL)pp_shouldAnimate:(BOOL)animated
{
    return animated && ![self pp_reduceMotionEnabled];
}

- (void)pp_completeAfterDuration:(NSTimeInterval)duration block:(dispatch_block_t)block
{
    if (!block) {
        return;
    }
    if (duration <= 0.0) {
        block();
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   block);
}

@end
