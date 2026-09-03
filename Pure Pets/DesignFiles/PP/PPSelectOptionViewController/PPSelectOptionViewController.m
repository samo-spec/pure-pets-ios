//
//  PPSelectOptionViewController.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//  (Updated with safe XLForm value handling + logging)
//

#import "PPSelectOptionViewController.h"
#import "Styling.h"
#import "Language.h"
#import "PPOptionCell.h"
#import <QuartzCore/QuartzCore.h>
#import "OptionModel.h"
// Simple log helpers
#ifndef DLog
#define DLog(fmt, ...) NSLog((@"[PPLOG] " fmt), ##__VA_ARGS__)
#endif

#define LogCurrentFunc() DLog(@"[%s]", __FUNCTION__)

static CGFloat const PPPremiumOptionPickerDefaultDetentFraction = 0.82;
static CGFloat const PPPremiumOptionPickerSideInset = 16.0;
static CGFloat const PPPremiumOptionPickerExpandedHeroMinHeight = 176.0;
static CGFloat const PPPremiumOptionPickerCompactHeroMinHeight = 136.0;
static CGFloat const PPPremiumOptionPickerTitleOnlyHeroMinHeight = 90.0;
static CGFloat const PPPremiumOptionPickerTopBreath = 10.0;
static CGFloat const PPPremiumOptionPickerHeroToRowsBreath = 16.0;

static NSString *PPSelectOptionTrimmedString(NSString *value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

static BOOL PPSelectOptionStringLooksLikeRemoteImageURL(NSString *value)
{
    NSString *trimmed = PPSelectOptionTrimmedString(value);
    NSString *lowercase = trimmed.lowercaseString;
    return [lowercase hasPrefix:@"http://"] || [lowercase hasPrefix:@"https://"];
}

static NSString *PPSelectOptionLocalizedString(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    if (value.length > 0 && ![value isEqualToString:key]) {
        return value;
    }
    return fallback ?: @"";
}

static BOOL PPSelectOptionTextContainsAny(NSString *text, NSArray<NSString *> *needles)
{
    NSString *safeText = PPSelectOptionTrimmedString(text);
    if (safeText.length == 0) {
        return NO;
    }
    for (NSString *needle in needles) {
        NSString *safeNeedle = PPSelectOptionTrimmedString(needle);
        if (safeNeedle.length > 0 &&
            [safeText localizedCaseInsensitiveContainsString:safeNeedle]) {
            return YES;
        }
    }
    return NO;
}

@interface PPPremiumOptionHeroSurfaceView : UIView
@property (nonatomic, strong, readonly) CAGradientLayer *pp_materialGradientLayer;
@end

@implementation PPPremiumOptionHeroSurfaceView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _pp_materialGradientLayer = [CAGradientLayer layer];
        _pp_materialGradientLayer.name = @"pp.hero.material.gradient";
        [self.layer insertSublayer:_pp_materialGradientLayer atIndex:0];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.pp_materialGradientLayer.frame = self.bounds;
    self.pp_materialGradientLayer.cornerRadius = self.layer.cornerRadius;
}

@end

@interface PPSelectOptionViewController ()<PPSDelegate>
{
    
}
@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedCellKeys;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;
@property (nonatomic, assign) CGFloat premiumHeroHeaderWidth;
@property (nonatomic, strong) UIView *premiumBackgroundView;
@property (nonatomic, strong) UIView *premiumGlowCircleView;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UITextField *headerSearchTextField;
@property (nonatomic, strong) UIButton *headerClearButton;
@property (nonatomic, strong) UILabel *premiumHeroCountLabel;
@property (nonatomic, copy) NSString *premiumHeroSearchText;
- (NSString *)pp_effectivePremiumHeroSubtitle;
- (void)pp_dismissAction;
- (void)pp_filterOptionsWithText:(NSString *)searchText;
- (void)pp_updateEmptyStateVisibility;
- (NSString *)pp_premiumHeroCountText;
- (void)pp_updatePremiumHeroCountLabel;
@end

@implementation PPSelectOptionViewController

#pragma mark - Init

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        LogCurrentFunc();
        _showSearchBar = YES;
        _presentationStyle = PPSelectOptionPresentationSheet;

        _allOptions = @[];
        _filteredOptions = @[];
        _animatedCellKeys = [NSMutableSet set];
        _preferredMainDetentHeight = 0.0;
        _preferredPremiumDetentFraction = PPPremiumOptionPickerDefaultDetentFraction;
        _usesCompactPremiumHero = YES;
        _useUsersOption = NO;
        _premiumHeroSearchText = @"";
    }
    return self;
}


- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                          row:(XLFormRowDescriptor *_Nullable)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                     completion:(PPSelectOptionBlock)completion
{
    return [self initWithOptions:options title:title row:row presentationStyle:style showSearchBar:NO completion:completion];
}
// ✅ Normalize your designated initializer name (lowercase completion)
- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                          row:(XLFormRowDescriptor *_Nullable)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                  showSearchBar:(BOOL)showSearchBar
                     completion:(PPSelectOptionBlock)completion
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        
        _allOptions = options ?: @[];
        _filteredOptions = _allOptions;
        self.title = title;
        _showSearchBar = showSearchBar;
        _presentationStyle = style;
        _onSelectOption = [completion copy];
        self.rowDescriptor = row;
        _animatedCellKeys = [NSMutableSet set];
        _preferredMainDetentHeight = 0.0;
        _preferredPremiumDetentFraction = PPPremiumOptionPickerDefaultDetentFraction;
        _usesCompactPremiumHero = YES;
        _premiumHeroSearchText = @"";
    }
    return self;
}

// ✅ Convenience initializer you’re trying to use
- (instancetype)initWithCompletion:(PPSelectOptionBlock)completion {
    return [self initWithOptions:@[]
                           title:kLang(@"Select")
                             row:self.rowDescriptor
                presentationStyle:PPSelectOptionPresentationSheet
                      completion:completion];
}



#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    LogCurrentFunc();
    
    
   

    BOOL premiumPicker = [self pp_usesPremiumPickerPresentation];
    if (premiumPicker) {
        self.tableView.rowHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedRowHeight = self.isGenderSelector ? 66.0 : (self.usesCompactPremiumHero ? 74.0 : 78.0);
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.backgroundColor = UIColor.clearColor;
        self.tableView.showsVerticalScrollIndicator = NO;
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
        self.tableView.layoutMargins = UIEdgeInsetsZero;
        self.tableView.separatorInset = UIEdgeInsetsZero;
        if (@available(iOS 11.0, *)) {
            self.tableView.directionalLayoutMargins = NSDirectionalEdgeInsetsZero;
            self.tableView.insetsContentViewsToSafeArea = NO;
        }
        if (@available(iOS 15.0, *)) {
            self.tableView.sectionHeaderTopPadding = 0.0;
        }
    } else {
        self.tableView.rowHeight = self.isGenderSelector ? 56.0 : 72.0;
        self.tableView.estimatedRowHeight = self.tableView.rowHeight;
        self.tableView.backgroundColor = PPIOS26() ? AppClearClr : [AppBackgroundClr colorWithAlphaComponent:0.8];
    }
    self.tableView.tableFooterView = [UIView new];
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_applyPremiumTableInsets];
    self.view.backgroundColor = premiumPicker ? [self pp_sheetBackgroundColor] : self.tableView.backgroundColor;
    
    self.view.layer.cornerRadius = premiumPicker ? 36.0 : 25.0;
    self.view.layer.cornerCurve = kCACornerCurveContinuous;
    self.view.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.view.clipsToBounds = YES;
    if (premiumPicker) {
        [self pp_configureNavigationAppearance];
        [self pp_updatePremiumHeroHeaderIfNeeded];
    } else if (self.showSearchBar) {
        [self setupSearchView];
    }

    [self pp_configureSheetPresentationIfNeeded];
    if (premiumPicker) {
        [self pp_prepareEntranceStateIfNeeded];
    }

    // set initial filteredOptions if not set
    if (!self.filteredOptions) self.filteredOptions = self.allOptions ?: @[];

    DLog(@"[PPSelectOption] allOptions=%lu", (unsigned long)self.allOptions.count);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if ([self pp_usesPremiumPickerPresentation]) {
        [self pp_updatePremiumHeroHeaderIfNeeded];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self pp_usesPremiumPickerPresentation]) {
        [self pp_configureNavigationAppearance];
        [self pp_configureSheetPresentationIfNeeded];
        [self pp_prepareEntranceStateIfNeeded];
    } else {
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([self pp_usesPremiumPickerPresentation]) {
        [self pp_runEntranceIfNeeded];
    }
}

