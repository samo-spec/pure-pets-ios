//
//  PPPermissionHelper.h
//  Pure Pets
//
//  Centralized camera & photo library permission helper.
//  Compliant with Apple guideline 5.1.1.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

typedef void (^PPPermissionResultBlock)(BOOL granted);

@interface PPPermissionHelper : NSObject

/// Request camera permission with a pre-explanation and compliant denied-state handling.
/// Shows an informational alert explaining *why* the camera is needed before the
/// system prompt. If access was previously denied, the user sees a neutral
/// informational alert with Settings and Cancel. A fresh denial is respected
/// without immediately asking the user to reconsider.
+ (void)requestCameraPermissionFromViewController:(UIViewController * _Nullable)viewController
                                       completion:(PPPermissionResultBlock)completion;

/// Request photo-library permission with the same compliant flow.
+ (void)requestPhotoLibraryPermissionFromViewController:(UIViewController * _Nullable)viewController
                                             completion:(PPPermissionResultBlock)completion;

/// Show a compliant "permission denied" alert (Settings + Cancel).
+ (void)showPermissionDeniedAlertForFeature:(NSString *)feature
                           onViewController:(UIViewController * _Nullable)viewController;

/// Open the app's Settings page.
+ (void)openAppSettings;

@end
