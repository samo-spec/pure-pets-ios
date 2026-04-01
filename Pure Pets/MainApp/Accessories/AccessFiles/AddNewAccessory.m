#import "AddNewAccessory.h"
#import "PPImageCollection.h"
#import "UserManager.h"

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
static CGFloat const PPAddAccessoryCollectionHeight = 124.0;
static CGFloat const PPAddAccessoryFooterHeight = 144.0;
static CGFloat const PPAddAccessoryCollectionHorizontalInset = 16.0;
static CGFloat const PPAddAccessoryProgressHeight = 4.0;
static CGFloat const PPAddAccessoryUploadMaxDimension = 2048.0;

static inline NSString *PPAccessorySafeString(id value) {
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

@interface AddNewAccessory ()<PPImageCollectionDelegate>

@property (nonatomic, strong) PPImageCollection *imageCollection;
@property (nonatomic, strong) UIView *imageFooterContainer;
@property (nonatomic, strong) XLFormDescriptor *mform;
@property (nonatomic, strong) PetAccessory *accessModel;
@property (nonatomic, strong) MainKindsModel *selectedKind;
@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;

@property (nonatomic, strong) XLFormRowDescriptor *petMainCategoryIDRow;
@property (nonatomic, strong) XLFormRowDescriptor *petSubCategoryIDRow;
@property (nonatomic, strong) XLFormRowDescriptor *nameRow;
@property (nonatomic, strong) XLFormRowDescriptor *priceRow;
@property (nonatomic, strong) XLFormRowDescriptor *descRow;

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

- (UIView *)pp_modernBlurTitleViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle;

@end

@implementation AddNewAccessory

#pragma mark - Lifecycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageDidChange:)
                                                 name:PPAddAccessoryLanguageDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleBlockedStateNotification:)
                                                 name:PPUserManagerDidUpdateBlockedStateNotification
                                               object:UserManager.sharedManager];
    [self pp_refreshMediaLocalizedText];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateImageFooterLayoutIfNeeded];

    if (self.uploadProgressView) {
        [self.view bringSubviewToFront:self.uploadProgressView];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_focusFirstFieldIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_updateNavigationTitle];
    [self ios26Bar];
    [self pp_refreshMediaLocalizedText];
    [self pp_setSubmitEnabled:!self.isSubmittingAccessory];
    [UserManager.sharedManager startListeningCurrentUserBlockedState];
    [UserManager.sharedManager startListeningCurrentUserPermissionsWithChange:nil];
    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [self pp_handleLiveBlockedStateIfNeeded];
    }
   // [PPBarMgr hide];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    BOOL isTrulyExitingController =
    self.isMovingFromParentViewController ||
    self.isBeingDismissed ||
    self.navigationController.isBeingDismissed;

    if (isTrulyExitingController) {
        [self.imageCollection clearAllImages];
    }
}

- (NSString *)draftStorageKey {
    NSString *currentUserID = PPAccessorySafeString(UserManager.sharedManager.currentUser.ID);
    if (self.formMode == AccessFormModeEdit && self.editingAccessory.accessoryID.length) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@",
                PPAddAccessoryDraftDefaultsPrefix,
                self.editingAccessory.accessoryID,
                currentUserID];
    }

    return [NSString stringWithFormat:@"%@.create.%ld.%@",
            PPAddAccessoryDraftDefaultsPrefix,
            (long)self.accessKindType,
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
    [self pp_syncModelFromFormRows];

    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    if (self.accessModel.petMainCategoryID > 0) {
        snapshot[PPAddAccessoryFieldMainCategoryID] = @(self.accessModel.petMainCategoryID);
    }
    if (self.accessModel.petSubCategoryID > 0) {
        snapshot[PPAddAccessoryFieldSubCategoryID] = @(self.accessModel.petSubCategoryID);
    }

    NSString *name = [PPAccessorySafeString(self.accessModel.name) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length) {
        snapshot[PPAddAccessoryFieldName] = name;
    }

    NSNumber *price = [self pp_numberFromValue:self.priceRow.value];
    if (price) {
        snapshot[PPAddAccessoryFieldPrice] = price;
    }

    NSString *desc = [PPAccessorySafeString(self.accessModel.desc) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (desc.length) {
        snapshot[PPAddAccessoryFieldDescription] = desc;
    }

    return snapshot.copy;
}

- (NSString *)writeDraftImage:(UIImage *)image
                        named:(NSString *)fileName
                    directory:(NSString *)directory {
    if (!image || fileName.length == 0 || directory.length == 0) return nil;

    NSData *imageData = UIImageJPEGRepresentation(image, 0.88);
    if (!imageData) {
        imageData = UIImagePNGRepresentation(image);
    }
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
        NSString *fileName = [NSString stringWithFormat:@"%@_%lu.jpg",
                              prefix,
                              (unsigned long)idx];
        NSString *path = [self writeDraftImage:image named:fileName directory:directory];
        if (path.length) {
            [paths addObject:path];
        }
    }];

    return paths.copy;
}

