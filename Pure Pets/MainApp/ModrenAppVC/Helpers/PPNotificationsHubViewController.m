//
//  PPNotificationsHubViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//

#import "PPNotificationsHubViewController.h"
#import "PPPetRemindersViewController.h"
#import "UserChatsViewController.h"
#import "OrderDetailsViewController.h"
#import "PPOrder.h"
#import "ChNotificationRouter.h"
#import "AppClasses.h"
#import "Language.h"
@import FirebaseFirestore;
@import UserNotifications;

static CGFloat const kPPHubTopBarHeight = 44.0;
static CGFloat const kPPHubActionButtonSize = 44.0;

static NSString *PPHubTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPHubInboxCategoryTitle(NSDictionary *payload)
{
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubTrimmedString(payload[@"orderId"]);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return kLang(@"notifications_inbox_category_chat") ?: @"Chats";
    }
    if (orderID.length > 0 || [type hasPrefix:@"order"]) {
        return kLang(@"notifications_inbox_category_orders") ?: @"Orders";
    }
    return kLang(@"notifications_inbox_category_updates") ?: @"Updates";
}

static UIColor *PPHubInboxAccentColor(NSDictionary *payload)
{
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *status = [[PPHubTrimmedString(payload[@"status"]) lowercaseString] copy];
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return [GM appPrimaryColor];
    }
    if ([status containsString:@"deliver"] || [status containsString:@"paid"]) {
        return UIColor.systemGreenColor;
    }
    if ([status containsString:@"ship"]) {
        return UIColor.systemBlueColor;
    }
    if ([status containsString:@"fail"] || [status containsString:@"cancel"]) {
        return UIColor.systemRedColor;
    }
    return UIColor.systemOrangeColor;
}

static NSString *PPHubInboxSymbolName(NSDictionary *payload)
{
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubTrimmedString(payload[@"orderId"]);
    NSString *status = [[PPHubTrimmedString(payload[@"status"]) lowercaseString] copy];

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return @"ellipsis.message.fill";
    }
    if (orderID.length > 0 || [type hasPrefix:@"order"]) {
        if ([status containsString:@"deliver"]) return @"checkmark.seal.fill";
        if ([status containsString:@"ship"]) return @"shippingbox.fill";
        if ([status containsString:@"fail"] || [status containsString:@"cancel"]) return @"xmark.octagon.fill";
        return @"bag.fill.badge.plus";
    }
    return @"bell.badge.fill";
}

@interface PPHubTopTabsView : UIView
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *contentClipView;
@property (nonatomic, strong) UIView *selectionIndicator;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, strong) NSLayoutConstraint *indicatorLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *indicatorWidthConstraint;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) void (^onSelectionChanged)(NSInteger index);
- (instancetype)initWithTitles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons;
- (void)selectIndex:(NSInteger)index animated:(BOOL)animated;
@end

