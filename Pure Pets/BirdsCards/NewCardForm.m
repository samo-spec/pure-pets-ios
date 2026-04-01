//
//  ViewController.m
//  projectxlforms
//
//  Created by IQRQA on 12/14/16.
//  Copyright © 2016 IQRQA. All rights reserved.
//

#import "NewCardForm.h"
#import "AppDelegate.h"
#import "BKCircularLoadingButton.h"


#import "selectTableViewController.h"
#import "PPCommerceFeedbackManager.h"





@interface MY_Media : NSObject
@property (nonatomic) FileType fileType;
@property (nonatomic) NSString *FileName;
@property (nonatomic) UIImage *imageFile;
@property (nonatomic) NSString *FileUrl;
@end

@implementation MY_Media

@end

static NSString *const kCustomRowText = @"kCustomText";
static NSString *const kNewCardDraftDefaultsPrefix = @"pp.new_card_form.draft";
static NSString *const kNewCardDraftFormDataKey = @"formData";
static NSString *const kNewCardDraftGalleryPathsKey = @"galleryImagePaths";
static NSString *const kNewCardDraftDNAPathKey = @"dnaImagePath";

@interface NewCardForm () {

    NSString *userID;
    NSString *SubKindPlace;
    NSString *subSubKindPlace;
    NSString *ClassificationPlace;
    float topbarHeight;

    NSInteger birdSexual;
   
    int AttributeNoteAdded;
    long finishFlag;
    int initFlag;

    NSString *alertTitleLoad;
    NSString *alertSubtitleLoad;

    NSString *alertTitleError;
    NSString *alertSubtitleError;

    NSInteger formFinishupload;

    NSString *_alertWarningDataTitle;
    NSString *_alertWarningDataSubTitle;

    NSString *alertAddImagesTitle;
    NSString *alertAddImagesDesc;

    NSString *alertRingIDText;
    NSString *alertSubKindIDText;

    FIRStorage *storage;

    NSMutableArray *selectedImagesNames;
}
@property (assign, nonatomic) NSInteger currentAdultHood;
@property (nonatomic, strong) NSMutableDictionary *formDataArray;
 
@property (nonatomic, strong) UIActivityIndicatorView *uploadProgressV;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) FIRStorageReference *storageRef;
@property (nonatomic, strong) XLFormDescriptor *mform; // Add your mform Property here.
@property (nonatomic, strong) BKCircularLoadingButton *BKbutton; // Add your BKbutton Property here.
@property (nonatomic, strong) NSUserDefaults *prefs;
@property (nonatomic, strong) NSString *alertTitleDone;
@property (nonatomic, strong) NSString *alertSubtitleDone;
@property (nonatomic, strong) NSString *alertWarningDataTitle;
@property (nonatomic, strong) NSString *alertWarningDataSubTitle;

//@property (nonatomic, strong) CardModel *cardToUpload;

@property XLFormRowDescriptor *SubKindRow;
@property XLFormRowDescriptor *colorTXTRow;
@property XLFormRowDescriptor *attributeRow;
@property XLFormRowDescriptor *MotherRow;
@property XLFormRowDescriptor *FatherRow;

@property XLFormRowDescriptor *ageRow;
@property XLFormRowDescriptor *AttributeNote;
@property NSArray *SubKindsArrayList;
@property NSArray *subSubKindsArrayList;
@property NSArray *subKindItemsArrayList;
@property NSMutableArray *selectedItemsArray;
@property NSMutableArray *selectedItemsLoadedArray;

@property NSArray<SubKindModel *> *SubKindsArrayLocal;
@property NSArray<subSubKindModel *> *subSubKindsArrayLocal;
@property NSMutableArray<subKindItemsModel *> *subKindItemsArrayLocal;

@property NSMutableArray<subKindItemsModel *> *LoadedItemsMaleArrayLocal;
@property NSMutableArray<subKindItemsModel *> *LoadedItemsFemaleArrayLocal;

@property NSArray<CardModel *> *fathersCardsArray;
@property NSArray<CardModel *> *mothersCardsArray;

@property NSMutableArray<subKindItemsModel *> *ItemsloveArray;
@property NSMutableArray<subKindItemsModel *> *ItemsSexualloveArray;
@property NSMutableArray<subKindItemsModel *> *globalItemsArray;
@property NSMutableArray *attributeArrayLocat;

@property (nonatomic, strong) NSArray<CardModel *> *CardsdataSource;
@property (nonatomic, strong) NSArray<CardModel *> *allCardsArray;
@property (strong, nonatomic) UIButton *closeBtnIB;

@property (nonatomic, strong) TTGSnackbar *snakBar;
@property NSMutableArray<MainKindsModel *> *MainKindsArray;

@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;
@property (nonatomic, strong) NSMutableArray *imagesFromStorage;  // To store downloaded UIImage
@property (nonatomic, strong) FileUploadManager *uploadManager;
@property (nonatomic, assign) BOOL didChangeImages;
@property (nonatomic, assign) BOOL isHydratingImages;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, assign) BOOL hasUserModifiedForm;

@property  SubKindModel *selectedSubKindModel;
@end;


#pragma mark - NSValueTransformer
@interface NSArrayValueTrasformerNewCard : NSValueTransformer @end

@implementation NSArrayValueTrasformerNewCard

+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    if (!value) {
        return nil;
    }

    if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray *)value;
        return [NSString stringWithFormat:@"%@ Item%@", @(array.count), array.count > 1 ? @"s" : @""];
    }

    if ([value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"%@ - ;) - Transformed", value];
    }

    return nil;
}

@end




@implementation NewCardForm


NSString *const RingIDValidation = @"RingID";
NSString *const SubKindValidation = @"SubKind";
NSString *const subSubKindValidation = @"subSubKind";
NSString *const ClassificationValidation = @"Classification";
NSString *const attributeValidation = @"attribute";
NSString *const BirthDateValidation = @"BirthDate";
NSString *const SexualValidation = @"Sexual";
NSString *const kSelectorUser = @"selectorUser";
NSString *const kselectorParent = @"selectorParent";
NSString *const kSelectorUserPopover = @"kSelectorUserPopover";
NSString *const no_value = @"no_value";


- (AppDelegate *)AppDelegate {
    return (AppDelegate *)[[UIApplication sharedApplication]delegate];
}

@synthesize BKbutton = _BKbutton;

- (BKCircularLoadingButton *)BKbutton
{
    if (_BKbutton) {
        return _BKbutton;
    }

    _BKbutton = [BKCircularLoadingButton autolayoutView];
    [_BKbutton setContentHuggingPriority:500 forAxis:UILayoutConstraintAxisHorizontal];
    return _BKbutton;
}


UIBarButtonItem *addbutton;

#pragma mark - Programmatic Header Setup

- (void)setupHeaderViews {
    CGFloat headerHeight = 56.0;

    _topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), headerHeight)];
    _topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _topView.backgroundColor = AppClearClr;
    [self.view addSubview:_topView];

    _topTitle = [[UILabel alloc] init];
    _topTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _topTitle.textAlignment = NSTextAlignmentCenter;
    _topTitle.textColor = [UIColor whiteColor];
    _topTitle.font = [GM MidFontWithSize:17];
    [_topView addSubview:_topTitle];

    [NSLayoutConstraint activateConstraints:@[
        [_topTitle.centerXAnchor constraintEqualToAnchor:_topView.centerXAnchor],
        [_topTitle.bottomAnchor constraintEqualToAnchor:_topView.bottomAnchor constant:-8],
        [_topTitle.leadingAnchor constraintGreaterThanOrEqualToAnchor:_topView.leadingAnchor constant:50],
        [_topTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_topView.trailingAnchor constant:-50],
    ]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupHeaderViews];

    self.storageRef = [GM CardsImagesRefrence];
    self.uploadManager = [[FileUploadManager alloc] init];
    self.formDataArray = [NSMutableDictionary new];
    self.allCardsArray = AppData.AllCardsDocs;
    self.didChangeImages = NO;
    self.isHydratingImages = NO;
    self.isSaving = NO;
    self.isHydratingFormData = YES;
    self.hasUserModifiedForm = NO;

    self.mform = [XLFormDescriptor formDescriptorWithTitle:@""];
    
    [self initializeForm];
    //[self.mform setAddAsteriskToRequiredRowsTitle:YES];
    
    self.view.layer.cornerRadius = 25;
    self.view.clipsToBounds = YES;
    //initFlag
    initFlag = 0;
    finishFlag = 0;
    formFinishupload = 0;
   #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
  
    topbarHeight = self.navigationController.navigationBar.hx_maxy;
    _topView.hx_h = topbarHeight;
   
    self.modalInPresentation = YES;
    // Do any additional setup after loading the view, typically from a nib.

    NSLog(@"self.FromVC  %@", self.FromVC);
    dispatch_async_on_main_queue(^{
    });
    [self setClassTpForm];

    if([self.FromVC isEqualToString:@"ViewData"])
        self.title = kLang(@"EditCard");
    else if([self.FromVC isEqualToString:@"ViewDatas"])
        self.title = kLang(@"EditCard");
    else
        self.title = kLang(@"addNewCard");
     

    _prefs = [NSUserDefaults standardUserDefaults];
    _storageRef = [GM CardsImagesRefrence];
    _alertTitleDone = kLang(@"doneTitle");
    _alertSubtitleDone = kLang(@"AddedAlertSubtitleDone");
    _alertWarningDataTitle = kLang(@"warningTitle");
    _alertWarningDataSubTitle = kLang(@"warningSubTitle");
    [self syncFormDataWithServerCardIfNeeded];
    if (self.prefilledRingID.length > 0 && ![self isEditingFlow]) {
        [self setformDataArray:self.prefilledRingID forKey:@"RingID"];
        [self setForDataForRow:@"RingID" andValue:self.prefilledRingID];
    }
    // Initialize UI components
    
    [self setupImageCollection];
    [self restoreDraftIfNeeded];
    self.isHydratingFormData = NO;
}

- (void)setupImageCollection {
    
    
    
    
    // Create image collection view
    // Remove the frame setting and autoresizing mask
    self.imageCollection = [[PPImageCollection alloc] initWithFrame:CGRectZero maxImageCount:8 useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.useArabic = Language.isRTL;
    self.imageCollection.titleText = kLang(@"AccessPostPhotosSection");
    self.imageCollection.translatesAutoresizingMaskIntoConstraints = NO;
    // Create a container view for the image collection
    UIView *footerContainer = [[UIView alloc] init];
    [footerContainer addSubview:self.imageCollection];

    // Add constraints to make image collection fill the container
    //self.imageCollection.frame = CGRectMake(20, 0, self.view.hx_w - 40, 100);
    // Or use auto layout:
     [self.imageCollection.leadingAnchor constraintEqualToAnchor:footerContainer.leadingAnchor constant:20].active = YES;
     [self.imageCollection.trailingAnchor constraintEqualToAnchor:footerContainer.trailingAnchor constant:-20].active = YES;
     [self.imageCollection.topAnchor constraintEqualToAnchor:footerContainer.topAnchor].active = YES;
     [self.imageCollection.bottomAnchor constraintEqualToAnchor:footerContainer.bottomAnchor].active = YES;

    // Calculate required height
    CGFloat requiredHeight = 150;
    footerContainer.frame = CGRectMake(0, 0, self.view.hx_w, requiredHeight);

    self.tableView.tableFooterView = footerContainer;

    // Adjust table view insets if needed
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, requiredHeight, 0);
   
    // Prefill images if editing
    if (self.serverCardClass.imagesUrls.count > 0) {
        [self prefillPhotosForEdit];
    }
}

- (BOOL)isEditingFlow
{
    if (!self.serverCardClass) return NO;
    return ([_FromVC isEqual:@"ViewData"] ||
            [_FromVC isEqual:@"main"] ||
            [_FromVC isEqual:@"childs"]);
}

