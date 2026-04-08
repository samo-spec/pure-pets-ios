//
//  PPStoryPlayerViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStory.h"
#import "PPStoryPlayerViewController.h"
#import "PPStoriesManager.h"
#import "PPImageLoaderManager.h"
#import "Language.h"
#import "GM.h"
#import "PPModernAvatarRenderer.h"
#import <FirebaseAuth/FirebaseAuth.h>
#import <AVFoundation/AVFoundation.h>

static NSString * const PPStoryProgressPulseAnimationKey = @"pp.story.progress.pulse";
static NSString * const PPStoryProgressSlideAnimationKey = @"pp.story.progress.slide";
static void *PPStoryPlayerItemStatusContext = &PPStoryPlayerItemStatusContext;

@interface PPStoryPlayerViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSArray<PPStory *> *stories;
@property (nonatomic, assign) NSInteger currentStoryIndex;
@property (nonatomic, assign) NSInteger currentItemIndex;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *progressContainer;
@property (nonatomic, strong) NSMutableArray<UIProgressView *> *progressBars;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UIPanGestureRecognizer *dismissPanGesture;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *videoResumeTimesByItemKey;
@property (nonatomic, strong, nullable) AVPlayerItem *currentPlayerItem;
@property (nonatomic, strong, nullable) NSString *currentVideoItemKey;
@property (nonatomic, assign) NSTimeInterval currentVideoFallbackDuration;
@property (nonatomic, assign) BOOL hasStartedCurrentVideoPlayback;
@property (nonatomic, assign) BOOL isPlayerMuted;
@property (nonatomic, assign) NSInteger videoLoadToken;
@property (nonatomic, assign) BOOL isInteractiveDismissInProgress;
@property (nonatomic, assign) BOOL isPausedByLongPress;

@property (nonatomic, strong) id playerTimeObserver;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval imageStartTime;
@property (nonatomic, assign) NSTimeInterval imageDuration;

@property (nonatomic, strong) UIImageView *userAvatarView;
@property (nonatomic, strong) UILabel *userNameHeaderLabel;
@property (nonatomic, strong) UILabel *storyTimeLabel;
@property (nonatomic, assign) NSTimeInterval pausedImageElapsed;
@end

@implementation PPStoryPlayerViewController

