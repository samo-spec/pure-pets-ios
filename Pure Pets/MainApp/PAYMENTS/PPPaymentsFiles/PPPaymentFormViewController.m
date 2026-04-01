


//
//  PPPaymentFormViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

#import "PPPaymentFormViewController.h"
 
@interface PPPaymentFormViewController ()
@property (nonatomic, strong, readonly) UIButton *SaveUIButton;
 @property (nonatomic, strong) PPGlassHeaderView *header;

@property (nonatomic, nullable,strong) XLFormSectionDescriptor *saveSection ;
 
@property (nonatomic, nullable,strong) XLFormBaseCell *lastSelectedCell;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, assign) BOOL expanded;

@property (nonatomic, strong) UIButton *saveBTN;
@property (nonatomic, strong) UIButton *cancelBTN;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, weak) id <PaymentHeightDelegate> delegate;


 
@property (nonatomic, strong) UserPaymentInstrumentManager *instrumentManager;
@property (nonatomic, strong) NSArray<PaymentMethod *> *availableMethods;
@property (nonatomic, strong) PaymentMethod *selectedMethod;

@end
@implementation PPPaymentFormViewController

static NSString *PPPaymentFormTrimmedString(id value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPPaymentFormNormalizedMethodID(NSString *methodID) {
    NSString *normalized = [PPPaymentFormTrimmedString(methodID).lowercaseString copy];
    if ([normalized isEqualToString:@"card"]) {
        return @"qib";
    }
    return normalized;
}

static BOOL PPPaymentFormUsesCardFields(NSString *methodID) {
    NSString *normalized = PPPaymentFormNormalizedMethodID(methodID);
    return [normalized isEqualToString:@"qib"];
}

static NSString *PPPaymentFormDigitsOnly(NSString *value) {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSArray<NSString *> *parts = [PPPaymentFormTrimmedString(value) componentsSeparatedByCharactersInSet:nonDigits];
    return [parts componentsJoinedByString:@""];
}

static NSDictionary<NSString *, NSString *> *PPPaymentFormExpiryComponents(NSString *rawExpiry) {
    NSString *trimmed = PPPaymentFormTrimmedString(rawExpiry);
    if (trimmed.length == 0) return @{};

    NSString *month = @"";
    NSString *year = @"";
    NSArray<NSString *> *slashParts = [trimmed componentsSeparatedByString:@"/"];
    if (slashParts.count >= 2) {
        month = PPPaymentFormDigitsOnly(slashParts.firstObject);
        year = PPPaymentFormDigitsOnly(slashParts[1]);
    } else {
        NSString *digits = PPPaymentFormDigitsOnly(trimmed);
        if (digits.length == 4) {
            month = [digits substringToIndex:2];
            year = [digits substringFromIndex:2];
        } else if (digits.length == 6) {
            month = [digits substringToIndex:2];
            year = [digits substringFromIndex:2];
        }
    }

    NSInteger monthValue = [month integerValue];
    if (monthValue < 1 || monthValue > 12) return @{};
    if (year.length == 2) {
        year = [@"20" stringByAppendingString:year];
    }
    if (year.length < 4) return @{};

    return @{
        @"month": [NSString stringWithFormat:@"%02ld", (long)monthValue],
        @"year": year
    };
}


- (instancetype)init {
    self = [super init];
    if (self) {
        [self initializeForm];
    }
    return self;
}



- (instancetype)initForAddingMethod:(PaymentMethod * _Nullable)method {
    self = [super init];
    if (self) {
        _isEditingExisting = NO;
        [self initializeForm];
    }
    return self;
}

- (instancetype)initForEditingInstrument:(UserPaymentInstrument *)instrument {
    self = [super init];
    if (self) {
        _isEditingExisting = YES;
        _editingInstrument = instrument;
        _selectedMethod = instrument.method;
        [self initializeForm];
    }
    return self;
}






- (void)viewDidLoad {
    [super viewDidLoad];
    _expanded = NO;
 
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.availableMethods = [PaymentMethod defaultMethods];
    [self addCustomNavBar];
    
    if (self.mode == PPPaymentFormModeEdit && self.editingInstrument) {
        [self prefillFormWithInstrument:self.editingInstrument];
    }

    
}

- (void)prefillFormWithInstrument:(UserPaymentInstrument *)instrument {
    NSDictionary *original = instrument.originalData ?: @{};
    NSString *normalizedMethodID = PPPaymentFormNormalizedMethodID(instrument.methodID);
    
    // Pre-select method section
    self.selectedMethod = instrument.method ?: [PaymentMethod methodForID:normalizedMethodID];
    [self remveSections];
    
    XLFormSectionDescriptor *section = nil;
    if (PPPaymentFormUsesCardFields(normalizedMethodID)) {
        section = [self buildCardSection];
    } else if ([normalizedMethodID isEqualToString:@"ooredoo"]) {
        section = [self buildOoredooSection];
    } else if ([normalizedMethodID isEqualToString:@"qnb"]) {
        section = [self buildQNBSection];
    } else if ([normalizedMethodID isEqualToString:@"fawry"]) {
        section = [self buildFawrySection];
    } else {
        section = [self buildCashSection];
    }
    
    [self.form addFormSection:section];
    [self.form addFormSection:[self buildSaveSection]];

    // Pre-fill values
    for (NSString *key in original) {
        XLFormRowDescriptor *row = [self.form formRowWithTag:key];
        if (row) row.value = original[key];
    }

    [self.tableView reloadData];
}
 
- (void)saveButtonPressed {
    NSDictionary *values = [self.form formValues];

    if (!self.selectedMethod && self.editingInstrument.methodID.length > 0) {
        self.selectedMethod = [PaymentMethod methodForID:PPPaymentFormNormalizedMethodID(self.editingInstrument.methodID)];
    }

    if (!self.selectedMethod) {
        [PPHUD showError:kLang(@"PleaseSelectPaymentMethod")];
        return;
    }

    if (values.count == 0) {
        [PPHUD showError:kLang(@"PleaseCompleteFields")];
        return;
    }

 
    // 🪪 Create or update instrument
    UserPaymentInstrument *instrument = self.mode == PPPaymentFormModeEdit && self.editingInstrument
        ? self.editingInstrument
        : [[UserPaymentInstrument alloc] init];
    
    instrument.userID = PPCurrentUser.ID;
    instrument.methodID = PPPaymentFormNormalizedMethodID(self.selectedMethod.methodID);
    instrument.method = self.selectedMethod;
    if (!instrument.createdAt) instrument.createdAt = [NSDate date];
    instrument.updatedAt = [NSDate date];
    instrument.isDefault = instrument.isDefault;

    NSMutableDictionary *original = [NSMutableDictionary dictionary];
    NSMutableDictionary *meta = [NSMutableDictionary dictionary];
    NSString *masked = @"";

    switch (self.selectedMethod.type) {
        case PaymentMethodTypeQIB:
        case PaymentMethodTypeCard: {
            NSString *cardNumber = PPPaymentFormDigitsOnly(values[@"cardNumber"]);
            NSString *expiry = PPPaymentFormTrimmedString(values[@"expiry"]);
            if (cardNumber.length < 12 || expiry.length == 0) {
                [PPHUD showError:kLang(@"PleaseFillCardDetails")];
                return;
            }
            NSDictionary<NSString *, NSString *> *expiryParts = PPPaymentFormExpiryComponents(expiry);
            if (expiryParts.count == 0) {
                [PPHUD showError:kLang(@"ExpiryDatePlaceholder")];
                return;
            }

            NSString *last4 = [cardNumber substringFromIndex:MAX(0, cardNumber.length - 4)];
            masked = [NSString stringWithFormat:@"•••• %@", last4];
            meta[@"issuer"] = [instrument detectCardIssuerFromNumber:cardNumber];
            meta[@"maskedCard"] = masked;
            meta[@"last4"] = last4;
            meta[@"expiryMonth"] = expiryParts[@"month"] ?: @"";
            meta[@"expiryYear"] = expiryParts[@"year"] ?: @"";
            break;
        }

        case PaymentMethodTypeQNB: {
            NSString *account = values[@"qnbAccount"];
            if (account.length == 0) {
                [PPHUD showError:kLang(@"PleaseEnterQNBAccount")];
                return;
            }
            original[@"qnbAccount"] = account;
            masked = [instrument maskString:account];
            meta[@"bank"] = @"QNB";
            meta[@"maskedAccount"] = masked;
            break;
        }

        case PaymentMethodTypeOoredoo: {
            NSString *number = values[@"ooredooNumber"];
            if (number.length == 0) {
                [PPHUD showError:kLang(@"PleaseEnterOoredooNumber")];
                return;
            }
            original[@"ooredooNumber"] = number;
            masked = [instrument maskString:number];
            meta[@"provider"] = @"Ooredoo Money";
            meta[@"maskedWallet"] = masked;
            break;
        }

        case PaymentMethodTypeFawryQatar: {
            NSString *customer = values[@"customerName"];
            NSString *mobile = values[@"mobileNumber"];
            NSString *email = values[@"email"] ?: @"";
            NSString *reference = values[@"referenceCode"] ?: @"";
            if (mobile.length == 0 || customer.length == 0) {
                [PPHUD showError:kLang(@"PleaseCompleteFawryDetails")];
                return;
            }
            original[@"customerName"] = customer;
            original[@"mobileNumber"] = mobile;
            original[@"email"] = email;
            original[@"referenceCode"] = reference;
            masked = [instrument maskString:mobile];
            meta[@"provider"] = @"Fawry Qatar";
            meta[@"maskedMobile"] = masked;
            break;
        }

        case PaymentMethodTypeCash:
            masked = kLang(@"CashPayment");
            meta[@"type"] = @"Cash";
            break;

        default:
            masked = @"••••••";
            break;
    }


    instrument.originalData = original;
    instrument.metaData = meta;
    instrument.maskedDetails = masked;

    __weak typeof(self) weakSelf = self;

    if (self.mode == PPPaymentFormModeEdit) {
        [self.instrumentManager updateInstrument:instrument
                                          forUser:PPCurrentUser.ID
                                       completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [PPHUD showSuccess:kLang(@"PaymentMethodUpdated")
                          subtitle:kLang(@"PaymentUpdatedSubtitle")];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            } else {
                [PPHUD showError:kLang(@"FailedToUpdatePaymentMethod")];
            }
        }];
    } else {
        [self.instrumentManager addInstrument:instrument
                                      forUser:PPCurrentUser.ID
                                   completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [PPHUD showSuccess:kLang(@"PaymentMethodSaved")
                          subtitle:kLang(@"PaymentSavedSubtitle")];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            } else {
                [PPHUD showError:kLang(@"FailedToSavePaymentMethod")];
            }
        }];
    }

}



