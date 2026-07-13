//
//  ChMessagingController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//


// ChMessagingController.h
// Pure Pets
//
// Created by Mohammed Ahmed on 28/07/2025.
#import "ChatMessageCell.h"
#import "ChatThreadModel.h"
#import "PPChatHeaderView.h"
#import "TypingIndicatorView.h"
#import "PPChatInputBarView.h"
#import "PPAudioPlaybackController.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, PPRecordingPreviewState) {
    PPRecordingPreviewStateIdle,
    PPRecordingPreviewStatePlaying,
    PPRecordingPreviewStatePaused
};

@protocol ReloadChatsDelegate <NSObject>
-(void)ReloadChats;
@end

@interface ChMessagingController : UIViewController





 @property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<ChatMessageModel *> *messages;
@property (nonatomic, weak) id <ReloadChatsDelegate> delegate;
@property (nonatomic, strong) ChatThreadModel *chatThread;
@property (nonatomic, strong) NSString *fromVC;
@property (nonatomic, assign) BOOL keepsBottomNavigationVisibleForNotificationHandoff;
- (instancetype)initWithChatThread:(ChatThreadModel *)thread;
@property (nonatomic, strong) PPChatHeaderView *chatHeaderView;


@property (nonatomic, strong, nullable) AVAudioPlayer *previewPlayer;
@property (nonatomic, strong,nullable) CADisplayLink *previewDisplayLink;
@property (nonatomic, assign) BOOL isPreviewPlaying;

@property (nonatomic, assign) PPRecordingPreviewState previewState;
 
@property (nonatomic, strong,nullable) CADisplayLink *recordingWaveDisplayLink;
@property (nonatomic, strong,nullable) AVAudioRecorder *audioRecorder;

@property (nonatomic, assign) PPVoiceRecordingState recordingState;
@property (nonatomic, strong) NSDate *recordingStartDate;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *audioResumeTimes;
@property (nonatomic, strong) PPAudioPlaybackController *audioController;
 

@property (nonatomic, strong,nullable) NSURL *currentRecordingURL;
@property (nonatomic, strong,nullable) NSTimer *recordingTimer;

@property (nonatomic, assign) BOOL didFinishRecordingOnce;
@property (nonatomic, assign) BOOL didFinishImageOnce;
@property (nonatomic, assign) BOOL didFinishVidOnce;

@property (nonatomic, strong) TypingIndicatorView *typingIndicatorView;
@property (nonatomic, assign) BOOL isCreatingThread;
@property (nonatomic, assign) CGFloat typingAutoHideThreshold;
 @property (nonatomic, strong) PPChatInputBarView *inputbar;
@end

NS_ASSUME_NONNULL_END
//@property (nonatomic, strong) TypingIndicatorView *typingIndicatorView;


/*
 //
 //  ChMessagingController.h
 //  Pure Pets
 //
 //  Created by Mohammed Ahmed on 19/01/2026.
 //
 #import "ChMessagingController.h"
 #import "PPChatHeaderView.h"
 #import "PPAudioPlaybackController.h"
 #import "ChatAudioMessageCell.h"
 #import "PPChatsFunc.h"
  
 @interface ChMessagingController (PPRecordHelper)<PPAudioPlaybackControllerDelegate,AVAudioPlayerDelegate,AVAudioPlayerDelegate,
 PPAudioPlaybackControllerDelegate>
  
 @property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *audioResumeTimes;
 @property (nonatomic, assign) BOOL wasPreviewPlayingBeforeScrub;
 @property (nonatomic, strong) NSIndexPath *currentlyPlayingAudioIndexPath;
 @property (nonatomic, strong) CADisplayLink *audioCellPlaybackLink;
 @property (nonatomic, strong) PPAudioPlaybackController *audioController;

 @property (nonatomic, strong) UIView *actionButtonContainer;

  @property (nonatomic, strong) NSTimer *recordingTimer;
  @property (nonatomic, strong) UILabel *recordingPreviewTimeLabel;
 @property (nonatomic, strong) UIView *recordingPreviewThumb;
 @property (nonatomic, strong) UIImpactFeedbackGenerator *scrubHaptic;
 @property (nonatomic, assign) NSInteger lastScrubTick;
 @property (nonatomic, strong) UIProgressView *recordingPreviewProgress;
 @property (nonatomic, strong) UIButton *recordingPreviewSendButton;
 @property (nonatomic, strong) UIButton *recordingPreviewCancelButton;
 @property (nonatomic, strong) AVAudioPlayer *previewPlayer;
 @property (nonatomic, assign) BOOL isPreviewPlaying;

 @property (nonatomic, strong) NSURL *currentRecordingURL;



 @property (nonatomic, strong) AVAudioRecorder *audioRecorder;
 @property (nonatomic, strong) NSTimer *silenceTimer;
 @property (nonatomic, assign) NSTimeInterval lastSoundTimestamp;
 @property (nonatomic, strong) CADisplayLink *playbackDisplayLink;
 @property (nonatomic, strong) CADisplayLink *recordingWaveDisplayLink;
 @property (nonatomic, strong) NSLayoutConstraint *recordingPreviewThumbLeadingConstraint;
  @property (nonatomic, strong) UIActivityIndicatorView *recordingSendSpinner;
 @property (nonatomic, assign) BOOL isUploadingRecording;
 - (void)setupInputView;
 @property (nonatomic, strong) UIButton *attachButton;
 @property (nonatomic, strong) UIButton *micButton;
 @property (nonatomic, strong) UIView *recordingPreviewBubble;
 @property (nonatomic, assign) BOOL isRecordingLocked;
 @property (nonatomic, assign) CGPoint micInitialTouchPoint;
  
 @property (nonatomic, assign) BOOL isHoldingMic;

 // === Recording Lock Pill ===
 @property (nonatomic, strong) UIView *recordingLockPill;
 @property (nonatomic, strong) UIImageView *lockIconView;
 @property (nonatomic, strong) UIButton *cancelRecordingButton;
 @property (nonatomic, strong) NSLayoutConstraint *lockPillTopConstraint;

  
 - (void)stopRecordingTimer;
 -(void)viewDidLoadRecordData;
 - (NSURL *)createNewRecordingURL;
 - (void)startRecordingWaveUpdates;


 - (void)micTouchUp;
 - (void)micTouchCancel;
 - (void)finishVoiceRecordingAndSend;
 - (void)sendRecordingPreview;
 - (void)cancelRecordingPreview;
 - (void)prepareLocalAudioForMessage:(ChatMessageModel *)msg
                          completion:(void (^)(NSURL *localURL))completion;
 @end

 */
