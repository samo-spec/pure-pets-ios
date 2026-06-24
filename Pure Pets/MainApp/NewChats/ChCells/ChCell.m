//
//  ChCell.m
//  Pure Pets
//
//  Premium Minimal Chat Cell - 2026
//
//  Visual thesis: calm editorial surface, precise spacing,
//  presence signaled with restraint, unread state carried by
//  typography and one measured accent.
//

#import "ChCell.h"

#import "ChatPresenceManager.h"
#import "ChatThreadModel.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "PPVerifiedBadgeHelper.h"
#import "UserModel.h"

#pragma mark - Design Tokens

static CGFloat const kCellOuterHorizontalInset   = 12.0;
static CGFloat const kCellOuterVerticalInset     = 5.0;
static CGFloat const kCanvasCornerRadius         = 24.0;
static CGFloat const kCanvasBorderWidth          = 1.0;
static CGFloat const kCanvasInnerHorizontalInset = 16.0;
static CGFloat const kCanvasInnerVerticalInset   = 12.0;
static CGFloat const kAvatarHaloSize             = 64.0;
static CGFloat const kAvatarSize                 = 56.0;
static CGFloat const kAvatarTextSpacing          = 14.0;
static CGFloat const kTextMetaSpacing            = 10.0;
static CGFloat const kNameOffsetFromCenter       = 4.0;
static CGFloat const kPreviewPlateHeight         = 28.0;
static CGFloat const kPreviewPlateCornerRadius   = 14.0;
static CGFloat const kPreviewPlateHorizontalPad  = 12.0;
static CGFloat const kPreviewAccentInset         = 8.0;
static CGFloat const kPreviewAccentWidth         = 3.0;
static CGFloat const kPreviewAccentHeight        = 14.0;
static CGFloat const kOnlineDotSize              = 10.0;
static CGFloat const kOnlineDotBorder            = 2.5;
static CGFloat const kBadgeHeight                = 22.0;
static CGFloat const kBadgeMinWidth              = 22.0;
static CGFloat const kVerifiedBadgeSize          = 16.0;

static BOOL PPIsSupport(NSString *url) {
    return [url hasPrefix:@"purepets://support-logo"];
}

static UIImage *PPSupportLogo(void) {
    return [UIImage imageNamed:@"newlogo"]
        ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

@interface ChCell ()

@property (nonatomic, strong) UIView *canvasView;
@property (nonatomic, strong) UIView *avatarHaloView;
@property (nonatomic, strong) RoundedImageViewWithShadow *avatarView;
@property (nonatomic, strong) UIView *previewPlateView;
@property (nonatomic, strong) UIView *messageAccentView;
@property (nonatomic, strong) UIView *onlineDot;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *presenceLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *unreadBadge;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) UIImageView *verifiedBadgeView;
@property (nonatomic, strong) NSLayoutConstraint *badgeWidthConstraint;
@property (nonatomic, assign) NSInteger currentUnreadCount;
@property (nonatomic, assign) BOOL currentOnline;

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
    self.contentView.clipsToBounds = NO;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    [self pp_buildUI];
    [self pp_buildLayout];
    [self pp_refreshChrome];

    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];

    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.avatarView.imageView];

    self.representedUserID = nil;
    self.representedAvatarURL = nil;
    self.currentUnreadCount = 0;
    self.currentOnline = NO;

    self.nameLabel.text = @"";
    self.messageLabel.text = @"";
    self.presenceLabel.text = @"";
    self.timeLabel.text = @"";
    self.unreadBadge.text = @"";
    self.unreadBadge.hidden = YES;
    self.badgeWidthConstraint.constant = 0.0;

    self.verifiedBadgeView.hidden = YES;
    self.onlineDot.hidden = YES;
    self.onlineDot.backgroundColor = UIColor.quaternaryLabelColor;

    self.avatarView.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.backgroundColor = UIColor.clearColor;

    [self pp_stopPulse];
    self.canvasView.alpha = 1.0;
    self.canvasView.transform = CGAffineTransformIdentity;
    self.avatarHaloView.transform = CGAffineTransformIdentity;

    [self pp_refreshChrome];
    [self pp_updateAccessibility];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshChrome];
        }
    }
}

#pragma mark - Build UI

