//
//  PPPetRemindersViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//  Modern UI refactor — card cells with type icons, skeleton, empty state, toggle, swipe delete.
//

#import "PPPetRemindersViewController.h"
#import "PPReminderEditorViewController.h"
#import "PPPetProfilesViewController.h"
#import "PPPetReminder.h"
#import "PPPetProfile.h"
#import "UserManager.h"
#import "Language.h"
#import "GM.h"
#import "PPPetProfilesUIStyle.h"
#import "PPReminderNotificationManager.h"

// ─── Helpers ──────────────────────────────────────────────

/// Returns a localized display string for a repeat-rule value.
static NSString * PPRemRepeatDisplayText(NSString *rule) {
    if ([rule isEqualToString:@"daily"])   return kLang(@"pet_reminder_repeat_daily")   ?: @"Every Day";
    if ([rule isEqualToString:@"weekly"])  return kLang(@"pet_reminder_repeat_weekly")  ?: @"Every Week";
    if ([rule isEqualToString:@"monthly"]) return kLang(@"pet_reminder_repeat_monthly") ?: @"Every Month";
    if ([rule isEqualToString:@"yearly"])  return kLang(@"pet_reminder_repeat_yearly")  ?: @"Every Year";
    return nil; // no repeat — return nil so caller can hide badge
}

// ─── Skeleton Cell ────────────────────────────────────────

@interface PPReminderSkeletonCell : UITableViewCell
@end

@implementation PPReminderSkeletonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;
    self.selectionStyle  = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(card, PPCornerCard);
    card.layer.shadowOpacity = 0.04;
    card.layer.shadowRadius = 16.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [self.contentView addSubview:card];

    UIView *icon = [self pp_sh:40 h:40 r:20];
    UIView *l1   = [self pp_sh:140 h:14 r:7];
    UIView *l2   = [self pp_sh:100 h:12 r:6];
    [card addSubview:icon]; [card addSubview:l1]; [card addSubview:l2];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:PPSpaceXS],
        [card.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:PPScreenMargin],
        [card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [card.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor   constant:-PPSpaceXS],

        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceBase],
        [icon.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [icon.widthAnchor   constraintEqualToConstant:40],
        [icon.heightAnchor  constraintEqualToConstant:40],

        [l1.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:PPSpaceMD],
        [l1.topAnchor     constraintEqualToAnchor:icon.topAnchor constant:PPSpaceXXS],
        [l2.leadingAnchor constraintEqualToAnchor:l1.leadingAnchor],
        [l2.topAnchor     constraintEqualToAnchor:l1.bottomAnchor constant:PPSpaceSM],
    ]];
    return self;
}

- (UIView *)pp_sh:(CGFloat)w h:(CGFloat)h r:(CGFloat)r {
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = UIColor.tertiarySystemFillColor;
    PPApplyContinuousCorners(v, r);
    [v.widthAnchor  constraintEqualToConstant:w].active = YES;
    [v.heightAnchor constraintEqualToConstant:h].active = YES;

    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors     = @[(id)[UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.4].CGColor,
                      (id)[UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.1].CGColor,
                      (id)[UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.4].CGColor];
    g.startPoint = CGPointMake(0, 0.5);
    g.endPoint   = CGPointMake(1, 0.5);
    g.frame      = CGRectMake(0, 0, w * 3, h);
    [v.layer addSublayer:g];

    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    a.fromValue      = @(-w * 2);
    a.toValue        = @(w);
    a.duration       = 1.5;
    a.repeatCount    = HUGE_VALF;
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [g addAnimation:a forKey:@"shimmer"];
    return v;
}

@end

// ─── Reminder Card Cell ───────────────────────────────────

@interface PPReminderCardCell : UITableViewCell
@property (nonatomic, strong) UIView      *cardContainer;
@property (nonatomic, strong) UIView      *typeCircle;
@property (nonatomic, strong) UIImageView *typeIcon;
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UILabel     *detailLabel;
@property (nonatomic, strong) UILabel     *dateLabel;
@property (nonatomic, strong) UIView      *repeatBadge;
@property (nonatomic, strong) UIImageView *repeatIcon;
@property (nonatomic, strong) UILabel     *repeatLabel;
@property (nonatomic, strong) UISwitch    *enableSwitch;
@property (nonatomic, copy)   void (^onToggle)(BOOL on);
@end

