//
//  ChatAudioMessageCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import "ChatAudioMessageCell.h"
#import "PPChatsFunc.h"
#import "PPPlaybackWaveformView.h"
#import "ChatBubbleView.h"


#import "ZYCircleProgressView.h"
//replace UIActivityIndicatorView with ZYCircleProgressView and make it show upload progress
@interface ChatAudioMessageCell ()<PPChatBubbleColorProviding,ChatMessageStatusUpdatable>
@property (nonatomic, strong) UIColor *playColor;

@property (nonatomic, strong) ChatMediaBubbleView *bubbleView;
@property (nonatomic, strong) PPPlaybackWaveformView *waveformView;
@property (nonatomic, strong) UIView *progressHitView;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, strong) UIView *thumbView;
@property (nonatomic, strong) UIImpactFeedbackGenerator *scrubHaptic;
@property (nonatomic, assign) NSInteger lastScrubTick;
@property (nonatomic, strong) UILabel *bottomTimeLabel;

@property (nonatomic, strong,nullable) ChatMessageModel *message;
@property (nonatomic, strong) UIImageView *statusImageView;

@property (nonatomic, strong) UIActivityIndicatorView *playLoadingIndicator;
@property (nonatomic, assign) BOOL isShowingUploadProgress;
@property (nonatomic, assign) PPChatGroupPosition groupPosition;
@property (nonatomic, assign) BOOL isIncoming;
@property (nonatomic, strong) UIStackView *audioStack;
@property (nonatomic, strong) UIView *replyPreviewView;
@property (nonatomic, strong) UIView *replyAccentView;
@property (nonatomic, strong) UILabel *replyTitleLabel;
@property (nonatomic, strong) UILabel *replySubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *replyPreviewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *audioStackTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *audioStackBelowReplyConstraint;
 @end

@implementation ChatAudioMessageCell

- (UIView *)messageInteractionView
{
    return self.bubbleView;
}


-(UIColor *)pp_bubbleBackgroundColor
{
    return [PPChatsFunc bubbleSurfaceColorForIncoming:self.isIncoming];
}


- (void)layoutSubviews {
    self.bubbleView.isIncoming = self.isIncoming;
    self.bubbleView.groupPosition = self.groupPosition;
    [super layoutSubviews];
}

  
#pragma mark - Init

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;

        [self buildUI];
    }
    return self;
}

#pragma mark - UI

