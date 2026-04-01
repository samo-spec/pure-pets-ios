//
//  NewAppVC.m
//  PurePets
//

#import "NewAppVC.h"
 
#define PPLog(fmt, ...) NSLog((@"[NewAppVC] " fmt), ##__VA_ARGS__)

@interface NewAppVC ()

@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIViewController *currentVC;
@property (nonatomic, strong) PPOverlayCoordinator *overlay;

// ADD THIS
- (UIViewController *)buildRootController;

@end

@implementation NewAppVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.overlay = [[PPOverlayCoordinator alloc] initWithPresenter:self];
    
    [self switchToTab:PPAppTabHome];
    
   
}
 

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

#pragma mark - Language

- (void)handleLanguageDidChange {

    
}

#pragma mark - Root Builder

- (UIViewController *)buildRootController {

    // This MUST mirror your app’s real root creation logic
    // If you already have this in AppManager / AppDelegate,
    // call it from here instead of duplicating.

    NewAppVC *root = [[NewAppVC alloc] init];
    return root;
}

- (UIWindow *)keyWindow {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Navigation

- (void)switchToTab:(PPAppTab)tab {
    if (!self.contentContainer) {
        self.contentContainer = [[UIView alloc] init];
        self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.contentContainer];

        [NSLayoutConstraint activateConstraints:@[
            [self.contentContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    }

    UIViewController *vc = [self viewControllerForTab:tab];
    if (!vc) return;

    if (self.currentVC) {
        [self.currentVC willMoveToParentViewController:nil];
        [self.currentVC.view removeFromSuperview];
        [self.currentVC removeFromParentViewController];
    }

    self.currentVC = vc;

    [self addChildViewController:vc];
    vc.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:vc.view];
   
    [NSLayoutConstraint activateConstraints:@[
        [vc.view.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [vc.view.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [vc.view.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [vc.view.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor]
    ]];

    [vc didMoveToParentViewController:self];

    PPLog(@"Switched tab: %ld", (long)tab);
}

- (UIViewController *)viewControllerForTab:(PPAppTab)tab {
    PPHomeViewController *vc = [PPHomeViewController new];
    vc.view.backgroundColor = AppBackgroundClr;

    UILabel *label = [[UILabel alloc] init];
    label.font = [GM boldFontWithSize:22];
    label.textColor = AppPrimaryTextClr;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    switch (tab) {
        case PPAppTabHome:
            return [[PPHomeViewController alloc] init];
            break;
        case PPAppTabNotifications:
            label.text = @"Notifications";
            break;
        case PPAppTabAddNew:
            label.text = @"";
            break;
        case PPAppTabOrders:
            label.text = @"Orders";
            break;
        case PPAppTabCart:
            label.text = @"cart";
            break;
    }

    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor]
    ]];

    return vc;
}

#pragma mark - PPBottomBarDelegate

- (void)bottomBarDidSelectTab:(PPAppTab)tab {
    [self switchToTab:tab];
}

- (void)bottomBarDidTapAdd {
    [self.overlay presentOverlay:PPOverlayTypeAddActions];
}

@end