@implementation PPHubTopTabsView

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;

    _surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.82 : 0.95];
    _surfaceView.layer.cornerRadius = 28.0;
    _surfaceView.layer.masksToBounds = NO;
    _surfaceView.layer.borderWidth = 1.0;
    _surfaceView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16].CGColor;
    _surfaceView.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.20].CGColor;
    _surfaceView.layer.shadowOpacity = 0.12;
    _surfaceView.layer.shadowRadius = 14.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:_surfaceView];

    // Content clip view — clips indicator within rounded corners while surface keeps shadow
    _contentClipView = [[UIView alloc] initWithFrame:CGRectZero];
    _contentClipView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentClipView.backgroundColor = UIColor.clearColor;
    _contentClipView.layer.cornerRadius = 28.0;
    _contentClipView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _contentClipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_contentClipView];

    _selectionIndicator = [[UIView alloc] initWithFrame:CGRectZero];
    _selectionIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    UIColor *brand = [GM appPrimaryColor] ?: AppPrimaryClr ?: UIColor.systemOrangeColor;
    _selectionIndicator.backgroundColor = AppClearClr;// brand;
    _selectionIndicator.layer.cornerRadius = 22.0;
    _selectionIndicator.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _selectionIndicator.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_contentClipView addSubview:_selectionIndicator];

    UIStackView *stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.spacing = 0.0;
    [_contentClipView addSubview:stackView];

    UIImageSymbolConfiguration *symbolConfig = nil;
    if (@available(iOS 13.0, *)) {
        symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    }

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSUInteger count = MIN(titles.count, icons.count);
    for (NSUInteger index = 0; index < count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = (NSInteger)index;
        button.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.72;
        button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 8.0, 0.0, 8.0);

        UIImage *image = nil;
        if (@available(iOS 13.0, *)) {
            image = [[UIImage systemImageNamed:icons[index] withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            image = [UIImage imageNamed:icons[index]];
        }
        [button setImage:image forState:UIControlStateNormal];
        [button setTitle:[NSString stringWithFormat:@"  %@", titles[index]] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(pp_handleTap:) forControlEvents:UIControlEventTouchUpInside];
        [stackView addArrangedSubview:button];
        [buttons addObject:button];
    }
    self.tabButtons = buttons.copy;

    self.indicatorLeadingConstraint = [self.selectionIndicator.leadingAnchor constraintEqualToAnchor:self.contentClipView.leadingAnchor constant:5.0];
    self.indicatorWidthConstraint = [self.selectionIndicator.widthAnchor constraintEqualToConstant:100.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.surfaceView.heightAnchor constraintEqualToConstant:kPPHubTopBarHeight],

        [self.contentClipView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.contentClipView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.contentClipView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.contentClipView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        self.indicatorLeadingConstraint,
        [self.selectionIndicator.topAnchor constraintEqualToAnchor:self.contentClipView.topAnchor constant:5.0],
        [self.selectionIndicator.bottomAnchor constraintEqualToAnchor:self.contentClipView.bottomAnchor constant:-5.0],
        self.indicatorWidthConstraint,

        [stackView.topAnchor constraintEqualToAnchor:self.contentClipView.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:self.contentClipView.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.contentClipView.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.contentClipView.bottomAnchor],
    ]];

    self.selectedIndex = NSNotFound;
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                                         cornerRadius:self.surfaceView.layer.cornerRadius];
    self.surfaceView.layer.shadowPath = shadowPath.CGPath;

    if (self.selectedIndex != NSNotFound) {
        [self pp_updateSelectionIndicatorForIndex:self.selectedIndex animated:NO];
    }
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < 0 || index >= (NSInteger)self.tabButtons.count) return;
    self.selectedIndex = index;
    [self pp_updateSelectionIndicatorForIndex:index animated:animated];
    [self pp_refreshButtonAppearance];
}

- (void)pp_handleTap:(UIButton *)sender
{
    NSInteger index = sender.tag;
    if (index == self.selectedIndex) return;
    [self selectIndex:index animated:YES];
    if (self.onSelectionChanged) {
        self.onSelectionChanged(index);
    }
}

- (void)pp_updateSelectionIndicatorForIndex:(NSInteger)index animated:(BOOL)animated
{
    CGFloat containerWidth = CGRectGetWidth(self.surfaceView.bounds);
    if (containerWidth <= 0.0 || self.tabButtons.count == 0) return;

    CGFloat tabWidth = floor(containerWidth / (CGFloat)self.tabButtons.count);
    CGFloat width = MAX(68.0, tabWidth - 10.0);
    CGFloat leading = (tabWidth * (CGFloat)index) + ((tabWidth - width) * 0.5);

    self.indicatorLeadingConstraint.constant = leading;
    self.indicatorWidthConstraint.constant = width;

    void (^animations)(void) = ^{
        [self.surfaceView layoutIfNeeded];
    };

    if (!animated) {
        animations();
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.56
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:animations
                     completion:nil];
}