- (NSString *)detectCardIssuerFromNumber:(NSString *)cardNumber {
    if ([cardNumber hasPrefix:@"4"]) return @"Visa";
    if ([cardNumber hasPrefix:@"5"]) return @"MasterCard";
    if ([cardNumber hasPrefix:@"34"] || [cardNumber hasPrefix:@"37"]) return @"American Express";
    if ([cardNumber hasPrefix:@"6"]) return @"Discover";
    return kLang(@"Unknown");
}

-(void)addCustomNavBar
{
    NSString *headerTitle = (self.mode == PPPaymentFormModeEdit)
        ? kLang(@"EditPaymentTitle")
        : kLang(@"SelectPaymentMethod");


    self.header = [[PPGlassHeaderView alloc] initWithTitle:headerTitle  cancelHandler:^{
         [super onBack];
        [self.navigationController popViewControllerAnimated:YES];
    }];
    
   // [self.view addSubview:self.header];
    
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:65],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:0],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        
    ]];
    
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    UIButton *saveBTN;
    UIButton *backBTN;
    
 
    NSString *saveTitle = (self.mode == PPPaymentFormModeEdit)
        ? kLang(@"Update")
        : kLang(@"Save");

    saveBTN = [PPButtonHelper pp_buttonWithTitleForBar:saveTitle
                                             imageName:@"checkmark.circle"
                                                target:self
                                                action:@selector(saveButtonPressed)];

    UIBarButtonItem *saveBarButton =
        [[UIBarButtonItem alloc] initWithCustomView:saveBTN];
    self.navigationItem.rightBarButtonItem = saveBarButton;

    // Back button (RTL aware)
  
   
    self.navigationItem.leftBarButtonItem =  [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName) style:UIBarButtonItemStylePlain target:self action:@selector(onBack)];
    // Ensure header and placeholders are on top
 
    //[self.view bringSubviewToFront:_emptyCard];
    
    
}