- (void)buildUI
{
    // Bubble
    self.bubbleView = [[ChatMediaBubbleView alloc] init];
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bubbleView.preferredMaximumCornerRadius = 32.0;
    //self.bubbleView.layer.cornerRadius = 18;
    self.bubbleView.layer.cornerCurve = kCACornerCurveContinuous;
    //self.bubbleView.clipsToBounds = YES;
    self.semanticContentAttribute = GM.setSemantic;
    self.contentView .semanticContentAttribute = GM.setSemantic;
    self.bubbleView.semanticContentAttribute = GM.setSemantic;
    
    [self.contentView addSubview:self.bubbleView];

    self.leadingConstraint =
        [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12];

    self.trailingConstraint =
        [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12];

    self.maxWidthConstraint =
    [self.bubbleView.widthAnchor constraintEqualToConstant:YYScreenSize().width * 0.8];

    [NSLayoutConstraint activateConstraints:@[
        [self.bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPChatBubblePad],
        [self.bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPChatBubblePad],
        self.maxWidthConstraint
    ]];

    // Play / Pause (legacy UIButton)
    _playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    _playPauseButton.backgroundColor = UIColor.clearColor;
    _playPauseButton.layer.cornerRadius = 18;
    _playPauseButton.layer.cornerCurve = kCACornerCurveContinuous;
    _playPauseButton.tintColor = UIColor.labelColor;
    [_playPauseButton setImage:[UIImage systemImageNamed:@"play.fill"]
                      forState:UIControlStateNormal];
    
    [_playPauseButton addTarget:self
                         action:@selector(playPauseTapped)
               forControlEvents:UIControlEventTouchUpInside];
    
    self.playLoadingIndicator =
        [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.playLoadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.playLoadingIndicator.color = [PPChatsFunc bubbleInteractiveAccentColorForIncoming:NO];
    self.playLoadingIndicator.hidesWhenStopped = YES;
    [_playPauseButton addSubview:self.playLoadingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.playLoadingIndicator.centerXAnchor
            constraintEqualToAnchor:_playPauseButton.centerXAnchor],
        [self.playLoadingIndicator.centerYAnchor
            constraintEqualToAnchor:_playPauseButton.centerYAnchor]
    ]];
    

    // Progress (waveform)
    self.waveformView = [[PPPlaybackWaveformView alloc] init];
    self.waveformView.translatesAutoresizingMaskIntoConstraints = NO;
    self.waveformView.userInteractionEnabled = NO; // scrubbing handled by hit view
    self.waveformView.activeColor = [PPChatsFunc bubbleInteractiveAccentColorForIncoming:NO];
    self.waveformView.inactiveColor = [PPChatsFunc bubbleWaveInactiveColorForIncoming:NO];
    // 🔥 Transparent hit area (44pt Apple minimum)
    self.progressHitView = [[UIView alloc] init];
    self.progressHitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressHitView.backgroundColor = UIColor.clearColor;
    self.progressHitView.userInteractionEnabled = YES;

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handleScrubPan:)];

    [self.progressHitView addGestureRecognizer:pan];
    
    
    // Add thumb view and haptic generator
    self.thumbView = [[UIView alloc] init];
    self.thumbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbView.backgroundColor = UIColor.whiteColor;
    self.thumbView.layer.cornerRadius = 5;
    self.thumbView.alpha = 0.0;
    [self.progressHitView addSubview:self.thumbView];

    [NSLayoutConstraint activateConstraints:@[
        [self.thumbView.widthAnchor constraintEqualToConstant:12],
        [self.thumbView.heightAnchor constraintEqualToConstant:12],
        [self.thumbView.centerYAnchor constraintEqualToAnchor:self.progressHitView.centerYAnchor],
        [self.thumbView.leadingAnchor constraintEqualToAnchor:self.progressHitView.leadingAnchor],
    ]];

    self.scrubHaptic =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [self.scrubHaptic prepare];

    self.lastScrubTick = -1;

    // Time
    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = [GM MidFontWithSize:13];
    self.timeLabel.textColor = [PPChatsFunc bubbleSecondaryContentColorForIncoming:NO];
    self.timeLabel.text = @"0:00";
    
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    
    // Bottom time label (e.g. 0:05 or 12:41 PM)
    self.bottomTimeLabel = [[UILabel alloc] init];
    self.bottomTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomTimeLabel.font = [GM MidFontWithSize:11];
    self.bottomTimeLabel.textColor = [PPChatsFunc bubbleSecondaryContentColorForIncoming:NO];
    self.bottomTimeLabel.text = @"0:00";
    [self.bottomTimeLabel sizeToFit];
    [self.bottomTimeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisHorizontal];
    [self.bottomTimeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                          forAxis:UILayoutConstraintAxisHorizontal];

    // Status icon (sent / delivered / read)
    self.statusImageView = [[UIImageView alloc] init];
    self.statusImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusImageView.tintColor = UIColor.tertiaryLabelColor;
    
    const CGFloat statusSize = 14.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.statusImageView.widthAnchor constraintEqualToConstant:statusSize],
        [self.statusImageView.heightAnchor constraintEqualToConstant:statusSize],
    ]];

    [_playPauseButton.widthAnchor constraintEqualToConstant:36].active = YES;
    [_playPauseButton.heightAnchor constraintEqualToConstant:36].active = YES;
    
    [self.progressHitView setContentHuggingPriority:UILayoutPriorityDefaultLow
                                           forAxis:UILayoutConstraintAxisHorizontal];
    [self.progressHitView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                         forAxis:UILayoutConstraintAxisHorizontal];

    // Stack
    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:@[
            _playPauseButton,
            self.timeLabel,
            self.progressHitView,
            self.bottomTimeLabel,
            self.statusImageView
        ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10;
    stack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.bubbleView addSubview:stack];
    self.audioStack = stack;

    if (@available(iOS 11.0, *)) {
        [stack setCustomSpacing:6.0 afterView:self.bottomTimeLabel];
    }

    self.replyPreviewView = [UIView new];
    self.replyPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyPreviewView.hidden = YES;
    self.replyPreviewView.clipsToBounds = YES;
    self.replyPreviewView.layer.cornerRadius = 12.0;
    self.replyPreviewView.layer.cornerCurve = kCACornerCurveContinuous;
    self.replyPreviewView.layer.borderWidth = 0.0;
    [self.bubbleView addSubview:self.replyPreviewView];

    self.replyAccentView = [UIView new];
    self.replyAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyAccentView.layer.cornerRadius = 1.5;
    [self.replyPreviewView addSubview:self.replyAccentView];

    self.replyTitleLabel = [UILabel new];
    self.replyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyTitleLabel.font = [GM boldFontWithSize:11.0];
    self.replyTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.replyTitleLabel.numberOfLines = 1;
    self.replyTitleLabel.textAlignment = NSTextAlignmentNatural;
    [self.replyPreviewView addSubview:self.replyTitleLabel];

    self.replySubtitleLabel = [UILabel new];
    self.replySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.replySubtitleLabel.font = [GM MidFontWithSize:12.0];
    self.replySubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.replySubtitleLabel.numberOfLines = 1;
    self.replySubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.replySubtitleLabel.textAlignment = NSTextAlignmentNatural;
    [self.replyPreviewView addSubview:self.replySubtitleLabel];

    self.replyPreviewHeightConstraint =
        [self.replyPreviewView.heightAnchor constraintEqualToConstant:0.0];
    [NSLayoutConstraint activateConstraints:@[
        [self.replyPreviewView.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:8.0],
        [self.replyPreviewView.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:10.0],
        [self.replyPreviewView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-10.0],
        self.replyPreviewHeightConstraint,
        [self.replyAccentView.leadingAnchor constraintEqualToAnchor:self.replyPreviewView.leadingAnchor constant:9.0],
        [self.replyAccentView.centerYAnchor constraintEqualToAnchor:self.replyPreviewView.centerYAnchor],
        [self.replyAccentView.widthAnchor constraintEqualToConstant:3.0],
        [self.replyAccentView.heightAnchor constraintEqualToConstant:27.0],
        [self.replyTitleLabel.topAnchor constraintEqualToAnchor:self.replyPreviewView.topAnchor constant:6.0],
        [self.replyTitleLabel.leadingAnchor constraintEqualToAnchor:self.replyAccentView.trailingAnchor constant:8.0],
        [self.replyTitleLabel.trailingAnchor constraintEqualToAnchor:self.replyPreviewView.trailingAnchor constant:-9.0],
        [self.replySubtitleLabel.topAnchor constraintEqualToAnchor:self.replyTitleLabel.bottomAnchor constant:1.0],
        [self.replySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.replyTitleLabel.leadingAnchor],
        [self.replySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.replyTitleLabel.trailingAnchor],
    ]];

    self.audioStackTopConstraint =
        [stack.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:8.0];
    self.audioStackBelowReplyConstraint =
        [stack.topAnchor constraintEqualToAnchor:self.replyPreviewView.bottomAnchor constant:7.0];
    self.audioStackTopConstraint.active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12],
        [stack.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor constant:-8.0],
    ]];

    [self.progressHitView addSubview:self.waveformView];
    // FIX 4: Ensure waveform is above bubble background (z-order safety)
    [self.progressHitView bringSubviewToFront:self.waveformView];

    [NSLayoutConstraint activateConstraints:@[
        [self.waveformView.leadingAnchor constraintEqualToAnchor:self.progressHitView.leadingAnchor],
        [self.waveformView.trailingAnchor constraintEqualToAnchor:self.progressHitView.trailingAnchor],
        [self.waveformView.centerYAnchor constraintEqualToAnchor:self.progressHitView.centerYAnchor],
        [self.waveformView.heightAnchor constraintEqualToConstant:30],

        // Touch target height
        [self.progressHitView.heightAnchor constraintEqualToConstant:44],
    ]];
    self.bubbleLeadingConstraint =
        [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12];

    self.bubbleTrailingConstraint =
        [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12];
    self.waveformView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
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
    self.replyPreviewHeightConstraint.constant = 46.0;
    self.audioStackTopConstraint.active = NO;
    self.audioStackBelowReplyConstraint.active = YES;
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
    self.audioStackBelowReplyConstraint.active = NO;
    self.audioStackTopConstraint.active = YES;
    self.replyPreviewView.hidden = YES;
    self.replyTitleLabel.text = nil;
    self.replySubtitleLabel.text = nil;
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
                          toImageView:self.statusImageView
                           isIncoming:self.isIncoming
                             animated:YES];
    // Do not touch thumbnail, loading, play state, or applyVisualState.
}
-(void)setLoading:(BOOL)isLoading
{
    self.playPauseButton.userInteractionEnabled = !isLoading;

    if (isLoading) {
        [_playPauseButton setTintColor:UIColor.clearColor];
        [self.playLoadingIndicator startAnimating];
    } else {
        [_playPauseButton setTintColor:self.playColor];
        [self.playLoadingIndicator stopAnimating];
    }
}
#pragma mark - Public API (UI only)

