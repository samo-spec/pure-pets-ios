//
//  PPCompleteProfileVC.m
//  Pure Pets
//

#import "PPCompleteProfileVC.h"
#import "PPPermissionHelper.h"
#import "PPModernAvatarRenderer.h"
#import "PPProfileTextFieldCell.h"
#import "PPProfilePhoneCell.h"
#import "PPProfileTextViewCell.h"
#import "PPProfileSelectorCell.h"
#import "UserModel.h"
#import "UserManager.h"
#import "PPVerificationCodeViewController.h"
#import "CitiesManager.h"
#import "CountryCodeModel.h"
#import "CountryModel.h"
#import "Language.h"

@import FirebaseAuth;
@import FirebaseStorage;
@import PhotosUI;

static inline void PPCompleteProfileDispatchMain(dispatch_block_t block)
{
    dispatch_async(dispatch_get_main_queue(), block);
}

typedef NS_ENUM(NSInteger, PPCompleteProfileSection) {
    PPCompleteProfileSectionIdentity = 0,
    PPCompleteProfileSectionContact,
    PPCompleteProfileSectionBio,
    PPCompleteProfileSectionCount
};

typedef NS_ENUM(NSInteger, PPCompleteProfileIdentityRow) {
    PPCompleteProfileIdentityRowUserName = 0,
    PPCompleteProfileIdentityRowFirstName,
    PPCompleteProfileIdentityRowLastName,
    PPCompleteProfileIdentityRowCount
};

typedef NS_ENUM(NSInteger, PPCompleteProfileContactRow) {
    PPCompleteProfileContactRowCountry = 0,
    PPCompleteProfileContactRowMobile,
    PPCompleteProfileContactRowEmail,
    PPCompleteProfileContactRowCount
};

typedef NS_ENUM(NSInteger, PPCompleteProfileBioRow) {
    PPCompleteProfileBioRowAbout = 0,
    PPCompleteProfileBioRowCount
};

typedef void (^PPCompleteProfileCountrySelection)(CountryCodeModel *country);

static CGFloat const PPCompleteProfilePreferredSheetRatio = 0.89;
static CGFloat const PPCompleteProfileDefaultBottomInset = 24.0;
static CGFloat const PPCompleteProfileAvatarUploadMaxPixel = 1200.0;

static UISemanticContentAttribute PPCompleteProfileCurrentSemanticAttribute(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static NSTextAlignment PPCompleteProfileCurrentTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

@interface PPCompleteProfileCountryPickerController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<CountryCodeModel *> *allCountries;
@property (nonatomic, copy) NSArray<CountryCodeModel *> *filteredCountries;
@property (nonatomic, strong) CountryCodeModel *selectedCountry;
@property (nonatomic, copy) PPCompleteProfileCountrySelection onSelect;
- (instancetype)initWithCountries:(NSArray<CountryCodeModel *> *)countries
                  selectedCountry:(CountryCodeModel *)selectedCountry
                         onSelect:(PPCompleteProfileCountrySelection)onSelect;
@end

@implementation PPCompleteProfileCountryPickerController

- (instancetype)initWithCountries:(NSArray<CountryCodeModel *> *)countries
                  selectedCountry:(CountryCodeModel *)selectedCountry
                         onSelect:(PPCompleteProfileCountrySelection)onSelect
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) {
        return nil;
    }
    _allCountries = [countries copy] ?: @[];
    _filteredCountries = _allCountries;
    _selectedCountry = selectedCountry;
    _onSelect = [onSelect copy];
    return self;
}

- (UIColor *)pp_canvasColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = kLang(@"code_Palce");
    self.view.backgroundColor = [self pp_canvasColor];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 64.0;
    self.tableView.semanticContentAttribute = PPCompleteProfileCurrentSemanticAttribute();

    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:kLang(@"Cancel")
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(pp_cancelTapped)];

    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.placeholder = kLang(@"TapToSelect");
    self.navigationItem.searchController = searchController;
    self.definesPresentationContext = YES;
}

- (void)pp_cancelTapped
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.filteredCountries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"PPCompleteProfileCountryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;
        cell.textLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    }

    CountryCodeModel *country = self.filteredCountries[indexPath.row];
    NSString *name = country.country ?: @"";
    NSString *flag = country.flag ?: @"";
    cell.textLabel.text = flag.length > 0 ? [NSString stringWithFormat:@"%@  %@", flag, name] : name;
    NSArray<NSString *> *detailParts = [@[country.phoneCode ?: @"", country.isoCountryCode ?: @""]
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    cell.detailTextLabel.text = [detailParts componentsJoinedByString:@"  "];
    cell.accessoryType = country.ID == self.selectedCountry.ID ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.semanticContentAttribute = PPCompleteProfileCurrentSemanticAttribute();
    cell.textLabel.textAlignment = PPCompleteProfileCurrentTextAlignment();
    cell.detailTextLabel.textAlignment = PPCompleteProfileCurrentTextAlignment();
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.filteredCountries.count) {
        return;
    }
    CountryCodeModel *country = self.filteredCountries[indexPath.row];
    if (self.onSelect) {
        self.onSelect(country);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *query = [[searchController.searchBar.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (query.length == 0) {
        self.filteredCountries = self.allCountries;
    } else {
        self.filteredCountries = [self.allCountries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(CountryCodeModel *country, NSDictionary<NSString *,id> *bindings) {
            NSString *name = [country.country ?: @"" lowercaseString];
            NSString *phone = [country.phoneCode ?: @"" lowercaseString];
            NSString *iso = [country.isoCountryCode ?: @"" lowercaseString];
            return [name containsString:query] || [phone containsString:query] || [iso containsString:query];
        }]];
    }
    [self.tableView reloadData];
}

@end

@interface PPCompleteProfileVC ()
<
    UIAdaptivePresentationControllerDelegate,
    UITableViewDelegate,
    UITableViewDataSource,
    UITextFieldDelegate,
    UITextViewDelegate
>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;
@property (nonatomic, strong) UIView *topBarView;
@property (nonatomic, strong) UIButton *saveBTN;
@property (nonatomic, strong) UIButton *skipBTN;

@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) UILabel *headerEyebrowLabel;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerHandleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UIView *progressPillView;
@property (nonatomic, strong) UILabel *progressPillLabel;
@property (nonatomic, strong) UIImageView *avatarIMV;
@property (nonatomic, strong) UIButton *addPhotoBtn;
@property (nonatomic, strong) UIImage *avatarPlaceholderImage;
@property (nonatomic, strong) UIImage *pendingAvatarImage;

@property (nonatomic, copy) NSString *draftUserName;
@property (nonatomic, copy) NSString *draftFirstName;
@property (nonatomic, copy) NSString *draftLastName;
@property (nonatomic, copy) NSString *draftUserEmail;
@property (nonatomic, copy) NSString *draftUserAbout;
@property (nonatomic, copy) NSString *draftMobileLocal;

@property (nonatomic, assign) BOOL isSavingProfile;
@property (nonatomic, assign) BOOL didAnimateIntro;
@property (nonatomic, assign) BOOL didManuallySelectCountry;
@property (nonatomic, assign) CGFloat baseBottomContentInset;

@end

@implementation PPCompleteProfileVC

#pragma mark - Initializer

- (instancetype)initWithUser:(UserModel *)user
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _editingUser = user ?: PPCurrentUser;
    return self;
}

- (instancetype)init
{
    NSAssert(NO, @"Use initWithUser: instead");
    return [self initWithUser:nil];
}

#pragma mark - Appearance

- (UIColor *)pp_canvasColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}

- (UIColor *)pp_surfaceColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
}

- (UIColor *)pp_surfaceBorderColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.85 green:0.80 blue:0.78 alpha:0.10];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
    }];
}

