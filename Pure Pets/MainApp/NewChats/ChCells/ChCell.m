//
//  ChCell.m
//  Pure Pets
//
//  Premium Chat Thread Cell
//
//  Visual thesis: one quiet, softly elevated material surface with the
//  avatar as its human anchor and unread emphasis carried by typography.
//  Structure thesis: identity and time first, conversation preview second,
//  one compact unread signal last.
//  Motion thesis: immediate material press response, truthful state
//  transitions, and a restrained presence breath while the cell is visible.
//  Risk thesis: reusable-cell motion must never replay during scrolling,
//  obscure content, or continue offscreen.
//

#import "ChCell.h"

#import "ChatPresenceManager.h"
#import "ChatThreadModel.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "PPVerifiedBadgeHelper.h"
#import "UserModel.h"

#pragma mark - Design Tokens

static CGFloat const kCellHorizontalInset      = 0.0;
static CGFloat const kCellVerticalInset        = 0.0;
static CGFloat const kSurfaceMinimumHeight     = 76.0;
static CGFloat const kSurfaceCornerRadius      = 0.0;
static CGFloat const kSurfaceHorizontalInset   = 14.0;
static CGFloat const kSurfaceVerticalInset     = 10.0;
static CGFloat const kAvatarHaloSize           = 56.0;
static CGFloat const kAvatarSize               = 50.0;
static CGFloat const kAvatarTextSpacing        = PPSpaceMD;
static CGFloat const kTextMetaSpacing          = PPSpaceSM;
static CGFloat const kTextRowSpacing           = PPSpaceXS;
static CGFloat const kOnlineDotSize            = 10.0;
static CGFloat const kPresenceGlowSize         = 18.0;
static CGFloat const kOnlineDotBorderWidth     = 2.0;
static CGFloat const kUnreadBadgeHeight        = 20.0;
static CGFloat const kUnreadBadgeMinimumWidth  = 20.0;
static CGFloat const kVerifiedBadgeSize        = 15.0;
static CGFloat const kPressedSurfaceScale      = 0.988;
static CGFloat const kPressedAvatarScale       = 0.972;
static float const kAmbientRestingOpacity      = 0.88f;

static BOOL PPIsSupportAvatarURL(NSString *url) {
    return [url hasPrefix:@"purepets://support-logo"];
}

static UIImage *PPSupportAvatarImage(void) {
    return [UIImage imageNamed:@"newlogo"]
        ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

static UIFont *PPChatScaledFont(UIFont *font, UIFontTextStyle textStyle) {
    UIFont *resolvedFont = font ?: [UIFont preferredFontForTextStyle:textStyle];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle]
                scaledFontForFont:resolvedFont];
    }
    return resolvedFont;
}

static UIColor *PPChatResolvedColor(UIColor *color,
                                    UITraitCollection *traitCollection) {
    UIColor *resolvedColor = color ?: UIColor.clearColor;
    if (@available(iOS 13.0, *)) {
        return [resolvedColor resolvedColorWithTraitCollection:traitCollection];
    }
    return resolvedColor;
}

@interface ChCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) CAGradientLayer *ambientGradientLayer;
@property (nonatomic, strong) UIView *avatarHaloView;
@property (nonatomic, strong) RoundedImageViewWithShadow *avatarView;
@property (nonatomic, strong) UIView *presenceGlowView;
@property (nonatomic, strong) UIView *onlineDot;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *unreadBadge;
@property (nonatomic, strong) UIImageView *verifiedBadgeView;
@property (nonatomic, strong) NSLayoutConstraint *badgeWidthConstraint;
@property (nonatomic, copy) NSString *presenceAccessibilityText;
@property (nonatomic, assign) NSInteger currentUnreadCount;
@property (nonatomic, assign) BOOL currentOnline;
@property (nonatomic, assign) BOOL hasConfiguredContent;
@property (nonatomic, assign) BOOL isConfiguring;
@property (nonatomic, strong) UIView *separatorView;

@end

@implementation ChCell

#pragma mark - Lifecycle

