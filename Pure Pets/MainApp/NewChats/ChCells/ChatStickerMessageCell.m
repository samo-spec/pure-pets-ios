//
//  ChatStickerMessageCell.m
//  Pure Pets
//
//  Created by Codex on 17/07/2026.
//

#import "ChatStickerMessageCell.h"
#import "ChatMessageModel.h"
#import "PPChatsFunc.h"
#import "Pure_Pets-Swift.h"

static const CGFloat PPChatStickerArtworkSize = 144.0;
static const CGFloat PPChatStickerVerticalInset = 8.0;
static const CGFloat PPChatStickerHorizontalInset = 18.0;

@interface ChatStickerMessageCell () <ChatMessageStatusUpdatable>
@property (nonatomic, strong) UIImageView *stickerImageView;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, copy) NSString *boundMessageID;
@end

@implementation ChatStickerMessageCell

+ (CGFloat)preferredCellHeight
{
    return PPChatStickerArtworkSize + (PPChatStickerVerticalInset * 2.0);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;

        self.stickerImageView = [[UIImageView alloc] init];
        self.stickerImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.stickerImageView.backgroundColor = UIColor.clearColor;
        self.stickerImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.stickerImageView.clipsToBounds = NO;
        self.stickerImageView.layer.masksToBounds = NO;
        self.stickerImageView.layer.shadowColor = UIColor.blackColor.CGColor;
        self.stickerImageView.layer.shadowOpacity = 0.18;
        self.stickerImageView.layer.shadowRadius = 18.0;
        self.stickerImageView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        self.stickerImageView.layer.shouldRasterize = YES;
        self.stickerImageView.layer.rasterizationScale = UIScreen.mainScreen.scale;
        self.stickerImageView.isAccessibilityElement = YES;
        self.stickerImageView.accessibilityTraits = UIAccessibilityTraitImage;
        self.stickerImageView.accessibilityLabel = kLang(@"chat_sticker_message");
        [self.contentView addSubview:self.stickerImageView];

        self.leadingConstraint =
            [self.stickerImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor
                                                                 constant:PPChatStickerHorizontalInset];
        self.trailingConstraint =
            [self.stickerImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor
                                                                  constant:-PPChatStickerHorizontalInset];

        [NSLayoutConstraint activateConstraints:@[
            [self.stickerImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPChatStickerVerticalInset],
            [self.stickerImageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPChatStickerVerticalInset],
            [self.stickerImageView.widthAnchor constraintEqualToConstant:PPChatStickerArtworkSize],
            [self.stickerImageView.heightAnchor constraintEqualToConstant:PPChatStickerArtworkSize],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.boundMessageID = nil;
    self.stickerImageView.image = nil;
    self.stickerImageView.alpha = 1.0;
    self.stickerImageView.transform = CGAffineTransformIdentity;
}

- (UIView *)messageInteractionView
{
    return self.stickerImageView;
}

- (void)configureWithMessage:(ChatMessageModel *)message
                  isIncoming:(BOOL)isIncoming
{
    self.boundMessageID = message.ID ?: @"";
    self.stickerImageView.image = nil;
    self.stickerImageView.accessibilityLabel = kLang(@"chat_sticker_message");

    BOOL usesTrailing = [PPChatsFunc bubbleUsesTrailingAlignmentForIncoming:isIncoming];
    self.leadingConstraint.active = NO;
    self.trailingConstraint.active = NO;
    self.leadingConstraint.active = !usesTrailing;
    self.trailingConstraint.active = usesTrailing;

    NSString *storagePath = message.stickerStoragePath ?: @"";
    NSString *downloadURL = message.fileURL ?: @"";
    if (downloadURL.length == 0 && storagePath.length == 0) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[PPStickerStore shared] imageForStickerWithStoragePath:storagePath
                                          downloadURLString:downloadURL
                                                 completion:^(UIImage * _Nullable image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (![self.boundMessageID isEqualToString:(message.ID ?: @"")]) return;
        if (!image) return;

        BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
        if (reduceMotion) {
            self.stickerImageView.image = image;
            self.stickerImageView.alpha = 1.0;
            return;
        }

        self.stickerImageView.alpha = 0.0;
        self.stickerImageView.transform = CGAffineTransformMakeScale(0.985, 0.985);
        self.stickerImageView.image = image;
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.stickerImageView.alpha = 1.0;
            self.stickerImageView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)updateMessageStatus:(ChatMessageModel *)message
{
    // Sticker messages intentionally render only the transparent sticker art.
}

@end
