//
//  PPPaymentManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/02/2026.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PPOrder.h"
@class PPAddressModel;

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPPaymentCompletion)(NSDictionary * _Nullable response,
                                    NSError * _Nullable error);

@interface PPPaymentManager : NSObject

+ (instancetype)shared;
+ (BOOL)isSimulatedPaymentSuccessEnabled;
+ (void)setSimulatedPaymentSuccessEnabled:(BOOL)enabled;

/// The same contact resolution/normalization used by the QIB launch path.
- (nullable NSString *)normalizedCheckoutPhoneForAddress:(nullable PPAddressModel *)address;
- (nullable NSString *)normalizedCheckoutPhoneFromString:(nullable NSString *)phone;

/**
 Starts QIB payment flow for a pending order.
 This method ONLY launches the SDK and returns its response.
 Order status must NOT be updated here.
 */
- (void)startPaymentForOrder:(PPOrder *)order
          fromViewController:(UIViewController *)viewController
                  completion:(PPPaymentCompletion)completion;

@end

NS_ASSUME_NONNULL_END
