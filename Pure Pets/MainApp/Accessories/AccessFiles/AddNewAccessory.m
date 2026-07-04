#import "AddNewAccessory.h"
#import "PPImageCollection.h"
#import "PPFormEngine.h"
#import "UserManager.h"
#import "PPNetworkRetryHelper.h"
#import "PPSelectOptionViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "CitiesManager.h"
#import "CityModel.h"

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
static NSString *const PPAddAccessoryFieldAccessoryCategoryID = @"AccessoryCategoryID";
static NSString *const PPAddAccessoryFieldCityID = @"cityID";

static NSInteger const PPAddAccessoryMaxImageCount = 8;
static CGFloat const PPAddAccessoryCollectionHeight = 220.0;
static CGFloat const PPAddAccessoryFooterHeight = 236.0;
static CGFloat const PPAddAccessoryProgressHeight = 4.0;
static CGFloat const PPAddAccessoryUploadMaxDimension = 2048.0;

static inline NSString *PPAccessorySafeString(id value) {
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

// ────────────────────────────────────────────────────────────
#pragma mark - Field identifiers

typedef NS_ENUM(NSInteger, PPAccessoryFieldKind) {
    PPAccessoryFieldKindName = 1,
    PPAccessoryFieldKindPrice
};

#pragma mark - AddNewAccessory  (main controller)
// ────────────────────────────────────────────────────────────

@interface AddNewAccessory ()<PPImageCollectionDelegate, UITextFieldDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) PPFormEngineView *categoryFormView;
@property (nonatomic, strong) PPFormEngineView *detailsFormView;
@property (nonatomic, strong) PPImageCollection *imageCollection;
@property (nonatomic, strong) UIView *imageFooterContainer;
@property (nonatomic, strong) PetAccessory *accessModel;
@property (nonatomic, strong) MainKindsModel *selectedKind;
@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;

// Draft properties (replace XLFormRowDescriptors)
@property (nonatomic, strong) MainKindsModel *draftMainKind;
@property (nonatomic, strong) SubKindModel   *draftSubKind;
@property (nonatomic, strong, nullable) PPAccessoryCategoryModel *draftAccessoryCategory;
@property (nonatomic, strong, nullable) CityModel *draftCity;
@property (nonatomic, strong, nullable) NSArray<CityModel *> *citiesList;
@property (nonatomic, strong, nullable) CLLocationManager *locationManager;
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

    [self pp_setupSmartCityPicker];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_handleLanguageDidChange:)
                                                 name:PPAddAccessoryLanguageDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_handleMainKindsUpdated:)
                                                 name:PPMainKindsUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_handleBlockedStateNotification:)
                                                 name:PPUserManagerDidUpdateBlockedStateNotification object:UserManager.sharedManager];
    [self pp_refreshMediaLocalizedText];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)pp_dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateImageFooterLayoutIfNeeded];
    if (self.uploadProgressView) [self.view bringSubviewToFront:self.uploadProgressView];
}

- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self pp_focusFirstFieldIfNeeded]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_setPremiumTabDockHidden:YES animated:animated];
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
    if (exiting) {
        [self pp_setPremiumTabDockHidden:NO animated:animated];
    }
    if (exiting) [self.imageCollection clearAllImages];
}

- (void)pp_setPremiumTabDockHidden:(BOOL)hidden animated:(BOOL)animated
{
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)self.tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
    }
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
    if (self.accessModel.AccessoryCategoryID.length) snap[PPAddAccessoryFieldAccessoryCategoryID] = self.accessModel.AccessoryCategoryID;
    if (self.accessModel.cityID > 0) snap[PPAddAccessoryFieldCityID] = @(self.accessModel.cityID);
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
    dm.AccessoryCategoryID = stored[PPAddAccessoryFieldAccessoryCategoryID];
    dm.cityID = [stored[PPAddAccessoryFieldCityID] integerValue];
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
    [self pp_refreshFormValuesAndStates];
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
    [PPAlertHelper showThreeActionConfirmationIn:self
                                           title:kLang(@"form_draft_prompt_title")
                                        subtitle:kLang(@"form_draft_prompt_message")
                                   primaryButton:kLang(@"form_draft_save_and_close")
                                    primaryStyle:UIAlertActionStyleDefault
                                 secondaryButton:kLang(@"form_draft_discard")
                                  secondaryStyle:UIAlertActionStyleDestructive
                                  tertiaryButton:kLang(@"form_draft_keep_editing")
                                   tertiaryStyle:UIAlertActionStyleCancel
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
        self.accessModel.condition = (self.accessKindType == AccessTypeFood || !PPAllwedUsedAccessoriesEnabled())
            ? AccessConditionsNew
            : AccessConditionsUsed;
        self.accessModel.quantity = 1;
        self.accessModel.hasOffer = NO;
        self.accessModel.showInAppMarket = YES;
        self.accessModel.isNew = (self.accessModel.condition == AccessConditionsNew);
    }
}

- (void)setBackAndCorners { self.view.backgroundColor = AppBackgroundClr; }

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
    self.imageCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.allowsVideoSelection = YES;
    self.imageCollection.useArabic = Language.isRTL;
    UIView *footer = [[UIView alloc] init];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    footer.backgroundColor = UIColor.clearColor;
    [footer addSubview:self.imageCollection];
    self.imageFooterContainer = footer;
    [self.contentStack addArrangedSubview:footer];
    [NSLayoutConstraint activateConstraints:@[
        [footer.heightAnchor constraintGreaterThanOrEqualToConstant:PPAddAccessoryFooterHeight],
        [self.imageCollection.topAnchor constraintEqualToAnchor:footer.topAnchor],
        [self.imageCollection.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor],
        [self.imageCollection.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor],
        [self.imageCollection.heightAnchor constraintEqualToConstant:PPAddAccessoryCollectionHeight],
        [self.imageCollection.bottomAnchor constraintLessThanOrEqualToAnchor:footer.bottomAnchor]
    ]];
    [self pp_updateImageFooterLayoutIfNeeded];
    [self pp_refreshMediaLocalizedText];
}

