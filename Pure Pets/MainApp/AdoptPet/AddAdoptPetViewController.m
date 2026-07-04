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
#import "PPFormEngine.h"
#import "CitiesManager.h"

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

#pragma mark - AddAdoptPetViewController

@interface AddAdoptPetViewController () <UITextFieldDelegate, UITextViewDelegate,
                                         PPImageCollectionDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) PPFormEngineView *formView;
@property (nonatomic, strong) UIView *formHeroView;
@property (nonatomic, strong) UILabel *formHeroEyebrowLabel;
@property (nonatomic, strong) UILabel *formHeroTitleLabel;
@property (nonatomic, strong) UILabel *formHeroSubtitleLabel;
@property (nonatomic, strong) UILabel *formHeroProgressLabel;
@property (nonatomic, strong) UIImageView *formHeroIconView;

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
@property (nonatomic, assign) BOOL didAnimateEntrance;

- (void)pp_presentSpeciesPicker;
- (void)pp_presentBreedPicker;
- (void)pp_presentGenderPicker;
- (void)pp_presentCityPicker;
- (NSArray<CityModel *> *)pp_availableCitiesForPicker;
- (void)pp_citiesDidUpdate:(NSNotification *)note;
- (void)pp_cancelSaveTimeout;
@end

@implementation AddAdoptPetViewController

- (instancetype)initWithPet:(AdoptPetModel *)pet {
    self = [super init];
    if (self) {
        _editingPet = pet;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self pp_cancelSaveTimeout];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
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
    [self pp_refreshFormHero];
    [self pp_prepareFormEntranceStateIfNeeded];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)pp_dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_setPremiumTabDockHidden:YES animated:animated];
    [self pp_refreshTitle];
    [self pp_prepareFormEntranceStateIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runFormEntranceAnimationIfNeeded];
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
    self.view.backgroundColor = AppBackgroundClr;

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.backgroundColor = UIColor.clearColor;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    scroll.contentInset = UIEdgeInsetsMake(6, 0, 24, 0);
    scroll.scrollIndicatorInsets = UIEdgeInsetsMake(6, 0, 24, 0);
    [self.view addSubview:scroll];
    self.scrollView = scroll;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 14.0;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);
    [scroll addSubview:stack];
    self.contentStack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];

    [self pp_setupFormHeroHeader];
    [self.contentStack addArrangedSubview:self.formHeroView];

    [self pp_rebuildFormFields];
}