- (void)pp_configureNavigationAppearance {
    if (self.presentationStyle != PPSelectOptionPresentationPush) {
        self.navigationController.navigationBarHidden = YES;
        self.navigationItem.title = nil;
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }
    self.navigationController.navigationBarHidden = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationController.navigationBar.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    self.navigationController.navigationBar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UIColor *sheetBackgroundColor = [self pp_sheetBackgroundColor];

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundEffect = nil;
        appearance.backgroundColor = sheetBackgroundColor;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: AppPrimaryTextClr ?: UIColor.labelColor,
            NSFontAttributeName: [Styling fontBold:18] ?: [UIFont systemFontOfSize:18 weight:UIFontWeightBold]
        };
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    }
    self.navigationController.navigationBar.backgroundColor = sheetBackgroundColor;
}

- (void)pp_configureSheetPresentationIfNeeded {
    if (self.presentationStyle == PPSelectOptionPresentationPush) return;
    if (@available(iOS 15.0, *)) {
        UIViewController *sheetOwner = self.navigationController ?: self;
        UISheetPresentationController *sheet = sheetOwner.sheetPresentationController;
        if (!sheet) return;

        BOOL premiumPicker = [self pp_usesPremiumPickerPresentation];
        sheet.prefersGrabberVisible = NO; // Studio Header has its own grabber and frosted close button
        sheet.prefersScrollingExpandsWhenScrolledToEdge = premiumPicker;
        sheet.preferredCornerRadius = premiumPicker ? 36.0 : 25.0;

        BOOL isUserMode = self.useUsersOption || [self.allOptions.firstObject isKindOfClass:[UserModel class]];
        BOOL needsSearch = self.showSearchBar || isUserMode || self.allOptions.count > 4;

        if (self.presentationStyle == PPSelectOptionPresentationMain || (!needsSearch && self.allOptions.count <= 3)) {
            if (@available(iOS 16.0, *)) {
                CGFloat calculatedHeight = 148.0 + (self.allOptions.count * 88.0) + 40.0;
                CGFloat preferredHeight = self.preferredMainDetentHeight > 0.0 ? MIN(self.preferredMainDetentHeight, calculatedHeight) : calculatedHeight;
                UISheetPresentationControllerDetent *compactDetent =
                [UISheetPresentationControllerDetent customDetentWithIdentifier:@"pp.compact.option.sheet"
                                                                        resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext>  _Nonnull context) {
                    return MIN(preferredHeight, context.maximumDetentValue);
                }];
                sheet.detents = @[compactDetent];
                sheet.selectedDetentIdentifier = compactDetent.identifier;
            } else {
                sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent]];
            }
        } else if (premiumPicker) {
            if (@available(iOS 16.0, *)) {
                CGFloat preferredFraction = [self pp_resolvedPremiumDetentFraction];
                UISheetPresentationControllerDetent *premiumDetent =
                [UISheetPresentationControllerDetent customDetentWithIdentifier:@"pp.premium.option.sheet"
                                                                        resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext>  _Nonnull context) {
                    CGFloat fractionHeight = context.maximumDetentValue * preferredFraction;
                    return MIN(MAX(fractionHeight, 460.0), context.maximumDetentValue);
                }];
                sheet.detents = @[premiumDetent, [UISheetPresentationControllerDetent largeDetent]];
                sheet.selectedDetentIdentifier = premiumDetent.identifier;
            } else {
                sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
            }
        } else {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
        }
    }
}

- (void)configurePremiumHeroWithEyebrow:(NSString *)eyebrow
                                  title:(NSString *)title
                                subtitle:(NSString *)subtitle
                              symbolName:(NSString *)symbolName
                               badgeText:(NSString *)badgeText
{
    self.premiumHeroEyebrow = eyebrow;
    self.premiumHeroTitle = title;
    self.premiumHeroSubtitle = subtitle;
    self.premiumHeroSymbolName = symbolName;
    self.premiumHeroBadgeText = badgeText;
    if (self.isViewLoaded && !self.showSearchBar) {
        self.premiumHeroHeaderWidth = 0.0;
        [self pp_applyPremiumTableInsets];
        [self pp_configurePremiumBackgroundIfNeeded];
        [self pp_updatePremiumHeroHeaderIfNeeded];
    }
}

- (BOOL)pp_hasPremiumHeroHeader {
    return [self pp_effectivePremiumHeroTitle].length > 0 ||
           [self pp_effectivePremiumHeroSubtitle].length > 0 ||
           self.premiumHeroSymbolName.length > 0 ||
           self.premiumHeroEyebrow.length > 0;
}

- (BOOL)pp_usesPremiumPickerPresentation {
    return self.presentationStyle != PPSelectOptionPresentationPush;
}

- (NSString *)pp_effectivePremiumHeroTitle {
    if (self.premiumHeroTitle.length > 0) return self.premiumHeroTitle;
    return self.title.length > 0 ? self.title : nil;
}

- (NSString *)pp_effectivePremiumHeroSubtitle {
    NSString *explicitSubtitle = PPSelectOptionTrimmedString(self.premiumHeroSubtitle);
    if (explicitSubtitle.length > 0) {
        return explicitSubtitle;
    }

    if (self.useUsersOption || [self.allOptions.firstObject isKindOfClass:[UserModel class]]) {
        return kLang(@"selection_studio_user_subtitle") ?: @"اختر جهة الاتصال لبدء محادثة فورية جديدة.";
    }

    if ([self.allOptions.firstObject isKindOfClass:[OptionModel class]]) {
        return (kLang(@"create_picker_subtitle") ?: @"اختر نوع النشر المناسب، وسنفتح النموذج الصحيح مباشرة.");
    }

    NSString *title = PPSelectOptionTrimmedString([self pp_effectivePremiumHeroTitle]);
    if (PPSelectOptionTextContainsAny(title, @[
        PPSelectOptionLocalizedString(@"Species", @"Species"),
        PPSelectOptionLocalizedString(@"selectSpecies", @"Select Species"),
        PPSelectOptionLocalizedString(@"KLang_SelectPetCategory", @"Select Pet Category"),
        PPSelectOptionLocalizedString(@"Category", @"Category"),
        @"الفئة",
        @"النوع",
        @"species",
        @"category"
    ])) {
        return PPSelectOptionLocalizedString(@"option_picker_species_subtitle",
                                            @"Choose the main category that matches this pet.");
    }

    if (PPSelectOptionTextContainsAny(title, @[
        PPSelectOptionLocalizedString(@"Breed", @"Breed"),
        PPSelectOptionLocalizedString(@"breed", @"Breed"),
        PPSelectOptionLocalizedString(@"selectCreed", @"Select Breed"),
        PPSelectOptionLocalizedString(@"subSubKind", @"Breed"),
        PPSelectOptionLocalizedString(@"subcategory", @"Breed"),
        @"السلالة",
        @"breed"
    ])) {
        return PPSelectOptionLocalizedString(@"option_picker_breed_subtitle",
                                            @"Choose the breed or family that best describes the pet.");
    }

    if (PPSelectOptionTextContainsAny(title, @[
        PPSelectOptionLocalizedString(@"selectGender", @"Select gender"),
        PPSelectOptionLocalizedString(@"SexualPlace", @"Select gender"),
        @"الجنس",
        @"gender"
    ])) {
        return PPSelectOptionLocalizedString(@"option_picker_gender_subtitle",
                                            @"Choose the value that should appear on this ad.");
    }

    return PPSelectOptionLocalizedString(@"option_picker_default_subtitle",
                                        @"Pick one option to continue.");
}


