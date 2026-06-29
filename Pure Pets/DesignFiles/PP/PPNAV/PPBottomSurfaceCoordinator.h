#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPBottomSurfaceKind) {
    PPBottomSurfaceKindNone = 0,
    PPBottomSurfaceKindPremiumTabBar,
    PPBottomSurfaceKindViewerCartBottomBar,
    PPBottomSurfaceKindFloatingCartSurface,
    PPBottomSurfaceKindSummaryBottomBar
};

@interface PPBottomSurfaceCoordinator : NSObject

@property (nonatomic, assign, readonly) PPBottomSurfaceKind activeSurfaceKind;
@property (nonatomic, weak, readonly, nullable) UIViewController *activeController;

+ (instancetype)sharedCoordinator;

- (PPBottomSurfaceKind)resolvedSurfaceKindForController:(nullable UIViewController *)controller;
- (void)applySurfaceForController:(nullable UIViewController *)controller animated:(BOOL)animated;

+ (NSTimeInterval)transitionOutDuration;
+ (NSTimeInterval)transitionInDuration;
+ (CGFloat)transitionInSpringDamping;
+ (CGFloat)transitionInSpringVelocity;

@end

NS_ASSUME_NONNULL_END
