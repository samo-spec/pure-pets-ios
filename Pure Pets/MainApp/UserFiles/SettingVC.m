//
//  SettingVC.m
//  Pure Pets

#import "SettingVC.h"
#import "PPRootTabBarController.h"
#import "PPFirebaseSessionBridge.h"
#import "LocationPickerViewController.h"
#import "PPHomeLocationSheetViewController.h"
#import "PPHomeLocationTitleView.h"
#import "PPDataViewInput.h"
#import <CoreLocation/CoreLocation.h>
#import <SafariServices/SFSafariViewController.h>
@import FirebaseFunctions;
@import UserNotifications;

@import Firebase;
@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseStorage;
@import FirebaseFirestore;


static NSString *const kSettingsMessagesPrivacyKey = @"messagesPrivacyValue";
static NSString *const kSettingsNotificationsKey   = @"notificationsSet";
NSString * const PPThemePreferenceDidChangeNotification = @"PPThemePreferenceDidChangeNotification";

// MARK: Legal URLs — update these to the production website URLs when available.
static NSString *const kPPPrivacyPolicyURL   = @"https://pure-pets.net/privacy";
static NSString *const kPPTermsOfServiceURL  = @"https://pure-pets.net";
static NSString *const PPSettingsNearbySelectedLatitudeKey = @"pp.home.nearby.latitude";
static NSString *const PPSettingsNearbySelectedLongitudeKey = @"pp.home.nearby.longitude";
static NSString *const PPSettingsNearbySelectedAreaNameKey = @"pp.home.nearby.areaName";
static NSString *const PPSettingsNearbyRecentLocationsKey = @"pp.home.nearby.recentLocations";
static NSInteger const PPSettingsNearbyRecentLocationsLimit = 4;
static double const PPSettingsNearbyDefaultRadiusKm = 8.0;

static UIColor *PPSettingsHeroSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.115 green:0.114 blue:0.125 alpha:0.96];
            }
            return [UIColor colorWithRed:0.992 green:0.989 blue:0.982 alpha:0.98];
        }];
    }
    return AppForgroundColr ?: UIColor.whiteColor;
}

static UIColor *PPSettingsHeroSecondarySurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [[UIColor whiteColor] colorWithAlphaComponent:0.07];
            }
            return [[UIColor blackColor] colorWithAlphaComponent:0.035];
        }];
    }
    return [[UIColor blackColor] colorWithAlphaComponent:0.035];
}

static UIColor *PPSettingsHeroBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [[UIColor whiteColor] colorWithAlphaComponent:0.10];
            }
            return [[UIColor blackColor] colorWithAlphaComponent:0.055];
        }];
    }
    return [[UIColor blackColor] colorWithAlphaComponent:0.055];
}

static UIColor *PPSettingsHeroPrimaryTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static UIColor *PPSettingsHeroSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

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
        return PPSettingsLocalizedString(@"delete_account_sign_in_required_message",
                                         @"Please sign in again, then return to Settings and delete your account.");
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
        return PPSettingsLocalizedString(@"delete_account_session_verify_message",
                                         @"We could not verify this account deletion request. Please try deleting your account again.");
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

#pragma mark - Location State

typedef NS_ENUM(NSInteger, PPSettingsLocationState) {
    PPSettingsLocationStateUnset = 0,
    PPSettingsLocationStateLoading,
    PPSettingsLocationStateReady,
    PPSettingsLocationStateDenied
};

#pragma mark - PPSettingsRowModel

typedef NS_ENUM(NSInteger, PPSettingsRowType) {
    PPSettingsRowTypeHero,
    PPSettingsRowTypeLocation,
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
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy, nullable) NSString *disabledHint;
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
        _enabled = YES;
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

#pragma mark - PPSettingsHeroCell

@interface PPSettingsHeroCell : UITableViewCell
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) UIView *accentLineView;
@property (nonatomic, strong) UIView *iconShellView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *actionPillView;
@property (nonatomic, strong) UILabel *actionLabel;
@property (nonatomic, strong) UIImageView *scopeIconImageView;
- (void)configureWithRow:(PPSettingsRowModel *)row;
- (void)prepareEntranceState;
- (void)runEntranceAnimationWithDelay:(NSTimeInterval)delay;
@end

@implementation PPSettingsHeroCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;

        UIView *card = [UIView new];
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.backgroundColor = AppForgroundColr;
        card.layer.borderWidth = 1.0;
        [card pp_setBorderColor:PPSettingsHeroBorderColor()];
        card.layer.shadowOpacity = 0.00;
        card.layer.shadowRadius = 0.0;
        card.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        [card pp_setShadowColor:[UIColor blackColor]];
        PPApplyContinuousCorners(card, 34.0);
        [self.contentView addSubview:card];
        self.heroCardView = card;

        UIView *accent = [UIView new];
        accent.translatesAutoresizingMaskIntoConstraints = NO;
        accent.backgroundColor = AppPrimaryClr ?: UIColor.systemTealColor;
        PPApplyContinuousCorners(accent, 2.0);
        [card addSubview:accent];
        self.accentLineView = accent;

        UIView *iconShell = [UIView new];
        iconShell.translatesAutoresizingMaskIntoConstraints = NO;
        iconShell.backgroundColor = PPSettingsHeroSecondarySurfaceColor();
        iconShell.layer.borderWidth = 1.0;
        [iconShell pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.24]];
        PPApplyContinuousCorners(iconShell, 38.0);
        iconShell.clipsToBounds = NO;
        [card addSubview:iconShell];
        self.iconShellView = iconShell;

        UIImageView *icon = [UIImageView new];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        UIImageSymbolConfiguration *heroIconConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:29.0
                                                            weight:UIImageSymbolWeightSemibold];
        icon.image = [[UIImage systemImageNamed:@"gearshape.fill"
                              withConfiguration:heroIconConfig]
                      imageWithTintColor:AppPrimaryClr ?: UIColor.systemTealColor
                      renderingMode:UIImageRenderingModeAlwaysOriginal];
        [iconShell addSubview:icon];
        self.iconImageView = icon;

        UILabel *eyebrow = [UILabel new];
        eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
        eyebrow.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                        scaledFontForFont:([GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold])];
        eyebrow.adjustsFontForContentSizeCategory = YES;
        eyebrow.textColor = PPSettingsHeroSecondaryTextColor();
        eyebrow.numberOfLines = 1;
        eyebrow.textAlignment = [Language alignmentForCurrentLanguage];
        [card addSubview:eyebrow];
        self.eyebrowLabel = eyebrow;

        UILabel *name = [UILabel new];
        name.translatesAutoresizingMaskIntoConstraints = NO;
        name.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3]
                     scaledFontForFont:([GM boldFontWithSize:21.0] ?: [UIFont systemFontOfSize:21.0 weight:UIFontWeightBold])];
        name.adjustsFontForContentSizeCategory = YES;
        name.textColor = PPSettingsHeroPrimaryTextColor();
        name.numberOfLines = 2;
        name.textAlignment = [Language alignmentForCurrentLanguage];
        [card addSubview:name];
        self.nameLabel = name;

        UILabel *subtitle = [UILabel new];
        subtitle.translatesAutoresizingMaskIntoConstraints = NO;
        subtitle.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                         scaledFontForFont:([GM fontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular])];
        subtitle.adjustsFontForContentSizeCategory = YES;
        subtitle.textColor = PPSettingsHeroSecondaryTextColor();
        subtitle.numberOfLines = 2;
        subtitle.textAlignment = [Language alignmentForCurrentLanguage];
        [card addSubview:subtitle];
        self.subtitleLabel = subtitle;

        UIView *pill = [UIView new];
        pill.translatesAutoresizingMaskIntoConstraints = NO;
        pill.backgroundColor = PPSettingsHeroSecondarySurfaceColor();
        pill.layer.borderWidth = 1.0;
        [pill pp_setBorderColor:PPSettingsHeroBorderColor()];
        PPApplyContinuousCorners(pill, 18.0);
        [card addSubview:pill];
        self.actionPillView = pill;

        UILabel *action = [UILabel new];
        action.translatesAutoresizingMaskIntoConstraints = NO;
        action.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                       scaledFontForFont:([GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold])];
        action.adjustsFontForContentSizeCategory = YES;
        action.textColor = AppPrimaryClr ?: UIColor.systemTealColor;
        action.numberOfLines = 1;
        action.textAlignment = NSTextAlignmentNatural;
        [pill addSubview:action];
        self.actionLabel = action;

        UIImageView *scopeIcon = [UIImageView new];
        scopeIcon.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageSymbolConfiguration *scopeIconConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                            weight:UIImageSymbolWeightSemibold];
        scopeIcon.image = [[UIImage systemImageNamed:@"slider.horizontal.3"
                                   withConfiguration:scopeIconConfig]
                           imageWithTintColor:AppPrimaryClr ?: UIColor.systemTealColor
                           renderingMode:UIImageRenderingModeAlwaysOriginal];
        scopeIcon.contentMode = UIViewContentModeScaleAspectFit;
        [pill addSubview:scopeIcon];
        self.scopeIconImageView = scopeIcon;

        UILayoutGuide *textGuide = [UILayoutGuide new];
        [card addLayoutGuide:textGuide];

        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
            [card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0.0],
            [card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:0.0],
            [card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:0.0],
            [card.heightAnchor constraintGreaterThanOrEqualToConstant:152.0],

            [accent.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
            [accent.topAnchor constraintEqualToAnchor:card.topAnchor constant:22.0],
            [accent.widthAnchor constraintEqualToConstant:3.0],
            [accent.heightAnchor constraintEqualToConstant:34.0],

            [iconShell.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:26.0],
            [iconShell.topAnchor constraintEqualToAnchor:card.topAnchor constant:26.0],
            [iconShell.widthAnchor constraintEqualToConstant:76.0],
            [iconShell.heightAnchor constraintEqualToConstant:76.0],

            [icon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:42.0],
            [icon.heightAnchor constraintEqualToConstant:42.0],

            [textGuide.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:18.0],
            [textGuide.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],
            [textGuide.topAnchor constraintEqualToAnchor:card.topAnchor constant:22.0],
            [textGuide.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20.0],

            [eyebrow.leadingAnchor constraintEqualToAnchor:textGuide.leadingAnchor],
            [eyebrow.trailingAnchor constraintEqualToAnchor:textGuide.trailingAnchor],
            [eyebrow.topAnchor constraintEqualToAnchor:textGuide.topAnchor],

            [name.leadingAnchor constraintEqualToAnchor:textGuide.leadingAnchor],
            [name.trailingAnchor constraintEqualToAnchor:textGuide.trailingAnchor],
            [name.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:4.0],

            [subtitle.leadingAnchor constraintEqualToAnchor:textGuide.leadingAnchor],
            [subtitle.trailingAnchor constraintEqualToAnchor:textGuide.trailingAnchor],
            [subtitle.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:6.0],

            [pill.leadingAnchor constraintEqualToAnchor:textGuide.leadingAnchor],
            [pill.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:14.0],
            [pill.bottomAnchor constraintEqualToAnchor:textGuide.bottomAnchor],
            [pill.heightAnchor constraintGreaterThanOrEqualToConstant:36.0],

            [action.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:14.0],
            [action.topAnchor constraintEqualToAnchor:pill.topAnchor constant:8.0],
            [action.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-8.0],

            [scopeIcon.leadingAnchor constraintEqualToAnchor:action.trailingAnchor constant:8.0],
            [scopeIcon.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-12.0],
            [scopeIcon.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
            [scopeIcon.widthAnchor constraintEqualToConstant:16.0],
            [scopeIcon.heightAnchor constraintEqualToConstant:16.0],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.heroCardView.alpha = 1.0;
    self.heroCardView.transform = CGAffineTransformIdentity;
    self.iconShellView.transform = CGAffineTransformIdentity;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    self.heroCardView.backgroundColor = PPSettingsHeroSurfaceColor();
    [self.heroCardView pp_setBorderColor:PPSettingsHeroBorderColor()];
    self.actionPillView.backgroundColor = PPSettingsHeroSecondarySurfaceColor();
    [self.actionPillView pp_setBorderColor:PPSettingsHeroBorderColor()];
    self.eyebrowLabel.textColor = PPSettingsHeroSecondaryTextColor();
    self.nameLabel.textColor = PPSettingsHeroPrimaryTextColor();
    self.subtitleLabel.textColor = PPSettingsHeroSecondaryTextColor();
}

- (void)configureWithRow:(PPSettingsRowModel *)row
{
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroCardView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.eyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.nameLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];

    self.eyebrowLabel.text = PPSettingsLocalizedString(@"settings_hero_eyebrow", @"Settings");
    self.nameLabel.text = row.title.length > 0
        ? row.title
        : PPSettingsLocalizedString(@"settings_hero_title", @"Tune Pure Pets");
    self.subtitleLabel.text = row.subtitle.length > 0
        ? row.subtitle
        : PPSettingsLocalizedString(@"settings_hero_subtitle",
                                    @"Control appearance, language, privacy, notifications, legal access, and account safety from one calm place.");
    self.actionLabel.text = PPSettingsLocalizedString(@"settings_hero_scope",
                                                      @"Privacy • Appearance • Language");

    UIImageSymbolConfiguration *scopeIconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                        weight:UIImageSymbolWeightSemibold];
    self.scopeIconImageView.image = [[UIImage systemImageNamed:@"slider.horizontal.3"
                                             withConfiguration:scopeIconConfig]
                                     imageWithTintColor:AppPrimaryClr ?: UIColor.systemTealColor
                                     renderingMode:UIImageRenderingModeAlwaysOriginal];

    NSString *accessibilityHint = PPSettingsLocalizedString(@"settings_hero_accessibility_hint",
                                                            @"Summarizes the settings available on this screen.");
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.accessibilityLabel = self.nameLabel.text;
    self.accessibilityValue = self.subtitleLabel.text;
    self.accessibilityHint = accessibilityHint;
}

- (void)prepareEntranceState
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroCardView.alpha = 1.0;
        self.heroCardView.transform = CGAffineTransformIdentity;
        self.iconShellView.transform = CGAffineTransformIdentity;
        return;
    }
    self.heroCardView.alpha = 0.0;
    self.heroCardView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 14.0),
                                CGAffineTransformMakeScale(0.982, 0.982));
    self.iconShellView.transform = CGAffineTransformMakeScale(0.94, 0.94);
}