- (void)pp_buildUI {
    self.canvasView = [UIView new];
    self.canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    self.canvasView.clipsToBounds = YES;
    self.canvasView.layer.cornerRadius = kCanvasCornerRadius;
    self.canvasView.layer.borderWidth = kCanvasBorderWidth;
    if (@available(iOS 13.0, *)) {
        self.canvasView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.canvasView];

    self.avatarHaloView = [UIView new];
    self.avatarHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarHaloView.layer.cornerRadius = kAvatarHaloSize * 0.5;
    self.avatarHaloView.layer.borderWidth = 1.0;
    [self.canvasView addSubview:self.avatarHaloView];

    self.avatarView =
        [[RoundedImageViewWithShadow alloc]
         initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.clipsToBounds = YES;
    self.avatarView.layer.shadowOpacity = 0.0;
    self.avatarView.layer.borderWidth = 0.0;
    self.avatarView.backgroundColor = UIColor.clearColor;
    [self.avatarHaloView addSubview:self.avatarView];

    self.onlineDot = [UIView new];
    self.onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.onlineDot.hidden = YES;
    self.onlineDot.layer.cornerRadius = kOnlineDotSize * 0.5;
    self.onlineDot.layer.borderWidth = kOnlineDotBorder;
    self.onlineDot.backgroundColor = UIColor.quaternaryLabelColor;
    [self.canvasView addSubview:self.onlineDot];

    self.verifiedBadgeView =
        [PPVerifiedBadgeHelper addBadgeToAvatarView:self.avatarView
                                        inSuperview:self.canvasView
                                          badgeSize:kVerifiedBadgeSize];
    self.verifiedBadgeView.hidden = YES;

    self.nameLabel = [UILabel new];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [GM boldFontWithSize:16.5] ?: [UIFont systemFontOfSize:16.5 weight:UIFontWeightSemibold];
    self.nameLabel.textColor = UIColor.labelColor;
    self.nameLabel.numberOfLines = 1;
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.textAlignment = NSTextAlignmentNatural;
    self.nameLabel.isAccessibilityElement = NO;
    [self.canvasView addSubview:self.nameLabel];

    self.previewPlateView = [UIView new];
    self.previewPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewPlateView.clipsToBounds = YES;
    self.previewPlateView.layer.cornerRadius = kPreviewPlateCornerRadius;
    self.previewPlateView.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        self.previewPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.canvasView addSubview:self.previewPlateView];

    self.messageAccentView = [UIView new];
    self.messageAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageAccentView.layer.cornerRadius = kPreviewAccentWidth * 0.5;
    [self.previewPlateView addSubview:self.messageAccentView];

    self.messageLabel = [UILabel new];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.font = [GM MidFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    self.messageLabel.textColor = UIColor.secondaryLabelColor;
    self.messageLabel.numberOfLines = 1;
    self.messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.messageLabel.textAlignment = NSTextAlignmentNatural;
    self.messageLabel.isAccessibilityElement = NO;
    [self.previewPlateView addSubview:self.messageLabel];

    self.presenceLabel = [UILabel new];
    self.presenceLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.presenceLabel.textColor = UIColor.tertiaryLabelColor;
    self.presenceLabel.numberOfLines = 1;

    self.timeLabel = [UILabel new];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.timeLabel.textColor = UIColor.tertiaryLabelColor;
    self.timeLabel.textAlignment = [self pp_isRTL] ? NSTextAlignmentLeft : NSTextAlignmentRight;
    self.timeLabel.isAccessibilityElement = NO;
    [self.canvasView addSubview:self.timeLabel];

    self.unreadBadge = [UILabel new];
    self.unreadBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.unreadBadge.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    self.unreadBadge.textAlignment = NSTextAlignmentCenter;
    self.unreadBadge.textColor = UIColor.whiteColor;
    self.unreadBadge.backgroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.unreadBadge.layer.cornerRadius = kBadgeHeight * 0.5;
    self.unreadBadge.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.unreadBadge.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.unreadBadge.hidden = YES;
    self.unreadBadge.isAccessibilityElement = NO;
    [self.canvasView addSubview:self.unreadBadge];

    self.separatorLine = [UIView new];
    self.separatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    [self.canvasView addSubview:self.separatorLine];

    [self.nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.messageLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                   forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.unreadBadge setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.unreadBadge setContentHuggingPriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];
}

#pragma mark - Layout

- (void)pp_buildLayout {
    BOOL isRTL = [self pp_isRTL];
    CGFloat hairline = 1.0 / UIScreen.mainScreen.scale;
    CGFloat separatorInset = kCanvasInnerHorizontalInset + kAvatarHaloSize + kAvatarTextSpacing;

    self.badgeWidthConstraint =
        [self.unreadBadge.widthAnchor constraintGreaterThanOrEqualToConstant:kBadgeMinWidth];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [self.canvasView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor
                                                  constant:kCellOuterVerticalInset],
        [self.canvasView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor
                                                     constant:-kCellOuterVerticalInset],
        [self.canvasView.leftAnchor constraintEqualToAnchor:self.contentView.leftAnchor
                                                   constant:kCellOuterHorizontalInset],
        [self.canvasView.rightAnchor constraintEqualToAnchor:self.contentView.rightAnchor
                                                    constant:-kCellOuterHorizontalInset],

        [self.avatarHaloView.topAnchor constraintEqualToAnchor:self.canvasView.topAnchor
                                                      constant:kCanvasInnerVerticalInset],
        [self.avatarHaloView.bottomAnchor constraintEqualToAnchor:self.canvasView.bottomAnchor
                                                         constant:-kCanvasInnerVerticalInset],
        [self.avatarHaloView.widthAnchor constraintEqualToConstant:kAvatarHaloSize],
        [self.avatarHaloView.heightAnchor constraintEqualToConstant:kAvatarHaloSize],

        [self.avatarView.centerXAnchor constraintEqualToAnchor:self.avatarHaloView.centerXAnchor],
        [self.avatarView.centerYAnchor constraintEqualToAnchor:self.avatarHaloView.centerYAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:kAvatarSize],
        [self.avatarView.heightAnchor constraintEqualToConstant:kAvatarSize],

        [self.onlineDot.widthAnchor constraintEqualToConstant:kOnlineDotSize],
        [self.onlineDot.heightAnchor constraintEqualToConstant:kOnlineDotSize],
        [self.onlineDot.rightAnchor constraintEqualToAnchor:self.avatarView.rightAnchor constant:1.0],
        [self.onlineDot.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor constant:1.0],

        [self.nameLabel.topAnchor constraintGreaterThanOrEqualToAnchor:self.canvasView.topAnchor constant:16.0],
        [self.nameLabel.bottomAnchor constraintEqualToAnchor:self.avatarHaloView.centerYAnchor
                                                    constant:-kNameOffsetFromCenter],

        [self.previewPlateView.centerYAnchor constraintEqualToAnchor:self.avatarHaloView.centerYAnchor
                                                            constant:13.0],
        [self.previewPlateView.heightAnchor constraintEqualToConstant:kPreviewPlateHeight],

        [self.timeLabel.centerYAnchor constraintEqualToAnchor:self.nameLabel.centerYAnchor],
        [self.unreadBadge.centerYAnchor constraintEqualToAnchor:self.previewPlateView.centerYAnchor],
        [self.unreadBadge.heightAnchor constraintEqualToConstant:kBadgeHeight],
        self.badgeWidthConstraint,

        [self.messageAccentView.widthAnchor constraintEqualToConstant:kPreviewAccentWidth],
        [self.messageAccentView.heightAnchor constraintEqualToConstant:kPreviewAccentHeight],
        [self.messageAccentView.centerYAnchor constraintEqualToAnchor:self.previewPlateView.centerYAnchor],

        [self.messageLabel.centerYAnchor constraintEqualToAnchor:self.previewPlateView.centerYAnchor],
        [self.messageLabel.topAnchor constraintGreaterThanOrEqualToAnchor:self.previewPlateView.topAnchor constant:4.0],
        [self.messageLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.previewPlateView.bottomAnchor constant:-4.0],

        [self.separatorLine.bottomAnchor constraintEqualToAnchor:self.canvasView.bottomAnchor],
        [self.separatorLine.heightAnchor constraintEqualToConstant:hairline],
    ]];

    if (isRTL) {
        [constraints addObjectsFromArray:@[
            [self.avatarHaloView.rightAnchor constraintEqualToAnchor:self.canvasView.rightAnchor
                                                            constant:-kCanvasInnerHorizontalInset],

            [self.nameLabel.rightAnchor constraintEqualToAnchor:self.avatarHaloView.leftAnchor
                                                       constant:-kAvatarTextSpacing],
            [self.nameLabel.leftAnchor constraintGreaterThanOrEqualToAnchor:self.timeLabel.rightAnchor
                                                                   constant:kTextMetaSpacing],

            [self.previewPlateView.rightAnchor constraintEqualToAnchor:self.nameLabel.rightAnchor],
            [self.previewPlateView.leftAnchor constraintGreaterThanOrEqualToAnchor:self.unreadBadge.rightAnchor
                                                                          constant:kTextMetaSpacing],

            [self.timeLabel.leftAnchor constraintEqualToAnchor:self.canvasView.leftAnchor
                                                      constant:kCanvasInnerHorizontalInset],
            [self.unreadBadge.leftAnchor constraintEqualToAnchor:self.canvasView.leftAnchor
                                                        constant:kCanvasInnerHorizontalInset],

            [self.messageAccentView.rightAnchor constraintEqualToAnchor:self.previewPlateView.rightAnchor
                                                               constant:-kPreviewAccentInset],
            [self.messageLabel.rightAnchor constraintEqualToAnchor:self.messageAccentView.leftAnchor
                                                          constant:-8.0],
            [self.messageLabel.leftAnchor constraintGreaterThanOrEqualToAnchor:self.previewPlateView.leftAnchor
                                                                      constant:kPreviewPlateHorizontalPad],

            [self.separatorLine.leftAnchor constraintEqualToAnchor:self.canvasView.leftAnchor
                                                          constant:kCanvasInnerHorizontalInset],
            [self.separatorLine.rightAnchor constraintEqualToAnchor:self.canvasView.rightAnchor
                                                           constant:-separatorInset],
        ]];
    } else {
        [constraints addObjectsFromArray:@[
            [self.avatarHaloView.leftAnchor constraintEqualToAnchor:self.canvasView.leftAnchor
                                                           constant:kCanvasInnerHorizontalInset],

            [self.nameLabel.leftAnchor constraintEqualToAnchor:self.avatarHaloView.rightAnchor
                                                      constant:kAvatarTextSpacing],
            [self.nameLabel.rightAnchor constraintLessThanOrEqualToAnchor:self.timeLabel.leftAnchor
                                                                 constant:-kTextMetaSpacing],

            [self.previewPlateView.leftAnchor constraintEqualToAnchor:self.nameLabel.leftAnchor],
            [self.previewPlateView.rightAnchor constraintLessThanOrEqualToAnchor:self.unreadBadge.leftAnchor
                                                                        constant:-kTextMetaSpacing],

            [self.timeLabel.rightAnchor constraintEqualToAnchor:self.canvasView.rightAnchor
                                                       constant:-kCanvasInnerHorizontalInset],
            [self.unreadBadge.rightAnchor constraintEqualToAnchor:self.canvasView.rightAnchor
                                                         constant:-kCanvasInnerHorizontalInset],

            [self.messageAccentView.leftAnchor constraintEqualToAnchor:self.previewPlateView.leftAnchor
                                                              constant:kPreviewAccentInset],
            [self.messageLabel.leftAnchor constraintEqualToAnchor:self.messageAccentView.rightAnchor
                                                         constant:8.0],
            [self.messageLabel.rightAnchor constraintLessThanOrEqualToAnchor:self.previewPlateView.rightAnchor
                                                                    constant:-kPreviewPlateHorizontalPad],

            [self.separatorLine.leftAnchor constraintEqualToAnchor:self.canvasView.leftAnchor
                                                          constant:separatorInset],
            [self.separatorLine.rightAnchor constraintEqualToAnchor:self.canvasView.rightAnchor
                                                           constant:-kCanvasInnerHorizontalInset],
        ]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
}

#pragma mark - Configuration

- (void)configureWithThread:(ChatThreadModel *)thread {
    UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
    NSString *displayName = user.PPBestDisplayName ?: user.UserName ?: @"";
    NSString *preview = [self pp_previewForThread:thread];
    NSDate *displayDate = thread.lastMessageAt ?: thread.timestamp;

    self.nameLabel.text = displayName;
    self.messageLabel.text = preview;
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
    [self pp_updateAccessibility];
}

- (void)setUnreadCount:(NSInteger)count {
    self.currentUnreadCount = MAX(count, 0);

    if (self.currentUnreadCount <= 0) {
        self.unreadBadge.hidden = YES;
        self.unreadBadge.text = @"";
        self.badgeWidthConstraint.constant = 0.0;
        [self pp_refreshChrome];
        [self pp_updateAccessibility];
        return;
    }

    NSString *text = self.currentUnreadCount > 99
                   ? @"99+"
                   : @(self.currentUnreadCount).stringValue;

    self.unreadBadge.hidden = NO;
    self.unreadBadge.text = text;

    CGFloat width =
        [text sizeWithAttributes:@{NSFontAttributeName: self.unreadBadge.font}].width;
    self.badgeWidthConstraint.constant = MAX(kBadgeMinWidth, ceil(width) + 12.0);

    [self pp_refreshChrome];
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
    self.currentOnline = online;
    self.onlineDot.hidden = NO;
    self.onlineDot.backgroundColor = online ? UIColor.systemGreenColor
                                            : UIColor.quaternaryLabelColor;

    self.presenceLabel.textColor = online ? UIColor.systemGreenColor
                                          : UIColor.tertiaryLabelColor;
    self.presenceLabel.text = online ? kLang(@"chat.online")
                                     : [self pp_formattedLastSeen:lastSeen];

    online ? [self pp_startPulse] : [self pp_stopPulse];
    [self pp_refreshChrome];
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
    CGFloat alpha = pressed ? 0.92 : 1.0;
    CGAffineTransform canvasTransform = pressed
        ? CGAffineTransformMakeScale(0.986, 0.986)
        : CGAffineTransformIdentity;
    CGAffineTransform haloTransform = pressed
        ? CGAffineTransformMakeScale(0.975, 0.975)
        : CGAffineTransformIdentity;

    if (!animated) {
        self.canvasView.alpha = alpha;
        self.canvasView.transform = canvasTransform;
        self.avatarHaloView.transform = haloTransform;
        return;
    }

    [UIView animateWithDuration:0.16
                          delay:0.0
                        options:(UIViewAnimationOptionBeginFromCurrentState |
                                 UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         self.canvasView.alpha = alpha;
                         self.canvasView.transform = canvasTransform;
                         self.avatarHaloView.transform = haloTransform;
                     }
                     completion:nil];
}

#pragma mark - Private Helpers

- (void)pp_refreshChrome {
    UIColor *accent = [self pp_primaryAccentColor];
    UIColor *canvasFill = [self pp_canvasFillColor];
    BOOL hasUnread = self.currentUnreadCount > 0;

    self.canvasView.backgroundColor = canvasFill;
    [self.canvasView pp_setBorderColor:[self pp_canvasBorderColor]];

    self.avatarHaloView.backgroundColor = [self pp_avatarHaloFillColor];
    [self.avatarHaloView pp_setBorderColor:[self pp_avatarHaloBorderColor]];

    self.previewPlateView.backgroundColor = [self pp_previewPlateFillColor];
    [self.previewPlateView pp_setBorderColor:[self pp_previewPlateBorderColor]];

    self.messageAccentView.backgroundColor = [self pp_messageAccentColor];
    self.nameLabel.textColor = UIColor.labelColor;
    self.messageLabel.textColor = hasUnread ? UIColor.labelColor : UIColor.secondaryLabelColor;
    self.timeLabel.textColor = hasUnread ? accent : UIColor.tertiaryLabelColor;
    self.separatorLine.backgroundColor = hasUnread
        ? [accent colorWithAlphaComponent:0.12]
        : [UIColor.labelColor colorWithAlphaComponent:0.05];
    self.unreadBadge.backgroundColor = accent;

    [self.onlineDot pp_setBorderColor:canvasFill];
    if (!self.currentOnline) {
        self.onlineDot.backgroundColor = hasUnread
            ? [accent colorWithAlphaComponent:0.32]
            : UIColor.quaternaryLabelColor;
    }
}

- (UIColor *)pp_primaryAccentColor {
    return AppPrimaryClr ?: UIColor.systemBlueColor;
}

- (UIColor *)pp_canvasFillColor {
    return [AppForgroundColr colorWithAlphaComponent:0.82];
}

- (UIColor *)pp_canvasBorderColor {
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor] colorWithAlphaComponent:0.18];
    }
    return [UIColor.labelColor colorWithAlphaComponent:0.06];
}

