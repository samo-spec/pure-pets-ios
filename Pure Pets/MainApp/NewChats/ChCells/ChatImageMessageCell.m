//
//  ChatImageMessageCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import "ChatImageMessageCell.h"
#import "PPImageLoaderManager.h"
#import "PPChatsFunc.h"


@interface ChatImageMessageCell ()<PPChatBubbleColorProviding,ChatMessageStatusUpdatable>
@property NSLayoutConstraint *leading;
@property NSLayoutConstraint *trailing;
@property NSLayoutConstraint *widthConstraint;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *statusIcon;
@property (nonatomic, strong) UIView *bottomBlurView;
@property (nonatomic, strong) UIVisualEffectView *mediaActionRail;
@property (nonatomic, strong) UIButton *viewMediaButton;
@property (nonatomic, strong) UIButton *downloadMediaButton;
@property (nonatomic, strong) UIView *replyPreviewView;
@property (nonatomic, strong) UIView *replyAccentView;
@property (nonatomic, strong) UILabel *replyTitleLabel;
@property (nonatomic, strong) UILabel *replySubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *replyPreviewHeightConstraint;

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIImageView *offlinePlaceholderView;

@property (nonatomic, copy) NSString *lastImageURL;
@property (nonatomic, assign) PPChatGroupPosition groupPosition;
@property (nonatomic, assign) BOOL isIncoming;
@property (nonatomic, strong) ChatMessageModel *message;


@end

@implementation ChatImageMessageCell

- (UIView *)messageInteractionView
{
    return self.bubbleView;
}
 
