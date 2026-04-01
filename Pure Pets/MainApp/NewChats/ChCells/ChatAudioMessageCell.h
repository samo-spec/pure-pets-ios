//
//  ChatAudioMessageCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import <UIKit/UIKit.h>

@interface ChatAudioMessageCell : UITableViewCell
@property (nonatomic, copy) NSString *boundMessageID;
@property (nonatomic, strong, readonly) UIButton *playPauseButton;
@property (nonatomic, copy) void (^onPlayPauseTapped)(void);
@property (nonatomic, assign) BOOL hasAppearedOnce;/// UI-only setters (controller drives them)
- (void)setPlaying:(BOOL)isPlaying;
- (void)setProgress:(CGFloat)progress;
- (void)setCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration;
@property (nonatomic, copy) void (^onScrubToProgress)(CGFloat progress);
- (void)updateMessageStatus:(ChatMessageModel *)message;

/// Layout
- (void)setIncoming:(BOOL)isIncoming maxWidth:(CGFloat)maxWidth
             status:(ChatMessageStatus)status
                msg:(ChatMessageModel *)msg
      groupPosition:(PPChatGroupPosition)groupPosition;

@property (nonatomic, assign) PPBubblePosition bubblePosition;

@property (nonatomic, strong) NSLayoutConstraint *bubbleLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleTrailingConstraint;
- (void)setBottomTimeText:(NSDate *)date;
- (void)setStatusImage:(UIImage *)image;
- (void)setTotalDuration:(NSTimeInterval)duration;
- (void)setLoading:(BOOL)isLoading;

- (void)applyPlaybackStateForMessageID:(NSString *)messageID
                              progress:(CGFloat)progress
                              isPlaying:(BOOL)isPlaying
                              duration:(NSTimeInterval)duration;
@end
