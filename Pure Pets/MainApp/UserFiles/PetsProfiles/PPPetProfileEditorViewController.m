//
//  PPPetProfileEditorViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//  Modern UI — matches ProfileVC.m form style exactly (accent-bar headers,
//  PPProfileTextFieldCell-pattern fields, hero image, vaccine cards, PPHUD).
//

#import "PPPetProfileEditorViewController.h"
#import "PPPetProfile.h"
#import "PPModernAvatarRenderer.h"
#import "PPVaccinationEditorSheet.h"
#import "UserManager.h"
#import "Language.h"
#import "GM.h"
 
@import PhotosUI;

// ─── Image cache ──────────────────────────────────────────

static NSCache<NSString *, UIImage *> *PPEditorImgCache(void) {
    static NSCache *c;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ c = [NSCache new]; c.countLimit = 20; });
    return c;
}

static NSURLSession *PPEditorURLSession(void) {
    static NSURLSession *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30;
        cfg.timeoutIntervalForResource = 60;
        s = [NSURLSession sessionWithConfiguration:cfg];
    });
    return s;
}

static void PPEditorLoadImage(UIImageView *iv, NSString *url, UIImage *ph) {
    iv.image = ph;
    if (!url.length) return;
    UIImage *cached = [PPEditorImgCache() objectForKey:url];
    if (cached) { iv.image = cached; return; }
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return;
    __weak UIImageView *w = iv;
    [[PPEditorURLSession() dataTaskWithURL:u completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d) return;
        UIImage *img = [UIImage imageWithData:d];
        if (!img) return;
        [PPEditorImgCache() setObject:img forKey:url];
        dispatch_async(dispatch_get_main_queue(), ^{ w.image = img; });
    }] resume];
}

// ─── Constants (matches ProfileVC.m exactly) ──────────────

static const CGFloat kPPEditorCellHorizontalInset = 20.0;
static const CGFloat kPPEditorCellVerticalInset   = 10.0;

static inline UISemanticContentAttribute PPEditorSemanticAttr(void) {
    return PPPetsCurrentSemanticAttribute();
}

// ─── Section / Row Enums ──────────────────────────────────

typedef NS_ENUM(NSInteger, PPEditorSection) {
    PPEditorSectionPhoto = 0,
    PPEditorSectionInfo,
    PPEditorSectionSettings,
    PPEditorSectionVaccinations,
    PPEditorSectionCount
};

typedef NS_ENUM(NSInteger, PPEditorInfoRow) {
    PPEditorInfoRowName = 0,
    PPEditorInfoRowBreed,
    PPEditorInfoRowAge,
    PPEditorInfoRowCount
};

typedef NS_ENUM(NSInteger, PPEditorFieldKind) {
    PPEditorFieldName  = 100,
    PPEditorFieldBreed = 101,
    PPEditorFieldAge   = 102
};

// ─── Base Cell (ProfileVC inset pattern) ──────────────────

@interface PPPetEditorBaseCell : UITableViewCell
@end

@implementation PPPetEditorBaseCell

- (void)setFrame:(CGRect)frame {
    frame.origin.x    = kPPEditorCellHorizontalInset;
    frame.size.width -= kPPEditorCellHorizontalInset * 2.0;
    frame.origin.y   += kPPEditorCellVerticalInset * 0.5;
    frame.size.height -= kPPEditorCellVerticalInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

@end

// ─── Text Field Cell (ProfileVC PPProfileTextFieldCell pattern) ──

@interface PPPetEditorFieldCell : PPPetEditorBaseCell
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UITextField *textField;
@end

@implementation PPPetEditorFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;
    self.semanticContentAttribute = PPEditorSemanticAttr();
    self.contentView.semanticContentAttribute = PPEditorSemanticAttr();

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font      = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = AppPrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:_titleLabel];

    _textField = [UITextField new];
    _textField.translatesAutoresizingMaskIntoConstraints = NO;
    _textField.borderStyle       = UITextBorderStyleNone;
    _textField.backgroundColor   = UIColor.clearColor;
    _textField.textColor         = AppPrimaryTextClr;
    _textField.font              = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    _textField.clearButtonMode   = UITextFieldViewModeWhileEditing;
    _textField.autocorrectionType = UITextAutocorrectionTypeNo;
    _textField.textAlignment     = Language.alignmentForCurrentLanguage;
    _textField.semanticContentAttribute = PPEditorSemanticAttr();
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

- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)ph
              keyboardType:(UIKeyboardType)kb
                 fieldKind:(PPEditorFieldKind)kind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate
{
    self.semanticContentAttribute = PPEditorSemanticAttr();
    self.contentView.semanticContentAttribute = PPEditorSemanticAttr();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.text = text ?: @"";
    self.textField.placeholder = ph ?: @"";
    self.textField.tag = kind;
    self.textField.delegate = delegate;
    self.textField.keyboardType = kb;
    self.textField.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.semanticContentAttribute = PPEditorSemanticAttr();
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end

// ─── Vaccine Card Cell ────────────────────────────────────

@interface PPPetEditorVaccineCell : PPPetEditorBaseCell
@property (nonatomic, strong) UILabel  *nameLabel;
@property (nonatomic, strong) UILabel  *notesLabel;
@property (nonatomic, strong) UILabel  *dateLabel;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, copy)   void (^onDelete)(void);
@end

@implementation PPPetEditorVaccineCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.semanticContentAttribute = PPEditorSemanticAttr();
    self.contentView.semanticContentAttribute = PPEditorSemanticAttr();

    _nameLabel = [UILabel new];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font      = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _nameLabel.textColor = AppPrimaryTextClr;
    [self.contentView addSubview:_nameLabel];

    _notesLabel = [UILabel new];
    _notesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _notesLabel.font          = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _notesLabel.textColor     = PPPetsUISecondaryTextColor();
    _notesLabel.numberOfLines = 2;
    [self.contentView addSubview:_notesLabel];

    _dateLabel = [UILabel new];
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateLabel.font      = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    _dateLabel.textColor = PPPetsUIBrandColor();
    [self.contentView addSubview:_dateLabel];

    _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_deleteButton setImage:[UIImage systemImageNamed:@"trash.circle.fill"] forState:UIControlStateNormal];
    _deleteButton.tintColor = UIColor.systemRedColor;
    [_deleteButton addTarget:self action:@selector(pp_del) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:_deleteButton];

    [NSLayoutConstraint activateConstraints:@[
        [_deleteButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [_deleteButton.centerYAnchor  constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_deleteButton.widthAnchor    constraintEqualToConstant:PPTouchTargetMin],
        [_deleteButton.heightAnchor   constraintEqualToConstant:PPTouchTargetMin],

        [_nameLabel.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor     constant:14.0],
        [_nameLabel.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_deleteButton.leadingAnchor constant:-8.0],

        [_notesLabel.topAnchor     constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4.0],
        [_notesLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_notesLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],

        [_dateLabel.topAnchor      constraintEqualToAnchor:_notesLabel.bottomAnchor constant:4.0],
        [_dateLabel.leadingAnchor  constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_dateLabel.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
    ]];
    return self;
}

- (void)configureWithRecord:(PPPetVaccinationRecord *)rec {
    self.nameLabel.text  = rec.name.length ? rec.name : (kLang(@"pet_vaccine_name") ?: @"Unnamed Vaccine");
    self.notesLabel.text = rec.notes.length ? rec.notes : (kLang(@"pet_vaccine_no_notes") ?: @"No notes");

    NSMutableArray *dateParts = [NSMutableArray array];
    if (rec.appliedAt) {
        [dateParts addObject:[NSString stringWithFormat:@"%@: %@",
                              kLang(@"pet_vaccine_applied") ?: @"Given",
                              [GM formattedDate:rec.appliedAt]]];
    }
    if (rec.nextDueDate) {
        [dateParts addObject:[NSString stringWithFormat:@"%@: %@",
                              kLang(@"pet_vaccine_next_due") ?: @"Next",
                              [GM formattedDate:rec.nextDueDate]]];
    }
    self.dateLabel.text = dateParts.count ? [dateParts componentsJoinedByString:@"  ·  "]
                                         : (kLang(@"pet_vaccine_no_date") ?: @"No date");

    self.nameLabel.textAlignment  = Language.alignmentForCurrentLanguage;
    self.notesLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.dateLabel.textAlignment  = Language.alignmentForCurrentLanguage;
}

- (void)pp_del { if (self.onDelete) self.onDelete(); }

@end

// ─── Settings / Add Button Cell (with BaseCell insets) ────

@interface PPPetEditorActionCell : PPPetEditorBaseCell
@end

@implementation PPPetEditorActionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (self) {
        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:48.0].active = YES;
    }
    return self;
}