- (instancetype)initWithStories:(NSArray<PPStory *> *)stories startIndex:(NSInteger)index {
    self = [super init];
    if (self) {
        _stories = stories ?: @[];
        _currentStoryIndex = MAX(index, 0);
        _currentItemIndex = 0;
        _progressBars = [NSMutableArray array];
        _videoResumeTimesByItemKey = [NSMutableDictionary dictionary];
        _isPlayerMuted = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.backgroundColor = UIColor.blackColor;
    [self.view addSubview:_imageView];

    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:nil];
    _playerLayer.frame = self.view.bounds;
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:_playerLayer];

    _progressContainer = [[UIView alloc] init];
    _progressContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_progressContainer];
    [NSLayoutConstraint activateConstraints:@[
        [_progressContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [_progressContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [_progressContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [_progressContainer.heightAnchor constraintEqualToConstant:4.0]
    ]];

    [self pp_setupControls];
    [self pp_setupGestures];
    [self loadStory];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.playerLayer.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_stopAllProgressAnimations];
    [self.timer invalidate];
    self.timer = nil;
    [self.player pause];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) {
        [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
    }
}

- (void)dealloc
{
    [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
}

#pragma mark - Setup

- (void)pp_setupControls
{
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 16.0;
    avatar.layer.borderWidth = 1.5;
    avatar.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
    avatar.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    avatar.tintColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    [self.view addSubview:avatar];
    self.userAvatarView = avatar;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    nameLabel.textColor = UIColor.whiteColor;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    nameLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:nameLabel];
    self.userNameHeaderLabel = nameLabel;

    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    timeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    timeLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:timeLabel];
    self.storyTimeLabel = timeLabel;

    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    dismissButton.tintColor = UIColor.whiteColor;
    dismissButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
    dismissButton.layer.cornerRadius = 18.0;
    [dismissButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    [dismissButton addTarget:self action:@selector(pp_dismissButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissButton];
    self.dismissButton = dismissButton;

    UIButton *muteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    muteButton.translatesAutoresizingMaskIntoConstraints = NO;
    muteButton.tintColor = UIColor.whiteColor;
    muteButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
    muteButton.layer.cornerRadius = 18.0;
    [muteButton addTarget:self action:@selector(pp_muteButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    muteButton.hidden = YES;
    [self.view addSubview:muteButton];
    self.muteButton = muteButton;
    [self pp_updateMuteButtonAppearance];

    [NSLayoutConstraint activateConstraints:@[
        [avatar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [avatar.topAnchor constraintEqualToAnchor:self.progressContainer.bottomAnchor constant:10.0],
        [avatar.widthAnchor constraintEqualToConstant:32.0],
        [avatar.heightAnchor constraintEqualToConstant:32.0],

        [nameLabel.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:8.0],
        [nameLabel.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:muteButton.leadingAnchor constant:-8.0],

        [timeLabel.leadingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor constant:6.0],
        [timeLabel.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],

        [dismissButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [dismissButton.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [dismissButton.widthAnchor constraintEqualToConstant:36.0],
        [dismissButton.heightAnchor constraintEqualToConstant:36.0],

        [muteButton.trailingAnchor constraintEqualToAnchor:dismissButton.leadingAnchor constant:-8.0],
        [muteButton.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [muteButton.widthAnchor constraintEqualToConstant:36.0],
        [muteButton.heightAnchor constraintEqualToConstant:36.0]
    ]];

    [nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                              forAxis:UILayoutConstraintAxisHorizontal];
    [timeLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)pp_setupGestures
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                           action:@selector(handleTap:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleLongPress:)];
    longPress.minimumPressDuration = 0.25;
    longPress.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:longPress];

    self.dismissPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleDismissPan:)];
    self.dismissPanGesture.delegate = self;
    self.dismissPanGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.dismissPanGesture];
}

#pragma mark - Story Flow

- (void)loadStory {
    [self.timer invalidate];
    self.timer = nil;
    [self pp_stopAllProgressAnimations];
    [self pp_stopCurrentPlaybackAndPreserveProgress:NO];

    [self.progressBars makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.progressBars removeAllObjects];

    if (self.currentStoryIndex >= self.stories.count) {
        [self pp_dismissViewerAnimated:YES];
        return;
    }

    PPStory *story = self.stories[self.currentStoryIndex];
    NSInteger count = story.items.count;
    if (count == 0) {
        [self nextStory];
        return;
    }

    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length > 0 && ![story.userID isEqualToString:currentUID]) {
        story.isSeen = YES;
        [[PPStoriesManager shared] recordViewForStoryOwnerID:story.userID completion:nil];
    }

    [self pp_updateUserInfoForCurrentStory];

    CGFloat totalW = self.view.bounds.size.width - 24.0;
    CGFloat spacing = 4.0;
    CGFloat barW = (totalW - (count - 1) * spacing) / MAX(count, 1);

    for (NSInteger i = 0; i < count; i++) {
        UIProgressView *pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        pv.progressTintColor = UIColor.whiteColor;
        pv.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.24];
        pv.translatesAutoresizingMaskIntoConstraints = NO;
        pv.progress = 0.0;
        pv.layer.cornerRadius = 2.0;
        pv.clipsToBounds = YES;
        [self.progressContainer addSubview:pv];
        [NSLayoutConstraint activateConstraints:@[
            [pv.leadingAnchor constraintEqualToAnchor:self.progressContainer.leadingAnchor constant:(barW + spacing) * i],
            [pv.widthAnchor constraintEqualToConstant:barW],
            [pv.topAnchor constraintEqualToAnchor:self.progressContainer.topAnchor],
            [pv.bottomAnchor constraintEqualToAnchor:self.progressContainer.bottomAnchor]
        ]];
        [self.progressBars addObject:pv];
    }

    [self pp_animateProgressContainerEntrance];
    self.currentItemIndex = 0;
    [self showItem];
}

- (void)showItem {
    [self.timer invalidate];
    self.timer = nil;
    [self pp_stopCurrentPlaybackAndPreserveProgress:YES];

    PPStory *story = self.stories[self.currentStoryIndex];
    if (self.currentItemIndex >= story.items.count) {
        [self nextStory];
        return;
    }

    for (NSInteger i = 0; i < self.progressBars.count; i++) {
        UIProgressView *bar = self.progressBars[i];
        bar.progress = (i < self.currentItemIndex) ? 1.0 : 0.0;
        [bar.layer removeAnimationForKey:PPStoryProgressPulseAnimationKey];
        [bar.layer removeAnimationForKey:PPStoryProgressSlideAnimationKey];
        bar.alpha = 1.0;
    }

    PPStoryItem *item = story.items[self.currentItemIndex];
    if (item.isVideo) {
        [self playVideoItem:item];
    } else {
        [self showImageItem:item];
    }
}

- (void)showImageItem:(PPStoryItem *)item {
    [self pp_stopCurrentPlaybackAndPreserveProgress:YES];
    self.playerLayer.player = nil;
    self.muteButton.hidden = YES;
    self.imageView.hidden = NO;

    UIImage *placeholder = [UIImage imageNamed:@"placeholder"];
    if (!placeholder) {
        placeholder = [UIImage systemImageNamed:@"photo"];
    }
    [[PPImageLoaderManager shared] setImageOnImageView:self.imageView
                                                    url:item.mediaURL.absoluteString
                                            placeholder:placeholder
                                        transitionStyle:PPImageTransitionStyleCrossDissolve
                                             complation:nil];

    NSTimeInterval duration = [self pp_safeDuration:item.duration fallback:5.0];
    self.imageDuration = duration;
    self.imageStartTime = CACurrentMediaTime();

    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }

    self.displayLink =
    [CADisplayLink displayLinkWithTarget:self
                                selector:@selector(pp_handleImageTick:)];

    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSRunLoopCommonModes];
}

