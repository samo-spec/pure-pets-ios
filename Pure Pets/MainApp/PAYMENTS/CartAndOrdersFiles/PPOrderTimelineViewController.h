//
//  PPOrderTimelineViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import <UIKit/UIKit.h>

@class PPOrder;
@class PPOrderManager;
@class PPOrderTimelineEvent;

@interface PPOrderTimelineViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                             events:(NSArray<PPOrderTimelineEvent *> *)events;
@end
