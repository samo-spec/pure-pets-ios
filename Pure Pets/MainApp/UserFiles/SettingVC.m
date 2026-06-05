//
//  SettingVC.m
//  Pure Pets

#import "SettingVC.h"
#import "PPRootTabBarController.h"
#import "ProfileVC.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "PPFirebaseSessionBridge.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SafariServices/SFSafariViewController.h>
@import FirebaseFunctions;
@import UserNotifications;




static NSString *const kSettingsAutoPlayKey        = @"isAutoPlaySet";
static NSString *const kSettingsMessagesPrivacyKey = @"messagesPrivacyValue";
static NSString *const kSettingsNotificationsKey   = @"notificationsSet";
NSString * const PPThemePreferenceDidChangeNotification = @"PPThemePreferenceDidChangeNotification";

// MARK: Legal URLs — update these to the production website URLs when available.
static NSString *const kPPPrivacyPolicyURL   = @"https://pure-pets.net/privacy";
static NSString *const kPPTermsOfServiceURL  = @"https://pure-pets.net";

static NSString *PPSettingsLocalizedString(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    if ([value isKindOfClass:NSString.class] &&
        value.length > 0 &&
        ![value isEqualToString:key]) {
        return value;
    }
    return fallback ?: key ?: @"";
}

static BOOL PPSettingsTextContainsAnyToken(NSString *text, NSArray<NSString *> *tokens)
{
    if (text.length == 0) return NO;
    for (NSString *token in tokens) {
        if (token.length > 0 && [text containsString:token]) {
            return YES;
        }
    }
    return NO;
}

static void PPSettingsAppendErrorText(NSError *error, NSMutableArray<NSString *> *parts, NSUInteger depth)
{
    if (!error || depth > 2) return;
    if (error.localizedDescription.length) [parts addObject:error.localizedDescription];
    if (error.localizedFailureReason.length) [parts addObject:error.localizedFailureReason];
    if (error.localizedRecoverySuggestion.length) [parts addObject:error.localizedRecoverySuggestion];

    for (id value in error.userInfo.allValues) {
        if ([value isKindOfClass:NSString.class]) {
            [parts addObject:(NSString *)value];
        } else if ([value isKindOfClass:NSError.class]) {
            PPSettingsAppendErrorText((NSError *)value, parts, depth + 1);
        } else if ([value isKindOfClass:NSDictionary.class] ||
                   [value isKindOfClass:NSArray.class]) {
            [parts addObject:[value description]];
        }
    }
}

static NSString *PPSettingsCombinedErrorText(NSError *error)
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    PPSettingsAppendErrorText(error, parts, 0);
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

static BOOL PPSettingsDeleteAccountErrorRequiresRecentLogin(NSError *error)
{
    if (!error) return NO;
    if (error.code == FIRAuthErrorCodeRequiresRecentLogin) return YES;

    NSString *text = PPSettingsCombinedErrorText(error);
    return PPSettingsTextContainsAnyToken(text, @[
        @"requires-recent-login",
        @"requires_recent_login",
        @"recent login",
        @"recent sign-in",
        @"recent sign in",
        @"recent re-auth",
        @"recent reauth",
        @"reauthenticate",
        @"reauthentication",
        @"sign in again",
        @"sign-in again",
        @"session refresh",
        @"could not refresh your session",
        @"couldn't refresh your session"
    ]);
}

static BOOL PPSettingsDeleteAccountErrorIsOffline(NSError *error)
{
    NSString *text = PPSettingsCombinedErrorText(error);
    return PPSettingsTextContainsAnyToken(text, @[
        @"client is offline",
        @"network is unavailable",
        @"network connection was lost",
        @"internet connection appears to be offline",
        @"timed out"
    ]) ||
    error.code == FIRFunctionsErrorCodeUnavailable ||
    error.code == FIRFunctionsErrorCodeDeadlineExceeded;
}

static BOOL PPSettingsDeleteAccountErrorIsDeviceVerification(NSError *error)
{
    NSString *text = PPSettingsCombinedErrorText(error);
    return PPSettingsTextContainsAnyToken(text, @[
        @"app check",
        @"appcheck",
        @"app attest",
        @"appattest",
        @"devicecheck",
        @"device check"
    ]);
}

static NSString *PPSettingsDeleteAccountFailureMessage(NSError *error)
{
    if (PPSettingsDeleteAccountErrorRequiresRecentLogin(error)) {
        return PPSettingsLocalizedString(@"delete_account_session_verify_message",
                                         @"We could not verify this account deletion request. Please try deleting your account again.");
    }

    if (PPSettingsDeleteAccountErrorIsOffline(error)) {
        return PPSettingsLocalizedString(@"delete_account_offline_message",
                                         @"Please check your connection, then try deleting your account again.");
    }

    if (PPSettingsDeleteAccountErrorIsDeviceVerification(error)) {
        return PPSettingsLocalizedString(@"delete_account_device_verification_message",
                                         @"We could not verify this device right now. Please try again.");
    }

    if ([PPFirebaseSessionBridge isAuthOrAppCheckError:error] ||
        error.code == FIRFunctionsErrorCodeUnauthenticated) {
        return PPSettingsLocalizedString(@"delete_account_sign_in_required_message",
                                         @"Please sign in again, then return to Settings and delete your account.");
    }

    if (error.code == FIRFunctionsErrorCodePermissionDenied) {
        return PPSettingsLocalizedString(@"delete_account_permission_denied_message",
                                         @"We could not verify this account deletion request. Please sign in again and retry.");
    }

    return PPSettingsLocalizedString(@"delete_account_failed_message",
                                     @"We could not delete your account right now. Please try again in a moment.");
}

static NSString *PPSettingsLogoutFailureMessage(NSError *error)
{
    NSString *message = [PPFirebaseSessionBridge publicMessageForError:error fallbackKey:@"logout_failed_message"];
    if ([message isKindOfClass:NSString.class] &&
        message.length > 0 &&
        ![message isEqualToString:@"logout_failed_message"]) {
        return message;
    }
    return PPSettingsLocalizedString(@"logout_failed_message",
                                     @"We could not log you out right now. Please try again.");
}

