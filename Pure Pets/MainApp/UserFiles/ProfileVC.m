//
//  ProfileVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2024.
//

#import "ProfileVC.h"
#import "PPPermissionHelper.h"
#import "PhoneNumberCell.h"
#import "XLFormRowFullWidthTextFieldCell.h"
#import "PPVerificationCodeViewController.h"
 
@interface ProfileVC ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate,AddressFormVCDelegate,TOCropViewControllerDelegate,PHPickerViewControllerDelegate>
{
    float thisContentLength;
    float viewTempSize;
    
    NSString *loginString;
    NSString *DescString;
    NSString *getCOdeString;
    NSString *codeBtnString;
    NSString *warmsq;
    NSString *warmsqName;
    
    NSUserDefaults *prefs ;
    NSURL *ImageUrl;
    
    BOOL addressLoadedFromUserModel;
    int flag;
    float topPadding;
    float bottomPadding;
    UIImage *localUserImage;
    NSMutableDictionary * cellProfileDataDict;
    NSString *addressPickerRowTag;
    XLFormPhoneCodeItem *MobileNoRow ;
    
    XLFormRowDescriptor *UserNameRow;
    XLFormRowDescriptor *firstNameRow ;
    XLFormRowDescriptor *LastNameRow ;
    XLFormRowDescriptor *UserEmailRow ;
    XLFormRowDescriptor *UserAboutRow ;
    XLFormRowDescriptor *codeRow;
    
    
    BKCircularLoadingButton *savebtn;
}
@property (nonatomic,assign) BOOL showingSave;
@property (nonatomic,assign) BOOL appear;
@property XLFormDescriptor *mform;
@property (nonatomic, strong) XLFormSectionDescriptor *basicDataSection;
@property (nonatomic, strong) UIButton *saveBTN;
@property (nonatomic, strong) UIButton *skipBTN;
@property (nonatomic, strong) XLFormSectionDescriptor *addressesSection;
@property (nonatomic, strong) XLFormRowDescriptor *addRow;
 @property (nonatomic, strong) NSArray<PPAddressModel *> *addresses;
@property (nonatomic, strong) id<FIRListenerRegistration> addressListener;

@property(nonatomic,retain)NSMutableArray<CountryCodeModel *> * contriesArray;
@property(nonatomic,retain)NSArray * ProfileTableDataArr;

@property(nonatomic,assign)NSIndexPath * NewIndexPath;
@property NSMutableDictionary *formDataArray;
@property (strong, nonatomic) CountryCodeModel *selectedCountry;
//@property (nonatomic, strong) NSArray<AddressModel *> *Addresses;

@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) RoundedImageViewWithShadow *avatarIMV;
@property (nonatomic, strong) UIButton *addPhotoBtn;

@property (nonatomic, strong, nullable) UIImage *pendingAvatarImage; // keep for later upload if needed

@property (nonatomic, strong) UIBarButtonItem *saveDataBarButton;
@property (nonatomic, strong) UIBarButtonItem *logoutBarButton;
@property (nonatomic, assign) BOOL isSavingProfile;
@property (nonatomic, assign) BOOL suppressEditTracking;
@property (nonatomic, copy) NSDictionary<NSString *, id> *profileDraftBaseline;
@end


@implementation ProfileVC

- (void)pp_showSaveButton
{
    if (!_saveDataBarButton) {
        _saveDataBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(updateUserData)];
    }
    [_saveDataBarButton setAction:@selector(updateUserData)];
    _saveDataBarButton.target = self;
    self.navigationItem.rightBarButtonItem = _saveDataBarButton;

    UIButton *saveBtn = [self pp_ButtonWithSystemName:@"checkmark" action:@selector(updateUserData)];
    [self pp_navBarRemoveButtonForKey:@"saveOrLogout"];
    [self _pp_addRightButton:saveBtn key:@"saveOrLogout"];
}

- (void)pp_showLogoutButton
{
    UIButton *logoutBtn = [self pp_ButtonWithSystemName:@"power" action:@selector(logoutTapped)];
    [self pp_navBarRemoveButtonForKey:@"saveOrLogout"];
    [self _pp_addRightButton:logoutBtn key:@"saveOrLogout"];
}

- (NSDictionary<NSString *, id> *)pp_profileDraftSnapshot
{
    CountryCodeModel *country = self.selectedCountry;
    if (!country && [codeRow.value isKindOfClass:CountryCodeModel.class]) {
        country = (CountryCodeModel *)codeRow.value;
    }

    NSString *firstName = [self pp_trimmedString:firstNameRow.value];
    NSString *lastName = [self pp_trimmedString:LastNameRow.value];
    NSString *userName = [self pp_trimmedString:UserNameRow.value];
    NSString *userEmail = [[self pp_trimmedString:UserEmailRow.value] lowercaseString];
    NSString *userAbout = [self pp_trimmedString:UserAboutRow.value];
    NSString *mobileLocal = [self pp_trimmedString:MobileNoRow.value];
    NSNumber *countryID = @((long)(country ? country.ID : 0));

    return @{
        @"firstName": firstName ?: @"",
        @"lastName": lastName ?: @"",
        @"userName": userName ?: @"",
        @"userEmail": userEmail ?: @"",
        @"userAbout": userAbout ?: @"",
        @"mobileLocal": mobileLocal ?: @"",
        @"countryID": countryID ?: @0
    };
}

- (void)pp_captureProfileDraftBaseline
{
    self.profileDraftBaseline = [self pp_profileDraftSnapshot];
}

- (BOOL)pp_hasPendingProfileChanges
{
    if (self.pendingAvatarImage != nil) {
        return YES;
    }

    NSDictionary<NSString *, id> *currentSnapshot = [self pp_profileDraftSnapshot];
    if (!self.profileDraftBaseline) {
        return currentSnapshot.count > 0;
    }
    return ![self.profileDraftBaseline isEqualToDictionary:currentSnapshot];
}

- (void)pp_refreshRightNavSaveState
{
    BOOL hasChanges = [self pp_hasPendingProfileChanges];
    self.showingSave = hasChanges;
    if (hasChanges) {
        [self pp_showSaveButton];
    } else {
        [self pp_showLogoutButton];
    }
}

