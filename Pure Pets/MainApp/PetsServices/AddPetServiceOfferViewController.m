//
//  AddPetServiceOfferViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//  [GM topPadding] + self.navigationController.navigationBar.hx_h

//  AddPetServiceOfferViewController.m
//  Pure Pets

#import "AddPetServiceOfferViewController.h"
#import "ServicesManager.h"
#import "UserManager.h"
#import "UserModel.h"
#import "PPPermissionHelper.h"
#import "PPRolePermission.h"
#import <Photos/Photos.h>
#import <FirebaseAuth/FirebaseAuth.h>

@interface AddPetServiceOfferViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) CategoryModel *selectedCategory;
@property (nonatomic, strong) FCAlertView *alertDone;
@property (nonatomic, strong) CCActivityHUD *activityHUD;

@property (strong, nonatomic) XLFormRowDescriptor *titleRow;
@property (strong, nonatomic) XLFormRowDescriptor *descRow;
@property (strong, nonatomic) XLFormRowDescriptor *priceRow;
@property (strong, nonatomic) XLFormRowDescriptor *categoryRow;
@property (strong, nonatomic) XLFormRowDescriptor *dateRow;
@property (nonatomic, assign) BOOL isSubmittingService;
@property (nonatomic, assign) BOOL hasHandledLiveBlockedState;

@end

@implementation AddPetServiceOfferViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"إضافة عرض خدمة";
    self.view.backgroundColor = PPBackgroundColorForIOS26([GM backOffwhileColor]);
    [self initializeForm];

    self.view.layer.cornerRadius = 25;
    self.view.clipsToBounds = YES;

    UIFont *font = [GM MidFontWithSize:16];
 

    UIButton *customButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customButton setTitle:@"إغلاق" forState:UIControlStateNormal];
    customButton.titleLabel.font = font;
    [customButton addTarget:self action:@selector(cancelAction) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *barItem = [[UIBarButtonItem alloc] initWithCustomView:customButton];
    self.navigationItem.rightBarButtonItem = barItem;

    [self setActivityIndecator];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleBlockedStateNotification:)
                                                 name:PPUserManagerDidUpdateBlockedStateNotification
                                               object:UserManager.sharedManager];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UserManager.sharedManager startListeningCurrentUserBlockedState];
    [UserManager.sharedManager startListeningCurrentUserPermissionsWithChange:nil];
    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [self pp_handleLiveBlockedStateIfNeeded];
    }
}

- (void)setActivityIndecator {
    self.activityHUD = [CCActivityHUD new];
    self.activityHUD.isTheOnlyActiveView = YES;
    self.activityHUD.backColor = [UIColor clearColor];
    self.activityHUD.indicatorColor = [GM appPrimaryColor];
    self.activityHUD.overlayType = CCActivityHUDOverlayTypeShadow;
    [self.activityHUD setAppearAnimationType:CCActivityHUDAppearAnimationTypeZoomIn];
    [self.activityHUD setDisappearAnimationType:CCActivityHUDDisappearAnimationTypeZoomOut];
}

