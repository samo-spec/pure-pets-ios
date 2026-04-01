//
//  PPCheckoutCoordinator.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PPOrder;
@class PPAddressModel;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPCheckoutResult) {
    PPCheckoutResultSuccess,
    PPCheckoutResultPendingVerification,
    PPCheckoutResultFailed,
    PPCheckoutResultCancelled
};

typedef void (^PPCheckoutCompletion)(PPCheckoutResult result, PPOrder * _Nullable order, NSError * _Nullable error);

@interface PPCheckoutCoordinator : NSObject

@property (nonatomic, strong, readonly) PPOrder *currentOrder;

- (instancetype)initWithPresentingViewController:(UIViewController *)viewController;

- (void)startCheckoutWithCompletion:(PPCheckoutCompletion)completion;
- (void)startCheckoutWithAddress:(PPAddressModel * _Nullable)address
                      completion:(PPCheckoutCompletion)completion;
- (void)startCheckoutWithAddress:(PPAddressModel * _Nullable)address
                 paymentMethodId:(nullable NSString *)paymentMethodId
                      completion:(PPCheckoutCompletion)completion;

@end

NS_ASSUME_NONNULL_END
