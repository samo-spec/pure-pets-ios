//
//  PPOrderDetailsRouter.h
//  Pure Pets
//
//  Single reversible route seam for the customer order-details experience.
//  The legacy OrderDetailsViewController remains available as a fail-safe.
//

#import <UIKit/UIKit.h>
#import "OrderDetailsViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPOrderDetailsRouter : NSObject

+ (UIViewController *)controllerWithOrder:(PPOrder *)order;

+ (UIViewController *)controllerWithOrder:(PPOrder *)order
                   entryPresentationState:(PPOrderDetailsEntryPresentationState)state
                                    message:(nullable NSString *)message;

@end

NS_ASSUME_NONNULL_END