- (void)pp_refreshButtonAppearance
{
    UIColor *inactiveColor = AppSecondaryTextClr;
    for (NSInteger index = 0; index < (NSInteger)self.tabButtons.count; index++) {
        BOOL isSelected = (index == self.selectedIndex);
        UIButton *button = self.tabButtons[index];
        UIColor *titleColor = isSelected ? AppPrimaryClr : inactiveColor;
        button.tintColor = titleColor;
        [button setTitleColor:titleColor forState:UIControlStateNormal];
        button.alpha = isSelected ? 1.0 : 0.92;
    }
}

@end

@interface PPNotificationInboxItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *categoryTitle;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, copy) NSDictionary *payload;
@end

@implementation PPNotificationInboxItem
@end

@interface PPNotificationInboxCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
- (void)configureWithItem:(PPNotificationInboxItem *)item formatter:(NSDateFormatter *)formatter;
@end

@implementation PPNotificationInboxCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.0 : 0.96];
    _cardView.layer.cornerRadius = 24.0;
    _cardView.layer.masksToBounds = NO;
    _cardView.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.16].CGColor;
    _cardView.layer.shadowOpacity = 0.10;
    _cardView.layer.shadowRadius = 14.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:_cardView];

    _iconContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    _iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconContainerView.layer.cornerRadius = 20.0;
    _iconContainerView.layer.masksToBounds = YES;
    [_cardView addSubview:_iconContainerView];

    _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconContainerView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:16.0];
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.numberOfLines = 2;
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:13.0];
    _subtitleLabel.textColor = UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 2;
    [_cardView addSubview:_subtitleLabel];

    _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.font = [GM MidFontWithSize:12.0];
    _metaLabel.textColor = UIColor.tertiaryLabelColor;
    _metaLabel.numberOfLines = 1;
    [_cardView addSubview:_metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16.0],
        [self.iconContainerView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:40.0],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:40.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:18.0],
        [self.iconView.heightAnchor constraintEqualToConstant:18.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:16.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:14.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.metaLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:8.0],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.metaLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-16.0],
    ]];

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                                                cornerRadius:self.cardView.layer.cornerRadius].CGPath;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.metaLabel.text = @"";
    self.iconView.image = nil;
}

- (void)configureWithItem:(PPNotificationInboxItem *)item formatter:(NSDateFormatter *)formatter
{
    self.titleLabel.text = item.title ?: @"";
    self.subtitleLabel.text = item.subtitle ?: @"";
    NSString *dateText = @"";
    if ([item.timestamp isKindOfClass:NSDate.class]) {
        dateText = [formatter stringFromDate:item.timestamp] ?: @"";
    }
    if (dateText.length > 0 && item.categoryTitle.length > 0) {
        self.metaLabel.text = [NSString stringWithFormat:@"%@ • %@", item.categoryTitle, dateText];
    } else {
        self.metaLabel.text = item.categoryTitle.length > 0 ? item.categoryTitle : dateText;
    }

    UIColor *accent = item.accentColor ?: [GM appPrimaryColor] ?: UIColor.systemOrangeColor;
    self.iconContainerView.backgroundColor = [accent colorWithAlphaComponent:0.14];
    self.iconView.tintColor = accent;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
        self.iconView.image = [UIImage systemImageNamed:item.symbolName ?: @"bell.fill" withConfiguration:config];
    } else {
        self.iconView.image = [UIImage imageNamed:item.symbolName ?: @"bell.fill"];
    }
}

@end

@interface PPNotificationsInboxViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) NSArray<PPNotificationInboxItem *> *items;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
- (void)reloadNotifications;
@end