// Upload progress indicator for outgoing audio messages
- (void)setUploadProgress:(CGFloat)progress
{
    self.isShowingUploadProgress = YES;
    [self setLoading:YES];

    if (progress >= 1.0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(0.25 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                self.isShowingUploadProgress = NO;
                [self setLoading:NO];
            });
    }
}

- (void)setBottomTimeText:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"h:mm a";
    self.bottomTimeLabel.text = [formatter stringFromDate:date ?: [NSDate date]];
}

- (void)setStatusImage:(UIImage *)image
{
    self.statusImageView.image = image;
    self.statusImageView.hidden = (image == nil);
}

- (void)handleScrubPan:(UIPanGestureRecognizer *)gesture
{
    CGPoint location = [gesture locationInView:self.progressHitView];
    CGFloat width = self.progressHitView.bounds.size.width;
    if (width <= 0) return;

    BOOL isRTL =
        self.waveformView.effectiveUserInterfaceLayoutDirection
        == UIUserInterfaceLayoutDirectionRightToLeft;

    CGFloat visual = location.x / width;
    visual = MAX(0.0, MIN(visual, 1.0));

    CGFloat progress = isRTL ? (1.0 - visual) : visual;

    

    // Thumb position
    CGFloat visualX =
        isRTL ? (width * (1.0 - progress)) : (width * progress);

    self.thumbView.transform = CGAffineTransformMakeScale(1.35, 1.35);
    self.thumbView.alpha = 1.0;
    self.thumbView.frame =
        CGRectMake(visualX - 6,
                   (self.progressHitView.bounds.size.height - 12) / 2.0,
                   12,
                   12);

    // Haptic ticks
    NSInteger ticks = 20;
    NSInteger tick = (NSInteger)round(progress * ticks);

    if (tick != self.lastScrubTick) {
        [self.scrubHaptic impactOccurred];
        [self.scrubHaptic prepare];
        self.lastScrubTick = tick;
    }

    // Stronger haptic at ends
    if (gesture.state == UIGestureRecognizerStateEnded ||
        gesture.state == UIGestureRecognizerStateCancelled) {

        if (progress < 0.02 || progress > 0.98) {
            UIImpactFeedbackGenerator *heavy =
                [[UIImpactFeedbackGenerator alloc]
                    initWithStyle:UIImpactFeedbackStyleHeavy];
            [heavy impactOccurred];
        }

        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.55
              initialSpringVelocity:0.0
                            options:0
                         animations:^{
            self.thumbView.transform = CGAffineTransformIdentity;
            self.thumbView.alpha = 0.0;
        } completion:nil];

        self.lastScrubTick = -1;
    }

    if (self.onScrubToProgress) {
        self.onScrubToProgress(progress);
    }
}


