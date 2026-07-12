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
    return [PPChatsFunc bubbleSurfaceColorForIncoming:self.isIncoming];
}

 

-(BOOL)isSingleLineMessage
{
    return self.bubbleView.isSingleLineMessage;;
}

- (UIView *)messageInteractionView
{
    return self.bubbleView;
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
    self.bubbleMaxWidthConstraint.active = NO;
    self.bubbleMaxWidthConstraint = nil;
    self.bubbleLeadingConstraint.active = YES;
    self.bubbleTrailingConstraint.active = NO;
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.accessibilityCustomActions = nil;
    self.bubbleView.accessibilityCustomActions = nil;
    [self.bubbleView setContextMenuPresentationActive:NO];
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
    self.bubbleView.groupPosition = groupPosition;
    self.boundMessageID = messageModel.ID;
    CGFloat availableWidth = MAX(140.0, UIScreen.mainScreen.bounds.size.width - 48.0);
    CGFloat maxBubbleWidth = MAX(140.0, MIN(maxWidth, availableWidth));
    self.bubbleMaxWidthConstraint.active = NO;
    self.bubbleMaxWidthConstraint = [self.bubbleView.widthAnchor constraintLessThanOrEqualToConstant:maxBubbleWidth];
    self.bubbleMaxWidthConstraint.active = YES;
    self.bubbleView.maxBubbleWidth = maxBubbleWidth;
    
    //self.bubbleMaxWidthConstraint.constant = maxBubbleWidth;
    
    // Configure bubble content
    [self.bubbleView setMessageText:message
                               time:date
                         isIncoming:isIncoming
                             status:status];
    
    // Toggle horizontal alignment
    BOOL usesTrailing = [PPChatsFunc bubbleUsesTrailingAlignmentForIncoming:isIncoming];
    self.bubbleLeadingConstraint.active = !usesTrailing;
    self.bubbleTrailingConstraint.active = usesTrailing;
    [self.bubbleView setDeleted:messageModel.isDeleted animated:NO];
    [self setNeedsLayout];
}

/// Update only the status-related UI (status icon/tint) for the given message, if currently bound.
- (void)updateMessageStatus:(ChatMessageModel *)message
{
    // Only update if bound to this message
    if (!self.boundMessageID || ![self.boundMessageID isEqualToString:message.ID]) {
        return;
    }
    self.message = message;
    [self.bubbleView updateMessageStatus:message animated:YES];
    // Do not touch thumbnail, loading, play state, or applyVisualState.
}

@end









 
