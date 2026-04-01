//
//  BBNavigationBar 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/01/2026.
//


#import "BBNavigationBar.h"

@interface BBNavigationBar ()
@property (nonatomic, weak) UIViewController *vc;
@end

@implementation BBNavigationBar

#pragma mark - Public

- (void)attachTo:(UIViewController *)viewController
{
    self.vc = viewController;

    PPNavigationBar *navBar = (PPNavigationBar *)viewController.navigationController.navigationBar;
    navBar.translucent = YES;

    if (@available(iOS 15.0, *)) {

        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
 
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;

        // 🔹 Title styling — PPDesignTokens-driven
        NSDictionary *titleAttrs = @{
            NSFontAttributeName : [GM boldFontWithSize:PPFontHeadline],
            NSForegroundColorAttributeName : UIColor.labelColor
        };

        appearance.titleTextAttributes = titleAttrs;
        appearance.largeTitleTextAttributes = titleAttrs;

        navBar.standardAppearance = appearance;
        navBar.scrollEdgeAppearance = appearance;
        navBar.compactAppearance = appearance;

        if (@available(iOS 16.0, *)) {
            navBar.compactScrollEdgeAppearance = appearance;
        }
    }
    else {
        // iOS 14 fallback (safe)
        navBar.barTintColor = UIColor.clearColor;
        navBar.shadowImage = [UIImage new];
        navBar.translucent = YES;
        navBar.titleTextAttributes = @{
            NSFontAttributeName : [GM boldFontWithSize:PPFontHeadline]
        };
    }

    // 🔹 Disable large titles globally for consistency
    viewController.navigationItem.largeTitleDisplayMode =
    UINavigationItemLargeTitleDisplayModeNever;
}

- (void)updateTitle:(NSString *)title
{
    self.vc.navigationItem.title = title;
}

@end
