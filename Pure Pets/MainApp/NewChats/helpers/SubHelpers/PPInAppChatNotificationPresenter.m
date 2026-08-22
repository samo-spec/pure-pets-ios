//
//  PPInAppChatNotificationPresenter.m
//  Pure Pets
//

#import "PPInAppChatNotificationPresenter.h"
#import "ChatThreadModel.h"
#import "PPChatFeedbackManager.h"
#import "ChatMessageModel.h"
#import "ChManager.h"
#import "ChNotificationRouter.h"
#import "PPModernAvatarRenderer.h"
#import "UserModel.h"

static CGFloat const kPPChatNoticeHorizontalInset = 14.0;
static CGFloat const kPPChatNoticeTopInset = 8.0;
static CGFloat const kPPChatNoticeMinHeight = 82.0;
static CGFloat const kPPChatNoticeAccessibilityHeight = 124.0;
static CGFloat const kPPChatNoticeMaxWidth = 520.0;
static CGFloat const kPPChatNoticeIdentitySize = 52.0;
static CGFloat const kPPChatNoticeAvatarSize = 40.0;
static CGFloat const kPPChatNoticeActionSize = 36.0;
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
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) UIView *identityFieldView;
@property (nonatomic, strong) CAGradientLayer *identityGradientLayer;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIView *textContainerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIView *actionFieldView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) CAGradientLayer *liveLineLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) UserModel *displayUser;
@property (nonatomic, copy) NSString *avatarURLString;
- (void)configureWithThread:(nullable ChatThreadModel *)thread
                    message:(ChatMessageModel *)message
                   animated:(BOOL)animated;
