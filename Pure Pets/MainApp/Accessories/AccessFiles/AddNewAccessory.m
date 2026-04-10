#import "AddNewAccessory.h"
#import "PPImageCollection.h"
#import "UserManager.h"
#import "PPNetworkRetryHelper.h"
#import "PPSelectOptionViewController.h"

static NSString *const PPAddAccessoryLanguageDidChangeNotification = @"LanguageDidChangeNotification";
static NSString *const PPAddAccessoryErrorDomain = @"PPAddAccessoryErrorDomain";
static NSString *const PPAddAccessoryDraftDefaultsPrefix = @"pp.add_accessory.draft";
static NSString *const PPAddAccessoryDraftFormDataKey = @"formData";
static NSString *const PPAddAccessoryDraftImagePathsKey = @"imagePaths";

// Form tags / Firestore field keys
static NSString *const PPAddAccessoryFieldName = @"name";
static NSString *const PPAddAccessoryFieldPrice = @"price";
static NSString *const PPAddAccessoryFieldDescription = @"desc";
static NSString *const PPAddAccessoryFieldMainCategoryID = @"petMainCategoryID";
static NSString *const PPAddAccessoryFieldSubCategoryID = @"petSubCategoryID";

static NSInteger const PPAddAccessoryMaxImageCount = 8;
static CGFloat const PPAddAccessoryCollectionHeight = 220.0;
static CGFloat const PPAddAccessoryFooterHeight = 236.0;
static CGFloat const PPAddAccessoryCollectionHorizontalInset = 16.0;
static CGFloat const PPAddAccessoryProgressHeight = 4.0;
static CGFloat const PPAddAccessoryUploadMaxDimension = 2048.0;

static inline NSString *PPAccessorySafeString(id value) {
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

// ────────────────────────────────────────────────────────────
#pragma mark - Cell constants & helpers
// ────────────────────────────────────────────────────────────

static const CGFloat kPPFormCellHorizontalInset = 20.0;
static const CGFloat kPPFormCellVerticalInset   = 10.0;

static inline UISemanticContentAttribute PPFormCurrentSemanticAttribute(void) {
    return Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

// ────────────────────────────────────────────────────────────
#pragma mark - Section / Row enumerations
// ────────────────────────────────────────────────────────────

typedef NS_ENUM(NSInteger, PPAccessoryFormSection) {
    PPAccessoryFormSectionCategory = 0,
    PPAccessoryFormSectionDetails,
    PPAccessoryFormSectionCount
};

typedef NS_ENUM(NSInteger, PPAccessoryCategoryRow) {
    PPAccessoryCategoryRowMain = 0,
    PPAccessoryCategoryRowSub,
    PPAccessoryCategoryRowCount
};

typedef NS_ENUM(NSInteger, PPAccessoryDetailRow) {
    PPAccessoryDetailRowName = 0,
    PPAccessoryDetailRowPrice,
    PPAccessoryDetailRowDesc,
    PPAccessoryDetailRowCount
};

typedef NS_ENUM(NSInteger, PPAccessoryFieldKind) {
    PPAccessoryFieldKindName = 1,
    PPAccessoryFieldKindPrice,
    PPAccessoryFieldKindDesc
};

// ────────────────────────────────────────────────────────────
#pragma mark - PPFormBaseCell
// ────────────────────────────────────────────────────────────

@interface PPFormBaseCell : UITableViewCell
@end

@implementation PPFormBaseCell
- (void)setFrame:(CGRect)frame {
    frame.origin.x = kPPFormCellHorizontalInset;
    frame.size.width -= kPPFormCellHorizontalInset * 2.0;
    frame.origin.y += kPPFormCellVerticalInset * 0.5;
    frame.size.height -= kPPFormCellVerticalInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}
@end

// ────────────────────────────────────────────────────────────
#pragma mark - PPFormTextFieldCell
// ────────────────────────────────────────────────────────────

@interface PPFormTextFieldCell : PPFormBaseCell
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UITextField *textField;
- (void)configureWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType fieldKind:(PPAccessoryFieldKind)fieldKind
                    target:(id)target action:(SEL)action delegate:(id<UITextFieldDelegate>)delegate;
@end

@implementation PPFormTextFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;
    self.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPFormCurrentSemanticAttribute();

    UILabel *tl = [[UILabel alloc] init];
    tl.translatesAutoresizingMaskIntoConstraints = NO;
    tl.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    tl.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    tl.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:tl];
    self.titleLabel = tl;

    UITextField *tf = [[UITextField alloc] init];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.borderStyle = UITextBorderStyleNone;
    tf.backgroundColor = UIColor.clearColor;
    tf.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    tf.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.adjustsFontSizeToFitWidth = NO;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.textAlignment = Language.alignmentForCurrentLanguage;
    tf.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    [self.contentView addSubview:tf];
    self.textField = tf;

    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [tl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [tl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [tl.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        
        
        [tf.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:6.0],
        [tf.leadingAnchor constraintEqualToAnchor:tl.leadingAnchor],
        [tf.trailingAnchor constraintEqualToAnchor:tl.trailingAnchor],
        [tf.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        [tf.heightAnchor constraintGreaterThanOrEqualToConstant:24.0]
    ]];
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
}

- (void)configureWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType fieldKind:(PPAccessoryFieldKind)fieldKind
                    target:(id)target action:(SEL)action delegate:(id<UITextFieldDelegate>)delegate {
    self.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.text = text ?: @"";
    self.textField.placeholder = placeholder ?: @"";
    self.textField.tag = fieldKind;
    self.textField.delegate = delegate;
    self.textField.keyboardType = keyboardType;
    self.textField.returnKeyType = UIReturnKeyNext;
    self.textField.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}
@end

// ────────────────────────────────────────────────────────────
#pragma mark - PPFormSelectorCell
// ────────────────────────────────────────────────────────────

@interface PPFormSelectorCell : PPFormBaseCell
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UILabel     *valueLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithTitle:(NSString *)title value:(NSString *)value disabled:(BOOL)disabled;
@end

@implementation PPFormSelectorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPFormCurrentSemanticAttribute();

    UILabel *tl = [[UILabel alloc] init];
    tl.translatesAutoresizingMaskIntoConstraints = NO;
    tl.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    tl.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    tl.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:tl];
    self.titleLabel = tl;

    UILabel *vl = [[UILabel alloc] init];
    vl.translatesAutoresizingMaskIntoConstraints = NO;
    vl.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    vl.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    vl.numberOfLines = 2;
    vl.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:vl];
    self.valueLabel = vl;

    UIImageView *cv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    cv.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.8];
    cv.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:cv];
    self.chevronView = cv;

    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [tl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [tl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [tl.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        
        [cv.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:10.0],
        [cv.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [cv.widthAnchor constraintEqualToConstant:14.0],
        [cv.heightAnchor constraintEqualToConstant:14.0],
        [vl.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:8.0],
        [vl.leadingAnchor constraintEqualToAnchor:tl.leadingAnchor],
        [vl.trailingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:-12.0],
        [vl.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
    ]];
    return self;
}

- (void)configureWithTitle:(NSString *)title value:(NSString *)value disabled:(BOOL)disabled {
    self.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.valueLabel.text = value ?: @"";
    self.valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.userInteractionEnabled = !disabled;
    CGFloat alpha = disabled ? 0.45 : 1.0;
    self.titleLabel.alpha = alpha;
    self.valueLabel.alpha = alpha;
    self.chevronView.alpha = alpha;
}
@end

// ────────────────────────────────────────────────────────────
#pragma mark - PPFormTextViewCell
// ────────────────────────────────────────────────────────────

@interface PPFormTextViewCell : PPFormBaseCell
@property (nonatomic, strong) UILabel    *titleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel    *placeholderLabel;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
- (void)configureWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder
                 fieldKind:(PPAccessoryFieldKind)fieldKind delegate:(id<UITextViewDelegate>)delegate;
- (void)updatePreferredHeight;
- (void)updatePlaceholderVisibility;
@end

@implementation PPFormTextViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPFormCurrentSemanticAttribute();

    UILabel *tl = [[UILabel alloc] init];
    tl.translatesAutoresizingMaskIntoConstraints = NO;
    tl.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    tl.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    tl.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:tl];
    self.titleLabel = tl;

    UITextView *tv = [[UITextView alloc] init];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.backgroundColor = UIColor.clearColor;
    tv.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    tv.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    tv.scrollEnabled = NO;
    tv.textContainerInset = UIEdgeInsetsZero;
    tv.textContainer.lineFragmentPadding = 0.0;
    tv.autocorrectionType = UITextAutocorrectionTypeNo;
    tv.textAlignment = Language.alignmentForCurrentLanguage;
    tv.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    [self.contentView addSubview:tv];
    self.textView = tv;

    UILabel *pl = [[UILabel alloc] init];
    pl.translatesAutoresizingMaskIntoConstraints = NO;
    pl.font = tv.font;
    pl.textColor = UIColor.placeholderTextColor;
    pl.numberOfLines = 0;
    pl.userInteractionEnabled = NO;
    [self.contentView addSubview:pl];
    self.placeholderLabel = pl;

    NSLayoutConstraint *hc = [tv.heightAnchor constraintGreaterThanOrEqualToConstant:116.0];
    hc.active = YES;
    self.textViewHeightConstraint = hc;

    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [tl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [tl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [tl.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        
        [tv.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:8.0],
        [tv.leadingAnchor constraintEqualToAnchor:tl.leadingAnchor],
        [tv.trailingAnchor constraintEqualToAnchor:tl.trailingAnchor],
        [tv.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        [pl.topAnchor constraintEqualToAnchor:tv.topAnchor],
        [pl.leadingAnchor constraintEqualToAnchor:tv.leadingAnchor constant:2.0],
        [pl.trailingAnchor constraintLessThanOrEqualToAnchor:tv.trailingAnchor]
    ]];
    return self;
}

- (void)configureWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder
                 fieldKind:(PPAccessoryFieldKind)fieldKind delegate:(id<UITextViewDelegate>)delegate {
    self.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.tag = fieldKind;
    self.textView.delegate = delegate;
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.semanticContentAttribute = PPFormCurrentSemanticAttribute();
    self.textView.text = text ?: @"";
    self.placeholderLabel.text = placeholder ?: @"";
    self.placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self updatePlaceholderVisibility];
    [self updatePreferredHeight];
}

- (void)updatePreferredHeight {
    CGFloat fw = CGRectGetWidth(self.textView.bounds);
    if (fw <= 1.0) fw = UIScreen.mainScreen.bounds.size.width - 72.0;
    CGSize ts = CGSizeMake(MAX(120.0, fw), CGFLOAT_MAX);
    CGFloat ph = ceil([self.textView sizeThatFits:ts].height);
    self.textViewHeightConstraint.constant = MAX(116.0, ph);
}

- (void)updatePlaceholderVisibility {
    self.placeholderLabel.hidden = self.textView.text.length > 0;
}
@end

// ────────────────────────────────────────────────────────────
#pragma mark - AddNewAccessory  (main controller)
// ────────────────────────────────────────────────────────────

@interface AddNewAccessory ()<PPImageCollectionDelegate, UITableViewDataSource, UITableViewDelegate,
                              UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) PPImageCollection *imageCollection;
