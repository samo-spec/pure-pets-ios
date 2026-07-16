#import "FullScreenImageViewerController.h"
#import <Pure_Pets-Swift.h>

static NSString *PPMediaPreviewLocalized(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    if ([value isKindOfClass:NSString.class] && value.length > 0 && ![value isEqualToString:key]) {
        return value;
    }
    return fallback ?: @"";
}

static UIViewController *PPMediaPreviewTopController(UIWindow *window)
{
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    BOOL advanced = YES;
    while (advanced) {
        advanced = NO;
        if ([controller isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)controller).visibleViewController;
            if (visible) { controller = visible; advanced = YES; }
        } else if ([controller isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)controller).selectedViewController;
            if (selected) { controller = selected; advanced = YES; }
        }
    }
    return controller;
}

@interface FullScreenImageViewerController ()
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, weak, nullable) UIImageView *sourceImageView;
@property (nonatomic, strong, nullable) UIViewController *previewController;
@property (nonatomic, assign) BOOL isDismissing;
@end

@implementation FullScreenImageViewerController

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _image = image;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
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
    [self pp_installPreviewIfPossible];
}

- (void)pp_installPreviewIfPossible
{
    if (self.previewController || !self.image) return;

    __weak typeof(self) weakSelf = self;
    void (^editAction)(void) = self.editHandler ? ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self && self.editHandler && self.image) self.editHandler(self, self.image);
    } : nil;
    void (^shareAction)(void) = self.shareHandler ? ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self && self.shareHandler) self.shareHandler(self);
    } : nil;

    UIViewController *preview =
    [PPMediaPreviewFactory imageControllerWithImage:self.image
                                         closeLabel:PPMediaPreviewLocalized(@"Close", @"Close")
                                          editLabel:PPMediaPreviewLocalized(@"Edit", @"Edit")
                                         shareLabel:PPMediaPreviewLocalized(@"Share", @"Share")
                                            onClose:^{ [weakSelf dismissFullScreen]; }
                                             onEdit:editAction
                                            onShare:shareAction];
    [self addChildViewController:preview];
    preview.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:preview.view];
    [NSLayoutConstraint activateConstraints:@[
        [preview.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [preview.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [preview.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [preview.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [preview didMoveToParentViewController:self];
    self.previewController = preview;
}

- (void)presentFullScreenFromImageView:(UIImageView *)sourceImageView
{
    if (!sourceImageView.window) return;
    self.sourceImageView = sourceImageView;
    self.image = self.image ?: sourceImageView.image;
    if (!self.image) return;

    UIViewController *presenter = PPMediaPreviewTopController(sourceImageView.window);
    if (!presenter) return;
    [presenter presentViewController:self animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

- (void)dismissFullScreen
{
    if (self.isDismissing) return;
    self.isDismissing = YES;
    __weak typeof(self) weakSelf = self;
    [self dismissViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled() completion:^{
        __strong typeof(weakSelf) self = weakSelf;
        self.isDismissing = NO;
        if (self.dismissalCompletion) self.dismissalCompletion();
    }];
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }

@end

@interface PPPremiumVideoPlayerViewController ()
@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong, nullable) UIViewController *previewController;
@end

@implementation PPPremiumVideoPlayerViewController

- (instancetype)initWithURL:(NSURL *)videoURL
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _videoURL = videoURL;
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

    __weak typeof(self) weakSelf = self;
    void (^editAction)(void) = self.editHandler ? ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self && self.editHandler) self.editHandler(self, self.videoURL);
    } : nil;
    UIViewController *preview =
    [PPMediaPreviewFactory videoControllerWithURL:self.videoURL
                                       closeLabel:PPMediaPreviewLocalized(@"Close", @"Close")
                                        editLabel:PPMediaPreviewLocalized(@"Edit", @"Edit")
                                       retryLabel:PPMediaPreviewLocalized(@"Retry", @"Retry")
                                          onClose:^{
        [weakSelf dismissViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
    }
                                           onEdit:editAction];
    [self addChildViewController:preview];
    preview.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:preview.view];
    [NSLayoutConstraint activateConstraints:@[
        [preview.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [preview.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [preview.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [preview.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [preview didMoveToParentViewController:self];
    self.previewController = preview;
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }

@end
