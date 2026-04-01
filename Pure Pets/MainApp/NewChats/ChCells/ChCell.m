//
//  ChCell.m
//  Pure Pets
//
//  Refactored 2026 – Modern Chat Thread Cell
//

#import "ChCell.h"
#import "ChatThreadModel.h"
#import "ChatPresenceManager.h"
#import "PPImageLoaderManager.h"

static NSString * const PPChCellSupportAvatarToken = @"purepets://support-logo";

static BOOL PPChCellIsSupportAvatarURL(NSString *urlString) {
    return [urlString hasPrefix:PPChCellSupportAvatarToken];
}

static UIImage *PPChCellSupportLogoImage(void) {
    return [UIImage imageNamed:@"newlogo"] ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

@interface ChCell ()

// Container
@property (nonatomic, strong) UIView *containerView;

// Avatar
@property (nonatomic, strong) RoundedImageViewWithShadow *avatarView;
@property (nonatomic, strong) UIView *onlineDot;

// Content
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *unreadBadge;
@property (nonatomic, strong) UILabel *lastSeenLabel;
@end

@implementation ChCell






#pragma mark - Lifecycle

 + (NSString *)reuseID {
     return @"ChCell";
 }

 - (instancetype)initWithStyle:(UITableViewCellStyle)style
               reuseIdentifier:(NSString *)reuseIdentifier {
     self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
     if (!self) return nil;

     self.selectionStyle = UITableViewCellSelectionStyleNone;
     self.backgroundColor = UIColor.clearColor;
     self.contentView.backgroundColor = UIColor.clearColor;

     [self buildUI];
     [self buildLayout];
     [self applyStyle];

     return self;
 }

 - (void)prepareForReuse {
     [super prepareForReuse];

     [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.avatarView.imageView];
     self.nameLabel.text = @"";
     self.messageLabel.text = @"";
     self.timeLabel.text = @"";
     self.unreadBadge.hidden = YES;
     
     self.lastSeenLabel.hidden = YES;
     self.lastSeenLabel.text = @"";
     self.separatorInset = UIEdgeInsetsZero;
     self.layoutMargins = UIEdgeInsetsZero;
     self.onlineDot.hidden = YES;
     self.onlineDot.backgroundColor = UIColor.quaternaryLabelColor;
     
     // 🔒 Reset identity so avatar CAN be reloaded if needed
     self.representedUserID = nil;
     self.representedAvatarURL = nil;
     self.avatarView.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
     self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
     self.avatarView.imageView.backgroundColor = UIColor.clearColor;
     
     [self stopOnlinePulse];
 }

// Absolute safety: never allow transform/alpha changes
- (void)layoutSubviews {
    [super layoutSubviews];
    self.containerView.transform = CGAffineTransformIdentity;
    self.containerView.alpha = 1.0;
}

#pragma mark - UI

- (void)buildUI {

    _containerView = [UIView new];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_containerView];

    _avatarView =
        [[RoundedImageViewWithShadow alloc]
         initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_avatarView];

    _onlineDot = [UIView new];
    _onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_onlineDot];

    _nameLabel = [UILabel new];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
     [_containerView addSubview:_nameLabel];

    _messageLabel = [UILabel new];
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _messageLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _messageLabel.textColor = UIColor.secondaryLabelColor;
    _messageLabel.numberOfLines = 1;
    [_containerView addSubview:_messageLabel];

    _timeLabel = [UILabel new];
    _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
     _timeLabel.textColor = UIColor.tertiaryLabelColor;
    [_containerView addSubview:_timeLabel];
    
    
    _lastSeenLabel = [UILabel new];
    _lastSeenLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _lastSeenLabel.font = [GM MidFontWithSize:11];
    _lastSeenLabel.textColor = UIColor.tertiaryLabelColor;
    _lastSeenLabel.hidden = YES;
    [_containerView addSubview:_lastSeenLabel];
    
    

    _unreadBadge = [UILabel new];
    _unreadBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _unreadBadge.textAlignment = NSTextAlignmentCenter;
     _unreadBadge.hidden = YES;
    [_containerView addSubview:_unreadBadge];
    
    _nameLabel.font = [GM boldFontWithSize:16];
    _messageLabel.font = [GM MidFontWithSize:14];
    _timeLabel.font = [GM MidFontWithSize:12];
    _unreadBadge.font = [GM boldFontWithSize:12];
}