- (XLFormRowDescriptor *)generateRawWithType:(NSString *)rowType
                                   inputType:(XLFormFullWidthTextFieldType)inputType
                                         tag:(NSString *)tag
                                       title:(NSString *)title
                                 placeholder:(NSString *)placeholder
                                    required:(BOOL)required
                                       value:(id)value
{
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:tag
                                                                     rowType:rowType
                                                                       title:title];
    [row.cellConfigAtConfigure setObject:placeholder forKey:@"textField.placeholder"];
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"detailTextLabel.font"];
    [row.cellConfig setObject:UIColor.lightGrayColor forKey:@"detailTextLabel.textColor"];
    [row.cellConfig setObject:AppSecondaryTextClr forKey:@"textField.textColor"];
    
    [row.cellConfig setObject:@(GM.setAligment) forKey:@"detailTextLabel.textAlignment"];
    row.cellConfig[@"inputType"] = @(inputType);
    row.cellConfig[@"titlePosition"] = inputType == XLFormFullWidthTextFieldTypeButton ? @(XLFormFullWidthTextFieldTitlePosCenter) : @(XLFormFullWidthTextFieldTitlePosTop);
    
    row.required = required;
    if (value) row.value = value;
    row.height = 70;
    return row;
}

- (XLFormRowDescriptor *)PaymentRowWithTag:(NSString *)tag
                                     title:(NSString *)title
                                  subtitle:(NSString * _Nullable)subtitle
                                      icon:(NSString * _Nullable)icon inSection:(XLFormSectionDescriptor *)section
{
    
    
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:tag
                                                                     rowType:XLFormRowFullWidthTitleSubtitleAndImage
                                                                       title:title];
    row.height = 64;
    row.cellConfig[@"subtitle"] = subtitle; // "Visa, MasterCard, American Express"
    row.cellConfig[@"icon"] = icon;
    [section addFormRow:row];
    
    return row;
}

