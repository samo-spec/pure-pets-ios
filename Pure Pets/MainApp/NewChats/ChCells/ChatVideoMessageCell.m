//
//  ChatVideoMessageCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import "ChatVideoMessageCell.h"
#import "PPImageLoaderManager.h"
#import "MDRadialProgressView.h"
#import "MDRadialProgressTheme.h"
#import "PPChatsFunc.h"
#import "ChatBubbleView.h"

@interface ChatVideoMessageCell ()<ChatMessageStatusUpdatable>
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) ChatMediaBubbleView *bubbleView;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIVisualEffectView *glassOverlay;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIVisualEffectView *mediaActionRail;
@property (nonatomic, strong) UIButton *viewMediaButton;
@property (nonatomic, strong) UIButton *downloadMediaButton;
@property (nonatomic, strong) UIView *replyPreviewView;
@property (nonatomic, strong) UIView *replyAccentView;
@property (nonatomic, strong) UILabel *replyTitleLabel;
@property (nonatomic, strong) UILabel *replySubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *replyPreviewHeightConstraint;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *statusIcon;
@property (nonatomic, strong) UIView *bottomBlurView;
@property (nonatomic, assign) BOOL isIncoming;
@property (nonatomic, strong, nullable) ChatMessageModel *message;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, assign) PPChatGroupPosition groupPosition;
@property (nonatomic, assign) BOOL loadingVideo;
@property (nonatomic, assign) BOOL playingVideo;
 @end

@implementation ChatVideoMessageCell

- (UIView *)messageInteractionView
{
    return self.bubbleView;
}

#pragma mark - Visual State

- (void)layoutSubviews {
    self.bubbleView.isIncoming = self.isIncoming;
    self.bubbleView.groupPosition = self.groupPosition;
    [super layoutSubviews];
}

/*
 BubbleLayer *bbLayer = [[BubbleLayer alloc]initWithSize:self.bubbleView.bounds.size];
 bbLayer.cornerRadius = 22;
 bbLayer.arrowDirection = _isIncoming ? ArrowDirectionLeft : ArrowDirectionRight;
 bbLayer.arrowHeight = 6; //Height (length) of the arrow
 bbLayer.arrowWidth =15; // The width of the arrow
 bbLayer.arrowPosition = 1.0; // relative position of arrow
 bbLayer.arrowRadius = 3; // The fillet radius at the arrow
 [self.bubbleView.layer setMask:[bbLayer layer]];
 */
- (void)applyVisualState {
    NSLog(@"🎬 [VideoCell] id=%@ loading=%d playing=%d",
          self.boundMessageID,
          self.loadingVideo,
          self.playingVideo);
    // Centralized visual state: only read self.loading, self.playing
    BOOL isLoading = self.loadingVideo;
    BOOL isPlaying = self.playingVideo;

    self.playButton.userInteractionEnabled = !isLoading;
    self.playButton.imageView.alpha = isLoading ? 0.0 : 1.0;

    if (isPlaying) {
        UIImage *img = [UIImage systemImageNamed:@"pause.fill"];
        [self.playButton setImage:img forState:UIControlStateNormal];
    } else {
        UIImage *img = [UIImage systemImageNamed:@"play.fill"];
        [self.playButton setImage:img forState:UIControlStateNormal];
    }

    if (isLoading) {
        [self.loadingIndicator startAnimating];
    } else {
        [self.loadingIndicator stopAnimating];
    }
}