@end

// ─── View Controller ──────────────────────────────────────

@interface PPPetProfileEditorViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, PHPickerViewControllerDelegate>
@property (nonatomic, strong) PPPetProfile *pet;
@property (nonatomic, strong) UITableView  *tableView;
@property (nonatomic, strong) NSMutableArray<PPPetVaccinationRecord *> *records;
@property (nonatomic, strong) UIImage      *selectedImage;
@property (nonatomic, strong) UIImageView  *heroImageView;
@property (nonatomic, strong) UIView       *headerRoot;
@property (nonatomic, strong) UIView       *headerCardView;
@property (nonatomic, strong) PPInsetLabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel      *heroTitleLabel;
@property (nonatomic, strong) UILabel      *heroSubtitleLabel;
@property (nonatomic, strong) PPInsetLabel *heroMetaLabel;
@property (nonatomic, strong) UIButton     *heroPhotoButton;
@property (nonatomic, strong) UITextField  *nameField;
@property (nonatomic, strong) UITextField  *breedField;
@property (nonatomic, strong) UITextField  *ageField;
@property (nonatomic, strong) UISwitch     *defaultSwitch;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, strong) UIView       *backgroundGlowViewTop;
@property (nonatomic, strong) UIView       *backgroundGlowViewBottom;
@property (nonatomic, strong) NSArray<UIView *> *floatingCircles;
@end

@implementation PPPetProfileEditorViewController

#pragma mark - Init