- (void)markFormAsEdited {
    if (self.suppressEditTracking) {
        return;
    }
    [self pp_refreshRightNavSaveState];

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

                                       [row.cellConfig setObject:UIColor.secondaryLabelColor forKey:@"detailTextLabel.textColor"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textField.textColor"];

    [row.cellConfig setObject:@(GM.setAligment) forKey:@"detailTextLabel.textAlignment"];
    row.cellConfig[@"inputType"] = @(inputType);
row.cellConfig[@"titlePosition"] = inputType == XLFormFullWidthTextFieldTypeButton ? @(XLFormFullWidthTextFieldTitlePosCenter) : @(XLFormFullWidthTextFieldTitleLeftRightText);

    row.required = required;
    if (value) row.value = value;
                                       row.height = 50;
    return row;
}
 
#pragma mark - Helpers
- (XLFormRowDescriptor *)fullTextRow:(NSString *)tag
                               title:(NSString *)title
                        placeholder:(NSString *)placeholder
                             value:(NSString *)value {

    XLFormRowDescriptor *row =
    [XLFormRowDescriptor formRowDescriptorWithTag:tag
                                          rowType:XLFormRowDescriptorTypeText
                                            title:title];

    [row.cellConfigAtConfigure setObject:placeholder forKey:@"textField.placeholder"];
    [row.cellConfig setObject:AppPrimaryTextClr forKey:@"textField.textColor"];

    row.value = value;
 
    return row;
}


-(void)initForms
{
    addressLoadedFromUserModel = NO;
    self.showingSave = NO;
    self.contriesArray = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];

    self.addresses = [NSMutableArray arrayWithArray:[UserManager.sharedManager currentUser].Addresses]; // Example source

    
    self.mform = [XLFormDescriptor formDescriptor];
    
    self.mform.assignFirstResponderOnShow = NO;
    
    NSString *firstNamePalce = [NSString stringWithFormat:@"%@", kLang(@"firstName_Palce")];
    NSString *LastNamePalce = [NSString stringWithFormat:@"%@", kLang(@"LastName_Palce")];
    NSString *UserNamePalce = [NSString stringWithFormat:@"%@", kLang(@"UserName_Palce")];
    NSString *MobileNoPalce = [NSString stringWithFormat:@"%@", kLang(@"MobileNo_Palce")];
    NSString *UserEmailPalce = [NSString stringWithFormat:@"%@", kLang(@"UserEmail_Palce")];
    NSString *UserAboutPalce = [NSString stringWithFormat:@"%@", kLang(@"UserAbout_Palce")];
    NSString *codePalce = [NSString stringWithFormat:@"%@", kLang(@"code_Palce")];
    
    
    typeof(self) __weak weakself = self;
  
    XLFormSectionDescriptor * section;
    section = [XLFormSectionDescriptor formSection];  //WithTitle:kLang(@"user_data")
    [self.mform addFormSection:section];
    
    
    // Username
    UserNameRow = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                  inputType:XLFormFullWidthTextFieldTypeDefault
                                        tag:kUserNameRow
                                      title:UserNamePalce
                                  placeholder:kLang(@"UserName_Palce")
                                     required:NO
                                        value:PPCurrentUser.FirstName];
   
  
    UserNameRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        if (newValue && ![newValue isEqual:oldValue] && ![newValue isEqual:PPCurrentUser.UserName]) {
            [weakself markFormAsEdited];
        }
        [weakself setformDataArray:newValue forKey:@"UserName"];
    };
    UserNameRow.cellConfig[@"titlePosition"] = @(XLFormFullWidthTextFieldTitleLeftRightText);
    UserNameRow.value = PPCurrentUser.UserName;
    [section addFormRow:UserNameRow];
    
    
    
  
    
    

    firstNameRow = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                   inputType:XLFormFullWidthTextFieldTypeDefault
                                          tag:kfirstNameRow
                                        title:firstNamePalce
                                   placeholder:kLang(@"Enter_First_Name")
                                      required:NO
                                         value:PPCurrentUser.FirstName];
    firstNameRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        if (newValue && ![newValue isEqual:oldValue] && ![newValue isEqual:PPCurrentUser.FirstName]) {
            [weakself markFormAsEdited];
        }
        [weakself setformDataArray:newValue forKey:@"firstName"];
    };
    [section addFormRow:firstNameRow];
    
    
    // Last Name
    LastNameRow = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                  inputType:XLFormFullWidthTextFieldTypeDefault
                                         tag:kLastNameRow
                                       title:LastNamePalce
                                  placeholder:kLang(@"Enter_Last_Name")
                                     required:NO
                                        value:PPCurrentUser.LastName];
    LastNameRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        if (newValue && ![newValue isEqual:oldValue] && ![newValue isEqual:PPCurrentUser.LastName]) {
            [weakself markFormAsEdited];
        }
        [weakself setformDataArray:newValue forKey:@"LastName"];
    };
    [section addFormRow:LastNameRow];


   
    
  
    
    self.basicDataSection = [XLFormSectionDescriptor formSectionWithTitle:@""];
    [self.mform addFormSection:self.basicDataSection];
    
    // Row with selector (XLFormRowDescriptorTypeSelectorPush)
    codeRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"codeRow" rowType:XLFormRowDescriptorTypeSelectorActionSheet title:codePalce];
    
    codeRow.required = NO;
    codeRow.selectorOptions = self.contriesArray;// Options to display in the selector
    
    if(self.selectedCountry)
        codeRow.value = self.selectedCountry;
    
    codeRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *__unused rowDescriptor) {
        CountryCodeModel *previousCountry = weakself.selectedCountry;
        NSString *existingLocalNumber = [weakself pp_trimmedString:MobileNoRow.value];
        if (existingLocalNumber.length == 0 && PPCurrentUser.MobileNo.length > 0) {
            existingLocalNumber = [weakself pp_localPhonePartFromE164:PPCurrentUser.MobileNo
                                                             dialCode:[weakself pp_trimmedString:previousCountry.phoneCode]];
        }
        weakself.selectedCountry = newValue;
        [weakself setformDataArray:@(weakself.selectedCountry.ID) forKey:@"CountryID"];
        MobileNoRow.dialCode = weakself.selectedCountry.phoneCode ?: @"";
        MobileNoRow.flag = weakself.selectedCountry.flag;
        MobileNoRow.countryCode = weakself.selectedCountry.isoCountryCode ?: @"";
        MobileNoRow.value = existingLocalNumber;
        [weakself updateFormRow:MobileNoRow];
        [weakself updatePrefixForCountryCode:weakself.selectedCountry.phoneCode];
        [weakself markFormAsEdited];
        
    };
    [self.basicDataSection addFormRow:codeRow];
    
    MobileNoRow = [[XLFormPhoneCodeItem alloc] initWithTag:kMobileNoRow
                                                                  rowType:XLFormRowDescriptorTypePhoneCode
                                                                    title:nil];
    MobileNoRow.dialCode = _selectedCountry.phoneCode;
    MobileNoRow.flag = _selectedCountry.flag;
    MobileNoRow.countryCode = _selectedCountry.isoCountryCode;
    // Allow editing even for phone-provider users; we verify before saving if number changed.
    
    if(PPCurrentUser.MobileNo)
        MobileNoRow.value = PPCurrentUser.MobileNo;

    MobileNoRow.onChangeBlock  = ^(id oldValue, id newValue, XLFormRowDescriptor *__unused rowDescriptor) {
        NSString *countryCode = [weakself pp_trimmedString:weakself.selectedCountry.phoneCode];
        NSString *localNumber = [weakself pp_trimmedString:newValue];
        NSString *combined = localNumber.length > 0
            ? [NSString stringWithFormat:@"%@%@", countryCode ?: @"", localNumber]
            : @"";
        [weakself setformDataArray:combined forKey:@"MobileNo"];
        [weakself updatePrefixForCountryCode:weakself.selectedCountry.phoneCode];
        [weakself markFormAsEdited];
    };
    [self.basicDataSection addFormRow:MobileNoRow];
    
    
    // Email
    UserEmailRow =  [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                    inputType:XLFormFullWidthTextFieldTypeEmail
                                           tag:kUserEmailRow
                                         title:UserEmailPalce
                                    placeholder:UserEmailPalce
                                       required:NO
                                          value:PPCurrentUser.UserEmail];
    
    UserEmailRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [weakself setformDataArray:newValue forKey:@"UserEmail"];
        [weakself markFormAsEdited];
    };
    [self.basicDataSection addFormRow:UserEmailRow];
    
    UserAboutRow = [XLFormRowDescriptor formRowDescriptorWithTag:kUserAboutRow rowType:XLFormRowDescriptorTypeTextView title:UserAboutPalce];
    [UserAboutRow.cellConfig setObject:UIColor.lightGrayColor forKey:@"textLabel.textColor"];
    UserAboutRow.value = PPCurrentUser.UserAbout;
    UserAboutRow.onChangeBlock = ^(id _Nullable oldValue, id _Nullable newValue, XLFormRowDescriptor *_Nonnull rowDescriptor) {
        [weakself setformDataArray:newValue forKey:@"UserAbout"];
        [weakself markFormAsEdited];
    };
    [self.basicDataSection addFormRow:UserAboutRow];
  
    // Addresses Section
    self.addressesSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"Shipping Addresses") sectionOptions: XLFormSectionOptionCanDelete];
    self.addressesSection.multivaluedTag = @"addressesSection";
    //self.addressesSection.multivaluedAddButton.title = kLang(@"AddNewAddress");
    [self.mform addFormSection:self.addressesSection];
    
    XLFormSectionDescriptor *addSection = [XLFormSectionDescriptor formSection];
    [self.mform addFormSection:addSection];
     self.addRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"addAddress" rowType:XLFormRowButtonKey title:kLang(@"Add New Address")];
   
    [Styling applyGlobalStyleToRow: self.addRow];
    self.addRow.cellConfig[@"icon"] = @"plus";
    self.addRow.action.formSelector = @selector(openAddressFormForNew);
    
    
    [addSection addFormRow:self.addRow];
    //
    //
    //
    //////////////////////////////////////////---------------------------------------------------------------------
    ///
    ///
  
    self.form = self.mform;
   
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    
    
    [weakself setformDataArray:@(weakself.selectedCountry.ID) forKey:@"CountryID"];
    [weakself updatePrefixForCountryCode:weakself.selectedCountry.phoneCode];
    
    //[self setTopGard:_topView];
    
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppClearClr); //
    self.tableView.backgroundColor = AppClearClr; //

    [self setupHeaderUI];
    [self listenToAddresses];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor].active = YES;
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor].active = YES;
    [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor].active = YES;
    [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor].active = YES;
    
 }