- (void)pp_updateImageFooterLayoutIfNeeded {
    if (!self.imageFooterContainer || !self.imageCollection) return;
    [self.imageFooterContainer setNeedsLayout];
    [self.imageFooterContainer layoutIfNeeded];
    [self.imageCollection setNeedsLayout];
    [self.imageCollection layoutIfNeeded];
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
    [self pp_rebuildFormFields];
    [self pp_refreshFormValuesAndStates];
    [self pp_refreshMediaLocalizedText]; [self pp_updateNavigationTitle]; [self ios26Bar];
}

- (void)pp_handleMainKindsUpdated:(NSNotification *)note {
    NSInteger mainKindID = self.draftMainKind ? self.draftMainKind.ID : self.accessModel.petMainCategoryID;
    if (mainKindID <= 0) return;

    MainKindsModel *freshKind = [MKM mainKindForID:mainKindID];
    if (!freshKind) return;
    self.draftMainKind = freshKind;
    self.selectedKind = freshKind;

    if (self.accessModel.petSubCategoryID > 0) {
        self.draftSubKind = [freshKind subKindForID:self.accessModel.petSubCategoryID];
    }

    if (self.accessModel.AccessoryCategoryID.length > 0) {
        PPAccessoryCategoryModel *freshCategory = [freshKind accessoryCategoryForID:self.accessModel.AccessoryCategoryID];
        if (freshCategory) {
            self.draftAccessoryCategory = freshCategory;
        } else {
            [self pp_hydrateAccessoryCategoryForModel:self.accessModel];
        }
    }
    [self pp_refreshFormValuesAndStates];
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
        if (self.accessKindType == AccessTypeAccessory) {
            subtitle = self.accessModel.condition == AccessConditionsUsed
                ? [self pp_localizedStringForKey:@"used" fallback:@"Used"]
                : [self pp_localizedStringForKey:@"New" fallback:@"New"];
        }
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
    NSArray<NSDictionary *> *mediaMetadata = [self.accessModel.imageMeta isKindOfClass:NSArray.class] ? self.accessModel.imageMeta : @[];
    if (mediaMetadata.count == 0 && self.accessModel.imageURLsArray.count == 0) return;
    self.isHydratingMedia = YES;
    void (^finish)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{ self.isHydratingMedia = NO; [self pp_refreshMediaLocalizedText]; });
    };
    if (mediaMetadata.count > 0) {
        [self.imageCollection preloadMediaMetadata:mediaMetadata completion:finish];
    } else {
        [self.imageCollection preloadImagesFromURLs:self.accessModel.imageURLsArray completion:finish];
    }
}

- (void)prefillFromModel:(PetAccessory *)model {
    if (!model) return;
    self.accessModel.petMainCategoryID = model.petMainCategoryID;
    self.accessModel.petSubCategoryID = model.petSubCategoryID;
    self.accessModel.AccessoryCategoryID = [model.AccessoryCategoryID copy];
    self.accessModel.cityID = model.cityID;

    self.selectedKind = [MKM mainKindForID:model.petMainCategoryID];
    self.draftMainKind = self.selectedKind;
    if (self.selectedKind) {
        SubKindModel *sk = nil;
        for (SubKindModel *sub in self.selectedKind.SubKindsArray) { if (sub.ID == model.petSubCategoryID) { sk = sub; break; } }
        self.draftSubKind = sk;
    } else { self.draftSubKind = nil; }

    if (model.AccessoryCategoryID.length > 0) {
        [self pp_hydrateAccessoryCategoryForModel:model];
    } else {
        self.draftAccessoryCategory = nil;
    }

    if (model.cityID > 0) {
        self.draftCity = [CitiesManager.shared cityByID:model.cityID];
    } else {
        self.draftCity = nil;
    }

    self.draftName = model.name ?: @"";
    self.draftPrice = model.price ?: @0;
    self.draftDesc = model.desc ?: @"";
    [self pp_syncModelFromDraftProperties];
    [self pp_refreshFormValuesAndStates];
}

#pragma mark - Form (PPFormEngine Setup)

- (void)initForm {
    self.view.backgroundColor = AppBackgroundClr;
    self.view.clipsToBounds = YES;

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

    NSString *categoryTitle = (self.accessKindType == AccessTypeAccessory)
        ? [self pp_localizedStringForKey:@"accessory_form_category_section_title" fallback:@"Category"]
        : [self pp_localizedStringForKey:@"food_form_category_section_title" fallback:@"Category"];
    NSString *detailsTitle = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"food_form_details_section_title" fallback:@"Details"]
        : [self pp_localizedStringForKey:@"accessory_form_details_section_title" fallback:@"Details"];

    [stack addArrangedSubview:[self pp_sectionHeaderViewWithTitle:categoryTitle subtitle:@""]];
    self.categoryFormView = [[PPFormEngineView alloc] initWithStyle:[self pp_accessoryFormStyle]];
    [stack addArrangedSubview:self.categoryFormView];

    [stack addArrangedSubview:[self pp_sectionHeaderViewWithTitle:detailsTitle subtitle:@""]];
    self.detailsFormView = [[PPFormEngineView alloc] initWithStyle:[self pp_accessoryFormStyle]];
    [stack addArrangedSubview:self.detailsFormView];

    [self pp_rebuildFormFields];
}