#pragma mark - PPSettingsRowModel

typedef NS_ENUM(NSInteger, PPSettingsRowType) {
    PPSettingsRowTypeProfile,
    PPSettingsRowTypeToggle,
    PPSettingsRowTypeNavigation,
    PPSettingsRowTypeSegment,
    PPSettingsRowTypeDestructive,
    PPSettingsRowTypeVersion,
    PPSettingsRowTypeLanguage,
    PPSettingsRowTypeThemePicker
};

@interface PPSettingsRowModel : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *iconName;
@property (nonatomic, strong, nullable) UIColor *iconTint;
@property (nonatomic, strong, nullable) UIColor *iconBackground;
@property (nonatomic, assign) PPSettingsRowType type;
@property (nonatomic, assign) BOOL toggleValue;
@property (nonatomic, assign) BOOL toggleEnabled;
@property (nonatomic, copy, nullable) NSArray<NSString *> *segmentTitles;
@property (nonatomic, assign) NSInteger segmentIndex;
@property (nonatomic, copy, nullable) void (^onToggle)(BOOL isOn);
@property (nonatomic, copy, nullable) void (^onTap)(void);
@property (nonatomic, copy, nullable) void (^onSegmentChange)(NSInteger index);
// Language dual-button
@property (nonatomic, assign) NSInteger languageIndex; // 0=Arabic, 1=English
@property (nonatomic, copy, nullable) void (^onLanguageTap)(NSInteger index);
// Theme picker: 0=Light, 1=Dark, 2=System
@property (nonatomic, assign) NSInteger themeIndex;
@property (nonatomic, copy, nullable) void (^onThemeTap)(NSInteger index);
@end

@implementation PPSettingsRowModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _toggleEnabled = YES;
    }
    return self;
}

@end

#pragma mark - PPSettingsSectionModel

@interface PPSettingsSectionModel : NSObject
@property (nonatomic, copy, nullable) NSString *headerTitle;
@property (nonatomic, copy, nullable) NSString *footerTitle;
@property (nonatomic, strong) NSArray<PPSettingsRowModel *> *rows;
@end

@implementation PPSettingsSectionModel
@end

#pragma mark - Cell IDs

static NSString *const kSettingsCellID  = @"PPSettingsCell";
static NSString *const kProfileCellID   = @"PPProfileCell";
static NSString *const kVersionCellID   = @"PPVersionCell";
static NSString *const kLanguageCellID  = @"PPLanguageCell";
static NSString *const kThemeCellID    = @"PPThemeCell";

#pragma mark - SettingVC

@interface SettingVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPSettingsSectionModel *> *sections;
@property (nonatomic, strong) NSUserDefaults *prefs;
@property (nonatomic, assign) BOOL alertAppear;
@end

@implementation SettingVC

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.prefs = [NSUserDefaults standardUserDefaults];
    self.alertAppear = NO;
    self.view.backgroundColor = AppBageColor();
    self.navigationItem.title = kLang(@"Setting");

    [self pp_setupTableView];
    [self pp_buildSections];
    [self pp_setupNotificationObservers];
    
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
 }

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_buildSections];
    [self.tableView reloadData];
    [self pp_refreshNotificationStatusAsync];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table View Setup

- (void)pp_setupTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 56, 0, 0);
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56.0;

    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kSettingsCellID];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kProfileCellID];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kVersionCellID];

    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark - Build Sections