- (BOOL)isNoValueString:(NSString *)value
{
    if (![value isKindOfClass:NSString.class]) return YES;
    NSString *trimmed = [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return (trimmed.length == 0 ||
            [trimmed isEqualToString:@"no_value"] ||
            [trimmed isEqualToString:@"null"] ||
            [trimmed isEqualToString:@"(null)"] ||
            [trimmed isEqualToString:@"<null>"] ||
            [trimmed isEqualToString:@"nil"]);
}

- (NSString *)trimmedStringOrNil:(NSString *)value
{
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

- (void)syncFormDataWithServerCardIfNeeded
{
    if (![self isEditingFlow]) return;

    CardModel *card = self.serverCardClass;
    [self setformDataArray:card.RingID forKey:@"RingID"];
    [self setformDataArray:@(card.SubKind) forKey:@"SubKind"];

    if (card.subSubKindID > 0) {
        [self setformDataArray:@(card.subSubKindID) forKey:@"subSubKindID"];
    }

    if (![self isNoValueString:card.FatherRingID]) {
        [self setformDataArray:card.FatherRingID forKey:@"FatherRingID"];
    }

    if (![self isNoValueString:card.MotherRingID]) {
        [self setformDataArray:card.MotherRingID forKey:@"MotherRingID"];
    }

    if (card.BirthDate) {
        [self setformDataArray:card.BirthDate forKey:@"BirthDate"];
    }

    if (card.Sexual == 1 || card.Sexual == 2) {
        [self setformDataArray:@(card.Sexual) forKey:@"Sexual"];
    }

    if (card.attribute > 0) {
        [self setformDataArray:[NSString stringWithFormat:@"%ld", (long)card.attribute] forKey:@"attribute"];
    }

    if (![self isNoValueString:card.AttributeNote]) {
        [self setformDataArray:card.AttributeNote forKey:@"AttributeNote"];
    }

    if (![self isNoValueString:card.birdColor]) {
        [self setformDataArray:card.birdColor forKey:@"birdColor"];
    }

    if (![self isNoValueString:card.AdDesc]) {
        [self setformDataArray:card.AdDesc forKey:@"AdDesc"];
    }

    if (![self isNoValueString:card.Dna]) {
        [self setformDataArray:card.Dna forKey:@"dnaImageName"];
    }

    NSMutableArray<NSNumber *> *selectedItems = [NSMutableArray array];
    for (NSString *item in [card.subKindItemsID componentsSeparatedByString:@","]) {
        NSInteger itemID = item.integerValue;
        if (itemID > 0) [selectedItems addObject:@(itemID)];
    }
    if (selectedItems.count > 0) {
        [self setformDataArray:selectedItems forKey:@"selectedItemsArray"];
    }

    NSMutableArray<NSNumber *> *selectedSplitItems = [NSMutableArray array];
    for (NSString *item in [card.splitID componentsSeparatedByString:@","]) {
        NSInteger itemID = item.integerValue;
        if (itemID > 0) [selectedSplitItems addObject:@(itemID)];
    }
    if (selectedSplitItems.count > 0) {
        [self setformDataArray:selectedSplitItems forKey:@"selectedItemsLoadedArray"];
    }
}

- (void)restoreFormAfterUploadAttempt
{
    self.isSaving = NO;
    self.navigationItem.leftBarButtonItem.enabled = YES;
    [self.BKbutton stopAnimation];
    [self.BKbutton setEnabled:YES];
    [self.tableView setUserInteractionEnabled:YES];
    self.form.disabled = NO;
    self.mform.disabled = NO;
    [self.uploadProgressView stopAnimating];
}

- (void)closeSelfController
{
    if (self.navigationController &&
        self.navigationController.viewControllers.count > 1 &&
        self.navigationController.topViewController == self) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (NSString *)draftStorageKey
{
    NSString *currentUserID = PPSafeString(UserManager.sharedManager.currentUser.ID);
    if ([self isEditingFlow] && self.serverCardClass.ID.length) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@",
                kNewCardDraftDefaultsPrefix,
                self.serverCardClass.ID,
                currentUserID];
    }

    return [NSString stringWithFormat:@"%@.new.%@",
            kNewCardDraftDefaultsPrefix,
            currentUserID];
}

- (NSString *)draftDirectoryPath
{
    NSString *draftID = [[[self draftStorageKey]
                          stringByReplacingOccurrencesOfString:@"." withString:@"_"]
                         stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pp_form_drafts"];
    return [root stringByAppendingPathComponent:draftID];
}

- (NSData *)archivedDraftDataForObject:(id)object
{
    if (!object) return nil;

    if (@available(iOS 11.0, *)) {
        NSError *archiveError = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object
                                             requiringSecureCoding:NO
                                                             error:&archiveError];
        if (archiveError) {
            NSLog(@"Failed to archive new card draft: %@", archiveError.localizedDescription);
        }
        return data;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedArchiver archivedDataWithRootObject:object];
#pragma clang diagnostic pop
}

- (id)unarchivedDraftObjectFromData:(NSData *)data
{
    if (![data isKindOfClass:NSData.class] || data.length == 0) return nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}

- (NSDictionary *)draftFormDataSnapshot
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    NSDictionary *source = [self.formDataArray copy] ?: @{};

    [source enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        (void)stop;
        if (![key isKindOfClass:NSString.class]) return;
        if ([key isEqualToString:@"DNAImage"]) return;
        if (!obj || obj == [NSNull null]) return;

        if ([obj isKindOfClass:NSString.class]) {
            NSString *value = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!value.length ||
                [value.lowercaseString isEqualToString:@"no_value"] ||
                [value.lowercaseString isEqualToString:@"null"] ||
                [value.lowercaseString isEqualToString:@"<null>"] ||
                [value.lowercaseString isEqualToString:@"(null)"] ||
                [value.lowercaseString isEqualToString:@"nil"]) {
                return;
            }
        }

        snapshot[key] = obj;
    }];

    if (userID.length) {
        snapshot[@"UserID"] = userID;
    }
    if (PPCurrentUser.UserName.length) {
        snapshot[@"OwnerName"] = PPCurrentUser.UserName;
    }

    return snapshot.copy;
}

