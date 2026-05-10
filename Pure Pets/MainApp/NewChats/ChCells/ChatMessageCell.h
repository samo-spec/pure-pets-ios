//
//  ChatMessageCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//


// ChatMessageCell.h

#import <UIKit/UIKit.h>
#import "ChatBubbleView.h"

#import "ChatMessageModel.h"
NS_ASSUME_NONNULL_BEGIN

@class ChatMessageCell;

@protocol ChatMessageCellDelegate <NSObject>
@optional
- (void)chatMessageCellDidRequestCopy:(ChatMessageCell *)cell;
- (void)chatMessageCellDidRequestReply:(ChatMessageCell *)cell;
@end

@interface ChatMessageCell : UITableViewCell
- (BOOL)isSingleLineMessage;
@property (nonatomic, strong) ChatBubbleView *bubbleView;
@property (nonatomic, weak) id<ChatMessageCellDelegate> delegate;

- (void)configureWithMessage:(NSString *)message
                        date:(NSDate *)date
                  isIncoming:(BOOL)isIncoming
                    maxWidth:(CGFloat)maxWidth
                      status:(ChatMessageStatus)status
                messageModel:(ChatMessageModel *)messageModel
               groupPosition:(PPChatGroupPosition)groupPosition;

@property (nonatomic, copy) NSString *boundMessageID;

@property (nonatomic, assign) BOOL didAnimateInsert;
// Constraints we will toggle/update
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleTrailingConstraint;
- (void)updateMessageStatus:(ChatMessageModel *)message;
@property (nonatomic, strong) NSLayoutConstraint *bubbleMaxWidthConstraint;
@end





NS_ASSUME_NONNULL_END