- (void)pp_setupFormHeroHeader {
    self.formHeroView = [[UIView alloc] init];
    self.formHeroView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formHeroView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.formHeroView.layer.cornerRadius = 28.0;
    self.formHeroView.layer.masksToBounds = NO;
    self.formHeroView.semanticContentAttribute = PPAdoptCurrentSemanticAttribute();
    PPApplyContinuousCorners(self.formHeroView, 28.0);
    [self.formHeroView pp_setShadowColor:UIColor.blackColor];
    self.formHeroView.layer.shadowOpacity = 0.045;
    self.formHeroView.layer.shadowRadius = 18.0;
    self.formHeroView.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.10];
    iconPlate.layer.cornerRadius = 22.0;
    iconPlate.layer.masksToBounds = YES;
    PPApplyContinuousCorners(iconPlate, 22.0);
    [self.formHeroView addSubview:iconPlate];

    self.formHeroIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"camera.macro.circle.fill"]];
    self.formHeroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formHeroIconView.tintColor = GM.appPrimaryColor;
    self.formHeroIconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconPlate addSubview:self.formHeroIconView];

    self.formHeroEyebrowLabel = [[UILabel alloc] init];
    self.formHeroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.formHeroEyebrowLabel.font = [GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    self.formHeroEyebrowLabel.textColor = [GM.appPrimaryColor colorWithAlphaComponent:0.92];
    self.formHeroEyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.formHeroEyebrowLabel.text = kLang(@"adopt_form_eyebrow");
    [self.formHeroView addSubview:self.formHeroEyebrowLabel];

    self.formHeroTitleLabel = [[UILabel alloc] init];
    self.formHeroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.formHeroTitleLabel.font = [GM boldFontWithSize:23.0] ?: [UIFont systemFontOfSize:23.0 weight:UIFontWeightBold];
    self.formHeroTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.formHeroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.formHeroTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.formHeroTitleLabel.minimumScaleFactor = 0.82;
    [self.formHeroView addSubview:self.formHeroTitleLabel];

    self.formHeroSubtitleLabel = [[UILabel alloc] init];
    self.formHeroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.formHeroSubtitleLabel.font = [GM MidFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    self.formHeroSubtitleLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
    self.formHeroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.formHeroSubtitleLabel.numberOfLines = 2;
    [self.formHeroView addSubview:self.formHeroSubtitleLabel];

    self.formHeroProgressLabel = [[UILabel alloc] init];
    self.formHeroProgressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.formHeroProgressLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    self.formHeroProgressLabel.textColor = GM.appPrimaryColor;
    self.formHeroProgressLabel.textAlignment = NSTextAlignmentCenter;
    self.formHeroProgressLabel.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.09];
    self.formHeroProgressLabel.layer.cornerRadius = 15.0;
    self.formHeroProgressLabel.layer.masksToBounds = YES;
    [self.formHeroView addSubview:self.formHeroProgressLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.formHeroView.heightAnchor constraintEqualToConstant:138.0],

        [iconPlate.leadingAnchor constraintEqualToAnchor:self.formHeroView.leadingAnchor constant:16.0],
        [iconPlate.topAnchor constraintEqualToAnchor:self.formHeroView.topAnchor constant:18.0],
        [iconPlate.widthAnchor constraintEqualToConstant:44.0],
        [iconPlate.heightAnchor constraintEqualToConstant:44.0],

        [self.formHeroIconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [self.formHeroIconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [self.formHeroIconView.widthAnchor constraintEqualToConstant:24.0],
        [self.formHeroIconView.heightAnchor constraintEqualToConstant:24.0],

        [self.formHeroEyebrowLabel.leadingAnchor constraintEqualToAnchor:iconPlate.trailingAnchor constant:12.0],
        [self.formHeroEyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.formHeroProgressLabel.leadingAnchor constant:-10.0],
        [self.formHeroEyebrowLabel.topAnchor constraintEqualToAnchor:self.formHeroView.topAnchor constant:18.0],

        [self.formHeroTitleLabel.leadingAnchor constraintEqualToAnchor:self.formHeroEyebrowLabel.leadingAnchor],
        [self.formHeroTitleLabel.trailingAnchor constraintEqualToAnchor:self.formHeroView.trailingAnchor constant:-16.0],
        [self.formHeroTitleLabel.topAnchor constraintEqualToAnchor:self.formHeroEyebrowLabel.bottomAnchor constant:4.0],

        [self.formHeroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.formHeroView.leadingAnchor constant:16.0],
        [self.formHeroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.formHeroView.trailingAnchor constant:-16.0],
        [self.formHeroSubtitleLabel.topAnchor constraintEqualToAnchor:iconPlate.bottomAnchor constant:14.0],
        [self.formHeroSubtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.formHeroView.bottomAnchor constant:-16.0],

        [self.formHeroProgressLabel.trailingAnchor constraintEqualToAnchor:self.formHeroView.trailingAnchor constant:-16.0],
        [self.formHeroProgressLabel.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [self.formHeroProgressLabel.heightAnchor constraintEqualToConstant:30.0],
        [self.formHeroProgressLabel.widthAnchor constraintGreaterThanOrEqualToConstant:82.0]
    ]];
}

- (void)pp_rebuildFormFields {
    if (!self.contentStack) return;

    if (self.formView) {
        [self.formView removeFromSuperview];
    }

    __weak typeof(self) weakSelf = self;
    PPFormStyle *style = [PPFormStyle defaultStyle];
    style.cardBackgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:1.0]
            : UIColor.whiteColor;
    }];
    style.fieldBackgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.12 green:0.12 blue:0.13 alpha:1.0]
            : [UIColor colorWithRed:0.973 green:0.974 blue:0.978 alpha:1.0];
    }];
    style.fieldBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.06]
            : [UIColor colorWithRed:0.42 green:0.43 blue:0.46 alpha:0.055];
    }];
    style.accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    style.primaryTextColor = AppPrimaryTextClr ?: UIColor.labelColor;
    style.secondaryTextColor = UIColor.secondaryLabelColor;
    style.titleFont = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    style.inputFont = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    style.placeholderFont = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    style.cardCornerRadius = 24.0;
    style.fieldCornerRadius = 14.0;
    style.stackSpacing = 12.0;
    style.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.01 : 0.03;
    style.shadowRadius = 16.0;
    style.shadowOffset = CGSizeMake(0.0, 6.0);

    self.formView = [[PPFormEngineView alloc] initWithStyle:style];
    [self.contentStack insertArrangedSubview:self.formView atIndex:1];

    PPFormFieldConfig *nameField = [PPFormFieldConfig fieldWithIdentifier:kRowName
                                                                    title:kLang(@"name")
                                                              placeholder:kLang(@"enter_pet_name")
                                                                inputType:PPFormInputTypeText];
    nameField.required = YES;
    nameField.value = self.draftName;
    nameField.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        weakSelf.draftName = value;
        if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
    };

    PPFormFieldConfig *speciesField = [PPFormFieldConfig fieldWithIdentifier:kRowSpecies
                                                                      title:kLang(@"species")
                                                                placeholder:kLang(@"selectSpecies")
                                                                  inputType:PPFormInputTypePicker];
    speciesField.required = YES;
    speciesField.value = self.draftMainKind.KindName;
    speciesField.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        [weakSelf pp_presentSpeciesPicker];
    };

    PPFormFieldConfig *breedField = [PPFormFieldConfig fieldWithIdentifier:kRowBreed
                                                                    title:kLang(@"breed")
                                                              placeholder:kLang(@"selectCreed")
                                                                inputType:PPFormInputTypePicker];
    breedField.required = YES;
    breedField.enabled = (self.draftMainKind != nil);
    breedField.value = self.draftSubKind.SubKindName;
    breedField.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        [weakSelf pp_presentBreedPicker];
    };

    PPFormFieldConfig *ageField = [PPFormFieldConfig fieldWithIdentifier:kRowAgeMonths
                                                                   title:kLang(@"ageMonths")
                                                             placeholder:kLang(@"enter_pet_age_in_months")
                                                               inputType:PPFormInputTypeNumber];
    ageField.required = YES;
    ageField.value = self.draftAgeMonths > 0 ? [@(self.draftAgeMonths) stringValue] : @"";
    ageField.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        weakSelf.draftAgeMonths = value.integerValue;
        if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
    };

    PPFormFieldConfig *genderField = [PPFormFieldConfig fieldWithIdentifier:kRowGender
                                                                     title:kLang(@"Gender")
                                                               placeholder:kLang(@"selectGender")
                                                                 inputType:PPFormInputTypePicker];
    genderField.required = YES;
    genderField.value = self.draftGender;
    genderField.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        [weakSelf pp_presentGenderPicker];
    };

    PPFormFieldConfig *cityField = [PPFormFieldConfig fieldWithIdentifier:kRowCity
                                                                   title:kLang(@"city")
                                                             placeholder:kLang(@"selectCity")
                                                               inputType:PPFormInputTypePicker];
    cityField.required = YES;
    cityField.value = self.draftCity.name;
    cityField.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        [weakSelf pp_presentCityPicker];
    };

    PPFormFieldConfig *detailsField = [PPFormFieldConfig fieldWithIdentifier:kRowDetails
                                                                      title:kLang(@"details")
                                                                placeholder:kLang(@"describePet")
                                                                  inputType:PPFormInputTypeTextView];
    detailsField.required = YES;
    detailsField.value = self.draftDetails;
    detailsField.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        weakSelf.draftDetails = value;
        if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
    };

    [self.formView setFields:@[nameField, speciesField, breedField, ageField, genderField, cityField, detailsField]];
}