- (PPFormStyle *)pp_accessoryFormStyle {
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
    style.accentColor = AppPrimaryClr ?: [GM appPrimaryColor] ?: UIColor.systemTealColor;
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
    return style;
}

- (void)pp_rebuildFormFields {
    __weak typeof(self) ws = self;

    PPFormFieldConfig *species = [PPFormFieldConfig fieldWithIdentifier:PPAddAccessoryFieldMainCategoryID
                                                                  title:[self pp_localizedStringForKey:@"form_species_title" fallback:@"Species"]
                                                            placeholder:[self pp_localizedStringForKey:@"form_species_placeholder" fallback:@"Select species"]
                                                              inputType:PPFormInputTypePicker];
    species.value = [self pp_mainKindDisplayText];
    species.required = YES;
    species.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config; (void)row;
        [ws pp_presentMainCategoryPicker];
    };

    PPFormFieldConfig *breed = [PPFormFieldConfig fieldWithIdentifier:PPAddAccessoryFieldSubCategoryID
                                                                title:[self pp_localizedStringForKey:@"form_breed_title" fallback:@"Breed"]
                                                          placeholder:[self pp_localizedStringForKey:@"form_breed_placeholder" fallback:@"Select breed"]
                                                            inputType:PPFormInputTypePicker];
    breed.value = [self pp_subKindDisplayText];
    breed.enabled = (self.draftMainKind != nil);
    breed.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config; (void)row;
        [ws pp_presentSubCategoryPicker];
    };

    PPFormFieldConfig *category = [PPFormFieldConfig fieldWithIdentifier:PPAddAccessoryFieldAccessoryCategoryID
                                                                   title:[self pp_localizedStringForKey:@"accessory_form_category_title" fallback:@"Accessory Category"]
                                                             placeholder:[self pp_localizedStringForKey:@"accessory_form_category_placeholder" fallback:@"Select Category"]
                                                               inputType:PPFormInputTypePicker];
    category.value = [self pp_accessoryCategoryDisplayText];
    category.required = YES;
    category.enabled = (self.draftMainKind != nil);
    category.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config; (void)row;
        [ws pp_presentAccessoryCategoryPicker];
    };

    [self.categoryFormView setFields:@[species, breed, category]];

    NSString *nameTitle = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"food_form_name_title" fallback:@"Food name"]
        : [self pp_localizedStringForKey:@"accessory_form_name_title" fallback:@"Accessory name"];
    NSString *namePlaceholder = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"food_form_name_placeholder" fallback:@"Enter food name"]
        : [self pp_localizedStringForKey:@"accessory_form_name_placeholder" fallback:@"Enter accessory name"];
    PPFormFieldConfig *name = [PPFormFieldConfig fieldWithIdentifier:PPAddAccessoryFieldName
                                                               title:nameTitle
                                                         placeholder:namePlaceholder
                                                           inputType:PPFormInputTypeText];
    name.value = self.draftName ?: @"";
    name.required = YES;
    name.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        __strong typeof(ws) s = ws; if (!s) return;
        s.draftName = value ?: @"";
        s.accessModel.name = s.draftName;
        if (!s.isHydratingFormData) s.hasUserModifiedForm = YES;
        [s.detailsFormView setErrorText:nil forIdentifier:PPAddAccessoryFieldName];
    };

    PPFormFieldConfig *price = [PPFormFieldConfig fieldWithIdentifier:PPAddAccessoryFieldPrice
                                                                title:[self pp_localizedStringForKey:@"form_price_title" fallback:@"Price"]
                                                          placeholder:[self pp_localizedStringForKey:@"form_price_placeholder" fallback:@"Enter price"]
                                                            inputType:PPFormInputTypeNumber];
    price.value = (self.draftPrice && [self.draftPrice doubleValue] > 0.0) ? [self.draftPrice stringValue] : @"";
    price.required = YES;
    price.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        __strong typeof(ws) s = ws; if (!s) return;
        NSNumber *p = [s pp_numberFromValue:value ?: @""];
        s.draftPrice = p;
        s.accessModel.price = p ?: @0;
        if (!s.isHydratingFormData) s.hasUserModifiedForm = YES;
        [s.detailsFormView setErrorText:nil forIdentifier:PPAddAccessoryFieldPrice];
    };

    NSString *descTitle = (self.accessKindType == AccessTypeFood)
        ? [self pp_localizedStringForKey:@"food_form_desc_title" fallback:@"Description"]
        : [self pp_localizedStringForKey:@"accessory_form_desc_title" fallback:@"Description"];
    PPFormFieldConfig *desc = [PPFormFieldConfig fieldWithIdentifier:PPAddAccessoryFieldDescription
                                                               title:descTitle
                                                         placeholder:[self pp_localizedStringForKey:@"form_desc_placeholder" fallback:@"Add details"]
                                                           inputType:PPFormInputTypeTextView];
    desc.value = self.draftDesc ?: @"";
    desc.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        __strong typeof(ws) s = ws; if (!s) return;
        s.draftDesc = value ?: @"";
        s.accessModel.desc = s.draftDesc;
        if (!s.isHydratingFormData) s.hasUserModifiedForm = YES;
    };

    PPFormFieldConfig *city = [PPFormFieldConfig fieldWithIdentifier:PPAddAccessoryFieldCityID
                                                               title:[self pp_localizedStringForKey:@"form_city_title" fallback:@"City"]
                                                         placeholder:[self pp_localizedStringForKey:@"form_city_placeholder" fallback:@"Select City"]
                                                           inputType:PPFormInputTypePicker];
    city.value = [self pp_cityDisplayText];
    city.required = YES;
    city.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config; (void)row;
        [ws pp_presentCityPicker];
    };

    [self.detailsFormView setFields:@[name, price, desc, city]];

    PPFormFieldRowView *nameRow = [self pp_rowForIdentifier:PPAddAccessoryFieldName];
    nameRow.textField.returnKeyType = UIReturnKeyNext;
    nameRow.textField.tag = PPAccessoryFieldKindName;
    nameRow.externalTextFieldDelegate = self;

    PPFormFieldRowView *priceRow = [self pp_rowForIdentifier:PPAddAccessoryFieldPrice];
    priceRow.textField.returnKeyType = UIReturnKeyDone;
    priceRow.textField.tag = PPAccessoryFieldKindPrice;
    priceRow.externalTextFieldDelegate = self;
}

