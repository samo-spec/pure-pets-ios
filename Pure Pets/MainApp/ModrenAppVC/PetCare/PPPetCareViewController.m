#import "PPPetCareViewController.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "VetManager.h"
#import "VetModel.h"
#import "MainKindsModel.h"
#import "ArabicNormalizer.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "PPNavigationController.h"
#import "PPHomeHelper.h"
#import "UIView+Badge.h"
#import "PPPetCareVetCell.h"

#import "PPPetCareMedicineCell.h"
#import "PPPetCareViewerVC.h"
#import "PPPetCareVetViewrVC.h"

typedef NS_ENUM(NSInteger, PPPetCareMedicineFilter) {
    PPPetCareMedicineFilterAll = 0,
    PPPetCareMedicineFilterOffers,
    PPPetCareMedicineFilterInStock,
    PPPetCareMedicineFilterNew
};

typedef NS_ENUM(NSInteger, PPPetCareVetFilter) {
    PPPetCareVetFilterAll = 0,
    PPPetCareVetFilterWithPhone,
    PPPetCareVetFilterCompany,
    PPPetCareVetFilterPersonal
};



static CGFloat PPPetCareNavigationSegmentWidth(void)
{
    CGFloat screenWidth = CGRectGetWidth(UIScreen.mainScreen.bounds);
    CGFloat availableWidth = screenWidth > 0.0 ? screenWidth - 150.0 : 240.0;
    return floor(MIN(278.0, MAX(224.0, availableWidth)));
}



static UIColor *PPPetCareSearchSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:0.12 alpha:0.86]
                : [UIColor colorWithWhite:1.0 alpha:0.88];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.88];
}

static UIColor *PPPetCareSearchBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.10]
                : [UIColor colorWithWhite:1.0 alpha:0.56];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.56];
}

static NSString *PPPetCareNormalizedText(NSString *value)
{
    NSString *trimmed = [PPPetCareSafeString(value) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }
    NSString *normalized = [ArabicNormalizer normalize:trimmed] ?: trimmed;
    return normalized.lowercaseString;
}




@interface PPPetCareViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, PPUniversalCellDelegate>
@property (nonatomic, assign) PPPetCareInitialSection selectedSection;
@property (nonatomic, assign) PPPetCareMedicineFilter medicineFilter;
@property (nonatomic, assign) PPPetCareVetFilter vetFilter;
@property (nonatomic, strong, nullable) MainKindsModel *selectedMainKind;
@property (nonatomic, copy) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *allMedicines;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *filteredMedicines;
@property (nonatomic, copy) NSArray<VetModel *> *allVets;
@property (nonatomic, copy) NSArray<VetModel *> *filteredVets;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIView *heroFill;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIView *largeOrbView;
@property (nonatomic, strong) UIView *smallOrbView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UISegmentedControl *sectionControl;
@property (nonatomic, strong) UIView *sectionTitleContainer;
@property (nonatomic, strong, nullable) UIButton *navCartButton;
@property (nonatomic, strong) UIView *bottomSearchBarView;
@property (nonatomic, strong) UIView *searchPillView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIImageView *searchIconView;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIView *filterBadgeView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *bottomSearchBarBottomConstraint;
@property (nonatomic, assign) BOOL loadingMedicines;
@property (nonatomic, assign) BOOL loadingVets;
@property (nonatomic, assign) CGFloat keyboardOverlap;
@property (nonatomic, assign) BOOL previousIQKeyboardManagerEnabled;
@property (nonatomic, assign) BOOL previousIQKeyboardToolbarEnabled;
@property (nonatomic, assign) BOOL isOverridingIQKeyboardManager;
- (void)pp_styleNavigationSectionControl;
- (void)pp_installCartNavigationButton;
- (void)pp_updateCartBadge;
- (void)pp_applyKeyboardManagerOverridesIfNeeded;
- (void)pp_restoreKeyboardManagerOverridesIfNeeded;
- (void)pp_presentMedicineDetails:(VetMedicineModel *)medicine;
- (void)pp_presentVetDetails:(VetModel *)vet;
- (void)pp_openPetCareViewer:(UIViewController *)viewer;
@end



@implementation PPPetCareViewController

- (instancetype)initWithInitialSection:(PPPetCareInitialSection)section
                              mainKind:(MainKindsModel *)mainKind
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _selectedSection = section;
    _selectedMainKind = mainKind;
    _medicineFilter = PPPetCareMedicineFilterAll;
    _vetFilter = PPPetCareVetFilterAll;
    _mainKinds = @[];
    _allMedicines = @[];
    _filteredMedicines = @[];
    _allVets = @[];
    _filteredVets = @[];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_applyKeyboardManagerOverridesIfNeeded];
    self.view.backgroundColor = UIColor.secondarySystemBackgroundColor;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:nil//PPPetCareLocalized(@"pet_care_title", @"Pet Care")
                    showBack:YES];
    [self pp_setupViews];
    [self pp_installCartNavigationButton];
    [self pp_loadFilters];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
    [self pp_loadData];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleCartUpdated:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
}

- (void)dealloc
{
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_applyKeyboardManagerOverridesIfNeeded];
    [self pp_installNavigationTitleControl];
    [self pp_installCartNavigationButton];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
    [self pp_updateCartBadge];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.searchField resignFirstResponder];
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyTheme];
            [self.collectionView reloadData];
        }
    }
}

