//
//  UITabBarItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/12/2025.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPMainTabBarItemsHelper : NSObject

/// Apply items to tab bar with animation and safe reselect
+ (void)setTabBar:(UITabBar *)tabBar
            items:(NSArray<UITabBarItem *> *)items
         animated:(BOOL)animated;

/// Convenience
+ (void)showIconsOnlyOnTabBar:(UITabBar *)tabBar
                        items:(NSArray<UITabBarItem *> *)iconsOnly
                     animated:(BOOL)animated;

+ (void)showIconsAndTitlesOnTabBar:(UITabBar *)tabBar
                             items:(NSArray<UITabBarItem *> *)iconsAndTitles
                          animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END






NS_ASSUME_NONNULL_BEGIN
@interface UITabBarItem (PPAdditions)

/// Wiggle a UIBarButtonItem (safe, system-like)
+ (void)wiggleBarButtonItem:(UIBarButtonItem *)item;

/// Stop wiggle if running
+ (void)stopWiggleOnBarButtonItem:(UIBarButtonItem *)item;

+ (UITabBarItem *)pp_tabBarItemWithInfo:(NSDictionary *)info;
+ (NSArray<NSDictionary *> *)tabBarItemsIconsOnlyDict;
+ (NSArray<NSDictionary *> *)tabBarItemsIconsAndTitlesDict;
@end


@interface UIView (PPCutout)

/// Cuts out (makes transparent) the area *below* `subview` within `self`,
/// so content behind `self` is visible.
/// Call this from `layoutSubviews`/`viewDidLayoutSubviews` after layout is final.
///
/// @param subview      The subview whose bottom edge defines the start of the cutout.
/// @param cornerRadius Optional corner radius for the cutout's top edge.
/// @param extraPadding Extra vertical padding between subview.bottom and cutout start.
- (void)pp_applyBottomCutoutStartingBelowSubview:(UIView *)subview
                                   cornerRadius:(CGFloat)cornerRadius
                                   extraPadding:(CGFloat)extraPadding;

/// Removes any cutout mask previously applied.
- (void)pp_clearCutoutMask;

@end

NS_ASSUME_NONNULL_END


 


 
NS_ASSUME_NONNULL_BEGIN

@interface PPBarButtonWiggleHelper : NSObject

/// Wiggle a UIBarButtonItem (safe, system-like)
+ (void)wiggleBarButtonItem:(UIBarButtonItem *)item;

/// Stop wiggle if running
+ (void)stopWiggleOnBarButtonItem:(UIBarButtonItem *)item;

@end

NS_ASSUME_NONNULL_END
