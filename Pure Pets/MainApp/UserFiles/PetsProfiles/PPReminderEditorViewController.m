//
//  PPReminderEditorViewController.m
//  Pure Pets
//
//  Native care-note editor. This controller remains the sole draft, navigation,
//  persistence and local-notification owner; the private views only render it.
//

#import "PPReminderEditorViewController.h"
#import "PPPetReminder.h"
#import "PPPetProfile.h"
#import "PPPetProfileEditorViewController.h"
#import "PPReminderNotificationManager.h"
#import "UserManager.h"
#import "Language.h"
#import "GM.h"
#import <Pure_Pets-Swift.h>
@import UserNotifications;

static BOOL PPRemEdMatchesOwner(NSString *ownerUID) {
    return ownerUID.length > 0 && [ownerUID isEqualToString:[UserManager sharedManager].currentAuthUser.uid];
}

// Stored values are a compatibility contract with the existing scheduler.
static NSArray<NSString *> *PPRemEdRepeatRules(void) {
    return @[@"", @"daily", @"weekly", @"monthly", @"yearly"];
}

static NSString *PPRemEdRepeatLabel(NSString *rule) {
    NSArray *rules = PPRemEdRepeatRules();
    NSArray *keys = @[@"pet_reminder_repeat_none", @"pet_reminder_repeat_daily",
                      @"pet_reminder_repeat_weekly", @"pet_reminder_repeat_monthly",
                      @"pet_reminder_repeat_yearly"];
    NSUInteger index = [rules indexOfObject:rule ?: @""];
    return kLang(keys[index == NSNotFound ? 0 : index]);
}

static UIFont *PPRemEdFont(CGFloat size, UIFontTextStyle style, BOOL bold) {
    UIFont *base = bold ? [GM boldFontWithSize:size] : [GM fontWithSize:size];
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:
            base ?: [UIFont systemFontOfSize:size weight:bold ? UIFontWeightSemibold : UIFontWeightRegular]];
}

static UILabel *PPRemEdLabel(NSString *text, CGFloat size, UIFontTextStyle style, BOOL bold, UIColor *color) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = PPRemEdFont(size, style, bold);
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    label.textColor = color;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    return label;
}

static UIStackView *PPRemEdStack(NSArray<UIView *> *views, CGFloat spacing) {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = spacing;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    return stack;
}

static UIView *PPRemEdSurface(UIView *content, CGFloat inset) {
    UIView *surface = [UIView new];
    surface.backgroundColor = UIColor.ppSurface;
    surface.layer.cornerRadius = 24.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [surface addSubview:content];
    // UIStackView collapses hidden surfaces to zero height. Let this one edge
    // yield while their controls retain their intrinsic and minimum heights.
    NSLayoutConstraint *bottom = [content.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-inset];
    bottom.priority = UILayoutPriorityRequired - 1;
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:surface.topAnchor constant:inset],
        bottom,
        [content.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:inset],
        [content.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-inset]
    ]];
    return surface;
}

static UIView *PPRemEdDivider(void) {
    UIView *divider = [UIView new];
    divider.backgroundColor = UIColor.separatorColor;
    [divider.heightAnchor constraintEqualToConstant:0.5].active = YES;
    divider.isAccessibilityElement = NO;
    return divider;
}

#pragma mark - Self-sizing title

@interface PPRemEdTitleView : UITextView
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, assign) CGFloat measuredWidth;
@end

@implementation PPRemEdTitleView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)container {
    self = [super initWithFrame:frame textContainer:container];
    if (!self) return nil;
    self.scrollEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.textContainerInset = UIEdgeInsetsMake(4, 0, 4, 0);
    self.textContainer.lineFragmentPadding = 0;
    self.font = PPRemEdFont(30, UIFontTextStyleTitle1, YES);
    self.adjustsFontForContentSizeCategory = YES;
    self.textColor = UIColor.ppTextPrimary;
    self.tintColor = UIColor.ppAccentText;
    self.textAlignment = Language.alignmentForCurrentLanguage;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.autocorrectionType = UITextAutocorrectionTypeDefault;
    self.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.returnKeyType = UIReturnKeyDone;
    self.placeholderLabel = PPRemEdLabel(kLang(@"reminder_editor_title_prompt"), 30, UIFontTextStyleTitle1, YES, UIColor.ppTextSecondary);
    self.placeholderLabel.isAccessibilityElement = NO;
    self.placeholderLabel.userInteractionEnabled = NO;
    [self addSubview:self.placeholderLabel];
    self.accessibilityLabel = kLang(@"pet_reminder_title");
    self.accessibilityHint = kLang(@"pet_reminder_title_required_msg");
    self.accessibilityIdentifier = @"reminderEditor.title";
    return self;
}

