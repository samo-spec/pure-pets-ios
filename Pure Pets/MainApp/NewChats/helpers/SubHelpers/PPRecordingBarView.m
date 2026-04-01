//
//  PPRecordingBarView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/01/2026.
//


#import "PPRecordingBarView.h"


@interface PPRecordingBarView ()

@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong, readwrite) PPInsetLabel *timeLabel;
@property (nonatomic, strong, readwrite) UILabel *hintLabel;
@property (nonatomic, strong, readwrite) UIButton *sendButton;
@property (nonatomic, strong, readwrite) UIButton *deleteButton;
@property (nonatomic, strong, readwrite) UIButton *playPauseButton;

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) NSLayoutConstraint *barHeightConstraint;

@end

@implementation PPRecordingBarView
  
 
#pragma mark - Init
- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
         [self setRecordingState:PPRecordingBarStateHidden animated:NO];
        self.clipsToBounds = NO;
        self.layer.masksToBounds = NO;
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    
    self.blurView.clipsToBounds = NO;
    self.blurView.layer.masksToBounds = NO;
    
 }

- (void)setPlaying:(BOOL)isPlaying animated:(BOOL)animated
{
    if (_isPlaying == isPlaying) return;
    _isPlaying = isPlaying;

    UIImage *image =
        isPlaying
        ? [UIImage systemImageNamed:@"pause.fill"]
        : [UIImage systemImageNamed:@"play.fill"];

    if (!animated) {
        [self.playPauseButton setImage:image forState:UIControlStateNormal];
        return;
    }

 
    [UIView transitionWithView:self.playPauseButton
                      duration:0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [self.playPauseButton setImage:image forState:UIControlStateNormal];
    } completion:^(BOOL finished) {
        self.playPauseButton.userInteractionEnabled = YES;
    }];

    // 🔥 Micro haptic
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *h =
            [[UIImpactFeedbackGenerator alloc]
             initWithStyle:UIImpactFeedbackStyleLight];
        [h prepare];
        [h impactOccurred];
    }
}

- (void)updateDuration:(NSTimeInterval)duration {
    NSInteger sec = (NSInteger)duration;
    self.timeLabel.text =
        [NSString stringWithFormat:@"%02ld:%02ld", sec / 60, sec % 60];
}

//01033985304
//01036495306

