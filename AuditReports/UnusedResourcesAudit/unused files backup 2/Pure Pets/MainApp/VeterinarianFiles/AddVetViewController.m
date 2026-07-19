//
//  AddVetViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//


#import "AddVetViewController.h"
#import "PPPermissionHelper.h"

@interface AddVetViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) FCAlertView *alertDone;
@property (nonatomic, strong) CCActivityHUD *activityHUD;

@end

@implementation AddVetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.vetToEdit ? @"تعديل الطبيب البيطري" : @"إضافة طبيب بيطري";
    self.view.backgroundColor = PPBackgroundColorForIOS26([GM backOffwhileColor]);

    self.view.layer.cornerRadius = 25;
    self.view.clipsToBounds = YES;
    [self setupLogoImageView];

    [self initializeForm];
    [self setActivityIndecator];
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

- (void)initializeForm {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:@"Vet Info"];
    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSectionWithTitle:@"معلومات الطبيب البيطري"];
    [form addFormSection:section];

    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"title" rowType:XLFormRowDescriptorTypeText title:@"الاسم"]];
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"phone" rowType:XLFormRowDescriptorTypePhone title:@"الهاتف"]];
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"whatsapp" rowType:XLFormRowDescriptorTypePhone title:@"واتساب"]];
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"descriptionText" rowType:XLFormRowDescriptorTypeTextView title:@"الوصف"]];
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"availableDate" rowType:XLFormRowDescriptorTypeDateInline title:@"تاريخ التوفر"]];

    XLFormRowDescriptor *typeRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"type" rowType:XLFormRowDescriptorTypeSelectorPush title:@"النوع"];
    typeRow.selectorOptions = @[
        [XLFormOptionsObject formOptionsObjectWithValue:@(VetTypePersonal) displayText:@"شخصي"],
        [XLFormOptionsObject formOptionsObjectWithValue:@(VetTypeCompany) displayText:@"شركة"]
    ];
    [section addFormRow:typeRow];

    XLFormRowDescriptor *saveRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"save" rowType:XLFormRowDescriptorTypeButton title:@"حفظ"];
    saveRow.action.formSelector = @selector(saveTapped);
    [form addFormSection:[XLFormSectionDescriptor formSection]];
    [[form formSections].lastObject addFormRow:saveRow];

    self.form = form;

    if (self.vetToEdit) {
        [self populateFormWithModel:self.vetToEdit];
    }
    
    self.tableView.backgroundColor = [GM backOffwhileColor];
}

- (void)populateFormWithModel:(VetModel *)model {
    [self.form formRowWithTag:@"title"].value = model.title;
    [self.form formRowWithTag:@"phone"].value = model.phone;
    [self.form formRowWithTag:@"whatsapp"].value = model.whatsapp;
    [self.form formRowWithTag:@"descriptionText"].value = model.descriptionText;
    [self.form formRowWithTag:@"availableDate"].value = model.availableDate;
    [self.form formRowWithTag:@"type"].value = [XLFormOptionsObject formOptionsObjectWithValue:@(model.type) displayText:(model.type == VetTypePersonal ? @"شخصي" : @"شركة")];
    [self.form formRowWithTag:@"petMainKindID"].value = @(model.petMainKindID);
}

-(void)showDoneAlert
{
    
    [self setAlertDone];
    
    [GM playSoundWithName:@"my_done" type:@"mp3"];
    
    [self.alertDone showAlertInView:self
                          withTitle:kLang(@"AddVet")
                       withSubtitle:kLang(@"vetAdded")
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


- (void)saveTapped {
    NSArray *errors = [self formValidationErrors];
    if (errors.count > 0) {
        [self showFormValidationError:[errors firstObject]];
        return;
    }
    [self.activityHUD show];
    NSDictionary *values = [self formValues];
    VetModel *model = self.vetToEdit ?: [[VetModel alloc] init];
    model.title = values[@"title"];
    model.phone = values[@"phone"];
    model.whatsapp = values[@"whatsapp"];
    model.descriptionText = values[@"descriptionText"];
    model.availableDate = values[@"availableDate"];
    model.type = [values[@"type"] formValue] ? [[values[@"type"] formValue] integerValue] : VetTypePersonal;
    model.petMainKindID = self.MainKindID;
    model.userID = UserManager.sharedManager.currentUser.ID;

    void (^finalizeSave)(NSString *) = ^(NSString *logoURL) {
        model.logoURL = logoURL ?: model.logoURL;

        if (self.vetToEdit) {
            [[VetManager sharedManager] updateVet:model image:self.selectedLogo completion:^(NSError * _Nullable error) {
                [self handleSaveResult:error];
                [self.activityHUD dismiss];
                
                [self showDoneAlert];
            }];
        } else {
            [[VetManager sharedManager] addVet:model image:self.selectedLogo completion:^(NSError * _Nullable error) {
                [self handleSaveResult:error];
                [self.activityHUD dismiss];
                [self showDoneAlert];
            }];
        }
    };

    if (self.selectedLogo) {
        [[VetManager sharedManager] uploadImage:self.selectedLogo vetID:model.vetID completion:^(NSString *imageURL) {
            
            finalizeSave(imageURL);
        }];
    } else {
        finalizeSave(nil);
    }
}

- (void)handleSaveResult:(NSError *)error {
    if (error) {
        [self showAlert:@"حدث خطأ أثناء الحفظ"];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

-(void)showAlert:(NSString *)alert
{
    
}

- (void)setupLogoImageView {
    self.logoImageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, self.navigationController.navigationBar.hx_h + 10, self.view.bounds.size.width - 40, 200)];
    self.logoImageView.backgroundColor = [GM AppForegroundColor];
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoImageView.clipsToBounds = YES;
    self.logoImageView.layer.cornerRadius = 12;
    self.logoImageView.userInteractionEnabled = YES;
    self.logoImageView.image = [UIImage imageNamed:@"veterinary"];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickImage)];
    [self.logoImageView addGestureRecognizer:tap];
    [self.view addSubview:self.logoImageView];

    self.tableView.contentInset = UIEdgeInsetsMake(self.logoImageView.hx_maxy, 0, 0, 0);

    if (self.vetToEdit.logoURL.length > 0) {
        [GM setImageFromUrlString:self.vetToEdit.logoURL imageView:self.logoImageView phImage:@"veterinary"];
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
    self.selectedLogo = info[UIImagePickerControllerOriginalImage];
    self.logoImageView.image = self.selectedLogo;
    [picker dismissViewControllerAnimated:YES completion:nil];
}


- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    NSInteger rows = [tableView numberOfRowsInSection:section];

    UIBezierPath *maskPath;
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGRect bounds = cell.bounds;

    if (row == 0 && row == rows - 1) {
        // Single cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:12];
    } else if (row == 0) {
        // First cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                         byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                               cornerRadii:CGSizeMake(20, 20)];
    } else if (row == rows - 1) {
        // Last cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                         byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                               cornerRadii:CGSizeMake(20, 20)];
    } else {
        // Middle cell
        maskPath = [UIBezierPath bezierPathWithRect:bounds];
    }

    maskLayer.path = maskPath.CGPath;
    cell.layer.mask = maskLayer;
}
@end