- (void)pp_appWillEnterForeground
{
    [self pp_applyTheme];
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
    [self.collectionView.visibleCells makeObjectsPerformSelector:@selector(setNeedsLayout)];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (self.heroGradientLayer && self.heroFill) {
        self.heroGradientLayer.frame = self.heroFill.bounds;
        self.heroGradientLayer.cornerRadius = self.heroFill.layer.cornerRadius;
    }
    if (self.heroView) {
        self.heroView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroView.bounds cornerRadius:self.heroView.layer.cornerRadius].CGPath;
    }
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
}

#pragma mark - Setup

- (void)pp_setupViews
{
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:contentView];

    _heroView = [[UIView alloc] init];
    _heroView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroView.layer.cornerRadius = 32.0;
    _heroView.layer.borderWidth = 0.8;
    _heroView.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _heroView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _heroView.layer.shadowRadius = 24.0;
    _heroView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [contentView addSubview:_heroView];

    _heroFill = [[UIView alloc] init];
    _heroFill.translatesAutoresizingMaskIntoConstraints = NO;
    _heroFill.layer.cornerRadius = 32.0;
    _heroFill.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _heroFill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_heroFill];

    _heroGradientLayer = [CAGradientLayer layer];
    _heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_heroFill.layer insertSublayer:_heroGradientLayer atIndex:0];

    _largeOrbView = [[UIView alloc] init];
    _largeOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _largeOrbView.layer.cornerRadius = 60.0;
    [_heroFill addSubview:_largeOrbView];

    _smallOrbView = [[UIView alloc] init];
    _smallOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _smallOrbView.layer.cornerRadius = 24.0;
    [_heroFill addSubview:_smallOrbView];

    _iconPlateView = [[UIView alloc] init];
    _iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconPlateView.layer.cornerRadius = 24.0;
    _iconPlateView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_iconPlateView];

    _heroIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"cross.case.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconPlateView addSubview:_heroIconView];

    _eyebrowLabel = [[UILabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _eyebrowLabel.numberOfLines = 1;
    [_heroView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:26.0] ?: [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.78;
    [_heroView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    _subtitleLabel.numberOfLines = 2;
    [_heroView addSubview:_subtitleLabel];

    _counterLabel = [[UILabel alloc] init];
    _counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _counterLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    _counterLabel.layer.cornerRadius = 14.0;
    _counterLabel.layer.masksToBounds = YES;
    _counterLabel.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _counterLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_counterLabel];

    _sectionControl = [[UISegmentedControl alloc] initWithItems:@[@"", @""]];
    _sectionControl.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    [_sectionControl addTarget:self action:@selector(pp_sectionChanged:) forControlEvents:UIControlEventValueChanged];
    [self pp_installNavigationTitleControl];

    _bottomSearchBarView = [[UIView alloc] init];
    _bottomSearchBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomSearchBarView.backgroundColor = UIColor.clearColor;
    _bottomSearchBarView.layer.shadowRadius = 22.0;
    _bottomSearchBarView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    _bottomSearchBarView.layer.shadowOpacity = 0.14;
    [_bottomSearchBarView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    [contentView addSubview:_bottomSearchBarView];

    _searchPillView = [[UIView alloc] init];
    _searchPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchPillView.layer.cornerRadius = 28.0;
    _searchPillView.layer.borderWidth = 0.7;
    _searchPillView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _searchPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_bottomSearchBarView addSubview:_searchPillView];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *searchMaterial =
            [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        searchMaterial.translatesAutoresizingMaskIntoConstraints = NO;
        searchMaterial.userInteractionEnabled = NO;
        [_searchPillView addSubview:searchMaterial];
        [NSLayoutConstraint activateConstraints:@[
            [searchMaterial.topAnchor constraintEqualToAnchor:_searchPillView.topAnchor],
            [searchMaterial.leadingAnchor constraintEqualToAnchor:_searchPillView.leadingAnchor],
            [searchMaterial.trailingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor],
            [searchMaterial.bottomAnchor constraintEqualToAnchor:_searchPillView.bottomAnchor]
        ]];
    }

    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.delegate = self;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.backgroundColor = UIColor.clearColor;
    _searchField.leftViewMode = UITextFieldViewModeNever;
    _searchField.inputAccessoryView = nil;
    if (@available(iOS 9.0, *)) {
        _searchField.inputAssistantItem.leadingBarButtonGroups = @[];
        _searchField.inputAssistantItem.trailingBarButtonGroups = @[];
    }
    _searchField.font = [GM MidFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    [_searchField addTarget:self action:@selector(pp_searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [_searchPillView addSubview:_searchField];

    _searchIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchIconView.tintColor = PPPetCareSecondaryTextColor();
    _searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    _searchIconView.isAccessibilityElement = NO;
    [_searchPillView addSubview:_searchIconView];

    _filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    _filterButton.layer.cornerRadius = 24.0;
    _filterButton.layer.borderWidth = 1.0;
    _filterButton.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _filterButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_filterButton setImage:[[UIImage systemImageNamed:@"slider.horizontal.3"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _filterButton.accessibilityLabel = PPPetCareLocalized(@"pet_care_filter_by", @"Filter By");
    if (@available(iOS 14.0, *)) {
        _filterButton.showsMenuAsPrimaryAction = YES;
    }
    [_bottomSearchBarView addSubview:_filterButton];

    _filterBadgeView = [[UIView alloc] init];
    _filterBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _filterBadgeView.backgroundColor = [UIColor systemRedColor];
    _filterBadgeView.layer.cornerRadius = 4.5;
    _filterBadgeView.layer.masksToBounds = YES;
    _filterBadgeView.layer.borderWidth = 1.5;
    _filterBadgeView.layer.borderColor = UIColor.whiteColor.CGColor;
    _filterBadgeView.hidden = YES;
    _filterBadgeView.userInteractionEnabled = NO;
    [_filterButton addSubview:_filterBadgeView];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 12.0;
    layout.minimumInteritemSpacing = 12.0;
    layout.sectionInset = UIEdgeInsetsMake(6.0, 18.0, 24.0, 18.0);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [_collectionView registerClass:PPPetCareMedicineCell.class forCellWithReuseIdentifier:PPPetCareMedicineCellID];
    [_collectionView registerClass:PPPetCareVetCell.class forCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier];
    [contentView addSubview:_collectionView];

    _emptyView = [[UIView alloc] init];
    _emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyView.userInteractionEnabled = NO;
    _emptyView.hidden = YES;

    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"heart.text.square.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.72];
    [_emptyView addSubview:emptyIcon];

    _emptyTitleLabel = [[UILabel alloc] init];
    _emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyTitleLabel.font = [GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _emptyTitleLabel.textColor = PPPetCareTextColor();
    _emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptyTitleLabel.numberOfLines = 2;
    [_emptyView addSubview:_emptyTitleLabel];

    _emptySubtitleLabel = [[UILabel alloc] init];
    _emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptySubtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _emptySubtitleLabel.textColor = PPPetCareSecondaryTextColor();
    _emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptySubtitleLabel.numberOfLines = 3;
    [_emptyView addSubview:_emptySubtitleLabel];
    [contentView addSubview:_emptyView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.bottomSearchBarBottomConstraint =
        [_bottomSearchBarView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_heroFill.topAnchor constraintEqualToAnchor:_heroView.topAnchor],
        [_heroFill.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor],
        [_heroFill.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor],
        [_heroFill.bottomAnchor constraintEqualToAnchor:_heroView.bottomAnchor],

        [_heroView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12.0],
        [_heroView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_heroView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        [_heroView.heightAnchor constraintEqualToConstant:162.0],

        [_largeOrbView.widthAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.heightAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.trailingAnchor constraintEqualToAnchor:_heroFill.trailingAnchor constant:24.0],
        [_largeOrbView.topAnchor constraintEqualToAnchor:_heroFill.topAnchor constant:-24.0],

        [_smallOrbView.widthAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.heightAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.leadingAnchor constraintEqualToAnchor:_heroFill.leadingAnchor constant:30.0],
        [_smallOrbView.bottomAnchor constraintEqualToAnchor:_heroFill.bottomAnchor constant:16.0],

        [_iconPlateView.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-18.0],
        [_iconPlateView.topAnchor constraintEqualToAnchor:_heroView.topAnchor constant:18.0],
        [_iconPlateView.widthAnchor constraintEqualToConstant:48.0],
        [_iconPlateView.heightAnchor constraintEqualToConstant:48.0],

        [_heroIconView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
        [_heroIconView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
        [_heroIconView.widthAnchor constraintEqualToConstant:22.0],
        [_heroIconView.heightAnchor constraintEqualToConstant:22.0],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor constant:20.0],
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_heroView.topAnchor constant:18.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:8.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-20.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],

        [_counterLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_counterLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:12.0],
        [_counterLabel.heightAnchor constraintEqualToConstant:28.0],
        [_counterLabel.widthAnchor constraintGreaterThanOrEqualToConstant:76.0],

        [_collectionView.topAnchor constraintEqualToAnchor:_heroView.bottomAnchor constant:14.0],
        [_collectionView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],

        [_bottomSearchBarView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_bottomSearchBarView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        self.bottomSearchBarBottomConstraint,
        [_bottomSearchBarView.heightAnchor constraintEqualToConstant:64.0],

        [_searchPillView.leadingAnchor constraintEqualToAnchor:_bottomSearchBarView.leadingAnchor],
        [_searchPillView.centerYAnchor constraintEqualToAnchor:_bottomSearchBarView.centerYAnchor],
        [_searchPillView.heightAnchor constraintEqualToConstant:56.0],

        [_filterButton.leadingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor constant:10.0],
        [_filterButton.trailingAnchor constraintEqualToAnchor:_bottomSearchBarView.trailingAnchor],
        [_filterButton.centerYAnchor constraintEqualToAnchor:_bottomSearchBarView.centerYAnchor],
        [_filterButton.heightAnchor constraintEqualToConstant:56.0],
        [_filterButton.widthAnchor constraintEqualToConstant:56.0],

        [_filterBadgeView.topAnchor constraintEqualToAnchor:_filterButton.topAnchor constant:14.0],
        [_filterBadgeView.trailingAnchor constraintEqualToAnchor:_filterButton.trailingAnchor constant:-14.0],
        [_filterBadgeView.widthAnchor constraintEqualToConstant:9.0],
        [_filterBadgeView.heightAnchor constraintEqualToConstant:9.0],

        [_searchField.topAnchor constraintEqualToAnchor:_searchPillView.topAnchor],
        [_searchField.leadingAnchor constraintEqualToAnchor:_searchPillView.leadingAnchor constant:18.0],
        [_searchField.trailingAnchor constraintEqualToAnchor:_searchIconView.leadingAnchor constant:-10.0],
        [_searchField.bottomAnchor constraintEqualToAnchor:_searchPillView.bottomAnchor],

        [_searchIconView.trailingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor constant:-18.0],
        [_searchIconView.centerYAnchor constraintEqualToAnchor:_searchPillView.centerYAnchor],
        [_searchIconView.widthAnchor constraintEqualToConstant:20.0],
        [_searchIconView.heightAnchor constraintEqualToConstant:20.0],

        [_emptyView.centerXAnchor constraintEqualToAnchor:_collectionView.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:_collectionView.centerYAnchor constant:-20.0],
        [_emptyView.leadingAnchor constraintGreaterThanOrEqualToAnchor:_collectionView.leadingAnchor constant:36.0],
        [_emptyView.trailingAnchor constraintLessThanOrEqualToAnchor:_collectionView.trailingAnchor constant:-36.0],

        [emptyIcon.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [emptyIcon.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:38.0],
        [emptyIcon.heightAnchor constraintEqualToConstant:38.0],

        [_emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:12.0],
        [_emptyTitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptyTitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],

        [_emptySubtitleLabel.topAnchor constraintEqualToAnchor:_emptyTitleLabel.bottomAnchor constant:7.0],
        [_emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],
        [_emptySubtitleLabel.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor],
    ]];

    [contentView bringSubviewToFront:_bottomSearchBarView];
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
}

#pragma mark - Navigation And Bottom Search

- (void)pp_applyKeyboardManagerOverridesIfNeeded
{
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    if (!self.isOverridingIQKeyboardManager) {
        self.previousIQKeyboardManagerEnabled = manager.enable;
        self.previousIQKeyboardToolbarEnabled = manager.enableAutoToolbar;
        self.isOverridingIQKeyboardManager = YES;
    }

    manager.enable = NO;
    manager.enableAutoToolbar = NO;
    self.searchField.inputAccessoryView = nil;
    [self.searchField reloadInputViews];
}

- (void)pp_restoreKeyboardManagerOverridesIfNeeded
{
    if (!self.isOverridingIQKeyboardManager) {
        return;
    }

    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    manager.enable = self.previousIQKeyboardManagerEnabled;
    manager.enableAutoToolbar = self.previousIQKeyboardToolbarEnabled;
    self.isOverridingIQKeyboardManager = NO;
}

- (void)pp_installNavigationTitleControl
{
    if (!self.sectionControl) {
        return;
    }

    CGFloat segmentWidth = PPPetCareNavigationSegmentWidth();
    CGFloat segmentHeight = 34.0;
    if (!self.sectionTitleContainer) {
        self.sectionTitleContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, segmentWidth, segmentHeight)];
        [self.sectionTitleContainer addSubview:self.sectionControl];
        [NSLayoutConstraint activateConstraints:@[
            [self.sectionControl.topAnchor constraintEqualToAnchor:self.sectionTitleContainer.topAnchor],
            [self.sectionControl.leadingAnchor constraintEqualToAnchor:self.sectionTitleContainer.leadingAnchor],
            [self.sectionControl.trailingAnchor constraintEqualToAnchor:self.sectionTitleContainer.trailingAnchor],
            [self.sectionControl.bottomAnchor constraintEqualToAnchor:self.sectionTitleContainer.bottomAnchor]
        ]];
    }
    self.sectionTitleContainer.frame = CGRectMake(0.0, 0.0, segmentWidth, segmentHeight);
    self.sectionTitleContainer.bounds = CGRectMake(0.0, 0.0, segmentWidth, segmentHeight);

    self.navigationItem.title = nil;
    self.navigationItem.hidesBackButton = NO;
    if (self.navigationItem.titleView != self.sectionTitleContainer) {
        self.navigationItem.titleView = self.sectionTitleContainer;
    }
    [self pp_styleNavigationSectionControl];
}

- (void)pp_styleNavigationSectionControl
{
    if (!self.sectionControl) {
        return;
    }

    UIFont *normalFont = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    UIFont *selectedFont = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    UIColor *normalColor = PPPetCareSecondaryTextColor();
    UIColor *selectedColor = PPPetCareTextColor();

    [self.sectionControl setTitleTextAttributes:@{
        NSFontAttributeName: normalFont,
        NSForegroundColorAttributeName: normalColor
    } forState:UIControlStateNormal];
    [self.sectionControl setTitleTextAttributes:@{
        NSFontAttributeName: selectedFont,
        NSForegroundColorAttributeName: selectedColor
    } forState:UIControlStateSelected];

    self.sectionControl.backgroundColor = PPPetCareSurfaceColor();
    self.sectionControl.selectedSegmentTintColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.18];
    self.sectionControl.tintColor = PPPetCareAccentColor();
    self.sectionControl.apportionsSegmentWidthsByContent = NO;
}

- (void)pp_installCartNavigationButton
{
    if (self.navCartButton && self.navigationItem.rightBarButtonItem.customView == self.navCartButton) {
        return;
    }

    UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
    [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];
    cartNavBtn.accessibilityLabel = PPPetCareLocalized(@"Cart", @"Cart");

    if (!PPIOS26()) {
        cartNavBtn.backgroundColor = AppForgroundColr;
        cartNavBtn.layer.cornerRadius = 20.0;
        cartNavBtn.clipsToBounds = NO;
        [cartNavBtn.widthAnchor constraintEqualToConstant:40.0].active = YES;
        [cartNavBtn.heightAnchor constraintEqualToConstant:40.0].active = YES;
    }

    self.navCartButton = cartNavBtn;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cartNavBtn];
    [self pp_updateCartBadge];
}

- (NSInteger)pp_currentCartItemCount
{
    return [CartManager.sharedManager totalItemsCount];
}

- (void)pp_updateCartBadge
{
    if (!self.navCartButton) {
        return;
    }

    UIButton *badgeHost = self.navCartButton;
    [badgeHost removeBadge];

    NSInteger count = [self pp_currentCartItemCount];
    if (count <= 0) {
        return;
    }

    NSString *badgeText = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    UIColor *badgeColor = AppPrimaryClr ?: UIColor.systemPinkColor;

    void (^applyBadge)(void) = ^{
        UIButton *host = self.navCartButton;
        if (!host) return;

        [host layoutIfNeeded];
        if (CGRectIsEmpty(host.bounds)) return;

        [host removeBadge];
        [host addBadgeWithContent:badgeText
                       badgeColor:badgeColor
                           offset:CGPointMake(-10.0, 10.0)
                      badgeRadius:9.5];
    };

    applyBadge();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
        applyBadge();
    });
}

- (void)pp_handleCartUpdated:(NSNotification *)notification
{
    (void)notification;
    [self pp_updateCartBadge];
}

- (void)onCartTapped
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    CartViewController *vc = [[CartViewController alloc] init];
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)pp_updateBottomSearchPositionAnimated:(BOOL)animated
                                 notification:(NSNotification *)notification
{
    if (!self.bottomSearchBarBottomConstraint) {
        return;
    }

    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat bottomInset = self.keyboardOverlap > 0.0 ? self.keyboardOverlap + 12.0 : safeBottom + 12.0;
    self.bottomSearchBarBottomConstraint.constant = -bottomInset;
    [self pp_updateCollectionBottomInsets];

    void (^changes)(void) = ^{
        self.bottomSearchBarView.transform = CGAffineTransformIdentity;
        [self.view layoutIfNeeded];
    };

    if (!animated) {
        changes();
        return;
    }

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (duration <= 0.0) {
        duration = 0.28;
    }
    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (curve << 16) | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:changes
                     completion:nil];
}

- (void)pp_updateCollectionBottomInsets
{
    if (!self.collectionView) {
        return;
    }

    CGFloat bottomInset = self.keyboardOverlap > 0.0 ? self.keyboardOverlap + 12.0 : self.view.safeAreaInsets.bottom;
    CGFloat bottomChrome = 92.0 + bottomInset;
    UIEdgeInsets contentInset = self.collectionView.contentInset;
    contentInset.bottom = bottomChrome;
    self.collectionView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.collectionView.scrollIndicatorInsets;
    indicatorInset.bottom = bottomChrome;
    self.collectionView.scrollIndicatorInsets = indicatorInset;
}

- (void)pp_keyboardWillChangeFrame:(NSNotification *)notification
{
    self.navigationItem.hidesBackButton = NO;
    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [self.view convertRect:keyboardEndFrame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrameInView);
    self.keyboardOverlap = MAX(0.0, overlap);
    [self pp_updateBottomSearchPositionAnimated:YES notification:notification];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    self.navigationItem.hidesBackButton = NO;
    self.keyboardOverlap = 0.0;
    [self pp_updateBottomSearchPositionAnimated:YES notification:notification];
}

#pragma mark - Data

- (void)pp_loadFilters
{
    NSArray *kinds = [MKM.MainKindsArray isKindOfClass:NSArray.class] ? MKM.MainKindsArray : @[];
    self.mainKinds = kinds;
    [self pp_updateFilterMenu];
}

- (void)pp_updateFilterMenu
{
    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIAction *> *kindActions = [NSMutableArray array];
        __weak typeof(self) weakSelf = self;

        UIAction *allKindAction = [UIAction actionWithTitle:PPPetCareLocalized(@"pet_care_all_pets", @"All pets") image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            weakSelf.selectedMainKind = nil;
            [weakSelf pp_applyFiltersAndReload];
            [weakSelf pp_updateFilterMenu];
        }];
        allKindAction.state = self.selectedMainKind == nil ? UIMenuElementStateOn : UIMenuElementStateOff;
        [kindActions addObject:allKindAction];

        for (MainKindsModel *kind in self.mainKinds) {
            NSString *title = kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
            UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                weakSelf.selectedMainKind = kind;
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = (self.selectedMainKind && self.selectedMainKind.ID == kind.ID) ? UIMenuElementStateOn : UIMenuElementStateOff;
            [kindActions addObject:action];
        }

        UIMenu *kindMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_kind_filter", @"Pet Kind") image:[UIImage systemImageNamed:@"pawprint.fill"] identifier:nil options:0 children:kindActions];

        NSMutableArray<UIAction *> *modeActions = [NSMutableArray array];
        NSArray<NSDictionary *> *items = self.selectedSection == PPPetCareInitialSectionMedicines
            ? @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareMedicineFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_offers", @"Offers"), @"tag": @(PPPetCareMedicineFilterOffers)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_in_stock", @"In stock"), @"tag": @(PPPetCareMedicineFilterInStock)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_new", @"New"), @"tag": @(PPPetCareMedicineFilterNew)}
            ]
            : @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareVetFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_with_phone", @"Contact ready"), @"tag": @(PPPetCareVetFilterWithPhone)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_clinics", @"Clinics"), @"tag": @(PPPetCareVetFilterCompany)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_doctors", @"Doctors"), @"tag": @(PPPetCareVetFilterPersonal)}
            ];

        for (NSDictionary *item in items) {
            NSInteger tag = [item[@"tag"] integerValue];
            BOOL isSelected = self.selectedSection == PPPetCareInitialSectionMedicines
                ? tag == self.medicineFilter
                : tag == self.vetFilter;

            UIAction *action = [UIAction actionWithTitle:item[@"title"] image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (weakSelf.selectedSection == PPPetCareInitialSectionMedicines) {
                    weakSelf.medicineFilter = (PPPetCareMedicineFilter)tag;
                } else {
                    weakSelf.vetFilter = (PPPetCareVetFilter)tag;
                }
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = isSelected ? UIMenuElementStateOn : UIMenuElementStateOff;
            [modeActions addObject:action];
        }

        UIMenu *modeMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_filter_by", @"Filter By") image:[UIImage systemImageNamed:@"line.3.horizontal.decrease"] identifier:nil options:0 children:modeActions];

        UIMenu *mainMenu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[kindMenu, modeMenu]];
        self.filterButton.menu = mainMenu;
    }
}

