//
//  PPOfflineBannerView.m
//  Pure Pets
//
//  Persistent offline status banner powered by NWPathMonitor (iOS 12+).
//
//  Architecture
//  ────────────
//  • A passthrough UIWindow (PPOfflinePassthroughWindow) at windowLevel
//    UIWindowLevelStatusBar − 1 hosts the banner so it floats above all
//    navigation / tab bar controllers without z-order conflicts.
//  • The passthrough window only intercepts touches that land on the
//    banner itself; everything else falls through to the app's key window.
//  • A 1-second debounce prevents flicker on brief connectivity drops
//    (e.g. switching from Wi-Fi to cellular).
//  • The banner respects safe area insets so it never overlaps the notch,
//    Dynamic Island, or the status bar.
//

#import "PPOfflineBannerView.h"
#import <Network/Network.h>

#pragma mark - Notification Name

NSNotificationName const PPConnectivityDidChangeNotification = @"PPConnectivityDidChange";

#pragma mark - Constants

static CGFloat const kPPBannerHeight          = 36.0;
static CGFloat const kPPBannerIconSize        = 16.0;
static CGFloat const kPPBannerIconTextSpacing = 6.0;
static CGFloat const kPPBannerHorizontalPad   = 12.0;
static NSTimeInterval const kPPShowDebounce   = 1.0;   // seconds before showing
static NSTimeInterval const kPPShowDuration   = 0.4;   // spring animation in
static NSTimeInterval const kPPHideDuration   = 0.3;   // ease-out animation out

#pragma mark - Passthrough Window

/// A UIWindow subclass that only intercepts touches landing on a specific
/// content view (the banner). All other touches pass through to the
/// underlying application window.
@interface PPOfflinePassthroughWindow : UIWindow
@property (nonatomic, weak) UIView *passthroughTarget;
@end

@implementation PPOfflinePassthroughWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.passthroughTarget) return NO;
    CGPoint converted = [self convertPoint:point toView:self.passthroughTarget];
    return [self.passthroughTarget pointInside:converted withEvent:event];
}

@end

#pragma mark - Passthrough Root VC (transparent, auto-rotating)

@interface PPOfflinePassthroughRootVC : UIViewController
@end

@implementation PPOfflinePassthroughRootVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
}

- (BOOL)prefersStatusBarHidden { return NO; }
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end

#pragma mark - PPOfflineBannerView Private

@interface PPOfflineBannerView ()

/// Network.framework monitor.
@property (nonatomic, strong) nw_path_monitor_t monitor;

/// Dedicated serial queue for NWPathMonitor callbacks.
@property (nonatomic, strong) dispatch_queue_t monitorQueue;

/// Floating window that hosts the banner above all other content.
@property (nonatomic, strong) PPOfflinePassthroughWindow *overlayWindow;

/// Content stack: icon + label.
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel     *messageLabel;

/// Internal state.
@property (nonatomic, assign, readwrite, getter=isConnected) BOOL connected;
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, assign) BOOL isBannerVisible;

/// Debounce work item — cancelled when connectivity is restored quickly.
@property (nonatomic, strong, nullable) dispatch_block_t showDebounceWork;

@end

@implementation PPOfflineBannerView

#pragma mark - Singleton

+ (instancetype)sharedBanner {
    static PPOfflineBannerView *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PPOfflineBannerView alloc] initWithFrame:CGRectZero];
    });
    return instance;
}

#pragma mark - Initialisation

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _connected      = YES;   // optimistic default
        _isMonitoring   = NO;
        _isBannerVisible = NO;
        [self pp_setupBannerUI];
    }
    return self;
}

