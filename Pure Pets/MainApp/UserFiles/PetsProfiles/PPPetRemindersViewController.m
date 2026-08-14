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

static UIFont * PPRemScaledFont(UIFont *font, UIFontTextStyle textStyle) {
    UIFont *baseFont = font ?: [UIFont preferredFontForTextStyle:textStyle];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:baseFont];
}

static BOOL PPRemUsesAccessibilityLayout(UITraitCollection *traits) {
    return UIContentSizeCategoryIsAccessibilityCategory(traits.preferredContentSizeCategory);
}

static UIColor * PPRemTypeColor(PPPetReminderType type) {
    switch (type) {
        case PPPetReminderTypeFood: return AppWarningClr;
        case PPPetReminderTypeAppointment: return AppPrimaryClr;
        case PPPetReminderTypeVaccination:
        default: return AppInfoClr;
    }
}

static NSString * PPRemTypeSymbolName(PPPetReminderType type) {
    switch (type) {
        case PPPetReminderTypeFood: return @"fork.knife";
        case PPPetReminderTypeAppointment: return @"calendar.badge.clock";
        case PPPetReminderTypeVaccination:
        default: return @"syringe.fill";
    }
}

static NSLayoutConstraint * PPRemPreferredCardWidth(UIView *card, UIView *container, CGFloat margin) {
    NSLayoutConstraint *constraint = [card.widthAnchor constraintEqualToAnchor:container.widthAnchor
                                                                      constant:-(margin * 2.0)];
    constraint.priority = 999;
    return constraint;
}

// ─── Skeleton Cell ────────────────────────────────────────

@interface PPReminderSkeletonCell : UITableViewCell
@property (nonatomic, strong) UIView *cardContainer;
- (void)configureAsAccessibilityStatus:(BOOL)isStatus;
@end

@implementation PPReminderSkeletonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;
    self.selectionStyle  = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.accessibilityElementsHidden = YES;

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(card, PPCornerCard);
    [self.contentView addSubview:card];
    self.cardContainer = card;

    UIView *icon = [self pp_sh:44 h:44 r:PPCorner16];
    UIView *l1   = [self pp_sh:152 h:15 r:7.5];
    UIView *l2   = [self pp_sh:112 h:12 r:6];
    [card addSubview:icon]; [card addSubview:l1]; [card addSubview:l2];

    NSLayoutConstraint *preferredWidth = PPRemPreferredCardWidth(card, self.contentView, PPScreenMargin);

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:PPSpaceXS],
        [card.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor   constant:-PPSpaceXS],
        [card.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [card.widthAnchor constraintLessThanOrEqualToConstant:680.0],
        preferredWidth,
        [card.heightAnchor constraintGreaterThanOrEqualToConstant:84.0],

        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceBase],
        [icon.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [icon.widthAnchor   constraintEqualToConstant:44],
        [icon.heightAnchor  constraintEqualToConstant:44],

        [l1.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:PPSpaceMD],
        [l1.topAnchor     constraintEqualToAnchor:icon.topAnchor constant:PPSpaceXXS],
        [l1.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
        [l2.leadingAnchor constraintEqualToAnchor:l1.leadingAnchor],
        [l2.topAnchor     constraintEqualToAnchor:l1.bottomAnchor constant:PPSpaceSM],
        [l2.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
    ]];
    return self;
}

- (void)configureAsAccessibilityStatus:(BOOL)isStatus {
    self.accessibilityElementsHidden = !isStatus;
    self.isAccessibilityElement = isStatus;
    self.accessibilityLabel = isStatus ? (kLang(@"please_wait") ?: @"Loading") : nil;
    self.accessibilityTraits = isStatus ? UIAccessibilityTraitUpdatesFrequently : UIAccessibilityTraitNone;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        PPPetsApplySurfaceStyle(self.cardContainer, PPCornerCard);
    }
}

- (UIView *)pp_sh:(CGFloat)w h:(CGFloat)h r:(CGFloat)r {
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = UIColor.tertiarySystemFillColor;
    PPApplyContinuousCorners(v, r);
    [v.widthAnchor  constraintEqualToConstant:w].active = YES;
    [v.heightAnchor constraintEqualToConstant:h].active = YES;
    return v;
}

@end

// ─── Reminder Card Cell ───────────────────────────────────

