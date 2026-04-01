//
//  UITabBarItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/12/2025.
//


#import "UITabBarItem+PPAdditions.h"


@implementation PPMainTabBarItemsHelper

#pragma mark - Public API

+ (void)setTabBar:(UITabBar *)tabBar
            items:(NSArray<UITabBarItem *> *)items
         animated:(BOOL)animated
{
    if (!tabBar || items.count == 0) return;

    // 1️⃣ Capture current selection safely
    NSUInteger selectedIndex = NSNotFound;
    if (tabBar.selectedItem) {
        selectedIndex = [tabBar.items indexOfObject:tabBar.selectedItem];
    }
    if (selectedIndex == NSNotFound || selectedIndex >= items.count) {
        selectedIndex = 0;
    }

    // 2️⃣ Animation block
    void (^applyItems)(void) = ^{
        tabBar.items = items;
        tabBar.selectedItem = items[selectedIndex];
        [tabBar setNeedsLayout];
        [tabBar layoutIfNeeded];
    };

    if (!animated) {
        applyItems();
        return;
    }

    // 3️⃣ Modern crossfade + slight lift (system-like)
   // UIView *container = tabBar;
    [UIView animateWithDuration:0.35 animations:^{
        applyItems();
    } completion:nil];
}

+ (void)showIconsOnlyOnTabBar:(UITabBar *)tabBar
                        items:(NSArray<UITabBarItem *> *)iconsOnly
                     animated:(BOOL)animated
{
    [self setTabBar:tabBar items:iconsOnly animated:animated];
}

+ (void)showIconsAndTitlesOnTabBar:(UITabBar *)tabBar
                             items:(NSArray<UITabBarItem *> *)iconsAndTitles
                          animated:(BOOL)animated
{
    [self setTabBar:tabBar items:iconsAndTitles animated:animated];
}

@end




@implementation UITabBarItem (PPAdditions)


+ (void)wiggleBarButtonItem:(UIBarButtonItem *)item
{
    UIView *view = [self _viewForBarButtonItem:item];
    if (!view) return;

    // Prevent stacking animations
    [self stopWiggleOnBarButtonItem:item];

    CAKeyframeAnimation *wiggle = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    wiggle.values = @[
        @(0),
        @(M_PI / 32),
        @(-M_PI / 32),
        @(M_PI / 40),
        @(-M_PI / 40),
        @(0)
    ];
    wiggle.duration = 0.45;
    wiggle.repeatCount = 2;
    wiggle.timingFunction =
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [view.layer addAnimation:wiggle forKey:@"pp_wiggle"];
}

+ (void)stopWiggleOnBarButtonItem:(UIBarButtonItem *)item
{
    UIView *view = [self _viewForBarButtonItem:item];
    [view.layer removeAnimationForKey:@"pp_wiggle"];
}

#pragma mark - Private

/// Safely resolves the underlying view of UIBarButtonItem
+ (UIView *)_viewForBarButtonItem:(UIBarButtonItem *)item
{
    if (item.customView) {
        return item.customView;
    }

    // UIKit-internal view resolution (safe, read-only)
    UIView *view = [item valueForKey:@"view"];
    return [view isKindOfClass:[UIView class]] ? view : nil;
}



+ (NSArray<NSDictionary *> *)tabBarItemsIconsOnlyDict
{
    return  @[
        @{
            @"icon": @"dogCus",
            @"tag": @(0)  // Assuming PPBarTagHome = 0
        },
        @{
            @"icon": @"love-birdsCus",
            @"tag": @(1)
        },
        @{
            @"icon": @"archiveCus",
            @"tag": @(2)
        },
        @{
            @"icon": @"deleteCus",
            @"tag": @(3)
        },
        @{
            @"icon": @"hotSalee",
            @"tag": @(4)
        }
    ];
}


+ (NSArray<NSDictionary *> *)tabBarItemsIconsAndTitlesDict
{
    return  @[
        @{
            @"icon": @"dogCus",
            @"title": kLang(@"Cards"),
            @"tag": @(0)  // Assuming PPBarTagHome = 0
        },
        @{
            @"icon": @"love-birdsCus",
            @"title": kLang(@"cages"),
            @"tag": @(1)
        },
        @{
            @"icon": @"archiveCus",
            @"title": kLang(@"Archive"),
            @"tag": @(2)
        },
        @{
            @"icon": @"deleteCus",
            @"title": kLang(@"Trash"),
            @"tag": @(3)
        },
        @{
            @"icon": @"hotSaleee",
            @"title": kLang(@"sales"),
            @"tag": @(4)
        }
    ];
}