- (void)reloadAddressesSection {
    dispatch_async(dispatch_get_main_queue(),
 ^{  // ✅ Always on main thread
        if (!self.addressesSection) return;
        
        if ([self.form.formSections containsObject:self.addressesSection])
        {
            [self.form removeFormSectionAtIndex:2];  }
        
        self.addressesSection =
        [XLFormSectionDescriptor formSectionWithTitle:kLang(@"")  //Shipping Addresses
                                       sectionOptions: XLFormSectionOptionCanDelete];
        self.addressesSection.multivaluedTag = @"addressesSection";
        self.addressesSection.multivaluedAddButton.title = kLang(@"AddNewAddress");
        [self.mform addFormSection:self.addressesSection afterSection:self.basicDataSection];
         
        
        // ✅ Ensure section exists in the form
        if (![self.form.formSections containsObject:self.addressesSection]) {
            [self.form addFormSection:self.addressesSection afterSection:self.basicDataSection];
        }
        
        // ✅ Handle empty state
        if (self.addresses.count > 0)
        {
            // ✅ Add each address row
            for (PPAddressModel *address in self.addresses) {
                if (address == nil) continue;

                XLFormRowDescriptor *row =
                [XLFormRowDescriptor formRowDescriptorWithTag:address.documentID ?: [[NSUUID UUID] UUIDString]
                                                      rowType:XLFormRowDescriptorTypeInfo
                                                        title:address.displayName ?: @"(Unnamed Address)"];

                row.value = address;
                [row.cellConfig setObject:[GM MidFontWithSize:16.0]
                                   forKey:@"textLabel.font"];
                [row.cellConfig setObject:(address.isDefault ? [AppPrimaryClr colorWithAlphaComponent:1.2] : UIColor.labelColor)
                                   forKey:@"textLabel.textColor"];
                [row.cellConfig setObject:@(Language.alignmentForCurrentLanguage)
                                   forKey:@"textLabel.textAlignment"];
          
                row.action.formBlock = ^(XLFormRowDescriptor * _Nonnull sender) {
                    [self openAddressFormFor:address];
                };
             
                [self.addressesSection addFormRow:row];
            }
        }

        //CGPoint oldOffset = self.tableView.contentOffset;
        //[UIView performWithoutAnimation:^{
        //    [self.tableView reloadData];
        //    [self.tableView layoutIfNeeded];
        //}];
        //[self.tableView setContentOffset:oldOffset animated:NO];
        
        /*
         
         // ✅ Animate reload for better UX
         [UIView transitionWithView:self.tableView
                           duration:0.25
                            options:UIViewAnimationOptionTransitionCrossDissolve
                         animations:^{
             [self.tableView beginUpdates];
             [self.tableView endUpdates];
         } completion:nil];
         */
    });
}
#pragma mark - Shipping Addresses Section

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
}
 
- (void)listenToAddresses {
    [self.addressListener remove];
    self.addressListener = nil;
    if (PPCurrentUser.Addresses.count > 0) {
        [self pp_applyLatestAddresses:PPCurrentUser.Addresses];
    }
    NSString *authenticatedUID = [PPADDRESS currentAuthenticatedUserID] ?: @"";
    if (authenticatedUID.length == 0) {
        [self pp_applyLatestAddresses:@[]];
        return;
    }
    __weak typeof(self) weakSelf = self;
    self.addressListener = [[PPAddressesManager sharedManager]
        listenToAddressesWithBlock:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error) {
            BOOL isUnauthenticatedError =
                [error.domain isEqualToString:@"PPAddressesManager"] &&
                error.code == 401;
            if (isUnauthenticatedError || [PPADDRESS currentAuthenticatedUserID].length == 0) {
                [weakSelf pp_applyLatestAddresses:@[]];
                return;
            }
            NSLog(@"❌ Address listener error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:error.localizedDescription ?: @""];
            });
            return;
        }
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}

- (void)pp_applyLatestAddresses:(NSArray<PPAddressModel *> *)addresses
{
    self.addresses = addresses ?: @[];
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (currentUser) {
        currentUser.Addresses = self.addresses.mutableCopy;
        [UserManager.sharedManager cacheUser:currentUser];
    }
    [self debouncedReloadAddresses];
}



- (void)debouncedReloadAddresses {
    static BOOL isScheduled = NO;
    if (isScheduled) return;
    isScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self reloadAddressesSection];
        isScheduled = NO;
    });
}



#pragma mark - Reload Addresses Section

#pragma mark - Reload Addresses Section (Safe)
-(void)openAddressFormForNew
{
    AddressFormVC *vc = [[AddressFormVC alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)didSelectFormRow:(XLFormRowDescriptor *)formRow
{
    [super didSelectFormRow:formRow];
    if([formRow.sectionDescriptor.multivaluedTag isEqualToString:@"addressesSection"])
    {
        PPAddressModel *address = formRow.value;
        if (!address) return;
        [self openAddressFormFor:address];
    }
    if([formRow.tagM isEqualToString:@"addAddress"])
    {
        [self openAddressFormForNew];
    }
     
}

- (void)openAddressFormFor:(nullable PPAddressModel *)address {
    AddressFormVC *vc = [[AddressFormVC alloc] initWithAddress:address];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}
- (void)formSectionInsertButtonWasPressed:(XLFormSectionDescriptor *)section {
    if ([section.multivaluedTag isEqualToString:@"addressesSection"]) {
        //[self openAddressFormFor:nil];
    }
}
- (void)formRowHasBeenRemoved:(XLFormRowDescriptor *)formRow atIndexPath:(NSIndexPath *)indexPath {
    if (![formRow.sectionDescriptor.multivaluedTag isEqualToString:@"addressesSection"]) return;
    
    PPAddressModel *address = formRow.value;
    if (!address) return;
    
    [[PPAddressesManager sharedManager] deleteAddress:address completion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [PPHUD showSuccess:kLang(@"AddressesDeleted") subtitle:@""];
            } else {
                [PPHUD showError:kLang(@"DeleteFailed")
                         subtitle:error.localizedDescription ?: @""];
            }
            [self reloadAddressesSection];
        });
    }];

}
#pragma mark - AddressFormVCDelegate

- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address {
    __weak typeof(self) weakSelf = self;
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (error) return;
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
    
}

- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address {
    __weak typeof(self) weakSelf = self;
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (error) return;
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}
- (void)dealloc {
    [self.addressListener remove];
    self.addressListener = nil;
}


 




//==================================================================================================================================================== TABLE VIEW
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!PPIOS26())  [Styling applyBackgroundStyleForTableView:tableView cell:cell indexPath:indexPath useRowCardMode:NO];
}
- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)formRow oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:formRow oldValue:oldValue newValue:newValue];
    NSLog(@"XLFormRowDescriptor TAG %@   \n oldValue %@  \n newValue %@  \n  ", formRow.tagM, oldValue, newValue);
}

 

