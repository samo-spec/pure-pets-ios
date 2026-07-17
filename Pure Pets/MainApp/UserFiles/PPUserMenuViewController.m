//
//  PPUserMenuViewController.m
//  Pure Pets
//

#import "PPUserMenuViewController.h"
#import "ProfileVC.h"
#import "SettingVC.h"
#import "PPModernAvatarRenderer.h"
#import "CartViewController.h"
#import "OrderHistoryViewController.h"
#import "PurchasedItemsViewController.h"
#import "CompanyLocationVC.h"
#import "LeaveFeedbackViewController.h"
#import "MainController.h"
#import "PPMarketplaceHeroCardStyle.h"
#import "PPUserSigningManager.h"
#import "Language.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <UserNotifications/UserNotifications.h>
#import "PPHUD.h"
#import "PPBackgroundView.h"

typedef NS_ENUM(NSInteger, PPUserMenuAction) {
    PPUserMenuActionProfile = 0,
    PPUserMenuActionLogin,
    PPUserMenuActionFavorites,
    PPUserMenuActionMyAds,
    PPUserMenuActionCart,
    PPUserMenuActionPurchased,
    PPUserMenuActionOrders,
    PPUserMenuActionProduction,
    PPUserMenuActionSettings,
    PPUserMenuActionSupport,
    PPUserMenuActionLogout,

    // Quick Access Actions
    PPUserMenuActionQuickAccessLightAppearance,
    PPUserMenuActionQuickAccessDarkAppearance,
    PPUserMenuActionQuickAccessSwitchToArabic,
    PPUserMenuActionQuickAccessSwitchToEnglish,
    PPUserMenuActionQuickAccessEnableNotifications,
    PPUserMenuActionQuickAccessEnableLocation
};

static NSString * const PPUserMenuCellIdentifier = @"PPUserMenuCell";
static NSString * const PPUserMenuHeroConstellationOpacityAnimationKey = @"pp.user.menu.hero.constellation.opacity";
static NSString * const PPUserMenuHeroDotPulseAnimationKey = @"pp.user.menu.hero.dot.pulse";

static NSString *PPUserMenuLocalized(NSString *key)
{
    NSString *value = kLang(key);
    if ([value isKindOfClass:NSString.class] &&
        value.length > 0 &&
        ![value isEqualToString:key]) {
        return value;
    }
    return key ?: @"";
}

static UIColor *PPUserMenuColor(UIColor *color, UIColor *fallback)
{
    return color ?: fallback ?: UIColor.systemBackgroundColor;
}

static UIColor *PPUserMenuCanvasColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.08 green:0.08 blue:0.09 alpha:1.0];
            }
            return [UIColor colorWithRed:0.970 green:0.963 blue:0.952 alpha:1.0];
        }];
    }
    return PPUserMenuColor(AppBackgroundClr, UIColor.systemBackgroundColor);
}

static UIColor *PPUserMenuSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.92];
            }
            return [[UIColor whiteColor] colorWithAlphaComponent:0.86];
        }];
    }
    return PPUserMenuColor(AppForgroundColr, UIColor.whiteColor);
}

static UIColor *PPUserMenuBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.08];
            }
            return [UIColor colorWithWhite:0.10 alpha:0.06];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.06];
}

static UIColor *PPUserMenuHeroAccentColor(void)
{
    return PPUserMenuColor(AppPrimaryClr, UIColor.systemTealColor);
}

static BOOL PPUserMenuHeroIsDark(UITraitCollection *traitCollection)
{
    if (@available(iOS 13.0, *)) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static UIColor *PPUserMenuMarketplaceHeroSurfaceBaseColor(UITraitCollection *traitCollection)
{
    UIColor *fallback = [UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        fallback = PPMarketplaceHeroCardResolvedColor(
            [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
                return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor colorWithWhite:0.104 alpha:1.0]
                    : [UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:1.0];
            }],
            traitCollection
        );
    }
    return AppForgroundColr ?: fallback;
}

static UIColor *PPUserMenuMarketplaceHeroSurfaceHighlightColor(UIColor *surfaceBase,
                                                               BOOL darkMode,
                                                               UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(surfaceBase,
                                      UIColor.whiteColor,
                                      darkMode ? 0.08 : 0.20,
                                      traitCollection);
}

static UIColor *PPUserMenuMarketplaceHeroBackgroundAccentColor(UIColor *primaryAccent,
                                                               UIColor *surfaceBase,
                                                               BOOL darkMode,
                                                               UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(primaryAccent,
                                      surfaceBase,
                                      darkMode ? 0.12 : 0.18,
                                      traitCollection);
}

static UIColor *PPUserMenuMarketplaceHeroSurfaceTintColor(UIColor *surfaceBase,
                                                          UIColor *backgroundAccent,
                                                          BOOL darkMode,
                                                          UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(surfaceBase,
                                      backgroundAccent,
                                      darkMode ? 0.095 : 0.038,
                                      traitCollection);
}

static UIColor *PPUserMenuMarketplaceHeroSurfaceTailColor(UIColor *surfaceTint,
                                                          UIColor *backgroundAccent,
                                                          BOOL darkMode,
                                                          UITraitCollection *traitCollection)
{
    return PPMarketplaceHeroCardBlend(surfaceTint,
                                      backgroundAccent,
                                      darkMode ? 0.062 : 0.024,
                                      traitCollection);
}

static UIColor *PPUserMenuMarketplaceHeroStrokeColor(BOOL darkMode)
{
    return [UIColor.whiteColor colorWithAlphaComponent:darkMode ? 0.12 : 0.78];
}

static UIColor *PPUserMenuHeroDotColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.26];
            }
            return [UIColor colorWithRed:0.530 green:0.485 blue:0.390 alpha:0.30];
        }];
    }
    return [UIColor colorWithWhite:0.35 alpha:0.22];
}

static UIColor *PPUserMenuHeroDotHaloColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.10];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.62];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.35];
}

static UIColor *PPUserMenuHeroConstellationLineColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.070];
            }
            return [UIColor colorWithRed:0.540 green:0.495 blue:0.410 alpha:0.105];
        }];
    }
    return [UIColor colorWithWhite:0.35 alpha:0.08];
}

static NSString *PPUserMenuFirstNonEmptyString(NSArray<NSString *> *values)
{
    for (NSString *value in values) {
        if (![value isKindOfClass:NSString.class]) {
            continue;
        }
        NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length > 0) {
            return trimmed;
        }
    }
    return @"";
}

static UIImage *PPUserMenuSymbol(NSString *name, UIColor *color, CGFloat pointSize, UIImageSymbolWeight weight)
{
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                        weight:weight
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *image = [UIImage systemImageNamed:name ?: @"" withConfiguration:configuration];
    UIColor *resolvedColor = PPUserMenuColor(color, UIColor.labelColor);
    return [[image imageWithTintColor:resolvedColor] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

#pragma mark - Models

@interface PPUserMenuItem : NSObject
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSString *subtitleKey;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, assign) PPUserMenuAction action;
@property (nonatomic, assign) BOOL destructive;
@end

@implementation PPUserMenuItem
@end

@interface PPUserMenuSection : NSObject
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, strong) NSArray<PPUserMenuItem *> *items;
@end