@property (nonatomic, strong) UIView *imageFooterContainer;
@property (nonatomic, strong) PetAccessory *accessModel;
@property (nonatomic, strong) MainKindsModel *selectedKind;
@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;

// Draft properties (replace XLFormRowDescriptors)
@property (nonatomic, strong) MainKindsModel *draftMainKind;
@property (nonatomic, strong) SubKindModel   *draftSubKind;
@property (nonatomic, copy)   NSString       *draftName;
@property (nonatomic, strong) NSNumber       *draftPrice;
@property (nonatomic, copy)   NSString       *draftDesc;

@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIBarButtonItem *uploadSpinnerItem;
@property (nonatomic, strong) UIBarButtonItem *originalRightBarButtonItem;
@property (nonatomic, strong) UIActivityIndicatorView *uploadSpinner;

@property (nonatomic, assign) BOOL isSubmittingAccessory;
@property (nonatomic, assign) BOOL isProgressAnimating;
@property (nonatomic, assign) BOOL didFocusFirstField;
@property (nonatomic, assign) BOOL hasHandledLiveBlockedState;
@property (nonatomic, assign) BOOL hasUserModifiedForm;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, assign) BOOL isHydratingMedia;
@property (nonatomic, copy, nullable) dispatch_block_t uploadTimeoutBlock;

- (UIView *)pp_modernBlurTitleViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle;
@end

@implementation AddNewAccessory

#pragma mark - Lifecycle

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isHydratingFormData = YES;
    self.isHydratingMedia = NO;
    self.hasUserModifiedForm = NO;

    [self initBase];
    [self pp_configureModeAndModel];
    [self initForm];
    [self setupImageCollection];
    [self pp_setupUploadProgressView];

    if ([self restoreDraftIfNeeded]) {
        self.isHydratingFormData = NO;
    } else if (self.formMode == AccessFormModeEdit) {
        [self prefillFromModel:self.editingAccessory];
        [self prefillPhotosForEdit];
        self.isHydratingFormData = NO;
    } else {
        self.isHydratingFormData = NO;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_handleLanguageDidChange:)
                                                 name:PPAddAccessoryLanguageDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_handleBlockedStateNotification:)
                                                 name:PPUserManagerDidUpdateBlockedStateNotification object:UserManager.sharedManager];
    [self pp_refreshMediaLocalizedText];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateImageFooterLayoutIfNeeded];
    if (self.uploadProgressView) [self.view bringSubviewToFront:self.uploadProgressView];
}

- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self pp_focusFirstFieldIfNeeded]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_updateNavigationTitle];
    [self ios26Bar];
    [self pp_refreshMediaLocalizedText];
    [self pp_setSubmitEnabled:!self.isSubmittingAccessory];
    [UserManager.sharedManager startListeningCurrentUserBlockedState];
    [UserManager.sharedManager startListeningCurrentUserPermissionsWithChange:nil];
    if (UserManager.sharedManager.isCurrentUserBlocked) [self pp_handleLiveBlockedStateIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    BOOL exiting = self.isMovingFromParentViewController || self.isBeingDismissed || self.navigationController.isBeingDismissed;
    if (exiting) [self.imageCollection clearAllImages];
}

#pragma mark - Draft Storage

- (NSString *)draftStorageKey {
    NSString *uid = PPAccessorySafeString(UserManager.sharedManager.currentUser.ID);
    if (self.formMode == AccessFormModeEdit && self.editingAccessory.accessoryID.length) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@", PPAddAccessoryDraftDefaultsPrefix, self.editingAccessory.accessoryID, uid];
    }
    return [NSString stringWithFormat:@"%@.create.%ld.%@", PPAddAccessoryDraftDefaultsPrefix, (long)self.accessKindType, uid];
}

- (NSString *)draftDirectoryPath {
    NSString *draftID = [[[self draftStorageKey] stringByReplacingOccurrencesOfString:@"." withString:@"_"]
                         stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [[NSTemporaryDirectory() stringByAppendingPathComponent:@"pp_form_drafts"] stringByAppendingPathComponent:draftID];
}

- (BOOL)hasSavedDraft {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]] isKindOfClass:NSDictionary.class];
}

