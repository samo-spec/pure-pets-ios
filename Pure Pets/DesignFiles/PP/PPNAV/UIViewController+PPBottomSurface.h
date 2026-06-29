#import <UIKit/UIKit.h>
#import "PPBottomSurfaceCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (PPBottomSurface)

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind;
- (void)pp_applyBottomSurfaceAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
