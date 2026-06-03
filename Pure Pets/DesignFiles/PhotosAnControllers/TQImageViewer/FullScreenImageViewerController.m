#import "FullScreenImageViewerController.h"
#import <AVFoundation/AVFoundation.h>

static NSString *PPFullScreenViewerLocalized(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    if ([value isKindOfClass:NSString.class] && value.length > 0 && ![value isEqualToString:key]) {
        return value;
    }
    return fallback ?: @"";
}

static CGRect PPFullScreenImageViewerAspectFitFrame(UIImage *image, CGRect bounds)
{
    if (!image || image.size.width <= 0.0 || image.size.height <= 0.0 ||
        bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
        return bounds;
    }

    CGFloat scale = MIN(bounds.size.width / image.size.width,
                        bounds.size.height / image.size.height);
    CGSize size = CGSizeMake(floor(image.size.width * scale),
                             floor(image.size.height * scale));
    CGFloat originX = floor(CGRectGetMidX(bounds) - (size.width * 0.5));
    CGFloat originY = floor(CGRectGetMidY(bounds) - (size.height * 0.5));
    return CGRectMake(originX, originY, size.width, size.height);
}

@interface FullScreenImageViewerController ()

@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, weak, nullable) UIImageView *sourceImageView;
@property (nonatomic, weak, nullable) UIWindow *presentationWindow;
@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, strong) UIImageView *animatingImageView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong, nullable) UIButton *shareButton;
@property (nonatomic, assign) CGRect sourceFrameInWindow;
@property (nonatomic, assign) CGRect sourceContentsRect;
@property (nonatomic, assign) CGFloat sourceCornerRadius;
@property (nonatomic, assign) BOOL isTransitioning;
@property (nonatomic, assign) BOOL didFinishPresentation;

@end

#pragma mark - Premium Video Player

@interface PPPremiumVideoPlayerViewController ()

@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *videoContainerView;
@property (nonatomic, strong) UIView *topChromeView;
@property (nonatomic, strong) UIView *bottomChromeView;
@property (nonatomic, strong) CAGradientLayer *topGradientLayer;
@property (nonatomic, strong) CAGradientLayer *bottomGradientLayer;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator;
@property (nonatomic, strong, nullable) id timeObserverToken;
@property (nonatomic, assign) BOOL controlsHidden;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, assign) BOOL didInstallObservers;
@property (nonatomic, assign) BOOL playbackRequested;
@property (nonatomic, assign) BOOL isPanDismissing;

@end

@implementation PPPremiumVideoPlayerViewController

