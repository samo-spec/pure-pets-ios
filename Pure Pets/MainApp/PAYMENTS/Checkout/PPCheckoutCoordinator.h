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

/// Posted by SceneDelegate when the scene becomes active.
/// PPCheckoutCoordinator observes this during an in-flight QIB payment
/// to re-check the order's Firestore status after an app-resume.
extern NSNotificationName const PPAppDidBecomeActiveNotification;

/// Key in NSError.userInfo indicating the failure is retryable (payment error
/// or timeout).  Value is an NSNumber wrapping a BOOL.
/// Validation errors (out-of-stock, invalid address, etc.) never carry this flag.
extern NSString *const PPCheckoutErrorIsRetryableKey;

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
