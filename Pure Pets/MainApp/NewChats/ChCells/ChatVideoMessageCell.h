//
//  ChatVideoMessageCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//

 
#import <UIKit/UIKit.h>
#import "ChatMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChatVideoMessageCell : UITableViewCell

@property (nonatomic, copy) void (^onPlayTapped)(void);
@property (nonatomic, copy, nullable) NSString *boundMessageID;

- (void)configureWithMessage:(ChatMessageModel *)message
                  isIncoming:(BOOL)isIncoming
                    maxWidth:(CGFloat)maxWidth
               groupPosition:(PPChatGroupPosition)groupPosition;

// ✅ REQUIRED PUBLIC STATE API
- (void)setLoading:(BOOL)isLoading;
- (void)setProgress:(CGFloat)progress;
- (void)setPlaying:(BOOL)isPlaying;
- (void)updateThumbnail:(UIImage *)image;

- (CGRect)thumbnailFrameInWindow;
- (void)updateMessageStatus:(ChatMessageModel *)message;
@end
NS_ASSUME_NONNULL_END
