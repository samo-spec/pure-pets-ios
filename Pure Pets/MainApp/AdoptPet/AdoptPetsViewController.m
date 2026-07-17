#import "AdoptPetsViewController.h"
#import "AddAdoptPetViewController.h"
#import "PPRolePermission.h"
#import "UserModel.h"
#import "PPSearchFilterView.h"

static NSString * const PPAdoptFilterKindKey = @"kindID";
static NSString * const PPAdoptFilterGenderKey = @"gender";
static NSString * const PPAdoptGenderMaleValue = @"male";
static NSString * const PPAdoptGenderFemaleValue = @"female";

static NSString *PPAdoptNormalizedGenderValue(NSString *gender) {
    if (![gender isKindOfClass:NSString.class]) {
        return @"";
    }

    NSString *normalized = [[gender stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (normalized.length == 0) {
        return @"";
    }

    if ([normalized containsString:@"female"] ||
        [normalized containsString:@"انث"] ||
        [normalized containsString:@"أنث"] ||
        [normalized containsString:@"بنت"]) {
        return PPAdoptGenderFemaleValue;
    }

    if ([normalized containsString:@"male"] ||
        [normalized containsString:@"ذكر"] ||
        [normalized containsString:@"ولد"]) {
        return PPAdoptGenderMaleValue;
    }

    return normalized;
}

@interface AdoptPetsViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PPUniversalCellDelegate, UISearchBarDelegate, PPSearchFilterViewDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<AdoptPetModel *> *items;
@property (nonatomic, strong) NSMutableArray<AdoptPetModel *> *filteredItems;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, strong) UIView *heroHeaderView;
@property (nonatomic, strong) UIView *heroIconPlateView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UILabel *heroCountLabel;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIImageView *emptyStateIconView;
@property (nonatomic, strong) UILabel *emptyStateTitleLabel;
@property (nonatomic, strong) UILabel *emptyStateSubtitleLabel;
@property (nonatomic, strong) UIButton *emptyStateActionButton;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) PPSearchFilterView *filterView;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIView *searchContainer;
@property (nonatomic, strong) UIView *searchSurfaceView;
@property (nonatomic, strong) UIImageView *searchAccentView;
@property (nonatomic, strong) UILabel *filterBadgeLabel;
@property (nonatomic, copy) NSString *filterContentSignature;
@property (nonatomic, strong) NSLayoutConstraint *collectionTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterHeightConstraint;
@property (nonatomic, assign) BOOL isFilterExpanded;
@property (nonatomic, assign) BOOL didAnimateSearchChrome;
@property (nonatomic, assign) BOOL hasReceivedInitialSnapshot;
@property (nonatomic, assign) BOOL isShowingLoadError;
@property (nonatomic, copy) NSString *loadErrorMessage;
@end

@implementation AdoptPetsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = AppBackgroundClr;
    self.items = [NSMutableArray array];
    self.filteredItems = [NSMutableArray array];

    [self pp_setupHeroHeader];
    [self pp_setupSearchBar];
    [self pp_setupCollectionView];
    [self pp_setupEmptyStateLabel];
    [self pp_prepareListEntranceStateIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"AdoptPet") showBack:YES];
    [self pp_updateSearchChromeForCurrentTraits];
    [self pp_prepareListEntranceStateIfNeeded];
    [self startListening];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_animateSearchChromeEntranceIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateCollectionInsetsForBottomBar];
    self.heroHeaderView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroHeaderView.bounds
                                   cornerRadius:self.heroHeaderView.layer.cornerRadius].CGPath;
    self.searchSurfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.searchSurfaceView.bounds
                                   cornerRadius:self.searchSurfaceView.layer.cornerRadius].CGPath;
    self.emptyStateView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.emptyStateView.bounds
                                   cornerRadius:self.emptyStateView.layer.cornerRadius].CGPath;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self pp_stopListening];
}

- (void)dealloc {
    [self pp_stopListening];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_updateSearchChromeForCurrentTraits];
        }
    }
}

#pragma mark - Search Bar

- (void)pp_prepareListEntranceStateIfNeeded {
    if (self.didAnimateSearchChrome || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.heroHeaderView.alpha = 0.0;
    self.heroHeaderView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                CGAffineTransformMakeScale(0.985, 0.985));
    self.searchSurfaceView.alpha = 0.0;
    self.searchSurfaceView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                CGAffineTransformMakeScale(0.985, 0.985));
    self.collectionView.alpha = 0.0;
    self.collectionView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
}

