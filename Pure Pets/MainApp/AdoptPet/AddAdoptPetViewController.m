//
//  AddAdoptPetViewController.m
//  Pure Pets
//
//  Adopt create/edit form — modern UITableView (no XLForm).
//

#import "AddAdoptPetViewController.h"
#import "AdoptPetManager.h"
#import "PPImageCollection.h"
#import "PPAlertHelper.h"
#import "PPSelectOptionViewController.h"

#ifdef DEBUG
#define PPAdoptLog(fmt, ...) NSLog((@"[AdoptPetForm] " fmt), ##__VA_ARGS__)
#else
#define PPAdoptLog(...)
#endif

static NSString * const kRowName      = @"name";
static NSString * const kRowSpecies   = @"species";
static NSString * const kRowBreed     = @"breed";
static NSString * const kRowAgeMonths = @"ageMonths";
static NSString * const kRowGender    = @"gender";
static NSString * const kRowCity      = @"city";
static NSString * const kRowDetails   = @"details";
static NSString * const kAdoptDraftDefaultsPrefix  = @"pp.add_adopt_pet.draft";
static NSString * const kAdoptDraftFormDataKey      = @"formData";
static NSString * const kAdoptDraftImagePathsKey    = @"imagePaths";

static CGFloat const kAdoptMediaFooterHeight = 236.0;
static CGFloat const kAdoptMediaInset        = 16.0;

