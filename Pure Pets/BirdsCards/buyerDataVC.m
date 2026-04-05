//
//  ViewController.m
//  projectxlforms
//
//  Created by IQRQA on 12/14/16.
//  Copyright © 2016 IQRQA. All rights reserved.
//

#import "buyerDataVC.h"
#import "AppDelegate.h"
#import "BKCircularLoadingButton.h"
#import "FileUploadManager.h"


#import "selectTableViewController.h"
#import "XLFormCustomCell.h"

@interface MY_Mediabyer : NSObject
@property (nonatomic) FileType fileTypebyer;
@property (nonatomic) NSString *FileNamebyer;
@property (nonatomic) UIImage *imageFilebyer;
@property (nonatomic) NSString *FileUrlbyer;
@end

@implementation MY_Mediabyer

@end

static NSString *const kCustomRowText = @"kCustomText";
static NSString *const kBuyerDraftDefaultsPrefix = @"pp.buyer_form.draft";
static NSString *const kBuyerDraftFormDataKey = @"formData";
static NSString *const kBuyerDraftSelectedCardIDsKey = @"selectedCardIDs";
static NSString *const kBuyerDraftPricesKey = @"pricesByCardID";

@interface buyerDataVC () {
    NSUserDefaults *prefs;
    NSString *userID;
    float topbarHeight;

    long finishFlag;
    int initFlag;
    NSInteger formFinishupload;
    FIRStorage *storage;
    FIRStorageReference *storageRef;
    NSMutableArray *selectedImagesNames;
    
    // add birds to bill variabels
    NSArray<SubKindModel *> *subKinsArr;
    NSMutableArray<SubKindModel *>  *mainArray;
    NSMutableArray<CardModel *> *rightOptions;
    NSMutableArray<XLFormLeftRightSelectorOption *> *selectorOptions;
    NSString *lastSelctedSubKind;
    NSMutableArray<CardModel *> *selectedBirdsCards;
    int selectedSubKindIndex;
    XLFormRowDescriptor *EmptyBirdRow;
    XLFormRowDescriptor *BirdRow;
    XLFormSectionDescriptor *multiSection;
    XLFormRowDescriptor *priceRow;
    int FirstLoad;
}

// Assuming these are already defined, adjust as needed
@property (nonatomic, strong) NSMutableArray<UIImage *> *mediaOutputArray;
@property (nonatomic, strong) NSMutableDictionary *formDataArray;
   @property (nonatomic, strong) UIActivityIndicatorView *uploadProgressV;
@property (nonatomic, strong) NSMutableArray *FilesToUploadDictArray;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) FIRStorageReference *storageRef;
@property (nonatomic, strong) XLFormDescriptor *mform; // Add your mform Property here.
@property (nonatomic, strong) BKCircularLoadingButton *BKbutton; // Add your BKbutton Property here.
@property (nonatomic, strong) NSUserDefaults *prefs;
 

//@property (nonatomic, strong) CardModel *cardToUpload;

 @property (nonatomic, strong) TTGSnackbar *snakBar;

@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;
@property (nonatomic, strong) NSMutableArray *imagesFromStorage;  // To store downloaded UIImage
@property (nonatomic, strong) FileUploadManager *uploadManager;
@property (nonatomic, assign) BOOL hasUserModifiedForm;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, copy, nullable) dispatch_block_t uploadTimeoutBlock;

@end;


#pragma mark - NSValueTransformer
@interface NSArrayValueTrasformerNew : NSValueTransformer @end

@implementation NSArrayValueTrasformerNew


NSString *const buyer_nameValidation = @"buyer_name";
NSString *const buyer_mobileValidation = @"buyer_mobile";
NSString *const sell_dateValidation = @"sell_date";
//NSString *const sell_dateValidation = @"sell_date";
@end
/*
 
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
         return [NSString stringWithFormat:@"%@ - ;) - ransformed", value];
     }

     return nil;
 }

 @end

 */


@implementation buyerDataVC

 @synthesize prefs;
@synthesize storageRef;



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

UIBarButtonItem *addbuttonBuyer;

#pragma mark - Programmatic Header Setup

