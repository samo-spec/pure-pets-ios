//
//  PPInAppChatNotificationPresenter.h
//  Pure Pets
//

#import <Foundation/Foundation.h>

@class ChatThreadModel;
@class ChatMessageModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPInAppChatNotificationPresenter : NSObject

+ (instancetype)sharedPresenter;

- (void)showChatNotificationForThread:(nullable ChatThreadModel *)thread
                              message:(ChatMessageModel *)message
                             userInfo:(NSDictionary<NSString *, id> *)userInfo;

- (void)dismissCurrentNotificationAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