@implementation PPReminderCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;
    self.selectionStyle  = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _cardContainer = [UIView new];
    _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(_cardContainer, PPCornerCard);
    [self.contentView addSubview:_cardContainer];

    _typeCircle = [UIView new];
    _typeCircle.translatesAutoresizingMaskIntoConstraints = NO;
    _typeCircle.layer.cornerRadius = 20;
    [_cardContainer addSubview:_typeCircle];

    _typeIcon = [UIImageView new];
    _typeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _typeIcon.tintColor = UIColor.whiteColor;
    [_typeCircle addSubview:_typeIcon];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font          = [GM boldFontWithSize:PPFontHeadline];
    _titleLabel.textColor     = PPPetsUIPrimaryTextColor();
    _titleLabel.numberOfLines = 1;
    [_cardContainer addSubview:_titleLabel];

    _detailLabel = [UILabel new];
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.font      = [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightRegular];
    _detailLabel.textColor = PPPetsUISecondaryTextColor();
    [_cardContainer addSubview:_detailLabel];

    _dateLabel = [UILabel new];
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateLabel.font      = [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium];
    _dateLabel.textColor = PPPetsUIBrandColor();
    [_cardContainer addSubview:_dateLabel];

    // Repeat badge (pill with icon + label)
    _repeatBadge = [UIView new];
    _repeatBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _repeatBadge.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.10];
    _repeatBadge.layer.cornerRadius = 10.0;
    _repeatBadge.layer.masksToBounds = YES;
    [_cardContainer addSubview:_repeatBadge];

    _repeatIcon = [UIImageView new];
    _repeatIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _repeatIcon.contentMode = UIViewContentModeScaleAspectFit;
    _repeatIcon.tintColor = PPPetsUIBrandColor();
    _repeatIcon.image = [[UIImage systemImageNamed:@"repeat"]
                          imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [_repeatBadge addSubview:_repeatIcon];

    _repeatLabel = [UILabel new];
    _repeatLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _repeatLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    _repeatLabel.textColor = PPPetsUIBrandColor();
    [_repeatBadge addSubview:_repeatLabel];

    _enableSwitch = [UISwitch new];
    _enableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _enableSwitch.onTintColor = PPPetsUIBrandColor();
    [_enableSwitch addTarget:self action:@selector(pp_toggled) forControlEvents:UIControlEventValueChanged];
    [_cardContainer addSubview:_enableSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [_cardContainer.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:PPSpaceXS],
        [_cardContainer.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:PPScreenMargin],
        [_cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [_cardContainer.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor   constant:-PPSpaceXS],

        [_typeCircle.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:PPSpaceBase],
        [_typeCircle.centerYAnchor constraintEqualToAnchor:_cardContainer.centerYAnchor],
        [_typeCircle.widthAnchor   constraintEqualToConstant:40],
        [_typeCircle.heightAnchor  constraintEqualToConstant:40],
        [_typeCircle.topAnchor     constraintGreaterThanOrEqualToAnchor:_cardContainer.topAnchor    constant:PPSpaceMD],
        [_typeCircle.bottomAnchor  constraintLessThanOrEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceMD],

        [_typeIcon.centerXAnchor constraintEqualToAnchor:_typeCircle.centerXAnchor],
        [_typeIcon.centerYAnchor constraintEqualToAnchor:_typeCircle.centerYAnchor],
        [_typeIcon.widthAnchor   constraintEqualToConstant:20],
        [_typeIcon.heightAnchor  constraintEqualToConstant:20],

        [_enableSwitch.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceBase],
        [_enableSwitch.centerYAnchor  constraintEqualToAnchor:_cardContainer.centerYAnchor],

        [_titleLabel.topAnchor      constraintEqualToAnchor:_typeCircle.topAnchor],
        [_titleLabel.leadingAnchor  constraintEqualToAnchor:_typeCircle.trailingAnchor constant:PPSpaceMD],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_enableSwitch.leadingAnchor constant:-PPSpaceSM],

        [_detailLabel.topAnchor     constraintEqualToAnchor:_titleLabel.bottomAnchor constant:PPSpaceXXS],
        [_detailLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_detailLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_dateLabel.topAnchor     constraintEqualToAnchor:_detailLabel.bottomAnchor constant:PPSpaceXXS],
        [_dateLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_dateLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        // Repeat badge (below dateLabel)
        [_repeatBadge.topAnchor     constraintEqualToAnchor:_dateLabel.bottomAnchor constant:PPSpaceXXS],
        [_repeatBadge.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_repeatBadge.heightAnchor  constraintEqualToConstant:20.0],
        [_repeatBadge.bottomAnchor  constraintLessThanOrEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceMD],

        [_repeatIcon.leadingAnchor constraintEqualToAnchor:_repeatBadge.leadingAnchor constant:6.0],
        [_repeatIcon.centerYAnchor constraintEqualToAnchor:_repeatBadge.centerYAnchor],
        [_repeatIcon.widthAnchor   constraintEqualToConstant:12.0],
        [_repeatIcon.heightAnchor  constraintEqualToConstant:12.0],

        [_repeatLabel.leadingAnchor  constraintEqualToAnchor:_repeatIcon.trailingAnchor constant:4.0],
        [_repeatLabel.centerYAnchor  constraintEqualToAnchor:_repeatBadge.centerYAnchor],
        [_repeatLabel.trailingAnchor constraintEqualToAnchor:_repeatBadge.trailingAnchor constant:-8.0],
    ]];
    return self;
}