- (UIColor *)pp_brandColor
{
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

- (void)pp_applyCanvas
{
    self.view.backgroundColor = [self pp_canvasColor];
    self.view.opaque = YES;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.opaque = NO;
}

- (void)pp_applySheetPresentationIfNeeded
{
    CGFloat targetHeight = floor(UIScreen.mainScreen.bounds.size.height * PPCompleteProfilePreferredSheetRatio);
    self.preferredContentSize = CGSizeMake(CGRectGetWidth(self.view.bounds), targetHeight);

    if (@available(iOS 16.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (!sheet) {
            return;
        }

        UISheetPresentationControllerDetentIdentifier detentIdentifier = @"pp.complete-profile.detent";
        __weak typeof(self) weakSelf = self;
        UISheetPresentationControllerDetent *detent =
        [UISheetPresentationControllerDetent customDetentWithIdentifier:detentIdentifier
                                                               resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            __strong typeof(weakSelf) self = weakSelf;
            CGFloat screenHeight = self.view.window.bounds.size.height > 0.0
                ? self.view.window.bounds.size.height
                : UIScreen.mainScreen.bounds.size.height;
            return MIN(context.maximumDetentValue, floor(screenHeight * PPCompleteProfilePreferredSheetRatio));
        }];
        sheet.detents = @[detent];
        sheet.selectedDetentIdentifier = detentIdentifier;
        sheet.largestUndimmedDetentIdentifier = detentIdentifier;
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 34.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        return;
    }

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 34.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.baseBottomContentInset = PPCompleteProfileDefaultBottomInset;
    self.modalInPresentation = YES;
    self.presentationController.delegate = self;
    self.view.semanticContentAttribute = PPCompleteProfileCurrentSemanticAttribute();
    self.view.clipsToBounds = YES;
    self.view.layer.cornerRadius = 36.0;
    if (@available(iOS 13.0, *)) {
        self.view.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [self pp_prepareDraftState];
    [self pp_applyCanvas];
    [self pp_buildBackdrop];
    [self pp_buildTopBar];
    [self pp_buildTableView];
    [self pp_setupHeaderUI];
    [self pp_updateHeaderContent];
    [self pp_updateProfileProgressUI];
    [self pp_applySheetPresentationIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.view.semanticContentAttribute = PPCompleteProfileCurrentSemanticAttribute();
    self.tableView.semanticContentAttribute = PPCompleteProfileCurrentSemanticAttribute();
    [self pp_applyCanvas];
    [self.tableView reloadData];
    [self pp_registerKeyboardNotifications];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
    [self pp_unregisterKeyboardNotifications];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self pp_updateHeaderLayoutForWidth:CGRectGetWidth(self.tableView.bounds)];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat topGlowWidth = CGRectGetWidth(self.backgroundGlowViewTop.bounds);
    CGFloat bottomGlowWidth = CGRectGetWidth(self.backgroundGlowViewBottom.bounds);
    self.backgroundGlowViewTop.layer.cornerRadius = topGlowWidth * 0.5;
    self.backgroundGlowViewBottom.layer.cornerRadius = bottomGlowWidth * 0.5;

    [self.headerCardView pp_setBorderColor:[self pp_surfaceBorderColor]];
    [self.avatarIMV pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.62]];
    [self.addPhotoBtn pp_setBorderColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:1.0]
            : UIColor.whiteColor;
    }]];

    [self pp_performIntroAnimationIfNeeded];
}

- (void)dealloc
{
    [self pp_unregisterKeyboardNotifications];
}

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController
{
    return NO;
}

#pragma mark - Setup

- (void)pp_buildBackdrop
{
    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [[self pp_brandColor] colorWithAlphaComponent:0.10];
    [topGlow pp_setShadowColor:[[self pp_brandColor] colorWithAlphaComponent:0.50]];
    topGlow.layer.shadowOpacity = 0.12;
    topGlow.layer.shadowRadius = 64.0;
    topGlow.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:topGlow];

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat alpha = tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.05 : 0.08;
        return [UIColor colorWithRed:0.72 green:0.45 blue:0.42 alpha:alpha];
    }];
    [bottomGlow pp_setShadowColor:[UIColor colorWithRed:0.68 green:0.27 blue:0.33 alpha:1.0]];
    bottomGlow.layer.shadowOpacity = 0.08;
    bottomGlow.layer.shadowRadius = 72.0;
    bottomGlow.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:bottomGlow];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-72.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:200.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:200.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0]
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;
}

- (void)pp_buildTopBar
{
    UIView *topBar = [[UIView alloc] init];
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    topBar.backgroundColor = [self pp_surfaceColor];
    topBar.layer.cornerRadius = 28.0;
    topBar.layer.borderWidth = 1.0;
    topBar.layer.masksToBounds = NO;
    [topBar pp_setBorderColor:[self pp_surfaceBorderColor]];
    [topBar pp_setShadowColor:UIColor.blackColor];
    topBar.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.02 : 0.06;
    topBar.layer.shadowRadius = 18.0;
    topBar.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        topBar.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.view addSubview:topBar];
    self.topBarView = topBar;

    UIButton *skipButton = [self pp_actionButtonWithTitle:kLang(@"Skip") systemImageName:@"xmark" filled:NO action:@selector(onDismiss)];
    UIButton *saveButton = [self pp_actionButtonWithTitle:kLang(@"Save") systemImageName:@"checkmark" filled:YES action:@selector(saveTapped)];
    [topBar addSubview:skipButton];
    [topBar addSubview:saveButton];
    self.skipBTN = skipButton;
    self.saveBTN = saveButton;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"Complete_Profile");
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [topBar addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [topBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [topBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [topBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [topBar.heightAnchor constraintEqualToConstant:62.0],

        [skipButton.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:10.0],
        [skipButton.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [skipButton.widthAnchor constraintGreaterThanOrEqualToConstant:104.0],
        [skipButton.heightAnchor constraintEqualToConstant:44.0],

        [saveButton.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-10.0],
        [saveButton.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [saveButton.widthAnchor constraintGreaterThanOrEqualToConstant:104.0],
        [saveButton.heightAnchor constraintEqualToConstant:44.0],

        [titleLabel.centerXAnchor constraintEqualToAnchor:topBar.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:skipButton.trailingAnchor constant:8.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:saveButton.leadingAnchor constant:-8.0]
    ]];
}

- (UIButton *)pp_actionButtonWithTitle:(NSString *)title
                       systemImageName:(NSString *)systemImageName
                                filled:(BOOL)filled
                                action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title ?: @"" forState:UIControlStateNormal];
    UIImage *image = [UIImage systemImageNamed:systemImageName ?: @""];
    [button setImage:image forState:UIControlStateNormal];
    button.titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 22.0;
    button.layer.masksToBounds = NO;
    button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
    button.imageEdgeInsets = UIEdgeInsetsMake(0.0, -3.0, 0.0, 3.0);
    button.titleEdgeInsets = UIEdgeInsetsMake(0.0, 3.0, 0.0, -3.0);
    button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    button.tintColor = filled ? UIColor.whiteColor : [self pp_brandColor];
    [button setTitleColor:(filled ? UIColor.whiteColor : (AppPrimaryTextClr ?: UIColor.labelColor)) forState:UIControlStateNormal];
    button.backgroundColor = filled ? [self pp_brandColor] : [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat alpha = tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.08 : 0.54;
        return [[UIColor whiteColor] colorWithAlphaComponent:alpha];
    }];
    [button pp_setShadowColor:UIColor.blackColor];
    button.layer.shadowOpacity = filled ? 0.12 : 0.0;
    button.layer.shadowRadius = filled ? 16.0 : 0.0;
    button.layer.shadowOffset = CGSizeMake(0.0, filled ? 8.0 : 0.0);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)pp_buildTableView
{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.backgroundColor = UIColor.clearColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.showsHorizontalScrollIndicator = NO;
    tableView.delaysContentTouches = NO;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 84.0;
    tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, self.baseBottomContentInset, 0.0);
    tableView.scrollIndicatorInsets = tableView.contentInset;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    tableView.semanticContentAttribute = PPCompleteProfileCurrentSemanticAttribute();
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }

    [tableView registerClass:PPProfileTextFieldCell.class forCellReuseIdentifier:@"PPProfileTextFieldCell"];
    [tableView registerClass:PPProfilePhoneCell.class forCellReuseIdentifier:@"PPProfilePhoneCell"];
    [tableView registerClass:PPProfileTextViewCell.class forCellReuseIdentifier:@"PPProfileTextViewCell"];
    [tableView registerClass:PPProfileSelectorCell.class forCellReuseIdentifier:@"PPProfileSelectorCell"];

    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.topBarView.bottomAnchor constant:8.0],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.tableView = tableView;
}

