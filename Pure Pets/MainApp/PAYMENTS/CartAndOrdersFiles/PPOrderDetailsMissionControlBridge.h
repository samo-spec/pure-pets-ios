//
//  PPOrderDetailsMissionControlBridge.h
//  Pure Pets
//
//  Objective-C domain adapter for the SwiftUI order-details owner. It keeps
//  Firebase, eligibility, support, address, and legacy destination contracts
//  outside the SwiftUI presentation layer.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PPOrder.h"
#import "OrderSupportFunc.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPOrderMissionStateUpdate)(NSDictionary *state);
typedef void (^PPOrderMissionResult)(NSDictionary * _Nullable result, NSError * _Nullable error);
typedef void (^PPOrderMissionListResult)(NSArray<NSDictionary *> *items, NSError * _Nullable error);

@interface PPOrderDetailsMissionControlBridge : NSObject

@property (nonatomic, strong, readonly) PPOrder *order;

- (instancetype)initWithOrder:(PPOrder *)order NS_DESIGNATED_INITIALIZER
    NS_SWIFT_NAME(init(order:));
- (instancetype)init NS_UNAVAILABLE;

- (void)startWithUpdate:(PPOrderMissionStateUpdate)update
    NS_SWIFT_NAME(start(update:));
- (void)setScreenVisible:(BOOL)visible
    NS_SWIFT_NAME(setScreenVisible(_:));
- (void)refresh;
- (void)stop;

- (NSArray<NSDictionary *> *)reasonOptionsForAction:(PPOrderCustomerActionType)actionType
    NS_SWIFT_NAME(reasonOptions(for:));

- (void)cancelOrderWithCompletion:(PPOrderMissionResult)completion
    NS_SWIFT_NAME(cancel(completion:));

- (void)submitAction:(PPOrderCustomerActionType)actionType
           reasonCode:(NSString *)reasonCode
          reasonTitle:(NSString *)reasonTitle
                notes:(NSString *)notes
      selectedItemIDs:(NSArray<NSString *> *)selectedItemIDs
               images:(NSArray<UIImage *> *)images
           completion:(PPOrderMissionResult)completion
    NS_SWIFT_NAME(submit(action:reasonCode:reasonTitle:notes:selectedItemIDs:images:completion:));

- (void)loadAddressesWithCompletion:(PPOrderMissionListResult)completion
    NS_SWIFT_NAME(loadAddresses(completion:));
- (void)selectAddressWithIdentifier:(NSString *)identifier
                         completion:(PPOrderMissionResult)completion
    NS_SWIFT_NAME(selectAddress(identifier:completion:));

- (void)startRequestEventsForRequestID:(NSString *)requestID
                                 update:(PPOrderMissionListResult)update
    NS_SWIFT_NAME(startRequestEvents(requestID:update:));
- (void)stopRequestEvents;

- (void)openAccessoryWithIdentifier:(NSString *)identifier
                  fromViewController:(UIViewController *)viewController
                          completion:(void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(openAccessory(identifier:from:completion:));

- (void)openAddressEditorFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openAddressEditor(from:));
- (void)openSupportChatFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openSupportChat(from:));
- (void)requestSupportCallFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(requestSupportCall(from:));

@end

NS_ASSUME_NONNULL_END