- (void)presentModernModal:(UIViewController *)modalViewController from:(UIViewController *)presentingVC {
    if (!presentingVC || !modalViewController) return;
    
    [presentingVC presentViewController:modalViewController animated:YES completion:^{
        NSLog(@"✅ Modal presented");
    }];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // M-05: Auth gate — prevent guest users from accessing the profile edit form.
    // Without this check, unauthenticated users can reach PPCurrentUser fields
    // (CountryID, MobileNo, etc.) which resolve to nil/zero and cause undefined behaviour.
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        // Pop back safely on the next run-loop tick so the navigation stack settles first.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.navigationController) {
                [self.navigationController popViewControllerAnimated:YES];
            } else {
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        });
        return;
    }

    [self BellowIos26Buttons];
    //[self setupTopBar];
  
    [[NSNotificationCenter defaultCenter]
           postNotificationName:PPHideSystemTabBarNotification
                         object:nil];
}


- (void)BellowIos26Buttons {
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"UserProfile") showBack:YES];

    // Keep this ready for save mode; UI state itself is decided by current dirty state.
    if (!_saveDataBarButton) {
        _saveDataBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(updateUserData)];
    }
    [self pp_refreshRightNavSaveState];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
    NSLog(@"viewWillDisappear");
    [PPHUD dismiss];
     
    [[XLFormViewController cellClassesForRowDescriptorTypes] setObject:[XLFormTextFieldCell class] forKey:XLFormRowDescriptorTypeText];
    
    [[NSNotificationCenter defaultCenter]
           postNotificationName:PPShowSystemTabBarNotification
                         object:nil];
   
}

- (void)updatePrefixForCountryCode:(NSString *)countryCode {
    if (!MobileNoRow) {
        return;
    }
    PhoneNumberCell *phoneCell = (PhoneNumberCell *)[[self.form formRowWithTag:kMobileNoRow] cellForFormController:self];
    if ([phoneCell isKindOfClass:PhoneNumberCell.class]) {
        phoneCell.prefixLabel.text = countryCode ?: @"";
    }
    MobileNoRow.dialCode = countryCode ?: @"";
    [self updateFormRow:MobileNoRow];
}

- (NSString *)prefixForCountryCode:(NSString *)countryCode {
    // Example: Return prefix based on country code
    
    for (NSDictionary *dic in [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]]) {
        if([[dic valueForKey:@"country"] isEqualToString:countryCode])
            return [dic valueForKey:@"phoneCode"];
    }
    
    return @""; // Default
}

// Implement formValueForKey to access values:
- (id)formValueForKey:(NSString *)key {
    return [self.formValues objectForKey:key];
}


- (void)closeForm:(UIBarButtonItem *)buttonItem
{
    [self dismissViewControllerAnimated:YES completion:nil];
    // [self dismissModalViewControllerAnimated:YES];
}

- (void)saveDateToServer
{
    __block int errorCount = 0;
    NSArray *array = [self formValidationErrors];
    
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        XLFormValidationStatus *validationStatus = [[obj userInfo] objectForKey:XLValidationStatusErrorKey];
        
        if ([validationStatus.rowDescriptor.tagM isEqualToString:kfirstNameRow]) {
            XLFormBaseCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            errorCount = errorCount + 1;
            [self animateCell:cell];
        } else if ([validationStatus.rowDescriptor.tagM isEqualToString:kLastNameRow]) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            errorCount = errorCount + 1;
            [self animateCell:cell];
        } else if ([validationStatus.rowDescriptor.tagM isEqualToString:kUserNameRow]) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            errorCount = errorCount + 1;
            [self animateCell:cell];
        }
        
        else if ([validationStatus.rowDescriptor.tagM isEqualToString:kMobileNoRow]) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            errorCount = errorCount + 1;
            [self animateCell:cell];
        }
    }];
    
    if (array.count == 0) {
        [self.tableView endEditing:YES];
        [self performSegueWithIdentifier:@"showOTP" sender:self];
        return;
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
}

- (void)removeindividualRow:(XLFormRowDescriptor *)sender
{
    NSIndexPath *index = [self.form indexPathOfFormRow:sender];
    NSLog(@"%@", index);
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.contriesArray = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    NSInteger selectedCountryID = PPCurrentUser.CountryID;
    CountryCodeModel *countryByID = selectedCountryID > 0
        ? [[self.contriesArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", selectedCountryID]] firstObject]
        : nil;
    CountryCodeModel *countryByMobile = [self pp_countryFromStoredMobileNumber:PPCurrentUser.MobileNo];
    NSString *carrierISO = [self pp_trimmedString:[GM getCurrentCountryFromCarrier]];
    CountryCodeModel *countryByCarrier = carrierISO.length > 0 ? [self pp_countryWithISOCode:carrierISO] : nil;
    NSString *currentISO = [self pp_trimmedString:CitiesManager.shared.CurrentCountry.iso];
    CountryCodeModel *countryByCurrent = currentISO.length > 0 ? [self pp_countryWithISOCode:currentISO] : nil;
    NSString *localeISO = [self pp_trimmedString:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    CountryCodeModel *countryByLocale = localeISO.length > 0 ? [self pp_countryWithISOCode:localeISO] : nil;

    self.selectedCountry = countryByID ?: countryByMobile ?: countryByCarrier ?: countryByCurrent ?: countryByLocale ?: [self pp_qatarCountry];
    if (countryByID && countryByMobile && ![countryByID.phoneCode isEqualToString:countryByMobile.phoneCode]) {
        NSString *storedMobile = [self pp_trimmedString:PPCurrentUser.MobileNo];
        if ([storedMobile hasPrefix:countryByMobile.phoneCode]) {
            self.selectedCountry = countryByMobile;
        }
    }
    if (!self.selectedCountry) {
        self.selectedCountry = [self pp_qatarCountry];
    }
    NSLog(@"selectedCountry: %@ ID: %ld", self.selectedCountry.country, self.selectedCountry.ID);
    
    self.formDataArray = [NSMutableDictionary new];
    self.suppressEditTracking = YES;
    [self initForms];
    if (self.selectedCountry.phoneCode.length > 0 && PPCurrentUser.MobileNo.length > 0) {
        MobileNoRow.value = [self pp_localPhonePartFromE164:PPCurrentUser.MobileNo
                                                    dialCode:self.selectedCountry.phoneCode];
        [self updateFormRow:MobileNoRow];
    }
    [self pp_captureProfileDraftBaseline];
    self.showingSave = NO;
    self.suppressEditTracking = NO;
    
    self.view.layer.cornerRadius = 25;
    self.view.clipsToBounds = YES;

    prefs = [NSUserDefaults standardUserDefaults];
    cellProfileDataDict = [NSMutableDictionary dictionary];
    flag = 0;
    
    
}


- (void)fillCurrentUserData {
    
    if(PPCurrentUser.CountryID){
        [self setForDataForRow:[NSString stringWithFormat:@"%ld",PPCurrentUser.CountryID] andValue:@"CountryID"];
    }
    
    
    if(PPCurrentUser.UserName)
        [self setForDataForRow:PPCurrentUser.UserName andValue:kUserNameRow];
    
    if(PPCurrentUser.FirstName)
        [self setForDataForRow:PPCurrentUser.FirstName andValue:kfirstNameRow];
    
    if(PPCurrentUser.LastName)
        [self setForDataForRow:PPCurrentUser.LastName andValue:kLastNameRow];
    
    if(PPCurrentUser.UserEmail)
        [self setForDataForRow:PPCurrentUser.UserEmail andValue:kUserEmailRow];
    
    if(PPCurrentUser.UserAbout)
        [self setForDataForRow:PPCurrentUser.UserAbout andValue:kUserAboutRow];
    
    
    if(PPCurrentUser.MobileNo)
        [self setformDataArray:PPCurrentUser.MobileNo forKey:kMobileNoRow];
    
    
    
}

- (void)setForDataForRow:(NSString *)Tag andValue:(id)value {
    NSLog(@"Tag is %@",Tag);
    XLFormRowDescriptor *row =   [self.form formRowWithTag:Tag];
    BOOL previousSuppress = self.suppressEditTracking;
    self.suppressEditTracking = YES;
    row.value = value;
    
    [self updateFormRow:[self.form formRowWithTag:Tag]];
    self.suppressEditTracking = previousSuppress;
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
        NSString *trimmed = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            [self.formDataArray removeObjectForKey:key];
            return;
        }
        self.formDataArray[key] = trimmed;
        return;
    }
    self.formDataArray[key] = obj;
}

- (void)removeDataArrayObjects:(NSArray *)objArray {
    for (NSString *key in objArray) {
        [self.formDataArray removeObjectForKey:key];
    }
    NSLog(@"formDataArray After Remove %@ ", self.formDataArray);
}



- (IBAction)dismissMe:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}