- (instancetype)initWithURL:(NSURL *)videoURL
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _videoURL = videoURL;
        _controlsHidden = NO;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.modalPresentationCapturesStatusBarAppearance = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.view.accessibilityViewIsModal = YES;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.videoURL];
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;

    self.videoContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.videoContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.videoContainerView.backgroundColor = UIColor.blackColor;
    self.videoContainerView.clipsToBounds = YES;
    [self.view addSubview:self.videoContainerView];

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.backgroundColor = UIColor.blackColor.CGColor;
    [self.videoContainerView.layer addSublayer:self.playerLayer];

    [self pp_setupChrome];
    [self pp_applySemanticContentAttribute];
    [self pp_installGestures];
    [self pp_installObservers];
    [self pp_updatePlayPauseIcon];
    [self pp_updateMuteIcon];

    [NSLayoutConstraint activateConstraints:@[
        [self.videoContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.videoContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.videoContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.videoContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.topChromeView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topChromeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topChromeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topChromeView.heightAnchor constraintEqualToConstant:124.0],

        [self.bottomChromeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomChromeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomChromeView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomChromeView.heightAnchor constraintEqualToConstant:170.0],

        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:18.0],
        [self.closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [self.closeButton.widthAnchor constraintEqualToConstant:44.0],
        [self.closeButton.heightAnchor constraintEqualToConstant:44.0],

        [self.playPauseButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:18.0],
        [self.playPauseButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18.0],
        [self.playPauseButton.widthAnchor constraintEqualToConstant:54.0],
        [self.playPauseButton.heightAnchor constraintEqualToConstant:54.0],

        [self.muteButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-18.0],
        [self.muteButton.centerYAnchor constraintEqualToAnchor:self.playPauseButton.centerYAnchor],
        [self.muteButton.widthAnchor constraintEqualToConstant:44.0],
        [self.muteButton.heightAnchor constraintEqualToConstant:44.0],

        [self.elapsedLabel.leadingAnchor constraintEqualToAnchor:self.playPauseButton.trailingAnchor constant:12.0],
        [self.elapsedLabel.centerYAnchor constraintEqualToAnchor:self.playPauseButton.centerYAnchor],
        [self.elapsedLabel.widthAnchor constraintGreaterThanOrEqualToConstant:42.0],

        [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.muteButton.leadingAnchor constant:-12.0],
        [self.durationLabel.centerYAnchor constraintEqualToAnchor:self.playPauseButton.centerYAnchor],
        [self.durationLabel.widthAnchor constraintGreaterThanOrEqualToConstant:42.0],

        [self.progressSlider.leadingAnchor constraintEqualToAnchor:self.elapsedLabel.trailingAnchor constant:10.0],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:self.durationLabel.leadingAnchor constant:-10.0],
        [self.progressSlider.centerYAnchor constraintEqualToAnchor:self.playPauseButton.centerYAnchor],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.playerLayer.frame = self.videoContainerView.bounds;
    self.topGradientLayer.frame = self.topChromeView.bounds;
    self.bottomGradientLayer.frame = self.bottomChromeView.bounds;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.feedbackGenerator prepare];
    [self pp_runEntranceIfNeeded];
    [self.loadingIndicator startAnimating];
    self.playbackRequested = YES;
    [self.player play];
    [self pp_updatePlayPauseIcon];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.playbackRequested = NO;
    [self.player pause];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

- (void)pp_setupChrome
{
    self.topChromeView = [[UIView alloc] initWithFrame:CGRectZero];
    self.topChromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topChromeView.userInteractionEnabled = NO;
    [self.view addSubview:self.topChromeView];

    self.bottomChromeView = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomChromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomChromeView.userInteractionEnabled = NO;
    [self.view addSubview:self.bottomChromeView];

    self.topGradientLayer = [CAGradientLayer layer];
    self.topGradientLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.66].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    self.topGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.topGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    [self.topChromeView.layer addSublayer:self.topGradientLayer];

    self.bottomGradientLayer = [CAGradientLayer layer];
    self.bottomGradientLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.78].CGColor
    ];
    self.bottomGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bottomGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    [self.bottomChromeView.layer addSublayer:self.bottomGradientLayer];

    self.closeButton = [self pp_chromeButtonWithSymbol:@"xmark"
                                    accessibilityLabel:PPFullScreenViewerLocalized(@"video_player_close", @"Close video")];
    [self.closeButton addTarget:self action:@selector(pp_closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];

    self.playPauseButton = [self pp_chromeButtonWithSymbol:@"pause.fill"
                                        accessibilityLabel:PPFullScreenViewerLocalized(@"video_player_play_pause", @"Play or pause video")];
    self.playPauseButton.layer.cornerRadius = 27.0;
    [self.playPauseButton addTarget:self action:@selector(pp_playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playPauseButton];

    self.muteButton = [self pp_chromeButtonWithSymbol:@"speaker.wave.2.fill"
                                   accessibilityLabel:PPFullScreenViewerLocalized(@"video_player_mute", @"Mute video")];
    [self.muteButton addTarget:self action:@selector(pp_muteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.muteButton];

    self.elapsedLabel = [self pp_timeLabelWithText:@"0:00"];
    [self.view addSubview:self.elapsedLabel];

    self.durationLabel = [self pp_timeLabelWithText:@"0:00"];
    [self.view addSubview:self.durationLabel];

    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressSlider.minimumValue = 0.0;
    self.progressSlider.maximumValue = 1.0;
    self.progressSlider.value = 0.0;
    self.progressSlider.minimumTrackTintColor = UIColor.whiteColor;
    self.progressSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.24];
    self.progressSlider.thumbTintColor = UIColor.whiteColor;
    [self.progressSlider addTarget:self action:@selector(pp_sliderBegan:) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(pp_sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(pp_sliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.view addSubview:self.progressSlider];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.color = UIColor.whiteColor;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];

    self.feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
}

- (void)pp_applySemanticContentAttribute
{
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
    self.videoContainerView.semanticContentAttribute = semantic;
    self.topChromeView.semanticContentAttribute = semantic;
    self.bottomChromeView.semanticContentAttribute = semantic;
    self.closeButton.semanticContentAttribute = semantic;
    self.playPauseButton.semanticContentAttribute = semantic;
    self.muteButton.semanticContentAttribute = semantic;
    self.elapsedLabel.semanticContentAttribute = semantic;
    self.durationLabel.semanticContentAttribute = semantic;
    self.progressSlider.semanticContentAttribute = semantic;
    self.loadingIndicator.semanticContentAttribute = semantic;
}

- (UIButton *)pp_chromeButtonWithSymbol:(NSString *)symbolName accessibilityLabel:(NSString *)accessibilityLabel
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.38];
    button.layer.cornerRadius = 22.0;
    button.layer.masksToBounds = YES;
    button.accessibilityLabel = accessibilityLabel;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UIImageSymbolConfiguration *config =
    [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:symbolName withConfiguration:config] forState:UIControlStateNormal];
    return button;
}

