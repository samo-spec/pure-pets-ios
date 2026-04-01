//
//  ChatMessageCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//


// ChatMessageCell.m

#import "ChatMessageCell.h"
#import "PPChatsFunc.h"

@interface ChatMessageCell()<PPChatBubbleColorProviding,ChatMessageStatusUpdatable>
@property (nonatomic, assign) PPChatGroupPosition groupPosition;
@property (nonatomic, assign) BOOL isIncoming;
@property (nonatomic, strong) ChatMessageModel *message;
@property (nonatomic, assign) BOOL didUpdateLayoutOnce;

@end
@implementation ChatMessageCell

- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL glow = _isIncoming && _groupPosition != PPChatGroupPositionMiddle;
    [PPChatsFunc applyBubbleMask:self.bubbleView isIncoming:self.isIncoming groupPosition:self.groupPosition showGlow:glow];

}

- (UITableView *)parentTableView {
    UIView *view = self.superview;
    while (view && ![view isKindOfClass:UITableView.class]) {
        view = view.superview;
    }
    return (UITableView *)view;
}

-(UIColor *)pp_bubbleBackgroundColor
{
    UIColor *soft =
    [PPColorUtils blendColor:AppBackgroundClrDarker
                        withColor:PPChatBackground
                           factor:0.75];
    return soft;
}

 

-(BOOL)isSingleLineMessage
{
    return self.bubbleView.isSingleLineMessage;;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupBubbleView];
        
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)setupBubbleView {
    self.bubbleView = [[ChatBubbleView alloc] init];
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.bubbleView];
    
    CGFloat spacingAbove = PPChatBubblePad;
    CGFloat spacingBelow = PPChatBubblePad;
    CGFloat horizontalMargin = 12.0;
    
    // Top / bottom
    [NSLayoutConstraint activateConstraints:@[
        [self.bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:spacingAbove],
        [self.bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-spacingBelow]
    ]];
    
    // Leading / trailing – we toggle which is active later
    self.bubbleLeadingConstraint =
        [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:horizontalMargin];
    
    self.bubbleTrailingConstraint =
        [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-horizontalMargin];
    
    // Start with incoming style (e.g. leading). We’ll override in configure.
    self.bubbleLeadingConstraint.active = YES;
    self.bubbleTrailingConstraint.active = NO;
    
    // Max width constraint – constant updated in configureWithMessage:…
    
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.didUpdateLayoutOnce = NO;
    self.bubbleLeadingConstraint.active = YES;
    self.bubbleTrailingConstraint.active = NO;
}

- (void)configureWithMessage:(NSString *)message
                        date:(NSDate *)date
                  isIncoming:(BOOL)isIncoming
                    maxWidth:(CGFloat)maxWidth
                      status:(ChatMessageStatus)status
                messageModel:(ChatMessageModel *)messageModel
               groupPosition:(PPChatGroupPosition)groupPosition
{
    
    self.isIncoming = isIncoming;
    self.message = messageModel;
    self.groupPosition = groupPosition;
    self.boundMessageID = messageModel.ID;
    // Max bubble width (same logic as before)
    CGFloat maxBubbleWidth = messageModel.mediaWidth ?: maxWidth * 0.8;
    NSLog(@"maxBubbleWidth %f",maxBubbleWidth);
    self.bubbleMaxWidthConstraint = [self.bubbleView.widthAnchor constraintLessThanOrEqualToConstant:maxBubbleWidth];
    self.bubbleMaxWidthConstraint.active = YES;
    
    //self.bubbleMaxWidthConstraint.constant = maxBubbleWidth;
    
    // Configure bubble content
    [self.bubbleView setMessageText:message
                               time:date
                         isIncoming:isIncoming
                             status:status];
    
    // Toggle horizontal alignment
    if (isIncoming) {
        // Incoming → TRAILING (right)
        self.bubbleLeadingConstraint.active = NO;
        self.bubbleTrailingConstraint.active = YES;
    } else {
        // Outgoing → LEADING (left)
        self.bubbleLeadingConstraint.active = YES;
        self.bubbleTrailingConstraint.active = NO;
    }
}

/// Update only the status-related UI (status icon/tint) for the given message, if currently bound.
- (void)updateMessageStatus:(ChatMessageModel *)message
{
    // Only update if bound to this message
    if (!self.boundMessageID || ![self.boundMessageID isEqualToString:message.ID]) {
        return;
    }
    self.message = message;
    // Only update status icon/tint for outgoing messages
    if (!self.isIncoming) {
        // Helper block to encapsulate status icon logic
        void (^updateStatusIcon)(void) = ^{
            UIImage *icon = nil;
            UIColor *tint = [UIColor grayColor];
            switch (message.status) {
                case ChatMessageStatusSending:
                    icon = [UIImage systemImageNamed:@"clock"];
                    tint = [AppForgroundColr colorWithAlphaComponent:0.4];
                    break;
                case ChatMessageStatusSent:
                    icon = [UIImage systemImageNamed:@"checkmark"];
                    tint = [AppForgroundColr colorWithAlphaComponent:0.4];
                    break;
                case ChatMessageStatusDelivered:
                    icon = [UIImage imageNamed:@"checked"];
                    tint = [AppForgroundColr colorWithAlphaComponent:0.4];
                    break;
                case ChatMessageStatusRead:
                    icon = [UIImage imageNamed:@"checked"];
                    tint = AppForgroundColr;
                    break;
                default:
                    icon = nil;
                    break;
            }
            self.bubbleView.getStatusImageView.image = icon;
            self.bubbleView.getStatusImageView.tintColor = tint;
            self.bubbleView.getStatusImageView.hidden = (icon == nil);
        };
        updateStatusIcon();
    }
    // Do not touch thumbnail, loading, play state, or applyVisualState.
}
@end









 