- (void)pp_buildSections
{
    NSMutableArray<PPSettingsSectionModel *> *allSections = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    // Section: Profile
    if (PPIsUserLoggedIn) {
        PPSettingsSectionModel *profileSection = [PPSettingsSectionModel new];
        PPSettingsRowModel *profileRow = [PPSettingsRowModel new];
        profileRow.type = PPSettingsRowTypeProfile;
        id currentUser = PPCurrentUser ?: UserManager.sharedManager.currentUser;
        profileRow.title = PPSafeString([currentUser valueForKey:@"PPBestDisplayName"]);
        if (profileRow.title.length == 0) {
            profileRow.title = PPSafeString([currentUser valueForKey:@"UserName"]);
        }
        profileRow.subtitle = kLang(@"ViewProfile") ?: @"View profile";
        profileRow.onTap = ^{ [weakSelf pp_openProfile]; };
        profileSection.rows = @[profileRow];
        [allSections addObject:profileSection];
    }

    // Section: Appearance (separate section with 3-button theme picker)
    PPSettingsSectionModel *appearanceSection = [PPSettingsSectionModel new];
    appearanceSection.headerTitle = kLang(@"Appearance") ?: @"Appearance";
    PPSettingsRowModel *themeRow = [PPSettingsRowModel new];
    themeRow.type = PPSettingsRowTypeThemePicker;
    themeRow.title = kLang(@"DarkSetPalce") ?: @"Appearance";
    themeRow.iconName = @"moon.fill";
    themeRow.iconTint = UIColor.whiteColor;
    themeRow.iconBackground = [UIColor colorWithRed:0.38 green:0.22 blue:0.72 alpha:1.0];
    UIUserInterfaceStyle currentStyle = [self loadUserInterfaceStyle];
    if (currentStyle == UIUserInterfaceStyleLight) {
        themeRow.themeIndex = 0;
    } else if (currentStyle == UIUserInterfaceStyleDark) {
        themeRow.themeIndex = 1;
    } else {
        themeRow.themeIndex = 2;
    }
    themeRow.onThemeTap = ^(NSInteger index) { [weakSelf pp_applyThemeAtIndex:index]; };
    appearanceSection.rows = @[themeRow];
    [allSections addObject:appearanceSection];

    // Section: App Settings
    PPSettingsSectionModel *appSection = [PPSettingsSectionModel new];
    appSection.headerTitle = kLang(@"AppSetting");
    NSMutableArray<PPSettingsRowModel *> *appRows = [NSMutableArray array];

    PPSettingsRowModel *autoPlayRow = [PPSettingsRowModel new];
    autoPlayRow.type = PPSettingsRowTypeToggle;
    autoPlayRow.title = kLang(@"autoPlaySetPalce") ?: @"Auto-play Videos";
    autoPlayRow.iconName = @"play.circle.fill";
    autoPlayRow.iconTint = UIColor.whiteColor;
    autoPlayRow.iconBackground = [UIColor systemBlueColor];
    autoPlayRow.toggleValue = [self.prefs boolForKey:kSettingsAutoPlayKey];
    autoPlayRow.onToggle = ^(BOOL isOn) { [weakSelf.prefs setBool:isOn forKey:kSettingsAutoPlayKey]; };
    [appRows addObject:autoPlayRow];

    PPSettingsRowModel *langRow = [PPSettingsRowModel new];
    langRow.type = PPSettingsRowTypeLanguage;
    langRow.title = kLang(@"Language") ?: @"Language";
    langRow.iconName = @"globe";
    langRow.iconTint = UIColor.whiteColor;
    langRow.iconBackground = [UIColor systemTealColor];
    langRow.languageIndex = Language.isRTL ? 0 : 1;
    langRow.onLanguageTap = ^(NSInteger index) {
        NSInteger currentIndex = [Language languageVal] == 0 ? 1 : 0;
        if (index == currentIndex) return;
        [weakSelf showLanguageSetupAlertFrom:weakSelf];
    };
    [appRows addObject:langRow];

    appSection.rows = appRows;
    [allSections addObject:appSection];

    // Section: Privacy
    PPSettingsSectionModel *privacySection = [PPSettingsSectionModel new];
    privacySection.headerTitle = kLang(@"PrivacySetting");
    NSMutableArray<PPSettingsRowModel *> *privacyRows = [NSMutableArray array];

    PPSettingsRowModel *notiRow = [PPSettingsRowModel new];
    notiRow.type = PPSettingsRowTypeToggle;
    notiRow.title = kLang(@"notificationsSetPalce") ?: @"Notifications";
    notiRow.iconName = @"bell.badge.fill";
    notiRow.iconTint = UIColor.whiteColor;
    notiRow.iconBackground = [UIColor systemRedColor];
    notiRow.toggleValue = [self.prefs boolForKey:kSettingsNotificationsKey];
    notiRow.onToggle = ^(BOOL isOn) { [weakSelf pp_handleNotificationToggle:isOn]; };
    [privacyRows addObject:notiRow];

    NSInteger savedPrivacy = [self.prefs integerForKey:kSettingsMessagesPrivacyKey];
    PPSettingsRowModel *messagesRow = [PPSettingsRowModel new];
    messagesRow.type = PPSettingsRowTypeNavigation;
    messagesRow.title = kLang(@"kmessagesSetPalce") ?: @"Messages";
    messagesRow.subtitle = (savedPrivacy == 1) ? (kLang(@"noOne") ?: @"No one") : (kLang(@"everyone") ?: @"Everyone");
    messagesRow.iconName = @"message.fill";
    messagesRow.iconTint = UIColor.whiteColor;
    messagesRow.iconBackground = [UIColor systemGreenColor];
    messagesRow.onTap = ^{ [weakSelf pp_showMessagesPrivacyPicker]; };
    [privacyRows addObject:messagesRow];

    privacySection.rows = privacyRows;
    [allSections addObject:privacySection];

    // Section: Storage
    PPSettingsSectionModel *storageSection = [PPSettingsSectionModel new];
    storageSection.headerTitle = kLang(@"Storage") ?: @"Storage";
    PPSettingsRowModel *clearCacheRow = [PPSettingsRowModel new];
    clearCacheRow.type = PPSettingsRowTypeNavigation;
    clearCacheRow.title = kLang(@"ClearCache") ?: @"Clear Cache";
    clearCacheRow.iconName = @"trash.circle.fill";
    clearCacheRow.iconTint = UIColor.whiteColor;
    clearCacheRow.iconBackground = [UIColor systemOrangeColor];
    clearCacheRow.subtitle = [self pp_formattedCacheSize];
    clearCacheRow.onTap = ^{ [weakSelf pp_clearCache]; };
    storageSection.rows = @[clearCacheRow];
    [allSections addObject:storageSection];

    // Section: Legal
    PPSettingsSectionModel *legalSection = [PPSettingsSectionModel new];
    legalSection.headerTitle = kLang(@"LegalSectionHeader") ?: @"Legal";
    NSMutableArray<PPSettingsRowModel *> *legalRows = [NSMutableArray array];

    PPSettingsRowModel *privacyPolicyRow = [PPSettingsRowModel new];
    privacyPolicyRow.type = PPSettingsRowTypeNavigation;
    privacyPolicyRow.title = kLang(@"PrivacyPolicy") ?: @"Privacy Policy";
    privacyPolicyRow.iconName = @"hand.raised.fill";
    privacyPolicyRow.iconTint = UIColor.whiteColor;
    privacyPolicyRow.iconBackground = [UIColor systemIndigoColor];
    privacyPolicyRow.onTap = ^{ [weakSelf pp_openLegalURL:kPPPrivacyPolicyURL]; };
    [legalRows addObject:privacyPolicyRow];

    PPSettingsRowModel *termsRow = [PPSettingsRowModel new];
    termsRow.type = PPSettingsRowTypeNavigation;
    termsRow.title = kLang(@"TermsOfService") ?: @"Terms of Service";
    termsRow.iconName = @"doc.text.fill";
    termsRow.iconTint = UIColor.whiteColor;
    termsRow.iconBackground = [UIColor systemGrayColor];
    termsRow.onTap = ^{ [weakSelf pp_openLegalURL:kPPTermsOfServiceURL]; };
    [legalRows addObject:termsRow];

    legalSection.rows = legalRows;
    [allSections addObject:legalSection];

    // Section: Account
    if (PPIsUserLoggedIn) {
        PPSettingsSectionModel *accountSection = [PPSettingsSectionModel new];
        NSMutableArray<PPSettingsRowModel *> *accountRows = [NSMutableArray array];

        PPSettingsRowModel *deleteAccountRow = [PPSettingsRowModel new];
        deleteAccountRow.type = PPSettingsRowTypeDestructive;
        deleteAccountRow.title = kLang(@"delete_account") ?: @"Delete Account";
        deleteAccountRow.iconName = @"person.crop.circle.badge.minus";
        deleteAccountRow.iconTint = UIColor.whiteColor;
        deleteAccountRow.iconBackground = [UIColor systemRedColor];
        deleteAccountRow.onTap = ^{ [weakSelf pp_confirmDeleteAccount]; };
        [accountRows addObject:deleteAccountRow];

        PPSettingsRowModel *logoutRow = [PPSettingsRowModel new];
        logoutRow.type = PPSettingsRowTypeDestructive;
        logoutRow.title = kLang(@"Logout") ?: @"Logout";
        logoutRow.iconName = @"rectangle.portrait.and.arrow.right";
        logoutRow.iconTint = UIColor.whiteColor;
        logoutRow.iconBackground = [UIColor systemRedColor];
        logoutRow.onTap = ^{ [weakSelf pp_confirmLogout]; };
        [accountRows addObject:logoutRow];

        accountSection.rows = [accountRows copy];
        [allSections addObject:accountSection];
    }

    // Section: Version
    PPSettingsSectionModel *versionSection = [PPSettingsSectionModel new];
    PPSettingsRowModel *versionRow = [PPSettingsRowModel new];
    versionRow.type = PPSettingsRowTypeVersion;
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *build   = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    versionRow.title = [NSString stringWithFormat:@"Pure Pets v%@ (%@)", version, build];
    versionSection.rows = @[versionRow];
    [allSections addObject:versionSection];

    self.sections = [allSections copy];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.sections[section].rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    switch (row.type) {
        case PPSettingsRowTypeProfile:
            return [self pp_profileCellForRow:row tableView:tableView];
        case PPSettingsRowTypeVersion:
            return [self pp_versionCellForRow:row tableView:tableView];
        case PPSettingsRowTypeToggle:
            return [self pp_toggleCellForRow:row tableView:tableView indexPath:indexPath];
        case PPSettingsRowTypeSegment:
            return [self pp_segmentCellForRow:row tableView:tableView];
        case PPSettingsRowTypeLanguage:
            return [self pp_languageCellForRow:row tableView:tableView];
        case PPSettingsRowTypeThemePicker:
            return [self pp_themeCellForRow:row tableView:tableView];
        case PPSettingsRowTypeNavigation:
        case PPSettingsRowTypeDestructive:
            return [self pp_navigationCellForRow:row tableView:tableView];
    }
    return [tableView dequeueReusableCellWithIdentifier:kSettingsCellID forIndexPath:indexPath];
}