- (void)pp_setupHeroHeader {
    self.heroHeaderView = [[UIView alloc] init];
    self.heroHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroHeaderView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.heroHeaderView.layer.cornerRadius = 28.0;
    self.heroHeaderView.layer.masksToBounds = NO;
    self.heroHeaderView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPApplyContinuousCorners(self.heroHeaderView, 28.0);
    [self.heroHeaderView pp_setShadowColor:UIColor.blackColor];
    self.heroHeaderView.layer.shadowOpacity = 0.045;
    self.heroHeaderView.layer.shadowRadius = 18.0;
    self.heroHeaderView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [self.view addSubview:self.heroHeaderView];

    self.heroIconPlateView = [[UIView alloc] init];
    self.heroIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconPlateView.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.10];
    self.heroIconPlateView.layer.cornerRadius = 22.0;
    self.heroIconPlateView.layer.masksToBounds = YES;
    PPApplyContinuousCorners(self.heroIconPlateView, 22.0);
    [self.heroHeaderView addSubview:self.heroIconPlateView];

    self.heroIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.circle.fill"]];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroIconView.tintColor = GM.appPrimaryColor;
    [self.heroIconPlateView addSubview:self.heroIconView];

    self.heroEyebrowLabel = [[UILabel alloc] init];
    self.heroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroEyebrowLabel.font = [GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    self.heroEyebrowLabel.textColor = [GM.appPrimaryColor colorWithAlphaComponent:0.92];
    self.heroEyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroEyebrowLabel.text = kLang(@"adopt_list_eyebrow");
    [self.heroHeaderView addSubview:self.heroEyebrowLabel];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = [GM boldFontWithSize:24.0] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    self.heroTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleLabel.minimumScaleFactor = 0.82;
    self.heroTitleLabel.text = kLang(@"adopt_list_title");
    [self.heroHeaderView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = [GM MidFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    self.heroSubtitleLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.numberOfLines = 2;
    self.heroSubtitleLabel.text = kLang(@"adopt_list_subtitle");
    [self.heroHeaderView addSubview:self.heroSubtitleLabel];

    self.heroCountLabel = [[UILabel alloc] init];
    self.heroCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCountLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    self.heroCountLabel.textColor = GM.appPrimaryColor;
    self.heroCountLabel.textAlignment = NSTextAlignmentCenter;
    self.heroCountLabel.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.09];
    self.heroCountLabel.layer.cornerRadius = 15.0;
    self.heroCountLabel.layer.masksToBounds = YES;
    NSString *initialCountFormat = kLang(@"adopt_list_count_format");
    if (initialCountFormat.length == 0) {
        initialCountFormat = @"%ld";
    }
    self.heroCountLabel.text = [NSString stringWithFormat:initialCountFormat, (long)0];
    [self.heroHeaderView addSubview:self.heroCountLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroHeaderView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8.0],
        [self.heroHeaderView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.heroHeaderView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [self.heroHeaderView.heightAnchor constraintGreaterThanOrEqualToConstant:116.0],

        [self.heroIconPlateView.leadingAnchor constraintEqualToAnchor:self.heroHeaderView.leadingAnchor constant:16.0],
        [self.heroIconPlateView.topAnchor constraintEqualToAnchor:self.heroHeaderView.topAnchor constant:18.0],
        [self.heroIconPlateView.widthAnchor constraintEqualToConstant:44.0],
        [self.heroIconPlateView.heightAnchor constraintEqualToConstant:44.0],

        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconPlateView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconPlateView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:24.0],
        [self.heroIconView.heightAnchor constraintEqualToConstant:24.0],

        [self.heroEyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroIconPlateView.trailingAnchor constant:12.0],
        [self.heroEyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroCountLabel.leadingAnchor constant:-10.0],
        [self.heroEyebrowLabel.topAnchor constraintEqualToAnchor:self.heroHeaderView.topAnchor constant:18.0],

        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroEyebrowLabel.leadingAnchor],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroHeaderView.trailingAnchor constant:-16.0],
        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:self.heroEyebrowLabel.bottomAnchor constant:4.0],

        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroHeaderView.leadingAnchor constant:16.0],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroHeaderView.trailingAnchor constant:-16.0],
        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroIconPlateView.bottomAnchor constant:14.0],
        [self.heroSubtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroHeaderView.bottomAnchor constant:-16.0],

        [self.heroCountLabel.trailingAnchor constraintEqualToAnchor:self.heroHeaderView.trailingAnchor constant:-16.0],
        [self.heroCountLabel.centerYAnchor constraintEqualToAnchor:self.heroIconPlateView.centerYAnchor],
        [self.heroCountLabel.heightAnchor constraintEqualToConstant:30.0],
        [self.heroCountLabel.widthAnchor constraintGreaterThanOrEqualToConstant:88.0]
    ]];
}