- (NSData *)archivedDraftDataForObject:(id)object {
    if (!object) return nil;
    if (@available(iOS 11.0, *)) {
        return [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:NO error:nil];
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
    [self pp_syncModelFromDraftProperties];
    NSMutableDictionary *snap = [NSMutableDictionary dictionary];
    if (self.accessModel.petMainCategoryID > 0) snap[PPAddAccessoryFieldMainCategoryID] = @(self.accessModel.petMainCategoryID);
    if (self.accessModel.petSubCategoryID > 0) snap[PPAddAccessoryFieldSubCategoryID] = @(self.accessModel.petSubCategoryID);
    NSString *n = [PPAccessorySafeString(self.draftName) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (n.length) snap[PPAddAccessoryFieldName] = n;
    NSNumber *p = [self pp_numberFromValue:self.draftPrice];
    if (p) snap[PPAddAccessoryFieldPrice] = p;
    NSString *d = [PPAccessorySafeString(self.draftDesc) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (d.length) snap[PPAddAccessoryFieldDescription] = d;
    return snap.copy;
}

- (NSString *)writeDraftImage:(UIImage *)image named:(NSString *)fileName directory:(NSString *)directory {
    if (!image || fileName.length == 0 || directory.length == 0) return nil;
    NSData *data = UIImagePNGRepresentation(image);
    if (!data) return nil;
    NSString *path = [directory stringByAppendingPathComponent:fileName];
    return [data writeToFile:path atomically:YES] ? path : nil;
}

- (NSArray<NSString *> *)writeDraftImages:(NSArray<UIImage *> *)images withPrefix:(NSString *)prefix directory:(NSString *)directory {
    if (images.count == 0) return @[];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    [images enumerateObjectsUsingBlock:^(UIImage *img, NSUInteger idx, BOOL *stop) {
        (void)stop;
        NSString *fn = [NSString stringWithFormat:@"%@_%lu.png", prefix, (unsigned long)idx];
        NSString *p = [self writeDraftImage:img named:fn directory:directory];
        if (p.length) [paths addObject:p];
    }];
    return paths.copy;
}

- (NSArray<UIImage *> *)imagesFromDraftPaths:(NSArray<NSString *> *)paths {
    NSMutableArray<UIImage *> *imgs = [NSMutableArray array];
    for (NSString *p in paths) {
        if (![p isKindOfClass:NSString.class] || p.length == 0) continue;
        UIImage *img = [UIImage imageWithContentsOfFile:p];
        if (img) [imgs addObject:img];
    }
    return imgs.copy;
}

- (void)clearSavedDraft {
    [[NSFileManager defaultManager] removeItemAtPath:[self draftDirectoryPath] error:nil];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs removeObjectForKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)saveDraftForLater {
    NSDictionary *snap = [self draftFormDataSnapshot];
    NSData *fd = [self archivedDraftDataForObject:snap];
    if (!fd) return;
    NSString *dir = [self draftDirectoryPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:dir error:nil];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray<NSString *> *imgPaths = [self writeDraftImages:[self.imageCollection allImages] withPrefix:@"media" directory:dir];
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[PPAddAccessoryDraftFormDataKey] = fd;
    payload[PPAddAccessoryDraftImagePathsKey] = imgPaths ?: @[];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (BOOL)restoreDraftIfNeeded {
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *stored = [self unarchivedDraftObjectFromData:payload[PPAddAccessoryDraftFormDataKey]];
    if (![stored isKindOfClass:NSDictionary.class]) { [self clearSavedDraft]; return NO; }

    self.isHydratingFormData = YES;
    PetAccessory *dm = [PetAccessory deepCopyFrom:self.accessModel] ?: [[PetAccessory alloc] init];
    dm.accessKindType = self.accessKindType;
    dm.petMainCategoryID = [stored[PPAddAccessoryFieldMainCategoryID] integerValue];
    dm.petSubCategoryID = [stored[PPAddAccessoryFieldSubCategoryID] integerValue];
    dm.name = PPAccessorySafeString(stored[PPAddAccessoryFieldName]);
    dm.price = [self pp_numberFromValue:stored[PPAddAccessoryFieldPrice]] ?: @0;
    dm.desc = PPAccessorySafeString(stored[PPAddAccessoryFieldDescription]);
    [self prefillFromModel:dm];

    NSArray<UIImage *> *imgs = [self imagesFromDraftPaths:payload[PPAddAccessoryDraftImagePathsKey]];
    self.isHydratingMedia = YES;
    [self.imageCollection clearAllImages];
    if (imgs.count > 0) [self.imageCollection addImages:imgs];
    self.isHydratingMedia = NO;
    self.hasUserModifiedForm = NO;
    self.isHydratingFormData = NO;
    [self.tableView reloadData];
    return YES;
}

- (BOOL)pp_shouldPromptForDraftOptions { return self.hasUserModifiedForm || [self hasSavedDraft]; }

- (void)pp_dismissForm {
    BOOL isRoot = (self.navigationController.presentingViewController != nil && self.navigationController.viewControllers.firstObject == self);
    if (isRoot) { [self.navigationController dismissViewControllerAnimated:YES completion:nil]; return; }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)presentUnsavedChangesPrompt {
    __weak typeof(self) ws = self;
    [PPAlertHelper showThreeActionConfirmationIn:self title:kLang(@"form_draft_prompt_title") subtitle:kLang(@"form_draft_prompt_message")
        primaryButton:kLang(@"form_draft_save_and_close") primaryStyle:UIAlertActionStyleDefault
        secondaryButton:kLang(@"form_draft_discard") secondaryStyle:UIAlertActionStyleDestructive
        tertiaryButton:kLang(@"form_draft_keep_editing") tertiaryStyle:UIAlertActionStyleCancel
        primaryBlock:^{ __strong typeof(ws) s = ws; if (!s) return; [s saveDraftForLater]; [s pp_dismissForm]; }
        secondaryBlock:^{ __strong typeof(ws) s = ws; if (!s) return; [s clearSavedDraft]; [s pp_dismissForm]; }
        tertiaryBlock:^{}];
}

- (void)pp_handleBackNavigation {
    if (self.isSubmittingAccessory) return;
    [self.view endEditing:YES];
    if ([self pp_shouldPromptForDraftOptions]) { [self presentUnsavedChangesPrompt]; return; }
    [self pp_dismissForm];
}

#pragma mark - Setup

- (void)initBase {
    if (!self.accessModel) self.accessModel = [[PetAccessory alloc] init];
    self.draftName = @""; self.draftPrice = nil; self.draftDesc = @"";
    [self setBackAndCorners];
}

- (void)pp_configureModeAndModel {
    if (self.accessKindType != AccessTypeAccessory && self.accessKindType != AccessTypeFood) self.accessKindType = AccessTypeAccessory;
    if (self.editingAccessory) {
        self.formMode = AccessFormModeEdit;
        self.accessKindType = self.editingAccessory.accessKindType;
        self.accessModel = [PetAccessory deepCopyFrom:self.editingAccessory];
    } else {
        self.formMode = AccessFormModeCreate;
        self.accessModel = [[PetAccessory alloc] init];
        self.accessModel.accessKindType = self.accessKindType;
        self.accessModel.condition = (self.accessKindType == AccessTypeFood) ? AccessConditionsNew : AccessConditionsUsed;
        self.accessModel.quantity = 1;
        self.accessModel.hasOffer = NO;
        self.accessModel.isNew = (self.accessModel.condition == AccessConditionsNew);
    }
}

- (void)setBackAndCorners { self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr); }

- (void)pp_setupUploadProgressView {
    if (self.uploadProgressView) return;
    GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectZero];
    pv.translatesAutoresizingMaskIntoConstraints = NO;
    pv.progressTintColor = [GM appPrimaryColor];
    pv.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return UIColor.whiteColor;
    }];
    [self.view addSubview:pv];
    [NSLayoutConstraint activateConstraints:@[
        [pv.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [pv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [pv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [pv.heightAnchor constraintEqualToConstant:PPAddAccessoryProgressHeight]
    ]];
    [pv stopAnimating];
    self.uploadProgressView = pv;
}

- (void)setupImageCollection {
    self.imageCollection = [[PPImageCollection alloc] initWithFrame:CGRectZero maxImageCount:PPAddAccessoryMaxImageCount useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.useArabic = Language.isRTL;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, PPAddAccessoryFooterHeight)];
    footer.backgroundColor = UIColor.clearColor;
    [footer addSubview:self.imageCollection];
    self.imageFooterContainer = footer;
    self.tableView.tableFooterView = footer;
    [self pp_updateImageFooterLayoutIfNeeded];
    [self pp_refreshMediaLocalizedText];
}

- (void)pp_updateImageFooterLayoutIfNeeded {
    if (!self.imageFooterContainer || !self.imageCollection) return;
    CGFloat tw = self.tableView.bounds.size.width;
    if (tw <= 0) return;
    CGRect ff = self.imageFooterContainer.frame;
    if (fabs(ff.size.width - tw) > 0.5 || fabs(ff.size.height - PPAddAccessoryFooterHeight) > 0.5) {
        ff.size.width = tw; ff.size.height = PPAddAccessoryFooterHeight;
        self.imageFooterContainer.frame = ff;
    }
    CGFloat cw = MAX(0, tw - (PPAddAccessoryCollectionHorizontalInset * 2.0));
    self.imageCollection.frame = CGRectMake(PPAddAccessoryCollectionHorizontalInset, 0, cw, PPAddAccessoryCollectionHeight);
    self.tableView.tableFooterView = self.imageFooterContainer;
}

#pragma mark - Localization / Titles

- (NSString *)pp_localizedStringForKey:(NSString *)key fallback:(NSString *)fallback {
    NSString *v = key.length ? kLang(key) : nil;
    if (![v isKindOfClass:NSString.class] || v.length == 0 || [v isEqualToString:key]) return fallback ?: @"";
    return v;
}

- (void)pp_refreshMediaLocalizedText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageCollection.useArabic = Language.isRTL;
        NSString *t = (self.accessKindType == AccessTypeFood)
            ? [self pp_localizedStringForKey:@"FoodPostPhotosSection" fallback:@"Food photos"]
            : [self pp_localizedStringForKey:@"AccessPostPhotosSection" fallback:@"Accessory photos"];
        self.imageCollection.titleText = t;
        [self.imageCollection setTitle:t icon:nil];
        [self.imageCollection reloadCollectionView];
    });
}

