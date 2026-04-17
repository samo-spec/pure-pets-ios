//
//  ChCell.m
//  Pure Pets
//
//  Refactored 2026 – Modern Chat Thread Cell
//

#import "ChCell.h"

#import "ChatPresenceManager.h"
#import "ChatThreadModel.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "PPVerifiedBadgeHelper.h"
#import "UserModel.h"

static NSString * const PPChCellSupportAvatarToken = @"purepets://support-logo";

static CGFloat const PPChCellCornerRadius = 28.0;
static CGFloat const PPChCellAvatarSize = 52.0;
static CGFloat const PPChCellVerticalInset = 6.0;
static CGFloat const PPChCellHorizontalInset = 12.0;
static CGFloat const PPChCellContentInset = 12.0;
static CGFloat const PPChCellSpacing = 10.0;
static CGFloat const PPChCellBadgeHeight = 24.0;
static CGFloat const PPChCellMinimumBadgeWidth = 24.0;

static BOOL PPChCellIsSupportAvatarURL(NSString *urlString) {
    return [urlString hasPrefix:PPChCellSupportAvatarToken];
}

static UIImage *PPChCellSupportLogoImage(void) {
    return [UIImage imageNamed:@"newlogo"] ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

static UIColor *PPChCellSurfaceColor(BOOL highlighted) {
    UIColor *base = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    return [base colorWithAlphaComponent:highlighted ? 0.16 : 0.10];
}

static UIColor *PPChCellStrokeColor(void) {
    return [AppForgroundColr colorWithAlphaComponent:0.18] ?: [UIColor.separatorColor colorWithAlphaComponent:0.25];
}

@interface ChCell ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIVisualEffectView *liquidBlur;
@property (nonatomic, strong) RoundedImageViewWithShadow *avatarView;
@property (nonatomic, strong) UIView *onlineDot;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *presenceLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *unreadBadge;
@property (nonatomic, strong) UIStackView *summaryStack;
@property (nonatomic, strong) UIView *metaColumnView;
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
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    [self buildUI];
    [self buildLayout];
    [self applyStyle];

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
    self.messageLabel.textColor = UIColor.secondaryLabelColor;

    [self stopOnlinePulse];
    [self pp_applyInteractionStateAnimated:NO];
    [self pp_updateAccessibility];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.containerView.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.containerView.bounds
                               cornerRadius:PPChCellCornerRadius].CGPath;
}

#pragma mark - UI