- (UIColor *)pp_avatarHaloFillColor {
    if (self.currentOnline) {
        return [UIColor.systemGreenColor colorWithAlphaComponent:0.10];
    }
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor] colorWithAlphaComponent:0.08];
    }
    UIColor *base = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    return [base colorWithAlphaComponent:0.88];
}

- (UIColor *)pp_avatarHaloBorderColor {
    if (self.currentOnline) {
        return [UIColor.systemGreenColor colorWithAlphaComponent:0.24];
    }
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor] colorWithAlphaComponent:0.16];
    }
    return [UIColor.labelColor colorWithAlphaComponent:0.06];
}

- (UIColor *)pp_previewPlateFillColor {
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor] colorWithAlphaComponent:0.10];
    }
    UIColor *base = AppBackgroundClr ?: UIColor.tertiarySystemBackgroundColor;
    return [base colorWithAlphaComponent:0.84];
}

- (UIColor *)pp_previewPlateBorderColor {
    if (self.currentUnreadCount > 0) {
        return [[self pp_primaryAccentColor] colorWithAlphaComponent:0.14];
    }
    return [UIColor.labelColor colorWithAlphaComponent:0.05];
}

- (UIColor *)pp_messageAccentColor {
    if (self.currentOnline) {
        return UIColor.systemGreenColor;
    }
    if (self.currentUnreadCount > 0) {
        return [self pp_primaryAccentColor];
    }
    return [UIColor.labelColor colorWithAlphaComponent:0.14];
}