- (void)pp_handleLanguageDidChange:(NSNotification *)note {
    [self pp_refreshMediaLocalizedText]; [self pp_updateNavigationTitle]; [self ios26Bar];
}

- (void)pp_updateNavigationTitle {
    NSString *title = @"", *subtitle = @"";
    if (self.formMode == AccessFormModeEdit) {
        title = self.accessKindType == AccessTypeFood
            ? [self pp_localizedStringForKey:@"Edit Food" fallback:@"Edit Food"]
            : [self pp_localizedStringForKey:@"Edit Accessory" fallback:@"Edit Accessory"];
    } else {
        title = self.accessKindType == AccessTypeFood
            ? [self pp_localizedStringForKey:@"New Food" fallback:@"New Food"]
            : [self pp_localizedStringForKey:@"Add Accessory" fallback:@"Add Accessory"];
        subtitle = [self pp_localizedStringForKey:@"used" fallback:@"Used"];
    }
    [self pp_navBarSetTitleViewCenteredSmallWidth:[self pp_modernBlurTitleViewWithTitle:title subtitle:subtitle ?: nil]];
}

- (UIView *)pp_modernBlurTitleViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    NSString *st = title ?: @"", *ss = subtitle ?: @"";
    UIFont *tf = [GM boldFontWithSize:16], *sf = [GM MidFontWithSize:12];
    CGFloat mw = MIN(UIScreen.mainScreen.bounds.size.width * 0.62, 240.0);
    CGFloat tw = ceil([st boundingRectWithSize:CGSizeMake(mw, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:tf} context:nil].size.width);
    CGFloat sw = 0;
    if (ss.length) sw = ceil([ss boundingRectWithSize:CGSizeMake(mw, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:sf} context:nil].size.width);
    CGFloat w = MIN(MAX(MAX(tw,sw)+36.0,156.0), mw), h = ss.length ? 50.0 : 42.0;
    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0,0,w,h)];
    c.backgroundColor = UIColor.clearColor; c.userInteractionEnabled = NO;
    c.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    CGFloat cr = h/2.0;
    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *bv = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
        bv.frame = c.bounds; bv.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        bv.userInteractionEnabled = NO; bv.layer.cornerRadius = cr; bv.layer.masksToBounds = YES;
        [c addSubview:bv];
        UIView *tv = [[UIView alloc] initWithFrame:bv.bounds];
        tv.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        tv.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.08];
        [bv.contentView addSubview:tv];
    } else { c.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.12]; }
    c.layer.cornerRadius = cr; c.layer.borderWidth = 1.0;
    c.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.16 : 0.10].CGColor;
    c.layer.shadowColor = [AppShadowClr colorWithAlphaComponent:0.18].CGColor;
    c.layer.shadowOffset = CGSizeMake(0,8); c.layer.shadowOpacity = 1.0; c.layer.shadowRadius = 18.0;
    UIStackView *sk = [[UIStackView alloc] init];
    sk.axis = UILayoutConstraintAxisVertical; sk.alignment = UIStackViewAlignmentCenter;
    sk.spacing = ss.length ? 1.0 : 0.0; sk.translatesAutoresizingMaskIntoConstraints = NO; sk.userInteractionEnabled = NO;
    [c addSubview:sk];
    UILabel *tl = [[UILabel alloc] init]; tl.font = tf; tl.textColor = AppPrimaryTextClr;
    tl.textAlignment = NSTextAlignmentCenter; tl.lineBreakMode = NSLineBreakByTruncatingTail; tl.numberOfLines = 1; tl.text = st;
    [sk addArrangedSubview:tl];
    if (ss.length) {
        UILabel *sl = [[UILabel alloc] init]; sl.font = sf; sl.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.72];
        sl.textAlignment = NSTextAlignmentCenter; sl.lineBreakMode = NSLineBreakByTruncatingTail; sl.numberOfLines = 1; sl.text = ss;
        [sk addArrangedSubview:sl];
    }
    [NSLayoutConstraint activateConstraints:@[
        [sk.leadingAnchor constraintGreaterThanOrEqualToAnchor:c.leadingAnchor constant:16.0],
        [sk.trailingAnchor constraintLessThanOrEqualToAnchor:c.trailingAnchor constant:-16.0],
        [sk.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],
        [sk.centerYAnchor constraintEqualToAnchor:c.centerYAnchor]
    ]];
    return c;
}

#pragma mark - Navigation Buttons

- (UIBarButtonItem *)pp_uploadSpinnerBarItem {
    if (self.uploadSpinnerItem) return self.uploadSpinnerItem;
    UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    sp.color = AppPrimaryClr; sp.hidesWhenStopped = YES; [sp startAnimating];
    self.uploadSpinner = sp;
    self.uploadSpinnerItem = [[UIBarButtonItem alloc] initWithCustomView:sp];
    return self.uploadSpinnerItem;
}

- (void)ios26Bar {
    NSString *bt = (self.formMode == AccessFormModeEdit)
        ? [self pp_localizedStringForKey:@"saveChanges" fallback:@"Save"]
        : [self pp_localizedStringForKey:@"postAd" fallback:@"Post"];
    self.saveButton = [PPButtonHelper pp_buttonWithTitle:bt font:[GM fontWithSize:17] imageName:@"" target:self config:[UIButtonConfiguration tintedButtonConfiguration] action:@selector(uploadAd)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.saveButton];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName) style:UIBarButtonItemStylePlain target:self action:@selector(onBack)];
    [self pp_setSubmitEnabled:!self.isSubmittingAccessory];
}

- (void)pp_setSubmitEnabled:(BOOL)e {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.saveButton.enabled = e; self.saveButton.alpha = e ? 1.0 : 0.6;
        if (self.navigationItem.rightBarButtonItem == self.originalRightBarButtonItem) self.navigationItem.rightBarButtonItem.enabled = e;
    });
}

- (void)pp_showUploadIndicatorOnNavBar {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.originalRightBarButtonItem) self.originalRightBarButtonItem = self.navigationItem.rightBarButtonItem;
        self.navigationItem.rightBarButtonItem = [self pp_uploadSpinnerBarItem];
    });
}