- (CGFloat)pp_resolvedPremiumDetentFraction {
    CGFloat fraction = self.preferredPremiumDetentFraction > 0.0
        ? self.preferredPremiumDetentFraction
        : PPPremiumOptionPickerDefaultDetentFraction;
    return MIN(MAX(fraction, 0.62), 0.86);
}

- (CGFloat)pp_effectiveHorizontalInset {
    CGFloat margin = self.tableView.layoutMargins.left;
    if (margin >= 16.0) {
        return margin;
    }
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(UIScreen.mainScreen.bounds);
    }
    return (width > 380.0) ? 20.0 : 16.0;
}

- (CGFloat)pp_premiumPickerSideInset {
    return [self pp_effectiveHorizontalInset];
}

- (void)pp_applyPremiumTableInsets {
    UIEdgeInsets inset = [self pp_usesPremiumPickerPresentation]
        ? UIEdgeInsetsMake(0.0, 0.0, 32.0, 0.0)
        : UIEdgeInsetsZero;
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
}

- (UIFont *)pp_scaledFont:(UIFont *)font textStyle:(UIFontTextStyle)textStyle {
    UIFont *resolvedFont = font ?: [UIFont preferredFontForTextStyle:textStyle];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:resolvedFont];
    }
    return resolvedFont;
}

- (UIColor *)pp_dynamicLightColor:(UIColor *)lightColor darkColor:(UIColor *)darkColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

- (void)pp_updatePremiumHeroHeaderIfNeeded {
    if (![self pp_usesPremiumPickerPresentation]) {
        self.tableView.tableHeaderView = nil;
        self.premiumHeroHeaderWidth = 0.0;
        self.headerSearchTextField = nil;
        self.headerClearButton = nil;
        self.premiumHeroCountLabel = nil;
        [self pp_configurePremiumBackgroundIfNeeded];
        return;
    }

    [self pp_configurePremiumBackgroundIfNeeded];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(UIScreen.mainScreen.bounds);
    }
    if (fabs(width - self.premiumHeroHeaderWidth) < 0.5 && self.tableView.tableHeaderView) {
        [self pp_updatePremiumHeroCountLabel];
        return;
    }

    NSString *retainedSearchText = self.headerSearchTextField.text ?: self.premiumHeroSearchText ?: @"";
    self.premiumHeroSearchText = retainedSearchText;
    BOOL restoreSearchFocus = self.headerSearchTextField.isFirstResponder;
    self.headerSearchTextField = nil;
    self.headerClearButton = nil;
    self.premiumHeroCountLabel = nil;
    UIView *header = [self pp_makePremiumHeroHeaderWithWidth:width];
    self.tableView.tableHeaderView = header;
    self.premiumHeroHeaderWidth = width;
    if (restoreSearchFocus && self.headerSearchTextField) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.headerSearchTextField becomeFirstResponder];
        });
    }
}

- (NSString *)pp_premiumHeroCountText {
    NSString *countString = self.premiumHeroBadgeText;
    if (countString.length > 0) {
        return countString;
    }

    NSUInteger count = self.filteredOptions.count;
    BOOL isUserMode = self.useUsersOption || [self.allOptions.firstObject isKindOfClass:[UserModel class]];
    if (isUserMode) {
        NSString *format = count == 1
            ? (kLang(@"selection_studio_user_count_single") ?: @"مستخدم واحد")
            : (kLang(@"selection_studio_user_count") ?: @"%lu مستخدم");
        return [NSString stringWithFormat:format, (unsigned long)count];
    }

    NSString *format = count == 1
        ? (kLang(@"selection_studio_action_count_single") ?: @"خيار واحد")
        : (kLang(@"selection_studio_action_count") ?: @"%lu خيارات");
    return [NSString stringWithFormat:format, (unsigned long)count];
}

- (void)pp_updatePremiumHeroCountLabel {
    if (!self.premiumHeroCountLabel) {
        return;
    }
    self.premiumHeroCountLabel.text = [self pp_premiumHeroCountText];
    [self.premiumHeroCountLabel.superview setNeedsLayout];
}

