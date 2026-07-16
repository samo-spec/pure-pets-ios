//
//  PPInAppChatNotificationPresenter.m
//  Pure Pets
//

#import "PPInAppChatNotificationPresenter.h"
#import "ChatThreadModel.h"
#import "ChatMessageModel.h"
#import "ChManager.h"
#import "ChNotificationRouter.h"
#import "PPModernAvatarRenderer.h"
#import "UserModel.h"

static CGFloat const kPPChatNoticeHorizontalInset = 14.0;
static CGFloat const kPPChatNoticeTopInset = 8.0;
static CGFloat const kPPChatNoticeMinHeight = 74.0;
static CGFloat const kPPChatNoticeMaxWidth = 520.0;
static CGFloat const kPPChatNoticeAvatarSize = 44.0;
static NSTimeInterval const kPPChatNoticeVisibleDuration = 5.2;
static NSString * const kPPChatNoticeSupportAvatarToken = @"purepets://support-logo";

static NSString *PPChatNoticeTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *PPChatNoticeLocalizedValue(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    if (value.length > 0 && ![value isEqualToString:key]) {
        return value;
    }
    return fallback ?: @"";
}

static NSString *PPChatNoticePreviewForMessage(ChatMessageModel *message)
{
    NSString *text = PPChatNoticeTrimmedString(message.text);
    if (text.length > 0) {
        return text;
    }

    switch (message.messageType) {
        case ChatMessageTypeAudio:
            return PPChatNoticeLocalizedValue(@"AudioFile", PPChatNoticeLocalizedValue(@"Message", @""));
        case ChatMessageTypeImage:
            return PPChatNoticeLocalizedValue(@"imageFile", PPChatNoticeLocalizedValue(@"Message", @""));
        case ChatMessageTypeVideo:
            return PPChatNoticeLocalizedValue(@"VideoFile", PPChatNoticeLocalizedValue(@"Message", @""));
        case ChatMessageTypeFile:
            return PPChatNoticeLocalizedValue(@"chat_notification_file", PPChatNoticeLocalizedValue(@"Message", @""));
        case ChatMessageTypeSticker:
            return PPChatNoticeLocalizedValue(@"chat_sticker_message", PPChatNoticeLocalizedValue(@"Message", @""));
        case ChatMessageTypeText:
        default:
            return PPChatNoticeLocalizedValue(@"Message", @"");
    }
}

@interface PPChatNoticePassthroughWindow : UIWindow
@property (nonatomic, weak) UIView *touchTarget;
@end

@implementation PPChatNoticePassthroughWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!self.touchTarget || self.hidden || self.alpha <= 0.01) {
        return NO;
    }
    CGPoint converted = [self convertPoint:point toView:self.touchTarget];
    return [self.touchTarget pointInside:converted withEvent:event];
}

@end

@interface PPChatNoticeRootViewController : UIViewController
@end

@implementation PPChatNoticeRootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.userInteractionEnabled = YES;
}

- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }

@end

@interface PPInAppChatNotificationBannerView : UIControl
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) CAGradientLayer *liveLineLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) UserModel *displayUser;
@property (nonatomic, copy) NSString *avatarURLString;
- (void)configureWithThread:(nullable ChatThreadModel *)thread message:(ChatMessageModel *)message;
- (void)startLiveEffectsWithDuration:(NSTimeInterval)duration;
- (void)stopLiveEffects;
@end

@implementation PPInAppChatNotificationBannerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_setupUI];
        [self pp_applyTheme];
    }
    return self;
}

