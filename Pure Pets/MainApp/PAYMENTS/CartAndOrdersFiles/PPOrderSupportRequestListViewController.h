//
//  PPOrderSupportRequestListViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import <UIKit/UIKit.h>

@class PPOrder;
@class PPOrderManager;
@class PPOrderSupportRequest;

@interface PPOrderSupportRequestListViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                           requests:(NSArray<PPOrderSupportRequest *> *)requests;
@end