+ (NSString *)reuseID {
    return NSStringFromClass(self);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;
    self.isAccessibilityElement = YES;
    self.shouldGroupAccessibilityChildren = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityIdentifier = @"chatThreadCell";

    [self pp_applyLanguageDirection];
    [self pp_buildUI];
    [self pp_buildLayout];
    [self pp_applyTypographyForCurrentState];
    [self pp_refreshChromeAnimated:NO];
    [self pp_updateAccessibility];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_reduceMotionStatusDidChange:)
               name:UIAccessibilityReduceMotionStatusDidChangeNotification
             object:nil];

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[PPImageLoaderManager shared]
        cancelImageLoadForImageView:self.avatarView.imageView];
    [self pp_stopPresenceBreathing];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.ambientGradientLayer.frame = self.surfaceView.bounds;
    self.ambientGradientLayer.cornerRadius = kSurfaceCornerRadius;
    self.ambientGradientLayer.startPoint =
        [self pp_isRTL] ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    self.ambientGradientLayer.endPoint =
        [self pp_isRTL] ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);

    self.surfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                   cornerRadius:kSurfaceCornerRadius].CGPath;

    [CATransaction commit];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];

    if (self.window && self.currentOnline) {
        [self pp_startPresenceBreathingIfNeeded];
    } else {
        [self pp_stopPresenceBreathing];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];

    [[PPImageLoaderManager shared]
        cancelImageLoadForImageView:self.avatarView.imageView];

    self.representedUserID = nil;
    self.representedAvatarURL = nil;
    self.presenceAccessibilityText = nil;
    self.currentUnreadCount = 0;
    self.currentOnline = NO;
    self.hasConfiguredContent = NO;
    self.isConfiguring = NO;

    self.nameLabel.text = nil;
    self.messageLabel.text = nil;
    self.timeLabel.text = nil;
    self.unreadBadge.text = nil;
    self.unreadBadge.hidden = YES;
    self.badgeWidthConstraint.constant = 0.0;

    self.verifiedBadgeView.hidden = YES;
    self.onlineDot.hidden = YES;
    self.presenceGlowView.hidden = YES;

    [self.avatarView.imageView.layer removeAllAnimations];
    self.avatarView.imageView.alpha = 1.0;
    self.avatarView.imageView.image =
        [UIImage systemImageNamed:@"person.crop.circle.fill"];
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.backgroundColor = UIColor.clearColor;

    [self pp_resetMotionState];
    [self pp_applyTypographyForCurrentState];
    [self pp_refreshChromeAnimated:NO];
    [self pp_updateAccessibility];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    BOOL colorAppearanceChanged = YES;
    if (@available(iOS 13.0, *)) {
        colorAppearanceChanged =
            !previousTraitCollection ||
            [self.traitCollection
             hasDifferentColorAppearanceComparedToTraitCollection:
             previousTraitCollection];
    }

    BOOL contentSizeChanged =
        !previousTraitCollection ||
        ![previousTraitCollection.preferredContentSizeCategory
          isEqualToString:self.traitCollection.preferredContentSizeCategory];

    if (contentSizeChanged) {
        [self pp_applyTypographyForCurrentState];
        [self setNeedsLayout];
    }
    if (colorAppearanceChanged) {
        [self pp_refreshChromeAnimated:NO];
    }
}

#pragma mark - Build UI

- (void)pp_buildUI {
    self.surfaceView = [UIView new];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.clipsToBounds = NO;
    self.surfaceView.layer.cornerRadius = kSurfaceCornerRadius;
    self.surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.surfaceView];

    self.ambientGradientLayer = [CAGradientLayer layer];
    self.ambientGradientLayer.locations = @[@0.0, @0.48, @1.0];
    self.ambientGradientLayer.opacity = kAmbientRestingOpacity;
    self.ambientGradientLayer.masksToBounds = YES;
    self.ambientGradientLayer.cornerRadius = kSurfaceCornerRadius;
    if (@available(iOS 13.0, *)) {
        self.ambientGradientLayer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView.layer insertSublayer:self.ambientGradientLayer atIndex:0];

    self.avatarHaloView = [UIView new];
    self.avatarHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarHaloView.clipsToBounds = NO;
    self.avatarHaloView.layer.cornerRadius = kAvatarHaloSize * 0.5;
    self.avatarHaloView.layer.borderWidth = 1.0;
    self.avatarHaloView.isAccessibilityElement = NO;
    [self.surfaceView addSubview:self.avatarHaloView];

    self.presenceGlowView = [UIView new];
    self.presenceGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.presenceGlowView.hidden = YES;
    self.presenceGlowView.userInteractionEnabled = NO;
    self.presenceGlowView.layer.cornerRadius = kPresenceGlowSize * 0.5;
    self.presenceGlowView.isAccessibilityElement = NO;
    [self.avatarHaloView addSubview:self.presenceGlowView];

    self.avatarView =
        [[RoundedImageViewWithShadow alloc]
         initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.backgroundColor = UIColor.clearColor;
    self.avatarView.layer.borderWidth = 0.0;
    self.avatarView.layer.shadowOpacity = 0.0;
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.clipsToBounds = YES;
    self.avatarView.imageView.isAccessibilityElement = NO;
    self.avatarView.imageView.accessibilityIgnoresInvertColors = YES;
    [self.avatarHaloView addSubview:self.avatarView];

    self.onlineDot = [UIView new];
    self.onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.onlineDot.hidden = YES;
    self.onlineDot.layer.cornerRadius = kOnlineDotSize * 0.5;
    self.onlineDot.layer.borderWidth = kOnlineDotBorderWidth;
    self.onlineDot.isAccessibilityElement = NO;
    [self.avatarHaloView addSubview:self.onlineDot];

    self.verifiedBadgeView =
        [PPVerifiedBadgeHelper addBadgeToAvatarView:self.avatarView
                                        inSuperview:self.surfaceView
                                          badgeSize:kVerifiedBadgeSize];
    self.verifiedBadgeView.hidden = YES;
    self.verifiedBadgeView.isAccessibilityElement = NO;
    self.verifiedBadgeView.accessibilityIgnoresInvertColors = YES;

    self.nameLabel = [UILabel new];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.numberOfLines = 1;
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.allowsDefaultTighteningForTruncation = YES;
    self.nameLabel.adjustsFontForContentSizeCategory = YES;
    self.nameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.nameLabel.isAccessibilityElement = NO;
    [self.surfaceView addSubview:self.nameLabel];

    self.messageLabel = [UILabel new];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.numberOfLines = 1;
    self.messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.messageLabel.allowsDefaultTighteningForTruncation = YES;
    self.messageLabel.adjustsFontForContentSizeCategory = YES;
    self.messageLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.messageLabel.isAccessibilityElement = NO;
    [self.surfaceView addSubview:self.messageLabel];

    self.timeLabel = [UILabel new];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.numberOfLines = 1;
    self.timeLabel.adjustsFontForContentSizeCategory = YES;
    self.timeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.timeLabel.isAccessibilityElement = NO;
    [self.surfaceView addSubview:self.timeLabel];

    self.unreadBadge = [UILabel new];
    self.unreadBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.unreadBadge.font =
        [GM boldFontWithSize:PPFontCaption2]
        ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    self.unreadBadge.textAlignment = NSTextAlignmentCenter;
    self.unreadBadge.textColor = UIColor.whiteColor;
    self.unreadBadge.layer.cornerRadius = kUnreadBadgeHeight * 0.5;
    self.unreadBadge.layer.masksToBounds = YES;
    self.unreadBadge.hidden = YES;
    self.unreadBadge.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        self.unreadBadge.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.unreadBadge];

    [self.nameLabel
        setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.messageLabel
        setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel
        setContentCompressionResistancePriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel
        setContentHuggingPriority:UILayoutPriorityRequired
                          forAxis:UILayoutConstraintAxisHorizontal];
    [self.unreadBadge
        setContentCompressionResistancePriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.unreadBadge
        setContentHuggingPriority:UILayoutPriorityRequired
                          forAxis:UILayoutConstraintAxisHorizontal];

    self.separatorView = [UIView new];
    self.separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        self.separatorView.backgroundColor = [UIColor separatorColor];
    } else {
        self.separatorView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    }
    [self.surfaceView addSubview:self.separatorView];
}