@implementation PPNotificationsInboxViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.items = @[];

    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    }
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = 100.0;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsMake(8.0, 0.0, 32.0, 0.0);
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:PPNotificationInboxCell.class forCellReuseIdentifier:@"PPNotificationInboxCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIView *emptyView = [[UIView alloc] initWithFrame:CGRectZero];
    emptyView.backgroundColor = UIColor.clearColor;

    UIImageView *emptyIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    emptyIconView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIconView.tintColor = UIColor.secondaryLabelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:42.0 weight:UIImageSymbolWeightRegular];
        emptyIconView.image = [UIImage systemImageNamed:@"bell.slash.fill" withConfiguration:config];
    }
    [emptyView addSubview:emptyIconView];

    self.emptyTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyTitleLabel.font = [GM boldFontWithSize:20.0];
    self.emptyTitleLabel.textColor = UIColor.labelColor;
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.text = kLang(@"notifications_inbox_empty_title") ?: @"No notifications yet";
    [emptyView addSubview:self.emptyTitleLabel];

    self.emptySubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptySubtitleLabel.font = [GM MidFontWithSize:14.0];
    self.emptySubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.numberOfLines = 0;
    self.emptySubtitleLabel.text = kLang(@"notifications_inbox_empty_subtitle") ?: @"Order updates and chat alerts will show up here.";
    [emptyView addSubview:self.emptySubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [emptyIconView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [emptyIconView.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:-38.0],

        [self.emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIconView.bottomAnchor constant:16.0],
        [self.emptyTitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:28.0],
        [self.emptyTitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-28.0],

        [self.emptySubtitleLabel.topAnchor constraintEqualToAnchor:self.emptyTitleLabel.bottomAnchor constant:8.0],
        [self.emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:34.0],
        [self.emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-34.0],
    ]];
    self.tableView.backgroundView = emptyView;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:@"PPRemoteNotificationTapped"
                                               object:nil];

    [self reloadNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pp_handleRefreshNotification:(NSNotification *)notification
{
    (void)notification;
    [self reloadNotifications];
}

- (void)reloadNotifications
{
    __weak typeof(self) weakSelf = self;
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        NSMutableArray<PPNotificationInboxItem *> *items = [NSMutableArray array];
        for (UNNotification *notification in notifications ?: @[]) {
            UNNotificationContent *content = notification.request.content;
            NSDictionary *payload = [content.userInfo isKindOfClass:NSDictionary.class] ? content.userInfo : @{};

            NSString *title = PPHubTrimmedString(content.title);
            if (title.length == 0) {
                title = PPHubInboxCategoryTitle(payload);
            }

            NSString *subtitle = PPHubTrimmedString(content.body);
            if (subtitle.length == 0) {
                subtitle = PPHubTrimmedString(payload[@"message"] ?: payload[@"status"]);
            }

            PPNotificationInboxItem *item = [PPNotificationInboxItem new];
            item.identifier = PPHubTrimmedString(notification.request.identifier);
            item.title = title;
            item.subtitle = subtitle;
            item.categoryTitle = PPHubInboxCategoryTitle(payload);
            item.symbolName = PPHubInboxSymbolName(payload);
            item.accentColor = PPHubInboxAccentColor(payload);
            item.timestamp = notification.date;
            item.payload = payload;
            [items addObject:item];
        }

        [items sortUsingComparator:^NSComparisonResult(PPNotificationInboxItem *a, PPNotificationInboxItem *b) {
            NSDate *first = a.timestamp ?: [NSDate distantPast];
            NSDate *second = b.timestamp ?: [NSDate distantPast];
            return [second compare:first];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.items = items.copy;
            [strongSelf.tableView reloadData];
            strongSelf.tableView.backgroundView.hidden = (strongSelf.items.count > 0);
        });
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPNotificationInboxCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPNotificationInboxCell" forIndexPath:indexPath];
    if (indexPath.row < (NSInteger)self.items.count) {
        [cell configureWithItem:self.items[indexPath.row] formatter:self.dateFormatter];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.items.count) return;

    PPNotificationInboxItem *item = self.items[indexPath.row];
    NSDictionary *payload = item.payload ?: @{};
    NSString *threadID = PPHubTrimmedString(payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPHubTrimmedString(payload[@"orderId"]);
    NSString *type = [[PPHubTrimmedString(payload[@"type"]) lowercaseString] copy];

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        [[ChNotificationRouter shared] handleChatNotification:payload fromViewController:self];
        return;
    }

    if (orderID.length == 0 && ![type hasPrefix:@"order"]) {
        return;
    }

    if (orderID.length == 0) {
        [PPHUD showInfo:kLang(@"notifications_inbox_empty_subtitle") ?: @"Notifications"];
        return;
    }

    FIRDocumentReference *orderRef = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    __weak typeof(self) weakSelf = self;
    [orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !snapshot.exists) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order data is unavailable right now."];
                return;
            }

            PPOrder *order = [PPOrder orderFromSnapshot:snapshot];
            if (!order) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order data is unavailable right now."];
                return;
            }

            OrderDetailsViewController *detailsVC = [[OrderDetailsViewController alloc] initWithOrder:order];
            detailsVC.order = order;
            [strongSelf.navigationController pushViewController:detailsVC animated:YES];
        });
    }];
}