- (CGSize)intrinsicContentSize {
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0) return CGSizeMake(UIViewNoIntrinsicMetric, 60);
    CGFloat textHeight = [self sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
    CGFloat hintHeight = [self.placeholderLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height + 8;
    return CGSizeMake(UIViewNoIntrinsicMetric, MAX(60, self.text.length ? textHeight : hintHeight));
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    self.placeholderLabel.frame = CGRectMake(0, 4, width,
        [self.placeholderLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    self.placeholderLabel.hidden = self.text.length > 0;
    if (fabs(width - self.measuredWidth) > 0.5) {
        self.measuredWidth = width;
        [self invalidateIntrinsicContentSize];
    }
}
@end

#pragma mark - Native action row

@interface PPRemEdActionRow : UIControl
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIImageView *symbolView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIActivityIndicatorView *activity;
- (void)configureTitle:(NSString *)title value:(NSString *)value hint:(NSString *)hint symbol:(NSString *)symbol loading:(BOOL)loading;
@end

@implementation PPRemEdActionRow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel = PPRemEdLabel(@"", 12, UIFontTextStyleCaption1, YES, UIColor.ppTextSecondary);
    self.valueLabel = PPRemEdLabel(@"", 18, UIFontTextStyleHeadline, YES, UIColor.ppTextPrimary);
    self.hintLabel = PPRemEdLabel(@"", 13, UIFontTextStyleFootnote, NO, UIColor.ppTextSecondary);
    self.symbolView = [[UIImageView alloc] init];
    self.symbolView.contentMode = UIViewContentModeScaleAspectFit;
    self.symbolView.tintColor = UIColor.ppAccentText;
    self.chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"]];
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronView.tintColor = UIColor.ppTextSecondary;
    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activity.hidesWhenStopped = YES;
    UIView *symbolContainer = [UIView new];
    for (UIView *view in @[self.symbolView, self.activity]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [symbolContainer addSubview:view];
        [NSLayoutConstraint activateConstraints:@[
            [view.centerXAnchor constraintEqualToAnchor:symbolContainer.centerXAnchor],
            [view.centerYAnchor constraintEqualToAnchor:symbolContainer.centerYAnchor],
            [view.widthAnchor constraintEqualToConstant:24], [view.heightAnchor constraintEqualToConstant:24]
        ]];
    }
    [symbolContainer.widthAnchor constraintEqualToConstant:28].active = YES;
    [symbolContainer.heightAnchor constraintEqualToConstant:28].active = YES;
    UIStackView *copy = PPRemEdStack(@[self.titleLabel, self.valueLabel, self.hintLabel], 4);
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[symbolContainer, copy, self.chevronView]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    row.userInteractionEnabled = NO;
    row.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:row];
    NSLayoutConstraint *chevronWidth = [self.chevronView.widthAnchor constraintEqualToConstant:12];
    chevronWidth.priority = UILayoutPriorityRequired - 1;
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16],
        [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        chevronWidth,
        [self.chevronView.heightAnchor constraintEqualToConstant:16],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:72]
    ]];
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    return self;
}

- (void)configureTitle:(NSString *)title value:(NSString *)value hint:(NSString *)hint symbol:(NSString *)symbol loading:(BOOL)loading {
    self.titleLabel.text = title;
    self.valueLabel.text = value;
    self.hintLabel.text = hint;
    self.hintLabel.hidden = hint.length == 0;
    self.symbolView.image = [UIImage systemImageNamed:symbol];
    self.symbolView.hidden = loading;
    self.chevronView.hidden = loading;
    if (loading) [self.activity startAnimating]; else [self.activity stopAnimating];
    self.accessibilityLabel = title;
    self.accessibilityValue = value;
    self.accessibilityHint = hint;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.72 : 1.0;
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.accessibilityTraits = UIAccessibilityTraitButton | (enabled ? 0 : UIAccessibilityTraitNotEnabled);
}
@end

