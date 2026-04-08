//
//  PPReminderEditorViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//  Modern UI — matches ProfileVC.m form style exactly (accent-bar headers,
//  ProfileTextFieldCell-pattern fields, inset base cells, PPHUD).
//

#import "PPReminderEditorViewController.h"
#import "PPPetReminder.h"
#import "PPPetProfile.h"
#import "UserManager.h"
#import "Language.h"
#import "GM.h"
#import "PPPetProfilesUIStyle.h"

// ─── Constants (ProfileVC pattern) ────────────────────────

static const CGFloat kPPRemEdCellHInset = 20.0;
static const CGFloat kPPRemEdCellVInset = 10.0;

static inline UISemanticContentAttribute PPRemEdSemanticAttr(void) {
    return PPPetsCurrentSemanticAttribute();
}

// ─── Sections ─────────────────────────────────────────────

typedef NS_ENUM(NSInteger, PPRemEdSection) {
    PPRemEdSectionTitle   = 0,
    PPRemEdSectionType    = 1,
    PPRemEdSectionPet     = 2,
    PPRemEdSectionDate    = 3,
    PPRemEdSectionToggle  = 4,
    PPRemEdSectionCount   = 5
};

// ─── Base Cell (ProfileVC inset pattern) ──────────────────

@interface PPRemEdBaseCell : UITableViewCell
@end

@implementation PPRemEdBaseCell

- (void)setFrame:(CGRect)frame {
    frame.origin.x    = kPPRemEdCellHInset;
    frame.size.width -= kPPRemEdCellHInset * 2.0;
    frame.origin.y   += kPPRemEdCellVInset * 0.5;
    frame.size.height -= kPPRemEdCellVInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

@end

// ─── Text Field Cell (ProfileVC PPProfileTextFieldCell pattern) ──

@interface PPRemEdFieldCell : PPRemEdBaseCell
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UITextField *textField;
@end

@implementation PPRemEdFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;
    self.semanticContentAttribute = PPRemEdSemanticAttr();
    self.contentView.semanticContentAttribute = PPRemEdSemanticAttr();

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font      = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = PPPetsUIPrimaryTextColor();
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:_titleLabel];

    _textField = [UITextField new];
    _textField.translatesAutoresizingMaskIntoConstraints = NO;
    _textField.borderStyle       = UITextBorderStyleNone;
    _textField.backgroundColor   = UIColor.clearColor;
    _textField.textColor         = PPPetsUIPrimaryTextColor();
    _textField.font              = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    _textField.clearButtonMode   = UITextFieldViewModeWhileEditing;
    _textField.autocorrectionType = UITextAutocorrectionTypeNo;
    _textField.textAlignment     = Language.alignmentForCurrentLanguage;
    _textField.semanticContentAttribute = PPRemEdSemanticAttr();
    [self.contentView addSubview:_textField];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor     constant:14.0],
        [_titleLabel.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [_textField.topAnchor      constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8.0],
        [_textField.leadingAnchor  constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_textField.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_textField.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        [_textField.heightAnchor   constraintGreaterThanOrEqualToConstant:24.0],
    ]];
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
}

@end

// ─── View Controller ──────────────────────────────────────

@interface PPReminderEditorViewController () <UITextFieldDelegate>
@property (nonatomic, strong) PPPetReminder *reminder;
@property (nonatomic, assign) BOOL isNewReminder;

@property (nonatomic, strong) NSArray<PPPetProfile *> *pets;
@property (nonatomic, assign) NSInteger selectedPetIndex;
@property (nonatomic, assign) BOOL petsLoaded;