- (void)prepareForEntrance;
- (void)animateEntranceDetails;
- (void)resetEntranceDetails;
- (void)playRefreshAccent;
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
    self.clipsToBounds = NO;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.clipsToBounds = YES;
    surface.userInteractionEnabled = NO;
    PPApplyContinuousCorners(surface, PPCornerCard);
    self.surfaceView = surface;
    [self addSubview:surface];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    blur.userInteractionEnabled = NO;
    self.blurView = blur;
    [surface addSubview:blur];

    UIView *tint = [[UIView alloc] init];
    tint.translatesAutoresizingMaskIntoConstraints = NO;
    tint.userInteractionEnabled = NO;
    self.tintView = tint;
    [surface addSubview:tint];

    CAGradientLayer *surfaceGradient = [CAGradientLayer layer];
    surfaceGradient.locations = @[@0.0, @0.58, @1.0];
    self.surfaceGradientLayer = surfaceGradient;
    [tint.layer insertSublayer:surfaceGradient atIndex:0];

    UIView *identityField = [[UIView alloc] init];
    identityField.translatesAutoresizingMaskIntoConstraints = NO;
    identityField.clipsToBounds = YES;
    identityField.userInteractionEnabled = NO;
    identityField.isAccessibilityElement = NO;
    PPApplyContinuousCorners(identityField, PPCornerMedium);
    self.identityFieldView = identityField;
    [surface addSubview:identityField];

    CAGradientLayer *identityGradient = [CAGradientLayer layer];
    identityGradient.startPoint = CGPointMake(0.0, 0.0);
    identityGradient.endPoint = CGPointMake(1.0, 1.0);
    self.identityGradientLayer = identityGradient;
    [identityField.layer insertSublayer:identityGradient atIndex:0];

    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.isAccessibilityElement = NO;
    PPApplyContinuousCorners(avatar, kPPChatNoticeAvatarSize / 2.0);
    self.avatarView = avatar;
    [identityField addSubview:avatar];

    UIView *textContainer = [[UIView alloc] init];
    textContainer.translatesAutoresizingMaskIntoConstraints = NO;
    textContainer.userInteractionEnabled = NO;
    textContainer.isAccessibilityElement = NO;
    self.textContainerView = textContainer;
    [surface addSubview:textContainer];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *titleFont = [GM boldFontWithSize:PPFontHeadline]
        ?: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:titleFont];
    title.adjustsFontForContentSizeCategory = YES;
    title.numberOfLines = 1;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    [title setContentCompressionResistancePriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisVertical];
    self.titleLabel = title;
    [textContainer addSubview:title];

    UILabel *message = [[UILabel alloc] init];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *messageFont = [GM fontWithSize:PPFontSubheadline]
        ?: [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    message.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:messageFont];
    message.adjustsFontForContentSizeCategory = YES;
    message.numberOfLines = 2;
    message.lineBreakMode = NSLineBreakByTruncatingTail;
    message.textAlignment = [Language alignmentForCurrentLanguage];
    [message setContentCompressionResistancePriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisVertical];
    self.messageLabel = message;
    [textContainer addSubview:message];

    UIView *actionField = [[UIView alloc] init];
    actionField.translatesAutoresizingMaskIntoConstraints = NO;
    actionField.userInteractionEnabled = NO;
    actionField.isAccessibilityElement = NO;
    PPApplyContinuousCorners(actionField, kPPChatNoticeActionSize / 2.0);
    self.actionFieldView = actionField;
    [surface addSubview:actionField];

    UIImageView *chevron = [[UIImageView alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.isAccessibilityElement = NO;
    chevron.tintColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:12.0
                                 weight:UIImageSymbolWeightBold];
        chevron.image = [UIImage systemImageNamed:@"chevron.forward" withConfiguration:cfg];
    }
    self.chevronView = chevron;
    [actionField addSubview:chevron];

    CAGradientLayer *line = [CAGradientLayer layer];
    line.startPoint = CGPointMake(0.5, 0.0);
    line.endPoint = CGPointMake(0.5, 1.0);
    line.cornerRadius = 1.5;
    line.opacity = 0.78;
    self.liveLineLayer = line;
    [surface.layer addSublayer:line];

    CAShapeLayer *progress = [CAShapeLayer layer];
    progress.fillColor = UIColor.clearColor.CGColor;
    progress.lineCap = kCALineCapRound;
    progress.lineWidth = 1.75;
    progress.opacity = 0.62;
    self.progressLayer = progress;
    [surface.layer addSublayer:progress];

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

        [identityField.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceMD],
        [identityField.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [identityField.widthAnchor constraintEqualToConstant:kPPChatNoticeIdentitySize],
        [identityField.heightAnchor constraintEqualToConstant:kPPChatNoticeIdentitySize],

        [avatar.centerXAnchor constraintEqualToAnchor:identityField.centerXAnchor],
        [avatar.centerYAnchor constraintEqualToAnchor:identityField.centerYAnchor],
        [avatar.widthAnchor constraintEqualToConstant:kPPChatNoticeAvatarSize],
        [avatar.heightAnchor constraintEqualToConstant:kPPChatNoticeAvatarSize],

        [actionField.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceMD],
        [actionField.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [actionField.widthAnchor constraintEqualToConstant:kPPChatNoticeActionSize],
        [actionField.heightAnchor constraintEqualToConstant:kPPChatNoticeActionSize],

        [chevron.centerXAnchor constraintEqualToAnchor:actionField.centerXAnchor],
        [chevron.centerYAnchor constraintEqualToAnchor:actionField.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:12.0],
        [chevron.heightAnchor constraintEqualToConstant:16.0],

        [textContainer.leadingAnchor constraintEqualToAnchor:identityField.trailingAnchor constant:PPSpaceMD],
        [textContainer.trailingAnchor constraintEqualToAnchor:actionField.leadingAnchor constant:-PPSpaceSM],
        [textContainer.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [textContainer.topAnchor constraintGreaterThanOrEqualToAnchor:surface.topAnchor constant:PPSpaceSM],
        [textContainer.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-PPSpaceSM],

        [title.topAnchor constraintEqualToAnchor:textContainer.topAnchor],
        [title.leadingAnchor constraintEqualToAnchor:textContainer.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:textContainer.trailingAnchor],

        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:1.0],
        [message.leadingAnchor constraintEqualToAnchor:textContainer.leadingAnchor],
        [message.trailingAnchor constraintEqualToAnchor:textContainer.trailingAnchor],
        [message.bottomAnchor constraintEqualToAnchor:textContainer.bottomAnchor]
    ]];

    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.layer.shadowRadius = 16.0;
    self.layer.shadowOpacity = 0.12;
    [self pp_updateContentAdaptation];
}

