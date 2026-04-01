//
//  ChatBubbleView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//  Refactored to use Auto Layout
//

#import "ChatBubbleView.h"
#import <QuartzCore/QuartzCore.h>

@interface ChatBubbleView ()

@property (nonatomic) NSLayoutConstraint *messageCenterY;
@property (nonatomic) NSLayoutConstraint *timeCenterY;
@property (nonatomic) NSLayoutConstraint *statusCenterY;
@property (nonatomic, strong, readwrite) UILabel *messageLabel;
@property (nonatomic, strong, readwrite) UILabel *timeLabel;
@property (nonatomic, strong, readwrite) UIImageView *statusImageView;
@property (nonatomic) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, readwrite) BOOL isIncoming;
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleTrailingConstraint;

@property (nonatomic) NSLayoutConstraint *messageTop;
@property (nonatomic) NSLayoutConstraint *messageBottom;

@property (nonatomic, strong) NSLayoutConstraint *minHeightConstraint;

@property (nonatomic, strong) UILayoutGuide *contentGuide;

// Added properties for constraint sets
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *singleLineConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *multiLineConstraints;

@end

@implementation ChatBubbleView

-(UIImageView *)getStatusImageView
{
    return self.statusImageView;
}
 
#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

/// Shared initialization
- (void)commonInit {
    
    _contentType = ChatBubbleContentTypeText;
  
    _maxBubbleWidth = YYScreenSize().width * 0.8; // default max width — can be adjusted from outside
    [self setupSubviews];
    [self setupConstraints];
    [self setupAccessibilityAndFonts];
   
    
    self.translatesAutoresizingMaskIntoConstraints = NO;
    //self.layer.cornerRadius = 20.0;
    //self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = NO;
    
    
     
}

// Removed obsolete single-line priority logic method
/*
- (void)updateSingleLineLayoutIfNeeded
{
    BOOL singleLine =
        self.messageLabel.intrinsicContentSize.height
        <= self.messageLabel.font.lineHeight + 1;

    self.messageCenterY.priority =
        singleLine ? UILayoutPriorityRequired : UILayoutPriorityDefaultLow;

    self.messageTop.priority =
        singleLine ? UILayoutPriorityDefaultLow : UILayoutPriorityRequired;

    self.messageBottom.priority =
        singleLine ? UILayoutPriorityDefaultLow : UILayoutPriorityRequired;
}
*/
#pragma mark - Subviews

- (void)setupSubviews {
    _messageLabel = [[UILabel alloc] init];
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _messageLabel.numberOfLines = 0;
    _messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _messageLabel.font = [GM fontWithSize:16];
    _messageLabel.adjustsFontForContentSizeCategory = YES;
    [self addSubview:_messageLabel];

    _timeLabel = [[UILabel alloc] init];
    _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _timeLabel.font = [GM fontWithSize:11];
    _timeLabel.textColor = [UIColor lightGrayColor];
    _timeLabel.adjustsFontForContentSizeCategory = YES;
    _timeLabel.textAlignment = NSTextAlignmentLeft;
    [self addSubview:_timeLabel];

    _statusImageView = [[UIImageView alloc] init];
    _statusImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _statusImageView.contentMode = UIViewContentModeScaleAspectFit;
    _statusImageView.tintColor = [UIColor whiteColor];
    _statusImageView.clipsToBounds = YES;
    [self addSubview:_statusImageView];
}

- (void)setupAccessibilityAndFonts {
    _messageLabel.isAccessibilityElement = YES;
    _timeLabel.isAccessibilityElement = YES;
    _statusImageView.isAccessibilityElement = YES;
    _messageLabel.accessibilityTraits = UIAccessibilityTraitStaticText;
}

#pragma mark - Constraints