- (IBAction)popBTN:(id)sender {
    [self popoverPresentationController];
}

#pragma mark - textFiled Edit Status
-(void)beginediting:(UITextField *)textF
{
    NSLog(@"field beginediting %@",textF.text);
    // [textF becomeFirstResponder];
}



#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    
}

- (id)getformDataForKey:(NSString *)key withType:(int)type {
    if ([self.formDataArray objectForKey:key] != nil) {
        return [self.formDataArray objectForKey:key];
    } else {
        return type == 0 ? 0 : [NSString stringWithFormat:@"no_value"];
    }
}



NSString *imageUUIDString(void) {
    NSUUID *uuid = [NSUUID UUID];
    return [uuid UUIDString];
}



- (void)logoutTapped{
    NSLog(@"logOut ---->>>>  %@",kLang(@"logOut"));
    NSString *lastSelectedLanguage = Language.currentLanguageCode;
    LeaveFeedbackViewController *feedbackVC = [[LeaveFeedbackViewController alloc] init];
    feedbackVC.onLogout = ^{
        
        [Language userSelectedLanguage:lastSelectedLanguage];
        [self applyLanguageChangeAndReloadUIFrom:self];
        
       
        
        [AppData stopAllListeners];
    };
    
    [PPFunc presentSheetFrom:self sheetVC:feedbackVC detentStyle:PPSheetDetentStyle70];
    
    
}




#pragma mark - Live language switch (no app restart)

- (void)applyLanguageChangeAndReloadUIFrom:(UIViewController *)sourceVC {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        if (!window) return;

        // Build a fresh root
        UIViewController *newRoot = [self buildRootController];
        if (!newRoot) return;

        // Cross-dissolve (Apple-style)
        [UIView transitionWithView:window
                          duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            BOOL old = [UIView areAnimationsEnabled];
            [UIView setAnimationsEnabled:NO];
            window.rootViewController = newRoot;
            [window makeKeyAndVisible];
            [UIView setAnimationsEnabled:old];
        } completion:nil];
    });
    
}

- (UIWindow *)keyWindow {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w;
    }
    UIWindow *fallback = UIApplication.sharedApplication.windows.firstObject;
    if (!fallback) {
        NSLog(@"❌ ProfileVC: no UIWindow available");
    }
    return fallback;
}

// 🔥 Always rebuild the REAL app root
- (UIViewController *)buildRootController {
    PPRootTabBarController *root =
        [[PPRootTabBarController alloc] init];
    return root;
}

-(void)viewWillLayoutSubviews
{
     [super viewWillLayoutSubviews];
    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];
    CGFloat height = [self.headerRoot systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    CGRect frame = self.headerRoot.frame;
    frame.size.height = height;
    self.headerRoot.frame = frame;
    self.tableView.tableHeaderView = self.headerRoot;
    [Styling addLiquidGlassBorderToView:self.avatarIMV cornerRadius:50.0];
   
  
}



 

- (void)didTapAddPhoto {
    
    UIAlertController *sheet =
    [UIAlertController alertControllerWithTitle:nil
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Camera")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self openCamera];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Photo_Library")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self openPhotoPicker];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = self.addPhotoBtn;
    sheet.popoverPresentationController.sourceRect = self.addPhotoBtn.bounds;

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openPhotoPicker {

    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.filter = [PHPickerFilter imagesFilter];
        config.selectionLimit = 1;

        PHPickerViewController *picker =
        [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
    else {
        [self openLegacyPicker];
    }
}

#pragma mark - Legacy Picker
- (void)openLegacyPicker {
    [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:self
                                                            completion:^(BOOL granted) {
        if (!granted) return;

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

#pragma mark - Camera
- (void)openCamera {

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        return;
    }

    [PPPermissionHelper requestCameraPermissionFromViewController:self
                                                       completion:^(BOOL granted) {
        if (!granted) return;
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

#pragma mark - PHPicker Delegate
- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    PHPickerResult *result = results.firstObject;
    if ([result.itemProvider canLoadObjectOfClass:[UIImage class]]) {

        [result.itemProvider loadObjectOfClass:[UIImage class]
                             completionHandler:^(UIImage *image, NSError *error) {
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handlePickedImage:image];
                });
            }
        }];
    }
}

#pragma mark - UIImagePickerController
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {

    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        [self handlePickedImage:image];
    }];
}

#pragma mark - Cropping
- (void)handlePickedImage:(UIImage *)image {

    [UIImage pp_presentCircularCropperWithImage:image
                                  fromController:self];
}

- (void)cropViewController:(TOCropViewController *)cropViewController
 didCropToCircularImage:(UIImage *)image
                  withRect:(CGRect)cropRect
                     angle:(NSInteger)angle {

    [self updateAvatar:image];
    [cropViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateAvatar:(UIImage *)image {

    [UIView transitionWithView:self.avatarIMV
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.pendingAvatarImage = image;
        self.avatarIMV.imageView.image = image;
        self.avatarIMV.tintColor = nil;
        self.avatarIMV.backgroundColor = UIColor.clearColor;
        [self markFormAsEdited];
    }
                    completion:nil];

    [PPFunc triggerLightHaptic];
}

#pragma mark - Header (Avatar + Add Photo)
- (void)setupHeaderUI {
    self.headerRoot = [[UIView alloc] init];
    self.headerRoot.backgroundColor = UIColor.clearColor;

    self.avatarIMV = [[RoundedImageViewWithShadow alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    self.avatarIMV.userInteractionEnabled = YES;
    if(PPCurrentUser.UserImageUrl)
        [GM setImageFromUrlString:PPSafeString(PPCurrentUser.UserImageUrl.absoluteString) imageView:self.avatarIMV.imageView phImage:@"person.crop.circle.fill"];
     
    self.avatarIMV.layer.cornerRadius = 50.0;
    self.avatarIMV.layer.masksToBounds = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapAddPhoto)];
    [self.avatarIMV addGestureRecognizer:tap];
    self.avatarIMV.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerRoot addSubview:self.avatarIMV];

    // 📷 Add Image Button
    UIButton *addImageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [addImageButton setTitle:kLang(@"Add Photo") forState:UIControlStateNormal];
    [addImageButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    addImageButton.backgroundColor = AppPrimaryClr;
    addImageButton.layer.cornerRadius = 20;
    addImageButton.translatesAutoresizingMaskIntoConstraints = NO;
    [addImageButton addTarget:self action:@selector(didTapAddPhoto) forControlEvents:UIControlEventTouchUpInside];
    [addImageButton.titleLabel setFont:[GM MidFontWithSize:17]];
    self.addPhotoBtn =  addImageButton;
    [self.headerRoot addSubview:self.addPhotoBtn];

    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.avatarIMV.centerXAnchor constraintEqualToAnchor:self.headerRoot.centerXAnchor],
        [self.avatarIMV.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:10],
        [self.avatarIMV.widthAnchor constraintEqualToConstant:100],
        [self.avatarIMV.heightAnchor constraintEqualToConstant:100],
        
        [addImageButton.topAnchor constraintEqualToAnchor:self.avatarIMV.bottomAnchor constant:12],
        [addImageButton.centerXAnchor constraintEqualToAnchor:self.headerRoot.centerXAnchor],
        [addImageButton.widthAnchor constraintEqualToConstant:110],
        [addImageButton.heightAnchor constraintEqualToConstant:40],
        [addImageButton.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-16],

 
     ]];

    // ⚠️ IMPORTANT: Calculate proper size for header
    CGSize fittingSize = [self.headerRoot systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    self.headerRoot.frame = CGRectMake(0, 0, self.view.bounds.size.width, fittingSize.height);
    
    self.tableView.tableHeaderView = self.headerRoot;
}


- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
   
   
    [Styling addLiquidGlassBorderToView:self.avatarIMV cornerRadius:50.0];
}

- (void)pp_setProfileSaving:(BOOL)isSaving
{
    self.isSavingProfile = isSaving;
    self.navigationItem.rightBarButtonItem.enabled = !isSaving;
    self.navigationItem.leftBarButtonItem.enabled = !isSaving;
    [self pp_navBarHideButtonForKey:@"saveOrLogout" hidden:isSaving animated:NO];
    self.tableView.userInteractionEnabled = !isSaving;
}

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)pp_isValidEmail:(NSString *)email
{
    if (email.length == 0) return YES;
    NSString *pattern = @"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", pattern];
    return [predicate evaluateWithObject:email];
}

- (NSString *)pp_digitsOnlyString:(NSString *)value
{
    NSString *raw = [self pp_trimmedString:value];
    if (raw.length == 0) return @"";

    NSMutableString *digits = [NSMutableString string];
    NSCharacterSet *digitSet = NSCharacterSet.decimalDigitCharacterSet;
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar ch = [raw characterAtIndex:i];
        if (ch >= '0' && ch <= '9') {
            [digits appendFormat:@"%c", (char)ch];
            continue;
        }
        if (ch >= 0x0660 && ch <= 0x0669) { // Arabic-Indic
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x0660))];
            continue;
        }
        if (ch >= 0x06F0 && ch <= 0x06F9) { // Extended Arabic-Indic
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x06F0))];
            continue;
        }
        if (ch >= 0xFF10 && ch <= 0xFF19) { // Full-width digits
            [digits appendFormat:@"%c", (char)('0' + (ch - 0xFF10))];
            continue;
        }
        if ([digitSet characterIsMember:ch]) {
            // Last-resort normalization for uncommon Unicode numeral forms.
            NSString *scalar = [NSString stringWithCharacters:&ch length:1];
            NSInteger numeric = [scalar integerValue];
            if (numeric >= 0 && numeric <= 9) {
                [digits appendFormat:@"%ld", (long)numeric];
            }
        }
    }
    return digits;
}

- (CountryCodeModel *)pp_countryFromStoredMobileNumber:(NSString *)mobile
{
    NSString *trimmed = [self pp_trimmedString:mobile];
    if (trimmed.length == 0 || ![trimmed hasPrefix:@"+"]) {
        return nil;
    }

    CountryCodeModel *best = nil;
    NSUInteger bestLen = 0;
    for (CountryCodeModel *candidate in self.contriesArray ?: @[]) {
        NSString *dial = [self pp_trimmedString:candidate.phoneCode];
        if (dial.length == 0 || ![dial hasPrefix:@"+"]) continue;
        if ([trimmed hasPrefix:dial] && dial.length > bestLen) {
            best = candidate;
            bestLen = dial.length;
        }
    }
    return best;
}

- (CountryCodeModel *)pp_countryWithISOCode:(NSString *)isoCode
{
    NSString *trimmedISO = [[self pp_trimmedString:isoCode] uppercaseString];
    if (trimmedISO.length != 2) {
        return nil;
    }

    for (CountryCodeModel *candidate in self.contriesArray ?: @[]) {
        NSString *candidateISO = [[self pp_trimmedString:candidate.isoCountryCode] uppercaseString];
        if ([candidateISO isEqualToString:trimmedISO]) {
            return candidate;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_qatarCountry
{
    CountryCodeModel *qatar = [self pp_countryWithISOCode:@"QA"];
    return qatar ?: self.contriesArray.firstObject;
}

- (NSString *)pp_localPhonePartFromE164:(NSString *)mobile dialCode:(NSString *)dialCode
{
    NSString *trimmedMobile = [self pp_trimmedString:mobile];
    NSString *trimmedDialCode = [self pp_trimmedString:dialCode];
    if (trimmedMobile.length == 0 || trimmedDialCode.length == 0) {
        return trimmedMobile;
    }

    NSString *dialDigits = [trimmedDialCode stringByReplacingOccurrencesOfString:@"+" withString:@""];
    NSString *mobileDigits = [[trimmedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""]
                              stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (dialDigits.length > 0 && [mobileDigits hasPrefix:dialDigits]) {
        return [mobileDigits substringFromIndex:dialDigits.length];
    }
    return trimmedMobile;
}

- (NSString *)pp_normalizedE164FromInput:(id)input dialCode:(NSString *)dialCode
{
    NSString *raw = [self pp_trimmedString:input];
    if (raw.length == 0) return @"";

    NSString *digits = [self pp_digitsOnlyString:raw];
    if (digits.length == 0) return @"";

    NSString *dialDigits = [[self pp_trimmedString:dialCode] stringByReplacingOccurrencesOfString:@"+" withString:@""];
    if (dialDigits.length > 0) {
        if ([digits hasPrefix:dialDigits] || [raw hasPrefix:@"+"]) {
            return [NSString stringWithFormat:@"+%@", digits];
        }
        return [NSString stringWithFormat:@"+%@%@", dialDigits, digits];
    }
    return [NSString stringWithFormat:@"+%@", digits];
}

- (BOOL)pp_authUser:(FIRUser *)authUser hasProviderID:(NSString *)providerID
{
    NSString *targetProviderID = [[self pp_trimmedString:providerID] lowercaseString];
    if (!authUser || targetProviderID.length == 0) {
        return NO;
    }

    for (id<FIRUserInfo> provider in authUser.providerData) {
        NSString *candidate = [[self pp_trimmedString:provider.providerID] lowercaseString];
        if ([candidate isEqualToString:targetProviderID]) {
            return YES;
        }
    }
    return NO;
}

- (void)pp_presentPhoneVerificationForProfileMobileChange:(NSString *)newMobile
                                              completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *safePhone = [self pp_trimmedString:newMobile];
    if (safePhone.length == 0) {
        if (completion) {
            NSError *invalidPhoneError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                             code:1001
                                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_phone_required_message")}];
            completion(invalidPhoneError);
        }
        return;
    }

    [PPHUD showLoading:kLang(@"auth_sending_code_title")];

    __weak typeof(self) weakSelf = self;
    __block NSString *currentVerificationID = @"";
    void (^sendCodeToPhone)(PPVerificationResendCompletion resendCompletion) = ^(PPVerificationResendCompletion resendCompletion) {
        [[FIRPhoneAuthProvider provider] verifyPhoneNumber:safePhone
                                               UIDelegate:nil
                                               completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || verificationID.length == 0) {
                    if (resendCompletion) {
                        NSError *resolvedError = error ?: [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                              code:1002
                                                                          userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_sending_code_failed_title")}];
                        resendCompletion(NO, resolvedError);
                    }
                    return;
                }

                currentVerificationID = verificationID ?: @"";
                [[NSUserDefaults standardUserDefaults] setObject:currentVerificationID forKey:@"authVerificationID"];
                [[NSUserDefaults standardUserDefaults] synchronize];

                if (resendCompletion) {
                    resendCompletion(YES, nil);
                }
            });
        }];
    };

    sendCodeToPhone(^(BOOL success, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            if (completion) {
                NSError *deallocatedError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                code:1003
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Session expired. Please try again."}];
                completion(deallocatedError);
            }
            return;
        }

        [PPHUD dismiss];

        if (!success) {
            if (completion) {
                completion(error);
            }
            return;
        }

        PPVerificationCodeViewController *vc = [[PPVerificationCodeViewController alloc] initWithPhone:safePhone];
        vc.onCodeVerificationRequested = ^(NSString *code, PPVerificationCodeCheckCompletion codeCompletion) {
            NSString *verificationID = currentVerificationID.length
                ? currentVerificationID
                : ([[NSUserDefaults standardUserDefaults] stringForKey:@"authVerificationID"] ?: @"");
            if (verificationID.length == 0) {
                NSError *missingVerificationError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                        code:1004
                                                                    userInfo:@{NSLocalizedDescriptionKey: kLang(@"invalid_code_message")}];
                if (codeCompletion) {
                    codeCompletion(NO, missingVerificationError);
                }
                return;
            }

            FIRUser *currentAuthUser = [FIRAuth auth].currentUser;
            if (!currentAuthUser) {
                NSError *authMissingError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                code:1005
                                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"PleaseRegister")}];
                if (codeCompletion) {
                    codeCompletion(NO, authMissingError);
                }
                return;
            }

            FIRPhoneAuthCredential *credential =
            [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID
                                                         verificationCode:code ?: @""];

            [currentAuthUser updatePhoneNumberCredential:credential completion:^(NSError * _Nullable updateError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (updateError) {
                        if (codeCompletion) {
                            codeCompletion(NO, updateError);
                        }
                        return;
                    }

                    if (completion) {
                        completion(nil);
                    }
                    if (codeCompletion) {
                        codeCompletion(YES, nil);
                    }
                });
            }];
        };
        vc.onResendRequested = ^(PPVerificationResendCompletion resendCompletion) {
            sendCodeToPhone(resendCompletion);
        };

        [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyleMediumOnly];
    });
}
 