#pragma mark - Coordinator

@interface PPReminderEditorViewController () <UITextViewDelegate>
@property (nonatomic, strong) PPPetReminder *reminder;
@property (nonatomic, strong) PPPetReminder *originalReminder;
@property (nonatomic, copy) NSString *ownerUID;
@property (nonatomic, assign) BOOL isNewReminder;
@property (nonatomic, strong) NSArray<PPPetProfile *> *pets;
@property (nonatomic, assign) BOOL isLoadingPets;
@property (nonatomic, assign) BOOL petsLoaded;
@property (nonatomic, assign) BOOL petsLoadFailed;
@property (nonatomic, assign) BOOL reloadPetsOnReturn;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL saveSucceeded;
@property (nonatomic, assign) BOOL notificationsDenied;
@property (nonatomic, assign) BOOL needsNotificationPermission;
@property (nonatomic, assign) NSUInteger petRequestID;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) PPRemEdTitleView *titleField;
@property (nonatomic, strong) UIStackView *typeStack;
@property (nonatomic, strong) NSArray<UIButton *> *typeButtons;
@property (nonatomic, strong) PPRemEdActionRow *petRow;
@property (nonatomic, strong) PPRemEdActionRow *repeatRow;
@property (nonatomic, strong) PPRemEdActionRow *permissionRow;
@property (nonatomic, strong) UIView *permissionSurface;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UIDatePicker *timePicker;
@property (nonatomic, strong) NSArray<UIStackView *> *dateRows;
@property (nonatomic, strong) UIStackView *enabledRow;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UILabel *validationLabel;
@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation PPReminderEditorViewController

#pragma mark - Init

- (instancetype)initWithReminder:(PPPetReminder *)reminder {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _originalReminder = reminder;
    _ownerUID = [[UserManager sharedManager].currentAuthUser.uid copy];
    _isNewReminder = reminder == nil;
    _reminder = reminder ? [[PPPetReminder alloc] initWithDictionary:reminder.toDictionary] : [PPPetReminder new];
    _reminder.fireDate = reminder.fireDate;
    _reminder.createdAt = reminder.createdAt;
    _reminder.updatedAt = reminder.updatedAt;
    // Give a new reminder a usable future time; never silently change an edited date.
    if (!_reminder.fireDate) _reminder.fireDate = [NSDate dateWithTimeIntervalSinceNow:3600];
    _pets = @[];
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.ppBackground;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.title = kLang(self.isNewReminder ? @"pet_reminder_add" : @"pet_reminder_edit");
    [self pp_buildNavigation];
    [self pp_buildEditor];
    [self pp_refreshPresentation];
    [self pp_loadPets];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_refreshNotificationPermission)
                                                name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.reloadPetsOnReturn) {
        self.reloadPetsOnReturn = NO;
        [self pp_loadPets];
    }
    [self pp_refreshNotificationPermission];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_applyAdaptiveLayout];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Composition

- (void)pp_buildNavigation {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"chevron.backward"] style:UIBarButtonItemStylePlain
        target:self action:@selector(pp_handleBack)];
    self.navigationItem.leftBarButtonItem.accessibilityLabel = kLang(@"Back");
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.accessibilityIdentifier = @"reminderEditor.save";
    [self.saveButton addTarget:self action:@selector(pp_save) forControlEvents:UIControlEventTouchUpInside];
    [self.saveButton.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [self.saveButton.widthAnchor constraintGreaterThanOrEqualToConstant:72].active = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.saveButton];
}

- (UILabel *)pp_heading:(NSString *)key {
    UILabel *label = PPRemEdLabel(kLang(key), 21, UIFontTextStyleTitle2, YES, UIColor.ppTextPrimary);
    label.accessibilityTraits |= UIAccessibilityTraitHeader;
    return label;
}