- (CGSize)intrinsicContentSize
{
    BOOL accessibilitySize = UIContentSizeCategoryIsAccessibilityCategory(
        self.traitCollection.preferredContentSizeCategory
    );
    return CGSizeMake(
        UIViewNoIntrinsicMetric,
        accessibilitySize
            ? kPPChatNoticeAccessibilityHeight
            : kPPChatNoticeMinHeight
    );
}

- (void)pp_updateContentAdaptation
{
    BOOL accessibilitySize = UIContentSizeCategoryIsAccessibilityCategory(
        self.traitCollection.preferredContentSizeCategory
    );
    self.messageLabel.numberOfLines = accessibilitySize ? 3 : 2;
    [self invalidateIntrinsicContentSize];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_applyTheme];

    CGFloat height = self.surfaceView.bounds.size.height;
    CGFloat width = self.surfaceView.bounds.size.width;
    BOOL isRTL = Language.isRTL;

    self.surfaceGradientLayer.frame = self.tintView.bounds;
    self.surfaceGradientLayer.startPoint = CGPointMake(isRTL ? 1.0 : 0.0, 0.5);
    self.surfaceGradientLayer.endPoint = CGPointMake(isRTL ? 0.0 : 1.0, 0.5);
    self.identityGradientLayer.frame = self.identityFieldView.bounds;

    CGFloat lineWidth = 3.0;
    CGFloat lineX = isRTL ? width - lineWidth : 0.0;
    self.liveLineLayer.frame = CGRectMake(
        lineX,
        PPSpaceBase,
        lineWidth,
        MAX(1.0, height - (PPSpaceBase * 2.0))
    );

    CGFloat progressInset = PPSpaceLG;
    CGFloat progressWidth = MAX(1.0, width - (progressInset * 2.0));
    self.progressLayer.frame = CGRectMake(progressInset, height - 3.5, progressWidth, 1.75);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0.0, 0.875)];
    [path addLineToPoint:CGPointMake(progressWidth, 0.875)];
    self.progressLayer.path = path.CGPath;

    self.layer.shadowPath = [UIBezierPath
        bezierPathWithRoundedRect:self.bounds
                    cornerRadius:PPCornerCard].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory
            isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        [self pp_updateContentAdaptation];
    }
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
            ? [UIColor colorWithRed:0.070 green:0.064 blue:0.078 alpha:0.90]
            : [UIColor colorWithRed:1.000 green:0.985 blue:0.990 alpha:0.94];
    }];
    UIColor *borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:1.0 alpha:0.16]
            : [UIColor colorWithWhite:0.18 alpha:0.09];
    }];
    UIColor *actionColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:1.0 alpha:0.085]
            : [UIColor colorWithWhite:0.12 alpha:0.045];
    }];
    UIColor *accent = AppPrimaryClr ?: [UIColor systemPinkColor];
    UIColor *resolvedAccent = [accent resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *resolvedBorder = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL increasedContrast = self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;

    self.tintView.backgroundColor = surfaceColor;
    self.blurView.alpha = dark ? 0.82 : 0.90;
    self.surfaceView.layer.borderColor = resolvedBorder.CGColor;
    self.surfaceView.layer.borderWidth = increasedContrast ? 1.25 : 0.8;
    self.surfaceGradientLayer.colors = @[
        (__bridge id)[resolvedAccent colorWithAlphaComponent:dark ? 0.15 : 0.10].CGColor,
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:dark ? 0.015 : 0.10].CGColor
    ];
    self.identityGradientLayer.colors = @[
        (__bridge id)[resolvedAccent colorWithAlphaComponent:dark ? 0.24 : 0.16].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:dark ? 0.09 : 0.045].CGColor
    ];
    self.identityFieldView.layer.borderColor =
        [resolvedAccent colorWithAlphaComponent:dark ? 0.28 : 0.18].CGColor;
    self.identityFieldView.layer.borderWidth = increasedContrast ? 1.25 : 0.75;
    self.actionFieldView.backgroundColor = actionColor;
    self.actionFieldView.layer.borderColor = resolvedBorder.CGColor;
    self.actionFieldView.layer.borderWidth = increasedContrast ? 1.0 : 0.6;
    self.liveLineLayer.colors = @[
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.10].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.92].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.10].CGColor
    ];
    self.progressLayer.strokeColor = [resolvedAccent colorWithAlphaComponent:0.62].CGColor;
    self.layer.shadowOpacity = dark ? 0.22 : 0.12;
}