- (void)pp_setupHeaderUI
{
    UIView *root = [[UIView alloc] init];
    root.backgroundColor = UIColor.clearColor;
    self.headerRoot = root;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [self pp_surfaceColor];
    cardView.layer.cornerRadius = 34.0;
    cardView.layer.masksToBounds = NO;
    cardView.layer.borderWidth = 1.0;
    [cardView pp_setBorderColor:[self pp_surfaceBorderColor]];
    [cardView pp_setShadowColor:UIColor.blackColor];
    cardView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.03 : 0.08;
    cardView.layer.shadowRadius = 24.0;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [root addSubview:cardView];
    self.headerCardView = cardView;

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.22 green:0.19 blue:0.17 alpha:0.50];
        }
        return [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    }];
    tintView.layer.cornerRadius = 34.0;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = [self pp_brandColor];
    accentBar.layer.cornerRadius = 3.0;
    [cardView addSubview:accentBar];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [[self pp_brandColor] colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = NSTextAlignmentCenter;
    eyebrowLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat alpha = tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 0.74;
        return [[UIColor whiteColor] colorWithAlphaComponent:alpha];
    }];
    eyebrowLabel.layer.cornerRadius = 14.0;
    eyebrowLabel.layer.masksToBounds = YES;
    [cardView addSubview:eyebrowLabel];
    self.headerEyebrowLabel = eyebrowLabel;

    UIView *avatarHalo = [[UIView alloc] init];
    avatarHalo.translatesAutoresizingMaskIntoConstraints = NO;
    avatarHalo.backgroundColor = [[self pp_brandColor] colorWithAlphaComponent:0.12];
    avatarHalo.layer.cornerRadius = 62.0;
    [avatarHalo pp_setShadowColor:[[self pp_brandColor] colorWithAlphaComponent:0.30]];
    avatarHalo.layer.shadowOpacity = 0.12;
    avatarHalo.layer.shadowRadius = 22.0;
    avatarHalo.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [cardView addSubview:avatarHalo];

    self.avatarPlaceholderImage = [PPModernAvatarRenderer avatarImageForName:self.draftUserName ?: self.editingUser.UserName size:108.0];
    UIImageView *avatarView = [[UIImageView alloc] initWithImage:self.avatarPlaceholderImage];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarView.userInteractionEnabled = YES;
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.clipsToBounds = YES;
    avatarView.layer.cornerRadius = 54.0;
    avatarView.layer.borderWidth = 3.0;
    [avatarView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.62]];
    [avatarHalo addSubview:avatarView];
    self.avatarIMV = avatarView;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapAddPhoto)];
    [avatarView addGestureRecognizer:tap];

    UIButton *editBadge = [UIButton buttonWithType:UIButtonTypeSystem];
    editBadge.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cameraConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    [editBadge setImage:[[UIImage systemImageNamed:@"camera.fill" withConfiguration:cameraConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    editBadge.tintColor = UIColor.whiteColor;
    editBadge.backgroundColor = [self pp_brandColor];
    editBadge.layer.cornerRadius = 16.0;
    editBadge.layer.borderWidth = 2.5;
    editBadge.accessibilityLabel = kLang(@"Add_Photo");
    [editBadge addTarget:self action:@selector(didTapAddPhoto) forControlEvents:UIControlEventTouchUpInside];
    [avatarHalo addSubview:editBadge];
    self.addPhotoBtn = editBadge;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 2;
    [cardView addSubview:titleLabel];
    self.headerTitleLabel = titleLabel;

    UILabel *handleLabel = [[UILabel alloc] init];
    handleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    handleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    handleLabel.textColor = UIColor.secondaryLabelColor;
    handleLabel.textAlignment = NSTextAlignmentCenter;
    handleLabel.numberOfLines = 1;
    [cardView addSubview:handleLabel];
    self.headerHandleLabel = handleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.92];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 3;
    [cardView addSubview:subtitleLabel];
    self.headerSubtitleLabel = subtitleLabel;

    UIView *progressPill = [[UIView alloc] init];
    progressPill.translatesAutoresizingMaskIntoConstraints = NO;
    progressPill.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat alpha = tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 0.78;
        return [[UIColor whiteColor] colorWithAlphaComponent:alpha];
    }];
    progressPill.layer.cornerRadius = 17.0;
    progressPill.layer.borderWidth = 1.0;
    [progressPill pp_setBorderColor:[[self pp_brandColor] colorWithAlphaComponent:0.10]];
    progressPill.layer.masksToBounds = YES;
    [cardView addSubview:progressPill];
    self.progressPillView = progressPill;

    UIImageView *progressIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill"]];
    progressIcon.translatesAutoresizingMaskIntoConstraints = NO;
    progressIcon.tintColor = [self pp_brandColor];
    progressIcon.contentMode = UIViewContentModeScaleAspectFit;
    [progressPill addSubview:progressIcon];

    UILabel *progressLabel = [[UILabel alloc] init];
    progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    progressLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    progressLabel.textColor = [[self pp_brandColor] colorWithAlphaComponent:0.92];
    progressLabel.textAlignment = NSTextAlignmentCenter;
    [progressPill addSubview:progressLabel];
    self.progressPillLabel = progressLabel;

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:root.topAnchor constant:10.0],
        [cardView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20.0],
        [cardView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20.0],
        [cardView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-14.0],

        [tintView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:22.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [eyebrowLabel.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [eyebrowLabel.widthAnchor constraintGreaterThanOrEqualToConstant:96.0],
        [eyebrowLabel.heightAnchor constraintEqualToConstant:28.0],

        [avatarHalo.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [avatarHalo.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:20.0],
        [avatarHalo.widthAnchor constraintEqualToConstant:124.0],
        [avatarHalo.heightAnchor constraintEqualToConstant:124.0],

        [avatarView.centerXAnchor constraintEqualToAnchor:avatarHalo.centerXAnchor],
        [avatarView.centerYAnchor constraintEqualToAnchor:avatarHalo.centerYAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:108.0],
        [avatarView.heightAnchor constraintEqualToConstant:108.0],

        [editBadge.widthAnchor constraintEqualToConstant:32.0],
        [editBadge.heightAnchor constraintEqualToConstant:32.0],
        [editBadge.trailingAnchor constraintEqualToAnchor:avatarHalo.trailingAnchor constant:-2.0],
        [editBadge.bottomAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:-2.0],

        [titleLabel.topAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [handleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [handleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [handleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:handleLabel.bottomAnchor constant:10.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:30.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-30.0],

        [progressPill.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:16.0],
        [progressPill.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [progressPill.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],

        [progressIcon.leadingAnchor constraintEqualToAnchor:progressPill.leadingAnchor constant:12.0],
        [progressIcon.centerYAnchor constraintEqualToAnchor:progressPill.centerYAnchor],
        [progressIcon.widthAnchor constraintEqualToConstant:14.0],
        [progressIcon.heightAnchor constraintEqualToConstant:14.0],

        [progressLabel.leadingAnchor constraintEqualToAnchor:progressIcon.trailingAnchor constant:8.0],
        [progressLabel.trailingAnchor constraintEqualToAnchor:progressPill.trailingAnchor constant:-14.0],
        [progressLabel.topAnchor constraintEqualToAnchor:progressPill.topAnchor constant:8.0],
        [progressLabel.bottomAnchor constraintEqualToAnchor:progressPill.bottomAnchor constant:-8.0]
    ]];

    [self pp_refreshAvatarImageView];
    [self pp_updateHeaderLayoutForWidth:CGRectGetWidth(self.view.bounds)];
}

- (void)pp_updateHeaderLayoutForWidth:(CGFloat)width
{
    if (width <= 0.0 || !self.headerRoot) {
        return;
    }

    CGSize targetSize = CGSizeMake(width, UILayoutFittingCompressedSize.height);
    CGSize headerSize = [self.headerRoot systemLayoutSizeFittingSize:targetSize
                                      withHorizontalFittingPriority:UILayoutPriorityRequired
                                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat resolvedHeight = MAX(1.0, ceil(headerSize.height));

    if (fabs(self.headerRoot.frame.size.width - width) > 1.0 ||
        fabs(self.headerRoot.frame.size.height - resolvedHeight) > 1.0) {
        self.headerRoot.frame = CGRectMake(0.0, 0.0, width, resolvedHeight);
        self.tableView.tableHeaderView = self.headerRoot;
    }
}

#pragma mark - Draft State

- (void)pp_prepareDraftState
{
    if (!self.editingUser) {
        self.editingUser = PPCurrentUser;
    }

    self.contriesArray = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    NSString *storedMobile = [self pp_trimmedString:self.editingUser.MobileNo];
    NSString *authMobile = [self pp_trimmedString:[FIRAuth auth].currentUser.phoneNumber];
    NSString *effectiveMobile = storedMobile.length > 0 ? storedMobile : authMobile;

    self.selectedCountry = [self pp_resolveAutomaticCountryFromMobile:effectiveMobile];

    self.draftUserName = [self pp_trimmedString:self.editingUser.UserName];
    self.draftFirstName = [self pp_trimmedString:self.editingUser.FirstName];
    self.draftLastName = [self pp_trimmedString:self.editingUser.LastName];
    self.draftUserEmail = [self pp_trimmedString:self.editingUser.UserEmail];
    if (self.draftUserEmail.length == 0) {
        self.draftUserEmail = [self pp_trimmedString:[FIRAuth auth].currentUser.email];
    }
    self.draftUserAbout = [self pp_trimmedString:self.editingUser.UserAbout];
    if (effectiveMobile.length > 0 && self.selectedCountry.phoneCode.length > 0) {
        self.draftMobileLocal = [self pp_localPhonePartFromE164:effectiveMobile dialCode:self.selectedCountry.phoneCode];
    } else {
        self.draftMobileLocal = effectiveMobile ?: @"";
    }
}

- (void)pp_updateHeaderContent
{
    NSString *firstName = [self pp_trimmedString:self.draftFirstName];
    NSString *lastName = [self pp_trimmedString:self.draftLastName];
    NSArray<NSString *> *nameParts = [@[firstName ?: @"", lastName ?: @""]
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    NSString *fullName = [nameParts componentsJoinedByString:@" "];
    NSString *handle = [self pp_trimmedString:self.draftUserName];

    self.headerEyebrowLabel.text = kLang(@"account");
    self.headerTitleLabel.text = fullName.length > 0 ? fullName : kLang(@"Complete_Profile");
    self.headerHandleLabel.text = handle.length > 0
        ? ([handle hasPrefix:@"@"] ? handle : [@"@" stringByAppendingString:handle])
        : kLang(@"profile_identity_hint");
    self.headerSubtitleLabel.text = kLang(@"auth_complete_profile_subtitle");
    self.headerTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.headerHandleLabel.textAlignment = NSTextAlignmentCenter;
    self.headerSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self pp_refreshAvatarImageView];
}

- (void)pp_refreshAvatarImageView
{
    if (self.pendingAvatarImage) {
        self.avatarIMV.image = self.pendingAvatarImage;
        return;
    }

    NSString *avatarURL = [self pp_trimmedString:self.editingUser.UserImageUrl.absoluteString];
    if (avatarURL.length > 0) {
        [GM setImageFromUrlString:avatarURL
                        imageView:self.avatarIMV
                          phImage:@"person.crop.circle.fill"];
        return;
    }

    self.avatarPlaceholderImage = [PPModernAvatarRenderer avatarImageForName:(self.draftUserName ?: self.editingUser.UserName)
                                                                        size:108.0];
    self.avatarIMV.image = self.avatarPlaceholderImage;
}

- (void)pp_updateProfileProgressUI
{
    NSInteger completed = 0;
    NSInteger total = 6;

    if ([self pp_trimmedString:self.draftUserName].length >= 3) completed += 1;
    if ([self pp_trimmedString:self.draftFirstName].length > 0) completed += 1;
    if ([self pp_trimmedString:self.draftLastName].length > 0) completed += 1;
    if ([self pp_isValidEmail:[[self pp_trimmedString:self.draftUserEmail] lowercaseString]] &&
        [self pp_trimmedString:self.draftUserEmail].length > 0) completed += 1;
    if ([self pp_trimmedString:self.draftMobileLocal].length > 0) completed += 1;
    if (self.selectedCountry.ID > 0) completed += 1;

    self.progressPillLabel.text = [NSString stringWithFormat:kLang(@"auth_profile_progress_format"), (long)completed, (long)total];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return PPCompleteProfileSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case PPCompleteProfileSectionIdentity:
            return PPCompleteProfileIdentityRowCount;
        case PPCompleteProfileSectionContact:
            return PPCompleteProfileContactRowCount;
        case PPCompleteProfileSectionBio:
            return PPCompleteProfileBioRowCount;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPCompleteProfileSectionIdentity) {
        PPProfileTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextFieldCell" forIndexPath:indexPath];
        switch (indexPath.row) {
            case PPCompleteProfileIdentityRowUserName:
                [cell configureWithTitle:kLang(@"UserName_Palce")
                                    text:self.draftUserName
                             placeholder:kLang(@"UserName_Palce")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeNickname
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindUserName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
            case PPCompleteProfileIdentityRowFirstName:
                [cell configureWithTitle:kLang(@"firstName_Palce")
                                    text:self.draftFirstName
                             placeholder:kLang(@"Enter_First_Name")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeGivenName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindFirstName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
            default:
                [cell configureWithTitle:kLang(@"LastName_Palce")
                                    text:self.draftLastName
                             placeholder:kLang(@"Enter_Last_Name")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeFamilyName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindLastName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
        }
        return cell;
    }

    if (indexPath.section == PPCompleteProfileSectionContact) {
        if (indexPath.row == PPCompleteProfileContactRowCountry) {
            PPProfileSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileSelectorCell" forIndexPath:indexPath];
            NSString *countryName = [self pp_trimmedString:self.selectedCountry.country];
            [cell configureWithTitle:kLang(@"code_Palce")
                               value:(countryName.length > 0 ? countryName : kLang(@"TapToSelect"))
                                flag:self.selectedCountry.flag ?: @""];
            return cell;
        }

        if (indexPath.row == PPCompleteProfileContactRowMobile) {
            PPProfilePhoneCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfilePhoneCell" forIndexPath:indexPath];
            [cell configureWithTitle:kLang(@"MobileNo_Palce")
                              prefix:[self pp_trimmedString:self.selectedCountry.phoneCode]
                                text:self.draftMobileLocal
                         placeholder:kLang(@"MobileNo_Palce")
                           fieldKind:PPProfileFieldKindMobile
                              target:self
                              action:@selector(pp_textFieldEditingChanged:)
                            delegate:self];
            return cell;
        }

        PPProfileTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextFieldCell" forIndexPath:indexPath];
        [cell configureWithTitle:kLang(@"UserEmail_Palce")
                            text:self.draftUserEmail
                     placeholder:kLang(@"UserEmail_Palce")
                    keyboardType:UIKeyboardTypeEmailAddress
                 textContentType:UITextContentTypeEmailAddress
                   returnKeyType:UIReturnKeyNext
          autocapitalizationType:UITextAutocapitalizationTypeNone
                       fieldKind:PPProfileFieldKindEmail
                          target:self
                          action:@selector(pp_textFieldEditingChanged:)
                        delegate:self];
        cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        return cell;
    }

    PPProfileTextViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextViewCell" forIndexPath:indexPath];
    [cell configureWithTitle:kLang(@"UserAbout_Palce")
                        text:self.draftUserAbout
                 placeholder:kLang(@"UserAbout_Palce")
                   fieldKind:PPProfileFieldKindAbout
                    delegate:self];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = [self pp_surfaceColor];
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    [cell.contentView pp_setBorderColor:[self pp_surfaceBorderColor]];
    [cell pp_setShadowColor:UIColor.blackColor];
    cell.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.02 : 0.05;
    cell.layer.shadowRadius = 12.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return !self.isSavingProfile;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == PPCompleteProfileSectionContact &&
        indexPath.row == PPCompleteProfileContactRowCountry) {
        [self pp_presentCountryPicker];
        return;
    }

    [self pp_focusFieldAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 73.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.000001;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

- (NSArray<NSString *> *)pp_sectionHeaderContentForSection:(NSInteger)section
{
    switch (section) {
        case PPCompleteProfileSectionIdentity:
            return @[kLang(@"profile_details"), kLang(@"profile_details_hint")];
        case PPCompleteProfileSectionContact:
            return @[kLang(@"contact_and_bio"), kLang(@"contact_and_bio_hint")];
        case PPCompleteProfileSectionBio:
            return @[kLang(@"UserAbout_Palce"), kLang(@"profile_identity_hint")];
        default:
            return @[@"", @""];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSection:section];
    return [self pp_sectionHeaderViewWithTitle:content.firstObject subtitle:content.lastObject];
}

- (UIView *)pp_sectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = [self pp_brandColor];
    accentBar.layer.cornerRadius = 2.0;
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = PPCompleteProfileCurrentTextAlignment();
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = PPCompleteProfileCurrentTextAlignment();
    subtitleLabel.numberOfLines = 2;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [accentBar.widthAnchor constraintEqualToConstant:28.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:9.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-8.0]
    ]];

    return container;
}

#pragma mark - Editing

- (void)pp_textFieldEditingChanged:(UITextField *)textField
{
    NSString *value = textField.text ?: @"";
    switch ((PPProfileFieldKind)textField.tag) {
        case PPProfileFieldKindUserName:
            self.draftUserName = value;
            break;
        case PPProfileFieldKindFirstName:
            self.draftFirstName = value;
            break;
        case PPProfileFieldKindLastName:
            self.draftLastName = value;
            break;
        case PPProfileFieldKindMobile:
            self.draftMobileLocal = value;
            break;
        case PPProfileFieldKindEmail:
            self.draftUserEmail = value;
            break;
        default:
            break;
    }

    [self pp_updateHeaderContent];
    [self pp_updateProfileProgressUI];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if ((PPProfileFieldKind)textView.tag == PPProfileFieldKindAbout) {
        self.draftUserAbout = textView.text ?: @"";
    }

    UIView *view = textView;
    while (view && ![view isKindOfClass:PPProfileTextViewCell.class]) {
        view = view.superview;
    }
    if ([view isKindOfClass:PPProfileTextViewCell.class]) {
        PPProfileTextViewCell *cell = (PPProfileTextViewCell *)view;
        [cell updatePlaceholderVisibility];
        [cell updatePreferredHeight];
    }

    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    switch ((PPProfileFieldKind)textField.tag) {
        case PPProfileFieldKindUserName:
            [self pp_focusFieldKind:PPProfileFieldKindFirstName];
            return NO;
        case PPProfileFieldKindFirstName:
            [self pp_focusFieldKind:PPProfileFieldKindLastName];
            return NO;
        case PPProfileFieldKindLastName:
            [self pp_focusFieldKind:PPProfileFieldKindMobile];
            return NO;
        case PPProfileFieldKindEmail:
            [self pp_focusFieldKind:PPProfileFieldKindAbout];
            return NO;
        default:
            [textField resignFirstResponder];
            return YES;
    }
}

- (NSIndexPath *)pp_indexPathForFieldKind:(PPProfileFieldKind)fieldKind
{
    switch (fieldKind) {
        case PPProfileFieldKindUserName:
            return [NSIndexPath indexPathForRow:PPCompleteProfileIdentityRowUserName inSection:PPCompleteProfileSectionIdentity];
        case PPProfileFieldKindFirstName:
            return [NSIndexPath indexPathForRow:PPCompleteProfileIdentityRowFirstName inSection:PPCompleteProfileSectionIdentity];
        case PPProfileFieldKindLastName:
            return [NSIndexPath indexPathForRow:PPCompleteProfileIdentityRowLastName inSection:PPCompleteProfileSectionIdentity];
        case PPProfileFieldKindMobile:
            return [NSIndexPath indexPathForRow:PPCompleteProfileContactRowMobile inSection:PPCompleteProfileSectionContact];
        case PPProfileFieldKindEmail:
            return [NSIndexPath indexPathForRow:PPCompleteProfileContactRowEmail inSection:PPCompleteProfileSectionContact];
        case PPProfileFieldKindAbout:
            return [NSIndexPath indexPathForRow:PPCompleteProfileBioRowAbout inSection:PPCompleteProfileSectionBio];
        default:
            return nil;
    }
}

- (PPProfileFieldKind)pp_fieldKindForIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPCompleteProfileSectionIdentity) {
        switch (indexPath.row) {
            case PPCompleteProfileIdentityRowUserName:
                return PPProfileFieldKindUserName;
            case PPCompleteProfileIdentityRowFirstName:
                return PPProfileFieldKindFirstName;
            case PPCompleteProfileIdentityRowLastName:
                return PPProfileFieldKindLastName;
            default:
                return 0;
        }
    }

    if (indexPath.section == PPCompleteProfileSectionContact) {
        switch (indexPath.row) {
            case PPCompleteProfileContactRowMobile:
                return PPProfileFieldKindMobile;
            case PPCompleteProfileContactRowEmail:
                return PPProfileFieldKindEmail;
            default:
                return 0;
        }
    }

    if (indexPath.section == PPCompleteProfileSectionBio &&
        indexPath.row == PPCompleteProfileBioRowAbout) {
        return PPProfileFieldKindAbout;
    }

    return 0;
}

- (void)pp_focusFieldAtIndexPath:(NSIndexPath *)indexPath
{
    PPProfileFieldKind fieldKind = [self pp_fieldKindForIndexPath:indexPath];
    if (fieldKind == 0) {
        return;
    }
    [self pp_focusFieldKind:fieldKind];
}

- (void)pp_focusFieldKind:(PPProfileFieldKind)fieldKind
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (!indexPath) {
        return;
    }

    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:PPProfileTextFieldCell.class]) {
            [((PPProfileTextFieldCell *)cell).textField becomeFirstResponder];
        } else if ([cell isKindOfClass:PPProfilePhoneCell.class]) {
            [((PPProfilePhoneCell *)cell).textField becomeFirstResponder];
        } else if ([cell isKindOfClass:PPProfileTextViewCell.class]) {
            [((PPProfileTextViewCell *)cell).textView becomeFirstResponder];
        }
    });
}