static inline NSString *PPAdoptSafeString(id value) {
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static const CGFloat kPPAdoptFormCellHInset = 20.0;
static const CGFloat kPPAdoptFormCellVInset = 10.0;

static inline UISemanticContentAttribute PPAdoptCurrentSemanticAttribute(void) {
    return Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

#pragma mark - PPAdoptFormBaseCell

@interface PPAdoptFormBaseCell : UITableViewCell
@end

@implementation PPAdoptFormBaseCell

- (void)setFrame:(CGRect)frame {
    frame.origin.x   = kPPAdoptFormCellHInset;
    frame.size.width -= kPPAdoptFormCellHInset * 2.0;
    frame.origin.y   += kPPAdoptFormCellVInset * 0.5;
    frame.size.height -= kPPAdoptFormCellVInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

@end

#pragma mark - PPAdoptFormTextFieldCell

@interface PPAdoptFormTextFieldCell : PPAdoptFormBaseCell
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UITextField *textField;
- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType
                    target:(id)target
                    action:(SEL)action;
@end

@implementation PPAdoptFormTextFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;
    self.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = UIColor.clearColor;
    textField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textField.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.adjustsFontSizeToFitWidth = NO;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.textAlignment = Language.alignmentForCurrentLanguage;
    textField.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    [self.contentView addSubview:textField];
    self.textField = textField;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:12.0],
        [titleLabel.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor   constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor  constant:-18.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        [textField.topAnchor      constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [textField.leadingAnchor  constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textField.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        [textField.heightAnchor   constraintGreaterThanOrEqualToConstant:24.0]
    ]];

    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
}

- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType
                    target:(id)target
                    action:(SEL)action {
    self.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.text = text ?: @"";
    self.textField.placeholder = placeholder ?: @"";
    self.textField.keyboardType = keyboardType;
    self.textField.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end

#pragma mark - PPAdoptFormSelectorCell

@interface PPAdoptFormSelectorCell : PPAdoptFormBaseCell
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UILabel     *valueLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithTitle:(NSString *)title value:(NSString *)value;
@end

@implementation PPAdoptFormSelectorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    valueLabel.numberOfLines = 2;
    [self.contentView addSubview:valueLabel];
    self.valueLabel = valueLabel;

    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.8];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:chevronView];
    self.chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:14.0],
        [titleLabel.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor   constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor  constant:-18.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        [chevronView.centerYAnchor  constraintEqualToAnchor:self.contentView.centerYAnchor constant:10.0],
        [chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [chevronView.widthAnchor    constraintEqualToConstant:14.0],
        [chevronView.heightAnchor   constraintEqualToConstant:14.0],

        [valueLabel.topAnchor      constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [valueLabel.leadingAnchor  constraintEqualToAnchor:titleLabel.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-12.0],
        [valueLabel.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title value:(NSString *)value {
    self.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.valueLabel.text = value ?: @"";
    self.valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
}

@end

#pragma mark - PPAdoptFormTextViewCell

@interface PPAdoptFormTextViewCell : PPAdoptFormBaseCell
@property (nonatomic, strong) UILabel    *titleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel    *placeholderLabel;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                  delegate:(id<UITextViewDelegate>)delegate;
- (void)updatePreferredHeight;
- (void)updatePlaceholderVisibility;
@end

@implementation PPAdoptFormTextViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.backgroundColor = UIColor.clearColor;
    textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textView.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    textView.scrollEnabled = NO;
    textView.textContainerInset = UIEdgeInsetsZero;
    textView.textContainer.lineFragmentPadding = 0.0;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.textAlignment = Language.alignmentForCurrentLanguage;
    textView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    [self.contentView addSubview:textView];
    self.textView = textView;

    UILabel *placeholderLabel = [[UILabel alloc] init];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = textView.font;
    placeholderLabel.textColor = UIColor.placeholderTextColor;
    placeholderLabel.numberOfLines = 0;
    placeholderLabel.userInteractionEnabled = NO;
    [self.contentView addSubview:placeholderLabel];
    self.placeholderLabel = placeholderLabel;

    NSLayoutConstraint *heightConstraint = [textView.heightAnchor constraintGreaterThanOrEqualToConstant:116.0];
    heightConstraint.active = YES;
    self.textViewHeightConstraint = heightConstraint;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:14.0],
        [titleLabel.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor   constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor  constant:-18.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        [textView.topAnchor      constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [textView.leadingAnchor  constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textView.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [placeholderLabel.topAnchor     constraintEqualToAnchor:textView.topAnchor],
        [placeholderLabel.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:2.0],
        [placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:textView.trailingAnchor]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                  delegate:(id<UITextViewDelegate>)delegate {
    self.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.delegate = delegate;
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    self.textView.text = text ?: @"";
    self.placeholderLabel.text = placeholder ?: @"";
    self.placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self updatePlaceholderVisibility];
    [self updatePreferredHeight];
}

- (void)updatePreferredHeight {
    CGFloat fittingWidth = CGRectGetWidth(self.textView.bounds);
    if (fittingWidth <= 1.0) {
        fittingWidth = UIScreen.mainScreen.bounds.size.width - 72.0;
    }
    CGSize targetSize = CGSizeMake(MAX(120.0, fittingWidth), CGFLOAT_MAX);
    CGFloat preferredHeight = ceil([self.textView sizeThatFits:targetSize].height);
    self.textViewHeightConstraint.constant = MAX(116.0, preferredHeight);
}

- (void)updatePlaceholderVisibility {
    self.placeholderLabel.hidden = self.textView.text.length > 0;
}

@end

#pragma mark - AddAdoptPetViewController

@interface AddAdoptPetViewController () <UITableViewDataSource, UITableViewDelegate,
                                         UITextFieldDelegate, UITextViewDelegate,
                                         PPImageCollectionDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, copy)   NSString       *draftName;
@property (nonatomic, strong) MainKindsModel *draftMainKind;
@property (nonatomic, strong) SubKindModel   *draftSubKind;
@property (nonatomic, assign) NSInteger       draftAgeMonths;
@property (nonatomic, copy)   NSString       *draftGender;
@property (nonatomic, strong) CityModel      *draftCity;
@property (nonatomic, copy)   NSString       *draftDetails;

@property (nonatomic, strong) MainKindsModel *selectedMainKindModel;
@property (nonatomic, strong) SubKindModel   *selectedSubKindModel;
@property (nonatomic, strong) CityModel      *selectedCity;

@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL isPrefillInProgress;

@property (nonatomic, strong) PPImageCollection      *imageCollection;
@property (nonatomic, strong) UIView                 *imageFooterContainer;
@property (nonatomic, strong) UIView                 *prefillLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *prefillLoadingSpinner;
@property (nonatomic, strong) UILabel                *prefillLoadingLabel;
@property (nonatomic, strong) UIBarButtonItem        *saveBarButton;
@property (nonatomic, strong) UIButton               *saveButtonView;
@property (nonatomic, strong) UIActivityIndicatorView *saveActivityIndicator;
@property (nonatomic, assign) BOOL hasUserModifiedForm;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, copy, nullable) dispatch_block_t saveTimeoutBlock;
@end

@implementation AddAdoptPetViewController

- (instancetype)initWithPet:(AdoptPetModel *)pet {
    self = [super init];
    if (self) {
        _editingPet = pet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.isHydratingFormData = YES;
    self.hasUserModifiedForm = NO;

    [self setNavButtons];
    [self pp_buildTableView];
    [self setupImageCollection];
    [self setupPrefillLoadingUI];
    if (![self restoreDraftIfNeeded]) {
        [self preloadFormIfEditing];
    }
    self.isHydratingFormData = NO;
    [self pp_refreshTitle];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_setPremiumTabDockHidden:YES animated:animated];
    [self pp_refreshTitle];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    BOOL exiting = self.isMovingFromParentViewController || self.isBeingDismissed || self.navigationController.isBeingDismissed;
    if (exiting) {
        [self pp_setPremiumTabDockHidden:NO animated:animated];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateImageFooterLayoutIfNeeded];
}

- (void)pp_setPremiumTabDockHidden:(BOOL)hidden animated:(BOOL)animated
{
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)self.tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
    }
}

- (void)setDraftMainKind:(MainKindsModel *)draftMainKind {
    _draftMainKind = draftMainKind;
    _selectedMainKindModel = draftMainKind;
}

- (void)setDraftSubKind:(SubKindModel *)draftSubKind {
    _draftSubKind = draftSubKind;
    _selectedSubKindModel = draftSubKind;
}

- (void)setDraftCity:(CityModel *)draftCity {
    _draftCity = draftCity;
    _selectedCity = draftCity;
}

#pragma mark - Build Table View

- (void)pp_buildTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate   = self;
    tableView.dataSource = self;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.showsVerticalScrollIndicator   = NO;
    tableView.showsHorizontalScrollIndicator = NO;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.rowHeight          = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 84.0;
    tableView.backgroundColor    = UIColor.clearColor;
    tableView.contentInset          = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    tableView.scrollIndicatorInsets = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }

    [tableView registerClass:PPAdoptFormTextFieldCell.class forCellReuseIdentifier:@"PPAdoptFormTextFieldCell"];
    [tableView registerClass:PPAdoptFormSelectorCell.class  forCellReuseIdentifier:@"PPAdoptFormSelectorCell"];
    [tableView registerClass:PPAdoptFormTextViewCell.class  forCellReuseIdentifier:@"PPAdoptFormTextViewCell"];

    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor  constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor   constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.tableView = tableView;
}