- (void)configureWithReminder:(PPPetReminder *)rem petName:(NSString *)petName {
    self.titleLabel.text = rem.title.length ? rem.title : [rem displayTypeText];

    NSString *pName   = petName.length ? petName : (kLang(@"pet_unknown") ?: @"Pet");
    NSString *typeTxt = [rem displayTypeText];
    self.detailLabel.text = [NSString stringWithFormat:@"%@ · %@", pName, typeTxt];

    self.dateLabel.text = rem.fireDate ? [GM formattedDate:rem.fireDate]
                                       : (kLang(@"pet_reminder_no_date") ?: @"No date set");
    self.enableSwitch.on = rem.enabled;

    // Repeat badge
    NSString *repeatText = PPRemRepeatDisplayText(rem.repeatRule);
    if (repeatText.length > 0) {
        self.repeatBadge.hidden = NO;
        self.repeatLabel.text = repeatText;
    } else {
        self.repeatBadge.hidden = YES;
    }

    UIColor *typeClr; NSString *iconName;
    switch (rem.type) {
        case PPPetReminderTypeVaccination:
            typeClr  = UIColor.systemTealColor;
            iconName = @"syringe.fill";
            break;
        case PPPetReminderTypeFood:
            typeClr  = UIColor.systemOrangeColor;
            iconName = @"fork.knife";
            break;
        case PPPetReminderTypeAppointment:
            typeClr  = PPPetsUIBrandColor();
            iconName = @"calendar.badge.clock";
            break;
    }
    self.typeCircle.backgroundColor = typeClr;
    self.typeIcon.image = [[UIImage systemImageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.cardContainer.alpha = rem.enabled ? 1.0 : 0.55;

    // RTL
    self.cardContainer.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.titleLabel.textAlignment  = Language.alignmentForCurrentLanguage;
    self.detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.dateLabel.textAlignment   = Language.alignmentForCurrentLanguage;

    // Accessibility
    self.isAccessibilityElement = NO;
    self.accessibilityElements = @[self.cardContainer];
    self.cardContainer.isAccessibilityElement = YES;
    self.cardContainer.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@",
        self.titleLabel.text ?: @"",
        self.detailLabel.text ?: @"",
        self.dateLabel.text ?: @""];
    self.cardContainer.accessibilityTraits = UIAccessibilityTraitButton;
    self.enableSwitch.accessibilityLabel = kLang(@"pet_reminder_toggle") ?: @"Enable reminder";
}

- (void)pp_toggled { if (self.onToggle) self.onToggle(self.enableSwitch.isOn); }

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    highlighted ? PPTapFeedbackDown(self.cardContainer) : PPTapFeedbackUp(self.cardContainer);
}

@end

// ─── View Controller ──────────────────────────────────────

@interface PPPetRemindersViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPPetReminder *> *reminders;
@property (nonatomic, strong) NSDictionary<NSString *, PPPetProfile *> *petMap;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasAppearedOnce;
@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;
@property (nonatomic, strong) NSArray<UIView *> *floatingCircles;
@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) PPInsetLabel *headerEyebrowLabel;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) PPInsetLabel *headerMetaLabel;
@property (nonatomic, strong) UIImageView *headerSymbolView;
@property (nonatomic, strong) UIButton *headerPrimaryButton;
@property (nonatomic, strong) UIButton *headerSecondaryButton;
@end

static NSString *const kRemCardID  = @"PPReminderCardCell";
static NSString *const kRemSkelID  = @"PPReminderSkeletonCell";
static NSString *const kRemEmptyID = @"PPReminderEmptyCell";