- (void)cancelAction {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)initializeForm {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"عرض الخدمة الجديدة", nil)];

    XLFormSectionDescriptor *topSection = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"الصورة", nil)];
    [form addFormSection:topSection];

    XLFormRowDescriptor *imageRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"image" rowType:XLFormRowDescriptorTypeButton title:[NSString stringWithFormat:@"📸 %@", NSLocalizedString(@"تحميل صورة", nil)]];
    imageRow.action.formSelector = @selector(pickImage);
    imageRow.cellConfig[@"textLabel.textColor"] = [GM appPrimaryColor];
    imageRow.cellConfig[@"textLabel.font"] = [GM MidFontWithSize:16];
    imageRow.cellConfig[@"contentView.backgroundColor"] = UIColor.systemBackgroundColor;
    [topSection addFormRow:imageRow];

    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"تفاصيل الخدمة", nil)];
    [form addFormSection:section];

    self.titleRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"title" rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"اسم الخدمة", nil)];
    self.titleRow.required = YES;
    [section addFormRow:self.titleRow];

    self.descRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"description" rowType:XLFormRowDescriptorTypeTextView title:NSLocalizedString(@"الوصف", nil)];
    self.descRow.required = YES;
    self.descRow.cellConfig[@"textView.placeholder"] = NSLocalizedString(@"أدخل وصفاً مفصلاً للخدمة", nil);
    [section addFormRow:self.descRow];

    self.priceRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"price" rowType:XLFormRowDescriptorTypeDecimal title:NSLocalizedString(@"السعر", nil)];
    self.priceRow.required = YES;
    [section addFormRow:self.priceRow];

    self.categoryRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"category" rowType:XLFormRowDescriptorTypeSelectorPush title:NSLocalizedString(@"نوع الخدمة", nil)];
    self.categoryRow.required = YES;
    self.categoryRow.noValueDisplayText = @"اختر نوع الخدمة";
    self.categoryRow.selectorOptions = @[ [[CategoryModel alloc] initWithID:@"1" name:kLang(@"Grooming")], [[CategoryModel alloc] initWithID:@"2" name:kLang(@"Training")], [[CategoryModel alloc] initWithID:@"3" name:kLang(@"Walking")] ];

    __weak typeof(self) weakSelf = self;
    self.categoryRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.selectedCategory = (CategoryModel *)newValue;
    };
    [section addFormRow:self.categoryRow];

    self.dateRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"date" rowType:XLFormRowDescriptorTypeDateInline title:NSLocalizedString(@"تاريخ التوفر", nil)];
    [section addFormRow:self.dateRow];

    XLFormSectionDescriptor *bottomSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:bottomSection];

    XLFormRowDescriptor *saveRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"saveRow" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"إضافة", nil)];
    saveRow.cellConfig[@"textLabel.textColor"] = UIColor.whiteColor;
    saveRow.cellConfig[@"textLabel.font"] = [GM boldFontWithSize:16];
    saveRow.cellConfig[@"contentView.backgroundColor"] = [GM appPrimaryColor];
    saveRow.action.formSelector = @selector(submitServiceOffer);
    [bottomSection addFormRow:saveRow];

    self.form = form;
    self.tableView.backgroundColor = [GM backOffwhileColor];

    self.previewImageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, self.navigationController.navigationBar.hx_h + 10, self.view.bounds.size.width - 40, 200)];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.previewImageView.layer.cornerRadius = 12;
    self.previewImageView.layer.masksToBounds = YES;
    self.previewImageView.backgroundColor = AppForgroundColr;
    self.previewImageView.image = [UIImage imageNamed:@"grooming"];
    [self.view addSubview:self.previewImageView];

    UIEdgeInsets insets = self.tableView.contentInset;
    insets.top += 180;
    self.tableView.contentInset = insets;

    if (self.serviceToEdit) {
        self.titleRow.value = self.serviceToEdit.title;
        self.descRow.value = self.serviceToEdit.desc;
        self.priceRow.value = @(self.serviceToEdit.price);
        NSString *categoryName = self.serviceToEdit.category.length > 0 ? self.serviceToEdit.category : self.serviceToEdit.categoryID;
        self.selectedCategory = [[CategoryModel alloc] initWithID:self.serviceToEdit.categoryID ?: @"" name:categoryName ?: @""];
        self.categoryRow.value = self.selectedCategory;
        self.dateRow.value = self.serviceToEdit.availableDate;

        self.previewImageView.image = [UIImage imageNamed:@"placeholder"];
        if (self.serviceToEdit.imageURL) {
            [GM setImageFromUrlString:self.serviceToEdit.imageURL imageView:self.previewImageView phImage:@"placeholder"];
        }
    }
    
    
}