@end

@interface PPNotificationsHubViewController ()
@property (nonatomic, strong) UIView *backgroundTopGlowView;
@property (nonatomic, strong) UIView *backgroundBottomGlowView;
@property (nonatomic, strong) UIView *topChromeContainerView;
@property (nonatomic, strong) PPHubTopTabsView *tabsView;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *contentContainerView;
@property (nonatomic, strong) UIViewController *activeChild;
@property (nonatomic, strong) NSArray<UIViewController *> *childControllers;
@property (nonatomic, strong) PPPetRemindersViewController *remindersVC;
@property (nonatomic, strong) UserChatsViewController *chatsVC;
@property (nonatomic, strong) PPNotificationsInboxViewController *notificationsVC;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation PPNotificationsHubViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.selectedIndex = 0;

    self.chatsVC = [UserChatsViewController new];
    self.remindersVC = [PPPetRemindersViewController new];
    self.notificationsVC = [PPNotificationsInboxViewController new];
    self.childControllers = @[self.chatsVC, self.remindersVC, self.notificationsVC];

    [self pp_setupNavigationChrome];
    [self pp_setupBackdrop];
    [self pp_setupTopChrome];
    [self pp_setupContentContainer];
    [self pp_showChildAtIndex:self.selectedIndex animated:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_setupNavigationChrome];
    [self pp_applyNavigationItems];
    [self pp_refreshActionButtonForIndex:self.selectedIndex];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;

    self.backgroundTopGlowView.frame = CGRectMake(-72.0, safeTop - 44.0, width * 0.72, width * 0.72);
    self.backgroundBottomGlowView.frame = CGRectMake(width - (width * 0.60) + 40.0,
                                                     height - (width * 0.56) - safeBottom - 90.0,
                                                     width * 0.60,
                                                     width * 0.60);
    self.backgroundTopGlowView.layer.cornerRadius = CGRectGetWidth(self.backgroundTopGlowView.bounds) * 0.5;
    self.backgroundBottomGlowView.layer.cornerRadius = CGRectGetWidth(self.backgroundBottomGlowView.bounds) * 0.5;

    CGFloat chromeWidth = floor(width * 0.80);
    self.topChromeContainerView.frame = CGRectMake(0.0, 0.0, chromeWidth, kPPHubTopBarHeight);
    self.actionButton.frame = CGRectMake(0.0, 0.0, kPPHubActionButtonSize, kPPHubActionButtonSize);
    [self pp_applyNavigationItems];

    self.contentContainerView.frame = self.view.bounds;
    self.activeChild.view.frame = self.contentContainerView.bounds;
}

#pragma mark - Setup

- (void)pp_setupNavigationChrome
{
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:nil showBack:NO];
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)pp_setupBackdrop
{
    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    self.backgroundTopGlowView.backgroundColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.10];
    [self.view addSubview:self.backgroundTopGlowView];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    self.backgroundBottomGlowView.backgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.06];
    [self.view addSubview:self.backgroundBottomGlowView];
}

