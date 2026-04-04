//
//  PPSearchViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/01/2026.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPSearchViewController : UIViewController

/// Called by TabBarController to focus search (Apple Phone style)
- (void)focusSearchField;

/// Opens search with the accessories segment selected and focuses the field.
- (void)openAccessoriesAll;

@end

NS_ASSUME_NONNULL_END