- (void)pp_handleImageTick:(CADisplayLink *)link
{
    CFTimeInterval elapsed = CACurrentMediaTime() - self.imageStartTime;

    CGFloat progress =
        MIN(1.0, elapsed / MAX(0.2, self.imageDuration));

    if (self.currentItemIndex < self.progressBars.count) {
        UIProgressView *pv = self.progressBars[self.currentItemIndex];
        pv.progress = progress;
    }

    if (progress >= 1.0) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        [self nextItem];
    }
}


- (void)playVideoItem:(PPStoryItem *)storyItem {

    [self pp_stopCurrentPlaybackAndPreserveProgress:YES];
    self.imageView.hidden = YES;
    self.muteButton.hidden = NO;

    NSURL *url = storyItem.mediaURL;
    if (![url isKindOfClass:NSURL.class] || url.absoluteString.length == 0) {
        [self nextItem];
        return;
    }

    AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSArray *keys = @[@"playable", @"duration"];

    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
    self.currentPlayerItem = playerItem;
    self.currentVideoItemKey = [self pp_itemKeyForCurrentPositionWithItem:storyItem];
    self.currentVideoFallbackDuration =
        [self pp_safeDuration:storyItem.duration fallback:5.0];
    self.hasStartedCurrentVideoPlayback = NO;

    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:playerItem];
        self.player.automaticallyWaitsToMinimizeStalling = YES;
    } else {
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    }

    self.player.muted = self.isPlayerMuted;
    self.playerLayer.player = self.player;
    [self pp_updateMuteButtonAppearance];

    __weak typeof(self) weakSelf = self;

    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{

            AVKeyValueStatus playableStatus =
                [asset statusOfValueForKey:@"playable" error:nil];

            if (playableStatus == AVKeyValueStatusLoaded) {

                CMTime durationTime = asset.duration;
                NSTimeInterval duration = CMTimeGetSeconds(durationTime);

                if (!isfinite(duration) || duration <= 0.15) {
                    duration = weakSelf.currentVideoFallbackDuration;
                }

                weakSelf.currentVideoFallbackDuration = duration;

                [weakSelf pp_tryStartCurrentVideoPlaybackIfReady];

            } else {
                [weakSelf nextItem];
            }
        });
    }];

    [playerItem addObserver:self
                 forKeyPath:@"status"
                    options:NSKeyValueObservingOptionInitial |
                            NSKeyValueObservingOptionNew
                    context:PPStoryPlayerItemStatusContext];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_playerItemDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
}
- (void)pp_tryStartCurrentVideoPlaybackIfReady
{
    if (self.hasStartedCurrentVideoPlayback) {
        return;
    }
    if (!self.currentPlayerItem) {
        return;
    }
    if (self.currentPlayerItem.status == AVPlayerItemStatusFailed) {
        [self nextItem];
        return;
    }
    if (self.currentPlayerItem.status != AVPlayerItemStatusReadyToPlay) {
        return;
    }

    self.hasStartedCurrentVideoPlayback = YES;
    NSTimeInterval totalDuration = [self pp_safeDuration:CMTimeGetSeconds(self.currentPlayerItem.duration)
                                                fallback:self.currentVideoFallbackDuration];

    __weak typeof(self) weakSelf = self;

    if (self.playerTimeObserver) {
        [self.player removeTimeObserver:self.playerTimeObserver];
        self.playerTimeObserver = nil;
    }

    self.playerTimeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.05, NSEC_PER_SEC)
                                              queue:dispatch_get_main_queue()
                                         usingBlock:^(CMTime time) {

        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSTimeInterval current = CMTimeGetSeconds(time);
        if (!isfinite(current) || current < 0) return;

        CGFloat progress = (totalDuration > 0.1)
            ? MIN(1.0, current / totalDuration)
            : 0.0;

        if (self.currentItemIndex < self.progressBars.count) {
            UIProgressView *pv = self.progressBars[self.currentItemIndex];
            pv.progress = progress;
        }

        if (progress >= 0.999) {
            if (self.playerTimeObserver) {
                [self.player removeTimeObserver:self.playerTimeObserver];
                self.playerTimeObserver = nil;
            }
            [self nextItem];
        }
    }];
}




