 

//
//  PPCompleteProfileVC.m – Version 3.0 (Clean Architecture)
//  Pure Pets
//

#import "PPCompleteProfileVC.h"
#import "PPPermissionHelper.h"
#import <PhotosUI/PhotosUI.h>
#import "PhoneNumberCell.h"
#import "UserModel.h"
#import "UserManager.h"
#import "CitiesManager.h"
#import "CountryModel.h"
#import "PPModernAvatarRenderer.h"

@interface PPCompleteProfileVC ()<UIAdaptivePresentationControllerDelegate>

@property (nonatomic, strong) UIView *backgroundTopGlowView;
@property (nonatomic, strong) UIView *backgroundBottomGlowView;
@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) UIImageView *avatarIMV;
@property (nonatomic, strong) UIImage *avatarPlaceholderImage;
@property (nonatomic, strong) UIButton *addPhotoBtn;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIView *progressPillView;
@property (nonatomic, strong) UIImageView *progressPillIconView;
@property (nonatomic, strong) UILabel *progressPillLabel;

@property (nonatomic, strong) UIButton *saveBTN;
@property (nonatomic, strong) UIButton *skipBTN;

@property (nonatomic, assign) BOOL didlayout;
@property (nonatomic, assign) BOOL didAnimateIntro;

@end


#pragma mark - Initializer
@implementation PPCompleteProfileVC

- (instancetype)initWithUser:(UserModel *)user {
    self = [super init];
    if (self) {
        _editingUser = user;
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"Use initWithUser: instead");
    return [self initWithUser:nil];
}

+ (UITableViewStyle)formTableViewStyle {
    return UITableViewStyleInsetGrouped;
}

- (void)pp_updateHeaderLayoutForWidth:(CGFloat)width {
    if (width <= 0.0 || !self.headerRoot) {
        return;
    }

    CGSize targetSize = CGSizeMake(width, UILayoutFittingCompressedSize.height);
    CGSize headerSize = [self.headerRoot systemLayoutSizeFittingSize:targetSize
                      withHorizontalFittingPriority:UILayoutPriorityRequired
                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat resolvedHeight = MAX(1.0, ceil(headerSize.height));

    if (fabs(self.headerRoot.frame.size.width - width) > 1.0 ||
        fabs(self.headerRoot.frame.size.height - resolvedHeight) > 1.0) {
        self.headerRoot.frame = CGRectMake(0, 0, width, resolvedHeight);
        self.tableView.tableHeaderView = self.headerRoot;
    }
}

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];

    self.didlayout = NO;
    self.view.backgroundColor = PPBackgroundColorForIOS26([AppBackgroundClr colorWithAlphaComponent:0.9]);
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.sectionHeaderHeight = 12.0;
    self.tableView.sectionFooterHeight = 8.0;
    self.view.layer.cornerRadius = 42;
    self.view.clipsToBounds = YES;

    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.backgroundTopGlowView];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.backgroundBottomGlowView];

    [self setupTopBar];
    [self setupHeaderUI];
    [self buildForm];
    
    
}

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController {
    return NO;
}

