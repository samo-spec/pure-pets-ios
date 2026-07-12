//
//  PPRecordingBarView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/01/2026.
//


#import "PPRecordingBarView.h"
#import "PPChatsFunc.h"

static BOOL PPRecordingBarIsDark(UITraitCollection *traitCollection)
{
    if (@available(iOS 13.0, *)) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static UIColor *PPRecordingBarPrimaryColor(void)
{
    return [PPChatsFunc chatNeutralAccentColor];
}

static UIColor *PPRecordingBarSurfaceColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPRecordingBarIsDark(traitCollection);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.105]
        : [UIColor colorWithRed:0.984 green:0.977 blue:0.958 alpha:0.96];
}

static UIColor *PPRecordingBarBorderColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPRecordingBarIsDark(traitCollection);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.13]
        : [UIColor.labelColor colorWithAlphaComponent:0.065];
}

static UIColor *PPRecordingBarMutedTextColor(UITraitCollection *traitCollection)
{
    return PPRecordingBarIsDark(traitCollection)
        ? [UIColor colorWithWhite:1.0 alpha:0.56]
        : UIColor.secondaryLabelColor;
}


@interface PPRecordingBarView ()

@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UIView *centerGlowView;
@property (nonatomic, strong) UIButton *centerBarView;
@property (nonatomic, strong) UIView *levelDotView;
@property (nonatomic, strong, readwrite) PPInsetLabel *timeLabel;
@property (nonatomic, strong, readwrite) UILabel *hintLabel;
@property (nonatomic, strong, readwrite) UIButton *sendButton;
@property (nonatomic, strong, readwrite) UIButton *deleteButton;
@property (nonatomic, strong, readwrite) UIButton *playPauseButton;

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) NSLayoutConstraint *barHeightConstraint;
@property (nonatomic, assign) CFTimeInterval lastLevelIndicatorUpdate;

- (void)pp_applyRecordingTheme;
- (void)pp_updateLiveLevelIndicator:(float)level;
- (void)pp_startLevelDotPulse;
- (void)pp_stopLevelDotPulse;

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

        if (!CGRectIsEmpty(self.centerBarView.bounds)) {
            self.centerBarView.layer.shadowPath =
                [UIBezierPath bezierPathWithRoundedRect:self.centerBarView.bounds
                                           cornerRadius:18.0].CGPath;
        }

        if (!CGRectIsEmpty(self.centerGlowView.bounds)) {
            self.centerGlowView.layer.shadowPath =
                [UIBezierPath bezierPathWithOvalInRect:self.centerGlowView.bounds].CGPath;
        }
	 }

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyRecordingTheme];
        }
    }
}