#pragma mark - Draft Storage

- (NSString *)draftStorageKey {
    NSString *currentUserID = PPAdoptSafeString(UserManager.sharedManager.currentUser.ID);
    if (self.editingPet.documentID.length) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@", kAdoptDraftDefaultsPrefix, self.editingPet.documentID, currentUserID];
    }
    return [NSString stringWithFormat:@"%@.create.%@", kAdoptDraftDefaultsPrefix, currentUserID];
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
}- (BOOL)restoreDraftIfNeeded {
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
    [self pp_rebuildFormFields];
    [self pp_refreshFormHero];
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
                                           title:@"Save your progress?"
                                        subtitle:@"You can save your current progress and come back later, or leave now without keeping these changes."
                                   primaryButton:@"Save and close"
                                    primaryStyle:UIAlertActionStyleDefault
                                 secondaryButton:@"Exit without saving"
                                  secondaryStyle:UIAlertActionStyleDestructive
                                  tertiaryButton:@"Keep editing"
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
    BOOL isEditing = (self.editingPet != nil);
    self.title = isEditing ? kLang(@"editAdoptPet") : kLang(@"addAdoptPet");
}

- (void)pp_refreshFormHero {
    BOOL isEditing = (self.editingPet != nil);
    self.formHeroEyebrowLabel.text = isEditing ? kLang(@"adopt_form_edit_eyebrow") : kLang(@"adopt_form_eyebrow");
    self.formHeroTitleLabel.text   = isEditing ? kLang(@"adopt_form_edit_title")   : kLang(@"adopt_form_title");

    NSString *subtitle = isEditing ? kLang(@"adopt_form_edit_subtitle") : kLang(@"adopt_form_subtitle");
    self.formHeroSubtitleLabel.text = subtitle;

    NSInteger filledFields = 0;
    NSInteger totalFields  = 7;

    if (self.draftName.length > 0) filledFields++;
    if (self.draftMainKind)        filledFields++;
    if (self.draftSubKind)         filledFields++;
    if (self.draftAgeMonths > 0)   filledFields++;
    if (self.draftGender.length > 0) filledFields++;
    if (self.draftCity)            filledFields++;
    if (self.draftDetails.length > 0) filledFields++;

    self.formHeroProgressLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)filledFields, (long)totalFields];
}