@interface PPReminderCardCell : UITableViewCell
@property (nonatomic, strong) UIView      *cardContainer;
@property (nonatomic, strong) UIView      *typeMarker;
@property (nonatomic, strong) UIView      *iconWell;
@property (nonatomic, strong) UIImageView *typeIcon;
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UILabel     *detailLabel;
@property (nonatomic, strong) UILabel     *dateLabel;
@property (nonatomic, strong) UIView      *repeatBadge;
@property (nonatomic, strong) UILabel     *repeatLabel;
@property (nonatomic, strong) UIStackView *metaStack;
@property (nonatomic, strong) UISwitch    *enableSwitch;
@property (nonatomic, strong) NSLayoutConstraint *titleToSwitchConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleToCardConstraint;
@property (nonatomic, strong) NSLayoutConstraint *detailToSwitchConstraint;
@property (nonatomic, strong) NSLayoutConstraint *detailToCardConstraint;
@property (nonatomic, strong) NSLayoutConstraint *switchCenterConstraint;
@property (nonatomic, strong) NSLayoutConstraint *metaBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *switchTopAccessibilityConstraint;
@property (nonatomic, strong) NSLayoutConstraint *switchBottomAccessibilityConstraint;
@property (nonatomic, copy)   void (^onToggle)(BOOL on);
@property (nonatomic, copy)   void (^onOpen)(void);
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

    _typeMarker = [UIView new];
    _typeMarker.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_typeMarker, 1.5);
    [_cardContainer addSubview:_typeMarker];

    _iconWell = [UIView new];
    _iconWell.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_iconWell, PPCorner16);
    [_cardContainer addSubview:_iconWell];

    _typeIcon = [UIImageView new];
    _typeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _typeIcon.contentMode = UIViewContentModeScaleAspectFit;
    [_iconWell addSubview:_typeIcon];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font          = PPRemScaledFont([GM boldFontWithSize:PPFontHeadline], UIFontTextStyleHeadline);
    _titleLabel.textColor     = AppPrimaryTextClr;
    _titleLabel.numberOfLines = 0;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    [_cardContainer addSubview:_titleLabel];

    _detailLabel = [UILabel new];
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.font      = PPRemScaledFont([GM MidFontWithSize:PPFontSubheadline], UIFontTextStyleSubheadline);
    _detailLabel.textColor = PPPetsUISecondaryTextColor();
    _detailLabel.numberOfLines = 0;
    _detailLabel.adjustsFontForContentSizeCategory = YES;
    [_cardContainer addSubview:_detailLabel];

    _dateLabel = [UILabel new];
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateLabel.font      = PPRemScaledFont([GM MidFontWithSize:PPFontFootnote], UIFontTextStyleFootnote);
    _dateLabel.textColor = AppPrimaryTextClr;
    _dateLabel.numberOfLines = 0;
    _dateLabel.adjustsFontForContentSizeCategory = YES;

    _repeatBadge = [UIView new];
    _repeatBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _repeatBadge.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(_repeatBadge, PPCornerSmall);
    _repeatBadge.layer.masksToBounds = YES;

    _repeatLabel = [UILabel new];
    _repeatLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _repeatLabel.font = PPRemScaledFont([GM MidFontWithSize:PPFontCaption1], UIFontTextStyleCaption1);
    _repeatLabel.textColor = PPPetsUIBrandColor();
    _repeatLabel.adjustsFontForContentSizeCategory = YES;
    _repeatLabel.numberOfLines = 0;
    [_repeatBadge addSubview:_repeatLabel];

    _metaStack = [[UIStackView alloc] initWithArrangedSubviews:@[_dateLabel, _repeatBadge]];
    _metaStack.translatesAutoresizingMaskIntoConstraints = NO;
    _metaStack.axis = UILayoutConstraintAxisHorizontal;
    _metaStack.alignment = UIStackViewAlignmentCenter;
    _metaStack.spacing = PPSpaceSM;
    [_cardContainer addSubview:_metaStack];

    _enableSwitch = [UISwitch new];
    _enableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _enableSwitch.onTintColor = PPPetsUIBrandColor();
    _enableSwitch.isAccessibilityElement = NO;
    [_enableSwitch addTarget:self action:@selector(pp_toggled) forControlEvents:UIControlEventValueChanged];
    [_cardContainer addSubview:_enableSwitch];

    NSLayoutConstraint *preferredWidth = PPRemPreferredCardWidth(_cardContainer, self.contentView, PPScreenMargin);
    self.titleToSwitchConstraint = [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_enableSwitch.leadingAnchor constant:-PPSpaceMD];
    self.titleToCardConstraint = [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceBase];
    self.detailToSwitchConstraint = [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_enableSwitch.leadingAnchor constant:-PPSpaceMD];
    self.detailToCardConstraint = [_detailLabel.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceBase];
    self.switchCenterConstraint = [_enableSwitch.centerYAnchor constraintEqualToAnchor:_iconWell.centerYAnchor];
    self.metaBottomConstraint = [_metaStack.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceBase];
    self.switchTopAccessibilityConstraint = [_enableSwitch.topAnchor constraintEqualToAnchor:_metaStack.bottomAnchor constant:PPSpaceMD];
    self.switchBottomAccessibilityConstraint = [_enableSwitch.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceBase];

    [NSLayoutConstraint activateConstraints:@[
        [_cardContainer.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:PPSpaceXS],
        [_cardContainer.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor   constant:-PPSpaceXS],
        [_cardContainer.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_cardContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [_cardContainer.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [_cardContainer.widthAnchor constraintLessThanOrEqualToConstant:680.0],
        preferredWidth,

        [_typeMarker.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor],
        [_typeMarker.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:PPSpaceBase],
        [_typeMarker.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceBase],
        [_typeMarker.widthAnchor constraintEqualToConstant:3.0],

        [_iconWell.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:PPSpaceBase],
        [_iconWell.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:PPSpaceBase],
        [_iconWell.widthAnchor constraintEqualToConstant:44.0],
        [_iconWell.heightAnchor constraintEqualToConstant:44.0],
        [_iconWell.bottomAnchor constraintLessThanOrEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceBase],

        [_typeIcon.centerXAnchor constraintEqualToAnchor:_iconWell.centerXAnchor],
        [_typeIcon.centerYAnchor constraintEqualToAnchor:_iconWell.centerYAnchor],
        [_typeIcon.widthAnchor   constraintEqualToConstant:20],
        [_typeIcon.heightAnchor  constraintEqualToConstant:20],

        [_enableSwitch.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceBase],

        [_titleLabel.topAnchor      constraintEqualToAnchor:_cardContainer.topAnchor constant:PPSpaceBase],
        [_titleLabel.leadingAnchor  constraintEqualToAnchor:_iconWell.trailingAnchor constant:PPSpaceMD],

        [_detailLabel.topAnchor     constraintEqualToAnchor:_titleLabel.bottomAnchor constant:PPSpaceXXS],
        [_detailLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],

        [_metaStack.topAnchor constraintEqualToAnchor:_detailLabel.bottomAnchor constant:PPSpaceSM],
        [_metaStack.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_metaStack.trailingAnchor constraintLessThanOrEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceBase],

        [_repeatLabel.topAnchor constraintEqualToAnchor:_repeatBadge.topAnchor constant:PPSpaceXS],
        [_repeatLabel.leadingAnchor constraintEqualToAnchor:_repeatBadge.leadingAnchor constant:PPSpaceSM],
        [_repeatLabel.trailingAnchor constraintEqualToAnchor:_repeatBadge.trailingAnchor constant:-PPSpaceSM],
        [_repeatLabel.bottomAnchor constraintEqualToAnchor:_repeatBadge.bottomAnchor constant:-PPSpaceXS],

        self.titleToSwitchConstraint,
        self.detailToSwitchConstraint,
        self.switchCenterConstraint,
        self.metaBottomConstraint,
    ]];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self pp_updateAdaptiveLayout];
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

    NSString *repeatText = PPRemRepeatDisplayText(rem.repeatRule);
    if (repeatText.length > 0) {
        self.repeatBadge.hidden = NO;
        self.repeatLabel.text = repeatText;
    } else {
        self.repeatBadge.hidden = YES;
    }

    UIColor *typeColor = PPRemTypeColor(rem.type);
    self.typeMarker.backgroundColor = typeColor;
    self.iconWell.backgroundColor = [typeColor colorWithAlphaComponent:0.12];
    self.typeIcon.tintColor = typeColor;
    self.typeIcon.image = [[UIImage systemImageNamed:PPRemTypeSymbolName(rem.type)] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.cardContainer.alpha = rem.enabled ? 1.0 : 0.62;

    self.cardContainer.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.titleLabel.textAlignment  = Language.alignmentForCurrentLanguage;
    self.detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.dateLabel.textAlignment   = Language.alignmentForCurrentLanguage;
    self.repeatLabel.textAlignment = Language.alignmentForCurrentLanguage;

    NSMutableArray<NSString *> *accessibilityParts = [NSMutableArray arrayWithArray:@[
        self.titleLabel.text ?: @"",
        self.detailLabel.text ?: @"",
        self.dateLabel.text ?: @""
    ]];
    if (repeatText.length) [accessibilityParts addObject:repeatText];
    self.accessibilityLabel = [accessibilityParts componentsJoinedByString:@", "];
    self.accessibilityValue = rem.enabled
        ? (kLang(@"pet_reminder_enabled") ?: @"Enabled")
        : (kLang(@"statusDisabled") ?: @"Disabled");
    [self pp_updateAccessibilityToggleAction];
}

- (void)pp_toggled {
    self.accessibilityValue = self.enableSwitch.isOn
        ? (kLang(@"pet_reminder_enabled") ?: @"Enabled")
        : (kLang(@"statusDisabled") ?: @"Disabled");
    [self pp_updateAccessibilityToggleAction];
    if (self.onToggle) self.onToggle(self.enableSwitch.isOn);
}

- (void)pp_updateAccessibilityToggleAction {
    NSString *toggleTitle = self.enableSwitch.isOn
        ? (kLang(@"pet_reminder_disable") ?: @"Disable")
        : (kLang(@"pet_reminder_enable") ?: @"Enable");
    self.accessibilityCustomActions = @[
        [[UIAccessibilityCustomAction alloc] initWithName:toggleTitle
                                                  target:self
                                                selector:@selector(pp_accessibilityToggle:)]
    ];
}

- (BOOL)pp_accessibilityToggle:(__unused UIAccessibilityCustomAction *)action {
    [self.enableSwitch setOn:!self.enableSwitch.isOn animated:NO];
    [self pp_toggled];
    return YES;
}

- (BOOL)accessibilityActivate {
    if (self.onOpen) self.onOpen();
    return self.onOpen != nil;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onToggle = nil;
    self.onOpen = nil;
    self.accessibilityCustomActions = nil;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self pp_updateAdaptiveLayout];
    }
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        PPPetsApplySurfaceStyle(self.cardContainer, PPCornerCard);
    }
}