/// Construct the banner's visual hierarchy.
- (void)pp_setupBannerUI {

    // ── Background ──────────────────────────────────────────────────
    // Amber / warning colour matching #F59E0B.
    self.backgroundColor = [UIColor colorWithRed:0.961
                                           green:0.620
                                            blue:0.043
                                           alpha:1.0];
    self.clipsToBounds = YES;

    // ── Wi-Fi-off icon (SF Symbol, iOS 13+) ─────────────────────────
    UIImageView *icon = [[UIImageView alloc] init];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = [UIColor whiteColor];
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:kPPBannerIconSize
                                                            weight:UIImageSymbolWeightSemibold];
        icon.image = [UIImage systemImageNamed:@"wifi.slash"
                             withConfiguration:cfg];
    }
    self.iconView = icon;

    // ── Label ───────────────────────────────────────────────────────
    UILabel *label    = [[UILabel alloc] init];
    label.text        = NSLocalizedString(@"offline_banner_text", nil);
    label.textColor   = [UIColor whiteColor];
    label.font        = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textAlignment       = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor  = 0.7;
    label.numberOfLines       = 1;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel = label;

    // ── Container stack ─────────────────────────────────────────────
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    stack.axis      = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing   = kPPBannerIconTextSpacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        // Icon fixed size
        [icon.widthAnchor  constraintEqualToConstant:kPPBannerIconSize],
        [icon.heightAnchor constraintEqualToConstant:kPPBannerIconSize],

        // Centre stack inside banner
        [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor
                                                         constant:kPPBannerHorizontalPad],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor
                                                       constant:-kPPBannerHorizontalPad],
    ]];

    // Semantic direction follows the app's language automatically via
    // the stack view's semanticContentAttribute inheritance.
}

#pragma mark - Overlay Window

/// Lazily creates the passthrough overlay window.
- (PPOfflinePassthroughWindow *)pp_overlayWindow {
    if (!_overlayWindow) {
        PPOfflinePassthroughWindow *w;

        if (@available(iOS 15.0, *)) {
            // Attach to the foreground-active window scene.
            UIWindowScene *activeScene = [self pp_activeWindowScene];
            if (activeScene) {
                w = [[PPOfflinePassthroughWindow alloc] initWithWindowScene:activeScene];
            } else {
                w = [[PPOfflinePassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
            }
        } else {
            w = [[PPOfflinePassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }

        w.windowLevel = UIWindowLevelStatusBar - 1;
        w.backgroundColor = [UIColor clearColor];
        w.hidden = NO;
        w.userInteractionEnabled = YES;
        w.passthroughTarget = self;

        // Transparent root VC — needed so the window participates in rotation.
        PPOfflinePassthroughRootVC *rootVC = [[PPOfflinePassthroughRootVC alloc] init];
        w.rootViewController = rootVC;

        // Add banner to root VC's view.
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [rootVC.view addSubview:self];

        UILayoutGuide *safe = rootVC.view.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [self.topAnchor      constraintEqualToAnchor:safe.topAnchor],
            [self.leadingAnchor  constraintEqualToAnchor:rootVC.view.leadingAnchor],
            [self.trailingAnchor constraintEqualToAnchor:rootVC.view.trailingAnchor],
            [self.heightAnchor   constraintEqualToConstant:kPPBannerHeight],
        ]];

        _overlayWindow = w;
    }
    return _overlayWindow;
}

/// Returns the foreground-active UIWindowScene (iOS 13+).
- (UIWindowScene * _Nullable)pp_activeWindowScene API_AVAILABLE(ios(13.0)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

#pragma mark - Monitoring

- (void)startMonitoring {
    if (self.isMonitoring) return;
    self.isMonitoring = YES;

    self.monitorQueue = dispatch_queue_create("com.purepets.network.monitor",
                                              DISPATCH_QUEUE_SERIAL);
    self.monitor = nw_path_monitor_create();

    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_update_handler(self.monitor, ^(nw_path_t _Nonnull path) {
        BOOL satisfied = (nw_path_get_status(path) == nw_path_status_satisfied);
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf pp_handleConnectivityChange:satisfied];
        });
    });

    nw_path_monitor_set_queue(self.monitor, self.monitorQueue);
    nw_path_monitor_start(self.monitor);

    NSLog(@"[PPOfflineBanner] Network monitoring started");
}