@property (nonatomic, strong) UITextField          *titleField;
@property (nonatomic, strong) UISegmentedControl   *typeControl;
@property (nonatomic, strong) UIDatePicker         *datePicker;
@property (nonatomic, strong) UISwitch             *enableSwitch;
@property (nonatomic, strong) UIView               *headerRoot;
@property (nonatomic, strong) UIView               *headerCardView;
@property (nonatomic, strong) PPInsetLabel         *heroEyebrowLabel;
@property (nonatomic, strong) UILabel              *heroTitleLabel;
@property (nonatomic, strong) UILabel              *heroSubtitleLabel;
@property (nonatomic, strong) PPInsetLabel         *heroMetaLabel;
@property (nonatomic, strong) UIImageView          *heroSymbolView;
@property (nonatomic, strong) UIView               *backgroundGlowViewTop;
@property (nonatomic, strong) UIView               *backgroundGlowViewBottom;
@property (nonatomic, strong) NSArray<UIView *>    *floatingCircles;
@end

@implementation PPReminderEditorViewController

#pragma mark - Init

- (instancetype)initWithReminder:(PPPetReminder *)reminder {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _isNewReminder = (reminder == nil);
        _reminder = reminder ?: [PPPetReminder new];
        if (_isNewReminder) {
            _reminder.enabled = YES;
            _reminder.type    = PPPetReminderTypeVaccination;
        }
        _pets             = @[];
        _selectedPetIndex = NSNotFound;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)loadView {
    // UITableViewController sets self.view = self.tableView.
    // We need a container view so backdrop glow views can be inserted *behind* the table.
    [super loadView];

    UITableView *tv = self.tableView;
    UIView *container = [[UIView alloc] initWithFrame:tv.frame];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.frame = container.bounds;
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:tv];
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.backgroundColor  = UIColor.clearColor;
    self.tableView.separatorStyle   = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.semanticContentAttribute = PPRemEdSemanticAttr();
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    self.title = self.isNewReminder
        ? (kLang(@"pet_reminder_add")  ?: @"Add Reminder")
        : (kLang(@"pet_reminder_edit") ?: @"Edit Reminder");

    // Nav — AddressFormVC style
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pp_handleBack)];
    UIButton *saveButton = [PPButtonHelper pp_buttonWithTitle:kLang(@"Save") ?: @"Save"
                                                          font:[GM fontWithSize:17]
                                                     imageName:@""
                                                        target:self
                                                        config:[UIButtonConfiguration tintedButtonConfiguration]
                                                        action:@selector(pp_save)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:saveButton];

    [self pp_setupBackdrop];
    [self pp_buildControls];
    [self pp_buildHeroHeader];
    [self pp_applyCanvasBackground];
    [self pp_refreshHeroHeader];
    [self pp_loadPets];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Appearance

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.semanticContentAttribute = PPRemEdSemanticAttr();
    self.tableView.semanticContentAttribute = PPRemEdSemanticAttr();
    [self pp_applyCanvasBackground];
    [self pp_refreshHeroHeader];
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

- (void)pp_applyCanvasBackground {
    PPPetsApplyCanvasBackground(self, nil);
    self.tableView.backgroundColor = UIColor.clearColor;
}

- (void)pp_setupBackdrop {
    if (self.backgroundGlowViewTop || self.backgroundGlowViewBottom) {
        return;
    }

    UIView *topGlow = PPPetsBuildGlowView([[UIColor colorWithRed:0.93 green:0.80 blue:0.69 alpha:1.0] colorWithAlphaComponent:0.12],
                                          [UIColor colorWithRed:0.98 green:0.82 blue:0.60 alpha:1.0],
                                          0.10,
                                          64.0);
    UIView *bottomGlow = PPPetsBuildGlowView([[UIColor colorWithRed:0.72 green:0.45 blue:0.42 alpha:1.0] colorWithAlphaComponent:0.06],
                                             [UIColor colorWithRed:0.68 green:0.27 blue:0.33 alpha:1.0],
                                             0.08,
                                             72.0);

    [self.view insertSubview:topGlow belowSubview:self.tableView];
    [self.view insertSubview:bottomGlow belowSubview:self.tableView];

    // Anchor to the container's own edges (not safeAreaLayoutGuide)
    // because the view is not yet in a window hierarchy during viewDidLoad.
    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-22.0],
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