#pragma mark - Cell Builders

- (UITableViewCell *)pp_profileCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kProfileCellID];
    cell.textLabel.text = row.title.length > 0 ? row.title : (kLang(@"Guest") ?: @"Guest");
    cell.textLabel.font = [GM boldFontWithSize:18];
    cell.textLabel.textColor = AppPrimaryTextClr;
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.font = [GM fontWithSize:13];
    cell.detailTextLabel.textColor = AppSecondaryTextClr;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = AppForgroundColr;

    CGFloat avatarSize = 40.0;
    UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, avatarSize, avatarSize)];
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.layer.cornerRadius = avatarSize / 2.0;
    avatarView.clipsToBounds = YES;
    avatarView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.1];

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:PPCurrentUser.UserName size:40];
    avatarView.image = placeholder;

    id currentUser = PPCurrentUser ?: UserManager.sharedManager.currentUser;
    NSURL *avatarURL = [currentUser valueForKey:@"UserImageUrl"];
    if (avatarURL) {
        [avatarView sd_setImageWithURL:avatarURL
                      placeholderImage:placeholder
                               options:SDWebImageRetryFailed
                             completed:nil];
        avatarView.contentMode = UIViewContentModeScaleAspectFill;
    }

    cell.imageView.image = placeholder;
    // Force layout to get imageView frame, then replace with custom avatar
    [cell layoutIfNeeded];
    for (UIView *subview in cell.contentView.subviews) {
        if (subview == cell.imageView) {
            avatarView.frame = CGRectMake(0, 0, avatarSize, avatarSize);
            cell.imageView.image = [self pp_transparentImageOfSize:CGSizeMake(avatarSize, avatarSize)];
            avatarView.tag = 9999;
            UIView *existing = [cell.contentView viewWithTag:9999];
            [existing removeFromSuperview];
            avatarView.translatesAutoresizingMaskIntoConstraints = NO;
            [cell.contentView addSubview:avatarView];
            [NSLayoutConstraint activateConstraints:@[
                [avatarView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16.0],
                [avatarView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [avatarView.widthAnchor constraintEqualToConstant:avatarSize],
                [avatarView.heightAnchor constraintEqualToConstant:avatarSize]
            ]];
            break;
        }
    }

    return cell;
}