@implementation PPUserMenuSection
@end

#pragma mark - Cell

@interface PPUserMenuCell : UITableViewCell
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithItem:(PPUserMenuItem *)item;
@end

@implementation PPUserMenuCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        UIView *surface = [UIView new];
        surface.translatesAutoresizingMaskIntoConstraints = NO;
        surface.backgroundColor = PPUserMenuSurfaceColor();
        surface.layer.borderWidth = 1.0;
        [surface pp_setBorderColor:PPUserMenuBorderColor()];
        PPApplyContinuousCorners(surface, 26.0);
        PPApplyCardShadow(surface);
        surface.layer.shadowOpacity = 0.045;
        [self.contentView addSubview:surface];
        self.surfaceView = surface;

        UIView *iconContainer = [UIView new];
        iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
        iconContainer.layer.cornerRadius = 20.0;
        PPApplyContinuousCorners(iconContainer, 20.0);
        iconContainer.clipsToBounds = YES;
        [surface addSubview:iconContainer];
        self.iconContainerView = iconContainer;

        UIImageView *iconView = [UIImageView new];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        [iconContainer addSubview:iconView];
        self.iconView = iconView;

        UILabel *titleLabel = [UILabel new];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                           scaledFontForFont:([GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold])];
        titleLabel.adjustsFontForContentSizeCategory = YES;
        titleLabel.textColor = PPUserMenuColor(AppPrimaryTextClr, UIColor.labelColor);
        titleLabel.numberOfLines = 1;
        titleLabel.textAlignment = [Language alignmentForCurrentLanguage];

        UILabel *subtitleLabel = [UILabel new];
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                              scaledFontForFont:([GM fontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular])];
        subtitleLabel.adjustsFontForContentSizeCategory = YES;
        subtitleLabel.textColor = PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
        subtitleLabel.numberOfLines = 2;
        subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];

        UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
        textStack.translatesAutoresizingMaskIntoConstraints = NO;
        textStack.axis = UILayoutConstraintAxisVertical;
        textStack.alignment = UIStackViewAlignmentFill;
        textStack.spacing = 3.0;
        [surface addSubview:textStack];
        self.titleLabel = titleLabel;
        self.subtitleLabel = subtitleLabel;

        UIImageView *chevron = [UIImageView new];
        chevron.translatesAutoresizingMaskIntoConstraints = NO;
        chevron.contentMode = UIViewContentModeScaleAspectFit;
        chevron.image = PPUserMenuSymbol(Language.isRTL ? @"chevron.left" : @"chevron.right",
                                         [PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor) colorWithAlphaComponent:0.55],
                                         14.0,
                                         UIImageSymbolWeightSemibold);
        [surface addSubview:chevron];
        self.chevronView = chevron;

        [NSLayoutConstraint activateConstraints:@[
            [surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
            [surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
            [surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
            [surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],

            [iconContainer.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceBase],
            [iconContainer.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
            [iconContainer.widthAnchor constraintEqualToConstant:40.0],
            [iconContainer.heightAnchor constraintEqualToConstant:40.0],

            [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:21.0],
            [iconView.heightAnchor constraintEqualToConstant:21.0],

            [textStack.leadingAnchor constraintEqualToAnchor:iconContainer.trailingAnchor constant:PPSpaceBase],
            [textStack.topAnchor constraintGreaterThanOrEqualToAnchor:surface.topAnchor constant:PPSpaceMD],
            [textStack.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
            [textStack.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-PPSpaceMD],

            [chevron.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceBase],
            [chevron.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
            [chevron.widthAnchor constraintEqualToConstant:12.0],
            [chevron.heightAnchor constraintEqualToConstant:18.0],

            [surface.heightAnchor constraintGreaterThanOrEqualToConstant:72.0]
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.surfaceView.alpha = 1.0;
}

- (void)configureWithItem:(PPUserMenuItem *)item
{
    BOOL destructive = item.destructive;
    UIColor *tint = destructive ? UIColor.systemRedColor : PPUserMenuColor(item.tintColor, AppPrimaryClr);
    self.titleLabel.text = PPUserMenuLocalized(item.titleKey);
    self.subtitleLabel.text = PPUserMenuLocalized(item.subtitleKey);
    self.titleLabel.textColor = destructive ? UIColor.systemRedColor : PPUserMenuColor(AppPrimaryTextClr, UIColor.labelColor);
    self.subtitleLabel.textColor = destructive
        ? [UIColor.systemRedColor colorWithAlphaComponent:0.68]
        : PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    self.iconContainerView.backgroundColor = [tint colorWithAlphaComponent:destructive ? 0.12 : 0.13];
    self.iconView.image = PPUserMenuSymbol(item.iconName, tint, 20.0, UIImageSymbolWeightSemibold);
    self.chevronView.hidden = destructive;
    self.accessibilityLabel = self.titleLabel.text;
    self.accessibilityHint = self.subtitleLabel.text;
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    void (^changes)(void) = ^{
        self.surfaceView.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        self.surfaceView.alpha = highlighted ? 0.86 : 1.0;
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

#pragma mark - Quick Access Cell

static NSString * const PPUserMenuQuickAccessCellIdentifier = @"PPUserMenuQuickAccessCell";

@interface PPUserMenuQuickAccessCell : UITableViewCell
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) NSArray *quickAccessItems;
@property (nonatomic, copy) void (^actionHandler)(PPUserMenuAction action);
- (void)configureWithItems:(NSArray *)items actionHandler:(void (^)(PPUserMenuAction action))actionHandler;
@end

@implementation PPUserMenuQuickAccessCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        UIScrollView *scrollView = [UIScrollView new];
        scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.alwaysBounceHorizontal = NO;
        [self.contentView addSubview:scrollView];
        self.scrollView = scrollView;

        UIStackView *stackView = [[UIStackView alloc] init];
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        stackView.axis = UILayoutConstraintAxisHorizontal;
        stackView.alignment = UIStackViewAlignmentCenter;
        stackView.spacing = 12.0;
        stackView.distribution = UIStackViewDistributionFillEqually;
        [scrollView addSubview:stackView];
        self.stackView = stackView;

        [NSLayoutConstraint activateConstraints:@[
            [scrollView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:60.0],

            [stackView.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:8.0],
            [stackView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:PPScreenMargin],
            [stackView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-PPScreenMargin],
            [stackView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-8.0],
            [stackView.heightAnchor constraintEqualToConstant:52.0],
            [stackView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-(PPScreenMargin * 2)]
        ]];
    }
    return self;
}

- (void)configureWithItems:(NSArray *)items actionHandler:(void (^)(PPUserMenuAction action))actionHandler
{
    self.quickAccessItems = items;
    self.actionHandler = actionHandler;

    // Clear existing views
    for (UIView *view in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    // Add new buttons for each quick access item
    for (PPUserMenuItem *item in items) {
        UIButton *button = [self pp_createQuickAccessButtonWithItem:item];
        [self.stackView addArrangedSubview:button];
    }
}

- (UIButton *)pp_createQuickAccessButtonWithItem:(PPUserMenuItem *)item
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // Use the existing PPUserMenuCell styling as inspiration
    UIView *surface = [UIView new];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.userInteractionEnabled = NO;
    surface.backgroundColor = PPUserMenuSurfaceColor();
    surface.layer.borderWidth =0.75;
    [surface pp_setBorderColor:PPUserMenuBorderColor()];
    PPApplyContinuousCorners(surface, 18.0);
    PPApplyCardShadow(surface);
    surface.layer.shadowOpacity = 0.025;
    [button addSubview:surface];

    UIImageView *iconView = [UIImageView new];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    UIColor *tint = PPUserMenuColor(item.tintColor, AppPrimaryClr);
    iconView.image = PPUserMenuSymbol(item.iconName, tint, 18.0, UIImageSymbolWeightSemibold);
    [surface addSubview:iconView];

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                       scaledFontForFont:([GM boldFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold])];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.7;
    titleLabel.textColor = PPUserMenuColor(item.tintColor, AppPrimaryClr);
    titleLabel.numberOfLines = 1;
    titleLabel.text = PPUserMenuLocalized(item.titleKey);
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [surface addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [surface.topAnchor constraintEqualToAnchor:button.topAnchor ],
        [surface.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
        [surface.heightAnchor constraintEqualToConstant:52.0],

        [iconView.centerXAnchor constraintEqualToAnchor:surface.centerXAnchor],
        [iconView.topAnchor constraintEqualToAnchor:surface.topAnchor constant:8.0],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:4.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:6.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-6.0],
        [titleLabel.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-6.0]
    ]];

    button.tag = item.action;
    [button addTarget:self action:@selector(pp_buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = titleLabel.text;
    button.accessibilityTraits = UIAccessibilityTraitButton;

    // Add pressed state styling
    [button addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchDragExit];

    return button;
}

- (void)pp_buttonTapped:(UIButton *)sender
{
    if (self.actionHandler) {
        self.actionHandler((PPUserMenuAction)sender.tag);
    }
}

- (void)pp_buttonTouchDown:(UIButton *)sender
{
    UIView *surface = sender.subviews.firstObject;
    if ([surface isKindOfClass:UIView.class]) {
        [UIView animateWithDuration:0.10 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
            surface.transform = CGAffineTransformMakeScale(0.96, 0.96);
            surface.alpha = 0.86;
        } completion:nil];
    }
}

- (void)pp_buttonTouchUp:(UIButton *)sender
{
    UIView *surface = sender.subviews.firstObject;
    if ([surface isKindOfClass:UIView.class]) {
        [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
            surface.transform = CGAffineTransformIdentity;
            surface.alpha = 1.0;
        } completion:nil];
    }
}

@end

#pragma mark - View Controller

@interface PPUserMenuViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPUserMenuSection *> *sections;
@property (nonatomic, strong) UIView *headerRootView;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) PPBackgroundView *headerBackgroundView;
@property (nonatomic, strong) UIView *avatarFrameView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) PPInsetLabel *statusPillLabel;
@property (nonatomic, strong) PPInsetLabel *metaLabel;
@property (nonatomic, strong) UIButton *primaryHeroButton;
@property (nonatomic, assign) BOOL preparedEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;
@property (nonatomic, assign) BOOL didCaptureNavigationBarHiddenState;
@property (nonatomic, assign) BOOL previousNavigationBarHiddenState;
@property (nonatomic, strong) NSLayoutConstraint *cardTopConstraint;
@end

@implementation PPUserMenuViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPUserMenuCanvasColor();
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.navigationItem.title = nil;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:nil showBack:NO];

    [self pp_buildTableView];
    [self pp_buildHeader];
    [self pp_rebuildSections];
    [self pp_refreshHeaderContent];
    [self pp_prepareEntranceState];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_applyMenuNavigationChromeAnimated:animated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_rebuildSections];
    [self pp_refreshHeaderContent];
    [self.tableView reloadData];
    [self pp_updateHeaderLayoutIfNeeded];
    [self pp_startHeroBackgroundMotionIfNeeded];
    if (!self.didRunEntrance) {
        [self pp_prepareEntranceState];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_updateHeaderLayoutIfNeeded];
    [self pp_layoutHeaderMaterialLayers];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_updateHeaderLayoutIfNeeded];
    [self pp_runEntranceIfNeeded];
    [self pp_startHeroBackgroundMotionIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_restoreMenuNavigationChromeIfNeededAnimated:animated];
    [self pp_stopHeroBackgroundMotion];
}