- (void)pp_setupUI
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.clipsToBounds = YES;
    surface.userInteractionEnabled = NO;
    PPApplyContinuousCorners(surface, 26.0);
    self.surfaceView = surface;
    [self addSubview:surface];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    blur.userInteractionEnabled = NO;
    self.blurView = blur;
    [surface addSubview:blur];

    UIView *tint = [[UIView alloc] init];
    tint.translatesAutoresizingMaskIntoConstraints = NO;
    tint.userInteractionEnabled = NO;
    self.tintView = tint;
    [surface addSubview:tint];

    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = kPPChatNoticeAvatarSize / 2.0;
    self.avatarView = avatar;
    [surface addSubview:avatar];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [GM boldFontWithSize:PPFontCallout];
    title.numberOfLines = 1;
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.82;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel = title;
    [surface addSubview:title];

    UILabel *message = [[UILabel alloc] init];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.font = [GM fontWithSize:PPFontFootnote];
    message.numberOfLines = 1;
    message.lineBreakMode = NSLineBreakByTruncatingTail;
    message.textAlignment = [Language alignmentForCurrentLanguage];
    self.messageLabel = message;
    [surface addSubview:message];

    UIImageView *chevron = [[UIImageView alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.tintColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
        chevron.image = [UIImage systemImageNamed:@"chevron.forward" withConfiguration:cfg];
    }
    self.chevronView = chevron;
    [surface addSubview:chevron];

    CAGradientLayer *line = [CAGradientLayer layer];
    line.startPoint = CGPointMake(0.5, 0.0);
    line.endPoint = CGPointMake(0.5, 1.0);
    line.opacity = 0.72;
    self.liveLineLayer = line;
    [surface.layer addSublayer:line];

    CAShapeLayer *progress = [CAShapeLayer layer];
    progress.fillColor = UIColor.clearColor.CGColor;
    progress.lineCap = kCALineCapRound;
    progress.lineWidth = 1.5;
    progress.opacity = 0.72;
    self.progressLayer = progress;
    [surface.layer addSublayer:progress];

    UILayoutGuide *textGuide = [[UILayoutGuide alloc] init];
    [surface addLayoutGuide:textGuide];

    [NSLayoutConstraint activateConstraints:@[
        [surface.topAnchor constraintEqualToAnchor:self.topAnchor],
        [surface.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [blur.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [blur.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],

        [tint.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [tint.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [tint.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [tint.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],

        [avatar.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceBase],
        [avatar.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [avatar.widthAnchor constraintEqualToConstant:kPPChatNoticeAvatarSize],
        [avatar.heightAnchor constraintEqualToConstant:kPPChatNoticeAvatarSize],

        [chevron.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceBase],
        [chevron.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:16.0],
        [chevron.heightAnchor constraintEqualToConstant:18.0],

        [textGuide.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:PPSpaceMD],
        [textGuide.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-PPSpaceMD],
        [textGuide.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [textGuide.heightAnchor constraintEqualToConstant:40.0],

        [title.topAnchor constraintEqualToAnchor:textGuide.topAnchor],
        [title.leadingAnchor constraintEqualToAnchor:textGuide.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:textGuide.trailingAnchor],

        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:1.0],
        [message.leadingAnchor constraintEqualToAnchor:textGuide.leadingAnchor],
        [message.trailingAnchor constraintEqualToAnchor:textGuide.trailingAnchor],
        [message.bottomAnchor constraintLessThanOrEqualToAnchor:textGuide.bottomAnchor],
    ]];

    PPApplyElevatedShadow(self);
    self.layer.shadowOpacity = 0.16;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_applyTheme];

    CGFloat height = self.surfaceView.bounds.size.height;
    CGFloat width = self.surfaceView.bounds.size.width;
    CGFloat lineWidth = 3.0;
    CGFloat lineX = Language.isRTL ? width - lineWidth : 0.0;
    self.liveLineLayer.frame = CGRectMake(lineX, 13.0, lineWidth, MAX(1.0, height - 26.0));

    CGFloat progressWidth = MAX(1.0, width - (PPSpaceBase * 2.0));
    self.progressLayer.frame = CGRectMake(PPSpaceBase, height - 3.0, progressWidth, 1.5);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0.0, 0.75)];
    [path addLineToPoint:CGPointMake(progressWidth, 0.75)];
    self.progressLayer.path = path.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyTheme];
}

- (void)pp_applyTheme
{
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.messageLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.chevronView.tintColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;

    UIColor *surfaceColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:0.04 alpha:0.64]
            : [UIColor colorWithWhite:1.0 alpha:0.70];
    }];
    UIColor *borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:1.0 alpha:0.13]
            : [UIColor colorWithWhite:0.0 alpha:0.07];
    }];
    UIColor *accent = AppPrimaryClr ?: [UIColor systemPinkColor];

    self.tintView.backgroundColor = surfaceColor;
    self.surfaceView.layer.borderColor = borderColor.CGColor;
    self.surfaceView.layer.borderWidth = 0.8;
    self.liveLineLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:0.08].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.95].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.08].CGColor
    ];
    self.progressLayer.strokeColor = [accent colorWithAlphaComponent:0.72].CGColor;
}