- (UILabel *)pp_timeLabelWithText:(NSString *)text
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont monospacedDigitSystemFontOfSize:12.5 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    label.text = text;
    label.textAlignment = NSTextAlignmentNatural;
    label.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)pp_installGestures
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_toggleChrome)];
    [self.videoContainerView addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleDismissPan:)];
    [self.videoContainerView addGestureRecognizer:pan];
}

- (void)pp_installObservers
{
    if (self.didInstallObservers) return;
    self.didInstallObservers = YES;
    [self.player.currentItem addObserver:self
                              forKeyPath:@"status"
                                 options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                 context:NULL];
    [self.player.currentItem addObserver:self
                              forKeyPath:@"duration"
                                 options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                 context:NULL];
    [self.player addObserver:self
                  forKeyPath:@"timeControlStatus"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_playerDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];

    __weak typeof(self) weakSelf = self;
    self.timeObserverToken =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.25, NSEC_PER_SEC)
                                              queue:dispatch_get_main_queue()
                                         usingBlock:^(CMTime time) {
        [weakSelf pp_updateProgressForTime:time];
    }];
}

- (void)pp_removeObservers
{
    if (self.timeObserverToken) {
        [self.player removeTimeObserver:self.timeObserverToken];
        self.timeObserverToken = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.didInstallObservers) {
        @try {
            [self.player.currentItem removeObserver:self forKeyPath:@"status"];
            [self.player.currentItem removeObserver:self forKeyPath:@"duration"];
            [self.player removeObserver:self forKeyPath:@"timeControlStatus"];
        } @catch (__unused NSException *exception) {
        }
        self.didInstallObservers = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (object == self.player) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_updatePlayPauseIcon];
        });
        return;
    }
    if (object != self.player.currentItem) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_refreshItemState];
    });
}

- (void)pp_refreshItemState
{
    AVPlayerItem *item = self.player.currentItem;
    if (item.status == AVPlayerItemStatusReadyToPlay) {
        [self.loadingIndicator stopAnimating];
    } else if (item.status == AVPlayerItemStatusFailed) {
        [self.loadingIndicator stopAnimating];
    } else {
        [self.loadingIndicator startAnimating];
    }
    NSTimeInterval duration = [self pp_secondsForTime:item.duration];
    if (duration > 0.0) {
        self.durationLabel.text = [self pp_formattedTime:duration];
    }
}

- (void)pp_updateProgressForTime:(CMTime)time
{
    if (self.isSeeking) return;
    NSTimeInterval elapsed = [self pp_secondsForTime:time];
    NSTimeInterval duration = [self pp_secondsForTime:self.player.currentItem.duration];
    self.elapsedLabel.text = [self pp_formattedTime:elapsed];
    if (duration > 0.0) {
        self.durationLabel.text = [self pp_formattedTime:duration];
        self.progressSlider.value = (float)MIN(MAX(elapsed / duration, 0.0), 1.0);
    }
}