// 2) SETUP contentGuide in setupConstraints
- (void)setupConstraints {
    const CGFloat padding = 8.0;
    const CGFloat padding16 = 16.0;
    //const CGFloat timeTopSpacing = 6.0;
    const CGFloat statusSize = 14.0;
    //const CGFloat spacingBetweenTimeAndStatus = 6.0;

    // 1) ADD a contentLayoutGuide
    self.contentGuide = [[UILayoutGuide alloc] init];
    [self addLayoutGuide:self.contentGuide];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentGuide.topAnchor constraintEqualToAnchor:self.topAnchor constant:2],
        [self.contentGuide.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
        [self.contentGuide.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.contentGuide.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
    ]];

    self.minHeightConstraint =
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:48.0];
    self.minHeightConstraint.active = YES;

    // 3) CONSTRAIN messageLabel INSIDE contentGuide (CRITICAL)
    self.messageTop =
        [self.messageLabel.topAnchor constraintEqualToAnchor:self.contentGuide.topAnchor];
    self.messageBottom =
        [self.messageLabel.bottomAnchor constraintEqualToAnchor:self.contentGuide.bottomAnchor];

    [NSLayoutConstraint activateConstraints:@[
        self.messageTop,
        self.messageBottom,
        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.contentGuide.leadingAnchor],
       
    ]];

    // Time label: below message label (unchanged)
    [NSLayoutConstraint activateConstraints:@[
         [self.timeLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-padding]
    ]];

    // Status icon: vertically aligned with time label baseline (trailing inside bubble)
    [NSLayoutConstraint activateConstraints:@[
        [self.statusImageView.centerYAnchor constraintEqualToAnchor:self.timeLabel.centerYAnchor],
        [self.statusImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding16],
        [self.statusImageView.widthAnchor constraintEqualToConstant:statusSize],
        [self.statusImageView.heightAnchor constraintEqualToConstant:statusSize],
        // Removed conflicting trailing constraints:
        // [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.timeLabel.leadingAnchor],
        // [self.timeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusImageView.leadingAnchor constant:-spacingBetweenTimeAndStatus]
    ]];

    self.messageCenterY =
        [self.messageLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor];
    self.messageCenterY.priority = UILayoutPriorityDefaultLow;

    self.timeCenterY =
        [self.timeLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor];
    self.timeCenterY.priority = UILayoutPriorityDefaultLow;

    self.statusCenterY =
        [self.statusImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor];
    self.statusCenterY.priority = UILayoutPriorityDefaultLow;

    [NSLayoutConstraint activateConstraints:@[
        self.messageCenterY,
        self.timeCenterY,
        self.statusCenterY
    ]];

    // Max width constraint for the bubble view
    self.maxWidthConstraint =
        [self.widthAnchor constraintLessThanOrEqualToConstant:self.maxBubbleWidth];
    self.maxWidthConstraint.priority = UILayoutPriorityRequired;
    self.maxWidthConstraint.active = YES;
   
    // --- Single-line layout (inline text + time + status)
    self.singleLineConstraints = @[
        [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.timeLabel.leadingAnchor constant:-6],
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.statusImageView.leadingAnchor constant:-4],
        [self.statusImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],

        [self.messageLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.timeLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.statusImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ];

    // --- Multi-line layout (text block + time/status at bottom trailing)
    self.multiLineConstraints = @[
        [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.contentGuide.trailingAnchor],

        // 🔧 FIX: prevent empty leading space
        [self.timeLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentGuide.leadingAnchor],

        [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.statusImageView.leadingAnchor constant:-4],
        [self.timeLabel.bottomAnchor constraintEqualToAnchor:self.contentGuide.bottomAnchor],

        [self.statusImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.statusImageView.bottomAnchor constraintEqualToAnchor:self.contentGuide.bottomAnchor],
    ];
}

- (void)setMaxBubbleWidth:(CGFloat)maxBubbleWidth {
    _maxBubbleWidth = maxBubbleWidth;
    if (self.maxWidthConstraint) {
        self.maxWidthConstraint.constant = maxBubbleWidth;
    } else {
        self.maxWidthConstraint =
            [self.widthAnchor constraintLessThanOrEqualToConstant:maxBubbleWidth];
        self.maxWidthConstraint.priority = UILayoutPriorityRequired;
        self.maxWidthConstraint.active = YES;
    }
}

#pragma mark - Gradient

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

   
}

- (void)updateLayoutForSingleLine:(BOOL)isSingleLine
{
    if (self.singleLineConstraints.count == 0 ||
        self.multiLineConstraints.count == 0) {
        return;
    }

    [NSLayoutConstraint deactivateConstraints:self.singleLineConstraints];
    [NSLayoutConstraint deactivateConstraints:self.multiLineConstraints];

    if (isSingleLine) {
        [NSLayoutConstraint activateConstraints:self.singleLineConstraints];
    } else {
        [NSLayoutConstraint activateConstraints:self.multiLineConstraints];
    }
}

- (void)applyIncomingShadowIfNeeded {
    if (!self.isIncoming) {
        self.layer.shadowOpacity = 0;
        return;
    }

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.06;      // micro elevation
    self.layer.shadowRadius = 6.0;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.masksToBounds = NO;
}
#pragma mark - API