- (void)setPlaying:(BOOL)isPlaying animated:(BOOL)animated
{
    if (_isPlaying == isPlaying) return;
    _isPlaying = isPlaying;

        NSString *systemName = isPlaying ? @"pause.fill" : @"play.fill";
        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        UIImage *baseImage = [UIImage systemImageNamed:systemName];
        UIImage *image = [baseImage imageByApplyingSymbolConfiguration:symbolConfig] ?: baseImage;

        void (^applyPlayImage)(void) = ^{
            if (@available(iOS 15.0, *)) {
                UIButtonConfiguration *config = self.playPauseButton.configuration;
                if (config) {
                    config.image = image;
                    self.playPauseButton.configuration = config;
                    return;
                }
            }
            [self.playPauseButton setImage:image forState:UIControlStateNormal];
        };

	    if (!animated) {
            applyPlayImage();
	        return;
	    }

 
    [UIView transitionWithView:self.playPauseButton
	                      duration:0.18
	                       options:UIViewAnimationOptionTransitionCrossDissolve
	                    animations:^{
            applyPlayImage();
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
	    self.timeLabel.textColor = PPRecordingBarMutedTextColor(self.traitCollection);
	    self.timeLabel.text = @"00:00";
	    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
	    self.timeLabel.textAlignment = NSTextAlignmentCenter;
	    self.timeLabel.textInsets = UIEdgeInsetsMake(4, 0, 4, 0);

	    // Setup hintLabel (if you're using it)
	    self.hintLabel = [[UILabel alloc] init];
	    self.hintLabel.font = [GM fontWithSize:13];
	    self.hintLabel.textColor = PPRecordingBarMutedTextColor(self.traitCollection);
	    self.hintLabel.text = kLang(@"Slide to cancel");
	    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
	    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    
    // Setup waveformView
	    self.waveformView = [[PPWaveformView alloc] init];
	    self.waveformView.translatesAutoresizingMaskIntoConstraints = NO;
	    self.waveformView.activeColor = PPRecordingBarPrimaryColor();
	    self.waveformView.accentColor = PPRecordingBarPrimaryColor();
	    self.waveformView.inactiveColor = PPRecordingBarMutedTextColor(self.traitCollection);
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

        self.levelDotView = [[UIView alloc] init];
        self.levelDotView.translatesAutoresizingMaskIntoConstraints = NO;
        self.levelDotView.userInteractionEnabled = NO;
        self.levelDotView.layer.cornerRadius = 4.0;
        self.levelDotView.hidden = YES;
        self.levelDotView.alpha = 0.0;
        [NSLayoutConstraint activateConstraints:@[
            [self.levelDotView.widthAnchor constraintEqualToConstant:8.0],
            [self.levelDotView.heightAnchor constraintEqualToConstant:8.0],
        ]];
 

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
        self.centerBarView = centerBarView;
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
            self.levelDotView,
	        self.waveformView,
	        self.timeLabel,
	    ]];
	    centerStack.axis = UILayoutConstraintAxisHorizontal;
	    centerStack.alignment = UIStackViewAlignmentCenter;
	    centerStack.spacing = 8;
	    centerStack.translatesAutoresizingMaskIntoConstraints = NO;
	    centerStack.distribution = UIStackViewDistributionFill;
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

        self.centerGlowView = [[UIView alloc] init];
        self.centerGlowView.translatesAutoresizingMaskIntoConstraints = NO;
        self.centerGlowView.userInteractionEnabled = NO;
        self.centerGlowView.alpha = 0.0;
        self.centerGlowView.layer.cornerRadius = 22.0;

	    // --- BEGIN: Add subviews directly for manual constraints ---
        [self.blurView addSubview:self.centerGlowView];
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

            [self.centerGlowView.leadingAnchor
                constraintEqualToAnchor:centerBarView.leadingAnchor constant:2.0],
            [self.centerGlowView.trailingAnchor
                constraintEqualToAnchor:centerBarView.trailingAnchor constant:-2.0],
            [self.centerGlowView.topAnchor
                constraintEqualToAnchor:centerBarView.topAnchor constant:2.0],
            [self.centerGlowView.bottomAnchor
                constraintEqualToAnchor:centerBarView.bottomAnchor constant:-2.0],
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
        [self pp_applyRecordingTheme];
 
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
    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.playPauseButton.transform =
            CGAffineTransformMakeScale(0.96, 0.96);
    } completion:nil];
}

- (void)playPauseTouchUp
{
    [UIView animateWithDuration:0.16
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.playPauseButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}



- (UIButton *)iconButton:(NSString *)systemName {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:systemName]
        forState:UIControlStateNormal];
    b.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [b.heightAnchor constraintEqualToConstant:44.0].active = YES;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config;
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            config = [UIButtonConfiguration plainButtonConfiguration];
            config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        }
        config.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
        b.configuration = config;
    }
    b.clipsToBounds = YES;
    b.layer.cornerRadius = 22;
    b.backgroundColor = AppClearClr;
    return b;
}

- (void)pp_configureIconButton:(UIButton *)button
                    systemName:(NSString *)systemName
                    foreground:(UIColor *)foreground
                    background:(UIColor *)background
                         border:(UIColor *)border
{
    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *image = [[UIImage systemImageNamed:systemName] imageByApplyingSymbolConfiguration:symbolConfig];

    BOOL usesSystemGlass = NO;
    if (@available(iOS 26.0, *)) {
        usesSystemGlass = YES;
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config;
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            config = [UIButtonConfiguration plainButtonConfiguration];
            config.background.backgroundColor = background;
            config.baseBackgroundColor = background;
            config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        }
        config.image = image;
        config.baseForegroundColor = foreground;
        config.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
        button.configuration = config;
    } else {
        [button setImage:image forState:UIControlStateNormal];
    }

    button.tintColor = foreground;
    button.imageView.tintColor = foreground;
    button.backgroundColor = usesSystemGlass ? UIColor.clearColor : background;
    button.layer.cornerRadius = 22.0;
    button.layer.borderWidth = usesSystemGlass ? 0.0 : (1.0 / UIScreen.mainScreen.scale);
    button.layer.borderColor = border.CGColor;
}