-(void)remveSections
{
    // Assuming you already have your XLFormDescriptor instance, for example:
    XLFormDescriptor *form = self.form;
    
    // Keep only section 0
    if (form.formSections.count > 1) {
        // Get the first section
        XLFormSectionDescriptor *firstSection = form.formSections.firstObject;
        
        // Remove all sections
        [form.formSections removeAllObjects];
        
        // Add back only section 0
        [form.formSections addObject:firstSection];
        
        // Reload the form view
        [self.tableView reloadData];
    }
    
    
}
/*
 
 #pragma mark - XLForm Setup
 - (void)initializeForm {
     XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:kLang(@"AddPaymentTitle")];
     
     // SECTION 1 - Payment Method
 #pragma mark - Payment Options Section
     
     XLFormSectionDescriptor *paymentSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodTitle")];
     [self setupPaymentSection:paymentSection];
     [form addFormSection:paymentSection];
     
     self.cardSection = [self buildCardSection];
     self.ooredooSection = [self buildOoredooSection];
     self.QNBSection = [self buildQNBSection];
     self.cashSection = [self buildCashSection];
     
     // Build modular sections
     
     self.form = form;
 }
 */

#pragma mark - 🧾 Initialize Form

- (void)initializeForm {
    NSString *title = self.isEditingExisting
        ? kLang(@"EditPaymentTitle")   // تعديل وسيلة الدفع
        : kLang(@"AddPaymentTitle");   // إضافة وسيلة دفع جديدة
    
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:title];
    
    if (self.isEditingExisting && self.editingInstrument) {
        // Build the form directly for this instrument
        NSString *methodID = self.editingInstrument.methodID.length > 0
            ? self.editingInstrument.methodID
            : self.editingInstrument.method.methodID;
        [self buildFormForMethodID:methodID
                    prefilledValues:self.editingInstrument.originalData ?: @{}];
        return;
    } else {
        // Show method selector first
        XLFormSectionDescriptor *paymentSection =
            [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodTitle")];
        
        [self setupPaymentSection:paymentSection];
        [form addFormSection:paymentSection];
    }

    self.form = form;
}


#pragma mark - 🧱 Build Form For Selected Method

- (void)buildFormForMethodID:(NSString *)methodID prefilledValues:(NSDictionary *)values {
    NSString *title = self.isEditingExisting
        ? kLang(@"EditPaymentTitle")
        : kLang(@"AddPaymentTitle");

    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:title];
    NSString *normalizedMethodID = PPPaymentFormNormalizedMethodID(methodID);
    self.selectedMethod = [PaymentMethod methodForID:normalizedMethodID];
    
    XLFormSectionDescriptor *section = nil;

    if (PPPaymentFormUsesCardFields(normalizedMethodID)) {
        section = [self buildCardSection];
    } else if ([normalizedMethodID isEqualToString:@"ooredoo"]) {
        section = [self buildOoredooSection];
    } else if ([normalizedMethodID isEqualToString:@"qnb"]) {
        section = [self buildQNBSection];
    } else if ([normalizedMethodID isEqualToString:@"fawry"]) {
        section = [self buildFawrySection];
    } else if ([normalizedMethodID isEqualToString:@"cash"]) {
        section = [self buildCashSection];
    }
    if (!section) {
        section = [self buildCashSection];
    }

    // Prefill values if available
    for (XLFormRowDescriptor *row in section.formRows) {
        NSString *tag = row.tagM;
        if (values[tag]) {
            row.value = values[tag];
        }
    }

    [form addFormSection:section];
    [form addFormSection:[self buildSaveSection]];
    self.form = form;
}


#pragma mark - ⚙️ Dynamic Payment Section Builder

- (void)buildFormWithAvailableMethods {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:kLang(@"AddPaymentTitle")];
    
    // 💳 Payment Options Section
    XLFormSectionDescriptor *paymentSection =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodTitle")];
    
    [form addFormSection:paymentSection];
    
    for (PaymentMethod *method in self.availableMethods) {
        XLFormRowDescriptor *row = [self PaymentRowWithTag:method.methodID
                                                     title:method.displayName
                                                  subtitle:method.methodDescription ?: @""
                                                      icon:method.iconName
                                                 inSection:paymentSection];
        
        row.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
            // You can handle selection here if needed
            // [weakSelf handlePaymentSelection:method];
        };
    }
    
    self.form = form;
}