- (UIView *)pp_makePremiumHeroHeaderWithWidth:(CGFloat)width {
    CGFloat safeWidth = MAX(width, 320.0);
    UIColor *accent = self.premiumHeroAccentColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    NSTextAlignment alignment = [Language alignmentForCurrentLanguage];
    
    NSString *resolvedTitle = [self pp_effectivePremiumHeroTitle] ?: @"";
    NSString *resolvedSubtitle = [self pp_effectivePremiumHeroSubtitle] ?: @"";
    
    BOOL isUserMode = self.useUsersOption || [self.allOptions.firstObject isKindOfClass:[UserModel class]];
    BOOL needsSearch = self.showSearchBar || isUserMode || self.allOptions.count > 4;
    
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, safeWidth, 1.0)];
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // 1. Sleek top grabber handle
    UIView *grabber = [UIView new];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent:0.18];
    grabber.layer.cornerRadius = 2.5;
    grabber.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:grabber];

    // 2. Circular glass close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    closeBtn.backgroundColor = [self pp_dynamicLightColor:[UIColor colorWithWhite:0.0 alpha:0.05]
                                                darkColor:[UIColor colorWithWhite:1.0 alpha:0.12]];
    closeBtn.layer.cornerRadius = 16.0;
    closeBtn.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageSymbolConfiguration *xConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold];
    UIImage *xImg = [UIImage systemImageNamed:@"xmark" withConfiguration:xConfig];
    [closeBtn setImage:[xImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    closeBtn.tintColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    [closeBtn addTarget:self action:@selector(pp_dismissAction) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:closeBtn];

    // 3. Context Pill & Eyebrow Row
    UIView *contextPill = [UIView new];
    contextPill.translatesAutoresizingMaskIntoConstraints = NO;
    contextPill.backgroundColor = [accent colorWithAlphaComponent:0.10];
    contextPill.layer.cornerRadius = 12.0;
    contextPill.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:contextPill];

    UIView *pulseDot = [UIView new];
    pulseDot.translatesAutoresizingMaskIntoConstraints = NO;
    pulseDot.backgroundColor = accent;
    pulseDot.layer.cornerRadius = 3.5;
    [contextPill addSubview:pulseDot];

    UILabel *contextLabel = [UILabel new];
    contextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    contextLabel.font = [Styling fontBold:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    contextLabel.textColor = accent;
    contextLabel.textAlignment = alignment;
    
    NSString *contextText = self.premiumHeroEyebrow;
    if (!contextText.length) {
        if (isUserMode) contextText = kLang(@"messages") ?: @"صندوق التواصل";
        else if ([self.allOptions.firstObject isKindOfClass:[OptionModel class]]) contextText = kLang(@"selection_studio_quick_action") ?: @"إجراء سريع";
        else contextText = kLang(@"Select") ?: @"تحديد خيار";
    }
    contextLabel.text = contextText;
    [contextPill addSubview:contextLabel];

    // Telemetry Count Pill
    UIView *countPill = [UIView new];
    countPill.translatesAutoresizingMaskIntoConstraints = NO;
    countPill.backgroundColor = [self pp_dynamicLightColor:[UIColor colorWithWhite:0.0 alpha:0.04]
                                                 darkColor:[UIColor colorWithWhite:1.0 alpha:0.08]];
    countPill.layer.cornerRadius = 12.0;
    countPill.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:countPill];

    UILabel *countLabel = [UILabel new];
    countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    countLabel.font = [Styling fontMedium:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    countLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    countLabel.textAlignment = NSTextAlignmentCenter;
    
    countLabel.text = [self pp_premiumHeroCountText];
    [countPill addSubview:countLabel];
    self.premiumHeroCountLabel = countLabel;

    // 4. Hero Title
    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [self pp_scaledFont:([Styling fontBold:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold])
                           textStyle:UIFontTextStyleTitle2];
    title.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    title.textAlignment = alignment;
    title.numberOfLines = 2;
    title.adjustsFontForContentSizeCategory = YES;
    title.text = resolvedTitle;
    [container addSubview:title];

    // 5. Hero Subtitle
    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [self pp_scaledFont:([Styling fontRegular:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular])
                              textStyle:UIFontTextStyleSubheadline];
    subtitle.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitle.textAlignment = alignment;
    subtitle.numberOfLines = 2;
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.text = resolvedSubtitle;
    [container addSubview:subtitle];

    CGFloat sideInset = [self pp_effectiveHorizontalInset];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [grabber.topAnchor constraintEqualToAnchor:container.topAnchor constant:8.0],
        [grabber.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:36.0],
        [grabber.heightAnchor constraintEqualToConstant:5.0],

        [contextPill.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:12.0],
        [contextPill.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:sideInset],
        [contextPill.heightAnchor constraintEqualToConstant:26.0],

        [pulseDot.leadingAnchor constraintEqualToAnchor:contextPill.leadingAnchor constant:8.0],
        [pulseDot.centerYAnchor constraintEqualToAnchor:contextPill.centerYAnchor],
        [pulseDot.widthAnchor constraintEqualToConstant:7.0],
        [pulseDot.heightAnchor constraintEqualToConstant:7.0],

        [contextLabel.leadingAnchor constraintEqualToAnchor:pulseDot.trailingAnchor constant:5.0],
        [contextLabel.trailingAnchor constraintEqualToAnchor:contextPill.trailingAnchor constant:-9.0],
        [contextLabel.centerYAnchor constraintEqualToAnchor:contextPill.centerYAnchor],

        [countPill.leadingAnchor constraintEqualToAnchor:contextPill.trailingAnchor constant:8.0],
        [countPill.centerYAnchor constraintEqualToAnchor:contextPill.centerYAnchor],
        [countPill.heightAnchor constraintEqualToConstant:26.0],
        [countPill.trailingAnchor constraintLessThanOrEqualToAnchor:closeBtn.leadingAnchor constant:-8.0],

        [countLabel.leadingAnchor constraintEqualToAnchor:countPill.leadingAnchor constant:9.0],
        [countLabel.trailingAnchor constraintEqualToAnchor:countPill.trailingAnchor constant:-9.0],
        [countLabel.centerYAnchor constraintEqualToAnchor:countPill.centerYAnchor],

        [closeBtn.centerYAnchor constraintEqualToAnchor:contextPill.centerYAnchor],
        [closeBtn.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-sideInset],
        [closeBtn.widthAnchor constraintEqualToConstant:32.0],
        [closeBtn.heightAnchor constraintEqualToConstant:32.0],

        [title.topAnchor constraintEqualToAnchor:contextPill.bottomAnchor constant:12.0],
        [title.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:sideInset],
        [title.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-sideInset],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor]
    ]];

    if (needsSearch) {
        UIView *searchCapsule = [UIView new];
        searchCapsule.translatesAutoresizingMaskIntoConstraints = NO;
        searchCapsule.backgroundColor = [self pp_dynamicLightColor:[UIColor colorWithWhite:0.0 alpha:0.045]
                                                         darkColor:[UIColor colorWithWhite:1.0 alpha:0.085]];
        searchCapsule.layer.cornerRadius = 14.0;
        searchCapsule.layer.cornerCurve = kCACornerCurveContinuous;
        searchCapsule.layer.borderWidth = 0.75;
        searchCapsule.layer.borderColor = [self pp_dynamicLightColor:[UIColor colorWithWhite:0.0 alpha:0.06]
                                                           darkColor:[UIColor colorWithWhite:1.0 alpha:0.10]].CGColor;
        [container addSubview:searchCapsule];

        UIImageSymbolConfiguration *magConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightMedium];
        UIImageView *magIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:magConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        magIcon.translatesAutoresizingMaskIntoConstraints = NO;
        magIcon.tintColor = AppTertiaryTextClr ?: UIColor.tertiaryLabelColor;
        [searchCapsule addSubview:magIcon];

        UITextField *searchField = [UITextField new];
        searchField.translatesAutoresizingMaskIntoConstraints = NO;
        searchField.font = [Styling fontRegular:14.0] ?: [UIFont systemFontOfSize:14.0];
        searchField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        searchField.tintColor = accent;
        searchField.textAlignment = alignment;
        searchField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        searchField.placeholder = isUserMode ? (kLang(@"selection_studio_search_users_placeholder") ?: @"ابحث عن عضو أو جهة اتصال...") : (kLang(@"selection_studio_search_placeholder") ?: @"ابحث بالاسم أو الوصف...");
        searchField.clearButtonMode = UITextFieldViewModeNever;
        searchField.autocorrectionType = UITextAutocorrectionTypeNo;
        searchField.returnKeyType = UIReturnKeyDone;
        searchField.text = self.premiumHeroSearchText ?: @"";
        [searchField addTarget:self action:@selector(pp_searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
        [searchCapsule addSubview:searchField];
        self.headerSearchTextField = searchField;

        UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        clearBtn.translatesAutoresizingMaskIntoConstraints = NO;
        UIImage *clearImg = [UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:magConfig];
        [clearBtn setImage:[clearImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        clearBtn.tintColor = AppTertiaryTextClr ?: UIColor.tertiaryLabelColor;
        clearBtn.hidden = searchField.text.length == 0;
        [clearBtn addTarget:self action:@selector(pp_clearSearchFieldAction) forControlEvents:UIControlEventTouchUpInside];
        [searchCapsule addSubview:clearBtn];
        self.headerClearButton = clearBtn;

        [constraints addObjectsFromArray:@[
            [searchCapsule.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:14.0],
            [searchCapsule.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:sideInset],
            [searchCapsule.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-sideInset],
            [searchCapsule.heightAnchor constraintEqualToConstant:44.0],
            [searchCapsule.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-12.0],

            [magIcon.leadingAnchor constraintEqualToAnchor:searchCapsule.leadingAnchor constant:12.0],
            [magIcon.centerYAnchor constraintEqualToAnchor:searchCapsule.centerYAnchor],
            [magIcon.widthAnchor constraintEqualToConstant:18.0],
            [magIcon.heightAnchor constraintEqualToConstant:18.0],

            [clearBtn.trailingAnchor constraintEqualToAnchor:searchCapsule.trailingAnchor constant:-10.0],
            [clearBtn.centerYAnchor constraintEqualToAnchor:searchCapsule.centerYAnchor],
            [clearBtn.widthAnchor constraintEqualToConstant:24.0],
            [clearBtn.heightAnchor constraintEqualToConstant:24.0],

            [searchField.leadingAnchor constraintEqualToAnchor:magIcon.trailingAnchor constant:8.0],
            [searchField.trailingAnchor constraintEqualToAnchor:clearBtn.leadingAnchor constant:-6.0],
            [searchField.topAnchor constraintEqualToAnchor:searchCapsule.topAnchor],
            [searchField.bottomAnchor constraintEqualToAnchor:searchCapsule.bottomAnchor]
        ]];
    } else {
        [constraints addObject:[subtitle.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14.0]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
    [container setNeedsLayout];
    [container layoutIfNeeded];
    CGSize fittingSize = [container systemLayoutSizeFittingSize:CGSizeMake(safeWidth, UILayoutFittingCompressedSize.height)
                                  withHorizontalFittingPriority:UILayoutPriorityRequired
                                        verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat resolvedHeight = ceil(fittingSize.height);
    container.frame = CGRectMake(0.0, 0.0, safeWidth, resolvedHeight);
    [container setNeedsLayout];
    [container layoutIfNeeded];
    return container;
}

- (void)pp_dismissAction {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
    if (self.presentationStyle == PPSelectOptionPresentationPush) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_searchTextChanged:(UITextField *)sender {
    NSString *query = sender.text ?: @"";
    self.premiumHeroSearchText = query;
    self.headerClearButton.hidden = query.length == 0;
    [self pp_filterOptionsWithText:query];
}

- (void)pp_clearSearchFieldAction {
    self.headerSearchTextField.text = @"";
    self.premiumHeroSearchText = @"";
    self.headerClearButton.hidden = YES;
    [self pp_filterOptionsWithText:@""];
    [self.headerSearchTextField resignFirstResponder];
}

- (void)pp_resetSearchAction {
    [self pp_clearSearchFieldAction];
}

- (void)pp_filterOptionsWithText:(NSString *)searchText {
    NSString *cleanText = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanText.length == 0) {
        self.filteredOptions = self.allOptions ?: @[];
        [self reloadTableViewAnimated];
        [self pp_updatePremiumHeroCountLabel];
        [self pp_updateEmptyStateVisibility];
        return;
    }

    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(id option, NSDictionary *bindings) {
        if ([option isKindOfClass:[UserModel class]]) {
            UserModel *u = (UserModel *)option;
            NSString *fullName = [NSString stringWithFormat:@"%@ %@ %@ %@ %@", u.UserName ?: @"", u.FirstName ?: @"", u.LastName ?: @"", u.MobileNo ?: @"", u.UserEmail ?: @""];
            return [fullName localizedCaseInsensitiveContainsString:cleanText];
        }
        if ([option isKindOfClass:[OptionModel class]]) {
            OptionModel *op = (OptionModel *)option;
            NSString *full = [NSString stringWithFormat:@"%@ %@ %@", op.title ?: @"", op.desc ?: @"", op.subtitle ?: @""];
            return [full localizedCaseInsensitiveContainsString:cleanText];
        }
        NSString *display = [self displayTextForOption:option];
        if (!display) return NO;
        return [display localizedCaseInsensitiveContainsString:cleanText];
    }];

    self.filteredOptions = [self.allOptions filteredArrayUsingPredicate:p];
    [self reloadTableViewAnimated];
    [self pp_updatePremiumHeroCountLabel];
    [self pp_updateEmptyStateVisibility];
}

- (void)pp_updateEmptyStateVisibility {
    if (self.filteredOptions.count == 0 && self.allOptions.count > 0) {
        if (!self.emptyStateView) {
            UIView *empty = [UIView new];
            empty.translatesAutoresizingMaskIntoConstraints = YES;
            empty.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            UIView *iconPlate = [UIView new];
            iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
            iconPlate.backgroundColor = [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.08];
            iconPlate.layer.cornerRadius = 32.0;
            [empty addSubview:iconPlate];
            
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightMedium];
            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]];
            icon.translatesAutoresizingMaskIntoConstraints = NO;
            icon.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
            [iconPlate addSubview:icon];
            
            UILabel *title = [UILabel new];
            title.translatesAutoresizingMaskIntoConstraints = NO;
            title.font = [Styling fontBold:17] ?: [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
            title.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
            title.textAlignment = NSTextAlignmentCenter;
            title.text = kLang(@"selection_studio_no_results_title") ?: @"لا توجد نتائج مطابقة";
            [empty addSubview:title];
            
            UILabel *subtitle = [UILabel new];
            subtitle.translatesAutoresizingMaskIntoConstraints = NO;
            subtitle.font = [Styling fontRegular:13.5] ?: [UIFont systemFontOfSize:13.5];
            subtitle.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
            subtitle.textAlignment = NSTextAlignmentCenter;
            subtitle.numberOfLines = 2;
            subtitle.text = kLang(@"selection_studio_no_results_desc") ?: @"تأكد من كتابة الكلمة بشكل صحيح أو جرّب بحثاً آخر.";
            [empty addSubview:subtitle];
            
            UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            resetBtn.translatesAutoresizingMaskIntoConstraints = NO;
            [resetBtn setTitle:(kLang(@"selection_studio_clear_search") ?: @"إعادة تعيين البحث") forState:UIControlStateNormal];
            resetBtn.titleLabel.font = [Styling fontBold:14];
            resetBtn.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
            [resetBtn addTarget:self action:@selector(pp_resetSearchAction) forControlEvents:UIControlEventTouchUpInside];
            [empty addSubview:resetBtn];
            
            [NSLayoutConstraint activateConstraints:@[
                [iconPlate.centerXAnchor constraintEqualToAnchor:empty.centerXAnchor],
                [iconPlate.topAnchor constraintEqualToAnchor:empty.topAnchor constant:40.0],
                [iconPlate.widthAnchor constraintEqualToConstant:64.0],
                [iconPlate.heightAnchor constraintEqualToConstant:64.0],
                [icon.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
                [icon.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
                
                [title.topAnchor constraintEqualToAnchor:iconPlate.bottomAnchor constant:16.0],
                [title.leadingAnchor constraintEqualToAnchor:empty.leadingAnchor constant:24.0],
                [title.trailingAnchor constraintEqualToAnchor:empty.trailingAnchor constant:-24.0],
                
                [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6.0],
                [subtitle.leadingAnchor constraintEqualToAnchor:empty.leadingAnchor constant:24.0],
                [subtitle.trailingAnchor constraintEqualToAnchor:empty.trailingAnchor constant:-24.0],
                
                [resetBtn.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:12.0],
                [resetBtn.centerXAnchor constraintEqualToAnchor:empty.centerXAnchor],
                [resetBtn.bottomAnchor constraintLessThanOrEqualToAnchor:empty.bottomAnchor constant:-20.0]
            ]];
            
            self.emptyStateView = empty;
        }
        self.tableView.backgroundView = self.emptyStateView;
    } else {
        self.tableView.backgroundView = nil;
    }
}

- (void)pp_configurePremiumBackgroundIfNeeded {
    self.tableView.backgroundColor = UIColor.clearColor;
    self.view.backgroundColor = [self pp_sheetBackgroundColor];
}

- (void)pp_layoutPremiumBackgroundGlow {
}

- (void)pp_startPremiumGlowAnimationIfNeeded {
}


- (void)pp_prepareEntranceStateIfNeeded {
    if (self.didRunEntrance || self.didPrepareEntrance) return;
    self.didPrepareEntrance = YES;
    self.tableView.alpha = 0.0;
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        self.tableView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    }
}

- (void)pp_runEntranceIfNeeded {
    if (self.didRunEntrance) return;
    self.didRunEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.tableView.alpha = 1.0;
        } completion:nil];
        return;
    }

    [UIView animateWithDuration:0.36
                          delay:0.02
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.35
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

/********** DID SELECT HELPERS **********
 - Normalizes incoming option to UserModel if possible
 - Updates XLForm row value with display text (STRING) to avoid XLForm NSString crashes
 - Calls onSelectOption callback (preserves previous behavior)
 - Returns the PPUserTokenID/device token if present (or nil)
*****************************************/
- (nullable NSString *)didSelectObjectAndReturnDevID:(id)obj {

    // Normalize to UserModel where possible
  
    if ([obj isKindOfClass:[CountryCodeModel class]]) {
        DLog(@"didSelectObject called with CountryCodeModel obj: %@", obj);

    } else if ([obj isKindOfClass:[PPAddressModel class]]) {
        DLog(@"didSelectObjectAndReturnDevID called with PPAddressModel obj: %@", obj);

    } else if ([obj isKindOfClass:[XLFormOptionsObject class]]) {
        // if the options object stored a UserModel in userInfo or value, try that
       /*
        XLFormOptionsObject *opt = (XLFormOptionsObject *)obj;
        if ([opt.valueData isKindOfClass:[UserModel class]]) {
            user = (UserModel *)opt.valueData;
        } else if ([opt.userInfo isKindOfClass:[NSDictionary class]]) {
            id maybeUser = opt.userInfo[@"user"];
            if ([maybeUser isKindOfClass:[UserModel class]]) {
                user = (UserModel *)maybeUser;
            }
        }
        */
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        // sometimes you may be passing a dict (e.g. from some earlier mapping)
        NSDictionary *d = (NSDictionary *)obj;
        // attempt to create a user or extract dev id directly
        NSString *dev = d[@"PPUserTokenID"] ?: d[@"deviceToken"] ?: d[@"token"];
        if (dev) {
            DLog(@"didSelect: got PPUserTokenID from NSDictionary: %@", dev);
            // Update row with readable text if available
            NSString *display = d[@"display"] ?: d[@"name"] ?: d[@"email"] ?: dev;
            [self updateRowValue:display];
            if (self.onSelectOption) self.onSelectOption(obj);
            return dev;
        }
    } else if ([obj isKindOfClass:NSString.class]) {
        // selected a plain string — nothing to parse to user
        DLog(@"didSelect: got NSString -> %@", (NSString *)obj);
        [self updateRowValue:(NSString *)obj]; // but make sure updateRowValue accepts string
        if (self.onSelectOption) self.onSelectOption(obj);
        return nil;
    }
 

    // fallback: still update row and call callback
    DLog(@"didSelect: couldn't resolve UserModel — calling callback with raw object");
    NSString *displayFallback = [obj description] ?: @"";
    [self updateRowValue:displayFallback];
    if (self.onSelectOption) self.onSelectOption(obj);
    return nil;
}


#pragma mark - Search header
- (void)setupSearchView {
    CGFloat padding = 20.0;
    CGFloat searchHeight = 50.0;
    CGFloat containerHeight = padding + searchHeight + padding;
    CGFloat width = self.view.bounds.size.width;

    // ✅ tableHeaderView must have a concrete frame
    self.searchContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, containerHeight)];
    self.searchContainer.backgroundColor = UIColor.clearColor;

    // PPS instance
    self.searchView = [[PPS alloc] initWithFrame:CGRectZero];
    self.searchView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchView.cornerRadius = searchHeight/2.0;
    self.searchView.blurEnabled = NO;
    self.searchView.shadowEnabled = YES;
    self.searchView.debounceInterval = 0.16;
    self.searchView.fuzzyEnabled = YES;
    self.searchView.caseInsensitive = YES;
    self.searchView.diacriticsInsensitive = YES;
    self.searchView.minRelevanceScore = 0.45;
    self.searchView.maxResults = 200;
    self.searchView.delegate = self;
    self.searchView.backgroundColor = AppForgroundColr;

    // Buttons
    UIImage *fil = [UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"];
    [self.searchView configurePrimaryButtonWithImage:fil target:self action:@selector(onFilterTapped:)];
    self.searchView.showsPrimaryButton = YES;
    self.searchView.showsSecondaryButton = NO;

    // Localization
    self.searchView.textField.placeholder = kLang(@"SearchHere");
    self.searchView.textField.textAlignment = [Language alignmentForCurrentLanguage];
    self.searchView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self.searchContainer addSubview:self.searchView];

    // ✅ pin searchView inside searchContainer with 15 padding
    [NSLayoutConstraint activateConstraints:@[
        [self.searchView.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor constant:padding],
        [self.searchView.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:padding],
        [self.searchView.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-padding],
        [self.searchView.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:-padding],
        [self.searchView.heightAnchor constraintEqualToConstant:searchHeight]
    ]];

    // ✅ assign header
    self.tableView.tableHeaderView = self.searchContainer;

    // provide search items (empty for now)
    __weak typeof(self) weakSelf = self;
    [self.searchView setSearchItems:self.allOptions stringProvider:^NSString * _Nonnull(id item) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return @"";
        if ([item isKindOfClass:PPAddressModel.class]) {
            PPAddressModel *m = (PPAddressModel *)item;
            return m.displayText ?: m.fullName ?: @"";
        }

        if ([item isKindOfClass:UserModel.class]) {
            UserModel *m = (UserModel *)item;
            return [NSString stringWithFormat:@"%@ %@", m.UserName ?: @"", m.UserEmail ?: @""];
        }

        return [self displayTextForOption:item] ?: @"";
    }];
    
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}