#pragma mark - Draft Storage

- (NSString *)draftStorageKey {
    NSString *currentUserID = PPAdoptSafeString(UserManager.sharedManager.currentUser.ID);
    if (self.editingPet.documentID.length > 0) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@",
                kAdoptDraftDefaultsPrefix,
                self.editingPet.documentID,
                currentUserID];
    }
    return [NSString stringWithFormat:@"%@.create.%@",
            kAdoptDraftDefaultsPrefix,
            currentUserID];
}

- (NSString *)draftDirectoryPath {
    NSString *draftID = [[[self draftStorageKey]
                          stringByReplacingOccurrencesOfString:@"." withString:@"_"]
                         stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pp_form_drafts"];
    return [root stringByAppendingPathComponent:draftID];
}

- (BOOL)hasSavedDraft {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]] isKindOfClass:NSDictionary.class];
}

- (NSData *)archivedDraftDataForObject:(id)object {
    if (!object) return nil;
    if (@available(iOS 11.0, *)) {
        return [NSKeyedArchiver archivedDataWithRootObject:object
                                     requiringSecureCoding:NO
                                                     error:nil];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedArchiver archivedDataWithRootObject:object];
#pragma clang diagnostic pop
}

- (id)unarchivedDraftObjectFromData:(NSData *)data {
    if (![data isKindOfClass:NSData.class] || data.length == 0) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}

- (NSDictionary *)draftFormDataSnapshot {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];

    NSString *name = [PPAdoptSafeString(self.draftName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length) snapshot[kRowName] = name;
    if (self.draftMainKind.ID > 0) snapshot[kRowSpecies] = @(self.draftMainKind.ID);
    if (self.draftSubKind.ID > 0)  snapshot[kRowBreed]   = @(self.draftSubKind.ID);
    if (self.draftAgeMonths > 0)   snapshot[kRowAgeMonths] = @(self.draftAgeMonths);

    NSString *gender = [self pp_normalizedGenderFromFormValue:self.draftGender];
    if (gender.length) snapshot[kRowGender] = gender;
    if (self.draftCity.cityID > 0) snapshot[kRowCity] = @(self.draftCity.cityID);

    NSString *details = [PPAdoptSafeString(self.draftDetails) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (details.length) snapshot[kRowDetails] = details;

    return snapshot.copy;
}

- (NSString *)writeDraftImage:(UIImage *)image
                        named:(NSString *)fileName
                    directory:(NSString *)directory {
    if (!image || fileName.length == 0 || directory.length == 0) return nil;
    NSData *imageData = UIImageJPEGRepresentation(image, 0.88);
    if (!imageData) imageData = UIImagePNGRepresentation(image);
    if (!imageData) return nil;
    NSString *path = [directory stringByAppendingPathComponent:fileName];
    return [imageData writeToFile:path atomically:YES] ? path : nil;
}

- (NSArray<NSString *> *)writeDraftImages:(NSArray<UIImage *> *)images
                               withPrefix:(NSString *)prefix
                                directory:(NSString *)directory {
    if (images.count == 0) return @[];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    [images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {
        (void)stop;
        NSString *fileName = [NSString stringWithFormat:@"%@_%lu.jpg", prefix, (unsigned long)idx];
        NSString *path = [self writeDraftImage:image named:fileName directory:directory];
        if (path.length) [paths addObject:path];
    }];
    return paths.copy;
}

- (NSArray<UIImage *> *)imagesFromDraftPaths:(NSArray<NSString *> *)paths {
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    for (NSString *path in paths) {
        if (![path isKindOfClass:NSString.class] || path.length == 0) continue;
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) [images addObject:image];
    }
    return images.copy;
}