- (void)pp_updateAdaptiveLayout {
    BOOL accessibilityLayout = PPRemUsesAccessibilityLayout(self.traitCollection);
    self.metaStack.axis = accessibilityLayout ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.metaStack.alignment = accessibilityLayout ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    self.titleToSwitchConstraint.active = !accessibilityLayout;
    self.switchCenterConstraint.active = !accessibilityLayout;
    self.metaBottomConstraint.active = !accessibilityLayout;
    self.titleToCardConstraint.active = accessibilityLayout;
    self.detailToSwitchConstraint.active = !accessibilityLayout;
    self.detailToCardConstraint.active = accessibilityLayout;
    self.switchTopAccessibilityConstraint.active = accessibilityLayout;
    self.switchBottomAccessibilityConstraint.active = accessibilityLayout;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    highlighted ? PPTapFeedbackDown(self.cardContainer) : PPTapFeedbackUp(self.cardContainer);
}

@end

// ─── Care Summary ──────────────────────────────────────────

@interface PPReminderMetricView : UIView
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong) UIView *iconWell;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, copy) void (^onAccessibilityActivate)(void);
- (instancetype)initWithSymbolName:(NSString *)symbolName accentColor:(UIColor *)accentColor;
- (void)configureWithValue:(NSString *)value caption:(NSString *)caption;
@end