-(UIColor *)pp_bubbleBackgroundColor
{
    // 1️⃣ Image-based color (preferred)
        if (self.message.cachedBubbleColor) {
            return [PPColorUtils blendColor: self.message.cachedBubbleColor
                                  withColor:[PPChatsFunc chatCanvasBackgroundColor]
                                     factor:0.65];
        }

        // 2️⃣ Fallback while loading
        if (self.imageViewMsg.image) {
           // return [UIColor secondarySystemBackgroundColor];
            return [PPColorUtils blendColor: self.message.cachedBubbleColor
                                  withColor:[PPChatsFunc chatCanvasBackgroundColor]
                                     factor:0.65];
        }

        // 3️⃣ Final fallback
    UIColor *base = [UIColor secondarySystemBackgroundColor];
    return [PPColorUtils blendColor:base
                          withColor:[PPChatsFunc chatCanvasBackgroundColor]
                             factor:0.45] ?: [PPChatsFunc chatCanvasBackgroundColor];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL glow = _isIncoming && _groupPosition != PPChatGroupPositionMiddle;
    [PPChatsFunc applyBubbleMask:self.bubbleView isIncoming:self.isIncoming groupPosition:self.groupPosition showGlow:YES];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;

       
        self.bubbleView = [[ChatBubbleView alloc] init];
        self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.bubbleView];

        self.imageViewMsg = [[UIImageView alloc] init];
        self.imageViewMsg.translatesAutoresizingMaskIntoConstraints = NO;
        self.imageViewMsg.clipsToBounds = YES;
        self.imageViewMsg.image = PPImage(@"PawPlaceholder");
        self.imageViewMsg.contentMode = UIViewContentModeScaleAspectFit;
        [self.bubbleView addSubview:self.imageViewMsg];

        // --- Offline Placeholder View ---
        self.offlinePlaceholderView = [[UIImageView alloc] init];
        self.offlinePlaceholderView.translatesAutoresizingMaskIntoConstraints = NO;
        UIImage *offlineImage = [UIImage imageNamed:@"OfflinePlaceholder"];
        if (!offlineImage) {
            offlineImage = [UIImage systemImageNamed:@"wifi.slash"];
        }
        self.offlinePlaceholderView.image = offlineImage;
        self.offlinePlaceholderView.contentMode = UIViewContentModeScaleAspectFit;
        self.offlinePlaceholderView.tintColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.7];
        self.offlinePlaceholderView.hidden = YES;
        self.offlinePlaceholderView.alpha = 0.0;
        [self.imageViewMsg addSubview:self.offlinePlaceholderView];
        
        self.loadingIndicator =
            [[UIActivityIndicatorView alloc]
                initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        self.loadingIndicator.color = UIColor.whiteColor;
        self.loadingIndicator.hidesWhenStopped = YES;
        [self.imageViewMsg addSubview:self.loadingIndicator];

        self.bottomBlurView =  [[UIView alloc] init];
        self.bottomBlurView.translatesAutoresizingMaskIntoConstraints = NO;
        self.bottomBlurView.clipsToBounds = YES;
        self.bottomBlurView.backgroundColor = AppClearClr;
        [self.bubbleView addSubview:self.bottomBlurView];
        
        
        // Time label
        self.timeLabel = [[UILabel alloc] init];
        self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.timeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        self.timeLabel.textColor = UIColor.secondaryLabelColor;
        [self.bottomBlurView addSubview:self.timeLabel];

        // Status icon
        self.statusIcon = [[UIImageView alloc] init];
        self.statusIcon.translatesAutoresizingMaskIntoConstraints = NO;
        self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
        self.statusIcon.tintColor = UIColor.secondaryLabelColor;
        [self.bottomBlurView addSubview:self.statusIcon];

        self.leading =
            [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12];
        self.trailing =
            [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12];
        self.widthConstraint =
        [self.bubbleView.widthAnchor constraintEqualToConstant:YYScreenSize().width * 0.7];
        self.widthConstraint.active = YES;

        [NSLayoutConstraint activateConstraints:@[
            [self.bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPChatBubblePad],
            [self.bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPChatBubblePad],
            self.widthConstraint,
        ]];
        
        [NSLayoutConstraint activateConstraints:@[
            // Image fills bubble except bottom blur
            [self.imageViewMsg.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:0],
            [self.imageViewMsg.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:0],
            [self.imageViewMsg.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-0],
            [self.imageViewMsg.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor constant:-0],
        ]];
        // Offline placeholder centered, 40x40 or 30% of width/height
        [NSLayoutConstraint activateConstraints:@[
            [self.offlinePlaceholderView.centerXAnchor constraintEqualToAnchor:self.imageViewMsg.centerXAnchor],
            [self.offlinePlaceholderView.centerYAnchor constraintEqualToAnchor:self.imageViewMsg.centerYAnchor],
            [self.offlinePlaceholderView.widthAnchor constraintEqualToAnchor:self.imageViewMsg.widthAnchor multiplier:0.3],
            [self.offlinePlaceholderView.heightAnchor constraintEqualToAnchor:self.offlinePlaceholderView.widthAnchor],
        ]];
        
        self.aspectRatioConstraint =
            [self.imageViewMsg.heightAnchor constraintEqualToAnchor:self.imageViewMsg.widthAnchor multiplier:1.0];
        self.aspectRatioConstraint.active = YES;
        
        
        [NSLayoutConstraint activateConstraints:@[
            [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.imageViewMsg.centerXAnchor],
            [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.imageViewMsg.centerYAnchor],
        ]];
        
        [NSLayoutConstraint activateConstraints:@[
            // Bottom blur view (inside bubble)
            [self.bottomBlurView.heightAnchor constraintEqualToConstant:36],
            [self.bottomBlurView.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12],
            [self.bottomBlurView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12],
            [self.bottomBlurView.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor],

            // Bottom row (time + status)
            [self.timeLabel.centerYAnchor constraintEqualToAnchor:self.bottomBlurView.centerYAnchor],
            [self.timeLabel.leadingAnchor constraintEqualToAnchor:self.bottomBlurView.leadingAnchor constant:4],

            [self.statusIcon.centerYAnchor constraintEqualToAnchor:self.timeLabel.centerYAnchor],
            [self.statusIcon.trailingAnchor constraintEqualToAnchor:self.bottomBlurView.trailingAnchor constant:-4],
            [self.statusIcon.widthAnchor constraintEqualToConstant:14],
            [self.statusIcon.heightAnchor constraintEqualToConstant:14],
            
            
        ]];
        
        
        // Retry button (hidden by default)
        self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.retryButton setImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                          forState:UIControlStateNormal];
        self.retryButton.tintColor = UIColor.whiteColor;
        self.retryButton.backgroundColor =
            [[UIColor blackColor] colorWithAlphaComponent:0.45];
        self.retryButton.layer.cornerRadius = 22;
        self.retryButton.hidden = YES;

        [self.retryButton addTarget:self
                             action:@selector(onRetryTapped)
                   forControlEvents:UIControlEventTouchUpInside];

        [self.imageViewMsg addSubview:self.retryButton];

        [NSLayoutConstraint activateConstraints:@[
            [self.retryButton.centerXAnchor constraintEqualToAnchor:self.imageViewMsg.centerXAnchor],
            [self.retryButton.centerYAnchor constraintEqualToAnchor:self.imageViewMsg.centerYAnchor],
            [self.retryButton.widthAnchor constraintEqualToConstant:44],
            [self.retryButton.heightAnchor constraintEqualToConstant:44],
        ]];

        [self setupPremiumMediaActions];
        [self setupReplyPreview];
        
    }
    return self;
}

