//
//  PPNavigationController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 07/10/2025.
//


#import <UIKit/UIKit.h>
 


//
// UIViewController+ModalBBNav.h
// Adds a programmatic nav bar when VC is presented without a UINavigationController.
// Uses BBNavigationBar if available; otherwise falls back to UINavigationBar.
// Minimal, drop-in, Objective-C (iOS 16+).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (ModalBBNav)

- (void)ensureModalNavigationBarIfNeeded;
- (void)removeModalNavigationBarIfNeeded;
- (void)updateModalNavigationBarItems;

@end
 





@interface PPNavBarContainer : UIView
@end

 


@interface PPNavigationBar : UINavigationBar
@end




@interface PPNavigationController : UINavigationController
@end
 



@interface PPBarItemWrapper : UIView
@end





@interface UIViewController (ModalNav)
- (void)ensureModalNavigationBarIfNeeded;
- (void)removeModalNavigationBarIfNeeded;
@end




@interface PPFadeAnimator : NSObject <UIViewControllerAnimatedTransitioning>
- (instancetype)initWithPresenting:(BOOL)presenting;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL crossfadeContents;

@end







@interface PPNavigationFadeDelegate : NSObject <UINavigationControllerDelegate, UITabBarControllerDelegate>

+ (instancetype)sharedInstance;

/// Animator duration for all transitions handled by this delegate.
@property (nonatomic, assign) NSTimeInterval animationDuration;

/// If YES, apply fade when switching tabs as well.
@property (nonatomic, assign) BOOL enableTabFade;
- (void)setFadeAllowedForViewControllerClasses:(NSArray<Class> * _Nullable)classes;
@property (nonatomic, strong)  NSSet * _Nullable allowedClasses;


@end





 






typedef NS_ENUM(NSInteger, PPTransitionStyle) {
    PPTransitionStyleNone = 0,
    PPTransitionStyleFade,
    PPTransitionStyleCustom
};

@protocol PPTransitioning <NSObject>
@optional
- (PPTransitionStyle)pp_transitionStyle;
@end



 


@interface UIViewController (PPTransition)

@property (nonatomic, assign) PPTransitionStyle pp_transitionStyle;

@end




@interface UIBarButtonItem (Badge)

@property (strong, nonatomic) UILabel * _Nullable pp_badgeLabel;

- (void)pp_setBadgeValue:(NSString * _Nullable)value;
- (void)pp_removeBadge;

@end
NS_ASSUME_NONNULL_END