@implementation PPReminderMetricView

- (instancetype)initWithSymbolName:(NSString *)symbolName accentColor:(UIColor *)accentColor {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentColor = accentColor ?: AppPrimaryClr;
    PPPetsApplySurfaceStyle(self, PPCornerMedium);

    _iconWell = [UIView new];
    _iconWell.translatesAutoresizingMaskIntoConstraints = NO;
    _iconWell.backgroundColor = [self.accentColor colorWithAlphaComponent:0.11];
    PPApplyContinuousCorners(_iconWell, PPCornerSmall);
    [self addSubview:_iconWell];

    _iconView = [UIImageView new];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.tintColor = self.accentColor;
    _iconView.image = [UIImage systemImageNamed:symbolName];
    _iconView.isAccessibilityElement = NO;
    [_iconWell addSubview:_iconView];

    _valueLabel = [UILabel new];
    _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _valueLabel.font = PPRemScaledFont([GM boldFontWithSize:PPFontTitle3], UIFontTextStyleTitle3);
    _valueLabel.textColor = AppPrimaryTextClr;
    _valueLabel.adjustsFontForContentSizeCategory = YES;
    _valueLabel.numberOfLines = 1;
    [self addSubview:_valueLabel];

    _captionLabel = [UILabel new];
    _captionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _captionLabel.font = PPRemScaledFont([GM MidFontWithSize:PPFontFootnote], UIFontTextStyleFootnote);
    _captionLabel.textColor = AppSecondaryTextClr;
    _captionLabel.adjustsFontForContentSizeCategory = YES;
    _captionLabel.numberOfLines = 0;
    [self addSubview:_captionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:72.0],

        [_iconWell.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPSpaceMD],
        [_iconWell.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_iconWell.widthAnchor constraintEqualToConstant:38.0],
        [_iconWell.heightAnchor constraintEqualToConstant:38.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconWell.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconWell.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:19.0],
        [_iconView.heightAnchor constraintEqualToConstant:19.0],

        [_valueLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPSpaceMD],
        [_valueLabel.leadingAnchor constraintEqualToAnchor:_iconWell.trailingAnchor constant:PPSpaceMD],
        [_valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceMD],

        [_captionLabel.topAnchor constraintEqualToAnchor:_valueLabel.bottomAnchor constant:PPSpaceXXS],
        [_captionLabel.leadingAnchor constraintEqualToAnchor:_valueLabel.leadingAnchor],
        [_captionLabel.trailingAnchor constraintEqualToAnchor:_valueLabel.trailingAnchor],
        [_captionLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPSpaceMD],
    ]];

    self.isAccessibilityElement = YES;
    _valueLabel.isAccessibilityElement = NO;
    _captionLabel.isAccessibilityElement = NO;
    return self;
}

- (void)configureWithValue:(NSString *)value caption:(NSString *)caption {
    self.valueLabel.text = value ?: @"0";
    self.captionLabel.text = caption ?: @"";
    self.valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.captionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", self.valueLabel.text, self.captionLabel.text];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        PPPetsApplySurfaceStyle(self, PPCornerMedium);
        self.iconWell.backgroundColor = [self.accentColor colorWithAlphaComponent:0.11];
    }
}

- (BOOL)accessibilityActivate {
    if (!self.onAccessibilityActivate) return NO;
    self.onAccessibilityActivate();
    return YES;
}

@end

// ─── Empty State ───────────────────────────────────────────