#pragma mark - Layout

- (void)pp_buildLayout {
    self.badgeWidthConstraint =
        [self.unreadBadge.widthAnchor constraintEqualToConstant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor
            constraintEqualToAnchor:self.contentView.topAnchor
                           constant:kCellVerticalInset],
        [self.surfaceView.bottomAnchor
            constraintEqualToAnchor:self.contentView.bottomAnchor
                           constant:-kCellVerticalInset],
        [self.surfaceView.leadingAnchor
            constraintEqualToAnchor:self.contentView.leadingAnchor
                           constant:kCellHorizontalInset],
        [self.surfaceView.trailingAnchor
            constraintEqualToAnchor:self.contentView.trailingAnchor
                           constant:-kCellHorizontalInset],
        [self.surfaceView.heightAnchor
            constraintGreaterThanOrEqualToConstant:kSurfaceMinimumHeight],

        [self.avatarHaloView.leadingAnchor
            constraintEqualToAnchor:self.surfaceView.leadingAnchor
                           constant:kSurfaceHorizontalInset],
        [self.avatarHaloView.centerYAnchor
            constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.avatarHaloView.widthAnchor
            constraintEqualToConstant:kAvatarHaloSize],
        [self.avatarHaloView.heightAnchor
            constraintEqualToConstant:kAvatarHaloSize],
        [self.avatarHaloView.topAnchor
            constraintGreaterThanOrEqualToAnchor:self.surfaceView.topAnchor
                                        constant:kSurfaceVerticalInset],
        [self.avatarHaloView.bottomAnchor
            constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor
                                     constant:-kSurfaceVerticalInset],

        [self.avatarView.centerXAnchor
            constraintEqualToAnchor:self.avatarHaloView.centerXAnchor],
        [self.avatarView.centerYAnchor
            constraintEqualToAnchor:self.avatarHaloView.centerYAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:kAvatarSize],
        [self.avatarView.heightAnchor constraintEqualToConstant:kAvatarSize],

        [self.onlineDot.widthAnchor constraintEqualToConstant:kOnlineDotSize],
        [self.onlineDot.heightAnchor constraintEqualToConstant:kOnlineDotSize],
        [self.onlineDot.centerXAnchor
            constraintEqualToAnchor:self.avatarView.leadingAnchor],
        [self.onlineDot.centerYAnchor
            constraintEqualToAnchor:self.avatarView.bottomAnchor
                           constant:-2.0],

        [self.presenceGlowView.widthAnchor
            constraintEqualToConstant:kPresenceGlowSize],
        [self.presenceGlowView.heightAnchor
            constraintEqualToConstant:kPresenceGlowSize],
        [self.presenceGlowView.centerXAnchor
            constraintEqualToAnchor:self.onlineDot.centerXAnchor],
        [self.presenceGlowView.centerYAnchor
            constraintEqualToAnchor:self.onlineDot.centerYAnchor],

        [self.nameLabel.leadingAnchor
            constraintEqualToAnchor:self.avatarHaloView.trailingAnchor
                           constant:kAvatarTextSpacing],
        [self.nameLabel.trailingAnchor
            constraintEqualToAnchor:self.timeLabel.leadingAnchor
                           constant:-kTextMetaSpacing],
        [self.nameLabel.topAnchor
            constraintGreaterThanOrEqualToAnchor:self.surfaceView.topAnchor
                                        constant:kSurfaceVerticalInset + PPSpaceXXS],

        [self.timeLabel.trailingAnchor
            constraintEqualToAnchor:self.surfaceView.trailingAnchor
                           constant:-kSurfaceHorizontalInset],
        [self.timeLabel.firstBaselineAnchor
            constraintEqualToAnchor:self.nameLabel.firstBaselineAnchor],

        [self.messageLabel.leadingAnchor
            constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.messageLabel.trailingAnchor
            constraintEqualToAnchor:self.unreadBadge.leadingAnchor
                           constant:-kTextMetaSpacing],
        [self.messageLabel.topAnchor
            constraintEqualToAnchor:self.nameLabel.bottomAnchor
                           constant:kTextRowSpacing],
        [self.messageLabel.bottomAnchor
            constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor
                                     constant:-(kSurfaceVerticalInset + PPSpaceXXS)],

        [self.unreadBadge.trailingAnchor
            constraintEqualToAnchor:self.surfaceView.trailingAnchor
                           constant:-kSurfaceHorizontalInset],
        [self.unreadBadge.centerYAnchor
            constraintEqualToAnchor:self.messageLabel.centerYAnchor],
        [self.unreadBadge.heightAnchor
            constraintEqualToConstant:kUnreadBadgeHeight],
        self.badgeWidthConstraint,
        [self.separatorView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        [self.separatorView.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        [self.separatorView.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.separatorView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
    ]];
}

#pragma mark - Configuration

- (void)configureWithThread:(ChatThreadModel *)thread {
    self.isConfiguring = YES;
    [self pp_resetMotionState];
    [self pp_applyLanguageDirection];

    UserModel *user =
        [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
    NSString *displayName =
        user.PPBestDisplayName ?: user.UserName ?: @"";
    NSDate *displayDate = thread.lastMessageAt ?: thread.timestamp;

    self.nameLabel.text = displayName;
    self.messageLabel.text = [self pp_previewForThread:thread];
    self.timeLabel.text = [self pp_timestampForDate:displayDate];
    self.verifiedBadgeView.hidden = !user.isVerified;

    [self pp_bindAvatarForUser:user];
    [self setUnreadCount:thread.unreadCount];

    BOOL online = NO;
    NSDate *lastSeen = nil;
    if (user.ID.length > 0) {
        online = [[ChatPresenceManager shared] isUserOnline:user.ID];
        lastSeen = [[ChatPresenceManager shared] lastSeenForUser:user.ID];
    }
    [self applyPresenceOnline:online lastSeen:lastSeen];

    self.isConfiguring = NO;
    self.hasConfiguredContent = YES;
    [self pp_refreshChromeAnimated:NO];
    [self pp_updateAccessibility];
}

- (void)setUnreadCount:(NSInteger)count {
    NSInteger normalizedCount = MAX(count, 0);
    NSInteger previousCount = self.currentUnreadCount;
    BOOL hadUnread = previousCount > 0;
    BOOL hasUnread = normalizedCount > 0;
    BOOL changed = normalizedCount != previousCount;

    self.currentUnreadCount = normalizedCount;
    [self pp_applyTypographyForCurrentState];

    NSString *badgeText = hasUnread
        ? (normalizedCount > 99 ? @"99+" : @(normalizedCount).stringValue)
        : nil;
    CGFloat targetWidth = 0.0;
    if (badgeText.length > 0) {
        CGFloat textWidth =
            [badgeText sizeWithAttributes:
             @{NSFontAttributeName: self.unreadBadge.font}].width;
        targetWidth =
            MAX(kUnreadBadgeMinimumWidth, ceil(textWidth) + 10.0);
    }

    BOOL animated = changed && [self pp_shouldAnimateStateChanges];
    if (!animated) {
        [self.unreadBadge.layer removeAllAnimations];
        self.badgeWidthConstraint.constant = targetWidth;
        self.unreadBadge.text = badgeText;
        self.unreadBadge.hidden = !hasUnread;
        self.unreadBadge.alpha = 1.0;
        self.unreadBadge.transform = CGAffineTransformIdentity;
        [self pp_refreshChromeAnimated:NO];
        [self pp_updateAccessibility];
        return;
    }

    [self.surfaceView layoutIfNeeded];

    if (hasUnread) {
        self.unreadBadge.text = badgeText;
        self.unreadBadge.hidden = NO;
        self.unreadBadge.alpha = hadUnread ? 1.0 : 0.0;
        self.unreadBadge.transform =
            CGAffineTransformMakeScale(hadUnread ? 0.92 : 0.78,
                                       hadUnread ? 0.92 : 0.78);
        self.badgeWidthConstraint.constant = targetWidth;

        [UIView animateWithDuration:0.26
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseOut |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction)
                         animations:^{
                             self.unreadBadge.alpha = 1.0;
                             self.unreadBadge.transform =
                                 CGAffineTransformIdentity;
                             [self.surfaceView layoutIfNeeded];
                         }
                         completion:nil];
    } else {
        self.badgeWidthConstraint.constant = 0.0;

        [UIView animateWithDuration:0.16
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction)
                         animations:^{
                             self.unreadBadge.alpha = 0.0;
                             self.unreadBadge.transform =
                                 CGAffineTransformMakeScale(0.78, 0.78);
                             [self.surfaceView layoutIfNeeded];
                         }
                         completion:^(__unused BOOL finished) {
                             if (self.currentUnreadCount == 0) {
                                 self.unreadBadge.hidden = YES;
                                 self.unreadBadge.text = nil;
                                 self.unreadBadge.alpha = 1.0;
                                 self.unreadBadge.transform =
                                     CGAffineTransformIdentity;
                             }
                         }];
    }

    [self pp_refreshChromeAnimated:YES];
    [self pp_updateAccessibility];
}

