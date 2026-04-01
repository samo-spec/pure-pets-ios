//
//  SettingVC.m
//  Pure Pets
//

#import "SettingVC.h"
#import "PPRootTabBarController.h"
#import "YYAnimatedImageView.h"
@import UserNotifications;

NSString *const knotificationsSet = @"notificationsSet";
NSString *const kautoPlaySet = @"autoPlaySet";
NSString *const kmessagesSet = @"messagesSet";
NSString *const klanguageSet = @"languageSet";
NSString *const kDarkSet = @"DarkSet";

static NSString *const kSettingsAutoPlayKey = @"isAutoPlaySet";
static NSString *const kSettingsMessagesPrivacyKey = @"messagesPrivacyValue";

@interface SettingVC ()
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *containerView;

@property (nonatomic, strong) NSUserDefaults *prefs;
@property (nonatomic, strong) XLFormDescriptor *mform;
@property (nonatomic, strong) XLFormRowDescriptor *languageRow;
@property (nonatomic, strong) XLFormRowDescriptor *notificationsRow;
@property (nonatomic, strong) XLFormOptionsObject *optArabic;
@property (nonatomic, strong) XLFormOptionsObject *optEnglish;
@property (nonatomic, assign) BOOL alertAppear;
@property (nonatomic, assign) BOOL isUpdatingNotificationToggle;
@end

@implementation SettingVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.prefs = [NSUserDefaults standardUserDefaults];
    self.alertAppear = NO;

    [self pp_setupAppearance];
    [self initForms];
    [self pp_setupNotificationObservers];
    [self pp_refreshNotificationStatus];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_refreshNotificationStatus];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pp_setupAppearance {
    self.view.layer.cornerRadius = 42;
    self.view.layer.masksToBounds = YES;
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);

    if (self.mTitleLabel) {
        self.mTitleLabel.font = [GM boldFontWithSize:22];
        self.mTitleLabel.text = kLang(@"Setting");
    }

    if (self.topView) {
        self.topView.translatesAutoresizingMaskIntoConstraints = YES;
    }
}

#pragma mark - Actions

- (IBAction)dismissMe:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)popBTN:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)dismissSettingBTN:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)changeLanguage {
    [self showLanguageSetupAlertFrom:self];
}

#pragma mark - Form