- (void)setupHeaderViews {
    CGFloat headerHeight = 66.0; // topbarHeight(56) + 10

    _topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), headerHeight)];
    _topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _topView.backgroundColor = [GM appPrimaryColor];
    [self.view addSubview:_topView];

    _topTitle = [[UILabel alloc] init];
    _topTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _topTitle.textAlignment = NSTextAlignmentCenter;
    _topTitle.textColor = [UIColor whiteColor];
    _topTitle.font = [GM MidFontWithSize:17];
    [_topView addSubview:_topTitle];

    _closeBtnIB = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeBtnIB.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeBtnIB setImage:[UIImage systemImageNamed:@"multiply"] forState:UIControlStateNormal];
    [_closeBtnIB setTintColor:[UIColor whiteColor]];
    [_closeBtnIB addTarget:self action:@selector(closeBTN:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeBtnIB];

    [NSLayoutConstraint activateConstraints:@[
        [_topTitle.centerXAnchor constraintEqualToAnchor:_topView.centerXAnchor],
        [_topTitle.bottomAnchor constraintEqualToAnchor:_topView.bottomAnchor constant:-8],
        [_topTitle.leadingAnchor constraintGreaterThanOrEqualToAnchor:_topView.leadingAnchor constant:50],
        [_topTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_topView.trailingAnchor constant:-50],
        [_closeBtnIB.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_closeBtnIB.centerYAnchor constraintEqualToAnchor:_topTitle.centerYAnchor],
        [_closeBtnIB.widthAnchor constraintEqualToConstant:30],
        [_closeBtnIB.heightAnchor constraintEqualToConstant:30],
    ]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupHeaderViews];
    FirstLoad = 0;
    storageRef = [GM CardsImagesRefrence];
    self.uploadManager = [[FileUploadManager alloc] init];
    self.formDataArray = [NSMutableDictionary new];
    self.isHydratingFormData = YES;
    self.hasUserModifiedForm = NO;
    selectedBirdsCards = [NSMutableArray<CardModel *> new];
    self.tableView.backgroundColor = AppClearClr;
    self.view.backgroundColor = PPBackgroundColorForIOS26([AppBackgroundClr colorWithAlphaComponent:0.9]);
    [self setClassTpForm];
    self.mform = [XLFormDescriptor formDescriptorWithTitle:kLang(@"pill")];
  
    [self initializeForm];
    [self.mform setAddAsteriskToRequiredRowsTitle:YES];
    
    self.view.layer.cornerRadius = 35;
    self.view.clipsToBounds = YES;
    //initFlag
    initFlag = 0;
    finishFlag = 0;
    formFinishupload = 0;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    topbarHeight = ([UIApplication sharedApplication].statusBarFrame.size.height +
                    (self.navigationController.navigationBar.frame.size.height ? : 0.0));

    topbarHeight = 56;
    _topView.hx_h = topbarHeight + 10;
    [self changeColor];
    self.modalInPresentation = YES;
    // Do any additional setup after loading the view, typically from a nib.

     _topTitle.text = kLang(@"addNewBill");

    prefs = [NSUserDefaults standardUserDefaults];
    storageRef = [GM CardsImagesRefrence];

    // Initialize UI components
    [self restoreDraftIfNeeded];
    self.isHydratingFormData = NO;
}

- (void)setClassTpForm
{
    if (_serverCardClass.ID.length) {
        priceRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:[NSString stringWithFormat:@"price.%@", _serverCardClass.ID]
                                              rowType:XLFormRowDescriptorTypeDecimal
                                                title:kLang(@"buyer_price")];
    } else {
        priceRow = nil;
    }

    subKinsArr = [MKM getSubKindArray:1] ?: @[];
    mainArray = [NSMutableArray<SubKindModel *> array];
    selectorOptions = [NSMutableArray<XLFormLeftRightSelectorOption *> array];
    selectedSubKindIndex = 0;

    NSMutableArray<CardModel *> *availableCards = [NSMutableArray array];
    for (CardModel *card in AppData.UserCardsDocs) {
        if (!card.ID.length || card.isDeleted == 1 || card.isSold == 1) continue;
        [availableCards addObject:card];
    }

    if (_serverCardClass.ID.length &&
        [availableCards filteredArrayUsingPredicate:
         [NSPredicate predicateWithFormat:@"SELF.ID == %@", _serverCardClass.ID]].count == 0 &&
        _serverCardClass.isDeleted != 1 &&
        _serverCardClass.isSold != 1) {
        [availableCards addObject:_serverCardClass];
    }

    NSMutableOrderedSet<NSNumber *> *uniqueSubKindIDs = [NSMutableOrderedSet orderedSet];
    for (CardModel *card in availableCards) {
        [uniqueSubKindIDs addObject:@(card.SubKind)];
    }

    NSInteger currentIndex = 0;
    for (NSNumber *subKindID in uniqueSubKindIDs) {
        SubKindModel *subKind =
        [subKinsArr filteredArrayUsingPredicate:
         [NSPredicate predicateWithFormat:@"SELF.ID == %ld", subKindID.integerValue]].firstObject;
        if (!subKind) continue;

        if (subKind.ID == _serverCardClass.SubKind) {
            selectedSubKindIndex = currentIndex;
        }

        [mainArray addObject:subKind];
        currentIndex++;
    }

    for (SubKindModel *mainOption in mainArray) {
        NSPredicate *pred =
        [NSPredicate predicateWithFormat:@"SELF.SubKind == %ld", mainOption.ID];

        rightOptions = [[availableCards filteredArrayUsingPredicate:pred] mutableCopy];
        if (!rightOptions) rightOptions = [NSMutableArray array];

        XLFormLeftRightSelectorOption *option =
        [XLFormLeftRightSelectorOption formLeftRightSelectorOptionWithLeftValue:mainOption.SubKindName
                                                                 httpParameterKey:nil
                                                                      rightOptions:rightOptions];
        [selectorOptions addObject:option];
    }

    [selectedBirdsCards removeAllObjects];
    if (_serverCardClass.ID.length &&
        _serverCardClass.isDeleted != 1 &&
        _serverCardClass.isSold != 1) {
        [selectedBirdsCards addObject:_serverCardClass];
        lastSelctedSubKind =
        [SubKindModel getSubKindName:_serverCardClass.SubKind
                   subKindsArrayLocal:subKinsArr];
    } else {
        lastSelctedSubKind = @"";
    }
}

- (NSString *)draftStorageKey
{
    NSString *currentUserID = PPSafeString(UserManager.sharedManager.currentUser.ID);
    if (self.serverCardClass.ID.length) {
        return [NSString stringWithFormat:@"%@.single.%@.%@",
                kBuyerDraftDefaultsPrefix,
                self.serverCardClass.ID,
                currentUserID];
    }

    return [NSString stringWithFormat:@"%@.multi.%@",
            kBuyerDraftDefaultsPrefix,
            currentUserID];
}

