//
//  PPVaccinationEditorSheet.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//  Modern bottom-sheet editor for vaccination records —
//  name, date, notes, next-due alert, all in a clean form.
//

#import "PPVaccinationEditorSheet.h"
#import "PPPetProfile.h"
#import "PPPetProfilesUIStyle.h"
#import "Language.h"
#import "GM.h"

// ─── Constants ────────────────────────────────────────────

static const CGFloat kSheetHPad   = 24.0;
static const CGFloat kFieldHeight = 50.0;
static const CGFloat kCorner      = 16.0;

// ─── Styled Text Field ───────────────────────────────────

@interface PPVaccSheetField : UITextField
@end

@implementation PPVaccSheetField

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.font            = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    self.textColor       = PPPetsUIPrimaryTextColor();
    self.backgroundColor = PPPetsUISurfaceColor();
    self.layer.cornerRadius = kCorner;
    self.layer.borderWidth  = 1.0;
    self.layer.borderColor  = PPPetsUISurfaceBorderColor().CGColor;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.returnKeyType = UIReturnKeyDone;
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    self.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.textAlignment = Language.alignmentForCurrentLanguage;
    return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 16.0, 0.0);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 16.0, 0.0);
}

@end

// ─── Date Row (label + date picker inline) ────────────────

@interface PPVaccDateRow : UIView
@property (nonatomic, strong) UILabel      *titleLabel;
@property (nonatomic, strong) UIDatePicker *picker;
@property (nonatomic, strong) UISwitch     *toggle;
@property (nonatomic, assign) BOOL          dateEnabled;
@end

@implementation PPVaccDateRow

- (instancetype)initWithTitle:(NSString *)title defaultDate:(NSDate * _Nullable)date showToggle:(BOOL)showToggle {
    self = [super init];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = PPPetsUISurfaceColor();
    self.layer.cornerRadius = kCorner;
    self.layer.borderWidth  = 1.0;
    self.layer.borderColor  = PPPetsUISurfaceBorderColor().CGColor;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.semanticContentAttribute = PPPetsCurrentSemanticAttribute();

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font      = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _titleLabel.textColor = PPPetsUISecondaryTextColor();
    _titleLabel.text      = title;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self addSubview:_titleLabel];

    _picker = [[UIDatePicker alloc] init];
    _picker.translatesAutoresizingMaskIntoConstraints = NO;
    _picker.datePickerMode  = UIDatePickerModeDate;
    _picker.tintColor       = PPPetsUIBrandColor();
    if (@available(iOS 13.4, *)) {
        _picker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    _picker.date = date ?: [NSDate date];
    _picker.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self addSubview:_picker];

    if (showToggle) {
        _toggle = [[UISwitch alloc] init];
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        _toggle.onTintColor = PPPetsUIBrandColor();
        _toggle.on = (date != nil);
        [_toggle addTarget:self action:@selector(pp_toggleChanged) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_toggle];

        _dateEnabled = (date != nil);
        _picker.alpha   = _dateEnabled ? 1.0 : 0.35;
        _picker.enabled = _dateEnabled;

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [_toggle.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:8.0],
            [_toggle.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [_picker.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
            [_picker.centerYAnchor  constraintEqualToAnchor:self.centerYAnchor],
            [_picker.leadingAnchor  constraintGreaterThanOrEqualToAnchor:_toggle.trailingAnchor constant:8.0],

            [self.heightAnchor constraintGreaterThanOrEqualToConstant:kFieldHeight],
        ]];
    } else {
        _dateEnabled = YES;

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [_picker.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
            [_picker.centerYAnchor  constraintEqualToAnchor:self.centerYAnchor],
            [_picker.leadingAnchor  constraintGreaterThanOrEqualToAnchor:_titleLabel.trailingAnchor constant:8.0],

            [self.heightAnchor constraintGreaterThanOrEqualToConstant:kFieldHeight],
        ]];
    }

    return self;
}

- (void)pp_toggleChanged {
    _dateEnabled = _toggle.isOn;
    [UIView animateWithDuration:0.25 animations:^{
        self.picker.alpha   = self.dateEnabled ? 1.0 : 0.35;
        self.picker.enabled = self.dateEnabled;
    }];
}

- (NSDate * _Nullable)selectedDate {
    return _dateEnabled ? _picker.date : nil;
}

@end