- (NSTimeInterval)pp_secondsForTime:(CMTime)time
{
    if (!CMTIME_IS_NUMERIC(time) || CMTIME_IS_INDEFINITE(time)) {
        return 0.0;
    }
    Float64 seconds = CMTimeGetSeconds(time);
    return isfinite(seconds) ? MAX(seconds, 0.0) : 0.0;
}

- (NSString *)pp_formattedTime:(NSTimeInterval)seconds
{
    NSInteger total = (NSInteger)llround(MAX(seconds, 0.0));
    NSInteger minutes = total / 60;
    NSInteger remainder = total % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)remainder];
}

- (void)pp_runEntranceIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.view.alpha = 1.0;
        return;
    }
    self.videoContainerView.transform = CGAffineTransformMakeScale(0.985, 0.985);
    self.topChromeView.alpha = 0.0;
    self.bottomChromeView.alpha = 0.0;
    self.closeButton.alpha = 0.0;
    self.playPauseButton.alpha = 0.0;
    self.muteButton.alpha = 0.0;
    self.progressSlider.alpha = 0.0;
    self.elapsedLabel.alpha = 0.0;
    self.durationLabel.alpha = 0.0;

    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.videoContainerView.transform = CGAffineTransformIdentity;
        self.topChromeView.alpha = 1.0;
        self.bottomChromeView.alpha = 1.0;
        self.closeButton.alpha = 1.0;
        self.playPauseButton.alpha = 1.0;
        self.muteButton.alpha = 1.0;
        self.progressSlider.alpha = 1.0;
        self.elapsedLabel.alpha = 1.0;
        self.durationLabel.alpha = 1.0;
    } completion:nil];
}

- (void)pp_toggleChrome
{
    self.controlsHidden = !self.controlsHidden;
    CGFloat alpha = self.controlsHidden ? 0.0 : 1.0;
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.08 : 0.22;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.topChromeView.alpha = alpha;
        self.bottomChromeView.alpha = alpha;
        self.closeButton.alpha = alpha;
        self.playPauseButton.alpha = alpha;
        self.muteButton.alpha = alpha;
        self.progressSlider.alpha = alpha;
        self.elapsedLabel.alpha = alpha;
        self.durationLabel.alpha = alpha;
    } completion:nil];
}

- (void)pp_handleDismissPan:(UIPanGestureRecognizer *)gesture
{
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];
    CGFloat downwardOffset = MAX(0.0, translation.y);
    CGFloat progress = MIN(downwardOffset / MAX(CGRectGetHeight(self.view.bounds), 1.0), 1.0);

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.isPanDismissing = YES;
            [self.feedbackGenerator prepare];
            break;
        case UIGestureRecognizerStateChanged:
            [self pp_applyDismissContentTransform:CGAffineTransformMakeTranslation(0.0, downwardOffset)
                                            alpha:1.0 - (progress * 0.55)];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            BOOL shouldDismiss = downwardOffset > 120.0 || velocity.y > 900.0;
            if (shouldDismiss) {
                [self.feedbackGenerator impactOccurred];
                [self pp_dismissSlidingDownAnimated:YES];
            } else {
                [self pp_restoreFromDismissPan];
            }
            break;
        }
        default:
            break;
    }
}

- (void)pp_restoreFromDismissPan
{
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.08 : 0.32;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self pp_applyDismissContentTransform:CGAffineTransformIdentity alpha:1.0];
    } completion:^(__unused BOOL finished) {
        self.isPanDismissing = NO;
    }];
}

