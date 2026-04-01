//
//  PPOverlayCoordinator.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/12/2025.
//


//
//  PPOverlayCoordinator.h
//  PurePets
//

#import <UIKit/UIKit.h>


typedef NS_ENUM(NSInteger, PPOverlayType) {
    PPOverlayTypeAddActions,
    PPOverlayTypeCategoryPicker,
    PPOverlayTypeProfileMenu,
    PPOverlayTypeNearbyAdsViewer,
    PPOverlayTypeAccessoriesViewer,
    PPOverlayTypeChatsPush,
    PPOverlayTypeChatsSheet
};



NS_ASSUME_NONNULL_BEGIN

@interface PPOverlayCoordinator : NSObject
- (UIViewController *)buildDetailViewerForObject:(id)object fromPresenter:(UIViewController *)presenter;
- (instancetype)initWithPresenter:(UIViewController *)presenter;
- (void)presentOverlay:(PPOverlayType)type;
- (void)dismissOverlay;
+ (nullable UIViewController *)pp_resolvedPresenterFrom:(nullable UIViewController *)source;
+ (BOOL)pp_canPresentFrom:(nullable UIViewController *)presenter;
+ (void)pp_openChatThread:(ChatThreadModel *)thread fromVC:(UIViewController *)vc;
+ (void)pp_openDetailForObject:(id)object
                        fromVC:(UIViewController *)vc
                    routingNav:(nullable PPNavigationController *)routingNav;
- (void)openChatThread:(ChatThreadModel *)thread;
@end

NS_ASSUME_NONNULL_END
