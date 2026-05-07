//
//  PPChatFeedbackManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/01/2026.
//


#import "PPChatFeedbackManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>

@interface PPChatFeedbackManager ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *lastEventPlaybackDates;
@property (nonatomic, strong) UIImpactFeedbackGenerator *lightImpact;
@property (nonatomic, strong) UINotificationFeedbackGenerator *notificationFeedback;
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@end

@implementation PPChatFeedbackManager

+ (instancetype)shared {
    static PPChatFeedbackManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPChatFeedbackManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _lastEventPlaybackDates = [NSMutableDictionary dictionary];
        _lightImpact =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        _notificationFeedback =
            [[UINotificationFeedbackGenerator alloc] init];
        _stateQueue = dispatch_queue_create("com.purepets.chat.feedback",
                                            DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSTimeInterval)minimumIntervalForEvent:(PPChatFeedbackEvent)event
{
    switch (event) {
        case PPChatFeedbackEventOutgoingSend:
            return 0.05;
        case PPChatFeedbackEventIncomingActiveChat:
            return 0.15;
        case PPChatFeedbackEventIncomingOutsideChat:
            return 0.40;
        case PPChatFeedbackEventMessageRead:
            return 0.20;
        case PPChatFeedbackEventTypingPulse:
            return 1.10;
    }
    return 0.20;
}

- (BOOL)reservePlaybackSlotForEvent:(PPChatFeedbackEvent)event
{
    __block BOOL canPlay = NO;
    dispatch_sync(self.stateQueue, ^{
        NSDate *now = [NSDate date];
        NSNumber *key = @(event);
        NSDate *lastDate = self.lastEventPlaybackDates[key];
        NSTimeInterval minInterval = [self minimumIntervalForEvent:event];
        if (lastDate && [now timeIntervalSinceDate:lastDate] < minInterval) {
            canPlay = NO;
            return;
        }
        self.lastEventPlaybackDates[key] = now;
        canPlay = YES;
    });
    return canPlay;
}

- (BOOL)shouldPlayForEvent:(PPChatFeedbackEvent)event
{
    UIApplicationState appState = UIApplication.sharedApplication.applicationState;
    if (appState != UIApplicationStateActive) {
        return NO;
    }

    switch (event) {
        case PPChatFeedbackEventOutgoingSend:
        case PPChatFeedbackEventIncomingActiveChat:
        case PPChatFeedbackEventIncomingOutsideChat:
        case PPChatFeedbackEventMessageRead:
        case PPChatFeedbackEventTypingPulse:
            return YES;
    }
    return NO;
}

- (void)playFeedbackForEvent:(PPChatFeedbackEvent)event {
    if (![self shouldPlayForEvent:event]) {
        return;
    }

    if (![self reservePlaybackSlotForEvent:event]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.lightImpact prepare];
        [self.notificationFeedback prepare];

        switch (event) {

            // 📤 Outgoing message (Send)
            case PPChatFeedbackEventOutgoingSend: {
                [self.lightImpact impactOccurred];
                AudioServicesPlaySystemSound(1104);
            } break;

            // 📥 Incoming while chat is OPEN
            case PPChatFeedbackEventIncomingActiveChat: {
                [self.notificationFeedback
                 notificationOccurred:UINotificationFeedbackTypeSuccess];
                AudioServicesPlaySystemSound(1105);
            } break;

            // 📥 Incoming while app active but chat NOT visible
            case PPChatFeedbackEventIncomingOutsideChat: {
                [self.notificationFeedback
                 notificationOccurred:UINotificationFeedbackTypeSuccess];
                AudioServicesPlaySystemSound(1007); //1016
            } break;

            // 👁 Message read (optional, subtle)
            case PPChatFeedbackEventMessageRead: {
                [self.lightImpact impactOccurred];
            } break;

            // ✍️ Typing pulse - intentionally throttled and quiet.
            case PPChatFeedbackEventTypingPulse: {
                [self.lightImpact impactOccurred];
                AudioServicesPlaySystemSound(1114);
            } break;
        }
    });
}

@end
/*
 // UI Sounds
 1312:  SMS Received (Vibrate) - good for silent mode
 1020:  "Tweet Sent" - for message sent confirmation
 1057:  "Tock" - keyboard tap (good for typing indicators)
 1073:  "Tink" - error/alerts
 1075:  "Tink" - alternative
 1102:  "Bleep" - minor notification
 1103:  "Bloom" - light notification
 1104:  "SentMessage" - message sent
 1105:  "ReceivedMessage"
 1107:  "SentMail" - for email-like chats
 1108:  "MailReceived"
 1109:  "MailSent"
 1110:  "SentMessage" alternative
 1111:  "Keypress"
 1113:  "Tock" alternative
 1114:  "Tock" softer
 1117:  "CameraShutter" - for photo messages
 1150:  "Lock" - for chat locking/security
 1151:  "Unlock" - for unlocking chat
 */