#pragma mark - Top Bar
- (void)setupTopBar {

    UIView *topBar = [UIView new];
    topBar.backgroundColor = UIColor.clearColor;
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:topBar];

    UIButtonConfiguration *glassConfig;
    if (@available(iOS 26.0, *)) {
        glassConfig = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        glassConfig = [UIButtonConfiguration filledButtonConfiguration];
    }

    self.saveBTN = [PPButtonHelper pp_buttonWithTitle:kLang(@"save")
                                                 font:[GM boldFontWithSize:17]
                                            textColor:AppPrimaryClr
                                              corners:22
                                            imageName:@"checkmark"
                                               target:self
                                               config:glassConfig
                                              btnSize:44
                                               action:@selector(saveTapped)];

    self.skipBTN = [PPButtonHelper pp_buttonWithTitle:kLang(@"Skip")
                                                 font:[GM boldFontWithSize:17]
                                            textColor:AppPrimaryClr
                                              corners:22
                                            imageName:@"xmark"
                                               target:self
                                               config:glassConfig
                                              btnSize:44
                                               action:@selector(onDismiss)];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kLang(@"Complete_Profile");
    titleLabel.font = [GM boldFontWithSize:20];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.saveBTN.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    self.skipBTN.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.10 : 0.80];
    [self.saveBTN setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.skipBTN setTitleColor:UIColor.secondaryLabelColor forState:UIControlStateNormal];

    self.saveBTN.translatesAutoresizingMaskIntoConstraints = NO;
    self.skipBTN.translatesAutoresizingMaskIntoConstraints = NO;

    [topBar addSubview:self.saveBTN];
    [topBar addSubview:self.skipBTN];
    [topBar addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [topBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [topBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [topBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [topBar.heightAnchor constraintEqualToConstant:60],

        [self.saveBTN.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.saveBTN.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [self.saveBTN.heightAnchor constraintEqualToConstant:44],

        [self.skipBTN.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.skipBTN.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [self.skipBTN.heightAnchor constraintEqualToConstant:44],

        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
    ]];
}
- (UIColor *)pp_selectedCellColorFromPrimary {
    UIColor *baseColor = [UIColor colorWithRed:0.698 green:0.106 blue:0.282 alpha:1.0]; // #B21B48
    CGFloat hue, sat, bright, alpha;
    [baseColor getHue:&hue saturation:&sat brightness:&bright alpha:&alpha];
    // lighten slightly and add transparency
    return [UIColor colorWithHue:hue saturation:sat brightness:MIN(bright + 0.2, 1.0) alpha:0.82];
}
#pragma mark - Header UI
- (void)setupHeaderUI {

    self.headerRoot = [[UIView alloc] init];
    self.headerRoot.backgroundColor = UIColor.clearColor;
    self.headerRoot.translatesAutoresizingMaskIntoConstraints = NO;

    self.heroCardView = [[UIView alloc] init];
    self.heroCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.58 : 0.98];
    self.heroCardView.layer.cornerRadius = 30.0;
    self.heroCardView.layer.masksToBounds = YES;
    [self.headerRoot addSubview:self.heroCardView];

    self.progressPillView = [[UIView alloc] init];
    self.progressPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressPillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.14 : 0.82];
    self.progressPillView.layer.cornerRadius = 18.0;
    self.progressPillView.layer.masksToBounds = YES;
    [self.heroCardView addSubview:self.progressPillView];

    self.progressPillIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill"]];
    self.progressPillIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressPillIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.progressPillIconView.tintColor = AppPrimaryClr;
    [self.progressPillView addSubview:self.progressPillIconView];

    self.progressPillLabel = [[UILabel alloc] init];
    self.progressPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressPillLabel.font = [GM boldFontWithSize:13];
    self.progressPillLabel.textColor = UIColor.labelColor;
    [self.progressPillView addSubview:self.progressPillLabel];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.text = kLang(@"Complete_Profile");
    self.heroTitleLabel.font = [GM boldFontWithSize:24];
    self.heroTitleLabel.textColor = UIColor.labelColor;
    self.heroTitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.heroCardView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.text = kLang(@"auth_complete_profile_subtitle");
    self.heroSubtitleLabel.font = [GM MidFontWithSize:14];
    self.heroSubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.heroSubtitleLabel.numberOfLines = 0;
    [self.heroCardView addSubview:self.heroSubtitleLabel];

    // Avatar
    self.avatarPlaceholderImage = [PPModernAvatarRenderer avatarImageForName:self.editingUser.UserName size:110];
    self.avatarIMV = [[UIImageView alloc] initWithImage:self.avatarPlaceholderImage];
    self.avatarIMV.backgroundColor = UIColor.clearColor;
    self.avatarIMV.layer.cornerRadius = 55;
    self.avatarIMV.clipsToBounds = YES;
    self.avatarIMV.userInteractionEnabled = YES;
    self.avatarIMV.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarIMV.contentMode = UIViewContentModeScaleAspectFill;
    if (self.editingUser.UserImageUrl.absoluteString.length > 5) {
        [GM setImageFromUrlString:PPSafeString(self.editingUser.UserImageUrl.absoluteString)
                        imageView:self.avatarIMV
                          phImage:@"person.crop.circle.fill" completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
            
            [self.addPhotoBtn setTitle:kLang(@"Tap_To_Change_Photo") forState:UIControlStateNormal];

        }];
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(didTapAddPhoto)];
    [self.avatarIMV addGestureRecognizer:tap];
 
    [self.heroCardView addSubview:self.avatarIMV];

    // Add Photo Button
    self.addPhotoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.addPhotoBtn setTitle:kLang(@"Add_Photo") forState:UIControlStateNormal];
    self.addPhotoBtn.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    self.addPhotoBtn.titleLabel.font = [GM MidFontWithSize:16];
    self.addPhotoBtn.layer.cornerRadius = 22;
    self.addPhotoBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addPhotoBtn addTarget:self
                         action:@selector(didTapAddPhoto)
               forControlEvents:UIControlEventTouchUpInside];
    self.addPhotoBtn.titleLabel.textColor =  AppForgroundColr;
    self.addPhotoBtn.configuration.baseForegroundColor =  AppForgroundColr;
    [self.addPhotoBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.heroCardView addSubview:self.addPhotoBtn];

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [self.heroCardView.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:12],
        [self.heroCardView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:16],
        [self.heroCardView.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-16],
        [self.heroCardView.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-10],

        [self.progressPillView.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:18],
        [self.progressPillView.centerXAnchor constraintEqualToAnchor:self.heroCardView.centerXAnchor],

        [self.progressPillIconView.leadingAnchor constraintEqualToAnchor:self.progressPillView.leadingAnchor constant:12],
        [self.progressPillIconView.centerYAnchor constraintEqualToAnchor:self.progressPillView.centerYAnchor],
        [self.progressPillIconView.widthAnchor constraintEqualToConstant:14],
        [self.progressPillIconView.heightAnchor constraintEqualToConstant:14],

        [self.progressPillLabel.leadingAnchor constraintEqualToAnchor:self.progressPillIconView.trailingAnchor constant:8],
        [self.progressPillLabel.trailingAnchor constraintEqualToAnchor:self.progressPillView.trailingAnchor constant:-14],
        [self.progressPillLabel.topAnchor constraintEqualToAnchor:self.progressPillView.topAnchor constant:10],
        [self.progressPillLabel.bottomAnchor constraintEqualToAnchor:self.progressPillView.bottomAnchor constant:-10],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:self.progressPillView.bottomAnchor constant:18],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:20],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-20],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:8],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:24],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-24],

        [self.avatarIMV.topAnchor constraintEqualToAnchor:self.heroSubtitleLabel.bottomAnchor constant:22],
        [self.avatarIMV.centerXAnchor constraintEqualToAnchor:self.heroCardView.centerXAnchor],
        [self.avatarIMV.widthAnchor constraintEqualToConstant:115],
        [self.avatarIMV.heightAnchor constraintEqualToConstant:110],

        [self.addPhotoBtn.topAnchor constraintEqualToAnchor:self.avatarIMV.bottomAnchor constant:16],
        [self.addPhotoBtn.centerXAnchor constraintEqualToAnchor:self.heroCardView.centerXAnchor],
        [self.addPhotoBtn.widthAnchor constraintGreaterThanOrEqualToConstant:176],
        [self.addPhotoBtn.heightAnchor constraintEqualToConstant:44],
        [self.addPhotoBtn.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:-22]
    ]];

    self.tableView.tableHeaderView = self.headerRoot;
    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];
    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) {
        headerWidth = CGRectGetWidth(self.view.bounds);
    }
    [self pp_updateHeaderLayoutForWidth:headerWidth];
    
    self.tableView.contentInset = UIEdgeInsetsMake(76, 0, 24, 0);
    [self updateProfileProgressUI];
 
}