#pragma mark - Country Picker

- (void)pp_presentCountryPicker
{
    if (self.contriesArray.count == 0) {
        [self pp_presentAlertWithTitle:kLang(@"PleaseFillFields") message:kLang(@"TapToSelect")];
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPCompleteProfileCountryPickerController *picker =
    [[PPCompleteProfileCountryPickerController alloc] initWithCountries:self.contriesArray
                                                        selectedCountry:self.selectedCountry
                                                               onSelect:^(CountryCodeModel *country) {
        PPCompleteProfileDispatchMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![country isKindOfClass:CountryCodeModel.class]) {
                return;
            }
            self.selectedCountry = country;
            self.didManuallySelectCountry = YES;
            [self.tableView reloadRowsAtIndexPaths:@[
                [NSIndexPath indexPathForRow:PPCompleteProfileContactRowCountry inSection:PPCompleteProfileSectionContact],
                [NSIndexPath indexPathForRow:PPCompleteProfileContactRowMobile inSection:PPCompleteProfileSectionContact]
            ] withRowAnimation:UITableViewRowAnimationNone];
            [self pp_updateProfileProgressUI];
        });
    }];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 28.0;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Save / Validation

- (void)saveTapped
{
    if (self.isSavingProfile) {
        return;
    }

    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        [self pp_presentAlertWithTitle:kLang(@"auth_register_required_title") message:kLang(@"SomethingWentWrong")];
        return;
    }

    [self.view endEditing:YES];

    NSString *firstName = [self pp_trimmedString:self.draftFirstName];
    NSString *lastName = [self pp_trimmedString:self.draftLastName];
    NSString *userName = [self pp_trimmedString:self.draftUserName];
    NSString *userEmail = [[self pp_trimmedString:self.draftUserEmail] lowercaseString];
    NSString *about = [self pp_trimmedString:self.draftUserAbout];
    NSString *mobileInput = [self pp_trimmedString:self.draftMobileLocal];

    if (userEmail.length > 0 && ![self pp_isValidEmail:userEmail]) {
        [self pp_showValidationErrorForField:PPProfileFieldKindEmail subtitle:kLang(@"UserEmail_Palce")];
        return;
    }

    BOOL didProvideMobile = mobileInput.length > 0;
    BOOL shouldResolveCountry = didProvideMobile || self.didManuallySelectCountry || self.editingUser.CountryID > 0;
    CountryCodeModel *country = shouldResolveCountry ? [self pp_validatedCountryForCurrentSelection] : nil;
    NSString *countryDialCode = [self pp_normalizedDialCode:country.phoneCode];
    NSString *countryISOCode = [[self pp_trimmedString:country.isoCountryCode] uppercaseString];
    NSString *normalizedMobile = @"";

    if (didProvideMobile) {
        if (!country || country.ID <= 0 || countryDialCode.length == 0 || countryISOCode.length != 2) {
            [self pp_showCountryValidationError];
            return;
        }

        normalizedMobile = [self pp_normalizedE164FromInput:mobileInput dialCode:countryDialCode];
        if (normalizedMobile.length == 0) {
            [self pp_showValidationErrorForField:PPProfileFieldKindMobile subtitle:kLang(@"MobileNo_Palce")];
            return;
        }

        NSInteger mobileDigitsCount = [[normalizedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""] length];
        if (mobileDigitsCount < 8 || mobileDigitsCount > 15) {
            [self pp_showValidationErrorForField:PPProfileFieldKindMobile subtitle:kLang(@"MobileNo_Palce")];
            return;
        }

        if (![normalizedMobile hasPrefix:countryDialCode]) {
            CountryCodeModel *mobileCountry = [self pp_countryFromStoredMobileNumber:normalizedMobile];
            if (!mobileCountry) {
                [self pp_showCountryValidationError];
                return;
            }
            self.selectedCountry = mobileCountry;
            country = mobileCountry;
            countryDialCode = [self pp_normalizedDialCode:mobileCountry.phoneCode];
            countryISOCode = [[self pp_trimmedString:mobileCountry.isoCountryCode] uppercaseString];
            [self.tableView reloadRowsAtIndexPaths:@[
                [NSIndexPath indexPathForRow:PPCompleteProfileContactRowCountry inSection:PPCompleteProfileSectionContact],
                [NSIndexPath indexPathForRow:PPCompleteProfileContactRowMobile inSection:PPCompleteProfileSectionContact]
            ] withRowAnimation:UITableViewRowAnimationNone];
        }
    } else if (self.didManuallySelectCountry &&
               (!country || country.ID <= 0 || countryDialCode.length == 0 || countryISOCode.length != 2)) {
        [self pp_showCountryValidationError];
        return;
    }

    NSString *currentAuthEmail = [[self pp_trimmedString:authUser.email] lowercaseString];
    BOOL emailDiffersFromAuth = userEmail.length > 0 && currentAuthEmail.length > 0 && ![userEmail isEqualToString:currentAuthEmail];
    if (emailDiffersFromAuth) {
        if ([self pp_authUser:authUser hasProviderID:@"google.com"] ||
            [self pp_authUser:authUser hasProviderID:@"apple.com"]) {
            [self pp_presentAlertWithTitle:kLang(@"UserEmail_Palce") message:kLang(@"profile_email_managed_by_provider")];
            return;
        }
        [self pp_presentAlertWithTitle:kLang(@"UserEmail_Palce") message:kLang(@"profile_email_reauth_required")];
        return;
    }

    NSMutableDictionary<NSString *, id> *updates = [NSMutableDictionary dictionary];
    updates[@"FirstName"] = firstName ?: @"";
    updates[@"LastName"] = lastName ?: @"";
    updates[@"UserAbout"] = about ?: @"";
    updates[@"UserEmail"] = userEmail ?: @"";

    if (userName.length > 0) {
        updates[@"UserName"] = userName;
        updates[FUUpdateKeyDisplayName] = userName;
    }

    if (normalizedMobile.length > 0) {
        updates[@"MobileNo"] = normalizedMobile;
    }

    BOOL shouldPersistCountry = country.ID > 0 && (self.didManuallySelectCountry || self.editingUser.CountryID > 0 || normalizedMobile.length > 0);
    if (shouldPersistCountry) {
        updates[@"CountryID"] = @(country.ID);
        updates[@"CountryName"] = country.country ?: @"";
        updates[@"CountryDialCode"] = countryDialCode;
        updates[@"CountryIsoCode"] = countryISOCode;
    }

    __weak typeof(self) weakSelf = self;
    void (^commitUpdates)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        [self pp_commitProfileUpdates:updates authUID:authUser.uid];
    };

    NSString *existingAuthMobile = [self pp_trimmedString:authUser.phoneNumber];
    BOOL phoneProviderChanged = [self pp_authUser:authUser hasProviderID:@"phone"] &&
                                normalizedMobile.length > 0 &&
                                existingAuthMobile.length > 0 &&
                                ![normalizedMobile isEqualToString:existingAuthMobile];
    if (phoneProviderChanged) {
        [self pp_presentPhoneVerificationForMobile:normalizedMobile completion:^(NSError * _Nullable error) {
            PPCompleteProfileDispatchMain(^{
                if (error) {
                    [weakSelf pp_presentAlertWithTitle:kLang(@"StatusSaveFailed") message:error.localizedDescription ?: kLang(@"SomethingWentWrong")];
                    return;
                }
                commitUpdates();
            });
        }];
        return;
    }

    commitUpdates();
}