- (void)runEntranceAnimationWithDelay:(NSTimeInterval)delay
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroCardView.alpha = 1.0;
        self.heroCardView.transform = CGAffineTransformIdentity;
        self.iconShellView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:delay
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroCardView.alpha = 1.0;
        self.heroCardView.transform = CGAffineTransformIdentity;
        self.iconShellView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    void (^changes)(void) = ^{
        self.heroCardView.transform = highlighted
            ? CGAffineTransformMakeScale(0.985, 0.985)
            : CGAffineTransformIdentity;
        self.heroCardView.alpha = highlighted ? 0.92 : 1.0;
    };
    if (animated) {
        [UIView animateWithDuration:highlighted ? 0.10 : 0.18
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

@end

#pragma mark - PPSettingsLocationCell

@interface PPSettingsLocationCell : UITableViewCell
@property (nonatomic, strong) UIImageView *leadingIconView;
@property (nonatomic, strong) PPHomeLocationTitleView *locationTitleView;
@property (nonatomic, copy, nullable) dispatch_block_t onActivate;
- (void)configureWithTitle:(NSString *)title
               statusColor:(UIColor *)statusColor
                   loading:(BOOL)loading
         accessibilityHint:(nullable NSString *)accessibilityHint
                  animated:(BOOL)animated;
@end

@implementation PPSettingsLocationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = AppForgroundColr;
        self.contentView.backgroundColor = AppForgroundColr;
        self.layer.cornerRadius = 16.0;
        self.layer.masksToBounds = YES;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.isAccessibilityElement = NO;
        self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

       

        PPHomeLocationTitleView *titleView =
            [[PPHomeLocationTitleView alloc] initWithFrame:CGRectMake(0.0, 8.0, 220.0, 64.0)];
        titleView.translatesAutoresizingMaskIntoConstraints = NO;
        titleView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [titleView addTarget:self
                      action:@selector(pp_locationTapped)
            forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:titleView];
        self.locationTitleView = titleView;

        [NSLayoutConstraint activateConstraints:@[
            
            
            [titleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [titleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0.0],
            [titleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [titleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
        ]];
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    [self.locationTitleView setCorners:16];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onActivate = nil;
    [self.locationTitleView stopLivingMotion];
    self.locationTitleView.transform = CGAffineTransformIdentity;
    self.locationTitleView.alpha = 1.0;
}

- (void)configureWithTitle:(NSString *)title
               statusColor:(UIColor *)statusColor
                   loading:(BOOL)loading
         accessibilityHint:(NSString *)accessibilityHint
                  animated:(BOOL)animated
{
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.locationTitleView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.locationTitleView configureWithTitle:title
                                   statusColor:statusColor
                                       loading:loading
                             accessibilityHint:accessibilityHint
                                      animated:animated];
}

- (void)pp_locationTapped
{
    if (self.onActivate) {
        self.onActivate();
    }
}

@end


#pragma mark - SwiftyMax V6 Settings Presentation

static UIColor *PPSettingsV6SurfaceColor(void)
{
    return AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
}

static UIColor *PPSettingsV6HairlineColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor separatorColor];
    }
    return [[UIColor blackColor] colorWithAlphaComponent:0.09];
}

static UIColor *PPSettingsV6BrandWashColor(void)
{
    return [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.10];
}

@interface PPSettingsV6HeroCell : UITableViewCell
@property (nonatomic, strong) UIView *brandDot;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabelV6;
@property (nonatomic, strong) UILabel *subtitleLabelV6;
- (void)configureWithRow:(PPSettingsRowModel *)row;
- (void)runEntranceIfNeeded;
@end

@implementation PPSettingsV6HeroCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.isAccessibilityElement = NO;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *dot = [UIView new];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    PPApplyContinuousCorners(dot, 4.0);
    [self.contentView addSubview:dot];
    self.brandDot = dot;

    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.text = PPSettingsLocalizedString(@"settings_v6_eyebrow", @"PURE PETS");
    eyebrow.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                    scaledFontForFont:([GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold])];
    eyebrow.adjustsFontForContentSizeCategory = YES;
    eyebrow.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    eyebrow.textAlignment = [Language alignmentForCurrentLanguage];
    eyebrow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.contentView addSubview:eyebrow];
    self.eyebrowLabel = eyebrow;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle]
                  scaledFontForFont:([GM boldFontWithSize:PPFontLargeTitle] ?: [UIFont systemFontOfSize:34 weight:UIFontWeightBold])];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    title.numberOfLines = 0;
    title.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.contentView addSubview:title];
    self.titleLabelV6 = title;

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                     scaledFontForFont:([GM fontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15])];
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitle.textAlignment = [Language alignmentForCurrentLanguage];
    subtitle.numberOfLines = 0;
    subtitle.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.contentView addSubview:subtitle];
    self.subtitleLabelV6 = subtitle;

    [NSLayoutConstraint activateConstraints:@[
        [dot.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [dot.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceXL],
        [dot.widthAnchor constraintEqualToConstant:8.0],
        [dot.heightAnchor constraintEqualToConstant:8.0],

        [eyebrow.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:PPSpaceSM],
        [eyebrow.centerYAnchor constraintEqualToAnchor:dot.centerYAnchor],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],

        [title.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [title.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [title.topAnchor constraintEqualToAnchor:dot.bottomAnchor constant:PPSpaceMD],

        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:PPSpaceSM],
        [subtitle.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceLG]
    ]];

    return self;
}

- (void)configureWithRow:(PPSettingsRowModel *)row
{
    self.titleLabelV6.text = row.title ?: @"";
    self.subtitleLabelV6.text = row.subtitle ?: @"";
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.eyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabelV6.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabelV6.textAlignment = [Language alignmentForCurrentLanguage];
}

- (void)runEntranceIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    if (self.contentView.layer.animationKeys.count > 0) return;
    self.contentView.alpha = 0.0;
    self.contentView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [UIView animateWithDuration:PPAnimDurationSlow
                          delay:0.02
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.contentView.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end

@interface PPSettingsV6LocationCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *titleLabelV6;
@property (nonatomic, strong) UILabel *actionLabel;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, copy, nullable) dispatch_block_t onActivate;
- (void)configureWithTitle:(NSString *)title
                    action:(nullable NSString *)action
               statusColor:(UIColor *)statusColor
                   loading:(BOOL)loading
         accessibilityHint:(nullable NSString *)accessibilityHint
                  animated:(BOOL)animated;
- (void)runEntranceIfNeeded;
@end

@implementation PPSettingsV6LocationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = PPSettingsV6SurfaceColor();
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:PPSettingsHeroBorderColor()];
    PPApplyContinuousCorners(card, 28.0);
    PPApplyCardShadow(card);
    card.layer.shadowOpacity = 0.045;
    [self.contentView addSubview:card];
    self.cardView = card;

    UIView *iconShell = [UIView new];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = PPSettingsV6BrandWashColor();
    PPApplyContinuousCorners(iconShell, 24.0);
    [card addSubview:iconShell];

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightSemibold];
    icon.image = [[UIImage systemImageNamed:@"location.fill" withConfiguration:config]
                  imageWithTintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                  renderingMode:UIImageRenderingModeAlwaysOriginal];
    [iconShell addSubview:icon];

    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.text = PPSettingsLocalizedString(@"settings_location_eyebrow", @"SMART LOCATION");
    eyebrow.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption2]
                    scaledFontForFont:([GM boldFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11 weight:UIFontWeightBold])];
    eyebrow.adjustsFontForContentSizeCategory = YES;
    eyebrow.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    eyebrow.textAlignment = [Language alignmentForCurrentLanguage];
    [card addSubview:eyebrow];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3]
                  scaledFontForFont:([GM boldFontWithSize:PPFontTitle3] ?: [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold])];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    title.numberOfLines = 2;
    [card addSubview:title];
    self.titleLabelV6 = title;

    UIView *status = [UIView new];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(status, 4.0);
    [card addSubview:status];
    self.statusDot = status;

    UIActivityIndicatorView *spinner;
    if (@available(iOS 13.0, *)) {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.color = AppPrimaryClr ?: UIColor.systemPinkColor;
    spinner.hidesWhenStopped = YES;
    [card addSubview:spinner];
    self.spinner = spinner;

    UILabel *action = [UILabel new];
    action.translatesAutoresizingMaskIntoConstraints = NO;
    action.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                   scaledFontForFont:([GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold])];
    action.adjustsFontForContentSizeCategory = YES;
    action.textColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    action.textAlignment = [Language alignmentForCurrentLanguage];
    [card addSubview:action];
    self.actionLabel = action;

    UIImageView *chevron = [UIImageView new];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    NSString *chevronName = Language.isRTL ? @"chevron.backward" : @"chevron.forward";
    chevron.image = [[UIImage systemImageNamed:chevronName] imageWithTintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                                                                 renderingMode:UIImageRenderingModeAlwaysOriginal];
    [card addSubview:chevron];
    self.chevronView = chevron;

    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceSM],
        [card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceMD],

        [iconShell.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceBase],
        [iconShell.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [iconShell.widthAnchor constraintEqualToConstant:48.0],
        [iconShell.heightAnchor constraintEqualToConstant:48.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:24.0],
        [icon.heightAnchor constraintEqualToConstant:24.0],

        [eyebrow.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:PPSpaceMD],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
        [eyebrow.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceBase],

        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:PPSpaceXS],

        [status.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [status.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:PPSpaceMD],
        [status.widthAnchor constraintEqualToConstant:8.0],
        [status.heightAnchor constraintEqualToConstant:8.0],
        [status.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceBase],

        [spinner.centerXAnchor constraintEqualToAnchor:status.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:status.centerYAnchor],

        [action.leadingAnchor constraintEqualToAnchor:status.trailingAnchor constant:PPSpaceSM],
        [action.centerYAnchor constraintEqualToAnchor:status.centerYAnchor],
        [action.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-PPSpaceSM],

        [chevron.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
        [chevron.centerYAnchor constraintEqualToAnchor:action.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:13.0],
        [chevron.heightAnchor constraintEqualToConstant:18.0]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onActivate = nil;
    [self.spinner stopAnimating];
    self.contentView.transform = CGAffineTransformIdentity;
    self.contentView.alpha = 1.0;
}

- (void)configureWithTitle:(NSString *)title
                    action:(NSString *)action
               statusColor:(UIColor *)statusColor
                   loading:(BOOL)loading
         accessibilityHint:(NSString *)accessibilityHint
                  animated:(BOOL)animated
{
    self.titleLabelV6.text = title ?: @"";
    self.actionLabel.text = action ?: @"";
    self.statusDot.backgroundColor = statusColor ?: AppSecondaryTextClr;
    self.statusDot.hidden = loading;
    loading ? [self.spinner startAnimating] : [self.spinner stopAnimating];
    self.cardView.isAccessibilityElement = NO;
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = title ?: @"";
    self.accessibilityValue = action ?: @"";
    self.accessibilityHint = accessibilityHint ?: action;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    NSString *chevronName = Language.isRTL ? @"chevron.backward" : @"chevron.forward";
    self.chevronView.image = [[UIImage systemImageNamed:chevronName] imageWithTintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                                                                 renderingMode:UIImageRenderingModeAlwaysOriginal];
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView transitionWithView:self.titleLabelV6 duration:PPAnimDurationNormal options:UIViewAnimationOptionTransitionCrossDissolve animations:^{} completion:nil];
    }
}


- (BOOL)accessibilityActivate
{
    if (self.onActivate) {
        self.onActivate();
        return YES;
    }
    return [super accessibilityActivate];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    void (^changes)(void) = ^{
        self.cardView.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    };
    if (animated) {
        [UIView animateWithDuration:PPAnimDurationFast animations:changes];
    } else {
        changes();
    }
}