- (void)clearSavedDraft {
    [[NSFileManager defaultManager] removeItemAtPath:[self draftDirectoryPath] error:nil];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs removeObjectForKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)saveDraftForLater {
    NSDictionary *snapshot = [self draftFormDataSnapshot];
    NSData *formData = [self archivedDraftDataForObject:snapshot];
    if (!formData) return;

    NSString *directory = [self draftDirectoryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:directory error:nil];
    [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray<NSString *> *imagePaths = [self writeDraftImages:[self.imageCollection allImages] ?: @[]
                                                  withPrefix:@"media"
                                                   directory:directory];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[kAdoptDraftFormDataKey]   = formData;
    payload[kAdoptDraftImagePathsKey] = imagePaths ?: @[];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (BOOL)restoreDraftIfNeeded {
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) return NO;

    NSDictionary *storedValues = [self unarchivedDraftObjectFromData:payload[kAdoptDraftFormDataKey]];
    if (![storedValues isKindOfClass:NSDictionary.class]) {
        [self clearSavedDraft];
        return NO;
    }

    self.isHydratingFormData = YES;

    self.draftName = PPAdoptSafeString(storedValues[kRowName]);

    NSNumber *speciesID = storedValues[kRowSpecies];
    if ([speciesID respondsToSelector:@selector(integerValue)]) {
        self.draftMainKind = [MainKindsModel mainKindClassForID:speciesID.integerValue
                                                         inArray:MKM.MainKindsArray];
    }

    NSNumber *breedID = storedValues[kRowBreed];
    if ([breedID respondsToSelector:@selector(integerValue)] && self.draftMainKind) {
        self.draftSubKind = [self.draftMainKind subKindForID:breedID.integerValue];
    }

    if ([storedValues[kRowAgeMonths] respondsToSelector:@selector(integerValue)]) {
        self.draftAgeMonths = [storedValues[kRowAgeMonths] integerValue];
    }

    NSString *gender = PPAdoptSafeString(storedValues[kRowGender]);
    if (gender.length) {
        self.draftGender = [self pp_displayGenderForStoredValue:gender];
    }

    NSNumber *cityID = storedValues[kRowCity];
    if ([cityID respondsToSelector:@selector(integerValue)] && cityID.integerValue > 0) {
        self.draftCity = [CitiesManager.shared cityByID:cityID.integerValue];
    }

    self.draftDetails = PPAdoptSafeString(storedValues[kRowDetails]);

    NSArray<UIImage *> *draftImages = [self imagesFromDraftPaths:payload[kAdoptDraftImagePathsKey]];
    [self.imageCollection clearAllImages];
    if (draftImages.count > 0) {
        [self.imageCollection addImages:draftImages];
    }

    self.hasUserModifiedForm = NO;
    self.isHydratingFormData = NO;
    [self.tableView reloadData];
    return YES;
}

#pragma mark - Navigation / Dismiss

- (BOOL)pp_shouldPromptForDraftOptions {
    return self.hasUserModifiedForm || [self hasSavedDraft];
}

- (void)pp_dismissForm {
    BOOL isRootOfPresentedNav = (self.navigationController.presentingViewController != nil &&
                                 self.navigationController.viewControllers.firstObject == self);
    if (isRootOfPresentedNav) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)presentUnsavedChangesPrompt {
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showThreeActionConfirmationIn:self
                                           title:kLang(@"form_draft_prompt_title")
                                        subtitle:kLang(@"form_draft_prompt_message")
                                   primaryButton:kLang(@"form_draft_save_and_close")
                                    primaryStyle:UIAlertActionStyleDefault
                                 secondaryButton:kLang(@"form_draft_discard")
                                  secondaryStyle:UIAlertActionStyleDestructive
                                  tertiaryButton:kLang(@"form_draft_keep_editing")
                                   tertiaryStyle:UIAlertActionStyleCancel
                                    primaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf saveDraftForLater];
        [strongSelf pp_dismissForm];
    } secondaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf clearSavedDraft];
        [strongSelf pp_dismissForm];
    } tertiaryBlock:^{
    }];
}

#pragma mark - UI

- (void)pp_refreshTitle {
    self.title = self.editingPet ? kLang(@"editAdoptPet") : kLang(@"addPetForAdoption");
}

- (void)setNavButtons {
    self.saveButtonView = [PPButtonHelper pp_buttonWithTitle:kLang(@"save") font:[GM fontWithSize:17] imageName:@"" target:self config:[UIButtonConfiguration tintedButtonConfiguration] action:@selector(saveTapped)];
    self.saveBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.saveButtonView];

    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:kLang(@"cancel")
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(cancelTapped)];
    [cancelBtn setTitleTextAttributes:@{
        NSFontAttributeName : [GM MidFontWithSize:16],
        NSForegroundColorAttributeName : GM.SecondaryTextColor
    } forState:UIControlStateNormal];

    self.navigationItem.rightBarButtonItem = self.saveBarButton;
    self.navigationItem.leftBarButtonItem  = cancelBtn;

    self.saveActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.saveActivityIndicator.hidesWhenStopped = YES;
}

- (void)cancelTapped {
    if (self.isSaving) return;
    [self.view endEditing:YES];
    if ([self pp_shouldPromptForDraftOptions]) {
        [self presentUnsavedChangesPrompt];
        return;
    }
    [self pp_dismissForm];
}

#pragma mark - Image Collection

- (void)setupImageCollection {
    if (self.imageCollection) return;

    self.imageCollection = [[PPImageCollection alloc] initWithFrame:CGRectZero
                                                       maxImageCount:15
                                                           useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.useArabic = Language.isRTL;
    self.imageCollection.titleText = kLang(@"photos");
    [self.imageCollection setTitle:kLang(@"photos") icon:nil];

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, kAdoptMediaFooterHeight)];
    footer.backgroundColor = UIColor.clearColor;
    [footer addSubview:self.imageCollection];
    self.imageFooterContainer = footer;
    self.tableView.tableFooterView = footer;
    [self pp_updateImageFooterLayoutIfNeeded];
}

- (void)pp_updateImageFooterLayoutIfNeeded {
    if (!self.imageFooterContainer || !self.imageCollection) return;
    CGFloat tableWidth = self.tableView.bounds.size.width;
    if (tableWidth <= 0) return;

    CGRect footerFrame = self.imageFooterContainer.frame;
    footerFrame.size.width  = tableWidth;
    footerFrame.size.height = kAdoptMediaFooterHeight;
    self.imageFooterContainer.frame = footerFrame;

    CGFloat collectionWidth = MAX(0, tableWidth - (kAdoptMediaInset * 2.0));
    self.imageCollection.frame = CGRectMake(kAdoptMediaInset, 10, collectionWidth, kAdoptMediaFooterHeight - 16);
    self.tableView.tableFooterView = self.imageFooterContainer;
}

#pragma mark - Prefill Loading UI