- (void)pp_refreshFormValuesAndStates {
    if (!self.categoryFormView || !self.detailsFormView) return;

    [self.categoryFormView setValue:[self pp_mainKindDisplayText] forIdentifier:PPAddAccessoryFieldMainCategoryID];
    [self.categoryFormView setValue:[self pp_subKindDisplayText] forIdentifier:PPAddAccessoryFieldSubCategoryID];
    [self.categoryFormView setFieldEnabled:(self.draftMainKind != nil) identifier:PPAddAccessoryFieldSubCategoryID];
    [self.categoryFormView setValue:[self pp_accessoryCategoryDisplayText] forIdentifier:PPAddAccessoryFieldAccessoryCategoryID];
    [self.categoryFormView setFieldEnabled:(self.draftMainKind != nil) identifier:PPAddAccessoryFieldAccessoryCategoryID];

    [self.detailsFormView setValue:self.draftName ?: @"" forIdentifier:PPAddAccessoryFieldName];
    NSString *priceText = (self.draftPrice && [self.draftPrice doubleValue] > 0.0) ? [self.draftPrice stringValue] : @"";
    [self.detailsFormView setValue:priceText forIdentifier:PPAddAccessoryFieldPrice];
    [self.detailsFormView setValue:self.draftDesc ?: @"" forIdentifier:PPAddAccessoryFieldDescription];
    [self.detailsFormView setValue:[self pp_cityDisplayText] forIdentifier:PPAddAccessoryFieldCityID];
}

- (PPFormEngineView *)pp_formViewForIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:PPAddAccessoryFieldMainCategoryID] ||
        [identifier isEqualToString:PPAddAccessoryFieldSubCategoryID] ||
        [identifier isEqualToString:PPAddAccessoryFieldAccessoryCategoryID]) {
        return self.categoryFormView;
    }
    return self.detailsFormView;
}

- (PPFormFieldRowView *)pp_rowForIdentifier:(NSString *)identifier {
    return [[self pp_formViewForIdentifier:identifier] rowForIdentifier:identifier];
}

- (void)pp_setFieldError:(NSString *)error identifier:(NSString *)identifier {
    [[self pp_formViewForIdentifier:identifier] setErrorText:error forIdentifier:identifier];
}

- (NSString *)pp_requiredErrorForTitle:(NSString *)title {
    NSString *format = [self pp_localizedStringForKey:@"form_required_error_format" fallback:@"%@ is required"];
    return [NSString stringWithFormat:format, title ?: @""];
}

- (NSString *)pp_mainKindDisplayText {
    return self.draftMainKind ? [self pp_displayNameForModel:self.draftMainKind] : @"";
}

- (NSString *)pp_subKindDisplayText {
    return self.draftSubKind ? [self pp_displayNameForModel:self.draftSubKind] : @"";
}

- (NSString *)pp_accessoryCategoryDisplayText {
    return self.draftAccessoryCategory ? [self.draftAccessoryCategory displayName] : @"";
}

- (NSString *)pp_cityDisplayText {
    if (!self.draftCity) return @"";
    return Language.isRTL ? (self.draftCity.arName ?: @"") : (self.draftCity.enName ?: @"");
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
    if (self.draftAccessoryCategory) {
        self.accessModel.AccessoryCategoryID = self.draftAccessoryCategory.categoryID ?: nil;
    }
    self.accessModel.cityID = self.draftCity ? self.draftCity.cityID : 0;
    self.accessModel.accessKindType = self.accessKindType;
    if (self.accessKindType == AccessTypeAccessory && !PPAllwedUsedAccessoriesEnabled()) {
        self.accessModel.condition = AccessConditionsNew;
    } else if (self.accessModel.condition != AccessConditionsNew && self.accessModel.condition != AccessConditionsUsed) {
        self.accessModel.condition = (self.accessKindType == AccessTypeFood) ? AccessConditionsNew : AccessConditionsUsed;
    }
    if (self.accessModel.quantity <= 0) self.accessModel.quantity = 1;
    self.accessModel.isNew = (self.accessModel.condition == AccessConditionsNew);
    if (!self.accessModel.ownerID.length) self.accessModel.ownerID = UserManager.sharedManager.currentUser.ID ?: @"";
    if (!self.accessModel.createdAt) self.accessModel.createdAt = NSDate.date;
}

#pragma mark - Display Helpers

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

#pragma mark - Section Headers