- (void)setupPremiumMediaActions
{
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    self.mediaActionRail = [[UIVisualEffectView alloc] initWithEffect:effect];
    self.mediaActionRail.translatesAutoresizingMaskIntoConstraints = NO;
    self.mediaActionRail.clipsToBounds = YES;
    self.mediaActionRail.layer.cornerRadius = 20.0;
    self.mediaActionRail.alpha = 0.0;
    if (@available(iOS 13.0, *)) {
        self.mediaActionRail.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.bubbleView addSubview:self.mediaActionRail];

    self.viewMediaButton = [self pp_mediaActionButtonWithSystemName:@"eye.fill"
                                                 accessibilityTitle:kLang(@"chat_media_view")];
    [self.viewMediaButton addTarget:self
                             action:@selector(onViewMediaTapped)
                   forControlEvents:UIControlEventTouchUpInside];

    self.downloadMediaButton = [self pp_mediaActionButtonWithSystemName:@"arrow.down"
                                                      accessibilityTitle:kLang(@"chat_media_download")];
    [self.downloadMediaButton addTarget:self
                                 action:@selector(onDownloadMediaTapped)
                       forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:@[
            self.viewMediaButton,
            self.downloadMediaButton
        ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.spacing = 4.0;
    [self.mediaActionRail.contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.mediaActionRail.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:10.0],
        [self.mediaActionRail.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-10.0],
        [self.mediaActionRail.heightAnchor constraintEqualToConstant:40.0],
        [self.mediaActionRail.widthAnchor constraintEqualToConstant:84.0],

        [stack.leadingAnchor constraintEqualToAnchor:self.mediaActionRail.contentView.leadingAnchor constant:4.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.mediaActionRail.contentView.trailingAnchor constant:-4.0],
        [stack.topAnchor constraintEqualToAnchor:self.mediaActionRail.contentView.topAnchor constant:2.0],
        [stack.bottomAnchor constraintEqualToAnchor:self.mediaActionRail.contentView.bottomAnchor constant:-2.0],

        [self.viewMediaButton.widthAnchor constraintEqualToConstant:36.0],
        [self.viewMediaButton.heightAnchor constraintEqualToConstant:36.0],
        [self.downloadMediaButton.widthAnchor constraintEqualToConstant:36.0],
        [self.downloadMediaButton.heightAnchor constraintEqualToConstant:36.0],
    ]];
}