- (void)configureWithThread:(nullable ChatThreadModel *)thread
                    message:(ChatMessageModel *)message
                   animated:(BOOL)animated
{
    UIView *previousCopy = nil;
    if (animated && self.window && !UIAccessibilityIsReduceMotionEnabled()) {
        [self layoutIfNeeded];
        previousCopy = [self.textContainerView snapshotViewAfterScreenUpdates:NO];
        previousCopy.frame = self.textContainerView.frame;
        previousCopy.userInteractionEnabled = NO;
        [self.surfaceView addSubview:previousCopy];
    }

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
    BOOL isSupportIdentity = [avatarURL hasPrefix:kPPChatNoticeSupportAvatarToken];
    self.avatarView.contentMode = isSupportIdentity
        ? UIViewContentModeScaleAspectFit
        : UIViewContentModeScaleAspectFill;
    self.avatarView.layer.cornerRadius = isSupportIdentity
        ? 0.0
        : kPPChatNoticeAvatarSize / 2.0;
    if (isSupportIdentity) {
        self.avatarView.image = [UIImage imageNamed:@"tintLogo"] ?: placeholder;
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

    if (previousCopy) {
        self.textContainerView.alpha = 0.0;
        self.textContainerView.transform = CGAffineTransformMakeTranslation(0.0, 5.0);
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            previousCopy.alpha = 0.0;
            previousCopy.transform = CGAffineTransformMakeTranslation(0.0, -4.0);
            self.textContainerView.alpha = 1.0;
            self.textContainerView.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL finished) {
            [previousCopy removeFromSuperview];
        }];
    } else {
        self.textContainerView.alpha = 1.0;
        self.textContainerView.transform = CGAffineTransformIdentity;
    }
}

- (void)prepareForEntrance
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self resetEntranceDetails];
        return;
    }

    CGFloat actionOffset = Language.isRTL ? -5.0 : 5.0;
    self.identityFieldView.alpha = 0.0;
    self.identityFieldView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    self.actionFieldView.alpha = 0.0;
    self.actionFieldView.transform = CGAffineTransformMakeTranslation(actionOffset, 0.0);
}

- (void)animateEntranceDetails
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self resetEntranceDetails];
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.05
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.identityFieldView.alpha = 1.0;
        self.identityFieldView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.20
                          delay:0.09
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.actionFieldView.alpha = 1.0;
        self.actionFieldView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)resetEntranceDetails
{
    self.identityFieldView.alpha = 1.0;
    self.identityFieldView.transform = CGAffineTransformIdentity;
    self.actionFieldView.alpha = 1.0;
    self.actionFieldView.transform = CGAffineTransformIdentity;
}

- (void)playRefreshAccent
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [self.liveLineLayer removeAnimationForKey:@"pp.chat.notice.line.pulse"];
    CABasicAnimation *accent = [CABasicAnimation animationWithKeyPath:@"opacity"];
    accent.fromValue = @0.38;
    accent.toValue = @0.92;
    accent.duration = 0.24;
    accent.autoreverses = YES;
    accent.repeatCount = 1.0;
    accent.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.liveLineLayer addAnimation:accent forKey:@"pp.chat.notice.line.refresh"];
}

- (void)startLiveEffectsWithDuration:(NSTimeInterval)duration
{
    [self stopLiveEffects];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.40;
    pulse.toValue = @0.92;
    pulse.duration = 0.34;
    pulse.autoreverses = YES;
    pulse.repeatCount = 1.0;
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
    progress.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.progressLayer addAnimation:progress forKey:@"pp.chat.notice.progress"];
}

