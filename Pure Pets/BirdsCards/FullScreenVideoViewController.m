#import "FullScreenVideoViewController.h"

@interface FullScreenVideoViewController ()
@property (nonatomic, strong) UIImageView *videoView;
@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) UIView *controlOverlay;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UISlider *progressSlider;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

@implementation FullScreenVideoViewController

- (instancetype)initWithVideoURL:(NSURL *)videoURL {
    self = [super init];
    if (self) {
        self.videoURL = videoURL;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set a black background with alpha transition
    self.view.backgroundColor = [UIColor blackColor];
    
    CGFloat topPadding = 0.0;
    CGFloat bottomPadding = 0.0;
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject]; // Get the first window
        if (window) { // Ensure the window is valid
            UIEdgeInsets safeAreaInsets = window.safeAreaInsets;
            topPadding = safeAreaInsets.top;
            bottomPadding = safeAreaInsets.bottom;
        } else {
            // Fallback if window is nil (unlikely in most cases)
            topPadding = 20.0;
            bottomPadding = 0.0;
            NSLog(@"Warning: Key window is nil. Using default safe area insets.");
        }

    } else {
        topPadding = 20.0;
        bottomPadding = 0.0;
    }
    
    // Create and configure the video view
    self.videoView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.videoView.contentMode = UIViewContentModeScaleAspectFit;
    self.videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.videoView.hx_h = self.view.hx_h - topPadding - bottomPadding;
    self.videoView.hx_y = topPadding;
    [self.view addSubview:self.videoView];

    [self.videoView jp_resumePlayWithURL:self.videoURL
                           bufferingIndicator:nil
                                  controlView:[[JPVideoPlayerControlView alloc] initWithControlBar:nil blurImage:nil]
                                 progressView:nil
                                configuration:^(UIView * _Nonnull view, JPVideoPlayerModel * _Nonnull playerModel) { }];
    // Setup the control overlay with play/pause button and slider.
      [self setupControlOverlay];
    
    // Add a dismiss button with custom styling.
    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dismissButton.frame = CGRectMake(20, 40, 44, 44);
    [dismissButton setImage:[UIImage imageNamed:@"pulldown"] forState:UIControlStateNormal];
    dismissButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    dismissButton.layer.cornerRadius = 22;
    dismissButton.clipsToBounds = YES;
    [dismissButton addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissButton];
    
    // Fade-in animation for smooth appearance.
    self.view.alpha = 0.0;
    [UIView animateWithDuration:0.3 animations:^{
        self.view.alpha = 1.0;
    }];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgress)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

#pragma mark - Control Actions

- (void)controlPlayPauseTapped:(UIButton *)sender {
    // Add a scaling animation.
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished){
        [UIView animateWithDuration:0.1 animations:^{
            sender.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            // Toggle play/pause using JPVideoPlayer methods.
            if (sender.selected) {
                [self.videoView jp_resume];
                sender.selected = NO;
            } else {
                [self.videoView jp_pause];
                sender.selected = YES;
            }
        }];
    }];
}

- (void)progressSliderChanged:(UISlider *)slider {
    if (self.player && self.player.currentItem.duration.value != 0) {
        float durationSeconds = CMTimeGetSeconds(self.player.currentItem.duration);
        float newTimeSeconds = slider.value * durationSeconds;
        CMTime newTime = CMTimeMakeWithSeconds(newTimeSeconds, self.player.currentItem.duration.timescale);
        [self.player seekToTime:newTime];
    }
}

- (void)updateProgress {
    if (self.player &&
        self.player.currentItem.duration.value != 0 &&
        CMTIME_IS_NUMERIC(self.player.currentItem.duration)) {
        
        float currentSeconds = CMTimeGetSeconds(self.player.currentTime);
        float durationSeconds = CMTimeGetSeconds(self.player.currentItem.duration);
        if (durationSeconds > 0) {
            self.progressSlider.value = currentSeconds / durationSeconds;
        }
    }
}

#pragma mark - Dismissal

- (void)dismissSelf {
    [UIView animateWithDuration:0.3 animations:^{
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.videoView jp_stopPlay];
        [self.displayLink invalidate];
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.view bringSubviewToFront:self.controlOverlay];
}
- (void)setupControlOverlay {
    // Create a semi-transparent overlay covering the videoView.
    self.controlOverlay = [[UIView alloc] init];
    self.controlOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    [self.view addSubview:self.controlOverlay];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.controlOverlay.topAnchor constraintEqualToAnchor:self.videoView.topAnchor],
        [self.controlOverlay.bottomAnchor constraintEqualToAnchor:self.videoView.bottomAnchor],
        [self.controlOverlay.leadingAnchor constraintEqualToAnchor:self.videoView.leadingAnchor],
        [self.controlOverlay.trailingAnchor constraintEqualToAnchor:self.videoView.trailingAnchor]
    ]];
    
    // Create Play/Pause Button.
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playPauseButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
    [self.playPauseButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateSelected];
    self.playPauseButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.playPauseButton.layer.cornerRadius = 25;
    self.playPauseButton.clipsToBounds = YES;
    [self.playPauseButton addTarget:self action:@selector(controlPlayPauseTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.controlOverlay addSubview:self.playPauseButton];
    
    // Layout the Play/Pause Button (bottom left corner).
    [NSLayoutConstraint activateConstraints:@[
        [self.playPauseButton.leadingAnchor constraintEqualToAnchor:self.controlOverlay.leadingAnchor constant:20],
        [self.playPauseButton.bottomAnchor constraintEqualToAnchor:self.controlOverlay.bottomAnchor constant:-20],
        [self.playPauseButton.widthAnchor constraintEqualToConstant:50],
        [self.playPauseButton.heightAnchor constraintEqualToConstant:50]
    ]];
    
    // Create a UISlider for progress.
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressSlider addTarget:self action:@selector(progressSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.controlOverlay addSubview:self.progressSlider];
    
    // Layout the progress slider (above the play button spanning much of the width).
    [NSLayoutConstraint activateConstraints:@[
        [self.progressSlider.leadingAnchor constraintEqualToAnchor:self.playPauseButton.trailingAnchor constant:20],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:self.controlOverlay.trailingAnchor constant:-20],
        [self.progressSlider.centerYAnchor constraintEqualToAnchor:self.playPauseButton.centerYAnchor]
    ]];
}



@end