- (void)pp_commitProfileUpdates:(NSMutableDictionary<NSString *, id> *)updates authUID:(NSString *)authUID
{
    [self pp_setSaving:YES];
    [PPHUD showLoading:kLang(@"Saving")];

    __weak typeof(self) weakSelf = self;
    void (^performUserUpdate)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [UsrMgr updateCurrentUserProfileWithValues:updates completion:^(NSError * _Nullable error) {
            PPCompleteProfileDispatchMain(^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }
                [self pp_setSaving:NO];
                [PPHUD dismiss];

                if (error) {
                    [self pp_presentAlertWithTitle:kLang(@"StatusSaveFailed")
                                           message:error.localizedDescription.length ? error.localizedDescription : kLang(@"SomethingWentWrong")];
                    return;
                }

                [self pp_applyCommittedUpdates:updates toUser:self.editingUser];
                [UsrMgr reloadCurrentUserWithCompletion:^(UserModel * _Nullable user, NSError * _Nullable reloadError) {
                    PPCompleteProfileDispatchMain(^{
                        UserModel *resolvedUser = user ?: self.editingUser;
                        if (resolvedUser && !reloadError) {
                            [UsrMgr cacheUser:resolvedUser];
                        }
                        if (self.onProfileCompleted) {
                            self.onProfileCompleted(resolvedUser);
                        }
                        [PPHUD showSuccess:kLang(@"Saved")];
                        [self dismissViewControllerAnimated:YES completion:nil];
                    });
                }];
            });
        }];
    };

    if (self.pendingAvatarImage) {
        [self pp_uploadAvatar:self.pendingAvatarImage forUserID:authUID completion:^(NSURL * _Nullable url, NSError * _Nullable error) {
            PPCompleteProfileDispatchMain(^{
                if (url.absoluteString.length > 0) {
                    updates[FUUpdateKeyPhotoURL] = url.absoluteString;
                    updates[@"UserImageUrl"] = url.absoluteString;
                    updates[@"photoURL"] = url.absoluteString;
                } else if (error) {
                    NSLog(@"[PPCompleteProfileVC] Avatar upload failed, continuing profile save: %@", error.localizedDescription);
                }
                performUserUpdate();
            });
        }];
        return;
    }

    performUserUpdate();
}