- (void)setOnline:(BOOL)isOnline {
    [self applyPresenceOnline:isOnline lastSeen:nil];
}

- (void)updatePresenceUI:(BOOL)isOnline {
    [self applyPresenceOnline:isOnline lastSeen:nil];
}

- (void)applyPresenceOnline:(BOOL)online
                   lastSeen:(NSDate *)lastSeen
{
    BOOL changed = self.currentOnline != online;
    self.currentOnline = online;
    self.presenceAccessibilityText =
        online ? kLang(@"chat.online") : [self pp_formattedLastSeen:lastSeen];

    BOOL animated = changed && [self pp_shouldAnimateStateChanges];
    [self pp_refreshChromeAnimated:animated];
    [self pp_updatePresenceIndicatorAnimated:animated];
    [self pp_updateAccessibility];
}

#pragma mark - Interaction

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self pp_applyPressAnimated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self pp_applyPressAnimated:animated];
}

- (void)pp_applyPressAnimated:(BOOL)animated {
    BOOL pressed = self.isHighlighted || self.isSelected;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    CGFloat targetAlpha = pressed ? 0.965 : 1.0;
    CGAffineTransform surfaceTransform =
        (!reduceMotion && pressed)
        ? CGAffineTransformMakeScale(kPressedSurfaceScale,
                                     kPressedSurfaceScale)
        : CGAffineTransformIdentity;
    CGAffineTransform avatarTransform =
        (!reduceMotion && pressed)
        ? CGAffineTransformMakeScale(kPressedAvatarScale,
                                     kPressedAvatarScale)
        : CGAffineTransformIdentity;

    void (^changes)(void) = ^{
        self.surfaceView.alpha = targetAlpha;
        self.surfaceView.transform = surfaceTransform;
        self.avatarHaloView.transform = avatarTransform;
        self.surfaceView.layer.shadowOpacity = 0.0;
        self.surfaceView.layer.shadowOffset = CGSizeZero;
    };

    NSTimeInterval duration = pressed ? 0.10 : 0.24;
    UIViewAnimationOptions options =
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction |
        (pressed ? UIViewAnimationOptionCurveEaseOut
                 : UIViewAnimationOptionCurveEaseInOut);

    if (!animated) {
        [UIView performWithoutAnimation:changes];
    } else {
        [UIView animateWithDuration:duration
                              delay:0.0
                            options:options
                         animations:changes
                         completion:nil];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    [CATransaction setAnimationDuration:duration];
    [CATransaction setAnimationTimingFunction:
        [CAMediaTimingFunction
         functionWithName:pressed
         ? kCAMediaTimingFunctionEaseOut
         : kCAMediaTimingFunctionEaseInEaseOut]];
    self.ambientGradientLayer.opacity =
        pressed ? 1.0f : kAmbientRestingOpacity;
    [CATransaction commit];
}

#pragma mark - Visual State

- (BOOL)pp_shouldAnimateStateChanges {
    return self.hasConfiguredContent &&
           !self.isConfiguring &&
           self.window != nil &&
           !UIAccessibilityIsReduceMotionEnabled();
}

- (void)pp_applyTypographyForCurrentState {
    BOOL hasUnread = self.currentUnreadCount > 0;

    UIFont *nameBaseFont =
        hasUnread
        ? ([GM boldFontWithSize:PPFontHeadline]
           ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold])
        : ([GM MidFontWithSize:PPFontHeadline]
           ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]);
    UIFont *messageBaseFont =
        hasUnread
        ? ([GM boldFontWithSize:PPFontSubheadline]
           ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold])
        : ([GM fontWithSize:PPFontSubheadline]
           ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular]);
    UIFont *timeBaseFont =
        hasUnread
        ? ([GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold])
        : ([GM fontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium]);

    self.nameLabel.font =
        PPChatScaledFont(nameBaseFont, UIFontTextStyleHeadline);
    self.messageLabel.font =
        PPChatScaledFont(messageBaseFont, UIFontTextStyleSubheadline);
    self.timeLabel.font =
        PPChatScaledFont(timeBaseFont, UIFontTextStyleCaption1);
}