- (void)pp_setupSearchBar {
    self.searchContainer = [[UIView alloc] init];
    self.searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchContainer.backgroundColor = UIColor.clearColor;
    self.searchContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:self.searchContainer];

    self.searchSurfaceView = [[UIView alloc] init];
    self.searchSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchSurfaceView.clipsToBounds = NO;
    self.searchSurfaceView.layer.cornerRadius = 28.0;
    PPApplyContinuousCorners(self.searchSurfaceView, 28.0);
    [self.searchContainer addSubview:self.searchSurfaceView];

    self.searchAccentView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    self.searchAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchAccentView.contentMode = UIViewContentModeScaleAspectFit;
    self.searchAccentView.tintColor = [GM.appPrimaryColor colorWithAlphaComponent:0.92];
    self.searchAccentView.alpha = 0.0;
    [self.searchSurfaceView addSubview:self.searchAccentView];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.backgroundImage = [UIImage new];
    self.searchBar.backgroundColor = UIColor.clearColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.placeholder = kLang(@"SearchPlaceholderModern");
    self.searchBar.delegate = self;
    self.searchBar.searchTextField.backgroundColor = UIColor.clearColor;
    self.searchBar.searchTextField.layer.cornerRadius = 0;
    self.searchBar.searchTextField.layer.masksToBounds = YES;
    self.searchBar.searchTextField.font = [GM MidFontWithSize:15];
    self.searchBar.searchTextField.textColor = AppPrimaryTextClr;
    self.searchBar.searchTextField.tintColor = GM.appPrimaryColor;
    self.searchBar.searchTextField.leftView.tintColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.72];
    [self.searchBar.searchTextField.heightAnchor constraintEqualToConstant:50.0].active = YES;
    self.searchBar.searchTextField.textAlignment = ([Language languageVal] == 0) ? NSTextAlignmentLeft : NSTextAlignmentRight;
    self.searchBar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.searchSurfaceView addSubview:self.searchBar];

    self.filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.filterButton setImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease"] forState:UIControlStateNormal];
    self.filterButton.tintColor = GM.appPrimaryColor;
    self.filterButton.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.10];
    self.filterButton.layer.cornerRadius = 22;
    self.filterButton.layer.masksToBounds = YES;
    self.filterButton.accessibilityLabel = kLang(@"filterPPAction");
    [self.filterButton addTarget:self action:@selector(pp_toggleFilter) forControlEvents:UIControlEventTouchUpInside];
    [self.filterButton addTarget:self action:@selector(pp_filterButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.filterButton addTarget:self action:@selector(pp_filterButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.searchSurfaceView addSubview:self.filterButton];

    self.filterBadgeLabel = [[UILabel alloc] init];
    self.filterBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterBadgeLabel.backgroundColor = GM.appPrimaryColor;
    self.filterBadgeLabel.textColor = UIColor.whiteColor;
    self.filterBadgeLabel.font = [GM boldFontWithSize:10];
    self.filterBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.filterBadgeLabel.layer.cornerRadius = 8.0;
    self.filterBadgeLabel.layer.masksToBounds = YES;
    self.filterBadgeLabel.layer.borderColor = AppPrimaryClr.CGColor;
    self.filterBadgeLabel.layer.borderWidth = 0.8;
    self.filterBadgeLabel.hidden = YES;
    [self.filterButton addSubview:self.filterBadgeLabel];

    self.filterView = [[PPSearchFilterView alloc] init];
    self.filterView.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterView.delegate = self;
    self.filterView.alpha = 0.0;
    self.filterView.hidden = YES;
    self.filterView.transform = CGAffineTransformMakeTranslation(0.0, -8.0);
    [self.view addSubview:self.filterView];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchContainer.topAnchor constraintEqualToAnchor:self.heroHeaderView.bottomAnchor constant:10.0],
        [self.searchContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.searchContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],

        [self.searchSurfaceView.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor],
        [self.searchSurfaceView.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor],
        [self.searchSurfaceView.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor],
        [self.searchSurfaceView.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor],
        [self.searchSurfaceView.heightAnchor constraintEqualToConstant:60.0],

        [self.searchAccentView.leadingAnchor constraintEqualToAnchor:self.searchSurfaceView.leadingAnchor constant:18.0],
        [self.searchAccentView.centerYAnchor constraintEqualToAnchor:self.searchSurfaceView.centerYAnchor],
        [self.searchAccentView.widthAnchor constraintEqualToConstant:22.0],
        [self.searchAccentView.heightAnchor constraintEqualToConstant:22.0],

       


        [self.filterButton.trailingAnchor constraintEqualToAnchor:self.searchSurfaceView.trailingAnchor constant:-8.0],
        [self.filterButton.centerYAnchor constraintEqualToAnchor:self.searchSurfaceView.centerYAnchor],
        [self.filterButton.widthAnchor constraintEqualToConstant:44],
        [self.filterButton.heightAnchor constraintEqualToConstant:44],

        [self.filterBadgeLabel.topAnchor constraintEqualToAnchor:self.filterButton.topAnchor constant:3.0],
        [self.filterBadgeLabel.trailingAnchor constraintEqualToAnchor:self.filterButton.trailingAnchor constant:-3.0],
        [self.filterBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:16.0],
        [self.filterBadgeLabel.heightAnchor constraintEqualToConstant:16.0],
        
        
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.searchSurfaceView.leadingAnchor constant:6.0],
        [self.searchBar.topAnchor constraintEqualToAnchor:self.searchSurfaceView.topAnchor constant:5.0],
        [self.searchBar.bottomAnchor constraintEqualToAnchor:self.searchSurfaceView.bottomAnchor constant:-5.0],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.filterButton.leadingAnchor constant:-8.0],
        
        
        [self.filterView.topAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:10],
        [self.filterView.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor],
        [self.filterView.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor],
    ]];

    self.filterHeightConstraint = [self.filterView.heightAnchor constraintEqualToConstant:0];
    self.filterHeightConstraint.active = YES;
    [self pp_updateSearchChromeForCurrentTraits];
    [self pp_updateFilterButtonAppearanceAnimated:NO];
}