- (void)configureWithThread:(nullable ChatThreadModel *)thread message:(ChatMessageModel *)message
{
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.messageLabel.textAlignment = [Language alignmentForCurrentLanguage];

    UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread];
    self.displayUser = user;

    NSString *displayName = PPChatNoticeTrimmedString(user.UserName);
    if (displayName.length == 0) {
        displayName = PPChatNoticeLocalizedValue(@"New Message", @"");
    }

    NSString *preview = PPChatNoticePreviewForMessage(message);
    if (preview.length == 0) {
        preview = PPChatNoticeLocalizedValue(@"Message", @"");
    }

    self.titleLabel.text = displayName;
    self.messageLabel.text = preview;
    self.accessibilityLabel = preview.length
        ? [NSString stringWithFormat:@"%@. %@", displayName, preview]
        : displayName;
    self.accessibilityHint = PPChatNoticeLocalizedValue(@"chat_notification_accessibility_hint", @"");

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:displayName size:kPPChatNoticeAvatarSize];
    self.avatarView.image = placeholder;

    NSString *avatarURL = PPChatNoticeTrimmedString(user.UserImageUrl.absoluteString);
    self.avatarURLString = avatarURL;
    if ([avatarURL hasPrefix:kPPChatNoticeSupportAvatarToken]) {
        self.avatarView.image = [UIImage imageNamed:@"PPLogo"] ?: placeholder;
    } else if (avatarURL.length > 0) {
        [GM setImageFromUrlString:avatarURL imageView:self.avatarView phImage:nil completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
            (void)error;
            if (![self.avatarURLString isEqualToString:avatarURL]) {
                return;
            }
            if (!image) {
                self.avatarView.image = placeholder;
            }
        }];
    }
}

- (void)startLiveEffectsWithDuration:(NSTimeInterval)duration
{
    [self stopLiveEffects];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.42;
    pulse.toValue = @0.95;
    pulse.duration = 1.35;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.liveLineLayer addAnimation:pulse forKey:@"pp.chat.notice.line.pulse"];

    self.progressLayer.strokeStart = 0.0;
    self.progressLayer.strokeEnd = 1.0;

    NSString *keyPath = Language.isRTL ? @"strokeStart" : @"strokeEnd";
    CABasicAnimation *progress = [CABasicAnimation animationWithKeyPath:keyPath];
    progress.fromValue = Language.isRTL ? @0.0 : @1.0;
    progress.toValue = Language.isRTL ? @1.0 : @0.0;
    progress.duration = duration;
    progress.removedOnCompletion = NO;
    progress.fillMode = kCAFillModeForwards;
    progress.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];
    [self.progressLayer addAnimation:progress forKey:@"pp.chat.notice.progress"];
}

- (void)stopLiveEffects
{
    [self.liveLineLayer removeAnimationForKey:@"pp.chat.notice.line.pulse"];
    [self.progressLayer removeAnimationForKey:@"pp.chat.notice.progress"];
    self.liveLineLayer.opacity = 0.72;
    self.progressLayer.strokeStart = 0.0;
    self.progressLayer.strokeEnd = 1.0;
}

@end

