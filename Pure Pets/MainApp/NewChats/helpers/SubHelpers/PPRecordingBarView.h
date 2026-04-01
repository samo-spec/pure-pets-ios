//
//  PPRecordingBarView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/01/2026.
//


#import <UIKit/UIKit.h>
#import "PPWaveformView.h"
typedef NS_ENUM(NSUInteger, PPRecordingBarState) {
    PPRecordingBarStateHidden,
    PPRecordingBarStateRecording,
    PPRecordingBarStateLocked,
    PPRecordingBarStatePreview
};

 
@protocol PPRecordingBarViewDelegate <NSObject>

- (void)recordingBarDidTapSend;
- (void)recordingBarDidTapCancel;
- (void)recordingBarDidTapPlayPause;
// 🔥 NEW — state-aware
- (void)recordingBarDidTapPlayFromLocked;
- (void)recordingBarDidTogglePlayback;

@end


@class PPWaveformView;

@interface PPRecordingBarView : UIView
@property (nonatomic, strong, readwrite) PPWaveformView *waveformView;
@property (nonatomic, assign) PPRecordingBarState state;

// UI
@property (nonatomic, strong, readonly) PPInsetLabel *timeLabel;
@property (nonatomic, strong, readonly) UILabel *hintLabel;
@property (nonatomic, strong, readonly) UIButton *sendButton;
@property (nonatomic, strong, readonly) UIButton *cancelButton;
- (void)setDeleteButtonVisible:(BOOL)visible animated:(BOOL)animated;
// State updates
- (void)setRecordingState:(PPRecordingBarState)state animated:(BOOL)animated;

// Recording
- (void)updateDuration:(NSTimeInterval)duration;
- (void)appendWaveformSample:(float)level;

// Preview
- (void)prepareForPreview;

// Reset
- (void)reset;
- (void)setPlaying:(BOOL)isPlaying animated:(BOOL)animated;
/// Update duration label (mm:ss)
@property (nonatomic, weak) id<PPRecordingBarViewDelegate> delegate;
 
@end
