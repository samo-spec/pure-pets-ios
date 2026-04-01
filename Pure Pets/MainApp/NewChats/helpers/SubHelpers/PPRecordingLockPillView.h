//
//  PPRecordingLockPillView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/01/2026.
//


#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PPRecordingLockPillState) {
    PPRecordingLockPillStateHidden,
    PPRecordingLockPillStateIdle,     // arrow animating
    PPRecordingLockPillStateLocked    // lock confirmed
};

@interface PPRecordingLockPillView : UIView

@property (nonatomic, assign) PPRecordingLockPillState state;
- (void)setState:(PPRecordingLockPillState)state animated:(BOOL)animated;
@end
