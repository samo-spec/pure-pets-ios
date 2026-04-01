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

@interface ChatVideoMessageCell ()<ChatMessageStatusUpdatable>
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIVisualEffectView *glassOverlay;
@property (nonatomic, strong) UIButton *playButton;
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

#pragma mark - Visual State

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.window) return;
    
    [PPChatsFunc applyBubbleMask:self.bubbleView isIncoming:self.isIncoming groupPosition:self.groupPosition showGlow:YES];
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
    self.bubbleView = [[UIView alloc] init];
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
    theme.completedColor = AppPrimaryClr;
    theme.incompletedColor = [AppPrimaryClr colorWithAlphaComponent:0.15];
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
        return;
    }
    self.boundMessageID = message.ID;

    self.isIncoming = isIncoming;
    self.message = message;
    self.groupPosition = groupPosition;

    self.leadingConstraint.active = !isIncoming;
    self.trailingConstraint.active = isIncoming;
    CGFloat absoluteMax = YYScreenSize().width * 0.72;
    CGFloat resolvedWidth = maxWidth > 0 ? MIN(maxWidth, absoluteMax) : absoluteMax;
    self.maxWidthConstraint.constant = MAX(140.0, resolvedWidth);

    self.bubbleView.backgroundColor = isIncoming ? PPChatBubbleSomeoneColor : PPChatBubbleMineColor;
    self.timeLabel.textColor = isIncoming ? PPChatTimeSomeoneColor : PPChatTimeMineColor;

    if (message.blurHash.length > 0) {
        UIImage *placeholder = [PPBlurHashBridge imageFrom:message.blurHash syncSize:CGSizeMake(32, 32) punch:1.0];
        if (placeholder) {
            self.thumbnailView.image = placeholder;
        }
    }
    [self updateMessageStatus:message];
    if (message.mediaDuration > 0) {
        NSInteger total = (NSInteger)round(message.mediaDuration);
        NSInteger minutes = total / 60;
        NSInteger seconds = total % 60;
        self.durationLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
    } else {
        self.durationLabel.text = @"";
    }

    self.timeLabel.text = [self formattedTime:message.timestamp];
    if (!isIncoming) {
        self.playButton.backgroundColor = [PPChatPrimaryAccent colorWithAlphaComponent:0.18];
        self.playButton.tintColor = PPChatPrimaryAccent;
        self.timeLabel.textColor = AppBackgroundClrLigter;
    } else {
        self.playButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
        self.playButton.tintColor = UIColor.labelColor;
        self.timeLabel.textColor = UIColor.secondaryLabelColor;
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
            self.statusIcon.image = icon;
            self.statusIcon.tintColor = tint;
            self.statusIcon.hidden = (icon == nil);
        };
        updateStatusIcon();
    }
    // Do not touch thumbnail, loading, play state, or applyVisualState.
}

#pragma mark - Actions

- (void)onPlay
{
    if (self.onPlayTapped) {
        self.onPlayTapped();
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
    self.boundMessageID = nil;
    self.message = nil;
    self.loadingVideo = NO;
    self.playingVideo = NO;

    self.thumbnailView.image = nil;
    [self.loadingIndicator stopAnimating];

    [self applyVisualState];
}

@end