- (instancetype)initWithPet:(PPPetProfile *)pet {
    self = [super init];
    if (self) {
        _pet     = pet ?: [PPPetProfile new];
        _records = [(_pet.vaccinations ?: @[]) mutableCopy] ?: [NSMutableArray array];
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    BOOL isEdit = self.pet.petID.length > 0;
    self.title  = isEdit ? (kLang(@"pet_edit_title") ?: @"Edit Pet") : (kLang(@"pet_add_title") ?: @"Add Pet");

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

    // Table
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource          = self;
    self.tableView.delegate            = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.backgroundColor     = UIColor.clearColor;
    self.tableView.separatorStyle      = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset        = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.semanticContentAttribute = PPEditorSemanticAttr();
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:PPPetEditorFieldCell.class   forCellReuseIdentifier:@"field"];
    [self.tableView registerClass:PPPetEditorActionCell.class   forCellReuseIdentifier:@"toggle"];
    [self.tableView registerClass:PPPetEditorVaccineCell.class forCellReuseIdentifier:@"vaccine"];
    [self.tableView registerClass:PPPetEditorActionCell.class   forCellReuseIdentifier:@"addBtn"];
    [self.view addSubview:self.tableView];

    [self pp_setupBackdrop];
    [self pp_buildHeroHeader];
    [self pp_applyCanvasBackground];
    [self pp_refreshHeroHeader];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_kbChange:)
                                                 name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Appearance

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.semanticContentAttribute = PPEditorSemanticAttr();
    self.tableView.semanticContentAttribute = PPEditorSemanticAttr();
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

    UIView *avatarHalo = [[UIView alloc] init];
    avatarHalo.translatesAutoresizingMaskIntoConstraints = NO;
    avatarHalo.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.12];
    avatarHalo.layer.cornerRadius = 32.0;
    avatarHalo.layer.borderWidth = 0.0;
    [avatarHalo pp_setBorderColor:PPPetsCardOverlay(0.48)];
    [avatarHalo pp_setShadowColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.30]];
    avatarHalo.layer.shadowOpacity = 0.12;
    avatarHalo.layer.shadowRadius = 12.0;
    avatarHalo.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [cardView addSubview:avatarHalo];

    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.layer.cornerRadius = 26.0;
    self.heroImageView.layer.borderWidth = 3.0;
    [self.heroImageView pp_setBorderColor:PPPetsCardOverlay(0.86)];
    self.heroImageView.backgroundColor = UIColor.clearColor;
    self.heroImageView.tintColor = PPPetsUIBrandColor();
    self.heroImageView.userInteractionEnabled = YES;
    [avatarHalo addSubview:self.heroImageView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    titleLabel.textColor = AppPrimaryTextClr;
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

    // Pencil edit badge on avatar corner
    UIButton *photoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    photoButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *pencilCfg = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
    [photoButton setImage:[[UIImage systemImageNamed:@"pencil" withConfiguration:pencilCfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    photoButton.tintColor = UIColor.whiteColor;
    photoButton.backgroundColor = PPPetsUIBrandColor();
    photoButton.layer.cornerRadius = 12.0;
    photoButton.layer.borderWidth = 2.5;
    [photoButton pp_setBorderColor:UIColor.whiteColor];
    [photoButton pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    photoButton.layer.shadowOpacity = 0.18;
    photoButton.layer.shadowRadius = 6.0;
    photoButton.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [photoButton addTarget:self action:@selector(pp_pickPhoto) forControlEvents:UIControlEventTouchUpInside];
    [avatarHalo addSubview:photoButton];

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

        [avatarHalo.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [avatarHalo.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:12.0],
        [avatarHalo.widthAnchor constraintEqualToConstant:64.0],
        [avatarHalo.heightAnchor constraintEqualToConstant:64.0],

        [self.heroImageView.centerXAnchor constraintEqualToAnchor:avatarHalo.centerXAnchor],
        [self.heroImageView.centerYAnchor constraintEqualToAnchor:avatarHalo.centerYAnchor],
        [self.heroImageView.widthAnchor constraintEqualToConstant:52.0],
        [self.heroImageView.heightAnchor constraintEqualToConstant:52.0],

        [titleLabel.topAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:10.0],
        [metaLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:cardView.leadingAnchor constant:34.0],
        [metaLabel.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-34.0],
        [metaLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-16.0],

        [photoButton.widthAnchor constraintEqualToConstant:24.0],
        [photoButton.heightAnchor constraintEqualToConstant:24.0],
        [photoButton.trailingAnchor constraintEqualToAnchor:avatarHalo.trailingAnchor constant:-2.0],
        [photoButton.bottomAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:-2.0],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_pickPhoto)];
    [self.heroImageView addGestureRecognizer:tap];

    self.headerCardView = cardView;
    self.heroEyebrowLabel = eyebrowLabel;
    self.heroTitleLabel = titleLabel;
    self.heroSubtitleLabel = subtitleLabel;
    self.heroMetaLabel = metaLabel;
    self.heroPhotoButton = photoButton;
    self.tableView.tableHeaderView = self.headerRoot;
}

- (void)pp_refreshHeroHeader {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        name = self.pet.name.length ? self.pet.name : (kLang(@"pet_add_title") ?: @"Add Pet");
    }

    NSString *breed = [self.breedField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (breed.length == 0) {
        breed = self.pet.breed ?: @"";
    }

    NSString *ageValue = [self.ageField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSInteger months = ageValue.length ? ageValue.integerValue : self.pet.ageInMonths;
    PPPetProfile *previewPet = [PPPetProfile new];
    previewPet.name = name ?: @"";
    previewPet.ageInMonths = MAX(0, months);
    NSString *ageText = months > 0 ? [previewPet displayAgeText] : @"";

    NSMutableArray<NSString *> *subtitleParts = [NSMutableArray array];
    if (breed.length) [subtitleParts addObject:breed];
    if (ageText.length) [subtitleParts addObject:ageText];

    self.heroEyebrowLabel.text = self.pet.petID.length > 0
        ? (kLang(@"pet_edit_title") ?: @"Edit Pet")
        : (kLang(@"pet_add_title") ?: @"Add Pet");
    self.heroTitleLabel.text = name.length ? name : (kLang(@"pet_name_placeholder") ?: @"Your pet");
    self.heroSubtitleLabel.text = subtitleParts.count
        ? [subtitleParts componentsJoinedByString:@" · "]
        : (kLang(@"pet_profiles_empty_subtitle") ?: @"Shape your pet profile with a clear identity, photo, and vaccine history.");

    BOOL isDefault = self.defaultSwitch ? self.defaultSwitch.isOn : self.pet.isDefaultPet;
    NSString *defaultText = isDefault ? (kLang(@"pet_default_action") ?: @"Default pet") : (kLang(@"pet_section_vaccinations") ?: @"Vaccinations");
    self.heroMetaLabel.text = [NSString stringWithFormat:@"%ld %@ · %@",
                               (long)self.records.count,
                               (kLang(@"pet_vaccines_short") ?: @"vaccines"),
                               defaultText];

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:(name ?: @"") size:52];
    if (self.selectedImage) {
        self.heroImageView.image = self.selectedImage;
    } else {
        PPEditorLoadImage(self.heroImageView, self.pet.imageURL, placeholder);
    }

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

#pragma mark - Photo Picker

- (void)pp_handleBack {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_pickPhoto {
    PHPickerConfiguration *cfg = [[PHPickerConfiguration alloc] init];
    cfg.selectionLimit = 1;
    cfg.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:cfg];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult *result = results.firstObject;
    if (!result) return;

    __weak typeof(self) ws = self;
    [result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image, NSError *error) {
        if (![image isKindOfClass:UIImage.class]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            ws.selectedImage = image;
            ws.heroImageView.image = image;
            [ws pp_refreshHeroHeader];
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return PPEditorSectionCount;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPEditorSectionSettings || indexPath.section == PPEditorSectionVaccinations) {
            return 60.0;
    }
    if (indexPath.section == PPEditorSectionInfo) {
            return 96.0;
    }
    return UITableViewAutomaticDimension;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case PPEditorSectionPhoto:        return 0;
        case PPEditorSectionInfo:         return PPEditorInfoRowCount;
        case PPEditorSectionSettings:     return 1;
        case PPEditorSectionVaccinations: return (NSInteger)self.records.count + 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil; // Custom header views used instead
}

#pragma mark - Section Header (ProfileVC accent-bar pattern)

- (UIView *)pp_sectionHeaderWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    return PPPetsBuildSectionHeaderView(title, subtitle);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    switch (section) {
        case PPEditorSectionInfo:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_section_info") ?: @"Basic Info")
                                         subtitle:(kLang(@"pet_section_info_hint") ?: @"Name, breed, and age help the profile feel complete at a glance.")];
        case PPEditorSectionSettings:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_section_settings") ?: @"Settings")
                                         subtitle:(kLang(@"pet_section_settings_hint") ?: @"Choose whether this profile should lead the rest of the pet experience.")];
        case PPEditorSectionVaccinations:
            return [self pp_sectionHeaderWithTitle:(kLang(@"pet_section_vaccinations") ?: @"Vaccinations")
                                         subtitle:(kLang(@"pet_section_vaccinations_hint") ?: @"Keep quick history notes so reminders and care decisions stay easy to scan.")];
        default:
            return [UIView new];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    switch (section) {
        case PPEditorSectionInfo:
        case PPEditorSectionSettings:
        case PPEditorSectionVaccinations:
            return 76.0;
        default:
            return 0.000001;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.000001;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView heightForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section {
    return 0.000001;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {

        case PPEditorSectionInfo: {
            PPPetEditorFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"field" forIndexPath:indexPath];
            switch (indexPath.row) {
                case PPEditorInfoRowName:
                    [cell configureWithTitle:(kLang(@"pet_field_name") ?: @"Pet Name")
                                       text:self.pet.name
                                placeholder:(kLang(@"pet_name_placeholder") ?: @"Enter pet name")
                               keyboardType:UIKeyboardTypeDefault
                                  fieldKind:PPEditorFieldName
                                     target:self action:@selector(pp_fieldChanged:) delegate:self];
                    self.nameField = cell.textField;
                    break;
                case PPEditorInfoRowBreed:
                    [cell configureWithTitle:(kLang(@"pet_field_breed") ?: @"Breed")
                                       text:self.pet.breed
                                placeholder:(kLang(@"pet_breed_placeholder") ?: @"Enter breed")
                               keyboardType:UIKeyboardTypeDefault
                                  fieldKind:PPEditorFieldBreed
                                     target:self action:@selector(pp_fieldChanged:) delegate:self];
                    self.breedField = cell.textField;
                    break;
                case PPEditorInfoRowAge:
                    [cell configureWithTitle:(kLang(@"pet_field_age") ?: @"Age (months)")
                                       text:(self.pet.ageInMonths > 0 ? [@(self.pet.ageInMonths) stringValue] : @"")
                                placeholder:(kLang(@"pet_age_months_placeholder") ?: @"Age in months")
                               keyboardType:UIKeyboardTypeNumberPad
                                  fieldKind:PPEditorFieldAge
                                     target:self action:@selector(pp_fieldChanged:) delegate:self];
                    self.ageField = cell.textField;
                    break;
            }
            return cell;
        }

        case PPEditorSectionSettings: {
            PPPetEditorActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"toggle" forIndexPath:indexPath];
            cell.textLabel.text          = kLang(@"pet_default_toggle") ?: @"Set as default pet";
            cell.textLabel.font          = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
            cell.textLabel.textColor     = AppPrimaryTextClr;
            cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;
            cell.selectionStyle          = UITableViewCellSelectionStyleNone;
            cell.imageView.image         = [[UIImage systemImageNamed:@"star.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            cell.imageView.tintColor     = UIColor.systemYellowColor;

            if (!self.defaultSwitch) {
                self.defaultSwitch = [UISwitch new];
                self.defaultSwitch.onTintColor = PPPetsUIBrandColor();
                self.defaultSwitch.on = self.pet.isDefaultPet;
                [self.defaultSwitch addTarget:self action:@selector(pp_defaultSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            }
            cell.accessoryView = self.defaultSwitch;
            return cell;
        }

        case PPEditorSectionVaccinations: {
            if (indexPath.row < (NSInteger)self.records.count) {
                PPPetEditorVaccineCell *cell = [tableView dequeueReusableCellWithIdentifier:@"vaccine" forIndexPath:indexPath];
                [cell configureWithRecord:self.records[indexPath.row]];
                __weak typeof(self) ws = self;
                NSInteger idx = indexPath.row;
                cell.onDelete = ^{ [ws pp_deleteVaccineAtIndex:idx]; };
                return cell;
            } else {
                PPPetEditorActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"addBtn" forIndexPath:indexPath];
                cell.textLabel.text          = kLang(@"pet_vaccine_add") ?: @"Add Vaccination Record";
                cell.textLabel.font          = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
                cell.textLabel.textColor     = PPPetsUIBrandColor();
                cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;
                cell.imageView.image         = [[UIImage systemImageNamed:@"plus.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                cell.imageView.tintColor     = PPPetsUIBrandColor();
                return cell;
            }
        }

        default: return [UITableViewCell new];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == PPEditorSectionVaccinations) {
        if (indexPath.row >= (NSInteger)self.records.count) {
            [self pp_addVaccination];
        } else {
            [self pp_editVaccineAtIndex:indexPath.row];
        }
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    PPPetsApplySurfaceCellStyle(cell, 20.0);
}

#pragma mark - Vaccinations

- (void)pp_addVaccination {
    __weak typeof(self) ws = self;
    [PPVaccinationEditorSheet presentFromViewController:self
                                             withRecord:nil
                                             completion:^(PPPetVaccinationRecord *rec, BOOL saved) {
        if (!saved || !rec) return;
        [ws.records addObject:rec];
        CGPoint savedOffset = ws.tableView.contentOffset;
        [UIView performWithoutAnimation:^{
            [ws.tableView reloadSections:[NSIndexSet indexSetWithIndex:PPEditorSectionVaccinations]
                        withRowAnimation:UITableViewRowAnimationNone];
        }];
        [ws.tableView layoutIfNeeded];
        ws.tableView.contentOffset = savedOffset;
        [ws pp_refreshHeroHeader];
    }];
}

- (void)pp_editVaccineAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= (NSInteger)self.records.count) return;
    PPPetVaccinationRecord *rec = self.records[idx];

    __weak typeof(self) ws = self;
    [PPVaccinationEditorSheet presentFromViewController:self
                                             withRecord:rec
                                             completion:^(PPPetVaccinationRecord *updatedRec, BOOL saved) {
        if (!saved) return;
        CGPoint savedOffset = ws.tableView.contentOffset;
        [UIView performWithoutAnimation:^{
            [ws.tableView reloadSections:[NSIndexSet indexSetWithIndex:PPEditorSectionVaccinations]
                        withRowAnimation:UITableViewRowAnimationNone];
        }];
        [ws.tableView layoutIfNeeded];
        ws.tableView.contentOffset = savedOffset;
        [ws pp_refreshHeroHeader];
    }];
}

- (void)pp_deleteVaccineAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= (NSInteger)self.records.count) return;
    [self.records removeObjectAtIndex:idx];
    CGPoint savedOffset = self.tableView.contentOffset;
    [UIView performWithoutAnimation:^{
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:PPEditorSectionVaccinations]
                      withRowAnimation:UITableViewRowAnimationNone];
    }];
    [self.tableView layoutIfNeeded];
    self.tableView.contentOffset = savedOffset;
    [self pp_refreshHeroHeader];
}

#pragma mark - Save

- (void)pp_save {
    if (self.isSaving) return;

    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        // Shake animation
        CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
        shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        shake.duration = 0.4;
        shake.values   = @[@(-8), @(8), @(-6), @(6), @(-4), @(4), @0];
        [self.nameField.layer addAnimation:shake forKey:@"shake"];

        [PPHUD showError:(kLang(@"pet_name_required") ?: @"Name Required")
                subtitle:(kLang(@"pet_name_required_msg") ?: @"Please enter your pet's name")];
        return;
    }

    self.isSaving = YES;
    self.pet.name         = name;
    self.pet.breed        = self.breedField.text ?: @"";
    self.pet.ageInMonths  = MAX(0, self.ageField.text.integerValue);
    self.pet.isDefaultPet = self.defaultSwitch.isOn;
    self.pet.vaccinations = self.records.copy;

    [PPHUD showIndeterminateIn:self.view title:(kLang(@"please_wait") ?: @"Saving…") subtitle:nil];

    __weak typeof(self) ws = self;
    void (^persist)(void) = ^{
        [[UserManager sharedManager] savePetProfile:ws.pet completion:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.isSaving = NO;
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
    };

    if (self.selectedImage) {
        NSString *petID = self.pet.petID.length ? self.pet.petID : [NSUUID UUID].UUIDString;
        self.pet.petID = petID;
        [[UserManager sharedManager] uploadPetImage:self.selectedImage petID:petID completion:^(NSString *imageURL, NSError *error) {
            if (imageURL.length) ws.pet.imageURL = imageURL;
            persist();
        }];
    } else {
        persist();
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)pp_fieldChanged:(UITextField *)field {
    [self pp_refreshHeroHeader];
}

- (void)pp_defaultSwitchChanged:(UISwitch *)sender {
    [self pp_refreshHeroHeader];
}

#pragma mark - Keyboard

- (void)pp_kbChange:(NSNotification *)note {
    CGRect frame       = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration   = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat bottomGap  = self.view.bounds.size.height - frame.origin.y;

    [UIView animateWithDuration:duration animations:^{
        self.tableView.contentInset          = UIEdgeInsetsMake(6.0, 0.0, MAX(24.0, bottomGap), 0.0);
        self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
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