- (void)pp_buildEditor {
    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor]
    ]];

    self.titleField = [[PPRemEdTitleView alloc] initWithFrame:CGRectZero textContainer:nil];
    self.titleField.delegate = self;
    self.titleField.text = self.reminder.title;
    UIToolbar *keyboardToolbar = [UIToolbar new];
    keyboardToolbar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        [[UIBarButtonItem alloc] initWithTitle:kLang(@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(pp_endEditing)]];
    [keyboardToolbar sizeToFit];
    keyboardToolbar.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleField.inputAccessoryView = keyboardToolbar;
    UILabel *titleLabel = PPRemEdLabel(kLang(@"reminder_editor_title_label"), 12, UIFontTextStyleCaption1, YES, UIColor.ppTextSecondary);
    titleLabel.isAccessibilityElement = NO;
    UIStackView *identity = PPRemEdStack(@[titleLabel, self.titleField], 4);

    [self pp_buildTypeButtons];
    self.petRow = [[PPRemEdActionRow alloc] initWithFrame:CGRectZero];
    self.petRow.accessibilityIdentifier = @"reminderEditor.pet";
    [self.petRow addTarget:self action:@selector(pp_showPetPicker) forControlEvents:UIControlEventTouchUpInside];

    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar_QA" : @"en_QA"];
    self.datePicker = [UIDatePicker new];
    self.timePicker = [UIDatePicker new];
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    self.timePicker.datePickerMode = UIDatePickerModeTime;
    NSMutableArray<UIStackView *> *dateRows = [NSMutableArray array];
    NSArray *pickers = @[self.datePicker, self.timePicker];
    NSArray *labelKeys = @[@"reminder_editor_date", @"reminder_editor_time"];
    for (NSUInteger i = 0; i < pickers.count; i++) {
        UIDatePicker *picker = pickers[i];
        picker.preferredDatePickerStyle = UIDatePickerStyleCompact;
        picker.locale = locale;
        picker.date = self.reminder.fireDate;
        picker.tintColor = UIColor.ppAccentText;
        picker.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        picker.accessibilityLabel = kLang(labelKeys[i]);
        picker.accessibilityIdentifier = i == 0 ? @"reminderEditor.date" : @"reminderEditor.time";
        [picker setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [picker.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        [picker addTarget:self action:@selector(pp_dateChanged:) forControlEvents:UIControlEventValueChanged];
        UILabel *label = PPRemEdLabel(kLang(labelKeys[i]), 16, UIFontTextStyleBody, NO, UIColor.ppTextPrimary);
        label.isAccessibilityElement = NO;
        UIStackView *row = PPRemEdStack(@[label, picker], 8);
        [dateRows addObject:row];
    }
    self.dateRows = dateRows;
    // A historical value can still be inspected. Saving an enabled past date asks
    // the owner to choose a future time, matching the scheduler's existing guard.
    self.repeatRow = [[PPRemEdActionRow alloc] initWithFrame:CGRectZero];
    self.repeatRow.accessibilityIdentifier = @"reminderEditor.repeat";
    [self.repeatRow addTarget:self action:@selector(pp_showRepeatPicker) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *calendarRows = PPRemEdStack(@[dateRows[0], PPRemEdDivider(), dateRows[1]], 12);
    UIView *calendarContent = PPRemEdSurface(calendarRows, 16);
    calendarContent.layer.cornerRadius = 0;
    UIStackView *scheduleRows = PPRemEdStack(@[calendarContent, PPRemEdDivider(), self.repeatRow], 0);
    UIView *scheduleSurface = PPRemEdSurface(scheduleRows, 0);
    scheduleSurface.clipsToBounds = YES;
    UIStackView *schedule = PPRemEdStack(@[[self pp_heading:@"reminder_editor_schedule"], scheduleSurface], 12);

    self.enableSwitch = [UISwitch new];
    self.enableSwitch.on = self.reminder.enabled;
    self.enableSwitch.onTintColor = UIColor.ppPrimary;
    self.enableSwitch.accessibilityLabel = kLang(@"reminder_editor_enabled");
    self.enableSwitch.accessibilityIdentifier = @"reminderEditor.enabled";
    [self.enableSwitch addTarget:self action:@selector(pp_enabledChanged:) forControlEvents:UIControlEventValueChanged];
    UILabel *enabledLabel = PPRemEdLabel(kLang(@"reminder_editor_enabled"), 18, UIFontTextStyleHeadline, YES, UIColor.ppTextPrimary);
    UILabel *enabledHint = PPRemEdLabel(kLang(@"reminder_editor_enabled_hint"), 13, UIFontTextStyleFootnote, NO, UIColor.ppTextSecondary);
    UIStackView *enabledCopy = PPRemEdStack(@[enabledLabel, enabledHint], 4);
    self.enabledRow = PPRemEdStack(@[enabledCopy, self.enableSwitch], 16);
    [self.enableSwitch setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.enableSwitch setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.permissionRow = [[PPRemEdActionRow alloc] initWithFrame:CGRectZero];
    [self.permissionRow configureTitle:kLang(@"reminder_editor_notifications_title")
                                 value:kLang(@"reminder_editor_notifications_action")
                                  hint:kLang(@"reminder_editor_notifications_hint") symbol:@"bell.slash" loading:NO];
    [self.permissionRow addTarget:self action:@selector(pp_openNotificationSettings) forControlEvents:UIControlEventTouchUpInside];
    self.permissionSurface = PPRemEdSurface(self.permissionRow, 0);
    self.permissionSurface.hidden = YES;
    self.validationLabel = PPRemEdLabel(@"", 14, UIFontTextStyleFootnote, NO, UIColor.ppError);
    self.validationLabel.hidden = YES;

    self.contentStack = PPRemEdStack(@[identity, self.validationLabel, self.typeStack, PPRemEdSurface(self.petRow, 0),
                                      schedule, self.enabledRow, self.permissionSurface], 24);
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStack];
    NSLayoutConstraint *preferredWidth = [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:20],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-32],
        [self.contentStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20],
        [self.contentStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20],
        [self.contentStack.centerXAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.centerXAnchor],
        [self.contentStack.widthAnchor constraintLessThanOrEqualToConstant:600], preferredWidth,
        [self.scrollView.contentLayoutGuide.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor]
    ]];
}