@implementation PPPetRemindersViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title     = kLang(@"pet_reminders_tab") ?: @"Pet Reminders";
    self.reminders = @[];
    self.petMap    = @{};
    self.isLoading = YES;

    // Nav — AddressFormVC style
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pp_handleBack)];
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"plus.circle.fill"]
                style:UIBarButtonItemStylePlain target:self action:@selector(pp_addReminder)];
    addBtn.tintColor = AppPrimaryClr;
    self.navigationItem.rightBarButtonItem = addBtn;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource       = self;
    self.tableView.delegate         = self;
    self.tableView.backgroundColor  = UIColor.clearColor;
    self.tableView.separatorStyle   = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset     = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    
    [self.tableView registerClass:PPReminderCardCell.class     forCellReuseIdentifier:kRemCardID];
    [self.tableView registerClass:PPReminderSkeletonCell.class forCellReuseIdentifier:kRemSkelID];
    [self.tableView registerClass:UITableViewCell.class        forCellReuseIdentifier:kRemEmptyID];
    [self.view addSubview:self.tableView];

    [self pp_setupBackdrop];
    [self pp_buildHeroHeader];
    [self pp_applyCanvasBackground];
    [self pp_refreshHeroHeaderContent];

    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(pp_pullRefresh) forControlEvents:UIControlEventValueChanged];
    rc.tintColor = AppPrimaryClr;
    self.tableView.refreshControl = rc;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.semanticContentAttribute      = PPPetsCurrentSemanticAttribute();
    self.tableView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self pp_applyCanvasBackground];
    [self pp_refreshHeroHeaderContent];
    [self pp_reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    PPPetsBeginFloatingAnimations(self.backgroundGlowViewTop, self.backgroundGlowViewBottom, self.floatingCircles);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_applyCanvasBackground];
    self.backgroundGlowViewTop.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewTop.bounds) * 0.5;
    self.backgroundGlowViewBottom.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewBottom.bounds) * 0.5;
    [self.view sendSubviewToBack:self.backgroundGlowViewBottom];
    [self.view sendSubviewToBack:self.backgroundGlowViewTop];
    [self pp_updateHeaderLayout];
}

#pragma mark - Appearance

- (void)pp_applyCanvasBackground {
    PPPetsApplyCanvasBackground(self, nil);
    self.tableView.backgroundColor = UIColor.clearColor;
}

- (void)pp_setupBackdrop {
    if (self.backgroundGlowViewTop || self.backgroundGlowViewBottom) {
        return;
    }

    UIView *topGlow = PPPetsBuildGlowView(PPPetsGlowFill(0.93, 0.80, 0.69, 0.12),
                                          PPPetsGlowFill(0.98, 0.82, 0.60, 1.0),
                                          0.10,
                                          64.0);
    UIView *bottomGlow = PPPetsBuildGlowView(PPPetsGlowFill(0.72, 0.45, 0.42, 0.06),
                                             PPPetsGlowFill(0.68, 0.27, 0.33, 1.0),
                                             0.08,
                                             72.0);

    [self.view insertSubview:topGlow belowSubview:self.tableView];
    [self.view insertSubview:bottomGlow belowSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-72.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:200.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:200.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0],
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;

    self.floatingCircles = PPPetsBuildFloatingCircles(self.view);
}