- (void)runEntranceIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    self.contentView.alpha = 0.0;
    self.contentView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    [UIView animateWithDuration:PPAnimDurationSlow
                          delay:0.06
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.contentView.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end

@interface PPSettingsV6RowCell : UITableViewCell
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconShell;
@property (nonatomic, strong) UIImageView *iconViewV6;
@property (nonatomic, strong) UILabel *titleLabelV6;
@property (nonatomic, strong) UILabel *subtitleLabelV6;
@property (nonatomic, strong) UIView *accessoryHost;
@property (nonatomic, strong) UIView *separatorViewV6;
@property (nonatomic, strong) NSLayoutConstraint *accessoryWidthConstraint;
- (void)configureWithRow:(PPSettingsRowModel *)row
                   first:(BOOL)first
                    last:(BOOL)last
               accessory:(nullable UIView *)accessory;
@end

@implementation PPSettingsV6RowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *surface = [UIView new];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = PPSettingsV6SurfaceColor();
    [self.contentView addSubview:surface];
    self.surfaceView = surface;

    UIView *iconShell = [UIView new];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = PPSettingsV6BrandWashColor();
    PPApplyContinuousCorners(iconShell, 12.0);
    [surface addSubview:iconShell];
    self.iconShell = iconShell;

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:icon];
    self.iconViewV6 = icon;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                  scaledFontForFont:([GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:17 weight:UIFontWeightMedium])];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    title.numberOfLines = 0;
    [surface addSubview:title];
    self.titleLabelV6 = title;

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                     scaledFontForFont:([GM fontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13])];
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitle.textAlignment = [Language alignmentForCurrentLanguage];
    subtitle.numberOfLines = 2;
    [surface addSubview:subtitle];
    self.subtitleLabelV6 = subtitle;

    UIView *accessoryHost = [UIView new];
    accessoryHost.translatesAutoresizingMaskIntoConstraints = NO;
    [surface addSubview:accessoryHost];
    self.accessoryHost = accessoryHost;

    UIView *separator = [UIView new];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = PPSettingsV6HairlineColor();
    [surface addSubview:separator];
    self.separatorViewV6 = separator;

    self.accessoryWidthConstraint = [accessoryHost.widthAnchor constraintEqualToConstant:28.0];

    [NSLayoutConstraint activateConstraints:@[
        [surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [iconShell.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceBase],
        [iconShell.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [iconShell.widthAnchor constraintEqualToConstant:36.0],
        [iconShell.heightAnchor constraintEqualToConstant:36.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18.0],
        [icon.heightAnchor constraintEqualToConstant:18.0],

        [title.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:PPSpaceMD],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:accessoryHost.leadingAnchor constant:-PPSpaceMD],
        [title.topAnchor constraintEqualToAnchor:surface.topAnchor constant:PPSpaceMD],

        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:accessoryHost.leadingAnchor constant:-PPSpaceMD],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2.0],
        [subtitle.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-PPSpaceMD],

        [accessoryHost.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceBase],
        [accessoryHost.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [accessoryHost.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        self.accessoryWidthConstraint,

        [separator.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceBase],
        [separator.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [surface.heightAnchor constraintGreaterThanOrEqualToConstant:72.0]
    ]];

    [title setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    for (UIView *view in self.accessoryHost.subviews) [view removeFromSuperview];
    self.contentView.alpha = 1.0;
}

- (void)configureWithRow:(PPSettingsRowModel *)row first:(BOOL)first last:(BOOL)last accessory:(UIView *)accessory
{
    self.titleLabelV6.text = row.title ?: @"";
    self.subtitleLabelV6.text = row.subtitle ?: @"";
    self.subtitleLabelV6.hidden = row.subtitle.length == 0;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.titleLabelV6.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabelV6.textAlignment = [Language alignmentForCurrentLanguage];

    BOOL isDeleteAction = (row.type == PPSettingsRowTypeDestructive && [row.iconName containsString:@"badge.minus"]);
    UIColor *accent = isDeleteAction ? UIColor.systemRedColor : (AppPrimaryClr ?: UIColor.systemPinkColor);
    UIColor *titleColor = isDeleteAction ? UIColor.systemRedColor : (AppPrimaryTextClr ?: UIColor.labelColor);
    self.titleLabelV6.textColor = row.enabled ? titleColor : (AppSecondaryTextClr ?: UIColor.secondaryLabelColor);
    self.iconShell.backgroundColor = [accent colorWithAlphaComponent:0.10];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:(row.iconName ?: @"circle") withConfiguration:config];
    self.iconViewV6.image = [image imageWithTintColor:accent renderingMode:UIImageRenderingModeAlwaysOriginal];

    CGFloat radius = PPCornerCard;
    self.surfaceView.layer.cornerRadius = (first || last) ? radius : 0.0;
    if (@available(iOS 13.0, *)) self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    if (@available(iOS 11.0, *)) {
        CACornerMask mask = 0;
        if (first) mask |= (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner);
        if (last) mask |= (kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner);
        self.surfaceView.layer.maskedCorners = mask;
    }
    self.separatorViewV6.hidden = last;

    for (UIView *view in self.accessoryHost.subviews) [view removeFromSuperview];
    if (accessory) {
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [self.accessoryHost addSubview:accessory];
        CGFloat width = MAX(28.0, accessory.intrinsicContentSize.width);
        if ([accessory isKindOfClass:UISwitch.class]) width = 52.0;
        self.accessoryWidthConstraint.constant = width;
        [NSLayoutConstraint activateConstraints:@[
            [accessory.centerXAnchor constraintEqualToAnchor:self.accessoryHost.centerXAnchor],
            [accessory.centerYAnchor constraintEqualToAnchor:self.accessoryHost.centerYAnchor]
        ]];
    } else {
        self.accessoryWidthConstraint.constant = 8.0;
    }

    self.contentView.alpha = row.enabled ? 1.0 : 0.58;
    self.surfaceView.isAccessibilityElement = NO;

    BOOL containsSwitch = [accessory isKindOfClass:UISwitch.class];
    self.isAccessibilityElement = !containsSwitch;
    if (self.isAccessibilityElement) {
        self.accessibilityLabel = row.title ?: @"";
        self.accessibilityValue = row.subtitle ?: @"";
        self.accessibilityTraits = row.enabled ? UIAccessibilityTraitButton : UIAccessibilityTraitNotEnabled;
    } else {
        self.accessibilityLabel = nil;
        self.accessibilityValue = nil;
        self.titleLabelV6.isAccessibilityElement = YES;
        self.subtitleLabelV6.isAccessibilityElement = row.subtitle.length > 0;
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    void (^changes)(void) = ^{
        self.surfaceView.alpha = highlighted ? 0.76 : 1.0;
        self.surfaceView.transform = highlighted ? CGAffineTransformMakeScale(0.992, 0.992) : CGAffineTransformIdentity;
    };
    animated ? [UIView animateWithDuration:PPAnimDurationFast animations:changes] : changes();
}

@end

#pragma mark - PPSettingsChoiceButton

@interface PPSettingsChoiceButton : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) BOOL isChosen;
@property (nonatomic, assign) NSInteger optionIndex;
- (void)configureWithTitle:(NSString *)title iconName:(nullable NSString *)iconName isChosen:(BOOL)isChosen;
@end

@implementation PPSettingsChoiceButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        PPApplyContinuousCorners(self, 14.0);
        self.clipsToBounds = YES;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        UIImageView *icon = [UIImageView new];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:icon];
        self.iconView = icon;

        UILabel *title = [UILabel new];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                      scaledFontForFont:([GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold])];
        title.adjustsFontForContentSizeCategory = YES;
        title.textAlignment = NSTextAlignmentCenter;
        title.numberOfLines = 1;
        [self addSubview:title];
        self.titleLabel = title;

        [NSLayoutConstraint activateConstraints:@[
            [icon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [icon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10.0],
            [icon.widthAnchor constraintEqualToConstant:17.0],
            [icon.heightAnchor constraintEqualToConstant:17.0],

            [title.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:5.0],
            [title.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10.0],
            
            [self.heightAnchor constraintGreaterThanOrEqualToConstant:46.0]
        ]];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title iconName:(NSString *)iconName isChosen:(BOOL)isChosen
{
    self.isChosen = isChosen;
    self.titleLabel.text = title ?: @"";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *img = [UIImage systemImageNamed:(iconName ?: @"circle.fill") withConfiguration:config];
    
    if (isChosen) {
        self.backgroundColor = AppPrimaryClr ?: UIColor.systemPinkColor;
        self.layer.borderWidth = 0.0;
        self.titleLabel.textColor = UIColor.whiteColor;
        self.iconView.image = [img imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        self.layer.shadowColor = (AppPrimaryClr ?: UIColor.systemPinkColor).CGColor;
        self.layer.shadowOpacity = 0.22;
        self.layer.shadowRadius = 8.0;
        self.layer.shadowOffset = CGSizeMake(0, 3);
    } else {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [[UIColor whiteColor] colorWithAlphaComponent:0.06]
                : [[UIColor blackColor] colorWithAlphaComponent:0.04];
        }];
        self.layer.borderWidth = 1.0;
        [self pp_setBorderColor:PPSettingsV6HairlineColor()];
        self.titleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
        self.iconView.image = [img imageWithTintColor:(AppSecondaryTextClr ?: UIColor.secondaryLabelColor)
                                        renderingMode:UIImageRenderingModeAlwaysOriginal];
        self.layer.shadowOpacity = 0.0;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self.alpha = highlighted ? 0.85 : 1.0;
    }];
}

@end

#pragma mark - PPSettingsV6ChoiceCell

@interface PPSettingsV6ChoiceCell : UITableViewCell
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIImageView *iconViewV6;
@property (nonatomic, strong) UILabel *titleLabelV6;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) NSMutableArray<PPSettingsChoiceButton *> *cardButtons;
@property (nonatomic, strong) UIView *separatorViewV6;
@property (nonatomic, copy, nullable) void (^onChoice)(NSInteger index);
- (void)configureTitle:(NSString *)title
                  icon:(NSString *)iconName
                titles:(NSArray<NSString *> *)titles
                 icons:(nullable NSArray<NSString *> *)icons
         selectedIndex:(NSInteger)selectedIndex
                 first:(BOOL)first
                  last:(BOOL)last
              onChoice:(void (^)(NSInteger index))onChoice;
@end

