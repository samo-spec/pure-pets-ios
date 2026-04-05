//
//  AddAdoptPetViewController.m
//  Pure Pets
//
//  Adopt create/edit form with PPImageCollection media flow.
//

#import "AddAdoptPetViewController.h"
#import "AdoptPetManager.h"
#import "PPImageCollection.h"
#import "PPAlertHelper.h"

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
static NSString * const kAdoptDraftDefaultsPrefix = @"pp.add_adopt_pet.draft";
static NSString * const kAdoptDraftFormDataKey = @"formData";
static NSString * const kAdoptDraftImagePathsKey = @"imagePaths";

static CGFloat const kAdoptMediaFooterHeight = 148.0;
static CGFloat const kAdoptMediaInset = 16.0;

static inline NSString *PPAdoptSafeString(id value) {
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

@interface AddAdoptPetViewController () <PPImageCollectionDelegate>
@property (nonatomic, strong) MainKindsModel *selectedMainKindModel;
@property (nonatomic, strong) SubKindModel *selectedSubKindModel;
@property (nonatomic, strong) CityModel *selectedCity;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL isPrefillInProgress;

@property (nonatomic, strong) PPImageCollection *imageCollection;
@property (nonatomic, strong) UIView *imageFooterContainer;
@property (nonatomic, strong) UIView *prefillLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *prefillLoadingSpinner;
@property (nonatomic, strong) UILabel *prefillLoadingLabel;
@property (nonatomic, strong) UIBarButtonItem *saveBarButton;
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
    self.tableView.backgroundColor = UIColor.clearColor;
    self.isHydratingFormData = YES;
    self.hasUserModifiedForm = NO;
   // self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self setNavButtons];
    [self buildForm];
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
     
    [self pp_refreshTitle];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateImageFooterLayoutIfNeeded];
}

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
    NSDictionary *values = [self.form formValues];
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];

    NSString *name = [PPAdoptSafeString(values[kRowName]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length) {
        snapshot[kRowName] = name;
    }

    if (self.selectedMainKindModel.ID > 0) {
        snapshot[kRowSpecies] = @(self.selectedMainKindModel.ID);
    }

    if (self.selectedSubKindModel.ID > 0) {
        snapshot[kRowBreed] = @(self.selectedSubKindModel.ID);
    }

    if ([values[kRowAgeMonths] respondsToSelector:@selector(integerValue)]) {
        NSInteger age = [values[kRowAgeMonths] integerValue];
        if (age > 0) {
            snapshot[kRowAgeMonths] = @(age);
        }
    }

    NSString *gender = [self pp_normalizedGenderFromFormValue:values[kRowGender]];
    if (gender.length) {
        snapshot[kRowGender] = gender;
    }

    if (self.selectedCity.cityID > 0) {
        snapshot[kRowCity] = @(self.selectedCity.cityID);
    }

    NSString *details = [PPAdoptSafeString(values[kRowDetails]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (details.length) {
        snapshot[kRowDetails] = details;
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

    NSArray<NSString *> *imagePaths = [self writeDraftImages:[self.imageCollection allImages] ?: @[]
                                                  withPrefix:@"media"
                                                   directory:directory];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[kAdoptDraftFormDataKey] = formData;
    payload[kAdoptDraftImagePathsKey] = imagePaths ?: @[];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (BOOL)restoreDraftIfNeeded {
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSDictionary *storedValues = [self unarchivedDraftObjectFromData:payload[kAdoptDraftFormDataKey]];
    if (![storedValues isKindOfClass:NSDictionary.class]) {
        [self clearSavedDraft];
        return NO;
    }

    self.isHydratingFormData = YES;

    NSString *name = PPAdoptSafeString(storedValues[kRowName]);
    if (name.length) {
        [self.form formRowWithTag:kRowName].value = name;
    }

    NSNumber *speciesID = storedValues[kRowSpecies];
    if ([speciesID respondsToSelector:@selector(integerValue)]) {
        self.selectedMainKindModel = [MainKindsModel mainKindClassForID:speciesID.integerValue
                                                                inArray:MKM.MainKindsArray];
        XLFormRowDescriptor *speciesRow = [self.form formRowWithTag:kRowSpecies];
        speciesRow.value = self.selectedMainKindModel;
        [self updateFormRow:speciesRow];
    }

    XLFormRowDescriptor *breedRow = [self.form formRowWithTag:kRowBreed];
    breedRow.selectorOptions = self.selectedMainKindModel.SubKindsArray ?: @[];
    breedRow.hidden = @(self.selectedMainKindModel == nil);
    [self updateFormRow:breedRow];

    NSNumber *breedID = storedValues[kRowBreed];
    if ([breedID respondsToSelector:@selector(integerValue)] && self.selectedMainKindModel) {
        self.selectedSubKindModel = [self.selectedMainKindModel subKindForID:breedID.integerValue];
        breedRow.value = self.selectedSubKindModel;
        [self updateFormRow:breedRow];
    }

    if ([storedValues[kRowAgeMonths] respondsToSelector:@selector(integerValue)]) {
        [self.form formRowWithTag:kRowAgeMonths].value = storedValues[kRowAgeMonths];
    }

    NSString *gender = PPAdoptSafeString(storedValues[kRowGender]);
    if (gender.length) {
        [self.form formRowWithTag:kRowGender].value = [self pp_displayGenderForStoredValue:gender];
    }

    NSNumber *cityID = storedValues[kRowCity];
    if ([cityID respondsToSelector:@selector(integerValue)] && cityID.integerValue > 0) {
        self.selectedCity = [CitiesManager.shared cityByID:cityID.integerValue];
        [self.form formRowWithTag:kRowCity].value = self.selectedCity;
    }

    NSString *details = PPAdoptSafeString(storedValues[kRowDetails]);
    if (details.length) {
        [self.form formRowWithTag:kRowDetails].value = details;
    }

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
    self.saveBarButton = [[UIBarButtonItem alloc] initWithTitle:kLang(@"save")
                                                          style:UIBarButtonItemStyleDone
                                                         target:self
                                                         action:@selector(saveTapped)];

    [self.saveBarButton setTitleTextAttributes:@{
        NSFontAttributeName : [GM boldFontWithSize:16],
        NSForegroundColorAttributeName : AppForgroundColr
    } forState:UIControlStateNormal];

    self.saveBarButton.tintColor = AppPrimaryClr;
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:kLang(@"cancel")
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(cancelTapped)];
    [cancelBtn setTitleTextAttributes:@{
        NSFontAttributeName : [GM MidFontWithSize:16],
        NSForegroundColorAttributeName : GM.SecondaryTextColor
    } forState:UIControlStateNormal];

    self.navigationItem.rightBarButtonItem = self.saveBarButton;
    self.navigationItem.leftBarButtonItem = cancelBtn;

    self.saveActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.saveActivityIndicator.hidesWhenStopped = YES;
}

- (void)cancelTapped {
    if (self.isSaving) {
        return;
    }

    [self.view endEditing:YES];
    if ([self pp_shouldPromptForDraftOptions]) {
        [self presentUnsavedChangesPrompt];
        return;
    }

    [self pp_dismissForm];
}

- (void)buildForm {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:nil];

    XLFormSectionDescriptor *basicSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:basicSection];

    XLFormRowDescriptor *nameRow = [XLFormRowDescriptor formRowDescriptorWithTag:kRowName
                                                                          rowType:XLFormRowDescriptorTypeName
                                                                            title:kLang(@"name")];
    nameRow.required = YES;
    [nameRow.cellConfigAtConfigure setObject:kLang(@"enter_pet_name")
                                      forKey:@"textField.placeholder"];
    [basicSection addFormRow:nameRow];

    __weak typeof(self) weakSelf = self;

    XLFormRowDescriptor *speciesRow = [XLFormRowDescriptor formRowDescriptorWithTag:kRowSpecies
                                                                             rowType:XLFormRowDescriptorTypeSelectorPush
                                                                               title:kLang(@"species")];
    speciesRow.required = YES;
    speciesRow.selectorTitle = kLang(@"selectSpecies");
    speciesRow.noValueDisplayText = kLang(@"selectSpecies");
    speciesRow.selectorOptions = MKM.MainKindsArray ?: @[];
    speciesRow.onChangeBlock = ^(id  _Nullable oldValue,
                                 id  _Nullable newValue,
                                 XLFormRowDescriptor * _Nonnull rowDescriptor) {
        weakSelf.selectedMainKindModel = [newValue isKindOfClass:MainKindsModel.class] ? (MainKindsModel *)newValue : nil;
        weakSelf.selectedSubKindModel = nil;

        XLFormRowDescriptor *breedRow = [weakSelf.form formRowWithTag:kRowBreed];
        breedRow.value = nil;
        breedRow.selectorTitle = kLang(@"selectCreed");
        breedRow.noValueDisplayText = kLang(@"selectCreed");
        breedRow.selectorOptions = weakSelf.selectedMainKindModel.SubKindsArray ?: @[];
        breedRow.hidden = @(weakSelf.selectedMainKindModel == nil);
        [weakSelf updateFormRow:breedRow];
    };
    [basicSection addFormRow:speciesRow];

    XLFormRowDescriptor *breedRow = [XLFormRowDescriptor formRowDescriptorWithTag:kRowBreed
                                                                           rowType:XLFormRowDescriptorTypeSelectorPush
                                                                             title:kLang(@"breed")];
    breedRow.required = YES;
    breedRow.hidden = @YES;
    breedRow.noValueDisplayText = kLang(@"selectCreed");
    breedRow.onChangeBlock = ^(id  _Nullable oldValue,
                               id  _Nullable newValue,
                               XLFormRowDescriptor * _Nonnull rowDescriptor) {
        weakSelf.selectedSubKindModel = [newValue isKindOfClass:SubKindModel.class] ? (SubKindModel *)newValue : nil;
    };
    [basicSection addFormRow:breedRow];

    XLFormRowDescriptor *ageRow = [XLFormRowDescriptor formRowDescriptorWithTag:kRowAgeMonths
                                                                         rowType:XLFormRowDescriptorTypeInteger
                                                                           title:kLang(@"ageMonths")];
    ageRow.required = YES;
    [ageRow.cellConfigAtConfigure setObject:kLang(@"enter_pet_age_in_months") forKey:@"textField.placeholder"];
    [basicSection addFormRow:ageRow];

    XLFormRowDescriptor *genderRow = [XLFormRowDescriptor formRowDescriptorWithTag:kRowGender
                                                                            rowType:XLFormRowDescriptorTypeSelectorPush
                                                                              title:kLang(@"Gender")];
    genderRow.required = YES;
    genderRow.selectorTitle = kLang(@"selectGender");
    genderRow.noValueDisplayText = kLang(@"selectGender");
    genderRow.selectorOptions = @[kLang(@"male"), kLang(@"female")];
    [basicSection addFormRow:genderRow];

    XLFormRowDescriptor *cityRow = [XLFormRowDescriptor formRowDescriptorWithTag:kRowCity
                                                                          rowType:XLFormRowDescriptorTypeSelectorPush
                                                                            title:kLang(@"city")];
    cityRow.selectorOptions = [[CitiesManager shared] citiesForCurrentCountry] ?: @[];
    cityRow.selectorTitle = kLang(@"selectCity");
    cityRow.noValueDisplayText = kLang(@"selectCity");
    cityRow.required = YES;
    cityRow.onChangeBlock = ^(id  _Nullable oldValue,
                              id  _Nullable newValue,
                              XLFormRowDescriptor * _Nonnull rowDescriptor) {
        weakSelf.selectedCity = [newValue isKindOfClass:CityModel.class] ? (CityModel *)newValue : nil;
    };
    [basicSection addFormRow:cityRow];

    XLFormSectionDescriptor *detailsSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"details")];
    [form addFormSection:detailsSection];

    XLFormRowDescriptor *detailsRow = [XLFormRowDescriptor formRowDescriptorWithTag:kRowDetails
                                                                             rowType:XLFormRowDescriptorTypeTextView];
    [detailsRow.cellConfigAtConfigure setObject:kLang(@"describePet") forKey:@"textView.placeholder"];
    [detailsSection addFormRow:detailsRow];

    self.form = form;
}