- (void)dealloc
{
    [self pp_stopHeroBackgroundMotion];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    self.view.backgroundColor = PPUserMenuCanvasColor();
    [self pp_stopHeroBackgroundMotion];
    [self pp_applyHeaderMaterialPalette];
    [self pp_startHeroBackgroundMotionIfNeeded];
    [self.tableView reloadData];
}

#pragma mark - Navigation Chrome

- (BOOL)pp_isPresentedAsRootTab
{
    return self.tabBarController != nil &&
           self.navigationController != nil &&
           self.navigationController.viewControllers.firstObject == self;
}

- (void)pp_applyMenuNavigationChromeAnimated:(BOOL)animated
{
    self.navigationItem.title = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItems = nil;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:nil showBack:NO];

    if (![self pp_isPresentedAsRootTab]) {
        return;
    }

    if (!self.didCaptureNavigationBarHiddenState) {
        self.previousNavigationBarHiddenState = self.navigationController.navigationBarHidden;
        self.didCaptureNavigationBarHiddenState = YES;
    }
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)pp_restoreMenuNavigationChromeIfNeededAnimated:(BOOL)animated
{
    if (!self.didCaptureNavigationBarHiddenState || !self.navigationController) {
        return;
    }

    [self.navigationController setNavigationBarHidden:self.previousNavigationBarHiddenState animated:animated];
    self.didCaptureNavigationBarHiddenState = NO;
}

#pragma mark - Setup