- (void)nextItem {
    self.currentItemIndex += 1;
    [self showItem];
}

- (void)nextStory {
    self.currentStoryIndex += 1;
    [self loadStory];
}


- (void)pp_handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (self.isInteractiveDismissInProgress) return;

    if (self.currentItemIndex < 0 ||
        self.currentItemIndex >= self.progressBars.count) return;

    if (gesture.state == UIGestureRecognizerStateBegan) {

        self.isPausedByLongPress = YES;

        [self.player pause];

        if (self.displayLink) {
            self.pausedImageElapsed = CACurrentMediaTime() - self.imageStartTime;
            [self.displayLink invalidate];
            self.displayLink = nil;
        }

        [UIView animateWithDuration:0.15 animations:^{
            self.progressContainer.alpha = 0.0;
            self.userAvatarView.alpha = 0.0;
            self.userNameHeaderLabel.alpha = 0.0;
            self.storyTimeLabel.alpha = 0.0;
            self.dismissButton.alpha = 0.0;
            self.muteButton.alpha = 0.0;
        }];
    }

    else if (gesture.state == UIGestureRecognizerStateEnded ||
             gesture.state == UIGestureRecognizerStateCancelled) {

        if (!self.isPausedByLongPress) return;
        self.isPausedByLongPress = NO;

        if (self.currentPlayerItem) {
            [self.player play];
        }
        else if (self.pausedImageElapsed > 0) {
            self.imageStartTime = CACurrentMediaTime() - self.pausedImageElapsed;
            self.pausedImageElapsed = 0;
            self.displayLink =
                [CADisplayLink displayLinkWithTarget:self
                                            selector:@selector(pp_handleImageTick:)];
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                                   forMode:NSRunLoopCommonModes];
        }

        [UIView animateWithDuration:0.15 animations:^{
            self.progressContainer.alpha = 1.0;
            self.userAvatarView.alpha = 1.0;
            self.userNameHeaderLabel.alpha = 1.0;
            self.storyTimeLabel.alpha = 1.0;
            self.dismissButton.alpha = 1.0;
            self.muteButton.alpha = 1.0;
        }];
    }
}