#pragma mark - Build Controls

- (void)pp_buildControls {
    _titleField = [UITextField new];
    _titleField.placeholder    = kLang(@"pet_reminder_title") ?: @"Reminder title";
    _titleField.text           = self.reminder.title;
    _titleField.font           = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    _titleField.textColor      = PPPetsUIPrimaryTextColor();
    _titleField.textAlignment  = Language.alignmentForCurrentLanguage;
    _titleField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _titleField.returnKeyType  = UIReturnKeyDone;
    _titleField.delegate       = self;
    _titleField.borderStyle    = UITextBorderStyleNone;
    _titleField.autocorrectionType = UITextAutocorrectionTypeNo;
    _titleField.semanticContentAttribute = PPRemEdSemanticAttr();
    [_titleField addTarget:self action:@selector(pp_controlValueChanged:) forControlEvents:UIControlEventEditingChanged];

    NSArray *typeItems = @[
        [NSString stringWithFormat:@"💉 %@", kLang(@"pet_reminder_vaccination") ?: @"Vaccination"],
        [NSString stringWithFormat:@"🍖 %@", kLang(@"pet_reminder_food") ?: @"Food"],
        [NSString stringWithFormat:@"📅 %@", kLang(@"pet_reminder_appointment") ?: @"Appointment"]
    ];
    _typeControl = [[UISegmentedControl alloc] initWithItems:typeItems];
    _typeControl.selectedSegmentIndex = self.reminder.type;
    _typeControl.selectedSegmentTintColor = PPPetsUIBrandColor();
    _typeControl.semanticContentAttribute = PPRemEdSemanticAttr();
    UIFont *segFont = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightMedium];
    [_typeControl setTitleTextAttributes:@{NSFontAttributeName: segFont,
                                           NSForegroundColorAttributeName: UIColor.whiteColor}
                                forState:UIControlStateSelected];
    [_typeControl setTitleTextAttributes:@{NSFontAttributeName: segFont,
                                           NSForegroundColorAttributeName: PPPetsUIPrimaryTextColor()}
                                forState:UIControlStateNormal];
    [_typeControl addTarget:self action:@selector(pp_controlValueChanged:) forControlEvents:UIControlEventValueChanged];

    _datePicker = [UIDatePicker new];
    _datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    _datePicker.tintColor      = PPPetsUIBrandColor();
    _datePicker.minimumDate    = [NSDate date];
    if (@available(iOS 13.4, *)) {
        _datePicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    if (self.reminder.fireDate) _datePicker.date = self.reminder.fireDate;
    _datePicker.semanticContentAttribute = PPRemEdSemanticAttr();
    [_datePicker addTarget:self action:@selector(pp_controlValueChanged:) forControlEvents:UIControlEventValueChanged];

    _enableSwitch = [UISwitch new];
    _enableSwitch.on        = self.reminder.enabled;
    _enableSwitch.onTintColor = PPPetsUIBrandColor();
    [_enableSwitch addTarget:self action:@selector(pp_controlValueChanged:) forControlEvents:UIControlEventValueChanged];
}