@implementation PPSettingsV6ChoiceCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.cardButtons = [NSMutableArray array];

    UIView *surface = [UIView new];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = PPSettingsV6SurfaceColor();
    [self.contentView addSubview:surface];
    self.surfaceView = surface;

    UIView *iconShell = [UIView new];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = PPSettingsV6BrandWashColor();
    PPApplyContinuousCorners(iconShell, 12.0);
    [surface addSubview:iconShell];

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:icon];
    self.iconViewV6 = icon;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                  scaledFontForFont:([GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:17 weight:UIFontWeightMedium])];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    [surface addSubview:title];
    self.titleLabelV6 = title;

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.alignment = UIStackViewAlignmentFill;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [surface addSubview:stack];
    self.stackView = stack;

    UIView *separator = [UIView new];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = PPSettingsV6HairlineColor();
    [surface addSubview:separator];
    self.separatorViewV6 = separator;

    [NSLayoutConstraint activateConstraints:@[
        [surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [iconShell.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceBase],
        [iconShell.topAnchor constraintEqualToAnchor:surface.topAnchor constant:PPSpaceMD],
        [iconShell.widthAnchor constraintEqualToConstant:36.0],
        [iconShell.heightAnchor constraintEqualToConstant:36.0],
        [icon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18.0],
        [icon.heightAnchor constraintEqualToConstant:18.0],

        [title.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:PPSpaceMD],
        [title.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceBase],
        [title.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],

        [stack.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceBase],
        [stack.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceBase],
        [stack.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:PPSpaceMD],
        [stack.heightAnchor constraintGreaterThanOrEqualToConstant:48.0],
        [stack.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-PPSpaceBase],

        [separator.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceBase],
        [separator.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceBase],
        [separator.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onChoice = nil;
    for (UIView *subview in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    [self.cardButtons removeAllObjects];
}

- (void)configureTitle:(NSString *)title icon:(NSString *)iconName titles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons selectedIndex:(NSInteger)selectedIndex first:(BOOL)first last:(BOOL)last onChoice:(void (^)(NSInteger))onChoice
{
    self.titleLabelV6.text = title ?: @"";
    self.titleLabelV6.textAlignment = [Language alignmentForCurrentLanguage];
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.stackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.onChoice = onChoice;

    for (UIView *subview in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    [self.cardButtons removeAllObjects];

    for (NSInteger i = 0; i < (NSInteger)titles.count; i++) {
        NSString *itemTitle = titles[i];
        NSString *itemIcon = (i < (NSInteger)icons.count) ? icons[i] : nil;
        PPSettingsChoiceButton *btn = [PPSettingsChoiceButton new];
        btn.optionIndex = i;
        [btn configureWithTitle:itemTitle iconName:itemIcon isChosen:(i == selectedIndex)];
        [btn addTarget:self action:@selector(pp_cardButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.stackView addArrangedSubview:btn];
        [self.cardButtons addObject:btn];
    }

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:(iconName ?: @"circle") withConfiguration:config];
    self.iconViewV6.image = [image imageWithTintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                                         renderingMode:UIImageRenderingModeAlwaysOriginal];

    self.surfaceView.layer.cornerRadius = (first || last) ? PPCornerCard : 0.0;
    if (@available(iOS 13.0, *)) self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    if (@available(iOS 11.0, *)) {
        CACornerMask mask = 0;
        if (first) mask |= (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner);
        if (last) mask |= (kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner);
        self.surfaceView.layer.maskedCorners = mask;
    }
    self.separatorViewV6.hidden = last;
}

- (void)pp_cardButtonTapped:(PPSettingsChoiceButton *)sender
{
    if (self.onChoice) self.onChoice(sender.optionIndex);
}

@end

#pragma mark - PPSettingsActionModal

@interface PPSettingsActionModalOption : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *iconName;
@property (nonatomic, strong, nullable) UIColor *iconTint;
@property (nonatomic, copy, nullable) NSArray<UIColor *> *swatches;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, assign) BOOL isDestructive;
@property (nonatomic, copy, nullable) dispatch_block_t actionBlock;
@end

@implementation PPSettingsActionModalOption
@end

@interface PPSettingsActionModalVC : UIViewController
@property (nonatomic, copy) NSString *headerIconName;
@property (nonatomic, strong, nullable) UIColor *headerIconTint;
@property (nonatomic, copy) NSString *modalTitle;
@property (nonatomic, copy, nullable) NSString *modalSubtitle;
@property (nonatomic, copy) NSArray<PPSettingsActionModalOption *> *options;
@property (nonatomic, copy, nullable) NSString *cancelTitle;
@property (nonatomic, strong) UIView *dimmedBackgroundView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) NSLayoutConstraint *cardBottomConstraint;

+ (void)presentIn:(UIViewController *)parent
            title:(NSString *)title
         subtitle:(nullable NSString *)subtitle
         iconName:(nullable NSString *)iconName
         iconTint:(nullable UIColor *)iconTint
          options:(NSArray<PPSettingsActionModalOption *> *)options;
@end

@implementation PPSettingsActionModalVC

+ (void)presentIn:(UIViewController *)parent
            title:(NSString *)title
         subtitle:(NSString *)subtitle
         iconName:(NSString *)iconName
         iconTint:(UIColor *)iconTint
          options:(NSArray<PPSettingsActionModalOption *> *)options
{
    PPSettingsActionModalVC *vc = [PPSettingsActionModalVC new];
    vc.modalTitle = title;
    vc.modalSubtitle = subtitle;
    vc.headerIconName = iconName;
    vc.headerIconTint = iconTint ?: AppPrimaryClr;
    vc.options = options;
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [parent presentViewController:vc animated:NO completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *dimmed = [UIView new];
    dimmed.translatesAutoresizingMaskIntoConstraints = NO;
    dimmed.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    dimmed.alpha = 0.0;
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissModalAnimated)];
    [dimmed addGestureRecognizer:dismissTap];
    [self.view addSubview:dimmed];
    self.dimmedBackgroundView = dimmed;

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:PPSettingsV6HairlineColor()];
    card.layer.cornerRadius = 32.0;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    if (@available(iOS 11.0, *)) {
        card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.16;
    card.layer.shadowRadius = 24.0;
    card.layer.shadowOffset = CGSizeMake(0, -6);
    card.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:card];
    self.cardView = card;

    // Grabber pill
    UIView *grabber = [UIView new];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent:0.20];
    PPApplyContinuousCorners(grabber, 2.5);
    [card addSubview:grabber];

    // Icon Shell
    UIView *iconShell = [UIView new];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [(self.headerIconTint ?: AppPrimaryClr) colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(iconShell, 24.0);
    [card addSubview:iconShell];

    UIImageView *headerIcon = [UIImageView new];
    headerIcon.translatesAutoresizingMaskIntoConstraints = NO;
    headerIcon.contentMode = UIViewContentModeScaleAspectFit;
    UIImageSymbolConfiguration *symConf = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
    headerIcon.image = [[UIImage systemImageNamed:(self.headerIconName ?: @"slider.horizontal.3") withConfiguration:symConf]
                        imageWithTintColor:(self.headerIconTint ?: AppPrimaryClr) renderingMode:UIImageRenderingModeAlwaysOriginal];
    [iconShell addSubview:headerIcon];

    // Title
    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3]
                       scaledFontForFont:([GM boldFontWithSize:20.0] ?: [UIFont systemFontOfSize:20 weight:UIFontWeightBold])];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 2;
    titleLabel.text = self.modalTitle ?: @"";
    [card addSubview:titleLabel];

    // Subtitle
    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                          scaledFontForFont:([GM fontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular])];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 3;
    subtitleLabel.text = self.modalSubtitle ?: @"";
    [card addSubview:subtitleLabel];

    // Options Stack
    UIStackView *optionsStack = [UIStackView new];
    optionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    optionsStack.axis = UILayoutConstraintAxisVertical;
    optionsStack.spacing = 10.0;
    optionsStack.distribution = UIStackViewDistributionFill;
    optionsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [card addSubview:optionsStack];

    for (NSInteger i = 0; i < (NSInteger)self.options.count; i++) {
        PPSettingsActionModalOption *option = self.options[i];
        UIView *optionCard = [self pp_buildOptionCardForOption:option index:i];
        [optionsStack addArrangedSubview:optionCard];
    }

    // Cancel Button
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelBtn setTitle:(self.cancelTitle ?: (kLang(@"cancel") ?: @"إلغاء")) forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [GM boldFontWithSize:15.5] ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    [cancelBtn setTitleColor:(AppSecondaryTextClr ?: UIColor.secondaryLabelColor) forState:UIControlStateNormal];
    cancelBtn.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [[UIColor whiteColor] colorWithAlphaComponent:0.08]
            : [[UIColor blackColor] colorWithAlphaComponent:0.05];
    }];
    PPApplyContinuousCorners(cancelBtn, 16.0);
    [cancelBtn addTarget:self action:@selector(pp_dismissModalAnimated) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:cancelBtn];

    self.cardBottomConstraint = [card.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:600.0];

    [NSLayoutConstraint activateConstraints:@[
        [dimmed.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dimmed.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dimmed.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dimmed.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.cardBottomConstraint,

        [grabber.topAnchor constraintEqualToAnchor:card.topAnchor constant:10.0],
        [grabber.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:38.0],
        [grabber.heightAnchor constraintEqualToConstant:5.0],

        [iconShell.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:14.0],
        [iconShell.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [iconShell.widthAnchor constraintEqualToConstant:48.0],
        [iconShell.heightAnchor constraintEqualToConstant:48.0],
        [headerIcon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [headerIcon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [headerIcon.widthAnchor constraintEqualToConstant:24.0],
        [headerIcon.heightAnchor constraintEqualToConstant:24.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24.0],

        [optionsStack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:16.0],
        [optionsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPScreenMargin],
        [optionsStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPScreenMargin],

        [cancelBtn.topAnchor constraintEqualToAnchor:optionsStack.bottomAnchor constant:14.0],
        [cancelBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPScreenMargin],
        [cancelBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPScreenMargin],
        [cancelBtn.heightAnchor constraintEqualToConstant:50.0],
        [cancelBtn.bottomAnchor constraintEqualToAnchor:card.safeAreaLayoutGuide.bottomAnchor constant:-14.0]
    ]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.cardBottomConstraint.constant = 0.0;
    [UIView animateWithDuration:0.38
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self.view layoutIfNeeded];
        self.dimmedBackgroundView.alpha = 1.0;
    } completion:nil];
}

- (UIView *)pp_buildOptionCardForOption:(PPSettingsActionModalOption *)option index:(NSInteger)index
{
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.tag = index;
    card.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPApplyContinuousCorners(card, 18.0);
    card.layer.borderWidth = option.isSelected ? 1.8 : 1.0;
    
    UIColor *borderClr = option.isSelected
        ? (option.isDestructive ? UIColor.systemRedColor : (AppPrimaryClr ?: UIColor.systemPinkColor))
        : PPSettingsV6HairlineColor();
    [card pp_setBorderColor:borderClr];

    card.backgroundColor = option.isSelected
        ? [(option.isDestructive ? UIColor.systemRedColor : (AppPrimaryClr ?: UIColor.systemPinkColor)) colorWithAlphaComponent:0.08]
        : [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [[UIColor whiteColor] colorWithAlphaComponent:0.05]
                : [[UIColor blackColor] colorWithAlphaComponent:0.03];
        }];

    // Leading Container (Swatches or Icon Shell)
    UIView *leadingContainer = [UIView new];
    leadingContainer.translatesAutoresizingMaskIntoConstraints = NO;
    leadingContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [card addSubview:leadingContainer];

    if (option.swatches.count > 1) {
        UIView *iconShell = [UIView new];
        iconShell.translatesAutoresizingMaskIntoConstraints = NO;
        iconShell.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [[UIColor whiteColor] colorWithAlphaComponent:0.08]
                : [[UIColor blackColor] colorWithAlphaComponent:0.04];
        }];
        PPApplyContinuousCorners(iconShell, 14.0);
        [leadingContainer addSubview:iconShell];
        
        [NSLayoutConstraint activateConstraints:@[
            [iconShell.leadingAnchor constraintEqualToAnchor:leadingContainer.leadingAnchor],
            [iconShell.trailingAnchor constraintEqualToAnchor:leadingContainer.trailingAnchor],
            [iconShell.topAnchor constraintEqualToAnchor:leadingContainer.topAnchor],
            [iconShell.bottomAnchor constraintEqualToAnchor:leadingContainer.bottomAnchor]
        ]];

        UIStackView *gridStack = [UIStackView new];
        gridStack.translatesAutoresizingMaskIntoConstraints = NO;
        gridStack.axis = UILayoutConstraintAxisVertical;
        gridStack.spacing = 3.5;
        gridStack.alignment = UIStackViewAlignmentCenter;
        gridStack.distribution = UIStackViewDistributionEqualSpacing;
        [iconShell addSubview:gridStack];

        UIStackView *row1 = [UIStackView new];
        row1.translatesAutoresizingMaskIntoConstraints = NO;
        row1.axis = UILayoutConstraintAxisHorizontal;
        row1.spacing = 3.5;
        row1.alignment = UIStackViewAlignmentCenter;
        [gridStack addArrangedSubview:row1];

        UIStackView *row2 = [UIStackView new];
        row2.translatesAutoresizingMaskIntoConstraints = NO;
        row2.axis = UILayoutConstraintAxisHorizontal;
        row2.spacing = 3.5;
        row2.alignment = UIStackViewAlignmentCenter;
        [gridStack addArrangedSubview:row2];

        NSInteger total = option.swatches.count;
        for (NSInteger sIdx = 0; sIdx < total; sIdx++) {
            UIColor *color = option.swatches[sIdx];
            UIView *dot = [UIView new];
            dot.translatesAutoresizingMaskIntoConstraints = NO;
            dot.backgroundColor = color;
            dot.layer.cornerRadius = 5.5;
            dot.clipsToBounds = YES;
            dot.layer.borderWidth = 1.0;
            [dot pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.6]];
            
            [NSLayoutConstraint activateConstraints:@[
                [dot.widthAnchor constraintEqualToConstant:11.5],
                [dot.heightAnchor constraintEqualToConstant:11.5]
            ]];
            
            if (sIdx < 2) {
                [row1 addArrangedSubview:dot];
            } else {
                [row2 addArrangedSubview:dot];
            }
        }

        [NSLayoutConstraint activateConstraints:@[
            [gridStack.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
            [gridStack.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor]
        ]];
    } else if (option.swatches.count == 1) {
        UIView *iconShell = [UIView new];
        iconShell.translatesAutoresizingMaskIntoConstraints = NO;
        UIColor *tint = option.swatches.firstObject;
        iconShell.backgroundColor = [tint colorWithAlphaComponent:0.14];
        PPApplyContinuousCorners(iconShell, 14.0);
        [leadingContainer addSubview:iconShell];

        UIView *dot = [UIView new];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = tint;
        dot.layer.cornerRadius = 10.0;
        dot.clipsToBounds = YES;
        dot.layer.borderWidth = 1.5;
        [dot pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.7]];
        [iconShell addSubview:dot];

        [NSLayoutConstraint activateConstraints:@[
            [iconShell.leadingAnchor constraintEqualToAnchor:leadingContainer.leadingAnchor],
            [iconShell.trailingAnchor constraintEqualToAnchor:leadingContainer.trailingAnchor],
            [iconShell.topAnchor constraintEqualToAnchor:leadingContainer.topAnchor],
            [iconShell.bottomAnchor constraintEqualToAnchor:leadingContainer.bottomAnchor],

            [dot.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
            [dot.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
            [dot.widthAnchor constraintEqualToConstant:20.0],
            [dot.heightAnchor constraintEqualToConstant:20.0]
        ]];
    } else {
        UIView *iconShell = [UIView new];
        iconShell.translatesAutoresizingMaskIntoConstraints = NO;
        UIColor *tint = option.isDestructive ? UIColor.systemRedColor : (option.iconTint ?: AppPrimaryClr);
        iconShell.backgroundColor = [tint colorWithAlphaComponent:0.12];
        PPApplyContinuousCorners(iconShell, 14.0);
        [leadingContainer addSubview:iconShell];

        UIImageView *icon = [UIImageView new];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        icon.image = [[UIImage systemImageNamed:(option.iconName ?: @"circle.fill") withConfiguration:sym]
                      imageWithTintColor:tint renderingMode:UIImageRenderingModeAlwaysOriginal];
        [iconShell addSubview:icon];

        [NSLayoutConstraint activateConstraints:@[
            [iconShell.leadingAnchor constraintEqualToAnchor:leadingContainer.leadingAnchor],
            [iconShell.trailingAnchor constraintEqualToAnchor:leadingContainer.trailingAnchor],
            [iconShell.topAnchor constraintEqualToAnchor:leadingContainer.topAnchor],
            [iconShell.bottomAnchor constraintEqualToAnchor:leadingContainer.bottomAnchor],
            [icon.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:20.0],
            [icon.heightAnchor constraintEqualToConstant:20.0]
        ]];
    }

    // Trailing Checkmark / Radio
    UIImageView *checkIcon = [UIImageView new];
    checkIcon.translatesAutoresizingMaskIntoConstraints = NO;
    checkIcon.contentMode = UIViewContentModeScaleAspectFit;
    UIImageSymbolConfiguration *chkConf = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
    if (option.isSelected) {
        UIColor *tint = option.isDestructive ? UIColor.systemRedColor : (AppPrimaryClr ?: UIColor.systemPinkColor);
        checkIcon.image = [[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:chkConf]
                           imageWithTintColor:tint renderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        checkIcon.image = [[UIImage systemImageNamed:@"circle" withConfiguration:chkConf]
                           imageWithTintColor:(AppTertiaryTextClr ?: UIColor.tertiaryLabelColor) renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    [card addSubview:checkIcon];

    // Title & Subtitle Labels
    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                     scaledFontForFont:([GM boldFontWithSize:15.5] ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightBold])];
    titleLbl.adjustsFontForContentSizeCategory = YES;
    titleLbl.textColor = option.isDestructive ? UIColor.systemRedColor : (AppPrimaryTextClr ?: UIColor.labelColor);
    titleLbl.textAlignment = [Language alignmentForCurrentLanguage];
    titleLbl.text = option.title ?: @"";
    [card addSubview:titleLbl];

    UILabel *subLbl = [UILabel new];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                   scaledFontForFont:([GM fontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5])];
    subLbl.adjustsFontForContentSizeCategory = YES;
    subLbl.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subLbl.textAlignment = [Language alignmentForCurrentLanguage];
    subLbl.numberOfLines = 2;
    subLbl.text = option.subtitle ?: @"";
    [card addSubview:subLbl];

    [NSLayoutConstraint activateConstraints:@[
        [leadingContainer.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [leadingContainer.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [leadingContainer.widthAnchor constraintEqualToConstant:40.0],
        [leadingContainer.heightAnchor constraintEqualToConstant:40.0],

        [checkIcon.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [checkIcon.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [checkIcon.widthAnchor constraintEqualToConstant:22.0],
        [checkIcon.heightAnchor constraintEqualToConstant:22.0],

        [titleLbl.leadingAnchor constraintEqualToAnchor:leadingContainer.trailingAnchor constant:12.0],
        [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:checkIcon.leadingAnchor constant:-10.0],
        [titleLbl.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],

        [subLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.trailingAnchor constraintLessThanOrEqualToAnchor:checkIcon.leadingAnchor constant:-10.0],
        [subLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:3.0],
        [subLbl.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0],

        [card.heightAnchor constraintGreaterThanOrEqualToConstant:68.0]
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_optionCardTapped:)];
    [card addGestureRecognizer:tap];
    card.userInteractionEnabled = YES;

    return card;
}

- (void)pp_optionCardTapped:(UITapGestureRecognizer *)sender
{
    NSInteger index = sender.view.tag;
    if (index < 0 || index >= (NSInteger)self.options.count) return;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    PPSettingsActionModalOption *option = self.options[index];
    [UIView animateWithDuration:0.10 animations:^{
        sender.view.transform = CGAffineTransformMakeScale(0.97, 0.97);
        sender.view.alpha = 0.85;
    } completion:^(BOOL finished) {
        [self pp_dismissModalWithCompletion:^{
            if (option.actionBlock) option.actionBlock();
        }];
    }];
}

- (void)pp_dismissModalAnimated
{
    [self pp_dismissModalWithCompletion:nil];
}

- (void)pp_dismissModalWithCompletion:(dispatch_block_t)completion
{
    self.cardBottomConstraint.constant = 600.0;
    [UIView animateWithDuration:0.28
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        [self.view layoutIfNeeded];
        self.dimmedBackgroundView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:completion];
    }];
}

@end


#pragma mark - Cell IDs

static NSString *const kSettingsCellID  = @"PPSettingsCell";
static NSString *const kHeroCellID      = @"PPSettingsHeroCell";
static NSString *const kLocationCellID  = @"PPSettingsLocationCell";
static NSString *const kVersionCellID   = @"PPVersionCell";
static NSString *const kLanguageCellID  = @"PPLanguageCell";
static NSString *const kThemeCellID    = @"PPThemeCell";

#pragma mark - SettingVC

@interface SettingVC () <UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPSettingsSectionModel *> *sections;
@property (nonatomic, strong) NSUserDefaults *prefs;
@property (nonatomic, assign) BOOL alertAppear;
@property (nonatomic, assign) BOOL didAnimateSettingsHeroCell;
@property (nonatomic, strong) CLLocationManager *settingsLocationManager;
@property (nonatomic, strong) CLGeocoder *settingsGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D settingsSelectedCoordinate;
@property (nonatomic, assign) BOOL hasSettingsSelectedCoordinate;
@property (nonatomic, copy) NSString *settingsSelectedAreaName;
@property (nonatomic, assign) PPSettingsLocationState settingsLocationState;
@property (nonatomic, assign) BOOL hasRequestedSettingsLocationAuthorization;
@property (nonatomic, assign) BOOL isUsingManualSettingsLocationSelection;
@property (nonatomic, assign) BOOL isPresentingSettingsLocationSheet;
- (void)pp_presentMarketplaceAccentOptions;
- (void)pp_applyMarketplaceUsesMainKindColors:(BOOL)usesMainKindColors;
@end

@implementation SettingVC

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.hidesBottomBarWhenPushed = YES;
    self.prefs = [NSUserDefaults standardUserDefaults];
    self.alertAppear = NO;
    self.view.backgroundColor = AppBackgroundClr;
    self.navigationItem.title = @"";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:nil
                    showBack:YES];

    [self pp_setupTableView];
    [self pp_configureSettingsLocationStateMachine];
    [self pp_buildSections];
    [self pp_setupNotificationObservers];
    
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:YES animation:animated];
    }
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:nil
                    showBack:YES];
    [self pp_configureSettingsLocationStateMachine];
    [self pp_buildSections];
    [self.tableView reloadData];
    [self pp_refreshNotificationStatusAsync];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if ((self.isMovingFromParentViewController || self.isBeingDismissed) &&
        [self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:NO animation:animated];
    }
}