- (void)onFilterTapped:(id)sender {
    DLog(@"[PPSelectOption] onFilterTapped");
    // hook for client; leave empty to not change logic
}

- (void)onClearTapped:(id)sender {
    DLog(@"[PPSelectOption] onClearTapped — clearing search");
  
    self.filteredOptions = self.allOptions;
    [self reloadTableViewAnimated];
}

#pragma mark - UITableView helpers

- (void)reloadTableViewAnimated {
    [self.animatedCellKeys removeAllObjects];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.tableView reloadData];
        return;
    }
    // simple fade animation to show updated results
    [UIView transitionWithView:self.tableView
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [self.tableView reloadData];
    } completion:nil];
}

#pragma mark - Table data source / delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredOptions.count;
}

- (PPOptionCell *)makeCellForTable:(UITableView *)tableView reuseId:(NSString *)reuse {
    PPOptionCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[PPOptionCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    }
    return cell;
}

#pragma mark - UITableViewDataSource

- (NSString *)emojiFlagForCountryCode:(NSString *)countryCode {
    if (countryCode.length < 2) return @"";
    NSString *code = [[countryCode substringToIndex:2] uppercaseString];
    
    int base = 127397; // regional indicator base
    uint32_t first = [code characterAtIndex:0] + base;
    uint32_t second = [code characterAtIndex:1] + base;
    
    // Combine both into a proper UTF-32 array
    uint32_t scalars[] = { first, second };
    NSString *flag = [[NSString alloc] initWithBytes:scalars
                                              length:sizeof(scalars)
                                            encoding:NSUTF32LittleEndianStringEncoding];
    return flag;
}

