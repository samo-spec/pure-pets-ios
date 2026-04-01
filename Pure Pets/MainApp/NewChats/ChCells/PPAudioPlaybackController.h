//
//  PPAudioPlaybackController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class PPAudioPlaybackController;

@protocol PPAudioPlaybackControllerDelegate <NSObject>
@required
- (void)audioPlaybackControllerDidUpdate:
    (PPAudioPlaybackController *)controller
                                 messageID:(NSString *)messageID
                                   progress:(CGFloat)progress
                                   duration:(NSTimeInterval)duration
                                   isPlaying:(BOOL)isPlaying;

- (void)audioPlaybackControllerDidUpdateProgress:(CGFloat)progress isPlaying:(BOOL)isPlaying;
@end

@interface PPAudioPlaybackController : NSObject
@property (nonatomic, readonly) NSTimeInterval currentPlaybackTime;
- (void)seekToTime:(NSTimeInterval)time;
@property (nonatomic, weak) id<PPAudioPlaybackControllerDelegate> delegate;
@property (nonatomic, readonly) NSString *currentMessageID;
@property (nonatomic, readonly) NSTimeInterval playerDuration;
- (void)playMessageID:(NSString *)messageID
                  url:(NSURL *)url;


- (void)togglePlayPause;
- (void)stop;

@end
