//
//  SceneDelegate.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/07/2024.
//



@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
- (void)reloadRootViewControllerForLanguageChange;
- (void)handleRemoteNotificationUserInfo:(NSDictionary *)userInfo;
- (void)notificationRoutingRootDidBecomeReady;
@property (strong, nonatomic) UIWindow * window;


@end
