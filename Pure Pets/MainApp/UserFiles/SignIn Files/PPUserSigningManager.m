 
#import "PPUserSigningManager.h"
 


static inline void PPDispatchMainThread(void (^block)(void)) {
    if (!block) {
        return;
    }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@implementation PPUserSigningManager

#pragma mark - Singleton

+ (instancetype)shared {
    static PPUserSigningManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaultCountryCode = @"+974";
        _shouldAutoDismissOnSuccess = YES;
        _shouldCreateUserDocument = YES;
        _presentationStyle = PPSignInPresentationStyleSheet;
    }
    return self;
}

#pragma mark - Default Presentation

+ (void)presentSignInFrom:(UIViewController *)presentingVC
                  success:(void (^)(UserModel *))success
                  failure:(void (^)(NSError *))failure
                cancelled:(void (^)(void))cancelled {
    
    [[self shared] presentSignInFrom:presentingVC
                      withCountryCode:[self shared].defaultCountryCode
                     presentationStyle:[self shared].presentationStyle
                autoDismissOnSuccess:[self shared].shouldAutoDismissOnSuccess
                              success:success
                              failure:failure
                            cancelled:cancelled];
}

+ (void)presentSignInFrom:(UIViewController *)presentingVC
           withCountryCode:(NSString *)countryCode
                   success:(void (^)(UserModel *))success
                   failure:(void (^)(NSError *))failure
                 cancelled:(void (^)(void))cancelled {
    
    [[self shared] presentSignInFrom:presentingVC
                      withCountryCode:countryCode
                     presentationStyle:[self shared].presentationStyle
                autoDismissOnSuccess:[self shared].shouldAutoDismissOnSuccess
                              success:success
                              failure:failure
                            cancelled:cancelled];
}

+ (void)presentSignInFrom:(UIViewController *)presentingVC
           withCountryCode:(NSString *)countryCode
          presentationStyle:(PPSignInPresentationStyle)style
     autoDismissOnSuccess:(BOOL)autoDismiss
                   success:(void (^)(UserModel *))success
                   failure:(void (^)(NSError *))failure
                 cancelled:(void (^)(void))cancelled {
    
    [[self shared] presentSignInFrom:presentingVC
                      withCountryCode:countryCode
                     presentationStyle:style
                autoDismissOnSuccess:autoDismiss
                              success:success
                              failure:failure
                            cancelled:cancelled];
}

#pragma mark - Instance Presentation