#pragma mark - Init/UI

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    self.bubbleView = [[ChatMediaBubbleView alloc] init];
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bubbleView.layer.masksToBounds = YES;
    [self.contentView addSubview:self.bubbleView];

    self.leadingConstraint = [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12];
    self.trailingConstraint = [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12];
    self.maxWidthConstraint = [self.bubbleView.widthAnchor constraintEqualToConstant:YYScreenSize().width];

    [NSLayoutConstraint activateConstraints:@[
        [self.bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPChatBubblePad],
        [self.bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPChatBubblePad],
        self.maxWidthConstraint
    ]];

    self.thumbnailView = [[UIImageView alloc] init];
    self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    self.thumbnailView.clipsToBounds = YES;
    self.thumbnailView.backgroundColor = UIColor.clearColor;
    self.thumbnailView.layer.minificationFilter = kCAFilterTrilinear;
    self.thumbnailView.layer.magnificationFilter = kCAFilterTrilinear;
    [self.bubbleView addSubview:self.thumbnailView];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    self.glassOverlay = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.glassOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.glassOverlay.alpha = 0.35;
    [self.bubbleView addSubview:self.glassOverlay];

    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    self.playButton.tintColor = UIColor.whiteColor;
    self.playButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    self.playButton.layer.cornerRadius = 26;
    self.playButton.clipsToBounds = YES;
    [self.playButton addTarget:self action:@selector(onPlay) forControlEvents:UIControlEventTouchUpInside];
    [self.bubbleView addSubview:self.playButton];

    MDRadialProgressTheme *theme = [MDRadialProgressTheme standardTheme];
    theme.sliceDividerHidden = YES;
    theme.thickness = 4;
    theme.completedColor = [PPChatsFunc chatNeutralAccentColor];
    theme.incompletedColor = [[PPChatsFunc chatNeutralAccentColor] colorWithAlphaComponent:0.15];
    theme.centerColor = UIColor.whiteColor;
    theme.labelColor = AppClearClr;
    self.loadingIndicator =
        [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.color = UIColor.whiteColor;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.playButton addSubview:self.loadingIndicator];

    self.bottomBlurView = [[UIView alloc] init];
    self.bottomBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomBlurView.layer.cornerRadius = 12;
    self.bottomBlurView.clipsToBounds = YES;
    self.bottomBlurView.alpha = 1.0;
    self.bottomBlurView.backgroundColor = AppClearClr;
    [self.bubbleView addSubview:self.bottomBlurView];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = [GM MidFontWithSize:11];
    self.timeLabel.textColor = UIColor.secondaryLabelColor;
    [self.bottomBlurView addSubview:self.timeLabel];

    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.durationLabel.font = [GM MidFontWithSize:14];
    self.durationLabel.textColor = UIColor.secondaryLabelColor;
    self.durationLabel.textAlignment = NSTextAlignmentLeft;
    [self.bottomBlurView addSubview:self.durationLabel];

    self.statusIcon = [[UIImageView alloc] init];
    self.statusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.bottomBlurView addSubview:self.statusIcon];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBubbleTapped)];
    [self.bubbleView addGestureRecognizer:tap];
    self.bubbleView.userInteractionEnabled = YES;

    [self setupConstraints];
    [self setupPremiumMediaActions];
    [self setupReplyPreview];

}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.thumbnailView.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:0],
        [self.thumbnailView.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:0],
        [self.thumbnailView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-0],
        [self.thumbnailView.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor constant:-0],

        [self.glassOverlay.topAnchor constraintEqualToAnchor:self.thumbnailView.topAnchor],
        [self.glassOverlay.bottomAnchor constraintEqualToAnchor:self.thumbnailView.bottomAnchor],
        [self.glassOverlay.leadingAnchor constraintEqualToAnchor:self.thumbnailView.leadingAnchor],
        [self.glassOverlay.trailingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor],

        [self.playButton.centerXAnchor constraintEqualToAnchor:self.bubbleView.centerXAnchor],
        [self.playButton.centerYAnchor constraintEqualToAnchor:self.bubbleView.centerYAnchor],
        [self.playButton.widthAnchor constraintEqualToConstant:52],
        [self.playButton.heightAnchor constraintEqualToConstant:52],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.playButton.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.playButton.centerYAnchor],

        [self.bottomBlurView.heightAnchor constraintEqualToConstant:32],
        [self.bottomBlurView.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12],
        [self.bottomBlurView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12],
        [self.bottomBlurView.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor],

        [self.durationLabel.topAnchor constraintEqualToAnchor:self.bottomBlurView.topAnchor],
        [self.durationLabel.leadingAnchor constraintEqualToAnchor:self.bottomBlurView.leadingAnchor constant:0],

        
        [self.statusIcon.centerYAnchor constraintEqualToAnchor:self.timeLabel.centerYAnchor],
        [self.statusIcon.trailingAnchor constraintEqualToAnchor:self.bottomBlurView.trailingAnchor constant:-6],
        [self.statusIcon.widthAnchor constraintEqualToConstant:14],
        [self.statusIcon.heightAnchor constraintEqualToConstant:14],
        
        
        [self.timeLabel.centerYAnchor constraintEqualToAnchor:self.bottomBlurView.centerYAnchor constant:0],
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.statusIcon.leadingAnchor constant:-4],

       
    ]];
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
                             action:@selector(onViewMedia)
                   forControlEvents:UIControlEventTouchUpInside];

    self.downloadMediaButton = [self pp_mediaActionButtonWithSystemName:@"arrow.down"
                                                      accessibilityTitle:kLang(@"chat_media_download")];
    [self.downloadMediaButton addTarget:self
                                 action:@selector(onDownloadMedia)
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

- (void)onBubbleTapped {
    if (self.onPlayTapped) {
        self.onPlayTapped();
    }
}

- (CGRect)thumbnailFrameInWindow {
    return [self.thumbnailView convertRect:self.thumbnailView.bounds toView:nil];
}

#pragma mark - Configure

- (void)configureWithMessage:(ChatMessageModel *)message
                  isIncoming:(BOOL)isIncoming
                    maxWidth:(CGFloat)maxWidth
               groupPosition:(PPChatGroupPosition)groupPosition
{
    // 🔒 Reuse guard: prevent flicker / wrong thumbnail on reuse
    if (self.boundMessageID && [self.boundMessageID isEqualToString:message.ID]) {
        // still update lightweight state
        self.loadingVideo = message.isUploading;
        [self applyVisualState];
        [self updateMediaActionsForMessage:message animated:NO];
        return;
    }
    
    self.boundMessageID = message.ID;

    self.isIncoming = isIncoming;
    self.message = message;
    self.groupPosition = groupPosition;
    [self updateMediaActionsForMessage:message animated:YES];

    BOOL usesTrailing = [PPChatsFunc bubbleUsesTrailingAlignmentForIncoming:isIncoming];
    self.leadingConstraint.active = !usesTrailing;
    self.trailingConstraint.active = usesTrailing;
    CGFloat absoluteMax = YYScreenSize().width * 0.72;
    CGFloat resolvedWidth = maxWidth > 0 ? MIN(maxWidth, absoluteMax) : absoluteMax;
    self.maxWidthConstraint.constant = MAX(140.0, resolvedWidth);

    self.bubbleView.backgroundColor = [PPChatsFunc bubbleSurfaceColorForIncoming:isIncoming];
    self.timeLabel.textColor = [PPChatsFunc bubbleSecondaryContentColorForIncoming:isIncoming];

    if (message.blurHash.length > 0) {
        UIImage *placeholder = [PPBlurHashBridge imageFrom:message.blurHash syncSize:CGSizeMake(32, 32) punch:1.0];
        if (placeholder) {
            self.thumbnailView.image = placeholder;
        }
    }
    [PPChatsFunc applyStatusForMessage:message
                          toImageView:self.statusIcon
                           isIncoming:isIncoming
                             animated:NO];
    if (message.mediaDuration > 0) {
        NSInteger total = (NSInteger)round(message.mediaDuration);
        NSInteger minutes = total / 60;
        NSInteger seconds = total % 60;
        self.durationLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
    } else {
        self.durationLabel.text = @"";
    }

    self.timeLabel.text = [self formattedTime:message.timestamp];
    UIColor *interactive = [PPChatsFunc bubbleInteractiveAccentColorForIncoming:isIncoming];
    UIColor *controlSurface = [PPChatsFunc bubblePlaybackControlSurfaceColorForIncoming:isIncoming];
    if (!isIncoming) {
        self.playButton.backgroundColor = controlSurface;
        self.playButton.tintColor = interactive;
        self.timeLabel.textColor = [PPChatsFunc bubbleSecondaryContentColorForIncoming:NO];
    } else {
        self.playButton.backgroundColor = controlSurface;
        self.playButton.tintColor = interactive;
        self.timeLabel.textColor = [PPChatsFunc bubbleSecondaryContentColorForIncoming:YES];
    }

    // Thumbnail loading
    if (message.thumbnailImage) {
        self.thumbnailView.image = message.thumbnailImage;
    } else if (message.thumbnailURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        [PPImageLoaderManager.shared
            setImageOnImageView:self.thumbnailView
            url:message.thumbnailURL
            placeholder:self.thumbnailView.image
         complation:^(UIImage * _Nullable image, NSString * _Nullable urlString) {
            
                if (!image) return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 🔒 Ensure cell still represents same message
                    if ([weakSelf.boundMessageID isEqualToString:message.ID]) {
                        weakSelf.thumbnailView.image = image;
                        message.thumbnailImage = image;
                    }
                });
            }];
    }

    // Set state flags and apply visual state
    self.loadingVideo = message.isUploading;
    // self.playingVideo = NO; // (Do not reset playing here; controller owns playback state.)
    [self applyVisualState];
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
    BOOL canView = (message.fileURL.length > 0 || message.localVideoURL != nil);
    BOOL canDownload = canView && !message.isUploading;
    self.viewMediaButton.enabled = canView;
    self.downloadMediaButton.enabled = canDownload;
    self.viewMediaButton.alpha = canView ? 1.0 : 0.45;
    self.downloadMediaButton.alpha = canDownload ? 1.0 : 0.45;

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