- (void)pp_setupTopChrome
{
    CGFloat initialWidth = floor(CGRectGetWidth(self.view.bounds) * 0.80);
    self.topChromeContainerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, initialWidth, kPPHubTopBarHeight)];
    self.topChromeContainerView.backgroundColor = UIColor.clearColor;

    NSArray<NSString *> *titles = @[
        (kLang(@"pet_chats_tab") ?: @"Chats"),
        (kLang(@"pet_reminders_tab") ?: @"Reminders"),
        (kLang(@"notifications_inbox_tab") ?: @"Notifications")
    ];
    NSArray<NSString *> *icons = @[
        @"ellipsis.message.fill",
        @"bell.badge.fill",
        @"app.badge.fill"
    ];
    self.tabsView = [[PPHubTopTabsView alloc] initWithTitles:titles icons:icons];
    __weak typeof(self) weakSelf = self;
    self.tabsView.onSelectionChanged = ^(NSInteger index) {
        [weakSelf pp_showChildAtIndex:index animated:YES];
    };
    [self.topChromeContainerView addSubview:self.tabsView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tabsView.topAnchor constraintEqualToAnchor:self.topChromeContainerView.topAnchor],
        [self.tabsView.leadingAnchor constraintEqualToAnchor:self.topChromeContainerView.leadingAnchor],
        [self.tabsView.trailingAnchor constraintEqualToAnchor:self.topChromeContainerView.trailingAnchor],
        [self.tabsView.bottomAnchor constraintEqualToAnchor:self.topChromeContainerView.bottomAnchor],
    ]];

    
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration glassButtonConfiguration];
        
        self.actionButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
    } else {
        self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
   
    }

    
    self.actionButton.frame = CGRectMake(0.0, 0.0, kPPHubActionButtonSize, kPPHubActionButtonSize);
    self.actionButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.0 : 0.96];
    self.actionButton.tintColor = [GM appPrimaryColor];
    self.actionButton.layer.cornerRadius = kPPHubActionButtonSize * 0.5;
    self.actionButton.clipsToBounds = NO;
    self.actionButton.layer.borderWidth = 1.0;
    if(!PPIOS26())
    {
        self.actionButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14].CGColor;
    }
    
    self.actionButton.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.18].CGColor;
    self.actionButton.layer.shadowOpacity = 0.10;
    self.actionButton.layer.shadowRadius = 10.0;
    self.actionButton.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    self.actionButton.accessibilityHint = kLang(@"empty_retry_button") ?: @"";
    if (@available(iOS 13.0, *)) {
        self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.actionButton addTarget:self action:@selector(pp_handleActionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyNavigationItems];
}

- (void)pp_setupContentContainer
{
    self.contentContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentContainerView.backgroundColor = UIColor.clearColor;
    self.contentContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentContainerView];
}

- (void)pp_applyNavigationItems
{
    if (!self.topChromeContainerView || !self.actionButton) return;

    UIBarButtonItem *tabsItem = [[UIBarButtonItem alloc] initWithCustomView:self.topChromeContainerView];
    UIView *actionContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, kPPHubActionButtonSize, kPPHubActionButtonSize)];
    actionContainer.backgroundColor = UIColor.clearColor;
    self.actionButton.center = CGPointMake(CGRectGetMidX(actionContainer.bounds), CGRectGetMidY(actionContainer.bounds));
    if (self.actionButton.superview != actionContainer) {
        [self.actionButton removeFromSuperview];
        [actionContainer addSubview:self.actionButton];
    }
    UIBarButtonItem *actionItem = [[UIBarButtonItem alloc] initWithCustomView:actionContainer];

    self.navigationItem.leftBarButtonItem = tabsItem;
    self.navigationItem.rightBarButtonItem = actionItem;
}

#pragma mark - Child Flow

