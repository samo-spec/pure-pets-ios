//
//  GM.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/11/2025.
//


//
//  GM+Haptics.h
//  PurePets
//

#import "PPFunc.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPFunc (Haptics)

+ (void)triggerLightHaptic;
+ (void)triggerMediumHaptic;
+ (void)triggerHeavyHaptic;
+ (void)triggerSuccessHaptic;
+ (void)triggerWarningHaptic;
+ (void)triggerErrorHaptic;

@end

NS_ASSUME_NONNULL_END