- (void)dealloc
{
    self.settingsLocationManager.delegate = nil;
    [self.settingsGeocoder cancelGeocode];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table View Setup

- (void)pp_setupTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 76.0;
    self.tableView.estimatedSectionHeaderHeight = 44.0;
    self.tableView.estimatedSectionFooterHeight = 52.0;
    self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, PPSpaceXXL, 0.0);
    self.tableView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, PPSpaceBase, 0.0);
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    [self.tableView registerClass:PPSettingsV6RowCell.class forCellReuseIdentifier:kSettingsCellID];
    [self.tableView registerClass:PPSettingsV6HeroCell.class forCellReuseIdentifier:kHeroCellID];
    [self.tableView registerClass:PPSettingsV6LocationCell.class forCellReuseIdentifier:kLocationCellID];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kVersionCellID];
    [self.tableView registerClass:PPSettingsV6ChoiceCell.class forCellReuseIdentifier:kLanguageCellID];
    [self.tableView registerClass:PPSettingsV6ChoiceCell.class forCellReuseIdentifier:kThemeCellID];

    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark - Build Sections

- (BOOL)pp_boolPreferenceForKey:(NSString *)key defaultValue:(BOOL)defaultValue
{
    if (key.length == 0) {
        return defaultValue;
    }
    id storedValue = [self.prefs objectForKey:key];
    if (!storedValue) {
        return defaultValue;
    }
    return [self.prefs boolForKey:key];
}

- (void)pp_buildSections
{
    NSMutableArray<PPSettingsSectionModel *> *allSections = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    PPSettingsSectionModel *heroSection = [PPSettingsSectionModel new];
    PPSettingsRowModel *heroRow = [PPSettingsRowModel new];
    heroRow.type = PPSettingsRowTypeHero;
    heroRow.title = PPSettingsLocalizedString(@"settings_v6_title", @"Settings");
    heroRow.subtitle = PPSettingsLocalizedString(@"settings_v6_subtitle",
                                                  @"Make Pure Pets feel right for you.");
    heroSection.rows = @[heroRow];
    [allSections addObject:heroSection];

    PPSettingsSectionModel *locationSection = [PPSettingsSectionModel new];
    PPSettingsRowModel *locationRow = [PPSettingsRowModel new];
    locationRow.type = PPSettingsRowTypeLocation;
    locationRow.title = [self pp_settingsLocationTitleText];
    locationRow.subtitle = [self pp_settingsLocationActionTitle] ?: @"";
    locationRow.onTap = ^{ [weakSelf pp_presentSettingsLocationOptions]; };
    locationSection.rows = @[locationRow];
    [allSections addObject:locationSection];

    PPSettingsSectionModel *experience = [PPSettingsSectionModel new];
    experience.headerTitle = PPSettingsLocalizedString(@"settings_experience_title", @"Experience");

    PPSettingsRowModel *themeRow = [PPSettingsRowModel new];
    themeRow.type = PPSettingsRowTypeThemePicker;
    themeRow.title = PPSettingsLocalizedString(@"settings_appearance_title", @"Appearance");
    themeRow.iconName = @"circle.lefthalf.filled";
    UIUserInterfaceStyle currentStyle = [self loadUserInterfaceStyle];
    themeRow.themeIndex = currentStyle == UIUserInterfaceStyleLight ? 0 : (currentStyle == UIUserInterfaceStyleDark ? 1 : 2);
    themeRow.onThemeTap = ^(NSInteger index) { [weakSelf pp_applyThemeAtIndex:index]; };

    BOOL usesMainKindAccentColors = [self.prefs boolForKey:PPMarketplaceUsesMainKindAccentColorsPreferenceKey];
    PPSettingsRowModel *accentRow = [PPSettingsRowModel new];
    accentRow.type = PPSettingsRowTypeNavigation;
    accentRow.title = PPSettingsLocalizedString(@"settings_marketplace_accent_title", @"Marketplace accent");
    accentRow.subtitle = usesMainKindAccentColors
        ? PPSettingsLocalizedString(@"settings_marketplace_accent_main_kind", @"Pet category colors")
        : PPSettingsLocalizedString(@"settings_marketplace_accent_brand", @"Pure Pets brand color");
    accentRow.iconName = @"paintpalette.fill";
    accentRow.onTap = ^{ [weakSelf pp_presentMarketplaceAccentOptions]; };

    PPSettingsRowModel *languageRow = [PPSettingsRowModel new];
    languageRow.type = PPSettingsRowTypeLanguage;
    languageRow.title = PPSettingsLocalizedString(@"settings_language_title", @"Language");
    languageRow.iconName = @"globe";
    languageRow.languageIndex = Language.isRTL ? 0 : 1;
    languageRow.onLanguageTap = ^(NSInteger index) {
        NSInteger currentIndex = [Language languageVal] == 0 ? 1 : 0;
        if (index != currentIndex) [weakSelf showLanguageSetupAlertFrom:weakSelf];
    };

    experience.rows = @[themeRow, accentRow, languageRow];
    [allSections addObject:experience];

    PPSettingsSectionModel *privacy = [PPSettingsSectionModel new];
    privacy.headerTitle = PPSettingsLocalizedString(@"settings_privacy_alerts_title", @"Privacy & Alerts");
    BOOL privacyControlsEnabled = PPIsUserLoggedIn;
    NSString *privacyLoginHint = PPSettingsLocalizedString(@"settings_privacy_login_footer",
                                                            @"Sign in to manage chat privacy and notification preferences.");
    privacy.footerTitle = privacyControlsEnabled ? nil : privacyLoginHint;

    PPSettingsRowModel *notificationsRow = [PPSettingsRowModel new];
    notificationsRow.type = PPSettingsRowTypeToggle;
    notificationsRow.title = kLang(@"notificationsSetPalce") ?: @"Notifications";
    notificationsRow.iconName = @"bell.fill";
    notificationsRow.enabled = privacyControlsEnabled;
    notificationsRow.toggleEnabled = privacyControlsEnabled;
    notificationsRow.disabledHint = privacyLoginHint;
    notificationsRow.toggleValue = [self pp_boolPreferenceForKey:kSettingsNotificationsKey defaultValue:YES];
    notificationsRow.onToggle = ^(BOOL isOn) { [weakSelf pp_handleNotificationToggle:isOn]; };

    NSInteger savedPrivacy = [self.prefs integerForKey:kSettingsMessagesPrivacyKey];
    PPSettingsRowModel *messagesRow = [PPSettingsRowModel new];
    messagesRow.type = PPSettingsRowTypeNavigation;
    messagesRow.title = kLang(@"kmessagesSetPalce") ?: @"Messages";
    messagesRow.iconName = @"message.fill";
    messagesRow.enabled = privacyControlsEnabled;
    messagesRow.disabledHint = privacyLoginHint;
    messagesRow.subtitle = privacyControlsEnabled
        ? ((savedPrivacy == 1) ? (kLang(@"noOne") ?: @"No one") : (kLang(@"everyone") ?: @"Everyone"))
        : nil;
    messagesRow.onTap = ^{ [weakSelf pp_showMessagesPrivacyPicker]; };

    privacy.rows = @[notificationsRow, messagesRow];
    [allSections addObject:privacy];

    PPSettingsSectionModel *dataLegal = [PPSettingsSectionModel new];
    dataLegal.headerTitle = PPSettingsLocalizedString(@"settings_data_legal_title", @"Data & Legal");

    PPSettingsRowModel *cacheRow = [PPSettingsRowModel new];
    cacheRow.type = PPSettingsRowTypeNavigation;
    cacheRow.title = kLang(@"ClearCache") ?: @"Clear Cache";
    cacheRow.subtitle = [self pp_formattedCacheSize];
    cacheRow.iconName = @"internaldrive.fill";
    cacheRow.onTap = ^{ [weakSelf pp_clearCache]; };

    PPSettingsRowModel *privacyPolicyRow = [PPSettingsRowModel new];
    privacyPolicyRow.type = PPSettingsRowTypeNavigation;
    privacyPolicyRow.title = kLang(@"PrivacyPolicy") ?: @"Privacy Policy";
    privacyPolicyRow.iconName = @"hand.raised.fill";
    privacyPolicyRow.onTap = ^{ [weakSelf pp_openLegalURL:kPPPrivacyPolicyURL]; };

    PPSettingsRowModel *termsRow = [PPSettingsRowModel new];
    termsRow.type = PPSettingsRowTypeNavigation;
    termsRow.title = kLang(@"TermsOfService") ?: @"Terms of Service";
    termsRow.iconName = @"doc.text.fill";
    termsRow.onTap = ^{ [weakSelf pp_openLegalURL:kPPTermsOfServiceURL]; };

    dataLegal.rows = @[cacheRow, privacyPolicyRow, termsRow];
    [allSections addObject:dataLegal];

    if (PPIsUserLoggedIn) {
        PPSettingsSectionModel *account = [PPSettingsSectionModel new];
        account.headerTitle = kLang(@"Account") ?: @"Account";

        PPSettingsRowModel *logoutRow = [PPSettingsRowModel new];
        logoutRow.type = PPSettingsRowTypeDestructive;
        logoutRow.title = kLang(@"Logout") ?: @"Logout";
        logoutRow.subtitle = PPSettingsLocalizedString(@"settings_logout_subtitle", @"Sign out on this device");
        logoutRow.iconName = @"rectangle.portrait.and.arrow.right";
        logoutRow.onTap = ^{ [weakSelf pp_confirmLogout]; };

        PPSettingsRowModel *deleteRow = [PPSettingsRowModel new];
        deleteRow.type = PPSettingsRowTypeDestructive;
        deleteRow.title = kLang(@"delete_account") ?: @"Delete Account";
        deleteRow.subtitle = PPSettingsLocalizedString(@"settings_delete_subtitle", @"Permanently remove your account and data");
        deleteRow.iconName = @"person.crop.circle.badge.minus";
        deleteRow.onTap = ^{ [weakSelf pp_confirmDeleteAccount]; };

        account.rows = @[logoutRow, deleteRow];
        [allSections addObject:account];
    }

    PPSettingsSectionModel *versionSection = [PPSettingsSectionModel new];
    PPSettingsRowModel *versionRow = [PPSettingsRowModel new];
    versionRow.type = PPSettingsRowTypeVersion;
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    versionRow.title = [NSString stringWithFormat:@"Pure Pets · v%@ (%@)", version, build];
    versionSection.rows = @[versionRow];
    [allSections addObject:versionSection];

    self.sections = [allSections copy];
}

#pragma mark - Home Location Section

- (CLAuthorizationStatus)pp_currentSettingsLocationAuthorizationStatus
{
    if (@available(iOS 14.0, *)) {
        return self.settingsLocationManager.authorizationStatus;
    }
    return [CLLocationManager authorizationStatus];
}

- (void)pp_configureSettingsLocationStateMachine
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.settingsSelectedCoordinate = kCLLocationCoordinate2DInvalid;
    self.hasSettingsSelectedCoordinate = NO;
    self.settingsSelectedAreaName = @"";

    if ([defaults objectForKey:PPSettingsNearbySelectedLatitudeKey] &&
        [defaults objectForKey:PPSettingsNearbySelectedLongitudeKey]) {
        CLLocationCoordinate2D persisted =
            CLLocationCoordinate2DMake([defaults doubleForKey:PPSettingsNearbySelectedLatitudeKey],
                                       [defaults doubleForKey:PPSettingsNearbySelectedLongitudeKey]);
        if (CLLocationCoordinate2DIsValid(persisted) &&
            !(fabs(persisted.latitude) < DBL_EPSILON && fabs(persisted.longitude) < DBL_EPSILON)) {
            self.settingsSelectedCoordinate = persisted;
            self.hasSettingsSelectedCoordinate = YES;
            self.settingsSelectedAreaName =
                [defaults stringForKey:PPSettingsNearbySelectedAreaNameKey] ?: @"";
        }
    }

    if (!self.settingsLocationManager) {
        self.settingsLocationManager = [[CLLocationManager alloc] init];
        self.settingsLocationManager.delegate = self;
        self.settingsLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        self.settingsLocationManager.distanceFilter = 75.0;
    }
    if (!self.settingsGeocoder) {
        self.settingsGeocoder = [[CLGeocoder alloc] init];
    }

    [self pp_updateSettingsLocationStateForAuthorizationStatus:[self pp_currentSettingsLocationAuthorizationStatus]];
}

- (void)pp_updateSettingsLocationStateForAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusDenied ||
        status == kCLAuthorizationStatusRestricted) {
        self.settingsLocationState = self.hasSettingsSelectedCoordinate
            ? PPSettingsLocationStateReady
            : PPSettingsLocationStateDenied;
        [self pp_refreshSettingsLocationRowAnimated:YES];
        return;
    }

    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            self.settingsLocationState = (self.hasSettingsSelectedCoordinate ||
                                          self.isUsingManualSettingsLocationSelection)
                ? PPSettingsLocationStateReady
                : PPSettingsLocationStateLoading;
            if (!self.isUsingManualSettingsLocationSelection) {
                [self pp_requestSettingsCurrentLocationIfNeeded];
            }
            break;
        case kCLAuthorizationStatusNotDetermined:
            self.settingsLocationState = self.hasSettingsSelectedCoordinate
                ? PPSettingsLocationStateReady
                : PPSettingsLocationStateLoading;
            if (!self.hasRequestedSettingsLocationAuthorization) {
                self.hasRequestedSettingsLocationAuthorization = YES;
                [self.settingsLocationManager requestWhenInUseAuthorization];
            }
            break;
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            self.settingsLocationState = self.hasSettingsSelectedCoordinate
                ? PPSettingsLocationStateReady
                : PPSettingsLocationStateDenied;
            break;
    }

    [self pp_refreshSettingsLocationRowAnimated:YES];
}

- (void)pp_requestSettingsCurrentLocationIfNeeded
{
    if (!self.settingsLocationManager || self.isUsingManualSettingsLocationSelection) {
        return;
    }
    [self.settingsLocationManager requestLocation];
}

- (NSString *)pp_settingsLocationTitleText
{
    switch (self.settingsLocationState) {
        case PPSettingsLocationStateLoading:
            return kLang(@"Loading...") ?: @"Loading...";
        case PPSettingsLocationStateDenied:
            return kLang(@"Location permission denied") ?: @"Location permission denied";
        case PPSettingsLocationStateReady:
            if (self.settingsSelectedAreaName.length > 0) {
                return self.settingsSelectedAreaName;
            }
            return kLang(@"Select your location") ?: @"Select your location";
        case PPSettingsLocationStateUnset:
        default:
            return kLang(@"Select your location") ?: @"Select your location";
    }
}

- (nullable NSString *)pp_settingsLocationActionTitle
{
    switch (self.settingsLocationState) {
        case PPSettingsLocationStateDenied:
            return kLang(@"Open Settings") ?: @"Open Settings";
        case PPSettingsLocationStateReady:
            return kLang(@"Hero_ChangeArea") ?: @"Change area";
        case PPSettingsLocationStateUnset:
            return kLang(@"Hero_LocationCTA") ?: @"Choose area";
        case PPSettingsLocationStateLoading:
        default:
            return nil;
    }
}

