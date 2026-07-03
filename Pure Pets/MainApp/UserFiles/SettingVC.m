//
//  SettingVC.m
//  Pure Pets

#import "SettingVC.h"
#import "PPRootTabBarController.h"
#import "PPFirebaseSessionBridge.h"
#import "LocationPickerViewController.h"
#import "PPHomeLocationSheetViewController.h"
#import "PPHomeLocationTitleView.h"
#import <CoreLocation/CoreLocation.h>
#import <SafariServices/SFSafariViewController.h>
@import FirebaseFunctions;
@import UserNotifications;




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
@end

@implementation SettingVC

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.prefs = [NSUserDefaults standardUserDefaults];
    self.alertAppear = NO;
    self.view.backgroundColor = AppBackgroundClr;
    self.navigationItem.title = kLang(@"Setting");

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
    [self pp_configureSettingsLocationStateMachine];
    [self pp_buildSections];
    [self.tableView reloadData];
    [self pp_refreshNotificationStatusAsync];
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
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 56, 0, 0);
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64.0;

    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kSettingsCellID];
    [self.tableView registerClass:PPSettingsHeroCell.class forCellReuseIdentifier:kHeroCellID];
    [self.tableView registerClass:PPSettingsLocationCell.class forCellReuseIdentifier:kLocationCellID];
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

    // Section: Settings Hero
    PPSettingsSectionModel *heroSection = [PPSettingsSectionModel new];
    PPSettingsRowModel *heroRow = [PPSettingsRowModel new];
    heroRow.type = PPSettingsRowTypeHero;
    heroRow.title = PPSettingsLocalizedString(@"settings_hero_title", @"Tune Pure Pets");
    heroRow.subtitle =
        PPSettingsLocalizedString(@"settings_hero_subtitle",
                                  @"Control appearance, language, privacy, notifications, legal access, and account safety from one calm place.");
    heroSection.rows = @[heroRow];
    [allSections addObject:heroSection];

    // Section: Home Location
    PPSettingsSectionModel *locationSection = [PPSettingsSectionModel new];
    PPSettingsRowModel *locationRow = [PPSettingsRowModel new];
    locationRow.type = PPSettingsRowTypeLocation;
    locationRow.title = [self pp_settingsLocationTitleText];
    locationRow.subtitle = [self pp_settingsLocationActionTitle] ?: @"";
    locationRow.onTap = ^{ [weakSelf pp_presentSettingsLocationOptions]; };
    locationSection.rows = @[locationRow];
    [allSections addObject:locationSection];

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
    BOOL privacyControlsEnabled = PPIsUserLoggedIn;
    NSString *privacyLoginHint =
        PPSettingsLocalizedString(@"settings_privacy_login_footer",
                                  @"Sign in to manage chat privacy and notification preferences.");
    privacySection.footerTitle = privacyControlsEnabled ? nil : privacyLoginHint;
    NSMutableArray<PPSettingsRowModel *> *privacyRows = [NSMutableArray array];

    PPSettingsRowModel *notiRow = [PPSettingsRowModel new];
    notiRow.type = PPSettingsRowTypeToggle;
    notiRow.title = kLang(@"notificationsSetPalce") ?: @"Notifications";
    notiRow.iconName = @"bell.badge.fill";
    notiRow.iconTint = UIColor.whiteColor;
    notiRow.iconBackground = [UIColor systemRedColor];
    notiRow.enabled = privacyControlsEnabled;
    notiRow.toggleEnabled = privacyControlsEnabled;
    notiRow.disabledHint = privacyLoginHint;
    notiRow.subtitle = nil;
    notiRow.toggleValue = [self pp_boolPreferenceForKey:kSettingsNotificationsKey defaultValue:YES];
    notiRow.onToggle = ^(BOOL isOn) { [weakSelf pp_handleNotificationToggle:isOn]; };
    [privacyRows addObject:notiRow];

    NSInteger savedPrivacy = [self.prefs integerForKey:kSettingsMessagesPrivacyKey];
    PPSettingsRowModel *messagesRow = [PPSettingsRowModel new];
    messagesRow.type = PPSettingsRowTypeNavigation;
    messagesRow.title = kLang(@"kmessagesSetPalce") ?: @"Messages";
    messagesRow.enabled = privacyControlsEnabled;
    messagesRow.disabledHint = privacyLoginHint;
    messagesRow.subtitle = privacyControlsEnabled
        ? ((savedPrivacy == 1) ? (kLang(@"noOne") ?: @"No one") : (kLang(@"everyone") ?: @"Everyone"))
        : nil;
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
        accountSection.headerTitle = kLang(@"Account") ?: @"Account";
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
    if (!indexPath) {
        return;
    }

    PPSettingsLocationCell *cell =
        [self.tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:PPSettingsLocationCell.class]) {
        [cell configureWithTitle:[self pp_settingsLocationTitleText]
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
            return [self pp_heroCellForRow:row tableView:tableView];
        case PPSettingsRowTypeLocation:
            return [self pp_locationCellForRow:row tableView:tableView];
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

    PPSettingsSectionModel *sectionModel = self.sections[section];
    NSString *title = sectionModel.headerTitle;
    
    if (title.length == 0) {
        if (sectionModel.rows.count > 0 && sectionModel.rows.firstObject.type == PPSettingsRowTypeLocation) {
            UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
            spacer.backgroundColor = UIColor.clearColor;
            return spacer;
        }
        return nil;
    }

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
    PPSettingsSectionModel *sectionModel = self.sections[section];
    if (sectionModel.headerTitle.length > 0) return 44.0;
    
    if (sectionModel.rows.count > 0 && sectionModel.rows.firstObject.type == PPSettingsRowTypeLocation) {
        return 20.0;
    }
    return CGFLOAT_MIN;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) return nil;

    NSString *title = self.sections[section].footerTitle;
    if (title.length == 0) return nil;

    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.backgroundColor = UIColor.clearColor;
    container.layoutMargins = UIEdgeInsetsMake(4.0, PPScreenMargin + 2.0, 8.0, PPScreenMargin + 2.0);
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [GM fontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    label.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.72] ?: [UIColor secondaryLabelColor];
    label.textAlignment = [Language alignmentForCurrentLanguage];
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    label.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [container addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.trailingAnchor],
        [label.topAnchor constraintEqualToAnchor:container.layoutMarginsGuide.topAnchor],
        [label.bottomAnchor constraintLessThanOrEqualToAnchor:container.layoutMarginsGuide.bottomAnchor]
    ]];

    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) return CGFLOAT_MIN;
    return self.sections[section].footerTitle.length > 0 ? 64.0 : CGFLOAT_MIN;
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
        indexPath.row >= (NSInteger)self.sections[indexPath.section].rows.count) {
        return;
    }
    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.type != PPSettingsRowTypeHero ||
        ![cell isKindOfClass:PPSettingsHeroCell.class] ||
        self.didAnimateSettingsHeroCell) {
        if (row.type == PPSettingsRowTypeLocation &&
            [cell isKindOfClass:PPSettingsLocationCell.class]) {
            PPSettingsLocationCell *locationCell = (PPSettingsLocationCell *)cell;
            [locationCell.locationTitleView playEntranceIfNeeded];
            [locationCell.locationTitleView startLivingMotion];
        }
        return;
    }

    self.didAnimateSettingsHeroCell = YES;
    PPSettingsHeroCell *heroCell = (PPSettingsHeroCell *)cell;
    [heroCell prepareEntranceState];
    [heroCell runEntranceAnimationWithDelay:0.04];
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
    PPSettingsRowModel *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.type == PPSettingsRowTypeHero) return UITableViewAutomaticDimension;
    if (row.type == PPSettingsRowTypeLocation) return 52;
    if (row.type == PPSettingsRowTypeVersion) return 44.0;
    if (row.type == PPSettingsRowTypeLanguage) return 60.0;
    if (row.type == PPSettingsRowTypeThemePicker) return 96.0;
    return 52.0;
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