- (NSData *)archivedDraftDataForObject:(id)object
{
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
        if (!obj || obj == [NSNull null]) return;

        if ([obj isKindOfClass:NSString.class]) {
            NSString *value =
            [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!value.length ||
                [value.lowercaseString isEqualToString:@"null"] ||
                [value.lowercaseString isEqualToString:@"<null>"] ||
                [value.lowercaseString isEqualToString:@"(null)"] ||
                [value.lowercaseString isEqualToString:@"nil"]) {
                return;
            }
        }

        snapshot[key] = obj;
    }];

    return snapshot.copy;
}

- (NSArray<NSString *> *)selectedCardIDsSnapshot
{
    NSMutableArray<NSString *> *cardIDs = [NSMutableArray array];
    for (CardModel *card in selectedBirdsCards) {
        if (card.ID.length) {
            [cardIDs addObject:card.ID];
        }
    }
    return cardIDs.copy;
}

- (NSDictionary<NSString *, NSString *> *)priceSnapshot
{
    NSMutableDictionary<NSString *, NSString *> *prices = [NSMutableDictionary dictionary];
    for (CardModel *card in selectedBirdsCards) {
        if (!card.ID.length) continue;
        NSString *price = [self normalizedPriceStringFromValue:card.soldPrice];
        if (price.length) {
            prices[card.ID] = price;
        }
    }
    return prices.copy;
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
    [prefs removeObjectForKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)saveDraftForLater
{
    NSData *formData = [self archivedDraftDataForObject:[self draftFormDataSnapshot]];
    if (!formData) return;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[kBuyerDraftFormDataKey] = formData;
    payload[kBuyerDraftSelectedCardIDsKey] = [self selectedCardIDsSnapshot] ?: @[];
    payload[kBuyerDraftPricesKey] = [self priceSnapshot] ?: @{};
    [prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)applyDraftValue:(id)value
               toRowTag:(NSString *)tag
{
    XLFormRowDescriptor *row = [self.form formRowWithTag:tag];
    if (!row || !value || value == [NSNull null]) return;
    row.value = value;
    [self updateFormRow:row];
}

- (CardModel *)draftCardForID:(NSString *)cardID
{
    if (cardID.length == 0) return nil;

    CardModel *card = [self getCardModelByID:cardID fromArray:AppData.UserCardsDocs];
    if (card) return card;

    if ([self.serverCardClass.ID isEqualToString:cardID]) {
        return self.serverCardClass;
    }

    return nil;
}

- (XLFormRowDescriptor *)selectorRowForCard:(CardModel *)card
{
    XLFormRowDescriptor *row =
    [XLFormRowDescriptor formRowDescriptorWithTag:@"partSelector"
                                          rowType:XLFormRowDescriptorTypeSelectorLeftRight
                                            title:kLang(@"TapToSelect")];
    row.selectorOptions = selectorOptions;
    row.height = 46;
    row.value = card;
    return row;
}

- (void)resetDraftSelectionRows
{
    NSArray<XLFormRowDescriptor *> *rowsCopy = [multiSection.formRows copy];
    for (XLFormRowDescriptor *row in rowsCopy) {
        if (row == BirdRow || row == EmptyBirdRow) continue;
        if ([row.tagM hasPrefix:@"price."] || [self isSelectorBirdRow:row]) {
            [multiSection removeFormRow:row];
        }
    }
    BirdRow.value = nil;
    [self updateFormRow:BirdRow];
}

- (void)restoreDraftIfNeeded
{
    NSDictionary *payload = [prefs objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) return;

    NSDictionary *storedValues = [self unarchivedDraftObjectFromData:payload[kBuyerDraftFormDataKey]];
    NSArray<NSString *> *storedCardIDs = payload[kBuyerDraftSelectedCardIDsKey];
    NSDictionary<NSString *, NSString *> *storedPrices = payload[kBuyerDraftPricesKey];

    if (![storedValues isKindOfClass:NSDictionary.class]) {
        [self clearSavedDraft];
        return;
    }

    NSMutableDictionary *merged = [self.formDataArray mutableCopy] ?: [NSMutableDictionary dictionary];
    [merged addEntriesFromDictionary:storedValues];
    self.formDataArray = merged;

    NSString *buyerName = PPSafeString(storedValues[@"buyer_name"]);
    if (buyerName.length) {
        [self applyDraftValue:buyerName toRowTag:@"buyer_name"];
    }

    NSString *buyerMobile = PPSafeString(storedValues[@"buyer_mobile"]);
    if (buyerMobile.length) {
        [self applyDraftValue:buyerMobile toRowTag:@"buyer_mobile"];
    }

    NSDate *sellDate = storedValues[@"sell_date"];
    if ([sellDate isKindOfClass:NSDate.class]) {
        [self applyDraftValue:sellDate toRowTag:@"sell_date"];
    }

    NSString *buyerNote = PPSafeString(storedValues[@"buyer_note"]);
    if (buyerNote.length) {
        [self applyDraftValue:buyerNote toRowTag:@"buyer_note"];
    }

    [self resetDraftSelectionRows];
    [selectedBirdsCards removeAllObjects];

    NSMutableArray<CardModel *> *restoredCards = [NSMutableArray array];
    for (NSString *cardID in storedCardIDs) {
        CardModel *card = [self draftCardForID:cardID];
        if (!card) continue;
        NSString *savedPrice = PPSafeString(storedPrices[card.ID]);
        if (savedPrice.length) {
            card.soldPrice = savedPrice;
        }
        [restoredCards addObject:card];
    }

    if (restoredCards.count > 0) {
        BirdRow.value = restoredCards.firstObject;
        [self updateFormRow:BirdRow];

        for (NSUInteger idx = 1; idx < restoredCards.count; idx++) {
            [multiSection addFormRow:[self selectorRowForCard:restoredCards[idx]]];
        }

        [selectedBirdsCards addObjectsFromArray:restoredCards];
        [self syncSelectedBirdsAndPriceRows];

        [storedPrices enumerateKeysAndObjectsUsingBlock:^(NSString *cardID, NSString *price, BOOL *stop) {
            (void)stop;
            XLFormRowDescriptor *priceRowForCard =
            [self.form formRowWithTag:[NSString stringWithFormat:@"price.%@", cardID]];
            if (priceRowForCard) {
                priceRowForCard.value = price;
                [self updateFormRow:priceRowForCard];
            }
        }];
    }

    self.hasUserModifiedForm = NO;
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
        [strongSelf syncSelectedBirdsAndPriceRows];
        [strongSelf saveDraftForLater];
        [strongSelf->prefs setInteger:0 forKey:@"FromForm"];
        [strongSelf dismissViewControllerAnimated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_discard")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf clearSavedDraft];
        [strongSelf->prefs setInteger:0 forKey:@"FromForm"];
        [strongSelf dismissViewControllerAnimated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_keep_editing")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}


- (void)setForDataForRow:(NSString *)Tag andValue:(id)value {
    XLFormRowDescriptor *row =   [self.form formRowWithTag:Tag];
    row.value = value;
}

- (void)initializeForm {
    

    

    NSString *buyer_name = [NSString stringWithFormat:@"%@", kLang(@"buyer_name")];
    NSString *buyer_mobile = [NSString stringWithFormat:@"%@", kLang(@"buyer_mobile")];
    //NSString *buyer_price = [NSString stringWithFormat:@"%@", kLang(@"buyer_price")];
    NSString *sell_date = [NSString stringWithFormat:@"%@", kLang(@"sell_date")];
    NSString *buyer_note = [NSString stringWithFormat:@"%@", kLang(@"buyer_note")];
    
    prefs = [NSUserDefaults standardUserDefaults];
    userID = UserManager.sharedManager.currentUser.ID;

    XLFormSectionDescriptor *section;
    // First section
    section = [XLFormSectionDescriptor formSection];
    XLFormRowDescriptor *buyer_mobileRow ;
    XLFormRowDescriptor *buyer_nameRow ;
    XLFormRowDescriptor *sell_dateRow ;
    
    // buyer_nameRow
    XLFormRowDescriptor *buyer_noteRow ;
    section = [XLFormSectionDescriptor formSection];
    
    buyer_nameRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"buyer_name" rowType:XLFormRowDescriptorTypeText title:buyer_name];
    [buyer_nameRow.cellConfigAtConfigure setObject:buyer_name forKey:@"textField.placeholder"];
    buyer_nameRow.cellConfigAtConfigure[@"detailTextLabel.textAlignment"] = @(NSTextAlignmentCenter);  // Change to Left, Right, or Center

    buyer_nameRow.required = YES;
    buyer_nameRow.height = 50;
    [self rowCustomization:buyer_nameRow];
    buyer_nameRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [self setformDataArray:newValue forKey:@"buyer_name"];
    }; [section addFormRow:buyer_nameRow];
    
    buyer_mobileRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"buyer_mobile" rowType:XLFormRowDescriptorTypePhone title:buyer_mobile];
    [buyer_mobileRow.cellConfigAtConfigure setObject:buyer_mobile forKey:@"textField.placeholder"];
    buyer_mobileRow.required = YES;
    buyer_mobileRow.height = 50;
    [self rowCustomization:buyer_mobileRow];
    buyer_mobileRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [self setformDataArray:newValue forKey:@"buyer_mobile"];
    }; [section addFormRow:buyer_mobileRow];
    
    
  
    
    NSDate *date = [NSDate date];

    sell_dateRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"sell_date" rowType:XLFormRowDescriptorTypeDate title:sell_date];
    sell_dateRow.required = YES;
    sell_dateRow.height = 50;
    sell_dateRow.value = date;
    [self rowCustomization:sell_dateRow];
    sell_dateRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [self setformDataArray:newValue forKey:@"sell_date"];
    }; [section addFormRow:sell_dateRow];


    buyer_noteRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"buyer_note" rowType:XLFormRowDescriptorTypeTextView title:buyer_note];
    [buyer_noteRow.cellConfigAtConfigure setObject:buyer_note forKey:@"textView.placeholder"];
    buyer_noteRow.height = 100.f;
    [self rowCustomization:buyer_noteRow];
    buyer_noteRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [self setformDataArray:newValue forKey:@"buyer_note"];
    };
    [section addFormRow:buyer_noteRow];
    [self.mform addFormSection:section];
    
    
    ////////// ********************
    ///
    ///
    ///
  
    multiSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"addBird") sectionOptions: XLFormSectionOptionCanInsert | XLFormSectionOptionCanDelete sectionInsertMode:XLFormSectionInsertModeButton];
    
    EmptyBirdRow = [XLFormRowDescriptor formRowDescriptorWithTag:nil rowType:XLFormRowDescriptorTypeSelectorLeftRight title:kLang(@"TapToSelect")];
    EmptyBirdRow.selectorOptions = selectorOptions;
    EmptyBirdRow.leftRightSelectorLeftOptionSelected = lastSelctedSubKind;
    EmptyBirdRow.height = 46;
    
    BirdRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"partSelector" rowType:XLFormRowDescriptorTypeSelectorLeftRight title:kLang(@"TapToSelect")];
    BirdRow.selectorOptions = selectorOptions;
    if (_serverCardClass.ID.length) {
        BirdRow.value = _serverCardClass;
    }
    BirdRow.height = 46;
    
    [multiSection addFormRow:BirdRow];
   
    
    multiSection.multivaluedRowTemplate = EmptyBirdRow;
    [self.mform addFormSection:multiSection];
     
    
    [XLFormDescriptor formDescriptorWithTitle:kLang(@"sale_from")];
    self.form = self.mform;

    [self setformDataArray:date forKey:@"sell_date"];
    
    initFlag = 1;
  /*
   
   */
}