- (void)pp_applyCommittedUpdates:(NSDictionary<NSString *, id> *)updates toUser:(UserModel *)user
{
    if (!user) {
        return;
    }

    if (updates[@"FirstName"] != nil) {
        user.FirstName = [self pp_trimmedString:updates[@"FirstName"]];
    }
    if (updates[@"LastName"] != nil) {
        user.LastName = [self pp_trimmedString:updates[@"LastName"]];
    }
    if (updates[@"UserName"] != nil) {
        user.UserName = [self pp_trimmedString:updates[@"UserName"]];
    }
    if (updates[@"UserAbout"] != nil) {
        user.UserAbout = [self pp_trimmedString:updates[@"UserAbout"]];
    }
    if (updates[@"UserEmail"] != nil) {
        user.UserEmail = [self pp_trimmedString:updates[@"UserEmail"]];
    }
    if (updates[@"MobileNo"] != nil) {
        user.MobileNo = [self pp_trimmedString:updates[@"MobileNo"]];
    }
    if ([updates[@"CountryID"] respondsToSelector:@selector(integerValue)]) {
        user.CountryID = [updates[@"CountryID"] integerValue];
    }
    NSString *imageURL = [self pp_trimmedString:updates[@"UserImageUrl"]];
    if (imageURL.length > 0) {
        user.UserImageUrl = [NSURL URLWithString:imageURL];
    }
}

- (void)pp_setSaving:(BOOL)isSaving
{
    self.isSavingProfile = isSaving;
    self.tableView.userInteractionEnabled = !isSaving;
    self.saveBTN.enabled = !isSaving;
    self.skipBTN.enabled = !isSaving;
    self.saveBTN.alpha = isSaving ? 0.62 : 1.0;
    self.skipBTN.alpha = isSaving ? 0.62 : 1.0;
}

- (void)pp_showValidationErrorForField:(PPProfileFieldKind)fieldKind subtitle:(NSString *)subtitle
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (indexPath) {
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pp_animateCell:[self.tableView cellForRowAtIndexPath:indexPath]];
        });
    }
    [self pp_presentAlertWithTitle:kLang(@"PleaseFillFields") message:subtitle ?: @""];
}

- (void)pp_showCountryValidationError
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:PPCompleteProfileContactRowCountry inSection:PPCompleteProfileSectionContact];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self pp_animateCell:[self.tableView cellForRowAtIndexPath:indexPath]];
    });
    [self pp_presentAlertWithTitle:kLang(@"PleaseFillFields") message:kLang(@"TapToSelect")];
}