- (void)playPauseTapped
{
    // 1️⃣ Optimistically toggle UI
    BOOL willPlay =
        [self.playPauseButton.currentImage
         isEqual:[UIImage systemImageNamed:@"play.fill"]];

    [self setPlaying:willPlay];

    // 2️⃣ Forward action to controller
    if (self.onPlayPauseTapped) {
        self.onPlayPauseTapped();
    }
}
 
#pragma mark - Public API (UI only)

- (void)setIncoming:(BOOL)isIncoming maxWidth:(CGFloat)maxWidth
             status:(ChatMessageStatus)status
                msg:(ChatMessageModel *)msg
      groupPosition:(PPChatGroupPosition)groupPosition
{

self.isIncoming = isIncoming;
self.message = msg;
self.groupPosition = groupPosition;
    
    BOOL usesTrailing = [PPChatsFunc bubbleUsesTrailingAlignmentForIncoming:isIncoming];
    self.leadingConstraint.active = !usesTrailing;
    self.trailingConstraint.active = usesTrailing;
    self.maxWidthConstraint.constant = maxWidth * 0.8;

    if (isIncoming) {
        //[self applyIncomingBubbleElevation:YES];
    } else {
        //[self applyIncomingBubbleElevation:YES];
    }

    self.bubbleView.backgroundColor = [PPChatsFunc bubbleSurfaceColorForIncoming:isIncoming];
    UIColor *foreground = [PPChatsFunc bubblePrimaryContentColorForIncoming:isIncoming];
    UIColor *secondary = [PPChatsFunc bubbleSecondaryContentColorForIncoming:isIncoming];
    UIColor *interactive = [PPChatsFunc bubbleInteractiveAccentColorForIncoming:isIncoming];
    UIColor *controlSurface = [PPChatsFunc bubblePlaybackControlSurfaceColorForIncoming:isIncoming];
    self.timeLabel.textColor = secondary;
    self.bottomTimeLabel.textColor = secondary;
    
    if(!isIncoming)
    {
        self.statusImageView.hidden = NO;
        self.playLoadingIndicator.color = foreground;
        _playPauseButton.backgroundColor = controlSurface;
        _playPauseButton.tintColor = interactive;
        _playColor = interactive;
        self.waveformView.activeColor = foreground;
        self.waveformView.inactiveColor = [PPChatsFunc bubbleWaveInactiveColorForIncoming:NO];
 
       // [Styling applyCornerMaskToView:self.bubbleView tl:12 tr:6 bl:12 br:12];

        [PPChatsFunc applyStatusForMessage:msg
                              toImageView:self.statusImageView
                               isIncoming:NO
                                 animated:NO];
    }
    else
    {
        self.statusImageView.hidden = YES;
        _playPauseButton.backgroundColor = controlSurface;
        _playPauseButton.tintColor = interactive;
        _playColor = interactive;

        self.waveformView.activeColor = interactive;
        self.waveformView.inactiveColor = [PPChatsFunc bubbleWaveInactiveColorForIncoming:YES];
        self.playLoadingIndicator.color = interactive;
        // FIX 2: Force waveform to redraw when colors / state change
         //[Styling applyCornerMaskToView:self.bubbleView tl:6 tr:12 bl:12 br:12];
    }
    
  
     
    if (![self.boundMessageID isEqualToString:msg.ID]) {
        self.boundMessageID = msg.ID;

        //[self animateBlockBreathingIfNeeded];

        [self.waveformView reset];

        if (msg.waveformSamples.count > 0) {
            [self.waveformView setSamples:msg.waveformSamples];
        } else {
            [self.waveformView setSamples:[PPPlaybackWaveformView idleSamples]];
        }

        [self.waveformView setPlaybackProgress:0];
    }
    
    // Update shadow path for correct rounded shadow after layout
    self.bubbleView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bubbleView.bounds
                                   cornerRadius:self.bubbleView.preferredMaximumCornerRadius].CGPath;
    
    [self layoutIfNeeded];
    [self setNeedsLayout];
}