- (void)pp_buildHeroHeader {
    self.headerRoot = [[UIView alloc] init];
    self.headerRoot.backgroundColor = UIColor.clearColor;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(cardView, 34.0);
    [self.headerRoot addSubview:cardView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = PPPetsUISurfaceTintColor();
    tintView.layer.cornerRadius = 34.0;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    UIView *ambientGlow = PPPetsBuildGlowView([PPPetsUIBrandColor() colorWithAlphaComponent:0.16],
                                              [PPPetsUIBrandColor() colorWithAlphaComponent:0.50],
                                              0.16,
                                              42.0);
    ambientGlow.layer.cornerRadius = 94.0;
    [cardView addSubview:ambientGlow];

    UIView *secondaryGlow = PPPetsBuildGlowView(PPPetsCardOverlay(0.40),
                                                PPPetsCardOverlay(0.45),
                                                0.20,
                                                22.0);
    secondaryGlow.layer.cornerRadius = 58.0;
    [cardView addSubview:secondaryGlow];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = PPPetsUIBrandColor();
    accentBar.layer.cornerRadius = 2.0;
    [cardView addSubview:accentBar];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = PPPetsCardOverlay(0.74);
    eyebrowPill.layer.cornerRadius = 13.0;
    eyebrowPill.layer.borderWidth = 1.0;
    [eyebrowPill pp_setBorderColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.10]];
    eyebrowPill.layer.masksToBounds = YES;
    [cardView addSubview:eyebrowPill];

    PPInsetLabel *eyebrowLabel = [[PPInsetLabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = NSTextAlignmentCenter;
    eyebrowLabel.textInsets = UIEdgeInsetsMake(2.0, 2.0, 2.0, 2.0);
    [eyebrowPill addSubview:eyebrowLabel];

    UIView *iconHalo = [[UIView alloc] init];
    iconHalo.translatesAutoresizingMaskIntoConstraints = NO;
    iconHalo.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.12];
    iconHalo.layer.cornerRadius = 32.0;
    iconHalo.layer.borderWidth = 1.0;
    [iconHalo pp_setBorderColor:PPPetsCardOverlay(0.48)];
    [iconHalo pp_setShadowColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.30]];
    iconHalo.layer.shadowOpacity = 0.12;
    iconHalo.layer.shadowRadius = 12.0;
    iconHalo.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [cardView addSubview:iconHalo];

    UIImageView *symbolView = [[UIImageView alloc] init];
    symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    symbolView.contentMode = UIViewContentModeScaleAspectFit;
    symbolView.tintColor = PPPetsUIBrandColor();
    symbolView.backgroundColor = PPPetsCardOverlay(0.66);
    symbolView.layer.cornerRadius = 26.0;
    symbolView.layer.masksToBounds = YES;
    [iconHalo addSubview:symbolView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    titleLabel.textColor = PPPetsUIPrimaryTextColor();
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 2;
    [cardView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = PPPetsUISecondaryTextColor();
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 2;
    [cardView addSubview:subtitleLabel];

    PPInsetLabel *metaLabel = [[PPInsetLabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    metaLabel.textColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.92];
    metaLabel.textAlignment = NSTextAlignmentCenter;
    metaLabel.numberOfLines = 2;
    metaLabel.backgroundColor = PPPetsCardOverlay(0.78);
    metaLabel.layer.cornerRadius = 17.0;
    metaLabel.layer.borderWidth = 1.0;
    [metaLabel pp_setBorderColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.10]];
    metaLabel.layer.masksToBounds = YES;
    metaLabel.textInsets = UIEdgeInsetsMake(6.0, 12.0, 6.0, 12.0);
    [cardView addSubview:metaLabel];

    UIButton *primaryButton = PPPetsBuildHeroButton(kLang(@"pet_reminder_add") ?: @"Add Reminder",
                                                    @"plus.circle.fill",
                                                    YES);
    [primaryButton addTarget:self action:@selector(pp_addReminder) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:primaryButton];

    UIButton *secondaryButton = PPPetsBuildHeroButton(kLang(@"pet_profiles_title") ?: @"Pet Profiles",
                                                      @"pawprint.circle.fill",
                                                      NO);
    [secondaryButton addTarget:self action:@selector(pp_openPets) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:secondaryButton];

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:10.0],
        [cardView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:20.0],
        [cardView.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-20.0],
        [cardView.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-14.0],

        [tintView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

        [ambientGlow.widthAnchor constraintEqualToConstant:188.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:188.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:-82.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:82.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:42.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:-34.0],

        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:14.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:56.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [eyebrowPill.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:10.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:12.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        [iconHalo.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [iconHalo.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:12.0],
        [iconHalo.widthAnchor constraintEqualToConstant:64.0],
        [iconHalo.heightAnchor constraintEqualToConstant:64.0],

        [symbolView.centerXAnchor constraintEqualToAnchor:iconHalo.centerXAnchor],
        [symbolView.centerYAnchor constraintEqualToAnchor:iconHalo.centerYAnchor],
        [symbolView.widthAnchor constraintEqualToConstant:52.0],
        [symbolView.heightAnchor constraintEqualToConstant:52.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconHalo.bottomAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:10.0],
        [metaLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:cardView.leadingAnchor constant:34.0],
        [metaLabel.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-34.0],

        [primaryButton.topAnchor constraintEqualToAnchor:metaLabel.bottomAnchor constant:14.0],
        [primaryButton.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [primaryButton.trailingAnchor constraintEqualToAnchor:cardView.centerXAnchor constant:-6.0],
        [primaryButton.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-16.0],

        [secondaryButton.topAnchor constraintEqualToAnchor:primaryButton.topAnchor],
        [secondaryButton.leadingAnchor constraintEqualToAnchor:cardView.centerXAnchor constant:6.0],
        [secondaryButton.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [secondaryButton.bottomAnchor constraintEqualToAnchor:primaryButton.bottomAnchor],
    ]];

    self.headerCardView = cardView;
    self.headerEyebrowLabel = eyebrowLabel;
    self.headerTitleLabel = titleLabel;
    self.headerSubtitleLabel = subtitleLabel;
    self.headerMetaLabel = metaLabel;
    self.headerSymbolView = symbolView;
    self.headerPrimaryButton = primaryButton;
    self.headerSecondaryButton = secondaryButton;

    self.tableView.tableHeaderView = self.headerRoot;
}

- (void)pp_refreshHeroHeaderContent {
    self.headerEyebrowLabel.text = kLang(@"pet_reminders_tab") ?: @"Pet Reminders";
    self.headerTitleLabel.text = kLang(@"pet_reminders_tab") ?: @"Pet Reminders";

    NSInteger activeCount = 0;
    NSInteger petCount = self.petMap.count;
    PPPetReminder *nextReminder = nil;
    for (PPPetReminder *reminder in self.reminders) {
        if (reminder.enabled) {
            activeCount += 1;
        }
        if (!nextReminder) {
            nextReminder = reminder;
            continue;
        }
        if (reminder.fireDate && (!nextReminder.fireDate || [reminder.fireDate compare:nextReminder.fireDate] == NSOrderedAscending)) {
            nextReminder = reminder;
        }
    }

    if (self.isLoading) {
        self.headerSubtitleLabel.text = kLang(@"please_wait") ?: @"Loading your reminder schedule…";
        self.headerMetaLabel.text = kLang(@"please_wait") ?: @"Loading…";
    } else if (nextReminder) {
        NSString *petName = self.petMap[nextReminder.petID].name ?: (kLang(@"pet_unknown") ?: @"Pet");
        NSString *dateText = nextReminder.fireDate ? [GM formattedDate:nextReminder.fireDate] : (kLang(@"pet_reminder_no_date") ?: @"No date set");
        self.headerSubtitleLabel.text = [NSString stringWithFormat:@"%@ · %@", petName, [nextReminder displayTypeText]];
        self.headerMetaLabel.text = [NSString stringWithFormat:@"%ld %@ · %@",
                                     (long)activeCount,
                                     (activeCount == 1 ? (kLang(@"pet_reminder_active_single") ?: @"active") : (kLang(@"pet_reminder_active_plural") ?: @"active")),
                                     dateText];
    } else {
        self.headerSubtitleLabel.text = kLang(@"pet_reminders_empty_subtitle") ?: @"Add reminders for vaccinations, food, and appointments so every routine stays on time.";
        self.headerMetaLabel.text = petCount > 0
            ? [NSString stringWithFormat:@"%ld %@", (long)petCount, (petCount == 1 ? (kLang(@"pet_profile_single") ?: @"pet profile") : (kLang(@"pet_profiles_title") ?: @"pet profiles"))]
            : (kLang(@"pet_profiles_empty_title") ?: @"No pet profiles yet");
    }

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28.0 weight:UIImageSymbolWeightMedium];
    NSString *symbolName = nextReminder.enabled ? @"bell.badge.fill" : @"bell.fill";
    self.headerSymbolView.image = [UIImage systemImageNamed:symbolName withConfiguration:config];
    self.headerSymbolView.contentMode = UIViewContentModeCenter;

    [self pp_updateHeaderLayout];
}

- (void)pp_updateHeaderLayout {
    if (!self.headerRoot) {
        return;
    }

    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) {
        headerWidth = CGRectGetWidth(self.view.bounds);
    }

    CGRect bounds = self.headerRoot.bounds;
    if (ABS(bounds.size.width - headerWidth) > 0.5) {
        bounds.size.width = headerWidth;
        self.headerRoot.bounds = bounds;
    }

    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];
    CGFloat headerHeight = [self.headerRoot systemLayoutSizeFittingSize:CGSizeMake(headerWidth, UILayoutFittingCompressedSize.height)
                                         withHorizontalFittingPriority:UILayoutPriorityRequired
                                               verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    CGRect frame = self.headerRoot.frame;
    frame.size.width = headerWidth;
    frame.size.height = headerHeight;
    self.headerRoot.frame = frame;
    self.tableView.tableHeaderView = self.headerRoot;
}

#pragma mark - Data

- (void)pp_reload {
    if (!self.tableView.refreshControl.isRefreshing && self.reminders.count == 0) {
        self.isLoading = YES;
        [self.tableView reloadData];
    }

    dispatch_group_t grp = dispatch_group_create();
    __block NSArray<PPPetReminder *> *loaded     = @[];
    __block NSArray<PPPetProfile *>  *loadedPets = @[];

    dispatch_group_enter(grp);
    [[UserManager sharedManager] fetchPetRemindersForCurrentUserWithCompletion:^(NSArray<PPPetReminder *> *r, NSError *e) {
        loaded = r ?: @[];
        dispatch_group_leave(grp);
    }];

    dispatch_group_enter(grp);
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> *p, NSError *e) {
        loadedPets = p ?: @[];
        dispatch_group_leave(grp);
    }];

    __weak typeof(self) ws = self;
    dispatch_group_notify(grp, dispatch_get_main_queue(), ^{
        [ws.tableView.refreshControl endRefreshing];
        ws.isLoading = NO;

        NSMutableDictionary *map = [NSMutableDictionary dictionary];
        for (PPPetProfile *p in loadedPets) {
            if (p.petID.length) map[p.petID] = p;
        }
        ws.petMap    = map.copy;
        ws.reminders = loaded;
        ws.hasAppearedOnce = NO;
        [ws pp_refreshHeroHeaderContent];
        [ws.tableView reloadData];
        [ws pp_updateEmptyState];
    });
}