@interface PPInAppChatNotificationPresenter ()
@property (nonatomic, strong) PPChatNoticePassthroughWindow *overlayWindow;
@property (nonatomic, strong) PPInAppChatNotificationBannerView *bannerView;
@property (nonatomic, copy) dispatch_block_t dismissWork;
@property (nonatomic, copy) NSDictionary<NSString *, id> *currentUserInfo;
@property (nonatomic, assign) BOOL isVisible;
- (nullable UIViewController *)pp_fallbackTopViewController;
- (nullable UIViewController *)pp_topViewControllerFromRoot:(nullable UIViewController *)rootViewController;
@end

@implementation PPInAppChatNotificationPresenter

+ (instancetype)sharedPresenter
{
    static PPInAppChatNotificationPresenter *presenter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        presenter = [[PPInAppChatNotificationPresenter alloc] init];
    });
    return presenter;
}

- (void)showChatNotificationForThread:(nullable ChatThreadModel *)thread
                              message:(ChatMessageModel *)message
                             userInfo:(NSDictionary<NSString *, id> *)userInfo
{
    if (!message || userInfo.count == 0) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
            return;
        }

        self.currentUserInfo = userInfo.copy;
        [self pp_prepareOverlayIfNeeded];
        [self.bannerView configureWithThread:thread message:message];
        [self pp_cancelDismissWork];
        [self pp_showBanner];
        [self pp_scheduleDismiss];
    });
}

- (void)dismissCurrentNotificationAnimated:(BOOL)animated
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_cancelDismissWork];
        [self pp_hideBannerAnimated:animated completion:nil];
    });
}

#pragma mark - Overlay

- (void)pp_prepareOverlayIfNeeded
{
    if (self.overlayWindow && self.bannerView.superview) {
        UIWindowScene *scene = self.overlayWindow.windowScene;
        if (!scene || scene.activationState == UISceneActivationStateForegroundActive) {
            self.overlayWindow.hidden = NO;
            return;
        }
        self.overlayWindow.hidden = YES;
        self.overlayWindow = nil;
        self.bannerView = nil;
    }

    PPChatNoticePassthroughWindow *window = nil;
    UIWindowScene *activeScene = [self pp_activeWindowScene];
    if (activeScene) {
        window = [[PPChatNoticePassthroughWindow alloc] initWithWindowScene:activeScene];
    } else {
        window = [[PPChatNoticePassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    window.windowLevel = UIWindowLevelStatusBar + 4.0;
    window.backgroundColor = UIColor.clearColor;
    window.hidden = NO;
    window.userInteractionEnabled = YES;

    PPChatNoticeRootViewController *root = [[PPChatNoticeRootViewController alloc] init];
    window.rootViewController = root;

    PPInAppChatNotificationBannerView *banner = [[PPInAppChatNotificationBannerView alloc] initWithFrame:CGRectZero];
    [banner addTarget:self action:@selector(pp_bannerTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [banner addTarget:self action:@selector(pp_bannerTouchCancel:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [banner addTarget:self action:@selector(pp_bannerTapped:) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:banner];

    UILayoutGuide *safe = root.view.safeAreaLayoutGuide;
    NSLayoutConstraint *widthLimit = [banner.widthAnchor constraintLessThanOrEqualToConstant:kPPChatNoticeMaxWidth];
    widthLimit.priority = UILayoutPriorityRequired;

    [NSLayoutConstraint activateConstraints:@[
        [banner.topAnchor constraintEqualToAnchor:safe.topAnchor constant:kPPChatNoticeTopInset],
        [banner.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.view.leadingAnchor constant:kPPChatNoticeHorizontalInset],
        [banner.trailingAnchor constraintLessThanOrEqualToAnchor:root.view.trailingAnchor constant:-kPPChatNoticeHorizontalInset],
        [banner.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
        widthLimit,
        [banner.heightAnchor constraintGreaterThanOrEqualToConstant:kPPChatNoticeMinHeight],
    ]];

    window.touchTarget = banner;
    self.overlayWindow = window;
    self.bannerView = banner;
}

- (UIWindowScene *)pp_activeWindowScene
{
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:UIWindowScene.class]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

#pragma mark - Motion

- (void)pp_showBanner
{
    [self.overlayWindow.rootViewController.view layoutIfNeeded];
    [self.bannerView.layer removeAllAnimations];
    [self.bannerView stopLiveEffects];
    self.overlayWindow.hidden = NO;
    self.bannerView.hidden = NO;

    if (self.isVisible) {
        [self pp_refreshVisibleBannerMotion];
        [self.bannerView startLiveEffectsWithDuration:kPPChatNoticeVisibleDuration];
        return;
    }

    self.isVisible = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:0.18 animations:^{
            self.bannerView.alpha = 1.0;
        }];
        return;
    }

    self.bannerView.alpha = 0.0;
    self.bannerView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -30.0),
                                                       CGAffineTransformMakeScale(0.985, 0.985));

    [UIView animateWithDuration:0.46
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.72
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self.bannerView startLiveEffectsWithDuration:kPPChatNoticeVisibleDuration];
}

- (void)pp_refreshVisibleBannerMotion
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        return;
    }

    self.bannerView.transform = CGAffineTransformMakeScale(0.985, 0.985);
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_hideBannerAnimated:(BOOL)animated completion:(void (^ _Nullable)(void))completion
{
    if (!self.isVisible && self.bannerView.hidden) {
        if (completion) completion();
        return;
    }

    self.isVisible = NO;
    [self.bannerView stopLiveEffects];

    void (^finish)(void) = ^{
        self.bannerView.hidden = YES;
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        self.overlayWindow.hidden = YES;
        self.currentUserInfo = nil;
        if (completion) completion();
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        finish();
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformMakeTranslation(0, -24.0);
    } completion:^(__unused BOOL finished) {
        finish();
    }];
}

- (void)pp_scheduleDismiss
{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t work = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_hideBannerAnimated:YES completion:nil];
    });
    self.dismissWork = work;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPChatNoticeVisibleDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   work);
}