- (void)pp_refreshChromeAnimated:(BOOL)animated {
    void (^changes)(void) = ^{
        [self pp_applyChromeValues];
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.28
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseInOut |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction)
                         animations:changes
                         completion:nil];
    } else {
        [UIView performWithoutAnimation:changes];
    }

    [self pp_updateAmbientGradientAnimated:
        animated && !UIAccessibilityIsReduceMotionEnabled()];
}

- (void)pp_applyChromeValues {
    UIColor *surfaceColor = [self pp_surfaceFillColor];
    UIColor *accentColor = [self pp_primaryAccentColor];
    BOOL hasUnread = self.currentUnreadCount > 0;
    BOOL pressed = self.isHighlighted || self.isSelected;

    if (pressed) {
        if (@available(iOS 13.0, *)) {
            self.surfaceView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
                return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor.whiteColor colorWithAlphaComponent:0.08]
                    : [UIColor.blackColor colorWithAlphaComponent:0.05];
            }];
        } else {
            self.surfaceView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.05];
        }
    } else {
        self.surfaceView.backgroundColor = UIColor.clearColor;
    }

    [self.surfaceView pp_setBorderColor:UIColor.clearColor];
    self.surfaceView.layer.shadowOpacity = 0.0;
    self.ambientGradientLayer.hidden = YES;

    self.avatarHaloView.backgroundColor = [self pp_avatarHaloFillColor];
    [self.avatarHaloView pp_setBorderColor:[self pp_avatarHaloBorderColor]];

    self.nameLabel.textColor = UIColor.labelColor;
    self.messageLabel.textColor =
        hasUnread ? UIColor.labelColor : UIColor.secondaryLabelColor;
    self.timeLabel.textColor =
        hasUnread ? accentColor : UIColor.tertiaryLabelColor;
    self.unreadBadge.backgroundColor = accentColor;

    self.onlineDot.backgroundColor = UIColor.systemGreenColor;
    [self.onlineDot pp_setBorderColor:surfaceColor];
    self.presenceGlowView.backgroundColor =
        [UIColor.systemGreenColor colorWithAlphaComponent:0.18];

    self.verifiedBadgeView.backgroundColor = surfaceColor;
    [self.verifiedBadgeView pp_setBorderColor:surfaceColor];
    self.avatarView.imageView.tintColor =
        [accentColor colorWithAlphaComponent:0.72];
}

