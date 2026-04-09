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

@interface VetViewerViewController ()
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIView *topHeaderView;
@property (nonatomic, strong) UILabel *topHeaderTitleLabel;
@property (nonatomic, strong) UIImageView *headerImageView;
@property (nonatomic, copy) NSArray<UIButton *> *actionButtons;
@end

@implementation VetViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"عرض الطبيب البيطري";
    self.view.backgroundColor = PPBackgroundColorForIOS26([GM AppForegroundColor]);
    self.view.layer.cornerRadius = 20;
    self.view.clipsToBounds = YES;

    [self setupForm];
    [self buildCloseButton];
    [self addTopHeader];
    [self addBottomButtonsIfNeeded];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_layoutChrome];
}

- (void)buildCloseButton
{
    if (self.closeButton) {
        return;
    }

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.backgroundColor = UIColor.clearColor;
    btn.clipsToBounds = YES;
    [btn setImage:[UIImage imageNamed:@"pulldown"] forState:UIControlStateNormal];
    btn.tintColor = UIColor.darkGrayColor;
    btn.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    [btn addTarget:self action:@selector(closeMe) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    self.closeButton = btn;
}

- (void)addTopHeader {
    if (self.topHeaderView) {
        self.topHeaderTitleLabel.text = self.vet.title;
        return;
    }

    UIView *customSubView = [[UIView alloc] initWithFrame:CGRectZero];
    customSubView.backgroundColor = GM.appPrimaryColor;
    customSubView.layer.cornerRadius = 22;
    customSubView.layer.maskedCorners = kCALayerMinXMaxYCorner;
    customSubView.clipsToBounds = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.text = self.vet.title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [GM boldFontWithSize:18];
    titleLabel.textColor = UIColor.whiteColor;

    [customSubView addSubview:titleLabel];
    [self.view addSubview:customSubView];

    self.topHeaderView = customSubView;
    self.topHeaderTitleLabel = titleLabel;
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
        self.headerImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.headerImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.headerImageView.clipsToBounds = YES;
        [GM setImageFromUrlString:self.vet.logoURL imageView:self.headerImageView phImage:@"placeholder"];
        self.tableView.tableHeaderView = self.headerImageView;
    }
}

- (XLFormRowDescriptor *)textRow:(NSString *)tag title:(NSString *)title value:(NSString *)value {
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:tag rowType:XLFormRowDescriptorTypeInfo title:title];
    row.value = value;
    return row;
}

#pragma mark - Buttons

- (void)addBottomButtonsIfNeeded {
    if (self.vet.type == 0 || self.actionButtons.count > 0) return;

    NSArray *icons = @[@"phone.fill", @"message.fill", @"location.fill", @"square.and.arrow.up"];
    NSArray *selectors = @[@"callTapped", @"whatsappTapped", @"locationTapped", @"shareTapped"];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray arrayWithCapacity:icons.count];

    for (NSInteger i = 0; i < icons.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = GM.appPrimaryColor;
        btn.clipsToBounds = YES;
        [btn setImage:[UIImage systemImageNamed:icons[i]] forState:UIControlStateNormal];
        btn.tintColor = UIColor.whiteColor;
        [btn addTarget:self action:NSSelectorFromString(selectors[i]) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
        [buttons addObject:btn];
    }

    self.actionButtons = buttons.copy;
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
                                                                         0,
                                                                         0);
        activityVC.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Private

- (void)pp_layoutChrome
{
    UIEdgeInsets safeInsets = self.view.safeAreaInsets;
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
    CGFloat viewHeight = CGRectGetHeight(self.view.bounds);

    self.closeButton.frame = CGRectMake(12.0,
                                        safeInsets.top + 8.0,
                                        44.0,
                                        44.0);

    CGFloat headerWidth = MIN(MAX(viewWidth * 0.46, 180.0), 240.0);
    self.topHeaderView.frame = CGRectMake(viewWidth - headerWidth,
                                          safeInsets.top,
                                          headerWidth,
                                          46.0);
    self.topHeaderTitleLabel.frame = self.topHeaderView.bounds;

    [self pp_updateTableHeaderIfNeededForWidth:viewWidth];
    [self pp_layoutBottomButtonsForWidth:viewWidth height:viewHeight safeInsets:safeInsets];
}

- (void)pp_updateTableHeaderIfNeededForWidth:(CGFloat)viewWidth
{
    if (!self.headerImageView) {
        return;
    }

    CGFloat headerWidth = MAX(viewWidth - 32.0, 0.0);
    CGFloat headerHeight = MIN(MAX(viewWidth * 0.56, 220.0), 320.0);
    CGRect headerFrame = CGRectMake(16.0, 8.0, headerWidth, headerHeight);

    if (!CGRectEqualToRect(self.headerImageView.frame, headerFrame)) {
        self.headerImageView.frame = headerFrame;
        self.tableView.tableHeaderView = self.headerImageView;
    }
}

- (void)pp_layoutBottomButtonsForWidth:(CGFloat)viewWidth height:(CGFloat)viewHeight safeInsets:(UIEdgeInsets)safeInsets
{
    if (self.actionButtons.count == 0) {
        self.tableView.contentInset = UIEdgeInsetsZero;
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
        return;
    }

    NSInteger buttonsPerRow = viewWidth >= 420.0 ? 4 : 2;
    CGFloat buttonSize = viewWidth >= 768.0 ? 66.0 : 58.0;
    CGFloat spacing = viewWidth >= 768.0 ? 20.0 : 14.0;
    NSInteger rows = (NSInteger)ceil((CGFloat)self.actionButtons.count / (CGFloat)buttonsPerRow);
    CGFloat totalWidth = (buttonSize * buttonsPerRow) + (spacing * MAX(buttonsPerRow - 1, 0));
    CGFloat startX = floor((viewWidth - totalWidth) * 0.5);
    CGFloat totalHeight = (buttonSize * rows) + (spacing * MAX(rows - 1, 0));
    CGFloat startY = viewHeight - safeInsets.bottom - 24.0 - totalHeight;

    [self.actionButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
        NSInteger row = (NSInteger)idx / buttonsPerRow;
        NSInteger column = (NSInteger)idx % buttonsPerRow;
        CGFloat x = startX + (column * (buttonSize + spacing));
        CGFloat y = startY + (row * (buttonSize + spacing));
        button.frame = CGRectMake(x, y, buttonSize, buttonSize);
        button.layer.cornerRadius = buttonSize * 0.5;
    }];

    CGFloat bottomInset = totalHeight + 36.0 + safeInsets.bottom;
    self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0);
}

@end