- (void)pp_buildTypeButtons {
    NSMutableArray *buttons = [NSMutableArray array];
    for (NSInteger type = PPPetReminderTypeVaccination; type <= PPPetReminderTypeAppointment; type++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = type;
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.accessibilityIdentifier = [NSString stringWithFormat:@"reminderEditor.type.%ld", (long)type];
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:76].active = YES;
        [button addTarget:self action:@selector(pp_typeChanged:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:button];
    }
    self.typeButtons = buttons;
    self.typeStack = PPRemEdStack(buttons, 8);
    self.typeStack.distribution = UIStackViewDistributionFillEqually;
}

- (void)pp_applyAdaptiveLayout {
    BOOL accessibility = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    self.typeStack.axis = accessibility ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.enabledRow.axis = accessibility ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.enabledRow.alignment = accessibility ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    BOOL stackDates = accessibility || CGRectGetWidth(self.view.bounds) < 390;
    for (UIStackView *row in self.dateRows) {
        row.axis = stackDates ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
        row.alignment = stackDates ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    }
}

#pragma mark - State rendering

- (PPPetProfile *)pp_selectedPet {
    for (PPPetProfile *pet in self.pets) {
        if ([pet.petID isEqualToString:self.reminder.petID]) return pet;
    }
    return nil;
}

