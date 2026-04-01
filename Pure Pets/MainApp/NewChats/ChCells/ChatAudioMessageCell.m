//
//  ChatAudioMessageCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/01/2026.
//


#import "ChatAudioMessageCell.h"
#import "PPChatsFunc.h"
#import "PPPlaybackWaveformView.h"


#import "ZYCircleProgressView.h"
//replace UIActivityIndicatorView with ZYCircleProgressView and make it show upload progress
@interface ChatAudioMessageCell ()<PPChatBubbleColorProviding,ChatMessageStatusUpdatable>
@property (nonatomic, strong) UIColor *playColor;

@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) PPPlaybackWaveformView *waveformView;
@property (nonatomic, strong) UIView *progressHitView;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *statuTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *statuTrailingConstraintSomeOne;
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
 @end

@implementation ChatAudioMessageCell


-(UIColor *)pp_bubbleBackgroundColor
{
    //return self.bubbleView.backgroundColor ?: PPChatBackground;
    
    UIColor *soft =
    [PPColorUtils blendColor:AppBackgroundClrDarker
                        withColor:PPChatBackground
                           factor:0.75];
    return soft;
}


- (void)layoutSubviews {
    [super layoutSubviews];

    BOOL glow = _isIncoming && _groupPosition != PPChatGroupPositionMiddle;
    [PPChatsFunc applyBubbleMask:self.bubbleView isIncoming:self.isIncoming groupPosition:self.groupPosition showGlow:glow];

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
    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
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
    _playPauseButton.backgroundColor =
        [AppForgroundColr colorWithAlphaComponent:0.0];
    _playPauseButton.layer.cornerRadius = 16;
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
    self.playLoadingIndicator.color = AppForgroundColr;
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
    self.waveformView.activeColor = AppPrimaryClr;
    self.waveformView.inactiveColor = [AppBackgroundClr colorWithAlphaComponent:0.3];
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
    self.timeLabel.textColor = AppBackgroundClrLigter;
    self.timeLabel.text = @"0:00";
    
    [_playPauseButton.widthAnchor constraintEqualToConstant:32].active = YES;
    [_playPauseButton.heightAnchor constraintEqualToConstant:32].active = YES;
    
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];

    [self.timeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    
    
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
            
        ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    // FIX 3: Ensure waveform is not visually collapsed by stack alignment
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 10;
    stack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.bubbleView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:8],

        [stack.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12],
 
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
    
     
    // Bottom time label (e.g. 0:05 or 12:41 PM)
    self.bottomTimeLabel = [[UILabel alloc] init];
    self.bottomTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomTimeLabel.font = [GM MidFontWithSize:11];
    self.bottomTimeLabel.textColor = AppBackgroundClrDarker;
    self.bottomTimeLabel.text = @"0:00";
    [self.bottomTimeLabel sizeToFit];
    // Status icon (sent / delivered / read)
    self.statusImageView = [[UIImageView alloc] init];
    self.statusImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusImageView.tintColor = UIColor.tertiaryLabelColor;
    
     
    [self.bubbleView addSubview:_bottomTimeLabel];
    [self.bubbleView addSubview:_statusImageView];
  
    const CGFloat padding16 = 16.0;
   
    const CGFloat statusSize = 14.0;
    const CGFloat spacingBetweenTimeAndStatus = 6.0;
    self.statuTrailingConstraint = [self.bottomTimeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusImageView.leadingAnchor constant:-spacingBetweenTimeAndStatus];
    self.statuTrailingConstraintSomeOne = [self.bottomTimeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.bubbleView.trailingAnchor constant:-16];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusImageView.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor constant: -8],
        [self.statusImageView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-padding16],
        [self.statusImageView.widthAnchor constraintEqualToConstant:statusSize],
        [self.statusImageView.heightAnchor constraintEqualToConstant:statusSize],
        // Removed conflicting trailing constraints:
        [self.bottomTimeLabel.centerYAnchor constraintEqualToAnchor:self.statusImageView.centerYAnchor],
        self.statuTrailingConstraint,
    ]];
    self.bubbleLeadingConstraint =
        [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12];

    self.bubbleTrailingConstraint =
        [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12];
    self.waveformView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
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
            self.statusImageView.image = icon;
            self.statusImageView.tintColor = tint;
            self.statusImageView.hidden = (icon == nil);
        };
        updateStatusIcon();
    }
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
    
    self.leadingConstraint.active = !isIncoming;
    self.trailingConstraint.active = isIncoming;
    self.maxWidthConstraint.constant = maxWidth * 0.8;

    if (isIncoming) {
       // self.bubbleView.backgroundColor =
       // PPColorWithAddedSaturation(AppPrimaryClr, 0.05);

        //[self applyIncomingBubbleElevation:YES];
    } else {
        //[self applyIncomingBubbleElevation:YES];
    }

    self.bubbleView.backgroundColor =  isIncoming ?  PPChatBubbleSomeoneColor : PPChatBubbleMineColor;
    self.timeLabel.textColor = isIncoming ? PPChatTimeSomeoneColor : PPChatTimeMineColor;
    self.bottomTimeLabel.textColor =  isIncoming ? PPChatTimeSomeoneColor : PPChatTimeMineColor;
    
    if(!isIncoming)
    {
        self.statuTrailingConstraint.active = YES;
        self.statuTrailingConstraintSomeOne.active = NO;
        self.playLoadingIndicator.color = AppForgroundColr;
        _playPauseButton.backgroundColor =  [PPChatPrimaryAccent colorWithAlphaComponent:0.18];
        _playPauseButton.tintColor = PPChatPrimaryAccent;
        _playColor = PPChatPrimaryAccent;
        self.waveformView.activeColor = AppForgroundColr;
        self.waveformView.inactiveColor = [AppBackgroundClr colorWithAlphaComponent:0.3];
 
       // [Styling applyCornerMaskToView:self.bubbleView tl:12 tr:6 bl:12 br:12];

        UIImage *icon = nil;
        UIColor *tint = AppBackgroundClrLigter;

        switch (status) {
            case ChatMessageStatusSending:
                icon = PPSYSImage(@"clock");
                tint = [AppForgroundColr colorWithAlphaComponent:0.4];
                break;

            case ChatMessageStatusSent:
                icon = PPSYSImage(@"checkmark");
                tint = [AppForgroundColr colorWithAlphaComponent:0.4];
                break;

            case ChatMessageStatusDelivered:
                icon = PPImage(@"checked");
                tint = [AppForgroundColr colorWithAlphaComponent:0.4];
                break;

            case ChatMessageStatusRead:
                icon = PPImage(@"checked");
                tint = AppForgroundColr;
                break;
        }

        self.statusImageView.image = icon;
        self.statusImageView.tintColor = tint;
        self.statusImageView.hidden = (icon == nil);
    }
    else
    {
        _playPauseButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
        _playPauseButton.tintColor = UIColor.labelColor;
        _playColor = UIColor.labelColor;

        self.waveformView.activeColor = AppPrimaryTextClr;
        self.waveformView.inactiveColor = [AppSecondaryTextClr colorWithAlphaComponent:0.2];
        self.playLoadingIndicator.color = AppPrimaryClr;
        // FIX 2: Force waveform to redraw when colors / state change
         //[Styling applyCornerMaskToView:self.bubbleView tl:6 tr:12 bl:12 br:12];
        self.statuTrailingConstraint.active = NO;
        self.statuTrailingConstraintSomeOne.active = YES;
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
                                   cornerRadius:12].CGPath;
    
    [self layoutIfNeeded];

    
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
    [self.bubbleView.layer removeAllAnimations];
    [self setPlaying:NO];
    [self setProgress:0];
    self.boundMessageID = nil;
    self.statusImageView.hidden = YES;
    self.playPauseButton.alpha = 1.0;
    self.isShowingUploadProgress = NO;
    [self.playLoadingIndicator stopAnimating];
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