static UIButton * PPRemBuildActionButton(NSString *title, NSString *symbolName, BOOL primary) {
    UIButtonConfiguration *configuration = primary
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration tintedButtonConfiguration];
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = PPSpaceSM;
    configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceMD, PPSpaceBase, PPSpaceMD, PPSpaceBase);
    configuration.image = [UIImage systemImageNamed:symbolName
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                                   weight:UIImageSymbolWeightSemibold]];
    configuration.title = title ?: @"";
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(
        NSDictionary<NSAttributedStringKey, id> *incomingAttributes) {
        NSMutableDictionary<NSAttributedStringKey, id> *attributes = incomingAttributes.mutableCopy;
        attributes[NSFontAttributeName] = PPRemScaledFont([GM boldFontWithSize:PPFontSubheadline], UIFontTextStyleHeadline);
        return attributes.copy;
    };
    configuration.baseForegroundColor = primary ? UIColor.whiteColor : AppPrimaryClr;
    configuration.baseBackgroundColor = primary
        ? AppPrimaryClr
        : [AppPrimaryClr colorWithAlphaComponent:0.10];

    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:(primary ? PPButtonHeightLG : PPButtonHeightMD)].active = YES;
    return button;
}

@interface PPReminderEmptyCell : UITableViewCell
@property (nonatomic, strong) UIView *cardContainer;
@property (nonatomic, strong) UIImageView *stateIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *secondaryButton;
@property (nonatomic, copy) void (^onAdd)(void);
@property (nonatomic, copy) void (^onOpenPets)(void);
- (void)configureWithAddAction:(void (^)(void))addAction openPetsAction:(void (^)(void))openPetsAction;
- (void)configureForErrorWithRetryAction:(void (^)(void))retryAction;
@end

@implementation PPReminderEmptyCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _cardContainer = [UIView new];
    _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(_cardContainer, PPCornerHero - PPSpaceXS);
    [self.contentView addSubview:_cardContainer];

    UIView *iconWell = [UIView new];
    iconWell.translatesAutoresizingMaskIntoConstraints = NO;
    iconWell.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.11];
    PPApplyContinuousCorners(iconWell, PPCornerCard);
    [_cardContainer addSubview:iconWell];

    UIImageView *iconView = [UIImageView new];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = AppPrimaryClr;
    iconView.image = [UIImage systemImageNamed:@"bell.badge.fill"];
    iconView.isAccessibilityElement = NO;
    [iconWell addSubview:iconView];
    self.stateIconView = iconView;

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = PPRemScaledFont([GM boldFontWithSize:PPFontTitle2], UIFontTextStyleTitle2);
    _titleLabel.textColor = AppPrimaryTextClr;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.numberOfLines = 0;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [_cardContainer addSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = PPRemScaledFont([GM MidFontWithSize:PPFontBody], UIFontTextStyleBody);
    _subtitleLabel.textColor = AppSecondaryTextClr;
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.numberOfLines = 0;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [_cardContainer addSubview:_subtitleLabel];

    _primaryButton = PPRemBuildActionButton(kLang(@"pet_reminder_add"), @"plus.circle.fill", YES);
    [_primaryButton addTarget:self action:@selector(pp_addTapped) forControlEvents:UIControlEventTouchUpInside];

    _secondaryButton = PPRemBuildActionButton(kLang(@"pet_profiles_title"), @"pawprint.fill", NO);
    [_secondaryButton addTarget:self action:@selector(pp_petsTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *buttonStack = [[UIStackView alloc] initWithArrangedSubviews:@[_primaryButton, _secondaryButton]];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisVertical;
    buttonStack.spacing = PPSpaceSM;
    [_cardContainer addSubview:buttonStack];

    NSLayoutConstraint *preferredWidth = PPRemPreferredCardWidth(_cardContainer, self.contentView, PPScreenMargin);
    [NSLayoutConstraint activateConstraints:@[
        [_cardContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceMD],
        [_cardContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceMD],
        [_cardContainer.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_cardContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [_cardContainer.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [_cardContainer.widthAnchor constraintLessThanOrEqualToConstant:560.0],
        preferredWidth,

        [iconWell.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:PPSpaceXL],
        [iconWell.centerXAnchor constraintEqualToAnchor:_cardContainer.centerXAnchor],
        [iconWell.widthAnchor constraintEqualToConstant:68.0],
        [iconWell.heightAnchor constraintEqualToConstant:68.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconWell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconWell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:30.0],
        [iconView.heightAnchor constraintEqualToConstant:30.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:iconWell.bottomAnchor constant:PPSpaceBase],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:PPSpaceXL],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceXL],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:PPSpaceSM],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [buttonStack.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:PPSpaceXL],
        [buttonStack.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:PPSpaceXL],
        [buttonStack.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceXL],
        [buttonStack.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceXL],
    ]];
    return self;
}

- (void)configureWithAddAction:(void (^)(void))addAction openPetsAction:(void (^)(void))openPetsAction {
    self.onAdd = addAction;
    self.onOpenPets = openPetsAction;
    self.stateIconView.image = [UIImage systemImageNamed:@"bell.badge.fill"];
    self.titleLabel.text = kLang(@"pet_reminders_empty_title") ?: @"No Reminders";
    self.subtitleLabel.text = kLang(@"pet_reminders_empty_subtitle") ?: @"Add reminders for vaccinations, food, and appointments.";
    self.cardContainer.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.secondaryButton.hidden = NO;

    UIButtonConfiguration *primaryConfiguration = self.primaryButton.configuration;
    primaryConfiguration.title = kLang(@"pet_reminder_add") ?: @"Add Reminder";
    primaryConfiguration.image = [UIImage systemImageNamed:@"plus.circle.fill"];
    self.primaryButton.configuration = primaryConfiguration;
    self.primaryButton.accessibilityLabel = primaryConfiguration.title;

    UIButtonConfiguration *secondaryConfiguration = self.secondaryButton.configuration;
    secondaryConfiguration.title = kLang(@"pet_profiles_title") ?: @"Pet Profiles";
    self.secondaryButton.configuration = secondaryConfiguration;
    self.secondaryButton.accessibilityLabel = secondaryConfiguration.title;
}

- (void)configureForErrorWithRetryAction:(void (^)(void))retryAction {
    self.onAdd = retryAction;
    self.onOpenPets = nil;
    self.stateIconView.image = [UIImage systemImageNamed:@"exclamationmark.arrow.triangle.2.circlepath"];
    self.titleLabel.text = kLang(@"pet_reminders_error_title") ?: @"Couldn't Load Reminders";
    self.subtitleLabel.text = kLang(@"pet_reminders_error_subtitle") ?: @"Check your connection, then try again.";
    self.cardContainer.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.secondaryButton.hidden = YES;

    UIButtonConfiguration *configuration = self.primaryButton.configuration;
    configuration.title = kLang(@"empty_retry_button") ?: @"Refresh";
    configuration.image = [UIImage systemImageNamed:@"arrow.clockwise"];
    self.primaryButton.configuration = configuration;
    self.primaryButton.accessibilityLabel = configuration.title;
}

- (void)pp_addTapped { if (self.onAdd) self.onAdd(); }
- (void)pp_petsTapped { if (self.onOpenPets) self.onOpenPets(); }

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onAdd = nil;
    self.onOpenPets = nil;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        PPPetsApplySurfaceStyle(self.cardContainer, PPCornerHero - PPSpaceXS);
    }
}

