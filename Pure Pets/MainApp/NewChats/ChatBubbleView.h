//
//  ChatBubbleView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//  Refactored to use Auto Layout
//

#import <UIKit/UIKit.h>


#import "ChatMessageModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface ChatBubbleView : UIView


@property (nonatomic) ChatBubbleContentType contentType;

@property (nonatomic, readonly) UILabel *messageLabel;
@property (nonatomic, readonly) UILabel *timeLabel;
@property (nonatomic, readonly) UIImageView *statusImageView;
/// If you want to control maximum bubble width from the outside
@property (nonatomic) CGFloat maxBubbleWidth;
-(UIImageView *)getStatusImageView;
/// Whether this bubble is incoming
@property (nonatomic, readonly) BOOL isIncoming;
- (BOOL)isSingleLineMessage;
- (void)setMessageText:(NSString *)message
                  time:(NSDate *)date
           isIncoming:(BOOL)isIncoming
               status:(ChatMessageStatus)status;
 @end

NS_ASSUME_NONNULL_END