- (UIColor *)pp_settingsLocationStatusColor
{
    switch (self.settingsLocationState) {
        case PPSettingsLocationStateDenied:
            return UIColor.systemRedColor;
        case PPSettingsLocationStateLoading:
            return UIColor.systemOrangeColor;
        case PPSettingsLocationStateReady:
            return AppPrimaryClr ?: UIColor.systemGreenColor;
        case PPSettingsLocationStateUnset:
        default:
            return AppSecondaryTextClr ?: UIColor.systemGrayColor;
    }
}

- (BOOL)pp_settingsLocationShowsLoading
{
    return self.settingsLocationState == PPSettingsLocationStateLoading;
}

- (NSString *)pp_settingsLocationAccessibilityHint
{
    NSString *actionTitle = [self pp_settingsLocationActionTitle];
    NSString *safeActionTitle = PPSafeString(actionTitle);
    if (safeActionTitle.length > 0) {
        return safeActionTitle;
    }
    return kLang(@"Hero_LocationCTA") ?: @"Choose area";
}

- (NSString *)pp_settingsLocationCurrentSubtitle
{
    NSString *currentSubtitleKey = @"home_location_sheet_current_subtitle_unset";
    if (self.settingsLocationState == PPSettingsLocationStateDenied) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_denied";
    } else if (self.isUsingManualSettingsLocationSelection) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_manual";
    } else if (self.settingsLocationState == PPSettingsLocationStateReady) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_auto";
    }
    return kLang(currentSubtitleKey) ?: @"";
}

- (void)pp_presentSettingsLocationOptions
{
    if (self.isPresentingSettingsLocationSheet) {
        return;
    }
    if ([self.presentedViewController isKindOfClass:PPHomeLocationSheetViewController.class]) {
        return;
    }
    if (self.presentedViewController || self.isBeingPresented || self.isBeingDismissed) {
        return;
    }

    self.isPresentingSettingsLocationSheet = YES;
    PPHomeLocationSheetViewController *sheet = [[PPHomeLocationSheetViewController alloc] init];
    sheet.sheetTitleText = kLang(@"home_location_sheet_title") ?: @"Choose your smart location";
    sheet.sheetSubtitleText = kLang(@"home_location_sheet_subtitle") ?: @"Switch between your live GPS position and recent areas quickly, while keeping nearby discovery smooth.";
    sheet.currentLocationTitle = [self pp_settingsLocationTitleText];
    sheet.currentLocationSubtitle = [self pp_settingsLocationCurrentSubtitle];
    sheet.showsUseCurrentLocationAction = (self.settingsLocationState != PPSettingsLocationStateDenied);
    sheet.showsOpenSettingsAction = (self.settingsLocationState == PPSettingsLocationStateDenied);
    sheet.recentLocations = [self pp_recentSettingsLocationRecords];

    __weak typeof(self) weakSelf = self;
    sheet.onUseCurrentLocation = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_switchSettingsLocationBackToAutomatic];
    };
    sheet.onChangeArea = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_openSettingsLocationPicker];
    };
    sheet.onOpenSettings = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_openSettingsLocationSettings];
    };
    sheet.onSelectRecentLocation = ^(NSDictionary *locationRecord) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_applySettingsNearbyLocationRecord:locationRecord];
    };

    [self pp_emitSettingsSelectionHaptic];
    [PPFunc presentFloatingSheetFrom:self sheetVC:sheet detentStyle:PPSheetDetentStyle80 withCompletion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isPresentingSettingsLocationSheet = NO;
    }];
}

- (void)pp_switchSettingsLocationBackToAutomatic
{
    self.isUsingManualSettingsLocationSelection = NO;
    [self pp_emitSettingsSelectionHaptic];
    if (!self.settingsLocationManager) {
        [self pp_configureSettingsLocationStateMachine];
        return;
    }
    [self pp_updateSettingsLocationStateForAuthorizationStatus:[self pp_currentSettingsLocationAuthorizationStatus]];
}

- (void)pp_openSettingsLocationSettings
{
    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
    }
}

- (void)pp_openSettingsLocationPicker
{
    LocationPickerViewController *picker = [[LocationPickerViewController alloc] init];
    picker.hidesBottomBarWhenPushed = YES;
    if (self.hasSettingsSelectedCoordinate &&
        CLLocationCoordinate2DIsValid(self.settingsSelectedCoordinate)) {
        picker.initialCoordinate = self.settingsSelectedCoordinate;
    }

    __weak typeof(self) weakSelf = self;
    void (^applyPickedCoordinate)(CLLocationCoordinate2D, NSString *) =
    ^(CLLocationCoordinate2D coordinate, NSString *resolvedTitle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!CLLocationCoordinate2DIsValid(coordinate) ||
            (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
            return;
        }

        NSString *resolvedAreaName = PPSafeString(resolvedTitle);
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = kLang(@"Select your location") ?: @"Select your location";
        }
        self.isUsingManualSettingsLocationSelection = YES;
        self.settingsSelectedCoordinate = coordinate;
        self.hasSettingsSelectedCoordinate = YES;
        self.settingsSelectedAreaName = resolvedAreaName;
        self.settingsLocationState = PPSettingsLocationStateReady;
        [self pp_recordRecentSettingsLocationCoordinate:coordinate
                                                  title:resolvedAreaName
                                                 source:@"manual"];
        [self pp_persistSettingsLocationIfNeeded];
        [self pp_refreshSettingsLocationRowAnimated:YES];
        [self pp_emitSettingsSelectionHaptic];
    };

    picker.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        if (!gmsAddress) return;
        NSString *resolvedAreaName = [LocationPickerViewController titleFromAddress:gmsAddress] ?: @"";
        if (resolvedAreaName.length == 0 && gmsAddress.lines.count > 0) {
            resolvedAreaName = [gmsAddress.lines componentsJoinedByString:@", "] ?: @"";
        }
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = gmsAddress.country ?: @"";
        }
        applyPickedCoordinate(gmsAddress.coordinate, resolvedAreaName);
    };
    picker.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        applyPickedCoordinate(coordinate, locationTitle);
    };

    if (self.navigationController) {
        [self.navigationController pushViewController:picker animated:YES];
    } else {
        picker.view.layer.cornerRadius = 42.0;
        [PPFunc presentFloatingSheetFrom:self sheetVC:picker detentStyle:PPSheetDetentStyle80];
    }
}

- (NSArray<NSDictionary *> *)pp_recentSettingsLocationRecords
{
    id savedRecords =
        [NSUserDefaults.standardUserDefaults objectForKey:PPSettingsNearbyRecentLocationsKey];
    if (![savedRecords isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *records = [NSMutableArray array];
    for (NSDictionary *record in (NSArray *)savedRecords) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSNumber *latitude = record[@"latitude"];
        NSNumber *longitude = record[@"longitude"];
        NSString *title = PPSafeString(record[@"title"]);
        CLLocationCoordinate2D coordinate =
            CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
        if (!CLLocationCoordinate2DIsValid(coordinate) || title.length == 0) {
            continue;
        }
        [records addObject:record];
    }

    [records sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSNumber *time1 = obj1[@"timestamp"];
        NSNumber *time2 = obj2[@"timestamp"];
        return [time2 compare:time1];
    }];

    if (records.count > PPSettingsNearbyRecentLocationsLimit) {
        return [records subarrayWithRange:NSMakeRange(0, PPSettingsNearbyRecentLocationsLimit)];
    }
    return records.copy;
}

- (void)pp_recordRecentSettingsLocationCoordinate:(CLLocationCoordinate2D)coordinate
                                            title:(NSString *)title
                                           source:(NSString *)source
{
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }

    NSString *safeTitle = PPSafeString(title);
    if (safeTitle.length == 0) {
        return;
    }

    NSMutableArray<NSDictionary *> *records =
        [[self pp_recentSettingsLocationRecords] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray<NSDictionary *> *filtered = [NSMutableArray array];

    for (NSDictionary *record in records) {
        NSNumber *latitude = record[@"latitude"];
        NSNumber *longitude = record[@"longitude"];
        NSString *existingTitle = PPSafeString(record[@"title"]);
        BOOL sameTitle = [existingTitle isEqualToString:safeTitle];
        BOOL sameCoordinate =
            fabs(latitude.doubleValue - coordinate.latitude) < 0.0001 &&
            fabs(longitude.doubleValue - coordinate.longitude) < 0.0001;
        if (sameTitle || sameCoordinate) {
            continue;
        }
        [filtered addObject:record];
    }

    NSDictionary *newRecord = @{
        @"latitude" : @(coordinate.latitude),
        @"longitude" : @(coordinate.longitude),
        @"title" : safeTitle,
        @"source" : PPSafeString(source),
        @"timestamp" : @([[NSDate date] timeIntervalSince1970])
    };
    [filtered insertObject:newRecord atIndex:0];

    if (filtered.count > PPSettingsNearbyRecentLocationsLimit) {
        [filtered removeObjectsInRange:NSMakeRange(PPSettingsNearbyRecentLocationsLimit,
                                                   filtered.count - PPSettingsNearbyRecentLocationsLimit)];
    }

    [NSUserDefaults.standardUserDefaults setObject:filtered.copy
                                            forKey:PPSettingsNearbyRecentLocationsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)pp_applySettingsNearbyLocationRecord:(NSDictionary *)record
{
    if (![record isKindOfClass:NSDictionary.class]) {
        return;
    }

    NSNumber *latitude = record[@"latitude"];
    NSNumber *longitude = record[@"longitude"];
    NSString *title = PPSafeString(record[@"title"]);
    CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
    if (!CLLocationCoordinate2DIsValid(coordinate) || title.length == 0) {
        return;
    }

    self.isUsingManualSettingsLocationSelection = YES;
    self.settingsSelectedCoordinate = coordinate;
    self.hasSettingsSelectedCoordinate = YES;
    self.settingsSelectedAreaName = title;
    self.settingsLocationState = PPSettingsLocationStateReady;
    [self pp_recordRecentSettingsLocationCoordinate:coordinate title:title source:@"recent"];
    [self pp_persistSettingsLocationIfNeeded];
    [self pp_refreshSettingsLocationRowAnimated:YES];
    [self pp_emitSettingsSelectionHaptic];
}

- (void)pp_persistSettingsLocationIfNeeded
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (self.hasSettingsSelectedCoordinate &&
        CLLocationCoordinate2DIsValid(self.settingsSelectedCoordinate) &&
        isfinite(self.settingsSelectedCoordinate.latitude) &&
        isfinite(self.settingsSelectedCoordinate.longitude)) {
        [defaults setDouble:self.settingsSelectedCoordinate.latitude
                     forKey:PPSettingsNearbySelectedLatitudeKey];
        [defaults setDouble:self.settingsSelectedCoordinate.longitude
                     forKey:PPSettingsNearbySelectedLongitudeKey];
        [defaults setObject:self.settingsSelectedAreaName ?: @""
                     forKey:PPSettingsNearbySelectedAreaNameKey];
    } else {
        [defaults removeObjectForKey:PPSettingsNearbySelectedLatitudeKey];
        [defaults removeObjectForKey:PPSettingsNearbySelectedLongitudeKey];
        [defaults removeObjectForKey:PPSettingsNearbySelectedAreaNameKey];
    }
    [defaults synchronize];
}

- (NSIndexPath *)pp_indexPathForRowType:(PPSettingsRowType)rowType
{
    for (NSInteger section = 0; section < (NSInteger)self.sections.count; section++) {
        NSArray<PPSettingsRowModel *> *rows = self.sections[section].rows;
        for (NSInteger row = 0; row < (NSInteger)rows.count; row++) {
            if (rows[row].type == rowType) {
                return [NSIndexPath indexPathForRow:row inSection:section];
            }
        }
    }
    return nil;
}

- (void)pp_refreshSettingsLocationRowAnimated:(BOOL)animated
{
    NSIndexPath *indexPath = [self pp_indexPathForRowType:PPSettingsRowTypeLocation];
    if (!indexPath) return;

    PPSettingsV6LocationCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:PPSettingsV6LocationCell.class]) {
        [cell configureWithTitle:[self pp_settingsLocationTitleText]
                          action:[self pp_settingsLocationActionTitle]
                     statusColor:[self pp_settingsLocationStatusColor]
                         loading:[self pp_settingsLocationShowsLoading]
               accessibilityHint:[self pp_settingsLocationAccessibilityHint]
                        animated:animated];
    }
}

- (void)pp_emitSettingsSelectionHaptic
{
    UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
    [generator prepare];
    [generator selectionChanged];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    if (manager != self.settingsLocationManager) {
        return;
    }
    [self pp_updateSettingsLocationStateForAuthorizationStatus:manager.authorizationStatus];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (manager != self.settingsLocationManager) {
        return;
    }
    [self pp_updateSettingsLocationStateForAuthorizationStatus:status];
}
#pragma clang diagnostic pop

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (manager != self.settingsLocationManager ||
        self.isUsingManualSettingsLocationSelection) {
        return;
    }

    CLLocation *latest = locations.lastObject;
    if (!latest) {
        return;
    }

    CLLocationCoordinate2D coordinate = latest.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate) ||
        (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
        return;
    }

    self.settingsSelectedCoordinate = coordinate;
    self.hasSettingsSelectedCoordinate = YES;

    [self.settingsGeocoder cancelGeocode];
    __weak typeof(self) weakSelf = self;
    CLLocation *location =
        [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    [self.settingsGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks,
                                                                               NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            NSString *area = self.settingsSelectedAreaName;
            CLPlacemark *placemark = placemarks.firstObject;
            if (!error && placemark) {
                NSString *locality = placemark.locality ?: placemark.subLocality;
                NSString *admin = placemark.administrativeArea;
                if (locality.length > 0 && admin.length > 0 && ![locality isEqualToString:admin]) {
                    area = [NSString stringWithFormat:@"%@, %@", locality, admin];
                } else if (locality.length > 0) {
                    area = locality;
                } else if (admin.length > 0) {
                    area = admin;
                }
            }

            if (area.length == 0) {
                area = kLang(@"Select your location") ?: @"Select your location";
            }

            self.settingsSelectedCoordinate = coordinate;
            self.settingsSelectedAreaName = area;
            self.hasSettingsSelectedCoordinate = YES;
            self.settingsLocationState = PPSettingsLocationStateReady;
            [self pp_recordRecentSettingsLocationCoordinate:coordinate title:area source:@"gps"];
            [self pp_persistSettingsLocationIfNeeded];
            [self pp_refreshSettingsLocationRowAnimated:YES];
        });
    }];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if (manager != self.settingsLocationManager) {
        return;
    }
    NSLog(@"[SettingsLocation] location failed: %@", error.localizedDescription ?: @"Unknown error");
    if (!self.hasSettingsSelectedCoordinate) {
        self.settingsLocationState = PPSettingsLocationStateDenied;
        [self pp_refreshSettingsLocationRowAnimated:YES];
    }
}


