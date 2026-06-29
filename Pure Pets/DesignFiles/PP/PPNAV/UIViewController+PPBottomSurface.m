#import "UIViewController+PPBottomSurface.h"

@implementation UIViewController (PPBottomSurface)

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindPremiumTabBar;
}

- (void)pp_applyBottomSurfaceAnimated:(BOOL)animated
{
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:self animated:animated];
}

@end