#pragma mark - Thumbnail Update

- (void)updateThumbnail:(UIImage *)image
{
    if (!image) return;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateThumbnail:image];
        });
        return;
    }
    // 🔒 Guard against reuse
    if (!self.message || ![self.boundMessageID isEqualToString:self.message.ID]) return;

    self.message.thumbnailImage = image;
    [UIView transitionWithView:self.thumbnailView
                      duration:0.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.thumbnailView.image = image;
    } completion:nil];
}

#pragma mark - State

- (void)setLoading:(BOOL)isLoading
{
    self.loadingVideo = isLoading;
    [self applyVisualState];
    if (self.message) {
        [self updateMediaActionsForMessage:self.message animated:YES];
    }
}

- (void)setProgress:(CGFloat)progress
{
    if (self.message) {
        self.message.transferProgress = progress;
    }
    [self applyVisualState];
}

- (void)setPlaying:(BOOL)isPlaying
{
    self.playingVideo = isPlaying;
    [self applyVisualState];
}


#pragma mark - Status UI Update

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

#pragma mark - Actions

- (void)onPlay
{
    if (self.onPlayTapped) {
        self.onPlayTapped();
    }
}

- (void)onViewMedia
{
    if (self.onViewTapped) {
        self.onViewTapped();
    } else if (self.onPlayTapped) {
        self.onPlayTapped();
    }
}

- (void)onDownloadMedia
{
    if (self.onDownloadTapped) {
        self.onDownloadTapped();
    }
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

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.accessibilityCustomActions = nil;
    self.bubbleView.accessibilityCustomActions = nil;
    self.boundMessageID = nil;
    self.message = nil;
    self.loadingVideo = NO;
    self.playingVideo = NO;

    self.thumbnailView.image = nil;
    [self.loadingIndicator stopAnimating];
    self.onViewTapped = nil;
    self.onDownloadTapped = nil;
    self.onReplyRequested = nil;
    self.mediaActionRail.alpha = 0.0;
    self.mediaActionRail.transform = CGAffineTransformMakeScale(0.94, 0.94);
    self.viewMediaButton.transform = CGAffineTransformIdentity;
    self.downloadMediaButton.transform = CGAffineTransformIdentity;
    [self clearReplyPreview];

    [self applyVisualState];
}

@end