- (CardModel *)getCardModelByID:(NSString *)cardID fromArray:(NSArray<CardModel *> *)cardsArray {
    for (CardModel *card in cardsArray) {
        if ([card.ID isEqualToString:cardID]) {
            return card;
        }
    }
    return nil; // Not found
}

- (NSString *)getSubstringAfterDot:(NSString *)input {
    NSRange range = [input rangeOfString:@"." options:NSBackwardsSearch];
    if (range.location != NSNotFound && range.location + 1 < input.length) {
        return [input substringFromIndex:range.location + 1];
    }
    return nil; // Or return input if you prefer
}

- (BOOL)isSelectorBirdRow:(XLFormRowDescriptor *)row
{
    if (!row) return NO;
    if (row == BirdRow || row == EmptyBirdRow) return YES;
    if (!row.tagM || [row.tagM isEqualToString:@"partSelector"]) return YES;
    return [row.rowType isEqualToString:XLFormRowDescriptorTypeSelectorLeftRight];
}

- (NSString *)normalizedPriceStringFromValue:(id)value
{
    NSString *raw = [[NSString stringWithFormat:@"%@", value ?: @""]
                     stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!raw.length ||
        [raw isEqualToString:@"(null)"] ||
        [raw isEqualToString:@"<null>"] ||
        [raw isEqualToString:@"null"]) {
        return @"";
    }
    return raw;
}