- (void)pp_animateCell:(UITableViewCell *)cell
{
    if (!cell) {
        return;
    }
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values = @[@0, @18, @-18, @9, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.28;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    [cell.layer addAnimation:animation forKey:@"shake"];
}

- (void)pp_presentAlertWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title ?: @""
                                                                   message:message ?: @""
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ok_button")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Avatar Picker

- (void)didTapAddPhoto
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Camera")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self openCamera];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Photo_Library")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self openPhotoPicker];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = self.addPhotoBtn ?: self.avatarIMV;
    sheet.popoverPresentationController.sourceRect = (self.addPhotoBtn ?: self.avatarIMV).bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openPhotoPicker
{
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.filter = [PHPickerFilter imagesFilter];
        config.selectionLimit = 1;

        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
        return;
    }

    [self openLegacyPicker];
}

- (void)openLegacyPicker
{
    [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:self completion:^(BOOL granted) {
        if (!granted) {
            return;
        }

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)openCamera
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        return;
    }

    [PPPermissionHelper requestCameraPermissionFromViewController:self completion:^(BOOL granted) {
        if (!granted) {
            return;
        }
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) {
        return;
    }

    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;
    if ([provider canLoadObjectOfClass:UIImage.class]) {
        __weak typeof(self) weakSelf = self;
        [provider loadObjectOfClass:UIImage.class completionHandler:^(__kindof id<NSItemProviderReading> object, NSError *error) {
            PPCompleteProfileDispatchMain(^{
                __strong typeof(weakSelf) self = weakSelf;
                UIImage *image = [object isKindOfClass:UIImage.class] ? (UIImage *)object : nil;
                [self handlePickedImage:image];
            });
        }];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    UIImage *image = info[UIImagePickerControllerEditedImage];
    if (![self pp_isRenderableAvatarImage:image]) {
        image = info[UIImagePickerControllerOriginalImage];
    }

    [picker dismissViewControllerAnimated:YES completion:^{
        [self handlePickedImage:image];
    }];
}

- (void)handlePickedImage:(UIImage *)image
{
    if (![self pp_isRenderableAvatarImage:image]) {
        return;
    }
    [UIImage pp_presentCircularCropperWithImage:image fromController:self];
}

- (void)cropViewController:(TOCropViewController *)cropViewController
     didCropToCircularImage:(UIImage *)image
                   withRect:(CGRect)cropRect
                      angle:(NSInteger)angle
{
    [self updateAvatar:image];
    [cropViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateAvatar:(UIImage *)image
{
    if (![self pp_isRenderableAvatarImage:image]) {
        return;
    }

    self.pendingAvatarImage = image;
    [UIView transitionWithView:self.avatarIMV
                      duration:0.28
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.avatarIMV.image = image;
        self.avatarIMV.tintColor = nil;
        self.avatarIMV.backgroundColor = UIColor.clearColor;
    } completion:nil];

    [PPFunc triggerLightHaptic];
}

#pragma mark - Upload / Phone Verification

- (void)pp_uploadAvatar:(UIImage *)image
              forUserID:(NSString *)userID
             completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion
{
    if (![self pp_isRenderableAvatarImage:image] || userID.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PPCompleteProfileVC.Avatar"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: kLang(@"SomethingWentWrong")}];
            completion(nil, error);
        }
        return;
    }

    UIImage *uploadImage = [self pp_resizedImageForUpload:image maxPixel:PPCompleteProfileAvatarUploadMaxPixel];
    NSData *jpeg = UIImageJPEGRepresentation(uploadImage, 0.82);
    if (jpeg.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PPCompleteProfileVC.Avatar"
                                                 code:1002
                                             userInfo:@{NSLocalizedDescriptionKey: kLang(@"SomethingWentWrong")}];
            completion(nil, error);
        }
        return;
    }

    NSString *fileName = [NSString stringWithFormat:@"avatar_%lld.jpg", (long long)(NSDate.date.timeIntervalSince1970 * 1000.0)];
    NSString *path = [NSString stringWithFormat:@"UsersImages/%@/%@", userID, fileName];
    FIRStorageReference *storageRef = [[[FIRStorage storage] reference] child:path];
    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"image/jpeg";

    [storageRef putData:jpeg metadata:metadata completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        [storageRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable downloadError) {
            if (completion) {
                completion(URL, downloadError);
            }
        }];
    }];
}

- (void)pp_presentPhoneVerificationForMobile:(NSString *)mobile
                                  completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *safePhone = [self pp_trimmedString:mobile];
    if (safePhone.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PPCompleteProfileVC.Phone"
                                                 code:2001
                                             userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_phone_required_message")}];
            completion(error);
        }
        return;
    }

    [PPHUD showLoading:kLang(@"auth_sending_code_title")];

    __weak typeof(self) weakSelf = self;
    __block NSString *currentVerificationID = @"";
    [[FIRPhoneAuthProvider provider] verifyPhoneNumber:safePhone UIDelegate:nil completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
        PPCompleteProfileDispatchMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            [PPHUD dismiss];
            if (!self) {
                if (completion) {
                    NSError *sessionError = [NSError errorWithDomain:@"PPCompleteProfileVC.Phone"
                                                                code:2002
                                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"SomethingWentWrong")}];
                    completion(sessionError);
                }
                return;
            }

            if (error || verificationID.length == 0) {
                if (completion) {
                    NSError *resolvedError = error ?: [NSError errorWithDomain:@"PPCompleteProfileVC.Phone"
                                                                           code:2003
                                                                       userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_sending_code_failed_title")}];
                    completion(resolvedError);
                }
                return;
            }

            currentVerificationID = verificationID ?: @"";
            [[NSUserDefaults standardUserDefaults] setObject:currentVerificationID forKey:@"authVerificationID"];
            [[NSUserDefaults standardUserDefaults] synchronize];

            PPVerificationCodeViewController *vc = [[PPVerificationCodeViewController alloc] initWithPhone:safePhone];
            __weak PPVerificationCodeViewController *weakVerificationVC = vc;
            vc.onCodeVerificationRequested = ^(NSString *code, PPVerificationCodeCheckCompletion codeCompletion) {
                NSString *verificationIDForCode = currentVerificationID.length
                    ? currentVerificationID
                    : ([[NSUserDefaults standardUserDefaults] stringForKey:@"authVerificationID"] ?: @"");
                if (verificationIDForCode.length == 0) {
                    NSError *missingVerificationError = [NSError errorWithDomain:@"PPCompleteProfileVC.Phone"
                                                                            code:2004
                                                                        userInfo:@{NSLocalizedDescriptionKey: kLang(@"invalid_code_message")}];
                    if (codeCompletion) {
                        codeCompletion(NO, missingVerificationError);
                    }
                    return;
                }

                FIRUser *currentAuthUser = [FIRAuth auth].currentUser;
                if (!currentAuthUser) {
                    NSError *authMissingError = [NSError errorWithDomain:@"PPCompleteProfileVC.Phone"
                                                                    code:2005
                                                                userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_register_required_title")}];
                    if (codeCompletion) {
                        codeCompletion(NO, authMissingError);
                    }
                    return;
                }

                FIRPhoneAuthCredential *credential = [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationIDForCode
                                                                                                  verificationCode:code ?: @""];
                [currentAuthUser updatePhoneNumberCredential:credential completion:^(NSError * _Nullable updateError) {
                    PPCompleteProfileDispatchMain(^{
                        if (updateError) {
                            if (codeCompletion) {
                                codeCompletion(NO, updateError);
                            }
                            return;
                        }

                        if (completion) {
                            completion(nil);
                        }
                        if (codeCompletion) {
                            codeCompletion(YES, nil);
                        }
                        [weakVerificationVC dismissViewControllerAnimated:YES completion:nil];
                    });
                }];
            };

            [self presentViewController:vc animated:YES completion:nil];
        });
    }];
}

#pragma mark - Keyboard

- (void)pp_registerKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)pp_unregisterKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)pp_keyboardWillChangeFrame:(NSNotification *)notification
{
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardInView = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardInView));
    CGFloat bottomInset = self.baseBottomContentInset + MAX(0.0, overlap - self.view.safeAreaInsets.bottom);
    [self pp_animateTableInsets:UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0) notification:notification];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    [self pp_animateTableInsets:UIEdgeInsetsMake(0.0, 0.0, self.baseBottomContentInset, 0.0) notification:notification];
}