// ─── View Controller ──────────────────────────────────────

@interface PPVaccinationEditorSheet () <UITextFieldDelegate>
@property (nonatomic, strong) PPPetVaccinationRecord *record;
@property (nonatomic, assign) BOOL isNewRecord;
@property (nonatomic, copy)   PPVaccinationEditorCompletion completion;

@property (nonatomic, strong) UIScrollView   *scrollView;
@property (nonatomic, strong) UIStackView    *stack;
@property (nonatomic, strong) PPVaccSheetField *nameField;
@property (nonatomic, strong) PPVaccSheetField *notesField;
@property (nonatomic, strong) PPVaccDateRow    *appliedDateRow;
@property (nonatomic, strong) PPVaccDateRow    *nextDueDateRow;
@property (nonatomic, strong) UIButton         *saveButton;
@property (nonatomic, strong) UIButton         *cancelButton;
@end

@implementation PPVaccinationEditorSheet

#pragma mark - Init

- (instancetype)initForNewRecordWithCompletion:(PPVaccinationEditorCompletion)completion {
    self = [super init];
    if (self) {
        _record      = [PPPetVaccinationRecord new];
        _isNewRecord = YES;
        _completion  = [completion copy];
    }
    return self;
}

- (instancetype)initWithRecord:(PPPetVaccinationRecord *)record
                    completion:(PPVaccinationEditorCompletion)completion {
    self = [super init];
    if (self) {
        _record      = record;
        _isNewRecord = NO;
        _completion  = [completion copy];
    }
    return self;
}

+ (void)presentFromViewController:(UIViewController *)parent
                       withRecord:(PPPetVaccinationRecord *)record
                       completion:(PPVaccinationEditorCompletion)completion {
    PPVaccinationEditorSheet *sheet;
    if (record) {
        sheet = [[PPVaccinationEditorSheet alloc] initWithRecord:record completion:completion];
    } else {
        sheet = [[PPVaccinationEditorSheet alloc] initForNewRecordWithCompletion:completion];
    }
    sheet.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *spc = sheet.sheetPresentationController;
        spc.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent
        ];
        spc.prefersGrabberVisible        = YES;
        spc.prefersScrollingExpandsWhenScrolledToEdge = NO;
        spc.preferredCornerRadius        = 28.0;
    }
    [parent presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPPetsUICanvasColor();
    self.view.semanticContentAttribute = PPPetsCurrentSemanticAttribute();

    [self pp_buildUI];
    [self pp_populateFields];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.isNewRecord) {
        [self.nameField becomeFirstResponder];
    }
}

#pragma mark - Build UI