- (void)pp_pullRefresh { [self pp_reload]; }

- (void)pp_updateEmptyState {
    // Empty state handled inline via table rows below hero
}

#pragma mark - Actions

- (void)pp_handleBack {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_addReminder {
    PPReminderEditorViewController *ed = [[PPReminderEditorViewController alloc] initWithReminder:nil];
    [self.navigationController pushViewController:ed animated:YES];
}

- (void)pp_openPets {
    PPPetProfilesViewController *vc = [PPPetProfilesViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)pp_deleteReminderAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= (NSInteger)self.reminders.count) return;
    PPPetReminder *rem = self.reminders[idx];

    __weak typeof(self) ws = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"pet_reminder_delete_title") ?: @"Delete Reminder"
                             subtitle:kLang(@"pet_reminder_delete_msg") ?: @"Are you sure you want to delete this reminder?"
                        confirmButton:kLang(@"Delete") ?: @"Delete"
                         cancelButton:kLang(@"Cancel") ?: @"Cancel"
                                 icon:[UIImage systemImageNamed:@"trash.circle.fill"]
                         confirmBlock:^(__unused NSString *t, __unused BOOL c) {
        [PPHUD showIndeterminateIn:ws.view title:(kLang(@"please_wait") ?: @"Deleting…") subtitle:nil];
        [[UserManager sharedManager] deletePetReminderWithID:rem.reminderID completion:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [PPHUD showError:(kLang(@"SomethingWentWrong") ?: @"Error") subtitle:error.localizedDescription];
                } else {
                    // Cancel pending local notification
                    [[PPReminderNotificationManager sharedManager] cancelNotificationForReminderID:rem.reminderID];
                    [PPHUD showSuccess:(kLang(@"Done") ?: @"Deleted") subtitle:nil];
                    [ws pp_reload];
                }
            });
        }];
    } cancelBlock:nil];
}