- (void)setupReplyPreview
{
    self.replyPreviewView = [[UIView alloc] init];
    self.replyPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyPreviewView.hidden = YES;
    self.replyPreviewView.clipsToBounds = YES;
    self.replyPreviewView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.44];
    self.replyPreviewView.layer.cornerRadius = 14.0;
    if (@available(iOS 13.0, *)) {
        self.replyPreviewView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.bubbleView addSubview:self.replyPreviewView];

    self.replyAccentView = [[UIView alloc] init];
    self.replyAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyAccentView.layer.cornerRadius = 1.5;
    [self.replyPreviewView addSubview:self.replyAccentView];

    self.replyTitleLabel = [[UILabel alloc] init];
    self.replyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyTitleLabel.font = [GM boldFontWithSize:11.0];
    self.replyTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.replyTitleLabel.textColor = UIColor.whiteColor;
    self.replyTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.replyTitleLabel.numberOfLines = 1;
    [self.replyPreviewView addSubview:self.replyTitleLabel];

    self.replySubtitleLabel = [[UILabel alloc] init];
    self.replySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.replySubtitleLabel.font = [GM MidFontWithSize:12.0];
    self.replySubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.replySubtitleLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.78];
    self.replySubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.replySubtitleLabel.numberOfLines = 1;
    self.replySubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.replyPreviewView addSubview:self.replySubtitleLabel];

    self.replyPreviewHeightConstraint =
        [self.replyPreviewView.heightAnchor constraintEqualToConstant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.replyPreviewView.topAnchor constraintEqualToAnchor:self.mediaActionRail.bottomAnchor constant:8.0],
        [self.replyPreviewView.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:10.0],
        [self.replyPreviewView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-10.0],
        self.replyPreviewHeightConstraint,

        [self.replyAccentView.leadingAnchor constraintEqualToAnchor:self.replyPreviewView.leadingAnchor constant:9.0],
        [self.replyAccentView.centerYAnchor constraintEqualToAnchor:self.replyPreviewView.centerYAnchor],
        [self.replyAccentView.widthAnchor constraintEqualToConstant:3.0],
        [self.replyAccentView.heightAnchor constraintEqualToConstant:26.0],

        [self.replyTitleLabel.leadingAnchor constraintEqualToAnchor:self.replyAccentView.trailingAnchor constant:8.0],
        [self.replyTitleLabel.trailingAnchor constraintEqualToAnchor:self.replyPreviewView.trailingAnchor constant:-9.0],
        [self.replyTitleLabel.topAnchor constraintEqualToAnchor:self.replyPreviewView.topAnchor constant:6.0],

        [self.replySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.replyTitleLabel.leadingAnchor],
        [self.replySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.replyTitleLabel.trailingAnchor],
        [self.replySubtitleLabel.topAnchor constraintEqualToAnchor:self.replyTitleLabel.bottomAnchor constant:1.0],
    ]];
}

- (UIButton *)pp_mediaActionButtonWithSystemName:(NSString *)systemName
                             accessibilityTitle:(NSString *)accessibilityTitle
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *image = [[UIImage systemImageNamed:systemName] imageByApplyingSymbolConfiguration:config];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.10];
    button.layer.cornerRadius = 18.0;
    button.clipsToBounds = YES;
    button.accessibilityLabel = accessibilityTitle;
    [button addTarget:self action:@selector(pp_mediaActionTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_mediaActionTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    return button;
}

- (void)pp_mediaActionTouchDown:(UIButton *)button
{
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:nil];
}

- (void)pp_mediaActionTouchUp:(UIButton *)button
{
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)onRetryTapped
{
    if (!self.message || !self.message.fileURL.length) return;

    self.didFailLoading = NO;
    self.retryButton.hidden = YES;

    // Re-trigger load safely
    [self configureWithImageURL:self.message.fileURL
                     isIncoming:self.isIncoming
                       maxWidth:self.widthConstraint.constant
                       message:self.message
                 groupPosition:self.groupPosition];
}

- (void)onViewMediaTapped
{
    if ([self.delegate respondsToSelector:@selector(chatImageMessageCellDidTapView:)]) {
        [self.delegate chatImageMessageCellDidTapView:self];
    }
}