- (void)pp_prepareFormEntranceStateIfNeeded {
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.formHeroView.alpha = 0.0;
    self.formHeroView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                CGAffineTransformMakeScale(0.985, 0.985));
    self.scrollView.alpha = 0.0;
    self.scrollView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
}

- (void)pp_runFormEntranceAnimationIfNeeded {
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.formHeroView.alpha = 1.0;
        self.formHeroView.transform = CGAffineTransformIdentity;
        self.scrollView.alpha = 1.0;
        self.scrollView.transform = CGAffineTransformIdentity;
        return;
    }

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.48
                          delay:0.02
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.formHeroView.alpha = 1.0;
        self.formHeroView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.36
                          delay:0.10
                         options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.scrollView.alpha = 1.0;
        self.scrollView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setNavButtons {
    UIButtonConfiguration *saveConfig = [UIButtonConfiguration filledButtonConfiguration];
    saveConfig.title = kLang(@"save");
    saveConfig.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    saveConfig.baseBackgroundColor = GM.appPrimaryColor;
    saveConfig.baseForegroundColor = UIColor.whiteColor;
    saveConfig.contentInsets = NSDirectionalEdgeInsetsMake(9.0, 16.0, 9.0, 16.0);
    saveConfig.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
        NSMutableDictionary *outgoing = [incoming mutableCopy];
        outgoing[NSFontAttributeName] = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
        return outgoing.copy;
    };

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    saveBtn.configuration = saveConfig;
    [saveBtn addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [saveBtn.widthAnchor constraintGreaterThanOrEqualToConstant:76.0].active = YES;
    self.saveButtonView = saveBtn;

    self.saveActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.saveActivityIndicator.color = GM.appPrimaryColor;
    self.saveActivityIndicator.hidesWhenStopped = YES;

    self.saveBarButton = [[UIBarButtonItem alloc] initWithCustomView:saveBtn];
    self.navigationItem.rightBarButtonItem = self.saveBarButton;

    UIImage *backImg = [UIImage systemImageNamed:Language.isRTL ? @"chevron.right" : @"chevron.left"];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:backImg
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(backTapped)];
    backItem.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.navigationItem.leftBarButtonItem = backItem;
}

- (void)backTapped {
    if (self.hasUserModifiedForm) {
        [self presentUnsavedChangesPrompt];
        return;
    }
    [self pp_dismissForm];
}

- (void)setupImageCollection {
    if (self.imageCollection) return;

    self.imageCollection = [[PPImageCollection alloc] initWithFrame:CGRectZero
                                                       maxImageCount:15
                                                           useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.allowsVideoSelection = PPReusableVideoMediaEnabled();
    self.imageCollection.useArabic = Language.isRTL;
    self.imageCollection.titleText = kLang(@"photos");
    [self.imageCollection setTitle:kLang(@"photos") icon:nil];

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kAdoptMediaFooterHeight)];
    footer.backgroundColor = UIColor.clearColor;
    [footer addSubview:self.imageCollection];
    self.imageFooterContainer = footer;
    [self.contentStack addArrangedSubview:self.imageFooterContainer];
    [self pp_updateImageFooterLayoutIfNeeded];
}