- (void)pp_updateAmbientGradientAnimated:(BOOL)animated {
    UIColor *anchorColor = nil;
    UIColor *middleColor = nil;
    BOOL isDark = [self pp_isDarkMode];

    if (self.currentUnreadCount > 0) {
        UIColor *accent = [self pp_primaryAccentColor];
        anchorColor =
            [accent colorWithAlphaComponent:isDark ? 0.16 : 0.085];
        middleColor =
            [(self.currentOnline ? UIColor.systemGreenColor : accent)
             colorWithAlphaComponent:isDark ? 0.045 : 0.025];
    } else if (self.currentOnline) {
        anchorColor =
            [UIColor.systemGreenColor
             colorWithAlphaComponent:isDark ? 0.075 : 0.045];
        middleColor =
            [UIColor.systemGreenColor
             colorWithAlphaComponent:isDark ? 0.025 : 0.012];
    } else {
        anchorColor =
            [UIColor.whiteColor
             colorWithAlphaComponent:isDark ? 0.025 : 0.12];
        middleColor =
            [UIColor.whiteColor
             colorWithAlphaComponent:isDark ? 0.010 : 0.025];
    }

    UIColor *transparentAnchor = [anchorColor colorWithAlphaComponent:0.0];
    NSArray *targetColors = @[
        (__bridge id)PPChatResolvedColor(anchorColor,
                                         self.traitCollection).CGColor,
        (__bridge id)PPChatResolvedColor(middleColor,
                                         self.traitCollection).CGColor,
        (__bridge id)PPChatResolvedColor(transparentAnchor,
                                         self.traitCollection).CGColor,
    ];

    CAGradientLayer *presentationLayer =
        (CAGradientLayer *)self.ambientGradientLayer.presentationLayer;
    NSArray *fromColors =
        presentationLayer.colors ?: self.ambientGradientLayer.colors;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ambientGradientLayer.colors = targetColors;
    self.ambientGradientLayer.startPoint =
        [self pp_isRTL] ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    self.ambientGradientLayer.endPoint =
        [self pp_isRTL] ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);
    if (!self.isHighlighted && !self.isSelected) {
        self.ambientGradientLayer.opacity = kAmbientRestingOpacity;
    }
    [CATransaction commit];

    [self.ambientGradientLayer
        removeAnimationForKey:@"pp_chat_state_colors"];
    if (animated && fromColors.count == targetColors.count) {
        CABasicAnimation *transition =
            [CABasicAnimation animationWithKeyPath:@"colors"];
        transition.fromValue = fromColors;
        transition.toValue = targetColors;
        transition.duration = 0.34;
        transition.timingFunction =
            [CAMediaTimingFunction
             functionWithControlPoints:0.4f :0.0f :0.2f :1.0f];
        [self.ambientGradientLayer
            addAnimation:transition
                  forKey:@"pp_chat_state_colors"];
    }
}

- (UIColor *)pp_primaryAccentColor {
    return AppPrimaryClr ?: UIColor.systemBlueColor;
}

- (UIColor *)pp_surfaceFillColor {
    UIColor *baseColor =
        AppForgroundColr ?: UIColor.secondarySystemGroupedBackgroundColor;
    return [baseColor colorWithAlphaComponent:[self pp_isDarkMode] ? 0.92 : 0.97];
}

- (UIColor *)pp_surfaceBorderColor {
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor]
                colorWithAlphaComponent:[self pp_isDarkMode] ? 0.24 : 0.16];
    }
    return [UIColor.labelColor
            colorWithAlphaComponent:[self pp_isDarkMode] ? 0.11 : 0.055];
}

- (UIColor *)pp_avatarHaloFillColor {
    if (self.currentOnline) {
        return [UIColor.systemGreenColor
                colorWithAlphaComponent:[self pp_isDarkMode] ? 0.14 : 0.085];
    }
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor]
                colorWithAlphaComponent:[self pp_isDarkMode] ? 0.14 : 0.075];
    }
    UIColor *baseColor =
        AppBackgroundClr ?: UIColor.tertiarySystemGroupedBackgroundColor;
    return [baseColor
            colorWithAlphaComponent:[self pp_isDarkMode] ? 0.72 : 0.82];
}

- (UIColor *)pp_avatarHaloBorderColor {
    if (self.currentOnline) {
        return [UIColor.systemGreenColor
                colorWithAlphaComponent:[self pp_isDarkMode] ? 0.34 : 0.24];
    }
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor]
                colorWithAlphaComponent:[self pp_isDarkMode] ? 0.28 : 0.17];
    }
    return [UIColor.labelColor
            colorWithAlphaComponent:[self pp_isDarkMode] ? 0.12 : 0.06];
}

- (float)pp_restingShadowOpacity {
    if ([self pp_isDarkMode]) {
        return self.currentUnreadCount > 0 ? 0.24f : 0.18f;
    }
    return self.currentUnreadCount > 0 ? 0.070f : 0.045f;
}

#pragma mark - Avatar