- (UIImage *)pp_transparentImageOfSize:(CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UITableViewCell *)pp_toggleCellForRow:(PPSettingsRowModel *)row
                               tableView:(UITableView *)tableView
                               indexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kSettingsCellID];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [GM MidFontWithSize:15];
    cell.textLabel.textColor = AppPrimaryTextClr;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = AppForgroundColr;
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.font = [GM fontWithSize:12];
    cell.detailTextLabel.textColor = AppSecondaryTextClr;
    cell.detailTextLabel.numberOfLines = 2;
    cell.imageView.image = [self pp_iconImageForName:row.iconName tint:row.iconTint background:row.iconBackground];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = row.toggleValue;
    toggle.onTintColor = AppPrimaryClr;
    toggle.enabled = row.toggleEnabled;
    toggle.userInteractionEnabled = row.toggleEnabled;
    toggle.alpha = row.toggleEnabled ? 1.0 : 0.65;
    toggle.tag = indexPath.section * 100 + indexPath.row;
    [toggle addTarget:self action:@selector(pp_switchToggled:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (UITableViewCell *)pp_segmentCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kSettingsCellID];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [GM MidFontWithSize:15];
    cell.textLabel.textColor = AppPrimaryTextClr;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = AppForgroundColr;
    cell.imageView.image = [self pp_iconImageForName:row.iconName tint:row.iconTint background:row.iconBackground];

    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:row.segmentTitles];
    segment.selectedSegmentIndex = row.segmentIndex;
    segment.frame = CGRectMake(0, 0, 160, 30);
    [segment setTitleTextAttributes:@{NSFontAttributeName: [GM fontWithSize:12]} forState:UIControlStateNormal];
    [segment addTarget:self action:@selector(pp_segmentChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = segment;
    return cell;
}

- (UITableViewCell *)pp_languageCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kLanguageCellID];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [GM MidFontWithSize:15];
    cell.textLabel.textColor = AppPrimaryTextClr;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = AppForgroundColr;
    cell.imageView.image = [self pp_iconImageForName:row.iconName tint:row.iconTint background:row.iconBackground];

    BOOL isArabicActive = (row.languageIndex == 0);

    NSString *arabicTitle = @"العربية";
    NSString *englishTitle = @"English";

    UIColor *activeBg = AppPrimaryClr ?: [UIColor systemOrangeColor];
    UIColor *activeFg = UIColor.whiteColor;
    UIColor *inactiveBg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.08]
            : [[UIColor blackColor] colorWithAlphaComponent:0.05];
    }];
    UIColor *inactiveFg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.6]
            : [[UIColor blackColor] colorWithAlphaComponent:0.55];
    }];
    UIColor *inactiveBorder = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.12]
            : [[UIColor blackColor] colorWithAlphaComponent:0.1];
    }];

    // Arabic button
    UIButton *arabicBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    arabicBtn.translatesAutoresizingMaskIntoConstraints = NO;
    arabicBtn.tag = 0;
    [arabicBtn setTitle:arabicTitle forState:UIControlStateNormal];
    arabicBtn.titleLabel.font = [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    arabicBtn.layer.cornerRadius = 14.0;
    arabicBtn.clipsToBounds = YES;
    if (isArabicActive) {
        arabicBtn.backgroundColor = activeBg;
        [arabicBtn setTitleColor:activeFg forState:UIControlStateNormal];
        arabicBtn.layer.borderWidth = 0;
    } else {
        arabicBtn.backgroundColor = inactiveBg;
        [arabicBtn setTitleColor:inactiveFg forState:UIControlStateNormal];
        arabicBtn.layer.borderWidth = 1.0;
        [arabicBtn pp_setBorderColor:inactiveBorder];
    }
    [arabicBtn addTarget:self action:@selector(pp_languageButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // English button
    UIButton *englishBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    englishBtn.translatesAutoresizingMaskIntoConstraints = NO;
    englishBtn.tag = 1;
    [englishBtn setTitle:englishTitle forState:UIControlStateNormal];
    englishBtn.titleLabel.font = [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    englishBtn.layer.cornerRadius = 14.0;
    englishBtn.clipsToBounds = YES;
    if (!isArabicActive) {
        englishBtn.backgroundColor = activeBg;
        [englishBtn setTitleColor:activeFg forState:UIControlStateNormal];
        englishBtn.layer.borderWidth = 0;
    } else {
        englishBtn.backgroundColor = inactiveBg;
        [englishBtn setTitleColor:inactiveFg forState:UIControlStateNormal];
        englishBtn.layer.borderWidth = 1.0;
        [englishBtn pp_setBorderColor:inactiveBorder];
    }
    [englishBtn addTarget:self action:@selector(pp_languageButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // Container stack — use accessoryView so UIKit clips textLabel automatically
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[arabicBtn, englishBtn]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillEqually;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 168, 32)];
    [container addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    cell.accessoryView = container;

    return cell;
}

- (void)pp_languageButtonTapped:(UIButton *)sender
{
    NSInteger tappedIndex = sender.tag;
    for (PPSettingsSectionModel *section in self.sections) {
        for (PPSettingsRowModel *row in section.rows) {
            if (row.type == PPSettingsRowTypeLanguage && row.onLanguageTap) {
                row.onLanguageTap(tappedIndex);
                return;
            }
        }
    }
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) return nil;

    NSString *title = self.sections[section].headerTitle;
    if (title.length == 0) return nil;

    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.backgroundColor = UIColor.clearColor;
    container.layoutMargins = UIEdgeInsetsMake(0.0, PPScreenMargin + 2.0, 0.0, PPScreenMargin + 2.0);
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [GM boldFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    label.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.76] ?: [UIColor secondaryLabelColor];
    label.textAlignment = [Language alignmentForCurrentLanguage];
    label.numberOfLines = 1;
    label.adjustsFontForContentSizeCategory = YES;
    label.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [container addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.trailingAnchor],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-6.0]
    ]];

    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) return CGFLOAT_MIN;
    return self.sections[section].headerTitle.length > 0 ? 44.0 : CGFLOAT_MIN;
}

- (UITableViewCell *)pp_navigationCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSettingsCellID];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [GM MidFontWithSize:15];
    cell.backgroundColor = AppForgroundColr;
    if (row.type == PPSettingsRowTypeDestructive) {
        cell.textLabel.textColor = UIColor.systemRedColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.textColor = AppPrimaryTextClr;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.font = [GM fontWithSize:13];
    cell.detailTextLabel.textColor = AppSecondaryTextClr;
    cell.imageView.image = [self pp_iconImageForName:row.iconName tint:row.iconTint background:row.iconBackground];
    return cell;
}

