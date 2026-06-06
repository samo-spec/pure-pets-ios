//
//  PPPermissionHelper.m
//  Pure Pets
//
//  Centralized camera & photo library permission helper.
//  Compliant with Apple guideline 5.1.1.
//

#import "PPPermissionHelper.h"

typedef NS_ENUM(NSUInteger, PPPermissionFeatureType) {
    PPPermissionFeatureTypeCamera,
    PPPermissionFeatureTypePhotos
};

@implementation PPPermissionHelper

#pragma mark - Presenter Resolution

+ (UIViewController *)pp_topViewControllerFromRoot:(UIViewController *)rootViewController
{
    UIViewController *current = rootViewController;

    while (current) {
        UIViewController *next = nil;

        if ([current isKindOfClass:[UINavigationController class]]) {
            next = ((UINavigationController *)current).visibleViewController;
        } else if ([current isKindOfClass:[UITabBarController class]]) {
            next = ((UITabBarController *)current).selectedViewController;
        } else if (current.presentedViewController &&
                   !current.presentedViewController.isBeingDismissed) {
            next = current.presentedViewController;
        }

        if (!next || next == current) {
            break;
        }
        current = next;
    }

    if ([current isKindOfClass:[UIAlertController class]] &&
        current.presentingViewController) {
        return current.presentingViewController;
    }

    return current;
}

+ (UIViewController *)pp_presentingViewControllerFrom:(UIViewController *)viewController
{
    if (viewController) {
        return [self pp_topViewControllerFromRoot:viewController];
    }

    UIViewController *rootViewController = nil;
    UIApplication *application = UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    rootViewController = window.rootViewController;
                    break;
                }
            }

            if (!rootViewController) {
                rootViewController = windowScene.windows.firstObject.rootViewController;
            }

            if (rootViewController) {
                break;
            }
        }
    }

    if (!rootViewController) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        rootViewController = application.keyWindow.rootViewController;
#pragma clang diagnostic pop
    }

    if (!rootViewController) {
        return nil;
    }

    return [self pp_topViewControllerFromRoot:rootViewController];
}

+ (void)pp_presentAlertController:(UIAlertController *)alert
                fromViewController:(UIViewController *)viewController
{
    UIViewController *presenter = [self pp_presentingViewControllerFrom:viewController];
    if (!presenter) {
        return;
    }

    if (presenter.presentedViewController &&
        !presenter.presentedViewController.isBeingDismissed) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self pp_presentAlertController:alert fromViewController:viewController];
        });
        return;
    }

    [presenter presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Copy

+ (NSString *)pp_featureTitleForType:(PPPermissionFeatureType)featureType
{
    switch (featureType) {
        case PPPermissionFeatureTypeCamera:
            return kLang(@"pp_perm_camera_feature");

        case PPPermissionFeatureTypePhotos:
            return kLang(@"pp_perm_photos_feature");
    }

    return @"";
}

+ (NSString *)pp_preExplanationMessageForType:(PPPermissionFeatureType)featureType
{
    switch (featureType) {
        case PPPermissionFeatureTypeCamera:
            return kLang(@"pp_perm_camera_pre_explanation");

        case PPPermissionFeatureTypePhotos:
            return kLang(@"pp_perm_photos_pre_explanation");
    }

    return @"";
}

+ (NSString *)pp_deniedMessageForRestrictedState:(BOOL)isRestricted
{
    return kLang(isRestricted ? @"pp_perm_restricted_message" : @"pp_perm_denied_message");
}

+ (void)pp_showDeniedAlertForFeatureType:(PPPermissionFeatureType)featureType
                              restricted:(BOOL)isRestricted
                         onViewController:(UIViewController *)viewController
{
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:[self pp_featureTitleForType:featureType]
                                        message:[self pp_deniedMessageForRestrictedState:isRestricted]
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_open_settings")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [self openAppSettings];
    }]];

    if (featureType != PPPermissionFeatureTypeCamera) {
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
    }

    [self pp_presentAlertController:alert fromViewController:viewController];
}

#pragma mark - Camera