- (void)setupPrefillLoadingUI {
    self.prefillLoadingView = [[UIView alloc] init];
    self.prefillLoadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.58];
    self.prefillLoadingView.layer.cornerRadius  = 12;
    self.prefillLoadingView.layer.masksToBounds = YES;
    self.prefillLoadingView.hidden = YES;

    self.prefillLoadingSpinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.prefillLoadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingSpinner.color = UIColor.whiteColor;

    self.prefillLoadingLabel = [[UILabel alloc] init];
    self.prefillLoadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingLabel.font      = [GM MidFontWithSize:12];
    self.prefillLoadingLabel.textColor = UIColor.whiteColor;
    self.prefillLoadingLabel.text      = kLang(@"loading_images");

    [self.prefillLoadingView addSubview:self.prefillLoadingSpinner];
    [self.prefillLoadingView addSubview:self.prefillLoadingLabel];
    [self.view addSubview:self.prefillLoadingView];

    [NSLayoutConstraint activateConstraints:@[
        [self.prefillLoadingView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.prefillLoadingView.bottomAnchor  constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-22],
        [self.prefillLoadingSpinner.leadingAnchor constraintEqualToAnchor:self.prefillLoadingView.leadingAnchor constant:10],
        [self.prefillLoadingSpinner.centerYAnchor constraintEqualToAnchor:self.prefillLoadingView.centerYAnchor],
        [self.prefillLoadingLabel.leadingAnchor  constraintEqualToAnchor:self.prefillLoadingSpinner.trailingAnchor constant:8],
        [self.prefillLoadingLabel.trailingAnchor constraintEqualToAnchor:self.prefillLoadingView.trailingAnchor constant:-10],
        [self.prefillLoadingLabel.topAnchor      constraintEqualToAnchor:self.prefillLoadingView.topAnchor constant:8],
        [self.prefillLoadingLabel.bottomAnchor   constraintEqualToAnchor:self.prefillLoadingView.bottomAnchor constant:-8]
    ]];
}

- (void)setPrefillLoadingVisible:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.prefillLoadingView.hidden = !visible;
        if (visible) {
            [self.prefillLoadingSpinner startAnimating];
        } else {
            [self.prefillLoadingSpinner stopAnimating];
        }
    });
}

#pragma mark - Prefill Editing

- (void)preloadFormIfEditing {
    if (!self.editingPet) return;

    self.draftMainKind  = self.editingPet.mainKindModel ?: [MainKindsModel mainKindClassForID:self.editingPet.kindID
                                                                                        inArray:MKM.MainKindsArray];
    self.draftSubKind   = self.editingPet.subKindModel  ?: [self.draftMainKind subKindForID:self.editingPet.breedID];
    self.draftCity      = [CitiesManager.shared cityByID:self.editingPet.cityID];
    self.draftName      = self.editingPet.name;
    self.draftAgeMonths = self.editingPet.ageMonths;
    self.draftGender    = [self pp_displayGenderForStoredValue:self.editingPet.gender];
    self.draftDetails   = self.editingPet.details;

    [self.tableView reloadData];

    if (self.editingPet.imageURLs.count > 0) {
        self.isPrefillInProgress = YES;
        [self setPrefillLoadingVisible:YES];
        __weak typeof(self) weakSelf = self;
        [self.imageCollection preloadImagesFromURLs:self.editingPet.imageURLs completion:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.isPrefillInProgress = NO;
            [strongSelf setPrefillLoadingVisible:NO];
        }];
    }
}

#pragma mark - Save Timeout Protection

- (void)pp_cancelSaveTimeout {
    if (self.saveTimeoutBlock) {
        dispatch_block_cancel(self.saveTimeoutBlock);
        self.saveTimeoutBlock = nil;
    }
}

- (void)pp_scheduleSaveTimeout {
    [self pp_cancelSaveTimeout];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.saveTimeoutBlock = nil;

        if (strongSelf.isSaving) {
            [strongSelf pp_resetSaveButton];
            [GM ActivityLoadingAnimationView:NO onView:strongSelf.tableView];
            strongSelf.isSaving = NO;
            [strongSelf pp_showSaveTimeoutError];
        }
    });
    self.saveTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);
}

- (void)pp_showSaveTimeoutError {
    if (self.presentedViewController) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"upload_timeout_title")
                                                                  message:kLang(@"save_timeout_message")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"KLang_Retry")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [weakSelf saveTapped];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Validation

- (void)pp_shakeCell:(UITableViewCell *)cell {
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animation];
    anim.keyPath  = @"position.x";
    anim.values   = @[@0, @20, @-20, @10, @0];
    anim.keyTimes = @[@0, @(1/6.0), @(3/6.0), @(5/6.0), @1];
    anim.duration = 0.3;
    anim.additive = YES;
    [cell.layer addAnimation:anim forKey:@"shake"];
}

- (void)pp_resetSaveButton {
    self.saveBarButton.enabled    = YES;
    self.saveBarButton.customView = self.saveButtonView;
    [self.saveActivityIndicator stopAnimating];
}

#pragma mark - Save