#pragma mark - 🧾 Setup Payment Section

- (void)setupPaymentSection:(XLFormSectionDescriptor *)paymentSection {
    // ====== Credit / Debit Card ======
    [self PaymentRowWithTag:@"qib"
                      title:kLang(@"PaymentOptionCard")
                   subtitle:kLang(@"PaymentOptionCardSubtitle")
                       icon:@"card1"
                  inSection:paymentSection];
    
    /* ====== Ooredoo Money ======
    [self PaymentRowWithTag:@"ooredoo"
                      title:kLang(@"Ooredoo Money")
                   subtitle:kLang(@"PaymentOptionOoredooSubtitle")
                       icon:@"ooredoo"
                  inSection:paymentSection];
    
    // ====== QNB ======
    [self PaymentRowWithTag:@"qnb"
                      title:kLang(@"PaymentMethodQNBTitle")
                   subtitle:kLang(@"Qatar National Bank")
                       icon:@"qnb"
                  inSection:paymentSection];
    
    // ====== Fawry Qatar ======
    [self PaymentRowWithTag:@"fawry"
                      title:kLang(@"Fawry Qatar")
                   subtitle:kLang(@"PaymentOptionFawrySubtitle")
                       icon:@"fawry"
                  inSection:paymentSection];
    
    */// ====== Cash on Delivery ======
    [self PaymentRowWithTag:@"cash"
                      title:kLang(@"Cash on Delivery")
                   subtitle:kLang(@"PaymentOptionCashSubtitle")
                       icon:@"cash2"
                  inSection:paymentSection];
}


#pragma mark - 🪄 Handle Selection

- (void)didSelectFormRow:(XLFormRowDescriptor *)formRow {
    if ([self.form indexPathOfFormRow:formRow].section == 0) {
        
        if (self.mode == PPPaymentFormModeEdit) {
            [PPHUD showInfo:kLang(@"EditingModeActive")
                   subtitle:kLang(@"YouCanEditFieldsBelow")];
            return;
        }

        NSString *normalizedMethodID = PPPaymentFormNormalizedMethodID(formRow.tagM);
        self.selectedMethod = [PaymentMethod methodForID:normalizedMethodID];
        if (!self.selectedMethod) {
            [PPHUD showError:kLang(@"PleaseSelectPaymentMethod")];
            return;
        }
        
        if (self.lastSelectedCell)
            [self deSelectCell:self.lastSelectedCell];
        
        if (self.lastSelectedSection)
            [self remveSections];
        
        _expanded = !_expanded;
        
        NSIndexPath *selectedIndexPath = [self.form indexPathOfFormRow:formRow];
        self.lastSelectedCell = [self.tableView cellForRowAtIndexPath:selectedIndexPath];
        [self selectCell:self.lastSelectedCell];
        
        // Prebuild all form sections
        self.cardSection    = [self buildCardSection];
        self.ooredooSection = [self buildOoredooSection];
        self.QNBSection     = [self buildQNBSection];
        self.fawrySection   = [self buildFawrySection];
        self.cashSection    = [self buildCashSection];
        self.saveSection    = [self buildSaveSection];
        
        // Add the selected one dynamically
        NSString *selectedMethodID = PPPaymentFormNormalizedMethodID(self.selectedMethod.methodID);
        if ([selectedMethodID isEqualToString:@"fawry"]) {
            self.lastSelectedSection = self.fawrySection;
        } else if (PPPaymentFormUsesCardFields(selectedMethodID)) {
            self.lastSelectedSection = self.cardSection;
        } else if ([selectedMethodID isEqualToString:@"ooredoo"]) {
            self.lastSelectedSection = self.ooredooSection;
        } else if ([selectedMethodID isEqualToString:@"qnb"]) {
            self.lastSelectedSection = self.QNBSection;
        } else if ([selectedMethodID isEqualToString:@"cash"]) {
            self.lastSelectedSection = self.cashSection;
        }
        
        if (self.lastSelectedSection) {
            [self.form addFormSection:self.lastSelectedSection];
            [self.form addFormSection:self.saveSection];
        }
        
        [self selectCell:self.lastSelectedCell];
        [self.tableView reloadData];
        
    } else {
        if ([formRow.tagM isEqualToString:@"generateFawryRef"]) {
            [self generateFawryReferencePressed:formRow];
        }
    }
    
    NSLog(@"didSelectFormRow %@", self.selectedMethod);
}