- (void)pp_hideUploadIndicatorOnNavBar {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.uploadSpinner stopAnimating];
        if (self.originalRightBarButtonItem) { self.navigationItem.rightBarButtonItem = self.originalRightBarButtonItem; self.originalRightBarButtonItem = nil; }
        self.uploadSpinnerItem = nil; self.uploadSpinner = nil;
    });
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)c didUpdateImages:(NSArray<UIImage *> *)imgs {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isHydratingFormData && !self.isHydratingMedia) self.hasUserModifiedForm = YES;
        [self pp_refreshMediaLocalizedText];
    });
}

- (void)imageCollection:(PPImageCollection *)c didSelectImage:(UIImage *)img AtIndex:(NSInteger)idx {
    [c presentEditorForImageAtIndex:idx fromViewController:self];
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)c {
    if (![self pp_canAddMoreImagesForCollection:c showAlert:YES]) return;
    [c presentPickerFromViewController:self];
}

- (BOOL)pp_canAddMoreImagesForCollection:(PPImageCollection *)c showAlert:(BOOL)show {
    if (c.imageCount < c.maxImageCount) return YES;
    if (show) {
        [PPAlertHelper showErrorIn:self
            title:[self pp_localizedStringForKey:@"max_images_reached" fallback:@"Maximum images reached"]
            subtitle:[NSString stringWithFormat:@"%@ %ld", [self pp_localizedStringForKey:@"max_images_hint" fallback:@"You can upload up to"], (long)c.maxImageCount]];
    }
    return NO;
}

#pragma mark - Prefill

- (void)prefillPhotosForEdit {
    if (self.accessModel.imageURLsArray.count == 0) return;
    self.isHydratingMedia = YES;
    [self.imageCollection preloadImagesFromURLs:self.accessModel.imageURLsArray completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{ self.isHydratingMedia = NO; [self pp_refreshMediaLocalizedText]; });
    }];
}

- (void)prefillFromModel:(PetAccessory *)model {
    if (!model) return;
    self.selectedKind = [MKM mainKindForID:model.petMainCategoryID];
    self.draftMainKind = self.selectedKind;
    if (self.selectedKind) {
        SubKindModel *sk = nil;
        for (SubKindModel *sub in self.selectedKind.SubKindsArray) { if (sub.ID == model.petSubCategoryID) { sk = sub; break; } }
        self.draftSubKind = sk;
    } else { self.draftSubKind = nil; }
    self.draftName = model.name ?: @"";
    self.draftPrice = model.price ?: @0;
    self.draftDesc = model.desc ?: @"";
    [self pp_syncModelFromDraftProperties];
    [self.tableView reloadData];
}

#pragma mark - Form (TableView Setup)