@end

// ─── View Controller ──────────────────────────────────────

@interface PPPetRemindersViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPPetReminder *> *reminders;
@property (nonatomic, strong) NSDictionary<NSString *, PPPetProfile *> *petMap;
@property (nonatomic, strong) NSError *loadError;
@property (nonatomic, strong) NSError *profileLoadError;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL profileRequestInFlight;
@property (nonatomic, assign) BOOL hasAppearedOnce;
@property (nonatomic, assign) NSUInteger reloadGeneration;
@property (nonatomic, strong) UIView *summaryRoot;
@property (nonatomic, strong) UIStackView *summaryStack;
@property (nonatomic, strong) PPReminderMetricView *activeMetricView;
@property (nonatomic, strong) PPReminderMetricView *petMetricView;
@property (nonatomic, strong) UITapGestureRecognizer *petMetricRetryRecognizer;
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
    self.tableView.rowHeight        = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 124.0;
    self.tableView.contentInset     = UIEdgeInsetsMake(PPSpaceXS, 0.0, PPSpaceXL, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.alwaysBounceVertical = YES;
    self.tableView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    
    [self.tableView registerClass:PPReminderCardCell.class     forCellReuseIdentifier:kRemCardID];
    [self.tableView registerClass:PPReminderSkeletonCell.class forCellReuseIdentifier:kRemSkelID];
    [self.tableView registerClass:PPReminderEmptyCell.class    forCellReuseIdentifier:kRemEmptyID];
    [self.view addSubview:self.tableView];

    [self pp_buildSummaryHeader];
    [self pp_applyCanvasBackground];
    [self pp_refreshSummaryHeaderContent];

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
    [self pp_refreshSummaryHeaderContent];
    [self pp_reload];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_applyCanvasBackground];
    [self pp_updateSummaryHeaderLayout];
}

#pragma mark - Appearance

- (void)pp_applyCanvasBackground {
    PPPetsApplyCanvasBackground(self, self.tableView);
}

- (void)pp_buildSummaryHeader {
    UIView *root = [UIView new];
    root.backgroundColor = UIColor.clearColor;

    PPReminderMetricView *activeMetric = [[PPReminderMetricView alloc] initWithSymbolName:@"bell.fill"
                                                                              accentColor:AppPrimaryClr];
    PPReminderMetricView *petMetric = [[PPReminderMetricView alloc] initWithSymbolName:@"pawprint.fill"
                                                                           accentColor:AppSecondaryTextClr];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[activeMetric, petMetric]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = PPSpaceSM;
    [root addSubview:stack];

    NSLayoutConstraint *preferredWidth = PPRemPreferredCardWidth(stack, root, PPScreenMargin);
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:root.topAnchor constant:PPSpaceSM],
        [stack.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-PPSpaceSM],
        [stack.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.leadingAnchor constant:PPScreenMargin],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:root.trailingAnchor constant:-PPScreenMargin],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:680.0],
        preferredWidth,
    ]];

    self.summaryRoot = root;
    self.summaryStack = stack;
    self.activeMetricView = activeMetric;
    self.petMetricView = petMetric;
    UITapGestureRecognizer *retryRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                      action:@selector(pp_retryProfileLoad)];
    retryRecognizer.enabled = NO;
    [petMetric addGestureRecognizer:retryRecognizer];
    self.petMetricRetryRecognizer = retryRecognizer;
    [self pp_updateSummaryAxis];
    self.tableView.tableHeaderView = root;
}