#pragma mark - Hero Header

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

    UIView *secondaryGlow = PPPetsBuildGlowView([[UIColor whiteColor] colorWithAlphaComponent:0.40],
                                                [[UIColor whiteColor] colorWithAlphaComponent:0.45],
                                                0.20,
                                                22.0);
    secondaryGlow.layer.cornerRadius = 58.0;
    [cardView addSubview:secondaryGlow];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = PPPetsUIBrandColor();
    accentBar.layer.cornerRadius = 3.0;
    [cardView addSubview:accentBar];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    eyebrowPill.layer.cornerRadius = 14.0;
    eyebrowPill.layer.borderWidth = 1.0;
    eyebrowPill.layer.borderColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.10].CGColor;
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
    iconHalo.layer.cornerRadius = 62.0;
    iconHalo.layer.borderWidth = 1.0;
    iconHalo.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.48].CGColor;
    iconHalo.layer.shadowColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.30].CGColor;
    iconHalo.layer.shadowOpacity = 0.12;
    iconHalo.layer.shadowRadius = 22.0;
    iconHalo.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [cardView addSubview:iconHalo];

    UIImageView *symbolView = [[UIImageView alloc] init];
    symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    symbolView.contentMode = UIViewContentModeCenter;
    symbolView.tintColor = PPPetsUIBrandColor();
    symbolView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    symbolView.layer.cornerRadius = 54.0;
    symbolView.layer.masksToBounds = YES;
    [iconHalo addSubview:symbolView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
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
    metaLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    metaLabel.layer.cornerRadius = 17.0;
    metaLabel.layer.borderWidth = 1.0;
    metaLabel.layer.borderColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.10].CGColor;
    metaLabel.layer.masksToBounds = YES;
    metaLabel.textInsets = UIEdgeInsetsMake(6.0, 12.0, 6.0, 12.0);
    [cardView addSubview:metaLabel];

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

        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:22.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [eyebrowPill.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:12.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        [iconHalo.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [iconHalo.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:20.0],
        [iconHalo.widthAnchor constraintEqualToConstant:124.0],
        [iconHalo.heightAnchor constraintEqualToConstant:124.0],

        [symbolView.centerXAnchor constraintEqualToAnchor:iconHalo.centerXAnchor],
        [symbolView.centerYAnchor constraintEqualToAnchor:iconHalo.centerYAnchor],
        [symbolView.widthAnchor constraintEqualToConstant:108.0],
        [symbolView.heightAnchor constraintEqualToConstant:108.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconHalo.bottomAnchor constant:22.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:14.0],
        [metaLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:cardView.leadingAnchor constant:34.0],
        [metaLabel.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-34.0],
        [metaLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],
    ]];

    self.headerCardView = cardView;
    self.heroEyebrowLabel = eyebrowLabel;
    self.heroTitleLabel = titleLabel;
    self.heroSubtitleLabel = subtitleLabel;
    self.heroMetaLabel = metaLabel;
    self.heroSymbolView = symbolView;
    self.tableView.tableHeaderView = self.headerRoot;
}

- (void)pp_refreshHeroHeader {
    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    PPPetReminderType currentType = (PPPetReminderType)self.typeControl.selectedSegmentIndex;
    NSString *typeText = nil;
    switch (currentType) {
        case PPPetReminderTypeFood:
            typeText = kLang(@"pet_reminder_food") ?: @"Food";
            break;
        case PPPetReminderTypeAppointment:
            typeText = kLang(@"pet_reminder_appointment") ?: @"Appointment";
            break;
        default:
            typeText = kLang(@"pet_reminder_vaccination") ?: @"Vaccination";
            break;
    }
    if (title.length == 0) {
        title = typeText;
    }

    NSString *petName = @"";
    if (self.selectedPetIndex != NSNotFound && self.selectedPetIndex < (NSInteger)self.pets.count) {
        PPPetProfile *pet = self.pets[self.selectedPetIndex];
        petName = pet.name.length ? pet.name : (kLang(@"pet_unknown") ?: @"Pet");
    } else if (self.petsLoaded && self.pets.count == 0) {
        petName = kLang(@"pet_no_pets") ?: @"No pets added";
    } else {
        petName = kLang(@"pet_reminder_select_pet") ?: @"Choose a pet";
    }

    self.heroEyebrowLabel.text = self.isNewReminder
        ? (kLang(@"pet_reminder_add") ?: @"Add Reminder")
        : (kLang(@"pet_reminder_edit") ?: @"Edit Reminder");
    self.heroTitleLabel.text = title.length ? title : (kLang(@"pet_reminder_title") ?: @"Reminder");
    self.heroSubtitleLabel.text = [NSString stringWithFormat:@"%@ · %@", petName, typeText ?: @""];

    NSString *dateText = self.datePicker.date ? [GM formattedDate:self.datePicker.date] : (kLang(@"pet_reminder_no_date") ?: @"No date set");
    NSString *statusText = self.enableSwitch.isOn ? (kLang(@"pet_reminder_enable") ?: @"Enabled") : (kLang(@"pet_reminder_disable") ?: @"Disabled");
    self.heroMetaLabel.text = [NSString stringWithFormat:@"%@ · %@", dateText, statusText];

    NSString *symbolName = @"bell.badge.fill";
    switch (currentType) {
        case PPPetReminderTypeFood:
            symbolName = @"fork.knife.circle.fill";
            break;
        case PPPetReminderTypeAppointment:
            symbolName = @"calendar.badge.clock";
            break;
        default:
            symbolName = @"syringe.fill";
            break;
    }
    self.heroSymbolView.image = [UIImage systemImageNamed:symbolName
                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:44.0 weight:UIImageSymbolWeightMedium]];

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