- (void)pp_buildUI {
    // ── Grabber accent bar ──
    UIView *grabberAccent = [[UIView alloc] init];
    grabberAccent.translatesAutoresizingMaskIntoConstraints = NO;
    grabberAccent.backgroundColor = PPPetsUIBrandColor();
    grabberAccent.layer.cornerRadius = 2.0;
    [self.view addSubview:grabberAccent];

    // ── Title label ──
    UILabel *sheetTitle = [UILabel new];
    sheetTitle.translatesAutoresizingMaskIntoConstraints = NO;
    sheetTitle.font      = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    sheetTitle.textColor = PPPetsUIPrimaryTextColor();
    sheetTitle.textAlignment = Language.alignmentForCurrentLanguage;
    sheetTitle.text = self.isNewRecord
        ? (kLang(@"pet_vaccine_add") ?: @"Add Vaccination")
        : (kLang(@"pet_vaccine_edit") ?: @"Edit Vaccination");
    [self.view addSubview:sheetTitle];

    // ── Subtitle ──
    UILabel *sheetSubtitle = [UILabel new];
    sheetSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    sheetSubtitle.font      = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    sheetSubtitle.textColor = PPPetsUISecondaryTextColor();
    sheetSubtitle.textAlignment = Language.alignmentForCurrentLanguage;
    sheetSubtitle.numberOfLines = 2;
    sheetSubtitle.text = self.isNewRecord
        ? (kLang(@"pet_vaccine_add_subtitle") ?: @"Record a vaccination with date, notes, and optional next-due reminder.")
        : (kLang(@"pet_vaccine_edit_subtitle") ?: @"Update vaccine details and set a reminder for the next dose.");
    [self.view addSubview:sheetSubtitle];

    // ── Scroll + Stack ──
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];

    self.stack = [[UIStackView alloc] init];
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    self.stack.axis      = UILayoutConstraintAxisVertical;
    self.stack.spacing   = 14.0;
    self.stack.alignment = UIStackViewAlignmentFill;
    [self.scrollView addSubview:self.stack];

    // ── Form Fields ──

    // 1. Name
    UILabel *nameLabel = [self pp_sectionLabel:(kLang(@"pet_vaccine_name") ?: @"Vaccine Name")];
    [self.stack addArrangedSubview:nameLabel];

    self.nameField = [PPVaccSheetField new];
    self.nameField.placeholder = kLang(@"pet_vaccine_name_prompt") ?: @"e.g. Rabies, FVRCP, DHPP…";
    self.nameField.delegate = self;
    [self.stack addArrangedSubview:self.nameField];
    [self.nameField.heightAnchor constraintEqualToConstant:kFieldHeight].active = YES;

    // 2. Applied date
    UILabel *dateLabel = [self pp_sectionLabel:(kLang(@"pet_vaccine_date") ?: @"Vaccination Date")];
    [self.stack addArrangedSubview:dateLabel];

    self.appliedDateRow = [[PPVaccDateRow alloc] initWithTitle:(kLang(@"pet_vaccine_applied") ?: @"Given on")
                                                  defaultDate:self.record.appliedAt
                                                   showToggle:NO];
    [self.stack addArrangedSubview:self.appliedDateRow];

    // 3. Notes
    UILabel *notesLabel = [self pp_sectionLabel:(kLang(@"pet_vaccine_notes_label") ?: @"Notes")];
    [self.stack addArrangedSubview:notesLabel];

    self.notesField = [PPVaccSheetField new];
    self.notesField.placeholder = kLang(@"pet_vaccine_notes_placeholder") ?: @"Optional notes about this vaccine…";
    self.notesField.delegate = self;
    [self.stack addArrangedSubview:self.notesField];
    [self.notesField.heightAnchor constraintEqualToConstant:kFieldHeight].active = YES;

    // 4. Next due date (with toggle)
    UILabel *nextLabel = [self pp_sectionLabel:(kLang(@"pet_vaccine_next_due") ?: @"Next Due Date")];
    [self.stack addArrangedSubview:nextLabel];

    self.nextDueDateRow = [[PPVaccDateRow alloc] initWithTitle:(kLang(@"pet_vaccine_remind") ?: @"Remind me")
                                                   defaultDate:self.record.nextDueDate
                                                    showToggle:YES];
    [self.stack addArrangedSubview:self.nextDueDateRow];

    // 5. Buttons
    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer.heightAnchor constraintEqualToConstant:8.0].active = YES;
    [self.stack addArrangedSubview:spacer];

    UIStackView *btnRow = [[UIStackView alloc] init];
    btnRow.translatesAutoresizingMaskIntoConstraints = NO;
    btnRow.axis         = UILayoutConstraintAxisHorizontal;
    btnRow.spacing      = 12.0;
    btnRow.distribution = UIStackViewDistributionFillEqually;

    self.cancelButton = [self pp_buildActionButton:(kLang(@"Cancel") ?: @"Cancel")
                                            filled:NO];
    [self.cancelButton addTarget:self action:@selector(pp_cancel)
                forControlEvents:UIControlEventTouchUpInside];
    [btnRow addArrangedSubview:self.cancelButton];

    NSString *saveTxt = self.isNewRecord
        ? (kLang(@"Add") ?: @"Add")
        : (kLang(@"Save") ?: @"Save");
    self.saveButton = [self pp_buildActionButton:saveTxt filled:YES];
    [self.saveButton addTarget:self action:@selector(pp_save)
              forControlEvents:UIControlEventTouchUpInside];
    [btnRow addArrangedSubview:self.saveButton];

    [self.stack addArrangedSubview:btnRow];

    // ── Layout ──
    [NSLayoutConstraint activateConstraints:@[
        [grabberAccent.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
        [grabberAccent.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kSheetHPad],
        [grabberAccent.widthAnchor constraintEqualToConstant:48.0],
        [grabberAccent.heightAnchor constraintEqualToConstant:4.0],

        [sheetTitle.topAnchor constraintEqualToAnchor:grabberAccent.bottomAnchor constant:18.0],
        [sheetTitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kSheetHPad],
        [sheetTitle.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kSheetHPad],

        [sheetSubtitle.topAnchor constraintEqualToAnchor:sheetTitle.bottomAnchor constant:6.0],
        [sheetSubtitle.leadingAnchor constraintEqualToAnchor:sheetTitle.leadingAnchor],
        [sheetSubtitle.trailingAnchor constraintEqualToAnchor:sheetTitle.trailingAnchor],

        [self.scrollView.topAnchor constraintEqualToAnchor:sheetSubtitle.bottomAnchor constant:20.0],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.stack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:kSheetHPad],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-kSheetHPad],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-32.0],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-(kSheetHPad * 2)],

        [btnRow.heightAnchor constraintEqualToConstant:52.0],
    ]];

    // Tap to dismiss keyboard
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self.view action:@selector(endEditing:)];
    tap.cancelsTouchesInView = NO;
    [self.scrollView addGestureRecognizer:tap];
}

