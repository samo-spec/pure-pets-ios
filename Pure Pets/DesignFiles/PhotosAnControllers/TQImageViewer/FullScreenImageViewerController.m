#import "FullScreenImageViewerController.h"

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
