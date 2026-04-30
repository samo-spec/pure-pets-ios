//
//  PPOverlayCoordinator 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/12/2025.
//


//
//  PPOverlayCoordinator.m
//  PurePets
//

#import "PPOverlayCoordinator.h"
#import "AccessViewerVC.h"
#import "ChMessagingController.h"
#import "PetCare/PPPetCareVetViewrVC.h"
#define PPLog(fmt, ...) NSLog((@"[Overlay] " fmt), ##__VA_ARGS__)

@interface PPOverlayCoordinator ()
@property (nonatomic, weak) UIViewController *presenter;
@end

@implementation PPOverlayCoordinator

+ (UIViewController *)pp_resolvedPresenterFrom:(UIViewController *)source
{
    if (!source) {
        return nil;
    }

    UIViewController *presenter = source;

    if ([presenter isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)presenter;
        UIViewController *selected = tab.selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) {
            presenter = ((UINavigationController *)selected).topViewController ?: selected;
        } else if (selected) {
            presenter = selected;
        }
    } else if ([presenter isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)presenter;
        presenter = nav.topViewController ?: nav;
    }

    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) {
        presenter = presenter.presentedViewController;
    }

    if ([presenter isKindOfClass:[UIAlertController class]]) {
        presenter = presenter.presentingViewController ?: presenter;
    }

    return presenter;
}

+ (BOOL)pp_canPresentFrom:(UIViewController *)presenter
{
    if (!presenter) {
        return NO;
    }
    if (!presenter.view.window) {
        return NO;
    }
    if (presenter.isBeingPresented || presenter.isBeingDismissed) {
        return NO;
    }
    if (presenter.transitionCoordinator) {
        return NO;
    }
    if (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) {
        return NO;
    }
    return YES;
}

- (instancetype)initWithPresenter:(UIViewController *)presenter {
    if (self = [super init]) {
        _presenter = presenter;
    }
    return self;
}

- (UIViewController *)viewControllerForOverlayType:(NSInteger)type {
    UIViewController *vc = nil;

    switch (type) {

        case PPOverlayTypeAddActions:
            //vc = [self buildAddActionsVC];
            PPLog(@"Present Add Actions");
            break;
 
    }
    return vc;
}

- (void)configureSheetIfNeeded:(UIViewController *)vc {
    if (!vc) return;
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    vc.sheetPresentationController.detents = @[
        UISheetPresentationControllerDetent.mediumDetent,
        UISheetPresentationControllerDetent.largeDetent
    ];
    vc.sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = NO;
    vc.sheetPresentationController.prefersGrabberVisible = YES;
    vc.sheetPresentationController.preferredCornerRadius = 32;
}

-(void)presentOverlay:(PPOverlayType)type {
    UIViewController *presenter = [PPOverlayCoordinator pp_resolvedPresenterFrom:self.presenter];
    if (![PPOverlayCoordinator pp_canPresentFrom:presenter]) return;
    
    UIViewController *vc = [self viewControllerForOverlayType:type];
    if (!vc) return;

    [self configureSheetIfNeeded:vc];

    UIImpactFeedbackGenerator *gen =
    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    [presenter presentViewController:vc animated:YES completion:nil];
}