- (void)pp_refreshPresentation {
    BOOL busy = self.isSaving || self.saveSucceeded;
    NSArray *keys = @[@"pet_reminder_vaccination", @"pet_reminder_food", @"pet_reminder_appointment"];
    NSArray *symbols = @[@"syringe", @"fork.knife", @"calendar"];
    BOOL accessibility = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    for (UIButton *button in self.typeButtons) {
        BOOL selected = button.tag == self.reminder.type;
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(keys[button.tag])
            attributes:@{NSFontAttributeName:PPRemEdFont(15, UIFontTextStyleSubheadline, selected)}];
        config.image = [UIImage systemImageNamed:symbols[button.tag]];
        config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        config.imagePlacement = accessibility ? NSDirectionalRectEdgeLeading : NSDirectionalRectEdgeTop;
        config.imagePadding = 8;
        config.contentInsets = NSDirectionalEdgeInsetsMake(14, 8, 14, 8);
        config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        config.titleLineBreakMode = NSLineBreakByWordWrapping;
        config.baseForegroundColor = selected ? UIColor.whiteColor : UIColor.ppTextPrimary;
        config.background.backgroundColor = selected ? UIColor.ppPrimary : UIColor.ppSurface;
        config.background.cornerRadius = 20;
        button.configuration = config;
        button.titleLabel.numberOfLines = 0;
        button.selected = selected;
        button.enabled = !busy;
        button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
    }
    NSString *petValue;
    NSString *petHint = @"";
    NSString *petSymbol = @"pawprint.fill";
    if (self.isLoadingPets) {
        petValue = kLang(@"reminder_editor_pets_loading");
    } else if (self.petsLoadFailed) {
        petValue = kLang(@"reminder_editor_pets_error");
        petHint = kLang(@"reminder_editor_pets_retry");
        petSymbol = @"arrow.clockwise";
    } else if (self.petsLoaded && self.pets.count == 0) {
        petValue = kLang(@"reminder_editor_add_pet");
        petHint = kLang(@"reminder_editor_add_pet_hint");
        petSymbol = @"plus";
    } else {
        PPPetProfile *pet = [self pp_selectedPet];
        petValue = pet ? (pet.name.length ? pet.name : kLang(@"pet_unknown")) : kLang(@"pet_reminder_select_pet");
        if (!pet && self.reminder.petID.length) petHint = kLang(@"reminder_editor_pet_unavailable");
    }
    [self.petRow configureTitle:kLang(@"pet_reminder_pet_section") value:petValue hint:petHint symbol:petSymbol loading:self.isLoadingPets];
    self.petRow.enabled = !self.isLoadingPets && !busy;
    [self.repeatRow configureTitle:kLang(@"pet_reminder_repeat_label") value:PPRemEdRepeatLabel(self.reminder.repeatRule)
                             hint:@"" symbol:@"repeat" loading:NO];
    self.repeatRow.enabled = !busy;
    self.titleField.editable = !busy;
    self.datePicker.enabled = !busy;
    self.timePicker.enabled = !busy;
    self.enableSwitch.enabled = !busy;
    self.permissionRow.enabled = !busy;
    [self.permissionRow configureTitle:kLang(self.needsNotificationPermission ? @"reminder_editor_notifications_setup" : @"reminder_editor_notifications_title")
                                 value:kLang(self.needsNotificationPermission ? @"reminder_editor_notifications_enable" : @"reminder_editor_notifications_action")
                                  hint:kLang(@"reminder_editor_notifications_hint") symbol:@"bell.slash" loading:NO];
    self.permissionSurface.hidden = !self.notificationsDenied || !self.reminder.enabled;
    self.navigationItem.leftBarButtonItem.enabled = !busy;
    BOOL hasTitle = [self.reminder.title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
    BOOL canSave = hasTitle && [self pp_selectedPet] != nil && self.petsLoaded && !self.isLoadingPets && !self.petsLoadFailed && !busy;
    self.saveButton.enabled = canSave;
    UIButtonConfiguration *save = [UIButtonConfiguration filledButtonConfiguration];
    save.title = kLang(self.isSaving ? @"please_wait" : self.saveSucceeded ? @"Done" : @"Save");
    save.showsActivityIndicator = self.isSaving;
    save.baseBackgroundColor = canSave ? UIColor.ppPrimary : UIColor.ppSurface;
    save.baseForegroundColor = canSave ? UIColor.whiteColor : UIColor.ppTextSecondary;
    save.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    save.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);
    self.saveButton.configuration = save;
    self.saveButton.accessibilityHint = kLang(@"reminder_editor_save_hint");
}

#pragma mark - Pets and recovery

- (void)pp_loadPets {
    if (self.isLoadingPets) return;
    if (!PPRemEdMatchesOwner(self.ownerUID)) { [self pp_rejectChangedOwner]; return; }
    self.isLoadingPets = YES;
    self.petsLoadFailed = NO;
    NSUInteger requestID = ++self.petRequestID;
    [self pp_refreshPresentation];
    __weak typeof(self) weakSelf = self;
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> *pets, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || requestID != self.petRequestID) return;
            if (!PPRemEdMatchesOwner(self.ownerUID)) { [self pp_rejectChangedOwner]; return; }
            self.isLoadingPets = NO;
            self.petsLoadFailed = error != nil;
            if (!error) {
                self.pets = pets ?: @[];
                self.petsLoaded = YES;
                // Preserve a missing existing association until the owner chooses.
                if (self.isNewReminder && self.reminder.petID.length == 0 && self.pets.count) {
                    self.reminder.petID = self.pets.firstObject.petID;
                }
            }
            [self pp_refreshPresentation];
        });
    }];
}