#pragma mark - Load Pets

- (void)pp_loadPets {
    __weak typeof(self) ws = self;
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> *pets, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ws.pets = pets ?: @[];
            ws.petsLoaded = YES;
            ws.selectedPetIndex = NSNotFound;
            for (NSUInteger i = 0; i < ws.pets.count; i++) {
                if ([ws.pets[i].petID isEqualToString:ws.reminder.petID]) {
                    ws.selectedPetIndex = (NSInteger)i;
                    break;
                }
            }
            if (ws.selectedPetIndex == NSNotFound && ws.pets.count > 0) {
                ws.selectedPetIndex = 0;
            }
            [ws pp_refreshHeroHeader];
            [ws.tableView reloadSections:[NSIndexSet indexSetWithIndex:PPRemEdSectionPet]
                        withRowAnimation:UITableViewRowAnimationFade];
        });
    }];
}

#pragma mark - Section Header (ProfileVC accent-bar pattern)

- (UIView *)pp_sectionHeaderWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    return PPPetsBuildSectionHeaderView(title, subtitle);
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return PPRemEdSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil; // Custom header views used
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    switch (section) {
        case PPRemEdSectionTitle:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_reminder_title_section") ?: @"Title")
                                         subtitle:(kLang(@"pet_reminder_title_hint") ?: @"Give the reminder a short name you can recognize in one glance.")];
        case PPRemEdSectionType:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_reminder_type_section") ?: @"Type")
                                         subtitle:(kLang(@"pet_reminder_type_hint") ?: @"Choose the care context so the reminder feels immediately scannable later.")];
        case PPRemEdSectionPet:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_reminder_pet_section") ?: @"Pet")
                                         subtitle:(kLang(@"pet_reminder_pet_hint") ?: @"Attach the reminder to the right profile before saving.")];
        case PPRemEdSectionDate:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_reminder_date_section") ?: @"Date & Time")
                                         subtitle:(kLang(@"pet_reminder_date_hint") ?: @"Set the next moment this reminder should surface in the care flow.")];
        case PPRemEdSectionToggle:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_reminder_toggle_section") ?: @"Status")
                                         subtitle:(kLang(@"pet_reminder_toggle_hint") ?: @"Keep it active now or save it disabled until the schedule is ready.")];
        default:
            return [UIView new];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 76.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.000001;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return 76.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section {
    return 0.000001;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case PPRemEdSectionTitle:  return [self pp_titleCell];
        case PPRemEdSectionType:   return [self pp_typeCell];
        case PPRemEdSectionPet:    return [self pp_petCell];
        case PPRemEdSectionDate:   return [self pp_dateCell];
        case PPRemEdSectionToggle: return [self pp_toggleCell];
        default: return [UITableViewCell new];
    }
}

#pragma mark - Cell Builders