- (void)dismissOverlay {
    [self.presenter dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Builders

- (UIViewController *)baseOverlayVC {
    UIViewController *vc = [UIViewController new];

    vc.view.backgroundColor = [UIColor clearColor];

    UIBlurEffect *blur =
    [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];

    UIVisualEffectView *blurView =
    [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;

    [vc.view addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:vc.view.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor]
    ]];

    return vc;
}

  
 

#pragma mark - Viewer Builders

- (UIViewController *)buildDetailViewerForObject:(id)object fromPresenter:(UIViewController *)presenter {
    UIViewController *detailVC = nil;
    if ([object isKindOfClass:NSClassFromString(@"PetAd")]) {
        // ViewerVC for PetAd
        Class ViewerVCClass = NSClassFromString(@"ViewerVC");
        if (ViewerVCClass) {
            ViewerVC *vc = [[ViewerVCClass alloc] init];
            vc.ad = (PetAd *)object;
            vc.hidesBottomBarWhenPushed = YES;
            detailVC = vc;
            return detailVC;
        }
    } else if ([object isKindOfClass:NSClassFromString(@"PetAccessory")]) {
        // AccessViewerVC for PetAccessory — returned bare for push navigation
        Class AccessViewerVCClass = NSClassFromString(@"AccessViewerVC");
        if (AccessViewerVCClass) {
            AccessViewerVC *vc = [[AccessViewerVCClass alloc] init];
            vc.accessAds = (PetAccessory *)object;
            vc.hidesBottomBarWhenPushed = YES;
            return vc;  // Caller pushes directly onto nav stack
        }
    }
    if (!detailVC) return nil;
    // Wrap in PPNavigationController
    Class NavClass = NSClassFromString(@"PPNavigationController");
    UIViewController *wrapped = detailVC;
    if (NavClass) {
        wrapped = [[NavClass alloc] initWithRootViewController:detailVC];
    }
    wrapped.modalInPresentation = YES;
    if (@available(iOS 16.0, *)) {
        wrapped.modalPresentationStyle = UIModalPresentationPageSheet;
    } else {
        wrapped.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return wrapped;
}
 
#pragma mark - Static Routing Entry (USED BY HOME)


// MARK: - Chat Routing

- (void)openChatThread:(ChatThreadModel *)thread
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    if (!thread) return;

    UIViewController *presenter = [PPOverlayCoordinator pp_resolvedPresenterFrom:self.presenter];
    if (![PPOverlayCoordinator pp_canPresentFrom:presenter]) return;
 
    //ChMessagingController *chatVC =
     //   [[ChMessagingController alloc] initWithChatThread:thread];
     //[PPFunc presentFloatingSheetFrom:presenter sheetVC:chatVC detentStyle:PPSheetDetentStyleSemiLargAndLarge];
    //[nav pushViewController:chatVC animated:YES];
    
    ChMessagingController *chat =
        [[ChMessagingController alloc] initWithChatThread:thread];

    PPNavigationController *nav =
        [[PPNavigationController alloc] initWithRootViewController:chat];

    nav.modalPresentationStyle = UIModalPresentationFullScreen;

    [presenter presentViewController:nav animated:YES completion:nil];
}


+ (void)pp_openChatThread:(ChatThreadModel *)thread
                   fromVC:(UIViewController *)vc
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    NSLog(@"💬 [Chat] Request to open chat thread");

    if (!thread) {
        NSLog(@"❌ [Chat] Thread is nil, aborting navigation");
        return;
    }

    if (!vc) {
        NSLog(@"❌ [Chat] Source view controller is nil");
        return;
    }
    UIViewController *presenter = [self pp_resolvedPresenterFrom:vc];
    if (![self pp_canPresentFrom:presenter]) {
        NSLog(@"⚠️ [Chat] Presenter is busy, dropping duplicate open request");
        return;
    }

    NSLog(@"📨 [Chat] Thread info | threadID=%@ | messagesCount=%ld",
          thread.ID,
          (long)thread.messagesCount);

    
    NSLog(@"➡️ [Chat] Pushing ChMessagingController");

    ChMessagingController *chat =
        [[ChMessagingController alloc] initWithChatThread:thread];

    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:chat];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [presenter presentViewController:nav animated:YES completion:nil];

    NSLog(@"✅ [Chat] Chat screen pushed successfully");
}