- (NSArray<UIImage *> *)imagesFromDraftPaths:(NSArray<NSString *> *)paths {
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    for (NSString *path in paths) {
        if (![path isKindOfClass:NSString.class] || path.length == 0) continue;
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            [images addObject:image];
        }
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

    NSArray<NSString *> *imagePaths = [self writeDraftImages:[self.imageCollection allImages]
                                                  withPrefix:@"media"
                                                   directory:directory];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[PPAddAccessoryDraftFormDataKey] = formData;
    payload[PPAddAccessoryDraftImagePathsKey] = imagePaths ?: @[];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (BOOL)restoreDraftIfNeeded {
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSDictionary *storedValues = [self unarchivedDraftObjectFromData:payload[PPAddAccessoryDraftFormDataKey]];
    if (![storedValues isKindOfClass:NSDictionary.class]) {
        [self clearSavedDraft];
        return NO;
    }

    self.isHydratingFormData = YES;

    PetAccessory *draftModel = [PetAccessory deepCopyFrom:self.accessModel] ?: [[PetAccessory alloc] init];
    draftModel.accessKindType = self.accessKindType;
    draftModel.petMainCategoryID = [storedValues[PPAddAccessoryFieldMainCategoryID] integerValue];
    draftModel.petSubCategoryID = [storedValues[PPAddAccessoryFieldSubCategoryID] integerValue];
    draftModel.name = PPAccessorySafeString(storedValues[PPAddAccessoryFieldName]);
    draftModel.price = [self pp_numberFromValue:storedValues[PPAddAccessoryFieldPrice]] ?: @0;
    draftModel.desc = PPAccessorySafeString(storedValues[PPAddAccessoryFieldDescription]);

    [self prefillFromModel:draftModel];

    NSArray<UIImage *> *draftImages = [self imagesFromDraftPaths:payload[PPAddAccessoryDraftImagePathsKey]];
    self.isHydratingMedia = YES;
    [self.imageCollection clearAllImages];
    if (draftImages.count > 0) {
        [self.imageCollection addImages:draftImages];
    }
    self.isHydratingMedia = NO;

    self.hasUserModifiedForm = NO;
    self.isHydratingFormData = NO;
    [self.tableView reloadData];
    return YES;
}

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

- (void)pp_handleBackNavigation {
    if (self.isSubmittingAccessory) {
        return;
    }

    [self.view endEditing:YES];
    if ([self pp_shouldPromptForDraftOptions]) {
        [self presentUnsavedChangesPrompt];
        return;
    }

    [self pp_dismissForm];
}

#pragma mark - Setup

- (void)initBase {
    self.mform = [XLFormDescriptor formDescriptorWithTitle:@""];

    if (!self.accessModel) {
        self.accessModel = [[PetAccessory alloc] init];
    }

    [self setBackAndCorners];
}

- (void)pp_configureModeAndModel {
    if (self.accessKindType != AccessTypeAccessory && self.accessKindType != AccessTypeFood) {
        self.accessKindType = AccessTypeAccessory;
    }

    if (self.editingAccessory) {
        self.formMode = AccessFormModeEdit;
        self.accessKindType = self.editingAccessory.accessKindType;
        self.accessModel = [PetAccessory deepCopyFrom:self.editingAccessory];
    } else {
        self.formMode = AccessFormModeCreate;
        self.accessModel = [[PetAccessory alloc] init];
        self.accessModel.accessKindType = self.accessKindType;
        self.accessModel.condition =
        (self.accessKindType == AccessTypeFood) ? AccessConditionsNew : AccessConditionsUsed;
        self.accessModel.quantity = 1;
        self.accessModel.hasOffer = NO;
        self.accessModel.isNew = (self.accessModel.condition == AccessConditionsNew);
    }
}

- (void)setBackAndCorners {
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.tableView.backgroundColor = AppClearClr;
    self.tableView.layer.cornerRadius = 0;
    self.tableView.clipsToBounds = YES;
}

- (void)pp_setupUploadProgressView {
    if (self.uploadProgressView) {
        return;
    }

    GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectZero];
    pv.translatesAutoresizingMaskIntoConstraints = NO;
    pv.progressTintColor = [GM appPrimaryColor];
    pv.backgroundColor = UIColor.whiteColor;
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
    self.imageCollection = [[PPImageCollection alloc] initWithFrame:CGRectZero
                                                      maxImageCount:PPAddAccessoryMaxImageCount
                                                          useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.useArabic = Language.isRTL;

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                              self.tableView.bounds.size.width,
                                                              PPAddAccessoryFooterHeight)];
    footer.backgroundColor = UIColor.clearColor;
    [footer addSubview:self.imageCollection];

    self.imageFooterContainer = footer;
    self.tableView.tableFooterView = footer;
    [self pp_updateImageFooterLayoutIfNeeded];
    [self pp_refreshMediaLocalizedText];
}