#pragma mark - Setup
- (void)setBarHeight:(CGFloat)height animated:(BOOL)animated {
    self.barHeightConstraint.constant = height;

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            [self layoutIfNeeded];
        } completion:nil];
    } else {
        [self layoutIfNeeded];
    }
}
// PPRecordingBarView.m
// Fixed version with proper constraints
- (void)setupView {
    
    self.barHeightConstraint =
        [self.heightAnchor constraintEqualToConstant:56];
    self.barHeightConstraint.priority = UILayoutPriorityRequired;
    self.barHeightConstraint.active = YES;
    
    self.layer.cornerRadius = 0.0;
    self.layer.masksToBounds = NO;
    self.backgroundColor = AppClearClr;

    // Setup blurView
    self.blurView = [[UIView alloc] init];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.backgroundColor = AppClearClr;
    [self addSubview:self.blurView];

    // Fixed height for the bar
    //[self.heightAnchor constraintEqualToConstant:56.0].active = YES;

    // Setup timeLabel
    self.timeLabel = [[PPInsetLabel alloc] init];
    self.timeLabel.font = [GM MidFontWithSize:13];
    self.timeLabel.textColor = UIColor.labelColor;
    self.timeLabel.text = @"00:00";
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    self.timeLabel.textInsets = UIEdgeInsetsMake(4, 0, 4, 0);

    // Setup hintLabel (if you're using it)
    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.font = [GM fontWithSize:13];
    self.hintLabel.textColor = UIColor.secondaryLabelColor;
    self.hintLabel.text = kLang(@"Slide to cancel");
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    
    // Setup waveformView
    self.waveformView = [[PPWaveformView alloc] init];
    self.waveformView.translatesAutoresizingMaskIntoConstraints = NO;
    self.waveformView.tintColor = UIColor.yellowColor;
    // ENSURE: waveformView never shrinks
    [self.waveformView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [self.waveformView setContentHuggingPriority:UILayoutPriorityDefaultLow
                                          forAxis:UILayoutConstraintAxisHorizontal];
    [self.waveformView.widthAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;
    
    // Keep timeLabel with high hugging priority
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];
    
    // Explicit waveform height constraint so it doesn't collapse
    [self.waveformView.heightAnchor constraintEqualToConstant:30].active = YES;
 

    // Setup buttons
    self.sendButton = [self iconButton:@"arrow.up"];
    self.sendButton.alpha = 1;

    self.deleteButton = [self iconButton:@"microphone.badge.xmark.fill"];
    self.deleteButton.tintColor = UIColor.systemRedColor;
    self.deleteButton.alpha = 1;

    self.playPauseButton = [self iconButton:@"play.fill"];
    self.playPauseButton.alpha = 1;
  
    [self.playPauseButton addTarget:self
                             action:@selector(playPauseTouchDown)
                   forControlEvents:UIControlEventTouchDown];

    [self.playPauseButton addTarget:self
                             action:@selector(playPauseTouchUp)
                   forControlEvents:UIControlEventTouchUpInside |
                                    UIControlEventTouchCancel |
                                    UIControlEventTouchUpOutside];

    // Create vertical stack for time + waveform
   

    UIButton *centerBarView =  [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
    centerBarView.translatesAutoresizingMaskIntoConstraints = NO;
    centerBarView.backgroundColor = UIColor.clearColor;
    centerBarView.userInteractionEnabled = YES;
     
    UIButtonConfiguration *config = centerBarView.configuration;
    config.background.cornerRadius = 16;
    config.background.backgroundColor = UIColor.clearColor;
    config.baseBackgroundColor = UIColor.clearColor;
    centerBarView.configuration = config;
    
    // Center stack with play button and wave stack
    UIStackView *centerStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.playPauseButton,
       
        self.waveformView,
        self.timeLabel,
    ]];
    centerStack.axis = UILayoutConstraintAxisHorizontal;
    centerStack.alignment = UIStackViewAlignmentCenter;
    centerStack.spacing = 6;
    centerStack.translatesAutoresizingMaskIntoConstraints = NO;
    centerStack.distribution = UIStackViewDistributionFillProportionally;
    centerStack.backgroundColor = UIColor.clearColor;
    
    [centerBarView addSubview:centerStack];
    [NSLayoutConstraint activateConstraints:@[
        [centerStack.topAnchor constraintEqualToAnchor:centerBarView.topAnchor],
        [centerStack.bottomAnchor constraintEqualToAnchor:centerBarView.bottomAnchor],
        [centerStack.leadingAnchor constraintEqualToAnchor:centerBarView.leadingAnchor constant:4],
        [centerStack.trailingAnchor constraintEqualToAnchor:centerBarView.trailingAnchor constant:-8],
    ]];
    
    [centerBarView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];
    [centerBarView setContentHuggingPriority:UILayoutPriorityDefaultLow
                                      forAxis:UILayoutConstraintAxisHorizontal];
    
    [centerBarView.heightAnchor constraintEqualToConstant:44].active = YES;

    // --- BEGIN: Add subviews directly for manual constraints ---
    [self.blurView addSubview:centerBarView];
    [self.blurView addSubview:self.sendButton];
    [self.blurView addSubview:self.deleteButton];
    // --- END: Add subviews directly for manual constraints ---
    
    [self.playPauseButton addTarget:self
                             action:@selector(onPlayPause)
                   forControlEvents:UIControlEventTouchUpInside];
    
    // Add targets
    [self.sendButton addTarget:self
                        action:@selector(onSend)
              forControlEvents:UIControlEventTouchUpInside];
    [self.deleteButton addTarget:self
                          action:@selector(onCancel)
                forControlEvents:UIControlEventTouchUpInside];
    
    // Keep buttons with high hugging priority so they don't expand horizontally
    // Ensure ALL buttons have required width/height and priorities
    NSArray *allButtons = @[self.sendButton, self.deleteButton, self.playPauseButton];
    for (UIButton *button in allButtons) {
        [button.widthAnchor constraintEqualToConstant:44.0].active = YES;
        [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
        [button setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
        [button setContentHuggingPriority:UILayoutPriorityRequired
                                   forAxis:UILayoutConstraintAxisHorizontal];
    }
 
    // --- BEGIN: Apply manual constraints for chat input bar geometry ---
    [NSLayoutConstraint activateConstraints:@[
        // Send button (LEFT)
        [self.sendButton.leadingAnchor
            constraintEqualToAnchor:self.blurView.leadingAnchor constant:12],
        [self.sendButton.centerYAnchor
            constraintEqualToAnchor:self.blurView.centerYAnchor],
        [self.sendButton.widthAnchor constraintEqualToConstant:44.0],
        [self.sendButton.heightAnchor constraintEqualToConstant:44.0],

        // Delete button (RIGHT)
        [self.deleteButton.trailingAnchor
            constraintEqualToAnchor:self.blurView.trailingAnchor constant:-12],
        [self.deleteButton.centerYAnchor
            constraintEqualToAnchor:self.sendButton.centerYAnchor],
        [self.deleteButton.widthAnchor constraintEqualToConstant:44.0],
        [self.deleteButton.heightAnchor constraintEqualToConstant:44.0],

        // Center bar view (REPLACES TEXT VIEW)
        [centerBarView.leadingAnchor
            constraintEqualToAnchor:self.sendButton.trailingAnchor constant:8],
        [centerBarView.trailingAnchor
            constraintEqualToAnchor:self.deleteButton.leadingAnchor constant:-8],
        [centerBarView.centerYAnchor
            constraintEqualToAnchor:self.sendButton.centerYAnchor],
        [centerBarView.heightAnchor constraintEqualToConstant:44],
    ]];
    // --- END: Apply manual constraints for chat input bar geometry ---

    // Remove rootStack layout constraints and priorities, but keep for state logic if needed
    [self setupConstraints]; // REMOVE rootStack constraints
    //[self setupContentPriorities]; // REMOVE rootStack priorities
    
    // Button padding
    self.sendButton.contentEdgeInsets = UIEdgeInsetsMake(4, 4, 4, 4);
    self.deleteButton.contentEdgeInsets = UIEdgeInsetsMake(4, 4, 4, 4);
    self.playPauseButton.contentEdgeInsets = UIEdgeInsetsMake(4, 4, 4, 4);
    
    // RTL support
    self.semanticContentAttribute = GM.setSemantic;
    self.blurView.semanticContentAttribute = GM.setSemantic;
    centerStack.semanticContentAttribute = GM.setSemantic;
 
    //glass.userInteractionEnabled = NO;
    //centerBarView.userInteractionEnabled = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];
}


- (void)setDeleteButtonVisible:(BOOL)visible animated:(BOOL)animated {
    void (^changes)(void) = ^{
        self.deleteButton.alpha = visible ? 1.0 : 0.0;
        self.deleteButton.userInteractionEnabled = visible;
    };

    if (animated) {
        [UIView animateWithDuration:0.18
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)setupContentPriorities {
    // Buttons: Fixed size, high priority for fixed size
    NSArray<UIButton *> *allButtons = @[self.sendButton, self.deleteButton, self.playPauseButton];
    for (UIButton *button in allButtons) {
        // Set fixed size
        NSLayoutConstraint *widthConstraint = [button.widthAnchor constraintEqualToConstant:44.0];
        widthConstraint.priority = UILayoutPriorityRequired;
        widthConstraint.active = YES;
        
        NSLayoutConstraint *heightConstraint = [button.heightAnchor constraintEqualToConstant:44.0];
        heightConstraint.priority = UILayoutPriorityRequired;
        heightConstraint.active = YES;
        
        // High hugging priority = doesn't want to expand
        [button setContentHuggingPriority:UILayoutPriorityRequired
                                  forAxis:UILayoutConstraintAxisHorizontal];
        
        // High compression resistance = doesn't want to shrink
        [button setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
    }
    
    // Time label: Hugs content tightly
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    
    // CRITICAL: Waveform should have LOW hugging (wants to expand)
    // and LOW compression resistance (can shrink if needed)
 
    // The center stack (containing play button + waveform stack)
    // should have LOW hugging to expand between send and delete buttons
     
    
    // Fixed heights
    [self.waveformView.heightAnchor constraintEqualToConstant:20].active = YES;
    [self.timeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:16].active = YES;
    
    // Minimum width for waveform - but with low priority so it can shrink if needed
    NSLayoutConstraint *minWidth = [self.waveformView.widthAnchor constraintGreaterThanOrEqualToConstant:80];
    minWidth.priority = UILayoutPriorityDefaultLow;
    minWidth.active = YES;
}

- (void)setupConstraints {
    // BlurView constraints - fills entire view
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
    ]];
   
    
    // Main view height constraint
    NSLayoutConstraint *heightConstraint = [self.heightAnchor constraintEqualToConstant:56];
    heightConstraint.priority = UILayoutPriorityRequired;
    heightConstraint.active = YES;
}



- (void)playPauseTouchDown
{
    [UIView animateWithDuration:0.12 animations:^{
        self.playPauseButton.transform =
            CGAffineTransformMakeScale(0.88, 0.88);
    }];
}

- (void)playPauseTouchUp
{
    [UIView animateWithDuration:0.12 animations:^{
        self.playPauseButton.transform = CGAffineTransformIdentity;
    }];
}



- (UIButton *)iconButton:(NSString *)systemName {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:systemName]
        forState:UIControlStateNormal];
    b.tintColor = AppPrimaryTextClr;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [b.heightAnchor constraintEqualToConstant:44.0].active = YES;
    UIButtonConfiguration *config;
    
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    }
    
    b.clipsToBounds = YES;
    b.layer.cornerRadius = 22;
    b.backgroundColor = AppClearClr;
    if(![systemName isEqualToString:@"play.fill"])
    b.configuration = config;
    return b;
}