- (void)pp_applyRecordingTheme
{
    BOOL isDark = PPRecordingBarIsDark(self.traitCollection);
    UIColor *primaryColor = PPRecordingBarPrimaryColor();
    UIColor *surfaceColor = PPRecordingBarSurfaceColor(self.traitCollection);
    UIColor *borderColor = PPRecordingBarBorderColor(self.traitCollection);
    UIColor *mutedTextColor = PPRecordingBarMutedTextColor(self.traitCollection);
    UIColor *controlSurface = isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.11]
        : [UIColor.labelColor colorWithAlphaComponent:0.055];

    self.timeLabel.textColor = mutedTextColor;
    self.hintLabel.textColor = mutedTextColor;

    self.waveformView.activeColor = primaryColor;
    self.waveformView.accentColor = primaryColor;
    self.waveformView.inactiveColor = [mutedTextColor colorWithAlphaComponent:isDark ? 0.26 : 0.18];

    self.centerBarView.backgroundColor = surfaceColor;
    self.centerBarView.layer.cornerRadius = 18.0;
    self.centerBarView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.centerBarView.layer.borderColor = borderColor.CGColor;
    self.centerBarView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.centerBarView.layer.shadowOpacity = isDark ? 0.18 : 0.07;
    self.centerBarView.layer.shadowRadius = isDark ? 16.0 : 12.0;
    self.centerBarView.layer.shadowOffset = CGSizeMake(0.0, isDark ? 8.0 : 5.0);
    if (@available(iOS 13.0, *)) {
        self.centerBarView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.centerBarView.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.background.cornerRadius = 18.0;
        config.background.backgroundColor = surfaceColor;
        config.baseBackgroundColor = surfaceColor;
        self.centerBarView.configuration = config;
    }

    self.centerGlowView.backgroundColor = [primaryColor colorWithAlphaComponent:isDark ? 0.14 : 0.10];
    self.centerGlowView.layer.shadowColor = primaryColor.CGColor;
    self.centerGlowView.layer.shadowOpacity = isDark ? 0.24 : 0.16;
    self.centerGlowView.layer.shadowRadius = 18.0;
    self.centerGlowView.layer.shadowOffset = CGSizeZero;

    self.levelDotView.backgroundColor = primaryColor;
    self.levelDotView.layer.shadowColor = primaryColor.CGColor;
    self.levelDotView.layer.shadowOpacity = isDark ? 0.42 : 0.28;
    self.levelDotView.layer.shadowRadius = 8.0;
    self.levelDotView.layer.shadowOffset = CGSizeZero;

    [self pp_configureIconButton:self.sendButton
                      systemName:@"arrow.up"
                      foreground:(isDark ? [UIColor.blackColor colorWithAlphaComponent:0.86] : UIColor.whiteColor)
                      background:[primaryColor colorWithAlphaComponent:isDark ? 0.86 : 0.92]
                           border:[primaryColor colorWithAlphaComponent:0.28]];
    [self pp_configureIconButton:self.deleteButton
                      systemName:@"microphone.badge.xmark.fill"
                      foreground:UIColor.systemRedColor
                      background:[UIColor.systemRedColor colorWithAlphaComponent:isDark ? 0.18 : 0.105]
                           border:[UIColor.systemRedColor colorWithAlphaComponent:isDark ? 0.26 : 0.16]];
    [self pp_configureIconButton:self.playPauseButton
                      systemName:(self.isPlaying ? @"pause.fill" : @"play.fill")
                      foreground:primaryColor
                      background:controlSurface
                           border:borderColor];
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
                self.userInteractionEnabled = NO;
                self.centerGlowView.alpha = 0.0;
                self.levelDotView.alpha = 0.0;
                self.levelDotView.hidden = YES;
                self.timeLabel.hidden = YES;
                self.waveformView.visualState = PPWaveformVisualStatePreview;
                [self pp_stopLevelDotPulse];
                [self stopHintPulse];
                break;

	            case PPRecordingBarStateRecording:
	                self.alpha = 1;   // ✅ REQUIRED
                    self.userInteractionEnabled = YES;
	                self.sendButton.hidden = YES;
	                self.deleteButton.hidden = YES;
	                self.playPauseButton.hidden = YES;
                    self.levelDotView.hidden = NO;
                    self.levelDotView.alpha = 0.72;
                    self.centerGlowView.alpha = 0.82;
	                self.hintLabel.text = kLang(@"Slide to cancel");
	                [self startHintPulse];
                    [self pp_startLevelDotPulse];
	                self.timeLabel.alpha = 1.0;
	                self.timeLabel.hidden = NO;
	                self.waveformView.visualState = PPWaveformVisualStateRecording;

                break;

	            case PPRecordingBarStateLocked:
	                self.sendButton.alpha = 1;
	                self.deleteButton.alpha = 1;
	                self.playPauseButton.alpha = 1;
	                self.alpha = 1;   // ✅ REQUIRED
                    self.userInteractionEnabled = YES;
	                self.sendButton.hidden = NO;
	                self.deleteButton.hidden = NO;
	                self.playPauseButton.hidden = NO;
                    self.levelDotView.hidden = NO;
                    self.levelDotView.alpha = 0.88;
                    self.centerGlowView.alpha = 0.92;
	                self.hintLabel.text = kLang(@"Recording locked…");
	                // 🔒→▶️ FORCE play icon
	                   [self setPlaying:NO animated:YES];
	                self.waveformView.visualState = PPWaveformVisualStateLocked;
                    [self pp_startLevelDotPulse];
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
                    self.levelDotView.alpha = 0.0;
                    self.levelDotView.hidden = YES;
                    self.centerGlowView.alpha = 0.42;

	                self.hintLabel.text = @"";
	                self.waveformView.visualState = PPWaveformVisualStatePreview;
                    [self pp_stopLevelDotPulse];
	                [self stopHintPulse];
	                self.userInteractionEnabled = YES;
	                [self setPlaying:NO animated:NO];
                break;
        }
        
        [self.waveformView setNeedsDisplay];

        
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.24
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)appendWaveformSample:(float)level {
    [self.waveformView addSample:level];
    [self pp_updateLiveLevelIndicator:level];
}