- (void)pp_applyDismissContentTransform:(CGAffineTransform)transform alpha:(CGFloat)alpha
{
    self.videoContainerView.transform = transform;
    self.videoContainerView.alpha = alpha;

    NSMutableArray<UIView *> *chromeViews = [NSMutableArray array];
    if (self.topChromeView) [chromeViews addObject:self.topChromeView];
    if (self.bottomChromeView) [chromeViews addObject:self.bottomChromeView];
    if (self.closeButton) [chromeViews addObject:self.closeButton];
    if (self.playPauseButton) [chromeViews addObject:self.playPauseButton];
    if (self.muteButton) [chromeViews addObject:self.muteButton];
    if (self.progressSlider) [chromeViews addObject:self.progressSlider];
    if (self.elapsedLabel) [chromeViews addObject:self.elapsedLabel];
    if (self.durationLabel) [chromeViews addObject:self.durationLabel];
    if (self.loadingIndicator) [chromeViews addObject:self.loadingIndicator];

    CGFloat chromeAlpha = self.controlsHidden ? 0.0 : alpha;
    for (UIView *view in chromeViews) {
        view.transform = transform;
        view.alpha = chromeAlpha;
    }
}

- (void)pp_playPauseTapped
{
    [self.feedbackGenerator impactOccurred];
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        self.playbackRequested = NO;
        [self.player pause];
    } else {
        if ([self pp_secondsForTime:self.player.currentTime] >= [self pp_secondsForTime:self.player.currentItem.duration]) {
            [self.player seekToTime:kCMTimeZero];
        }
        self.playbackRequested = YES;
        [self.player play];
    }
    [self pp_updatePlayPauseIcon];
}

- (void)pp_muteTapped
{
    [self.feedbackGenerator impactOccurred];
    self.player.muted = !self.player.muted;
    [self pp_updateMuteIcon];
}

- (void)pp_closeTapped
{
    [self.feedbackGenerator impactOccurred];
    [self pp_dismissSlidingDownAnimated:YES];
}

- (void)pp_sliderBegan:(UISlider *)slider
{
    self.isSeeking = YES;
}

- (void)pp_sliderChanged:(UISlider *)slider
{
    NSTimeInterval duration = [self pp_secondsForTime:self.player.currentItem.duration];
    NSTimeInterval target = duration * slider.value;
    self.elapsedLabel.text = [self pp_formattedTime:target];
}

- (void)pp_sliderEnded:(UISlider *)slider
{
    NSTimeInterval duration = [self pp_secondsForTime:self.player.currentItem.duration];
    NSTimeInterval target = duration * slider.value;
    CMTime time = CMTimeMakeWithSeconds(target, NSEC_PER_SEC);
    __weak typeof(self) weakSelf = self;
    [self.player seekToTime:time
            toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero
          completionHandler:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isSeeking = NO;
        });
    }];
}

- (void)pp_playerDidEnd:(NSNotification *)notification
{
    self.playbackRequested = NO;
    [self.player seekToTime:kCMTimeZero];
    [self.player pause];
    [self pp_updatePlayPauseIcon];
}

- (void)pp_updatePlayPauseIcon
{
    BOOL showsPause = self.playbackRequested || self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
    NSString *symbol = showsPause ? @"pause.fill" : @"play.fill";
    UIImageSymbolConfiguration *config =
    [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold];
    [self.playPauseButton setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];
}

- (void)pp_dismissSlidingDownAnimated:(BOOL)animated
{
    self.playbackRequested = NO;
    [self.player pause];
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }

    CGFloat height = MAX(CGRectGetHeight(self.view.bounds), 1.0);
    [UIView animateWithDuration:0.28
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self pp_applyDismissContentTransform:CGAffineTransformMakeTranslation(0.0, height) alpha:0.0];
    } completion:^(__unused BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:^{
            [self pp_applyDismissContentTransform:CGAffineTransformIdentity alpha:1.0];
            self.isPanDismissing = NO;
        }];
    }];
}