+ (void)pp_openDetailForObject:(id)object
                        fromVC:(UIViewController *)vc
                    routingNav:(nullable PPNavigationController *)routingNav
{
    if (!object || !vc) return;

    UIViewController *targetVC = nil;
    UIViewController *presentingVC = [self pp_resolvedPresenterFrom:vc];
    if (!presentingVC || presentingVC.isBeingPresented || presentingVC.isBeingDismissed) {
        return;
    }

    // 🐾 PetAd → ViewerVC
    if ([object isKindOfClass:[PetAd class]]) {
        ViewerVC *viewer = [ViewerVC new];
        viewer.ad = (PetAd *)object;
        viewer.hidesBottomBarWhenPushed = YES;
        targetVC = viewer;

        UINavigationController *nav = routingNav ?: presentingVC.navigationController;
        if (!nav && vc.navigationController) {
            nav = vc.navigationController;
        }

        if (nav) {
            [nav pushViewController:targetVC animated:YES];
        } else {
            PPNavigationController *newNav =
                [[PPNavigationController alloc] initWithRootViewController:targetVC];
            newNav.modalPresentationStyle = UIModalPresentationFullScreen;
            [presentingVC presentViewController:newNav animated:YES completion:nil];
        }
    }

    // 🧩 PetAccessory → AccessViewerVC (push navigation)
    else if ([object isKindOfClass:[PetAccessory class]]) {
        AccessViewerVC *viewer = [AccessViewerVC new];
        viewer.accessAds = (PetAccessory *)object;
        viewer.hidesBottomBarWhenPushed = YES;

        if ([vc conformsToProtocol:@protocol(CartQuantityFromViewerDelegate)]) {
            viewer.QtyDelegate = (id<CartQuantityFromViewerDelegate>)vc;
        }
        targetVC = viewer;

        // Push onto existing navigation stack
        UINavigationController *nav = routingNav ?: presentingVC.navigationController;
        if (nav) {
            [nav pushViewController:targetVC animated:YES];
        } else {
            // Fallback: wrap in nav and push
            PPNavigationController *newNav =
                [[PPNavigationController alloc] initWithRootViewController:targetVC];
            newNav.modalPresentationStyle = UIModalPresentationFullScreen;
            [presentingVC presentViewController:newNav animated:YES completion:nil];
        }
    }

    // 🧰 Service
    else if ([object isKindOfClass:[ServiceModel class]]) {
        ServiceViewerViewController *viewer = [ServiceViewerViewController new];
        viewer.service = (ServiceModel *)object;
        targetVC = viewer;
        [PPFunc presentSheetFrom:presentingVC sheetVC:targetVC detentStyle:PPSheetDetentStyleLargeOnly];
    }

    // 🏥 Vet
    else if ([object isKindOfClass:[VetModel class]]) {
        PPPetCareVetViewrVC *viewer = [[PPPetCareVetViewrVC alloc] initWithVet:(VetModel *)object
                                                                  mainKindName:nil];
        targetVC = viewer;
        [PPFunc presentSheetFrom:presentingVC sheetVC:targetVC detentStyle:PPSheetDetentStyleLargeOnly];
    }

    if (!targetVC) {
        NSLog(@"⚠️ [OverlayCoordinator] Unsupported object: %@", object);
        return;
    }
}


+ (void)setShadowToView:(UIView *)view
{
    if (!view) return;

    // Always allow shadow to render
    view.layer.masksToBounds = NO;

    // Shadow color (dynamic, works in dark/light)
    [view pp_setShadowColor:[UIColor blackColor]];

    // Soft, modern shadow
    view.layer.shadowOpacity = 0.82;
    view.layer.shadowRadius  = 4.0;
    view.layer.shadowOffset  = CGSizeMake(2, 2);

    // 🔑 Performance optimization (VERY IMPORTANT)
    // Match your corner radius if set
    CGFloat radius = view.layer.cornerRadius > 0 ? view.layer.cornerRadius : 16.0;
    view.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:view.bounds
                                   cornerRadius:radius].CGPath;

    // Improve animation quality
    view.layer.shouldRasterize = YES;
    view.layer.rasterizationScale = UIScreen.mainScreen.scale;
}

@end
 