- (void)pp_loadData
{
    self.loadingMedicines = YES;
    self.loadingVets = YES;
    [self pp_updateEmptyState];

    __weak typeof(self) weakSelf = self;
    [[VetManager sharedManager] fetchAllPetMedicinesWithCompletion:^(NSArray<VetMedicineModel *> *medicinesArray, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingMedicines = NO;
        NSArray<VetMedicineModel *> *medicines = medicinesArray ?: @[];
        self.allMedicines = [medicines sortedArrayUsingComparator:^NSComparisonResult(VetMedicineModel *a, VetMedicineModel *b) {
            return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
        }];
        [self pp_applyFiltersAndReload];
    }];

    [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> *vetsArray, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingVets = NO;
        NSArray *vets = vetsArray ?: @[];
        self.allVets = [vets sortedArrayUsingComparator:^NSComparisonResult(VetModel *a, VetModel *b) {
            return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
        }];
        [self pp_applyFiltersAndReload];
    }];
}

- (void)pp_applyFiltersAndReload
{
    NSString *query = PPPetCareNormalizedText(self.searchField.text);
    NSInteger kindID = self.selectedMainKind ? self.selectedMainKind.ID : 0;

    BOOL hasActiveFilter = (kindID > 0);
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        hasActiveFilter = hasActiveFilter || (self.medicineFilter != PPPetCareMedicineFilterAll);
    } else {
        hasActiveFilter = hasActiveFilter || (self.vetFilter != PPPetCareVetFilterAll);
    }
    self.filterBadgeView.hidden = !hasActiveFilter;

    NSMutableArray<VetMedicineModel *> *medicines = [NSMutableArray array];
    for (VetMedicineModel *item in self.allMedicines) {
        if (kindID > 0 && ![self pp_animalTypes:item.animalTypes matchMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_medicine:item matchesFilter:self.medicineFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(item.title),
                                                           PPPetCareSafeString(item.title_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [medicines addObject:item];
    }
    self.filteredMedicines = medicines.copy;

    NSMutableArray<VetModel *> *vets = [NSMutableArray array];
    for (VetModel *vet in self.allVets) {
        if (kindID > 0 && ![self pp_vet:vet matchesMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_vet:vet matchesFilter:self.vetFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(vet.title),
                                                           PPPetCareSafeString(vet.name_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [vets addObject:vet];
    }
    self.filteredVets = vets.copy;

    [self.collectionView reloadData];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (BOOL)pp_medicine:(VetMedicineModel *)medicine matchesFilter:(PPPetCareMedicineFilter)filter
{
    if (medicine.isPublished == NO || medicine.isDisabled || medicine.isAvailable == NO) {
        return NO;
    }
    switch (filter) {
        case PPPetCareMedicineFilterOffers:
            return medicine.requiresPrescription == NO;
        case PPPetCareMedicineFilterInStock:
            return medicine.stockQuantity > 0;
        case PPPetCareMedicineFilterNew:
            if (!medicine.createdAt) {
                return YES;
            }
            return [medicine.createdAt timeIntervalSinceNow] >= -(14.0 * 24.0 * 60.0 * 60.0);
        case PPPetCareMedicineFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vet:(VetModel *)vet matchesFilter:(PPPetCareVetFilter)filter
{
    if (vet.isDisabled) {
        return NO;
    }
    if (![self pp_vetIsApprovedForListing:vet]) {
        return NO;
    }
    switch (filter) {
        case PPPetCareVetFilterWithPhone:
            return vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
        case PPPetCareVetFilterCompany:
            return vet.type == VetTypeCompany;
        case PPPetCareVetFilterPersonal:
            return vet.type == VetTypePersonal;
        case PPPetCareVetFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vetIsApprovedForListing:(VetModel *)vet
{
    NSString *verificationStatus = PPPetCareSafeString(vet.verificationStatus).lowercaseString;
    if (verificationStatus.length == 0) {
        return YES;
    }

    static NSSet<NSString *> *approvedStatuses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        approvedStatuses = [NSSet setWithArray:@[@"approved", @"active", @"verified"]];
    });

    return [approvedStatuses containsObject:verificationStatus];
}

- (BOOL)pp_animalTypes:(NSArray<NSString *> *)animalTypes matchMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (animalTypes.count == 0) {
        return YES;
    }

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    if (mainKind.ID > 0) {
        [candidates addObject:[NSString stringWithFormat:@"%ld", (long)mainKind.ID]];
    }
    for (NSString *value in @[PPPetCareSafeString(mainKind.KindName), PPPetCareSafeString(mainKind.KindNameEn), PPPetCareSafeString(mainKind.KindNameAr)]) {
        NSString *normalized = PPPetCareNormalizedText(value);
        if (normalized.length > 0) {
            [candidates addObject:normalized];
        }
    }

    for (NSString *animalType in animalTypes) {
        NSString *normalizedAnimalType = PPPetCareNormalizedText(animalType);
        for (NSString *candidate in candidates) {
            if ([normalizedAnimalType isEqualToString:candidate]) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)pp_vet:(VetModel *)vet matchesMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (vet.animalTypes.count > 0) {
        return [self pp_animalTypes:vet.animalTypes matchMainKind:mainKind];
    }
    return vet.petMainKindID == mainKind.ID;
}

#pragma mark - Localization and Theme

- (void)pp_updateLocalizedText
{
    [self pp_installNavigationTitleControl];
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_medicines", @"Medicines") forSegmentAtIndex:0];
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_veterinarians", @"Veterinarians") forSegmentAtIndex:1];
    self.searchField.placeholder = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_search_medicines", @"Search medicines")
        : PPPetCareLocalized(@"pet_care_search_vets", @"Search veterinarians");
    self.eyebrowLabel.text = PPPetCareLocalized(@"pet_care_eyebrow", @"Premium care");
    self.titleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_title", @"Pet medicines")
        : PPPetCareLocalized(@"pet_care_vets_title", @"Veterinarians");
    self.subtitleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_subtitle", @"Curated treatment, wellness, and care supplies from the shared store catalog.")
        : PPPetCareLocalized(@"pet_care_vets_subtitle", @"Find veterinarians matched to pet kind, contact readiness, and clinic type.");
    self.sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    self.view.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.sectionTitleContainer.semanticContentAttribute = self.view.semanticContentAttribute;
    self.bottomSearchBarView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchPillView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchField.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchIconView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchField.textAlignment = [Language alignmentForCurrentLanguage];
    self.eyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];

    self.heroIconView.image = [[UIImage systemImageNamed:self.selectedSection == PPPetCareInitialSectionMedicines ? @"pills.fill" : @"cross.case.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self pp_updateFilterMenu];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPPetCareAccentColor();
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.heroView.backgroundColor = PPPetCareSurfaceColor();
    [self.heroView pp_setBorderColor:PPPetCareBorderColor()];
    self.heroView.layer.shadowOpacity = dark ? 0.0 : 0.08;

    self.heroGradientLayer.colors = @[
        (id)[accent colorWithAlphaComponent:dark ? 0.20 : 0.13].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    self.largeOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.08];
    self.smallOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.12];

    self.iconPlateView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.11];
    [self.iconPlateView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.16]];
    self.heroIconView.tintColor = accent;

    self.eyebrowLabel.textColor = [accent colorWithAlphaComponent:dark ? 0.92 : 0.82];
    self.titleLabel.textColor = PPPetCareTextColor();
    self.subtitleLabel.textColor = PPPetCareSecondaryTextColor();
    self.counterLabel.textColor = PPPetCareTextColor();
    self.counterLabel.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.15 : 0.09];
    [self.counterLabel pp_setBorderColor:PPPetCareBorderColor()];

    self.bottomSearchBarView.layer.shadowOpacity = dark ? 0.22 : 0.14;
    self.searchPillView.backgroundColor = PPPetCareSearchSurfaceColor();
    [self.searchPillView pp_setBorderColor:PPPetCareSearchBorderColor()];
    self.searchField.textColor = PPPetCareTextColor();
    self.searchField.backgroundColor = UIColor.clearColor;
    self.searchField.tintColor = PPPetCareAccentColor();
    self.searchIconView.tintColor = PPPetCareTextColor();

    self.filterButton.tintColor = PPPetCareTextColor();
    self.filterButton.backgroundColor = PPPetCareSearchSurfaceColor();
    [self.filterButton pp_setBorderColor:PPPetCareSearchBorderColor()];

    self.filterBadgeView.layer.borderColor = self.filterButton.backgroundColor.CGColor;

    [self pp_styleNavigationSectionControl];
}

- (void)pp_updateCounter
{
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines
        ? self.filteredMedicines.count
        : self.filteredVets.count;
    NSString *format = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_count_format", @"%ld medicines")
        : PPPetCareLocalized(@"pet_care_vet_count_format", @"%ld vets");
    self.counterLabel.text = [NSString stringWithFormat:format, (long)count];
}

- (void)pp_updateEmptyState
{
    BOOL isLoading = self.selectedSection == PPPetCareInitialSectionMedicines ? self.loadingMedicines : self.loadingVets;
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines ? self.filteredMedicines.count : self.filteredVets.count;
    self.emptyView.hidden = isLoading || count > 0;
    if (isLoading) {
        return;
    }
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_title", @"No medicines found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_subtitle", @"Try another pet kind, remove filters, or search with a shorter word.");
    } else {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_title", @"No veterinarians found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_subtitle", @"Try all pet kinds, contact-ready filters, or a different search term.");
    }
}

#pragma mark - Actions

- (void)pp_sectionChanged:(UISegmentedControl *)sender
{
    self.selectedSection = sender.selectedSegmentIndex == 1
        ? PPPetCareInitialSectionVeterinarians
        : PPPetCareInitialSectionMedicines;
    [self pp_updateLocalizedText];
    [self pp_applyFiltersAndReload];
}

- (void)pp_kindChipTapped:(UIButton *)sender
{
    if (sender.tag == 0) {
        self.selectedMainKind = nil;
    } else {
        NSInteger index = sender.tag - 1;
        self.selectedMainKind = (index >= 0 && index < self.mainKinds.count) ? self.mainKinds[index] : nil;
    }
    [self pp_applyFiltersAndReload];
    [self pp_updateFilterMenu];
}

- (void)pp_filterChipTapped:(UIButton *)sender
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.medicineFilter = (PPPetCareMedicineFilter)sender.tag;
    } else {
        self.vetFilter = (PPPetCareVetFilter)sender.tag;
    }
    [self pp_applyFiltersAndReload];
    [self pp_updateFilterMenu];
}

- (void)pp_searchTextChanged:(UITextField *)textField
{
    [self pp_applyFiltersAndReload];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        return self.filteredMedicines.count;
    }
    return self.filteredVets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        PPPetCareMedicineCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareMedicineCellID
                                                                                forIndexPath:indexPath];
        if (indexPath.item < self.filteredMedicines.count) {
            VetMedicineModel *medicine = self.filteredMedicines[indexPath.item];
            NSString *mainKindName = self.selectedMainKind ? [self pp_mainKindNameForID:self.selectedMainKind.ID] : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
            [cell configureWithMedicine:medicine mainKindName:mainKindName];
            __weak typeof(self) weakSelf = self;
            cell.onDetailsTap = ^{
                __strong typeof(weakSelf) self = weakSelf;
                [self pp_openObject:medicine];
            };
        }
        return cell;
    }

    PPPetCareVetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier
                                                                       forIndexPath:indexPath];
    if (indexPath.item < self.filteredVets.count) {
        VetModel *vet = self.filteredVets[indexPath.item];
        [cell configureWithVet:vet mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
        __weak typeof(self) weakSelf = self;
        cell.onDetailsTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_openObject:vet];
        };
        cell.onCallTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_callVet:vet];
        };
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = CGRectGetWidth(collectionView.bounds);
    UIEdgeInsets inset = ((UICollectionViewFlowLayout *)collectionViewLayout).sectionInset;
    CGFloat available = width - inset.left - inset.right;
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        BOOL twoColumns = available >= 330.0;
        CGFloat itemWidth = twoColumns ? floor((available - 12.0) / 2.0) : available;
        return CGSizeMake(itemWidth, MAX(294.0, itemWidth * 1.42));
    }
    return CGSizeMake(available, 206.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        if (indexPath.item < self.filteredMedicines.count) {
            [self pp_openObject:self.filteredMedicines[indexPath.item]];
        }
    } else {
        if (indexPath.item < self.filteredVets.count) {
            [self pp_openObject:self.filteredVets[indexPath.item]];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.12 animations:^{
        cell.transform = CGAffineTransformMakeScale(0.985, 0.985);
        cell.alpha = 0.92;
    }];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
}

