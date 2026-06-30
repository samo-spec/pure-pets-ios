// AppDelegate.h
//
//
//
//
//


// AppDelegate.h  30/06/2026
#import <UIKit/UIKit.h>
 
@class OIDExternalUserAgentSession;
@class FileUploadManager;

@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate, FIRMessagingDelegate>

@property (nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;
@property (nonatomic, strong) FileUploadManager * _Nullable uploadManager;
@property (nonatomic, strong) AVAudioPlayer * _Nullable audioPlayer;

@end



/*//
//  AppDelegate.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/07/2024.
//



#undef NSLog
#define NSLog(FORMAT, ...) fprintf(stderr, "%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);


// Global variables (declared as extern in the header)
extern CGFloat topPadding;
extern CGFloat bottomPadding;


#import <IQKeyboardManager/IQKeyboardManager.h>
@protocol OIDExternalUserAgentSession;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow * _Nullable window;


// Instance variables (if you need them within the class)
@property (nonatomic, assign) CGFloat myTopPadding;
@property (nonatomic, assign) CGFloat myBottomPadding;

@property(nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;


@property (nonatomic, strong, nullable) id<FIRListenerRegistration> globalMessageListener;
// used by unit tests
@property (nonatomic, strong) NSData *_Nullable didRegisterForRemoteNotificationsWithDeviceToken;
@property (nonatomic, strong) NSDictionary *_Nullable didReceiveRemoteNotificationUserInfo;
@property (nonatomic, strong) NSDictionary *_Nullable didReceiveRemoteNotificationFetchCompletionHandlerUserInfo;

@end

*/