- (void)pickImage {
    [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:self
                                                            completion:^(BOOL granted) {
        if (!granted) return;

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    self.selectedImage = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    XLFormRowDescriptor *imageRow = [self.form formRowWithTag:@"image"];
    imageRow.title = NSLocalizedString(@"✅ تم تحميل الصورة", nil);
    [self updateFormRow:imageRow];
    self.previewImageView.image = self.selectedImage;
    self.previewImageView.hidden = NO;
}

- (void)submitServiceOffer {
    if (self.isSubmittingService) {
        return;
    }
    if (![self pp_validateAddServiceAccessShowingAlert:YES]) {
        return;
    }

    NSArray *errors = [self formValidationErrors];
    if (errors.count > 0) {
        [self showFormValidationError:errors.firstObject];
        return;
    }
    self.isSubmittingService = YES;
    [self.activityHUD show];
    NSDictionary *values = [self formValues];

    ServiceModel *model = [[ServiceModel alloc] init];
    model.title = values[@"title"];
    model.desc = values[@"description"];
    model.price = [values[@"price"] doubleValue];
    model.category = self.selectedCategory.name;
    model.categoryID = self.selectedCategory.categoryID;
    model.availableDate = values[@"date"];
    model.timestamp = [NSDate date];
    model.petMainKindID = self.MainKindID;
    model.serviceOwnerID = [UserManager sharedManager].currentUser.ID;

    if (!errors && self.onAddedBlock) {
           self.onAddedBlock(model ?: nil);
       }
    
    
    if (self.selectedImage) {
        [[ServicesManager sharedInstance] addService:model image:self.selectedImage completion:^(NSError *error) {
            [self handleSubmitResult:error];
        }];
    } else {
        [[ServicesManager sharedInstance] addService:model image:self.selectedImage completion:^(NSError *error) {
            [self handleSubmitResult:error];
        }];
    }
}

- (void)handleSubmitResult:(NSError *)error {
    self.isSubmittingService = NO;
    [self.activityHUD dismiss];
    if (error) {
        [self showAlert:error.localizedDescription];
        return;
    }
    [self setAlertDone];
    [self.alertDone showAlertInView:self
                          withTitle:kLang(@"AddService")
                       withSubtitle:kLang(@"Added")
                    withCustomImage:nil
                withDoneButtonTitle:kLang(@"done")
                         andButtons:@[]];
    self.alertDone.doneBlock = ^{
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    };
}

- (void)setAlertDone {
    self.alertDone = [[FCAlertView alloc] init];
    [self.alertDone makeAlertTypeSuccess];
    self.alertDone.dismissOnOutsideTouch = NO;
    self.alertDone.hideDoneButton = NO;
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"الخدمة", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"تم", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self.tableView reloadData];
}

#pragma mark - Access Guard

- (BOOL)pp_validateAddServiceAccessShowingAlert:(BOOL)showAlert {
    UserManager *userManager = UserManager.sharedManager;
    UserModel *currentUser = userManager.currentUser;
    NSString *uid = [currentUser.ID isKindOfClass:NSString.class] ? currentUser.ID : @"";

    if (uid.length == 0) {
        if (showAlert) {
            [self showAlert:kLang(@"Please sign in first.")];
        }
        return NO;
    }

    if (currentUser.isBlocked || userManager.isCurrentUserBlocked) {
        if (showAlert) {
            [self pp_handleLiveBlockedStateIfNeeded];
        }
        return NO;
    }

    if ([currentUser hasAnyPermissionInKeys:@[kPermManageServices, kPermAdminAll]]) {
        return YES;
    }

    if (showAlert) {
        [self showAlert:kLang(@"You don't have permission to add services.")];
    }
    return NO;
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
    self.isSubmittingService = NO;
    [self.activityHUD dismiss];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Account blocked")
                                                                   message:kLang(@"Your account is blocked. You can no longer add new services.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [weakSelf.navigationController dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