#pragma mark - Messages Privacy

- (void)pp_showMessagesPrivacyPicker
{
    if (!PPIsUserLoggedIn) {
        [PPHUD showInfo:PPSettingsLocalizedString(@"settings_privacy_login_required_toast",
                                                  @"Sign in to manage these privacy settings.")];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"kmessagesSetPalce")
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:(kLang(@"everyone") ?: @"Everyone")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *a) {
        [weakSelf.prefs setInteger:0 forKey:kSettingsMessagesPrivacyKey];
        [weakSelf pp_buildSections]; [weakSelf.tableView reloadData];
        [PPHUD showSuccess:PPSettingsLocalizedString(@"settings_messages_everyone_success",
                                                     @"Conversations from everyone enabled")];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:(kLang(@"noOne") ?: @"No one")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *a) {
        [weakSelf.prefs setInteger:1 forKey:kSettingsMessagesPrivacyKey];
        [weakSelf pp_buildSections]; [weakSelf.tableView reloadData];
        [PPHUD showSuccess:PPSettingsLocalizedString(@"settings_messages_no_one_success",
                                                     @"Conversations disabled")];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                        CGRectGetMidY(self.view.bounds),
                                        1.0,
                                        1.0);
        popover.permittedArrowDirections = 0;
    }

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
            [authUser deleteWithCompletion:^(NSError * _Nullable error) {
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