- (void)initForm {
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.clipsToBounds = YES;
    UITableView *tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.delegate = self; tv.dataSource = self;
    tv.separatorStyle = UITableViewCellSeparatorStyleNone;
    tv.showsVerticalScrollIndicator = NO; tv.showsHorizontalScrollIndicator = NO;
    tv.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tv.rowHeight = UITableViewAutomaticDimension; tv.estimatedRowHeight = 84.0;
    tv.backgroundColor = AppClearClr; tv.clipsToBounds = YES;
    tv.contentInset = UIEdgeInsetsMake(6, 0, 24, 0);
    tv.scrollIndicatorInsets = UIEdgeInsetsMake(6, 0, 24, 0);
    tv.sectionFooterHeight = 0; tv.estimatedSectionFooterHeight = 0;
    if (@available(iOS 15.0, *)) tv.sectionHeaderTopPadding = 0.0;
    [tv registerClass:PPFormTextFieldCell.class forCellReuseIdentifier:@"PPFormTextFieldCell"];
    [tv registerClass:PPFormSelectorCell.class forCellReuseIdentifier:@"PPFormSelectorCell"];
    [tv registerClass:PPFormTextViewCell.class forCellReuseIdentifier:@"PPFormTextViewCell"];
    [self.view addSubview:tv];
    [NSLayoutConstraint activateConstraints:@[
        [tv.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.tableView = tv;
}

- (NSNumber *)pp_numberFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *t = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return t.length == 0 ? nil : @([t doubleValue]);
    }
    return nil;
}

- (void)pp_syncModelFromDraftProperties {
    NSString *n = [PPAccessorySafeString(self.draftName) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.draftName = n; self.accessModel.name = n;
    self.accessModel.price = [self pp_numberFromValue:self.draftPrice] ?: @0;
    self.accessModel.desc = PPAccessorySafeString(self.draftDesc);
    MainKindsModel *mk = self.draftMainKind ?: self.selectedKind;
    self.selectedKind = mk; self.accessModel.petMainCategoryID = mk.ID;
    self.accessModel.petSubCategoryID = self.draftSubKind ? self.draftSubKind.ID : 0;
    self.accessModel.accessKindType = self.accessKindType;
    if (self.accessModel.condition != AccessConditionsNew && self.accessModel.condition != AccessConditionsUsed)
        self.accessModel.condition = (self.accessKindType == AccessTypeFood) ? AccessConditionsNew : AccessConditionsUsed;
    if (self.accessModel.quantity <= 0) self.accessModel.quantity = 1;
    self.accessModel.isNew = (self.accessModel.condition == AccessConditionsNew);
    if (!self.accessModel.ownerID.length) self.accessModel.ownerID = UserManager.sharedManager.currentUser.ID ?: @"";
    if (!self.accessModel.createdAt) self.accessModel.createdAt = NSDate.date;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return PPAccessoryFormSectionCount; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch ((PPAccessoryFormSection)s) {
        case PPAccessoryFormSectionCategory: return PPAccessoryCategoryRowCount;
        case PPAccessoryFormSectionDetails:  return PPAccessoryDetailRowCount;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    switch ((PPAccessoryFormSection)ip.section) {
        case PPAccessoryFormSectionCategory: return [self pp_categoryCellForRow:ip.row];
        case PPAccessoryFormSectionDetails:  return [self pp_detailCellForRow:ip.row];
        default: return [[UITableViewCell alloc] init];
    }
}

- (UITableViewCell *)pp_categoryCellForRow:(NSInteger)row {
    PPFormSelectorCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"PPFormSelectorCell"];
    if (!cell) cell = [[PPFormSelectorCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PPFormSelectorCell"];
    switch ((PPAccessoryCategoryRow)row) {
        case PPAccessoryCategoryRowMain: {
            NSString *t = [self pp_localizedStringForKey:@"form_species_title" fallback:@"Species"];
            NSString *v = self.draftMainKind ? [self pp_displayNameForModel:self.draftMainKind]
                : [self pp_localizedStringForKey:@"form_species_placeholder" fallback:@"Select species"];
            [cell configureWithTitle:t value:v disabled:NO];
            cell.valueLabel.textColor = self.draftMainKind ? (AppPrimaryTextClr ?: UIColor.labelColor) : UIColor.placeholderTextColor;
            break;
        }
        case PPAccessoryCategoryRowSub: {
            NSString *t = [self pp_localizedStringForKey:@"form_breed_title" fallback:@"Breed"];
            BOOL dis = (self.draftMainKind == nil);
            NSString *v = self.draftSubKind ? [self pp_displayNameForModel:self.draftSubKind]
                : [self pp_localizedStringForKey:@"form_breed_placeholder" fallback:@"Select breed"];
            [cell configureWithTitle:t value:v disabled:dis];
            cell.valueLabel.textColor = self.draftSubKind ? (AppPrimaryTextClr ?: UIColor.labelColor) : UIColor.placeholderTextColor;
            break;
        }
        default: break;
    }
    return cell;
}

- (UITableViewCell *)pp_detailCellForRow:(NSInteger)row {
    switch ((PPAccessoryDetailRow)row) {
        case PPAccessoryDetailRowName: {
            PPFormTextFieldCell *c = [self.tableView dequeueReusableCellWithIdentifier:@"PPFormTextFieldCell"];
            if (!c) c = [[PPFormTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PPFormTextFieldCell"];
            NSString *t = (self.accessKindType == AccessTypeFood)
                ? [self pp_localizedStringForKey:@"food_form_name_title" fallback:@"Food name"]
                : [self pp_localizedStringForKey:@"accessory_form_name_title" fallback:@"Accessory name"];
            NSString *p = (self.accessKindType == AccessTypeFood)
                ? [self pp_localizedStringForKey:@"food_form_name_placeholder" fallback:@"Enter food name"]
                : [self pp_localizedStringForKey:@"accessory_form_name_placeholder" fallback:@"Enter accessory name"];
            [c configureWithTitle:t text:self.draftName placeholder:p keyboardType:UIKeyboardTypeDefault
                        fieldKind:PPAccessoryFieldKindName target:self action:@selector(pp_textFieldEditingChanged:) delegate:self];
            return c;
        }
        case PPAccessoryDetailRowPrice: {
            PPFormTextFieldCell *c = [self.tableView dequeueReusableCellWithIdentifier:@"PPFormTextFieldCell"];
            if (!c) c = [[PPFormTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PPFormTextFieldCell"];
            NSString *pt = (self.draftPrice && [self.draftPrice integerValue] != 0) ? [self.draftPrice stringValue] : @"";
            [c configureWithTitle:[self pp_localizedStringForKey:@"form_price_title" fallback:@"Price"]
                             text:pt placeholder:[self pp_localizedStringForKey:@"form_price_placeholder" fallback:@"Enter price"]
                     keyboardType:UIKeyboardTypeNumberPad fieldKind:PPAccessoryFieldKindPrice
                           target:self action:@selector(pp_textFieldEditingChanged:) delegate:self];
            return c;
        }
        case PPAccessoryDetailRowDesc: {
            PPFormTextViewCell *c = [self.tableView dequeueReusableCellWithIdentifier:@"PPFormTextViewCell"];
            if (!c) c = [[PPFormTextViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PPFormTextViewCell"];
            NSString *t = (self.accessKindType == AccessTypeFood)
                ? [self pp_localizedStringForKey:@"food_form_desc_title" fallback:@"Description"]
                : [self pp_localizedStringForKey:@"accessory_form_desc_title" fallback:@"Description"];
            [c configureWithTitle:t text:self.draftDesc
                      placeholder:[self pp_localizedStringForKey:@"form_desc_placeholder" fallback:@"Add details"]
                        fieldKind:PPAccessoryFieldKindDesc delegate:self];
            return c;
        }
        default: return [[UITableViewCell alloc] init];
    }
}

- (NSString *)pp_displayNameForModel:(id)m {
    if ([m isKindOfClass:[MainKindsModel class]]) {
        NSString *n = ((MainKindsModel *)m).KindName;
        if (n.length > 0) return n;
    }
    if ([m isKindOfClass:[SubKindModel class]]) {
        NSString *n = ((SubKindModel *)m).SubKindName;
        if (n.length > 0) return n;
    }
    if ([m respondsToSelector:@selector(name)]) {
        NSString *n = [m performSelector:@selector(name)];
        if ([n isKindOfClass:NSString.class] && n.length > 0) return n;
    }
    return @"";
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip {
    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    UIColor *accessBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.85 green:0.80 blue:0.78 alpha:0.10];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
    }];
    cell.contentView.layer.borderColor = [accessBorderColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    cell.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    cell.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.02 : 0.05;
    cell.layer.shadowRadius = 12.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;
}

- (BOOL)tableView:(UITableView *)tv shouldHighlightRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == PPAccessoryFormSectionCategory) {
        return !(ip.row == PPAccessoryCategoryRowSub && !self.draftMainKind);
    }
    return NO;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != PPAccessoryFormSectionCategory) return;
    [self.view endEditing:YES];
    if (ip.row == PPAccessoryCategoryRowMain) [self pp_presentMainCategoryPicker];
    else if (ip.row == PPAccessoryCategoryRowSub && self.draftMainKind) [self pp_presentSubCategoryPicker];
}

#pragma mark - Section Headers


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0 || indexPath.row == 1) {
        return 74.0;
    }
    
    return UITableViewAutomaticDimension;
}



- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 73.0; }
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s { return 0.000001; }
- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)s { return [UIView new]; }

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    NSString *t = @"", *sub = @"";
    switch ((PPAccessoryFormSection)s) {
        case PPAccessoryFormSectionCategory:
            t = (self.accessKindType == AccessTypeAccessory)
                ? [self pp_localizedStringForKey:@"accessory_form_category_section_title" fallback:@"Category"]
                : [self pp_localizedStringForKey:@"food_form_category_section_title" fallback:@"Category"];
            break;
        case PPAccessoryFormSectionDetails:
            t = (self.accessKindType == AccessTypeFood)
                ? [self pp_localizedStringForKey:@"food_form_details_section_title" fallback:@"Details"]
                : [self pp_localizedStringForKey:@"accessory_form_details_section_title" fallback:@"Details"];
            break;
        default: break;
    }
    return [self pp_sectionHeaderViewWithTitle:t subtitle:sub];
}

- (UIView *)pp_sectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *c = [[UIView alloc] init]; c.backgroundColor = UIColor.clearColor;
    UIView *ab = [[UIView alloc] init]; ab.translatesAutoresizingMaskIntoConstraints = NO;
    ab.backgroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor; ab.layer.cornerRadius = 2.0;
    [c addSubview:ab];
    UILabel *tl = [[UILabel alloc] init]; tl.translatesAutoresizingMaskIntoConstraints = NO;
    tl.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    tl.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    tl.text = title ?: @""; tl.textAlignment = Language.alignmentForCurrentLanguage;
    [c addSubview:tl];
    UILabel *sl = [[UILabel alloc] init]; sl.translatesAutoresizingMaskIntoConstraints = NO;
    sl.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    sl.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
    sl.text = subtitle ?: @""; sl.textAlignment = Language.alignmentForCurrentLanguage; sl.numberOfLines = 2;
    [c addSubview:sl];
    [NSLayoutConstraint activateConstraints:@[
        [ab.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:20.0],
        [ab.topAnchor constraintEqualToAnchor:c.topAnchor constant:14.0],
        [ab.widthAnchor constraintEqualToConstant:28.0], [ab.heightAnchor constraintEqualToConstant:4.0],
        [tl.topAnchor constraintEqualToAnchor:ab.bottomAnchor constant:9.0],
        [tl.leadingAnchor constraintEqualToAnchor:ab.leadingAnchor],
        [tl.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-20.0],
        [sl.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:4.0],
        [sl.leadingAnchor constraintEqualToAnchor:tl.leadingAnchor],
        [sl.trailingAnchor constraintEqualToAnchor:tl.trailingAnchor],
        [sl.bottomAnchor constraintLessThanOrEqualToAnchor:c.bottomAnchor constant:-8.0]
    ]];
    return c;
}

#pragma mark - Selector Pickers

- (void)pp_presentMainCategoryPicker {
    __weak typeof(self) ws = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:MKM.MainKindsArray
                  title:[self pp_localizedStringForKey:@"form_species_selector_title" fallback:@"Select species"]
                    row:nil presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable obj) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            if (![obj isKindOfClass:[MainKindsModel class]]) {
                s.selectedKind = nil; s.draftMainKind = nil;
                s.accessModel.petMainCategoryID = 0; s.accessModel.petSubCategoryID = 0; s.draftSubKind = nil;
            } else {
                s.selectedKind = obj; s.draftMainKind = obj;
                s.accessModel.petMainCategoryID = s.selectedKind.ID; s.accessModel.petSubCategoryID = 0; s.draftSubKind = nil;
                if (!s.isHydratingFormData) s.hasUserModifiedForm = YES;
            }
            CGPoint savedOffset = s.tableView.contentOffset;
            [UIView performWithoutAnimation:^{
                [s.tableView reloadRowsAtIndexPaths:@[
                    [NSIndexPath indexPathForRow:PPAccessoryCategoryRowMain inSection:PPAccessoryFormSectionCategory],
                    [NSIndexPath indexPathForRow:PPAccessoryCategoryRowSub  inSection:PPAccessoryFormSectionCategory]
                ] withRowAnimation:UITableViewRowAnimationNone];
            }];
            [s.tableView layoutIfNeeded];
            s.tableView.contentOffset = savedOffset;
        });
    }];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