- (void)pp_animateTableInsets:(UIEdgeInsets)insets notification:(NSNotification *)notification
{
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = ([notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        self.tableView.contentInset = insets;
        self.tableView.scrollIndicatorInsets = insets;
    } completion:nil];
}

#pragma mark - Helpers

- (CountryCodeModel *)pp_validatedCountryForCurrentSelection
{
    CountryCodeModel *country = self.selectedCountry;
    if (country.ID > 0) {
        return country;
    }
    if (self.editingUser.CountryID > 0) {
        country = [self pp_countryWithID:self.editingUser.CountryID];
    }
    if (!country) {
        country = [self pp_countryWithISOCode:[GM getCurrentCountryFromCarrier]];
    }
    if (!country) {
        country = [self pp_countryWithISOCode:CitiesManager.shared.CurrentCountry.iso];
    }
    if (!country) {
        country = [self pp_countryWithISOCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    }
    return country ?: [self pp_qatarCountry];
}

- (CountryCodeModel *)pp_resolveAutomaticCountryFromMobile:(NSString *)mobile
{
    CountryCodeModel *resolved = nil;
    if (self.editingUser.CountryID > 0) {
        resolved = [self pp_countryWithID:self.editingUser.CountryID];
    }
    if (!resolved) {
        resolved = [self pp_countryFromStoredMobileNumber:mobile];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:[GM getCurrentCountryFromCarrier]];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:CitiesManager.shared.CurrentCountry.iso];
    }
    if (!resolved) {
        resolved = [self pp_countryWithPhoneCode:CitiesManager.shared.CurrentCountry.countryCode];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    }
    return resolved ?: [self pp_qatarCountry];
}

- (CountryCodeModel *)pp_countryWithID:(NSInteger)countryID
{
    if (countryID <= 0) {
        return nil;
    }
    for (CountryCodeModel *country in self.contriesArray ?: @[]) {
        if (country.ID == countryID) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryWithISOCode:(NSString *)isoCode
{
    NSString *trimmedISO = [[self pp_trimmedString:isoCode] uppercaseString];
    if (trimmedISO.length != 2) {
        return nil;
    }
    for (CountryCodeModel *country in self.contriesArray ?: @[]) {
        NSString *candidateISO = [[self pp_trimmedString:country.isoCountryCode] uppercaseString];
        if ([candidateISO isEqualToString:trimmedISO]) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryWithPhoneCode:(NSString *)phoneCode
{
    NSString *normalized = [self pp_normalizedDialCode:phoneCode];
    if (normalized.length == 0) {
        return nil;
    }
    for (CountryCodeModel *country in self.contriesArray ?: @[]) {
        if ([[self pp_normalizedDialCode:country.phoneCode] isEqualToString:normalized]) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryFromStoredMobileNumber:(NSString *)mobile
{
    NSString *trimmed = [self pp_trimmedString:mobile];
    if (trimmed.length == 0 || ![trimmed hasPrefix:@"+"]) {
        return nil;
    }

    CountryCodeModel *best = nil;
    NSUInteger bestLength = 0;
    for (CountryCodeModel *country in self.contriesArray ?: @[]) {
        NSString *dial = [self pp_normalizedDialCode:country.phoneCode];
        if (dial.length == 0) {
            continue;
        }
        if ([trimmed hasPrefix:dial] && dial.length > bestLength) {
            best = country;
            bestLength = dial.length;
        }
    }
    return best;
}

- (CountryCodeModel *)pp_qatarCountry
{
    CountryCodeModel *qatar = [self pp_countryWithISOCode:@"QA"];
    return qatar ?: self.contriesArray.firstObject;
}

- (NSString *)pp_localPhonePartFromE164:(NSString *)mobile dialCode:(NSString *)dialCode
{
    NSString *trimmedMobile = [self pp_trimmedString:mobile];
    NSString *trimmedDialCode = [self pp_normalizedDialCode:dialCode];
    if (trimmedMobile.length == 0 || trimmedDialCode.length == 0) {
        return trimmedMobile;
    }

    NSString *dialDigits = [trimmedDialCode stringByReplacingOccurrencesOfString:@"+" withString:@""];
    NSString *mobileDigits = [[trimmedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""]
        stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (dialDigits.length > 0 && [mobileDigits hasPrefix:dialDigits]) {
        return [mobileDigits substringFromIndex:dialDigits.length];
    }
    return trimmedMobile;
}

- (NSString *)pp_normalizedE164FromInput:(id)input dialCode:(NSString *)dialCode
{
    NSString *raw = [self pp_trimmedString:input];
    if (raw.length == 0) {
        return @"";
    }

    NSString *digits = [self pp_digitsOnlyString:raw];
    if (digits.length == 0) {
        return @"";
    }

    NSString *dialDigits = [[self pp_normalizedDialCode:dialCode] stringByReplacingOccurrencesOfString:@"+" withString:@""];
    if (dialDigits.length > 0) {
        if ([digits hasPrefix:dialDigits] || [raw hasPrefix:@"+"]) {
            return [NSString stringWithFormat:@"+%@", digits];
        }
        return [NSString stringWithFormat:@"+%@%@", dialDigits, digits];
    }
    return [NSString stringWithFormat:@"+%@", digits];
}

- (NSString *)pp_normalizedDialCode:(NSString *)dialCode
{
    NSString *digits = [self pp_digitsOnlyString:dialCode];
    if (digits.length == 0) {
        return @"";
    }
    return [@"+" stringByAppendingString:digits];
}

- (NSString *)pp_digitsOnlyString:(id)value
{
    NSString *raw = [self pp_trimmedString:value];
    if (raw.length == 0) {
        return @"";
    }

    NSMutableString *digits = [NSMutableString string];
    NSCharacterSet *digitSet = NSCharacterSet.decimalDigitCharacterSet;
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar ch = [raw characterAtIndex:i];
        if (ch >= '0' && ch <= '9') {
            [digits appendFormat:@"%c", (char)ch];
            continue;
        }
        if (ch >= 0x0660 && ch <= 0x0669) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x0660))];
            continue;
        }
        if (ch >= 0x06F0 && ch <= 0x06F9) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x06F0))];
            continue;
        }
        if (ch >= 0xFF10 && ch <= 0xFF19) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0xFF10))];
            continue;
        }
        if ([digitSet characterIsMember:ch]) {
            NSString *scalar = [NSString stringWithCharacters:&ch length:1];
            NSInteger numeric = [scalar integerValue];
            if (numeric >= 0 && numeric <= 9) {
                [digits appendFormat:@"%ld", (long)numeric];
            }
        }
    }
    return digits;
}

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (BOOL)pp_isValidEmail:(NSString *)email
{
    if (email.length == 0) {
        return NO;
    }
    NSString *pattern = @"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", pattern];
    return [predicate evaluateWithObject:email];
}

- (BOOL)pp_authUser:(FIRUser *)authUser hasProviderID:(NSString *)providerID
{
    NSString *targetProviderID = [[self pp_trimmedString:providerID] lowercaseString];
    if (!authUser || targetProviderID.length == 0) {
        return NO;
    }

    for (id<FIRUserInfo> provider in authUser.providerData) {
        NSString *candidate = [[self pp_trimmedString:provider.providerID] lowercaseString];
        if ([candidate isEqualToString:targetProviderID]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_isRenderableAvatarImage:(UIImage *)image
{
    return [image isKindOfClass:UIImage.class] &&
           image.size.width > 1.0 &&
           image.size.height > 1.0;
}

- (UIImage *)pp_resizedImageForUpload:(UIImage *)image maxPixel:(CGFloat)maxPixel
{
    if (![self pp_isRenderableAvatarImage:image]) {
        return image;
    }

    CGFloat longestSide = MAX(image.size.width, image.size.height);
    if (longestSide <= maxPixel) {
        return image;
    }

    CGFloat scale = maxPixel / longestSide;
    CGSize targetSize = CGSizeMake(floor(image.size.width * scale), floor(image.size.height * scale));
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:CGRectMake(0.0, 0.0, targetSize.width, targetSize.height)];
    }];
}

- (void)pp_performIntroAnimationIfNeeded
{
    if (self.didAnimateIntro || !self.tableView || !self.topBarView) {
        return;
    }
    self.didAnimateIntro = YES;

    NSArray<UIView *> *views = @[self.topBarView, self.tableView];
    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
        [UIView animateWithDuration:0.55
                              delay:0.05 * idx
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Skip

- (void)onDismiss
{
    [self.view endEditing:YES];
    if (self.onProfileCompleted) {
        self.onProfileCompleted(self.editingUser);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