- (void)saveTapped {
    if (self.isSaving) return;

    self.saveBarButton.enabled = NO;
    [self.saveActivityIndicator startAnimating];
    self.saveBarButton.customView = self.saveActivityIndicator;
    [self.view endEditing:YES];

    NSString *name = [PPAdoptSafeString(self.draftName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSIndexPath *firstInvalidIP = nil;

    if (name.length == 0 && !firstInvalidIP)          firstInvalidIP = [NSIndexPath indexPathForRow:0 inSection:0];
    if (!self.draftMainKind && !firstInvalidIP)        firstInvalidIP = [NSIndexPath indexPathForRow:1 inSection:0];
    if (!self.draftSubKind && !firstInvalidIP)         firstInvalidIP = [NSIndexPath indexPathForRow:2 inSection:0];
    if (self.draftAgeMonths <= 0 && !firstInvalidIP)   firstInvalidIP = [NSIndexPath indexPathForRow:3 inSection:0];
    if (self.draftGender.length == 0 && !firstInvalidIP) firstInvalidIP = [NSIndexPath indexPathForRow:0 inSection:1];
    if (!self.draftCity && !firstInvalidIP)            firstInvalidIP = [NSIndexPath indexPathForRow:1 inSection:1];

    NSArray<UIImage *> *images = [self.imageCollection allImages] ?: @[];
    BOOL hasExistingURLs = self.editingPet.imageURLs.count > 0;

    if (!self.editingPet && images.count == 0) {
        [self pp_resetSaveButton];
        [self showErrorMessage:kLang(@"pleaseSelectAtLeastOnePhoto")];
        return;
    }
    if (self.editingPet && images.count == 0 && !hasExistingURLs) {
        [self pp_resetSaveButton];
        [self showErrorMessage:kLang(@"pleaseSelectAtLeastOnePhoto")];
        return;
    }

    if (firstInvalidIP) {
        [self pp_resetSaveButton];
        [self.tableView scrollToRowAtIndexPath:firstInvalidIP atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:firstInvalidIP];
            if (cell) [self pp_shakeCell:cell];
        });
        [self showErrorMessage:kLang(@"adopt_form_required_fields_error")];
        return;
    }

    [self persistFormWithImages:images];
}

- (AdoptPetModel *)buildModelFromForm {
    AdoptPetModel *model = [[AdoptPetModel alloc] init];
    model.documentID = self.editingPet.documentID ?: @"";
    model.name       = [PPAdoptSafeString(self.draftName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    model.kindID     = self.draftMainKind.ID;
    model.breedID    = self.draftSubKind.ID;
    model.ageMonths  = self.draftAgeMonths;
    model.gender     = [self pp_normalizedGenderFromFormValue:self.draftGender];
    model.cityID     = self.draftCity.cityID;
    model.details    = PPAdoptSafeString(self.draftDetails);
    NSString *ownerID = self.editingPet.ownerID.length > 0 ? self.editingPet.ownerID : UserManager.sharedManager.currentUser.ID;
    model.ownerID   = ownerID ?: @"";
    model.createdAt = self.editingPet.createdAt ?: [NSDate date];
    model.imageURLs = self.editingPet.imageURLs ?: @[];
    return model;
}

- (void)persistFormWithImages:(NSArray<UIImage *> *)images {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [self pp_resetSaveButton];
        [UserManager showPromptOnTopController];
        return;
    }

    self.isSaving = YES;
    [GM ActivityLoadingAnimationView:YES onView:self.tableView];
    [self pp_scheduleSaveTimeout];

    AdoptPetModel *model = [self buildModelFromForm];
    __weak typeof(self) weakSelf = self;

    if (self.editingPet) {
        if (images.count > 0) {
            [[AdoptPetManager shared] updatePet:model
                                         images:images
                                     completion:^(BOOL success, NSError * _Nullable error) {
                [weakSelf pp_finishSaveWithSuccess:success error:error isEditing:YES];
            }];
        } else {
            [[AdoptPetManager shared] updatePetWithID:model.documentID
                                                 data:[model toFirestoreDictionary]
                                           completion:^(BOOL success, NSError * _Nullable error) {
                [weakSelf pp_finishSaveWithSuccess:success error:error isEditing:YES];
            }];
        }
        return;
    }

    [[AdoptPetManager shared] createPet:model
                                 images:images
                             completion:^(BOOL success, NSString * _Nullable documentID, NSError * _Nullable error) {
        [weakSelf pp_finishSaveWithSuccess:success error:error isEditing:NO];
    }];
}

- (void)pp_finishSaveWithSuccess:(BOOL)success
                           error:(NSError * _Nullable)error
                       isEditing:(BOOL)isEditing {
    [self pp_cancelSaveTimeout];
    [self pp_resetSaveButton];
    [GM ActivityLoadingAnimationView:NO onView:self.tableView];
    self.isSaving = NO;

    if (!success) {
        [self showErrorMessage:error.localizedDescription.length > 0 ? error.localizedDescription : kLang(@"unknownError")];
        return;
    }

    [self clearSavedDraft];
    NSString *title    = isEditing ? kLang(@"adoptPetUpdatedTitle") : kLang(@"adoptPetAddedTitle");
    NSString *subtitle = isEditing ? kLang(@"adoptPetUpdatedDesc")  : kLang(@"adoptPetAddedDesc");

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showSuccessIn:self title:title subtitle:subtitle OKAction:^(NSString * _Nullable text, BOOL didConfirm) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_dismissForm];
    }];
}

#pragma mark - Errors

- (void)showErrorMessage:(NSString *)message {
    [PPAlertHelper showErrorIn:self
                         title:kLang(@"error")
                      subtitle:message.length > 0 ? message : kLang(@"unknownError")];
}

#pragma mark - Helpers

- (NSString *)pp_displayGenderForStoredValue:(NSString *)gender {
    NSString *v = [PPAdoptSafeString(gender) lowercaseString];
    if ([v isEqualToString:@"female"] || [v isEqualToString:[kLang(@"female") lowercaseString]]) {
        return kLang(@"female");
    }
    return kLang(@"male");
}