- (void)pp_presentSheet:(UIAlertController *)sheet fromRow:(UIView *)row {
    [self.view endEditing:YES];
    sheet.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = row;
        sheet.popoverPresentationController.sourceRect = row.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_showPetPicker {
    if (self.isLoadingPets || self.isSaving || self.saveSucceeded) return;
    if (self.petsLoadFailed) { [self pp_loadPets]; return; }
    if (!self.pets.count) {
        [self.view endEditing:YES];
        self.reloadPetsOnReturn = YES;
        PPPetProfileEditorViewController *editor = [[PPPetProfileEditorViewController alloc] initWithPet:nil];
        if (self.navigationController) {
            [self.navigationController pushViewController:editor animated:YES];
        } else {
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:editor];
            navigation.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:navigation animated:YES completion:nil];
        }
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"pet_reminder_select_pet") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (PPPetProfile *pet in self.pets) {
        NSString *petID = pet.petID;
        [sheet addAction:[UIAlertAction actionWithTitle:pet.name.length ? pet.name : kLang(@"pet_unknown")
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                weakSelf.reminder.petID = petID;
                weakSelf.validationLabel.hidden = YES;
                [weakSelf pp_refreshPresentation];
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self pp_presentSheet:sheet fromRow:self.petRow];
}

- (void)pp_showRepeatPicker {
    if (self.isSaving || self.saveSucceeded) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"pet_reminder_repeat_label") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSString *rule in PPRemEdRepeatRules()) {
        [sheet addAction:[UIAlertAction actionWithTitle:PPRemEdRepeatLabel(rule) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            weakSelf.reminder.repeatRule = rule;
            [weakSelf pp_refreshPresentation];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self pp_presentSheet:sheet fromRow:self.repeatRow];
}

#pragma mark - Input

- (void)textViewDidChange:(UITextView *)textView {
    self.reminder.title = textView.text ?: @"";
    self.titleField.placeholderLabel.hidden = textView.text.length > 0;
    [textView invalidateIntrinsicContentSize];
    self.validationLabel.hidden = YES;
    [self pp_refreshPresentation];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) { [textView resignFirstResponder]; return NO; }
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect rect = [textView convertRect:textView.bounds toView:self.scrollView];
        [self.scrollView scrollRectToVisible:rect animated:!UIAccessibilityIsReduceMotionEnabled()];
    });
}

- (void)pp_endEditing { [self.view endEditing:YES]; }

- (void)pp_typeChanged:(UIButton *)sender {
    if (self.isSaving || self.saveSucceeded) return;
    self.reminder.type = sender.tag;
    [self pp_refreshPresentation];
}

- (void)pp_dateChanged:(UIDatePicker *)sender {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateComponents *day = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:self.datePicker.date];
    NSDateComponents *time = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:self.timePicker.date];
    day.hour = time.hour;
    day.minute = time.minute;
    day.second = 0;
    NSDate *date = [calendar dateFromComponents:day];
    if (!date) return;
    self.reminder.fireDate = date;
    // Keep both native controls on the same absolute draft date.
    self.datePicker.date = date;
    self.timePicker.date = date;
    self.validationLabel.hidden = YES;
}

- (void)pp_enabledChanged:(UISwitch *)sender {
    self.reminder.enabled = sender.isOn;
    self.validationLabel.hidden = YES;
    [self pp_refreshPresentation];
}

#pragma mark - Notification settings

- (void)pp_refreshNotificationPermission {
    __weak typeof(self) weakSelf = self;
    [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.needsNotificationPermission = settings.authorizationStatus == UNAuthorizationStatusNotDetermined;
            weakSelf.notificationsDenied = settings.authorizationStatus == UNAuthorizationStatusDenied ||
                settings.authorizationStatus == UNAuthorizationStatusNotDetermined;
            [weakSelf pp_refreshPresentation];
        });
    }];
}