- (void)onDownloadMediaTapped
{
    if ([self.delegate respondsToSelector:@selector(chatImageMessageCellDidTapDownload:)]) {
        [self.delegate chatImageMessageCellDidTapDownload:self];
    }
}

- (void)configureWithImageURL:(NSString *)imageURL
                    isIncoming:(BOOL)isIncoming
                      maxWidth:(CGFloat)maxWidth
                      message:(ChatMessageModel *)message
                groupPosition:(PPChatGroupPosition)groupPosition
{
    self.didFailLoading = NO;
    [self hideOverlaysAnimated:NO];

    // Apply stable layout before anything else
    [self applyStableLayoutForMessage:message maxWidth:maxWidth];
    [self applyAspectRatioFromMessage:message];

    // Instant BlurHash placeholder (NO waiting)
    if (message.blurHash.length > 0 && !message.localImage) {
        UIImage *blur =
        [PPBlurHashBridge imageFrom:message.blurHash
                           syncSize:CGSizeMake(32, 32)
                              punch:1.0];
        if (blur) {
            self.imageViewMsg.image = blur;
        }
    }

    self.isIncoming = isIncoming;
    self.message = message;
    self.groupPosition = groupPosition;
    self.bubbleView.isIncoming = isIncoming;
    self.bubbleView.groupPosition = groupPosition;
    self.boundMessageID = message.ID;
    [self updateMediaActionsForMessage:message animated:YES];

    BOOL usesTrailing = [PPChatsFunc bubbleUsesTrailingAlignmentForIncoming:isIncoming];
    self.leading.active = !usesTrailing;
    self.trailing.active = usesTrailing;

    // 1️⃣ LOCAL IMAGE (outgoing, uploading)
    if (message.localImage) {
        self.imageViewMsg.image = message.localImage;
        //[self hidePlaceholder];
    }
    
    
    

    if (message.fileURL.length > 0) {
        NSString *currentMessageID = message.ID;
        NSString *newURL = message.fileURL;

        // Prevent reuse corruption
        if (![self.boundMessageID isEqualToString:currentMessageID]) {
            return;
        }

        // Only reload image if URL changed
        if (![self.lastImageURL isEqualToString:newURL]) {
            self.lastImageURL = newURL;
            [self showSpinnerAnimated:NO];
            __weak typeof(self) weakSelf = self;
            [PPImageLoaderManager.shared fetchImageWithURL:newURL
                                               completion:^(UIImage * _Nullable image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self) return;
                    // Reuse guard
                    if (![self.boundMessageID isEqualToString:currentMessageID]) {
                        return;
                    }
                    [self hideOverlaysAnimated:YES];
                    // ❌ FAILED
                    if (!image) {
                        self.didFailLoading = YES;
                        [self showRetryAnimated:YES];
                        [self showOfflinePlaceholderAnimated:YES];
                        return;
                    }
                    // ✅ SUCCESS
                    self.didFailLoading = NO;
                    [self hideOverlaysAnimated:YES];
                    [self hideOfflinePlaceholderAnimated:YES];

                    if (image.size.width > 0 && image.size.height > 0) {
                        CGFloat ratio = image.size.height / image.size.width;
                        BOOL shouldCorrectRatio =
                            (message.mediaAspectRatio <= 0) ||
                            fabs(message.mediaAspectRatio - ratio) > 0.35;
                        if (!shouldCorrectRatio) {
                            ratio = message.mediaAspectRatio;
                        }
                        ratio = MAX(0.35, MIN(ratio, 3.2));
                        message.mediaWidth = image.size.width;
                        message.mediaHeight = image.size.height;
                        message.mediaAspectRatio = ratio;
                        [self lockAspectRatio:ratio];

                        UITableView *table = [self enclosingTableView];
                        if (table) {
                            [UIView performWithoutAnimation:^{
                                [table beginUpdates];
                                [table endUpdates];
                            }];
                        }
                    }

                    [UIView transitionWithView:self.imageViewMsg
                                      duration:0.25
                                       options:UIViewAnimationOptionTransitionCrossDissolve
                                    animations:^{
                        self.imageViewMsg.image = image;
                    } completion:nil];
                    // Cache bubble color ONCE
                    if (!message.cachedBubbleColor) {
                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                            UIColor *avg = [PPColorUtils pp_averageColorFromImage:image];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                message.cachedBubbleColor = avg;
                            });
                        });
                    }
                });
            }];
        }
    }

    self.timeLabel.text = [self formattedTime:message.timestamp];
    self.bubbleView.backgroundColor = [PPChatsFunc bubbleSurfaceColorForIncoming:isIncoming];
    self.timeLabel.textColor = [PPChatsFunc bubbleSecondaryContentColorForIncoming:isIncoming];

    [PPChatsFunc applyStatusForMessage:message
                          toImageView:self.statusIcon
                           isIncoming:isIncoming
                             animated:NO];
    [self setNeedsLayout];
}

