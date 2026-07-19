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
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;
@property (nonatomic, strong) UIView *heroArea;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UIButton *imagePickerButton;
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

- (UIColor *)pp_canvasColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.97 green:0.96 blue:0.95 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    }];
}

- (UIColor *)pp_borderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.06];
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";
    self.view.backgroundColor = [self pp_canvasColor];
    [self pp_setupBackdropGlows];
    [self initializeForm];
    [self pp_applyTableChrome];
    [self pp_buildHero];
    [self pp_applyPreviewState];

    UIFont *font = [GM MidFontWithSize:16];
    UIButton *customButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customButton setTitle:kLang(@"Close") forState:UIControlStateNormal];
    customButton.titleLabel.font = font;
    customButton.tintColor = AppPrimaryClr;
    [customButton addTarget:self action:@selector(cancelAction) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *barItem = [[UIBarButtonItem alloc] initWithCustomView:customButton];
    self.navigationItem.rightBarButtonItem = barItem;
    self.navigationController.navigationBar.tintColor = AppPrimaryClr;

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

- (void)pp_setupBackdropGlows {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 110.0;
    [self.view insertSubview:self.bgGlowTop atIndex:0];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 100.0;
    [self.view insertSubview:self.bgGlowBottom atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:220.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-72.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:200.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0]
    ]];

    [self pp_updateGlowsForStyle];
}

- (void)pp_updateGlowsForStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bgGlowTop.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.05 : 0.10];
    self.bgGlowTop.layer.shadowColor = AppPrimaryClr.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.08;
    self.bgGlowTop.layer.shadowRadius = 60.0;

    self.bgGlowBottom.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:isDark ? 0.03 : 0.06];
    self.bgGlowBottom.layer.shadowColor = [UIColor systemOrangeColor].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.02 : 0.06;
    self.bgGlowBottom.layer.shadowRadius = 70.0;
}

- (void)pp_applyTableChrome {
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64.0;
    self.tableView.layer.masksToBounds = NO;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
}

- (void)pp_buildHero {
    self.heroArea = [[UIView alloc] init];
    self.heroArea.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroArea.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.heroArea];

    UIView *heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.backgroundColor = [self pp_surfaceColor];
    heroCard.layer.cornerRadius = 34.0;
    heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    heroCard.layer.borderWidth = 1.0;
    heroCard.layer.borderColor = [self pp_borderColor].CGColor;
    heroCard.clipsToBounds = YES;

    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    heroCard.layer.shadowColor = UIColor.blackColor.CGColor;
    heroCard.layer.shadowOpacity = isDark ? 0.03 : 0.08;
    heroCard.layer.shadowRadius = 24.0;
    heroCard.layer.shadowOffset = CGSizeMake(0, 14.0);
    [self.heroArea addSubview:heroCard];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr;
    accentBar.layer.cornerRadius = 3.0;
    [heroCard addSubview:accentBar];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.previewImageView.clipsToBounds = YES;
    self.previewImageView.layer.cornerRadius = 34.0;
    self.previewImageView.layer.cornerCurve = kCACornerCurveContinuous;
    self.previewImageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    self.previewImageView.layer.borderWidth = 2.0;
    self.previewImageView.layer.borderColor = [UIColor whiteColor].CGColor;
    self.previewImageView.userInteractionEnabled = YES;
    [self.previewImageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickImage)]];
    [heroCard addSubview:self.previewImageView];

    self.imagePickerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.imagePickerButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *camCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [self.imagePickerButton setImage:[UIImage systemImageNamed:@"camera.fill" withConfiguration:camCfg] forState:UIControlStateNormal];
    self.imagePickerButton.tintColor = AppPrimaryClr;
    self.imagePickerButton.backgroundColor = [self pp_surfaceColor];
    self.imagePickerButton.layer.cornerRadius = 16.0;
    self.imagePickerButton.layer.borderWidth = 1.0;
    self.imagePickerButton.layer.borderColor = [self pp_borderColor].CGColor;
    self.imagePickerButton.layer.shadowColor = UIColor.blackColor.CGColor;
    self.imagePickerButton.layer.shadowOpacity = 0.1;
    self.imagePickerButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.imagePickerButton.layer.shadowRadius = 8.0;
    [self.imagePickerButton addTarget:self action:@selector(pickImage) forControlEvents:UIControlEventTouchUpInside];
    [heroCard addSubview:self.imagePickerButton];

    UILabel *heroTitle = [[UILabel alloc] init];
    heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroTitle.font = [Styling fontBold:26.0];
    heroTitle.textColor = AppPrimaryClr;
    heroTitle.textAlignment = NSTextAlignmentCenter;
    heroTitle.numberOfLines = 2;
    heroTitle.text = self.serviceToEdit ? kLang(@"service_view_details_title") : kLang(@"AddService");
    [heroCard addSubview:heroTitle];

    UILabel *heroSubtitle = [[UILabel alloc] init];
    heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroSubtitle.font = [Styling fontMedium:13.0];
    heroSubtitle.textColor = AppSecondaryTextClr;
    heroSubtitle.textAlignment = NSTextAlignmentCenter;
    heroSubtitle.numberOfLines = 2;
    heroSubtitle.text = kLang(@"Home_ServiceProvidersSubtitle");
    [heroCard addSubview:heroSubtitle];

    UILayoutGuide *safeGuide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroArea.topAnchor constraintEqualToAnchor:safeGuide.topAnchor constant:4.0],
        [self.heroArea.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.heroArea.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.heroArea.heightAnchor constraintEqualToConstant:320.0],

        [heroCard.topAnchor constraintEqualToAnchor:self.heroArea.topAnchor constant:12.0],
        [heroCard.leadingAnchor constraintEqualToAnchor:self.heroArea.leadingAnchor constant:20.0],
        [heroCard.trailingAnchor constraintEqualToAnchor:self.heroArea.trailingAnchor constant:-20.0],
        [heroCard.bottomAnchor constraintEqualToAnchor:self.heroArea.bottomAnchor constant:-12.0],

        [accentBar.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:20.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [self.previewImageView.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [self.previewImageView.centerXAnchor constraintEqualToAnchor:heroCard.centerXAnchor],
        [self.previewImageView.widthAnchor constraintEqualToConstant:108.0],
        [self.previewImageView.heightAnchor constraintEqualToConstant:108.0],

        [self.imagePickerButton.bottomAnchor constraintEqualToAnchor:self.previewImageView.bottomAnchor],
        [self.imagePickerButton.trailingAnchor constraintEqualToAnchor:self.previewImageView.trailingAnchor constant:6.0],
        [self.imagePickerButton.widthAnchor constraintEqualToConstant:32.0],
        [self.imagePickerButton.heightAnchor constraintEqualToConstant:32.0],

        [heroTitle.topAnchor constraintEqualToAnchor:self.previewImageView.bottomAnchor constant:12.0],
        [heroTitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [heroTitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0],

        [heroSubtitle.topAnchor constraintEqualToAnchor:heroTitle.bottomAnchor constant:4.0],
        [heroSubtitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:24.0],
        [heroSubtitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-24.0]
    ]];

    [self.view bringSubviewToFront:self.heroArea];
}