- (NSString *)pp_normalizedGenderFromFormValue:(id)value {
    NSString *raw = [PPAdoptSafeString(value) lowercaseString];
    if ([raw isEqualToString:@"female"] || [raw isEqualToString:[kLang(@"female") lowercaseString]]) {
        return @"Female";
    }
    return @"Male";
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 4 : 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: {
                PPAdoptFormTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptFormTextFieldCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"name")
                                    text:self.draftName
                             placeholder:kLang(@"enter_pet_name")
                            keyboardType:UIKeyboardTypeDefault
                                  target:self
                                  action:@selector(pp_nameFieldChanged:)];
                cell.textField.tag = 100;
                cell.textField.delegate = self;
                return cell;
            }
            case 1: {
                PPAdoptFormSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptFormSelectorCell" forIndexPath:indexPath];
                NSString *value = self.draftMainKind.KindName ?: kLang(@"selectSpecies");
                [cell configureWithTitle:kLang(@"species") value:value];
                return cell;
            }
            case 2: {
                PPAdoptFormSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptFormSelectorCell" forIndexPath:indexPath];
                NSString *value = self.draftSubKind.SubKindName ?: kLang(@"selectCreed");
                [cell configureWithTitle:kLang(@"breed") value:value];
                BOOL enabled = (self.draftMainKind != nil);
                cell.userInteractionEnabled = enabled;
                cell.contentView.alpha = enabled ? 1.0 : 0.5;
                return cell;
            }
            case 3: {
                PPAdoptFormTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptFormTextFieldCell" forIndexPath:indexPath];
                NSString *ageText = self.draftAgeMonths > 0 ? [@(self.draftAgeMonths) stringValue] : @"";
                [cell configureWithTitle:kLang(@"ageMonths")
                                    text:ageText
                             placeholder:kLang(@"enter_pet_age_in_months")
                            keyboardType:UIKeyboardTypeNumberPad
                                  target:self
                                  action:@selector(pp_ageFieldChanged:)];
                cell.textField.tag = 101;
                cell.textField.delegate = self;
                return cell;
            }
            default: break;
        }
    }

    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: {
                PPAdoptFormSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptFormSelectorCell" forIndexPath:indexPath];
                NSString *value = self.draftGender.length > 0 ? self.draftGender : kLang(@"selectGender");
                [cell configureWithTitle:kLang(@"Gender") value:value];
                return cell;
            }
            case 1: {
                PPAdoptFormSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptFormSelectorCell" forIndexPath:indexPath];
                NSString *value = self.draftCity.name ?: kLang(@"selectCity");
                [cell configureWithTitle:kLang(@"city") value:value];
                return cell;
            }
            case 2: {
                PPAdoptFormTextViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAdoptFormTextViewCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"details")
                                    text:self.draftDetails
                             placeholder:kLang(@"describePet")
                                delegate:self];
                return cell;
            }
            default: break;
        }
    }

    return [[UITableViewCell alloc] init];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds   = NO;
    cell.selectionStyle  = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor     = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
    cell.contentView.layer.cornerRadius  = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth   = 1.0;
    UIColor *adoptBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.85 green:0.80 blue:0.78 alpha:0.10];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
    }];
    [cell.contentView pp_setBorderColor:[adoptBorderColor resolvedColorWithTraitCollection:self.traitCollection]];
    [cell pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    cell.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.02 : 0.05;
    cell.layer.shadowRadius  = 12.0;
    cell.layer.shadowOffset  = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 48.0;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath{
    if(indexPath.row == 0)
        if(indexPath.row == 0 || indexPath.row == 1 || indexPath.row == 2 || indexPath.row == 3 ||indexPath.row == 4 || indexPath.row == 5) return 83;
    if(indexPath.row == 1)
        if(indexPath.row == 0 || indexPath.row == 1) return 83;
    return UITableViewAutomaticDimension;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = section == 0 ? kLang(@"petInfo") : kLang(@"additionalInfo");

    UIView *header = [[UIView alloc] init];
    header.backgroundColor = UIColor.clearColor;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    label.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    label.text = title;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    [header addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor  constraintEqualToAnchor:header.leadingAnchor  constant:18.0],
        [label.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18.0],
        [label.topAnchor      constraintEqualToAnchor:header.topAnchor      constant:24.0],
        [label.bottomAnchor   constraintEqualToAnchor:header.bottomAnchor   constant:-8.0]
    ]];

    return header;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && (indexPath.row == 1 || indexPath.row == 2)) return YES;
    if (indexPath.section == 1 && (indexPath.row == 0 || indexPath.row == 1)) return YES;
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        if (indexPath.row == 1) {
            [self pp_presentSpeciesPicker];
        } else if (indexPath.row == 2 && self.draftMainKind) {
            [self pp_presentBreedPicker];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self pp_presentGenderPicker];
        } else if (indexPath.row == 1) {
            [self pp_presentCityPicker];
        }
    }
}

#pragma mark - Selector Pickers

