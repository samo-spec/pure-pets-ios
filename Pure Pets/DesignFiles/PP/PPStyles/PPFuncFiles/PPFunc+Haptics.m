//
//  GM.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/11/2025.
//


//
//  GM+Haptics.m
//  PurePets
//

#import "PPFunc+Haptics.h"
#import <CoreHaptics/CoreHaptics.h>

@implementation PPFunc (Haptics)

#pragma mark - Public API

+ (void)triggerLightHaptic {
    [self generateImpactWithStyle:UIImpactFeedbackStyleLight];
}

+ (void)triggerMediumHaptic {
    [self generateImpactWithStyle:UIImpactFeedbackStyleMedium];
}

+ (void)triggerHeavyHaptic {
    [self generateImpactWithStyle:UIImpactFeedbackStyleHeavy];
}

+ (void)triggerSuccessHaptic {
    [self generateNotificationWithType:UINotificationFeedbackTypeSuccess];
}

+ (void)triggerWarningHaptic {
    [self generateNotificationWithType:UINotificationFeedbackTypeWarning];
}

+ (void)triggerErrorHaptic {
    [self generateNotificationWithType:UINotificationFeedbackTypeError];
}

#pragma mark - Private Helpers

+ (BOOL)hapticsAllowed {
    // Respect user settings and hardware capabilities
    // If Reduce Motion is enabled, avoid haptics
    BOOL reduceMotionEnabled = UIAccessibilityIsReduceMotionEnabled();
    if (reduceMotionEnabled) {
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        // Use Core Haptics to verify hardware support without referencing CHHapticEngineCapabilities directly
        if ([CHHapticEngine respondsToSelector:@selector(capabilitiesForHardware)]) {
            id caps = [CHHapticEngine capabilitiesForHardware];
            if ([caps respondsToSelector:@selector(supportsHaptics)]) {
                return ((BOOL)[caps supportsHaptics]);
            }
        }
        // Fallback to UIFeedbackGenerator availability if capabilities are not accessible
        return [UIFeedbackGenerator class] != nil;
    } else if (@available(iOS 10.0, *)) {
        // Haptic feedback generators are available from iOS 10
        return [UIFeedbackGenerator class] != nil;
    } else {
        return NO;
    }
}

+ (void)generateImpactWithStyle:(UIImpactFeedbackStyle)style {
    if (![self hapticsAllowed]) return;
    
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [generator prepare];
        [generator impactOccurred];
    }
}

+ (void)generateNotificationWithType:(UINotificationFeedbackType)type {
    if (![self hapticsAllowed]) return;
    
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator prepare];
        [generator notificationOccurred:type];
    }
}

@end