- (NSString *)writeDraftImage:(UIImage *)image
                      named:(NSString *)fileName
                  directory:(NSString *)directory
{
    if (!image || !fileName.length || !directory.length) return nil;

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
                                directory:(NSString *)directory
{
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

- (NSArray<UIImage *> *)imagesFromDraftPaths:(NSArray<NSString *> *)paths
{
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

- (void)showDraftSnackbarMessage:(NSString *)message
{
    if (message.length == 0) return;

    self.snakBar = [[TTGSnackbar alloc] initWithMessage:message duration:1.6];
    [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromBottomBackToBottom];
    self.snakBar.messageTextAlign = NSTextAlignmentCenter;
    self.snakBar.cornerRadius = 18;
    [self.snakBar setIconTintColor:AppForgroundColr];
    [self.snakBar show];
}

- (void)clearSavedDraft
{
    NSString *directory = [self draftDirectoryPath];
    [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
    [self.prefs removeObjectForKey:[self draftStorageKey]];
    [self.prefs synchronize];
}

- (void)saveDraftForLater
{
    NSDictionary *snapshot = [self draftFormDataSnapshot];
    NSString *directory = [self draftDirectoryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    [fileManager removeItemAtPath:directory error:nil];
    [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray<NSString *> *galleryPaths = [self writeDraftImages:[self.imageCollection allImages]
                                                    withPrefix:@"gallery"
                                                     directory:directory];

    NSString *dnaImagePath = nil;
    UIImage *dnaImage = [self.formDataArray objectForKey:@"DNAImage"];
    if ([dnaImage isKindOfClass:UIImage.class]) {
        dnaImagePath = [self writeDraftImage:dnaImage named:@"dna.jpg" directory:directory];
    }

    NSData *archivedSnapshot = [self archivedDraftDataForObject:snapshot];
    if (!archivedSnapshot) {
        return;
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[kNewCardDraftFormDataKey] = archivedSnapshot;
    payload[kNewCardDraftGalleryPathsKey] = galleryPaths ?: @[];
    if (dnaImagePath.length) {
        payload[kNewCardDraftDNAPathKey] = dnaImagePath;
    }

    [self.prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [self.prefs synchronize];
}

- (void)applyDraftValue:(id)value
               toRowTag:(NSString *)tag
           triggerBlock:(BOOL)triggerBlock
{
    XLFormRowDescriptor *row = [self.form formRowWithTag:tag];
    if (!row || !value || value == [NSNull null]) return;

    id oldValue = row.value;
    row.value = value;
    [self updateFormRow:row];

    if (triggerBlock && row.onChangeBlock) {
        row.onChangeBlock(oldValue, value, row);
    }
}

- (NSArray<subKindItemsModel *> *)draftItemModelsFromIDs:(NSArray *)storedIDs
{
    if (![storedIDs isKindOfClass:NSArray.class] || storedIDs.count == 0) return @[];

    NSMutableArray<subKindItemsModel *> *items = [NSMutableArray array];
    for (id rawValue in storedIDs) {
        NSInteger itemID = [rawValue integerValue];
        subKindItemsModel *match =
        [[self.subKindItemsArrayLocal filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"SELF.ID == %ld", itemID]] firstObject];
        if (match) {
            [items addObject:match];
        }
    }
    return items.copy;
}

- (void)restoreDraftIfNeeded
{
    NSDictionary *payload = [self.prefs objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) return;

    NSData *archivedSnapshot = payload[kNewCardDraftFormDataKey];
    NSDictionary *storedSnapshot = [self unarchivedDraftObjectFromData:archivedSnapshot];
    if (![storedSnapshot isKindOfClass:NSDictionary.class] || storedSnapshot.count == 0) {
        [self clearSavedDraft];
        return;
    }

    self.isHydratingFormData = YES;
    NSMutableDictionary *mergedValues = [self.formDataArray mutableCopy] ?: [NSMutableDictionary dictionary];
    [mergedValues addEntriesFromDictionary:storedSnapshot];
    self.formDataArray = mergedValues;

    NSString *ringID = PPSafeString(storedSnapshot[@"RingID"]);
    if (ringID.length) {
        [self applyDraftValue:ringID toRowTag:@"RingID" triggerBlock:YES];
    }

    NSNumber *subKindID = storedSnapshot[@"SubKind"];
    if ([subKindID respondsToSelector:@selector(integerValue)]) {
        SubKindModel *subKind =
        [[self.SubKindsArrayLocal filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"SELF.ID == %ld", subKindID.integerValue]] firstObject];
        if (subKind) {
            [self applyDraftValue:subKind toRowTag:@"SubKind" triggerBlock:YES];
        }
    }

    NSNumber *subSubKindID = storedSnapshot[@"subSubKindID"];
    if ([subSubKindID respondsToSelector:@selector(integerValue)]) {
        subSubKindModel *subSubKind =
        [[self.subSubKindsArrayLocal filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"SELF.ID == %ld", subSubKindID.integerValue]] firstObject];
        if (subSubKind) {
            [self applyDraftValue:subSubKind toRowTag:@"subSubKind" triggerBlock:YES];
        }
    }

    NSArray *classificationIDs = storedSnapshot[@"selectedItemsArray"];
    NSArray<subKindItemsModel *> *classificationItems = [self draftItemModelsFromIDs:classificationIDs];
    if (classificationItems.count > 0) {
        [self applyDraftValue:classificationItems toRowTag:@"Classification" triggerBlock:YES];
    }

    NSInteger attributeIndex = [storedSnapshot[@"attribute"] integerValue];
    if (attributeIndex > 0 && attributeIndex <= self.attributeArrayLocat.count) {
        NSString *attributeValue = self.attributeArrayLocat[attributeIndex - 1];
        [self applyDraftValue:attributeValue toRowTag:@"attribute" triggerBlock:YES];
    }

    NSString *attributeNote = PPSafeString(storedSnapshot[@"AttributeNote"]);
    if (attributeNote.length) {
        [self applyDraftValue:attributeNote toRowTag:@"AttributeNote" triggerBlock:YES];
    }

    NSString *birdColor = PPSafeString(storedSnapshot[@"birdColor"]);
    if (birdColor.length) {
        [self applyDraftValue:birdColor toRowTag:@"colorTXT" triggerBlock:YES];
    }

    NSDate *birthDate = storedSnapshot[@"BirthDate"];
    if ([birthDate isKindOfClass:NSDate.class]) {
        [self applyDraftValue:birthDate toRowTag:@"BirthDate" triggerBlock:YES];
    }

    NSString *fatherID = PPSafeString(storedSnapshot[@"FatherRingID"]);
    if (fatherID.length) {
        CardModel *father =
        [[self.allCardsArray filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"SELF.ID == %@", fatherID]] firstObject];
        if (father) {
            [self applyDraftValue:father toRowTag:@"FatherRingID" triggerBlock:YES];
        }
    }

    NSString *motherID = PPSafeString(storedSnapshot[@"MotherRingID"]);
    if (motherID.length) {
        CardModel *mother =
        [[self.allCardsArray filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"SELF.ID == %@", motherID]] firstObject];
        if (mother) {
            [self applyDraftValue:mother toRowTag:@"motherRingID" triggerBlock:YES];
        }
    }

    NSInteger sexualValue = [storedSnapshot[@"Sexual"] integerValue];
    if (sexualValue == 1 || sexualValue == 2) {
        NSString *localizedSexual = sexualValue == 1 ? kLang(@"Male") : kLang(@"Female");
        [self applyDraftValue:localizedSexual toRowTag:@"Sexual" triggerBlock:YES];
    }

    NSArray *loadedClassificationIDs = storedSnapshot[@"selectedItemsLoadedArray"];
    NSArray<subKindItemsModel *> *loadedItems = [self draftItemModelsFromIDs:loadedClassificationIDs];
    if (loadedItems.count > 0) {
        [self applyDraftValue:loadedItems toRowTag:@"ClassificationLoaded" triggerBlock:YES];
    }

    NSString *adDesc = PPSafeString(storedSnapshot[@"AdDesc"]);
    if (adDesc.length) {
        [self applyDraftValue:adDesc toRowTag:@"AdDesc" triggerBlock:YES];
    }

    NSString *dnaImageName = PPSafeString(storedSnapshot[@"dnaImageName"]);
    NSString *dnaImagePath = PPSafeString(payload[kNewCardDraftDNAPathKey]);
    if (dnaImagePath.length) {
        UIImage *dnaImage = [UIImage imageWithContentsOfFile:dnaImagePath];
        if (dnaImage) {
            [self setformDataArray:dnaImage forKey:@"DNAImage"];
            if (dnaImageName.length) {
                [self setformDataArray:dnaImageName forKey:@"dnaImageName"];
            }
            [self applyDraftValue:dnaImage toRowTag:@"dnaImage" triggerBlock:NO];
        }
    }

    NSArray<NSString *> *storedGalleryPaths = payload[kNewCardDraftGalleryPathsKey];
    if ([storedGalleryPaths isKindOfClass:NSArray.class]) {
        NSArray<UIImage *> *galleryImages = [self imagesFromDraftPaths:storedGalleryPaths];
        self.isHydratingImages = YES;
        [self.imageCollection clearAllImages];
        if (galleryImages.count > 0) {
            [self.imageCollection addImages:galleryImages];
        }
        self.isHydratingImages = NO;
    }

    self.hasUserModifiedForm = NO;
    self.didChangeImages = NO;
    self.isHydratingFormData = NO;
    [self.tableView reloadData];
    [self showDraftSnackbarMessage:kLang(@"form_draft_restored")];
}

- (void)presentUnsavedChangesPromptFromBarButtonItem:(UIBarButtonItem *)buttonItem
{
    (void)buttonItem;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"form_draft_prompt_title")
                                                                   message:kLang(@"form_draft_prompt_message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.view.tintColor = [GM appPrimaryColor];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_save_and_close")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf saveDraftForLater];
        [strongSelf.prefs setInteger:0 forKey:@"FromForm"];
        [strongSelf closeSelfController];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_discard")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf clearSavedDraft];
        [strongSelf.prefs setInteger:0 forKey:@"FromForm"];
        [strongSelf closeSelfController];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_keep_editing")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Image Management

- (void)prefillPhotosForEdit {
    if (self.serverCardClass.imagesUrls.count == 0) return;

    self.isHydratingImages = YES;
    __weak typeof(self) weakSelf = self;
    [self.imageCollection preloadImagesFromURLs:self.serverCardClass.imagesUrlsStrings completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.isHydratingImages = NO;
        strongSelf.didChangeImages = NO;
        NSLog(@"Prefilled %ld images for editing", (long)strongSelf.serverCardClass.imagesUrlsStrings.count);
    }];
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    if (!self.isHydratingImages) {
        self.didChangeImages = YES;
    }
    NSLog(@"Image collection updated with %ld images", (long)images.count);
}

- (void)imageCollection:(PPImageCollection *)collection didSelectImage:(nonnull UIImage *)selectedImage AtIndex:(NSInteger)index{
    
    [collection presentEditorForImageAtIndex:index fromViewController:self];
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    [collection presentPickerFromViewController:self];
}

- (void)setClassTpForm
{
    if ([_FromVC isEqual:@"ViewData"] || [_FromVC isEqual:@"main"] || [_FromVC isEqual:@"childs"]) {
        
        
        if ([_FromVC isEqual:@"ViewData"] || [_FromVC isEqual:@"main"]) {
            _topTitle.text = kLang(@"topTitleEditCard");
        } else {
            _topTitle.text = kLang(@"topTitleCompleteChild");
        }

        if (self.serverCardClass.FilesArray.count > 0) {
            self.imagesFromStorage = [[NSMutableArray alloc] init];
          //  NSMutableArray<FileModel *> *FilesArray = [self.serverCardClass.FilesArray mutableCopy];
        }

        

        NSLog(@"_self.serverCardClass.FilesArray  %@ ", [self.serverCardClass.FilesArray valueForKey:@"FileUrl"]);
        // Ring ID
        [self setForDataForRow:@"RingID" andValue:self.serverCardClass.RingID];

        // SUB KIND
        SubKindModel *SubKind =  [[self.SubKindsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.serverCardClass.SubKind]] firstObject];

        if (SubKind) {
            [self setForDataForRow:@"SubKind" andValue:SubKind];
        }

        // SUB SUB KIND
        subSubKindModel *subSubKindID =  [[self.subSubKindsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.serverCardClass.subSubKindID]] firstObject];

        if (subSubKindID) {
            [self setForDataForRow:@"subSubKind" andValue:subSubKindID];
        }

        //NSLog(@" tempCardClass.FatherRingID %@", self.serverCardClass.FatherRingID);
        if (![self.serverCardClass.FatherRingID isEqualToString:@"no_value"]) {
            CardModel *FRingID = [[self.allCardsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.serverCardClass.FatherRingID]] firstObject];

            if (FRingID) {
                self.FatherRow.value = FRingID;
            }
        }

        //MotherRow
        if (![self.serverCardClass.MotherRingID isEqualToString:@"no_value"]) {
            CardModel *MRingID = [[self.allCardsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.serverCardClass.MotherRingID]] firstObject];

            if (MRingID) {
                self.MotherRow.value = MRingID;
            }
        }

        // ATTRIBUTE
        if ([_FromVC isEqual:@"ViewData"]  || [_FromVC isEqual:@"main"]) {
            // SUB SUB KIND
            NSMutableArray<subKindItemsModel *> *selectedItemsModels = [[NSMutableArray<subKindItemsModel *> alloc] init];
            NSArray *subKindItemsIDs = [self.serverCardClass.subKindItemsID componentsSeparatedByString:@","];

            for (NSString *ItemID in subKindItemsIDs) {
                if ([[self.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject]) {
                    subKindItemsModel *itemModel = [[self.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject];
                    [selectedItemsModels addObject:itemModel];
                }
            }

            if (selectedItemsModels.count > 0) {
                [self setForDataForRow:@"Classification" andValue:selectedItemsModels];
            }

            if (self.serverCardClass.attribute < (self.attributeArrayLocat.count)) {
                
                
                NSLog(@"HERE \n self.serverCardClass.attribute %ld    \n self.attributeArrayLocat.count %ld",self.serverCardClass.attribute,self.attributeArrayLocat.count);
                NSString *attributeString =  [self.attributeArrayLocat objectAtIndex:(self.serverCardClass.attribute == 0 ? 0 : self.serverCardClass.attribute - 1)];

                 if (self.serverCardClass.attribute != 0) {
                     [self setForDataForRow:@"attribute" andValue:attributeString];
                 }
             }
            

            // COLOR
            NSString *birdColor =  self.serverCardClass.birdColor;

            if (![birdColor isEqualToString:@"no_value"]) {
                [self setForDataForRow:@"colorTXT" andValue:birdColor];
            }

            // DATE
            if (self.serverCardClass.BirthDate) {
                NSLog(@" self.serverCardClass.BirthDate %@", self.serverCardClass.BirthDate);
                [self setForDataForRow:@"BirthDate" andValue:self.serverCardClass.BirthDate];
                [self setformDataArray:self.serverCardClass.BirthDate forKey:@"BirthDate"];
            }

            // SEXUAL
            NSString *Sexual =  self.serverCardClass.getBirdSexual;

            if (![Sexual isEqualToString:@"no_value"]) {
                [self setForDataForRow:@"Sexual" andValue:Sexual];
            }

            selectedItemsModels = [[NSMutableArray<subKindItemsModel *> alloc] init];
            NSArray *splitIDs = [self.serverCardClass.splitID componentsSeparatedByString:@","];

            if (![self.serverCardClass.splitID isEqualToString:@"no_value"]) {
                for (NSString *ItemID in splitIDs) {
                    if ([[self.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject]) {
                        subKindItemsModel *ItemModel = [[self.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject];
                        [selectedItemsModels addObject:ItemModel];
                    }
                }

                if (selectedItemsModels.count > 0) {
                    [self setForDataForRow:@"ClassificationLoaded" andValue:selectedItemsModels];
                }
            }

            // AD DESC
            if (![self.serverCardClass.AdDesc isEqualToString:@"no_value"]) {
                [self setForDataForRow:@"AdDesc" andValue:self.serverCardClass.AdDesc];
            }

            if (![self.serverCardClass.Dna isEqualToString:@"no_value"]) {
                // Create a reference to the file you want to download
                NSString *str = [NSString stringWithFormat:@"%@/%@", [GM CardsImagesRefStr], self.serverCardClass.Dna];
                FIRStorageReference *starsRef = [self.storageRef child:str];

                // Fetch the download URL
                [starsRef downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
                    if (error != nil) {
                        // Handle any errors
                    } else {
                        // NSLog(@"IMAGE FROM CardsImages ---------->>> URL IS::: %@ ",URL);
                        [[SDWebImageManager sharedManager] loadImageWithURL:URL
                                                                    options:0
                                                                   progress:nil
                                                                  completed:^(UIImage *_Nullable image, NSData *_Nullable data, NSError *_Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL *_Nullable imageURL) {
                            [self setForDataForRow:@"dnaImage"
                                          andValue:image];
                            [self updateFormRow:[self.form formRowWithTag:@"dnaImage"]];
                        }];
                    }
                }];
            }
        }

        [self.tableView reloadData];

        NSLog(@"subSubKindID %@ \n self.serverCardClass.subSubKindID %ld ", subSubKindID, self.serverCardClass.subSubKindID);
    }
}

- (void)setParentArray_SubKindID:(NSInteger)subKindID
{
    
    self.CardsdataSource = AppData.UserCardsDocs;


    NSArray<CardModel *> *temCards = [ self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.SubKind == %ld", subKindID]];


    NSPredicate *sPredicate =
        [NSPredicate predicateWithFormat:@"SELF.Sexual == 2"];
    self.mothersCardsArray = [temCards filteredArrayUsingPredicate:sPredicate];
    sPredicate =
        [NSPredicate predicateWithFormat:@"SELF.Sexual == 1"];
    self.fathersCardsArray = [temCards filteredArrayUsingPredicate:sPredicate];

    //self.FathersArraylast = [NSMutableArray<XLFormOptionsObject *> new];
    //self.MothersArraylast = [NSMutableArray<XLFormOptionsObject *> new];
   
    
    if (self.mothersCardsArray.count == 0) {
        self.MotherRow.noValueDisplayText = kLang(@"MotherRowCount");
    }
    else
    {
        self.MotherRow.noValueDisplayText = kLang(@"selectMother");
        self.MotherRow.selectorOptions = self.mothersCardsArray;
        self.MotherRow.selectedKind = self.selectedSubKindModel.ID;
    }

    if (self.fathersCardsArray.count == 0) {
        self.FatherRow.noValueDisplayText = kLang(@"FatherRowCount");

    }
    else
    {
        self.FatherRow.noValueDisplayText = kLang(@"selectFather");
        self.FatherRow.selectorOptions = self.fathersCardsArray;
        self.FatherRow.selectedKind = self.selectedSubKindModel.ID;
        
    }

    [self updateFormRow:self.MotherRow];
    [self updateFormRow:self.FatherRow];
    self.FatherRow.disabled = self.fathersCardsArray.count == 0 ? @(YES): @(NO);
    [self updateFormRow:self.FatherRow];

    self.MotherRow.disabled = self.mothersCardsArray.count == 0 ? @(YES): @(NO);
    [self updateFormRow:self.MotherRow];
}

- (void)setForDataForRow:(NSString *)Tag andValue:(id)value {
    XLFormRowDescriptor *row =   [self.form formRowWithTag:Tag];
    row.value = value;
}

- (void)initializeForm {
    NSString *RingID = [NSString stringWithFormat:@"%@", kLang(@"RingID")];
    NSString *SubKind = [NSString stringWithFormat:@"%@", kLang(@"SubKind")];
    NSString *attribute = [NSString stringWithFormat:@"%@", kLang(@"attribute")];
    NSString *colorTXT = [NSString stringWithFormat:@"%@", kLang(@"Color")];
    NSString *ClassificationLoaded = [NSString stringWithFormat:@"%@", kLang(@"ClassificationLoaded")];
    NSString *AdDesc = [NSString stringWithFormat:@"%@", kLang(@"cardDesc")];
    NSString *Dna = [NSString stringWithFormat:@"%@", kLang(@"AddDnaScan")];
    NSString *attributeNote = [NSString stringWithFormat:@"%@", kLang(@"attributeNote")];

    NSString *RingIDPlace = [NSString stringWithFormat:@"%@", kLang(@"RingIDPlace")];

    SubKindPlace = [NSString stringWithFormat:@"%@", kLang(@"SubKindPlace")];
    subSubKindPlace = [NSString stringWithFormat:@"%@", kLang(@"SubKindPlace")];
    ClassificationPlace = [NSString stringWithFormat:@"%@", kLang(@"ClassificationPlace")];
    NSString *attributePlace = [NSString stringWithFormat:@"%@", kLang(@"attributePlace")];
    NSString *colorTXTPlace = [NSString stringWithFormat:@"%@", kLang(@"colorTXTPlace")];
    NSString *BirthDatePlace = [NSString stringWithFormat:@"%@", kLang(@"BirthDatePlace")];
    NSString *fatherRingIDPlace = [NSString stringWithFormat:@"%@", kLang(@"fatherRingIDPlace")];
    NSString *motherRingIDPlace = [NSString stringWithFormat:@"%@", kLang(@"motherRingIDPlace")];
    NSString *SexualPlace = [NSString stringWithFormat:@"%@", kLang(@"SexualPlace")];
    NSString *AdDescPlace = [NSString stringWithFormat:@"%@", kLang(@"AdDescPlace")];
    NSString *attributeNotePlace = [NSString stringWithFormat:@"%@", kLang(@"attributeNotePlace")];


    self.prefs = [NSUserDefaults standardUserDefaults];
    userID = UserManager.sharedManager.currentUser.ID;

    self.CardsdataSource = AppData.UserCardsDocs;
    NSPredicate *sPredicate =
        [NSPredicate predicateWithFormat:@"SELF.Sexual == 2"];


  //  self.mothersCardsArray = [ self.CardsdataSource filteredArrayUsingPredicate:sPredicate];
    sPredicate =
        [NSPredicate predicateWithFormat:@"SELF.Sexual == 1"];
  //  self.fathersCardsArray = [ self.CardsdataSource filteredArrayUsingPredicate:sPredicate];

    initFlag = 1;
    self.SubKindsArrayLocal = [[MKM.MainKindsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", 1]] firstObject].SubKindsArray;
    self.SubKindsArrayList = [self.SubKindsArrayLocal valueForKey:@"SubKindNameAr"];

    
     
      
    self.attributeArrayLocat = [[NSMutableArray alloc] init];
    [self.attributeArrayLocat addObject:kLang(@"blue")];
    [self.attributeArrayLocat addObject:kLang(@"Green")];
    [self.attributeArrayLocat addObject:kLang(@"trkwaz")];
    [self.attributeArrayLocat addObject:kLang(@"other")];

    //NSLog(@"SubKindsArrayLocal %@ SubKindsArrayList %@", self.SubKindsArrayLocal, self.SubKindsArrayList);
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *RingIDRow;

    typeof(self) __weak weakself = self;

    [self setformDataArray:@"no_value" forKey:@"AdDesc"];
    [self setformDataArray:@"no_value" forKey:@"loanForUser"];
    [self setformDataArray:@"no_value" forKey:@"AttributeNote"];


    self.attributeRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"attribute" rowType:XLFormRowDescriptorTypeSelectorPush title:attribute];
     self.attributeRow.selectorOptions = self.attributeArrayLocat;
    self.attributeRow.selectorTitle = attributePlace;
    self.attributeRow.required = NO;
    self.attributeRow.hidden = [NSPredicate predicateWithValue:YES];
    self.attributeRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [weakself removeDataArrayObjects:@[@"AttributeNote"]];
        [weakself.form removeFormRowWithTag:@"AttributeNote"];
        NSLog(@"newValue %@", newValue);
        NSInteger selectedIndex = [weakself.attributeArrayLocat indexOfObject:newValue];
        [weakself setformDataArray:[NSString stringWithFormat:@"%ld", selectedIndex + 1] forKey:@"attribute"];
        //weakself.cardToUpload.attribute = selectedIndex + 1;
        if (selectedIndex == 3) {
            [weakself.form addFormRow:weakself.AttributeNote afterRow:rowDescriptor];
        } else {
            [weakself removeDataArrayObjects:@[@"AttributeNote"]];
            [weakself.form removeFormRowWithTag:@"AttributeNote"];
        }
    };


    // colorTXT
    self.colorTXTRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"colorTXT" rowType:XLFormRowDescriptorTypeText title:colorTXT];
    self.colorTXTRow.hidden = [NSPredicate predicateWithValue:YES];
    [self.colorTXTRow.cellConfigAtConfigure setObject:colorTXTPlace forKey:@"textField.placeholder"];
    self.colorTXTRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [weakself setformDataArray:newValue forKey:@"birdColor"];
        //weakself.cardToUpload.birdColor = newValue;
    };

    self.AttributeNote = [XLFormRowDescriptor formRowDescriptorWithTag:@"AttributeNote" rowType:XLFormRowDescriptorTypeText title:attributeNote  ];
    [self.AttributeNote.cellConfigAtConfigure setObject:attributeNotePlace forKey:@"textField.placeholder"];
    self.AttributeNote.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [weakself setformDataArray:newValue forKey:@"AttributeNote"];
        //weakself.cardToUpload.AttributeNote = newValue;
    };



    // First section
    section = [XLFormSectionDescriptor formSection];
 
      

       /*  if (foundIndex != NSNotFound) {
            //HXPhotoModel *vid = [weakself.mediaOutputArray objectAtIndex:foundIndex];
            // NSLog(@"vid BEFORE ---------->> %@", [vid modelToJSONObject]);

            [GM compressVideoAtURL:[weakself.mediaOutputArray objectAtIndex:foundIndex].videoURL
                        completion:^(NSURL *_Nonnull outputURL, NSError *_Nonnull error) {
                if (error) {
                    //  NSLog(@"Compression Error: %@", error);
                    // Handle the error (e.g., show an alert)
                } else if (outputURL) {
                    //  NSLog(@"Compressed video saved to: %@", outputURL.absoluteString);
                    // Now, 'outputURL' holds the URL for the smaller video.
                    // You can use outputURL to upload or share the video
                    //for example to share it with UIActivityViewController

                    [weakself.mediaOutputArray objectAtIndex:foundIndex].videoURL = outputURL;
                    // NSLog(@"vid AFTER ---------->> %@", [vid modelToJSONObject]);
                } else {
                    // NSLog(@"Something went wrong");
                }
            }];
        } */
           
 
    [self setformDataArray:userID forKey:@"UserID"];
    [self setformDataArray:PPCurrentUser.UserName forKey:@"OwnerName"];

    // RingID
    section = [XLFormSectionDescriptor formSection];
    RingIDRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"RingID" rowType:XLFormRowDescriptorTypeText title:RingID];
    [RingIDRow.cellConfigAtConfigure setObject:RingIDPlace forKey:@"textField.placeholder"];
    RingIDRow.required = YES;
    RingIDRow.height = 44;
    RingIDRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        
        
        [self setformDataArray:newValue forKey:@"RingID"];
        self->alertRingIDText = newValue;
        //weakself.cardToUpload.RingID = newValue;
        NSInteger SubKind = [[weakself getformDataForKey:@"SubKind" withType:0] integerValue];
        NSLog(@"SubKindSubKindSubKindSubKindSubKind --->>> %ld EXIST", SubKind);
    };
    [section addFormRow:RingIDRow];
    __block int isDateSelected = 0;
    //SubKind
    self.SubKindRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"SubKind" rowType:XLFormRowDescriptorTypeSelectorPush title:SubKind];
    self.SubKindRow.required = YES;
 
    self.SubKindRow.selectorOptions = self.SubKindsArrayLocal;
    self.SubKindRow.selectorTitle = SubKindPlace;

    self.SubKindRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *__unused rowDescriptor) {
        
        __strong typeof(weakself) strongSelf = weakself;
        if (!strongSelf) return;
        
        [strongSelf.form removeFormRowWithTag:@"subSubKind"];
        [strongSelf.form removeFormRowWithTag:@"Classification"];
        [strongSelf.form removeFormRowWithTag:@"ClassificationLoaded"];
        //strongSelf.cardToUpload.SubKind = 0;

        strongSelf.selectedItemsArray = [NSMutableArray new];
        strongSelf.selectedItemsLoadedArray = [NSMutableArray new];

        [strongSelf.formDataArray removeObjectForKey:@"attribute"];
        [strongSelf.formDataArray removeObjectForKey:@"AttributeNote"];
        [strongSelf.formDataArray removeObjectForKey:@"selectedItemsArray"];
        [strongSelf.formDataArray removeObjectForKey:@"selectedItemsLoadedArray"];

        [strongSelf.formDataArray removeObjectForKey:@"birdColor"];
        [strongSelf.formDataArray removeObjectForKey:@"attribute"];
        strongSelf.attributeRow.hidden = [NSPredicate predicateWithValue:YES];
        strongSelf.colorTXTRow.hidden = [NSPredicate predicateWithValue:YES];
        [strongSelf.form removeFormRowWithTag:@"AttributeNote"];
        [strongSelf removeDataArrayObjects:@[@"selectedItemsArray", @"ClassificationLoaded", @"subSubKindID", @"attributeRow"]];

        strongSelf.selectedSubKindModel = newValue;
        [strongSelf setParentArray_SubKindID:strongSelf.selectedSubKindModel.ID];
        strongSelf.currentAdultHood = strongSelf.selectedSubKindModel.adultHood;
        NSDate *birtDate = [NSDate date];

        if (isDateSelected == 1) {
            birtDate = [self.form formRowWithTag:@"BirthDate"].value;
        }

        [strongSelf.form formRowWithTag:@"ageRow"].value = [strongSelf ageFromBirthday:birtDate adultHood:strongSelf.currentAdultHood];
        strongSelf.ageRow.title = [NSString stringWithFormat:@"%@ (%ld) %@", kLang(@"AdultHoodCount"), strongSelf.currentAdultHood, kLang(@"month")];
        [[strongSelf.form formRowWithTag:@"ageRow"] editTextValue];
        [strongSelf updateFormRow:[strongSelf.form formRowWithTag:@"ageRow"]];

        [strongSelf setformDataArray:@(strongSelf.selectedSubKindModel.ID) forKey:@"SubKind"];
        self->alertSubKindIDText = strongSelf.selectedSubKindModel.SubKindNameAr;
        //strongSelf.cardToUpload.SubKind = strongSelf.selectedSubKindModel.ID;
        if (strongSelf.selectedSubKindModel.have_subSub == 1 && (strongSelf.selectedSubKindModel.have_items == 1 || strongSelf.selectedSubKindModel.have_items == 0)) {
            // get selectedKindsJason
            strongSelf.subSubKindsArrayLocal = strongSelf.selectedSubKindModel.subSubKindArray;
            strongSelf.subSubKindsArrayList = [Language languageVal] == 0 ? [strongSelf.subSubKindsArrayLocal valueForKey:@"nameEn"] : [strongSelf.subSubKindsArrayLocal valueForKey:@"nameAr"];

            if (strongSelf.selectedSubKindModel.ID == 7) {
                strongSelf.attributeRow.hidden = [NSPredicate predicateWithValue:NO];
                strongSelf.colorTXTRow.hidden = [NSPredicate predicateWithValue:NO];
            } else {
                strongSelf.attributeRow.hidden = [NSPredicate predicateWithValue:YES];
                [strongSelf.form removeFormRowWithTag:@"AttributeNote"];
                strongSelf.colorTXTRow.hidden = [NSPredicate predicateWithValue:YES];
            }

            [strongSelf addsubSubKind:strongSelf.subSubKindsArrayLocal afterRow:rowDescriptor];
        } else if (strongSelf.selectedSubKindModel.have_subSub == 0 &&  strongSelf.selectedSubKindModel.have_items == 1) {
            strongSelf.subSubKindsArrayLocal = strongSelf.selectedSubKindModel.subSubKindArray;
            strongSelf.subKindItemsArrayLocal = [strongSelf.subSubKindsArrayLocal objectAtIndex:0].subKindItemsArray;

            if (strongSelf.subKindItemsArrayLocal.count != 0) {
                strongSelf.LoadedItemsMaleArrayLocal = [strongSelf.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.Male == 'yes'"]].mutableCopy;
                strongSelf.LoadedItemsFemaleArrayLocal = [strongSelf.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.Female == 'yes'"]].mutableCopy;
                [strongSelf addClassificationRow:strongSelf.subKindItemsArrayLocal afterRow:rowDescriptor];
            }
        } else {
            
          
            
            [strongSelf.form removeFormRowWithTag:@"subSubKind"];
            [strongSelf.form removeFormRowWithTag:@"Classification"];

            strongSelf.attributeRow.hidden = [NSPredicate predicateWithValue:YES];
            [strongSelf.form removeFormRowWithTag:@"AttributeNote"];
            strongSelf.colorTXTRow.hidden = [NSPredicate predicateWithValue:YES];

            [strongSelf.form removeFormRowWithTag:@"Classification"];
            strongSelf.selectedItemsArray = [NSMutableArray new];
            strongSelf.selectedItemsLoadedArray = [NSMutableArray new];

            [strongSelf.formDataArray removeObjectForKey:@"birdColor"];
            [strongSelf.formDataArray removeObjectForKey:@"attribute"];

            [strongSelf.formDataArray removeObjectForKey:@"Classification"];
            [strongSelf.formDataArray removeObjectForKey:@"AttributeNote"];
            [strongSelf.formDataArray removeObjectForKey:@"selectedItemsArray"];
            [strongSelf.formDataArray removeObjectForKey:@"selectedItemsLoadedArray"];
            
            [weakself.tableView reloadData];
        }
    };

    [section addFormRow:self.SubKindRow];


    //attribute
    [section addFormRow:self.attributeRow];


    // ADD First Section
    [self.mform addFormSection:section];

    // Second Section
    section = [XLFormSectionDescriptor formSection];
    // colorTXT
    [section addFormRow:self.colorTXTRow];
    XLFormRowDescriptor *row;
    __block int ageRowAdded = 0;
    //BirthDate
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"BirthDate" rowType:XLFormRowDescriptorTypeDate title:BirthDatePlace];
    row.required = YES;
    row.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        
        __strong typeof(weakself) strongSelf = weakself;
        if (!strongSelf) return;
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd/MM/yyyy"];

        [strongSelf.form formRowWithTag:@"ageRow"].value = [self ageFromBirthday:newValue adultHood:strongSelf.currentAdultHood];
        self.ageRow.title = [NSString stringWithFormat:@"%@ (%ld) %@", kLang(@"AdultHoodCount"), strongSelf.currentAdultHood, kLang(@"month")];
        [[strongSelf.form formRowWithTag:@"ageRow"] editTextValue];
        [self updateFormRow:[strongSelf.form formRowWithTag:@"ageRow"]];
        isDateSelected = 1;

        if (ageRowAdded == 0) {
            //self.ageRow.
            [strongSelf.form addFormRow:self.ageRow afterRow:rowDescriptor];
        }
        //strongSelf.cardToUpload.BirthDate = newValue;
        ageRowAdded = 1;
        [self setformDataArray:newValue forKey:@"BirthDate"];
    };
    [section addFormRow:row];


    // Time
    self.ageRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"ageRow" rowType:XLFormRowDescriptorTypeText title:kLang(@"ageBird")];
    [self.ageRow.cellConfigAtConfigure setObject:kLang(@"ageBird")forKey:@"textField.placeholder"];
    self.ageRow.required = YES;
    // [self.ageRow.cellConfigIfDisabled setObject:[GM appPrimaryColor] forKey:@"textLabel.textColor"];

    self.ageRow.height = 46;
    self.ageRow.disabled = @(YES);
    //ageRow.value = @"123";
    self.ageRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
    };

    // Selector Push
    self.FatherRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"FatherRingID" rowType:XLFormRowDescriptorTypeSelectorPush title:fatherRingIDPlace];

     //selectTableViewController

    self.FatherRow.selectorTitle = fatherRingIDPlace;
    self.FatherRow.selectorOptions = self.fathersCardsArray;
    self.FatherRow.disabled = self.fathersCardsArray.count == 0 ? @(YES) : @(NO);
    self.FatherRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        __strong typeof(weakself) strongSelf = weakself;
        if (!strongSelf) return;
        
        CardModel *ca = (CardModel *)newValue;
        [strongSelf setformDataArray:ca.ID forKey:@"FatherRingID"];
    };
    [section addFormRow:self.FatherRow];

    //motherRingID
    self.MotherRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"motherRingID" rowType:XLFormRowDescriptorTypeSelectorPush title:motherRingIDPlace];
    self.MotherRow.selectorTitle = motherRingIDPlace;

    
    self.MotherRow.selectorOptions = self.mothersCardsArray;
    self.MotherRow.disabled = self.mothersCardsArray.count == 0 ? @(YES) : @(NO);
     self.MotherRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        __strong typeof(weakself) strongSelf = weakself;
        if (!strongSelf) return;
        
        CardModel *ca = (CardModel *)newValue;
        [strongSelf setformDataArray:ca.ID forKey:@"MotherRingID"];
    };
    [section addFormRow:self.MotherRow];

    // ADD Seconed Section
    [self.mform addFormSection:section];

    // Third Section
    section = [XLFormSectionDescriptor formSection];

    // Sexual SexualPlace
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"Sexual" rowType:XLFormRowDescriptorTypeSelectorSegmentedControl];

    row.selectorTitle = SexualPlace;
    row.selectorOptions = @[kLang(@"Female")
                            , kLang(@"Male")];
    row.required = YES;
    row.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *__unused rowDescriptor) {
        __strong typeof(weakself) strongSelf = weakself;
        if (!strongSelf) return;
        [weakself.form removeFormRowWithTag:@"ClassificationLoaded"];

        if ([newValue isEqualToString:kLang(@"Male")]) {
            [self setformDataArray:@1 forKey:@"Sexual"];

            if (self.LoadedItemsMaleArrayLocal.count != 0) {
                [strongSelf addClassificationLoaded:ClassificationLoaded options:self.LoadedItemsMaleArrayLocal afterRow:rowDescriptor];
            }
        } else {
            [self setformDataArray:@2 forKey:@"Sexual"];

            if (self.LoadedItemsFemaleArrayLocal.count != 0) {
                [strongSelf addClassificationLoaded:ClassificationLoaded options:self.LoadedItemsFemaleArrayLocal afterRow:rowDescriptor];
            }
        }
    };
    row.height = 80;
    [section addFormRow:row];


    //AdDesc
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"AdDesc" rowType:XLFormRowDescriptorTypeTextView title:AdDesc];
    [row.cellConfigAtConfigure setObject:AdDescPlace forKey:@"textView.placeholder"];
    row.height = 60.f;
    row.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [self setformDataArray:newValue forKey:@"AdDesc"];
    };
    [section addFormRow:row];


    //Dna
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"dnaImage" rowType:XLFormRowDescriptorTypeImage title:Dna];
    row.value = [UIImage imageNamed:@"XLForm.bundle/add_img"];
    row.height = 50;
    row.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        UIImage *dnaImage = [newValue isKindOfClass:UIImage.class] ? [self normalizedDNAImage:newValue] : nil;
        if (!dnaImage) {
            [self removeDataArrayObjects:@[@"DNAImage", @"dnaImageName"]];
            return;
        }
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
        NSString *dnaImageName = [NSString stringWithFormat:@"%@%@%@%@", self->userID, [dateFormatter stringFromDate:[NSDate date]], @"DNA", @".jpeg"];
        rowDescriptor.value = dnaImage;
        [self setformDataArray:dnaImage forKey:@"DNAImage"];
        [self setformDataArray:dnaImageName forKey:@"dnaImageName"];
        [self updateFormRow:rowDescriptor];
    };
    [section addFormRow:row];

    [self.mform addFormSection:section];

    // Section
   
    [XLFormDescriptor formDescriptorWithTitle:kLang(@"addNewCard")];
    
    self.tableView.sectionFooterHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
    
    
    self.form = self.mform;
    
    self.tableView.sectionFooterHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
}

 
 