- (void)pp_updateImageFooterLayoutIfNeeded {
    if (!self.imageFooterContainer || !self.imageCollection) return;
    CGFloat tableWidth = self.view.bounds.size.width;
    if (tableWidth <= 0) return;

    CGRect footerFrame = self.imageFooterContainer.frame;
    footerFrame.size.width  = tableWidth;
    footerFrame.size.height = kAdoptMediaFooterHeight;
    self.imageFooterContainer.frame = footerFrame;

    CGFloat collectionWidth = MAX(0, tableWidth - (kAdoptMediaInset * 2.0));
    self.imageCollection.frame = CGRectMake(kAdoptMediaInset, 10, collectionWidth, kAdoptMediaFooterHeight - 16);
}

#pragma mark - Prefill Loading UI

- (void)setupPrefillLoadingUI {
    self.prefillLoadingView = [[UIView alloc] init];
    self.prefillLoadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.prefillLoadingView.layer.cornerRadius  = 18;
    self.prefillLoadingView.layer.masksToBounds = NO;
    self.prefillLoadingView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [self.prefillLoadingView pp_setBorderColor:[[UIColor separatorColor] colorWithAlphaComponent:0.22]];
    [self.prefillLoadingView pp_setShadowColor:UIColor.blackColor];
    self.prefillLoadingView.layer.shadowOpacity = 0.08;
    self.prefillLoadingView.layer.shadowRadius = 18.0;
    self.prefillLoadingView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.prefillLoadingView.hidden = YES;
    [self.view addSubview:self.prefillLoadingView];

    self.prefillLoadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.prefillLoadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingSpinner.color = GM.appPrimaryColor;
    [self.prefillLoadingView addSubview:self.prefillLoadingSpinner];

    self.prefillLoadingLabel = [[UILabel alloc] init];
    self.prefillLoadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingLabel.font = [GM boldFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    self.prefillLoadingLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.prefillLoadingLabel.text = kLang(@"loading_prefill_media");
    self.prefillLoadingLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.prefillLoadingView addSubview:self.prefillLoadingLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.prefillLoadingView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.prefillLoadingView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20.0],
        [self.prefillLoadingView.heightAnchor constraintEqualToConstant:56.0],

        [self.prefillLoadingSpinner.leadingAnchor constraintEqualToAnchor:self.prefillLoadingView.leadingAnchor constant:18.0],
        [self.prefillLoadingSpinner.centerYAnchor constraintEqualToAnchor:self.prefillLoadingView.centerYAnchor],

        [self.prefillLoadingLabel.leadingAnchor constraintEqualToAnchor:self.prefillLoadingSpinner.trailingAnchor constant:10.0],
        [self.prefillLoadingLabel.trailingAnchor constraintEqualToAnchor:self.prefillLoadingView.trailingAnchor constant:-18.0],
        [self.prefillLoadingLabel.centerYAnchor constraintEqualToAnchor:self.prefillLoadingView.centerYAnchor]
    ]];
}

- (void)setPrefillLoadingVisible:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible) {
            self.prefillLoadingView.hidden = NO;
            self.prefillLoadingView.alpha = 0.0;
            self.prefillLoadingView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
            [self.prefillLoadingSpinner startAnimating];
            [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.prefillLoadingView.alpha = 1.0;
                self.prefillLoadingView.transform = CGAffineTransformIdentity;
            } completion:nil];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                self.prefillLoadingView.alpha = 0.0;
                self.prefillLoadingView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
            } completion:^(__unused BOOL finished) {
                self.prefillLoadingView.hidden = YES;
                self.prefillLoadingView.transform = CGAffineTransformIdentity;
                [self.prefillLoadingSpinner stopAnimating];
            }];
        }
    });
}

#pragma mark - Picker Presentation

- (void)pp_presentSpeciesPicker {
    NSArray<MainKindsModel *> *options = [MKM.MainKindsArray isKindOfClass:NSArray.class] ? MKM.MainKindsArray : @[];
    if (options.count == 0) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"error")
                          subtitle:kLang(@"unknownError")];
        return;
    }

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

            if ([selectedObject isKindOfClass:MainKindsModel.class]) {
                MainKindsModel *kind = (MainKindsModel *)selectedObject;
                strongSelf.draftMainKind = kind;
                strongSelf.draftSubKind = nil;
            } else {
                strongSelf.draftMainKind = nil;
                strongSelf.draftSubKind = nil;
            }

            if (!strongSelf.isHydratingFormData) {
                strongSelf.hasUserModifiedForm = YES;
            }
            [strongSelf pp_rebuildFormFields];
            [strongSelf pp_refreshFormHero];
        });
    }];
    vc.selectedOption = self.draftMainKind;
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