- (void)pp_buildTableView
{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.backgroundColor = UIColor.clearColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 82.0;
    tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 104.0, 0.0);
    tableView.scrollIndicatorInsets = tableView.contentInset;
    if (@available(iOS 11.0, *)) {
        tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [tableView registerClass:PPUserMenuCell.class forCellReuseIdentifier:PPUserMenuCellIdentifier];
    [tableView registerClass:PPUserMenuQuickAccessCell.class forCellReuseIdentifier:PPUserMenuQuickAccessCellIdentifier];
    [self.view addSubview:tableView];
    self.tableView = tableView;

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)pp_applyHeaderMaterialPalette
{
    UIColor *brand = PPUserMenuHeroAccentColor();
    self.view.backgroundColor = PPUserMenuCanvasColor();

    [self.headerBackgroundView reapplyPalette];

    self.headerCardView.backgroundColor = UIColor.clearColor;
    [self.headerCardView pp_setBorderColor:UIColor.clearColor];
    [self.headerCardView pp_setShadowColor:UIColor.clearColor];
    self.headerCardView.layer.shadowOpacity = 0.0f;
    self.headerCardView.layer.shadowRadius = 0.0f;
    self.headerCardView.layer.shadowOffset = CGSizeZero;

    UIColor *quietFill = nil;
    UIColor *quietStroke = nil;
    if (@available(iOS 13.0, *)) {
        quietFill = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.060];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.70];
        }];
        quietStroke = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.09];
            }
            return [UIColor colorWithWhite:0.0 alpha:0.060];
        }];
    } else {
        quietFill = [UIColor colorWithWhite:1.0 alpha:0.70];
        quietStroke = [UIColor colorWithWhite:0.0 alpha:0.060];
    }

    self.avatarFrameView.backgroundColor = quietFill;
    [self.avatarFrameView pp_setBorderColor:quietStroke];
    [self.avatarFrameView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    self.avatarFrameView.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.07 : 0.105;
    self.avatarFrameView.layer.shadowRadius = 18.0;
    self.avatarFrameView.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    UIColor *avatarStroke = nil;
    if (@available(iOS 13.0, *)) {
        avatarStroke = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.14];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.82];
        }];
    } else {
        avatarStroke = [UIColor colorWithWhite:1.0 alpha:0.82];
    }
    [self.avatarImageView pp_setBorderColor:avatarStroke];

    self.statusPillLabel.backgroundColor = quietFill;
    self.statusPillLabel.textColor = PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    [self.statusPillLabel pp_setBorderColor:quietStroke];

    if (@available(iOS 13.0, *)) {
        self.metaLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.045];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.52];
        }];
    } else {
        self.metaLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.52];
    }
    self.metaLabel.textColor = PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    [self.metaLabel pp_setBorderColor:quietStroke];

    self.primaryHeroButton.backgroundColor = brand;
    self.primaryHeroButton.tintColor = UIColor.whiteColor;
    [self.primaryHeroButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.primaryHeroButton setTitleColor:[UIColor.whiteColor colorWithAlphaComponent:0.68] forState:UIControlStateHighlighted];
}

- (void)pp_layoutHeaderMaterialLayers
{
    if (self.avatarFrameView && !CGRectIsEmpty(self.avatarFrameView.bounds)) {
        self.avatarFrameView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.avatarFrameView.bounds
                                       cornerRadius:self.avatarFrameView.layer.cornerRadius].CGPath;
    }
}

- (void)pp_startHeroBackgroundMotionIfNeeded
{
    [self.headerBackgroundView startAnimations];
}

- (void)pp_stopHeroBackgroundMotion
{
    [self.headerBackgroundView stopAnimations];
}