- (void)pp_refreshSummaryHeaderContent {
    if (!self.summaryRoot) return;

    BOOL hidesSummary = (self.isLoading && self.reminders.count == 0) || self.loadError != nil;
    self.summaryRoot.hidden = hidesSummary;
    if (hidesSummary) {
        if (self.tableView.tableHeaderView == self.summaryRoot) self.tableView.tableHeaderView = nil;
        return;
    }

    NSInteger activeCount = 0;
    for (PPPetReminder *reminder in self.reminders) {
        if (reminder.enabled) activeCount += 1;
    }

    NSString *activeCaption = activeCount == 1
        ? (kLang(@"pet_reminder_active_single") ?: @"active")
        : (kLang(@"pet_reminder_active_plural") ?: @"active");
    [self.activeMetricView configureWithValue:[NSString stringWithFormat:@"%ld", (long)activeCount]
                                       caption:activeCaption];

    if (self.profileRequestInFlight && self.petMap.count == 0) {
        self.petMetricView.iconView.image = [UIImage systemImageNamed:@"arrow.clockwise"];
        [self.petMetricView configureWithValue:@"-"
                                        caption:(kLang(@"please_wait") ?: @"Loading")];
        self.petMetricRetryRecognizer.enabled = NO;
        self.petMetricView.onAccessibilityActivate = nil;
        self.petMetricView.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
        self.petMetricView.accessibilityHint = nil;
    } else if (self.profileLoadError) {
        NSString *errorCaption = [NSString stringWithFormat:@"%@ · %@",
                                  (kLang(@"pet_profiles_error_title") ?: @"Pet Profiles Unavailable"),
                                  (kLang(@"empty_retry_button") ?: @"Refresh")];
        self.petMetricView.iconView.image = [UIImage systemImageNamed:@"arrow.clockwise"];
        [self.petMetricView configureWithValue:@"-"
                                        caption:errorCaption];
        self.petMetricRetryRecognizer.enabled = YES;
        __weak typeof(self) ws = self;
        self.petMetricView.onAccessibilityActivate = ^{ [ws pp_retryProfileLoad]; };
        self.petMetricView.accessibilityTraits = UIAccessibilityTraitButton;
        self.petMetricView.accessibilityHint = kLang(@"empty_retry_button") ?: @"Refresh";
    } else {
        self.petMetricView.iconView.image = [UIImage systemImageNamed:@"pawprint.fill"];
        NSInteger petCount = self.petMap.count;
        NSString *petCaption = petCount == 1
            ? (kLang(@"pet_profile_single") ?: @"profile")
            : (kLang(@"pet_profiles_title") ?: @"Pet Profiles");
        [self.petMetricView configureWithValue:[NSString stringWithFormat:@"%ld", (long)petCount]
                                        caption:petCaption];
        self.petMetricRetryRecognizer.enabled = NO;
        self.petMetricView.onAccessibilityActivate = nil;
        self.petMetricView.accessibilityTraits = self.profileRequestInFlight
            ? UIAccessibilityTraitUpdatesFrequently
            : UIAccessibilityTraitNone;
        self.petMetricView.accessibilityHint = self.profileRequestInFlight
            ? (kLang(@"please_wait") ?: @"Loading")
            : nil;
    }
    if (self.tableView.tableHeaderView != self.summaryRoot) self.tableView.tableHeaderView = self.summaryRoot;
    [self pp_updateSummaryHeaderLayout];
}

- (void)pp_retryProfileLoad {
    if (self.profileLoadError) [self pp_reload];
}

- (void)pp_updateSummaryAxis {
    BOOL accessibilityLayout = PPRemUsesAccessibilityLayout(self.traitCollection);
    self.summaryStack.axis = accessibilityLayout ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
}

- (void)pp_updateSummaryHeaderLayout {
    if (!self.summaryRoot || self.summaryRoot.hidden) return;

    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) headerWidth = CGRectGetWidth(self.view.bounds);

    [self pp_updateSummaryAxis];
    CGRect bounds = self.summaryRoot.bounds;
    bounds.size.width = headerWidth;
    self.summaryRoot.bounds = bounds;
    CGFloat headerHeight = [self.summaryRoot systemLayoutSizeFittingSize:CGSizeMake(headerWidth, UILayoutFittingCompressedSize.height)
                                   withHorizontalFittingPriority:UILayoutPriorityRequired
                                         verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;

    CGRect frame = self.summaryRoot.frame;
    if (ABS(frame.size.width - headerWidth) <= 0.5 && ABS(frame.size.height - headerHeight) <= 0.5) {
        if (self.tableView.tableHeaderView != self.summaryRoot) self.tableView.tableHeaderView = self.summaryRoot;
        return;
    }
    frame.size.width = headerWidth;
    frame.size.height = headerHeight;
    self.summaryRoot.frame = frame;
    self.tableView.tableHeaderView = self.summaryRoot;
}

