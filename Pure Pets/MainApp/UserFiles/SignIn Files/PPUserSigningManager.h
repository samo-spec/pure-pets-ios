 



NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPSignInPresentationStyle) {
    PPSignInPresentationStyleSheet,
    PPSignInPresentationStyleFullScreen
};

@interface PPUserSigningManager : NSObject

#pragma mark - Configuration
@property (nonatomic, copy) NSString *defaultCountryCode;
@property (nonatomic, assign) BOOL shouldAutoDismissOnSuccess;
@property (nonatomic, assign) BOOL shouldCreateUserDocument;
@property (nonatomic, assign) PPSignInPresentationStyle presentationStyle;

#pragma mark - Singleton
+ (instancetype)shared;

#pragma mark - Presentation Methods

/**
 Present sign-in controller with default configuration
 */
+ (void)presentSignInFrom:(UIViewController *)presentingVC
                  success:(nullable void(^)(UserModel *user))success
                  failure:(nullable void(^)(NSError *error))failure
                cancelled:(nullable void(^)(void))cancelled;

/**
 Present sign-in controller with custom configuration
 */
+ (void)presentSignInFrom:(UIViewController *)presentingVC
           withCountryCode:(NSString *)countryCode
                   success:(nullable void(^)(UserModel *user))success
                   failure:(nullable void(^)(NSError *error))failure
                 cancelled:(nullable void(^)(void))cancelled;

/**
 Present sign-in controller with full customization
 */
+ (void)presentSignInFrom:(UIViewController *)presentingVC
           withCountryCode:(NSString *)countryCode
          presentationStyle:(PPSignInPresentationStyle)style
     autoDismissOnSuccess:(BOOL)autoDismiss
                   success:(nullable void(^)(UserModel *user))success
                   failure:(nullable void(^)(NSError *error))failure
                 cancelled:(nullable void(^)(void))cancelled;

#pragma mark - Quick Check Methods

/**
 Check if user is logged in and present sign-in if not
 Returns YES if user is already logged in, NO if sign-in was presented
 */
+ (BOOL)requireSignInFrom:(UIViewController *)presentingVC
                  success:(nullable void(^)(UserModel *user))success
                cancelled:(nullable void(^)(void))cancelled;

/**
 Check if user is logged in with custom message
 */
+ (BOOL)requireSignInFrom:(UIViewController *)presentingVC
          withMessage:(nullable NSString *)message
                  success:(nullable void(^)(UserModel *user))success
                cancelled:(nullable void(^)(void))cancelled;

@end

NS_ASSUME_NONNULL_END