- (void)presentSignInFrom:(UIViewController *)presentingVC
           withCountryCode:(NSString *)countryCode
          presentationStyle:(PPSignInPresentationStyle)style
     autoDismissOnSuccess:(BOOL)autoDismiss
                   success:(void (^)(UserModel *))success
                   failure:(void (^)(NSError *))failure
                 cancelled:(void (^)(void))cancelled {
    
    // Convert presentation style
    PPUserSigningPresentationStyle controllerStyle;
    switch (style) {
        case PPSignInPresentationStyleSheet:
            controllerStyle = PPUserSigningPresentationStyleSheet;
            break;
        case PPSignInPresentationStyleFullScreen:
            controllerStyle = PPUserSigningPresentationStyleFullScreen;
            break;
    }
    
    // Create and configure controller
    PPUserSigningController *signInVC = [[PPUserSigningController alloc] initWithPresentationStyle:controllerStyle];
    signInVC.defaultCountryCode = countryCode ?: self.defaultCountryCode;
    signInVC.shouldAutoDismissOnSuccess = autoDismiss;
    signInVC.shouldCreateUserDocument = self.shouldCreateUserDocument;
    
    // Set callbacks
    signInVC.signInSuccess = ^(UserModel *user) {
        // Auto-cache user
        [UsrMgr cacheUser:user];
        
        // Call success callback
        if (success) {
            success(user);
        }
        
        // Log event
        NSLog(@"✅ User signed in successfully: %@", user.UserName);
    };
    
    signInVC.signInFailure = ^(NSError *error) {
        if (failure) {
            failure(error);
        }
        NSLog(@"❌ Sign-in failed: %@", error.localizedDescription);
    };
    
    signInVC.signInCancelled = ^{
        if (cancelled) {
            cancelled();
        }
        NSLog(@"🔘 User cancelled sign-in");
    };
    
    PPDispatchMainThread(^{
        if (!presentingVC) {
            NSError *presentationError = [NSError errorWithDomain:@"PPAuth"
                                                             code:2001
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Unable to present sign-in screen right now."}];
            if (failure) {
                failure(presentationError);
            }
            return;
        }
        
        UIViewController *topPresenter = [self topMostViewControllerFrom:presentingVC];
        if (!topPresenter) {
            if (failure) {
                NSError *topPresenterError = [NSError errorWithDomain:@"PPAuth"
                                                                  code:2002
                                                              userInfo:@{NSLocalizedDescriptionKey: @"Unable to find a valid presenter."}];
                failure(topPresenterError);
            }
            return;
        }
        
        if (topPresenter.presentedViewController) {
            topPresenter = [self topMostViewControllerFrom:topPresenter];
        }
        if (topPresenter.isBeingPresented || topPresenter.isBeingDismissed) {
            if (failure) {
                NSError *busyPresenterError = [NSError errorWithDomain:@"PPAuth"
                                                                   code:2003
                                                               userInfo:@{NSLocalizedDescriptionKey: @"Please try again in a moment."}];
                failure(busyPresenterError);
            }
            return;
        }
        
        [topPresenter presentViewController:signInVC animated:YES completion:nil];
    });
}

- (UIViewController *)topMostViewControllerFrom:(UIViewController *)controller {
    UIViewController *top = controller;
    while (top) {
        if ([top isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)top;
            top = nav.visibleViewController ?: nav.topViewController;
            continue;
        }
        if ([top isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tab = (UITabBarController *)top;
            top = tab.selectedViewController ?: top;
            continue;
        }
        if (top.presentedViewController &&
            !top.presentedViewController.isBeingDismissed &&
            !top.presentedViewController.isBeingPresented) {
            top = top.presentedViewController;
            continue;
        }
        break;
    }
    return top;
}

#pragma mark - Quick Check Methods

+ (BOOL)requireSignInFrom:(UIViewController *)presentingVC
                  success:(void (^)(UserModel *))success
                cancelled:(void (^)(void))cancelled {
    
    return [self requireSignInFrom:presentingVC 
                       withMessage:nil 
                           success:success 
                         cancelled:cancelled];
}

+ (BOOL)requireSignInFrom:(UIViewController *)presentingVC
          withMessage:(NSString * _Nullable)message
                  success:(void (^)(UserModel *))success
                cancelled:(void (^)(void))cancelled {
    
    // Check if user is already logged in
    if ([self isUserLoggedIn]) {
        return YES;
    }
    
    // Present sign-in with optional custom message
    if (message) {
        // You could show an alert first, then present sign-in
        [self presentSignInWithMessage:message from:presentingVC success:success cancelled:cancelled];
    } else {
        [self presentSignInFrom:presentingVC success:success failure:nil cancelled:cancelled];
    }
    
    return NO;
}

#pragma mark - Utility Methods

+ (BOOL)isUserLoggedIn {
    // Check your existing user management system
    return PPCurrentUser != nil;
}

+ (void)presentSignInWithMessage:(NSString *)message 
                            from:(UIViewController *)presentingVC 
                         success:(void (^)(UserModel *))success 
                       cancelled:(void (^)(void))cancelled {
    
    // Show alert with message first, then present sign-in
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign In Required"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Sign In" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self presentSignInFrom:presentingVC success:success failure:nil cancelled:cancelled];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (cancelled) {
            cancelled();
        }
    }]];
    
    PPDispatchMainThread(^{
        UIViewController *safePresenter = [[self shared] topMostViewControllerFrom:presentingVC];
        if (!safePresenter) {
            if (cancelled) {
                cancelled();
            }
            return;
        }
        [safePresenter presentViewController:alert animated:YES completion:nil];
    });
}

@end