- (void)pp_buildHeader
{
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 244.0)];
    root.backgroundColor = UIColor.clearColor;
    root.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.clearColor;
    card.accessibilityIdentifier = @"profile_menu_hero_card";
    [root addSubview:card];
    self.headerCardView = card;

    PPBackgroundView *bg = [PPBackgroundView new];
    bg.translatesAutoresizingMaskIntoConstraints = NO;
    bg.hidden = NO;
    bg.alpha = 1.0;
    [card insertSubview:bg atIndex:0];
    self.headerBackgroundView = bg;

    PPInsetLabel *statusPill = [PPInsetLabel new];
    statusPill.translatesAutoresizingMaskIntoConstraints = NO;
    statusPill.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                       scaledFontForFont:([GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold])];
    statusPill.adjustsFontForContentSizeCategory = YES;
    statusPill.adjustsFontSizeToFitWidth = YES;
    statusPill.minimumScaleFactor = 0.78;
    statusPill.numberOfLines = 1;
    statusPill.textAlignment = NSTextAlignmentCenter;
    statusPill.textInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    statusPill.layer.cornerRadius = 17.0;
    statusPill.layer.borderWidth = 1.0;
    statusPill.clipsToBounds = YES;
    [card addSubview:statusPill];
    self.statusPillLabel = statusPill;

    UIButton *primaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    primaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    primaryButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                                     scaledFontForFont:([GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold])];
    primaryButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    primaryButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    primaryButton.titleLabel.minimumScaleFactor = 0.78;
    primaryButton.contentEdgeInsets = UIEdgeInsetsMake(9.0, 14.0, 9.0, 14.0);
    primaryButton.layer.cornerRadius = 12.0;
    primaryButton.clipsToBounds = YES;
    PPApplyContinuousCorners(primaryButton, 12.0);
    primaryButton.accessibilityIdentifier = @"profile_menu_hero_primary_action";
    [primaryButton addTarget:self action:@selector(pp_handleHeroPrimaryTouchDown:) forControlEvents:UIControlEventTouchDown];
    [primaryButton addTarget:self action:@selector(pp_handleHeroPrimaryTouchUp:) forControlEvents:UIControlEventTouchDragExit | UIControlEventTouchCancel | UIControlEventTouchUpOutside];
    [primaryButton addTarget:self action:@selector(pp_handleHeroPrimaryAction:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:primaryButton];
    self.primaryHeroButton = primaryButton;

    UIView *avatarFrame = [UIView new];
    avatarFrame.translatesAutoresizingMaskIntoConstraints = NO;
    avatarFrame.layer.borderWidth = 1.0;
    avatarFrame.clipsToBounds = NO;
    PPApplyContinuousCorners(avatarFrame, 48.0);
    [card addSubview:avatarFrame];
    self.avatarFrameView = avatarFrame;

    UIImageView *avatar = [UIImageView new];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 41.0;
    avatar.layer.borderWidth = 2.0;
    avatar.isAccessibilityElement = NO;
    [avatarFrame addSubview:avatar];
    self.avatarImageView = avatar;

    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                    scaledFontForFont:([GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold])];
    eyebrow.adjustsFontForContentSizeCategory = YES;
    eyebrow.textColor = PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    eyebrow.numberOfLines = 1;
    eyebrow.adjustsFontSizeToFitWidth = YES;
    eyebrow.minimumScaleFactor = 0.82;
    eyebrow.textAlignment = [Language alignmentForCurrentLanguage];
    [card addSubview:eyebrow];
    self.eyebrowLabel = eyebrow;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2]
                  scaledFontForFont:([GM boldFontWithSize:28.0] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold])];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = PPUserMenuColor(AppPrimaryTextClr, UIColor.labelColor);
    title.numberOfLines = 2;
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.82;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    [card addSubview:title];
    self.titleLabel = title;

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                     scaledFontForFont:([GM fontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular])];
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.textColor = PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    subtitle.numberOfLines = 3;
    subtitle.textAlignment = [Language alignmentForCurrentLanguage];
    [card addSubview:subtitle];
    self.subtitleLabel = subtitle;

    PPInsetLabel *meta = [PPInsetLabel new];
    meta.translatesAutoresizingMaskIntoConstraints = NO;
    meta.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                 scaledFontForFont:([GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium])];
    meta.adjustsFontForContentSizeCategory = YES;
    meta.adjustsFontSizeToFitWidth = YES;
    meta.minimumScaleFactor = 0.78;
    meta.numberOfLines = 1;
    meta.textAlignment = [Language alignmentForCurrentLanguage];
    meta.textInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    meta.layer.cornerRadius = 17.0;
    meta.layer.borderWidth = 1.0;
    meta.clipsToBounds = YES;
    [card addSubview:meta];
    self.metaLabel = meta;

    self.cardTopConstraint = [card.topAnchor constraintEqualToAnchor:root.topAnchor constant:PPStatusBarHeight + 12.0];
    [NSLayoutConstraint activateConstraints:@[
        self.cardTopConstraint,
        [card.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:PPScreenMargin],
        [card.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-PPScreenMargin],
        [card.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-14.0],

        [bg.topAnchor constraintEqualToAnchor:card.topAnchor],
        [bg.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [bg.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [bg.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],

        [statusPill.topAnchor constraintEqualToAnchor:card.topAnchor constant:22.0],
        [statusPill.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [statusPill.trailingAnchor constraintLessThanOrEqualToAnchor:primaryButton.leadingAnchor constant:-12.0],
        [statusPill.heightAnchor constraintGreaterThanOrEqualToConstant:34.0],

        [primaryButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:20.0],
        [primaryButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],
        [primaryButton.widthAnchor constraintGreaterThanOrEqualToConstant:106.0],
        [primaryButton.heightAnchor constraintGreaterThanOrEqualToConstant:38.0],

        [avatarFrame.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [avatarFrame.topAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:22.0],
        [avatarFrame.widthAnchor constraintEqualToConstant:96.0],
        [avatarFrame.heightAnchor constraintEqualToConstant:96.0],

        [avatar.centerXAnchor constraintEqualToAnchor:avatarFrame.centerXAnchor],
        [avatar.centerYAnchor constraintEqualToAnchor:avatarFrame.centerYAnchor],
        [avatar.widthAnchor constraintEqualToConstant:82.0],
        [avatar.heightAnchor constraintEqualToConstant:82.0],

        [eyebrow.leadingAnchor constraintEqualToAnchor:avatarFrame.trailingAnchor constant:18.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24.0],
        [eyebrow.topAnchor constraintEqualToAnchor:avatarFrame.topAnchor constant:1.0],

        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:5.0],

        [subtitle.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:PPSpaceSM],
        [subtitle.bottomAnchor constraintLessThanOrEqualToAnchor:meta.topAnchor constant:-12.0],

        [meta.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [meta.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-24.0],
        [meta.topAnchor constraintGreaterThanOrEqualToAnchor:avatarFrame.bottomAnchor constant:16.0],
        [meta.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-24.0],
        [avatarFrame.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-24.0]
    ]];

    // Keep all identity, status, and action content above the decorative hero material.
    [card sendSubviewToBack:bg];
    [self pp_applyHeaderMaterialPalette];
    self.headerRootView = root;
    self.tableView.tableHeaderView = root;
}

#pragma mark - Content

- (PPUserMenuItem *)pp_itemWithTitleKey:(NSString *)titleKey
                            subtitleKey:(NSString *)subtitleKey
                               iconName:(NSString *)iconName
                              tintColor:(UIColor *)tintColor
                                 action:(PPUserMenuAction)action
                            destructive:(BOOL)destructive
{
    PPUserMenuItem *item = [PPUserMenuItem new];
    item.titleKey = titleKey ?: @"";
    item.subtitleKey = subtitleKey ?: @"";
    item.iconName = iconName ?: @"circle";
    item.tintColor = tintColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    item.action = action;
    item.destructive = destructive;
    return item;
}

- (PPUserMenuSection *)pp_sectionWithTitleKey:(NSString *)titleKey items:(NSArray<PPUserMenuItem *> *)items
{
    PPUserMenuSection *section = [PPUserMenuSection new];
    section.titleKey = titleKey ?: @"";
    section.items = items ?: @[];
    return section;
}

- (NSArray<PPUserMenuItem *> *)pp_buildQuickAccessItems
{
    
    NSMutableArray<PPUserMenuItem *> *items = [NSMutableArray array];

    // Detect current theme
    UIUserInterfaceStyle currentTheme = [[PPThemeManager sharedManager] loadUserInterfaceStyle];
    BOOL isDarkMode = (currentTheme == UIUserInterfaceStyleDark);

    // Detect current language
    NSInteger currentLanguage = [Language languageVal];
    BOOL isArabic = (currentLanguage == 1);

    // Theme quick access
    if (isDarkMode) {
        // Currently dark, suggest light
        [items addObject:[self pp_itemWithTitleKey:@"Light Appearance"
                                          subtitleKey:@""
                                             iconName:@"sun.max.fill"
                                            tintColor:UIColor.systemYellowColor
                                               action:PPUserMenuActionQuickAccessLightAppearance
                                          destructive:NO]];
    } else {
        // Currently light or system, suggest dark
        [items addObject:[self pp_itemWithTitleKey:@"Dark Appearance"
                                          subtitleKey:@""
                                             iconName:@"moon.fill"
                                            tintColor:UIColor.systemIndigoColor
                                               action:PPUserMenuActionQuickAccessDarkAppearance
                                          destructive:NO]];
    }

    // Language quick access
    if (isArabic) {
        // Currently Arabic, suggest English
        [items addObject:[self pp_itemWithTitleKey:@"English"
                                          subtitleKey:@""
                                             iconName:@"globe.central.south.asia"
                                            tintColor:UIColor.systemBlueColor
                                               action:PPUserMenuActionQuickAccessSwitchToEnglish
                                          destructive:NO]];
    } else {
        // Currently English, suggest Arabic
        [items addObject:[self pp_itemWithTitleKey:@"Arabic"
                                          subtitleKey:@""
                                             iconName:@"globe.central.south.asia"
                                            tintColor:UIColor.systemGreenColor
                                               action:PPUserMenuActionQuickAccessSwitchToArabic
                                          destructive:NO]];
    }

    // Notifications quick access
    [items addObject:[self pp_itemWithTitleKey:@"Notifications"
                                      subtitleKey:@""
                                         iconName:@"bell.fill"
                                        tintColor:UIColor.systemRedColor
                                           action:PPUserMenuActionQuickAccessEnableNotifications
                                      destructive:NO]];

    // Location quick access
    [items addObject:[self pp_itemWithTitleKey:@"Location"
                                      subtitleKey:@""
                                         iconName:@"location.fill"
                                        tintColor:UIColor.systemTealColor
                                           action:PPUserMenuActionQuickAccessEnableLocation
                                      destructive:NO]];

    return items.copy;
    
}

- (PPUserMenuSection *)pp_buildQuickAccessSection
{
    NSArray<PPUserMenuItem *> *items = [self pp_buildQuickAccessItems];
    if (items.count == 0) {
        return nil;
    }
    return [self pp_sectionWithTitleKey:@"quick_access_settings_section" items:items];
}

- (void)pp_rebuildSections
{
    NSMutableArray<PPUserMenuSection *> *sections = [NSMutableArray array];
    BOOL loggedIn = PPIsUserLoggedIn && UserManager.sharedManager.currentUser;
    UIColor *brand = PPUserMenuColor(AppPrimaryClr, UIColor.systemTealColor);

    PPUserMenuItem *accountItem = loggedIn
        ? [self pp_itemWithTitleKey:@"showProfile"
                        subtitleKey:@"user_menu_profile_subtitle"
                           iconName:@"person.crop.circle.fill"
                          tintColor:brand
                             action:PPUserMenuActionProfile
                        destructive:NO]
        : [self pp_itemWithTitleKey:@"go_to_login"
                        subtitleKey:@"user_menu_login_subtitle"
                           iconName:@"person.crop.circle.fill.badge.plus"
                          tintColor:brand
                             action:PPUserMenuActionLogin
                        destructive:NO];
    [sections addObject:[self pp_sectionWithTitleKey:@"user_menu_account_section" items:@[accountItem]]];

    // Add Quick Access Settings section
    PPUserMenuSection *quickAccessSection = [self pp_buildQuickAccessSection];
    if (quickAccessSection) {
        [sections addObject:quickAccessSection];
    }

    NSMutableArray<PPUserMenuItem *> *activity = [NSMutableArray array];
    [activity addObject:[self pp_itemWithTitleKey:@"showfav"
                                      subtitleKey:@"user_menu_favorites_subtitle"
                                         iconName:@"star.fill"
                                        tintColor:UIColor.systemYellowColor
                                           action:PPUserMenuActionFavorites
                                      destructive:NO]];
    [activity addObject:[self pp_itemWithTitleKey:@"myadsTitle"
                                      subtitleKey:@"user_menu_ads_subtitle"
                                         iconName:@"circle.hexagonpath.fill"
                                        tintColor:UIColor.systemPurpleColor
                                           action:PPUserMenuActionMyAds
                                      destructive:NO]];
    [activity addObject:[self pp_itemWithTitleKey:@"Cart"
                                      subtitleKey:@"user_menu_cart_subtitle"
                                         iconName:@"cart.fill"
                                        tintColor:UIColor.systemGreenColor
                                           action:PPUserMenuActionCart
                                      destructive:NO]];
    [activity addObject:[self pp_itemWithTitleKey:@"purchased_profile_menu_title"
                                      subtitleKey:@"user_menu_purchased_subtitle"
                                         iconName:@"bag.badge.plus"
                                        tintColor:UIColor.systemBlueColor
                                           action:PPUserMenuActionPurchased
                                      destructive:NO]];
    [activity addObject:[self pp_itemWithTitleKey:@"OrderHistory"
                                      subtitleKey:@"user_menu_orders_subtitle"
                                         iconName:@"bag.fill"
                                        tintColor:UIColor.systemIndigoColor
                                           action:PPUserMenuActionOrders
                                      destructive:NO]];
    if ([[UserManager.sharedManager.currentUser.prodectionStatus lowercaseString] isEqualToString:@"active"]) {
        [activity addObject:[self pp_itemWithTitleKey:@"showProdection"
                                          subtitleKey:@"user_menu_production_subtitle"
                                             iconName:@"doc.on.doc.fill"
                                            tintColor:UIColor.systemOrangeColor
                                               action:PPUserMenuActionProduction
                                          destructive:NO]];
    }
    [sections addObject:[self pp_sectionWithTitleKey:@"user_menu_activity_section" items:activity.copy]];

    NSArray<PPUserMenuItem *> *tools = @[
        [self pp_itemWithTitleKey:@"Setting"
                      subtitleKey:@"user_menu_settings_subtitle"
                         iconName:@"gearshape.fill"
                        tintColor:UIColor.systemGrayColor
                           action:PPUserMenuActionSettings
                      destructive:NO],
        [self pp_itemWithTitleKey:@"supprot"
                      subtitleKey:@"user_menu_support_subtitle"
                         iconName:@"person.crop.circle.badge.questionmark"
                        tintColor:UIColor.systemTealColor
                           action:PPUserMenuActionSupport
                      destructive:NO]
    ];
    [sections addObject:[self pp_sectionWithTitleKey:@"user_menu_tools_section" items:tools]];

    if (loggedIn) {
        PPUserMenuItem *logout = [self pp_itemWithTitleKey:@"logout"
                                               subtitleKey:@"user_menu_logout_subtitle"
                                                  iconName:@"rectangle.portrait.and.arrow.right"
                                                 tintColor:UIColor.systemRedColor
                                                    action:PPUserMenuActionLogout
                                               destructive:YES];
        [sections addObject:[self pp_sectionWithTitleKey:@"" items:@[logout]]];
    }

    self.sections = sections.copy;
}

- (void)pp_refreshHeaderContent
{
    UserModel *user = UserManager.sharedManager.currentUser ?: PPCurrentUser;
    BOOL loggedIn = PPIsUserLoggedIn && user;
    NSString *displayName = loggedIn ? PPSafeString(user.PPBestDisplayName) : @"PurePets";
    if (loggedIn && displayName.length == 0) {
        displayName = PPSafeString(user.UserName);
    }
    if (loggedIn && displayName.length == 0) {
        displayName = PPUserMenuLocalized(@"Guest");
    }

    self.eyebrowLabel.text = loggedIn ? PPUserMenuLocalized(@"user_menu_signed_in_eyebrow") : PPUserMenuLocalized(@"user_menu_guest_eyebrow");
    self.titleLabel.text = displayName;
    self.subtitleLabel.text = loggedIn ? PPUserMenuLocalized(@"user_menu_subtitle") : PPUserMenuLocalized(@"user_menu_guest_subtitle");
    self.statusPillLabel.text = loggedIn ? PPUserMenuLocalized(@"user_menu_profile_status_ready") : PPUserMenuLocalized(@"user_menu_profile_status_guest");

    NSString *email = loggedIn ? PPSafeString(user.UserEmail) : @"";
    NSString *phone = loggedIn ? PPSafeString(user.MobileNo) : @"";
    NSString *signedInFallback = PPUserMenuLocalized(@"user_menu_profile_meta_signed_in");
    NSString *guestFallback = PPUserMenuLocalized(@"user_menu_profile_meta_guest");
    self.metaLabel.text = loggedIn
        ? PPUserMenuFirstNonEmptyString(@[email, phone, signedInFallback])
        : guestFallback;

    NSString *actionTitle = loggedIn ? PPUserMenuLocalized(@"user_menu_profile_action") : PPUserMenuLocalized(@"user_menu_login_action");
    [self.primaryHeroButton setTitle:actionTitle forState:UIControlStateNormal];
    self.primaryHeroButton.accessibilityLabel = actionTitle;
    self.primaryHeroButton.accessibilityHint = loggedIn
        ? PPUserMenuLocalized(@"user_menu_profile_subtitle")
        : PPUserMenuLocalized(@"user_menu_login_subtitle");
    self.headerCardView.accessibilityLabel = displayName;
    self.headerCardView.accessibilityHint = self.subtitleLabel.text;

    UIImageSymbolConfiguration *buttonConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    NSString *buttonSymbolName = loggedIn ? @"square.and.pencil" : @"person.crop.circle.badge.plus";
    UIImage *buttonImage = [[UIImage systemImageNamed:buttonSymbolName withConfiguration:buttonConfiguration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.primaryHeroButton setImage:buttonImage forState:UIControlStateNormal];
    self.primaryHeroButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.primaryHeroButton.imageEdgeInsets = Language.isRTL
        ? UIEdgeInsetsMake(0.0, 8.0, 0.0, -8.0)
        : UIEdgeInsetsMake(0.0, -8.0, 0.0, 8.0);

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:displayName size:82.0 style:PPModernAvatarStyleGlass];
    self.avatarImageView.image = placeholder;
    NSURL *avatarURL = user.UserImageUrl;
    if (loggedIn && avatarURL.absoluteString.length > 0) {
        [self.avatarImageView sd_setImageWithURL:avatarURL
                                placeholderImage:placeholder
                                         options:SDWebImageRetryFailed | SDWebImageAvoidAutoSetImage
                                       completed:^(UIImage * _Nullable image,
                                                   NSError * _Nullable error,
                                                   SDImageCacheType cacheType,
                                                   NSURL * _Nullable imageURL) {
            if (image) {
                self.avatarImageView.image = image;
            }
        }];
    }
}

#pragma mark - Motion

- (void)pp_prepareEntranceState
{
    if (self.didRunEntrance || self.preparedEntrance) {
        return;
    }
    self.preparedEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
        self.headerCardView.alpha = 1.0;
        self.headerCardView.transform = CGAffineTransformIdentity;
        self.primaryHeroButton.alpha = 1.0;
        self.primaryHeroButton.transform = CGAffineTransformIdentity;
        return;
    }
    self.tableView.alpha = 0.0;
    self.tableView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 14.0),
                                                       CGAffineTransformMakeScale(0.992, 0.992));
    self.headerCardView.alpha = 0.0;
    self.headerCardView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                                           CGAffineTransformMakeScale(1.018, 1.018));
    self.primaryHeroButton.alpha = 0.0;
    self.primaryHeroButton.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntrance) {
        return;
    }
    self.didRunEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
        self.headerCardView.alpha = 1.0;
        self.headerCardView.transform = CGAffineTransformIdentity;
        self.primaryHeroButton.alpha = 1.0;
        self.primaryHeroButton.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.46
                          delay:0.0
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.52
                          delay:0.02
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.headerCardView.alpha = 1.0;
        self.headerCardView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.38
                          delay:0.14
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.primaryHeroButton.alpha = 1.0;
        self.primaryHeroButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Layout