- (void)pp_bindAvatarForUser:(UserModel *)user {
    NSString *userID = user.ID ?: @"";
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";

    if ([self.representedUserID isEqualToString:userID] &&
        [self.representedAvatarURL isEqualToString:avatarURL]) {
        return;
    }

    self.representedUserID = userID;
    self.representedAvatarURL = avatarURL;

    if (PPIsSupport(avatarURL)) {
        self.avatarView.imageView.image = PPSupportLogo();
        self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.avatarView.imageView.backgroundColor = UIColor.whiteColor;
        return;
    }

    UIImage *placeholder =
        [PPModernAvatarRenderer avatarImageForName:user.UserName size:kAvatarSize];
    self.avatarView.imageView.image = placeholder;
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.backgroundColor = UIColor.clearColor;

    if (avatarURL.length == 0) {
        return;
    }

    [[PPImageLoaderManager shared]
        setImageOnImageView:self.avatarView.imageView
                        url:avatarURL
                placeholder:placeholder
                 complation:^(__unused UIImage *image, __unused NSString *url) {}];
}

- (NSString *)pp_previewForThread:(ChatThreadModel *)thread {
    NSString *preview = thread.lastMessage ?: @"";
    preview = [preview stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    preview = [preview stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
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
        [calendar components:NSCalendarUnitDay fromDate:date toDate:NSDate.date options:0];
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
        return [NSString stringWithFormat:@"%@ %@",
                kLang(@"chat.last_seen"),
                [NSString stringWithFormat:kLang(@"chat.today_at"),
                 [timeFormatter stringFromDate:date]]];
    }
    if ([calendar isDateInYesterday:date]) {
        return [NSString stringWithFormat:@"%@ %@",
                kLang(@"chat.last_seen"),
                [NSString stringWithFormat:kLang(@"chat.yesterday_at"),
                 [timeFormatter stringFromDate:date]]];
    }

    NSDateFormatter *fullFormatter = [NSDateFormatter new];
    fullFormatter.dateStyle = NSDateFormatterShortStyle;
    fullFormatter.timeStyle = NSDateFormatterShortStyle;
    return [NSString stringWithFormat:@"%@ %@",
            kLang(@"chat.last_seen"),
            [fullFormatter stringFromDate:date]];
}

#pragma mark - Online Pulse

- (void)pp_startPulse {
    if ([self.onlineDot.layer animationForKey:@"pp_pulse"]) {
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @1.0;
    pulse.toValue = @0.4;
    pulse.duration = 1.6;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.onlineDot.layer addAnimation:pulse forKey:@"pp_pulse"];
}

- (void)pp_stopPulse {
    [self.onlineDot.layer removeAnimationForKey:@"pp_pulse"];
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
    if (self.presenceLabel.text.length > 0) {
        [parts addObject:self.presenceLabel.text];
    }

    self.accessibilityLabel = [parts componentsJoinedByString:@", "];
    self.accessibilityValue = self.currentUnreadCount > 0 ? self.unreadBadge.text : nil;
}

#pragma mark - RTL

- (BOOL)pp_isRTL {
    UISemanticContentAttribute attribute = self.contentView.semanticContentAttribute;
    return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:attribute]
        == UIUserInterfaceLayoutDirectionRightToLeft;
}

@end
