//
//  ChatStickerMessageCell.h
//  Pure Pets
//
//  Created by Codex on 17/07/2026.
//

#import <UIKit/UIKit.h>

@class ChatMessageModel;

NS_ASSUME_NONNULL_BEGIN

@interface ChatStickerMessageCell : UITableViewCell

+ (CGFloat)preferredCellHeight;

- (void)configureWithMessage:(ChatMessageModel *)message
                  isIncoming:(BOOL)isIncoming;
- (void)updateMessageStatus:(ChatMessageModel *)message;
- (UIView *)messageInteractionView;

@end

NS_ASSUME_NONNULL_END
