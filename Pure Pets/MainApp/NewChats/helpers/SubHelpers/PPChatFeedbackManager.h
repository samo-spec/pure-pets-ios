//
//  PPChatFeedbackManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/01/2026.
//


typedef NS_ENUM(NSInteger, PPChatFeedbackEvent) {
    PPChatFeedbackEventOutgoingSend,
    PPChatFeedbackEventIncomingActiveChat,
    PPChatFeedbackEventIncomingOutsideChat,
    PPChatFeedbackEventMessageRead
};

@interface PPChatFeedbackManager : NSObject

+ (instancetype)shared;

- (void)playFeedbackForEvent:(PPChatFeedbackEvent)event;

@end