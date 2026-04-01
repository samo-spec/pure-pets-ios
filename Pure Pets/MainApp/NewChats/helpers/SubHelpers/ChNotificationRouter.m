//
//  ChNotificationRouter.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//


// ChNotificationRouter.m

#import "ChNotificationRouter.h"
#import "ChMessagingController.h"
#import "ChatThreadModel.h"
#import "PPFunc.h" // your sheet presenter

@implementation ChNotificationRouter

+ (instancetype)shared {
    static ChNotificationRouter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ChNotificationRouter alloc] init];
    });
    return instance;
}
- (void)handleChatNotification:(NSDictionary *)userInfo
           fromViewController:(UIViewController *)presentingVC {

    NSString *threadID =
        userInfo[@"threadID"] ?: userInfo[@"threadId"];

    if (threadID.length == 0 || !presentingVC) {
        NSLog(@"❌ [NotificationRouter] Missing threadID");
        return;
    }

    [ChManager fetchThreadWithID:threadID
                            completion:^(ChatThreadModel *thread) {

        if (!thread) {
            NSLog(@"❌ [NotificationRouter] Thread not found");
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{

            ChMessagingController *chatVC =
                [[ChMessagingController alloc] initWithChatThread:thread];

 
            [PPFunc presentSheetFrom:presentingVC
                             sheetVC:chatVC
                         detentStyle:PPSheetDetentStyleSemiLargAndLarge];
        });
    }];
}

@end
