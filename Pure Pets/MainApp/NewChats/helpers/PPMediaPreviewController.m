#import "PPMediaPreviewController.h"
#import <AVKit/AVKit.h>

@interface PPMediaPreviewController () <UIScrollViewDelegate>

@property (nonatomic) PPMediaPreviewType type;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSURL *videoURL;

// Image
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;

// Video
@property (nonatomic, strong) AVPlayerViewController *playerVC;

// Bottom controls
@property (nonatomic, strong) UIView *controlsBlurView;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *cancelButton;

@end

@implementation PPMediaPreviewController

#pragma mark - Init

- (instancetype)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _type = PPMediaPreviewTypeImage;
        _image = image;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (instancetype)initWithVideoURL:(NSURL *)videoURL {
    self = [super init];
    if (self) {
        _type = PPMediaPreviewTypeVideo;
        _videoURL = videoURL;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    if (self.type == PPMediaPreviewTypeImage) {
        [self setupZoomableImage];
    } else {
        [self setupVideoPlayer];
    }

    [self setupBottomControls];
}

#pragma mark - Image (Zoomable)

- (void)setupZoomableImage {

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.delegate = self;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 4.0;
    self.scrollView.backgroundColor = UIColor.blackColor;
    self.scrollView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.imageView = [[UIImageView alloc] initWithImage:self.image];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.frame = self.scrollView.bounds;
    self.imageView.userInteractionEnabled = YES;

    [self.scrollView addSubview:self.imageView];
    [self.view addSubview:self.scrollView];

    // Double-tap zoom
    UITapGestureRecognizer *doubleTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:doubleTap];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (self.scrollView.zoomScale > 1.0) {
        [self.scrollView setZoomScale:1.0 animated:YES];
    } else {
        CGPoint point = [gesture locationInView:self.imageView];
        CGRect zoomRect = [self zoomRectForScale:3.0 center:point];
        [self.scrollView zoomToRect:zoomRect animated:YES];
    }
}

- (CGRect)zoomRectForScale:(CGFloat)scale center:(CGPoint)center {
    CGRect rect;
    rect.size.width = self.scrollView.bounds.size.width / scale;
    rect.size.height = self.scrollView.bounds.size.height / scale;
    rect.origin.x = center.x - rect.size.width / 2.0;
    rect.origin.y = center.y - rect.size.height / 2.0;
    return rect;
}

#pragma mark - Video

- (void)setupVideoPlayer {

    self.playerVC = [[AVPlayerViewController alloc] init];
    self.playerVC.player = [AVPlayer playerWithURL:self.videoURL];
    self.playerVC.showsPlaybackControls = YES;

    self.playerVC.view.frame = self.view.bounds;
    self.playerVC.view.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self addChildViewController:self.playerVC];
    [self.view addSubview:self.playerVC.view];
    [self.playerVC didMoveToParentViewController:self];

    [self.playerVC.player play];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [Styling addLiquidGlassBorderToView:self.controlsBlurView cornerRadius:29];
}

#pragma mark - Bottom Controls (Glass Buttons)

- (void)setupBottomControls {

    CGFloat height = 68.0;

    UIVisualEffect *effect;
    if (@available(iOS 26.0, *)) {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }

    self.controlsBlurView =
        [[UIView alloc] init];
    self.controlsBlurView.frame =
        CGRectMake(32,
                   self.view.bounds.size.height - height,
                   self.view.bounds.size.width-64,
                   54);
    self.controlsBlurView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.controlsBlurView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.4];
    self.controlsBlurView.layer.cornerRadius = 27;
    self.controlsBlurView.clipsToBounds = YES;
    [self.view addSubview:self.controlsBlurView];

    self.cancelButton = [self glassButtonWithTitle:kLang(@"Cancel")];
    self.sendButton   = [self glassButtonWithTitle:kLang(@"Send")];

    self.cancelButton.frame = CGRectMake(6, 6, 120, 42);
    self.sendButton.frame =
        CGRectMake(self.controlsBlurView.bounds.size.width - 126,
                   6, 120, 42);

    self.sendButton.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin;

    [self.cancelButton addTarget:self
                           action:@selector(onCancel)
                 forControlEvents:UIControlEventTouchUpInside];

    [self.sendButton addTarget:self
                         action:@selector(onSend)
               forControlEvents:UIControlEventTouchUpInside];

    [self.controlsBlurView addSubview:self.cancelButton];
    [self.controlsBlurView addSubview:self.sendButton];
}

- (UIButton *)glassButtonWithTitle:(NSString *)title
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 26.0, *)) {

        UIButtonConfiguration *config =
            [UIButtonConfiguration glassButtonConfiguration];

        config.title = title;

        // Font (this is the ONLY correct way)
        config.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey, id> *
        (NSDictionary<NSAttributedStringKey, id>* incoming) {

                NSMutableDictionary *attrs =
                    incoming.mutableCopy ?: NSMutableDictionary.new;

                attrs[NSFontAttributeName] =
                    [GM boldFontWithSize:17];

                return attrs;
            };

        // Colors
        //config.baseForegroundColor = UIColor.whiteColor;
        config.background.backgroundColor =
            [UIColor.systemBackgroundColor colorWithAlphaComponent:0.22];

        btn.configuration = config;

    } else {

        // iOS 25 and below fallback
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [GM boldFontWithSize:17];
        btn.tintColor = UIColor.whiteColor;
        btn.backgroundColor =
            [[UIColor blackColor] colorWithAlphaComponent:0.35];
        btn.layer.cornerRadius = 14;
        btn.layer.masksToBounds = YES;
    }

    return btn;
}

#pragma mark - Actions

- (void)onCancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onSend {
    self.sendButton.enabled = NO;
    self.cancelButton.enabled = NO;
    self.sendButton.alpha = 0.6;

    PPMediaPreviewType type = self.type;
    UIImage *selectedImage = self.image;
    NSURL *selectedVideoURL = self.videoURL;
    void (^sendImageBlock)(UIImage *) = [self.onSendImage copy];
    void (^sendVideoBlock)(NSURL *) = [self.onSendVideo copy];

    [self dismissViewControllerAnimated:YES completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (type == PPMediaPreviewTypeImage && sendImageBlock) {
                sendImageBlock(selectedImage);
            }
            if (type == PPMediaPreviewTypeVideo && sendVideoBlock) {
                sendVideoBlock(selectedVideoURL);
            }
        });
    }];
}

@end
