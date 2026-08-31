//
//  PPBottomBarView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/12/2025.
//


//
//  PPBottomBarView.h
//  PurePets
//

#import <UIKit/UIKit.h>
#import "UserChatsViewController.h"
 
#import "PPSelectOptionViewController.h"
#import "OrderHistoryViewController.h"
#import "AddNewAccessory.h"
#import "AddAdoptPetViewController.h"


NS_ASSUME_NONNULL_BEGIN

typedef void (^PPCartFloatingBarOpenHandler)(void);
@class ChatThreadModel;
@class PPRootSwiftCoordinator;
 
@interface PPRootTabBarController : UITabBarController <UITabBarControllerDelegate>
@property (nonatomic, strong, nullable) PPRootSwiftCoordinator *swiftCoordinator;
- (void)setPremiumTabDockViewHidden:(BOOL)hidden animation:(BOOL)animated;
- (void)pp_setBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated;
- (nullable UIView *)pp_novaAmbientBottomNavigationAnchorView;
- (CGFloat)pp_currentBottomNavigationContentClearance;
- (void)pp_activateFloatingCartBarForSourceViewController:(UIViewController *)viewController
                                          openCartHandler:(PPCartFloatingBarOpenHandler)openCartHandler
                                                 animated:(BOOL)animated;
- (void)pp_deactivateFloatingCartBarForSourceViewController:(UIViewController *)viewController
                                                   animated:(BOOL)animated;
- (BOOL)pp_openChatThreadFromNotification:(ChatThreadModel *)thread animated:(BOOL)animated;
- (BOOL)pp_openNotificationsInboxAnimated:(BOOL)animated;

/// Opens the existing listing editor for a PureLens-created draft. The editor
/// remains host-owned; prefill values are advisory and never publish directly.
- (void)pp_openListingDraftWithPrefill:(NSDictionary<NSString *, NSString *> *)prefill
    NS_SWIFT_NAME(pp_openListingDraft(prefill:));

- (void)pp_setCustomAccentColor:(nullable UIColor *)accentColor;
@end


NS_ASSUME_NONNULL_END