- (UITableViewCell *)pp_versionCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kVersionCellID];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [GM fontWithSize:12];
    cell.textLabel.textColor = AppSecondaryTextClr;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.clearColor;
    return cell;
}

#pragma mark - Icon Builder

- (UIImage *)pp_iconImageForName:(NSString *)name tint:(UIColor *)tint background:(UIColor *)background
{
    CGFloat size = 30.0;
    CGFloat cornerRadius = 7.0;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size)
                                                          cornerRadius:cornerRadius];
    [(background ?: AppPrimaryClr) setFill];
    [roundedRect fill];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [[UIImage systemImageNamed:(name ?: @"gearshape") withConfiguration:config]
                       imageWithTintColor:(tint ?: UIColor.whiteColor) renderingMode:UIImageRenderingModeAlwaysOriginal];
    if (symbol) {
        CGSize symbolSize = symbol.size;
        CGFloat x = (size - symbolSize.width) / 2.0;
        CGFloat y = (size - symbolSize.height) / 2.0;
        [symbol drawInRect:CGRectMake(x, y, symbolSize.width, symbolSize.height)];
    }
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.onTap) { row.onTap(); }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.type == PPSettingsRowTypeProfile) return 72.0;
    if (row.type == PPSettingsRowTypeVersion) return 44.0;
    if (row.type == PPSettingsRowTypeLanguage) return 60.0;
    if (row.type == PPSettingsRowTypeThemePicker) return 96.0;
    return 52.0;
}

#pragma mark - Control Actions

- (void)pp_switchToggled:(UISwitch *)sender
{
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    if (section < (NSInteger)self.sections.count &&
        row < (NSInteger)self.sections[section].rows.count) {
        PPSettingsRowModel *model = self.sections[section].rows[row];
        model.toggleValue = sender.isOn;
        if (model.onToggle) { model.onToggle(sender.isOn); }
    }
}

- (void)pp_segmentChanged:(UISegmentedControl *)sender
{
    for (PPSettingsSectionModel *section in self.sections) {
        for (PPSettingsRowModel *row in section.rows) {
            if (row.type == PPSettingsRowTypeSegment && row.onSegmentChange) {
                row.onSegmentChange(sender.selectedSegmentIndex);
                return;
            }
        }
    }
}

#pragma mark - Profile

- (void)pp_openProfile
{
    ProfileVC *profileVC = [[ProfileVC alloc] init];
    [self.navigationController pushViewController:profileVC animated:YES];
}

#pragma mark - Theme

- (void)pp_applyThemeAtIndex:(NSInteger)index
{
    UIUserInterfaceStyle style;
    NSString *legacyKey;
    if (index == 0) {
        style = UIUserInterfaceStyleLight;
        legacyKey = @"light";
    } else if (index == 1) {
        style = UIUserInterfaceStyleDark;
        legacyKey = @"dark";
    } else {
        style = UIUserInterfaceStyleUnspecified;
        legacyKey = @"system";
    }
    [self saveUserInterfaceStyle:style];
    [self.prefs setObject:legacyKey forKey:@"themePreference"];
    UIWindow *window = [self pp_keyWindow];
    if (window) {
        [UIView transitionWithView:window
                          duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            window.overrideUserInterfaceStyle = style;
            [window setNeedsLayout];
            [window layoutIfNeeded];
            [window.rootViewController.view setNeedsLayout];
            [window.rootViewController.view layoutIfNeeded];
        } completion:^(__unused BOOL finished) {
            [window setNeedsLayout];
            [window layoutIfNeeded];
            [window.rootViewController.view setNeedsLayout];
            [window.rootViewController.view layoutIfNeeded];
            dispatch_async(dispatch_get_main_queue(), ^{
                [window setNeedsLayout];
                [window layoutIfNeeded];
                [window.rootViewController.view setNeedsLayout];
                [window.rootViewController.view layoutIfNeeded];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPThemePreferenceDidChangeNotification object:nil];
            });
        }];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:PPThemePreferenceDidChangeNotification object:nil];
    }
    [self pp_buildSections];
    [self.tableView reloadData];
}

- (UITableViewCell *)pp_themeCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kThemeCellID];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = AppForgroundColr;

    NSInteger activeIndex = row.themeIndex;

    UIColor *activeBg = AppPrimaryClr ?: [UIColor systemOrangeColor];
    UIColor *activeFg = UIColor.whiteColor;
    UIColor *inactiveBg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.08]
            : [[UIColor blackColor] colorWithAlphaComponent:0.05];
    }];
    UIColor *inactiveFg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.6]
            : [[UIColor blackColor] colorWithAlphaComponent:0.55];
    }];
    UIColor *inactiveBorder = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.12]
            : [[UIColor blackColor] colorWithAlphaComponent:0.1];
    }];

    NSArray<NSDictionary *> *items = @[
        @{ @"icon": @"sun.max.fill",          @"label": kLang(@"LightMode") ?: @"Light" },
        @{ @"icon": @"moon.fill",             @"label": kLang(@"DarkMode") ?: @"Dark" },
        @{ @"icon": @"iphone",                @"label": kLang(@"SystemMode") ?: @"System" },
    ];

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
        NSDictionary *item = items[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.tag = i;
        btn.layer.cornerRadius = 14.0;
        btn.clipsToBounds = YES;

        // Icon + label as attributed title
        NSString *iconName = item[@"icon"];
        NSString *label = item[@"label"];
        UIImageSymbolConfiguration *symConf = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:iconName withConfiguration:symConf];

        NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] init];
        if (icon) {
            NSTextAttachment *attach = [[NSTextAttachment alloc] init];
            attach.image = [icon imageWithTintColor:(i == activeIndex ? activeFg : inactiveFg) renderingMode:UIImageRenderingModeAlwaysOriginal];
            [attrTitle appendAttributedString:[NSAttributedString attributedStringWithAttachment:attach]];
            [attrTitle appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        }
        NSDictionary *textAttrs = @{
            NSFontAttributeName: [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: (i == activeIndex ? activeFg : inactiveFg),
        };
        [attrTitle appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:textAttrs]];
        [btn setAttributedTitle:attrTitle forState:UIControlStateNormal];

        if (i == activeIndex) {
            btn.backgroundColor = activeBg;
            btn.layer.borderWidth = 0;
        } else {
            btn.backgroundColor = inactiveBg;
            btn.layer.borderWidth = 1.0;
            [btn pp_setBorderColor:inactiveBorder];
        }

        [btn addTarget:self action:@selector(pp_themeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:btn];
    }

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10.0;
    stack.distribution = UIStackViewDistributionFillEqually;

    for (UIView *sub in cell.contentView.subviews) { [sub removeFromSuperview]; }
    [cell.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16.0],
        [stack.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [stack.heightAnchor constraintEqualToConstant:44.0],
    ]];

    return cell;
}