#pragma mark - Playback Lifecycle

- (void)pp_stopCurrentPlaybackAndPreserveProgress:(BOOL)preserveProgress
{
    if (preserveProgress) {
        [self pp_storeCurrentVideoProgressIfNeeded];
    }

    [self.timer invalidate];
    self.timer = nil;
    [self.player pause];
    if (self.playerTimeObserver) {
        [self.player removeTimeObserver:self.playerTimeObserver];
        self.playerTimeObserver = nil;
    }

    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    [self pp_removeCurrentPlayerItemObservers];
    self.hasStartedCurrentVideoPlayback = NO;
    self.currentVideoFallbackDuration = 0.0;
    self.currentVideoItemKey = nil;
}

- (void)pp_storeCurrentVideoProgressIfNeeded
{
    if (self.currentVideoItemKey.length == 0 || !self.player.currentItem) {
        return;
    }

    CMTime currentTime = self.player.currentTime;
    NSTimeInterval seconds = CMTimeGetSeconds(currentTime);
    if (!isfinite(seconds) || seconds <= 0.1) {
        [self.videoResumeTimesByItemKey removeObjectForKey:self.currentVideoItemKey];
        return;
    }

    self.videoResumeTimesByItemKey[self.currentVideoItemKey] = [NSValue valueWithCMTime:currentTime];
}

- (void)pp_removeCurrentPlayerItemObservers
{
    if (!self.currentPlayerItem) {
        return;
    }

    @try {
        [self.currentPlayerItem removeObserver:self
                                    forKeyPath:@"status"
                                       context:PPStoryPlayerItemStatusContext];
    } @catch (__unused NSException *exception) {
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.currentPlayerItem];
    self.currentPlayerItem = nil;
}

- (CMTime)pp_resumeTimeForCurrentVideoItemWithDuration:(NSTimeInterval)duration
{
    if (self.currentVideoItemKey.length == 0) {
        return kCMTimeZero;
    }

    NSValue *value = self.videoResumeTimesByItemKey[self.currentVideoItemKey];
    if (![value isKindOfClass:NSValue.class]) {
        return kCMTimeZero;
    }

    CMTime time = value.CMTimeValue;
    if (!CMTIME_IS_NUMERIC(time)) {
        return kCMTimeZero;
    }

    NSTimeInterval seconds = CMTimeGetSeconds(time);
    if (!isfinite(seconds) || seconds <= 0.1) {
        return kCMTimeZero;
    }

    if (duration > 0.4 && seconds >= duration - 0.2) {
        [self.videoResumeTimesByItemKey removeObjectForKey:self.currentVideoItemKey];
        return kCMTimeZero;
    }

    return time;
}

#pragma mark - Progress Animations