#pragma mark - Build Form
- (void)buildForm {

    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:kLang(@"Complete_Profile")];

    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];

    // Username
    XLFormRowDescriptor *usernameRow =
    [self fullTextRow:@"userName"
                 title:kLang(@"UserName_Palce")
          placeholder:kLang(@"UserName_Palce")
               value:self.editingUser.UserName];
    usernameRow.height = 54;
    usernameRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        self.editingUser.UserName = newValue;
        [self updateProfileProgressUI];
    };

    [section addFormRow:usernameRow];

    // First name
    XLFormRowDescriptor *firstRow =
    [self fullTextRow:@"firstName"
                 title:kLang(@"firstName_Palce")
          placeholder:kLang(@"Enter_First_Name")
               value:self.editingUser.FirstName];

    firstRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        self.editingUser.FirstName = newValue;
        [self updateProfileProgressUI];
    };
    firstRow.height = 54;
    [section addFormRow:firstRow];

    // Last name
    XLFormRowDescriptor *lastRow =
    [self fullTextRow:@"lastName"
                 title:kLang(@"LastName_Palce")
          placeholder:kLang(@"Enter_Last_Name")
               value:self.editingUser.LastName];
    lastRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        self.editingUser.LastName = newValue;
        [self updateProfileProgressUI];
    };
    lastRow.height = 54;
    [section addFormRow:lastRow];

     
    // Email
    XLFormRowDescriptor *emailRow =
    [XLFormRowDescriptor formRowDescriptorWithTag:@"UserEmail"
                                          rowType:XLFormRowDescriptorTypeEmail
                                            title:kLang(@"UserEmail_Palce")];
    emailRow.value = self.editingUser.UserEmail;
    emailRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        self.editingUser.UserEmail = newValue;
        [self updateProfileProgressUI];
    };
    emailRow.height = 54;
    [section addFormRow:emailRow];

    // About
    XLFormRowDescriptor *aboutRow =
    [XLFormRowDescriptor formRowDescriptorWithTag:@"about"
                                          rowType:XLFormRowDescriptorTypeTextView
                                            title:kLang(@"UserAbout_Palce")];

    aboutRow.value = self.editingUser.UserAbout;
    aboutRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        self.editingUser.UserAbout = newValue;
    };
    //[section addFormRow:aboutRow];

    
    self.contriesArray = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    self.selectedCountry = [self pp_resolveAutomaticCountryFromCountries:self.contriesArray];
    if (self.selectedCountry.ID > 0) {
        self.editingUser.CountryID = self.selectedCountry.ID;
    }

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    // Row with selector (XLFormRowDescriptorTypeSelectorPush)
    XLFormRowDescriptor *codeRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"codeRow"
                                                                         rowType:XLFormRowDescriptorTypeSelectorActionSheet title:kLang(@"code_Palce")];
    codeRow.selectorOptions = self.contriesArray;// Options to display in the selector
    codeRow.value = self.selectedCountry;
    __weak typeof(self) weakSelf = self;
    codeRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        if (![newValue isKindOfClass:[CountryCodeModel class]]) {
            return;
        }
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.selectedCountry = (CountryCodeModel *)newValue;
        self.editingUser.CountryID = self.selectedCountry.ID;
        [self updateProfileProgressUI];
    };
    codeRow.height = 54;
    [section addFormRow:codeRow];
    
    self.form = form;
}

