//
//  VetViewerViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/07/2025.
//


#import "VetViewerViewController.h"
#import "GM.h"
#import "AppManager.h"
#import "UserModel.h"

@implementation VetViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"عرض الطبيب البيطري";
    self.view.backgroundColor = PPBackgroundColorForIOS26([GM AppForegroundColor]);
    self.view.layer.cornerRadius = 20;
    self.view.clipsToBounds = YES;

    [self setupForm];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(10, 10, 40, 40);
    btn.backgroundColor = UIColor.clearColor;
    btn.clipsToBounds = YES;
    [btn setImage:[UIImage imageNamed:@"pulldown"] forState:UIControlStateNormal];
    btn.tintColor = UIColor.darkGrayColor;
    btn.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    [btn addTarget:self action:@selector(closeMe) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];

    [self addTopHeader];
}

- (void)addTopHeader {
    UIView *parentView = self.view;
    CGFloat width = 200;
    CGFloat height = 44;
    CGFloat x = parentView.frame.size.width - width;
    CGFloat y = 0;

    UIView *customSubView = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    customSubView.backgroundColor = GM.appPrimaryColor;
    customSubView.layer.cornerRadius = 22;
    customSubView.layer.maskedCorners = kCALayerMinXMaxYCorner;
    customSubView.clipsToBounds = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:customSubView.bounds];
    titleLabel.text = self.vet.title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [GM boldFontWithSize:18];
    titleLabel.textColor = UIColor.whiteColor;

    [customSubView addSubview:titleLabel];
    [parentView addSubview:customSubView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [UIView animateWithDuration:0.3 animations:^{
        [self addBottomButtonsIfNeeded];
    }];
}

- (void)closeMe {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - XLForm Setup

- (void)setupForm {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:@"تفاصيل الطبيب البيطري"];
    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSectionWithTitle:@"معلومات الطبيب"];
    [form addFormSection:section];

    [section addFormRow:[self textRow:@"title" title:@"الاسم" value:self.vet.title]];
    [section addFormRow:[self textRow:@"type" title:@"النوع" value:(self.vet.type == 1 ? @"شركة" : @"شخصي")]];
    [section addFormRow:[self textRow:@"availableDate" title:@"تاريخ التوفر" value:[GM formattedDate:self.vet.availableDate]]];

    self.form = form;

    if (self.vet.logoURL.length > 0) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 8, self.view.frame.size.width - 32, 250)];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        [GM setImageFromUrlString:self.vet.logoURL imageView:imageView phImage:@"placeholder"];
        self.tableView.tableHeaderView = imageView;
    }
}

- (XLFormRowDescriptor *)textRow:(NSString *)tag title:(NSString *)title value:(NSString *)value {
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:tag rowType:XLFormRowDescriptorTypeInfo title:title];
    row.value = value;
    return row;
}

#pragma mark - Buttons

- (void)addBottomButtonsIfNeeded {
    if (self.vet.type == 0) return;

    CGFloat buttonSize = 60;
    CGFloat spacing = 20;

    CGFloat totalWidth = (buttonSize * 4) + (spacing * 3);
    CGFloat startX = (self.view.bounds.size.width - totalWidth) / 2;
    CGFloat yPosition = self.view.bounds.size.height - buttonSize - 40;

    NSArray *icons = @[@"phone.fill", @"message.fill", @"location.fill", @"square.and.arrow.up"];
    NSArray *selectors = @[@"callTapped", @"whatsappTapped", @"locationTapped", @"shareTapped"];

    for (int i = 0; i < 4; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(startX + (i * (buttonSize + spacing)), yPosition, buttonSize, buttonSize);
        btn.backgroundColor = GM.appPrimaryColor;
        btn.layer.cornerRadius = buttonSize / 2;
        btn.clipsToBounds = YES;
        [btn setImage:[UIImage systemImageNamed:icons[i]] forState:UIControlStateNormal];
        btn.tintColor = UIColor.whiteColor;
        [btn addTarget:self action:NSSelectorFromString(selectors[i]) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}

#pragma mark - Actions

- (void)callTapped {
    NSString *phoneNumber = [self.vet.phone stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (phoneNumber.length == 0) return;
    NSString *phone = [@"tel://" stringByAppendingString:phoneNumber];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:phone] options:@{} completionHandler:nil];
}

- (void)whatsappTapped {
    NSString *whatsAppNumber = [self.vet.whatsapp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (whatsAppNumber.length == 0) {
        whatsAppNumber = [self.vet.phone stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (whatsAppNumber.length == 0) return;
    NSString *urlStr = [NSString stringWithFormat:@"https://wa.me/%@", whatsAppNumber];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr] options:@{} completionHandler:nil];
}

- (void)locationTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"الموقع" message:@"لم يتم تحديد موقع لهذه الخدمة" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shareTapped {
    NSString *text = [NSString stringWithFormat:@"الطبيب البيطري: %@\n%@", self.vet.title, self.vet.description ?: @""];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                         CGRectGetMidY(self.view.bounds),
                                                                         0, 0);
        activityVC.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end