-(void)selectCell:(UITableViewCell *)cell{
     
    cell.alpha = 0.0;
    cell.transform = CGAffineTransformMakeScale(0.96, 0.96);

     

    // Fade + gentle pop-in
    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.alpha = 1.0;
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.tintColor = [AppPrimaryClr colorWithAlphaComponent:1.2];
        cell.transform = CGAffineTransformIdentity;
                     }
                     completion:^(BOOL finished) {
        [self.delegate expandToLargeDetent:self.expanded];
    }];
    
    
    
    
}

-(void)deSelectCell:(UITableViewCell *)cell{
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    [UIView animateWithDuration:0.15 animations:^{
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectedBackgroundView = ({
            UIView *bg = [UIView new];
            bg.backgroundColor = AppForgroundColr;
            bg;
        });
        cell.backgroundColor= AppForgroundColr;
        
        cell.tintColor = AppClearClr;
        cell.transform = CGAffineTransformIdentity;
    }];
    
}

#pragma mark - 🧾 Build Fawry Payment Section

- (XLFormSectionDescriptor *)buildFawrySection {
    XLFormSectionDescriptor *section =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodFawryTitle")];
    section.footerTitle = kLang(@"PaymentMethodFawryFooter");
    
    // 🔹 Customer Name
    XLFormRowDescriptor *customerName =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"customerName"
                                              rowType:XLFormRowDescriptorTypeText
                                                title:kLang(@"FawryCustomerNameTitle")];
    customerName.required = YES;
    customerName.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"FawryCustomerNamePlaceholder");
    customerName.height = 54;
    [section addFormRow:customerName];
    
    // 🔹 Customer Mobile Number
    XLFormRowDescriptor *mobileNumber =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"mobileNumber"
                                              rowType:XLFormRowDescriptorTypePhone
                                                title:kLang(@"FawryMobileTitle")];
    mobileNumber.required = YES;
    mobileNumber.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"FawryMobilePlaceholder");
    mobileNumber.height = 54;
    [section addFormRow:mobileNumber];
    
    // 🔹 Email (optional)
    XLFormRowDescriptor *email =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"email"
                                              rowType:XLFormRowDescriptorTypeEmail
                                                title:kLang(@"FawryEmailTitle")];
    email.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"FawryEmailPlaceholder");
    email.height = 54;
    [section addFormRow:email];
    
    // 🔹 Reference Code (disabled until generated)
    XLFormRowDescriptor *referenceCode =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"referenceCode"
                                              rowType:XLFormRowDescriptorTypeText
                                                title:kLang(@"FawryReferenceTitle")];
    referenceCode.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"FawryReferencePlaceholder");
    referenceCode.disabled = @YES;
    referenceCode.height = 54;
    [section addFormRow:referenceCode];
    
    // 🔹 Inline loading indicator (hidden initially)
    XLFormRowDescriptor *loadingRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"fawryLoading"
                                              rowType:XLFormRowDescriptorTypeInfo
                                                title:kLang(@"FawryLoadingTitle")];
    loadingRow.cellConfig[@"detailTextLabel.textColor"] = AppSecondaryTextClr;
    loadingRow.hidden = @YES;
    [section addFormRow:loadingRow];
    
    // 🔹 Generate Reference Button
    XLFormRowDescriptor *generateButton =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"generateFawryRef"
                                              rowType:XLFormRowDescriptorTypeButton
                                                title:kLang(@"GenerateFawryReferenceButton")];
    generateButton.action.formSelector = @selector(generateFawryReferencePressed:);
    generateButton.cellConfigAtConfigure[@"backgroundColor"] = AppPrimaryClr;
    generateButton.cellConfigAtConfigure[@"textLabel.textColor"] = UIColor.whiteColor;
    generateButton.height = 54;
    [section addFormRow:generateButton];
    
    return section;
}


#pragma mark - ⚙️ Generate Fawry Reference

- (void)generateFawryReferencePressed:(XLFormRowDescriptor *)sender {
    XLFormRowDescriptor *loadingRow   = [self.form formRowWithTag:@"fawryLoading"];
    XLFormRowDescriptor *referenceRow = [self.form formRowWithTag:@"referenceCode"];
    
    // 1️⃣ Show loading row
    loadingRow.hidden = @NO;
    loadingRow.title  = kLang(@"FawryLoadingTitle");
    [self updateFormRow:loadingRow];
    
    // 2️⃣ Disable button during request
    sender.disabled = @YES;
    [self updateFormRow:sender];
    
    // 3️⃣ Production-safe behavior: no local simulation.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
    loadingRow.hidden = @YES;
    [self updateFormRow:loadingRow];

    referenceRow.value = nil;
    [self updateFormRow:referenceRow];

    sender.disabled = @NO;
    [self updateFormRow:sender];

    [PPHUD showError:kLang(@"FawryReferenceError")];
    });
}