- (void)pp_themeButtonTapped:(UIButton *)sender
{
    NSInteger tappedIndex = sender.tag;
    for (PPSettingsSectionModel *section in self.sections) {
        for (PPSettingsRowModel *row in section.rows) {
            if (row.type == PPSettingsRowTypeThemePicker && row.onThemeTap) {
                row.onThemeTap(tappedIndex);
                return;
            }
        }
    }
}

- (void)saveUserInterfaceStyle:(UIUserInterfaceStyle)style
{
    [[PPThemeManager sharedManager] saveUserInterfaceStyle:style];
}

- (UIUserInterfaceStyle)loadUserInterfaceStyle
{
    return [[PPThemeManager sharedManager] loadUserInterfaceStyle];
}

#pragma mark - Language

- (void)showLanguageSetupAlertFrom:(UIViewController *)viewController
{
    if (self.alertAppear) return;
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
        if (!didConfirm) { strongSelf.alertAppear = NO; return; }

        NSInteger newLangVal = ([Language languageVal] == 0) ? 1 : 0;
        [Language userSelectedLanguage:LanguageCode[newLangVal]];
        
        
        strongSelf.alertAppear = NO;
    }
                           cancelBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_buildSections];
        [strongSelf.tableView reloadData];
        strongSelf.alertAppear = NO;
    }];
}

#pragma mark - Notifications

- (void)pp_setupNotificationObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleAppWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)pp_handleAppWillEnterForeground { [self pp_refreshNotificationStatusAsync]; }

- (void)pp_refreshNotificationStatusAsync
{
    __weak typeof(self) weakSelf = self;
    [[UNUserNotificationCenter currentNotificationCenter]
        getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        BOOL authorized = (settings.authorizationStatus == UNAuthorizationStatusAuthorized ||
                           settings.authorizationStatus == UNAuthorizationStatusProvisional ||
                           settings.authorizationStatus == UNAuthorizationStatusEphemeral);
        BOOL prefEnabled = [weakSelf.prefs boolForKey:kSettingsNotificationsKey];
        if (!authorized && prefEnabled) {
            [weakSelf.prefs setBool:NO forKey:kSettingsNotificationsKey];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf pp_buildSections];
            [weakSelf.tableView reloadData];
        });
    }];
}

- (void)pp_handleNotificationToggle:(BOOL)isOn
{
    if (isOn) { [self pp_requestNotificationAuthorization]; return; }
    [self.prefs setBool:NO forKey:kSettingsNotificationsKey];
}

- (void)pp_requestNotificationAuthorization
{
    UNAuthorizationOptions options =
        (UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge);
    __weak typeof(self) weakSelf = self;
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:options
                      completionHandler:^(BOOL granted, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (granted) {
                [strongSelf.prefs setBool:YES forKey:kSettingsNotificationsKey];
                [UIApplication.sharedApplication registerForRemoteNotifications];
            } else {
                [strongSelf.prefs setBool:NO forKey:kSettingsNotificationsKey];
                [PPHUD showError:kLang(@"Notifications permission denied")];
            }
            [strongSelf pp_buildSections];
            [strongSelf.tableView reloadData];
        });
    }];
}

#pragma mark - Messages Privacy

- (void)pp_showMessagesPrivacyPicker
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"kmessagesSetPalce")
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:(kLang(@"everyone") ?: @"Everyone")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [weakSelf.prefs setInteger:0 forKey:kSettingsMessagesPrivacyKey];
        [weakSelf pp_buildSections]; [weakSelf.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:(kLang(@"noOne") ?: @"No one")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [weakSelf.prefs setInteger:1 forKey:kSettingsMessagesPrivacyKey];
        [weakSelf pp_buildSections]; [weakSelf.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Cache

- (NSString *)pp_formattedCacheSize
{
    NSUInteger diskSize = [SDImageCache sharedImageCache].totalDiskSize;
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:(long long)diskSize];
}

- (void)pp_clearCache
{
    __weak typeof(self) weakSelf = self;
    [GM showDeleteConfirmationFrom:self
                             title:(kLang(@"ClearCache") ?: @"Clear Cache")
                           message:(kLang(@"ClearCacheMessage") ?: @"This will clear all cached images and data.")
                        completion:^(BOOL confirmed) {
        if (!confirmed) return;
        [[SDImageCache sharedImageCache] clearMemory];
        [[SDImageCache sharedImageCache] clearDiskOnCompletion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf pp_buildSections]; [weakSelf.tableView reloadData];
                [PPHUD showSuccess:(kLang(@"CacheCleared") ?: @"Cache cleared")];
            });
        }];
    }];
}

#pragma mark - Legal

- (void)pp_openLegalURL:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:url];
    safariVC.preferredControlTintColor = AppPrimaryClr;
    safariVC.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:safariVC animated:YES completion:nil];
}

#pragma mark - Delete Account