- (void)pp_updateImageFooterLayoutIfNeeded {
    if (!self.imageFooterContainer || !self.imageCollection) {
        return;
    }

    CGFloat tableWidth = self.tableView.bounds.size.width;
    if (tableWidth <= 0) {
        return;
    }

    CGRect footerFrame = self.imageFooterContainer.frame;
    BOOL footerNeedsResize =
    fabs(footerFrame.size.width - tableWidth) > 0.5 ||
    fabs(footerFrame.size.height - PPAddAccessoryFooterHeight) > 0.5;

    if (footerNeedsResize) {
        footerFrame.size.width = tableWidth;
        footerFrame.size.height = PPAddAccessoryFooterHeight;
        self.imageFooterContainer.frame = footerFrame;
    }

    CGFloat collectionWidth = MAX(0, tableWidth - (PPAddAccessoryCollectionHorizontalInset * 2.0));
    self.imageCollection.frame = CGRectMake(PPAddAccessoryCollectionHorizontalInset,
                                            0,
                                            collectionWidth,
                                            PPAddAccessoryCollectionHeight);

    // Reassigning tableFooterView applies frame updates reliably.
    self.tableView.tableFooterView = self.imageFooterContainer;
}

#pragma mark - Localization / Titles

- (NSString *)pp_localizedStringForKey:(NSString *)key fallback:(NSString *)fallback {
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (void)pp_refreshMediaLocalizedText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageCollection.useArabic = Language.isRTL;

        NSString *title = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"FoodPostPhotosSection" fallback:@"Food photos"]
        : [self pp_localizedStringForKey:@"AccessPostPhotosSection" fallback:@"Accessory photos"];

        self.imageCollection.titleText = title;
        [self.imageCollection setTitle:title icon:nil];

        // Rebuild add-cell menu titles (Camera/Photo Library) after language changes.
        [self.imageCollection reloadCollectionView];
    });
}

- (void)pp_handleLanguageDidChange:(NSNotification *)note {
    [self pp_refreshMediaLocalizedText];
    [self pp_updateNavigationTitle];
    [self ios26Bar];
}

- (void)pp_updateNavigationTitle {
    NSString *title = @"";
    NSString *subtitle = @"";

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

    UIView *topView = [self pp_modernBlurTitleViewWithTitle:title
                                                   subtitle:subtitle ?: nil];
    [self pp_navBarSetTitleViewCenteredSmallWidth:topView];
}

- (UIView *)pp_modernBlurTitleViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    NSString *safeTitle = title ?: @"";
    NSString *safeSubtitle = subtitle ?: @"";
    UIFont *titleFont = [GM boldFontWithSize:16];
    UIFont *subtitleFont = [GM MidFontWithSize:12];
    CGFloat maxWidth = MIN(UIScreen.mainScreen.bounds.size.width * 0.62, 240.0);

    CGFloat titleWidth =
    ceil([safeTitle boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                              attributes:@{NSFontAttributeName: titleFont}
                                 context:nil].size.width);

    CGFloat subtitleWidth = 0.0;
    if (safeSubtitle.length) {
        subtitleWidth =
        ceil([safeSubtitle boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                     attributes:@{NSFontAttributeName: subtitleFont}
                                        context:nil].size.width);
    }

    CGFloat width = MIN(MAX(MAX(titleWidth, subtitleWidth) + 36.0, 156.0), maxWidth);
    CGFloat height = safeSubtitle.length ? 50.0 : 42.0;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    container.backgroundColor = UIColor.clearColor;
    container.userInteractionEnabled = NO;
    container.semanticContentAttribute =
    Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                   : UISemanticContentAttributeForceLeftToRight;

    CGFloat cornerRadius = height / 2.0;
    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blurView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
        blurView.frame = container.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = cornerRadius;
        blurView.layer.masksToBounds = YES;
        [container addSubview:blurView];

        UIView *tintView = [[UIView alloc] initWithFrame:blurView.bounds];
        tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tintView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.08];
        [blurView.contentView addSubview:tintView];
    } else {
        container.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.12];
    }

    container.layer.cornerRadius = cornerRadius;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.16 : 0.10].CGColor;
    container.layer.shadowColor = [AppShadowClr colorWithAlphaComponent:0.18].CGColor;
    container.layer.shadowOffset = CGSizeMake(0, 8);
    container.layer.shadowOpacity = 1.0;
    container.layer.shadowRadius = 18.0;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = safeSubtitle.length ? 1.0 : 0.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    [container addSubview:stack];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = titleFont;
    titleLabel.textColor = AppPrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.numberOfLines = 1;
    titleLabel.text = safeTitle;
    [stack addArrangedSubview:titleLabel];

    if (safeSubtitle.length) {
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.font = subtitleFont;
        subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.72];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
        subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        subtitleLabel.numberOfLines = 1;
        subtitleLabel.text = safeSubtitle;
        [stack addArrangedSubview:subtitleLabel];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-16.0],
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];

    return container;
}