- (void)initForms {
    self.mform = [XLFormDescriptor formDescriptorWithTitle:nil];
    self.mform.assignFirstResponderOnShow = NO;

    __weak typeof(self) weakSelf = self;

    XLFormSectionDescriptor *appSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"AppSetting")];
    [self.mform addFormSection:appSection];

    XLFormRowDescriptor *darkModeRow = [XLFormRowDescriptor formRowDescriptorWithTag:kDarkSet
                                                                              rowType:XLFormRowDescriptorTypeBooleanSwitch
                                                                                title:kLang(@"DarkSetPalce")];
    [darkModeRow.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    [darkModeRow.cellConfigAtConfigure setObject:[GM appPrimaryColor] forKey:@"switchControl.onTintColor"];
    darkModeRow.height = 44;
    UIUserInterfaceStyle savedStyle = [self loadUserInterfaceStyle];
    BOOL isDark = (savedStyle == UIUserInterfaceStyleDark);
    darkModeRow.value = @(isDark);
    darkModeRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        [weakSelf pp_applyThemeIsDark:[newValue boolValue]];
    };
    [appSection addFormRow:darkModeRow];

    XLFormRowDescriptor *autoPlayRow = [XLFormRowDescriptor formRowDescriptorWithTag:kautoPlaySet
                                                                              rowType:XLFormRowDescriptorTypeBooleanSwitch
                                                                                title:kLang(@"autoPlaySetPalce")];
    [autoPlayRow.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    [autoPlayRow.cellConfigAtConfigure setObject:[GM appPrimaryColor] forKey:@"switchControl.onTintColor"];
    autoPlayRow.height = 44;
    autoPlayRow.value = @([self.prefs boolForKey:kSettingsAutoPlayKey]);
    autoPlayRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        [weakSelf.prefs setBool:[newValue boolValue] forKey:kSettingsAutoPlayKey];
    };
    [appSection addFormRow:autoPlayRow];

    self.languageRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"languageSegment"
                                                              rowType:XLFormRowDescriptorTypeSelectorSegmentedControl
                                                                title:kLang(@"changelanguage")];
    [self.languageRow.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    self.languageRow.height = 80;

    self.optEnglish = [XLFormOptionsObject formOptionsObjectWithValue:@(0) displayText:kLang(@"English")];
    self.optArabic = [XLFormOptionsObject formOptionsObjectWithValue:@(1) displayText:kLang(@"Arabic")];
    self.languageRow.selectorOptions = @[self.optArabic, self.optEnglish];
    self.languageRow.value = Language.isRTL ? self.optArabic : self.optEnglish;
    self.languageRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        XLFormOptionsObject *obj = [newValue isKindOfClass:XLFormOptionsObject.class] ? (XLFormOptionsObject *)newValue : nil;
        NSInteger selectedIndex = [obj.formValue integerValue];
        if (selectedIndex == [Language languageVal]) {
            return;
        }
        [weakSelf showLanguageSetupAlertFrom:weakSelf];
    };
    [appSection addFormRow:self.languageRow];

    XLFormSectionDescriptor *privacySection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"PrivacySetting")];
    [self.mform addFormSection:privacySection];

    XLFormRowDescriptor *notificationsRow = [XLFormRowDescriptor formRowDescriptorWithTag:knotificationsSet
                                                                                   rowType:XLFormRowDescriptorTypeBooleanSwitch
                                                                                     title:kLang(@"notificationsSetPalce")];
    [notificationsRow.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    [notificationsRow.cellConfigAtConfigure setObject:[GM appPrimaryColor] forKey:@"switchControl.onTintColor"];
    notificationsRow.height = 44;
    notificationsRow.value = @([self.prefs boolForKey:knotificationsSet]);
    notificationsRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        if (weakSelf.isUpdatingNotificationToggle) {
            return;
        }
        [weakSelf pp_handleNotificationToggle:[newValue boolValue]];
    };
    [privacySection addFormRow:notificationsRow];
    self.notificationsRow = notificationsRow;

    XLFormRowDescriptor *messagesRow = [XLFormRowDescriptor formRowDescriptorWithTag:kmessagesSet
                                                                              rowType:XLFormRowDescriptorTypeSelectorAlertView
                                                                                title:kLang(@"kmessagesSetPalce")];
    [messagesRow.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    messagesRow.height = 44;

    XLFormOptionsObject *everyoneOption = [XLFormOptionsObject formOptionsObjectWithValue:@(0)
                                                                                displayText:kLang(@"everyone")];
    XLFormOptionsObject *noOneOption = [XLFormOptionsObject formOptionsObjectWithValue:@(1)
                                                                             displayText:kLang(@"noOne")];
    messagesRow.selectorOptions = @[everyoneOption, noOneOption];

    NSInteger savedPrivacy = [self.prefs integerForKey:kSettingsMessagesPrivacyKey];
    messagesRow.value = (savedPrivacy == 1) ? noOneOption : everyoneOption;
    messagesRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        XLFormOptionsObject *obj = [newValue isKindOfClass:XLFormOptionsObject.class] ? (XLFormOptionsObject *)newValue : nil;
        [weakSelf.prefs setInteger:[obj.formValue integerValue] forKey:kSettingsMessagesPrivacyKey];
    };
    [privacySection addFormRow:messagesRow];

    self.form = self.mform;
    self.tableView.backgroundColor = AppBackgroundClr;
    self.tableView.scrollEnabled = YES;
    UIEdgeInsets inset = UIEdgeInsetsMake(12, 0, 20, 0);
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self pp_layoutTableView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_layoutTableView];
}

- (void)pp_layoutTableView
{
    if (!self.tableView) {
        return;
    }
    CGFloat top = 0.0;
    if (self.topView) {
        top = CGRectGetMaxY(self.topView.frame);
    }
    CGFloat bottom = 0.0;
    if (@available(iOS 11.0, *)) {
        bottom = self.view.safeAreaInsets.bottom;
    }

    CGFloat height = CGRectGetHeight(self.view.bounds) - top - bottom;
    height = MAX(0.0, height);

    self.tableView.frame = CGRectMake(0.0, top, CGRectGetWidth(self.view.bounds), height);
}

#pragma mark - Theme

- (void)pp_applyThemeIsDark:(BOOL)isDark {
    UIUserInterfaceStyle style = isDark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    [self saveUserInterfaceStyle:style];

    [self.prefs setObject:(isDark ? @"dark" : @"light") forKey:@"themePreference"];

    if (@available(iOS 13.0, *)) {
        UIWindow *window = [self keyWindow];
        if (window) {
            window.overrideUserInterfaceStyle = style;
        }
    }

    [self.tableView reloadData];
}

- (void)saveUserInterfaceStyle:(UIUserInterfaceStyle)style {
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:kUserInterfaceStyleKey];
}

