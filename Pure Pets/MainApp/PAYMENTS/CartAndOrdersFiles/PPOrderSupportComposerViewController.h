//
//  PPOrderSupportComposerViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//
#import "OrderSupportFunc.h"

@interface PPOrderSupportComposerViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                         actionType:(PPOrderCustomerActionType)actionType
                       orderManager:(PPOrderManager *)orderManager
                         onComplete:(dispatch_block_t)onComplete;
@end