- (UITableViewCell *)pp_titleCell {
    PPRemEdFieldCell *cell = [[PPRemEdFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];

    cell.titleLabel.text = kLang(@"pet_reminder_title") ?: @"Reminder Title";

    self.titleField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.titleField removeFromSuperview];

    // Replace the cell's built-in textField with our shared titleField
    cell.textField.hidden = YES;
    [cell.contentView addSubview:self.titleField];
    [NSLayoutConstraint activateConstraints:@[
        [self.titleField.topAnchor      constraintEqualToAnchor:cell.titleLabel.bottomAnchor constant:8.0],
        [self.titleField.leadingAnchor  constraintEqualToAnchor:cell.titleLabel.leadingAnchor],
        [self.titleField.trailingAnchor constraintEqualToAnchor:cell.titleLabel.trailingAnchor],
        [self.titleField.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-14.0],
        [self.titleField.heightAnchor   constraintGreaterThanOrEqualToConstant:24.0],
    ]];
    return cell;
}

- (UITableViewCell *)pp_typeCell {
    PPRemEdBaseCell *cell = [[PPRemEdBaseCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle  = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.clearColor;

    self.typeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.typeControl removeFromSuperview];
    [cell.contentView addSubview:self.typeControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.typeControl.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor      constant:14.0],
        [self.typeControl.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor   constant:-14.0],
        [self.typeControl.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor  constant:18.0],
        [self.typeControl.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-18.0],
    ]];
    return cell;
}