- (void)saveForm:(id)buttonItem
{
    // return;
    [self saveBarButton];
    return;
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];

    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [self.imageCollection clearAllImages];
    }
}

- (void)closeForm:(UIBarButtonItem *)buttonItem
{
    if (self.isSaving) return;
    [self.view endEditing:YES];
    BOOL shouldPromptDiscard = (self.hasUserModifiedForm || self.didChangeImages) && formFinishupload == 0;
    if (shouldPromptDiscard) {
        [self presentUnsavedChangesPromptFromBarButtonItem:buttonItem];
        return;
    }

    [PPHUD dismiss];
    [self.prefs setInteger:0 forKey:@"FromForm"];
    [self closeSelfController];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
 
    //[self.view bringSubviewToFront:self.tableView];
    
    if (!self.uploadProgressView) {
        GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0,  self.navigationController.navigationBar.hx_maxy , self.view.hx_w, 4)];
        pv.progressTintColor = [[GM appPrimaryColor]colorWithAlphaComponent:0.1];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        pv.backgroundColor = UIColor.whiteColor;
        [self.view addSubview:pv];
        self.uploadProgressView = pv;
    }
    [self.view bringSubviewToFront:self.uploadProgressView];
    
    self.tableView.frame = CGRectMake(0,  0, self.view.hx_w, self.view.hx_h);
}