#pragma mark - Save / Update
 

- (void)updateUserData {
    if (self.isSavingProfile) {
        return;
    }

    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        [PPAlertHelper showErrorIn:self title:kLang(@"PleaseRegister") subtitle:@""];
        return;
    }

    [self.view endEditing:YES];
    NSArray *errors = [self formValidationErrors];
    if (errors.count > 0) {
        NSError *firstError = errors.firstObject;
        if (!firstError) {
            NSLog(@"❌ ProfileVC: errors.firstObject nil despite count > 0");
            [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:@""];
            return;
        }
        XLFormValidationStatus *firstErr = [firstError.userInfo objectForKey:XLValidationStatusErrorKey];
        NSIndexPath *badIndex = [self.form indexPathOfFormRow:firstErr.rowDescriptor];
        UITableViewCell *badCell = [self.tableView cellForRowAtIndexPath:badIndex];
        [self animateCell:badCell];
        [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:@""];
        return;
    }

    NSString *firstName = [self pp_trimmedString:firstNameRow.value];
    NSString *lastName = [self pp_trimmedString:LastNameRow.value];
    NSString *userName = [self pp_trimmedString:UserNameRow.value];
    NSString *userEmail = [[self pp_trimmedString:UserEmailRow.value] lowercaseString];
    NSString *about = [self pp_trimmedString:UserAboutRow.value];

    if (userName.length == 0) {
        NSString *composed = [NSString stringWithFormat:@"%@ %@", firstName ?: @"", lastName ?: @""];
        userName = [self pp_trimmedString:composed];
    }
    if (userName.length == 0) {
        [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"UserName_Palce")];
        return;
    }

    if (![self pp_isValidEmail:userEmail]) {
        [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"UserEmail_Palce")];
        return;
    }

    CountryCodeModel *country = self.selectedCountry;
    if (!country) {
        NSInteger fallbackCountryID = PPCurrentUser.CountryID;
        if (fallbackCountryID > 0) {
            country = [[self.contriesArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", fallbackCountryID]] firstObject];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:[GM getCurrentCountryFromCarrier]];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:CitiesManager.shared.CurrentCountry.iso];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
        }
    }
    if (!country && self.contriesArray.count > 0) {
        country = [self pp_qatarCountry];
    }
    if (!country || country.ID <= 0) {
        [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"SelectCountry")];
        return;
    }
    self.selectedCountry = country;
    NSString *countryDialCode = [self pp_trimmedString:country.phoneCode];
    if (countryDialCode.length > 0 && ![countryDialCode hasPrefix:@"+"]) {
        countryDialCode = [@"+" stringByAppendingString:countryDialCode];
    }
    NSString *countryISOCode = [[self pp_trimmedString:country.isoCountryCode] uppercaseString];
    if (countryDialCode.length == 0 || countryISOCode.length != 2) {
        [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"SelectCountry")];
        return;
    }

    NSString *normalizedMobile = [self pp_normalizedE164FromInput:MobileNoRow.value dialCode:countryDialCode];
    NSString *rawMobileInput = [self pp_trimmedString:MobileNoRow.value];
    NSString *existingMobile = [self pp_trimmedString:PPCurrentUser.MobileNo];
    if (rawMobileInput.length == 0 && existingMobile.length > 0) {
        NSString *fallbackDialCode = [existingMobile hasPrefix:@"+"] ? @"" : countryDialCode;
        normalizedMobile = [self pp_normalizedE164FromInput:existingMobile dialCode:fallbackDialCode];
    }
    if (rawMobileInput.length > 0 && normalizedMobile.length == 0) {
        [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"MobileNo_Palce")];
        return;
    }
    NSInteger mobileDigitsCount = [[normalizedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""] length];
    if (normalizedMobile.length > 0 && (mobileDigitsCount < 8 || mobileDigitsCount > 15)) {
        [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"MobileNo_Palce")];
        return;
    }
    if (normalizedMobile.length > 0 &&
        countryDialCode.length > 0 &&
        ![normalizedMobile hasPrefix:countryDialCode]) {
        CountryCodeModel *mobileCountry = [self pp_countryFromStoredMobileNumber:normalizedMobile];
        if (!mobileCountry) {
            [PPAlertHelper showInfoIn:self
                                title:kLang(@"PleaseFillFields")
                             subtitle:kLang(@"SelectCountry")];
            return;
        }
        self.selectedCountry = mobileCountry;
        country = mobileCountry;
        countryDialCode = [self pp_trimmedString:mobileCountry.phoneCode];
        if (countryDialCode.length > 0 && ![countryDialCode hasPrefix:@"+"]) {
            countryDialCode = [@"+" stringByAppendingString:countryDialCode];
        }
        countryISOCode = [[self pp_trimmedString:mobileCountry.isoCountryCode] uppercaseString];
        if (countryDialCode.length == 0 || countryISOCode.length != 2) {
            [PPAlertHelper showInfoIn:self
                                title:kLang(@"PleaseFillFields")
                             subtitle:kLang(@"SelectCountry")];
            return;
        }
        if (codeRow) {
            codeRow.value = mobileCountry;
            [self updateFormRow:codeRow];
        }
        [self updatePrefixForCountryCode:countryDialCode];
    }

    NSString *currentEmail = [[self pp_trimmedString:authUser.email] lowercaseString];
    NSString *baselineEmail = @"";
    id baselineEmailValue = self.profileDraftBaseline[@"userEmail"];
    if ([baselineEmailValue isKindOfClass:NSString.class]) {
        baselineEmail = [[self pp_trimmedString:baselineEmailValue] lowercaseString];
    }
    BOOL emailFieldEdited = ![userEmail isEqualToString:baselineEmail];
    if (userEmail.length == 0) {
        userEmail = currentEmail;
    }
    BOOL emailChanged = emailFieldEdited && ![userEmail isEqualToString:currentEmail];
    if (emailChanged) {
        NSString *authProviderID = @"";
        for (id<FIRUserInfo> provider in authUser.providerData) {
            NSString *providerID = [[self pp_trimmedString:provider.providerID] lowercaseString];
            if (providerID.length == 0 || [providerID isEqualToString:@"firebase"]) {
                continue;
            }
            authProviderID = providerID;
            break;
        }

        if ([authProviderID isEqualToString:@"google.com"] || [authProviderID isEqualToString:@"apple.com"]) {
            [PPAlertHelper showWarningIn:self
                                   title:kLang(@"UserEmail_Palce")
                                subtitle:kLang(@"profile_email_managed_by_provider")];
            return;
        }

        if ([authProviderID isEqualToString:@"password"]) {
            [PPAlertHelper showWarningIn:self
                                   title:kLang(@"UserEmail_Palce")
                                subtitle:kLang(@"profile_email_reauth_required")];
            return;
        }
    }

    NSString *existingAuthMobile = [self pp_trimmedString:authUser.phoneNumber];
    NSString *baselineMobileForCompare = existingAuthMobile.length > 0 ? existingAuthMobile : existingMobile;
    NSString *baselineDialHint = [baselineMobileForCompare hasPrefix:@"+"] ? @"" : countryDialCode;
    NSString *baselineNormalizedMobile = [self pp_normalizedE164FromInput:baselineMobileForCompare
                                                                 dialCode:baselineDialHint];
    NSString *draftBaselineLocalMobile = @"";
    id draftBaselineMobileValue = self.profileDraftBaseline[@"mobileLocal"];
    if ([draftBaselineMobileValue isKindOfClass:NSString.class]) {
        draftBaselineLocalMobile = [self pp_trimmedString:draftBaselineMobileValue];
    }
    NSString *draftBaselineRawMobile = draftBaselineLocalMobile.length > 0 ? draftBaselineLocalMobile : existingMobile;
    NSString *draftBaselineDialHint = draftBaselineRawMobile.length > 0 && ![draftBaselineRawMobile hasPrefix:@"+"]
        ? countryDialCode
        : @"";
    NSString *draftBaselineNormalizedMobile = [self pp_normalizedE164FromInput:draftBaselineRawMobile
                                                                      dialCode:draftBaselineDialHint];
    BOOL mobileFieldEdited = ![normalizedMobile isEqualToString:draftBaselineNormalizedMobile];
    BOOL editedDataIncludesMobileNumber =
        (self.formDataArray[@"MobileNo"] != nil) ||
        (self.formDataArray[kMobileNoRow] != nil);
    BOOL mobileChanged = mobileFieldEdited &&
                         (normalizedMobile.length > 0) &&
                         ![normalizedMobile isEqualToString:baselineNormalizedMobile];
    BOOL authUsesPhoneProvider = [self pp_authUser:authUser hasProviderID:@"phone"];

    NSMutableDictionary<NSString *, id> *updates = [NSMutableDictionary dictionary];
    updates[@"FirstName"] = firstName ?: @"";
    updates[@"LastName"] = lastName ?: @"";
    updates[@"UserName"] = userName;
    updates[@"UserAbout"] = about ?: @"";
    updates[@"CountryID"] = @(country.ID);
    updates[@"CountryName"] = country.country ?: @"";
    updates[@"CountryDialCode"] = countryDialCode;
    updates[@"CountryIsoCode"] = countryISOCode;
    if (normalizedMobile.length > 0) {
        updates[@"MobileNo"] = normalizedMobile;
    }
    if (emailChanged) {
        updates[@"UserEmail"] = userEmail ?: @"";
        updates[@"email"] = userEmail ?: @"";
    }
    updates[FUUpdateKeyDisplayName] = userName;

    __weak typeof(self) weakSelf = self;
    void (^commitUpdates)(void) = ^{
        [UsrMgr updateCurrentUserProfileWithValues:updates completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                [self pp_setProfileSaving:NO];
                [PPHUD dismiss];

                if (error) {
                    NSLog(@"❌ Profile update failed: %@", error.localizedDescription);
                    [PPAlertHelper showErrorIn:self
                                         title:kLang(@"StatusSaveFailed")
                                      subtitle:error.localizedDescription ?: @""];
                    return;
                }

                [UsrMgr reloadCurrentUserWithCompletion:^(UserModel * _Nullable user, NSError * _Nullable loadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (user && !loadError) {
                            [UsrMgr cacheUser:user];
                        }
                        self.pendingAvatarImage = nil;
                        [self.formDataArray removeAllObjects];
                        [self pp_captureProfileDraftBaseline];
                        [PPHUD showSuccess:kLang(@"Saved")];
                        [self pp_refreshRightNavSaveState];
                    });
                }];
            });
        }];
    };

    void (^performSavePipeline)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self pp_setProfileSaving:YES];
        [PPHUD showLoading:kLang(@"Saving")];

        if (self.pendingAvatarImage) {
            [self uploadAvatar:self.pendingAvatarImage
                     forUserID:authUser.uid
                    completion:^(NSURL * _Nullable url, NSError * _Nullable err) {
                if (url.absoluteString.length > 0) {
                    updates[FUUpdateKeyPhotoURL] = url.absoluteString;
                    updates[@"UserImageUrl"] = url.absoluteString;
                    updates[@"photoURL"] = url.absoluteString;
                } else if (err) {
                    NSLog(@"⚠️ Avatar upload failed; continuing profile update without new avatar: %@", err.localizedDescription);
                }
                commitUpdates();
            }];
            return;
        }

        commitUpdates();
    };

    if (authUsesPhoneProvider && editedDataIncludesMobileNumber && mobileChanged) {
        [self pp_presentPhoneVerificationForProfileMobileChange:normalizedMobile completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                if (error) {
                    [PPAlertHelper showErrorIn:self
                                         title:kLang(@"StatusSaveFailed")
                                      subtitle:error.localizedDescription ?: @""];
                    return;
                }

                if (PPCurrentUser) {
                    PPCurrentUser.MobileNo = normalizedMobile;
                }
                performSavePipeline();
            });
        }];
        return;
    }

    performSavePipeline();
}

 
#pragma mark - Avatar upload helper

