//
//  PPCommerceFeedbackManager.h
//  Pure Pets
//
//  Centralized commerce sound + haptic feedback manager.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, PPCommerceFeedbackEvent) {
    PPCommerceFeedbackEventCartQuantityChanged = 0,
    PPCommerceFeedbackEventCartItemRemoved,
    PPCommerceFeedbackEventCartUndo,
    PPCommerceFeedbackEventPaymentAction,
    PPCommerceFeedbackEventPaymentSuccess,
    PPCommerceFeedbackEventPaymentFailure,
    PPCommerceFeedbackEventRootTabSelected
};

NS_ASSUME_NONNULL_BEGIN

@interface PPCommerceFeedbackManager : NSObject

+ (instancetype)shared;
- (void)playEvent:(PPCommerceFeedbackEvent)event;

@end

NS_ASSUME_NONNULL_END