#pragma mark - SwiftyMax V6 Cell Builders

- (void)pp_v6GroupPositionForIndexPath:(NSIndexPath *)indexPath first:(BOOL *)first last:(BOOL *)last
{
    NSInteger count = (indexPath.section < (NSInteger)self.sections.count)
        ? (NSInteger)self.sections[indexPath.section].rows.count : 0;
    if (first) *first = (indexPath.row == 0);
    if (last) *last = (indexPath.row == count - 1);
}

- (UIImageView *)pp_v6ChevronAccessory
{
    UIImageView *chevron = [[UIImageView alloc] initWithFrame:CGRectZero];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
    NSString *chevronName = Language.isRTL ? @"chevron.backward" : @"chevron.forward";
    chevron.image = [[UIImage systemImageNamed:chevronName withConfiguration:config]
                     imageWithTintColor:(AppTertiaryTextClr ?: UIColor.tertiaryLabelColor)
                     renderingMode:UIImageRenderingModeAlwaysOriginal];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    return chevron;
}

- (UITableViewCell *)pp_v6HeroCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    PPSettingsV6HeroCell *cell = [tableView dequeueReusableCellWithIdentifier:kHeroCellID];
    if (![cell isKindOfClass:PPSettingsV6HeroCell.class]) {
        cell = [[PPSettingsV6HeroCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kHeroCellID];
    }
    [cell configureWithRow:row];
    return cell;
}

- (UITableViewCell *)pp_v6LocationCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    PPSettingsV6LocationCell *cell = [tableView dequeueReusableCellWithIdentifier:kLocationCellID];
    if (![cell isKindOfClass:PPSettingsV6LocationCell.class]) {
        cell = [[PPSettingsV6LocationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kLocationCellID];
    }
    __weak typeof(self) weakSelf = self;
    cell.onActivate = ^{ [weakSelf pp_presentSettingsLocationOptions]; };
    [cell configureWithTitle:[self pp_settingsLocationTitleText]
                      action:[self pp_settingsLocationActionTitle]
                 statusColor:[self pp_settingsLocationStatusColor]
                     loading:[self pp_settingsLocationShowsLoading]
           accessibilityHint:[self pp_settingsLocationAccessibilityHint]
                    animated:NO];
    return cell;
}

- (UITableViewCell *)pp_v6StandardCellForRow:(PPSettingsRowModel *)row
                                   tableView:(UITableView *)tableView
                                   indexPath:(NSIndexPath *)indexPath
{
    PPSettingsV6RowCell *cell = [tableView dequeueReusableCellWithIdentifier:kSettingsCellID];
    if (![cell isKindOfClass:PPSettingsV6RowCell.class]) {
        cell = [[PPSettingsV6RowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kSettingsCellID];
    }

    BOOL first = NO, last = NO;
    [self pp_v6GroupPositionForIndexPath:indexPath first:&first last:&last];
    UIView *accessory = nil;

    if (row.type == PPSettingsRowTypeToggle) {
        UISwitch *toggle = [UISwitch new];
        toggle.on = row.toggleValue;
        toggle.onTintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
        toggle.enabled = row.toggleEnabled;
        toggle.userInteractionEnabled = row.toggleEnabled;
        toggle.tag = indexPath.section * 100 + indexPath.row;
        [toggle addTarget:self action:@selector(pp_switchToggled:) forControlEvents:UIControlEventValueChanged];
        accessory = toggle;
    } else if (row.type == PPSettingsRowTypeNavigation) {
        accessory = row.enabled ? [self pp_v6ChevronAccessory] : nil;
    }

    [cell configureWithRow:row first:first last:last accessory:accessory];
    return cell;
}

- (UITableViewCell *)pp_v6ChoiceCellForRow:(PPSettingsRowModel *)row
                                 tableView:(UITableView *)tableView
                                 indexPath:(NSIndexPath *)indexPath
{
    NSString *reuse = row.type == PPSettingsRowTypeThemePicker ? kThemeCellID : kLanguageCellID;
    PPSettingsV6ChoiceCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (![cell isKindOfClass:PPSettingsV6ChoiceCell.class]) {
        cell = [[PPSettingsV6ChoiceCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
    }

    BOOL first = NO, last = NO;
    [self pp_v6GroupPositionForIndexPath:indexPath first:&first last:&last];

    if (row.type == PPSettingsRowTypeThemePicker) {
        NSArray *titles = @[
            kLang(@"LightMode") ?: @"Light",
            kLang(@"DarkMode") ?: @"Dark",
            kLang(@"SystemMode") ?: @"System"
        ];
        NSArray *icons = @[
            @"sun.max.fill",
            @"moon.fill",
            @"circle.lefthalf.filled"
        ];
        [cell configureTitle:row.title
                        icon:(row.iconName ?: @"circle.lefthalf.filled")
                      titles:titles
                       icons:icons
               selectedIndex:row.themeIndex
                       first:first
                        last:last
                    onChoice:^(NSInteger index) {
            if (row.onThemeTap) row.onThemeTap(index);
        }];
    } else if (row.type == PPSettingsRowTypeLanguage) {
        [cell configureTitle:row.title
                        icon:(row.iconName ?: @"globe")
                      titles:@[@"العربية", @"English"]
                       icons:@[@"globe.central.south.asia.fill", @"globe.americas.fill"]
               selectedIndex:row.languageIndex
                       first:first
                        last:last
                    onChoice:^(NSInteger index) {
            if (row.onLanguageTap) row.onLanguageTap(index);
        }];
    } else {
        [cell configureTitle:row.title
                        icon:(row.iconName ?: @"slider.horizontal.3")
                      titles:(row.segmentTitles ?: @[])
                       icons:nil
               selectedIndex:row.segmentIndex
                       first:first
                        last:last
                    onChoice:^(NSInteger index) {
            if (row.onSegmentChange) row.onSegmentChange(index);
        }];
    }
    return cell;
}

- (UITableViewCell *)pp_v6VersionCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kVersionCellID];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kVersionCellID];
    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = row.title;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption2]
                           scaledFontForFont:([GM fontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11])];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.textColor = AppTertiaryTextClr ?: UIColor.tertiaryLabelColor;
    return cell;
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
        case PPSettingsRowTypeHero:
            return [self pp_v6HeroCellForRow:row tableView:tableView];
        case PPSettingsRowTypeLocation:
            return [self pp_v6LocationCellForRow:row tableView:tableView];
        case PPSettingsRowTypeVersion:
            return [self pp_v6VersionCellForRow:row tableView:tableView];
        case PPSettingsRowTypeThemePicker:
        case PPSettingsRowTypeLanguage:
        case PPSettingsRowTypeSegment:
            return [self pp_v6ChoiceCellForRow:row tableView:tableView indexPath:indexPath];
        case PPSettingsRowTypeToggle:
        case PPSettingsRowTypeNavigation:
        case PPSettingsRowTypeDestructive:
            return [self pp_v6StandardCellForRow:row tableView:tableView indexPath:indexPath];
    }
    return [self pp_v6StandardCellForRow:row tableView:tableView indexPath:indexPath];
}

#pragma mark - Cell Builders

- (UITableViewCell *)pp_heroCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    PPSettingsHeroCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kHeroCellID];
    if (![cell isKindOfClass:PPSettingsHeroCell.class]) {
        cell = [[PPSettingsHeroCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:kHeroCellID];
    }
    [cell configureWithRow:row];
    return cell;
}

- (UITableViewCell *)pp_locationCellForRow:(PPSettingsRowModel *)row tableView:(UITableView *)tableView
{
    PPSettingsLocationCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kLocationCellID];
    if (![cell isKindOfClass:PPSettingsLocationCell.class]) {
        cell = [[PPSettingsLocationCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:kLocationCellID];
    }

    __weak typeof(self) weakSelf = self;
    cell.onActivate = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_presentSettingsLocationOptions];
    };
    [cell configureWithTitle:[self pp_settingsLocationTitleText]
                 statusColor:[self pp_settingsLocationStatusColor]
                     loading:[self pp_settingsLocationShowsLoading]
           accessibilityHint:[self pp_settingsLocationAccessibilityHint]
                    animated:NO];
    
    // Set the leading icon
    cell.leadingIconView.image = [self pp_circularIconImageForName:@"location.fill" tint:AppPrimaryClr background:[UIColor systemBackgroundColor]];
    
    return cell;
}

- (UITableViewCell *)pp_toggleCellForRow:(PPSettingsRowModel *)row
                               tableView:(UITableView *)tableView
                               indexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kSettingsCellID];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [GM MidFontWithSize:15];
    cell.textLabel.textColor = row.enabled ? AppPrimaryTextClr : AppSecondaryTextClr;
    cell.textLabel.enabled = row.enabled;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = AppForgroundColr;
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.font = [GM fontWithSize:12];
    cell.detailTextLabel.textColor = AppSecondaryTextClr;
    cell.detailTextLabel.enabled = row.enabled;
    cell.detailTextLabel.numberOfLines = 2;
    cell.imageView.image = [self pp_iconImageForName:row.iconName tint:row.iconTint background:row.iconBackground];
    cell.imageView.alpha = row.enabled ? 1.0 : 0.45;

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = row.toggleValue;
    toggle.onTintColor = AppPrimaryClr;
    toggle.enabled = row.toggleEnabled;
    toggle.userInteractionEnabled = row.toggleEnabled;
    toggle.alpha = row.toggleEnabled ? 1.0 : 0.65;
    toggle.tag = indexPath.section * 100 + indexPath.row;
    [toggle addTarget:self action:@selector(pp_switchToggled:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    cell.contentView.alpha = row.enabled ? 1.0 : 0.72;
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

    UIView *container = [UIView new];
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                  scaledFontForFont:([GM boldFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold])];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    label.textAlignment = [Language alignmentForCurrentLanguage];
    label.numberOfLines = 0;
    [container addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:PPScreenMargin + PPSpaceXS],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-(PPScreenMargin + PPSpaceXS)],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:PPSpaceLG],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-PPSpaceSM]
    ]];
    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) return CGFLOAT_MIN;
    return self.sections[section].headerTitle.length > 0 ? UITableViewAutomaticDimension : CGFLOAT_MIN;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) return nil;
    NSString *title = self.sections[section].footerTitle;
    if (title.length == 0) return nil;

    UIView *container = [UIView new];
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                  scaledFontForFont:([GM fontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13])];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    label.textAlignment = [Language alignmentForCurrentLanguage];
    label.numberOfLines = 0;
    [container addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:PPScreenMargin + PPSpaceXS],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-(PPScreenMargin + PPSpaceXS)],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:PPSpaceSM],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-PPSpaceMD]
    ]];
    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) return CGFLOAT_MIN;
    return self.sections[section].footerTitle.length > 0 ? UITableViewAutomaticDimension : CGFLOAT_MIN;
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
        cell.textLabel.textColor = row.enabled ? AppPrimaryTextClr : AppSecondaryTextClr;
        cell.accessoryType = row.enabled ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }
    cell.textLabel.enabled = row.enabled;
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.font = [GM fontWithSize:13];
    cell.detailTextLabel.textColor = AppSecondaryTextClr;
    cell.detailTextLabel.enabled = row.enabled;
    cell.imageView.image = [self pp_iconImageForName:row.iconName tint:row.iconTint background:row.iconBackground];
    cell.imageView.alpha = row.enabled ? 1.0 : 0.45;
    cell.contentView.alpha = row.enabled ? 1.0 : 0.72;
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
    return [self pp_iconImageForName:name tint:tint background:background isCircle:NO];
}

- (UIImage *)pp_circularIconImageForName:(NSString *)name tint:(UIColor *)tint background:(UIColor *)background
{
    return [self pp_iconImageForName:name tint:tint background:background isCircle:YES];
}

- (UIImage *)pp_iconImageForName:(NSString *)name tint:(UIColor *)tint background:(UIColor *)background isCircle:(BOOL)isCircle
{
    CGFloat size = 30.0;
    CGFloat cornerRadius = isCircle ? (size / 2.0) : 7.0;
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

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section >= (NSInteger)self.sections.count ||
        indexPath.row >= (NSInteger)self.sections[indexPath.section].rows.count) return;

    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.type == PPSettingsRowTypeHero &&
        [cell isKindOfClass:PPSettingsV6HeroCell.class] &&
        !self.didAnimateSettingsHeroCell) {
        self.didAnimateSettingsHeroCell = YES;
        [(PPSettingsV6HeroCell *)cell runEntranceIfNeeded];
    } else if (row.type == PPSettingsRowTypeLocation &&
               [cell isKindOfClass:PPSettingsV6LocationCell.class]) {
        [(PPSettingsV6LocationCell *)cell runEntranceIfNeeded];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section >= (NSInteger)self.sections.count ||
        indexPath.row >= (NSInteger)self.sections[indexPath.section].rows.count) {
        return;
    }
    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    if (!row.enabled) {
        NSString *hint = row.disabledHint ?: self.sections[indexPath.section].footerTitle;
        if (hint.length > 0) {
            [PPHUD showInfo:hint];
        }
        return;
    }
    if (row.onTap) { row.onTap(); }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.type == PPSettingsRowTypeHero) return 166.0;
    if (row.type == PPSettingsRowTypeLocation) return 56.0;
    if (row.type == PPSettingsRowTypeThemePicker) return 96.0;
    if (row.type == PPSettingsRowTypeLanguage) return 60.0;
    return 56.0;
}

#pragma mark - Control Actions

- (void)pp_switchToggled:(UISwitch *)sender
{
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    if (section < (NSInteger)self.sections.count &&
        row < (NSInteger)self.sections[section].rows.count) {
        PPSettingsRowModel *model = self.sections[section].rows[row];
        if (!model.enabled || !model.toggleEnabled) {
            sender.on = model.toggleValue;
            NSString *hint = model.disabledHint ?: self.sections[section].footerTitle;
            if (hint.length > 0) {
                [PPHUD showInfo:hint];
            }
            return;
        }
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
    // Mark that the user made an explicit choice so the system-default migration
    // in loadUserInterfaceStyle never overwrites a deliberate Light selection.
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PPThemeUserChoseExplicitly"];
    [[PPThemeManager sharedManager] applyInterfaceStyleGlobally:style];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PPThemePreferenceDidChangeNotification object:nil];
    });
    
    [self pp_buildSections];
    [self.tableView reloadData];
    [PPHUD showSuccess:[self pp_themeFeedbackMessageForIndex:index]];
}