- (void)pp_presentBreedPicker {
    if (!self.draftMainKind) return;

    NSArray<SubKindModel *> *options = [self.draftMainKind.SubKindsArray isKindOfClass:NSArray.class] ? self.draftMainKind.SubKindsArray : @[];
    if (options.count == 0) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"error")
                          subtitle:kLang(@"unknownError")];
        return;
    }

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

            if ([selectedObject isKindOfClass:SubKindModel.class]) {
                strongSelf.draftSubKind = (SubKindModel *)selectedObject;
            } else {
                strongSelf.draftSubKind = nil;
            }

            if (!strongSelf.isHydratingFormData) {
                strongSelf.hasUserModifiedForm = YES;
            }
            [strongSelf pp_rebuildFormFields];
            [strongSelf pp_refreshFormHero];
        });
    }];
    vc.selectedOption = self.draftSubKind;
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

- (void)pp_presentGenderPicker {
    NSArray<NSString *> *options = @[kLang(@"Male"), kLang(@"Female")];

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

            if ([selectedObject isKindOfClass:NSString.class]) {
                strongSelf.draftGender = (NSString *)selectedObject;
            } else {
                strongSelf.draftGender = @"";
            }

            if (!strongSelf.isHydratingFormData) {
                strongSelf.hasUserModifiedForm = YES;
            }
            [strongSelf pp_rebuildFormFields];
            [strongSelf pp_refreshFormHero];
        });
    }];
    vc.selectedOption = self.draftGender;
    vc.showSearchBar = NO;
    vc.isGenderSelector = YES;
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

- (NSArray<CityModel *> *)pp_availableCitiesForPicker {
    NSArray<CityModel *> *cities = [CitiesManager.shared citiesForCurrentCountry];
    if (cities.count > 0) return cities;

    CountryModel *country = CitiesManager.shared.CurrentCountry ?: [CitiesManager.shared qatarCountry];
    return country.cities ?: @[];
}

- (void)pp_presentCityPicker {
    NSArray<CityModel *> *options = [self pp_availableCitiesForPicker];
    if (options.count == 0) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_citiesDidUpdate:)
                                                     name:CitiesManagerDidUpdateNotification
                                                   object:nil];
        [CitiesManager.shared loadData];
        return;
    }

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

            if ([selectedObject isKindOfClass:CityModel.class]) {
                strongSelf.draftCity = (CityModel *)selectedObject;
            } else {
                strongSelf.draftCity = nil;
            }

            if (!strongSelf.isHydratingFormData) {
                strongSelf.hasUserModifiedForm = YES;
            }
            [strongSelf pp_rebuildFormFields];
            [strongSelf pp_refreshFormHero];
        });
    }];
    vc.selectedOption = self.draftCity;
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