- (UIUserInterfaceStyle)loadUserInterfaceStyle {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kUserInterfaceStyleKey] != nil) {
        return (UIUserInterfaceStyle)[defaults integerForKey:kUserInterfaceStyleKey];
    }

    NSString *legacyTheme = [defaults stringForKey:@"themePreference"];
    if ([legacyTheme isEqualToString:@"dark"]) {
        return UIUserInterfaceStyleDark;
    }
    if ([legacyTheme isEqualToString:@"light"]) {
        return UIUserInterfaceStyleLight;
    }
    return UIUserInterfaceStyleUnspecified;
}

#pragma mark - Language

- (void)showLanguageSetupAlertFrom:(UIViewController *)viewController {
    if (self.alertAppear) {
        return;
    }

    self.alertAppear = YES;

    NSString *title = kLang(@"Language Setup");
    NSString *changeTitle = ([Language languageVal] == 0) ? kLang(@"Switch to Arabic") : kLang(@"Switch to English");
    NSString *cancelTitle = kLang(@"cancel");

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:(viewController ?: AppMgr.topViewController)
                                title:title
                             subtitle:changeTitle
                        confirmButton:changeTitle
                         cancelButton:cancelTitle
                                 icon:PPSYSImage(@"globe.central.south.asia.fill")
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (!didConfirm) {
            strongSelf.alertAppear = NO;
            return;
        }

        NSInteger newLangVal = ([Language languageVal] == 0) ? 1 : 0;
        [Language userSelectedLanguage:LanguageCode[newLangVal]];

        if ([strongSelf.delegate respondsToSelector:@selector(changeLanguageWithCode:)]) {
            [strongSelf.delegate changeLanguageWithCode:(int)newLangVal];
        }

        [strongSelf applyLanguageChangeAndReloadUIFrom:strongSelf];
        strongSelf.alertAppear = NO;
    }
                           cancelBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.languageRow.value = Language.isRTL ? strongSelf.optArabic : strongSelf.optEnglish;
        [strongSelf updateFormRow:strongSelf.languageRow];
        strongSelf.alertAppear = NO;
    }];
}

- (void)pp_setupNotificationObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleAppWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)pp_handleAppWillEnterForeground
{
    [self pp_refreshNotificationStatus];
}

- (void)pp_refreshNotificationStatus
{
    if (!self.notificationsRow) {
        return;
    }

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        BOOL authorized = (settings.authorizationStatus == UNAuthorizationStatusAuthorized ||
                           settings.authorizationStatus == UNAuthorizationStatusProvisional ||
                           settings.authorizationStatus == UNAuthorizationStatusEphemeral);

        BOOL prefEnabled = [self.prefs boolForKey:knotificationsSet];
        if (!authorized && prefEnabled) {
            [self.prefs setBool:NO forKey:knotificationsSet];
            prefEnabled = NO;
        }

        BOOL effective = (authorized && prefEnabled);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_updateNotificationRowValue:effective];
        });
    }];
}

- (void)pp_updateNotificationRowValue:(BOOL)isOn
{
    if (!self.notificationsRow) {
        return;
    }

    self.isUpdatingNotificationToggle = YES;
    self.notificationsRow.value = @(isOn);
    [self updateFormRow:self.notificationsRow];
    self.isUpdatingNotificationToggle = NO;
}

- (void)pp_handleNotificationToggle:(BOOL)isOn
{
    if (isOn) {
        [self pp_requestNotificationAuthorization];
        return;
    }

    [self.prefs setBool:NO forKey:knotificationsSet];
}

- (void)pp_requestNotificationAuthorization
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options =
        (UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge);

    __weak typeof(self) weakSelf = self;
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error) {
                NSLog(@"[Settings] Notification permission error: %@", error.localizedDescription);
            }

            if (granted) {
                [strongSelf.prefs setBool:YES forKey:knotificationsSet];
                [strongSelf pp_updateNotificationRowValue:YES];
                [UIApplication.sharedApplication registerForRemoteNotifications];
            } else {
                [strongSelf.prefs setBool:NO forKey:knotificationsSet];
                [strongSelf pp_updateNotificationRowValue:NO];
                [PPHUD showError:kLang(@"Notifications permission denied")];
            }
        });
    }];
}

- (void)applyLanguageChangeAndReloadUIFrom:(UIViewController *)sourceVC {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        if (!window) {
            return;
        }

        UIViewController *newRoot = [self buildRootController];
        if (!newRoot) {
            return;
        }

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
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

- (UIViewController *)buildRootController {
    return [[PPRootTabBarController alloc] init];
}

@end