- (void)pp_bindAvatarForUser:(UserModel *)user {
    NSString *userID = user.ID ?: @"";
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";

    if ([self.representedUserID isEqualToString:userID] &&
        [self.representedAvatarURL isEqualToString:avatarURL]) {
        return;
    }

    [[PPImageLoaderManager shared]
        cancelImageLoadForImageView:self.avatarView.imageView];
    [self.avatarView.imageView.layer removeAllAnimations];
    self.avatarView.imageView.alpha = 1.0;

    self.representedUserID = userID;
    self.representedAvatarURL = avatarURL;

    if (PPIsSupportAvatarURL(avatarURL)) {
        self.avatarView.imageView.image = PPSupportAvatarImage();
        self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.avatarView.imageView.backgroundColor = UIColor.whiteColor;
        return;
    }

    NSString *avatarName =
        user.PPBestDisplayName ?: user.UserName ?: @"";
    UIImage *placeholder =
        [PPModernAvatarRenderer avatarImageForName:avatarName size:kAvatarSize];
    self.avatarView.imageView.image = placeholder;
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.backgroundColor = UIColor.clearColor;

    if (avatarURL.length == 0) {
        return;
    }

    PPImageTransitionStyle transitionStyle =
        UIAccessibilityIsReduceMotionEnabled()
        ? PPImageTransitionStyleNone
        : PPImageTransitionStyleCrossDissolve;
    [[PPImageLoaderManager shared]
        setImageOnImageView:self.avatarView.imageView
                        url:avatarURL
                placeholder:placeholder
            transitionStyle:transitionStyle
                 complation:nil];
}

#pragma mark - Copy Formatting

- (NSString *)pp_previewForThread:(ChatThreadModel *)thread {
    NSString *preview = thread.lastMessage ?: @"";
    if ([preview isEqualToString:@"__pp_message_unsent__"]) {
        return kLang(@"chat_message_unsent");
    }
    preview =
        [preview stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    preview =
        [preview stringByTrimmingCharactersInSet:
         NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return preview.length > 0 ? preview : kLang(@"NewMessage");
}

- (NSString *)pp_timestampForDate:(NSDate *)date {
    if (!date) {
        return @"";
    }

    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = NSLocale.currentLocale;

    if ([calendar isDateInToday:date]) {
        formatter.dateStyle = NSDateFormatterNoStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        return [formatter stringFromDate:date];
    }
    if ([calendar isDateInYesterday:date]) {
        formatter.doesRelativeDateFormatting = YES;
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
        return [formatter stringFromDate:date];
    }

    NSDateComponents *delta =
        [calendar components:NSCalendarUnitDay
                    fromDate:date
                      toDate:NSDate.date
                     options:0];
    if (delta.day < 7) {
        formatter.dateFormat = @"EEE";
        return [formatter stringFromDate:date];
    }

    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    return [formatter stringFromDate:date];
}

- (NSString *)pp_formattedLastSeen:(NSDate *)date {
    if (!date) {
        return kLang(@"chat.offline");
    }

    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateFormatter *timeFormatter = [NSDateFormatter new];
    timeFormatter.timeStyle = NSDateFormatterShortStyle;
    timeFormatter.dateStyle = NSDateFormatterNoStyle;

    if ([calendar isDateInToday:date]) {
        return [NSString
            stringWithFormat:@"%@ %@",
                             kLang(@"chat.last_seen"),
                             [NSString
                              stringWithFormat:kLang(@"chat.today_at"),
                                               [timeFormatter
                                                stringFromDate:date]]];
    }
    if ([calendar isDateInYesterday:date]) {
        return [NSString
            stringWithFormat:@"%@ %@",
                             kLang(@"chat.last_seen"),
                             [NSString
                              stringWithFormat:kLang(@"chat.yesterday_at"),
                                               [timeFormatter
                                                stringFromDate:date]]];
    }

    NSDateFormatter *fullFormatter = [NSDateFormatter new];
    fullFormatter.dateStyle = NSDateFormatterShortStyle;
    fullFormatter.timeStyle = NSDateFormatterShortStyle;
    return [NSString stringWithFormat:@"%@ %@",
            kLang(@"chat.last_seen"),
            [fullFormatter stringFromDate:date]];
}

#pragma mark - Presence Motion

- (void)pp_updatePresenceIndicatorAnimated:(BOOL)animated {
    if (!animated) {
        [self pp_stopPresenceBreathing];
        [self.onlineDot.layer removeAllAnimations];
        [self.presenceGlowView.layer removeAllAnimations];
        self.onlineDot.hidden = !self.currentOnline;
        self.presenceGlowView.hidden = !self.currentOnline;
        self.onlineDot.alpha = 1.0;
        self.presenceGlowView.alpha =
            UIAccessibilityIsReduceMotionEnabled() ? 0.62 : 1.0;
        self.onlineDot.transform = CGAffineTransformIdentity;
        self.presenceGlowView.transform = CGAffineTransformIdentity;
        if (self.currentOnline) {
            [self pp_startPresenceBreathingIfNeeded];
        }
        return;
    }

    if (self.currentOnline) {
        [self pp_stopPresenceBreathing];
        self.onlineDot.hidden = NO;
        self.presenceGlowView.hidden = NO;
        self.onlineDot.alpha = 0.0;
        self.presenceGlowView.alpha = 0.0;
        self.onlineDot.transform = CGAffineTransformMakeScale(0.58, 0.58);
        self.presenceGlowView.transform =
            CGAffineTransformMakeScale(0.76, 0.76);

        [UIView animateWithDuration:0.28
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseOut |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction)
                         animations:^{
                             self.onlineDot.alpha = 1.0;
                             self.presenceGlowView.alpha = 1.0;
                             self.onlineDot.transform =
                                 CGAffineTransformIdentity;
                             self.presenceGlowView.transform =
                                 CGAffineTransformIdentity;
                         }
                         completion:^(__unused BOOL finished) {
                             if (self.currentOnline) {
                                 [self pp_startPresenceBreathingIfNeeded];
                             }
                         }];
    } else {
        [self pp_stopPresenceBreathing];
        [UIView animateWithDuration:0.16
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction)
                         animations:^{
                             self.onlineDot.alpha = 0.0;
                             self.presenceGlowView.alpha = 0.0;
                             self.onlineDot.transform =
                                 CGAffineTransformMakeScale(0.62, 0.62);
                             self.presenceGlowView.transform =
                                 CGAffineTransformMakeScale(0.78, 0.78);
                         }
                         completion:^(__unused BOOL finished) {
                             if (!self.currentOnline) {
                                 self.onlineDot.hidden = YES;
                                 self.presenceGlowView.hidden = YES;
                                 self.onlineDot.alpha = 1.0;
                                 self.presenceGlowView.alpha = 1.0;
                                 self.onlineDot.transform =
                                     CGAffineTransformIdentity;
                                 self.presenceGlowView.transform =
                                     CGAffineTransformIdentity;
                             }
                         }];
    }
}