- (void)pp_startPulseAnimationForProgressView:(UIProgressView *)progressView
{
    if (![progressView isKindOfClass:UIProgressView.class]) {
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.58;
    pulse.toValue = @1.0;
    pulse.duration = 0.55;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [progressView.layer addAnimation:pulse forKey:PPStoryProgressPulseAnimationKey];
}

- (void)pp_startSlideAnimationForProgressView:(UIProgressView *)progressView
{
    if (![progressView isKindOfClass:UIProgressView.class]) {
        return;
    }

    CABasicAnimation *slide = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    slide.fromValue = @(-4.0);
    slide.toValue = @(0.0);
    slide.duration = 0.22;
    slide.repeatCount = 1;
    slide.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [progressView.layer addAnimation:slide forKey:PPStoryProgressSlideAnimationKey];
}

- (void)pp_stopAllProgressAnimations
{
    for (NSInteger i = 0; i < self.progressBars.count; i++) {
        UIProgressView *bar = self.progressBars[i];

        bar.progress = (i < self.currentItemIndex) ? 1.0 : 0.0;

        [bar.layer removeAllAnimations];
        bar.layer.speed = 1.0;
        bar.layer.timeOffset = 0.0;
        bar.layer.beginTime = 0.0;
        bar.alpha = 1.0;
    }
}

- (void)pp_animateProgressContainerEntrance
{
    self.progressContainer.alpha = 0.0;
    self.progressContainer.transform = CGAffineTransformMakeTranslation(18.0, -4.0);
    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.progressContainer.alpha = 1.0;
        self.progressContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Actions

- (void)handleTap:(UITapGestureRecognizer *)tap {
    if (self.isInteractiveDismissInProgress) {
        return;
    }

    CGPoint loc = [tap locationInView:self.view];

    CGFloat topBarHeight = self.view.safeAreaInsets.top + 60.0;
    if (loc.y < topBarHeight) {
        return;
    }

    CGFloat midX = self.view.bounds.size.width * 0.5;

    // LEFT SIDE → Previous
    if (loc.x < midX) {

        // Previous item
        if (self.currentItemIndex > 0) {
            self.currentItemIndex -= 1;
            [self showItem];
        }
        // Previous story
        else if (self.currentStoryIndex > 0) {
            self.currentStoryIndex -= 1;
            [self loadStory];
        }
    }
    // RIGHT SIDE → Next
    else {
        [self nextItem];
    }
}

- (void)pp_dismissButtonTapped
{
    [self pp_dismissViewerAnimated:YES];
}

- (void)pp_muteButtonTapped
{
    self.isPlayerMuted = !self.isPlayerMuted;
    self.player.muted = self.isPlayerMuted;
    [self pp_updateMuteButtonAppearance];
}

- (void)pp_updateMuteButtonAppearance
{
    NSString *imageName = self.isPlayerMuted ? @"speaker.slash.fill" : @"speaker.wave.2.fill";
    [self.muteButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
}

- (void)pp_dismissViewerAnimated:(BOOL)animated
{
    [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
    [self dismissViewControllerAnimated:animated completion:nil];
}

#pragma mark - Swipe Down Dismiss

- (void)pp_handleDismissPan:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:self.view];
    CGFloat y = MAX(translation.y, 0.0);
    CGFloat progress = MIN(1.0, y / 220.0);

    if (pan.state == UIGestureRecognizerStateBegan ||
        pan.state == UIGestureRecognizerStateChanged) {
        self.isInteractiveDismissInProgress = YES;
        self.view.transform = CGAffineTransformMakeTranslation(0.0, y);
        self.view.alpha = 1.0 - (progress * 0.45);
        return;
    }

    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled ||
        pan.state == UIGestureRecognizerStateFailed) {
        CGPoint velocity = [pan velocityInView:self.view];
        BOOL shouldDismiss = (y > 130.0 || velocity.y > 1100.0);

        if (shouldDismiss) {
            [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
            [UIView animateWithDuration:0.20
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                self.view.transform = CGAffineTransformMakeTranslation(0.0, self.view.bounds.size.height);
                self.view.alpha = 0.0;
            } completion:^(__unused BOOL finished) {
                self.isInteractiveDismissInProgress = NO;
                [self dismissViewControllerAnimated:NO completion:nil];
            }];
        } else {
            [UIView animateWithDuration:0.24
                                  delay:0.0
                 usingSpringWithDamping:0.86
                  initialSpringVelocity:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                self.view.transform = CGAffineTransformIdentity;
                self.view.alpha = 1.0;
            } completion:^(__unused BOOL finished) {
                self.isInteractiveDismissInProgress = NO;
            }];
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.dismissPanGesture) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:self.view];
        return fabs(velocity.y) > fabs(velocity.x) && velocity.y > 0.0;
    }
    return YES;
}