#pragma mark - Navigation Buttons

- (UIBarButtonItem *)pp_uploadSpinnerBarItem {
    if (self.uploadSpinnerItem) {
        return self.uploadSpinnerItem;
    }

    UIActivityIndicatorView *spinner =
    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = AppPrimaryClr;
    spinner.hidesWhenStopped = YES;
    [spinner startAnimating];

    self.uploadSpinner = spinner;
    self.uploadSpinnerItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];

    return self.uploadSpinnerItem;
}

- (void)ios26Bar {
    NSString *buttonTitle = (self.formMode == AccessFormModeEdit)
    ? [self pp_localizedStringForKey:@"saveChanges" fallback:@"Save"]
    : [self pp_localizedStringForKey:@"postAd" fallback:@"Post"];

    UIButton *saveBTN = [PPButtonHelper pp_buttonWithTitleForBar:buttonTitle
                                                        imageName:@"checkmark"
                                                           target:self
                                                           action:@selector(uploadAd)];
    self.saveButton = saveBTN;

    UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(@"checkmark") style:UIBarButtonItemStylePlain target:self action:@selector(uploadAd)];
    self.navigationItem.rightBarButtonItem = saveBarButton;

    UIButton *backBTN = [PPButtonHelper pp_buttonWithTitleForBar:nil
                                                        imageName:PPChevronName
                                                           target:self
                                                           action:@selector(onBack:)];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName) style:UIBarButtonItemStylePlain target:self action:@selector(onBack)];
    self.navigationItem.leftBarButtonItem = backBarButton;

    [self pp_setSubmitEnabled:!self.isSubmittingAccessory];
}

- (void)pp_setSubmitEnabled:(BOOL)enabled {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.saveButton.enabled = enabled;
        self.saveButton.alpha = enabled ? 1.0 : 0.6;

        if (self.navigationItem.rightBarButtonItem == self.originalRightBarButtonItem) {
            self.navigationItem.rightBarButtonItem.enabled = enabled;
        }
    });
}

- (void)pp_showUploadIndicatorOnNavBar {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.originalRightBarButtonItem) {
            self.originalRightBarButtonItem = self.navigationItem.rightBarButtonItem;
        }

        self.navigationItem.rightBarButtonItem = [self pp_uploadSpinnerBarItem];
    });
}

- (void)pp_hideUploadIndicatorOnNavBar {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.uploadSpinner stopAnimating];

        if (self.originalRightBarButtonItem) {
            self.navigationItem.rightBarButtonItem = self.originalRightBarButtonItem;
            self.originalRightBarButtonItem = nil;
        }

        self.uploadSpinnerItem = nil;
        self.uploadSpinner = nil;
    });
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Image collection updated with %ld images", (long)images.count);
        if (!self.isHydratingFormData && !self.isHydratingMedia) {
            self.hasUserModifiedForm = YES;
        }
        [self pp_refreshMediaLocalizedText];
    });
}

- (void)imageCollection:(PPImageCollection *)collection
         didSelectImage:(nonnull UIImage *)selectedImage
                AtIndex:(NSInteger)index {
    [collection presentEditorForImageAtIndex:index fromViewController:self];
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    if (![self pp_canAddMoreImagesForCollection:collection showAlert:YES]) {
        return;
    }
    [collection presentPickerFromViewController:self];
}

- (BOOL)pp_canAddMoreImagesForCollection:(PPImageCollection *)collection showAlert:(BOOL)showAlert {
    NSInteger currentCount = collection.imageCount;
    if (currentCount < collection.maxImageCount) {
        return YES;
    }

    if (showAlert) {
        NSString *title = [self pp_localizedStringForKey:@"max_images_reached"
                                                 fallback:@"Maximum images reached"];
        NSString *subtitle = [NSString stringWithFormat:@"%@ %ld",
                              [self pp_localizedStringForKey:@"max_images_hint"
                                                     fallback:@"You can upload up to"],
                              (long)collection.maxImageCount];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
    }

    return NO;
}

#pragma mark - Prefill

- (void)prefillPhotosForEdit {
    if (self.accessModel.imageURLsArray.count == 0) {
        return;
    }

    self.isHydratingMedia = YES;
    [self.imageCollection preloadImagesFromURLs:self.accessModel.imageURLsArray completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Prefilled %ld images for editing", (long)self.accessModel.imageURLsArray.count);
            self.isHydratingMedia = NO;
            [self pp_refreshMediaLocalizedText];
        });
    }];
}