- (void)rowCustomization:(XLFormRowDescriptor *)row
{
   [row.cellConfig setObject:[UIFont systemFontOfSize:14] forKey:@"textLabel.font"];
   [row.cellConfig setObject:[UIFont systemFontOfSize:14] forKey:@"textField.font"];

}

- (void)setformDataArray:(id)obj forKey:(NSString *)key {
    if (key.length == 0) return;

    if (!self.formDataArray) {
        self.formDataArray = [NSMutableDictionary new];
    }

    if (!obj || obj == [NSNull null]) {
        [self.formDataArray removeObjectForKey:key];
        return;
    }

    if ([obj isKindOfClass:NSString.class]) {
        NSString *value = (NSString *)obj;
        if ([self isNoValueString:value]) {
            [self.formDataArray removeObjectForKey:key];
            return;
        }
    }

    id oldValue = [self.formDataArray objectForKey:key];
    if (!self.isHydratingFormData && ![oldValue isEqual:obj]) {
        self.hasUserModifiedForm = YES;
    }

    [self.formDataArray setObject:obj forKey:key];
}

- (void)removeDataArrayObjects:(NSArray *)objArray {
    for (NSString *key in objArray) {
        if (!self.isHydratingFormData && [self.formDataArray objectForKey:key] != nil) {
            self.hasUserModifiedForm = YES;
        }
        [self.formDataArray removeObjectForKey:key];
    }
}

