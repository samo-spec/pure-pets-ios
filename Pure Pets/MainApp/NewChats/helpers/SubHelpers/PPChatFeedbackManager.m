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
@property (nonatomic, strong) UIImpactFeedbackGenerator *mediumImpact;
@property (nonatomic, strong) UISelectionFeedbackGenerator *selectionFeedback;
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
        if (@available(iOS 13.0, *)) {
            _lightImpact =
                [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
            _mediumImpact =
                [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
        } else {
            _lightImpact =
                [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            _mediumImpact = _lightImpact;
        }
        _selectionFeedback = [[UISelectionFeedbackGenerator alloc] init];
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
            return 0.04;
        case PPChatFeedbackEventIncomingActiveChat:
            return 0.10;
        case PPChatFeedbackEventIncomingOutsideChat:
            return 0.30;
        case PPChatFeedbackEventMessageRead:
            return 0.15;
    }
    return 0.15;
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
            return YES;
    }
    return NO;
}

#pragma mark - Premium Sound Engine

- (void)pp_playSendSound
{
    AudioServicesPlaySystemSound(1104);
}

- (void)pp_playReceiveSound
{
    AudioServicesPlaySystemSound(1105);
}

- (void)pp_subtleImpactWithDelay:(NSTimeInterval)delay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.selectionFeedback selectionChanged];
    });
}

- (void)pp_successNotificationWithDelay:(NSTimeInterval)delay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.notificationFeedback notificationOccurred:UINotificationFeedbackTypeSuccess];
    });
}

#pragma mark - Public API

- (void)playNovaFeedbackForEvent:(PPChatFeedbackEvent)event
{
    if (![self shouldPlayForEvent:event]) {
        return;
    }

    if (![self reservePlaybackSlotForEvent:event]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.lightImpact prepare];
        [self.selectionFeedback prepare];

        switch (event) {
            case PPChatFeedbackEventOutgoingSend: {
                [self.lightImpact impactOccurredWithIntensity:0.62];
            } break;

            case PPChatFeedbackEventIncomingActiveChat: {
                [self.lightImpact impactOccurredWithIntensity:0.45];
                [self.notificationFeedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            } break;

            case PPChatFeedbackEventIncomingOutsideChat: {
                [self.lightImpact impactOccurredWithIntensity:0.45];
                [self.notificationFeedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            } break;

            case PPChatFeedbackEventMessageRead: {
                [self.lightImpact impactOccurredWithIntensity:0.32];
            } break;
        }
    });
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
        [self.mediumImpact prepare];
        [self.selectionFeedback prepare];
        [self.notificationFeedback prepare];

        switch (event) {

            case PPChatFeedbackEventOutgoingSend: {
                [self pp_playSendSound];
                [self.lightImpact impactOccurredWithIntensity:0.66];
                [self pp_subtleImpactWithDelay:0.05];
            } break;

            case PPChatFeedbackEventIncomingActiveChat: {
                [self pp_playReceiveSound];
                [self.lightImpact impactOccurredWithIntensity:0.45];
                [self pp_subtleImpactWithDelay:0.04];
                [self pp_successNotificationWithDelay:0.06];
            } break;

            case PPChatFeedbackEventIncomingOutsideChat: {
                [self pp_playReceiveSound];
                [self.lightImpact impactOccurredWithIntensity:0.45];
                [self.notificationFeedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            } break;

            case PPChatFeedbackEventMessageRead: {
                [self.mediumImpact impactOccurredWithIntensity:0.48];
            } break;
        }
    });
}

@end