- (UIImage *)imageFromEmoji:(NSString *)emoji size:(CGFloat)size {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    label.text = emoji;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:size];

    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 0.0);
    [label.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id option = (indexPath.row < self.filteredOptions.count)
        ? self.filteredOptions[indexPath.row] : nil;

    PPOptionCell *cell = [self makeCellForTable:tableView reuseId:@"PPOptionCell"];
    BOOL premiumPicker = [self pp_usesPremiumPickerPresentation];
    cell.premiumCardStyleEnabled = premiumPicker;
    cell.preferredHorizontalInset = 0.0;
    cell.isUserOption = self.useUsersOption;
    if (!option) return cell;

    // --- Extract title, subtitle, and image safely ---
    NSString *title = [self displayTextForOption:option] ?: @"";
    NSString *subtitle = @"";
    UIImage *image = nil;
    NSString *imageNamed = nil;
    NSString *imageURLString = nil;
    UIColor *semanticAccentColor = nil;
    BOOL usesFlagImage = NO;
    // ✅ Handle XLFormOptionsObject properly
    if ([option isKindOfClass:[XLFormOptionsObject class]]) {
        XLFormOptionsObject *xlObj = (XLFormOptionsObject *)option;
        if ([xlObj.formValue isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)xlObj.formValue;
            subtitle = dict[@"desc"] ?: @"";
            NSString *imgName = dict[@"image"];
            if (imgName.length > 0)
                image = [UIImage imageNamed:imgName];
        }
    }
    
    
    else if ([option isKindOfClass:[UserModel class]]) {
        cell.isUserOption = YES;
        UserModel *op = (UserModel *)option;
        title = op.UserName;
        subtitle = op.MobileNo ?: op.UserEmail;
        imageURLString = op.UserImageUrl.absoluteString;
    }
    
    else if ([option isKindOfClass:[MainKindsModel class]]) {
        
        MainKindsModel *op = (MainKindsModel *)option;
        title = op.KindName;
        imageURLString = op.KindImageUrl;
    }
    
    
    else if ([option isKindOfClass:[SubKindModel class]]) {
        
        SubKindModel *op = (SubKindModel *)option;
        title = op.SubKindName;
        imageURLString = op.subKindIconUrl;
    }

    else if ([option isKindOfClass:[PPAccessoryCategoryModel class]]) {
        PPAccessoryCategoryModel *op = (PPAccessoryCategoryModel *)option;
        title = [op displayName];
        imageNamed = [self pp_accessoryCategoryIconNameForIdentifier:op.categoryID mainKindID:op.mainKindID];
        semanticAccentColor = [self pp_accessoryCategoryAccentColorForIdentifier:op.categoryID mainKindID:op.mainKindID];
    }
    
    
    else if ([option isKindOfClass:[OptionModel class]]) {
        
        OptionModel *op = (OptionModel *)option;
        title = op.title;
        subtitle = op.subtitle;
        if (PPSelectOptionStringLooksLikeRemoteImageURL(op.imageName)) {
            imageURLString = PPSelectOptionTrimmedString(op.imageName);
        } else {
            imageNamed = op.systemImageName ?: op.imageName;
        }
    }
    else if ([option respondsToSelector:@selector(systemImageName)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *iconName = [option performSelector:@selector(systemImageName)];
#pragma clang diagnostic pop
        if ([iconName isKindOfClass:NSString.class] && iconName.length > 0) {
            imageNamed = iconName;
        }
    }
    
    
    else if ([option isKindOfClass:[CountryCodeModel class]]) {
        
        CountryCodeModel *op = (CountryCodeModel *)option;
        
        
        NSString *flag = [self emojiFlagForCountryCode:op.isoCountryCode];
        NSData *data = [flag dataUsingEncoding:NSUTF8StringEncoding];
        NSLog(@"Flag: %@ (%@)", flag, data);
        title = op.country;
        cell.titleLabel.numberOfLines = 1;
        
        if(flag)
       {
           image = [self imageFromEmoji:flag size:40];
           usesFlagImage = YES;
       }
       

    }


    else if ([option isKindOfClass:[PPAddressModel class]]) {
        
        if ([option respondsToSelector:@selector(UserAbout)]) {
            subtitle = [option performSelector:@selector(UserAbout)] ?: @"";
        }
        
        if ([option respondsToSelector:@selector(UserImageUrl)]) {
            id val = [option performSelector:@selector(UserImageUrl)];
            if ([val isKindOfClass:[NSURL class]]) {
                imageURLString = [(NSURL *)val absoluteString];
            } else if ([val isKindOfClass:[NSString class]]) {
                imageURLString = val;
            }
        }
        
        cell.titleLabel.numberOfLines = 2;
        imageNamed = @"mappin.and.ellipse.circle.fill";

    }

    // Handle CardModel (birds cards — father/mother selection)
    else if ([option respondsToSelector:@selector(RingID)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *ringID = [option performSelector:@selector(RingID)];
#pragma clang diagnostic pop
        title = ringID ?: title;
    }

    // Handle any XLFormOptionObject conformant (subSubKindModel, subKindItemsModel, etc.)
    else if ([option respondsToSelector:@selector(formDisplayText)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        title = [option performSelector:@selector(formDisplayText)] ?: title;
#pragma clang diagnostic pop
    }

    // ✅ Handle NSString option
    else if ([option isKindOfClass:[NSString class]]) {
        subtitle = @"";
    }
    
    


    if (self.optionTitleProvider) {
        NSString *providedTitle = self.optionTitleProvider(option);
        if ([providedTitle isKindOfClass:NSString.class] && providedTitle.length > 0) {
            title = providedTitle;
        }
    }

    // --- Configure cell ---
    BOOL selected = [self pp_isOption:option selectedWithTitle:title];
    if ([option isKindOfClass:[UserModel class]]) {
        [cell configureAsUserDossierWithUser:(UserModel *)option selected:selected];
    } else if ([option isKindOfClass:[OptionModel class]] && (self.presentationStyle == PPSelectOptionPresentationMain || self.usesCompactOptionIcons || !self.showSearchBar)) {
        OptionModel *op = (OptionModel *)option;
        [cell configureAsActionPortalWithTitle:title
                                      subtitle:(op.desc ?: subtitle)
                                      actionID:op.optID
                                    systemIcon:(op.systemImageName ?: op.imageName)
                                   accentColor:self.premiumHeroAccentColor
                                      selected:selected];
    } else if (imageURLString.length > 0) {
        [cell configureWithTitle:title subtitle:subtitle imageUrl:imageURLString];
    } else if (imageNamed.length > 0) {
        if (premiumPicker) {
            [cell configureWithTitle:title
                            subtitle:subtitle
                          imageNamed:imageNamed
                        useSmallIcon:(self.isGenderSelector ||
                                      self.usesCompactOptionIcons ||
                                      semanticAccentColor != nil)
                         accentColor:semanticAccentColor
                            selected:selected];
        } else {
            [cell configureWithTitle:title
                            subtitle:subtitle
                          imageNamed:imageNamed
                        useSmallIcon:(self.isGenderSelector || self.usesCompactOptionIcons)];
        }
    } else {
        [cell configureWithTitle:title subtitle:subtitle image:image];
    }

    if (usesFlagImage) {
        cell.circleImageView.layer.cornerRadius = 0.0;
        cell.circleImageView.layer.masksToBounds = NO;
        cell.circleImageView.clipsToBounds = NO;
        cell.circleImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    if (self.optionCellBackgroundColor) {
        cell.backgroundColor = self.optionCellBackgroundColor;
        cell.contentView.backgroundColor = self.optionCellBackgroundColor;
    }
    if (premiumPicker) {
        [cell setOptionSelected:selected animated:NO];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        [cell setOptionSelected:NO animated:NO];
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    cell.tintColor = AppPrimaryClr;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}


#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    LogCurrentFunc();
    id option = self.filteredOptions[indexPath.row];
    UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
    [feedback selectionChanged];
    if ([option isKindOfClass:[OptionModel class]]) {
        
        if (self.presentationStyle == PPSelectOptionPresentationPush) {
            [self.navigationController popViewControllerAnimated:YES ];
        } else {
            [self dismissViewControllerAnimated:YES completion:^{
                self.onSelectOption(option);
            }];
        }
        return;
    }
    
    NSString *display = [self displayTextForOption:option] ?: @"";
    DLog(@"[PPSelectOption] didSelect option display='%@' index=%ld", display, (long)indexPath.row);

    
    NSString *PPUserTokenID = [self didSelectObjectAndReturnDevID:option];
    DLog(@"[PPSelectOption] didSelectRowAtIndexPath -> extracted PPUserTokenID: %@", PPUserTokenID ?: @"(nil)");
    // keep the original object
    self.selectedOption = option;

    // store **string** into XLForm row.value to avoid XLForm internal string methods crashes
    if (self.rowDescriptor) {
        self.rowDescriptor.value = display;
        DLog(@"[PPSelectOption] rowDescriptor.value set to string '%@'", display);
    } else {
        DLog(@"[PPSelectOption] WARNING: rowDescriptor is nil — caller must set vc.rowDescriptor before presenting");
    }

    // refresh the list (updates checkmarks safely)
    [self.tableView reloadData];

    // fire callback with the real model
    if (self.onSelectOption) {
        DLog(@"[PPSelectOption] calling onSelectOption callback with model: %@", option);
        self.onSelectOption(option);
    }

    // ask parent form to update UI (caller should have set vc.parentForm = self (XLFormViewController))
    [self updateRowValue:display];

    // dismiss/pop
    if (self.presentationStyle == PPSelectOptionPresentationPush) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Search (UISearchBarDelegate)

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    LogCurrentFunc();
    if (searchText.length == 0) {
        self.filteredOptions = self.allOptions ?: @[];
        [self reloadTableViewAnimated];
        [self pp_updatePremiumHeroCountLabel];
        return;
    }

    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(id option, NSDictionary *bindings) {
        NSString *display = [self displayTextForOption:option];
        if (!display) return NO;
        return [display localizedCaseInsensitiveContainsString:searchText];
    }];

    self.filteredOptions = [self.allOptions filteredArrayUsingPredicate:p];
    DLog(@"[PPSelectOption] search text='%@' results=%lu", searchText, (unsigned long)self.filteredOptions.count);
    [self reloadTableViewAnimated];
    [self pp_updatePremiumHeroCountLabel];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Helpers

- (NSString *)displayTextForOption:(id)option {
    if (!option) return @"";
    if (self.optionTitleProvider) {
        NSString *providedTitle = self.optionTitleProvider(option);
        if ([providedTitle isKindOfClass:NSString.class] && providedTitle.length > 0) {
            return providedTitle;
        }
    }
    if ([option isKindOfClass:XLFormOptionsObject.class]) {
        return [(XLFormOptionsObject *)option displayText] ?: @"";
    } else if ([option respondsToSelector:@selector(UserName)] ||
               [option respondsToSelector:@selector(UserEmail)] ||
               [option respondsToSelector:@selector(MobileNo)]) {
        // Try common UserModel properties via selectors to avoid needing header
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *name = nil;
        if ([option respondsToSelector:@selector(UserName)]) name = [option performSelector:@selector(UserName)];
        if (!name && [option respondsToSelector:@selector(UserEmail)]) name = [option performSelector:@selector(UserEmail)];
        if (!name && [option respondsToSelector:@selector(MobileNo)]) name = [option performSelector:@selector(MobileNo)];
#pragma clang diagnostic pop
        return name ?: [option description] ?: @"";
    } else if ([option isKindOfClass:NSString.class]) {
        return (NSString *)option;
    } else if ([option isKindOfClass:PPAddressModel.class]) {
        PPAddressModel *optionPP = (PPAddressModel *)option;
        return optionPP.displayText;
    } else if ([option respondsToSelector:@selector(formDisplayText)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        return [option performSelector:@selector(formDisplayText)] ?: @"";
#pragma clang diagnostic pop
    }
    // fallback
    return [option description] ?: @"";
}

- (BOOL)pp_isOption:(id)option selectedWithTitle:(NSString *)title {
    id currentValue = self.rowDescriptor ? self.rowDescriptor.value : nil;
    if (currentValue && [currentValue isKindOfClass:[NSString class]]) {
        NSString *currentString = (NSString *)currentValue;
        if ([title isEqualToString:currentString]) return YES;
        if ([option isKindOfClass:[PPAccessoryCategoryModel class]]) {
            PPAccessoryCategoryModel *category = (PPAccessoryCategoryModel *)option;
            return [category.categoryID isEqualToString:currentString] || [category.documentID isEqualToString:currentString];
        }
        return NO;
    }

    if (currentValue != nil) {
        return [currentValue isEqual:option];
    }

    if (!self.selectedOption) return NO;
    if ([self.selectedOption isEqual:option]) return YES;

    if ([option isKindOfClass:[PPAccessoryCategoryModel class]] &&
        [self.selectedOption isKindOfClass:[PPAccessoryCategoryModel class]]) {
        PPAccessoryCategoryModel *left = (PPAccessoryCategoryModel *)option;
        PPAccessoryCategoryModel *right = (PPAccessoryCategoryModel *)self.selectedOption;
        if (left.categoryID.length && [left.categoryID isEqualToString:right.categoryID]) return YES;
        if (left.documentID.length && [left.documentID isEqualToString:right.documentID]) return YES;
    }

    return NO;
}

- (NSString *)pp_accessoryCategoryIconNameForIdentifier:(NSString *)identifier mainKindID:(NSInteger)mainKindID {
    NSString *key = [[identifier ?: @"" lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@"_"];

    if ([key containsString:@"track"]) return @"location.north.line.fill";
    if ([key containsString:@"glove"]) return @"hand.raised.fill";
    if ([key containsString:@"hood"]) return @"eye.slash.fill";
    if ([key containsString:@"jess"] || [key containsString:@"collar"] || [key containsString:@"halter"]) return @"link.circle.fill";
    if ([key containsString:@"perch"] || [key containsString:@"stand"]) return @"rectangle.connected.to.line.below";
    if ([key containsString:@"nest"] || [key containsString:@"bed"]) return @"house.fill";
    if ([key containsString:@"cage"] || [key containsString:@"carrier"]) return @"shippingbox.fill";
    if ([key containsString:@"feeder"] || [key containsString:@"bowl"] || [key isEqualToString:@"food"]) return @"fork.knife";
    if ([key containsString:@"toy"]) return @"sparkles";
    if ([key containsString:@"groom"]) return @"comb.fill";
    if ([key containsString:@"litter"]) return @"tray.fill";
    if ([key containsString:@"aquarium"]) return @"drop.fill";
    if ([key containsString:@"filter"]) return @"line.3.horizontal.decrease.circle.fill";
    if ([key containsString:@"decor"]) return @"paintpalette.fill";
    if ([key containsString:@"light"]) return @"lightbulb.fill";
    if ([key containsString:@"supplement"] || [key containsString:@"nutrition"]) return @"leaf.fill";
    if ([key containsString:@"saddle"]) return @"shield.lefthalf.filled";

    if (mainKindID == 1) return @"bird.fill";
    return @"pawprint.fill";
}

- (UIColor *)pp_accessoryCategoryAccentColorForIdentifier:(NSString *)identifier mainKindID:(NSInteger)mainKindID {
    NSString *key = [[identifier ?: @"" lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@"_"];

    if ([key containsString:@"track"]) return UIColor.systemBlueColor;
    if ([key containsString:@"aquarium"] || [key containsString:@"filter"]) return UIColor.systemTealColor;
    if ([key containsString:@"food"] || [key containsString:@"bowl"] || [key containsString:@"nutrition"] || [key containsString:@"supplement"]) return UIColor.systemGreenColor;
    if ([key containsString:@"toy"] || [key containsString:@"decor"] || [key containsString:@"light"]) return UIColor.systemPurpleColor;
    if ([key containsString:@"glove"] || [key containsString:@"saddle"]) return UIColor.systemBrownColor;
    if ([key containsString:@"hood"] || [key containsString:@"jess"] || [key containsString:@"collar"] || [key containsString:@"halter"]) return UIColor.systemIndigoColor;
    if ([key containsString:@"nest"] || [key containsString:@"bed"] || [key containsString:@"cage"] || [key containsString:@"carrier"]) return UIColor.systemOrangeColor;
    if (mainKindID == 1) return [UIColor colorWithRed:0.08 green:0.68 blue:0.68 alpha:1.0];
    return AppPrimaryClr ?: UIColor.systemPinkColor;
}

- (UIColor *)pp_sheetSurfaceColor {
    return AppForgroundColr ?: UIColor.secondarySystemGroupedBackgroundColor;
}

- (UIColor *)pp_sheetBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:1.0]
                : [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0];
        }];
    }
    UIColor *baseColor = AppBackgroundClr ?: UIColor.systemGroupedBackgroundColor;
    return PPBackgroundColorForIOS26(baseColor) ?: baseColor;
}

- (void)updateRowValue:(id)value {
    LogCurrentFunc();
    if (!self.rowDescriptor) {
        DLog(@"[PPSelectOption] updateRowValue: rowDescriptor missing — cannot update form");
        return;
    }

    // rowDescriptor already updated in selection handler, but keep idempotent
    self.rowDescriptor.value = value;

    // ask parent form to refresh row (caller must set parentForm)
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.parentForm && [self.parentForm respondsToSelector:@selector(updateFormRow:)]) {
            DLog(@"[PPSelectOption] calling parentForm updateFormRow:");
            //[self.parentForm updateFormRow:self.rowDescriptor];
        } else {
            DLog(@"[PPSelectOption] parentForm nil or doesn't respond to updateFormRow:");
        }
    });
}