- (void)uploadAvatar:(UIImage *)image
           forUserID:(NSString *)userID
          completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion
{
    if (!image || userID.length == 0) {
        if (completion) completion(nil, [NSError errorWithDomain:@"app.profile"
                                                            code:-1
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Missing image or user id"}]);
        return;
    }
    
    // Compress to a sane size (~75–85% quality)
    NSData *jpeg = UIImageJPEGRepresentation(image, 0.82);
    if (!jpeg) {
        if (completion) completion(nil, [NSError errorWithDomain:@"app.profile"
                                                            code:-2
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Could not encode image"}]);
        return;
    }
    
    // Path: users/{uid}/avatar_{timestamp}.jpg
    NSString *fileName = [NSString stringWithFormat:@"avatar_%@", @((long long)(NSDate.date.timeIntervalSince1970 * 1000))];
    NSString *path = [NSString stringWithFormat:@"users/%@/%@.jpg", userID, fileName];
    
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *ref = [[storage reference] child:path];
    
    FIRStorageMetadata *meta = [FIRStorageMetadata new];
    meta.contentType = @"image/jpeg";
    
    [ref putData:jpeg metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error2) {
            if (completion) completion(URL, error2);
        }];
    }];
}


- (BOOL)navigationShouldPopOnBackButton {
    if (self.showingSave) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Confirm")
                                                                       message:kLang(@"changes_not_saved")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Discard")
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction * _Nonnull action) {
            self.showingSave = NO;
            [self.navigationController popViewControllerAnimated:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return NO; // stop automatic pop
    }
    return YES;
}


- (void)onBack
{
    //[GM clearImagesDiskCache];
    if (self.showingSave)
    {
        NSLog(@"[Addresses] showingSave → Stay here & ask confirmation");

        [PPAlertHelper showConfirmationIn:self
                                    title:kLang(@"unsaved_changes_title")        // "Unsaved changes"
                                 subtitle:kLang(@"unsaved_changes_message")      // "You have unsaved changes. Do you want to leave without saving?"
                            confirmButton:kLang(@"leave_button")                 // "Leave"
                             cancelButton:kLang(@"stay_button")
                                     icon:nil// "Stay"
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if(!didConfirm) return;
            // 🔴 User chose "Leave" → go back
            [super onBack];
        }
                               cancelBlock:^{
            // 🟢 User chose "Stay" → do nothing
            NSLog(@"[Addresses] Stay pressed → remain on screen");
        }];
    }
    else
    {
        [super onBack];
    }
}
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return section == 2 ? 40 : 0.000001;    //if(indexPath.section == 0) return 56;
}

 

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {

    return 0.000001; // no footer space
}

-(UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return 0.000001;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return 0.000001;
}

@end