- (void)setReplyPreviewTitle:(nullable NSString *)title
                    subtitle:(nullable NSString *)subtitle
                  isIncoming:(BOOL)isIncoming
{
    if (title.length == 0 && subtitle.length == 0) {
        [self clearReplyPreview];
        return;
    }

    self.replyPreviewView.hidden = NO;
    self.replyPreviewHeightConstraint.constant =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory)
            ? 56.0
            : 44.0;
    self.replyTitleLabel.text = title.length > 0 ? title : kLang(@"chat_replying");
    self.replySubtitleLabel.text = subtitle.length > 0 ? subtitle : kLang(@"Message");
    UIColor *foreground = [PPChatsFunc bubblePrimaryContentColorForIncoming:isIncoming];
    self.replyAccentView.backgroundColor =
        [PPChatsFunc bubbleInteractiveAccentColorForIncoming:isIncoming];
    self.replyPreviewView.backgroundColor =
        [PPChatsFunc bubbleReplySurfaceColorForIncoming:isIncoming];
    self.replyPreviewView.layer.borderColor =
        [PPChatsFunc bubbleStrokeColorForIncoming:isIncoming].CGColor;
    self.replyTitleLabel.textColor = foreground;
    self.replySubtitleLabel.textColor = [foreground colorWithAlphaComponent:0.66];
}

- (void)clearReplyPreview
{
    self.replyPreviewHeightConstraint.constant = 0.0;
    self.replyTitleLabel.text = nil;
    self.replySubtitleLabel.text = nil;
    self.replyPreviewView.hidden = YES;
}

- (void)updateMediaActionsForMessage:(ChatMessageModel *)message animated:(BOOL)animated
{
    BOOL canView = (message.localImage != nil || message.fileURL.length > 0 || self.imageViewMsg.image != nil);
    BOOL canDownload = (message.fileURL.length > 0 || message.localImage != nil || self.imageViewMsg.image != nil);
    self.viewMediaButton.enabled = canView;
    self.downloadMediaButton.enabled = canDownload && !message.isUploading;
    self.viewMediaButton.alpha = canView ? 1.0 : 0.45;
    self.downloadMediaButton.alpha = self.downloadMediaButton.enabled ? 1.0 : 0.45;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    void (^changes)(void) = ^{
        self.mediaActionRail.alpha = canView ? 1.0 : 0.0;
        self.mediaActionRail.transform = canView
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(0.94, 0.94);
    };

    if (!animated || reduceMotion || self.mediaActionRail.alpha > 0.95) {
        changes();
        return;
    }

    self.mediaActionRail.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.22
                          delay:0.02
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

/// Update only the status-related UI (status icon/tint) for the given message, if currently bound.
- (void)updateMessageStatus:(ChatMessageModel *)message
{
    // Only update if bound to this message
    if (!self.boundMessageID || ![self.boundMessageID isEqualToString:message.ID]) {
        return;
    }
    self.message = message;
    [PPChatsFunc applyStatusForMessage:message
                          toImageView:self.statusIcon
                           isIncoming:self.isIncoming
                             animated:YES];
    // Do not touch thumbnail, loading, play state, or applyVisualState.
}


#pragma mark - Helpers

- (NSString *)formattedTime:(NSDate *)date
{
    static NSDateFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"HH:mm";
    });
    return [fmt stringFromDate:date];
}