- (void)pp_updateSearchChromeForCurrentTraits {
    if (!self.searchSurfaceView) {
        return;
    }

    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *surfaceColor = [[GM AppForegroundColor] colorWithAlphaComponent:1];
    if (@available(iOS 13.0, *)) {
        if (isDark) {
            surfaceColor = [[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:0.92];
        }
    }
    UIColor *borderColor = isDark
        ? [[UIColor whiteColor] colorWithAlphaComponent:0.08]
    : [[UIColor whiteColor] colorWithAlphaComponent:0.84] ;

    self.searchSurfaceView.backgroundColor = AppBackgroundClr;
    self.searchSurfaceView.layer.borderWidth = 0.75;
    [self.searchSurfaceView pp_setBorderColor:borderColor];
    [self.searchSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.searchSurfaceView.layer.shadowOpacity = isDark ? 0.18 : 0.08;
    self.searchSurfaceView.layer.shadowRadius = isDark ? 18.0 : 22.0;
    self.searchSurfaceView.layer.shadowOffset = CGSizeMake(0.0, isDark ? 10.0 : 14.0);

    self.searchAccentView.tintColor = [GM.appPrimaryColor colorWithAlphaComponent:isDark ? 0.16 : 0.10];
    self.searchAccentView.alpha = 1.0;
    self.searchBar.searchTextField.textColor = AppPrimaryTextClr;
    self.searchBar.searchTextField.tintColor = GM.appPrimaryColor;
    self.searchBar.searchTextField.leftView.tintColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.70];
}

- (void)pp_animateSearchChromeEntranceIfNeeded {
    if (self.didAnimateSearchChrome || !self.searchSurfaceView) {
        return;
    }
    self.didAnimateSearchChrome = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroHeaderView.alpha = 1.0;
        self.heroHeaderView.transform = CGAffineTransformIdentity;
        self.searchSurfaceView.alpha = 1.0;
        self.searchSurfaceView.transform = CGAffineTransformIdentity;
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        return;
    }

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.46
                          delay:0.02
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroHeaderView.alpha = 1.0;
        self.heroHeaderView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.46
                          delay:0.08
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.searchSurfaceView.alpha = 1.0;
        self.searchSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:0.16
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_filterButtonTouchDown:(UIButton *)button {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:nil];
}

- (void)pp_filterButtonTouchUp:(UIButton *)button {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_updateFilterButtonAppearanceAnimated:(BOOL)animated {
    NSUInteger activeCount = [self.filterView activeFilters].count;
    BOOL active = self.isFilterExpanded || activeCount > 0;
    UIColor *foreground = active ? UIColor.whiteColor : GM.appPrimaryColor;
    UIColor *background = active
    ? [GM.appPrimaryColor colorWithAlphaComponent:0.82]
        : [GM.appPrimaryColor colorWithAlphaComponent:0.10];

    void (^updates)(void) = ^{
        self.filterButton.backgroundColor = background;
        self.filterButton.tintColor = foreground;
        self.filterButton.layer.borderWidth = active ? 0.0 : 0.75;
        [self.filterButton pp_setBorderColor:[GM.appPrimaryColor colorWithAlphaComponent:0.16]];
        self.filterBadgeLabel.hidden = activeCount == 0;
        self.filterBadgeLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)activeCount];
        self.filterBadgeLabel.backgroundColor = active ? UIColor.whiteColor : GM.appPrimaryColor;
        self.filterBadgeLabel.textColor = active ? GM.appPrimaryColor : UIColor.whiteColor;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
        return;
    }
    [UIView transitionWithView:self.filterButton
                      duration:0.20
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:updates
                    completion:nil];
}

- (void)pp_toggleFilter {
    self.isFilterExpanded = !self.isFilterExpanded;
    [self pp_rebuildFilterContentIfNeeded:NO];
    if (self.isFilterExpanded) {
        [self.filterView layoutIfNeeded];
    }
    CGFloat targetFilterHeight = self.isFilterExpanded ? [self pp_currentFilterHeight] : 0;
    CGFloat collectionTopConstant = self.isFilterExpanded ? (12 + targetFilterHeight + 12) : 12;
    self.collectionTopConstraint.constant = collectionTopConstant;
    self.filterHeightConstraint.constant = targetFilterHeight;
    self.filterView.hidden = NO;
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
    [self pp_updateFilterButtonAppearanceAnimated:YES];

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    if (reduceMotion) {
        self.filterView.alpha = self.isFilterExpanded ? 1.0 : 0.0;
        self.filterView.transform = CGAffineTransformIdentity;
        [self.filterView.superview layoutIfNeeded];
        self.filterView.hidden = !self.isFilterExpanded;
        return;
    }

    [UIView animateWithDuration:0.32 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.filterView.alpha = self.isFilterExpanded ? 1.0 : 0.0;
        self.filterView.transform = self.isFilterExpanded ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, -8.0);
        [self.filterView.superview layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.filterView.hidden = !self.isFilterExpanded;
    }];
}

- (void)pp_rebuildFilterContentIfNeeded:(BOOL)force {
    NSArray<NSDictionary *> *kindItems = [self pp_kindFilterItems];
    NSArray<NSDictionary *> *genderItems = [self pp_genderFilterItems];
    NSString *signature = [self pp_filterSignatureForKindItems:kindItems genderItems:genderItems];

    if (!force && self.filterView.hasContent && [self.filterContentSignature isEqualToString:signature]) {
        return;
    }

    NSDictionary *previousFilters = [self.filterView activeFilters];
    [self.filterView removeAllSections];

    if (kindItems.count > 0) {
        [self.filterView addSectionWithTitle:kLang(@"Kind")
                                       items:kindItems
                                         key:PPAdoptFilterKindKey
                               allowMultiple:NO];
    }

    [self.filterView addSectionWithTitle:kLang(@"Gender")
                                   items:genderItems
                                     key:PPAdoptFilterGenderKey
                           allowMultiple:NO];
    [self.filterView addResetButtonWithTitle:kLang(@"Reset")];
    [self.filterView applySelectedFilters:previousFilters notify:NO];
    [self.filterView layoutIfNeeded];

    self.filterContentSignature = signature;
    [self pp_updateExpandedFilterLayoutIfNeeded];
}