- (UIView *)pp_sectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *c = [[UIView alloc] init]; c.translatesAutoresizingMaskIntoConstraints = NO; c.backgroundColor = UIColor.clearColor;
    [c.heightAnchor constraintEqualToConstant:64.0].active = YES;
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
        [ab.leadingAnchor constraintEqualToAnchor:c.leadingAnchor],
        [ab.topAnchor constraintEqualToAnchor:c.topAnchor constant:14.0],
        [ab.widthAnchor constraintEqualToConstant:28.0], [ab.heightAnchor constraintEqualToConstant:4.0],
        [tl.topAnchor constraintEqualToAnchor:ab.bottomAnchor constant:9.0],
        [tl.leadingAnchor constraintEqualToAnchor:ab.leadingAnchor],
        [tl.trailingAnchor constraintEqualToAnchor:c.trailingAnchor],
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
            s.draftAccessoryCategory = nil;
            s.accessModel.AccessoryCategoryID = nil;
            if (![obj isKindOfClass:[MainKindsModel class]]) {
                s.selectedKind = nil; s.draftMainKind = nil;
                s.accessModel.petMainCategoryID = 0; s.accessModel.petSubCategoryID = 0; s.draftSubKind = nil;
            } else {
                s.selectedKind = obj; s.draftMainKind = obj;
                s.accessModel.petMainCategoryID = s.selectedKind.ID; s.accessModel.petSubCategoryID = 0; s.draftSubKind = nil;
                if (!s.isHydratingFormData) s.hasUserModifiedForm = YES;
            }
            [s pp_refreshFormValuesAndStates];
        });
    }];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

- (void)pp_presentSubCategoryPicker {
    if (!self.draftMainKind) return;
    __weak typeof(self) ws = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:self.draftMainKind.SubKindsArray ?: @[]
                  title:[self pp_localizedStringForKey:@"form_breed_selector_title" fallback:@"Select breed"]
                    row:nil presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable obj) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            if ([obj isKindOfClass:[SubKindModel class]]) {
                s.draftSubKind = obj; s.accessModel.petSubCategoryID = ((SubKindModel *)obj).ID;
            } else { s.draftSubKind = nil; s.accessModel.petSubCategoryID = 0; }
            if (!s.isHydratingFormData) s.hasUserModifiedForm = YES;
            [s pp_refreshFormValuesAndStates];
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
        PPFormFieldRowView *priceRow = [self pp_rowForIdentifier:PPAddAccessoryFieldPrice];
        [priceRow.textField becomeFirstResponder];
    } else { [tf resignFirstResponder]; }
    return YES;
}

#pragma mark - Submission

- (NSError *)pp_uploadErrorWithCode:(NSInteger)code description:(NSString *)desc {
    NSString *fallback = [self pp_localizedStringForKey:@"media_upload_failed_default_message"
                                               fallback:@"Failed to upload images."];
    return [NSError errorWithDomain:PPAddAccessoryErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: desc.length ? desc : fallback}];
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
    if (imgs.count > PPAddAccessoryMaxImageCount) {
        NSString *format = [self pp_localizedStringForKey:@"max_images_count_error_format"
                                                 fallback:@"Maximum %ld images are allowed."];
        if (error) *error = [self pp_uploadErrorWithCode:101 description:[NSString stringWithFormat:format, (long)PPAddAccessoryMaxImageCount]];
        return nil;
    }
    NSMutableArray<UIImage *> *out = [NSMutableArray arrayWithCapacity:imgs.count];
    for (NSInteger i = 0; i < imgs.count; i++) {
        UIImage *p = [self pp_normalizedImageForUpload:imgs[i]];
        if (!p) {
            NSString *format = [self pp_localizedStringForKey:@"image_prepare_failed_format"
                                                     fallback:@"Failed to prepare image at index %ld."];
            if (error) *error = [self pp_uploadErrorWithCode:102 description:[NSString stringWithFormat:format, (long)i+1]];
            return nil;
        }
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
    BOOL isEdit = (self.formMode == AccessFormModeEdit);
    if (isEdit && self.accessModel.accessoryID.length == 0) {
        [PPAlertHelper showErrorIn:self title:[self pp_localizedStringForKey:@"error" fallback:@"Error"]
                          subtitle:[self pp_localizedStringForKey:@"missing_accessory_id" fallback:@"Missing accessory ID. Please reopen and try again."]];
        return;
    }
    if ([self.imageCollection hasSelectedVideos]) {
        if ([self.imageCollection imageCount] == 0) {
            [PPAlertHelper showErrorIn:self
                                 title:[self pp_localizedStringForKey:@"error" fallback:@"Error"]
                              subtitle:[self pp_localizedStringForKey:@"please_add_photos_before_submit" fallback:@"Please add at least one image before posting."]];
            return;
        }
        [self pp_beginSubmitUI];
        [self pp_submitAccessoryWithReusableMediaIsEditing:isEdit];
        return;
    }
    NSError *ne = nil;
    NSArray<UIImage *> *ni = [self pp_normalizedImagesForSubmitWithError:&ne];
    if (ni.count == 0) {
        [PPAlertHelper showErrorIn:self title:[self pp_localizedStringForKey:@"error" fallback:@"Error"]
                          subtitle:ne.localizedDescription ?: [self pp_localizedStringForKey:@"Something went wrong" fallback:@"Something went wrong."]];
        return;
    }
    [self pp_beginSubmitUI];
    [self pp_submitAccessoryIsEditing:isEdit images:ni];
}

#pragma mark - Validation

