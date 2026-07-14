//
//  PPOrderTimelineViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//


@interface PPOrderTimelineViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                             events:(NSArray<PPOrderTimelineEvent *> *)events;
@end