- (NSString *)differentParentsValidationMessage
{
    return Language.isRTL
    ? @"يجب اختيار اب وام مختلفين."
    : @"Father and mother must be different birds.";
}

- (NSString *)selfParentValidationMessageForRole:(NSString *)role
{
    if (Language.isRTL) {
        if ([role isEqualToString:@"father"]) {
            return @"لا يمكن للطير ان يكون ابا لنفسه.";
        }
        return @"لا يمكن للطير ان يكون اما لنفسه.";
    }

    if ([role isEqualToString:@"father"]) {
        return @"A bird cannot be its own father.";
    }
    return @"A bird cannot be its own mother.";
}

- (BOOL)validateBeforeUpload
{
    NSString *ring = [self trimmedStringOrNil:[self getformDataForKey:@"RingID" withType:1]];
    if ([self isNoValueString:ring]) {
        [PPAlertHelper showWarningIn:self title:kLang(@"warningTitle") subtitle:kLang(@"RingIDPlace")];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:[self.form formRowWithTag:@"RingID"]]];
        [self animateCell:cell];
        return NO;
    }
    [self setformDataArray:ring forKey:@"RingID"];
    [self setForDataForRow:@"RingID" andValue:ring];

    XLFormRowDescriptor *birthDateRow = [self.form formRowWithTag:@"BirthDate"];
    id storedBirthDate = [self getformDataForKey:@"BirthDate" withType:1];
    NSDate *birthDate = [birthDateRow.value isKindOfClass:NSDate.class]
    ? birthDateRow.value
    : ([storedBirthDate isKindOfClass:NSDate.class] ? storedBirthDate : nil);
    if ([birthDate isKindOfClass:NSDate.class] && [birthDate timeIntervalSinceNow] > 0) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"warningTitle")
                            subtitle:kLang(@"BirthDatePlace")];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:birthDateRow]];
        [self animateCell:cell];
        return NO;
    }

    NSString *fatherID = [self getformDataForKey:@"FatherRingID" withType:1];
    NSString *motherID = [self getformDataForKey:@"MotherRingID" withType:1];

    if (![self isNoValueString:fatherID] &&
        ![self isNoValueString:motherID] &&
        [fatherID isEqualToString:motherID]) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"warningTitle")
                            subtitle:[self differentParentsValidationMessage]];
        UITableViewCell *fatherCell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:[self.form formRowWithTag:@"FatherRingID"]]];
        UITableViewCell *motherCell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:[self.form formRowWithTag:@"motherRingID"]]];
        [self animateCell:fatherCell];
        [self animateCell:motherCell];
        return NO;
    }

    if ([self isEditingFlow] && self.serverCardClass.ID.length) {
        if (![self isNoValueString:fatherID] && [fatherID isEqualToString:self.serverCardClass.ID]) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            [PPAlertHelper showWarningIn:self
                                   title:kLang(@"warningTitle")
                                subtitle:[self selfParentValidationMessageForRole:@"father"]];
            return NO;
        }
        if (![self isNoValueString:motherID] && [motherID isEqualToString:self.serverCardClass.ID]) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            [PPAlertHelper showWarningIn:self
                                   title:kLang(@"warningTitle")
                                subtitle:[self selfParentValidationMessageForRole:@"mother"]];
            return NO;
        }
    }

    return YES;
}

- (void)saveBarButton
{
    if (self.isSaving) return;

    NSArray *array = [self formValidationErrors];
    if (array.count == 0) {
        [[[self.form formRowWithTag:@"ActionButton"] cellForFormController:self] highlightBK];
    } else {
        NSIndexPath *firstInvalidIndexPath = nil;

        for (id obj in array) {
            XLFormValidationStatus *validationStatus = [[obj userInfo] objectForKey:XLValidationStatusErrorKey];
            if (!validationStatus.rowDescriptor) {
                continue;
            }

            NSIndexPath *indexPath = [self.form indexPathOfFormRow:validationStatus.rowDescriptor];
            if (indexPath) {
                firstInvalidIndexPath = indexPath;
                break;
            }
        }

        if (firstInvalidIndexPath) {
            [self.tableView scrollToRowAtIndexPath:firstInvalidIndexPath
                                  atScrollPosition:UITableViewScrollPositionMiddle
                                          animated:YES];
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            for (id obj in array) {
                XLFormValidationStatus *validationStatus = [[obj userInfo] objectForKey:XLValidationStatusErrorKey];
                if (!validationStatus.rowDescriptor) {
                    continue;
                }

                NSIndexPath *indexPath = [self.form indexPathOfFormRow:validationStatus.rowDescriptor];
                if (!indexPath) {
                    continue;
                }

                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                if (!cell) {
                    [self.tableView layoutIfNeeded];
                    cell = [self.tableView cellForRowAtIndexPath:indexPath];
                }
                [self animateCell:cell];
            }
        });
    }

    if (array.count == 0) {
        if (![self validateBeforeUpload]) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            return;
        }
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
        self.isSaving = YES;
        [self sendForDataToServer];
    } else {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
    }
}


#pragma mark - Helper

- (void)animateCell:(UITableViewCell *)cell
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values =  @[ @0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    [cell.layer addAnimation:animation forKey:@"shake"];
    
    [PPHUD dismiss];
}

- (void)addClassificationRow:(NSArray<subKindItemsModel *> *)options afterRow:(XLFormRowDescriptor *)formRow
{
    //OPTIONS subKindItemsArrayList
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:@"Classification" rowType:XLFormRowDescriptorTypeMultipleSelector title:ClassificationPlace];

    row.selectorTitle = ClassificationPlace;
    row.selectorOptions = options;
    row.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        self.selectedItemsArray = [[NSMutableArray alloc] init];

        NSLog(@"newValue CLASS %@", newValue);

        // GET ITEMS IDS
        for (subKindItemsModel *subItemModel in newValue) {
            //NSLog(@"subKindItemsArrayLocal %@",[[self.subKindItemsArrayLocal filteredArrayUsingPredicate:sPredicate] firstObject].ID);
            // ADD ITEM ID TO SELCTED ARRAY
            if (![self.selectedItemsArray containsObject:@(subItemModel.ID)]) {
                [self.selectedItemsArray addObject:@(subItemModel.ID)];
            }
        }

        NSString *Classification = [self.selectedItemsArray componentsJoinedByString:@","];
        [self setformDataArray:Classification forKey:@"Classification"];
        [self setformDataArray:self.selectedItemsArray forKey:@"selectedItemsArray"];

        NSLog(@"Classification ----------------->> %@", Classification);
    };
    [self.form addFormRow:row afterRow:formRow];
    
    [self.tableView reloadData];
}

- (void)addClassificationLoaded:(NSString *)title options:(NSArray<subKindItemsModel *> *)options afterRow:(XLFormRowDescriptor *)formRow
{
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:@"ClassificationLoaded" rowType:XLFormRowDescriptorTypeMultipleSelector title:title];

    row.selectorOptions = options;
    row.selectorTitle = ClassificationPlace;
    row.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        self.selectedItemsLoadedArray = [[NSMutableArray alloc] init];

        // GET ITEMS IDS
        for (subKindItemsModel *subKindItemModel in newValue) {
            // ADD ITEM ID TO SELCTED ARRAY
            if (![self.selectedItemsLoadedArray containsObject:@(subKindItemModel.ID)]) {
                [self.selectedItemsLoadedArray addObject:@(subKindItemModel.ID)];
            }
        }

        NSString *ClassificationLoaded = [self.selectedItemsLoadedArray componentsJoinedByString:@","];
        [self setformDataArray:ClassificationLoaded forKey:@"ClassificationLoaded"];
        [self setformDataArray:self.selectedItemsLoadedArray forKey:@"selectedItemsLoadedArray"];
    };
    [self.form addFormRow:row afterRow:formRow];
}

- (void)addsubSubKind:(NSArray<subSubKindModel *> *)options afterRow:(XLFormRowDescriptor *)formRow
{
    typeof(self) __weak weakself = self;
    XLFormRowDescriptor *subSubKindRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"subSubKind" rowType:XLFormRowDescriptorTypeSelectorPush title:kLang(@"subSubKind")];

     subSubKindRow.selectorOptions = options;
    subSubKindRow.selectorTitle = kLang(@"subSubKindPlaceholder");
    subSubKindRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *__unused rowDescriptor) {
        self.selectedItemsArray = [[NSMutableArray alloc] init];
        [weakself.form removeFormRowWithTag:@"Classification"];
        [weakself.form removeFormRowWithTag:@"ClassificationLoaded"];

        [self removeDataArrayObjects:@[@"selectedItemsArray", @"ClassificationLoaded"]];

        subSubKindModel *selectedsubSubKindModel = newValue;
        [self setformDataArray:@(selectedsubSubKindModel.ID) forKey:@"subSubKindID"];

        self.subKindItemsArrayLocal =  selectedsubSubKindModel.subKindItemsArray;

        if (self.subKindItemsArrayLocal.count != 0) {
            self.LoadedItemsMaleArrayLocal = [self.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.Male == 'yes'"]].mutableCopy;
            self.LoadedItemsFemaleArrayLocal = [self.subKindItemsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.Female == 'yes'"]].mutableCopy;
            [self addClassificationRow:self.subKindItemsArrayLocal afterRow:self.attributeRow];
        }
    };
    [self.form addFormRow:subSubKindRow afterRow:formRow];
    [self.tableView reloadData];
}

- (UIStoryboard *)storyboardForRow:(XLFormRowDescriptor *)formRow
{
    return [UIStoryboard storyboardWithName:@"Main" bundle:nil];
}

- (void)changeColor {
 
     self.navigationController.navigationBar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner ;
 
    UIBarButtonItem *closebutton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"arrow.right" : @"arrow.left"] style:UIBarButtonItemStylePlain target:self action:@selector(closeForm:)];
    self.navigationItem.leftBarButtonItem = closebutton;

    [self.BKbutton setTitle:kLang(@"save")  forState:UIControlStateNormal];
    [self.BKbutton setTitleColor:GM.appPrimaryColor forState:UIControlStateNormal];
    [self.BKbutton setCircleColor:GM.appPrimaryColor];
    [self.BKbutton.titleLabel setFont:[GM boldFontWithSize:16]];
    [self.BKbutton setOriginalTitle:kLang(@"save")];
    [self.BKbutton addTarget:self action:@selector(saveForm:) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *savebutton = [[UIBarButtonItem alloc] initWithTitle:kLang(@"save") style:UIBarButtonItemStylePlain target:self action:@selector(saveForm:)];
    savebutton = [[UIBarButtonItem alloc] initWithCustomView:self.BKbutton];
    self.navigationItem.rightBarButtonItem = savebutton;

}