- (BOOL)pp_validateFormWithShake {
    BOOL ok = YES;
    NSString *firstInvalidIdentifier = nil;
    [self.categoryFormView clearErrors];
    [self.detailsFormView clearErrors];

    if (!self.draftMainKind) {
        NSString *title = [self pp_localizedStringForKey:@"form_species_title" fallback:@"Species"];
        [self pp_setFieldError:[self pp_requiredErrorForTitle:title] identifier:PPAddAccessoryFieldMainCategoryID];
        if (!firstInvalidIdentifier) firstInvalidIdentifier = PPAddAccessoryFieldMainCategoryID;
        ok = NO;
    }
    if (!self.draftAccessoryCategory) {
        NSString *title = [self pp_localizedStringForKey:@"accessory_form_category_title" fallback:@"Accessory Category"];
        [self pp_setFieldError:[self pp_requiredErrorForTitle:title] identifier:PPAddAccessoryFieldAccessoryCategoryID];
        if (!firstInvalidIdentifier) firstInvalidIdentifier = PPAddAccessoryFieldAccessoryCategoryID;
        ok = NO;
    }
    NSString *nm = [PPAccessorySafeString(self.draftName) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (nm.length == 0) {
        NSString *title = (self.accessKindType == AccessTypeFood)
            ? [self pp_localizedStringForKey:@"food_form_name_title" fallback:@"Food name"]
            : [self pp_localizedStringForKey:@"accessory_form_name_title" fallback:@"Accessory name"];
        [self pp_setFieldError:[self pp_requiredErrorForTitle:title] identifier:PPAddAccessoryFieldName];
        if (!firstInvalidIdentifier) firstInvalidIdentifier = PPAddAccessoryFieldName;
        ok = NO;
    }
    NSNumber *pr = [self pp_numberFromValue:self.draftPrice];
    if (!pr || [pr doubleValue] <= 0) {
        [self pp_setFieldError:[self pp_localizedStringForKey:@"form_price_positive_error" fallback:@"Enter a valid price"] identifier:PPAddAccessoryFieldPrice];
        if (!firstInvalidIdentifier) firstInvalidIdentifier = PPAddAccessoryFieldPrice;
        ok = NO;
    }
    if (!self.draftCity) {
        NSString *title = [self pp_localizedStringForKey:@"form_city_title" fallback:@"City"];
        [self pp_setFieldError:[self pp_requiredErrorForTitle:title] identifier:PPAddAccessoryFieldCityID];
        if (!firstInvalidIdentifier) firstInvalidIdentifier = PPAddAccessoryFieldCityID;
        ok = NO;
    }

    if (!ok && firstInvalidIdentifier.length > 0) {
        [self pp_shakeFieldForIdentifier:firstInvalidIdentifier];
    }
    return ok;
}

- (void)pp_shakeFieldForIdentifier:(NSString *)identifier {
    PPFormFieldRowView *row = [self pp_rowForIdentifier:identifier];
    if (!row) return;
    CGRect rowRect = [row convertRect:row.bounds toView:self.scrollView];
    [self.scrollView scrollRectToVisible:CGRectInset(rowRect, 0.0, -24.0) animated:YES];
    [self pp_shakeView:row];
}

- (void)pp_shakeView:(UIView *)view {
    if (!view) return;
    CAKeyframeAnimation *a = [CAKeyframeAnimation animation];
    a.keyPath = @"position.x";
    a.values = @[@0, @20, @-20, @10, @0];
    a.keyTimes = @[@0, @(1/6.0), @(3/6.0), @(5/6.0), @1];
    a.duration = 0.3; a.additive = YES;
    [view.layer addAnimation:a forKey:@"shake"];
}

#pragma mark - Upload Timeout

- (void)pp_cancelUploadTimeout { if (self.uploadTimeoutBlock) { dispatch_block_cancel(self.uploadTimeoutBlock); self.uploadTimeoutBlock = nil; } }

- (void)pp_scheduleUploadTimeout {
    [self pp_cancelUploadTimeout];
    __weak typeof(self) ws = self;
    dispatch_block_t tb = dispatch_block_create(0, ^{
        __strong typeof(ws) s = ws; if (!s) return; s.uploadTimeoutBlock = nil;
        if (s.isSubmittingAccessory) {
            s.isSubmittingAccessory = NO; s.scrollView.userInteractionEnabled = YES; s.categoryFormView.userInteractionEnabled = YES; s.detailsFormView.userInteractionEnabled = YES; s.imageCollection.userInteractionEnabled = YES;
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
        self.scrollView.userInteractionEnabled = NO; self.categoryFormView.userInteractionEnabled = NO; self.detailsFormView.userInteractionEnabled = NO; self.imageCollection.userInteractionEnabled = NO;
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
        self.scrollView.userInteractionEnabled = YES; self.categoryFormView.userInteractionEnabled = YES; self.detailsFormView.userInteractionEnabled = YES; self.imageCollection.userInteractionEnabled = YES;
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

- (void)pp_submitAccessoryWithReusableMediaIsEditing:(BOOL)isEdit {
    if (!isEdit && self.accessModel.accessoryID.length == 0) self.accessModel.accessoryID = NSUUID.UUID.UUIDString;
    NSString *ownerID = self.accessModel.ownerID.length > 0 ? self.accessModel.ownerID : (UserManager.sharedManager.currentUser.ID ?: @"unknown");
    __weak typeof(self) weakSelf = self;
    [self.imageCollection uploadSelectedMediaWithStorageFolder:@"accessories"
                                                       ownerID:ownerID
                                                     contextID:self.accessModel.accessoryID
                                                    completion:^(PPMediaUploadResult * _Nullable result, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !result) {
                [self pp_handleSubmitFailure:error ?: [NSError errorWithDomain:@"AddNewAccessory"
                                                                          code:-900
                                                                      userInfo:@{NSLocalizedDescriptionKey: [self pp_localizedStringForKey:@"media_upload_failed_message" fallback:@"Media upload failed. Please try again."]}]];
                return;
            }

            [[PetAccessoryManager sharedManager] createAccessory:self.accessModel
                                               uploadedImageURLs:result.imageURLs
                                                   imageMetadata:result.imageMetadata
                                                       videoURLs:result.videoURLs
                                                   videoMetadata:result.videoMetadata
                                                   mixedMetadata:result.mixedMetadata
                                                      completion:^(NSError * _Nullable saveError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (saveError) { [self pp_handleSubmitFailure:saveError]; return; }
                    [self clearSavedDraft]; [self pp_finishSubmitUI]; [self showSuccessAlertForEditing:isEdit];
                });
            }];
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
    // Disabled as per user request to stop auto show keyboard/focus on load
}

- (void)onBack { [self pp_handleBackNavigation]; }
- (void)onBack:(id)sender { (void)sender; [self pp_handleBackNavigation]; }

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_rebuildFormFields];
        [self pp_refreshFormValuesAndStates];
    }
}

#pragma mark - Premium Selector Pickers & Location Detection Helper Methods

- (void)pp_fetchAccessoryCategoriesForMainKind:(MainKindsModel *)mainKind completion:(void (^)(NSArray<PPAccessoryCategoryModel *> *categories))completion {
    if (!mainKind) {
        if (completion) completion(@[]);
        return;
    }

    NSArray<PPAccessoryCategoryModel *> *cached = mainKind.accessoryCategories ?: @[];
    if (cached.count > 0) {
        if (completion) completion(cached);
        return;
    }

    __weak typeof(self) ws = self;
    [[MainKindsArrayManager shared] loadAccessoryCategoriesForMainKind:mainKind completion:^(NSArray<PPAccessoryCategoryModel *> *categories, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            if (error) {
                NSLog(@"❌ Failed to load accessory categories for main kind %ld: %@", (long)mainKind.ID, error.localizedDescription);
            }
            [s pp_refreshFormValuesAndStates];
            if (completion) completion(categories ?: @[]);
        });
    }];
}