- (void)pp_updateExpandedFilterLayoutIfNeeded {
    if (!self.isFilterExpanded) {
        return;
    }
    [self.filterView layoutIfNeeded];
    CGFloat targetFilterHeight = [self pp_currentFilterHeight];
    self.filterHeightConstraint.constant = targetFilterHeight;
    self.collectionTopConstraint.constant = 12 + targetFilterHeight + 12;
}

- (CGFloat)pp_currentFilterHeight {
    [self.filterView layoutIfNeeded];
    CGFloat measuredHeight = [self.filterView intrinsicContentSize].height;
    if (measuredHeight <= 0 || !isfinite(measuredHeight)) {
        measuredHeight = 0;
    }
    CGFloat maxHeight = floor(CGRectGetHeight(self.view.bounds) * 0.34);
    if (maxHeight <= 0) {
        maxHeight = 260.0;
    }
    return MIN(measuredHeight, maxHeight);
}

- (NSArray<NSDictionary *> *)pp_kindFilterItems {
    NSMutableArray<MainKindsModel *> *availableKinds = [NSMutableArray array];
    for (MainKindsModel *kind in MKM.MainKindsArray) {
        if (![kind isKindOfClass:MainKindsModel.class] || kind.ID <= 0 || !kind.isVisibleInUserApp) {
            continue;
        }
        NSString *title = kind.KindName.length > 0 ? kind.KindName : [MainKindsModel kindNameForID:kind.ID];
        if (title.length == 0) {
            continue;
        }
        [availableKinds addObject:kind];
    }

    if (availableKinds.count > 0) {
        NSArray<MainKindsModel *> *sortedKinds = [availableKinds sortedArrayUsingComparator:^NSComparisonResult(MainKindsModel *first, MainKindsModel *second) {
            if (first.sortingKey != second.sortingKey) {
                return first.sortingKey < second.sortingKey ? NSOrderedAscending : NSOrderedDescending;
            }
            NSString *firstTitle = first.KindName ?: @"";
            NSString *secondTitle = second.KindName ?: @"";
            return [firstTitle localizedCaseInsensitiveCompare:secondTitle];
        }];

        NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithCapacity:sortedKinds.count];
        for (MainKindsModel *kind in sortedKinds) {
            NSString *title = kind.KindName.length > 0 ? kind.KindName : [MainKindsModel kindNameForID:kind.ID];
            if (title.length > 0) {
                [items addObject:@{ @"id": @(kind.ID), @"title": title }];
            }
        }
        return items;
    }

    NSMutableDictionary<NSNumber *, NSString *> *fallbackKinds = [NSMutableDictionary dictionary];
    for (AdoptPetModel *pet in self.items) {
        if (pet.kindID <= 0) {
            continue;
        }
        MainKindsModel *kindModel = [MainKindsModel mainKindModelForID:pet.kindID];
        if (kindModel && !kindModel.isVisibleInUserApp) {
            continue;
        }
        NSString *title = [MainKindsModel kindNameForID:pet.kindID];
        if (title.length == 0) {
            title = kindModel.KindName.length > 0 ? kindModel.KindName : pet.mainKindModel.KindName;
        }
        if (title.length > 0) {
            fallbackKinds[@(pet.kindID)] = title;
        }
    }

    NSArray<NSNumber *> *sortedIDs = [fallbackKinds.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithCapacity:sortedIDs.count];
    for (NSNumber *kindID in sortedIDs) {
        NSString *title = fallbackKinds[kindID];
        if (title.length > 0) {
            [items addObject:@{ @"id": kindID, @"title": title }];
        }
    }
    return items;
}

- (NSArray<NSDictionary *> *)pp_genderFilterItems {
    return @[
        @{ @"id": PPAdoptGenderMaleValue, @"title": kLang(@"Male") },
        @{ @"id": PPAdoptGenderFemaleValue, @"title": kLang(@"Female") },
    ];
}

- (NSString *)pp_filterSignatureForKindItems:(NSArray<NSDictionary *> *)kindItems genderItems:(NSArray<NSDictionary *> *)genderItems {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSDictionary *item in kindItems) {
        [parts addObject:[NSString stringWithFormat:@"k:%@:%@", item[@"id"] ?: @"", item[@"title"] ?: @""]];
    }
    for (NSDictionary *item in genderItems) {
        [parts addObject:[NSString stringWithFormat:@"g:%@:%@", item[@"id"] ?: @"", item[@"title"] ?: @""]];
    }
    return [parts componentsJoinedByString:@"|"];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self pp_applySearchAndFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - PPSearchFilterViewDelegate

- (void)searchFilterView:(PPSearchFilterView *)view didSelectFilters:(NSDictionary *)filters {
    [self pp_applySearchAndFilterWithFilters:filters];
    [self pp_updateFilterButtonAppearanceAnimated:YES];
}

- (void)searchFilterViewDidReset:(PPSearchFilterView *)view {
    [self pp_applySearchAndFilter];
    [self pp_updateFilterButtonAppearanceAnimated:YES];
}