#pragma mark - Layout

- (void)buildLayout {

    UILayoutGuide *g = self.contentView.layoutMarginsGuide;

    [NSLayoutConstraint activateConstraints:@[
        [_containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0],
        [_containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-0],
        [_containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:0],
        [_containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-0],
        
        [_avatarView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:12],
        [_avatarView.centerYAnchor constraintEqualToAnchor:_containerView.centerYAnchor],
        [_avatarView.widthAnchor constraintEqualToConstant:52],
        [_avatarView.heightAnchor constraintEqualToConstant:52],
        
        [_onlineDot.widthAnchor constraintEqualToConstant:10],
        [_onlineDot.heightAnchor constraintEqualToConstant:10],
        [_onlineDot.bottomAnchor constraintEqualToAnchor:_avatarView.bottomAnchor constant:-2],
        [_onlineDot.trailingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:-2],

        [_timeLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-12],
        [_timeLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:12],

        [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:12],
        [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_timeLabel.leadingAnchor constant:-8],
        [_nameLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:12],

        [_messageLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_messageLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_unreadBadge.leadingAnchor constant:-8],
        [_messageLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],

        [_unreadBadge.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-12],
        [_unreadBadge.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-12],
        [_unreadBadge.widthAnchor constraintGreaterThanOrEqualToConstant:20],
        [_unreadBadge.heightAnchor constraintEqualToConstant:20],
        
        [_lastSeenLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor constant:-0],
        [_lastSeenLabel.topAnchor constraintEqualToAnchor:_messageLabel.bottomAnchor constant:2],
    ]];
}

 #pragma mark - Style

 - (void)applyStyle {

     // Card
     self.containerView.backgroundColor = UIColor.systemBackgroundColor;
     self.containerView.layer.cornerRadius = 0;
     self.containerView.layer.masksToBounds = NO;

     self.containerView.layer.shadowColor = UIColor.blackColor.CGColor;
     self.containerView.layer.shadowOpacity = 0.00;
     self.containerView.layer.shadowRadius = 0;
     self.containerView.layer.shadowOffset = CGSizeMake(0, 0);
     // Prevent CoreAnimation shadow relayout jitter
     self.containerView.layer.shouldRasterize = YES;
     self.containerView.layer.rasterizationScale = UIScreen.mainScreen.scale;

     // Text
     self.nameLabel.textColor = UIColor.labelColor;
     self.messageLabel.textColor = UIColor.secondaryLabelColor;
     self.timeLabel.textColor = UIColor.tertiaryLabelColor;

     // Unread badge (Pure Pets color)
     self.unreadBadge.backgroundColor = AppPrimaryClr;
     self.unreadBadge.textColor = UIColor.whiteColor;
     self.unreadBadge.layer.cornerRadius = 10;
     self.unreadBadge.layer.masksToBounds = YES;

     // Online dot
     self.onlineDot.layer.cornerRadius = 5;
     self.onlineDot.layer.borderWidth = 2;
     self.onlineDot.layer.borderColor = UIColor.systemBackgroundColor.CGColor;
 }


#pragma mark - Configuration