+ (UITabBarItem *)pp_tabBarItemWithInfo:(NSDictionary *)info {

    NSString *iconName     = info[@"icon"];
    NSString *title        = info[@"title"];
    NSInteger tag          = [info[@"tag"] integerValue];

    NSString *iconNameFill = [NSString stringWithFormat:@"%@.fill", iconName];

    UIColor *primaryClr    = [AppPrimaryClr colorWithAlphaComponent:1.5];

    UIImage *normalImage =
        [UIImage systemImageNamed:iconName]
        ? [UIImage pp_symbolNamed:iconName
                         pointSize:19
                            weight:UIImageSymbolWeightSemibold
                             scale:UIImageSymbolScaleMedium
                           palette:@[AppButtonMixColorClr, AppButtonMixColorClr]
                      makeTemplate:YES]
        : [UIImage imageNamed:iconName];

    UIImage *selectedImage =
        [UIImage systemImageNamed:iconNameFill]
        ? [UIImage pp_symbolNamed:iconNameFill
                         pointSize:20
                            weight:UIImageSymbolWeightSemibold
                             scale:UIImageSymbolScaleMedium
                           palette:@[primaryClr, primaryClr]
                      makeTemplate:YES]
        : [UIImage imageNamed:iconNameFill];

    UITabBarItem *item =
        [[UITabBarItem alloc] initWithTitle:title
                                      image:normalImage
                              selectedImage:selectedImage];

    item.tag = tag;
    return item;
}

@end

 











@implementation UIView (PPCutout)

- (void)pp_applyBottomCutoutStartingBelowSubview:(UIView *)subview
                                     cornerRadius:(CGFloat)cornerRadius
                                     extraPadding:(CGFloat)extraPadding
{
    if (!subview || !subview.superview) {
        self.layer.mask = nil;
        return;
    }

    // 1. Ensure we have a valid layout
    [self layoutIfNeeded];
    [subview layoutIfNeeded];

    // 2. Convert subview frame into self’s coordinate space
    CGRect subFrameInSelf = [self convertRect:subview.bounds fromView:subview];

    CGFloat cutoutStartY = CGRectGetMaxY(subFrameInSelf) + extraPadding;
    CGFloat boundsHeight = CGRectGetHeight(self.bounds);
    CGFloat boundsWidth  = CGRectGetWidth(self.bounds);

    if (cutoutStartY >= boundsHeight) {
        // Nothing to cut; entire view stays visible
        self.layer.mask = nil;
        return;
    }

    // 3. Define the visible region as a rect from top down to cutoutStartY
    CGRect visibleRect = CGRectMake(0.0,
                                    0.0,
                                    boundsWidth,
                                    cutoutStartY);

    // 4. Build path for visible region (we can round the bottom corners if desired)
    UIBezierPath *path;
    if (cornerRadius > 0.0) {
        // Rounded bottom corners
        path = [UIBezierPath bezierPathWithRoundedRect:visibleRect
                                      byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                            cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
    } else {
        path = [UIBezierPath bezierPathWithRect:visibleRect];
    }

    // 5. Create mask layer
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.bounds;
    maskLayer.path  = path.CGPath;

    // For a simple "show only visibleRect" we don't need even-odd rule.
    // The rest of the view (below visibleRect) becomes transparent.
    maskLayer.fillRule = kCAFillRuleNonZero;

    self.layer.mask = maskLayer;
}

- (void)pp_clearCutoutMask {
    self.layer.mask = nil;
}

@end






 



 #import <QuartzCore/QuartzCore.h>

@implementation PPBarButtonWiggleHelper

#pragma mark - Public

+ (void)wiggleBarButtonItem:(UIBarButtonItem *)item
{
    UIView *view = [self _viewForBarButtonItem:item];
    if (!view) return;

    // Prevent stacking animations
    [self stopWiggleOnBarButtonItem:item];

    CAKeyframeAnimation *wiggle = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    wiggle.values = @[
        @(0),
        @(M_PI / 32),
        @(-M_PI / 32),
        @(M_PI / 40),
        @(-M_PI / 40),
        @(0)
    ];
    wiggle.duration = 0.45;
    wiggle.repeatCount = 2;
    wiggle.timingFunction =
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [view.layer addAnimation:wiggle forKey:@"pp_wiggle"];
}

+ (void)stopWiggleOnBarButtonItem:(UIBarButtonItem *)item
{
    UIView *view = [self _viewForBarButtonItem:item];
    [view.layer removeAnimationForKey:@"pp_wiggle"];
}

#pragma mark - Private

/// Safely resolves the underlying view of UIBarButtonItem
+ (UIView *)_viewForBarButtonItem:(UIBarButtonItem *)item
{
    if (item.customView) {
        return item.customView;
    }

    // UIKit-internal view resolution (safe, read-only)
    UIView *view = [item valueForKey:@"view"];
    return [view isKindOfClass:[UIView class]] ? view : nil;
}

@end