- (void)syncSelectedBirdsAndPriceRows
{
    NSMutableDictionary<NSString *, NSString *> *priceByCardID = [NSMutableDictionary dictionary];
    for (CardModel *card in selectedBirdsCards) {
        if (!card.ID.length) continue;
        NSString *price = [self normalizedPriceStringFromValue:card.soldPrice];
        if (price.length) {
            priceByCardID[card.ID] = price;
        }
    }

    NSMutableArray<CardModel *> *newSelected = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];

    for (XLFormRowDescriptor *row in multiSection.formRows) {
        if (![self isSelectorBirdRow:row]) continue;
        if (![row.value isKindOfClass:CardModel.class]) continue;

        CardModel *card = (CardModel *)row.value;
        if (!card.ID.length || [seenIDs containsObject:card.ID]) continue;

        NSString *priceTag = [NSString stringWithFormat:@"price.%@", card.ID];
        XLFormRowDescriptor *priceRowForCard = [self.form formRowWithTag:priceTag];
        NSString *rowPrice = [self normalizedPriceStringFromValue:priceRowForCard.value];
        NSString *savedPrice = rowPrice.length ? rowPrice : priceByCardID[card.ID];
        card.soldPrice = savedPrice ?: @"";

        [newSelected addObject:card];
        [seenIDs addObject:card.ID];
    }

    [selectedBirdsCards removeAllObjects];
    [selectedBirdsCards addObjectsFromArray:newSelected];

    NSArray<XLFormRowDescriptor *> *rowsCopy = [multiSection.formRows copy];
    for (XLFormRowDescriptor *row in rowsCopy) {
        if (![row.tagM hasPrefix:@"price."]) continue;
        NSString *cardID = [self getSubstringAfterDot:row.tagM];
        if (!cardID.length || ![seenIDs containsObject:cardID]) {
            [multiSection removeFormRow:row];
        }
    }

    for (CardModel *card in selectedBirdsCards) {
        if (!card.ID.length) continue;

        NSString *priceTag = [NSString stringWithFormat:@"price.%@", card.ID];
        XLFormRowDescriptor *row = [self.form formRowWithTag:priceTag];
        if (!row) {
            row = [XLFormRowDescriptor formRowDescriptorWithTag:priceTag
                                                        rowType:XLFormRowDescriptorTypeDecimal
                                                          title:kLang(@"buyer_price")];
            row.height = 46;
            [self rowCustomization:row];
            [multiSection addFormRow:row];
        }

        NSString *normalized = [self normalizedPriceStringFromValue:card.soldPrice];
        row.value = normalized.length ? normalized : nil;
        [self updateFormRow:row];
    }

    if (selectedBirdsCards.count > 0) {
        CardModel *last = selectedBirdsCards.lastObject;
        lastSelctedSubKind = PPSafeString(last.subKindString);
        EmptyBirdRow.leftRightSelectorLeftOptionSelected = lastSelctedSubKind;
    }
}

- (BOOL)validateSelectedBirdsBeforeSaving
{
    [self syncSelectedBirdsAndPriceRows];

    if (selectedBirdsCards.count == 0) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"warningTitle")
                            subtitle:kLang(@"TapToSelect")];
        return NO;
    }

    for (CardModel *card in selectedBirdsCards) {
        NSString *price = [self normalizedPriceStringFromValue:card.soldPrice];
        NSDecimalNumber *num = [NSDecimalNumber decimalNumberWithString:price];
        BOOL isNaN = [num isEqualToNumber:[NSDecimalNumber notANumber]];
        if (!price.length || isNaN || [num compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
            NSString *rowTag = [NSString stringWithFormat:@"price.%@", card.ID];
            XLFormRowDescriptor *priceRowForCard = [self.form formRowWithTag:rowTag];
            if (priceRowForCard) {
                UITableViewCell *cell =
                [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:priceRowForCard]];
                [self animateCell:cell];
            }
            [PPAlertHelper showWarningIn:self
                                   title:kLang(@"warningTitle")
                                subtitle:kLang(@"buyer_price")];
            return NO;
        }
    }

    return YES;
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)formRow oldValue:(id)oldValue newValue:(id)newValue
{
    (void)oldValue;
    [super formRowDescriptorValueHasChanged:formRow oldValue:oldValue newValue:newValue];

    if (!self.isHydratingFormData) {
        self.hasUserModifiedForm = YES;
    }

    if ([formRow.tagM hasPrefix:@"price."]) {
        NSString *cardID = [self getSubstringAfterDot:formRow.tagM];
        NSString *normalizedPrice = [self normalizedPriceStringFromValue:newValue];
        CardModel *selectedCard = [self getCardModelByID:cardID fromArray:selectedBirdsCards];
        if (selectedCard) {
            selectedCard.soldPrice = normalizedPrice;
        }
        return;
    }

    if ([newValue isKindOfClass:CardModel.class] || [self isSelectorBirdRow:formRow]) {
        [self syncSelectedBirdsAndPriceRows];
    }
}


- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
 forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (!self.isHydratingFormData) {
            self.hasUserModifiedForm = YES;
        }
        XLFormSectionDescriptor *section = [self.form.formSections objectAtIndex:indexPath.section];
        XLFormRowDescriptor *row = [section.formRows objectAtIndex:indexPath.row];
        
        
        if ([row.tagM hasPrefix:@"price."]) {
            row.value = nil;
            [self updateFormRow:row];
            return;
        }
       
        // Let XLForm handle the actual deletion
        [super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
        [self syncSelectedBirdsAndPriceRows];
    }
}

- (void)saveBarButton
{
    NSArray *array = [self formValidationErrors];

    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        XLFormValidationStatus *validationStatus = [[obj userInfo] objectForKey:XLValidationStatusErrorKey];
        if (!validationStatus.rowDescriptor) return;

        if ([validationStatus.rowDescriptor.tagM isEqualToString:buyer_mobileValidation]) {
            XLFormBaseCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            [self animateCell:cell];
        } else if ([validationStatus.rowDescriptor.tagM isEqualToString:sell_dateValidation]) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            [self animateCell:cell];
        } else if ([validationStatus.rowDescriptor.tagM isEqualToString:buyer_nameValidation]) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            [self animateCell:cell];
        }
        
    }];

    if (array.count == 0 && [self validateSelectedBirdsBeforeSaving]) {
        [self sendFormDataToServer];
    }
}

-(void)createNewBuyer
{
    
}


- (void)saveForm:(BKCircularLoadingButton *)buttonItem
{
    // return;
    [self saveBarButton];
    return;
}

- (void)closeForm:(UIBarButtonItem *)buttonItem
{
    [self.view endEditing:YES];
    if (self.hasUserModifiedForm && formFinishupload == 0) {
        [self presentUnsavedChangesPromptFromBarButtonItem:buttonItem];
        return;
    }

    [prefs setInteger:0 forKey:@"FromForm"];
    [self dismissViewControllerAnimated:YES completion:nil];
    // [self dismissModalViewControllerAnimated:YES];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self.view bringSubviewToFront:self.tableView];
    [self.view bringSubviewToFront:self.closeBtnIB];

    if (!self.uploadProgressView) {
        GSIndeterminateProgressView *progressView =
        [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0, 0, self.view.hx_w, 4)];
        progressView.progressTintColor = [GM appPrimaryColor];
        progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        progressView.backgroundColor = UIColor.whiteColor;
        [self.topView addSubview:progressView];
        self.uploadProgressView = progressView;
    }
}

- (void)rowCustomization:(XLFormRowDescriptor *)row
{
    
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"detailTextLabel.font"];
    [row.cellConfig setObject:[UIColor darkGrayColor] forKey:@"textLabel.textColor"];
}

