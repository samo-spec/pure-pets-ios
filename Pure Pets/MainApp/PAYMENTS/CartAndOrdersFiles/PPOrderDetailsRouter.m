//
//  PPOrderDetailsRouter.m
//  Pure Pets
//

#import "PPOrderDetailsRouter.h"

@protocol PPOrderDetailsMissionControlRouting <NSObject>
- (instancetype)initWithOrder:(PPOrder *)order;
@optional
- (void)configureEntryPresentationState:(NSInteger)state message:(nullable NSString *)message;
@end

@implementation PPOrderDetailsRouter

+ (UIViewController *)controllerWithOrder:(PPOrder *)order
{
    return [self controllerWithOrder:order
              entryPresentationState:PPOrderDetailsEntryPresentationStateNone
                               message:nil];
}

+ (UIViewController *)controllerWithOrder:(PPOrder *)order
                   entryPresentationState:(PPOrderDetailsEntryPresentationState)state
                                    message:(NSString *)message
{
    Class missionControlClass = NSClassFromString(@"PPOrderDetailsMissionControlViewController");
    if (missionControlClass &&
        [missionControlClass isSubclassOfClass:UIViewController.class] &&
        [missionControlClass instancesRespondToSelector:@selector(initWithOrder:)]) {
        id<PPOrderDetailsMissionControlRouting> allocated = (id<PPOrderDetailsMissionControlRouting>)[missionControlClass alloc];
        UIViewController<PPOrderDetailsMissionControlRouting> *controller =
            (UIViewController<PPOrderDetailsMissionControlRouting> *)[allocated initWithOrder:order];
        if (controller) {
            if ([controller respondsToSelector:@selector(configureEntryPresentationState:message:)]) {
                [controller configureEntryPresentationState:state message:message];
            }
            return controller;
        }
    }

    NSLog(@"[PPOrderMission] SwiftUI route unavailable; using preserved legacy fallback (class=%@).",
          missionControlClass ? NSStringFromClass(missionControlClass) : @"missing");
    OrderDetailsViewController *legacyController =
        [[OrderDetailsViewController alloc] initWithOrder:order];
    legacyController.order = order;
    legacyController.entryPresentationState = state;
    legacyController.entryPresentationMessage = message;
    return legacyController;
}

@end