- (void)pp_applySearchAndFilter {
    [self pp_applySearchAndFilterWithFilters:nil];
}

- (void)pp_applySearchAndFilterWithFilters:(NSDictionary *)extraFilters {
    NSString *query = self.searchBar.text ? [self.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] : @"";
    NSDictionary *activeFilters = extraFilters ?: [self.filterView activeFilters];

    if (query.length == 0 && activeFilters.count == 0) {
        self.filteredItems = [self.items mutableCopy];
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (AdoptPetModel *pet in self.items) {
            BOOL matchesQuery = YES;
            if (query.length > 0) {
                NSString *kindName = pet.mainKindModel.KindName.length > 0 ? pet.mainKindModel.KindName : [MainKindsModel kindNameForID:pet.kindID];
                NSString *normalizedGender = PPAdoptNormalizedGenderValue(pet.gender);
                NSString *genderName = @"";
                if ([normalizedGender isEqualToString:PPAdoptGenderFemaleValue]) {
                    genderName = kLang(@"Female");
                } else if ([normalizedGender isEqualToString:PPAdoptGenderMaleValue]) {
                    genderName = kLang(@"Male");
                }
                NSString *searchSpace = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@",
                    pet.name ?: @"",
                    pet.details ?: @"",
                    pet.mCityName ?: @"",
                    pet.subKindModel.SubKindName ?: @"",
                    kindName ?: @"",
                    genderName ?: @""].lowercaseString;
                matchesQuery = [searchSpace containsString:query.lowercaseString];
            }

            BOOL matchesFilters = YES;
            if (activeFilters[PPAdoptFilterKindKey]) {
                NSInteger filterKind = [activeFilters[PPAdoptFilterKindKey] integerValue];
                if (pet.kindID != filterKind) matchesFilters = NO;
            }
            if (activeFilters[PPAdoptFilterGenderKey]) {
                NSString *filterGender = PPAdoptNormalizedGenderValue(activeFilters[PPAdoptFilterGenderKey]);
                NSString *petGender = PPAdoptNormalizedGenderValue(pet.gender);
                if (filterGender.length > 0 && ![petGender isEqualToString:filterGender]) matchesFilters = NO;
            }

            if (matchesQuery && matchesFilters) {
                [filtered addObject:pet];
            }
        }
        self.filteredItems = filtered;
    }

    [self.collectionView reloadData];
    [self pp_updateEmptyState];
}

#pragma mark - Setup Collection