- (void)prefillFromModel:(PetAccessory *)model {
    if (!model) {
        return;
    }

    self.selectedKind = [MKM mainKindForID:model.petMainCategoryID];
    self.petMainCategoryIDRow.value = self.selectedKind;

    if (self.selectedKind) {
        self.petSubCategoryIDRow.disabled = @NO;
        self.petSubCategoryIDRow.selectorOptions = self.selectedKind.SubKindsArray;

        SubKindModel *subKind = nil;
        for (SubKindModel *sub in self.selectedKind.SubKindsArray) {
            if (sub.ID == model.petSubCategoryID) {
                subKind = sub;
                break;
            }
        }
        self.petSubCategoryIDRow.value = subKind;
    } else {
        self.petSubCategoryIDRow.disabled = @YES;
        self.petSubCategoryIDRow.selectorOptions = @[];
        self.petSubCategoryIDRow.value = nil;
    }

    self.nameRow.value = model.name ?: @"";
    self.priceRow.value = model.price ?: @0;
    self.descRow.value = model.desc ?: @"";

    [self pp_syncModelFromFormRows];
    [self.tableView reloadData];
}

#pragma mark - Form

- (void)initForm {
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.clipsToBounds = YES;

    __weak typeof(self) weakSelf = self;
    XLFormSectionDescriptor *section;

    if (self.accessKindType != AccessTypeFood) {
        section = [XLFormSectionDescriptor formSectionWithTitle:
                   [self pp_localizedStringForKey:@"accessory_form_used_note_title"
                                          fallback:@"Used Accessory"]];
        [self.mform addFormSection:section];
    }

    section = [XLFormSectionDescriptor formSectionWithTitle:
               (self.accessKindType == AccessTypeAccessory)
               ? [self pp_localizedStringForKey:@"accessory_form_category_section_title" fallback:@"Category"]
               : [self pp_localizedStringForKey:@"food_form_category_section_title" fallback:@"Category"]];

    self.petMainCategoryIDRow =
    [XLFormRowDescriptor formRowDescriptorWithTag:PPAddAccessoryFieldMainCategoryID
                                          rowType:XLFormRowDescriptorTypeSelectorPush
                                            title:[self pp_localizedStringForKey:@"form_species_title" fallback:@"Species"]];
    self.petMainCategoryIDRow.required = YES;
    self.petMainCategoryIDRow.selectorOptions = MKM.MainKindsArray;
    self.petMainCategoryIDRow.selectorTitle =
    [self pp_localizedStringForKey:@"form_species_selector_title" fallback:@"Select species"];
    self.petMainCategoryIDRow.noValueDisplayText =
    [self pp_localizedStringForKey:@"form_species_placeholder" fallback:@"Select species"];

    self.petMainCategoryIDRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        if (![newValue isKindOfClass:[MainKindsModel class]]) {
            weakSelf.selectedKind = nil;
            weakSelf.accessModel.petMainCategoryID = 0;
            weakSelf.accessModel.petSubCategoryID = 0;

            weakSelf.petSubCategoryIDRow.disabled = @YES;
            weakSelf.petSubCategoryIDRow.selectorOptions = @[];
            weakSelf.petSubCategoryIDRow.value = nil;
            [weakSelf updateFormRow:weakSelf.petSubCategoryIDRow];
            return;
        }

        weakSelf.selectedKind = newValue;
        weakSelf.accessModel.petMainCategoryID = weakSelf.selectedKind.ID;
        weakSelf.accessModel.petSubCategoryID = 0;

        weakSelf.petSubCategoryIDRow.disabled = @NO;
        weakSelf.petSubCategoryIDRow.selectorOptions = weakSelf.selectedKind.SubKindsArray ?: @[];
        weakSelf.petSubCategoryIDRow.value = nil;
        [weakSelf updateFormRow:weakSelf.petSubCategoryIDRow];
    };
    self.petMainCategoryIDRow.height = 50.0;
    [section addFormRow:self.petMainCategoryIDRow];

    self.petSubCategoryIDRow =
    [XLFormRowDescriptor formRowDescriptorWithTag:PPAddAccessoryFieldSubCategoryID
                                          rowType:XLFormRowDescriptorTypeSelectorPush
                                            title:[self pp_localizedStringForKey:@"form_breed_title" fallback:@"Breed"]];
    self.petSubCategoryIDRow.required = NO;
    self.petSubCategoryIDRow.disabled = @YES;
    self.petSubCategoryIDRow.selectorOptions = @[];
    self.petSubCategoryIDRow.selectorTitle =
    [self pp_localizedStringForKey:@"form_breed_selector_title" fallback:@"Select breed"];
    self.petSubCategoryIDRow.noValueDisplayText =
    [self pp_localizedStringForKey:@"form_breed_placeholder" fallback:@"Select breed"];

    self.petSubCategoryIDRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        if ([newValue isKindOfClass:[SubKindModel class]]) {
            weakSelf.accessModel.petSubCategoryID = ((SubKindModel *)newValue).ID;
        } else {
            weakSelf.accessModel.petSubCategoryID = 0;
        }
    };
    self.petSubCategoryIDRow.height = 50.0;
    [section addFormRow:self.petSubCategoryIDRow];

    [self.mform addFormSection:section];

    section = [XLFormSectionDescriptor formSectionWithTitle:
               self.accessKindType == AccessTypeFood
               ? [self pp_localizedStringForKey:@"food_form_details_section_title" fallback:@"Details"]
               : [self pp_localizedStringForKey:@"accessory_form_details_section_title" fallback:@"Details"]];

    self.nameRow =
    [XLFormRowDescriptor formRowDescriptorWithTag:PPAddAccessoryFieldName
                                          rowType:XLFormRowDescriptorTypeText
                                            title:(self.accessKindType == AccessTypeFood
                                                   ? [self pp_localizedStringForKey:@"food_form_name_title" fallback:@"Food name"]
                                                   : [self pp_localizedStringForKey:@"accessory_form_name_title" fallback:@"Accessory name"])];
    self.nameRow.required = YES;
    self.nameRow.height = 50.0;
    [self.nameRow.cellConfigAtConfigure setObject:
     (self.accessKindType == AccessTypeFood
      ? [self pp_localizedStringForKey:@"food_form_name_placeholder" fallback:@"Enter food name"]
      : [self pp_localizedStringForKey:@"accessory_form_name_placeholder" fallback:@"Enter accessory name"])
                                           forKey:@"textField.placeholder"];
    self.nameRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.accessModel.name = [newValue isKindOfClass:[NSString class]] ? newValue : @"";
    };
    [section addFormRow:self.nameRow];

    self.priceRow =
    [XLFormRowDescriptor formRowDescriptorWithTag:PPAddAccessoryFieldPrice
                                          rowType:XLFormRowDescriptorTypeInteger
                                            title:[self pp_localizedStringForKey:@"form_price_title" fallback:@"Price"]];
    self.priceRow.required = YES;
    self.priceRow.height = 50.0;
    [self.priceRow.cellConfigAtConfigure setObject:
     [self pp_localizedStringForKey:@"form_price_placeholder" fallback:@"Enter price"]
                                            forKey:@"textField.placeholder"];
    self.priceRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.accessModel.price = [weakSelf pp_numberFromValue:newValue] ?: @0;
    };
    [section addFormRow:self.priceRow];

    self.descRow =
    [XLFormRowDescriptor formRowDescriptorWithTag:PPAddAccessoryFieldDescription
                                          rowType:XLFormRowDescriptorTypeTextView
                                            title:(self.accessKindType == AccessTypeFood
                                                   ? [self pp_localizedStringForKey:@"food_form_desc_title" fallback:@"Description"]
                                                   : [self pp_localizedStringForKey:@"accessory_form_desc_title" fallback:@"Description"])];
    self.descRow.height = 100.0;
    [self.descRow.cellConfigAtConfigure setObject:
     [self pp_localizedStringForKey:@"form_desc_placeholder" fallback:@"Add details"]
                                           forKey:@"textView.placeholder"];
    self.descRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.accessModel.desc = [newValue isKindOfClass:[NSString class]] ? newValue : @"";
    };
    [section addFormRow:self.descRow];

    [self.mform addFormSection:section];

    self.form = self.mform;
    self.tableView.sectionFooterHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (NSNumber *)pp_numberFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *trimmed = [((NSString *)value)
                             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            return nil;
        }
        return @([trimmed doubleValue]);
    }
    return nil;
}

