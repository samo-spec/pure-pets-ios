//
//  ChatImageMessageCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import <UIKit/UIKit.h>
#import "ChatBubbleView.h"

@class ChatImageMessageCell;

@protocol ChatImageMessageCellDelegate <NSObject>
@optional
- (void)chatImageMessageCellDidTapView:(ChatImageMessageCell *)cell;
- (void)chatImageMessageCellDidTapDownload:(ChatImageMessageCell *)cell;
- (void)chatImageMessageCellDidRequestReply:(ChatImageMessageCell *)cell;
@end

@interface ChatImageMessageCell : UITableViewCell
@property (nonatomic, strong) NSNumber *imageAspectRatio; // height / width
@property (nonatomic, strong) ChatBubbleView *bubbleView;
@property (nonatomic, strong) UIImageView *imageViewMsg;
@property (nonatomic, assign) PPBubblePosition bubblePosition;
@property (nonatomic, weak) id<ChatImageMessageCellDelegate> delegate;

- (void)configureWithImageURL:(NSString *)imageURL
                    isIncoming:(BOOL)isIncoming
                      maxWidth:(CGFloat)maxWidth
                      message:(ChatMessageModel *)message
                groupPosition:(PPChatGroupPosition)groupPosition;
- (void)updateMessageStatus:(ChatMessageModel *)message;
- (void)setReplyPreviewTitle:(nullable NSString *)title
                    subtitle:(nullable NSString *)subtitle
                  isIncoming:(BOOL)isIncoming;
- (void)clearReplyPreview;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, assign) BOOL didFailLoading;
@property (nonatomic, assign) BOOL didAnimateInsert;
@property (nonatomic, copy) NSString *boundMessageID;
@property (nonatomic, strong) NSLayoutConstraint *aspectRatioConstraint;
- (void)updateUploadingState:(ChatMessageModel *)message;
 @end
