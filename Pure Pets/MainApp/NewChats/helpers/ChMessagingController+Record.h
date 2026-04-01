//
//  ChMessagingController+Record.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/01/2026.
//

#import "ChMessagingController.h"
#import "PPAudioPlaybackController.h"
#import "ChatMessageModel.h"

@interface ChMessagingController (PPRecordHelper)
<
PPAudioPlaybackControllerDelegate,
AVAudioPlayerDelegate
>

#pragma mark - Lifecycle

- (void)viewDidLoadRecordData;

#pragma mark - Recording Control (called by input bar)

- (void)startVoiceRecording;
- (void)finishVoiceRecordingAndSend;
 

#pragma mark - Recording Preview Actions

- (void)sendRecordingPreview;
- (void)cancelRecordingPreview;

#pragma mark - Audio Helpers
 

- (void)prepareLocalAudioForMessage:(ChatMessageModel *)msg
                         completion:(void (^)(NSURL *localURL))completion;

@end