#pragma mark - Public API helpers (convenience)

- (void)setAllOptions:(NSArray *)allOptions {
    _allOptions = allOptions ?: @[];
    // initialize filtered as well
    self.filteredOptions = _allOptions;
    [self.animatedCellKeys removeAllObjects];
}

#pragma mark - Debugging hints / suggestions

/********** ISSUE CATCHER **********
 If you see crashes like:
  - '-[UserModel rangeOfCharacterFromSet:]: unrecognized selector sent to instance ...'
 It means some XLForm (or your code) attempted to call NSString APIs on `rowDescriptor.value`.
 SUGGESTED SOLUTION:
 1) Always set `rowDescriptor.value` to an NSString (display string or unique ID).
 2) Keep the selected model in `vc.selectedOption` (or in `rowDescriptor.userInfo`).
 3) Caller (XLForm controller) **must** set `vc.rowDescriptor = row; vc.parentForm = self;` before presenting.
 4) If you need to store the actual model in the form, store safely under userInfo or separate property.
 ********** END ISSUE CATCHER **********/

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self pp_usesPremiumPickerPresentation]) {
        if (!PPIOS26())  [Styling applyBackgroundStyleForTableView:tableView cell:cell indexPath:indexPath useRowCardMode:NO];
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) return;

    NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    if ([self.animatedCellKeys containsObject:key]) return;
    [self.animatedCellKeys addObject:key];

    CGFloat delay = MIN(indexPath.row, 8) * 0.025;
    cell.contentView.alpha = 0.0;
    cell.contentView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                                         CGAffineTransformMakeScale(0.985, 0.985));
    [UIView animateWithDuration:0.30
                          delay:delay
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.contentView.alpha = 1.0;
        cell.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}
@end
