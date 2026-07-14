//
//  PPOrderSupportRequestDetailsViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//


@interface PPOrderSupportRequestDetailsViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                            request:(PPOrderSupportRequest *)request;
@end