- (void)pp_presentSubCategoryPicker {
    if (!self.draftMainKind) return;
    __weak typeof(self) ws = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:self.selectedKind.SubKindsArray ?: @[]
                  title:[self pp_localizedStringForKey:@"form_breed_selector_title" fallback:@"Select breed"]
                    row:nil presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable obj) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            if ([obj isKindOfClass:[SubKindModel class]]) {
                s.draftSubKind = obj; s.accessModel.petSubCategoryID = ((SubKindModel *)obj).ID;
            } else { s.draftSubKind = nil; s.accessModel.petSubCategoryID = 0; }
            if (!s.isHydratingFormData) s.hasUserModifiedForm = YES;
            CGPoint savedOffset = s.tableView.contentOffset;
            [UIView performWithoutAnimation:^{
                [s.tableView reloadRowsAtIndexPaths:@[
                    [NSIndexPath indexPathForRow:PPAccessoryCategoryRowSub inSection:PPAccessoryFormSectionCategory]
                ] withRowAnimation:UITableViewRowAnimationNone];
            }];
            [s.tableView layoutIfNeeded];
            s.tableView.contentOffset = savedOffset;
        });
    }];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate + Editing Changed

- (void)pp_textFieldEditingChanged:(UITextField *)tf {
    NSString *v = tf.text ?: @"";
    switch ((PPAccessoryFieldKind)tf.tag) {
        case PPAccessoryFieldKindName: self.draftName = v; self.accessModel.name = v; break;
        case PPAccessoryFieldKindPrice: { NSNumber *p = [self pp_numberFromValue:v]; self.draftPrice = p; self.accessModel.price = p ?: @0; break; }
        default: break;
    }
    if (!self.isHydratingFormData) self.hasUserModifiedForm = YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    if (tf.tag == PPAccessoryFieldKindName) {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:PPAccessoryDetailRowPrice inSection:PPAccessoryFormSectionDetails];
        PPFormTextFieldCell *pc = [self.tableView cellForRowAtIndexPath:ip];
        if ([pc isKindOfClass:PPFormTextFieldCell.class]) [pc.textField becomeFirstResponder];
    } else { [tf resignFirstResponder]; }
    return YES;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)tv {
    if ((PPAccessoryFieldKind)tv.tag == PPAccessoryFieldKindDesc) { self.draftDesc = tv.text ?: @""; self.accessModel.desc = self.draftDesc; }
    UIView *v = tv;
    while (v && ![v isKindOfClass:PPFormTextViewCell.class]) v = v.superview;
    if ([v isKindOfClass:PPFormTextViewCell.class]) { [(PPFormTextViewCell *)v updatePlaceholderVisibility]; [(PPFormTextViewCell *)v updatePreferredHeight]; }
    [UIView setAnimationsEnabled:NO];
    [self.tableView beginUpdates]; [self.tableView endUpdates];
    [UIView setAnimationsEnabled:YES];
    if (!self.isHydratingFormData) self.hasUserModifiedForm = YES;
}

#pragma mark - Submission

- (NSError *)pp_uploadErrorWithCode:(NSInteger)code description:(NSString *)desc {
    return [NSError errorWithDomain:PPAddAccessoryErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: desc.length ? desc : @"Failed to upload images."}];
}

- (UIImage *)pp_normalizedImageForUpload:(UIImage *)img {
    if (!img || img.size.width <= 0 || img.size.height <= 0) return nil;
    CGSize ts = img.size;
    CGFloat ls = MAX(ts.width, ts.height);
    if (ls > PPAddAccessoryUploadMaxDimension) { CGFloat sc = PPAddAccessoryUploadMaxDimension / ls; ts = CGSizeMake(ts.width*sc, ts.height*sc); }
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat]; fmt.scale = 1.0; fmt.opaque = NO;
    UIImage *n = [[[UIGraphicsImageRenderer alloc] initWithSize:ts format:fmt] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [img drawInRect:CGRectMake(0, 0, ts.width, ts.height)];
    }];
    return n ?: img;
}

- (NSArray<UIImage *> *)pp_normalizedImagesForSubmitWithError:(NSError **)error {
    NSArray<UIImage *> *imgs = [self.imageCollection allImages] ?: @[];
    if (imgs.count == 0) { if (error) *error = [self pp_uploadErrorWithCode:100 description:[self pp_localizedStringForKey:@"please_add_photos_before_submit" fallback:@"Please add at least one image before posting."]]; return nil; }
    if (imgs.count > PPAddAccessoryMaxImageCount) { if (error) *error = [self pp_uploadErrorWithCode:101 description:[NSString stringWithFormat:@"Maximum %ld images are allowed.", (long)PPAddAccessoryMaxImageCount]]; return nil; }
    NSMutableArray<UIImage *> *out = [NSMutableArray arrayWithCapacity:imgs.count];
    for (NSInteger i = 0; i < imgs.count; i++) {
        UIImage *p = [self pp_normalizedImageForUpload:imgs[i]];
        if (!p) { if (error) *error = [self pp_uploadErrorWithCode:102 description:[NSString stringWithFormat:@"Failed to prepare image at index %ld.", (long)i+1]]; return nil; }
        [out addObject:p];
    }
    return out.copy;
}

- (void)uploadAd {
    if (![PPNetworkRetryHelper isNetworkAvailable]) { [PPAlertHelper showWarningIn:self title:kLang(@"offline_action_title") subtitle:kLang(@"offline_action_message") completion:nil]; return; }
    if (UserManager.sharedManager.isCurrentUserBlocked) { [self pp_handleLiveBlockedStateIfNeeded]; return; }
    if (self.isSubmittingAccessory) return;
    if (![self pp_validateFormWithShake]) return;
    [self pp_syncModelFromDraftProperties];
    NSError *ne = nil;
    NSArray<UIImage *> *ni = [self pp_normalizedImagesForSubmitWithError:&ne];
    if (ni.count == 0) {
        [PPAlertHelper showErrorIn:self title:[self pp_localizedStringForKey:@"error" fallback:@"Error"]
                          subtitle:ne.localizedDescription ?: [self pp_localizedStringForKey:@"Something went wrong" fallback:@"Something went wrong."]];
        return;
    }
    BOOL isEdit = (self.formMode == AccessFormModeEdit);
    if (isEdit && self.accessModel.accessoryID.length == 0) {
        [PPAlertHelper showErrorIn:self title:[self pp_localizedStringForKey:@"error" fallback:@"Error"]
                          subtitle:[self pp_localizedStringForKey:@"missing_accessory_id" fallback:@"Missing accessory ID. Please reopen and try again."]];
        return;
    }
    [self pp_beginSubmitUI];
    [self pp_submitAccessoryIsEditing:isEdit images:ni];
}

#pragma mark - Validation

- (BOOL)pp_validateFormWithShake {
    BOOL ok = YES;
    if (!self.draftMainKind) {
        UITableViewCell *c = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:PPAccessoryCategoryRowMain inSection:PPAccessoryFormSectionCategory]];
        if (c) [self pp_shakeCell:c]; ok = NO;
    }
    NSString *nm = [PPAccessorySafeString(self.draftName) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (nm.length == 0) {
        UITableViewCell *c = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:PPAccessoryDetailRowName inSection:PPAccessoryFormSectionDetails]];
        if (c) [self pp_shakeCell:c]; ok = NO;
    }
    NSNumber *pr = [self pp_numberFromValue:self.draftPrice];
    if (!pr || [pr doubleValue] <= 0) {
        UITableViewCell *c = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:PPAccessoryDetailRowPrice inSection:PPAccessoryFormSectionDetails]];
        if (c) [self pp_shakeCell:c]; ok = NO;
    }
    return ok;
}