- (void)pp_cancelDismissWork
{
    if (self.dismissWork) {
        dispatch_block_cancel(self.dismissWork);
        self.dismissWork = nil;
    }
}

#pragma mark - Touch

- (void)pp_bannerTouchDown:(UIControl *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.982, 0.982);
    } completion:nil];
}

- (void)pp_bannerTouchCancel:(UIControl *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_bannerTapped:(UIControl *)sender
{
    (void)sender;
    NSDictionary<NSString *, id> *userInfo = self.currentUserInfo.copy;
    if (userInfo.count == 0) {
        [self dismissCurrentNotificationAnimated:YES];
        return;
    }

    [[PPChatFeedbackManager shared] playFeedbackForEvent:PPChatFeedbackEventIncomingOutsideChat];

    [self pp_cancelDismissWork];
    [self pp_hideBannerAnimated:YES completion:^{
        UIViewController *topVC = [AppMgr topViewController];
        if (!topVC) {
            topVC = [self pp_fallbackTopViewController];
        }
        if (topVC) {
            [ChManager sharedManager].isHandlingNotificationHandoff = YES;
            [[ChNotificationRouter shared] handleChatNotification:userInfo fromViewController:topVC];
        }
    }];
}

- (UIViewController *)pp_fallbackTopViewController
{
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window == self.overlayWindow ||
            window.hidden ||
            window.alpha <= 0.01 ||
            !window.rootViewController) {
            continue;
        }
        UIViewController *candidate = [self pp_topViewControllerFromRoot:window.rootViewController];
        if (candidate) {
            return candidate;
        }
    }
    return nil;
}

- (UIViewController *)pp_topViewControllerFromRoot:(UIViewController *)rootViewController
{
    UIViewController *candidate = rootViewController;
    while (candidate.presentedViewController) {
        candidate = candidate.presentedViewController;
    }
    if ([candidate isKindOfClass:UINavigationController.class]) {
        return [self pp_topViewControllerFromRoot:((UINavigationController *)candidate).topViewController];
    }
    if ([candidate isKindOfClass:UITabBarController.class]) {
        return [self pp_topViewControllerFromRoot:((UITabBarController *)candidate).selectedViewController];
    }
    return candidate;
}

@end