- (NSString *)pp_themeFeedbackMessageForIndex:(NSInteger)index
{
    if (index == 0) {
        return PPSettingsLocalizedString(@"settings_theme_light_active", @"Light mode active");
    }
    if (index == 1) {
        return PPSettingsLocalizedString(@"settings_theme_dark_active", @"Dark mode active");
    }
    return PPSettingsLocalizedString(@"settings_theme_system_active", @"System appearance active");
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

    BOOL isCurrentlyArabic = (Language.isRTL || [Language languageVal] == 0);
    __weak typeof(self) weakSelf = self;

    PPSettingsActionModalOption *arabicOpt = [PPSettingsActionModalOption new];
    arabicOpt.title = @"العربية (RTL)";
    arabicOpt.subtitle = PPSettingsLocalizedString(@"settings_lang_ar_desc", @"تطبيق الواجهة العربية وتخطيط الاتجاه من اليمين لليسار");
    arabicOpt.iconName = @"globe.central.south.asia.fill";
    arabicOpt.iconTint = AppPrimaryClr ?: UIColor.systemPinkColor;
    arabicOpt.isSelected = isCurrentlyArabic;
    arabicOpt.actionBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.alertAppear = NO;
        if (!isCurrentlyArabic) {
            [Language userSelectedLanguage:@"ar"];
        }
    };

    PPSettingsActionModalOption *englishOpt = [PPSettingsActionModalOption new];
    englishOpt.title = @"English (LTR)";
    englishOpt.subtitle = PPSettingsLocalizedString(@"settings_lang_en_desc", @"Apply English interface with Left-to-Right layout direction");
    englishOpt.iconName = @"globe.americas.fill";
    englishOpt.iconTint = AppPrimaryClr ?: UIColor.systemPinkColor;
    englishOpt.isSelected = !isCurrentlyArabic;
    englishOpt.actionBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.alertAppear = NO;
        if (isCurrentlyArabic) {
            [Language userSelectedLanguage:@"en"];
        }
    };

    [PPSettingsActionModalVC presentIn:(viewController ?: self)
                                title:kLang(@"Language Setup") ?: @"Language Setup"
                             subtitle:PPSettingsLocalizedString(@"settings_language_switch_subtitle", @"Changing language updates all app interfaces and layout direction.")
                             iconName:@"globe"
                             iconTint:AppPrimaryClr ?: UIColor.systemPinkColor
                              options:@[arabicOpt, englishOpt]];
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
        BOOL prefEnabled = [weakSelf pp_boolPreferenceForKey:kSettingsNotificationsKey defaultValue:YES];
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
    if (!PPIsUserLoggedIn) {
        [self pp_buildSections];
        [self.tableView reloadData];
        [PPHUD showInfo:PPSettingsLocalizedString(@"settings_privacy_login_required_toast",
                                                  @"Sign in to manage these privacy settings.")];
        return;
    }
    if (isOn) { [self pp_requestNotificationAuthorization]; return; }
    [self.prefs setBool:NO forKey:kSettingsNotificationsKey];
    [PPHUD showSuccess:PPSettingsLocalizedString(@"settings_chat_notifications_disabled",
                                                 @"Chat alerts disabled")];
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
            if (error) {
                [strongSelf.prefs setBool:NO forKey:kSettingsNotificationsKey];
                [PPHUD showError:PPSettingsLocalizedString(@"settings_notifications_permission_denied",
                                                          @"Notifications are not available right now.")];
            } else if (granted) {
                [strongSelf.prefs setBool:YES forKey:kSettingsNotificationsKey];
                [UIApplication.sharedApplication registerForRemoteNotifications];
                [PPHUD showSuccess:PPSettingsLocalizedString(@"settings_chat_notifications_enabled",
                                                             @"Chat alerts enabled")];
            } else {
                [strongSelf.prefs setBool:NO forKey:kSettingsNotificationsKey];
                [PPHUD showError:PPSettingsLocalizedString(@"settings_notifications_permission_denied",
                                                          @"Notifications permission denied")];
            }
            [strongSelf pp_buildSections];
            [strongSelf.tableView reloadData];
        });
    }];
}

#pragma mark - Marketplace Appearance

- (void)pp_presentMarketplaceAccentOptions
{
    BOOL usesMainKindColors = [self.prefs boolForKey:PPMarketplaceUsesMainKindAccentColorsPreferenceKey];
    __weak typeof(self) weakSelf = self;

    PPSettingsActionModalOption *mainKindOpt = [PPSettingsActionModalOption new];
    mainKindOpt.title = PPSettingsLocalizedString(@"settings_marketplace_accent_main_kind", @"Pet category colors");
    mainKindOpt.subtitle = PPSettingsLocalizedString(@"settings_marketplace_accent_main_kind_desc", @"Dynamic color highlights for dogs, cats, birds, and small pets");
    mainKindOpt.iconName = @"paintpalette.fill";
    mainKindOpt.iconTint = UIColor.systemBlueColor;
    mainKindOpt.swatches = @[
        [UIColor systemBlueColor],
        [UIColor systemOrangeColor],
        [UIColor systemGreenColor],
        [UIColor systemPurpleColor]
    ];
    mainKindOpt.isSelected = usesMainKindColors;
    mainKindOpt.actionBlock = ^{
        [weakSelf pp_applyMarketplaceUsesMainKindColors:YES];
    };

    PPSettingsActionModalOption *brandOpt = [PPSettingsActionModalOption new];
    brandOpt.title = PPSettingsLocalizedString(@"settings_marketplace_accent_brand", @"Pure Pets brand color");
    brandOpt.subtitle = PPSettingsLocalizedString(@"settings_marketplace_accent_brand_desc", @"Signature Pure Pets luxury brand accent across the marketplace");
    brandOpt.iconName = @"app.badge.fill";
    brandOpt.iconTint = AppPrimaryClr ?: UIColor.systemPinkColor;
    brandOpt.swatches = @[
        AppPrimaryClr ?: UIColor.systemPinkColor
    ];
    brandOpt.isSelected = !usesMainKindColors;
    brandOpt.actionBlock = ^{
        [weakSelf pp_applyMarketplaceUsesMainKindColors:NO];
    };

    [PPSettingsActionModalVC presentIn:self
                                title:PPSettingsLocalizedString(@"settings_marketplace_accent_title", @"Marketplace accent color")
                             subtitle:PPSettingsLocalizedString(@"settings_marketplace_accent_subtitle", @"Choose how category accents and highlights appear across the marketplace.")
                             iconName:@"paintpalette.fill"
                             iconTint:AppPrimaryClr ?: UIColor.systemPinkColor
                              options:@[mainKindOpt, brandOpt]];
}

- (void)pp_applyMarketplaceUsesMainKindColors:(BOOL)usesMainKindColors
{
    BOOL currentValue =
        [self.prefs boolForKey:PPMarketplaceUsesMainKindAccentColorsPreferenceKey];
    if (currentValue == usesMainKindColors) {
        return;
    }

    [self.prefs setBool:usesMainKindColors
                 forKey:PPMarketplaceUsesMainKindAccentColorsPreferenceKey];
    [NSNotificationCenter.defaultCenter
        postNotificationName:PPMarketplaceAccentColorPreferenceDidChangeNotification
                      object:nil];
    [self pp_emitSettingsSelectionHaptic];
    [self pp_buildSections];
    [self.tableView reloadData];

    NSString *activeTitle = usesMainKindColors
        ? PPSettingsLocalizedString(@"settings_marketplace_accent_main_kind",
                                    @"Pet category colors")
        : PPSettingsLocalizedString(@"settings_marketplace_accent_brand",
                                    @"Pure Pets brand color");
    NSString *feedbackFormat =
        PPSettingsLocalizedString(@"settings_marketplace_accent_updated_format",
                                  @"Marketplace accents now use %@.");
    [PPHUD showSuccess:[NSString stringWithFormat:feedbackFormat, activeTitle]];
}

#pragma mark - Messages Privacy

- (void)pp_showMessagesPrivacyPicker
{
    if (!PPIsUserLoggedIn) {
        [PPHUD showInfo:PPSettingsLocalizedString(@"settings_privacy_login_required_toast",
                                                  @"Sign in to manage these privacy settings.")];
        return;
    }

    NSInteger savedPrivacy = [self.prefs integerForKey:kSettingsMessagesPrivacyKey];
    __weak typeof(self) weakSelf = self;

    PPSettingsActionModalOption *everyoneOpt = [PPSettingsActionModalOption new];
    everyoneOpt.title = kLang(@"everyone") ?: @"Everyone";
    everyoneOpt.subtitle = PPSettingsLocalizedString(@"settings_messages_everyone_desc", @"Allow all verified buyers, sellers, and vets to start a chat with you");
    everyoneOpt.iconName = @"person.2.fill";
    everyoneOpt.iconTint = AppPrimaryClr ?: UIColor.systemPinkColor;
    everyoneOpt.isSelected = (savedPrivacy == 0);
    everyoneOpt.actionBlock = ^{
        [weakSelf.prefs setInteger:0 forKey:kSettingsMessagesPrivacyKey];
        [weakSelf pp_buildSections];
        [weakSelf.tableView reloadData];
        [PPHUD showSuccess:PPSettingsLocalizedString(@"settings_messages_everyone_success",
                                                     @"Conversations from everyone enabled")];
    };

    PPSettingsActionModalOption *noOneOpt = [PPSettingsActionModalOption new];
    noOneOpt.title = kLang(@"noOne") ?: @"No one";
    noOneOpt.subtitle = PPSettingsLocalizedString(@"settings_messages_no_one_desc", @"Disable incoming new chat requests from other members");
    noOneOpt.iconName = @"lock.shield.fill";
    noOneOpt.iconTint = UIColor.systemRedColor;
    noOneOpt.isSelected = (savedPrivacy == 1);
    noOneOpt.actionBlock = ^{
        [weakSelf.prefs setInteger:1 forKey:kSettingsMessagesPrivacyKey];
        [weakSelf pp_buildSections];
        [weakSelf.tableView reloadData];
        [PPHUD showSuccess:PPSettingsLocalizedString(@"settings_messages_no_one_success",
                                                     @"Conversations disabled")];
    };

    [PPSettingsActionModalVC presentIn:self
                                title:kLang(@"kmessagesSetPalce") ?: @"Messages Privacy"
                             subtitle:PPSettingsLocalizedString(@"settings_messages_privacy_subtitle", @"Control who can initiate direct conversations with you.")
                             iconName:@"message.fill"
                             iconTint:AppPrimaryClr ?: UIColor.systemPinkColor
                              options:@[everyoneOpt, noOneOpt]];
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
    NSString *cacheSize = [self pp_formattedCacheSize];

    PPSettingsActionModalOption *clearOpt = [PPSettingsActionModalOption new];
    clearOpt.title = kLang(@"ClearCache") ?: @"Clear Cache";
    clearOpt.subtitle = [NSString stringWithFormat:@"%@ (%@)", kLang(@"ClearCacheMessage") ?: @"Free up device storage", cacheSize];
    clearOpt.iconName = @"trash.fill";
    clearOpt.iconTint = AppPrimaryClr ?: UIColor.systemPinkColor;
    clearOpt.actionBlock = ^{
        [[SDImageCache sharedImageCache] clearMemory];
        [[SDImageCache sharedImageCache] clearDiskOnCompletion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf pp_buildSections];
                [weakSelf.tableView reloadData];
                [PPHUD showSuccess:(kLang(@"CacheCleared") ?: @"Cache cleared")];
            });
        }];
    };

    [PPSettingsActionModalVC presentIn:self
                                title:kLang(@"ClearCache") ?: @"Clear Cache"
                             subtitle:[NSString stringWithFormat:@"%@: %@", PPSettingsLocalizedString(@"current_cache_size", @"Current Cache Size"), cacheSize]
                             iconName:@"internaldrive.fill"
                             iconTint:AppPrimaryClr ?: UIColor.systemPinkColor
                              options:@[clearOpt]];
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
    __weak typeof(self) weakSelf = self;
    PPSettingsActionModalOption *deleteOpt = [PPSettingsActionModalOption new];
    deleteOpt.title = PPSettingsLocalizedString(@"delete_account", @"Delete Account");
    deleteOpt.subtitle = PPSettingsLocalizedString(@"settings_delete_confirm_desc", @"Permanently delete your account, listings, and messages. This action cannot be undone.");
    deleteOpt.iconName = @"trash.fill";
    deleteOpt.iconTint = UIColor.systemRedColor;
    deleteOpt.isDestructive = YES;
    deleteOpt.actionBlock = ^{
        [weakSelf pp_executeAccountDeletion];
    };

    [PPSettingsActionModalVC presentIn:self
                                title:PPSettingsLocalizedString(@"delete_account", @"Delete Account")
                             subtitle:PPSettingsLocalizedString(@"delete_account_warning", @"This will permanently delete your account and remove access to your Pure Pets data.")
                             iconName:@"exclamationmark.triangle.fill"
                             iconTint:UIColor.systemRedColor
                              options:@[deleteOpt]];
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

    [self pp_executeAccountDeletionForcingSessionRefresh:NO didRetryAuth:NO];
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

        FIRUser *authUser = [FIRAuth auth].currentUser;
        if (!authUser) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                [strongSelf pp_presentAccountDeletionFailureForError:[NSError errorWithDomain:FIRAuthErrorDomain code:FIRAuthErrorCodeRequiresRecentLogin userInfo:nil]];
            });
            return;
        }
        
        NSDate *lastSignIn = authUser.metadata.lastSignInDate;
        BOOL needsRecentLogin = YES;
        if (lastSignIn) {
            needsRecentLogin = fabs([lastSignIn timeIntervalSinceNow]) > 300.0;
        }
        
        if (needsRecentLogin) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                [strongSelf pp_presentAccountDeletionFailureForError:[NSError errorWithDomain:FIRAuthErrorDomain code:FIRAuthErrorCodeRequiresRecentLogin userInfo:nil]];
            });
            return;
        }

        NSString *uid = authUser.uid;
        [[UserManager sharedManager] deleteUserDocumentForUID:uid completion:^(NSError * _Nullable docErr) {
            // Proceed to delete auth user even if doc deletion fails, to ensure account removal
            [[UserManager sharedManager] deleteCurrentUserAccountWithCompletion:^(NSError * _Nullable error) {
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
                    [strongSelf pp_finishLocalLogoutAndReloadUI];
                });
            }];
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
    PPSettingsActionModalOption *logoutOpt = [PPSettingsActionModalOption new];
    logoutOpt.title = PPSettingsLocalizedString(@"Logout", @"Logout");
    logoutOpt.subtitle = PPSettingsLocalizedString(@"LogoutConfirmSubtitle", @"Sign out from this device. Your saved data remains secure.");
    logoutOpt.iconName = @"rectangle.portrait.and.arrow.right";
    logoutOpt.iconTint = UIColor.systemOrangeColor;
    logoutOpt.isDestructive = YES;
    logoutOpt.actionBlock = ^{
        [weakSelf pp_performLogout];
    };

    [PPSettingsActionModalVC presentIn:self
                                title:PPSettingsLocalizedString(@"Logout", @"Logout")
                             subtitle:PPSettingsLocalizedString(@"LogoutMessage", @"Are you sure you want to log out?")
                             iconName:@"rectangle.portrait.and.arrow.right"
                             iconTint:UIColor.systemOrangeColor
                              options:@[logoutOpt]];
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
