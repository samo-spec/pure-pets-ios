//
//  PPCommerceFeedbackManager.m
//  Pure Pets
//

#import "PPCommerceFeedbackManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>

@interface PPCommerceFeedbackManager ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *lastPlaybackByEvent;
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@property (nonatomic, strong) UIImpactFeedbackGenerator *lightImpact;
@property (nonatomic, strong) UIImpactFeedbackGenerator *softImpact;
@property (nonatomic, strong) UINotificationFeedbackGenerator *notificationFeedback;
@property (nonatomic, assign) BOOL soundEnabled;
@end

// Use stable built‑in iOS system sound IDs (audible on device)
static const SystemSoundID PPCommerceSoundTap     = 1104; // Tock
static const SystemSoundID PPCommerceSoundSuccess = 1110; // Modern success tone
static const SystemSoundID PPCommerceSoundRemove  = 1150; // Soft remove tick
static const SystemSoundID PPCommerceSoundFail    = 1053; // Distinct failure tone

static inline void PPCommercePlaySystemSoundIfEnabled(BOOL enabled, SystemSoundID soundID) {
    if (!enabled) { return; }
    if (soundID == 0) { return; }
    AudioServicesPlaySystemSound(soundID);
}

@implementation PPCommerceFeedbackManager

+ (instancetype)shared
{
    static PPCommerceFeedbackManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPCommerceFeedbackManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _lastPlaybackByEvent = [NSMutableDictionary dictionary];
        _stateQueue = dispatch_queue_create("com.purepets.commerce.feedback", DISPATCH_QUEUE_SERIAL);
        _lightImpact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        _softImpact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        _notificationFeedback = [[UINotificationFeedbackGenerator alloc] init];
        _soundEnabled = YES;
    }
    return self;
}

- (NSTimeInterval)minimumIntervalForEvent:(PPCommerceFeedbackEvent)event
{
    switch (event) {
        case PPCommerceFeedbackEventCartQuantityChanged:
            return 0.08;
        case PPCommerceFeedbackEventCartItemRemoved:
        case PPCommerceFeedbackEventCartUndo:
            return 0.12;
        case PPCommerceFeedbackEventPaymentAction:
            return 0.10;
        case PPCommerceFeedbackEventPaymentSuccess:
        case PPCommerceFeedbackEventPaymentFailure:
            return 0.20;
        case PPCommerceFeedbackEventRootTabSelected:
            return 0.10;
    }
    return 0.12;
}

- (BOOL)reserveSlotForEvent:(PPCommerceFeedbackEvent)event
{
    __block BOOL canPlay = NO;
    dispatch_sync(self.stateQueue, ^{
        NSDate *now = [NSDate date];
        NSNumber *key = @(event);
        NSDate *last = self.lastPlaybackByEvent[key];
        NSTimeInterval minimum = [self minimumIntervalForEvent:event];
        if (last && [now timeIntervalSinceDate:last] < minimum) {
            canPlay = NO;
            return;
        }
        self.lastPlaybackByEvent[key] = now;
        canPlay = YES;
    });
    return canPlay;
}

- (BOOL)canPlayFeedback
{
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return NO;
    }
    return YES;
}

- (void)playEvent:(PPCommerceFeedbackEvent)event
{
    if (![self canPlayFeedback]) {
        return;
    }
    if (![self reserveSlotForEvent:event]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        // Prepare generators (Apple recommends preparing shortly before use)
        [self.lightImpact prepare];
        [self.softImpact prepare];
        [self.notificationFeedback prepare];

        switch (event) {
            case PPCommerceFeedbackEventCartQuantityChanged: {
                [self.lightImpact impactOccurred];
                PPCommercePlaySystemSoundIfEnabled(self.soundEnabled, PPCommerceSoundTap);
            } break;

            case PPCommerceFeedbackEventCartItemRemoved: {
                [self.softImpact impactOccurred];
                PPCommercePlaySystemSoundIfEnabled(self.soundEnabled, PPCommerceSoundRemove);
            } break;

            case PPCommerceFeedbackEventCartUndo: {
                [self.notificationFeedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                PPCommercePlaySystemSoundIfEnabled(self.soundEnabled, PPCommerceSoundSuccess);
            } break;

            case PPCommerceFeedbackEventPaymentAction: {
                [self.softImpact impactOccurred];
                PPCommercePlaySystemSoundIfEnabled(self.soundEnabled, PPCommerceSoundTap);
            } break;

            case PPCommerceFeedbackEventPaymentSuccess: {
                [self.notificationFeedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                PPCommercePlaySystemSoundIfEnabled(self.soundEnabled, PPCommerceSoundSuccess);
            } break;

            case PPCommerceFeedbackEventPaymentFailure: {
                [self.lightImpact impactOccurred];
                PPCommercePlaySystemSoundIfEnabled(self.soundEnabled, PPCommerceSoundFail);
            } break;

            case PPCommerceFeedbackEventRootTabSelected: {
                [self.softImpact impactOccurred];
                PPCommercePlaySystemSoundIfEnabled(self.soundEnabled, PPCommerceSoundTap);
            } break;
        }
    });
}

@end