- (void)pp_applyPreviewState {
    if (self.selectedImage) {
        self.previewImageView.image = self.selectedImage;
        self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.previewImageView.tintColor = nil;
        return;
    }

    if (self.serviceToEdit.imageURL.length > 0) {
        self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.previewImageView.tintColor = nil;
        [GM setImageFromUrlString:self.serviceToEdit.imageURL imageView:self.previewImageView phImage:@"placeholder"];
        return;
    }

    self.previewImageView.image = [UIImage systemImageNamed:@"pawprint.fill"];
    self.previewImageView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.2];
    self.previewImageView.contentMode = UIViewContentModeCenter;
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
    imageRow.cellConfig[@"textLabel.font"] = [Styling fontBold:15.0];
    imageRow.cellConfig[@"textLabel.textAlignment"] = @(Language.alignmentForCurrentLanguage);
    [topSection addFormRow:imageRow];

    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"service_view_details_title")];
    [form addFormSection:section];

    self.titleRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"title" rowType:XLFormRowDescriptorTypeText title:kLang(@"Name")];
    self.titleRow.required = YES;
    self.titleRow.cellConfig[@"textField.font"] = [Styling fontBold:15.0];
    self.titleRow.cellConfig[@"textField.textColor"] = AppPrimaryClr;
    self.titleRow.cellConfig[@"textField.textAlignment"] = @(Language.alignmentForCurrentLanguage);
    self.titleRow.cellConfig[@"textLabel.textColor"] = AppPrimaryClr;
    self.titleRow.cellConfig[@"textLabel.font"] = [Styling fontMedium:13.0];
    [section addFormRow:self.titleRow];

    self.descRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"description" rowType:XLFormRowDescriptorTypeTextView title:kLang(@"Description")];
    self.descRow.required = YES;
    self.descRow.cellConfig[@"textView.placeholder"] = NSLocalizedString(@"أدخل وصفاً مفصلاً للخدمة", nil);
    self.descRow.cellConfig[@"textView.textColor"] = AppPrimaryClr;
    self.descRow.cellConfig[@"textView.font"] = [Styling fontBold:15.0];
    self.descRow.cellConfig[@"textView.textAlignment"] = @(Language.alignmentForCurrentLanguage);
    self.descRow.cellConfig[@"textLabel.textColor"] = AppPrimaryClr;
    self.descRow.cellConfig[@"textLabel.font"] = [Styling fontMedium:13.0];
    [section addFormRow:self.descRow];

    self.priceRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"price" rowType:XLFormRowDescriptorTypeDecimal title:kLang(@"Price")];
    self.priceRow.required = YES;
    self.priceRow.cellConfig[@"textField.font"] = [Styling fontBold:15.0];
    self.priceRow.cellConfig[@"textField.textColor"] = AppPrimaryClr;
    self.priceRow.cellConfig[@"textField.textAlignment"] = @(Language.alignmentForCurrentLanguage);
    self.priceRow.cellConfig[@"textLabel.textColor"] = AppPrimaryClr;
    self.priceRow.cellConfig[@"textLabel.font"] = [Styling fontMedium:13.0];
    [section addFormRow:self.priceRow];

    self.categoryRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"category" rowType:XLFormRowDescriptorTypeSelectorPush title:kLang(@"service_view_type")];
    self.categoryRow.required = YES;
    self.categoryRow.noValueDisplayText = @"اختر نوع الخدمة";
    self.categoryRow.cellConfig[@"textLabel.textColor"] = AppPrimaryClr;
    self.categoryRow.cellConfig[@"textLabel.font"] = [Styling fontMedium:13.0];
    self.categoryRow.cellConfig[@"detailTextLabel.textColor"] = AppPrimaryClr;
    self.categoryRow.cellConfig[@"detailTextLabel.font"] = [Styling fontBold:15.0];
    self.categoryRow.selectorOptions = @[ [[CategoryModel alloc] initWithID:@"1" name:kLang(@"Grooming")], [[CategoryModel alloc] initWithID:@"2" name:kLang(@"Training")], [[CategoryModel alloc] initWithID:@"3" name:kLang(@"Walking")] ];

    __weak typeof(self) weakSelf = self;
    self.categoryRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.selectedCategory = (CategoryModel *)newValue;
    };
    [section addFormRow:self.categoryRow];

    self.dateRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"date" rowType:XLFormRowDescriptorTypeDateInline title:kLang(@"service_view_available_date")];
    self.dateRow.cellConfig[@"textLabel.textColor"] = AppPrimaryClr;
    self.dateRow.cellConfig[@"textLabel.font"] = [Styling fontMedium:13.0];
    self.dateRow.cellConfig[@"detailTextLabel.textColor"] = AppPrimaryClr;
    self.dateRow.cellConfig[@"detailTextLabel.font"] = [Styling fontBold:15.0];
    [section addFormRow:self.dateRow];

    XLFormSectionDescriptor *bottomSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:bottomSection];

    XLFormRowDescriptor *saveRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"saveRow" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"إضافة", nil)];
    saveRow.cellConfig[@"textLabel.textColor"] = UIColor.whiteColor;
    saveRow.cellConfig[@"textLabel.font"] = [Styling fontBold:17.0];
    saveRow.cellConfig[@"textLabel.textAlignment"] = @(NSTextAlignmentCenter);
    saveRow.action.formSelector = @selector(submitServiceOffer);
    [bottomSection addFormRow:saveRow];

    self.form = form;

    if (self.serviceToEdit) {
        self.titleRow.value = self.serviceToEdit.title;
        self.descRow.value = self.serviceToEdit.desc;
        self.priceRow.value = @(self.serviceToEdit.price);
        NSString *categoryName = self.serviceToEdit.category.length > 0 ? self.serviceToEdit.category : self.serviceToEdit.categoryID;
        self.selectedCategory = [[CategoryModel alloc] initWithID:self.serviceToEdit.categoryID ?: @"" name:categoryName ?: @""];
        self.categoryRow.value = self.selectedCategory;
        self.dateRow.value = self.serviceToEdit.availableDate;
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
    [self pp_applyPreviewState];
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

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self.tableView reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat horizontalInset = 24.0;
    self.tableView.frame = CGRectMake(horizontalInset,
                                      CGRectGetMinY(self.view.bounds),
                                      MAX(0.0, CGRectGetWidth(self.view.bounds) - (horizontalInset * 2.0)),
                                      CGRectGetHeight(self.view.bounds));

    CGFloat topInset = CGRectGetMaxY(self.heroArea.frame) + 20.0 - CGRectGetMinY(self.tableView.frame);
    UIEdgeInsets tableInsets = UIEdgeInsetsMake(topInset, 0, 120.0, 0);
    if (!UIEdgeInsetsEqualToEdgeInsets(self.tableView.contentInset, tableInsets)) {
        self.tableView.contentInset = tableInsets;
    }
    if (!UIEdgeInsetsEqualToEdgeInsets(self.tableView.scrollIndicatorInsets, tableInsets)) {
        self.tableView.scrollIndicatorInsets = tableInsets;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
        [self pp_updateGlowsForStyle];
        [self.tableView reloadData];
    }
}