- (void)updateProfileProgressUI {
    NSInteger completed = 0;
    NSInteger total = 5;

    NSString *username = [PPSafeString(self.editingUser.UserName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *firstName = [PPSafeString(self.editingUser.FirstName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lastName = [PPSafeString(self.editingUser.LastName) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *email = [PPSafeString(self.editingUser.UserEmail) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (username.length >= 3) completed += 1;
    if (firstName.length > 0) completed += 1;
    if (lastName.length > 0) completed += 1;
    if (email.length > 0) completed += 1;
    if (self.editingUser.CountryID > 0 || self.selectedCountry.ID > 0) completed += 1;

    self.progressPillLabel.text = [NSString stringWithFormat:kLang(@"auth_profile_progress_format"), (long)completed, (long)total];
    self.progressPillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.14 : 0.82];
}

#pragma mark - Helpers
- (CountryCodeModel *)pp_countryWithID:(NSInteger)countryID
                            inCountries:(NSArray<CountryCodeModel *> *)countries {
    if (countryID <= 0 || countries.count == 0) {
        return nil;
    }
    for (CountryCodeModel *country in countries) {
        if (country.ID == countryID) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryWithISOCode:(NSString *)isoCode
                                 inCountries:(NSArray<CountryCodeModel *> *)countries {
    if (isoCode.length == 0 || countries.count == 0) {
        return nil;
    }
    NSString *normalizedISO = isoCode.uppercaseString;
    for (CountryCodeModel *country in countries) {
        if ([country.isoCountryCode.uppercaseString isEqualToString:normalizedISO]) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryWithPhoneCode:(NSString *)phoneCode
                                   inCountries:(NSArray<CountryCodeModel *> *)countries {
    NSString *normalizedCode = [[(phoneCode ?: @"")
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (normalizedCode.length == 0 || countries.count == 0) {
        return nil;
    }
    if (![normalizedCode hasPrefix:@"+"]) {
        normalizedCode = [@"+" stringByAppendingString:normalizedCode];
    }
    for (CountryCodeModel *country in countries) {
        NSString *candidate = country.phoneCode ?: @"";
        if (![candidate hasPrefix:@"+"] && candidate.length > 0) {
            candidate = [@"+" stringByAppendingString:candidate];
        }
        if ([candidate isEqualToString:normalizedCode]) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_resolveAutomaticCountryFromCountries:(NSArray<CountryCodeModel *> *)countries {
    if (countries.count == 0) {
        return nil;
    }

    CountryCodeModel *resolved = nil;
    NSInteger explicitCountryID = self.editingUser.CountryID > 0 ? self.editingUser.CountryID : PPCurrentUser.CountryID;
    if (explicitCountryID > 0) {
        resolved = [self pp_countryWithID:explicitCountryID inCountries:countries];
    }

    CountryModel *currentCountry = CitiesManager.shared.CurrentCountry;
    NSString *carrierISO = [GM getCurrentCountryFromCarrier];
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:PPSafeString(carrierISO)
                                   inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:PPSafeString(currentCountry.iso)
                                   inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithPhoneCode:PPSafeString(currentCountry.countryCode)
                                     inCountries:countries];
    }
    if (!resolved) {
        NSString *localeISO = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        resolved = [self pp_countryWithISOCode:PPSafeString(localeISO)
                                   inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:@"QA" inCountries:countries];
    }
    return resolved ?: countries.firstObject;
}

- (XLFormRowDescriptor *)fullTextRow:(NSString *)tag
                               title:(NSString *)title
                        placeholder:(NSString *)placeholder
                             value:(NSString *)value {

    XLFormRowDescriptor *row =
    [XLFormRowDescriptor formRowDescriptorWithTag:tag
                                          rowType:XLFormRowDescriptorTypeText
                                            title:title];

    [row.cellConfigAtConfigure setObject:placeholder forKey:@"textField.placeholder"];
    [row.cellConfig setObject:[GM MidFontWithSize:16] forKey:@"textLabel.font"];
    [row.cellConfig setObject:AppSecondaryTextClr forKey:@"textField.textColor"];

    row.value = value;
 
    return row;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;

    UIView *background = [[UIView alloc] initWithFrame:CGRectInset(cell.bounds, 12.0, 4.0)];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.58 : 0.98];
    background.layer.cornerRadius = 18.0;
    background.layer.masksToBounds = YES;
    [Styling addLiquidGlassBorderToView:background cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.16]];
    cell.backgroundView = background;

    UIView *selectedBackground = [[UIView alloc] initWithFrame:background.bounds];
    selectedBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    selectedBackground.backgroundColor = [[self pp_selectedCellColorFromPrimary] colorWithAlphaComponent:0.22];
    selectedBackground.layer.cornerRadius = 18.0;
    selectedBackground.layer.masksToBounds = YES;
    cell.selectedBackgroundView = selectedBackground;
}

#pragma mark - Save
- (void)saveTapped {

    [PPHUD showLoading:kLang(@"saving")];

    [self uploadAvatarIfNeeded:^{
        [self saveUserModel];
    }];
}

- (void)saveUserModel {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        [PPHUD dismiss];
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:kLang(@"auth_error_title")
                                            message:kLang(@"error_not_signed_in")
                                     preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ok_button")
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *firstName = [PPSafeString(self.editingUser.FirstName)
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lastName = [PPSafeString(self.editingUser.LastName)
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *userName = [PPSafeString(self.editingUser.UserName)
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (userName.length == 0) {
        NSString *derived = [[NSString stringWithFormat:@"%@ %@", firstName ?: @"", lastName ?: @""]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        userName = derived.length > 0 ? derived : @"User";
    }

    NSString *email = [PPSafeString(self.editingUser.UserEmail)
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
    NSString *currentAuthEmail = [PPSafeString(authUser.email)
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
    if (email.length == 0) {
        email = currentAuthEmail;
    }
    if (email.length > 0 && ![email isEqualToString:currentAuthEmail]) {
        [PPHUD dismiss];
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:kLang(@"auth_error_title")
                                            message:kLang(@"Please reauthenticate before changing email.")
                                     preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ok_button")
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSMutableDictionary<NSString *, id> *updates = [NSMutableDictionary dictionary];
    updates[@"FirstName"] = firstName ?: @"";
    updates[@"LastName"] = lastName ?: @"";
    updates[@"UserName"] = userName;
    updates[FUUpdateKeyDisplayName] = userName;
    updates[@"UserAbout"] = [PPSafeString(self.editingUser.UserAbout)
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    if (email.length > 0) {
        updates[@"UserEmail"] = email;
    }
    if (self.editingUser.CountryID > 0) {
        updates[@"CountryID"] = @(self.editingUser.CountryID);
    }
    if (self.selectedCountry.country.length > 0) {
        updates[@"CountryName"] = self.selectedCountry.country;
    }
    if (self.selectedCountry.phoneCode.length > 0) {
        updates[@"CountryDialCode"] = self.selectedCountry.phoneCode;
    }
    if (self.selectedCountry.isoCountryCode.length > 0) {
        updates[@"CountryIsoCode"] = self.selectedCountry.isoCountryCode;
    }
    if (self.editingUser.UserImageUrl.absoluteString.length > 0) {
        updates[FUUpdateKeyPhotoURL] = self.editingUser.UserImageUrl.absoluteString;
        updates[@"UserImageUrl"] = self.editingUser.UserImageUrl.absoluteString;
    }

    [UsrMgr updateCurrentUserProfileWithValues:updates completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];

            if (error) {
                UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:kLang(@"auth_error_title")
                                                    message:error.localizedDescription.length ? error.localizedDescription : kLang(@"Unable to save profile. Please try again.")
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ok_button")
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }

            [UsrMgr reloadCurrentUserWithCompletion:^(UserModel * _Nullable user, NSError * _Nullable reloadError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UserModel *resolvedUser = user ?: self.editingUser;
                    if (resolvedUser && !reloadError) {
                        [UsrMgr cacheUser:resolvedUser];
                    }
                    if (self.onProfileCompleted) {
                        self.onProfileCompleted(resolvedUser);
                    }
                    [self dismissViewControllerAnimated:YES completion:nil];
                });
            }];
        });
    }];
}

#pragma mark - Avatar Upload
- (void)uploadAvatarIfNeeded:(void(^)(void))completion {

    if (!self.avatarIMV.image ||
        self.avatarIMV.image == self.avatarPlaceholderImage) {
        if (completion) {
            completion();
        }
        return;
    }

    UIImage *finalImage = self.avatarIMV.image;
    NSData *data = UIImageJPEGRepresentation(finalImage, 0.8);
    if (data.length == 0) {
        if (completion) {
            completion();
        }
        return;
    }
    
    NSString *userID = self.editingUser.ID;
    if (userID.length == 0) {
        if (completion) {
            completion();
        }
        return;
    }

    FIRStorageReference *storageRef =
    [[[FIRStorage storage] reference] child:
     [NSString stringWithFormat:@"UsersCol/%@/avatar.jpg", userID]];

    [storageRef putData:data
               metadata:nil
             completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {

        if (error) {
            if (completion) {
                completion(); // Still allow profile save
            }
            return;
        }

        [storageRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
            if (!error && URL) {
                self.editingUser.UserImageUrl = URL;
                PPCurrentUser.UserImageUrl = URL;
            }
            if (completion) {
                completion();
            }
        }];
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat topGlowSize = MIN(220.0, width * 0.48);
    CGFloat bottomGlowSize = MIN(200.0, width * 0.44);
    self.backgroundTopGlowView.frame = CGRectMake(-36.0, self.view.safeAreaInsets.top + 8.0, topGlowSize, topGlowSize);
    self.backgroundBottomGlowView.frame = CGRectMake(width - bottomGlowSize + 28.0, MAX(height * 0.56, 360.0), bottomGlowSize, bottomGlowSize);
    self.backgroundTopGlowView.layer.cornerRadius = topGlowSize * 0.5;
    self.backgroundBottomGlowView.layer.cornerRadius = bottomGlowSize * 0.5;
    self.backgroundTopGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.10];
    self.backgroundBottomGlowView.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:PPIOS26() ? 0.10 : 0.07];

    [self.headerRoot layoutIfNeeded];
    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) {
        headerWidth = width;
    }
    [self pp_updateHeaderLayoutForWidth:headerWidth];

    [Styling addLiquidGlassBorderToView:self.heroCardView cornerRadius:30 color:[[UIColor whiteColor] colorWithAlphaComponent:0.18]];
    [Styling addLiquidGlassBorderToView:self.progressPillView cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.18]];
    [Styling addLiquidGlassBorderToView:self.avatarIMV cornerRadius:55 color:[[UIColor whiteColor] colorWithAlphaComponent:0.24]];
    [Styling addLiquidGlassBorderToView:self.addPhotoBtn cornerRadius:22 color:[[UIColor whiteColor] colorWithAlphaComponent:0.10]];
    [Styling addLiquidGlassBorderToView:self.saveBTN cornerRadius:22 color:[[UIColor whiteColor] colorWithAlphaComponent:0.10]];
    [Styling addLiquidGlassBorderToView:self.skipBTN cornerRadius:22 color:[[UIColor whiteColor] colorWithAlphaComponent:0.16]];

    if (!self.didAnimateIntro) {
        self.didAnimateIntro = YES;
        NSArray<UIView *> *animatedViews = @[self.heroCardView ?: UIView.new, self.tableView ?: UIView.new];
        [animatedViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
            view.alpha = 0.0;
            view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
            [UIView animateWithDuration:0.55
                                  delay:0.05 * idx
                 usingSpringWithDamping:0.88
                  initialSpringVelocity:0.16
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
            (void)stop;
        }];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
 [[NSNotificationCenter defaultCenter] addObserver:self
                                          selector:@selector(keyboardWillShow:)
                                              name:UIKeyboardWillShowNotification
                                            object:nil];

 [[NSNotificationCenter defaultCenter] addObserver:self
                                          selector:@selector(keyboardWillHide:)
                                              name:UIKeyboardWillHideNotification
                                            object:nil];
 
}


- (void)keyboardWillShow:(NSNotification *)note {
 // Preserve exact background color
 self.view.backgroundColor = PPBackgroundColorForIOS26([AppBackgroundClr  colorWithAlphaComponent:1.0]);
 // Prevent automatic safe-area and blur changes
 if (@available(iOS 13.0, *)) {
      self.sheetPresentationController.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
 }
}

- (void)keyboardWillHide:(NSNotification *)note {
 self.view.backgroundColor = PPBackgroundColorForIOS26([AppForgroundColr colorWithAlphaComponent:0.0]);
}
-(void)viewWillDisappear:(BOOL)animated
{
 [super viewWillDisappear:animated];
 [PPHUD dismiss];
 [[NSNotificationCenter defaultCenter] removeObserver:self];
}
#pragma mark - Avatar Picker
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
        self.avatarIMV.image = image;
        self.avatarIMV.tintColor = nil;
        self.avatarIMV.backgroundColor = UIColor.clearColor;
    }
                    completion:nil];

    [PPFunc triggerLightHaptic];
}

#pragma mark - Skip
- (void)onDismiss {
    if (self.onProfileCompleted) {
        self.onProfileCompleted(self.editingUser);
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