- (void)pp_updateMuteIcon
{
    NSString *symbol = self.player.isMuted ? @"speaker.slash.fill" : @"speaker.wave.2.fill";
    UIImageSymbolConfiguration *config =
    [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
    [self.muteButton setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];
}

- (void)dealloc
{
    [self.player pause];
    [self pp_removeObservers];
    self.playerLayer.player = nil;
}

@end

@implementation FullScreenImageViewerController

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _image = image;
        _sourceContentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        if (@available(iOS 13.0, *)) {
            self.modalInPresentation = YES;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;
    self.view.clipsToBounds = YES;
    self.view.accessibilityViewIsModal = YES;

    self.dimmingView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.dimmingView.backgroundColor = UIColor.blackColor;
    self.dimmingView.alpha = 0.0;
    [self.view addSubview:self.dimmingView];

    self.animatingImageView = [[UIImageView alloc] initWithImage:self.image];
    self.animatingImageView.clipsToBounds = YES;
    self.animatingImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.animatingImageView.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.animatingImageView.layer.contentsRect = self.sourceContentsRect;
    self.animatingImageView.layer.masksToBounds = YES;
    [self.view addSubview:self.animatingImageView];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.closeButton.tintColor = UIColor.whiteColor;
    self.closeButton.alpha = 0.0;
    self.closeButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.34];
    self.closeButton.layer.cornerRadius = 20.0;
    self.closeButton.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                       weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:@"xmark" withConfiguration:config];
        [self.closeButton setImage:image forState:UIControlStateNormal];
    }
    [self.closeButton addTarget:self
                         action:@selector(dismissFullScreen)
               forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];

    if (self.shareHandler) {
        UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
        shareButton.translatesAutoresizingMaskIntoConstraints = NO;
        shareButton.tintColor = UIColor.whiteColor;
        shareButton.alpha = 0.0;
        shareButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.34];
        shareButton.layer.cornerRadius = 20.0;
        shareButton.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                           weight:UIImageSymbolWeightSemibold];
            UIImage *image = [UIImage systemImageNamed:@"square.and.arrow.up"
                                      withConfiguration:config];
            [shareButton setImage:image forState:UIControlStateNormal];
        }
        [shareButton addTarget:self
                        action:@selector(pp_shareTapped)
              forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:shareButton];
        self.shareButton = shareButton;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:18.0],
        [self.closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [self.closeButton.widthAnchor constraintEqualToConstant:40.0],
        [self.closeButton.heightAnchor constraintEqualToConstant:40.0],
    ]];

    if (self.shareButton) {
        [NSLayoutConstraint activateConstraints:@[
            [self.shareButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-18.0],
            [self.shareButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
            [self.shareButton.widthAnchor constraintEqualToConstant:40.0],
            [self.shareButton.heightAnchor constraintEqualToConstant:40.0],
        ]];
    }
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

- (void)presentFullScreenFromImageView:(UIImageView *)sourceImageView
{
    if (self.isTransitioning || !sourceImageView) {
        return;
    }

    UIImage *resolvedImage = self.image ?: sourceImageView.image;
    if (!resolvedImage) {
        return;
    }
    self.image = resolvedImage;
    self.sourceImageView = sourceImageView;
    self.presentationWindow = sourceImageView.window ?: UIApplication.sharedApplication.keyWindow;
    if (!self.presentationWindow) {
        return;
    }

    self.sourceFrameInWindow = [sourceImageView convertRect:sourceImageView.bounds
                                                     toView:self.presentationWindow];
    if (CGRectIsEmpty(self.sourceFrameInWindow)) {
        return;
    }

    self.sourceCornerRadius = sourceImageView.layer.cornerRadius;
    self.sourceContentsRect = sourceImageView.layer.contentsRect;
    if (CGRectIsEmpty(self.sourceContentsRect)) {
        self.sourceContentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
    }

    UIViewController *presenter = [self pp_topViewControllerFromWindow:self.presentationWindow];
    if (!presenter) {
        return;
    }

    self.isTransitioning = YES;
    [presenter presentViewController:self
                            animated:NO
                          completion:^{
        [self pp_runPresentationAnimation];
    }];
}

- (void)dismissFullScreen
{
    if (self.isTransitioning || !self.didFinishPresentation) {
        return;
    }

    self.isTransitioning = YES;
    self.view.userInteractionEnabled = NO;

    CGRect targetFrame = self.sourceFrameInWindow;
    UIImageView *sourceImageView = self.sourceImageView;
    if (sourceImageView.window) {
        targetFrame = [sourceImageView convertRect:sourceImageView.bounds
                                            toView:self.view];
    }
    if (CGRectIsEmpty(targetFrame)) {
        targetFrame = self.sourceFrameInWindow;
    }

    sourceImageView.hidden = YES;
    self.animatingImageView.layer.contentsGravity = kCAGravityResizeAspectFill;

    CABasicAnimation *contentsAnimation =
    [CABasicAnimation animationWithKeyPath:@"contentsRect"];
    contentsAnimation.fromValue = [NSValue valueWithCGRect:self.animatingImageView.layer.contentsRect];
    contentsAnimation.toValue = [NSValue valueWithCGRect:self.sourceContentsRect];
    contentsAnimation.duration = UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.34;
    contentsAnimation.timingFunction =
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    self.animatingImageView.layer.contentsRect = self.sourceContentsRect;
    [self.animatingImageView.layer addAnimation:contentsAnimation
                                         forKey:@"pp_fullscreen_contents_dismiss"];

    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.34;
    UIViewPropertyAnimator *animator =
    [[UIViewPropertyAnimator alloc] initWithDuration:duration
                                        dampingRatio:0.85
                                          animations:^{
        self.dimmingView.alpha = 0.0;
        self.closeButton.alpha = 0.0;
        self.shareButton.alpha = 0.0;
        self.animatingImageView.frame = targetFrame;
        self.animatingImageView.layer.cornerRadius = self.sourceCornerRadius;
    }];

    __weak typeof(self) weakSelf = self;
    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        sourceImageView.hidden = NO;
        [self.animatingImageView removeFromSuperview];
        [self dismissViewControllerAnimated:NO completion:^{
            self.isTransitioning = NO;
            if (self.dismissalCompletion) {
                self.dismissalCompletion();
            }
        }];
    }];
    [animator startAnimation];
}

