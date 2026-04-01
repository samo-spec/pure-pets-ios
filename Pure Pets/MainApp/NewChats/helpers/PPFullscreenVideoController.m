//
//  PPFullscreenVideoController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//


#import "PPFullscreenVideoController.h"
@import AVKit;

@interface PPFullscreenVideoController ()
@property (nonatomic, strong) AVPlayerViewController *playerVC;
@property (nonatomic, assign) CGRect fromFrame;
@end

@implementation PPFullscreenVideoController

- (instancetype)initWithURL:(NSURL *)url
                  fromFrame:(CGRect)fromFrame
{
    if (self = [super init]) {
        _fromFrame = fromFrame;
        AVPlayer *player = [AVPlayer playerWithURL:url];
        _playerVC = [AVPlayerViewController new];
        _playerVC.player = player;
        _playerVC.showsPlaybackControls = YES;
        _playerVC.videoGravity = AVLayerVideoGravityResizeAspect;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.playerVC.player play];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    [self addChildViewController:self.playerVC];
    self.playerVC.view.frame = self.view.bounds;
    [self.view addSubview:self.playerVC.view];
    [self.playerVC didMoveToParentViewController:self];
}

@end