- (void)pp_citiesDidUpdate:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CitiesManagerDidUpdateNotification object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.view.window || self.presentedViewController) return;
        [self pp_presentCityPicker];
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

    [self pp_rebuildFormFields];
    [self pp_refreshFormHero];

    NSArray<NSDictionary *> *mediaMetadata = [self.editingPet.imageMeta isKindOfClass:NSArray.class] ? self.editingPet.imageMeta : @[];
    if (mediaMetadata.count > 0 || self.editingPet.imageURLs.count > 0) {
        self.isPrefillInProgress = YES;
        [self setPrefillLoadingVisible:YES];
        __weak typeof(self) weakSelf = self;
        void (^finishPrefill)(void) = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.isPrefillInProgress = NO;
            [strongSelf setPrefillLoadingVisible:NO];
        };
        if (mediaMetadata.count > 0) {
            [self.imageCollection preloadMediaMetadata:mediaMetadata completion:finishPrefill];
        } else {
            [self.imageCollection preloadImagesFromURLs:self.editingPet.imageURLs completion:finishPrefill];
        }
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
    dispatch_block_t block = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.isSaving) {
            [strongSelf pp_handleSaveTimeout];
        }
    });
    self.saveTimeoutBlock = block;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)pp_handleSaveTimeout {
    [self pp_resetSaveButton];
    self.isSaving = NO;
    [GM ActivityLoadingAnimationView:NO onView:self.view];

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

- (void)pp_shakeCell:(UIView *)cell {
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
    NSString *firstInvalidId = nil;

    if (name.length == 0)                             firstInvalidId = kRowName;
    else if (!self.draftMainKind)                      firstInvalidId = kRowSpecies;
    else if (!self.draftSubKind)                       firstInvalidId = kRowBreed;
    else if (self.draftAgeMonths <= 0)                 firstInvalidId = kRowAgeMonths;
    else if (self.draftGender.length == 0)             firstInvalidId = kRowGender;
    else if (!self.draftCity)                          firstInvalidId = kRowCity;

    NSArray<UIImage *> *images = [self.imageCollection allImages] ?: @[];
    BOOL hasSelectedMedia = self.imageCollection.imageCount > 0;
    BOOL hasExistingMedia = self.editingPet.imageURLs.count > 0 || self.editingPet.imageMeta.count > 0;

    if (!self.editingPet && !hasSelectedMedia) {
        [self pp_resetSaveButton];
        [self showErrorMessage:kLang(@"pleaseSelectAtLeastOnePhoto")];
        return;
    }
    if (self.editingPet && !hasSelectedMedia && !hasExistingMedia) {
        [self pp_resetSaveButton];
        [self showErrorMessage:kLang(@"pleaseSelectAtLeastOnePhoto")];
        return;
    }

    if (firstInvalidId) {
        [self pp_resetSaveButton];
        PPFormFieldRowView *row = [self.formView rowForIdentifier:firstInvalidId];
        if (row) {
            [self pp_shakeCell:row];
        }
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
    model.imageMeta = self.editingPet.imageMeta ?: @[];
    return model;
}

- (void)persistFormWithImages:(NSArray<UIImage *> *)images {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [self pp_resetSaveButton];
        [UserManager showPromptOnTopController];
        return;
    }

    self.isSaving = YES;
    [GM ActivityLoadingAnimationView:YES onView:self.view];
    [self pp_scheduleSaveTimeout];

    AdoptPetModel *model = [self buildModelFromForm];
    __weak typeof(self) weakSelf = self;

    if ([self.imageCollection hasSelectedVideos]) {
        if (!self.editingPet && model.documentID.length == 0) {
            model.documentID = NSUUID.UUID.UUIDString;
        }
        [self.imageCollection uploadSelectedMediaWithStorageFolder:@"adoptions"
                                                           ownerID:model.ownerID
                                                         contextID:(model.documentID.length > 0 ? model.documentID : nil)
                                                        completion:^(PPMediaUploadResult * _Nullable result, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error || !result) {
                [strongSelf pp_finishSaveWithSuccess:NO
                                               error:error ?: [NSError errorWithDomain:@"AddAdoptPetViewController"
                                                                                  code:-700
                                                                              userInfo:@{NSLocalizedDescriptionKey: kLang(@"media_upload_failed_message")}]
                                           isEditing:(strongSelf.editingPet != nil)];
                return;
            }

            model.imageURLs = result.imageURLs ?: @[];
            model.imageMeta = result.mixedMetadata ?: @[];

            if (strongSelf.editingPet) {
                [[AdoptPetManager shared] updatePetWithID:model.documentID
                                                     data:[model toFirestoreDictionary]
                                               completion:^(BOOL success, NSError * _Nullable saveError) {
                    [strongSelf pp_finishSaveWithSuccess:success error:saveError isEditing:YES];
                }];
            } else {
                [[AdoptPetManager shared] createPet:model
                                             images:@[]
                                         completion:^(BOOL success, NSString * _Nullable documentID, NSError * _Nullable saveError) {
                    [strongSelf pp_finishSaveWithSuccess:success error:saveError isEditing:NO];
                }];
            }
        }];
        return;
    }

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
    [GM ActivityLoadingAnimationView:NO onView:self.view];
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

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    (void)collection;
    PPAdoptLog(@"Media changed -> %lu images", (unsigned long)images.count);
    if (!self.isHydratingFormData && !self.isPrefillInProgress) {
        self.hasUserModifiedForm = YES;
    }
    [self pp_refreshFormHero];
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
        [self pp_rebuildFormFields];
    }
}

@end