+ (void)requestCameraPermissionFromViewController:(UIViewController *)viewController
                                       completion:(PPPermissionResultBlock)completion
{
    UIViewController *presenter = [self pp_presentingViewControllerFrom:viewController];
    if (!presenter) {
        if (completion) completion(NO);
        return;
    }

    AVAuthorizationStatus status =
        [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    switch (status) {
        case AVAuthorizationStatusAuthorized:
            if (completion) completion(YES);
            break;
            
        case AVAuthorizationStatusDenied:
            [self pp_showDeniedAlertForFeatureType:PPPermissionFeatureTypeCamera
                                        restricted:NO
                                   onViewController:presenter];
            if (completion) completion(NO);
            break;

        case AVAuthorizationStatusRestricted:
            [self pp_showDeniedAlertForFeatureType:PPPermissionFeatureTypeCamera
                                        restricted:YES
                                   onViewController:presenter];
            if (completion) completion(NO);
            break;
            
        case AVAuthorizationStatusNotDetermined:
        {
            [self showPreExplanationForFeature:[self pp_featureTitleForType:PPPermissionFeatureTypeCamera]
                                       message:[self pp_preExplanationMessageForType:PPPermissionFeatureTypeCamera]
                              onViewController:presenter
                            allowDeclineAction:NO
                                    completion:^(BOOL userAccepted) {
                if (!userAccepted) {
                    if (completion) completion(NO);
                    return;
                }
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                         completionHandler:^(BOOL granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) completion(granted);
                    });
                }];
            }];
    }
            break;

        default:
            if (completion) completion(NO);
            break;
    }
}

#pragma mark - Photo Library

+ (void)requestPhotoLibraryPermissionFromViewController:(UIViewController *)viewController
                                             completion:(PPPermissionResultBlock)completion
{
    UIViewController *presenter = [self pp_presentingViewControllerFrom:viewController];
    if (!presenter) {
        if (completion) completion(NO);
        return;
    }

    PHAuthorizationStatus status;
#ifdef __IPHONE_14_0
    if (@available(iOS 14, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
    } else
#endif
    {
        status = [PHPhotoLibrary authorizationStatus];
    }

    if (status == PHAuthorizationStatusAuthorized) {
        if (completion) completion(YES);
        return;
    }
#ifdef __IPHONE_14_0
    if (@available(iOS 14, *)) {
        if (status == PHAuthorizationStatusLimited) {
            if (completion) completion(YES);
            return;
        }
    }
#endif

    if (status == PHAuthorizationStatusDenied ||
        status == PHAuthorizationStatusRestricted) {
        [self pp_showDeniedAlertForFeatureType:PPPermissionFeatureTypePhotos
                                    restricted:(status == PHAuthorizationStatusRestricted)
                               onViewController:presenter];
        if (completion) completion(NO);
        return;
    }

    // Not determined — show pre-explanation then request
    [self showPreExplanationForFeature:[self pp_featureTitleForType:PPPermissionFeatureTypePhotos]
                               message:[self pp_preExplanationMessageForType:PPPermissionFeatureTypePhotos]
                      onViewController:presenter
                    allowDeclineAction:YES
                            completion:^(BOOL userAccepted) {
        if (!userAccepted) {
            if (completion) completion(NO);
            return;
        }
#ifdef __IPHONE_14_0
        if (@available(iOS 14, *)) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                      handler:^(PHAuthorizationStatus newStatus) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL granted = (newStatus == PHAuthorizationStatusAuthorized ||
                                    newStatus == PHAuthorizationStatusLimited);
                    if (completion) completion(granted);
                });
            }];
        } else
#endif
        {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL granted = (newStatus == PHAuthorizationStatusAuthorized);
                    if (completion) completion(granted);
                });
            }];
        }
    }];
}

#pragma mark - Pre-Explanation Alert

+ (void)showPreExplanationForFeature:(NSString *)feature
                             message:(NSString *)message
                    onViewController:(UIViewController *)viewController
                   allowDeclineAction:(BOOL)allowDeclineAction
                          completion:(void (^)(BOOL userAccepted))completion
{
    UIViewController *presenter = [self pp_presentingViewControllerFrom:viewController];
    if (!presenter) {
        if (completion) completion(NO);
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:feature
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_continue")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        if (completion) completion(YES);
    }]];

    if (allowDeclineAction) {
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_not_now")
                                                  style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction * _Nonnull action) {
            if (completion) completion(NO);
        }]];
    }

    [self pp_presentAlertController:alert fromViewController:presenter];
}

#pragma mark - Denied Alert

+ (void)showPermissionDeniedAlertForFeature:(NSString *)feature
                           onViewController:(UIViewController *)viewController
{
    UIViewController *presenter = [self pp_presentingViewControllerFrom:viewController];
    if (!presenter) return;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:feature
                                            message:[self pp_deniedMessageForRestrictedState:NO]
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_open_settings")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self openAppSettings];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self pp_presentAlertController:alert fromViewController:presenter];
}

#pragma mark - Settings

+ (void)openAppSettings
{
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (url && [UIApplication.sharedApplication canOpenURL:url]) {
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    }
}

@end
