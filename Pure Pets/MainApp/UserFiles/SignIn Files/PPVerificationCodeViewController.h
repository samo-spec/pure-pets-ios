//
//  PPVerificationPromptViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/11/2025.
//


#import <UIKit/UIKit.h>
@class FIRAuthDataResult;
#import "PPAuthStepIndicatorView.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPVerificationResendCompletion)(BOOL success, NSError * _Nullable error);
typedef void (^PPVerificationCodeCheckCompletion)(BOOL success, NSError * _Nullable error);

@interface PPVerificationCodeViewController : UIViewController

@property (nonatomic, copy, nullable) void (^onCodeSubmitted)(NSString *code);
@property (nonatomic, copy, nullable) void (^onCodeVerificationRequested)(NSString *code, PPVerificationCodeCheckCompletion completion);
@property (nonatomic, copy, nullable) void (^onAuthResultSuccess)(FIRAuthDataResult *authResult);
@property (nonatomic, copy, nullable) void (^onResendRequested)(PPVerificationResendCompletion completion);
@property (nonatomic, copy, nullable) void (^onBackRequested)(void);
/// Ephemeral Firebase phone-auth binding. Keep in memory only and replace it
/// when a resend returns a new verification ID.
@property (nonatomic, copy, nullable) NSString *verificationID;

- (instancetype)initWithPhone:(NSString *)phone;

@end

NS_ASSUME_NONNULL_END
 