#pragma mark - Helpers

- (UILabel *)pp_sectionLabel:(NSString *)text {
    UILabel *lbl = [UILabel new];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font      = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    lbl.textColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.85];
    lbl.text      = text;
    lbl.textAlignment = Language.alignmentForCurrentLanguage;
    return lbl;
}

- (UIButton *)pp_buildActionButton:(NSString *)title filled:(BOOL)filled {
    UIColor *fg = filled ? UIColor.whiteColor : PPPetsUIBrandColor();
    UIColor *bg = filled ? PPPetsUIBrandColor() : PPPetsUISurfaceColor();

    UIButtonConfiguration *config = filled
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration tintedButtonConfiguration];
    config.contentInsets   = NSDirectionalEdgeInsetsMake(14.0, 20.0, 14.0, 20.0);
    config.cornerStyle     = UIButtonConfigurationCornerStyleLarge;
    config.baseForegroundColor = fg;
    config.baseBackgroundColor = bg;
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                            attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: fg
    }];

    UIButton *btn = [UIButton buttonWithConfiguration:config primaryAction:nil];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    if (!filled) {
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.16].CGColor;
    }
    if (@available(iOS 13.0, *)) {
        btn.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return btn;
}

#pragma mark - Populate

- (void)pp_populateFields {
    self.nameField.text  = self.record.name ?: @"";
    self.notesField.text = self.record.notes ?: @"";

    if (self.record.appliedAt) {
        self.appliedDateRow.picker.date = self.record.appliedAt;
    }
    if (self.record.nextDueDate) {
        self.nextDueDateRow.picker.date  = self.record.nextDueDate;
        self.nextDueDateRow.toggle.on    = YES;
        self.nextDueDateRow.dateEnabled  = YES;
        self.nextDueDateRow.picker.alpha = 1.0;
        self.nextDueDateRow.picker.enabled = YES;
    }
}

#pragma mark - Actions

- (void)pp_save {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        [self pp_shakeField:self.nameField];
        return;
    }

    self.record.name      = name;
    self.record.appliedAt = self.appliedDateRow.selectedDate;
    self.record.notes     = [self.notesField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.record.nextDueDate = self.nextDueDateRow.selectedDate;

    __weak typeof(self) ws = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (ws.completion) ws.completion(ws.record, YES);
    }];
}

- (void)pp_cancel {
    __weak typeof(self) ws = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (ws.completion) ws.completion(nil, NO);
    }];
}

- (void)pp_shakeField:(UIView *)field {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    shake.duration = 0.4;
    shake.values   = @[@(-8), @(8), @(-6), @(6), @(-3), @(3), @(0)];
    [field.layer addAnimation:shake forKey:@"shake"];

    field.layer.borderColor = UIColor.systemRedColor.CGColor;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        field.layer.borderColor = PPPetsUISurfaceBorderColor().CGColor;
    });
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.nameField) {
        [self.notesField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

#pragma mark - Dark Mode

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        CGColorRef borderCG = [PPPetsUISurfaceBorderColor() resolvedColorWithTraitCollection:self.traitCollection].CGColor;
        self.nameField.layer.borderColor       = borderCG;
        self.notesField.layer.borderColor      = borderCG;
        self.appliedDateRow.layer.borderColor   = borderCG;
        self.nextDueDateRow.layer.borderColor   = borderCG;
    }
}

@end