- (void)pp_syncModelFromFormRows {
    NSString *name = [self.nameRow.value isKindOfClass:[NSString class]] ? self.nameRow.value : @"";
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.nameRow.value = name;
    self.accessModel.name = name;

    NSNumber *price = [self pp_numberFromValue:self.priceRow.value];
    self.accessModel.price = price ?: @0;

    NSString *desc = [self.descRow.value isKindOfClass:[NSString class]] ? self.descRow.value : @"";
    self.accessModel.desc = desc;

    MainKindsModel *mainKind =
    [self.petMainCategoryIDRow.value isKindOfClass:[MainKindsModel class]]
    ? (MainKindsModel *)self.petMainCategoryIDRow.value
    : self.selectedKind;

    self.selectedKind = mainKind;
    self.accessModel.petMainCategoryID = mainKind.ID;

    SubKindModel *subKind =
    [self.petSubCategoryIDRow.value isKindOfClass:[SubKindModel class]]
    ? (SubKindModel *)self.petSubCategoryIDRow.value
    : nil;
    self.accessModel.petSubCategoryID = subKind ? subKind.ID : 0;

    self.accessModel.accessKindType = self.accessKindType;

    if (self.accessModel.condition != AccessConditionsNew &&
        self.accessModel.condition != AccessConditionsUsed) {
        self.accessModel.condition =
        (self.accessKindType == AccessTypeFood) ? AccessConditionsNew : AccessConditionsUsed;
    }

    if (self.accessModel.quantity <= 0) {
        self.accessModel.quantity = 1;
    }

    self.accessModel.isNew = (self.accessModel.condition == AccessConditionsNew);
    if (!self.accessModel.ownerID.length) {
        self.accessModel.ownerID = UserManager.sharedManager.currentUser.ID ?: @"";
    }

    if (!self.accessModel.createdAt) {
        self.accessModel.createdAt = NSDate.date;
    }
}

