//
//  LeaveFeedbackViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2025.
//


// LeaveFeedbackViewController.h
#import <UIKit/UIKit.h>

@interface LeaveFeedbackViewController : UIViewController
@property (nonatomic, copy) void (^onLogout)(void);
@end