- (UIImage *)statusImageForMessage:(ChatMessageModel *)msg
{
    if (msg.isUploading) {
        return [UIImage systemImageNamed:@"arrow.up.circle"];
    }

    switch (msg.status) {
        case ChatMessageStatusSent:
            return [UIImage systemImageNamed:@"checkmark"];
        case ChatMessageStatusDelivered:
            return [UIImage systemImageNamed:@"checkmark.circle"];
        case ChatMessageStatusRead:
            return [UIImage systemImageNamed:@"checkmark.circle.fill"];
        default:
            return nil;
    }
}


// MARK: - Animated Overlay Helpers

- (void)showRetryAnimated:(BOOL)animated {
    if (!self.retryButton.hidden && self.retryButton.alpha == 1.0) return;
    self.retryButton.hidden = NO;
    if (animated) {
        self.retryButton.alpha = 0.0;
        [UIView animateWithDuration:0.22 animations:^{
            self.retryButton.alpha = 1.0;
        }];
    } else {
        self.retryButton.alpha = 1.0;
    }
    [self hideSpinnerAnimated:animated];
}

- (void)showSpinnerAnimated:(BOOL)animated {
    if (!self.loadingIndicator.hidden && self.loadingIndicator.alpha == 1.0 && self.loadingIndicator.isAnimating) return;
    self.loadingIndicator.hidden = NO;
    if (animated) {
        self.loadingIndicator.alpha = 0.0;
        [self.loadingIndicator startAnimating];
        [UIView animateWithDuration:0.22 animations:^{
            self.loadingIndicator.alpha = 1.0;
        }];
    } else {
        self.loadingIndicator.alpha = 1.0;
        [self.loadingIndicator startAnimating];
    }
    [self hideRetryAnimated:animated];
}

- (void)hideSpinnerAnimated:(BOOL)animated {
    if (self.loadingIndicator.hidden || self.loadingIndicator.alpha == 0.0) {
        [self.loadingIndicator stopAnimating];
        self.loadingIndicator.hidden = YES;
        self.loadingIndicator.alpha = 0.0;
        return;
    }
    if (animated) {
        [UIView animateWithDuration:0.18 animations:^{
            self.loadingIndicator.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.loadingIndicator stopAnimating];
            self.loadingIndicator.hidden = YES;
        }];
    } else {
        self.loadingIndicator.alpha = 0.0;
        [self.loadingIndicator stopAnimating];
        self.loadingIndicator.hidden = YES;
    }
}

- (void)hideRetryAnimated:(BOOL)animated {
    if (self.retryButton.hidden || self.retryButton.alpha == 0.0) {
        self.retryButton.hidden = YES;
        self.retryButton.alpha = 0.0;
        return;
    }
    if (animated) {
        [UIView animateWithDuration:0.18 animations:^{
            self.retryButton.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.retryButton.hidden = YES;
        }];
    } else {
        self.retryButton.alpha = 0.0;
        self.retryButton.hidden = YES;
    }
}

- (void)hideOverlaysAnimated:(BOOL)animated {
    [self hideRetryAnimated:animated];
    [self hideSpinnerAnimated:animated];
}

- (void)showOfflinePlaceholderAnimated:(BOOL)animated {
    if (!self.offlinePlaceholderView.hidden && self.offlinePlaceholderView.alpha == 1.0) return;
    self.offlinePlaceholderView.hidden = NO;
    if (animated) {
        self.offlinePlaceholderView.alpha = 0.0;
        [UIView animateWithDuration:0.2 animations:^{
            self.offlinePlaceholderView.alpha = 1.0;
        }];
    } else {
        self.offlinePlaceholderView.alpha = 1.0;
    }
}