- (void)pp_presentAccessoryCategoryPicker {
    if (!self.draftMainKind) return;

    __weak typeof(self) ws = self;
    [self pp_fetchAccessoryCategoriesForMainKind:self.draftMainKind completion:^(NSArray<PPAccessoryCategoryModel *> *categories) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            if (categories.count == 0) {
                [PPAlertHelper showWarningIn:s
                                       title:[s pp_localizedStringForKey:@"accessory_categories_unavailable_title" fallback:@"No categories available"]
                                    subtitle:[s pp_localizedStringForKey:@"accessory_categories_unavailable_message" fallback:@"Please choose another species or try again later."]
                                  completion:nil];
                return;
            }

            PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
                initWithOptions:categories
                          title:[s pp_localizedStringForKey:@"accessory_form_category_selector_title" fallback:@"Select Category"]
                            row:nil presentationStyle:PPSelectOptionPresentationSheet
                     completion:^(id _Nullable obj) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(ws) s2 = ws; if (!s2) return;
                    if ([obj isKindOfClass:[PPAccessoryCategoryModel class]]) {
                        s2.draftAccessoryCategory = obj;
                        s2.accessModel.AccessoryCategoryID = ((PPAccessoryCategoryModel *)obj).categoryID;
                    } else {
                        s2.draftAccessoryCategory = nil;
                        s2.accessModel.AccessoryCategoryID = nil;
                    }
                    s2.hasUserModifiedForm = YES;
                    [s2 pp_refreshFormValuesAndStates];
                });
            }];
            vc.selectedOption = s.draftAccessoryCategory;
            [s presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
        });
    }];
}

- (void)pp_hydrateAccessoryCategoryForModel:(PetAccessory *)model {
    if (model.AccessoryCategoryID.length == 0 || model.petMainCategoryID <= 0) return;
    MainKindsModel *mainKind = self.draftMainKind ?: [MKM mainKindForID:model.petMainCategoryID];
    PPAccessoryCategoryModel *cached = [mainKind accessoryCategoryForID:model.AccessoryCategoryID];
    if (cached) {
        self.draftAccessoryCategory = cached;
        [self pp_refreshFormValuesAndStates];
        return;
    }
    __weak typeof(self) ws = self;
    [self pp_fetchAccessoryCategoriesForMainKind:mainKind completion:^(NSArray<PPAccessoryCategoryModel *> *categories) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            for (PPAccessoryCategoryModel *cat in categories) {
                if ([cat.categoryID isEqualToString:model.AccessoryCategoryID] || [cat.documentID isEqualToString:model.AccessoryCategoryID]) {
                    s.draftAccessoryCategory = cat;
                    [s pp_refreshFormValuesAndStates];
                    break;
                }
            }
        });
    }];
}

- (void)pp_presentCityPicker {
    if (self.citiesList.count == 0) return;

    __weak typeof(self) ws = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:self.citiesList
                  title:[self pp_localizedStringForKey:@"form_city_selector_title" fallback:@"Select City"]
                    row:nil presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable obj) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            if ([obj isKindOfClass:[CityModel class]]) {
                s.draftCity = obj;
                s.accessModel.cityID = ((CityModel *)obj).cityID;
            } else {
                s.draftCity = nil;
                s.accessModel.cityID = 0;
            }
            s.hasUserModifiedForm = YES;
            [s pp_refreshFormValuesAndStates];
        });
    }];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
}