- (UITableViewCell *)pp_petCell {
    PPRemEdBaseCell *cell = [[PPRemEdBaseCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = UIColor.clearColor;
    cell.accessoryType   = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.font  = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
    cell.textLabel.textColor = PPPetsUIPrimaryTextColor();
    cell.textLabel.text  = kLang(@"pet_reminder_select_pet") ?: @"Select Pet";
    cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;

    cell.imageView.image = [[UIImage systemImageNamed:@"pawprint.fill"]
                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.imageView.tintColor = PPPetsUIBrandColor();

    if (self.petsLoaded && self.selectedPetIndex != NSNotFound && self.selectedPetIndex < (NSInteger)self.pets.count) {
        PPPetProfile *pet = self.pets[self.selectedPetIndex];
        cell.detailTextLabel.text = pet.name.length ? pet.name : (kLang(@"pet_unknown") ?: @"Pet");
        cell.detailTextLabel.textColor = PPPetsUIBrandColor();
        cell.detailTextLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightMedium];
    } else if (self.petsLoaded && self.pets.count == 0) {
        cell.detailTextLabel.text = kLang(@"pet_no_pets") ?: @"No pets added";
        cell.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
    } else {
        cell.detailTextLabel.text = kLang(@"please_wait") ?: @"Loading…";
        cell.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
    }
    return cell;
}

- (UITableViewCell *)pp_dateCell {
    PPRemEdBaseCell *cell = [[PPRemEdBaseCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle  = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.clearColor;

    UILabel *lbl  = [UILabel new];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font      = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
    lbl.textColor = PPPetsUIPrimaryTextColor();
    lbl.text      = kLang(@"pet_reminder_fire_date") ?: @"Date & Time";
    lbl.textAlignment = Language.alignmentForCurrentLanguage;
    [cell.contentView addSubview:lbl];

    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [self.datePicker removeFromSuperview];
    [cell.contentView addSubview:self.datePicker];

    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor constant:18.0],
        [lbl.centerYAnchor  constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [self.datePicker.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-18.0],
        [self.datePicker.centerYAnchor  constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [self.datePicker.topAnchor      constraintGreaterThanOrEqualToAnchor:cell.contentView.topAnchor    constant:8.0],
        [self.datePicker.bottomAnchor   constraintLessThanOrEqualToAnchor:cell.contentView.bottomAnchor constant:-8.0],
        [lbl.trailingAnchor constraintLessThanOrEqualToAnchor:self.datePicker.leadingAnchor constant:-8.0],
    ]];
    return cell;
}

- (UITableViewCell *)pp_toggleCell {
    PPRemEdBaseCell *cell = [[PPRemEdBaseCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle  = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.clearColor;
    cell.textLabel.text  = kLang(@"pet_reminder_enabled") ?: @"Enabled";
    cell.textLabel.font  = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
    cell.textLabel.textColor = PPPetsUIPrimaryTextColor();
    cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;

    [self.enableSwitch removeFromSuperview];
    cell.accessoryView = self.enableSwitch;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == PPRemEdSectionPet) {
        [self pp_showPetPicker];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    PPPetsApplySurfaceCellStyle(cell, 20.0);
}

#pragma mark - Pet Picker

- (void)pp_showPetPicker {
    if (self.pets.count == 0) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"pet_no_pets_title") ?: @"No Pets"
                          subtitle:kLang(@"pet_no_pets_msg") ?: @"Add a pet profile first."];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"pet_reminder_select_pet") ?: @"Select Pet"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) ws = self;
    for (NSUInteger i = 0; i < self.pets.count; i++) {
        PPPetProfile *pet = self.pets[i];
        NSString *name = pet.name.length ? pet.name : [NSString stringWithFormat:@"Pet %lu", (unsigned long)i + 1];
        UIAlertAction *act = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
            ws.selectedPetIndex = (NSInteger)i;
            [ws.tableView reloadSections:[NSIndexSet indexSetWithIndex:PPRemEdSectionPet]
                        withRowAnimation:UITableViewRowAnimationFade];
            [ws pp_refreshHeroHeader];
        }];
        if ((NSInteger)i == self.selectedPetIndex) {
            [act setValue:[UIImage systemImageNamed:@"checkmark.circle.fill"] forKey:@"image"];
        }
        [sheet addAction:act];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") ?: @"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Save

- (void)pp_handleBack {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_save {
    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length == 0) {
        CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
        shake.values   = @[@0, @(-10), @(10), @(-8), @(8), @(-4), @(4), @0];
        shake.duration = 0.4;
        [self.titleField.layer addAnimation:shake forKey:@"shake"];
        [PPHUD showError:(kLang(@"pet_reminder_title_required") ?: @"Title Required")
                subtitle:(kLang(@"pet_reminder_title_required_msg") ?: @"Please enter a reminder title.")];
        return;
    }

    if (self.selectedPetIndex == NSNotFound || self.selectedPetIndex >= (NSInteger)self.pets.count) {
        [PPHUD showError:(kLang(@"pet_reminder_pet_required") ?: @"Pet Required")
                subtitle:(kLang(@"pet_reminder_pet_required_msg") ?: @"Please select a pet for this reminder.")];
        return;
    }

    self.reminder.title    = title;
    self.reminder.type     = self.typeControl.selectedSegmentIndex;
    self.reminder.petID    = self.pets[self.selectedPetIndex].petID ?: @"";
    self.reminder.fireDate = self.datePicker.date;
    self.reminder.enabled  = self.enableSwitch.isOn;

    [PPHUD showIndeterminateIn:self.view title:(kLang(@"please_wait") ?: @"Saving…") subtitle:nil];
    self.navigationItem.rightBarButtonItem.enabled = NO;

    __weak typeof(self) ws = self;
    [[UserManager sharedManager] savePetReminder:self.reminder completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ws.navigationItem.rightBarButtonItem.enabled = YES;
            if (error) {
                [PPHUD showError:(kLang(@"SomethingWentWrong") ?: @"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:(kLang(@"Done") ?: @"Saved") subtitle:nil];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [ws.navigationController popViewControllerAnimated:YES];
                });
            }
        });
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self pp_refreshHeroHeader];
    return YES;
}

- (void)pp_controlValueChanged:(id)sender {
    [self pp_refreshHeroHeader];
}

@end