- (void)pp_startPresenceBreathingIfNeeded {
    if (!self.currentOnline ||
        !self.window ||
        UIAccessibilityIsReduceMotionEnabled() ||
        [self.presenceGlowView.layer
         animationForKey:@"pp_chat_presence_breath"]) {
        return;
    }

    CABasicAnimation *scale =
        [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @0.92;
    scale.toValue = @1.12;

    CABasicAnimation *opacity =
        [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @0.52;
    opacity.toValue = @1.0;

    CAAnimationGroup *breath = [CAAnimationGroup animation];
    breath.animations = @[scale, opacity];
    breath.duration = 1.8;
    breath.autoreverses = YES;
    breath.repeatCount = HUGE_VALF;
    breath.timingFunction =
        [CAMediaTimingFunction
         functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [self.presenceGlowView.layer
        addAnimation:breath
              forKey:@"pp_chat_presence_breath"];
}

- (void)pp_stopPresenceBreathing {
    [self.presenceGlowView.layer
        removeAnimationForKey:@"pp_chat_presence_breath"];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.presenceGlowView.layer.opacity = 1.0;
    self.presenceGlowView.layer.transform = CATransform3DIdentity;
    [CATransaction commit];
}

- (void)pp_resetMotionState {
    [self pp_stopPresenceBreathing];
    [self.surfaceView.layer removeAllAnimations];
    [self.avatarHaloView.layer removeAllAnimations];
    [self.onlineDot.layer removeAllAnimations];
    [self.presenceGlowView.layer removeAllAnimations];
    [self.unreadBadge.layer removeAllAnimations];
    [self.ambientGradientLayer removeAllAnimations];

    self.surfaceView.alpha = 1.0;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.avatarHaloView.transform = CGAffineTransformIdentity;
    self.onlineDot.alpha = 1.0;
    self.onlineDot.transform = CGAffineTransformIdentity;
    self.presenceGlowView.alpha = 1.0;
    self.presenceGlowView.transform = CGAffineTransformIdentity;
    self.unreadBadge.alpha = 1.0;
    self.unreadBadge.transform = CGAffineTransformIdentity;
    self.ambientGradientLayer.opacity = kAmbientRestingOpacity;
}

- (void)pp_reduceMotionStatusDidChange:(NSNotification *)notification {
    (void)notification;

    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf pp_reduceMotionStatusDidChange:nil];
        });
        return;
    }

    [self pp_resetMotionState];
    [self pp_refreshChromeAnimated:NO];
    [self pp_updatePresenceIndicatorAnimated:NO];
}

#pragma mark - Accessibility

- (void)pp_updateAccessibility {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if (self.nameLabel.text.length > 0) {
        [parts addObject:self.nameLabel.text];
    }
    if (self.messageLabel.text.length > 0) {
        [parts addObject:self.messageLabel.text];
    }
    if (self.presenceAccessibilityText.length > 0) {
        [parts addObject:self.presenceAccessibilityText];
    }
    if (self.timeLabel.text.length > 0) {
        [parts addObject:self.timeLabel.text];
    }

    self.accessibilityLabel = [parts componentsJoinedByString:@", "];
    NSString *unreadFormat = kLang(@"chat_unread_count_format");
    if ([unreadFormat isEqualToString:@"chat_unread_count_format"]) {
        self.accessibilityValue = self.currentUnreadCount > 0
            ? [NSString stringWithFormat:@"%@: %ld",
                                         kLang(@"NewMessage"),
                                         (long)self.currentUnreadCount]
            : nil;
    } else {
        self.accessibilityValue = self.currentUnreadCount > 0
            ? [NSString stringWithFormat:unreadFormat,
                                         (long)self.currentUnreadCount]
            : nil;
    }
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

#pragma mark - Language Direction

- (void)pp_applyLanguageDirection {
    UISemanticContentAttribute semanticAttribute =
        Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    self.semanticContentAttribute = semanticAttribute;
    self.contentView.semanticContentAttribute = semanticAttribute;
    self.surfaceView.semanticContentAttribute = semanticAttribute;
    self.nameLabel.textAlignment = alignment;
    self.messageLabel.textAlignment = alignment;
    self.timeLabel.textAlignment = alignment;
    [self setNeedsLayout];
}

- (BOOL)pp_isRTL {
    return self.contentView.effectiveUserInterfaceLayoutDirection ==
           UIUserInterfaceLayoutDirectionRightToLeft;
}

- (BOOL)pp_isDarkMode {
    if (@available(iOS 12.0, *)) {
        return self.traitCollection.userInterfaceStyle ==
               UIUserInterfaceStyleDark;
    }
    return NO;
}

@end