- (void)pp_setupSmartCityPicker {
    if (CitiesManager.shared.countries.count == 0) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_citiesDidUpdate:)
                                                     name:CitiesManagerDidUpdateNotification
                                                   object:nil];
        [CitiesManager.shared loadData];
    } else {
        [self pp_initializeCitiesDataAndDetect];
    }
}

- (void)pp_citiesDidUpdate:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CitiesManagerDidUpdateNotification object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_initializeCitiesDataAndDetect];
    });
}

- (void)pp_initializeCitiesDataAndDetect {
    CountryModel *detectedCountry = CitiesManager.shared.CurrentCountry;
    if (!detectedCountry) {
        detectedCountry = [CitiesManager.shared qatarCountry];
    }

    self.citiesList = detectedCountry.cities ?: @[];

    // 1. If form has editing/existing model city, use it
    if (self.accessModel.cityID > 0) {
        self.draftCity = [CitiesManager.shared cityByID:self.accessModel.cityID];
    }

    // 2. If draftCity is still nil, check if user profile addresses have a cityID
    if (!self.draftCity) {
        UserModel *cu = [UserManager sharedManager].currentUser;
        if (cu.addresses.count > 0) {
            for (PPAddressModel *addr in cu.addresses) {
                if (addr.cityID > 0) {
                    self.draftCity = [CitiesManager.shared cityByID:addr.cityID];
                    if (self.draftCity) {
                        self.accessModel.cityID = self.draftCity.cityID;
                        break;
                    }
                }
            }
        }
    }

    // 3. If draftCity is still nil, request/detect location
    if (!self.draftCity) {
        [self pp_requestLocationAndDetectCity];
    } else {
        [self pp_refreshFormValuesAndStates];
    }
}

- (void)pp_requestLocationAndDetectCity {
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }

    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
    } else if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        CLLocation *cachedLocation = self.locationManager.location;
        if (cachedLocation && CLLocationCoordinate2DIsValid(cachedLocation.coordinate)) {
            [self pp_detectCityFromCoordinate:cachedLocation.coordinate];
        } else {
            [self.locationManager startUpdatingLocation];
        }
    } else {
        [self pp_applyDefaultCityFallback];
    }
}

- (void)pp_applyDefaultCityFallback {
    if (!self.draftCity && self.citiesList.count > 0) {
        CountryModel *detectedCountry = CitiesManager.shared.CurrentCountry ?: [CitiesManager.shared qatarCountry];
        CityModel *defaultCity = [CitiesManager.shared defaultCityForCountry:detectedCountry];
        if (defaultCity) {
            self.draftCity = defaultCity;
            self.accessModel.cityID = defaultCity.cityID;
        } else {
            self.draftCity = self.citiesList.firstObject;
            self.accessModel.cityID = self.draftCity.cityID;
        }
        [self pp_refreshFormValuesAndStates];
    }
}

- (void)pp_detectCityFromCoordinate:(CLLocationCoordinate2D)coordinate {
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        [self pp_applyDefaultCityFallback];
        return;
    }

    __weak typeof(self) ws = self;
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocation *loc = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    [geocoder reverseGeocodeLocation:loc completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) s = ws; if (!s) return;
            CityModel *matchedCity = nil;
            CLPlacemark *placemark = placemarks.firstObject;

            if (placemark) {
                NSArray<NSString *> *candidateNames = @[
                    placemark.locality ?: @"",
                    placemark.subAdministrativeArea ?: @"",
                    placemark.administrativeArea ?: @"",
                ];

                for (NSString *candidateName in candidateNames) {
                    if (candidateName.length == 0) continue;
                    NSString *normalizedCandidate = [candidateName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;

                    for (CityModel *city in s.citiesList) {
                        NSString *en = city.enName.lowercaseString;
                        NSString *ar = city.arName.lowercaseString;
                        if ([normalizedCandidate isEqualToString:en] || [normalizedCandidate isEqualToString:ar] ||
                            [en containsString:normalizedCandidate] || [ar containsString:normalizedCandidate]) {
                            matchedCity = city;
                            break;
                        }
                    }
                    if (matchedCity) break;
                }
            }

            if (!matchedCity && s.citiesList.count > 0) {
                CLLocation *target = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
                CLLocationDistance bestDistance = DBL_MAX;

                for (CityModel *city in s.citiesList) {
                    if (city.latitude == 0 && city.longitude == 0) continue;
                    CLLocation *cityLoc = [[CLLocation alloc] initWithLatitude:city.latitude longitude:city.longitude];
                    CLLocationDistance distance = [target distanceFromLocation:cityLoc];
                    if (distance < bestDistance) {
                        bestDistance = distance;
                        matchedCity = city;
                    }
                }
            }

            if (matchedCity) {
                s.draftCity = matchedCity;
                s.accessModel.cityID = matchedCity.cityID;
            } else {
                [s pp_applyDefaultCityFallback];
            }
            [s pp_refreshFormValuesAndStates];
        });
    }];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    if (location && CLLocationCoordinate2DIsValid(location.coordinate)) {
        [manager stopUpdatingLocation];
        [self pp_detectCityFromCoordinate:location.coordinate];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [manager stopUpdatingLocation];
    NSLog(@"❌ Location detection failed: %@", error.localizedDescription);
    [self pp_applyDefaultCityFallback];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self pp_applyDefaultCityFallback];
    }
}

@end