- (XLFormRowDescriptor *)pp_rowDescriptorAtIndexPath:(NSIndexPath *)indexPath {
    return [self.form formRowAtIndex:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    XLFormRowDescriptor *rowDescriptor = [self pp_rowDescriptorAtIndexPath:indexPath];
    if (!rowDescriptor || [rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeDatePicker]) {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    if ([rowDescriptor.tagM isEqualToString:@"description"]) {
        return 140.0;
    }
    if ([rowDescriptor.tagM isEqualToString:@"saveRow"]) {
        return 56.0;
    }
    return 58.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 2) {
        return 12.0;
    }
    return section == 0 ? 52.0 : 70.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView heightForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return section == 2 ? 0.000001 : 18.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section {
    return [self tableView:tableView heightForFooterInSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 2) {
        return [UIView new];
    }

    NSString *title = section == 0 ? NSLocalizedString(@"الصورة", nil) : kLang(@"service_view_details_title");
    NSString *subtitle = section == 0 ? nil : kLang(@"service_view_important_info_default");
    NSString *iconName = section == 0 ? @"photo.on.rectangle.angled" : @"doc.text.fill";
    return [self pp_sectionHeaderViewWithTitle:title subtitle:subtitle icon:iconName];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UIView *footer = [[UIView alloc] init];
    footer.backgroundColor = UIColor.clearColor;
    return footer;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    XLFormRowDescriptor *rowDescriptor = [self pp_rowDescriptorAtIndexPath:indexPath];
    BOOL isSaveRow = [rowDescriptor.tagM isEqualToString:@"saveRow"];
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.layer.masksToBounds = NO;
    cell.layoutMargins = UIEdgeInsetsZero;
    cell.separatorInset = UIEdgeInsetsMake(0, CGRectGetWidth(tableView.bounds), 0, 0);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    cell.contentView.backgroundColor = isSaveRow ? AppPrimaryClr : [self pp_surfaceColor];
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = isSaveRow ? 0.0 : 1.0;
    cell.contentView.layer.borderColor = isSaveRow ? UIColor.clearColor.CGColor : [self pp_borderColor].CGColor;
    cell.contentView.layoutMargins = UIEdgeInsetsMake(0.0, 18.0, 0.0, 18.0);

    cell.layer.shadowColor = (isSaveRow ? AppPrimaryClr : UIColor.blackColor).CGColor;
    cell.layer.shadowOpacity = isSaveRow ? (isDark ? 0.15 : 0.30) : (isDark ? 0.02 : 0.05);
    cell.layer.shadowRadius = isSaveRow ? 16.0 : 12.0;
    cell.layer.shadowOffset = isSaveRow ? CGSizeMake(0, 8) : CGSizeMake(0, 6);
    cell.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds cornerRadius:20.0].CGPath;

    cell.textLabel.textAlignment = isSaveRow ? NSTextAlignmentCenter : Language.alignmentForCurrentLanguage;
    cell.textLabel.font = isSaveRow ? [Styling fontBold:17.0] : [Styling fontBold:15.0];
    cell.textLabel.textColor = isSaveRow ? UIColor.whiteColor : ([rowDescriptor.tagM isEqualToString:@"image"] ? AppPrimaryClr : AppPrimaryClr);
    cell.detailTextLabel.font = [Styling fontBold:15.0];
    cell.detailTextLabel.textColor = isSaveRow ? UIColor.whiteColor : AppPrimaryClr;
}

- (UIView *)pp_sectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = AppPrimaryClr;
    bar.layer.cornerRadius = 2.0;
    [container addSubview:bar];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeCenter;
    [container addSubview:icon];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:14.0];
    titleLabel.textColor = AppPrimaryClr;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = title;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontMedium:11.0];
    subtitleLabel.textColor = AppSecondaryTextClr;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.alpha = 0.7;
    subtitleLabel.text = subtitle;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [bar.widthAnchor constraintEqualToConstant:28.0],
        [bar.heightAnchor constraintEqualToConstant:4.0],

        [icon.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [icon.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:9.0],
        [icon.widthAnchor constraintEqualToConstant:16.0],
        [icon.heightAnchor constraintEqualToConstant:16.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
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
