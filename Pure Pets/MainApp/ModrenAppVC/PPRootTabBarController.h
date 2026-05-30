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
#import "BottomOptionsViewController.h"
#import "PPSelectOptionViewController.h"
#import "OrderHistoryViewController.h"
#import "AddNewAccessory.h"
#import "AddAdoptPetViewController.h"


NS_ASSUME_NONNULL_BEGIN
 
@interface PPRootTabBarController : UITabBarController <UITabBarControllerDelegate>
- (void)setPremiumTabDockViewHidden:(BOOL)hidden animation:(BOOL)animated;
- (void)pp_setBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated;
@end


NS_ASSUME_NONNULL_END