- (void)setformDataArray:(id)obj forKey:(NSString *)key {
    if (!key.length) return;

    if (!self.formDataArray) {
        self.formDataArray = [NSMutableDictionary new];
    }

    if (!obj || obj == [NSNull null]) {
        if (!self.isHydratingFormData && [self.formDataArray objectForKey:key] != nil) {
            self.hasUserModifiedForm = YES;
        }
        [self.formDataArray removeObjectForKey:key];
        return;
    }

    if ([obj isKindOfClass:NSString.class]) {
        NSString *normalized =
        [(NSString *)obj stringByTrimmingCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (!normalized.length ||
            [normalized isEqualToString:@"<null>"] ||
            [normalized isEqualToString:@"(null)"] ||
            [normalized isEqualToString:@"null"] ||
            [normalized isEqualToString:@"nil"]) {
            if (!self.isHydratingFormData && [self.formDataArray objectForKey:key] != nil) {
                self.hasUserModifiedForm = YES;
            }
            [self.formDataArray removeObjectForKey:key];
            return;
        }

        id oldValue = [self.formDataArray objectForKey:key];
        if (!self.isHydratingFormData && ![oldValue isEqual:normalized]) {
            self.hasUserModifiedForm = YES;
        }
        [self.formDataArray setObject:normalized forKey:key];
        return;
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

    // NSLog(@"formDataArray After Remove %@ ", self.formDataArray);
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
}

- (void)removeindividualRow:(XLFormRowDescriptor *)sender
{
    NSIndexPath *index = [self.form indexPathOfFormRow:sender];

    NSLog(@"%@", index);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStoryboard *)storyboardForRow:(XLFormRowDescriptor *)formRow
{
    return [UIStoryboard storyboardWithName:@"Main" bundle:nil];
}

- (void)changeColor {

    //[self setTopGard:_topView];

    UIBarButtonItem *closebutton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"multiply"] style:UIBarButtonItemStylePlain target:self action:@selector(closeForm:)];
    self.navigationItem.leftBarButtonItem = closebutton;

    [self.BKbutton setTitle:kLang(@"save")  forState:UIControlStateNormal];
    [self.BKbutton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    [self.BKbutton setCircleColor:[AppPrimaryClr colorWithAlphaComponent:1.1]];
    [self.BKbutton.titleLabel setFont:[GM MidFontWithSize:16]];
    [self.BKbutton setOriginalTitle:kLang(@"save")];
    [self.BKbutton addTarget:self action:@selector(saveForm:) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *savebutton = [[UIBarButtonItem alloc] initWithTitle:@"save" style:UIBarButtonItemStylePlain target:self action:@selector(saveForm:)];
    savebutton = [[UIBarButtonItem alloc] initWithCustomView:self.BKbutton];


    NSDictionary *barButtonAppearanceDict = @{
            NSFontAttributeName: [GM MidFontWithSize:15], NSForegroundColorAttributeName: [GM appPrimaryColor]
    };
    [[UIBarButtonItem appearance] setTitleTextAttributes:barButtonAppearanceDict forState:UIControlStateNormal];

    self.navigationItem.rightBarButtonItem = savebutton;
}


- (BOOL)prefersStatusBarHidden {
    if (!self) {
        return [super prefersStatusBarHidden];
    }

    return YES;
}

- (void)closeBTN:(id)sender {
    (void)sender;
    [self closeForm:nil];
}

- (id)getformDataForKey:(NSString *)key withType:(int)type {
    if (key && [self.formDataArray objectForKey:key]) {
        return [self.formDataArray objectForKey:key];
    } else {
        return type == 0 ? @(0) : nil;
    }
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

#pragma mark - Upload Timeout Protection

- (void)pp_cancelUploadTimeout {
    if (self.uploadTimeoutBlock) {
        dispatch_block_cancel(self.uploadTimeoutBlock);
        self.uploadTimeoutBlock = nil;
    }
}

- (void)pp_scheduleUploadTimeout {
    [self pp_cancelUploadTimeout];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.uploadTimeoutBlock = nil;

        // Reset UI state directly (already on main queue)
        [strongSelf.uploadProgressView stopAnimating];
        [strongSelf.BKbutton stopAnimation];
        [strongSelf.BKbutton setEnabled:YES];
        [strongSelf.view endEditing:YES];
        [strongSelf.tableView setUserInteractionEnabled:YES];
        strongSelf.form.disabled = NO;
        strongSelf.mform.disabled = NO;

        [strongSelf pp_showUploadTimeoutError];
    });
    self.uploadTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);
}

- (void)pp_showUploadTimeoutError {
    if (self.presentedViewController) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"upload_timeout_title")
                                                                  message:kLang(@"upload_timeout_message")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"KLang_Retry")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [weakSelf sendFormDataToServer];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)sendFormDataToServer {
    [self syncSelectedBirdsAndPriceRows];

    if (selectedBirdsCards.count == 0) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"warningTitle")
                            subtitle:kLang(@"TapToSelect")];
        return;
    }

    [self.uploadProgressView startAnimating];
    [self.BKbutton startAnimation];
    [self.BKbutton setEnabled:NO];
    self.form.disabled = YES;
    self.mform.disabled = YES;
    [self.tableView setUserInteractionEnabled:NO];

    [self pp_scheduleUploadTimeout];

    NSString *buyer_nameS = [self normalizedPriceStringFromValue:[self getformDataForKey:@"buyer_name" withType:1]];
    NSString *buyer_mobileS = [self normalizedPriceStringFromValue:[self getformDataForKey:@"buyer_mobile" withType:1]];
    NSDate *sell_dateS = [self getformDataForKey:@"sell_date" withType:1];
    NSString *buyer_noteS = [self normalizedPriceStringFromValue:[self getformDataForKey:@"buyer_note" withType:1]];

    if (![sell_dateS isKindOfClass:NSDate.class]) {
        sell_dateS = [NSDate date];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_group_t createGroup = dispatch_group_create();
    __block BOOL hasCreateError = NO;

    for (CardModel *CardClass in selectedBirdsCards) {
        if (!CardClass.ID.length) {
            hasCreateError = YES;
            continue;
        }

        NSString *price = [self normalizedPriceStringFromValue:CardClass.soldPrice];
        if (!price.length) {
            hasCreateError = YES;
            continue;
        }

        BuyerModel *newBuyer = [[BuyerModel alloc] init];
        newBuyer.buyerName = buyer_nameS;
        newBuyer.buyerMobile = buyer_mobileS;
        newBuyer.sellDate = sell_dateS;
        newBuyer.buyerNote = buyer_noteS;
        newBuyer.birdWasIn = self.lastLocation;
        newBuyer.birdID = CardClass.ID;
        newBuyer.UserID = userID.length ? userID : UserManager.sharedManager.currentUser.ID;
        newBuyer.buyerPrice = price;

        dispatch_group_enter(createGroup);
        [BuyerModel createBuyer:newBuyer
                     completion:^(NSError * _Nullable createError) {
            if (createError) {
                NSLog(@"❌ Error creating buyer for card %@: %@", CardClass.ID, createError);
                hasCreateError = YES;
                dispatch_group_leave(createGroup);
                return;
            }

            NSLog(@"✅ Buyer created successfully for card %@", CardClass.ID);

            NSDictionary *updates = @{
                @"isSold": @1,
                @"soldPrice" : price,
                @"lastUpdated" : [FIRTimestamp timestampWithDate:[NSDate date]]
            };

            [CardClass updateCardWithID:CardClass.ID
                             updateDictionary:updates
                                  completion:^(NSError * _Nullable updateError) {
                if (updateError) {
                    NSLog(@"❌ Error updating card %@: %@", CardClass.ID, updateError);
                    hasCreateError = YES;
                } else {
                    NSLog(@"✅ Card %@ updated to sold", CardClass.ID);
                }
                dispatch_group_leave(createGroup);
            }];
        }];
    }

    dispatch_group_notify(createGroup, dispatch_get_main_queue(), ^{
        if (hasCreateError) {
            [weakSelf processUploadCompleteWithError:YES CardID:nil];
            return;
        }

        dispatch_group_t syncGroup = dispatch_group_create();
        __block BOOL hasSyncError = NO;

        dispatch_group_enter(syncGroup);
        [weakSelf updateCageCollection:^(int result) {
            if (result < 0) hasSyncError = YES;
            dispatch_group_leave(syncGroup);
        }];

        dispatch_group_enter(syncGroup);
        [weakSelf updateArchivesCollection:^(int result) {
            if (result < 0) hasSyncError = YES;
            dispatch_group_leave(syncGroup);
        }];

        dispatch_group_notify(syncGroup, dispatch_get_main_queue(), ^{
            if (hasSyncError) {
                NSLog(@"⚠️ Sale saved with partial side-effect sync issues");
            }
            [weakSelf processUploadCompleteWithError:NO CardID:nil];
        });
    });
}