- (void)setupImageCollection {
    if (self.imageCollection) {
        return;
    }

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
    if (!self.imageFooterContainer || !self.imageCollection) {
        return;
    }

    CGFloat tableWidth = self.tableView.bounds.size.width;
    if (tableWidth <= 0) {
        return;
    }

    CGRect footerFrame = self.imageFooterContainer.frame;
    footerFrame.size.width = tableWidth;
    footerFrame.size.height = kAdoptMediaFooterHeight;
    self.imageFooterContainer.frame = footerFrame;

    CGFloat collectionWidth = MAX(0, tableWidth - (kAdoptMediaInset * 2.0));
    self.imageCollection.frame = CGRectMake(kAdoptMediaInset, 10, collectionWidth, kAdoptMediaFooterHeight - 16);
    self.tableView.tableFooterView = self.imageFooterContainer;
}

- (void)setupPrefillLoadingUI
{
    self.prefillLoadingView = [[UIView alloc] init];
    self.prefillLoadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.58];
    self.prefillLoadingView.layer.cornerRadius = 12;
    self.prefillLoadingView.layer.masksToBounds = YES;
    self.prefillLoadingView.hidden = YES;

    self.prefillLoadingSpinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.prefillLoadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingSpinner.color = UIColor.whiteColor;

    self.prefillLoadingLabel = [[UILabel alloc] init];
    self.prefillLoadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingLabel.font = [GM MidFontWithSize:12];
    self.prefillLoadingLabel.textColor = UIColor.whiteColor;
    self.prefillLoadingLabel.text = kLang(@"loading_images");

    [self.prefillLoadingView addSubview:self.prefillLoadingSpinner];
    [self.prefillLoadingView addSubview:self.prefillLoadingLabel];
    [self.view addSubview:self.prefillLoadingView];

    [NSLayoutConstraint activateConstraints:@[
        [self.prefillLoadingView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.prefillLoadingView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-22],
        [self.prefillLoadingSpinner.leadingAnchor constraintEqualToAnchor:self.prefillLoadingView.leadingAnchor constant:10],
        [self.prefillLoadingSpinner.centerYAnchor constraintEqualToAnchor:self.prefillLoadingView.centerYAnchor],
        [self.prefillLoadingLabel.leadingAnchor constraintEqualToAnchor:self.prefillLoadingSpinner.trailingAnchor constant:8],
        [self.prefillLoadingLabel.trailingAnchor constraintEqualToAnchor:self.prefillLoadingView.trailingAnchor constant:-10],
        [self.prefillLoadingLabel.topAnchor constraintEqualToAnchor:self.prefillLoadingView.topAnchor constant:8],
        [self.prefillLoadingLabel.bottomAnchor constraintEqualToAnchor:self.prefillLoadingView.bottomAnchor constant:-8]
    ]];
}

