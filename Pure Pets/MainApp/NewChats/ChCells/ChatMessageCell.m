//
//  ChatMessageCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//


// ChatMessageCell.m

#import "ChatMessageCell.h"
#import "PPChatsFunc.h"

@interface ChatMessageCell()<PPChatBubbleColorProviding,ChatMessageStatusUpdatable,UIContextMenuInteractionDelegate>
@property (nonatomic, assign) PPChatGroupPosition groupPosition;
@property (nonatomic, assign) BOOL isIncoming;
@property (nonatomic, strong) ChatMessageModel *message;
@property (nonatomic, assign) BOOL didUpdateLayoutOnce;
@property (nonatomic, assign) float ppContextPreviousShadowOpacity;
@property (nonatomic, assign) BOOL ppContextSuppressedShadow;
@property (nonatomic, strong) UIColor *ppContextBubbleBackgroundColor;
@property (nonatomic, assign) BOOL ppContextHasBubbleBackgroundColor;

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
    
    // Long-press context menu (Copy / Reply)
    UIContextMenuInteraction *menuInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [self.bubbleView addInteraction:menuInteraction];
    
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
    [self pp_setContextFocusSuppressed:NO];
    self.ppContextBubbleBackgroundColor = nil;
    self.ppContextHasBubbleBackgroundColor = NO;
    self.didUpdateLayoutOnce = NO;
    self.bubbleMaxWidthConstraint.active = NO;
    self.bubbleMaxWidthConstraint = nil;
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
    self.bubbleMaxWidthConstraint.active = NO;
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

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self pp_restoreContextBubbleBackgroundIfNeeded];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self pp_restoreContextBubbleBackgroundIfNeeded];
}

#pragma mark - Long-Press Context Menu

- (nullable UIColor *)pp_visibleBubbleBackgroundColor
{
    UIColor *color = self.bubbleView.backgroundColor;
    if (!color) {
        return nil;
    }

    CGFloat alpha = CGColorGetAlpha(color.CGColor);
    return alpha > 0.01 ? color : nil;
}

- (void)pp_captureContextBubbleBackgroundIfNeeded
{
    UIColor *color = [self pp_visibleBubbleBackgroundColor];
    self.ppContextBubbleBackgroundColor = color;
    self.ppContextHasBubbleBackgroundColor = (color != nil);
}

- (UIColor *)pp_contextPreviewBackgroundColor
{
    if (self.ppContextHasBubbleBackgroundColor && self.ppContextBubbleBackgroundColor) {
        return self.ppContextBubbleBackgroundColor;
    }
    return [self pp_visibleBubbleBackgroundColor] ?: UIColor.clearColor;
}

- (void)pp_restoreContextBubbleBackgroundIfNeeded
{
    if (self.ppContextHasBubbleBackgroundColor && self.ppContextBubbleBackgroundColor) {
        self.bubbleView.backgroundColor = self.ppContextBubbleBackgroundColor;
    }
}

- (void)pp_setContextFocusSuppressed:(BOOL)suppressed
{
    if (suppressed) {
        if (!self.ppContextSuppressedShadow) {
            self.ppContextPreviousShadowOpacity = self.bubbleView.layer.shadowOpacity;
            [self pp_captureContextBubbleBackgroundIfNeeded];
        }
        self.ppContextSuppressedShadow = YES;
        [self pp_restoreContextBubbleBackgroundIfNeeded];
        self.bubbleView.layer.shadowOpacity = 0.0;
        return;
    }

    if (self.ppContextSuppressedShadow) {
        self.bubbleView.layer.shadowOpacity = self.ppContextPreviousShadowOpacity;
    }
    [self pp_restoreContextBubbleBackgroundIfNeeded];
    self.ppContextSuppressedShadow = NO;
    self.ppContextBubbleBackgroundColor = nil;
    self.ppContextHasBubbleBackgroundColor = NO;
}

- (nullable UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                         configurationForMenuAtLocation:(CGPoint)location
{
    UIImpactFeedbackGenerator *feedback =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurredWithIntensity:0.45];
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [self makeContextMenu];
    }];
}

- (UIMenu *)makeContextMenu
{
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];

    // Reply action first: holding a message should make the reply path feel primary.
    UIImage *replyIcon = [UIImage systemImageNamed:@"arrowshape.turn.up.left"];
    UIAction *replyAction = [UIAction actionWithTitle:kLang(@"reply")
                                                image:replyIcon
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
        if ([self.delegate respondsToSelector:@selector(chatMessageCellDidRequestReply:)]) {
            [self.delegate chatMessageCellDidRequestReply:self];
        }
    }];
    [actions addObject:replyAction];
    
    // Copy action
    if (self.message.text.length > 0) {
        UIImage *copyIcon = [UIImage systemImageNamed:@"doc.on.doc"];
        UIAction *copyAction = [UIAction actionWithTitle:kLang(@"copy")
                                                   image:copyIcon
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = self.message.text;
            if ([self.delegate respondsToSelector:@selector(chatMessageCellDidRequestCopy:)]) {
                [self.delegate chatMessageCellDidRequestCopy:self];
            }
        }];
        [actions addObject:copyAction];
    }

    return [UIMenu menuWithTitle:@"" children:actions];
}

- (nullable UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                       previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    [self pp_setContextFocusSuppressed:YES];
    UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
    parameters.backgroundColor = [self pp_contextPreviewBackgroundColor];
    parameters.visiblePath =
        [UIBezierPath bezierPathWithRoundedRect:self.bubbleView.bounds
                                   cornerRadius:30.0];
    return [[UITargetedPreview alloc] initWithView:self.bubbleView
                                       parameters:parameters];
}

- (nullable UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        previewForDismissingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
    parameters.backgroundColor = [self pp_contextPreviewBackgroundColor];
    parameters.visiblePath =
        [UIBezierPath bezierPathWithRoundedRect:self.bubbleView.bounds
                                   cornerRadius:30.0];
    return [[UITargetedPreview alloc] initWithView:self.bubbleView
                                       parameters:parameters];
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction
       willEndForConfiguration:(UIContextMenuConfiguration *)configuration
                      animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [animator addCompletion:^{
        [self pp_setContextFocusSuppressed:NO];
    }];
}

@end









 
