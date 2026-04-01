//
//  PPUserSigningController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 17/11/2025.
//

#import <UIKit/UIKit.h>
#import "PPVerificationCodeViewController.h"
#import "PPCompleteProfileVC.h"




NS_ASSUME_NONNULL_BEGIN

@class UserModel;

/**
 Presentation style for the sign-in controller
 */
typedef NS_ENUM(NSInteger, PPUserSigningPresentationStyle) {
    PPUserSigningPresentationStyleFullScreen,
    PPUserSigningPresentationStyleSheet
};

/**
 Available sign-in methods
 */
typedef NS_ENUM(NSInteger, PPSignInMethod) {
    PPSignInMethodPhone,
    PPSignInMethodApple,
    PPSignInMethodGoogle
};

/**
 A modern sign-in controller supporting phone, Apple, and Google authentication
 Features glass morphism design, smooth animations, and Firebase integration
 */
@interface PPUserSigningController : UIViewController

#pragma mark - Initializers

/**
 Designated initializer with specific presentation style
 
 @param style The presentation style (full screen or bottom sheet)
 @return An initialized sign-in controller
 */
- (instancetype)initWithPresentationStyle:(PPUserSigningPresentationStyle)style;

/**
 Convenience initializer with default sheet presentation
 
 @return An initialized sign-in controller with sheet presentation
 */
- (instancetype)init;

#pragma mark - Configuration Properties

/**
 Default country code for phone authentication
 Default: "+974"
 */
@property (nonatomic, copy) NSString *defaultCountryCode;

/**
 Whether to automatically dismiss after successful authentication
 Default: YES
 */
@property (nonatomic, assign) BOOL shouldAutoDismissOnSuccess;

/**
 Whether to create user document in Firestore if it doesn't exist
 Default: YES
 */
@property (nonatomic, assign) BOOL shouldCreateUserDocument;

/**
 Presentation style for the controller (read-only)
 */
@property (nonatomic, assign, readonly) PPUserSigningPresentationStyle presentationStyle;

#pragma mark - Callback Blocks

/**
 Called when user successfully signs in and UserModel is created/cached
 
 @param user The authenticated user model
 */
@property (nonatomic, copy, nullable) void (^signInSuccess)(UserModel *user);

/**
 Called when sign-in fails with an error
 
 @param error The authentication error
 */
@property (nonatomic, copy, nullable) void (^signInFailure)(NSError *error);

/**
 Called when user cancels the sign-in flow
 */
@property (nonatomic, copy, nullable) void (^signInCancelled)(void);

@end

NS_ASSUME_NONNULL_END
