//
//  PPChatInputBarView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/01/2026.
//


#import <UIKit/UIKit.h>
#import "PPRecordingBarView.h"
#import "PPRecordingLockPillView.h"


typedef NS_ENUM(NSUInteger, PPActionButtonMode) {
    PPActionButtonModeRecord,
    PPActionButtonModeSend
};
@class PPChatInputBarView;
NS_ASSUME_NONNULL_BEGIN
@protocol PPChatInputBarViewDelegate <NSObject>
- (void)inputBar:(PPChatInputBarView *)bar  didSendText:(NSString *)text;
- (void)inputBar:(PPChatInputBarView *)bar  didChangeText:(UITextView *)textView;
- (void)inputBarDidStartRecording:(PPChatInputBarView *)bar;
- (void)inputBar:(PPChatInputBarView *)bar didFinishRecordingWithURL:(nullable NSURL *)fileURL duration:(NSTimeInterval)duration  locked:(BOOL)locked;
- (void)inputBarDidCancelRecording:(PPChatInputBarView *)bar;
- (void)inputBarDidTapAttachImage:(PPChatInputBarView *)bar;
- (void)inputBarDidTapAttachVideo:(PPChatInputBarView *)bar;
- (void)inputBar:(PPChatInputBarView *)bar didChangeHeight:(CGFloat)newHeight;
@optional
- (void)inputBarDidCancelReply:(PPChatInputBarView *)bar;
@required
- (void)inputBarDidToggleRecordingPreview:(PPChatInputBarView *)bar;
- (void)finishVoiceRecordingAndSend;
- (void)inputBarDidStopRecordingPreview:(PPChatInputBarView *)bar;
// 🔥 NEW — state-aware
- (void)recordingBarDidTapPlayFromLocked;
- (void)recordingBarDidTogglePlayback;
@end


@interface PPChatInputBarView : UIView
@property (nonatomic, weak) id<PPChatInputBarViewDelegate> delegate;
- (void)updateRecordingDuration:(NSTimeInterval)duration;
- (void)setRecordingLocked:(BOOL)locked;
- (void)resetRecordingUI;
- (void)appendRecordingWaveSample:(float)level;
- (void)setReplyPreviewTitle:(NSString *)title subtitle:(NSString *)subtitle animated:(BOOL)animated;
- (void)clearReplyPreviewAnimated:(BOOL)animated;
@property (nonatomic, strong) PPRecordingBarView *recordingBar;
@property (nonatomic, assign) PPActionButtonMode actionMode;
@property (nonatomic, strong) PPRecordingLockPillView *lockPill;
@property (nonatomic, strong,nullable) NSURL *currentRecordingURL;
@property (nonatomic, assign) NSTimeInterval currentRecordingDuration;

@end
NS_ASSUME_NONNULL_END