-(void)updateArchivesCollection:(void (^)(int result))completionHandler
{
    if (selectedBirdsCards.count == 0) {
        if (completionHandler) completionHandler(0);
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    __block BOOL anyError = NO;

    for (CardModel *serverCardClass in selectedBirdsCards) {
        if (!serverCardClass.ID.length) continue;

        dispatch_group_enter(group);
        [self updateArchiveSoldStateForCardID:serverCardClass.ID
                                       isSold:YES
                                   completion:^(NSError * _Nullable error) {
            if (error) anyError = YES;
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completionHandler) {
            completionHandler(anyError ? -1 : DataLoadingResultSuccess);
        }
    });
}

- (void)updateArchiveSoldStateForCardID:(NSString *)cardID
                                 isSold:(BOOL)isSold
                             completion:(void(^)(NSError * _Nullable error))completion
{
    if (!cardID.length) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRTimestamp *nowTS = [FIRTimestamp timestampWithDate:[NSDate date]];

    [[[db collectionGroupWithID:@"ArchiveDetailsCol"]
      queryWhereField:@"CardID" isEqualTo:cardID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error) {
        if (error) {
            if (completion) completion(error);
            return;
        }

        if (snapshot.documents.count == 0) {
            if (completion) completion(nil);
            return;
        }

        FIRWriteBatch *batch = [db batch];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [batch updateData:@{
                @"isSold" : @(isSold),
                @"lastUpdated" : nowTS
            } forDocument:doc.reference];
        }

        [batch commitWithCompletion:^(NSError * _Nullable batchError) {
            if (completion) completion(batchError);
        }];
    }];
}


- (void)updateCageCollection:(void (^)(int result))completionHandler
{
    if (selectedBirdsCards.count == 0) {
        if (completionHandler) completionHandler(0);
        return;
    }

    dispatch_group_t group = dispatch_group_create();

    __block BOOL anyError = NO;
    FIRTimestamp *nowTS = [FIRTimestamp timestampWithDate:[NSDate date]];

    for (CardModel *card in selectedBirdsCards) {

        if (!card.CageID.length || !card.ID.length) {
            continue;
        }

        dispatch_group_enter(group);
        [ChildsDataManager updateChildWithCardID:card.ID
                                          cageID:card.CageID
                                            data:@{
            @"isSold" : @1,
            @"lastUpdated" : nowTS
        } completion:^(NSError * _Nullable error) {
            if (error) {
                anyError = YES;
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completionHandler) {
            completionHandler(anyError ? -1 : DataLoadingResultSuccess);
        }
    });
}



- (void)processUploadCompleteWithError:(BOOL)error CardID:(NSString *)CardID {
    (void)CardID;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_cancelUploadTimeout];
        [self.uploadProgressView stopAnimating];
        [self.BKbutton stopAnimation];
        [self.BKbutton setEnabled:YES];
        [self.view endEditing:YES];
        [self.tableView setUserInteractionEnabled:YES];
        self.form.disabled = NO;
        self.mform.disabled = NO;

        if (error) {
            [PPAlertHelper showInfoIn:self title:kLang(@"alertTitleError") subtitle:kLang(@"alertSubtitleError") completion:^{
                
            } ];
        } else {
            [PPAlertHelper showSuccessIn:self title:kLang(@"SaleDone") subtitle:kLang(@"SaleDone") OKAction:^(NSString * _Nullable text, BOOL didConfirm) {
                [self clearSavedDraft];
                [self->prefs setInteger:1 forKey:@"FromForm"];
                [self dismissModalViewControllerAnimated:YES];
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

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (FirstLoad == 0) {
        BirdRow.leftRightSelectorLeftOptionSelected =
        [SubKindModel getSubKindName:_serverCardClass.SubKind
                   subKindsArrayLocal:subKinsArr];
        if (_serverCardClass.ID.length) {
            BirdRow.value = _serverCardClass;
        }
        [self updateFormRow:BirdRow];
        FirstLoad = 1;

        EmptyBirdRow.leftRightSelectorLeftOptionSelected = lastSelctedSubKind;
        [self updateFormRow:EmptyBirdRow];

        [self syncSelectedBirdsAndPriceRows];
    }
    
    self.tableView.hx_h = self.view.hx_h;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

@end
