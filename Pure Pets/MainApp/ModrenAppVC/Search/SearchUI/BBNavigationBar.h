//
//  BBNavigationBar.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/01/2026.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BBNavigationBar : NSObject

/// Attach modern navigation appearance to a view controller
- (void)attachTo:(UIViewController *)viewController;

/// Update title attributes (optional)
- (void)updateTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END