- (void)pp_updateHeaderLayoutIfNeeded
{
    if (!self.headerRootView) {
        return;
    }
    self.cardTopConstraint.constant = PPStatusBarHeight + 12.0;
    
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds);
    }
    if (width <= 0.0) {
        return;
    }

    CGRect measurementFrame = self.headerRootView.frame;
    if (fabs(measurementFrame.size.width - width) > 0.5) {
        measurementFrame.size.width = width;
        self.headerRootView.frame = measurementFrame;
    }
    [self.headerRootView setNeedsLayout];
    [self.headerRootView layoutIfNeeded];

    CGSize fittingSize = [self.headerRootView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                                             withHorizontalFittingPriority:UILayoutPriorityRequired
                                                   verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat height = ceil(MAX(172.0, fittingSize.height));
    CGRect frame = self.headerRootView.frame;
    if (fabs(frame.size.width - width) > 0.5 || fabs(frame.size.height - height) > 0.5) {
        frame.size = CGSizeMake(width, height);
        self.headerRootView.frame = frame;
        self.tableView.tableHeaderView = self.headerRootView;
    }

    [self.headerRootView setNeedsLayout];
    [self.headerRootView layoutIfNeeded];
    [self.headerCardView setNeedsLayout];
    [self.headerCardView layoutIfNeeded];
    [self.headerCardView sendSubviewToBack:self.headerBackgroundView];
    self.headerBackgroundView.hidden = NO;
    self.headerBackgroundView.alpha = 1.0;
    [self.headerBackgroundView setNeedsLayout];
    [self.headerBackgroundView layoutIfNeeded];
    [self pp_layoutHeaderMaterialLayers];
    [self pp_startHeroBackgroundMotionIfNeeded];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)self.sections.count) {
        return 0;
    }
    PPUserMenuSection *menuSection = self.sections[section];
    if ([menuSection.titleKey isEqualToString:@"quick_access_settings_section"]) {
        return 1;
    }
    return menuSection.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPUserMenuSection *section = self.sections[indexPath.section];

    // Check if this is the quick access section
    if ([section.titleKey isEqualToString:@"quick_access_settings_section"]) {
        PPUserMenuQuickAccessCell *cell = [tableView dequeueReusableCellWithIdentifier:PPUserMenuQuickAccessCellIdentifier forIndexPath:indexPath];
        __weak typeof(self) weakSelf = self;
        [cell configureWithItems:section.items actionHandler:^(PPUserMenuAction action) {
            [weakSelf pp_handleAction:action];
        }];
        return cell;
    }

    // Regular menu cell
    PPUserMenuCell *cell = [tableView dequeueReusableCellWithIdentifier:PPUserMenuCellIdentifier forIndexPath:indexPath];
    PPUserMenuItem *item = [self pp_itemAtIndexPath:indexPath];
    [cell configureWithItem:item];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPUserMenuSection *section = self.sections[indexPath.section];
    if ([section.titleKey isEqualToString:@"quick_access_settings_section"]) {
        return 60.0; // Fixed height for quick access rail
    }
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    PPUserMenuSection *menuSection = section < self.sections.count ? self.sections[section] : nil;
    return menuSection.titleKey.length > 0 ? 36.0 : 14.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    PPUserMenuSection *menuSection = section < self.sections.count ? self.sections[section] : nil;
    UIView *header = [UIView new];
    header.backgroundColor = UIColor.clearColor;
    if (menuSection.titleKey.length == 0) {
        return header;
    }

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = PPUserMenuLocalized(menuSection.titleKey);
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                  scaledFontForFont:([GM boldFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold])];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = PPUserMenuColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    label.textAlignment = [Language alignmentForCurrentLanguage];
    [header addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPScreenMargin + PPSpaceSM],
        [label.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-(PPScreenMargin + PPSpaceSM)],
        [label.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-6.0]
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.01;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPUserMenuSection *section = self.sections[indexPath.section];

    // Quick access section buttons handle their own taps
    if ([section.titleKey isEqualToString:@"quick_access_settings_section"]) {
        return;
    }

    PPUserMenuItem *item = [self pp_itemAtIndexPath:indexPath];
    if (!item) {
        return;
    }
    [PPFunc triggerLightHaptic];
    [self pp_handleAction:item.action];
}