- (void)onSend {
    [self.delegate recordingBarDidTapSend];
}

- (void)onCancel {
    [self.delegate recordingBarDidTapCancel];
}

- (void)onPlayPause
{
    if (self.state == PPRecordingBarStateLocked) {
        // 🔒 LOCK MODE → finish recording & go preview
        if ([self.delegate respondsToSelector:@selector(recordingBarDidTapPlayFromLocked)]) {
            [self.delegate recordingBarDidTapPlayFromLocked];
        }
        return;
    }

    // ▶️ PREVIEW MODE → normal playback toggle
    if ([self.delegate respondsToSelector:@selector(recordingBarDidTogglePlayback)]) {
        [self.delegate recordingBarDidTogglePlayback];
    }
}



#pragma mark - State Handling

- (void)setRecordingState:(PPRecordingBarState)state animated:(BOOL)animated {
    _state = state;

    void (^changes)(void) = ^{
        switch (state) {

            case PPRecordingBarStateHidden:
                self.alpha = 0;
                self.timeLabel.hidden = YES;
                [self stopHintPulse];
                break;

            case PPRecordingBarStateRecording:
                self.alpha = 1;   // ✅ REQUIRED
                self.sendButton.hidden = YES;
                self.deleteButton.hidden = YES;
                self.playPauseButton.hidden = YES;
                self.hintLabel.text = kLang(@"Slide to cancel");
                [self startHintPulse];
                self.timeLabel.alpha = 1.0;
                self.timeLabel.hidden = NO;
                self.waveformView.visualState = PPWaveformVisualStateRecording;

                break;

            case PPRecordingBarStateLocked:
                self.sendButton.alpha = 1;
                self.deleteButton.alpha = 1;
                self.playPauseButton.alpha = 1;
                self.alpha = 1;   // ✅ REQUIRED
                self.sendButton.hidden = NO;
                self.deleteButton.hidden = NO;
                self.playPauseButton.hidden = NO;
                self.hintLabel.text = kLang(@"Recording locked…");
                // 🔒→▶️ FORCE play icon
                   [self setPlaying:YES animated:YES];
                self.waveformView.visualState = PPWaveformVisualStateLocked;
                [self stopHintPulse];
                break;

            case PPRecordingBarStatePreview:
                self.alpha = 1;
                self.sendButton.hidden = NO;
                self.deleteButton.hidden = NO;
                self.playPauseButton.hidden = NO;

                self.sendButton.userInteractionEnabled = YES;
                self.deleteButton.userInteractionEnabled = YES;
                self.playPauseButton.userInteractionEnabled = YES;

                self.sendButton.alpha = 1;
                self.deleteButton.alpha = 1;
                self.playPauseButton.alpha = 1;

                self.hintLabel.text = @"";
                self.waveformView.visualState = PPWaveformVisualStatePreview;
                [self stopHintPulse];
                self.userInteractionEnabled = YES;
                [self setPlaying:NO animated:NO];
                break;
        }
        
        [self.waveformView setNeedsDisplay];

        
    };

    if (animated) {
        [UIView animateWithDuration:0.2 animations:changes];
    } else {
        changes();
    }
}

- (void)appendWaveformSample:(float)level {
    [self.waveformView addSample:level];
}

#pragma mark - Preview

- (void)prepareForPreview {
    [self.waveformView freeze];
    [self setRecordingState:PPRecordingBarStatePreview animated:YES];
    [self setPlaying:NO animated:NO];
}

#pragma mark - Reset

- (void)reset {
    self.timeLabel.text = @"00:00";
    [self.waveformView reset];
    [self setRecordingState:PPRecordingBarStateHidden animated:NO];
    [self setPlaying:NO animated:NO];
    self.timeLabel.hidden = YES;
}



// Subtle "slide to cancel" pulse animation for hintLabel
- (void)startHintPulse {
    if ([self.hintLabel.layer animationForKey:@"hintPulse"]) return;

    CGFloat dir =
        self.semanticContentAttribute == UISemanticContentAttributeForceRightToLeft
        ? 1 : -1;

    CAKeyframeAnimation *anim =
        [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.values = @[@0, @(dir * 6), @0];
    anim.duration = 1.4;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [self.hintLabel.layer addAnimation:anim forKey:@"hintPulse"];
}

- (void)stopHintPulse {
    [self.hintLabel.layer removeAnimationForKey:@"hintPulse"];
}


@end