- (void)pp_toggleReminderAtIndex:(NSInteger)idx enabled:(BOOL)enabled {
    if (idx < 0 || idx >= (NSInteger)self.reminders.count) return;
    PPPetReminder *rem = self.reminders[idx];
    rem.enabled = enabled;

    __weak typeof(self) ws = self;
    [[UserManager sharedManager] savePetReminder:rem completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPHUD showError:(kLang(@"SomethingWentWrong") ?: @"Error") subtitle:error.localizedDescription];
                [ws pp_reload];
            } else {
                // Schedule or cancel notification based on toggle state
                [[PPReminderNotificationManager sharedManager] scheduleNotificationForReminder:rem];
            }
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isLoading) return 5;
    return self.reminders.count > 0 ? (NSInteger)self.reminders.count : 1; // 1 = empty-message row
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading) {
        return [tableView dequeueReusableCellWithIdentifier:kRemSkelID forIndexPath:indexPath];
    }

    // Empty-message row
    if (self.reminders.count == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kRemEmptyID forIndexPath:indexPath];
        cell.selectionStyle  = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;

        static NSInteger const kEmptyTag = 9921;
        UILabel *lbl = [cell.contentView viewWithTag:kEmptyTag];
        if (!lbl) {
            lbl = [[UILabel alloc] init];
            lbl.tag = kEmptyTag;
            lbl.translatesAutoresizingMaskIntoConstraints = NO;
            lbl.numberOfLines = 0;
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
            [cell.contentView addSubview:lbl];
            [NSLayoutConstraint activateConstraints:@[
                [lbl.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor      constant:32.0],
                [lbl.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor  constant:32.0],
                [lbl.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-32.0],
                [lbl.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor   constant:-32.0],
            ]];
        }
        lbl.textColor = PPPetsUISecondaryTextColor();
        lbl.text = kLang(@"pet_reminders_empty_subtitle") ?: @"No reminders yet.\nTap + to set your first reminder 🔔";
        return cell;
    }

    PPReminderCardCell *cell = [tableView dequeueReusableCellWithIdentifier:kRemCardID forIndexPath:indexPath];
    if (indexPath.row < (NSInteger)self.reminders.count) {
        PPPetReminder *rem = self.reminders[indexPath.row];
        PPPetProfile  *pet = self.petMap[rem.petID];
        [cell configureWithReminder:rem petName:pet.name];
        __weak typeof(self) ws = self;
        NSInteger i = indexPath.row;
        cell.onToggle = ^(BOOL on) { [ws pp_toggleReminderAtIndex:i enabled:on]; };
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading) return 93.0;
    if (self.reminders.count == 0) return UITableViewAutomaticDimension;
    return 96.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 96.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading || indexPath.row >= (NSInteger)self.reminders.count) return;
    PPReminderEditorViewController *ed = [[PPReminderEditorViewController alloc] initWithReminder:self.reminders[indexPath.row]];
    [self.navigationController pushViewController:ed animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (self.isLoading || self.reminders.count == 0) return nil;

    __weak typeof(self) ws = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                     title:kLang(@"Delete") ?: @"Delete"
                                                                   handler:^(__unused UIContextualAction *a, __unused UIView *sv, void (^ch)(BOOL)) {
        [ws pp_deleteReminderAtIndex:indexPath.row];
        ch(YES);
    }];
    del.image = [UIImage systemImageNamed:@"trash.fill"];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
    contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                       point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if (self.isLoading || indexPath.row >= (NSInteger)self.reminders.count) return nil;

    __weak typeof(self) ws = self;
    PPPetReminder *rem = self.reminders[indexPath.row];

    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *editAct = [UIAction actionWithTitle:kLang(@"Edit") ?: @"Edit"
                                                image:[UIImage systemImageNamed:@"pencil.circle"]
                                           identifier:nil handler:^(__unused UIAction *a) {
            PPReminderEditorViewController *ed = [[PPReminderEditorViewController alloc] initWithReminder:rem];
            [ws.navigationController pushViewController:ed animated:YES];
        }];
        NSString *togTitle = rem.enabled ? (kLang(@"pet_reminder_disable") ?: @"Disable")
                                         : (kLang(@"pet_reminder_enable")  ?: @"Enable");
        UIAction *togAct = [UIAction actionWithTitle:togTitle
                                               image:[UIImage systemImageNamed:rem.enabled ? @"bell.slash" : @"bell.badge"]
                                          identifier:nil handler:^(__unused UIAction *a) {
            [ws pp_toggleReminderAtIndex:indexPath.row enabled:!rem.enabled];
        }];
        UIAction *delAct = [UIAction actionWithTitle:kLang(@"Delete") ?: @"Delete"
                                               image:[UIImage systemImageNamed:@"trash.circle"]
                                          identifier:nil handler:^(__unused UIAction *a) {
            [ws pp_deleteReminderAtIndex:indexPath.row];
        }];
        delAct.attributes = UIMenuElementAttributesDestructive;
        return [UIMenu menuWithTitle:@"" children:@[editAct, togAct, delAct]];
    }];
}

#pragma mark - Entrance Animation

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading || self.hasAppearedOnce) return;
    __weak typeof(self) ws = self;

    cell.alpha     = 0;
    cell.transform = CGAffineTransformMakeTranslation(0, 30);

    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:indexPath.row * 0.06
         usingSpringWithDamping:PPAnimSpringDamping
          initialSpringVelocity:PPAnimSpringVelocity
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha     = 1;
        cell.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        if (indexPath.row >= (NSInteger)ss.reminders.count - 1) {
            ss.hasAppearedOnce = YES;
        }
    }];
}

#pragma mark - Dark Mode

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        PPPetsApplyCanvasBackground(self, self.tableView);
        PPPetsRefreshDynamicLayerColors(self.tableView);
    }
}

@end