- (void)pp_setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 12;
    layout.minimumLineSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.alwaysBounceVertical = YES;
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    [self.view addSubview:self.collectionView];

    [self.view bringSubviewToFront:self.filterView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.collectionTopConstraint = [self.collectionView.topAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:12];
    [NSLayoutConstraint activateConstraints:@[
        self.collectionTopConstraint,
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)pp_setupEmptyStateLabel {
    self.emptyStateView = [[UIView alloc] init];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.emptyStateView.layer.cornerRadius = 28.0;
    self.emptyStateView.layer.masksToBounds = NO;
    self.emptyStateView.hidden = YES;
    self.emptyStateView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPApplyContinuousCorners(self.emptyStateView, 28.0);
    [self.emptyStateView pp_setShadowColor:UIColor.blackColor];
    self.emptyStateView.layer.shadowOpacity = 0.04;
    self.emptyStateView.layer.shadowRadius = 18.0;
    self.emptyStateView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [self.view addSubview:self.emptyStateView];

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.10];
    iconPlate.layer.cornerRadius = 25.0;
    iconPlate.layer.masksToBounds = YES;
    PPApplyContinuousCorners(iconPlate, 25.0);
    [self.emptyStateView addSubview:iconPlate];

    self.emptyStateIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    self.emptyStateIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateIconView.tintColor = GM.appPrimaryColor;
    self.emptyStateIconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconPlate addSubview:self.emptyStateIconView];

    self.emptyStateTitleLabel = [[UILabel alloc] init];
    self.emptyStateTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateTitleLabel.numberOfLines = 2;
    self.emptyStateTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyStateTitleLabel.font = [GM boldFontWithSize:19.0] ?: [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    self.emptyStateTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self.emptyStateView addSubview:self.emptyStateTitleLabel];

    self.emptyStateSubtitleLabel = [[UILabel alloc] init];
    self.emptyStateSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateSubtitleLabel.numberOfLines = 0;
    self.emptyStateSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyStateSubtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.emptyStateSubtitleLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
    [self.emptyStateView addSubview:self.emptyStateSubtitleLabel];

    self.emptyStateActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.emptyStateActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateActionButton.titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    self.emptyStateActionButton.tintColor = UIColor.whiteColor;
    self.emptyStateActionButton.backgroundColor = GM.appPrimaryColor;
    self.emptyStateActionButton.layer.cornerRadius = 20.0;
    self.emptyStateActionButton.layer.masksToBounds = YES;
    PPApplyContinuousCorners(self.emptyStateActionButton, 20.0);
    [self.emptyStateActionButton addTarget:self action:@selector(pp_emptyStateActionTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyStateView addSubview:self.emptyStateActionButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:24.0],
        [self.emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [self.emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28.0],

        [iconPlate.topAnchor constraintEqualToAnchor:self.emptyStateView.topAnchor constant:24.0],
        [iconPlate.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:50.0],
        [iconPlate.heightAnchor constraintEqualToConstant:50.0],

        [self.emptyStateIconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [self.emptyStateIconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [self.emptyStateIconView.widthAnchor constraintEqualToConstant:24.0],
        [self.emptyStateIconView.heightAnchor constraintEqualToConstant:24.0],

        [self.emptyStateTitleLabel.topAnchor constraintEqualToAnchor:iconPlate.bottomAnchor constant:16.0],
        [self.emptyStateTitleLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor constant:22.0],
        [self.emptyStateTitleLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor constant:-22.0],

        [self.emptyStateSubtitleLabel.topAnchor constraintEqualToAnchor:self.emptyStateTitleLabel.bottomAnchor constant:8.0],
        [self.emptyStateSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor constant:24.0],
        [self.emptyStateSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor constant:-24.0],

        [self.emptyStateActionButton.topAnchor constraintEqualToAnchor:self.emptyStateSubtitleLabel.bottomAnchor constant:18.0],
        [self.emptyStateActionButton.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [self.emptyStateActionButton.heightAnchor constraintEqualToConstant:40.0],
        [self.emptyStateActionButton.widthAnchor constraintGreaterThanOrEqualToConstant:142.0],
        [self.emptyStateActionButton.bottomAnchor constraintEqualToAnchor:self.emptyStateView.bottomAnchor constant:-24.0]
    ]];
}

- (void)pp_updateCollectionInsetsForBottomBar {
    CGFloat bottomInset = 100.0;
    self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
}

#pragma mark - Listening

- (void)pp_stopListening {
    if (self.listener) {
        [self.listener remove];
        self.listener = nil;
    }
}

- (void)startListening {
    [self pp_stopListening];

    __weak typeof(self) weakSelf = self;
    self.listener = [AdoptPetManager.shared observeAllPetsWithUpdate:^(NSArray<AdoptPetModel *> * _Nonnull pets, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[AdoptPets] listener error: %@", error.localizedDescription);
            strongSelf.isShowingLoadError = YES;
            strongSelf.loadErrorMessage = error.localizedDescription;
            strongSelf.hasReceivedInitialSnapshot = YES;
            [strongSelf pp_updateEmptyState];
            return;
        }

        strongSelf.isShowingLoadError = NO;
        strongSelf.loadErrorMessage = nil;
        strongSelf.hasReceivedInitialSnapshot = YES;
        strongSelf.items = pets.mutableCopy ?: [NSMutableArray array];
        [strongSelf pp_rebuildFilterContentIfNeeded:NO];
        [strongSelf pp_applySearchAndFilter];
        [strongSelf pp_updateFilterButtonAppearanceAnimated:NO];
        [strongSelf pp_updateEmptyState];
    }];
}

- (void)pp_updateEmptyState {
    [self pp_updateHeroCount];

    BOOL hasVisibleData = self.filteredItems.count > 0;
    BOOL showError = self.isShowingLoadError && !hasVisibleData;
    BOOL showEmpty = !hasVisibleData && self.hasReceivedInitialSnapshot;
    BOOL show = showError || showEmpty;
    self.emptyStateView.hidden = !show;
    self.collectionView.hidden = show && self.filteredItems.count == 0;
    if (!show) {
        return;
    }

    if (showError) {
        self.emptyStateIconView.image = [UIImage systemImageNamed:@"wifi.exclamationmark"];
        self.emptyStateTitleLabel.text = kLang(@"adopt_list_error_title");
        self.emptyStateSubtitleLabel.text = self.loadErrorMessage.length > 0 ? self.loadErrorMessage : kLang(@"adopt_list_error_subtitle");
        [self.emptyStateActionButton setTitle:kLang(@"KLang_Retry") forState:UIControlStateNormal];
        self.emptyStateActionButton.hidden = NO;
        return;
    }

    BOOL hasActiveFilters = self.searchBar.text.length > 0 || [self.filterView activeFilters].count > 0;
    self.emptyStateIconView.image = [UIImage systemImageNamed:hasActiveFilters ? @"line.3.horizontal.decrease.circle" : @"heart.circle.fill"];
    self.emptyStateTitleLabel.text = hasActiveFilters ? kLang(@"adopt_list_no_results_title") : kLang(@"adopt_list_empty_title");
    self.emptyStateSubtitleLabel.text = hasActiveFilters ? kLang(@"adopt_list_no_results_subtitle") : kLang(@"adopt_list_empty_subtitle");
    [self.emptyStateActionButton setTitle:(hasActiveFilters ? kLang(@"Reset") : kLang(@"adopt_list_add_action")) forState:UIControlStateNormal];
    self.emptyStateActionButton.hidden = NO;
}

- (void)pp_updateHeroCount {
    NSString *format = kLang(@"adopt_list_count_format");
    if (format.length == 0) {
        format = @"%ld";
    }
    self.heroCountLabel.text = [NSString stringWithFormat:format, (long)self.items.count];
}

- (void)pp_emptyStateActionTapped {
    if (self.isShowingLoadError) {
        [self startListening];
        return;
    }

    BOOL hasActiveFilters = self.searchBar.text.length > 0 || [self.filterView activeFilters].count > 0;
    if (hasActiveFilters) {
        self.searchBar.text = @"";
        [self.filterView resetAll];
        [self pp_applySearchAndFilter];
        [self pp_updateFilterButtonAppearanceAnimated:YES];
        return;
    }

    [self addNewPetForAdopt];
}

#pragma mark - Navigation Actions

- (IBAction)showHome {
    CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)showSupport {
    CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)notificationsBtnTapped:(UIButton *)sender {}

- (void)chatsBtnTapped:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    UserChatsViewController *vc = [[UserChatsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)shoppingCartClicked:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)cartClicked:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    CartViewController *vc = [[CartViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)addNewPetForAdopt {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Account blocked")
                          subtitle:kLang(@"Your account is blocked. You can't add adoption posts right now.")];
        return;
    }

    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermAdoption, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add adoption posts.")];
        return;
    }

    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] init];
    vc.modalInPresentation = NO;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.layer.cornerRadius = 20;
    nav.navigationBar.clipsToBounds = YES;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)favTapped {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites
                                                                    viewType:ViewTypeAdopt];
    vc.modalInPresentation = NO;
    vc.navigationItem.backButtonTitle = @"";
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.filteredItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    id cell = [PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
    if (indexPath.item >= (NSInteger)self.filteredItems.count) return cell;

    AdoptPetModel *model = self.filteredItems[indexPath.item];
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:model context:PPCellForAdopt];
    vm.indexPath = indexPath;

    cell.delegate = self;
    cell.showsSubtitle = YES;
    cell.hideTopBadge = NO;
    //vm.finalPrice = @425;
    [cell applyViewModel:vm
                 context:PPCellForAdopt
              layoutMode:PPCellLayoutModePinterest
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView * _Nullable iv, NSString * _Nullable url, UIImage * _Nullable ph, UIView * _Nullable card) {
        if (url.length > 0) {
            [GM setImageFromFirebaseURLString:url imageView:iv phImage:@"PawPlacerS" showShimmer:YES completion:nil];
        }
    }];

    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat available = collectionView.bounds.size.width - (12 * 3);
    CGFloat width = floor(available / 2.0);
    return CGSizeMake(width, width + 65.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.filteredItems.count) return;
    AdoptPetModel *selected = self.filteredItems[indexPath.item];
    BOOL isOwner = [self pp_isOwnerForModel:selected];
    AdoptPetDetailsViewController *vc = [[AdoptPetDetailsViewController alloc] initWithModel:selected isOwner:isOwner];
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = vc.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = NO;
        sheet.preferredCornerRadius = 30;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
        sheet.prefersEdgeAttachedInCompactHeight = YES;
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = NO;
    }
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel {
    NSIndexPath *ip = universalModel.indexPath;
    if (!ip || ip.item >= (NSInteger)self.filteredItems.count) return;
    [self collectionView:self.collectionView didSelectItemAtIndexPath:ip];
}

- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;

    NSMutableArray *shareItems = [NSMutableArray array];
    NSString *title = model.name.length > 0 ? model.name : kLang(@"AdoptPet");
    [shareItems addObject:title];

    NSString *imageURL = model.imageURLs.firstObject;
    if (imageURL.length > 0) {
        NSURL *url = [NSURL URLWithString:imageURL];
        if (url) [shareItems addObject:url];
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:shareItems applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
        activityVC.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)PPUniversalCell_tapFavorite:(PPUniversalCellViewModel *)universalModel {
    // FavoriteButton handles persistence internally via the cell's FavoriteButton.
}

- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;
    if (![self pp_isOwnerForModel:model]) return;

    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] initWithPet:model];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;
    if (![self pp_isOwnerForModel:model] || model.documentID.length == 0) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Delete")
                                                                    message:kLang(@"Are you sure you want to delete this post?")
                                                             preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Delete")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [[AdoptPetManager shared] deletePetWithID:model.documentID completion:^(BOOL success, NSError * _Nullable error) {
            if (!success && error) {
                [PPAlertHelper showErrorIn:strongSelf title:kLang(@"error") subtitle:error.localizedDescription ?: kLang(@"unknownError")];
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;
    if (![self pp_isOwnerForModel:model] || model.documentID.length == 0) return;

    BOOL nextVisible = !universalModel.isPubliclyVisible;
    __weak typeof(self) weakSelf = self;
    [[AdoptPetManager shared] updatePetVisibilityWithID:model.documentID
                                             visibility:(nextVisible ? 0 : 1)
                                             completion:^(BOOL success, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!success || error) {
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"listing_visibility_failed")];
            return;
        }
        NSString *message = nextVisible ? kLang(@"listing_visible_success") : kLang(@"listing_hidden_success");
        [AppManager.sharedInstance showSnakBar:message withColor:GM.appPrimaryColor andDuration:0.6 containerView:strongSelf.view];
    }];
}

#pragma mark - Helpers

- (BOOL)pp_isOwnerForModel:(AdoptPetModel *)model {
    NSString *currentUserID = UserManager.sharedManager.currentUser.ID;
    if (currentUserID.length == 0 || model.ownerID.length == 0) return NO;
    return [model.ownerID isEqualToString:currentUserID];
}

- (BOOL)pp_currentUserHasAnyPermissionInKeys:(NSArray<NSString *> *)permissionKeys {
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (!currentUser) return NO;
    return [currentUser hasAnyPermissionInKeys:permissionKeys];
}

@end