- (void)pp_showChildAtIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < 0 || index >= (NSInteger)self.childControllers.count) return;

    UIViewController *nextChild = self.childControllers[index];
    if (self.activeChild == nextChild) {
        [self pp_refreshActionButtonForIndex:index];
        [self.tabsView selectIndex:index animated:animated];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
        return;
    }

    UIViewController *previousChild = self.activeChild;
    self.selectedIndex = index;
    [self.tabsView selectIndex:index animated:animated];

    if (previousChild) {
        [previousChild willMoveToParentViewController:nil];
    }

    [self addChildViewController:nextChild];
    nextChild.view.frame = self.contentContainerView.bounds;
    nextChild.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    if (!animated || !previousChild) {
        [previousChild.view removeFromSuperview];
        [previousChild removeFromParentViewController];
        [self.contentContainerView addSubview:nextChild.view];
        [nextChild didMoveToParentViewController:self];
        self.activeChild = nextChild;
        [self pp_refreshActionButtonForIndex:index];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
        return;
    }

    nextChild.view.alpha = 0.0;
    nextChild.view.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [self.contentContainerView addSubview:nextChild.view];

    [UIView animateWithDuration:0.26
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowAnimatedContent
                     animations:^{
        previousChild.view.alpha = 0.0;
        previousChild.view.transform = CGAffineTransformMakeTranslation(0.0, -8.0);
        nextChild.view.alpha = 1.0;
        nextChild.view.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [previousChild.view removeFromSuperview];
        previousChild.view.alpha = 1.0;
        previousChild.view.transform = CGAffineTransformIdentity;
        [previousChild removeFromParentViewController];
        [nextChild didMoveToParentViewController:self];
        self.activeChild = nextChild;
        [self pp_refreshActionButtonForIndex:index];
        if (index == 2) {
            [self.notificationsVC reloadNotifications];
        }
    }];
}

- (void)pp_refreshActionButtonForIndex:(NSInteger)index
{
    NSString *symbolName = @"arrow.clockwise";
    NSString *accessibilityLabel = kLang(@"empty_retry_button") ?: @"Refresh";
    BOOL enabled = YES;

    switch (index) {
        case 0:
            symbolName = @"square.and.pencil";
            accessibilityLabel = kLang(@"empty_chats_button") ?: @"Start chat";
            enabled = [self.chatsVC respondsToSelector:@selector(startNewChat)];
            break;
        case 1:
            symbolName = @"plus";
            accessibilityLabel = kLang(@"pet_reminder_add") ?: @"Add Reminder";
            enabled = [self.remindersVC respondsToSelector:@selector(pp_addReminder)];
            break;
        case 2:
        default:
            symbolName = @"arrow.clockwise";
            accessibilityLabel = kLang(@"empty_retry_button") ?: @"Refresh";
            enabled = YES;
            break;
    }

    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold];
        image = [UIImage systemImageNamed:symbolName withConfiguration:config];
    } else {
        image = [UIImage imageNamed:symbolName];
    }
    [self.actionButton setImage:image forState:UIControlStateNormal];
    self.actionButton.accessibilityLabel = accessibilityLabel;
    self.actionButton.enabled = enabled;
    self.actionButton.alpha = enabled ? 1.0 : 0.45;
    self.actionButton.backgroundColor = AppClearClr;
}

- (void)pp_handleActionButtonTapped
{
    switch (self.selectedIndex) {
        case 0:
            [self pp_invokeAction:@selector(startNewChat) onTarget:self.chatsVC];
            break;
        case 1:
            [self pp_invokeAction:@selector(pp_addReminder) onTarget:self.remindersVC];
            break;
        case 2:
        default:
            [self.notificationsVC reloadNotifications];
            break;
    }
}

- (void)pp_invokeAction:(SEL)selector onTarget:(id)target
{
    if (!target || ![target respondsToSelector:selector]) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [target performSelector:selector];
#pragma clang diagnostic pop
}

@end