- (void)configureWithThread:(ChatThreadModel *)thread {

    UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
    NSDate *displayDate = thread.lastMessageAt ?: thread.timestamp;
    if (displayDate) {
        NSDateFormatter *df = [NSDateFormatter new];
        df.timeStyle = NSDateFormatterShortStyle;
        self.timeLabel.text = [df stringFromDate:displayDate];
    } else {
        self.timeLabel.text = @"";
    }

    if (!user) {
        self.nameLabel.text = @"...";
        self.messageLabel.text = thread.lastMessage ?: @"";
        [self setUnreadCount:thread.unreadCount];
        [self applyPresenceOnline:NO lastSeen:nil];
        self.avatarView.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
        return;
    }

    self.nameLabel.text = user.UserName ?: @"";
    self.messageLabel.text = thread.lastMessage ?: @"";

    NSString *userID = user.ID ?: @"";
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";
    BOOL isSupportAvatar = PPChCellIsSupportAvatarURL(avatarURL);

    if ([self.representedUserID isEqualToString:userID] &&
        [self.representedAvatarURL isEqualToString:avatarURL]) {
        // already bound to same identity and avatar
    } else {
        self.representedUserID = userID;
        self.representedAvatarURL = avatarURL;

        if (isSupportAvatar) {
            self.avatarView.imageView.image = PPChCellSupportLogoImage();
            self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFit;
            self.avatarView.imageView.backgroundColor = UIColor.whiteColor;
        } else if (avatarURL.length > 0) {
            self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
            self.avatarView.imageView.backgroundColor = UIColor.clearColor;
            [PPImageLoaderManager.shared setImageOnImageView:self.avatarView.imageView
                                                         url:avatarURL
                                                 placeholder:PPSYSImage(@"person.crop.circle.fill")
                                                  complation:^(__unused UIImage * _Nullable image, __unused NSString * _Nullable urlString) {
            }];
        } else {
            self.avatarView.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
            self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
            self.avatarView.imageView.backgroundColor = UIColor.clearColor;
        }
    }

    [self setUnreadCount:thread.unreadCount];

    BOOL online =
        [[ChatPresenceManager shared] isUserOnline:user.ID];

    NSDate *lastSeen =
        [[ChatPresenceManager shared] lastSeenForUser:user.ID];

    [self applyPresenceOnline:online lastSeen:lastSeen];
}