#pragma mark - 💳 Card Section

- (XLFormSectionDescriptor *)buildCardSection {
    XLFormSectionDescriptor *section =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodCardTitle")];
    section.footerTitle = kLang(@"PaymentMethodCardFooter");
    
    XLFormRowDescriptor *cardNumber =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"cardNumber"
                                              rowType:XLFormRowDescriptorTypeText
                                                title:kLang(@"CardNumberTitle")];
    cardNumber.required = YES;
    cardNumber.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"CardNumberPlaceholder");
    cardNumber.height = 54;
    [section addFormRow:cardNumber];
    
    XLFormRowDescriptor *expiry =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"expiry"
                                              rowType:XLFormRowDescriptorTypeText
                                                title:kLang(@"ExpiryDateTitle")];
    expiry.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"ExpiryDatePlaceholder");
    expiry.height = 54;
    [section addFormRow:expiry];
    
    XLFormRowDescriptor *cvv =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"cvv"
                                              rowType:XLFormRowDescriptorTypePassword
                                                title:kLang(@"CVVTitle")];
    cvv.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"CVVPlaceholder");
    cvv.height = 54;
    [section addFormRow:cvv];
    
    return section;
}

#pragma mark - 🇴🇴 Ooredoo Section

- (XLFormSectionDescriptor *)buildOoredooSection {
    XLFormSectionDescriptor *section =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodOoredooTitle")];
    section.footerTitle = kLang(@"PaymentMethodOoredooFooter");
    
    XLFormRowDescriptor *phoneRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"ooredooNumber"
                                              rowType:XLFormRowDescriptorTypePhone
                                                title:kLang(@"OoredooWalletNumberTitle")];
    phoneRow.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"OoredooWalletNumberPlaceholder");
    phoneRow.height = 54;
    [section addFormRow:phoneRow];
    
    return section;
}

#pragma mark - 💰 PayPal Section

- (XLFormSectionDescriptor *)buildPayPalSection {
    XLFormSectionDescriptor *section =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodPayPalTitle")];
    section.footerTitle = kLang(@"PaymentMethodPayPalFooter");
    
    XLFormRowDescriptor *emailRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"paypalEmail"
                                              rowType:XLFormRowDescriptorTypeEmail
                                                title:kLang(@"PayPalEmailTitle")];
    emailRow.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"PayPalEmailPlaceholder");
    emailRow.height = 54;
    [section addFormRow:emailRow];
    
    return section;
}

#pragma mark - 🏦 QNB Section

- (XLFormSectionDescriptor *)buildQNBSection {
    XLFormSectionDescriptor *section =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodQNBTitle")];
    section.footerTitle = kLang(@"PaymentMethodQNBFooter");
    
    XLFormRowDescriptor *accountRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"qnbAccount"
                                              rowType:XLFormRowDescriptorTypeText
                                                title:kLang(@"QNBAccountTitle")];
    accountRow.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"QNBAccountPlaceholder");
    accountRow.height = 54;
    [section addFormRow:accountRow];
    
    XLFormRowDescriptor *otpRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"qnbOtp"
                                              rowType:XLFormRowDescriptorTypePassword
                                                title:kLang(@"QNBOTPTitle")];
    otpRow.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"QNBOTPPlaceholder");
    otpRow.height = 54;
    [section addFormRow:otpRow];
    
    return section;
}

#pragma mark - 💵 Cash Section

- (XLFormSectionDescriptor *)buildCashSection {
    XLFormSectionDescriptor *section =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodCashTitle")];
    section.footerTitle = kLang(@"PaymentMethodCashFooter");
    
    XLFormRowDescriptor *noteRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"cashNote"
                                              rowType:XLFormRowDescriptorTypeTextView
                                                title:kLang(@"DeliveryNoteTitle")];
    noteRow.cellConfigAtConfigure[@"textView.placeholder"] = kLang(@"DeliveryNotePlaceholder");
    noteRow.height = 80;
    [section addFormRow:noteRow];
    
    return section;
}

#pragma mark - 💾 Save Section

- (XLFormSectionDescriptor *)buildSaveSection {
    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
    
    NSString *saveTitle =
        (self.mode == PPPaymentFormModeEdit) ? kLang(@"Update") : kLang(@"Save");
    
    XLFormRowDescriptor *saveRow =
        [XLFormRowDescriptor formRowDescriptorWithTag:@"saveRow"
                                              rowType:XLFormRowButtonKey
                                                title:saveTitle];
    
    saveRow.action.formSelector = @selector(saveButtonPressed);
    saveRow.height = 90;
    saveRow.cellConfig[@"icon"] = @"plus";
    //[section addFormRow:saveRow];
    
     
    return section;
}