- (void)pp_runPresentationAnimation
{
    [self.view layoutIfNeeded];
    self.view.userInteractionEnabled = NO;

    self.sourceImageView.hidden = YES;

    self.animatingImageView.image = self.image;
    self.animatingImageView.frame = self.sourceFrameInWindow;
    self.animatingImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.animatingImageView.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.animatingImageView.layer.contentsRect = self.sourceContentsRect;
    self.animatingImageView.layer.cornerRadius = self.sourceCornerRadius;

    CGRect targetFrame = PPFullScreenImageViewerAspectFitFrame(self.image, self.view.bounds);

    CABasicAnimation *contentsAnimation =
    [CABasicAnimation animationWithKeyPath:@"contentsRect"];
    contentsAnimation.fromValue = [NSValue valueWithCGRect:self.sourceContentsRect];
    contentsAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0.0, 0.0, 1.0, 1.0)];
    contentsAnimation.duration = UIAccessibilityIsReduceMotionEnabled() ? 0.18 : 0.42;
    contentsAnimation.timingFunction =
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    self.animatingImageView.layer.contentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
    [self.animatingImageView.layer addAnimation:contentsAnimation
                                         forKey:@"pp_fullscreen_contents_present"];

    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.18 : 0.42;
    UIViewPropertyAnimator *animator =
    [[UIViewPropertyAnimator alloc] initWithDuration:duration
                                        dampingRatio:0.85
                                          animations:^{
        self.dimmingView.alpha = 1.0;
        self.animatingImageView.frame = targetFrame;
        self.animatingImageView.layer.cornerRadius = 0.0;
    }];

    __weak typeof(self) weakSelf = self;
    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.didFinishPresentation = YES;
        self.isTransitioning = NO;
        self.view.userInteractionEnabled = YES;

        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.12 : 0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.closeButton.alpha = 1.0;
            self.shareButton.alpha = self.shareHandler ? 1.0 : 0.0;
        } completion:nil];
    }];
    [animator startAnimation];
}

- (void)pp_shareTapped
{
    if (self.shareHandler) {
        self.shareHandler(self);
    }
}

- (UIViewController *)pp_topViewControllerFromWindow:(UIWindow *)window
{
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }

    BOOL didAdvance = YES;
    while (didAdvance) {
        didAdvance = NO;
        if ([controller isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)controller).visibleViewController;
            if (visible) {
                controller = visible;
                didAdvance = YES;
            }
        } else if ([controller isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)controller).selectedViewController;
            if (selected) {
                controller = selected;
                didAdvance = YES;
            }
        }
    }
    return controller;
}

- (void)dealloc
{
    self.sourceImageView.hidden = NO;
}

@end