- (void)stopMonitoring {
    if (!self.isMonitoring) return;
    self.isMonitoring = NO;

    if (self.monitor) {
        nw_path_monitor_cancel(self.monitor);
        self.monitor = nil;
    }

    // Cancel any pending debounce.
    if (self.showDebounceWork) {
        dispatch_block_cancel(self.showDebounceWork);
        self.showDebounceWork = nil;
    }

    [self pp_hideBannerAnimated:NO];

    NSLog(@"[PPOfflineBanner] Network monitoring stopped");
}

#pragma mark - State Machine

- (void)pp_handleConnectivityChange:(BOOL)isConnected {
    NSAssert(NSThread.isMainThread, @"Must be called on main thread");

    // Avoid duplicate processing.
    if (self.connected == isConnected) return;

    self.connected = isConnected;

    // Post notification for other subsystems.
    [[NSNotificationCenter defaultCenter]
        postNotificationName:PPConnectivityDidChangeNotification
                      object:self
                    userInfo:@{ @"isConnected" : @(isConnected) }];

    if (isConnected) {
        // Cancel pending show (debounce).
        if (self.showDebounceWork) {
            dispatch_block_cancel(self.showDebounceWork);
            self.showDebounceWork = nil;
        }
        [self pp_hideBannerAnimated:YES];
        NSLog(@"[PPOfflineBanner] Connectivity restored — hiding banner");
    } else {
        // Debounce: wait kPPShowDebounce before actually showing.
        [self pp_scheduleShowBanner];
        NSLog(@"[PPOfflineBanner] Connectivity lost — scheduling banner (%.0fs debounce)",
              kPPShowDebounce);
    }
}

#pragma mark - Show / Hide

- (void)pp_scheduleShowBanner {
    // Cancel any existing pending show.
    if (self.showDebounceWork) {
        dispatch_block_cancel(self.showDebounceWork);
        self.showDebounceWork = nil;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t work = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.showDebounceWork = nil;

        // Double-check: connectivity could have been restored during debounce.
        if (strongSelf.isConnected) return;

        [strongSelf pp_showBannerAnimated:YES];
    });

    self.showDebounceWork = work;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                  (int64_t)(kPPShowDebounce * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), work);
}

- (void)pp_showBannerAnimated:(BOOL)animated {
    if (self.isBannerVisible) return;
    self.isBannerVisible = YES;

    // Refresh localised text (language could change at runtime).
    self.messageLabel.text = NSLocalizedString(@"offline_banner_text", nil);

    // Ensure the overlay window is created & visible.
    PPOfflinePassthroughWindow *overlay = [self pp_overlayWindow];
    overlay.hidden = NO;

    // Start off-screen (above the visible area).
    self.transform = CGAffineTransformMakeTranslation(0, -kPPBannerHeight);
    self.alpha = 0.0;

    if (animated) {
        [UIView animateWithDuration:kPPShowDuration
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformIdentity;
            self.alpha = 1.0;
        } completion:nil];
    } else {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }
}

- (void)pp_hideBannerAnimated:(BOOL)animated {
    if (!self.isBannerVisible) return;

    void (^cleanup)(BOOL) = ^(BOOL finished) {
        self.isBannerVisible = NO;
        self.overlayWindow.hidden = YES;
    };

    if (animated) {
        [UIView animateWithDuration:kPPHideDuration
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformMakeTranslation(0, -kPPBannerHeight);
            self.alpha = 0.0;
        } completion:cleanup];
    } else {
        self.transform = CGAffineTransformMakeTranslation(0, -kPPBannerHeight);
        self.alpha = 0.0;
        cleanup(YES);
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    [self stopMonitoring];
}

@end