#pragma mark - Data

- (void)pp_reload {
    NSUInteger generation = ++self.reloadGeneration;
    self.loadError = nil;
    self.profileLoadError = nil;
    self.profileRequestInFlight = YES;
    if (!self.tableView.refreshControl.isRefreshing && self.reminders.count == 0) {
        self.isLoading = YES;
        [self.tableView reloadData];
    }
    [self pp_refreshSummaryHeaderContent];

    dispatch_group_t grp = dispatch_group_create();
    __block NSArray<PPPetReminder *> *loaded     = @[];
    __block NSArray<PPPetProfile *>  *loadedPets = @[];
    __block NSError *reminderError = nil;
    __block NSError *petError = nil;

    dispatch_group_enter(grp);
    [[UserManager sharedManager] fetchPetRemindersForCurrentUserWithCompletion:^(NSArray<PPPetReminder *> *r, NSError *e) {
        loaded = r ?: @[];
        reminderError = e;
        dispatch_group_leave(grp);
    }];

    dispatch_group_enter(grp);
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> *p, NSError *e) {
        loadedPets = p ?: @[];
        petError = e;
        dispatch_group_leave(grp);
    }];

    __weak typeof(self) ws = self;
    dispatch_group_notify(grp, dispatch_get_main_queue(), ^{
        if (!ws || ws.reloadGeneration != generation) return;
        [ws.tableView.refreshControl endRefreshing];
        ws.isLoading = NO;
        ws.profileRequestInFlight = NO;
        ws.profileLoadError = petError;

        if (!petError) {
            NSMutableDictionary *map = [NSMutableDictionary dictionary];
            for (PPPetProfile *p in loadedPets) {
                if (p.petID.length) map[p.petID] = p;
            }
            ws.petMap = map.copy;
        }

        if (reminderError) {
            if (ws.reminders.count == 0) {
                ws.loadError = reminderError;
            } else {
                [PPHUD showError:(kLang(@"SomethingWentWrong") ?: @"Error") subtitle:reminderError.localizedDescription];
            }
        } else {
            ws.reminders = loaded;
        }
        [ws pp_refreshSummaryHeaderContent];
        [ws.tableView reloadData];
        [ws pp_updateEmptyState];
    });
}

- (void)pp_pullRefresh { [self pp_reload]; }

- (void)pp_updateEmptyState {
    // Empty state is represented by the table's dedicated action cell.
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

- (void)pp_openReminder:(PPPetReminder *)reminder {
    if (!reminder) return;
    PPReminderEditorViewController *editor = [[PPReminderEditorViewController alloc] initWithReminder:reminder];
    [self.navigationController pushViewController:editor animated:YES];
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
                [ws pp_refreshSummaryHeaderContent];
                if (idx < (NSInteger)ws.reminders.count) {
                    [ws.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]]
                                        withRowAnimation:UITableViewRowAnimationNone];
                }
            }
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isLoading) return 5;
    return self.reminders.count > 0 ? (NSInteger)self.reminders.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading) {
        PPReminderSkeletonCell *cell = [tableView dequeueReusableCellWithIdentifier:kRemSkelID forIndexPath:indexPath];
        [cell configureAsAccessibilityStatus:indexPath.row == 0];
        return cell;
    }

    if (self.reminders.count == 0) {
        PPReminderEmptyCell *cell = [tableView dequeueReusableCellWithIdentifier:kRemEmptyID forIndexPath:indexPath];
        __weak typeof(self) ws = self;
        if (self.loadError) {
            [cell configureForErrorWithRetryAction:^{ [ws pp_reload]; }];
        } else {
            [cell configureWithAddAction:^{ [ws pp_addReminder]; }
                        openPetsAction:^{ [ws pp_openPets]; }];
        }
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
        cell.onOpen = ^{ [ws pp_openReminder:rem]; };
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading) return 92.0;
    if (self.reminders.count == 0) return 340.0;
    return 124.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading || indexPath.row >= (NSInteger)self.reminders.count) return;
    [self pp_openReminder:self.reminders[indexPath.row]];
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
            [ws pp_openReminder:rem];
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
    NSInteger lastRow = MAX((NSInteger)self.reminders.count - 1, 0);
    if (UIAccessibilityIsReduceMotionEnabled()) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        if (indexPath.row >= lastRow) self.hasAppearedOnce = YES;
        return;
    }
    __weak typeof(self) ws = self;

    cell.alpha     = 0;
    cell.transform = CGAffineTransformMakeTranslation(0, 8.0);

    [UIView animateWithDuration:0.18
                          delay:MIN(indexPath.row, 6) * 0.025
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha     = 1;
        cell.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        if (indexPath.row >= lastRow) {
            ss.hasAppearedOnce = YES;
        }
    }];
}

#pragma mark - Dark Mode

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self pp_updateSummaryAxis];
        [self pp_updateSummaryHeaderLayout];
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        PPPetsApplyCanvasBackground(self, self.tableView);
    }
}

@end