- (void)setTotalDuration:(NSTimeInterval)duration
{
    if (duration <= 0) return;

    NSInteger min = (NSInteger)(duration / 60);
    NSInteger sec = (NSInteger)fmod(duration, 60);

    self.timeLabel.text =
        [NSString stringWithFormat:@"%ld:%02ld", (long)min, (long)sec];

    [self.waveformView setPlaybackProgress:0.0];
}

- (void)applyPlaybackStateForMessageID:(NSString *)messageID
                              progress:(CGFloat)progress
                              isPlaying:(BOOL)isPlaying
                               duration:(NSTimeInterval)duration
{
    if (![self.boundMessageID isEqualToString:messageID]) {
        return; // ❗️ignore updates for other messages
    }

    [self setPlaying:isPlaying];
    [self setProgress:progress];
    [self setCurrentTime:(progress * duration) duration:duration];
}

- (void)setPlaying:(BOOL)isPlaying
{
    BOOL currentlyPlaying =
        [self.playPauseButton.currentImage
         isEqual:[UIImage systemImageNamed:@"pause.fill"]];

    // ✅ Prevent duplicate animation
    if (currentlyPlaying == isPlaying) {
        return;
    }

    UIImage *img =
        [UIImage systemImageNamed:(isPlaying ? @"pause.fill" : @"play.fill")];

    [self.playPauseButton setImage:img
                          forState:UIControlStateNormal];
}