#pragma mark - Player Events

- (void)pp_playerItemDidFinish:(NSNotification *)notification
{
    if (notification.object != self.currentPlayerItem) {
        return;
    }
    if (self.currentVideoItemKey.length > 0) {
        [self.videoResumeTimesByItemKey removeObjectForKey:self.currentVideoItemKey];
    }
    [self nextItem];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    (void)change;
    if (context == PPStoryPlayerItemStatusContext) {
        if (object == self.currentPlayerItem && [keyPath isEqualToString:@"status"]) {
            [self pp_tryStartCurrentVideoPlaybackIfReady];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Helpers

- (NSTimeInterval)pp_safeDuration:(NSTimeInterval)duration fallback:(NSTimeInterval)fallback
{
    if (isfinite(duration) && duration > 0.15) {
        return duration;
    }
    if (isfinite(fallback) && fallback > 0.15) {
        return fallback;
    }
    return 5.0;
}

- (NSString *)pp_itemKeyForCurrentPositionWithItem:(PPStoryItem *)item
{
    if (self.currentStoryIndex < 0 || self.currentStoryIndex >= self.stories.count) {
        return [NSString stringWithFormat:@"story-%ld-item-%ld", (long)self.currentStoryIndex, (long)self.currentItemIndex];
    }

    PPStory *story = self.stories[self.currentStoryIndex];
    NSString *userID = story.userID ?: @"";
    NSString *media = item.mediaURL.absoluteString ?: @"";
    return [NSString stringWithFormat:@"%@|%ld|%@", userID, (long)self.currentItemIndex, media];
}

#pragma mark - User Info

- (void)pp_updateUserInfoForCurrentStory
{
    if (self.currentStoryIndex < 0 || self.currentStoryIndex >= (NSInteger)self.stories.count) {
        return;
    }

    PPStory *story = self.stories[self.currentStoryIndex];

    NSString *name = [story.userName stringByTrimmingCharactersInSet:
                      NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        name = kLang(@"Unknown");
    }
    self.userNameHeaderLabel.text = name;
    self.storyTimeLabel.text = [self pp_timeAgoFromDate:story.updatedAt];

    if (story.userImageURL) {
        [PPImageLoaderManager.shared setImageOnImageView:self.userAvatarView
                                                      url:story.userImageURL.absoluteString
                                               placeholder:[PPModernAvatarRenderer avatarImageForName:story.userName size:32]
                                                complation:nil];
    } else {
        self.userAvatarView.image = [PPModernAvatarRenderer avatarImageForName:story.userName size:32];
    }
}

- (NSString *)pp_timeAgoFromDate:(NSDate *)date
{
    if (!date) return @"";

    if (@available(iOS 13.0, *)) {
        NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
        formatter.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleAbbreviated;
        return [formatter localizedStringForDate:date relativeToDate:[NSDate date]];
    }

    NSTimeInterval seconds = -[date timeIntervalSinceNow];
    if (seconds < 60) return @"now";
    if (seconds < 3600) return [NSString stringWithFormat:@"%ldm", (long)(seconds / 60)];
    if (seconds < 86400) return [NSString stringWithFormat:@"%ldh", (long)(seconds / 3600)];
    return [NSString stringWithFormat:@"%ldd", (long)(seconds / 86400)];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

@end