#pragma mark - Submission

- (NSError *)pp_uploadErrorWithCode:(NSInteger)code description:(NSString *)description {
    NSString *message = description.length ? description : @"Failed to upload images.";
    return [NSError errorWithDomain:PPAddAccessoryErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (UIImage *)pp_normalizedImageForUpload:(UIImage *)image {
    if (!image) {
        return nil;
    }
    if (image.size.width <= 0.0 || image.size.height <= 0.0) {
        return nil;
    }

    CGSize targetSize = image.size;
    CGFloat longestSide = MAX(targetSize.width, targetSize.height);
    if (longestSide > PPAddAccessoryUploadMaxDimension) {
        CGFloat scale = PPAddAccessoryUploadMaxDimension / longestSide;
        targetSize = CGSizeMake(targetSize.width * scale, targetSize.height * scale);
    }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 1.0;
    format.opaque = NO;

    UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];

    UIImage *normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    }];

    return normalized ?: image;
}

- (NSArray<UIImage *> *)pp_normalizedImagesForSubmitWithError:(NSError **)error {
    NSArray<UIImage *> *images = [self.imageCollection allImages] ?: @[];

    if (images.count == 0) {
        if (error) {
            NSString *message = [self pp_localizedStringForKey:@"please_add_photos_before_submit"
                                                      fallback:@"Please add at least one image before posting."];
            *error = [self pp_uploadErrorWithCode:100 description:message];
        }
        return nil;
    }

    if (images.count > PPAddAccessoryMaxImageCount) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Maximum %ld images are allowed.",
                                 (long)PPAddAccessoryMaxImageCount];
            *error = [self pp_uploadErrorWithCode:101 description:message];
        }
        return nil;
    }

    NSMutableArray<UIImage *> *normalized = [NSMutableArray arrayWithCapacity:images.count];
    for (NSInteger idx = 0; idx < images.count; idx++) {
        UIImage *prepared = [self pp_normalizedImageForUpload:images[idx]];
        if (!prepared) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"Failed to prepare image at index %ld.", (long)idx + 1];
                *error = [self pp_uploadErrorWithCode:102 description:message];
            }
            return nil;
        }
        [normalized addObject:prepared];
    }

    return [normalized copy];
}

- (void)uploadAd {
    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [self pp_handleLiveBlockedStateIfNeeded];
        return;
    }

    if (self.isSubmittingAccessory) {
        return;
    }

    NSArray *errors = [self formValidationErrors];
    if (errors.count > 0) {
        [self highlightErrors:errors];
        return;
    }

    [self pp_syncModelFromFormRows];

    NSError *normalizationError = nil;
    NSArray<UIImage *> *normalizedImages = [self pp_normalizedImagesForSubmitWithError:&normalizationError];
    if (normalizedImages.count == 0) {
        NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
        NSString *subtitle = normalizationError.localizedDescription ?: [self pp_localizedStringForKey:@"Something went wrong" fallback:@"Something went wrong."];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    BOOL isEditing = (self.formMode == AccessFormModeEdit);

    if (isEditing && self.accessModel.accessoryID.length == 0) {
        NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
        NSString *subtitle = [self pp_localizedStringForKey:@"missing_accessory_id"
                                                   fallback:@"Missing accessory ID. Please reopen and try again."];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    [self pp_beginSubmitUI];
    [self pp_submitAccessoryIsEditing:isEditing images:normalizedImages];
}

- (void)pp_beginSubmitUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isSubmittingAccessory) {
            return;
        }

        self.isSubmittingAccessory = YES;
        self.form.disabled = YES;
        self.mform.disabled = YES;
        self.imageCollection.userInteractionEnabled = NO;

        [self pp_setSubmitEnabled:NO];
        [self pp_showUploadIndicatorOnNavBar];

        if (!self.isProgressAnimating) {
            [self.uploadProgressView startAnimating];
            self.isProgressAnimating = YES;
        }
    });
}

- (void)pp_finishSubmitUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isSubmittingAccessory && !self.isProgressAnimating) {
            [self pp_hideUploadIndicatorOnNavBar];
            return;
        }

        self.isSubmittingAccessory = NO;
        self.form.disabled = NO;
        self.mform.disabled = NO;
        self.imageCollection.userInteractionEnabled = YES;

        [self pp_setSubmitEnabled:YES];
        [self pp_hideUploadIndicatorOnNavBar];

        if (self.isProgressAnimating) {
            [self.uploadProgressView stopAnimating];
            self.isProgressAnimating = NO;
        }
    });
}