- (void)setMessageText:(NSString *)message
                  time:(NSDate *)date
           isIncoming:(BOOL)isIncoming
               status:(ChatMessageStatus)status 
             
{
    if (self.contentType == ChatBubbleContentTypeAudio) {
        return;
    }
    
    self.contentType = ChatBubbleContentTypeText;
    self.isIncoming = isIncoming;
    // Texts
    self.messageLabel.text = message ?: @"";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"h:mm a";
    self.timeLabel.text = [formatter stringFromDate:date ?: [NSDate date]];
    
    
    // Removed call to updateSingleLineLayoutIfNeeded
    [self applyIncomingShadowIfNeeded];
    
    
    self.contentType = ChatBubbleContentTypeText;
    self.isIncoming = isIncoming;

    
    
    
    BOOL emojiOnly = [self isEmojiOnlyText:message];
    if (emojiOnly) {
        self.messageLabel.font = [GM fontWithSize:64];
        self.messageLabel.textAlignment = NSTextAlignmentCenter;

        self.timeLabel.hidden = YES;
        self.statusImageView.hidden = YES;

        self.backgroundColor = UIColor.clearColor;
        self.layer.shadowOpacity = 0;

       // [Styling applyCornerMaskToView:self tl:0 tr:0 bl:0 br:0];

        [self setNeedsLayout];
        [self layoutIfNeeded];
        return;
    }
    
    self.messageLabel.font = [GM fontWithSize:16];
    self.messageLabel.textAlignment = NSTextAlignmentNatural;
    self.timeLabel.hidden = NO;
    //self.layer.shadowOpacity = 0.06;
    

    
    self.backgroundColor =  !isIncoming ? PPChatBubbleMineColor : PPChatBubbleSomeoneColor;
    self.timeLabel.textColor = isIncoming ? PPChatTimeSomeoneColor : PPChatTimeMineColor;
    
    // Colors / appearance
    if (isIncoming) {
        self.messageLabel.textColor = GM.PrimaryTextColor ?: [UIColor whiteColor];
         self.statusImageView.hidden = YES;
     } else {
        self.messageLabel.textColor =  AppForgroundColr ?: [UIColor labelColor];
         self.statusImageView.hidden = NO;
        
        UIImage *icon = nil;
        UIColor *tint = [UIColor grayColor];
        switch (status) {
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
                tint =  AppForgroundColr;
                break;
            default:
                icon = nil;
                break;
        }
        self.statusImageView.image = icon;
        self.statusImageView.tintColor = tint;
        self.statusImageView.hidden = (icon == nil);
     }
    
    BOOL singleLine =
        self.messageLabel.intrinsicContentSize.height
        <= self.messageLabel.font.lineHeight + 1;

    [self updateLayoutForSingleLine:singleLine];
    // 5️⃣ Final layout pass
    //[self updateSingleLineLayoutIfNeeded]; // removed call
    [self setNeedsLayout];
}

- (BOOL)isSingleLineMessage {
    if (self.messageLabel.text.length == 0) return YES;

    CGFloat availableWidth = CGRectGetWidth(self.messageLabel.bounds);
    if (availableWidth <= 0) return YES;

    CGSize size =
    [self.messageLabel.text boundingRectWithSize:CGSizeMake(availableWidth, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{ NSFontAttributeName : self.messageLabel.font }
                                         context:nil].size;

    return size.height <= ceil(self.messageLabel.font.lineHeight + 1);
}

- (BOOL)isEmojiOnlyText:(NSString *)text
{
    if (text.length == 0) return NO;

    __block BOOL hasEmoji = NO;
    __block BOOL hasNonEmoji = NO;

    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange range, NSRange enclosingRange, BOOL *stop) {

        if (substring.length == 0) return;

        const unichar hs = [substring characterAtIndex:0];
        BOOL isEmoji =
            (hs >= 0xD800 && hs <= 0xDBFF) || // surrogate
            (hs >= 0x2100 && hs <= 0x27BF);   // symbols

        if (isEmoji) {
            hasEmoji = YES;
        } else {
            NSString *trimmed =
                [substring stringByTrimmingCharactersInSet:
                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (trimmed.length > 0) {
                hasNonEmoji = YES;
            }
        }
    }];

    return hasEmoji && !hasNonEmoji;
}
@end