- (void)pp_shakeCell:(UITableViewCell *)cell {
    CAKeyframeAnimation *a = [CAKeyframeAnimation animation];
    a.keyPath = @"position.x";
    a.values = @[@0, @20, @-20, @10, @0];
    a.keyTimes = @[@0, @(1/6.0), @(3/6.0), @(5/6.0), @1];
    a.duration = 0.3; a.additive = YES;
    [cell.layer addAnimation:a forKey:@"shake"];
}

#pragma mark - Upload Timeout

- (void)pp_cancelUploadTimeout { if (self.uploadTimeoutBlock) { dispatch_block_cancel(self.uploadTimeoutBlock); self.uploadTimeoutBlock = nil; } }

- (void)pp_scheduleUploadTimeout {
    [self pp_cancelUploadTimeout];
    __weak typeof(self) ws = self;
    dispatch_block_t tb = dispatch_block_create(0, ^{
        __strong typeof(ws) s = ws; if (!s) return; s.uploadTimeoutBlock = nil;
        if (s.isSubmittingAccessory) {
            s.isSubmittingAccessory = NO; s.tableView.userInteractionEnabled = YES; s.imageCollection.userInteractionEnabled = YES;
            [s pp_setSubmitEnabled:YES]; [s pp_hideUploadIndicatorOnNavBar];
            if (s.isProgressAnimating) { [s.uploadProgressView stopAnimating]; s.isProgressAnimating = NO; }
            [s pp_showUploadTimeoutError];
        }
    });
    self.uploadTimeoutBlock = tb;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), tb);
}

- (void)pp_showUploadTimeoutError {
    if (self.presentedViewController) return;
    UIAlertController *al = [UIAlertController alertControllerWithTitle:kLang(@"upload_timeout_title") message:kLang(@"upload_timeout_message") preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) ws = self;
    [al addAction:[UIAlertAction actionWithTitle:kLang(@"KLang_Retry") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [ws uploadAd]; }]];
    [al addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:al animated:YES completion:nil];
}

- (void)pp_beginSubmitUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isSubmittingAccessory) return;
        self.isSubmittingAccessory = YES;
        self.tableView.userInteractionEnabled = NO; self.imageCollection.userInteractionEnabled = NO;
        [self pp_setSubmitEnabled:NO]; [self pp_showUploadIndicatorOnNavBar];
        if (!self.isProgressAnimating) { [self.uploadProgressView startAnimating]; self.isProgressAnimating = YES; }
        [self pp_scheduleUploadTimeout];
    });
}

- (void)pp_finishSubmitUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_cancelUploadTimeout];
        if (!self.isSubmittingAccessory && !self.isProgressAnimating) { [self pp_hideUploadIndicatorOnNavBar]; return; }
        self.isSubmittingAccessory = NO;
        self.tableView.userInteractionEnabled = YES; self.imageCollection.userInteractionEnabled = YES;
        [self pp_setSubmitEnabled:YES]; [self pp_hideUploadIndicatorOnNavBar];
        if (self.isProgressAnimating) { [self.uploadProgressView stopAnimating]; self.isProgressAnimating = NO; }
    });
}

- (void)pp_submitAccessoryIsEditing:(BOOL)isEdit images:(NSArray<UIImage *> *)images {
    if (!isEdit && self.accessModel.accessoryID.length == 0) self.accessModel.accessoryID = NSUUID.UUID.UUIDString;
    [[PetAccessoryManager sharedManager] createAccessory:self.accessModel images:images completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { [self pp_handleSubmitFailure:error]; return; }
            [self clearSavedDraft]; [self pp_finishSubmitUI]; [self showSuccessAlertForEditing:isEdit];
        });
    }];
}

- (void)pp_handleSubmitFailure:(NSError *)error {
    NSString *t = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
    NSString *fb = [self pp_localizedStringForKey:@"submit_failed" fallback:@"Unable to save your accessory right now. Please try again."];
    NSString *sub = error.localizedDescription.length ? error.localizedDescription : fb;
    dispatch_async(dispatch_get_main_queue(), ^{ [PPAlertHelper showErrorIn:self title:t subtitle:sub]; [self pp_finishSubmitUI]; });
}

- (void)showSuccessAlertForEditing:(BOOL)isEdit {
    NSString *t = @"", *m = @"";
    if (isEdit) {
        t = (self.accessKindType == AccessTypeFood)
            ? [self pp_localizedStringForKey:@"food_updated_title" fallback:@"Food Updated!"]
            : [self pp_localizedStringForKey:@"accessory_updated_title" fallback:@"Accessory Updated!"];
        m = (self.accessKindType == AccessTypeFood)
            ? [self pp_localizedStringForKey:@"food_updated_desc" fallback:@"Your food item was updated successfully."]
            : [self pp_localizedStringForKey:@"accessory_updated_desc" fallback:@"Your accessory was updated successfully."];
    } else {
        t = (self.accessKindType == AccessTypeFood)
            ? [self pp_localizedStringForKey:@"Food Posted!" fallback:@"Food Posted!"]
            : [self pp_localizedStringForKey:@"Accessory Posted!" fallback:@"Accessory Posted!"];
        m = (self.accessKindType == AccessTypeFood)
            ? [self pp_localizedStringForKey:@"Your food item has been listed successfully." fallback:@"Your food item has been listed successfully."]
            : [self pp_localizedStringForKey:@"Your accessory has been listed successfully." fallback:@"Your accessory has been listed successfully."];
    }
    __weak typeof(self) ws = self;
    [PPAlertHelper showSuccessIn:self title:t subtitle:m confirmAction:^(NSString * _Nullable text, BOOL ok) {
        if (!ok) return;
        if (ws.onFinish) ws.onFinish(ws.accessModel, isEdit);
        [ws pp_dismissForm];
    } cancelAction:^{}];
}

#pragma mark - Live Block Handling

- (void)pp_handleBlockedStateNotification:(NSNotification *)n {
    NSNumber *bv = n.userInfo[PPUserManagerBlockedStateUserInfoKey];
    if ([bv respondsToSelector:@selector(boolValue)] && bv.boolValue) [self pp_handleLiveBlockedStateIfNeeded];
}

- (void)pp_handleLiveBlockedStateIfNeeded {
    if (self.hasHandledLiveBlockedState) return;
    self.hasHandledLiveBlockedState = YES;
    [self pp_finishSubmitUI]; [self pp_setSubmitEnabled:NO];
    [PPAlertHelper showErrorIn:self
        title:[self pp_localizedStringForKey:@"AccountBlockedTitle" fallback:@"Account blocked"]
        subtitle:[self pp_localizedStringForKey:@"AccountBlockedMessage" fallback:@"Your account was blocked. You can no longer add new accessories."]];
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (ws.navigationController.viewControllers.firstObject == ws) { [ws.navigationController dismissViewControllerAnimated:YES completion:nil]; return; }
        [ws.navigationController popViewControllerAnimated:YES];
    });
}

#pragma mark - First Responder UX

- (void)pp_focusFirstFieldIfNeeded {
    if (self.didFocusFirstField || self.formMode == AccessFormModeEdit || self.isSubmittingAccessory) return;
    self.didFocusFirstField = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *ip = [NSIndexPath indexPathForRow:PPAccessoryDetailRowName inSection:PPAccessoryFormSectionDetails];
        [self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        [self.tableView layoutIfNeeded];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];
        if ([cell isKindOfClass:PPFormTextFieldCell.class]) [((PPFormTextFieldCell *)cell).textField becomeFirstResponder];
    });
}

- (void)onBack { [self pp_handleBackNavigation]; }
- (void)onBack:(id)sender { (void)sender; [self pp_handleBackNavigation]; }

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self.tableView reloadData];
    }
}

@end
