//
//  PPAudioPlaybackController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import "PPAudioPlaybackController.h"

@interface PPAudioPlaybackController () <AVAudioPlayerDelegate>
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSString *currentMessageID;
@property (nonatomic, assign) BOOL didAnimateInsert;
@end

@implementation PPAudioPlaybackController

- (NSTimeInterval)currentPlaybackTime
{
    return self.player ? self.player.currentTime : 0;
}

- (void)seekToTime:(NSTimeInterval)time
{
    if (!self.player) return;

    self.player.currentTime =
        MAX(0, MIN(time, self.player.duration));
}
- (NSTimeInterval)playerDuration
{
    return self.player ? self.player.duration : 0;
}

- (void)playMessageID:(NSString *)messageID url:(NSURL *)url
{
    if (!url) return;

    // Stop previous
    [self stop];

    self.currentMessageID = messageID;

    AVAudioSession *session = AVAudioSession.sharedInstance;
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionDuckOthers
                   error:nil];
    [session setActive:YES error:nil];

    NSError *err = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    if (err || !self.player) return;

    self.player.delegate = self;
    [self.player prepareToPlay];
    [self.player play];
    [self startDisplayLink];
}


- (void)tick {
    if (!self.player || !self.player.isPlaying) return;

    CGFloat progress =
        self.player.duration > 0
        ? self.player.currentTime / self.player.duration
        : 0;

    [self.delegate audioPlaybackControllerDidUpdate:self
                                           messageID:self.currentMessageID
                                            progress:progress
                                            duration:self.player.duration
                                           isPlaying:YES];
}


- (void)togglePlayPause
{
    if (!self.player) return;

    if (self.player.isPlaying) {
        [self.player pause];
    } else {
        [self.player play];
    }
}

- (void)startDisplayLink
{
    [self stopDisplayLink];

    self.displayLink =
        [CADisplayLink displayLinkWithTarget:self
                                    selector:@selector(tick)];

    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop
                           forMode:NSRunLoopCommonModes];
}

- (void)stopDisplayLink
{
    [self.displayLink invalidate];
    self.displayLink = nil;
}


- (void)stop
{
    [self stopDisplayLink];
    [self.player stop];
    self.player = nil;
    self.currentMessageID = nil;
}

#pragma mark - AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self stop];
}

@end