#pragma mark - Preview

- (void)prepareForPreview {
    [self.waveformView freeze];
    [self setRecordingState:PPRecordingBarStatePreview animated:YES];
    [self setPlaying:NO animated:NO];
}

- (void)pp_updateLiveLevelIndicator:(float)level
{
    if (self.levelDotView.hidden || UIAccessibilityIsReduceMotionEnabled()) return;

    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastLevelIndicatorUpdate < 0.055) return;
    self.lastLevelIndicatorUpdate = now;

    CGFloat clamped = MIN(MAX(level, 0.0f), 1.0f);
    CGFloat scale = 0.86 + (clamped * 0.58);
    CGFloat alpha = 0.58 + (clamped * 0.34);
    CGFloat glowAlpha = 0.44 + (clamped * 0.36);

    [UIView animateWithDuration:0.11
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.levelDotView.transform = CGAffineTransformMakeScale(scale, scale);
        self.levelDotView.alpha = alpha;
        self.centerGlowView.alpha = glowAlpha;
    } completion:nil];
}

- (void)pp_startLevelDotPulse
{
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    if ([self.levelDotView.layer animationForKey:@"pp_level_dot_breathe"]) return;

    CABasicAnimation *scale =
        [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @0.92;
    scale.toValue = @1.18;
    scale.duration = 0.96;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction =
        [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];

    CABasicAnimation *opacity =
        [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @0.58;
    opacity.toValue = @0.92;
    opacity.duration = scale.duration;
    opacity.autoreverses = YES;
    opacity.repeatCount = HUGE_VALF;
    opacity.timingFunction = scale.timingFunction;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[scale, opacity];
    group.duration = scale.duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    [self.levelDotView.layer addAnimation:group forKey:@"pp_level_dot_breathe"];
}

- (void)pp_stopLevelDotPulse
{
    [self.levelDotView.layer removeAnimationForKey:@"pp_level_dot_breathe"];
    self.levelDotView.transform = CGAffineTransformIdentity;
}

#pragma mark - Reset

- (void)reset {
    self.timeLabel.text = @"00:00";
    [self.waveformView reset];
    [self setRecordingState:PPRecordingBarStateHidden animated:NO];
    [self setPlaying:NO animated:NO];
    self.timeLabel.hidden = YES;
    [self pp_stopLevelDotPulse];
}



// Subtle "slide to cancel" pulse animation for hintLabel
- (void)startHintPulse {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    if ([self.hintLabel.layer animationForKey:@"hintPulse"]) return;

    CGFloat dir =
        self.semanticContentAttribute == UISemanticContentAttributeForceRightToLeft
        ? 1 : -1;

    CAKeyframeAnimation *anim =
        [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.values = @[@0, @(dir * 8), @0];
    anim.keyTimes = @[@0.0, @0.42, @1.0];
    anim.duration = 1.05;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction =
        [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];

    [self.hintLabel.layer addAnimation:anim forKey:@"hintPulse"];
}

- (void)stopHintPulse {
    [self.hintLabel.layer removeAnimationForKey:@"hintPulse"];
}


@end