- (void)buildUI {
    self.containerView = [UIView new];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.containerView];

    self.avatarView =
    [[RoundedImageViewWithShadow alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.clipsToBounds = YES;
    [self.containerView addSubview:self.avatarView];

    self.onlineDot = [UIView new];
    self.onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.onlineDot.hidden = YES;
    [self.containerView addSubview:self.onlineDot];

    self.verifiedBadgeView =
    [PPVerifiedBadgeHelper addBadgeToAvatarView:self.avatarView
                                    inSuperview:self.containerView
                                      badgeSize:16.0];
    self.verifiedBadgeView.hidden = YES;

    self.nameLabel = [UILabel new];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [GM boldFontWithSize:16];
    self.nameLabel.textColor = UIColor.labelColor;
    self.nameLabel.numberOfLines = 1;
    self.nameLabel.textAlignment = NSTextAlignmentNatural;
    self.nameLabel.isAccessibilityElement = NO;

    self.messageLabel = [UILabel new];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.font = [GM MidFontWithSize:14];
    self.messageLabel.textColor = UIColor.secondaryLabelColor;
    self.messageLabel.numberOfLines = 1;
    self.messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.messageLabel.textAlignment = NSTextAlignmentNatural;
    self.messageLabel.isAccessibilityElement = NO;

    self.presenceLabel = [UILabel new];
    self.presenceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.presenceLabel.font = [GM MidFontWithSize:12];
    self.presenceLabel.textColor = UIColor.tertiaryLabelColor;
    self.presenceLabel.numberOfLines = 1;
    self.presenceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.presenceLabel.textAlignment = NSTextAlignmentNatural;
    self.presenceLabel.isAccessibilityElement = NO;

    self.summaryStack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.nameLabel,
        self.messageLabel,
        self.presenceLabel
    ]];
    self.summaryStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.summaryStack.axis = UILayoutConstraintAxisVertical;
    self.summaryStack.spacing = 4.0;
    self.summaryStack.alignment = UIStackViewAlignmentFill;
    [self.containerView addSubview:self.summaryStack];

    self.metaColumnView = [UIView new];
    self.metaColumnView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.metaColumnView];

    self.timeLabel = [UILabel new];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = [GM MidFontWithSize:12];
    self.timeLabel.textColor = UIColor.secondaryLabelColor;
    self.timeLabel.textAlignment = [self pp_isRightToLeftLayout] ? NSTextAlignmentLeft : NSTextAlignmentRight;
    self.timeLabel.isAccessibilityElement = NO;
    [self.metaColumnView addSubview:self.timeLabel];

    self.unreadBadge = [UILabel new];
    self.unreadBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.unreadBadge.font = [GM boldFontWithSize:12];
    self.unreadBadge.textAlignment = NSTextAlignmentCenter;
    self.unreadBadge.hidden = YES;
    self.unreadBadge.isAccessibilityElement = NO;
    [self.metaColumnView addSubview:self.unreadBadge];

    [self.nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.messageLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [self.presenceLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.summaryStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.summaryStack setContentHuggingPriority:UILayoutPriorityDefaultLow
                                         forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.metaColumnView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                         forAxis:UILayoutConstraintAxisHorizontal];
    [self.metaColumnView setContentHuggingPriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)buildLayout {
    UILayoutGuide *guide = self.containerView.layoutMarginsGuide;
    BOOL isRTL = [self pp_isRightToLeftLayout];
    self.containerView.layoutMargins = UIEdgeInsetsMake(PPChCellContentInset,
                                                        PPChCellContentInset,
                                                        PPChCellContentInset,
                                                        PPChCellContentInset);

    self.badgeWidthConstraint =
    [self.unreadBadge.widthAnchor constraintGreaterThanOrEqualToConstant:PPChCellMinimumBadgeWidth];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [self.containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPChCellVerticalInset],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPChCellHorizontalInset],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPChCellHorizontalInset],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPChCellVerticalInset],

        [self.avatarView.centerYAnchor constraintEqualToAnchor:self.containerView.centerYAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:PPChCellAvatarSize],
        [self.avatarView.heightAnchor constraintEqualToConstant:PPChCellAvatarSize],
        [self.avatarView.topAnchor constraintGreaterThanOrEqualToAnchor:guide.topAnchor],
        [self.avatarView.bottomAnchor constraintLessThanOrEqualToAnchor:guide.bottomAnchor],

        [self.onlineDot.widthAnchor constraintEqualToConstant:12.0],
        [self.onlineDot.heightAnchor constraintEqualToConstant:12.0],
        [self.onlineDot.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:-1.0],
        [self.onlineDot.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor constant:-1.0],

        [self.summaryStack.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [self.summaryStack.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],

        [self.metaColumnView.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [self.metaColumnView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],

        [self.timeLabel.topAnchor constraintEqualToAnchor:self.metaColumnView.topAnchor constant:1.0],
        [self.unreadBadge.bottomAnchor constraintEqualToAnchor:self.metaColumnView.bottomAnchor],
        self.badgeWidthConstraint,
        [self.unreadBadge.heightAnchor constraintEqualToConstant:PPChCellBadgeHeight],

        [self.metaColumnView.widthAnchor constraintGreaterThanOrEqualToAnchor:self.timeLabel.widthAnchor],
        [self.metaColumnView.widthAnchor constraintGreaterThanOrEqualToAnchor:self.unreadBadge.widthAnchor]
    ]];

    if (isRTL) {
        [constraints addObjectsFromArray:@[
            [self.avatarView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
            [self.metaColumnView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
            [self.timeLabel.leadingAnchor constraintEqualToAnchor:self.metaColumnView.leadingAnchor],
            [self.timeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.metaColumnView.trailingAnchor],
            [self.unreadBadge.leadingAnchor constraintEqualToAnchor:self.metaColumnView.leadingAnchor],
            [self.unreadBadge.trailingAnchor constraintLessThanOrEqualToAnchor:self.metaColumnView.trailingAnchor],
            [self.summaryStack.trailingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor constant:-PPChCellSpacing],
            [self.summaryStack.leadingAnchor constraintEqualToAnchor:self.metaColumnView.trailingAnchor constant:12.0]
        ]];
    } else {
        [constraints addObjectsFromArray:@[
            [self.avatarView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
            [self.metaColumnView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
            [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.metaColumnView.trailingAnchor],
            [self.timeLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.metaColumnView.leadingAnchor],
            [self.unreadBadge.trailingAnchor constraintEqualToAnchor:self.metaColumnView.trailingAnchor],
            [self.unreadBadge.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.metaColumnView.leadingAnchor],
            [self.summaryStack.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:PPChCellSpacing],
            [self.summaryStack.trailingAnchor constraintEqualToAnchor:self.metaColumnView.leadingAnchor constant:-12.0]
        ]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)applyStyle {
    // Liquid glass blur backing inside container
    if (!self.liquidBlur) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        self.liquidBlur = [[UIVisualEffectView alloc] initWithEffect:blur];
        self.liquidBlur.translatesAutoresizingMaskIntoConstraints = NO;
        self.liquidBlur.layer.cornerRadius = PPChCellCornerRadius;
        self.liquidBlur.layer.masksToBounds = YES;
        self.liquidBlur.userInteractionEnabled = NO;
        [self.containerView insertSubview:self.liquidBlur atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [self.liquidBlur.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
            [self.liquidBlur.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
            [self.liquidBlur.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
            [self.liquidBlur.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor],
        ]];
    }

    self.containerView.backgroundColor = PPChCellSurfaceColor(NO);
    self.containerView.layer.cornerRadius = PPChCellCornerRadius;
    if (@available(iOS 13.0, *)) {
        self.containerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.containerView.layer.borderWidth = 1.0;
    self.containerView.layer.borderColor = PPChCellStrokeColor().CGColor;
    self.containerView.layer.shadowColor = [AppForgroundColr colorWithAlphaComponent:0.08].CGColor;
    self.containerView.layer.shadowOpacity = 0.12;
    self.containerView.layer.shadowRadius = 14.0;
    self.containerView.layer.shadowOffset = CGSizeMake(0.0, 6.0);

    self.avatarView.layer.shadowOpacity = 0.10;
    self.avatarView.layer.shadowRadius = 8.0;
    self.avatarView.layer.shadowOffset = CGSizeMake(0.0, 4.0);

    self.onlineDot.layer.cornerRadius = 6.0;
    self.onlineDot.layer.borderWidth = 2.0;
    self.onlineDot.layer.borderColor = self.containerView.backgroundColor.CGColor;

    self.unreadBadge.backgroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.unreadBadge.textColor = UIColor.whiteColor;
    self.unreadBadge.layer.cornerRadius = PPChCellBadgeHeight * 0.5;
    if (@available(iOS 13.0, *)) {
        self.unreadBadge.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.unreadBadge.layer.masksToBounds = YES;
}

#pragma mark - Configuration

- (void)configureWithThread:(ChatThreadModel *)thread {
    UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
    NSString *displayName = user.PPBestDisplayName ?: user.UserName ?: @"";
    NSString *preview = [self pp_previewTextForThread:thread];
    NSDate *displayDate = thread.lastMessageAt ?: thread.timestamp;

    self.nameLabel.text = displayName;
    self.messageLabel.text = preview;
    self.timeLabel.text = [self pp_timestampTextForDate:displayDate];
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
        self.messageLabel.textColor = UIColor.secondaryLabelColor;
        [self pp_updateAccessibility];
        return;
    }

    NSString *badgeText = self.currentUnreadCount > 99 ? @"99+" : @(self.currentUnreadCount).stringValue;
    self.unreadBadge.hidden = NO;
    self.unreadBadge.text = badgeText;
    self.messageLabel.textColor = UIColor.labelColor;

    CGFloat badgeTextWidth =
    [badgeText sizeWithAttributes:@{ NSFontAttributeName : self.unreadBadge.font }].width;
    self.badgeWidthConstraint.constant = MAX(PPChCellMinimumBadgeWidth, ceil(badgeTextWidth) + 14.0);

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
    self.onlineDot.backgroundColor = online ? UIColor.systemGreenColor : UIColor.quaternaryLabelColor;
    self.presenceLabel.textColor = online ? UIColor.systemGreenColor : UIColor.tertiaryLabelColor;
    self.presenceLabel.text = online ? kLang(@"chat.online") : [self formattedLastSeen:lastSeen];

    if (online) {
        [self startOnlinePulse];
    } else {
        [self stopOnlinePulse];
    }

    [self pp_updateAccessibility];
}

#pragma mark - Interaction

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self pp_applyInteractionStateAnimated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self pp_applyInteractionStateAnimated:animated];
}

- (void)pp_applyInteractionStateAnimated:(BOOL)animated {
    BOOL emphasized = self.isHighlighted || self.isSelected;
    CGAffineTransform transform = emphasized ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    UIColor *surfaceColor = PPChCellSurfaceColor(emphasized);
    UIColor *borderColor = emphasized
        ? [AppForgroundColr colorWithAlphaComponent:0.30]
        : PPChCellStrokeColor();
    CGFloat shadowOpacity = emphasized ? 0.16 : 0.12;

    void (^changes)(void) = ^{
        self.containerView.transform = transform;
        self.containerView.backgroundColor = surfaceColor;
        self.containerView.layer.borderColor = borderColor.CGColor;
        self.containerView.layer.shadowOpacity = shadowOpacity;
        self.onlineDot.layer.borderColor = surfaceColor.CGColor;
    };

    if (animated) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

#pragma mark - Helpers

- (void)pp_bindAvatarForUser:(UserModel *)user {
    NSString *userID = user.ID ?: @"";
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";
    BOOL isSupportAvatar = PPChCellIsSupportAvatarURL(avatarURL);

    if ([self.representedUserID isEqualToString:userID] &&
        [self.representedAvatarURL isEqualToString:avatarURL]) {
        return;
    }

    self.representedUserID = userID;
    self.representedAvatarURL = avatarURL;

    if (isSupportAvatar) {
        self.avatarView.imageView.image = PPChCellSupportLogoImage();
        self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.avatarView.imageView.backgroundColor = UIColor.whiteColor;
        return;
    }

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:user.UserName size:PPChCellAvatarSize];
    self.avatarView.imageView.image = placeholder;
    self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.imageView.backgroundColor = UIColor.clearColor;

    if (avatarURL.length == 0) {
        return;
    }

    [[PPImageLoaderManager shared] setImageOnImageView:self.avatarView.imageView
                                                   url:avatarURL
                                           placeholder:placeholder
                                            complation:^(__unused UIImage *image, __unused NSString *urlString) {
    }];
}

- (NSString *)pp_previewTextForThread:(ChatThreadModel *)thread {
    NSString *preview = thread.lastMessage ?: @"";
    preview = [preview stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    preview = [preview stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return preview.length > 0 ? preview : kLang(@"NewMessage");
}

- (NSString *)pp_timestampTextForDate:(NSDate *)date {
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

- (NSString *)formattedLastSeen:(NSDate *)date {
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

- (void)startOnlinePulse {
    if ([self.onlineDot.layer animationForKey:@"pulse"]) {
        return;
    }

    CABasicAnimation *pulse =
    [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @1.0;
    pulse.toValue = @1.22;
    pulse.duration = 1.4;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.onlineDot.layer addAnimation:pulse forKey:@"pulse"];
}

- (void)stopOnlinePulse {
    [self.onlineDot.layer removeAnimationForKey:@"pulse"];
}

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

- (BOOL)pp_isRightToLeftLayout {
    UISemanticContentAttribute semantic = self.contentView.semanticContentAttribute;
    return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:semantic] == UIUserInterfaceLayoutDirectionRightToLeft;
}

@end