- (void)pp_openNotificationSettings {
    if (self.needsNotificationPermission) {
        __weak typeof(self) weakSelf = self;
        [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:
            (UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
            completionHandler:^(BOOL granted, NSError *error) {
                [weakSelf pp_refreshNotificationPermission];
            }];
        return;
    }
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

#pragma mark - Persistence

- (void)pp_handleBack {
    if (self.isSaving) return;
    [self.view endEditing:YES];
    if (self.navigationController.viewControllers.count > 1) [self.navigationController popViewControllerAnimated:YES];
    else [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_showValidation:(NSString *)message {
    self.validationLabel.text = message;
    self.validationLabel.hidden = NO;
    [self.view layoutIfNeeded];
    CGRect rect = [self.validationLabel convertRect:self.validationLabel.bounds toView:self.scrollView];
    [self.scrollView scrollRectToVisible:rect animated:!UIAccessibilityIsReduceMotionEnabled()];
    if (self.view.window) UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

- (void)pp_rejectChangedOwner {
    self.isSaving = NO;
    self.isLoadingPets = NO;
    self.petsLoaded = NO;
    self.petsLoadFailed = YES;
    self.pets = @[];
    [self pp_refreshPresentation];
    NSString *message = kLang(self.ownerUID.length ? @"pet_editor_session_changed_message" : @"login_required_message");
    [self pp_showValidation:message];
    if (self.view.window) {
        [PPHUD showError:kLang(self.ownerUID.length ? @"pet_editor_session_changed_title" : @"login_required_title") subtitle:message];
    }
}

- (void)pp_save {
    if (self.isSaving || self.saveSucceeded || self.isLoadingPets || self.petsLoadFailed) return;
    if (!PPRemEdMatchesOwner(self.ownerUID)) { [self pp_rejectChangedOwner]; return; }
    [self.view endEditing:YES];
    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!title.length) {
        [self pp_showValidation:kLang(@"pet_reminder_title_required_msg")];
        [self.titleField becomeFirstResponder];
        return;
    }
    if (![self pp_selectedPet]) {
        [self pp_showValidation:kLang(@"pet_reminder_pet_required_msg")];
        return;
    }
    if (self.reminder.enabled && [self.reminder.fireDate compare:NSDate.date] != NSOrderedDescending) {
        [self pp_showValidation:kLang(@"reminder_editor_future_date")];
        return;
    }
    self.reminder.title = title;
    self.isSaving = YES;
    self.validationLabel.hidden = YES;
    [self pp_refreshPresentation];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"please_wait") subtitle:nil];
    // Keep the save snapshot alive even if UIKit dismisses the screen during I/O.
    PPPetReminder *savedReminder = self.reminder;
    PPPetReminder *originalReminder = self.originalReminder;
    NSString *ownerUID = self.ownerUID;
    __weak typeof(self) weakSelf = self;
    [[UserManager sharedManager] savePetReminder:savedReminder completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            self.isSaving = NO;
            // Never schedule an old account's alert in a new account's session.
            if (!PPRemEdMatchesOwner(ownerUID)) { [self pp_rejectChangedOwner]; return; }
            if (error) {
                [self pp_refreshPresentation];
                if (self.view.window) {
                    [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:error.localizedDescription];
                    [self pp_showValidation:kLang(@"reminder_editor_save_error")];
                }
                return;
            }
            originalReminder.reminderID = savedReminder.reminderID;
            originalReminder.petID = savedReminder.petID;
            originalReminder.title = savedReminder.title;
            originalReminder.type = savedReminder.type;
            originalReminder.fireDate = savedReminder.fireDate;
            originalReminder.repeatRule = savedReminder.repeatRule;
            originalReminder.enabled = savedReminder.enabled;
            originalReminder.createdAt = savedReminder.createdAt;
            originalReminder.updatedAt = savedReminder.updatedAt;
            [[PPReminderNotificationManager sharedManager] scheduleNotificationForReminder:savedReminder];
            self.saveSucceeded = YES;
            [self pp_refreshPresentation];
            if (!self.view.window) return;
            [PPHUD showSuccess:kLang(@"Done") subtitle:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.navigationController.topViewController == self || (!self.navigationController && self.presentingViewController)) {
                    [self pp_handleBack];
                }
            });
        });
    }];
}

#pragma mark - Appearance and accessibility

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (!self.isViewLoaded) return;
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory] ||
        [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self.titleField invalidateIntrinsicContentSize];
        [self pp_applyAdaptiveLayout];
        [self pp_refreshPresentation];
    }
}

@end