- (void)closeBTN:(id)sender {
    [self closeForm:nil];
}

- (id)getformDataForKey:(NSString *)key withType:(int)type {
    id value = [self.formDataArray objectForKey:key];
    if (value && value != [NSNull null]) {
        return value;
    } else {
        return type == 0 ? 0 : [NSString stringWithFormat:@"no_value"];
    }
}

- (BOOL)RingIDExist
{
    NSString *UserID = [self getformDataForKey:@"UserID" withType:1];
    NSInteger SubKind = [[self getformDataForKey:@"SubKind" withType:0] integerValue];
    NSString *RingID = [self trimmedStringOrNil:[self getformDataForKey:@"RingID" withType:1]];
    if (RingID.length == 0) return NO;

    //NSString *CardID = [NSString stringWithFormat:@"%ld%ld%@",UserID,SubKind,RingID];

    for (CardModel *card in AppData.UserCardsDocs) {
        if ([card.UserID isEqualToString:UserID] &&
            card.SubKind == SubKind &&
            [card.RingID caseInsensitiveCompare:RingID] == NSOrderedSame &&
            !([self isEditingFlow] && [card.ID isEqualToString:self.serverCardClass.ID])) {
            NSString *subKindTitle = alertSubKindIDText ?: @"";
            NSString *ringTitle = alertRingIDText ?: RingID;
            _alertWarningDataTitle = [NSString stringWithFormat:@"%@ (%@) %@ (%@)", kLang(@"youHaveBird"), subKindTitle, kLang(@"withRingId"), ringTitle];
            _alertWarningDataSubTitle = [NSString stringWithFormat:@"%@", kLang(@"YouWannaDeleteIT")];
            return TRUE;
        }
    }

    //NSString *SubKind =  [[self.SubKindsArrayLocal filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.serverCardClass.SubKind]] firstObject].SubKindNameAr;
    return FALSE;
}

- (BOOL)PhotoAdded
{
    NSArray<UIImage *> *images = [self.imageCollection allImages];
    return images.count > 0;
}

- (void)setAlertLoaded
{
    _uploadProgressV = [[UIActivityIndicatorView alloc]
                        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    [_uploadProgressV setColor:[GM appPrimaryColor]];
    _uploadProgressV.center = CGPointMake(self.view.bounds.size.width / 2,
                                          self.view.bounds.size.height / 2);
    [self.view addSubview:_uploadProgressV];
}

- (void)sendForDataToServer {
    [self.view endEditing:YES];

    BOOL isEditing = [self isEditingFlow];
    CardModel *editingCard = self.serverCardClass;

    NSString *RingID = [self trimmedStringOrNil:[self getformDataForKey:@"RingID" withType:1]];
    if (!RingID.length && isEditing) {
        RingID = [self trimmedStringOrNil:editingCard.RingID];
    }
    if (!RingID.length) {
        [self restoreFormAfterUploadAttempt];
        return;
    }

    NSInteger SubKind = [[self getformDataForKey:@"SubKind" withType:0] integerValue];
    if (SubKind <= 0 && isEditing) SubKind = editingCard.SubKind;

    NSInteger subSubKindID = [[self getformDataForKey:@"subSubKindID" withType:0] integerValue];
    if (subSubKindID <= 0 && isEditing) subSubKindID = editingCard.subSubKindID;

    NSString *attribute = [NSString stringWithFormat:@"%@", [self getformDataForKey:@"attribute" withType:1]];
    if ([self isNoValueString:attribute] && isEditing) {
        attribute = [NSString stringWithFormat:@"%ld", (long)editingCard.attribute];
    }
    if ([self isNoValueString:attribute]) attribute = @"0";

    NSString *birdColor = [self getformDataForKey:@"birdColor" withType:1];
    if ([self isNoValueString:birdColor] && isEditing) birdColor = editingCard.birdColor;
    if ([self isNoValueString:birdColor]) birdColor = no_value;

    id birthDateObj = [self getformDataForKey:@"BirthDate" withType:1];
    NSDate *BirthDate = [birthDateObj isKindOfClass:NSDate.class] ? birthDateObj : nil;
    if (!BirthDate && isEditing) BirthDate = editingCard.BirthDate;
    if (!BirthDate) BirthDate = [NSDate date];

    NSString *FatherRingID = [self getformDataForKey:@"FatherRingID" withType:1];
    if ([self isNoValueString:FatherRingID] && isEditing) FatherRingID = editingCard.FatherRingID;
    if ([self isNoValueString:FatherRingID]) FatherRingID = no_value;

    NSString *MotherRingID = [self getformDataForKey:@"MotherRingID" withType:1];
    if ([self isNoValueString:MotherRingID] && isEditing) MotherRingID = editingCard.MotherRingID;
    if ([self isNoValueString:MotherRingID]) MotherRingID = no_value;

    NSInteger Sexual = [[self getformDataForKey:@"Sexual" withType:0] integerValue];
    if ((Sexual != 1 && Sexual != 2) && isEditing && (editingCard.Sexual == 1 || editingCard.Sexual == 2)) {
        Sexual = editingCard.Sexual;
    }

    NSString *Dna = [self getformDataForKey:@"dnaImageName" withType:1];
    if ([self isNoValueString:Dna] && isEditing) Dna = editingCard.Dna;
    if ([self isNoValueString:Dna]) Dna = no_value;

    NSString *AdDesc = [self getformDataForKey:@"AdDesc" withType:1];
    if ([self isNoValueString:AdDesc] && isEditing) AdDesc = editingCard.AdDesc;
    if ([self isNoValueString:AdDesc]) AdDesc = no_value;

    NSString *AttributeNote = [self getformDataForKey:@"AttributeNote" withType:1];
    if ([self isNoValueString:AttributeNote] && isEditing) AttributeNote = editingCard.AttributeNote;
    if ([self isNoValueString:AttributeNote]) AttributeNote = no_value;

    NSString *userID = [self getformDataForKey:@"UserID" withType:1];
    if ([self isNoValueString:userID] && isEditing) userID = editingCard.UserID;
    if ([self isNoValueString:userID]) userID = UserManager.sharedManager.currentUser.ID ?: no_value;

    id subKindItemsObj = [self getformDataForKey:@"selectedItemsArray" withType:1];
    NSString *subKindItemsID = [subKindItemsObj isKindOfClass:NSArray.class]
    ? [subKindItemsObj componentsJoinedByString:@","]
    : no_value;
    if ([self isNoValueString:subKindItemsID] && isEditing) subKindItemsID = editingCard.subKindItemsID;
    if ([self isNoValueString:subKindItemsID]) subKindItemsID = no_value;

    id subKindItemsLoadedObj = [self getformDataForKey:@"selectedItemsLoadedArray" withType:1];
    NSString *splitID = [subKindItemsLoadedObj isKindOfClass:NSArray.class]
    ? [subKindItemsLoadedObj componentsJoinedByString:@","]
    : no_value;
    if ([self isNoValueString:splitID] && isEditing) splitID = editingCard.splitID;
    if ([self isNoValueString:splitID]) splitID = no_value;

    NSLog(@"serverData       :  RingID %@", RingID);
    NSLog(@"serverData       :  SubKind %ld", (long)SubKind);
    NSLog(@"serverData       :  attribute %@", attribute);
    NSLog(@"serverData       :  birdColor %@", birdColor);
    NSLog(@"serverData       :  BirthDate %@", BirthDate);
    NSLog(@"serverData       :  FatherRingID %@", FatherRingID);
    NSLog(@"serverData       :  Sexual %ld", (long)Sexual);
    NSLog(@"serverData       :  dnaImageName %@", Dna);
    NSLog(@"serverData       :  AdDesc %@", AdDesc);
    NSLog(@"serverData       :  AttributeNote %@", AttributeNote);
    NSLog(@"serverData       :  subKindItemsID %@", subKindItemsID);
    NSLog(@"serverData       :  userID %@", userID);
    NSLog(@"serverData       :  splitID %@", splitID);
    NSLog(@"serverData       :  subSubKindID %ld", (long)subSubKindID);

    NSArray<UIImage *> *images = [self.imageCollection allImages];
    NSLog(@"mediaOutputArray %@", [images modelToJSONObject]);

    NSDate *AddedDate = [NSDate date];
    NSDateFormatter *CardFormatter = [[NSDateFormatter alloc] init];
    [CardFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en"]];
    [CardFormatter setDateFormat:@"ddMMHHmmssSSS"];
    NSString *CardIDDate = [CardFormatter stringFromDate:[NSDate date]];
    NSString *CardID = [NSString stringWithFormat:@"%@_%@", RingID, CardIDDate];

    NSMutableDictionary *Dic = [NSMutableDictionary new];
    [Dic setValue:CardID forKey:@"ID"];
    [Dic setValue:RingID forKey:@"RingID"];
    [Dic setValue:@(SubKind) forKey:@"SubKind"];
    [Dic setValue:@(subSubKindID) forKey:@"subSubKindID"];
    [Dic setValue:subKindItemsID forKey:@"subKindItemsID"];
    [Dic setValue:splitID forKey:@"splitID"];
    [Dic setValue:@([attribute integerValue]) forKey:@"attribute"];
    [Dic setValue:AttributeNote forKey:@"AttributeNote"];
    [Dic setValue:@(Sexual) forKey:@"Sexual"];
    [Dic setValue:birdColor forKey:@"birdColor"];
    [Dic setValue:BirthDate forKey:@"BirthDate"];
    [Dic setValue:FatherRingID forKey:@"FatherRingID"];
    [Dic setValue:MotherRingID forKey:@"MotherRingID"];
    [Dic setValue:Dna forKey:@"Dna"];
    [Dic setValue:AdDesc forKey:@"AdDesc"];
    [Dic setValue:AddedDate forKey:@"AddedDate"];
    [Dic setValue:userID forKey:@"UserID"];
    [Dic setValue:@"not_set" forKey:@"CardLocation"];
    [Dic setValue:@(1) forKey:@"cardInfo"];
    [Dic setValue:@"no_value" forKey:@"loanForUser"];
    [Dic setValue:@(0) forKey:@"isSold"];
    [Dic setValue:@"" forKey:@"soldPrice"];
    [Dic setValue:[FIRFieldValue fieldValueForServerTimestamp] forKey:@"lastUpdated"];
    [Dic setValue:@(CardSectionCards) forKey:@"cardSection"];

    if ([_FromVC isEqual:@"childs"]) {
        [Dic setValue:@(2) forKey:@"cardInfo"];
        [Dic setValue:@"new_child" forKey:@"CardLocation"];
        [Dic setValue:@(CardSectionNewChild) forKey:@"cardSection"];
    }

    typeof(self) __weak weakself = self;

    if (isEditing) {
        CardID = self.serverCardClass.ID;
        [Dic setValue:self.serverCardClass.ID forKey:@"ID"];
        [Dic setValue:self.serverCardClass.CardLocation forKey:@"CardLocation"];
        [Dic setValue:self.serverCardClass.CageID forKey:@"CageID"];
        [Dic setValue:@(self.serverCardClass.cardInfo) forKey:@"cardInfo"];
        [Dic setValue:self.serverCardClass.archiveID forKey:@"archiveID"];
        [Dic setValue:self.serverCardClass.masterArchiveID forKey:@"masterArchiveID"];
        [Dic setValue:@(self.serverCardClass.isSold) forKey:@"isSold"];
        [Dic setValue:PPSafeString(self.serverCardClass.soldPrice) forKey:@"soldPrice"];
        [Dic setValue:@(self.serverCardClass.cardSection) forKey:@"cardSection"];

        if ([_FromVC isEqual:@"ViewData"] || [_FromVC isEqual:@"main"]) {
            [Dic removeObjectForKey:@"AddedDate"];
        }

        self.currentIndex = 0;
        [self startUploadFiles];
        [self uploadFiles:Dic CardID:CardID];
        return;
    }

    if ([self RingIDExist]) {
        [PPAlertHelper showConfirmationIn:self
                                    title:_alertWarningDataTitle
                                 subtitle:_alertWarningDataSubTitle
                            confirmButton:kLang(@"yes")
                             cancelButton:kLang(@"cancel")
                                     icon:nil
                              confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if (!didConfirm) {
                [weakself restoreFormAfterUploadAttempt];
                return;
            }
            weakself.currentIndex = 0;
            [weakself startUploadFiles];
            [weakself uploadFiles:Dic CardID:CardID];
        }
                               cancelBlock:^{
            [self restoreFormAfterUploadAttempt];
        }];
    } else {
        NSLog(@"self.mediaOutputArray.count %ld", (long)images.count);
        self.currentIndex = 0;
        [self startUploadFiles];
        [self uploadFiles:Dic CardID:CardID];
    }

    NSLog(@"serverData    : CardID %@", CardID);
}

- (void)uploadData:(NSMutableDictionary *)Dic CardID:(NSString *)CardID {
    __weak typeof(self) weakSelf = self;
    [self uploadDNAImageIfNeededWithCompletion:^(NSError * _Nullable dnaError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { NSLog(@"❌ NewCardForm: self deallocated during DNA upload"); return; }
        if (dnaError) {
            NSLog(@"FireDB ---->>> DNA upload failed before save: %@", dnaError);
            [strongSelf processUploadCompleteWithError:YES
                                          CardID:CardID];
            return;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            FIRFirestore *db = [FIRFirestore firestore];
            FIRDocumentReference *docRef = [[db collectionWithPath:@"CardsCol"] documentWithPath:CardID];

            [docRef setData:Dic merge:YES
                 completion:^(NSError *_Nullable error) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) { NSLog(@"❌ NewCardForm: self deallocated during Firestore write"); return; }
                if (error != nil) {
                    NSLog(@"FireDB ---->>> Error Creating Document: %@", error);
                    [strongSelf processUploadCompleteWithError:YES
                                                  CardID:CardID];
                    return;
                }

                NSLog(@"FireDB ---->>> Document Created Successfully ID: %@", CardID);
                [strongSelf processUploadCompleteWithError:NO
                                              CardID:CardID];
            }];
        });
    }];
      
}