- (void)pp_submitAccessoryIsEditing:(BOOL)isEditing images:(NSArray<UIImage *> *)images {
    if (!isEditing && self.accessModel.accessoryID.length == 0) {
        self.accessModel.accessoryID = NSUUID.UUID.UUIDString;
    }

    [[PetAccessoryManager sharedManager] createAccessory:self.accessModel
                                                  images:images
                                              completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self pp_handleSubmitFailure:error];
                return;
            }

            [self clearSavedDraft];
            [self pp_finishSubmitUI];
            [self showSuccessAlertForEditing:isEditing];
        });
    }];
}

- (void)pp_handleSubmitFailure:(NSError *)error {
    NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
    NSString *fallbackSubtitle =
    [self pp_localizedStringForKey:@"submit_failed"
                          fallback:@"Unable to save your accessory right now. Please try again."];
    NSString *subtitle = error.localizedDescription.length ? error.localizedDescription : fallbackSubtitle;

    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        [self pp_finishSubmitUI];
    });
}

- (void)showSuccessAlertForEditing:(BOOL)isEditing {
    NSString *title = @"";
    NSString *message = @"";

    if (isEditing) {
        title = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"food_updated_title" fallback:@"Food Updated!"]
        : [self pp_localizedStringForKey:@"accessory_updated_title" fallback:@"Accessory Updated!"];

        message = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"food_updated_desc" fallback:@"Your food item was updated successfully."]
        : [self pp_localizedStringForKey:@"accessory_updated_desc" fallback:@"Your accessory was updated successfully."];
    } else {
        title = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"Food Posted!" fallback:@"Food Posted!"]
        : [self pp_localizedStringForKey:@"Accessory Posted!" fallback:@"Accessory Posted!"];

        message = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"Your food item has been listed successfully." fallback:@"Your food item has been listed successfully."]
        : [self pp_localizedStringForKey:@"Your accessory has been listed successfully." fallback:@"Your accessory has been listed successfully."];
    }

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showSuccessIn:self
                           title:title
                        subtitle:message
                   confirmAction:^(NSString * _Nullable text, BOOL didConfirm) {
        if (!didConfirm) {
            return;
        }

        if (weakSelf.onFinish) {
            weakSelf.onFinish(weakSelf.accessModel, isEditing);
        }

        [weakSelf pp_dismissForm];
    } cancelAction:^{}];
}

- (void)highlightErrors:(NSArray *)errors {
    for (id obj in errors) {
        XLFormValidationStatus *status = [obj userInfo][XLValidationStatusErrorKey];
        if (!status) {
            continue;
        }

        UITableViewCell *cell =
        [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:status.rowDescriptor]];
        if (cell) {
            [GM animateCell:cell];
        }
    }
}

#pragma mark - Live Block Handling

- (void)pp_handleBlockedStateNotification:(NSNotification *)notification {
    NSNumber *blockedValue = notification.userInfo[PPUserManagerBlockedStateUserInfoKey];
    if ([blockedValue respondsToSelector:@selector(boolValue)] && blockedValue.boolValue) {
        [self pp_handleLiveBlockedStateIfNeeded];
    }
}

- (void)pp_handleLiveBlockedStateIfNeeded {
    if (self.hasHandledLiveBlockedState) {
        return;
    }
    self.hasHandledLiveBlockedState = YES;

    [self pp_finishSubmitUI];
    [self pp_setSubmitEnabled:NO];

    NSString *title = [self pp_localizedStringForKey:@"AccountBlockedTitle" fallback:@"Account blocked"];
    NSString *subtitle = [self pp_localizedStringForKey:@"AccountBlockedMessage" fallback:@"Your account was blocked. You can no longer add new accessories."];

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (weakSelf.navigationController.viewControllers.firstObject == weakSelf) {
            [weakSelf.navigationController dismissViewControllerAnimated:YES completion:nil];
            return;
        }
        [weakSelf.navigationController popViewControllerAnimated:YES];
    });
}

#pragma mark - First Responder UX

- (void)pp_focusFirstFieldIfNeeded {
    if (self.didFocusFirstField || self.formMode == AccessFormModeEdit || self.isSubmittingAccessory) {
        return;
    }
    self.didFocusFirstField = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [self.form indexPathOfFormRow:self.nameRow];
        if (!indexPath) {
            return;
        }

        [self.tableView scrollToRowAtIndexPath:indexPath
                              atScrollPosition:UITableViewScrollPositionMiddle
                                      animated:NO];
        [self.tableView layoutIfNeeded];

        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([cell respondsToSelector:@selector(becomeFirstResponder)]) {
            [cell becomeFirstResponder];
        }
    });
}

- (void)onBack
{
    [self pp_handleBackNavigation];
}

- (void)onBack:(id)sender
{
    (void)sender;
    [self pp_handleBackNavigation];
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)formRow
                                oldValue:(id)oldValue
                                newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:formRow oldValue:oldValue newValue:newValue];

    if (!self.isHydratingFormData) {
        self.hasUserModifiedForm = YES;
    }
}

#pragma mark - Table View Appearance

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
}

@end