- (void)pp_presentSpeciesPicker {
    NSArray *options = MKM.MainKindsArray ?: @[];
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:options
                  title:kLang(@"selectSpecies")
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
           if (!strongSelf) return;
           if (![selectedObject isKindOfClass:MainKindsModel.class]) return;
           strongSelf.draftMainKind = (MainKindsModel *)selectedObject;
           strongSelf.draftSubKind  = nil;
           if (!strongSelf.isHydratingFormData) strongSelf.hasUserModifiedForm = YES;
           CGPoint savedOffset = strongSelf.tableView.contentOffset;
           [UIView performWithoutAnimation:^{
               [strongSelf.tableView reloadRowsAtIndexPaths:@[
                   [NSIndexPath indexPathForRow:1 inSection:0],
                   [NSIndexPath indexPathForRow:2 inSection:0]
               ] withRowAnimation:UITableViewRowAnimationNone];
           }];
           [strongSelf.tableView layoutIfNeeded];
           strongSelf.tableView.contentOffset = savedOffset;
        });
        
        
        
             
     }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pp_presentBreedPicker {
    NSArray *options = self.draftMainKind.SubKindsArray ?: @[];
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:options
                  title:kLang(@"selectCreed")
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (![selectedObject isKindOfClass:SubKindModel.class]) return;
            strongSelf.draftSubKind = (SubKindModel *)selectedObject;
            if (!strongSelf.isHydratingFormData) strongSelf.hasUserModifiedForm = YES;
            CGPoint savedOffset = strongSelf.tableView.contentOffset;
            [UIView performWithoutAnimation:^{
                [strongSelf.tableView reloadRowsAtIndexPaths:@[
                    [NSIndexPath indexPathForRow:2 inSection:0]
                ] withRowAnimation:UITableViewRowAnimationNone];
            }];
            [strongSelf.tableView layoutIfNeeded];
            strongSelf.tableView.contentOffset = savedOffset;
        });
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pp_presentGenderPicker {
    NSArray *options = @[kLang(@"male"), kLang(@"female")];
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:options
                  title:kLang(@"selectGender")
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (![selectedObject isKindOfClass:NSString.class]) return;
            strongSelf.draftGender = (NSString *)selectedObject;
            if (!strongSelf.isHydratingFormData) strongSelf.hasUserModifiedForm = YES;
            CGPoint savedOffset = strongSelf.tableView.contentOffset;
            [UIView performWithoutAnimation:^{
                [strongSelf.tableView reloadRowsAtIndexPaths:@[
                    [NSIndexPath indexPathForRow:0 inSection:1]
                ] withRowAnimation:UITableViewRowAnimationNone];
            }];
            [strongSelf.tableView layoutIfNeeded];
            strongSelf.tableView.contentOffset = savedOffset;
        });
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pp_presentCityPicker {
    NSArray *options = [[CitiesManager shared] citiesForCurrentCountry] ?: @[];
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:options
                  title:kLang(@"selectCity")
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (![selectedObject isKindOfClass:CityModel.class]) return;
            strongSelf.draftCity = (CityModel *)selectedObject;
            if (!strongSelf.isHydratingFormData) strongSelf.hasUserModifiedForm = YES;
            CGPoint savedOffset = strongSelf.tableView.contentOffset;
            [UIView performWithoutAnimation:^{
                [strongSelf.tableView reloadRowsAtIndexPaths:@[
                    [NSIndexPath indexPathForRow:1 inSection:1]
                ] withRowAnimation:UITableViewRowAnimationNone];
            }];
            [strongSelf.tableView layoutIfNeeded];
            strongSelf.tableView.contentOffset = savedOffset;
        });
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Text Field Actions

- (void)pp_nameFieldChanged:(UITextField *)textField {
    self.draftName = textField.text;
    if (!self.isHydratingFormData) self.hasUserModifiedForm = YES;
}

- (void)pp_ageFieldChanged:(UITextField *)textField {
    self.draftAgeMonths = [textField.text integerValue];
    if (!self.isHydratingFormData) self.hasUserModifiedForm = YES;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.draftDetails = textView.text;
    if (!self.isHydratingFormData) self.hasUserModifiedForm = YES;

    PPAdoptFormTextViewCell *cell = (PPAdoptFormTextViewCell *)[self pp_parentCellForView:textView];
    if ([cell isKindOfClass:PPAdoptFormTextViewCell.class]) {
        [cell updatePlaceholderVisibility];
        [cell updatePreferredHeight];
    }

    [UIView setAnimationsEnabled:NO];
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    [UIView setAnimationsEnabled:YES];
}

- (UITableViewCell *)pp_parentCellForView:(UIView *)view {
    UIView *current = view.superview;
    while (current) {
        if ([current isKindOfClass:UITableViewCell.class]) return (UITableViewCell *)current;
        current = current.superview;
    }
    return nil;
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    (void)collection;
    PPAdoptLog(@"Media changed -> %lu images", (unsigned long)images.count);
    if (!self.isHydratingFormData && !self.isPrefillInProgress) {
        self.hasUserModifiedForm = YES;
    }
}

- (void)imageCollection:(PPImageCollection *)collection
         didSelectImage:(nonnull UIImage *)selectedImage
                AtIndex:(NSInteger)index {
    (void)selectedImage;
    if (index < 0 || index >= collection.imageCount) return;
    [collection presentEditorForImageAtIndex:index fromViewController:self];
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    if (collection.imageCount >= collection.maxImageCount) {
        NSString *title    = kLang(@"max_images_reached");
        NSString *subtitle = [NSString stringWithFormat:@"%@ %ld",
                              kLang(@"max_images_hint"),
                              (long)collection.maxImageCount];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }
    [collection presentPickerFromViewController:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self.tableView reloadData];
    }
}

@end