- (void)stopLiveEffects
{
    [self.liveLineLayer removeAnimationForKey:@"pp.chat.notice.line.pulse"];
    [self.liveLineLayer removeAnimationForKey:@"pp.chat.notice.line.refresh"];
    [self.progressLayer removeAnimationForKey:@"pp.chat.notice.progress"];
    self.liveLineLayer.opacity = 0.78;
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
        if (!self.overlayWindow || !self.bannerView) {
            [self pp_cancelDismissWork];
            self.currentUserInfo = nil;
            return;
        }
        BOOL updatesVisibleBanner = self.isVisible && !self.bannerView.hidden;
        [self.bannerView configureWithThread:thread
                                     message:message
                                    animated:updatesVisibleBanner];
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
    UIWindowScene *activeScene = [self pp_activeWindowScene];

    if (self.overlayWindow && self.bannerView.superview) {
        UIWindowScene *scene = self.overlayWindow.windowScene;
        if (scene && scene == activeScene && scene.activationState == UISceneActivationStateForegroundActive) {
            self.overlayWindow.hidden = NO;
            return;
        }
        [self.bannerView stopLiveEffects];
        [self.bannerView.layer removeAllAnimations];
        self.overlayWindow.hidden = YES;
        self.overlayWindow = nil;
        self.bannerView = nil;
        self.isVisible = NO;
    }

    if (!activeScene) {
        return;
    }

    PPChatNoticePassthroughWindow *window = [[PPChatNoticePassthroughWindow alloc] initWithWindowScene:activeScene];
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
    NSLayoutConstraint *fillAvailableWidth = [banner.widthAnchor
        constraintEqualToAnchor:root.view.widthAnchor
                     constant:-(kPPChatNoticeHorizontalInset * 2.0)];
    fillAvailableWidth.priority = 999;
    NSLayoutConstraint *preferredMaxWidth = [banner.widthAnchor
        constraintEqualToConstant:kPPChatNoticeMaxWidth];
    preferredMaxWidth.priority = 998;

    [NSLayoutConstraint activateConstraints:@[
        [banner.topAnchor constraintEqualToAnchor:safe.topAnchor constant:kPPChatNoticeTopInset],
        [banner.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.view.leadingAnchor constant:kPPChatNoticeHorizontalInset],
        [banner.trailingAnchor constraintLessThanOrEqualToAnchor:root.view.trailingAnchor constant:-kPPChatNoticeHorizontalInset],
        [banner.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
        widthLimit,
        fillAvailableWidth,
        preferredMaxWidth,
        [banner.heightAnchor constraintGreaterThanOrEqualToConstant:kPPChatNoticeMinHeight]
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
        [self.bannerView startLiveEffectsWithDuration:kPPChatNoticeVisibleDuration];
        [self pp_refreshVisibleBannerMotion];
        return;
    }

    self.isVisible = YES;
    [self.bannerView prepareForEntrance];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:0.14 animations:^{
            self.bannerView.alpha = 1.0;
        }];
        [self.bannerView resetEntranceDetails];
        return;
    }

    self.bannerView.alpha = 0.0;
    self.bannerView.transform = CGAffineTransformConcat(
        CGAffineTransformMakeTranslation(0.0, -18.0),
        CGAffineTransformMakeScale(0.985, 0.985)
    );

    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:1.0
          initialSpringVelocity:0.42
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self.bannerView animateEntranceDetails];
    [self.bannerView startLiveEffectsWithDuration:kPPChatNoticeVisibleDuration];
}

- (void)pp_refreshVisibleBannerMotion
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        [self.bannerView resetEntranceDetails];
        return;
    }

    self.bannerView.alpha = 1.0;
    self.bannerView.transform = CGAffineTransformIdentity;
    [self.bannerView resetEntranceDetails];
    [self.bannerView playRefreshAccent];
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
        [self.bannerView resetEntranceDetails];
        self.overlayWindow.hidden = YES;
        self.currentUserInfo = nil;
        if (completion) completion();
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        finish();
        return;
    }

    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformConcat(
            CGAffineTransformMakeTranslation(0.0, -14.0),
            CGAffineTransformMakeScale(0.99, 0.99)
        );
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
        sender.transform = CGAffineTransformMakeScale(0.992, 0.992);
    } completion:nil];
}

- (void)pp_bannerTouchCancel:(UIControl *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:1.0
          initialSpringVelocity:0.32
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