- (void)setPrefillLoadingVisible:(BOOL)visible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.prefillLoadingView.hidden = !visible;
        if (visible) {
            [self.prefillLoadingSpinner startAnimating];
        } else {
            [self.prefillLoadingSpinner stopAnimating];
        }
    });
}

- (void)preloadFormIfEditing {
    if (!self.editingPet) {
        return;
    }

    self.selectedMainKindModel = self.editingPet.mainKindModel ?: [MainKindsModel mainKindClassForID:self.editingPet.kindID
                                                                                              inArray:MKM.MainKindsArray];
    self.selectedSubKindModel = self.editingPet.subKindModel ?: [self.selectedMainKindModel subKindForID:self.editingPet.breedID];
    self.selectedCity = [CitiesManager.shared cityByID:self.editingPet.cityID];

    [self.form formRowWithTag:kRowName].value = self.editingPet.name;

    XLFormRowDescriptor *speciesRow = [self.form formRowWithTag:kRowSpecies];
    speciesRow.value = self.selectedMainKindModel;

    XLFormRowDescriptor *breedRow = [self.form formRowWithTag:kRowBreed];
    breedRow.selectorOptions = self.selectedMainKindModel.SubKindsArray ?: @[];
    breedRow.hidden = @NO;
    breedRow.value = self.selectedSubKindModel;
    [self updateFormRow:breedRow];

    [self.form formRowWithTag:kRowAgeMonths].value = @(self.editingPet.ageMonths);
    [self.form formRowWithTag:kRowGender].value = [self pp_displayGenderForStoredValue:self.editingPet.gender];
    [self.form formRowWithTag:kRowCity].value = self.selectedCity;
    [self.form formRowWithTag:kRowDetails].value = self.editingPet.details;

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
            // Reset UI state without triggering the generic error alert
            strongSelf.saveBarButton.enabled = YES;
            [strongSelf.saveActivityIndicator stopAnimating];
            strongSelf.saveBarButton.customView = nil;
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

#pragma mark - Save

- (void)saveTapped {
    if (self.isSaving) {
        return;
    }
    self.saveBarButton.enabled = NO;
    [self.saveActivityIndicator startAnimating];
    self.saveBarButton.customView = self.saveActivityIndicator;
    [self.view endEditing:YES];

    NSArray<NSError *> *validationErrors = [self formValidationErrors];
    NSMutableSet<NSString *> *invalidTags = [NSMutableSet set];
    for (NSError *error in validationErrors) {
        XLFormValidationStatus *status = error.userInfo[XLValidationStatusErrorKey];
        if (status.rowDescriptor.tagM.length > 0) {
            [invalidTags addObject:status.rowDescriptor.tagM];
        }
    }

    NSDictionary *values = [self.form formValues];
    NSString *name = [PPAdoptSafeString(values[kRowName]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger age = [values[kRowAgeMonths] integerValue];

    if (name.length == 0) [invalidTags addObject:kRowName];
    if (!self.selectedMainKindModel) [invalidTags addObject:kRowSpecies];
    if (!self.selectedSubKindModel) [invalidTags addObject:kRowBreed];
    if (!self.selectedCity) [invalidTags addObject:kRowCity];
    if (age <= 0) [invalidTags addObject:kRowAgeMonths];

    NSArray<UIImage *> *images = [self.imageCollection allImages] ?: @[];
    BOOL hasExistingURLs = self.editingPet.imageURLs.count > 0;
    if (!self.editingPet && images.count == 0) {
        [self showErrorMessage:kLang(@"pleaseSelectAtLeastOnePhoto")];
        return;
    }
    if (self.editingPet && images.count == 0 && !hasExistingURLs) {
        [self showErrorMessage:kLang(@"pleaseSelectAtLeastOnePhoto")];
        return;
    }

    if (invalidTags.count > 0) {
        [self showErrorMessage:kLang(@"adopt_form_required_fields_error")];
        return;
    }

    [self persistFormWithImages:images];
}

- (AdoptPetModel *)buildModelFromForm {
    NSDictionary *values = [self.form formValues];

    AdoptPetModel *model = [[AdoptPetModel alloc] init];
    model.documentID = self.editingPet.documentID ?: @"";
    model.name = [PPAdoptSafeString(values[kRowName]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    model.kindID = self.selectedMainKindModel.ID;
    model.breedID = self.selectedSubKindModel.ID;
    model.ageMonths = [values[kRowAgeMonths] integerValue];
    model.gender = [self pp_normalizedGenderFromFormValue:values[kRowGender]];
    model.cityID = self.selectedCity.cityID;
    model.details = PPAdoptSafeString(values[kRowDetails]);
    NSString *ownerID = self.editingPet.ownerID.length > 0 ? self.editingPet.ownerID : UserManager.sharedManager.currentUser.ID;
    model.ownerID = ownerID ?: @"";
    model.createdAt = self.editingPet.createdAt ?: [NSDate date];
    model.imageURLs = self.editingPet.imageURLs ?: @[];
    return model;
}

- (void)persistFormWithImages:(NSArray<UIImage *> *)images {
    if (!UserManager.sharedManager.isUserLoggedIn) {
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
    self.saveBarButton.enabled = YES;
    [self.saveActivityIndicator stopAnimating];
    self.saveBarButton.customView = nil;
    [GM ActivityLoadingAnimationView:NO onView:self.tableView];
    self.isSaving = NO;

    if (!success) {
        [self showErrorMessage:error.localizedDescription.length > 0 ? error.localizedDescription : kLang(@"unknownError")];
        return;
    }

    [self clearSavedDraft];
    NSString *title = isEditing ? kLang(@"adoptPetUpdatedTitle") : kLang(@"adoptPetAddedTitle");
    NSString *subtitle = isEditing ? kLang(@"adoptPetUpdatedDesc") : kLang(@"adoptPetAddedDesc");

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

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)formRow
                                oldValue:(id)oldValue
                                newValue:(id)newValue {
    [super formRowDescriptorValueHasChanged:formRow oldValue:oldValue newValue:newValue];

    if (!self.isHydratingFormData) {
        self.hasUserModifiedForm = YES;
    }
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
                AtIndex:(NSInteger)index
{
    (void)selectedImage;
    if (index < 0 || index >= collection.imageCount) {
        return;
    }
    [collection presentEditorForImageAtIndex:index fromViewController:self];
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    if (collection.imageCount >= collection.maxImageCount) {
        NSString *title = kLang(@"max_images_reached");
        NSString *subtitle = [NSString stringWithFormat:@"%@ %ld",
                              kLang(@"max_images_hint"),
                              (long)collection.maxImageCount];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }
    [collection presentPickerFromViewController:self];
}

@end