//[_checkoutButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:pad],
//[_checkoutButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-pad],
//[_checkoutButton.heightAnchor constraintEqualToConstant:60],
//[_checkoutButton.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-10]
@end
























@interface PPGlassHeaderView ()
@property (nonatomic, copy) void (^cancelHandler)(void);
@end

@implementation PPGlassHeaderView

- (instancetype)initWithTitle:(NSString *)title
                cancelHandler:(void (^)(void))handler {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.cancelHandler = handler;
        [self setupUIWithTitle:title];
    }
    return self;
}

- (void)setupUIWithTitle:(NSString *)title {
    // 🧱 Background (transparent by default)
    self.backgroundColor = UIColor.clearColor;
    
    // Title Label
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = title;
    _titleLabel.font = [GM boldFontWithSize:18];
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration *config;
    // Cancel Button
    if (@available(iOS 16.0, *)) {
        if (@available(iOS 26.0, *))
            config = [UIButtonConfiguration glassButtonConfiguration];
        else
            config = [UIButtonConfiguration filledButtonConfiguration];
        
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.buttonSize = UIButtonConfigurationSizeMedium;
        config.baseForegroundColor = UIColor.labelColor;
        
        _cancelButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
        [_cancelButton setImage:PPSYSImage(@"multiply") forState:UIControlStateNormal];
    } else {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelButton setImage:PPSYSImage(@"multiply") forState:UIControlStateNormal];
        _cancelButton.backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.4];
        _cancelButton.layer.cornerRadius = 8;
    }
    
    //_cancelButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [_cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Stack container
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _cancelButton]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:26],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
        
        [_cancelButton.widthAnchor constraintEqualToConstant:40],
        [_cancelButton.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (void)cancelTapped {
    if (self.cancelHandler) {
        self.cancelHandler();
    }
}






@end
/*
 
 // SECTION 1 - Payment Method
 #pragma mark - Payment Options Section
 
 XLFormSectionDescriptor *paymentSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PaymentMethodTitle")];
 [self setupPaymentSection:paymentSection];
 [form addFormSection:paymentSection];
 
 
 // SECTION 2 - Card Info
 XLFormSectionDescriptor *cardSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"cardInformationTitle")];
 //[form addFormSection:cardSection];
 
 XLFormRowDescriptor *cardNumber = [XLFormRowDescriptor formRowDescriptorWithTag:@"cardNumber"
 rowType:XLFormRowDescriptorTypeText
 title:kLang(@"CardNumberLabel")];
 cardNumber.required = YES;
 cardNumber.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"FieldRequiredPlaceholder");
 [cardSection addFormRow:cardNumber];
 
 XLFormRowDescriptor *expiry = [XLFormRowDescriptor formRowDescriptorWithTag:@"expiry"
 rowType:XLFormRowDescriptorTypeText
 title:kLang(@"CardExpiryLabel")];
 expiry.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"CardExpiryPlaceholder");
 [cardSection addFormRow:expiry];
 
 XLFormRowDescriptor *cvv = [XLFormRowDescriptor formRowDescriptorWithTag:@"cvv"
 rowType:XLFormRowDescriptorTypePassword
 title:kLang(@"CardCVVLabel")];
 cvv.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"CardCVVPlaceholder");
 [cardSection addFormRow:cvv];
 
 // SECTION 3 - Billing Name
 XLFormSectionDescriptor *nameSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"BillingNameTitle")];
 //[form addFormSection:nameSection];
 
 XLFormRowDescriptor *firstName = [XLFormRowDescriptor formRowDescriptorWithTag:@"firstName"
 rowType:XLFormRowDescriptorTypeText
 title:kLang(@"FirstNameLabel")];
 firstName.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"FieldRequiredPlaceholder");
 [nameSection addFormRow:firstName];
 
 XLFormRowDescriptor *lastName = [XLFormRowDescriptor formRowDescriptorWithTag:@"lastName"
 rowType:XLFormRowDescriptorTypeText
 title:kLang(@"LastNameLabel")];
 lastName.cellConfigAtConfigure[@"textField.placeholder"] = kLang(@"FieldRequiredPlaceholder");
 [nameSection addFormRow:lastName];
 
 
 
 // Done Button
 XLFormSectionDescriptor *doneSection = [XLFormSectionDescriptor formSectionWithTitle:@" "];
 XLFormRowDescriptor *doneRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"done"
 rowType:XLFormRowDescriptorTypeButton
 title:kLang(@"DoneButtonTitle")];
 doneRow.action.formSelector = @selector(submitForm);
 [form addFormSection:doneSection];
 //[doneSection addFormRow:doneRow];
 */
