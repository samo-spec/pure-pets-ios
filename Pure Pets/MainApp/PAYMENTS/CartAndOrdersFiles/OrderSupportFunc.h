//
//  OrderSupportFunc.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#ifndef OrderSupportFunc_h
#define OrderSupportFunc_h

#import <UIKit/UIKit.h>

@class PPOrderTimelineEvent;

extern CGFloat const kOrderDetailsScreenMargin;

typedef NS_ENUM(NSInteger, PPOrderCustomerActionType) {
    PPOrderCustomerActionTypeTrack,
    PPOrderCustomerActionTypeCancel,
    PPOrderCustomerActionTypeReturn,
    PPOrderCustomerActionTypeRefund,
    PPOrderCustomerActionTypeReplacement,
    PPOrderCustomerActionTypeComplaint,
    PPOrderCustomerActionTypeSupport
};
NS_ASSUME_NONNULL_BEGIN
@interface UIViewController (PPOrderChevronBack)
- (void)pp_orderApplyChevronBackButton;
- (void)pp_orderHandleChevronBack;
@end

UIColor *PPOrderDetailsSurfaceColor(void);
UIColor *PPOrderDetailsSubsurfaceColor(void);
void PPOrderDetailsApplySurface(UIView *view, CGFloat cornerRadius, BOOL elevated);
UIColor *PPOrderRequestStatusColor(NSString *status);
NSString *PPOrderStepperSymbolForTitle(NSString *title, NSInteger index);
UIImage * _Nullable PPOrderStepperImage(NSString *name);
NSString *PPOrderTimelineTitle(PPOrderTimelineEvent *event);
NSString *PPOrderTimelineSubtitle(PPOrderTimelineEvent *event);


static NSString * const PPOrderStepperCurrentDotMotionKey = @"pp_stepper_current_dot_breath";
static NSString * const PPOrderStepperCurrentHaloScaleKey = @"pp_stepper_current_halo_breath";
static NSString * const PPOrderStepperCurrentHaloOpacityKey = @"pp_stepper_current_halo_opacity";
static NSString * const PPOrderStepperCurrentIconMotionKey = @"pp_stepper_current_icon_settle";
static NSString * const PPOrderStepperCurrentLabelFloatKey = @"pp_stepper_current_label_float";
static NSString * const PPOrderStepperCurrentLabelOpacityKey = @"pp_stepper_current_label_opacity";
static NSString * const PPOrderStepperLegacyDotPulseKey = @"pp_stepper_dot_pulse";
static NSString * const PPOrderStepperLegacyHaloScaleKey = @"pp_stepper_halo_scale";
static NSString * const PPOrderStepperLegacyHaloOpacityKey = @"pp_stepper_halo_opacity";
static NSString * const PPOrderTimelineCurrentMarkerMotionKey = @"pp_timeline_current_marker_breath";
static NSString * const PPOrderTimelineCurrentHaloScaleKey = @"pp_timeline_current_halo_scale";
static NSString * const PPOrderTimelineCurrentHaloOpacityKey = @"pp_timeline_current_halo_opacity";
static NSString * const PPOrderTimelineCurrentIconMotionKey = @"pp_timeline_current_icon_breath";
static NSString * const PPOrderTimelineCurrentTitleFloatKey = @"pp_timeline_current_title_float";
static NSString * const PPOrderTimelineCurrentTitleOpacityKey = @"pp_timeline_current_title_opacity";
static NSString * const PPOrderSummaryStatusBadgeMotionKey = @"pp_summary_status_badge_breath";
static NSString * const PPOrderSummaryStatusHaloScaleKey = @"pp_summary_status_halo_scale";
static NSString * const PPOrderSummaryStatusHaloOpacityKey = @"pp_summary_status_halo_opacity";
static NSString * const PPOrderSummaryStatusIconMotionKey = @"pp_summary_status_icon_float";
static NSString * const PPOrderSummaryProgressChipMotionKey = @"pp_summary_progress_chip_breath";
static NSString * const PPOrderSummaryTimelineCounterMotionKey = @"pp_summary_timeline_counter_breath";
static NSString * const PPOrderSummaryAmbientDot1MotionKey = @"pp_summary_ambient_dot_1_orbit";
static NSString * const PPOrderSummaryAmbientDot2MotionKey = @"pp_summary_ambient_dot_2_orbit";
static NSString * const PPOrderSummaryAmbientDot3MotionKey = @"pp_summary_ambient_dot_3_orbit";


NS_ASSUME_NONNULL_END

#endif /* OrderSupportFunc_h */