- (PPUserMenuItem *)pp_itemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath || indexPath.section >= self.sections.count) {
        return nil;
    }
    PPUserMenuSection *section = self.sections[indexPath.section];
    if (indexPath.row >= section.items.count) {
        return nil;
    }
    return section.items[indexPath.row];
}

#pragma mark - Actions

- (void)pp_handleHeroPrimaryTouchDown:(UIButton *)sender
{
    if (!sender || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.965, 0.965);
        sender.alpha = 0.92;
    } completion:nil];
}

- (void)pp_handleHeroPrimaryTouchUp:(UIButton *)sender
{
    if (!sender) {
        return;
    }
    [UIView animateWithDuration:0.16
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (void)pp_handleHeroPrimaryAction:(UIButton *)sender
{
    [self pp_handleHeroPrimaryTouchUp:sender];
    [PPFunc triggerLightHaptic];
    BOOL loggedIn = PPIsUserLoggedIn && (UserManager.sharedManager.currentUser ?: PPCurrentUser);
    [self pp_handleAction:(loggedIn ? PPUserMenuActionProfile : PPUserMenuActionLogin)];
}

- (void)pp_handleAction:(PPUserMenuAction)action
{
    switch (action) {
        case PPUserMenuActionProfile: {
            if (![PPFunc PPUserCheck]) return;
            ProfileVC *vc = [ProfileVC new];
            vc.view.layer.cornerRadius = 42.0;
            vc.view.backgroundColor = AppBackgroundClr;
            vc.view.clipsToBounds = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionLogin:
            [self pp_presentLogin];
            break;
        case PPUserMenuActionFavorites: {
            if (![PPFunc PPUserCheck]) return;
            MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionMyAds: {
            if (![PPFunc PPUserCheck]) return;
            MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeMyAds];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionCart: {
            if (![PPFunc PPUserCheck]) return;
            CartViewController *vc = [CartViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionPurchased: {
            if (![PPFunc PPUserCheck]) return;
            PurchasedItemsViewController *vc = [PurchasedItemsViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionOrders: {
            if (![PPFunc PPUserCheck]) return;
            OrderHistoryViewController *vc = [OrderHistoryViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionProduction: {
            if (![PPFunc PPUserCheck]) return;
            MainController *vc = [MainController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionSettings: {
            SettingVC *vc = [SettingVC new];
            [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyleProfile];
            break;
        }
        case PPUserMenuActionSupport: {
            CompanyLocationVC *vc = [CompanyLocationVC new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPUserMenuActionLogout:
            [self pp_presentLogoutFlow];
            break;

        // Quick Access Actions
        case PPUserMenuActionQuickAccessLightAppearance: {
            [[PPThemeManager sharedManager] saveUserInterfaceStyle:UIUserInterfaceStyleLight];
            [[PPThemeManager sharedManager] applyInterfaceStyleGlobally:UIUserInterfaceStyleLight];
            [PPFunc triggerLightHaptic];
            [PPHUD showSuccess:kLang(@"quick_access_light_mode_toast")];
            [self pp_rebuildSections];
            [self.tableView reloadData];
            break;
        }
        case PPUserMenuActionQuickAccessDarkAppearance: {
            [[PPThemeManager sharedManager] saveUserInterfaceStyle:UIUserInterfaceStyleDark];
            [[PPThemeManager sharedManager] applyInterfaceStyleGlobally:UIUserInterfaceStyleDark];
            [PPFunc triggerLightHaptic];
            [PPHUD showSuccess:kLang(@"quick_access_dark_mode_toast")];
            [self pp_rebuildSections];
            [self.tableView reloadData];
            break;
        }
        case PPUserMenuActionQuickAccessSwitchToArabic: {
            [Language userSelectedLanguage:@"ar"];
            [PPFunc triggerLightHaptic];
            [self pp_rebuildSections];
            [self.tableView reloadData];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [PPHUD showSuccess:kLang(@"quick_access_lang_ar_toast")];
            });
            break;
        }
        case PPUserMenuActionQuickAccessSwitchToEnglish: {
            [Language userSelectedLanguage:@"en"];
            [PPFunc triggerLightHaptic];
            [self pp_rebuildSections];
            [self.tableView reloadData];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [PPHUD showSuccess:kLang(@"quick_access_lang_en_toast")];
            });
            break;
        }
        case PPUserMenuActionQuickAccessEnableNotifications: {
            [PPFunc triggerLightHaptic];
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        [[UIApplication sharedApplication] registerForRemoteNotifications];
                        [PPHUD showSuccess:kLang(@"Allow Alerts")];
                    } else {
                        [PPHUD showInfo:kLang(@"quick_access_notifications_toast")];
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    }
                });
            }];
            break;
        }
        case PPUserMenuActionQuickAccessEnableLocation: {
            [PPFunc triggerLightHaptic];
            [PPHUD showInfo:kLang(@"quick_access_location_toast")];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
            break;
        }
    }
}

- (void)pp_presentLogin
{
    [PPUserSigningManager presentSignInFrom:self
                            withCountryCode:CitiesManager.shared.CurrentCountry.countryCode
                          presentationStyle:PPSignInPresentationStyleSheet
                       autoDismissOnSuccess:YES
                                     success:^(UserModel *user) {
        [PPFunc reloadAppUI];
        [[AppDataListenerManager shared] stopAllListeners];
        [[AppDataListenerManager shared] startListenersForUser:PPCurrentUser.ID];
    } failure:nil cancelled:nil];
}

- (void)pp_presentLogoutFlow
{
    if (!PPIsUserLoggedIn) {
        [self pp_presentLogin];
        return;
    }
    LeaveFeedbackViewController *feedbackVC = [[LeaveFeedbackViewController alloc] init];
    feedbackVC.onLogout = ^{
        [GM clearUserProfileDefaults];
        [PPFunc reloadAppUI];
    };
    [PPFunc presentSheetFrom:self sheetVC:feedbackVC detentStyle:PPSheetDetentStyle70];
}

@end