- (void)setProgress:(CGFloat)progress {
    [self.waveformView setPlaybackProgress:progress];
}
- (void)setCurrentTime:(NSTimeInterval)currentTime
              duration:(NSTimeInterval)duration
{
    if (duration <= 0) {
        self.timeLabel.text = @"0:00";
        return;
    }

    NSTimeInterval remaining =
        MAX(duration - currentTime, 0);

    NSInteger min = (NSInteger)(remaining / 60);
    NSInteger sec = (NSInteger)round(remaining) % 60;

    self.timeLabel.text =
        [NSString stringWithFormat:@"%ld:%02ld",
         (long)min, (long)sec];
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.accessibilityCustomActions = nil;
    self.bubbleView.accessibilityCustomActions = nil;
    [self.bubbleView.layer removeAllAnimations];
    [self setPlaying:NO];
    [self setProgress:0];
    self.boundMessageID = nil;
    self.statusImageView.hidden = YES;
    self.playPauseButton.alpha = 1.0;
    self.isShowingUploadProgress = NO;
    [self.playLoadingIndicator stopAnimating];
    [self clearReplyPreview];
 }


#pragma mark - Micro-Shadow Elevation

- (void)applyIncomingBubbleElevation:(BOOL)enabled
{
    if (enabled) {
        self.bubbleView.layer.shadowColor =
            [UIColor blackColor].CGColor;
        self.bubbleView.layer.shadowOpacity = 0.06;
        self.bubbleView.layer.shadowRadius = 4.0;
        self.bubbleView.layer.shadowOffset = CGSizeMake(0, 1.5);
        self.bubbleView.layer.masksToBounds = NO;
    } else {
        self.bubbleView.layer.shadowOpacity = 0.0;
        self.bubbleView.layer.shadowRadius = 0.0;
        self.bubbleView.layer.shadowOffset = CGSizeZero;
    }
}
 
#pragma mark - Block Breathing Animation

- (void)animateBlockBreathingIfNeeded
{
    return;/*
    // Respect Reduce Motion
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    // Only animate for outgoing blocks
    if (self.isIncoming) return;

    // Only for new blocks (single or first)
    if (self.bubblePosition != PPBubblePositionSingle &&
        self.bubblePosition != PPBubblePositionFirst) {
        return;
    }

    // Prevent replay on reuse
    if (self.bubbleView.layer.animationKeys.count > 0) {
        return;
    }

    self.bubbleView.transform = CGAffineTransformMakeScale(0.985, 0.985);
    self.bubbleView.alpha = 0.96;

    [UIView animateWithDuration:0.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.bubbleView.transform = CGAffineTransformIdentity;
        self.bubbleView.alpha = 1.0;
    } completion:nil]; */
}

@end