- (void)processUploadCompleteWithError:(BOOL)error CardID:(NSString *)CardID {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { NSLog(@"❌ NewCardForm: self deallocated before upload completion UI"); return; }
        [PPHUD dismiss];
        [strongSelf restoreFormAfterUploadAttempt];
        strongSelf->formFinishupload = error ? 0 : 1;

        if (error) {
            // error happened
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            [PPAlertHelper showWarningIn:strongSelf
                                   title:strongSelf->alertTitleError ?: kLang(@"alertTitleError")
                                subtitle:strongSelf->alertSubtitleError ?: kLang(@"alertSubtitleError")
                             completion:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf) [strongSelf closeSelfController];
            }];
  
        } else {
            //everything succeded
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
            [PPAlertHelper showSuccessIn:strongSelf title:strongSelf.alertTitleDone subtitle:strongSelf.alertSubtitleDone confirmAction:^(NSString * _Nullable text, BOOL didConfirm) {
                if(!didConfirm) return;
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf clearSavedDraft];
                [strongSelf.prefs setInteger:1 forKey:@"FromForm"];
                
                
                [strongSelf.delegate refreshView];
                [strongSelf closeSelfController];
            } cancelAction:^{
               
            }];
 
        }
    });
}

- (NSDictionary *)dictionaryFromFilesArray:(NSMutableArray<FileModel *> *)filesArray {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (FileModel *file in filesArray) {
        [dictionary setObject:file forKey:@(file.ID)];
    }

    return [dictionary copy];  // Return an immutable copy for safety
}

- (void)uploadFiles:(NSMutableDictionary *)Dic CardID:(NSString *)CardID
{
    NSArray<UIImage *> *images = [self.imageCollection allImages];

    if ([self isEditingFlow] && !self.didChangeImages) {
        NSArray *existingFiles = [self.serverCardClass.FilesArray modelToJSONObject] ?: @[];
        [Dic setValue:existingFiles forKey:@"FilesArray"];
        [self uploadData:Dic CardID:CardID];
        return;
    }

    if (images.count == 0 && [self isEditingFlow]) {
        [Dic setValue:@[] forKey:@"FilesArray"];
        [self uploadData:Dic CardID:CardID];
        return;
    }

    [self.uploadManager uploadFilesfromArray:images.mutableCopy
                                  completion:^(NSMutableArray<FileModel *> *filesArray, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"Error uploading files: %@", error);
                [self processUploadCompleteWithError:YES CardID:CardID];
                return;
            }

            [Dic setValue:[filesArray modelToJSONObject] forKey:@"FilesArray"];
            [self uploadData:Dic CardID:CardID];
            NSLog(@"Files uploaded successfully for card ID %@", [filesArray modelToJSONObject]);
        });
    }];
}



- (void)startUploadFiles
{
    if (!self.uploadProgressView) {
        GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.hx_maxy, self.view.hx_w, 4)];
        pv.progressTintColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.1];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        pv.backgroundColor = UIColor.whiteColor;
        [self.view addSubview:pv];
        self.uploadProgressView = pv;
    }

    self.navigationItem.leftBarButtonItem.enabled = NO;
    alertTitleLoad = @"الرجاء الانتظار";
    alertSubtitleLoad = @"تتم الان عملية انشاء البطاقة للطير";
    [PPHUD showLoading:alertTitleLoad subtitle:alertSubtitleLoad];
    [self.uploadProgressView startAnimating];
    [self.BKbutton startAnimation];
    [self.BKbutton setEnabled:NO];
    [self.tableView setUserInteractionEnabled:NO];
    self.form.disabled = YES;
    self.mform.disabled = YES;
}

- (NSString *)ageFromBirthday:(NSDate *)birthdate adultHood:(NSInteger)adultHood {
    NSString *monthString = kLang(@"month");
    NSString *yearString = kLang(@"year");
    NSString *redyString = kLang(@"readyToMarrage");
    NSString *ageString = kLang(@"age");
    NSString *stringDate;
    NSDate *today = [NSDate date];
    NSDateComponents *ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitMonth
                                                                     fromDate:birthdate
                                                                       toDate:today
                                                                      options:0];

    if (ageComponents.month < 12) {
        stringDate = [NSString stringWithFormat:@"%@ (%ld) %@ %@", ageString, (long)ageComponents.month, monthString, ageComponents.month >= adultHood ? redyString : @""];
        return stringDate;
    } else if (ageComponents.month == 12) {
        stringDate = [NSString stringWithFormat:@"(1) %@ %@", yearString, redyString];
        return stringDate;
    } else {
        NSInteger aboveMonths = ageComponents.month % 12;
        NSInteger allMonths = ageComponents.month;
        NSLog(@"%ld %ld", (long)adultHood, (long)ageComponents.month);

        if (ageComponents.month % 12 == 0) {
            ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitYear
                                                           fromDate:birthdate
                                                             toDate:today
                                                            options:0];

            stringDate = [NSString stringWithFormat:@"(%ld) %@ %@", (long)ageComponents.year, yearString, allMonths >= adultHood ? redyString : @""];
            return stringDate;
        } else {
            ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitYear
                                                           fromDate:birthdate
                                                             toDate:today
                                                            options:0];

            ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitYear
                                                           fromDate:birthdate
                                                             toDate:today
                                                            options:0];
            stringDate = [NSString stringWithFormat:@"(%ld) %@ (%ld) %@ %@", (long)ageComponents.year, yearString, (long)aboveMonths, monthString, allMonths >= adultHood ? redyString : @""];
            return stringDate;
        }

        return stringDate;
    }
}

- (void)sendDnaImage:(UIImage *)DNAImage ImageName:(NSString *)ImageName
{
    FIRStorageReference *mountainRef = [[GM CardsImagesRefrence] child:ImageName];
    NSData *imageData = UIImageJPEGRepresentation(DNAImage, 0.6);
    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
    metadata.contentType = @"image/jpeg";

    FIRStorageUploadTask *uploadTask = [mountainRef putData:imageData metadata:metadata];

    [uploadTask observeStatus:FIRStorageTaskStatusSuccess
                      handler:^(FIRStorageTaskSnapshot *_Nonnull metadata) {
    }];
}

- (UIImage *)normalizedDNAImage:(UIImage *)image
{
    if (![image isKindOfClass:UIImage.class]) {
        return nil;
    }

    UIImage *resized = [self resizedImage:image withMaxDimension:2000.0];
    return resized ?: image;
}

- (void)uploadDNAImageIfNeededWithCompletion:(void (^)(NSError * _Nullable error))completion
{
    UIImage *dnaImage = [self.formDataArray objectForKey:@"DNAImage"];
    NSString *imageName = [self.formDataArray objectForKey:@"dnaImageName"];

    if (![dnaImage isKindOfClass:UIImage.class] || imageName.length == 0) {
        if (completion) completion(nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            UIImage *normalizedImage = [self normalizedDNAImage:dnaImage];
            NSData *imageData = UIImageJPEGRepresentation(normalizedImage, 0.72);
            if (imageData.length == 0) {
                NSError *error = [NSError errorWithDomain:@"com.purepets.cards"
                                                     code:-1001
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode DNA image."}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(error);
                });
                return;
            }

            FIRStorageReference *mountainRef = [[GM CardsImagesRefrence] child:imageName];
            FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
            metadata.contentType = @"image/jpeg";

            [mountainRef putData:imageData metadata:metadata completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(error);
                });
            }];
        }
    });
}

- (UIImage *)resizedImage:(UIImage *)image withMaxDimension:(CGFloat)maxDimension {
    CGFloat scale = 1.0;

    if (image.size.width > maxDimension || image.size.height > maxDimension) {
        scale = MIN(maxDimension / image.size.width, maxDimension / image.size.height);
    }

    CGSize newSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

// Show No network alert method
- (void)showNoNetworkAlert {
    FCAlertView *alert = [[FCAlertView alloc] init];

    alert.colorScheme = [GM appPrimaryColor];
    alert.tintColor = [GM appPrimaryColor];
    alert.firstButtonTitleColor = GM.appPrimaryColor;
    [alert  showAlertInView:self
                  withTitle:kLang(@"noInternetTitle")
               withSubtitle:kLang(@"noInternetSubTitle")
            withCustomImage:nil
        withDoneButtonTitle:kLang(@"ok")
                 andButtons:nil];
}

 

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self changeColor];
}
// In your XLFormViewController
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    /*
    // 1. Get the row by tag (make sure you set this tag when you created the row)
    XLFormRowDescriptor *row = [self.form formRowWithTag:@"myRowTag"];
    if (!row) { return; }
    
    // 2. Get the actual cell instance for this controller
    XLFormBaseCell *cell = (XLFormBaseCell *)[row cellForFormController:self];
    if (!cell) { return; }
    
    // 3. Create your subview
    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectZero];
    bottomView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomView.backgroundColor = [UIColor systemBlueColor];
    bottomView.layer.cornerRadius = 8.0;
    
    [cell.contentView addSubview:bottomView];
    
    // 4. Add constraints so it sits at the bottom of the cell and resizes with it
    UILayoutGuide *content = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [bottomView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [bottomView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [bottomView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-4.0],
        [bottomView.heightAnchor constraintEqualToConstant:32.0]
    ]];
    
    // If you use automatic dimensions, you may need to reload that row so the layout updates:
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
     */
}

@end