- (void)hideOfflinePlaceholderAnimated:(BOOL)animated {
    if (self.offlinePlaceholderView.hidden || self.offlinePlaceholderView.alpha == 0.0) {
        self.offlinePlaceholderView.hidden = YES;
        self.offlinePlaceholderView.alpha = 0.0;
        return;
    }
    if (animated) {
        [UIView animateWithDuration:0.15 animations:^{
            self.offlinePlaceholderView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.offlinePlaceholderView.hidden = YES;
        }];
    } else {
        self.offlinePlaceholderView.alpha = 0.0;
        self.offlinePlaceholderView.hidden = YES;
    }
}

- (void)updateUploadingState:(ChatMessageModel *)msg
{
    if (msg.isUploading) {
        [self showSpinnerAnimated:YES];
    } else {
        [self hideOverlaysAnimated:YES];
    }
    [self updateMediaActionsForMessage:msg animated:YES];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.accessibilityCustomActions = nil;
    self.bubbleView.accessibilityCustomActions = nil;
    
    self.imageViewMsg.image = nil;
    self.boundMessageID = nil;
    self.lastImageURL = nil;
    self.didFailLoading = NO;
    
    // Reset overlays and placeholder
    [self hideOverlaysAnimated:NO];
    [self hideOfflinePlaceholderAnimated:NO];
    self.mediaActionRail.alpha = 0.0;
    self.mediaActionRail.transform = CGAffineTransformMakeScale(0.94, 0.94);
    self.viewMediaButton.transform = CGAffineTransformIdentity;
    self.downloadMediaButton.transform = CGAffineTransformIdentity;
    [self clearReplyPreview];
    
    
}

// MARK: - Stable Layout Helper

- (void)applyStableLayoutForMessage:(ChatMessageModel *)message maxWidth:(CGFloat)maxWidth {
    CGFloat maxBubbleWidth = YYScreenSize().width * 0.72;
    CGFloat requestedWidth = maxWidth > 0 ? maxWidth : maxBubbleWidth;
    CGFloat targetWidth = MIN(requestedWidth, maxBubbleWidth);
    targetWidth = MAX(targetWidth, 140.0);
    self.widthConstraint.constant = targetWidth;
}


#pragma mark - Aspect Ratio Lock (CRITICAL)

- (void)applyAspectRatioFromMessage:(ChatMessageModel *)message
{
    if (message.mediaAspectRatio <= 0 &&
        message.mediaWidth > 0 &&
        message.mediaHeight > 0) {
        message.mediaAspectRatio = message.mediaHeight / message.mediaWidth;
    }

    if (message.mediaAspectRatio > 0) {
        [self lockAspectRatio:message.mediaAspectRatio];
        return;
    }

    UIImage *source =
        message.localImage ?: self.imageViewMsg.image;

    if (!source || source.size.width <= 0 || source.size.height <= 0) {
        return;
    }

    CGFloat ratio = source.size.height / source.size.width;

    // Clamp to sane chat ranges (prevents ultra tall / ultra wide jumps)
    ratio = MAX(0.35, MIN(ratio, 3.2));

    message.mediaAspectRatio = ratio;
    [self lockAspectRatio:ratio];
}

- (UITableView *)enclosingTableView
{
    UIView *v = self.superview;
    while (v && ![v isKindOfClass:UITableView.class]) {
        v = v.superview;
    }
    return (UITableView *)v;
}

- (void)lockAspectRatio:(CGFloat)ratio
{
    if (!ratio) return;

    CGFloat multiplier = ratio;

    // Safety clamp (prevents AutoLayout explosions)
    if (multiplier < 0.35 || multiplier > 3.2) {
        multiplier = 1.0;
    }

    if (self.aspectRatioConstraint) {
        self.aspectRatioConstraint.active = NO;
    }

    self.aspectRatioConstraint =
        [self.imageViewMsg.heightAnchor
            constraintEqualToAnchor:self.imageViewMsg.widthAnchor
                         multiplier:multiplier];

    self.aspectRatioConstraint.priority = UILayoutPriorityRequired;
    self.aspectRatioConstraint.active = YES;
}
@end