#pragma mark - Universal Cell

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    [self pp_openObject:universalModel.ModelObject];
}

#pragma mark - Routing

- (void)pp_openObject:(id)object
{
    if (!object) {
        return;
    }
    if ([object isKindOfClass:VetMedicineModel.class]) {
        [self pp_presentMedicineDetails:(VetMedicineModel *)object];
        return;
    }
    if ([object isKindOfClass:VetModel.class]) {
        [self pp_presentVetDetails:(VetModel *)object];
        return;
    }
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:self
                                     routingNav:(PPNavigationController *)self.navigationController];
}

- (void)pp_presentMedicineDetails:(VetMedicineModel *)medicine
{
    NSString *mainKindName = self.selectedMainKind
        ? [self pp_mainKindNameForID:self.selectedMainKind.ID]
        : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    PPPetCareViewerVC *viewer = [[PPPetCareViewerVC alloc] initWithMedicine:medicine
                                                               mainKindName:mainKindName];
    [self pp_openPetCareViewer:viewer];
}

- (void)pp_presentVetDetails:(VetModel *)vet
{
    PPPetCareVetViewrVC *viewer = [[PPPetCareVetViewrVC alloc] initWithVet:vet
                                                              mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
    [self pp_openPetCareViewer:viewer];
}

- (void)pp_openPetCareViewer:(UIViewController *)viewer
{
    if (!viewer) {
        return;
    }
    viewer.hidesBottomBarWhenPushed = YES;
    UINavigationController *nav = self.navigationController;
    if (nav) {
        [nav pushViewController:viewer animated:YES];
        return;
    }

    PPNavigationController *wrapped = [[PPNavigationController alloc] initWithRootViewController:viewer];
    wrapped.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:wrapped animated:YES completion:nil];
}

- (void)pp_callVet:(VetModel *)vet
{
    NSString *rawPhone = vet.phone.length > 0 ? vet.phone : vet.whatsapp;
    if (rawPhone.length == 0) {
        return;
    }

    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    for (NSUInteger idx = 0; idx < rawPhone.length; idx++) {
        unichar ch = [rawPhone characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    if (clean.length == 0) {
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", clean]];
    if (!url) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:url]) {
        [application openURL:url options:@{} completionHandler:nil];
    }
}

- (NSString *)pp_mainKindNameForID:(NSInteger)kindID
{
    if (kindID <= 0) {
        return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    }
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == kindID) {
            return kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
        }
    }
    return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
}

@end
