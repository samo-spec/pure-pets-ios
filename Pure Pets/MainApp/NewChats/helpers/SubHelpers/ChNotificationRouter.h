//
//  ChNotificationRouter.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//

// ChNotificationRouter.h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChNotificationRouter : NSObject

+ (instancetype)shared;

- (void)handleChatNotification:(NSDictionary *)userInfo
           fromViewController:(UIViewController *)presentingVC;

@end

NS_ASSUME_NONNULL_END