- (void)pp_confirmDeleteAccount
{
    NSString *title = PPSettingsLocalizedString(@"delete_account", @"Delete Account");
    NSString *message = PPSettingsLocalizedString(@"delete_account_warning", @"This will permanently delete your account and remove access to your Pure Pets data. This action cannot be undone.");

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:(kLang(@"Delete") ?: @"Delete")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [weakSelf pp_executeAccountDeletion];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") ?: @"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                     CGRectGetMidY(self.view.bounds), 0, 0);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_executeAccountDeletion
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        [PPHUD showError:PPSettingsLocalizedString(@"delete_account_failed", @"Could not delete account")
                subtitle:PPSettingsLocalizedString(@"delete_account_sign_in_required_message", @"Please sign in again, then return to Settings and delete your account.")
                   delay:2.6];
        return;
    }

    [self pp_executeAccountDeletionForcingSessionRefresh:YES didRetryAuth:NO];
}

- (void)pp_executeAccountDeletionForcingSessionRefresh:(BOOL)forceSessionRefresh
                                          didRetryAuth:(BOOL)didRetryAuth
{
    [PPHUD showIndeterminateIn:self.view
                         title:PPSettingsLocalizedString(@"deleting_account", @"Deleting account...")
                      subtitle:nil];

    __weak typeof(self) weakSelf = self;
    [PPFirebaseSessionBridge ensureFreshAuthSessionForcingRefresh:forceSessionRefresh completion:^(NSError * _Nullable authError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (authError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                [strongSelf pp_presentAccountDeletionFailureForError:authError];
            });
            return;
        }

        FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
        [[functions HTTPSCallableWithName:@"deleteUserAccount"]
         callWithObject:@{}
         completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;

                if (error) {
                    NSLog(@"[SettingVC] Delete account failed: %@", error.localizedDescription ?: error);
                    if (!didRetryAuth &&
                        !PPSettingsDeleteAccountErrorRequiresRecentLogin(error) &&
                        [PPFirebaseSessionBridge isAuthOrAppCheckError:error]) {
                        [strongSelf pp_executeAccountDeletionForcingSessionRefresh:YES didRetryAuth:YES];
                        return;
                    }

                    [PPHUD dismiss];
                    [strongSelf pp_presentAccountDeletionFailureForError:error];
                    return;
                }

                [PPHUD dismiss];
                [PPHUD showSuccess:PPSettingsLocalizedString(@"account_deleted", @"Account deleted")];
                [UserManager.sharedManager signOutCurrentUserWithCompletion:^(NSError * _Nullable signOutError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (signOutError) {
                            NSLog(@"[SettingVC] Account deleted, but local sign-out reported: %@", signOutError.localizedDescription ?: signOutError);
                        }
                        [strongSelf pp_finishLocalLogoutAndReloadUI];
                    });
                }];
            });
        }];
    }];
}

- (void)pp_presentAccountDeletionFailureForError:(NSError *)error
{
    [PPHUD showError:PPSettingsLocalizedString(@"delete_account_failed", @"Could not delete account")
            subtitle:PPSettingsDeleteAccountFailureMessage(error)
               delay:2.6];
}

#pragma mark - Logout

- (void)pp_confirmLogout
{
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:PPSettingsLocalizedString(@"Logout", @"Logout")
                                                                   message:PPSettingsLocalizedString(@"LogoutMessage", @"Are you sure you want to log out?")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:PPSettingsLocalizedString(@"cancel", @"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:PPSettingsLocalizedString(@"Logout", @"Logout")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_performLogout];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_performLogout
{
    [PPHUD showIndeterminateIn:self.view
                         title:PPSettingsLocalizedString(@"logging_out", @"Logging out...")
                      subtitle:nil];

    __weak typeof(self) weakSelf = self;
    [UserManager.sharedManager signOutCurrentUserWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            [PPHUD dismiss];

            if (error) {
                NSLog(@"[SettingVC] Logout failed: %@", error.localizedDescription ?: error);
                [PPHUD showError:PPSettingsLocalizedString(@"logout_failed", @"Could not log out")
                        subtitle:PPSettingsLogoutFailureMessage(error)
                           delay:2.4];
                return;
            }

            [strongSelf pp_finishLocalLogoutAndReloadUI];
        });
    }];
}

- (void)pp_finishLocalLogoutAndReloadUI
{
    [UserManager.sharedManager logoutAndClearAll];
    [self pp_reloadRootControllerAfterLogout];
}

- (void)pp_reloadRootControllerAfterLogout
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self pp_keyWindow];
        if (!window) return;

        UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
        UIViewController *newRoot = [[PPRootTabBarController alloc] init];
        if (!newRoot) return;

        newRoot.view.semanticContentAttribute = semantic;
        window.semanticContentAttribute = semantic;

        [UIView transitionWithView:window
                          duration:0.32
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
            BOOL old = [UIView areAnimationsEnabled];
            [UIView setAnimationsEnabled:NO];
            window.rootViewController = newRoot;
            [window makeKeyAndVisible];
            [UIView setAnimationsEnabled:old];
        } completion:nil];
    });
}

#pragma mark - Language Reload

- (void)pp_applyLanguageChangeAndReloadUI
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self pp_keyWindow];
        if (!window) return;
        
        UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
        window.semanticContentAttribute = semantic;
        
        UIViewController *newRoot = [[PPRootTabBarController alloc] init];
        if (!newRoot) return;
        [UIView transitionWithView:window
                          duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve
        animations:^{
            BOOL old = [UIView areAnimationsEnabled];
            [UIView setAnimationsEnabled:NO];
            window.rootViewController = newRoot;
            newRoot.view.semanticContentAttribute = semantic;
            window.semanticContentAttribute = semantic;
            [[UIView appearance] setSemanticContentAttribute:semantic];
            [[UINavigationBar appearance] setSemanticContentAttribute:semantic];
            [[UITabBar appearance] setSemanticContentAttribute:semantic];
            [[UITableView appearance] setSemanticContentAttribute:semantic];
            [[UICollectionView appearance] setSemanticContentAttribute:semantic];
            
            
            [window makeKeyAndVisible];
            [UIView setAnimationsEnabled:old];
        } completion:nil];
    });
}

- (UIWindow *)pp_keyWindow
{
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) return window;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

@end