- (NSString *)formattedLastSeen:(NSDate *)date
{
    NSCalendar *cal = NSCalendar.currentCalendar;

    NSDateFormatter *timeFormatter = [NSDateFormatter new];
    timeFormatter.timeStyle = NSDateFormatterShortStyle;
    timeFormatter.dateStyle = NSDateFormatterNoStyle;

    if ([cal isDateInToday:date]) {
        return [NSString stringWithFormat:@"%@ %@",
                kLang(@"chat.last_seen"),
                [NSString stringWithFormat:kLang(@"chat.today_at"),
                 [timeFormatter stringFromDate:date]]];
    }

    if ([cal isDateInYesterday:date]) {
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


- (void)applyPresenceOnline:(BOOL)online
                   lastSeen:(NSDate *)lastSeen
{
    self.lastSeenLabel.hidden = NO;

    // Online dot
    self.onlineDot.hidden = NO;
    self.onlineDot.backgroundColor =
        online ? UIColor.systemGreenColor : UIColor.quaternaryLabelColor;

    online ? [self startOnlinePulse] : [self stopOnlinePulse];

    if (online) {
        // ✅ Always show something
        self.lastSeenLabel.text = kLang(@"chat.online");
        return;
    }

    if (lastSeen) {
        self.lastSeenLabel.text = [self formattedLastSeen:lastSeen];
        return;
    }

    // 🔒 Fallback when lastSeen not available
    self.lastSeenLabel.text = kLang(@"chat.offline");
}



#pragma mark - State

- (void)setUnreadCount:(NSInteger)count {
    if (count <= 0) {
        self.unreadBadge.hidden = YES;
        return;
    }

    self.unreadBadge.hidden = NO;
    self.unreadBadge.text =
        count > 99 ? @"99+" : @(count).stringValue;
}

- (void)updateOnlineState:(BOOL)online {
    self.onlineDot.hidden = !online;
    self.onlineDot.backgroundColor = UIColor.systemGreenColor;

    online ? [self startOnlinePulse] : [self stopOnlinePulse];
}

#pragma mark - Animation

- (void)startOnlinePulse {
    if ([self.onlineDot.layer animationForKey:@"pulse"]) return;

    CABasicAnimation *pulse =
        [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @1.0;
    pulse.toValue = @1.25;
    pulse.duration = 1.6;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;

    [self.onlineDot.layer addAnimation:pulse forKey:@"pulse"];
}

- (void)stopOnlinePulse {
    [self.onlineDot.layer removeAnimationForKey:@"pulse"];
}

#pragma mark - Init
- (void)updatePresenceUI:(BOOL)isOnline {

    self.onlineDot.backgroundColor = isOnline
        ? UIColor.systemGreenColor
        : UIColor.tertiaryLabelColor;

    if (isOnline) {
        if (![self.onlineDot.layer animationForKey:@"pulse"]) {
            CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            pulse.fromValue = @1.0;
            pulse.toValue = @1.22;
            pulse.duration = 1.4;
            pulse.autoreverses = YES;
            pulse.repeatCount = HUGE_VALF;
            pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.onlineDot.layer addAnimation:pulse forKey:@"pulse"];
        }
    } else {
        [self.onlineDot.layer removeAllAnimations];
    }
    
    if (isOnline) {
        self.lastSeenLabel.hidden = YES;
    }
}

- (void)setOnline:(BOOL)isOnline {
    self.onlineDot.hidden = !isOnline;
}
@end


/*
 //
 //  ChCell.h
 //  Pure Pets
 //
 //  Created by Mohammed Ahmed on 22/01/2026.
 //

 //
 #import "ChCell.h"
 #import "ChatThreadModel.h"
 #import "PPImageLoaderManager.h"
 #import "ChatPresenceManager.h"
 @interface ChCell ()

 @property (nonatomic, strong) UIView *cardView;

 @property (nonatomic, strong) RoundedImageViewWithShadow *avatarView;
 @property (nonatomic, strong) UIView *onlineDot;
 @property (nonatomic, strong) UIImageView *bgView;

 @property (nonatomic, strong) UILabel *nameLabel;
 @property (nonatomic, strong) UILabel *messageLabel;
 @property (nonatomic, strong) UILabel *timeLabel;

 @property (nonatomic, strong) UILabel *unreadBadge;

 @end

 @implementation ChCell

 #pragma mark - Init
 - (void)updatePresenceUI:(BOOL)isOnline {

     self.onlineDot.backgroundColor = isOnline
         ? UIColor.systemGreenColor
         : UIColor.tertiaryLabelColor;

     if (isOnline) {
         if (![self.onlineDot.layer animationForKey:@"pulse"]) {
             CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
             pulse.fromValue = @1.0;
             pulse.toValue = @1.22;
             pulse.duration = 1.4;
             pulse.autoreverses = YES;
             pulse.repeatCount = HUGE_VALF;
             pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
             [self.onlineDot.layer addAnimation:pulse forKey:@"pulse"];
         }
     } else {
         [self.onlineDot.layer removeAllAnimations];
     }
 }
 
 - (void)setOnline:(BOOL)isOnline {
     self.onlineDot.hidden = !isOnline;
 }
 
 
 + (NSString *)reuseID {
     return @"ChCell";
 }

 - (instancetype)initWithStyle:(UITableViewCellStyle)style
               reuseIdentifier:(NSString *)reuseIdentifier {
     self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
     if (!self) return nil;

     self.backgroundColor = UIColor.clearColor;
     self.selectionStyle = UITableViewCellSelectionStyleNone;


     [self buildUI];
     [self buildLayout];
     [self applyStyle];
     
     
     self.contentView.clipsToBounds = NO;
     self.clipsToBounds = NO;
     
     self.contentView.layer.masksToBounds = NO;
     self.layer.masksToBounds = NO;

     return self;
 }

 #pragma mark - UI Setup

 - (void)handleTap {
     if (self.onTap) {
         self.onTap();
     }
 }


 - (void)buildUI {

     
     _bgView = [[UIImageView alloc] init];
     _bgView.translatesAutoresizingMaskIntoConstraints = NO;
     _bgView.contentMode = UIViewContentModeScaleAspectFill;
     _bgView.clipsToBounds = YES;
     _bgView.alpha = 0.2;
     [self.contentView addSubview:_bgView];

     
     UIButton *btn = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
     
      UIButtonConfiguration *config = btn.configuration;
      config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
      config.background.cornerRadius = 0;
     
     btn.configuration = config;
     btn.userInteractionEnabled = NO;
     
     btn.adjustsImageWhenHighlighted = NO;
     btn.adjustsImageWhenDisabled = NO;
     btn.showsTouchWhenHighlighted = NO;

     btn.configurationUpdateHandler = ^(UIButton *button) {
         button.alpha = 1.0;
         button.transform = CGAffineTransformIdentity;
     };

     btn.layer.actions = @{
         @"opacity": [NSNull null],
         @"transform": [NSNull null],
     };
     
     
     [btn addTarget:self   action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
     _cardView = btn;
     //_cardView = [[UIView alloc]init];
     _cardView.translatesAutoresizingMaskIntoConstraints = NO;
     //
     _cardView.userInteractionEnabled = NO;
    
     [self.contentView addSubview:_cardView];
     //_cardView.userInteractionEnabled = NO;
     _cardView.clipsToBounds = YES;
     
     
     _avatarView = [[RoundedImageViewWithShadow alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
     _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
     _avatarView.contentMode = UIViewContentModeScaleAspectFill;
     //_avatarView.clipsToBounds = YES;
     [self.cardView addSubview:_avatarView];

     _onlineDot = [UIView new];
     _onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
     _onlineDot.hidden = YES;
     [self.cardView addSubview:_onlineDot];

     _nameLabel = [UILabel new];
     _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
     _nameLabel.font = [GM boldFontWithSize:17];
     _nameLabel.adjustsFontForContentSizeCategory = YES;
     [self.cardView addSubview:_nameLabel];

     _messageLabel = [UILabel new];
     _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
     _messageLabel.font = [GM MidFontWithSize:15];
     _messageLabel.adjustsFontForContentSizeCategory = YES;
     _messageLabel.numberOfLines = 1;
     _messageLabel.textColor = UIColor.secondaryLabelColor;
     [self.cardView addSubview:_messageLabel];

     _timeLabel = [UILabel new];
     _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
     _timeLabel.font = [GM MidFontWithSize:14];
     [self.cardView addSubview:_timeLabel];

     _unreadBadge = [UILabel new];
     _unreadBadge.translatesAutoresizingMaskIntoConstraints = NO;
     _unreadBadge.hidden = YES;
     _unreadBadge.textAlignment = NSTextAlignmentCenter;
     _unreadBadge.font = [GM boldFontWithSize:12];
     [self.cardView addSubview:_unreadBadge];
     
     [self.cardView bringSubviewToFront:self.onlineDot];
 }

 #pragma mark - Layout

 - (void)buildLayout {

     UILayoutGuide *g = self.contentView.safeAreaLayoutGuide;

     [NSLayoutConstraint activateConstraints:@[

         [self.bgView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:5],
         [self.bgView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-5],
         [self.bgView.topAnchor constraintEqualToAnchor:g.topAnchor constant:5],
         [self.bgView.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-5],
         
         // Card
         [self.cardView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:-5],
         [self.cardView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:5],
         [self.cardView.topAnchor constraintEqualToAnchor:g.topAnchor constant:-5],
         [self.cardView.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:5],

         // Avatar
         [self.avatarView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
         [self.avatarView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
         [self.avatarView.widthAnchor constraintEqualToConstant:58],
         [self.avatarView.heightAnchor constraintEqualToConstant:58],

         // Online dot
         [self.onlineDot.widthAnchor constraintEqualToConstant:12],
         [self.onlineDot.heightAnchor constraintEqualToConstant:12],
         [self.onlineDot.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor constant:-1],
         [self.onlineDot.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:-1],

         // Time
         [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-24],
         [self.timeLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14],

         // Name
         [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:12],
         [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.timeLabel.leadingAnchor constant:-8],
         [self.nameLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],

         // Message
         [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
         [self.messageLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.unreadBadge.leadingAnchor constant:-8],
         [self.messageLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],

         // Unread badge
         [self.unreadBadge.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-14],
         [self.unreadBadge.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-14],
         [self.unreadBadge.widthAnchor  constraintEqualToConstant:20],
         [self.unreadBadge.heightAnchor constraintEqualToConstant:20],

     ]];
 }

 #pragma mark - Style

 - (void)applyStyle {

     self.cardView.backgroundColor = UIColor.clearColor;
     self.cardView.layer.cornerRadius = 0;
     self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
     self.cardView.layer.shadowOpacity = 0.0;
     self.cardView.layer.shadowRadius = 0;
     self.cardView.layer.shadowOffset = CGSizeMake(0, 6);
     self.cardView.layer.masksToBounds = NO;

     self.avatarView.layer.cornerRadius = 24;

     [self applyOnlineDotStyle];
     self.onlineDot.backgroundColor = UIColor.systemGreenColor;

     self.nameLabel.textColor = UIColor.labelColor;
     self.messageLabel.textColor = [UIColor colorWithWhite:0.25 alpha:1.0];
     self.timeLabel.textColor = UIColor.tertiaryLabelColor;

     self.unreadBadge.backgroundColor = UIColor.systemRedColor;
     self.unreadBadge.textColor = UIColor.whiteColor;
     self.unreadBadge.layer.cornerRadius = 10;
     self.unreadBadge.layer.masksToBounds = YES;
     
     self.contentView.layer.masksToBounds = NO;
     self.layer.masksToBounds = NO;
 }

 - (void)applyOnlineDotStyle {

     // Base dot
     self.onlineDot.backgroundColor = UIColor.systemGreenColor;
     self.onlineDot.layer.cornerRadius = 6;
     self.onlineDot.layer.masksToBounds = YES;

     // Add subtle border for accessibility/contrast
     self.onlineDot.layer.borderWidth = 1.0;
     self.onlineDot.layer.borderColor = UIColor.systemBackgroundColor.CGColor;

     // Add shadow for depth
     self.onlineDot.layer.shadowColor = UIColor.blackColor.CGColor;
     self.onlineDot.layer.shadowOpacity = 0.12;
     self.onlineDot.layer.shadowOffset = CGSizeMake(0, 2);
     self.onlineDot.layer.shadowRadius = 3;

     // Prepare for animation
     self.onlineDot.transform = CGAffineTransformIdentity;
 }

 - (void)animateOnlinePulse {
     CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
     pulse.duration = 1.6;
     pulse.fromValue = @1.0;
     pulse.toValue = @1.25;
     pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
     pulse.autoreverses = YES;
     pulse.repeatCount = INFINITY;

     [self.onlineDot.layer addAnimation:pulse forKey:@"onlinePulse"];
 }

 - (void)stopOnlinePulse {
     [self.onlineDot.layer removeAnimationForKey:@"onlinePulse"];
 }

 #pragma mark - Public API

 - (void)configureWithThread:(ChatThreadModel *)thread
 {
     //NSLog(@"🧵 [ThreadCell] configure START threadID=%@", thread.ID);

     if (!thread) {
         NSLog(@"❌ [ThreadCell] thread is NIL");
         return;
     }

     //NSLog(@"🧵 [ThreadCell] lastMessage=%@", thread.lastMessage);
     //NSLog(@"🧵 [ThreadCell] unreadCount=%ld", (long)thread.unreadCount);

     UserModel *otherUser = [ChatThreadModel resolveOtherUserFromThread:thread];

     if (!otherUser) {
         NSLog(@"❌ [ThreadCell] otherUser is NIL for threadID=%@", thread.ID);
     } else {
         //NSLog(@"👤 [ThreadCell] otherUserID=%@", otherUser.ID);
         //NSLog(@"👤 [ThreadCell] otherUserName=%@", otherUser.UserName);
     }

     self.nameLabel.text = otherUser.UserName ?: @"";
     self.messageLabel.text = thread.lastMessage ?: @"";
     NSString *avatarURL = otherUser.UserImageUrl.absoluteString ?: @"";
     BOOL isSupportAvatar = PPChCellIsSupportAvatarURL(avatarURL);

     NSDate *date =
         [thread respondsToSelector:@selector(lastMessageAt)]
             ? thread.lastMessageAt
             : [thread respondsToSelector:@selector(timestamp)]
                 ? thread.timestamp
                 : nil;

     //NSLog(@"⏰ [ThreadCell] date=%@", date);

     if (date) {
         NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
         formatter.dateStyle = NSDateFormatterNoStyle;
         formatter.timeStyle = NSDateFormatterShortStyle;
         self.timeLabel.text = [formatter stringFromDate:date];
     } else {
         self.timeLabel.text = @"";
     }

     if (isSupportAvatar) {
         self.avatarView.imageView.image = PPChCellSupportLogoImage();
         self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFit;
         self.avatarView.imageView.backgroundColor = UIColor.whiteColor;
         self.bgView.image = nil;
     } else if (avatarURL.length > 0) {
         //NSLog(@"🖼 [ThreadCell] loading avatar=%@", otherUser.UserImageUrl.absoluteString);
         self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
         self.avatarView.imageView.backgroundColor = UIColor.clearColor;
         [GM setImageFromUrlString:PPSafeString(avatarURL)
                         imageView:self.avatarView.imageView
                           phImage:@"person.crop.circle.fill" completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
             if(image) self.bgView.image = image;
         }];
     } else {
         //NSLog(@"🖼 [ThreadCell] using placeholder avatar");
         self.avatarView.imageView.image =
             [UIImage systemImageNamed:@"person.crop.circle.fill"];
         self.avatarView.imageView.contentMode = UIViewContentModeScaleAspectFill;
         self.avatarView.imageView.backgroundColor = UIColor.clearColor;
     }

    //NSLog(@"📬 [ThreadCell] setUnreadCount=%ld", (long)thread.unreadCount);
     [self setUnreadCount:thread.unreadCount];

     

     

     NSLog(@"✅ [ThreadCell] configure END threadID=%@", thread.ID);
     
     UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread];
         NSString *uid = user.ID;

     BOOL online = [[ChatPresenceManager shared] isUserOnline:uid];
     NSDate *lastSeen = [[ChatPresenceManager shared] lastSeenForUser:uid];


     

     
     self.onlineDot.hidden = NO; // always show container
     self.onlineDot.backgroundColor = online ? UIColor.systemGreenColor : UIColor.quaternaryLabelColor;

     // Pulse only when online
     if (online) {
         [self animateOnlinePulse];
     } else {
         [self stopOnlinePulse];
     }
     
     
 }
 - (void)setUnreadCount:(NSInteger)count {

     if (count <= 0) {
         self.unreadBadge.hidden = YES;
         return;
     }

     self.unreadBadge.hidden = NO;
     self.unreadBadge.text = count > 99 ? @"99+" : @(count).stringValue;
 }

 - (void)setOnline:(BOOL)isOnline {
     self.onlineDot.hidden = !isOnline;
 }

 - (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
     [super setHighlighted:highlighted animated:animated];

     CGFloat scale = highlighted ? 0.97 : 1.0;

     [UIView animateWithDuration:animated ? 0.15 : 0
                      animations:^{
         self.cardView.transform = CGAffineTransformMakeScale(scale, scale);
         self.cardView.alpha = highlighted ? 0.92 : 1.0;
     }];
 }

 @end

 */
